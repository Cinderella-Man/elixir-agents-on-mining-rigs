# resolve.exs: evaluated inside the controller (controller.sh rpc), in a process of its own. For every pull request
# in P5_DIR/numbers.txt: the source pair (the same as the maker's) and the toolchain resolver on the starting commit,
# without making a task (Eab.BundleMaker.resolve_list/2).
# P5_DIR holds numbers.txt, recipe.json (the template), toolchain_images.json and tables/ (census and screen);
# REPOSITORY, CENSUS and SCREEN name the upstream and the two tables. Writes P5_DIR/out/resolve.tsv and the marker
# P5_DIR/out/resolve.done.
dir = System.get_env("P5_DIR", "/data/p5")
repository = System.get_env("REPOSITORY")
census = System.get_env("CENSUS")
screen = System.get_env("SCREEN")
out = Path.join(dir, "out")
File.mkdir_p!(out)

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

    results = Path.join(out, "resolve.tsv")
    File.rm(results)

    Eab.BundleMaker.resolve_list(requests,
      recipe: Path.join(dir, "recipe.json"),
      cache: Path.join(dir, "cache"),
      toolchain_table: Path.join(dir, "toolchain_images.json"),
      results: results
    )

    "ok"
  rescue
    error -> "error " <> Exception.format(:error, error, __STACKTRACE__)
  end

File.write!(Path.join(out, "resolve.done"), status <> "\n")
