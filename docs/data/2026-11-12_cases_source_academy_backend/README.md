# source-academy/backend: the project's set-up in the task factory, and its checked cases (2026-11-12)

`source-academy/backend` (the Phoenix and Ecto application behind Source Academy, Apache-2.0) is one of the dataset's 16
applications ([rules](../../dataset_rules.md)). This job wrote the project's recipe, ran the project's whole test suite
once through the engine, and made and checked every candidate on Elixir 1.18 or newer, newest merged first, one at a
time, through its own controller built from this repository's `main` at `60b1a65`. Everything ran on the data-mining
machine (28 threads, 30 GiB, no GPU), shared with other task-making jobs and one job that uses the model. Times are
that machine's (UTC+1).

## Result

- **4 cases are checked and pass both scans:** 1386, 1385, 1330 and 1247. By kind: **3 bug fixes and 1 feature**
  (1330); the maker's `task_kind` and its rule read one line at a time agree for all four (`kind_rule.tsv`).
- **20 cannot be reached: the project has only 13 candidates on Elixir 1.18 or newer.** The screening took 39
  candidates since 2024; 25 of them start on Elixir 1.13.4, and so does 1151, which the screening listed as 1.18.3
  (its starting commit's CI names 1.13.4 with OTP 25.3.2; `versions.tsv`). Everything older is older still. All 13 were
  tried.
- **Left out:** 8 for the pull requests' own causes, 1 for the factory's, none for the machine's (after a second try):
  `start_run_did_not_finish` 2, `no_starting_failure` 2, `binary_file` 1, `no_test_names` 1, `no_existing_tests` 1,
  `reference_regression_fails` 1 (the pull requests'); `unsupported_path` 1 (the factory's: the engine's patch check
  refuses a `#` in a path, and the project names its recorded HTTP replies `name#1.json`); `elixir_before_1.18` 1
  (1151, not made). `counts.tsv`, section 3.
- **The project needs no extra package and no service but Postgres.** Its build needs one setting in the recipe: a
  test-only dependency (`git_hooks`) installs Git hooks while it compiles and fails outside a Git checkout, and the
  engine compiles the dependencies before it makes the workspace a Git checkout (section 1).
- **The whole suite passes** at 1386's starting commit, on Elixir 1.19.5 with OTP 28.5 and Postgres 18.6: ExUnit's
  summary **1,153 tests, 0 failures, 0 excluded, in 87.5 s**; the engine's record is complete (1,153 records, all
  distinct).
- **Six candidates name Postgres 17.4 in their CI**, which the factory's table lacks; they were checked on Postgres 18.6
  as the rules allow (section 2 of the rules, "The database and the cache"), with both versions recorded
  (`versions.tsv`). One of them, 1247, is among the 4 cases; none of the five others was left out for a reason that
  points to the database version (section 3).
- **One check took 310 s, 400 s, 281 s, 161 s, 471 s and 161 s** for the tries that ended checked (1386; 1385's second
  try; 1330 twice; 1247 twice). The run took 1 h 13 min 32 s (18:07:43 to 19:21:15), 19 tries of 13 pull requests.
- **Both scans pass for the 4:** the project's `LICENSE` file is the Apache License 2.0, all 35 touched files pass
  at both commits, and the hold-out check finds no name and no run that needs reading (section 4).

## 1. The project's set-up

The recipe is [`factory/recipes/source-academy__backend.json`](../../../factory/recipes/source-academy__backend.json), a
template: the toolchain resolver reads each commit's Elixir, OTP and Postgres from the commit's own files.

