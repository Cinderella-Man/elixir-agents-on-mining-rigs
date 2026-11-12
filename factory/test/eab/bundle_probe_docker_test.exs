defmodule Eab.BundleProbeDockerTest do
  use ExUnit.Case, async: false
  @moduletag :docker
  @moduletag timeout: 600_000
  alias Eab.{BundleProbe, Command, Grader, Inventory, Store}

  test "the test names are observed and a partial fix is searched on made-up tasks, which then pass the controls" do
    previous = Store.root()
    root = Path.join(System.tmp_dir!(), "eab-bundle-probe-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)
    tag = "elixir-task-factory:bundle-probe-#{System.unique_integer([:positive])}"

    on_exit(fn ->
      Eab.Sandbox.cleanup("bundle-probe")
      Command.run("docker", ["image", "rm", tag])
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
    end)

    source = Eab.MadeUpTasks.write_source!(Path.join(root, "context/source"))

    # An existing test whose assertion the reference of ledgerette-pr-1 changes: it passes on the unchanged project
    # and fails on that reference, so settling the existing tests leaves it out there.
    File.write!(Path.join(source, "test/old_debits_test.exs"), """
    defmodule OldDebitsTest do
      use ExUnit.Case

      test "debits are added" do
        assert Ledgerette.balance([{:debit, 5}]) == 5
      end
    end
    """)

    for args <- [
          ["init", "--quiet"],
          ["config", "user.name", "Synthetic"],
          ["config", "user.email", "test@localhost"],
          ["add", "."],
          ["commit", "--quiet", "-m", "Baseline"]
        ],
        do: Command.run!("git", args, cd: source)

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

    prepare = fn id, dir ->
      Inventory.with_case(id, dir, fn ->
        Store.write("runtimes/#{id}.json", %{
          "image" => image,
          "services" => %{},
          "fixture_hashes" => Inventory.fixture_hashes(id)
        })
      end)
    end

    for id <- ~w(ledgerette-pr-1 ledgerette-pr-2) do
      original = Inventory.read_json(Path.join(Eab.MadeUpTasks.dir(id), "case.json"))

      # A draft as the maker writes it before a run: one test name of the reading, and no partial fix yet.
      dir = Path.join(root, "drafts/#{id}")
      File.mkdir_p!(Path.dirname(dir))
      File.cp_r!(Eab.MadeUpTasks.dir(id), dir)
      File.rm(Path.join(dir, "incomplete.patch"))

      draft =
        original
        |> put_in(["grading", "required"], Enum.take(original["grading"]["required"], 1))
        |> put_in(["grading", "starting_failures"], Enum.take(original["grading"]["required"], 1))
        |> put_in(
          ["grading", "preservation"],
          "mix test test/ledgerette_test.exs test/old_debits_test.exs"
        )
        |> Map.put("partial_control", %{"present" => false, "reason" => "single_hunk"})

      File.write!(Path.join(dir, "case.json"), Jason.encode!(draft))
      prepare.(id, dir)

      assert {:ok, names} = BundleProbe.finish(id, dir, "bundle-probe")
      spec = Inventory.read_json(Path.join(dir, "case.json"))
      assert spec["grading"]["required"] == Enum.sort(original["grading"]["required"])

      assert spec["grading"]["starting_failures"] ==
               Enum.sort(original["grading"]["starting_failures"])

      assert names["partial_control"] == spec["partial_control"]

      case id do
        "ledgerette-pr-1" ->
          assert spec["grading"]["preservation"] == "mix test test/ledgerette_test.exs"

          assert spec["grading"]["preservation_left_out"] == [
                   %{"file" => "test/old_debits_test.exs", "reason" => "fails_on_reference"}
                 ]

        "ledgerette-pr-2" ->
          # Its reference only adds a function, so both existing files stay.
          assert spec["grading"]["preservation"] ==
                   "mix test test/ledgerette_test.exs test/old_debits_test.exs"

          assert spec["grading"]["preservation_left_out"] == []
      end

      case id do
        "ledgerette-pr-1" ->
          # The first variant leaves out lib/ledgerette.ex, and its hidden run fails "debits lower the balance".
          assert spec["partial_control"] == %{"present" => true}
          partial = File.read!(Path.join(dir, "incomplete.patch"))
          assert partial =~ "diff --git a/lib/ledgerette/format.ex"
          refute partial =~ "diff --git a/lib/ledgerette.ex"

        "ledgerette-pr-2" ->
          assert spec["partial_control"] == %{"present" => false, "reason" => "single_hunk"}
          refute File.exists?(Path.join(dir, "incomplete.patch"))
      end

      # The written task passes the engine's controls.
      prepare.(id, dir)

      Inventory.with_case(id, dir, fn ->
        control = Grader.qualify(id, "bundle-probe", fn _ -> :ok end)
        assert control["valid"], inspect(control)
      end)
    end

    # ledgerette-pr-2 with a second hidden test that the project marks as skipped (E86): its reference passes every
    # other hidden test, yet no fix can pass the grader's hidden step, so the probe refuses it as skipped_test before
    # any control runs, and leaves the folder as it was.
    id = "ledgerette-pr-2"
    dir = Path.join(root, "skipped/#{id}")
    File.mkdir_p!(Path.dirname(dir))
    File.cp_r!(Eab.MadeUpTasks.dir(id), dir)

    File.write!(Path.join(dir, "reference-tests.patch"), """
    diff --git a/test/debits_test.exs b/test/debits_test.exs
    new file mode 100644
    --- /dev/null
    +++ b/test/debits_test.exs
    @@ -0,0 +1,12 @@
    +defmodule Ledgerette.DebitsTest do
    +  use ExUnit.Case
    +
    +  test "debits sum only the debit entries" do
    +    assert Ledgerette.debits([{:credit, 10}, {:debit, 4}, {:debit, 3}]) == 7
    +  end
    +
    +  @tag :skip
    +  test "debits of an empty ledger are zero" do
    +    assert Ledgerette.debits([]) == 0
    +  end
    +end
    """)

    before = File.read!(Path.join(dir, "case.json"))
    prepare.(id, dir)

    assert BundleProbe.finish(id, dir, "bundle-probe") ==
             {:refused, "skipped_test",
              "the project marks hidden tests as skipped: " <>
                "Elixir.Ledgerette.DebitsTest::test debits of an empty ledger are zero"}

    assert File.read!(Path.join(dir, "case.json")) == before
  end
end
