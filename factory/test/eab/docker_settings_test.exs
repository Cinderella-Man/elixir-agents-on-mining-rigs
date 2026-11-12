defmodule Eab.DockerSettingsTest do
  @moduledoc """
  The installation's labels and CPU share (factory/README.md, section 6, change 1), with a stand-in `docker` that
  records its arguments. With both settings unset the arguments are the bench's; `bench_parity_test.exs` pins them.
  """
  use ExUnit.Case, async: false
  alias Eab.{DockerSettings, Sandbox}

  setup do
    on_exit(fn ->
      Application.delete_env(:eab, :docker_labels)
      Application.delete_env(:eab, :cpu_shares)
      Application.delete_env(:eab, :hex_cache_id)
    end)
  end

  test "unset, nothing is added" do
    Application.delete_env(:eab, :docker_labels)
    Application.delete_env(:eab, :cpu_shares)
    assert DockerSettings.run_args() == []
    assert DockerSettings.build_args() == []
  end

  test "set, the labels and the share follow the engine's own labels on each docker run" do
    Application.put_env(:eab, :docker_labels, ["machine=build", "owner.lane=tasks"])
    Application.put_env(:eab, :cpu_shares, 256)

    extra = [
      "--label",
      "machine=build",
      "--label",
      "owner.lane=tasks",
      "--cpu-shares",
      "256"
    ]

    assert DockerSettings.run_args() == extra

    assert DockerSettings.build_args() == [
             "--label",
             "machine=build",
             "--label",
             "owner.lane=tasks"
           ]

    services = %{"postgres" => "example/postgres:16", "clickhouse" => "example/clickhouse:25"}
    runs = docker_calls(%{"image" => "example/workspace:1", "services" => services})
    own = ["--label", "etf.installation=<installation>", "--label", "etf.run=settings-run"]

    assert runs == [
             ["run", "-d", "--name", "<name>-db", "--network=none", "--memory=1g", "--cpus=1"] ++
               own ++ extra ++ ["-e", "POSTGRES_PASSWORD=postgres", "example/postgres:16"],
             [
               "run",
               "-d",
               "--name",
               "<name>-ch",
               "--network=container:<name>-db",
               "--memory=3g",
               "--cpus=2",
               "--ulimit",
               "nofile=262144:262144"
             ] ++ own ++ extra ++ ["-e", "CLICKHOUSE_SKIP_USER_SETUP=1", "example/clickhouse:25"],
             [
               "run",
               "-d",
               "--name",
               "<name>",
               "--init",
               "--network=container:<name>-db",
               "--cap-drop=ALL",
               "--security-opt=no-new-privileges",
               "--memory=4g",
               "--cpus=2",
               "--pids-limit=512",
               "--tmpfs=/tmp:rw,nosuid,size=512m"
             ] ++ own ++ extra ++ ["example/workspace:1"]
           ]
  end

  test "labels alone add no share, and a share alone adds no label" do
    Application.put_env(:eab, :docker_labels, ["machine=build"])
    Application.delete_env(:eab, :cpu_shares)
    assert DockerSettings.run_args() == ["--label", "machine=build"]
    Application.delete_env(:eab, :docker_labels)
    Application.put_env(:eab, :cpu_shares, 512)
    assert DockerSettings.run_args() == ["--cpu-shares", "512"]
    assert DockerSettings.build_args() == []
  end

  test "a label that is not key=value and a share below 2 are refused" do
    for label <- ["machine", "=build", "a=b c"] do
      Application.put_env(:eab, :docker_labels, [label])
      assert_raise ArgumentError, ~r/EAB_DOCKER_LABELS/, fn -> DockerSettings.run_args() end
    end

    Application.delete_env(:eab, :docker_labels)

    for shares <- [0, 1, "256"] do
      Application.put_env(:eab, :cpu_shares, shares)
      assert_raise ArgumentError, ~r/EAB_CPU_SHARES/, fn -> DockerSettings.run_args() end
    end
  end

  # Section 6, change 10: the Hex cache id of the workspace recipe.
  test "unset or empty, the Hex cache id is the bench's, and the recipe carries it" do
    for unset <- [nil, ""] do
      Application.put_env(:eab, :hex_cache_id, unset)
      assert DockerSettings.hex_cache_id() == "eab-hex-packages-v1"
    end

    Application.delete_env(:eab, :hex_cache_id)
    recipe = Eab.Fixtures.dockerfile(%{"runtime" => %{"image" => "base"}}, "base")
    mounts = Regex.scan(~r/--mount=type=cache,id=([^,]+),/, recipe, capture: :all_but_first)
    assert mounts == [["eab-hex-packages-v1"], ["eab-hex-packages-v1"]]
  end

  test "set, the Hex cache id is the installation's in both lines of the recipe, and changes the recipe's hash" do
    Application.delete_env(:eab, :hex_cache_id)
    spec = %{"runtime" => %{"image" => "base"}}
    bench = Eab.Fixtures.dockerfile(spec, "base")
    Application.put_env(:eab, :hex_cache_id, "etf-hex-packages-v1")
    own = Eab.Fixtures.dockerfile(spec, "base")
    mounts = Regex.scan(~r/--mount=type=cache,id=([^,]+),/, own, capture: :all_but_first)
    assert mounts == [["etf-hex-packages-v1"], ["etf-hex-packages-v1"]]
    assert String.replace(own, "etf-hex-packages-v1", "eab-hex-packages-v1") == bench
    refute Eab.Inventory.hash(own) == Eab.Inventory.hash(bench)
  end

  test "a Hex cache id with other characters is refused" do
    for id <- ["-x", "a b", "a,target=/", "x" <> String.duplicate("y", 128), :atom] do
      Application.put_env(:eab, :hex_cache_id, id)
      assert_raise ArgumentError, ~r/EAB_HEX_CACHE_ID/, fn -> DockerSettings.hex_cache_id() end
    end
  end

  # Runs Eab.Sandbox against a stand-in `docker` that records its arguments and succeeds. Returns the `docker run`
  # calls, with the workspace container's name and the installation id replaced by placeholders.
  defp docker_calls(runtime) do
    dir = Path.join(System.tmp_dir!(), "etf-settings-#{System.unique_integer([:positive])}")
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

    try do
      Sandbox.with_runtime("settings-case", %{"runtime" => %{}}, runtime, "settings-run", fn _ ->
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
      |> Enum.filter(&(hd(&1) == "run"))

    File.rm_rf!(dir)
    ["run", "-d", "--name", name | _] = List.last(calls)
    assert name =~ ~r/\Aetf-[0-9a-f]{16}\z/
    installation = Sandbox.installation()

    replace = fn arg ->
      arg |> String.replace(name, "<name>") |> String.replace(installation, "<installation>")
    end

    Enum.map(calls, &Enum.map(&1, replace))
  end
end
