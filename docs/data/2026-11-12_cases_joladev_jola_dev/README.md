# joladev/jola.dev: the project's set-up in the task factory, and its checked cases (2026-11-12)

Registry rows [E68](../../../experiments.md) (the pilot of the task factory) and E82. `joladev/jola.dev` is one of the
dataset's 16 applications ([rules](../../dataset_rules.md)). This job wrote the project's recipe, ran the project's
whole test suite once through the engine, and made and checked all its candidates one at a time, newest merged first,
through a controller built from this repository's `main` at `044f52c`, on the data-mining machine (28 threads, 30 GiB,
no GPU), while other task-making jobs and one job that uses the model shared the machine. Times are the data-mining
machine's (UTC+1).

## Result

- **3 cases count, all 3 features** (54, 42 and 40), of the project's 7 candidates, all tried (`checked.tsv`). Each
  is checked by the engine, passes the licence scan (every touched file `ok`, the project's MIT `LICENSE`) and passes
  the hold-out check (40 after its shared runs were read: section 4). The list ends here: the project has no further
  candidate.
- **The project has 7 candidates, all on Elixir 1.18 or newer** (the screening's list,
  [2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)). Its other 169 merged pull
  requests change no code (153), change code without a test (12) or change `mix.exs`/`mix.lock` (4). 105 of the
  project's 273 commits are a bot's dependency updates. No candidate contains another (each merge has one parent; no
  side branch), so none is `contains_other_candidates`.
- **Left out: 4, all the pull requests' own causes** (`counts.tsv`): 47 refused by the maker as `no_existing_tests`,
  13 and 10 at the probe as `no_existing_tests`, 37 at the probe as `no_starting_failure` (section 3). None was the
  machine's or the factory's, and none points to the database version: the project uses no database.
- **The data store:** none. At every candidate's starting commit `mix.lock` holds no Ecto adapter and no database
  driver (`versions.tsv`, `database_client`); the blog's posts are Markdown files under `priv/posts/` compiled into the
  application. The two oldest candidates' CI file still starts `postgres:12` (from the Phoenix template), unused.
- **The whole suite passes** at the newest candidate's starting commit (pull request 54), on Elixir 1.19.5 with OTP
  28.3.2: ExUnit's summary **98 tests, 0 failures, in 0.6 s** (the engine's run 2.0 s). Prepared cold in 128.5 s.
- **A check took 161 s, 221 s and 180 s** for the 3 checked cases (the driver's wall time; the engine's own totals
  158.9 s, 211.6 s and 178.5 s); a drop at the probe took 61 s to 120 s; making a case took 5 s or 6 s. The whole run,
  7 candidates, took 15 min 34 s (19:44:51 to 20:00:25). Every check was settled (the 1-minute load stayed under 12),
  so no check was run a second time.

## 1. The project's set-up

The recipe is [`factory/recipes/joladev__jola.dev.json`](../../../factory/recipes/joladev__jola.dev.json), a template:
the toolchain resolver reads each starting commit's own Elixir and OTP (`resolve.tsv`). The two oldest candidates use
the fixed recipe [`recipe_ci_postgres12.json`](recipe_ci_postgres12.json) (below).

