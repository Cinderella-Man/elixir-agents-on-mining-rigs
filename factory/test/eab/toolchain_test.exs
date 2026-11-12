defmodule Eab.ToolchainTest do
  use ExUnit.Case, async: true
  alias Eab.Toolchain

  @table %{
    "elixir" => [
      %{
        "elixir" => "1.16.1",
        "otp" => "26.2.1",
        "image" =>
          "hexpm/elixir:1.16.1-erlang-26.2.1-ubuntu-noble-20260101@sha256:#{String.duplicate("a", 64)}"
      },
      %{
        "elixir" => "1.17.2",
        "otp" => "27.0.1",
        "image" =>
          "hexpm/elixir:1.17.2-erlang-27.0.1-ubuntu-noble-20260101@sha256:#{String.duplicate("a", 64)}"
      },
      %{
        "elixir" => "1.18.3",
        "otp" => "27.3",
        "image" =>
          "hexpm/elixir:1.18.3-erlang-27.3-ubuntu-noble-20260101@sha256:#{String.duplicate("a", 64)}"
      },
      %{
        "elixir" => "1.18.4",
        "otp" => "28.0",
        "image" =>
          "hexpm/elixir:1.18.4-erlang-28.0-ubuntu-noble-20260101@sha256:#{String.duplicate("a", 64)}"
      }
    ],
    "postgres" => [
      %{
        "version" => "14",
        "image" => "postgres:14.24-alpine@sha256:#{String.duplicate("b", 64)}"
      },
      %{"version" => "16", "image" => "postgres:16.10-alpine@sha256:#{String.duplicate("c", 64)}"}
    ],
    "clickhouse" => [
      %{
        "version" => "25.4.2.31",
        "image" => "clickhouse/clickhouse-server:25.4.2.31@sha256:#{String.duplicate("d", 64)}"
      }
    ],
    "service_clients" => %{"redis" => ["redix", "exredis"]}
  }

  @template %{
    "runtime" => %{
      "profile" => "mix",
      "image" =>
        "hexpm/elixir:9.9.9-erlang-99-ubuntu-noble-20260101@sha256:#{String.duplicate("e", 64)}",
      "environment" => %{"MIX_ENV" => "test"},
      "setup_commands" => ["mix compile"],
      "before_test_commands" => []
    },
    "services" => %{
      "postgres" => %{"image" => "postgres:18.6-alpine@sha256:#{String.duplicate("f", 64)}"}
    },
    "baseline" => %{
      "mode" => "prepared",
      "commands" => ["mix ecto.create --quiet", "mix ecto.migrate --quiet"]
    },
    "grading" => %{"protected_paths" => ["test/"], "preservation" => "mix test"},
    "toolchain" => %{
      "baseline" => [
        %{"when" => %{"mix_alias_uses" => "ash.setup"}, "commands" => ["mix ash.setup --quiet"]},
        %{"commands" => ["mix ecto.create --quiet", "mix ecto.migrate --quiet"]}
      ],
      "ci_services_not_needed" => %{"redis" => "the application does not connect to it in tests"}
    }
  }

  @mix ~s|defmodule Shop.MixProject do\n  use Mix.Project\n  def project, do: [app: :shop, elixir: "~> 1.16", deps: deps()]\n  defp deps, do: [{:ecto_sql, "~> 3.10"}]\nend\n|

  defp ok!(files, template \\ @template) do
    assert {:ok, resolved} = Toolchain.resolve(files, template, @table)
    resolved
  end

  defp value(resolved, key), do: get_in(resolved["record"], [key, "value"])
  defp source(resolved, key), do: get_in(resolved["record"], [key, "source"])

  test "wanted names the root files, the CI files and the GitHub workflows" do
    assert Toolchain.wanted(
             ~w(lib/a.ex mix.exs .tool-versions .github/workflows/ci.yml .github/workflows/x/y.yml
             .travis.yml Dockerfile README.md mise.toml)
           ) ==
             ~w(.github/workflows/ci.yml .tool-versions .travis.yml Dockerfile mise.toml mix.exs)
  end

  test ".tool-versions comes first, and its elixir line's -otp suffix is not the OTP version" do
    resolved =
      ok!(%{
        ".tool-versions" => "elixir 1.17.2-otp-27\nerlang 27.0.1\nnodejs 22.0.0\n",
        "mise.toml" => "[tools]\nelixir = \"1.18.3-otp-27\"\nerlang = \"27.3\"\n",
        "mix.exs" => @mix
      })

    assert value(resolved, "elixir") == "1.17.2"
    assert value(resolved, "otp") == "27.0.1"
    assert source(resolved, "elixir") == ".tool-versions"
    assert resolved["runtime"]["image"] =~ "hexpm/elixir:1.17.2-erlang-27.0.1-"
    assert source(resolved, "image") == "config/toolchain_images.json: 1.17.2/27.0.1"
    assert resolved["runtime"]["environment"] == %{"MIX_ENV" => "test"}
  end

  test "mise.toml and .mise.toml are read when there is no .tool-versions" do
    for name <- ["mise.toml", ".mise.toml"] do
      resolved =
        ok!(%{
          name => "[tools]\nelixir = \"1.18.3-otp-27\"\n\"erlang\" = { version = \"27.3\" }\n",
          "mix.exs" => @mix
        })

      assert {value(resolved, "elixir"), value(resolved, "otp")} == {"1.18.3", "27.3"}
      assert source(resolved, "otp") == name
    end
  end

  test "a GitHub workflow gives the versions of setup-beam, and a matrix's first item" do
    workflow = """
    jobs:
      test:
        steps:
          - uses: erlef/setup-beam@v1
            with:
              otp-version: "26.2.1"
              elixir-version: '1.16.1'
    """

    resolved = ok!(%{".github/workflows/ci.yml" => workflow, "mix.exs" => @mix})
    assert {value(resolved, "elixir"), value(resolved, "otp")} == {"1.16.1", "26.2.1"}
    assert source(resolved, "elixir") == ".github/workflows/ci.yml"

    matrix = """
    jobs:
      test:
        strategy:
          matrix:
            elixir: ['1.18.3']
            otp: ['27.3']
        steps:
          - uses: erlef/setup-beam@v1
            with:
              otp-version: ${{ matrix.otp }}
              elixir-version: ${{ matrix.elixir }}
    """

    resolved = ok!(%{".github/workflows/ci.yml" => matrix, "mix.exs" => @mix})
    assert {value(resolved, "elixir"), value(resolved, "otp")} == {"1.18.3", "27.3"}
  end

  test "a Travis file gives the first item of its lists, and its Postgres under addons" do
    travis = """
    language: elixir
    elixir:
      - 1.16.1
    otp_release:
      - 26.2.1
    addons:
      postgresql: "14"
    services:
      - postgresql
    """

    resolved = ok!(%{".travis.yml" => travis, "mix.exs" => @mix})
    assert {value(resolved, "elixir"), value(resolved, "otp")} == {"1.16.1", "26.2.1"}
    assert resolved["services"]["postgres"]["image"] =~ "postgres:14.24-alpine@"
    assert source(resolved, "postgres") =~ ".travis.yml: postgresql 14"
  end

  test "a Dockerfile's ARG lines, or its hexpm/elixir base, give the versions" do
    args =
      "ARG ELIXIR_VERSION=1.18.3\nARG OTP_VERSION=27.3\nFROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}\n"

    resolved = ok!(%{"Dockerfile" => args, "mix.exs" => @mix})
    assert {value(resolved, "elixir"), value(resolved, "otp")} == {"1.18.3", "27.3"}
    assert source(resolved, "elixir") == "Dockerfile"

    from = "FROM hexpm/elixir:1.17.2-erlang-27.0.1-debian-bookworm-20240722-slim AS build\n"
    resolved = ok!(%{"Dockerfile" => from, "mix.exs" => @mix})
    assert {value(resolved, "elixir"), value(resolved, "otp")} == {"1.17.2", "27.0.1"}
  end

  test "mix.exs's requirement is the last source; the table's newest pair of that minor version is taken" do
    resolved =
      ok!(%{"mix.exs" => String.replace(@mix, "~> 1.16", "~> 1.18")})

    assert value(resolved, "elixir") == "1.18"
    assert value(resolved, "otp") == nil
    assert source(resolved, "elixir") =~ "mix.exs (the lower bound"
    assert resolved["runtime"]["image"] =~ "1.18.4-erlang-28.0"
    assert source(resolved, "image") =~ "1.18.4/28.0 (the newest pair that matches by prefix)"
  end

  test "with no version anywhere, the template's image is the default" do
    resolved = ok!(%{"mix.exs" => "defmodule X.MixProject do\nend\n"})
    assert resolved["runtime"]["image"] == @template["runtime"]["image"]
    assert source(resolved, "image") =~ "the template's default"
  end

  test "the database: the CI file's version pinned by the table, or the template's default" do
    workflow = """
    jobs:
      test:
        services:
          db:
            image: postgres:16
            env:
              POSTGRES_PASSWORD: postgres
            ports:
              - 5432:5432
        steps:
          - run: mix test
    """

    files = %{".tool-versions" => "elixir 1.18.3\nerlang 27.3\n", "mix.exs" => @mix}
    resolved = ok!(Map.put(files, ".github/workflows/ci.yml", workflow))

    assert resolved["services"] == %{
             "postgres" => %{
               "image" => "postgres:16.10-alpine@sha256:" <> String.duplicate("c", 64)
             }
           }

    assert source(resolved, "postgres") =~
             ".github/workflows/ci.yml: postgres:16; config/toolchain_images.json: postgres 16"

    untagged = String.replace(workflow, "postgres:16", "postgres")
    resolved = ok!(Map.put(files, ".github/workflows/ci.yml", untagged))
    assert resolved["services"] == @template["services"]

    assert source(resolved, "postgres") =~
             "the template's default: .github/workflows/ci.yml: postgres names no version"

    resolved = ok!(files)
    assert resolved["services"] == @template["services"]
    assert source(resolved, "postgres") == "the template's default: no CI file starts postgres"

    clickhouse =
      String.replace(
        workflow,
        "db:\n        image: postgres:16",
        "ch:\n        image: clickhouse/clickhouse-server:25.4"
      )

    resolved = ok!(Map.put(files, ".github/workflows/ci.yml", clickhouse))
    assert resolved["services"]["clickhouse"]["image"] =~ "clickhouse-server:25.4.2.31@"
  end

  test "the baseline is the template's first candidate whose condition holds" do
    files = %{".tool-versions" => "elixir 1.18.3\nerlang 27.3\n"}

    ash =
      String.replace(
        @mix,
        "defp deps",
        ~s|defp aliases, do: [test: ["ash.setup --quiet", "test"]]\n  defp deps|
      )

    assert ok!(Map.put(files, "mix.exs", ash))["baseline"]["commands"] == [
             "mix ash.setup --quiet"
           ]

    resolved = ok!(Map.put(files, "mix.exs", @mix))

    assert resolved["baseline"]["commands"] == [
             "mix ecto.create --quiet",
             "mix ecto.migrate --quiet"
           ]

    assert source(resolved, "baseline") == "the template's candidate 2 of 2 (no condition)"

    dep_only =
      put_in(@template, ["toolchain", "baseline"], [
        %{"when" => %{"mix_dep" => "ash"}, "commands" => ["mix ash.setup"]}
      ])

    resolved = ok!(Map.put(files, "mix.exs", @mix), dep_only)
    assert resolved["baseline"] == @template["baseline"]
    assert source(resolved, "baseline") == "the template's default baseline"
  end

  test "refused: no_image when the table has no pair for the commit's versions" do
    assert {:refused, "no_image:1.10.3/22.3.4.1", detail, record} =
             Toolchain.resolve(
               %{
                 ".tool-versions" => "elixir 1.10.3-otp-22\nerlang 22.3.4.1\n",
                 "mix.exs" => @mix
               },
               @template,
               @table
             )

    assert detail == "no_image:1.10.3/22.3.4.1"
    assert get_in(record, ["elixir", "source"]) == ".tool-versions"
  end

  test "refused: no_service_image when the table lacks the CI file's database version" do
    workflow = "jobs:\n  t:\n    services:\n      postgres:\n        image: postgres:9.6\n"

    assert {:refused, "no_service_image:postgres/9.6", _, _} =
             Toolchain.resolve(
               %{
                 ".tool-versions" => "elixir 1.18.3\nerlang 27.3\n",
                 ".github/workflows/t.yml" => workflow
               },
               @template,
               @table
             )
  end

  test "refused: needs_service for a Redis client in mix.exs, even when the template marks the CI's Redis not needed" do
    redix = String.replace(@mix, ~s|[{:ecto_sql|, ~s|[{:redix, "~> 1.3"}, {:ecto_sql|)
    workflow = "jobs:\n  t:\n    services:\n      redis:\n        image: redis\n"

    files = %{
      ".tool-versions" => "elixir 1.18.3\nerlang 27.3\n",
      ".github/workflows/t.yml" => workflow
    }

    resolved = ok!(Map.put(files, "mix.exs", @mix))
    assert get_in(resolved["record"], ["services_checked", "not_needed_by_template"]) == ["redis"]

    assert {:refused, "needs_service:redis", _, record} =
             Toolchain.resolve(Map.put(files, "mix.exs", redix), @template, @table)

    assert get_in(record, ["services_checked", "mix_clients"]) == ["redix (redis)"]
  end

  test "refused: needs_service for a CI service the engine lacks and the template does not mark" do
    drone =
      "kind: pipeline\nservices:\n- name: minio\n  image: minio/minio:latest\n- name: database\n  image: postgres:14\n"

    assert {:refused, "needs_service:minio", _, record} =
             Toolchain.resolve(
               %{
                 ".tool-versions" => "elixir 1.18.3\nerlang 27.3\n",
                 ".drone.yml" => drone,
                 "mix.exs" => @mix
               },
               @template,
               @table
             )

    assert get_in(record, ["services_checked", "ci_starts"]) == ["minio", "postgres"]
    assert get_in(record, ["postgres", "value"]) =~ "postgres:14.24-alpine@"
  end

  test "several refusals: the first in the resolver's order is the reason, the detail lists all" do
    redix = String.replace(@mix, ~s|[{:ecto_sql|, ~s|[{:redix, "~> 1.3"}, {:ecto_sql|)

    assert {:refused, "no_image:1.10.3/22.3", "no_image:1.10.3/22.3; needs_service:redis", _} =
             Toolchain.resolve(
               %{".tool-versions" => "elixir 1.10.3\nerlang 22.3\n", "mix.exs" => redix},
               @template,
               @table
             )
  end

  test "prefix matching and the template check" do
    assert Toolchain.prefix?("1.17", "1.17.2")
    assert Toolchain.prefix?("1.17.2", "1.17.2")
    refute Toolchain.prefix?("1.17.2", "1.17.20")
    refute Toolchain.prefix?("1.1", "1.17.2")
    refute Toolchain.prefix?("main", "1.17.2")

    assert Toolchain.valid_template?(@template["toolchain"])
    refute Toolchain.valid_template?(%{"baseline" => [%{"commands" => []}]})

    refute Toolchain.valid_template?(%{
             "baseline" => [%{"commands" => ["x"], "when" => %{"elixir" => "1"}}]
           })

    refute Toolchain.valid_template?(%{"images" => []})
  end

  test "the factory's image table and the two templates load" do
    table = Toolchain.read_table!(Eab.Inventory.path("config/toolchain_images.json"))
    pairs = Enum.map(table["elixir"], &"#{&1["elixir"]}/#{&1["otp"]}")
    assert "1.18.3/27.3" in pairs and "1.20.3/29.0.5" in pairs
    assert Enum.all?(table["elixir"], &(Version.compare(&1["elixir"], "1.12.0") != :lt))

    # OTP 27.2's ssl rejects the certificate of builds.hex.pm, so such an image cannot install Hex; 27.2.1's does
    # too (radiator #607, 2026-11-12), so no pair of OTP 27.2 or its patch releases is in the table
    refute Enum.any?(table["elixir"], &Toolchain.prefix?("27.2", &1["otp"]))

    for name <- ["axelclark__ex338", "podlove__radiator"] do
      recipe = Eab.BundleMaker.read_recipe!(Eab.Inventory.path("recipes/#{name}.json"))
      assert Toolchain.valid_template?(recipe["toolchain"])
      assert Enum.any?(table["elixir"], &(&1["image"] == recipe["runtime"]["image"]))
    end
  end
end
