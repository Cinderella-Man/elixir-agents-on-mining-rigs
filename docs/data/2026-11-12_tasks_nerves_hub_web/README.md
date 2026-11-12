# nerves_hub_web: the factory's gaps settled, and its newest candidates checked (2026-11-12)

Registry rows [E86](../../../experiments.md) (a hidden test the project skips), [E88](../../../experiments.md)
(nerves_hub_web's two gaps), [E84](../../../experiments.md) (missing Elixir/OTP pairs) and
[E68](../../../experiments.md) (the pilot of the task factory). `nerves-hub/nerves_hub_web` is one of the dataset's 16
applications ([rules](../../dataset_rules.md)). The pilot job
([2026-11-12_pilot_tasks_nerves_hub_web](../2026-11-12_pilot_tasks_nerves_hub_web/README.md)) put `fwup`, `xdelta3` and
`mtools` into the project's template and made 29 candidates, but no check finished, and three gaps stood in the way of
its tasks. This job settled the gaps in the factory, ran the project's whole suite once, and checked candidates one at a
time, newest merged first, until 25 were checked. Everything ran on the data-mining machine (28 threads, 30 GiB, no
GPU) through a controller of its own, beside one job that uses the model and, from 13:15, five other project sessions;
nothing ran on the model's machine. Times are the data-mining machine's.

## Result

**27 tasks of nerves_hub_web pass the gate, and all 27 pass the licence scan and the hold-out check.** 42 pull
requests were tried, in 47 tries, newest merged first, from 11:40 to 16:40: 27 checked, 15 left out. 26 of the 27 are
settled (the 1-minute load stayed under 12 during the check); 3261 was checked on its second try at a highest load of
12.81. The 27 are 10 bug fixes and 17 features, 18 on Elixir 1.20.3 with OTP 29.0.5 and 9 on Elixir 1.20.4 with OTP
29.1.2, merged 2026-10-01 to 2026-11-10.

- **The gaps are settled** (section 1): a hidden test the project skips is named `skipped_test` at the probe; `zip` is
  in the template; a module run under `parameterize:` gives one record per parameter set; ISC is in the licence tool;
  the pair 1.20.4/29.1.2 is in the image table. A fourth gap, the service images' shared tag, was found during the run
  and settled the same way. The factory's tests pass: 245 without Docker, 255 with it.
- **The project's whole suite finishes** at the starting commit of the newest candidate, pull request 3261: ExUnit's
  4,605 tests all passed, 4 were excluded (the `detools` tests) and none failed, in 237.4 s; the engine's record holds
  4,609 distinct records (section 2).
- **The 15 left out, by cause** (`counts.tsv`, the last try of each):
  - the pull requests' own, 13: `start_run_did_not_finish` 10 (features whose hidden tests need what the fix adds, so
    they cannot run on the unchanged project), `no_existing_tests` 2 (one at the maker, one at the probe),
    `binary_file` 1 (refused by the maker);
  - an unstable test, 2: 3135 and 3101. In each, a test that waits 100 ms for a message (`assert_receive`) failed in
    both tries, at highest loads of 7.66 and 8.10 (3135) and 9.58 and 10.11 (3101), every one under the line of 12.
    The rules count an unstable test as the pull request's own; the same tests passed when the machine was quiet.
  - The factory's cause left no pull request out: it dropped two tries (3108's first and 3097's first, the shared
    service-image tag), and both were checked when tried again.

## 1. The gaps, and how each was settled

