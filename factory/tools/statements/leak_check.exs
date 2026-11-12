# leak_check.exs: the leak check alone, on a statement already written (README.md in this folder).
#   elixir -r statement.ex leak_check.exs <task folder> <git clone with the task's commits> [statement file]
# The statement file defaults to the task folder's ticket.md. Prints one line of JSON: the task, the rule's version,
# the verdict (pass or leak) and the hits as [rule, item]. Exit 0 on a pass, 1 on a leak.

[task_dir, clone | rest] = System.argv()
file = List.first(rest) || Path.join(task_dir, "ticket.md")
task = Statements.Task.read!(task_dir)
items = Statements.Leak.items(task, Statements.Task.tree_lines!(clone, task.start))
hits = Statements.Leak.check(File.read!(file), items)

IO.puts(
  JSON.encode!(%{
    "id" => task.id,
    "rule" => Statements.Leak.rule_version(),
    "verdict" => if(hits == [], do: "pass", else: "leak"),
    "hits" => Enum.map(hits, &Tuple.to_list/1)
  })
)

System.halt(if hits == [], do: 0, else: 1)
