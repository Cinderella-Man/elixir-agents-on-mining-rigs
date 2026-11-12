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

    # The existing test file the pull request changes; lib/shopette/price.ex has no test file at the start.
    assert spec["grading"]["preservation"] == "mix test test/shopette_test.exs"

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

  test "a template resolves the toolchain from the starting commit, records each source, and refuses what it cannot serve",
       %{root: root, upstream: upstream, opts: opts} do
    pin = &"@sha256:#{String.duplicate(&1, 64)}"
    table = Path.join(root, "toolchain_images.json")

    File.write!(
      table,
      Jason.encode!(%{
        "elixir" => [
          %{
            "elixir" => "1.17.2",
            "otp" => "27.0.1",
            "image" => "hexpm/elixir:1.17.2-erlang-27.0.1-made-up" <> pin.("a")
          }
        ],
        "postgres" => [%{"version" => "14", "image" => "postgres:14.24-alpine" <> pin.("b")}],
        "service_clients" => %{"redis" => ["redix"]}
      })
    )

    template = Path.join(root, "template.json")
    recipe = opts[:recipe] |> File.read!() |> Jason.decode!()

    File.write!(
      template,
      Jason.encode!(
        Map.merge(recipe, %{
          "baseline" => %{"mode" => "prepared", "commands" => ["mix ecto.create --quiet"]},
          "toolchain" => %{
            "baseline" => [
              %{"commands" => ["mix ecto.create --quiet", "mix ecto.migrate --quiet"]}
            ],
            "ci_services_not_needed" => %{"redis" => "not used by the tests"}
          }
        })
      )
    )

    opts = Keyword.merge(opts, recipe: template, toolchain_table: table)

    workflow =
      "jobs:\n  test:\n    services:\n      postgres:\n        image: postgres:14\n      redis:\n        image: redis\n"

    commit(upstream, "Toolchain", %{
      ".tool-versions" => "elixir 1.17.2-otp-27\nerlang 27.0.1\n",
      ".github/workflows/test.yml" => workflow
    })

    {start, merge, paths} = squash(upstream)
    summary = BundleMaker.make(request(merge, paths), opts)
    assert summary["toolchain"] == "1.17.2/27.0.1"

    spec = Inventory.read_json(Path.join(summary["dir"], "case.json"))
    assert spec["runtime"]["image"] == "hexpm/elixir:1.17.2-erlang-27.0.1-made-up" <> pin.("a")
    assert spec["runtime"]["setup_commands"] == ["mix compile"]
    assert spec["services"] == %{"postgres" => %{"image" => "postgres:14.24-alpine" <> pin.("b")}}
    assert spec["baseline"]["commands"] == ["mix ecto.create --quiet", "mix ecto.migrate --quiet"]
    refute Map.has_key?(spec, "toolchain")

    record = Inventory.read_json(Path.join(summary["dir"], "provenance.json"))["toolchain"]
    assert record["elixir"] == %{"value" => "1.17.2", "source" => ".tool-versions"}
    assert record["image"]["source"] == "config/toolchain_images.json: 1.17.2/27.0.1"
    assert record["postgres"]["source"] =~ ".github/workflows/test.yml: postgres:14"
    assert record["services_checked"]["not_needed_by_template"] == ["redis"]

    # The resolver alone, as `resolve` runs it over a list
    [row] = BundleMaker.resolve_list([request(merge, paths)], opts)
    assert {row["result"], row["start_revision"], row["elixir"]} == {"resolved", start, "1.17.2"}
    assert row["postgres"] == "postgres:14.24-alpine" <> pin.("b")

    # A Redis client in mix.exs, and a pair the table lacks
    commit(upstream, "Redis", %{
      "mix.exs" =>
        ~s|defmodule Shopette.MixProject do\n  defp deps, do: [{:redix, "~> 1.3"}]\nend\n|
    })

    {_, merge2, paths2} = squash_again(upstream)
    row = BundleMaker.make_one(request(merge2, paths2, 40), opts)
    assert {row["result"], row["reason"]} == {"refused", "needs_service:redis"}

    commit(upstream, "Old Elixir", %{
      "mix.exs" => "defmodule Shopette.MixProject do\nend\n",
      ".tool-versions" => "elixir 1.16.3\nerlang 26.2.5\n"
    })

    {_, merge3, paths3} = squash_again(upstream)
    row = BundleMaker.make_one(request(merge3, paths3, 41), opts)
    assert {row["result"], row["reason"]} == {"refused", "no_image:1.16.3/26.2.5"}

    assert BundleMaker.resolve_one(request(merge3, paths3, 41), opts)["reason"] ==
             "no_image:1.16.3/26.2.5"

    # A plain recipe (no toolchain block) is used as it is
    plain =
      BundleMaker.make(
        request(merge3, paths3, 42),
        Keyword.put(opts, :recipe, Path.join(root, "recipe.json"))
      )

    assert plain["toolchain"] == "recipe"

    assert Inventory.read_json(Path.join(plain["dir"], "case.json"))["runtime"]["image"] ==
             "hexpm/elixir:made-up"
  end

  # A second pull request on top of whatever the upstream holds now: one code change and one test change.
  defp squash_again(upstream) do
    start = git(upstream, ["rev-parse", "HEAD"]) |> String.trim()
    n = System.unique_integer([:positive])

    merge =
      commit(upstream, "Change #{n}", %{
        "lib/shopette.ex" => shop(1) <> "\n# change #{n}\n",
        "test/shopette_test.exs" =>
          String.replace(shop_test(1), "[1, 2]) == 2", "[1, 2, #{n}]) == 3")
      })

    {start, merge, ~w(lib/shopette.ex test/shopette_test.exs)}
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

  test "the existing tests' command names changed test files and test files that match changed code files",
       %{upstream: upstream, opts: opts} do
    # A code file whose test file exists at the start, and a new test file: the command names the matching file.
    commit(upstream, "Price", %{
      "lib/shopette/price.ex" => "defmodule Shopette.Price do\n  def cents(x), do: x\nend\n",
      "test/shopette/price_test.exs" =>
        "defmodule Shopette.PriceTest do\n  use ExUnit.Case\n  test \"cents\", do: assert(Shopette.Price.cents(1) == 1)\nend\n"
    })

    merge =
      commit(upstream, "Price in cents (#30)", %{
        "lib/shopette/price.ex" =>
          "defmodule Shopette.Price do\n  def cents(x), do: x * 100\nend\n",
        "test/shopette/cents_test.exs" =>
          "defmodule Shopette.CentsTest do\n  use ExUnit.Case\n  test \"cents\", do: assert(Shopette.Price.cents(1) == 100)\nend\n"
      })

    summary = BundleMaker.make(request(merge, nil, 30), opts)
    spec = Inventory.read_json(Path.join(summary["dir"], "case.json"))
    assert spec["grading"]["preservation"] == "mix test test/shopette/price_test.exs"
    assert spec["grading"]["acceptance"] == "mix test test/shopette/cents_test.exs"

    # A new code file and a new test file only: no existing test file, so no task.
    merge =
      commit(upstream, "Tax (#31)", %{
        "lib/shopette/tax.ex" => "defmodule Shopette.Tax do\n  def rate, do: 0\nend\n",
        "test/shopette/tax_test.exs" =>
          "defmodule Shopette.TaxTest do\n  use ExUnit.Case\n  test \"rate\", do: assert(Shopette.Tax.rate() == 0)\nend\n"
      })

    assert %{"result" => "refused", "reason" => "no_existing_tests"} =
             BundleMaker.make_one(request(merge, nil, 31), opts)

    block = fn path, status -> %{path: path, status: status, text: ""} end

    assert BundleMaker.existing_tests(
             [
               block.("test/a_test.exs", :modified),
               block.("test/b_test.exs", :deleted),
               block.("test/c_test.exs", :added),
               block.("test/support/helper.ex", :modified)
             ],
             [
               block.("lib/x/y.ex", :modified),
               block.("lib/z.ex", :deleted),
               block.("lib/none.ex", :modified),
               block.("config/config.exs", :modified)
             ],
             ["test/"],
             &(&1 in ~w(test/x/y_test.exs test/z_test.exs test/a_test.exs))
           ) == ~w(test/a_test.exs test/b_test.exs test/x/y_test.exs test/z_test.exs)

    assert BundleMaker.test_path("lib/a/b.ex", ["test/"]) == "test/a/b_test.exs"
    assert BundleMaker.test_path("lib/a/b.exs", ["test/"]) == nil
    assert BundleMaker.test_path("priv/a.ex", ["test/"]) == nil
  end

  test "settling the existing tests leaves out files that fail or change between runs" do
    result = fn states ->
      %{"completed" => true, "test_results" => states, "failure_phases" => %{}}
    end

    files = ~w(test/a_test.exs test/b_test.exs test/c_test.exs test/d_test.exs)
    modules = Map.new(files, fn f -> {f, [Macro.camelize(Path.basename(f, ".exs"))]} end)
    pass = Map.new(~w(A B C D), &{"Elixir.#{&1}Test::test t", "passed"})

    # B changes between the two runs of the unchanged project, D fails there, A fails on the reference.
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    run = fn
      "", _files ->
        n = Agent.get_and_update(counter, &{&1, &1 + 1})

        result.(
          pass
          |> Map.put("Elixir.DTest::test t", "failed")
          |> Map.put("Elixir.BTest::test t", if(n == 0, do: "failed", else: "passed"))
        )

      "REF", _files ->
        result.(Map.put(pass, "Elixir.ATest::test t", "failed"))
    end

    assert BundleProbe.settle(files, "REF", modules, run) ==
             {:ok, ["test/c_test.exs"],
              [
                %{"file" => "test/a_test.exs", "reason" => "fails_on_reference"},
                %{"file" => "test/b_test.exs", "reason" => "unstable"},
                %{"file" => "test/d_test.exs", "reason" => "fails_on_unchanged"}
              ]}

    # When the run of all files does not finish on a side, each file runs alone there.
    run = fn
      "", _files ->
        result.(pass)

      "REF", [_, _ | _] ->
        %{"completed" => false, "test_results" => %{}}

      "REF", ["test/b_test.exs"] ->
        %{"completed" => false, "test_results" => %{}}

      "REF", [file] ->
        name = Macro.camelize(Path.basename(file, ".exs"))
        result.(%{"Elixir.#{name}::test t" => "passed"})
    end

    assert BundleProbe.settle(files, "REF", modules, run) ==
             {:ok, ~w(test/a_test.exs test/c_test.exs test/d_test.exs),
              [%{"file" => "test/b_test.exs", "reason" => "does_not_finish_on_reference"}]}

    # A failing test that belongs to no file also sends each file to run alone.
    run = fn
      "", [_, _ | _] ->
        result.(Map.put(pass, "Elixir.Elsewhere::test t", "failed"))

      _, files ->
        result.(
          Map.take(
            pass,
            Enum.map(files, &"Elixir.#{Macro.camelize(Path.basename(&1, ".exs"))}::test t")
          )
        )
    end

    assert {:ok, ^files, []} = BundleProbe.settle(files, "REF", modules, run)

    # A skipped test fails the grader's existing-tests step, so its file is left out (radiator, 2026-11-12).
    skip = fn _, _ -> result.(Map.put(pass, "Elixir.CTest::test t", "skipped")) end

    assert BundleProbe.settle(files, "REF", modules, skip) ==
             {:ok, ~w(test/a_test.exs test/b_test.exs test/d_test.exs),
              [%{"file" => "test/c_test.exs", "reason" => "skipped_on_unchanged"}]}

    assert {:error, "no_existing_tests", "test/a_test.exs: fails_on_unchanged"} =
             BundleProbe.settle(["test/a_test.exs"], "REF", modules, fn _, _ ->
               result.(%{"Elixir.ATest::test t" => "failed"})
             end)
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
