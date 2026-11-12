# diag_hidden.exs: evaluated inside the controller (controller.sh rpc), in a process of its own. Runs the engine's own
# probe step (Eab.BundleProbe.hidden_run/3) for one task on its unchanged project (empty patch) or on its reference,
# and keeps what the probe throws away: the run's whole output and any exception.
# Environment: D_DIR (where to write), D_ID (the task id), D_SIDE ("reference" or "start"), D_COMMAND (optional: a test
# command run in place of the hidden tests, without them, as the probe settles the existing tests), D_TAG (optional:
# a name for the output files in place of the side).
# Writes D_DIR/<id>_<tag>.json (completed, returncode, counts, error), D_DIR/<id>_<tag>.txt (the output) and last
# D_DIR/<id>_<tag>.done.
dir = System.fetch_env!("D_DIR")
id = System.fetch_env!("D_ID")
side = System.get_env("D_SIDE", "reference")
run_id = "diag-" <> id
command = System.get_env("D_COMMAND")
base = Path.join(dir, "#{id}_#{System.get_env("D_TAG", side)}")
File.mkdir_p!(dir)

result =
  try do
    Eab.Inventory.with_case(id, Path.join(System.get_env("EAB_TASKS_DIR", "/tasks"), id), fn ->
      patch = if side == "reference", do: Eab.Inventory.file(id, "reference.patch"), else: ""
      if command do
        Eab.Sandbox.with_box(id, run_id, fn box ->
          if patch != "", do: Eab.Sandbox.apply_patch(box, patch)
          Eab.TestAdapter.install(box)
          Eab.Grader.run_tests(box, command)
        end)
      else
        Eab.BundleProbe.hidden_run(id, run_id, patch)
      end
    end)
  rescue
    error -> %{"completed" => false, "error" => Exception.format(:error, error, __STACKTRACE__), "test_results" => %{}}
  after
    Eab.Sandbox.cleanup(run_id)
  end

File.write!(base <> ".txt", result["output"] || "")

File.write!(
  base <> ".json",
  Jason.encode!(
    %{
      "completed" => result["completed"],
      "returncode" => result["returncode"],
      "passed" => result["passed"],
      "counts" => (result["test_results"] || %{}) |> Map.values() |> Enum.frequencies(),
      "error" => result["error"]
    },
    pretty: true
  )
)

File.write!(base <> ".done", "ok\n")
