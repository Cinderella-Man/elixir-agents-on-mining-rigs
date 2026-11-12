# mbta/screens in the task factory: the project's set-up and its first cases (2026-11-12)

One of five jobs that each take one of the dataset's 16 applications ([dataset rules](../../dataset_rules.md)) into
the task factory ([`factory/`](../../../factory/README.md)). This one sets up `mbta/screens` (MIT) and checks its
newest usable merged pull requests as cases, one at a time, until 3 are checked or 12 have been tried. Everything ran
on the data-mining machine, beside six other jobs.

**A second job, toward 15 checked cases, is running (from 14:09).** At this commit 10 cases are checked (6 bug fixes,
4 features): 3358, 3353, 3356, 3343, 3341, 3319 and 3307 were added from 11 more candidates; 3336 and 3322 were dropped
for the pull request's own cause, and 3359 and 3333 at the probe with a run that did not finish (their cause is read
by a diagnostic run at the end of the job). [`cases_mbta_screens.tsv`](cases_mbta_screens.tsv) holds every try so
far, written by [`run/cases_table.sh`](run/cases_table.sh). The free-space stop of `run/watch.sh` is now
50,000,000,000 bytes (the owner's line since 14:20). From 3307 on, the controller runs the factory of this repository
at `0d99a67`, which keeps each database image under a tag of its own installation (the shared tag could be moved by
another controller on the same Docker, and the image it named removed). The rest of this page describes the first job
until the second one ends.

**Result of the first job: 3 checked cases, and all 3 pass the licence scan and the hold-out check.** They are pull requests 3388 and
3387 (bug fixes, Elixir 1.20.4 with OTP 29.1.2) and 3363 (a feature, Elixir 1.20.2 with OTP 29.0.2). They came from
the 9 newest candidates; the other 6 were dropped at the probe, all for the pull request's own cause (3 whose tests
need code the pull request adds, 2 whose tests pass without the fix, 1 with no existing test left to protect). One
check took 98.2 s, 109.9 s and 149.0 s (the engine's total) for the three. The project's own suite passes at the
newest candidate's commit: 1,087 of 1,092 tests, 0 failed, 5 skipped by the project. After these, 35 candidates on
Elixir 1.20 are ready and untried; the 105 older candidates of the screening are on Elixir 1.17
(`elixir_before_1.18`). A fourth case, 3356, was checked out of order by a fault of this job's driver (section 6); it
passed and is kept in the controller, not exported.

| File | What it holds |
|---|---|
| [`project_tests.tsv`](project_tests.tsv) | the project's own suite: the engine's record and ExUnit's summary |
| [`project_tests_skipped.tsv`](project_tests_skipped.tsv) | the 5 tests the project marks as skipped |
| [`cases_mbta_screens.tsv`](cases_mbta_screens.tsv) | one line per check: verdict, step, reason, whose cause, Elixir/OTP, merge date, kind, the time of each step, the load, the bytes |
| [`counts.tsv`](counts.tsv) | the pull requests tried and not reached, by their last check's reason |
| [`diagnostics.tsv`](diagnostics.tsv) | the hidden runs repeated to tell whose cause a "did not finish" drop was |
| [`scans.tsv`](scans.tsv) | the licence scan and the hold-out check of the 3 checked cases |
| [`images.tsv`](images.tsv) | every image the job built, with Docker's own, shared and unique bytes |
| [`run/`](run/) | the scripts that ran (section 7) |

## 1. The project's set-up

The recipe is [`factory/recipes/mbta__screens.json`](../../../factory/recipes/mbta__screens.json), a template: the
bundle maker's toolchain resolver reads each starting commit's own Elixir, OTP and database (section 3.5 of the
factory's README); the recipe's own image and database are only the defaults.

| What | Value | Where it comes from |
|---|---|---|
| Elixir / OTP | 1.20.4 / 29.1.2 at the newest commits, 1.20.2 / 29.0.2 from 2026-08-21 to 2026-10-22 | `.tool-versions` of each starting commit; both pairs are in the image table |
| Image | `hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1`, pinned by digest (the default) | the image table's line for the pair |
| Database | Postgres 18 (`postgres:18.6-alpine`, pinned by digest) | `ci.yml` starts `postgres:18-bookworm`; the table's line for major version 18 |
| Other services | none | `mix.exs` has no Redis client; CI starts only Postgres. `memcachex` is configured only for production |
| System packages, release files | none | the project's CI installs nothing beyond the Elixir and Node toolchains; the Elixir tests need no Node |
| Environment | `MIX_ENV=test`, `DATABASE_USER=postgres`, `DATABASE_PASSWORD=postgres`, `DATABASE_HOST=localhost` | `config/runtime.exs` reads the database user (required), password and host from the environment, as CI sets them; the engine's Postgres answers on the workspace's loopback with that user and password |
| Build | `mix compile` (after the engine's `mix deps.get`) | two dependencies come from GitHub (`screens_config`, and `ueberauth_fake_oidcc` for tests); the image build fetches them |
| Database preparation | `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the project's own `ecto.setup`; its `test` alias runs the same two before the tests |
| Exclusion tags | none | `test/test_helper.exs` excludes nothing; ExUnit skips `:skip` by itself |
| Whole-suite command | `mix test` | CI's test step |

## 2. The project's own tests

A hand-made probe task for pull request 3399 (the newest candidate; starting commit `f03bc6b5`) was prepared through
the controller (`run/env_tests.sh probe` and `prepare`): the workspace image and the database, cold, in 147.0 s (the
engine's own step 143.3 s). The suite then ran once through the engine's own runner (`run/env_tests.sh tests`), in a
fresh workspace container with a fresh database and no network ([`project_tests.tsv`](project_tests.tsv)):

| Run | Tests | Passed | Failed | Skipped | ExUnit time | Engine time | Output |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | 1,092 (1 property) | 1,087 | 0 | 5 | 4.1 s | 5.2 s | 198,759 bytes |

ExUnit's summary: `Result: 1087 passed (1 property, 1086 tests), 5 skipped`. **No test fails.** The 5 skipped tests
are the project's own: two `describe` blocks of `test/screens/screens_by_alert_test.exs` carry `@describetag :skip`
([`project_tests_skipped.tsv`](project_tests_skipped.tsv)). The engine records the run as finished and not passed,
since it passes no skipped test (factory README, section 2.2); for a task this only means that file can never be among
its existing tests. The reporter printed 1,092 rows for 1,092 names: no name twice.

## 3. The cases

The candidates are the screening's for this project
([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md), `classes_16`): 150 newest
merged pull requests that pass the screen, of which 45 are on Elixir 1.18 or newer (all on 1.20, merged 2026-08-21 to
2026-11-09) and 105 on Elixir 1.17.3 (`elixir_before_1.18`, never made). The 45 were taken newest first, one at a
time, through the bundle maker with the toolchain resolver, the factory's import, `factoryctl check` and, for a
checked case, `factoryctl export`. The job stopped when 3 were checked, after 9 tries.

| # | Pull request | Merged | Elixir/OTP | Kind | Verdict | Step | Reason | Whose | Check (s) | Load start / end |
|---:|---:|---|---|---|---|---|---|---|---:|---|
| 1 | 3399 | 2026-11-09 | 1.20.4/29.1.2 | bug fix | dropped | probe | `no_existing_tests` | the pull request's | 191 | 6.39 / 8.15 |
| 2 | 3397 | 2026-11-06 | 1.20.4/29.1.2 | bug fix | dropped | probe | `no_starting_failure` (second try) | the pull request's | 40 and 11 | 7.85 / 9.87, 5.60 / 5.52 |
| 3 | 3379 | 2026-11-04 | 1.20.4/29.1.2 | bug fix | dropped | probe | `start_run_did_not_finish` (second try) | the pull request's | 20 | 9.00 / 7.24 |
| 4 | 3388 | 2026-11-03 | 1.20.4/29.1.2 | bug fix | **checked** | | | | 101 | 7.24 / 5.35 |
| 5 | 3387 | 2026-11-03 | 1.20.4/29.1.2 | bug fix | **checked** | | | | 110 | 5.35 / 4.63 |
| 6 | 3375 | 2026-11-02 | 1.20.4/29.1.2 | feature | dropped | probe | `start_run_did_not_finish` | the pull request's | 41 | 5.94 / 5.74 |
| 7 | 3371 | 2026-10-28 | 1.20.4/29.1.2 | feature | dropped | probe | `start_run_did_not_finish` | the pull request's | 60 | 5.74 / 5.02 |
| 8 | 3368 | 2026-10-22 | 1.20.2/29.0.2 | feature | dropped | probe | `no_starting_failure` | the pull request's | 211 | 7.02 / 7.90 |
| 9 | 3363 | 2026-10-22 | 1.20.2/29.0.2 | feature | **checked** | | | | 150 | 7.90 / 8.06 |
| 13 | 3356 | 2026-10-20 | 1.20.2/29.0.2 | bug fix | checked, out of order | | | | 341 | 6.71 / – |

"Check" is the wall time of `factoryctl check` until its record left "running"; making the folder took 5 to 11 s
more, the import under 1 s and the export under 2 s. The engine's own step times, the hidden test counts, the
existing tests kept and left out, the highest load during each check and the bytes of each try are in
[`cases_mbta_screens.tsv`](cases_mbta_screens.tsv). Every check was settled: the 1-minute load stayed under 12
during each (highest 10.33, on 28 threads).

**The checked cases.**
- **3388** (bug fix): 3 hidden tests fail first and 91 pass after the fix; one existing test file is kept; no partial
  fix fails a hidden test (`no_variant_fails`), so the case has no partial-fix control.
- **3387** (bug fix): 1 hidden test fails first, 14 pass after; one existing test file; the fix is one hunk
  (`single_hunk`), so no partial-fix control.
- **3363** (feature): 5 fail first, 27 pass after; one existing test file kept and one left out
  (`test/screens/util/admin_test.exs`, `fails_on_reference`); it has a partial-fix control, which was rejected. It
  touches `assets/` (the screen's mark).

**The drops, and how their cause was told.** All six are the pull request's own; none is the factory's or the
machine's as a final verdict.
- **3399, `no_existing_tests`:** its only existing test file is the file it changes. That file's old version fails
  on the fixed code (`fails_on_reference`), so nothing is left to protect.
- **3379, 3375, 3371, `start_run_did_not_finish`:** the hidden tests do not compile on the unchanged project, because
  they use code the pull request adds: a new struct (3379), a mock of a new module in a test support file (3375), a new
  struct key (3371). The hidden runs were repeated by hand (`run/diag.exs`, [`diagnostics.tsv`](diagnostics.tsv)) to
  read the compiler's error, since the engine keeps no output of a probe's runs. This is row 4 of the gate (factory
  README section 4): common for feature pull requests.
- **3368, `no_starting_failure`:** the hidden tests pass on the unchanged project, so they do not test the change.
- **3397:** its first check dropped it as `reference_run_did_not_finish`, under a load of 9.87 to 10.33. Run again by
  hand 15 minutes later at a load of 6, the same hidden run on the fixed code finished with 8 of 8 passed, so that
  drop was not the pull request's; with no output kept, it cannot be said whether the machine or the factory caused
  it. Its second try (`RETRY=3397`) finished both runs and dropped it as `no_starting_failure`: its new test passes
  without the fix.
- **3379** also had an earlier try (A in the table) that ended at the preparation step with `environment`: "content
  digest sha256:95dcf33a… not found" from Docker while the database baseline was built. That is the machine's cause
  (the image store is shared with six other jobs and lost a layer in use); the next try prepared without error.

[`counts.tsv`](counts.tsv), by each pull request's last check: checked 3; `start_run_did_not_finish` 3,
`no_starting_failure` 2, `no_existing_tests` 1 (all the pull request's); not reached 3 (3359, 3358, 3353, inside the
12 allowed). By kind: of the 9 tried, 5 bug fixes (2 checked) and 4 features (1 checked).

## 4. The licence scan and the hold-out check

Run on each checked case, one at a time (`run/scans.sh`, which calls
[`factory/tools/check_tasks.sh`](../../../factory/tools/README.md) with the Hex metadata fetched and a temporary copy of
the bench's cases, removed afterwards). [`scans.tsv`](scans.tsv):

| Case | Files touched | Passing | Licence | Name hits | Shared runs of 8 / 12 words (to read) | Hold-out |
|---|---:|---:|---|---:|---|---|
| 3388 | 2 | 2 | pass (MIT, `LICENSE`) | 0 | 10 / 3 (0 / 0) | pass |
| 3387 | 2 | 2 | pass (MIT) | 0 | 10 / 3 (0 / 0) | pass |
| 3363 | 5 | 5 | pass (MIT) | 0 | 11 / 3 (0 / 0) | pass |

Every shared run is boilerplate that several of the bench's projects share (`common`), and one of 3363's is plain
syntax. The project's 89 locked dependencies: 84 under a listed licence, 2 under "Apache 2.0" written without the SPDX
id (`connection`, `cowboy_telemetry`), and 3 Git dependencies whose licence the scan does not read: `screens_config`
and `ehmon` (the project's own organisation) and `ueberauth_fake_oidcc`. They matter only for the sessions'
quotation scan (dataset rules, section 6), not for the cases.

## 5. Time, load and disk

- **One case:** 98.2 s, 109.9 s and 149.0 s of engine time for the three checked ones (preparation 13.5 to 24.7 s,
  probe 30.1 to 44.7 s, controls with the second round 54.0 to 79.6 s). A drop at the probe spent 7.1 to 56.3 s in the
  probe after its preparation. The first case on a new Elixir pair or database family pays for its build: the project's first
  preparation took 147.0 s, 3356's (the first on 1.20.2) 245.9 s, 3368's 200.5 s.
- **Load:** the job ran beside six other jobs. The 1-minute load at the job's start was 1.89 (13:16); during the
  checks it ranged from 4.63 to 10.33. The stop rules (load above 26 twice, five minutes apart; free space under
  700,000,000,000 bytes; a bench run) never fired.
- **Disk:** the images the job built are listed in [`images.tsv`](images.tsv). Each checked case added one workspace
  image with about 218 MB of its own layers (unique bytes 218,123,271, 218,121,568 and 217,708,896); a new database
  family adds a 56 MB snapshot; each of the two Elixir pairs built a toolchain image whose own layers are 606,778,170 and
  648,268,453 bytes over its base image. In all: 2,397,956,028 bytes of workspace images, 280,265,377 of database
  snapshots and at most 1,255,046,623 of toolchain layers. The controller's folder holds 696,979,209 bytes, the job's
  folder 320,804,190 (with two copies of the project's Git history and the scans' checked-out trees), the 3 exported
  cases 62,867. The scan's Python image (185,294,601 bytes) was pulled by this job. Free space on `/` went from
  798,039,351,296 to 768,199,536,640 bytes over the job, for all seven jobs together.

## 6. What went wrong, in order

None of these changed a verdict; each is recorded so that the next job avoids it.
1. **Every pull request `fetch_failed` in seconds** (13:25): the maker's Git cache was copied by the machine's
   ordinary user, the controller runs as root, and Git refuses a repository owned by another user ("detected dubious
   ownership"). Fixed by giving the cache to root; the 12 refusals are kept apart and are not tries.
2. **The driver ran as the ordinary user and could not remove the maker's records**, which the controller writes as
   root: `one.sh` failed at once, without a row, for each of the 12 numbers the first run had touched, and the driver
   moved through the list. The 13th, 3356, had no record to remove, so its try went ahead; the driver was stopped by
   hand after its check had started. That check ran to the end (checked, 341 s) and is the out-of-order case above. The driver now runs as root and stops when a try leaves no
   row.
3. **`timeout 5` around `setsid nohup all.sh`** killed the driver after 5 s (13:33); its first `one.sh` (3399) ran on
   alone and finished. Started again under `timeout` around a `bash -c` that starts it.
4. **`one.sh: /usr/bin/jq: Argument list too long`** (13:39, 3379): the snapshot of Docker's image list, passed as one
   argument, outgrew Linux's 128 KiB limit on one argument as the seven jobs' images piled up. The driver stopped;
   `one.sh` now passes the list through a file. The interrupted try of 3379 is try A (its check had ended at the
   preparation, above); its record in the job's folder was removed before the restart, and the engine's own record of
   it is what the table shows.
5. The Python image for the scans was not on the machine; `docker run` pulled `python:3.12-slim-bookworm`
   (185,294,601 bytes) at 13:54.

## 7. Exact commands

On the data-mining machine, with `WORK` the factory's folder there (`J=$WORK/jobs/hb-screens`,
`C=$WORK/ctl-hb-screens`). The factory folder came from this repository at `772f3bd`
(`git archive 772f3bd factory`, unpacked into `$J/src`), with the recipe of this job added to `$J/src/recipes/`.

```sh
git clone --bare https://github.com/mbta/screens $J/screens.git
SRC=$J/src OUT=$J/out/build LABEL=task-factory=1 IMAGE=elixir-task-factory:screens-20261112 $J/run/build.sh controller
CTL=$C NAME=factory-screens IMAGE=elixir-task-factory:screens-20261112 LABELS=task-factory=1,task-factory-job=hb-screens \
  HEX_CACHE_ID=etf-hex-packages-v1 EPMD_PORT=4517 SOURCES=$J PREPARE_WORKERS=1 PREPARE_AHEAD=1 $J/run/controller.sh up

# the project's own suite at the starting commit of 3399 (merge commit c6fa3978), once
JOB=$J DATA=$C/data GIT_DIR=$J/screens.git NAME=factory-screens NUMBER=3399 \
  MERGE=c6fa3978f18fe8eb741f5972999a9989f5d8b971 ROUNDS=1 TEST_TIMEOUT=900 SUB=env OUT=$J/out/suite CTL=$C \
  JOB_LABEL=task-factory-job=hb-screens TASK_LABEL=task-factory=1 $J/run/suite.sh
D=$C/data/env OUT=$J/out/suite/tables ROUNDS=1 $J/run/suite_tables.sh

# the tables: the screening's census and screen of mbta/screens in $J/tables/ (prs_mbta__screens.tsv,
# screen_mbta__screens.tsv); numbers.txt: the 45 classes_16 rows of mbta/screens with below_1_18 "-", in their order
mkdir $J/cache && cp -a $J/screens.git $J/cache/mbta__screens.git
WORK=$WORK JOB=$J CTL=$C NAME=factory-screens CACHE=$J/cache $J/run/all.sh stage
chown -R root:root $C/data/screens/cache

# the cases, as root, detached
WORK=$WORK JOB=$J CTL=$C NAME=factory-screens OUT=$J/out/cases JOB_LABEL=task-factory-job=hb-screens \
  TASK_LABEL=task-factory=1 TARGET=3 MAX_TRIES=12 SETTLE_LOAD=12 $J/run/all.sh run

# the repeated hidden runs, then 3397's second try
mkdir -p $C/data/diag && cp $J/run/diag.exs $C/data/diag/
CTL=$C NAME=factory-screens $J/run/controller.sh rpc 'System.put_env(%{"DIAG_DIR" => "/data/diag", "DIAG_SPECS" => "screens-pr-3397:reference,screens-pr-3379:start,screens-pr-3375:start,screens-pr-3371:start"}); spawn(fn -> Code.eval_file("/data/diag/diag.exs") end)'
WORK=$WORK JOB=$J CTL=$C NAME=factory-screens OUT=$J/out/cases JOB_LABEL=task-factory-job=hb-screens \
  TASK_LABEL=task-factory=1 TARGET=3 MAX_TRIES=12 SETTLE_LOAD=12 RETRY=3397 $J/run/all.sh run

# the two scans, one case at a time (ids.txt: the 3 checked ids, newest first)
SRC=$J/src DEST=$WORK/tasks/mbta__screens IDS=$J/out/scans/ids.txt OUT=$J/out/scans CLONES=$J/screens.git \
  BENCH_CASES=<a temporary copy of the bench's cases/, without admission.json> \
  LABELS=task-factory=1,task-factory-job=hb-screens $J/run/scans.sh run
SRC=$J/src DEST=$WORK/tasks/mbta__screens IDS=$J/out/scans/ids.txt OUT=$J/out/scans $J/run/scans.sh table

# the tables of the tries (numbers_window.txt: the first 12 of numbers.txt), then the controller is stopped (kept)
OUT=$J/out/cases NUMBERS=$J/out/cases/numbers_window.txt TASKDIR=$C/tasks \
  SCREEN_TSV=$J/tables/screen_mbta__screens.tsv $J/run/table.sh tasks
CTL=$C NAME=factory-screens $J/run/controller.sh stop
```

The scripts are those of the nerves_hub_web job on the same machine, with the project as settings, plus `diag.exs`
and `scans.sh`. Changed here: `all.sh` (the project's names as settings, `MAX_TRIES`, `RETRY`, a stop when a try leaves
no row, no second try for a case that passed under load), `one.sh` (the image list through a file), `env_tests.sh`
(the project as settings), `watch.sh` (stops above a load of 26), `prepare.exs` and `tests.exs` (no default task id).

## 8. Provenance and licence

The project is `mbta/screens`, MIT (`LICENSE` at every commit read). The case folders, the patches and the test output
stay on the data-mining machine; this folder holds only counts, names of tests and files, commit ids and timings. No
title, body or patch text of a pull request is reproduced here.
