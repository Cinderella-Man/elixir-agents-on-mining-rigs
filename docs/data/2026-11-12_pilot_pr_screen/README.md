# The screening verdict of the merged pull requests of the three pilot applications (2026-11-12)

A verdict and a reason for every merged pull request of the three pilot applications of [E68](../../../experiments.md):
`nerves-hub/nerves_hub_web`, `axelclark/ex338` and `podlove/radiator`. It is job P1 of the
[design note](../../research/notes/task_factory_on_the_bench_engine.md) (section 9), and it applies the screening rules of its section 4.2
that GitHub's metadata and the changed lines can decide. It starts from the rows of the
[census](../2026-11-11_pilot_pr_census/README.md) of 2026-11-11. Only GitHub's API was read: the GraphQL API on
2026-11-11 between 23:22 and 23:25 UTC (titles, bodies, the merge commit's message and the numbers of the issues each pull
request closes), and the REST API between 23:27 and 23:30 UTC (the per-file patches of the 169 pull requests in the
111 named pairs that the repair test could use). Nothing was cloned, built or run. Titles, bodies and patch text were
read only to compute the flags below; none is stored in any file here.

## Result

3,476 merged pull requests: 1,115 candidates and 2,361 rejected (705 of 2,474
in nerves_hub_web, 305 of 749 in ex338, 105 of 253 in radiator). A candidate is a pull request that no rule rejected; it
is not a claim that it makes a good task (the gate decides that).

**The reason is the first rule that applies,** in the order of the table. A pull request that fails several rules is counted
once, under the first. In this data every dependency-only, docs-only, CI-only, revert and reverted-later pull request also has no code or
no test change, so the first rule takes them and none of them is a first reason: the second table counts every rule that applies.

| Application | Merged | Candidates | Rejected | no code change | no test change | bot | `mix.exs` or `mix.lock` | repaired by a later pull request |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 2,474 | 705 | 1,769 | 926 | 711 | 2 | 98 | 32 |
| axelclark/ex338 | 749 | 305 | 444 | 270 | 132 | 2 | 40 | 0 |
| podlove/radiator | 253 | 105 | 148 | 67 | 61 | 0 | 19 | 1 |
| Together | 3,476 | 1,115 | 2,361 | 1,263 | 904 | 4 | 157 | 33 |

Every rule that applies to a pull request, whatever its place in the order (a pull request can be counted in several
columns, so a row does not add up to the rejected count):

| Application | no code change | no test change | bot | dependency only | docs only | CI only | `mix.exs` or `mix.lock` | revert | reverted later | repaired by a later pull request |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 926 | 1,591 | 527 | 551 | 28 | 11 | 720 | 2 | 2 | 43 |
| axelclark/ex338 | 270 | 387 | 176 | 182 | 11 | 0 | 234 | 0 | 0 | 1 |
| podlove/radiator | 67 | 124 | 32 | 39 | 1 | 0 | 77 | 0 | 0 | 1 |
| Together | 1,263 | 2,102 | 735 | 772 | 40 | 11 | 1,031 | 2 | 2 | 45 |

Two things about the first table's columns:
- **`mix.exs` or `mix.lock`** rejects any change to either file, as the rule is worded, including a `mix.exs` change that is not
  a dependency (an alias, a version, a path list). Of the 157 pull requests this rule rejects first, 30 change `mix.exs` without
  `mix.lock` (21 in nerves_hub_web, 8 in ex338, 1 in radiator), 11 change `mix.lock` without `mix.exs` and the rest change
  both. The diff is not read, so the 30 are not told apart.
- **No test change** means no changed `_test.exs` path under `test/`. The census's `n_tests` counted every path under `test/`;
  21 pull requests by people change code and only support files or fixtures there (14 in nerves_hub_web, 3 in ex338, 4 in
  radiator) and are rejected here.

### Pairs

A pair is an earlier pull request and a later merged pull request, within the next 50 merged pull requests and 30 days of the
earlier one's merge (whichever ends first), where the later one names the earlier one by number in its title or body, or
closes an issue that the earlier one closes too. A bot is never the later one. The later one **repairs** the earlier one
when it changes lines that the earlier one added, in code or in tests.

