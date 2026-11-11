# Runs inside the fixture's own Elixir/OTP, including the oldest supported release.
defmodule Eab.FixtureSeed do
  @metadata "/opt/eab-seed/inputs.etf"
  @preserved ["deps", "_build", "tracker/node_modules"]

  def sync(source, workspace) do
    for path <- [".git" | @preserved], type(Path.join(source, path)) != nil do
      raise "Source snapshot contains reserved build path #{path}"
    end

    # Mix 1.15 uses second-resolution mtimes before comparing file digests. A
    # same-second, same-size edit must not look older than the cached manifest.
    manifests = Path.wildcard(Path.join(workspace, "_build/**/.mix/*"), match_dot: true)
    latest = Enum.reduce(manifests, 0, &max(File.stat!(&1, time: :posix).mtime, &2))
    now = System.os_time(:millisecond)

    cond do
      latest * 1000 > now + 1000 -> File.rm_rf!(Path.join(workspace, "_build"))
      latest * 1000 >= now - 1000 -> Process.sleep(max(0, (latest + 1) * 1000 - now))
      true -> :ok
    end

    File.rm_rf!(Path.join(workspace, ".git"))
    sync_directory(source, workspace, "")
  end

  defp sync_directory(source, destination, relative) do
    unless type(destination) == :directory, do: File.rm_rf!(destination)
    File.mkdir_p!(destination)
    names = File.ls!(source)

    for name <- File.ls!(destination),
        name not in names,
        Path.join(relative, name) not in @preserved do
      File.rm_rf!(Path.join(destination, name))
    end

    for name <- names do
      from = Path.join(source, name)
      to = Path.join(destination, name)

      case type(from) do
        :directory ->
          sync_directory(from, to, Path.join(relative, name))

        :regular ->
          if type(to) != :regular or File.read!(from) != File.read!(to) do
            File.rm_rf!(to)
            File.cp!(from, to)
            File.touch!(to)
          end

          if File.stat!(to).mode != File.stat!(from).mode,
            do: File.chmod!(to, File.stat!(from).mode)

        :symlink ->
          if type(to) != :symlink or File.read_link!(from) != File.read_link!(to) do
            File.rm_rf!(to)
            File.ln_s!(File.read_link!(from), to)
          end
      end
    end

    if File.stat!(destination).mode != File.stat!(source).mode,
      do: File.chmod!(destination, File.stat!(source).mode)
  end

  defp type(path) do
    case File.lstat(path) do
      {:ok, stat} -> stat.type
      {:error, :enoent} -> nil
      {:error, reason} -> raise File.Error, reason: reason, action: "stat", path: path
    end
  end

  def reconcile(metadata \\ @metadata) do
    Mix.Task.run("loadconfig")
    config = Mix.Project.config()
    deps = Mix.Dep.load_and_cache()

    current = %{
      project:
        config
        |> Keyword.drop([
          :deps,
          :version,
          :description,
          :docs,
          :package,
          :source_url,
          :homepage_url,
          :name,
          :elixir,
          :releases,
          :default_release,
          :escript
        ])
        |> Enum.sort(),
      config: config_files(),
      deps:
        Map.new(deps, fn dep ->
          {dep.app,
           {dep.manager, dep.system_env, Enum.sort(Keyword.drop(dep.opts, [:from, :top_level])),
            Enum.sort(Enum.map(dep.deps, & &1.app))}}
        end)
    }

    previous =
      case File.read(metadata) do
        {:ok, data} -> :erlang.binary_to_term(data)
        {:error, :enoent} -> nil
      end

    cond do
      is_nil(previous) ->
        IO.puts("Build seed: cold preparation")

      previous.project != current.project or previous.config != current.config ->
        IO.puts(
          "Build seed: compilation settings changed; discarding compiled artifacts and dependency worktrees"
        )

        File.rm_rf!(Mix.Project.build_path())
        File.rm_rf!("_build")
        File.rm_rf!(Mix.Project.deps_path())

      true ->
        changed = for {app, identity} <- current.deps, previous.deps[app] != identity, do: app
        removed = Map.keys(previous.deps) -- Map.keys(current.deps)
        invalid = dependents(changed ++ removed, deps)

        for dep <- deps, dep.app in invalid do
          File.rm_rf!(dep.opts[:build])
          # Native dependencies can leave objects in their source directory.
          if dep.scm.fetchable?, do: File.rm_rf!(dep.opts[:dest])
        end

        IO.puts(
          "Build seed: retaining compatible artifacts; invalidated dependencies: #{Enum.join(invalid, ", ")}"
        )
    end

    File.mkdir_p!(Path.dirname(metadata))
    File.write!(metadata, :erlang.term_to_binary(current))
  end

  defp dependents(apps, deps) do
    expanded =
      (apps ++ for(dep <- deps, Enum.any?(dep.deps, &(&1.app in apps)), do: dep.app))
      |> Enum.uniq()

    if length(expanded) == length(apps), do: expanded, else: dependents(expanded, deps)
  end

  defp config_files do
    (Path.wildcard("config/**/*", match_dot: true) ++ Mix.Project.config_files())
    |> Enum.map(&Path.expand/1)
    |> Enum.reject(&(&1 == Path.expand("mix.exs")))
    |> Enum.filter(&File.regular?/1)
    |> Map.new(&{&1, :crypto.hash(:sha256, File.read!(&1))})
  end
end

defmodule Mix.Tasks.Eab.Seed do
  use Mix.Task
  def run(args), do: Eab.FixtureSeed.reconcile(List.first(args) || "/opt/eab-seed/inputs.etf")
end
