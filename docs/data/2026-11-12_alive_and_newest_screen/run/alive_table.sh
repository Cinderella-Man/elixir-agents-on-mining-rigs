#!/usr/bin/env bash
# Part 1, steps 5 and 6. The Elixir and OTP at each head, then the table of the applications.
# Step 5 reads the head of each clone's default branch the way the bundle maker's resolver reads a starting commit
# (git_tree_fetch.sh with MODE=self, then periods_run.sh); step 6 joins select.sh's rows, the history, the archived
# flags, the heads and the mix.lock versions.
#   REPOS   select.sh's output       HIST  alive_history.sh's output      ARCH  alive_archived.sh's output
#   DEPS    alive_deps.sh's output   CENS  census_window.sh's output
#   CLONES  the clones               RAW   raw folder (writes $RAW/head/)
#   TABLE   factory/config/toolchain_images.json                          OUT   writes $OUT/alive/ (alive.tsv, heads/)
#   PILOTS  owner/name screened by the pilot      EARLIER  owner/name whose pages an earlier job fetched (both: spaces)
#   MINOR   the Elixir of the stricter reading (default 1.18)
# alive (the working definition of 2026-11-12): the default branch has a commit in the last 6 months, and a merged pull
#   request in the last 12 shows in the history (numbered merges) or, where the application has one, in the census.
# elixir_ok: the Elixir the resolver reads at the head is MINOR or newer (by major and minor); `unknown` when it reads none.
# agrees: yes when both hold and the repository is not archived, so the stricter reading agrees with the selection rule
#   (select.sh); else what fails.
# Rows are ordered by the Elixir the resolver reads (newest first), then merged pull requests in the last 12 months.
set -euo pipefail
: "${REPOS:?}"; : "${HIST:?}"; : "${ARCH:?}"; : "${DEPS:?}"; : "${CENS:?}"; : "${CLONES:?}"; : "${RAW:?}"; : "${TABLE:?}"; : "${OUT:?}"
here="$(cd "$(dirname "$0")" && pwd)"
MINOR="${MINOR:-1.18}"
mkdir -p "$OUT/alive/heads" "$RAW/head"
awk -F'\t' -v OFS='\t' 'NR > 1 { s = $1; sub("/", "__", s); print s, 0, $4, $3 }' "$HIST" > "$RAW/head/cand.tsv"
CAND="$RAW/head/cand.tsv" CLONES="$CLONES" RAW="$RAW/head" MODE=self "$here/git_tree_fetch.sh"
RAW="$RAW/head" TABLE="$TABLE" OUT="$OUT/alive/heads" "$here/periods_run.sh"
# heads.tsv: repo, elixir and otp CI names, elixir source, image result, lacks, the resolver's reading and image, redis,
# the Postgres and ClickHouse versions CI names
for f in "$OUT"/alive/heads/periods_*.tsv.gz; do
  slug=$(basename "$f" .tsv.gz); slug=${slug#periods_}
  gzip -dc "$f" | awk -F'\t' -v OFS='\t' -v repo="${slug/__//}" 'NR == 2 { print repo, $5, $7, $6, $9, $23, $24, $25, $14, $10, $12 }'
done > "$OUT/alive/heads.tsv"
pk=$(head -n 1 "$DEPS" | cut -f4- | tr '\t' ' ')
{ printf 'order\trepo\tset\talive\telixir_ok\tagrees\tdefault_branch\tlast_commit\tcommits_12m\tcommits_6m\tmerged_prs_12m\tby_merge_commit\tby_squash_subject\tby_bot_subject\tweb_flow_unnumbered_12m\tcensus_merged_12m\tarchived\telixir_resolver\totp_resolver\tresolver_image\telixir_ci\totp_ci\telixir_source\tci_image\tlacks_at_head\tredis\tpostgres_ci\tclickhouse_ci\tlock_packages'
  for p in $pk; do printf '\t%s' "$p"; done
  printf '\tmix_elixir_pool\tlast_pushed_pool\tmerged_prs_pool\n'
  awk -F'\t' -v OFS='\t' -v pilots="${PILOTS:-}" -v earlier="${EARLIER:-}" -v minor="$MINOR" '
    FILENAME == ARGV[1] { if (FNR > 1) { order[++n] = $1; sel[$1] = $3 OFS $4 OFS $5 } ; next }
    FILENAME == ARGV[2] { if (FNR > 1) { h[$1] = $0; w6 = $14 } ; next }
    FILENAME == ARGV[3] { if (FNR > 1) arch[$1] = $4; next }
    FILENAME == ARGV[4] { hd[$1] = $0; next }
    FILENAME == ARGV[5] { if (FNR == 1) { np = NF - 3 } else { d = $3; for (i = 4; i <= NF; i++) d = d OFS $i; dep[$1] = d } ; next }
    FILENAME == ARGV[6] { if (FNR > 1) cen[$1] = $2; next }
    END {
      split(minor, M, ".")
      k = split(pilots, P, " "); for (i = 1; i <= k; i++) setof[P[i]] = "pilot"
      k = split(earlier, E, " "); for (i = 1; i <= k; i++) if (!(E[i] in setof)) setof[E[i]] = "pages_fetched"
      nodep = "-"; for (i = 1; i < np + 1; i++) nodep = nodep OFS "-"
      for (j = 1; j <= n; j++) { r = order[j]; set = (r in setof) ? setof[r] : "new"
        if (r in h) { split(h[r], H, "\t"); cm = (r in cen) ? cen[r] : "-"; alive = (substr(H[4], 1, 10) >= w6 && (H[8] + 0 > 0 || cm + 0 > 0)) ? "yes" : "no" }
        else { for (i = 1; i <= 15; i++) H[i] = "-"; alive = "unknown"; cm = "-" }
        if (r in hd) split(hd[r], D, "\t"); else for (i = 1; i <= 11; i++) D[i] = "-"
        split(D[7], RR, "/"); er = (D[7] == "-" || D[7] == "") ? "-" : RR[1]; otr = (D[7] == "-" || D[7] == "") ? "-" : RR[2]
        if (er ~ /^[0-9]+\.[0-9]+/) { split(er, V, "."); eok = (V[1] + 0 > M[1] + 0 || (V[1] + 0 == M[1] + 0 && V[2] + 0 >= M[2] + 0)) ? "yes" : "no"; key = sprintf("%03d%03d", V[1], V[2]) }
        else { eok = "unknown"; key = "000000" }
        why = ""; if (alive != "yes") why = "not_alive"; if ((r in arch) && arch[r] == "yes") why = why (why == "" ? "" : ";") "archived"; if (eok != "yes") why = why (why == "" ? "" : ";") "elixir_" eok
        agrees = (why == "") ? "yes" : "no:" why
        print key, sprintf("%07d", H[8] + 0), r, set, alive, eok, agrees, H[2], H[4], H[6], H[7], H[8], H[9], H[10], H[11], H[15], cm, (r in arch ? arch[r] : "-"),
              er, otr, D[8], D[2], D[3], D[4], D[5], D[6], D[9], D[10], D[11], (r in dep ? dep[r] : nodep), sel[r] } }' \
    "$REPOS" "$HIST" "$ARCH" "$OUT/alive/heads.tsv" "$DEPS" "$CENS" \
  | sort -t$'\t' -k1,1r -k2,2r -k3,3 \
  | awk -F'\t' -v OFS='\t' '{ out = NR; for (i = 3; i <= NF; i++) out = out OFS $i; print out }'
} > "$OUT/alive/alive.tsv"
awk -F'\t' 'NR > 1 { n++; if ($4 == "yes") a++; if ($6 == "yes") g++ } END { print a + 0 " of " n " alive; " g + 0 " of " n " alive and on Elixir 1.18 or newer at the head" }' "$OUT/alive/alive.tsv"
