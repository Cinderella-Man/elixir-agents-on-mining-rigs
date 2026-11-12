# hidden_output.exs: evaluated inside the controller (controller.sh rpc), in a process of its own. Runs one task's
# hidden tests once, as the probe does (Eab.BundleProbe.hidden_run/3), on the reference fix (or on the unchanged
# project when HIDDEN_PATCH is "none"), and keeps the whole output, which the probe does not. The task's runtime must
# be prepared (it is, after a check that reached the probe).
# Environment (set in the controller before the call): HIDDEN_ID (the task id), HIDDEN_DIR (the task folder),
# HIDDEN_OUT (a folder), HIDDEN_PATCH ("reference", the default, or "none").
# Writes HIDDEN_OUT/<id>.txt (the output), HIDDEN_OUT/<id>.json (completed, returncode, the tests that did not pass)
# and last HIDDEN_OUT/<id>.done ("ok" or "error").
id = System.fetch_env!("HIDDEN_ID")
dir = System.fetch_env!("HIDDEN_DIR")
out = System.fetch_env!("HIDDEN_OUT")
which = System.get_env("HIDDEN_PATCH", "reference")
File.mkdir_p!(out)

status =
  try do
    result =
      Eab.Inventory.with_case(id, dir, fn ->
        patch = if which == "none", do: "", else: Eab.Inventory.file(id, "reference.patch")
        Eab.BundleProbe.hidden_run(id, "hidden-#{id}", patch)
      end)

    File.write!(Path.join(out, "#{id}.txt"), result["output"] || "")

    not_passed =
      for {name, state} <- result["test_results"] || %{}, state != "passed", into: %{}, do: {name, state}

    File.write!(
      Path.join(out, "#{id}.json"),
      Jason.encode!(
        %{
          "patch" => which,
          "completed" => result["completed"],
          "returncode" => result["returncode"],
          "tests" => map_size(result["test_results"] || %{}),
          "not_passed" => not_passed
        },
        pretty: true
      )
    )

    "ok"
  rescue
    error ->
      File.write!(Path.join(out, "#{id}.error"), Exception.format(:error, error, __STACKTRACE__))
      "error"
  after
    Eab.Sandbox.cleanup("hidden-#{id}")
  end

File.write!(Path.join(out, "#{id}.done"), status <> "\n")
