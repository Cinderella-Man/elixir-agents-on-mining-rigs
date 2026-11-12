# bikebrigade/dispatch: the project's set-up in the task factory, and its checked cases (2026-11-12)

Registry row [E68](../../../experiments.md) (the pilot of the task factory). `bikebrigade/dispatch` is one of the
dataset's 16 applications ([rules](../../dataset_rules.md)). This job wrote the project's recipe, ran the project's
whole test suite once through the engine, and made and checked every candidate on Elixir 1.18 or newer, one at a time,
newest merged first, through a controller built from this repository's `main` at `60b1a65`. Everything ran on the
data-mining machine (28 threads, 30 GiB, no GPU) while other task-making jobs and one job that uses the model shared
it. Times are the data-mining machine's (UTC+1).

## Result

- **2 cases are checked and pass both scans:** pull requests 558 and 549, both features (by the kind in their
  `case.json` and by the maker's rule as written). There is no bug fix: the project has no other candidate on Elixir
  1.18 or newer.
- **Only 5 of the project's candidates are on Elixir 1.18 or newer.** The project moved from Elixir 1.15 (OTP 26) to
  Elixir 1.20 (OTP 29) on 2026-10-21; the 5 candidates merged since then are the whole list. The screening's other 46
  candidates since 2024 name Elixir 1.15 or 1.14.2 at their starting commits and are left out as `elixir_before_1.18`
  (`list.tsv`); the 24 older candidates (2021 to 2023) were not taken by the screening.
- **The 3 others are left out for their own reasons:** 550 changes nothing (its merge commit has the same tree as its
  parent: the same change had landed through 549), refused by the maker as `paths_never_match`; 540's test file holds a
  test the project marks as skipped, dropped at the probe as `skipped_test`; 538's hidden test reads a shared fake
  without waiting for the background task that writes to it, and it passed in the first round and failed in the second
  in both of its two checks, dropped as `unstable` (section 3). None was the machine's or the factory's.
- **The project needs a PostGIS database.** Its migrations run `CREATE EXTENSION postgis` and add `geography`
  columns, and its CI runs the tests on `postgis/postgis:16-3.6`. The engine's `postgres:*-alpine` images lack
  PostGIS, so the recipe names that image, pulled on the owner's word (2026-11-12: "Yes, download it"). Nothing else
  was added: no system package, no release file, no other service.
- **The whole suite passes** at the starting commit of pull request 558, on Elixir 1.20.4 with OTP 29.1.2 and
  PostgreSQL 16 with PostGIS 3.6: ExUnit's summary **358 passed, 1 skipped, in 23.4 s** (2.3 s async, 21.0 s sync).
  The skipped test is the project's own (`@tag :skip`). The engine's record is complete: 359 records, all distinct.
- **A check took 480 s (558) and 551 s (549),** the first check of each. The whole job, from the first read of the
  machine to the controller's stop, took 47 minutes; the driver's 8 tries took 33 minutes.

## 1. The project's set-up

The recipe is [`factory/recipes/bikebrigade__dispatch.json`](../../../factory/recipes/bikebrigade__dispatch.json). It is
a plain recipe, not a template: the toolchain resolver reads a CI database image's major version and takes the image
table's plain Postgres line for it, which has no PostGIS (and the table has no Postgres 16 line, so the resolver would
refuse every commit as `no_service_image:postgres/16`). All 5 starting commits name the same versions, so one fixed
recipe holds them all.

