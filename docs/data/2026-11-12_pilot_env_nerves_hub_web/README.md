# Pilot job P3 for `nerves-hub/nerves_hub_web`: the periods of all candidates, the recipe, one starting commit prepared, the project's tests run there

Registry row: E68 (pilot job P3 of the design note
[`task_factory_on_the_bench_engine.md`](../../research/notes/task_factory_on_the_bench_engine.md), section 9). Run on
2026-11-12 on the 7-GPU machine, CPU only, through a controller of its own started from the factory's installed image
(`elixir-task-factory:pilot`, [job P2](../2026-11-12_pilot_controller/README.md)). The same job for the other two pilot
applications: [`2026-11-12_pilot_env_ex338`](../2026-11-12_pilot_env_ex338/README.md) and
[`2026-11-12_pilot_env_radiator`](../2026-11-12_pilot_env_radiator/README.md); this one reuses their scripts.

**Result.** The preparation works and the tests do not, for one reason the engine cannot fix today.

- **Periods.** The 705 candidates fall into 29 toolchain periods. The largest is P02 (Elixir 1.20.3, OTP 29.0.5,
  Postgres 18, ClickHouse 25.4.2.31, merged 2026-08-11 to 2026-10-19), with **127 candidates**. The three newest
  periods hold 201 candidates.
- **Recipe and preparation.** The recipe
  [`factory/recipes/nerves-hub__nerves_hub_web.json`](../../../factory/recipes/nerves-hub__nerves_hub_web.json) serves
  P02. With it the engine prepared the starting commit of pull request 3155 (`b3b161e9`) **cold in 259.9 s**: the
  workspace image, a Postgres database and a ClickHouse database, both migrated.
- **Tests: none ran.** The project's suite ran twice through the engine's own test runner, with no network. **Both runs
  ended before the first test:** 0 passed, 0 failed, 0 excluded, return code 1. The application refuses to start
  unless the `fwup` program is on the `PATH` (`NervesHub.Application.start/2` calls `fwup --version` and raises).
  `fwup` is a system program that every period's CI installs, from a `.deb` on fwup's GitHub releases. The engine
  installs no system package per task, and the image has no `fwup`.
- **Diagnostic runs.** Two more runs used a stand-in `fwup` that answers `--version` and fails every other call. Both
  ran the whole suite in 59.9 s and 58.7 s, and ExUnit's own summary was identical: 3,155 tests (5 doctests),
  **1,520 passed, 1,635 failed (891 of them in `setup_all`), 4 excluded** (the `mtools` tag). The failures shown are
  almost all tests whose fixtures call `fwup` to make keys and firmware.
- **What it needs.** Running this project needs the real `fwup` in the image. `xdelta3`, `mtools` and `detools` are
  needed for a few more tests.

## Files

| File | What it holds |
|---|---|
| `periods.tsv` | the 705 candidates of [`screen_nerves-hub__nerves_hub_web.tsv`](../2026-11-12_pilot_pr_screen/screen_nerves-hub__nerves_hub_web.tsv), each with its period and what its starting commit (first parent of the merge commit, from the [census](../2026-11-11_pilot_pr_census/README.md)) asks for: `.tool-versions`, `mise.toml`, the `elixir:` line of `mix.exs`, the Dockerfile's version arguments, the CI files and, from them, the Elixir image, the Postgres and ClickHouse images, what CI installs and CI's test command |
| `periods_summary.tsv` | one row per period: from, to, candidates, Elixir, OTP, Postgres, ClickHouse, the distinct install lines and test commands of CI in that period |
| `stub_fwup_tests.tsv` | the diagnostic runs with the stand-in `fwup`: each test the engine's reporter named, with its state in run 1 and run 2. See section 4 for why 468 rows are `unknown` |
| `images.tsv` | every image pulled, reused or built, with its size |
| `run/periods.sh` | reads the toolchain of each starting commit from a full clone (step 1); the radiator version, plus `.github/actions/`, the Elixir, Postgres and ClickHouse images of CI, CI's install lines and test command |
| `run/periods_group.awk` | groups the rows of `periods.sh` into periods (one per Elixir, OTP, Postgres image and ClickHouse image) and writes the summary |
| `run/make_probe.sh` | writes the hand-made probe task for one pull request; as radiator's, with the licence taken from `LICENCE` |
| `run/prepare.exs` | run in the controller: the import check, the source pair, the workspace image and the databases; only the default task id differs from radiator |
| `run/tests.exs` | run in the controller: the project's tests through `Eab.Grader.run_tests/3`, twice, each in a fresh box; adds `P3_STUB_FWUP=1`, the diagnostic stand-in for `fwup` |
| `run/watch_labels.sh` | records the label and CPU share of every container the engine starts; unchanged |
| `run/run_all.sh` | the whole job in order, with the exact commands; it starts its own controller (`NAME`, `EPMD_PORT`) and can run a subset of steps (`STEPS`) |

