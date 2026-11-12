# mbta/screens in the task factory: the project's set-up and its 15 cases (2026-11-12)

One of five jobs that each take one of the dataset's 16 applications ([dataset rules](../../dataset_rules.md)) into
the task factory ([`factory/`](../../../factory/README.md)). This folder covers two jobs on `mbta/screens` (MIT), one
after the other, on the same controller. The first (13:15 to 14:05) set the project up and checked its newest usable
merged pull requests as cases, one at a time, until 3 were checked (sections 1 to 8). The second (14:07 to 15:25) went
on down the same list, one at a time, until 15 checked cases passed both scans (section 9). Everything ran on the
data-mining machine, beside six other jobs.

**Result: 15 checked cases that pass the licence scan and the hold-out check.** They are 8 bug fixes and 7 features:
3388, 3387 (Elixir 1.20.4 with OTP 29.1.2), 3363, 3358, 3353, 3356, 3343, 3341, 3319, 3306, 3310, 3281, 3293, 3284 and
3287 (Elixir 1.20.2 with OTP 29.0.2). A 16th checked case, 3307 (a feature), fails the licence scan: it changes the
front end's npm lock file, which the scan leaves out as too large to read (`exclude:large`). The 16 came from the 30
newest candidates on Elixir 1.18 or newer; the other 14 were dropped at the probe, every one for the pull request's own
cause (6 whose new tests cannot run on the unchanged project, 5 with no existing test left to protect, 3 whose tests
pass without the fix). The 15 checks took 98.2, 109.9, 149.0, 178.0, 159.1, 118.9, 328.2, 109.7, 143.4, 245.7, 163.1,
192.6, 237.7, 377.7 and 173.1 s of the engine's time, in the order of the list above (section 9.5 says why some took
longer). The project's own suite passes at the newest candidate's commit: 1,087 of 1,092 tests, 0 failed, 5 skipped by
the project. 15 candidates on Elixir 1.20 are left untried (`not_reached`); the 105 older candidates of the screening
are on Elixir 1.17 (`elixir_before_1.18`).

