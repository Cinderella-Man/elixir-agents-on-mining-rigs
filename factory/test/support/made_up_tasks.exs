defmodule Eab.MadeUpTasks do
  @moduledoc """
  Made-up tasks in the one format (factory/README.md, section 3), in place of the bench's cases, which are never
  copied here. The projects are invented for these tests, and so are their repositories, commits and pull requests:

  - `ledgerette`, a tiny ledger with no dependencies and no database. Its source is written by `write_source!/1`,
    so that the factory's own `mix test` never loads its test files. Its two tasks apply to that source, and the
    Docker test grades them:
    - `ledgerette-pr-1`, a bug fix in two files, with a partial fix (the reference without the second file);
    - `ledgerette-pr-2`, a feature in one hunk, without a partial fix (`single_hunk`).
  - `shelfwise-pr-7`, a bug fix in a made-up stock-keeping application with Postgres and a Node build step. Its
    source is not here; the tests that use it prepare nothing for real.

  The bundles are in `test/support/tasks/<id>/`. Tests reach them in one process through `use!/1`, or as the whole
  inventory, a task folder, through `mount!/1`.
  """

  @root Path.expand("tasks", __DIR__)

  def root, do: @root
  def dir(id), do: Path.join(@root, id)

  def ids do
    Path.join(@root, "*/case.json")
    |> Path.wildcard()
    |> Enum.map(&(&1 |> Path.dirname() |> Path.basename()))
  end

  @doc """
  Makes a task resolvable by `Eab.Inventory` in the calling process, as `Eab.Inventory.with_case/3` does for the
  length of a function. Meant for an ExUnit `setup` block, which runs in the test's own process.
  """
  def use!(id), do: Process.put({Eab.Inventory, id}, dir(id))

  @doc """
  Makes the made-up tasks the inventory, as a mounted task folder is (`EAB_TASKS_DIR`), for the calling test, and
  puts the setting back when the test ends. With a directory, the tasks are copied into it first, so that the test
  may change them; without one, the inventory reads `test/support/tasks/` itself, for tests that only read. Returns
  the task ids, in order.
  """
  def mount!(directory \\ nil) do
    folder =
      if directory do
        File.mkdir_p!(directory)
        for id <- ids(), do: File.cp_r!(dir(id), Path.join(directory, id))
        directory
      else
        @root
      end

    previous = Application.fetch_env(:eab, :tasks_dir)
    Application.put_env(:eab, :tasks_dir, folder)

    ExUnit.Callbacks.on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:eab, :tasks_dir, value)
        :error -> Application.delete_env(:eab, :tasks_dir)
      end
    end)

    Eab.Inventory.all()
  end

  @doc "Adds a copy of the made-up task `from` to a mounted task folder, under the id `id`."
  def copy!(id, from) do
    target = Path.join(Eab.Inventory.tasks_dir(), id)
    File.cp_r!(dir(from), target)
    manifest = Path.join(target, "case.json")
    spec = manifest |> File.read!() |> Jason.decode!() |> Map.put("id", id)
    File.write!(manifest, Jason.encode!(spec))
    id
  end

  @doc "Writes the starting source of `ledgerette` into `dir`."
  def write_source!(dir) do
    for {file, contents} <- ledgerette() do
      path = Path.join(dir, file)
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, contents)
    end

    dir
  end

  defp ledgerette do
    [
      {".gitignore", "/_build/\n/deps/\n"},
      {"mix.exs",
       """
       defmodule Ledgerette.MixProject do
         use Mix.Project

         def project do
           [app: :ledgerette, version: "0.1.0", deps: []]
         end
       end
       """},
      {"lib/ledgerette.ex",
       """
       defmodule Ledgerette do
         @moduledoc "A made-up ledger for the factory's tests."

         def balance(entries) do
           Enum.reduce(entries, 0, fn
             {:credit, amount}, total -> total + amount
             {:debit, amount}, total -> total + amount
           end)
         end
       end
       """},
      {"lib/ledgerette/format.ex",
       """
       defmodule Ledgerette.Format do
         def amount(cents) do
           "\#{div(cents, 100)}.\#{cents |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")}"
         end
       end
       """},
      {"test/test_helper.exs", "ExUnit.start()\n"},
      {"test/ledgerette_test.exs",
       """
       defmodule LedgeretteTest do
         use ExUnit.Case

         test "credits raise the balance" do
           assert Ledgerette.balance([{:credit, 5}, {:credit, 7}]) == 12
         end

         test "amounts print with two decimals" do
           assert Ledgerette.Format.amount(1205) == "12.05"
         end
       end
       """}
    ]
  end
end
