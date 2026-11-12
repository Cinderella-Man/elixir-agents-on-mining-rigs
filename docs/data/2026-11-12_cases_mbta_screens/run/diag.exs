# diag.exs: evaluated inside the controller (controller.sh rpc), in a process of its own. For a dropped task whose
# hidden run "did not finish", runs the hidden tests once more as the probe does (Eab.BundleProbe.hidden_run/3: a
# fresh container of the prepared runtime, the patch, the engine's reporter, the hidden test files, the acceptance
# command) and keeps what the probe does not keep: the output and the error. For a task whose existing test files
# "did not finish", runs those files once together as the probe's first run of them does
# (Eab.BundleProbe.preservation_run/4: their starting-commit versions, `mix test <files>`). One run at a time, in the
# order given.
# DIAG_DIR: the folder for the results; DIAG_SPECS: "id:side,id:side,...", side "start" (the hidden tests on the
# unchanged project), "reference" (the hidden tests with the reference patch), "existing_start" or
# "existing_reference" (the existing test files named for the id in DIAG_FILES, a JSON object id => [file, ...], on
# the unchanged project or with the reference patch). Tasks are read from the controller's task folder
# (EAB_TASKS_DIR).
# Writes DIAG_DIR/<id>_<side>.json (completed, returncode, counts, error, ms) and .txt (the output), then
# DIAG_DIR/diag.done.
dir = System.fetch_env!("DIAG_DIR")
tasks = System.fetch_env!("EAB_TASKS_DIR")
files = System.get_env("DIAG_FILES", "{}") |> Jason.decode!()
File.mkdir_p!(dir)

specs =
  System.fetch_env!("DIAG_SPECS")
  |> String.split(",", trim: true)
  |> Enum.map(&String.split(&1, ":"))

for [id, side] <- specs do
  run_id = "diag-#{id}-#{side}"
  t0 = System.monotonic_time(:millisecond)

  result =
    Eab.Inventory.with_case(id, Path.join(tasks, id), fn ->
      patch =
        if side in ["reference", "existing_reference"],
          do: Eab.Inventory.file(id, "reference.patch"),
          else: ""

      try do
        if side in ["existing_start", "existing_reference"],
          do: Eab.BundleProbe.preservation_run(id, run_id, patch, Map.fetch!(files, id)),
          else: Eab.BundleProbe.hidden_run(id, run_id, patch)
      rescue
        error ->
          %{"completed" => false, "error" => Exception.format(:error, error, __STACKTRACE__), "test_results" => %{}}
      after
        Eab.Sandbox.cleanup(run_id)
      end
    end)

  ms = System.monotonic_time(:millisecond) - t0
  File.write!(Path.join(dir, "#{id}_#{side}.txt"), result["output"] || "")

  File.write!(
    Path.join(dir, "#{id}_#{side}.json"),
    Jason.encode!(
      %{
        "id" => id,
        "side" => side,
        "ms" => ms,
        "completed" => result["completed"],
        "returncode" => result["returncode"],
        "counts" => (result["test_results"] || %{}) |> Map.values() |> Enum.frequencies(),
        "error" => result["error"]
      },
      pretty: true
    )
  )
end

File.write!(Path.join(dir, "diag.done"), "ok\n")
