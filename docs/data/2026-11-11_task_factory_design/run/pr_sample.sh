#!/usr/bin/env bash
# Screening signals in the latest merged pull requests of the pilot repositories, from GitHub's metadata only.
# Nothing is cloned and no project code runs. Needs the GitHub CLI (gh), signed in; the counting is gh's own --jq.
#
# usage: [REPOS="owner/name ..."] [LIMIT=200] bash pr_sample.sh
#   prints, per repository, the counts of pr_sample.tsv as two JSON objects, then the 2023-2024 window for the first
#   repository
set -euo pipefail
REPOS=${REPOS:-"nerves-hub/nerves_hub_web axelclark/ex338 podlove/radiator"}
LIMIT=${LIMIT:-200}
FIELDS=number,title,author,additions,deletions,changedFiles,files,closingIssuesReferences,mergedAt,labels,body

# "code": a file under lib/ ending in .ex, .heex, .eex or .leex; "test": a file under test/ ending in _test.exs.
# gh lists at most 100 files per pull request.
DEFS='def islib: (.path|startswith("lib/")) and (.path|test("\\.(ex|heex|eex|leex)$"));
def istest: (.path|startswith("test/")) and (.path|endswith("_test.exs"));
def isbot: ((.author.is_bot // false) or (.author.login|test("dependabot|renovate|\\[bot\\]";"i")));'

SIGNALS="$DEFS"'
[ .[] | { bot: isbot,
          lib: ([.files[]|select(islib)]|length), tst: ([.files[]|select(istest)]|length),
          mig: ([.files[]|select(.path|startswith("priv/repo/migrations/"))]|length),
          assets: ([.files[]|select(.path|startswith("assets/"))]|length),
          deps: ([.files[]|select(.path=="mix.lock" or .path=="mix.exs")]|length),
          nfiles: (.files|length), issue: ((.closingIssuesReferences|length)>0),
          nobody: (((.body // "")|length) < 20), revert: (.title|test("^revert";"i")), merged: .mergedAt } ] as $r
| ($r|map(select(.bot|not))) as $h | ($h|map(select(.lib>0 and .tst>0))) as $b
| { sample: ($r|length), oldest: ($r|map(.merged)|min), newest: ($r|map(.merged)|max),
    bot_authored: ($r|map(select(.bot))|length), human: ($h|length),
    human_lib_and_test: ($b|length),
    human_lib_only_no_test: ($h|map(select(.lib>0 and .tst==0))|length),
    human_test_only: ($h|map(select(.lib==0 and .tst>0))|length),
    human_neither: ($h|map(select(.lib==0 and .tst==0))|length),
    human_reverts: ($h|map(select(.revert))|length),
    human_100_files_listed: ($h|map(select(.nfiles>=100))|length),
    of_those_1_lib_file: ($b|map(select(.lib==1))|length),
    of_those_2_to_5_lib_files: ($b|map(select(.lib>=2 and .lib<=5))|length),
    of_those_over_5_lib_files: ($b|map(select(.lib>5))|length),
    of_those_with_migration: ($b|map(select(.mig>0))|length),
    of_those_touch_assets: ($b|map(select(.assets>0))|length),
    of_those_touch_mix_exs_or_lock: ($b|map(select(.deps>0))|length),
    of_those_closing_issue: ($b|map(select(.issue))|length),
    of_those_body_under_20_chars: ($b|map(select(.nobody))|length) }'

# The descriptions of the pull requests by a person that change code and tests.
BODIES="$DEFS"'
[ .[] | select(isbot|not)
      | select(([.files[]|select(islib)]|length)>0 and ([.files[]|select(istest)]|length)>0) | (.body // "") ] as $b
| { lib_and_test: ($b|length),
    claude: ($b|map(select(test("claude";"i")))|length),
    claude_code_footer: ($b|map(select(test("generated with \\[?claude code";"i")))|length),
    copilot: ($b|map(select(test("copilot";"i")))|length),
    codex: ($b|map(select(test("codex";"i")))|length),
    cursor_word: ($b|map(select(test("\\bcursor\\b";"i")))|length),
    co_authored_by: ($b|map(select(test("co-authored-by";"i")))|length),
    median_body_chars: ($b|map(length)|sort|.[(length/2|floor)]) }'

for repo in $REPOS; do
  echo "== $repo, latest $LIMIT merged"
  gh pr list --repo "$repo" --state merged --limit "$LIMIT" --json "$FIELDS" --jq "$SIGNALS"
  gh pr list --repo "$repo" --state merged --limit "$LIMIT" --json "$FIELDS" --jq "$BODIES"
done

first=${REPOS%% *}
echo "== $first, merged 2023-01-01..2024-12-31 (at most 300)"
gh pr list --repo "$first" --state merged --search "merged:2023-01-01..2024-12-31" --limit 300 \
  --json "$FIELDS" --jq "$BODIES"
