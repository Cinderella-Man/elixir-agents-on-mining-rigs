# The bundle maker resolves the toolchain per starting commit (2026-11-12)

Registry row [E72](../../../experiments.md). The pilot's first tasks showed that one hand-written recipe per project
serves only one period of the project's history: job P3's recipe for ex338 fits 5 of its first 30 candidates and
radiator's 1 of 19, because the projects change their Elixir, OTP and database every few months
([ex338](../2026-11-12_pilot_env_ex338/README.md), [radiator](../2026-11-12_pilot_env_radiator/README.md), each with
a periods table). Now the bundle maker reads the environment of each task from the starting commit's own files
([factory README](../../../factory/README.md), section 3.5, "The toolchain resolver"). Everything ran on the CPU of
the 7-GPU machine on 2026-11-12, between 04:30 and 05:02 (UTC+1), while other jobs used the same Docker daemon.

## The rule

For a starting commit, in this order, each step recorded in the task's `provenance.json` under `toolchain` with the
file it came from:

1. **Elixir and OTP,** each from the first file that names it: `.tool-versions`, `mise.toml` or `.mise.toml`, the CI
   files (GitHub workflows, `.travis.yml`, `.drone.yml`, `.gitlab-ci.yml`), a `Dockerfile`, and last the lower bound
   of `mix.exs`'s `elixir:` requirement.
2. **The image:** [`factory/config/toolchain_images.json`](../../../factory/config/toolchain_images.json) maps a pair to
   one `hexpm/elixir` image pinned by digest. A pair it lacks is refused, `no_image:<elixir>/<otp>`.
   [`factory/scripts/toolchain_image.sh`](../../../factory/scripts/toolchain_image.sh) looks a pair up at Docker Hub and
   prints the line to add; the maker never runs it.
3. **The database:** the Postgres or ClickHouse version the CI files start, pinned by the same table; the template's
   default when they name none. `no_service_image:<service>/<version>` when the table lacks it.
4. **The baseline commands:** the template's first candidate whose condition holds (radiator: `mix ash.setup --quiet`
   when `mix.exs` uses `ash.setup` in an alias, otherwise `mix ecto.create --quiet` and `mix ecto.migrate --quiet`).
5. **Services the engine lacks:** a Redis client in `mix.exs`, or a CI service other than Postgres and ClickHouse that
   the template does not mark as not needed, is refused, `needs_service:<name>`.

The two recipes became templates: they keep their fields, which are now the defaults, and gain a `toolchain` block.
ex338's marks the CI files' Redis as not needed, with the reason: from 2024-03 on the CI still starts Redis, but the
application connects to it only while `mix.exs` depends on `redix`, which the resolver refuses. The nerves_hub_web
recipe has no block and is used as before. The task format did not change.

## Result

**The four proofs pass.** Through a controller built from this change, with the resolver and no period recipe, six
pull requests from five periods other than the recipes' own were made, passed the source check and the import
check, were prepared, and had their hidden tests run on the unchanged project and on the reference. Five became
checked tasks; radiator-pr-598 was dropped by the probe for its own reason (both of its existing test files fail
on the reference, `no_existing_tests`), after its environment was prepared and its hidden tests ran.

| Pull request | Period | Resolved | Baseline | Hidden tests, start | Hidden tests, reference | Verdict |
|---|---|---|---|---|---|---|
| ex338 #1350 | 5 | 1.17.2 / 27.0.1, Postgres 14 | create, migrate | 1 failed | 1 passed | checked |
| ex338 #1331 | 4b | 1.16.1 / 26.2.1, Postgres 14 | create, migrate | 3 failed, 54 passed | 57 passed | checked |
| ex338 #1313 | 4b | 1.16.1 / 26.2.1, Postgres 14 | create, migrate | 2 failed, 8 passed | 10 passed | checked |
| radiator #639 | B | 1.19.5 / 28.4.1, Postgres 18.6 (default) | `ash.setup` | 14 failed, 27 passed | 41 passed | checked |
| radiator #598 | D | 1.17.2 / 27.0.1, Postgres 18.6 (default) | create, migrate | 1 failed, 128 passed | 129 passed | dropped by the probe: `no_existing_tests` |
| radiator #542 | E | 1.16.3 / 26.2.5, Postgres 18.6 (default) | create, migrate | 3 failed, 48 passed | 51 passed | checked |

