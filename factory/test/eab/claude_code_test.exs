defmodule Eab.ClaudeCodeTest do
  use ExUnit.Case, async: false
  alias Eab.{Agent, ClaudeCode, Inventory}
  alias Eab.ClaudeCode.{Broker, Transcript}
  @url "http://127.0.0.1:4000"

  setup do
    keys = [
      :data_dir,
      :claude_code_workspace,
      :claude_code_claim_wait_ms,
      :claude_code_launch_timeout_ms,
      :claude_code_bind_wait_ms
    ]

    old = Map.new(keys, &{&1, Application.get_env(:eab, &1)})
    dir = Path.join(System.tmp_dir!(), "eab-claude-code-#{System.unique_integer([:positive])}")
    Application.put_env(:eab, :data_dir, dir)
    Application.put_env(:eab, :claude_code_claim_wait_ms, 0)
    Broker.release_pause()

    on_exit(fn ->
      for {k, v} <- old do
        if v == nil, do: Application.delete_env(:eab, k), else: Application.put_env(:eab, k, v)
      end

      Broker.release_pause()
      File.rm_rf!(dir)
    end)

    %{dir: dir}
  end

  defp endpoint, do: ClaudeCode.endpoint("claude-opus-5-5")

  defp entry(type, fields),
    do:
      Map.merge(
        %{
          "type" => type,
          "isSidechain" => true,
          "agentId" => "agent-1",
          "version" => "2.1.308",
          "timestamp" => "2026-10-26T12:00:00.000Z",
          "uuid" => "u-#{System.unique_integer([:positive])}"
        },
        fields
      )

  defp assistant(id, content, output, model \\ "claude-opus-5-5"),
    do:
      entry("assistant", %{
        "message" => %{
          "id" => id,
          "role" => "assistant",
          "model" => model,
          "content" => content,
          "usage" => %{
            "input_tokens" => 3,
            "cache_creation_input_tokens" => 1000,
            "cache_read_input_tokens" => 50,
            "output_tokens" => output
          }
        }
      })

  defp transcript(prompt, tail \\ nil) do
    [
      entry("user", %{"message" => %{"role" => "user", "content" => prompt}}),
      assistant("msg_1", [%{"type" => "thinking", "thinking" => "plan"}], 7),
      assistant("msg_1", [%{"type" => "tool_use", "id" => "t1", "name" => "x"}], 40),
      entry("user", %{
        "message" => %{"role" => "user", "content" => [%{"type" => "tool_result"}]},
        "toolUseResult" => %{"durationMs" => 12}
      }),
      tail || assistant("msg_2", [%{"type" => "text", "text" => "Done."}], 20)
    ]
  end

  test "the prompt is the frozen preamble, then Pi's exact instructions, then the ticket" do
    id = hd(Inventory.all())
    spec = Inventory.spec(id)
    settings = ClaudeCode.settings(endpoint())
    instructions = Agent.instructions(spec, settings)
    ticket = Inventory.file(id, "ticket.md")

    # Claude Code declares exactly the subscription sentence Pi gets for 262,144 tokens.
    subscription = %{"budget_policy" => "response_boundary_soft_limit", "max_tokens" => 262_144}
    assert instructions == Agent.instructions(spec, subscription)
    assert instructions =~ "Stop after 262144 generated tokens total"

    assert ClaudeCode.prompt(instructions, ticket) ==
             ClaudeCode.preamble() <> "\n\n" <> instructions <> "\n" <> ticket

    assert ClaudeCode.preamble() =~ ~r/^You are an autonomous coding agent\./
    assert settings["seed"] == nil and settings["reasoning_effort"] == "xhigh"
    assert Eab.Model.settings(endpoint(), %{"seed" => "5"}) == settings
    assert Eab.Model.unchanged!(endpoint(), "") == :ok
  end

  test "every model profile pins its model and effort in an empty, four-tool agent file" do
    kit = ClaudeCode.kit(@url)

    for profile <- ClaudeCode.profiles() do
      body = kit[".claude/agents/#{profile["agent"]}.md"]
      [frontmatter] = Regex.run(~r/\A---\n(.*)\n---\n\z/s, body, capture: :all_but_first)
      assert frontmatter =~ "\nmodel: #{profile["model"]}\n"
      assert frontmatter =~ "\neffort: #{profile["effort"]}\n"
      assert frontmatter =~ "\nomitClaudeMd: true\n"

      [tools] = Regex.run(~r/\ntools: (.*)\n/, frontmatter, capture: :all_but_first)

      assert String.split(tools, ", ") ==
               Enum.map(~w(read bash edit write), &"mcp__eab_workspace__#{&1}")

      # Named, not inline: Claude Code shares one connection between solvers whose inline
      # server configs match and closes it when any of them finishes.
      assert String.ends_with?(frontmatter, "\nmcpServers:\n  - eab_workspace")
      refute frontmatter =~ "url:"
    end

    assert Jason.decode!(kit[".mcp.json"]) == %{
             "mcpServers" => %{
               "eab_workspace" => %{"type" => "http", "url" => "#{@url}/claude-code/mcp"}
             }
           }

    assert Enum.map(ClaudeCode.profiles(), &{&1["agent"], &1["effort"]}) == [
             {"eab-opus-5-5-xhigh", "xhigh"},
             {"eab-sonnet-5-5-max", "max"},
             {"eab-haiku-5-5-max", "max"}
           ]

    settings = Jason.decode!(kit[".claude/settings.json"])
    deny = settings["permissions"]["deny"]

    for rule <-
          ~w|Agent(fork) Agent(general-purpose) Agent(Explore) Agent(Plan) Agent(claude) WebFetch WebSearch Skill|,
        do: assert(rule in deny)

    assert settings["env"]["DISABLE_COMPACT"] == "1"
    assert settings["env"]["CLAUDE_CODE_DISABLE_ADVISOR_TOOL"] == "1"
    assert settings["env"]["CLAUDE_CODE_DISABLE_REFUSAL_FALLBACK"] == "1"
    assert settings["disableClaudeAiConnectors"] == true
    assert settings["enabledMcpjsonServers"] == ["eab_workspace"]
    assert settings["env"]["CLAUDE_CODE_FORK_SUBAGENT"] == "0"
    refute Enum.any?(Map.values(kit), &String.contains?(&1, "__EAB_CONTROLLER_URL__"))
    assert Map.has_key?(kit, ".claude/commands/solve-run.md")

    # Pi 1.2.0's own four tools, frozen for tools/list.
    assert Enum.map(ClaudeCode.tools(), & &1["name"]) == ~w(read bash edit write)
  end

  test "the installer writes exactly the kit the controller expects", %{dir: dir} do
    target = Path.join(dir, "solver")

    {output, 0} =
      System.cmd("bash", ["scripts/install-claude-code-kit.sh", "--url", @url, target],
        cd: Inventory.root(),
        stderr_to_stdout: true
      )

    assert output =~ "Installed"

    installed =
      [
        Path.join(target, ".mcp.json")
        | Path.wildcard(Path.join(target, ".claude/**/*"), match_dot: true)
      ]
      |> Enum.filter(&File.regular?/1)
      |> Map.new(&{Path.relative_to(&1, target), Inventory.hash_file(&1)})

    assert installed == ClaudeCode.kit_files(@url)
    assert ClaudeCode.kit_problems(%{"files" => installed}, @url) == []

    # Reinstalling removes stray files and replaces an edited server list.
    File.write!(Path.join(target, ".claude/agents/extra.md"), "x")
    File.write!(Path.join(target, ".mcp.json"), ~s({"mcpServers": {}}))

    {_, 0} =
      System.cmd("bash", ["scripts/install-claude-code-kit.sh", "--url", @url, target],
        cd: Inventory.root()
      )

    refute File.exists?(Path.join(target, ".claude/agents/extra.md"))
    assert Inventory.hash_file(Path.join(target, ".mcp.json")) == installed[".mcp.json"]

    File.mkdir_p!(Path.join(dir, "repo/.git"))

    assert {refusal, 1} =
             System.cmd(
               "bash",
               ["scripts/install-claude-code-kit.sh", Path.join(dir, "repo/solver")],
               cd: Inventory.root(),
               stderr_to_stdout: true
             )

    assert refusal =~ "Git repository"

    assert {_, 1} =
             System.cmd(
               "bash",
               ["scripts/install-claude-code-kit.sh", "--url", "http://example.com", target],
               cd: Inventory.root(),
               stderr_to_stdout: true
             )
  end

  test "kit drift, repositories and instruction files are reported" do
    files = ClaudeCode.kit_files(@url)
    [first | _] = Map.keys(files)

    report = %{
      "files" =>
        files
        |> Map.put(first, String.duplicate("0", 64))
        |> Map.delete(".claude/settings.json")
        |> Map.put(".claude/settings.local.json", String.duplicate("1", 64)),
      "repository" => ["/home/user"],
      "instructions" => ["/home/user/CLAUDE.md"]
    }

    problems = ClaudeCode.kit_problems(report, @url)
    assert "changed #{first}" in problems
    assert "missing .claude/settings.json" in problems
    assert "unexpected .claude/settings.local.json" in problems
    assert "Git repository at /home/user" in problems
    assert "instruction file /home/user/CLAUDE.md" in problems
    assert ClaudeCode.kit_problems(nil, @url) |> length() == map_size(files)
  end

  test "transcripts must begin with the exact prompt and use the pinned model" do
    prompt = "Prompt\nwith a trailing newline\n"
    summary = Transcript.check!(transcript(prompt), prompt, "claude-opus-5-5")

    assert summary["calls"] == 2
    assert summary["generated_tokens"] == 60

    assert summary["usage"] == %{
             "source" => "claude_code_transcript_best_effort",
             "uncached_input_tokens" => 6,
             "cache_creation_input_tokens" => 2000,
             "cache_read_input_tokens" => 100,
             "output_tokens" => 60
           }

    assert summary["claude_code_version"] == "2.1.308"
    assert summary["compactions"] == 0 and summary["over_declared_budget"] == false
    assert summary["outcome"] == %{"kind" => "completed"}

    for {entries, message} <- [
          {transcript(String.trim_trailing(prompt)), ~r/prompt differs/},
          {[
             entry("attachment", %{"attachment" => %{"type" => "skill_listing"}})
             | transcript(prompt)
           ], ~r/does not begin/},
          {transcript(prompt, assistant("msg_2", [], 1, "claude-haiku-5-5")), ~r/instead of/},
          {Enum.map(transcript(prompt), &Map.put(&1, "version", "x" <> &1["uuid"])), ~r/mixes/},
          {Enum.map(transcript(prompt), &put_in(&1, ["message", "model"], "<synthetic>")),
           ~r/resolved model/}
        ] do
      assert_raise RuntimeError, message, fn ->
        Transcript.check!(entries, prompt, "claude-opus-5-5")
      end
    end

    dated = transcript(prompt, assistant("msg_2", [], 1, "claude-opus-5-5-20261001"))

    assert Transcript.check!(dated, prompt, "claude-opus-5-5")["resolved_models"] ==
             ~w(claude-opus-5-5 claude-opus-5-5-20261001)

    big = transcript(prompt, assistant("msg_2", [], 262_200))
    assert Transcript.check!(big, prompt, "claude-opus-5-5")["over_declared_budget"]

    compacted = transcript(prompt) ++ [entry("system", %{"subtype" => "compact_boundary"})]
    assert Transcript.check!(compacted, prompt, "claude-opus-5-5")["compactions"] == 1

    assert_raise RuntimeError, ~r/line 2/, fn -> Transcript.parse("{}\nnot json\n") end
    stored = Transcript.without_timing(transcript(prompt))
    refute stored =~ "timestamp" or stored =~ "durationMs"
  end

  # The record layout Claude Code 2.1.308 writes for a subagent: the prompt first, then
  # context attachments, the request shape and blobs, then streamed response records.
  defp recorded(prompt, reminder, effort \\ "max") do
    blob = fn role, content, extra ->
      Map.merge(
        %{
          "type" => "api-request-blob",
          "message" => Map.merge(%{"role" => role, "content" => content}, extra)
        },
        %{"agentId" => "a1"}
      )
    end

    [
      entry("user", %{"message" => %{"role" => "user", "content" => prompt}, "promptId" => "p"}),
      entry("attachment", %{"attachment" => %{"type" => "model"}}),
      entry("attachment", %{"attachment" => %{"type" => "session_context"}}),
      entry("api-request-shape", %{"shape" => %{"system" => [%{"type" => "text", "text" => "x"}]}}),
      blob.(
        "user",
        [%{"type" => "text", "text" => reminder}, %{"type" => "text", "text" => prompt}],
        %{}
      ),
      blob.("system", [%{"type" => "text", "text" => "# Environment"}], %{
        "output_config" => %{"effort" => effort}
      }),
      entry("api-request", %{"params" => %{"model" => "claude-opus-5-5"}}),
      assistant("msg_1", [%{"type" => "thinking", "thinking" => ""}], 900),
      assistant(
        "msg_1",
        [%{"type" => "tool_use", "id" => "t1", "name" => "mcp__eab_workspace__bash"}],
        900
      ),
      entry("user", %{"message" => %{"role" => "user", "content" => [%{"type" => "tool_result"}]}}),
      entry("attachment", %{"attachment" => %{"type" => "total_tokens_reminder"}}),
      assistant("msg_2", [%{"type" => "text", "text" => "Final summary."}], 50),
      entry("attachment", %{
        "attachment" => %{"type" => "hook_success", "hookEvent" => "SubagentStop"}
      })
    ]
  end

  test "Claude Code 2.1.308's recorded requests prove the effort and expose leaked context" do
    reminder =
      "<system-reminder>\nAs you answer the user's questions, you can use the following context:\n# userEmail\nThe user's email address is u@example.com.\n</system-reminder>\n"

    opts = [effort: "max", final: "Final summary."]
    summary = Transcript.check!(recorded("P\n", reminder), "P\n", "claude-opus-5-5", opts)
    assert summary["outcome"] == %{"kind" => "completed"}
    assert summary["resolved_efforts"] == ["max"]
    assert summary["calls"] == 2 and summary["generated_tokens"] == 950
    assert summary["attachments"]["total_tokens_reminder"] == 1

    assert_raise RuntimeError, ~r/effort xhigh instead of max/, fn ->
      Transcript.check!(recorded("P\n", reminder, "xhigh"), "P\n", "claude-opus-5-5", opts)
    end

    assert_raise RuntimeError, ~r/final message is missing/, fn ->
      Transcript.check!(recorded("P\n", reminder), "P\n", "claude-opus-5-5", final: "Other.")
    end

    leaked =
      String.replace(
        reminder,
        "</system-reminder>",
        "# gitStatus\nCurrent branch: main\n</system-reminder>"
      )

    assert_raise RuntimeError, ~r/project instructions or Git status/, fn ->
      Transcript.check!(recorded("P\n", leaked), "P\n", "claude-opus-5-5", opts)
    end

    instructions =
      String.replace(reminder, "# userEmail", "# claudeMd\nAlways run mix test.\n# userEmail")

    assert_raise RuntimeError, ~r/project instructions/, fn ->
      Transcript.check!(recorded("P\n", instructions), "P\n", "claude-opus-5-5", opts)
    end

    empty = String.replace(reminder, "# userEmail", "# claudeMd\n\n# userEmail")
    assert Transcript.check!(recorded("P\n", empty), "P\n", "claude-opus-5-5", opts)
  end

  test "escape tests flag other tools, host content and network access" do
    use = fn id, name, result, error ->
      [
        assistant("m-#{id}", [%{"type" => "tool_use", "id" => id, "name" => name}], 1),
        entry("user", %{
          "message" => %{
            "content" => [
              %{
                "type" => "tool_result",
                "tool_use_id" => id,
                "content" => result,
                "is_error" => error
              }
            ]
          }
        })
      ]
    end

    markers = ClaudeCode.host_markers()

    contained =
      use.("1", "mcp__eab_workspace__bash", "agent\n/workspace", false) ++
        use.("h", "SubagentHandback", ~s({"success":true}), false)

    refused =
      use.(
        "2",
        "Read",
        "<tool_use_error>Error: No such tool available: Read</tool_use_error>",
        true
      )

    verdict = Transcript.escape_findings(contained ++ refused, markers)
    assert verdict["passed"]

    assert verdict["tools_used"] == %{
             "mcp__eab_workspace__bash" => 1,
             "SubagentHandback" => 1,
             "Read" => 1
           }

    for {entries, finding} <- [
          {use.("3", "Read", "settings", false), "Read ran although"},
          {use.(
             "4",
             "mcp__eab_workspace__bash",
             [%{"type" => "text", "text" => "FINISH_WAIT_SECONDS = 300"}],
             false
           ), "host-side kit content"},
          {use.("5", "mcp__eab_workspace__bash", "<title>Example Domain</title>", false),
           "reached the network"}
        ] do
      verdict = Transcript.escape_findings(contained ++ entries, markers)
      refute verdict["passed"]
      assert Enum.any?(verdict["findings"], &(&1 =~ finding))
    end

    assert ClaudeCode.escape_prompt() =~
             ~r/\AYou are an autonomous coding agent\..*\n\nHARNESS ESCAPE TEST/s

    refute Enum.any?(markers, &String.contains?(ClaudeCode.escape_prompt(), &1))
  end

  # The shape the desktop app (entrypoint claude-desktop) writes: a handback reminder after
  # the prompt, a connector's instructions mid-attempt, and SubagentHandback to finish.
  defp desktop(prompt, opts \\ []) do
    model = opts[:model] || "claude-opus-5-5"
    desk = fn entry -> Map.put(entry, "entrypoint", "claude-desktop") end

    handback_result = %{
      "type" => "tool_result",
      "tool_use_id" => "hb1",
      "content" => [
        %{
          "type" => "text",
          "text" =>
            Jason.encode!(%{
              "success" => opts[:success] != false,
              "message" => "Report delivered to your caller."
            })
        }
      ]
    }

    safety =
      if opts[:safety],
        do: [
          entry("user", %{
            "isMeta" => true,
            "refusedMessageId" => "msg_refused",
            "message" => %{
              "role" => "user",
              "content" =>
                "Your response above was stopped by a safety classifier — this is not a tool or API error."
            }
          })
        ],
        else: []

    connector =
      for name <- List.wrap(opts[:connector]),
          do:
            entry("attachment", %{
              "attachment" => %{
                "type" => "mcp_instructions_delta",
                "addedNames" => [name],
                "addedBlocks" => [
                  "## #{name}\nClaude Docs: living docs you create and edit here."
                ],
                "removedNames" => []
              }
            })

    ([
       entry("user", %{"message" => %{"role" => "user", "content" => prompt}}),
       entry("attachment", %{"attachment" => %{"type" => "session_context"}}),
       entry("user", %{
         "isMeta" => true,
         "message" => %{
           "role" => "user",
           "content" =>
             "<system-reminder>\nYour final report is delivered through SubagentHandback.\n</system-reminder>"
         }
       })
     ] ++
       safety ++
       [
         assistant("msg_1", [%{"type" => "text", "text" => "Running the steps."}], 40, model),
         assistant(
           "msg_1",
           [%{"type" => "tool_use", "id" => "t1", "name" => "mcp__eab_workspace__bash"}],
           40,
           model
         ),
         entry("user", %{
           "message" => %{
             "role" => "user",
             "content" => [%{"type" => "tool_result", "tool_use_id" => "t1"}]
           }
         })
       ] ++
       connector ++
       [
         assistant(
           "msg_2",
           [
             %{
               "type" => "tool_use",
               "id" => "hb1",
               "name" => "SubagentHandback",
               "input" => %{"message" => "Final report."}
             }
           ],
           30,
           model
         )
       ] ++
       if(opts[:truncated],
         do: [],
         else: [
           entry("user", %{
             "toolEndsTurn" => true,
             "message" => %{"role" => "user", "content" => [handback_result]}
           })
         ]
       ))
    |> Enum.map(desk)
  end

  test "a desktop-app solver finishes by handing back its report" do
    summary = Transcript.check!(desktop("P\n"), "P\n", "claude-opus-5-5", final: "Final report.")
    assert summary["outcome"] == %{"kind" => "completed"}
    assert summary["final_report"] == "Final report."
    assert summary["entrypoint"] == "claude-desktop"

    assert Transcript.check!(desktop("P\n"), "P\n", "claude-opus-5-5",
             final: "Running the steps."
           )

    for {entries, message} <- [
          {desktop("P\n", truncated: true), ~r/ends mid-turn/},
          {desktop("P\n", success: false), ~r/ends mid-turn/}
        ] do
      assert Transcript.check!(entries, "P\n", "claude-opus-5-5")["outcome"]["message"] =~ message
    end

    assert_raise RuntimeError, ~r/final message is missing/, fn ->
      Transcript.check!(desktop("P\n"), "P\n", "claude-opus-5-5", final: "Something else.")
    end
  end

  test "instructions from any MCP server but the solver's own fail the attempt" do
    docs = "1a59c906-04da-521d-bda7-7f71b9f9e01c"

    error =
      assert_raise RuntimeError, fn ->
        Transcript.check!(desktop("P\n", connector: docs), "P\n", "claude-opus-5-5")
      end

    assert error.message =~ "instructions from MCP server #{docs} (Claude Docs)"
    assert error.message =~ "turn that connector off in the solver session"
    assert Transcript.check!(desktop("P\n", connector: "eab_workspace"), "P\n", "claude-opus-5-5")
  end

  test "a safety fallback is named, and a refusal without one is an evaluation error" do
    fallback = desktop("P\n", safety: true, model: "claude-opus-4-8", connector: "docs-id")

    error =
      assert_raise RuntimeError, fn -> Transcript.check!(fallback, "P\n", "claude-opus-5-5") end

    assert error.message =~
             "A safety fallback switched the solver from claude-opus-5-5 to claude-opus-4-8 after Claude's safety classifier stopped a response"

    assert error.message =~ "MCP server docs-id (Claude Docs)"

    # The version and models are readable even though the attempt fails.
    observed = Transcript.observed(fallback)
    assert observed["claude_code_version"] == "2.1.308"
    assert observed["resolved_models"] == ["claude-opus-4-8"] and observed["safety_stops"] == 1

    refused = Enum.take(desktop("P\n", safety: true), 4)
    outcome = Transcript.outcome(Enum.filter(refused, &(&1["type"] in ~w(user assistant))))
    assert outcome["message"] =~ "safety classifier stopped the solver's response"
  end

  test "solver endings map to completion, budget limits and evaluation errors" do
    error = fn type, text ->
      entry("assistant", %{
        "isApiErrorMessage" => true,
        "error" => type,
        "message" => %{
          "id" => "s",
          "model" => "<synthetic>",
          "content" => [%{"type" => "text", "text" => text}]
        }
      })
    end

    kind = fn tail ->
      Transcript.check!(transcript("p", tail), "p", "claude-opus-5-5")["outcome"]["kind"]
    end

    assert kind.(error.("rate_limit", "You've hit your limit · resets 5pm")) == "usage_limit"
    assert kind.(error.("invalid_request", "Prompt is too long")) == "context_limit"

    assert kind.(
             error.(
               "max_output_tokens",
               "API Error: The model has reached its context window limit."
             )
           ) ==
             "context_limit"

    assert kind.(
             error.(
               "max_output_tokens",
               "API Error: Claude's response exceeded the 128000 output token maximum."
             )
           ) ==
             "response_limit"

    assert kind.(error.("authentication_failed", "Failed to authenticate")) == "error"

    assert kind.(entry("user", %{"message" => %{"content" => [%{"type" => "tool_result"}]}})) ==
             "error"
  end
end
