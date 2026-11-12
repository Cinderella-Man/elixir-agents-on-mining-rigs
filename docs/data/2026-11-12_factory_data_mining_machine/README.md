# The task factory set up on the data-mining machine, and one task checked there

Registry row E76. On 2026-11-12 every task-factory job moved to a dedicated data-mining machine with no GPU: an
Intel Core i7-14700 (28 threads), 30 GiB of memory, one 935 GB disk, Docker 29.9.2 with BuildKit v0.34.0 in its
default builder. The owner's Elixir SWE Bench also runs on that Docker (its controller was up throughout, with no
bench run). This job built the factory's two images there, ran the factory's tests, started a controller and checked
one task that had already been checked on the 7-GPU machine.

**Result:** `radiator-pr-500` checked, with the same result as before: 88 of 90 compared items are equal, and the two
that differ are the hashes of the grading code and of the rebuilt images, which had to change (below). The factory's
tests: 240 passed, 0 failed, 10 excluded without Docker, and 250 passed, 0 failed with it. Two names the factory
shared with the bench were set apart first, by two new switches (factory README, section 6, change 10); the parity
test, 6 of 6, is untouched.

## What was shared with the bench, and what was done

The full list, every name checked against the machine: [collisions.md](collisions.md). Two were shared:

- **The BuildKit cache id `eab-hex-packages-v1`** (Hex packages, in the workspace recipe's two `mix deps.get`
  lines). The bench's cache mount with that id was in the machine's builder (55.19 MB, used 53 times). New switch
  `EAB_HEX_CACHE_ID`, default the bench's id; the controller and the Docker tests ran with `etf-hex-packages-v1`.
  After the check the factory's own cache mount held 3.326 MB.
- **The tooling image tag `eab-tooling:dev`,** which nine Docker test files named as their base. New test switch
  `EAB_TOOLING_IMAGE`, default the bench's tag; the tests ran on `etf-tooling:20261112`.

One more collided with the defaults and was avoided by an existing switch: Erlang's port mapper. The bench's listens
on 0.0.0.0:4369; the controller's ran on 127.0.0.1:4510 and [::1]:4510, its node `factory_hb@127.0.0.1` on a
loopback port. The builder's garbage collection is shared by nature; with its policy and the machine's free space it
could not evict the bench's entries (collisions.md, last row).

## The check

The task: the first id in sort order among the 27 checked radiator tasks, which needs Postgres and no other service.
Imported and checked through `bin/factoryctl` (`import`, `check`, `job`) in the controller `factory-hb`, one task at
a time.

| Step | Data-mining machine | 7-GPU machine (pilot gate, E72) |
|---|---|---|
| Verdict | `checked` | `checked` |
| Source fetch | 2.2 s (`source_ms` 2,198) | — |
| Preparation (project image, database baseline) | 87.1 s (`prepare_ms` 87,128) | 209.6 s (`prepare_ms` 209,595) |
| Probe (hidden and existing tests, partial fix) | 26.6 s (`probe_ms` 26,604) | 55.3 s (`probe_ms` 55,323) |
| Controls with the second round | 48.6 s (`controls_ms` 48,605) | 112.2 s gate plus 101.3 s second round (`gate_ms` 112,233, `second_ms` 101,251) |
| Whole check | 164.9 s (`total_ms` 164,854; 165 s by the wall clock) | 508.4 s (`total_ms` 508,429) |

The two columns are one run each. The 7-GPU machine's run was the pilot's gate script, with other jobs on that
machine at the same hour; the factory's `check` runs the same sequence (section 9 of the factory README). The import
took under a second.

The comparison, item by item: [comparison.tsv](comparison.tsv) (lists of test names by their SHA-256). Equal:
- the verdict and the probe (`ok`);
- the hidden tests: 1 fails on the unchanged project and 10 pass with the reference, the same names
  (`grading.starting_failures` and `grading.required` of `case.json`);
- the existing tests command (`mix test test/radiator/outline_test.exs`), none left out, the partial control
  present;
- every control (reference, unchanged project, partial repair, early exit): passed or not, and for the hidden tests,
  the regression step and the submission, completed, passed, exit code, every test's state by name and every failing
  test with its phase;
- the second round: the same outcomes, no test changed, the unchanged project not passing and the reference passing;
- the six task files, byte for byte after the check.

Different, as they must be: `identity.grader` (the grading code's hash; the factory's code has changed since that check, from
job T10 to change 10) and `identity.runtime` (the project image, the
Postgres snapshot and the database baseline's ids, rebuilt on this machine from a recipe whose text now holds
`etf-hex-packages-v1`).

Every container the engine started for the check carried `task-factory=1` and `--cpu-shares 256` (sampled every
10 s, `check_containers.tsv` in the private record), the Postgres containers with `--network=none` and the workspace
in their network namespace, as in the bench. Peak 1-minute load during the check: 1.80.

