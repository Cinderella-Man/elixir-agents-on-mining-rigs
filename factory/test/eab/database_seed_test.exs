defmodule Eab.DatabaseSeedTest do
  use ExUnit.Case, async: true
  alias Eab.DatabaseSeed

  setup do
    root = Path.join(System.tmp_dir!(), "eab-migrations-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    %{
      root: root,
      spec: %{"repository" => %{"url" => "test"}, "runtime" => %{"environment" => %{}}}
    }
  end

  defp put(root, path, content) do
    file = Path.join(root, path)
    File.mkdir_p!(Path.dirname(file))
    File.write!(file, content)
  end

  test "only forward unchanged migration prefixes can seed a target", %{root: root, spec: spec} do
    put(
      root,
      "priv/repo/migrations/001_first.exs",
      "defmodule First do\n use Ecto.Migration\nend"
    )

    first = DatabaseSeed.describe(root, spec)

    put(
      root,
      "priv/repo/migrations/002_second.exs",
      "defmodule Second do\n use Ecto.Migration\nend"
    )

    second = DatabaseSeed.describe(root, spec)
    assert DatabaseSeed.compatible?(first, second)
    refute DatabaseSeed.compatible?(second, first)

    put(
      root,
      "priv/repo/migrations/001_first.exs",
      "defmodule First do\n def changed, do: true\nend"
    )

    refute DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
  end

  test "shortened/renamed helper aliases, dependency versions and priv data invalidate seeds", %{
    root: root,
    spec: spec
  } do
    put(
      root,
      "priv/repo/migrations/001_first.exs",
      "alias Demo.DataMigration, as: DM\nDM.SiteImports.run()"
    )

    put(
      root,
      "lib/imports.ex",
      "defmodule Demo.DataMigration.SiteImports do\n def run, do: :old\nend"
    )

    first = DatabaseSeed.describe(root, spec)

    put(
      root,
      "lib/imports.ex",
      "defmodule Demo.DataMigration.SiteImports do\n def run, do: :new\nend"
    )

    refute DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
    first = DatabaseSeed.describe(root, spec)
    put(root, "mix.lock", "new dependency lock")
    refute DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
    first = DatabaseSeed.describe(root, spec)
    put(root, "priv/data.csv", "new input")
    refute DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
  end

  test "opaque migration helpers include all app source and cross-repo suffixes are rejected", %{
    root: root,
    spec: spec
  } do
    put(root, "priv/repo/migrations/001_first.exs", "apply(get_module(), :run, [])")
    put(root, "lib/hidden.ex", "defmodule Hidden do\n def value, do: 1\nend")
    first = DatabaseSeed.describe(root, spec)
    put(root, "lib/hidden.ex", "defmodule Hidden do\n def value, do: 2\nend")
    refute DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
    first = DatabaseSeed.describe(root, spec)
    put(root, "priv/repo/migrations/002_second.exs", "Plausible.IngestRepo.query!(\"sql\")")
    refute DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
  end

  test "an unrelated app change can reuse statically understood migrations", %{
    root: root,
    spec: spec
  } do
    put(
      root,
      "priv/repo/migrations/001_first.exs",
      "defmodule First do\n use Ecto.Migration\n def change, do: execute(\"SELECT 1\")\nend"
    )

    first = DatabaseSeed.describe(root, spec)
    put(root, "lib/ui.ex", "defmodule UI do\n def render, do: :new\nend")
    assert DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
  end

  test "nested modules and literal module atoms cannot hide changed helpers", %{
    root: root,
    spec: spec
  } do
    put(root, "priv/repo/migrations/001_first.exs", "Demo.Helper.run()")

    put(
      root,
      "lib/helper.ex",
      "defmodule Demo do\n defmodule Helper do\n def run, do: :old\n end\nend"
    )

    first = DatabaseSeed.describe(root, spec)

    put(
      root,
      "lib/helper.ex",
      "defmodule Demo do\n defmodule Helper do\n def run, do: :new\n end\nend"
    )

    refute DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
    put(root, "priv/repo/migrations/001_first.exs", ~s|:"Elixir.Demo.Helper".run()|)
    first = DatabaseSeed.describe(root, spec)
    put(root, "lib/helper.ex", "defmodule Demo.Helper do\n def run, do: :another\nend")
    refute DatabaseSeed.compatible?(first, DatabaseSeed.describe(root, spec))
  end

  test "shared cyclic helpers preserve every transitive dependency", %{root: root, spec: spec} do
    put(root, "lib/one.ex", "defmodule One do\n def run, do: Two.run()\nend")
    put(root, "lib/two.ex", "defmodule Two do\n def run, do: One.run()\nend")

    for n <- 1..3 do
      put(root, "priv/repo/migrations/00#{n}_change.exs", "One.run()")
    end

    first = DatabaseSeed.describe(root, spec)
    put(root, "lib/two.ex", "defmodule Two do\n def run, do: {One.run(), :changed}\nend")
    second = DatabaseSeed.describe(root, spec)
    refute DatabaseSeed.compatible?(first, second)

    for {before, after_} <-
          Enum.zip(first["migrations"]["postgres"], second["migrations"]["postgres"]) do
      assert before["content"] == after_["content"]
      refute before["dependencies"] == after_["dependencies"]
    end
  end
end
