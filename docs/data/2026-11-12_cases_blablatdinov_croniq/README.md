# blablatdinov/croniq: the project's set-up in the task factory, and its checked cases (2026-11-12)

Registry row [E68](../../../experiments.md) (the pilot of the task factory). `blablatdinov/croniq` is one of the
dataset's 16 applications ([rules](../../dataset_rules.md)). This job wrote the project's recipe, ran the project's
whole test suite once through the engine, and made and checked all its candidates one at a time, newest merged first,
through a controller built from this repository's `main` at `60b1a65`, on the data-mining machine (28 threads, 30 GiB,
no GPU), while other task-making jobs and one job that uses the model shared the machine. Times are the data-mining
machine's (UTC+1).

## Result

- **9 cases count: 3 features and 6 bug fixes**, of the project's 23 candidates on Elixir 1.18 or newer, all tried
  (`checked.tsv`). Each is checked by the engine and passes the hold-out check, and every file each one touches
  passes the licence scan's per-file check. The list ends here: the project has no further candidate.
- **The project has 23 candidates on Elixir 1.18 or newer, and no more.** Its whole history holds 24 candidates, all
  merged between 2025-06-14 and 2025-07-28 (the screening's list,
  [2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)); the 24th, 21, names Elixir
  1.14 and is left out as `elixir_before_1.18`. Of the 147 pull requests merged since 2025-07-29, 139 are a bot's
  dependency updates and the 8 others change no test or only `mix.exs`/`mix.lock` (the screen's `no_code_change`,
  `no_test_change`, `mix_files`).
- **Left out: 14, all the pull requests' own causes** (`counts.tsv`): 6 at the probe as `skipped_test`, 4 at the
  probe as `no_starting_failure`, 3 at the probe as `no_existing_tests`, 1 refused by the maker as
  `no_existing_tests`. None was the machine's or the factory's, and none points to the database or Redis version.
  Every check that ran while the machine's 1-minute load reached 12 was run again once it was lower, with the same
  verdict each time (section 3).
- **The database versions** (rules, section 2, "The database and the cache"): every candidate's CI file starts
  Postgres 17.5, and the 8 newest also Redis 8 (72: Redis 6). The factory's image table holds Postgres 10, 14 and 18
  and Redis 7.2, so the toolchain resolver refuses all 23 (`no_service_image:postgres/17.5`, `resolve.tsv`). The
  cases are built and checked on the newest versions the table has, Postgres 18.6 and Redis 7.2, set in the recipe;
  both versions are recorded per candidate (`versions.tsv`). No download was needed.
- **The licence** (rules, section 9): 90 passes the licence scan on the project's licence file, 88 and 86 on its
  README statement. The other 6 (75, 65, 53, 52, 47, 31) start before the project stated any licence, so the scan
  fails them for "no licence" at that commit only; they count under the rule for a case older than the project's
  licence: the README states MIT from 2025-07-13 (`README.md` line 162, commit `e3fa91e17ef5`), the licence file
  exists from 2025-07-28 (commit `11b9133be517`, "Copyright (c) 2025 Almaz Ilaletdinov"), both still at the project's
  newest commit (copyright line "2025-2026"), and every commit that touched any of their files up to each merge is
  the licence holder's own (`licence_proof.tsv`, `licence_authors.tsv`).
- **The whole suite runs** at the newest candidate's starting commit (pull request 90), on Elixir 1.18.4 with OTP
  26.2.5.21, Postgres 18.6 and Redis 7.2: ExUnit's summary **183 tests, 0 failures, 4 skipped, in 1.3 s**; the 4
  skipped tests carry the project's own skip tag. Prepared cold in 165.2 s.
