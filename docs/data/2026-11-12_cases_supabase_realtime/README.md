# supabase/realtime in the task factory: set-up and the newest candidates (2026-11-12)

One of the five project jobs of 2026-11-12, for [supabase/realtime](https://github.com/supabase/realtime) (Apache-2.0),
one of the dataset's 16 applications ([dataset rules](../../dataset_rules.md)). The job set the project up in the task
factory on the data-mining machine and took its candidates newest merged first, one at a time.

## Result

**0 checked cases.** The project builds in the engine, but its tests cannot run there: they need Supabase's own
Postgres build, and they start their own database containers through Docker. Neither is something the engine offers
today. Every one of the 150 newest candidates has the same need, so none of them can be checked until the factory
serves it.

| | Count |
|---|---:|
| Candidates tried, newest merged first | 12 |
| Refused by the bundle maker: `no_existing_tests` (the pull request's own cause) | 1 (2547) |
| Made, with the source check and the import check passed | 11 |
| Put through the gate: dropped at the environment step, `needs_service:supabase_postgres` (the factory's cause) | 1 (2543) |
| Made only, not checked: the same environment step would fail (`needs_service:supabase_postgres`) | 10 |
| Checked | 0 |

The licence scan and the hold-out check run on checked cases only, so they did not run.

## The project's set-up

At pull request 2547's starting commit (`87c669e5`, merged 2026-11-12):

- **Elixir and OTP:** 1.19.5 with OTP 28.5.0.4, from `mise.toml` (the CI workflow names the same pair). The image
  table has the pair: `hexpm/elixir:1.19.5-erlang-28.5.0.4-ubuntu-noble-20260730.1`, pinned by digest. All 11 made
  candidates resolve to it. The screening's 150 newest candidates are 123 on this pair and 27 on 1.18.4 with OTP 27.
- **The build works.** The workspace image fetched the Hex packages and the three Git dependencies (`heroicons`,
  `gen_rpc`, `postgres_replication`) and compiled the project with its three in-repository path dependencies
  (`forum`, `policy_eval`, `rollcall`). The build took 142 s with no build seed; the whole preparation, the failed
  database step included, took 150.9 s.
- **The database step fails.** The recipe's baseline is the project's own `mix ecto.create` and `mix ecto.migrate`
  (its `mix test` alias runs the same two first). `config/test.exs` connects as `supabase_admin` with the password
  `postgres`. The engine's Postgres (`postgres:18.6-alpine`, the table's newest) has no such role:

  ```
  FATAL 28000 (invalid_authorization_specification) role "supabase_admin" does not exist
  ** (Mix) The database for Realtime.Repo couldn't be created: killed
  ```

- **The suite:** not run; the engine refuses a test run on an environment that was not prepared. There is no ExUnit
  summary.

### What the project's tests need

Read from the files at `87c669e5` (`config/test.exs`, `test/test_helper.exs`, `test/support/test_tenant_db/`,
`compose.*.yml`, `dev/postgres/`, `.github/workflows/tests.yml`, `.github/db-images.json`):

1. **Supabase's Postgres build,** `supabase/postgres` (17.11.0.018 in the compose files; CI runs the suite on six
   tenant databases: Supabase's Postgres 14, 15 (two builds), 17 and 17 with OrioleDB, and a Multigres cluster). It
   brings the role `supabase_admin` (the image's superuser), the roles `anon`, `authenticated`, `service_role` and
   `supabase_auth_admin`, the schemas `auth` and `extensions`, Supabase's extensions, and logical WAL
   (`wal_level = logical` in its configuration). The project's bootstrap, `dev/postgres/zb-supabase-schema.sql`,
   builds on all of these, so a stock Postgres cannot stand in for it.
2. **Tenant databases besides the project's own database.** By default (`TestTenantDb.Backend.Docker`) the test run
   itself starts `supabase/postgres` containers with `docker run`, one per pool worker (`MAX_CASES`, 4 by default,
   plus 2). With `USE_EXTERNAL_TENANT_DB=true` it uses running servers on the ports of `EXTERNAL_TENANT_DB_PORTS`
   instead (CI: five, on 5433 to 5437), and runs one test module fewer at a time than it has ports. The engine runs
   one Postgres on 127.0.0.1:5432 and gives the workspace no Docker and no network.
3. **The engine cannot run Supabase's image as its Postgres as it is.** The engine's Postgres layout image moves the
   data folder with `PGDATA=/opt/eab-state/postgres` and checks `SHOW data_directory` before it saves the database
   state. Supabase's image starts with `postgres -D /etc/postgresql`, and its `postgresql.conf` fixes
   `data_directory = '/var/lib/postgresql/data'`. Serving it needs a change to the factory's service recipe.
4. **The image is a download outside this job's allowance.** `supabase/postgres:17.11.0.018` (index digest
   `sha256:7c31363a3f7434ff14945f1b8a4880e6eca8b362e197e88b87c476c77aa3cf8c`) is 333,723,664 bytes compressed in 28
   layers for amd64, by the registry's manifest. It was not downloaded.

The same need holds for every candidate in the screened range: the tenant-database helpers that start Docker
containers are present at the newest starting commit, the 50th, the 100th and the 150th (2026-06-24; there as
`test/support/containers.ex`).

### The recipe

[`factory/recipes/supabase__realtime.json`](../../../factory/recipes/supabase__realtime.json) is marked `provisional`
with the reason above. It holds the image, the engine's Postgres, the project's database commands, the whole-suite
command `mix test`, and the 11 tags `test/test_helper.exs` may exclude at run time (`failing`, `requires_pg_140006`,
`requires_pg_150000`, `requires_pgdelta_shadow_cleanup`, `requires_supautils_policy_grants`,
`requires_no_supautils_policy_grants`, `skip_orioledb`, `requires_orioledb`, `requires_docker_backend`,
`requires_direct_connection`, `requires_synchronous_standby`) as permitted exclusion tags. Its `toolchain` block lets
the resolver serve each commit; this project's CI starts no database service, so the resolver keeps the recipe's
Postgres.

## The candidates

[`tasks.tsv`](tasks.tsv) has one line per gate try (the merge date, the Elixir/OTP pair and kind of the made folder,
the verdict, the step and reason, the wall time of each step, the engine's step times, the 1-minute load at start
and end and its highest value during the check, and the disk bytes). [`make_only.tsv`](make_only.tsv) has the bundle
maker's result for the 11 that were made (the starting commit, the pair, the kind, the number of hidden tests, the
source and import checks, the time, the load and the free bytes before and after). [`counts.tsv`](counts.tsv) counts
the gate's tries by reason.

| Pull request | Merged | Elixir/OTP | Kind | Verdict | Step | Reason name | Whose cause |
|---|---|---|---|---|---|---|---|
| 2547 | 2026-11-12 | 1.19.5/28.5.0.4 | – | refused | maker | `no_existing_tests` | the pull request's |
| 2543 | 2026-11-11 | 1.19.5/28.5.0.4 | feature | dropped | prepare | `needs_service:supabase_postgres` (the engine's reason: `environment`) | the factory's |
| 2555 | 2026-11-11 | 1.19.5/28.5.0.4 | feature | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2549 | 2026-11-11 | 1.19.5/28.5.0.4 | feature | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2544 | 2026-11-11 | 1.19.5/28.5.0.4 | bug fix | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2545 | 2026-11-11 | 1.19.5/28.5.0.4 | feature | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2534 | 2026-11-11 | 1.19.5/28.5.0.4 | feature | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2532 | 2026-11-10 | 1.19.5/28.5.0.4 | feature | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2526 | 2026-11-10 | 1.19.5/28.5.0.4 | feature | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2523 | 2026-11-10 | 1.19.5/28.5.0.4 | feature | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2529 | 2026-11-09 | 1.19.5/28.5.0.4 | feature | made, not checked | – | `needs_service:supabase_postgres` | the factory's |
| 2511 | 2026-11-09 | 1.19.5/28.5.0.4 | bug fix | made, not checked | – | `needs_service:supabase_postgres` | the factory's |

2547's pair is its starting commit's (the maker refused it before resolving). Of the 11 made, 9 are features and 2
bug fixes, by the maker's provisional rule; every one has a partial-fix variant, and each names between 1 and 6
existing test files.

**The gate on 2543,** twice, with the same verdict and message (`role "supabase_admin" does not exist`): the first
try built its workspace from the set-up run's build in 124.2 s before the database step failed; the second, with the
build saved, failed after 10.2 s. The first try's driver did not record a line (below), so `tasks.tsv` holds the
second.

### Time, load and disk

- **Making one folder** (the maker, the source check, the import check): 4 to 9 s of wall time each for the 11
  (`make_ms` 943 to 1,448, `verify_ms` 1,855 to 5,356).
- **A check:** not measured, since no check passed the environment step.
- **Load:** the machine ran seven jobs. The highest 1-minute load in the watcher's 299 samples (every 10 s, 13:23 to
  14:16 UTC+1) was 10.33, on 28 threads; no stop rule was reached.
- **Disk:** the job added three images ([`images.tsv`](images.tsv)): the toolchain image (908,082,459 bytes) and two
  project images (1,092,040,540 and 1,092,009,336 bytes) that are built on it, so their sizes overlap (est. 184 MB
  each of their own). The job's folders hold 203,171,704 bytes (the clone, the maker's Git cache, the records).
  The base image of the pair and the controller image were already on the machine (the controller image built
  fully from cache). Free space on `/` fell from 798,040,653,824 to 757,549,166,592 bytes over the job, most of it
  by the six other jobs.