| What | Value | Where it comes from |
|---|---|---|
| Elixir and OTP | `hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1`, pinned by digest (the image table's line for 1.20.4/29.1.2) | the project's `Dockerfile` builds on `hexpm/elixir:1.20.4-erlang-29.1.2-alpine-3.24.2` at all 5 starting commits; the CI names `1.20` and `29`; `mix.exs` asks `~> 1.20`; no `.tool-versions` |
| Database | `postgis/postgis:16-3.6`, pinned by its index digest `sha256:d07ce3f06f657b6516c7511412232e97174d7e9dcf4c9fe520109b682b44a201` (PostgreSQL 16 with PostGIS 3.6, Debian; 237,638,812 bytes compressed for amd64 by Docker Hub, 950,576,003 bytes on disk by Docker); used for this project only, with nothing installed into it | the CI workflow's `services:` and `docker-compose.yml` start this image; the migrations run `CREATE EXTENSION postgis` and add `geography` columns. The other extensions they create (`citext`, `fuzzystrmatch`, `pg_trgm`, `unaccent`) ship with PostgreSQL itself |
| Other services | none | no Redis client in `mix.exs`; the CI starts only the database |
| System packages | none | |
| Database commands | `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the project's `test` alias runs `ecto.create --quiet`, `ecto.migrate`, `test` |
| Build | `mix compile` after the engine's own dependency steps | the bench's default recipe |
| Whole-suite command | `mix test` | the CI workflow's test step |
| Excluded tags | none | the project's `test_helper.exs` excludes nothing |

What the build fetches besides Hex packages, as the project's `mix.exs` and `mix.lock` ask: two dependencies from
GitHub at the commits `mix.lock` pins (`linkify`, `ecto_view_migrations`), and the compiled part of `lazy_html`
(`cc_precompiler`) from its own release page, as in other projects. The project's test configuration replaces every
outside service with a fake (Slack, SMS, geocoding, media storage, Mailchimp, Google); its endpoint listens on port
4002 inside the workspace container during the tests.

The recipe ran with one more field, `provisional`, while the database image waited for the owner's word; the maker
never copies it, and it was removed once the image was pulled and the suite had run.

## 2. The project's own suite

A hand-made probe task for pull request 558 (`run/make_probe.sh`, with its own id and a 1,800-second limit for one
test command) was prepared through the controller (`run/prepare.exs`) in 158.6 s cold (the engine's own step 158.4 s:
the toolchain image, the workspace image, and the PostGIS database set up once for its family), and the whole suite
ran once through the engine's own runner (`run/tests.exs`), in a fresh workspace container with a fresh database and no
network. `project_tests.tsv`:

| Run | ExUnit tests | Passed | Failed | Skipped | ExUnit time | Engine time | Return code | Output | Engine: finished |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 359 | 358 | 0 | 1 | 23.4 s | 24.7 s | 0 | 96,314 bytes | yes (359 records, all distinct) |

The engine's own `passed` is false only because of the skipped test: the grader passes no skipped test. That test is
`BikeBrigadeWeb.CampaignLiveTest` "New create campaigns", marked `@tag :skip` above `describe "New"` (so ExUnit applies
it to the first test only and warns about the tag). It matters for a case whose hidden tests include it (540, below).

## 3. The candidates

The screening's list ([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)) holds 51
candidates of this project since 2024 (75 in all); 5 of them are on Elixir 1.18 or newer (`list.tsv`). Each of the 5
was made ahead of any check through the controller (`run/make_ahead.sh`, the bundle maker with the source check and
the import check; `made_ahead.tsv`), then imported, checked with `factoryctl check --concurrency 1` and, when checked,
exported, one at a time, newest merged first (`run/all.sh`). A check is settled when the 1-minute load stayed under 12
during it; a check that was not settled was run once more at the end. `tasks_dispatch.tsv` has one line per try with
every column; the engine's step times are in seconds.

| Try | Pull request | Merged | Elixir/OTP | Kind | Verdict | Step | Reason | Whose | Make | Check (prepare / probe / controls) | Load at start → end (highest in the check) | This job's images added (Docker's bytes) |
|---|---|---|---|---|---|---|---|---|---:|---|---|---:|
| 1 | 558 | 2026-11-07 | 1.20.4/29.1.2 | feature | **checked** | - | - | - | 4 s | 480 s (133.5 / 125.4 / 218.8) | 7.90 → 11.01 (11.6), settled | 1,035,014,481 |
| 1 | 550 | 2026-10-29 | - | - | refused | maker | `paths_never_match` | the pull request's | 5 s | - | 11.01 → 10.94 | 0 |
| 1 | 549 | 2026-10-22 | 1.20.4/29.1.2 | feature | **checked** | - | - | - | 2 s | 551 s (239.8 / 124.3 / 185.3) | 10.94 → 14.11 (17.05), not settled | 2,142,377,254 |
| 1 | 540 | 2026-10-21 | 1.20.4/29.1.2 | feature | dropped | probe | `skipped_test` | the pull request's | 5 s | 121 s (83.6 / 28.2 / -) | 14.11 → 13.00 (14.28), not settled | 2,142,116,635 |
| 1 | 538 | 2026-10-21 | 1.20.4/29.1.2 | feature | dropped | second round | `unstable` | the pull request's | 2 s | 391 s (175.0 / 98.1 / 114.7) | 12.92 → 10.80 (13.73), not settled | 2,142,068,553 |
| 2 | 549 | | | | **checked** | - | - | - | - | 120 s (0.1 / 118.3 / 0.2) | 10.49 → 14.51 (14.3), not settled | 0 |
| 2 | 540 | | | | dropped | probe | `skipped_test` | the pull request's | - | 30 s (0.2 / 29.7 / -) | 14.51 → 14.96 (14.6), not settled | 0 |
| 2 | 538 | | | | dropped | second round | `unstable` | the pull request's | - | 251 s (0.2 / 110.4 / 133.7) | 14.96 → 12.67 (15.38), not settled | 0 |

- **550:** its merge commit `80327f8` has exactly the tree of its parent `7d3b456`. The pull request's change had
  landed on `main` through pull request 549 (merged a week earlier), so this merge changes nothing,
  and no first parent within 30 commits changes the census's paths.
- **540:** its hidden tests include `test/bike_brigade_web/live/campaign_live_test.exs`, which holds the project's
  skipped test (section 2): "the project marks hidden tests as skipped: Elixir.BikeBrigadeWeb.CampaignLiveTest::test
  New create campaigns". No fix could pass such a task (rules, section 4).
- **538:** in both checks the reference passed the hidden test
  `BikeBrigade.Tasks.MailchimpImporterTest` "sync_riders/0 handles case where phone is invalid" in the first round and
  failed it in the second ("2 named outcomes changed": the test, and with it the reference). The importer sends its
  Slack message from a background task (`Task.start`), and the test reads the fake Slack server's last call as soon as
  `sync_riders/0` returns, so the outcome depends on which process runs first. The race is in the pull request's own
  test; a busy machine makes it lose more often. Both checks ran with the load between 10.8 and 15.4. The engine keeps
  no output of a second-round run, so the failing assertion itself is not recorded.
- **549's second check** reused the controls the first had saved (the task, the grading code and the images were
  unchanged; controls 0.2 s), so it repeated the probe only. The first check's second round agreed.
- **The kinds:** both checked cases are features by `case.json` and by the maker's rule read one line at a time
  (`kind_rule.tsv`): 558 adds the public function `mark_campaign_tasks_complete_by_rider` and a `handle_event` clause;
  549 adds a `handle_event` clause. The other three made folders were features too.

`checked.tsv`, per checked case:

| Case | Hidden tests failing first | Passing after | Existing test files kept | Left out | Partial fix | Second round agrees |
|---|---:|---:|---:|---:|---|---|
| 558 | 7 | 61 | 3 | 0 | present | yes |
| 549 | 1 | 23 | 2 | 0 | present | yes |

Counts by each pull request's last try (`counts.tsv`): 2 checked, 1 refused by the maker (`paths_never_match`), 1
dropped at the probe (`skipped_test`), 1 dropped at the second round (`unstable`); and 46 not made
(`elixir_before_1.18`).

## 4. Licence and hold-out

Run on each checked task, one at a time (`run/run_scans.sh`, which calls `run/scans.sh` and through it
`factory/tools/check_tasks.sh` of `main` at `60b1a65`), in a Python container with no network; Hex metadata was fetched
for the dependency list. `scans.tsv`, `licence_root.tsv`, `licence_files.tsv`, `holdout_tasks.tsv`, `deps_flagged.tsv`:

| Task | Licence result | Root licence | Files touched | Files passing | Hold-out result | Name hits | Shared 8-word runs (`common` / `syntax` / own tree) | Shared 12-word runs |
|---|---|---|---:|---:|---|---:|---:|---:|
| 558 | pass | `ok:licence-file` (`LICENSE`), Apache-2.0 | 8 | 8 | pass | 0 | 4 (4 / 0 / 0) | 0 |
| 549 | pass | `ok:licence-file` (`LICENSE`), Apache-2.0 | 6 | 6 | pass | 0 | 4 (4 / 0 / 0) | 0 |

- **The project's licence:** the Apache License 2.0 text in `LICENSE` at the root (SHA-256
  `0cec06e0e55fbc3dc5...`, unchanged since 2021). Every touched file passes at both commits; no file is long enough to
  be left out of the scan. The table's `holders` column holds a phrase of the licence text itself (the licence names
  no holder); it is not a copyright holder.
- **The locked dependencies** (`deps_flagged.tsv`, those not plainly allowed, with the number of tasks that lock each):
  the two GitHub dependencies (`linkify`, `ecto_view_migrations`), whose licences the tool does not read; `exexif`
  0.0.5, whose Hex metadata says "MIT. See LICENSE.md" (outside the tool's spellings); `poison` 4.0.1, CC0-1.0 (outside
  the list); and four that spell Apache-2.0 loosely. These matter for sessions (rules, section 6), not for the tasks.
- **Hold-out:** the repository is not held out, no task names a held-out project, and every shared 8-word run is
  `common` (it occurs in the cases of two or more of the bench's projects). No run needs reading, and no task shares a
  12-word run.

## 5. How the run went

- The controller was built and the 5 folders were made while the database image waited for the owner's word; the
  controller was then stopped and started again after the pull. The driver scripts are those of
  [2026-11-12_cases_hexpm_hexpm](../2026-11-12_cases_hexpm_hexpm/README.md), with this project's names: the driver runs
  as root (the engine's job records are readable by root only), and `run/one.sh` passes Docker's image list through a
  file. New here: `run/make_ahead.sh` (the folders made before any check), `run/pub.sh` (all tables in one step), and
  `table.sh` reads the Elixir/OTP pair from the runtime image's tag when a folder has no resolver record.
- The driver ran once (18:05 to 18:38). No try was the machine's (no time-out, lost database connection or lost
  image). No stop rule fired: free bytes on the system disk never under 50,000,000,000, the 1-minute load never above
  26 (highest seen by the watcher 17.05, at 18:18), no bench run.

## 6. Disk and load

- **This job's images** carry its label (`own_images.tsv`, Docker's bytes, which overlap since images share layers):
  one toolchain image (869,696,604) tagged for each task, 5 workspace images (each tagged `project` and `seed`,
  1,035,014,481 to 1,048,410,291 bytes), 4 database snapshots (1,093,965,953 to 1,093,974,923) and the database layout
  image on the PostGIS image (950,593,274). The PostGIS image itself is 950,576,003 bytes.
- **This job's folders:** the controller's folder 67,687,773 bytes, the job folder 53,165,410 bytes, the 2 exported
  task folders 55,619 bytes.
- **The machine:** free bytes on the system disk 653,762,027,520 when the job started (17:53) and 614,852,370,432 when
  the driver ended (18:39), with every job's use in it. The 1-minute load was 3.60 at the start; during the checks it
  ran from 7.90 to 17.05 on 28 threads.
- **The engine's own limits:** one preparation worker and one check at a time (`--concurrency 1`); the engine has no
  switch for build jobs, and every workspace container runs Erlang with 2 schedulers (the engine's `ERL_FLAGS
  "+S 2:2"`). Every container carried the labels `task-factory=1` and `task-factory-job=hb-dispatch` and a CPU share of
  256.

## Files

| File | What it holds |
|---|---|
| `list.tsv` | the screening's 51 candidates since 2024, newest first: merge date, starting commit, the Elixir/OTP it names, the screening's class, and this job's outcome |
| `made_ahead.tsv` | the bundle maker's result for each of the 5, before any check: made or refused with the reason, the kind, the time |
| `tasks_dispatch.tsv` | one line per try: number, id, merge date, Elixir/OTP, kind, folder origin, verdict, step, reason, the driver's step times, the engine's step times, load at start and end and the highest during the check, settled, the bytes of every image the machine gained meanwhile (all jobs'; images share layers), the build cache's change, the disk bytes used (all jobs'), start, end, and this job's own images and their bytes |
| `counts.tsv` | pull requests per verdict, step and reason, each by its last try |
| `checked.tsv` | per checked case: kind, hidden tests failing first and passing after, existing test files kept and left out, the partial fix, the second round |
| `kind_rule.tsv` | per exported task folder: the kind in `case.json`, the kind by the maker's rule as written (read one line at a time), the files and public functions the reference adds |
| `project_tests.tsv` | the whole-suite run: the engine's verdict and counts, ExUnit's summary, the output's size |
| `scans.tsv` | per task: the licence result, the root licence family, files touched and passing, the hold-out result, name hits, seconds |
| `licence_root.tsv` | per task: the root licence's result, the file it was read from and that file's SHA-256, the family |
| `licence_files.tsv` | per task and touched file: which patches touch it, the scan's verdict at the starting and the merge commit, the result |
| `holdout_tasks.tsv` | per task: the repository check, name hits, and the shared 8- and 12-word runs by class |
| `deps_flagged.tsv` | the locked dependencies whose licence is not plainly in the list, with the number of tasks that lock each |
| `own_images.tsv` | every image of this job: id, tags, Docker's size |
| `run/` | the scripts that ran (below) |

## Commands

On the data-mining machine, as root (the engine's job records are readable by root only). `WORK` is the factory's
work folder (with `tasks/`), `JOB` this job's folder (with `run/`, `src/` = this repository's `factory/` at `60b1a65`
plus this recipe, `tables/` = the screening's census, screen and class tables of dispatch, `numbers.txt` = the 5
candidates on Elixir 1.18 or newer, `dispatch.git` = a bare clone of the project, `cache/bikebrigade__dispatch.git` = a
copy of it owned by root), `CTL` the controller's folder.

```sh
docker pull postgis/postgis:16-3.6@sha256:d07ce3f06f657b6516c7511412232e97174d7e9dcf4c9fe520109b682b44a201
SRC=$JOB/src OUT=$JOB/logs IMAGE=elixir-task-factory:dispatch-20261112 LABEL=task-factory=1 run/build.sh controller
CTL=$CTL NAME=factory-dispatch SOURCES=$JOB IMAGE=elixir-task-factory:dispatch-20261112 \
  HEX_CACHE_ID=etf-hex-packages-v1 LABELS=task-factory=1,task-factory-job=hb-dispatch EPMD_PORT=4522 \
  PREPARE_WORKERS=1 PREPARE_AHEAD=1 run/controller.sh up
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-dispatch CACHE=$JOB/cache run/all.sh stage
JOB=$JOB CTL=$CTL NAME=factory-dispatch run/make_ahead.sh 558 550 549 540 538

# the whole suite once at the starting commit of pull request 558 (merge commit d5eb71d5)
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/dispatch.git NAME=factory-dispatch NUMBER=558 \
  MERGE=d5eb71d50095a330af5303040dd73eb49a805ce8 ROUNDS=1 TEST_TIMEOUT=1800 SUB=env OUT=$JOB/out/suite CTL=$CTL \
  JOB_LABEL=task-factory-job=hb-dispatch TASK_LABEL=task-factory=1 MAX_LOAD=26 MIN_FREE=50000000000 run/suite.sh
D=$CTL/data/env OUT=$JOB/out/suite ROUNDS=1 run/suite_tables.sh

# the cases: newest first, one at a time
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-dispatch JOB_LABEL=task-factory-job=hb-dispatch TASK_LABEL=task-factory=1 \
  TARGET=20 MAX_TRIED=80 MAX_LOAD=26 MIN_FREE=50000000000 run/all.sh run

# the licence scan and the hold-out check, one task at a time
JOB=$JOB WORK=$WORK BENCH_CASES=<the bench's cases/ folder> run/run_scans.sh dispatch-pr-558
JOB=$JOB WORK=$WORK BENCH_CASES=<the bench's cases/ folder> run/run_scans.sh dispatch-pr-549

# the tables
JOB=$JOB TASKDIR=$WORK/tasks/bikebrigade__dispatch JOB_LABEL=task-factory-job=hb-dispatch DEST=<this folder> run/pub.sh
CTL=$CTL NAME=factory-dispatch run/controller.sh stop
```

`run/run_scans.sh` writes `JOB/out/scans/scans.tsv` for every task scanned so far, so the second call's table holds
both. The shared spans' text (`LOCAL_spans.json`) is removed after each scan; it is never published.

## Provenance and licence

The project is `bikebrigade/dispatch` on GitHub, Apache License 2.0. The tables hold pull request numbers, commit ids,
file paths, test names and counts, not the pull requests' titles, bodies or code. The scripts are this repository's.
