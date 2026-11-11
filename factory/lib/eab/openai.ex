defmodule Eab.OpenAI.Error do
  defexception [:message, :status, :code, :param, :request_id, :body]
end

defmodule Eab.OpenAI do
  @moduledoc "ChatGPT subscription discovery and stateless Responses transport for the existing Pi runner."
  alias Eab.{ChatGPTAuth, Store}
  @url "https://api.openai.com"
  @unsupported ~w(background conversation max_output_tokens max_tool_calls metadata moderation multi_agent prompt prompt_cache_retention prompt_cache_options safety_identifier temperature top_logprobs top_p truncation user previous_response_id seed max_tokens max_completion_tokens stream_options)

  def endpoint?(url) do
    Eab.Model.normalize_url!(url) == @url
  rescue
    _ -> false
  end

  def catalog(account) do
    body = request(account, :get, "/v1/models")
    unless is_list(body["models"]), do: raise("OpenAI did not return a ChatGPT model catalog")
    rows = Enum.filter(body["models"], &(&1["visibility"] == "list" and is_binary(&1["slug"])))
    if rows == [], do: raise("No models are available to this ChatGPT account")
    Enum.map(rows, &Map.take(&1, ~w(slug display_name)))
  end

  def endpoint(account, row) do
    %{
      "url" => @url,
      "backend" => "openai_subscription",
      "model" => row["slug"],
      "account_id" => account,
      "context" => nil,
      "profile" => %{"transport" => "responses", "billing" => "chatgpt_subscription"},
      "metadata" => %{"model" => row},
      "identity_note" =>
        "Account-visible OpenAI model; serving revision and context capacity are not reported."
    }
  end

  def unchanged!(endpoint) do
    assert_endpoint!(endpoint)

    unless Enum.any?(catalog(endpoint["account_id"]), &(&1["slug"] == endpoint["model"])),
      do: raise("Selected model is no longer available to this ChatGPT account")

    :ok
  end

  def settings(input) do
    value = input["max_tokens"] || "262144"
    value = if is_integer(value), do: value, else: String.to_integer(value)

    unless value in 1..10_000_000,
      do: raise("Generated-token threshold must be between 1 and 10000000")

    effort = input["reasoning_effort"] || "high"
    unless effort in ~w(default low medium high xhigh), do: raise("Invalid reasoning effort")

    %{
      "max_tokens" => value,
      "budget_policy" => "response_boundary_soft_limit",
      "context_policy" => "provider_enforced",
      "window_tokens" => nil,
      "response_tokens" => nil,
      "seed" => nil,
      "compaction" => false,
      "reasoning_effort" => effort
    }
  rescue
    _ in ArgumentError ->
      raise ArgumentError, "Generated-token threshold must be a positive integer"
  end

  def payload(body, endpoint, settings) do
    assert_endpoint!(endpoint)
    unless is_list(body["input"]), do: raise("Pi must provide complete Responses input history")

    input =
      Enum.map(body["input"], fn
        %{"role" => "system"} = item -> Map.put(item, "role", "developer")
        item -> item
      end)

    # Keep Pi's call IDs, namespaces, tool outputs and encrypted reasoning intact.
    # This route requires namespace groups for function definitions.
    tools = body["tools"] || []
    unless Enum.all?(tools, &(&1["type"] == "function")), do: raise("Unsupported Pi tool schema")

    body =
      body
      |> Map.drop(@unsupported)
      |> Map.merge(%{
        "model" => endpoint["model"],
        "store" => false,
        "stream" => true,
        "input" => input,
        "include" => ["reasoning.encrypted_content"]
      })

    body =
      if tools == [],
        do: Map.delete(body, "tools"),
        else:
          Map.put(body, "tools", [
            %{
              "type" => "namespace",
              "name" => "functions",
              "description" => "Pi workspace tools",
              "tools" => tools
            }
          ])

    if settings["reasoning_effort"] == "default",
      do: Map.delete(body, "reasoning"),
      else:
        Map.put(body, "reasoning", %{
          "effort" => settings["reasoning_effort"],
          "summary" => "auto"
        })
  end

  def stream(endpoint, payload) do
    assert_endpoint!(endpoint)
    request(endpoint["account_id"], :post, "/v1/responses", payload)
  end

  def usage(%{body: body} = response) do
    usage(body)
  rescue
    error in Eab.OpenAI.Error ->
      raise %{error | status: response.status, request_id: response.request_id}
  end

  def usage(body) do
    events =
      body
      |> String.split(~r/\r?\n\r?\n/)
      |> Enum.flat_map(fn block ->
        lines =
          for "data:" <> line <- String.split(block, ~r/\r?\n/), do: String.trim_leading(line)

        case Enum.join(lines, "\n") do
          value when value in ["", "[DONE]"] -> []
          value -> [Jason.decode!(value)]
        end
      end)

    for event <- events do
      if event["type"] in ["error", "response.failed", "response.incomplete"] or event["error"] do
        code =
          get_in(event, ["response", "error", "code"]) || get_in(event, ["error", "code"]) ||
            event["code"]

        raise Eab.OpenAI.Error, message: failure(code), code: code, body: event
      end
    end

    completed = Enum.filter(events, &(&1["type"] == "response.completed"))

    unless length(completed) == 1 and get_in(hd(completed), ["response", "status"]) == "completed",
      do: raise("OpenAI stream ended without a completed response; this attempt is an error")

    usage = get_in(hd(completed), ["response", "usage"]) || %{}
    input = usage["input_tokens"]
    output = usage["output_tokens"]
    reasoning = get_in(usage, ["output_tokens_details", "reasoning_tokens"]) || 0

    unless is_integer(input) and input >= 0 and is_integer(output) and output >= 0 and
             is_integer(reasoning) and reasoning >= 0 and reasoning <= output,
           do: raise("OpenAI returned missing or invalid usage accounting")

    %{"input_tokens" => input, "output_tokens" => output, "reasoning_tokens" => reasoning}
  end

  defp assert_endpoint!(endpoint) do
    unless endpoint["url"] == @url and endpoint["backend"] == "openai_subscription",
      do: raise("ChatGPT credentials can only be sent to https://api.openai.com")
  end

  defp request(account, method, route, payload \\ nil) do
    if payload do
      case ChatGPTAuth.check_inference(account) do
        :ok -> :ok
        {:error, message} -> raise message
      end
    end

    key =
      case ChatGPTAuth.token(account) do
        {:ok, token} -> token
        {:error, message} -> raise message
      end

    opts = [
      url: @url <> route,
      method: method,
      headers: [{"authorization", "Bearer " <> key}],
      retry: false,
      redirect: false,
      receive_timeout: if(payload, do: 1_200_000, else: 30_000),
      connect_options: [timeout: 10_000],
      decode_body: is_nil(payload)
    ]

    opts =
      if payload do
        into = fn {:data, data}, {req, response} ->
          chunks = [data | Map.get(response.private, :eab_chunks, [])]
          {:cont, {req, %{response | private: Map.put(response.private, :eab_chunks, chunks)}}}
        end

        opts ++ [json: payload, into: into]
      else
        opts
      end

    transport = Application.get_env(:eab, :http_request, &Req.request/1)
    # Never replay a possibly submitted generation, refresh on a 401, or change billing routes.
    case transport(transport, opts) do
      {:ok, %{status: status} = response} ->
        body =
          case response do
            %{private: %{eab_chunks: chunks}} -> chunks |> Enum.reverse() |> IO.iodata_to_binary()
            _ -> response.body
          end

        request_id = response |> Map.get(:headers, %{}) |> request_id() |> Store.scrub(key)

        if status in 200..299 do
          body = Store.scrub(body, key)
          if payload, do: %{body: body, status: status, request_id: request_id}, else: body
        else
          decoded =
            if is_binary(body) do
              case Jason.decode(body) do
                {:ok, data} -> data
                _ -> body
              end
            else
              body
            end

          decoded = Store.scrub(decoded, key)
          code = if is_map(decoded) and is_map(decoded["error"]), do: decoded["error"]["code"]
          param = if is_map(decoded) and is_map(decoded["error"]), do: decoded["error"]["param"]

          message =
            cond do
              code ->
                failure(code)

              status == 401 ->
                "ChatGPT rejected the signed session or its permission. Check the account and granted plan access."

              true ->
                "OpenAI request failed (HTTP #{status}); check ChatGPT plan access and model settings"
            end

          error = %Eab.OpenAI.Error{
            message: message,
            status: status,
            code: code,
            param: param,
            request_id: Store.scrub(request_id, key),
            body: decoded
          }

          pause_for(account, error)
          raise error
        end

      _ ->
        raise "OpenAI connection failed; the request was not replayed"
    end
  end

  def pause_for(account, %Eab.OpenAI.Error{code: code} = error)
      when code in ~w(subscription_sharing_usage_limit_exceeded subscription_sharing_usage_unavailable subscription_sharing_user_not_eligible subscription_sharing_invalid_user chatpass_v2_scope_not_authorized chatpass_v2_invalid_authorization_context) do
    ChatGPTAuth.pause(account, Exception.message(error))
  end

  def pause_for(_, _), do: :ok

  def error_details(error), do: Map.from_struct(error) |> Map.drop([:__exception__])

  defp request_id(headers) when is_map(headers),
    do: headers |> Map.get("x-request-id", []) |> List.wrap() |> List.first()

  defp request_id(_), do: nil

  defp transport(fun, opts) do
    fun.(opts)
  rescue
    _ -> {:error, :transport}
  end

  defp failure("subscription_sharing_usage_limit_exceeded"),
    do:
      "ChatGPT app usage limit reached. Requests are paused. Review https://chatgpt.com/settings/usage; no reset time is assumed. This attempt is an error, not a failed repair."

  defp failure("subscription_sharing_usage_unavailable"),
    do:
      "ChatGPT usage availability could not be checked. Requests are paused; reconnect later. See https://chatgpt.com/settings/usage."

  defp failure("subscription_sharing_user_not_eligible"),
    do:
      "ChatGPT plan usage is unavailable for this user, workspace or policy. Requests are paused; check eligibility before reconnecting."

  defp failure(code) when is_binary(code),
    do:
      "OpenAI rejected the request (#{code}); inspect the saved provider error before reconnecting."

  defp failure(_), do: "OpenAI returned a failed or incomplete response; this attempt is an error"
end