## The tests

In the tooling image, as the user 1000:1000 with two CPUs; the Docker step with no network in the test container,
the Docker socket, `docker_shim.sh` adding the label and the share to each `docker run`.

| Step | Result | Time |
|---|---|---|
| `mix format --check-formatted` | passes (first run: one missing blank line in `build_seed_docker_test.exs`, fixed) | 1 s |
| without Docker | 240 passed, 0 failed, 10 excluded | 33.6 s in ExUnit |
| with Docker, first run | 248 passed, 2 failed | 334.1 s |
| with Docker, after the bases below were present | 250 passed, 0 failed | 386.0 s |

Against the last recorded counts, test by test (236 passed without Docker after the Redis maker change; 241 with
Docker in the last settled Docker run, job E72's, before the Redis maker and the step times): every test ends as before; the new ones pass (3 for change 10 in
`docker_settings_test`, 1 for the step times in `factory_test`, 5 for the Redis maker in `toolchain_test` and
`bundle_maker_test`). `bench_parity_test`: 6 of 6.

The two failures of the first Docker run were the machine's, not the code's: `baseline_docker_test` and
`docker_settings_docker_test` build `FROM postgres:16-alpine` and the ClickHouse tags `24.12.2.29-alpine` and
`25.11.5.8-alpine`, which the 7-GPU machine held and this one did not. BuildKit fetches a registry token through the
client that starts the build; that client runs in the test container, which has no network by design, so the build
failed at `load metadata` with "network is unreachable" on the DNS lookup of `auth.docker.io`. The tests did not change. `postgres:16-alpine` arrived during the run
(the Redis Docker test starts it with `docker run`, which the daemon pulls); the other three were pulled on the host
before the second run.

## Images and time

