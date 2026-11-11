defmodule Eab.AgentImage do
  @moduledoc "Attaches the independently cached Pi runtime to a pristine project image."
  alias Eab.{BuildCache, Cache, Command, Inventory, Pi, Store}

  def inputs(spec, project_image) do
    %{
      "version" => 1,
      "project" => project_image,
      "pi" => Pi.identity(),
      "node" => Pi.node_image(spec),
      "bridge" => Inventory.hash_file(Inventory.path("priv/pi/bridge.mjs")),
      "watchdog" => Inventory.hash_file(Inventory.path("priv/pi/bash-watchdog.mjs")),
      "recipe" => Inventory.hash(recipe("PROJECT", "NODE"))
    }
  end

  def ensure(spec, project_image, opts \\ []) do
    inputs = inputs(spec, project_image)

    {artifact, _} =
      Cache.fetch("agents", inputs, fn _ -> build(inputs) end, opts)

    artifact["image"]
  end

  def recipe(project, node) do
    """
    FROM #{node} AS pi
    WORKDIR /opt/pi
    COPY package.json package-lock.json ./
    RUN npm ci --ignore-scripts --no-audit --no-fund
    COPY bridge.mjs ./
    COPY --chmod=0755 bash-watchdog.mjs ./
    FROM #{project}
    COPY --from=pi /opt/pi /opt/pi
    COPY --from=pi /usr/local/bin/node /opt/pi/node
    RUN /opt/pi/node /opt/pi/node_modules/@earendil-works/pi-coding-agent/dist/bundle/cli.js --version
    """
  end

  defp build(inputs) do
    id = Cache.key(inputs)
    dest = Store.path("build/agents/#{id}")
    File.mkdir_p!(dest)

    for file <- ["package.json", "package-lock.json", "bridge.mjs", "bash-watchdog.mjs"],
        do: File.cp!(Inventory.path("priv/pi/#{file}"), Path.join(dest, file))

    project = BuildCache.tag(inputs["project"], "project")
    File.write!(Path.join(dest, "Dockerfile"), recipe(project, inputs["node"]))
    tag = "elixir-agent-benchmark:agent-#{id}"

    Command.run!(
      "docker",
      ["buildx", "build", "--load", "--provenance=false", "--progress=plain", "-t", tag, dest],
      timeout: 1200,
      limit: 2_000_000
    )

    image =
      Command.run!("docker", ["image", "inspect", tag, "--format", "{{.Id}}"])
      |> String.trim()

    %{"image" => image, "images" => [image]}
  end
end
