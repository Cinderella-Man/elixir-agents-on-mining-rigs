defmodule Eab.ServiceImages do
  @moduledoc "Pinned database engines with all persistent state outside Docker volumes."
  alias Eab.{BuildCache, Cache, Command, Store}

  def resolve(services, opts \\ []) do
    inputs = %{"services" => services}

    {artifact, _} =
      Cache.fetch(
        "engines",
        inputs,
        fn _ ->
          previous = Enum.find(Cache.records("engines"), &(&1["id"] == Cache.key(inputs)))
          saved = if previous, do: previous["artifact"]["services"], else: %{}

          pinned =
            Map.new(services, fn {name, config} ->
              unless name in ["postgres", "clickhouse"], do: raise("Unsupported service #{name}")
              reference = saved[name] || config["image"]
              Command.run!("docker", ["pull", "--quiet", reference], timeout: 1200)
              [info] = Command.run!("docker", ["image", "inspect", reference]) |> Jason.decode!()
              digest = List.first(info["RepoDigests"] || []) || raise "Unpinned service image"
              {name, digest}
            end)

          %{"services" => pinned, "images" => Map.values(pinned)}
        end,
        opts
      )

    artifact["services"]
  end

  def layout_identity do
    Cache.key(Map.new(["postgres", "clickhouse"], &{&1, recipe(&1, "ENGINE")}))
  end

  def ensure(name, engine, opts \\ []) do
    recipe = recipe(name, engine)

    {artifact, _} =
      Cache.fetch(
        "service-layouts",
        %{"recipe" => recipe},
        fn _ ->
          image = build(recipe, "layout-" <> Cache.key(recipe))
          %{"image" => image, "images" => [image]}
        end,
        opts
      )

    artifact["image"]
  end

  def recipe("postgres", engine) do
    """
    FROM #{engine}
    ENV PGDATA=/opt/eab-state/postgres
    RUN mkdir -p /opt/eab-state/postgres && chown postgres:postgres /opt/eab-state/postgres && chmod 700 /opt/eab-state/postgres
    """
  end

  def recipe("clickhouse", engine) do
    config = """
    <clickhouse>
      <path replace="replace">/opt/eab-state/clickhouse/</path>
      <tmp_path replace="replace">/opt/eab-state/clickhouse/tmp/</tmp_path>
      <user_files_path replace="replace">/opt/eab-state/clickhouse/user_files/</user_files_path>
      <format_schema_path replace="replace">/opt/eab-state/clickhouse/format_schemas/</format_schema_path>
      <user_defined_path replace="replace">/opt/eab-state/clickhouse/user_defined/</user_defined_path>
      <custom_cached_disks_base_directory replace="replace">/opt/eab-state/clickhouse/caches/</custom_cached_disks_base_directory>
      <user_directories><local_directory><path replace="replace">/opt/eab-state/clickhouse/access/</path></local_directory></user_directories>
      <logger><log remove="remove"/><errorlog remove="remove"/><console>1</console></logger>
    </clickhouse>
    """

    """
    FROM #{engine}
    RUN mkdir -p /opt/eab-state/clickhouse && chown clickhouse:clickhouse /opt/eab-state/clickhouse
    RUN printf '%s' '#{Base.encode64(config)}' | base64 -d > /etc/clickhouse-server/config.d/eab-state.xml
    """
  end

  def rebase(name, seed, engine) do
    base = ensure(name, engine)
    seed_tag = BuildCache.tag(seed, "database-parent")
    base_tag = BuildCache.tag(base, "database-layout")

    build(
      """
      FROM #{seed_tag} AS seed
      FROM #{base_tag}
      COPY --from=seed /opt/eab-state/ /opt/eab-state/
      """,
      "checkpoint-" <> Cache.key([name, seed, base])
    )
  end

  def capture(name, container, identity) do
    assert_unmounted!(container, "/opt/eab-state")
    Command.run!("docker", ["stop", "--time", "90", container], timeout: 105)
    [info] = Command.run!("docker", ["inspect", container]) |> Jason.decode!()
    state = info["State"]

    unless state["Running"] == false and state["ExitCode"] == 0 and state["OOMKilled"] == false,
      do: raise("Refusing to capture #{name} after an unclean shutdown")

    tag = "elixir-agent-benchmark:snapshot-#{identity}-#{name}"
    image = Command.run!("docker", ["commit", container, tag], timeout: 300) |> String.trim()

    if name == "clickhouse" do
      # Preserve database/table UUIDs, but let each clone generate its server UUID.
      build(
        "FROM #{tag}\nRUN rm -f /opt/eab-state/clickhouse/uuid\n",
        "sealed-#{identity}-#{name}"
      )
    else
      image
    end
  end

  def validate!(box) do
    if box.runtime["services"]["postgres"] do
      path = postgres(box.name <> "-db", "SHOW data_directory")
      unless path == "/opt/eab-state/postgres", do: raise("PostgreSQL state is outside capture")

      unless postgres(
               box.name <> "-db",
               "SELECT count(*) FROM pg_tablespace WHERE pg_tablespace_location(oid) <> ''"
             ) == "0",
             do: raise("External PostgreSQL tablespaces cannot be captured")

      Command.run!("docker", [
        "exec",
        box.name <> "-db",
        "sh",
        "-c",
        "test \"$(readlink -f /opt/eab-state/postgres/pg_wal)\" = /opt/eab-state/postgres/pg_wal"
      ])
    end

    if box.runtime["services"]["clickhouse"] do
      name = box.name <> "-ch"

      for query <- [
            "SELECT count(*) FROM system.disks WHERE path != '' AND NOT startsWith(path, '/opt/eab-state/clickhouse/')",
            "SELECT count(*) FROM system.tables WHERE startsWith(engine, 'Replicated') OR engine IN ('Distributed', 'Kafka', 'S3', 'HDFS', 'MySQL', 'PostgreSQL')"
          ] do
        unless clickhouse(name, query) == "0",
          do: raise("ClickHouse has state outside its local snapshot")
      end

      dictionaries =
        clickhouse(
          name,
          "SELECT database, name, create_table_query FROM system.tables WHERE engine = 'Dictionary' FORMAT JSONEachRow"
        )

      for line <- String.split(dictionaries, "\n", trim: true) do
        dictionary = Jason.decode!(line)
        ddl = dictionary["create_table_query"]

        unless Regex.match?(~r/SOURCE\s*\(CLICKHOUSE\s*\(/i, ddl) and
                 not Regex.match?(~r/\b(HOST|PORT|REPLICA|CLUSTER)\b/i, ddl),
               do: raise("Dictionary #{dictionary["name"]} is not a local ClickHouse source")
      end

      script = """
      for i in $(seq 1 120); do
        failed=$(clickhouse-client --query "SELECT count(*) FROM system.mutations WHERE NOT is_done AND latest_fail_reason != ''") || exit 1
        test "$failed" = 0 || exit 1
        pending=$(clickhouse-client --query "SELECT count(*) FROM system.mutations WHERE NOT is_done") || exit 1
        test "$pending" = 0 && exit 0
        sleep 1
      done
      exit 1
      """

      Command.run!("docker", ["exec", name, "sh", "-c", script], timeout: 150)
    end
  end

  defp assert_unmounted!(container, root) do
    [info] = Command.run!("docker", ["inspect", container]) |> Jason.decode!()

    if Enum.any?(info["Mounts"], fn mount ->
         path = String.trim_trailing(mount["Destination"], "/")

         path == "" or path == root or String.starts_with?(path, root <> "/") or
           String.starts_with?(root, path <> "/")
       end),
       do: raise("Database state overlaps an excluded Docker mount")
  end

  defp postgres(container, query) do
    Command.run!("docker", [
      "exec",
      container,
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-Atc",
      query
    ])
    |> String.trim()
  end

  defp clickhouse(container, query) do
    Command.run!("docker", ["exec", container, "clickhouse-client", "--query", query],
      limit: 1_000_000
    )
    |> String.trim()
  end

  defp build(recipe, identity) do
    dest = Store.path("build/services/#{identity}")
    File.mkdir_p!(dest)
    File.write!(Path.join(dest, "Dockerfile"), recipe)
    tag = "elixir-agent-benchmark:#{identity}"

    Command.run!(
      "docker",
      ["buildx", "build", "--load", "--provenance=false", "--progress=plain", "-t", tag, dest],
      timeout: 600,
      limit: 1_000_000
    )

    Command.run!("docker", ["image", "inspect", tag, "--format", "{{.Id}}"])
    |> String.trim()
  end
end
