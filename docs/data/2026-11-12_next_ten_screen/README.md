# Ten more applications of the approved batch: census, screening and toolchain periods (2026-11-12)

Part of [E68](../../../experiments.md). The pilot built the chain for three applications: a
[census](../2026-11-11_pilot_pr_census/README.md) of every merged pull request, a
[screening](../2026-11-12_pilot_pr_screen/README.md) that gives each one a verdict and a reason, and a table of
toolchain periods per application ([nerves_hub_web](../2026-11-12_pilot_env_nerves_hub_web/README.md)). This job runs
the same chain over ten more applications of the [approved batch](../2026-11-09_elixir_project_pool/README.md), by
metadata only: GitHub's GraphQL and REST APIs, read on 2026-11-12 between 07:22 and 07:54 UTC. Nothing was cloned,
built or run. Titles, bodies and patch text of pull requests were read only to compute flags and are stored in no file
here.

## Status

The job stopped before it was finished. What exists:

| Step | Done for | Not done |
|---|---|---|
| Choice of the ten (section 1) | all 53 applications of the batch, [choice.tsv](choice.tsv) | |
| Census (section 2) | all ten, 16,421 merged pull requests, [census/](census/) | |
| Screening (section 3) | 2 of the ten: `hashrocket/tilex` and `source-academy/backend`, [screen/](screen/) | the other eight: their metadata pages are fetched and their named pairs found; the per-file patches of the repair test are fetched for 583 of 924 pull requests; the verdict step has not run |
| Toolchain periods (section 4) | the same two, [periods/](periods/) | the other eight |
| History of the version files | all ten, [periods/file_history.tsv](periods/file_history.tsv) | |

So the table of section 5 holds counts for two applications. For the other eight it holds only the census's counts.
The scripts that finish the job are in [run/](run/); the commands are at the end.

## 1. The ten

From the 53 applications of [approved_app_first_batch.tsv](../2026-11-09_elixir_project_pool/approved_app_first_batch.tsv),
each one left out for every reason that applies ([choice.tsv](choice.tsv) has all 53 rows with every reason;
[state.tsv](state.tsv) has what the API said on the day: archived or not, last push, merged pull requests now, language
shares):

| Reason | Rule as applied | Applications (any reason) | Counted under it first |
|---|---|---:|---:|
| pilot | `nerves-hub/nerves_hub_web`, `axelclark/ex338`, `podlove/radiator` | 3 | 3 |
| archived | `isArchived` true upstream | 8 | 8 |
| not pushed since 2025 | last push before 2025-01-01 | 5 | 1 |
| Elixir under 70 % | GitHub's language share of the default branch, today | 13 | 11 |
| hold-out | the repository, its organisation or its name is in `factory/config/holdout.json` | 0 | 0 |
| other service | a driver in the pool table's `service_deps` column other than `ecto_sql`, `postgrex`, `ch` (ClickHouse) and `redix` (Redis) | 8 | 5 |
| over the cap | more than 3,500 merged pull requests now | 3 | 0 |

(The reasons are listed in this order; an application is counted once under the first that applies.) 28 applications
are left out, 10 are chosen and 15 more pass every rule.

- **The three over the cap** are `firezone/firezone` (11,063 merged pull requests), `Simon-Initiative/oli-torus` (5,122)
  and `santiment/sanbase2` (5,115). All three are also under 70 % Elixir (63.6, 68.3 and 63.4), so the later batch of
  applications that only the cap holds back is empty.
- **The eight with another service:** `santiment/sanbase2` (`brod`, Kafka), `sequinstream/sequin` (`amqp`, `brod`),
  `bors-ng/bors-ng` (`myxql`), `astarte-platform/astarte_flow` (`amqp`), and four that name only SQLite
  (`FarmBot/farmbot_os` and `texttile-blog/texttile` with `ecto_sqlite3`, `lambdaclass/stark_compass_explorer` with
  `ecto_sqlite3`, `cr0t/lexin` with `exqlite`). SQLite has no server to start, but the rule was applied to the column as
  written, so these four are out. Read the other way, `FarmBot/farmbot_os` (1,204 merged pull requests, 71 % Elixir)
  would be the sixth of the ten and `hashrocket/tilex` would drop to the eleventh place.
- **The next in line** after the ten: `cesium/safira` (408 merged pull requests), `cesium/atomic` (369),
  `bikebrigade/dispatch` (306), `jaxernst/lasso-rpc` (306), `blablatdinov/croniq` (232, with Redis).

The ten, by merged pull requests on the day (the pool table of 2026-11-09 had 3,401, 3,171, 2,468, 1,687, 1,402, 1,083,
985, 963, 695 and 525):

