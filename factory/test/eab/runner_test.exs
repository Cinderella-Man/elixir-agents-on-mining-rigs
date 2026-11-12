defmodule Eab.RunnerTest do
  use ExUnit.Case, async: true

  test "only complete valid runs receive an equally weighted score" do
    run = %{
      "status" => "completed",
      "cases" => ["a", "b"],
      "attempts" => %{
        "a" => %{"status" => "completed", "grade" => %{"passed" => true}},
        "b" => %{"status" => "completed", "grade" => %{"passed" => false}}
      }
    }

    assert Eab.Runner.score(run)["score_percent"] == 50.0

    for status <- ["running", "cancelled", "interrupted", "error"],
        do: assert(Eab.Runner.score(%{run | "status" => status})["score_percent"] == nil)

    assert Eab.Runner.score(put_in(run, ["attempts", "b"], %{"status" => "error"}))[
             "score_percent"
           ] == nil

    assert Eab.Runner.score(put_in(run, ["attempts", "b"], nil))["score_percent"] == nil
  end

  test "fixture images contain only broken source, with dependencies installed inside Docker" do
    Eab.MadeUpTasks.use!("shelfwise-pr-7")

    recipe =
      Eab.Fixtures.dockerfile(
        Eab.Inventory.spec("shelfwise-pr-7"),
        "elixir@sha256:base",
        "node@sha256:node"
      )

    assert recipe =~ "mix deps.get --only shelf_test"
    assert recipe =~ "npm ci --prefix assets"
    refute recipe =~ "reference.patch"
    refute recipe =~ "reference-tests.patch"
    assert recipe =~ "git init"
  end
end