## 1. The periods

Each starting commit's toolchain, read from a full bare clone of the project (33 MB). The history of the files tells the
same story: `.tool-versions` changed 25 times since 2018 and holds Node, Elixir and Erlang (and Python 3.10 from 2024-03
to 2026-02). `mise.toml` exists since 2026-08 and pins only `detools` through pipx. CI moved from CircleCI (Elixir
images `circleci/elixir:1.6` to `1.10`, then `hexpm/elixir` Alpine images) to GitHub Actions with `erlef/setup-beam`
reading `.tool-versions`. 9 candidates were merged into branches that are gone, so their merge commits are not in the
clone (`missing`).

| Period | Merged | Candidates | Elixir, OTP | Postgres | ClickHouse | CI installs |
|---|---|---|---|---|---|---|
| P01 | 2026-10-19 to 2026-11-10 | 44 | 1.20.4, 29.1.2 | 18 | 25.4.2.31 | fwup 1.17.1, xdelta3, mtools, detools |
| **P02** | **2026-08-11 to 2026-10-19** | **127** | **1.20.3, 29.0.5** | **18** | **25.4.2.31** | fwup 1.16.0 (102) or 1.17.1 (25); xdelta3, mtools; detools from 2026-08-23 (97) |
| P03 | 2026-06-06 to 2026-08-09 | 30 | 1.20.0, 29.0.1 | 18 | 25.4.2.31 | fwup 1.16.0, xdelta3, mtools |
| P04 | 2026-05-04 to 2026-06-03 | 11 | 1.19.5, 28.5 | 18 | 25.4.2.31 | fwup 1.13.0 or 1.16.0, xdelta3, mtools |
| P05 | 2026-04-18 to 2026-04-30 | 5 | 1.19.5, 28.3.1 | 18 | 25.4.2.31 | fwup 1.13.0, xdelta3, mtools |
| P06 | 2026-02-23 to 2026-04-17 | 34 | 1.19.5, 28.3.1 | 15 | 25.4.2.31 | fwup 1.13.0, xdelta3, mtools |
| P07 | 2025-05-13 to 2026-02-22 | 86 | 1.18.3, 27.3.3 | 15 | 25.4.2.31 | fwup 1.12.0 or 1.13.0; xdelta3, mtools from 2025-06-13 |
| P08 | 2025-04-23 to 2025-05-09 | 7 | 1.18.3, 27.3.3 | 15 | none | fwup 1.12.0 |
| P09 | 2025-03-12 to 2025-04-22 | 20 | 1.18.3, 27.3 | 15 | none | fwup 1.12.0 |
| P10 | 2024-12-20 to 2025-03-05 | 35 | 1.18.0, 27.1.3 | 15 | none | fwup 1.10.1 |
| P11 to P16 | 2023-12-12 to 2024-12-10 | 77 | 1.15.7 to 1.17.2, OTP 26 or 27 (six pairs) | 15 | none | fwup 1.10.1 |
| P17 to P21 | 2022-03-31 to 2023-12-29 | 56 | 1.13.2 to 1.15.7, OTP 23 to 26 (five pairs) | 10.1 or 12.12 | none | fwup from Alpine (`apk add build-base git fwup` in CI's `hexpm/elixir` Alpine image) |
| P22 to P29 | 2018-03-12 to 2021-07-11 | 164 | Elixir 1.6 to 1.11 from CI images | 10.1 | none | fwup 1.2.0 to 1.3.2 (P22: `apk add … fwup`) |
| missing | | 9 | | | | |

`periods_summary.tsv` has every period on its own row; the counts above add up to 705. Postgres 15 and 18 are CI's
tags (`postgres:15`, `postgres:18`); CircleCI's were `circleci/postgres:10.1-alpine` and `cimg/postgres:12.12`.

**What else would differ in the other periods**, from the files alone (nothing was prepared):
- P01: only `runtime.image` (an Elixir 1.20.4 / OTP 29.1.2 image).
- P03 to P05: `runtime.image` only. P04 and P05 have OTP 28 and Elixir 1.19.5.
- P06 and P07: the image, and the Postgres pin (CI's `postgres:15`).
- P08 to P16: no ClickHouse. `config/test.exs` of those commits configures no `AnalyticsRepo`, so the recipe drops the
  `clickhouse` service (not checked commit by commit).
- P17 and older: Elixir 1.15 and older on Alpine images with OTP 23 to 26. The older half (P22 to P29, 164
  candidates) is the 2018 to 2021 application.
- **Every period needs `fwup`:** CI installs it in every period from 2018 on (in P17 to P22 with `apk add` from Alpine's
  own packages). The boot check of section 4 is in `lib/nerves_hub/application.ex` at the commits checked from P20,
  P16, P10 and P08 (2023 to 2025), and not at that path in P21 (2022) and older; the older fixtures call `fwup` too
  (not checked commit by commit).

## 2. The recipe, field by field

The recipe holds the per-project fields of `case.json` (`factory/README.md`, section 3.2), in the layout of the ex338
and radiator recipes. The bundle maker copies them into each task of P02.

| Field | Value | Why |
|---|---|---|
| `runtime.profile` | `mix` | fixed by the format |
| `runtime.image` | `hexpm/elixir:1.20.3-erlang-29.0.5-ubuntu-noble-20260810@sha256:f1ee5c31…` | the Elixir and OTP of `.tool-versions` in P02; the same image as radiator's recipe, pinned by digest |
| `runtime.environment` | `{"MIX_ENV": "test"}` | as CI. `CI` stays unset, so `test_helper.exs` caps ExUnit at 10 cases at once and the pool size is `schedulers_online * 2` = 4 (the engine sets `+S 2:2`) |
| `runtime.setup_commands` | `["mix compile"]` | compiles the project into the image (24.1 s), so no test run compiles it |
| `runtime.before_test_commands` | `[]` | nothing is needed before a test run |
| `services.postgres.image` | `postgres:18.6-alpine@sha256:9ba53c7d…` | CI's `postgres:18`, which was 18.6 when pull request 3155 was merged (as for radiator's 647, a week later); user and password `postgres`, as `config/test.exs` expects on `localhost` |
| `services.clickhouse.image` | `clickhouse/clickhouse-server:25.4.2.31@sha256:5311f717…` | the version CI starts. The engine starts it in the Postgres container's network with `CLICKHOUSE_SKIP_USER_SETUP=1`, as CI does, so `config/test.exs`'s default URL `http://default:@localhost:8123/default_test` reaches it |
| `baseline` | `{"mode": "prepared", "commands": ["mix ecto.create --quiet", "mix ecto.migrate --quiet"]}` | the first two steps of the project's `test` alias (`ecto.create --quiet`, `ecto.migrate`, `test`). `ecto_repos` lists `NervesHub.AnalyticsRepo` (ClickHouse, 10 migrations) and `NervesHub.Repo` (Postgres, 255 migrations), so both databases are made and migrated once; each run starts from that copy and the alias's migration step prints "Migrations already up" for each |
| `test_timeout` | `240` | the bench's default. The diagnostic runs took 59.9 s and 58.7 s by ExUnit's clock, but with most `fwup` calls failing at once: the time with the real `fwup` is not measured |
| `permitted_exclusion_tags` | `["pending", "mtools"]` | `test_helper.exs` excludes `pending`; the test command excludes `mtools` |
| `grading.preservation` | `mix test --exclude mtools` | the whole suite without the 4 tests tagged `mtools` (`test/nerves_hub/firmwares/update_tool_test.exs`), which need the `mtools` package. CI runs them with `--include mtools`, which has no effect because nothing excludes them by default; without `mtools` their setup calls `flunk("Please install mtools to run these tests.")` |
| `grading.protected_paths` | `["test/"]` | the only test folder |
| `grading.test_suffixes` | `["_test.exs"]` | fixed by the format |

No `runtime.node_image` and no `runtime.packages`: the tests need no Node (CI's Node job is lint and the JS unit
tests). `runtime.packages` would not help yet: the engine does not install it (trimming job T8), and `fwup` is not an
Ubuntu package that CI uses (CI installs fwup's own `.deb`).

## 3. The preparation

The probe task (`run/make_probe.sh`) is pull request 3155, "Fix two partial writes when a device joins", merged
2026-10-19, the newest candidate of P02. Starting commit `b3b161e9ebbbbb556f2cf245f48138f2f70e8e83` (tree `962e63b9…`),
merge commit `ddc55538…` (tree `d70dbf7f…`). Its five files: `case.json` (the recipe's fields, the allowed folders
`lib/` and `test/`, the acceptance command with the pull request's two test files, placeholder test names),
`provenance.json` (licence Apache-2.0), `reference.patch` (2 files under `lib/`), `reference-tests.patch` (two test
files and `test/test_helper.exs`) and the fixed `integrity.patch`. It is a probe: it was not imported into the
candidate store and its controls were not run. The task id is `nerves-hub-web-pr-3155`, since the engine's ids allow
only lower-case letters, digits and hyphens.

`run/prepare.exs` did what `Eab.Candidates.qualify/3` does before the controls:

| Step | Engine part | Result | Time |
|---|---|---|---|
| import check (check 1) | `Eab.Candidates.validate!/1` | ok | under 1 s |
| source pair (check 2) | `Eab.Provenance.verify/3` | both trees fetched and matched; the three patches rebuild the merge tree exactly | 3.6 s |
| toolchain image | `Eab.Fixtures.ensure/3` | reused: the same base image as radiator's recipe gives the same toolchain image | 0 s |
| workspace image | `Eab.Fixtures.ensure/3` | built: `mix deps.get` 13.6 s, `mix deps.loadpaths` (compiles the dependencies) 157.9 s, `mix compile` 24.1 s; about 225 s in all | 225 s |
| databases (check 3) | `Eab.Baseline.ensure/6` | Postgres and ClickHouse started, the baseline ran, the state checked and committed as images (ClickHouse's also sealed); the ClickHouse 25.4.2.31 layout image was built, the Postgres 18.6 one was already there | 29.5 s |
| all | | **prepared** | **259.9 s** |

The engine's database seed record lists no ClickHouse migrations for this project: `Eab.DatabaseSeed` looks for them
in `priv/ingest_repo/migrations` (the bench's Plausible), and this project keeps them in
`priv/analytics_repo/migrations`. They still count, as files under `priv/`, so a later commit reuses this database only
when they are unchanged; the database is correct either way. Every container the engine started carried
`pascal-quants=1` and a CPU share of 256 (from the wrapper); Postgres had no network, and the workspace and ClickHouse
containers shared only Postgres's.

## 4. The project's own tests

`run/tests.exs`, in the controller: `Eab.Sandbox.with_box/4` (a fresh workspace container from the image, a fresh
Postgres and a fresh ClickHouse from their snapshots), `Eab.TestAdapter.install/1` (the engine's reporter), then
`Eab.Grader.run_tests(box, "mix test --exclude mtools")`.

| Run | Return code | Finished | Tests | Passed | Failed | Excluded | Time (engine) |
|---|---|---|---|---|---|---|---|
| 1 | 1 | no | 0 | 0 | 0 | 0 | 5.5 s |
| 2 | 1 | no | 0 | 0 | 0 | 0 | 5.0 s |

Both runs print the same error after the alias's two "Migrations already up" lines:

```
** (Mix) Could not start application nerves_hub: exited in: NervesHub.Application.start(:normal, [])
    ** (EXIT) an exception was raised:
        ** (ErlangError) Erlang error: :enoent
            (elixir 1.20.3) lib/system.ex:1141: System.cmd("fwup", ["--version"], [env: []])
            (nerves_hub 2.4.0+dev) lib/nerves_hub/application.ex:30: NervesHub.Application.start/2
```

Nothing changed between the runs. The suite cannot start without `fwup`. Leaving tests out cannot fix that, because
the application itself will not start.

**The diagnostic runs (`P3_STUB_FWUP=1`, not part of the recipe).** Before each run, `tests.exs` writes a 3-line
`~/.local/bin/fwup` in the box (Ubuntu's login profile puts that folder on the `PATH` of the engine's `bash -lc`). It
prints a version for `--version` and exits 1 with "fwup stub: not installed" for anything else. The application then
starts and the whole suite runs:

| Run | Return code | ExUnit's own line | Time (ExUnit) | Time (engine) |
|---|---|---|---|---|
| 1 | 2 | `Result: 1520/3155 passed (5/5 doctests, 1515/3150 tests), 891 invalid, 4 excluded`, `Failed: 1635 tests` | 59.9 s | 61.9 s |
| 2 | 2 | the same line | 58.7 s | 60.8 s |

The two summaries are identical. The output of each run is larger than the engine's 2 MiB limit for one test command
(`limit: 2_097_152` in `Eab.Grader.run_tests/3`), and the engine keeps only part of it. So the engine marks both runs
unfinished, and its per-test record (`stub_fwup_tests.tsv`) names only part of the tests: 2,791 in run 1, of which 985
passed, 1,334 failed, 4 were excluded and 468 are `unknown`. Run 2 has 1,005 passed, because a different part of the
output was cut. ExUnit's own summary line is the reliable count. With the real `fwup`, far fewer tests fail and print
their errors, so the output should be much smaller (est.); this was not measured.

What the visible failures show (the cut output undercounts each):
- **`fwup`**: almost every failure. 1,357 lines are `File.Error` on a key or firmware file that `fwup -g` or the
  firmware fixtures should have written, such as `org_key-48.pub`. 891 tests are failures in `setup_all`, mostly the
  modules that use `NervesHubWeb.ConnCase.Browser`, which makes a key pair and a signed firmware once per module. 36
  are the stand-in's own message.
- **`detools`**: `test/nerves_hub/firmwares/update_tool/esp_idf_test.exs` (the `create_firmware_delta_file/3` tests)
  raises "`detools` is not installed, and the ESP-IDF delta tests need it" in its setup. They can be left out by that
  file. `detools` is a Python package (pipx), so it is outside any apt list.
- **`xdelta3`**: called by `NervesHub.Firmwares.UpdateTool.Fwup` to make fwup deltas, which the delta tests of
  `test/nerves_hub/firmwares/update_tool_test.exs` and `test/nerves_hub/workers/firmware_delta_builder_test.exs` exercise. No visible failure names it, because those tests fail
  earlier, on `fwup`. They carry no tag; leaving them out would need their files or names.
- **`mtools`**: the 4 tagged tests, left out by `--exclude mtools`.
- No failure names the network, a port or a missing service. The two endpoints listen on 4100 and 4101 inside the box.

**What would make this project run** (none is in the engine today):
1. `fwup` in the workspace image. CI installs a pinned `.deb` from fwup's GitHub releases (`fwup_1.16.0_amd64.deb` or
   `fwup_1.17.1_amd64.deb` in P02). So `runtime.packages` (T8) would need to take a file from a URL with its checksum,
   not only an apt name, or a pinned base image with `fwup` in it would be needed. A set-up command could in principle
   download and unpack the `.deb` into `~/.local/bin` (the build has the network and runs as the image's user). That
   puts a binary from outside the engine's sources into the image, and this job did not do it. A third way: Alpine packages
   `fwup` (CI installed it with `apk add` from 2021 to 2023), and the engine's toolchain stage already uses `apk` on an
   Alpine image; so `runtime.packages` (T8) with an Alpine `hexpm/elixir` image for Elixir 1.20.3 / OTP 29.0.5 might
   be enough. Whether Alpine's current release still has `fwup`, and whether the dependencies build on Alpine, were
   not checked.
2. `xdelta3` and `mtools` from Ubuntu (T8 as planned), for the delta and `mtools` tests.
3. `detools` (pip), or `esp_idf_test.exs` left out.

## 5. What it cost (planning figures, est.)

- **Cold preparation of one commit:** 259.9 s, with the base image and the toolchain image already on the machine and
  the ClickHouse image pulled beforehand. 157.9 s of it compiles the dependencies.
- **One test run:** 5.5 s and 5.0 s to the boot failure. A full suite took 59.9 s and 58.7 s (ExUnit) with the
  stand-in; the time with the real `fwup` is not known.
- **Disk:** free space on `/` was 614 GB before and 610 GB after. `docker images` sizes share layers: the
  ClickHouse image 902 MB (pulled), its layout image and the two ClickHouse snapshots about 903 MB each, almost all of
  it the ClickHouse image's own layers; the workspace image 1.25 GB (of which 911 MB is the toolchain image); the
  Postgres snapshot 494 MB (of which 433 MB is the Postgres image). The 4 GB fall in free space also includes other
  jobs that ran at the same time.

## 6. What differed from ex338 and radiator

- **The suite does not start in the engine.** ex338 and radiator passed all their tests; this application needs a
  system program, `fwup`, at boot.
- **ClickHouse** beside Postgres, the first pilot project to use it, and the engine's ClickHouse support worked: it
  pulled the image, built the layout image, ran the migrations, checked the state and committed it, and started a
  fresh copy for each run.
- **Many candidates in few periods:** 127 of 705 in P02 and 201 in the newest three, against 5 of 30 for ex338 and 1 of
  19 for radiator. The periods were laid over all candidates at once, from a full clone, not over the first 30.
- **The CI files are in two places**, `.github/workflows/ci.yml` and `.github/actions/setup/action.yml` (where
  `setup-beam` reads `.tool-versions`), and in older periods `.circleci/config.yml`.
- **An exclusion tag in the test command** (`--exclude mtools`), and the task id spelled with hyphens.
- **The toolchain image was reused** from radiator (same base image).
- **The engine's 2 MiB output limit** for one test command was reached, with 1,635 failing tests.

## For the next job

- **No task of this project can be checked yet:** each needs the real `fwup` in the workspace image. The recipe is
  ready for P02 and its preparation is proven. Once `fwup` (and `xdelta3`, `mtools`) can be added per task, the
  recipe gains that list and its test command is run again.
- **The probe is not a task:** the prepared images are keyed by the source, the recipe and the environment, so a task
  with the same starting commit and the same recipe reuses them. Adding a package list changes the runtime and so the
  workspace image.

## Commands

On the machine with Docker, from a folder holding `run/*` and the recipe:

```sh
JOB=$PWD WORK=<a controller folder of this job's own> RUN=<folder of controller.sh and docker_shim.sh> \
NAME=factory-nhw EPMD_PORT=4459 \
SCREEN=<path>/screen_nerves-hub__nerves_hub_web.tsv CENSUS=<path>/prs_nerves-hub__nerves_hub_web.tsv.gz ./run_all.sh
awk -F'\t' -v SUMMARY=periods_summary.tsv -f periods_group.awk periods_raw.tsv > periods.tsv
```

The job ran it in parts: `STEPS="periods"` and `STEPS=probe` in the foreground (the ClickHouse image pulled by hand),
then `STEPS="prepare tests stub tables"`, detached with a log and a done marker. `run_all.sh` lists each step: the
clone and `periods.sh`, the pulls, `make_probe.sh` with `NUMBER=3155` and `LICENCE=Apache-2.0`, the controller's `up`,
`prepare.exs` and `tests.exs` started by `controller.sh rpc 'spawn(fn -> Code.eval_file(...) end)'` (`tests.exs` with
its settings put in the controller's environment first: `P3_TAG`, `P3_COMMAND`, `P3_STUB_FWUP`) with a wait on their
done markers, `down`, and the tables.

## Provenance and licence

nerves_hub_web is Apache-2.0 (`LICENSE` at `b3b161e9`). The tables hold commit ids, toolchain versions, CI install
lines and the project's test names. They hold no source code. The images were pulled from Docker Hub (`hexpm/elixir`,
`postgres`, `clickhouse/clickhouse-server`).
