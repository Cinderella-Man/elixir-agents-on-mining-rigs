# youcongress/youcongress: the project's set-up in the task factory, and its checked cases (2026-11-12)

`youcongress/youcongress` (a Phoenix LiveView and Ecto application for public positions on policy questions, MIT) is
one of the dataset's 16 applications ([rules](../../dataset_rules.md)). This job wrote the project's recipe, ran the
project's whole test suite once through the engine, and made and checked every candidate on Elixir 1.18 or newer,
newest merged first, one at a time, through its own controller built from this repository's `main` at `044f52c`.
Everything ran on the data-mining machine (28 threads, 30 GiB, no GPU), shared with other task-making jobs and one job
that uses the model. Times are that machine's (UTC+1).

## Result

- **5 cases are checked and pass both scans:** 194, 193, 192, 185 and 178. By the maker's label: **3 features**
  (194, 192, 178) **and 2 bug fixes** (193, 185). The label of 185 is plainly wrong: it adds new data to the answer of
  one of the application's tools (the statements an opinion is linked to, with its author's vote on each), which is a
  feature; the maker's rule (registry E108) calls it a bug fix because the change adds only private functions. Read
  that way the five are 4 features and 1 bug fix (section 3).
- **5 is all this project can give now.** The screening found 57 candidates (merged pull requests that change code
  and tests). 49 start on Elixir 1.16.2 or 1.14 and are left out (`elixir_before_1.18`); 8 start on Elixir 1.19.4 with
  OTP 28.3, and all 8 were tried. The project merges few pull requests: most of its work goes to its default branch
  directly.
- **Left out: 3, all for the pull requests' own causes,** none for the machine's or the factory's, each on its first
  try with the machine calm: 181 (no existing test to protect; the engine names it `reference_regression_fails`, see
  section 3), 180 (`reference_fails_hidden`: a test in its changed test file was already broken before the change) and
  179 (`no_existing_tests`). `counts.tsv`.
- **The project needs Postgres with the `vector` extension, and Redis beside the three newest.** From June 2026 its
  migrations create the `vector` extension (pgvector), which the factory's plain Postgres images lack. The recipe uses
  the pgvector image (`pgvector/pgvector:pg17`) that was already on the machine for another project of the dataset; no
  download was needed. The project has no CI and names no database version anywhere. No system package, no release
  file, no other service. The build fetches Hex packages and two Git dependencies at the commits `mix.lock` pins.
- **The whole suite runs:** at 194's starting commit ExUnit's summary is **812 tests, 2 failures, 1 skipped (1
  excluded), in 33.8 s**. The two failures are the project's own tests that no longer match its code at that commit
  (section 2); the skipped test is one the project marks `@tag :skip`, the excluded one carries the project's
  `openai_api` tag.
- **One check took 221 s, 170 s, 210 s, 250 s and 140 s** for the five that ended checked (194, 193, 192, 185, 178).
  The run of all 8 took 21 min 20 s (19:49:43 to 20:11:03). The highest 1-minute load seen was 6.89.
- **Both scans pass for the 5:** the project's `LICENSE` file is the MIT licence, all 24 touched files pass, and the
  hold-out check finds no name and one shared run of 8 words that was read and is a common idiom (section 4).
- **The project's history was rewritten after these merges.** Its default branch holds the same pull requests under
  new commit ids, some with renamed authors; the census holds the ids GitHub recorded at each merge. GitHub still
  serves those commits by id, so the maker fetched them as they are, and for all 8 the old merge commit and its first
  parent hold exactly the same files as their rewritten copies (`history.tsv`).

## 1. The project's set-up

The recipe is [`factory/recipes/youcongress__youcongress.json`](../../../factory/recipes/youcongress__youcongress.json),
a template: the toolchain resolver reads each commit's Elixir, OTP and services from the commit's own files
(`resolve.tsv`, `versions.tsv`).

