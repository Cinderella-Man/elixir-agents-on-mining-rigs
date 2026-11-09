# The Elixir project pool (2026-11-09)

A list of the Elixir repositories on GitHub that training tasks could be mined from, with each one's licence, size and
trust signals. Only metadata was read: nothing was cloned, and no project code ran. Registry row:
[E46](../../../experiments.md). What the tiers are for, and how tasks are made from these projects:
[the guide](../../research/notes/task_collection_guide.md).

**Result.** GitHub lists 1,182 Elixir repositories with 100 or more stars. 929 of them are candidates:

| Tier | What it means | Repositories | Merged pull requests | With a `test/` folder at the root |
|---|---|---:|---:|---:|
| A | permissive licence, a code base, not archived, created before 2024, and 1,000 or more stars or a Hex package with 10,000,000 or more downloads | 171 | 64,766 | 165 |
| B | the same with 300 or more stars or 1,000,000 or more downloads, created before 2025 | 264 | 28,782 | 251 |
| C | every other permissive candidate: fewer stars, newer, archived, or learning material and templates | 494 | 59,556 | 438 |
| check:licence | a custom or unclear licence text | 16 | 8,641 | 11 |
| check:no_licence_file | no licence file under the usual names | 140 | 13,047 | 99 |
| out:copyleft | GPL, AGPL, LGPL or MPL | 52 | — | — |
| out:holdout | the bench's projects and other repositories of their organisations | 45 | — | — |

- Tiers A, B and C together: 929 repositories and 153,104 merged pull requests; 242 repositories have 100 or more
  merged pull requests and 59 have 500 or more; 546 were pushed to since 2025; 62 are archived.
- Licences among the 929, as GitHub names them: MIT 587, Apache-2.0 196, ISC 9, BSD-3-Clause 9, Unlicense 5,
  BSD-2-Clause 3, CC0-1.0 2, MIT-0 1, 0BSD 1. For 116 GitHub named none; 73 of those are permissive by their Hex
  package's metadata and 43 by the first lines of their licence file. These 116 need the per-file scan before use.
- [first_wave.tsv](first_wave.tsv) is the 40 tier-A repositories with the most merged pull requests: 51,592 between
  them.

## The approved first batch

**The first wave was approved on 2026-11-09 as the first batch to build training tasks from, under MIT, Apache-2.0 and
BSD licences only.** [approved_first_batch.tsv](approved_first_batch.tsv) checks each of the 40 against that rule at
today's default branch and adds what building it will need:

| Kind | Repositories | Merged pull requests |
|---|---:|---:|
| Applications | 7 | 19,630 |
| The language | 1 | 8,267 |
| Frameworks | 7 | 10,158 |
| Libraries | 22 | 11,426 |
| Tools | 3 | 2,111 |

- **Licences:** 20 are MIT and 20 are Apache-2.0. 37 state it in a licence file at the root. Three do not: `nx` keeps
  its licence files inside its three package folders (read: `nx/LICENSE`; the other two are still to read), `nerves`
  uses a `LICENSES` folder (its documentation and logo are under other terms and stay out), and `postgrex` has no
  licence file, only the Apache-2.0 notice in its README.
- **Mixed languages:** 8 repositories are less than 80 % Elixir (firezone 63.4 %, phoenix_live_view 57.8 %, hologram
  57.7 %, papercups 59.3 %, ex_doc 71 %, farmbot_os 71 %, petal_components 72.3 %, phoenix 79.4 %). Pull requests
  that touch no Elixir give no task, so these yield less than their counts suggest.
- **Services:** 11 name a database driver in `mix.exs` (two of them are drivers themselves): Postgres most often,
  logflare also ClickHouse. kafka_ex needs a Kafka broker and wallaby a browser driver for their integration tests.
- **To look at before use:** anoma (33,549 stars against 898 merged pull requests) and papercups (Elixir 1.11.3 and
  OTP 23, last pushed 2024-02-15).

## The mirrors

All 40 were forked on 2026-11-09 into the maintainer's GitHub account, where the bench's forks already are
([mirrors.tsv](mirrors.tsv)). Each fork's default branch pointed at the same commit as its upstream when checked,
and that commit is recorded. No fork has an active workflow: GitHub leaves a new fork's workflows off until its
owner turns them on. A mirror keeps the commits reachable if a project is deleted or rewritten; tasks point at commit
ids, and no branch is made per task.

## Applications against libraries

Most real use of an Elixir model is work inside an application that uses Phoenix, Ecto, Ash, Nerves or Nx, not work on
those frameworks themselves. [usage_kinds.tsv](usage_kinds.tsv) classes every repository from its `mix.exs` and
folders: an application has no Hex package, depends on a framework, and has a web folder or database migrations.
The classes are a reading of signals, not a review.

| | Applications that use the frameworks | Libraries, frameworks and tools | Other |
|---|---:|---:|---:|
| The 40 forked | 6 | 32 | 2 |
| The 929 usable candidates | 63 | 761 | 105 |

