defmodule Eab.TaskContract do
  @moduledoc """
  The one task format, `schema_version: 3` (factory/README.md, section 3): its grading contract and the instruction
  text the model is given. Every other version is refused, the bench's own formats included.
  """

  @partial_reasons ~w(single_hunk no_variant_compiles no_variant_fails)

  # Fields of the bench's formats that the one format removed (section 3). A manifest that still has one is refused,
  # so a bench case with its version number changed cannot load here.
  @removed ~w(title family domains suite source_inspiration regression_command acceptance_command
    required_acceptance_tests require_regression_test partial_repair_probe)

  def read(spec) do
    case spec["schema_version"] do
      3 -> validate!(spec)
      _ -> raise "Unsupported case schema version"
    end
  end

  def validate!(spec) do
    contract = spec["grading"] || %{}
    kind = spec["task_kind"]
    paths = contract["protected_paths"] || []
    requirements = contract["requirements"] || []
    required = contract["required"] || []
    starting = contract["starting_failures"] || []

    unless kind in ~w(bug_fix feature) and contract["adapter"] == "exunit" and
             nonempty_strings?(paths) and Enum.all?(paths, &safe_directory?/1) and
             nonempty_strings?(contract["test_suffixes"]) and
             nonempty_strings?(required) and nonempty_strings?(starting) and
             Enum.all?(starting, &(&1 in required)) and
             contract["model_tests"] == "behavioral" and
             spec["acceptance_patch"] == "reference-tests.patch" and
             is_map(spec["clarifications"] || %{}) and
             not Enum.any?(@removed, &Map.has_key?(spec, &1)) and
             not Map.has_key?(spec["runtime"] || %{}, "browser") and
             partial_control?(spec["partial_control"]) and
             is_list(requirements) and
             Enum.all?(requirements, fn r ->
               is_map(r) and Enum.sort(Map.keys(r)) == ["id", "text"] and is_binary(r["id"]) and
                 String.trim(r["id"]) != "" and is_binary(r["text"]) and
                 String.trim(r["text"]) != ""
             end),
           do: raise("Invalid task contract")

    ids = Enum.map(requirements, & &1["id"])
    unless length(Enum.uniq(ids)) == length(ids), do: raise("Requirement ids must be unique")

    services!(spec["services"])
    %{"release_files" => release_files} = runtime_extras!(spec["runtime"] || %{})

    for %{"url" => url} <- release_files,
        not Eab.ReleaseFiles.allowed?(url),
        do: raise("Release file host is not allowed by this installation: #{url}")

    for key <- ~w(acceptance preservation) do
      unless Enum.take(OptionParser.split(contract[key] || ""), 2) == ["mix", "test"],
        do: raise("Invalid #{key} test command")
    end

    contract
    |> Map.put("kind", kind)
    |> Map.put("requirements", requirements)
    |> Map.put("partial", spec["partial_control"]["present"])
  end

  # The partial-fix control is optional and recorded per task: present, or absent with one of the counted reasons.
  defp partial_control?(%{"present" => true} = control), do: map_size(control) == 1

  defp partial_control?(%{"present" => false, "reason" => reason} = control),
    do: map_size(control) == 2 and reason in @partial_reasons

  defp partial_control?(_), do: false

  def test_file?(contract, path) do
    Enum.any?(contract["protected_paths"], &String.starts_with?(path, &1)) and
      Enum.any?(contract["test_suffixes"], &String.ends_with?(path, &1))
  end

  def instructions(spec) do
    contract = read(spec)

    # The one format fixes `model_tests` at "behavioral"; the bench's sentences for "preservation" (refactors) and
    # "optional" (its older format) cannot be reached here and went with those inputs.
    tests =
      "Add or change a test that fails in its test body on the starting source and passes after your change. Compilation/setup failures do not count."

    "Complete the #{contract["kind"]} task in /workspace. Investigate the source and run the relevant tests.\n" <>
      "Test command: #{contract["preservation"]}.\n#{tests}\n" <>
      Enum.map_join(
        contract["requirements"],
        "\n",
        &"Required outcome (#{&1["id"]}): #{&1["text"]}"
      )
  end

  @doc """
  The extra system packages and release files a task asks for (factory/README.md, section 6, change 3), checked for
  their form: `runtime.packages` is a list of package names, each matching a strict pattern, so no name can carry a
  shell command; `runtime.release_files` is a list of `{"url", "sha256", "kind"}` with an `https` URL, a lower-case
  SHA-256 and a known kind: `deb`, a Debian package, or `bin`, a bare program, which also carries the `name` it is
  installed under in `/usr/local/bin` (a strict pattern, no path; no name twice). Absent or empty, both are `[]` and
  the workspace recipe is the bench's. Whether a release file's host is allowed is the installation's setting, checked
  by `validate!/1` and again when the file is fetched.
  """
  def runtime_extras!(runtime) do
    packages = Map.get(runtime, "packages") || []
    release_files = Map.get(runtime, "release_files") || []

    unless is_list(packages) and packages == Enum.uniq(packages) and
             Enum.all?(packages, &package_name?/1),
           do: raise("Invalid runtime.packages")

    unless is_list(release_files) and Enum.all?(release_files, &release_file?/1) and
             length(Enum.uniq_by(release_files, & &1["sha256"])) == length(release_files) and
             unique_program_names?(release_files),
           do: raise("Invalid runtime.release_files")

    %{"packages" => packages, "release_files" => release_files}
  end

  @doc """
  The `services` a task asks for, checked for the Redis entry (factory/README.md, section 6, change 9): `redis` must be
  `{"image": ...}` with nothing else, the image pinned by digest (`<name>[:<tag>]@sha256:<64 hex digits>`). The
  entries for `postgres` and `clickhouse` are checked as before, when the engine resolves them. Absent, `services` is
  `%{}`.
  """
  def services!(services) do
    services = services || %{}
    unless is_map(services), do: raise("Invalid services")

    case Map.fetch(services, "redis") do
      :error -> :ok
      {:ok, entry} -> unless pinned_image?(entry), do: raise("Invalid services.redis")
    end

    services
  end

  defp pinned_image?(%{"image" => image} = entry),
    do:
      map_size(entry) == 1 and is_binary(image) and
        Regex.match?(~r/\A[a-z0-9][a-z0-9._\/:-]*@sha256:[0-9a-f]{64}\z/, image)

  defp pinned_image?(_), do: false

  @release_file_kinds ~w(deb bin)
  def release_file_kinds, do: @release_file_kinds

  # Debian and Alpine package names: lower-case letters, digits and `+ . -`, starting with a letter or digit.
  defp package_name?(name),
    do: is_binary(name) and Regex.match?(~r/\A[a-z0-9][a-z0-9+.\-]{0,99}\z/, name)

  # The name a bare program is installed under: letters, digits and `+ . _ -`, starting with a letter or digit, so it
  # can carry neither a path nor a shell command.
  defp program_name?(name),
    do: is_binary(name) and Regex.match?(~r/\A[A-Za-z0-9][A-Za-z0-9+._\-]{0,99}\z/, name)

  defp release_file?(%{"url" => url, "sha256" => sha, "kind" => kind} = entry) do
    fields? =
      case kind do
        "bin" -> map_size(entry) == 4 and program_name?(entry["name"])
        _ -> map_size(entry) == 3
      end

    fields? and kind in @release_file_kinds and is_binary(sha) and
      Regex.match?(~r/\A[0-9a-f]{64}\z/, sha) and Eab.ReleaseFiles.https_url?(url)
  end

  defp release_file?(_), do: false

  defp unique_program_names?(release_files) do
    names = for %{"kind" => "bin", "name" => name} <- release_files, do: name
    length(Enum.uniq(names)) == length(names)
  end

  defp safe_directory?(path),
    do:
      String.ends_with?(path, "/") and not String.starts_with?(path, "/") and
        Enum.all?(Path.split(path), &(&1 not in [".", "..", ".git"])) and
        not String.starts_with?(path, "-") and not String.contains?(path, ["*", "?", "[", ":"])

  defp nonempty_strings?(list),
    do:
      is_list(list) and list != [] and list == Enum.uniq(list) and
        Enum.all?(list, &(is_binary(&1) and String.trim(&1) != ""))
end
