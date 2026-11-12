defmodule Eab.CandidatesTest do
  use ExUnit.Case, async: false
  alias Eab.{Candidates, Inventory, Store}

  setup do
    old = Store.root()
    root = Path.join(System.tmp_dir!(), "eab-candidate-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, root)
    File.mkdir_p!(root)

    on_exit(fn ->
      Application.put_env(:eab, :data_dir, old)
      File.rm_rf!(root)
    end)

    %{
      directory: bundle(root, "draft", "ledgerette-pr-1"),
      without_partial: bundle(root, "draft-single", "ledgerette-pr-2"),
      root: root
    }
  end

  # A copy of a made-up task under another id, with a statement and its record.
  defp bundle(root, name, task) do
    directory = Path.join(root, name)
    File.cp_r!(Eab.MadeUpTasks.dir(task), directory)
    spec = Inventory.read_json(Path.join(directory, "case.json"))

    File.write!(
      Path.join(directory, "case.json"),
      Jason.encode!(Map.put(spec, "id", "synthetic-#{name}"))
    )

    state(directory, "Synthetic statement, never used.")
    directory
  end

  defp state(directory, text) do
    File.write!(Path.join(directory, "ticket.md"), text)

    File.write!(
      Path.join(directory, "statement.json"),
      Jason.encode!(%{
        "writer" => %{"name" => "made-up-writer", "file" => "none", "settings" => %{}},
        "ticket_sha256" => Inventory.hash(text),
        "written" => "2026-11-12"
      })
    )
  end

  test "import stays outside inventory and changed artifacts require another version", %{
    directory: directory
  } do
    ids = Inventory.all()
    ref = Candidates.import(directory)
    assert Candidates.read!(ref)["id"] == "synthetic-draft"
    assert Inventory.all() == ids
    assert_raise ArgumentError, fn -> Inventory.spec("synthetic-draft") end
    state(directory, "Changed statement")
    next = Candidates.import(directory)
    refute next == ref

    assert Candidates.read!(ref)["files"]["ticket.md"] !=
             Candidates.read!(next)["files"]["ticket.md"]
  end

  test "the import check takes tasks with and without a partial fix, and only in the one format",
       %{
         directory: directory,
         without_partial: without_partial,
         root: root
       } do
    assert Candidates.import(without_partial)["id"] == "synthetic-draft-single"

    # Every made-up task passes the import check as it is.
    for id <- Eab.MadeUpTasks.ids(),
        do: assert(Candidates.import(Eab.MadeUpTasks.dir(id))["id"] == id)

    # A task may pass the gate before it has a statement.
    unstated = Path.join(root, "unstated")
    File.cp_r!(directory, unstated)
    File.rm!(Path.join(unstated, "ticket.md"))
    File.rm!(Path.join(unstated, "statement.json"))
    assert Candidates.import(unstated)["id"] == "synthetic-draft"

    spec = Inventory.read_json(Path.join(directory, "case.json"))

    refusals = [
      {"admission.json", fn dir -> File.write!(Path.join(dir, "admission.json"), "{}") end},
      {"upstream-tests.patch",
       fn dir ->
         File.cp!(Path.join(dir, "reference-tests.patch"), Path.join(dir, "upstream-tests.patch"))
       end},
      {"version 2",
       fn dir ->
         File.write!(
           Path.join(dir, "case.json"),
           Jason.encode!(Map.put(spec, "schema_version", 2))
         )
       end},
      {"removed field",
       fn dir ->
         File.write!(Path.join(dir, "case.json"), Jason.encode!(Map.put(spec, "family", "x")))
       end},
      {"not mix",
       fn dir ->
         File.write!(
           Path.join(dir, "case.json"),
           Jason.encode!(put_in(spec, ["runtime", "profile"], "plausible_ce"))
         )
       end},
      {"partial recorded, file missing",
       fn dir -> File.rm!(Path.join(dir, "incomplete.patch")) end},
      {"partial absent, file present",
       fn dir ->
         File.write!(
           Path.join(dir, "case.json"),
           Jason.encode!(
             Map.put(spec, "partial_control", %{
               "present" => false,
               "reason" => "no_variant_fails"
             })
           )
         )
       end},
      {"statement without its record", fn dir -> File.rm!(Path.join(dir, "statement.json")) end},
      {"statement changed after its record",
       fn dir -> File.write!(Path.join(dir, "ticket.md"), "Edited after the record") end},
      {"no early exit",
       fn dir ->
         File.write!(
           Path.join(dir, "integrity.patch"),
           File.read!(Path.join(dir, "incomplete.patch"))
         )
       end},
      {"reference outside the allowed folders",
       fn dir ->
         File.write!(
           Path.join(dir, "reference.patch"),
           "diff --git a/mix.exs b/mix.exs\n--- a/mix.exs\n+++ b/mix.exs\n"
         )
       end},
      {"hidden tests outside the test folders",
       fn dir ->
         File.write!(
           Path.join(dir, "reference-tests.patch"),
           File.read!(Path.join(dir, "reference.patch"))
         )
       end}
    ]

    for {name, change} <- refusals do
      copy = Path.join(root, "refused-#{System.unique_integer([:positive])}")
      File.cp_r!(directory, copy)
      change.(copy)

      outcome =
        try do
          Candidates.import(copy) && :imported
        rescue
          RuntimeError -> :refused
        end

      assert {name, outcome} == {name, :refused}
    end
  end

  test "candidate context is restored on exceptions", %{directory: directory} do
    assert_raise RuntimeError, fn ->
      Inventory.with_case("synthetic-candidate", directory, fn -> raise "cancelled" end)
    end

    assert_raise ArgumentError, fn -> Inventory.spec("synthetic-candidate") end
  end
end
