defmodule Eab.FactoryDockerTest do
  use ExUnit.Case, async: false
  @moduletag :docker
  @moduletag timeout: 900_000
  alias Eab.{Command, Factory, Inventory, Store}

  # `Eab.Factory.check/2` on two made-up tasks with the real probe and the real controls, second round included. Only
  # the source check (the made-up repositories do not exist) and the preparation (an image built from the tooling
  # image, as in task_grading_docker_test.exs) are replaced.
  test "check takes made-up tasks through the probe, the controls and their second round" do
    previous = Store.root()

    root =
      Path.join(System.tmp_dir!(), "eab-factory-docker-#{System.unique_integer([:positive])}")

    Application.put_env(:eab, :data_dir, root)
    tag = "elixir-task-factory:factory-check-#{System.unique_integer([:positive])}"
    Eab.MadeUpTasks.mount!(root <> "-tasks")

    on_exit(fn ->
      Command.run("docker", ["image", "rm", tag])
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
      File.rm_rf!(root <> "-tasks")
    end)

    source = Eab.MadeUpTasks.write_source!(Path.join(root, "context/source"))

    for args <- [
          ["init", "--quiet"],
          ["config", "user.name", "Synthetic"],
          ["config", "user.email", "test@localhost"],
          ["add", "."],
          ["commit", "--quiet", "-m", "Baseline"]
        ],
        do: Command.run!("git", args, cd: source)

    File.write!(Path.join(root, "context/Dockerfile"), """
    FROM #{Eab.TestTooling.image()}
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

    prepare = fn id, dir, _run_id, _emit ->
      Inventory.with_case(id, dir, fn ->
        Store.write("runtimes/#{id}.json", %{
          "image" => image,
          "services" => %{},
          "fixture_hashes" => Inventory.fixture_hashes(id)
        })
      end)
    end

    steps = %{source: fn _, _, _, _ -> :ok end, prepare: prepare}
    ids = ~w(ledgerette-pr-1 ledgerette-pr-2)
    assert {:ok, job} = Factory.check(ids, steps: steps, concurrency: 1)
    record = await_job(job)
    {:ok, %{"results" => results}} = Factory.job(job)
    assert record["counts"] == %{"checked" => 2}, inspect(results, pretty: true)

    for result <- results do
      assert result["verdict"] == "checked"
      assert result["second_round"]["same"], inspect(result)
      assert result["second_round"]["changed"] == []
      assert result["files"] == folder_hashes(Path.join(Inventory.tasks_dir(), result["id"]))
      control = Store.read("controls/#{result["id"]}.json")
      assert control["valid"]
      assert control["second_round"] == result["second_round"]
    end

    by = Map.new(results, &{&1["id"], &1})

    assert {by["ledgerette-pr-1"]["hidden_failing_first"],
            by["ledgerette-pr-1"]["hidden_passing_after"]} == {2, 2}

    assert by["ledgerette-pr-1"]["partial_control"] == %{"present" => true}

    assert by["ledgerette-pr-2"]["partial_control"] == %{
             "present" => false,
             "reason" => "single_hunk"
           }

    assert by["ledgerette-pr-2"]["preservation_left_out"] == []
  end

  defp folder_hashes(dir),
    do:
      for(file <- File.ls!(dir), into: %{}, do: {file, Inventory.hash_file(Path.join(dir, file))})

  defp await_job(job, attempts \\ 1500) do
    case Store.read("factory/jobs/#{job}/job.json") do
      %{"status" => status} = record when status in ~w(done error) ->
        record

      _ when attempts == 0 ->
        flunk("The job #{job} did not finish")

      _ ->
        Process.sleep(400)
        await_job(job, attempts - 1)
    end
  end
end
