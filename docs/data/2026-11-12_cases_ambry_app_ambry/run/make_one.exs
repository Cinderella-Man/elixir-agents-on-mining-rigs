# make_one.exs: evaluated inside the controller (controller.sh rpc), in a process of its own. Makes the task folder of
# one pull request with the bundle maker, then runs the source check and the import check on it
# (Eab.BundleMaker.verify/2). It is make.exs of docs/data/2026-11-12_maker_toolchain/run/ for one number, so that each
# pull request is made, imported and checked before the next one starts.
# Environment (set in the controller before the call): P5_DIR (holds recipe.json, toolchain_images.json, holdout.json,
# tables/ and the maker's Git cache cache/), NUMBER, REPOSITORY, CENSUS and SCREEN (file names in P5_DIR/tables).
# Writes P5_DIR/tasks/<id>/ and, in P5_DIR/out/<NUMBER>/: make.tsv (the maker's result line with its header),
# verify.tsv, make.log, and last the marker make.done ("ok" or "error").
dir = System.fetch_env!("P5_DIR")
number = System.fetch_env!("NUMBER") |> String.to_integer()
repository = System.fetch_env!("REPOSITORY")
census = System.fetch_env!("CENSUS")
screen = System.fetch_env!("SCREEN")
out = Path.join([dir, "out", Integer.to_string(number)])
File.rm_rf!(out)
File.mkdir_p!(out)
{:ok, log} = File.open(Path.join(out, "make.log"), [:append, :utf8])
emit = fn msg -> IO.puts(log, "#{DateTime.utc_now() |> DateTime.to_iso8601()} #{msg}") end

status =
  try do
    [request] =
      Eab.BundleMaker.requests(repository, [number],
        census: Path.join([dir, "tables", census]),
        screen: Path.join([dir, "tables", screen])
      )

    opts = [
      recipe: Path.join(dir, "recipe.json"),
      out: Path.join(dir, "tasks"),
      cache: Path.join(dir, "cache"),
      holdout: Path.join(dir, "holdout.json"),
      toolchain_table: Path.join(dir, "toolchain_images.json"),
      results: Path.join(out, "make.tsv")
    ]

    File.mkdir_p!(opts[:out])
    t0 = System.monotonic_time(:millisecond)
    [row] = Eab.BundleMaker.make_list([request], opts)
    ms = System.monotonic_time(:millisecond) - t0
    emit.("make #{number}: #{row["result"]} #{row["reason"]} #{row["detail"]} (#{ms} ms)")
    File.write!(Path.join(out, "verify.tsv"), "id\tsource_check\timport\tmake_ms\tverify_ms\n")

    if row["result"] == "made" do
      t0 = System.monotonic_time(:millisecond)
      [v] = Eab.BundleMaker.verify([row["dir"]], emit)
      vms = System.monotonic_time(:millisecond) - t0

      File.write!(
        Path.join(out, "verify.tsv"),
        Enum.join([v["id"], v["source_check"], v["import"], ms, vms], "\t") <> "\n",
        [:append]
      )
    else
      File.write!(Path.join(out, "verify.tsv"), Enum.join([row["id"] || "-", "-", "-", ms, "-"], "\t") <> "\n", [
        :append
      ])
    end

    "ok"
  rescue
    error ->
      emit.("ERROR " <> Exception.format(:error, error, __STACKTRACE__))
      "error"
  end

File.close(log)
File.write!(Path.join(out, "make.done"), status <> "\n")
