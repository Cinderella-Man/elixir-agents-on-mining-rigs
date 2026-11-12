# The task factory's mounted task folder (2026-11-12)

Job T6 of the [task factory](../../../factory/README.md) (section 7), for registry row [E68](../../../experiments.md):
change 2 of the factory's README, section 6. The inventory is now the task folders under `EAB_TASKS_DIR` (default
`/tasks`), mounted into the controller, so nothing about tasks is built into its image. A run, a retry, a repeat and
a check each freeze only the tasks they are given, and resume checks only that release. The bench's own checks ran
and were compared, test by test, with job P4's runs
([2026-11-12_pilot_bundle_maker](../2026-11-12_pilot_bundle_maker/README.md)). Everything ran on the CPU of the
7-GPU machine, in the tooling image `eab-tooling:dev` that T0 built, on 2026-11-12 between 03:01 and 03:15 (UTC+1).

## Result

- **The project compiles with warnings as errors, and the format check passes.**
- **No test that passed in P4 fails now.** The 22 tests that failed in T5 and P4 because the inventory held no task
  now pass on made-up tasks in a temporary task folder. Three tests are new and pass.

  | Run | Passed | Failed | Excluded | P4 |
  |---|---:|---:|---:|---|
  | `MIX_ENV=test mix test --warnings-as-errors` | 226 | 2 | 8 | 201, 24, 8 |
  | the same with `EAB_DOCKER_TESTS=1` and the Docker socket | 232 | 2 | 2 | 207, 24, 2 |

- **The 2 failures are in `claude_code_test`,** a file that goes in job T2, and fail as in P4: one reads a bench file
  that was not copied, and one takes the first task of the inventory, which that file leaves empty.
- **The parity test passes untouched,** 6 of 6 in both runs; `test/eab/bench_parity_test.exs` was not edited.
- **The controller's image builds with no task in it**: `elixir-task-factory:t6`, 779 MB by `docker images` (194 MB
  of content), id `sha256:9d81d53b7230`. It was not started. Its last stage copies the release,
  `config/benchmark.json` (no case list since this job), `lib/`, `mix.lock` and three folders of `priv/` (`fixtures`,
  `pi`, `claude_code`); no task file is in the build, and the build context was 531 kB.

### The tests that changed

| Test | P4 | Now | Why |
|---|---|---|---|
| 12 in `runs_test`, 10 in `checkpoints_test` | failed | passed | their runs freeze made-up tasks in a temporary task folder (`Eab.MadeUpTasks.mount!/1`); the two tests that need four tasks add a copy of `ledgerette-pr-2` under a new id (`copy!/2`) |
| `runs_test` "a run over two of three made-up tasks touches only those two" | | new, passed | the test section 6 names: the run, its release and its records hold only the two tasks; the third task changes and a fourth arrives during the run, and the run still resumes; a change to one of its own tasks stops the resume; a run with no list, an unknown task or a repeated task is refused |
| `checkpoints_test` "a release freezes only the tasks it is given, and resume checks only those" | | new, passed | a release of two of three tasks, in the order of their ids; other tasks may change or arrive; a task of the release that leaves the folder, an unknown task and a folder not named by its task's id are refused |
| `inventory_test` "the inventory is the task folder, in the order of its ids, and nothing else" | | new, passed | the folder decides membership and order; a list of cases in the configuration is ignored; a protocol binds only the tasks it is given; another folder is another inventory with no rebuild |

Four tests that passed in P4 now run on the mounted folder and keep their names: the two other tests of
`inventory_test` (the folder is `EAB_TASKS_DIR` in place of `cases/`), and two preparation tests of `runs_test`
(`prepare_all/0` became `prepare/1`, which takes the list). In `checkpoints_test` "same immutable release
is reusable and frozen fixture corruption is rejected" checks `case.json` in place of `ticket.md`, because the first
made-up task has no statement. `fixtures_test` "recipes reconcile seeds before compilation and export an independent
fixture" now checks the three made-up tasks; in T5 and P4 the inventory was empty, so it checked none. `fixtures_test`
"required acceptance checks and unknown future grading rules invalidate controls" copies the made-up tasks into a
task folder in place of a `cases/` folder.

## What changed

