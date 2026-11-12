# The 21 applications: how alive they are, and their newest candidates (2026-11-12)

Registry rows [E82](../../../experiments.md) (newest Elixir first, from repositories that are alive) and E84 (the
Elixir/OTP pairs the factory's image table lacks). On 2026-11-12 the dataset was limited to 21 applications, and later
the same day to 16 of them ([2026-11-12_dataset_projects](../2026-11-12_dataset_projects/README.md)). This job ran for
the 21 ([run/select.sh](run/select.sh) applies the first rule to the pool table and gives the same 21,
[selected.tsv](selected.tsv)); section 2.4 gives the 16. For the 21 this folder holds:

1. **The alive table:** the last commit on the default branch, the commits of the last 12 and 6 months, the merged pull
   requests of the last 12, whether the repository is archived, the Elixir and OTP at the head as the factory's
   resolver reads them, and the versions of the main dependencies in `mix.lock` at the head.
2. **The newest candidates:** the pilot's screening rules applied to every merged pull request of 19 of them, then,
   per application, the candidates from the newest backwards until 150 or the first merge before 2024-01-01, each with
   the Elixir/OTP pair of its starting commit and one class: the table has the pair, the pair is missing, a service is
   missing, or Elixir before 1.12. `axelclark/ex338` and `nerves-hub/nerves_hub_web` were screened by the pilot
   ([2026-11-12_pilot_pr_screen](../2026-11-12_pilot_pr_screen/README.md)) and are not screened again: only their newest
   candidates' pairs are read.

All of it ran on the data-mining machine on 2026-11-12 between 09:52 and 11:25 UTC, as a light job: git (clones of the
default branches without file contents), the public pages of github.com, GitHub's GraphQL API with a read-only token
(the census and the metadata of the 14 applications no earlier job had read: 1,180 requests, all answered 200), `jq`,
`awk` and shell. Nothing was built, no container was started, no task was checked and no model was asked. Titles, bodies
and patch text were read only to compute flags; none is stored in any file here.

## Result

- **All 21 are alive** by the working definition: each has a commit on its default branch since 2026-05-12 and merged
  pull requests since 2025-11-12. The stricter reading (alive, Elixir 1.18 or newer at the head, not archived) agrees
  for 20; `hexpm/preview` is archived (its page and GitHub's API both say so) and stays in the list.
- **All 21 heads name Elixir 1.18 or newer** as the resolver reads them; 13 name 1.20. **The image table has the pair of 2
  heads of 21:** `bikebrigade/dispatch` (1.20 and OTP 29, served by 1.20.3/29.0.5) and `axelclark/ex338` (1.18.3/27.3).
- **1,298 candidates were taken,** newest first, 150 per application at most and none merged before 2024-01-01: 1,060 need
  an Elixir/OTP pair the table lacks, 6 a service the table lacks (Postgres 16), none needs an Elixir before 1.12, and
  **232 have their pair and every service in the table.** Of the 232, 127 also need something their CI installs
  beyond the pair (in nerves_hub_web a program from a downloaded file, 97 of them Python too; in hexpm Rust), and 105
  need nothing more.
- **The pairs the table lacks** (registry E84) are led by 1.20.2/29.0.4 (197 candidates in sanbase2, ambry and
  local_cents), 1.20.4 with OTP 29.1 (186 by one table line 1.20.4/29.1.2: hexpm, nerves_hub_web, screens, flick),
  1.19.2/28.1.1 (150 in oli-torus, which also need `pgvector`) and 1.19.5/28.5.0.4 (128 by one line: realtime, backend,
  asciinema). Section 2 has the whole list.
- 295 of the 1,298 are on an Elixir older than 1.18.
- **Under the two rules the owner added the same day** (the list is 16 applications; a case is built on Elixir 1.18 or
  newer, [docs/dataset_rules.md](../../dataset_rules.md)), section 2.4: of the 1,270 candidates of the 16, 273 are on an
  Elixir older than 1.18, **145 have their pair and every service in the table** (18 of them need nothing more), 847
  lack a pair and 5 a service. The pairs that would serve the most are the same as above.
- `cr0t/lexin`, one of the five taken off for fewer than 10 merged pull requests in 12 months, merged 13 by GitHub's own
  list (the census); it merges without a number, so its history shows 0. It has no candidate in any year, so the
  dataset loses nothing by it.

## 1. The alive table

[alive/alive.tsv](alive/alive.tsv) has one row per application, in this order: the Elixir the resolver reads at the
head (newest first), then merged pull requests in the last 12 months.

**Alive** (the working definition of 2026-11-12, until the owner names another): the default branch has a commit in the
last 6 months, and a merged pull request in the last 12 shows in the history or in the census. **Elixir ok:** the
resolver reads Elixir 1.18 or newer at the head. **Agrees:** both hold and the repository is not archived, so this
stricter reading agrees with the selection rule; a project that fails it stays in the list (the list is the owner's)
and is reported here.

| # | Application | Alive | Agrees | Last commit | Commits, 12 m | 6 m | Merged pull requests, 12 m: history | census | Elixir/OTP at the head | In the table | Phoenix | LiveView | Ecto |
|---:|---|---|---|---|---:|---:|---:|---:|---|---|---|---|---|
| 1 | nerves-hub/nerves_hub_web | yes | yes | 2026-11-10 | 730 | 520 | 719 | 727 | 1.20.4/29.1.2 | no | 1.8.16 | 1.2.13 | 3.14.3 |
| 2 | hexpm/hexpm | yes | yes | 2026-11-11 | 672 | 495 | 645 | 650 | 1.20.4/29.1 | no | 1.8.16 | 1.2.13 | 3.14.2 |
| 3 | mbta/screens | yes | yes | 2026-11-09 | 513 | 287 | 291 | 484 | 1.20.4/29.1.2 | no | 1.8.16 | 1.2.12 | 3.14.2 |
| 4 | ambry-app/ambry | yes | yes | 2026-10-27 | 442 | 415 | 205 | 215 | 1.20.2/29.0.4 | no | 1.8.16 | 1.2.13 | 3.14.2 |
| 5 | santiment/sanbase2 | yes | yes | 2026-11-12 | 1,356 | 774 | 182 | 452 | 1.20.2/29.0.4 | no | 1.8.9 | 1.2.8 | 3.13.6 |
| 6 | joladev/jola.dev | yes | yes | 2026-11-12 | 252 | 221 | 161 | 161 | 1.20.4/29.1.1 | no | 1.8.16 | 1.2.13 | - |
| 7 | zorn/local_cents | yes | yes | 2026-10-08 | 133 | 133 | 130 | 130 | 1.20.2/29.0.4 | no | 1.8.15 | 1.2.12 | 3.14.2 |
| 8 | blablatdinov/croniq | yes | yes | 2026-08-16 | 110 | 32 | 110 | 110 | 1.20.3/28.3 | no | 1.8.9 | 1.2.6 | 3.14.0 |
| 9 | zorn/flick | yes | yes | 2026-11-08 | 87 | 81 | 87 | 93 | 1.20.5/29.1.2 | no | 1.8.16 | 1.2.13 | 3.14.3 |
| 10 | bikebrigade/dispatch | yes | yes | 2026-11-07 | 58 | 35 | 55 | 55 | 1.20/29 | 1.20.3/29.0.5 | 1.8.16 | 1.2.13 | 3.14.2 |
| 11 | notesclub/notesclub | yes | yes | 2026-11-11 | 93 | 83 | 25 | 26 | 1.20.2/29.0.3 | no | 1.8.16 | 1.2.13 | 3.14.3 |
| 12 | youcongress/youcongress | yes | yes | 2026-11-09 | 765 | 466 | 22 | 23 | 1.20.4/29.0.6 | no | 1.7.24 | 1.1.33 | 3.14.2 |
| 13 | cr0t/lexin | yes | yes | 2026-09-05 | 38 | 13 | 0 | 13 | 1.20.4/29.0.6 | no | 1.8.13 | 1.2.11 | - |
| 14 | supabase/realtime | yes | yes | 2026-11-12 | 1,084 | 794 | 714 | 712 | 1.19.5/28.5.0.4 | no | 1.8.15 | 1.2.11 | 3.14.3 |
| 15 | Simon-Initiative/oli-torus | yes | yes | 2026-11-11 | 931 | 383 | 392 | 941 | 1.19.2/28.1.1 | no | 1.8.2 | 1.1.4 | 3.13.2 |
| 16 | source-academy/backend | yes | yes | 2026-11-10 | 41 | 14 | 41 | 41 | 1.19.5/28.5 | no | 1.8.7 | 0.19.3 | 3.13.6 |
| 17 | cesium/safira | yes | yes | 2026-11-11 | 19 | 17 | 4 | 5 | 1.19/28.1.1 | no | 1.8.1 | 1.1.17 | 3.13.5 |
| 18 | asciinema/asciinema-server | yes | yes | 2026-11-07 | 526 | 272 | 1 | 4 | 1.19.5/28.5 | no | 1.8.16 | 1.2.13 | 3.14.3 |
| 19 | hexpm/preview | yes | no: archived | 2026-07-16 | 120 | 51 | 113 | 113 | 1.18.1/27.3.4.12 | no | 1.8.9 | 1.2.5 | - |
| 20 | covalenthq/refiner | yes | yes | 2026-05-22 | 5 | 5 | 1 | 1 | 1.18.0/27 | no | 1.4.18 | - | - |
| 21 | axelclark/ex338 | yes | yes | 2026-09-09 | 50 | 24 | 0 | 24 | 1.18.3/27.3 | 1.18.3/27.3 | 1.7.21 | 1.0.11 | 3.12.5 |

(The last commit is the committer's own date. "In the table" names the table's pair that serves the head, or no. The
census counts every merged pull request of the window; [alive_census_window.tsv](alive_census_window.tsv) also has those
into the default branch.)

- **Where the history count misses pull requests:** `axelclark/ex338` and `cr0t/lexin` merge without a number (0 by
  history, 24 and 13 by the census), and `asciinema/asciinema-server` mostly so (1 against 4). The history shows 392 of
  the census's 941 in `Simon-Initiative/oli-torus` (798 of them into the default branch), 291 of 484 in `mbta/screens`
  and 182 of 452 in `santiment/sanbase2`; in the other 15 the two counts are within 10 of each other. The census decides
  `alive` wherever it exists, and here it exists for all 21.
- **Archived:** only `hexpm/preview`. Its last commit (2026-07-16) and 113 merged pull requests of the window are from
  before it was archived.
- **What the heads run** ([alive_deps.tsv](alive_deps.tsv)): Phoenix 1.8 in 18 of 21 (1.7.21 in ex338, 1.7.24 in
  youcongress, 1.4.18 in refiner); LiveView 1.x in 19 (0.19.3 in backend, none in refiner); Ecto 3.14 in 12, 3.13 in 4
  and 3.12.5 in ex338, none in jola.dev, lexin, preview and refiner; Oban in 11, Bandit in 11, Broadway in 4, Absinthe
  in 2.

How each column was counted (the reference day is 2026-11-12; the windows start on 2025-11-12 and 2026-05-12):

| Column | How |
|---|---|
| last commit | the committer date of the head of the default branch (`git log -1 --format=%cI`), from a bare clone of that branch only |
| commits, 12 and 6 months | every commit reachable from that head with a committer date in the window, the commits of merged branches included |
| merged pull requests, history | on the first-parent line of the default branch, the distinct numbers of commits whose subject is `Merge pull request #n` (a merge commit), ends in `(#n)` (a squash merge or a merge queue) or starts with `Merge #n` (a merge bot), by that commit's date. A rebase merge leaves no number, and a pull request merged into another branch counts only when that branch is merged with a number ([run/alive_history.sh](run/alive_history.sh)) |
| web-flow commits | first-parent commits of the window that GitHub itself committed (`noreply@github.com`) with no number: the mark a rebase merge made on github.com leaves, one per rebased commit |
| merged pull requests, census | the census's own count (GitHub's list of merged pull requests, read through its API by this job or the earlier ones) of pull requests merged in the window, and of those into the default branch ([run/census_window.sh](run/census_window.sh)) |
| archived | the banner of the repository's public page on github.com ([run/alive_archived.sh](run/alive_archived.sh)); the API's answer of the same morning ([state.tsv](../2026-11-12_next_ten_screen/state.tsv)) agrees for all 21 |
| Elixir and OTP | the head read the way the factory's resolver reads a starting commit (`factory/lib/eab/toolchain.ex`): `.tool-versions`, `mise.toml` or `.mise.toml`, the CI files, a `Dockerfile`, then the lower bound of the `elixir:` requirement of `mix.exs`, each version from the first file that names it; the image from `factory/config/toolchain_images.json` by prefix. The same jq port as the candidates below ([alive/heads/](alive/heads/) has the full row of each head) |
| `mix.lock` versions | the root `mix.lock` at the head; a Hex package gives its version, a git dependency `git:` and its commit ([alive_deps.tsv](alive_deps.tsv), 14 packages) |

## 2. The newest candidates

### 2.1 The screening of 19

The census ([census/](census/), one row per merged pull request, the census's columns and flags) and the screening
([screen/](screen/), one row per merged pull request: verdict, first reason, every rule that applies, the marks) of the
19 applications the pilot did not screen. The rules are the pilot's, as [docs/dataset_rules.md](../../dataset_rules.md)
section 3 writes them; the reason is the first that applies.

| Application | Merged | Candidates | no code change | no test change | bot | `mix.exs` or `mix.lock` | revert | reverted later | repaired by a later one |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Simon-Initiative/oli-torus | 5,122 | 1,751 | 2,053 | 1,120 | 0 | 155 | 0 | 0 | 43 |
| santiment/sanbase2 | 5,117 | 1,482 | 1,042 | 2,428 | 0 | 126 | 20 | 13 | 6 |
| mbta/screens | 2,468 | 505 | 1,279 | 611 | 0 | 60 | 5 | 5 | 3 |
| supabase/realtime | 1,712 | 273 | 692 | 356 | 0 | 381 | 0 | 0 | 10 |
| hexpm/hexpm | 1,404 | 557 | 396 | 350 | 1 | 79 | 0 | 0 | 21 |
| ambry-app/ambry | 1,083 | 101 | 809 | 122 | 0 | 27 | 0 | 0 | 24 |
| source-academy/backend | 696 | 204 | 358 | 91 | 0 | 35 | 1 | 1 | 6 |
| cesium/safira | 408 | 49 | 85 | 259 | 0 | 14 | 0 | 0 | 1 |
| bikebrigade/dispatch | 306 | 75 | 63 | 148 | 0 | 16 | 1 | 1 | 2 |
| blablatdinov/croniq | 232 | 24 | 181 | 20 | 0 | 7 | 0 | 0 | 0 |
| covalenthq/refiner | 220 | 13 | 148 | 43 | 0 | 13 | 0 | 0 | 3 |
| joladev/jola.dev | 176 | 7 | 153 | 12 | 0 | 4 | 0 | 0 | 0 |
| notesclub/notesclub | 167 | 53 | 52 | 42 | 0 | 19 | 0 | 0 | 1 |
| zorn/flick | 155 | 30 | 91 | 18 | 0 | 15 | 0 | 0 | 1 |
| hexpm/preview | 153 | 7 | 113 | 25 | 0 | 8 | 0 | 0 | 0 |
| cr0t/lexin | 130 | 0 | 89 | 25 | 1 | 15 | 0 | 0 | 0 |
| zorn/local_cents | 130 | 21 | 71 | 18 | 0 | 17 | 0 | 0 | 3 |
| youcongress/youcongress | 121 | 57 | 10 | 44 | 0 | 9 | 0 | 0 | 1 |
| asciinema/asciinema-server | 106 | 10 | 72 | 12 | 0 | 12 | 0 | 0 | 0 |
| Together | 19,906 | 5,219 | 7,757 | 5,744 | 2 | 1,012 | 27 | 20 | 125 |

- **Named pairs** (a later pull request names an earlier one, or both close the same issue, within the next 50 merged
  and 30 days): 731, of which 384 tested and 203 repaired. Four applications have none (asciinema-server, croniq,
  jola.dev, preview).
- **Written with an AI tool** (a mark, never a reason): 199 of the 19,906 merged pull requests and 101 of the 5,219
  candidates, 64 of those in ambry.
- [screen/summary.tsv](screen/summary.tsv) has every column (each rule that applies, the pairs, the candidates per
  year), [screen/pairs.tsv](screen/pairs.tsv) every named pair and its test.

### 2.2 The newest candidates and their pairs

Per application, the candidates from the newest merged pull request backwards, until 150 or the first merge before
2024-01-01 ([run/newest.sh](run/newest.sh)); for ex338 and nerves_hub_web the pilot's candidates
([2026-11-12_pilot_pr_screen](../2026-11-12_pilot_pr_screen/README.md), on its census of 2026-11-11). Each was read at its starting commit (the first parent
of its merge commit) the way the factory's resolver reads it, and given one class, the first that applies
([run/classes.sh](run/classes.sh)):

| Class | When |
|---|---|
| before 1.12 | the Elixir the commit names is before 1.12 (never built: E83) |
| pair missing | the image table has no Elixir/OTP pair for what the commit names (the table matches both by prefix) |
| service missing | the table has the pair, but not a service the commit's CI or `mix.exs` needs: a Postgres, ClickHouse or Redis version, or another service a CI job that runs the tests starts |
| the table has the pair | the pair and every service are in the table |

The pair is the one CI names: the resolver's reading, plus versions CI sets in an environment variable or a container
image (the earlier job's two readings); `resolver_image` in [classes/classes.tsv](classes/classes.tsv) is what the
resolver itself reads. The two differ for 33 candidates, all of backend, the gap the earlier job found: for 32 CI names
the versions in environment variables (1.13.4/25.3.2 for 25, 1.18.3/27.3.3 for 7) and the resolver reads `1.10` from
`mix.exs`; for 1 the resolver reads `1.19` from `mix.exs` and would take the table's 1.19.5/28.4.1 where CI names OTP
28.3.1.

| Application | Candidates | since 2024 | Taken | Table has the pair | Pair missing | Service missing | Before 1.12 | On Elixir below 1.18 | Taken from | to |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|
| Simon-Initiative/oli-torus | 1,751 | 1,042 | 150 | 0 | 150 | 0 | 0 | 0 | 2026-07-09 | 2026-11-11 |
| santiment/sanbase2 | 1,482 | 422 | 150 | 0 | 150 | 0 | 0 | 0 | 2026-05-29 | 2026-11-12 |
| mbta/screens | 505 | 302 | 150 | 0 | 150 | 0 | 0 | 105 | 2025-11-03 | 2026-11-09 |
| nerves-hub/nerves_hub_web (pilot) | 705 | 477 | 150 | 106 | 44 | 0 | 0 | 0 | 2026-08-21 | 2026-11-10 |
| supabase/realtime | 273 | 258 | 150 | 0 | 150 | 0 | 0 | 0 | 2026-06-24 | 2026-11-12 |
| hexpm/hexpm | 557 | 358 | 150 | 21 | 129 | 0 | 0 | 0 | 2026-09-03 | 2026-11-11 |
| ambry-app/ambry | 101 | 92 | 92 | 1 | 91 | 0 | 0 | 1 | 2024-03-21 | 2026-08-24 |
| axelclark/ex338 (pilot) | 305 | 42 | 42 | 42 | 0 | 0 | 0 | 25 | 2024-02-20 | 2026-09-09 |
| source-academy/backend | 204 | 39 | 39 | 0 | 39 | 0 | 0 | 25 | 2024-02-03 | 2026-11-10 |
| cesium/safira | 49 | 22 | 22 | 13 | 9 | 0 | 0 | 22 | 2024-01-16 | 2025-02-11 |
| bikebrigade/dispatch | 75 | 51 | 51 | 27 | 19 | 5 | 0 | 46 | 2024-01-03 | 2026-11-07 |
| blablatdinov/croniq | 24 | 24 | 24 | 1 | 23 | 0 | 0 | 1 | 2025-06-14 | 2025-07-28 |
| covalenthq/refiner | 13 | 0 | 0 | | | | | | | |
| joladev/jola.dev | 7 | 7 | 7 | 0 | 7 | 0 | 0 | 0 | 2025-08-10 | 2026-05-24 |
| notesclub/notesclub | 53 | 7 | 7 | 0 | 7 | 0 | 0 | 7 | 2024-01-06 | 2026-08-17 |
| zorn/flick | 30 | 30 | 30 | 12 | 17 | 1 | 0 | 14 | 2024-04-30 | 2026-10-28 |
| hexpm/preview | 7 | 5 | 5 | 0 | 5 | 0 | 0 | 0 | 2026-03-19 | 2026-07-15 |
| cr0t/lexin | 0 | 0 | 0 | | | | | | | |
| zorn/local_cents | 21 | 21 | 21 | 0 | 21 | 0 | 0 | 0 | 2026-07-08 | 2026-09-10 |
| youcongress/youcongress | 57 | 57 | 57 | 9 | 48 | 0 | 0 | 49 | 2024-01-06 | 2026-08-29 |
| asciinema/asciinema-server | 10 | 1 | 1 | 0 | 1 | 0 | 0 | 0 | 2026-11-05 | 2026-11-05 |
| Together | 6,229 | 3,257 | 1,298 | 232 | 1,060 | 6 | 0 | 295 | | |

- **The 232 with their pair in the table:** ex338's 42 (1.16.1/26.2.1, 1.17.2/27.0.1 and 1.18.3/27.3), nerves_hub_web's
  106 and hexpm's 21 on 1.20.3/29.0.5, dispatch's 27 on 1.15.7/26.0.2, safira's 13 and flick's 10 on 1.17.2/27.0.1,
  youcongress's 9, flick's 2 and croniq's 1 on 1.14.4/25.3.2, and ambry's 1 on 1.18.3/27.3. Of these, 127 also need
  something CI installs beyond the pair: nerves_hub_web's 106 a program from a downloaded file (97 of them Python too),
  hexpm's 21 Rust.
- **The 6 that miss only a service** need Postgres 16 (dispatch 5, flick 1); the table has 10, 14 and 18. Behind a
  missing pair, more lack a service too: oli-torus's 150 start `pgvector` (a Postgres image with that extension),
  croniq's 23 Postgres 17.5 (8 of them also Redis 8 or 6), backend's 6 Postgres 17.4, safira's 9 Postgres 11.5,
  notesclub's 7 Postgres 15.0, jola.dev's 2 Postgres 12, flick's 2 Postgres 16.
- [classes/classes.tsv](classes/classes.tsv) has one row per candidate (its starting commit, both readings, the class
  and what it lacks); [periods/](periods/) the earlier job's periods tables for the same candidates.

### 2.3 The pairs the image table lacks (registry E84)

Newest first, with the candidates each would serve ([classes/e84_pairs.tsv](classes/e84_pairs.tsv)). The pair is what
the commits name; the table matches Elixir and OTP each by prefix, so one table line can serve several rows (1.20.4/29.1.2
serves both 1.20.4 rows below, 186 candidates; 1.19.5/28.5.0.4 both 1.19.5/28.5 rows, 128).

| Pair | Below 1.18 | Candidates | Still lack a service | Applications |
|---|---|---:|---:|---|
| 1.20.4/29.1.2 | | 57 | 0 | screens 7, nerves_hub_web 44, flick 6 |
| 1.20.4/29.1 | | 129 | 0 | hexpm 129 |
| 1.20.2/29.0.4 | | 197 | 0 | sanbase2 108, ambry 80, local_cents 9 |
| 1.20.2/29.0.2 | | 38 | 0 | screens 38 |
| 1.20.2/28.5.0.3 | | 4 | 0 | local_cents 4 |
| 1.20.1/28.5 | | 8 | 0 | local_cents 8 |
| 1.20.1/28.5.0.2 | | 9 | 0 | flick 9 |
| 1.20.0/29.0.1 | | 1 | 0 | ambry 1 |
| 1.19.5/28.5 | | 5 | 0 | backend 4, asciinema-server 1 |
| 1.19.5/28.5.0.4 | | 123 | 0 | realtime 123 |
| 1.19.5/28.3.2 | | 2 | 0 | jola.dev 2 |
| 1.19.5/28.3.1 | | 3 | 0 | backend 3 |
| 1.19.4/28.4 | | 42 | 0 | sanbase2 42 |
| 1.19.4/28.3 | | 8 | 0 | youcongress 8 |
| 1.19.2/28.1.1 | | 150 | 150 | oli-torus 150 |
| 1.19.1/28.1.1 | | 7 | 0 | ambry 7 |
| 1.18.4/28.0.2 | | 5 | 2 | jola.dev 5 |
| 1.18.4/27 | | 27 | 0 | realtime 27 |
| 1.18.3/27.3.3 | | 7 | 6 | backend 7 |
| 1.18.2/27.2.2 | | 1 | 0 | ambry 1 |
| 1.18.1/27.3.4.12 | | 1 | 0 | preview 1 |
| 1.18.1/27.2 | | 5 | 0 | ambry 1, preview 4 |
| 1.18.0/27.1.3 | | 1 | 1 | flick 1 |
| 1.18/26 | | 23 | 23 | croniq 23 |
| 1.17.3/27.3.4 | yes | 105 | 0 | screens 105 |
| 1.17.3/27.0.1 | yes | 1 | 1 | flick 1 |
| 1.16.3/25.3.2.8 | yes | 4 | 4 | notesclub 4 |
| 1.16.2/26.2.3 | yes | 1 | 0 | ambry 1 |
| 1.16.2/26.2.1 | yes | 40 | 0 | youcongress 40 |
| 1.16.0/26.2.1 | yes | 1 | 1 | notesclub 1 |
| 1.16.0/25.3.2.8 | yes | 1 | 1 | notesclub 1 |
| 1.14.3/25.0.3 | yes | 1 | 1 | notesclub 1 |
| 1.14.2/25 | yes | 19 | 0 | dispatch 19 |
| 1.14.1/25.1.2 | yes | 9 | 9 | safira 9 |
| 1.13.4/25.3.2 | yes | 25 | 0 | backend 25 |

- `1.18/26` (croniq) is `mix.exs`'s lower bound with the OTP CI names: any 1.18 line with OTP 26 serves it.
- OTP 27.2 is never added to the table (its ssl rejects the package server's certificate), so `1.18.1/27.2` stays
  refused; 27.2.2 has not been tried.
- backend's `1.13.4/25.3.2` and `1.18.3/27.3.3` are named in CI's environment variables; the resolver reads `1.10` from
  `mix.exs` for those 32, so a table line alone does not serve them.
- **The heads need** 1.20.5/29.1.2 (flick), 1.20.4/29.1.2 (nerves_hub_web, screens), 1.20.4/29.1.1 (jola.dev),
  1.20.4/29.1 (hexpm), 1.20.4/29.0.6 (youcongress, lexin), 1.20.3/28.3 (croniq), 1.20.2/29.0.4 (ambry, sanbase2,
  local_cents), 1.20.2/29.0.3 (notesclub), 1.19.5/28.5.0.4 (realtime), 1.19.5/28.5 (backend, asciinema-server),
  1.19.2/28.1.1 (oli-torus), 1.19/28.1.1 (safira), 1.18.1/27.3.4.12 (preview) and 1.18.0/27 (refiner).

### 2.4 The 16 applications, from Elixir 1.18 on

While this job ran, the owner took five of the 21 off the list (`hexpm/preview` archived; `asciinema/asciinema-server`,
`covalenthq/refiner`, `cesium/safira` and `cr0t/lexin` for fewer than 10 merged pull requests in 12 months:
[2026-11-12_dataset_projects](../2026-11-12_dataset_projects/README.md)) and set a floor for every case: Elixir 1.18 or
newer, reason name `elixir_before_1.18`. [classes_16/](classes_16/) is [run/classes.sh](run/classes.sh) run again on
the same candidates for the 16 with `FLOOR=1.18`: a candidate on an older Elixir gets that class first.

| Application | Taken | Elixir before 1.18 | Table has the pair | Pair missing | Service missing |
|---|---:|---:|---:|---:|---:|
| Simon-Initiative/oli-torus | 150 | 0 | 0 | 150 | 0 |
| santiment/sanbase2 | 150 | 0 | 0 | 150 | 0 |
| mbta/screens | 150 | 105 | 0 | 45 | 0 |
| nerves-hub/nerves_hub_web | 150 | 0 | 106 | 44 | 0 |
| supabase/realtime | 150 | 0 | 0 | 150 | 0 |
| hexpm/hexpm | 150 | 0 | 21 | 129 | 0 |
| ambry-app/ambry | 92 | 1 | 1 | 90 | 0 |
| axelclark/ex338 | 42 | 25 | 17 | 0 | 0 |
| source-academy/backend | 39 | 25 | 0 | 14 | 0 |
| bikebrigade/dispatch | 51 | 46 | 0 | 0 | 5 |
| blablatdinov/croniq | 24 | 1 | 0 | 23 | 0 |
| joladev/jola.dev | 7 | 0 | 0 | 7 | 0 |
| notesclub/notesclub | 7 | 7 | 0 | 0 | 0 |
| zorn/flick | 30 | 14 | 0 | 16 | 0 |
| zorn/local_cents | 21 | 0 | 0 | 21 | 0 |
| youcongress/youcongress | 57 | 49 | 0 | 8 | 0 |
| Together | 1,270 | 273 | 145 | 847 | 5 |

- The 145 are ex338's 17 and ambry's 1 on 1.18.3/27.3, which need nothing more, and nerves_hub_web's 106 and hexpm's 21
  on 1.20.3/29.0.5, which also need what their CI installs (section 2.2).
- The 847 lack 23 pairs: the rows of section 2.3 above `1.17.3/27.3.4` without the five applications' 6 candidates
  ([classes_16/e84_pairs.tsv](classes_16/e84_pairs.tsv)), so `1.19.5/28.5` serves 4 (backend), `1.18.1/27.2` 1
  (ambry), and `1.18.1/27.3.4.12` none.

## 3. What changed from the earlier jobs' method

The screening is the pilot's ([2026-11-12_pilot_pr_screen](../2026-11-12_pilot_pr_screen/README.md)), with its scripts and
the earlier job's copies ([2026-11-12_next_ten_screen](../2026-11-12_next_ten_screen/README.md)) run unchanged. Three inputs
come another way, because the data-mining machine has no `gh`:

- **The census and metadata pages** of the 14 new applications: the earlier job's `fetch_one.sh` (and through it the
  census's and the pilot's fetch scripts) unchanged, with their two `gh` calls (`gh api graphql`, `gh api rate_limit`)
  served by [run/shim/gh](run/shim/gh), a stand-in on `curl` that reads a token from a file and never prints it.
- **The repair test's per-file patches** ([run/git_patches.sh](run/git_patches.sh)): from the blobless clones, in place
  of GitHub's REST files list. The pull request's head comes from `refs/pull/<n>/head`, and the patch is
  `git diff -M <merge commit's first parent>...<head>`, the same base...head comparison as GitHub's list, turned into
  its JSON by [run/diff_files.jq](run/diff_files.jq) so the pilot's `files.jq` and `lines.jq` read it unchanged. When the
  head is already on the base branch (a rebase merge that kept the commits), the merge commit's first parent lies inside
  the pull request's own series, so the public page `https://github.com/<repo>/pull/<n>.diff` is read instead.
  The patches the earlier job had fetched from the REST API are kept.
- **The files at each starting commit** ([run/git_tree_fetch.sh](run/git_tree_fetch.sh)): `git ls-tree` and
  `git cat-file` on the clones, written in the shape of the earlier job's GraphQL answers, so its `periods_run.sh` and
  `periods_facts.jq` read them unchanged. Its `periods_resolve.jq` is copied with one change: the resolver's Redis rule
  of public commit `1a0f888` (the table's Redis line serves a commit whose CI file or `mix.exs` needs Redis, unless CI
  names a version no line matches).

## 4. Checks

- **The earlier job's results come out the same.** The census rebuilt from the pages of the five applications whose
  pages the earlier job fetched (ambry, backend, hexpm, realtime, screens) is the published census of
  [2026-11-12_next_ten_screen](../2026-11-12_next_ten_screen/README.md), row for row, with the same summary rows; and
  backend's screen table, its rows of `summary.tsv`, `candidates_first.tsv`, `pairs.tsv` and `sensitivity.tsv` are
  the published ones.
- **The patches made with git against GitHub's own files lists** ([screen/compare_patches.tsv](screen/compare_patches.tsv),
  [run/compare_patches.sh](run/compare_patches.sh)): for 48 pull requests whose REST answer the earlier job saved (25 of
  hexpm, 23 of ambry), the files and every added and removed line the repair test reads are the same for all 48. The
  first version of the script differed for 1 of them (ambry #1234, a rebase merge whose head is the merge commit); the
  `.diff` page rule above was added for that case, and every patch was made again with it.
- **Every needed patch was made:** 463 by this job, 338 with git and 125 from the `.diff` page, none missing
  ([screen/patches_log.tsv](screen/patches_log.tsv)); the earlier job's 162 REST answers were kept.
- **The pilot's checks** ([screen/checks.txt](screen/checks.txt)): the same pull-request numbers in the same order as the
  census, and every census mention pair in `pairs.tsv`, for all 19. The pilot's second check fails for dispatch,
  screens, sanbase2 and backend because its formula leaves out pull requests rejected as reverted later; the earlier
  job's `check_ten.sh` adds that term and passes for all 19.
- **The archived flags** of the page and of GitHub's API of the same morning agree for all 21.

## Files

| File | What |
|---|---|
| [selected.tsv](selected.tsv) | the 21, by [run/select.sh](run/select.sh) (the same list as [projects.tsv](../2026-11-12_dataset_projects/projects.tsv)) |
| [alive/alive.tsv](alive/alive.tsv) | the alive table: one row per application, every column of section 1 and the `mix.lock` versions |
| [alive_history.tsv](alive_history.tsv), [alive_census_window.tsv](alive_census_window.tsv), [alive_archived.tsv](alive_archived.tsv), [alive_deps.tsv](alive_deps.tsv), [alive_clone_log.tsv](alive_clone_log.tsv) | the inputs of the alive table: the history counts, the census counts, the archived flags, the lock versions, the clones (seconds, bytes, default branch) |
| `alive/heads/periods_<owner>__<name>.tsv.gz` | each head's full reading (versions and their sources, the image, databases, services, installs, CI's test command); `periods_summary.tsv`, `periods_by_repo.tsv` |
| `census/prs_<owner>__<name>.tsv.gz` | the census of the 19 (the columns of [the pilot's census](../2026-11-11_pilot_pr_census/README.md)); `summary.tsv`; `fetch_log.txt` (each page's cost and the budget left) |
| `screen/screen_<owner>__<name>.tsv` | the screening of the 19 (the columns of [the pilot's screening](../2026-11-12_pilot_pr_screen/README.md)); `summary.tsv`, `pairs.tsv`, `candidates_first.tsv`, `sensitivity.tsv`, `checks.txt`, `patches_log.tsv` (how each patch was made), `compare_patches.tsv` |
| `periods/periods_<owner>__<name>.tsv.gz` | one row per candidate taken (the earlier job's periods columns); `periods_summary.tsv` (one row per period), `periods_by_repo.tsv` |
| [classes/classes.tsv](classes/classes.tsv) | one row per candidate taken: its starting commit, the pair CI names, the class and what it lacks, the resolver's own reading, below 1.18 |
| [classes/classes_by_repo.tsv](classes/classes_by_repo.tsv), [classes/e84_pairs.tsv](classes/e84_pairs.tsv) | the tables of sections 2.2 and 2.3 |
| `classes_16/` | the same three files for the 16 applications the list kept, with the floor of Elixir 1.18 (section 2.4) |
| `run/` | every script: `job.sh` (the stages), `guard.sh`, `select.sh`, `alive_*.sh`, `census_window.sh`, `fetch_new.sh`, `shim/gh`, `census.sh`, `run_screen.sh`, `git_patches.sh`, `diff_files.jq`, `compare_patches.sh`, `newest.sh`, `git_tree_fetch.sh`, `periods_run.sh` and `periods_facts.jq` (copies, unchanged), `periods_resolve.jq` (a copy with the Redis rule), `classes.sh` |

## Commands

On the data-mining machine, with `git`, `curl`, `jq`, `awk` (mawk 1.3.4 there), GNU `date`, `gzip` and `docker` (only
`docker ps`, for the stop rules). `WORK` is the job's folder there; `PUB` a copy of this repository (only `docs/data` and
`factory/config` are read); `SRC_RAW` the earlier job's raw pages; `GITHUB_TOKEN_FILE` a file holding a read-only token;
`BENCH_KEEP` the name of the bench container that runs all day on the machine. Each stage writes
`$WORK/logs/<stage>.log` and `$WORK/logs/<stage>.done`.

```bash
export WORK=<job folder> PUB=<copy of this repository> SRC_RAW=<earlier raw pages> BENCH_KEEP=<bench container>
export GITHUB_TOKEN_FILE=<token file>
R=$PUB/docs/data/2026-11-12_alive_and_newest_screen/run
for s in raw select clone history archived deps heads; do nice -n 19 bash $R/job.sh $s; done        # part 1
for s in fetch census screen compare newest periods classes deps heads classes16; do nice -n 19 bash $R/job.sh $s; done   # part 2
```

[run/job.sh](run/job.sh) holds every stage's command and variables. The stop rules ([run/guard.sh](run/guard.sh)),
checked before each repository: a bench container beside the standing one, a 1-minute load above 20, or less than
700,000,000,000 bytes free on `/`; and GitHub answering with a rate-limit or abuse error three times in a row
([run/shim/gh](run/shim/gh)). None of them fired.

## Provenance and licence

The tables hold repository names, pull-request numbers, merge times, public GitHub logins, labels, changed paths,
commit ids, dates, counts, toolchain and package versions and CI command lines. They hold no titles, bodies, patch text
or source code. The 21 applications are under MIT or Apache-2.0.
