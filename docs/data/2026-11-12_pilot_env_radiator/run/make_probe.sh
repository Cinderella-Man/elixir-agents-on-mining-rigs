#!/usr/bin/env bash
# A minimal task folder in the one format (factory/README.md, section 3), made by hand to let the engine fetch the
# source, build the workspace image and the database for one starting commit. It is a probe, not a kept task: its
# test names are placeholders, it has no partial fix and no statement.
# Environment: GIT_DIR (a clone of the project), RECIPE (the project's recipe), REPO (owner/name), PROJECT (short
# name), NUMBER (the pull request), MERGE (its merge commit), MERGED_AT, OUT (the folder to write; must not exist).
set -euo pipefail
: "${GIT_DIR:?}" "${RECIPE:?}" "${REPO:?}" "${PROJECT:?}" "${NUMBER:?}" "${MERGE:?}" "${MERGED_AT:?}" "${OUT:?}"
export GIT_DIR
start=$(git rev-parse "$MERGE^1")
mkdir "$OUT"
git diff --binary "$start" "$MERGE" -- . ':(exclude)test/' ':(exclude)*.md' ':(exclude)*.txt' > "$OUT/reference.patch"
git diff --binary "$start" "$MERGE" -- test/ > "$OUT/reference-tests.patch"
docs=$(git diff --binary "$start" "$MERGE" -- ':(exclude)test/' '*.md' '*.txt')
if [ -n "$docs" ]; then printf '%s\n' "$docs" > "$OUT/upstream-docs.patch"; fi
printf '%s\n' 'diff --git a/lib/eab_halt.ex b/lib/eab_halt.ex' 'new file mode 100644' '--- /dev/null' \
  '+++ b/lib/eab_halt.ex' '@@ -0,0 +1 @@' '+System.halt(0)' > "$OUT/integrity.patch"
prefixes=$(git diff --name-only "$start" "$MERGE" -- ':(exclude)*.md' ':(exclude)*.txt' | cut -d/ -f1 | sort -u |
  jq -R . | jq -sc 'map(. + "/")')
tests=$(git diff --name-only --diff-filter=AM "$start" "$MERGE" -- 'test/*_test.exs' | tr '\n' ' ')
jq -n --slurpfile r "$RECIPE" --arg id "$PROJECT-pr-$NUMBER" --arg project "$PROJECT" \
  --arg url "https://github.com/$REPO" --arg rev "$start" --argjson prefixes "$prefixes" \
  --arg acceptance "mix test ${tests% }" '
  $r[0] as $r |
  {id: $id, schema_version: 3, task_kind: "feature", project: $project,
   repository: {url: $url, revision: $rev},
   runtime: $r.runtime, services: $r.services, baseline: $r.baseline,
   test_timeout: $r.test_timeout, permitted_exclusion_tags: $r.permitted_exclusion_tags,
   allowed_edit_prefixes: $prefixes, acceptance_patch: "reference-tests.patch",
   grading: ($r.grading + {adapter: "exunit", acceptance: $acceptance,
     required: ["probe::placeholder"], starting_failures: ["probe::placeholder"], model_tests: "behavioral"}),
   partial_control: {present: false, reason: "single_hunk"}}' > "$OUT/case.json"
jq -n --arg url "https://github.com/$REPO" --arg pr "https://github.com/$REPO/pull/$NUMBER" \
  --arg br "$start" --arg bt "$(git rev-parse "$start^{tree}")" \
  --arg fr "$MERGE" --arg ft "$(git rev-parse "$MERGE^{tree}")" --arg merged "$MERGED_AT" '
  {repository: $url, pull_request: $pr, broken_revision: $br, broken_tree: $bt,
   fixed_revision: $fr, fixed_tree: $ft,
   pair_selection: "first parent of the merge commit, and the merge commit",
   licence: "MIT", merged_at: $merged, marks: []}' > "$OUT/provenance.json"
ls -l "$OUT"
