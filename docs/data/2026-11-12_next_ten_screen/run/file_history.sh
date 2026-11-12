#!/usr/bin/env bash
# The history of the files that name the toolchain, from GitHub's REST API (commits that touched a path on the default
# branch; a path's history is followed by name, not across renames). One row per repository and path: the number of commits,
# the first and the last commit date. Metadata only.
#   REPOS  space-separated owner/name list     OUT  folder (writes $OUT/file_history.tsv)
set -euo pipefail
: "${REPOS:?}"; : "${OUT:?}"
mkdir -p "$OUT"
printf 'repo\tpath\tcommits\tfirst_commit\tlast_commit\n' > "$OUT/file_history.tsv"
for repo in $REPOS; do
  for path in .tool-versions mise.toml .mise.toml .github/workflows .github/actions .travis.yml .circleci Dockerfile; do
    gh api --paginate "repos/$repo/commits?path=$path&per_page=100" --jq '.[] | .commit.committer.date' 2> /dev/null \
      | sort | awk -v repo="$repo" -v path="$path" -v OFS='\t' 'NR == 1 { first = $0 } { last = $0; n++ } END { if (n > 0) print repo, path, n, substr(first, 1, 10), substr(last, 1, 10) }' >> "$OUT/file_history.tsv"
  done
  # mix.exs: only the count (its history is long, and the elixir: line is read at every starting commit instead)
done
