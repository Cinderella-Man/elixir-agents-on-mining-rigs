defmodule Eab.RedisServiceTest do
  @moduledoc """
  The Redis service (factory/README.md, section 6, change 9), with a stand-in `docker` that records its arguments: the
  containers and arguments with Redis beside Postgres and alone, the labels and the CPU share on it, nothing about
  Redis for a task that does not ask for it (`bench_parity_test.exs` pins those arguments), and the database
  baseline, which never captures Redis.
  """
  use ExUnit.Case, async: false
  alias Eab.{Baseline, Cache, Sandbox, ServiceImages, Store}

  @redis "redis:7.2-alpine@sha256:" <> String.duplicate("2f", 32)
  @labels ["--label", "etf.installation=<installation>", "--label", "etf.run=svc-run"]
  @redis_wait "for i in $(seq 1 60); do test \"$(redis-cli -h 127.0.0.1 ping)\" = PONG && exit 0; sleep 1; done; exit 1"
  @pg_wait "for i in $(seq 1 60); do pg_isready -h 127.0.0.1 -U postgres && exit 0; sleep 1; done; exit 1"

  setup do
    on_exit(fn ->
      Application.delete_env(:eab, :docker_labels)
      Application.delete_env(:eab, :cpu_shares)
    end)
  end

  test "beside Postgres, Redis joins Postgres's network with the workspace, and goes before Postgres" do
    calls = docker_calls(%{"postgres" => "example/postgres:16", "redis" => @redis})

    assert calls == [
             ["run", "-d", "--name", "<name>-db", "--network=none", "--memory=1g", "--cpus=1"] ++
               @labels ++ ["-e", "POSTGRES_PASSWORD=postgres", "example/postgres:16"],
             ["exec", "<name>-db", "sh", "-c", @pg_wait],
             [
               "run",
               "-d",
               "--name",
               "<name>-redis",
               "--network=container:<name>-db",
               "--memory=1g",
               "--cpus=1",
               "--tmpfs=/data:rw,nosuid,size=64m"
             ] ++ @labels ++ [@redis, "redis-server", "--save", "", "--appendonly", "no"],
             ["exec", "<name>-redis", "sh", "-c", @redis_wait],
             workspace("container:<name>-db"),
             ["rm", "-f", "-v", "<name>"],
             ["rm", "-f", "-v", "<name>-ch"],
             ["rm", "-f", "-v", "<name>-redis"],
             ["rm", "-f", "-v", "<name>-db"]
           ]
  end

  test "alone, Redis holds the private network and the workspace joins it" do
    calls = docker_calls(%{"redis" => @redis})

    assert calls == [
             [
               "run",
               "-d",
               "--name",
               "<name>-redis",
               "--network=none",
               "--memory=1g",
               "--cpus=1",
               "--tmpfs=/data:rw,nosuid,size=64m"
             ] ++ @labels ++ [@redis, "redis-server", "--save", "", "--appendonly", "no"],
             ["exec", "<name>-redis", "sh", "-c", @redis_wait],
             workspace("container:<name>-redis"),
             ["rm", "-f", "-v", "<name>"],
             ["rm", "-f", "-v", "<name>-ch"],
             ["rm", "-f", "-v", "<name>-redis"],
             ["rm", "-f", "-v", "<name>-db"]
           ]
  end

  test "with all three, the order is Postgres, ClickHouse, Redis, then the workspace" do
    services = %{
      "postgres" => "example/postgres:16",
      "clickhouse" => "example/clickhouse:25",
      "redis" => @redis
    }

    started =
      for ["run", "-d", "--name", name | args] <- docker_calls(services),
          do: {name, Enum.find(args, &String.starts_with?(&1, "--network="))}

    assert started == [
             {"<name>-db", "--network=none"},
             {"<name>-ch", "--network=container:<name>-db"},
             {"<name>-redis", "--network=container:<name>-db"},
             {"<name>", "--network=container:<name>-db"}
           ]
  end

  test "a task without Redis gets no Redis container, wait or removal" do
    for services <- [
          %{},
          %{"postgres" => "example/postgres:16"},
          %{"postgres" => "example/postgres:16", "clickhouse" => "example/clickhouse:25"}
        ] do
      calls = docker_calls(services)
      refute Enum.any?(calls, fn call -> Enum.any?(call, &String.contains?(&1, "redis")) end)

      assert Enum.filter(calls, &(hd(&1) == "rm")) == [
               ["rm", "-f", "-v", "<name>"],
               ["rm", "-f", "-v", "<name>-ch"],
               ["rm", "-f", "-v", "<name>-db"]
             ]
    end
  end

  test "the installation's labels and CPU share go on the Redis container too" do
    Application.put_env(:eab, :docker_labels, ["machine=build"])
    Application.put_env(:eab, :cpu_shares, 256)
    extra = ["--label", "machine=build", "--cpu-shares", "256"]

    [redis | _] = docker_calls(%{"redis" => @redis})

    assert redis ==
             [
               "run",
               "-d",
               "--name",
               "<name>-redis",
               "--network=none",
               "--memory=1g",
               "--cpus=1",
               "--tmpfs=/data:rw,nosuid,size=64m"
             ] ++ @labels ++ extra ++ [@redis, "redis-server", "--save", "", "--appendonly", "no"]
  end

  test "the database baseline never captures Redis and keeps it in the prepared runtime" do
    previous = Store.root()

    root =
      Path.join(System.tmp_dir!(), "etf-redis-baseline-#{System.unique_integer([:positive])}")

    Application.put_env(:eab, :data_dir, root)

    on_exit(fn ->
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
    end)

    opts = [image_exists?: fn _ -> true end]
    spec = %{"runtime" => %{}, "baseline" => %{"mode" => "prepared", "commands" => ["setup"]}}
    policy = Baseline.policy(spec)

    runtime = %{
      "image" => "project",
      "toolchain_image" => "tools",
      "services" => %{"postgres" => "pg-engine", "redis" => @redis},
      "database_inputs" => %{"version" => 1, "migrations" => %{"postgres" => []}}
    }

    assert ServiceImages.databases(runtime["services"]) == %{"postgres" => "pg-engine"}
    assert ServiceImages.ephemeral(runtime["services"]) == %{"redis" => @redis}

    # The database's key is the one the same project has without Redis, so Redis neither splits nor reuses it.
    inputs = Baseline.inputs(runtime, policy)

    assert inputs ==
             Baseline.inputs(Map.put(runtime, "services", %{"postgres" => "pg-engine"}), policy)

    Cache.fetch(
      "databases",
      inputs,
      fn _ -> %{"services" => %{"postgres" => "pg-snapshot"}, "images" => ["pg-snapshot"]} end,
      opts
    )

    result = Baseline.ensure("case", spec, runtime, "run", fn _ -> :ok end, opts)
    assert result["services"] == %{"postgres" => "pg-snapshot", "redis" => @redis}
    assert result["service_engines"] == runtime["services"]

    # Redis alone is no database: no record, no bootstrap, and the service stays as resolved.
    plain = %{"runtime" => %{}}
    alone = Map.put(runtime, "services", %{"redis" => @redis})
    result = Baseline.ensure("case", plain, alone, "run", fn _ -> flunk("prepared") end, opts)
    assert result["services"] == %{"redis" => @redis}
    assert result["baseline"]["mode"] == "prepared"
    assert length(Cache.records("databases")) == 1

    assert_raise RuntimeError, ~r/cannot cache bootstrap commands/, fn ->
      Baseline.ensure("case", spec, alone, "run", fn _ -> :ok end, opts)
    end
  end

  defp workspace(network) do
    [
      "run",
      "-d",
      "--name",
      "<name>",
      "--init",
      "--network=#{network}",
      "--cap-drop=ALL",
      "--security-opt=no-new-privileges",
      "--memory=4g",
      "--cpus=2",
      "--pids-limit=512",
      "--tmpfs=/tmp:rw,nosuid,size=512m"
    ] ++ @labels ++ ["example/workspace:1"]
  end

  # Runs Eab.Sandbox against a stand-in `docker` that records its arguments and succeeds. Returns every call, with the
  # workspace container's name and the installation id replaced by placeholders.
  defp docker_calls(services) do
    dir = Path.join(System.tmp_dir!(), "etf-redis-#{System.unique_integer([:positive])}")
    log = Path.join(dir, "calls")
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, "docker"), """
    #!/bin/sh
    for arg in "$@"; do printf '%s\\037' "$arg"; done >> '#{log}'
    printf '\\036' >> '#{log}'
    """)

    File.chmod!(Path.join(dir, "docker"), 0o755)
    path = System.get_env("PATH")
    System.put_env("PATH", dir <> ":" <> path)
    runtime = %{"image" => "example/workspace:1", "services" => services}

    try do
      Sandbox.with_runtime("redis-case", %{"runtime" => %{}}, runtime, "svc-run", fn _ ->
        :ok
      end)
    after
      System.put_env("PATH", path)
    end

    calls =
      log
      |> File.read!()
      |> String.split("\x1e", trim: true)
      |> Enum.map(&(&1 |> String.split("\x1f") |> Enum.drop(-1)))

    File.rm_rf!(dir)
    ["run", "-d", "--name", name | _] = Enum.find(Enum.reverse(calls), &(hd(&1) == "run"))
    assert name =~ ~r/\Aetf-[0-9a-f]{16}\z/
    installation = Sandbox.installation()

    replace = fn arg ->
      arg |> String.replace(name, "<name>") |> String.replace(installation, "<installation>")
    end

    Enum.map(calls, &Enum.map(&1, replace))
  end
end
