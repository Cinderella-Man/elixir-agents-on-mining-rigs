defmodule Eab.StoreTest do
  use ExUnit.Case, async: false

  test "redaction precedes JSON encoding, including quotes and newlines" do
    secret = "key\"line\nnext"
    data = %{"nested" => [%{"echo" => "before " <> secret <> " after"}]}

    assert Eab.Store.scrub(data, secret) == %{
             "nested" => [%{"echo" => "before [REDACTED] after"}]
           }

    assert Eab.Store.scrub(%{"case_result" => {"case", data}}, secret) == %{
             "case_result" => {"case", %{"nested" => [%{"echo" => "before [REDACTED] after"}]}}
           }
  end

  test "artifact access rejects traversal and symlinked parents" do
    base = Eab.Store.path("runs/artifact-test")
    File.mkdir_p!(base)
    File.write!(Path.join(base, "valid.json"), "{}")
    File.ln_s!(System.tmp_dir!(), Path.join(base, "escape"))
    on_exit(fn -> File.rm_rf!(base) end)
    assert {:ok, _} = Eab.Store.artifact("artifact-test", "valid.json")
    assert :error = Eab.Store.artifact("artifact-test", "../session-secret")
    assert :error = Eab.Store.artifact("../artifact-test", "valid.json")
    assert :error = Eab.Store.artifact("artifact-test", "escape/example.txt")
  end

  test "history pages use compact metadata and isolate corrupt run records" do
    previous = Application.fetch_env!(:eab, :data_dir)
    root = Path.join(System.tmp_dir!(), "eab-history-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)

    on_exit(fn ->
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
    end)

    for n <- 1..23 do
      id = "history-#{String.pad_leading(to_string(n), 3, "0")}"

      run = %{
        "id" => id,
        "created_at" => id,
        "status" => "completed",
        "cases" => [],
        "attempts" => %{},
        "model" => %{"model" => "fixture", "metadata" => %{"large" => "PRIVATE-DETAIL"}}
      }

      Eab.Store.write("runs/#{id}/run.json", run)
      Eab.Store.index_run(run)
    end

    Eab.Store.write_text("runs/broken/run.json", "not valid json")
    assert %{total: 24, items: items} = Eab.Store.run_page(0, 20)
    assert length(items) == 20
    refute Jason.encode!(items) =~ "PRIVATE-DETAIL"
    assert length(Eab.Store.run_page(20).items) == 4
    assert Enum.any?(Eab.Store.runs(), &(&1["status"] == "corrupt"))
    assert File.read!(Eab.Store.path("runs/broken/run.json")) == "not valid json"
  end
end
