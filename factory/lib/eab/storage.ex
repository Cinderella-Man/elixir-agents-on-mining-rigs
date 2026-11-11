defmodule Eab.Storage do
  @moduledoc "On-demand Docker-reported shared/unique image sizes and allocated controller storage."
  alias Eab.{Command, Store}

  def read do
    version =
      Command.run!("docker", ["version", "--format", "{{.Server.APIVersion}}"], timeout: 15)
      |> String.trim()

    [major, minor] = version |> String.split(".") |> Enum.map(&String.to_integer/1)

    unless major == 1 and minor >= 44,
      do: raise("Docker storage inspection requires API 1.44 or newer")

    # 1.52 still exposes shared image sizes in the legacy response. Later APIs
    # removed these fields; version the request rather than interpreting absence as zero.
    api = "1.#{min(minor, 52)}"

    result =
      Command.run(
        "curl",
        [
          "--fail",
          "--silent",
          "--show-error",
          "--max-time",
          "60",
          "--unix-socket",
          "/var/run/docker.sock",
          "http://localhost/v#{api}/system/df?type=image"
        ],
        timeout: 65,
        limit: 8_388_608
      )

    unless result["returncode"] == 0 and not result["output_truncated"],
      do:
        raise(
          "Docker could not provide a complete storage snapshot: #{String.slice(result["output"], 0, 500)}"
        )

    images = summarize(Jason.decode!(result["output"]))

    areas =
      for name <- ~w(sources build scratch runs releases candidates cache qualifications),
          File.dir?(Store.path(name)),
          into: %{} do
        value =
          Command.run!(
            "du",
            ["--summarize", "--block-size=1", "--one-file-system", Store.path(name)],
            timeout: 30
          )
          |> String.split()
          |> hd()
          |> String.to_integer()

        {name, value}
      end

    totals =
      Command.run!("docker", ["system", "df", "--format", "{{json .}}"],
        timeout: 65,
        limit: 20_000
      )
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    Map.merge(images, %{
      "controller_areas" => areas,
      "docker_totals" => totals,
      "recorded_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "api" => api
    })
  end

  def summarize(data) do
    unless is_list(data["Images"]), do: raise("Docker did not report per-image storage data")

    images =
      data["Images"]
      |> Enum.uniq_by(& &1["Id"])
      |> Enum.filter(fn image ->
        Enum.any?(image["RepoTags"] || [], &String.starts_with?(&1, "elixir-agent-benchmark:"))
      end)
      |> Enum.map(fn image ->
        size = image["Size"]
        shared = image["SharedSize"]

        valid =
          is_integer(size) and is_integer(shared) and size >= 0 and shared >= 0 and shared <= size

        %{
          "image" => image["Id"],
          "tags" => image["RepoTags"],
          "size" => size,
          "shared" => if(valid, do: shared),
          "unique" => if(valid, do: size - shared)
        }
      end)
      |> Enum.sort_by(&List.first(&1["tags"]))

    %{
      "images" => images,
      "daemon_image_bytes" => data["LayersSize"],
      "owned_unique_bytes" =>
        if(Enum.all?(images, &is_integer(&1["unique"])),
          do: Enum.sum(Enum.map(images, & &1["unique"]))
        )
    }
  end

  def bytes(nil), do: "Unavailable"

  def bytes(value) when is_integer(value) and value >= 0,
    do: "#{Float.round(value / 1_073_741_824, 3)} GiB"

  def bytes(_), do: "Unavailable"
end
