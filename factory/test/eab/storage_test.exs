defmodule Eab.StorageTest do
  use ExUnit.Case, async: true
  alias Eab.Storage

  test "image aliases are deduplicated and shared bytes are never summed as unique storage" do
    image = %{
      "Id" => "one",
      "Size" => 100,
      "SharedSize" => 70,
      "RepoTags" => ["elixir-agent-benchmark:one"]
    }

    other = %{image | "Id" => "two", "Size" => 120}
    unrelated = %{image | "Id" => "external", "RepoTags" => ["other:project"]}

    report =
      Storage.summarize(%{"LayersSize" => 900, "Images" => [image, image, other, unrelated]})

    assert length(report["images"]) == 2
    assert report["owned_unique_bytes"] == 80
    assert report["daemon_image_bytes"] == 900
    report = Storage.summarize(%{"Images" => [Map.put(image, "SharedSize", -1)]})
    assert report["owned_unique_bytes"] == nil
    assert Storage.bytes(nil) == "Unavailable"
    assert_raise RuntimeError, fn -> Storage.summarize(%{}) end
  end
end
