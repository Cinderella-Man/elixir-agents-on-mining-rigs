defmodule Eab.Thinking do
  @moduledoc "Records a local server's thinking preset without overriding it."
  @fields ~w(reasoning_effort enable_thinking chat_template_kwargs)

  def profile_fields, do: @fields

  def settings(endpoint, input) do
    reported = reported(endpoint)
    entered = normalize(input["reasoning_effort"])

    {effort, source} =
      case input["reasoning_effort_source"] do
        "server_reported" ->
          unless entered == reported, do: raise("Server thinking preset changed")
          {reported, "server_reported"}

        "not_reported" ->
          unless is_nil(reported), do: raise("Server thinking preset changed")
          {"unknown", "not_reported"}

        _ when entered not in [nil, ""] ->
          {entered, "operator_declared"}

        _ ->
          if reported, do: {reported, "server_reported"}, else: {"unknown", "not_reported"}
      end

    %{
      "reasoning_effort" => effort,
      "reasoning_effort_source" => source,
      "thinking_policy" => "server_preset"
    }
  end

  def reported(endpoint) do
    profile = endpoint["profile"] || %{}
    defaults = profile["default_generation_settings"] || %{}
    params = defaults["params"] || %{}

    values =
      Enum.reduce([profile, defaults, params], %{}, fn fields, acc ->
        Map.merge(acc, Map.take(fields, @fields))
      end)

    values = Map.merge(values, kwargs(values["chat_template_kwargs"]))

    cond do
      values["enable_thinking"] == false -> "off"
      is_binary(values["reasoning_effort"]) -> normalize(values["reasoning_effort"])
      values["enable_thinking"] == true -> "on"
      true -> nil
    end
  end

  # Pi may generate a thinking budget even though the operator selected a server
  # preset. Strip only request controls, preserving all reasoning history.
  # Legacy runs without this policy keep their original request behavior.
  def payload(body, %{"thinking_policy" => "server_preset"}) do
    body = Map.drop(body, ~w(thinking reasoning reasoning_effort reasoning_budget_tokens))

    Enum.reduce(
      [
        {"output_config", ["effort"]},
        {"chat_template_kwargs", ["enable_thinking", "reasoning_effort"]}
      ],
      body,
      fn {key, controls}, body ->
        case body[key] do
          value when is_map(value) ->
            rest = Map.drop(value, controls)
            if map_size(rest) == 0, do: Map.delete(body, key), else: Map.put(body, key, rest)

          _ ->
            body
        end
      end
    )
  end

  def payload(body, _), do: body

  def label(settings) do
    case (settings || %{})["reasoning_effort"] do
      nil -> "Not recorded"
      "unknown" -> "Not reported"
      "on" -> "On (no level)"
      "off" -> "Off"
      "default" -> "Server/provider default"
      "unsupported" -> "Not supported"
      effort -> effort
    end
  end

  defp normalize(nil), do: nil

  defp normalize(value) when is_binary(value) do
    value = value |> String.trim() |> String.downcase()

    unless value == "" or Regex.match?(~r/^[a-z0-9][a-z0-9_-]{0,63}$/, value),
      do: raise(ArgumentError, "Thinking preset must be a short name, such as off, on or xhigh")

    if value == "", do: nil, else: value
  end

  defp normalize(_), do: raise(ArgumentError, "Thinking preset must be text")

  defp kwargs(value) when is_map(value), do: value

  defp kwargs(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, fields} when is_map(fields) -> fields
      _ -> %{}
    end
  end

  defp kwargs(_), do: %{}
end