| What | Value | Where it comes from |
|---|---|---|
| Elixir and OTP | 1.19.4 with OTP 28.3, for all 8 | the commit's `.tool-versions` (`elixir 1.19.4`, `erlang 28.3`); the image is the table's line, pinned by digest |
| Database | `pgvector/pgvector:pg17` (Postgres 17.11 with the pgvector extension), pinned by its index digest `sha256:7d0a4146…` | the recipe's default: the repository has no CI file and names no Postgres version. From the migration of 2026-06-07 on, the schema runs `CREATE EXTENSION IF NOT EXISTS vector`, which needs pgvector (192, 193, 194); `citext` and `pg_trgm`, which older migrations create, are in every Postgres image. The older five run on the same image, which is plain Postgres for them |
| Other services | Redis 7.2 (`redis:7.2-alpine`, the table's line) for 192, 193, 194; none for the older five | the resolver adds Redis when `mix.exs` depends on `redix`, which the project added between March and August 2026. Its tests do not use Redis: the session store that would use it is switched off in `config/test.exs`, and Redis is used only when a production setting names it |
| System packages | none | `bcrypt_elixir` needs a C compiler, which the engine's toolchain stage already installs |
| Environment | `MIX_ENV=test` | `config/test.exs` logs in as `postgres` with the password `postgres` on `localhost`, as the engine's database expects |
| Database commands | `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the project's `test` alias |
| Build | `mix compile` after the engine's own dependency steps | the bench's default recipe |
| Whole-suite command | `mix test` | the project's `test` alias |
| Permitted exclusion tags | `openai_api` | `test/test_helper.exs` excludes it in every run (tests that call the OpenAI API) |

What the build fetches: Hex packages as `mix.lock` pins them, and two Git dependencies at their locked commits
(`anubis_mcp` from the project author's fork on GitHub, `ecto_materialized_path` from GitHub). The engine's toolchain
stage has Git, so `mix deps.get` fetches them while the image is built.

**The rewritten history.** The census gives each pull request's merge commit as GitHub recorded it. The project later
rewrote its default branch (the same changes and messages, new ids, some authors renamed), so a clone of the branch
does not contain those ids. GitHub still serves them by id: the maker fetches each merge commit and its first parent
by id into its cache, as it always does, and this job's clone fetched the 8 by id too
(`refs/census/pr-<number>`). For all 8 the old merge commit and the rewritten one hold the same tree, and so do their
first parents (`history.tsv`, made by `run/history.sh`). Nothing in a task depends on the new ids.

## 2. The project's own suite

A hand-made probe task for pull request 194 (`run/make_probe.sh`, with its own id and a 1,800-second limit for one
test command) was prepared through the controller (`run/prepare.exs`) in 195.8 s (the toolchain image, the workspace
image with the Git dependencies, the database with the project's migrations, from nothing), and the whole suite ran
once through the engine's own runner (`run/tests.exs`), in a fresh workspace container with fresh services and no
network. `project_tests.tsv`, `project_test_failures.tsv`:

| Run | ExUnit tests | Passed | Failed | Excluded | Skipped | ExUnit time | Engine time | Return code | Output | Engine: finished |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 812 | 809 | 2 | 1 | 1 | 33.8 s | 34.8 s | 2 | 142,791 bytes | yes (813 records, all distinct) |

Elixir 1.19.4 prints the excluded tests in brackets and leaves them out of its count of tests ("812 tests, 2
failures, 1 skipped (1 excluded)"); the engine records all 813.

**The two failures are the project's own, at that commit:**
- `YouCongress.HallsTest` "all_stats/0 counts sourced quotes that are not attached to a statement" expects a count of
  2 and gets 0: since 2026-07-25 the count comes from the dataset's own reckoning (`QuotesCsv.dataset_counts/0`), which
  counts only verified quotes of statements with enough of them, and keeps its result for an hour; the test was not
  changed with it.
- `YouCongressWeb.StatementLiveTest` "Index defaults to an unrestricted feed and shows aggregate stats" looks for a
  link labelled "COVID origins", and the navigation at that commit labels it "COVID-19 origins".

Neither depends on the machine, the time or the database version. No candidate's hidden or kept test file is one of
these two (`checked.tsv`, `tasks_youcongress.tsv`).

## 3. The candidates

The screening's list (newest merged first, each with its Elixir/OTP): 57 candidates; the 8 newest start on 1.19.4/28.3,
the next one (merged 2025-12-21) and everything older on 1.16.2/26.2.1 or 1.14. `numbers.txt` held the 8 newest first;
`run/all.sh` ran each through `run/one.sh` (made by the bundle maker, imported, checked with `factoryctl check
--concurrency 1`, exported). No check was unsettled (the 1-minute load never reached 12), and no failure was the
machine's, so no second try ran. `tasks_youcongress.tsv` has every try with its step times, loads and bytes;
`versions.tsv` the versions named and used.

| Pull request | Merged | Kind (label) | Elixir/OTP | Database / Redis | Verdict | Step, reason | Whose | Check (s) | Load start → end (highest) |
|---|---|---|---|---|---|---|---|---:|---|
| 194 | 2026-08-29 | feature | 1.19.4/28.3 | pgvector pg17 / 7.2 | **checked** | | | 221 | 5.97 → 6.35 (6.89) |
| 193 | 2026-08-29 | bug fix | 1.19.4/28.3 | pgvector pg17 / 7.2 | **checked** | | | 170 | 6.35 → 4.95 (5.99) |
| 192 | 2026-08-29 | feature | 1.19.4/28.3 | pgvector pg17 / 7.2 | **checked** | | | 210 | 4.95 → 5.55 (6.25) |
| 185 | 2026-03-14 | bug fix (plainly a feature) | 1.19.4/28.3 | pgvector pg17 / – | **checked** | | | 250 | 5.55 → 3.29 (5.47) |
| 181 | 2026-03-07 | bug fix | 1.19.4/28.3 | pgvector pg17 / – | dropped | controls, `reference_regression_fails` (read: no existing test) | the pull request's | 151 | 3.99 → 3.84 (5.05) |
| 180 | 2026-03-07 | bug fix | 1.19.4/28.3 | pgvector pg17 / – | dropped | probe, `reference_fails_hidden` | the pull request's | 51 | 4.81 → 3.76 (4.69) |
| 179 | 2026-03-07 | | 1.19.4/28.3 named | – | refused | maker, `no_existing_tests` | the pull request's | | 4.66 → 4.44 |
| 178 | 2026-03-07 | feature | 1.19.4/28.3 | pgvector pg17 / – | **checked** | | | 140 | 4.49 → 3.22 (4.57) |
| 49 older | 2024-01-06 to 2025-12-21 | | 1.16.2/26.2.1 (41), 1.14 (8) | | not made | `elixir_before_1.18` | | | |

The kind is the made folder's `task_kind`; the read-ahead in `kinds.tsv` gives 179 a feature (it adds three files).
193 and 194 carry the screening's mark that they were written with an AI tool. 178, 179 and 185 were opened by the
project's account for its AI agents (their commits are signed that way), so they were most likely written with an AI
tool too; the screening's mark, read from the pull request's text and commit lines, does not catch an account.
Making a folder took 5 or 6 s. Every
checked case has hidden tests that fail first and pass after, a partial fix that the controls reject, and a second
round that agrees (`checked.tsv`): 194 14 and 20, 193 1 and 6, 192 11 and 46, 185 2 and 13, 178 1 and 6.

**The kinds.** 193 hides the vote's action bar from visitors who are not logged in on one page: a bug fix is a fair
reading. 185 extends the answer of the application's "show opinion" tool with the statements the opinion is linked to
and its author's vote on each: new behaviour, a feature, though the maker's rule (a new file or a new public function)
finds only private functions and labels it a bug fix. The other three labels match the changes.

**What each drop is.** The engine keeps no output of the probe's runs, so 180's probe step was run again by hand
(`run/diag_hidden.exs`, through the controller, the engine's own functions, one run each side):
- **181** (`reference_regression_fails`): the probe kept one existing test file, `test/you_congress/opinions_test.exs`,
  which is **empty** (0 bytes) at the starting commit, and left out the other, `test/you_congress/opinions/quotes/quotator_test.exs`,
  because its old version fails on the merged code (`fails_on_reference`: the pull request changes the quote finder's
  reply that the old test checks). The run of the empty file prints "0 tests, 0 failures": the probe counts that as
  passing, the controls count a run in which no test was recorded as not finished, and drop the task. With the empty
  file read as holding no test, no existing test is left to protect, which is `no_existing_tests`: the pull request's
  own. That the probe keeps a test file that holds no test is a gap of the factory; it changed the reason's name here,
  not the verdict.
- **180** (`reference_fails_hidden`): one test of the pull request's changed test file
  `test/you_congress_web/live/statement_live_test.exs` ("Index saves new statement and redirect to show") fails on the
  merged code: a background job (`YouCongress.Workers.QuotatorWorker.perform/1`) gets a reply of a shape it does not
  match (`CaseClauseError` on `{:ok, 5}`) from the quote finder's test stand-in. By hand on the unchanged project the
  same test fails the same way (29 tests, 2 failures: this one and one of the new tests); on the merged code 29 tests,
  1 failure. The test was broken before the pull request and stays broken after it; the next candidate, 181, reworks
  that reply. The pull request's own: its test file holds a failing test.
- **179** (`no_existing_tests`): it adds three modules and the new test file that tests them, and changes one module
  that no existing test file covers. Before that, the maker's source check had refused it as `paths_never_match`
  (`resolve.tsv`): the census lists six files and the merge changes five. The sixth, `README.md`, was changed on the
  pull request's branch, but the same change had reached the default branch through 178, merged 20 minutes earlier, so
  the squash merge leaves it as it was. The job made 179 again from a census row with the merge's own five paths (a
  second list, `lists.tsv`, staged with that row; `history.tsv` has the counts), and the maker then refused it for its
  own reason above. The pull request's own.

## 4. Licence and hold-out

Run on each checked task, one task at a time (`run/run_scans.sh`, which calls `run/scans.sh` and through it
`factory/tools/check_tasks.sh` of `main` at `044f52c`), in a Python container with no network; Hex metadata was
fetched for the dependency list. `scans.tsv`, `licence_root.tsv`, `licence_files.tsv`, `holdout_tasks.tsv`,
`deps_flagged.tsv`:

| Task | Licence result | Root licence | Files touched | Files passing | Hold-out result | Name hits | Shared 8-word runs | Shared 12-word runs |
|---|---|---|---:|---:|---|---:|---|---|
| 194 | pass | `ok:licence-file`, MIT | 5 | 5 | pass | 0 | 11 (10 `common`, 1 `syntax`) | 3 (all `common`) |
| 193 | pass | `ok:licence-file`, MIT | 4 | 4 | pass | 0 | 10 (all `common`) | 3 (all `common`) |
| 192 | pass | `ok:licence-file`, MIT | 9 | 9 | review, read: pass | 0 | 16 (10 `common`, 5 `syntax`, 1 to read) | 3 (all `common`) |
| 185 | pass | `ok:licence-file`, MIT | 2 | 2 | pass | 0 | 10 (all `common`) | 3 (all `common`) |
| 178 | pass | `ok:licence-file`, MIT | 4 | 4 | pass | 0 | 10 (all `common`) | 3 (all `common`) |

- **The project's licence:** the root `LICENSE` is the MIT licence at every starting commit (SHA-256
  `414b1c799663a5fd...`, the same file in all five), present since 2024-05-08, long before the oldest of the 8; the
  file names no copyright holder. No touched file carries another notice, and none is long enough to be left out of
  the scan. 178 adds a 315-byte SVG icon (`priv/static/images/wikipedia.svg`: a circle and one line) with no notice;
  the scan passes it.
- **The one shared run to read** (192, span `b03cfde29b07`, 8 words, shared with the reference fix of a bench case):
  the end of a query (`Repo.all()` and `end`) followed by the opening of the next function's documentation ("Returns
  a"), the usual shape of a Phoenix context module. It is not code taken from the bench; 192 passes. The text was read
  on the machine and deleted; it is not published.
- **The locked dependencies** (`deps_flagged.tsv`, with the number of tasks that lock each): two Git dependencies whose
  licence the scan does not read (`anubis_mcp`, the project author's fork, in 3 tasks; `ecto_materialized_path` in all
  5); `anubis_mcp`'s Hex release 0.17.0 is LGPL-3.0, outside the list; `poison` 5.0.0 is 0BSD, not in the list until
  read; `bcrypt_elixir` and `poolboy` name several licences, some outside; the rest are in the list but spelled loosely
  (`Apache 2.0`, `BSD`). For the tasks this changes nothing; a session that quotes a file of a dependency outside the
  list, or of a Git dependency not yet read, is dropped (rules, section 6).
- **Hold-out:** the repository is not held out and no task names a held-out project.

## 5. How the run went

- The driver scripts are source-academy/backend's
  ([2026-11-12_cases_source_academy_backend](../2026-11-12_cases_source_academy_backend/README.md)), with this
  project's names; `suite_tables.sh` is croniq's (with a skipped column), taught Elixir 1.19.4's summary line, in which
  the excluded tests stand in brackets outside the count; `versions.sh` gained a Redis column; `resolve.exs` is
  croniq's; `history.sh` is new. The driver ran as root (the engine's job records are readable by root only), started
  once, and ended by itself.
- The controller: container `factory-youcongress`, its own node, port mapper and folders, image
  `elixir-task-factory:youcongress-20261112` (771,609,948 bytes) built from `factory/` at `044f52c` with the set-up's
  switches (`EAB_HEX_CACHE_ID=etf-hex-packages-v1`), one preparation worker, one check at a time, every container with
  the labels `task-factory=1` and this job's own, and a CPU share of 256. It was stopped at the end, not removed.
- **Disk and load:** free bytes on the system disk 562,593,087,488 at the start of the cases (19:49:43) and
  551,669,063,680 at their end (20:10:52), with every job's use in it. The watcher's 127 samples of the 1-minute load
  during the cases ran up to 6.89 (19:51:54), its 24 samples during the suite up to 7.15; no stop rule fired (free bytes
  never under 50,000,000,000, load never above 26) and no bench run started. At the end this job's label was on 34
  image tags of 17 images (one toolchain image under 9 tags, 8 workspace images each tagged `project` and `seed`, 7
  database snapshots, one database layout image under 2 tags); Docker's sizes overlap (shared layers), so the per-try
  bytes are in `tasks_youcongress.tsv`. The
  controller's folder held 118,329,705 bytes, the job folder 141,862,184 bytes and the 5 exported task folders 118,449
  bytes.

## Files

| File | What it holds |
|---|---|
| `tasks_youcongress.tsv` | one line per try and one per candidate not made: the try, number, id, merge date, Elixir/OTP, kind, folder origin, verdict, step, reason, the driver's step times, the engine's step times, load at start and end and the highest during the check, settled, the bytes of every image the machine gained meanwhile (all jobs'; images share layers), the build cache's change, the disk bytes used (all jobs'), start, end, and this job's own images and their bytes |
| `counts.tsv` | pull requests per verdict, step and reason, each by its last try, the 49 not made included |
| `checked.tsv` | per checked case: kind, hidden tests failing first and passing after, existing test files kept and left out, the partial fix, the second round |
| `versions.tsv` | per candidate: the starting commit, its `.tool-versions`, the CI's versions (none: no CI), the Elixir/OTP, database and Redis images the task used, and the recipe kind |
| `resolve.tsv` | the toolchain resolver over the 8 before any was made: the versions, image, database, baseline and Redis with their sources, and 179's first refusal (`paths_never_match`) |
| `history.tsv` | per candidate: the census's merge commit and first parent, the same pull request's commits on the rewritten default branch, whether their trees are equal, and the paths the census lists against those the merge changes |
| `kinds.tsv` | the 8 in order: merge date, starting and merge commits, and the kind read ahead by the maker's rule, with the files and public functions the fix adds |
| `kind_rule.tsv` | per exported task folder: the kind in `case.json`, the kind by the maker's rule read one line at a time, the files and public functions the reference adds, and their names |
| `project_tests.tsv` | the whole-suite run: the engine's verdict and counts, ExUnit's summary, the output's size |
| `project_test_failures.tsv` | the two tests that failed in the whole-suite run, with their file and line |
| `scans.tsv` | per task: the licence result, the root licence families, files touched and passing, the scan's reasons, the hold-out result, name hits, seconds |
| `licence_root.tsv` | per task: the root licence's result, the file it was read from and that file's SHA-256, the families |
| `licence_files.tsv` | per task and touched file: which patches touch it, the scan's verdict at the starting and the merge commit, the result |
| `holdout_tasks.tsv` | per task: the repository check, name hits, and the shared 8- and 12-word runs by class |
| `deps_flagged.tsv` | the locked dependencies whose licence is not plainly in the list, with the number of tasks that lock each |
| `run/` | the scripts that ran (below) |

## Commands

On the data-mining machine, as root unless marked. `WORK` is the factory's work folder (with `tasks/`), `JOB` this
job's folder (with `run/`, `src/` = this repository's `factory/` at `044f52c` plus this recipe, `tables/` = the
screening's census, screen and class tables of the project, `numbers.txt` = the 8 candidates newest first,
`youcongress.git` = a bare clone of the project owned by the work user, `cache/youcongress__youcongress.git` = a copy
of it owned by root), `CTL` the controller's folder, `BENCH_CASES` the bench's `cases/` folder (read in place by the
hold-out check).

```sh
# the clone (as the work user), with the census's merge commits fetched by id
git clone --bare https://github.com/youcongress/youcongress.git $JOB/youcongress.git
for n in $(cat $JOB/numbers.txt); do
  m=$(awk -F'\t' -v n=$n '$1 == n {print $10}' $JOB/tables/prs_youcongress__youcongress.tsv)
  git -C $JOB/youcongress.git fetch -q https://github.com/youcongress/youcongress.git +$m:refs/census/pr-$n
done
# the 8 rows of the class table (as the work user)
awk -F'\t' 'NR > 1 && $7 == "pair_missing"' $JOB/tables/classes_youcongress__youcongress.tsv > $JOB/tables/classes_8.tsv

E="CTL=$CTL NAME=factory-youcongress"
SRC=$JOB/src OUT=$JOB/out IMAGE=elixir-task-factory:youcongress-20261112 LABEL=task-factory=1 run/build.sh controller
env $E SOURCES=$JOB IMAGE=elixir-task-factory:youcongress-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=<this job> EPMD_PORT=<a free port> PREPARE_WORKERS=1 PREPARE_AHEAD=1 \
  run/controller.sh up
env $E WORK=$WORK JOB=$JOB CACHE=$JOB/cache run/all.sh stage

# the resolver over the 8, without making a task
cp $JOB/numbers.txt run/resolve.exs $CTL/data/youcongress/
run/controller.sh rpc 'System.put_env(%{"P5_DIR" => "/data/youcongress", "REPOSITORY" => "https://github.com/youcongress/youcongress",
  "CENSUS" => "prs_youcongress__youcongress.tsv", "SCREEN" => "screen_youcongress__youcongress.tsv"});
  spawn(fn -> Code.eval_file("/data/youcongress/resolve.exs") end)'