| What | Value | Where it comes from |
|---|---|---|
| Elixir and OTP | 1.19.5 and 28.3.2 for 54 and 47; 1.18.4 and 28.0.2 for 42, 40, 37, 13 and 10 (`hexpm/elixir:...-ubuntu-noble-20260509.1` images, pinned by digest, both already on the machine) | each commit's `.tool-versions` (`erlang` line for the OTP), matched exactly in the image table; the CI file names the same pairs |
| Database | none for 54 to 37; Postgres 18.6 (`postgres:18.6-alpine`, pinned by digest) for 13 and 10 | the CI file of 54 to 37 starts no service. The CI file of 13 and 10 starts `postgres:12`; the table has no Postgres 12, so the resolver refuses them (`no_service_image:postgres/12`) and the fixed recipe gives them the table's newest line (rules, section 2). The project uses no database at any of these commits, so Postgres runs beside the tests unused; both versions are recorded in `versions.tsv` |
| Database commands | none | nothing to create or migrate |
| System packages | `fontconfig`, `fonts-inter` (Ubuntu's) | the project renders its Open Graph images at compile time with the `image` package (libvips) in the font "Inter" (at the starting commits of 40 and newer); its own `Dockerfile` installs `fonts-inter` for that. The engine installs them with `apt-get install --no-install-recommends` in the toolchain stage |
| Build | `mix compile` after the engine's own dependency steps | the bench's default recipe |
| Whole-suite command | `mix test` | the CI workflow's test step |
| Excluded tags | none | `test/test_helper.exs` is `ExUnit.start()` |

**What the build fetches by itself.** Besides its Hex packages, the project's own dependencies fetch, with no change to
the recipe: the git dependencies `heroicons` (`tailwindlabs/heroicons`, tag v2.2.0) and `lucide`
(`lucide-icons/lucide`, a tag pinned by `mix.lock`), and the prebuilt native files of `lazy_html` (test only; versions
0.1.5, 0.1.6 and 0.1.11 across the commits) and `vix` 0.38.0 (with libvips; at the starting commits of 40 and newer) from their GitHub release pages
through `elixir_make`, each checked by its package's own checksum file. No release file and no other download was
needed. The engine has no switch for build jobs; every workspace container runs Erlang with 2 schedulers.

## 2. The project's own suite

A hand-made probe task for pull request 54 (`run/make_probe.sh`, with its own id and a 900-second limit for one test
command) was prepared through the controller (`run/prepare.exs`) in 128.5 s cold (the toolchain image with the two
packages, the workspace image), and the whole suite ran once through the engine's own runner (`run/tests.exs`), in a
fresh workspace container with no network. `project_tests.tsv`:

| Run | ExUnit tests | Passed | Failed | Skipped | Excluded | ExUnit time | Engine time | Return code | Output | Engine: passed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 98 | 98 | 0 | 0 | 0 | 0.6 s | 2.0 s | 0 | 15,057 bytes | yes (98 records, all distinct) |

No test fails, none is skipped. The suite is small and fast: the blog has no database, and its tests render pages,
feeds and images in memory.

## 3. The candidates

All 7, newest merged first, from the screening's list, one at a time: made with the bundle maker through the controller
(`run/make_one.exs`), imported with `factoryctl import`, checked with `factoryctl check --concurrency 1`, and a checked
case exported to the factory's task folder (`run/one.sh`, driven by `run/all.sh`; 13 and 10 from the second list
folder with the fixed recipe, `lists.tsv`). `tasks_jola_dev.tsv` has one line per try with every column; the engine's
step times are in seconds.

| Pull request | Merged | Elixir/OTP | Kind (case.json) | Verdict | Step | Reason | Check (prepare / probe / controls) | Load start → end (highest) | Bytes used on disk (all jobs) |
|---|---|---|---|---|---|---|---|---|---:|
| 54 | 2026-05-24 | 1.19.5/28.3.2 | feature | **checked** | - | - | 161 s (64.4 / 34.4 / 60.1) | 6.37 → 5.86 (6.87) | 2,553,446,400 |
| 47 | 2026-05-17 | 1.19.5/28.3.2 | - | refused | maker | `no_existing_tests` | - (made in 5 s) | 7.15 → 6.82 (-) | 138,629,120 |
| 42 | 2026-05-13 | 1.18.4/28.0.2 | feature | **checked** | - | - | 221 s (129.2 / 40.7 / 41.7) | 7.39 → 5.65 (7.25) | 4,160,241,664 |
| 40 | 2026-05-12 | 1.18.4/28.0.2 | feature | **checked** | - | - | 180 s (60.9 / 59.7 / 57.9) | 6.80 → 4.90 (6.66) | 903,000,064 |
| 37 | 2026-05-11 | 1.18.4/28.0.2 | bug fix | dropped | probe | `no_starting_failure` | 61 s (50.8 / 8.0 / -) | 4.90 → 5.33 (5.09) | 146,898,944 |
| 13 | 2025-08-12 | 1.18.4/28.0.2, Postgres 18.6 for CI's 12 | bug fix | dropped | probe | `no_existing_tests` | 120 s (88.8 / 22.6 / -) | 5.33 → 4.62 (5.4) | 852,144,128 |
| 10 | 2025-08-10 | 1.18.4/28.0.2, Postgres 18.6 for CI's 12 | bug fix | dropped | probe | `no_existing_tests` | 110 s (73.9 / 33.4 / -) | 5.61 → 5.34 (6.44) | 1,018,433,536 |

