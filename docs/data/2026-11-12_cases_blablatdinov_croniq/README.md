# blablatdinov/croniq: the project's set-up in the task factory, and its checked cases (2026-11-12)

Registry row [E68](../../../experiments.md) (the pilot of the task factory). `blablatdinov/croniq` is one of the
dataset's 16 applications ([rules](../../dataset_rules.md)). This job wrote the project's recipe, ran the project's
whole test suite once through the engine, and makes and checks its candidates one at a time, newest merged first,
through a controller built from this repository's `main` at `60b1a65`, on the data-mining machine (28 threads, 30 GiB,
no GPU), while other task-making jobs and one job that uses the model share the machine. Times are the data-mining
machine's (UTC+1).

## Result so far (milestone 1, 18:35)

- **The project has 23 candidates on Elixir 1.18 or newer, and no more.** Its whole history holds 24 candidates, all
  merged between 2025-06-14 and 2025-07-28 (the screening's list,
  [2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)); the 24th, 21, names Elixir 1.14
  and is left out as `elixir_before_1.18`. Of the 147 pull requests merged since 2025-07-29, 139 are a bot's dependency
  updates and the 8 others change no test or only `mix.exs`/`mix.lock` (the screen's `no_code_change`,
  `no_test_change`, `mix_files`).
- **The database versions:** every candidate's CI file starts Postgres 17.5, and the 8 newest also Redis 8 (72: Redis
  6). The factory's image table holds Postgres 10, 14 and 18 and Redis 7.2, so the toolchain resolver refuses all 23
  (`no_service_image:postgres/17.5`, `resolve.tsv`). Under the rules' section 2 ("The database and the cache") the
  cases are built and checked on the newest versions the table has, Postgres 18.6 and Redis 7.2, set in the recipe;
  both versions are recorded per candidate (`versions.tsv`).
- **The whole suite runs** at the newest candidate's starting commit (pull request 90), on Elixir 1.18.4 with OTP
  26.2.5.21, Postgres 18.6 and Redis 7.2: ExUnit's summary **183 tests, 0 failures, 4 skipped, in 1.3 s**; the 4
  skipped tests carry the project's own skip tag. Prepared cold in 165.2 s.
- **The cases:** checking runs; this section is replaced by the result when the list ends.

## 1. The project's set-up

The recipe is [`factory/recipes/blablatdinov__croniq.json`](../../../factory/recipes/blablatdinov__croniq.json). It
is a fixed recipe, not a template: the resolver reads Postgres 17.5 from every candidate's CI file and refuses it, so
the recipe names the image and the services itself. The image is the one the resolver gives every candidate's own
files (`resolve.tsv`), so the Elixir and OTP are still each commit's own.

| What | Value | Where it comes from |
|---|---|---|
| Elixir and OTP | 1.18.4 and 26.2.5.21 (`hexpm/elixir:1.18.4-erlang-26.2.5.21-ubuntu-noble-20260810`, pinned by digest) | every candidate's CI workflow (`elixir-version: '1.18'`, `otp-version: '26'`), matched by the image table's newest 1.18 line with OTP 26; the project has no `.tool-versions` at these commits, and its `mix.exs` asks for `~> 1.14` |
| Database | Postgres 18.6 (`postgres:18.6-alpine`, pinned by digest) | the CI workflow starts `postgres:17.5`; the table has no Postgres 17, so its newest line is used (rules, section 2) |
| Redis | Redis 7.2 (`redis:7.2-alpine`, pinned by digest), for every candidate | the CI workflow of the 8 newest starts `redis:8` (72: `redis:6`) and their `mix.exs` depends on `redix`; the table has only 7.2. The 15 older candidates neither start Redis nor depend on a Redis client; a fixed recipe gives every task the same services, so Redis runs beside them unused |
| System package | `postgresql-client` (Ubuntu's `psql`) | for the first database command below |
| Database commands | create the role `almazilaletdinov` when it is missing (`psql` as the engine's `postgres` user), `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the project's `config/test.exs` logs in as `almazilaletdinov` with an empty password at `localhost`; the engine's Postgres trusts connections from inside its own network, so the role only has to exist. The command is safe to repeat, because the engine runs the commands again on a saved database of an older commit |
| Build | `mix compile` after the engine's own dependency steps | the bench's default recipe |
| Whole-suite command | `mix test` | the CI workflow's test job |
| Excluded tags | none | the project's `test_helper.exs` excludes nothing |

The CI's lint job downloads a release of `editorconfig-checker` from GitHub (the screening's `release_file` mark on 12
candidates); it is not part of the tests and is not used.

## 2. The project's own suite

A hand-made probe task for pull request 90 (`run/make_probe.sh`, with its own id and a 900-second limit for one test
command) was prepared through the controller (`run/prepare.exs`) in 165.2 s cold (the engine's own step 163.3 s: the
toolchain image with `postgresql-client`, the workspace image, the Postgres database with the role and the
migrations), and the whole suite ran once through the engine's own runner (`run/tests.exs`), in a fresh workspace
container with a fresh database and no network. `project_tests.tsv`:

| Run | ExUnit tests | Passed | Failed | Skipped | Excluded | ExUnit time | Engine time | Return code | Output | Engine: finished |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 183 | 179 | 0 | 4 | 0 | 1.3 s | 2.4 s | 0 | 26,171 bytes | yes (183 records, all distinct) |

The engine marks the run not passed only because of the 4 skipped tests (the grader passes a run when every test
passed or was excluded by a permitted tag). The 4 are `CroniqWeb.TasksAPIControllerTest` "Tasks list pagination",
"Task edit without \"name\" field" and "Task edit invalid cron", and `CroniqWeb.APIAuthControllerTest` "Remove
token". A case whose hidden tests include one of them is dropped at the probe as `skipped_test`.

## Files

| File | What it holds |
|---|---|
| `resolve.tsv` | the toolchain resolver's line for each of the 23 candidates with the factory's own table: the Elixir and OTP each commit names and where, the image, the refusal (`no_service_image:postgres/17.5` for all) |
| `versions.tsv` | per candidate: the Elixir and OTP named and the image used; the Postgres and Redis its CI file starts, its Redis client, and the versions used |
| `kinds.tsv` | the screening's 24 candidates in order: merge date, starting and merge commits, the screening's marks, and the kind read ahead by the maker's rule, with the files and public functions the fix adds |
| `project_tests.tsv` | the whole-suite run: the engine's verdict and counts, ExUnit's summary, the output's size |
| `run/` | the scripts that ran |

## Licence

The tables hold pull request numbers, dates, commits, version pairs, reason names, test names, file paths of the
project, times and byte counts; no code, title, body or patch text of the project. croniq is under the MIT licence
(its `LICENSE` file, added 2025-07-28).
