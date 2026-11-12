# gate.exs: evaluated inside the controller (controller.sh rpc), in a process of its own. For each made task folder
# named in P5_DIR/ids.txt, in turn (P5_CONCURRENCY at once):
#   1. prepare: the import check, the source check, the workspace image and the database (Eab.Fixtures.ensure/3);
#   2. two diagnostic runs of the hidden tests (unchanged project, reference), only to record how they fail;
#   3. Eab.BundleProbe.finish/4: observe the test names, settle the existing tests of grading.preservation, search a
#      partial fix, rewrite case.json;
#   4. import the rewritten folder (Eab.Candidates.import/1) and run the gate through Eab.Candidates.qualify/3:
#      the source check, prepare again, then Eab.Grader.qualify/3 (unchanged project, reference, early exit,
#      partial fix when one was found);
#   5. for a task whose controls hold, a second round: the unchanged project and the reference graded again in fresh
#      containers, every named test compared with the first round.
# Writes P5_DIR/out/<id>/ (row.json, the raw outputs of the runs), P5_DIR/checked/<id>/ (the checked folders),
# P5_DIR/out/gate.log and the marker P5_DIR/out/gate.done.
defmodule P5Gate do
  alias Eab.{BundleProbe, Candidates, Fixtures, Grader, Inventory, Provenance, Sandbox, Store, TaskContract}

  def ms_since(t0), do: System.monotonic_time(:millisecond) - t0

  def free_bytes do
    case System.cmd("df", ["-B1", "--output=avail", "/data"], stderr_to_stdout: true) do
      {text, 0} -> text |> String.split("\n", trim: true) |> List.last() |> String.trim() |> String.to_integer()
      _ -> nil
    end
  rescue
    _ -> nil
  end

  def snippet(nil), do: nil

  def snippet(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&(&1 =~ ~r/(\*\* \(|error:|== Compilation error|could not compile)/i))
    |> Enum.take(4)
    |> Enum.join(" | ")
    |> String.slice(0, 600)
  end

  def summary(nil), do: nil

  def summary(result) do
    states = result["test_results"] || %{}
    phases = result["failure_phases"] || %{}
    failed = for {name, "failed"} <- states, do: name
    body = Enum.count(failed, &(phases[&1] == "test"))
    setup = Enum.count(failed, &(phases[&1] == "setup"))

    %{
      "completed" => result["completed"],
      "passed" => result["passed"],
      "returncode" => result["returncode"],
      "counts" => states |> Map.values() |> Enum.frequencies(),
      "failed_in_body" => body,
      "failed_in_setup" => setup,
      "failed_other" => length(failed) - body - setup,
      "error" => result["error"],
      "not_finished" => if(result["completed"] != true, do: snippet(result["output"]))
    }
  end

  def hidden(id, run_id, patch) do
    BundleProbe.hidden_run(id, run_id, patch)
  rescue
    error -> %{"completed" => false, "error" => Exception.message(error), "test_results" => %{}}
  end

  def save(dir, name, result) do
    if is_map(result) and is_binary(result["output"]),
      do: File.write!(Path.join(dir, name <> ".txt"), result["output"])
  end

  def control(name, nil), do: {name, nil}

  def control(name, grade) do
    {name,
     %{
       "passed" => grade["passed"],
       "reason" => grade["reason"],
       "submission" => summary(grade["submission"]),
       "hidden" => summary(grade["hidden"]),
       "regression" => summary(grade["regression"]),
       "coverage_passed" => get_in(grade, ["regression_coverage", "passed"]),
       "changed_control_states" =>
         map_size(get_in(grade, ["hidden", "changed_control_states"]) || %{}) +
           map_size(get_in(grade, ["regression", "changed_control_states"]) || %{})
     }}
  end

  # Which check of README section 4 the controls fail first (4/5: the unchanged project, 6: the reference,
  # 7: the early exit, 8: the partial fix).
  def first_failure(contract, controls) do
    empty = controls["empty_patch"] || %{}
    gold = controls["reference_patch"] || %{}
    bypass = controls["early_exit"] || %{}
    partial = controls["partial_repair"]
    failures = Grader.behavioral_failures(empty["hidden"] || %{})

    cond do
      get_in(empty, ["hidden", "completed"]) != true -> "unchanged_project_did_not_finish"
      empty["passed"] -> "unchanged_project_passes"
      failures == [] -> "unchanged_project_no_body_failure"
      Enum.sort(failures) != Enum.sort(contract["starting_failures"]) -> "starting_failures_differ"
      gold["passed"] != true -> "reference_" <> reference_part(gold)
      bypass["passed"] == true -> "early_exit_accepted"
      not is_boolean(get_in(bypass, ["hidden", "completed"])) -> "early_exit_not_run"
      contract["partial"] and not partial_rejected?(contract, partial) -> "partial_fix_accepted"
      true -> "grader_identity"
    end
  end

  defp reference_part(gold) do
    cond do
      get_in(gold, ["submission", "passed"]) != true -> "existing_tests_fail"
      get_in(gold, ["hidden", "passed"]) != true -> "hidden_tests_fail"
      get_in(gold, ["regression", "passed"]) != true -> "regression_fails"
      get_in(gold, ["regression_coverage", "passed"]) != true -> "no_test_fails_first"
      true -> gold["reason"] || "fails"
    end
  end

  defp partial_rejected?(contract, %{} = partial) do
    failures = Grader.behavioral_failures(partial["hidden"] || %{})

    get_in(partial, ["hidden", "completed"]) == true and
      Enum.any?(failures, &(&1 in contract["starting_failures"]))
  end

  defp partial_rejected?(_, _), do: false

  def changes(first, second) do
    a = first["test_results"] || %{}
    b = second["test_results"] || %{}

    for name <- Enum.uniq(Map.keys(a) ++ Map.keys(b)), a[name] != b[name] do
      "#{name}: #{a[name] || "-"} -> #{b[name] || "-"}"
    end
  end

  def second_round(id, files, run_id, controls) do
    Inventory.with_case(id, files, fn ->
      reference = Inventory.file(id, "reference.patch") <> Inventory.file(id, "reference-tests.patch")
      empty = Grader.grade(id, "", run_id, coverage: false)
      gold = Grader.grade(id, reference, run_id)

      changed =
        for {label, now, before} <- [
              {"empty", empty, controls["empty_patch"]},
              {"reference", gold, controls["reference_patch"]}
            ],
            part <- ~w(submission hidden regression),
            change <- changes(before[part] || %{}, now[part] || %{}),
            do: "#{label}/#{part}: #{change}"

      hidden_changed = Enum.filter(changed, &String.contains?(&1, "/hidden: "))

      # The task's verdict: every hidden test ends as in the first round in both controls, the unchanged project
      # still fails and the reference still passes. A test of the existing suite that changes state is recorded
      # apart (`existing_changed`): it is the project's, the same for every task of the project.
      %{
        "same" => hidden_changed == [] and empty["passed"] == false and
          controls["empty_patch"]["passed"] == false and gold["passed"] == true and
          controls["reference_patch"]["passed"] == true,
        "same_all" => changed == [],
        "changed" => changed,
        "existing_changed" => changed -- hidden_changed,
        "empty_passed" => empty["passed"],
        "reference_passed" => gold["passed"]
      }
    end)
  after
    Sandbox.cleanup(run_id)
  end

  def run(id, dir, checked, out, emit) do
    task = Path.join(dir, id)
    here = Path.join(out, id)
    File.mkdir_p!(here)
    t0 = System.monotonic_time(:millisecond)
    first_reading =
      Path.join(task, "case.json") |> Inventory.read_json() |> get_in(["grading", "preservation"])

    row = %{"id" => id, "free_before" => free_bytes(), "first_reading" => first_reading}
    emit = fn msg -> emit.("#{id}: #{msg}") end
    run_id = "p5-" <> id

    row =
      try do
        steps(id, task, checked, here, run_id, emit, row)
      rescue
        error -> Map.merge(row, %{"verdict" => "error", "error" => Exception.message(error)})
      catch
        kind, value -> Map.merge(row, %{"verdict" => "error", "error" => "#{kind}: #{inspect(value)}"})
      after
        Sandbox.cleanup(run_id)
      end

    row = Map.merge(row, %{"total_ms" => ms_since(t0), "free_after" => free_bytes()})
    File.write!(Path.join(here, "row.json"), Jason.encode!(row, pretty: true))
    emit.("verdict #{row["verdict"]} #{row["dropped_at"]} #{row["reason"]} (#{row["total_ms"]} ms)")
    row
  end

  defp steps(id, task, checked, here, run_id, emit, row) do
    # 1. prepare
    t = System.monotonic_time(:millisecond)

    prepared =
      try do
        Inventory.with_case(id, task, fn ->
          :ok = Candidates.validate!(id)
          Provenance.verify(id, emit)
          Fixtures.ensure(id, emit, run_id: run_id)
        end)

        :ok
      rescue
        error -> {:error, Exception.message(error)}
      end

    row = Map.put(row, "prepare_ms", ms_since(t))

    case prepared do
      {:error, message} ->
        Map.merge(row, %{"prepared" => false, "verdict" => "dropped", "dropped_at" => "prepare",
          "reason" => "environment", "error" => String.slice(message, 0, 2000)})

      :ok ->
        row = Map.put(row, "prepared", true)
        after_prepare(id, task, checked, here, run_id, emit, row)
    end
  end

  defp after_prepare(id, task, checked, here, run_id, emit, row) do
    # 2. the diagnostic runs
    t = System.monotonic_time(:millisecond)

    {start, fixed} =
      Inventory.with_case(id, task, fn ->
        {hidden(id, run_id, ""), hidden(id, run_id, Inventory.file(id, "reference.patch"))}
      end)

    Sandbox.cleanup(run_id)
    save(here, "diag_start", start)
    save(here, "diag_reference", fixed)

    row =
      Map.merge(row, %{
        "diag_ms" => ms_since(t),
        "diag_start" => summary(start),
        "diag_reference" => summary(fixed)
      })

    # 3. the probe
    t = System.monotonic_time(:millisecond)
    probe = BundleProbe.finish(id, task, run_id, emit)
    row = Map.put(row, "probe_ms", ms_since(t))

    case probe do
      {:refused, reason, detail} ->
        Map.merge(row, %{"probe" => "refused", "verdict" => "dropped", "dropped_at" => "probe",
          "reason" => reason, "detail" => String.slice(to_string(detail), 0, 2000)})

      {:ok, names} ->
        row =
          Map.merge(row, %{
            "probe" => "ok",
            "required" => length(names["required"]),
            "starting_failures" => length(names["starting_failures"]),
            "partial_control" => names["partial_control"],
            "preservation" => names["preservation"],
            "preservation_left_out" => names["preservation_left_out"]
          })

        gate(id, task, checked, here, emit, row)
    end
  end

  defp gate(id, task, checked, here, emit, row) do
    # 4. import the rewritten folder; the gate prepares it again and runs the controls
    ref = Candidates.import(task)
    files = Store.path("candidates/#{id}/#{ref["version"]}/files")
    File.rm(Store.path("controls/#{id}.json"))
    t = System.monotonic_time(:millisecond)

    gate =
      try do
        Candidates.qualify(ref, emit)
        :ok
      rescue
        error -> {:error, Exception.message(error)}
      end

    row = Map.merge(row, %{"gate_ms" => ms_since(t), "version" => ref["version"]})
    controls = Store.read("controls/#{id}.json")
    spec = Inventory.read_json(Path.join(files, "case.json"))
    contract = TaskContract.read(spec)

    if controls,
      do: File.write!(Path.join(here, "controls.json"), Jason.encode!(controls, pretty: true))

    row =
      if controls do
        Map.put(
          row,
          "controls",
          Map.new([
            control("empty_patch", controls["empty_patch"]),
            control("reference_patch", controls["reference_patch"]),
            control("early_exit", controls["early_exit"]),
            control("partial_repair", controls["partial_repair"])
          ])
        )
      else
        row
      end

    cond do
      gate == :ok and controls["valid"] == true ->
        # 5. the second round
        t = System.monotonic_time(:millisecond)
        second = second_round(id, files, "p5r2-" <> id, controls)
        row = Map.merge(row, %{"second_round" => second, "second_ms" => ms_since(t)})

        if second["same"] do
          File.rm_rf!(Path.join(checked, id))
          File.cp_r!(files, Path.join(checked, id))
          Map.merge(row, %{"verdict" => "checked"})
        else
          Map.merge(row, %{"verdict" => "dropped", "dropped_at" => "second_round", "reason" => "unstable"})
        end

      controls == nil ->
        {:error, message} = gate
        Map.merge(row, %{"verdict" => "dropped", "dropped_at" => "gate_prepare", "reason" => "environment",
          "error" => String.slice(message, 0, 2000)})

      true ->
        Map.merge(row, %{"verdict" => "dropped", "dropped_at" => "controls",
          "reason" => first_failure(contract, controls)})
    end
  end
end

dir = System.get_env("P5_DIR", "/data/p5")
concurrency = String.to_integer(System.get_env("P5_CONCURRENCY", "2"))
out = Path.join(dir, "out")
checked = Path.join(dir, "checked")
File.mkdir_p!(checked)
{:ok, log} = File.open(Path.join(out, "gate.log"), [:append, :utf8])
emit = fn msg -> IO.puts(log, "#{DateTime.utc_now() |> DateTime.to_iso8601()} #{msg}") end
ids = File.read!(Path.join(dir, "ids.txt")) |> String.split(~r/\s+/, trim: true)

status =
  try do
    rows =
      ids
      |> Task.async_stream(&P5Gate.run(&1, Path.join(dir, "tasks"), checked, out, emit),
        max_concurrency: concurrency,
        timeout: :infinity,
        ordered: true
      )
      |> Enum.map(fn {:ok, row} -> row end)

    File.write!(Path.join(out, "gate_rows.json"), Jason.encode!(rows, pretty: true))
    "ok"
  rescue
    error ->
      emit.("ERROR " <> Exception.format(:error, error, __STACKTRACE__))
      "error"
  end

File.close(log)
File.write!(Path.join(out, "gate.done"), status <> "\n")
