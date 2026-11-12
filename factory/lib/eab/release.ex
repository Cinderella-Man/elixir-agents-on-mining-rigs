defmodule Eab.Release do
  @moduledoc "Immutable, checksummed inputs for an experiment, separate from mutable cache pointers."
  alias Eab.{Cache, Inventory, Store}

  @doc """
  Freezes the tasks `ids` of one run or check, and only those (factory/README.md, section 5.1): the release holds
  their files, in the order of their ids, and other tasks in the task folder may change or arrive without touching it.
  """
  def freeze(ids) do
    unless is_list(ids) and ids != [] and ids == Enum.uniq(ids) and
             Enum.all?(ids, &Store.valid_id?/1),
           do: raise("Invalid release case inventory")

    for id <- ids do
      unless Inventory.member?(id), do: raise("Unknown task: #{id}")

      # Every task is in the one format (README section 3); there is no admission record to check.
      spec = Inventory.spec(id)
      unless spec["id"] == id, do: raise("Task folder and task id differ: #{id}")
      Eab.TaskContract.read(spec)
    end

    protocol = Inventory.protocol(Enum.sort(ids))
    cases = protocol["inventory"]["cases"]

    id = Cache.key(protocol)

    Cache.locked({:release, id}, fn ->
      case Store.read("releases/#{id}/manifest.json") do
        nil ->
          for case_id <- cases, {file, hash} <- protocol["fixtures"][case_id] do
            unless Path.basename(file) == file, do: raise("Invalid release fixture path")
            body = Inventory.file(case_id, file)
            unless Inventory.hash(body) == hash, do: raise("Case changed while freezing release")
            Store.write_text("releases/#{id}/cases/#{case_id}/#{file}", body)
          end

          release = %{"version" => 1, "id" => id, "protocol" => protocol}
          verify!(release)
          Store.write("releases/#{id}/manifest.json", release)
          release

        _ ->
          read!(id)
      end
    end)
  end

  def read!(id) do
    unless is_binary(id) and Regex.match?(~r/^[a-f0-9]{64}$/, id),
      do: raise("Invalid release identity")

    release = Store.read("releases/#{id}/manifest.json")

    unless (release && release["version"] == 1) and release["id"] == id and
             Cache.key(release["protocol"]) == id,
           do: raise("Release record is missing or corrupt")

    for {case_id, files} <- release["protocol"]["fixtures"], {file, hash} <- files do
      unless Inventory.hash_file(Store.path("releases/#{id}/cases/#{case_id}/#{file}")) == hash,
        do: raise("Frozen release fixture is corrupt: #{case_id}/#{file}")
    end

    release
  end

  # Boundaries check the relevant case, rather than rereading all fixtures for
  # every preparation/attempt/grading event. Start/end checks cover the corpus.
  # Benchmark code may change between a run's start and its resumption (ADR 0011);
  # its cases, fixtures and agent may not. Only the release's own tasks are checked:
  # the rest of the task folder is not part of it.
  def verify!(release, case_id \\ nil) do
    protocol = release["protocol"]
    cases = if case_id, do: [case_id], else: protocol["inventory"]["cases"]

    unless Cache.key(protocol) == release["id"] and
             protocol["inventory"]["id"] == Inventory.config()["id"] and
             Enum.all?(cases, &Inventory.member?/1) and
             protocol["agent"] == Eab.Pi.identity(),
           do: raise("Benchmark cases or agent changed; start a new run")

    for id <- cases do
      unless protocol["fixtures"][id] == Inventory.fixture_hashes(id),
        do: raise("Benchmark case changed: #{id}; start a new run")
    end

    :ok
  end

  def experiment(release_id, endpoint, settings, selection \\ nil) do
    identity = %{
      "release" => release_id,
      "model" => model_identity(endpoint),
      "settings" => settings,
      "network" => "offline-workspaces-model-gateway-only-v1"
    }

    Cache.key(if selection, do: Map.put(identity, "selection", selection), else: identity)
  end

  def model_identity(endpoint),
    do: Map.take(endpoint, ~w(url backend model context profile))

  def case_metadata(release) do
    Map.new(release["protocol"]["inventory"]["cases"], fn id ->
      spec = Store.read("releases/#{release["id"]}/cases/#{id}/case.json")

      {id,
       %{
         "project" => spec["project"] || spec["suite"],
         "task_kind" => spec["task_kind"] || "bug_fix",
         "family" => spec["family"],
         "languages" =>
           spec["languages"] ||
             Enum.filter(spec["domains"] || [], &(&1 in ~w(elixir javascript typescript)))
       }}
    end)
  end
end
