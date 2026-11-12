# Pilot job P3 for `podlove/radiator`: the environment recipe, one starting commit prepared, the project's tests run there

Registry row: E68 (pilot job P3 of the design note
[`task_factory_on_the_bench_engine.md`](../../research/notes/task_factory_on_the_bench_engine.md), section 9). Run on
2026-11-12 on the 7-GPU machine, CPU only, through a controller of its own started from the factory's installed image
(`elixir-task-factory:pilot`, [job P2](../2026-11-12_pilot_controller/README.md)). The same job for the first pilot
application is [`2026-11-12_pilot_env_ex338`](../2026-11-12_pilot_env_ex338/README.md); this one reuses its scripts.

**Result.** The recipe [`factory/recipes/podlove__radiator.json`](../../../factory/recipes/podlove__radiator.json)
serves radiator's newest period (Elixir 1.20.3, OTP 29.0.5, Postgres 18.6). With it the engine prepared the starting
commit of pull request 647 (`049c8f4`) cold in 292.0 s: it fetched the source, verified the source pair, built the
workspace image and the database. The project's own suite then ran twice through the engine's own test runner, each
time in a fresh container with no network: **303 of 303 tests passed in both runs**, none failed, none was excluded,
and no test changed state between the runs. The runs took 6.6 s and 5.8 s. Nothing had to be left out. Radiator has
19 candidates in the screening, and 1 of them falls in this period. 13 more (2024 to 2026) need four more images (one
recipe each; sections 1 and 6). The 5 of 2019 belong to an earlier application that also needs an S3 service, which
the engine does not have.

## Files

