defmodule Eab.ChatGPTAuthTest do
  use ExUnit.Case, async: false
  alias Eab.{ChatGPTAuth, ChatGPTFixture}
  setup do: ChatGPTFixture.start!()

  test "registers with PKCE, verifies identity, persists privately and reuses registration", f do
    {params, state} = ChatGPTFixture.begin!(f)
    assert params["client_id"] == "dynamic_agent_client"
    assert params["agent_name_hint"] == "Elixir Agent Benchmark"
    assert params["ext_agent_host_id"] =~ ~r/^urn:uuid:[a-f0-9-]+$/
    assert params["code_challenge_method"] == "S256"

    assert {:ok, "oaiapp_test"} =
             ChatGPTAuth.complete(
               %{"state" => state, "code" => "code-test", "client_id" => "oaiapp_test"},
               state
             )

    assert {:ok, "access-test-0"} = ChatGPTAuth.token("oaiapp_test")

    assert_receive {:auth_request,
                    [
                      method: :post,
                      url: _,
                      retry: false,
                      redirect: false,
                      receive_timeout: _,
                      connect_options: _,
                      form: form
                    ]}

    assert form[:redirect_uri] == params["redirect_uri"]
    assert form[:client_id] == "oaiapp_test"

    assert Base.url_encode64(:crypto.hash(:sha256, form[:code_verifier]), padding: false) ==
             params["code_challenge"]

    assert Bitwise.band(File.stat!(f.path).mode, 0o777) == 0o600
    assert Bitwise.band(File.stat!(Path.dirname(f.path)).mode, 0o777) == 0o700
    refute inspect(ChatGPTAuth.accounts()) =~ "access-test"
    refute inspect(:sys.get_status(f.server)) =~ "access-test"
    stop_supervised!(ChatGPTAuth)
    start_supervised!({ChatGPTAuth, name: f.name, path: f.path, request: f.request})
    {returning, _} = ChatGPTFixture.begin!(f, "oaiapp_test")
    assert returning["client_id"] == "oaiapp_test"
    assert returning["ext_agent_host_id"] == params["ext_agent_host_id"]
    refute Map.has_key?(returning, "agent_name_hint")
    assert {:ok, "access-test-0"} = ChatGPTAuth.token("oaiapp_test")
  end

  test "rejects wrong browser binding, consumes callbacks once and honors denial", f do
    {_, state} = ChatGPTFixture.begin!(f)
    params = %{"state" => state, "code" => "code-test", "client_id" => "oaiapp_test"}
    assert {:error, _} = ChatGPTAuth.complete(params, "attacker")
    assert {:ok, _} = ChatGPTAuth.complete(params, state)
    assert {:error, _} = ChatGPTAuth.complete(params, state)
    {_, denied} = ChatGPTFixture.begin!(f)

    assert {:error, _} =
             ChatGPTAuth.complete(%{"state" => denied, "error" => "access_denied"}, denied)

    assert Agent.get(f.control, & &1.exchanges) == 1
  end

  test "retains an issued registration after failed exchange and refuses replacement client/identity",
       f do
    {_, state} = ChatGPTFixture.begin!(f)
    Agent.update(f.control, &%{&1 | error: "invalid_grant"})

    assert {:error, :reauthorize} =
             ChatGPTAuth.complete(
               %{"state" => state, "code" => "expired", "client_id" => "oaiapp_test"},
               state
             )

    assert [%{"id" => "oaiapp_test", "signed_in" => false}] = ChatGPTAuth.accounts()
    Agent.update(f.control, &%{&1 | error: nil})
    {params, state} = ChatGPTFixture.begin!(f, "oaiapp_test")
    assert params["client_id"] == "oaiapp_test"

    assert {:error, _} =
             ChatGPTAuth.complete(
               %{"state" => state, "code" => "test", "client_id" => "oaiapp_other"},
               state
             )

    {_, state} = ChatGPTFixture.begin!(f, "oaiapp_test")
    assert {:ok, _} = ChatGPTAuth.complete(%{"state" => state, "code" => "test"}, state)
    Agent.update(f.control, &%{&1 | subject: "another-user"})
    {_, state} = ChatGPTFixture.begin!(f, "oaiapp_test")
    assert {:error, message} = ChatGPTAuth.complete(%{"state" => state, "code" => "test"}, state)
    assert message =~ "identity differs"
    assert {:ok, "access-test-0"} = ChatGPTAuth.token("oaiapp_test")
  end

  test "checks JWT signature, issuer, audience, expiry and nonce", f do
    base = %{
      "iss" => "https://auth.openai.com",
      "sub" => "user",
      "aud" => "oaiapp_test",
      "exp" => System.system_time(:second) + 300,
      "nonce" => "nonce"
    }

    jwks = %{"keys" => [f.jwk]}
    valid = ChatGPTFixture.sign(f.key, base)
    assert ChatGPTAuth.verify_id_token!(valid, jwks, "oaiapp_test", "nonce") == base

    for claims <- [
          Map.put(base, "iss", "https://attacker"),
          Map.put(base, "aud", "other"),
          Map.put(base, "exp", 0),
          Map.put(base, "nonce", "other"),
          Map.put(base, "sub", ""),
          Map.put(base, "aud", ["oaiapp_test", "other"])
        ] do
      assert_raise RuntimeError, ~r/verification failed/, fn ->
        ChatGPTAuth.verify_id_token!(
          ChatGPTFixture.sign(f.key, claims),
          jwks,
          "oaiapp_test",
          "nonce"
        )
      end
    end

    wrong_key = JOSE.JWK.generate_key({:rsa, 2048})

    assert_raise RuntimeError, ~r/verification failed/, fn ->
      ChatGPTAuth.verify_id_token!(
        ChatGPTFixture.sign(wrong_key, base),
        jwks,
        "oaiapp_test",
        "nonce"
      )
    end
  end

  test "serializes rotating refreshes and clears revoked credentials while retaining registration",
       f do
    Agent.update(f.control, &%{&1 | expiry: 1})
    ChatGPTFixture.login!(f)

    results =
      1..3
      |> Task.async_stream(fn _ -> ChatGPTAuth.token("oaiapp_test") end, max_concurrency: 2)
      |> Enum.to_list()

    assert Enum.all?(results, &(&1 == {:ok, {:ok, "access-test-1"}}))
    assert Agent.get(f.control, & &1.refreshes) == 1

    assert_receive {:auth_request,
                    [
                      method: :post,
                      url: _,
                      retry: false,
                      redirect: false,
                      receive_timeout: _,
                      connect_options: _,
                      form: [
                        grant_type: "refresh_token",
                        client_id: "oaiapp_test",
                        refresh_token: "refresh-test-0",
                        resource: _
                      ]
                    ]}

    assert {:ok, _} = ChatGPTAuth.sign_out("oaiapp_test")
    assert Agent.get(f.control, & &1.revoked)
    assert {:error, _} = ChatGPTAuth.token("oaiapp_test")
    refute File.read!(f.path) =~ "access-test"
    refute File.read!(f.path) =~ "refresh-test"
    assert [%{"id" => "oaiapp_test", "signed_in" => false}] = ChatGPTAuth.accounts()
  end

  test "terminal refresh failure requires reauthorization and unsuccessful revocation is visible",
       f do
    Agent.update(f.control, &%{&1 | expiry: 1})
    ChatGPTFixture.login!(f)
    Agent.update(f.control, &%{&1 | error: "invalid_grant"})
    assert {:error, message} = ChatGPTAuth.token("oaiapp_test")
    assert message =~ "expired or was revoked"
    refute File.read!(f.path) =~ "refresh-test"
    Agent.update(f.control, &%{&1 | error: nil, expiry: 3600, revoke_error: true})
    ChatGPTFixture.login!(f, "oaiapp_second")
    assert {:error, message} = ChatGPTAuth.sign_out("oaiapp_second")
    assert message =~ "revocation was not confirmed"
    assert {:error, _} = ChatGPTAuth.token("oaiapp_second")
  end

  test "retains verified accounts without plan permission but never returns an inference token",
       f do
    Agent.update(f.control, &%{&1 | scope: "openid email offline_access"})
    ChatGPTFixture.login!(f)
    assert [%{"signed_in" => true, "plan_enabled" => false}] = ChatGPTAuth.accounts()
    assert {:error, message} = ChatGPTAuth.token("oaiapp_test")
    assert message =~ "plan usage is disabled"
    {params, _} = ChatGPTFixture.begin!(f, "oaiapp_test")
    assert params["prompt"] == "consent"
    assert params["client_id"] == "oaiapp_test"
    assert params["scope"] =~ "chatgpt.tokens.use.direct"
  end

  test "honors earliest renewal time and retains tokens after transient refresh errors", f do
    Agent.update(
      f.control,
      &%{&1 | expiry: 30, earliest_refresh_at: System.system_time(:second) + 15}
    )

    ChatGPTFixture.login!(f)
    assert {:ok, "access-test-0"} = ChatGPTAuth.token("oaiapp_test")
    assert Agent.get(f.control, & &1.refreshes) == 0
    Agent.update(f.control, &%{&1 | expiry: 1, earliest_refresh_at: nil})
    ChatGPTFixture.login!(f, "oaiapp_second")
    Agent.update(f.control, &%{&1 | error: "temporarily_unavailable"})
    assert {:error, _} = ChatGPTAuth.token("oaiapp_second")
    assert File.read!(f.path) =~ "refresh-test-0"
    Agent.update(f.control, &%{&1 | error: nil})
    assert {:ok, "access-test-2"} = ChatGPTAuth.token("oaiapp_second")
  end
end
