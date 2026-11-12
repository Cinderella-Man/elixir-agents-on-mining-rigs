#!/usr/bin/env bash
# Part 2: one class per candidate, from its periods row (periods_run.sh), and the counts behind registry E84.
# The class is the first that applies:
#   no_starting_commit   the merge commit or its first parent could not be read
#   before_1.12          the Elixir the starting commit names is before 1.12 (never built: E83)
#   pair_missing         the Elixir/OTP pair is not in the image table (the pair is named)
#   service_missing      the table has the pair, but not a service the commit's CI or mix.exs needs: a Postgres,
#                        ClickHouse or Redis version the table lacks, or another service started by a CI job that runs the
#                        tests (each named)
#   no_version_named     no file names an Elixir version (the factory would use the project template's default)
#   table_has_pair       the table has the pair and every service; other_lacks still lists a program CI installs from a
#                        downloaded file (release_file) or another language's toolchain (toolchain:<name>)
# below_1_18 marks a candidate whose Elixir is older than 1.18 (docs/dataset_rules.md, section 2: not decided whether such
# a task is left out; until then it is taken last).
# The pair is the one CI names (the periods tables' columns elixir and otp: the resolver's reading, plus versions CI sets
# in an environment variable or a container image); resolver_image is what the resolver itself reads today.
#   OUT     the folder with periods/ (periods_<slug>.tsv.gz) and screen/ (screen_<slug>.tsv[.gz])
#   SLUGS   the repositories (owner__name)     SINCE  the first merge date taken (default 2024-01-01)
#   FLOOR   optional, an Elixir version (1.18): a candidate on an older Elixir gets the class elixir_before_<FLOOR> first
#           (after no_starting_commit), the reason name of docs/dataset_rules.md
#   CDIR    the folder written under $OUT (default classes)
#   EXTRA_SCREEN  a further folder with screen tables, read for a repository $OUT/screen lacks (the pilot's screen)
# Writes $OUT/$CDIR/classes.tsv (one row per candidate), classes_by_repo.tsv and e84_pairs.tsv.
set -euo pipefail
: "${OUT:?}"; : "${SLUGS:?}"
SINCE="${SINCE:-2024-01-01}"; CDIR="${CDIR:-classes}"; FLOOR="${FLOOR:-}"
mkdir -p "$OUT/$CDIR"
c="$OUT/$CDIR/classes.tsv"
printf 'repo\tnumber\tmerged_at\tstart_commit\telixir\totp\tclass\tdetail\tother_lacks\timage\tresolver_reads\tresolver_image\tresolver_gap\tbelow_1_18\n' > "$c"
for slug in $SLUGS; do
  f="$OUT/periods/periods_$slug.tsv.gz"; [ -f "$f" ] || continue
  gzip -dc "$f" | awk -F'\t' -v OFS='\t' -v repo="${slug/__//}" -v floor="$FLOOR" 'NR > 1 {
    l = $23; n = split(l, a, ";"); pm = ""; sv = ""; other = ""
    for (i = 1; i <= n; i++) {
      if (a[i] ~ /^pair_missing:/) pm = substr(a[i], 14)
      else if (a[i] ~ /^(db_version|service):/) sv = sv (sv == "" ? "" : ";") a[i]
      else if (a[i] != "-" && a[i] != "elixir_older_than_1.12") other = other (other == "" ? "" : ";") a[i] }
    nv = split($5, V, "."); split(floor, F, ".")
    belowf = (floor != "" && $5 ~ /^[0-9]+\.[0-9]+/ && (V[1] + 0 < F[1] + 0 || (V[1] + 0 == F[1] + 0 && V[2] + 0 < F[2] + 0)))
    if ($4 == "missing") { cl = "no_starting_commit"; d = $23 }
    else if (belowf) { cl = "elixir_before_" floor; d = $5 "/" $7 }
    else if (l ~ /elixir_older_than_1\.12/) { cl = "before_1.12"; d = $5 "/" $7 }
    else if (pm != "") { cl = "pair_missing"; d = pm }
    else if (sv != "") { cl = "service_missing"; d = sv }
    else if ($9 == "none_named") { cl = "no_version_named"; d = "-" }
    else { cl = "table_has_pair"; d = substr($9, 4) }
    old = ($5 ~ /^[0-9]+\.[0-9]+/ && (V[1] + 0 < 1 || (V[1] + 0 == 1 && V[2] + 0 < 18))) ? "yes" : "-"
    print repo, $2, $3, $4, $5, $7, cl, d, (other == "" ? "-" : other) (pm != "" && sv != "" ? ";also:" sv : ""), $9, $24, $25, $26, old }' >> "$c"
