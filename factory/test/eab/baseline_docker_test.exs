defmodule Eab.BaselineDockerTest do
  use ExUnit.Case, async: false
  @moduletag :docker
  alias Eab.{Cache, Command, Sandbox, ServiceImages, Store}

  # Tiny synthetic databases only. These are isolation/durability checks, not
  # benchmark cases or measurements of preparation/startup performance.
  @tag timeout: 600_000
  test "clean snapshots preserve both database families and independent writable clones" do
    previous = Store.root()
    id = "eab-snapshot-check-#{System.unique_integer([:positive])}"
    root = Path.join(System.tmp_dir!(), id)
    Application.put_env(:eab, :data_dir, root)
    project = "#{id}:project"
    File.mkdir_p!(root)
    before = docker(["image", "ls", "--format", "{{.Repository}}:{{.Tag}}"]) |> String.split()

    on_exit(fn ->
      # Remove only tags this check created, never previously existing ones.
      after_ = docker(["image", "ls", "--format", "{{.Repository}}:{{.Tag}}"]) |> String.split()

      declared =
        case File.read(Path.join(root, "cleanup-tags")) do
          {:ok, body} -> String.split(body)
          _ -> []
        end

      tags =
        Enum.filter(after_ -- before, fn tag ->
          String.starts_with?(tag, id <> ":") or String.contains?(tag, id) or tag in declared
        end)

      # A child may initially keep its parent alive. Both passes are restricted
      # to these test-owned tags; pre-existing images are never removed.
      for _ <- 1..2, tag <- tags do
        Command.run("docker", ["image", "rm", tag])
      end

      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
    end)

    build(
      root,
      project,
      "FROM eab-tooling:dev\nWORKDIR /workspace\nCMD [\"sleep\", \"infinity\"]\n"
    )

    for {pg, ch, family} <- [
          {"postgres:16-alpine", "clickhouse/clickhouse-server:24.12.2.29-alpine", "older"},
          {"postgres:18-alpine", "clickhouse/clickhouse-server:25.11.5.8-alpine", "newer"}
        ] do
      services =
        Map.new([{"postgres", pg}, {"clickhouse", ch}], fn {name, engine} ->
          tag = "#{id}:#{family}-#{name}"
          build(root, tag, ServiceImages.recipe(name, engine))
          {name, tag}
        end)

      runtime = %{"image" => project, "services" => services}
      spec = %{"runtime" => %{"before_test_commands" => ["false"]}}

      saved =
        Sandbox.with_runtime(
          id,
          spec,
          runtime,
          id,
          fn box ->
            pg(
              box,
              "CREATE TABLE baseline (id integer PRIMARY KEY, value text); INSERT INTO baseline VALUES (1, 'pristine')"
            )

            ch(box, "CREATE DATABASE baseline")

            ch(
              box,
              "CREATE TABLE baseline.values (id UInt64, value String) ENGINE=MergeTree ORDER BY id"
            )

            ch(box, "INSERT INTO baseline.values VALUES (1, 'pristine')")

            ch(
              box,
              "CREATE DICTIONARY baseline.lookup (id UInt64, value String) PRIMARY KEY id SOURCE(CLICKHOUSE(DB 'baseline' TABLE 'values')) LAYOUT(HASHED()) LIFETIME(0)"
            )

            ch(box, "CREATE FUNCTION eab_identity AS (x) -> x")
            ServiceImages.validate!(box)

            Map.new(services, fn {name, _} ->
              suffix = if name == "postgres", do: "-db", else: "-ch"
              {name, ServiceImages.capture(name, box.name <> suffix, "#{id}-#{family}")}
            end)
          end,
          before_test: false
        )

      runtime = Map.put(runtime, "services", saved)

      uuid =
        Sandbox.with_runtime(
          id,
          spec,
          runtime,
          id,
          fn box ->
            assert pg(box, "SELECT value FROM baseline WHERE id=1") == "pristine"

            assert ch(box, "SELECT dictGet('baseline.lookup', 'value', toUInt64(1))") ==
                     "pristine"

            assert ch(box, "SELECT eab_identity(9)") == "9"
            uuid = ch(box, "SELECT serverUUID()")
            pg(box, "UPDATE baseline SET value='attempt'")
            ch(box, "INSERT INTO baseline.values VALUES (2, 'attempt')")
            assert pg(box, "SELECT value FROM baseline WHERE id=1") == "attempt"
            uuid
          end,
          before_test: false
        )

      rebased =
        Map.new([{"postgres", pg}, {"clickhouse", ch}], fn {name, engine} ->
          {name, rebase(root, name, saved[name], engine)}
        end)

      Sandbox.with_runtime(
        id,
        spec,
        Map.put(runtime, "services", rebased),
        id,
        fn box ->
          assert pg(box, "SELECT value FROM baseline WHERE id=1") == "pristine"
          assert ch(box, "SELECT count(*) FROM baseline.values") == "1"
          assert ch(box, "SELECT dictGet('baseline.lookup', 'value', toUInt64(1))") == "pristine"
          assert ch(box, "SELECT eab_identity(9)") == "9"
          refute ch(box, "SELECT serverUUID()") == uuid
          ServiceImages.validate!(box)
        end,
        before_test: false
      )
    end
  end

  defp rebase(root, name, seed, engine) do
    cleanup = Path.join(root, "cleanup-tags")
    layout = "elixir-agent-benchmark:layout-" <> Cache.key(ServiceImages.recipe(name, engine))
    File.write!(cleanup, layout <> "\n", [:append])
    base = ServiceImages.ensure(name, engine)

    tags = [
      "elixir-agent-benchmark:checkpoint-" <> Cache.key([name, seed, base]),
      "elixir-agent-benchmark:database-parent-" <> String.replace_prefix(seed, "sha256:", ""),
      "elixir-agent-benchmark:database-layout-" <> String.replace_prefix(base, "sha256:", "")
    ]

    File.write!(cleanup, Enum.join(tags, "\n") <> "\n", [:append])
    ServiceImages.rebase(name, seed, engine)
  end

  defp build(root, tag, recipe) do
    File.write!(Path.join(root, "Dockerfile"), recipe)

    docker(["buildx", "build", "--load", "--provenance=false", "--network=none", "-t", tag, root],
      timeout: 120
    )
  end

  defp pg(box, query),
    do:
      docker(["exec", box.name <> "-db", "psql", "-U", "postgres", "-Atc", query])
      |> String.trim()

  defp ch(box, query),
    do:
      docker(["exec", box.name <> "-ch", "clickhouse-client", "--query", query]) |> String.trim()

  defp docker(args, opts \\ []),
    do: Command.run!("docker", args, Keyword.put_new(opts, :limit, 200_000))
end
