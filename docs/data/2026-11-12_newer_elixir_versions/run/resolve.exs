# resolve.exs: what the factory's toolchain resolver (Eab.Toolchain) reads and picks at each starting commit of a
# list, from the commit's own files in a local clone: the root files and .github/workflows/, as the bundle maker
# reads them. Run with `mix run --no-start` in the factory folder.
# Environment: LIST (TSV: repo, number, commit; "#" lines are skipped), CLONES (a folder of clones named
# <owner>__<repo>.git), TABLE (an image table). Prints TSV: repo, number, commit, elixir, its source, otp, its source,
# the image outcome (ok:<elixir>/<otp> of the table's line, no_image:<elixir>/<otp>, or default when no file names
# Elixir) and how the line matched (exact, prefix, -).
alias Eab.Toolchain

table = Toolchain.read_table!(System.fetch_env!("TABLE"))
clones = System.fetch_env!("CLONES")
recipe = %{"runtime" => %{"image" => nil}, "services" => %{}, "baseline" => nil}

git = fn dir, args ->
  case System.cmd("git", ["-C", dir | args], stderr_to_stdout: true) do
    {out, 0} -> {:ok, out}
    _ -> :error
  end
end

value = fn
  nil -> {"-", "-"}
  %{value: v, source: s} -> {v, s}
end

System.fetch_env!("LIST")
|> File.stream!()
|> Stream.map(&String.trim_trailing(&1, "\n"))
|> Stream.reject(&(&1 == "" or String.starts_with?(&1, "#")))
|> Enum.each(fn line ->
  [repo, number, commit | _] = String.split(line, "\t")
  dir = Path.join(clones, String.replace(repo, "/", "__") <> ".git")

  listing =
    for args <- [["ls-tree", "--name-only", commit], ["ls-tree", "--name-only", commit, ".github/workflows/"]],
        {:ok, out} <- [git.(dir, args)],
        into: "",
        do: out

  paths = listing |> String.split("\n", trim: true) |> Toolchain.wanted()

  files =
    for path <- paths, {:ok, text} <- [git.(dir, ["show", "#{commit}:#{path}"])], into: %{}, do: {path, text}

  {elixir, otp} = Toolchain.versions(files)

  record =
    case Toolchain.resolve(files, recipe, table) do
      {:ok, resolved} -> resolved["record"]
      {:refused, _first, _detail, record} -> record
    end
    |> Jason.encode!()
    |> Jason.decode!()

  source = record["image"]["source"]

  {outcome, how} =
    cond do
      record["image"]["value"] == nil ->
        {"no_image:#{elem(value.(elixir), 0)}/#{elem(value.(otp), 0)}", "-"}

      match = Regex.run(~r/^config\/toolchain_images\.json: (\S+)/, source) ->
        {"ok:" <> Enum.at(match, 1), if(source =~ "by prefix", do: "prefix", else: "exact")}

      true ->
        {"default", "-"}
    end

  {e, es} = value.(elixir)
  {o, os} = value.(otp)
  IO.puts(Enum.join([repo, number, commit, e, es, o, os, outcome, how], "\t"))
end)