| What | Value | Where it comes from |
|---|---|---|
| Elixir and OTP | 1.19.5 with OTP 28.5 (the four newest candidates), 1.19.5 with OTP 28.3.1 (1349, 1346, 1330) | `.tool-versions` where the commit has one (its `erlang` line wins over CI's `OTP_VERSION: 28.3.1`), else the CI workflow's `ELIXIR_VERSION`/`OTP_VERSION` |
| Database | Postgres 18.6 (`postgres:18.6-alpine`, pinned by digest) | the CI workflow starts `postgres:18.1` to `postgres:18.4` (the table's Postgres 18 line) |
| Other services | none | no Redis client in `mix.exs`; the CI starts only Postgres |
| System packages | none | |
| Environment | `MIX_ENV=test`, and `ERL_AFLAGS=-eval application:set_env(git_hooks,auto_install,false,[{persistent,true}])` | see below |
| Database commands | `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the project's `test` alias (`ecto.create --quiet`, `ecto.migrate`, `test`) |
| Build | `mix compile` after the engine's own dependency steps | the bench's default recipe |
| Whole-suite command | `mix test` | the CI workflow's test step (`mix coveralls.github`, the same tests with coverage) |
| Excluded tags | none | the project's `test_helper.exs` excludes nothing |

**The one setting.** `git_hooks` 0.9.0 (a dependency for `:dev` and `:test`) installs the project's Git hooks in its
module body when it compiles, unless its `auto_install` setting is false, and raises when the folder is not inside a Git
working tree. The engine's workspace image compiles the dependencies (`mix deps.loadpaths`) before its last step makes
the workspace a Git checkout, so the first preparation failed after 69.4 s: "git_hooks: /workspace/deps/git_hooks is
not inside a git working tree". The project's CI runs in a Git checkout and does not meet this. The recipe sets
`auto_install` to false through `ERL_AFLAGS`, which the Erlang runtime reads before Elixir starts, so the setting is in
place when Mix compiles the package; `ERL_FLAGS` comes after Elixir's own start on the command line and was tested to
leave the setting unset. The engine's own `ERL_FLAGS` (`+S 2:2`) stays. Nothing of the project's code, tests or
configuration changes; only the hook installation is skipped. That the engine compiles dependencies before the
workspace is a Git checkout is the factory's fault; it is written down here, not changed.

What the build fetches: only Hex packages, as `mix.lock` pins them (110 lines, no Git dependency, no release file).

**The six older candidates** (1247, 1288, 1284, 1281, 1270, 1268) start on Elixir 1.18.3 with OTP 27.3.3 and a CI
that starts `postgres:17.4`; the factory's table has Postgres 10, 14 and 18, so the resolver refuses them
(`no_service_image:postgres/17.4`), and a recipe cannot change that for a template. They were made with a second
recipe, [`recipe_ci_postgres17.json`](recipe_ci_postgres17.json): the same fields with a fixed image (Elixir 1.18.3,
OTP 27.3.3, the table's line) and Postgres 18.6, and no `toolchain` block, so the maker takes its values as they are.
`run/all.sh` stages it as a second list folder and uses it for the numbers in `lists.tsv`. Every one of the six names
Elixir 1.18.3 and OTP 27.3.3 in its CI, read before it was made (`versions.tsv`).

## 2. The project's own suite

A hand-made probe task for pull request 1386 (`run/make_probe.sh`, with its own id and a 1,800-second limit for one
test command) was prepared through the controller (`run/prepare.exs`) in 108.2 s (the engine's own step 108.1 s: the
toolchain image, the workspace image, the Postgres database with the project's migrations), and the whole suite ran
once through the engine's own runner (`run/tests.exs`), in a fresh workspace container with a fresh database and no
network. `project_tests.tsv`:

| Run | ExUnit tests | Passed | Failed | Excluded | ExUnit time | Engine time | Return code | Output | Engine: finished |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 1,153 | 1,153 | 0 | 0 | 87.5 s (9.8 s async, 77.6 s sync) | 89.0 s | 0 | 242,109 bytes | yes (1,153 records, all distinct) |

The first preparation, without the setting of section 1, failed at the dependency step and ran no test.

## 3. The candidates

The screening's list (newest merged first, each with its Elixir/OTP and what else it lacks): 14 candidates since 2024
on Elixir 1.18 or newer by the screening's reading, 13 by their starting commits' own files. `numbers.txt` held the
13 newest first; `run/all.sh` ran each through `run/one.sh` (made by the bundle maker, imported, checked with
`factoryctl check --concurrency 1`, exported), then ran once more every one whose check was not settled (the 1-minute
load reached 12 during it). Three of those, whose drop had already been read in full by hand as the pull request's own
(below), were held from the second try (`out/hold.txt`). `tasks_backend.tsv` has every try with its step times, loads
and bytes; `versions.tsv` the versions named and used.

| Pull request | Merged | Kind | Elixir/OTP used | Postgres: CI / used | Verdict (last try) | Step, reason | Whose | Check (s), each try | Load start → end (highest), each try |
|---|---|---|---|---|---|---|---|---|---|
| 1386 | 2026-11-10 | bug fix | 1.19.5/28.5 | 18.4 / 18.6 | **checked** | | | 310 | 7.83 → 10.06 (11.6) |
| 1385 | 2026-09-05 | bug fix | 1.19.5/28.5 | 18.4 / 18.6 | **checked** | try 1: probe, `reference_run_did_not_finish` | try 1: the machine's | 240; 400 | 10.94 → 13.70 (15.81); 10.93 → 9.08 (12.06) |
| 1382 | 2026-08-13 | feature | 1.19.5/28.5 | 18.4 / 18.6 | dropped | probe, `start_run_did_not_finish` | the pull request's | 220 | 13.70 → 14.44 (17.05) |
| 1361 | 2026-08-01 | | | 18.4 / – | refused | maker, `binary_file` | the pull request's | | 14.44 → 14.16 |
| 1349 | 2026-05-06 | | | 18.3 / – | refused | maker, `unsupported_path` | the factory's | | 13.67 → 13.85 |
| 1346 | 2026-05-06 | feature | 1.19.5/28.3.1 | 18.3 / 18.6 | dropped | probe, `start_run_did_not_finish` | the pull request's | 281 | 15.55 → 13.10 (15.1) |
| 1330 | 2026-02-12 | feature | 1.19.5/28.3.1 | 18.1 / 18.6 | **checked** | | | 281; 161 | 13.49 → 11.17 (13.11); 9.16 → 8.61 (11.09) |
| 1247 | 2025-11-04 | bug fix | 1.18.3/27.3.3 | 17.4 / 18.6 | **checked** | | | 471; 161 | 11.16 → 11.23 (15.1); 9.44 → 8.71 (10.67) |
| 1288 | 2025-08-19 | bug fix | 1.18.3/27.3.3 | 17.4 / 18.6 | dropped | probe, `no_existing_tests` | the pull request's | 261 | 13.38 → 12.43 (14.57) |
| 1284 | 2025-08-14 | | | 17.4 / – | refused | maker, `no_test_names` | the pull request's | | 12.43 → 12.14 |
| 1281 | 2025-08-08 | feature | 1.18.3/27.3.3 | 17.4 / 18.6 | dropped | controls, `reference_regression_fails` | the pull request's (most likely) | 761; 401 | 12.14 → 13.00 (14.59); 9.29 → 4.54 (9.29) |
| 1270 | 2025-07-01 | feature | 1.18.3/27.3.3 | 17.4 / 18.6 | dropped | probe, `no_starting_failure` | the pull request's | 210; 31 | 13.32 → 13.20 (15); 5.62 → 6.11 (6.9) |
| 1268 | 2025-07-01 | feature | 1.18.3/27.3.3 | 17.4 / 18.6 | dropped | probe, `no_starting_failure` | the pull request's | 51; 10 | 14.30 → 10.93 (13.88); 6.11 → 6.60 (7.06) |
| 1151 | 2025-06-13 | | 1.13.4/25.3.2 named | 14.2 / – | not made | `elixir_before_1.18` | | | |

The kind is the made folder's `task_kind`; a pull request the maker refused has none (the read-ahead in `kinds.tsv`
gives 1361 a bug fix, 1349 a feature and 1284 a bug fix). 1386 carries the screening's mark that it was written with
an AI tool. Making a folder took 5 or 6 s.

**What each drop is, read where the engine keeps no output.** The engine keeps no output of the probe's runs, so the
probe's step was run again by hand for the unclear ones (`run/diag_hidden.exs`, through the controller, the engine's
own functions, one run each):
- **1385, try 1** (`reference_run_did_not_finish` in a probe of 50.4 s, highest load 15.81): the same probe step on the
  reference, by hand, finished and passed all 86 hidden tests (43,095 bytes of output, far under the 2 MiB limit), and
  the hidden tests on the merged commit itself passed too (86 tests, 0 failures, 11.7 s). Its second try was checked.
  The first try's cause cannot be read; it is counted as the machine's.
- **1382 and 1346** (`start_run_did_not_finish`): on the unchanged project the hidden tests do not compile. 1382's test
  for a new struct (`Cadet.Chatbot.PixelbotDocument`) and calls to a new module (`Cadet.Chatbot.Slug`) fail; 1346's
  changed test factory (`test/factories/factory.ex`) builds a new struct (`Cadet.Assessments.Version`). Both add the
  code their tests need, so nothing can fail inside a test's body: the pull requests' own.
- **1288** (`no_existing_tests`): its only existing test file is also its hidden test file, and that file's old version
  fails on the merged code in one test (90 tests, 1 failure: it calls `Cadet.Assessments.all_user_total_xp/3`, which
  the pull request replaces with `/2`). The probe leaves the file out (`fails_on_reference`), and no existing test is
  left: the pull request's own, not the database version.
- **1281** (`reference_regression_fails`, both tries): on the reference two existing tests of `Cadet.AssessmentsTest`
  ("all_user_total_xp pagination with offset and limit ...") lose their database connection: the query holds it for
  longer than the test pool's 15,000 ms and is cancelled (`DBConnection.ConnectionError`, Postgres `57014
  query_canceled`). Both tries failed the same way, the second with the machine calm (highest load 9.29); on the
  unchanged project the same files pass. The probe had kept the file after two passing runs on the reference, so the
  query runs close to the limit. The pull request introduces that query (a full join with an `or` condition), and the
  next pull request, 1288, rewrote it with left joins. Counted as the pull request's own; the database version
  (Postgres 18.6 for the 17.4 its CI names) cannot be ruled out without a Postgres 17 image.
- **1270 and 1268** (`no_starting_failure`): the hidden tests pass on the unchanged project. 1270 only changes code to
  quiet warnings; 1268's one hidden test passes without the fix. The pull requests' own.
- **1361** adds `test/fixtures/upload.wav` (`binary_file`); **1284** changes no test's body (`no_test_names`); **1349**
  adds `test/fixtures/custom_cassettes/chatbot/chat_empty_choices#1.json`, a path with `#`, which the engine's patch
  check does not accept (`unsupported_path`). The project's recorded HTTP replies (ExVCR cassettes under
  `test/fixtures/`) are named that way, so every pull request that adds one is refused: a limit of the factory.

**For a later Postgres 17 line:** of the six candidates checked on 18.6, 1247 is checked; 1288, 1284, 1270 and 1268
were left out for reasons that do not depend on the database; 1281 is the one whose result could change on Postgres
17.4.

## 4. Licence and hold-out

Run on each checked task, one task at a time (`run/run_scans.sh`, which calls `run/scans.sh` and through it
`factory/tools/check_tasks.sh` of `main` at `60b1a65`), in a Python container with no network; Hex metadata was
fetched for the dependency list. The four were scanned again after the second tries, from their exported folders.
`scans.tsv`, `licence_root.tsv`, `licence_files.tsv`, `holdout_tasks.tsv`, `deps_flagged.tsv`:

| Task | Licence result | Root licence | Files touched | Files passing | Hold-out result | Name hits | Shared 8-word runs (all `common`) | Shared 12-word runs (all `common`) |
|---|---|---|---:|---:|---|---:|---:|---:|
| 1386 | pass | `ok:licence-file`, Apache-2.0 | 10 | 10 | pass | 0 | 10 | 3 |
| 1385 | pass | `ok:licence-file`, Apache-2.0 | 12 | 12 | pass | 0 | 10 | 3 |
| 1330 | pass | `ok:licence-file`, Apache-2.0 | 6 | 6 | pass | 0 | 10 | 3 |
| 1247 | pass | `ok:licence-file`, Apache-2.0 | 7 | 7 | pass | 0 | 4 | 0 |

- **The project's licence:** the root `LICENSE` is the Apache License 2.0 at every starting commit (SHA-256
  `c71d239df91726fc...`, the same file in all four). No touched file carries another notice, and none is long enough to
  be left out of the scan.
