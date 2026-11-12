# parity_capture_feature.exs: prints the instruction text the unchanged copy gives for a made-up `feature` task.
# Run it like job T0's parity_capture.exs, from the unchanged copy (public commit 470301e), in the tooling image:
#   MIX_ENV=test mix run /path/to/parity_capture_feature.exs
# The input is the parity test's `bug_fix` input with the kind changed to `feature`. The bench's own format needs at
# least one requirement for a feature (its older format knows only bug fixes), so a feature text without
# requirement lines cannot come from the unchanged copy. The printed value is pasted into bench_parity_test.exs.
llama = %{
  "backend" => "llama_cpp",
  "model" => "widget-coder",
  "context" => 262_144,
  "url" => "http://model.invalid:8080",
  "profile" => %{"chat_template_caps" => %{"supports_thinking" => true}}
}

spec = %{
  "schema_version" => 2,
  "task_kind" => "feature",
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
    "model_tests" => "behavioral",
    "requirements" => [
      %{
        "id" => "R1",
        "text" => "Totals round half up to two places.",
        "kind" => "behavior",
        "checks" => ["test/widget_test.exs:12"]
      },
      %{
        "id" => "R2",
        "text" => "An empty order totals zero.",
        "kind" => "behavior",
        "checks" => ["test/widget_test.exs:20"]
      }
    ]
  }
}

IO.write("==== instructions v2 feature\n" <> Eab.Agent.instructions(spec, Eab.Model.settings(llama)) <> "==== end\n")