| # | Application | Merged | Elixir share | Last push | Drivers in `mix.exs` (pool table) |
|---:|---|---:|---:|---|---|
| 1 | `Logflare/logflare` | 3,412 | 89.9 % | 2026-11-11 | `ch`, `ecto_sql`, `postgrex` |
| 2 | `mbta/dotcom` | 3,171 | 70.6 % | 2026-11-11 | `redix` |
| 3 | `mbta/screens` | 2,468 | 77.5 % | 2026-11-10 | `ecto_sql`, `postgrex` |
| 4 | `supabase/realtime` | 1,712 | 89.4 % | 2026-11-12 | `ecto_sql`, `postgrex` |
| 5 | `hexpm/hexpm` | 1,404 | 93.8 % | 2026-11-11 | `ecto_sql`, `postgrex` |
| 6 | `ambry-app/ambry` | 1,083 | 92.9 % | 2026-11-09 | `ecto_sql`, `postgrex` |
| 7 | `Flo0807/share-a-secret` | 987 | 88.6 % | 2026-11-12 | `ecto_sql`, `postgrex` |
| 8 | `supabase/supavisor` | 963 | 92.5 % | 2026-11-10 | `ecto_sql`, `postgrex` |
| 9 | `source-academy/backend` | 696 | 98.7 % | 2026-11-12 | `postgrex` |
| 10 | `hashrocket/tilex` | 525 | 73.5 % | 2025-11-07 | `ecto_sql`, `postgrex` |
| | Together | 16,421 | | | |

All ten are under MIT or Apache-2.0 in the batch table; `hexpm/hexpm` has its licence notice only in the README.

## 2. The census of the ten

The pilot's census, unchanged in its columns and flags ([the pilot's README](../2026-11-11_pilot_pr_census/README.md)
defines every one): one row per merged pull request in [census/](census/) (`prs_<owner>__<name>.tsv.gz`), and
[census/summary.tsv](census/summary.tsv).

| Application | Merged | First merge | Last merge | By bots | Only `mix.exs` or `mix.lock` | Docs only | Reverts | Code under `lib/` and tests | Of those, 2 to 5 code files |
|---|---:|---|---|---:|---:|---:|---:|---:|---:|
| `Logflare/logflare` | 3,412 | 2019-02-13 | 2026-11-11 | 134 | 43 | 132 | 17 | 1,213 | 501 |
| `mbta/dotcom` | 3,171 | 2019-05-29 | 2026-11-09 | 220 | 47 | 21 | 27 | 1,061 | 510 |
| `mbta/screens` | 2,468 | 2020-01-21 | 2026-11-09 | 567 | 142 | 14 | 28 | 597 | 277 |
| `supabase/realtime` | 1,712 | 2019-10-08 | 2026-11-12 | 108 | 65 | 29 | 2 | 679 | 350 |
| `hexpm/hexpm` | 1,404 | 2014-04-22 | 2026-11-11 | 156 | 77 | 50 | 0 | 643 | 278 |
| `ambry-app/ambry` | 1,083 | 2021-09-30 | 2026-10-27 | 762 | 554 | 3 | 0 | 153 | 47 |
| `Flo0807/share-a-secret` | 987 | 2023-10-24 | 2026-11-11 | 944 | 344 | 1 | 1 | 4 | 3 |
| `supabase/supavisor` | 963 | 2023-01-13 | 2026-11-06 | 5 | 18 | 21 | 0 | 255 | 119 |
| `source-academy/backend` | 696 | 2018-01-21 | 2026-11-10 | 280 | 276 | 10 | 6 | 256 | 124 |
| `hashrocket/tilex` | 525 | 2016-12-19 | 2025-10-31 | 139 | 89 | 18 | 1 | 83 | 40 |
| Together | 16,421 | | | 3,315 | 1,655 | 299 | 82 | 4,944 | 2,249 |

Every candidate of the screening changes both code under `lib/` and a test, so the "code and tests" column is the most
the candidates of each application can be: 4,944 for the ten. Two applications have mostly pull requests by bots:
`Flo0807/share-a-secret` (944 of 987 merged pull requests, 4 with code and tests) and `ambry-app/ambry` (762 of 1,083,
153 with code and tests).

## 3. The screening of two

