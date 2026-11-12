# The bundle maker names the Redis service; ex338's Redis candidates (2026-11-12, cut off)

Registry rows [E71](../../../experiments.md) and [E72](../../../experiments.md). Job E71 gave the engine a Redis
service; the toolchain resolver of [2026-11-12_maker_toolchain](../2026-11-12_maker_toolchain/README.md) still
refused every starting commit whose `mix.exs` depends on a Redis client (`needs_service:redis`). For
axelclark/ex338 that refusal covered 26 screened candidates, all merged before 2024-03-07, when the application
started a Redix client for its session cache in every environment, tests included. This job changed the resolver
to name the service, then started to make and check the 26 through a controller built from the change. The run was
stopped at 08:52 (UTC+1) on the owner's order to end all task work on the 7-GPU machine, which was being given to a
model's set-up; what had run by then is below.

## Result

- **The resolver names Redis** (`factory/lib/eab/toolchain.ex`, step 5; `factory/README.md` 3.5): a commit with a
  Redis client in `mix.exs`, or whose CI file starts Redis without the template marking it as not needed, gets
  `"redis": {"image": ...}` in its `services` when the image table has a `redis` line: the CI file's Redis version
  matched by prefix (`no_service_image:redis/<version>` when the table lacks it), else the template's
  `services.redis`, else the table's newest line. Any other service the engine lacks, or Redis with no line in the
  table, is still refused as `needs_service:<name>`. A commit that needs no Redis gets no entry and the same record
  as before. The table has one line, `redis:7.2-alpine@sha256:2f66de68…c335`, the image the engine's own Redis tests
  pin; `scripts/toolchain_image.sh redis 7.2` printed exactly that line. The line `resolve` writes has a last column,
  `redis`.
