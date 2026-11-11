defmodule Eab.TaskContractTest do
  use ExUnit.Case, async: true
  alias Eab.{Grader, TaskContract}

  def spec(kind \\ "feature") do
    %{
      "schema_version" => 2,
      "task_kind" => kind,
      "grading" => %{
        "adapter" => "node",
        "acceptance" => "node --test test/acceptance.mjs",
        "preservation" => "node --test test/original.mjs",
        "protected_paths" => ["test/"],
        "test_suffixes" => [".mjs"],
        "required" => ["capability"],
        "starting_failures" => ["capability"],
        "model_tests" => if(kind == "refactor", do: "preservation", else: "behavioral"),
        "requirements" => [
          %{
            "id" => "public_api",
            "text" => "Expose the stated interface.",
            "kind" => if(kind == "refactor", do: "structural", else: "behavior"),
            "checks" => ["capability"]
          }
        ]
      }
    }
  end

  test "new task kinds have explicit test policies and solver-visible requirements" do
    for kind <- ~w(bug_fix feature refactor) do
      contract = TaskContract.read(spec(kind))
      assert contract["kind"] == kind
      assert TaskContract.instructions(spec(kind)) =~ "Expose the stated interface."
      assert TaskContract.test_file?(contract, "test/new.mjs")
      refute TaskContract.test_file?(contract, "src/new.mjs")
    end

    assert TaskContract.instructions(spec("refactor")) =~ "No behavioral regression"
    assert TaskContract.instructions(spec("feature")) =~ "fails in its test body"
  end

  test "refactors cannot hide an unstated structural preference or demand behavioral breakage" do
    for changed <- [
          put_in(spec("refactor"), ["grading", "model_tests"], "behavioral"),
          put_in(spec("refactor"), ["grading", "requirements"], []),
          put_in(spec("refactor"), ["grading", "required"], ["capability", "secret_preference"]),
          put_in(spec("refactor"), ["grading", "protected_paths"], ["../"])
        ],
        do: assert_raise(RuntimeError, fn -> TaskContract.read(changed) end)
  end

  test "qualification rejects missing capabilities only as named completed test failures" do
    contract = TaskContract.read(spec())

    failed = %{
      "completed" => true,
      "test_results" => %{"capability" => "failed"},
      "failure_phases" => %{"capability" => "test"}
    }

    empty = %{"passed" => false, "hidden" => failed, "regression" => %{"passed" => true}}
    gold = %{"passed" => true}
    bypass = %{"passed" => false, "hidden" => %{"completed" => false}}
    assert Grader.valid_controls?(contract, empty, gold, bypass, empty)
    refute Grader.valid_controls?(contract, empty, gold, Map.put(bypass, "passed", true), empty)

    refute Grader.valid_controls?(
             contract,
             empty,
             gold,
             %{"passed" => false, "reason" => "disallowed_patch"},
             empty
           )

    refute Grader.valid_controls?(
             contract,
             put_in(empty, ["hidden", "completed"], false),
             gold,
             bypass,
             empty
           )

    refute Grader.valid_controls?(
             contract,
             put_in(empty, ["hidden", "failure_phases", "capability"], "setup"),
             gold,
             bypass,
             empty
           )

    refute Grader.valid_controls?(
             TaskContract.read(spec("refactor")),
             put_in(empty, ["regression", "passed"], false),
             gold,
             bypass,
             empty
           )
  end
end
