defmodule Eab.Preparation do
  @moduledoc "Baseline ancestry for preparation; never changes the order of Pi attempts."
  alias Eab.{Cache, Inventory}

  def plan(ids, opts \\ []) do
    load = Keyword.get(opts, :spec, &Inventory.spec/1)
    provenance = Keyword.get(opts, :provenance, &read_provenance/1)

    cached? =
      if opts[:cached?] do
        opts[:cached?]
      else
        cached = Eab.Fixtures.cached_cases(ids)
        &MapSet.member?(cached, &1)
      end

    {cached, missing} = Enum.split_with(ids, cached?)

    missing
    |> Enum.group_by(fn id -> family(load.(id)) end)
    |> Enum.flat_map(fn {_family, members} ->
      members
      |> Enum.sort_by(fn id -> {number(provenance.(id)), id} end)
      |> Enum.map_reduce([], fn id, earlier -> {{id, earlier}, earlier ++ [id]} end)
      |> elem(0)
    end)
    |> Map.new()
    |> Map.merge(Map.new(cached, &{&1, []}))
  end

  # This is a scheduling hint, not permission to reuse a build or database.
  # Installed toolchain identities and migration compatibility are checked again
  # at artifact selection. GitHub PR numbers order creation, not merge ancestry.
  def family(spec) do
    Cache.key(%{
      "repository" => spec["repository"]["url"],
      "runtime" => Map.drop(spec["runtime"], ["before_test_commands"])
    })
  end

  defp read_provenance(id), do: Inventory.read_json(Inventory.case_path(id, "provenance.json"))

  defp number(provenance) do
    case Regex.run(
           ~r{^https://github.com/[^/]+/[^/]+/pull/(\d+)$},
           provenance["pull_request"] || ""
         ) do
      [_, number] -> String.to_integer(number)
      _ -> raise "Preparation requires recorded GitHub PR provenance"
    end
  end
end
