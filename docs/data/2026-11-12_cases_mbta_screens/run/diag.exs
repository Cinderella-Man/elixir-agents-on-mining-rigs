# diag.exs: evaluated inside the controller (controller.sh rpc), in a process of its own. For a dropped task whose
# hidden run "did not finish", runs the hidden tests once more as the probe does (Eab.BundleProbe.hidden_run/3: a
# fresh container of the prepared runtime, the patch, the engine's reporter, the hidden test files, the acceptance
# command) and keeps what the probe does not keep: the output and the error. One run at a time, in the order given.
# DIAG_DIR: the folder for the results; DIAG_SPECS: "id:side,id:side,...", side "start" (the unchanged project) or
# "reference" (the reference patch). Tasks are read from the controller's task folder (EAB_TASKS_DIR).
# Writes DIAG_DIR/<id>_<side>.json (completed, returncode, counts, error, ms) and .txt (the output), then
# DIAG_DIR/diag.done.
dir = System.fetch_env!("DIAG_DIR")
tasks = System.fetch_env!("EAB_TASKS_DIR")
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
      patch = if side == "reference", do: Eab.Inventory.file(id, "reference.patch"), else: ""

      try do
        Eab.BundleProbe.hidden_run(id, run_id, patch)
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