# 179's second list: its census row with the merge's own five paths
mkdir -p $JOB/tables/c179
awk -F'\t' -v OFS='\t' 'NR == 1 {for (i = 1; i <= NF; i++) if ($i == "paths") p = i}
  NR > 1 && $1 == 179 {$p = "lib/you_congress_web/mcp_server.ex;lib/you_congress_web/mcp_server/opinions_delete.ex;lib/you_congress_web/mcp_server/opinions_edit.ex;lib/you_congress_web/mcp_server/opinions_show.ex;test/you_congress_web/mcp_server/opinions_tools_test.exs"}
  {print}' $JOB/tables/prs_youcongress__youcongress.tsv > $JOB/tables/c179/prs_youcongress__youcongress.tsv
env $E WORK=$WORK JOB=$JOB CACHE=$JOB/cache LIST=youcongress-c179 run/all.sh stage
cp $JOB/tables/c179/prs_youcongress__youcongress.tsv $CTL/data/youcongress-c179/tables/
printf '179\tyoucongress-c179\n' > $JOB/lists.tsv

# the whole suite once at the starting commit of pull request 194 (merge commit 9d88f98a)
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/youcongress.git NAME=factory-youcongress NUMBER=194 \
  MERGE=9d88f98ac6a02701179223fa620d15bf3dffbef4 ROUNDS=1 TEST_TIMEOUT=1800 SUB=env OUT=$JOB/out/suite CTL=$CTL \
  JOB_LABEL=task-factory-job=<this job> TASK_LABEL=task-factory=1 MAX_LOAD=26 MIN_FREE=50000000000 run/suite.sh