The bytes are the fall in free space on the system disk during the try, with every job's use in it; the images this
job's label added per try, by Docker's sizes (which overlap), are in `tasks_jola_dev.tsv` (`own_images`,
`own_images_docker_bytes`).

- **47, `no_existing_tests` at the maker:** it adds a new module and its new test file and changes one line each in the
  configuration and the endpoint; no existing test file is changed, and none matches a changed code file by path. The pull request's
  own cause.
- **13 and 10, `no_existing_tests` at the probe:** each changes behaviour that its own test files already checked, and
  changes those files with it. The starting-commit versions of those files fail on the merged code
  (`fails_on_reference`: `test/jola_dev_web/plugs/blog_redirect_test.exs` for 13;
  `test/jola_dev_web/controllers/blog_controller_test.exs` and `.../error_html_test.exs` for 10), so no existing test
  is left to protect. The pull requests' own cause; the database plays no part.
- **37, `no_starting_failure`:** its code change adds one response header to the RSS feed; its test change rewrites two
  assertions of the blog's post and tag lists in another module, which pass on the unchanged project. Its tests do not
  test its change. The pull request's own cause.
- **The checked cases** (`checked.tsv`, from the engine's result of each case's checked try):

| Case | Kind | Hidden tests failing first | Passing after | Existing test files kept | Left out (`fails_on_reference`) | Partial fix | Second round agrees | Licence | Hold-out |
|---|---|---:|---:|---:|---:|---|---|---|---|
| 54 | feature | 6 | 36 | 4 | 2 | present | yes | pass (`LICENSE`) | pass |
| 42 | feature | 10 | 18 | 2 | 3 | present | yes | pass (`LICENSE`) | pass |
| 40 | feature | 18 | 20 | 1 | 2 | present | yes | pass (`LICENSE`) | pass after reading |

- **The kinds:** the maker's kind in `case.json` matches its written rule read one line at a time for all 6 made
  folders (`kind_rule.tsv`, `run/kind_rule.sh`) and the read-ahead of `kinds.tsv`. 54 adds a public function
  (`canonical_url`); 42 adds a file and public functions; 40 adds two files (a catalog of images and a plug that serves
  them) and removes a controller. The project's own titles call all three improvements; none is plainly a bug fix, so
  no label is wrong here (registry E108). The project's 3 bug fixes are all left out, so its cases are 3 features and 0
  bug fixes.
