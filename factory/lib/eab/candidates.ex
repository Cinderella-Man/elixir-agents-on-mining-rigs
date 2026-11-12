defmodule Eab.Candidates do
  @moduledoc """
  The import check of the one task format (factory/README.md, sections 3 and 4, check 1): immutable candidate
  bundles, validated and stored by content, then checked by the controls. There is no review record and no admission
  file.
  """
  alias Eab.{Cache, Fixtures, Grader, Inventory, Provenance, Store, TaskContract}

  # The files of a task (section 3.1). The optional ones may be absent; no other file is accepted.
  @required ~w(case.json provenance.json reference.patch reference-tests.patch integrity.patch)
  @optional ~w(upstream-docs.patch incomplete.patch ticket.md statement.json)

  def import(directory) do
    files = files!(directory)
    spec = Inventory.read_json(Path.join(directory, "case.json"))
    id = spec["id"]

    unless Store.valid_id?(id) and not Inventory.member?(id) and spec["schema_version"] == 3,
      do: raise("Import needs a new task ID and schema version 3; checked tasks are immutable")

    Inventory.with_case(id, directory, fn -> validate!(id) end)
    hashes = Map.new(files, &{&1, Inventory.hash_file(Path.join(directory, &1))})
    version = Cache.key(hashes)
    ref = %{"id" => id, "version" => version}

    Cache.locked({:candidate, id}, fn ->
      for {file, hash} <- hashes do
        content = File.read!(Path.join(directory, file))
        unless Inventory.hash(content) == hash, do: raise("Candidate changed during import")
        Store.write_text("#{prefix(ref)}/files/#{file}", content)
      end

      record = Map.merge(ref, %{"files" => hashes, "schema" => 1})
      Store.write("#{prefix(ref)}/manifest.json", record)
      ref
    end)
  end

  @doc """
  The files of a task folder, sorted, after the limits of check 1: at most 64 flat regular files of at most 4 MiB,
  each a `.json`, `.md` or `.patch` file of the one format, with every required one present. Raises otherwise.
  """
  def files!(directory) do
    files = File.ls!(directory) |> Enum.sort()

    unless files != [] and length(files) <= 64 and
             Enum.all?(files, fn file ->
               Path.basename(file) == file and Path.extname(file) in ~w(.json .md .patch) and
                 File.lstat!(Path.join(directory, file)).type == :regular and
                 File.stat!(Path.join(directory, file)).size <= 4_194_304
             end),
           do: raise("Candidates require bounded, flat regular fixture files")

    unless Enum.all?(@required, &(&1 in files)) and
             Enum.all?(files, &(&1 in (@required ++ @optional))),
           do: raise("A task holds exactly the files of the one format")

    files
  end

  def read!(ref) do
    record = Store.read("#{prefix(ref)}/manifest.json") || raise("Candidate is missing")

    unless record["id"] == ref["id"] and record["version"] == ref["version"] and
             Cache.key(record["files"]) == ref["version"],
           do: raise("Candidate record is corrupt")

    for {file, hash} <- record["files"] do
      unless Path.basename(file) == file and
               Inventory.hash_file(Store.path("#{prefix(ref)}/files/#{file}")) == hash,
             do: raise("Candidate files changed; import a new version")
    end

    record
  end

  def qualify(ref, emit, opts \\ []) do
    read!(ref)
    id = ref["id"]

    if Inventory.member?(id),
      do: raise("Admitted cases cannot be prepared through a candidate override")

    run_id = "candidate-#{id}"

    Cache.locked({:candidate, id}, fn ->
      Eab.Retention.lease(run_id)

      try do
        Inventory.with_case(id, Store.path("#{prefix(ref)}/files"), fn ->
          validate!(id)

          try do
            stage(ref, "checking_source", emit)
            source = Provenance.verify(id, emit, opts)
            stage(ref, "preparing", emit)
            runtime = Fixtures.ensure(id, emit, Keyword.put(opts, :run_id, run_id))
            stage(ref, "qualifying", emit)
            controls = Grader.qualify(id, run_id, emit)

            proof = %{
              "candidate" => ref,
              "source" => source,
              "runtime" => runtime,
              "controls" => controls,
              "grader" => Inventory.qualification_hash()
            }

            Store.write(
              "#{prefix(ref)}/qualification.json",
              Map.put(proof, "checksum", Cache.key(proof))
            )

            stage(ref, "qualified", emit)
            proof
          rescue
            error ->
              Store.write("#{prefix(ref)}/job.json", %{
                "status" => "error",
                "error" => Exception.message(error)
              })

              reraise error, __STACKTRACE__
          end
        end)
      after
        Eab.Sandbox.cleanup(run_id)
        Eab.Retention.release(run_id)
      end
    end)
  end

  @doc """
  Check 1 of the gate for a task the inventory can resolve (directly, or through `Eab.Inventory.with_case/3`): the
  manifest and its contract, the provenance, the files that must and may exist, the statement record, both test
  commands, and the folders each patch may touch.
  """
  def validate!(id) do
    spec = Inventory.spec(id)
    contract = TaskContract.read(spec)
    Provenance.validate!(spec, Inventory.read_json(Inventory.case_path(id, "provenance.json")))
    present? = &File.regular?(Inventory.case_path(id, &1))
    runtime = spec["runtime"] || %{}

    unless spec["id"] == id and is_binary(spec["project"]) and spec["project"] != "" and
             runtime["profile"] == "mix" and is_binary(runtime["image"]) and
             runtime["image"] != "",
           do: raise("Invalid task manifest")

    for file <- @required, not present?.(file), do: raise("Missing candidate artifact: #{file}")

    unless present?.("incomplete.patch") == contract["partial"],
      do: raise("incomplete.patch must exist exactly when partial_control.present is true")

    validate_statement!(id, present?)

    for command <- [contract["acceptance"], contract["preservation"]],
        do: Eab.TestAdapter.command(contract["adapter"], command, [])

    unless Grader.validate_patch(Inventory.file(id, "reference-tests.patch"), %{
             "allowed_edit_prefixes" => contract["protected_paths"]
           }) == {:ok, []},
           do: raise("reference-tests.patch must only change protected test paths")

    for file <- ~w(reference.patch incomplete.patch integrity.patch), present?.(file) do
      unless match?({:ok, _}, Grader.validate_patch(Inventory.file(id, file), spec)),
        do: raise("#{file} violates the allowed edit paths")
    end

    integrity = Inventory.file(id, "integrity.patch")

    unless length(String.split(integrity, "diff --git ")) == 2 and
             String.contains?(integrity, "\nnew file mode 100644\n") and
             String.contains?(integrity, "\n+System.halt(0)\n"),
           do: raise("integrity.patch must add one new file that calls System.halt(0)")

    :ok
  end

  # A task may pass the gate before it has a statement (section 3.1). When it has one, `statement.json` names its
  # writer and the SHA-256 of `ticket.md` (section 3.4); the check that a statement does not give the fix away runs
  # outside the engine.
  defp validate_statement!(id, present?) do
    case {present?.("ticket.md"), present?.("statement.json")} do
      {false, false} ->
        :ok

      {true, true} ->
        record = Inventory.read_json(Inventory.case_path(id, "statement.json"))

        writer = if is_map(record), do: record["writer"]

        unless is_map(record) and
                 ((is_binary(writer) and String.trim(writer) != "") or
                    (is_map(writer) and map_size(writer) > 0)) and is_binary(record["written"]) and
                 record["ticket_sha256"] ==
                   Inventory.hash_file(Inventory.case_path(id, "ticket.md")),
               do: raise("statement.json must name its writer and match ticket.md")

      _ ->
        raise "ticket.md and statement.json come together"
    end
  end

  defp stage(ref, status, emit) do
    Store.write("#{prefix(ref)}/job.json", %{"status" => status})
    emit.("Candidate #{ref["id"]}: #{status}")
  end

  defp prefix(%{"id" => id, "version" => version}) do
    unless Store.valid_id?(id) and is_binary(version) and
             Regex.match?(~r/^[a-f0-9]{64}$/, version),
           do: raise("Invalid candidate reference")

    "candidates/#{id}/#{version}"
  end
end