The proofs for the brief: (a) ex338 periods 5 (#1350) and 4b (#1331, #1313); (b) radiator periods B (#639, 2026)
and E (#542, 2024), with #598 (D, 2024) as a third environment proved without a task. Every checked task passed the
controls with a partial fix and the strict second round. Each run's times are in `proofs.tsv`. In all, the six took 381.1, 403.5, 408.3, 439.4, 168.0 and
296.6 s (in the table's order), of which preparing took 232.7, 212.9, 222.9, 291.3, 105.9 and 172.4 s, since every
starting commit built its own workspace image.

**How many candidates the resolver serves.** By the two periods tables (job P3's 30 ex338 and 19 radiator
candidates), and over every screened candidate of the two projects (`resolve` on all 305 and 105):

| Project | Candidates | Resolved | `needs_service:redis` | `no_image` (Elixir older than 1.12) | Other | Before (one recipe) |
|---|---:|---:|---:|---:|---:|---|
| ex338, periods table | 30 | 12 | 9 | 9 (`1.10.3/22.3.4.1`) | 0 | 5, most likely 6 |
| radiator, periods table | 19 | 14 | 0 | 5 (`1.8.1/-` 3, `1.8/-` 1, `1.5/-` 1) | 0 | 1 |
| ex338, all screened | 305 | 31 | 26 | 247 | 1 (`paths_never_match`) | - |
| radiator, all screened | 105 | 64 | 0 | 41 | 0 | - |

Apart from one pull request whose source pair the maker does not find (`paths_never_match`, the maker's own refusal,
before any resolving), every refusal is one of two kinds: the engine has no Redis service (E71), or the commit's
Elixir is older than 1.12,
which the engine's pinned Hex 2.5.3 cannot install (README section 2.1). The `no_image` reasons by pair are in
`candidates_counts.tsv`. With the first table of 9 pairs (the pairs of the periods tables), radiator's full list
resolved 48 of 105; 16 more needed five pairs the periods tables do not show (1.16.2/26.0.2, 1.15.7/26.0.2,
1.18.2/27.2, 1.18.1/27.2, 1.17.1/26.2.5). Those five were looked up with the script, read and added, which gave the
table of 14 pairs and the 64. No ex338 count changed between the two tables.

**The pairs** (`pairs.tsv`): the table holds 14 pairs, the oldest 1.13.4/25.0 and the newest 1.20.3/29.0.5; the script reproduced the
two pins of the recipes byte for byte. The engine cannot build any pair with Elixir older than 1.12, so none is in
the table: 1.10.3/22.3.4.1 (ex338 period 1; the image exists), 1.11.x, 1.9 and older.

## The factory change

- `lib/eab/toolchain.ex` (new, `Eab.Toolchain`): pure, it takes the commit's files as a map, the template and the
  table, and returns the resolved `runtime`, `services`, `baseline` and the record, or the refusal.
- `lib/eab/bundle_maker.ex`: a recipe with a `toolchain` block is resolved from the starting commit after the
  maker's own checks; the record goes into `provenance.json`; the result line has a new last column `toolchain`
  (`<elixir>/<otp>`, or `recipe`); `resolve_one/2`, `resolve_list/2` and the script mode `resolve` run the source pair
  and the resolver without making a task; `--toolchain-table`.
- `config/toolchain_images.json` (new), `scripts/toolchain_image.sh` (new), the `toolchain` blocks in
  `recipes/axelclark__ex338.json` and `recipes/podlove__radiator.json`.
- Tests: `test/eab/toolchain_test.exs` (17 tests on made-up trees: one per source of versions, the database, the
  baseline, one per refusal, the table and the templates) and one new test in `test/eab/bundle_maker_test.exs` (a
  template on a made-up repository: the resolved manifest and provenance, the `resolve` line, a Redis refusal, a
  `no_image` refusal, and a plain recipe used as it is).

**Tests, against the newest reference** (`origin/main` before this change, run on the same machine the same hour;
`tests_compared.tsv`): format check passes; without Docker 207 passed, 0 failed, 5 excluded (reference 189, 0, 5);
with Docker 212 passed, 0 failed (reference 193 passed, 1 failed). 193 tests end as in the reference, 18 are new and
pass. The one that differs is `baseline_docker_test` "clean snapshots preserve both database families", which failed
in the reference run with "No such image" while another job's Docker tests ran on the same daemon; run alone on the
reference tree it passed (1 of 1). The parity test passed 6 of 6 and was not edited; no file of README section 2
changed.

**After the rebase onto jobs T7, T8 and T9** (they landed while this job ran; none touched the maker's files), the
checks ran again on the rebased tree and on the new reference, `origin/main` at T9 (`tests_compared_rebased.tsv`):
format check passes; without Docker 223 passed, 0 failed, 9 excluded (reference 205, 0, 9); with Docker 232 passed,
0 failed (reference 213 passed, 1 failed). 213 tests end as in the reference and the same 18 are new and pass. The
one that differs is T7's `docker_settings_docker_test`, which failed in the reference run and once more alone with
"No such image" while another job's tooling container ran, then passed alone on both trees. The proofs ran on the
tree before the rebase.

## Disk

Free on `/`: 646,170,750,976 bytes at 04:26 (before), 635,947,851,776 at 05:02 (after), with other jobs running.
The images pulled and built are in `images.tsv`: four `hexpm/elixir` bases (79,832,725, 80,719,740, 82,981,729 and 80,772,729 bytes by
`docker image inspect`), four toolchain images (two shared by two tasks each), six workspace images, six database
images and the controller.

## Files

| File | What it holds |
|---|---|
| `proofs.tsv` | the six proof pull requests: period, resolved versions, baseline, hidden-test counts, verdict, partial fix, second round, times |
| `periods_resolved.tsv` | job P3's two periods tables, row by row, with the resolver's result, reason, pair, image tag, Postgres and baseline |
| `resolve_ex338.tsv`, `resolve_radiator.tsv` | the `resolve` line of every screened candidate (14-pair table): versions and their sources, image, database, baseline, CI services, Redis clients, refusal detail |
| `candidates_counts.tsv` | the two lists counted by result and reason |
| `pairs.tsv` | every pair seen, whether the engine can build it, whether it is in the table, and which proof used it |
| `images.tsv` | the images pulled and built |
| `tests_compared.tsv` | each test of the reference and of this change, with and without Docker |
| `tests_compared_rebased.tsv` | the same after the rebase onto T7, T8 and T9 |
| `run/` | the scripts that ran (below) |

## Exact commands

On the build machine, in a work folder `JOB_ROOT` that holds `src/` (the factory folder of this commit, with Mix's
`.local/` copied from an earlier job), `tables/` (the census and screen tables of
[the census](../2026-11-11_pilot_pr_census/README.md) and [the screen](../2026-11-12_pilot_pr_screen/README.md); the
radiator census table from job P3) and `run/` (this folder's scripts, with job T0's `test.sh`, `checks.sh`,
`compare.sh`, `t0_formatter.exs` and `docker_shim.sh` from [T0](../2026-11-12_factory_t0/README.md)):

```sh
# the tests: the reference tree (src/ at origin/main before this change), then this change in src/
WORK=$JOB_ROOT LABEL=pascal-quants=1 run/checks.sh base
WORK=$JOB_ROOT LABEL=pascal-quants=1 run/checks.sh e72
SRC=$REFERENCE_TREE WORK=$JOB_ROOT LABEL=pascal-quants=1 TAG=base_rerun run/test.sh docker test/eab/baseline_docker_test.exs
WORK=$JOB_ROOT run/compare.sh base_unit base_docker e72_unit e72_docker > tests_compared.tsv
# the controller, built from this change, with an empty task folder
SRC=$JOB_ROOT/src IMAGE=elixir-task-factory:e72 WORK=$CTL run/controller.sh build
WORK=$CTL NAME=factory-e72 IMAGE=elixir-task-factory:e72 EPMD_PORT=4472 run/controller.sh up
# numbers.txt: ex338-all and radiator-all every screened candidate; ex338 "1350 1331 1313"; radiator "639 598 542"
JOB_ROOT=$JOB_ROOT WORK=$CTL NAME=factory-e72 P5_CONCURRENCY=3 run/proofs.sh
WORK=$CTL NAME=factory-e72 run/controller.sh down
# a line for the image table
factory/scripts/toolchain_image.sh elixir 1.17.2 27.0.1
factory/scripts/toolchain_image.sh postgres 14
```

`proofs.sh` stages each list (`run.sh stage`: the template, the image table, the hold-out list, the tables and the
scripts into the controller's data), runs `resolve.exs` for the two full lists, then `make.exs` (made, source check,
import check) and `gate.exs` (prepare, the hidden tests on both sides, the probe, the gate and the second round, as
job P5's [gate.exs](../2026-11-12_pilot_tasks_ex338_r2/run/gate.exs)) for the proof lists. In this run the two full
lists were resolved first with the 9-pair table and again, after the five pairs were added, with the 14-pair table;
the tables here are from the second run.

## Provenance and licence

The pull requests and their code are axelclark/ex338's and podlove/radiator's (MIT, as the tasks' `licence` field
reads it); the tables here hold only their numbers, commit ids and the versions read from their files. The image
digests are Docker Hub's.
