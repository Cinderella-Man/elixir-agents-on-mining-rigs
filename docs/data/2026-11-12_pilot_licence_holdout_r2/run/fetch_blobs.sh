#!/usr/bin/env bash
# Fetches, in one batch, the file contents that a partial clone (cloned with --filter=blob:none) lacks for the
# starting and merge commits of a set of task folders. This is what git does for a lazy fetch, with the ids
# listed up front, so the tree checkout of check_tasks.sh does not fetch them one by one. Run it on a COPY of the
# clone: it writes into the clone.
#   CLONE  git directory of the partial clone (a copy)
#   TASKS  folder that holds the task folders
#   REPO   <owner>/<name> on GitHub; only tasks whose provenance.json names this repository count
#   WORK   scratch folder for the list of ids
set -euo pipefail
: "${CLONE:?}" "${TASKS:?}" "${REPO:?}" "${WORK:?}"
mkdir -p "$WORK"
name=${REPO#*/}
commits=$(for p in "$TASKS"/*/provenance.json; do
  grep -q "\"repository\": \"https://github.com/$REPO\"" "$p" || continue
  grep -Eo '"(broken|fixed)_revision": "[0-9a-f]{40}"' "$p" | grep -Eo '[0-9a-f]{40}'
done | sort -u)
echo "$name: $(echo "$commits" | wc -l) commits; clone before: $(du -sb "$CLONE" | cut -f1) bytes"
# --no-walk: the commits' own trees only, not their history
# shellcheck disable=SC2086
git --git-dir="$CLONE" rev-list --objects --no-walk --missing=print $commits | sed -n 's/^?//p' | sort -u \
  > "$WORK/missing_$name.txt"
n=$(wc -l < "$WORK/missing_$name.txt")
echo "$name: $n blobs wanted"
if [ "$n" -gt 0 ]; then
  git --git-dir="$CLONE" -c fetch.negotiationAlgorithm=noop fetch origin --no-tags --no-write-fetch-head \
    --recurse-submodules=no --filter=blob:none --stdin < "$WORK/missing_$name.txt"
fi
echo "$name: clone after: $(du -sb "$CLONE" | cut -f1) bytes"
# shellcheck disable=SC2086
echo "$name: still missing: $(git --git-dir="$CLONE" rev-list --objects --no-walk --missing=print $commits | grep -c '^?' || true)"
