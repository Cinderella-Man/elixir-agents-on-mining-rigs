# notesclub/notesclub: no case on Elixir 1.18 or newer (2026-11-12)

`notesclub/notesclub` is one of the dataset's 16 applications ([rules](../../dataset_rules.md); MIT). This job was to
set the project up in the task factory and check its pull requests as cases, newest merged first, until it had 20
good cases or its candidates on Elixir 1.18 or newer ran out. They run out before the first: the project has **no
candidate on Elixir 1.18 or newer**, so no case was made, no recipe was written and no controller was started. Every
reading below ran on the data-mining machine, read only, from the screening's tables
([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)) and its clone of the project.
Times of the readings are the data-mining machine's (UTC+1); merge times are GitHub's (UTC).

## Result

- **0 good cases, 0 of each kind.** Of the screening's 53 candidates (every merged pull request of the project that
  changes code and tests and passes the other rules of the rules page's section 3), all 53 are left out at the
  versions step as `elixir_before_1.18`, the pull request's own cause. None was made into a case, so no step of the
  gate, no scan and no kind applies.
- **The project moved to Elixir 1.18 or newer on 2026-08-17,** in pull request 241 (commit `cd4c9d7`): its
  `.tool-versions` went from Elixir 1.16.3 with OTP 25.3.2.8 to Elixir 1.20.2 with OTP 29.0.3, the versions its head
  still names (head `9d6e25e`, 2026-11-11). The newest candidate, 236, was merged eight hours before that, on
  Elixir 1.16.3.
