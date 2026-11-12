# write_statement.exs: one task's statement (README.md in this folder).
#   elixir -r statement.ex write_statement.exs <task folder> <git clone with the task's commits> <out folder>
# Environment: MODEL_URL (the server's OpenAI-style base, ending in /v1), MODEL_KEY_FILE (a file holding the key; unset
# for a server without one), MODEL (the served model's name), WRITER_MODEL, WRITER_FILE, WRITER_PRESET (the writer's id
# in statement.json), TRIES (3), MAX_WAIT_MS (600000), TIMEOUT_MS (3600000), ERROR_PAUSE_MS (30000).
# Writes OUT/items.json (what the leak check looks for), OUT/try-N/{request.json,response.json,try.json} and
# OUT/result.json; on a pass, ticket.md and statement.json in the task folder (mode 600).
# Exit: 0 a statement passed, 10 none after TRIES answers, 13 three server errors in a row, 14 the server was busy.

[task_dir, clone, out] = System.argv()
env = fn name, default -> System.get_env(name) || default end
here = Path.dirname(__ENV__.file)
template = File.read!(Path.join(here, "instruction.md"))
instruction_sha = :crypto.hash(:sha256, template) |> Base.encode16(case: :lower)

task = Statements.Task.read!(task_dir)
items = Statements.Leak.items(task, Statements.Task.tree_lines!(clone, task.start))
File.mkdir_p!(out)
File.write!(Path.join(out, "items.json"), Statements.Writer.pretty(items))

url = System.fetch_env!("MODEL_URL")
key_file = System.get_env("MODEL_KEY_FILE")
timeout = String.to_integer(env.("TIMEOUT_MS", "3600000"))

writer = %{
  "model" => System.fetch_env!("WRITER_MODEL"),
  "file" => System.fetch_env!("WRITER_FILE"),
  "preset" => System.fetch_env!("WRITER_PRESET"),
  "instruction_sha256" => instruction_sha,
  "tool" => "factory/tools/statements"
}

{outcome, records} =
  Statements.Writer.run(task, items,
    template: template,
    model: System.fetch_env!("MODEL"),
    writer: writer,
    out: out,
    tries: String.to_integer(env.("TRIES", "3")),
    max_wait_ms: String.to_integer(env.("MAX_WAIT_MS", "600000")),
    error_pause_ms: String.to_integer(env.("ERROR_PAUSE_MS", "30000")),
    send: &Statements.Client.post(url, key_file, &1, timeout)
  )

result = %{
  id: task.id,
  outcome: Atom.to_string(outcome),
  answers: Enum.count(records, &(not &1.server_error)),
  server_errors: Enum.count(records, & &1.server_error),
  instruction_sha256: instruction_sha,
  leak_rule: Statements.Leak.rule_version()
}

File.write!(Path.join(out, "result.json"), Statements.Writer.pretty(result))

IO.puts(
  "#{task.id}\t#{outcome}\t#{result.answers} answers\t#{result.server_errors} server errors"
)

System.halt(%{ok: 0, no_statement: 10, server_errors: 13, busy: 14}[outcome])
