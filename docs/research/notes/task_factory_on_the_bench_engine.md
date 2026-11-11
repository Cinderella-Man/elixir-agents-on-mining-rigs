# A task factory on the bench's engine: the design for the pilot (2026-11-11)

How the [Elixir SWE Bench](https://github.com/Cinderella-Man/elixir-swe-bench)'s own engine and curation lessons can
make training tasks from merged pull requests, for the pilot on three applications (registry row
[E68](../../../experiments.md)): `nerves-hub/nerves_hub_web`, `axelclark/ex338` and `podlove/radiator`.

This is a design note. Nothing was built and no project code ran. It rests on:
- the bench's documents and engine source at commit `28c064ca`;
- the 20 case folders;
- the sizes of the bench's prepared images on the maintainer's laptop;
- the metadata of the latest 200 merged pull requests of each pilot repository.

The counts and the commands behind them are in
[docs/data/2026-11-11_task_factory_design](../../data/2026-11-11_task_factory_design/README.md). It builds on the
[task collection guide](task_collection_guide.md), which explains tasks, sessions, licences and safety from the start.

## The short answer

1. **The engine already does the hard parts.** It prepares a project at an old commit and then works offline. It
   starts Postgres with the migrated database. It runs tests by name and tells a failed assertion from a failed
   set-up. It checks a task with four controls, grades a patch against hidden tests, and runs an agent under Pi while
   saving every request and response. All of it can be called by a script, without the website (section 1).
2. **A machine can make most of one task's bundle:** the manifest, the provenance record, the three patches, the
   early-exit control and the test names. It cannot make the statement, the requirement texts or the independent
   review, and it cannot always make the partial fix (section 2).
3. **There are two routes.** The engine still reads its older bundle format, which needs none of those four parts
   and no change to the bench. The current format has the stronger checks, but needs three small changes to the
   bench before machine-made tasks can run under it. The changes are listed with their files; none was made
   (section 2.4).
4. **The gate keeps every check a machine can run** and drops the ones a person did. The risk that remains is a
   wrong fix that passes the hidden tests and enters the training data. After hand curation the bench still found
   that in 16 of its 20 cases, and a pull request's own tests are weaker than a curator's (section 3).
5. **Screening can reject most pull requests from metadata alone.** In the samples, 110, 64 and 100 of the latest
   200 merged pull requests change both code and tests and come from a person (section 4). A follow-up fix is found
   by its reference to the earlier pull request or by the lines it changes. It ends in one of three ways: one task
   from both, a task of its own, or both dropped.
6. **The statement is the open decision.** The bench's tickets were written by its curator, so that method is closed
   by the rule against Claude's text in training data. Pull-request text is closed by the guide's licence rule. In
   `nerves_hub_web` it is also mostly Claude's: 107 of 110 recent code-and-test pull requests carry Claude Code's
   footer (section 5).
7. **It has to run on the 7-GPU machine,** as a second controller with its own checkout and its own data. The laptop
   must not build or test, and the engine does both wherever its controller runs. The bench's runbook puts 20
   prepared cases at about 24 GB of images (est.) plus 1.2 GB of source archives, and asks for about 100 GB free
   during a cold preparation. No preparation time is on record (section 6).
8. **The same engine can run the teacher.** It ran DeepSeek-V4.1-Flash-1017 for the published 16 of 20. Training
   tasks go into the second controller, which never holds the 20 bench cases (section 7).
9. **The sister repo adds what the bench lacks:** a licence scan per file, checks that every text has an approved
   writer, a check against held-out text, and the dataset export (section 8).
10. **The pilot is eleven kinds of single-job session** (section 9). The first can start with no further decision:
    screen the three repositories' pull requests from metadata, with no project code run.

## Words used here

- **Bundle:** the folder of files that defines one task for the engine.
- **Hidden tests:** tests the model never sees. They are applied after it finishes and decide pass or fail.
- **Control:** a patch whose outcome is known in advance, graded to check the task itself. The bench uses four: no
  change, the reference fix, the reference fix plus an early exit, and a partial fix.
- **Starting failure:** a hidden test that fails on the unchanged project, inside the test's own body.
- **Statement:** the text the model is given as its task. The bench calls it the ticket.

## 1. What the engine already does

Paths are in the bench's repository.

| A task factory needs | The engine's part | What it does |
|---|---|---|
| A project at an old commit, usable offline | `lib/eab/source.ex`, `Eab.Source.snapshot/4` | Fetches one commit by its id, checks the commit and its tree hash, refuses submodules, removes the Git history, and keeps a tar archive per repository and commit. Later uses need no network. |
| Proof that the fix is the real one | `lib/eab/provenance.ex`, `Eab.Provenance.verify/3` | Fetches the commit before and the commit after. Applies the reference patch, the test patch and the documentation patch to the first, and requires exactly the second's tree. |
| The right Elixir, dependencies and a compiled project | `lib/eab/fixtures.ex`, `Eab.Fixtures.ensure/3` | Builds an image from a pinned `hexpm/elixir` image: Git and build tools, a non-root user, a pinned Hex, `mix deps.get`, the compile, the case's set-up commands, and one fresh commit as the workspace. A later commit of the same project starts from an earlier build (a "build seed"). Downloaded packages are cached. |
| Postgres with the project's schema | `lib/eab/service_images.ex`, `lib/eab/baseline.ex`, `lib/eab/database_seed.ex` | Pins the database image by digest. Runs the case's baseline commands once, such as `mix ecto.create --quiet` and `mix ecto.migrate --quiet`, then saves the database as an image. Every later container starts from that image. A later commit reuses the nearest saved database and applies only the missing migrations. Supported services: Postgres and ClickHouse. |
| A locked container per use | `lib/eab/sandbox.ex`, `Eab.Sandbox.with_box/4` | A new container with no network, all capabilities dropped, 4 GB of memory, 2 CPUs and 512 processes; Postgres beside it with 1 GB and 1 CPU. Removed afterwards. |
| Tests run by name | `lib/eab/test_adapter.ex`, `Eab.Grader.run_tests/3`, `priv/fixtures/grade_formatter.exs` | Runs an explicit `mix test` command with the engine's own reporter. Every test comes back as passed, failed or excluded. A failure is marked as in the test's body or in its set-up. A run that stops early is not counted as complete. |
| The controls | `lib/eab/grader.ex`, `Eab.Grader.qualify/3` | Grades four patches in fresh containers: none, the reference, the reference with an early exit, and the partial fix. The task is valid when the first fails in a test body, the second passes, and the third and fourth are rejected. The receipt is tied to the image, the database, the case files and the grading code. |
| Grading a patch against hidden tests | `Eab.Grader.grade/4` | Checks the patch's paths against the allowed ones. Applies it in a fresh container and runs the model's tests with the existing ones. Puts the original tests back, applies the hidden tests and runs them. Puts the tests back again and runs the existing tests. Then checks that the model's own new test fails on the unchanged project. |
| A store for drafts | `lib/eab/candidates.ex`: `import/1`, `review/2`, `qualify/3`, `export/2` | Keeps each draft bundle as an unchangeable version, outside the scored cases. `qualify` runs the source check, the preparation and the controls with no model. |
| An agent, with everything kept | `lib/eab/agent.ex`, `lib/eab/pi.ex`, `lib/eab/pi_gateway.ex` | Starts Pi 1.2.0 inside the container. The controller alone talks to the model and saves each request, each streamed response and its token counts. Pi's messages, tool calls and tool results are saved too, and the patch after every turn. |
| A whole run | `lib/eab/runs.ex`, `lib/eab/runner.ex`, `lib/eab/checkpoints.ex`, `lib/eab/evidence.ex` | One attempt per case over the folder of cases, prepared ahead, graded apart from the attempt, with sealed receipts for the patch and for the grade. A stopped run can resume. |
| Disk kept under control | `lib/eab/retention.ex` | Records which images each case needs, refuses new builds below a free-space reserve (5 GB by default), and removes a case's images only when nothing else uses them. |

**How it is called without the website.** The bench's documents call these curator and developer functions, and its
own curation used them from scripts in two ways:
- inside the running controller: `bin/eab rpc 'Code.eval_file("<script>.exs")'`
  (`verification/case-curation-2026-10-20/ash-pr-3031/README.md`);
- as a script in the tooling image, which starts the engine's two helper processes itself and then calls, for
  example, `Eab.Qualification.run/2` (`scripts/qualify_promoted_cases.exs`).

A model run is started by `Eab.Runs.start(endpoint, key, settings, opts)`, the same call the website's Run button
makes. `Eab.Model.discover(url, key)` builds the endpoint from a server's address.

## 2. The smallest bundle the engine accepts for one pull request

### 2.1 Two formats

- **The current format** (`schema_version: 2`). All 20 cases use it. A case folder holds `case.json`,
  `provenance.json`, `ticket.md`, `reference.patch`, `reference-tests.patch`, `acceptance.patch`, `incomplete.patch`,
  `integrity.patch` and, once admitted, `admission.json`. Some also hold `upstream-tests.patch` and
  `upstream-docs.patch`.
- **The older format** (no `schema_version`). The first cases used it. The engine still reads it
  (`lib/eab/task_contract.ex`, `legacy/1`), and two bundles in it remain under `cases_rejected/`. A folder holds
  `case.json`, `provenance.json`, `ticket.md`, `reference.patch`, `acceptance.patch` and optionally
  `reference-tests.patch`. The early exit is built into the engine. The partial fix is one entry in `case.json`
  (`partial_repair_probe`): "this one file of the reference only", or a text replacement in the reference.

**The older format is the smallest bundle the engine accepts today:** five required files and the test patch. It has
no requirement texts, no review and no admission file.

### 2.2 Part by part

| Part | Can a machine make it? | How, or what stands in the way |
|---|---|---|
| `case.json`: repository, commit, test commands, allowed paths | yes | From the pull request and a recipe per project. The allowed paths are the folders the pull request touches. |
| `case.json`: the environment (`runtime`, `services`, `baseline`) | mostly | One recipe per project and period, from `.tool-versions`, `mix.exs` and the CI file. 9 of the 20 cases also list hand-made preparation files in their fork (a test helper, a script for a native library, a lock file), and the lessons describe a tenth (Ash). |
| `provenance.json`: the two commits and their tree hashes | yes | Read from Git. The starting commit is the first parent of the merge commit, not the branch point GitHub reports: the lessons record a branch point that held unrelated changes. |
| `reference.patch`, `reference-tests.patch` | yes | The pull request's diff, split by path into code and tests. The split must rebuild the merged tree exactly, or the source check fails. |
| `acceptance.patch` (the hidden tests) | yes, weaker | The pull request's own tests. The bench's curators wrote their own, and strengthened them four times (section 3). |
| The names of the tests that must fail first and pass after | yes | They are observed, not guessed: run the hidden tests on the unchanged project and on the reference, then write the names down. The lessons warn that a guessed list spoils the controls. |
| `integrity.patch` (the early exit) | yes | A fixed file: 17 of the 20 cases share one identical 134-byte patch that adds a file calling `System.halt(0)`. The older format has it built in. |
| `incomplete.patch` (a partial fix) | sometimes | For a fix in several files: drop one file, or one hunk, and keep the first variant that compiles and fails a starting failure in a test body. For a one-hunk fix there is nothing to drop. The share is not known. |
| `ticket.md` (the statement) | no | It needs a writer (section 5). The engine accepts any text. |
| The requirement mapping (`grading.requirements`) | no | Every required test must be mapped to a sentence, and those sentences are added to the model's prompt. A machine can do the mapping, but not write the sentences. Only the current format asks for it. |
| The review record | no | Approval needs an author, a different reviewer and two statements that a person read the requirements before the tests. Recording that for a machine would be a false record. Only the current format asks for it, and only for export and for runs. |
| Prepared fork branches and the draft pull request | not needed | The engine fetches any commit by its id from any GitHub repository. A plain task can point at the project's own repository and pull request. A branch is needed only for a fix assembled from two pull requests (section 4.3) or for a preparation change. |
| A reference fix corrected by the curator | no | 9 of the 20 cases record a curator's extension or correction of the upstream fix. A machine uses the upstream fix as it is. |

### 2.3 What that means

- **Route A, no change to the bench: the older format.** Everything in a bundle is machine-made except the
  statement. The gate is weaker in one place: the engine checks that some hidden test fails on the unchanged project,
  but does not compare the failing tests with a declared list. The factory's own script can do that comparison
  outside the engine. Every task is announced to the model as a bug fix, features included, because the older format
  has no task kind. No current case exercises this path, and it was not run for this note.
- **Route B, the current format with changes to the bench.** The checks are the bench's own, in full. It needs
  changes 1 to 3 below, because today a bundle without a partial fix cannot pass, a bundle without requirement
  sentences cannot load, and a case without a reviewed admission cannot enter a run.
- **Both routes can be mixed:** make and check tasks in the current format through `Eab.Candidates.qualify/3`, which
  needs no review, and hand them to the teacher in the older format. Then the same task exists in two files that
  must be kept in step.

### 2.4 Changes the bench would need (none made; each is the maintainer's call)

| # | File | What stands in the way today | The change | What happens without it |
|---|---|---|---|---|
| 1 | `lib/eab/grader.ex` (`valid_controls?/5`), `lib/eab/candidates.ex` (`validate!/1`) | A task with no working partial fix can never be valid. | A recorded, per-case choice to skip the partial control. | Tasks with no machine-found partial fix are dropped, or made in the older format with the same limit. |
| 2 | `lib/eab/task_contract.ex` (`validate!/1`, `instructions/1`) | The current format requires requirement sentences, and adds them to the prompt. | Allow a task kind with no requirement sentences. | An approved writer writes one sentence per task, or the older format is used. |
| 3 | `lib/eab/candidates.ex` (`export/2`), `lib/eab/release.ex` (`freeze/0`) | A current-format case enters a run only with an approved, independent review. | A second kind of admission: checked by machine, not reviewed, for training only, never part of a bench release. | The teacher's runs use the older format. |
| 4 | `lib/eab/provenance.ex` (`validate!/2`), `lib/eab/preparation.ex` (`number/1`) | The pull request must belong to the same repository the commit is fetched from. A mirror has the commits but not the pull requests. | Accept the upstream pull request beside a mirror's address. | Tasks fetch from the upstream repository. The mirror stays a backup, and the source archive is kept after the first fetch. |
| 5 | `lib/eab/fixtures.ex` (`dockerfile/4`) | The system packages in the image are a fixed list. `nerves_hub_web`'s CI installs `xdelta3` and `mtools` for some tests. | A list of extra packages per case. | Those tests are left out by their tag, or the tasks that need them are dropped. |
| 6 | `lib/eab/sandbox.ex` (`start/2`), `lib/eab/fixtures.ex` (`build/3`) | The engine labels its containers its own way and caps each at 2 CPUs. It has no setting for an extra label or a low CPU share, which the 7-GPU machine's house rules ask for. | Extra labels and a CPU share from the environment. | The maintainer allows the engine's containers as they are. |
| 7 | `Dockerfile` (`COPY cases cases`) | The set of runnable cases is built into the controller's image. Every change of the set is a rebuild. | Read the cases from a mounted folder. | One rebuild per batch of tasks. Drafts in the candidate store need none. |

Changes 1, 2 and 6 touch files that are part of the grading identity (`grader.ex`, `task_contract.ex`, `sandbox.ex`).
After such a change every one of the 20 cases is checked again before its next run. The engine does that by itself
(ADR 0012), and it costs one pass of controls. A change to the image recipe (5 or 6) also forces every case's image to be
built again, unless the recipe it writes for the existing cases stays the same byte for byte.

## 3. The gate for a training task against the bench's gate

The bench's gate was built so that a score is fair. A training task needs less: a kept session must be real, correct
work on a task that could be solved from what the model saw.

| Check | The bench | A training task | What dropping it risks |
|---|---|---|---|
| The source pair rebuilds exactly | yes | **keep** | — |
| The unchanged project fails a hidden test in the test's body, not in set-up or compile | yes | **keep** | Tests that "fail" only because a file does not compile prove nothing. Feature pull requests whose tests need a new struct or macro fail this check and are dropped; the bench solved those by hand. |
| The reference fix passes the hidden tests and the existing tests | yes | **keep** | — |
| An early exit is rejected | yes | **keep** (it is free) | — |
| A partial fix fails a named starting failure | yes | **keep where a machine can make one** | Hidden tests that a half-fix passes. The kept session may then hold a half-fix. |
| The failing tests are the declared ones | yes | **keep** (observed in a first run, then fixed) | A task whose failures change from run to run. |
| The model's own new test fails on the unchanged project and passes after its change | yes | **keep** | Without it a session need not contain a test. The bench asks every model for one, so the student should see it done. The cost is yield: a right fix with no such test is not kept. |
| Three fresh rounds of controls with the same named outcomes | yes | **two rounds**, the second for the unchanged project and the reference only | An unstable test keeps a wrong session or throws away a right one. Whether two rounds are enough is measured in the pilot: the count of tasks whose outcome changes between rounds. |
| The receipt is tied to the image, the database and the grading code | yes | **keep** (the engine does it) | — |
| An independent person reads the requirements before the tests | yes | **drop** | A statement that does not justify what the hidden tests demand. The teacher then fails more often, which costs attempts. It does not make a kept session wrong. |
| Every hidden test is mapped to a stated requirement | yes | **drop**, or one coarse sentence | The same. |
| Two blind passes by a strong model | yes | **drop** as a gate | A task nobody can solve stays in the pool and wastes attempts. The teacher's own pass takes this role: a task with no passing attempt gives no session. Tasks never solved are audited before more attempts are spent (registry Q527). |
| A person reads every passing patch and tries the wrong solutions the tests should reject | yes, four times over | **drop**; replaced by the two measures below | **A wrong or partial fix that passes the hidden tests is kept as a training example.** |
| A frozen release, three-run series, validation runs kept unpublished | yes | not applicable | — |

**The lesson that matters most.** The bench's first full validation run passed 19 of 20 cases. The review of those
passes found that in 16 cases a plausible wrong or partial solution also passed every check, or the reference itself
failed a stated requirement. The next three reviews changed 15, 9 and 8 cases. Those were hidden tests written and
reviewed by a curator. A machine-made task has only the pull request's own tests.

The recurring gaps the bench names are exactly what a pull request's tests tend to have: test data that happens to
agree with a wrong rule, only one path exercised, a form changed but never submitted, short and plain inputs only, a
value changed but never changed back, an assertion that cannot fail.

So some kept sessions will hold fixes that are wrong and still pass. Three things limit that without a person
reading every patch:
- **the partial-fix control,** which is one wrong solution built by machine;
- **a test-strength probe** (new, registry E69): apply the reference fix, change one token at a time inside the
  lines the fix added, using Elixir's own parser as the sister repo's tool does, and count how many of those wrong
  variants the hidden tests reject. A task whose tests reject few is dropped or marked;
- **a read of a sample:** a reader the maintainer approves compares a random sample of kept sessions with the
  reference fixes. That gives the share of wrong fixes as a number, per project.

The second review also found that two earlier passes would have failed the corrected checks. A pass is evidence
that a patch passed these tests, not that it is right.

## 4. Screening rules for pull requests

### 4.1 What the three repositories look like

The latest 200 merged pull requests of each, from GitHub's metadata on 2026-11-11
([table and commands](../../data/2026-11-11_task_factory_design/README.md)). "Code" is a file under `lib/` ending in
`.ex`, `.heex`, `.eex` or `.leex`. "Test" is a file under `test/` ending in `_test.exs`. The query lists at most
100 files per pull request; one pull request in each sample reached that limit.

| | nerves_hub_web | ex338 | radiator |
|---|---:|---:|---:|
| Merged pull requests in all (the pool table, 2026-11-09) | 2,455 | 749 | 252 |
| The sample was merged between | 2026-09-10 and 2026-11-10 | 2022-07-31 and 2026-09-09 | 2019-06-17 and 2026-11-10 |
| By a bot | 63 | 86 | 32 |
| By a person | 137 | 114 | 168 |
| — changing code and tests | 110 | 64 | 100 |
| — changing code, no test | 7 | 34 | 43 |
| — changing tests only | 5 | 4 | 4 |
| — changing neither | 15 | 12 | 21 |
| Of those changing code and tests: 1 code file | 26 | 11 | 10 |
| 2 to 5 code files | 45 | 27 | 36 |
| more than 5 code files | 39 | 26 | 54 |
| adding a database migration | 20 | 10 | 43 |
| touching `assets/` | 7 | 6 | 13 |
| touching `mix.exs` or `mix.lock` | 4 | 13 | 12 |
| with an issue that GitHub says the pull request closes | 3 | 15 | 20 |
| with a description shorter than 20 characters | 0 | 16 | 44 |
| median length of the description, characters | 1,978 | 108 | 65 |
| with Claude Code's "Generated with" footer in the description | 107 | 10 | 7 |

`nerves_hub_web` merged 200 pull requests in two months, and almost all of its recent descriptions were written by
Claude Code. In the same repository's pull requests merged from 2023-01-01 to 2024-12-31 (at most 300 fetched), 69
by a person change code and tests, none carries the footer, and the median description is 209 characters.

These counts are of metadata only. They are an upper bound on usable pull requests, not a yield.

### 4.2 The rules

From the bench's `docs/pr-selection-guidelines.md` and `docs/benchmark-expansion-plan.md`, kept to what GitHub's
metadata and the diff can show.

**Reject:**
- no code change or no test change;
- a bot as author;
- typo-only, formatting-only, generated, documentation-only or CI-only changes; mechanical upgrades;
- a change to `mix.lock`, or to the dependencies in `mix.exs`: the workspace is offline and holds the old
  dependencies;
- a revert, a backport or a duplicate of another pull request; a pull request that was later reverted;
- unrelated changes in one pull request;
- work whose only claimed result is speed;
- anything that needs a cloud account, a private package, or a service other than Postgres or ClickHouse;
- a submodule change, a symbolic link, or a patch larger than 1 MiB: the engine refuses them; and binary files;
- a project among the bench's 12 or their sibling repositories (E12), and a commit whose licence is not MIT,
  Apache-2.0 or BSD (E51).

**Prefer:**
- 2 to 5 code files that have to agree with each other, counted without tests. This is the bench's main group. Some
  one-file tasks are kept as a smaller share; a large pull request is not good for its size alone;
- one recognisable problem or capability, with a linked issue where there is one;
- tests at the boundary the change affects: a controller, a LiveView or a context function, not only a helper;
- the kinds of work the bench wants covered: Phoenix and LiveView interactions, Ecto queries and constraints, OTP
  process state, background jobs, serialization and authorization.

**Mark and report apart, at least in the pilot:**
- pull requests that add a migration. The prepared database holds the starting commit's schema, so the project's
  test alias has to run the new migration;
- pull requests that touch `assets/`;
- pull requests whose description says an AI tool wrote them (new, registry E70);
- pull requests merged after the base models' training cut-off, which go to the dev lane (E53).

**What screening cannot see** and the gate decides: whether the environment builds at that commit, whether the tests
fail in a test body, and whether the reference passes.

### 4.3 A buggy pull request, and a fix spread over two

The bench's rule: check the follow-up fixes that are specifically identified, record what was decided, and do not
search without end. In Ash, three flagged follow-ups concerned other behaviour and stayed out of the reference. A
fix found wanting is corrected in a separate, recorded commit. Unrelated pull requests are never combined. 9 of the
20 cases carry such a correction or extension, so an upstream fix that is not quite right is common, not rare.

**How to detect a follow-up, by machine.** For each kept pull request, look at later merged pull requests, bounded
to the next 50 merged or the next 30 days, whichever ends first, for any of these:
1. its title or description names the earlier pull request's number, or the same issue;
2. it changes lines that the earlier pull request added, or tests that it added;
3. it reverts the earlier pull request's commit;
4. the issue was reopened after the earlier merge.

**What to do with a pair.**

| Finding | The task |
|---|---|
| The follow-up concerns other behaviour | Keep the first pull request alone and record the decision. |
| The first was reverted and not merged again | Drop it. |
| The first was reverted and merged again in a new form | Use the later form and drop the first. |
| The follow-up repairs the first one's own new code, and both apply cleanly to the first one's starting commit with nothing else in between touching the same files | **One task from both:** the starting commit of the first, and a reference that holds both. The follow-up's tests join the hidden tests. |
| The same, but they do not apply cleanly, or the follow-up is larger than the first, or there are three or more in the chain | **No combined task.** The first pull request is dropped as a task. |
| In that last case, the follow-up alone | **A task of its own:** the project after the first pull request has a real bug, and the follow-up is its fix with its tests. This is the cheapest kind of bug-fix task. It is made only when the combined task was not, so no fix appears twice. If it fails the gate too, both are dropped. |

**One cost of combining.** The engine's source check needs a real commit whose tree is the reference. For two pull
requests with other work between them, that commit has to be made on a branch of the mirror (the starting commit,
plus the first, plus the second). This is the one case where a task needs a branch, against the guide's "no branch
per task". With a mirror as the source, change 4 of section 2.4 is needed as well. How many tasks this affects is not
known; if they are few, dropping them is simpler than building for them.

## 5. The statement

**Where the bench's tickets came from.** They were written during curation. They were not copied from the pull
request or the issue: the guidelines forbid the pull request's number, the root cause, file names and solution steps
in a ticket. A second reader then checked that each one states everything the hidden tests demand. The curation
sessions ran on an AI model, and the current rule names Claude (`docs/case-curation-loop.md`). Who wrote each single
ticket was not checked. In the 20 cases:
- the 12 bug-fix tickets are 53 to 1,044 bytes long, for example "I can't change a site's domain as an Editor; fix
  it.";
- the 8 feature tickets are 366 to 10,884 bytes; the long ones are full specifications;
- each case adds 2 to 6 requirement sentences and a note about the environment to the prompt;
- 3 cases record an upstream issue. One case's record says that an AI agent wrote the upstream pull request's text.

**What a training task can use without a curator.** Five options. This note does not choose.

| Option | For | Against |
|---|---|---|
| A. The pull request's title and description, as they are | Free and authentic. | The guide rules it out: comments on GitHub are licensed for viewing there, not for a dataset. They describe the fix, so they give the answer away. Many are empty (median 108 and 65 characters in two of the three samples). In `nerves_hub_web`'s recent ones the text is Claude's. |
| B. The commit message or the title alone | It is part of the repository, so it stands under the repository's licence more clearly than a comment does. That is a reading, not legal advice. | Short, often names the fix, and may be written by an AI tool too. |
| C. The linked issue's text | It is the real report of the problem, the closest thing to a bench ticket. | The same licence doubt as A. Few pull requests have one: 3 of 110, 15 of 64 and 20 of 100. |
| D. A statement written by an approved writer from the change and the failing tests | The guide's current rule (section 3.4), with a check that rejects statements that give the fix away (Q480, Q526). | The writer is not named yet. The writer reads the fix, so leaks have to be caught. It costs model time per task. |
| E. One template, approved once, filled with the names of the failing tests | The cheapest. The sister repo makes its statements this way. | The statement shows the hidden tests' names, which tells the model much of what to do. It is unlike the tickets the student meets on the bench. |

**What is already decided:**
- no text written by Claude goes into training data, and every text needs a writer the maintainer has approved;
- the statement is not the issue's or the pull request's discussion text (the guide, sections 3.4 and 8);
- everything in a task must be publishable.

**What is open:** who the writer is, and whether option B is allowed. The same answer is needed for the
requirement sentences on route B and for the hints of E55.

**Texts that are in every session whatever is chosen.** The engine adds its own fixed instructions to each prompt:
the task kind, the test command, the rule about adding a test, the allowed paths and the budget
(`lib/eab/task_contract.ex`, `lib/eab/agent.ex`). Pi adds its system prompt and tool descriptions (Pi is MIT). These
are the same texts the student will see on the bench. Whether they may stand in published training sessions is the
maintainer's decision; who wrote the engine's sentences was not checked. The bench's per-case environment note can
be left empty for a training task.

## 6. Where it runs and what it costs

**Where.** The bench's controller is a Docker Compose service on the maintainer's laptop. The controller builds the
images and starts the test containers on the machine it runs on, through that machine's Docker. Building and testing
are exactly what the laptop must not do. So the factory needs a controller on the 7-GPU machine.

**Disk, from the 20 prepared cases.**
- The bench's runbook: one installation's 20 cases held about 24 GB of images, estimated from layer history, plus
  1.2 GB of source archives. It asks for about 100 GB free during a cold preparation, because of the build cache.
  That is est. 1.2 GB of images per case, across 12 different projects.
- `docker images` on the laptop, 2026-11-11. The laptop holds several generations of each case, so there are more
  images than cases. Docker counts shared layers in every image, so these sizes do not add up:

| Kind of image | Distinct images | Smallest | Median | Largest |
|---|---:|---:|---:|---:|
| Toolchain (Elixir, build tools, Hex) | 33 | 0.77 GB | 0.90 GB | 3.35 GB |
| Project at one commit (toolchain, source, dependencies, compiled) | 58 | 0.82 GB | 1.07 GB | 3.53 GB |
| Project with Pi attached | 74 | 1.19 GB | 1.44 GB | 3.89 GB |
| Saved Postgres database | 22 | 406 MB | 493.5 MB | 704 MB |
| Saved ClickHouse database | 9 | 727 MB | 936 MB | 945 MB |

  The largest toolchain and project images belong to the one case with a browser.
- Per extra commit of a project already prepared: est. 0.17 GB for the workspace layer (the median project image
  minus the median toolchain image) and est. 0.37 GB for Pi (the median image with Pi minus the median project
  image). Whether Docker shares the Pi layer between images was not checked. For hundreds of tasks in one project
  the real figure is what the pilot measures.

**Preparation time.** Not on record. The bench's repository holds no preparation timings, and its own rules say
that build and test durations from the laptop are not evidence. Each build writes a log in the controller's data
volume, which was not opened for this note. What the code bounds: one hour per image build, 20 minutes per baseline
command, and 240 seconds per test command unless the case sets more (the 20 cases set 300, 600 or 900). One round
of controls is est. 13 test commands in 5 fresh containers, each waiting for Postgres to start (counted from
`lib/eab/grader.ex`, not measured).

**What a second controller on the 7-GPU machine needs.** The maintainer removed the bench's copy from that machine
on 2026-11-10 to save space, so each of these is a decision:
- Docker with Compose and Buildx, a checkout of the bench, and `docker compose up --build -d`;
- its own folder name, so that Compose gives it its own data volume, and its own inventory name in
  `config/benchmark.json`, so that nothing it writes can be read as a bench result;
- a `cases/` folder without the 20 bench cases. Drafts live in the candidate store and need no case folder;
- the internet during preparation: base images for each Elixir version, a Postgres image, Hex packages and the
  source commits. Those are downloads, which need the maintainer's word;
- disk for Docker's images and for the data volume: est. 100 GB free to start, by the runbook's figure for 20 cases;
- memory collection switched off (`EAB_MEMORY=off`) or given a login to the model's host: the runbook says a run
  does not start when collection is set up and cannot connect;
- the machine's house rules against the engine's behaviour: the engine labels and limits its containers its own way
  (change 6);
- the website listens on `127.0.0.1` only. Scripts do not need it; to look at it, a tunnel.

## 7. The teacher's sessions

**Can the same engine run DeepSeek on training tasks, apart from the 20 cases?** Yes.
- It has already run this teacher. The published 16 of 20 is DeepSeek-V4.1-Flash-1017 (Unsloth UD-IQ1_M,
  250,404,346,724 bytes) under Pi 1.2.0, served by Strata, with a budget of 65,536 generated tokens, at most 8,192
  per response and a 262,144-token window. That run used 28,736 generated tokens and 46.3 model calls per passed
  case ([the read of the published runs](../../data/2026-11-09_bench_runs_read/README.md)).
- A run covers the cases in the controller's `cases/` folder. In the second controller that folder holds training
  tasks only, so the two sets never share a release, a receipt or a run.
- A run makes one attempt per case. Several attempts per task are several runs with different seeds, or
  `Eab.Runs.repeat_cases/3` for chosen tasks.
- Current-format tasks need change 3 to enter a run; older-format tasks do not.
- Failed attempts are saved too, which gives the pass rate per task.

**The files that make up one kept session,** under `runs/<run>/<task>/` in the controller's data:

| File | What it holds |
|---|---|
| `prompt.md`, `instructions.md` | the statement, and the engine's fixed instructions |
| `pi-config.json` | Pi's version, the model's name and the settings |
| `request-NNNN.json`, `response-NNNN.sse`, `usage-NNNN.json` | every model call: the full request with the history and the tool definitions, the raw streamed answer with the reasoning, and the token counts |
| `pi-events.jsonl` | Pi's own record: messages, tool calls and tool results |
| `model.patch` | the patch that was graded |
| `attempt.json` | the status, the number of calls, the generated tokens and why it stopped |
| `grade.json` | the full grading output: every test, in every stage |
| `submission.json`, `checkpoints/<task>.json` | sealed receipts: the patch's hash, the environment, the grade's hash |
| `runtime.json`, `qualification.json` | the exact image and database, and the task's controls |
| `activity.log`, `build.log` | the readable log of the attempt and of the preparation |

A session is kept when `attempt.json` says `completed` and its grade says `passed`. The last request and its answer
hold the whole conversation. Turning that into the student's chat format is a separate step outside the engine (the
requests are in Strata's message format).

## 8. What to reuse from the sister repo's generator

The sister repo's `bench/agentic_data` makes publishable agent sessions on Elixir's standard library. The two tools
answer different questions. The bench's engine proves that a session ran as recorded, on which image, and with
which grade. The sister's gate proves that every byte of a session may be published.

| Sister repo's part | Reuse | Overlap with the bench's engine |
|---|---|---|
| `license_scan.py`: a verdict per file (the project's own licence, another permissive one, copyleft, vendored, binary) | **As it is,** on each project's tree at the task's commit and on its dependencies. A session that read a file without a passing verdict is left out. | None. The bench has no licence check; one of its projects is AGPL, which is fine for a benchmark and not for a training set. |
| `gate.py`: a chain of records from code base to dataset, each naming its parents by hash | **The checks, not the stages.** Reusable as they are: an approved writer for every text; licence or copyright lines in tool output that are not in the workspace; paths outside the workspace; machine paths in a row. The stages read the sister's own session format, so a stage that reads the bench's run folder is new code. | The bench has its own chain (release, control receipt, sealed patch and grade). It covers how a session ran, not whether it may be published. Both are needed. |
| `heldout_check.py`: no run of 8 or 12 words shared with held-out tests | **For E12:** tasks, statements and sessions against the 20 cases' tickets, requirement sentences and hidden tests. | None. |
| `export.py`: the dataset layout, with `LICENSE`, `LICENSES/`, `NOTICE` and a card | **The layout and the notice builder.** The session reader is new. | None; the bench exports results, not datasets. |
| `sandbox/Dockerfile.elixir`, `sandbox/tools.py` | **No.** One image with Elixir 1.18.4, no dependencies and no database: it cannot build a Phoenix application. | The bench's preparation and containers replace it. |
| `sandbox/ex_tool.exs`: one-token changes made with Elixir's parser | **Yes,** for the test-strength probe of section 3, and for planted bugs (Q478). | None. |
| `tasks.py`: planted bugs and removed function bodies, statements from filled templates | Not for pull-request tasks. Its template mechanism is option E of section 5. | None. |
| `agent.py`: the sister's own agent loop | **No.** The teacher should work in the harness the student is judged in, which is Pi under the bench's engine. | The bench's Pi runner replaces it. |

**Where the bench's containers differ from the guide's safety rules** (guide, section 9). They have no network, no
secrets, a non-root user, memory and process limits, a fresh container per use and a one-commit workspace. Two
points differ: the root file system is writable, and the dependencies are compiled during the image build, while the
network is still on. The guide asks for the network during the download only.

## 9. The pilot as single-job sessions

Each is one job with one result, sized to stay under about three hours. A run that may take longer is started
detached, and a fresh session records it. Times are unknown until measured, except where marked.

| # | The job | Runs on | Needs first | Done means | It measures |
|---|---|---|---|---|---|
| P1 | Screen the three repositories' merged pull requests by the rules of section 4, from metadata and diffs. No project code runs. | metadata fetched with `gh`; the script on the 7-GPU machine's CPU | nothing | one row per merged pull request with a verdict and a reason, published | pull requests per project that pass; the share lost to each rule; follow-up pairs; pull requests marked as AI-written |
| P2 | Install the training controller: its own checkout, data volume and inventory name, no bench cases, memory collection off. | 7-GPU machine | the maintainer's word on disk, downloads, the route and the house rules | the controller answers a script call | the controller image's size; what had to be downloaded |
| P3 | The environment for one project: the recipe, one starting commit prepared, the project's own tests run there. One session per project, three in all. | 7-GPU machine, CPU | P2 | the recipe, and which of the project's tests pass at that commit | cold preparation time and disk per project; whether a preparation change was needed |
| P4 | The bundle maker (code): one screened pull request in, one bundle out, with the test names observed in a first run and the search for a partial fix. | code, checked on the 7-GPU machine | P1, one P3 | three bundles from three pull requests pass the source check | — |
| P5 | Make and gate the tasks of one project, for a fixed number of screened pull requests (est. 30). One session per project, three in all. | 7-GPU machine, CPU | that project's P3, P4 | a table of how many survive each check; the gated bundles | the share surviving each check; time and disk per task; how many needed two pull requests |
| P6 | The licence scan and the hold-out check on the gated tasks. | 7-GPU machine, CPU | P5 | scan tables; tasks touching a file without a passing verdict dropped | the share lost to licence and to the hold-out |
| P7 | The statements for the first 20 tasks, by the option chosen in section 5. | the writer's cards, or none | the maintainer's choice; P5 | 20 statements with their writer's id, each through the leak check | time per statement; the share the leak check rejects |
| P8 | The teacher's probe: DeepSeek on the first 20 tasks, one run, one attempt each. Launched by one session, recorded by another. | 7-GPU machine, the teacher's cards and the CPU | P6, P7, the teacher served | the run has ended and the kept sessions are counted | kept sessions per hour; the pass rate; tokens and calls per kept session |
| P9 | The publishability checks on the kept sessions and a sample export in the dataset layout. Nothing is published. | 7-GPU machine, CPU | P8 | a gate record and an export folder | the share of kept sessions excluded, and why |
| P10 | A read of a sample of kept sessions against the reference fixes. | a reader the maintainer approves | P8 | the share of wrong or partial fixes, with examples | how often a wrong fix passes the hidden tests |
| P11 | The pilot's record: the measures in one public table, and E68's result. | file edits | all of the above | the table is published | — |

The test-strength probe (E69) is one more session after P5, if the maintainer wants it in the pilot.

## 10. Decisions this design waits for

1. **The route:** the older bundle format with no change to the bench, or the current format with changes 1 to 3.
2. **The second controller** on the 7-GPU machine: the disk, the downloads, and the engine's containers under that
   machine's rules.
3. **The statement:** the writer, and whether a commit message or a title may be used.
4. **The harness texts:** whether the engine's fixed instructions and Pi's own prompt may stand in published
   sessions.
5. **Pull requests written with an AI tool:** whether their code may be a task's reference fix and part of the
   workspace. Their description is not used in any case.
6. **Combined tasks:** build them on mirror branches, or drop both pull requests.

## 11. What was not verified

- Nothing ran. Every statement about the engine comes from reading its source and documents at one commit.
- The older bundle format: no current case uses it, and whether it still passes end to end was not tried.
- Preparation time, and disk per task for many tasks of one project: no record exists.
- Whether the three projects build at old commits, which services they needed then, and whether they need a
  preparation change. Today `nerves_hub_web`'s CI starts Postgres 18 and ClickHouse and installs `xdelta3` and
  `mtools`, although the pool table lists Postgres only. `ex338`'s CI starts Postgres 14, and `radiator`'s a
  Postgres with no version pinned. `radiator` has no `.tool-versions` file at its root.
- The samples cover the latest 200 merged pull requests, not each repository's history. The file lists stop at 100
  files, and the AI mark is one footer text, so it counts Claude Code only.
- Whether a project's test alias runs a new migration before the tests, for the pull requests that add one.
- Whether Docker shares the Pi layer between images, and the unique disk per image. `docker images` shows neither.
- The share of pull requests for which a machine finds a partial fix, and the share with a follow-up fix.
- Who wrote the engine's fixed instruction sentences, and who wrote each of the 20 tickets.
- The licence readings in section 5 are a reading of the guide, not legal advice.

## Sources

In the bench's repository, <https://github.com/Cinderella-Man/elixir-swe-bench>, at commit `28c064ca`:
- `docs/pr-selection-guidelines.md`, `docs/curation-lessons.md`, `docs/case-admission.md`,
  `docs/case-curation-loop.md`, `docs/prepared-fork-sources.md`, `docs/benchmark-expansion-plan.md`,
  `docs/runbook.md`, `docs/evaluation.md`, `docs/adr/0001` to `0014`, `cases_rejected/README.md`, `AGENTS.md`,
  `CONTEXT.md`;
- `lib/eab/`: `candidates.ex`, `source.ex`, `provenance.ex`, `preparation.ex`, `fixtures.ex`, `baseline.ex`,
  `sandbox.ex`, `service_images.ex`, `task_contract.ex`, `test_adapter.ex`, `grader.ex`, `qualification.ex`,
  `inventory.ex`, `release.ex`, `agent.ex`, `agent_image.ex`, `pi.ex`, `pi_gateway.ex`, `runs.ex`, `runner.ex`,
  `checkpoints.ex`, `evidence.ex`, `retention.ex`, `readiness.ex`, `store.ex`;
- the 20 folders under `cases/`, read in full for `vutuv-pr-1759`, and `cases_rejected/plausible-pr-6441/case.json`;
- `results-page/results/`, `Dockerfile`, `compose.yaml`, `config/`.

In the sister repo, <https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs>: `bench/agentic_data/README.md`,
`gate.py`, `license_scan.py`, `tasks.py`, `export.py` and `sandbox/`.

In this repository: the [task collection guide](task_collection_guide.md), [the plan](../../plan.md), and the
[approved application-first batch](../../data/2026-11-09_elixir_project_pool/approved_app_first_batch.tsv).
