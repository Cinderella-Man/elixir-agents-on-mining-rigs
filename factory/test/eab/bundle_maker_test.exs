defmodule Eab.BundleMakerTest do
  use ExUnit.Case, async: false
  alias Eab.{BundleMaker, BundleProbe, Candidates, Command, Inventory, Provenance, Store}

  @url "https://github.com/made-up-org/shopette"

  setup do
    old = Store.root()
    root = Path.join(System.tmp_dir!(), "eab-bundle-maker-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, Path.join(root, "data"))
    upstream = Path.join(root, "upstream")
    File.mkdir_p!(upstream)

    for args <- [
          ["init", "--quiet", "--initial-branch=main"],
          ["config", "user.name", "Synthetic"],
          ["config", "user.email", "test@localhost"],
          ["config", "uploadpack.allowAnySHA1InWant", "true"]
        ],
        do: git(upstream, args)

    commit(upstream, "Start", %{
      "mix.exs" => "defmodule Shopette.MixProject do\n  use Mix.Project\nend\n",
      "LICENSE" => "MIT License\n\nPermission is hereby granted, free of charge, to any person\n",
      "README.md" => "# Shopette\n",
      "lib/shopette.ex" => shop(1),
      "test/test_helper.exs" => "ExUnit.start()\n",
      "test/shopette_test.exs" => shop_test(1)
    })

    recipe = Path.join(root, "recipe.json")

    File.write!(
      recipe,
      Jason.encode!(%{
        "runtime" => %{
          "profile" => "mix",
          "image" => "hexpm/elixir:made-up",
          "environment" => %{"MIX_ENV" => "test"},
          "setup_commands" => ["mix compile"],
          "before_test_commands" => []
        },
        "test_timeout" => 120,
        "grading" => %{"protected_paths" => ["test/"], "preservation" => "mix test"}
      })
    )

    on_exit(fn ->
      Application.put_env(:eab, :data_dir, old)
      File.rm_rf!(root)
    end)

    opts = [
      recipe: recipe,
      out: Path.join(root, "tasks"),
      cache: Path.join(root, "cache"),
      fetch_url: upstream
    ]

    %{root: root, upstream: upstream, opts: opts}
  end

  defp git(dir, args), do: Command.run!("git", args, cd: dir, quiet: true)

  defp commit(dir, message, files) do
    for {file, contents} <- files do
      path = Path.join(dir, file)

      case contents do
        nil ->
          File.rm!(path)

        {:symlink, target} ->
          File.mkdir_p!(Path.dirname(path))
          File.ln_s!(target, path)

        contents ->
          File.mkdir_p!(Path.dirname(path))
          File.write!(path, contents)
      end
    end

    git(dir, ["add", "--all"])
    git(dir, ["commit", "--quiet", "-m", message])
    git(dir, ["rev-parse", "HEAD"]) |> String.trim()
  end

  defp shop(1) do
    """
    defmodule Shopette do
      def total(items), do: Enum.sum(items)

      def first(items), do: hd(items)

      def count(items), do: length(items)

      def last(items), do: List.last(items)

      def empty?(items), do: items == []
    end
    """
  end

  defp shop(2) do
    """
    defmodule Shopette do
      def total(items), do: items |> Enum.reject(&(&1 < 0)) |> Enum.sum()

      def first(items), do: hd(items)

      def count(items), do: length(items)

      def last(items), do: List.last(items)

      def empty?(items), do: Enum.empty?(items)
    end
    """
  end

  defp shop_test(1) do
    """
    defmodule ShopetteTest do
      use ExUnit.Case

      describe "total/1" do
        test "adds the items" do
          assert Shopette.total([1, 2]) == 3
        end
      end

      test "counts the items" do
        assert Shopette.count([1, 2]) == 2
      end
    end
    """
  end

  defp shop_test(2) do
    """
    defmodule ShopetteTest do
      use ExUnit.Case

      describe "total/1" do
        test "adds the items" do
          assert Shopette.total([1, 2, -4]) == 3
        end

        test "skips returns" do
          assert Shopette.total([-1]) == 0
        end
      end

      test "counts the items" do
        assert Shopette.count([1, 2]) == 2
      end
    end
    """
  end

  # A pull request merged as one commit: two hunks in one code file, a new code file, a migration, a CI file, a
  # changed test file, a test support file and two documentation files.
  defp squash(upstream) do
    start = git(upstream, ["rev-parse", "HEAD"]) |> String.trim()

    merge =
      commit(upstream, "Skip returns in totals (#7)", %{
        "lib/shopette.ex" => shop(2),
        "lib/shopette/price.ex" =>
          "defmodule Shopette.Price do\n  def cents(x), do: x * 100\nend\n",
        "priv/repo/migrations/1_add_returns.exs" => "defmodule AddReturns do\nend\n",
        ".github/workflows/ci.yml" => "name: CI\n",
        "test/shopette_test.exs" => shop_test(2),
        "test/support/factory.ex" => "defmodule Factory do\nend\n",
        "README.md" => "# Shopette\n\nReturns are skipped.\n",
        "docs/returns.md" => "Returns\n"
      })

    paths =
      ~w(lib/shopette.ex lib/shopette/price.ex priv/repo/migrations/1_add_returns.exs .github/workflows/ci.yml
        test/shopette_test.exs test/support/factory.ex README.md docs/returns.md)

    {start, merge, paths}
  end

  defp request(merge, paths, number \\ 7),
    do: %{
      "repository" => @url,
      "number" => number,
      "merge_commit" => merge,
      "merged_at" => "2026-04-01T10:00:00Z",
      "paths" => paths,
      "verdict" => "candidate",
      "marks" => ["adds_migration"]
    }

  test "a squash-merged pull request becomes a task that rebuilds the merged tree and passes the import check",
       %{
         upstream: upstream,
         opts: opts
       } do
    {start, merge, paths} = squash(upstream)
    summary = BundleMaker.make(request(merge, paths), opts)
    dir = summary["dir"]

    assert summary["id"] == "shopette-pr-7"
    assert summary["start_revision"] == start
    assert summary["walked"] == 0
    assert summary["code_files"] == 4
    assert summary["test_files"] == 2
    assert summary["docs_files"] == 2
    assert summary["recipe"] == "final"

    assert Enum.sort(File.ls!(dir)) ==
             ~w(case.json incomplete.patch integrity.patch provenance.json reference-tests.patch
               reference.patch upstream-docs.patch)

    spec = Inventory.read_json(Path.join(dir, "case.json"))
    provenance = Inventory.read_json(Path.join(dir, "provenance.json"))

    assert spec["schema_version"] == 3
    assert spec["task_kind"] == "feature"
    assert spec["project"] == "shopette"
    assert spec["repository"] == %{"url" => @url, "revision" => start}
    assert spec["test_timeout"] == 120
    assert spec["allowed_edit_prefixes"] == [".github/", "lib/", "priv/", "test/"]
    assert spec["grading"]["acceptance"] == "mix test test/shopette_test.exs"
    assert spec["grading"]["preservation"] == "mix test"

    # Only the tests whose body the pull request changes; the unchanged one is not a hidden test's name.
    assert spec["grading"]["required"] == [
             "Elixir.ShopetteTest::test total/1 adds the items",
             "Elixir.ShopetteTest::test total/1 skips returns"
           ]

    assert spec["grading"]["starting_failures"] == spec["grading"]["required"]
    assert spec["partial_control"] == %{"present" => true}
    refute Map.has_key?(spec, "clarifications")
    refute File.exists?(Path.join(dir, "ticket.md"))

    assert provenance["pull_request"] == "#{@url}/pull/7"

    assert provenance["pair_selection"] ==
             "first parent of the merge commit, and the merge commit"

    assert provenance["licence"] == "MIT"
    assert provenance["merged_at"] == "2026-04-01"
    assert provenance["marks"] == ["adds_migration"]

    docs = File.read!(Path.join(dir, "upstream-docs.patch"))
    assert docs =~ "diff --git a/README.md b/README.md"
    assert docs =~ "diff --git a/docs/returns.md b/docs/returns.md"
    assert File.read!(Path.join(dir, "reference-tests.patch")) =~ "test/support/factory.ex"
    assert File.read!(Path.join(dir, "integrity.patch")) =~ "+++ b/lib/eab_halt.ex"

    # The engine's source check, with the upstream repository standing in for GitHub.
    patches =
      Enum.map(~w(reference.patch reference-tests.patch upstream-docs.patch), &Path.join(dir, &1))

    local = Map.put(spec, "repository", %{"url" => upstream, "revision" => start})
    receipt = Provenance.verify_pair(local, provenance, patches, fn _ -> :ok end)
    assert receipt["verified"]
    assert receipt["reconstructed_tree"] == provenance["fixed_tree"]

    ref = Candidates.import(dir)
    assert Candidates.read!(ref)["id"] == "shopette-pr-7"

    assert_raise BundleMaker.Refusal, ~r/exists/, fn ->
      BundleMaker.make(request(merge, paths), opts)
    end
  end

  test "a rebase merge walks back first parents until the census's paths match", %{
    upstream: upstream,
    opts: opts
  } do
    start = git(upstream, ["rev-parse", "HEAD"]) |> String.trim()
    commit(upstream, "Fix totals", %{"lib/shopette.ex" => shop(2)})
    commit(upstream, "Price", %{"lib/shopette/price.ex" => "defmodule P do\nend\n"})
    merge = commit(upstream, "Test", %{"test/shopette_test.exs" => shop_test(2)})
    paths = ~w(lib/shopette.ex lib/shopette/price.ex test/shopette_test.exs)

    summary = BundleMaker.make(request(merge, paths, 8), opts)
    assert summary["start_revision"] == start
    assert summary["walked"] == 2

    assert Inventory.read_json(Path.join(summary["dir"], "provenance.json"))["pair_selection"] ==
             "the commit 3 first parents before the merge commit, and the merge commit"

    row = BundleMaker.make_one(request(merge, ["lib/elsewhere.ex"], 9), opts)
    assert row["result"] == "refused"
    assert row["reason"] == "paths_never_match"
  end

  test "refusals: the hold-out list, the screen, links, binary files, and no code or no test part",
       %{
         root: root,
         upstream: upstream,
         opts: opts
       } do
    {_, merge, paths} = squash(upstream)

    holdout = fn url ->
      BundleMaker.make_one(Map.put(request(merge, paths), "repository", url), opts)
    end

    for url <- [
          "https://github.com/plausible/analytics",
          "https://github.com/livebook-dev/kino",
          "https://github.com/someone/livebook",
          "https://github.com/Cinderella-Man/vutuv"
        ],
        do: assert(%{"result" => "refused", "reason" => "holdout"} = holdout.(url))

    rejected = Map.merge(request(merge, paths), %{"verdict" => "rejected", "reason" => "bot"})

    assert %{"reason" => "screen_rejected", "detail" => "bot"} =
             BundleMaker.make_one(rejected, opts)

    cases = [
      {"symbolic_link",
       %{"lib/link.ex" => {:symlink, "shopette.ex"}, "test/a_test.exs" => "x\n"}},
      {"binary_file", %{"lib/logo.png" => <<0, 1, 2, 255, 0>>, "test/b_test.exs" => "x\n"}},
      {"no_test_part", %{"lib/shopette.ex" => shop(1) <> "# more\n"}},
      {"no_code_part", %{"test/shopette_test.exs" => shop_test(1)}},
      {"no_test_names",
       %{"lib/c.ex" => "defmodule C do\nend\n", "test/c_test.exs" => "# no test\n"}}
    ]

    results = Path.join(root, "results.tsv")

    requests =
      for {{_, files}, n} <- Enum.with_index(cases, 20) do
        merge = commit(upstream, "Case #{n}", files)
        request(merge, nil, n)
      end

    rows = BundleMaker.make_list(requests, Keyword.put(opts, :results, results))
    assert Enum.map(rows, & &1["reason"]) == Enum.map(cases, &elem(&1, 0))

    [header | lines] = results |> File.read!() |> String.split("\n", trim: true)
    assert header == Enum.join(BundleMaker.columns(), "\t")
    assert length(lines) == length(cases)
    assert Enum.all?(lines, &(&1 =~ "\trefused\t"))
    assert File.ls(opts[:out]) in [{:ok, []}, {:error, :enoent}]
  end

  test "test names follow the reporter's form and the changed lines" do
    source = """
    defmodule My.ThingTest do
      use ExUnit.Case

      setup do
        :ok
      end

      describe "build/1" do
        test "keeps the name", %{} do
          assert 1 == 1
        end

        test "drops blanks" do
          assert 2 == 2
        end
      end

      test "plain" do
        assert true
      end

      test "pending"

      for n <- 1..2 do
        test "generated \#{n}" do
          assert n
        end
      end

      defmodule Inner do
        use ExUnit.Case
        test "nested", do: assert(true)
      end
    end
    """

    assert BundleMaker.test_names(source) == [
             "Elixir.My.ThingTest::test build/1 keeps the name",
             "Elixir.My.ThingTest::test build/1 drops blanks",
             "Elixir.My.ThingTest::test plain",
             "Elixir.My.ThingTest.Inner::test nested"
           ]

    assert BundleMaker.test_names(source, MapSet.new([14])) == [
             "Elixir.My.ThingTest::test build/1 drops blanks"
           ]

    assert BundleMaker.test_names(source, MapSet.new([5])) == []
    assert BundleMaker.test_names("defmodule (", :all) == []

    block = "diff --git a/t b/t\n--- a/t\n+++ b/t\n@@ -3,4 +3,5 @@ x\n a\n-b\n+c\n+d\n e\n f\n"
    assert BundleMaker.changed_lines(block) == MapSet.new([4, 5])
  end

  test "partial-fix variants leave out one file, then one hunk, with later hunks renumbered" do
    one = """
    diff --git a/lib/a.ex b/lib/a.ex
    --- a/lib/a.ex
    +++ b/lib/a.ex
    @@ -1,3 +1,4 @@
     a
    +b
     c
     d
    @@ -10,3 +11,3 @@ x
     j
    -k
    +K
     l
    """

    two = """
    diff --git a/lib/b.ex b/lib/b.ex
    --- a/lib/b.ex
    +++ b/lib/b.ex
    @@ -1 +1 @@
    -x
    +y
    """

    [no_a, no_b, no_first_hunk, no_second_hunk] = BundleProbe.variants(one <> two)
    assert no_a == two
    assert no_b == one
    assert no_first_hunk =~ "@@ -10,3 +10,3 @@ x"
    refute no_first_hunk =~ "+b\n"
    assert no_second_hunk =~ "@@ -1,3 +1,4 @@"
    refute no_second_hunk =~ "+K\n"
    assert BundleProbe.variants(two) == []
    assert BundleProbe.search(two, ["t"], fn _ -> flunk("no run") end) == {:absent, "single_hunk"}
  end

  test "observing and searching decide from the hidden runs" do
    result = fn states, phases ->
      %{"completed" => true, "test_results" => states, "failure_phases" => phases}
    end

    start = result.(%{"M::test a" => "failed", "M::test b" => "passed"}, %{"M::test a" => "test"})
    fixed = result.(%{"M::test a" => "passed", "M::test b" => "passed"}, %{})
    runs = %{"" => start, "REF" => fixed}

    assert BundleProbe.observe("REF", &runs[&1]) ==
             {:ok,
              %{"required" => ["M::test a", "M::test b"], "starting_failures" => ["M::test a"]}}

    assert {:error, "start_run_did_not_finish", _} =
             BundleProbe.observe("REF", &Map.put(runs, "", %{"completed" => false})[&1])

    broken = result.(%{"M::test a" => "failed"}, %{"M::test a" => "test"})

    assert {:error, "reference_fails_hidden", "M::test a"} =
             BundleProbe.observe("REF", &Map.put(runs, "REF", broken)[&1])

    setup_only = result.(%{"M::test a" => "failed"}, %{"M::test a" => "setup"})

    assert {:error, "no_starting_failure", _} =
             BundleProbe.observe("REF", &Map.put(runs, "", setup_only)[&1])

    reference =
      "diff --git a/lib/a.ex b/lib/a.ex\n--- a/lib/a.ex\n+++ b/lib/a.ex\n@@ -1 +1 @@\n-a\n+b\n" <>
        "diff --git a/lib/c.ex b/lib/c.ex\n--- a/lib/c.ex\n+++ b/lib/c.ex\n@@ -1 +1 @@\n-c\n+d\n"

    [first, second] = BundleProbe.variants(reference)
    compiles_not = %{"completed" => false, "test_results" => %{}}

    assert BundleProbe.search(reference, ["M::test a"], fn _ -> compiles_not end) ==
             {:absent, "no_variant_compiles"}

    assert BundleProbe.search(reference, ["M::test a"], fn _ -> fixed end) ==
             {:absent, "no_variant_fails"}

    assert BundleProbe.search(reference, ["M::test a"], &%{first => fixed, second => start}[&1]) ==
             {:present, second}
  end

  test "the hold-out list holds the plan's 12 projects, and recipes hold exactly the per-project fields" do
    list = Inventory.read_json(Inventory.path("config/holdout.json"))

    assert Enum.map(list["projects"], & &1["project"]) ==
             ~w(absinthe accent ash beacon cachex guardian live_beats livebook operately pinchflat
               plausible-analytics vutuv)

    recipe = BundleMaker.read_recipe!(Inventory.path("recipes/axelclark__ex338.json"))
    refute Map.has_key?(recipe, "provisional")
    assert recipe["grading"]["protected_paths"] == ["test/"]

    write = fn recipe ->
      path = Path.join(System.tmp_dir!(), "eab-recipe-#{System.unique_integer([:positive])}.json")
      File.write!(path, Jason.encode!(recipe))
      path
    end

    provisional = write.(Map.put(recipe, "provisional", "a note"))
    assert BundleMaker.read_recipe!(provisional)["provisional"] == "a note"
    File.rm(provisional)

    for bad <- [
          Map.put(recipe, "task_kind", "bug_fix"),
          put_in(recipe, ["grading", "test_suffixes"], [".exs"]),
          put_in(recipe, ["grading", "required"], ["x"]),
          put_in(recipe, ["grading", "preservation"], "make test")
        ] do
      path = write.(bad)

      try do
        assert_raise BundleMaker.Refusal, ~r/recipe/, fn -> BundleMaker.read_recipe!(path) end
      after
        File.rm(path)
      end
    end
  end
end
