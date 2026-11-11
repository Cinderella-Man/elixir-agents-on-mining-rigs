defmodule Eab.Activity do
  @moduledoc "Per-case terminal output shared by command runners, Pi and the website."
  use GenServer
  alias Eab.Store
  @limit 67_108_864

  def context, do: Process.get(:eab_activity)

  def with_case(run_id, case_id, key, fun) do
    {:ok, pid} = GenServer.start_link(__MODULE__, {run_id, case_id, key})

    try do
      inherit(pid, fun)
    after
      if Process.alive?(pid), do: GenServer.stop(pid)
    end
  end

  def inherit(pid, fun) do
    previous = Process.put(:eab_activity, pid)

    try do
      fun.()
    after
      Process.put(:eab_activity, previous)
    end
  end

  def note(text), do: call({:note, text})
  def output(stream, data), do: call({:output, stream, data, false})
  def flush(stream), do: call({:output, stream, "", true})
  def model_chunk(stream, data), do: call({:model, stream, data})
  def model_end(stream), do: call({:model_end, stream})
  def pi(event), do: call({:pi, event})

  defp call(message) do
    if pid = context(), do: GenServer.call(pid, message, 30_000), else: :ok
  catch
    :exit, {:noproc, _} -> :ok
    :exit, {:normal, _} -> :ok
    :exit, {:killed, _} -> :ok
  end

  @impl true
  def init({run_id, case_id, key}) do
    path = Store.path("runs/#{run_id}/#{case_id}/activity.log")
    File.mkdir_p!(Path.dirname(path))
    File.chmod!(Path.dirname(path), 0o700)
    File.write!(path, "", [:append])
    File.chmod!(path, 0o600)

    {:ok,
     %{path: path, key: key, buffers: %{}, models: %{}, tools: %{}, size: File.stat!(path).size}}
  end

  @impl true
  def handle_call({:note, text}, _, state),
    do:
      {:reply, :ok,
       write(
         state,
         "\n[#{Calendar.strftime(DateTime.utc_now(), "%H:%M:%S UTC")}] #{Store.redact(text, state.key)}\n"
       )}

  def handle_call({:output, stream, data, final}, _, state),
    do: {:reply, :ok, stream_write(state, stream, data, final)}

  def handle_call({:model, stream, data}, _, state) do
    buffer = Map.get(state.models, stream, "") <> data
    blocks = Regex.split(~r/\r?\n\r?\n/, buffer)
    {ready, [pending]} = Enum.split(blocks, -1)
    state = put_in(state.models[stream], pending)

    state =
      Enum.reduce(ready, state, fn block, state ->
        body =
          for "data:" <> line <- String.split(block, ~r/\r?\n/), do: String.trim_leading(line)

        case Jason.decode(Enum.join(body, "\n")) do
          {:ok, event} -> stream_write(state, {:model, stream}, model_text(event), false)
          _ -> state
        end
      end)

    {:reply, :ok, state}
  end

  def handle_call({:model_end, stream}, _, state) do
    state = stream_write(state, {:model, stream}, "", true)
    {:reply, :ok, %{state | models: Map.delete(state.models, stream)}}
  end

  def handle_call({:pi, event}, _, state) do
    id = event["toolCallId"]

    state =
      case event["type"] do
        "tool_execution_start" ->
          args = event["args"] || %{}

          line =
            if event["toolName"] == "bash",
              do: "$ " <> to_string(args["command"]),
              else: event["toolName"] <> " " <> Jason.encode!(args, pretty: true)

          write(state, "\n\n" <> Store.redact(line, state.key) <> "\n")

        type when type in ["tool_execution_update", "tool_execution_end"] ->
          result = event["partialResult"] || event["result"] || %{}
          output = Enum.map_join(result["content"] || [], "\n", &(&1["text"] || ""))
          previous = state.tools[id] || ""

          delta =
            if String.starts_with?(output, previous),
              do:
                binary_part(output, byte_size(previous), byte_size(output) - byte_size(previous)),
              else: "\n" <> output

          state = put_in(state.tools[id], output)
          state = stream_write(state, {:tool, id}, delta, type == "tool_execution_end")

          if type == "tool_execution_end",
            do: write(state, "\n[Tool #{if event["isError"], do: "failed", else: "finished"}]\n"),
            else: state

        "message_end" ->
          if get_in(event, ["message", "stopReason"]) in ["error", "aborted"],
            do:
              write(
                state,
                "\nPi: " <>
                  Store.redact(event["message"]["errorMessage"] || "Stopped", state.key) <> "\n"
              ),
            else: state

        _ ->
          state
      end

    {:reply, :ok, state}
  end

  defp model_text(%{"type" => "content_block_delta", "delta" => delta}),
    do: delta["thinking"] || delta["text"] || delta["partial_json"] || ""

  defp model_text(%{
         "type" => "content_block_start",
         "content_block" => %{"type" => "tool_use", "name" => name}
       }),
       do: "\n[Model requests #{name}]\n"

  defp model_text(%{"choices" => choices}) do
    Enum.map_join(choices, fn choice ->
      delta = choice["delta"] || %{}

      (delta["reasoning_content"] || delta["reasoning"] || "") <>
        (delta["content"] || "") <>
        Enum.map_join(delta["tool_calls"] || [], fn call ->
          function = call["function"] || %{}

          if(function["name"], do: "\n[Model requests #{function["name"]}]\n", else: "") <>
            (function["arguments"] || "")
        end)
    end)
  end

  defp model_text(%{"type" => type, "delta" => delta})
       when type in [
              "response.output_text.delta",
              "response.reasoning_summary_text.delta",
              "response.function_call_arguments.delta"
            ] and is_binary(delta) do
    delta
  end

  defp model_text(%{
         "type" => "response.output_item.added",
         "item" => %{"type" => "function_call", "name" => name}
       }),
       do: "\n[Model requests #{name}]\n"

  defp model_text(_), do: ""

  # Hold a possible partial credential across chunk boundaries before writing.
  defp stream_write(state, stream, data, final) do
    body = Store.redact(Map.get(state.buffers, stream, "") <> data, state.key)
    keep = if final, do: 0, else: pending_secret(body, state.key)
    split = byte_size(body) - keep
    <<ready::binary-size(^split), pending::binary>> = body

    state = %{
      state
      | buffers:
          if(final,
            do: Map.delete(state.buffers, stream),
            else: Map.put(state.buffers, stream, pending)
          )
    }

    write(state, ready)
  end

  defp pending_secret(_, ""), do: 0

  defp pending_secret(body, key) do
    max_size = min(byte_size(key) - 1, byte_size(body))

    Enum.find(max_size..0//-1, 0, fn size ->
      binary_part(body, byte_size(body) - size, size) == binary_part(key, 0, size)
    end)
  end

  @impl true
  def terminate(_, state) do
    Enum.reduce(state.buffers, state, fn {stream, _}, state ->
      stream_write(state, stream, "", true)
    end)

    :ok
  end

  defp write(state, ""), do: state
  defp write(%{size: size} = state, _) when size >= @limit, do: state

  defp write(state, text) do
    text =
      if state.size + byte_size(text) > @limit,
        do: binary_part(text, 0, @limit - state.size) <> "\n[Log size limit reached]\n",
        else: text

    File.write!(state.path, text, [:append])
    %{state | size: state.size + byte_size(text)}
  end
end
