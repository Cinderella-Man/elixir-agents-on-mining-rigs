#!/usr/bin/env bash
# summary.sh: the sums of a task table written by table.sh (pool_table.sh of docs/data/2026-11-12_pilot_tasks_all/run/),
# in the form of that run's summary.tsv and by_period.tsv.
#   summary.sh REPO TASKS_TSV summary > summary.tsv      per check and reason: how many (checked first)
#   summary.sh REPO TASKS_TSV period > by_period.tsv     per toolchain pair and baseline: tried, checked, dropped,
#                                                        not tried, the drops by check and reason
set -euo pipefail
repo=${1:?REPO}
tasks=${2:?TASKS_TSV}
mode=${3:?summary|period}
# The check a line ends at: checked, not tried (the gate's deadline or disk floor), or the check that dropped it.
key='function key() { if ($20 == "checked") return "checked\t-"; if ($20 == "not_tried") return "not tried\t" $22; return $21 "\t" $22 }'
case $mode in
summary)
  printf 'repository\tcheck\treason\tcount\n'
  awk -F'\t' -v OFS='\t' -v r="$repo" "$key"'
    NR > 1 { n[key()]++ }
    END { for (k in n) print r, k, n[k] }' "$tasks" |
    sort -t$'\t' -k2,2 -k4,4nr | awk -F'\t' '$2 == "checked" { print; next } { rest[++m] = $0 } END { for (i = 1; i <= m; i++) print rest[i] }'
  ;;
period)
  printf 'repository\telixir_otp\tbaseline\ttried\tchecked\tdropped\tnot_tried\tdrops_by_cause\n'
  awk -F'\t' -v OFS='\t' -v r="$repo" "$key"'
    NR > 1 {
      p = $4 SUBSEP $5
      if (!(p in seen)) { seen[p] = 1; order[++n] = p }
      k = key()
      if ($20 == "checked") checked[p]++
      else if ($20 == "not_tried") not_tried[p]++
      else { dropped[p]++; split(k, part, "\t"); c = part[1] ": " part[2]; cause[p, c]++; if (!((p, c) in listed)) { listed[p, c] = 1; causes[p] = causes[p] (causes[p] == "" ? "" : "\t") c } }
    }
    END {
      for (i = 1; i <= n; i++) {
        p = order[i]; split(p, q, SUBSEP)
        text = ""
        m = split(causes[p], list, "\t")
        for (j = 1; j <= m; j++) text = text (j > 1 ? "; " : "") list[j] " " cause[p, list[j]]
        print r, q[1], q[2], checked[p] + dropped[p], checked[p] + 0, dropped[p] + 0, not_tried[p] + 0, (text == "" ? "-" : text)
      }
    }' "$tasks"
  ;;
*) echo "unknown mode $mode"; exit 2 ;;
esac
