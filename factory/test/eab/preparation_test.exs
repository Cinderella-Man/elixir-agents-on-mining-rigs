defmodule Eab.PreparationTest do
  use ExUnit.Case, async: true
  alias Eab.Preparation

  test "orders missing baselines by PR creation order within runtime families" do
    spec = fn id ->
      %{
        "repository" => %{"url" => "https://github.com/org/app"},
        "runtime" => %{"image" => if(id == "other", do: "other", else: "same")}
      }
    end

    numbers = %{"new" => 30, "old" => 10, "middle" => 20, "other" => 1}

    provenance = fn id ->
      %{"pull_request" => "https://github.com/org/app/pull/#{numbers[id]}"}
    end

    assert Preparation.plan(~w(new other old middle),
             spec: spec,
             provenance: provenance,
             cached?: fn _ -> false end
           ) == %{"old" => [], "middle" => ["old"], "new" => ["old", "middle"], "other" => []}

    assert Preparation.plan(~w(new other old middle),
             spec: spec,
             provenance: provenance,
             cached?: &(&1 == "middle")
           ) == %{"old" => [], "middle" => [], "new" => ["old"], "other" => []}
  end
end
