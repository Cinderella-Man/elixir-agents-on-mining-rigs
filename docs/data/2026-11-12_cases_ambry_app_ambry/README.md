# ambry-app/ambry in the task factory: the project's set-up and its first 3 checked cases (2026-11-12)

Registry rows [E68](../../../experiments.md) (the pilot of the task factory) and E82 (newest Elixir first, from alive
applications). One of five jobs that each set up one of the dataset's 16 applications
([the list](../2026-11-12_dataset_projects/README.md)) and check its newest usable pull requests as cases, one at a
time. Everything ran on the data-mining machine on 2026-11-12 between 13:16 and 14:27 (UTC+1), through a controller of
its own built from the factory's `main` at `772f3bd`, while the four other case jobs, a check job of another project
and a teacher run used the same Docker daemon.

## Result

- **The project's set-up works without a release file.** The recipe
  ([`factory/recipes/ambry-app__ambry.json`](../../../factory/recipes/ambry-app__ambry.json)) needs Elixir 1.20.2 with
  OTP 29.0.4 (from `.tool-versions`), Postgres 18.6, and one distribution package, `ffmpeg`.
- **The project's own suite passes:** at the starting commit of pull request 1290, ExUnit's summary is
  **2,157 passed (8 doctests, 2,149 tests), 0 failed, 1 skipped, in 91.0 s** (one run, the engine's run 92.4 s).
- **3 cases are checked** (pull requests 1283, 1282 and 1281), from 9 pull requests tried, newest merged first. All
  three pass the licence scan and the hold-out check.
- **Of the 6 left out:** 4 are the pull request's own cause, 1 is the factory's (an image name that the controllers on
  one machine share), and 1 is probably the machine's and not settled.
- **What is left for later:** 13 more candidates are ready and were not tried; 67 older ones need a release file
  (`shaka-packager`) that was not fetched; 3 are left out by the rules.

## 1. The project's set-up

| What | Value | Where it comes from |
|---|---|---|
| Elixir / OTP | 1.20.2 / 29.0.4, image `hexpm/elixir:1.20.2-erlang-29.0.4-ubuntu-noble-20260730.1` (pinned by digest) | `.tool-versions`, read by the toolchain resolver; the image table's line (E84) |
| Database | Postgres 18.6 (`postgres:18.6-alpine`, pinned) | the CI file starts `postgres` with no version, so the recipe's default |
| Other services | none | no Redis client in `mix.exs`; CI starts only Postgres |
| System packages | `ffmpeg` (`runtime.packages`) | CI installs it (`AnimMouse/setup-ffmpeg`); the application reads audio files with `ffprobe` (`lib/ambry/media/`) |
| Database set-up | `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the project's `ecto.setup` alias |
| Whole-suite command | `mix test` | `grading.preservation`; the project's `test` alias creates and migrates the database first |
| Licence | MIT (`LICENSE` at every starting commit) | |

**What the build fetches by itself.** Beside the Hex packages, the project's own dependencies fetch four things
during `mix deps.get` and `mix compile`, with no change to the recipe: the git dependency `boundary` (from its GitHub
repository, pinned by `mix.lock`), and three prebuilt native libraries from their GitHub release pages (`mdex_native`
0.2.6 through `rustler_precompiled`; `lazy_html` 0.1.12 and `vix` 0.40.0 through `elixir_make`, `vix`'s with
`libvips`). No release file was added to the recipe and none was fetched by the engine.

**Cold preparation** of the starting commit of 1290: 163.7 s for the probe task (the engine's own step 161.3 s): the
`ffmpeg` layer 17.7 s, the dependencies and the compile, the database family. Every later commit was seeded from that
build: each case's preparation took 37.7 s to 51.9 s.

### The project's own tests

One run of the whole suite, through the engine's own runner, in a fresh workspace container with a fresh database
and no network (`project_tests.tsv`):

| Command | Return code | ExUnit | Failed | Skipped | ExUnit time | Engine time | Output |
|---|---:|---|---:|---:|---:|---:|---:|
| `mix test` | 0 | 2,157 passed (8 doctests, 2,149 tests) | 0 | 1 | 91.0 s | 92.4 s | 342,035 bytes |

- **No test fails.** The reporter printed 2,158 rows for 2,158 distinct names (no name twice), well under the 2 MiB
  output limit.
- **The engine's own verdict is "not passed"** only because of the one skipped test: the grader passes no skipped
  test (`factory/README.md`, section 2.2). It is a test of `test/ambry/people_test.exs` that the project marks
  `@tag :skip`. A task whose hidden tests include it is dropped as `skipped_test`; it does not touch the existing tests
  of the three cases.
- The run used `max_cases: 4` (the workspace runs Erlang with 2 schedulers).

## 2. The cases

The candidates are the screening's for this project
([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)), with the images the resolver
gives them since E84 ([2026-11-12_newer_elixir_versions](../2026-11-12_newer_elixir_versions/README.md)). Of the 92
screened candidates since 2024, the newest 21 (pull requests 1290 back to 1265) need nothing beyond the recipe. They
were taken newest merged first, one at a time: the bundle maker with the resolver (`make_one.exs`), `factoryctl
import`, `factoryctl check` with one task at a time, then `factoryctl export` of a checked task. The job stopped when
3 were checked (the cap was 12 tried).

`cases_ambry.tsv` (one line per pull request, its last try; `whose.tsv` gives the reason for each drop's cause):

| Pull request | Merged | Elixir / OTP | Kind | Verdict | Step | Reason | Whose | Check | Load at start / end / highest |
|---:|---|---|---|---|---|---|---|---:|---|
| 1290 | 2026-08-24 | 1.20.2 / 29.0.4 | bug fix | dropped | probe | `no_starting_failure` | the pull request's | 21 s | 8.45 / 8.64 / 9.34 |
| 1289 | 2026-08-24 | — | — | refused | maker | `patch_over_1_mib` | the pull request's | — | 8.67 / 8.45 / — |
| 1288 | 2026-08-22 | 1.20.2 / 29.0.4 | feature | dropped | probe | `start_run_did_not_finish` | the pull request's | 31 s | 7.10 / 6.54 / 7.1 |
| 1287 | 2026-08-22 | 1.20.2 / 29.0.4 | feature | dropped | probe | `start_run_did_not_finish` | the pull request's | 100 s | 6.54 / 8.51 / 8.64 |
| 1286 | 2026-08-22 | 1.20.2 / 29.0.4 | feature | dropped | second round | `unstable` | probably the machine's; not settled | 631 s | 8.51 / 6.61 / 8.82 |
| 1284 | 2026-08-22 | 1.20.2 / 29.0.4 | feature | dropped | prepare | `environment` | the factory's; to run again | 51 s | 6.61 / 7.70 / 7.7 |
| **1283** | 2026-08-22 | 1.20.2 / 29.0.4 | feature | **checked** | | | | 651 s | 7.70 / 6.82 / 9.33 |
| **1282** | 2026-08-22 | 1.20.2 / 29.0.4 | feature | **checked** | | | | 250 s | 6.82 / 9.53 / 9.42 |
| **1281** | 2026-08-21 | 1.20.2 / 29.0.4 | feature | **checked** | | | | 390 s | 9.53 / 8.73 / 9.22 |

The load is the 1-minute load average on 28 threads; every check is "settled" (its highest load stayed under 12).

**Why each was left out:**
- **1290:** the hidden test file's tests pass on the unchanged project: nothing fails in its body.
- **1289:** its patch is over 1 MiB, which the engine does not take.
- **1288 and 1287:** features whose hidden tests call code the fix adds (1288 adds new modules under
  `lib/ambry/wanted/` and `lib/ambry_scraping/` and two LiveView pages; 1287 adds a public function that a new test
  file calls), so they cannot compile on the unchanged project and the run does not finish. This is the gate's row 4
  for features (`factory/README.md`, section 4). The engine keeps no output of the probe (registry E80); the cause is
  read from the patches.
- **1286:** it passed the probe and the first round of controls. In the second round two tests of
  `test/ambry_web/live/admin/inbox_live/form_test.exs` failed on the reference after passing in the first round.
  Both wait for background work with LiveView's `render_async`, whose default limit is 100 ms, so a busy machine can
  fail them. The second round keeps no output (registry E80), so the failure itself cannot be read. Not run again,
  since 3 cases were checked by then.
- **1284:** the build of its workspace image failed in Docker: "content digest … not found". The digest belonged to
  the engine's layout image for the database (`elixir-task-factory:layout-e418e414…`). The engine names that image by
  its recipe alone (`Eab.ServiceImages.ensure/3`), but every controller adds its own job label to what it builds, so
  each of the controllers on the machine builds a different image under the same name and moves the name to it.
  During this job the image under that name changed five times; at the end it carried another job's label. The
  factory's cause, seen only with several controllers on one Docker; not the pull request's, and to be run again.

**The three checked cases** (in the project's task folder on the data-mining machine, `WORK/tasks/ambry-app__ambry/`):

| Case | Kind | Hidden tests required | Fail before the fix | Existing-test files | Partial fix | Marks |
|---|---|---:|---:|---:|---|---|
| `ambry-pr-1283` | feature | 129 | 4 | 3 | present | `ai_written` |
| `ambry-pr-1282` | feature | 22 | 11 | 3 | present | `adds_migration`, `ai_written` |
| `ambry-pr-1281` | feature | 16 | 2 | 5 | present | `touches_assets`, `ai_written` |

No existing-test file was left out in any of the three. Each has a partial fix that the controls reject.

**Counts per reason** (`counts.tsv`, by each pull request's last try): checked 3; `start_run_did_not_finish` 2;
`patch_over_1_mib` 1; `no_starting_failure` 1; `unstable` 1; `environment` 1. **By whose cause:** the pull request's
4, the factory's 1, probably the machine's 1.

### The rest of the project's candidates

`candidates_ambry.tsv` (all 92 screened candidates since 2024, with what each still needs):

| Status | Pull requests | Why |
|---|---:|---|
| tried here | 9 | above |
| ready, not tried | 13 | 1280, 1279, 1277, 1276, 1274, 1275, 1272, 1269, 1268, 1267, 1266, 1265 (Elixir 1.20.2 / OTP 29.0.4), and 1013 (1.18.3 / 27.3) |
| waits for a release file | 67 | from pull request 1263 back, the application calls `shaka-packager` (`lib/ambry/media/processor/`), and CI installs version 3.4.2 from its GitHub release page. Fetching it needs the owner's word, so it was not fetched |
| left out | 3 | 995 (`no_image:1.18.2/27.2.2`) and 966 (`no_image:1.18.1/27.2`): OTP 27.2 is never built; 820: `elixir_before_1.18` (1.16.2) |

## 3. The licence scan and the hold-out check

Run on each checked case, one at a time, with the factory's tools unchanged
([`factory/tools/`](../../../factory/tools/README.md)), in a Python container with no network; the Hex metadata was
fetched with `HEX_FETCH=1`. 13 s to 17 s per case.

| Case | Licence: files touched / passing | Root licence | Hold-out: repository, names | 8-word spans shared (common, syntax, own tree, to read) | 12-word spans shared | Result |
|---|---|---|---|---|---|---|
| `ambry-pr-1283` | 8 / 8 | MIT | pass, 0 name hits | 10 (10, 0, 0, 0) | 3 (3, 0, 0, 0) | **pass, pass** |
| `ambry-pr-1282` | 10 / 10 | MIT | pass, 0 name hits | 15 (10, 2, 3, 0) | 3 (3, 0, 0, 0) | **pass, pass** |
| `ambry-pr-1281` | 14 / 14 | MIT | pass, 0 name hits | 10 (10, 0, 0, 0) | 3 (3, 0, 0, 0) | **pass, pass** |

No span is `to-read`, so nothing needed reading. The span tables hold span ids only (`holdout_hits.tsv`).

**Dependencies** (`deps.tsv`; the three starting commits lock the same 90 packages): 88 declare an allowed licence by
SPDX id; `natural_order` 0.3.0 declares "Apache 2.0" (allowed, not an SPDX id); the git dependency `boundary` at
`da77b9b` carries the MIT licence (its `LICENSE` and its `mix.exs`, read from the project's built image, since the
tool does not read git dependencies). So every dependency is under an allowed licence.

**A held-out library as a dependency:** ambry depends on `absinthe` 1.11.0, `absinthe_plug` 1.5.10 and
`absinthe_relay` 1.6.0, the bench's held-out project's own packages, and on `dataloader` 2.0.2 from the same GitHub
organisation. This is allowed for a task ([the rules](../../dataset_rules.md), section 4); a session that reads or
prints a file of the held-out project's own package is dropped as `quotes_held_out` (section 6).

## 4. Time, load and disk

- **Per checked case:** the check took 651 s, 250 s and 390 s (the engine's own total 643.9 s, 243.6 s, 380.3 s:
  preparation 37.7 s to 51.9 s, the probe 60.2 s to 212.0 s, the controls with the second round 123.0 s to 401.4 s).
  Making the folder took 5 s to 11 s, the export under 2 s, the two scans 13 s to 17 s.
- **The whole job** ran from 13:16 to 14:27: the controller image 5 s (its steps cached by the other jobs' builds of
  the same `main`), the set-up and the suite 4.5 min (13:20:44 to 13:25:16), the cases from 13:25:49 to 14:23:15 with
  the two stops of section 5, the scans under 1 min for the three.
- **Load:** the highest 1-minute load during the cases was 10.33 on 28 threads (13:37:58; sampled every 10 s by the
  driver's watcher); never near the stop rule of 26.
- **Disk of this job:** the controller's folder 132,552,619 bytes, the job folder 129,148,787 bytes (most of it the
  maker's Git cache and a full clone of the project, 10 MB each, and the engine's sources), the three task folders
  121,220 bytes. Docker images that carry this job's label: 17, of which 2,196,996,498 bytes are shared with no other
  image (Docker's count; their total size, shared layers counted in each, 20,029,895,024 bytes). The controller's
  image is the same image as the four other case jobs' (the same build of `main`), so it adds no bytes. Free space on
  `/` went from 798,034,067,456 to 752,955,428,864 bytes over the job, mostly the other jobs' images and build cache.
  The per-try columns `own_images_*` count this job's images, `machine_disk_used_bytes` the whole machine.

## 5. Faults of the job's own scripts (fixed here)

The driver scripts are the nerves_hub_web job's of the same day. Two faults in them stopped this job twice; both are
fixed in this folder's `run/`, and neither changed a verdict:
- **The check's record was unreadable.** The controller runs as root and writes each check job's record
  (`factory/jobs/<job>/job.json`) readable by root only. Started as an ordinary user, `one.sh` could not read it and
  waited for ever after pull request 1290's check had ended. The driver now runs as root, as the other jobs' do.
  1290 was checked again with the same result (`no_starting_failure`).
- **The image list passed Linux's 128 KiB limit for one argument.** `one.sh` handed Docker's whole image list to `jq`
  as one argument; with all the jobs' images (327) that is over 128 KiB, so `jq` could not start ("Argument list too
  long", exit 126). Pull request 1288's check ended without its row, and the next 18 pull requests ended at once
  without a step. The list now goes through a file. 1288 was checked again with the same result
  (`start_run_did_not_finish`); the 18 were run after the fix (6 of them before the job reached 3 checked).
- **The scan's span file** first pointed into a folder that did not exist, so the hold-out tool ended with an error
  after writing its tables; all three scans were run again with the path fixed (`run/scan.sh`), with the same results.

## Files

| File | What it holds |
|---|---|
| `project_tests.tsv` | the run of the project's suite: the engine's verdict, ExUnit's counts and time, the output size |
| `cases_ambry.tsv` | the 9 pull requests tried, one line each: merge date, Elixir/OTP, kind, verdict, step, reason, whose cause, the wall time of each step and the engine's step times, the load, the job's own images and the machine's disk change |
| `whose.tsv` | whose cause each drop is, and why (written from each drop's detail) |
| `counts.tsv` | the pull requests per verdict, step and reason |
| `candidates_ambry.tsv` | the 92 screened candidates: Elixir/OTP, the image now, what else they need, where each stands |
| `licence_tasks.tsv`, `licence_files.tsv` | the licence scan: per case, and per touched file |
| `holdout_tasks.tsv`, `holdout_hits.tsv` | the hold-out check: per case, and per shared span (ids only) |
| `deps.tsv` | the 90 locked dependencies and their declared licences |
| `run/build.sh`, `run/controller.sh`, `run/state.sh`, `run/watch.sh`, `run/row.sh`, `run/make_one.exs`, `run/make_probe.sh`, `run/prepare.exs`, `run/tests.exs`, `run/suite.sh`, `run/suite_tables.sh` | nerves_hub_web's job scripts of 2026-11-12, unchanged |
| `run/env_tests.sh` | the project's own tests (probe, prepare, suite), with the project as settings |
| `run/one.sh` | one pull request: make, import, check, export; the image list through a file |
| `run/all.sh` | the driver: newest first, until `TARGET` checked or `MAX_TRIED` tried; a second try for a check that was not settled, or for the numbers in `RETRY` |
| `run/table.sh` | the per-try table, the counts and the images from the driver's rows |
| `run/final_tables.sh` | `cases_ambry.tsv` and `candidates_ambry.tsv` |
| `run/scan.sh` | the licence scan and the hold-out check, one case at a time |

## Commands

On the data-mining machine, as root, in a job folder `$JOB` holding `run/` (this folder's scripts), `src/` (the
factory folder of `main` with the recipe), `tables/` (the census, unpacked, the screen and the classes table of the
screening, and `resolve_after.tsv`), `numbers.txt` (the 21 newest numbers, newest merged first), `cache/` (a folder
holding `ambry-app__ambry.git`, a clone, for the maker) and `ambry.git` (a full clone); `$CTL` is a new folder and
`$WORK` the factory's work folder:

```sh
SRC=$JOB/src OUT=$JOB/out LABEL=task-factory=1 IMAGE=elixir-task-factory:ambry-20261112 $JOB/run/build.sh controller
CTL=$CTL NAME=factory-ambry SOURCES=$JOB IMAGE=elixir-task-factory:ambry-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-ambry EPMD_PORT=4518 PREPARE_WORKERS=1 PREPARE_AHEAD=1 $JOB/run/controller.sh up
JOB=$JOB OUT=$JOB/out/suite CTL=$CTL NAME=factory-ambry JOB_LABEL=task-factory-job=hb-ambry TASK_LABEL=task-factory=1 \
  DATA=$CTL/data GIT_DIR=$JOB/ambry.git NUMBER=1290 MERGE=d9cc0d78dbf146cb62da3b71c81cc01740571f39 ROUNDS=1 MAX_LOAD=26 \
  $JOB/run/suite.sh
D=$CTL/data/env OUT=$JOB/out/suite ROUNDS=1 $JOB/run/suite_tables.sh
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-ambry CACHE=$JOB/cache $JOB/run/all.sh stage
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-ambry OUT=$JOB/out/cases JOB_LABEL=task-factory-job=hb-ambry \
  TASK_LABEL=task-factory=1 TARGET=3 MAX_TRIED=12 MAX_LOAD=26 $JOB/run/all.sh run
SRC=$JOB/src DEST=$WORK/tasks/ambry-app__ambry WORK=$JOB/out/scan CLONES=$JOB/ambry.git BENCH_SRC=<the bench's cases/ folder> \
  LABELS=task-factory=1,task-factory-job=hb-ambry HEX_FETCH=1 $JOB/run/scan.sh ambry-pr-1283 ambry-pr-1282 ambry-pr-1281
OUT=$JOB/out/cases NUMBERS=<the numbers tried> PREFIX=ambry TASKDIR=$CTL/data/ambry/tasks \
  SCREEN_TSV=$JOB/tables/screen_ambry-app__ambry.tsv $JOB/run/table.sh tasks > tasks.tsv
TASKS=tasks.tsv OWN=own_images.tsv WHOSE=whose.tsv $JOB/run/final_tables.sh cases > cases_ambry.tsv
TASKS=tasks.tsv CLASSES=$JOB/tables/classes_ambry.tsv RESOLVE=$JOB/tables/resolve_after.tsv \
  $JOB/run/final_tables.sh ready > candidates_ambry.tsv
CTL=$CTL NAME=factory-ambry $JOB/run/controller.sh stop
```

The controller's Git cache was given to root (`chown -R 0:0 $CTL/data/ambry/cache`) after staging, since the
controller runs `git` as root. `own_images.tsv` was made with Docker's API (`/system/df`): the images that carry the
job's label, joined with each try's `images_added.tsv`.

## Provenance and licence

ambry is MIT (`LICENSE` at each starting commit, read by the maker and by the licence scan). The tables hold pull
request numbers, merge dates, file names, image names, counts and times. They hold no source code, no pull request
text and no test text.
