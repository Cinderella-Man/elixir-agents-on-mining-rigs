# parity_capture.exs: prints the outputs that factory/test/eab/bench_parity_test.exs pins, from the code it runs in.
# Run in the tooling image from the factory folder: MIX_ENV=test mix run /path/to/parity_capture.exs
# The inputs here are the parity test's own made-up inputs; the printed values were pasted into that test.
defmodule ParityCapture do
  def llama do
    %{
      "backend" => "llama_cpp",
      "model" => "widget-coder",
      "context" => 262_144,
      "url" => "http://model.invalid:8080",
      "profile" => %{"chat_template_caps" => %{"supports_thinking" => true}}
    }
  end

  def strata do
    %{
      "backend" => "strata",
      "model" => "widget-pack",
      "context" => 262_144,
      "url" => "http://model.invalid:8081"
    }
  end

  def legacy_spec(require_test) do
    %{
      "regression_command" => "mix test test/widget_test.exs",
      "require_regression_test" => require_test,
      "allowed_edit_prefixes" => ["lib/", "test/"]
    }
  end

  def contract_spec(kind) do
    {model_tests, requirement} =
      case kind do
        "refactor" ->
          {"preservation",
           %{
             "id" => "R2",
             "text" => "Totals are computed by Widget.Total.sum/1.",
             "kind" => "structural",
             "checks" => ["test/widget_test.exs:20"]
           }}

        _ ->
          {"behavioral",
           %{
             "id" => "R2",
             "text" => "An empty order totals zero.",
             "kind" => "behavior",
             "checks" => ["test/widget_test.exs:20"]
           }}
      end

    %{
      "schema_version" => 2,
      "task_kind" => kind,
      "allowed_edit_prefixes" => ["lib/"],
      "clarifications" => %{"rounding" => "Half up, to two places."},
      "grading" => %{
        "adapter" => "exunit",
        "acceptance" => "mix test test/widget_test.exs",
        "preservation" => "mix test",
        "protected_paths" => ["test/"],
        "test_suffixes" => ["_test.exs"],
        "required" => ["test/widget_test.exs:12", "test/widget_test.exs:20"],
        "starting_failures" => ["test/widget_test.exs:20"],
        "model_tests" => model_tests,
        "requirements" => [
          %{
            "id" => "R1",
            "text" => "Totals round half up to two places.",
            "kind" => "behavior",
            "checks" => ["test/widget_test.exs:12"]
          },
          requirement
        ]
      }
    }
  end

  def recipe_plain do
    spec = %{"runtime" => %{"image" => "hexpm/elixir:1.18.4-erlang-28.0.2-ubuntu-noble-20250714"}}
    Eab.Fixtures.dockerfile(spec, spec["runtime"]["image"])
  end

  def node_spec do
    %{
      "runtime" => %{
        "image" => "hexpm/elixir:1.13.4-erlang-24.3.4-alpine-3.15.3",
        "environment" => %{"WIDGET_MODE" => "strict", "MIX_ENV" => "test"},
        "setup_commands" => ["mix deps.get", "mix deps.compile", "mix compile"]
      }
    }
  end

  def recipe_node do
    Eab.Fixtures.dockerfile(node_spec(), node_spec()["runtime"]["image"], "example/node:22")
  end

  def recipe_full do
    Eab.Fixtures.dockerfile(node_spec(), "example/elixir:1.13", "example/node:22",
      toolchain: "example/toolchain:1",
      seed: "example/seed:1",
      force_add: true
    )
  end

  def docker_calls(runtime, spec) do
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
    [_, name | _] = Enum.find(Enum.reverse(calls), &(hd(&1) == "run")) |> Enum.drop(2)
    installation = Eab.Sandbox.installation()

    {name,
     Enum.map(calls, fn call ->
       Enum.map(call, &(&1 |> String.replace(name, "<name>") |> String.replace(installation, "<installation>")))
     end)}
  end

  def show(label, value) when is_binary(value), do: IO.write("==== #{label}\n" <> value <> "==== end\n")

  def show(label, value),
    do: IO.puts("==== #{label}\n" <> inspect(value, pretty: true, limit: :infinity, printable_limit: :infinity, width: 98))
end

alias ParityCapture, as: C

llama_settings = Eab.Model.settings(C.llama())
strata_settings = Eab.Model.settings(C.strata())
C.show("settings llama", llama_settings)
C.show("settings strata", strata_settings)
legacy = Eab.Agent.instructions(C.legacy_spec(true), llama_settings)
C.show("instructions legacy behavioral", legacy)
C.show("instructions legacy optional", Eab.Agent.instructions(C.legacy_spec(false), llama_settings))
C.show("instructions v2 bug_fix", Eab.Agent.instructions(C.contract_spec("bug_fix"), llama_settings))
C.show("instructions v2 refactor", Eab.Agent.instructions(C.contract_spec("refactor"), llama_settings))
C.show("pi llama", Eab.Pi.config(C.llama(), llama_settings, "Fix the widget totals.\n", legacy))
C.show("pi strata", Eab.Pi.config(C.strata(), strata_settings, "Fix the widget totals.\n", legacy))
C.show("recipe plain", C.recipe_plain())
C.show("recipe node", C.recipe_node())
C.show("recipe full", C.recipe_full())

services = %{
  "postgres" => "example/postgres:16",
  "clickhouse" => "example/clickhouse:25"
}

spec = %{"runtime" => %{"before_test_commands" => ["mix ecto.reset"]}}
C.show("docker services", C.docker_calls(%{"image" => "example/workspace:1", "services" => services}, spec))
C.show("docker plain", C.docker_calls(%{"image" => "example/workspace:1", "services" => %{}}, %{"runtime" => %{}}))
