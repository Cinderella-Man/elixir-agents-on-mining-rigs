defmodule Eab.Harness do
  @moduledoc "The coding-agent harness behind a run: always Pi, the bench's harness."
  alias Eab.Pi

  def identity(_endpoint), do: Map.put(Pi.identity(), "name", "pi")

  def label(run) do
    case run && run["harness"] do
      %{"name" => "pi", "version" => version} when is_binary(version) ->
        "Pi #{version}"

      _ ->
        "Pi"
    end
  end

  @doc "The agent named in progress messages."
  def agent(_run), do: "Pi"
end
