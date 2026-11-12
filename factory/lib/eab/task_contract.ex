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