| Gap | What happened before | The change | Tests |
|---|---|---|---|
| **A hidden test the project marks as skipped** (E86) | The probe kept a test tagged `@tag :skip` among the hidden tests. The grader passes no skipped test ([factory README](../../../factory/README.md) 2.2), so the reference control failed, and the task was dropped as `reference_existing_tests_fail` although the existing tests passed. | `Eab.BundleProbe.observe/2` refuses such a task as `skipped_test`, naming the skipped tests, before any control runs; `Eab.Factory.first_failure/2` names a reference that fails only on a skipped test the same way. The task is still lost: keeping it would need the grader to pass a skipped test, which departs from the bench. The cause is the pull request's own (its changed test file holds the skipped test). No candidate of this run hit it. | `observe/2` on a made-up run; `first_failure/2` on made-up controls (four cases); the probe on a made-up task whose hidden file has a skip-tagged test (Docker) |
| **`zip` is not in the image** (E88) | 13 of the project's tests call `System.cmd("zip", ...)`, which raised `:enoent`: 10 in `update_tool_test.exs`, 3 in `firmware_delta_builder_test.exs`. GitHub's runner image has `zip`; the project's CI never installs it. | `zip` joins `xdelta3` and `mtools` in `runtime.packages` of [the template](../../../factory/recipes/nerves-hub__nerves_hub_web.json). | the whole suite below: no test fails |
| **One module runs twice under `parameterize:`** (E88) | `test/nerves_hub_web/channels/websocket_test.exs` uses `use NervesHubWeb.ChannelCase, parameterize: [%{serializer: :json}, %{serializer: :msgpack}]`, so ExUnit runs each of its tests twice under one name. The reporter wrote one name twice, and `Eab.Grader.parse/2` called every run that held the file unfinished. | The reporter (`priv/fixtures/grade_formatter.exs`) adds a test's parameters to its name when its module runs once per parameter set: `Elixir.M::test a %{serializer: :json}`. Every other test's record is the bench's, byte for byte; `parse/2` is unchanged; the model never sees the file (it is copied into grading containers only). The parity test pins the new blob id (`75eed312`) with the bench's (`ea8dec71`) in a comment. | the reporter on made-up test structs (with and without parameters, and an older struct with no such field); a real ExUnit run of a parameterized module in a temporary project, parsed by `parse/2` |
| **The licence tool's list** | `task_licence.py` did not hold ISC, which the owner added on 2026-11-12. | ISC in `ALLOWED_SPDX`, in the loose spellings (`isc`, `ISC License`) and in the root licence families. | `factory/tools/test_task_licence.py`, 4 tests |
| **The newest candidates' pair** (E84) | The project's 44 newest candidates (merged 2026-10-19 to 2026-11-10) name Elixir 1.20.4 with OTP 29.1.2, which the image table lacked (`no_image:1.20.4/29.1.2`). | One line in `factory/config/toolchain_images.json`, printed by `scripts/toolchain_image.sh elixir 1.20.4 29.1.2`: `hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1`, pinned by digest. The image-table job added the same line, with the same digest, the same day. | `toolchain_test` reads the table; 9 of the checked tasks run on it |