## Files

| File | What it holds |
|---|---|
| `tasks.tsv`, `counts.tsv` | the gate's tries and their counts, written by `run/table.sh` |
| `make_only.tsv` | the bundle maker's results for the 11 made, written by `run/make_only.sh` |
| `images.tsv` | the images the job added |
| `run/` | the scripts that ran (below) |

The scripts are those of the nerves_hub_web job of the same day, with this project's names, and two fixes: `one.sh`
reads Docker's image list from a file (as one argument it passes Linux's 128 KiB limit once the machine holds many
images), and `watch.sh` stops at 50,000,000,000 free bytes and a 1-minute load above 26. `make_only.sh` is new.

| Script | What it does |
|---|---|
| `build.sh` | builds the controller image |
| `controller.sh` | starts, stops and calls one controller beside the other jobs' (own name, node name, port mapper port, data folder, labels, CPU share 256, one preparation worker) |
| `suite.sh`, `env_tests.sh`, `make_probe.sh`, `prepare.exs`, `tests.exs`, `suite_tables.sh` | the project's set-up run: a hand-made probe task at one starting commit, prepared through the controller, then the whole suite through the engine's own runner |
| `all.sh`, `one.sh`, `make_one.exs`, `row.sh`, `table.sh` | the candidates: one pull request at a time, made, imported, checked and exported, until the target count is checked |
| `make_only.sh` | the bundle maker alone for a list of pull requests |
| `watch.sh`, `state.sh` | the stop rules (free space, load, a bench run) and a snapshot of the machine |
| `docker_shim.sh` | the label and CPU share for the engine's Docker tests (copied with the set, not used here) |

