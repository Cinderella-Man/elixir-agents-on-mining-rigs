defmodule Eab.Agent do
  @moduledoc "Harness submission and independent grading, with durable handoff between them."
  alias Eab.{
    Checkpoints,
    Evidence,
    Grader,
    Inventory,
    Model,
    Pi,
    Sandbox,
    Store,
    TaskContract
  }

  def attempt(id, run_id, endpoint, key, settings, control, emit) do
    submission =
      Sandbox.with_box(id, run_id, &submit(id, run_id, &1, endpoint, key, settings, emit),
        agent: true
      )

    grade(id, run_id, submission, endpoint, key, control, emit)
  rescue
    error -> error(id, run_id, Exception.message(error), key)
  end

  def submit(id, run_id, box, endpoint, key, settings, emit) do
    prefix = "runs/#{run_id}/#{id}"
    spec = Inventory.spec(id)
    prompt = Inventory.file(id, "ticket.md")
    instructions = instructions(spec, settings)

    base = %{
      "case" => id,
      "settings" => settings,
      "agent" => Pi.identity(),
      "agent_image" => box.runtime["image"],
      "calls" => 0,
      "generated_tokens" => 0,
      "status" => "running",
      "model" => endpoint
    }

    Store.write("#{prefix}/attempt.json", base, key)
    Store.write_text("#{prefix}/prompt.md", prompt, key)
    Store.write_text("#{prefix}/instructions.md", instructions, key)

    {record, patch} =
      try do
        # The factory records no elapsed time or speed: every attempt starts with
        # measuring off. Pi still calls the measuring modules, so they stay.
        result =
          Pi.run(box, endpoint, key, settings, prefix, prompt, instructions, emit, measure: false)

        {Map.merge(base, result), Sandbox.patch(box)}
      after
        try do
          Store.write_text("#{prefix}/model.patch", Sandbox.patch(box), key)
        rescue
          _ -> :ok
        end
      end

    Checkpoints.submit(run_id, id, record, patch, key)
  end

  @doc "Pi's exact task instructions."
  def instructions(spec, settings) do
    """
    #{TaskContract.instructions(spec)}
    Dependencies are prepared. The workspace is offline. Preserve existing behavior and do not weaken tests.

    Allowed edit prefixes: #{Enum.join(spec["allowed_edit_prefixes"], ", ")}.
    When finished, give a short summary. Your current patch is then checked in a fresh workspace.
    #{budget_instructions(settings)}
    History is never compacted. If a budget is exhausted, the current patch is graded.
    Task details: #{Jason.encode!(spec["clarifications"] || %{})}
    """
  end

  def grade(id, run_id, {record, patch}, endpoint, key, control, emit) do
    prefix = "runs/#{run_id}/#{id}"
    Store.write("#{prefix}/attempt.json", Map.put(record, "status", "grading"), key)
    emit.("Grading #{id}")
    grade = Grader.grade(id, patch, run_id, expected: control["reference_patch"])
    Model.unchanged!(endpoint, key)
    summary = Evidence.save(run_id, id, grade, key)
    record = Map.merge(record, %{"status" => "completed", "grade" => summary})
    Checkpoints.complete(run_id, id, record, key) |> Evidence.compact()
  end

  def error(id, run_id, message, key) do
    prefix = "runs/#{run_id}/#{id}"
    Store.write_text("#{prefix}/error.txt", message, key)

    record =
      Store.read("#{prefix}/attempt.json", %{"case" => id})
      |> Map.merge(Store.read("#{prefix}/agent-progress.json", %{}))
      |> Map.merge(%{
        "status" => "error",
        "error" => Store.redact(message, key) |> String.slice(0, 2000)
      })

    Store.write("#{prefix}/attempt.json", record, key)
    Eab.Activity.note("ERROR: " <> record["error"])
    record
  end

  defp budget_instructions(settings) do
    "Model and tool calls are unlimited. Limits: #{settings["max_tokens"]} generated tokens total, #{settings["window_tokens"]} context tokens including up to #{settings["response_tokens"]} response tokens."
  end
end
