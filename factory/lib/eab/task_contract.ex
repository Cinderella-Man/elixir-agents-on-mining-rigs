defmodule Eab.TaskContract do
  @moduledoc "Explicit task acceptance, preservation and model-test policies, with legacy repair support."

  def read(spec) do
    case spec["schema_version"] do
      nil -> legacy(spec)
      2 -> validate!(spec)
      _ -> raise "Unsupported case schema version"
    end
  end

  defp legacy(spec) do
    %{
      "adapter" => "exunit",
      "kind" => "bug_fix",
      "acceptance" => spec["acceptance_command"],
      "preservation" => spec["regression_command"],
      "protected_paths" => ["test/"],
      "test_suffixes" => ["_test.exs"],
      "required" => spec["required_acceptance_tests"] || [],
      "starting_failures" => [],
      "requirements" => [],
      "model_tests" => if(spec["require_regression_test"], do: "behavioral", else: "optional")
    }
  end

  def validate!(spec) do
    contract = spec["grading"] || %{}
    kind = spec["task_kind"]
    paths = contract["protected_paths"] || []
    requirements = contract["requirements"] || []
    required = contract["required"] || []
    starting = contract["starting_failures"] || []

    unless kind in ~w(bug_fix feature refactor) and contract["adapter"] in ~w(exunit node) and
             nonempty_strings?(paths) and Enum.all?(paths, &safe_directory?/1) and
             nonempty_strings?(contract["test_suffixes"]) and
             nonempty_strings?(required) and nonempty_strings?(starting) and
             Enum.all?(starting, &(&1 in required)) and
             contract["model_tests"] ==
               if(kind == "refactor", do: "preservation", else: "behavioral") and
             is_list(requirements) and requirements != [] and
             Enum.all?(requirements, fn r ->
               is_map(r) and is_binary(r["id"]) and r["id"] != "" and
                 is_binary(r["text"]) and String.trim(r["text"]) != "" and
                 r["kind"] in ~w(behavior structural) and nonempty_strings?(r["checks"]) and
                 Enum.all?(r["checks"], &(&1 in required))
             end),
           do: raise("Invalid explicit task contract")

    ids = Enum.map(requirements, & &1["id"])
    mapped = Enum.flat_map(requirements, & &1["checks"]) |> Enum.uniq() |> Enum.sort()

    unless length(Enum.uniq(ids)) == length(ids) and mapped == Enum.sort(required),
      do: raise("Every required acceptance check needs an unambiguous requirement mapping")

    if kind == "refactor" and
         not Enum.any?(requirements, fn r ->
           r["kind"] == "structural" and Enum.any?(r["checks"], &(&1 in starting))
         end),
       do:
         raise(
           "Refactors need a stated structural or interface check that rejects unchanged code"
         )

    for key <- ~w(acceptance preservation) do
      args = OptionParser.split(contract[key] || "")
      prefix = if contract["adapter"] == "exunit", do: ["mix", "test"], else: ["node", "--test"]
      unless Enum.take(args, 2) == prefix, do: raise("Invalid #{key} test command")
    end

    Map.put(contract, "kind", kind)
  end

  def test_file?(contract, path) do
    Enum.any?(contract["protected_paths"], &String.starts_with?(path, &1)) and
      Enum.any?(contract["test_suffixes"], &String.ends_with?(path, &1))
  end

  def instructions(spec) do
    contract = read(spec)

    tests =
      case contract["model_tests"] do
        "behavioral" ->
          "Add or change a test that fails in its test body on the starting source and passes after your change. Compilation/setup failures do not count."

        "preservation" ->
          "Add or change a test covering the stated contract or preserved behavior. No behavioral regression on the starting source is required for this refactor."

        "optional" ->
          "Run the relevant tests; additional tests are optional."
      end

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