- **None of the 13 pull requests merged from the upgrade on is a candidate** (the upgrade's own included): 8 change
  no code, 3 change code but no test, and the 2 that change both code and tests also change `mix.exs` or `mix.lock`
  (`mix_files`). The reasons are the screening's, by the rules page's section 3.
- **Most of the project's work since the upgrade went in without a pull request.** Of the 47 commits on the main line
  from the upgrade to the head, 16 change both a code file under `lib/` and a test file under `test/`; 2 of those are
  the pull requests 242 and 243 above, and 14 were pushed directly. A case is cut from a merged pull request (rules
  page, sections 1 and 3), so the 14 are not candidates.
- **The project gives cases** when a pull request merged on Elixir 1.18 or newer changes code and tests without
  changing `mix.exs` or `mix.lock`. The factory's image table holds the head's pair (Elixir 1.20.2 with OTP 29.0.3).

## The upgrade

`.tool-versions` on the main line (`tool_versions.tsv`), as the toolchain resolver reads it first:

| Commit | Date | Elixir | OTP |
|---|---|---|---|
| `de05203` | 2022-11-05 | not read (the file's text is not in the clone) | - |
| `8ba8d9e` | 2023-02-18 | 1.14.3 | 25.0.3 |
| `67e5b78` | 2024-01-21 | 1.16.0 | 26.2.1 |
| `b996999` | 2024-05-04 | 1.16.0 | 25.3.2.8 |
| `1803c81` | 2025-05-05 | 1.16.3 | 25.3.2.8 |
| `cd4c9d7` (pull request 241) | 2026-08-17 | 1.20.2 | 29.0.3 |

## The candidates

`candidates.tsv`, newest first. The seven newest are the ones the screening resolved (2024 on); for them the Elixir
read from the starting commit's `.tool-versions` equals the screening's.

| Pull request | Merged (UTC) | Elixir / OTP of the starting commit | Verdict |
|---:|---|---|---|
| 236 | 2026-08-17 08:39 | 1.16.3 / 25.3.2.8 | left out, `elixir_before_1.18` |
| 225 | 2025-09-06 15:18 | 1.16.3 / 25.3.2.8 | left out, `elixir_before_1.18` |
| 222 | 2025-08-25 19:25 | 1.16.3 / 25.3.2.8 | left out, `elixir_before_1.18` |
| 221 | 2025-08-23 15:16 | 1.16.3 / 25.3.2.8 | left out, `elixir_before_1.18` |
| 198 | 2024-08-09 22:32 | 1.16.0 / 25.3.2.8 | left out, `elixir_before_1.18` |
| 190 | 2024-04-28 18:00 | 1.16.0 / 26.2.1 | left out, `elixir_before_1.18` |
| 182 | 2024-01-06 10:19 | 1.14.3 / 25.0.3 | left out, `elixir_before_1.18` |

| Basis of the verdict | Candidates |
|---|---:|
| The starting commit's `.tool-versions` names Elixir 1.14.3, 1.16.0 or 1.16.3 | 22 |
| No version read (no `.tool-versions` at the commit, or its text not in the clone), merged on or before 2023-02-16, before Elixir 1.18.0 was released (2024-12-19) | 31 |
| Not decided | 0 |
| **All, left out as `elixir_before_1.18`** | **53** |

52 of the 53 merge commits are in the history before the upgrade; the 53rd, pull request 58 (merged 2022-10-30), has
a merge commit that is not in the clone's history, and was merged before Elixir 1.18 existed.

## The pull requests merged from the upgrade on

`since_upgrade.tsv`, with the screening's verdict (rules page, section 3: the reason is the first rule that applies;
all rules that apply are listed).

| Pull request | Merged (UTC) | Code files | Test files | Reason | All rules that apply |
|---:|---|---:|---:|---|---|
| 241 | 2026-08-17 17:03 | 0 | 0 | `no_code_change` | no_code_change, no_test_change, mix_files |
| 242 | 2026-08-17 19:04 | 1 | 1 | `mix_files` | mix_files |
| 243 | 2026-09-05 17:04 | 3 | 2 | `mix_files` | mix_files |
| 244 | 2026-09-05 17:04 | 1 | 0 | `no_test_change` | no_test_change |
| 245 | 2026-09-26 12:24 | 0 | 0 | `no_code_change` | no_code_change, no_test_change, mix_files |
| 251 | 2026-10-22 18:31 | 0 | 0 | `no_code_change` | no_code_change, no_test_change, bot, dependency_only, mix_files |
| 252 | 2026-10-26 20:00 | 0 | 0 | `no_code_change` | no_code_change, no_test_change, dependency_only, mix_files |
| 258 | 2026-10-27 19:26 | 2 | 0 | `no_test_change` | no_test_change, mix_files |
| 264 | 2026-11-03 19:02 | 0 | 0 | `no_code_change` | no_code_change, no_test_change, dependency_only, mix_files |
| 268 | 2026-11-11 18:38 | 0 | 0 | `no_code_change` | no_code_change, no_test_change |
| 266 | 2026-11-11 18:41 | 0 | 0 | `no_code_change` | no_code_change, no_test_change, bot, dependency_only, mix_files |
| 265 | 2026-11-11 19:20 | 0 | 0 | `no_code_change` | no_code_change, no_test_change, bot, dependency_only |
| 267 | 2026-11-11 19:27 | 1 | 0 | `no_test_change` | no_test_change, bot, mix_files |

Counts by reason: `no_code_change` 8, `no_test_change` 3, `mix_files` 2.

## What was not done

- No recipe (`factory/recipes/notesclub__notesclub.json` does not exist): a recipe is worked out at the newest usable
  candidate's starting commit and proven by preparing it, and there is none.
- No controller, image or container, no run of the project's test suite, no case folder, no licence scan and no
  hold-out check. Nothing was downloaded.

## Files

| File | What it holds |
|---|---|
| `summary.tsv` | the counts: the upgrade (commit, date, pull request, versions before and after), the head, the candidates by verdict and basis, the pull requests and commits from the upgrade on |
| `tool_versions.tsv` | every main-line commit that changed `.tool-versions`: commit, date, the file's blob, the Elixir and OTP it names |
| `candidates.tsv` | the screening's 53 candidates: number, merge time, merge commit, starting commit and where it came from, the Elixir and OTP of its `.tool-versions`, the screening's reading, merged before the upgrade, verdict, step, reason, whose cause, basis |
| `since_upgrade.tsv` | the 13 pull requests merged from the upgrade on, with the screening's verdict, reason, rules and file counts |
| `code_and_tests.tsv` | the 16 main-line commits from the upgrade on that change a code file and a test file, with the pull request whose merge commit it is, or `-` |
| `run/versions.sh` | the script that wrote them |

## Commands

On the data-mining machine, as the factory's user. `SCREEN` is the screening's output folder (`screen/`, `census/`,
`periods/`), `CLONE` its blobless clone of the project; `GIT_NO_LAZY_FETCH` keeps the reading from fetching anything.

```sh
SCREEN=<the screening's out folder> CLONE=<its clone of notesclub/notesclub> REPO=notesclub/notesclub OUT=out \
  nice -n 19 run/versions.sh
```

It ran in 4 s (17:58:01 to 17:58:05), at a 1-minute load of 6.05, with 653,019,475,968 bytes free on `/`.

## Licence

The project is MIT. These tables hold only pull-request numbers, dates, commit and blob ids, version numbers and file
counts from the project's public history; no title, description or code of the project.
