defmodule Eab.BuildSeedDockerTest do
  use ExUnit.Case, async: false
  @moduletag :docker
  alias Eab.{BuildCache, Command, Fixtures, Inventory, Store}

  @tag timeout: 240_000
  test "generated Docker recipe forks a pristine seed into an isolated offline image" do
    id = "eab-seed-check-#{System.unique_integer([:positive])}"
    context = Path.join(System.tmp_dir!(), id)
    toolchain = "#{id}:tools"
    first = "#{id}:first"
    second = "#{id}:second"
    key = Inventory.hash(id)
    File.mkdir_p!(Path.join(context, "source/lib"))
    File.mkdir_p!(Path.join(context, "pi"))

    on_exit(fn ->
      if seed = Store.read("build-seeds/#{key}.json") do
        Command.run("docker", ["image", "rm", seed["tag"]])
      end

      Command.run("docker", ["image", "rm", first, second, toolchain])
      File.rm(Store.path("build-seeds/#{key}.json"))
      File.rm_rf!(context)
    end)

    File.write!(Path.join(context, "Dockerfile"), """
    FROM eab-tooling:dev
    USER root
    RUN groupadd -f agent && useradd -o -u 1000 -g agent -m agent && mkdir -p /workspace /opt/eab-seed && chown agent:agent /workspace /opt/eab-seed
    ENV MIX_ENV=test MIX_BUILD_ROOT=/workspace/_build MIX_DEPS_PATH=/workspace/deps HOME=/home/agent HEX_HOME=/opt/hex
    WORKDIR /workspace
    USER agent
    """)

    build(context, toolchain)
    tools_id = image_id(toolchain)
    build(context, toolchain)
    assert image_id(toolchain) == tools_id

    for file <- ["package.json", "package-lock.json", "bridge.mjs"],
        do: File.cp!(Inventory.path("priv/pi/#{file}"), Path.join(context, "pi/#{file}"))

    File.cp!(BuildCache.script(), Path.join(context, "build_seed.exs"))

    source = Path.join(context, "source")

    File.write!(Path.join(source, "mix.exs"), """
    defmodule SeedDocker.MixProject do
      use Mix.Project
      def project, do: [app: :seed_docker, version: "0.1.0", deps: []]
    end
    """)

    File.write!(Path.join(source, ".gitignore"), "_build/\ndeps/\n")

    File.write!(
      Path.join(source, "lib/main.ex"),
      "defmodule SeedDocker do\n def value, do: :old\nend\n"
    )

    File.write!(
      Path.join(source, "lib/removed.ex"),
      "defmodule SeedDeleted do\n def value, do: :gone\nend\n"
    )

    spec = %{
      "runtime" => %{
        "profile" => "livebook",
        "image" => "eab-tooling:dev",
        "setup_commands" => ["mix compile"]
      }
    }

    recipe = Fixtures.dockerfile(spec, "unused", nil, toolchain: toolchain)
    File.write!(Path.join(context, "Dockerfile"), recipe)
    build(context, first)

    image = image_id(first)

    seed = BuildCache.publish(key, image, "synthetic-first", "first-revision")
    assert BuildCache.find(key) == seed

    File.write!(
      Path.join(source, "lib/main.ex"),
      "defmodule SeedDocker do\n def value, do: :new\nend\n"
    )

    File.rm!(Path.join(source, "lib/removed.ex"))
    recipe = Fixtures.dockerfile(spec, "unused", nil, toolchain: toolchain, seed: seed["tag"])
    File.write!(Path.join(context, "Dockerfile"), recipe)
    build(context, second)

    check = """
    test ! -e /incoming && test ! -e /opt/eab-build-seed.exs &&
    test ! -e lib/removed.ex && test ! -e _build/test/lib/seed_docker/ebin/Elixir.SeedDeleted.beam &&
    test -z "$(git status --porcelain)" && test "$(git rev-list --count HEAD)" = 1 &&
    mix run --no-start --no-compile -e 'unless SeedDocker.value() == :new, do: raise("stale source")'
    """

    run(second, ["sh", "-c", check])
    # Building the second image cannot modify the published seed.
    run(first, [
      "mix",
      "run",
      "--no-start",
      "--no-compile",
      "-e",
      "unless SeedDocker.value() == :old, do: raise(\"mutated seed\")"
    ])
  end

  defp build(context, tag) do
    Command.run!(
      "docker",
      ["buildx", "build", "--load", "--provenance=false", "--progress=plain", "-t", tag, context],
      timeout: 90,
      limit: 200_000
    )
  end

  defp image_id(tag) do
    Command.run!("docker", ["image", "inspect", tag, "--format", "{{.Id}}"])
    |> String.trim()
  end

  defp run(image, args) do
    Command.run!(
      "docker",
      ["run", "--rm", "--network=none", "--cpus=2", "--memory=512m", image | args],
      timeout: 30
    )
  end
end
