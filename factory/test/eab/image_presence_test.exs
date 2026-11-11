defmodule Eab.ImagePresenceTest do
  use ExUnit.Case, async: true
  alias Eab.ImagePresence

  test "500 unique images use bounded batches, preserving IDs and digest aliases" do
    parent = self()
    images = Enum.map(1..500, &"sha256:#{&1}")

    result =
      ImagePresence.existing(images ++ images, fn batch ->
        send(parent, {:batch, length(batch)})

        %{
          "returncode" => 0,
          "output_truncated" => false,
          "output" =>
            Enum.map_join(batch, "\n", &Jason.encode!(%{"id" => &1, "digests" => ["repo@#{&1}"]}))
        }
      end)

    assert MapSet.size(result) == 1000
    assert_receive {:batch, 200}
    assert_receive {:batch, 200}
    assert_receive {:batch, 100}
    refute_receive {:batch, _}
    assert ImagePresence.existing([], fn _ -> flunk("unexpected Docker call") end) == MapSet.new()
  end

  test "partial missing images remain misses but inspection failures never look like an empty cache" do
    result = %{
      "returncode" => 1,
      "output_truncated" => false,
      "output" =>
        "{\"id\":\"present\",\"tags\":[\"repo:tag\"]}\nError response from daemon: No such image: gone"
    }

    assert ImagePresence.identities(result) == MapSet.new(["present", "repo:tag"])

    assert_raise RuntimeError, fn ->
      ImagePresence.identities(%{result | "output_truncated" => true})
    end

    assert_raise RuntimeError, fn ->
      ImagePresence.identities(%{result | "output" => "Cannot connect to Docker"})
    end
  end
end
