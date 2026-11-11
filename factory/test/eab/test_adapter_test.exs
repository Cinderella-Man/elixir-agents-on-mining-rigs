defmodule Eab.TestAdapterTest do
  use ExUnit.Case, async: true
  alias Eab.{Command, Grader, Inventory, TestAdapter}

  setup do
    root = Path.join(System.tmp_dir!(), "eab-node-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root}
  end

  defp run(root, code) do
    File.write!(Path.join(root, "case.mjs"), code)
    node = System.find_executable("node") || "/opt/pi/node"

    Command.run(node, [Inventory.path("priv/fixtures/node_runner.mjs"), "case.mjs"],
      cd: root,
      timeout: 15
    )
    |> Grader.parse()
  end

  test "trusted Node events distinguish assertions from setup and incomplete output", %{
    root: root
  } do
    passing = run(root, "import test from 'node:test'; test('capability', () => {});")
    assert passing["passed"], inspect(passing)
    assert passing["test_results"] == %{"case.mjs::capability" => "passed"}

    failing =
      run(
        root,
        "import test from 'node:test'; import assert from 'node:assert/strict'; test('capability', () => assert.equal(1, 2));"
      )

    assert Grader.behavioral_failures(failing) == ["case.mjs::capability"]

    setup =
      run(
        root,
        "import test, {before} from 'node:test'; before(() => { throw Error('setup'); }); test('capability', () => {});"
      )

    refute setup["passed"]
    assert Grader.behavioral_failures(setup) == []

    for code <- [
          "process.exit(0)",
          "import test from 'node:test'; test.skip('capability', () => {});",
          "import test from 'node:test'; test('same', () => {}); test('same', () => {});",
          "console.log('EAB_TEST:passed:eA==\\nEAB_SUITE_FINISHED:1'); process.exit(0)"
        ],
        do: refute(run(root, code)["passed"])
  end

  test "node commands cannot override the trusted reporter or silently discover a different suite" do
    assert TestAdapter.command("node", "node --test test/original.mjs", ["test/new.mjs"]) =~
             "'test/new.mjs'"

    for cmd <- [
          "node --test",
          "node --test --test-reporter fake.mjs",
          "node --test ../test.mjs",
          "node --test test/*.mjs"
        ],
        do: assert_raise(RuntimeError, fn -> TestAdapter.command("node", cmd, []) end)
  end
end
