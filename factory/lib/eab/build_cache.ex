defmodule Eab.BuildCache do
  @moduledoc "Immutable pristine build seeds, partitioned by resolved toolchain and build policy."
  alias Eab.{Command, Inventory, Store}

  def script, do: Inventory.path("priv/fixtures/build_seed.exs")

  def key(spec, base, node, recipe_hash) do
    %{
      "repository" => spec["repository"]["url"],
      "runtime" => spec["runtime"] |> Map.put("image", base) |> Map.put("node_image", node),
      "recipe" => recipe_hash,
      "script" => Inventory.hash_file(script())
    }
    |> Jason.encode!()
    |> Inventory.hash()
  end

  def find(key, exists? \\ &Eab.Fixtures.image_exists?/1) do
    case Store.read("build-seeds/#{key}.json") do
      %{"key" => ^key, "image" => image} = seed -> if exists?.(image), do: seed
      _ -> nil
    end
  end

  def publish(key, image, id, revision) do
    # Content-addressed tags cannot move under concurrent builders. They also keep
    # a seed referenced if its case's ordinary tag is replaced by a later build.
    tag = tag(image, "seed")
    seed = %{"key" => key, "image" => image, "tag" => tag, "case" => id, "revision" => revision}
    Store.write("build-seeds/#{key}.json", seed)
    seed
  end

  def tag(image, kind) do
    tag = "elixir-agent-benchmark:#{kind}-" <> String.replace_prefix(image, "sha256:", "")
    Command.run!("docker", ["image", "tag", image, tag])
    tag
  end
end
