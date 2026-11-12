#!/usr/bin/env bash
# The table the owner needs: per application the merged pull requests, the candidates, and the candidates in periods the
# factory can build today; and for the ten together. Counts only. Joins the three summaries.
#   OUT  the committed folder (census/summary.tsv, screen/summary.tsv, periods/periods_by_repo.tsv, choice.tsv); writes $OUT/summary.tsv
# Columns:
#   merged_prs                 merged pull requests (the census)
#   candidates                 pull requests no screening rule rejected
#   no_lack_found              candidates whose period has no lack: the Elixir and OTP CI names are a pair of the image table, the
#                              Postgres and ClickHouse versions are in the table, CI's test jobs start no service beyond Postgres,
#                              ClickHouse and Redis, no release file, no other toolchain (a Rust one, for example)
#   resolver_reads_it          of those, the candidates whose pair the resolver finds today (the resolver reads fewer places than CI
#                              names versions in: an environment variable such as ELIXIR_VERSION, a container image)
#   with_redis                 of no_lack_found, those that start Redis or depend on a Redis client (the engine has the service; the
#                              resolver still answers needs_service:redis, so a template must say so)
#   commit_not_found           candidates whose merge commit GitHub no longer serves (no toolchain read)
#   lack_*                     candidates by kind of lack (a candidate can have several)
set -euo pipefail
: "${OUT:?}"
{
  printf 'repo\tmerged_prs\tcandidates\tno_lack_found\tresolver_reads_it\twith_redis\tcommit_not_found\tlack_elixir_older_than_1_12\tlack_pair_missing\tlack_db_version\tlack_service\tlack_release_file\tlack_toolchain\tresolver_gap\n'
  awk -F'\t' -v OFS='\t' '
    FILENAME ~ /census/ { if (FNR > 1) merged[$1] = $2; next }
    FILENAME ~ /screen/ { if (FNR > 1) cand[$1] = $3; next }
    FNR == 1 { next }
    { rep[++n] = $1; for (i = 3; i <= 13; i++) v[n, i] = $i }
    END {
      for (k = 1; k <= n; k++) { r = rep[k]
        line = r OFS merged[r] OFS cand[r]; for (i = 3; i <= 13; i++) { line = line OFS v[k, i]; tot[i] += v[k, i] }
        print line; tm += merged[r]; tc += cand[r] }
      line = "Together" OFS tm OFS tc; for (i = 3; i <= 13; i++) line = line OFS tot[i]
      print line }' "$OUT/census/summary.tsv" "$OUT/screen/summary.tsv" "$OUT/periods/periods_by_repo.tsv"
} > "$OUT/summary.tsv"
cat "$OUT/summary.tsv"
