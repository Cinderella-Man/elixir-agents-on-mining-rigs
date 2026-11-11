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
    recipe =
      Eab.Fixtures.dockerfile(
        Eab.Inventory.spec("plausible-pr-5939"),
        "elixir@sha256:base",
        "node@sha256:node"
      )

    assert recipe =~ "mix deps.get --only ce_test"
    assert recipe =~ "npm ci --prefix tracker"
    refute recipe =~ "reference.patch"
    refute recipe =~ "acceptance.patch"
    assert recipe =~ "git init"
  end
end
