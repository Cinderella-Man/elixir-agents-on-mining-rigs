#!/usr/bin/env bash
# Per-case and per-series tables from the Elixir SWE Bench's published results.
#   RESULTS  path to results.json (https://cinderella-man.github.io/elixir-swe-bench/results.json)
#   OUT      output folder
set -euo pipefail
: "${RESULTS:?path to results.json}" "${OUT:?output folder}"
mkdir -p "$OUT"

# One row per attempt.
{
  printf 'model\tquantization\tharness\trun\tseed\tcase\tpassed\tgenerated_tokens\tmodel_calls\tbudget\n'
  jq -r '
    .results[] | . as $s | .runs | to_entries[] | .key as $i | .value as $r | $r.cases[] |
    [$s.model.name, ($s.model.quantization // "-"), $s.harness.name, $i + 1, ($r.seed // "-"),
     .id, .passed, .generated_tokens, .model_calls, $s.settings.max_tokens] | @tsv' "$RESULTS"
} > "$OUT/cases.tsv"

# One row per series. "At the budget" means the attempt generated at least the series' generation budget.
{
  printf 'model\tquantization\tharness\truns\tbudget\tpassed\tfailed\tfailed_at_budget\tfailed_below_budget\tpassed_at_budget\tgenerated_tokens\tgenerated_tokens_passed\ttokens_per_pass\tcalls_per_pass\n'
  jq -r '
    .results[] | . as $s | $s.settings.max_tokens as $b | [.runs[].cases[]] as $c |
    ($c | map(select(.passed))) as $p | ($c | map(select(.passed | not))) as $f |
    [$s.model.name, ($s.model.quantization // "-"), $s.harness.name, $s.run_count, $b,
     ($p | length), ($f | length),
     ($f | map(select(.generated_tokens >= $b)) | length),
     ($f | map(select(.generated_tokens < $b)) | length),
     ($p | map(select(.generated_tokens >= $b)) | length),
     ($c | map(.generated_tokens) | add),
     ($p | map(.generated_tokens) | add),
     (($p | map(.generated_tokens) | add) / ($p | length) | round),
     (($p | map(.model_calls) | add) / ($p | length) * 10 | round / 10)] | @tsv' "$RESULTS"
} > "$OUT/series.tsv"

# Generated tokens on the cases every listed Pi series passed (one seed each).
jq -r --argjson names "${COMMON:-[\"DeepSeek-V4.1-Flash-1017\",\"Qwen3.8-Flash-Next-Gyro-L\",\"Qwen3.8-Flash-Next-GSQ-RCO\"]}" '
  [.results[] | select(.harness.name == "pi") | select(.model.name as $n | $names | index($n))] as $s |
  ($s | map([.runs[0].cases[] | select(.passed) | .id]) | reduce .[1:][] as $x (.[0]; . - (. - $x))) as $ids |
  (["case"] + ($s | map(.model.name + " " + (.model.quantization // "-"))) | @tsv),
  ($ids[] as $id | [$id] + ($s | map(.runs[0].cases[] | select(.id == $id) | .generated_tokens)) | @tsv),
  (["total"] + ($s | map([.runs[0].cases[] | select(.id as $i | $ids | index($i)) | .generated_tokens] | add)) | @tsv)
' "$RESULTS" > "$OUT/common_passes.tsv"
