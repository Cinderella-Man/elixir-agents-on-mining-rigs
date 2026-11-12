# make_task.exs: makes the made-up task ledgerette-pr-1 (factory/test/support/tasks/) runnable by a real controller.
#   elixir make_task.exs SRC OUT IMAGE
# SRC is the factory folder, OUT the job's folder, IMAGE the pinned hexpm/elixir image the task's workspace builds on.
# It writes:
#   OUT/build/ledgerette           a Git repository: the made-up project's starting source (Eab.MadeUpTasks), then the
#                                  task's reference and its tests as the merge commit, with fixed authors and dates
#   OUT/mirror/ledgerette.git      a bare copy of it, and OUT/mirror/mirrors.json naming it as the mirror of the task's
#                                  made-up GitHub address (README section 6, change 4), seen by the controller as /mirror
#   OUT/incoming/ledgerette-pr-1   the task: case.json with the real starting commit and IMAGE, provenance.json with
#                                  the real commits and trees, and a statement of two made-up sentences, marked in
#                                  statement.json as a test fixture that is never training data
# Everything else in the task folder is the test fixture's own bytes.
[src, out, image] = System.argv()
Code.require_file(Path.join(src, "test/support/made_up_tasks.exs"))
id = "ledgerette-pr-1"
fixture = Path.join(src, "test/support/tasks/#{id}")
repo = Path.join(out, "build/ledgerette")
mirror = Path.join(out, "mirror/ledgerette.git")
task = Path.join(out, "incoming/#{id}")

env = [
  {"GIT_AUTHOR_NAME", "Made-up Author"},
  {"GIT_AUTHOR_EMAIL", "author@example.invalid"},
  {"GIT_COMMITTER_NAME", "Made-up Author"},
  {"GIT_COMMITTER_EMAIL", "author@example.invalid"}
]

git = fn args, date ->
  dates = if date, do: [{"GIT_AUTHOR_DATE", date}, {"GIT_COMMITTER_DATE", date}], else: []
  {output, 0} = System.cmd("git", args, cd: repo, env: env ++ dates, stderr_to_stdout: true)
  String.trim(output)
end

for path <- [repo, mirror, task], do: File.rm_rf!(path)
File.mkdir_p!(repo)
Eab.MadeUpTasks.write_source!(repo)
git.(["init", "--quiet", "--initial-branch=main"], nil)
git.(["add", "--all"], nil)
git.(["commit", "--quiet", "-m", "Starting source of the made-up project"], "2026-03-01T12:00:00Z")
broken = git.(["rev-parse", "HEAD"], nil)
broken_tree = git.(["rev-parse", "HEAD^{tree}"], nil)

git.(
  ["apply", "--index"] ++
    Enum.map(~w(reference.patch reference-tests.patch), &Path.join(fixture, &1)),
  nil
)

git.(["commit", "--quiet", "-m", "Merge pull request #1 (made up)"], "2026-03-04T12:00:00Z")
fixed = git.(["rev-parse", "HEAD"], nil)
fixed_tree = git.(["rev-parse", "HEAD^{tree}"], nil)

{_, 0} = System.cmd("git", ["clone", "--quiet", "--bare", repo, mirror])
{_, 0} = System.cmd("git", ["-C", mirror, "config", "uploadpack.allowAnySHA1InWant", "true"])

File.write!(
  Path.join(out, "mirror/mirrors.json"),
  JSON.encode!(%{"https://github.com/made-up-org/ledgerette" => "file:///mirror/ledgerette.git"})
)

File.mkdir_p!(Path.dirname(task))
File.cp_r!(fixture, task)
read = fn file -> task |> Path.join(file) |> File.read!() |> JSON.decode!() end
write = fn file, data -> File.write!(Path.join(task, file), JSON.encode!(data) <> "\n") end

spec = read.("case.json")

write.(
  "case.json",
  spec
  |> put_in(["repository", "revision"], broken)
  |> put_in(["runtime", "image"], image)
)

write.(
  "provenance.json",
  read.("provenance.json")
  |> Map.merge(%{
    "broken_revision" => broken,
    "broken_tree" => broken_tree,
    "fixed_revision" => fixed,
    "fixed_tree" => fixed_tree
  })
)

ticket =
  "A debit entry raises the ledger's balance instead of lowering it, and a negative amount prints with a stray " <>
    "minus sign in its cents. Debits should lower the balance, and a negative amount should print with one " <>
    "leading minus sign.\n"

File.write!(Path.join(task, "ticket.md"), ticket)

write.("statement.json", %{
  "writer" => %{
    "name" => "test-fixture",
    "file" => "none",
    "settings" => %{},
    "note" => "made-up statement for factory job T10: a test fixture, never training data"
  },
  "ticket_sha256" => :crypto.hash(:sha256, ticket) |> Base.encode16(case: :lower),
  "written" => "2026-11-12"
})

IO.puts(
  JSON.encode!(%{
    "broken_revision" => broken,
    "broken_tree" => broken_tree,
    "fixed_revision" => fixed,
    "fixed_tree" => fixed_tree,
    "task" => task
  })
)
