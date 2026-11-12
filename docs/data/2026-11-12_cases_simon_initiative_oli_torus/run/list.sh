#!/usr/bin/env bash
# list.sh: oli-torus's candidates in a window of merge dates, newest merged first, each with what its starting commit
# needs, read from the commit's own files in a bare clone. The screening's class table holds only the project's 150
# newest candidates; this extends it backwards in the same column layout, so kinds.sh reads it as it reads that table.
#   list.sh > list.tsv
# A candidate is a pull request whose screen verdict is "candidate" (SCREEN, column 4), merged on or after SINCE and
# before UNTIL (ISO times, UTC). Its starting commit is the first parent of its merge commit (CENSUS, column 10), as
# the bundle maker takes it for a squash merge.
# Read at the starting commit:
#   elixir, otp   the `elixir` and `erlang` lines of `.tool-versions` (an `-otp-N` suffix dropped), as the toolchain
#                 resolver reads them first
#   gleam         "yes" when `gleam/gleam.toml` exists: the project then compiles a Gleam package with the Gleam
#                 compiler and the mix_gleam archive, which the factory's workspace build cannot install
#   database      the image the CI workflow's `services:` starts, else the image the compose file names for
#                 `postgres` (the CI started it with `docker compose up -d postgres`)
# Column 9 ("needs") is "-", or the reasons the candidate cannot be made as the factory stands, ";"-joined:
# `needs_program:gleam`, `elixir_before_1.18`.
# Environment: CLONE (a bare clone), CENSUS, SCREEN, SINCE, UNTIL, REPO (owner/name).
# Prints: repo, number, merged, start, elixir, otp, gleam, database, needs, merge.
set -euo pipefail
export LC_ALL=C
: "${CLONE:?}" "${CENSUS:?}" "${SCREEN:?}" "${SINCE:?}" "${UNTIL:?}" "${REPO:?}"
g() { git --git-dir="$CLONE" "$@"; }
printf 'repo\tnumber\tmerged\tstart\telixir\totp\tgleam\tdatabase\tneeds\tmerge\n'
awk -F'\t' -v s="$SINCE" -v u="$UNTIL" 'NR > 1 && $4 == "candidate" && $2 >= s && $2 < u {print $1 "\t" $2}' "$SCREEN" |
  sort -t$'\t' -k2,2r |
  while IFS=$'\t' read -r number merged; do
    merge=$(awk -F'\t' -v n="$number" '$1 == n {print $10}' "$CENSUS")
    if [ -z "$merge" ] || [ "$merge" = - ] || ! start=$(g rev-parse -q --verify "$merge^1^{commit}" 2>/dev/null); then
      printf '%s\t%s\t%s\t-\t-\t-\t-\t-\tno_merge_commit\t%s\n' "$REPO" "$number" "$merged" "${merge:--}"
      continue
    fi
    tv=$(g show "$start:.tool-versions" 2>/dev/null || true)
    elixir=$(printf '%s\n' "$tv" | awk '$1 == "elixir" {sub(/-otp-.*/, "", $2); print $2; exit}')
    otp=$(printf '%s\n' "$tv" | awk '$1 == "erlang" {print $2; exit}')
    if g cat-file -e "$start:gleam/gleam.toml" 2>/dev/null; then gleam=yes; else gleam=no; fi
    ci=$(g show "$start:.github/workflows/build.yml" 2>/dev/null | awk '/^ +services:/ {s = 1} s && /image:/ {print $2; exit}')
    if [ -z "$ci" ]; then
      for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        ci=$(g show "$start:$f" 2>/dev/null | awk '/^  postgres:/ {p = 1; next} p && /^  [a-z]/ {p = 0} p && /image:/ {print "compose:" $2; exit}')
        [ -z "$ci" ] || break
      done
    fi
    needs=()
    [ "$gleam" = no ] || needs+=(needs_program:gleam)
    case ${elixir:-0} in 1.18* | 1.19* | 1.2[0-9]*) ;; *) needs+=(elixir_before_1.18) ;; esac
    n=$(IFS=';'; echo "${needs[*]:-}")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$REPO" "$number" "$merged" "$start" "${elixir:--}" "${otp:--}" \
      "$gleam" "${ci:--}" "${n:--}" "$merge"
  done
