# nerves_hub_web: the factory's gaps settled, and its newest candidates checked (2026-11-12)

Registry rows [E86](../../../experiments.md) (a hidden test the project skips), [E88](../../../experiments.md)
(nerves_hub_web's two gaps), [E84](../../../experiments.md) (missing Elixir/OTP pairs) and
[E68](../../../experiments.md) (the pilot of the task factory). `nerves-hub/nerves_hub_web` is one of the dataset's 16
applications ([rules](../../dataset_rules.md)). The pilot job
([2026-11-12_pilot_tasks_nerves_hub_web](../2026-11-12_pilot_tasks_nerves_hub_web/README.md)) put `fwup`, `xdelta3` and
`mtools` into the project's template and made 29 candidates, but no check finished, and three gaps stood in the way of
its tasks. This job settled the gaps in the factory, ran the project's whole suite once, and checked candidates one at a
time, newest merged first. Everything ran on the data-mining machine (28 threads, 30 GiB, no GPU) through a controller
of its own, beside one job that uses the model; nothing ran on the model's machine.

## Result

**The run is in progress;** this page is written again at every tenth checked task (times are the data-mining
machine's). At 13:15, 17 pull requests had been tried, newest merged first: **10 checked, 7 dropped**, every verdict
settled (the highest 1-minute load during any check was 5.89 on 28 threads).

- **The gaps are settled** (section 1), and the factory's tests pass: 243 without Docker, 253 with it.
- **The project's whole suite finishes** at the starting commit of the newest candidate, pull request 3261, on Elixir
  1.20.4 with OTP 29.1.2: ExUnit's 4,605 tests (9 doctests) all passed, 4 were excluded (the `detools` tests) and none
  failed, in 237.4 s. The engine's record is complete: 4,609 records, all distinct; the 46 tests of the module that
  runs under `parameterize:` are 92 records (section 2).
- **The 7 drops are all the pull requests' own:** `start_run_did_not_finish` at the probe. Each is a feature that adds
  3 to 16 new modules under `lib/` and new test files that use them, so its hidden tests cannot compile on the
  unchanged project (the rules' "cannot run at all", section 4 of the [rules](../../dataset_rules.md)). Each probe took
  13 to 34 s, far under the engine's 240-second limit for one test command.

## 1. The gaps, and how each was settled

| Gap | What happened before | The change | Tests |
|---|---|---|---|
| **A hidden test the project marks as skipped** (E86) | The probe kept a test tagged `@tag :skip` among the hidden tests. The grader passes no skipped test ([factory README](../../../factory/README.md) 2.2), so the reference control failed, and the task was dropped as `reference_existing_tests_fail` although the existing tests passed. | `Eab.BundleProbe.observe/2` refuses such a task as `skipped_test`, naming the skipped tests, before any control runs; `Eab.Factory.first_failure/2` names a reference that fails only on a skipped test the same way. The task is still lost: keeping it would need the grader to pass a skipped test, which departs from the bench. The cause is the pull request's own (its changed test file holds the skipped test). | `observe/2` on a made-up run; `first_failure/2` on made-up controls (four cases); the probe on a made-up task whose hidden file has a skip-tagged test (Docker) |
| **`zip` is not in the image** (E88) | 13 of the project's tests call `System.cmd("zip", ...)`, which raised `:enoent`: 10 in `update_tool_test.exs`, 3 in `firmware_delta_builder_test.exs`. GitHub's runner image has `zip`; the project's CI never installs it. | `zip` joins `xdelta3` and `mtools` in `runtime.packages` of [the template](../../../factory/recipes/nerves-hub__nerves_hub_web.json). | the whole suite below: no test fails |
| **One module runs twice under `parameterize:`** (E88) | `test/nerves_hub_web/channels/websocket_test.exs` uses `use NervesHubWeb.ChannelCase, parameterize: [%{serializer: :json}, %{serializer: :msgpack}]`, so ExUnit runs each of its tests twice under one name. The reporter wrote one name twice, and `Eab.Grader.parse/2` called every run that held the file unfinished. | The reporter (`priv/fixtures/grade_formatter.exs`) adds a test's parameters to its name when its module runs once per parameter set: `Elixir.M::test a %{serializer: :json}`. Every other test's record is the bench's, byte for byte; `parse/2` is unchanged; the model never sees the file (it is copied into grading containers only). The parity test pins the new blob id (`75eed312`) with the bench's (`ea8dec71`) in a comment. | the reporter on made-up test structs (with and without parameters, and an older struct with no such field); a real ExUnit run of a parameterized module in a temporary project, parsed by `parse/2` |
| **The licence tool's list** | `task_licence.py` did not hold ISC, which the owner added on 2026-11-12. | ISC in `ALLOWED_SPDX`, in the loose spellings (`isc`, `ISC License`) and in the root licence families. | `factory/tools/test_task_licence.py`, 4 tests |
| **The newest candidates' pair** (E84) | The project's 44 newest candidates (merged 2026-10-19 to 2026-11-10) name Elixir 1.20.4 with OTP 29.1.2, which the image table lacked (`no_image:1.20.4/29.1.2`). | One line in `factory/config/toolchain_images.json`, printed by `scripts/toolchain_image.sh elixir 1.20.4 29.1.2`: `hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1`, pinned by digest. | `toolchain_test` reads the table |

**A fourth gap, found during the run: the service images' shared tag.** The engine builds each database's "layout"
image (`FROM postgres…` with the data folder the snapshots capture) under `elixir-task-factory:layout-<key of the
recipe>`, the same tag in every installation. From 13:15 six controllers shared the machine's Docker (five project
sessions beside this job, on the owner's word), each with its own labels, so each built its own image under that one
tag. On this Docker (the containerd image store) an image whose last tag moves to another image is removed at once,
and the engine's cache then named an image that was gone: `docker failed: … content digest sha256:3a7666a0…: not
found`, at the step that starts a new database family. It dropped 3108's first try and 3097 at `prepare`
(`environment`), the factory's cause, and it would drop every task that needs a new database on any controller
there. The change (`Eab.ServiceImages.build/2`): each service image (layouts, checkpoints, sealed ClickHouse
snapshots) is built under a second tag of the installation's own (`elixir-task-factory:<identity>-<installation>`,
`own_tag/1`), which no other controller moves, and its id is read from that tag. A Docker test moves the shared tag
to another image and checks that the layout image stays and the cache still finds it. The run was held after 3101,
the controller was rebuilt (`elixir-task-factory:nhw-20261112-b`; the first container is kept, stopped, as
`factory-nhw-a`), and 3097 was tried again first (`run/all.sh`, `AGAIN`).

**The factory's tests** on the data-mining machine, in the tooling image (`run/test.sh`):

| Run | Before (the set-up job) | After |
|---|---|---|
| without Docker | 240 passed, 0 failed, 10 excluded | 243 passed, 0 failed, 10 excluded (33.7 s) |
| with Docker | 250 passed, 0 failed | 253 passed, 0 failed (378.9 s) |
| format check | passes | passes |
| `factory/tools/test_task_licence.py` | - | 4 of 4 |

The three new tests are the reporter's two and `first_failure/2`'s; the probe's Docker test and `observe/2`'s unit test
gained a case each. The parity test passes. The Docker run was before the image-table line was added; the run without
Docker was repeated after it (243 passed).

## 2. The project's own suite

A hand-made probe task for pull request 3261 (`run/make_probe.sh`, with its own id and a 900-second limit for one
test command) on the image the resolver gives that commit (`hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1`,
from `.tool-versions`), with Postgres 18.6 and ClickHouse 25.4.2.31 from the project's CI file and the template's
packages and release file. It was prepared through the controller in 184.4 s (cold: the new Elixir image, the
workspace, the two databases; `fwup`'s `.deb` was the pilot's kept copy, checked by its SHA-256, so nothing was
fetched from the release page), and the whole suite ran once through the engine's own runner (`run/tests.exs`,
`Eab.Grader.run_tests/3` with the engine's reporter), in a fresh workspace container with fresh databases.

`project_tests.tsv`:

| Command | Return code | Engine: finished | Records (distinct) | ExUnit tests | Passed | Failed | Excluded | ExUnit time | Output |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| `mix test --exclude describe:create_firmware_delta_file/3` | 0 | yes | 4,609 (4,609) | 4,605 (9 doctests) | 4,605 | 0 | 4 | 237.4 s | 803,409 bytes |

- **No test fails.** The 13 tests that needed `zip` pass. `project_test_failures.tsv` is empty.
- **The engine's verdict is "not passed" only because of the 4 excluded tests:** the `describe` block of the
  `detools` tests is left out by the command, and that is not a tag the template permits. No task's test command
  names that file's `describe`.
- **`websocket_test.exs`:** 46 tests, each run with `%{serializer: :json}` and `%{serializer: :msgpack}`, 92 records
  with distinct names. The pilot's run at 3155 had 37 such tests and called the run unfinished.

## 3. The candidates

The order: the 30 candidates the pilot made first (pull requests 3155 back to 3082, merged 2026-10-19 back to
2026-10-01, newest merged first), then every other candidate of the pilot's screening
([2026-11-12_pilot_pr_screen](../2026-11-12_pilot_pr_screen/README.md)) merged since 2025-01-01, newest merged first:
403 pull requests in all (`run/all.sh`, `numbers.txt` on the machine). The run stops starting pull requests when 25
are checked: the dataset takes at most 15 cases of one project into its first 100 (rules, section 7), and 25 leaves
room for drops at the session stage.

Each pull request went through `run/one.sh`, one at a time, before the next started:
1. **Made again** with the bundle maker and the toolchain resolver (`run/make_one.exs` in the controller): the pilot's
   folders were made with the template before `zip`. For the first, 3155, the new folder is the pilot's byte for byte
   but for `runtime.packages`.
2. **Imported** (`factoryctl import`), **checked** (`factoryctl check --concurrency 1`) and, when checked,
   **exported** (`factoryctl export`) to the task folder of the dataset.
3. **Recorded:** the wall time of each step and the engine's own step times, the 1-minute load at the start, at the
   end and its highest value during the check (sampled every 10 s), the free bytes on the disk before and after, the
   images and build-cache bytes added. A verdict is settled when the load stayed under 12 during the check; otherwise
   the pull request is run once more.

The stop rules ran beside it (`run/watch.sh`): free space under 700,000,000,000 bytes, the 1-minute load above 20 in
two readings five minutes apart, or a bench run on the same Docker. None fired.

`tasks_nerves_hub_web.tsv` has one line per try. So far (merged 2026-10-15 to 2026-10-19, all on Elixir 1.20.3 with
OTP 29.0.5, Postgres 18.6 and ClickHouse 25.4.2.31):

| Pull request | Kind | Verdict | Step, reason | Check (s) | Prepare / probe / controls (s) | Highest load |
|---|---|---|---|---:|---|---:|
| 3155 | bug fix | checked | - | 421 | 186.3 / 79.4 / 148.9 | 2.42 |
| 3159 | feature | checked | - | 470 | 142.7 / 143.6 / 178.1 | 2.13 |
| 3156 | bug fix | checked | - | 321 | 142.6 / 69.4 / 105.5 | 2.10 |
| 3153 | feature | checked | - | 761 | 140.6 / 198.1 / 417.3 | 2.41 |
| 3124 | bug fix | checked | - | 601 | 142.9 / 152.6 / 303.4 | 2.22 |
| 3148 | feature | dropped | probe, `start_run_did_not_finish` | 180 | 142.0 / 29.0 / - | 2.50 |
| 3149 | feature | dropped | probe, `start_run_did_not_finish` | 161 | 142.0 / 13.8 / - | 3.82 |
| 3140 | bug fix | checked | - | 300 | 145.5 / 51.8 / 99.7 | 4.15 |
| 3139 | feature | checked | - | 311 | 147.3 / 65.6 / 95.6 | 3.84 |
| 3142 | feature | checked | - | 361 | 147.0 / 67.0 / 143.1 | 4.59 |
| 3138 | feature | checked | - | 380 | 137.8 / 74.7 / 160.6 | 5.89 |
| 3123 | feature | dropped | probe, `start_run_did_not_finish` | 181 | 156.7 / 18.5 / - | 5.06 |
| 3122 | feature | dropped | probe, `start_run_did_not_finish` | 160 | 140.6 / 13.0 / - | 3.78 |
| 3120 | feature | dropped | probe, `start_run_did_not_finish` | 180 | 145.9 / 34.0 / - | 3.61 |
| 3119 | feature | dropped | probe, `start_run_did_not_finish` | 180 | 140.8 / 29.4 / - | 3.68 |
| 3117 | feature | dropped | probe, `start_run_did_not_finish` | 180 | 142.9 / 30.0 / - | 4.34 |
| 3146 | feature | checked | - | 360 | 146.2 / 75.8 / 132.2 | 3.91 |

The free-space change per try (`disk_used_bytes`) counts the other job's writes on the same disk too, so it is an
upper bound for this job's.

## Files

| File | What it holds |
|---|---|
| `tasks_nerves_hub_web.tsv` | one line per try: merge date, Elixir/OTP pair, task kind, verdict, step and reason, the wall time of each step and the engine's step times, the load, the settled flag, the bytes added |
| `counts.tsv` | the pull requests by verdict, step and reason (the last try of each); the ones not reached are counted as such |
| `project_tests.tsv`, `project_test_failures.tsv` | the project's own suite at pull request 3261 (no failures) |
| `run/` | the scripts that ran: `test.sh`, `tests_chain.sh`, `build.sh`, `docker_shim.sh`, `t0_formatter.exs` (the factory's tests and images, from the set-up job); `controller.sh` (with the release-file hosts); `suite.sh`, `env_tests.sh`, `make_probe.sh`, `prepare.exs`, `tests.exs`, `suite_tables.sh` (the project's suite, from the pilot, for any pull request and image); `all.sh`, `one.sh`, `row.sh`, `watch.sh`, `make_one.exs`, `table.sh` (the run, from the cut-off checks' job, for one project and a target count) |

## Commands

On the data-mining machine, in a job folder `$JOB` holding `run/` (these scripts), `src/` (the factory folder),
`tables/` (the census and screen tables of the pilot's screening), `numbers.txt` and `cache/` (a full clone of the
project as `nerves-hub__nerves_hub_web.git`); `$CTL` is a new folder, `$WORK` holds `tasks/`:

```sh
export SRC=$JOB/src IMAGE=etf-tooling:20261112 LABEL=task-factory=1 HEX_CACHE_ID=etf-hex-packages-v1
OUT=$JOB/out/tests $JOB/run/test.sh format; OUT=$JOB/out/tests $JOB/run/tests_chain.sh   # then unit and docker
OUT=$JOB/out/build IMAGE=elixir-task-factory:nhw-20261112 $JOB/run/build.sh controller
CTL=$CTL NAME=factory-nhw SOURCES=$JOB IMAGE=elixir-task-factory:nhw-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-nhw EPMD_PORT=4512 \
  RELEASE_FILE_HOSTS="github.com release-assets.githubusercontent.com" $JOB/run/controller.sh up
JOB=$JOB CTL=$CTL DATA=$CTL/data GIT_DIR=$JOB/cache/nerves-hub__nerves_hub_web.git NAME=factory-nhw NUMBER=3261 \
  MERGE=20b01f2c9143cdc96f3212dbe738a417ac0cb305 IMAGE=<the table's 1.20.4/29.1.2 image> ROUNDS=1 SUB=env \
  OUT=$JOB/out/suite JOB_LABEL=task-factory-job=hb-nhw TASK_LABEL=task-factory=1 $JOB/run/suite.sh
D=$CTL/data/env OUT=<tables> ROUNDS=1 $JOB/run/suite_tables.sh
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-nhw CACHE=$JOB/cache COPY= $JOB/run/all.sh stage
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-nhw JOB_LABEL=task-factory-job=hb-nhw TASK_LABEL=task-factory=1 TARGET=25 \
  $JOB/run/all.sh run
OUT=$JOB/out NUMBERS=$JOB/numbers.txt TASKDIR=$CTL/data/nhw/tasks SCREEN_TSV=$JOB/tables/<screen> \
  $JOB/run/table.sh tasks       # and counts, images
```

The controller's `fwup` file was the pilot's kept copy, placed at `$CTL/data/release-files/<sha256>.deb` before the
controller started; the engine checks it by its SHA-256 and reuses it.

## Licence

The tables hold pull request numbers, dates, version pairs, reason names, times and byte counts; no code, title, body
or patch text of the project. nerves_hub_web is under Apache-2.0.
