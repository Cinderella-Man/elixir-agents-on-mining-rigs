# The first real training tasks, from ex338 (2026-11-12)

Job P5 for [axelclark/ex338](https://github.com/axelclark/ex338), of the
[task factory](../../research/notes/task_factory_on_the_bench_engine.md) (section 9), for registry row
[E68](../../../experiments.md). For the first time the whole chain ran on a real project: the bundle maker
([factory README](../../../factory/README.md), section 3.5) made the task folders, the engine prepared each starting
commit, `Eab.BundleProbe.finish/4` observed the hidden tests and searched a partial fix, and the gate of README
section 4 ran its controls. Everything ran on the CPU of the 7-GPU machine through the factory's controller, rebuilt
for this job from the factory as it stood on `main` (`e89d1df`), on 2026-11-12 between 03:00 and 03:45 (UTC+1).

## Result

**19 pull requests chosen, 19 made, 19 prepared; 11 became checked tasks, 2 were dropped by the probe and 6 by the
controls.** No task was dropped by the maker, the source check, the import check, the environment or the second
round.

| Check (README section 4) | In | Passed | Dropped |
|---|---:|---:|---:|
| The maker makes the folder (3.5) | 19 | 19 | 0 |
| 2. The source pair rebuilds (`Eab.Provenance.verify/3`) | 19 | 19 | 0 |
| 1. The bundle loads (`Eab.Candidates.import/1`) | 19 | 19 | 0 |
| 3. The environment builds (`Eab.Fixtures.ensure/3`) | 19 | 19 | 0 |
| The probe observes the hidden tests (`Eab.BundleProbe.finish/4`) | 19 | 17 | 2 |
| Import of the rewritten folder, and the environment built again | 17 | 17 | 0 |
| 4.–8. The controls (`Eab.Grader.qualify/3`) | 17 | 11 | 6 |
| 9. A second round of the unchanged project and the reference | 11 | 11 | 0 |

The 11 checked tasks are #1463, #1461, #1460, #1457, #1452, #1450, #1398, #1394, #1392, #1390 and #1350. Ten have a
partial fix that the gate rejects; none was dropped for lacking one. Two of the 17 that reached the controls had no
partial fix (`single_hunk`: #1411, #1395), and both were dropped for another reason.
Every hidden-test failure the probe saw on the unchanged project was in a test's body, none in set-up; one pull
request's hidden tests did not compile there (#1447).

### Why the 8 were dropped

| Cause | Pull requests | Whose | What would fix it |
|---|---|---|---|
| **The existing tests' command runs the old version of a test file the pull request changes.** The reference's regression step (README 2.2, step 4) puts the test folders back to the starting commit and runs `grading.preservation`, which is the recipe's whole `mix test`. When the pull request changes what an existing test asserts, the old test fails on the reference. The failing tests are in the pull request's own test files. | #1451 (3 tests of `draft_pick_test.exs`), #1395 (1 of `draft_picks/admin_test.exs`), #1339 (1 of `fantasy_team_draft_queues_live/edit_test.exs`) | the maker | `grading.preservation` without the test files the pull request changes or deletes: `mix test` with the other existing test files. This is the open question of README section 8 ("which existing test files the bundle maker puts into `grading.preservation`"); not changed here, registered as [E74](../../../experiments.md) |
| **A test of the existing suite failed once in the reference's regression run** and passed in the same task's other full runs. | #1458 (`DraftQueuesTest` "get_top_queue/1 returns pending draft queues for a team and sport"), #1446 and #1411 (`FantasyTeamsTest` "standings_history/1 returns the total points for each team by month") | the project's environment | Leave the unstable tests out of the existing tests' command in the recipe, or run fewer checks at once (see below); registered as [E75](../../../experiments.md) |
| **The hidden tests do not compile on the unchanged project:** they use a struct the pull request adds (`Ex338.Audit.AuditLog`). Check 4 of README section 4. | #1447 | the pull request | nothing |
| **No hidden test fails on the unchanged project:** all 5 pass before and after the fix. | #1391 | the pull request | nothing |

**The unstable existing tests.** Of the 19 tasks' full-suite runs (about 8 per task that reached the controls), these
tests changed state between runs of the same code: `FantasyTeamsTest` "standings_history/1 returns the total points
for each team by month" (in the main run it failed 4 times: the reference's regression in #1446 and #1411, the
unchanged project's existing tests in #1398 and #1452, where it passed in the second round), `DraftQueuesTest` "get_top_queue/1 returns
pending draft queues for a team and sport" (#1458), `ChampionshipTest` "preload_assocs_by_league/2 preloads all
assocs for a league" (#1458, the unchanged project's existing tests, which no check reads) and, in the trial run of
#1460, `AutoDraftTest` "make_picks_from_queues/1 makes two draft picks when autodraft setting is on". Job P3's two
full runs at one starting commit had none. The checks ran three tasks at once, each in containers with a CPU share
of 256 while another job used the machine's CPU, and one diagnostic run (not a check) lost its database connection
in the `ecto.migrate` alias after 3 s (#1451). **The three tasks dropped this way were run once more, one at a time,
after the main run:** #1458 and #1411 passed every control and the second round (in #1458's second round
`FantasyTeamsTest` "standings_history/1" changed again, from failed to passed in the unchanged project's regression
run); #1446 passed every control, and in its second round the same test failed in both of the reference's full runs,
so the rerun dropped it as unstable. So `FantasyTeamsTest` "standings_history/1" changes state with one task at a
time too, and the cause is the project's tests, not only the load. Their verdict stays "dropped": the rerun is
evidence about the cause, not a second chance.

### The second round

The engine's own second round (README section 4, check 9; change 8) is not built yet, so this job ran it: the
unchanged project and the reference graded again in fresh containers, every named test compared with the first
round. **The rule used here:** a task passes when every hidden test ends as in the first round in both controls, the
unchanged project still fails and the reference still passes. A test of the existing suite that changes state is
recorded apart, because it belongs to the project and is the same for every task of it. All 11 passed. In 9 every
named test ended as in the first round; in 2 (#1398, #1452) one existing test, `FantasyTeamsTest`
"standings_history/1", failed in the unchanged project's first run and passed in its second. Under the stricter rule
"every named test", those 2 would be dropped and 9 tasks would remain.

### Time and disk per task (planning figures)

- **Wall time:** the gate step took 23 min for 19 pull requests with three at once (02:11 to 02:34 UTC), about 73 s
  per pull request. One pull request's own time, summed over its steps, was 250.5 s on average for the 11 checked
  tasks (the shortest 187.3 s, #1392; the longest 340 s, #1452; each in `tasks.tsv`), and 44.5 s (#1391) and
  76.7 s (#1447) for the two the probe dropped. Three at once slows each one, so these are upper figures for one at
  a time (est.).
- **The steps of a checked task,** averages over the 11 (each value is a column of `tasks.tsv`): prepare 55.8 s,
  the two diagnostic runs 11.4 s, the probe 18.8 s, the controls 105.3 s (four grades, each with up to three test
  runs of the whole suite of 1,087 tests), the second round 59.2 s. Preparing is short when the engine seeds the
  commit from a prepared neighbour (#1392 26.9 s, #1450 25.5 s) and long when it rebuilds the project (#1452
  134.2 s, #1398 136.2 s, #1350 116.7 s); #1460 reused the trial's preparation (0.1 s). Making a folder took under
  1 s from a warm Git cache (column `make_s`; 6.6 s for the first fetch of #1447 in the trial).
- **Disk:** free space on `/` went from 659,314,761,728 bytes before the job (03:00) to 648,849,375,232 after the
  main run (03:35), and 648,619,061,248 at the end (03:43): 10.47 GB for 19 pull requests and the trial of #1460, about 0.5 GB per pull request (est.:
  another job may have written in the same window). Most of it is the engine's images per starting commit (a project
  image and a seed image of about 1.1 GB each by `docker images`, sharing layers) and the controls' evidence
  (about 2.4 MB of JSON per task). The per-row `disk_free_change_gb` in `tasks.tsv` overlaps between the three tasks
  that ran at once and is not a per-task figure.

## How the pull requests were chosen

From the screening table (`../2026-11-12_pilot_pr_screen/screen_axelclark__ex338.tsv`), every `candidate` whose
starting commit asks for a toolchain the recipe fits. For the 19 newest candidates, the starting commit (the merge
commit's first parent, from the census's merge commit) and its `.tool-versions` and `mix.exs` were read with
read-only GitHub queries:
- 17 (#1463 back to #1390) name Elixir 1.18.3, Erlang 27.3, `~> 1.18`: job P3's period 6, the recipe's own;
- 2 (#1350, #1339) name Elixir 1.17.2, Erlang 27.0.1, `~> 1.17`: period 5. They were tried with the same recipe
  (Elixir 1.18.3) and both prepared and compiled; #1350 became a checked task, #1339 was dropped for the
  `grading.preservation` cause above, not for its environment;
- none of the 19 lists `:redix` in `mix.exs`.

The next older candidate, #1331, is in job P3's period 4b (Elixir 1.16.1, OTP 26.2.1), and every older one is in
period 4b or older; before 2024-03-07 the application also needs a Redis service (E71). They are out:
`chosen.tsv` lists all 305 candidates with "in" or the reason. Nineteen is fewer than the 30 the brief allowed,
because no more candidates fit the recipe.

## Files

| File | What it holds |
|---|---|
| `tasks.tsv` | one line per chosen pull request: made, source check, import, prepared, the diagnostic runs of the hidden tests on the unchanged project and the reference (how many fail, in a body or in set-up), the probe's counts of required tests and starting failures, the partial fix, each control's outcome, the second round, existing tests that changed in it, the verdict, and the seconds of each step |
| `chosen.tsv` | every candidate of ex338's screening, newest first: starting commit, `.tool-versions`, `mix.exs`'s Elixir requirement (read for the 19 in), and "in" or the reason it is out |
| `run/make.exs` | the maker and its two checks for a list of pull requests, evaluated in the controller |
| `run/gate.exs` | prepare, the diagnostic runs, the probe, the import and the gate, the second round, for each made folder, evaluated in the controller |
| `run/run.sh` | the steps on the build machine: `stage`, `make`, `gate`, `keep` |
| `run/table.sh` | `tasks.tsv` from the run's result files, with `jq` |

The task folders are not here: they hold the project's code as patches, and are published after the licence scan
(E51) and the hold-out check. The maker's result lines and the checks are in `tasks.tsv`.

## Exact commands

On the build machine, with the factory from `main` in `$JOB/src`, the controller's scripts from
[`2026-11-12_pilot_controller/run/`](../2026-11-12_pilot_controller/README.md) and this folder's `run/` in `$JOB/run`,
the census and screen tables in `$JOB/tables`, and the 19 numbers in `$JOB/numbers.txt`:

```sh
export WORK=<the controller's folder> JOB=<this job's folder>
WORK=$WORK SRC=$JOB/src IMAGE=elixir-task-factory:pilot2 $JOB/run/controller.sh build
$JOB/run/run.sh stage
IMAGE=elixir-task-factory:pilot2 RUN=$JOB/run $JOB/run/controller.sh up
$JOB/run/run.sh make
P5_CONCURRENCY=3 $JOB/run/run.sh gate
KEEP=<where the checked folders go> $JOB/run/run.sh keep
OUT=$WORK/factory/data/p5/out $JOB/run/table.sh > tasks.tsv
$JOB/run/controller.sh down
```

The numbers, newest first: `1463 1461 1460 1458 1457 1452 1451 1450 1447 1446 1411 1398 1395 1394 1392 1391 1390
1350 1339`. Before the main run, a trial of `gate.exs` on #1460 alone found that the second round's first rule
(every named test the same) dropped it for one existing test (`AutoDraftTest`); the rule above was then written,
and the main run made every folder afresh. The rerun of the three unstable drops used `gate.exs` with
`P5_DIR=/data/p5/rerun` and `P5_CONCURRENCY=1` on copies of their folders.

The controller image `elixir-task-factory:pilot2` (779 MB by `docker images`, 193,604,782 bytes by
`docker image inspect`) was built from `e89d1df`; no other image was pulled or built by hand. The engine built its
images per starting commit through Docker's builder, from the two base images job P3 pulled.

## Licence and provenance

The pull requests are ex338's (MIT, read at each starting commit by the maker; the licence scan, E51, has the last
word). The tables hold pull request numbers, commit ids, test names and counts. No statement was written: the tasks
stay without one until the teacher writes them.