- **The locked dependencies** (`deps_flagged.tsv`, with the number of tasks that lock each): `phoenix_swagger` is under
  the MPL 2.0 (0.8.3 in 1247, 0.8.5 in the other three), a licence outside the list; the others listed are in the list
  but spelled loosely (`Apache 2.0`, `BSD`, `bsd`). For the tasks this changes nothing; a session that quotes a file
  of `phoenix_swagger`'s own package is dropped (rules, section 6).
- **Hold-out:** the repository is not held out, no task names a held-out project, and every shared run is `common`
  (it occurs in the cases of two or more of the bench's projects); none needs reading.

## 5. How the run went

- The driver scripts are hexpm's ([2026-11-12_cases_hexpm_hexpm](../2026-11-12_cases_hexpm_hexpm/README.md)), with this
  project's names; `all.sh` gained the second list folder (`LIST`, `RECIPE_FILE`, `lists.tsv`), `suite_tables.sh`
  reads ExUnit's summary line of Elixir 1.18 and 1.19 ("N tests, F failures"), `table.sh` reads a fixed recipe's pair
  from its image, `versions.sh` and `diag_hidden.exs` are new, and `pub.sh` writes one run's tables. The driver ran
  as root (the engine's job records are readable by root only), started once, and ended by itself.
- The controller: container `factory-sourceacademy`, its own node, port mapper and folders, image
  `elixir-task-factory:sourceacademy-20261112` (771,609,948 bytes) built from `factory/` at `60b1a65` with the
  set-up's switches (`EAB_HEX_CACHE_ID=etf-hex-packages-v1`), one preparation worker, one check at a time, every
  container with the labels `task-factory=1` and this job's own, and a CPU share of 256.
- **The two kinds:** the brief asked to prefer the shorter kind after 10 good cases; with 13 candidates all were tried
  in date order. The 4 cases hold 3 bug fixes and 1 feature, so this project alone is under the rules' 30 % for
  features; the balance is kept over the whole dataset (rules, section 7).
- **Disk and load:** free bytes on the system disk 642,965,258,240 at the start of the cases (18:07:43) and
  583,665,901,568 at their end (19:21:05), with every job's use in it. The watcher's 437 samples of the 1-minute load
  ran up to 17.05 (18:18:10); no stop rule fired (free bytes never under 50,000,000,000, load never above 26 in two
  readings five minutes apart) and no bench run started. At the end this job's label was on 48 image tags (15
  toolchain, 11 workspace images each tagged `project` and `seed`, 10 Postgres snapshots, 1 layout); Docker's sizes
  overlap (shared layers), so the per-try bytes are in `tasks_backend.tsv`. The controller's folder held 123,036,605
  bytes, the job folder 97,639,184 bytes and the 4 exported task folders 117,067 bytes.

## Files

| File | What it holds |
|---|---|
| `tasks_backend.tsv` | one line per try: the try, number, id, merge date, Elixir/OTP used, kind, folder origin, verdict, step, reason, the driver's step times, the engine's step times, load at start and end and the highest during the check, settled, the bytes of every image the machine gained meanwhile (all jobs'; images share layers), the build cache's change, the disk bytes used (all jobs'), start, end, and this job's own images and their bytes |
| `versions.tsv` | per candidate: the starting commit, its `.tool-versions`, the CI's Elixir/OTP and Postgres image, the Elixir/OTP and Postgres the task used, and which recipe made it (template or fixed) |
| `counts.tsv` | pull requests per verdict, step and reason, each by its last try |
| `checked.tsv` | per checked case: kind, hidden tests failing first and passing after, existing test files kept and left out, the partial fix, the second round |
| `kinds.tsv` | the 13 candidates in order: merge date, starting and merge commits, what the screening says they lack, and the kind read ahead by the maker's rule, with the files and public functions the fix adds |
| `kind_rule.tsv` | per exported task folder: the kind in `case.json`, the kind by the maker's rule read one line at a time, the files and public functions the reference adds, and their names |
| `project_tests.tsv` | the whole-suite run: the engine's verdict and counts, ExUnit's summary, the output's size |
| `scans.tsv` | per task: the licence result, the root licence families, files touched and passing, the scan's reasons, the hold-out result, name hits, seconds |
| `licence_root.tsv` | per task: the root licence's result, the file it was read from and that file's SHA-256, the families |
| `licence_files.tsv` | per task and touched file: which patches touch it, the scan's verdict at the starting and the merge commit, the result |
| `holdout_tasks.tsv` | per task: the repository check, name hits, and the shared 8- and 12-word runs by class |
| `deps_flagged.tsv` | the locked dependencies whose licence is not plainly in the list, with the number of tasks that lock each |
| `recipe_ci_postgres17.json` | the fixed recipe for the six candidates whose CI names Postgres 17.4 |
| `run/` | the scripts that ran (below) |

## Commands

On the data-mining machine, as root. `WORK` is the factory's work folder (with `tasks/`), `JOB` this job's folder
(with `run/`, `src/` = this repository's `factory/` at `60b1a65` plus this recipe, `tables/` = the screening's census,
screen and class tables of the project, `numbers.txt` = the 13 candidates newest first, `lists.tsv` = the six of them
for the second list, `recipe_ci_postgres17.json`, `backend.git` = a bare clone of the project owned by the work user,
`cache/source-academy__backend.git` = a copy of it owned by root), `CTL` the controller's folder, `BENCH_CASES` the
bench's `cases/` folder (read in place by the hold-out check).

```sh
E="CTL=$CTL NAME=factory-sourceacademy"
SRC=$JOB/src OUT=$JOB/out IMAGE=elixir-task-factory:sourceacademy-20261112 LABEL=task-factory=1 run/build.sh controller
env $E SOURCES=$JOB IMAGE=elixir-task-factory:sourceacademy-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=<this job> EPMD_PORT=<a free port> PREPARE_WORKERS=1 PREPARE_AHEAD=1 \
  run/controller.sh up
env $E WORK=$WORK JOB=$JOB CACHE=$JOB/cache run/all.sh stage
env $E WORK=$WORK JOB=$JOB CACHE=$JOB/cache LIST=backend-pg18 RECIPE_FILE=$JOB/recipe_ci_postgres17.json run/all.sh stage

# the whole suite once at the starting commit of pull request 1386 (merge commit 9db393ea)
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/backend.git NAME=factory-sourceacademy NUMBER=1386 \
  MERGE=9db393eaf89e126dc48cf35550826248e91b4386 ROUNDS=1 TEST_TIMEOUT=1800 SUB=env2 OUT=$JOB/out/suite_try2 CTL=$CTL \
  JOB_LABEL=task-factory-job=<this job> TASK_LABEL=task-factory=1 MAX_LOAD=26 MIN_FREE=50000000000 run/suite.sh
D=$CTL/data/env2 OUT=$JOB/out/suite_try2 ROUNDS=1 run/suite_tables.sh

# the kinds read ahead (as the work user: the clone is its own)
CLASSES=$JOB/tables/classes_13.tsv CENSUS=$JOB/tables/prs_source-academy__backend.tsv CLONE=$JOB/backend.git \
  run/kinds.sh > $JOB/kinds.tsv

# the cases: every listed number, newest first, then once more each one whose check was not settled
env $E WORK=$WORK JOB=$JOB JOB_LABEL=task-factory-job=<this job> TASK_LABEL=task-factory=1 TARGET=20 MAX_TRIED=80 \
  MAX_LOAD=26 MIN_FREE=50000000000 run/all.sh run

# one probe step by hand, keeping its output (here: 1385's hidden tests on its reference)
run/controller.sh rpc 'System.put_env(%{"D_DIR" => "/data/diag", "D_ID" => "backend-pr-1385", "D_SIDE" => "reference"});
  spawn(fn -> Code.eval_file("/data/diag/diag_hidden.exs") end)'
# the old test file of 1288 on its reference (D_COMMAND: run that command instead of the hidden tests)
run/controller.sh rpc 'System.put_env(%{"D_DIR" => "/data/diag", "D_ID" => "backend-pr-1288", "D_SIDE" => "reference",
  "D_TAG" => "existing_reference", "D_COMMAND" => "mix test test/cadet/assessments/assessments_test.exs"});
  spawn(fn -> Code.eval_file("/data/diag/diag_hidden.exs") end)'

# the licence scan and the hold-out check, one task at a time
JOB=$JOB WORK=$WORK BENCH_CASES=$BENCH_CASES JOB_LABEL=task-factory-job=<this job> \
  run/run_scans.sh backend-pr-1386 backend-pr-1385 backend-pr-1330 backend-pr-1247

# the tables
OUT=$JOB/out NUMBERS=$JOB/out/tried_and_listed.txt PREFIX=backend TASKDIR=$CTL/tasks \
  SCREEN_TSV=$JOB/tables/screen_source-academy__backend.tsv JOB_LABEL=task-factory-job=<this job> RUN=$JOB/run \
  HOLD=$JOB/out/before_118.txt HELD_REASON=elixir_before_1.18 run/tables.sh
CLONE=$JOB/backend.git CENSUS=$JOB/tables/prs_source-academy__backend.tsv TASKDIR=$CTL/tasks \
  run/versions.sh $(cat $JOB/out/tried_and_listed.txt) > $JOB/out/tables/versions.tsv
OUT=$JOB/out SCANS=$JOB/out/scans DEST=$JOB/pub run/pub.sh
run/kind_rule.sh $WORK/tasks/source-academy__backend > $JOB/pub/kind_rule.tsv
env $E run/controller.sh stop
```

`run/` holds `all.sh`, `one.sh`, `row.sh`, `watch.sh`, `controller.sh`, `build.sh`, `state.sh`, `make_one.exs`,
`make_probe.sh`, `prepare.exs`, `tests.exs`, `env_tests.sh`, `suite.sh`, `suite_tables.sh`, `table.sh`, `tables.sh`,
`kinds.sh`, `kind_rule.sh`, `scans.sh`, `run_scans.sh` and `pub.sh` from the hexpm job with the changes of section 5,
and `versions.sh` and `diag_hidden.exs`, new.

## Licence

The tables hold pull request numbers, dates, commit ids, version pairs, reason names, file paths and module names of
the project, times and byte counts; no code, title, body or patch text of the project. source-academy/backend is under
the Apache License 2.0 (its `LICENSE` file).
