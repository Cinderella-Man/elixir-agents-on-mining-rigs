# zorn/flick in the task factory: the project's set-up and its checked cases (2026-11-12)

Registry rows [E68](../../../experiments.md) (the task factory's pilot) and E82 (the 16 dataset projects). `zorn/flick`
is one of the 16 applications of the dataset ([2026-11-12_dataset_projects](../2026-11-12_dataset_projects/README.md)).
This job set the project up in the task factory, ran its own test suite once in the engine, and made and checked its
usable pull requests as cases, newest merged first, one at a time, until the list ran out (the target was 20 good
cases). Everything ran on the data-mining machine through a controller of its own, built from the factory's `main` at
`f3c2082`, while other task jobs used the same Docker daemon.

## Result

**flick has 11 good cases, and its list is used up (2026-11-12 19:14).** A case is good when the gate checked it and
it passes both scans. Every candidate on Elixir 1.18 or newer was tried; the target of 20 cannot be reached in this
project.

- **The project runs in the engine.** Its own suite passes whole at the newest candidate's starting commit: 210
  passed, 0 failed, in 1.9 s. Beyond the factory's defaults it needs one setting: the database port
  (`POSTGRES_PORT=5432`), because its test configuration defaults to 5418.
- **The list is short.** Of the project's 30 screened candidates, 14 are on Elixir 1.17 or 1.14
  (`elixir_before_1.18`), one is on Elixir 1.18.0 with OTP 27.1.3, which the factory never builds
  (`no_image:1.18.0/27.1.3`, refused by the maker in seconds), and one is the merge of a side branch whose own pull
  requests are candidates (`contains_other_candidates`, section 3; never made). That left 14 to make and check.
- **Good (11): 341, 339, 330, 327, 310, 276, 274, 261, 222, 221 and 213** (merged 2026-09-27 to 2026-10-28). By the
  maker's label six are bug fixes (341, 330, 276, 274, 261, 221) and five features (339, 327, 310, 222, 213); the
  label agrees with its written rule read line by line for every checked case ([`kind_rule.tsv`](kind_rule.tsv)). By
  the project's own commit type two of the five features are bug fixes (339 and 222, type `fix`): each adds a file
  (339 a migration), which the rule counts as a feature; 213 is a refactor. All 11 pass the licence scan (MIT, every
  touched file) and the hold-out check, 310 after its one shared 8-word run was read (test-file syntax).
- **Checked but not counted (1): 217.** The gate checked it, but it fails the licence scan: it adds
  `assets/vendor/sortable.js`, a minified copy of a third-party JavaScript library (Sortable 1.15.7, whose header
  names MIT), which the scan marks `exclude:vendored`; the rules page, section 4, fails a case for such a file. The
  case folder is kept.
- **Left out (2), for the pull request's own reason, both `no_existing_tests`:** 322 has no existing test file to
  protect (refused by the maker); 215's two existing test files fail on its own merged code in both of the probe's
  runs (`fails_on_reference`: the change alters what their old versions check), so none is left to protect.
- **None failed for the machine's reasons;** no candidate was run twice.
- **Time per checked case** (the engine's own count): 343.8, 193.5, 165.2, 193.8, 277.3, 353.8, 346.3, 317.1, 288.1,
  184.6, 169.2 and 127.5 s for 341, 339, 330, 327, 310, 276, 274, 261, 222, 221, 217 and 213; 215's check ended at
  the probe after 70.0 s. Making each case took 6, 5, 6, 5, 5, 15, 5, 6, 10, 5, 6 and 5 s in the same order (the
  `make_s` column of [`cases.tsv`](cases.tsv)). The whole run of 15 pull requests took 56 min (18:18:12 to 19:14:39).
- **Disk:** each made case adds a project image of about 1.04 GB by Docker's size (est.; most of it shared with the
  other cases' images) and a database snapshot of about 489 MB, of which Docker counts about 56 MB as its own; every
  image's exact bytes and Docker's own share are in [`own_images.tsv`](own_images.tsv). Shared once: two toolchain
  images (909,190,563 bytes for 1.20.1 / 28.5.0.2, 869,696,758 bytes for 1.20.4 / 29.1.2) and the Postgres 18.6
  layout (432,794,066 bytes).

## 1. The project's set-up

The recipe is [`factory/recipes/zorn__flick.json`](../../../factory/recipes/zorn__flick.json). It is a template (it has
a `toolchain` block): the maker resolves each starting commit's Elixir and OTP itself. The resolver read both from the
project's `.tool-versions` (`erlang` and `elixir` lines) at every starting commit, and the database from the CI file
`.github/workflows/build-and-test.yaml`, which starts `postgres:18`.

| Field | Value | Why |
|---|---|---|
| `runtime.image` (default) | `hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1`, pinned by digest | the image table's line for the pair the newest starting commits name; older ones resolve to 1.20.1 / 28.5.0.2 |
| `runtime.environment` | `MIX_ENV=test`, `POSTGRES_PORT=5432` | `config/test.exs` reads the database port from `POSTGRES_PORT` and defaults to 5418 (the port the project's own `compose.yml` publishes); the engine's Postgres listens on 5432 in the workspace's network namespace. Starting commits before 2026-10-27 hard-code no port (Postgrex's default, 5432), so the setting changes nothing there |
| `runtime.packages` | none | the project's build and tests need no system package beyond the engine's own |
| `services.postgres` | `postgres:18.6-alpine`, pinned by digest | the image table's line for Postgres 18, the major version the CI file starts (`postgres:18`). The CI names no minor version, so this is the version it names, not a replacement |
| `baseline` | `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the project's `test` alias runs the same two steps before `mix test`, every run, so a migration a pull request adds is applied by the test command itself |
| `permitted_exclusion_tags` | none | `test/test_helper.exs` excludes no tag |
| `test_timeout` | 240 (the default) | the whole suite takes about 2 s |
| `grading.preservation` (the whole-suite command) | `mix test` | |

What the tests do not need: no ClickHouse and no Redis client is a dependency; OpenTelemetry's exporter is off in
`config/test.exs` (`traces_exporter: :none`); the mailer uses Swoosh's test adapter; Paraxial, which calls its service
on every boot, is not a dependency in `:test`. So no service besides PostgreSQL is started.

### What the project's own build fetches

Besides its Hex packages, the build fetches what the project's `mix.exs` and its packages pin:

| Dependency | From | Pinned by |
|---|---|---|
| `heroicons` | `github.com/tailwindlabs/heroicons`, tag `v2.2.0` (icons only: `app: false, compile: false`) | `mix.lock` |
| `mdex_native` 0.2.13 (Hex) | its prebuilt native file, from the package's GitHub release (`rustler_precompiled`) | the package's checksum file |
| `lazy_html` 0.1.13 (Hex; test only) | its prebuilt native file, from the package's GitHub release (`cc_precompiler`) | the package's checksum file |

## 2. The project's own tests

At the starting commit of pull request 341 (`24a590ce`, the newest candidate), a hand-made probe task
([`run/make_probe.sh`](run/make_probe.sh)) was prepared through the controller and the whole suite ran once through
the engine's own runner, in a fresh workspace container and a fresh copy of the database, with no network
([`run/suite.sh`](run/suite.sh)).

- **The preparation** took 180.9 s, cold: the workspace image (the dependencies fetched and compiled, the project
  compiled) and the database layout and its migrated snapshot on Postgres 18.6.
- **The suite: all of it passes.** ExUnit's own summary: **210 passed (2 doctests, 208 tests), 0 failed, 0 excluded,
  in 1.9 s** (1.9 s async, 0.06 s sync); the engine's run took 3.4 s and recorded 210 rows for 210 distinct names,
  every one passed. Its output was 34,815 bytes. Table: [`project_tests.tsv`](project_tests.tsv); no test failed, so
  there is no table of failures.

## 3. The cases

The list ([`list.tsv`](list.tsv), made by [`run/list.sh`](run/list.sh) from the screening's class table of the 16
projects): flick's 30 screened candidates, newest merged first. 14 are on Elixir 1.17.2, 1.17.3 or 1.14 and are left
out (`elixir_before_1.18`). The other 16 are the job's list. The toolchain resolver ran over them first
([`resolve.tsv`](resolve.tsv), [`run/resolve.exs`](run/resolve.exs)): 6 starting commits name Elixir 1.20.4 with OTP
29.1.2, 9 name Elixir 1.20.1 with OTP 28.5.0.2, every one in `.tool-versions`, and all 15 start Postgres 18 in CI;
109 names Elixir 1.18.0 with OTP 27.1.3 (and Postgres 16), a pair the factory never builds (the rules page, section 2),
and is refused `no_image:1.18.0/27.1.3`.

**One umbrella pull request.** 223 merged a side branch into `main`; five pull requests had been merged into that
branch one by one: 213, 215, 217, 221 and 222 (each a candidate of its own, with its own starting commit on the side
branch). 223's change contains all of theirs (28 files, 1,332 lines added, against 9, 5, 7, 2 and 7 files). It is
left out as `contains_other_candidates` (the rules page, section 3, decided while this job ran) and was never made
into a case; its five parts are checked on their own. The side branch's commits are not on `main`; the maker fetched
them by id.

The driver ([`run/all.sh`](run/all.sh)) takes the list one at a time through [`run/one.sh`](run/one.sh): the bundle
maker, the import, `factoryctl check --concurrency 1`, the export of a checked task, then the licence scan and the
hold-out check ([`run/scans.sh`](run/scans.sh), the factory's `tools/` unchanged). 223 was in the driver's hold file,
so it was skipped without any step.

[`cases.tsv`](cases.tsv) has one line per try: the merge date, the resolved Elixir/OTP, the kind, the verdict, the step
and reason of a drop, the wall time of each step, the engine's own step times, the 1-minute load at the start and the
end and its highest value during the check, the bytes of this job's own images the try added, the two scans and whose
cause a drop is. A check counts as settled when the machine’s 1-minute load stayed under 12 during it. With the other
jobs running, the load rose above 12 during eight of the first nine checks (all but 330's; the highest value of each is
in `load_max_check`), so those are "not settled"; the last four, from 221 on, are settled. That matters for a drop,
which is then run again; a check that passed under load passed all the same. Both drops (322 at the maker, 215 at a
load of 10.67) are settled.

| Pull request | Merged | Elixir / OTP | Kind | Verdict | Step, reason | Hidden tests failing first / passing after | Licence | Hold-out |
|---|---|---|---|---|---|---|---|---|
| 341 | 2026-10-28 | 1.20.4 / 29.1.2 | bug_fix | checked | - | 3 / 120 | pass | pass |
| 339 | 2026-10-28 | 1.20.4 / 29.1.2 | feature | checked | - | 2 / 86 | pass | pass |
| 330 | 2026-10-27 | 1.20.4 / 29.1.2 | bug_fix | checked | - | 2 / 83 | pass | pass |
| 327 | 2026-10-27 | 1.20.4 / 29.1.2 | feature | checked | - | 2 / 5 | pass | pass |
| 322 | 2026-10-21 | - | - | refused | maker, no_existing_tests | - | - | - |
| 310 | 2026-10-20 | 1.20.4 / 29.1.2 | feature | checked | - | 3 / 11 | pass | review, read: pass |
| 276 | 2026-10-11 | 1.20.1 / 28.5.0.2 | bug_fix | checked | - | 4 / 88 | pass | pass |
| 274 | 2026-10-11 | 1.20.1 / 28.5.0.2 | bug_fix | checked | - | 4 / 78 | pass | pass |
| 261 | 2026-10-06 | 1.20.1 / 28.5.0.2 | bug_fix | checked | - | 2 / 74 | pass | pass |
| 223 | 2026-09-28 | - | - | left out | contains_other_candidates (parts: 213, 215, 217, 221, 222) | - | - | - |
| 222 | 2026-09-28 | 1.20.1 / 28.5.0.2 | feature | checked | - | 5 / 70 | pass | pass |
| 221 | 2026-09-28 | 1.20.1 / 28.5.0.2 | bug_fix | checked | - | 1 / 31 | pass | pass |
| 217 | 2026-09-28 | 1.20.1 / 28.5.0.2 | feature | checked, not counted | - | 4 / 35 | fail: `assets/vendor/sortable.js` (`exclude:vendored`) | pass |
| 215 | 2026-09-28 | 1.20.1 / 28.5.0.2 | feature | dropped | probe, no_existing_tests (both existing test files `fails_on_reference`) | - | - | - |
| 213 | 2026-09-27 | 1.20.1 / 28.5.0.2 | feature | checked | - | 1 / 61 | pass | pass |
| 109 | 2025-01-11 | 1.18.0 / 27.1.3 | - | refused | maker, no_image:1.18.0/27.1.3 | - | - | - |

Every checked case but one has a partial fix that the gate rejected (`partial_fix` present); 221 changes one hunk, so it
has none (`single_hunk`). Whose cause each drop is, read by a person: [`causes.tsv`](causes.tsv).

**The scans** ([`scans.tsv`](scans.tsv), [`good.tsv`](good.tsv), [`holdout_reviews.tsv`](holdout_reviews.tsv),
[`deps.tsv`](deps.tsv)): the licence file is `LICENSE` (MIT, "Copyright (c) 2024 Mike Zornek") at every starting
commit, and every file a case touches passes, except one in 217: `assets/vendor/sortable.js`, which the pull request
adds, is a minified third-party library (its first line names Sortable 1.15.7 and MIT; 45,478 bytes), and the scan
marks it `exclude:vendored`, which fails the case (the rules page, section 4). The hold-out check found no held-out name. Its shared runs are classed
`common` (found in several held-out projects: mostly the task format’s own `case.json` fields, and Elixir syntax such as
closing `end`s), one is already in flick’s own tree (327), and one in 310 was to be read (span id in
[`holdout_reviews.tsv`](holdout_reviews.tsv)): read as boilerplate, the end of one test, ExUnit's `capture_log` tag
and the start of the next.

**Dependencies, for the later scan of sessions** ([`deps.tsv`](deps.tsv)): the checked cases lock 106 distinct
packages. Every Hex package declares a licence in the list (three spell Apache 2.0 loosely). The one Git dependency,
`heroicons` (tag `v2.2.0`, commit `0435d4ca`), is MIT ("Copyright (c) Tailwind Labs, Inc.", read in the dependency's
own `LICENSE` inside the workspace image; the scan does not read Git dependencies).

## 4. Files

| File | What it holds |
|---|---|
| [`cases.tsv`](cases.tsv) | one line per try (above); the pull requests not reached have one line "not run" with the reason |
| [`counts.tsv`](counts.tsv) | the pull requests by their last try's verdict, step and reason |
| [`causes.tsv`](causes.tsv) | the drops and the case not counted, read by a person: whose cause, and why |
| [`good.tsv`](good.tsv) | every checked case with its licence and hold-out results, its kind, and whether it counts |
| [`kind_rule.tsv`](kind_rule.tsv) | each checked case's kind in `case.json` beside the maker's written rule read one line at a time (registry E108) |
| [`scans.tsv`](scans.tsv) | the two scans per checked case: licence file, family, files touched and passing; the hold-out's checks and span counts |
| [`holdout_reviews.tsv`](holdout_reviews.tsv) | the hold-out hits read by a person (span ids, never their text) |
| [`deps.tsv`](deps.tsv) | the locked packages of the checked cases, their declared licences and class, and how many cases lock them |
| [`own_images.tsv`](own_images.tsv) | every image of this job: id, tags, Docker's size and its unique size |
| [`list.tsv`](list.tsv) | the 30 screened candidates and each one's status in this job |
| [`resolve.tsv`](resolve.tsv) | the toolchain resolver's reading of the 16 listed starting commits: Elixir, OTP, image, database, baseline and where each came from |
| [`project_tests.tsv`](project_tests.tsv) | the project's own suite: the engine's verdict, ExUnit's summary, the output's size |
| [`run/`](run/) | the scripts that ran: `controller.sh`, `build.sh`, `state.sh`, `watch.sh`; the suite (`suite.sh`, `env_tests.sh`, `make_probe.sh`, `prepare.exs`, `tests.exs`, `suite_tables.sh`); the cases (`list.sh`, `resolve.exs`, `all.sh`, `one.sh`, `make_one.exs`, `row.sh`, `scans.sh`, `kind_rule.sh`); the tables (`table.sh`, `collect.sh`); `read_large_file_hunks.py` (the mbta/screens job's helper, unchanged; no case here touches a long file) |

## 5. Exact commands

On the data-mining machine, as root, with `WORK` the factory's work folder, `JOB=$WORK/jobs/hb-flick` (this folder's
`run/`, the factory's folder as `src/` at `f3c2082` with the recipe added, `tables/` with the screening's census,
screen and class tables of the project, `flick.git` a full clone of the project), `CTL=$WORK/ctl-hb-flick`:

```sh
# the controller, apart from the other jobs' and the bench's
SRC=$JOB/src OUT=$JOB/logs IMAGE=elixir-task-factory:flick-20261112 LABEL=task-factory=1 $JOB/run/build.sh controller
CTL=$CTL SOURCES=$JOB IMAGE=elixir-task-factory:flick-20261112 NAME=factory-flick \
  LABELS=task-factory=1,task-factory-job=hb-flick HEX_CACHE_ID=etf-hex-packages-v1 EPMD_PORT=4525 \
  PREPARE_WORKERS=1 PREPARE_AHEAD=1 $JOB/run/controller.sh up
# the list (the class table's rows without its header) and the stage
CLASSES=$JOB/tables/classes_flick_rows.tsv OUT=$JOB/tables N=16 $JOB/run/list.sh && cp $JOB/tables/numbers.txt $JOB/
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-flick $JOB/run/all.sh stage
# the resolver over the list (resolve.exs and numbers.txt copied into $CTL/data/flick first)
CTL=$CTL NAME=factory-flick $JOB/run/controller.sh rpc 'System.put_env(%{"P5_DIR" => "/data/flick", "REPOSITORY" => "https://github.com/zorn/flick", "CENSUS" => "prs_zorn__flick.tsv", "SCREEN" => "screen_zorn__flick.tsv"}); spawn(fn -> Code.eval_file("/data/flick/resolve.exs") end)'
# the project's own suite, once, at pull request 341's starting commit
JOB=$JOB OUT=$JOB/suite CTL=$CTL NAME=factory-flick JOB_LABEL=task-factory-job=hb-flick TASK_LABEL=task-factory=1 \
  MAX_LOAD=26 MIN_FREE=50000000000 DATA=$CTL/data GIT_DIR=$JOB/flick.git NUMBER=341 \
  MERGE=aa58df2bbda1a9c78685d41d78830d11c1c80cd7 IMAGE=<the image table's line for 1.20.4/29.1.2> ROUNDS=1 SUB=env \
  TEST_TIMEOUT=1800 $JOB/run/suite.sh
D=$CTL/data/env OUT=$JOB/suite_tables ROUNDS=1 $JOB/run/suite_tables.sh
# the cases (a temporary copy of the bench's cases for the hold-out check first; deleted at the end)
BENCH_SRC=<the bench's cases folder> BENCH=$JOB/bench_cases OUT=$JOB/scans $JOB/run/scans.sh cases
echo flick-pr-223 >> $JOB/out/hold.txt   # contains_other_candidates
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-flick JOB_LABEL=task-factory-job=hb-flick TASK_LABEL=task-factory=1 \
  TARGET=20 MAX_TRIES=16 KIND_AFTER=99 KIND_MIN=3 MAX_LOAD=26 MIN_FREE=50000000000 $JOB/run/all.sh run
# the tables
HELD_REASON=contains_other_candidates JOB=$JOB WORK=$WORK CTL=$CTL PUB=<this folder> \
  JOB_LABEL=task-factory-job=hb-flick $JOB/run/collect.sh
$JOB/run/kind_rule.sh $WORK/tasks/zorn__flick > <this folder>/kind_rule.tsv
```

`KIND_AFTER=99` turns the driver's kind balance off: every candidate on the list is tried anyway, so holding one kind
back would only change the order. The watcher stops the job when a bench run starts, when free space on `/` falls
under 50,000,000,000 bytes (the owner, 2026-11-12: "do not stop until you get to last 50GB of free space"), or when the
1-minute load is above 26 in two readings 300 s apart. `scans.sh` reads `$JOB/flick.git`, a full clone of the project
into which the side branch's five merge commits were fetched by id.

## 6. Provenance and licence

The project's code is MIT (`LICENSE`, "Copyright (c) 2024 Mike Zornek"); the tables hold pull request numbers, commit
ids, file names and test names, never pull request titles, bodies or patch text. The scripts in `run/` are this
repository's: the santiment/sanbase2 job's scripts on the same machine with that project's names replaced by this
one's, `list.sh` reading a database-version note as no need, `watch.sh` with the owner's stop lines as its defaults,
and `kind_rule.sh` from the hexpm/hexpm job.
