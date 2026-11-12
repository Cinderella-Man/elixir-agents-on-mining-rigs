# The ex338 tasks again, with a focused existing-tests command (2026-11-12)

The second run of job P5 for [axelclark/ex338](https://github.com/axelclark/ex338), for registry rows
[E68](../../../experiments.md) and [E74](../../../experiments.md). The [first run](../2026-11-12_pilot_tasks_ex338/README.md)
dropped 3 of 19 tasks because every task's existing-tests command was the project's whole `mix test`. The grader's
regression step puts the test folders back to the starting commit and runs that command. So the old version of a
test whose assertion the pull request changes failed on the reference. The night chain's manager then decided the
rule of E74 on 2026-11-12, for the owner to review. It is now in the factory
([factory README](../../../factory/README.md), section 3.5):

- `grading.preservation` = `mix test` followed by a sorted list of existing test files. The bench's 20 cases do
  the same: each names a few test files near the change. The maker writes a first list: the test files present at
  the starting commit that the pull request's tests change or delete, and those that match a code file it changes
  by path (`lib/<path>/<name>.ex` gives `test/<path>/<name>_test.exs`). An empty list is refused
  (`no_existing_tests`).
- The probe (`Eab.BundleProbe.finish/4`) runs those files in their starting-commit version, twice on the unchanged
  project and twice on the reference code. It leaves out every file with a test that fails or ends differently in
  the two runs, and records each in `grading.preservation_left_out` with the reason. When no file is left, it
  refuses with `no_existing_tests`.
- The whole-suite command stays in the recipe for the project's own check (job P3's kind of run). No task carries
  it.

The same 19 pull requests were made and checked again, with the same scripts as the first run and the same
second-round rule, through a controller rebuilt from the changed factory. Everything ran on the CPU of the 7-GPU
machine on 2026-11-12, between 03:59 and 04:14 (UTC+1).

## Result

**19 pull requests, 19 made, 19 prepared; 16 became checked tasks (first run: 11). 3 were dropped by the probe and
none by the controls (first run: 2 and 6).** All 16 also pass the strict second round, where every named test must
end as in the first round. In the first run 9 passed that rule.

| Check (README section 4) | In | Passed | Dropped | First run |
|---|---:|---:|---:|---|
| The maker makes the folder (3.5) | 19 | 19 | 0 | 19, 0 |
| 2. The source pair rebuilds | 19 | 19 | 0 | 19, 0 |
| 1. The bundle loads | 19 | 19 | 0 | 19, 0 |
| 3. The environment builds | 19 | 19 | 0 | 19, 0 |
| The probe: hidden tests, existing tests, partial fix | 19 | 16 | 3 | 17, 2 |
| 4.–8. The controls | 16 | 16 | 0 | 11, 6 |
| 9. The second round (rule of the first run) | 16 | 16 | 0 | 11, 0 |
| 9. The second round, strict (every named test) | 16 | 16 | 0 | 9, 2 |

**How the verdicts changed:**

| Pull request | First run | This run | Why |
|---|---|---|---|
| #1451, #1395 | dropped: an old test of the pull request's own test file failed on the reference | checked | the probe left that file out (`draft_pick_test.exs`, `draft_picks/admin_test.exs`: `fails_on_reference`); the other files of the list stay |
| #1339 | dropped for the same cause | dropped by the probe: `no_existing_tests` | its one candidate file, `fantasy_team_draft_queues_live/edit_test.exs`, fails on the reference, so no file is left |
| #1458, #1446, #1411 | dropped: an unstable test of the existing suite failed in the reference's regression run | checked | the unstable tests (`FantasyTeamsTest` "standings_history/1", `DraftQueuesTest` "get_top_queue/1") are in files the focused command does not name |
| #1447, #1391 | dropped by the probe | the same | the pull request: #1447's hidden tests do not compile before the fix; none of #1391's fails before it |
| the other 11 | checked | checked | |

**The existing-tests command per task.** The maker named 10 files for #1446, 6 for #1447, 5 for #1398, 4 for #1460 and #1451, 3 for #1458, #1394,
#1392 and #1390, 2 for #1452, #1411, #1395 and #1350, and 1 for #1463, #1461, #1457, #1450, #1391 and #1339 (each
list is in `tasks.tsv`, column `existing_first_reading`). The probe left out 3 files in 19 tasks, all `fails_on_reference`, and none as
unstable: in the 4 runs per task, no test of a named file changed state. Of the 16 checked tasks, 14 keep every file the
maker named; #1451 keeps 3 of 4 and #1395 1 of 2. A partial fix was found for 14 of the 16 checked tasks; #1411 and #1395
are `single_hunk`.

### Time and disk (planning figures)

- **Wall time:** the gate step took 13 min for 19 pull requests with three at once (03:00:04 to 03:13:13 UTC). The
  first run took 23 min.
