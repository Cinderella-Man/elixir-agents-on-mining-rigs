# The merged pull requests of the three pilot applications (2026-11-11)

A count of what the merged pull requests of the three pilot applications of [E68](../../../experiments.md) are:
`nerves-hub/nerves_hub_web`, `axelclark/ex338` and `podlove/radiator` (their upstream repositories, which carry the
pull requests; licences Apache-2.0, MIT and MIT). Only GitHub's metadata was read, through the GraphQL API on
2026-11-11 between 22:38 and 22:45 UTC: nothing was cloned, built or run. Titles and bodies were read only to compute
the revert flag and the pull-request numbers a pull request mentions; they are not stored in any file here.

## Result

3,476 merged pull requests: 2,474 in nerves_hub_web, 749 in ex338 and 253 in radiator. The project pool of
2026-11-09 listed 2,455, 749 and 252; the difference is pull requests merged since (the last merges are 2026-11-10 in
nerves_hub_web and radiator, 2026-09-09 in ex338).

| Application | Merged | By bots | Dependencies only (`mix.exs`, `mix.lock`) | Dependencies only, JavaScript manifests too | Docs only | Reverts |
|---|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 2,474 | 527 | 506 | 551 | 28 | 2 |
| axelclark/ex338 | 749 | 176 | 166 | 182 | 11 | 0 |
| podlove/radiator | 253 | 32 | 38 | 39 | 1 | 0 |
| Together | 3,476 | 735 | 710 | 772 | 40 | 2 |

| Application | Both `lib/` code and tests | Of those, 2 to 5 implementation files | Of those, followed by another pull request | Both, followed by another pull request | Followed through a shared test file | Followed through a mention |
|---|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 851 | 358 | 224 | 591 | 579 | 75 |
| axelclark/ex338 | 280 | 113 | 55 | 161 | 161 | 1 |
| podlove/radiator | 129 | 42 | 28 | 88 | 88 | 5 |
| Together | 1,260 | 513 | 307 | 840 | 828 | 81 |

The third column counts the 2-to-5 group; the fourth counts all pull requests changing both. The last two columns split
the fourth by route, and one pull request can be in both ([summary.tsv](summary.tsv) names each column).

**ex338 keeps the Phoenix 1.2 layout (`web/`) for its older code,** which the implementation class (`lib/`) does not
see: 703 `.ex` and `.eex` paths in 144 pull requests are counted apart as `n_web`. With `web/` counted as
implementation, ex338 has 350 pull requests changing both (against 280) and 153 of them with 2 to 5 implementation
files (against 113); the other two applications have no such path (`both_web`, `both_2_5_web` in the summary).

Merged pull requests by year of merge:

| Application | 2016 | 2017 | 2018 | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | 2026 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| nerves-hub/nerves_hub_web | 0 | 0 | 205 | 184 | 68 | 65 | 63 | 248 | 398 | 536 | 707 |
| axelclark/ex338 | 97 | 99 | 65 | 94 | 151 | 9 | 48 | 30 | 103 | 29 | 24 |
| podlove/radiator | 0 | 0 | 0 | 143 | 7 | 0 | 0 | 5 | 54 | 21 | 23 |

Also in the files: pull requests whose base is not `main` or `master` (`base`): nerves_hub_web 84, radiator 37,
ex338 0; pull requests with at least one issue GitHub records as closed by them (`closes_issues`): nerves_hub_web 84,
radiator 50, ex338 135. Every pull request's file list is complete (listed files equal GitHub's `changedFiles` for all 3,476).

## What was counted

**One row per merged pull request** (`prs_<owner>__<name>.tsv`, gzip over 1 MB). Columns: `number`, `merged_at`,
`author` (`-` where GitHub has none), `bot`, `base`, `additions`, `deletions`, `changed_files`, `files_listed`,
`merge_commit` (the commit on the base branch: the squash or merge commit, or the last commit of a rebase merge),
`labels` (`;`-joined), `closes_issues`, the file counts per class (`n_impl`, `n_tests`, `n_migrations`, `n_config`,
`n_assets`, `n_deps`, `n_docs`, `n_ci`, `n_other`, `n_web`), the flags (`deps_only`, `deps_only_js`, `docs_only`,
`revert`, `reverts` = the number it reverts where the body or branch says so, `both_impl_tests`, `impl_2_5`,
`both_impl_tests_web`, `impl_2_5_web`), `followed_by_tests`, `followed_by_mentions`, `followed_by_n`, `mentions` and
`paths` (every changed path, `;`-joined). Flags are 1 or 0.

**Classes of a changed path,** first match wins; an umbrella path `apps/<app>/x` is classed as `x`:

