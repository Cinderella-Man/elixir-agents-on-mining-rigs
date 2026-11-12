# hexpm/hexpm: the project's set-up in the task factory, and its first 3 checked cases (2026-11-12)

Registry row [E68](../../../experiments.md) (the pilot of the task factory). `hexpm/hexpm` is one of the dataset's 16
applications ([rules](../../dataset_rules.md)). This job wrote the project's recipe, ran the project's whole test
suite once through the engine, and made and checked its newest candidates one at a time, newest merged first, until 3
were checked. Everything ran on the data-mining machine (28 threads, 30 GiB, no GPU) through a controller of its own,
built from this repository's `main` at `e1d56cb`, while other task-making jobs and one job that uses the model shared
the machine. Times are the data-mining machine's (UTC+1).

## Result

- **The project runs in the engine with one extra package:** `postgresql-client`, so that `mix ecto.load` can load the
  project's saved database layout (`priv/repo/structure.sql`). Nothing else was added: no release file, no other
  service than Postgres.
- **The whole suite passes** at the starting commit of the newest candidate, pull request 2118, on Elixir 1.20.4 with
  OTP 29.1.2 and Postgres 18.6: ExUnit's summary **5,313 passed (32 properties, 5,281 tests), 0 failed, 0 excluded, in
  105.1 s**. The engine's record is complete: 5,313 records, all distinct.
- **3 cases checked of 4 tried:** 2119, 2113 and 2112 checked; 2118 dropped at the probe as `no_existing_tests`, the
  pull request's own cause. Every check was settled: the highest 1-minute load during a check was 9.97 on 28 threads.
- **The hold-out check passes for all 3.** **The licence scan fails all 3, for one reason only:** the project has no
  licence file at its root, and the scan reads the root licence from that file alone. The project states Apache-2.0 in
  the licence section of its `README.md`. Every file the 3 cases touch (21 files) passes the per-file scan at both
  commits.

## 1. The project's set-up

The recipe is [`factory/recipes/hexpm__hexpm.json`](../../../factory/recipes/hexpm__hexpm.json), a template: the
toolchain resolver reads each commit's Elixir, OTP and Postgres from the commit's own files.

