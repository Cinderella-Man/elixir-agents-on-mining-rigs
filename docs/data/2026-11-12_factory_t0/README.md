# The task factory's starting point: the tooling image and the tests of the unchanged copy (2026-11-12)

Job T0 of the [task factory](../../../factory/README.md) (section 7), for registry row [E68](../../../experiments.md).
The tooling image was built from `factory/Dockerfile`, and the bench's own checks ran on the copy of the bench's engine
as it was copied (bench commit `28c064ca`), with no change to it. Then two tests were added to `factory/test/eab/`:
`bench_parity_test.exs`, which holds what the model sees and what a pass means to the bench's values, and
`model_identity_test.exs`, a new test of `lib/eab/model_identity.ex` with made-up values. Everything ran on the CPU of
the 7-GPU machine, in Docker 29.1.3, on 2026-11-12 between 00:54 and 01:14 (UTC+1).

## Result

- **The tooling image builds** from the unchanged `Dockerfile` (`--target tooling`) in 61 seconds: Elixir 1.20.2 on
  Erlang/OTP 29, Ubuntu 24.04.4, Docker 29.1.3 and Buildx 0.30.1 inside, no `python3`.
- **The format check passes** on the unchanged copy, and again with the two new files.
- **The tests of the unchanged copy:** 48 test files, 284 tests.

  | Run | Passed | Failed | Excluded |
  |---|---:|---:|---:|
  | `MIX_ENV=test mix test --warnings-as-errors` | 212 | 65 | 7 |
  | the same with `EAB_DOCKER_TESTS=1` and the Docker socket | 217 | 65 | 2 |

  The 65 failures are the same tests in both runs. **Every one fails for one of two reasons, and none for any other:**
  48 need the bench's cases, which are never copied here, and 17 read a file of the bench that was not copied
  (`results-page/index.html` 16, `scripts/install-claude-code-kit.sh` 1).

  | Test files | Files | Pass in full | Fail | Not run |
  |---|---:|---:|---:|---:|
  | that stay (section 5.6: keep 18, change 16) | 34 | 27 | 7 | 0 |
  | that are dropped (section 5.6) | 14 | 8 | 4 | 2 |
  | all | 48 | 35 | 11 | 2 |

  The seven files that stay and fail all fail only because they need the bench's cases, 40 tests in all:
  `candidates_test` 3, `checkpoints_test` 10, `fixtures_test` 5, `grader_test` 1, `readiness_test` 8,
  `runner_test` 1, `runs_test` 12. The section's list of seven names six of them and `dashboard_test`, which is
  dropped; `grader_test` is the one it does not name (its test "all retained PR reference patches satisfy edit rules
  and have partial controls" needs a non-empty case inventory).
- **Both new tests pass** on the unchanged copy: `bench_parity_test` 6 of 6 and `model_identity_test` 8 of 8, with
  and without `EAB_DOCKER_TESTS=1`. With them the runs give 226 passed, 65 failed, 7 excluded, and 231 passed, 65
  failed, 2 excluded.
- **The parity test catches a change.** On a scratch copy with six one-line changes (one byte added to
  `priv/pi/bridge.mjs`; "Dependencies are prepared." made "Dependencies are ready." in `lib/eab/agent.ex`; `--memory=4g`
  made `--memory=5g` in `lib/eab/sandbox.ex`; one `chown` changed in `lib/eab/fixtures.ex`; Pi's idle timeout changed in
  `lib/eab/pi.ex`; the token budget made 65,535 in `config/benchmark.json`), all 6 of its tests failed. The scratch copy
  was then deleted.

Two tests did not run in any run:
- `browser_docker_test` was left out of the Docker run by this job (`--exclude module:Elixir.Eab.BrowserDockerTest`):
  it builds from the Playwright image and installs Playwright from npm, downloads that this job was not allowed. The
  test is dropped with the browser support (section 5.1).
- `claude_code_hook_test` is excluded by the copy's own test helper when `python3` is missing, as it is in the tooling
  image. It is dropped with the Claude Code harness.

**The Docker tests do not pull their database images.** The bench's command runs the test container with
`--network none`. In the first Docker run, `baseline_docker_test` failed: BuildKit could not fetch a registry token
for `postgres:16-alpine` from inside that container. With `postgres:16-alpine`, `postgres:18-alpine`,
`clickhouse/clickhouse-server:24.12.2.29-alpine` and `clickhouse/clickhouse-server:25.11.5.8-alpine` pulled first, it
passed; the tables above are from that second run. The tests that build `FROM eab-tooling:dev`, an image that is
already there, passed in both runs.

`mix deps.get` reports open security advisories for `bandit` 1.12.5, which `mix.lock` pins. Bandit is the web server
of the page that job T1 drops.

## Files

| File | What it holds |
|---|---|
| [tests_per_file.tsv](tests_per_file.tsv) | One row per test file: its verdict in section 5.6, tests, passed, failed and excluded in both runs of the unchanged copy, the outcome and the cause of its failures. The two new files are the last rows, with the counts from the runs with them. |
| [tests_per_test.tsv](tests_per_test.tsv) | One row per test (298): its state in the run without Docker, in the run with Docker, and in the Docker run with the two new tests; the cause of a failure. Later jobs compare their runs against it. |
| [run/sync.sh](run/sync.sh) | Copies `factory/` to the build machine. |
| [run/build_tooling.sh](run/build_tooling.sh) | Builds the tooling image through a Docker client image with Buildx, for a machine whose `docker` has none. |
| [run/test.sh](run/test.sh) | The bench's checks in the tooling image: `deps`, `format`, `unit`, `docker`, and `capture`. |
| [run/docker_shim.sh](run/docker_shim.sh) | Put ahead of `docker` in the test container: adds the machine's label and a CPU share to every container the tests start. |
| [run/t0_formatter.exs](run/t0_formatter.exs) | An ExUnit formatter added beside the engine's own: one line per test with its state and reason. |
| [run/parity_capture.exs](run/parity_capture.exs) | Prints the values the parity test pins, from the code it runs in. |
| [run/table.sh](run/table.sh), [run/per_test.sh](run/per_test.sh) | The two tables, from the per-test lines. |

## Exact commands

On the editing machine, after each edit of `factory/`:

```bash
HOST=<build machine> WORK=<work folder> docs/data/2026-11-12_factory_t0/run/sync.sh
```

On the build machine, in `WORK`, with `LABEL=<key>=<value>` for every container started (`CPU_SHARES` is 256):

```bash
docker pull docker:cli
WORK=$PWD LABEL=$LABEL run/build_tooling.sh
WORK=$PWD LABEL=$LABEL run/test.sh deps
WORK=$PWD LABEL=$LABEL run/test.sh format
WORK=$PWD LABEL=$LABEL TAG=unit_copy run/test.sh unit
for i in postgres:16-alpine postgres:18-alpine clickhouse/clickhouse-server:24.12.2.29-alpine clickhouse/clickhouse-server:25.11.5.8-alpine; do docker pull -q $i; done
WORK=$PWD LABEL=$LABEL TAG=docker_copy2 run/test.sh docker --exclude module:Elixir.Eab.BrowserDockerTest
WORK=$PWD LABEL=$LABEL run/test.sh capture
```

The steps run, inside the image, exactly the bench's commands (its `docs/runbook.md`, "Bounded correctness checks"):
`mix deps.get`, `mix format --check-formatted`, and `MIX_ENV=test mix test --warnings-as-errors`, the last started as
`elixir -r t0_formatter.exs -S mix test ...` with the extra formatter. The test container runs as `1000:1000` with
`--cpus=2`, `HOME=/tmp` and `HEX_HOME=/tmp/hex`; the Docker run adds `--network none`, the socket's group, the socket
and `EAB_DOCKER_TESTS=1`. The format check and the tests run as two steps, so that a failing format check would not hide
the tests.

The two new files were formatted with the project's own settings, then checked and tested:

```bash
docker run --rm --label $LABEL --cpu-shares 256 --cpus=2 --user 1000:1000 -e HOME=/tmp -e HEX_HOME=/tmp/hex \
  -v $PWD/src:/app -w /app eab-tooling:dev mix format test/eab/bench_parity_test.exs test/eab/model_identity_test.exs
WORK=$PWD LABEL=$LABEL TAG=format_t0 run/test.sh format
WORK=$PWD LABEL=$LABEL TAG=unit_t0 run/test.sh unit
WORK=$PWD LABEL=$LABEL TAG=docker_t0 run/test.sh docker --exclude module:Elixir.Eab.BrowserDockerTest
WORK=$PWD run/table.sh unit_copy docker_copy2
WORK=$PWD run/per_test.sh unit_copy docker_copy2 docker_t0 > tests_per_test.tsv
```

The parity check on a scratch copy: `cp -a src mut`, the six edits listed above with `sed` and `printf`, then
`WORK=$PWD SRC=$PWD/mut LABEL=$LABEL TAG=mutation run/test.sh unit test/eab/bench_parity_test.exs`, then `rm -rf mut`.

## Images and disk

| Image | How | Content size (bytes, `docker image inspect`) | On disk (`docker images`) |
|---|---|---:|---:|
| `eab-tooling:dev` (`sha256:e2042995…`) | built | 403,541,195 | 1.6 GB |
| `docker:cli` (`sha256:2357639a…`) | pulled | 67,832,842 | 243 MB |
| `postgres:16-alpine` | pulled | 116,087,053 | 420 MB |
| `postgres:18-alpine` | pulled | 120,090,937 | 433 MB |
| `clickhouse/clickhouse-server:24.12.2.29-alpine` | pulled | 154,860,102 | 717 MB |
| `clickhouse/clickhouse-server:25.11.5.8-alpine` | pulled | 202,768,899 | 923 MB |

The build pulled the two base images by digest (`node@sha256:d6aa754f…`, `hexpm/elixir@sha256:73e79b5a…`) into
the builder's cache; they are not listed as images. The builder's cache went from 0 B to 2.925 GB. Free space on `/`,
which holds Docker's data: 672,835,543,040 bytes before, 666,552,070,144 after. The test runs removed every image and
container they made.

## Provenance and licence

The code under test is the bench's engine as copied into `factory/` (see its README, section 1, for the licence
question). The two new test files and the scripts here are this repository's. The tables hold only test names, states
and causes.
