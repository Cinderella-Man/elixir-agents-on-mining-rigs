defmodule Eab.BundleMaker do
  @moduledoc """
  The bundle maker (factory/README.md, section 3.5): one screened pull request in, one task folder in the one format
  out, or a refusal with its reason.

  It reads Git only. It finds the source pair, splits the pull request's diff by path into the reference fix, the
  hidden tests and the documentation, and writes `case.json`, `provenance.json` and the patches. It writes no
  statement. The test names and the partial fix it writes are a first reading of the diff; `Eab.BundleProbe`
  replaces them with what a run observes, once the project is prepared.
  """
  alias Eab.{Candidates, Command, Inventory, Provenance}
  alias Jason.OrderedObject, as: Ordered

  defmodule Refusal do
    defexception [:reason, :detail]
    @impl true
    def message(%{reason: reason, detail: detail}), do: "#{reason}: #{detail}"
  end

  @pair_selection "first parent of the merge commit, and the merge commit"
  @recipe_fields ~w(runtime services baseline test_timeout permitted_exclusion_tags grading)
  @recipe_grading ~w(protected_paths preservation test_suffixes)
  @test_suffixes ["_test.exs"]
  @max_walk 30
  @patch_limit 1_048_576
  @diff_limit 8_388_608
  @columns ~w(repository number id result reason start_revision walked code_files test_files docs_files
    hidden_tests task_kind partial licence recipe detail)

  @doc "The columns of a result line, in order."
  def columns, do: @columns

  @doc """
  Makes one task folder under `opts[:out]`. `request` holds `repository` (the upstream address), `number`,
  `merge_commit`, and optionally `paths` (the census's changed paths), `merged_at`, `marks` and the screen's
  `verdict` and `reason`. Options: `:recipe` (a path), `:out`, `:cache` (where fetched commits are kept),
  `:holdout` (default `config/holdout.json`), `:fetch_url` (where commits are fetched from, default the repository).
  Returns a summary map, or raises `Refusal`.
  """
  def make(request, opts) do
    recipe = read_recipe!(opts[:recipe])
    url = String.replace_suffix(request["repository"] || "", ".git", "")
    {owner, name} = repository!(url)
    holdout!(owner, name, opts[:holdout] || Inventory.path("config/holdout.json"))

    if request["verdict"] not in [nil, "candidate"],
      do: refuse!(:screen_rejected, request["reason"] || request["verdict"])

    number = request["number"]

    unless is_integer(number) and number > 0,
      do: refuse!(:invalid_request, "no pull request number")

    merge = request["merge_commit"]

    unless is_binary(merge) and Regex.match?(~r/^[a-f0-9]{40}$/, merge),
      do: refuse!(:not_in_census, "no merge commit for pull request #{number}")

    id = task_id(name, number)
    out = Path.join(opts[:out] || refuse!(:invalid_request, "no output folder"), id)
    if File.exists?(out), do: refuse!(:exists, "#{id} is already made")

    git = cache!(opts[:cache], owner, name)
    {start, walked} = source_pair!(git, opts[:fetch_url] || url, merge, request["paths"])

    for commit <- [start, merge] do
      if Regex.match?(~r/^160000 /m, git!(git, ["ls-tree", "-r", commit], 4_000_000)),
        do: refuse!(:submodule, "the source at #{commit} has a submodule")
    end

    protected = get_in(recipe, ["grading", "protected_paths"])
    split = split!(diff!(git, start, merge), protected)
    acceptance = hidden_tests(split.tests, protected)
    if acceptance == [], do: refuse!(:no_test_part, "no added or changed test file")

    names =
      split.tests
      |> Enum.filter(&(&1.path in acceptance))
      |> Enum.flat_map(fn block ->
        source = git!(git, ["show", "#{merge}:#{block.path}"], 4_194_304)
        test_names(source, if(block.status == :added, do: :all, else: changed_lines(block.text)))
      end)
      |> Enum.uniq()
      |> Enum.sort()

    if names == [], do: refuse!(:no_test_names, "no test is added or changed in a test's body")

    present =
      MapSet.new(
        git!(git, ["ls-tree", "-r", "--name-only", start, "--" | protected], 8_000_000)
        |> String.split("\n", trim: true)
      )

    existing =
      existing_tests(split.tests, split.reference, protected, &MapSet.member?(present, &1))

    if existing == [],
      do:
        refuse!(
          :no_existing_tests,
          "no existing test file is changed or matches a changed code file"
        )

    prefixes = edit_prefixes(split.reference, protected)
    reference = join(split.reference)
    variant = List.first(Eab.BundleProbe.variants(reference))

    spec =
      manifest(
        id,
        name,
        url,
        start,
        recipe,
        prefixes,
        acceptance,
        names,
        existing,
        split.reference,
        variant
      )

    provenance =
      Ordered.new([
        {"repository", url},
        {"pull_request", "#{url}/pull/#{number}"},
        {"broken_revision", start},
        {"broken_tree", tree!(git, start)},
        {"fixed_revision", merge},
        {"fixed_tree", tree!(git, merge)},
        {"pair_selection", pair_selection(walked)},
        {"licence", licence!(git, start)},
        {"merged_at", String.slice(request["merged_at"] || "", 0, 10)},
        {"marks", request["marks"] || []}
      ])

    files =
      [
        {"case.json", encode(spec)},
        {"provenance.json", encode(provenance)},
        {"reference.patch", reference},
        {"reference-tests.patch", join(split.tests)},
        {"upstream-docs.patch", join(split.docs)},
        {"integrity.patch", integrity!(prefixes, protected)},
        {"incomplete.patch", variant || ""}
      ]
      |> Enum.reject(fn {_, content} -> content == "" end)

    for {file, content} <- files,
        String.ends_with?(file, ".patch"),
        byte_size(content) > @patch_limit,
        do: refuse!(:patch_over_1_mib, "#{file} has #{byte_size(content)} bytes")

    rebuilds!(git, start, merge, [reference, join(split.tests), join(split.docs)])
    write!(out, id, files)

    %{
      "id" => id,
      "dir" => out,
      "start_revision" => start,
      "walked" => walked,
      "code_files" => length(split.reference),
      "test_files" => length(split.tests),
      "docs_files" => length(split.docs),
      "hidden_tests" => length(names),
      "task_kind" => spec["task_kind"],
      "partial" => if(variant, do: "first_variant", else: "single_hunk"),
      "licence" => provenance["licence"],
      "recipe" => if(recipe["provisional"], do: "provisional", else: "final")
    }
  end

  @doc "Makes one task and returns its result line as a map; never raises."
  def make_one(request, opts) do
    row = %{"repository" => request["repository"], "number" => request["number"]}

    try do
      summary = make(request, opts)
      Map.merge(row, Map.merge(summary, %{"result" => "made", "reason" => "-"}))
    rescue
      error in Refusal ->
        Map.merge(row, %{
          "result" => "refused",
          "reason" => to_string(error.reason),
          "detail" => error.detail
        })

      error ->
        Map.merge(row, %{
          "result" => "refused",
          "reason" => "error",
          "detail" => Exception.message(error)
        })
    end
  end

  @doc """
  Makes every request in turn, appends one result line per pull request to `opts[:results]` (a TSV file, its header
  written when the file is new), and returns the lines. One refusal never stops the list.
  """
  def make_list(requests, opts) do
    for request <- requests do
      row = make_one(request, opts)
      if opts[:results], do: append_row!(opts[:results], row)
      row
    end
  end

  @doc """
  Checks made task folders as the gate's first two steps do: the source check (`Eab.Provenance.verify/3`, which
  fetches both commits from upstream) and the import check (`Eab.Candidates.import/1`). Returns one map per folder.
  """
  def verify(dirs, emit \\ fn _ -> :ok end) do
    for dir <- dirs do
      id = Path.basename(dir)

      source =
        try do
          receipt = Inventory.with_case(id, dir, fn -> Provenance.verify(id, emit) end)
          if receipt["verified"] == true, do: "passed", else: "failed: #{inspect(receipt)}"
        rescue
          error -> "failed: " <> Exception.message(error)
        end

      import =
        try do
          ref = Candidates.import(dir)
          "accepted #{ref["version"]}"
        rescue
          error -> "refused: " <> Exception.message(error)
        end

      %{"id" => id, "source_check" => one_line(source), "import" => one_line(import)}
    end
  end

  @doc """
  The requests for `numbers` of `repository`, joined from the census table (merge commit, merge date, changed paths)
  and the screen table (verdict, reason, marks). Either table may be gzipped.
  """
  def requests(repository, numbers, census: census, screen: screen) do
    census = Map.new(read_tsv!(census), &{&1["number"], &1})
    screen = Map.new(read_tsv!(screen), &{&1["number"], &1})

    for number <- numbers do
      key = to_string(number)
      row = census[key] || %{}
      verdict = screen[key] || %{}

      marks =
        [
          {"adds_migration", verdict["adds_migration"] == "1"},
          {"touches_assets", verdict["touches_assets"] == "1"},
          {"ai_written", verdict["ai_tool"] == "1"}
        ]
        |> Enum.filter(&elem(&1, 1))
        |> Enum.map(&elem(&1, 0))

      %{
        "repository" => repository,
        "number" => number,
        "merge_commit" => row["merge_commit"],
        "merged_at" => row["merged_at"],
        "paths" => if(row["paths"], do: String.split(row["paths"], ";", trim: true)),
        "verdict" => verdict["verdict"],
        "reason" => verdict["reason"],
        "marks" => marks
      }
    end
  end

  @doc """
  The script entry point. `make` makes a list of tasks; `verify` checks made folders.

      make --repository URL --numbers 1,2 --census TSV --screen TSV --recipe JSON --out DIR --results TSV
           [--cache DIR] [--holdout JSON]
      verify --out DIR [--ids a,b] --results TSV
  """
  def main([mode | argv]) do
    {opts, _, _} =
      OptionParser.parse(argv,
        strict: [
          repository: :string,
          numbers: :string,
          census: :string,
          screen: :string,
          recipe: :string,
          out: :string,
          results: :string,
          cache: :string,
          holdout: :string,
          ids: :string
        ]
      )

    case mode do
      "make" ->
        numbers =
          opts[:numbers] |> String.split(",", trim: true) |> Enum.map(&String.to_integer/1)

        requests =
          requests(opts[:repository], numbers, census: opts[:census], screen: opts[:screen])

        rows = make_list(requests, opts)

        for row <- rows,
            do: IO.puts("#{row["number"]}\t#{row["result"]}\t#{row["reason"]}\t#{row["id"]}")

      "verify" ->
        ids =
          if opts[:ids],
            do: String.split(opts[:ids], ",", trim: true),
            else: opts[:out] |> File.ls!() |> Enum.sort()

        for row <- verify(Enum.map(ids, &Path.join(opts[:out], &1)), &IO.puts/1) do
          line = Enum.join([row["id"], row["source_check"], row["import"]], "\t")
          if opts[:results], do: File.write!(opts[:results], line <> "\n", [:append])
          IO.puts(line)
        end
    end
  end

  ## The source pair

  defp source_pair!(git, url, merge, paths) do
    expected = if is_list(paths), do: MapSet.new(paths)

    found =
      Enum.reduce_while(1..@max_walk, nil, fn back, _ ->
        fetch!(git, url, merge, back)

        case rev(git, "#{merge}~#{back}") do
          nil ->
            {:halt, nil}

          start ->
            names = git!(git, ["diff", "--name-only", "-z", "-M", start, merge], @diff_limit)
            changed = names |> String.split("\0", trim: true) |> MapSet.new()

            if is_nil(expected) or changed == expected,
              do: {:halt, {start, back - 1}},
              else: {:cont, nil}
        end
      end)

    found ||
      refuse!(
        :paths_never_match,
        "no first parent within #{@max_walk} commits of #{merge} changes the census's paths"
      )
  end

  # Fetches `merge` deep enough that its `back`-th first parent exists, unless it is already here.
  defp fetch!(git, url, merge, back) do
    unless rev(git, "#{merge}~#{back}") do
      result =
        Command.run("git", ["fetch", "--quiet", "--depth=#{back + 1}", url, merge],
          cd: git,
          quiet: true,
          timeout: 600
        )

      if result["returncode"] != 0 and back == 1,
        do: refuse!(:fetch_failed, one_line(result["output"]))
    end
  end

  defp rev(git, ref) do
    result =
      Command.run("git", ["rev-parse", "--verify", "--quiet", ref <> "^{commit}"],
        cd: git,
        quiet: true
      )

    if result["returncode"] == 0, do: String.trim(result["output"])
  end

  defp tree!(git, commit), do: String.trim(git!(git, ["rev-parse", commit <> "^{tree}"]))

  defp pair_selection(0), do: @pair_selection

  defp pair_selection(walked),
    do: "the commit #{walked + 1} first parents before the merge commit, and the merge commit"

  defp cache!(nil, _owner, _name), do: refuse!(:invalid_request, "no cache folder")

  defp cache!(root, owner, name) do
    git = Path.join(Path.expand(root), "#{owner}__#{name}.git")

    unless File.dir?(git) do
      File.mkdir_p!(git)
      git!(git, ["init", "--quiet", "--bare"])
    end

    git
  end

  defp diff!(git, start, merge) do
    git!(
      git,
      ~w(-c core.quotepath=false diff --binary --full-index --no-renames --no-color --no-ext-diff
        --src-prefix=a/ --dst-prefix=b/) ++ [start, merge],
      @diff_limit
    )
  end

  # The three patches applied to the starting tree must give the merged tree: the same check as the engine's
  # source check, on the local copy, so that a bad split is refused before anything is written.
  defp rebuilds!(git, start, merge, patches) do
    root = Path.join(System.tmp_dir!(), "eab-bundle-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    index = "GIT_INDEX_FILE=" <> Path.join(root, "index")

    try do
      Command.run!("env", [index, "git", "--git-dir", git, "read-tree", start], quiet: true)

      for {patch, n} <- Enum.with_index(patches), patch != "" do
        file = Path.join(root, "#{n}.patch")
        File.write!(file, patch)

        result =
          Command.run(
            "env",
            [index, "git", "--git-dir", git, "apply", "--cached", "--whitespace=nowarn", file],
            quiet: true
          )

        if result["returncode"] != 0, do: refuse!(:does_not_apply, one_line(result["output"]))
      end

      rebuilt = Command.run!("env", [index, "git", "--git-dir", git, "write-tree"], quiet: true)

      unless String.trim(rebuilt) == tree!(git, merge),
        do: refuse!(:does_not_rebuild, "the patches do not give the merged tree")
    after
      File.rm_rf!(root)
    end
  end

  ## The split

  @doc """
  Splits a diff (no renames) by path. Paths under the test folders are the hidden tests; `.md` and `.txt` files
  whose top folder the code part does not touch are the documentation; everything else is the reference fix,
  CI files, assets and lock files included, because the source check needs every changed path in one of the three.
  Refuses a symbolic link, a submodule, a binary file and a path Git or the engine cannot write plainly.
  """
  def split!(diff, protected) do
    blocks = diff |> String.split(~r/^(?=diff --git )/m) |> Enum.filter(&(&1 =~ ~r/^diff --git /))
    if blocks == [], do: refuse!(:empty_diff, "the pull request changes nothing")
    blocks = Enum.map(blocks, &block!/1)
    {tests, rest} = Enum.split_with(blocks, &under?(&1.path, protected))
    docs? = &(Path.extname(&1.path) in [".md", ".txt"])
    code_tops = rest |> Enum.reject(docs?) |> Enum.map(&top(&1.path)) |> MapSet.new()
    {docs, reference} = Enum.split_with(rest, &(docs?.(&1) and top(&1.path) not in code_tops))
    if reference == [], do: refuse!(:no_code_part, "nothing changes outside the tests and docs")
    %{reference: reference, tests: tests, docs: docs}
  end

  defp block!(text) do
    [header | _] = String.split(text, "\n", parts: 2)

    path =
      case String.split(String.replace_prefix(header, "diff --git ", ""), " ") do
        ["a/" <> a, "b/" <> b] when a == b -> a
        _ -> refuse!(:unsupported_path, one_line(header))
      end

    unless Regex.match?(~r{^[A-Za-z0-9_@+=,.%/-]+$}u, path) and
             not Enum.any?(Path.split(path), &(&1 in [".", "..", ".git"])),
           do: refuse!(:unsupported_path, path)

    cond do
      Regex.match?(~r/^(new file mode|deleted file mode|old mode|new mode) 120000$/m, text) or
          Regex.match?(~r/^index \S+ 120000$/m, text) ->
        refuse!(:symbolic_link, path)

      Regex.match?(~r/^(new file mode|deleted file mode|old mode|new mode) 160000$/m, text) or
          Regex.match?(~r/^index \S+ 160000$/m, text) ->
        refuse!(:submodule, path)

      Regex.match?(~r/^(GIT binary patch|Binary files )/m, text) ->
        refuse!(:binary_file, path)

      true ->
        :ok
    end

    status =
      cond do
        Regex.match?(~r/^new file mode /m, text) -> :added
        Regex.match?(~r/^deleted file mode /m, text) -> :deleted
        true -> :modified
      end

    %{path: path, status: status, text: text}
  end

  defp under?(path, prefixes), do: Enum.any?(prefixes, &String.starts_with?(path, &1))

  defp top(path) do
    case String.split(path, "/", parts: 2) do
      [file] -> file
      [folder, _] -> folder <> "/"
    end
  end

  defp join(blocks), do: Enum.map_join(blocks, & &1.text)

  # The top-level folders (and root files) the code part touches, and the test folders, where the model writes its
  # own test.
  defp edit_prefixes(reference, protected),
    do: (Enum.map(reference, &top(&1.path)) ++ protected) |> Enum.uniq() |> Enum.sort()

  defp hidden_tests(tests, protected) do
    contract = %{"protected_paths" => protected, "test_suffixes" => @test_suffixes}

    tests
    |> Enum.filter(&(&1.status != :deleted and Eab.TaskContract.test_file?(contract, &1.path)))
    |> Enum.map(& &1.path)
    |> Enum.sort()
  end

  @doc """
  The existing test files a task's command names, before the probe settles them (README section 3.5): the test files
  present at the starting commit that the pull request's tests change or delete, and those that match a code file
  the pull request changes by path (`lib/<path>/<name>.ex` gives `<test folder><path>/<name>_test.exs`). `present?`
  says whether a path exists at the starting commit. Sorted, without repeats.
  """
  def existing_tests(tests, reference, protected, present?) do
    contract = %{"protected_paths" => protected, "test_suffixes" => @test_suffixes}

    changed =
      for block <- tests,
          block.status != :added,
          Eab.TaskContract.test_file?(contract, block.path),
          do: block.path

    matched =
      for block <- reference,
          path <- [test_path(block.path, protected)],
          path != nil and present?.(path),
          do: path

    (changed ++ matched) |> Enum.uniq() |> Enum.sort()
  end

  @doc "The test file that matches a code file by path, or nil: `lib/a/b.ex` gives `test/a/b_test.exs`."
  def test_path("lib/" <> rest, [folder | _]) do
    if String.ends_with?(rest, ".ex"),
      do: folder <> String.replace_suffix(rest, ".ex", "_test.exs")
  end

  def test_path(_path, _protected), do: nil

  # The early-exit control: one new file that stops the VM, in `lib/` when the task may edit it, else in the first
  # folder it may edit outside the tests.
  defp integrity!(prefixes, protected) do
    folder =
      if "lib/" in prefixes,
        do: "lib/",
        else: Enum.find(prefixes, &(String.ends_with?(&1, "/") and &1 not in protected))

    folder || refuse!(:no_folder_for_early_exit, "the code part touches only root files")
    file = folder <> "eab_halt.ex"

    "diff --git a/#{file} b/#{file}\nnew file mode 100644\n--- /dev/null\n+++ b/#{file}\n@@ -0,0 +1 @@\n+System.halt(0)\n"
  end

  ## Test names

  @doc """
  The post-image line numbers a diff block adds or changes; a removed line marks the line that follows it.
  """
  def changed_lines(text) do
    text
    |> String.split("\n")
    |> Enum.reduce({nil, MapSet.new()}, fn
      "@@ " <> rest, {_, lines} ->
        [_, first] = Regex.run(~r/\+(\d+)/, rest)
        {String.to_integer(first), lines}

      _, {nil, lines} ->
        {nil, lines}

      "+" <> _, {n, lines} ->
        {n + 1, MapSet.put(lines, n)}

      "-" <> _, {n, lines} ->
        {n, MapSet.put(lines, n)}

      "\\" <> _, state ->
        state

      _, {n, lines} ->
        {n + 1, lines}
    end)
    |> elem(1)
  end

  @doc """
  The names the engine's test reporter gives (`Elixir.Module::test describe name`) to the tests of an ExUnit file
  whose body holds a changed line, or all of them for `:all`. Only tests with a literal name and a `do` block count.
  """
  def test_names(source, changed \\ :all) do
    case Code.string_to_quoted(source, token_metadata: true, columns: false, emit_warnings: false) do
      {:ok, ast} ->
        ast
        |> walk(nil, nil)
        |> Enum.filter(fn {_, first, last} ->
          changed == :all or Enum.any?(first..last//1, &MapSet.member?(changed, &1))
        end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.uniq()

      _ ->
        []
    end
  end

  defp walk({:defmodule, _, [{:__aliases__, _, parts}, [{:do, body}]]}, parent, _)
       when is_list(parts) do
    if Enum.all?(parts, &is_atom/1),
      do: walk(body, Module.concat(List.wrap(parent) ++ parts), nil),
      else: []
  end

  defp walk({:describe, _, [name, [{:do, body}]]}, module, nil) when is_binary(name),
    do: walk(body, module, name)

  defp walk({kind, meta, [name | rest]}, module, describe)
       when kind in [:test, :property] and is_binary(name) and not is_nil(module) do
    case List.last(rest) do
      [{:do, _} | _] ->
        label = if describe, do: "#{describe} #{name}", else: name
        first = meta[:line] || 0
        [{"#{module}::#{kind} #{label}", first, get_in(meta, [:end, :line]) || first}]

      _ ->
        []
    end
  end

  defp walk({left, right}, module, describe),
    do: walk(left, module, describe) ++ walk(right, module, describe)

  defp walk(list, module, describe) when is_list(list),
    do: Enum.flat_map(list, &walk(&1, module, describe))

  defp walk({_, _, args}, module, describe) when is_list(args),
    do: Enum.flat_map(args, &walk(&1, module, describe))

  defp walk(_, _, _), do: []

  ## The manifest

  defp manifest(
         id,
         name,
         url,
         start,
         recipe,
         prefixes,
         acceptance,
         names,
         existing,
         reference,
         variant
       ) do
    grading = recipe["grading"]

    optional =
      for key <- ~w(services baseline test_timeout permitted_exclusion_tags),
          Map.has_key?(recipe, key),
          do: {key, recipe[key]}

    Ordered.new(
      [
        {"id", id},
        {"schema_version", 3},
        {"task_kind", task_kind(reference)},
        {"project", name},
        {"repository", Ordered.new([{"url", url}, {"revision", start}])},
        {"runtime", recipe["runtime"]}
      ] ++
        optional ++
        [
          {"allowed_edit_prefixes", prefixes},
          {"acceptance_patch", "reference-tests.patch"},
          {"grading",
           Ordered.new([
             {"adapter", "exunit"},
             {"acceptance", Enum.join(["mix", "test" | acceptance], " ")},
             {"preservation", Enum.join(["mix", "test" | existing], " ")},
             {"protected_paths", grading["protected_paths"]},
             {"test_suffixes", @test_suffixes},
             {"required", names},
             {"starting_failures", names},
             {"model_tests", "behavioral"}
           ])},
          {"partial_control",
           if(variant,
             do: Ordered.new([{"present", true}]),
             else: Ordered.new([{"present", false}, {"reason", "single_hunk"}])
           )}
        ]
    )
  end

  @doc """
  The provisional rule for the task's kind (README section 8 leaves the rule open): `feature` when the reference
  adds a file or a public function it does not also remove, else `bug_fix`.
  """
  def task_kind(reference) do
    defs = fn sign ->
      Enum.flat_map(reference, fn block ->
        Regex.scan(~r/^#{sign}\s*def\s+([a-z_][A-Za-z0-9_?!]*)/m, block.text,
          capture: :all_but_first
        )
      end)
      |> List.flatten()
    end

    if Enum.any?(reference, &(&1.status == :added)) or defs.("\\+") -- defs.("-") != [],
      do: "feature",
      else: "bug_fix"
  end

  defp task_id(name, number) do
    slug = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
    "#{slug}-pr-#{number}"
  end

  ## The recipe, the hold-out list, the licence

  @doc """
  Reads a project's recipe (`factory/recipes/<owner>__<repo>.json`): exactly the per-project fields of `case.json`
  (`runtime`, `services`, `baseline`, `test_timeout`, `permitted_exclusion_tags`, and `grading.protected_paths` and
  `grading.preservation`, the project's whole-suite command for its own check, which a task never carries;
  `grading.test_suffixes` may be there, and then is the fixed `["_test.exs"]`). A recipe that is not final yet
  carries one more field, `provisional`, a note that the maker never copies.
  """
  def read_recipe!(nil), do: refuse!(:recipe, "no recipe given")

  def read_recipe!(path) do
    recipe =
      case File.read(path) do
        {:ok, text} -> Jason.decode!(text)
        {:error, reason} -> refuse!(:recipe, "#{path}: #{reason}")
      end

    extra = Map.keys(recipe) -- ["provisional" | @recipe_fields]
    grading = recipe["grading"] || %{}
    runtime = recipe["runtime"] || %{}

    unless extra == [] and is_map(grading) and Map.keys(grading) -- @recipe_grading == [] and
             runtime["profile"] == "mix" and is_binary(runtime["image"]) and
             runtime["image"] != "" and is_list(grading["protected_paths"]) and
             grading["protected_paths"] != [] and
             Enum.all?(
               grading["protected_paths"],
               &(is_binary(&1) and String.ends_with?(&1, "/"))
             ) and
             Enum.take(OptionParser.split(grading["preservation"] || ""), 2) == ["mix", "test"] and
             (grading["test_suffixes"] || @test_suffixes) == @test_suffixes,
           do: refuse!(:recipe, "#{path} does not hold exactly the per-project fields")

    recipe
  end

  defp repository!(url) do
    case Regex.run(~r{^https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$}, url) do
      [_, owner, name] -> {owner, name}
      _ -> refuse!(:invalid_request, "not a GitHub repository address: #{url}")
    end
  end

  @doc "Refuses a repository of the bench's 12 projects, of their organisations, or named as one of them."
  def holdout!(owner, name, path) do
    list = Jason.decode!(File.read!(path))
    down = &String.downcase/1
    repository = down.("#{owner}/#{name}")

    held =
      down.(owner) in Enum.map(list["organisations"], down) or
        repository in Enum.map(list["repositories"], down) or
        repository in Enum.map(list["projects"], &down.(&1["repository"])) or
        down.(name) in Enum.map(list["names"], down)

    if held, do: refuse!(:holdout, "#{owner}/#{name} is on the bench's hold-out list")
    :ok
  end

  defp licence!(git, commit) do
    file =
      git!(git, ["ls-tree", "--name-only", commit])
      |> String.split("\n", trim: true)
      |> Enum.find(&Regex.match?(~r/^(LICEN[CS]E|COPYING)(\.md|\.txt)?$/i, &1))

    if file, do: spdx(git!(git, ["show", "#{commit}:#{file}"], 1_000_000)), else: "NOASSERTION"
  end

  @doc "A first reading of a licence text as an SPDX id; the licence scan (E51) has the last word."
  def spdx(text) do
    cond do
      text =~ ~r/Permission is hereby granted, free of charge/ ->
        "MIT"

      text =~ ~r/Apache License/ and text =~ ~r/Version 2\.0/ ->
        "Apache-2.0"

      text =~ ~r/Mozilla Public License,? [Vv]ersion 2\.0/ ->
        "MPL-2.0"

      text =~ ~r/Permission to use, copy, modify, and\/or distribute/ ->
        "ISC"

      text =~ ~r/Redistribution and use in source and binary forms/ and
          text =~ ~r/Neither the name/ ->
        "BSD-3-Clause"

      text =~ ~r/Redistribution and use in source and binary forms/ ->
        "BSD-2-Clause"

      true ->
        "NOASSERTION"
    end
  end

  ## Files

  defp write!(out, id, files) do
    temp = out <> ".#{System.unique_integer([:positive])}.tmp"
    File.mkdir_p!(temp)

    try do
      for {file, content} <- files, do: File.write!(Path.join(temp, file), content)

      try do
        Inventory.with_case(id, temp, fn -> Candidates.validate!(id) end)
      rescue
        error -> refuse!(:import_check, Exception.message(error))
      end

      File.rename!(temp, out)
    after
      File.rm_rf!(temp)
    end
  end

  defp encode(value), do: Jason.encode!(value, pretty: true) <> "\n"

  defp append_row!(path, row) do
    unless File.exists?(path), do: File.write!(path, Enum.join(@columns, "\t") <> "\n")
    line = Enum.map_join(@columns, "\t", &one_line(to_string(Map.get(row, &1, "-"))))
    File.write!(path, line <> "\n", [:append])
  end

  defp read_tsv!(path) do
    data = File.read!(path)
    data = if String.ends_with?(path, ".gz"), do: :zlib.gunzip(data), else: data
    [header | rows] = String.split(data, "\n", trim: true)
    keys = String.split(header, "\t")
    Enum.map(rows, &(keys |> Enum.zip(String.split(&1, "\t")) |> Map.new()))
  end

  defp git!(git, args, limit \\ 200_000) do
    result = Command.run("git", args, cd: git, quiet: true, limit: limit, timeout: 600)

    cond do
      result["returncode"] != 0 -> raise "git #{hd(args)} failed: #{one_line(result["output"])}"
      result["output_truncated"] -> refuse!(:output_over_limit, "git output over #{limit} bytes")
      true -> result["output"]
    end
  end

  defp one_line(text) do
    text = text |> String.replace(~r/\s+/, " ") |> String.trim()
    if String.length(text) > 300, do: String.slice(text, 0, 300) <> "...", else: text
  end

  @doc false
  def refuse!(reason, detail), do: raise(Refusal, reason: reason, detail: detail)
end
