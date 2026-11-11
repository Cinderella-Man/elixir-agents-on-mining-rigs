defmodule Eab.DatabaseSeed do
  @moduledoc "Conservative migration/dependency identities for pristine database reuse."
  alias Eab.{Cache, Inventory}

  @repos %{"postgres" => "priv/repo/migrations", "clickhouse" => "priv/ingest_repo/migrations"}

  def describe(source, spec) do
    files = Path.wildcard(Path.join(source, "{lib,extra,src}/**/*.{ex,exs,erl,hrl}"))

    migration_files =
      Map.new(@repos, fn {service, directory} ->
        {service, Path.wildcard(Path.join([source, directory, "*.exs"])) |> Enum.sort()}
      end)

    # Every file is read and parsed once. Opaque dependencies require all app
    # source, so there is no reason to traverse the rest of that graph first.
    analysis =
      Map.new(Enum.uniq(files ++ List.flatten(Map.values(migration_files))), fn file ->
        text = File.read!(file)
        ast = Code.string_to_quoted(text)

        {file,
         %{
           modules: Regex.scan(~r/\bdefmodule\s+([A-Z][A-Za-z0-9_.]*)\b/, text),
           names: aliases(ast),
           opaque: opaque?(text, ast),
           cross_service: String.contains?(text, "IngestRepo"),
           hash: Inventory.hash(text)
         }}
      end)

    modules =
      Enum.reduce(files, %{}, fn file, index ->
        analysis[file].modules
        |> Enum.reduce(index, fn [_, name], acc -> Map.put(acc, name, file) end)
      end)

    aliases =
      analysis
      |> Enum.flat_map(fn {_, info} -> info.names end)
      |> Enum.uniq()
      |> Map.new(fn alias_name ->
        children =
          for {name, path} <- modules,
              name == alias_name or String.ends_with?(name, "." <> alias_name) or
                String.ends_with?(alias_name, "." <> name) or
                String.starts_with?(name, alias_name <> "."),
              into: MapSet.new(),
              do: path

        {alias_name, children}
      end)

    graph =
      Map.new(analysis, fn {file, info} ->
        children = Enum.reduce(info.names, MapSet.new(), &MapSet.union(aliases[&1], &2))
        {file, Map.put(info, :children, children)}
      end)

    shared =
      (["mix.exs", "mix.lock"] |> Enum.map(&Path.join(source, &1))) ++
        Path.wildcard(Path.join(source, "config/**/*")) ++
        Path.wildcard(Path.join(source, "priv/**/*")) ++
        Path.wildcard(Path.join(source, "src/**/*"))

    shared =
      shared
      |> Enum.filter(&File.regular?/1)
      |> Enum.reject(fn file ->
        Enum.any?(Map.values(@repos), &String.starts_with?(file, Path.join(source, &1) <> "/"))
      end)

    migrations =
      Map.new(migration_files, fn {service, migration_files} ->
        entries =
          migration_files
          |> Enum.map(fn file ->
            [_, version] = Regex.run(~r/^(\d+)_/, Path.basename(file))
            dependencies = closure(MapSet.new([file]), graph, MapSet.new(), [file | files])

            %{
              "version" => String.to_integer(version),
              "file" => Path.relative_to(file, source),
              "content" => analysis[file].hash,
              "dependencies" => fingerprint(dependencies -- [file], source, analysis),
              "cross_service" =>
                service == "postgres" and
                  Enum.any?(dependencies, &analysis[&1].cross_service)
            }
          end)
          |> Enum.sort_by(& &1["version"])

        versions = Enum.map(entries, & &1["version"])

        unless length(Enum.uniq(versions)) == length(versions),
          do: raise("Duplicate migration versions")

        {service, entries}
      end)

    %{
      "version" => 1,
      "repository" => spec["repository"]["url"],
      "environment" => spec["runtime"]["environment"] || %{},
      "shared" => fingerprint(shared, source),
      "migrations" => migrations
    }
  end

  def compatible?(seed, target) when is_map(seed) and is_map(target) do
    is_map(seed["migrations"]) and is_map(target["migrations"]) and
      Map.drop(seed, ["migrations"]) == Map.drop(target, ["migrations"]) and
      Enum.all?(@repos, fn {service, _} ->
        before = get_in(seed, ["migrations", service]) || []
        after_ = get_in(target, ["migrations", service]) || []
        prefix? = Enum.take(after_, length(before)) == before
        suffix = Enum.drop(after_, length(before))
        prefix? and not Enum.any?(suffix, & &1["cross_service"])
      end)
  end

  def compatible?(_, _), do: false

  def migration_count(description) do
    description["migrations"] |> Map.values() |> Enum.map(&length/1) |> Enum.sum()
  end

  defp fingerprint(files, root, analysis \\ %{}) do
    files
    |> Enum.uniq()
    |> Enum.sort()
    |> Map.new(fn file ->
      hash = if info = analysis[file], do: info.hash, else: Inventory.hash_file(file)
      {Path.relative_to(file, root), hash}
    end)
    |> Cache.key()
  end

  defp closure(pending, graph, visited, all_source) do
    case Enum.take(pending, 1) do
      [] ->
        MapSet.to_list(visited)

      [file] ->
        info = graph[file]

        if info.opaque do
          Enum.uniq(all_source)
        else
          visited = MapSet.put(visited, file)

          pending =
            pending
            |> MapSet.delete(file)
            |> MapSet.union(info.children)
            |> MapSet.difference(visited)

          closure(pending, graph, visited, all_source)
        end
    end
  end

  defp aliases(quoted) do
    case quoted do
      {:ok, ast} ->
        {_, names} =
          Macro.prewalk(ast, [], fn
            {{:., _, [{:__aliases__, _, prefix}, :{}]}, _, children} = node, names ->
              joined =
                for {:__aliases__, _, suffix} <- children, do: Enum.join(prefix ++ suffix, ".")

              {node, joined ++ names}

            {:__aliases__, _, parts} = node, names ->
              if Enum.all?(parts, &is_atom/1),
                do: {node, [Enum.join(parts, ".") | names]},
                else: {node, names}

            node, names ->
              {node, names}
          end)

        Enum.uniq(names)

      _ ->
        []
    end
  end

  defp opaque?(text, quoted) do
    match?({:error, _}, quoted) or
      Regex.match?(
        ~r/\b(apply\s*\(|Module\.concat|Code\.(eval|require|compile)|File\.|System\.|__MODULE__|unquote|quote\b)/,
        text
      ) or dynamic_call?(quoted)
  end

  defp dynamic_call?(quoted) do
    case quoted do
      {:ok, ast} ->
        {_, dynamic?} =
          Macro.prewalk(ast, false, fn
            {:use, _, [{:__aliases__, _, [:Ecto, :Migration]}]} = node, found -> {node, found}
            {:use, _, _} = node, _ -> {node, true}
            {{:., _, [{:__aliases__, _, _}, _]}, _, _} = node, found -> {node, found}
            {{:., _, _}, _, _} = node, _ -> {node, true}
            node, found -> {node, found}
          end)

        dynamic?

      _ ->
        true
    end
  end
end
