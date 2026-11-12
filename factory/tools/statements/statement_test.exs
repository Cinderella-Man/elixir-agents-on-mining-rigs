# The statement tool's tests: elixir -r statement.ex statement_test.exs (needs git; no network, no model server).
ExUnit.start()

defmodule StatementsTest.Fixture do
  @moduledoc "A made-up project in a temporary Git repository, and a task folder whose fix and tests change it."

  @fix """
  diff --git a/lib/app.ex b/lib/app.ex
  index 1111111..2222222 100644
  --- a/lib/app.ex
  +++ b/lib/app.ex
  @@ -1,5 +1,9 @@
   defmodule App do
     def existing_fun(x), do: x
  +
  +  def make_thing(attrs), do: App.NewThing.build(normalize_name(attrs))
  +
  +  defp normalize_name(attrs), do: Map.update(attrs, :name, nil, &String.trim/1)
  +  defp move(a), do: a
   end
  diff --git a/lib/app/new_thing.ex b/lib/app/new_thing.ex
  new file mode 100644
  index 0000000..3333333
  --- /dev/null
  +++ b/lib/app/new_thing.ex
  @@ -0,0 +1,3 @@
  +defmodule App.NewThing do
  +  def build(attrs), do: {:ok, Map.put(attrs, :kind, :thing)}
  +end
  """

  @tests """
  diff --git a/test/app/thing_test.exs b/test/app/thing_test.exs
  new file mode 100644
  index 0000000..4444444
  --- /dev/null
  +++ b/test/app/thing_test.exs
  @@ -0,0 +1,8 @@
  +defmodule App.ThingTest do
  +  use ExUnit.Case
  +
  +  test "creates a thing with a trimmed name" do
  +    assert {:ok, %{name: "a"}} = App.make_thing(%{name: " a "})
  +  end
  +end
  diff --git a/test/app_test.exs b/test/app_test.exs
  index 5555555..6666666 100644
  --- a/test/app_test.exs
  +++ b/test/app_test.exs
  @@ -1,3 +1,4 @@
   defmodule AppTest do
     use ExUnit.Case
  +  test "ok", do: assert(App.existing_fun(1) == 1)
   end
  """

  def build(root) do
    repo = Path.join(root, "repo")
    File.mkdir_p!(Path.join(repo, "lib"))
    File.mkdir_p!(Path.join(repo, "test"))

    File.write!(Path.join(repo, "lib/app.ex"), """
    defmodule App do
      def existing_fun(x), do: x
    end
    """)

    File.write!(Path.join(repo, "test/app_test.exs"), """
    defmodule AppTest do
      use ExUnit.Case
    end
    """)

    git = fn args -> {_, 0} = System.cmd("git", ["-C", repo | args], stderr_to_stdout: true) end
    git.(["init", "-q"])
    git.(["add", "-A"])

    git.([
      "-c",
      "user.name=t",
      "-c",
      "user.email=t@example.invalid",
      "commit",
      "-q",
      "-m",
      "start"
    ])

    {rev, 0} = System.cmd("git", ["-C", repo, "rev-parse", "HEAD"])
    rev = String.trim(rev)

    dir = Path.join(root, "thing-pr-42")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, "reference.patch"), @fix)
    File.write!(Path.join(dir, "reference-tests.patch"), @tests)

    File.write!(
      Path.join(dir, "case.json"),
      JSON.encode!(%{
        "id" => "thing-pr-42",
        "task_kind" => "feature",
        "repository" => %{"url" => "https://github.com/example/thing", "revision" => rev},
        "grading" => %{"preservation" => "mix test test/app_test.exs"}
      })
    )

    File.write!(
      Path.join(dir, "provenance.json"),
      JSON.encode!(%{
        "pull_request" => "https://github.com/example/thing/pull/42",
        "fixed_revision" => "abcdef0123456789abcdef0123456789abcdef01"
      })
    )

    %{repo: repo, dir: dir, rev: rev}
  end
end

