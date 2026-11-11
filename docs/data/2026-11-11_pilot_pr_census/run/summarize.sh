#!/usr/bin/env bash
# prs_<owner>__<name>.tsv (plain or .gz) -> summary.tsv, one row per repository.
#   OUT  the folder holding the prs_*.tsv files; writes $OUT/summary.tsv
# Columns:
#   repo, merged_prs, first_merge, last_merge
#   by_bots, deps_only, deps_only_js, docs_only, reverts
#   both_impl_tests    changing both implementation (lib/) and tests
#   both_2_5           of those, with 2 to 5 implementation files
#   both_followed      of both_impl_tests, followed by another pull request (test files or mentions)
#   both_2_5_followed  of both_2_5, followed by another pull request
#   both_followed_tests, both_followed_mentions   of both_impl_tests, followed through a shared test file / a mention
#                      (a pull request can be in both)
#   both_web, both_2_5_web   both_impl_tests and both_2_5 with files under web/ counted as implementation
#   y2016 ... y2026    merged pull requests by year of merge
set -euo pipefail
: "${OUT:?folder with the prs files}"
for f in "$OUT"/prs_*.tsv "$OUT"/prs_*.tsv.gz; do
  [ -e "$f" ] || continue
  case "$f" in *.gz) zcat "$f" ;; *) cat "$f" ;; esac | awk -F'\t' -v slug="$(basename "$f" | sed 's/^prs_//; s/\.tsv.*$//; s#__#/#')" '
    NR == 1 { for (i = 1; i <= NF; i++) c[$i] = i; next }
    {
      n++; d = substr($c["merged_at"], 1, 10); y = substr(d, 1, 4)
      if (first == "" || d < first) first = d
      if (d > last) last = d
      bot += $c["bot"]; dep += $c["deps_only"]; depjs += $c["deps_only_js"]; doc += $c["docs_only"]; rev += $c["revert"]
      if ($c["both_impl_tests"] == 1) {
        both++; if ($c["followed_by_n"] > 0) bf++
        if ($c["followed_by_tests"] != "-") bft++
        if ($c["followed_by_mentions"] != "-") bfm++
        if ($c["impl_2_5"] == 1) { b25++; if ($c["followed_by_n"] > 0) b25f++ }
      }
      if ($c["both_impl_tests_web"] == 1) { bw++; if ($c["impl_2_5_web"] == 1) b25w++ }
      if (y < 2016 || y > 2026) { print "year out of range: " y > "/dev/stderr"; bad = 1 }
      yr[y]++
    }
    END {
      if (bad) exit 1
      printf "%s\t%d\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d", slug, n, first, last, bot, dep, depjs, doc, rev, both, b25, bf, b25f, bft, bfm, bw, b25w
      for (y = 2016; y <= 2026; y++) printf "\t%d", yr[y]
      printf "\n"
    }'
done | sort -t"$(printf "\t")" -k1,1 > "$OUT/summary.body"
{
  printf 'repo\tmerged_prs\tfirst_merge\tlast_merge\tby_bots\tdeps_only\tdeps_only_js\tdocs_only\treverts\tboth_impl_tests\tboth_2_5\tboth_followed\tboth_2_5_followed\tboth_followed_tests\tboth_followed_mentions\tboth_web\tboth_2_5_web'
  for y in $(seq 2016 2026); do printf '\ty%s' "$y"; done; printf '\n'
  cat "$OUT/summary.body"
} > "$OUT/summary.tsv"
rm -f "$OUT/summary.body"
cat "$OUT/summary.tsv"