## Exact commands

On the data-mining machine, with `WORK` the factory's folder, `JOB` this job's folder (`run/` these scripts, `src/`
the factory at public `772f3bd`, `realtime.git` a bare clone of the project, `tables/` the screening's census and
screen tables of this project) and `CTL` the controller's own folder:

```sh
SRC=$JOB/src OUT=$JOB/out/build IMAGE=elixir-task-factory:realtime-20261112 LABEL=task-factory=1 $JOB/run/build.sh controller
CTL=$CTL SOURCES=$JOB IMAGE=elixir-task-factory:realtime-20261112 NAME=factory-realtime \
  LABELS=task-factory=1,task-factory-job=hb-realtime HEX_CACHE_ID=etf-hex-packages-v1 EPMD_PORT=4514 \
  PREPARE_WORKERS=1 PREPARE_AHEAD=1 $JOB/run/controller.sh up

# the project's set-up at pull request 2547's starting commit
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/realtime.git NAME=factory-realtime OUT=$JOB/out/suite CTL=$CTL \
  JOB_LABEL=task-factory-job=hb-realtime TASK_LABEL=task-factory=1 ROUNDS=1 TEST_TIMEOUT=1800 SUB=env $JOB/run/suite.sh

# the candidates (numbers.txt: 2547 2543 2555 2549 2544 2545 2534 2532 2526 2523 2529 2511; OUT/hold.txt: the ten
# after 2543, which were made only)
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-realtime CACHE=<an empty folder> COPY= $JOB/run/all.sh stage
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-realtime OUT=$JOB/out/gate JOB_LABEL=task-factory-job=hb-realtime \
  TASK_LABEL=task-factory=1 TARGET=15 $JOB/run/all.sh run
CTL=$CTL NAME=factory-realtime LIST=realtime NUMBERS=<the 11 after 2547> REPOSITORY=https://github.com/supabase/realtime \
  PREFIX=realtime CENSUS=prs_supabase__realtime.tsv SCREEN=screen_supabase__realtime.tsv OUT=$JOB/out/make_only \
  $JOB/run/make_only.sh
OUT=$JOB/out/gate NUMBERS=$JOB/numbers.txt PREFIX=realtime TASKDIR=$CTL/data/realtime/tasks \
  SCREEN_TSV=$JOB/tables/screen_supabase__realtime.tsv HELD_REASON=made_only $JOB/run/table.sh tasks > tasks.tsv
$JOB/run/controller.sh stop
```

The drivers run as root: the controller writes its job records as root in folders only root can read, so a driver
run as another user waits for the job's record forever (the first try of 2543 did).

## Licence and provenance

supabase/realtime is Apache-2.0 (its `LICENSE`, and the maker's reading for all 11 made folders). The tables hold
pull request numbers, merge dates, commit ids, counts and times; no title, description or patch text. The task
folders stay on the data-mining machine and are not published.
