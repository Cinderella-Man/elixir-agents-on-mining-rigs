defmodule Eab.BenchParityTest do
  @moduledoc """
  What the model sees and what a pass means stay the bench's (factory/README.md, section 2). Every expected value
  here was taken from the unchanged copy of the bench's engine, Cinderella-Man/elixir-swe-bench at commit
  28c064ca86108d550a6dcb693c751df21a18b736, by job T0.

  Two kinds of edit to this file are expected, and no other:
  - an input is rewritten in a new format when a job changes that format (job T5: the one task format), and the
    expected output stays byte for byte;
  - `@name_prefix`, `@installation_label` and `@run_label` take the factory's own names (section 6, change 6).

  Job T5 removed two expected texts, the bench's text for a task whose added tests are optional and its text for a
  refactor: the one format cannot express those inputs (`model_tests` is always "behavioral" and `refactor` is not
  a kind), so no model can ever be shown those texts. It added the text for a `feature`, captured from the unchanged
  copy (public commit 470301e) with job T0's capture script and this job's `parity_capture_feature.exs`
  (docs/data/2026-11-12_factory_t5/run/). That text has requirement lines: the bench's format needs at least one
  for a feature, so a feature text without them cannot come from the unchanged copy.
  """
  use ExUnit.Case, async: false

  @root Path.expand("../..", __DIR__)

  # Files that keep the bench's bytes, with their Git blob ids.
  @same_bytes %{
    "lib/eab/pi.ex" => "c087a89c6b57bb1998a7cd0799611f4851a8488b",
    "lib/eab/thinking.ex" => "db329d80205f25ae57cefe7c4fe3cc16cd291eb2",
    "priv/fixtures/build_seed.exs" => "caafd335f6539ddd30f5d6905270c659dd04945e",
    # The bench's bytes were ea8dec71fe1becbc6e4a34698d3693e7d93051c7. The one change (registry E88) adds the
    # parameters to the name of a test run under `parameterize:`; every other test's record is the bench's, byte for
    # byte (test/eab/grader_test.exs), and the model never sees this file (it is copied into grading containers only).
    "priv/fixtures/grade_formatter.exs" => "75eed3126e2338224dd8b9ec934822f15b0138ca",
    "priv/pi/bash-watchdog.mjs" => "a424def5963621c0f6e450a46c153117e9173c43",
    "priv/pi/bridge.mjs" => "7c26c2f0b5ae9de37f0c516e1536d5a8c1ef5d6d",
    "priv/pi/package-lock.json" => "1835860d59a282f9d57c52fd6af70fad9ab6bbdd",
    "priv/pi/package.json" => "4085058d01669b6f4acc6c6633be2bf393565168",
    "priv/pi/runtime.json" => "22cb0bcb3951897e81045bee675dfd9f9ebd37f8"
  }

  # The names the factory replaces with its own (section 6, change 6).
  @name_prefix "etf-"
  @installation_label "etf.installation"
  @run_label "etf.run"

  @settings %{
    "compaction" => false,
    "max_tokens" => 65536,
    "reasoning_effort" => "unknown",
    "reasoning_effort_source" => "not_reported",
    "response_tokens" => 8192,
    "safety_tokens" => 8,
    "seed" => 101,
    "thinking_policy" => "server_preset",
    "window_tokens" => 262_144
  }

  @bug_fix_text ~S"""
  Complete the bug_fix task in /workspace. Investigate the source and run the relevant tests.
  Test command: mix test test/widget_test.exs.
  Add or change a test that fails in its test body on the starting source and passes after your change. Compilation/setup failures do not count.

  Dependencies are prepared. The workspace is offline. Preserve existing behavior and do not weaken tests.

  Allowed edit prefixes: lib/, test/.
  When finished, give a short summary. Your current patch is then checked in a fresh workspace.
  Model and tool calls are unlimited. Limits: 65536 generated tokens total, 262144 context tokens including up to 8192 response tokens.
  History is never compacted. If a budget is exhausted, the current patch is graded.
  Task details: {}
  """

  @requirements_text ~S"""
  Complete the bug_fix task in /workspace. Investigate the source and run the relevant tests.
  Test command: mix test.
  Add or change a test that fails in its test body on the starting source and passes after your change. Compilation/setup failures do not count.
  Required outcome (R1): Totals round half up to two places.
  Required outcome (R2): An empty order totals zero.
  Dependencies are prepared. The workspace is offline. Preserve existing behavior and do not weaken tests.

  Allowed edit prefixes: lib/.
  When finished, give a short summary. Your current patch is then checked in a fresh workspace.
  Model and tool calls are unlimited. Limits: 65536 generated tokens total, 262144 context tokens including up to 8192 response tokens.
  History is never compacted. If a budget is exhausted, the current patch is graded.
  Task details: {"rounding":"Half up, to two places."}
  """

  @feature_text ~S"""
  Complete the feature task in /workspace. Investigate the source and run the relevant tests.
  Test command: mix test.
  Add or change a test that fails in its test body on the starting source and passes after your change. Compilation/setup failures do not count.
  Required outcome (R1): Totals round half up to two places.
  Required outcome (R2): An empty order totals zero.
  Dependencies are prepared. The workspace is offline. Preserve existing behavior and do not weaken tests.

  Allowed edit prefixes: lib/.
  When finished, give a short summary. Your current patch is then checked in a fresh workspace.
  Model and tool calls are unlimited. Limits: 65536 generated tokens total, 262144 context tokens including up to 8192 response tokens.
  History is never compacted. If a budget is exhausted, the current patch is graded.
  Task details: {"rounding":"Half up, to two places."}
  """

  @plain_recipe ~S"""
  FROM hexpm/elixir:1.18.4-erlang-28.0.2-ubuntu-noble-20250714 AS toolchain
  USER root
  RUN if command -v apk; then apk add --no-cache git bash ca-certificates build-base brotli libstdc++ cmake grep ripgrep coreutils findutils diffutils; else apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git bash ca-certificates build-essential brotli cmake grep ripgrep coreutils findutils diffutils && rm -rf /var/lib/apt/lists/*; fi
  RUN if command -v useradd; then existing=$(getent passwd 1000 | cut -d: -f1); groupadd -f agent; if [ -n "$existing" ]; then usermod -l agent -d /home/agent -m -g agent "$existing"; else useradd -m -u 1000 -g agent agent; fi; else adduser -D -u 1000 agent; fi
  WORKDIR /workspace
  RUN mkdir -p /opt/mix /opt/hex /opt/eab-seed && chown agent:agent /workspace /opt/mix /opt/hex /opt/eab-seed
  USER agent
  ENV ERL_FLAGS="+S 2:2"
  ENV HEX_HOME="/opt/hex"
  ENV MIX_ENV="test"
  ENV MIX_HOME="/opt/mix"
  RUN mix local.hex 2.5.3 --force && mix local.rebar --force
  FROM toolchain AS prepared
  COPY --chown=agent:agent build_seed.exs /opt/eab-build-seed.exs
  COPY --chown=agent:agent source/ /incoming/
  RUN elixir -r /opt/eab-build-seed.exs -e 'Eab.FixtureSeed.sync("/incoming", "/workspace")'
  RUN --mount=type=cache,id=eab-hex-packages-v1,target=/opt/hex/packages,sharing=locked,uid=1000,gid=1000 mix deps.get --only test
  RUN elixir -r /opt/eab-build-seed.exs -S mix eab.seed
  RUN --mount=type=cache,id=eab-hex-packages-v1,target=/opt/hex/packages,sharing=locked,uid=1000,gid=1000 mix deps.get --only test && mix deps.clean --unused
  RUN mix deps.loadpaths
  RUN rm -rf .git && git init && git config user.name Benchmark && git config user.email benchmark@localhost && git add . && git commit -m 'Initial task workspace'
  FROM toolchain AS fixture
  COPY --from=prepared --chown=agent:agent /workspace/ /workspace/
  COPY --from=prepared --chown=agent:agent /opt/eab-seed/ /opt/eab-seed/
  CMD ["sleep", "infinity"]
  """

  @node_recipe ~S"""
  FROM example/node:22 AS nodejs
  FROM hexpm/elixir:1.13.4-erlang-24.3.4-alpine-3.15.3 AS toolchain
  USER root
  RUN if command -v apk; then apk add --no-cache git bash ca-certificates build-base brotli libstdc++ cmake grep ripgrep coreutils findutils diffutils; else apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git bash ca-certificates build-essential brotli cmake grep ripgrep coreutils findutils diffutils && rm -rf /var/lib/apt/lists/*; fi
  RUN if command -v useradd; then existing=$(getent passwd 1000 | cut -d: -f1); groupadd -f agent; if [ -n "$existing" ]; then usermod -l agent -d /home/agent -m -g agent "$existing"; else useradd -m -u 1000 -g agent agent; fi; else adduser -D -u 1000 agent; fi
  COPY --from=nodejs /usr/local/bin/node /usr/local/bin/node
  COPY --from=nodejs /usr/local/lib/node_modules /usr/local/lib/node_modules
  RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
  WORKDIR /workspace
  RUN mkdir -p /opt/mix /opt/hex /opt/eab-seed && chown agent:agent /workspace /opt/mix /opt/hex /opt/eab-seed
  USER agent
  ENV ERL_FLAGS="+S 2:2"
  ENV HEX_HOME="/opt/hex"
  ENV MIX_ENV="test"
  ENV MIX_HOME="/opt/mix"
  ENV WIDGET_MODE="strict"
  RUN mix archive.install https://builds.hex.pm/installs/1.13.0/hex-2.5.3.ez --sha512 a096b3c82cea512cba884f5f86d0b623389b13cac3dcbd5afe571fa73a7850fe40353c5e1f0deff0123dcced25b31e6c6c5390d2a8695cbcb77a467c56d17a7c --force && mix local.rebar --force
  FROM toolchain AS prepared
  COPY --chown=agent:agent build_seed.exs /opt/eab-build-seed.exs
  COPY --chown=agent:agent source/ /incoming/
  RUN elixir -r /opt/eab-build-seed.exs -e 'Eab.FixtureSeed.sync("/incoming", "/workspace")'
  RUN --mount=type=cache,id=eab-hex-packages-v1,target=/opt/hex/packages,sharing=locked,uid=1000,gid=1000 mix deps.get --only test
  RUN elixir -r /opt/eab-build-seed.exs -S mix eab.seed
  RUN --mount=type=cache,id=eab-hex-packages-v1,target=/opt/hex/packages,sharing=locked,uid=1000,gid=1000 mix deps.get --only test && mix deps.clean --unused
  RUN mix deps.loadpaths
  RUN mix compile
  RUN rm -rf .git && git init && git config user.name Benchmark && git config user.email benchmark@localhost && git add . && git commit -m 'Initial task workspace'
  FROM toolchain AS fixture
  COPY --from=prepared --chown=agent:agent /workspace/ /workspace/
  COPY --from=prepared --chown=agent:agent /opt/eab-seed/ /opt/eab-seed/
  CMD ["sleep", "infinity"]
  """

  @seeded_recipe ~S"""
  FROM example/node:22 AS nodejs
  FROM example/toolchain:1 AS toolchain
  FROM toolchain AS prepared
  COPY --from=example/seed:1 --chown=agent:agent /workspace/ /workspace/
  COPY --from=example/seed:1 --chown=agent:agent /opt/eab-seed/ /opt/eab-seed/
  COPY --chown=agent:agent build_seed.exs /opt/eab-build-seed.exs
  COPY --chown=agent:agent source/ /incoming/
  RUN elixir -r /opt/eab-build-seed.exs -e 'Eab.FixtureSeed.sync("/incoming", "/workspace")'
  RUN --mount=type=cache,id=eab-hex-packages-v1,target=/opt/hex/packages,sharing=locked,uid=1000,gid=1000 mix deps.get --only test
  RUN elixir -r /opt/eab-build-seed.exs -S mix eab.seed
  RUN --mount=type=cache,id=eab-hex-packages-v1,target=/opt/hex/packages,sharing=locked,uid=1000,gid=1000 mix deps.get --only test && mix deps.clean --unused
  RUN mix deps.loadpaths
  RUN mix compile
  COPY --chown=agent:agent force-add.txt /opt/eab-force-add.txt
  RUN rm -rf .git && git init && git config user.name Benchmark && git config user.email benchmark@localhost && git add . && GIT_LITERAL_PATHSPECS=1 git add -f --pathspec-from-file=/opt/eab-force-add.txt --pathspec-file-nul && git commit -m 'Initial task workspace'
  FROM toolchain AS fixture
  COPY --from=prepared --chown=agent:agent /workspace/ /workspace/
  COPY --from=prepared --chown=agent:agent /opt/eab-seed/ /opt/eab-seed/
  CMD ["sleep", "infinity"]
  """

  test "the files that keep the bench's bytes keep their blob ids" do
    for {path, id} <- @same_bytes do
      assert {path, blob_id(path)} == {path, id}
    end
  end

  test "the budgets are the bench's for both local back ends" do
    assert Eab.Model.settings(llama()) == @settings
    assert Eab.Model.settings(strata()) == @settings
  end

  test "the fixed instruction sentences give the bench's text, byte for byte" do
    assert Eab.Agent.instructions(plain_spec(), @settings) == @bug_fix_text
    assert Eab.Agent.instructions(contract_spec("bug_fix"), @settings) == @requirements_text
    assert Eab.Agent.instructions(contract_spec("feature"), @settings) == @feature_text
  end

  test "Pi's configuration is the bench's for llama.cpp and Strata" do
    settings = %{
      "cacheWarming" => "off",
      "compaction" => %{"enabled" => false},
      "defaultProjectTrust" => "never",
      "httpIdleTimeoutMs" => 1_260_000,
      "images" => %{"blockImages" => true},
      "retry" => %{"enabled" => false, "provider" => %{"maxRetries" => 0}},
      "shellPath" => "/opt/pi/bash-watchdog.mjs"
    }

    model = fn id ->
      %{
        "contextWindow" => 262_144,
        "cost" => %{"cacheRead" => 0, "cacheWrite" => 0, "input" => 0, "output" => 0},
        "id" => id,
        "input" => ["text"],
        "maxTokens" => 8192,
        "name" => id,
        "reasoning" => true
      }
    end

    assert Eab.Pi.config(llama(), @settings, "Fix the widget totals.\n", @bug_fix_text) == %{
             "api_prefix" => "/v1",
             "bash_timeout_seconds" => 1200,
             "instructions" => @bug_fix_text,
             "model" => "widget-coder",
             "models" => %{
               "providers" => %{
                 "benchmark" => %{
                   "api" => "openai-completions",
                   "apiKey" => "local-transport",
                   "compat" => %{
                     "maxTokensField" => "max_tokens",
                     "supportsDeveloperRole" => false,
                     "supportsReasoningEffort" => false,
                     "supportsStore" => false,
                     "supportsUsageInStreaming" => true
                   },
                   "models" => [model.("widget-coder")]
                 }
               }
             },
             "prompt" => "Fix the widget totals.\n",
             "provider" => "benchmark",
             "settings" => settings
           }

    assert Eab.Pi.config(strata(), @settings, "Fix the widget totals.\n", @bug_fix_text) == %{
             "api_prefix" => "",
             "bash_timeout_seconds" => 1200,
             "instructions" => @bug_fix_text,
             "model" => "widget-pack",
             "models" => %{
               "providers" => %{
                 "benchmark" => %{
                   "api" => "anthropic-messages",
                   "apiKey" => "local-transport",
                   "compat" => %{
                     "allowEmptySignature" => true,
                     "supportsCacheControlOnTools" => false,
                     "supportsEagerToolInputStreaming" => false
                   },
                   "models" => [model.("widget-pack")]
                 }
               }
             },
             "prompt" => "Fix the widget totals.\n",
             "provider" => "benchmark",
             "settings" => settings
           }
  end

  test "the workspace recipe is the bench's" do
    plain = %{
      "runtime" => %{"image" => "hexpm/elixir:1.18.4-erlang-28.0.2-ubuntu-noble-20250714"}
    }

    assert Eab.Fixtures.dockerfile(plain, plain["runtime"]["image"]) == @plain_recipe

    assert Eab.Fixtures.dockerfile(
             node_spec(),
             node_spec()["runtime"]["image"],
             "example/node:22"
           ) ==
             @node_recipe

    assert Eab.Fixtures.dockerfile(node_spec(), "example/elixir:1.13", "example/node:22",
             toolchain: "example/toolchain:1",
             seed: "example/seed:1",
             force_add: true
           ) == @seeded_recipe
  end

  test "the workspace and its databases start under the bench's limits" do
    labels = [
      "--label",
      "#{@installation_label}=<installation>",
      "--label",
      "#{@run_label}=parity-run"
    ]

    services = %{"postgres" => "example/postgres:16", "clickhouse" => "example/clickhouse:25"}
    spec = %{"runtime" => %{"before_test_commands" => ["mix ecto.reset"]}}

    {name, calls} =
      docker_calls(%{"image" => "example/workspace:1", "services" => services}, spec)

    assert name =~ ~r/\A#{Regex.escape(@name_prefix)}[0-9a-f]{16}\z/

    assert calls == [
             ["run", "-d", "--name", "<name>-db", "--network=none", "--memory=1g", "--cpus=1"] ++
               labels ++ ["-e", "POSTGRES_PASSWORD=postgres", "example/postgres:16"],
             [
               "exec",
               "<name>-db",
               "sh",
               "-c",
               "for i in $(seq 1 60); do pg_isready -h 127.0.0.1 -U postgres && exit 0; sleep 1; done; exit 1"
             ],
             [
               "run",
               "-d",
               "--name",
               "<name>-ch",
               "--network=container:<name>-db",
               "--memory=3g",
               "--cpus=2",
               "--ulimit",
               "nofile=262144:262144"
             ] ++ labels ++ ["-e", "CLICKHOUSE_SKIP_USER_SETUP=1", "example/clickhouse:25"],
             [
               "exec",
               "<name>-ch",
               "sh",
               "-c",
               "for i in $(seq 1 90); do clickhouse-client --query 'SELECT 1' && exit 0; sleep 1; done; exit 1"
             ],
             [
               "run",
               "-d",
               "--name",
               "<name>",
               "--init",
               "--network=container:<name>-db",
               "--cap-drop=ALL",
               "--security-opt=no-new-privileges",
               "--memory=4g",
               "--cpus=2",
               "--pids-limit=512",
               "--tmpfs=/tmp:rw,nosuid,size=512m"
             ] ++ labels ++ ["example/workspace:1"],
             [
               "exec",
               "-w",
               "/workspace",
               "<name>",
               "timeout",
               "-k",
               "5",
               "240",
               "bash",
               "-lc",
               "mix ecto.reset"
             ],
             ["rm", "-f", "-v", "<name>"],
             ["rm", "-f", "-v", "<name>-ch"],
             ["rm", "-f", "-v", "<name>-db"]
           ]

    {_, calls} =
      docker_calls(%{"image" => "example/workspace:1", "services" => %{}}, %{"runtime" => %{}})

    assert calls == [
             [
               "run",
               "-d",
               "--name",
               "<name>",
               "--init",
               "--network=none",
               "--cap-drop=ALL",
               "--security-opt=no-new-privileges",
               "--memory=4g",
               "--cpus=2",
               "--pids-limit=512",
               "--tmpfs=/tmp:rw,nosuid,size=512m"
             ] ++ labels ++ ["example/workspace:1"],
             ["rm", "-f", "-v", "<name>"],
             ["rm", "-f", "-v", "<name>-ch"],
             ["rm", "-f", "-v", "<name>-db"]
           ]
  end

  defp blob_id(path) do
    body = File.read!(Path.join(@root, path))
    :crypto.hash(:sha, "blob #{byte_size(body)}\0" <> body) |> Base.encode16(case: :lower)
  end

  defp llama do
    %{
      "backend" => "llama_cpp",
      "model" => "widget-coder",
      "context" => 262_144,
      "url" => "http://model.invalid:8080",
      "profile" => %{"chat_template_caps" => %{"supports_thinking" => true}}
    }
  end

  defp strata do
    %{
      "backend" => "strata",
      "model" => "widget-pack",
      "context" => 262_144,
      "url" => "http://model.invalid:8081"
    }
  end

  # The task inputs below are in the one format (job T5); the expected texts above are the bench's.
  # A training task as the bundle maker writes it: no requirement sentences and no clarifications.
  defp plain_spec do
    %{
      "schema_version" => 3,
      "task_kind" => "bug_fix",
      "allowed_edit_prefixes" => ["lib/", "test/"],
      "acceptance_patch" => "reference-tests.patch",
      "partial_control" => %{"present" => false, "reason" => "single_hunk"},
      "grading" => %{
        "adapter" => "exunit",
        "acceptance" => "mix test test/widget_extra_test.exs",
        "preservation" => "mix test test/widget_test.exs",
        "protected_paths" => ["test/"],
        "test_suffixes" => ["_test.exs"],
        "required" => ["test/widget_extra_test.exs:4"],
        "starting_failures" => ["test/widget_extra_test.exs:4"],
        "model_tests" => "behavioral"
      }
    }
  end

  # The two optional fields of the one format that the bench's prompt uses, filled: requirement sentences and
  # clarifications.
  defp contract_spec(kind) do
    %{
      "schema_version" => 3,
      "task_kind" => kind,
      "allowed_edit_prefixes" => ["lib/"],
      "acceptance_patch" => "reference-tests.patch",
      "partial_control" => %{"present" => true},
      "clarifications" => %{"rounding" => "Half up, to two places."},
      "grading" => %{
        "adapter" => "exunit",
        "acceptance" => "mix test test/widget_test.exs",
        "preservation" => "mix test",
        "protected_paths" => ["test/"],
        "test_suffixes" => ["_test.exs"],
        "required" => ["test/widget_test.exs:12", "test/widget_test.exs:20"],
        "starting_failures" => ["test/widget_test.exs:20"],
        "model_tests" => "behavioral",
        "requirements" => [
          %{"id" => "R1", "text" => "Totals round half up to two places."},
          %{"id" => "R2", "text" => "An empty order totals zero."}
        ]
      }
    }
  end

  defp node_spec do
    %{
      "runtime" => %{
        "image" => "hexpm/elixir:1.13.4-erlang-24.3.4-alpine-3.15.3",
        "environment" => %{"WIDGET_MODE" => "strict", "MIX_ENV" => "test"},
        "setup_commands" => ["mix deps.get", "mix deps.compile", "mix compile"]
      }
    }
  end

  # Runs Eab.Sandbox against a stand-in `docker` that records its arguments and succeeds. Returns the workspace
  # container's name and every call, with that name and the installation id replaced by placeholders.
  defp docker_calls(runtime, spec) do
    dir = Path.join(System.tmp_dir!(), "eab-parity-#{System.unique_integer([:positive])}")
    log = Path.join(dir, "calls")
    File.mkdir_p!(dir)

    File.write!(Path.join(dir, "docker"), """
    #!/bin/sh
    for arg in "$@"; do printf '%s\\037' "$arg"; done >> '#{log}'
    printf '\\036' >> '#{log}'
    """)

    File.chmod!(Path.join(dir, "docker"), 0o755)
    path = System.get_env("PATH")
    System.put_env("PATH", dir <> ":" <> path)

    try do
      Eab.Sandbox.with_runtime("parity-case", spec, runtime, "parity-run", fn _box -> :ok end)
    after
      System.put_env("PATH", path)
    end

    calls =
      log
      |> File.read!()
      |> String.split("\x1e", trim: true)
      |> Enum.map(&(&1 |> String.split("\x1f") |> Enum.drop(-1)))

    File.rm_rf!(dir)
    ["run", "-d", "--name", name | _] = Enum.find(Enum.reverse(calls), &(hd(&1) == "run"))
    installation = Eab.Sandbox.installation()

    replace = fn arg ->
      arg |> String.replace(name, "<name>") |> String.replace(installation, "<installation>")
    end

    {name, Enum.map(calls, &Enum.map(&1, replace))}
  end
end