done
# per repository: the screen's candidates (all years, and since SINCE), the ones taken, and the classes
{ printf 'repo\tcandidates_all\tcandidates_since\ttaken\ttable_has_pair\tpair_missing\tservice_missing\tbefore_1_12\tno_version_named\tno_starting_commit\ttable_has_pair_with_other_lack\tresolver_gap\tnewest_taken\toldest_taken\telixir_below_1_18\tbelow_floor\n'
  for slug in $SLUGS; do
    repo="${slug/__//}"; s=$(ls "$OUT"/screen/screen_"$slug".tsv* ${EXTRA_SCREEN:+"$EXTRA_SCREEN"/screen_"$slug".tsv*} 2> /dev/null | head -n 1 || true)
    all=$(gzip -dcf "$s" | awk -F'\t' 'NR > 1 && $4 == "candidate"' | wc -l)
    since=$(gzip -dcf "$s" | awk -F'\t' -v d="$SINCE" 'NR > 1 && $4 == "candidate" && $2 >= d' | wc -l)
    awk -F'\t' -v OFS='\t' -v repo="$repo" -v all="$all" -v since="$since" '
      $1 == repo { t++; k[$7]++; if ($7 == "table_has_pair" && $9 != "-") o++; if ($13 == "yes") g++; if ($14 == "yes") b++; if ($7 ~ /^elixir_before_/) bf++
                   if (new == "" || $3 > new) new = $3; if (old == "" || $3 < old) old = $3 }
      END { print repo, all, since, t + 0, k["table_has_pair"] + 0, k["pair_missing"] + 0, k["service_missing"] + 0, k["before_1.12"] + 0,
                  k["no_version_named"] + 0, k["no_starting_commit"] + 0, o + 0, g + 0, (new == "" ? "-" : substr(new, 1, 10)), (old == "" ? "-" : substr(old, 1, 10)), b + 0, bf + 0 }' "$c"
  done; } > "$OUT/$CDIR/classes_by_repo.tsv"
# registry E84: the missing pairs, newest first, with the candidates each would unlock (and how many of those would still
# lack a service, or are read differently by the resolver today)
{ printf 'pair\tbelow_1_18\tcandidates\tstill_lack_a_service\tresolver_reads_another\tnewest_merge\toldest_merge\tby_repo\n'
  awk -F'\t' -v OFS='\t' 'NR > 1 && $7 == "pair_missing" {
      p = $8; n[p]++; if ($9 ~ /also:/) s[p]++; if ($11 != $5 "/" $6) r[p]++
      if (!(p in new) || $3 > new[p]) new[p] = $3; if (!(p in old) || $3 < old[p]) old[p] = $3
      if (!((p, $1) in br)) { br[p, $1] = 0; repos[p] = repos[p] (repos[p] == "" ? "" : ",") $1 } ; br[p, $1]++ }
    END { for (p in n) {
        split(p, ab, "/"); ne = split(ab[1], e, "."); no = split(ab[2], o, ".")
        key = sprintf("%03d%03d%03d%03d%03d%03d", e[1], e[2], (ne > 2 ? e[3] : 0), o[1], (no > 1 ? o[2] : 0), (no > 2 ? o[3] : 0))
        m = split(repos[p], rr, ","); b = ""; for (i = 1; i <= m; i++) b = b (b == "" ? "" : ", ") rr[i] " " br[p, rr[i]]
        print key, p, ((e[1] + 0 < 1 || (e[1] + 0 == 1 && e[2] + 0 < 18)) ? "yes" : "-"), n[p], s[p] + 0, r[p] + 0, substr(new[p], 1, 10), substr(old[p], 1, 10), b } }' "$c" | sort -t$'\t' -k1,1r | cut -f2-
} > "$OUT/$CDIR/e84_pairs.tsv"
cat "$OUT/$CDIR/classes_by_repo.tsv"
cat "$OUT/$CDIR/e84_pairs.tsv"
