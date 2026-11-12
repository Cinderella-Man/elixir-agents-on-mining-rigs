defmodule Eab.TaskGradingDockerTest do
  use ExUnit.Case, async: false
  @moduletag :docker
  @moduletag timeout: 600_000
  alias Eab.{Command, Grader, Inventory, Store}

  test "bug-fix and feature grading reject no-ops, incomplete solutions and early exits while accepting alternatives, with and without a partial fix" do
    previous = Store.root()
    root = Path.join(System.tmp_dir!(), "eab-task-grade-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)
    tag = "elixir-task-factory:made-up-tasks-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      Eab.Sandbox.cleanup("made-up-tasks")
      Command.run("docker", ["image", "rm", tag])
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
    end)

    # The made-up project's starting source, committed as the workspace image does.
    source = Eab.MadeUpTasks.write_source!(Path.join(root, "context/source"))

    for args <- [
          ["init", "--quiet"],
          ["config", "user.name", "Synthetic"],
          ["config", "user.email", "test@localhost"],
          ["add", "."],
          ["commit", "--quiet", "-m", "Baseline"]
        ],
        do: Command.run!("git", args, cd: source)

    patch = fn files ->
      for {file, contents} <- files, do: File.write!(Path.join(source, file), contents)
      Command.run!("git", ["add", "--all"], cd: source)
      diff = Command.run!("git", ["diff", "--cached", "--binary", "HEAD"], cd: source)
      Command.run!("git", ["restore", "--source=HEAD", "--staged", "--worktree", "."], cd: source)
      Command.run!("git", ["clean", "-fd"], cd: source)
      diff
    end

    ledger = File.read!(Path.join(source, "lib/ledgerette.ex"))
    format = File.read!(Path.join(source, "lib/ledgerette/format.ex"))

    # Other correct fixes than the references, each with the model's own test.
    alternatives = %{
      "ledgerette-pr-1" =>
        patch.([
          {"lib/ledgerette.ex",
           String.replace(
             ledger,
             "{:debit, amount}, total -> total + amount",
             "{:debit, amount}, total -> total + -amount"
           )},
          {"lib/ledgerette/format.ex",
           String.replace(
             format,
             "  def amount(cents) do\n",
             "  def amount(cents) when cents < 0 do\n    \"-\" <> amount(abs(cents))\n  end\n\n  def amount(cents) do\n"
           )},
          {"test/sign_test.exs",
           "defmodule SignTest do\n  use ExUnit.Case\n\n  test \"a debit is subtracted\" do\n    assert Ledgerette.balance([{:debit, 2}]) == -2\n  end\nend\n"}
        ]),
      "ledgerette-pr-2" =>
        patch.([
          {"lib/ledgerette.ex",
           String.replace(
             ledger,
             "    end)\n  end\nend\n",
             "    end)\n  end\n\n  def debits(entries) do\n    entries |> Enum.filter(&match?({:debit, _}, &1)) |> Enum.map(&elem(&1, 1)) |> Enum.sum()\n  end\nend\n"
           )},
          {"test/total_debits_test.exs",
           "defmodule TotalDebitsTest do\n  use ExUnit.Case\n\n  test \"debits are summed\" do\n    assert Ledgerette.debits([{:debit, 2}, {:debit, 5}]) == 7\n  end\nend\n"}
        ])
    }

    File.write!(Path.join(root, "context/Dockerfile"), """
    FROM #{Eab.TestTooling.image()}
    ENV PATH=/opt/pi:$PATH HOME=/tmp MIX_ENV=test MIX_BUILD_ROOT=/workspace/_build MIX_DEPS_PATH=/workspace/deps
    WORKDIR /workspace
    COPY --chown=65534:65534 source/ /workspace/
    RUN chown -R 65534:65534 /workspace
    USER 65534:65534
    RUN mix compile
    CMD ["sleep", "infinity"]
    """)

    Command.run!(
      "docker",
      ["build", "--network=none", "--provenance=false", "-t", tag, Path.join(root, "context")],
      timeout: 300
    )

    image =
      Command.run!("docker", ["image", "inspect", tag, "--format", "{{.Id}}"]) |> String.trim()

    for id <- ~w(ledgerette-pr-1 ledgerette-pr-2) do
      Inventory.with_case(id, Eab.MadeUpTasks.dir(id), fn ->
        spec = Inventory.spec(id)

        Store.write("runtimes/#{id}.json", %{
          "image" => image,
          "services" => %{},
          "fixture_hashes" => Inventory.fixture_hashes(id)
        })

        control =
          try do
            Grader.qualify(id, "made-up-tasks", fn _ -> :ok end)
          rescue
            error ->
              saved = Store.read("controls/#{id}.json")

              flunk(
                Exception.message(error) <>
                  "\n" <> inspect(saved, limit: :infinity, printable_limit: :infinity)
              )
          end

        assert control["valid"], inspect(control)
        assert control["partial_control"] == spec["partial_control"]
        refute control["empty_patch"]["passed"]
        refute control["early_exit"]["passed"]

        if spec["partial_control"]["present"] do
          refute control["partial_repair"]["passed"]
          assert control["partial_repair"]["hidden"]["completed"]
        else
          assert control["partial_repair"] == nil
        end

        reference = Inventory.file(id, "reference.patch")

        assert Grader.grade(id, alternatives[id], "made-up-tasks",
                 expected: control["reference_patch"]
               )["passed"]

        # The reference alone adds no test that fails first, so it does not pass.
        refute Grader.grade(id, reference, "made-up-tasks", expected: control["reference_patch"])[
                 "passed"
               ]
      end)
    end
  end
end