defmodule StatementsTest do
  use ExUnit.Case, async: false
  alias Statements.{Diff, Leak, Prompt, Task, Writer}

  setup do
    root = Path.join(System.tmp_dir!(), "statements-test-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(root) end)
    fx = StatementsTest.Fixture.build(root)
    task = Task.read!(fx.dir)

    %{
      fx: fx,
      task: task,
      items: Leak.items(task, Task.tree_lines!(fx.repo, task.start)),
      root: root
    }
  end

  test "the diff reader finds new files, added and removed lines" do
    files =
      Diff.parse("""
      diff --git a/a.ex b/a.ex
      --- a/a.ex
      +++ b/a.ex
      @@ -1,2 +1,2 @@
      -old
      +++new
       same
      diff --git a/gone.ex b/gone.ex
      deleted file mode 100644
      --- a/gone.ex
      +++ /dev/null
      @@ -1 +0,0 @@
      -bye
      """)

    assert [
             %{old: "a.ex", new: "a.ex", added: ["++new"], removed: ["old"]},
             %{old: "gone.ex", new: nil}
           ] = files

    assert Diff.paths(files) == ["a.ex", "gone.ex"]
  end

  test "the task's own files and the engine's instruction text", %{task: task} do
    assert task.id == "thing-pr-42"
    assert task.pull_request =~ "/pull/42"

    assert Task.engine_text(task) ==
             "Complete the feature task in /workspace. Investigate the source and run the relevant tests.\n" <>
               "Test command: mix test test/app_test.exs.\n" <>
               "Add or change a test that fails in its test body on the starting source and passes after your change. " <>
               "Compilation/setup failures do not count.\n"
  end

  test "what the leak check looks for", %{items: items} do
    assert "normalize_name" in items.code_words
    refute "make_thing" in items.code_words, "the tests call it: the interface"
    refute "existing_fun" in items.code_words, "it is in the starting tree"
    assert "move" in items.plain_words
    assert "App.NewThing" in items.dotted
    assert "creates a thing with a trimmed name" in items.test_names
    refute "ok" in items.test_names, "fewer than 3 words"
    assert "App.ThingTest" in items.test_modules

    assert items.test_paths == ["test/app/thing_test.exs"],
           "the engine's test command shows test/app_test.exs"

    assert "lib/app/new_thing.ex" in items.fix_paths and "lib/app.ex" in items.fix_paths
    assert items.pull_number == "42"

    assert Enum.any?(
             items.lines,
             &String.contains?(&1, "Map.update(attrs, :name, nil, &String.trim/1)")
           )
  end

  test "a statement that says what, not how, passes", %{items: items} do
    statement = """
    Add `App.make_thing/1`: it takes a map with a `:name` and returns `{:ok, thing}`, with the name's leading and
    trailing spaces removed. Things must move to the new kind. `App.existing_fun/1` keeps working as before.
    """

    assert Leak.check(statement, items) == []
  end

  test "each rule catches its leak", %{items: items, task: task} do
    hit = fn text -> text |> Leak.check(items) |> Enum.map(&elem(&1, 0)) |> Enum.uniq() end
    assert hit.("Use a private normalize_name helper.") == ["L2"]
    assert hit.("Call `move` on it.") == ["L2"]
    assert hit.("Build it in App.NewThing.") == ["L2"]

    assert hit.(
             "It must work: def make_thing(attrs), do: App.NewThing.build(normalize_name(attrs))"
           )
           |> Enum.member?("L1")

    assert hit.("It creates a thing with a  Trimmed name.") == ["L3"]
    assert hit.("See App.ThingTest.") == ["L3"]
    assert hit.("Look at thing_test.exs.") == ["L4"]
    assert hit.("Run test/app_test.exs as before.") == []
    assert hit.("Put it in lib/app/new_thing.ex.") == ["L5"]
    assert hit.("Change app.ex.") == ["L5"]
    assert hit.("As in #42.") == ["L6"]
    assert hit.("As in PR 42.") == ["L6"]
    assert hit.("Since commit #{String.slice(task.start, 0, 8)}.") == ["L6"]
    assert hit.("Since abcdef0.") == ["L6"]
    assert hit.("There are 42 things.") == []
  end

  test "the statement is the text between the tags" do
    assert Prompt.extract("x\n<statement>\n  Fix it.\n\n</statement>\ny") == {:ok, "Fix it.\n"}
    assert Prompt.extract("<statement>\n\n</statement>") == :none
    assert Prompt.extract("Fix it.") == :none
    assert Prompt.extract(nil) == :none
  end

  test "the request carries the task's files, the engine's text and, on a retry, what was rejected",
       %{task: task} do
    template = File.read!(Path.join(Path.dirname(__ENV__.file), "instruction.md"))
    first = Prompt.build(template, task)
    assert first =~ ~r/Elixir\s+application example\/thing/
    assert first =~ "The task is a feature."
    assert first =~ "    Test command: mix test test/app_test.exs."
    assert first =~ "+  defp move(a), do: a"
    assert first =~ ~s(+  test "creates a thing with a trimmed name" do)
    refute first =~ "rejected"
    refute first =~ "{{"
    again = Prompt.build(template, task, ["normalize_name"])
    assert again =~ "rejected because it contained"
    assert again =~ "- normalize_name"
  end

  defp answer(content, opts \\ []) do
    timings = %{
      "prompt_ms" => 100.0,
      "predicted_ms" => 200.0,
      "prompt_per_second" => 70.5,
      "predicted_per_second" => 46.2,
      "draft_n" => 20,
      "draft_n_accepted" => 13
    }

    %{
      status: 200,
      wall_ms: Keyword.get(opts, :wall, 310),
      raw:
        JSON.encode!(%{
          "model" => "served",
          "choices" => [
            %{
              "message" => %{"content" => content, "reasoning_content" => "think"},
              "finish_reason" => "stop"
            }
          ],
          "usage" => %{"prompt_tokens" => 10, "completion_tokens" => 5},
          "timings" => timings
        })
    }
  end

  defp run(ctx, replies, opts \\ []) do
    {:ok, agent} = Agent.start_link(fn -> {replies, []} end)

    send = fn body ->
      Agent.get_and_update(agent, fn {[r | rest], seen} -> {r, {rest, [body | seen]}} end)
    end

    result =
      Writer.run(
        ctx.task,
        ctx.items,
        [
          template: "{{retry_note}}",
          model: "m",
          writer: %{"model" => "W"},
          out: Path.join(ctx.root, "out"),
          send: send,
          error_pause_ms: 0
        ] ++ opts
      )

    {result, agent |> Agent.get(&elem(&1, 1)) |> Enum.reverse()}
  end

  test "a leak is asked for again, and the first statement that passes is written", ctx do
    {{:ok, records}, bodies} =
      run(ctx, [
        answer("<statement>Use normalize_name.</statement>"),
        answer("<statement>\nAdd make_thing.\n</statement>")
      ])

    assert Enum.map(records, & &1.verdict) == ["leak", "pass"]
    assert [_, second] = bodies
    assert hd(second["messages"])["content"] =~ "- normalize_name"
    ticket = File.read!(Path.join(ctx.fx.dir, "ticket.md"))
    assert ticket == "Add make_thing.\n"
    meta = JSON.decode!(File.read!(Path.join(ctx.fx.dir, "statement.json")))
    assert meta["ticket_sha256"] == :crypto.hash(:sha256, ticket) |> Base.encode16(case: :lower)
    assert meta["writer"] == %{"model" => "W", "served_as" => "served"}
    assert meta["try"] == 2
    assert meta["written"] =~ ~r/^\d{4}-\d\d-\d\d$/
    assert File.stat!(Path.join(ctx.fx.dir, "ticket.md")).mode |> Bitwise.band(0o777) == 0o600
    assert File.exists?(Path.join([ctx.root, "out", "try-1", "try.json"]))
    assert hd(records).timings["draft_n_accepted"] == 13
  end

  test "three answers without a passing statement leave the task without one", ctx do
    {{:no_statement, records}, _} =
      run(ctx, [
        answer("no tags"),
        answer("<statement>See #42</statement>"),
        answer("<statement>new_thing.ex</statement>")
      ])

    assert Enum.map(records, & &1.verdict) == ["no_statement", "leak", "leak"]
    refute File.exists?(Path.join(ctx.fx.dir, "ticket.md"))
  end

  test "a server error does not use up a try; three in a row stop", ctx do
    err = %{status: 500, raw: "boom", wall_ms: 5}
    {{:ok, records}, _} = run(ctx, [err, err, answer("<statement>Fix it.</statement>")])
    assert Enum.map(records, & &1.server_error) == [true, true, false]
    assert List.last(records).try == 1

    File.rm!(Path.join(ctx.fx.dir, "ticket.md"))
    {{:server_errors, records}, _} = run(ctx, [err, err, err])
    assert length(records) == 3
  end

  test "an answer that waited too long, or none within the time-out, stops the task", ctx do
    {{:busy, _}, _} =
      run(ctx, [answer("<statement>Fix it.</statement>", wall: 700_000)], max_wait_ms: 600_000)

    refute File.exists?(Path.join(ctx.fx.dir, "ticket.md"))
    {{:busy, [record]}, _} = run(ctx, [%{status: nil, raw: "{:error, :timeout}", wall_ms: 9}])
    assert record.timeout
  end
end
