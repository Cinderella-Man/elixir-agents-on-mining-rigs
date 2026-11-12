#!/usr/bin/env bash
# The rule that limits the dataset to 21 applications (the owner, 2026-11-12), applied to the pool table:
#   - the column `group` is `application`;
#   - the licence is MIT or Apache-2.0;
#   - `last_pushed` is on or after SINCE (default 2026-05-12, six months before the day of the rule);
#   - `mix_elixir` asks for Elixir MINOR or newer (default 1.18): the first version in the requirement
#     (`~> 1.18`, `~> 1.20.0`), compared by major and minor; a row with no requirement (`-`) is out.
#   LIST  approved_app_first_batch.tsv
# Writes to stdout: repo, licence, mix_elixir, last_pushed, merged_prs (the pool table's), in the table's order.
set -euo pipefail
: "${LIST:?}"
SINCE="${SINCE:-2026-05-12}"; MINOR="${MINOR:-1.18}"
printf 'repo\tlicence\tmix_elixir\tlast_pushed\tmerged_prs_pool\n'
awk -F'\t' -v OFS='\t' -v since="$SINCE" -v minor="$MINOR" '
  NR == 1 { for (i = 1; i <= NF; i++) c[$i] = i; split(minor, m, "."); next }
  $c["group"] == "application" && ($c["licence"] == "MIT" || $c["licence"] == "Apache-2.0") && $c["last_pushed"] >= since {
    v = $c["mix_elixir"]; if (!match(v, /[0-9]+\.[0-9]+/)) next
    split(substr(v, RSTART, RLENGTH), a, ".")
    if (a[1] + 0 > m[1] + 0 || (a[1] + 0 == m[1] + 0 && a[2] + 0 >= m[2] + 0))
      print $c["repo"], $c["licence"], $c["mix_elixir"], $c["last_pushed"], $c["merged_prs"] }' "$LIST"
