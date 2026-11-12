# nerves_hub_web with `fwup`: the project's own tests in the engine, and its first 30 candidates made (2026-11-12)

Registry row [E68](../../../experiments.md) (the pilot of the task factory). Job P3 for `nerves-hub/nerves_hub_web`
([2026-11-12_pilot_env_nerves_hub_web](../2026-11-12_pilot_env_nerves_hub_web/README.md)) prepared the project but
no test could run: the application refuses to start without the program `fwup`, which its CI installs from a `.deb`
on `fwup`'s release page. Since then the engine installs distribution packages and release files per task
([factory job T8](../2026-11-12_factory_t8/README.md)), and the bundle maker resolves each commit's toolchain itself
([E72](../2026-11-12_maker_toolchain/README.md)). This job put `fwup` 1.17.1, `xdelta3` and `mtools` into the
project's template, ran the project's own suite twice through the engine, and made 30 candidates of the template's
period. Everything ran on the CPU of the 7-GPU machine on 2026-11-12 between 07:58 and 09:02 (UTC+1), through a
controller of its own built from the factory's `main`, while two other task-making jobs used the same Docker daemon
and a 258 GB model file was being copied onto the same disk.

**The counts below were measured on a loaded machine and are not settled:** they are to be run again on a machine
that does nothing else. What does not depend on the load: the release file and its checksum, the 13 tests that call
`zip` (the program is not in the image), the module that runs twice under ExUnit's `parameterize:`, and the 29 made
task folders. At 09:02 the owner moved all task work off this machine, and the job's checks were stopped before any
had finished.

## Result

- **The project's tests run.** At the starting commit of pull request 3155, prepared cold in 330.3 s, the whole
  suite ran twice. ExUnit's own summary: **run 1: 4,033 of 4,046 passed, 13 failed, 4 excluded, in 282.7 s; run 2:
  4,025 passed, 21 failed, 4 excluded, in 764.6 s** (not settled: both under load). The 13 failures of run 1 fail
  in run 2 too, and all 13 call the program `zip`, which the image lacks (GitHub's runner image has it; the CI does
  not install it). The 8 extra failures of run 2 are database errors (cancelled queries, closed connections) while
  the machine's load average was 12 to 15 and its system disk was saturated by the model copy. The 4 excluded tests
  are the ESP-IDF delta tests that need `detools`.
- **The engine's per-test record calls both runs unfinished,** because one module, `NervesHubWeb.WebsocketTest`,
  runs twice under ExUnit's `parameterize:` (a JSON and a msgpack serializer) with the same test names: the
  reporter printed 4,050 rows for 4,013 distinct names, 37 names twice. The 2 MiB limit on a test command's output is
  no longer reached: 730,465 and 770,106 bytes.
- **The first tasks: 29 of 30 made, none checked.** The maker made 29 task folders from the 30 newest candidates of
  period P02 (pull requests 3155 back to 3082) and refused 1 (3118, `no_existing_tests`). All 29 resolved to the same
  environment, passed the source check and the import check, and were imported. **No check finished:** the checks
  started at 08:47, two at once; at 09:02, when the owner moved task work off the machine, 3155 and 3159 were still
  building their workspace images and the other 27 had not started. 29 of the 30 carry the screen's AI-tool mark.

## 1. The release file and the packages

| What | Value |
|---|---|
| Program and version | `fwup` 1.17.1, the `amd64` `.deb` |
| Where it is named | `.github/workflows/ci.yml` at `b3b161e9` (the starting commit of pull request 3155): `FWUP_VERSION: "1.17.1"`, then `wget https://github.com/fwup-home/fwup/releases/download/v${FWUP_VERSION}/fwup_${FWUP_VERSION}_amd64.deb` and `sudo dpkg -i` |
| URL | `https://github.com/fwup-home/fwup/releases/download/v1.17.1/fwup_1.17.1_amd64.deb` |
| Size | 366,032 bytes |
| SHA-256 | `b73ca78effe61e4c8cedcff567ca137b6bdaa1772b84f9e4d88913f192c09bf2` |
| How the checksum was got | from the release's own published checksums: `SHA256SUMS`, an asset of the `v1.17.1` release (published 2026-09-15), its line for `fwup_1.17.1_amd64.deb`. GitHub's own digest for the asset is the same. It was not computed from the download; the engine checked the download against it, and the kept file gives the same SHA-256 |
| Hosts the fetch needs | `github.com`, and `release-assets.githubusercontent.com`, the host GitHub's `302` points to (seen with a `HEAD` request that follows no redirect). Only this job's controller allows them (`EAB_RELEASE_FILE_HOSTS`, [`run/controller.sh`](run/controller.sh)) |
| Fetched | once, 2026-11-12 07:00:56 UTC, by the engine at the image build; nothing else was downloaded from a release page |

