# The statement writer and its leak check (factory/README.md, section 3.4; the design note, section 5, job P7).
# Standard library only, so it runs with `elixir -r statement.ex <script>` in the factory's tooling image.
# README.md in this folder gives the method, the leak rule and how to run it.

defmodule Statements.Diff do
  @moduledoc """
  Reads a unified diff in Git's format into one map per file: `old` and `new` (paths, `nil` for `/dev/null`),
  `added` and `removed` (the lines without their first character).
  """

  def parse(text) do
    text
    |> String.split("\n")
    |> Enum.reduce({[], nil, :header}, &line/2)
    |> then(fn {files, current, _} -> Enum.reverse(push(files, current)) end)
    |> Enum.map(fn file ->
      %{file | added: Enum.reverse(file.added), removed: Enum.reverse(file.removed)}
    end)
  end

  defp line("diff --git a/" <> rest, {files, current, _}) do
    {old, new} =
      case String.split(rest, " b/", parts: 2) do
        [old, new] -> {old, new}
        [old] -> {old, old}
      end

    {push(files, current), %{old: old, new: new, added: [], removed: []}, :header}
  end

  defp line(_, {files, nil, state}), do: {files, nil, state}

  defp line("--- /dev/null", {files, current, :header}),
    do: {files, %{current | old: nil}, :header}

  defp line("+++ /dev/null", {files, current, :header}),
    do: {files, %{current | new: nil}, :header}

  defp line("@@" <> _, {files, current, _}), do: {files, current, :hunk}

  defp line("+" <> added, {files, current, :hunk}),
    do: {files, %{current | added: [added | current.added]}, :hunk}

  defp line("-" <> gone, {files, current, :hunk}),
    do: {files, %{current | removed: [gone | current.removed]}, :hunk}

  defp line(_, acc), do: acc

  defp push(files, nil), do: files
  defp push(files, current), do: [current | files]

  def added_lines(files), do: Enum.flat_map(files, & &1.added)

  def paths(files),
    do: files |> Enum.flat_map(&[&1.old, &1.new]) |> Enum.reject(&is_nil/1) |> Enum.uniq()
end

defmodule Statements.Task do
  @moduledoc "The parts of one task folder (factory/README.md, section 3) that the writer and the leak check read."

  def read!(dir) do
    case_json = JSON.decode!(File.read!(Path.join(dir, "case.json")))
    provenance = JSON.decode!(File.read!(Path.join(dir, "provenance.json")))
    fix = File.read!(Path.join(dir, "reference.patch"))
    tests = File.read!(Path.join(dir, "reference-tests.patch"))

    %{
      id: case_json["id"],
      dir: dir,
      kind: case_json["task_kind"],
      repository: case_json["repository"]["url"],
      start: case_json["repository"]["revision"],
      merge: provenance["fixed_revision"],
      pull_request: provenance["pull_request"],
      preservation: case_json["grading"]["preservation"],
      requirements: case_json["grading"]["requirements"] || [],
      fix_text: fix,
      tests_text: tests,
      fix: Statements.Diff.parse(fix),
      tests: Statements.Diff.parse(tests)
    }
  end

  @doc """
  The engine's own instruction text for the task, as `Eab.TaskContract.instructions/1` builds it: the solver reads it
  beside the statement.
  """
  def engine_text(task) do
    "Complete the #{task.kind} task in /workspace. Investigate the source and run the relevant tests.\n" <>
      "Test command: #{task.preservation}.\n" <>
      "Add or change a test that fails in its test body on the starting source and passes after your change. " <>
      "Compilation/setup failures do not count.\n" <>
      Enum.map_join(task.requirements, "\n", &"Required outcome (#{&1["id"]}): #{&1["text"]}")
  end

  @doc "Every line of every text file in the starting commit's tree, read from a Git clone that holds the commit."
  def tree_lines!(clone, revision) do
    {out, 0} =
      System.cmd("git", [
        "-c",
        "safe.directory=*",
        "-C",
        clone,
        "grep",
        "-h",
        "-I",
        "-e",
        "",
        revision
      ])

    String.split(out, "\n")
  end
end

