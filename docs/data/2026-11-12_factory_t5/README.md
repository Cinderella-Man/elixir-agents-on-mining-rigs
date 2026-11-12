# The task factory's one task format, with made-up tasks in place of the bench's cases (2026-11-12)

Job T5 of the [task factory](../../../factory/README.md) (section 7), for registry row [E68](../../../experiments.md).
The factory now reads one task format, `schema_version: 3` (the factory's README, section 3), with an optional
partial-fix control. Its tests use made-up tasks under `factory/test/support/` in place of the bench's cases, which
are never copied here. The bench's own checks ran and were compared, test by test, with job T1's runs
([2026-11-12_factory_t1](../2026-11-12_factory_t1/README.md)). Everything ran on the CPU of the 7-GPU machine, in the
tooling image `eab-tooling:dev` that T0 built, on 2026-11-12 between 02:03 and 02:17 (UTC+1).

## Result

- **The project compiles with warnings as errors, and the format check passes.**
- **No test that passed in T1 fails now.** 16 tests that failed in T1 because they needed the bench's cases now pass
  on made-up tasks, and 2 more such tests were replaced by new ones that pass (below).

  | Run | Passed | Failed | Excluded | T1 |
  |---|---:|---:|---:|---|
  | `MIX_ENV=test mix test --warnings-as-errors` | 194 | 24 | 7 | 176, 42, 7 |
  | the same with `EAB_DOCKER_TESTS=1` and the Docker socket | 199 | 24 | 2 | 181, 42, 2 |

- **The 24 failures are all T1 failures, unchanged:** 12 in `runs_test` and 10 in `checkpoints_test` need tasks in
  the inventory itself, which comes with the mounted task folder (job T6). 2 are in `claude_code_test`, a file that
  goes in T2: one reads a bench file that was not copied, and one needs a task in the inventory.
- **The Docker test grades two made-up tasks from end to end,** one with a partial fix and one without. For each, the
  controls hold: the unchanged project fails the declared tests in their bodies, the reference passes, the early exit
  is rejected, and the partial fix is rejected (for the task that has one). Then another correct fix with its own
  test passes, and the reference without a test does not.
- **The parity test passes,** 6 of 6 in both runs, with only the edits allowed for T5 (below).

### The parity test

`factory/test/eab/bench_parity_test.exs`, test "the fixed instruction sentences give the bench's text, byte for byte":

| Expected text | Input now | Change |
|---|---|---|
| `@bug_fix_text` (the text of the factory's README, section 2.1) | a v3 bug fix with no requirement sentences and no clarifications (`plain_spec/0`, which was `legacy_spec/1`) | input rewritten; text unchanged |
| `@requirements_text` (two `Required outcome` lines and `Task details`) | a v3 bug fix with `grading.requirements` (`{id, text}` only) and `clarifications` (`contract_spec("bug_fix")`) | input rewritten; text unchanged |
| `@feature_text` | the same input, kind `feature` | **new**: the text was captured from the unchanged copy (commit `470301e`) |
| `@optional_tests_text` | none | **removed**: the one format has no `model_tests` other than `behavioral` |
| `@refactor_text` | none | **removed**: the one format has no `refactor` |

No other line changed: the test's name, its other five tests and every pinned blob id are as in T0, and the test's
moduledoc says what T5 changed and why. The feature text has requirement lines because the bench's format needs at
least one for a feature (its older format knows only bug fixes), so a feature text without them cannot come from the
unchanged copy. The capture ran job T0's `parity_capture.exs` too: its output equals T0's capture except for the
compiler's two lines, the random container names, and one section (the Node recipe) that the new capture prints
and T0's saved capture does not hold.

### The tests that changed

| Test | T1 | Now | Why |
|---|---|---|---|
| 5 in `fixtures_test`, 8 in `readiness_test`, 1 in `runner_test`, 2 in `candidates_test` | failed | passed | a made-up task in place of a bench case (`shelfwise-pr-7`, or a copy of `ledgerette-pr-1`) |
| `candidates_test` "review and source/execution evidence are separate admission gates" | failed | gone | the review record and the admission file are not part of the format |
| `candidates_test` "the import check takes tasks with and without a partial fix, and only in the one format" | | new, passed | in its place: the import check takes tasks with and without a partial fix and without a statement, and refuses 12 kinds of bundle outside the format |
| `grader_test` "all retained PR reference patches satisfy edit rules and have partial controls" | failed | gone | it named the bench's cases and required a partial fix for every task |
| `grader_test` "made-up tasks' reference patches satisfy edit rules and their partial controls are as recorded" | | new, passed | in its place: the same checks on the made-up tasks, with the partial fix as each task records it |
| `task_contract_test` "refactors cannot hide an unstated structural preference or demand behavioral breakage" | passed | gone | `refactor` is not a kind of the format |
| `task_contract_test` "the one format refuses other versions, removed fields and kinds, and unclear partial records" | | new, passed | in its place: 21 manifests the format refuses |
| `task_grading_docker_test` "feature and refactor grading ..." | excluded, passed | gone | it graded Node tasks of kinds `feature` and `refactor`; the format has only ExUnit and no refactor |
| `task_grading_docker_test` "bug-fix and feature grading ..., with and without a partial fix" | | new: excluded, passed | in its place: two made-up ExUnit tasks, one with a partial fix and one without |

`task_contract_test` "new task kinds have explicit test policies and solver-visible requirements" and "qualification
rejects missing capabilities only as named completed test failures" keep their names; they now check both kinds with
and without a partial fix, and the controls with and without one.

One test passes without testing anything, as in T1: `fixtures_test` "recipes reconcile seeds before compilation and
export an independent fixture" loops over the inventory, which is empty until the mounted task folder (T6).

## What changed

| File | Change |
|---|---|
| `lib/eab/task_contract.ex` | Reads `schema_version: 3` only: kinds `bug_fix` and `feature`, adapter `exunit`, `model_tests` `behavioral`, `acceptance_patch` `reference-tests.patch`, `partial_control` present or absent with one of three reasons, optional `grading.requirements` (`{id, text}`) and `clarifications`; refuses the removed fields. The instruction text keeps the bench's code path. |
| `lib/eab/grader.ex` | `qualify/5`: the early exit is the task's `integrity.patch`; the partial control runs only when the task records one, and the saved controls record `partial_control`. `partial_patch/1` returns nil without one. `valid_controls?/5` takes nil for a missing partial fix. Nothing of README section 2.2 changed. |
| `lib/eab/candidates.ex` | The import check for the format: the files a task may hold, `incomplete.patch` exactly when recorded, `ticket.md` with `statement.json` and its hash, the early exit's shape, the folders each patch may touch, `runtime.profile` `mix`. `review/2`, `export/2` and `verify_admission!/1` are gone. |
| `lib/eab/inventory.ex` | `statement.json` joins the files that do not void the controls' receipt; `admission.json` and `upstream-tests.patch` leave that list. |
| `lib/eab/release.ex` | No admission check; every task's contract is read when a release is frozen. |
| `factory/test/support/made_up_tasks.exs`, `factory/test/support/tasks/` (3 tasks, 19 files) | The made-up tasks: `ledgerette-pr-1` (a bug fix in two files, with a partial fix), `ledgerette-pr-2` (a feature in one hunk, without one), both on an invented ledger whose source the module writes; `shelfwise-pr-7` (an invented application with Postgres and a Node step, with a statement). |
| 8 test files | As above; `test_helper.exs` loads the made-up tasks. |

## Files

| File | What it holds |
|---|---|
| [tests_compared.tsv](tests_compared.tsv) | One row per test (229): its state in T1's two runs (`t1_unit2`, `t1_docker2`) and in this job's two runs, and the verdict (`same`, `differs`, `gone: test removed`, `new`). |
| [run/checks.sh](run/checks.sh) | The format check, the tests and the Docker tests, one after another, with T0's `test.sh`. |
| [run/capture.sh](run/capture.sh) | Runs T0's capture script and `parity_capture_feature.exs` in the unchanged copy, in a scratch folder. |
| [run/parity_capture_feature.exs](run/parity_capture_feature.exs) | Prints the unchanged copy's instruction text for the feature input. |

The other scripts are T0's and T1's, unchanged: [sync.sh, test.sh, parity_capture.exs](../2026-11-12_factory_t0/run/)
and [compare.sh](../2026-11-12_factory_t1/run/compare.sh).

## Exact commands

On the editing machine, after each edit of `factory/`, and once for the unchanged copy:

```bash
HOST=<build machine> WORK=<work folder> docs/data/2026-11-12_factory_t0/run/sync.sh
git archive 470301e factory | ssh <build machine> tar -x -C <work folder>/t5/copy470
rsync -a docs/data/2026-11-12_factory_t5/run/ <build machine>:<work folder>/t5/run/
```

On the build machine, in `WORK`, with `LABEL=<key>=<value>` for every container started (`CPU_SHARES` is 256):

```bash
WORK=$PWD LABEL=$LABEL t5/run/capture.sh
docker run --rm --label $LABEL --cpu-shares 256 --cpus=2 --user 1000:1000 -e HOME=/tmp -e HEX_HOME=/tmp/hex \
  -v $PWD/src:/app -w /app eab-tooling:dev mix format
WORK=$PWD LABEL=$LABEL t5/run/checks.sh t5a
WORK=$PWD run/compare.sh t1_unit2 t1_docker2 t5a_unit t5a_docker > tests_compared.tsv
```

`mix format` wrote six files of this job's edits on the build machine; they were copied back into `factory/` before
the checks. A first unit run (before the table's) failed the three `candidates_test` tests on a missing temporary
folder in the test's set-up; after the fix the file passed alone, and then in the full runs. The scratch copy was
removed afterwards.

## Images and disk

No image was pulled. The Docker test builds one image from `eab-tooling:dev` and removes it. The capture's
`mix deps.get` and `mix deps.compile` fetched the unchanged copy's locked Hex packages that T1 had removed from the
shared dependency folder, and the precompiled library of its test-only `lazy_html`, into the scratch copy only.
Free space on `/`, which holds Docker's data: 666,181,865,472 bytes before, 665,987,076,096 after. The test runs
removed every container they started.

## Provenance and licence

The code under test is the bench's engine as copied into `factory/` (see its README, section 1, for the licence
question), with this job's edits. The made-up tasks, their projects, repositories, commits and pull requests are
invented for these tests. The scripts here are this repository's. The table holds only test names and states.
