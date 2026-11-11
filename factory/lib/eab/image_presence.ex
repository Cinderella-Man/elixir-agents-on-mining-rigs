defmodule Eab.ImagePresence do
  @moduledoc "Batch read-only image existence probes for preparation planning."
  alias Eab.Command

  def existing(images, inspect_batch \\ &inspect_batch/1) do
    images
    |> Enum.uniq()
    |> Enum.chunk_every(200)
    |> Enum.reduce(MapSet.new(), fn batch, present ->
      MapSet.union(present, identities(inspect_batch.(batch)))
    end)
  end

  def identities(result) do
    unless not result["output_truncated"] and
             (result["returncode"] == 0 or
                String.contains?(result["output"], ["No such image", "No such object"])),
           do: raise("Docker could not inspect the preparation cache")

    result["output"]
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      case Jason.decode(line) do
        {:ok, %{"id" => id} = image} -> [id] ++ (image["tags"] || []) ++ (image["digests"] || [])
        _ -> []
      end
    end)
    |> MapSet.new()
  end

  defp inspect_batch(images) do
    format = ~s({"id":{{json .Id}},"tags":{{json .RepoTags}},"digests":{{json .RepoDigests}}})

    Command.run("docker", ["image", "inspect", "--format", format | images],
      timeout: 45,
      limit: 2_097_152
    )
  end
end
