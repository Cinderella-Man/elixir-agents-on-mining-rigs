#!/usr/bin/env bash
# list.sh: the job's list of pull requests, from the screening's class table of the 16 projects
# (docs/data/2026-11-12_alive_and_newest_screen/classes_16/classes.tsv, the project's rows), newest merged first.
# A row whose Elixir is older than 1.18 is left out as elixir_before_1.18 (docs/dataset_rules.md, section 2); a row
# whose other_lacks column names something the engine does not have (Rust, a release file, a service) is left out
# with that need; a note "-;also:db_version:<service>/<version>" alone is no need (the rules page, section 2: the
# task runs on the newest version of that service the image table has). The first N of the rest go to numbers.txt.
# Environment: CLASSES (the project's rows of the class table), OUT (where list.tsv and numbers.txt go), N (12).
# Writes OUT/list.tsv (number, merged_at, elixir, otp, other_lacks, status: listed, not_listed or the reason) and
# OUT/numbers.txt (one number per line).
set -euo pipefail
: "${CLASSES:?}" "${OUT:?}"
N=${N:-12}
mkdir -p "$OUT"
sort -t$'\t' -k3,3r "$CLASSES" | awk -F'\t' -v n="$N" '
  function before_1_18(v,   p) { split(v, p, "."); return (p[1] + 0 < 1) || (p[1] + 0 == 1 && p[2] + 0 < 18) }
  BEGIN { OFS = "\t"; print "number", "merged_at", "elixir", "otp", "other_lacks", "status" }
  {
    status = ""
    if (before_1_18($5)) status = "elixir_before_1.18"
    else if ($9 != "-" && $9 != "" && $9 !~ /^-;also:db_version:/) status = "needs:" $9
    else if (++k <= n) status = "listed"
    else status = "not_listed"
    print $2, $3, $5, $6, $9, status
  }' > "$OUT/list.tsv"
awk -F'\t' 'NR > 1 && $6 == "listed" {print $1}' "$OUT/list.tsv" > "$OUT/numbers.txt"
awk -F'\t' 'NR > 1 {c[$6]++} END {for (s in c) print c[s] "\t" s}' "$OUT/list.tsv" | sort -rn