The template ([`factory/recipes/nerves-hub__nerves_hub_web.json`](../../../factory/recipes/nerves-hub__nerves_hub_web.json))
now holds, beside job P3's fields:
- `runtime.release_files`: the file above, kind `deb`. The engine installs it with `apt-get`, which takes `fwup`'s
  dependencies from Ubuntu; that image layer is 1.57 MB.
- `runtime.packages`: `xdelta3` and `mtools`, the two packages CI installs with `apt-get` for the tests; a 1.25 MB
  layer.
- `grading.preservation` (the project's whole-suite command, used only for this check): `mix test --exclude
  describe:create_firmware_delta_file/3`. The four tests that need `detools` (a Python package CI installs with
  `pipx`, not installed here) carry no tag of their own: they are the `describe "create_firmware_delta_file/3"`
  block of `test/nerves_hub/firmwares/update_tool/esp_idf_test.exs`, whose set-up raises without `detools`. ExUnit
  tags every test with its `describe`, and that name is unique in the suite, so the command leaves out exactly
  those four. They are counted as excluded in both runs.
- `permitted_exclusion_tags`: `["pending"]`. The `mtools` tests are no longer excluded, since `mtools` is installed.
- a `toolchain` block, so the maker resolves each commit's image and services: `.tool-versions` names Elixir 1.20.3
  and OTP 29.0.5, and `ci.yml` starts `postgres:18` and `clickhouse/clickhouse-server:25.4.2.31`.

Within period P02, 102 candidates' CI installs `fwup` 1.16.0 and 25 install 1.17.1. The template pins 1.17.1 for
all of them; of the 30 below, 25 install 1.17.1 in their own CI and 5 (3111, 3101, 3100, 3097, 3082) install 1.16.0.

## 2. The project's own tests

A hand-made probe task for pull request 3155 ([`run/make_probe.sh`](run/make_probe.sh), as in job P3, with its own
id `nerves-hub-web-probe-pr-3155` and a 900-second limit for one test command) was prepared through the controller
(`run/prepare.exs`): the toolchain image with the release file and the packages, the workspace image, and the
Postgres and ClickHouse databases, **cold in 330.3 s** (the engine's own step 326.6 s). The suite then ran twice
through the engine's own runner (`run/tests.exs`: `Eab.Grader.run_tests/3` with the engine's reporter), each run in a
fresh workspace container with fresh databases. Every engine container seen meanwhile carried the label
`pascal-quants=1` and a CPU share of 256; the Postgres containers had no network, and the others joined only their
Postgres container's network.

`project_tests.tsv`:

| Run | ExUnit tests | Passed | Failed | Excluded | ExUnit time | Engine time | Return code | Output | Engine: finished |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 4,046 (5 doctests) | 4,033 | 13 | 4 | 282.7 s | 284.9 s | 2 | 730,465 bytes | no (37 names twice) |
| 2 | 4,046 (5 doctests) | 4,025 | 21 | 4 | 764.6 s | 780.2 s | 2 | 770,106 bytes | no (37 names twice) |

**Each failure** (`project_test_failures.tsv`, with the file, line and first error line of each):
- **13 in both runs: `zip` is missing.** 10 tests of `test/nerves_hub/firmwares/update_tool_test.exs` ("firmware
  archive and delta updates", among them 3 of the 4 tests tagged `mtools`) and 3 of
  `test/nerves_hub/workers/firmware_delta_builder_test.exs`. `NervesHub.Firmwares.UpdateTool.Fwup` builds a delta
  archive with `System.cmd("zip", ...)`, which raises `:enoent`. GitHub's runner image has `zip`, so the project's CI
  never installs it; the `hexpm/elixir` image does not have it. Adding `zip` to `runtime.packages` would be one more
  distribution package; this job did not add it.
- **8 only in run 2: the database under load.** Two `ERROR 57014 (query_canceled)`, two `ERROR XX000 ... could not
  open file "base/...": Interrupted system call`, four `DBConnection.ConnectionError ... tcp recv: closed`, in eight
  test files (accounts, audit logs, five LiveView pages, the websocket test). Run 2 took 2.7 times as long as run 1
  while two other jobs built images and ran their own checks on the same machine (load average 12 to 15).
- Every other test ended the same in both runs.

**The engine's record calls both runs unfinished.** `Eab.Grader.parse/2` names a test by module and name; a run is
finished only when every printed row has a distinct name. `test/nerves_hub_web/channels/websocket_test.exs` uses
`use NervesHubWeb.ChannelCase, parameterize: [%{serializer: :json}, %{serializer: :msgpack}]`, so ExUnit runs each of
its 37 tests twice under one name. The reporter and `parse/2` are among the files that must stay as the bench has
them (`factory/README.md`, section 2.2), so this is not changed here. For tasks it means: a task whose test command
names `websocket_test.exs` cannot have a finished run, so the probe leaves that file out of the existing tests, and a
pull request whose hidden tests are in it is dropped.

**The 2 MiB output limit.** Job P3's diagnostic runs, with a stand-in `fwup` and 1,635 failures, went over the
engine's 2 MiB limit for one test command, and the engine kept only part of the output. With the real `fwup` the
output is 730,465 and 770,106 bytes, so the limit is not reached and costs nothing; the whole output is kept.

**After run 2** the engine's removal of the run's containers took longer than its 30-second limit for one `docker
rm` under the load, and the script ended with an error after both runs were written. Its two remaining containers
were removed by hand.

## 3. The first 30 candidates

The 30 newest candidates of period P02 by merge time (`tasks_nerves_hub_web.tsv`, one line per pull request in the
mass run's columns of [2026-11-12_pilot_tasks_all](../2026-11-12_pilot_tasks_all/README.md), plus `probe_gate_s`,
`clickhouse`, `ai_tool` and the check's `job`): pull requests 3155, 3159, 3156, 3153, 3124, 3148, 3149, 3140, 3139,
3142, 3138, 3123, 3122, 3120, 3119, 3117, 3146, 3145, 3135, 3133, 3118, 3113, 3108, 3115, 3114, 3111, 3100, 3097,
3101 and 3082, merged 2026-10-19 back to 2026-10-01.

**Made** with the maker and the toolchain resolver through the controller (`run/make.exs`, the mass run's script,
unchanged), then imported with the factory's own entry point (`factoryctl import`). The checks were to run through
`factoryctl check`, one task per check job and two jobs at once (`run/check_pool.sh`), with the free space read
before each start.

| Step | Result | Count | Whose |
|---|---|---:|---|
| the maker | refused: `no_existing_tests` (no existing test file is changed or matches a changed code file) | 1 (3118) | the pull request |
| the maker | made; the toolchain resolved to Elixir 1.20.3 / OTP 29.0.5 from `.tool-versions`, Postgres 18.6 and ClickHouse 25.4.2.31 from `ci.yml` | 29 | |
| source check and import check | passed | 29 | |
| `factoryctl import` | imported | 29 | |
| `factoryctl check` | **stopped** while building the workspace image (3155, 3159), **not started** (the other 27) | 29 | the run was stopped (below) |

**Drops by whose they are:** ours 0, the project's 0, the pull request's 1 (3118); 29 with no verdict.

**Why none was checked.** The checks first waited on a disk floor: free space on the system disk fell from
602,128,957,440 bytes when the job started (07:58) to 519,051,497,472 at 08:37, under the job's first floor of
572,835,543,040 bytes. This job's own files and images are about 1 GB of that (est., section 4); the rest was the
other jobs' images and build cache and the model copy. With the larger allowance the owner had set at 08:22, the
checks started at 08:47, two at once. At 09:02 the owner moved all task work off this machine and the run was
stopped: 3155 and 3159 were still building their workspace images (seeded from the probe's build, 13 minutes in,
under a disk saturated by the model copy), and the other 27 had not started. The 29 imported task folders are kept;
checking them is a new job on another machine.

**The AI-tool mark** of the screening (`ai_tool`): 29 of the 30 carry it, every one but 3124. It is a column for
reporting, not a reason to drop.

## 4. Time and disk (rough planning figures)

- **Making:** the 29 folders and the refusal in 36 s (about 1.2 s per pull request, the source pairs cached after the
  first), then the source check and the import check of all 29 in about 100 s.
- **Per checked task:** not measured, since no check finished. The cold preparation of one commit with this template
  took 330.3 s, against 259.9 s for job P3's without `fwup` and the packages (not settled: under load).
- **Disk of this job:** the controller's data folder 685,453,312 bytes and the job folder 38,518,784 bytes; new image
  layers about 0.3 GB by `docker history` (the workspace's 240 MB source and build layer, the Postgres snapshot's
  53 MB, the two packages' and the release file's 2.8 MB; the ClickHouse snapshots 2.5 MB; the system-package layer is
  shared with job P3's toolchain image). About 1 GB in all (est.).

## Files

| File | What it holds |
|---|---|
| `release_file.tsv` | the release file: version, URL, size, SHA-256, where the checksum came from, GitHub's digest, the CI lines, the redirect host, when it was fetched |
| `project_tests.tsv` | the two runs of the project's suite: the engine's verdict, ExUnit's counts and time, the output size, the names printed twice |
| `project_test_failures.tsv` | the 21 tests that failed in either run, their state in each run, their file and line, their first error line |
| `tasks_nerves_hub_web.tsv` | the 30 pull requests, one line each |
| `summary.tsv` | the 30 summed up by step and cause |
| `run/controller.sh` | the controller: build, up, rpc, down; job T10's with `RELEASE_FILE_HOSTS` and `rpc` added |
| `run/make_probe.sh` | the hand-made probe task (job P3's, with an optional `TEST_TIMEOUT`) |
| `run/prepare.exs`, `run/tests.exs` | job P3's, unchanged: prepare one task folder; run a test command `ROUNDS` times |
| `run/env_tests.sh` | the project's own tests: the probe, its preparation, the suite twice |
| `run/watch_labels.sh` | job P3's watcher of the engine's containers, for the `etf-` names the engine uses since job T7 |
| `run/make.exs` | the mass run's maker script, unchanged |
| `run/resolve.exs` | the mass run's resolver script, unchanged (not run: `make.exs` resolves each commit too) |
| `run/tasks.sh` | the first tasks: stage, make, import, check, export |
| `run/check_pool.sh` | `factoryctl check`, one task per job, two jobs at once, with the free-space floor |
| `run/table.sh` | `tasks_nerves_hub_web.tsv` from the maker's files, the pool's records and the check results |
| `run/suite_tables.sh` | `project_tests.tsv` and `project_test_failures.tsv` from the runs' files |

## Commands

On the machine with Docker, in a job folder `$JOB` holding `run/` (this folder's scripts), `src/` (the factory folder
with the template), `numbers.txt`, a full clone of the project (`GIT_DIR`) and `tables/` (the census, unpacked, and
the screen of [2026-11-12_pilot_pr_screen](../2026-11-12_pilot_pr_screen/README.md)); `$DATA`, `$TASKS` and
`$MIRROR` are new folders:

```sh
export JOB DATA TASKS MIRROR GIT_DIR NAME=factory-nhw-fwup EPMD_PORT=4591 IMAGE=elixir-task-factory:nhw-fwup
export RELEASE_FILE_HOSTS="github.com release-assets.githubusercontent.com"
SRC=<the factory folder of main> $JOB/run/controller.sh build
$JOB/run/controller.sh up
$JOB/run/env_tests.sh probe && $JOB/run/env_tests.sh prepare && $JOB/run/env_tests.sh tests
D=$DATA/env OUT=<tables> $JOB/run/suite_tables.sh
$JOB/run/tasks.sh stage && $JOB/run/tasks.sh make && $JOB/run/tasks.sh import
MIN_FREE=<floor in bytes> $JOB/run/tasks.sh check
KEEP=<checked tasks> OUT=<tar folder> $JOB/run/tasks.sh export
D=$DATA/nhw SCREEN=$JOB/tables/screen_nerves-hub__nerves_hub_web.tsv $JOB/run/table.sh > tasks_nerves_hub_web.tsv
LOG=<log file> $JOB/run/controller.sh down
```

This job ran `env_tests.sh` and the `stage`, `make` and `import` steps, and started `check` (`MIN_FREE` 134,454,282,076
bytes), which was stopped at 09:02 with no result (section 3); `export` did not run. The 29 lines of
`tasks_nerves_hub_web.tsv` were written by `table.sh` from a pool record written by hand: `stopped` / `prepare` for
the two checks that had started (with their job ids), `not_tried` / `run_stopped` for the other 27.
`numbers.txt` is the 30 numbers of period P02 in [job P3's `periods.tsv`](../2026-11-12_pilot_env_nerves_hub_web/periods.tsv)
sorted by merge time, newest first. The controller's image was built from the factory's `main` at `8b8bb99`.

## Provenance and licence

nerves_hub_web is Apache-2.0 (`LICENSE` at each starting commit, read by the maker). `fwup` is Apache-2.0; its `.deb`
was fetched from the project's own GitHub release and installed into the test image only. The tables hold pull
request numbers, test names, file names and error lines of the project's tests. They hold no source code.
