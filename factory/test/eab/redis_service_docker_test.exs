defmodule Eab.RedisServiceDockerTest do
  @moduledoc """
  The Redis service on real containers (factory/README.md, section 6, change 9), with a made-up task, `tally-pr-3`,
  whose project keeps counters in Redis and whose tests talk to it on 127.0.0.1:6379. Its bundle is written here, in
  a temporary folder, so the made-up tasks of `test/support/` stay as they are. The Redis image is pinned by digest
  and must be on the machine before the test runs (its container has no network).

  - The gate's controls hold with Redis alone and with Redis beside Postgres: the unchanged project fails the hidden
    test in its body, the reference passes, the early exit is refused; another correct fix with its own test passes.
  - Without the service the same task does not qualify: its existing tests cannot reach Redis.
  - Every container of a task starts with an empty Redis that saves nothing, and Redis is removed with the workspace.
  """
  use ExUnit.Case, async: false
  @moduletag :docker
  @moduletag timeout: 900_000
  alias Eab.{Command, Grader, Inventory, Sandbox, Store}

  @redis "redis:7.2-alpine@sha256:2f66de68111e64c3927859f158f8e666066dae2b97d9f82770a6f37a5aa1c335"
  @postgres "postgres:16-alpine"
  @id "tally-pr-3"
  @run "redis-check"

  test "a task whose tests need Redis passes the gate with the service, and each container starts with an empty one" do
    previous = Store.root()
    root = Path.join(System.tmp_dir!(), "etf-redis-check-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)
    tag = "elixir-task-factory:redis-check-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      Sandbox.cleanup(@run)
      Command.run("docker", ["image", "rm", tag])
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
    end)

    source = Path.join(root, "context/source")
    write_source!(source)
    git!(source, ["init", "--quiet"])
    git!(source, ["config", "user.name", "Synthetic"])
    git!(source, ["config", "user.email", "test@localhost"])
    git!(source, ["add", "."])
    git!(source, ["commit", "--quiet", "-m", "Baseline"])

    tally = File.read!(Path.join(source, "lib/tally.ex"))
    broken = ~s|Redis.command(["INCR", key])|

    reference =
      patch(source, [
        {"lib/tally.ex",
         String.replace(tally, broken, ~s|Redis.command(["INCRBY", key, Integer.to_string(n)])|)}
      ])

    reference_tests =
      patch(source, [
        {"test/add_many_test.exs",
         """
         defmodule Tally.AddManyTest do
           use ExUnit.Case

           test "adding counts every unit" do
             key = "tally:" <> Base.encode16(:crypto.strong_rand_bytes(8))
             Tally.add(key, 3)
             Tally.add(key, 4)
             assert Tally.count(key) == 7
           end
         end
         """}
      ])

    # Another correct fix than the reference, with the model's own test.
    alternative =
      patch(source, [
        {"lib/tally.ex",
         String.replace(
           tally,
           broken,
           ~s|Enum.reduce(1..n//1, nil, fn _, _ -> Redis.command(["INCR", key]) end)|
         )},
        {"test/sum_test.exs",
         """
         defmodule Tally.SumTest do
           use ExUnit.Case

           test "two adds sum" do
             key = "tally:" <> Base.encode16(:crypto.strong_rand_bytes(8))
             Tally.add(key, 2)
             Tally.add(key, 5)
             assert Tally.count(key) == 7
           end
         end
         """}
      ])

    bundle = write_bundle!(Path.join(root, "tasks"), reference, reference_tests)

    File.write!(Path.join(root, "context/Dockerfile"), """
    FROM eab-tooling:dev
    ENV PATH=/opt/pi:$PATH HOME=/tmp MIX_ENV=test MIX_BUILD_ROOT=/workspace/_build MIX_DEPS_PATH=/workspace/deps
    WORKDIR /workspace
    COPY --chown=65534:65534 source/ /workspace/
    RUN chown -R 65534:65534 /workspace
    USER 65534:65534
    RUN mix compile
    CMD ["sleep", "infinity"]
    """)

    Command.run!(
      "docker",
      ["build", "--network=none", "--provenance=false", "-t", tag, Path.join(root, "context")],
      timeout: 300
    )

    image =
      Command.run!("docker", ["image", "inspect", tag, "--format", "{{.Id}}"]) |> String.trim()

    Inventory.with_case(@id, bundle, fn ->
      runtime = fn services ->
        Store.write("runtimes/#{@id}.json", %{
          "image" => image,
          "services" => services,
          "fixture_hashes" => Inventory.fixture_hashes(@id)
        })
      end

      for services <- [%{"redis" => @redis}, %{"postgres" => @postgres, "redis" => @redis}] do
        runtime.(services)
        control = qualify!()

        IO.puts(
          "E71 controls with #{Enum.join(Enum.sort(Map.keys(services)), "+")}: valid=#{control["valid"]} " <>
            "empty=#{control["empty_patch"]["passed"]} reference=#{control["reference_patch"]["passed"]} " <>
            "early_exit=#{control["early_exit"]["passed"]}"
        )

        assert control["valid"], inspect(control)
        refute control["empty_patch"]["passed"]
        assert control["reference_patch"]["passed"]
        refute control["early_exit"]["passed"]
        assert control["partial_repair"] == nil

        assert Grader.grade(@id, alternative, @run, expected: control["reference_patch"])[
                 "passed"
               ]

        refute Grader.grade(@id, reference, @run, expected: control["reference_patch"])["passed"]
      end

      # Without the service the existing tests cannot reach Redis, so the reference fails and the task is refused.
      runtime.(%{})

      assert_raise RuntimeError, ~r/qualification failed/, fn ->
        Grader.qualify(@id, @run, fn _ -> :ok end)
      end

      without = Store.read("controls/#{@id}.json")
      IO.puts("E71 controls without the service: valid=#{without["valid"]}")
      refute without["reference_patch"]["passed"]
    end)

    # Every container of a task starts with an empty Redis that saves nothing; it is removed with the workspace.
    services = %{"postgres" => @postgres, "redis" => @redis}
    spec = %{"runtime" => %{}}

    first =
      Sandbox.with_runtime(@id, spec, %{"image" => image, "services" => services}, @run, fn box ->
        redis = box.name <> "-redis"
        assert redis_cli(redis, ["SET", "left-over", "1"]) == "OK"
        assert redis_cli(redis, ["DBSIZE"]) == "1"
        assert redis_cli(redis, ["CONFIG", "GET", "save"]) == "save"
        assert redis_cli(redis, ["CONFIG", "GET", "appendonly"]) == "appendonly\nno"

        [info] = Command.run!("docker", ["inspect", redis]) |> Jason.decode!()
        assert info["Mounts"] == []
        assert info["HostConfig"]["Tmpfs"] == %{"/data" => "rw,nosuid,size=64m"}
        [db] = Command.run!("docker", ["inspect", box.name <> "-db"]) |> Jason.decode!()
        network = info["HostConfig"]["NetworkMode"]
        assert network in ["container:" <> box.name <> "-db", "container:" <> db["Id"]]
        assert info["HostConfig"]["Memory"] == 1_073_741_824
        assert info["HostConfig"]["NanoCpus"] == 1_000_000_000
        assert info["Config"]["Labels"]["etf.run"] == @run

        IO.puts(
          "E71 container #{redis} network=#{info["HostConfig"]["NetworkMode"]} " <>
            "memory=#{info["HostConfig"]["Memory"]} nano_cpus=#{info["HostConfig"]["NanoCpus"]} " <>
            "cpu_shares=#{info["HostConfig"]["CpuShares"]} tmpfs=#{Jason.encode!(info["HostConfig"]["Tmpfs"])} " <>
            "mounts=#{length(info["Mounts"])}"
        )

        box.name
      end)

    for suffix <- ["", "-redis", "-db"] do
      result = Command.run("docker", ["inspect", first <> suffix], timeout: 30)
      refute result["returncode"] == 0, "#{first <> suffix} was not removed"
    end

    Sandbox.with_runtime(@id, spec, %{"image" => image, "services" => services}, @run, fn box ->
      assert redis_cli(box.name <> "-redis", ["DBSIZE"]) == "0"
      assert redis_cli(box.name <> "-redis", ["GET", "left-over"]) == ""
    end)
  end

  defp qualify! do
    Grader.qualify(@id, @run, fn _ -> :ok end)
  rescue
    error ->
      saved = Store.read("controls/#{@id}.json")

      flunk(
        Exception.message(error) <>
          "\n" <> inspect(saved, limit: :infinity, printable_limit: :infinity)
      )
  end

  defp redis_cli(container, args) do
    Command.run!("docker", ["exec", container, "redis-cli", "-h", "127.0.0.1" | args])
    |> String.trim()
  end

  defp git!(dir, args), do: Command.run!("git", args, cd: dir)

  defp patch(source, files) do
    for {file, contents} <- files do
      File.mkdir_p!(Path.dirname(Path.join(source, file)))
      File.write!(Path.join(source, file), contents)
    end

    git!(source, ["add", "--all"])
    diff = git!(source, ["diff", "--cached", "--binary", "HEAD"])
    git!(source, ["restore", "--source=HEAD", "--staged", "--worktree", "."])
    git!(source, ["clean", "-fd"])
    diff
  end

  defp write_source!(dir) do
    files = [
      {".gitignore", "/_build/\n/deps/\n"},
      {"mix.exs",
       """
       defmodule Tally.MixProject do
         use Mix.Project

         def project do
           [app: :tally, version: "0.1.0", deps: []]
         end
       end
       """},
      {"lib/tally.ex",
       """
       defmodule Tally do
         @moduledoc "Made-up counters kept in Redis, for the factory's tests."
         alias Tally.Redis

         def add(key, n) when is_integer(n) and n >= 0 do
           Redis.command(["INCR", key])
         end

         def count(key) do
           case Redis.command(["GET", key]) do
             nil -> 0
             value -> String.to_integer(value)
           end
         end
       end
       """},
      {"lib/tally/redis.ex",
       """
       defmodule Tally.Redis do
         @moduledoc "Just enough of the Redis protocol for the counters."

         def command(args) do
           {:ok, socket} =
             :gen_tcp.connect({127, 0, 0, 1}, 6379, [:binary, active: false, packet: :line], 5000)

           try do
             request = ["*\#{length(args)}\\r\\n" | Enum.map(args, &"$\#{byte_size(&1)}\\r\\n\#{&1}\\r\\n")]
             :ok = :gen_tcp.send(socket, request)
             reply(socket)
           after
             :gen_tcp.close(socket)
           end
         end

         defp reply(socket) do
           case line(socket) do
             "+" <> text -> text
             ":" <> number -> String.to_integer(number)
             "$-1" -> nil
             "$" <> _ -> line(socket)
             "-" <> error -> raise "Redis error: \#{error}"
           end
         end

         defp line(socket) do
           {:ok, line} = :gen_tcp.recv(socket, 0, 5000)
           String.trim_trailing(line, "\\r\\n")
         end
       end
       """},
      {"test/test_helper.exs", "ExUnit.start()\n"},
      {"test/tally_test.exs",
       """
       defmodule TallyTest do
         use ExUnit.Case

         test "a new counter is zero" do
           assert Tally.count("tally:" <> Base.encode16(:crypto.strong_rand_bytes(8))) == 0
         end

         test "one unit counts one" do
           key = "tally:" <> Base.encode16(:crypto.strong_rand_bytes(8))
           Tally.add(key, 1)
           assert Tally.count(key) == 1
         end
       end
       """}
    ]

    for {file, contents} <- files do
      File.mkdir_p!(Path.dirname(Path.join(dir, file)))
      File.write!(Path.join(dir, file), contents)
    end
  end

  defp write_bundle!(tasks, reference, reference_tests) do
    dir = Path.join(tasks, @id)
    File.mkdir_p!(dir)
    digest = "@sha256:" <> String.duplicate("0", 63) <> "1"

    manifest = %{
      "id" => @id,
      "schema_version" => 3,
      "task_kind" => "bug_fix",
      "project" => "tally",
      "repository" => %{
        "url" => "https://github.com/made-up-org/tally",
        "revision" => "7a1c3e5f9b2d4f6a8c0e2b4d6f8a0c2e4b6d8f0a"
      },
      "runtime" => %{
        "profile" => "mix",
        "image" => "hexpm/elixir:1.18.4-erlang-27.3.4-ubuntu-noble-20250714" <> digest,
        "environment" => %{"MIX_ENV" => "test"},
        "setup_commands" => ["mix compile"],
        "before_test_commands" => []
      },
      "services" => %{"redis" => %{"image" => @redis}},
      "test_timeout" => 60,
      "allowed_edit_prefixes" => ["lib/", "test/"],
      "acceptance_patch" => "reference-tests.patch",
      "grading" => %{
        "adapter" => "exunit",
        "acceptance" => "mix test test/add_many_test.exs",
        "preservation" => "mix test test/tally_test.exs",
        "protected_paths" => ["test/"],
        "test_suffixes" => ["_test.exs"],
        "required" => ["Elixir.Tally.AddManyTest::test adding counts every unit"],
        "starting_failures" => ["Elixir.Tally.AddManyTest::test adding counts every unit"],
        "model_tests" => "behavioral"
      },
      "partial_control" => %{"present" => false, "reason" => "single_hunk"}
    }

    provenance = %{
      "repository" => "https://github.com/made-up-org/tally",
      "pull_request" => "https://github.com/made-up-org/tally/pull/3",
      "broken_revision" => "7a1c3e5f9b2d4f6a8c0e2b4d6f8a0c2e4b6d8f0a",
      "broken_tree" => "1b3d5f7a9c1e3b5d7f9a1c3e5b7d9f1a3c5e7b9d",
      "fixed_revision" => "2c4e6a8b0d2f4a6c8e0b2d4f6a8c0e2b4d6f8a0c",
      "fixed_tree" => "3d5f7b9c1e3a5c7e9b1d3f5a7c9e1b3d5f7a9c1e",
      "pair_selection" => "first parent of the merge commit, and the merge commit",
      "licence" => "MIT",
      "merged_at" => "2026-03-12",
      "marks" => []
    }

    File.write!(Path.join(dir, "case.json"), Jason.encode!(manifest))
    File.write!(Path.join(dir, "provenance.json"), Jason.encode!(provenance))
    File.write!(Path.join(dir, "reference.patch"), reference)
    File.write!(Path.join(dir, "reference-tests.patch"), reference_tests)

    File.write!(
      Path.join(dir, "integrity.patch"),
      File.read!(Path.join(Eab.MadeUpTasks.dir("ledgerette-pr-2"), "integrity.patch"))
    )

    dir
  end
end
