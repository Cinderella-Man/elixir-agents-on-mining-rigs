# summarize.exs: the tables of a run of run_all.sh, from the records it left (one folder per case).
#   elixir summarize.exs <OUT of run_all.sh> <case list> <tasks folder> <folder for the tables>
# Writes, into the tables' folder:
#   cases.tsv, cases.md    one row per case: project, case, kind, answers, accepted or not, seconds, the statement's
#                          bytes, what each rejected answer was rejected for
#   tries.tsv, tries.md    one row per answer or server error: times, token counts, the server's own timings
#   rejections.tsv         one row per rejected item: case, answer, rule, item
#   totals.tsv             sums by project and kind, by project, by kind and over the run
#   sha_check.tsv          ticket.md's SHA-256 against statement.json and against the accepted answer's text
# Each number in cases and tries is one case or one request; totals.tsv holds sums and the speeds they give.

[out, list, tasks_dir, tables] = System.argv()
File.mkdir_p!(tables)

rows =
  list
  |> File.read!()
  |> String.split("\n", trim: true)
  |> Enum.map(fn line -> line |> String.split("\t") |> hd() end)

read = fn path -> if File.exists?(path), do: JSON.decode!(File.read!(path)), else: nil end

# The project as owner/name, from the case's own record of its repository.
project_of = fn folder ->
  case read.(Path.join([tasks_dir, folder, "case.json"])) do
    %{"repository" => %{"url" => url}} ->
      url |> String.trim_trailing("/") |> String.split("/") |> Enum.take(-2) |> Enum.join("/")

    _ ->
      Path.dirname(folder)
  end
end
sha = fn text -> :crypto.hash(:sha256, text) |> Base.encode16(case: :lower) end
dec = fn v -> :erlang.float_to_binary(v * 1.0, decimals: 1) end
s = fn ms -> if is_number(ms), do: dec.(ms / 1000), else: "" end
num = fn v -> if is_float(v), do: dec.(v), else: to_string(v || "") end
cell = fn text -> text |> String.replace("|", "\\|") |> String.replace(~r/\s+/, " ") end

seconds =
  Path.join(out, "tasks.tsv")
  |> File.read!()
  |> String.split("\n", trim: true)
  |> tl()
  |> Enum.map(&String.split(&1, "\t"))
  |> Enum.group_by(&hd/1, fn [_, exit, start, stop, secs] ->
    %{exit: exit, start: start, stop: stop, seconds: String.to_integer(secs)}
  end)

tries =
  for folder <- rows,
      id = Path.basename(folder),
      dir <- Path.wildcard(Path.join([out, id, "try-*"])) |> Enum.sort(),
      record = read.(Path.join(dir, "try.json")),
      record != nil do
    t = record["timings"] || %{}

    %{
      project: project_of.(folder),
      id: id,
      attempt: Path.basename(dir),
      try: record["try"],
      verdict: record["verdict"] || if(record["server_error"], do: "server_error", else: ""),
      hit_list: record["hits"] || [],
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
      predicted_n: t["predicted_n"],
      predicted_ms: t["predicted_ms"],
      predicted_per_second: t["predicted_per_second"],
      draft_n: t["draft_n"],
      draft_n_accepted: t["draft_n_accepted"],
      finish_reason: record["finish_reason"],
      reasoning_bytes: record["reasoning_bytes"],
      content_bytes: record["content_bytes"],
      statement_bytes: if(record["statement"], do: byte_size(record["statement"]), else: nil),
      statement_sha256: if(record["statement"], do: sha.(record["statement"]), else: nil),
      detail: record["detail"],
      started_at: record["started_at"]
    }
  end

tsv = fn rows, cols ->
  lines =
    [Enum.map_join(cols, "\t", &to_string/1)] ++
      Enum.map(rows, fn r ->
        Enum.map_join(cols, "\t", fn c ->
          r |> Map.get(c) |> num.() |> String.replace(~r/[\t\n\r]/, " ")
        end)
      end)

  Enum.join(lines, "\n") <> "\n"
end

try_cols =
  ~w(project id attempt verdict wall_ms wait_ms prompt_tokens cached_tokens prompt_n cache_n completion_tokens
     predicted_n prompt_ms prompt_per_second predicted_ms predicted_per_second draft_n draft_n_accepted finish_reason
     reasoning_bytes content_bytes statement_bytes started_at hits)a

File.write!(Path.join(tables, "tries.tsv"), tsv.(tries, try_cols))

