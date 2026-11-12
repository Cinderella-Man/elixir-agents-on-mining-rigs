defmodule Eab.DockerSettingsDockerTest do
  @moduledoc """
  The installation's labels and CPU share on real containers and images (factory/README.md, section 6, change 1).
  The labels are this test's own `etf.check=<id>` plus those of `EAB_DOCKER_LABELS`, the share is `EAB_CPU_SHARES`
  or 300. Every container the engine starts for a workspace with Postgres and ClickHouse, the two database images it
  builds and the snapshot it commits are inspected, and one line per container and image is printed to the log.
  """
  use ExUnit.Case, async: false
  @moduletag :docker
  alias Eab.{Command, Sandbox, ServiceImages, Store}

  @tag timeout: 600_000
  test "the engine's containers and images carry the labels and the share, under the factory's names" do
    previous = Store.root()
    id = "etf-settings-check-#{System.unique_integer([:positive])}"
    root = Path.join(System.tmp_dir!(), id)
    File.mkdir_p!(root)
    Application.put_env(:eab, :data_dir, root)

    extra =
      String.split(System.get_env("EAB_DOCKER_LABELS", ""), [",", " ", "\t", "\n"], trim: true)

    labels = ["etf.check=#{id}" | extra]

    shares =
      case String.trim(System.get_env("EAB_CPU_SHARES", "")) do
        "" -> 300
        text -> String.to_integer(text)
      end

    Application.put_env(:eab, :docker_labels, labels)
    Application.put_env(:eab, :cpu_shares, shares)
    expected = Map.new(labels, &List.to_tuple(String.split(&1, "=", parts: 2)))
    before = tags()

    on_exit(fn ->
      Application.delete_env(:eab, :docker_labels)
      Application.delete_env(:eab, :cpu_shares)

      # Only tags this test created: its workspace image and the engine's new tags.
      created =
        Enum.filter(tags() -- before, fn tag ->
          String.starts_with?(tag, id <> ":") or String.starts_with?(tag, "elixir-task-factory:")
        end)

      for _ <- 1..2, tag <- created, do: Command.run("docker", ["image", "rm", tag])
      Application.put_env(:eab, :data_dir, previous)
      File.rm_rf!(root)
    end)

    workspace = "#{id}:workspace"

    File.write!(
      Path.join(root, "Dockerfile"),
      "FROM #{Eab.TestTooling.image()}\nCMD [\"sleep\", \"infinity\"]\n"
    )

    docker(
      [
        "buildx",
        "build",
        "--load",
        "--provenance=false",
        "--network=none",
        "-t",
        workspace,
        root
      ],
      timeout: 120
    )

    postgres = ServiceImages.ensure("postgres", "postgres:16-alpine")

    clickhouse =
      ServiceImages.ensure("clickhouse", "clickhouse/clickhouse-server:24.12.2.29-alpine")

    runtime = %{
      "image" => workspace,
      "services" => %{"postgres" => postgres, "clickhouse" => clickhouse}
    }

    snapshot =
      Sandbox.with_runtime(
        id,
        %{"runtime" => %{}},
        runtime,
        id,
        fn box ->
          for {name, cpus} <- [
                {box.name, 2.0e9},
                {box.name <> "-db", 1.0e9},
                {box.name <> "-ch", 2.0e9}
              ] do
            [info] = docker(["inspect", name]) |> Jason.decode!()
            own = info["Config"]["Labels"]

            IO.puts(
              "T7 container #{name} labels=#{Jason.encode!(own)} cpu_shares=#{info["HostConfig"]["CpuShares"]} nano_cpus=#{info["HostConfig"]["NanoCpus"]}"
            )

            assert info["Name"] == "/" <> name
            assert String.starts_with?(name, "etf-")
            assert own["etf.installation"] == Sandbox.installation()
            assert own["etf.run"] == id
            assert Map.take(own, Map.keys(expected)) == expected
            refute Map.has_key?(own, "eab.installation") or Map.has_key?(own, "eab.run")
            assert info["HostConfig"]["CpuShares"] == shares
            assert info["HostConfig"]["NanoCpus"] == trunc(cpus)
          end

          names =
            docker(["ps", "-a", "--filter", "label=etf.run=#{id}", "--format", "{{.Names}}"])
            |> String.split()

          assert Enum.sort(names) == Enum.sort([box.name, box.name <> "-db", box.name <> "-ch"])
          ServiceImages.capture("postgres", box.name <> "-db", id)
        end,
        before_test: false
      )

    for {what, image} <- [
          {"postgres layout", postgres},
          {"clickhouse layout", clickhouse},
          {"postgres snapshot", snapshot}
        ] do
      [info] = docker(["image", "inspect", image]) |> Jason.decode!()
      own = info["Config"]["Labels"] || %{}

      IO.puts(
        "T7 image #{what} #{image} tags=#{Jason.encode!(info["RepoTags"])} labels=#{Jason.encode!(Map.take(own, Map.keys(expected)))}"
      )

      assert Map.take(own, Map.keys(expected)) == expected
      assert info["RepoTags"] != []
      assert Enum.all?(info["RepoTags"], &String.starts_with?(&1, "elixir-task-factory:"))
    end

    # Another controller on the same Docker builds the same layout recipe with its own labels and moves the shared
    # tag. The image stays under this installation's own tag, and the cache still finds it.
    identity = "layout-" <> Eab.Cache.key(ServiceImages.recipe("postgres", "postgres:16-alpine"))
    docker(["image", "tag", workspace, "elixir-task-factory:" <> identity])
    kept = docker(["image", "inspect", postgres, "--format", "{{.Id}}"]) |> String.trim()
    assert kept == postgres
    assert ServiceImages.own_tag(identity) in image_tags(postgres)
    assert ServiceImages.ensure("postgres", "postgres:16-alpine") == postgres
  end

  defp image_tags(image),
    do: docker(["image", "inspect", image, "--format", "{{json .RepoTags}}"]) |> Jason.decode!()

  defp tags,
    do: docker(["image", "ls", "--format", "{{.Repository}}:{{.Tag}}"]) |> String.split()

  defp docker(args, opts \\ []) do
    Command.run!("docker", args, Keyword.put_new(opts, :timeout, 120))
  end
end
