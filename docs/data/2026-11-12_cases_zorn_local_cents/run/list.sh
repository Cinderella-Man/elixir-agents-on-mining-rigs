#!/usr/bin/env bash
# list.sh: the job's list of pull requests, from the screening's class table of the 16 projects
# (docs/data/2026-11-12_alive_and_newest_screen/classes_16/classes.tsv, the project's rows), newest merged first.
# A row whose Elixir is older than 1.18 is left out as elixir_before_1.18 (docs/dataset_rules.md, section 2); a row
# whose other_lacks column names something the engine does not have (a release file, a service) is left out with that
# need. A need the project's recipe serves itself (SERVED, space separated; for zorn/local_cents "toolchain:rust":
# the recipe installs Rust from the distribution's packages) does not leave a row out. The screening's class
# (pair_missing) is the image table of its day; the maker resolves each commit against today's table. The first N of
# the rest go to numbers.txt.
# Environment: CLASSES (the project's rows of the class table), OUT (where list.tsv and numbers.txt go), N (12),
# SERVED (optional).
# Writes OUT/list.tsv (number, merged_at, elixir, otp, other_lacks, status: listed, not_listed or the reason) and
# OUT/numbers.txt (one number per line).
set -euo pipefail
: "${CLASSES:?}" "${OUT:?}"
N=${N:-12}
SERVED=${SERVED:-}
mkdir -p "$OUT"
sort -t$'\t' -k3,3r "$CLASSES" | awk -F'\t' -v n="$N" -v served="$SERVED" '
  function before_1_18(v,   p) { split(v, p, "."); return (p[1] + 0 < 1) || (p[1] + 0 == 1 && p[2] + 0 < 18) }
  # the needs of the other_lacks column (separated by ";"; "-" for none, "also:" before some) that the recipe does not serve
  function unserved(lacks,   a, k, i, x, out) {
    k = split(lacks, a, ";"); out = ""
    for (i = 1; i <= k; i++) {
      x = a[i]; sub(/^also:/, "", x)
      if (x == "-" || x == "" || (x in ok)) continue
      out = out (out == "" ? "" : ";") x
    }
    return out
  }
  BEGIN { OFS = "\t"; m = split(served, s, " "); for (i = 1; i <= m; i++) ok[s[i]] = 1
          print "number", "merged_at", "elixir", "otp", "other_lacks", "status" }
  {
    status = ""; u = unserved($9)
    if (before_1_18($5)) status = "elixir_before_1.18"
    else if (u != "") status = "needs:" u
    else if (++k <= n) status = "listed"
    else status = "not_listed"
    print $2, $3, $5, $6, $9, status
  }' > "$OUT/list.tsv"
awk -F'\t' 'NR > 1 && $6 == "listed" {print $1}' "$OUT/list.tsv" > "$OUT/numbers.txt"
awk -F'\t' 'NR > 1 {c[$6]++} END {for (s in c) print c[s] "\t" s}' "$OUT/list.tsv" | sort -rn