`hashrocket/tilex` and `source-academy/backend`, with the pilot's rules unchanged ([the pilot's README](../2026-11-12_pilot_pr_screen/README.md)
has them and every column): [screen/screen_hashrocket__tilex.tsv](screen/screen_hashrocket__tilex.tsv) and
[screen/screen_source-academy__backend.tsv](screen/screen_source-academy__backend.tsv) (one row per merged pull request:
verdict, reason, every rule that applies, marks, `ai_tool` and `ai_signals`), [screen/pairs.tsv](screen/pairs.tsv) (the 29
named pairs and whether the later one repairs the earlier), [screen/summary.tsv](screen/summary.tsv),
[screen/candidates_first.tsv](screen/candidates_first.tsv), [screen/sensitivity.tsv](screen/sensitivity.tsv),
[screen/checks.txt](screen/checks.txt).

| Application | Merged | Candidates | Rejected | no code change | no test change | `mix.exs` or `mix.lock` | revert | repaired by a later one |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `hashrocket/tilex` | 525 | 72 | 453 | 289 | 138 | 25 | 0 | 1 |
| `source-academy/backend` | 696 | 204 | 492 | 358 | 91 | 35 | 1 | 6 |
| Together | 1,221 | 276 | 945 | 647 | 229 | 60 | 1 | 7 |

