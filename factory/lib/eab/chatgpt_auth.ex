defmodule Eab.ChatGPTAuth do
  @moduledoc "App-owned ChatGPT registrations and serialized rotating credentials, outside run evidence."
  use GenServer
  @issuer "https://auth.openai.com"
  @resource "https://api.openai.com/v1"
  @scope "openid profile email offline_access resource.invoke chatgpt.tokens.use.direct"
  @tokens ~w(access_token refresh_token id_token expires_at scopes earliest_refresh_at)

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)

  def accounts(server \\ server()), do: GenServer.call(server, :accounts, 90_000)

  def begin(account, redirect_uri, server \\ server()),
    do: GenServer.call(server, {:begin, account, redirect_uri}, 90_000)

  def complete(params, browser_state, server \\ server()),
    do: GenServer.call(server, {:complete, params, browser_state}, 90_000)

  def token(account, server \\ server()), do: GenServer.call(server, {:token, account}, 90_000)

  def sign_out(account, server \\ server()),
    do: GenServer.call(server, {:sign_out, account}, 90_000)

  def check_inference(account, server \\ server()),
    do: GenServer.call(server, {:check_inference, account}, 90_000)

  def pause(account, message, server \\ server()),
    do: GenServer.call(server, {:pause, account, message}, 90_000)

  def retry_requests(account, server \\ server()),
    do: GenServer.call(server, {:retry_requests, account}, 90_000)

  @impl true
  def init(opts) do
    path = opts[:path] || Eab.Store.path("credentials/chatgpt.json")

    data =
      case File.read(path) do
        {:ok, body} ->
          case Jason.decode(body) do
            {:ok, %{"accounts" => accounts, "host_id" => host} = data}
            when is_map(accounts) and is_binary(host) ->
              data

            _ ->
              raise "ChatGPT credential storage is invalid"
          end

        {:error, :enoent} ->
          %{"host_id" => host_id(), "accounts" => %{}}

        {:error, _} ->
          raise "Cannot read ChatGPT credential storage"
      end

    state = %{
      path: path,
      data: data,
      pending: %{},
      paused: %{},
      request: opts[:request] || (&Req.request/1)
    }

    persist(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:accounts, _, state) do
    accounts =
      state.data["accounts"]
      |> Map.values()
      |> Enum.sort_by(& &1["client_id"])
      |> Enum.map(fn a ->
        %{
          "id" => a["client_id"],
          "email" => a["email"],
          "signed_in" => is_binary(a["access_token"]),
          "plan_enabled" => plan_enabled?(a),
          "label" => "#{a["email"] || "Registration"} · #{a["client_id"]}"
        }
      end)

    {:reply, accounts, state}
  end

  def handle_call({:begin, id, redirect_uri}, _, state) do
    result =
      safely(fn ->
        uri = URI.parse(redirect_uri)

        unless uri.scheme == "http" and uri.host == "127.0.0.1" and
                 uri.path == "/auth/chatgpt/callback" and is_nil(uri.query) and
                 is_nil(uri.fragment) and is_nil(uri.userinfo),
               do: raise("ChatGPT sign-in requires the local 127.0.0.1 callback")

        account = if id in [nil, ""], do: %{}, else: account!(state, id)
        discovery = discovery!(state)

        pending = %{
          state: random(),
          nonce: random(),
          verifier: random(),
          redirect_uri: redirect_uri,
          client_id: account["client_id"],
          expires: now() + 600
        }

        params = %{
          "client_id" => account["client_id"] || "dynamic_agent_client",
          "ext_agent_host_id" => state.data["host_id"],
          "response_type" => "code",
          "redirect_uri" => redirect_uri,
          "scope" => @scope,
          "resource" => @resource,
          "state" => pending.state,
          "nonce" => pending.nonce,
          "code_challenge_method" => "S256",
          "code_challenge" =>
            Base.url_encode64(:crypto.hash(:sha256, pending.verifier), padding: false)
        }

        params =
          if account["client_id"],
            do: params,
            else: Map.put(params, "agent_name_hint", "Elixir Agent Benchmark")

        params =
          if account["subject"] && not plan_enabled?(account),
            do: Map.put(params, "prompt", "consent"),
            else: params

        # No ID-token hint in a URL or Phoenix redirect log. The account selector is intentional.
        {discovery["authorization_endpoint"] <> "?" <> URI.encode_query(params), pending}
      end)

    case result do
      {:ok, {url, pending}} ->
        live = Map.reject(state.pending, fn {_, p} -> p.expires < now() end)

        {:reply, {:ok, url, pending.state},
         %{state | pending: Map.put(live, pending.state, pending)}}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:complete, params, browser_state}, _, state) do
    token_state = params["state"]

    # Validate the browser binding before consuming an attempt. Never accept unsolicited callbacks.
    pending =
      if is_binary(browser_state) and is_binary(token_state) and
           Plug.Crypto.secure_compare(browser_state, token_state),
         do: state.pending[token_state]

    if is_nil(pending) or pending.expires < now() do
      {:reply, {:error, "ChatGPT sign-in expired or its state did not match. Start again."},
       state}
    else
      state = %{state | pending: Map.delete(state.pending, token_state)}

      result =
        safely(fn ->
          if params["error"],
            do: raise("ChatGPT sign-in was not authorized. Start again to enable plan usage.")

          client = params["client_id"] || pending.client_id

          unless is_binary(client) and byte_size(client) in 1..1024 and
                   client != "dynamic_agent_client" and
                   (is_nil(pending.client_id) or client == pending.client_id),
                 do: raise("ChatGPT returned a missing or mismatched registration")

          unless is_binary(params["code"]) and params["code"] != "",
            do: raise("Missing authorization code")

          client
        end)

      case result do
        {:error, _} = error ->
          {:reply, error, state}

        {:ok, client} ->
          # Keep the issued registration even when code exchange fails; never reuse the code.
          previous = state.data["accounts"][client] || %{"client_id" => client}
          state = put_account(state, client, previous)

          result =
            safely(fn ->
              discovery = discovery!(state)

              response =
                post!(state, discovery["token_endpoint"],
                  grant_type: "authorization_code",
                  client_id: client,
                  code: params["code"],
                  code_verifier: pending.verifier,
                  redirect_uri: pending.redirect_uri,
                  resource: @resource
                )

              claims = verify!(state, discovery, response["id_token"], client, pending.nonce)
              same_identity!(previous, claims)

              credentials!(
                response,
                Map.merge(previous, %{
                  "subject" => claims["sub"],
                  "issuer" => claims["iss"],
                  "email" => claims["email"]
                })
              )
            end)

          case result do
            {:ok, account} ->
              {:reply, {:ok, client},
               put_account(%{state | paused: Map.delete(state.paused, client)}, client, account)}

            {:error, _} = error ->
              {:reply, error, state}
          end
      end
    end
  end

  def handle_call({:pause, id, message}, _, state),
    do: {:reply, :ok, %{state | paused: Map.put(state.paused, id, message)}}

  def handle_call({:retry_requests, id}, _, state),
    do: {:reply, :ok, %{state | paused: Map.delete(state.paused, id)}}

  def handle_call({:check_inference, id}, _, %{paused: paused} = state)
      when is_map_key(paused, id),
      do: {:reply, {:error, paused[id] <> " Reconnect explicitly before trying again."}, state}

  def handle_call({:check_inference, _id}, _, state), do: {:reply, :ok, state}

  def handle_call({:token, id}, _, state) do
    result =
      safely(fn ->
        account = account!(state, id)

        unless is_binary(account["access_token"]),
          do: raise("Continue with ChatGPT to sign in again")

        unless plan_enabled?(account),
          do: raise("ChatGPT plan usage is disabled. Continue with ChatGPT to enable it.")

        earliest = account["earliest_refresh_at"] || 0

        if earliest > now() and account["expires_at"] <= now(),
          do: raise("ChatGPT token renewal is not available yet. Retry later.")

        if account["expires_at"] > now() + 60 or earliest > now() do
          account
        else
          discovery = discovery!(state)

          response =
            post!(state, discovery["token_endpoint"],
              grant_type: "refresh_token",
              client_id: id,
              refresh_token: account["refresh_token"],
              resource: @resource
            )

          if response["id_token"] do
            claims = verify!(state, discovery, response["id_token"], id, nil)
            same_identity!(account, claims)
          end

          credentials!(response, account, true)
        end
      end)

    case result do
      {:ok, account} ->
        reply =
          if plan_enabled?(account),
            do: {:ok, account["access_token"]},
            else: {:error, "ChatGPT plan usage is disabled. Continue with ChatGPT to enable it."}

        {:reply, reply, put_account(state, id, account)}

      {:error, :reauthorize} ->
        state =
          if state.data["accounts"][id],
            do: put_account(state, id, Map.drop(state.data["accounts"][id], @tokens)),
            else: state

        {:reply, {:error, "ChatGPT session expired or was revoked. Continue with ChatGPT again."},
         state}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:sign_out, id}, _, state) do
    account = state.data["accounts"][id]

    if account do
      result =
        safely(fn ->
          if account["refresh_token"] do
            url = discovery!(state)["revocation_endpoint"]
            # One bounded retry while we still possess the token. Local sign-out always completes.
            case revoke(state, url, account) do
              :ok ->
                :ok

              :error ->
                Process.sleep(250)

                if revoke(state, url, account) != :ok,
                  do:
                    raise(
                      "Remote revocation was not confirmed. Disconnect this app in ChatGPT Settings."
                    )
            end
          end
        end)

      state = put_account(state, id, Map.drop(account, @tokens))
      {:reply, result, state}
    else
      {:reply, {:error, "Unknown ChatGPT account"}, state}
    end
  end

  defp revoke(state, url, account) do
    case request(state, :post, url,
           form: [
             token: account["refresh_token"],
             token_type_hint: "refresh_token",
             client_id: account["client_id"]
           ]
         ) do
      {:ok, %{status: 200}} -> :ok
      _ -> :error
    end
  end

  defp credentials!(response, previous, refresh \\ false) do
    scopes =
      if is_binary(response["scope"]),
        do: String.split(response["scope"]),
        else: if(refresh, do: previous["scopes"] || [], else: [])

    unless is_binary(response["access_token"]) and response["access_token"] != "" and
             String.downcase(response["token_type"] || "") == "bearer" and
             is_integer(response["expires_in"]) and response["expires_in"] > 0 and
             (not plan_enabled?(%{"scopes" => scopes}) or is_binary(response["refresh_token"])),
           do: raise("ChatGPT returned an incomplete credential set")

    Map.merge(previous, %{
      "access_token" => response["access_token"],
      "refresh_token" => response["refresh_token"] || previous["refresh_token"],
      "id_token" => response["id_token"] || previous["id_token"],
      "scopes" => scopes,
      "expires_at" => now() + response["expires_in"],
      "earliest_refresh_at" => refresh_time(response["earliest_refresh_at"])
    })
  end

  defp verify!(state, discovery, token, audience, nonce) do
    jwks = get!(state, discovery["jwks_uri"])
    verify_id_token!(token, jwks, audience, nonce)
  end

  @doc false
  def verify_id_token!(token, jwks, audience, nonce) do
    try do
      [header, _, _] = String.split(token, ".")
      header = header |> Base.url_decode64!(padding: false) |> Jason.decode!()
      true = header["alg"] == "RS256"

      key =
        Enum.find(
          jwks["keys"],
          &(&1["kid"] == header["kid"] and &1["kty"] == "RSA" and
              &1["use"] in [nil, "sig"] and &1["alg"] in [nil, "RS256"])
        )

      true = is_map(key)

      {true, %JOSE.JWT{fields: claims}, _} =
        JOSE.JWT.verify_strict(JOSE.JWK.from_map(key), ["RS256"], token)

      true = claims["iss"] == @issuer
      audiences = List.wrap(claims["aud"])
      true = audience in audiences

      true =
        (length(audiences) == 1 and claims["azp"] in [nil, audience]) or claims["azp"] == audience

      true = is_integer(claims["exp"]) and claims["exp"] > now()
      true = is_nil(claims["nbf"]) or (is_integer(claims["nbf"]) and claims["nbf"] <= now())
      true = is_binary(claims["sub"]) and claims["sub"] != ""
      true = is_nil(nonce) or claims["nonce"] == nonce
      claims
    rescue
      _ -> raise "ChatGPT identity verification failed. Start sign-in again."
    end
  end

  defp same_identity!(previous, claims) do
    if previous["subject"] &&
         (previous["subject"] != claims["sub"] or previous["issuer"] != claims["iss"]),
       do: raise("ChatGPT identity differs from the selected registration")
  end

  defp discovery!(state) do
    document = get!(state, @issuer <> "/.well-known/openid-configuration")
    unless document["issuer"] == @issuer, do: raise("Invalid ChatGPT identity provider")

    for field <- ~w(authorization_endpoint token_endpoint jwks_uri revocation_endpoint) do
      uri = URI.parse(document[field] || "")

      unless uri.scheme == "https" and uri.host == "auth.openai.com" and uri.port == 443 and
               is_nil(uri.userinfo) and is_nil(uri.fragment),
             do: raise("Invalid ChatGPT identity endpoint")
    end

    document
  end

  defp request(state, method, url, opts \\ []) do
    state.request.(
      [
        method: method,
        url: url,
        retry: false,
        redirect: false,
        receive_timeout: 15_000,
        connect_options: [timeout: 10_000]
      ] ++ opts
    )
  rescue
    _ -> {:error, :transport}
  end

  defp get!(state, url) do
    case request(state, :get, url) do
      {:ok, %{status: 200, body: body}} when is_map(body) -> body
      _ -> raise "Cannot contact ChatGPT sign-in. Try again."
    end
  end

  defp post!(state, url, form) do
    case request(state, :post, url, form: form) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        body

      {:ok, %{body: %{"error" => error}}}
      when error in [
             "invalid_grant",
             "invalid_refresh_token",
             "token_expired",
             "refresh_token_expired",
             "refresh_token_invalidated",
             "refresh_token_reused"
           ] ->
        throw(:reauthorize)

      _ ->
        raise "ChatGPT token exchange is unavailable. Try again; check the saved client registration if it persists."
    end
  end

  defp account!(state, id), do: state.data["accounts"][id] || raise("Unknown ChatGPT account")

  defp safely(fun) do
    {:ok, fun.()}
  rescue
    error in RuntimeError -> {:error, error.message}
    _ -> {:error, "ChatGPT authentication failed. Start sign-in again."}
  catch
    :reauthorize -> {:error, :reauthorize}
  end

  defp put_account(state, id, account) do
    if state.data["accounts"][id] == account do
      state
    else
      state = %{state | data: put_in(state.data, ["accounts", id], account)}
      persist(state)
      state
    end
  end

  defp persist(state) do
    dir = Path.dirname(state.path)
    File.mkdir_p!(dir)
    File.chmod!(dir, 0o700)
    tmp = state.path <> ".tmp"
    File.write!(tmp, Jason.encode!(state.data))
    File.chmod!(tmp, 0o600)
    File.rename!(tmp, state.path)
  end

  # Do not include credentials or pending authorization codes in OTP crash/status reports.
  @impl true
  def format_status(status),
    do:
      Map.merge(status, %{
        state: "[private ChatGPT credentials]",
        message: "[private authentication request]",
        log: []
      })

  defp server, do: Application.get_env(:eab, :chatgpt_auth_server, __MODULE__)

  defp plan_enabled?(account),
    do:
      Enum.all?(~w(resource.invoke chatgpt.tokens.use.direct), &(&1 in (account["scopes"] || [])))

  defp refresh_time(nil), do: nil
  defp refresh_time(value) when is_integer(value) and value >= 0, do: value

  defp refresh_time(value) when is_binary(value) do
    case Integer.parse(value) do
      {seconds, ""} when seconds >= 0 ->
        seconds

      _ ->
        case DateTime.from_iso8601(value) do
          {:ok, time, _} -> DateTime.to_unix(time)
          _ -> raise "ChatGPT returned an invalid token renewal time"
        end
    end
  end

  defp refresh_time(_), do: raise("ChatGPT returned an invalid token renewal time")
  defp random, do: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
  defp now, do: System.system_time(:second)

  defp host_id do
    <<a::32, b::16, _::4, c::12, _::2, d::14, e::48>> = :crypto.strong_rand_bytes(16)

    hex = fn n, width ->
      n |> Integer.to_string(16) |> String.downcase() |> String.pad_leading(width, "0")
    end

    "urn:uuid:#{hex.(a, 8)}-#{hex.(b, 4)}-4#{hex.(c, 3)}-#{hex.(Bitwise.bor(d, 0x8000), 4)}-#{hex.(e, 12)}"
  end
end