| Class | Paths |
|---|---|
| tests | `test/` |
| migrations | `priv/<repo>/migrations/` (`priv/repo/migrations/` and the like) |
| deps | `mix.exs`, `mix.lock` |
| config | `config/` |
| ci | `.github/` (a `.md` file there is ci, not docs) |
| assets | `assets/`, `priv/static/` |
| impl | `.ex`, `.heex`, `.eex`, `.leex` under `lib/` |
| web | the same extensions under `web/` |
| docs | `.md` anywhere, `docs/`, `guides/` |
| other | everything else |

**Flags.**
- `bot`: GitHub's author type is Bot, or the login ends in `[bot]`, or contains `dependabot` or `renovate`.
- `deps_only`: at least one path, and every path is `mix.exs` or `mix.lock`. `deps_only_js` also allows
  `package.json`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml` and `npm-shrinkwrap.json`.
- `docs_only`: at least one path, and every path is in class docs.
- `revert`: the title starts with revert, reverts, reverted or reverting; or the body starts with `Reverts <ref>#N`;
  or the head branch is GitHub's `revert-<N>-<branch>`. Two further pull requests of nerves_hub_web (#1204 and
  #2067) describe a revert in their branch name or in the middle of their title; they are not flagged.
- `both_impl_tests`: at least one impl path and at least one tests path. `impl_2_5`: 2 to 5 impl paths.
  `both_impl_tests_web` and `impl_2_5_web`: the same with web paths counted as implementation.

**Followed by,** the later merged pull requests (later in the order of merge time, then number; merged within 30 days
of this one's merge) that
- touch at least one of the same test files: a path ending in `_test.exs` under `test/`, the same path
  (`followed_by_tests`); support files such as `test/support/` and `test_helper.exs` are not test files here; or
- mention `#<number>` or `<this repository>#<number>` in their title or body (`followed_by_mentions`). Full pull-request
  URLs are not matched. The mentions of bot-authored pull requests are not read, because a dependency bump's body
  copies the dependency's release notes, whose `#<number>` belong to that project. `mentions` lists every `#<number>` a
  pull request mentions, pull requests and issues alike; only the numbers of merged pull requests of the same
  repository can match.

`followed_by_n` is the size of the union of the two lists.

## What the metadata cannot tell

- Whether a pull request's tests run, or pass, at its commit: that needs the build.
- Whether a `_test.exs` path holds a test that checks the change (a pull request may only touch a fixture or a
  helper inside it), or whether an implementation path holds code.
- Whether a follow-up is a correction. A later pull request touching the same test file or naming the number may
  extend, fix, revert or have nothing to do with it; 30 days is a window, not a cause. The shared-test-file route
  accounts for 828 of the 840 "both" pull requests followed, so it is the loose one.
- Whether a pull request is buggy, was stacked on another (its `base` says only the branch it merged into), or depends
  on a change that merged earlier.
- Anything the mentions rule misses: other words for a revert, URL references, a fix that names no number.
- What the labels, authors and paths mean beyond their text. Author logins are GitHub's public handles.

## Files

| File | What |
|---|---|
| [prs_nerves-hub__nerves_hub_web.tsv.gz](prs_nerves-hub__nerves_hub_web.tsv.gz) | 2,474 rows (1,124 KiB unzipped) |
| [prs_axelclark__ex338.tsv](prs_axelclark__ex338.tsv) | 749 rows |
| [prs_podlove__radiator.tsv](prs_podlove__radiator.tsv) | 253 rows |
| [summary.tsv](summary.tsv) | one row per repository: the tables above, with every column named in `run/summarize.sh` |
| [fetch_log.txt](fetch_log.txt) | each request's page, cost and remaining budget; the budget before and after |
| `run/` | `fetch.sh`, `flatten.sh`, `derive.sh`, `summarize.sh`, `run_all.sh` |

**GitHub's budget,** from `fetch_log.txt`: `gh api rate_limit` showed 4,999 of 5,000 GraphQL points remaining before and
4,953 after. 117 requests (83, 25 and 9 for the three repositories; each page is 30 pull requests with up to 100 of
their files, their labels and closing issues) cost 1 point each. The `remaining` printed with each request is GraphQL's
own counter and runs lower (4,768 at the lowest, 4,998 at the highest), because the login is also used by other tools. A
first run on radiator alone had been made earlier in the same window as a test.

## Commands

`gh` logged in, plus `jq`, `awk` and `gzip`. The scripts take their folders from the environment: `RAW` for the
raw pages (they hold titles and bodies, so they stay out of any commit), `WORK` for the intermediate rows, `OUT` for the
committed files.

```bash
RAW=<raw> bash run/fetch.sh
FETCH=0 RAW=<raw> WORK=<work> OUT=<out> bash run/run_all.sh
```

`run_all.sh` alone does both (fetch, then flatten, derive and gzip, summarize). The result was checked against a
separate `jq` count straight from the raw pages: pull requests, bots, dependencies only, both implementation and tests
and those with 2 to 5 implementation files agree for all three; docs only differs by one pull request in two
repositories, because that count ignored the `.github/` rule above.
