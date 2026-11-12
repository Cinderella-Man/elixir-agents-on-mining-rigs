# The dataset's rules: which projects, tasks and sessions get in, and why the others are left out

One place for every rule that decides what enters the public Elixir dataset (tasks cut from merged pull requests, and
the sessions in which the teacher model solves them). Each rule has a reason name. Whatever is left out is kept in a
table with that name, so every rejection can be counted and explained. Where the owner decided a rule, the date is
given. A rule that is not built into a tool yet says so.

The order is the order of the work: a project is chosen, its pull requests are screened, a candidate is made into a
task and checked, the teacher writes its statement, the teacher solves it, and the session is kept or dropped.

## 1. Projects

The dataset is limited to 16 applications. The owner, 2026-11-12: "limit our dataset to those 21 projects and SAVE
THE RULES that lead to selecting them"; the same day a closer look took five of the 21 off (the last two rules below;
the owner: "Yes, drop them"). The list, the applications left out and the script are in
[data/2026-11-12_dataset_projects](data/2026-11-12_dataset_projects/README.md).

| Rule | It passes when | Left out as | Why |
|---|---|---|---|
| An application | it is an application of the approved batch, not a library, a framework or a tool | `not_an_application` | the model is meant for day-to-day work, and that happens inside applications that use Phoenix, Ecto, Ash, Nerves or Nx |
| A permissive licence | the repository states one of the licences of section 9 | `licence_outside_list` | every task and session republishes the project's code; without a permissive licence there is no permission to do that |
| Alive | it was pushed to in the six months before the decision (on or after 2026-05-12) | `not_alive` | a project nobody works on shows how Elixir was written, not how it is written |
| A new Elixir | its `mix.exs` asks for Elixir 1.18 or newer | `old_elixir`, `no_elixir_version` | the owner, 2026-11-12: "we should prioritize the newest elixir codebases as Elixir changed a bit - we need to use "alive" repositories" |
| Not held out | it is none of the Elixir SWE Bench's 12 projects (absinthe, accent, ash, beacon, cachex, guardian, live_beats, livebook, operately, pinchflat, plausible-analytics, vutuv) | `held_out` | the model is judged on that bench; nothing that shapes it may come from there |
| Not archived | the repository is not archived on GitHub | `archived` | nobody works on it any more |
| Works through pull requests | it had at least 10 merged pull requests in the 12 months before the decision | `too_few_pull_requests` | a case is cut from a merged pull request; a project that is pushed to directly gives none |

No task, statement, session or screening is made for a project outside the list.

## 2. Versions

- **The project:** `mix.exs` asks for Elixir 1.18 or newer (section 1).
- **The task:** it is built on the Elixir and OTP of its own starting commit, read from the commit's files
  (`.tool-versions`, the CI workflow, `mix.exs`). That pair must be in the factory's image table
  (`factory/config/toolchain_images.json`, 36 pairs on 2026-11-12, the newest 1.20.5 with OTP 29.1.2; E84). A commit on a
  pair the table lacks is left out as `no_image:<elixir>/<otp>` until the pair is added; pairs are added newest first.