| Application | Named pairs | through a mention | through the same issue | not tested: one has no code or test change | tested | tested, no common code or test file | repaired | repaired, a line at the same place |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 126 | 126 | 0 | 25 | 101 | 27 | 47 | 43 |
| axelclark/ex338 | 4 | 2 | 2 | 1 | 3 | 0 | 1 | 1 |
| podlove/radiator | 8 | 8 | 0 | 1 | 7 | 3 | 1 | 1 |
| Together | 138 | 136 | 2 | 27 | 111 | 30 | 49 | 45 |

A pair with both routes would count in both route columns (none has both). No pair needed a patch that GitHub leaves out (`patch_missing` is 0 in all
111 tested pairs).

| Application | Pull requests named by a later one | repaired by a later one | repairing an earlier one | candidates that repair an earlier one | chains ending in a repair (2 or more pull requests) | 3 or more | 4 or more |
|---|---:|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 110 | 43 | 45 | 28 | 40 | 4 | 1 |
| axelclark/ex338 | 4 | 1 | 1 | 0 | 1 | 0 | 0 |
| podlove/radiator | 8 | 1 | 1 | 1 | 1 | 0 | 0 |
| Together | 122 | 45 | 47 | 29 | 42 | 4 | 1 |

A pull request that repairs two earlier ones is counted once in "repairing", so a chain is counted once, at its last pull
request. Of the 45 repaired pull requests, 33 are rejected for this reason first; the rest were already rejected by an earlier rule.

### Candidates

| Application | 1 code file | 2 to 5 code files | more than 5 | 2 to 5 code files, no migration, no `assets/` |
|---|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 169 | 317 | 219 | 255 |
| axelclark/ex338 | 51 | 138 | 116 | 105 |
| podlove/radiator | 10 | 39 | 56 | 19 |
| Together | 230 | 494 | 391 | 379 |

Candidates by year of merge:

| Application | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 0 | 0 | 69 | 60 | 23 | 14 | 9 | 53 | 74 | 128 | 275 |
| axelclark/ex338 | 49 | 69 | 33 | 41 | 52 | 3 | 13 | 3 | 25 | 6 | 11 |
| podlove/radiator | 0 | 0 | 0 | 41 | 0 | 0 | 0 | 3 | 41 | 9 | 11 |
| Together | 49 | 69 | 102 | 142 | 75 | 17 | 22 | 59 | 140 | 143 | 297 |

The marks of the candidates (recorded, never a reason to reject). "Named" is named by a later pull request without being
repaired by it; "touched again" is the census's `followed_by_tests` (a later pull request changes the same `_test.exs` file
within 30 days, the loose route of the census); "other base" is a pull request merged into a branch other than `main` or `master`.

| Application | adds a migration | touches `assets/` | written with an AI tool | not marked as AI | named | touched again | repairs an earlier one | closes an issue | other base |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 136 | 60 | 161 | 544 | 40 | 479 | 28 | 44 | 41 |
| axelclark/ex338 | 57 | 31 | 8 | 297 | 2 | 181 | 0 | 77 | 0 |
| podlove/radiator | 40 | 13 | 4 | 101 | 5 | 73 | 1 | 26 | 3 |
| Together | 233 | 104 | 173 | 942 | 47 | 733 | 29 | 147 | 44 |

**Written with an AI tool,** over all merged pull requests (the mark is for reporting; such pull requests are used like any
other): 257 in all, 233 in nerves_hub_web, 16 in ex338 and 8 in radiator. The signals, which can fire together:

| Application | any signal | footer in the body | co-author trailer in the body | statement in the body | merge commit | author login |
|---|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 233 | 195 | 0 | 0 | 232 | 0 |
| axelclark/ex338 | 16 | 15 | 0 | 0 | 16 | 0 |
| podlove/radiator | 8 | 8 | 0 | 0 | 7 | 0 |
| Together | 257 | 218 | 0 | 0 | 255 | 0 |