D=$CTL/data/env OUT=$JOB/out/suite ROUNDS=1 run/suite_tables.sh

# the kinds read ahead (as the work user: the clone is its own)
CLASSES=$JOB/tables/classes_8.tsv CENSUS=$JOB/tables/prs_youcongress__youcongress.tsv CLONE=$JOB/youcongress.git \
  run/kinds.sh > $JOB/kinds.tsv

# the cases: every listed number, newest first (then once more each one not settled: none was)
env $E WORK=$WORK JOB=$JOB JOB_LABEL=task-factory-job=<this job> TASK_LABEL=task-factory=1 TARGET=20 MAX_TRIED=80 \
  MAX_LOAD=26 MIN_FREE=50000000000 run/all.sh run

# 180's hidden tests by hand, keeping the output: on its reference, then on the unchanged project
mkdir -p $CTL/data/diag && cp run/diag_hidden.exs $CTL/data/diag/
run/controller.sh rpc 'System.put_env(%{"D_DIR" => "/data/diag", "D_ID" => "youcongress-pr-180", "D_SIDE" => "reference"});
  spawn(fn -> Code.eval_file("/data/diag/diag_hidden.exs") end)'
run/controller.sh rpc 'System.put_env(%{"D_DIR" => "/data/diag", "D_ID" => "youcongress-pr-180", "D_SIDE" => "start"});
  spawn(fn -> Code.eval_file("/data/diag/diag_hidden.exs") end)'

