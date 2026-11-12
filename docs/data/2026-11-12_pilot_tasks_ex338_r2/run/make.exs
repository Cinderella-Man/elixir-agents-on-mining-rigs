# make.exs: evaluated inside the controller (controller.sh rpc), in a process of its own. Makes one task folder per
# pull request with the bundle maker, one after another (they share one Git cache), then runs the source check and
# the import check on every made folder (Eab.BundleMaker.verify/2).
# P5_DIR (in the controller, default /data/p5) holds numbers.txt (pull request numbers), recipe.json, holdout.json and
# tables/ (the census and screen tables of the project); REPOSITORY is the upstream address.
# Writes P5_DIR/tasks/<id>/, P5_DIR/out/make.tsv (the maker's result lines), P5_DIR/out/make_times.tsv,
# P5_DIR/out/verify.tsv, P5_DIR/out/make.log, and the marker P5_DIR/out/make.done.
dir = System.get_env("P5_DIR", "/data/p5")
repository = System.get_env("REPOSITORY", "https://github.com/axelclark/ex338")
census = System.get_env("CENSUS", "prs_axelclark__ex338.tsv")
screen = System.get_env("SCREEN", "screen_axelclark__ex338.tsv")
out = Path.join(dir, "out")
File.mkdir_p!(out)
{:ok, log} = File.open(Path.join(out, "make.log"), [:append, :utf8])
emit = fn msg -> IO.puts(log, "#{DateTime.utc_now() |> DateTime.to_iso8601()} #{msg}") end

numbers =
  File.read!(Path.join(dir, "numbers.txt"))
  |> String.split(~r/[\s,]+/, trim: true)
  |> Enum.map(&String.to_integer/1)

status =
  try do
    requests =
      Eab.BundleMaker.requests(repository, numbers,
        census: Path.join([dir, "tables", census]),
        screen: Path.join([dir, "tables", screen])
      )

    opts = [
      recipe: Path.join(dir, "recipe.json"),
      out: Path.join(dir, "tasks"),
      cache: Path.join(dir, "cache"),
      holdout: Path.join(dir, "holdout.json"),
      results: Path.join(out, "make.tsv")
    ]

    File.mkdir_p!(opts[:out])
    File.write!(Path.join(out, "make_times.tsv"), "number\tms\n")

    rows =
      for request <- requests do
        t0 = System.monotonic_time(:millisecond)
        [row] = Eab.BundleMaker.make_list([request], opts)
        ms = System.monotonic_time(:millisecond) - t0
        File.write!(Path.join(out, "make_times.tsv"), "#{request["number"]}\t#{ms}\n", [:append])
        emit.("make #{request["number"]}: #{row["result"]} #{row["reason"]} #{row["detail"]} (#{ms} ms)")
        row
      end

    made = for row <- rows, row["result"] == "made", do: row["dir"]
    File.write!(Path.join(out, "verify.tsv"), "id\tsource_check\timport\tms\n")

    for d <- made do
      t0 = System.monotonic_time(:millisecond)
      [v] = Eab.BundleMaker.verify([d], emit)
      ms = System.monotonic_time(:millisecond) - t0

      File.write!(
        Path.join(out, "verify.tsv"),
        Enum.join([v["id"], v["source_check"], v["import"], ms], "\t") <> "\n",
        [:append]
      )
    end

    "ok"
  rescue
    error ->
      emit.("ERROR " <> Exception.format(:error, error, __STACKTRACE__))
      "error"
  end

File.close(log)
File.write!(Path.join(out, "make.done"), status <> "\n")
