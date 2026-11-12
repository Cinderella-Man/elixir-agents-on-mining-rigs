defmodule Eab.RuntimeExtrasDockerTest do
  @moduledoc """
  A made-up task's extra system package and self-made release files, a `.deb` and a bare program (factory/README.md,
  section 6, change 3), built
  into an image. The lines built are the ones the task's workspace recipe carries between the bench's own system
  packages and the user line, on the tooling image as the base: the rest of the toolchain stage would download the
  bench's build tools and Hex, which this test does not. The one download is the package from the base image's own
  distribution; the release file is a Debian package this test makes and serves to the engine itself.
  """
  use ExUnit.Case, async: false
  @moduletag :docker
  alias Eab.{Command, Fixtures, ReleaseFiles}

  @base Eab.TestTooling.image()

  setup do
    old =
      Map.new(
        [:data_dir, :release_file_hosts, :release_file_request],
        &{&1, Application.get_env(:eab, &1)}
      )

    id = "etf-extras-check-#{System.unique_integer([:positive])}"
    root = Path.join(System.tmp_dir!(), id)
    File.mkdir_p!(root)
    Application.put_env(:eab, :data_dir, Path.join(root, "data"))
    Application.put_env(:eab, :release_file_hosts, ["releases.example.test"])

    on_exit(fn ->
      Command.run("docker", ["image", "rm", "#{id}:good", "#{id}:bad"])
      for {key, value} <- old, do: Application.put_env(:eab, key, value)
      File.rm_rf!(root)
    end)

    %{id: id, root: root, deb: make_deb(root)}
  end

  @tag timeout: 600_000
  test "a made-up task's image gets its distribution package and its checked release file", %{
    id: id,
    root: root,
    deb: deb
  } do
    body = File.read!(deb)
    sha = :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
    url = "https://releases.example.test/etf-release-probe_1.0_all.deb"

    # A bare program, as a project's CI downloads onto its path: a script this test makes, kept non-executable here.
    program = "#!/bin/sh\necho etf program probe ran \"$@\"\n"
    program_sha = :crypto.hash(:sha256, program) |> Base.encode16(case: :lower)
    program_url = "https://releases.example.test/etf-program-probe-linux-x64"

    runtime = %{
      "image" => @base,
      "packages" => ["xdelta3"],
      "release_files" => [
        %{"url" => url, "sha256" => sha, "kind" => "deb"},
        %{
          "url" => program_url,
          "sha256" => program_sha,
          "kind" => "bin",
          "name" => "etf-program-probe"
        }
      ]
    }

    # The engine fetches the files through its own request function; here they are served from memory.
    Application.put_env(:eab, :release_file_request, fn opts ->
      case opts[:url] do
        ^url -> {:ok, Req.Response.new(status: 200, body: body)}
        ^program_url -> {:ok, Req.Response.new(status: 200, body: program)}
        _ -> {:ok, Req.Response.new(status: 404, body: "")}
      end
    end)

    context = Path.join(root, "good")
    ReleaseFiles.stage!(runtime["release_files"], context, fn _ -> :ok end)
    File.write!(Path.join(context, "Dockerfile"), extras_dockerfile(runtime))
    build!(context, "#{id}:good")

    out =
      run!(
        "#{id}:good",
        "dpkg-query -W -f='${Status}\\n' xdelta3 etf-release-probe && xdelta3 -V 2>&1 | head -1 && etf-release-probe"
      )

    assert out =~ ~r/\Ainstall ok installed\ninstall ok installed\n/
    assert out =~ ~r/Xdelta version 3/i
    assert out =~ "etf release probe installed"

    # The bare program is on the path under its name, executable by anyone, and runs.
    assert run!(
             "#{id}:good",
             "command -v etf-program-probe && stat -c %a /usr/local/bin/etf-program-probe && etf-program-probe --version"
           ) == "/usr/local/bin/etf-program-probe\n755\netf program probe ran --version\n"

    # The bind mount leaves no copy of the files in the image.
    refute run!("#{id}:good", "ls /tmp/eab-release-files 2>/dev/null || true") =~ ~r/deb|bin/
  end

  @tag timeout: 600_000
  test "a release file whose bytes do not match its checksum fails the build", %{
    id: id,
    root: root,
    deb: deb
  } do
    sha = :crypto.hash(:sha256, "other bytes") |> Base.encode16(case: :lower)

    runtime = %{
      "image" => @base,
      "release_files" => [
        %{"url" => "https://releases.example.test/x.deb", "sha256" => sha, "kind" => "deb"}
      ]
    }

    # The file is passed in from the build context under the name of the checksum it claims, as if the staging check
    # had been bypassed: the image build checks it again.
    context = Path.join(root, "bad")
    File.mkdir_p!(Path.join(context, "release-files"))
    File.cp!(deb, Path.join(context, "release-files/#{sha}.deb"))
    File.write!(Path.join(context, "Dockerfile"), extras_dockerfile(runtime))
    result = build(context, "#{id}:bad")

    assert result["returncode"] != 0
    assert result["output"] =~ "FAILED"
    assert Command.run("docker", ["image", "inspect", "#{id}:bad"])["returncode"] != 0
  end

  # The task's own recipe, cut to the lines it adds to the bench's toolchain stage.
  defp extras_dockerfile(runtime) do
    lines = Fixtures.dockerfile(%{"runtime" => runtime}, @base) |> String.split("\n")
    start = Enum.find_index(lines, &String.contains?(&1, "build-essential")) + 1
    stop = Enum.find_index(lines, &String.starts_with?(&1, "RUN if command -v useradd"))
    extra = Enum.slice(lines, start, stop - start)
    assert extra == Fixtures.extra_lines(runtime)
    assert extra != []
    Enum.join(["FROM #{@base}", "USER root" | extra], "\n") <> "\n"
  end

  defp make_deb(root) do
    pkg = Path.join(root, "pkg")
    File.mkdir_p!(Path.join(pkg, "DEBIAN"))
    File.mkdir_p!(Path.join(pkg, "usr/local/bin"))

    File.write!(Path.join(pkg, "DEBIAN/control"), """
    Package: etf-release-probe
    Version: 1.0
    Architecture: all
    Maintainer: Test <test@localhost>
    Description: A release file made up for the factory's tests
    """)

    File.write!(
      Path.join(pkg, "usr/local/bin/etf-release-probe"),
      "#!/bin/sh\necho etf release probe installed\n"
    )

    for dir <- ["", "DEBIAN", "usr", "usr/local", "usr/local/bin"],
        do: File.chmod!(Path.join(pkg, dir), 0o755)

    File.chmod!(Path.join(pkg, "usr/local/bin/etf-release-probe"), 0o755)
    File.chmod!(Path.join(pkg, "DEBIAN/control"), 0o644)
    deb = Path.join(root, "etf-release-probe_1.0_all.deb")
    Command.run!("dpkg-deb", ["--root-owner-group", "--build", pkg, deb], timeout: 60)
    deb
  end

  defp build(context, tag) do
    Command.run(
      "docker",
      ["buildx", "build", "--load", "--provenance=false", "--progress=plain"] ++
        Eab.DockerSettings.build_args() ++ ["-t", tag, context],
      timeout: 480,
      limit: 400_000
    )
  end

  defp build!(context, tag) do
    result = build(context, tag)
    assert result["returncode"] == 0, result["output"]
  end

  defp run!(image, script) do
    Command.run!(
      "docker",
      ["run", "--rm", "--network=none", "--cpus=1", "--memory=256m", image, "sh", "-c", script],
      timeout: 60
    )
  end
end