- **Marks for reporting** (the screening's table): none of the 3 carries the AI-tool mark, adds a migration or changes
  assets.

## 4. Licence and hold-out

Run on each checked case, one at a time (`run/run_scans.sh`, which calls `run/scans.sh` and through it
`factory/tools/check_tasks.sh` of `main` at `044f52c`), in a Python container with no network; Hex metadata was fetched
for the dependency list. `scans.tsv`, `licence_root.tsv`, `licence_files.tsv`, `holdout_tasks.tsv`,
`deps_flagged.tsv`, `holdout_reviews.tsv`:

| Case | Licence scan | Root licence | Files touched | Files passing | Hold-out | Shared 8-word runs (`common` / `syntax` / own tree / to read) | 12-word runs (to read) |
|---|---|---|---:|---:|---|---|---:|
| 54 | pass | `LICENSE`, MIT | 21 | 21 | pass | 3 (3 / 0 / 0 / 0) | 0 |
| 42 | pass | `LICENSE`, MIT | 12 | 12 | pass | 3 (3 / 0 / 0 / 0) | 0 |
| 40 | pass | `LICENSE`, MIT | 12 | 12 | review, read: pass | 14 (3 / 3 / 1 / 7) | 4 (4) |

- **The licence:** the project's `LICENSE` (MIT, "Copyright (c) 2025 Johanna Larsson") is in its first commit
  (2025-08-04) and at every candidate's starting commit, so no candidate is older than the licence and the rule for a
  licence stated later (rules, section 9) is not needed. Every touched file is `ok` at both commits, including the
  blog posts under `priv/posts/` that 54 touches; none carries another licence notice and none is left out for its
  length.
- **Hold-out:** the repository is not held out and no case names a held-out project. 40's change shares 7 runs of 8
  words and 4 of 12 words with the documentation patch of the bench's `guardian-pr-748`. They were read on the machine
  (the shared text was then deleted): every one is the standard opening of a Plug module, the same in both (the
  behaviour line for Plug, the import of `Plug.Conn`, an `init/1` marked as the Plug callback that returns its options
  unchanged). That is boilerplate, not code taken from a held-out project, so 40 counts (`holdout_reviews.tsv`, one row
  per run; `run/checked.sh` reads it). The other shared runs are `common` (the task format's own fields) or `syntax`.
- **The locked dependencies:** every Hex package's licence is in the list. The tool does not read the licence of the
  two git dependencies, `heroicons` (locked by all 3 cases) and `lucide` (two commits across the cases). They matter for
  sessions (rules, section 6), not for the cases.

## 5. How the run went

1. **The set-up** (19:37 to 19:44): read-only checks (no bench run; load 4.00; 574,087,176,192 free bytes on `/`), the
   project's clone, the controller image (`elixir-task-factory:joladev-20261112`, `run/build.sh`, 16 s: 6 steps cached, the factory's own package
   steps ran again), the controller (`run/controller.sh up`), the two list folders staged (`run/all.sh stage`), the
   resolver over the 7 (`run/resolve.exs`), and the whole suite on a probe (`run/suite.sh`).
2. **The cases** (19:44:51 to 20:00:25): `run/all.sh run`, `TARGET=20`, `MAX_TRIED=80`, as the controller's user
   (root: the engine writes its job records readable by root only). The list ran out at 7; no second check was needed.
3. **The scans** (20:00:54 to 20:01:27), the hold-out reading of 40, and the tables (`run/tables.sh`,
   `run/versions.sh`, `run/checked.sh`, `run/kind_rule.sh`, `run/pub.sh`).

## 6. Disk and load

- **The engine's own limits:** one preparation worker and one check at a time (`--concurrency 1`). Every container
  carried the labels `task-factory=1` and `task-factory-job=hb-joladev` and a CPU share of 256.
- **The load:** the watcher's 92 samples of the 1-minute load during the cases reached at most 7.25 (19:48:49); no stop
  rule fired (free bytes never under 50,000,000,000; load never above 26) and no bench run started.
- **Disk:** free bytes on the system disk 574,087,176,192 at the start and 554,502,623,232 at the end, with every job's
  use in it. This job's label was on 27 image tags (12 distinct images) at the end: 9 toolchain, 7 project and 7 seed
  (workspace), 2 Postgres snapshots, 2 layout. The controller's folder held 21,288,776 bytes, the job's folder
  27,455,557 bytes (with the project's clone), and the 3 exported case folders 113,136 bytes.

## Files

| File | What it holds |
|---|---|
| `resolve.tsv` | the toolchain resolver's line for each of the 7 candidates with the factory's own table: the Elixir and OTP each commit names and where, the image, the services, the refusal (`no_service_image:postgres/12` for 13 and 10) |
| `versions.tsv` | per candidate: the Elixir and OTP named and the image used, the recipe (template or fixed), the Postgres its CI file starts and the one used, and the database client in `mix.lock` (none) |
| `recipe_ci_postgres12.json` | the fixed recipe for 13 and 10 |
| `kinds.tsv` | the 7 candidates in order: merge date, starting and merge commits, the screening's need, and the kind read ahead by the maker's rule, with the files and public functions the fix adds |
| `project_tests.tsv` | the whole-suite run: the engine's verdict and counts, ExUnit's summary, the output's size |
| `tasks_jola_dev.tsv` | one line per try: number, id, merge date, Elixir/OTP, kind, folder origin, verdict, step, reason, the driver's step times, the engine's step times, load at start and end and the highest during the check, settled, the bytes of every image the machine gained meanwhile (all jobs'; images share layers), the build cache's change, the disk bytes used (all jobs'), start, end, and this job's own images and their bytes |
| `counts.tsv` | pull requests per verdict, step and reason |
| `checked.tsv` | per checked case: kind, the try, hidden tests failing first and passing after, existing test files kept and left out, the partial fix, the second round, the licence scan's result and root licence, files touched and passing, the licence route, the hold-out result before and after reading, and whether the case counts |
| `kind_rule.tsv` | per made folder: the kind in `case.json`, the kind by the maker's written rule read one line at a time, the files and public functions the fix adds |
| `scans.tsv` | per case: the licence scan's file, families, files touched and passing, result; the hold-out check's name hits, shared runs and result; the locked dependencies by licence class |
| `licence_root.tsv` | per case: the licence scan's columns with the root licence |
| `licence_files.tsv` | per case and touched file: which patches touch it, the scan's verdict at the starting and the merge commit, the result |
| `holdout_tasks.tsv` | per case: the repository check, name hits, and the shared 8- and 12-word runs by class |
| `holdout_reviews.tsv` | per shared run of 40 marked to read: the files, the bench case, the run's id and the reading |
| `deps_flagged.tsv` | the locked dependencies whose licence is not plainly in the list, with the number of cases that lock each |
| `run/` | the scripts that ran (below) |

## Commands

On the data-mining machine, as root (the engine's job records are readable by root only). `WORK` is the factory's
work folder (with `tasks/`), `JOB` this job's folder (with `run/`, `src/` = this repository's `factory/` at `044f52c`
plus this recipe, `tables/` = the screening's census, screen and class tables of jola.dev, `numbers.txt` = the 7
candidates newest first, `lists.tsv` = "13 joladev-pg18" and "10 joladev-pg18", `recipe_ci_postgres12.json`,
`joladev.git` = a bare clone of the project, `cache/joladev__jola.dev.git` = a copy of it owned by root), `CTL` the
controller's folder, `BENCH` the bench's `cases/` folder (read in place).

```sh
SRC=$JOB/src OUT=$JOB/out IMAGE=elixir-task-factory:joladev-20261112 LABEL=task-factory=1 run/build.sh controller
CTL=$CTL NAME=factory-joladev SOURCES=$JOB IMAGE=elixir-task-factory:joladev-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-joladev EPMD_PORT=4528 PREPARE_WORKERS=1 PREPARE_AHEAD=1 \
  run/controller.sh up
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-joladev CACHE=$JOB/cache run/all.sh stage
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-joladev CACHE=$JOB/cache LIST=joladev-pg18 \
  RECIPE_FILE=$JOB/recipe_ci_postgres12.json run/all.sh stage

# the resolver over the 7, with the factory's own table (numbers.txt and resolve.exs copied into CTL/data/joladev)
CTL=$CTL NAME=factory-joladev run/controller.sh rpc 'System.put_env(%{"P5_DIR" => "/data/joladev",
  "REPOSITORY" => "https://github.com/joladev/jola.dev", "CENSUS" => "prs_joladev__jola.dev.tsv",
  "SCREEN" => "screen_joladev__jola.dev.tsv"}); spawn(fn -> Code.eval_file("/data/joladev/resolve.exs") end)'
# (written as one line in the call)

# the whole suite once at the starting commit of pull request 54 (merge commit e16aad0d)
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/cache/joladev__jola.dev.git NAME=factory-joladev NUMBER=54 \
  MERGE=e16aad0d319ac721124b528c6a505b8a0e7a12f9 ROUNDS=1 TEST_TIMEOUT=900 SUB=env OUT=$JOB/out/suite CTL=$CTL \
  JOB_LABEL=task-factory-job=hb-joladev TASK_LABEL=task-factory=1 MAX_LOAD=26 MIN_FREE=50000000000 run/suite.sh
D=$CTL/data/env OUT=$JOB/out/suite ROUNDS=1 run/suite_tables.sh

# the candidates' kinds read ahead (as the work user, who owns the clone)
CLASSES=$JOB/tables/classes_joladev.tsv CENSUS=$JOB/tables/prs_joladev__jola.dev.tsv CLONE=$JOB/joladev.git \
  run/kinds.sh > $JOB/kinds.tsv

# the cases: newest first, until 20 count, 80 are tried or the list ends (it ended at 7)
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-joladev JOB_LABEL=task-factory-job=hb-joladev TASK_LABEL=task-factory=1 \
  TARGET=20 MAX_TRIED=80 MAX_LOAD=26 MIN_FREE=50000000000 run/all.sh run

# the licence scan and the hold-out check, one case at a time (scan_ids.txt: the checked case ids)
JOB=$JOB CLONE=$JOB/cache/joladev__jola.dev.git DEST=$WORK/tasks/joladev__jola.dev IDS=$JOB/out/scan_ids.txt \
  BENCH_CASES=$BENCH LABELS=task-factory=1,task-factory-job=hb-joladev run/run_scans.sh
# 40 once more with the shared text kept for reading (LOCAL_spans.json, deleted after reading)
WORK=$JOB/out/scans_review/jola-dev-pr-40 CLONES=$JOB/cache/joladev__jola.dev.git BENCH_CASES=$BENCH HEX_FETCH=1 \
  DOCKER_RUN_ARGS='--cpu-shares 256 --label task-factory=1 --label task-factory-job=hb-joladev' \
  LOCAL_SPANS=$JOB/out/scans_review/jola-dev-pr-40/LOCAL_spans.json \
  $JOB/src/tools/check_tasks.sh $WORK/tasks/joladev__jola.dev/jola-dev-pr-40

# the tables (out/made: a copy of the made folders of both lists; licence_authors_none.tsv: the header only, as no
# candidate is older than the licence)
RESOLVE=$JOB/out/resolve.tsv CLONE=$JOB/cache/joladev__jola.dev.git LISTS=$JOB/lists.tsv \
  FIXED=$JOB/recipe_ci_postgres12.json TASKDIRS="$CTL/data/joladev/tasks $CTL/data/joladev-pg18/tasks" \
  run/versions.sh > $JOB/out/versions.tsv
OUT=$JOB/out NUMBERS=$JOB/numbers.txt PREFIX=jola-dev TASKDIR=$JOB/out/made \
  SCREEN_TSV=$JOB/tables/screen_joladev__jola.dev.tsv JOB_LABEL=task-factory-job=hb-joladev RUN=$JOB/run run/tables.sh
OUT=$JOB/out DEST=$WORK/tasks/joladev__jola.dev SCANS=$JOB/out/scans AUTHORS=$JOB/out/licence_authors_none.tsv \
  REVIEWS=$JOB/holdout_reviews.tsv run/checked.sh > $JOB/out/tables/checked.tsv
run/kind_rule.sh $JOB/out/made > $JOB/out/tables/kind_rule.tsv
OUT=$JOB/out DEST=$JOB/pub run/pub.sh
CTL=$CTL NAME=factory-joladev run/controller.sh stop
```

`run/` holds source-academy/backend's `all.sh` (two list folders; this project's names), `one.sh`, `row.sh`,
`watch.sh`, `controller.sh`, `build.sh`, `state.sh`, `make_one.exs`, `make_probe.sh`, `prepare.exs`, `tests.exs`,
`suite.sh` and `env_tests.sh` (this project's names); croniq's `suite_tables.sh`, `table.sh`, `tables.sh`, `scans.sh`,
`run_scans.sh`, `kinds.sh`, `kind_rule.sh`, `pub.sh`, `resolve.exs` and `read_large_file_hunks.py` (not needed: no
long file); `checked.sh` (croniq's, which now also reads a table of hold-out readings); and `versions.sh`, written
again for this project (two recipes, the database client).

## Licence

The tables hold pull request numbers, dates, commits, version pairs, reason names, test file paths, file paths of the
project, the licence holder's name as the project's licence file gives it, times and byte counts; no code, title, body
or patch text of the project. jola.dev is under the MIT licence (its `LICENSE` file, in the project's first commit).
