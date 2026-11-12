defmodule Eab.TaskContractTest do
  use ExUnit.Case, async: true
  alias Eab.{Grader, TaskContract}

  def spec(kind \\ "feature", partial \\ true) do
    %{
      "schema_version" => 3,
      "task_kind" => kind,
      "acceptance_patch" => "reference-tests.patch",
      "partial_control" =>
        if(partial,
          do: %{"present" => true},
          else: %{"present" => false, "reason" => "single_hunk"}
        ),
      "grading" => %{
        "adapter" => "exunit",
        "acceptance" => "mix test test/acceptance_test.exs",
        "preservation" => "mix test test/original_test.exs",
        "protected_paths" => ["test/"],
        "test_suffixes" => ["_test.exs"],
        "required" => ["capability"],
        "starting_failures" => ["capability"],
        "model_tests" => "behavioral"
      }
    }
  end

  test "new task kinds have explicit test policies and solver-visible requirements" do
    for kind <- ~w(bug_fix feature), partial <- [true, false] do
      contract = TaskContract.read(spec(kind, partial))
      assert contract["kind"] == kind
      assert contract["partial"] == partial
      assert contract["requirements"] == []
      assert TaskContract.instructions(spec(kind, partial)) =~ "fails in its test body"
      refute TaskContract.instructions(spec(kind, partial)) =~ "Required outcome"
      assert TaskContract.test_file?(contract, "test/new_test.exs")
      refute TaskContract.test_file?(contract, "lib/new_test.exs")

      stated =
        put_in(spec(kind, partial), ["grading", "requirements"], [
          %{"id" => "public_api", "text" => "Expose the stated interface."}
        ])

      assert TaskContract.instructions(stated) =~
               "Required outcome (public_api): Expose the stated interface."
    end
  end

  test "the one format refuses other versions, removed fields and kinds, and unclear partial records" do
    changes = [
      Map.delete(spec(), "schema_version"),
      Map.put(spec(), "schema_version", 2),
      Map.put(spec(), "task_kind", "refactor"),
      Map.put(spec(), "title", "A descriptive field the format removed"),
      Map.put(spec(), "source_inspiration", %{"url" => "https://example.invalid/pull/1"}),
      Map.put(spec(), "acceptance_patch", "acceptance.patch"),
      Map.put(spec(), "runtime", %{"browser" => true}),
      Map.put(spec(), "clarifications", ["not a map"]),
      Map.delete(spec(), "partial_control"),
      Map.put(spec(), "partial_control", %{"present" => false}),
      Map.put(spec(), "partial_control", %{"present" => false, "reason" => "not_counted"}),
      Map.put(spec(), "partial_control", %{"present" => true, "reason" => "single_hunk"}),
      put_in(spec(), ["grading", "adapter"], "node"),
      put_in(spec(), ["grading", "model_tests"], "optional"),
      put_in(spec(), ["grading", "model_tests"], "preservation"),
      put_in(spec(), ["grading", "starting_failures"], ["unrequired"]),
      put_in(spec(), ["grading", "protected_paths"], ["../"]),
      put_in(spec(), ["grading", "preservation"], "echo passed"),
      put_in(spec(), ["grading", "requirements"], [%{"id" => "r1", "text" => " "}]),
      put_in(spec(), ["grading", "requirements"], [
        %{"id" => "r1", "text" => "Stated.", "kind" => "behavior", "checks" => ["capability"]}
      ]),
      put_in(spec(), ["grading", "requirements"], [
        %{"id" => "r1", "text" => "Stated."},
        %{"id" => "r1", "text" => "Stated twice."}
      ])
    ]

    for changed <- changes, do: assert_raise(RuntimeError, fn -> TaskContract.read(changed) end)
  end

  test "qualification rejects missing capabilities only as named completed test failures" do
    contract = TaskContract.read(spec())
    without_partial = TaskContract.read(spec("feature", false))

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

    # The partial control: required when recorded, and then it must fail a starting failure in a test body.
    refute Grader.valid_controls?(contract, empty, gold, bypass, nil)
    refute Grader.valid_controls?(contract, empty, gold, bypass, gold)

    refute Grader.valid_controls?(
             contract,
             empty,
             gold,
             bypass,
             put_in(empty, ["hidden", "failure_phases", "capability"], "setup")
           )

    # Without a partial fix the controls are the unchanged project, the reference and the early exit.
    assert Grader.valid_controls?(without_partial, empty, gold, bypass, nil)
    refute Grader.valid_controls?(without_partial, empty, gold, bypass, empty)

    refute Grader.valid_controls?(
             without_partial,
             empty,
             Map.put(gold, "passed", false),
             bypass,
             nil
           )

    refute Grader.valid_controls?(
             without_partial,
             empty,
             gold,
             Map.put(bypass, "passed", true),
             nil
           )
  end
end