**A fourth gap, found during the run: the service images' shared tag.** The engine builds each database's "layout"
image (`FROM postgres…` with the data folder the snapshots capture) under `elixir-task-factory:layout-<key of the
recipe>`, the same tag in every installation. From 13:15 six controllers shared the machine's Docker, each with its
own labels, so each built its own image under that one tag; the Postgres 18.6 layout tag pointed at five different
images that day. On this Docker (the containerd image store) an image whose last tag moves to another image is removed
at once, and the engine's cache then named an image that was gone: `docker failed: … content digest sha256:3a7666a0…:
not found`, at the step that starts a new database family. It dropped 3108's first try and 3097's first at `prepare`
(`environment`), the factory's cause, and it would drop every task that needs a new database on any controller there.
The change (`Eab.ServiceImages.build/2`): each service image (layouts, checkpoints, sealed ClickHouse snapshots) is
built under a second tag of the installation's own (`elixir-task-factory:<identity>-<installation>`, `own_tag/1`),
which no other controller moves, and its id is read from that tag. A Docker test moves the shared tag to another image
and checks that the layout image stays and the cache still finds it. The run was held after 3101, the controller was
rebuilt (`elixir-task-factory:nhw-20261112-b`; the first container is kept, stopped, as `factory-nhw-a`), and 3097 was
tried again first (`run/all.sh`, `AGAIN`).

**The factory's tests** on the data-mining machine, in the tooling image (`run/test.sh`):

| Run | Before (the set-up job) | After the first three gaps | After the fourth |
|---|---|---|---|
| without Docker | 240 passed, 0 failed, 10 excluded | 243 passed, 0 failed, 10 excluded (33.7 s) | 245 passed, 0 failed, 10 excluded (39.4 s) |
| with Docker | 250 passed, 0 failed | 253 passed, 0 failed (378.9 s) | 255 passed, 0 failed (381.4 s) |
| format check | passes | passes | passes |
| `factory/tools/test_task_licence.py` | - | 4 of 4 | - |

The three new tests of the first change are the reporter's two and `first_failure/2`'s; the probe's Docker test and
`observe/2`'s unit test gained a case each. The last column runs on `main` after the image-table job's change, whose
two tests make the difference of two; the fourth gap's test is a new case in `docker_settings_docker_test`. The parity
test passes in every run.

## 2. The project's own suite

A hand-made probe task for pull request 3261 (`run/make_probe.sh`, with its own id and a 900-second limit for one
test command) on the image the resolver gives that commit (`hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1`,
from `.tool-versions`), with Postgres 18.6 and ClickHouse 25.4.2.31 from the project's CI file and the template's
packages and release file. It was prepared through the controller in 184.4 s (cold: the new Elixir image, the
workspace, the two databases; `fwup`'s `.deb` was the pilot's kept copy, checked by its SHA-256, so nothing was
fetched from the release page), and the whole suite ran once through the engine's own runner (`run/tests.exs`,
`Eab.Grader.run_tests/3` with the engine's reporter), in a fresh workspace container with fresh databases, at a load
near 1.

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
403 pull requests in all (`numbers.txt` on the machine). The run stopped starting pull requests when 25 were checked:
the dataset takes at most 15 cases of one project into its first 100 (rules, section 7), and 25 leaves room for drops
at the session stage. 361 were not reached.

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

Five drops were tried a second time (`run/all.sh`, `AGAIN`): 3097 (the factory's cause, settled) and 3135, 3101, 3261
and 3111, whose drops looked like instability rather than a broken fix. 3111's hidden tests were first run once more
on the fixed code with their output kept (`run/hidden_output.exs`): all 112 passed, where its first try had one fail.

| Pull request | Try | Merged | Elixir/OTP | Kind | Verdict | Step, reason | Check (s) | Prepare / probe / controls (s) | Highest load |
|---|---:|---|---|---|---|---|---:|---|---:|
| 3155 | 1 | 2026-10-19 | 1.20.3/29.0.5 | bug fix | checked | - | 421 | 186.3 / 79.4 / 148.9 | 2.42 |
| 3159 | 1 | 2026-10-19 | 1.20.3/29.0.5 | feature | checked | - | 470 | 142.7 / 143.6 / 178.1 | 2.13 |
| 3156 | 1 | 2026-10-17 | 1.20.3/29.0.5 | bug fix | checked | - | 321 | 142.6 / 69.4 / 105.5 | 2.1 |
| 3153 | 1 | 2026-10-16 | 1.20.3/29.0.5 | feature | checked | - | 761 | 140.6 / 198.1 / 417.3 | 2.41 |
| 3124 | 1 | 2026-10-15 | 1.20.3/29.0.5 | bug fix | checked | - | 601 | 142.9 / 152.6 / 303.4 | 2.22 |
| 3148 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | dropped | probe, `start_run_did_not_finish` | 180 | 142.0 / 29.0 / - | 2.5 |
| 3149 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | dropped | probe, `start_run_did_not_finish` | 161 | 142.0 / 13.8 / - | 3.82 |
| 3140 | 1 | 2026-10-15 | 1.20.3/29.0.5 | bug fix | checked | - | 300 | 145.5 / 51.8 / 99.7 | 4.15 |
| 3139 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | checked | - | 311 | 147.3 / 65.6 / 95.6 | 3.84 |
| 3142 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | checked | - | 361 | 147.0 / 67.0 / 143.1 | 4.59 |
| 3138 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | checked | - | 380 | 137.8 / 74.7 / 160.6 | 5.89 |
| 3123 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | dropped | probe, `start_run_did_not_finish` | 181 | 156.7 / 18.5 / - | 5.06 |
| 3122 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | dropped | probe, `start_run_did_not_finish` | 160 | 140.6 / 13.0 / - | 3.78 |
| 3120 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | dropped | probe, `start_run_did_not_finish` | 180 | 145.9 / 34.0 / - | 3.61 |
| 3119 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | dropped | probe, `start_run_did_not_finish` | 180 | 140.8 / 29.4 / - | 3.68 |
| 3117 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | dropped | probe, `start_run_did_not_finish` | 180 | 142.9 / 30.0 / - | 4.34 |
| 3146 | 1 | 2026-10-15 | 1.20.3/29.0.5 | feature | checked | - | 360 | 146.2 / 75.8 / 132.2 | 3.91 |
| 3145 | 1 | 2026-10-14 | 1.20.3/29.0.5 | feature | checked | - | 271 | 141.3 / 46.2 / 81.8 | 2.57 |
| 3135 | 1 | 2026-10-14 | 1.20.3/29.0.5 | feature | dropped | controls, `starting_failures_differ` | 321 | 142.4 / 82.2 / 93.1 | 7.66 |
| 3135 | 2 | 2026-10-14 | 1.20.3/29.0.5 | feature | dropped | probe, `reference_fails_hidden` | 70 | 22.0 / 39.9 / - | 8.1 |
| 3133 | 1 | 2026-10-14 | 1.20.3/29.0.5 | bug fix | dropped | probe, `no_existing_tests` | 221 | 162.1 / 49.3 / - | 9.19 |
| 3118 | 1 | 2026-10-14 | - | - | refused | maker, `no_existing_tests` | - | - | - |
| 3113 | 1 | 2026-10-14 | 1.20.3/29.0.5 | feature | checked | - | 391 | 193.8 / 63.8 / 123.2 | 7.81 |
| 3108 | 1 | 2026-10-12 | 1.20.3/29.0.5 | feature | checked | - | 631 | 15.3 / 195.8 / 418.0 | 8.73 |
| 3115 | 1 | 2026-10-12 | 1.20.3/29.0.5 | bug fix | checked | - | 401 | 161.6 / 75.1 / 161.7 | 8.75 |
| 3114 | 1 | 2026-10-11 | 1.20.3/29.0.5 | feature | dropped | probe, `start_run_did_not_finish` | 220 | 188.4 / 31.7 / - | 8.09 |
| 3111 | 1 | 2026-10-10 | 1.20.3/29.0.5 | feature | dropped | probe, `reference_fails_hidden` | 220 | 175.7 / 37.1 / - | 8.18 |
| 3111 | 2 | 2026-10-10 | 1.20.3/29.0.5 | feature | checked | - | 430 | 39.4 / 150.4 / 235.6 | 11.14 |
| 3100 | 1 | 2026-10-05 | 1.20.3/29.0.5 | feature | checked | - | 370 | 171.5 / 65.3 / 126.4 | 9.06 |
| 3097 | 1 | 2026-10-05 | 1.20.3/29.0.5 | bug fix | dropped | prepare, `environment` | 210 | 205.3 / - / - | 7.78 |
| 3097 | 2 | 2026-10-05 | 1.20.3/29.0.5 | bug fix | checked | - | 461 | 23.0 / 146.2 / 282.4 | 10.61 |
| 3101 | 1 | 2026-10-04 | 1.20.3/29.0.5 | bug fix | dropped | controls, `reference_existing_tests_fail` | 521 | 184.6 / 167.5 / 159.2 | 9.58 |
| 3101 | 2 | 2026-10-04 | 1.20.3/29.0.5 | bug fix | dropped | controls, `reference_existing_tests_fail` | 380 | 19.0 / 172.3 / 181.7 | 10.11 |
| 3082 | 1 | 2026-10-01 | 1.20.3/29.0.5 | feature | checked | - | 671 | 184.1 / 147.7 / 338.5 | 10.1 |
| 3261 | 1 | 2026-11-10 | 1.20.4/29.1.2 | feature | dropped | probe, `reference_fails_hidden` | 270 | 214.4 / 55.1 / - | 9.44 |
| 3261 | 2 | 2026-11-10 | 1.20.4/29.1.2 | feature | checked | - | 705 | 0.2 / 211.5 / 483.1 | 12.81 (not settled) |
| 3259 | 1 | 2026-11-10 | 1.20.4/29.1.2 | feature | checked | - | 411 | 203.1 / 66.7 / 131.0 | 10.93 |
| 3258 | 1 | 2026-11-10 | 1.20.4/29.1.2 | feature | checked | - | 641 | 191.3 / 148.3 / 295.2 | 11.48 |
| 3257 | 1 | 2026-11-10 | 1.20.4/29.1.2 | bug fix | checked | - | 451 | 187.5 / 84.2 / 172.1 | 9.33 |
| 3255 | 1 | 2026-11-10 | 1.20.4/29.1.2 | bug fix | checked | - | 481 | 177.7 / 112.8 / 187.3 | 8.28 |
| 3256 | 1 | 2026-11-10 | 1.20.4/29.1.2 | bug fix | checked | - | 391 | 177.3 / 65.5 / 146.7 | 7.07 |
| 3254 | 1 | 2026-11-10 | 1.20.4/29.1.2 | bug fix | checked | - | 420 | 160.0 / 73.1 / 186.9 | 9.34 |
| 3248 | 1 | 2026-11-10 | 1.20.4/29.1.2 | feature | dropped | probe, `start_run_did_not_finish` | 211 | 186.0 / 17.0 / - | 8.95 |
| 3236 | 1 | 2026-11-10 | - | - | refused | maker, `binary_file` | - | - | - |
| 3235 | 1 | 2026-11-10 | 1.20.4/29.1.2 | feature | checked | - | 711 | 168.2 / 156.4 / 376.3 | 8.46 |
| 3234 | 1 | 2026-11-09 | 1.20.4/29.1.2 | feature | dropped | probe, `start_run_did_not_finish` | 231 | 182.8 / 39.9 / - | 8.58 |
| 3233 | 1 | 2026-11-09 | 1.20.4/29.1.2 | feature | checked | - | 430 | 193.2 / 84.6 / 146.3 | 7.68 |

**What each drop is:**
- `start_run_did_not_finish` (10): each pull request is a feature whose hidden tests need what the fix adds, so their
  run on the unchanged project does not finish. Nine add new files under `lib/` (3148 adds 10, 3149 3, 3123 7, 3122 5,
  3120 11, 3119 10, 3117 16, 3248 1, 3234 1) beside new or changed test files; 3114 adds none. For three the hidden
  tests were run once more on the unchanged project with their output kept (`run/hidden_output.exs`): 3248 and 3234
  stop at a compile error (a struct, a module the fix adds), 3114 stops after 9 tests with a `KeyError` for a key the
  fix adds (`:map_style`). Every such probe took under 40 s, far from the engine's 240-second limit.
- `no_existing_tests` (2): 3133's three existing test files, in their starting version, each fail on the fixed code
  (the pull request changed the behaviour they cover); the maker found none for 3118, as in the pilot.
- `binary_file` (1): 3236 changes a binary file, which the engine's patches cannot carry.
- 3135 and 3101: the failing test is `assert_receive` with its default 100 ms (in
  `extensions_channel_test.exs` for 3135, `devices_test.exs`'s `async_bulk_create/4` test for 3101). 3261's first
  try failed on the same `devices_test.exs` test and its second passed every control.
- 3097's first try: the shared service-image tag (section 1).

**What interrupted the run, and what it cost:**
- **13:39, the driver's state snapshot:** `one.sh` passed Docker's whole image list to `jq` as one argument; with the
  other sessions' images it passed Linux's 128 KiB limit for one argument, and 29 starts failed at once with exit 126
  before any step (no task touched; 3108, whose check had just ended, lost its row and was checked again). The image
  list now goes through a file.
- **14:24, the service-image fix:** the remaining pull requests were held, the controller rebuilt, and the run
  started again (section 1).
- **16:12, a watcher with the old floor:** a driver started for the second tries ran its watcher with the earlier
  default of 700,000,000,000 bytes, which stopped the job at once; 3135's second try was cut off before any step and
  run again. The default is now 50,000,000,000 bytes.

The stop rules (`run/watch.sh`): free space under 700,000,000,000 bytes, lowered to 50,000,000,000 at about 14:43
on the owner's word ("do not stop - you can use drive up to 50GB left"); the 1-minute load above 20 in two readings
five minutes apart; a bench run on the same Docker. Apart from the 16:12 stop above, none fired.

## 4. The licence scan and the hold-out check

`factory/tools/check_tasks.sh` on the 27 checked task folders (`run/scans.sh`), with the project's full clone, the
bench's 20 case files read in place and deleted after the run, and a Python 3.12 image already on the machine.
`licence_tasks.tsv` and `holdout_tasks.tsv`:

| Check | Result |
|---|---|
| Licence, per file | 27 of 27 pass: 248 files touched, none failing; the root licence is Apache-2.0 at every starting commit, as the task records say |
| Hold-out | 27 of 27 pass: the repository and its names are not held out (0 name hits); shared runs of words with the bench's cases: 8 words: 275 common, 35 syntax, 12 own-tree, 0 to read; 12 words: 81 common, 3 syntax, 4 own-tree, 0 to read |
| Dependencies' licences | not fetched: the Hex metadata was not downloaded (226 locked packages: 219 not fetched, 7 git dependencies). No task's verdict depends on it |

## 5. Time and disk

- **Time:** the 47 tries took 16,898 s of wall time (make, import, check and export), 625.9 s per checked task (est.:
  the drops' time shared over the 27). Of the 27 checks that passed, the shortest took 271 s and the longest 761 s
  (`tasks_nerves_hub_web.tsv` has each one).
- **Disk:** this job's own images (180, with its label: project images, database snapshots, layouts, toolchains) hold
  16,353,516,973 bytes that no other image shares; the controller's data folder 1,472,886,970 bytes; the job's folder
  623,476,486 bytes (560 MB of it the scan's checked-out trees); the 27 task folders 1,390,933 bytes. That is
  683,380,421 bytes per checked task (est.; layers shared between this job's own images are not counted). The free
  space on the disk fell by 146,932,936,704 bytes over the 47 tries, the other sessions' writes included.

## Files

| File | What it holds |
|---|---|
| `tasks_nerves_hub_web.tsv` | one line per try: merge date, Elixir/OTP pair, task kind, verdict, step and reason, the wall time of each step and the engine's step times, the load, the settled flag, the bytes added |
| `counts.tsv` | the pull requests by verdict, step and reason (the last try of each); the ones not reached are counted as such |
| `project_tests.tsv`, `project_test_failures.tsv` | the project's own suite at pull request 3261 (no failures) |
| `licence_tasks.tsv`, `holdout_tasks.tsv` | the licence scan and the hold-out check, one line per checked task |
| `run/` | the scripts that ran: `test.sh`, `tests_chain.sh`, `build.sh`, `docker_shim.sh`, `t0_formatter.exs` (the factory's tests and images, from the set-up job); `controller.sh` (with the release-file hosts); `suite.sh`, `env_tests.sh`, `make_probe.sh`, `prepare.exs`, `tests.exs`, `suite_tables.sh` (the project's suite, from the pilot, for any pull request and image); `all.sh`, `one.sh`, `row.sh`, `watch.sh`, `make_one.exs`, `table.sh` (the run, from the cut-off checks' job, for one project, a target count and second tries); `hidden_output.exs` (one task's hidden tests with their output kept); `scans.sh` (the licence scan and the hold-out check) |

## Commands

On the data-mining machine, in a job folder `$JOB` holding `run/` (these scripts), `src/` (the factory folder),
`tables/` (the census and screen tables of the pilot's screening), `numbers.txt` and `cache/` (a full clone of the
project as `nerves-hub__nerves_hub_web.git`); `$CTL` is a new folder, `$WORK` holds `tasks/`:

```sh
export SRC=$JOB/src IMAGE=etf-tooling:20261112 LABEL=task-factory=1 HEX_CACHE_ID=etf-hex-packages-v1
OUT=$JOB/out/tests $JOB/run/test.sh format; OUT=$JOB/out/tests $JOB/run/tests_chain.sh   # then unit and docker
OUT=$JOB/out/build IMAGE=elixir-task-factory:nhw-20261112-b $JOB/run/build.sh controller
CTL=$CTL NAME=factory-nhw SOURCES=$JOB IMAGE=elixir-task-factory:nhw-20261112-b HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-nhw EPMD_PORT=4512 \
  RELEASE_FILE_HOSTS="github.com release-assets.githubusercontent.com" $JOB/run/controller.sh up