- **A check took 210 s at the median** (the 9 checked cases' first checks, 131 s to 301 s; a drop took 41 s to 160 s);
  making a case took 5 s to 10 s. The whole run, 23 candidates and 17 second checks, took 70 min (18:04:52 to
  19:14:49).

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

## 3. The candidates

All 23, newest merged first, from the screening's list, one at a time: made with the bundle maker through the
controller (`run/make_one.exs`), imported with `factoryctl import`, checked with `factoryctl check --concurrency 1`,
and a checked case exported to the factory's task folder (`run/one.sh`, driven by `run/all.sh`). A check is settled
when the 1-minute load stayed under 12 during it. After the list, `run/all.sh` checked once more every candidate whose
first check was not settled (try 2). `tasks_croniq.tsv` has one line per try with every column; the engine's step
times are in seconds.

| Pull request | Merged | Kind (case.json) | Verdict | Step | Reason | Check, try 1 (prepare / probe / controls) | Load start → end (highest), try 1 | Try 2 |
|---|---|---|---|---|---|---|---|---|
| 90 | 2025-07-28 | feature | **checked** | - | - | 210 s (73.9 / 44.4 / 86.6) | 7.57 → 8.79 (8.98) | - |
| 88 | 2025-07-27 | feature | **checked** | - | - | 290 s (104.3 / 89.9 / 86.8) | 8.79 → 11.42 (11.6) | - |
| 86 | 2025-07-26 | feature | **checked** | - | - | 210 s (23.3 / 48.9 / 132.0) | 11.79 → 13.48 (16.4) | checked, not settled (14.3) |
| 58 | 2025-07-23 | bug fix | dropped | probe | `no_existing_tests` | 150 s (86.1 / 60.2 / -) | 13.48 → 14.93 (17.05) | the same, not settled (12.06) |
| 83 | 2025-07-23 | bug fix | dropped | probe | `skipped_test` | 41 s (21.4 / 14.7 / -) | 14.93 → 14.22 (14.47) | the same, settled |
| 75 | 2025-07-12 | bug fix | **checked** | - | - | 230 s (60.2 / 74.4 / 92.3) | 14.28 → 12.92 (15.55) | checked, settled |
| 74 | 2025-07-12 | feature | dropped | probe | `skipped_test` | 60 s (33.6 / 16.8 / -) | 12.92 → 13.22 (12.95) | the same, settled |
| 72 | 2025-07-10 | feature | dropped | probe | `skipped_test` | 51 s (33.6 / 14.9 / -) | 13.22 → 13.73 (13.49) | the same, settled |
| 66 | 2025-07-05 | feature | dropped | probe | `no_starting_failure` | 121 s (96.2 / 15.0 / -) | 13.73 → 11.50 (12.78) | the same, settled |
| 65 | 2025-07-04 | bug fix | **checked** | - | - | 171 s (16.3 / 54.2 / 93.9) | 11.50 → 10.35 (11.17) | - |
| 53 | 2025-06-29 | bug fix | **checked** | - | - | 220 s (100.7 / 49.2 / 60.9) | 10.35 → 14.55 (15.02) | checked, settled |
| 52 | 2025-06-29 | bug fix | **checked** | - | - | 131 s (15.6 / 34.3 / 74.9) | 15.38 → 12.85 (15.11) | checked, settled |
| 49 | 2025-06-29 | feature | dropped | probe | `no_existing_tests` | 160 s (95.7 / 54.5 / -) | 12.85 → 9.85 (13.38) | the same, settled |
| 50 | 2025-06-29 | feature | dropped | probe | `no_starting_failure` | 60 s (37.4 / 16.3 / -) | 11.46 → 10.88 (12.8) | the same, settled |
| 48 | 2025-06-29 | bug fix | dropped | probe | `no_existing_tests` | 100 s (21.7 / 70.9 / -) | 12.97 → 11.55 (14.13) | the same, settled |
| 47 | 2025-06-28 | bug fix | **checked** | - | - | 180 s (19.7 / 62.7 / 95.4) | 12.31 → 10.84 (12.27) | checked, settled |
| 46 | 2025-06-27 | feature | dropped | probe | `skipped_test` | 80 s (54.5 / 15.6 / -) | 10.84 → 11.81 (11.07) | - |
| 45 | 2025-06-27 | bug fix | dropped | probe | `skipped_test` | 50 s (28.3 / 20.0 / -) | 11.81 → 12.62 (11.93) | - |
| 44 | 2025-06-27 | bug fix | dropped | probe | `no_starting_failure` | 50 s (29.3 / 13.7 / -) | 12.62 → 12.71 (12.76) | the same, settled |
| 43 | 2025-06-27 | feature | dropped | probe | `no_starting_failure` | 110 s (90.8 / 19.0 / -) | 12.71 → 11.99 (13.22) | the same, settled |
| 41 | 2025-06-26 | - | refused | maker | `no_existing_tests` | - | 11.99 → 11.53 (-) | - |
| 31 | 2025-06-20 | bug fix | **checked** | - | - | 301 s (95.2 / 106.4 / 88.9) | 11.53 → 11.70 (14.38) | checked, settled |
| 28 | 2025-06-18 | feature | dropped | probe | `skipped_test` | 80 s (55.3 / 15.6 / -) | 11.70 → 13.49 (14.76) | the same, settled |

Every candidate is built on Elixir 1.18.4 with OTP 26.2.5.21 (the pair its own CI file names), Postgres 18.6 and Redis
7.2 (`versions.tsv`). The kind of a dropped candidate is its made folder's.

- **`skipped_test` (6):** the engine runs a case's hidden tests by whole test file, and the grader passes no skipped
  test (`factory/README.md` section 2.2), so a case whose changed test file holds a test the project skips cannot be
  passed by any fix. For 83, 72, 46, 45 and 28 the skipped tests are the 3 that
  `test/croniq_web/controllers/tasks_api_controller_test.exs` already skipped at their starting commits ("Tasks list
  pagination", "Task edit without \"name\" field", "Task edit invalid cron"); the pull requests change other tests of
  that file. 74 adds a skip tag itself, to "task pages edit task contain schedule" in
  `test/croniq_web/controllers/tasks_controller_test.exs`. The rules count `skipped_test` as the pull request's own
  cause (its changed test file holds the skipped test).
- **`no_starting_failure` (4: 66, 50, 44, 43):** no hidden test fails in its body on the unchanged project. None of
  them uses Redis, and a database version could make a test fail, not pass, so this does not point to the versions.
- **`no_existing_tests` (4):** 58, 49 and 48 at the probe (every existing test file near the change fails or is
  skipped on one side, so none is left to protect), and 41 at the maker (no existing test file is changed or matches
  a changed code file).
- **The second checks.** The machine's 1-minute load stayed between 7.57 and 17.05 during the first pass (other jobs'
  checks), so 17 first checks were not settled; every one was checked again after the list and gave the same verdict.
  A second check of a case whose task folder had not changed reran the probe and reused the controls of the first
  (the engine's receipt matched): 86, 53, 52, 47 and 31 (controls 0.1 s to 0.2 s); 75's probe settled a different
  list of existing tests, so its controls ran again (103.6 s). The exported folder is the last checked try's.
- **The checked cases** (`checked.tsv`, from the engine's result of each case's last checked try):

| Case | Kind | Hidden tests failing first | Passing after | Existing test files kept | Left out | Partial fix | Second round agrees | Licence route | Hold-out |
|---|---|---:|---:|---:|---:|---|---|---|---|
| 90 | feature | 2 | 35 | 1 | 0 | present | yes | licence file | pass |
| 88 | feature | 3 | 32 | 1 | 0 | present | yes | README statement | pass |
| 86 | feature | 1 | 29 | 2 | 0 | present | yes | README statement | pass |
| 75 | bug fix | 2 | 21 | 1 | 0 | present | yes | licence stated later | pass |
| 65 | bug fix | 3 | 14 | 2 | 0 | present | yes | licence stated later | pass |
| 53 | bug fix | 1 | 16 | 1 | 0 | none (`single_hunk`) | yes | licence stated later | pass |
| 52 | bug fix | 1 | 11 | 1 | 0 | none (`single_hunk`) | yes | licence stated later | pass |
| 47 | bug fix | 1 | 16 | 1 | 0 | present | yes | licence stated later | pass |
| 31 | bug fix | 7 | 16 | 1 | 0 | present | yes | licence stated later | pass |

- **The kinds:** the maker's kind in `case.json` matches its written rule read one line at a time for all 9
  (`kind_rule.tsv`, `run/kind_rule.sh`), and matches the read-ahead of `kinds.tsv`. The 3 features add a public
  function (`delete_with_logs`; `parse_params`) or a file and four functions (88: `lib/croniq_web/pagination.ex`).
- **Marks for reporting** (the screening's table): none of the 9 carries the AI-tool mark, adds a migration or
  changes assets. All 9 may edit `lib/` and `test/` only.

## 4. Licence and hold-out

Run on each checked case, one at a time (`run/run_scans.sh`, which calls `run/scans.sh` and through it
`factory/tools/check_tasks.sh` of `main` at `60b1a65`), in a Python container with no network; Hex metadata was
fetched for the dependency list. The scans of the first milestones were made again on the 9 final folders.
`scans.tsv`, `licence_root.tsv`, `licence_files.tsv`, `holdout_tasks.tsv`, `deps_flagged.tsv`:

| Case | Licence scan | Root licence at the starting commit | Files touched | Files passing | Holder wrote every touched file | Counts by | Hold-out | Shared 8-word runs (`common`) | 12-word runs |
|---|---|---|---:|---:|---|---|---|---:|---:|
| 90 | pass | `ok:licence-file` (`LICENSE`) | 4 | 4 | yes | the scan | pass | 3 (3) | 0 |
| 88 | pass | `ok:readme-statement` (line 164) | 3 | 3 | yes | the scan | pass | 3 (3) | 0 |
| 86 | pass | `ok:readme-statement` (line 164) | 4 | 4 | yes | the scan | pass | 3 (3) | 0 |
| 75 | fail | `fail:no-licence` | 4 | 4 | yes | rules section 9, licence stated later | pass | 3 (3) | 0 |
| 65 | fail | `fail:no-licence` | 6 | 6 | yes | rules section 9, licence stated later | pass | 3 (3) | 0 |
| 53 | fail | `fail:no-licence` | 2 | 2 | yes | rules section 9, licence stated later | pass | 3 (3) | 0 |
| 52 | fail | `fail:no-licence` | 2 | 2 | yes | rules section 9, licence stated later | pass | 3 (3) | 0 |
| 47 | fail | `fail:no-licence` | 4 | 4 | yes | rules section 9, licence stated later | pass | 3 (3) | 0 |
| 31 | fail | `fail:no-licence` | 4 | 4 | yes | rules section 9, licence stated later | pass | 3 (3) | 0 |

- **The project's licence over time** (`licence_proof.tsv`, from the project's history): the repository had no
  licence statement until pull request 15 (merged 2025-07-13), which added the README's licence section with "This
  project is licensed under the MIT License." (line 162 there, line 164 at the starting commits of 88 and 86); pull
  request 89 (merged 2025-07-28) added the `LICENSE` file (MIT, "Copyright (c) 2025 Almaz Ilaletdinov") and an MIT
  notice at the top of the project's files. The project's newest commit (2026-08-16) still has both, the copyright
  line reading "2025-2026". Of the 23 candidates, 90 starts with the licence file, 88, 86, 58 and 83 with the README
  statement, and the other 18 with neither.
- **Who wrote the touched files** (`licence_authors.tsv`): for every candidate, every commit that touched any file its
  change touches (the fix and the tests), up to its merge commit, is by the licence holder, under one of two spellings
  of the name on the same account (all 140 rows of candidate and file name the one spelling, 31 of them also the
  other). No touched file has another author,
  and the dependency bot's commits touch none of them, so no candidate is `no_licence_at_commit`. The only other person
  in the project's history fixed a README badge, which no candidate touches.
- **Per file** (`licence_files.tsv`): all 33 touched files of the 9 cases are `ok` at both commits (a file the change
  adds is `-` at the start); none carries another licence notice.
- **The locked dependencies** (the same in every case but the number locked; `deps_flagged.tsv`): `bcrypt_elixir`
  3.3.2 (BSD-3-Clause, ISC, BSD-4-Clause), `poolboy` 1.5.2 (Unlicense or Apache 2.0, locked by 4 cases), `heroicons`
  from GitHub at a pinned commit (licence not read by the tool), and three spelled loosely (`metrics` BSD,
  `parse_trans` and `unicode_util_compat` Apache 2.0). These matter for sessions (rules, section 6), not for the cases.
- **Hold-out:** the repository is not held out, no case names a held-out project, every shared 8-word run is `common`
  (it occurs in the cases of two or more of the bench's projects), and no case shares a 12-word run.

## 5. How the run went

1. **The set-up** (17:53 to 18:04): read-only checks (no bench run; load 3.66; 653,690,986,496 free bytes on `/`), the
   project's clone, the controller image (`elixir-task-factory:croniq-20261112`, `run/build.sh`, every layer cached,
   1 s), the controller (`run/controller.sh up`), the screening's tables staged (`run/all.sh stage`), the resolver
   over the 23 (`run/resolve.exs`: all refused `no_service_image:postgres/17.5`), and the whole suite on a probe
   (`run/suite.sh`).
2. **The recipe changed once:** it was first written as a template (the resolver reads each commit's versions); the
   resolver refused every candidate for Postgres 17.5, and after the rules' section 2 rule it became the fixed recipe
   above. No case was made with the template.
3. **The cases** (18:04:52 to 19:14:49): `run/all.sh run`, `TARGET=20`, `MAX_TRIED=80`, as the controller's user
   (root: the engine writes its job records readable by root only). The list ran out at 23; then the 17 second checks.
   One change to the hexpm job's `all.sh`: a try that leaves no row stops the driver (it never did).
4. **The scans** at each milestone and again on the 9 final folders (19:15 to 19:17), and the tables (`run/tables.sh`,
   `run/checked.sh`, `run/kind_rule.sh`, `run/licence_proof.sh`, `run/versions.sh`, `run/pub.sh`).

## 6. Disk and load

- **The engine's own limits:** one preparation worker and one check at a time (`--concurrency 1`); the engine has no
  switch for build jobs, and every workspace container runs Erlang with 2 schedulers (`ERL_FLAGS "+S 2:2"`). Every
  container carried the labels `task-factory=1` and `task-factory-job=hb-croniq` and a CPU share of 256.
- **The load:** the watcher's 415 samples of the 1-minute load during the cases reached at most 17.05 (18:18:11);
  no stop rule fired (free bytes never under 50,000,000,000; load never above 26) and no bench run started.
- **Disk:** free bytes on the system disk 650,313,232,384 before the suite (18:00), 644,845,334,528 when the cases
  started and 589,395,628,032 when they ended, with every job's use in it. This job's label was on 84 image tags at
  the end (toolchain, workspace and Postgres snapshot images; Docker's sizes overlap, so the per-try bytes are in
  `tasks_croniq.tsv`). The controller's folder held 47,908,096 bytes, the job's folder 129,795,487 bytes (with the
  project's clone and the scans' checked-out trees), and the 9 exported case folders 120,540 bytes.

## Files

| File | What it holds |
|---|---|
| `resolve.tsv` | the toolchain resolver's line for each of the 23 candidates with the factory's own table: the Elixir and OTP each commit names and where, the image, the refusal (`no_service_image:postgres/17.5` for all) |
| `versions.tsv` | per candidate: the Elixir and OTP named and the image used; the Postgres and Redis its CI file starts, its Redis client, and the versions used |
| `kinds.tsv` | the screening's 24 candidates in order: merge date, starting and merge commits, the screening's marks, and the kind read ahead by the maker's rule, with the files and public functions the fix adds |
| `project_tests.tsv` | the whole-suite run: the engine's verdict and counts, ExUnit's summary, the output's size |
| `licence_proof.tsv` | per candidate: its starting commit and date, whether the project's README states its licence there and whether its licence file exists there, the README sentence's and the licence file's commit and date and the copyright line, and the files the change touches: how many, how many were written only by the licence holder, and the others with their authors |
| `licence_authors.tsv` | per candidate and touched file (fix and tests): added or changed, the commits that touched the file up to the merge, their authors by name with their counts, and whether the licence holder wrote all of them (`run/licence_proof.sh`) |
| `tasks_croniq.tsv` | one line per try: the try, number, id, merge date, Elixir/OTP, kind, folder origin, verdict, step, reason, the driver's step times, the engine's step times, load at start and end and the highest during the check, settled, the bytes of every image the machine gained meanwhile (all jobs'; images share layers), the build cache's change, the disk bytes used (all jobs'), start, end, and this job's own images and their bytes |
| `counts.tsv` | pull requests per verdict, step and reason, each by its last try |
| `checked.tsv` | per checked case: kind, the try exported, hidden tests failing first and passing after, existing test files kept and left out, the partial fix, the second round, the licence scan's result and root licence, files touched and passing, whether the licence holder wrote every touched file, the route by which the licence rule holds, the hold-out result, and whether the case counts (`run/checked.sh`) |
| `kind_rule.tsv` | per case folder: the kind in `case.json`, the kind by the maker's written rule read one line at a time, the files and public functions the fix adds |
| `scans.tsv` | per case: the licence scan's file, families, files touched and passing, result and reasons; the hold-out check's name hits, shared runs and result; the locked dependencies by licence class |
| `licence_root.tsv` | per case: the licence scan's columns, with the root licence and its proof (the file, its commit, and for a README statement its line and sentence) |
| `licence_files.tsv` | per case and touched file: which patches touch it, the scan's verdict at the starting and the merge commit, the result |
| `holdout_tasks.tsv` | per case: the repository check, name hits, and the shared 8- and 12-word runs by class |
| `deps_flagged.tsv` | the locked dependencies whose licence is not plainly in the list, with the number of cases that lock each |
| `run/` | the scripts that ran (below) |

## Commands

On the data-mining machine, as root (the engine's job records are readable by root only). `WORK` is the factory's
work folder (with `tasks/`), `JOB` this job's folder (with `run/`, `src/` = this repository's `factory/` at `60b1a65`
plus this recipe, `tables/` = the screening's census, screen and class tables of croniq, `numbers.txt` = the 23
candidates newest first, `croniq.git` = a bare clone of the project, `cache/blablatdinov__croniq.git` = a copy of it
owned by root), `CTL` the controller's folder, `BENCH` the bench's `cases/` folder (read in place).

```sh
SRC=$JOB/src OUT=$JOB/out IMAGE=elixir-task-factory:croniq-20261112 LABEL=task-factory=1 run/build.sh controller
CTL=$CTL NAME=factory-croniq SOURCES=$JOB IMAGE=elixir-task-factory:croniq-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-croniq EPMD_PORT=4523 PREPARE_WORKERS=1 PREPARE_AHEAD=1 \
  run/controller.sh up
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-croniq CACHE=$JOB/cache run/all.sh stage

# the resolver over the 23, with the factory's own table (numbers.txt and resolve.exs copied into CTL/data/croniq)
CTL=$CTL NAME=factory-croniq run/controller.sh rpc 'System.put_env(%{"P5_DIR" => "/data/croniq",
  "REPOSITORY" => "https://github.com/blablatdinov/croniq", "CENSUS" => "prs_blablatdinov__croniq.tsv",
  "SCREEN" => "screen_blablatdinov__croniq.tsv"}); spawn(fn -> Code.eval_file("/data/croniq/resolve.exs") end)'
# (written as one line in the call)

# the whole suite once at the starting commit of pull request 90 (merge commit b50c6355)
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/croniq.git NAME=factory-croniq NUMBER=90 \
  MERGE=b50c6355fa33ea578d4672014b60ebc26b615f58 ROUNDS=1 TEST_TIMEOUT=900 SUB=env OUT=$JOB/out/suite CTL=$CTL \
  JOB_LABEL=task-factory-job=hb-croniq TASK_LABEL=task-factory=1 MAX_LOAD=26 MIN_FREE=50000000000 run/suite.sh
D=$CTL/data/env OUT=$JOB/out/suite ROUNDS=1 run/suite_tables.sh

# the candidates' kinds read ahead, and their versions (the resolver's lines in out/resolve_before_answer.tsv)
CLASSES=$JOB/tables/classes_croniq.tsv CENSUS=$JOB/tables/prs_blablatdinov__croniq.tsv CLONE=$JOB/croniq.git \
  run/kinds.sh > $JOB/kinds.tsv
RESOLVE=$JOB/out/resolve_before_answer.tsv CLONE=$JOB/croniq.git RECIPE=$JOB/src/recipes/blablatdinov__croniq.json \
  run/versions.sh > $JOB/out/versions.tsv

# the cases: newest first, until 20 count, 80 are tried or the list ends (it ended at 23)
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-croniq JOB_LABEL=task-factory-job=hb-croniq TASK_LABEL=task-factory=1 \
  TARGET=20 MAX_TRIED=80 MAX_LOAD=26 MIN_FREE=50000000000 run/all.sh run

# the licence scan and the hold-out check, one case at a time (scan_ids.txt: the checked case ids)
JOB=$JOB CLONE=$JOB/croniq.git DEST=$WORK/tasks/blablatdinov__croniq IDS=$JOB/out/scan_ids.txt BENCH_CASES=$BENCH \
  LABELS=task-factory=1,task-factory-job=hb-croniq run/run_scans.sh

# the licence proof and the authors of every touched file
E="CLONE=$JOB/croniq.git KINDS=$JOB/kinds.tsv NUMBERS=$JOB/numbers.txt README_COMMIT=e3fa91e \
  README_SENTENCE='This project is licensed under the MIT License.' LICENCE_COMMIT=11b9133 \
  HOLDER='^(Ilaletdinov Almaz|Almaz Ilaletdinov)$'"
env $E run/licence_proof.sh candidates > $JOB/out/licence_proof.tsv
env $E run/licence_proof.sh files > $JOB/out/licence_authors.tsv

# the tables
OUT=$JOB/out NUMBERS=$JOB/numbers.txt PREFIX=croniq TASKDIR=$CTL/data/croniq/tasks \
  SCREEN_TSV=$JOB/tables/screen_blablatdinov__croniq.tsv JOB_LABEL=task-factory-job=hb-croniq RUN=$JOB/run run/tables.sh
OUT=$JOB/out DEST=$WORK/tasks/blablatdinov__croniq SCANS=$JOB/out/scans AUTHORS=$JOB/out/licence_authors.tsv \
  run/checked.sh > $JOB/out/tables/checked.tsv
run/kind_rule.sh $WORK/tasks/blablatdinov__croniq > $JOB/out/tables/kind_rule.tsv
OUT=$JOB/out DEST=$JOB/pub run/pub.sh
CTL=$CTL NAME=factory-croniq run/controller.sh stop
```

`run/` holds the hexpm job's `all.sh` (this project's names; a try that leaves no row stops the driver), `one.sh`,
`row.sh`, `watch.sh`, `controller.sh`, `build.sh`, `state.sh`, `make_one.exs`, `make_probe.sh`, `prepare.exs`,
`tests.exs`, `env_tests.sh` (this project's names), `suite.sh`, `suite_tables.sh` (it also reads Elixir 1.18's summary
line, "N tests, F failures, S skipped"), `kinds.sh`, `kind_rule.sh`, `table.sh` (for a fixed recipe it reads the
pair from the image in `case.json`) and `tables.sh`; sanbase2's `resolve.exs`; mbta/screens' `scans.sh`, `diag.exs`
(not used) and `read_large_file_hunks.py` (not needed: no long file); and, new, `versions.sh`, `run_scans.sh`,
`licence_proof.sh`, `checked.sh` and `pub.sh`.

## Licence

The tables hold pull request numbers, dates, commits, version pairs, reason names, test names, file paths of the
project, the licence holder's name as the project's licence file and history give it, times and byte counts; no
code, title, body or patch text of the project. croniq is under the MIT licence (its `LICENSE` file, added
2025-07-28; before that, a README statement from 2025-07-13).
