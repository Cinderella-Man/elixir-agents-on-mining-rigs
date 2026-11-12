defmodule Eab.ReleaseFilesTest do
  use ExUnit.Case, async: false
  alias Eab.{ReleaseFiles, Store}

  @body "a release file made up for this test\n"

  setup do
    old =
      Map.new(
        [:data_dir, :release_file_hosts, :release_file_request],
        &{&1, Application.get_env(:eab, &1)}
      )

    root = Path.join(System.tmp_dir!(), "eab-release-files-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)

    Application.put_env(:eab, :release_file_hosts, [
      "releases.example.test",
      "assets.example.test"
    ])

    on_exit(fn ->
      for {key, value} <- old, do: Application.put_env(:eab, key, value)
      File.rm_rf!(root)
    end)

    sha = :crypto.hash(:sha256, @body) |> Base.encode16(case: :lower)

    entry = %{
      "url" => "https://releases.example.test/tool_1.0_amd64.deb",
      "sha256" => sha,
      "kind" => "deb"
    }

    %{root: root, entry: entry, sha: sha}
  end

  # A stand-in for Req: the allowed release host redirects to an allowed asset host, as GitHub's releases do.
  defp serve(test, routes) do
    Application.put_env(:eab, :release_file_request, fn opts ->
      send(test, {:fetched, opts[:url]})
      refute opts[:redirect]

      case Map.fetch(routes, opts[:url]) do
        {:ok, {:redirect, to}} ->
          {:ok, Req.Response.new(status: 302, headers: %{"location" => [to]})}

        {:ok, body} ->
          {:ok, Req.Response.new(status: 200, body: body)}

        :error ->
          {:ok, Req.Response.new(status: 404, body: "")}
      end
    end)
  end

  test "a release file is fetched from an allowed host, checked, kept and staged under its SHA-256",
       %{
         root: root,
         entry: entry,
         sha: sha
       } do
    serve(self(), %{
      entry["url"] => {:redirect, "https://assets.example.test/blob/1"},
      "https://assets.example.test/blob/1" => @body
    })

    dest = Path.join(root, "build")
    assert ReleaseFiles.stage!([entry], dest, fn _ -> :ok end) == :ok
    assert File.read!(Path.join(dest, "release-files/#{sha}.deb")) == @body
    assert File.read!(Store.path("release-files/#{sha}.deb")) == @body
    assert_received {:fetched, "https://releases.example.test/tool_1.0_amd64.deb"}
    assert_received {:fetched, "https://assets.example.test/blob/1"}

    # The kept copy is reused: nothing is fetched the second time.
    serve(self(), %{})
    File.rm_rf!(dest)
    assert ReleaseFiles.stage!([entry], dest, fn _ -> :ok end) == :ok
    assert File.read!(Path.join(dest, "release-files/#{sha}.deb")) == @body
    refute_received {:fetched, _}

    # An empty list stages nothing.
    other = Path.join(root, "plain")
    assert ReleaseFiles.stage!([], other, fn _ -> :ok end) == :ok
    refute File.exists?(other)
  end

  test "a wrong checksum, a host that is not allowed and a redirect off the list fail before anything is kept",
       %{
         root: root,
         entry: entry,
         sha: sha
       } do
    dest = Path.join(root, "build")

    serve(self(), %{entry["url"] => "other bytes"})

    assert_raise RuntimeError, ~r/checksum mismatch/, fn ->
      ReleaseFiles.stage!([entry], dest, fn _ -> :ok end)
    end

    serve(self(), %{entry["url"] => {:redirect, "https://elsewhere.example.test/blob"}})

    assert_raise RuntimeError, ~r/not allowed/, fn ->
      ReleaseFiles.stage!([entry], dest, fn _ -> :ok end)
    end

    refute_received {:fetched, "https://elsewhere.example.test/blob"}

    serve(self(), %{"https://elsewhere.example.test/tool.deb" => @body})

    assert_raise RuntimeError, ~r/not allowed/, fn ->
      ReleaseFiles.stage!(
        [Map.put(entry, "url", "https://elsewhere.example.test/tool.deb")],
        dest,
        fn _ -> :ok end
      )
    end

    refute_received {:fetched, "https://elsewhere.example.test/tool.deb"}

    Application.put_env(:eab, :release_file_hosts, [])
    serve(self(), %{entry["url"] => @body})

    assert_raise RuntimeError, ~r/not allowed/, fn ->
      ReleaseFiles.stage!([entry], dest, fn _ -> :ok end)
    end

    refute File.exists?(Store.path("release-files/#{sha}.deb"))
  end
end