**Result of the first job: 3 checked cases, and all 3 pass the licence scan and the hold-out check.** They are pull
requests 3388 and 3387 (bug fixes) and 3363 (a feature). They came from the 9 newest candidates; the other 6 were
dropped at the probe, all for the pull request's own cause (3 whose tests need code the pull request adds, 2 whose
tests pass without the fix, 1 with no existing test left to protect). One check took 98.2 s, 109.9 s and 149.0 s (the
engine's total) for the three. A fourth case, 3356, was checked out of order by a fault of the first job's driver
(section 6); the second job checked it again in its place and exported it.

| File | What it holds |
|---|---|
| [`project_tests.tsv`](project_tests.tsv) | the project's own suite: the engine's record and ExUnit's summary |
| [`project_tests_skipped.tsv`](project_tests_skipped.tsv) | the 5 tests the project marks as skipped |
| [`cases_mbta_screens.tsv`](cases_mbta_screens.tsv) | one line per check of both jobs, and one per candidate not reached: verdict, step, reason, whose cause and why, Elixir/OTP, merge date, kind, the time of each step, the load, the bytes |
| [`counts.tsv`](counts.tsv) | the 45 candidates on Elixir 1.18 or newer, by their last check's reason |
| [`diagnostics.tsv`](diagnostics.tsv) | the runs repeated to tell whose cause a "did not finish" drop was (both jobs) |
| [`scans.tsv`](scans.tsv) | the licence scan and the hold-out check of the 16 checked cases |
| [`images.tsv`](images.tsv) | every image the two jobs built, with Docker's own, shared and unique bytes |
| [`run/`](run/) | the scripts that ran (sections 7 and 9.7) |

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

## 9. The second job: from 3 to 15 checked cases (14:07 to 15:25)

The same controller, data folder, job folder and driver as the first job (`run/all.sh` with `TARGET=15`,
`MAX_TRIES=69`), on the same list of 45 candidates, newest first, from the 10th (3359) on. The 9 pull requests the
first job tried were not made or checked again: their rows stand. 3356, which the first job had checked out of order
and kept, was checked again in its place (its folder as it was) and exported. One case at a time, one preparation
worker, every container with the job's labels and a CPU share of 256.

### 9.1 Two changes during the job

- **The free-space stop.** `run/watch.sh` stopped the job under 700,000,000,000 free bytes on `/`. The owner set the
  line at 50,000,000,000 bytes during the job; the watcher was started again with it at 14:15:21 (the machine's clock),
  between two of its samples, while the driver ran on. That is now the script's default.
- **A fault of the factory, fixed between two cases.** Every controller built its database layout image under the same
  tag; when another controller on the same Docker built the same recipe, the tag moved and Docker removed the image it
  had named, and the next case that started a new database family was dropped at the preparation with "content digest
  … not found" (the nerves_hub_web job found it; the first job's try A of 3379 is one such drop). This repository fixed
  it at `0d99a67` (each service image is also kept under a tag of its own installation). The driver was stopped
  between two cases (after 3319, by a hold list of the untried ids), the controller's image was built from `0d99a67`
  (`run/build.sh`: 1 s, every layer in the build cache; 771,600,480 bytes), and the controller was made again with the
  same settings, data and port (the old container kept, renamed). 3307 and every later try ran the fixed code. No try of
  this job was dropped by that fault.

### 9.2 The tries

| # | Pull request | Merged | Kind | Verdict | Reason | Whose | Check (s) | Engine (s) | Load start / end / highest |
|---:|---:|---|---|---|---|---|---:|---:|---|
| 10 | 3359 | 2026-10-22 | feature | dropped | `start_run_did_not_finish` | the pull request's | 40 | 37.0 | 4.92 / 7.56 / 6.56 |
| 11 | 3358 | 2026-10-20 | bug fix | **checked** |  |  | 181 | 178.0 | 7.56 / 6.43 / 9.06 |
| 12 | 3353 | 2026-10-20 | feature | **checked** |  |  | 160 | 159.1 | 6.43 / 9.29 / 8.7 |
| 13 | 3356 | 2026-10-20 | bug fix | **checked** |  |  | 121 | 118.9 | 9.29 / 8.08 / 9.53 |
| 14 | 3343 | 2026-10-15 | feature | **checked** |  |  | 330 | 328.2 | 8.08 / 7.42 / 9.04 |
| 15 | 3341 | 2026-10-14 | bug fix | **checked** |  |  | 110 | 109.7 | 7.42 / 8.54 / 9.89 |
| 16 | 3333 | 2026-10-09 | bug fix | dropped | `no_existing_tests` | the pull request's | 380 | 378.1 | 8.54 / 5.31 / 10.48 |
| 17 | 3336 | 2026-10-09 | feature | dropped | `no_existing_tests` | the pull request's | 60 | 58.2 | 5.31 / 5.29 / 5.9 |
| 18 | 3322 | 2026-10-09 | bug fix | dropped | `no_starting_failure` | the pull request's | 40 | 35.4 | 5.29 / 5.24 / 5.48 |
| 19 | 3319 | 2026-10-09 | bug fix | **checked** |  |  | 150 | 143.4 | 5.24 / 5.16 / 10.61 |
| 20 | 3307 | 2026-10-02 | feature | **checked** |  |  | 331 | 326.4 | 7.35 / 6.62 / 9.23 |
| 21 | 3306 | 2026-10-02 | feature | **checked** |  |  | 250 | 245.7 | 6.62 / 6.61 / 7.62 |
| 22 | 3310 | 2026-10-01 | bug fix | **checked** |  |  | 171 | 163.1 | 6.61 / 6.96 / 6.98 |
| 23 | 3300 | 2026-10-01 | feature | dropped | `no_existing_tests` | the pull request's | 231 | 229.3 | 8.41 / 9.44 / 10.37 |
| 24 | 3281 | 2026-09-24 | feature | **checked** |  |  | 200 | 192.6 | 9.44 / 7.97 / 9.23 |
| 25 | 3294 | 2026-09-23 | bug fix | dropped | `start_run_did_not_finish` | the pull request's | 50 | 41.7 | 7.97 / 10.24 / 9.3 |
| 26 | 3293 | 2026-09-21 | bug fix | **checked** |  |  | 241 | 237.7 | 10.24 / 8.97 / 10.31 |
| 27 | 3298 | 2026-09-21 | feature | dropped | `start_run_did_not_finish` | the pull request's | 40 | 32.5 | 8.97 / 8.16 / 9.06 |
| 28 | 3296 | 2026-09-18 | feature | dropped | `no_existing_tests` | the pull request's | 71 | 67.4 | 10.15 / 9.09 / 9.66 |
| 29 | 3284 | 2026-09-16 | feature | **checked** |  |  | 380 | 377.7 | 9.09 / 8.46 / 11.38 |
| 30 | 3287 | 2026-09-15 | feature | **checked** |  |  | 181 | 173.1 | 7.37 / 8.64 / 9.33 |

All 21 tries ran on Elixir 1.20.2 with OTP 29.0.2. "Check" is the wall time of `factoryctl check`; "Engine" is the
engine's total. Every check was settled: the 1-minute load stayed under 12 during each (highest 11.38, during 3284's).
The hidden test counts, the existing tests kept and left out, each step's time and each try's image bytes are in
[`cases_mbta_screens.tsv`](cases_mbta_screens.tsv).

By kind: of the 21 tries, 9 bug fixes (6 checked) and 12 features (7 checked). Of the 30 tries of both jobs, 14 bug
fixes (8 checked) and 16 features (8 checked, 3307 among them). After 10 checked cases there were 6 bug fixes and 4
features; neither kind was under 3, so the list's order was kept.

### 9.3 The drops, and how their cause was told

All 8 are the pull request's own; none was the machine's (no time-out and no lost database connection in any of them)
or the factory's.
- **3336, 3300, 3296, `no_existing_tests`:** each has one existing test file, and its old version fails on the fixed
  code (`fails_on_reference`; the file is named in the table), so nothing is left to protect.
- **3333, `no_existing_tests`:** all 8 of its existing test files "did not finish" on the fixed code. Run again by hand
  (`run/diag.exs`, the new side `existing_reference`, which runs those files as the probe does and keeps the output),
  they do not compile: the starting commit's test support file mocks a module the pull request removes.
- **3359, 3294, 3298, `start_run_did_not_finish`:** run again by hand (`run/diag.exs`, side `start`), the hidden tests
  cannot run on the unchanged project: they call a function of a mock that the pull request adds (3359), a function the
  pull request adds (3294), and set a struct key the pull request adds (3298). [`diagnostics.tsv`](diagnostics.tsv)
  holds each run's first error.
- **3322, `no_starting_failure`:** its hidden tests pass on the unchanged project.

[`counts.tsv`](counts.tsv), by each candidate's last check, both jobs: checked 16; `start_run_did_not_finish` 6,
`no_existing_tests` 5, `no_starting_failure` 3 (all the pull request's); not reached 15 (3286 and the 14 older ones).

### 9.4 The licence scan and the hold-out check

Run on each checked case of this job, one at a time, as in section 4 (`run/scans.sh`, the factory at `0d99a67`, whose
two scan tools are those of the first job's; a temporary copy of the bench's cases, removed afterwards).
[`scans.tsv`](scans.tsv):

| Case | Files touched | Passing | Licence | Name hits | Shared runs of 8 / 12 words (to read) | Hold-out |
|---|---:|---:|---|---:|---|---|
| 3358 | 10 | 10 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3353 | 6 | 6 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3356 | 4 | 4 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3343 | 7 | 7 | pass | 0 | 12 / 3 (1 / 0) | review; read: pass |
| 3341 | 2 | 2 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3319 | 27 | 27 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3307 | 17 | 16 | **fail** (`assets/package-lock.json`: `exclude:large`) | 0 | 13 / 3 (0 / 0) | pass |
| 3306 | 21 | 21 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3310 | 10 | 10 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3281 | 12 | 12 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3293 | 10 | 10 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3284 | 5 | 5 | pass | 0 | 10 / 3 (0 / 0) | pass |
| 3287 | 3 | 3 | pass | 0 | 10 / 3 (0 / 0) | pass |

- **3343:** one shared run of 8 words was left to read (with one of the bench's hidden-test files). Read: it is plain
  test syntax (a comparison with `{:ok, []}`, the end of a test and the next `test`), so the case passes.
- **3307** changes the front end's npm lock file. The licence scan leaves a file that large out as unread and fails the
  case, so 3307 is checked but not counted; one more candidate, 3287, was taken in its place. The rules read
  `mix_files` for Elixir's lock file only (dataset rules, section 3).
- The other shared runs are boilerplate that several of the bench's projects share, or code already in the project's
  own tree, as in section 4. The 89 locked dependencies (88 at 3284's and 3287's commits) read as in section 4.

### 9.5 Time, load and disk

- **One case.** The 13 checked cases of this job took 178.0, 159.1, 118.9, 328.2, 109.7, 143.4, 326.4, 245.7, 163.1,
  192.6, 237.7, 377.7 and 173.1 s of engine time (3358 to 3287, in the table's order). The three longest, 3343, 3307
  and 3284, spent 173.9, 189.0 and 230.4 s in the preparation, almost all of it building the project's image from
  another case's build (155, 181 and 218 s by the engine's log); every other checked case of this job spent 46.4 s or
  less there. The engine's record does not say why those builds took longer. The 8 drops took 37.0, 378.1, 58.2, 35.4,
  229.3, 41.7, 32.5 and 67.4 s (3359 to 3296, in the table's order); 3333 and 3300 also built their image the long way
  (187 and 170 s).
- **The whole job.** The 21 tries ran from 14:09:04 to 15:12:36 and from 15:18:34 to 15:21:45, with the pause for the
  rebuild from 14:36:45 to 14:37:53. The scans took 15:13:50 to 15:17:08 for 12 cases and 19 s for 3287.
- **Load.** 4.92 at the first try's start; the highest 1-minute load the watcher saw was 11.38 (15:10:05). No stop rule
  fired; no bench run started.
- **Disk.** The job built 26 images with 4,683,587,297 unique bytes ([`images.tsv`](images.tsv)): one project image of
  about 217 MB for each try but 3356 (which reused the first job's), and 6 database snapshots of about 56 MB. That is
  360,275,946 bytes est. per checked case of this job, the drops' images included. The controller's folder grew from
  696,979,209 to 1,846,108,568 bytes and the job's folder from 320,804,190 to 1,038,976,730 (707,652,378 of them the
  scans' checked-out trees); the 16 exported case folders hold 697,435 bytes. Free space on `/` went from
  763,499,622,400 (14:07) to 721,656,512,512 bytes (15:22), for all seven jobs together.

### 9.6 What went wrong

None of these changed a verdict.
1. The pause by hold list left an empty try folder of 3307 (the driver stops when a try leaves no row); it was removed
   before the restart and is not a try.
2. The scans' shared-span texts were deleted before 3343's one span was read. The hold-out check was run again for
   3343 alone (same result), the span read, and the texts and the temporary copy of the bench's cases deleted again.

### 9.7 Exact commands

On the data-mining machine, as in section 7 (`J=$WORK/jobs/hb-screens`, `C=$WORK/ctl-hb-screens`). The factory of
`0d99a67` came from this repository (`git archive 0d99a67 factory`, unpacked into `$J/src_0d99a67`).

```sh
# the first job's controller again, then the driver, as root, detached, to 15 checked
CTL=$C NAME=factory-screens $J/run/controller.sh start
WORK=$WORK JOB=$J CTL=$C NAME=factory-screens OUT=$J/out/cases JOB_LABEL=task-factory-job=hb-screens \
  TASK_LABEL=task-factory=1 TARGET=15 MAX_TRIES=69 SETTLE_LOAD=12 $J/run/all.sh run

# the watcher again with the owner's line, the driver running on
MIN_FREE=50000000000 END=$J/out/cases/watch.end STOP=$J/out/cases/STOP CTL=$C NAME=factory-screens \
  JOB_LABEL=task-factory-job=hb-screens TASK_LABEL=task-factory=1 $J/run/watch.sh >> $J/out/cases/watch.tsv

# the pause: every untried id into the hold list (one.sh exits 3 for a held id and the driver stops)
# the controller from 0d99a67, then the driver again (same command, MIN_FREE=50000000000)
SRC=$J/src_0d99a67 OUT=$J/out/build_0d99a67 LABEL=task-factory=1 IMAGE=elixir-task-factory:screens-20261112-0d99a67 \
  $J/run/build.sh controller
CTL=$C NAME=factory-screens $J/run/controller.sh stop
docker rename factory-screens factory-screens-772f3bd
CTL=$C NAME=factory-screens IMAGE=elixir-task-factory:screens-20261112-0d99a67 \
  LABELS=task-factory=1,task-factory-job=hb-screens HEX_CACHE_ID=etf-hex-packages-v1 EPMD_PORT=4517 SOURCES=$J \
  PREPARE_WORKERS=1 PREPARE_AHEAD=1 $J/run/controller.sh up

# the repeated runs (DIAG_FILES: 3333's 8 existing test files, as a JSON object)
mkdir -p $C/data/diag2 && cp $J/run/diag.exs $C/data/diag2/
CTL=$C NAME=factory-screens $J/run/controller.sh rpc 'System.put_env(%{"DIAG_DIR" => "/data/diag2", "DIAG_SPECS" => "screens-pr-3359:start,screens-pr-3294:start,screens-pr-3298:start,screens-pr-3333:existing_reference", "DIAG_FILES" => "{\"screens-pr-3333\": [...]}"}); spawn(fn -> Code.eval_file("/data/diag2/diag.exs") end)'

# the two scans, one case at a time (ids.txt: the checked ids of this job, newest first), then the table
SRC=$J/src_0d99a67 DEST=$WORK/tasks/mbta__screens IDS=$J/out/scans_to15/ids.txt OUT=$J/out/scans_to15 \
  CLONES=$J/screens.git BENCH_CASES=<a temporary copy of the bench's cases/, without admission.json> \
  LABELS=task-factory=1,task-factory-job=hb-screens $J/run/scans.sh run
SRC=$J/src_0d99a67 DEST=$WORK/tasks/mbta__screens IDS=$J/out/scans_to15/ids.txt OUT=$J/out/scans_to15 $J/run/scans.sh table

# one more case after 3307's licence fail: the driver again with TARGET=16, then its scans as above

# the tables (notes.tsv: id, try, whose cause and why, for each drop; T=$J/out/tables_to15)
OUT=$J/out/cases JOB_LABEL=task-factory-job=hb-screens $J/run/cases_table.sh images
OUT=$J/out/cases NUMBERS=$J/numbers.txt TASKDIR=$C/tasks SCREEN_TSV=$J/tables/screen_mbta__screens.tsv \
  NOTES=$T/notes.tsv IDS=$T/ids_final.txt $J/run/cases_table.sh cases > $T/cases_final_new.tsv
OUT=$J/out/cases BASE=<this table at the previous commit> NEW=$T/cases_final_new.tsv WINDOW=$J/numbers.txt \
  NUMBERS=$J/numbers.txt TASKDIR=$C/tasks SCREEN_TSV=$J/tables/screen_mbta__screens.tsv NOT_RUN_REASON=not_reached \
  NOT_RUN_WHY="15 cases that pass both scans were checked first" $J/run/cases_table.sh merge > cases_mbta_screens.tsv
OUT=$J/out/cases TABLE=cases_mbta_screens.tsv $J/run/cases_table.sh counts > counts.tsv
OUT=$J/out/cases SINCE=2026-11-12T14:09:00+01:00 $J/run/cases_table.sh built   # the new rows of images.tsv
CTL=$C NAME=factory-screens $J/run/controller.sh stop
```

The notes on 3307 and 3343 in the table's last text column were added by hand from the scans. Changed in `run/` by
this job: `watch.sh` (the owner's free-space line as its default), `diag.exs` (the `existing_start` and
`existing_reference` sides), and `cases_table.sh` (new).