- **Never built:** Elixir before 1.12 (the engine's Hex install does not support it) and OTP 27.2 and 27.1.3 (their ssl
  rejects the package server's certificate, so the image cannot install Hex).
- **The order inside a project:** from the newest merged pull request backwards.
- **The task's floor:** a task is left out as `elixir_before_1.18` when the Elixir it is built and checked on is
  older than 1.18, also inside a chosen project (the owner, 2026-11-12: "Yes, 1.18+ only"). A candidate on such a
  commit is not made into a task.

## 3. Pull requests

A merged pull request is a candidate unless one of these rules rejects it; the first that applies is its reason. The
rules read paths, authors and titles, not the code.

| Left out as | When | Why |
|---|---|---|
| `no_code_change` | no changed code file (`.ex`, `.heex`, `.eex`, `.leex` under `lib/`) | nothing for a model to write |
| `no_test_change` | code changed, but no `_test.exs` file under `test/` | the task's hidden tests are the pull request's own tests; without them a solution cannot be judged |
| `bot` | the author is a bot | version bumps and generated changes, not development work |
| `dependency_only`, `docs_only`, `ci_only` | every changed file is a manifest or lock file, documentation, or under `.github/` | no application code |
| `mix_files` | it changes `mix.exs` or `mix.lock` | the task's environment is built before the change, and a changed dependency set would need another environment after it |
| `revert`, `reverted_later` | it is a revert, or a later pull request reverts it | the project itself took the change back |
| `repaired_by` | a later pull request repairs it | the change had a bug. The follow-up is kept as its own task (the owner, 2026-11-12: "Yes, do that"); the pairs are counted |

Recorded on a candidate and never a reason to reject: written with an AI tool (the owner, 2026-11-12: "I don't see
the point of avoiding "co-authored by Claude""), adds a migration, touches `assets/`.

## 4. Tasks

A candidate becomes a task folder (the starting commit, the reference fix, the hidden tests) and must pass the
factory's gate. Each drop names the step and the cause, and a cause is one of three kinds: the pull request's own, the
factory's, or the machine's. Only the first is a verdict on the pull request; the other two are fixed and run again.

| Check | Dropped when | Whose cause |
|---|---|---|
| The task folder is valid | a patch touches a folder it may not, a test command is not an explicit `mix test`, or the repository is held out | the pull request's, or the maker's |
| The source rebuilds exactly | the starting commit plus the three patches does not give the merged tree | the maker's |
| The environment builds | `no_image` (section 2), `needs_service:<name>` (a service the engine does not run; Postgres, ClickHouse and Redis are run), a package that can no longer be downloaded, a missing system program | the factory's |
| The unchanged project fails a hidden test in the test's own body | `no_starting_failure`: the hidden tests pass before the fix, or cannot run at all | the pull request's |
| The failing tests are the same in every run | the set of failures changes between runs | the pull request's (an unstable test) |
| The reference fix passes | the hidden or the existing tests fail on the merged tree: they need the network, the clock or a service, or `no_existing_tests` is left to protect | the pull request's |
| No hidden test is skipped | `skipped_test`: a hidden test is one the project marks as skipped (`@tag :skip`). It is not a failure of the reference fix, but the grader passes no skipped test (`factory/README.md` section 2.2), so no fix could pass the task; the probe drops it before the controls (registry E86) | the pull request's (its changed test file holds the skipped test) |
| An early exit is rejected | the project's test command can report success without running the tests | the project's |
| A partial fix is rejected, where the task has one | a half-done fix passes the hidden tests | the pull request's (weak tests); the task stays without the control |
| A second round agrees | a named test ends differently in a fresh container | the pull request's |

Then two scans, on every checked task:

- **Licence, per file** (`factory/tools/task_licence.py`): every file the fix or the tests touch must be under the
  project's own permissive licence. `fail` when a touched file carries another licence notice or is a third-party
  file kept in the repository (`exclude:vendored`, for example a minified JavaScript library under `assets/vendor/`);
  binary files are left out of the task.
- **Hold-out** (`factory/tools/task_holdout.py`): the repository and the names in the task are not a held-out
  project's, and the task shares no run of 8 or 12 words with the bench's 20 cases other than boilerplate. A shared
  run that is not boilerplate is `review` and is read before the task is used.

A task may depend on a held-out library, or on a dependency whose licence is outside the list (the owner,
2026-11-12: "Yes, that rule"): the task's own code is the application's. What that means for a session is in section 6.

## 5. Statements

The statement is the text the model is given as its assignment.

- **The teacher model writes it,** from the fix and the hidden tests, which the solver never sees (decided
  2026-11-12). No statement by any other writer is used, and none is edited, trimmed or repaired by hand.
- **The voice** (the owner, 2026-11-12: "actually real-world ones as developer would type, unless it's a feature, then
  assume quite a lot of text"): a developer typing a request to a coding agent in their own repository. A bug fix or a
  small change is short and plain. A feature is long and detailed, as a developer writes it after being questioned
  about every decision: the goal, the settled behaviour with examples, the edge cases, what is out of scope, and the
  names the rest of the code will use.
- **The leak check:** a statement is rejected as `leak` when it gives the fix away: a line or an identifier that
  exists only in the fix, a hidden test's name, the name of a file or function the fix adds and the tests do not use.
  It is asked for again, at most 3 times; after that the task is `no_statement` and is not run.

## 6. Sessions

A session is the teacher's whole attempt at one task: its messages, its tool calls and what the tools returned.

**Kept** when the attempt ended as completed and its patch passes, each step in a fresh container:
1. the patch changes only files under the task's allowed folders, is at most 1 MiB and adds no symbolic link or
   submodule;
2. the existing tests and the model's own tests pass with the patch;
3. the hidden tests pass, and every required test is among them;
4. the existing tests pass again;
5. the model's own tests, alone on the unchanged project, fail at least once.

**Dropped although its patch passed** when its text may not be published or would leak the bench:

| Left out as | When | Why |
|---|---|---|
| `quotes_dependency_outside_licence_list` | the session read or printed a file of a dependency (under `deps/`) whose licence is not in section 9, or that has no licence | the session would republish that code, and there is no permission for it. The task itself stays |
| `quotes_held_out` | the session read or printed a file of a held-out project's own package (for example Ash's files in an application built on Ash) | the bench's projects must stay unseen (the owner, 2026-11-12) |

These two scans run on every kept session before it is published. They are not built yet: no session has been made.

**When a session fails** (the owner, 2026-11-12: "what happens if DeepSeek can solve only 5 out of 16 cases? We don't
know is this the faulty case or faulty DeepSeek?"; decided the same day: "Yes, add it"). A failed session alone does
not say whose fault it is. Before the teacher runs, every case is known to have a fix that passes; what is not known is
whether its description says everything the hidden tests want. So after every run each failed session is sorted:

| The fault is | When | What happens |
|---|---|---|
| the machine's (`machine_fault`) | a time-out, a tool error, the server not answering | the case is run again; the session does not count as an attempt |
| the description's (`description_gap`) | the failing test wants something the description does not say: an exact name, a message, a rule | the teacher writes the description again with the gap named, it passes the leak check again, and the case is run again |
| the teacher's own (`teacher_failure`) | the description was fair and the work was wrong or unfinished | the case gets up to 3 attempts |

A case that fails 3 attempts with a fair description gets one blind attempt by a second strong model, as a tie-breaker
only: that attempt is never training data. If it fails too, the case is set aside as `not_solvable_from_description`.
The rounds are repeated until the failures that remain are the teacher's own, as the bench's own cases were run until
every fault of a case was caught.

## 7. Balance

Decided by the owner on 2026-11-12 ("Yes, add them"), so that no project and no kind of work dominates the dataset.

| Rule | Left out as | Why |
|---|---|---|
| **No project gives more than 15 of the first 100 cases,** and no more than 15 % of the cases after that. Inside a project the newest cases are kept | `over_project_cap` | a model trained mostly on one code base learns that code base. In SWE-smith's test at a fixed 700 sessions, 4, 25, 50 and 100 repositories gave better results each time ([paper](https://arxiv.org/abs/2504.21798), section 4.1) |
| **Neither bug fixes nor features fall under 30 % of the cases.** The kind is the task's `task_kind`. When one kind is short, cases of the other kind wait until it catches up | `over_kind_share` | both kinds of work must be well represented. No study read gives a right ratio, so this is a guard, not a target |
| **At most 3 kept sessions per case** | `over_session_cap` | easy cases are solved again and again, and many copies of them made the trained model worse; SWE-smith keeps at most 3 per task for that reason (section 4) |

No study read tests a cap per project or a ratio of kinds; the first two numbers are the owner's choice on a proposal.
A case left out by a cap is not lost: it enters when the dataset grows.

## 8. What is recorded

Nothing is dropped silently. For every project, pull request, candidate, statement and session that is left out, a
table keeps its id and the reason name of this page, and the counts per reason are published with the data.

## 9. Licences

| | Licences |
|---|---|
| In the list | MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC (ISC added by the owner on 2026-11-12) |
| Outside the list | copyleft and weak copyleft (GPL, AGPL, LGPL, MPL, EPL), no licence at all, a custom or unclear licence text, and any other licence until it is read and added |

**A licence stated in the README counts when the repository has no licence file at its root** (the owner, 2026-11-12:
"Yes, accept it", for hexpm/hexpm, which states Apache-2.0 in its README and has no licence file). The statement must
name a licence of the list in plain words and be the maintainers' own; the file, the commit and the sentence are
recorded with every case of that project as the proof. A licence file, where there is one, still decides.

The list is applied three times: to the repository (section 1), to every file a task touches (section 4) and to every
dependency file a session quotes (section 6). The dataset's own licence: third-party code keeps its licence, named
per row with the notices shipped; the licence of the owner's own part is not final (the owner leans to MIT). This page
is not legal advice.

## 10. Where each rule runs

| Rule | Tool or file |
|---|---|
| Projects | `docs/data/2026-11-12_dataset_projects/run/select.sh` on the pool table |
| Pull requests | the screening scripts of `docs/data/2026-11-12_pilot_pr_screen/` |
| Versions | `factory/lib/eab/toolchain.ex`, `factory/config/toolchain_images.json` |
| The gate | `factory/README.md` section 4; `bin/factoryctl check` |
| Licence and hold-out of a task | `factory/tools/task_licence.py`, `factory/tools/task_holdout.py` |
| Statements and the leak check | the statement tool under `factory/tools/` |
| Sessions kept | `factory/README.md` section 2.2; `bin/factoryctl kept_sessions` |
| Sessions dropped for what they quote | not built yet |

## 11. Open points

- Sixteen ex338 tasks were built on the project's 1.18.3 image before the maker read each commit's own Elixir and OTP;
  the pair each of those commits declares is being listed.
- The two session scans of section 6 are to be built before the first session is published.
- The licence tool reads only a root licence file: it does not yet accept a README statement (section 9), so
  `hexpm/hexpm`'s cases fail it until that is added.