| File | What it holds |
|---|---|
| `periods.tsv` | the 19 radiator candidates of [`candidates_first.tsv`](../2026-11-12_pilot_pr_screen/candidates_first.tsv): period, pull request, starting commit (first parent of the merge commit), merge date, `.tool-versions`, `mise.toml`, the `elixir:` line of `mix.exs`, the Dockerfile's version arguments, the CI files and what they name |
| `tests.tsv` | each of the 303 tests of the suite at `049c8f4` (`<module>::<test name>`, as the engine's reporter names them) with its state in run 1 and run 2 |
| `images.tsv` | every image pulled, reused or built, with its size |
| `run/periods.sh` | reads the toolchain of each starting commit from a clone (step 1); adds `mise.toml` and the Dockerfile to the ex338 version |
| `run/make_probe.sh` | writes the hand-made probe task in the one format for one pull request from a clone and the recipe (step 3); unchanged from ex338 |
| `run/prepare.exs` | run in the controller: the import check, the source pair, the workspace image and the database for the probe; only the default task id differs from ex338 |
| `run/tests.exs` | run in the controller: the project's tests through `Eab.Grader.run_tests/3`, twice, each in a fresh box; only the default task id differs from ex338 |
| `run/watch_labels.sh` | records the label and CPU share of every container the engine starts; unchanged |
| `run/run_all.sh` | the whole job in order, with the exact commands; it starts its own controller (`NAME`, `EPMD_PORT`) and can run a subset of steps (`STEPS`) |

## 1. The periods

The toolchain each starting commit asks for. Radiator has no `.tool-versions` at its newest commits: since
2026-09-06 (commit `fb7863f`) its versions are in `mise.toml`, which CI's `erlef/setup-beam` reads
(`version-file: mise.toml`). CI (`.github/workflows/test.yml`) starts the service image `postgres` with no tag, so
the newest Postgres at the time of each commit, and runs `mix deps.get`, `mix compile --warnings-as-errors`,
`mix format --check-formatted`, `mix credo --strict` and `mix test`. CI installs and starts nothing else in any
period from 2024 on.

| Period | Pull requests | Elixir, OTP | `mix.exs` | The application | One recipe? |
|---|---|---|---|---|---|
| A | 647 (1) | 1.20.3, 29.0.5 (`mise.toml`; the Dockerfile builds with the same pair) | `~> 1.17` | Phoenix 1.8, LiveView 1.2, Ash 3 with AshPostgres, AshOban, AshAuthentication; test alias `ash.setup --quiet`, `test` | **this recipe; proven at 647** |
| B | 639 (1) | 1.19.5, 28.4.1 | `~> 1.18` | as A, without Oban in the supervision tree | a second recipe: only `runtime.image` differs (a 1.19.5 / OTP 28.4.1 image) |
| C | 635, 628 (2) | 1.19.2, 28.1 (`mise.toml` says `1.19.2-otp-28`; `.tool-versions` says `1.19.2-otp-27` with Erlang 28.1) | `~> 1.18` | as B | a third recipe: only `runtime.image` differs (a 1.19.2 / OTP 28.1 image) |
| D | 598, 587, 586, 583, 582, 578, 561, 550, 546 (9) | 1.17.2, 27.0.1 (`.tool-versions`) | `~> 1.15` | the 2024 application: Ecto without Ash, a `Finch` client and a GenStage command queue in the supervision tree; test alias `ecto.create --quiet`, `ecto.migrate --quiet`, `test` | a fourth recipe: a 1.17.2 / OTP 27.0.1 image, and the baseline `mix ecto.create --quiet`, `mix ecto.migrate --quiet` |
| E | 542 (1) | 1.16.3, 26.2.5 | `~> 1.15` | as D (an event producer and consumer in place of the command queue) | a fifth recipe: as D with a 1.16.3 / OTP 26.2.5 image |
| F | 240, 193, 103, 67, 16 (5) | 1.8 (Travis, pull request 16) and 1.9 (Drone CI, the others) | `~> 1.5` | the 2019 application, another code base under the same name: Phoenix 1.4, Absinthe, files stored in S3 through `arc` and `ex_aws` | **no**: Drone starts `postgres:9-alpine` and a MinIO S3 server, and runs `mix ua_inspector.download` (network) before the tests |

**The application changed twice under the same name.** The 2019 code base (period F) was replaced in 2024 by a new
Phoenix application (periods D and E, `.tool-versions` added 2024-03-26), and that one by an Ash application
initialised on 2025-09-14 (periods A to C). Nothing in periods A to E starts a service other than Postgres in the test
environment: the supervision tree holds the repository, PubSub, the endpoint (not serving in test), Oban in
`testing: :manual` mode (period A), and in-process workers. `config/test.exs` routes the feed client through
`Req.Test` and mail through `Swoosh.Adapters.Test`, so no test reaches the network.

**What else would differ in the older periods**, from the files alone (nothing was prepared):
- periods B and C: only `runtime.image`. Whether the period A image (Elixir 1.20.3) also builds their locked
  dependencies was not tried; their `mix.exs` (`~> 1.18`) admits it;
- periods D and E: the image and the baseline commands (no Ash, so `ecto.create` and `ecto.migrate`). CI used the
  newest Postgres of 2024 (16); the recipe's Postgres 18.6 is likely to serve, not verified;
- period F: the engine offers Postgres and ClickHouse only (`Eab.ServiceImages.resolve/2` refuses any other service),
  and the 2019 test configuration stores uploads in S3 on `localhost:9000`. Bringing these 5 in needs an S3 service
  in the engine and network for `ua_inspector.download`, or a test command that leaves the S3 tests out; Elixir 1.9
  is not in the engine's table of direct Hex installs either. Not done; they are left out.

## 2. The recipe, field by field

The recipe holds exactly the per-project fields of `case.json` (`factory/README.md`, section 3.2), in the layout of
the ex338 recipe. The bundle maker copies them into each task of this period.

| Field | Value | Why |
|---|---|---|
| `runtime.profile` | `mix` | fixed by the format |
| `runtime.image` | `hexpm/elixir:1.20.3-erlang-29.0.5-ubuntu-noble-20260810@sha256:f1ee5c31…` | the Elixir and OTP of `mise.toml` and the Dockerfile; the newer of the two Ubuntu builds of that pair on Docker Hub on 2026-11-12; pinned by digest |
| `runtime.environment` | `{"MIX_ENV": "test"}` | as CI; the engine adds `MIX_HOME`, `HEX_HOME` and `ERL_FLAGS` itself |
| `runtime.setup_commands` | `["mix compile"]` | compiles the project into the image, so that no test run compiles it. The engine always runs `mix deps.get` and `mix deps.loadpaths`, which fetches the Hex packages and the two Git dependencies (`daisyui` and `heroicons`, sparse checkouts from GitHub) and compiles the dependencies, the C code of `bcrypt_elixir` and `picosat_elixir` included |
| `runtime.before_test_commands` | `[]` | nothing is needed before a test run |
| `services.postgres.image` | `postgres:18.6-alpine@sha256:9ba53c7d…` | CI's untagged `postgres`, which was 18 when pull request 647 was merged; user and password `postgres`, as `config/test.exs` expects on `localhost` |
| `baseline` | `{"mode": "prepared", "commands": ["mix ash.setup --quiet"]}` | the project's own set-up of the test database, as in its `test` alias (`ash.setup --quiet`, `test`): AshPostgres creates `radiator_test` and runs its 15 migrations once; each run starts from that copy. On the prepared copy the alias's `ash.setup` only prints "Getting extensions in current project..." and "Running setup for AshPostgres.DataLayer..." |
| `test_timeout` | `240` | the bench's default; the full suite took 6.6 s and 5.8 s |
| `permitted_exclusion_tags` | `[]` | `test/test_helper.exs` excludes no tag, and no test carries a tag that ExUnit excludes by default; ex338 had `pending` |
| `grading.preservation` | `mix test` | the whole suite; the bundle maker narrows it to the files that pass on the unchanged project |
| `grading.protected_paths` | `["test/"]` | the only test folder |
| `grading.test_suffixes` | `["_test.exs"]` | fixed by the format |

No `runtime.node_image` and no `runtime.packages`: the tests need no Node, no assets and no extra system package
(`esbuild` and `tailwind` run in the dev environment only).

## 3. The preparation

The probe task (`run/make_probe.sh`) is pull request 647, "scheduling: add policies", merged 2026-10-26. Starting
commit `049c8f4e93440d3f1718e16c24739c536ca2efb4` (tree `7a058906…`), merge commit `28df799d…` (tree `5e202e44…`, a
squash merge with one parent). Its five files: `case.json` (the recipe's fields, the allowed folders `lib/` and
`test/`, the acceptance command with the two test files the pull request adds or changes, and placeholder test
names), `provenance.json`, `reference.patch` (5 files under `lib/`), `reference-tests.patch` (one new and one changed
test file) and the fixed `integrity.patch`. It is a probe: it was not imported into the candidate store and its
controls were not run.

`run/prepare.exs` did what `Eab.Candidates.qualify/3` does before the controls:

| Step | Engine part | Result | Time |
|---|---|---|---|
| import check (check 1) | `Eab.Candidates.validate!/1` | ok | under 1 s |
| source pair (check 2) | `Eab.Provenance.verify/3` | both trees fetched and matched; the three patches rebuild the merge tree exactly | 2 s |
| toolchain image | `Eab.Fixtures.ensure/3` | built (system packages 23.2 s, Hex 2.5.3 and rebar 4.9 s); no build seed existed | 46 s |
| workspace image | `Eab.Fixtures.ensure/3` | built: `mix deps.get` 14.6 s, `mix deps.loadpaths` (compiles the dependencies) 161.4 s, `mix compile` (118 files) 6.1 s | 210 s |
| database (check 3) | `Eab.Baseline.ensure/6` | Postgres started, `mix ash.setup --quiet` ran, the state checked and committed as an image; the Postgres 18.6 layout image was already there | 34 s |
| all | | **prepared** | **292.0 s** |

Hex 2.5.3, the engine's pinned version, installs and works on Elixir 1.20.3 / OTP 29. The build printed 52
compiler warnings, all in dependencies or the project's own code, none fatal (the engine does not compile with
`--warnings-as-errors`). Every container the engine started for this job carried `pascal-quants=1` and a CPU share
of 256 (from the wrapper), the Postgres containers had no network and the workspace containers shared only Postgres's
(`run/watch_labels.sh`). The image builds run inside the Docker daemon, so the wrapper's CPU share does not reach
them, as for ex338.