defmodule Statements.Leak do
  @moduledoc """
  The leak check (README.md in this folder, "The leak rule"): a statement fails when it contains any of
  - L1 a line the fix adds that exists nowhere in the starting tree nor in the hidden tests (20 or more non-blank
    characters, compared with runs of white space made one space);
  - L2 an identifier the fix adds that exists nowhere in the starting tree nor in the hidden tests' added lines: a
    code-like one (with `_`, an inner capital, or ending in `?` or `!`) or a dotted module name anywhere; any other
    one of 3 or more characters only in code form (in backticks, before `(` or `/<arity>`, or after a `.`);
  - L3 the name of a test or `describe` block that the hidden tests add (3 or more words, compared without case and
    with runs of white space made one space), or a module the hidden tests add;
  - L4 the path or the file name of a hidden test file, unless the engine's test command names it;
  - L5 the path or the file name of a file the fix adds, changes or deletes;
  - L6 the pull request's number (`#N`, `pull/N`, `PR N`, `pull request N`) or a prefix of 7 or more hex digits of the
    starting or merge commit.
  """

  @word ~r/[A-Za-z_][A-Za-z0-9_]*[?!]?/
  @dotted ~r/\b[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)+/
  @test_name ~r/^\s*(?:test|describe|property)\s+"((?:[^"\\]|\\.)*)"/
  @test_module ~r/^\s*defmodule\s+([A-Z][A-Za-z0-9_.]*)\s+do/

  def rule_version, do: "statements-leak-v1"

  @doc "The fix-only items of one task, computed once and checked against every statement written for it."
  def items(task, tree_lines) do
    tree_set = MapSet.new(tree_lines, &norm/1)
    tree_words = words(tree_lines)
    tree_dotted = dotted(tree_lines)

    test_added = Statements.Diff.added_lines(task.tests)
    test_set = MapSet.new(test_added, &norm/1)
    test_words = words(test_added)
    test_dotted = dotted(test_added)

    fix_added = Statements.Diff.added_lines(task.fix)

    lines =
      fix_added
      |> Enum.map(&norm/1)
      |> Enum.filter(&(String.length(String.replace(&1, " ", "")) >= 20))
      |> Enum.reject(&(MapSet.member?(tree_set, &1) or MapSet.member?(test_set, &1)))
      |> Enum.uniq()

    fix_only =
      fix_added |> words() |> MapSet.difference(tree_words) |> MapSet.difference(test_words)

    {code_like, plain} = Enum.split_with(fix_only, &code_like?/1)

    dotted_only =
      fix_added |> dotted() |> MapSet.difference(tree_dotted) |> MapSet.difference(test_dotted)

    test_names =
      test_added
      |> Enum.flat_map(fn line ->
        case Regex.run(@test_name, line) do
          [_, name] -> [name |> String.replace("\\\"", "\"") |> String.downcase() |> norm()]
          _ -> []
        end
      end)
      |> Enum.filter(&(length(String.split(&1)) >= 3))
      |> Enum.uniq()

    test_modules =
      test_added
      |> Enum.flat_map(fn line ->
        case Regex.run(@test_module, line) do
          [_, name] -> [name]
          _ -> []
        end
      end)
      |> Enum.reject(&MapSet.member?(tree_dotted, &1))
      |> Enum.uniq()

    visible = task.preservation || ""

    test_paths =
      task.tests
      |> Statements.Diff.paths()
      |> Enum.reject(&String.contains?(visible, &1))

    %{
      lines: lines,
      code_words: Enum.sort(code_like),
      plain_words: plain |> Enum.filter(&(String.length(&1) >= 3)) |> Enum.sort(),
      dotted: Enum.sort(dotted_only),
      test_names: test_names,
      test_modules: test_modules,
      test_paths: test_paths,
      fix_paths: Statements.Diff.paths(task.fix),
      pull_number: pull_number(task.pull_request),
      revisions: Enum.reject([task.start, task.merge], &is_nil/1)
    }
  end

  @doc "The hits of one statement: a list of `{rule, item}`, empty when it passes."
  def check(statement, items) do
    flat = norm(statement)
    lower = String.downcase(flat)
    statement_words = words([statement])
    statement_dotted = dotted([statement])

    l1 = for line <- items.lines, String.contains?(flat, line), do: {"L1", line}
    l2a = for w <- items.code_words, MapSet.member?(statement_words, w), do: {"L2", w}
    l2b = for w <- items.plain_words, code_form?(statement, w), do: {"L2", w}
    l2c = for d <- items.dotted, MapSet.member?(statement_dotted, d), do: {"L2", d}
    l3a = for name <- items.test_names, String.contains?(lower, name), do: {"L3", name}

    l3b =
      for m <- items.test_modules,
          MapSet.member?(statement_dotted, m) or MapSet.member?(statement_words, m),
          do: {"L3", m}

    l4 = for p <- items.test_paths, path_named?(lower, p), do: {"L4", p}
    l5 = for p <- items.fix_paths, path_named?(lower, p), do: {"L5", p}
    l6 = pull_hits(statement, items.pull_number) ++ revision_hits(statement, items.revisions)

    Enum.uniq(l1 ++ l2a ++ l2b ++ l2c ++ l3a ++ l3b ++ l4 ++ l5 ++ l6)
  end

  def norm(line), do: line |> String.split() |> Enum.join(" ")

  def code_like?(word) do
    String.contains?(word, "_") or Regex.match?(~r/[a-z0-9][A-Z]/, word) or
      String.ends_with?(word, ["?", "!"])
  end

  defp words(lines) do
    Enum.reduce(lines, MapSet.new(), fn line, acc ->
      @word |> Regex.scan(line) |> List.flatten() |> MapSet.new() |> MapSet.union(acc)
    end)
  end

  defp dotted(lines) do
    Enum.reduce(lines, MapSet.new(), fn line, acc ->
      @dotted |> Regex.scan(line) |> List.flatten() |> MapSet.new() |> MapSet.union(acc)
    end)
  end

  defp code_form?(text, word) do
    w = Regex.escape(word)

    Regex.match?(
      ~r/`#{w}`|(?<![A-Za-z0-9_])#{w}\(|(?<![A-Za-z0-9_])#{w}\/\d|\.#{w}(?![A-Za-z0-9_?!])/,
      text
    )
  end

  defp path_named?(lower, path) do
    base = Path.basename(path)
    p = String.downcase(path)
    b = String.downcase(base)

    String.contains?(lower, p) or
      Regex.match?(~r/(?<![A-Za-z0-9_\/.-])#{Regex.escape(b)}(?![A-Za-z0-9_])/, lower)
  end

  defp pull_number(nil), do: nil

  defp pull_number(url) do
    case Regex.run(~r/\/pull\/(\d+)/, url) do
      [_, n] -> n
      _ -> nil
    end
  end

  defp pull_hits(_text, nil), do: []

  defp pull_hits(text, n) do
    if Regex.match?(
         ~r/#\s?#{n}\b|pull\/#{n}\b|\bPR\s*#?\s*#{n}\b|pull request\s*#?\s*#{n}\b/i,
         text
       ),
       do: [{"L6", "pull request #{n}"}],
       else: []
  end

  defp revision_hits(text, revisions) do
    ~r/\b[0-9a-f]{7,40}\b/
    |> Regex.scan(String.downcase(text))
    |> List.flatten()
    |> Enum.filter(fn hex -> Enum.any?(revisions, &String.starts_with?(&1, hex)) end)
    |> Enum.uniq()
    |> Enum.map(&{"L6", &1})
  end
end

defmodule Statements.Prompt do
  @moduledoc "The one request for one task: the instruction text (instruction.md) filled with the task's own files."

  def build(template, task, rejected \\ []) do
    template
    |> String.replace("{{repository}}", repository_name(task.repository))
    |> String.replace("{{kind_words}}", kind_words(task.kind))
    |> String.replace("{{engine_text}}", indent(Statements.Task.engine_text(task)))
    |> String.replace("{{retry_note}}", retry_note(rejected))
    |> String.replace("{{reference_patch}}", String.trim_trailing(task.fix_text))
    |> String.replace("{{reference_tests_patch}}", String.trim_trailing(task.tests_text))
  end

  def body(model, prompt),
    do: %{"model" => model, "messages" => [%{"role" => "user", "content" => prompt}]}

  @doc "The statement: the text between the first `<statement>` and the `</statement>` after it, without the white space at its two ends, plus one newline."
  def extract(nil), do: :none

  def extract(content) do
    case Regex.run(~r/<statement>(.*?)<\/statement>/s, content) do
      [_, text] ->
        case String.trim(text) do
          "" -> :none
          trimmed -> {:ok, trimmed <> "\n"}
        end

      _ ->
        :none
    end
  end

  defp repository_name(url),
    do: url |> String.trim_trailing("/") |> String.split("/") |> Enum.take(-2) |> Enum.join("/")

  defp kind_words("bug_fix"), do: "bug fix"
  defp kind_words("feature"), do: "feature"
  defp kind_words(other), do: other

  defp indent(text),
    do:
      text |> String.trim_trailing() |> String.split("\n") |> Enum.map_join("\n", &("    " <> &1))

  defp retry_note([]), do: ""

  defp retry_note(items) do
    listed = Enum.map_join(items, "\n", &"- #{&1}")

    "\nAn earlier answer for this task was rejected because it contained the following, which gives the change " <>
      "away or names the tests. Write it again without them:\n#{listed}\n"
  end
end

defmodule Statements.Client do
  @moduledoc "One chat request to an OpenAI-style server with Erlang's own HTTP client; the key is read from a file."

  def post(url, key_file, body, timeout_ms) do
    {:ok, _} = Application.ensure_all_started(:inets)
    headers = auth(key_file)
    started = System.monotonic_time(:millisecond)

    result =
      :httpc.request(
        :post,
        {String.to_charlist(url <> "/chat/completions"), headers, ~c"application/json",
         JSON.encode!(body)},
        [timeout: timeout_ms, connect_timeout: 30_000],
        body_format: :binary
      )

    wall = System.monotonic_time(:millisecond) - started

    case result do
      {:ok, {{_, status, _}, _headers, raw}} -> %{status: status, raw: raw, wall_ms: wall}
      {:error, reason} -> %{status: nil, raw: inspect(reason), wall_ms: wall}
    end
  end

  def get(url, key_file, path) do
    {:ok, _} = Application.ensure_all_started(:inets)

    case :httpc.request(
           :get,
           {String.to_charlist(url <> path), auth(key_file)},
           [timeout: 60_000],
           body_format: :binary
         ) do
      {:ok, {{_, status, _}, _, raw}} -> %{status: status, raw: raw}
      {:error, reason} -> %{status: nil, raw: inspect(reason)}
    end
  end

  defp auth(nil), do: []

  defp auth(key_file) do
    key = key_file |> File.read!() |> String.trim()
    [{~c"authorization", String.to_charlist("Bearer " <> key)}]
  end
end

defmodule Statements.Writer do
  @moduledoc """
  One task: up to `tries` requests, each answer through the leak check; the first statement that passes is written
  as `ticket.md` and `statement.json` into the task folder. Every request and answer goes to `out`.

  Ends with `{outcome, records}`, the outcome one of
  - `:ok`: a statement passed and was written;
  - `:no_statement`: `tries` answers, none passed;
  - `:server_errors`: three server errors in a row (an error does not use up a try; the same try is sent again after
    `error_pause_ms`);
  - `:busy`: an answer waited longer than `max_wait_ms` before the server began on it (its wall time less the
    server's own prompt and generation times), or no answer came within the client's time-out.
  """

  def run(task, items, opts) do
    s = %{
      task: task,
      items: items,
      opts: opts,
      template: Keyword.fetch!(opts, :template),
      send: Keyword.fetch!(opts, :send),
      out: Keyword.fetch!(opts, :out),
      tries: Keyword.get(opts, :tries, 3),
      max_wait: Keyword.get(opts, :max_wait_ms, 600_000),
      pause: Keyword.get(opts, :error_pause_ms, 30_000),
      n: 1,
      errors: 0,
      rejected: [],
      records: []
    }

    File.mkdir_p!(s.out)
    loop(s)
  end

  defp loop(%{n: n, tries: tries} = s) when n > tries,
    do: {:no_statement, Enum.reverse(s.records)}

  defp loop(s) do
    prompt = Statements.Prompt.build(s.template, s.task, s.rejected)
    body = Statements.Prompt.body(Keyword.fetch!(s.opts, :model), prompt)
    dir = Path.join(s.out, "try-#{s.n}" <> if(s.errors > 0, do: "-again-#{s.errors}", else: ""))
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "request.json"), JSON.encode!(body))
    started_at = DateTime.utc_now() |> DateTime.to_iso8601()
    reply = s.send.(body)
    File.write!(Path.join(dir, "response.json"), reply.raw)
    record = summarize(reply, started_at, s.n)

    if record.server_error do
      write_record(dir, record)
      s = %{s | records: [record | s.records], errors: s.errors + 1}

      cond do
        record.timeout ->
          {:busy, Enum.reverse(s.records)}

        s.errors >= 3 ->
          {:server_errors, Enum.reverse(s.records)}

        true ->
          Process.sleep(s.pause)
          loop(s)
      end
    else
      hits =
        case record.statement do
          nil -> [{"none", "no text between <statement> and </statement>"}]
          text -> Statements.Leak.check(text, s.items)
        end

      record =
        Map.merge(record, %{hits: Enum.map(hits, &Tuple.to_list/1), verdict: verdict(hits)})

      write_record(dir, record)
      s = %{s | records: [record | s.records], errors: 0}

      cond do
        record.wait_ms != nil and record.wait_ms > s.max_wait ->
          {:busy, Enum.reverse(s.records)}

        hits == [] ->
          write_statement!(s.task, record, s.opts)
          {:ok, Enum.reverse(s.records)}

        true ->
          new = for {rule, item} <- hits, rule != "none", do: item
          loop(%{s | n: s.n + 1, rejected: Enum.uniq(s.rejected ++ new)})
      end
    end
  end

  defp verdict([]), do: "pass"
  defp verdict([{"none", _}]), do: "no_statement"
  defp verdict(_), do: "leak"

  @doc "The fields kept from one answer: times, token counts, the server's own timings, and the statement."
  def summarize(%{status: 200, raw: raw, wall_ms: wall}, started_at, n) do
    case JSON.decode(raw) do
      {:ok, %{"choices" => [%{"message" => message} = choice | _]} = answer} ->
        timings = answer["timings"] || %{}
        usage = answer["usage"] || %{}
        busy = (timings["prompt_ms"] || 0) + (timings["predicted_ms"] || 0)
        content = message["content"]
        reasoning = message["reasoning_content"]

        statement =
          case Statements.Prompt.extract(content) do
            {:ok, text} -> text
            :none -> nil
          end

        %{
          try: n,
          started_at: started_at,
          server_error: false,
          timeout: false,
          http: 200,
          wall_ms: wall,
          wait_ms: if(timings == %{}, do: nil, else: round(wall - busy)),
          served_as: answer["model"],
          finish_reason: choice["finish_reason"],
          prompt_tokens: usage["prompt_tokens"],
          completion_tokens: usage["completion_tokens"],
          cached_tokens: get_in(usage, ["prompt_tokens_details", "cached_tokens"]),
          reasoning_tokens: get_in(usage, ["completion_tokens_details", "reasoning_tokens"]),
          timings: timings,
          content_bytes: byte_size(content || ""),
          reasoning_bytes: byte_size(reasoning || ""),
          statement: statement
        }

      _ ->
        error(200, raw, wall, started_at, n)
    end
  end

  def summarize(%{status: status, raw: raw, wall_ms: wall}, started_at, n),
    do: error(status, raw, wall, started_at, n)

  defp error(status, raw, wall, started_at, n) do
    %{
      try: n,
      started_at: started_at,
      server_error: true,
      timeout: status == nil and String.contains?(raw, "timeout"),
      http: status,
      wall_ms: wall,
      detail: String.slice(raw, 0, 500),
      statement: nil
    }
  end

  defp write_record(dir, record), do: File.write!(Path.join(dir, "try.json"), pretty(record))

  defp write_statement!(task, record, opts) do
    ticket = Path.join(task.dir, "ticket.md")
    meta = Path.join(task.dir, "statement.json")
    sha = :crypto.hash(:sha256, record.statement) |> Base.encode16(case: :lower)

    statement = %{
      "writer" => Map.put(Keyword.fetch!(opts, :writer), "served_as", record.served_as),
      "ticket_sha256" => sha,
      "written" => String.slice(record.started_at, 0, 10),
      "try" => record.try,
      "leak_check" => Statements.Leak.rule_version() <> ": pass"
    }

    File.write!(ticket, record.statement)
    File.write!(meta, pretty(statement))
    File.chmod!(ticket, 0o600)
    File.chmod!(meta, 0o600)
  end

  def pretty(term), do: IO.iodata_to_binary([:json.format(jsonable(term)), "\n"])

  defp jsonable(%{} = map), do: Map.new(map, fn {k, v} -> {to_string(k), jsonable(v)} end)
  defp jsonable(list) when is_list(list), do: Enum.map(list, &jsonable/1)
  defp jsonable(nil), do: :null
  defp jsonable(other), do: other
end
