# Simon-Initiative/oli-torus: the project's set-up in the task factory, and its checked cases (2026-11-12)

Registry rows [E68](../../../experiments.md) (the pilot of the task factory) and E82 (the newest cases of the 16
applications). `Simon-Initiative/oli-torus` is one of the dataset's 16 applications ([rules](../../dataset_rules.md)).
This job wrote the project's recipe, ran the project's whole test suite once through the engine, and made and checked
its candidates one at a time, newest merged first, toward 20 cases that pass the engine's check and both scans, through
a controller built from this repository's `main` at `686862f`. Everything ran on the data-mining machine (28 threads,
30 GiB, no GPU) while seven other task-making jobs and one job that uses the model shared it. Times are the data-mining
machine's (UTC+1).

**Final: 15 good cases** (9 features and 6 bug fixes by the maker's label; 8 and 7 by its written rule) of 25 pull
requests tried. The run was stopped at 21:46 on the manager's word, when the whole thread was closed, with 232 candidates
that can be made left untried.

## Result

- **The project needs a Postgres with the `vector` extension** at every candidate: its migrations have created the
  extension since 2023, and the factory's own Postgres images lack it. The cases run on `pgvector/pgvector:pg17`
  (PostgreSQL 17.11), the image the sanbase2 job had already brought to the machine: no download (the manager's
  decision). The CI of the candidates tried names `pgvector/pgvector:pg18`; both are recorded per case (rules,
  section 2, "The database and the cache").
- **One more system package:** Ubuntu's `nodejs` (18.19.1). The application starts a Node.js pool when it boots (its
  default rule evaluator runs in Node), so no test can start without `node`; the project's CI machine has Node built
  in. Nothing else was added: no release file, no service besides Postgres.
- **The whole suite runs** at the starting commit of the newest candidate that can be made, pull request 6722, on
  Elixir 1.19.2 with OTP 28.1.1: ExUnit's summary **26 doctests, 7,541 tests, 1 failure, 74 skipped (1 excluded), in
  800.2 s**. The one failure is a timing assertion (section 2).
- **15 cases are checked and pass both scans** of 25 pull requests tried (section 3): 9 features and 6 bug fixes by the
  label in `case.json`, 8 and 7 by the maker's written rule (6573 is mislabelled, registry E108). 10 were dropped at
  the probe, all for the pull requests' own causes (4 `skipped_test`, 3 `no_existing_tests`, 3
  `start_run_did_not_finish`); none was the machine's or the factory's, and none needed a second try.
- **A check took 491 s at the median** of the 15 checked (410 s to 1,511 s; the two longest ran under a 1-minute load
  of 10 to 15 from the other jobs). The 25 tries took 3 h 15 min (18:31 to 21:46). Every test command of this project
  rebuilds its database first (its `test` alias drops, creates, migrates and seeds it), about 40 s each.
