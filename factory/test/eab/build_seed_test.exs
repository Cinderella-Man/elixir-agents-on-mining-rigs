Code.require_file("priv/fixtures/build_seed.exs")

defmodule Eab.BuildSeedTest do
  use ExUnit.Case, async: false
  alias Eab.{Command, FixtureSeed, Inventory}

  setup do
    root = Path.join(System.tmp_dir!(), "eab-seed-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root}
  end

  test "source replacement preserves only build directories and removes obsolete source", %{
    root: root
  } do
    source = Path.join(root, "source")
    workspace = Path.join(root, "workspace")
    put(source, "lib/keep.ex", "same")
    put(source, ".gitignore", "deps\n_build\n")
    put(source, "lib/change.ex", "new!")
    put(workspace, "lib/keep.ex", "same")
    File.touch!(Path.join(workspace, "lib/keep.ex"), 1_000_000)
    put(workspace, "lib/change.ex", "old!")
    put(workspace, "lib/removed.ex", "gone")
    put(workspace, "priv/generated.js", "old generated output")
    put(workspace, "deps/cached/keep", "dependency")
    put(workspace, "_build/test/keep", "compiled")
    put(workspace, ".git/secret-history", "old commit")
    File.ln_s!(Path.join(root, "outside"), Path.join(workspace, "link"))
    put(source, "link", "regular now")

    FixtureSeed.sync(source, workspace)
    assert File.read!(Path.join(workspace, "lib/change.ex")) == "new!"
    assert File.stat!(Path.join(workspace, "lib/keep.ex"), time: :posix).mtime == 1_000_000
    assert File.read!(Path.join(workspace, "deps/cached/keep")) == "dependency"
    assert File.read!(Path.join(workspace, "_build/test/keep")) == "compiled"
    assert File.read!(Path.join(workspace, "link")) == "regular now"
    refute File.exists?(Path.join(workspace, "lib/removed.ex"))
    refute File.exists?(Path.join(workspace, "priv/generated.js"))
    refute File.exists?(Path.join(workspace, ".git"))
    refute File.exists?(Path.join(root, "outside"))

    put(source, "deps/tracked", "cannot silently ignore pinned source")

    assert_raise RuntimeError, ~r/reserved build path deps/, fn ->
      FixtureSeed.sync(source, workspace)
    end
  end

  @tag timeout: 180_000
  test "real Mix reuses unchanged artifacts and invalidates edits, dependencies, configuration and removals",
       %{root: root} do
    leaf = Path.join(root, "leaf-repository")
    stable = Path.join(root, "stable-repository")
    middle = Path.join(root, "middle-repository")
    project = Path.join(root, "workspace")
    source = Path.join(root, "incoming")
    metadata = Path.join(root, "inputs.etf")

    package(leaf, :seed_leaf, [], "defmodule SeedLeaf do\n def value, do: :old\nend\n")
    old_leaf = commit(leaf)
    package(stable, :seed_stable, [], "defmodule SeedStable do\n def value, do: :stable\nend\n")
    stable_ref = commit(stable)
    middle_deps = [{:seed_leaf, [git: leaf, ref: old_leaf]}]

    package(
      middle,
      :seed_middle,
      middle_deps,
      "defmodule SeedMiddle do\n @value SeedLeaf.value()\n def value, do: @value\nend\n"
    )

    middle_ref = commit(middle)

    deps = [
      {:seed_leaf, [git: leaf, ref: old_leaf, override: true]},
      {:seed_middle, [git: middle, ref: middle_ref]},
      {:seed_stable, [git: stable, ref: stable_ref]}
    ]

    package(source, :seed_app, deps, app_source("old"))
    put(source, "lib/removed.ex", "defmodule SeedRemoved do\n def value, do: :gone\nend\n")
    put(source, "lib/unchanged.ex", "defmodule SeedUnchanged do\n def value, do: :same\nend\n")
    prepare(source, project, metadata)
    assert_value(project, "{SeedApp.value(), SeedMiddle.value()}", "{\"old\", :old}")
    unchanged = beam(project, :seed_app, "SeedUnchanged") |> File.read!()
    stable_beam = beam(project, :seed_stable, "SeedStable") |> File.read!()
    # Sentinel mtimes establish that files were retained, not rebuilt to equal bytes.
    File.touch!(beam(project, :seed_app, "SeedUnchanged"), 1_000_000)
    File.touch!(beam(project, :seed_stable, "SeedStable"), 1_000_000)

    # Same-size edits with deliberately old snapshot mtimes must still compile.
    File.cp!(Path.join(project, "mix.lock"), Path.join(source, "mix.lock"))
    put(source, "lib/main.ex", app_source("new"))
    File.touch!(Path.join(source, "lib/main.ex"), 1_000_000)
    File.rm!(Path.join(source, "lib/removed.ex"))
    output = prepare(source, project, metadata)
    assert output =~ "retaining compatible artifacts"
    assert_value(project, "SeedApp.value()", "\"new\"")
    assert File.read!(beam(project, :seed_app, "SeedUnchanged")) == unchanged
    assert File.read!(beam(project, :seed_stable, "SeedStable")) == stable_beam
    assert File.stat!(beam(project, :seed_app, "SeedUnchanged"), time: :posix).mtime == 1_000_000
    assert File.stat!(beam(project, :seed_stable, "SeedStable"), time: :posix).mtime == 1_000_000
    refute File.exists?(beam(project, :seed_app, "SeedRemoved"))

    put(leaf, "lib/main.ex", "defmodule SeedLeaf do\n def value, do: :new\nend\n")
    new_leaf = commit(leaf)

    new_deps =
      List.keyreplace(
        deps,
        :seed_leaf,
        0,
        {:seed_leaf, [git: leaf, ref: new_leaf, override: true]}
      )

    project_file(source, :seed_app, new_deps)
    put(project, "deps/seed_leaf/stale-native-object", "must not survive a changed dependency")
    output = prepare(source, project, metadata)
    assert output =~ "seed_leaf"
    assert output =~ "seed_middle"
    assert_value(project, "SeedMiddle.value()", ":new")
    assert File.read!(beam(project, :seed_stable, "SeedStable")) == stable_beam
    assert File.stat!(beam(project, :seed_stable, "SeedStable"), time: :posix).mtime == 1_000_000
    refute File.exists?(Path.join(project, "deps/seed_leaf/stale-native-object"))

    # Recompile a dependency that reads application configuration at compile time.
    put(
      leaf,
      "lib/main.ex",
      "defmodule SeedLeaf do\n @value Application.compile_env(:seed_leaf, :value, :default)\n def value, do: @value\nend\n"
    )

    configured_ref = commit(leaf)

    configured_deps =
      List.keyreplace(
        deps,
        :seed_leaf,
        0,
        {:seed_leaf, [git: leaf, ref: configured_ref, override: true]}
      )

    project_file(source, :seed_app, configured_deps)
    put(source, "config/config.exs", "import Config\nconfig :seed_leaf, :value, :first\n")
    prepare(source, project, metadata)
    assert_value(project, "SeedMiddle.value()", ":first")
    put(source, "config/config.exs", "import Config\nconfig :seed_leaf, :value, :other\n")
    output = prepare(source, project, metadata)
    assert output =~ "compilation settings changed"
    assert_value(project, "SeedMiddle.value()", ":other")

    project_file(source, :seed_app, [{:seed_stable, [git: stable, ref: stable_ref]}])
    output = prepare(source, project, metadata)
    assert output =~ "retaining compatible artifacts"
    refute File.exists?(Path.join(project, "deps/seed_leaf"))
    refute File.exists?(Path.join(project, "_build/test/lib/seed_middle"))
    assert_value(project, "SeedApp.value()", "\"new\"")

    put(project, "_build/test/stale-build-option", "remove when compiler settings change")

    project_file(
      source,
      :seed_app,
      [{:seed_stable, [git: stable, ref: stable_ref]}],
      "elixirc_options: [debug_info: false],"
    )

    output = prepare(source, project, metadata)
    assert output =~ "compilation settings changed"
    refute File.exists?(Path.join(project, "_build/test/stale-build-option"))
  end

  defp prepare(source, workspace, metadata) do
    FixtureSeed.sync(source, workspace)

    commands = [
      {"mix", ["deps.get"]},
      {"elixir",
       ["-r", Inventory.path("priv/fixtures/build_seed.exs"), "-S", "mix", "eab.seed", metadata]},
      {"mix", ["deps.get"]},
      {"mix", ["deps.clean", "--unused"]},
      {"mix", ["deps.loadpaths"]},
      {"mix", ["compile", "--warnings-as-errors"]}
    ]

    Enum.map_join(commands, fn {exe, args} -> run(workspace, exe, args) end)
  end

  defp run(project, exe, args) do
    Command.run!(
      "env",
      ["-u", "MIX_BUILD_ROOT", "-u", "MIX_DEPS_PATH", "MIX_ENV=test", exe | args],
      cd: project,
      timeout: 30
    )
  end

  defp assert_value(project, expression, expected) do
    output =
      run(project, "mix", ["run", "--no-start", "--no-compile", "-e", "IO.inspect(#{expression})"])

    assert String.trim(output) |> String.ends_with?(expected)
  end

  defp beam(project, app, module),
    do: Path.join(project, "_build/test/lib/#{app}/ebin/Elixir.#{module}.beam")

  defp app_source(value), do: "defmodule SeedApp do\n def value, do: #{inspect(value)}\nend\n"

  defp package(path, app, deps, code) do
    project_file(path, app, deps)
    put(path, "lib/main.ex", code)
    put(path, ".gitignore", "_build/\ndeps/\n")
  end

  defp project_file(path, app, deps, extra \\ "") do
    put(
      path,
      "mix.exs",
      "defmodule #{Macro.camelize(to_string(app))}.MixProject do\n use Mix.Project\n def project, do: [app: #{inspect(app)}, version: \"0.1.0\", #{extra} deps: #{inspect(deps, limit: :infinity)}]\nend\n"
    )
  end

  defp commit(path) do
    Command.run!("git", ["init", "-q"], cd: path)
    Command.run!("git", ["add", "."], cd: path)

    Command.run!(
      "git",
      ["-c", "user.name=Test", "-c", "user.email=test@localhost", "commit", "-qm", "revision"],
      cd: path
    )

    Command.run!("git", ["rev-parse", "HEAD"], cd: path) |> String.trim()
  end

  defp put(root, relative, content) do
    path = Path.join(root, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end
end
