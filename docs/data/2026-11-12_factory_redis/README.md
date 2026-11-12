# Factory job E71: a Redis service in the engine

Registry row E71; `factory/README.md` section 6, change 9. The pilot showed why: `axelclark/ex338` before 2024-03-07
starts a Redis client (`Redix`, to `redis://localhost:6379`) for its session cache in every environment, tests
included, so 18 of its first 30 candidate pull requests could not be prepared
([pilot data](../2026-11-12_pilot_env_ex338/README.md)); three more applications of the approved batch name a Redis
client. A task may now list `redis` in `services`. A task that does not gets exactly the containers, `docker run`
arguments and removals it got before: the parity test passes untouched.

## What changed

- **The task.** `"services": {"redis": {"image": "<name>[:<tag>]@sha256:<64 hex digits>"}}`, beside `postgres` and
  `clickhouse` or alone. `Eab.TaskContract.services!/1`, part of the import check, refuses a `redis` entry in any
  other form (a missing digest, an upper-case or short digest, extra fields such as a command, a bare string). The
  entries for Postgres and ClickHouse are checked as before, when the engine resolves them.
- **The container** (`lib/eab/sandbox.ex`, `start/2`). Started as `<workspace>-redis`, after Postgres and ClickHouse
  and before the workspace:
  `docker run -d --name <workspace>-redis --network=<…> --memory=1g --cpus=1 --tmpfs=/data:rw,nosuid,size=64m`
  `<the two labels> <the installation's labels and CPU share> <image> redis-server --save "" --appendonly no`,
  then `redis-cli -h 127.0.0.1 ping` until it answers `PONG` (60 s at most). The limits are Postgres's (1 GB, 1 CPU).
- **The network.** No network of its own. With Postgres it joins Postgres's private network
  (`--network=container:<workspace>-db`), as ClickHouse and the workspace do. Alone, it holds the private network
  (`--network=none`) and the workspace joins it (`--network=container:<workspace>-redis`). The workspace reaches it
  as it reaches Postgres: on its own loopback, at `127.0.0.1:6379`.
- **No data between containers.** Saving is off (`--save ""`, `--appendonly no`) and `/data`, the image's volume, is
  a tmpfs, so nothing is mounted and nothing is written to disk. Every container of a task, in each grading step and
  each attempt, starts with an empty Redis.
- **Removal.** `docker rm -f -v <workspace>-redis` with the workspace, after ClickHouse and before Postgres. A task
  without Redis keeps the bench's three removals.
- **The database baseline** (`lib/eab/baseline.ex`, `lib/eab/fixtures.ex`). `ServiceImages.databases/1` (Postgres,
  ClickHouse) are prepared and captured as before; `ServiceImages.ephemeral/1` (Redis) runs beside them during the
  bootstrap commands, which may boot an application that needs it, and goes into the prepared runtime as resolved.
  The baseline's key leaves Redis out, so the same project with and without Redis shares one baseline. A task with
  Redis alone has no database baseline, like a task without services. `lib/eab/service_images.ex` is part of that
  key, so every database baseline is prepared once more after this update, as after T7.
- **Tests.** `task_contract_test` (1 new: 4 valid entries, 4 tasks without Redis, 9 refused forms), new
  `redis_service_test.exs` (6: the arguments with Redis beside Postgres, alone, and with all three; none for a task
  without it; the installation's labels and share on Redis; the baseline), new `redis_service_docker_test.exs` (1,
  below). `bench_parity_test.exs` is untouched.

**The Docker test.** A made-up task, `tally-pr-3`: counters kept in Redis by a project whose code speaks the Redis
protocol over a plain socket to `127.0.0.1:6379`, and whose existing and hidden tests talk to it. The bug: `add/2`
sends `INCR` and ignores the amount. Its workspace image is built from the tooling image. The gate's controls run
twice, with Redis alone and with Redis beside Postgres (`postgres:16-alpine`): the unchanged project fails the hidden
test in its body, the reference passes, the early exit is refused, and the controls hold in the second round; another
correct fix with its own test passes, the reference without a test does not. With no services the same task does not
qualify, because its tests cannot reach Redis. Then two workspaces one after the other: a key set in the first is not
in the second (`DBSIZE` 0), `CONFIG GET save` is empty, `appendonly` is `no`, the Redis container has no mount, a
64 MB tmpfs on `/data`, Postgres's network, 1 GB and 1 CPU, the run's label and the CPU share, and it is gone after
its workspace.