- **Most of the project's newest history cannot be made yet** (section 4): of 535 candidates merged since 2025-07-01,
  175 (merged from 2026-06-08 on, and every one after 2026-07-09) need the Gleam compiler, which the factory cannot
  install (`needs_program:gleam`, the factory's cause, registry E111), 53 need OTP 28.3.1, which the image table lacks,
  and 37 are on Elixir 1.17. 257 can be made; 232 of them were not reached.

## 1. The project's set-up

The recipe is [`factory/recipes/Simon-Initiative__oli-torus.json`](../../../factory/recipes/Simon-Initiative__oli-torus.json),
a template: the toolchain resolver reads each commit's Elixir and OTP from the commit's own files.

| What | Value | Where it comes from |
|---|---|---|
| Elixir and OTP | 1.19.2 and 28.1.1 (`hexpm/elixir:1.19.2-erlang-28.1.1-ubuntu-noble-20260509.1`), 1.18.4 and 28.0.2 for the older candidates | `.tool-versions` at each starting commit |
| Database | `pgvector/pgvector:pg17`, pinned by its index digest `sha256:7d0a4146…`; 627,202,175 bytes on disk (Docker's image size), already on the machine | the project's migrations run `CREATE EXTENSION vector`; the CI names `pgvector/pgvector:pg18` (since 2026-03-06; the candidates tried) or `ankane/pgvector` (before; the CI started it from the project's compose file). Used for this project's cases with nothing installed into it |
| The CI's database as a service | `toolchain.ci_services_not_needed` names `pgvector` | the resolver reads a CI service `pgvector/pgvector` as a service of its own; it is the project's Postgres, served as `services.postgres` |
| Other services | none | the CI starts only Postgres; the test configuration replaces ClickHouse with a stub |
| System package | `nodejs` (Ubuntu's, 18.19.1) | `Oli.Application` starts `NodeJS` (the `nodejs` package's pool) when the rule evaluator is the Node one, the default |
| Database commands | `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the template's one candidate. The project's `test` alias drops, creates, migrates and seeds the database again before every `mix test` |
| Build | `mix compile` after the engine's own dependency steps | the bench's default recipe |
| Whole-suite command | `mix test` | the CI workflow's test step |
| Excluded tags | `nightly`, `skip_if_no_python` | `test/test_helper.exs` excludes `:skip` and `:nightly`, and `:skip_if_no_python` when no Python is installed (none is; one test carries it) |
| Test time limit | 600 s for one test command | the alias's database work comes before every run |

What the build fetches besides Hex packages (152 in `mix.lock`, none from GitHub): the compiled part of `lazy_html`
0.1.6, from the package's own release page through its build step (`cc_precompiler`), as hexpm's and nerves_hub_web's
builds do; the file is in the workspace image (`_build/test/lib/lazy_html/priv/liblazy_html.so`).

The project's CI also builds a Gleam package (at the starting commits of the pull requests merged from 2026-06-08 on), runs a TypeScript job and a Playwright job; none is
part of the Elixir suite at the commits tried.

## 2. The project's own suite

A hand-made probe task for pull request 6722 (`run/make_probe.sh`, with its own id and a 3,600-second limit for one
test command) was prepared through the controller (`run/prepare.exs`) in 473.0 s cold (the engine's own step 454.9 s:
the toolchain image with `nodejs`, the workspace image, the database), and the whole suite ran once through the
engine's own runner (`run/tests.exs`), in a fresh workspace container with a fresh database and no network.
`project_tests.tsv`:

| Run | ExUnit's summary | Passed | Failed | Skipped | Excluded | ExUnit time | Engine time | Return code | Output | Engine: records |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 26 doctests, 7,541 tests, 1 failure, 74 skipped (1 excluded) | 7,492 | 1 | 74 | 1 | 800.2 s | 840.9 s | 2 | 1,634,689 bytes | 7,568, all distinct |

- **The one failure** (`project_test_failures.tsv`): `Oli.MCP.AuthIntegrationTest`, "token usage updates last_used_at
  timestamp" (`test/oli/mcp/auth_integration_test.exs:86`), asserts that a token's last use is less than 1,000 ms old;
  it was 1,023 ms. A timing assertion, on a machine with a 1-minute load near 12 at the time.
- **Skipped:** 74 tests the project marks `@tag :skip`. **Excluded:** the one test tagged `:skip_if_no_python`.

## 3. The candidates

Newest merged first, from the candidate list of section 4 (the candidates that can be made), one at a time: made with
the bundle maker and the toolchain resolver through the controller (`run/make_one.exs`), imported with
`factoryctl import`, checked with `factoryctl check --concurrency 1`, and a checked task exported to the factory's task
folder; then the licence scan and the hold-out check on each checked task (`run/follow.sh`). A check is settled when
the 1-minute load stayed under 12 during it. `tasks.tsv` has one line per try with every column; the engine's step times
are in seconds.

| Pull request | Merged | Elixir/OTP | Kind | Verdict | Step | Reason | Whose | Check (prepare / probe / controls) | Load at start → end (highest in the check) | CI's database → used |
|---|---|---|---|---|---|---|---|---|---|---|
| 6722 | 2026-07-09 | 1.19.2/28.1.1 | feature | **checked** | - | - | - | 1,311 s (399.2 / 312.7 / 596.2) | 10.14 → 10.94 (15.1) | pg18 → pg17 |
| 6706 | 2026-07-01 | 1.19.2/28.1.1 | bug fix | dropped | probe | `skipped_test` | the pull request's | 170 s (113.2 / 55.4 / -) | 10.94 → 12.13 (14.38) | pg18 → pg17 |
| 6664 | 2026-06-18 | 1.19.2/28.1.1 | feature | **checked** | - | - | - | 1,511 s (107.6 / 498.0 / 899.9) | 12.13 → 6.31 (15) | pg18 → pg17 |
| 6639 | 2026-06-05 | 1.19.2/28.1.1 | bug fix | **checked** | - | - | - | 661 s (59.4 / 337.9 / 262.7) | 6.31 → 5.09 (6.51) | pg18 → pg17 |
| 6626 | 2026-06-04 | 1.19.2/28.1.1 | feature | dropped | probe | `no_existing_tests` | the pull request's | 171 s (75.6 / 93.0 / -) | 5.09 → 3.78 (7.4) | pg18 → pg17 |
| 6629 | 2026-06-04 | 1.19.2/28.1.1 | bug fix | **checked** | - | - | - | 531 s (84.5 / 122.0 / 317.6) | 3.72 → 5.72 (6.45) | pg18 → pg17 |
| 6625 | 2026-06-03 | 1.19.2/28.1.1 | feature | dropped | probe | `skipped_test` | the pull request's | 141 s (82.2 / 53.0 / -) | 6.78 → 6.34 (7.54) | pg18 → pg17 |
| 6623 | 2026-06-03 | 1.19.2/28.1.1 | feature | **checked** | - | - | - | 591 s (78.4 / 147.2 / 357.1) | 6.34 → 6.57 (6.89) | pg18 → pg17 |
| 6608 | 2026-06-03 | 1.19.2/28.1.1 | feature | dropped | probe | `start_run_did_not_finish` | the pull request's | 130 s (84.9 / 36.7 / -) | 6.57 → 4.96 (6) | pg18 → pg17 |
| 6599 | 2026-05-29 | 1.19.2/28.1.1 | feature | dropped | probe | `start_run_did_not_finish` | the pull request's | 120 s (79.3 / 36.5 / -) | 4.96 → 3.62 (4.4) | pg18 → pg17 |
| 6615 | 2026-05-29 | 1.19.2/28.1.1 | bug fix | **checked** | - | - | - | 481 s (81.1 / 120.9 / 269.4) | 3.62 → 1.96 (5.05) | pg18 → pg17 |
| 6609 | 2026-05-29 | 1.19.2/28.1.1 | feature | dropped | probe | `no_existing_tests` | the pull request's | 170 s (77.6 / 89.4 / -) | 2.68 → 1.84 (3.09) | pg18 → pg17 |
| 6611 | 2026-05-29 | 1.19.2/28.1.1 | bug fix | **checked** | - | - | - | 411 s (60.0 / 113.2 / 237.1) | 1.84 → 2.02 (3.69) | pg18 → pg17 |
| 6596 | 2026-05-28 | 1.19.2/28.1.1 | feature | **checked** | - | - | - | 491 s (78.4 / 129.5 / 278.5) | 2.02 → 1.33 (4.23) | pg18 → pg17 |
| 6601 | 2026-05-28 | 1.19.2/28.1.1 | bug fix | **checked** | - | - | - | 901 s (63.7 / 575.4 / 255.7) | 2.91 → 2.96 (2.71) | pg18 → pg17 |
| 6593 | 2026-05-19 | 1.19.2/28.1.1 | feature | **checked** | - | - | - | 440 s (62.7 / 125.2 / 248.8) | 2.81 → 1.72 (9.29) | pg18 → pg17 |
| 6592 | 2026-05-19 | 1.19.2/28.1.1 | feature | **checked** | - | - | - | 411 s (33.6 / 119.2 / 247.6) | 0.96 → 1.47 (3.22) | pg18 → pg17 |
| 6556 | 2026-05-14 | 1.19.2/28.1.1 | feature | dropped | probe | `start_run_did_not_finish` | the pull request's | 91 s (53.2 / 29.9 / -) | 1.43 → 2.28 (3.95) | pg18 → pg17 |
| 6574 | 2026-05-13 | 1.19.2/28.1.1 | feature | **checked** | - | - | - | 461 s (76.5 / 111.2 / 262.8) | 2.97 → 1.55 (2.73) | pg18 → pg17 |
| 6582 | 2026-05-12 | 1.19.2/28.1.1 | bug fix | dropped | probe | `skipped_test` | the pull request's | 110 s (45.1 / 60.2 / -) | 1.55 → 4.33 (2.86) | pg18 → pg17 |
| 6576 | 2026-05-12 | 1.19.2/28.1.1 | feature | **checked** | - | - | - | 450 s (81.5 / 106.1 / 255.4) | 4.33 → 1.47 (4.4) | pg18 → pg17 |
| 6573 | 2026-05-11 | 1.19.2/28.1.1 | feature (by the rule: bug fix) | **checked** | - | - | - | 561 s (61.9 / 151.0 / 340.7) | 1.43 → 1.60 (2.37) | pg18 → pg17 |
| 6563 | 2026-05-08 | 1.19.2/28.1.1 | bug fix | dropped | probe | `no_existing_tests` | the pull request's | 171 s (42.2 / 124.1 / -) | 1.71 → 1.58 (2.09) | pg18 → pg17 |
| 6570 | 2026-05-08 | 1.19.2/28.1.1 | bug fix | dropped | probe | `skipped_test` | the pull request's | 110 s (59.2 / 44.4 / -) | 1.58 → 1.42 (1.96) | pg18 → pg17 |
| 6562 | 2026-05-08 | 1.19.2/28.1.1 | bug fix | **checked** | - | - | - | 410 s (53.5 / 127.6 / 226.4) | 1.38 → 1.50 (1.69) | pg18 → pg17 |

- **6608, 6599, 6556:** `start_run_did_not_finish`: the hidden tests do not finish on the unchanged project. The probes
  took under 37 s, far under the 600-second limit for a test command, so this is not a time-out; the engine keeps no output
  of the probe's runs, so the error is not readable (most likely the hidden tests do not compile without the fix, which
  the rules count as the pull request's own cause).
- **6706, 6625, 6582, 6570:** `skipped_test`: hidden tests the pull request adds or changes are marked skipped by the project, so no
  fix could pass them (the grader passes no skipped test).
- **6626, 6609, 6563:** `no_existing_tests`: no existing test file is left to protect once the ones that fail on the reference are
  left out.
- **6722, 6664:** checked while the load was above 12 ("not settled"). The checks passed, the engine's second round
  included; a passed case is not checked again for a load reading alone (`all.sh`'s closing loop runs again only a
  dropped case whose check was not settled, or one dropped at the second round).
- **The checked cases** (`checked.tsv`, from the engine's result of each):

| Case | Kind | Hidden tests failing first | Passing after | Existing test files kept | Left out | Partial fix | Second round agrees |
|---|---|---:|---:|---:|---|---|---|
| 6722 | feature | 5 | 76 | 2 | 1 (`fails_on_reference`) | present | yes |
| 6664 | feature | 10 | 113 | 4 | 0 | present | yes |
| 6639 | bug fix | 1 | 5 | 1 | 1 (`skipped_on_unchanged`) | present | yes |
| 6629 | bug fix | 2 | 46 | 2 | 0 | none | yes |
| 6623 | feature | 5 | 22 | 2 | 0 | present | yes |
| 6615 | bug fix | 5 | 18 | 2 | 0 | present | yes |
| 6611 | bug fix | 1 | 21 | 1 | 0 | present | yes |
| 6596 | feature | 34 | 95 | 6 | 0 | present | yes |
| 6601 | bug fix | 2 | 18 | 2 | 0 | present | yes |
| 6593 | feature | 1 | 34 | 2 | 0 | present | yes |
| 6592 | feature | 1 | 34 | 2 | 0 | present | yes |
| 6574 | feature | 9 | 34 | 1 | 0 | present | yes |
| 6576 | feature | 1 | 9 | 2 | 0 | present | yes |
| 6573 | feature (by the rule: bug fix) | 4 | 145 | 4 | 0 | present | yes |
| 6562 | bug fix | 3 | 13 | 1 | 1 (`fails_on_reference`) | present | yes |

- **The kinds** (`kind_rule.tsv`): the maker's label in `case.json` gives 9 features and 6 bug fixes; the maker's
  written rule (a feature when the fix adds a file or a public function it does not also remove), read one line at a
  time, gives 8 and 7. 6573 adds no file and no public function but is labelled a feature: the maker's reading lets
  `\s*` cross a line break, so an added blank line before an unchanged `def` counts as an added function (registry
  E108).

## 4. The candidates and why most are left out

The screening's list ([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)) names the
project's 150 newest candidates, all of them from the Gleam period. `run/list.sh` extends it backwards: every pull
request with the screen's verdict `candidate` merged since 2025-07-01 (535), each with what its starting commit needs,
read from the commit's own files; the toolchain resolver then ran on the 315 that need no Gleam and are on Elixir 1.18 or
newer (`run/resolve.exs`, `resolve.tsv`). Candidates merged before 2025-07-01 are all on Elixir 1.17 or older
(`.tool-versions`: 1.17.2 from 2024-07-29, 1.18.4 from 2025-07-31). `candidates.tsv` has every one with what this job
did with it; `left_out.tsv` counts them:

| Candidates | Reason | Whose cause |
|---:|---|---|
| 175 | `needs_program:gleam`: the starting commit has `gleam/gleam.toml`; the project compiles a Gleam package with the Gleam compiler and the `mix_gleam` archive, and its `deps.get` alias runs `gleam.deps.get`. The factory runs its own `mix deps.get` before any recipe step and installs a release file only as a `.deb` or a bare program, while Gleam ships as a `.tar.gz` (registry E111) | the factory's |
| 53 | `no_image:1.19.2/28.3.1` (merged 2026-01-29 to 2026-03-06) | the factory's (the image table) |
| 37 | `elixir_before_1.18` (Elixir 1.17.2) | the dataset's floor |
| 8 | no merge commit in the census | the census |
| 5 | `paths_never_match`: no first parent within 30 commits changes the census's paths (6719, 6440, 6145, 5849, 5848) | the factory's (the maker) |
| 257 | can be made: 176 on 1.19.2/28.1.1, 81 on 1.18.4/28.0.2; 25 tried, 232 not reached | - |

Kinds read ahead by the maker's rule (`run/kinds.sh`) among the 257: 150 features, 107 bug fixes.

## 5. The scans

The licence scan and the hold-out check (`factory/tools/check_tasks.sh` through `run/scans.sh`, one task at a time,
Hex metadata fetched) pass for all 15 checked cases (`scans.tsv`):

- **Licence:** the root licence is `LICENSE.md` (MIT, sha256 `696205ce…`) at every starting commit (`licence_root.tsv`);
  every file the 15 cases touch (143 files) passes at both commits (`licence_files.tsv`).
- **Hold-out:** 0 name hits; the shared runs of 8 and 12 words with the bench's cases are all `common`
  (`holdout_tasks.tsv`).
- **Dependencies that matter for sessions** (`deps_flagged.tsv`, rules section 6): `anubis_mcp` 0.13.1 (LGPL-3.0),
  `open_api_spex` 3.22.0 (MPL-2.0), `poison` 5.0.0 (0BSD), `eflame` 1.0.1 (licence unclear), `bcrypt_elixir` 3.3.2 and
  `poolboy` 1.5.2 (several licences, some outside the list), and eight with loose spellings of allowed licences. A
  session that quotes their files is dropped.

## 6. Files

| File | What |
|---|---|
| `tasks.tsv` | one line per try: merge date, Elixir/OTP, kind, verdict, step, reason, every step's time, load, images and disk, the CI's database and the one used |
| `counts.tsv` | pull requests per verdict, step and reason (last try) |
| `checked.tsv` | per checked case: hidden tests, existing test files kept and left out, partial fix, second round |
| `kind_rule.tsv` | per checked case: the kind in `case.json` and the kind by the maker's written rule read one line at a time |
| `candidates.tsv` | every candidate merged since 2025-07-01: versions and Gleam at its starting commit, the CI's database, the resolver's result, the kind read ahead, what this job did |
| `left_out.tsv` | the candidates left out without a try, per reason |
| `resolve.tsv` | the toolchain resolver's line for each of the 315 candidates it read |
| `project_tests.tsv`, `project_test_failures.tsv` | the project's whole suite |
| `scans.tsv`, `licence_files.tsv`, `licence_root.tsv`, `holdout_tasks.tsv`, `deps_flagged.tsv` | the two scans |
| `run/` | every script that ran (below) |

## 7. Exact commands

On the data-mining machine, as root, in the job's folder `JOB` (with `run/`, `src/` = this repository's `factory/` at
`686862f` plus the recipe, `tables/` with the screening's census and screen tables, and `oli-torus.git`, a bare clone);
`WORK` is the factory's work folder, `CTL` the controller's folder, `BENCH_CASES` the bench's `cases/` folder (read in
place). Git reads the clone through `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0=$JOB/oli-torus.git`.

```sh
SRC=$JOB/src OUT=$JOB/logs IMAGE=elixir-task-factory:olitorus-20261112 LABEL=task-factory-job=hb-olitorus \
  run/build.sh controller
CTL=$CTL NAME=factory-olitorus EPMD_PORT=4520 IMAGE=elixir-task-factory:olitorus-20261112 \
  HEX_CACHE_ID=etf-hex-packages-v1 LABELS=task-factory=1,task-factory-job=hb-olitorus SOURCES=$JOB \
  PREPARE_WORKERS=1 PREPARE_AHEAD=1 run/controller.sh up
CLONE=$JOB/oli-torus.git CENSUS=tables/prs_Simon-Initiative__oli-torus.tsv \
  SCREEN=tables/screen_Simon-Initiative__oli-torus.tsv SINCE=2025-07-01T00:00:00Z UNTIL=2026-11-13T00:00:00Z \
  REPO=Simon-Initiative/oli-torus run/list.sh > tables/list.tsv
CLASSES=<list.tsv without its header> CENSUS=tables/prs_Simon-Initiative__oli-torus.tsv CLONE=$JOB/oli-torus.git \
  run/kinds.sh > kinds.tsv
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-olitorus CACHE=<an empty folder> COPY= run/all.sh stage
git clone --bare --local $JOB/oli-torus.git $CTL/data/olitorus/cache/Simon-Initiative__oli-torus.git   # the maker's cache
# the resolver over the candidates that need neither Gleam nor an older Elixir (their numbers in $CTL/data/olitorus/numbers.txt)
CTL=$CTL NAME=factory-olitorus run/controller.sh rpc 'System.put_env(%{"P5_DIR" => "/data/olitorus", "REPOSITORY" => "https://github.com/Simon-Initiative/oli-torus", "CENSUS" => "prs_Simon-Initiative__oli-torus.tsv", "SCREEN" => "screen_Simon-Initiative__oli-torus.tsv"}); spawn(fn -> Code.eval_file("/data/olitorus/resolve.exs") end)'
# the whole suite at 6722's starting commit
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/oli-torus.git NAME=factory-olitorus NUMBER=6722 \
  MERGE=cc96d5e71f64ec31db36441795fb77f03262ceb6 ROUNDS=1 TEST_TIMEOUT=3600 SUB=env OUT=$JOB/out/suite CTL=$CTL \
  JOB_LABEL=task-factory-job=hb-olitorus TASK_LABEL=task-factory=1 MAX_LOAD=26 MIN_FREE=50000000000 run/suite.sh
D=$CTL/data/env OUT=$JOB/out/suite_tables ROUNDS=1 run/suite_tables.sh
# the cases (numbers.txt: the 257 that can be made, newest merged first), and beside them the scans; phase 1 with
# TARGET=10, then (both kinds had 5 of the 10) phase 2 with TARGET=20 in the same OUT, where a tried number is not run again;
# at 21:38 every untried number was put on the hold list (OUT/hold.txt), so the driver ended after the check that was
# running
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-olitorus JOB_LABEL=task-factory-job=hb-olitorus TASK_LABEL=task-factory=1 \
  TARGET=10 MAX_TRIED=80 MAX_LOAD=26 MIN_FREE=50000000000 run/all.sh run
JOB=$JOB T=$JOB WORK=$WORK BENCH_CASES=$BENCH_CASES run/follow.sh
# the tables
OUT=$JOB/out NUMBERS=$JOB/numbers.txt PREFIX=oli-torus TASKDIR=$CTL/data/olitorus/tasks \
  SCREEN_TSV=$JOB/tables/screen_Simon-Initiative__oli-torus.tsv JOB_LABEL=task-factory-job=hb-olitorus RUN=$JOB/run \
  run/tables.sh
OUT=$JOB/out SCANS=$JOB/out/scans LIST=$JOB/tables/list.tsv RESOLVE=$JOB/tables/resolve.tsv KINDS=$JOB/kinds.tsv \
  SUITE=$JOB/out/suite_tables TASKDIR=$CTL/data/olitorus/tasks DEST=<this folder> run/pub.sh
run/kind_rule.sh $WORK/tasks/Simon-Initiative__oli-torus > <this folder>/kind_rule.tsv
```

The scripts are those of [2026-11-12_cases_hexpm_hexpm](../2026-11-12_cases_hexpm_hexpm/README.md) for this project,
with these changes: `list.sh`, `follow.sh` and `pub.sh` are new; `resolve.exs` is the one of
[2026-11-12_maker_toolchain](../2026-11-12_maker_toolchain/README.md); `suite_tables.sh` also reads the summary line
Elixir 1.19 and 1.18 print; `watch.sh` stops at 50,000,000,000 free bytes and a load above 26 by default; `all.sh`'s
closing loop runs again only a dropped case (section 3).

## Provenance and licence

The cases are cut from `Simon-Initiative/oli-torus` (MIT, `LICENSE.md`); no title, body or patch text of a pull request
is published here, only numbers, dates, paths and counts. The tables are this job's own output.
