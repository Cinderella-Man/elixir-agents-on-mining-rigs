defmodule Eab.Factory do
  @moduledoc """
  The entry points a script calls (factory/README.md, section 6, change 5), through the release's `rpc` command;
  `bin/factoryctl` wraps them. Each takes and returns plain data (strings, lists, maps), so `cli/1` can print it as
  JSON.

  - `import/2`: checks every task folder under a folder and copies the valid ones into the task folder.
  - `check/2`: for each task, the gate of section 4 as one sequence, in a background job: prepare, the probe, prepare
    again, the controls with their second round. One result per task, written to a file as it finishes.
  - `export/2`: copies checked tasks and a table of their results.
  - `start_run/4`: starts a teacher run on tasks that have a statement.
  - `kept_sessions/1`: the attempts of a run that completed and passed, with their folders.
  - `status/0` and `job/1`: what is running, and one job's progress.

  Files, under the data folder: `factory/jobs/<job>/job.json` (the job and, at its end, its counts),
  `factory/jobs/<job>/progress.log` (one line per step), `factory/jobs/<job>/results/<id>.json` and
  `factory/jobs/<job>/results.tsv` (one result per task, as it finishes), `factory/jobs/<job>/work/<id>/` (the probed
  copy of a task that was dropped), `factory/tasks/<id>.json` (the latest check of each task) and
  `factory/imports/<stamp>.json` (one import's results).
  """
  alias Eab.{
    BundleMaker,
    BundleProbe,
    Candidates,
    Checkpoints,
    Fixtures,
    Grader,
    Inventory,
    Model,
    Provenance,
    Retention,
    Runs,
    Sandbox,
    Store,
    TaskContract
  }

  @jobs "factory_jobs"
  @columns ~w(id verdict dropped_at reason hidden_failing_first hidden_passing_after partial partial_reason
    preservation_files left_out second_round_changed total_ms)

  ## import

  @doc """
  Checks every folder under `dir` as a task and copies the valid ones into the task folder (`EAB_TASKS_DIR`).
  A folder is refused when it is not named by its task's id (`folder_not_named_by_id`), when its repository or project
  is on the hold-out list (`holdout`, `config/holdout.json` or `opts[:holdout]`), when it fails the import check
  (`import_check`, `Eab.Candidates.files!/1` and `validate!/1`), or when a task of the same id is already there with
  other bytes (`exists_with_other_bytes`). A task already there with the same bytes is `unchanged`. Returns
  `{:ok, results}`, one map per folder, in the order of the folder names.
  """
  def import(dir, opts \\ []) do
    holdout = opts[:holdout] || Inventory.path("config/holdout.json")
    dir = Path.expand(dir)

    results =
      dir
      |> File.ls!()
      |> Enum.sort()
      |> Enum.reject(&String.starts_with?(&1, "."))
      |> Enum.filter(&File.dir?(Path.join(dir, &1)))
      |> Enum.map(&import_one(Path.join(dir, &1), holdout))

    Store.write("factory/imports/#{stamp()}.json", %{
      "source" => dir,
      "at" => now(),
      "results" => results
    })

    {:ok, results}
  end

  defp import_one(folder, holdout) do
    name = Path.basename(folder)

    try do
      files = Candidates.files!(folder)
      spec = Inventory.read_json(Path.join(folder, "case.json"))
      id = spec["id"]

      unless Store.valid_id?(id) and id == name,
        do:
          throw(
            {:refused, "folder_not_named_by_id",
             "the folder #{name} holds the task #{inspect(id)}"}
          )

      holdout!(spec, holdout)
      Inventory.with_case(id, folder, fn -> Candidates.validate!(id) end)
      hashes = Map.new(files, &{&1, Inventory.hash_file(Path.join(folder, &1))})
      target = Path.join(Inventory.tasks_dir(), id)

      cond do
        not File.exists?(target) ->
          copy_in!(folder, hashes, target)
          %{"folder" => name, "id" => id, "result" => "imported"}

        folder_hashes(target) == hashes ->
          %{"folder" => name, "id" => id, "result" => "unchanged"}

        true ->
          throw(
            {:refused, "exists_with_other_bytes",
             "the task folder already holds #{id} with other bytes"}
          )
      end
    rescue
      error ->
        %{
          "folder" => name,
          "result" => "refused",
          "reason" => "import_check",
          "detail" => Exception.message(error)
        }
    catch
      {:refused, reason, detail} ->
        %{"folder" => name, "result" => "refused", "reason" => reason, "detail" => detail}
    end
  end

  defp holdout!(spec, path) do
    url = String.replace_suffix(get_in(spec, ["repository", "url"]) || "", ".git", "")

    case Regex.run(~r{^https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/?$}, url) do
      [_, owner, name] ->
        for candidate <- Enum.uniq([name, spec["project"]]), is_binary(candidate) do
          try do
            BundleMaker.holdout!(owner, candidate, path)
          rescue
            error in BundleMaker.Refusal -> throw({:refused, "holdout", error.detail})
          end
        end

        :ok

      _ ->
        throw(
          {:refused, "import_check", "the repository is not a GitHub address: #{inspect(url)}"}
        )
    end
  end

  # The copy goes to a hidden folder beside the target and is renamed into place, so a task folder is never seen
  # half written (`Eab.Inventory.all/0` does not list hidden folders).
  defp copy_in!(folder, hashes, target) do
    temp = Path.join(Path.dirname(target), ".import-#{Path.basename(target)}-#{unique()}")
    File.mkdir_p!(temp)

    try do
      for {file, hash} <- hashes do
        File.cp!(Path.join(folder, file), Path.join(temp, file))

        unless Inventory.hash_file(Path.join(temp, file)) == hash,
          do: raise("Task changed during import: #{file}")
      end

      File.rename!(temp, target)
    after
      File.rm_rf(temp)
    end
  end

  defp folder_hashes(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        for file <- files, File.regular?(Path.join(dir, file)), into: %{} do
          {file, Inventory.hash_file(Path.join(dir, file))}
        end

      _ ->
        nil
    end
  end

  ## check

  @doc """
  Checks the tasks `ids` of the task folder in a background job and returns `{:ok, job}` at once. For each task, as
  `docs/data/2026-11-12_pilot_tasks_ex338_r2/run/gate.exs` did on real tasks: the import check, the source check and
  the preparation; the probe (`Eab.BundleProbe.finish/4`: the test names, the existing tests, the partial fix); the
  import check and the preparation again; the controls of `Eab.Grader.qualify/3` with their second round. The work is
  done on a copy; a task that passes replaces its folder with the probed copy, a task that fails leaves it as it was.

  Options: `concurrency` (tasks at once, 1 to 8, default 2); `steps`, a map that replaces the steps `:source`,
  `:prepare`, `:probe` or `:controls` (each `fn id, dir, run_id, emit`) or `:cleanup` (`fn run_id`), for the tests.

  Refuses (`{:error, message}`) an empty or repeated list, a task the folder does not hold, and a task that the
  active run or another running job holds.
  """
  def check(ids, opts \\ []) do
    concurrency = opts[:concurrency] || 2

    with :ok <- ids!(ids),
         :ok <-
           if(concurrency in 1..8,
             do: :ok,
             else: {:error, "Concurrency is a whole number from 1 to 8"}
           ) do
      Eab.Cache.locked({__MODULE__, :jobs}, fn ->
        with :ok <- free!(ids) do
          job = "check-" <> stamp()

          record = %{
            "id" => job,
            "kind" => "check",
            "ids" => ids,
            "status" => "running",
            "started_at" => now()
          }

          Store.write("factory/jobs/#{job}/job.json", record)

          start_job(record, fn emit ->
            run_check(job, ids, concurrency, steps(opts[:steps]), emit)
          end)
        end
      end)
    end
  end

  defp ids!(ids) do
    cond do
      not is_list(ids) or ids == [] or ids != Enum.uniq(ids) ->
        {:error, "Give a list of distinct task ids"}

      (unknown = Enum.reject(ids, &Inventory.member?/1)) != [] ->
        {:error, "Unknown tasks: " <> Enum.join(unknown, ", ")}

      true ->
        :ok
    end
  end

  defp free!(ids) do
    active = Runs.snapshot().active
    in_run = if active, do: Enum.filter(ids, &(&1 in (active["cases"] || []))), else: []

    in_jobs =
      for {_, job} <- Registry.lookup(Eab.PubSub, @jobs), id <- job["ids"], id in ids, do: id

    cond do
      in_run != [] -> {:error, "The active run holds: " <> Enum.join(in_run, ", ")}
      in_jobs != [] -> {:error, "A running job holds: " <> Enum.join(Enum.uniq(in_jobs), ", ")}
      true -> :ok
    end
  end

  # The job registers itself before the call returns, so that `status/0` sees it at once.
  defp start_job(record, work) do
    parent = self()
    ref = make_ref()

    {:ok, _} =
      Task.Supervisor.start_child(Eab.Tasks, fn ->
        {:ok, _} = Registry.register(Eab.PubSub, @jobs, record)
        send(parent, {ref, :registered})
        log = Store.path("factory/jobs/#{record["id"]}/progress.log")

        emit = fn message ->
          File.write!(log, "#{now()} #{message}\n", [:append])
        end

        final =
          try do
            Map.merge(record, work.(emit))
          rescue
            error ->
              emit.("ERROR " <> Exception.message(error))
              Map.merge(record, %{"status" => "error", "error" => Exception.message(error)})
          end

        Store.write("factory/jobs/#{record["id"]}/job.json", Map.put(final, "finished_at", now()))
      end)

    receive do
      {^ref, :registered} -> {:ok, record["id"]}
    after
      10_000 -> {:error, "The job did not start"}
    end
  end

  defp steps(overrides) do
    Map.merge(
      %{
        source: &source/4,
        prepare: &prepare/4,
        probe: &BundleProbe.finish/4,
        controls: &controls/4,
        cleanup: &Sandbox.cleanup/1
      },
      Map.new(overrides || [])
    )
  end

  @doc "The source check (README section 4, check 2) of the task in `dir`."
  def source(id, dir, _run_id, emit),
    do: Inventory.with_case(id, dir, fn -> Provenance.verify(id, emit) end)

  @doc "The preparation (check 3) of the task in `dir`: the workspace image and the database."
  def prepare(id, dir, run_id, emit),
    do: Inventory.with_case(id, dir, fn -> Fixtures.ensure(id, emit, run_id: run_id) end)

  @doc """
  The controls (checks 4 to 9) of the task in `dir`: `{:ok, control}`, or `{:error, control, message}` with the saved
  control evidence (nil when the controls did not get as far as saving it).
  """
  def controls(id, dir, run_id, emit) do
    File.rm(Store.path("controls/#{id}.json"))
    Inventory.with_case(id, dir, fn -> {:ok, Grader.qualify(id, run_id, emit)} end)
  rescue
    error -> {:error, Store.read("controls/#{id}.json"), Exception.message(error)}
  end

  defp run_check(job, ids, concurrency, steps, emit) do
    Retention.lease(job)
    emit.("Checking #{length(ids)} tasks, #{concurrency} at once")
    tsv = Store.path("factory/jobs/#{job}/results.tsv")
    File.write!(tsv, Enum.join(@columns, "\t") <> "\n")

    try do
      results =
        ids
        |> Enum.with_index(1)
        |> Task.async_stream(
          fn {id, n} -> check_one(job, id, "#{job}-#{n}", steps, emit, tsv) end,
          max_concurrency: concurrency,
          timeout: :infinity,
          ordered: true
        )
        |> Enum.map(fn {:ok, result} -> result end)

      counts = results |> Enum.map(& &1["verdict"]) |> Enum.frequencies()
      emit.("Done: " <> Enum.map_join(Enum.sort(counts), ", ", fn {k, v} -> "#{v} #{k}" end))
      %{"status" => "done", "counts" => counts}
    after
      Retention.release(job)
    end
  end

  defp check_one(job, id, run_id, steps, emit, tsv) do
    t0 = System.monotonic_time(:millisecond)
    emit = fn message -> emit.("#{id}: #{message}") end
    work = Store.path("factory/jobs/#{job}/work/#{id}")
    base = %{"id" => id, "job" => job, "started_at" => now()}

    result =
      try do
        File.rm_rf!(work)
        File.mkdir_p!(Path.dirname(work))
        File.cp_r!(Path.join(Inventory.tasks_dir(), id), work)
        sequence(id, work, run_id, steps, emit, base)
      rescue
        error ->
          Map.merge(base, %{
            "verdict" => "error",
            "reason" => "error",
            "detail" => Exception.message(error)
          })
      catch
        kind, value ->
          Map.merge(base, %{
            "verdict" => "error",
            "reason" => "error",
            "detail" => "#{kind}: #{inspect(value)}"
          })
      after
        try do
          steps.cleanup.(run_id)
        rescue
          error -> emit.("cleanup failed: " <> Exception.message(error))
        end
      end

    result =
      result
      |> Map.merge(%{
        "total_ms" => System.monotonic_time(:millisecond) - t0,
        "finished_at" => now()
      })
      |> Map.merge(manifest_counts(work))

    Store.write("factory/jobs/#{job}/results/#{id}.json", result)
    Store.write("factory/tasks/#{id}.json", result)
    File.write!(tsv, row(result) <> "\n", [:append])
    # A dropped task's probed copy stays in the job's folder as evidence.
    if result["verdict"] == "checked", do: File.rm_rf(work)
    emit.("#{result["verdict"]} #{result["dropped_at"]} #{result["reason"]}" |> String.trim())
    result
  end

  # The gate as one sequence; the first check that fails ends it, with the step (`dropped_at`) and the reason.
  defp sequence(id, work, run_id, steps, emit, row) do
    with {:ok, row} <- step(row, "import_check", fn -> validate(id, work) end),
         {:ok, row} <- step(row, "source", fn -> steps.source.(id, work, run_id, emit) end),
         {:ok, row} <- step(row, "prepare", fn -> steps.prepare.(id, work, run_id, emit) end),
         {:ok, row} <- probe(row, fn -> steps.probe.(id, work, run_id, emit) end),
         {:ok, row} <- step(row, "import_check_after_probe", fn -> validate(id, work) end),
         {:ok, row} <-
           step(row, "source_after_probe", fn -> steps.source.(id, work, run_id, emit) end),
         {:ok, row} <-
           step(row, "prepare_after_probe", fn -> steps.prepare.(id, work, run_id, emit) end) do
      t = System.monotonic_time(:millisecond)
      control = steps.controls.(id, work, run_id, emit)
      row = Map.put(row, "controls_ms", System.monotonic_time(:millisecond) - t)
      verdict(id, work, row, control)
    end
  end

  defp validate(id, work), do: Inventory.with_case(id, work, fn -> Candidates.validate!(id) end)

  defp step(row, name, fun) do
    t = System.monotonic_time(:millisecond)

    try do
      fun.()
      {:ok, Map.put(row, "#{name}_ms", System.monotonic_time(:millisecond) - t)}
    rescue
      error ->
        reason = if name in ~w(prepare prepare_after_probe), do: "environment", else: name

        Map.merge(row, %{
          "#{name}_ms" => System.monotonic_time(:millisecond) - t,
          "verdict" => "dropped",
          "dropped_at" => name,
          "reason" => reason,
          "detail" => error |> Exception.message() |> detail()
        })
    end
  end

  defp probe(row, fun) do
    t = System.monotonic_time(:millisecond)
    answer = fun.()
    row = Map.put(row, "probe_ms", System.monotonic_time(:millisecond) - t)

    case answer do
      {:ok, _summary} ->
        {:ok, Map.put(row, "probe", "ok")}

      {:refused, reason, detail} ->
        Map.merge(row, %{
          "verdict" => "dropped",
          "dropped_at" => "probe",
          "reason" => to_string(reason),
          "detail" => detail(detail)
        })
    end
  end

  # The detail of a failure: its head and its tail when it is long. A failed build or command says why at the end of
  # its output: a toolchain build's log of 54 kB ended with builds.hex.pm's certificate refused, which a cut after the
  # first 2,000 characters left out.
  defp detail(message) do
    text = to_string(message)
    size = String.length(text)

    if size <= 2000,
      do: text,
      else: String.slice(text, 0, 300) <> "\n[...]\n" <> String.slice(text, size - 1700, 1700)
  end

  defp verdict(id, work, row, {:ok, control}) do
    install!(id, work)

    Map.merge(row, %{
      "verdict" => "checked",
      "second_round" => control["second_round"],
      "files" => folder_hashes(Path.join(Inventory.tasks_dir(), id))
    })
  end

  defp verdict(_id, _work, row, {:error, nil, message}),
    do:
      Map.merge(row, %{
        "verdict" => "dropped",
        "dropped_at" => "controls",
        "reason" => "error",
        "detail" => detail(message)
      })

  defp verdict(id, work, row, {:error, control, message}) do
    second = control["second_round"]
    row = Map.merge(row, %{"second_round" => second, "detail" => detail(message)})

    if is_map(second) and second["same"] != true do
      Map.merge(row, %{
        "verdict" => "dropped",
        "dropped_at" => "second_round",
        "reason" => "unstable"
      })
    else
      contract = Inventory.with_case(id, work, fn -> TaskContract.read(Inventory.spec(id)) end)

      Map.merge(row, %{
        "verdict" => "dropped",
        "dropped_at" => "controls",
        "reason" => first_failure(contract, control)
      })
    end
  end

  @doc """
  Which check of README section 4 a failed first round of controls fails first: 4 and 5 the unchanged project, 6 the
  reference, 7 the early exit, 8 the partial fix; `grader_identity` when the controls hold but the grading code
  changed while they ran. A reference whose first failing step fails only because the project marks a test as
  skipped is `skipped_test`, not a failure of the reference: the grader passes no skipped test (section 2.2).
  """
  def first_failure(contract, control) do
    empty = control["empty_patch"] || %{}
    gold = control["reference_patch"] || %{}
    bypass = control["early_exit"] || %{}
    failures = Grader.behavioral_failures(empty["hidden"] || %{})

    cond do
      get_in(empty, ["hidden", "completed"]) != true ->
        "unchanged_project_did_not_finish"

      empty["passed"] ->
        "unchanged_project_passes"

      failures == [] ->
        "unchanged_project_no_body_failure"

      Enum.sort(failures) != Enum.sort(contract["starting_failures"]) ->
        "starting_failures_differ"

      gold["passed"] != true ->
        reference_reason(gold)

      bypass["passed"] == true ->
        "early_exit_accepted"

      not is_boolean(get_in(bypass, ["hidden", "completed"])) ->
        "early_exit_not_run"

      not Grader.valid_controls?(contract, empty, gold, bypass, control["partial_repair"]) ->
        "partial_fix_accepted"

      true ->
        "grader_identity"
    end
  end

  defp reference_reason(gold) do
    {part, step} = reference_part(gold)
    if skipped_only?(gold[step]), do: "skipped_test", else: "reference_" <> part
  end

  defp reference_part(gold) do
    cond do
      get_in(gold, ["submission", "passed"]) != true -> {"existing_tests_fail", "submission"}
      get_in(gold, ["hidden", "passed"]) != true -> {"hidden_tests_fail", "hidden"}
      get_in(gold, ["regression", "passed"]) != true -> {"regression_fails", "regression"}
      get_in(gold, ["regression_coverage", "passed"]) != true -> {"no_test_fails_first", nil}
      true -> {gold["reason"] || "fails", nil}
    end
  end

  # A run that finished and exited 0 with a skipped test and no failed one: a skipped test alone fails it.
  defp skipped_only?(%{"completed" => true, "returncode" => 0} = run) do
    states = Map.values(run["test_results"] || %{})
    "skipped" in states and Enum.all?(states, &(&1 in ~w(passed skipped excluded)))
  end

  defp skipped_only?(_), do: false

  # A checked task's folder becomes the probed copy: written beside it, then swapped in by two renames.
  defp install!(id, work) do
    target = Path.join(Inventory.tasks_dir(), id)

    unless folder_hashes(target) == folder_hashes(work) do
      n = unique()
      fresh = Path.join(Path.dirname(target), ".check-#{id}-#{n}")
      old = Path.join(Path.dirname(target), ".old-#{id}-#{n}")
      File.cp_r!(work, fresh)
      File.rename!(target, old)
      File.rename!(fresh, target)
      File.rm_rf!(old)
    end

    :ok
  end

  # What the task's manifest says after the probe: the counts of hidden tests that fail first and pass after, the
  # partial fix, and the existing test files kept and left out.
  defp manifest_counts(work) do
    spec = Inventory.read_json(Path.join(work, "case.json"))
    grading = spec["grading"] || %{}
    preservation = grading["preservation"] || ""

    %{
      "hidden_failing_first" => length(grading["starting_failures"] || []),
      "hidden_passing_after" => length(grading["required"] || []),
      "partial_control" => spec["partial_control"],
      "preservation" => preservation,
      "preservation_files" => preservation |> OptionParser.split() |> Enum.drop(2) |> length(),
      "preservation_left_out" => grading["preservation_left_out"] || []
    }
  rescue
    _ -> %{}
  end

  defp row(result) do
    partial = result["partial_control"] || %{}

    values = %{
      "partial" => partial["present"],
      "partial_reason" => partial["reason"],
      "left_out" => length(result["preservation_left_out"] || []),
      "second_round_changed" => length(get_in(result, ["second_round", "changed"]) || [])
    }

    Enum.map_join(@columns, "\t", fn column ->
      value = Map.get(values, column, result[column])
      if is_nil(value), do: "", else: value |> to_string() |> String.replace(~r/[\t\n]/, " ")
    end)
  end

  ## export

  @doc """
  Copies the checked tasks `ids` to `dest/<id>/` and writes `dest/results.tsv`, one row per task folder in `dest`
  that has a check result. A task is refused when it has no passing check (`not_checked`), when its folder changed
  since that check (`changed_since_check`; a statement added later does not count), or when `dest` already holds it
  with other bytes (`exists_with_other_bytes`). Returns `{:ok, %{"exported" => ids, "refused" => [...]}}`.
  """
  def export(ids, dest) do
    with :ok <- ids!(ids) do
      dest = Path.expand(dest)
      File.mkdir_p!(dest)

      {exported, refused} =
        Enum.reduce(ids, {[], []}, fn id, {done, refused} ->
          case export_one(id, dest) do
            :ok -> {[id | done], refused}
            {:refused, reason} -> {done, [%{"id" => id, "reason" => reason} | refused]}
          end
        end)

      rows =
        for file <- dest |> Path.join("*/case.json") |> Path.wildcard() |> Enum.sort(),
            id = file |> Path.dirname() |> Path.basename(),
            result = Store.read("factory/tasks/#{id}.json"),
            do: row(result)

      File.write!(
        Path.join(dest, "results.tsv"),
        Enum.join([Enum.join(@columns, "\t") | rows], "\n") <> "\n"
      )

      {:ok, %{"exported" => Enum.reverse(exported), "refused" => Enum.reverse(refused)}}
    end
  end

  defp export_one(id, dest) do
    source = Path.join(Inventory.tasks_dir(), id)
    target = Path.join(dest, id)
    result = Store.read("factory/tasks/#{id}.json")
    hashes = folder_hashes(source)
    statement = ~w(ticket.md statement.json)

    cond do
      result["verdict"] != "checked" ->
        {:refused, "not_checked"}

      Map.drop(hashes, statement) != Map.drop(result["files"] || %{}, statement) ->
        {:refused, "changed_since_check"}

      File.exists?(target) and folder_hashes(target) == hashes ->
        :ok

      File.exists?(target) ->
        {:refused, "exists_with_other_bytes"}

      true ->
        copy_in!(source, hashes, target)
        :ok
    end
  end

  ## teacher runs

  @doc """
  Starts a teacher run of the model server at `url` on the tasks `ids`, with the run `settings` of
  `Eab.Model.settings/2`; returns `{:ok, run}` at once, or `{:error, message}`. Every task must have a statement
  (`ticket.md` with its `statement.json`, README section 3.4) and pass the import check; the run's own preparation
  runs the controls again before the first attempt. Options: `key` (the server's key, default `EAB_MODEL_KEY` or
  none), `parallel_attempts` (1 to 8), `discover` (replaces `Eab.Model.discover/2`, for the tests).
  """
  def start_run(url, ids, settings \\ %{}, opts \\ []) do
    with :ok <- ids!(ids),
         :ok <- statements!(ids) do
      key = opts[:key] || System.get_env("EAB_MODEL_KEY", "")
      discover = opts[:discover] || (&Model.discover/2)
      endpoint = discover.(url, key)

      Runs.start(endpoint, key, settings || %{},
        cases: ids,
        parallel_attempts: opts[:parallel_attempts] || 1
      )
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp statements!(ids) do
    missing =
      Enum.reject(ids, fn id ->
        Enum.all?(~w(ticket.md statement.json), &File.regular?(Inventory.case_path(id, &1)))
      end)

    if missing == [] do
      Enum.each(ids, &Candidates.validate!/1)
      :ok
    else
      {:error, "Tasks without a statement: " <> Enum.join(missing, ", ")}
    end
  end

  @doc """
  The sessions a run keeps (README section 2.2): its attempts that ended as `completed` with a patch that passed.
  Each with its folder under the data folder and the files there. Attempts of a run with sealed receipts are read
  through `Eab.Checkpoints.completed/2`; one whose receipt does not verify is listed under `unverified`, not kept.
  """
  def kept_sessions(run_id) do
    case Store.valid_id?(run_id) && Store.run(run_id) do
      run when is_map(run) ->
        {kept, unverified} =
          Enum.reduce(run["cases"], {[], []}, fn id, {kept, unverified} ->
            case attempt(run, id) do
              {:ok, %{"status" => "completed", "grade" => %{"passed" => true}} = record} ->
                folder = Store.path("runs/#{run_id}/#{id}")

                session = %{
                  "case" => id,
                  "folder" => folder,
                  "files" => folder |> File.ls!() |> Enum.sort(),
                  "generation" => record["generation"] || 1
                }

                {[session | kept], unverified}

              {:error, message} ->
                {kept, [%{"case" => id, "error" => message} | unverified]}

              _ ->
                {kept, unverified}
            end
          end)

        {:ok,
         %{
           "run" => run_id,
           "status" => run["status"],
           "cases" => length(run["cases"]),
           "kept" => Enum.reverse(kept),
           "unverified" => Enum.reverse(unverified)
         }}

      _ ->
        {:error, "Unknown run: #{run_id}"}
    end
  end

  defp attempt(run, id) do
    if run["experiment_id"],
      do: {:ok, Checkpoints.completed(run, id)},
      else: {:ok, Store.read("runs/#{run["id"]}/#{id}/attempt.json")}
  rescue
    error -> {:error, Exception.message(error)}
  end

  ## status

  @doc """
  What is running: the active teacher run (its id, status, phase, task count and current task), a preparation, and
  the running jobs of this module with the count of tasks finished.
  """
  def status do
    snapshot = Runs.snapshot()
    active = snapshot.active

    %{
      "run" =>
        active &&
          %{
            "id" => active["id"],
            "status" => active["status"],
            "phase" => active["phase"],
            "message" => active["message"],
            "cases" => length(active["cases"] || []),
            "current_case" => active["current_case"]
          },
      "preparation" =>
        if(get_in(snapshot, [:preparation, "status"]) == "running", do: snapshot.preparation),
      "cleaning" => snapshot.cleaning,
      "jobs" =>
        for {_, job} <- Registry.lookup(Eab.PubSub, @jobs) do
          Map.merge(job, %{"finished" => finished(job["id"]), "total" => length(job["ids"])})
        end
        |> Enum.sort_by(& &1["id"])
    }
  end

  @doc "One job's record and the results written so far."
  def job(job) do
    with true <- Store.valid_id?(job),
         %{} = record <- Store.read("factory/jobs/#{job}/job.json") do
      results =
        Store.path("factory/jobs/#{job}/results/*.json")
        |> Path.wildcard()
        |> Enum.sort()
        |> Enum.map(&Inventory.read_json/1)

      {:ok, Map.put(record, "results", results)}
    else
      _ -> {:error, "Unknown job: #{job}"}
    end
  end

  defp finished(job), do: length(Path.wildcard(Store.path("factory/jobs/#{job}/results/*.json")))

  ## the command line

  @doc """
  `bin/factoryctl`'s entry: runs one entry point from its arguments and prints the answer as JSON.

      import DIR
      check [--concurrency N] ID...
      export DEST ID...
      start-run [--settings JSON] [--parallel N] URL ID...
      kept RUN
      status
      job JOB
  """
  def cli(argv) do
    answer =
      try do
        dispatch(argv)
      rescue
        error -> {:error, Exception.message(error)}
      end

    IO.puts(Jason.encode!(json(answer), pretty: true))
  end

  defp dispatch(["import", dir]), do: __MODULE__.import(dir)

  defp dispatch(["check" | rest]) do
    {opts, ids} = OptionParser.parse!(rest, strict: [concurrency: :integer])
    check(ids, opts)
  end

  defp dispatch(["export", dest | ids]), do: export(ids, dest)

  defp dispatch(["start-run" | rest]) do
    {opts, [url | ids]} =
      OptionParser.parse!(rest, strict: [settings: :string, parallel: :integer])

    settings = if opts[:settings], do: Jason.decode!(opts[:settings]), else: %{}
    start_run(url, ids, settings, parallel_attempts: opts[:parallel] || 1)
  end

  defp dispatch(["kept", run]), do: kept_sessions(run)
  defp dispatch(["status"]), do: status()
  defp dispatch(["job", job]), do: job(job)
  defp dispatch(argv), do: {:error, "Unknown command: #{Enum.join(argv, " ")}"}

  defp json({:ok, value}), do: %{"ok" => value}
  defp json({:error, message}), do: %{"error" => message}
  defp json(value), do: %{"ok" => value}

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp stamp do
    (DateTime.utc_now() |> Calendar.strftime("%Y%m%d-%H%M%S-")) <>
      Base.encode16(:crypto.strong_rand_bytes(3), case: :lower)
  end

  defp unique, do: System.unique_integer([:positive])
end
