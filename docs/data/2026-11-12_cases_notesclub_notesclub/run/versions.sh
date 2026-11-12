#!/usr/bin/env bash
# versions.sh: which of a project's candidates are on Elixir 1.18 or newer, read from the screening's tables and a
# clone of the project. Read only: no object is fetched (GIT_NO_LAZY_FETCH), so a blobless clone works; the Elixir of
# a commit is read from its .tool-versions, whose blob id is in the commit's tree and whose text is read once per
# version of the file.
#   OUT/tool_versions.tsv   every first-parent commit that changed .tool-versions, oldest first: commit, date, the
#                           file's blob, the Elixir and OTP it names
#   OUT/candidates.tsv      the screening's candidates (every year), newest first: number, merged, merge commit,
#                           starting commit (the screening's where it resolved one, else the merge commit's first
#                           parent), the starting commit's Elixir and OTP by its .tool-versions, what the screening
#                           read, whether it is merged before the upgrade, and the verdict (step, reason, whose) and
#                           its basis: "read" (the starting commit's .tool-versions), "merged_before_elixir_1.18_existed"
#                           (no version read, merged before Elixir 1.18.0 was released) or "not_read"
#   OUT/since_upgrade.tsv   the pull requests whose merge commit has the upgrade among its ancestors (the upgrade's
#                           own pull request included), with the screening's verdict, reason, rules and file counts
#   OUT/code_and_tests.tsv  the first-parent commits from the upgrade to the clone's head that change a code file
#                           (.ex, .heex, .eex, .leex under lib/) and a _test.exs file under test/, with the pull
#                           request whose merge commit it is, or "-" for a commit pushed without one
#   OUT/summary.tsv         the counts
# The upgrade is the oldest first-parent commit whose .tool-versions names Elixir 1.18 or newer.
# Environment: SCREEN (the screening's out folder: screen/, census/, periods/), CLONE (a clone of the project),
# REPO (owner/name), OUT.
set -euo pipefail
: "${SCREEN:?}" "${CLONE:?}" "${REPO:?}" "${OUT:?}"
ELIXIR_1_18_RELEASED=2024-12-19 # the day Elixir 1.18.0 was released
slug=${REPO/\//__}
export GIT_NO_LAZY_FETCH=1
g() { git -C "$CLONE" "$@"; }
census=$SCREEN/census/prs_$slug.tsv.gz
screen=$SCREEN/screen/screen_$slug.tsv
periods=$SCREEN/periods/periods_$slug.tsv.gz
mkdir -p "$OUT"
tmp=$(mktemp -d "$OUT/.tmp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
at_least_1_18() { [[ $1 =~ ^[0-9]+\.[0-9]+ ]] && [ "$(printf '1.18\n%s\n' "$1" | sort -V | head -n 1)" = 1.18 ]; }

# 1. .tool-versions on the first-parent line
printf 'commit\tdate\tblob\telixir\totp\n' > "$OUT/tool_versions.tsv"
upgrade=-
for c in $(g log --first-parent --reverse --format=%H -- .tool-versions); do
  blob=$(g rev-parse -q --verify "$c:.tool-versions" 2> /dev/null || echo -)
  ex=-; otp=-
  if [ "$blob" != - ]; then
    text=$(g cat-file blob "$blob" 2> /dev/null || echo "elixir unread")
    ex=$(printf '%s\n' "$text" | awk '$1 == "elixir" {sub(/-otp-.*/, "", $2); print $2; exit}')
    otp=$(printf '%s\n' "$text" | awk '$1 == "erlang" {print $2; exit}')
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$c" "$(g log -1 --format=%cI "$c")" "$blob" "${ex:--}" "${otp:--}" >> "$OUT/tool_versions.tsv"
  if [ "$upgrade" = - ] && at_least_1_18 "${ex:--}"; then upgrade=$c; fi
done
[ "$upgrade" != - ] || { echo "no first-parent commit names Elixir 1.18 or newer in .tool-versions"; exit 1; }

zcat "$census" | awk -F'\t' 'NR > 1 {print $1 "\t" $10}' > "$tmp/merge_commits"
zcat "$periods" | awk -F'\t' 'NR > 1 {print $2 "\t" $4 "\t" $5 "/" $7 "\t" $6 "/" $8}' > "$tmp/periods"
mc_of() { awk -F'\t' -v n="$1" '$1 == n {print $2; exit}' "$tmp/merge_commits"; }
pr_of() { awk -F'\t' -v c="$1" '$2 == c {print $1; exit}' "$tmp/merge_commits"; }
versions_of() { # the Elixir and OTP a commit's .tool-versions names, by its blob
  local b
  b=$(g rev-parse -q --verify "$1:.tool-versions" 2> /dev/null || echo -)
  awk -F'\t' -v b="$b" 'NR > 1 && $3 == b {print $4 "\t" $5; f = 1; exit} END {if (!f) print "-\t-"}' "$OUT/tool_versions.tsv"
}

# 2. the screening's candidates
printf 'number\tmerged_at\tmerge_commit\tstart_commit\tstart_from\telixir\totp\tscreening_read\tscreening_source\tbefore_upgrade\tverdict\tstep\treason\twhose\tbasis\n' > "$OUT/candidates.tsv"
awk -F'\t' 'NR > 1 && $4 == "candidate" {print $2 "\t" $1}' "$screen" | sort -r | while IFS=$'\t' read -r merged n; do
  mc=$(mc_of "$n"); mc=${mc:--}
  p=$(awk -F'\t' -v n="$n" '$1 == n {print $2 "\t" $3 "\t" $4; exit}' "$tmp/periods")
  if [ -n "$p" ]; then
    IFS=$'\t' read -r start sread ssrc <<< "$p"; from=screening
  else
    start=$(g rev-parse -q --verify "$mc^1" 2> /dev/null || echo -); from=first_parent; sread=-; ssrc=-
  fi
  if [ "$start" != - ]; then IFS=$'\t' read -r ex otp <<< "$(versions_of "$start")"; else ex=-; otp=-; fi
  if [ "$mc" != - ] && g merge-base --is-ancestor "$mc" "$upgrade^" 2> /dev/null; then before=yes; else before=no; fi
  if at_least_1_18 "$ex"; then
    verdict=candidate; step=-; reason=-; whose=-; basis=read
  elif [[ $ex =~ ^[0-9]+\.[0-9]+ ]]; then
    verdict=left_out; step=versions; reason=elixir_before_1.18; whose=pull_request; basis=read
  elif [[ $merged < $ELIXIR_1_18_RELEASED ]]; then
    verdict=left_out; step=versions; reason=elixir_before_1.18; whose=pull_request; basis=merged_before_elixir_1.18_existed
  else
    verdict=unknown; step=-; reason=-; whose=-; basis=not_read
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$merged" "$mc" "$start" "$from" "$ex" "$otp" \
    "$sread" "$ssrc" "$before" "$verdict" "$step" "$reason" "$whose" "$basis" >> "$OUT/candidates.tsv"
done

# 3. the pull requests merged from the upgrade on
printf 'number\tmerged_at\tmerge_commit\tverdict\treason\trules\tcode_files\ttest_files\n' > "$OUT/since_upgrade.tsv"
awk -F'\t' 'NR > 1 {print $2 "\t" $1 "\t" $4 "\t" $5 "\t" $7 "\t" $9 "\t" $10}' "$screen" | sort |
  while IFS=$'\t' read -r merged n verdict reason rules code tests; do
    mc=$(mc_of "$n")
    [ -n "$mc" ] && g merge-base --is-ancestor "$upgrade" "$mc" 2> /dev/null || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$merged" "$mc" "$verdict" "$reason" "$rules" "$code" "$tests"
  done >> "$OUT/since_upgrade.tsv"

# 4. the commits from the upgrade on that change code and tests
head=$(g rev-parse HEAD)
g log --no-renames --first-parent --format='@%H %cI' --name-only "$upgrade^..$head" |
  awk '/^@/ {if (h != "") print h, d, c, t; h = substr($1, 2); d = $2; c = 0; t = 0; next}
       /^lib\/.*\.(ex|heex|eex|leex)$/ {c++} /^test\/.*_test\.exs$/ {t++}
       END {if (h != "") print h, d, c, t}' > "$tmp/commits"
printf 'commit\tdate\tcode_files\ttest_files\tpull_request\n' > "$OUT/code_and_tests.tsv"
while read -r c d code tests; do
  [ "$code" -gt 0 ] && [ "$tests" -gt 0 ] || continue
  pr=$(pr_of "$c")
  printf '%s\t%s\t%s\t%s\t%s\n' "$c" "$d" "$code" "$tests" "${pr:--}"
done < "$tmp/commits" >> "$OUT/code_and_tests.tsv"

# 5. the counts
head_versions=$(versions_of "$head")
{
  printf 'what\tvalue\n'
  printf 'upgrade_commit\t%s\n' "$upgrade"
  printf 'upgrade_date\t%s\n' "$(g log -1 --format=%cI "$upgrade")"
  printf 'upgrade_pull_request\t%s\n' "$(pr_of "$upgrade" | grep . || echo -)"
  printf 'upgrade_versions\t%s\n' "$(versions_of "$upgrade" | tr '\t' /)"
  printf 'before_upgrade_versions\t%s\n' "$(versions_of "$upgrade^" | tr '\t' /)"
  printf 'head_commit\t%s\n' "$head"
  printf 'head_date\t%s\n' "$(g log -1 --format=%cI "$head")"
  printf 'head_versions\t%s\n' "$(printf '%s' "$head_versions" | tr '\t' /)"
  printf 'candidates\t%s\n' "$(awk 'NR > 1' "$OUT/candidates.tsv" | wc -l)"
  printf 'candidates_on_1.18_or_newer\t%s\n' "$(awk -F'\t' 'NR > 1 && $11 == "candidate"' "$OUT/candidates.tsv" | wc -l)"
  printf 'candidates_elixir_before_1.18\t%s\n' "$(awk -F'\t' 'NR > 1 && $13 == "elixir_before_1.18"' "$OUT/candidates.tsv" | wc -l)"
  printf 'candidates_merged_before_upgrade\t%s\n' "$(awk -F'\t' 'NR > 1 && $10 == "yes"' "$OUT/candidates.tsv" | wc -l)"
  printf 'candidates_elixir_read\t%s\n' "$(awk -F'\t' 'NR > 1 && $15 == "read"' "$OUT/candidates.tsv" | wc -l)"
  printf 'candidates_merged_before_elixir_1.18_existed\t%s\n' "$(awk -F'\t' 'NR > 1 && $15 == "merged_before_elixir_1.18_existed"' "$OUT/candidates.tsv" | wc -l)"
  printf 'candidates_not_read\t%s\n' "$(awk -F'\t' 'NR > 1 && $15 == "not_read"' "$OUT/candidates.tsv" | wc -l)"
  printf 'pull_requests_from_upgrade\t%s\n' "$(awk 'NR > 1' "$OUT/since_upgrade.tsv" | wc -l)"
  printf 'pull_requests_from_upgrade_candidates\t%s\n' "$(awk -F'\t' 'NR > 1 && $4 == "candidate"' "$OUT/since_upgrade.tsv" | wc -l)"
  printf 'commits_from_upgrade\t%s\n' "$(wc -l < "$tmp/commits")"
  printf 'commits_from_upgrade_code_and_tests\t%s\n' "$(awk 'NR > 1' "$OUT/code_and_tests.tsv" | wc -l)"
  printf 'commits_from_upgrade_code_and_tests_pull_requests\t%s\n' "$(awk -F'\t' 'NR > 1 && $5 != "-"' "$OUT/code_and_tests.tsv" | wc -l)"
} > "$OUT/summary.tsv"
cat "$OUT/summary.tsv"