- **The steps of a checked task,** averages over the 16 (each value is a column of `tasks.tsv`): prepare 0.1 s
  (every image was reused from the first run, so this is not a cold figure; the first run's prepare averaged
  55.8 s), the two diagnostic runs 12.0 s, the probe 49.5 s (settling the existing tests is about 25 s of it), the
  controls 53.0 s, the second round 27.2 s; in all 141.8 s (first run 250.5 s). The controls and the second round
  are about half as long as in the first run, because each test run covers a few files and not 1,087 tests.
- **Making** a folder from a fresh Git cache took under 1 s for 17 pull requests, 1.7 s for #1411 and 7.5 s for
  #1447 (`make_s`).
- **Disk:** free space on `/` went from 647,888,433,152 bytes (03:59) to 647,465,877,504 (04:14): 0.42 GB. No
  image was built for a starting commit, because all were reused. The controller image `elixir-task-factory:pilot3`
  (778 MB by `docker images`, 193,261,885 bytes by `docker image inspect`) was built for this run.

## The factory change

Public commit `1063fb9`: `lib/eab/bundle_maker.ex` (`existing_tests/4`, `test_path/2`, the refusal `no_existing_tests`) and
`lib/eab/bundle_probe.ex` (`settle/4`, `preservation_run/4`, the new step in `finish/4`), with two new tests in
`test/eab/bundle_maker_test.exs`. In `test/eab/bundle_probe_docker_test.exs` the probe now also leaves out an
existing test whose assertion a made-up reference changes. The grading functions of README section 2.2 and the
instruction sentences are untouched. Only the command a task carries changes, and with it the "Test command" line
the model reads. Checks, run on the build machine in the tooling image:

| Run | Passed | Failed | Excluded | Reference |
|---|---:|---:|---:|---|
| `mix test --warnings-as-errors`, on job T2's tree | 197 | 0 | 6 | T2: 195, 0, 6 |
| the same with `EAB_DOCKER_TESTS=1` | 202 | 0 | 1 | T2: 200, 0, 1 |
| after the rebase onto job T3, without Docker | 189 | 0 | 6 | T3: 187, 0, 6 |
| after the rebase onto job T3, with Docker | 194 | 0 | 1 | T3: 192, 0, 1 |
| after the rebase onto job T4, without Docker | 189 | 0 | 5 | T4: 187, 0, 5 |
| after the rebase onto job T4, with Docker | 194 | 0 | 0 | T4: 192, 0, 0 |

On T2's tree, 201 tests end as in T2 and the 2 new ones pass; after the rebases, 193 end as in T3 and 192 as in
T4, and the 2 new ones pass. The parity test passes 6 of 6, untouched, and the format check passes. The controller image of this run was built from the change on T2's tree. Jobs T3 (the memory
collector removed) and T4 (the browser support removed) landed while this run went on; the controller runs with memory collection off.

## Files

| File | What it holds |
|---|---|
| `tasks.tsv` | one line per pull request, as in the first run, plus: `verdict_r1` (the first run's verdict), `existing_first_reading` (the files the maker named), `existing_kept` (the files of the task's command), `existing_left_out` (with the reason), `second_round_strict` |
| `run/make.exs`, `run/gate.exs` | as in the first run; `gate.exs` also records the maker's list and the probe's kept and left-out files |
| `run/run.sh` | as in the first run, with `SUB`, the folder in the controller's data (`p5r2`) |
| `run/table.sh` | `tasks.tsv`, with `R1` pointing at the first run's table |
| `run/controller.sh`, `run/docker_shim.sh` | job P2's controller script, with `TASKS`: the host task folder mounted at `/tasks`, as job T6 added (`EAB_TASKS_DIR=/tasks`); here an empty folder, so that the candidates are not in the inventory |

The pull requests were chosen as in the first run (its `chosen.tsv`). The task folders are not published (licence
scan and hold-out check first).

## Exact commands

As in the first run, with this folder's `run/` in `$JOB/run`:

```sh
export WORK=<the controller's folder> JOB=<this job's folder>
WORK=$WORK SRC=$JOB/src IMAGE=elixir-task-factory:pilot3 $JOB/run/controller.sh build
$JOB/run/run.sh stage
IMAGE=elixir-task-factory:pilot3 RUN=$JOB/run TASKS=$JOB/mounted $JOB/run/controller.sh up
$JOB/run/run.sh make
P5_CONCURRENCY=3 $JOB/run/run.sh gate
KEEP=<where the checked folders go> $JOB/run/run.sh keep
OUT=$WORK/factory/data/p5r2/out R1=<the first run's tasks.tsv> $JOB/run/table.sh > tasks.tsv
$JOB/run/controller.sh down
```

The numbers: `1463 1461 1460 1458 1457 1452 1451 1450 1447 1446 1411 1398 1395 1394 1392 1391 1390 1350 1339`.

## Licence and provenance

As in the first run: ex338's pull requests (MIT, read by the maker; the licence scan, E51, has the last word). The
tables hold pull request numbers, commit ids, test file names and counts. No statement was written.
