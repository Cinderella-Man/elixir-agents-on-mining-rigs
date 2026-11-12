defmodule Eab.FactoryTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias Eab.{Checkpoints, Factory, Grader, Inventory, Runs, Store}

  # The entry points of factory/README.md, section 6, change 5, on the made-up tasks in a temporary task folder. The
  # steps that need Docker (the source check, the preparation, the probe and the controls) are replaced by made-up
  # ones here; factory_docker_test.exs runs them for real.

  setup do
    previous = Store.root()
    root = Path.join(System.tmp_dir!(), "eab-factory-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)
    File.mkdir_p!(root)
    Eab.MadeUpTasks.mount!(root <> "-tasks")

    on_exit(fn ->
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
      File.rm_rf!(root <> "-tasks")
    end)

    %{root: root}
  end

  defp mounted(id), do: Path.join(Inventory.tasks_dir(), id)
  defp spec(dir), do: Inventory.read_json(Path.join(dir, "case.json"))

  defp hashes(dir) do
    for file <- File.ls!(dir), into: %{}, do: {file, Inventory.hash_file(Path.join(dir, file))}
  end

  # A copy of a made-up task in `dir`, changed by `change` (a function of the manifest), or byte for byte (nil).
  defp draft(dir, folder, from, change) do
    target = Path.join(dir, folder)
    File.mkdir_p!(dir)
    File.cp_r!(Eab.MadeUpTasks.dir(from), target)

    if change,
      do: File.write!(Path.join(target, "case.json"), Jason.encode!(change.(spec(target))))

    target
  end

  defp await_job(job, attempts \\ 500) do
    case Store.read("factory/jobs/#{job}/job.json") do
      %{"status" => status} = record when status in ~w(done error) ->
        record

      _ when attempts == 0 ->
        flunk("The job #{job} did not finish")

      _ ->
        Process.sleep(20)
        await_job(job, attempts - 1)
    end
  end

  defp result(states, phases \\ %{}),
    do: %{"completed" => true, "test_results" => states, "failure_phases" => phases}

  # The first round of a task's controls, reduced to what the second round compares: the unchanged project fails the
  # task's starting failures in their bodies, the reference passes its required tests, and the existing test passes in
  # both.
  defp first_round(id) do
    grading = spec(mounted(id))["grading"]
    existing = result(%{"Elixir.LedgeretteTest::test credits raise the balance" => "passed"})
    failing = Map.new(grading["starting_failures"], &{&1, "failed"})

    empty = %{
      "passed" => false,
      "submission" => existing,
      "hidden" => result(failing, Map.new(failing, fn {name, _} -> {name, "test"} end)),
      "regression" => existing
    }

    gold = %{
      "passed" => true,
      "submission" => existing,
      "hidden" => result(Map.new(grading["required"], &{&1, "passed"})),
      "regression" => existing
    }

    {empty, gold}
  end

  # Controls as `Eab.Grader.qualify/3` returns them. For the task `unstable`, a made-up unstable test: its first
  # starting failure passes on the unchanged project when the second round grades it again.
  defp controls(unstable) do
    fn id, _dir, _run_id, _emit ->
      {empty, gold} = first_round(id)

      again =
        if id == unstable do
          name = hd(spec(mounted(id))["grading"]["starting_failures"])
          put_in(empty, ["hidden", "test_results", name], "passed")
        else
          empty
        end

      second = Grader.second_round(empty, gold, again, gold)
      control = %{"empty_patch" => empty, "reference_patch" => gold, "second_round" => second}

      if second["same"],
        do: {:ok, Map.put(control, "valid", true)},
        else:
          {:error, Map.put(control, "valid", false),
           "Fixture qualification failed in the second round"}
    end
  end

  # The probe writes what it observed into the folder; here it adds an empty list of left-out existing tests, so that
  # a checked task's folder visibly becomes the probed copy.
  defp probe(id, dir, _run_id, _emit) do
    if id == "shelfwise-pr-7" do
      {:refused, "no_starting_failure",
       "no hidden test fails in its body on the unchanged project"}
    else
      manifest = Path.join(dir, "case.json")

      File.write!(
        manifest,
        Jason.encode!(put_in(spec(dir), ["grading", "preservation_left_out"], []))
      )

      {:ok, %{}}
    end
  end

  defp steps(unstable \\ nil) do
    ok = fn _, _, _, _ -> :ok end

    %{
      source: ok,
      prepare: ok,
      probe: &probe/4,
      controls: controls(unstable),
      cleanup: fn _ -> :ok end
    }
  end

  test "import copies valid task folders and refuses held-out repositories, other bytes and broken folders",
       %{
         root: root
       } do
    incoming = Path.join(root, "incoming")
    draft(incoming, "fresh-pr-1", "ledgerette-pr-2", &Map.put(&1, "id", "fresh-pr-1"))
    draft(incoming, "ledgerette-pr-1", "ledgerette-pr-1", nil)
    draft(incoming, "ledgerette-pr-2", "ledgerette-pr-2", &Map.put(&1, "test_timeout", 61))

    draft(incoming, "held-pr-1", "ledgerette-pr-1", fn spec ->
      spec
      |> Map.put("id", "held-pr-1")
      |> put_in(["repository", "url"], "https://github.com/livebook-dev/livebook")
    end)

    broken = draft(incoming, "broken-pr-1", "ledgerette-pr-1", &Map.put(&1, "id", "broken-pr-1"))
    File.rm!(Path.join(broken, "integrity.patch"))
    draft(incoming, "misnamed", "ledgerette-pr-1", &Map.put(&1, "id", "other-pr-1"))
    before = hashes(mounted("ledgerette-pr-2"))

    assert {:ok, results} = Factory.import(incoming)
    by = Map.new(results, &{&1["folder"], &1})
    assert by["fresh-pr-1"]["result"] == "imported"
    assert by["ledgerette-pr-1"]["result"] == "unchanged"
    assert by["ledgerette-pr-2"]["reason"] == "exists_with_other_bytes"
    assert by["held-pr-1"]["reason"] == "holdout"
    assert by["held-pr-1"]["detail"] =~ "livebook-dev/livebook"
    assert by["broken-pr-1"]["reason"] == "import_check"
    assert by["misnamed"]["reason"] == "folder_not_named_by_id"
    assert Enum.count(results, &(&1["result"] == "refused")) == 4

    assert "fresh-pr-1" in Inventory.all()
    refute "held-pr-1" in Inventory.all()
    refute "broken-pr-1" in Inventory.all()
    assert hashes(mounted("fresh-pr-1")) == hashes(Path.join(incoming, "fresh-pr-1"))
    assert hashes(mounted("ledgerette-pr-2")) == before
    assert [_] = Path.wildcard(Store.path("factory/imports/*.json"))
    # No half-written copy is left beside the tasks.
    assert File.ls!(Inventory.tasks_dir()) |> Enum.filter(&String.starts_with?(&1, ".")) == []
  end

  test "check runs the gate in a background job: a task that passes, one dropped by an unstable test in the second round, one dropped by the probe" do
    ids = ~w(ledgerette-pr-1 ledgerette-pr-2 shelfwise-pr-7)
    untouched = hashes(mounted("ledgerette-pr-2"))

    assert {:ok, job} = Factory.check(ids, steps: steps("ledgerette-pr-2"), concurrency: 2)
    record = await_job(job)
    assert record["status"] == "done", inspect(record)
    assert record["counts"] == %{"checked" => 1, "dropped" => 2}

    {:ok, %{"results" => results}} = Factory.job(job)
    by = Map.new(results, &{&1["id"], &1})

    passed = by["ledgerette-pr-1"]
    assert passed["verdict"] == "checked"
    assert passed["hidden_failing_first"] == 2
    assert passed["hidden_passing_after"] == 2
    assert passed["partial_control"] == %{"present" => true}
    assert passed["preservation_files"] == 1
    assert passed["preservation_left_out"] == []
    assert passed["second_round"]["same"]
    assert passed["files"] == hashes(mounted("ledgerette-pr-1"))
    # The checked task's folder is the probed copy now.
    assert spec(mounted("ledgerette-pr-1"))["grading"]["preservation_left_out"] == []

    unstable = by["ledgerette-pr-2"]
    name = hd(spec(mounted("ledgerette-pr-2"))["grading"]["starting_failures"])
    assert unstable["verdict"] == "dropped"
    assert unstable["dropped_at"] == "second_round"
    assert unstable["reason"] == "unstable"
    assert unstable["second_round"]["changed"] == ["empty/hidden: #{name}: failed -> passed"]
    assert unstable["partial_control"] == %{"present" => false, "reason" => "single_hunk"}
    # A dropped task's folder stays as it was imported; its probed copy stays with the job.
    assert hashes(mounted("ledgerette-pr-2")) == untouched
    assert File.exists?(Store.path("factory/jobs/#{job}/work/ledgerette-pr-2/case.json"))

    refused = by["shelfwise-pr-7"]
    assert {refused["dropped_at"], refused["reason"]} == {"probe", "no_starting_failure"}

    tsv =
      File.read!(Store.path("factory/jobs/#{job}/results.tsv")) |> String.split("\n", trim: true)

    assert length(tsv) == 4

    assert Enum.any?(
             tsv,
             &String.starts_with?(&1, "ledgerette-pr-2\tdropped\tsecond_round\tunstable\t")
           )

    assert Store.read("factory/tasks/ledgerette-pr-1.json")["verdict"] == "checked"

    assert File.read!(Store.path("factory/jobs/#{job}/progress.log")) =~
             "ledgerette-pr-1: checked"

    assert Factory.check(["no-such-task"]) == {:error, "Unknown tasks: no-such-task"}
    assert {:error, _} = Factory.check(["ledgerette-pr-1", "ledgerette-pr-1"])
  end

  test "a reference that fails only on a test the project skips is skipped_test, not a failure of the reference" do
    contract = %{"starting_failures" => ["M::test a"]}

    empty = %{
      "passed" => false,
      "hidden" => result(%{"M::test a" => "failed"}, %{"M::test a" => "test"})
    }

    run = fn states, code ->
      Map.merge(result(states), %{"returncode" => code, "passed" => false})
    end

    skipped = run.(%{"M::test a" => "passed", "M::test s" => "skipped"}, 0)
    passing = Map.put(run.(%{"M::test a" => "passed"}, 0), "passed", true)

    failing =
      run.(%{"M::test a" => "passed", "M::test s" => "skipped", "M::test f" => "failed"}, 2)

    for {submission, hidden, reason} <- [
          {skipped, skipped, "skipped_test"},
          {passing, skipped, "skipped_test"},
          {failing, skipped, "reference_existing_tests_fail"},
          {passing, failing, "reference_hidden_tests_fail"}
        ] do
      gold = %{"passed" => false, "submission" => submission, "hidden" => hidden}
      control = %{"empty_patch" => empty, "reference_patch" => gold}
      assert Factory.first_failure(contract, control) == reason
    end
  end

  test "check times every step, a failing one too, and keeps the tail of a long failure, where a build says why" do
    assert {:ok, job} = Factory.check(["ledgerette-pr-1"], steps: steps())
    assert await_job(job)["counts"] == %{"checked" => 1}
    {:ok, %{"results" => [passed]}} = Factory.job(job)

    for step <- ~w(import_check source prepare probe import_check_after_probe source_after_probe
                   prepare_after_probe controls),
        do: assert(is_integer(passed["#{step}_ms"]), step)

    log = "#1 building\n" <> String.duplicate("#5 Get: a package\n", 500) <> "ERROR: the cause"
    failing = Map.put(steps(), :prepare, fn _, _, _, _ -> raise log end)
    assert {:ok, job} = Factory.check(["ledgerette-pr-2"], steps: failing)
    assert await_job(job)["counts"] == %{"dropped" => 1}
    {:ok, %{"results" => [dropped]}} = Factory.job(job)
    assert {dropped["dropped_at"], dropped["reason"]} == {"prepare", "environment"}
    assert is_integer(dropped["prepare_ms"])
    assert String.starts_with?(dropped["detail"], "#1 building\n")
    assert String.ends_with?(dropped["detail"], "\nERROR: the cause")
    assert String.length(dropped["detail"]) < 2010

    short = Map.put(steps(), :probe, fn _, _, _, _ -> {:refused, "made_up", "short"} end)
    assert {:ok, job} = Factory.check(["ledgerette-pr-2"], steps: short)
    assert await_job(job)["counts"] == %{"dropped" => 1}
    {:ok, %{"results" => [refused]}} = Factory.job(job)
    assert {refused["detail"], is_integer(refused["probe_ms"])} == {"short", true}
  end

  test "export copies checked tasks with a table of their results and refuses the others", %{
    root: root
  } do
    assert {:ok, job} = Factory.check(["ledgerette-pr-1"], steps: steps())
    assert await_job(job)["counts"] == %{"checked" => 1}

    dest = Path.join(root, "export")
    assert {:ok, answer} = Factory.export(~w(ledgerette-pr-1 ledgerette-pr-2), dest)
    assert answer["exported"] == ["ledgerette-pr-1"]
    assert answer["refused"] == [%{"id" => "ledgerette-pr-2", "reason" => "not_checked"}]
    assert hashes(Path.join(dest, "ledgerette-pr-1")) == hashes(mounted("ledgerette-pr-1"))
    refute File.exists?(Path.join(dest, "ledgerette-pr-2"))
    [header, line] = File.read!(Path.join(dest, "results.tsv")) |> String.split("\n", trim: true)
    assert String.starts_with?(header, "id\tverdict\tdropped_at\treason\thidden_failing_first")
    assert String.starts_with?(line, "ledgerette-pr-1\tchecked\t\t\t2\t2\ttrue\t")

    # The same export again is a no-op; a task changed since its check is refused.
    assert {:ok, %{"exported" => ["ledgerette-pr-1"]}} = Factory.export(["ledgerette-pr-1"], dest)
    manifest = Path.join(mounted("ledgerette-pr-1"), "case.json")

    File.write!(
      manifest,
      Jason.encode!(Map.put(spec(mounted("ledgerette-pr-1")), "test_timeout", 61))
    )

    assert {:ok, %{"refused" => [%{"reason" => "changed_since_check"}]}} =
             Factory.export(["ledgerette-pr-1"], Path.join(root, "export2"))
  end

  test "start_run refuses a task without a statement and starts a run on tasks that have one" do
    discover = fn _, _ -> flunk("a refused run must not reach the model server") end

    assert Factory.start_run("http://stand-in:8080", ~w(ledgerette-pr-1 shelfwise-pr-7), %{},
             discover: discover
           ) ==
             {:error, "Tasks without a statement: ledgerette-pr-1"}

    assert Factory.start_run("http://stand-in:8080", ["no-such-task"], %{}, discover: discover) ==
             {:error, "Unknown tasks: no-such-task"}

    parent = self()
    keys = [:runner, :cleanup]
    old = Map.new(keys, &{&1, Application.get_env(:eab, &1)})
    Application.put_env(:eab, :cleanup, fn _ -> :ok end)

    Application.put_env(:eab, :runner, fn run, _, _ ->
      send(parent, {:started, run["cases"], run["model"]["url"]})
      :ok
    end)

    on_exit(fn ->
      for {k, v} <- old,
          do:
            if(v == nil,
              do: Application.delete_env(:eab, k),
              else: Application.put_env(:eab, k, v)
            )
    end)

    Runs.subscribe()

    endpoint = fn url, _key ->
      %{"url" => url, "backend" => "llama_cpp", "model" => "stand-in", "context" => 32_768}
    end

    assert {:ok, run} =
             Factory.start_run("http://stand-in:8080", ["shelfwise-pr-7"], %{},
               discover: endpoint
             )

    assert_receive {:started, ["shelfwise-pr-7"], "http://stand-in:8080"}, 3000
    await(fn -> Store.run(run)["status"] == "completed" and not Runs.snapshot().cleaning end)
  end

  defp await(condition, attempts \\ 150) do
    cond do
      condition.() ->
        :ok

      attempts == 0 ->
        flunk("The condition did not hold")

      true ->
        receive do
          :runs_changed -> :ok
        after
          20 -> :ok
        end

        await(condition, attempts - 1)
    end
  end

  test "kept_sessions lists the attempts of a finished run that completed and passed, with their folders" do
    run = "made-up-run"
    cases = ~w(passed-a failed-b error-c changed-d)

    Store.write("runs/#{run}/run.json", %{
      "id" => run,
      "status" => "completed",
      "cases" => cases,
      "experiment_id" => "made-up-experiment",
      "attempts" => %{},
      "model" => %{}
    })

    for {id, passed} <- [{"passed-a", true}, {"failed-b", false}, {"changed-d", true}] do
      Store.write("runs/#{run}/#{id}/runtime.json", %{"image" => "made-up-image"})
      {record, _} = Checkpoints.submit(run, id, %{"case" => id}, "made-up patch\n", "")
      Store.write("runs/#{run}/#{id}/grade.json", %{"passed" => passed})

      Checkpoints.complete(
        run,
        id,
        Map.merge(record, %{"status" => "completed", "grade" => %{"passed" => passed}}),
        ""
      )
    end

    Store.write("runs/#{run}/error-c/attempt.json", %{"case" => "error-c", "status" => "error"})
    # A grade changed after its receipt was sealed: not kept, and named.
    Store.write("runs/#{run}/changed-d/grade.json", %{"passed" => true, "changed" => true})

    assert {:ok, answer} = Factory.kept_sessions(run)
    assert answer["cases"] == 4
    assert [kept] = answer["kept"]
    assert kept["case"] == "passed-a"
    assert kept["folder"] == Store.path("runs/#{run}/passed-a")
    assert "model.patch" in kept["files"] and "grade.json" in kept["files"]
    assert [%{"case" => "changed-d", "error" => error}] = answer["unverified"]
    assert error =~ "changed"

    assert Factory.kept_sessions("no-such-run") == {:error, "Unknown run: no-such-run"}
  end

  test "status says which jobs run and how far they are, and a running job's tasks cannot be checked twice" do
    parent = self()

    blocking =
      Map.put(steps(), :probe, fn _id, _dir, _run_id, _emit ->
        send(parent, {:probing, self()})

        receive do
          :go -> {:refused, "made_up", "held by the test"}
        end
      end)

    assert {:ok, job} = Factory.check(["ledgerette-pr-1"], steps: blocking)
    assert_receive {:probing, worker}, 3000

    status = Factory.status()

    assert [
             %{
               "id" => ^job,
               "kind" => "check",
               "ids" => ["ledgerette-pr-1"],
               "finished" => 0,
               "total" => 1
             }
           ] =
             status["jobs"]

    assert Factory.check(["ledgerette-pr-1"], steps: blocking) ==
             {:error, "A running job holds: ledgerette-pr-1"}

    output = capture_io(fn -> Factory.cli(["status"]) end) |> Jason.decode!()
    assert [%{"id" => ^job}] = output["ok"]["jobs"]
    assert capture_io(fn -> Factory.cli(["no-such-command"]) end) =~ "Unknown command"

    send(worker, :go)
    assert await_job(job)["counts"] == %{"dropped" => 1}
    await(fn -> Factory.status()["jobs"] == [] end)
    assert Factory.status()["run"] == nil
  end

  # Job T10: in the controller's image the VM that runs `rpc` printed an ESOCK warning to standard output before the
  # answer, so the wrapper's output was not JSON. A stand-in for `docker` prints the same warning, then the answer.
  test "bin/factoryctl prints only the JSON answer after a warning, or all when no answer", %{
    root: root
  } do
    fake = Path.join(root, "docker")

    File.write!(fake, """
    #!/bin/sh
    IFS= read -r code
    echo "=ESOCK WARNING MSG==== 12-Nov-2026::04:08:17.011411 ==="
    echo "[UNIX-ESSIO] Failed open sctp dynamic library: libsctp.so.1"
    case "$code" in
      *'Eab.Factory.cli([Base.decode64!("c3RhdHVz")])'*) printf '{\\n  "ok": "status"\\n}\\n' ;;
      *) echo "rpc failed: $code"; exit 1 ;;
    esac
    """)

    File.chmod!(fake, 0o755)
    wrapper = Inventory.path("bin/factoryctl")
    env = [{"DOCKER", fake}, {"NAME", "made-up-controller"}]

    {output, 0} = System.cmd("bash", [wrapper, "status"], env: env)
    assert Jason.decode!(output) == %{"ok" => "status"}

    {output, status} = System.cmd("bash", [wrapper, "kept", "x"], env: env)
    assert status != 0
    assert output =~ "ESOCK WARNING"

    assert output =~
             ~s|rpc failed: Eab.Factory.cli([Base.decode64!("a2VwdA=="), Base.decode64!("eA==")])|
  end
end
