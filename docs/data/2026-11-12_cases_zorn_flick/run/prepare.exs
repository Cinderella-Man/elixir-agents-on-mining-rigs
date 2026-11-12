# Evaluated inside the controller (controller.sh rpc), in a process of its own, so that the rpc call returns at once.
# It does for one task folder what Eab.Candidates.qualify/3 does before the controls: the import check, the source
# pair (Eab.Provenance.verify/3), then the workspace image and the database (Eab.Fixtures.ensure/3).
# P3_DIR (in the controller): the folder with probe/<id>/; the log goes to P3_DIR/prepare.log, the marker to
# P3_DIR/prepare.done ("ok <ms>" or "error <ms>").
dir = System.get_env("P3_DIR", "/data/p3")
id = System.get_env("P3_ID", "flick-probe-pr-341")
run_id = "p3-" <> id
{:ok, log} = File.open(Path.join(dir, "prepare.log"), [:append, :utf8])
emit = fn msg -> IO.puts(log, "#{DateTime.utc_now() |> DateTime.to_iso8601()} #{msg}") end
t0 = System.monotonic_time(:millisecond)

status =
  try do
    Eab.Inventory.with_case(id, Path.join([dir, "probe", id]), fn ->
      :ok = Eab.Candidates.validate!(id)
      emit.("import check: ok")
      source = Eab.Provenance.verify(id, emit)
      emit.("source pair: " <> Jason.encode!(source))
      t1 = System.monotonic_time(:millisecond)
      runtime = Eab.Fixtures.ensure(id, emit, run_id: run_id)
      emit.("prepared in #{System.monotonic_time(:millisecond) - t1} ms")
      File.write!(Path.join(dir, "runtime.json"), Jason.encode!(runtime, pretty: true))
    end)

    "ok"
  rescue
    error ->
      emit.("ERROR " <> Exception.format(:error, error, __STACKTRACE__))
      "error"
  after
    Eab.Sandbox.cleanup(run_id)
  end

File.close(log)
File.write!(Path.join(dir, "prepare.done"), "#{status} #{System.monotonic_time(:millisecond) - t0}\n")