## 4. The project's own tests

`run/tests.exs`, in the controller: `Eab.Sandbox.with_box/4` (a fresh workspace container from the image and a fresh
Postgres from the database snapshot), `Eab.TestAdapter.install/1` (the engine's reporter), then
`Eab.Grader.run_tests(box, "mix test")`.

| Run | Return code | Finished | Tests | Passed | Failed | Excluded | Time (engine) | ExUnit's own line |
|---|---|---|---|---|---|---|---|---|
| 1 | 0 | yes | 303 | 303 | 0 | 0 | 6.6 s | `Finished in 3.1 seconds (2.7s async, 0.4s sync)`, `Result: 303 passed` |
| 2 | 0 | yes | 303 | 303 | 0 | 0 | 5.8 s | `Finished in 3.3 seconds (2.8s async, 0.4s sync)`, `Result: 303 passed` |

The 303 tests are in 33 modules; no doctests. The per-test states of the two runs are identical (`tests.tsv`). There
is no failing test to explain, and no test that needs the network or a missing service: none had to be left out, so
the recipe's test command is the plain `mix test`. The lines outside ExUnit's are the two from `ash.setup` (section 2)
and an Erlang notice that `libsctp` is missing, which nothing uses.

## 5. What it cost (planning figures, est.)

- **Cold preparation of one commit:** 292.0 s, with the base images already on the machine. 161.4 s of it compile
  the dependencies; ex338 needed 178.6 s in all. A later commit of the same period starts
  from the build seed and the database seed, so it should cost less (est.).
- **One test run of the full suite:** about 6 s, plus starting the two containers.
- **Disk:** free space on `/` was 617 GB before and 615 GB after. `docker images` sizes are shared layers: the
  workspace image 1.34 GB (of which 911 MB is the toolchain image and 263 MB the base), the database snapshot 490 MB
  (of which 433 MB is the Postgres image, already present). The engine's records under its data folder: 2.2 MB of
  build folders and 2.1 MB of source archives. About 0.7 GB of new image layers for the first commit of the period
  (est.).

## 6. What differed from ex338

- **The version file is `mise.toml`**, not `.tool-versions` (removed on 2026-09-06), so `run/periods.sh` reads it,
  and the Dockerfile's version arguments as a cross-check.
- **CI's Postgres has no tag** (`image: postgres`), so the recipe pins the version that tag meant at the time of the
  newest candidate: 18.6.
- **The baseline is `mix ash.setup --quiet`**, the project's own set-up through AshPostgres, not `ecto.create` and
  `ecto.migrate`.
- **No exclusion tag** (ex338: `pending`), two Git dependencies (`daisyui`, `heroicons`) instead of one, and two
  dependencies with C code compiled at build time.
- **Its own controller** (`NAME=factory-radiator`, its own data folder and Erlang port mapper port), because another
  job used the first controller at the same time; `run/run_all.sh` takes both from the environment.
- **The periods are short and many**: radiator moves to each new Elixir release within months and was rewritten
  twice, so its 19 candidates need six toolchains, and only 1 fits the newest. ex338's newest period held 5 of 30.

## For the next job

- **Radiator's candidates:** 1 (pull request 647) can be checked with this recipe now. 639 and 628/635 need one
  recipe each with only the image changed; the 10 of 2024 need two recipes with an older image and the Ecto
  baseline. The 5 of 2019 need an S3 service in the engine (a code job), or they are left out and counted as such.
- **The probe is not a task:** the bundle maker makes the real task for pull request 647. The prepared images are
  keyed by the source, the recipe and the environment, so a task with the same starting commit and the same recipe
  reuses them.

## Commands

On the machine with Docker, from a folder holding `run/*` and the recipe:

```sh
JOB=$PWD WORK=<a controller folder of this job's own> RUN=<folder of controller.sh and docker_shim.sh> \
NAME=factory-radiator EPMD_PORT=4456 \
CANDIDATES=<path>/candidates_first.tsv CENSUS=<path>/prs_podlove__radiator.tsv ./run_all.sh
```

The job ran it in two parts: `STEPS="periods probe"`, then `STEPS="pull prepare tests tables"`, detached with a log
and a done marker. `run_all.sh` lists each step: the clone and `periods.sh`, the pulls, `make_probe.sh` with
`NUMBER=647`, the controller's `up`, `prepare.exs` and `tests.exs` started by
`controller.sh rpc 'spawn(fn -> Code.eval_file(...) end)'` with a wait on their done markers, `down`, and the
tables. `watch_labels.sh` logs every container named `eab-*` on the machine, so its log was filtered to this job's
image ids.

## Provenance and licence

Radiator is MIT (its `LICENSE` at `049c8f4`, "Copyright (c) 2024 Podlove"). The tables hold commit ids, toolchain
versions and the project's test names. They hold no source code. The images were pulled from Docker Hub
(`hexpm/elixir`, `postgres`).