JOB=$JOB CTL=$CTL DATA=$CTL/data GIT_DIR=$JOB/cache/nerves-hub__nerves_hub_web.git NAME=factory-nhw NUMBER=3261 \
  MERGE=20b01f2c9143cdc96f3212dbe738a417ac0cb305 IMAGE=<the table's 1.20.4/29.1.2 image> ROUNDS=1 SUB=env \
  OUT=$JOB/out/suite JOB_LABEL=task-factory-job=hb-nhw TASK_LABEL=task-factory=1 $JOB/run/suite.sh
D=$CTL/data/env OUT=<tables> ROUNDS=1 $JOB/run/suite_tables.sh
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-nhw CACHE=$JOB/cache COPY= $JOB/run/all.sh stage
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-nhw JOB_LABEL=task-factory-job=hb-nhw TASK_LABEL=task-factory=1 TARGET=25 \
  $JOB/run/all.sh run            # later runs with AGAIN="<numbers>" for second tries
CTL=$CTL NAME=factory-nhw $JOB/run/controller.sh rpc 'System.put_env(%{"HIDDEN_ID" => "nerves-hub-web-pr-3111", "HIDDEN_DIR" => "<its task folder>", "HIDDEN_OUT" => "/data/hidden"}); spawn(fn -> Code.eval_file("/data/hidden_output.exs") end)'
SRC=$JOB/src TASKS=$WORK/tasks/nerves-hub__nerves_hub_web CLONES=$JOB/cache/nerves-hub__nerves_hub_web.git \
  BENCH=<the bench's cases/ folder> SCAN=$JOB/scan IMAGE=python:3.12-slim-bookworm \
  LABELS="task-factory=1 task-factory-job=hb-nhw" $JOB/run/scans.sh
OUT=$JOB/out NUMBERS=$JOB/numbers.txt TASKDIR=$CTL/data/nhw/tasks SCREEN_TSV=$JOB/tables/<screen> \
  $JOB/run/table.sh tasks       # and counts, images
```

The controller's `fwup` file was the pilot's kept copy, placed at `$CTL/data/release-files/<sha256>.deb` before the
controller started; the engine checks it by its SHA-256 and reuses it. `hidden_output.exs` is copied into `$CTL/data`
first.

## Licence

The tables hold pull request numbers, dates, version pairs, reason names, times, byte counts and the licence and
hold-out verdicts; no code, title, body or patch text of the project. nerves_hub_web is under Apache-2.0.