| File | Change |
|---|---|
| `lib/eab/inventory.ex` | `tasks_dir/0` (`EAB_TASKS_DIR`, default `/tasks`); `all/0` lists the folders that hold a `case.json`, in the order of their ids; `member?/1` answers a lookup without listing the folder; `config/0` is the configuration without a case list; `protocol/1` binds only the tasks it is given. |
| `lib/eab/release.ex` | `freeze/1` takes the list: it refuses an empty or repeated list, a task the folder does not hold, and a folder not named by its task's id, and freezes the tasks in the order of their ids. `verify!/2` checks the inventory's id, Pi and the release's own tasks, not the whole folder. |
| `lib/eab/runs.ex` | `start/4` takes `cases: ids` (a harness check freezes its one task); `prepare_all/0` became `prepare/1`; a retry or a repeat freezes only the tasks it selects, after checking that they, the inventory's settings and Pi are as in the source run's release. |
| `lib/eab/qualification.ex` | `run/3` takes the list and freezes only it. |
| `lib/eab/checkpoints.ex` | `validate_cases!/2`: a run's tasks are its release's tasks, in the same order, whatever chose them. |
| `lib/eab/candidates.ex` | Two lookups of the whole inventory became `Inventory.member?/1`. |
| `config/benchmark.json` | The bench's list of 20 case names is gone. |
| `config/config.exs`, `config/runtime.exs` | `tasks_dir` from `EAB_TASKS_DIR`; in the tests an empty temporary folder. |
| `Dockerfile`, `.dockerignore`, `.gitignore` | `EAB_TASKS_DIR=/tasks` in the image; a local `tasks/` folder stays out of the image and out of Git. |
| `compose.yaml` | The task folder `${EAB_TASKS_HOST_DIR:-./tasks}` mounted at `/tasks`, and `EAB_TASKS_DIR=/tasks`. |
| `test/support/made_up_tasks.exs` | `mount!/1` and `copy!/2`. |
| 4 test files | As above. |

Nothing of the factory's README, section 2 changed: none of the files it pins, no instruction text, no grading code.

## Starting a controller with the task folder

The controller reads its tasks from `/tasks` inside the container. To the `docker run` of
[the pilot's controller.sh](../2026-11-12_pilot_controller/run/controller.sh) (`up`), or to Compose, add the host
folder that holds the task folders:

```bash
-v <host task folder>:/tasks -e EAB_TASKS_DIR=/tasks
```

The image sets `EAB_TASKS_DIR=/tasks` already; the `-e` only makes it explicit. An image built before this job reads
`cases/` under its own root and ignores both.

## Files

| File | What it holds |
|---|---|
| [tests_compared.tsv](tests_compared.tsv) | One row per test (236): its state in P4's two runs (`p4c_unit`, `p4c_docker`) and in this job's two runs (`t6a_unit`, `t6a_docker`), and the verdict (`same`, `differs`, `new`). |

No new script: the checks are [T5's checks.sh](../2026-11-12_factory_t5/run/checks.sh), with T0's
[sync.sh and test.sh](../2026-11-12_factory_t0/run/), T1's [compare.sh](../2026-11-12_factory_t1/run/compare.sh) and
P2's [controller.sh](../2026-11-12_pilot_controller/run/controller.sh) for the image.

## Exact commands

On the editing machine, after each edit of `factory/`:

```bash
HOST=<build machine> WORK=<work folder> docs/data/2026-11-12_factory_t0/run/sync.sh
```

On the build machine, in `WORK`, with `LABEL=<key>=<value>` for every container started (`CPU_SHARES` is 256):

```bash
WORK=$PWD LABEL=$LABEL run/checks.sh t6a
WORK=$PWD run/compare.sh p4c_unit p4c_docker t6a_unit t6a_docker > tests_compared.tsv
WORK=$PWD SRC=$PWD/src IMAGE=elixir-task-factory:t6 LABEL=$LABEL run/controller.sh build
```

Before the table's runs (`t6a`): a first format check found two files to reformat (`config/config.exs` and
`runs_test`); a focused run of five test files found a type warning in a new test line and one `fixtures_test` test
that still copied its task into `cases/`; after both fixes, eight test files passed alone (61 tests). A first full run
(`t6`) gave the same test results as the table's (226, 2, 8 and 232, 2, 2) but failed the format check on one line
of `inventory_test`, which was reformatted by hand before `t6a`.

## Images and disk

No image was pulled. The Docker test builds one image from `eab-tooling:dev` and removes it. The controller's image
`elixir-task-factory:t6` was built once from this job's copy (779 MB by `docker images` (194 MB of content), id `sha256:9d81d53b7230`) and kept. Free space on `/`, which holds Docker's
data: 659,201,966,080 bytes before (03:01), 655,527,489,536 before the image build (03:14), 655,462,989,824 after
(03:15). Other jobs ran on the machine at the same time. The test runs removed every container they started.

## Provenance and licence

The code under test is the bench's engine as copied into `factory/` (see its README, section 1, for the licence
question), with this job's edits. The made-up tasks are invented for these tests. The table holds only test names and
states.