cases =
  for folder <- rows do
    id = Path.basename(folder)
    project = project_of.(folder)
    result = read.(Path.join([out, id, "result.json"])) || %{}
    ticket = Path.join([tasks_dir, folder, "ticket.md"])
    meta = read.(Path.join([tasks_dir, folder, "statement.json"]))
    kind = (read.(Path.join([tasks_dir, folder, "case.json"])) || %{})["task_kind"]
    mine = Enum.filter(tries, &(&1.id == id))
    answers = Enum.reject(mine, &(&1.verdict == "server_error"))
    passed = Enum.find(answers, &(&1.verdict == "pass"))
    runs = Map.get(seconds, id, [])

    outcome =
      cond do
        result["outcome"] -> result["outcome"]
        File.dir?(Path.join(out, id)) -> "stopped"
        true -> "not run"
      end

    accepted =
      case outcome do
        "ok" -> "yes"
        "no_statement" -> "no: no accepted answer after #{length(answers)}"
        other -> "no: #{other}"
      end

    ticket_text = if File.regular?(ticket), do: File.read!(ticket), else: nil

    rejected =
      answers
      |> Enum.reject(&(&1.verdict == "pass"))
      |> Enum.map(fn a -> {a.try, a.verdict, a.hit_list} end)

    %{
      project: project,
      id: id,
      kind: kind,
      outcome: outcome,
      accepted: accepted,
      answers: length(answers),
      server_errors: length(mine) - length(answers),
      verdicts: Enum.map_join(answers, ", ", & &1.verdict),
      seconds: Enum.map_join(runs, ", ", &to_string(&1.seconds)),
      seconds_sum: runs |> Enum.map(& &1.seconds) |> Enum.sum(),
      statement_bytes: if(ticket_text, do: byte_size(ticket_text), else: nil),
      ticket_sha256: ticket_text && sha.(ticket_text),
      record_sha256: meta && meta["ticket_sha256"],
      answer_sha256: passed && passed.statement_sha256,
      accepted_try: meta && meta["try"],
      rejected: rejected,
      rejected_for:
        Enum.map_join(rejected, " / ", fn {n, verdict, hits} ->
          "answer #{n} (#{verdict}): " <> Enum.map_join(hits, "; ", fn [rule, item] -> "#{rule} #{item}" end)
        end),
      tries: mine
    }
  end

File.write!(
  Path.join(tables, "cases.tsv"),
  tsv.(
    cases,
    ~w(project id kind answers accepted seconds statement_bytes verdicts server_errors accepted_try ticket_sha256 rejected_for)a
  )
)

File.write!(
  Path.join(tables, "sha_check.tsv"),
  tsv.(
    Enum.map(cases, fn c ->
      Map.put(
        c,
        :same,
        cond do
          c.ticket_sha256 == nil and c.record_sha256 == nil -> "no statement"
          c.ticket_sha256 == c.record_sha256 and c.ticket_sha256 == c.answer_sha256 -> "same"
          true -> "DIFFERENT"
        end
      )
    end),
    ~w(project id same ticket_sha256 record_sha256 answer_sha256)a
  )
)

rejections =
  for c <- cases, {n, verdict, hits} <- c.rejected, [rule, item] <- hits do
    %{project: c.project, id: c.id, kind: c.kind, answer: n, verdict: verdict, rule: rule, item: item}
  end

File.write!(
  Path.join(tables, "rejections.tsv"),
  tsv.(rejections, ~w(project id kind answer verdict rule item)a)
)

cases_md =
  [
    "| Project | Case | Kind | Answers | Accepted | Seconds | Statement (bytes) | Rejected for |",
    "|---|---|---|---:|---|---:|---:|---|"
  ] ++
    Enum.map(cases, fn c ->
      why =
        Enum.map_join(c.rejected, "; ", fn {n, _verdict, hits} ->
          items =
            case hits do
              [["none", _]] -> "no text between the tags"
              _ -> Enum.map_join(hits, ", ", fn [rule, item] -> "#{rule} `#{cell.(item)}`" end)
            end

          "answer #{n}: " <> items
        end)

      "| `#{c.project}` | `#{c.id}` | #{c.kind} | #{c.answers} | #{c.accepted} | #{c.seconds} | " <>
        "#{c.statement_bytes || "none"} | #{why} |"
    end)

File.write!(Path.join(tables, "cases.md"), Enum.join(cases_md, "\n") <> "\n")

list_of = fn values -> Enum.map_join(values, ", ", &num.(&1)) end

prompt_cell = fn t ->
  if (t.cache_n || 0) > 0, do: "#{t.prompt_tokens} (#{t.cache_n} cached)", else: "#{t.prompt_tokens}"
end

tries_md =
  [
    "| Case | Kind | Answers | Verdicts | Wall time (s) | Waited (s) | Prompt tokens | Generated tokens | Reading (tok/s) | Generating (tok/s) | Drafted tokens accepted |",
    "|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|"
  ] ++
    Enum.map(cases, fn c ->
      a = Enum.reject(c.tries, &(&1.verdict == "server_error"))

      "| `#{c.id}` | #{c.kind} | #{c.answers} | #{c.verdicts} | " <>
        "#{Enum.map_join(a, ", ", &s.(&1.wall_ms))} | #{Enum.map_join(a, ", ", &s.(&1.wait_ms))} | " <>
        "#{Enum.map_join(a, ", ", &prompt_cell.(&1))} | #{list_of.(Enum.map(a, & &1.completion_tokens))} | " <>
        "#{list_of.(Enum.map(a, & &1.prompt_per_second))} | #{list_of.(Enum.map(a, & &1.predicted_per_second))} | " <>
        "#{Enum.map_join(a, "; ", &"#{&1.draft_n_accepted} of #{&1.draft_n}")} |"
    end)

