# The dataset's projects: 16 applications (2026-11-12)

Registry row [E82](../../../experiments.md). Decided by the owner on 2026-11-12: "limit our dataset to those 21
projects and SAVE THE RULES that lead to selecting them". Training tasks and sessions come from these projects only;
work on any other project stopped the same day. The list was 21 at first; a closer look the same day took five
off (rules 6 and 7), also on the owner's word ("Yes, drop them").

## The rules

A project is in the dataset when it passes all of these, tested on the pool table of approved applications
([`approved_app_first_batch.tsv`](../2026-11-09_elixir_project_pool/approved_app_first_batch.tsv), read from GitHub
on 2026-11-09):

1. **It is an application,** not a library or a framework (`group` is `application`). The day-to-day work the model
   is meant for happens inside applications.
2. **Its licence is permissive:** MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause or ISC, as the repository states it
   (`licence`). The licence of every file a task touches is checked again per task, at the task's commit.
3. **It is alive:** pushed to in the six months before the decision (`last_pushed` on or after 2026-05-12).
4. **It is on a new Elixir:** its `mix.exs` asks for Elixir 1.18 or newer (`mix_elixir`). The owner: "we should
   prioritize the newest elixir codebases as Elixir changed a bit - we need to use "alive" repositories".
5. **It is not held out:** none of the Elixir SWE Bench's 12 projects (the approved batch already leaves them out).
6. **It is not archived** on GitHub.
7. **It works through pull requests:** at least 10 merged pull requests in the 12 months before the decision. A case
   is cut from a merged pull request, so a project without them gives none.

Inside a project, candidates are taken from the newest merged pull request backwards.

## Result

Of the 53 approved applications 21 pass ([`projects.tsv`](projects.tsv)). The other 32 are in
[`left_out.tsv`](left_out.tsv), each with the first rule it fails: 13 were not pushed to since 2026-05-12, 16 ask for
an older Elixir, and 3 state no Elixir version in `mix.exs`.

| Project | Licence | `mix.exs` asks for | Merged pull requests | Last pushed |
|---|---|---|---:|---|
| Simon-Initiative/oli-torus | MIT | ~> 1.19 | 5,116 | 2026-11-09 |
| santiment/sanbase2 | MIT | ~> 1.19 | 5,112 | 2026-11-09 |
| mbta/screens | MIT | ~> 1.20 | 2,468 | 2026-11-09 |
| nerves-hub/nerves_hub_web | Apache-2.0 | ~> 1.20.0 | 2,455 | 2026-11-09 |
| supabase/realtime | Apache-2.0 | ~> 1.19 | 1,687 | 2026-11-09 |
| hexpm/hexpm | Apache-2.0 | ~> 1.20 | 1,402 | 2026-11-08 |
| ambry-app/ambry | MIT | ~> 1.18 | 1,083 | 2026-11-09 |
| axelclark/ex338 | MIT | ~> 1.18 | 749 | 2026-09-10 |
| source-academy/backend | Apache-2.0 | ~> 1.19 | 695 | 2026-11-09 |
| bikebrigade/dispatch | Apache-2.0 | ~> 1.20 | 306 | 2026-11-07 |
| blablatdinov/croniq | MIT | ~> 1.20 | 232 | 2026-10-28 |
| joladev/jola.dev | MIT | ~> 1.18 | 175 | 2026-11-09 |
| notesclub/notesclub | MIT | ~> 1.20.2 | 163 | 2026-11-05 |
| zorn/flick | MIT | ~> 1.20.5 | 155 | 2026-11-08 |
| zorn/local_cents | MIT | ~> 1.20 | 130 | 2026-11-01 |
| youcongress/youcongress | MIT | ~> 1.18 | 121 | 2026-11-09 |

## What the rules read, and what they do not

- `last_pushed` is GitHub's date of the last push to any branch, as read on 2026-11-09.
- `mix_elixir` is the lowest Elixir a project accepts, not the one it runs. podlove/radiator asks for `~> 1.17` and
  is left out by rule 4, although its newest checked tasks were built on Elixir 1.20.3.
- hexpm/hexpm states Apache-2.0, and the pool table found no licence file at the root of the repository
  (`licence_file_reads_as`). The per-task licence scan decides for each of its tasks.
- Rules 6 and 7 are not columns of the pool table. They were read for the 21 by the screening job
  (`2026-11-12_alive_and_newest_screen`): the archived mark from GitHub, and the merged pull requests of the 12 months
  from GitHub's own list (ex338: 24). The smallest count among the 16 is 22.

## Files

| File | What it holds |
|---|---|
| `projects.tsv` | the 16, with the pool table's columns: mirror, licence, licence file, merged pull requests, share of Elixir, what it uses, the `mix.exs` requirement, service dependencies, last push |
| `left_out.tsv` | the 32 other approved applications, each with the first rule it fails |
| `dropped_after_closer_look.tsv` | the five that pass rules 1 to 5 and fail rule 6 or 7 |
| `run/select.sh` | the selection, as it ran |

## Commands

On the data-mining machine, in a folder that holds the script and the pool table:

```sh
sh select.sh approved_app_first_batch.tsv 2026-05-12 chosen   > projects.tsv
sh select.sh approved_app_first_batch.tsv 2026-05-12 left_out > left_out.tsv
```

## Provenance and licence

The pool table was read from GitHub's public metadata on 2026-11-09
([2026-11-09_elixir_project_pool](../2026-11-09_elixir_project_pool/README.md)). These files hold repository names
and counts only, no code of any project.
