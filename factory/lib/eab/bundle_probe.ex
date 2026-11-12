defmodule Eab.BundleProbe do
  @moduledoc """
  The two steps of the bundle maker that need a prepared project (factory/README.md, section 3.5):

  - observing the test names: the hidden tests are run on the unchanged project and on the reference, and the
    manifest's `required` (the hidden tests that pass on the reference) and `starting_failures` (those that fail in
    their body on the unchanged project) are written from what the runs show;
  - the search for a partial fix: the reference with one file, then one hunk, left out, in order; the first variant
    whose hidden run finishes and fails a starting failure in its body becomes `incomplete.patch`, or the reason none
    was found is recorded.

  Both run only the hidden tests (`grading.acceptance`), as the grader's hidden step does, in fresh containers of
  the task's prepared runtime.
  """
  alias Eab.{Grader, Inventory, Sandbox, TestAdapter}
  alias Jason.OrderedObject, as: Ordered

  @doc """
  Observes, searches and writes the result into the task folder `dir`. The task's runtime must be prepared
  (`runtimes/<id>.json`, as for `Eab.Grader.qualify/3`); after the folder changes it is stale, and the gate prepares
  it again. Returns `{:ok, summary}` or `{:refused, reason, detail}`; on a refusal the folder is left as it was.
  """
  def finish(id, dir, run_id, emit \\ fn _ -> :ok end) do
    Inventory.with_case(id, dir, fn ->
      reference = Inventory.file(id, "reference.patch")

      run = fn patch ->
        try do
          hidden_run(id, run_id, patch)
        rescue
          error ->
            %{"completed" => false, "error" => Exception.message(error), "test_results" => %{}}
        end
      end

      emit.("Observing the hidden tests of #{id}")

      case observe(reference, run) do
        {:ok, names} ->
          emit.("Searching a partial fix for #{id}")
          partial = search(reference, names["starting_failures"], run)
          write!(dir, names, partial)
          {:ok, Map.put(names, "partial_control", partial_control(partial))}

        {:error, reason, detail} ->
          {:refused, reason, detail}
      end
    end)
  after
    Sandbox.cleanup(run_id)
  end

  @doc """
  The test names from a run of the hidden tests on the unchanged project and on the reference. `run` takes a patch
  and returns the hidden run's parsed result (`Eab.Grader.parse/2`).
  """
  def observe(reference, run) do
    start = run.("")
    fixed = run.(reference)
    states = fixed["test_results"] || %{}
    required = for {name, "passed"} <- states, do: name
    failing = for {name, state} <- states, state not in ~w(passed excluded skipped), do: name
    starting = Grader.behavioral_failures(start)

    cond do
      start["completed"] != true ->
        {:error, "start_run_did_not_finish",
         "the hidden tests do not finish on the unchanged project"}

      fixed["completed"] != true ->
        {:error, "reference_run_did_not_finish",
         "the hidden tests do not finish on the reference"}

      failing != [] ->
        {:error, "reference_fails_hidden", Enum.join(Enum.sort(failing), "; ")}

      required == [] ->
        {:error, "no_passing_test", "no hidden test passes on the reference"}

      starting == [] ->
        {:error, "no_starting_failure",
         "no hidden test fails in its body on the unchanged project"}

      starting -- required != [] ->
        {:error, "starting_failure_not_required",
         Enum.join(Enum.sort(starting -- required), "; ")}

      true ->
        {:ok, %{"required" => Enum.sort(required), "starting_failures" => Enum.sort(starting)}}
    end
  end

  @doc """
  The first variant of the reference that compiles (its hidden run finishes) and fails a starting failure in a test's
  body: `{:present, patch}`, or `{:absent, reason}` with `single_hunk`, `no_variant_compiles` or `no_variant_fails`.
  """
  def search(reference, starting, run) do
    case variants(reference) do
      [] ->
        {:absent, "single_hunk"}

      variants ->
        Enum.reduce_while(variants, {:absent, "no_variant_compiles"}, fn variant, absent ->
          result = run.(variant)

          cond do
            result["completed"] != true ->
              {:cont, absent}

            Enum.any?(Grader.behavioral_failures(result), &(&1 in starting)) ->
              {:halt, {:present, variant}}

            true ->
              {:cont, {:absent, "no_variant_fails"}}
          end
        end)
    end
  end

  @doc """
  The variants of a reference patch, in the order they are tried: each file left out (when there are two or more),
  then each hunk left out of a file with two or more. Later hunks of that file get their new line numbers moved back.
  """
  def variants(reference) do
    files =
      reference |> String.split(~r/^(?=diff --git )/m) |> Enum.filter(&(&1 =~ ~r/^diff --git /))

    parsed = Enum.map(files, &hunks/1)

    by_file =
      if length(files) > 1,
        do: for(i <- 0..(length(files) - 1), do: files |> List.delete_at(i) |> Enum.join()),
        else: []

    by_hunk =
      for {{head, hunks}, i} <- Enum.with_index(parsed),
          length(hunks) > 1,
          j <- 0..(length(hunks) - 1) do
        files |> List.replace_at(i, head <> drop_hunk(hunks, j)) |> Enum.join()
      end

    (by_file ++ by_hunk) |> Enum.reject(&(&1 == "")) |> Enum.uniq()
  end

  defp hunks(file) do
    [head | hunks] = String.split(file, ~r/^(?=@@ )/m)
    {head, hunks}
  end

  defp drop_hunk(hunks, j) do
    {before, [dropped | later]} = Enum.split(hunks, j)
    shift = delta(dropped)

    later =
      Enum.map(later, fn hunk ->
        Regex.replace(~r/^@@ -(\d+(?:,\d+)?) \+(\d+)/, hunk, fn _, old, new ->
          "@@ -#{old} +#{String.to_integer(new) - shift}"
        end)
      end)

    Enum.join(before ++ later)
  end

  defp delta(hunk) do
    [_, old, new] = Regex.run(~r/^@@ -\d+(?:,(\d+))? \+\d+(?:,(\d+))? @@/, hunk) |> pad()
    count(new) - count(old)
  end

  defp pad([whole]), do: [whole, nil, nil]
  defp pad([whole, old]), do: [whole, old, nil]
  defp pad(list), do: list
  defp count(nil), do: 1
  defp count(""), do: 1
  defp count(n), do: String.to_integer(n)

  @doc """
  Runs only the hidden tests in a fresh container of the prepared runtime, after `patch` (code only), as the
  grader's hidden step does.
  """
  def hidden_run(id, run_id, patch) do
    Sandbox.with_box(id, run_id, fn box ->
      Sandbox.apply_patch(box, patch)
      TestAdapter.install(box)
      Sandbox.apply_patch(box, Inventory.file(id, box.spec["acceptance_patch"]))
      Grader.run_tests(box, Eab.TaskContract.read(box.spec)["acceptance"])
    end)
  end

  defp partial_control({:present, _}), do: %{"present" => true}
  defp partial_control({:absent, reason}), do: %{"present" => false, "reason" => reason}

  defp write!(dir, names, partial) do
    path = Path.join(dir, "case.json")
    spec = path |> File.read!() |> Jason.decode!(objects: :ordered_objects)

    control =
      case partial do
        {:present, _} -> Ordered.new([{"present", true}])
        {:absent, reason} -> Ordered.new([{"present", false}, {"reason", reason}])
      end

    spec =
      spec
      |> put_in(["grading", "required"], names["required"])
      |> put_in(["grading", "starting_failures"], names["starting_failures"])
      |> put_in(["partial_control"], control)

    File.write!(path, Jason.encode!(spec, pretty: true) <> "\n")

    case partial do
      {:present, patch} -> File.write!(Path.join(dir, "incomplete.patch"), patch)
      {:absent, _} -> File.rm(Path.join(dir, "incomplete.patch"))
    end

    :ok
  end
end
