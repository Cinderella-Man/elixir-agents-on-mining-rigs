# diag.exs: evaluated inside the controller (the release's rpc), in a process of its own. The two diagnostic runs of
# the mass run's gate (docs/data/2026-11-12_maker_toolchain/run/gate.exs, step 2), which the factory's `check` does
# not make: the hidden tests on the unchanged project and on the reference, with their whole output, for tasks that
# a check job dropped without saying why. Each task is run from the job's probed copy of it.
# DIAG_JOB (the check job), DIAG_IDS (space-separated task ids), DIAG_OUT (default /data/diag).
# Writes DIAG_OUT/<id>/start.txt and reference.txt (the outputs), DIAG_OUT/<id>/summary.json, and DIAG_OUT/diag.done.
alias Eab.{BundleProbe, Inventory, Sandbox, Store}

job = System.fetch_env!("DIAG_JOB")
ids = System.fetch_env!("DIAG_IDS") |> String.split(~r/\s+/, trim: true)
out = System.get_env("DIAG_OUT", "/data/diag")
File.mkdir_p!(out)

summary = fn
  %{} = result ->
    states = result["test_results"] || %{}
    phases = result["failure_phases"] || %{}
    failed = for {name, "failed"} <- states, do: name

    %{
      "completed" => result["completed"],
      "passed" => result["passed"],
      "returncode" => result["returncode"],
      "counts" => states |> Map.values() |> Enum.frequencies(),
      "failed_in_body" => Enum.count(failed, &(phases[&1] == "test")),
      "failed_in_setup" => Enum.count(failed, &(phases[&1] == "setup")),
      "error" => result["error"]
    }

  other ->
    %{"error" => inspect(other)}
end

run = fn id, dir, run_id, patch ->
  try do
    Inventory.with_case(id, dir, fn -> BundleProbe.hidden_run(id, run_id, patch.()) end)
  rescue
    error -> %{"completed" => false, "error" => Exception.message(error), "test_results" => %{}}
  after
    Sandbox.cleanup(run_id)
  end
end

status =
  try do
    for id <- ids do
      dir = Store.path("factory/jobs/#{job}/work/#{id}")
      here = Path.join(out, id)
      File.mkdir_p!(here)
      start = run.(id, dir, "diag-#{id}", fn -> "" end)
      fixed = run.(id, dir, "diag-#{id}", fn -> File.read!(Path.join(dir, "reference.patch")) end)
      File.write!(Path.join(here, "start.txt"), start["output"] || "")
      File.write!(Path.join(here, "reference.txt"), fixed["output"] || "")

      File.write!(
        Path.join(here, "summary.json"),
        Jason.encode!(%{"start" => summary.(start), "reference" => summary.(fixed)}, pretty: true)
      )
    end

    "ok"
  rescue
    error -> "error " <> Exception.message(error)
  end

File.write!(Path.join(out, "diag.done"), status <> "\n")
