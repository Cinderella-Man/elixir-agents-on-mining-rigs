defmodule Eab.SourceTest do
  use ExUnit.Case, async: false
  alias Eab.{Command, Inventory, Source, Store}

  setup do
    old = Application.fetch_env!(:eab, :data_dir)
    root = Path.join(System.tmp_dir!(), "eab-source-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)
    source = Path.join(root, "upstream")
    File.mkdir_p!(source)

    for args <- [
          ["init", "--quiet"],
          ["config", "user.name", "Fixture"],
          ["config", "user.email", "fixture@localhost"]
        ],
        do: Command.run!("git", args, cd: source)

    File.write!(Path.join(source, "app.ex"), "pristine source")
    Command.run!("git", ["add", "."], cd: source)
    Command.run!("git", ["commit", "--quiet", "-m", "Synthetic source"], cd: source)
    revision = Command.run!("git", ["rev-parse", "HEAD"], cd: source) |> String.trim()
    tree = Command.run!("git", ["rev-parse", "HEAD^{tree}"], cd: source) |> String.trim()

    on_exit(fn ->
      Application.put_env(:eab, :data_dir, old)
      File.rm_rf!(root)
    end)

    %{repo: %{"url" => source, "revision" => revision}, tree: tree}
  end

  test "verified archive is reusable without upstream access and contains no Git history", %{
    repo: repo,
    tree: tree
  } do
    first = Store.path("first")
    File.mkdir_p!(first)
    receipt = Source.snapshot(repo, first, fn _ -> :ok end, expected_tree: tree)
    assert receipt["tree"] == tree
    refute File.exists?(Path.join(first, ".git"))
    File.rename!(repo["url"], repo["url"] <> "-unavailable")
    next = Store.path("next")
    File.mkdir_p!(next)
    assert Source.snapshot(repo, next, fn _ -> :ok end, expected_tree: tree) == receipt
    assert File.read!(Path.join(next, "app.ex")) == "pristine source"
    key = Inventory.hash(Jason.encode!([repo["url"], repo["revision"]]))
    File.write!(Store.path("sources/#{key}.tar"), "corrupt")

    assert_raise RuntimeError, ~r/integrity check/, fn ->
      Source.snapshot(repo, next, fn _ -> :ok end, expected_tree: tree)
    end
  end

  test "a wrong tree fails before an archive is published", %{repo: repo} do
    dest = Store.path("wrong")
    File.mkdir_p!(dest)

    assert_raise RuntimeError, ~r/provenance/, fn ->
      Source.snapshot(repo, dest, fn _ -> :ok end, expected_tree: String.duplicate("0", 40))
    end

    assert Path.wildcard(Store.path("sources/*.json")) == []
  end

  test "retained implementation and tests must reconstruct the exact fixed tree", %{
    repo: repo,
    tree: tree
  } do
    File.write!(Path.join(repo["url"], "app.ex"), "fixed source")
    File.write!(Path.join(repo["url"], "test.exs"), "reference test")
    Command.run!("git", ["add", "."], cd: repo["url"])

    implementation =
      Command.run!("git", ["diff", "--cached", "--binary", "--", "app.ex"], cd: repo["url"])

    tests =
      Command.run!("git", ["diff", "--cached", "--binary", "--", "test.exs"], cd: repo["url"])

    fixed_tree = Command.run!("git", ["write-tree"], cd: repo["url"]) |> String.trim()
    Command.run!("git", ["commit", "--quiet", "-m", "Accepted change"], cd: repo["url"])
    fixed_revision = Command.run!("git", ["rev-parse", "HEAD"], cd: repo["url"]) |> String.trim()
    patches = [Store.path("implementation.patch"), Store.path("tests.patch")]

    Enum.zip(patches, [implementation, tests])
    |> Enum.each(fn {path, body} -> File.write!(path, body) end)

    provenance = %{
      "broken_tree" => tree,
      "fixed_tree" => fixed_tree,
      "fixed_revision" => fixed_revision
    }

    receipt =
      Eab.Provenance.verify_pair(%{"repository" => repo}, provenance, patches, fn _ -> :ok end)

    assert receipt["verified"]
    assert receipt["reconstructed_tree"] == fixed_tree

    assert_raise RuntimeError, ~r/do not reconstruct/, fn ->
      Eab.Provenance.verify_pair(
        %{"repository" => repo},
        provenance,
        Enum.take(patches, 1),
        fn _ -> :ok end
      )
    end
  end
end
