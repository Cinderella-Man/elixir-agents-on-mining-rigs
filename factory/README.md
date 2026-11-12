# The task factory

A copy of the [Elixir SWE Bench](https://github.com/Cinderella-Man/elixir-swe-bench)'s engine, to be cut down to one
job: turn merged pull requests of Elixir applications into checked training tasks, run the teacher model on them
under the bench's own harness, and keep the sessions that pass. It serves the pilot of registry row
[E68](../experiments.md). The design is in
[A task factory on the bench's engine](../docs/research/notes/task_factory_on_the_bench_engine.md), called "the design
note" below.

**State on 2026-11-12: job T0 built the tooling image, ran the copy's checks and added two tests; job T1 removed the
web page, the results page, the run series and the comparison, and with them Phoenix, LiveView and the web server;
job T5 put in the one task format and made-up tasks in place of the bench's cases (section 7). Sections 2 to 7
describe the factory after the trimming; jobs T2 to T4 and T6 to T10 have not started.** Section 7
lists the trimming jobs; each one that lands adds its line to the table there.

Words used here are the design note's: a *bundle* is the folder of files that defines one task, *hidden tests* are
the tests the model never sees, a *control* is a patch whose outcome is known in advance, and the *statement* is the
text the model is given as its task.

## 1. What this is and where it came from

- **Source:** <https://github.com/Cinderella-Man/elixir-swe-bench>, commit
  `28c064ca86108d550a6dcb693c751df21a18b736`.
- **Copied, unchanged:** 157 files, 1,084,685 bytes, written with `git archive` from that commit (this repository's
  commit `470301e`):

  | Path | Files | What it is |
  |---|---:|---|
  | `lib/` | 70 | the engine (`lib/eab/`, 61 files), its web page (`lib/eab_web/`, 8) and one Mix task |
  | `priv/` | 24 | Pi's pinned files, the test reporter and build helper, the Claude Code kit, the browser bundle, the page's assets |
  | `config/` | 3 | the inventory file and the application's settings |
  | `test/` | 52 | the engine's tests and their helpers |
  | `mix.exs`, `mix.lock` | 2 | the Elixir project and its locked dependencies |
  | `Dockerfile`, `compose.yaml` | 2 | the controller's image and service |
  | `.dockerignore`, `.formatter.exs`, `.gitattributes`, `.gitignore` | 4 | what the image build, the format check and Git need |

- **How to check the copy:** every copied file has the same Git blob id here as in the bench at that commit. Compare
  `git ls-tree -r 470301e:factory` in this repository with `git ls-tree -r 28c064ca` in the bench, for the paths
  above. The only difference is the two files named below.
- **Not copied:**
  - `cases/` and `cases_rejected/`: the bench's own tasks. They are held out from everything that shapes a model
    (this repository's [plan](../docs/plan.md), row E12), so they never enter this folder.
  - `docs/`, `results-page/`, `verification/`, `scripts/`, `licenses/`, `tools/`, `.github/`, and the root files
    `README.md`, `AGENTS.md`, `CONTEXT.md` and `NOTICE.md`. The bench's documents stay the reference for how the
    engine works: `docs/runbook.md`, `docs/case-admission.md` and `docs/adr/` at the commit above.
  - two test files, because this repository publishes no machine's names, addresses or paths:
    `test/eab/memory_collector_test.exs` holds a machine address, and `test/eab/model_identity_test.exs` holds a
    machine path. The first tests a part that is dropped (section 5). The second tests a file that stays, so that
    test is written again with made-up values (section 5.6).
- **What the same check matched and why it stayed.** Before each commit this repository's files are searched for
  home and service folders, VPN and host names, and network addresses. In the copy the search matches these, and
  none of them names a machine:
  - the home folder of the user `agent`, which the engine creates inside every workspace image
    (`lib/eab/fixtures.ex`, `test/eab/build_seed_docker_test.exs`);
  - a made-up home folder of a user called `user`, in `test/eab/claude_code_test.exs`;
  - the bench's default place for its memory collector on a model host, a service-folder path that is a setting's
    default and not any machine's path (`compose.yaml`, `config/runtime.exs`);
  - a made-up login with a private-range address and a made-up collector path, in
    `test/eab/memory_monitor_test.exs`;
  - a made-up model path built from the test's own id, in `test/eab/series_test.exs`;
  - the name of a VPN product, given as an example of an SSH service in two comments of
    `lib/eab/memory_monitor.ex`;
  - the address that means "all interfaces", in `lib/eab/memory_collector/sampler.ex`;
  - four version numbers with four parts, which only look like addresses: two ClickHouse image versions in
    `test/eab/baseline_docker_test.exs` and two Erlang versions in `test/eab/fixtures_test.exs`.
- **Licence:** the bench's repository states no licence of its own. It has no licence file at that commit, and its
  `README.md` names none. Both repositories have the same owner. Which licence covers this folder is the owner's
  decision and is not recorded yet.
- **Other people's code:** none is copied. Pi is installed from npm by the pinned files in `priv/pi/`; its licence
  is MIT. `mix.lock` and the two `package-lock.json` files name packages and do not contain them.

## 2. What must stay the same as the bench

The student is judged on the real bench. So a teacher's session made here must look to the model as a bench session
does, and a pass here must mean what a pass means there. These files carry that. "Same bytes" means the file keeps
the blob id it has in the copy. Where a file has to change for another reason, the row names the part that must not.

### 2.1 What the model sees

| What | File | What must stay |
|---|---|---|
| Pi's version | `priv/pi/package.json` | Same bytes (`4085058d`): `@earendil-works/pi-coding-agent` 1.2.0. |
| Pi's dependencies | `priv/pi/package-lock.json` | Same bytes (`1835860d`). The engine records this file's SHA-256 as part of Pi's identity. |
| The Node that runs Pi | `priv/pi/runtime.json` | Same bytes (`22cb0bcb`): one pinned Node image for glibc systems and one for musl. |
| How Pi is started, and its tools | `priv/pi/bridge.mjs` | Same bytes (`7c26c2f0`). It starts Pi with `--tools read,bash,edit,write`, with no extensions, MCP, skills or prompt templates, and offline. It writes the statement to `/tmp/eab-ticket.md` and passes the instructions as an addition to Pi's system prompt. The tool definitions themselves are Pi's own, so the version and the lock file fix them. |
| The shell behind Pi's `bash` tool | `priv/pi/bash-watchdog.mjs` | Same bytes (`a424def5`). It stops a command after the limit and prints `Command timed out after <n> seconds`. |
| Pi's settings | `lib/eab/pi.ex` | Same bytes (`c087a89c`). `config/4` switches compaction, retries and images off, sets project trust to "never", names the shell above, and passes the context and response sizes. The limit for one `bash` command is 1,200 seconds. |
| How Pi gets into the image | `lib/eab/agent_image.ex`, `recipe/2` | The recipe text. Only the image tag's prefix changes (section 6, change 6). |
| What is sent to the model server | `lib/eab/pi_gateway.ex`, the last clause of `exchange/2` | For a llama.cpp or Strata server: Pi's messages and tools are passed whole; `max_completion_tokens`, `temperature`, `top_p` and `top_k` are removed; `model`, `stream`, `max_tokens` and `seed` are set; for Strata `tool_choice` is removed, and for llama.cpp the usage report is asked for. The two stops, `token_budget` and `context_budget`, stay. Only the clauses for the two cloud providers are cut. |
| Thinking controls | `lib/eab/thinking.ex` | Same bytes (`db329d80`). The server's own thinking preset is used and Pi's request controls are removed. |
| The fixed instruction sentences | `lib/eab/task_contract.ex`, `instructions/1`; `lib/eab/agent.ex`, `instructions/2` and `budget_instructions/1` | The text below, byte for byte. |
| The budgets | `config/benchmark.json`, the `defaults` block; `lib/eab/model.ex`, `settings/2` | Context cap 262,144 tokens, 8,192 per response, 8 held back, 65,536 generated in all, seed 101, no compaction. |
| The workspace image | `lib/eab/fixtures.ex`, `dockerfile/4`; `priv/fixtures/build_seed.exs` (same bytes, `caafd335`) | The recipe text for a task that asks for no extra packages: the same system packages, the user `agent` with id 1000, the folder `/workspace`, the environment variables, Hex 2.5.3, and one Git commit by `Benchmark <benchmark@localhost>` with the message `Initial task workspace`. |
| The limits the model works under | `lib/eab/sandbox.ex`, `start/2` | Workspace container: no network (or only the database's own), all capabilities dropped, no new privileges, 4 GB of memory, 2 CPUs, 512 processes, a 512 MB `/tmp`. Postgres beside it: 1 GB and 1 CPU. ClickHouse: 3 GB and 2 CPUs. Labels and a CPU share are added (section 6, change 1); these flags are not touched. |

**The instruction text.** For a bug-fix task with the budgets above and `lib/` and `test/` as its allowed folders, the
model gets this after Pi's own system prompt:

```text
Complete the bug_fix task in /workspace. Investigate the source and run the relevant tests.
Test command: <the task's command for the existing tests>.
Add or change a test that fails in its test body on the starting source and passes after your change. Compilation/setup failures do not count.

Dependencies are prepared. The workspace is offline. Preserve existing behavior and do not weaken tests.

Allowed edit prefixes: lib/, test/.
When finished, give a short summary. Your current patch is then checked in a fresh workspace.
Model and tool calls are unlimited. Limits: 65536 generated tokens total, 262144 context tokens including up to 8192 response tokens.
History is never compacted. If a budget is exhausted, the current patch is graded.
Task details: {}
```

Two places differ from a bench session, and both follow from the task format, not from the engine:
- the first empty line is where a bench case has its `Required outcome (<id>): <sentence>` lines, 2 to 6 of them.
  A training task has no requirement sentences by default (section 3);
- `Task details:` is `{}`. Each of the 20 bench cases puts a note about its environment there.

Both come from two optional fields of the one format, `grading.requirements` and `clarifications` (section 3.2).
They are empty by default, and only a writer the owner approves may fill them. When they are filled, the engine
writes them by the bench's own code path, so the text is the bench's: the parity test pins a task with two
requirement sentences and a clarification (2.3).

The second empty line is where the one bench case with a browser has a sentence about Chromium. It is empty in the
other 19 cases and stays an empty line here when the browser support is cut.

**Names that must not be renamed.** The factory gets a name of its own (section 6, change 6), but only outside the
container. Inside it the model can meet these, and they stay: `/workspace`, `/opt/pi`, `/opt/eab-seed`,
`/tmp/eab-ticket.md`, the variable `EAB_BASH_TIMEOUT_SECONDS`, the Git author `Benchmark`, the commit message
`Initial task workspace`, Pi's provider name `benchmark`, and the gateway's stop message `Benchmark <reason> reached`.

### 2.2 What a pass means

| What | File | What must stay |
|---|---|---|
| Grading one patch | `lib/eab/grader.ex`: `grade/4`, `do_grade/5`, `coverage/4`, `validate_patch/2`, `parse/2`, `test_command/2`, `run_tests/3`, `restore_tests/1` | All of it. The controls change (section 6, change 7); these functions do not. |
| The test reporter | `priv/fixtures/grade_formatter.exs` | Same bytes (`ea8dec71`). It reports every test as passed, failed, skipped or excluded, and says whether a failure was in the test's body or in its set-up. |
| How a test command is run | `lib/eab/test_adapter.ex`, `priv/fixtures/node_runner.mjs` | Kept as they are. |
| The time limit of one test command | `lib/eab/grader.ex`, `run_tests/3` | 240 seconds unless the task sets `test_timeout`. |

A patch passes when all of this holds, each step in a fresh container:
1. it changes only files under the task's allowed folders, it is at most 1 MiB, and it adds no symbolic link or
   submodule;
2. with the patch applied, the existing tests and the test files the model added or changed pass;
3. the test folders are put back, the hidden tests are applied, their run passes, and every required test is among
   the passed ones;
4. the test folders are put back again, and the existing tests pass;
5. the model's own test files, applied alone to the unchanged project, give at least one test that fails in its body
   and that passed in step 2.

A session is kept when its attempt ended as `completed` and its patch passed. That is the bench's rule, unchanged.

### 2.3 How it is held

- The first trimming job writes `test/eab/bench_parity_test.exs` from the unchanged copy. It pins the blob ids above
  and the exact output of `Eab.Agent.instructions/2`, `Eab.Pi.config/4`, `Eab.Fixtures.dockerfile/4` and the
  `docker run` arguments of `Eab.Sandbox`. Every later job must leave it passing.
- Job T5 rewrote the test's task inputs in the one format, and the texts it expects stayed byte for byte: a bug fix
  with no requirement sentences (the text above), and a bug fix with two requirement sentences and a clarification.
  It removed two expected texts, the bench's text for a task whose added tests are optional and its text for a
  refactor: the one format cannot express those inputs, so no model can ever be shown those texts. It added the
  bench's text for a `feature`, captured from the unchanged copy (commit `470301e`). That text has requirement
  sentences, because the bench's format needs at least one for a feature, so a feature text without them cannot
  come from the unchanged copy
  ([data](../docs/data/2026-11-12_factory_t5/README.md)).
- When the bench changes any of these (a new Pi version, a new instruction sentence), the factory takes the change:
  the files are copied again from the bench's new commit, and that commit is recorded in section 7.

## 3. The one task format

One format, `schema_version: 3`. The bench reads only its own two formats and refuses a 3, and the factory refuses
everything else, so a bench case cannot be loaded here and a training task cannot be loaded there.

It is the bench's current format with these parts removed: the mapping of requirement sentences to tests (the
sentences stay as an optional field), the review record, the admission file, the separate copy of the upstream
tests (`upstream-tests.patch`) and of the hidden tests (`acceptance.patch`), the browser switch, the kind
`refactor`, the test policies other than `behavioral`, and the descriptive fields (`title`, `family`, `domains`,
`source_inspiration`). `clarifications` stays as an optional field. The partial fix is optional.

`Eab.TaskContract.read/1` refuses every other `schema_version`, and a manifest that still has one of the removed
fields (`title`, `family`, `domains`, `suite`, `source_inspiration`, the older format's `regression_command`,
`acceptance_command`, `required_acceptance_tests`, `require_regression_test`, `partial_repair_probe`, or
`runtime.browser`), so a bench case with its version number changed does not load either (job T5).

### 3.1 The files of a task

| File | What it holds | Where it comes from |
|---|---|---|
| `case.json` | the manifest (3.2) | the bundle maker |
| `provenance.json` | the two commits and the marks (3.3) | Git and the screening row |
| `reference.patch` | the pull request's change to the code | the pull request's diff, the part outside the test folders |
| `reference-tests.patch` | the pull request's tests. They are also the hidden tests. | the pull request's diff, the part inside the test folders |
| `upstream-docs.patch` | optional: the pull request's changes to `.md` and `.txt` files outside the allowed folders | the pull request's diff |
| `integrity.patch` | the early-exit control: one new file that calls `System.halt(0)` | a fixed text |
| `incomplete.patch` | optional: a partial fix | the bundle maker's search: the reference with one file or one hunk left out |
| `ticket.md` | the statement | the statement's writer; added after the task passed the gate |
| `statement.json` | the writer's id and the SHA-256 of `ticket.md` | written with the statement |

The engine keeps its file names, so that the code that reads them is not edited. A task can pass the gate before it
has a statement. A teacher run takes only tasks that have one.

The import check (`Eab.Candidates.validate!/1`, job T5) takes no other file: the first five are required,
`incomplete.patch` must exist exactly when `partial_control.present` is true, `ticket.md` and `statement.json` come
together, and `integrity.patch` must add one new file and contain the line `System.halt(0)`. The partial fix and the
early exit must stay in the allowed folders, and the hidden tests in the test folders.

### 3.2 `case.json`

| Field | Value | Where it comes from |
|---|---|---|
| `id` | `<project>-pr-<number>`: lower-case letters, digits and hyphens | the screening row |
| `schema_version` | `3` | fixed |
| `task_kind` | `bug_fix` or `feature`. The instruction text names it. `refactor` is not used: it needs a hand-written structural check. | the bundle maker, by a rule that is not written yet (section 8) |
| `project` | the repository's name | the screening row |
| `repository.url`, `repository.revision` | the upstream repository, and the starting commit: the first parent of the merge commit | Git |
| `runtime.profile` | `mix` | fixed |
| `runtime.image` | a `hexpm/elixir` image, pinned by digest | the project's recipe |
| `runtime.node_image` | optional: a Node image, for a project whose tests need Node | the project's recipe |
| `runtime.environment` | environment variables | the project's recipe |
| `runtime.setup_commands`, `runtime.before_test_commands` | commands run at build time and before each test run | the project's recipe |
| `runtime.packages` | new: extra system packages for the image (section 6, change 3) | the project's recipe |
| `services` | `postgres` and `clickhouse` images, pinned by digest; absent when the project needs none | the project's recipe |
| `baseline` | the commands that build the database once, as the engine's policy object: `{"mode": "prepared", "commands": ["mix ecto.create --quiet", "mix ecto.migrate --quiet"]}` | the project's recipe |
| `test_timeout` | seconds for one test command; 240 when absent | the project's recipe |
| `permitted_exclusion_tags` | optional: tags of tests the project itself excludes | the project's recipe |
| `allowed_edit_prefixes` | the top-level folders the pull request changes | the pull request's diff |
| `acceptance_patch` | `reference-tests.patch`. The field stays because the grading code reads it. | fixed |
| `grading.adapter` | `exunit` | fixed |
| `grading.acceptance` | `mix test` with the test files the pull request adds or changes | the pull request's diff |
| `grading.preservation` | `mix test` with existing test files. It is the "Test command" the model is told. | the bundle maker: files that pass on the unchanged project in the first run |
| `grading.protected_paths` | the test folders, `["test/"]` for a plain project | the project's recipe |
| `grading.test_suffixes` | `["_test.exs"]` | fixed |
| `grading.required` | the names of the hidden tests that pass on the reference | observed in the first run, then fixed |
| `grading.starting_failures` | the names of those that fail in their body on the unchanged project | observed in the first run, then fixed |
| `grading.model_tests` | `behavioral`: the model must add a test that fails first | fixed |
| `grading.requirements` | optional: a list of `{"id": ..., "text": ...}`, written into the instruction text as `Required outcome (<id>): <text>`. No `kind`, no `checks`, no mapping to tests. Empty by default. | only a writer the owner approves |
| `clarifications` | optional: an object, written into the instruction text as `Task details: <JSON>`. Empty by default. | only a writer the owner approves |
| `partial_control` | `{"present": true}`, or `{"present": false, "reason": "..."}` | the bundle maker's search |

A project's recipe is one file per project and period of its history: the Elixir image, the services, the
environment and the commands. It is written once per project (job P3 of the design note) and is not part of a task.

The reasons a task has no partial fix, each counted apart: `single_hunk` (the fix is one hunk in one file, so there
is nothing to leave out), `no_variant_compiles`, `no_variant_fails` (every variant that compiles passes the hidden
tests, which says the tests do not cover the part left out).

### 3.3 `provenance.json`

| Field | Value | Where it comes from |
|---|---|---|
| `repository` | the upstream repository's address | the screening row |
| `pull_request` | the pull request's address in that repository | the screening row |
| `broken_revision`, `broken_tree` | the starting commit and its tree hash | Git |
| `fixed_revision`, `fixed_tree` | the merge commit and its tree hash | Git |
| `pair_selection` | `first parent of the merge commit, and the merge commit` | fixed |
| `licence` | the SPDX id of the repository's licence at the starting commit (E51) | the licence scan |
| `merged_at` | the merge date | the screening row |
| `marks` | `ai_written` with the tool's name (E70), `adds_migration`, `touches_assets`, `after_cutoff` (E53) | the screening row |

A task has one pull request. A fix spread over two is not combined in the pilot: the first is dropped, the follow-up
is a task of its own, and the pairs are counted.

### 3.4 The statement

`ticket.md` is a text, and `statement.json` says who wrote it:

| Field | Value |
|---|---|
| `writer` | the id of the model that wrote it: its name, its file and its settings |
| `ticket_sha256` | the SHA-256 of `ticket.md` |
| `written` | the date |

The teacher model writes the statements (decided 2026-11-12); a statement by any other writer is not used. The check
that a statement does not give the fix away runs outside the engine. The engine checks only that the record exists
and that the hash matches. Since job T5 the import check does this: `writer` is a non-empty text or object, `written`
is a text, and `ticket_sha256` is the SHA-256 of `ticket.md`. A change to either file leaves the controls' receipt
valid (`Eab.Inventory.qualification_inputs/1`).

### 3.5 The bundle maker

`Eab.BundleMaker` (`lib/eab/bundle_maker.ex`, job P4) turns one screened pull request into one task folder, or
refuses it with a reason. `Eab.BundleProbe` (`lib/eab/bundle_probe.ex`) holds its two steps that need a prepared
project. Neither writes a statement.

**Input:** the upstream repository's address, the pull request's number and merge commit (the census), its changed
paths (the census), its verdict and marks (the screen), and the project's recipe,
`recipes/<owner>__<repo>.json`. A recipe holds exactly the per-project fields of `case.json`: `runtime`,
`services`, `baseline`, `test_timeout`, `permitted_exclusion_tags`, and `grading.protected_paths` and
`grading.preservation` (the command for the existing tests). A recipe that is not final carries one more field,
`provisional`, a note the maker never copies; the result line says `provisional`. `recipes/axelclark__ex338.json` is
provisional: job P4 wrote it from the project's files for its proofs, and job P3 replaces it.

**What it does,** in order:
1. **The source pair.** The merge commit and its first parents are fetched by id into a local cache. The starting
   commit is the first parent when the difference to the merge commit changes exactly the census's paths. When it
   does not (a rebase merge leaves several commits), the maker walks back along first parents, up to 30, until the
   paths match; `pair_selection` then names the commit it took.
2. **The split,** by path, of the difference without rename detection: paths under the recipe's test folders are
   `reference-tests.patch`; `.md` and `.txt` files whose top folder the code part does not touch are
   `upstream-docs.patch`; everything else is `reference.patch`, CI files, assets, lock files and migrations
   included, because the source check needs every changed path in one of the three. The three patches applied to
   the starting tree must give the merged tree; the maker checks this on its local copy before it writes anything.
3. **The manifest and the provenance record** (3.2, 3.3). `allowed_edit_prefixes` are the top folders (or root
   files) the code part touches, and the test folders. `grading.acceptance` is `mix test` with the test files the
   pull request adds or changes; `grading.preservation` is the recipe's command. `task_kind` follows a provisional
   rule (section 8): `feature` when the reference adds a file or a public function it does not also remove, else
   `bug_fix`. `licence` is a first reading of the licence file at the starting commit; the licence scan (E51) has
   the last word. `marks` are the screen's `adds_migration`, `touches_assets` and `ai_written` (the screen does not
   record the tool's name). `integrity.patch` adds `lib/eab_halt.ex`, or the same file in the first folder the task
   may edit when `lib/` is not one.
4. **A first reading of the test names and the partial fix.** The format needs both before any run. `required` and
   `starting_failures` are the tests (`Elixir.<Module>::test <describe> <name>`, the reporter's form) whose body
   holds a line the pull request adds or changes, read from the merged test files. `incomplete.patch` is the first
   variant of the search below, or `partial_control` is `single_hunk` when there is none.
5. **The import check** (`Eab.Candidates.validate!/1`) on the written folder; a folder that fails it is not kept.

**The two steps that need a prepared project,** `Eab.BundleProbe.finish/4`, for a task whose runtime the gate has
prepared:
- **Observing the test names:** only the hidden tests run, on the unchanged project and on the reference.
  `required` becomes the hidden tests that pass on the reference, and `starting_failures` those that fail in their
  body on the unchanged project. It refuses, and leaves the folder as it was, when a run does not finish, a hidden
  test fails on the reference, or nothing fails in its body on the unchanged project.
- **The search for a partial fix:** the reference with one file left out, each in turn when there are two or more,
  then with one hunk left out of each file that has two or more. The first variant whose hidden run finishes and
  fails a starting failure in its body becomes `incomplete.patch`. Otherwise `partial_control` records
  `single_hunk`, `no_variant_compiles` or `no_variant_fails`.

**What it refuses** (the result line's `reason`): `holdout` (the owner or repository is on
[`config/holdout.json`](config/holdout.json): the bench's 12 projects of [the plan](../docs/plan.md), their GitHub
organisations, the bench's copies of them, and any repository with one of their names), `screen_rejected`,
`not_in_census`, `paths_never_match`, `fetch_failed`, `submodule` (in the pull request or anywhere in either
tree), `symbolic_link`, `binary_file`, `unsupported_path` (a path with a space, a quote or another character the
engine's patch check cannot read), `patch_over_1_mib`, `no_code_part`, `no_test_part` (no added or changed
`_test.exs` file), `no_test_names` (no test with a literal name and a changed body), `does_not_apply`,
`does_not_rebuild`, `import_check`, `no_folder_for_early_exit`, `exists` (the task folder is already there), and
`error` with the message for anything else. One refusal never stops a list.

**How it is called,** on the build machine, in the tooling image, with the network (it fetches from GitHub). The
scripts are in [`docs/data/2026-11-12_pilot_bundle_maker/run/`](../docs/data/2026-11-12_pilot_bundle_maker/README.md):

```sh
WORK=<work folder> LABEL=<key=value> CENSUS=prs_axelclark__ex338.tsv SCREEN=screen_axelclark__ex338.tsv \
  run/make.sh make --repository https://github.com/axelclark/ex338 --numbers 1460,1463,1394
WORK=<work folder> LABEL=<key=value> run/make.sh verify
```

`make` writes the folders to `WORK/tasks/` and one line per pull request to `WORK/out/results.tsv` (made, or
refused with the reason). `verify` runs the source check (`Eab.Provenance.verify/3`) and the import check
(`Eab.Candidates.import/1`) on every folder there. In Elixir: `Eab.BundleMaker.make/2`, `make_list/2`,
`requests/3` and `verify/2`; `Eab.BundleProbe.finish/4`.

## 4. The gate

The checks a task must pass before the teacher sees it, in the order the engine runs them. They are the "keep" rows
of the design note's section 3. Every result is recorded per task with its reason, so that the pilot can count the
share lost at each step.

| # | Check | The engine's part | What a failure means |
|---|---|---|---|
| 1 | **The bundle loads.** Its fields are valid, its patches touch only the folders they may, both test commands are explicit `mix test` commands, it has at most 64 flat files of at most 4 MiB, and its repository is not one of the bench's projects. | `Eab.Candidates.import/1` and `validate!/1`, `Eab.TaskContract` | The bundle maker has a fault, or the pull request is of a kind the engine refuses (a binary file, a symbolic link, a patch over 1 MiB). The task is dropped. |
| 2 | **The source pair rebuilds exactly.** The starting commit and the merge commit are fetched by id and their tree hashes checked. The three patches applied to the first must give exactly the second's tree. | `Eab.Provenance.verify/3`, `Eab.Source.snapshot/4` | The split of the diff lost a change: a file outside the three patches, a binary file, a submodule. The task is dropped. Many such failures in one project point at the bundle maker. |
| 3 | **The environment builds.** The image, the dependencies, the compile and the database. | `Eab.Fixtures.ensure/3`, `Eab.Baseline` | The project's recipe does not fit this commit: another Elixir version, a package that can no longer be downloaded, a missing system package or service. This is not a verdict on the task. It is counted apart, and the recipe gets a second period or the commit range is left out. |
| 4 | **The unchanged project fails a hidden test in the test's body.** The hidden run must finish, and at least one test must fail inside its own body. | the empty-patch control in `Eab.Grader.qualify/3` | The run did not finish: the tests need a module, function or struct that does not exist yet, so nothing can fail "in a body". This is common for feature pull requests. Or nothing failed: the tests pass without the fix and do not test it. Dropped in both cases. |
| 5 | **The failing tests are the declared ones.** The first run writes the names down; from then on the observed set must equal the written one. | `Eab.Grader.valid_controls?/5` | The task's failures change from run to run. Dropped, and counted as unstable. |
| 6 | **The reference passes:** the hidden tests, the existing tests, and the rule about a test that fails first. | the reference control | The pull request's own tests do not pass on the merged tree in this environment: they need the network, the clock or a service, or they are unstable. Dropped. Many in one project point at the recipe. |
| 7 | **An early exit is rejected:** the reference plus a file that stops the VM with exit code 0. | the early-exit control | The project's test command can report success without the engine's reporter seeing the tests. No grade of this project can be trusted. Dropped, and the project's recipe is looked at. |
| 8 | **The partial fix is rejected,** for a task that has one: its hidden run finishes and fails at least one declared starting failure in its body. | the partial control | The variant passes the hidden tests. The bundle maker tries the next one. When none is left, the task stays, with `partial_control.present` false and its reason. |
| 9 | **A second round agrees.** The unchanged project and the reference are graded again in fresh containers, and every named test must end as in the first round. | new, in the check's entry point (section 6, change 8) | An unstable test would keep a wrong session or throw away a right one. Dropped. How many tasks change between rounds is one of the pilot's measures. |
| 10 | **The receipt.** It is tied to the image, the database, the task's files and the grading code. | `Eab.Grader.qualification_identity/2` | It cannot fail. When the grading code, the image or the task changes later, the receipt no longer matches and the engine runs the controls again before the next attempt. |

Then, for each of the teacher's attempts, the five steps of section 2.2 decide whether the session is kept.

**What the gate does not have,** against the bench's: a person who reads the requirements before the tests, the
mapping of every hidden test to a requirement, two blind passes by a strong model, a person who reads every passing
patch, and a third round of controls. So some kept sessions will hold a fix that is wrong and still passes. Three
things outside the gate limit that: the partial-fix control, the test-strength probe (E69), and a read of a sample of
kept sessions against the reference fixes.

## 5. The cut list

Every file of the copy as keep, change or drop. Keep means no edit is planned. The changes are described in
section 6. The reading rule for a drop: a file goes only when nothing that stays calls it.

| | Keep | Change | Drop |
|---|---:|---:|---:|
| `lib/` (70) | 17 | 24 | 29 |
| `priv/` (24) | 8 | 0 | 16 |
| `config/` (3) | 0 | 3 | 0 |
| root files (8) | 0 | 8 | 0 |
| `test/` (52) | 18 | 17 | 17 |
| **All (157)** | **43** | **52** | **62** |

### 5.1 The parts that go, and why

| Part | Verdict | Why |
|---|---|---|
| The results page and its publication tooling | drop | It exports and publishes bench results. The factory must not be able to write a bench result. |
| Run series and run comparison | drop | Three-run series and side-by-side tables belong to published bench scores. |
| The other harness (Claude Code) and the two cloud back ends (Claude API, ChatGPT subscription) | drop | The teacher is a local model under Pi. With these gone the factory cannot produce a session by a cloud model at all, which fits this repository's rule that every text in the training data has an approved writer. The llama.cpp and Strata back ends stay. |
| The memory collector and its monitor | drop | They sample the model host's memory over SSH for the results page. No training measure needs them. |
| The browser support | drop | It serves one bench case. The pilot's tasks are graded by ExUnit only. |
| The second (older) task format | drop | One format (section 3). The older one has no task kind, and no current case uses it. |
| The web page | drop | See below. |
| Release freezing | **change, not drop** | The sealed receipts of every attempt rest on it: a run names a release, and resume checks it. What goes is the copy of the whole inventory per run and the admission check; a run freezes only the tasks it was given. |
| The Node test adapter | **keep** | It is not needed: the format allows only `exunit`. Cutting it means edits in three files of the grading identity for 3 KB of code, so it stays until someone wants that edit. |
| Elapsed-time and speed recording | **keep, switched off** | `lib/eab/pi.ex` must keep its bytes and calls both modules. The factory records no speed: the attempt is started with `measure: false`. |

**The web page, on its merits.** For keeping it: a person can watch a run and open an attempt's log in a browser
without a script. Against it:
- it is the one file that calls every part dropped above (`lib/eab_web/dashboard_live.ex`, 93,981 bytes), so keeping
  it means rewriting most of it by hand before anything else can be cut;
- it is built around one benchmark run of 20 cases, with a Run button, a series and a publish step. A factory has
  hundreds of tasks and is driven by scripts;
- everything it shows is already in files and in one call: `runs/<run>/events.jsonl`, each attempt's `activity.log`,
  and `Eab.Runs.snapshot/0`;
- without it the controller listens on no port, and Phoenix, LiveView and the web server leave the dependencies.

So it is dropped. What is lost is the live view. A `status` entry point takes its place (section 6, change 5).

### 5.2 `lib/eab/`

| File | Verdict | Reason |
|---|---|---|
| `activity.ex` | keep | Writes each task's `activity.log`: commands, model output and Pi's tool calls. |
| `agent.ex` | change | The Claude Code branch and the browser sentence go; attempts start with `measure: false`. `instructions/2` must give the same text (section 2). |
| `agent_image.ex` | change | The image tag's prefix. The recipe stays. |
| `anthropic.ex` | drop | The Claude API back end. |
| `application.ex` | change | The children for the web page, ChatGPT, the Claude Code broker and the memory monitors go. Phoenix's PubSub becomes an Elixir `Registry` under the same name, `Eab.PubSub` (T1). |
| `baseline.ex` | change | The default for one bench project's profile (`plausible_ce`) goes. The rest stays. |
| `browser.ex` | drop | Browser support. |
| `build_cache.ex` | change | The image tag's prefix. |
| `cache.ex` | keep | The store of prepared parts, keyed by their inputs. |
| `candidates.ex` | change | Becomes the import check: `import/1`'s limits and `validate!/1` stay, without the partial fix as a must. The draft store, `review/2`, `export/2`'s review and admission, `verify_admission!/1` and `qualify/3` go: checks run through `Eab.Qualification`, so that many tasks share the preparation scheduler. T5 removed `review/2`, `export/2` and `verify_admission!/1` and wrote `validate!/1` for the one format (public now, for the entry points); the draft store (`import/1`, `read!/1`) and `qualify/3` stay until T6 and T9 give the check its place. |
| `chatgpt_auth.ex` | drop | The ChatGPT subscription's sign-in. |
| `checkpoints.ex` | change | `validate_cases!/2`: a run's tasks are a chosen list; the two harness-check kinds go. The sealed receipts stay. |
| `claude_code.ex`, `claude_code/attempt.ex`, `claude_code/broker.ex`, `claude_code/mcp.ex`, `claude_code/transcript.ex` | drop | The Claude Code harness. |
| `command.ex` | keep | Runs subprocesses with output limits and watchdogs. |
| `comparison.ex` | drop | Run comparison; only the web page calls it. |
| `database_seed.ex` | keep | Decides when a saved database can be reused for a later commit. |
| `evidence.ex` | keep | Saves `grade.json` and the short verdict. |
| `fixtures.ex` | change | Extra system packages; the image tag's prefix; the browser calls and the `plausible_ce` line go. The recipe for a task without packages must not change (section 2). |
| `grader.ex` | change | The partial control becomes optional per task; the older format's built-in controls go. Grading itself is not touched (section 2.2). Done in T5: only `qualify/5`, `partial_patch/1` and `valid_controls?/5` changed; the early exit is read from the task's `integrity.patch`; the saved controls record `partial_control`, and `partial_repair` is null without a partial fix. |
| `harness.ex` | change | Pi only. |
| `image_presence.ex` | keep | Asks Docker which images exist, in batches. |
| `inventory.ex` | change | Tasks come from a mounted folder; no case list in the configuration; `statement.json` joins the files that do not void a receipt. T5 did the last part, and `admission.json` and `upstream-tests.patch` left that list: they are not files of the format, so a task that has one is refused at import. |
| `log_sections.ex` | drop | Splits a log into stages for the web page; nothing else calls it. |
| `measurement.ex` | change | One sentence: the reason given when nothing is measured. |
| `memory_collector/cli.ex`, `memory_collector/sampler.ex`, `memory_collector/weights.ex`, `memory_monitor.ex` | drop | The memory collector. |
| `model.ex` | change | The three branches for the cloud back ends and Claude Code go from `settings/2` and `unchanged!/2`. Discovery of llama.cpp and Strata servers stays. |
| `model_identity.ex` | keep | Names the served model file in a run's record. |
| `model_speed.ex` | keep | Called by `pi.ex`; it records nothing when measuring is off. |
| `openai.ex` | drop | The ChatGPT subscription back end. |
| `pi.ex` | keep | Same bytes (section 2). |
| `pi_gateway.ex` | change | The two cloud clauses of `exchange/2` and their routes go. The local clause stays as it is (section 2). |
| `pipeline.ex` | keep | The scheduler: preparation ahead, attempts in order, grading apart. |
| `preparation.ex` | keep | Orders a project's commits so that a later one builds from an earlier one. |
| `provenance.ex` | keep | The source check. It already takes the pull request's own tests when no separate upstream copy exists. |
| `qualification.ex` | change | Prepares and checks a given list of tasks, not the whole inventory; the second round. |
| `readiness.ex` | keep | Says which tasks can run with no internet. |
| `release.ex` | change | Freezes the tasks of one run; the admission check goes (5.1). T5 removed the admission check; every task's contract is read when a release is frozen. |
| `report.ex` | change | The report's title and its lines about memory, speed and score. |
| `results.ex`, `results/preview.ex`, `results/resources.ex`, `results/schema.ex` | drop | The results page. |
| `retention.ex` | change | The image tag's prefix in the removal guard. |
| `runner.ex` | keep | Runs one run through the scheduler. |
| `runs.ex` | change | `start/4` takes the list of tasks; preparation takes a list; the series, the memory monitor, the Claude Code version and the harness checks go. The change notifications stay: `runs_test` waits on them, and so can the `status` entry point. Since T1 `subscribe/0` and the broadcast use the `Registry` `Eab.PubSub` in place of Phoenix's PubSub, with the same `:runs_changed` message. |
| `sandbox.ex` | change | Labels and a CPU share from the environment; the container name's prefix and the label keys. The limits stay (section 2). |
| `series.ex` | drop | Run series. |
| `service_images.ex` | change | The image tag's prefix, in two places. |
| `source.ex` | change | The mirror as a second place to fetch from (section 6, change 4). |
| `storage.ex` | change | The image tag's prefix. Its report of shared and unique image sizes is what the pilot needs for "disk per task". |
| `store.ex` | keep | Reads and writes the data folder. |
| `task_contract.ex` | change | One format (section 3). The instruction text stays (section 2). Done in T5. |
| `test_adapter.ex` | keep | See 5.1. |
| `thinking.ex` | keep | Same bytes (section 2). |
| `factory.ex` | **new** | The entry points (section 6, change 5). |

### 5.3 `lib/eab_web/` and `lib/mix/`

| File | Verdict | Reason |
|---|---|---|
| `eab_web/dashboard_live.ex`, `eab_web/router.ex`, `eab_web/endpoint.ex`, `eab_web/layouts.ex`, `eab_web/artifact_controller.ex` | drop | The web page (5.1). |
| `eab_web/chatgpt_controller.ex` | drop | The ChatGPT sign-in's pages. |
| `eab_web/claude_code_controller.ex` | drop | The Claude Code harness's endpoints. |
| `eab_web/results_controller.ex` | drop | The results page's preview. |
| `mix/tasks/eab.results.ex` | drop | The results page's command. |

### 5.4 `priv/`

| File | Verdict | Reason |
|---|---|---|
| `pi/package.json`, `pi/package-lock.json`, `pi/runtime.json`, `pi/bridge.mjs`, `pi/bash-watchdog.mjs` | keep | Same bytes (section 2). |
| `fixtures/grade_formatter.exs`, `fixtures/build_seed.exs` | keep | Same bytes (section 2). |
| `fixtures/node_runner.mjs` | keep | With the Node test adapter (5.1). |
| `fixtures/browser/package.json`, `fixtures/browser/package-lock.json` | drop | Browser support. |
| `claude_code/` (11 files) | drop | The Claude Code harness's kit, prompts and tools. |
| `static/assets/app.css`, `static/assets/app.js` | drop | The web page. |
| `admitted_validation_runs.json` | drop | A list of bench runs for the run series. |

### 5.5 `config/` and the root files

| File | Verdict | Reason |
|---|---|---|
| `config/benchmark.json` | change | Renamed `config/factory.json`: an id of its own, no case list, no scoring text. The `defaults` block stays (section 2). |
| `config/config.exs` | change | The web endpoint's settings go (done in T1, with Phoenix's own settings). |
| `config/runtime.exs` | change | The session secret, the memory collection and the endpoint go; the task folder, the labels, the CPU share and the mirror list come from the environment. The secret and the endpoint went in T1. `lib/eab/claude_code.ex` still reads the endpoint's port from the removed setting and falls back to 4000, until it goes in T2. |
| `mix.exs` | change | `phoenix`, `phoenix_live_view`, `phoenix_html`, `bandit`, `jose` and `lazy_html` leave the dependencies; `jason` and `req` stay; the release gets its own name; the `assets` alias goes. T1 removed all of them but `jose`, and named `plug_crypto` (2.2.0, already in `mix.lock` through Plug) as a direct dependency, because `chatgpt_auth.ex` calls `Plug.Crypto.secure_compare/2`; both leave with that file in T2. |
| `mix.lock` | change | Written again by Mix after the dependencies change, never by hand. |
| `Dockerfile` | change | No `COPY cases`, no Claude Code kit, no SSH client; the release's name. The stage that installs Pi stays. T1 removed `mix assets` and the copy of `priv/admitted_validation_runs.json`. |
| `compose.yaml` | change | Names of its own; the task folder mounted; the memory settings and the results-page mount go; the label and CPU share on the controller itself; Erlang's distribution bound to the loopback. T1 removed the results-page mount and the web port (`PORT`). |
| `.dockerignore`, `.gitignore`, `.gitattributes` | change | The lines for dropped files go. T1 removed the two lines for the page's copied script files. |
| `.formatter.exs` | change | The LiveView plug-in and the path of the uncopied memory-collector project go. The plug-in went in T1. |

### 5.6 `test/`

Ten test files of the copy have tests that need the bench's own cases, which are not here, so those tests cannot pass
on the unchanged copy (48 tests when job T0 ran them):
- five read a case by its name (`plausible-pr-5939`, `livebook-pr-2219` or `livebook-pr-2800`): `eab/candidates_test`,
  `eab/fixtures_test`, `eab/readiness_test`, `eab/runner_test` and `eab_web/dashboard_test`;
- two build their runs from the whole inventory and need at least four cases in it: `eab/runs_test` and
  `eab/checkpoints_test`;
- three have one or two such tests each and were found by job T0: `eab/grader_test` (one test needs a non-empty case
  inventory), and the dropped `eab/claude_code_test` and `eab/results_test`.

17 more tests fail on the unchanged copy because they read a file of the bench that was not copied
(`results-page/index.html` or `scripts/install-claude-code-kit.sh`); all of them are in dropped files. Job T0's tables
list every test with its state and cause ([`docs/data/2026-11-12_factory_t0/`](../docs/data/2026-11-12_factory_t0/README.md)).

Each of them that stays is changed to use made-up tasks under `test/support/`, never a bench case and never a real
project. Job T5 wrote them: `test/support/made_up_tasks.exs` and the bundles in `test/support/tasks/`. Two tasks of
an invented ledger with no dependencies apply to its source and are graded in the Docker test, one with a partial
fix and one without; a third, of an invented application with Postgres and a Node step, serves the tests that
prepare nothing for real. T5 moved `candidates_test`, `fixtures_test`, `grader_test`, `readiness_test`,
`runner_test`, `task_contract_test` and `task_grading_docker_test` to them. The tests of `runs_test` and
`checkpoints_test` that need tasks in the inventory itself wait for the mounted task folder (T6); so does the one of
`claude_code_test`, which goes with that file in T2.

| File | Verdict | Reason |
|---|---|---|
| `test_helper.exs` | change | The line that loads the ChatGPT helper goes. |
| `eab/activity_test.exs`, `eab/baseline_test.exs`, `eab/build_seed_test.exs`, `eab/build_seed_docker_test.exs`, `eab/cache_test.exs`, `eab/command_test.exs`, `eab/database_seed_test.exs`, `eab/evidence_test.exs`, `eab/image_presence_test.exs`, `eab/model_speed_test.exs`, `eab/model_test.exs`, `eab/pi_docker_test.exs`, `eab/pipeline_test.exs`, `eab/preparation_test.exs`, `eab/retention_test.exs`, `eab/store_test.exs`, `eab/test_adapter_test.exs`, `eab/thinking_test.exs` | keep | They test files that stay, and name nothing that is dropped or renamed. |
| `eab/baseline_docker_test.exs`, `eab/storage_test.exs`, `eab/task_grading_docker_test.exs` | change | They name the image tag's prefix; the last also the task format. |
| `eab/candidates_test.exs` | change | The import check without review and admission; a made-up task. |
| `eab/checkpoints_test.exs`, `eab/inventory_test.exs`, `eab/runs_test.exs` | change | Made-up tasks in a mounted task folder, a run over a chosen list, the release of one run; the series and Claude Code cases go. T1 removed one assertion from `runs_test` ("Claude Code validation runs record their harness and are never publishable"): that `Eab.Results.export!/1` refuses a validation run. |
| `eab/fixtures_test.exs` | change | A made-up task; extra packages; the older-format and browser cases go. |
| `eab/grader_test.exs` | change | The optional partial control; a made-up task. |
| `eab/readiness_test.exs`, `eab/runner_test.exs` | change | A made-up task in place of a bench case. |
| `eab/task_contract_test.exs` | change | The one format. |
| `eab/source_test.exs` | change | The fetch from a mirror. |
| `eab/pi_test.exs` | change | One case for the ChatGPT back end goes. The cases with made-up llama.cpp and Strata replies stay. |
| `eab/measurement_test.exs`, `eab/report_test.exs` | change | The changed sentence and report lines. |
| `eab/anthropic_test.exs`, `eab/openai_test.exs`, `eab/chatgpt_auth_test.exs`, `support/chatgpt_fixture_helper.exs`, `eab_web/chatgpt_test.exs` | drop | The cloud back ends. `eab_web/chatgpt_test.exs` went in T1: all 5 of its tests drive the web page. |
| `eab/claude_code_test.exs`, `eab/claude_code_docker_test.exs`, `eab/claude_code_hook_test.exs`, `claude_code/hook_test.py` | drop | The Claude Code harness. T1 removed the 10 tests of `claude_code_test` that post to the harness's endpoints in `lib/eab_web/claude_code_controller.ex` through Phoenix's test connection; the other 11 stay until T2. |
| `eab/memory_monitor_test.exs`, `support/memory_collector.mjs` | drop | The memory collector. |
| `eab/browser_docker_test.exs` | drop | Browser support. |
| `eab/results_test.exs`, `eab/series_test.exs`, `eab/comparison_test.exs`, `eab/log_sections_test.exs`, `eab_web/dashboard_test.exs` | drop | The results page, the run series, the comparison and the web page. |
| `eab/bench_parity_test.exs`, `eab/factory_test.exs`, `support/` with made-up tasks | **new** | Section 2.3 and section 6, change 5. |
| `eab/model_identity_test.exs` | **new** | The bench's test of `lib/eab/model_identity.ex` is not copied (section 1). It is written again with made-up values, without the cases that open the web page. |

## 6. The changes to make

| # | Change | Files | How it is checked |
|---|---|---|---|
| 1 | **The machine's label and a low CPU share, set by the engine.** `EAB_DOCKER_LABELS` (a list of `key=value`) and `EAB_CPU_SHARES` (a number) are added to each of the three `docker run` calls: the workspace, Postgres and ClickHouse. Unset, the arguments are the bench's. The share is a weight under load and does not lower the cap of 2 CPUs. The labels also go on the images the engine builds. The controller's own container gets both from `compose.yaml`. | `lib/eab/sandbox.ex` (`start/2`), `lib/eab/fixtures.ex` (`build/3`), `lib/eab/agent_image.ex`, `lib/eab/service_images.ex`, `config/runtime.exs`, `compose.yaml` | The parity test pins the arguments with both unset; a test with both set. |
| 2 | **Tasks read from a mounted folder.** The inventory is the folders under `EAB_TASKS_DIR` (default `/tasks`), in the order of their ids. Nothing about tasks is built into the controller's image, so a new batch needs no rebuild. A run and a check each work on the list they are given. | `lib/eab/inventory.ex`, `lib/eab/release.ex`, `lib/eab/runs.ex`, `lib/eab/qualification.ex`, `lib/eab/checkpoints.ex`, `Dockerfile`, `compose.yaml`, `config/` | `inventory_test`, `runs_test` and `checkpoints_test` with a made-up task folder. |
| 3 | **Extra system packages per task.** `runtime.packages` is a list of package names. They are installed by one more line in the toolchain stage. A task with no list gets the bench's recipe, byte for byte. The list is part of `runtime`, which already keys the image and the build seed. | `lib/eab/fixtures.ex` (`dockerfile/4`), `lib/eab/task_contract.ex` | The parity test for an empty list; `fixtures_test` for a list. |
| 4 | **The source from the upstream repository, with a mirror as backup.** A task names only the upstream repository and the commit. The engine fetches that commit by its id from upstream. When that fails, it fetches the same id from the mirror named for that repository in the file `EAB_MIRRORS` points at. The tree hash is checked in both cases, so a mirror cannot serve other content. The receipt says where the source came from. The archive is kept after the first fetch, as now. A mirror's address is part of the installation, never of a task. | `lib/eab/source.ex`, `config/runtime.exs` | `source_test` with two local repositories. |
| 5 | **Entry points for scripts,** in one module. `import(dir)` checks every bundle under a folder and copies the valid ones into the task folder; it refuses an id that exists with other bytes, and a repository on the hold-out list. `check(ids)` runs the gate of section 4 and writes one result per task. `export(ids, dest)` copies checked tasks and a table of their gate results. `start_run(url, ids, settings)` starts a teacher run on tasks that have a statement. `kept_sessions(run)` lists the attempts that completed and passed, with their folders. `status()` says what is running. The long ones return at once with a job id and write their progress to files. They are called through the release's `rpc` command; a small script wraps that. | new `lib/eab/factory.ex` and `bin/factoryctl`; `lib/eab/candidates.ex`, `lib/eab/qualification.ex`, `lib/eab/runs.ex`; new `config/holdout.json` | `factory_test` on a made-up task, then job T10. |
| 6 | **A name of its own.** The inventory id is `elixir-task-factory-v1`. Image tags start with `elixir-task-factory:`; the label keys are `etf.installation` and `etf.run`; container names start with `etf-`. The release, the Compose service, its image and its volume are named `factory`. The report is titled "Task run report". The Elixir modules keep the prefix `Eab` and the settings keep `EAB_`, so that the code can still be compared with the bench, and the names inside the container stay (section 2). The tag prefix matters most: the engine removes only images whose tags all carry its own prefix, so with a prefix of its own a factory on the same machine as a bench controller can never remove the bench's images, nor the bench the factory's. | `config/factory.json`, `mix.exs`, `compose.yaml`, `Dockerfile`, `lib/eab/agent_image.ex`, `lib/eab/build_cache.ex`, `lib/eab/fixtures.ex`, `lib/eab/service_images.ex`, `lib/eab/retention.ex`, `lib/eab/storage.ex`, `lib/eab/sandbox.ex`, `lib/eab/report.ex` | A search of the code for the bench's names outside the list of section 2; the tests that name tags. |
| 7 | **The one format, with an optional partial control.** `schema_version: 3` as in section 3. With `partial_control.present` false, the controls are the unchanged project, the reference and the early exit. Done in T5. | `lib/eab/task_contract.ex`, `lib/eab/grader.ex` (`qualify/5`, `valid_controls?/5`, `partial_patch/1`), `lib/eab/candidates.ex`, `lib/eab/inventory.ex`, `lib/eab/release.ex` | `task_contract_test`, `grader_test`, `candidates_test`, and `task_grading_docker_test`, which grades a made-up task with a partial fix and one without. |
| 8 | **A second round of controls.** After the first round passes, the unchanged project and the reference are graded again, and the named outcomes compared. | `lib/eab/qualification.ex`, `lib/eab/grader.ex` | `grader_test` with a made-up unstable test. |

Change 1 covers the containers. Image builds run inside Docker's builder and take no CPU share from `docker run`.
They are bounded another way: the image sets two Erlang schedulers, and `EAB_PREPARE_WORKERS` (default 2) bounds how
many builds run at once.

## 7. The order of the trimming jobs

Each job is one session, sized to stay under about three hours; none has been timed. Each ends with the format check
and the tests passing, a commit to this folder, and its line in the table below.

**What every job needs.** A machine that can compile and test: Docker with Buildx, and the bench's tooling image
built from this folder's `Dockerfile` (`--target tooling`). The checks are the bench's own
(`docs/runbook.md`, "Bounded correctness checks"): `mix format --check-formatted`, then
`MIX_ENV=test mix test --warnings-as-errors`, and the same with `EAB_DOCKER_TESTS=1` and the Docker socket for the
tests that start containers. The first build downloads the Elixir, Node and Ubuntu base images, the Hex packages and
Pi's npm packages. The Docker tests do not pull their database images: their container has no network, so
`postgres:16-alpine`, `postgres:18-alpine`, `clickhouse/clickhouse-server:24.12.2.29-alpine` and
`clickhouse/clickhouse-server:25.11.5.8-alpine` are pulled before they run (job T0). The maintainer's laptop cannot
do any of this: it only edits files and runs Git. So every job runs on the 7-GPU machine's CPU, and needs that machine
free and the downloads allowed. Job T0's scripts do each step there:
[`docs/data/2026-11-12_factory_t0/run/`](../docs/data/2026-11-12_factory_t0/README.md), including a build through a
Docker client image that carries Buildx, for a machine whose `docker` has none.

The jobs run in this order, one at a time. Several edit the same files (`runs.ex`, `agent.ex`, `fixtures.ex`,
`mix.exs`), and all of them share one machine.

| Job | What it does | Done when |
|---|---|---|
| T0 | **The starting point.** Build the tooling image and run the tests of the unchanged copy. Write the parity test (2.3) and the new test of `model_identity.ex` (5.6). | A table says which tests pass and which fail only because the bench's cases are not here (5.6). The two new tests pass. |
| T1 | **The web page, the results page, the run series and the comparison go.** `lib/eab_web/`, `results*`, `series`, `comparison`, `log_sections`, the Mix task, their `priv/` files and tests; the edits in `runs.ex`, `application.ex`, `config/`, `mix.exs`. It comes first because the page calls every other part that is dropped. | The project compiles without Phoenix; the remaining tests give the same results as in T0. |
| T2 | **The other harness and the cloud back ends go.** Claude Code, the Claude API, the ChatGPT subscription; the edits in `agent.ex`, `harness.ex`, `model.ex`, `pi_gateway.ex`, `runs.ex`, `application.ex`, `mix.exs`. | The parity test and `pi_test` pass with `pi.ex` untouched. |
| T3 | **The memory collector goes.** The four files, their tests, and the edits in `runs.ex`, `report.ex`, `config/runtime.exs`, `compose.yaml`, `Dockerfile`. | A run starts in `runs_test` with no memory settings. |
| T4 | **The browser support goes,** with the one bench project's profile; measuring is switched off. `browser.ex`, `fixtures.ex`, `agent.ex`, `baseline.ex`, `measurement.ex`. | The parity test passes: the recipe and the instruction text have not moved. |
| T5 | **The one format** (change 7): `task_contract.ex`, `grader.ex`, `candidates.ex`, `release.ex`, and the made-up tasks that replace the bench cases in the tests. | Every test of 5.6 that needed a bench case passes on a made-up task, with and without a partial fix. |
| T6 | **The mounted task folder** (change 2), with runs, checks and releases over a given list. | The controller's image builds with no task in it; a run over two of three made-up tasks touches only those two. |
| T7 | **The name, the labels and the CPU share** (changes 1 and 6). | The Docker tests show the labels and the share on every container the engine starts, and no image or container with the bench's names. |
| T8 | **Extra packages and the mirror** (changes 3 and 4). | A made-up task with a package list builds; a source is fetched from a second local repository when the first is gone. |
| T9 | **The entry points and the second round** (changes 5 and 8). | `factory_test` passes: import, check, export, start and list. |
| T10 | **One made-up task from end to end,** through the controller's image: imported, checked, run against a stand-in model server as the engine's own tests do, and listed as a kept session. | The kept session's files are the ones the design note's section 7 lists. After it the factory can be installed for the pilot (job P2 of the design note). |

### What has landed

| Date | Job | Commit | Tests |
|---|---|---|---|
| 2026-11-12 | The copy, unchanged, from the bench's commit `28c064ca` | `470301e` | not run |
| 2026-11-12 | T0: the tooling image built; the unchanged copy's format check and tests run; `test/eab/bench_parity_test.exs` and `test/eab/model_identity_test.exs` added ([data](../docs/data/2026-11-12_factory_t0/README.md)) | `dd8a86b` | format check passes; unchanged copy 212 of 284 passed without Docker and 217 with it, 65 failed in both (48 need the bench's cases, 17 read a bench file that was not copied), 2 not run; the two new tests 6 of 6 and 8 of 8 |
| 2026-11-12 | T1: `lib/eab_web/`, the results page (`results.ex`, `results/`), the run series, the comparison, the log sections, the Mix task, `priv/static/`, `priv/admitted_validation_runs.json` and their 6 test files removed; Phoenix, LiveView, Bandit and LazyHTML out of the dependencies (14 packages leave `mix.lock`); the edits in `runs.ex`, `application.ex`, `config/`, `mix.exs` and the root files ([data](../docs/data/2026-11-12_factory_t1/README.md)) | `fb64f08` | format check passes; compiles with warnings as errors; 176 of 218 passed without Docker and 181 of 223 with it, 42 failed in both (41 need the bench's cases, 1 reads an uncopied bench file), 7 and 2 excluded; all 225 remaining tests end as in T0, 73 are gone (63 with their files, 10 removed from `claude_code_test`); the parity test 6 of 6, untouched |
| 2026-11-12 | T5: the one task format (change 7) in `task_contract.ex`, `grader.ex` (`qualify/5`, `partial_patch/1`, `valid_controls?/5`), `candidates.ex`, `inventory.ex` and `release.ex`; three made-up tasks in `test/support/` replace the bench's cases in 7 test files; the parity test's inputs in the one format ([data](../docs/data/2026-11-12_factory_t5/README.md)) | `f6dbdde` | format check passes; compiles with warnings as errors; 194 of 218 passed without Docker and 199 of 223 with it (T1 176 and 181), 24 failed in both, 7 and 2 excluded; no test that passed in T1 fails: 16 now pass, 4 replaced by 4 new ones that pass; the 24 failures are T1's, 22 need tasks in the inventory (T6) and 2 are in `claude_code_test` (T2); the Docker test grades a made-up task with a partial fix and one without; the parity test 6 of 6, with the bug-fix and requirements texts unchanged, the optional-tests and refactor texts removed and a captured feature text added |
| 2026-11-12 | P2 (pilot): the controller built as `elixir-task-factory:pilot` (the line `COPY cases cases` removed from the `Dockerfile`, no other edit) and started once on the build machine with no task ([data](../docs/data/2026-11-12_pilot_controller/README.md)) | see the data folder | no tests run; the controller answers `rpc` with an empty inventory, `docker` inside it is the wrapper, and `Eab.Candidates.import/1` takes a made-up task |
| 2026-11-12 | P4: the bundle maker (section 3.5), `lib/eab/bundle_maker.ex` and `lib/eab/bundle_probe.ex`, with `config/holdout.json` and a provisional recipe for ex338 in `recipes/`; three ex338 pull requests made into task folders, each passing the source check and the import check ([data](../docs/data/2026-11-12_pilot_bundle_maker/README.md)) | `816df6d` | format check passes; compiles with warnings as errors; 201 of 225 passed without Docker and 207 of 231 with it (T5 194 and 199), 24 failed in both, 8 and 2 excluded; every T5 test ends as in T5, and the 8 new tests (7 in `bundle_maker_test`, 1 in `bundle_probe_docker_test`) pass; the parity test 6 of 6, untouched |

## 8. What is not decided, and what is not verified

**Not decided:**
- the licence line for this folder (section 1);
- the rule by which the bundle maker names a task `bug_fix` or `feature`. Job P4 uses a provisional one (3.5);
- which existing test files the bundle maker puts into `grading.preservation`. Job P4 uses the recipe's command
  for the existing tests (3.5);
- whether a task whose every partial variant passes the hidden tests (`no_variant_fails`) stays in the pool or is
  dropped. This page keeps it and counts it apart;
- whether a fix spread over two pull requests is ever combined. The pilot does not combine.

**Not verified:**
- The cut list comes from reading the source and from searching it for the names of the dropped modules. Job T1
  compiled the rest with warnings as errors after removing the page's parts; what it found that the list had not
  said is in the rows of `application.ex`, `runs.ex`, `mix.exs`, `config/runtime.exs` and the three test rows that
  name T1. The other dropped parts (T2 to T4) have not been removed yet, so the same can still happen there.
- The controller's image does not build: its `Dockerfile` copies `cases/`, which is not here, until that line goes
  (T6). The tests use only the tooling image, which builds from the copy (T0).
- Two tests of the copy have not run: `eab/browser_docker_test` (it builds from the Playwright image, a download job
  T0 was not allowed) and `eab/claude_code_hook_test` (the tooling image has no `python3`). Both are dropped.
- That each trimming job fits three hours.
- The made-up tasks are graded in an image built from the tooling image, not through the workspace recipe of
  section 2.1; the recipe is built for a made-up task first in T10. `fixtures_test` "recipes reconcile seeds before
  compilation and export an independent fixture" loops over the inventory, which is empty until T6, so it passes
  without checking any task (job T5).
- That many hundred tasks in one folder are fast enough. The engine lists the folder on every lookup and hashes every
  task's files when a run starts. Change 2 makes a run work on its own list; the cost that remains is measured in
  the pilot.
- That a CPU share on the containers is enough for a shared machine during image builds (section 6).
