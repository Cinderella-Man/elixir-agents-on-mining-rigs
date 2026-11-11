defmodule Eab.ThinkingTest do
  use ExUnit.Case, async: true
  alias Eab.{Model, Thinking}

  defp endpoint(profile \\ %{}),
    do: %{"backend" => "llama_cpp", "context" => 32768, "profile" => profile}

  test "records every host preset, including enabled without a level and custom levels" do
    for effort <- ~w(off on low medium high xhigh max ultra default unsupported) do
      settings = Model.settings(endpoint(), %{"reasoning_effort" => effort})
      assert settings["reasoning_effort"] == effort
      assert settings["reasoning_effort_source"] == "operator_declared"
      assert settings["thinking_policy"] == "server_preset"
      assert Model.settings(endpoint(), settings) == settings
    end

    assert_raise ArgumentError, fn ->
      Model.settings(endpoint(), %{"reasoning_effort" => "not a preset"})
    end
  end

  test "uses explicit server metadata, never template capability flags or model names" do
    for {profile, expected} <- [
          {%{"reasoning_effort" => "max"}, "max"},
          {%{"chat_template_kwargs" => %{"enable_thinking" => false}}, "off"},
          {%{"chat_template_kwargs" => ~s({"enable_thinking":true})}, "on"},
          {%{
             "default_generation_settings" => %{
               "params" => %{"chat_template_kwargs" => %{"reasoning_effort" => "xhigh"}}
             }
           }, "xhigh"}
        ] do
      model = endpoint(profile)
      settings = Model.settings(model)
      assert settings["reasoning_effort"] == expected
      assert settings["reasoning_effort_source"] == "server_reported"
      assert Model.settings(model, settings) == settings
    end

    settings =
      Model.settings(endpoint(%{"chat_template_caps" => %{"supports_thinking" => true}}))

    assert settings["reasoning_effort"] == "unknown"
    assert settings["reasoning_effort_source"] == "not_reported"
    assert Thinking.label(settings) == "Not reported"
    assert Thinking.label(%{}) == "Not recorded"
    assert Model.settings(endpoint(), settings) == settings
  end

  test "removes Pi overrides while preserving reasoning history and unrelated request controls" do
    messages = [%{"role" => "assistant", "reasoning_content" => "earlier reasoning"}]

    body = %{
      "messages" => messages,
      "thinking" => %{"type" => "enabled", "budget_tokens" => 2048},
      "reasoning" => %{"effort" => "medium"},
      "reasoning_effort" => "medium",
      "reasoning_budget_tokens" => 2048,
      "output_config" => %{"effort" => "medium", "format" => "json"},
      "chat_template_kwargs" => %{
        "enable_thinking" => true,
        "reasoning_effort" => "medium",
        "other" => 1
      }
    }

    assert Thinking.payload(body, Model.settings(endpoint(), %{"reasoning_effort" => "off"})) ==
             %{
               "messages" => messages,
               "output_config" => %{"format" => "json"},
               "chat_template_kwargs" => %{"other" => 1}
             }

    assert Thinking.payload(body, %{}) == body
  end
end
