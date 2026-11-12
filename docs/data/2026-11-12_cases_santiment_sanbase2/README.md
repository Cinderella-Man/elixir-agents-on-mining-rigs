# santiment/sanbase2 in the task factory: the project's set-up and its first checked cases (2026-11-12)

Registry rows [E68](../../../experiments.md) (the task factory's pilot) and E82 (the 16 dataset projects); queue
row HB16 (five project jobs, one project each). `santiment/sanbase2` is one of the 16 applications of the dataset
([2026-11-12_dataset_projects](../2026-11-12_dataset_projects/README.md)). This job set the project up in the task
factory, ran its own test suite once in the engine, and made and checked its newest usable pull requests as cases,
one at a time, first until 3 were checked, then (on the owner's word) until 15 and then 20 are good, or 80 have been
tried. Everything ran on the data-mining machine through a
controller of its own, built from the factory's `main`, while other task jobs used the same Docker daemon.

## Result

**Milestone 2 of the job (2026-11-12 17:31): 10 good cases of 29 pull requests tried.** A case is good when the gate
checked it and it passes both scans. The job goes on, newest merged first, to 20 good cases or 80 tried (the owner,
2026-11-12: "Yes, 15 each", then "I would do 20 each because there could be more issues / unsolved"); this page is
brought up to date at each milestone.

- **The project runs in the engine.** Its own suite passes whole at the newest candidate's starting commit: 5,431
  passed, 0 failed, in 325.8 s. Beyond the factory's defaults it needs a Postgres image with the `vector` extension
  (`pgvector/pgvector:pg17`, the image the project's CI uses), `psql` and ImageMagick in the image, `libsctp1` so that
  Erlang prints no warning into a dependency's build, and, since 16:04, an empty database at the start of every test
  run, which the project's test alias fills from the dump in the code under test, as its CI does (section 1).
- **Good (10): 5425, 5427, 5422, 5423, 5414, 5407, 5401, 5382, 5395 and 5393** (merged 2026-10-22 to 2026-11-12).
  Seven are features, three bug fixes. All pass the licence scan (MIT, every touched file); eight pass the hold-out
  check outright and two (5422, 5382) after their shared phrases were read: standard test assertions, and a common
  Elixir idiom.
- **Checked but not counted (2): 5405 and 5394.** Each passes every check of the gate and the hold-out check, and fails
  the licence scan on one file only: `priv/repo/structure.sql`, the project's own generated schema dump (369,778 and
  369,852 bytes at 5394's two commits, 373,423 and 373,821 at 5405's; [`licence_large.tsv`](licence_large.tsv)), which the scan sets aside
  as too large (over 262,144 bytes) without any other finding. Whether such a file may pass on a person's reading is a
  new licence rule, put to the owner; until then they do not count.
- **Left out (17), all for the pull request's own reason:** 10 have no existing test left to protect (6 refused by the
  maker, 4 at the probe because their one nearby test file is the file they rewrite), 6 are features whose hidden tests
  cannot run before the change (`no_starting_failure`), and 1 has an unstable test of its own (5409: a test that waits
  on a background task passed once and failed once on the merged code). None was the machine's. The factory's side
  caused 5405's first two tries (its migration was never applied; fixed, section 1).
- **Time per checked case** (the engine's own count, in [`cases.tsv`](cases.tsv)): 525.9, 894.1, 626.5, 528.0, 674.0,
  626.0, 574.9, 499.2, 1,432.1, 707.9, 600.2 and 545.7 s for 5425, 5427, 5422, 5423, 5414, 5407, 5405, 5401, 5382,
  5395, 5394 and 5393. 5382 ran while the machine's 1-minute load reached 13.06. The maker's step per pull request is the column `make_s`.
- **Disk per checked case:** a project image of about 1.45 GB and a database snapshot of about 0.69 GB by Docker's sizes,
  which overlap; the layers only that case uses are about 475 MB and 66 MB (Docker's rounded unique sizes in
  [`own_images.tsv`](own_images.tsv)). The first case also built the shared layers once: the toolchain image
  (974,739,987 bytes) and the database layout on the pgvector image (627,219,456 bytes).



## 1. The project's set-up

The recipe is [`factory/recipes/santiment__sanbase2.json`](../../../factory/recipes/santiment__sanbase2.json). It is
a template (it has a `toolchain` block): the maker resolves each starting commit's Elixir and OTP itself. For every
candidate this job tried the resolver read Elixir 1.20.2 and OTP 29.0.4 from the project's `Dockerfile`
(`ARG ELIXIR_VERSION`, `ARG OTP_VERSION`) and took the image table's line for that pair. The project runs its CI on
Jenkins (`Jenkinsfile`, with `Dockerfile-test`); the resolver reads no Jenkins file, so the database comes from the
recipe's default.

| Field | Value | Why |
|---|---|---|
| `runtime.image` (default) | `hexpm/elixir:1.20.2-erlang-29.0.4-ubuntu-noble-20260730.1`, pinned by digest | the image table's line for the pair the project's `Dockerfile` names |
| `runtime.packages` | `postgresql-client`, `imagemagick`, `libsctp1` | the test database is loaded from the project's SQL dump (`priv/repo/structure.sql`) with `psql`, and `Dockerfile-test` installs ImageMagick too; `libsctp1` keeps Erlang from printing a warning into the build of the dependency `crc32cer` (section 2) |
| `services.postgres` | `pgvector/pgvector:pg17`, pinned by its index digest `sha256:7d0a41464797aeb9862dfdc0bbf1526b82cfd324cdd8036df19e3545f4a9ccb8` (PostgreSQL 17.11 on Debian 12); 627,202,175 bytes on disk (Docker's image size) | the SQL dump runs `CREATE EXTENSION vector`, which the factory's `postgres:*-alpine` images lack; the `Jenkinsfile` runs the tests on `pgvector/pgvector:pg17`. Used for this project only, with nothing installed into it |
| `baseline` | `mix ecto.create --quiet`: an empty database (since 2026-11-12 16:04) | the project's `test` alias then creates the database if needed, loads `priv/repo/structure.sql` into it when it is empty (`ecto.load --skip-if-loaded`), fills the metric registry (`mix run test/test_seeds.exs`) and runs `mix test`, every run: as in the project's CI, which starts each run on a fresh Postgres. So the dump of the code under test is loaded, a pull request's (or a model's) included. About 10 s more per test command (12,558 ms for one test file on a fresh database). Cases made before 16:04 carry the earlier baseline, `mix ecto.create --quiet` and `mix ecto.load --skip-if-loaded --quiet` (the dump loaded once, at the starting commit), with which a pull request's migration was never applied (5405's first try); none of their checked cases adds a migration |
| `runtime.before_test_commands` | none | from 15:50 to 16:04 the recipe held a step that applies pending migrations (`Ecto.Migrator` through `mix run --no-start`); the engine runs this list when the container starts, before a patch is applied, so it could not apply a migration the patch adds (5405's second try), and it was taken out. Cases made in those minutes (5405's second try, 5402, 5401) carry it; on the loaded database it is a no-op |
| `permitted_exclusion_tags` | `skip_suite` | `test/test_helper.exs` excludes `skip_suite: true` |
| `test_timeout` | 240 (the default) | a test command of a few files took well under a minute, the alias's set-up included |
| `grading.preservation` (the whole-suite command) | `mix test` | |

What the tests do not need: ClickHouse is switched off in `config/test.exs` (`clickhouse_repo_enabled?: false`), so
the `ch` and `ecto_ch` clients connect to nothing; Kafka (`brod`) is not started in tests (`included_applications`,
and `Sanbase.InMemoryKafka.Producer` in `config/test.exs`); no Redis client is a dependency. So no service besides
PostgreSQL is started.

### What the project's own build fetches

Besides its Hex packages, the build fetches what the project's `mix.lock` and its packages pin:

| Dependency | From | Pinned by | Licence at the pinned commit |
|---|---|---|---|
| `absinthe` | `github.com/santiment/absinthe` (a fork of Absinthe), branch `memory-footprint-improvements` | `mix.lock`: commit `9de55dd55ea5e46668ab66b951f2219c5742cb77` | MIT (`LICENSE.md`, "Copyright (c) Bruce Williams, Ben Wilson"; `mix.exs` says MIT) |
| `absinthe_phoenix` | `github.com/IvanIvanoff/absinthe_phoenix` (a fork), branch `support-new-absinthe` | `mix.lock`: commit `c96140e821c73d554e2dd4311c7f96072fd7d0b9` | MIT (`LICENSE.md`; `mix.exs` says MIT) |
| `crc32cer` | `github.com/zmstone/crc32cer`, with its Git submodules (Google's CRC32C library and, under it, its benchmark, glog and googletest sources) | `mix.lock`: commit `3f6d73c46442c7d613655dd101b1761a75a61e2c`; the submodules by the commits that commit records | Apache-2.0 (`LICENSE`); the bundled CRC32C library carries a BSD-style licence ("Copyright 2017, The CRC32C Authors") |
| `faker` | `github.com/santiment/faker` (a fork), branch `fix-latest-elixir-compile-errors`; test and dev only | `mix.lock`: commit `35b158120552025b9a08fbf0a68c24230391a4d8` | MIT (`LICENSE`, "Copyright (c) 2015 Igor Kapkov"; `mix.exs` says MIT) |
| `langfuse_sdk` | `github.com/workera-ai/langfuse_sdk` | `mix.lock`: commit `1fbf2a84ec8b8e050b02b988b708247fd8471cbd` | MIT (`LICENSE`, "Copyright (c) 2025 Workera") |
| `ex_keccak` 0.7.8 (Hex) | its prebuilt native file `libexkeccak-v0.7.8-nif-2.16-x86_64-unknown-linux-gnu.so`, from the package's GitHub release (`rustler_precompiled`) | the package's `checksum-Elixir.ExKeccak.exs` (22 SHA-256 lines); the package itself by `mix.lock` | the package's own (Hex metadata) |
| `htmd` 0.2.0 (Hex) | its prebuilt native file `libhtmd_nif-v0.2.0-nif-2.17-x86_64-unknown-linux-gnu.so`, from the package's GitHub release (`rustler_precompiled`) | the package's `checksum-Elixir.Htmd.Native.exs` (18 SHA-256 lines) | the package's own |
| `lazy_html` 0.1.12 (Hex; test only) | its prebuilt native file for this NIF version and platform, from the package's GitHub release (`cc_precompiler`) | the package's `checksum.exs` | the package's own |

`absinthe` and `absinthe_phoenix` are forks of the Absinthe project, one of the bench's held-out projects. The rules
allow a held-out library as a dependency; a session that reads or prints these packages' files is dropped as
`quotes_held_out` (rules page, section 6).

## 2. The project's own tests

At the starting commit of pull request 5425 (`4995066c`, the newest candidate), a hand-made probe task
([`run/make_probe.sh`](run/make_probe.sh)) was prepared through the controller and the whole suite ran once through
the engine's own runner, in a fresh workspace container and a fresh copy of the database, with no network
([`run/suite.sh`](run/suite.sh)).

- **The first preparation failed** after 126.7 s, in the build of the dependency `crc32cer`: its CMake file asks
  `erl -noshell -eval` for Erlang's root folder and keeps what the command prints. In the `hexpm/elixir` Ubuntu image
  of OTP 29.0.4, Erlang also prints a warning on standard output that it cannot open `libsctp.so.1`, so the path
  CMake writes into `flags.make` holds two extra lines, and `make` stops with "missing separator". The recipe now
  installs `libsctp1` (one distribution package); the warning is gone and the dependency builds.
- **The second preparation** took 252.4 s (the workspace image built cold, the database image pulled, the database
  loaded from the SQL dump and captured).
- **The suite: all of it passes.** ExUnit's own summary: **5,431 passed (131 doctests, 2 properties, 5,298 tests), 0
  failed, 0 excluded, in 325.8 s** (61.9 s async, 263.8 s sync); the engine's run took 328.5 s and recorded 5,431
  rows for 5,431 distinct names, every one passed. Its output was 1,035,131 bytes, under the engine's 2 MiB limit.
  Before the tests the project's `test` alias filled the metric registry (804 metrics). Table:
  [`project_tests.tsv`](project_tests.tsv); no test failed, so there is no table of failures.

## 3. The cases

The list ([`list.tsv`](list.tsv), made by [`run/list.sh`](run/list.sh) from the screening's class table of the 16
projects): sanbase2's 150 screened candidates, newest merged first. None is on an Elixir older than 1.18 (all 150 read
1.20.2 or 1.19.4); the 42 oldest also need Rust (`needs:toolchain:rust`) and are left out; the first 80 of the other
108 are the job's list. The driver ([`run/all.sh`](run/all.sh)) takes them one at a time through
[`run/one.sh`](run/one.sh): the bundle maker, the import, `factoryctl check --concurrency 1`, the export of a checked
task, then the licence scan and the hold-out check ([`run/scans.sh`](run/scans.sh), the factory's `tools/` unchanged).

[`cases.tsv`](cases.tsv) has one line per try: the merge date, the resolved Elixir/OTP, the kind, the verdict, the step
and reason of a drop, the wall time of each step, the engine's own step times, the 1-minute load at the start and the
end and its highest value during the check, the bytes of this job's own images the try added, the two scans and whose
cause a drop is ([`causes.tsv`](causes.tsv) holds the reading). Every check but one stayed under a 1-minute load of 12 on the machine's 28 threads; 5382's reached 13.06 (it passed
all the same).

| Pull request | Merged | Kind | Verdict | Step, reason | Hidden tests failing first / passing after | Licence | Hold-out |
|---|---|---|---|---|---|---|---|
| 5425 | 2026-11-12 | feature | checked | - | 16 / 65 | pass | pass |
| 5427 | 2026-11-12 | feature | checked | - | 40 / 115 | pass | pass |
| 5422 | 2026-11-10 | feature | checked | - | 5 / 37 | pass | review |
| 5423 | 2026-11-09 | feature | checked | - | 6 / 25 | pass | pass |
| 5421 | 2026-11-09 | bug_fix | dropped | probe, no_existing_tests | - | - | - |
| 5420 | 2026-11-09 | bug_fix | dropped | probe, no_existing_tests | - | - | - |
| 5419 | 2026-11-05 | feature | dropped | probe, start_run_did_not_finish | - | - | - |
| 5406 | 2026-11-05 | - | refused | maker, no_existing_tests | - | - | - |
| 5403 | 2026-11-04 | feature | dropped | probe, no_existing_tests | - | - | - |
| 5416 | 2026-11-03 | - | refused | maker, no_existing_tests | - | - | - |
| 5414 | 2026-11-03 | bug_fix | checked | - | 20 / 32 | pass | pass |
| 5411 | 2026-11-03 | - | refused | maker, no_existing_tests | - | - | - |
| 5412 | 2026-11-03 | - | refused | maker, no_existing_tests | - | - | - |
| 5409 | 2026-11-02 | feature | dropped | controls, reference_existing_tests_fail | - | - | - |
| 5410 | 2026-11-02 | feature | dropped | probe, start_run_did_not_finish | - | - | - |
| 5408 | 2026-11-02 | feature | dropped | probe, no_existing_tests | - | - | - |
| 5407 | 2026-10-30 | feature | checked | - | 16 / 53 | pass | pass |
| 5405 (try 1) | 2026-10-28 | feature | dropped | probe, reference_fails_hidden (the recipe's cause: its migration was not applied) | - | - | - |
| 5405 (try 2) | 2026-10-28 | feature | dropped | probe, reference_fails_hidden (the same; the migration step ran before the patch) | - | - | - |
| 5405 (try 3) | 2026-10-28 | feature | checked, not counted | - | 18 / 20 | fail (size limit only) | pass |
| 5198 | 2026-10-28 | feature | dropped | probe, start_run_did_not_finish | - | - | - |
| 5402 | 2026-10-28 | - | refused | maker, no_existing_tests | - | - | - |
| 5401 | 2026-10-28 | bug_fix | checked | - | 1 / 26 | pass | pass |
| 5399 | 2026-10-27 | feature | dropped | probe, start_run_did_not_finish | - | - | - |
| 5382 | 2026-10-27 | feature | checked | - | 59 / 438 | pass | review |
| 5397 | 2026-10-26 | feature | dropped | probe, start_run_did_not_finish | - | - | - |
| 5396 | 2026-10-23 | feature | dropped | probe, start_run_did_not_finish | - | - | - |
| 5395 | 2026-10-22 | feature | checked | - | 41 / 97 | pass | pass |
| 5391 | 2026-10-22 | - | refused | maker, no_existing_tests | - | - | - |
| 5394 | 2026-10-22 | feature | checked, not counted | - | 4 / 81 | fail (size limit only) | pass |
| 5393 | 2026-10-22 | bug_fix | checked | - | 1 / 45 | pass | pass |

Counts by the last try ([`counts.tsv`](counts.tsv)): 12 checked (10 good, 2 not counted); 6 refused by the maker and 4 dropped at the probe, all `no_existing_tests`; 6 dropped at the probe because the hidden tests do not finish on the unchanged project (`start_run_did_not_finish`, the rules' `no_starting_failure`); 1 dropped at the controls (`reference_existing_tests_fail`, an unstable test); 51 not reached yet.

**The balance of kinds** (rules page, section 7): the driver prefers the short kind once 12 cases are good and one
kind has fewer than 4 (until the target was raised to 20: 10 and 3); a candidate of the other kind is then made but deferred, not counted as tried, and run at the
end if the target is not reached.

**The code the cases ran on:** 5425, 5427, 5422, 5423 and 5421 ran on a controller built from the factory's `main` at
`772f3bd`; from 5420 on, on one built from `0d99a67`, which keeps each installation's service images under a tag of
its own (another job's controller had been able to remove them). No case of this job was hit by that fault: this
project's database layout is built on the pgvector image, which no other job uses.

**The scans** ([`scans.tsv`](scans.tsv), [`good.tsv`](good.tsv), [`holdout_reviews.tsv`](holdout_reviews.tsv),
[`deps.tsv`](deps.tsv)): the licence file is `LICENSE.md` (MIT) at every starting commit, and every file a case touches
passes, except the schema dump of 5405 and 5394, set aside as too large ([`licence_large.tsv`](licence_large.tsv)). The hold-out check found no held-out name and no shared 12-word run; the shared 8-word runs are common to
several held-out projects, syntax, or already in sanbase2, except two in 5422 and six in 5382 (span ids in
[`holdout_reviews.tsv`](holdout_reviews.tsv)), read as boilerplate: two standard test assertions, and the common idiom
that counts a process's messages (`after 0 -> count`). The scans read a full clone of the project: a
partial clone fetched every file of a commit one request at a time.

**Dependencies, for the later scan of sessions** ([`deps.tsv`](deps.tsv)): of the 177 locked packages, 4 Hex packages
declare a licence outside the list: `anubis_mcp` 1.10.0 (LGPL-3.0), `cidr` 1.2.0 (MPL-2.0), `ex_abi` 0.8.3
(GPL-3.0) and `poolboy` 1.5.2 (Unlicense or Apache 2.0). A session that reads or prints their files is dropped as
`quotes_dependency_outside_licence_list`; the cases themselves are the application's own code. The five GitHub
dependencies are read by hand in section 1 (the tool marks them "licence not read").


## 4. Files

| File | What it holds |
|---|---|
| [`cases.tsv`](cases.tsv) | one line per try (above); the pull requests not reached have one line "not run" |
| [`counts.tsv`](counts.tsv) | the pull requests by their last try's verdict, step and reason |
| [`causes.tsv`](causes.tsv) | the drops read by a person: whose cause, and why |
| [`good.tsv`](good.tsv) | every checked case with its licence and hold-out results, its kind, and whether it counts |
| [`scans.tsv`](scans.tsv) | the two scans per checked case: licence file, family, files touched and passing; the hold-out's checks and span counts |
| [`holdout_reviews.tsv`](holdout_reviews.tsv) | the hold-out hits read by a person (span ids, never their text) |
| [`licence_large.tsv`](licence_large.tsv) | the checked cases whose licence result fails only on files the scan set aside as too large: the file, its bytes at both commits, the number of other failing files |
| [`deps.tsv`](deps.tsv) | the locked packages of the checked cases, their declared licences and class, and how many cases lock them |
| [`own_images.tsv`](own_images.tsv) | every image of this job: id, tags, Docker's size and its unique size |
| [`list.tsv`](list.tsv) | the 150 screened candidates and each one's status in this job |
| [`project_tests.tsv`](project_tests.tsv) | the project's own suite: the engine's verdict, ExUnit's summary, the output's size |
| [`run/`](run/) | the scripts that ran: `controller.sh`, `build.sh`, `state.sh`, `watch.sh`; the suite (`suite.sh`, `env_tests.sh`, `make_probe.sh`, `prepare.exs`, `tests.exs`, `suite_tables.sh`); the cases (`list.sh`, `resolve.exs`, `all.sh`, `one.sh`, `make_one.exs`, `row.sh`, `scans.sh`); the tables (`table.sh`, `collect.sh`) |


## 5. Exact commands

On the data-mining machine, as root, with `WORK` the factory's work folder, `JOB=$WORK/jobs/hb-sanbase2` (this
folder's `run/`, the factory's folder as `src/` at the commit named above, `tables/` with the screening's census,
screen and class tables of the project), `CTL=$WORK/ctl-hb-sanbase2`:

```sh
# the controller, apart from the other jobs' and the bench's
SRC=$JOB/src OUT=$JOB/logs IMAGE=elixir-task-factory:sanbase2-20261112 LABEL=task-factory=1 $JOB/run/build.sh controller
CTL=$CTL SOURCES=$JOB IMAGE=elixir-task-factory:sanbase2-20261112 NAME=factory-sanbase2 \
  LABELS=task-factory=1,task-factory-job=hb-sanbase2 HEX_CACHE_ID=etf-hex-packages-v1 EPMD_PORT=4515 \
  PREPARE_WORKERS=1 PREPARE_AHEAD=1 $JOB/run/controller.sh up
# the list and the stage
CLASSES=$JOB/tables/classes_sanbase2.tsv OUT=$JOB/tables N=80 $JOB/run/list.sh && cp $JOB/tables/numbers.txt $JOB/
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-sanbase2 $JOB/run/all.sh stage
# the project's own suite, once, at pull request 5425's starting commit
JOB=$JOB OUT=$JOB/suite CTL=$CTL NAME=factory-sanbase2 JOB_LABEL=task-factory-job=hb-sanbase2 TASK_LABEL=task-factory=1 \
  MAX_LOAD=26 DATA=$CTL/data GIT_DIR=$JOB/sanbase2.git NUMBER=5425 MERGE=606912884a49ac238537b5dc606fafe0fa29eb7a \
  IMAGE=<the image table's line for 1.20.2/29.0.4> ROUNDS=1 SUB=env TEST_TIMEOUT=5400 $JOB/run/suite.sh
D=$CTL/data/env OUT=$JOB/suite_tables ROUNDS=1 $JOB/run/suite_tables.sh
# the cases (a temporary copy of the bench's cases for the hold-out check first; deleted at the end)
BENCH_SRC=<the bench's cases folder> BENCH=$JOB/bench_cases OUT=$JOB/scans $JOB/run/scans.sh cases
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-sanbase2 JOB_LABEL=task-factory-job=hb-sanbase2 TASK_LABEL=task-factory=1 \
  TARGET=20 MAX_TRIES=80 KIND_AFTER=12 KIND_MIN=4 MAX_LOAD=26 MIN_FREE=50000000000 $JOB/run/all.sh run
# a try again (5405's second and third, after its folders were set aside so that the maker made it again)
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-sanbase2 JOB_LABEL=task-factory-job=hb-sanbase2 TASK_LABEL=task-factory=1 \
  $JOB/run/all.sh retry 5405 3
# the tables
JOB=$JOB WORK=$WORK CTL=$CTL PUB=<this folder> JOB_LABEL=task-factory-job=hb-sanbase2 $JOB/run/collect.sh
```

The watcher stops the job when a bench run starts, when free space on `/` falls under 50,000,000,000 bytes (the
owner, 2026-11-12: "do not stop until you get to last 50GB of free space"), or when the 1-minute load is above 26 in
two readings 300 s apart. `scans.sh` reads `$JOB/sanbase2-full.git`, a full clone of the project.


## 6. Provenance and licence

The project's code is MIT (`LICENSE.md`); the tables hold pull request numbers, commit ids, file names and test
names, never pull request titles, bodies or patch text. The scripts in `run/` are this repository's; most are the
nerves_hub_web job's scripts on the same machine, with that project's names replaced by this one's.