(The reason is the first rule that applies; the rules are the pilot's. `source-academy/backend` has one more first
reason, `reverted_later`, 1 pull request: #73, reverted by #75.)

- **Pairs:** 15 named pairs in tilex, 14 in backend; 14 and 11 tested; 1 and 8 repaired.
- **Written with an AI tool** (the mark, as a column of every table): 0 of tilex's 525 merged pull requests, 5 of
  backend's 696 (3 with a footer in the body, 5 with a trace in the merge commit, 1 with an author login of a coding
  tool's agent); 1 of backend's 204 candidates, none of tilex's 72.
- **Checks** ([screen/checks.txt](screen/checks.txt)): the pilot's `check.sh` prints one FAIL, backend's second check
  (211 counted from the census, 210 in the screen). Its formula leaves out the `reverted_later` rule: #73 passes every
  rule before the repair rule and is rejected as reverted later, which the pilot's three repositories never needed.
  `run/check_ten.sh` is that check with the third term added; both counts are 211 in backend and 73 in tilex.

## 4. The toolchain periods of two

A period is a run of candidates (newest first, by merge time) whose toolchain, database versions, services and installed
programs are the same. The pilot read each starting commit's files from a clone; here the files of each candidate's
starting commit (the first parent of its merge commit, from the census) are read through GraphQL: the root tree, the
`.github/workflows` and `.github/actions` trees (names and blob ids), then each distinct blob once.
`run/periods_facts.jq` and `run/periods_resolve.jq` are a port to `jq` of the readers of the factory's toolchain
resolver (`factory/lib/eab/toolchain.ex`): `.tool-versions`, `mise.toml` and `.mise.toml`, the CI files, a `Dockerfile`
and the lower bound of the `elixir:` requirement of `mix.exs`, in that order, each version from the first file that
names it; the image from `factory/config/toolchain_images.json` by prefix; the Postgres major and the ClickHouse version
from CI's services, matched against the same table. The port was tried on made-up files and on these two applications;
it was not compared with the Elixir code's output.

Two readings are recorded for each candidate. **What the resolver reads today** is the port of the Elixir code (columns
`resolver_reads`, `resolver_image`). **What CI names** also reads an environment variable such as `ELIXIR_VERSION: '1.13.3'`
and a container image such as `hexpm/elixir:1.14.4-erlang-25.3.2` (columns `elixir`, `otp`, `image`). The two differ
where the resolver misses a version CI states: `source-academy/backend` names its versions in environment variables from
2021 to 2025, and the resolver reads `1.10` from `mix.exs` instead. A period is marked as one the factory can build when
the second reading gives no lack; `resolver_gap` is `yes` where the first reading would still refuse it. The lacks:

| Lack | Meaning |
|---|---|
| `elixir_older_than_1.12` | an Elixir before 1.12 (the engine's pinned Hex does not install there) |
| `pair_missing:<elixir>/<otp>` | a pair the image table lacks (the table matches Elixir by prefix and OTP by prefix of its own full version); `near_table_pair` lists the table's pairs with the same Elixir minor and OTP major |
| `db_version:postgres/<version>` | a Postgres major other than the table's (10, 14, 18), or a ClickHouse version it lacks |
| `service:<name>` | a service other than Postgres, ClickHouse and Redis started by a CI job that runs the tests |
| `release_file` | CI installs a program from a downloaded file (`.deb`, an archive, `curl` or `wget` to a file or a pipe) |
| `toolchain:<name>` | CI sets up, or `mix.exs` needs, another language's toolchain (Rust for `rustler`, Python, Go and so on) |

Apt packages (`apt_packages`), Docker Compose use in a test job (`docker_compose`), and services started only by
workflows that do not run the tests (`services_in_other_workflows`) are recorded as columns and are not lacks: the
engine installs distribution packages per task, and the resolver refuses any CI service other than Postgres and
ClickHouse unless the project's template marks it as not needed. Redis is served by the engine; the resolver still
answers `needs_service:redis`, so a period with `redis` set needs its template to say so.

| Application | Candidates | Periods | No lack | Elixir older than 1.12 | Pair missing | Postgres version missing | Release file |
|---|---:|---:|---:|---:|---:|---:|---:|
| `hashrocket/tilex` | 72 | 14 | 0 | 59 | 13 | 0 | 13 |
| `source-academy/backend` | 204 | 19 | 0 | 142 | 62 | 121 | 0 |
| Together | 276 | 33 | 0 | 201 | 75 | 121 | 13 |

(A candidate can have several lacks, so the columns after "No lack" are counted per kind.)

- **`hashrocket/tilex`:** the newest period (2025-10-30, 1 candidate) is Elixir 1.18.4 and OTP 28.1, Postgres 14; the
  table has 1.18.3/27.3 and 1.19.2/28.1. The 2022-10 to 2023-04 periods (6 candidates) are 1.14.0 and 1.14.1 on OTP 25.1.x;
  the table's 1.14 pair is 1.14.4/25.3.2. 1.12.1 on OTP 24.0.2 (6 candidates) has no pair at all. 59 candidates from
  2016 to 2020 need Elixir 1.2 to 1.9.
- **`source-academy/backend`:** 62 candidates from 2021-09 to 2026-11 name Elixir 1.12 to 1.19 and lack a pair;
  10 of them (2021-09 to 2022-01 and 2025-07 to 2025-11) lack a Postgres version too: 1.19.5/28.5 and 1.19.5/28.3.1 (the table has 1.19.5/28.4.1), 1.18.3/27.3.3 (1.18.3/27.3), 1.13.4/25.3.2
  (33 candidates; 1.13.4/25.0), 1.13.3/24.2.1 and 1.12.3/24.0.6. CI's Postgres is 14.2 in 2022 to 2025 (in the table),
  17.4 in 2025 (6 candidates, not), 13.1 in 2021 to 2022 and 9.6 in 2018 to 2020.
- **The file history** ([periods/file_history.tsv](periods/file_history.tsv), from GitHub's commit lists per path, all
  ten): for example `.tool-versions` changed 22 times in `Logflare/logflare` and `mbta/dotcom`, 14 in tilex and 3 in
  backend; `supabase/realtime` has `mise.toml` since 2026-04; `hexpm/hexpm` has no version file (its history shows `.travis.yml` until
  2020 and workflows since).

## What the other eight need that the factory lacks, from the default branch's root

Read from each repository's root listing and workflow names on 2026-11-12 (the default branch only, not per period; the
periods step above would settle it per candidate):

- `Logflare/logflare`: `Cargo.toml` and `native/` at the root (a Rust crate); `docker-compose*.yml` files, one for
  MinIO; 17 workflows, among them end-to-end and replication jobs. Services in the pool table: ClickHouse and Postgres.
- `mbta/dotcom`: Redis (`redix`); `package.json`, `cypress/` and `playwright.config.js`, and `requirements.txt` (Python)
  at the root; `.github/actions`.
- `mbta/screens`: `.github/actions`; five workflows, one of them `ci.yml`.
- `supabase/realtime`: `compose*.yml` files for its databases, `mise.toml` and `mise.lock`, 22 workflows.
- `supabase/supavisor`: `native/` and `docker-compose*.yml`, `mise.toml`, `.tool-versions`.
- `hexpm/hexpm`: `docker-compose.yaml`; four workflows (`main.yml` and three security ones), no version file.
- `ambry-app/ambry` (three workflows) and `Flo0807/share-a-secret` (one, `ci.yml`): a `.tool-versions` each.

## What metadata cannot tell

- Whether a candidate's tests run, or fail before and pass after the change: that needs the build.
- Whether the file a CI job names is the one the project's tests use; a matrix of versions is read as its first item.
- Whether the first parent of a merge commit is the commit the pull request branched from: for a rebase merge it is the
  previous commit of the rebased series.
- What a Docker Compose file starts, a Dockerfile's apt packages, or a service that the application starts inside its
  own tests: none is in the CI files.
- Candidates whose merge commit GitHub no longer serves (a deleted branch) have no starting commit; their rows say so.
- The counts in the tables are counts of pull requests, not of tasks.

## Files

| File | What |
|---|---|
| [choice.tsv](choice.tsv) | the 53 applications: merged pull requests now and in the pool table, Elixir share, last push, archived, drivers, every reason that applies, the decision |
| [state.tsv](state.tsv) | the API's answer for the 53 on the day |
| `census/prs_<owner>__<name>.tsv.gz` | the census, ten files; `census/summary.tsv`; `census/fetch_log.txt` (each request's page, cost and remaining budget) |
| `screen/screen_*.tsv` | the screening of the two; `pairs.tsv`, `summary.tsv`, `candidates_first.tsv`, `sensitivity.tsv`, `checks.txt`, `fetch_log_meta.txt` (the metadata fetch of all ten) |
| `periods/periods_<owner>__<name>.tsv.gz` | one row per candidate: its period, versions and their sources, the image, databases, services, installs, test command, lacks, the resolver's reading |
| `periods/periods_summary.tsv` | one row per period; `periods/periods_by_repo.tsv`; `periods/file_history.tsv` |
| `run/` | every script (below) |

## Differences from the pilot's scripts

The pilot's scripts run unchanged where they fit. Four are copies with one change each, and this folder adds the rest:
- `fetch_census.sh` is `fetch.sh` of the census with the extra pages of a pull request that has more than 100 files kept in a
  file instead of a shell variable. With the variable, `mbta/dotcom` stopped with `jq: Argument list too long`.
- `census_summarize.sh` and `screen_summarize.sh` / `screen_summarize.awk` take the first and last year of the year columns
  as parameters (the pilot's were fixed at 2016 and 2026; `hexpm/hexpm` has merges from 2014).
- `check_ten.sh` is the pilot's second check with the `reverted_later` term (section 3).
- New: `state.sh`, `choose.sh`, `fetch_one.sh`, `run_ten.sh`, `candidates.sh`, `periods_fetch.sh`, `periods_facts.jq`,
  `periods_resolve.jq`, `periods_run.sh`, `file_history.sh`, `summary.sh`.
- Status of the new scripts: `state.sh`, `choose.sh`, `fetch_one.sh`, `file_history.sh` and the census step of `run_ten.sh`
  ran for all ten. The screen step of `run_ten.sh` ran in full for two applications and as far as the patch fetch for
  the others. `candidates.sh`, `periods_fetch.sh` and `periods_run.sh` ran for the two. `summary.sh` has not run.

## Commands

`gh` logged in, plus `jq`, `awk` and `gzip`. `PILOT` is `docs/data`; `RAW` holds the raw pages (titles, bodies and patches:
never commit it); `WORK` holds intermediate rows; `OUT` is this folder.

```bash
LIST=$PILOT/2026-11-09_elixir_project_pool/approved_app_first_batch.tsv OUT=<state> bash run/state.sh
LIST=$LIST STATE=<state>/state.tsv HOLDOUT=factory/config/holdout.json OUT=<choice> bash run/choose.sh
# per application of <choice>/ten.txt, with PRS its merged pull requests now (column 2 of choice.tsv)
PILOT=$PILOT RAW=$RAW PRS=<n> bash run/fetch_one.sh <owner>/<name>
PILOT=$PILOT RAW=$RAW WORK=$WORK OUT=$OUT bash run/run_ten.sh          # census, then screening (fetches patches: resumable)
CENSUS=$OUT/census SCREEN=$OUT/screen bash run/candidates.sh > $WORK/cand.tsv
CAND=$WORK/cand.tsv RAW=$RAW bash run/periods_fetch.sh                  # SLUGS="owner__name ..." for a subset
RAW=$RAW TABLE=factory/config/toolchain_images.json OUT=$OUT/periods bash run/periods_run.sh
REPOS="owner/name ..." OUT=$OUT/periods bash run/file_history.sh
OUT=$OUT bash run/summary.sh
```

`run_ten.sh` checks GitHub's REST budget before the patch fetch, `fetch_one.sh` and `periods_fetch.sh` check the GraphQL
budget before each repository, and each stops without writing more when the budget would run out. The patch fetch skips
the pull requests already in `$RAW/patches`.

**GitHub's budget,** from the logs: the ten repositories' census (553 requests) and metadata fetch (553) cost 1 GraphQL
point per request, 30 pull requests each. The patch fetch is one REST request per pull request in a named pair: 924 are
needed, 583 were fetched. The periods fetch of the two applications used 12 tree queries and the blob queries (a few
hundred files).

## Provenance and licence

The tables hold pull-request numbers, merge times, public GitHub logins, labels, changed paths, commit ids, toolchain
versions and CI install lines. They hold no titles, bodies, patch text or source code. The applications are under
MIT or Apache-2.0.