| Step | Wall time | Peak 1-minute load |
|---|---|---|
| tooling image `etf-tooling:20261112` (every step cached: the bench's builds had left the same layers) | 26 s | 0.78 |
| tests: deps, format, without Docker | 39 s | 1.27 |
| tests with Docker, first run | 335 s | 5.03 |
| base pulls before the second run | 6 s | 1.40 |
| tests with Docker, second run | 386 s | 4.30 |
| controller image `elixir-task-factory:hb-20261112` | 34 s | 2.23 |
| controller start until it answers `rpc` | 2 s | — |
| import and check of `radiator-pr-500` | 165 s | 1.80 |

Peak over the whole job: 5.03 (28 threads). Free bytes on `/`: 852,627,361,792 at the start, 846,604,267,520 at the
end (6,023,094,272 used); the lowest sample 846,604,247,040.

What the job added to Docker, by `docker image inspect` size (layers are shared, so the sizes do not add up; Docker
counted its images at 33.57 GB before and 37.47 GB after, the build cache at 42.53 GB and 45.6 GB):

| Image | Size (bytes) | Made by |
|---|---|---|
| `etf-tooling:20261112` | 1,598,669,266 | this job (tests) |
| `elixir-task-factory:hb-20261112` | 771,589,185 | this job (controller) |
| `elixir-task-factory:toolchain-radiator-pr-500` and `:toolchain-3f47fdbe…` (one image) | 897,380,686 | the engine |
| `elixir-task-factory:project-84addfe4…` and `:seed-e95aacf9…` (one image) | 953,036,169 | the engine |
| `elixir-task-factory:layout-e418e414…` | 432,794,036 | the engine (Postgres layout) |
| `elixir-task-factory:snapshot-92ca65cf…-postgres` | 489,163,481 | the engine (database baseline) |
| `hexpm/elixir@sha256:917eb211…` (untagged) | 249,520,615 | pulled by the engine (the task's base) |
| `postgres:18-alpine` (`sha256:9ba53c7d…`, also the task's Postgres pin) | 432,777,476 | pulled for the tests |
| `postgres:16-alpine` | 419,078,352 | pulled by the Redis Docker test |
| `redis@sha256:2f66de68…` (untagged) | 57,068,957 | pulled by the Redis Docker test |
| tags `clickhouse/clickhouse-server:24.12.2.29-alpine` and `:25.11.5.8-alpine` | 717,308,925 and 923,454,394 | pulled for the tests; both images were already on the machine, untagged, so only the tags are new |

The controller's image build fetched `ubuntu:24.04` into the builder's cache; no tag was left. No volume or network
was created. The controller `factory-hb` is stopped and kept, with its data folder (5,118,556 bytes, holding the
checked task and the made-up task of proof c).

## The controller's three proofs

The same three proofs as pilot job P2 (`run/proofs.sh`), on a fresh data folder:
- (a) it answers; `Eab.Inventory.all()` is `[]`, and `factoryctl status` shows no job, run or preparation;
- (b) `System.find_executable("docker")` is `/usr/bin/docker`: since T7 there is no wrapper in front of `docker`;
  the engine adds `["--label", "task-factory=1", "--cpu-shares", "256"]` to each `docker run` and
  `["--label", "task-factory=1"]` to each build, and `Eab.DockerSettings.hex_cache_id()` is `"etf-hex-packages-v1"`;
- (c) `factoryctl import` of the made-up task `ledgerette-pr-1` (from `factory/test/support/tasks/`) answers
  `imported`, and the inventory then holds it.

The controller's container: label `task-factory=1`, `cpu_shares` 256, host network, no published port; mounts of the
data folder (also at `/data`, the image's volume, so Docker makes no anonymous volume), its own task folder, the
folder of checked tasks (read only, imports only) and the Docker socket, each host path at the same path inside.

## Commands

From the editing machine:

```bash
CLIENT=<ssh destination> SSH_OPTS=<extra ssh options> WORK=<factory work folder> run/sync.sh
```

On the data-mining machine (`J=$WORK/jobs/setup`, the scripts in `$J/run`):

```bash
run/state.sh > out/state_0_before.txt
STOP=$J/out/watch.stop run/watch.sh > out/watch.tsv &
SRC=$WORK/src OUT=$J/out LABEL=task-factory=1 TOOLING_IMAGE=etf-tooling:20261112 run/build.sh tooling
export SRC=$WORK/src OUT=$J/out IMAGE=etf-tooling:20261112 LABEL=task-factory=1 HEX_CACHE_ID=etf-hex-packages-v1
run/test.sh deps; run/test.sh format; run/test.sh unit; run/test.sh docker
docker pull postgres:18-alpine
docker pull clickhouse/clickhouse-server:24.12.2.29-alpine
docker pull clickhouse/clickhouse-server:25.11.5.8-alpine
TAG=format2 run/test.sh format; TAG=docker2 run/test.sh docker
SRC=$WORK/src OUT=$J/out LABEL=task-factory=1 IMAGE=elixir-task-factory:hb-20261112 run/build.sh controller
export CTL=$WORK/ctl-hb SOURCES=$WORK/tasks IMAGE=elixir-task-factory:hb-20261112 NAME=factory-hb \
  LABEL=task-factory=1 HEX_CACHE_ID=etf-hex-packages-v1 SRC=$WORK/src
run/controller.sh up
run/proofs.sh
TASK_DIR=$WORK/tasks/podlove__radiator/radiator-pr-500 OUT=$J/out/check run/check_one.sh
ROW=<the earlier gate's row.json> OLD_CONTROLS=<the earlier controller's controls/radiator-pr-500.json> \
  RESULT=$CTL/data/factory/jobs/<job>/results/radiator-pr-500.json NEW_CONTROLS=$CTL/data/controls/radiator-pr-500.json \
  BEFORE=$WORK/tasks/podlove__radiator/radiator-pr-500 AFTER=$CTL/tasks/radiator-pr-500 run/compare.sh > comparison.tsv
run/controller.sh stop
```

Two scripts were corrected during the job and the corrected versions are the ones here: `proofs.sh` (its last
inventory line read ids as maps; the controller was then started again on a fresh data folder and all proofs run
again) and `check_one.sh` (`import` takes a folder of task folders, so the one task is copied into one first; the
first attempt imported nothing and `check` refused the id). `controller.sh stop` needed no label after a fix.

## Files

| File | What it is |
|---|---|
| [collisions.md](collisions.md) | every name the factory uses, checked against the machine |
| [comparison.tsv](comparison.tsv) | the check against the earlier one, 90 items, test-name lists by SHA-256 |
| `run/sync.sh` | copies `factory/` and `run/` to the machine |
| `run/state.sh` | a read-only snapshot: load, free space, containers, images with sizes, volumes, networks, build cache, sockets |
| `run/watch.sh` | samples the load, free bytes and memory every 10 s |
| `run/build.sh` | builds the tooling image or the controller's image with the machine's own Buildx |
| `run/test.sh`, `run/docker_shim.sh`, `run/t0_formatter.exs` | the factory's tests in the tooling image (job T0's, with the image, the label and the two switches passed in) |
| `run/controller.sh` | `up`, `rpc`, `stop`, `start` of a controller beside a bench |
| `run/proofs.sh` | the three proofs |
| `run/check_one.sh` | imports and checks one task through `bin/factoryctl` |
| `run/compare.sh` | the item-by-item comparison |

Provenance: the task is `podlove/radiator` pull request 500 (MIT licence), made and first checked by the pilot (E68,
E72); the factory's code is public `main` plus change 10. No model was run.
