# Pilot job P3 for `axelclark/ex338`: the environment recipe, one starting commit prepared, the project's tests run there

Registry row: E68 (pilot job P3 of the design note
[`task_factory_on_the_bench_engine.md`](../../research/notes/task_factory_on_the_bench_engine.md), section 9). Run on
2026-11-12 on the 7-GPU machine, CPU only, through the factory's installed controller (`elixir-task-factory:pilot`,
[job P2](../2026-11-12_pilot_controller/README.md)), with the factory at public commit `aecd139`.

**Result.** The recipe [`factory/recipes/axelclark__ex338.json`](../../../factory/recipes/axelclark__ex338.json)
serves ex338's newest period (Elixir 1.18.3, OTP 27.3, Postgres 14). With it the engine prepared the starting
commit of pull request 1460 (`a502f92`) cold in 178.6 s: it fetched the source, verified the source pair, built the
workspace image and the database. The project's own suite then ran twice through the engine's own test runner, each
time in a fresh container with no network: **1,087 of 1,087 tests passed in both runs**, none failed, none was
excluded, and no test changed state between the runs. Each run took 10.2 s and 10.0 s. Nothing had to be left out.
5 of the first 30 candidates fall in this period. 7 more need at most two more recipes (1 most likely this one, 6 a
second one with an older image; sections 1 and 6), and 18 need a Redis service, which the engine does not have.

## Files

