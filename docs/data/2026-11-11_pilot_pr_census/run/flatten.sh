#!/usr/bin/env bash
# Raw pages -> one row per merged pull request, no titles and no bodies. Titles and bodies are read only to compute
# whether a pull request is a revert (and which pull request it reverts) and which pull-request numbers it mentions.
#   RAW   the folder fetch.sh wrote
#   WORK  output folder; writes $WORK/flat_<owner>__<name>.tsv, sorted by merge time
# Columns: number, merged_epoch, merged_at, author, author_type, base, additions, deletions, changed_files,
#          merge_commit, labels, closes_issues, revert, reverts, mentions, files_listed, paths
set -euo pipefail
: "${RAW:?raw pages}"; : "${WORK:?output folder}"
mkdir -p "$WORK"
for dir in "$RAW"/*__*/; do
  slug=$(basename "$dir"); repo="${slug/__//}"
  re=$(printf '%s' "$repo" | sed 's/[.]/\\./g')      # the repository's own name as a regular expression
  jq -r --arg re "$re" '
    .data.repository.pullRequests.nodes[]
    | . as $p
    | (($p.title // "") + "\n" + ($p.body // "")) as $text
    # "#N" and "<this repository>#N", not "&#N", not another repository'"'"'s "x/y#N", not a URL fragment
    | ([ $text | scan("(?:^|[^A-Za-z0-9_/&.-])#([0-9]+)(?![0-9])") | .[0] ]
       + [ $text | scan("(?<![A-Za-z0-9_/.-])" + $re + "#([0-9]+)(?![0-9])") | .[0] ]
       | map(tonumber) | map(select(. != $p.number)) | unique | map(tostring) | join(";")) as $mentions
    | (($p.title // "") | test("^\\s*revert(s|ed|ing)?\\b"; "i")) as $rt
    | (($p.headRefName // "") | test("^revert-[0-9]+-")) as $rbranch
    | (($p.body // "") | test("\\A\\s*Reverts\\s+(" + $re + ")?#[0-9]+")) as $rbody
    | (if $rbody then ($p.body | capture("\\A\\s*Reverts\\s+(" + $re + ")?#(?<n>[0-9]+)") | .n)
       elif $rbranch then ($p.headRefName | capture("^revert-(?<n>[0-9]+)-") | .n)
       else "" end) as $reverts
    | [ $p.number,
        ($p.mergedAt | fromdateiso8601),
        $p.mergedAt,
        ($p.author.login // "-"),
        ($p.author.__typename // "-"),
        $p.baseRefName,
        $p.additions, $p.deletions, $p.changedFiles,
        ($p.mergeCommit.oid // "-"),
        (([$p.labels.nodes[].name | gsub("[\\t;]"; " ")] | join(";")) | if . == "" then "-" else . end),
        $p.closingIssuesReferences.totalCount,
        ($rt or $rbranch or $rbody),
        (if $reverts == "" then "-" else $reverts end),
        (if $mentions == "" then "-" else $mentions end),
        ($p.files.nodes | length),
        ([$p.files.nodes[].path | gsub("[\\t;]"; "?")] | join(";"))
      ] | @tsv' "$dir"/pr_*.json | sort -t$'\t' -k2,2n -k1,1n > "$WORK/flat_$slug.tsv"
  echo "$repo: $(wc -l < "$WORK/flat_$slug.tsv") rows"
done