Of the 257, 216 have both a footer in the body and a trace in the merge commit, 39 only in the merge commit (37 of them
a Co-Authored-By trailer naming a coding tool, 2 a footer) and 2 only in the body. The mark is a lower bound: a pull request
written with a tool that left none of these traces is not marked.

**The first 60 candidates to try** ([candidates_first.tsv](candidates_first.tsv)): 2 to 5 code files, no migration, no
`assets/`, newest first, per application. It is an order to try them in, not a claim that they make good tasks. radiator has
19 such candidates, so its list is that long; the other two lists have 60.

## The rules as applied

The verdict is `rejected` with the first of these rules that applies, else `candidate`. "Code" is a path ending in `.ex`,
`.heex`, `.eex` or `.leex` under `lib/`, or under `web/` (ex338's older Phoenix 1.2 layout, which the census counted apart as
`n_web`; 144 of its pull requests change `web/` paths, which would not count as code if it were left out). "Test" is a `_test.exs` path under
`test/`. Umbrella paths `apps/<app>/x` count as `x`. The path classes are the census's.

| # | Reason | Applies when |
|---|---|---|
| 1 | `no_code_change` | no changed code path |
| 1 | `no_test_change` | code changed, no changed `_test.exs` path |
| 2 | `bot` | the author is a bot (the census's flag) |
| 3 | `dependency_only` | every path is `mix.exs`, `mix.lock` or a JavaScript manifest or lock file |
| 3 | `docs_only` | every path is documentation (the census's flag) |
| 3 | `ci_only` | every path is under `.github/` |
| 4 | `mix_files` | the pull request changes `mix.exs` or `mix.lock` |
| 5 | `revert` | the title starts with revert, or GitHub's revert branch or body (the census's flag) |
| 6 | `reverted_later` | a later merged pull request is a revert of this one (any time later); `reason_pr` is the first |
| 7 | `repaired_by` | a later pull request of a named pair repairs it; `reason_pr` is the first one |

The repairing pull request stays a candidate if no other rule rejects it, and carries `repair_of` (the numbers it repairs) and
`repair_chain` (the number of pull requests in the chain ending in it, itself included). In a chain of three or more, every
pull request that a later one repairs is rejected and the last stays. This is the rule for a fix spread over two pull
requests: the first is dropped, the follow-up is kept as its own task, and the pairs are counted (above).

**Marks,** recorded for every pull request and used for candidates: `group` (code files: 1, 2-5, 6+; 0 for none), `year`,
`adds_migration` (a path under `priv/<repo>/migrations/`), `touches_assets` (a path under `assets/` or `priv/static/`), `ai_tool`
and `ai_signals`, `named_by`, `touched_again_tests`, `issue_linked` (GitHub records an issue the pull request closes),
`body_chars` (the body's length in characters as GitHub returns it, a line end counting 2) and `base_main`.

**Reverts.** A revert's target is the pull request named by GitHub's own pattern (a body starting `Reverts <repository>#N` or a
branch `revert-N-...`), else the earlier pull request whose title is the quoted title of a `Revert "<title>"`, else the one
earlier merged pull request that a title starting with revert names. Four titles in nerves_hub_web have the word revert or
a form of it:
- #610 reverts #608 (found by the quoted title);
- #1212 reverts #1061, which switched the web server; found by reading the earlier titles by hand
  ([run/reverts_by_hand.tsv](run/reverts_by_hand.tsv)), and #1226 switched back on 2024-02-21, so #1061 was reverted and then
  merged again;
- #2067 has a form of the word revert in the middle of its title and an empty body, and #2314 is a feature about a
  device's automatic revert. Neither is treated as a revert: #2067's target cannot be told from the metadata, #2314 is not one.

No verdict depends on this: #608, #610, #1061 and #1212 have no changed test (and #1061 and #1212 change `mix.exs`), and
#2067 has none either. The rule as worded rejects a pull request that was reverted "and not merged again"; #1061, the one that
was merged again, would be rejected by the design note's table (4.3, the first was reverted and merged again: use the later
form), and it is rejected here for the earlier rules, so the difference is not tested.

**The repair test,** for a named pair whose two pull requests both change code or tests, is on the per-file patches of the code
and test files. The lines a pull request adds are taken with the file's path after it; the lines it removes with the path before
it (a renamed file by its old name). The later pull request repairs the earlier one when it removes a line that the earlier one added
in the same file: the lines are compared by text with the spaces trimmed and collapsed, only lines of 12 characters or more count
(so `end`, `else` and `)` do not), and an added line is matched at most as often as it was added. The test does not use line
numbers, because other pull requests may have moved the lines in between. It also records `lines_same_place`: the matched lines whose
line number is the same (the earlier one's new line number is the later one's old line number), which is true when nothing
else changed the file in between. The shortest line that counts changes the result by at most two pairs:

| Shortest line | Pairs tested | repaired in nerves_hub_web | repaired in ex338 | repaired in radiator | repaired together | repaired together, a line at the same place |
|---:|---:|---:|---:|---:|---:|---:|
| 8 | 111 | 47 | 1 | 1 | 49 | 45 |
| 12 (used) | 111 | 47 | 1 | 1 | 49 | 45 |
| 16 | 111 | 46 | 1 | 1 | 48 | 45 |
| 20 | 111 | 45 | 1 | 1 | 47 | 45 |
| 30 | 111 | 45 | 1 | 1 | 47 | 45 |

The rows give the pairs tested and the pairs repaired with that shortest line (12 is the one used), and in the last column
the pairs repaired with a matched line at the same place.

## Not applied here

These need a reading of the whole diff, or of the pull request beyond GitHub's metadata, and are not guessed from sizes:
- typo-only, formatting-only, generated and mechanical-upgrade changes; unrelated changes in one pull request; work whose
  only claimed result is speed;
- a backport or a duplicate of another pull request;
- work that needs a cloud account, a private package or a service other than Postgres or ClickHouse;
- a submodule change, a symbolic link, binary files and a patch larger than 1 MiB;
- the licence check of a commit and the check against the bench's 12 projects, which the gate's later steps decide.

So a candidate may still be a typo fix, a formatting change or a generated change with a test touched, and the candidates
include pull requests the gate will refuse.

## What the API's data cannot tell

- Whether a pull request's tests run, or fail before and pass after: that needs the build.
- Whether a later pull request that changes the earlier one's lines is a correction. The test only says it removed a line the
  earlier one added; an extension, a refactor or the next step of a stacked series does the same. Of the 49 repaired
  pairs, 33 were merged less than a day apart, 10 between one and seven days apart and 6 more than seven days apart; a
  follow-up merged within a day is as likely the next step of one piece of work as a correction. A repair that only adds
  lines (a missing clause, for example) and removes none of the earlier one's is not found.
- A fix that names neither the number nor a shared issue, or that comes later than 50 merged pull requests or 30 days, is not
  a named pair and is not tested. A change that reached the main branch without a pull request is not seen.
- A pair whose pull requests share no code or test file (30 of the 111 tested) cannot be a repair under the test; a rename
  of a file by the later pull request is matched only through its old name.
- Whether the mentions of a bot-authored pull request name this one: they are not read (a dependency bump's body copies the
  dependency's release notes, whose `#N` are that project's).
- Whether a pull request was written with an AI tool beyond the signals above. The commit trailers of the earlier commits of a pull
  request merged by a merge commit or a rebase are not read, only the merge commit's own message. No author login of a coding
  tool's agent account was found.
- `issue_linked` is GitHub's record of an issue the pull request closes; an issue named in the text without a closing keyword
  is not counted (147 of the 1,115 candidates have one).
- `base_main` is 0 for a pull request merged into another branch (44 candidates); its starting commit would be
  that branch's.

## Files

| File | What |
|---|---|
| [screen_nerves-hub__nerves_hub_web.tsv](screen_nerves-hub__nerves_hub_web.tsv) | 2,474 rows |
| [screen_axelclark__ex338.tsv](screen_axelclark__ex338.tsv) | 749 rows |
| [screen_podlove__radiator.tsv](screen_podlove__radiator.tsv) | 253 rows |
| [summary.tsv](summary.tsv) | one row per repository and a Together row; every column is named in `run/summarize.awk` |
| [candidates_first.tsv](candidates_first.tsv) | the first 60 candidates to try, per repository |
| [pairs.tsv](pairs.tsv) | the 138 named pairs, with the route, the days and merged pull requests between, the test and its result |
| [sensitivity.tsv](sensitivity.tsv) | the repair test with other shortest lines |
| [fetch_log_meta.txt](fetch_log_meta.txt), [fetch_log_patches.txt](fetch_log_patches.txt) | each request's page, cost and remaining budget; the budgets before and after |
| `run/` | `fetch_meta.sh`, `flatten_meta.sh`, `relate.sh`, `repair.sh`, `fetch_patches.sh`, `verdict.sh`, `summarize.sh`, `sensitivity.sh`, `check.sh`, `run_all.sh`, their awk and jq programs, and `reverts_by_hand.tsv` |

**Columns of `screen_<repo>.tsv`:** `number`, `merged_at`, `year`, `verdict`, `reason`, `reason_pr`, `rules` (every rule that applies,
`;`-joined; the reason is the first), `group`, `code_files`, `test_files`, `adds_migration`, `touches_assets`, `ai_tool`, `ai_signals`,
`named_by` (the later pull requests that name this one, `;`-joined), `reverted_by`, `repaired_by`, `repair_of`, `repair_chain`,
`touched_again_tests`, `issue_linked`, `body_chars`, `base_main`. A `-` is none.

**Columns of `pairs.tsv`:** `repo`, `earlier`, `later`, `route` (mention, issue or both), `days` between the merges,
`rank_gap` (merged pull requests between), `status` (`tested`, or `no_code_or_test_in_earlier`, `no_code_or_test_in_later`), `shared_files`
(code or test files both change), `patch_missing`, `lines_matched`, `lines_same_place`, `repaired`.

**GitHub's budget,** from the two logs. The GraphQL fetch was 117 requests (83, 25 and 9 for the three repositories; each page is 30
pull requests with their titles, bodies, the merge commit's message and up to 20 closing issues), each reported as cost 1;
`gh api rate_limit` showed 4,941 of 5,000 points before and 4,913 after, while the `remaining` printed with each request ran from
4,878 to 4,971, because the login is also used by other tools; the two counters were not reconciled. The REST fetch was one request
per page of 100 files for 169 pull requests: the core budget showed 4,985 of 5,000 before and 4,814 after (171 requests).

## Checks

`run/check.sh` re-counts with its own expressions and prints one line per check; all 9 printed ok in the run that wrote these files:
the screen has the census's pull-request numbers in its order; the number of pull requests that pass every rule before the repair
rule (candidates plus repaired) equals a count straight from the census's author, flag and path columns (737 in nerves_hub_web, 305 in ex338, 106 in radiator); every pair that the census
saw through a mention within 50 merged pull requests is in `pairs.tsv`. The flatten step also checks that every mention the census read is
among the mentions read here, and that the closing-issue numbers fetched here are as many as the census's `closes_issues` (no
difference in any of the 3,476 pull requests).

## Commands

`gh` logged in, plus `jq`, `awk` and `gzip`. The scripts take their folders from the environment: `CENSUS` is the census folder,
`RAW` the raw pages and patches (they hold titles, bodies and diff text, so they stay out of any commit), `WORK` the
intermediate rows, `OUT` the committed files.

```bash
CENSUS=<census> OUT=<out> RAW=<raw> WORK=<work> bash run/run_all.sh                 # fetch, then every step
FETCH=0 CENSUS=<census> OUT=<out> RAW=<raw> WORK=<work> bash run/run_all.sh         # reuse the pages and patches in RAW
```

The steps, in order: `fetch_meta.sh` (GraphQL), `flatten_meta.sh` (one row per pull request, flags only),
`relate.sh` (the census row joined with it; named pairs; reverts), `repair.sh` (the list of pull requests that need patches,
`fetch_patches.sh` (REST), the added and removed lines, the test of every pair), `verdict.sh`, `summarize.sh`, `sensitivity.sh`,
`check.sh`. The files here were written by the second command, over the pages and patches that the first fetched on 2026-11-11 (UTC).
