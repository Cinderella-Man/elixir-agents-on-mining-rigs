#!/usr/bin/env bash
# COPY of 2026-11-12_next_ten_screen/run/periods_run.sh, unchanged: it calls the periods_facts.jq (unchanged) and
# periods_resolve.jq (the Redis rule added) next to it.
# Periods, step 3: from the files periods_fetch.sh read, one row per candidate (what the resolver reads at its starting
# commit and what the factory lacks), then the periods: runs of candidates, newest first, whose toolchain, databases,
# services and installed programs are the same. Needs jq and awk.
#   RAW    the raw folder periods_fetch.sh wrote ($RAW/periods/<slug>/)
#   TABLE  factory/config/toolchain_images.json (the image table the verdicts are made against)
#   OUT    the committed folder: writes $OUT/periods_<slug>.tsv.gz (one row per candidate), $OUT/periods_summary.tsv (one row
#          per period) and $OUT/periods_by_repo.tsv
#   SLUGS  the repositories (owner__name), default every folder of $RAW/periods
set -euo pipefail
: "${RAW:?}"; : "${TABLE:?}"; : "${OUT:?}"
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
clients=$(jq -c '.service_clients' "$TABLE")
slugs="${SLUGS:-$(cd "$RAW/periods" && ls -d *__* | sort)}"
HEAD='number\tmerged_at\tstart_commit\telixir\telixir_source\totp\totp_source\timage\tpostgres_ci\tpostgres_result\tclickhouse_ci\tclickhouse_result\tredis\tservices_in_test_ci\tservices_in_other_workflows\tapt_packages\trelease_file\tother_toolchains\tdocker_compose\tci_test_command\tbuildable\tlacks\tresolver_reads\tresolver_image\tresolver_gap\tnear_table_pair'
rm -f "$OUT"/periods_*.tsv.gz "$OUT/periods_summary.tsv" "$OUT/periods_by_repo.tsv"
printf 'repo\tperiod\tfrom\tto\tcandidates\telixir\totp\timage\tpostgres_ci\tpostgres_result\tclickhouse_ci\tclickhouse_result\tredis\tservices_in_test_ci\tservices_in_other_workflows\tapt_packages\trelease_file\tother_toolchains\tdocker_compose\tci_test_command\tbuildable\tlacks\tresolver_reads\tresolver_image\tresolver_gap\tnear_table_pair\n' > "$OUT/periods_summary.tsv"
for slug in $slugs; do
  repo="${slug/__//}"; dir="$RAW/periods/$slug"
  jq -c --argjson clients "$clients" -f "$here/periods_facts.jq" "$dir/blobs.jsonl" | jq -s 'map({((.kind) + ":" + .oid): .}) | add // {}' > "$dir/facts.json"
  # one record per candidate from the tree answers; a candidate with no starting commit in the answer is `missing`
  for t in "$dir"/trees_*.json; do
    jq -c --rawfile cand "${t%.json}.cand" '
      ($cand | split("\n") | map(select(length > 0) | split("\t"))) as $C
      | .data.repository as $r
      | range(0; $C | length) as $i | ($i + 1) as $n
      | { number: ($C[$i][0] | tonumber), merged_at: $C[$i][2], start: ($r["c\($n)s"].oid // null),
          root: (($r["c\($n)r"].entries // []) | map({(.name): .oid}) | add // {}),
          wf: (($r["c\($n)w"].entries // []) | map(select(.name | test("\\.ya?ml$")))),
          act: [ ($r["c\($n)a"].entries // [])[] | .name as $d | (.object.entries // [])[] | select(.name | test("^action\\.ya?ml$")) | {path: (".github/actions/" + $d + "/" + .name), oid: .oid} ] }' "$t"
  done > "$dir/records.jsonl"
  { jq -r --slurpfile facts "$dir/facts.json" --slurpfile table "$TABLE" -f "$here/periods_resolve.jq" < <(jq -c 'select(.start != null)' "$dir/records.jsonl")
    jq -r 'select(.start == null) | [.number, .merged_at, "missing"] + [range(17) | "-"] + ["unknown", "commit_not_found", "-", "-", "-", "-"] | @tsv' "$dir/records.jsonl"
    awk -F'\t' -v OFS='\t' '{ r = $1 OFS $2 OFS "missing"; for (i = 0; i < 17; i++) r = r OFS "-"; print r, "unknown", "no_merge_commit", "-", "-", "-", "-" }' "$dir/missing_merge.tsv"
  } | sort -t$'\t' -k2,2r -k1,1nr > "$dir/rows.tsv"
  # periods: consecutive rows (newest first) with the same key; the key is every column that names a version, a service or a program
  awk -F'\t' -v OFS='\t' '
    { key = $4 SUBSEP $6 SUBSEP $8 SUBSEP $9 SUBSEP $10 SUBSEP $11 SUBSEP $12 SUBSEP $13 SUBSEP $14 SUBSEP $17 SUBSEP $18 SUBSEP $22 SUBSEP $24
      if (NR == 1 || key != prev) { p++; prev = key }
      print sprintf("P%02d", p), $0 }' "$dir/rows.tsv" > "$dir/rows_p.tsv"
  { printf 'period\t%b\n' "$HEAD"; cat "$dir/rows_p.tsv"; } | gzip -n -c > "$OUT/periods_$slug.tsv.gz"
  awk -F'\t' -v OFS='\t' -v repo="$repo" '
    function addset(arr, key, s,   n, a, i) { n = split(s, a, /;| \|\| /); for (i = 1; i <= n; i++) if (a[i] != "-" && a[i] != "" && !((key, a[i]) in arr)) { arr[key, a[i]] = 1; lst[key] = lst[key] (lst[key] == "" ? "" : ";") a[i] } }
    { p = $1; if (!(p in seen)) { seen[p] = 1; order[++np] = p; from[p] = $3; to[p] = $3; for (i = 5; i <= 27; i++) f[p, i] = $i }
      n[p]++; if ($3 < from[p]) from[p] = $3; if ($3 > to[p]) to[p] = $3
      addset(pk, p "pk", $17); addset(sv, p "sv", $16); addset(ts, p "ts", $21) }
    END { for (k = 1; k <= np; k++) { p = order[k]
        print repo, p, substr(from[p], 1, 10), substr(to[p], 1, 10), n[p], f[p,5], f[p,7], f[p,9], f[p,10], f[p,11], f[p,12], f[p,13], f[p,14], f[p,15],
              (lst[p "sv"] == "" ? "-" : lst[p "sv"]), (lst[p "pk"] == "" ? "-" : lst[p "pk"]), f[p,18], f[p,19], f[p,20], (lst[p "ts"] == "" ? "-" : lst[p "ts"]), f[p,22], f[p,23], f[p,24], f[p,25], f[p,26], f[p,27] } }' "$dir/rows_p.tsv" >> "$OUT/periods_summary.tsv"
  echo "$repo: $(wc -l < "$dir/rows.tsv") candidates, $(cut -f1 "$dir/rows_p.tsv" | sort -u | wc -l) periods, $(awk -F'\t' '$22 == "yes"' "$dir/rows_p.tsv" | wc -l) with no lack found"
done
# per repository and for all: candidates, and the candidates in periods with no lack found
# columns of rows_p.tsv: the period, then the 26 columns of HEAD (so buildable is 22, lacks 23, resolver_gap 26, redis 14)
#   no_lack_found        no lack in the versions CI names (columns buildable)
#   resolver_reads_it    of those, the resolver reads the same pair today (resolver_gap is not yes)
#   with_redis           of the no_lack_found ones, those that start Redis or depend on a Redis client
#   the lack_ columns count candidates by kind of lack (a candidate can have several)
{ printf 'repo\tcandidates\tno_lack_found\tresolver_reads_it\twith_redis\tmissing\tlack_elixir_older_than_1_12\tlack_pair_missing\tlack_db_version\tlack_service\tlack_release_file\tlack_toolchain\tresolver_gap\n'
  for slug in $slugs; do
    awk -F'\t' -v OFS='\t' -v repo="${slug/__//}" '
      { n++; if ($22 == "yes") { b++; if ($26 != "yes") rr++; if ($14 == "yes") br++ } ; if ($4 == "missing") m++
        if ($26 == "yes") gap++
        l = $23; if (l ~ /elixir_older_than_1.12/) e++; if (l ~ /pair_missing/) pm++; if (l ~ /db_version/) db++; if (l ~ /service:/) sv++; if (l ~ /release_file/) rf++; if (l ~ /toolchain:/) tc++ }
      END { print repo, n + 0, b + 0, rr + 0, br + 0, m + 0, e + 0, pm + 0, db + 0, sv + 0, rf + 0, tc + 0, gap + 0 }' "$RAW/periods/$slug/rows_p.tsv"
  done; } > "$OUT/periods_by_repo.tsv"