| File | What it holds |
|---|---|
| `periods.tsv` | the first 30 ex338 candidates of [`candidates_first.tsv`](../2026-11-12_pilot_pr_screen/candidates_first.tsv): period, whether the application starts a Redis client, pull request, starting commit (first parent of the merge commit), merge date, `.tool-versions`, the `elixir:` line of `mix.exs`, the CI files, and the Elixir, OTP, Postgres and other services they name |
| `tests.tsv` | each of the 1,087 tests of the suite at `a502f92` (`<module>::<test name>`, as the engine's reporter names them) with its state in run 1 and run 2 |
| `images.tsv` | every image pulled or built, with its size |
| `run/periods.sh` | reads the toolchain of each starting commit from a clone (step 1) |
| `run/make_probe.sh` | writes the hand-made probe task in the one format for one pull request from a clone and the recipe (step 3) |
| `run/prepare.exs` | run in the controller: the import check, the source pair, the workspace image and the database for the probe |
| `run/tests.exs` | run in the controller: the project's tests through `Eab.Grader.run_tests/3`, twice, each in a fresh box |
| `run/watch_labels.sh` | records the label and CPU share of every container the engine starts |
| `run/run_all.sh` | the whole job in order, with the exact commands |

## 1. The periods

The toolchain each starting commit asks for, from `.tool-versions`, `mix.exs` and the CI file. In every period CI
starts Postgres and runs `mix ecto.create`, `mix ecto.migrate` and `mix test`, with `MIX_ENV=test`. Up to and
including pull request 1392 CI also names Redis.

| Period | Pull requests (of the first 30) | Elixir, OTP | Postgres in CI | Redis in the application | One recipe? |
|---|---|---|---|---|---|
| 6 | 1460, 1458, 1457, 1452, 1392 (5) | 1.18.3, 27.3 (`.tool-versions` also names Node 22.14.0) | 14 | no | **this recipe; proven at 1460** |
| 5 | 1350 (1) | 1.17.2, 27.0.1; `mix.exs` asks `~> 1.17` | 14 | no | likely this recipe (same OTP major, `~> 1.17` admits 1.18.3); not prepared |
| 4b | 1331, 1313, 1302, 1300, 1288, 1284 (6) | 1.16.1, 26.2.1; `~> 1.14` | 14 | no | a second recipe: a 1.16.1 / OTP 26.2.1 image, the rest unchanged |
| 4a | 1252 (1) | 1.16.1, 26.2.1 | 14 | **yes** | needs Redis |
| 3 | 1208, 1177 (2) | 1.14.4, 25.3.2 | 14 | **yes** | needs Redis |
| 2 | 1168, 1129, 1119, 1108, 1093, 1086 (6) | 1.13.4, 25.0 | 10 | **yes** | needs Redis |
| 1 | 981, 980, 976, 959, 957, 933, 914, 911, 841 (9) | 1.10.3, 22.3.4.1 | 10 | **yes** | needs Redis |

**Redis.** Until commit `4a6144f` (2024-03-07, "Replace pow with mix phx.auth") the application's supervision tree
starts a `Redix` connection to `redis://localhost:6379` in every environment, the test environment included, for
Pow's session cache (`cache_store_backend: Ex338Web.Pow.RedisCache`). The engine offers Postgres and ClickHouse
only (`Eab.ServiceImages.resolve/2` refuses any other service). So the 18 starting commits before that date (periods
1 to 4a) cannot be prepared as they are. Bringing them in needs a change to the engine: a `redis` service, started
beside Postgres in its network namespace the way ClickHouse is. That is outside this job, so these commits are left
out. After that commit Redis is used only by `Phoenix.PubSub.Redis` outside the test environment.

**What else would differ in the older periods**, from the files alone (nothing was prepared):
- period 4b: only `runtime.image` (a `hexpm/elixir:1.16.1-erlang-26.2.1-…` image pinned by digest);
- periods 1 and 2: Postgres 10 in CI. Elixir 1.13 is in the engine's table of direct Hex installs
  (`Eab.Fixtures`, `@hex_builds`), and 1.10 is not, so on 1.10 `mix local.hex 2.5.3` is used, which Mix before
  1.14 ignores. Whether a Hex for Elixir 1.10 then installs is not verified.

## 2. The recipe, field by field

The recipe holds exactly the per-project fields of `case.json` (`factory/README.md`, section 3.2). The bundle maker
copies them into each task of this period, beside the fields that come from the pull request.

| Field | Value | Why |
|---|---|---|
| `runtime.profile` | `mix` | fixed by the format |
| `runtime.image` | `hexpm/elixir:1.18.3-erlang-27.3-ubuntu-noble-20260509.1@sha256:05d0223e…` | the Elixir and OTP of `.tool-versions` and CI; the newest Ubuntu build of that pair on 2026-11-12; pinned by digest |
| `runtime.environment` | `{"MIX_ENV": "test"}` | as CI; the engine adds `MIX_HOME`, `HEX_HOME` and `ERL_FLAGS` itself |
| `runtime.setup_commands` | `["mix compile"]` | compiles the project into the image, so that no test run compiles it. The engine always runs `mix deps.get` and `mix deps.loadpaths`, which fetches the Hex packages and the one Git dependency (`heroicons`, from GitHub) and compiles the dependencies |
| `runtime.before_test_commands` | `[]` | nothing is needed before a test run |
| `services.postgres.image` | `postgres:14.24-alpine@sha256:928ce526…` | CI's `postgres:14`; user and password `postgres`, as `config/test.exs` expects on `localhost` |
| `baseline` | `{"mode": "prepared", "commands": ["mix ecto.create --quiet", "mix ecto.migrate --quiet"]}` | builds `ex338_test` and its 106 migrations once; each run starts from that copy. The project's `test` alias also runs `ecto.create` and `ecto.migrate`; on the prepared copy they do nothing ("Migrations already up") |
| `test_timeout` | `240` | the bench's default; the full suite took 10.2 s and 10.0 s. The probe ran with 600, which changed nothing |
| `permitted_exclusion_tags` | `["pending"]` | `test/test_helper.exs` excludes `pending: true`. No test at `a502f92` carries it; a later commit's tagged test is counted as excluded, not failed |
| `grading.preservation` | `mix test` | the whole suite; the bundle maker narrows it to the files that pass on the unchanged project |
| `grading.protected_paths` | `["test/"]` | the only test folder |
| `grading.test_suffixes` | `["_test.exs"]` | fixed by the format |

No `runtime.node_image` and no `runtime.packages`: the tests need no Node, no assets and no extra system package
(the assets are built by `esbuild` and `tailwind` in the dev environment only).

## 3. The preparation

The probe task (`run/make_probe.sh`) is pull request 1460, "Let teams edit draft queues and autodraft over MCP",
merged 2026-08-02. Starting commit `a502f92e38a4b6286e6db51d7771c10899cf635c` (tree `739c8006…`), merge commit
`4a4825e1…` (tree `b31f8ea6…`, a squash merge with one parent). Its five files: `case.json` (the recipe's fields, the
pull request's allowed folders `lib/` and `test/`, the acceptance command with the one test file it adds, and
placeholder test names), `provenance.json`, `reference.patch` (5 files under `lib/`), `reference-tests.patch` (one
new test file) and the fixed `integrity.patch`. It is a probe: it was not imported into the candidate store and its
controls were not run.

`run/prepare.exs` did what `Eab.Candidates.qualify/3` does before the controls:

| Step | Engine part | Result | Time |
|---|---|---|---|
| import check (check 1) | `Eab.Candidates.validate!/1` | ok | under 1 s |
| source pair (check 2) | `Eab.Provenance.verify/3` | both trees fetched and matched; the three patches rebuild the merge tree exactly | 2 s |
| toolchain image | `Eab.Fixtures.ensure/3` | built; no build seed existed | 44 s |
| workspace image | `Eab.Fixtures.ensure/3` | built: `mix deps.get` 6.3 s, `mix deps.loadpaths` (compiles the dependencies) 71.0 s, `mix compile` 7.5 s | 105 s |
| database (check 3) | `Eab.Baseline.ensure/6` | Postgres started, `ecto.create` and `ecto.migrate` ran, the state checked and committed as an image | 27 s |
| all | | **prepared** | **178.6 s** |

Every container the engine started carried `pascal-quants=1` and a CPU share of 256 (from the wrapper), the Postgres
container had no network and the workspace container shared only Postgres's (`run/watch_labels.sh`). The image
builds run inside the Docker daemon (`docker buildx build`), so the wrapper's CPU share does not reach them.

## 4. The project's own tests

`run/tests.exs`, in the controller: `Eab.Sandbox.with_box/4` (a fresh workspace container from the image and a fresh
Postgres from the database snapshot), `Eab.TestAdapter.install/1` (the engine's reporter), then
`Eab.Grader.run_tests(box, "mix test")`. The engine runs `elixir -r /opt/eab-grade/formatter.exs -S mix test --seed 0
--formatter ExUnit.CLIFormatter --formatter ElixirAgentBenchmark.TrustedFormatter` with the task's time limit.

| Run | Return code | Finished | Tests | Passed | Failed | Excluded | Time (engine) | ExUnit's own line |
|---|---|---|---|---|---|---|---|---|
| 1 | 0 | yes | 1,087 | 1,087 | 0 | 0 | 10.2 s | `Finished in 9.0 seconds (6.2s async, 2.8s sync)`, `1087 tests, 0 failures` |
| 2 | 0 | yes | 1,087 | 1,087 | 0 | 0 | 10.0 s | `1087 tests, 0 failures` |

The 1,087 tests are in 125 modules; no doctests. The per-test states of the two runs are identical (`tests.tsv`).
There is no failing test to explain, and no test that needs the network or a missing service: none had to be left
out, so the recipe's test command is the plain `mix test`. The only lines outside ExUnit's are Ecto's
"Migrations already up" and `os_mon` closing its ports at the end.

## 5. What it cost (planning figures, est.)

- **Cold preparation of one commit:** 178.6 s, with the base images already pulled (10 s and 4 s). A later commit of
  the same period starts from the build seed and the database seed, so it should cost less (est.); job P5 measures it.
- **One test run of the full suite:** about 10 s, plus starting the two containers (about 2 s per run, est., from
  the timestamps).
- **Disk:** free space on `/` was 620 GB before and 617 GB after. `docker images` sizes are shared layers: the
  workspace image 1.06 GB (of which 904 MB is the toolchain image and 256 MB the base), the database snapshot 476 MB
  (of which 415 MB is the Postgres image). The engine's own records under its data folder: 5.8 MB of build folders
  and 7.3 MB of source archives. About 1.5 GB of images in all (est.) for the first commit of the period.

## 6. For the next job and the next application

- **ex338's first 30 candidates:** 5 can be checked with this recipe now (period 6). Pull request 1350 most likely
  can too. Periods 4b (6 pull requests) need a second recipe with a 1.16.1 / OTP 26.2.1 image. The 18 before
  2024-03-07 need a Redis service in the engine (a code job), or they are left out and counted as such.
- **The probe is not a task:** P5 makes the real task for pull request 1460 with the bundle maker. The prepared images
  are keyed by the source, the recipe and the environment, so a task with the same starting commit and the same
  recipe reuses them.
- **For the next application:** read the supervision tree in `lib/<app>/application.ex` for the services it starts in
  every environment (here an old Redis client). Look for Git dependencies (here `heroicons` from GitHub, fetched at
  build time with the network on). Check whether `test/test_helper.exs` excludes tags. And see whether the `test`
  alias runs `ecto.create` and `ecto.migrate`; on a prepared database these do nothing.

## Commands

On the machine with Docker, from a folder holding `run/*` and the recipe:

```sh
JOB=$PWD WORK=<controller folder> RUN=<folder of controller.sh and docker_shim.sh> \
CANDIDATES=<path>/candidates_first.tsv CENSUS=<path>/prs_axelclark__ex338.tsv ./run_all.sh
```

`run_all.sh` lists each step: the clone and `periods.sh`, the two pulls, `make_probe.sh` with `NUMBER=1460`, the
controller's `up`, `prepare.exs` and `tests.exs` started by `controller.sh rpc 'spawn(fn -> Code.eval_file(...) end)'`
with a wait on their done markers, `down`, and the tables. `watch_labels.sh` logs every container named `eab-*` on
the machine, so its log was filtered to this job's image ids.

## Provenance and licence

ex338 is MIT (its `LICENSE` at `a502f92`). The tables hold commit ids, toolchain versions and the project's test
names. They hold no source code. The images were pulled from Docker Hub (`hexpm/elixir`, `postgres`).