# the licence scan and the hold-out check, one task at a time
JOB=$JOB WORK=$WORK BENCH_CASES=$BENCH_CASES JOB_LABEL=task-factory-job=<this job> \
  run/run_scans.sh youcongress-pr-194 youcongress-pr-193 youcongress-pr-192 youcongress-pr-185 youcongress-pr-178
# 192's shared run, read on the machine: the scan once more with its text kept, then the text deleted
SRC=$JOB/src DEST=$WORK/tasks/youcongress__youcongress CLONE=$JOB/youcongress.git BENCH_CASES=$BENCH_CASES \
  OUT=$JOB/out/scans_review LABELS=task-factory=1,task-factory-job=<this job> run/scans.sh youcongress-pr-192
rm -f $JOB/out/scans_review/*/LOCAL_spans.json

# the tables (the 49 older candidates listed as not made)
awk -F'\t' 'NR > 1 && $7 == "elixir_before_1.18" {print $2}' $JOB/tables/classes_youcongress__youcongress.tsv \
  > $JOB/out/before_118_numbers.txt
sed 's/^/youcongress-pr-/' $JOB/out/before_118_numbers.txt > $JOB/out/before_118.txt
cat $JOB/numbers.txt $JOB/out/before_118_numbers.txt > $JOB/out/tried_and_listed.txt
OUT=$JOB/out NUMBERS=$JOB/out/tried_and_listed.txt PREFIX=youcongress TASKDIR=$CTL/tasks \
  SCREEN_TSV=$JOB/tables/screen_youcongress__youcongress.tsv JOB_LABEL=task-factory-job=<this job> RUN=$JOB/run \
  HOLD=$JOB/out/before_118.txt HELD_REASON=elixir_before_1.18 run/tables.sh
# as the work user
CLONE=$JOB/youcongress.git CENSUS=$JOB/tables/prs_youcongress__youcongress.tsv TASKDIR=$CTL/tasks \
  run/versions.sh $(cat $JOB/numbers.txt) > $JOB/out/tables/versions.tsv
CLONE=$JOB/youcongress.git CENSUS=$JOB/tables/prs_youcongress__youcongress.tsv \
  run/history.sh $(cat $JOB/numbers.txt) > $JOB/out/tables/history.tsv
OUT=$JOB/out SCANS=$JOB/out/scans DEST=$JOB/pub run/pub.sh
run/kind_rule.sh $WORK/tasks/youcongress__youcongress > $JOB/pub/kind_rule.tsv
env $E run/controller.sh stop
```

`run/` holds `all.sh`, `one.sh`, `row.sh`, `watch.sh`, `controller.sh`, `build.sh`, `state.sh`, `make_one.exs`,
`make_probe.sh`, `prepare.exs`, `tests.exs`, `env_tests.sh`, `suite.sh`, `table.sh`, `tables.sh`, `kinds.sh`,
`kind_rule.sh`, `scans.sh`, `run_scans.sh`, `pub.sh` and `diag_hidden.exs` from source-academy/backend's job with this
project's names, `suite_tables.sh` and `resolve.exs` from croniq's job with the changes of section 5, `versions.sh`
with a Redis column, and `history.sh`, new.

## Licence

The tables hold pull request numbers, dates, commit ids, version pairs, reason names, file paths, module and test
names of the project, times and byte counts; no code, title, body or patch text of the project. youcongress/youcongress
is under the MIT licence (its `LICENSE` file).