| What | Value | Where it comes from |
|---|---|---|
| Elixir and OTP | 1.20.4 and 29.1, served by `hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1` (the table's newest 29.1 line) | the CI workflow's job environment (`elixir: 1.20.4`, `otp: 29.1`) at every candidate tried; the project has no `.tool-versions` |
| Database | Postgres 18.6 (`postgres:18.6-alpine`, pinned by digest) | the CI workflow starts `postgres:18` |
| Other services | none | no Redis client in `mix.exs`; the CI starts only Postgres |
| System package | `postgresql-client` (Ubuntu's, `psql` 16) | the project's `test` alias runs `ecto.load --skip-if-loaded`, and Ecto loads `structure.sql` with `psql`; the layout was written by `pg_dump` 14.23, which `psql` 16 reads |
| Database commands | `mix ecto.create --quiet`, `mix ecto.load --skip-if-loaded --quiet`, `mix ecto.migrate --quiet` | the template's first candidate, taken when `mix.exs` names `ecto.load` in an alias; otherwise create and migrate only |
| Build | `mix compile` after the engine's own dependency steps | the bench's default recipe |
| Whole-suite command | `mix test` | the CI workflow's test job |
| Excluded tags | none | the project's `test_helper.exs` excludes nothing |

What the build fetches besides Hex packages, all as the project's own `mix.exs` and `mix.lock` ask:
- three dependencies from GitHub at the commits `mix.lock` pins (`finch`, `git_diff`, `hex_core`);
- the compiled parts of three packages, from the packages' own release pages through their build steps: `lumis`
  0.10.6 and `mdex_native` 0.3.1 (`rustler_precompiled`; their files in the image are named
  `...-nif-2.15-x86_64-unknown-linux-gnu.so`) and `lazy_html` 0.1.13 (`cc_precompiler`). nerves_hub_web's build
  does the same.

The project's CI also runs a job against the Hex client's own repository (`test-hex`) and a Docker build; neither is
part of the project's test suite, and neither is used.

**The screening's view:** of the project's 150 newest candidates (merged 2026-11-11 back), all 150 get an image since
the table holds Elixir 1.20.4 with OTP 29.1.2; 78 need nothing more, and 72 have a CI file that installs Rust (all of
them merged on or before 2026-10-06). The 4 tried here are the 4 newest of the 78.

## 2. The project's own suite

A hand-made probe task for pull request 2118 (`run/make_probe.sh`, with its own id and a 1,800-second limit for one
test command) was prepared through the controller (`run/prepare.exs`) in 131.2 s cold (the engine's own step 125.5 s:
the toolchain image with `postgresql-client`, the workspace image, the Postgres database with `structure.sql` loaded),
and the whole suite ran once through the engine's own runner (`run/tests.exs`), in a fresh workspace container with a
fresh database and no network. `project_tests.tsv`:

| Run | ExUnit tests | Passed | Failed | Excluded | ExUnit time | Engine time | Return code | Output | Engine: finished |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 5,313 (32 properties, 5,281 tests) | 5,313 | 0 | 0 | 105.1 s | 106.5 s | 0 | 887,347 bytes | yes (5,313 records, all distinct) |

## 3. The candidates

Newest merged first, from the screening's list ([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)),
one at a time: made with the bundle maker and the toolchain resolver through the controller (`run/make_one.exs`),
imported with `factoryctl import`, checked with `factoryctl check --concurrency 1`, and a checked task exported to the
factory's task folder. A check is settled when the 1-minute load stayed under 12 during it. `tasks_hexpm.tsv` has one
line per pull request with every column; the engine's step times are in seconds.

| Pull request | Merged | Elixir/OTP | Kind | Verdict | Step | Reason | Whose | Make | Check (prepare / probe / controls) | Load at start → end (highest in the check) | This job's images added (Docker's bytes) |
|---|---|---|---|---|---|---|---|---:|---|---|---:|
| 2118 | 2026-11-11 | 1.20.4/29.1 | bug fix | dropped | probe | `no_existing_tests` | the pull request's | 5 s (an earlier start) | 50 s (0.1 / 45.9 / -) | 5.39 → 6.58 (5.5) | 0 |
| 2119 | 2026-11-11 | 1.20.4/29.1 | feature | **checked** | - | - | - | 6 s | 280 s (68.6 / 80.5 / 121.9) | 6.58 → 6.68 (8.8) | 1,702,309,990 |
| 2113 | 2026-11-08 | 1.20.4/29.1 | feature | **checked** | - | - | - | 6 s | 941 s (58.2 / 360.9 / 519.6) | 6.68 → 6.00 (9.57) | 1,702,290,798 |
| 2112 | 2026-11-08 | 1.20.4/29.1 | feature | **checked** | - | - | - | 5 s | 370 s (51.7 / 140.8 / 167.9) | 6.00 → 10.48 (9.97) | 1,702,263,669 |

- **2118:** its only existing test file near the change is the test file the pull request changes, and that file's
  starting version fails on the reference fix (the pull request changes the behaviour the old tests asserted). The
  probe left it out (`fails_on_reference`), and no existing test was left. The same drop was seen in an earlier start
  of the run (section 5).
- **2119:** 1 hidden test fails first and 53 pass after the fix; the existing-tests command names 2 files, none left
  out; a partial fix is present.
- **2113:** 4 fail first, 84 pass after; 2 existing files kept, 2 left out (`fails_on_reference`); a partial fix is
  present.
- **2112:** 5 fail first, 100 pass after; 1 existing file kept, 3 left out (`fails_on_reference`); a partial fix is
  present.
- None of the 4 carries the screening's AI-tool mark, a migration or an assets change. All 3 checked tasks may edit
  `lib/` and `test/` only.

**Counts by reason** (`counts.tsv`): checked 3; dropped at the probe, `no_existing_tests`, 1 (the pull request's).
Drops by whose cause: the pull request's 1, the factory's 0, the machine's 0.

**One more pull request was checked out of order, 2109** (merged 2026-11-06, the 7th newest): a stop of the run left
its check running alone in the controller (section 5), and it was let finish. It was **dropped at the second round as
`unstable`**: one test of `HexpmWeb.API.OAuthControllerTest`, among its hidden tests, passed on the reference in the
first round and failed in the second. The load was 9.04 when it ended. The engine keeps no output of a second-round run,
so why the test failed cannot be read. By the rules it is the pull request's cause (an unstable test); it was seen once
and was not run again. It is not counted in the table above.

## 4. Licence and hold-out

Run on each checked task, one at a time (`run/scans.sh`, which calls `factory/tools/check_tasks.sh`), in a Python
container with no network; Hex metadata was fetched for the dependency list. `scans.tsv`, `licence_files.tsv`,
`holdout_tasks.tsv`, `deps_flagged.tsv`:

| Task | Licence result | Root licence found | Files touched | Files passing | Hold-out result | Name hits | Shared 8-word runs (all `common`) | Shared 12-word runs |
|---|---|---|---:|---:|---|---:|---:|---:|
| 2119 | fail: root licence not MIT, Apache-2.0, BSD or ISC | none | 4 | 4 | pass | 0 | 7 | 0 |
| 2113 | fail: root licence not MIT, Apache-2.0, BSD or ISC | none | 6 | 6 | pass | 0 | 7 | 0 |
| 2112 | fail: root licence not MIT, Apache-2.0, BSD or ISC | none | 11 | 11 | pass | 0 | 7 | 0 |

- **Why the licence scan fails:** `task_licence.py` reads the root licence only from a file named `LICENSE`,
  `LICENCE` or `COPYING` (with or without `.md` or `.txt`) at the root. hexpm has none at these commits; its
  `README.md` ends with a licence section that names the Apache License, Version 2.0, and the project's copyright
  holder. So the root family is `none`, the task's `provenance.json` records `NOASSERTION`, and every task fails the
  root rule. Each touched file's own verdict is `ok` at both commits. Whether a licence stated in the README is
  enough is not decided by the rules page; until it is, these 3 tasks stay out of training data
  (`licence_outside_list` covers "a custom or unclear licence text", section 9).
- **The locked dependencies** (the same 158 in all 3 tasks; `deps_flagged.tsv` lists those not plainly allowed): the
  three GitHub dependencies (`finch`, `git_diff`, `hex_core`), whose licences the tool does not read; `bcrypt_elixir`
  3.3.2, which lists BSD-3-Clause, ISC and BSD-4-Clause; and three spelled loosely (`BSD`, `Apache 2.0`). These matter
  for sessions (rules, section 6), not for the tasks.
- **Hold-out:** the repository is not held out, no task names a held-out project, and the 7 shared 8-word runs of each
  task are all `common` (they occur in the cases of two or more of the bench's projects).

## 5. How the run went

The job used the driver scripts of [2026-11-12_tasks_nerves_hub_web](../2026-11-12_tasks_nerves_hub_web/README.md),
with this project's names. The run was started five times; only the fifth gives the table above. The four earlier
starts gave no verdict except the two checks named:

1. **The maker could not read its Git cache** (`fetch_failed`, "detected dubious ownership"): the cache had been copied
   as the machine's work user, and the controller runs as root. 2118, 2119, 2113, 2112 and 2111 were refused at once,
   and the run was stopped by hand. Fixed by giving the cache to root.
2. **The driver could not remove the maker's earlier files** (owned by root) and ended each pull request at once. The
   run was stopped by hand. Meanwhile 2109 had been made and its check started; it ran to its end alone (section 3).
   The earlier files were removed.
3. **The driver could not read the engine's job records**, which the engine writes readable by root only, so it waited
   on 2118's finished check without end. Its check had ended in 104 s: dropped at the probe, `no_existing_tests`. The
   driver was stopped and from then on ran as root, as the other jobs' drivers do.
4. **Every pull request ended before its first step with exit code 126:** `one.sh` passed Docker's whole image list as
   one argument to `jq`, and with the images on the machine by then (149,026 bytes as JSON) that argument passed the
   kernel's 131,072-byte limit for one argument. **This job's `run/one.sh` writes the list to a file instead;** the
   rest of the script is unchanged. The scripts it was copied from have the same limit.

## 6. Disk and load

- **This job's images** carry its label: one toolchain image (879 MB by Docker, its layers shared), six workspace
  images (the probe's, 2109's, 2118's, 2119's, 2113's, 2112's; 329.1 MB each unique, 325.6 MB for 2109's) and five
  Postgres snapshots (61.8 MB each unique). About 2.3 GB in all (est., from Docker's unique sizes).
- **This job's folders:** the controller's data and task folders 393,732,990 bytes, the job folder 272,559,706 bytes
  (with the project's clone and the job's records), the 3 exported task folders 94,564 bytes.
- **The machine:** free bytes on the system disk 798,025,519,104 when the job started (13:16) and 751,960,117,248 when
  the controller stopped (14:29), with every job's use in it. The 1-minute load was 1.82 at the start; during the
  checks it ran from 5.39 to 9.97 on 28 threads.
- **The engine's own limits:** one preparation worker and one check at a time (`--concurrency 1`); the engine has no
  switch for build jobs, and every workspace container runs Erlang with 2 schedulers (the engine's `ERL_FLAGS
  "+S 2:2"`). Every container carried the labels `task-factory=1` and `task-factory-job=hb-hexpm` and a CPU share of
  256; no stop rule fired (free bytes never under 700,000,000,000; load never above 26).

## Files

| File | What it holds |
|---|---|
| `tasks_hexpm.tsv` | one line per pull request tried in the final run: the try, number, id, merge date, Elixir/OTP read, kind, folder origin, verdict, step, reason, the driver's step times, the engine's step times, load at start and end and the highest during the check, settled, the bytes of every image the machine gained meanwhile (all jobs'; images share layers), the build cache's change, the disk bytes used (all jobs'), start, end, and this job's own images and their bytes |
| `counts.tsv` | pull requests per verdict, step and reason |
| `project_tests.tsv` | the whole-suite run: the engine's verdict and counts, ExUnit's summary, the output's size |
| `scans.tsv` | per task: the licence result, the root licence families, files touched and passing, the scan's reasons, the hold-out result, name hits, seconds |
| `licence_files.tsv` | per task and touched file: which patches touch it, the scan's verdict at the starting and the merge commit, the result |
| `holdout_tasks.tsv` | per task: the repository check, name hits, and the shared 8- and 12-word runs by class |
| `deps_flagged.tsv` | the locked dependencies whose licence is not plainly in the list |
| `run/` | the scripts that ran (below) |

## Commands

On the data-mining machine, as root (the engine's job records are readable by root only). `WORK` is the factory's
work folder (with `tasks/`), `JOB` this job's folder (with `run/`, `src/` = this repository's `factory/` at `e1d56cb`
plus this recipe, `tables/` = the screening's census and screen tables of hexpm, `numbers.txt` = the screening's 30
newest candidates, `hexpm.git` = a bare clone of the project, `cache/hexpm__hexpm.git` = a copy of it owned by root),
`CTL` the controller's folder.

```sh
SRC=$JOB/src OUT=$JOB/out IMAGE=elixir-task-factory:hexpm-20261112 LABEL=task-factory=1 run/build.sh controller
CTL=$CTL NAME=factory-hexpm SOURCES=$JOB IMAGE=elixir-task-factory:hexpm-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-hexpm EPMD_PORT=4516 PREPARE_WORKERS=1 PREPARE_AHEAD=1 run/controller.sh up
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-hexpm CACHE=$JOB/cache run/all.sh stage

# the whole suite once at the starting commit of pull request 2118 (merge commit 7347bf2a)
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/hexpm.git NAME=factory-hexpm NUMBER=2118 \
  MERGE=7347bf2aa2a01a2f669cbfdd0120fb7ac7170dda ROUNDS=1 TEST_TIMEOUT=1800 SUB=env OUT=$JOB/out/suite CTL=$CTL \
  JOB_LABEL=task-factory-job=hb-hexpm TASK_LABEL=task-factory=1 MAX_LOAD=26 MIN_FREE=700000000000 run/suite.sh
D=$CTL/data/env OUT=$JOB/out/suite ROUNDS=1 run/suite_tables.sh

# the cases: newest first, until 3 are checked or 12 tried
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-hexpm JOB_LABEL=task-factory-job=hb-hexpm TASK_LABEL=task-factory=1 \
  TARGET=3 MAX_TRIED=12 MAX_LOAD=26 MIN_FREE=700000000000 run/all.sh run

# the licence scan and the hold-out check, one task at a time
SRC=$JOB/src DEST=$WORK/tasks/hexpm__hexpm CLONE=$JOB/hexpm.git BENCH_CASES=<the bench's cases/ folder> \
  OUT=$JOB/out/scans LABELS=task-factory=1,task-factory-job=hb-hexpm \
  run/scans.sh hexpm-pr-2119 hexpm-pr-2113 hexpm-pr-2112

# the tables (NUMBERS: the numbers tried, one per line)
for t in tasks counts images; do
  OUT=$JOB/out NUMBERS=$JOB/out/tried.txt PREFIX=hexpm TASKDIR=$CTL/data/hexpm/tasks \
    SCREEN_TSV=$JOB/tables/screen_hexpm__hexpm.tsv run/table.sh $t > $JOB/out/tables/$t.tsv
done
CTL=$CTL NAME=factory-hexpm run/controller.sh stop
```

`run/` holds `all.sh`, `one.sh` (its image list through a file, section 5), `row.sh`, `watch.sh`, `controller.sh`,
`build.sh`, `state.sh`, `make_one.exs`, `make_probe.sh`, `prepare.exs`, `tests.exs`, `env_tests.sh`, `suite.sh`,
`suite_tables.sh` and `table.sh` from the nerves_hub_web job, with this project's names in `all.sh`, `env_tests.sh`
and `table.sh`, a cap on the pull requests tried in `all.sh`, and `scans.sh`, new.

## Licence

The tables hold pull request numbers, dates, version pairs, reason names, file paths of the project, times and byte
counts; no code, title, body or patch text of the project. hexpm states the Apache License, Version 2.0 in its
README.
