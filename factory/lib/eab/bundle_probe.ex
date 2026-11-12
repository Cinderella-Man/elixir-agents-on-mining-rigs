defmodule Eab.BundleProbe do
  @moduledoc """
  The two steps of the bundle maker that need a prepared project (factory/README.md, section 3.5):

  - observing the test names: the hidden tests are run on the unchanged project and on the reference, and the
    manifest's `required` (the hidden tests that pass on the reference) and `starting_failures` (those that fail in
    their body on the unchanged project) are written from what the runs show;
  - settling the existing tests: the existing test files the maker named for `grading.preservation` run in their
    starting-commit version, twice on the unchanged project and twice on the reference; a file with a test that
    fails or ends differently in two runs is left out and recorded in `grading.preservation_left_out`;
  - the search for a partial fix: the reference with one file, then one hunk, left out, in order; the first variant
    whose hidden run finishes and fails a starting failure in its body becomes `incomplete.patch`, or the reason none
    was found is recorded.

  The first and the last run only the hidden tests (`grading.acceptance`), as the grader's hidden step does; the
  second runs the existing tests, as its regression step does; all in fresh containers of the task's prepared
  runtime.
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

      with {:ok, names} <- observe(reference, run),
           _ = emit.("Settling the existing tests of #{id}"),
           {:ok, kept, left_out} <- settle_task(id, run_id, reference) do
        emit.("Searching a partial fix for #{id}")
        partial = search(reference, names["starting_failures"], run)
        existing = %{"preservation" => kept, "preservation_left_out" => left_out}
        write!(dir, names, existing, partial)

        {:ok,
         names
         |> Map.merge(existing)
         |> Map.put("partial_control", partial_control(partial))}
      else
        {:error, reason, detail} -> {:refused, reason, detail}
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
  Settles the existing test files of a task's command (README section 3.5): `files` are the maker's first reading,
  `run.(patch, files)` runs `mix test <files>` in their starting-commit version on the unchanged project (`patch`
  "") or on the reference code, and returns the parsed result. Each side runs twice. A file is left out when one of
  its tests fails on the unchanged project or on the reference, or ends differently in the two runs of the same
  code; its tests are found by the modules it defines (`modules`, file => module names). When a run of all the files
  does not finish, or a failing test belongs to no file, each file is run alone on that side.

  Returns `{:ok, kept, left_out}` with `left_out` a list of `%{"file" => ..., "reason" => ...}` (`unstable`,
  `fails_on_unchanged`, `fails_on_reference`, `skipped_on_unchanged`, `skipped_on_reference` (a skipped test, which
  the grader does not pass), `does_not_finish_on_unchanged`, `does_not_finish_on_reference`), or
  `{:error, "no_existing_tests", detail}` when no file is left.
  """
  def settle(files, reference, modules, run) do
    owner =
      for {file, names} <- modules, name <- names, into: %{}, do: {"Elixir." <> name, file}

    file_of = fn test -> owner[test |> String.split("::", parts: 2) |> hd()] end

    reasons =
      for {side, patch} <- [{"unchanged", ""}, {"reference", reference}], reduce: %{} do
        acc ->
          verdicts = side_verdicts(files, patch, file_of, run)

          Enum.reduce(verdicts, acc, fn {file, verdict}, acc ->
            if verdict == :ok or Map.has_key?(acc, file),
              do: acc,
              else: Map.put(acc, file, reason(verdict, side))
          end)
      end

    kept = Enum.reject(files, &Map.has_key?(reasons, &1))

    left_out =
      for file <- files,
          Map.has_key?(reasons, file),
          do: %{"file" => file, "reason" => reasons[file]}

    if kept == [],
      do:
        {:error, "no_existing_tests",
         Enum.map_join(left_out, "; ", &"#{&1["file"]}: #{&1["reason"]}")},
      else: {:ok, kept, left_out}
  end

  defp reason(:unstable, _side), do: "unstable"
  defp reason(:skipped, side), do: "skipped_on_" <> side
  defp reason(:fails, side), do: "fails_on_" <> side
  defp reason(:does_not_finish, side), do: "does_not_finish_on_" <> side

  # One side's verdict per file: :ok, :fails, :unstable or :does_not_finish.
  defp side_verdicts(files, patch, file_of, run) do
    runs = [run.(patch, files), run.(patch, files)]

    attributable =
      Enum.all?(runs, &(&1["completed"] == true)) and
        Enum.all?(runs, fn result ->
          Enum.all?(result["test_results"] || %{}, fn {test, state} ->
            good?(state) or file_of.(test) != nil
          end)
        end)

    if attributable do
      Map.new(files, fn file -> {file, verdict(runs, &(file_of.(&1) == file))} end)
    else
      Map.new(files, fn file ->
        alone = [run.(patch, [file]), run.(patch, [file])]

        if Enum.all?(alone, &(&1["completed"] == true)),
          do: {file, verdict(alone, fn _ -> true end)},
          else: {file, :does_not_finish}
      end)
    end
  end

  defp verdict([first, second], mine?) do
    a =
      for {test, state} <- first["test_results"] || %{},
          mine?.(test),
          into: %{},
          do: {test, state}

    b =
      for {test, state} <- second["test_results"] || %{},
          mine?.(test),
          into: %{},
          do: {test, state}

    cond do
      a != b -> :unstable
      Enum.any?(a, fn {_, state} -> not good?(state) end) -> :fails
      # The grader passes a run only when every test passed or was excluded by a permitted tag, so a skipped test
      # fails the existing-tests step even on the reference.
      Enum.any?(a, fn {_, state} -> state == "skipped" end) -> :skipped
      true -> :ok
    end
  end

  defp good?(state), do: state in ~w(passed excluded skipped)

  # The maker's first reading of the existing test files, settled by runs in the task's prepared runtime.
  defp settle_task(id, run_id, reference) do
    contract = Eab.TaskContract.read(Inventory.spec(id))

    files =
      contract["preservation"]
      |> OptionParser.split()
      |> Enum.drop(2)
      |> Enum.filter(&Eab.TaskContract.test_file?(contract, &1))

    if files == [] do
      {:error, "no_existing_tests", "the command names no existing test file"}
    else
      modules = modules(id, run_id, files)

      run = fn patch, selected ->
        try do
          preservation_run(id, run_id, patch, selected)
        rescue
          error ->
            %{"completed" => false, "error" => Exception.message(error), "test_results" => %{}}
        end
      end

      settle(files, reference, modules, run)
    end
  end

  # The modules each file defines at the starting commit, read in a fresh container.
  defp modules(id, run_id, files) do
    Sandbox.with_box(id, run_id, fn box ->
      Map.new(files, fn file ->
        output = Sandbox.command!(box, "cat -- #{Eab.Command.quote(file)}", limit: 4_194_304)

        names =
          Regex.scan(~r/^\s*defmodule\s+([A-Z][A-Za-z0-9_.]*)/m, output, capture: :all_but_first)
          |> List.flatten()

        {file, names}
      end)
    end)
  end

  @doc """
  Runs `mix test <files>` in a fresh container of the prepared runtime, after `patch` (code only), with the test
  files of the starting commit, as the grader's regression step does.
  """
  def preservation_run(id, run_id, patch, files) do
    Sandbox.with_box(id, run_id, fn box ->
      Sandbox.apply_patch(box, patch)
      TestAdapter.install(box)
      Grader.run_tests(box, Enum.join(["mix", "test" | files], " "))
    end)
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

  defp write!(dir, names, existing, partial) do
    path = Path.join(dir, "case.json")
    spec = path |> File.read!() |> Jason.decode!(objects: :ordered_objects)

    control =
      case partial do
        {:present, _} -> Ordered.new([{"present", true}])
        {:absent, reason} -> Ordered.new([{"present", false}, {"reason", reason}])
      end

    left_out =
      Enum.map(
        existing["preservation_left_out"],
        &Ordered.new([{"file", &1["file"]}, {"reason", &1["reason"]}])
      )

    spec =
      spec
      |> put_in(
        ["grading", "preservation"],
        Enum.join(["mix", "test" | existing["preservation"]], " ")
      )
      |> put_in(["grading", "preservation_left_out"], left_out)
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