- **The 6 in the first batch:** firezone, logflare, supabase/realtime, supabase/supavisor, papercups and farmbot_os,
  with 18,732 of the batch's 51,592 merged pull requests (firezone alone 10,976).
- **The 63 usable applications** hold 34,589 merged pull requests; 26 of them have 100 or more, 34,019 between them.
  The 761 libraries, frameworks and tools hold 89,603.
- **What the 63 use:** Phoenix 62, Ecto 40, LiveView 35, Oban 12, Broadway 3, Ash 2, Absinthe 2, Nerves 1, Nx 0.
- **57 more applications are outside the usable set:** 24 are copyleft and 33 need their licence read.
- **Stars undercount applications:** oli-torus has 119 stars and 5,116 merged pull requests. Repositories below 100
  stars are not in this list at all.
- For scale, 15 of the Elixir SWE Bench's 20 cases come from applications and 5 from libraries.

## What the columns mean

| Column | Meaning |
|---|---|
| `tier` | as above |
| `merged_prs` | merged pull requests (GitHub, 2026-11-09); the raw material for tasks, not a count of tasks |
| `test_dir`, `mix_exs` | whether the default branch has `test/` and `mix.exs` at its root; "no" often means an umbrella or a mixed-language repository |
| `licence_github` | GitHub's SPDX id; `NOASSERTION` and `none` mean GitHub could not tell |
| `licence_class` | `permissive` (GitHub's id), `permissive_per_hex` (the Hex package's licences), `permissive_per_file` (the licence file's first lines), `copyleft`, `weak_copyleft`, `check`, `none` |
| `kind_guess` | `learning_or_template` when the name or description reads like a list, a course, exercises, an example or a starter; a guess from words, not a review |
| `holdout` | `bench` for a project of the Elixir SWE Bench, `same_org` for another repository of such a project's organisation |
| `hex_package`, `hex_downloads` | the most downloaded Hex package whose links name this repository, among Hex's 1,500 most downloaded; 0 means no match, not no downloads |

## What this list is not

- **Not a safety check.** Stars, age and downloads lower the odds of a hostile project. They do not make its code
  safe to run. Every project's code runs only in the sandbox the guide describes.
- **Not a licence clearance.** The licence that counts is the one in the repository at a task's commit, read file by
  file. This table reads today's default branch.
- **Not a task count.** In two public pipelines, 1.7 % and 2.5 % of pull requests became verified tasks (100,000 of
  6,000,000 in Scale-SWE; 2,294 of about 90,000 in SWE-bench). At those rates the 929 candidates would give est.
  2,600 to 3,800 tasks from real pull requests, before planted bugs.

## Files

| File | What it holds |
|---|---|
| [projects.tsv](projects.tsv) | all 1,182 repositories, one row each, sorted by stars |
| [first_wave.tsv](first_wave.tsv) | the 40 tier-A repositories with the most merged pull requests |
| [approved_first_batch.tsv](approved_first_batch.tsv) | the approved 40: kind, licence and where it was read, Elixir share, toolchain, service dependencies, notes |
| [first_batch_hand.tsv](first_batch_hand.tsv) | the hand-written columns of that table: kind, licence, notes |
| [mirrors.tsv](mirrors.tsv) | each approved repository's fork, its default branch, the commit it pointed at when forked, and its active workflows |
| [usage_kinds.tsv](usage_kinds.tsv) | every repository outside the hold-out: application or library, the frameworks it uses, the signals behind the class |
| [run/gather.sh](run/gather.sh) | reads GitHub's repository search and Hex's package list |
| [run/build.sh](run/build.sh) | one row per repository, with the licence class and the hold-out mark |
| [run/prs.sh](run/prs.sh) | merged pull requests, the two root checks and the licence files' first lines |
| [run/tier.sh](run/tier.sh) | the tiers and the final table |
| [run/first_batch.sh](run/first_batch.sh) | per approved repository: language shares, root entries, the licence file's first lines, `mix.exs`, `.tool-versions` |
| [run/approve.sh](run/approve.sh) | joins those checks with the hand-written columns |
| [run/mirror.sh](run/mirror.sh) | forks every approved repository into the logged-in account and checks each fork |
| [run/classify.sh](run/classify.sh) | reads `mix.exs` and the folders of every repository and writes the usage classes |

## Commands

```bash
export OUT=pool
bash run/gather.sh && bash run/build.sh && bash run/prs.sh && bash run/tier.sh
LIST=first_wave.tsv bash run/first_batch.sh && DATA=. DATE=2026-11-09 bash run/approve.sh
DATA=. DATE=2026-11-09 bash run/mirror.sh
DATA=. bash run/classify.sh
```

## Provenance

- GitHub's REST search (`language:Elixir stars:>=100`, three star ranges) and GraphQL API, read 2026-11-09 with `gh`.
  A repository whose main language GitHub counts as something else is not in the list.
- Hex's public API, `packages?sort=total_downloads`, pages 1 to 15, read 2026-11-09.
- The descriptions are the repositories' own. The hold-out list is the bench's twelve upstream projects.
- Licence: the tables and scripts in this folder are under this repository's MIT licence.
