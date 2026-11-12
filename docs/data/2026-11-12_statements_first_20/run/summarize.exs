# summarize.exs: the tables of a run of run_all.sh, from the records it left (one folder per task).
#   elixir summarize.exs <OUT of run_all.sh> <task list> <tasks folder>
# Writes OUT/tries.tsv (one row per answer or server error), OUT/statements.tsv (one row per task) and
# OUT/table.md (the README's table: one row per task). Each number is one request; nothing is averaged here.

[out, list, tasks_dir] = System.argv()

rows =
  list
  |> File.read!()
  |> String.split("\n", trim: true)
  |> Enum.map(fn line -> line |> String.split("\t") |> hd() end)

read = fn path -> if File.exists?(path), do: JSON.decode!(File.read!(path)), else: nil end
s = fn ms -> if is_number(ms), do: :erlang.float_to_binary(ms / 1000, decimals: 1), else: "" end
num = fn v -> if is_float(v), do: :erlang.float_to_binary(v, decimals: 1), else: to_string(v || "") end

tries =
  for folder <- rows,
      id = Path.basename(folder),
      dir <- Path.wildcard(Path.join([out, id, "try-*"])) |> Enum.sort(),
      record = read.(Path.join(dir, "try.json")),
      record != nil do
    t = record["timings"] || %{}

    %{
      id: id,
      attempt: Path.basename(dir),
      verdict: record["verdict"] || if(record["server_error"], do: "server_error", else: ""),
      hits: (record["hits"] || []) |> Enum.map_join("; ", fn [rule, item] -> "#{rule} #{item}" end),
      wall_ms: record["wall_ms"],
      wait_ms: record["wait_ms"],
      prompt_tokens: record["prompt_tokens"],
      completion_tokens: record["completion_tokens"],
      cached_tokens: record["cached_tokens"],
      prompt_n: t["prompt_n"],
      cache_n: t["cache_n"],
      prompt_ms: t["prompt_ms"],
      prompt_per_second: t["prompt_per_second"],
      predicted_ms: t["predicted_ms"],
      predicted_per_second: t["predicted_per_second"],
      draft_n: t["draft_n"],
      draft_n_accepted: t["draft_n_accepted"],
      finish_reason: record["finish_reason"],
      reasoning_bytes: record["reasoning_bytes"],
      content_bytes: record["content_bytes"],
      statement_bytes: if(record["statement"], do: byte_size(record["statement"]), else: nil),
      started_at: record["started_at"]
    }
  end

cols =
  ~w(id attempt verdict wall_ms wait_ms prompt_tokens cached_tokens prompt_n cache_n completion_tokens prompt_ms prompt_per_second
     predicted_ms predicted_per_second draft_n draft_n_accepted finish_reason reasoning_bytes content_bytes
     statement_bytes started_at hits)a

tsv = fn rows, cols ->
  [Enum.map_join(cols, "\t", &to_string/1)] ++
    Enum.map(rows, fn r ->
      Enum.map_join(cols, "\t", fn c -> r |> Map.get(c) |> num.() |> String.replace(~r/[\t\n]/, " ") end)
    end)
end

File.write!(Path.join(out, "tries.tsv"), Enum.join(tsv.(tries, cols), "\n") <> "\n")

tasks =
  for folder <- rows do
    id = Path.basename(folder)
    result = read.(Path.join([out, id, "result.json"])) || %{}
    meta = read.(Path.join([tasks_dir, folder, "statement.json"]))
    kind = (read.(Path.join([tasks_dir, folder, "case.json"])) || %{})["task_kind"]
    mine = Enum.filter(tries, &(&1.id == id))
    answers = Enum.reject(mine, &(&1.verdict == "server_error"))

    passed = Enum.find(answers, &(&1.verdict == "pass"))

    outcome =
      cond do
        result["outcome"] -> result["outcome"]
        File.dir?(Path.join(out, id)) -> "stopped"
        true -> "not run"
      end

    statement =
      cond do
        meta -> "#{File.stat!(Path.join([tasks_dir, folder, "ticket.md"])).size}"
        passed -> "#{passed.statement_bytes}, removed: project outside the dataset"
        outcome == "stopped" -> "none: stopped when the list changed"
        true -> "none"
      end

    %{
      id: id,
      kind: kind,
      outcome: outcome,
      answers: length(answers),
      server_errors: length(mine) - length(answers),
      verdicts: Enum.map_join(answers, ", ", & &1.verdict),
      statement: statement,
      ticket_sha256: meta && meta["ticket_sha256"],
      tries: mine
    }
  end

File.write!(
  Path.join(out, "statements.tsv"),
  Enum.join(
    tsv.(tasks, ~w(id kind outcome answers server_errors verdicts statement ticket_sha256)a),
    "\n"
  ) <> "\n"
)

list_of = fn values -> Enum.map_join(values, ", ", &num.(&1)) end

prompt_cell = fn t ->
  if (t.cache_n || 0) > 0, do: "#{t.prompt_tokens} (#{t.cache_n} cached)", else: "#{t.prompt_tokens}"
end

table =
  [
    "| Task | Kind | Tries | Verdicts | Statement (bytes) | Wall time (s) | Waited (s) | Prompt tokens | Generated tokens | Reading (tok/s) | Generating (tok/s) | Drafted tokens accepted |",
    "|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|"
  ] ++
    Enum.map(tasks, fn t ->
      a = Enum.reject(t.tries, &(&1.verdict == "server_error"))

      "| `#{t.id}` | #{t.kind} | #{t.answers} | #{t.verdicts} | #{t.statement} | " <>
        "#{Enum.map_join(a, ", ", &s.(&1.wall_ms))} | #{Enum.map_join(a, ", ", &s.(&1.wait_ms))} | " <>
        "#{Enum.map_join(a, ", ", &prompt_cell.(&1))} | #{list_of.(Enum.map(a, & &1.completion_tokens))} | " <>
        "#{list_of.(Enum.map(a, & &1.prompt_per_second))} | #{list_of.(Enum.map(a, & &1.predicted_per_second))} | " <>
        "#{Enum.map_join(a, "; ", &"#{&1.draft_n_accepted} of #{&1.draft_n}")} |"
    end)

File.write!(Path.join(out, "table.md"), Enum.join(table, "\n") <> "\n")
IO.puts("#{length(tries)} answers and errors, #{length(tasks)} tasks")