File.write!(Path.join(tables, "tries.md"), Enum.join(tries_md, "\n") <> "\n")

sum = fn list, key -> list |> Enum.map(&(Map.get(&1, key) || 0)) |> Enum.sum() end
rate = fn n, ms -> if ms > 0, do: dec.(n / (ms / 1000)), else: "" end

total = fn name, group ->
  answers = group |> Enum.flat_map(& &1.tries) |> Enum.reject(&(&1.verdict == "server_error"))
  errors = group |> Enum.flat_map(& &1.tries) |> Enum.filter(&(&1.verdict == "server_error"))
  rejected = Enum.reject(answers, &(&1.verdict == "pass"))
  speeds = answers |> Enum.map(& &1.predicted_per_second) |> Enum.filter(&is_number/1)
  waits = answers |> Enum.map(& &1.wait_ms) |> Enum.filter(&is_number/1)
  sizes = group |> Enum.map(& &1.statement_bytes) |> Enum.filter(&is_number/1)

  %{
    group: name,
    cases: length(group),
    accepted: Enum.count(group, &(&1.outcome == "ok")),
    no_accepted_answer: Enum.count(group, &(&1.outcome == "no_statement")),
    other_outcome: Enum.count(group, &(&1.outcome not in ["ok", "no_statement"])),
    first_answer: Enum.count(group, &(&1.outcome == "ok" and &1.accepted_try == 1)),
    second_answer: Enum.count(group, &(&1.outcome == "ok" and &1.accepted_try == 2)),
    third_answer: Enum.count(group, &(&1.outcome == "ok" and &1.accepted_try == 3)),
    answers: length(answers),
    rejected_answers: length(rejected),
    server_errors: length(errors),
    seconds: sum.(group, :seconds_sum),
    answers_wall_s: s.(sum.(answers, :wall_ms)),
    rejected_wall_s: s.(sum.(rejected, :wall_ms)),
    prompt_tokens: sum.(answers, :prompt_tokens),
    prompt_read: sum.(answers, :prompt_n),
    prompt_cached: sum.(answers, :cache_n),
    prompt_s: s.(sum.(answers, :prompt_ms)),
    reading_tok_s: rate.(sum.(answers, :prompt_n), sum.(answers, :prompt_ms)),
    generated_tokens: sum.(answers, :completion_tokens),
    generating_s: s.(sum.(answers, :predicted_ms)),
    generating_tok_s: rate.(sum.(answers, :completion_tokens), sum.(answers, :predicted_ms)),
    slowest_generating_tok_s: if(speeds == [], do: "", else: dec.(Enum.min(speeds))),
    fastest_generating_tok_s: if(speeds == [], do: "", else: dec.(Enum.max(speeds))),
    longest_wait_s: if(waits == [], do: "", else: s.(Enum.max(waits))),
    drafted: sum.(answers, :draft_n),
    drafted_accepted: sum.(answers, :draft_n_accepted),
    statement_bytes: Enum.sum(sizes),
    smallest_statement: if(sizes == [], do: "", else: Enum.min(sizes)),
    largest_statement: if(sizes == [], do: "", else: Enum.max(sizes))
  }
end

groups =
  [{"all", cases}] ++
    (cases |> Enum.group_by(& &1.kind) |> Enum.sort() |> Enum.map(fn {k, g} -> {"all, #{k}", g} end)) ++
    (cases |> Enum.group_by(& &1.project) |> Enum.sort() |> Enum.map(fn {p, g} -> {p, g} end)) ++
    (cases
     |> Enum.group_by(&{&1.project, &1.kind})
     |> Enum.sort()
     |> Enum.map(fn {{p, k}, g} -> {"#{p}, #{k}", g} end))

total_cols =
  ~w(group cases accepted no_accepted_answer other_outcome first_answer second_answer third_answer answers
     rejected_answers server_errors seconds answers_wall_s rejected_wall_s prompt_tokens prompt_read prompt_cached
     prompt_s reading_tok_s generated_tokens generating_s generating_tok_s slowest_generating_tok_s
     fastest_generating_tok_s longest_wait_s drafted drafted_accepted statement_bytes smallest_statement
     largest_statement)a

File.write!(
  Path.join(tables, "totals.tsv"),
  tsv.(Enum.map(groups, fn {name, group} -> total.(name, group) end), total_cols)
)

different =
  Enum.count(cases, fn c ->
    c.ticket_sha256 != c.record_sha256 or (c.ticket_sha256 != nil and c.ticket_sha256 != c.answer_sha256)
  end)

IO.puts(
  "#{length(tries)} answers and errors, #{length(cases)} cases, " <>
    "#{Enum.count(cases, &(&1.outcome == "ok"))} accepted, #{different} statements that differ from their record"
)