- **What the application needs** (read from the code at the starting commits of #1129 and #1271):
  `lib/ex338/application.ex` takes the Redis address from `Application.get_env(:ex338, :pow_redis, uri:
  "redis://localhost:6379")`; only `config/prod.exs` (2022) or the production block of `config/runtime.exs` (2024)
  sets it, from `REDIS_URL`. Phoenix PubSub uses Redis outside the test environment only. So in a test run the client
  connects to `localhost:6379`, which is where the engine's service listens, and the template needs no setting.
- **All 26 resolved with Redis** (`resolve_ex338_redis.tsv`): 13 with Elixir 1.13.4 / OTP 25.0 and Postgres 10.23,
  2 with 1.14.4 / 25.3.2 and 11 with 1.16.1 / 26.2.1, those 13 with Postgres 14.24; each with
  `redis:7.2-alpine`, named because `mix.exs depends on redix`. The three Elixir pairs were already in the image
  table; the look-up script printed the same three lines again, so no Elixir line was added.
- **Four were made and gated as proofs** (`proofs.tsv`). All four were made, passed the source check and the import
  check, and carry `redis` beside `postgres` in `case.json`, with the record's source in `provenance.json`.
  - **#1271** (1.16.1 / 26.2.1) was prepared with Redis beside Postgres in 205.1 s, and its hidden tests ran and
    finished on the unchanged project and on the reference (127 passed on each side). The probe then dropped it,
    `no_starting_failure`: no hidden test fails before the fix. That drop is the pull request's.
  - **#1129** (1.13.4 / 25.0), **#1269** (1.16.1 / 26.2.1) and **#1208** (1.14.4 / 25.3.2) were dropped at
    prepare. Postgres did not answer the engine's 60-second wait (`127.0.0.1:5432 - no response`) while the engine
    set up a new database family. From about 08:05 another program copied 258 GB onto the same disk. At 08:50 the
    disk was 90.9 % busy with a 219 ms write latency, and `/proc/pressure/io` "full" was at 82.9 (60-second
    average). The same Postgres 10.23 container, started by hand with the engine's flags at 08:17, answered after
    132 s: initdb's sync and the shutdown checkpoint took most of that time. These three drops are the machine's,
    not the pull requests'. **Not settled: re-run on another machine.** The engine's wait is registry row E78, parked.
- **The 26 as a list:** stopped while the maker was making them. None was gated, and none is checked.

| | Pull requests |
|---|---:|
| Candidates refused before (`needs_service:redis`) | 26 |
| Resolved with Redis now | 26 |
| Made, source check passed, import accepted (the proofs) | 4 |
| Prepared | 1 (#1271) |
| Dropped by the probe, the pull request's (`no_starting_failure`) | 1 (#1271) |
| Dropped at prepare, the machine's load (not settled) | 3 (#1129, #1269, #1208) |
| Checked tasks | 0 |
| Not tried as the list (the run was stopped) | 26 (the 4 proofs included) |

**Whose drops:** ours none; the project's none; the pull request's 1 (#1271); the machine's 3 (above).

## Tests

On the 7-GPU machine's CPU, in the tooling image, from 07:59 to 08:52 (UTC+1). The changed tree and public `main`
before the change were each run within minutes of the other:

| Run | Changed tree | `main` before the change |
|---|---|---|
| format check | passes | not run |
| without Docker (`--warnings-as-errors`) | 236 passed, 0 failed, 10 excluded | 231 passed, 0 failed, 10 excluded |
| with Docker, without `docker_settings_docker_test.exs` | stopped at 08:52 after 220 tests: 216 passed, 4 failed, every failure a time-out under the disk load (three Docker tests at 600 s or a check job that did not finish, and `bundle_maker_test`'s rebase-merge test at 60 s, which passes without Docker) | not run (the run was stopped first) |
| `docker_settings_docker_test.exs` alone | not run | not run |

Without Docker every test passes on both trees, so no test that passes on `main` fails there. The 5 new tests pass:
4 in `toolchain_test` and 1 in `bundle_maker_test`, which makes a task from a made-up tree with a Redis client and
imports it. One assertion block was added to `toolchain_test`'s table test: the table's Redis line is the engine's
pin, and an unpinned line is refused. The tests that check the refusal still pass unchanged, because their tables
have no `redis` line. `bench_parity_test` passes 6 of 6, not edited; no file of README section 2 changed. **The
Docker suite is not settled.** `docker_settings_docker_test.exs` removes every `elixir-task-factory:*` tag made on
the machine while it runs, so it is run alone, only when no controller is building images. After the rebase onto public `main` (the retry job's change to `lib/eab/factory.ex` and `factory_test`, the nerves_hub_web template, one comment in `toolchain_test` and the image table's note), the tree was not run again: task work on the 7-GPU machine had ended. None of those commits changed `toolchain.ex` or `bundle_maker.ex`.

## Time and disk

- Make: 202, 190, 259 and 3,219 ms (#1129, #1271, #1269, #1208); the source and import checks 3,850, 3,633, 35,986
  and 19,588 ms (`proofs.tsv`).
- Prepare: #1271 205.1 s. The three dropped ones spent 527.8 s, 663.2 s and 1,567.2 s before the drop, mostly
  building the workspace image under the load.
- Free space on `/` fell from 602,606,649,344 bytes (07:53) to 481,312,055,296 (08:53), most of it the 258 GB copy.
  Images pulled by digest for this job's periods: `hexpm/elixir` 1.13.4/25.0 (79,090,250 bytes), 1.14.4/25.3.2
  (79,605,327) and `postgres:10.23-alpine` (31,165,043). The controller's image `elixir-task-factory:redis-ex338` is
  191,528,244 bytes.

## Files

| File | What it holds |
|---|---|
| `resolve_ex338_redis.tsv` | the resolver's line for each of the 26 (number, starting commit, merge time, result, Elixir, OTP, image, Postgres, baseline, the CI's services, the `mix.exs` clients, Redis) |
| `proofs.tsv` | the four proofs: the resolved pair, Postgres, Redis and its source, made, source check, import, prepared, the hidden tests' counts, the verdict, the check and reason, whose, the times |
| `run/run.sh` | one list resolved, made and gated through a running controller (`bin/factory rpc`), with an optional Git cache, an explicit id list for the gate, and a keep step for the list's own checked folders |
| `run/checks.sh` | the format check and the tests of the changed tree and the reference tree, with `docker_settings_docker_test.exs` held apart |
| `run/summary.sh` | the sums of a task table, in the form of the mass run's `summary.tsv` and `by_period.tsv` (not run: no list was gated) |

The other scripts are unchanged from earlier jobs: the controller,
[`2026-11-12_factory_t10/run/controller.sh`](../2026-11-12_factory_t10/run/controller.sh); `resolve.exs`,
`make.exs` and `gate.exs` from [`2026-11-12_maker_toolchain/run/`](../2026-11-12_maker_toolchain/run/); the task
table, `pool_table.sh` of [`2026-11-12_pilot_tasks_all/run/`](../2026-11-12_pilot_tasks_all/run/); the test
scripts `test.sh`, `docker_shim.sh` and `t0_formatter.exs` of [`2026-11-12_factory_t0/run/`](../2026-11-12_factory_t0/run/)
and `compare.sh` of [`2026-11-12_factory_redis/run/`](../2026-11-12_factory_redis/run/). The made task folders stay
on the build machine and are not published.

## Exact commands

On the build machine, in a work folder `$JOB` holding `src/` (the changed factory folder, with the tooling image's
`.local/`), `base/` (`main` before the change), `build/` (a clean copy of `src/` for the image), `run/` (the scripts
above), `tables/` (ex338's census and screen tables) and the number lists; `$CTL` is a new controller folder:

```sh
WORK=$JOB LABEL=pascal-quants=1 run/checks.sh all c2
run/toolchain_image.sh redis 7.2          # and: elixir 1.13.4 25.0, elixir 1.14.4 25.3.2, elixir 1.16.1 26.2.1
SRC=$JOB/build IMAGE=elixir-task-factory:redis-ex338 run/controller.sh build
IMAGE=elixir-task-factory:redis-ex338 NAME=factory-redis-ex338 EPMD_PORT=4545 \
  DATA=$CTL/data TASKS=$CTL/tasks MIRROR=$CTL/mirror run/controller.sh up
export JOB DATA=$CTL/data NAME=factory-redis-ex338
for step in stage resolve make gate; do      # CACHE (stage only): an earlier list's Git cache of ex338
  SUB=proofs NUMBERS=$JOB/numbers_proofs.txt CONCURRENCY=2 MIN_FREE=<floor> run/run.sh $step
done                                         # numbers_proofs.txt: 1129 1271; then SUB=proofs2 with 1269 1208
for step in stage resolve make; do SUB=all NUMBERS=$JOB/numbers_all.txt run/run.sh $step; done   # stopped in make
LOG=$CTL/controller.log NAME=factory-redis-ex338 run/controller.sh down
```

## Provenance and licence

The pull requests and their code are axelclark/ex338's (MIT, as the tasks' `licence` field reads it); the tables
hold their numbers, the versions read from their files and the images the resolver chose.
