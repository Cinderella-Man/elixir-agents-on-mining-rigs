defmodule Eab.ChatGPTFixture do
  import ExUnit.Callbacks
  alias Eab.ChatGPTAuth

  def start! do
    key = JOSE.JWK.generate_key({:rsa, 2048})
    {_, jwk} = JOSE.JWK.to_public_map(key)
    jwk = Map.merge(jwk, %{"kid" => "test-key", "alg" => "RS256", "use" => "sig"})

    control =
      start_supervised!(
        {Agent,
         fn ->
           %{
             nonce: nil,
             subject: "test-user",
             refreshes: 0,
             exchanges: 0,
             error: nil,
             expiry: 3600,
             earliest_refresh_at: nil,
             scope: "openid email resource.invoke chatgpt.tokens.use.direct offline_access",
             revoked: false,
             revoke_error: false
           }
         end}
      )

    parent = self()

    request = fn opts ->
      send(parent, {:auth_request, opts})
      state = Agent.get(control, & &1)

      body =
        cond do
          String.ends_with?(opts[:url], "openid-configuration") ->
            %{
              "issuer" => "https://auth.openai.com",
              "authorization_endpoint" => "https://auth.openai.com/api/accounts/authorize",
              "token_endpoint" => "https://auth.openai.com/api/accounts/oauth/token",
              "revocation_endpoint" => "https://auth.openai.com/api/accounts/oauth/revoke",
              "jwks_uri" => "https://auth.openai.com/.well-known/jwks.json"
            }

          String.ends_with?(opts[:url], "jwks.json") ->
            %{"keys" => [jwk]}

          String.ends_with?(opts[:url], "/revoke") ->
            Agent.update(control, &%{&1 | revoked: true})
            ""

          String.ends_with?(opts[:url], "/token") ->
            refresh = opts[:form][:grant_type] == "refresh_token"
            field = if refresh, do: :refreshes, else: :exchanges
            Agent.update(control, &Map.update!(&1, field, fn count -> count + 1 end))

            if state.error do
              %{"error" => state.error}
            else
              claims = %{
                "iss" => "https://auth.openai.com",
                "sub" => state.subject,
                "aud" => opts[:form][:client_id],
                "exp" => System.system_time(:second) + 3600,
                "nonce" => state.nonce,
                "email" => "test@example.test"
              }

              %{
                "id_token" => sign(key, claims),
                "access_token" => "access-test-#{state.refreshes + if(refresh, do: 1, else: 0)}",
                "refresh_token" =>
                  "refresh-test-#{state.refreshes + if(refresh, do: 1, else: 0)}",
                "token_type" => "Bearer",
                "expires_in" => if(refresh, do: 3600, else: state.expiry),
                "scope" => state.scope,
                "earliest_refresh_at" => state.earliest_refresh_at
              }
            end
        end

      status =
        cond do
          is_map(body) and body["error"] -> 400
          state.revoke_error and String.ends_with?(opts[:url], "/revoke") -> 503
          true -> 200
        end

      {:ok, %{status: status, body: body}}
    end

    path = Eab.Store.path("test-auth-#{System.unique_integer([:positive])}/credentials.json")
    name = Eab.ChatGPTFixture.Auth
    server = start_supervised!({ChatGPTAuth, name: name, path: path, request: request})
    Application.put_env(:eab, :chatgpt_auth_server, name)

    on_exit(fn ->
      Application.delete_env(:eab, :chatgpt_auth_server)
      Application.delete_env(:eab, :http_request)
      File.rm_rf!(Path.dirname(path))
    end)

    %{
      server: server,
      name: name,
      control: control,
      path: path,
      key: key,
      jwk: jwk,
      request: request
    }
  end

  def begin!(fixture, account \\ nil) do
    {:ok, url, state} =
      ChatGPTAuth.begin(account, "http://127.0.0.1:4000/auth/chatgpt/callback", fixture.name)

    params = URI.decode_query(URI.parse(url).query)
    Agent.update(fixture.control, &%{&1 | nonce: params["nonce"]})
    {params, state}
  end

  def login!(fixture, id \\ "oaiapp_test") do
    {_, state} = begin!(fixture)

    {:ok, ^id} =
      ChatGPTAuth.complete(
        %{"state" => state, "code" => "code-test", "client_id" => id},
        state,
        fixture.name
      )

    id
  end

  def sign(key, claims) do
    {_, token} =
      JOSE.JWT.sign(key, %{"alg" => "RS256", "kid" => "test-key"}, claims) |> JOSE.JWS.compact()

    token
  end
end