## Files

| File | What it holds |
|---|---|
| `README.md` | this page |
| `tests_compared_t10.tsv` | one line per test: its state in T10's two runs (`t10e`, the newest on `main` when the final checks ran) and in E71's final two runs (`e71e`), and the verdict (`same`, `differs`, `gone: …`, `new`) |
| `tests_compared_e72.tsv` | the same against E72's two runs (`e72r`) |
| `tests_compared_t9.tsv` | the same against T9's two runs (`t9c`) |
| `tests_compared.tsv` | the same against T8's two runs (`t8`), the newest on `main` when this job started |
| `run/checks.sh` | the format check, the tests and the Docker tests in a row, with free space before and after |

The code is in `factory/`, this repository's licence; the tables are made from the test runs. The Redis image is
the official one, used in the Docker test only and not redistributed.

## The image

`redis:7.2-alpine`, Redis 7.2.17, pinned as
`redis:7.2-alpine@sha256:2f66de68111e64c3927859f158f8e666066dae2b97d9f82770a6f37a5aa1c335`: 16,037,250 bytes by
`docker image inspect` (57.6 MB by `docker images`). It is the one download of this job, pulled once before the
Docker test.

## Commands (on the build machine, in the work folder with `src/` and `run/`)

```
docker pull redis:7.2-alpine
export WORK=$PWD LABEL=pascal-quants=1
run/checks.sh e71e
run/compare.sh t10e_unit t10e_docker e71e_unit e71e_docker > tests_compared_t10.tsv
run/compare.sh e72r_unit e72r_docker e71e_unit e71e_docker > tests_compared_e72.tsv
run/compare.sh t9c_unit t9c_docker e71e_unit e71e_docker > tests_compared_t9.tsv
run/compare.sh t8_unit t8_docker e71e_unit e71e_docker > tests_compared.tsv
```

`test.sh`, `docker_shim.sh`, `t0_formatter.exs` and `compare.sh` are the earlier jobs'
([T0](../2026-11-12_factory_t0/README.md), [T4](../2026-11-12_factory_t4/)); `checks.sh` is new. Every step runs
`mix test --warnings-as-errors`.

## Counts

| | T8 (`t8`) | T9 (`t9c`) | E72 (`e72r`) | T10 (`t10e`) | E71 (`e71e`, pushed) |
|---|---|---|---|---|---|
| format check | passes | passes | passes | passes | passes |
| without Docker: passed, failed, excluded | 198, 0, 8 | 205, 0, 9 | 223, 0, 9 | 224, 0, 9 | 231, 0, 10 |
| with `EAB_DOCKER_TESTS=1` | 206, 0, 0 | 214, 0, 0 | 232, 0, 0 | 233, 0, 0 | 241, 0, 0 |

T8 was the newest reference on `main` when this job started; T9, E72 and T10 landed while it ran, and the job was
rebased onto each before running the checks again. `tests_compared_t10.tsv` (242 lines with the header): 233 tests end
as in T10, none differs, none is gone; 8 are new and pass, all this job's (1 in `task_contract_test`, 6 in
`redis_service_test`, 1 in `redis_service_docker_test`, excluded without Docker). Against E72: 232 the same, 9 new
(and T10's 1); against T9: 214 the same, 27 new (and E72's 18); against T8: 206 the same, 35 new (and T9's 8). `bench_parity_test` passes 6 of 6 in both
runs and is not in this job's diff.

**Earlier runs.** `e71a`, before the rebases: format passes; 203 of 205 passed without Docker and 212 of 214 with it.
The 2 failures were mistakes in `redis_service_test` itself (the run id `redis-run` matched the search for "redis",
and the network was read from the wrong position of the workspace's arguments), fixed before the next run; the Docker
test passed. `e71b`, on T9's tree: 212, 0, 10 without Docker; with Docker 221 of 222: `docker_settings_docker_test`
failed with "No such image" because another job's checks ran the same test on the same machine at the same time, and
each run removes the database layout images it sees as new, which carry the same tags in both; the other job's run
failed the same test the same way. Its Docker step run again alone (`e71c`): 222, 0, 0. `e71d`, on E72's tree: 230, 0, 10
and 240, 0, 0.

Free space on the build machine's `/`: 637,215,784,960 bytes before (04:55:27), 624,343,609,344 after (05:58:09),
with other jobs running at the same time. No container of this job is left; the Redis image stays on the machine for
the tasks that will name it.
