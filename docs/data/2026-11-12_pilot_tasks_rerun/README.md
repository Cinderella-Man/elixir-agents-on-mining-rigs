# Radiator's six cut-off checks run again on the data-mining machine

Registry rows E68 (the pilot) and E71 (the Redis service). On the morning of 2026-11-12 the 7-GPU machine ran task
jobs beside the model server and a 258 GB file copy. Six of radiator's checks were dropped by that load: the test
command got no Postgres connection within 2 s, or Docker stalled ([the retry](../2026-11-12_pilot_tasks_retry/README.md)).
This job checked those six again on the data-mining machine, one at a time, through the factory's own entry points
(`bin/factoryctl import`, `check`, `export`). It ran beside the model job, which was writing task statements and used
no task container of this job's.

The brief also listed ex338's 26 Redis candidates
([the maker's job](../2026-11-12_pilot_tasks_ex338_redis/README.md)). They were **not run: left for later on the
owner's word** (10:52 the same day). Newer code bases come first, and these 26 are on Elixir 1.13 to 1.16. None of
them was made, imported or checked.

**Result: of radiator's six, 3 checked (#603, #523, #525) and 3 dropped.**
- #599 and #601 were dropped at the controls by a test the project marks as skipped. The probe keeps that test among
  the hidden tests, and the grader does not pass a skipped test. This is the factory's gap (below).
- #521 was dropped by the probe, `no_existing_tests`. This is the pull request's own: the task has three existing
  test files, all changed by the pull request, and each fails in its starting-commit version on the merge commit, so
  no existing-tests command is left.

All six verdicts are settled: the highest 1-minute load during any check was 1.81 on 28 threads, against the job's
limit of 12. No stop rule fired.

Times are the data-mining machine's clock (UTC+1).

## The six

| Pull request | Elixir/OTP | Merged | Verdict | Dropped at | Reason | Cause | Check (s) | Prepare / probe / controls (s) | Highest load | Disk used (bytes) | The 7-GPU machine's mass run; its retry |
|---|---|---|---|---|---|---|---|---|---|---|---|
| #599 | 1.17.2/27.0.1 | 2024-12-17 | dropped | controls | `reference_existing_tests_fail` | the factory's: a skipped hidden test | 191 | 99.3 / 55.3 / 32.4 | 1.29 | 1,657,229,312 | controls, same reason; probe, `start_run_did_not_finish` (load) |
| #601 | 1.17.2/27.0.1 | 2024-12-29 | dropped | controls | `reference_existing_tests_fail` | the factory's: a skipped hidden test | 501 | 55.9 / 316.7 / 116.9 | 1.21 | 289,964,032 | controls, same reason; prepare, `environment` (load) |
| #603 | 1.17.2/27.0.1 | 2025-01-05 | **checked** | - | - | - | 731 | 19.7 / 238.2 / 470.0 | 0.57 | 544,260,096 | controls, `reference_existing_tests_fail`; probe, `reference_run_did_not_finish` (load) |
| #521 | 1.16.2/26.0.2 | 2024-04-14 | dropped | probe | `no_existing_tests` | the pull request's own | 120 | 85.9 / 23.2 / - | 1.81 | 1,400,745,984 | probe, `no_existing_tests`; probe, `start_run_did_not_finish` (load) |
| #523 | 1.16.2/26.0.2 | 2024-04-25 | **checked** | - | - | - | 210 | 47.5 / 99.0 / 54.8 | 1.68 | 264,413,184 | probe, `no_existing_tests`; probe, `start_run_did_not_finish` (load) |
| #525 | 1.16.2/26.0.2 | 2024-05-26 | **checked** | - | - | - | 110 | 18.3 / 28.7 / 57.2 | 1.76 | 211,984,384 | probe, `no_existing_tests`; probe, `start_run_did_not_finish` (load) |

- Every pull request used the task folder the retry had made on the 7-GPU machine, imported as it was. The import
  took each one, so none was made again.
- Postgres is `postgres:18.6-alpine` for all six. Its first set-up answered within the engine's 60-s wait every time:
  no check was dropped at prepare.
- The controls column holds the controls with their second round. "Disk used" is the change in free bytes on the
  machine's disk over the try: images, build cache and data, the model job's writes beside it included.
- The earlier columns come from the retry's [`tasks.tsv`](../2026-11-12_pilot_tasks_retry/tasks.tsv). The mass run
  ran an earlier probe, before `settle/4` left out files with a skipped test. Why #523 and #525 pass the probe now
  was not looked into.

**Counts per cause, of the 32 in the brief:**

| Cause | Pull requests |
|---|---|
| checked | 3 (#603, #523, #525) |
| the pull request's own | 1 (#521) |
| the factory's | 2 (#599, #601: the skipped hidden test) |
| the machine's | 0 |
| not run: left for later on the owner's word | 26 (ex338 #1079 to #1271) |

The machine-readable versions are [`counts.tsv`](counts.tsv), by verdict, step and reason, and
[`tasks.tsv`](tasks.tsv).

## The factory's gap: a hidden test the project marks as skipped

What the project holds: `test/radiator/outline/node_repository_test.exs` tags one test `@tag :skip`, the test
"with invalid data returns error changeset" in `describe "create_node/1"`. The tag is on line 38 at #599's starting
commit and on line 45 at #599's merge commit and at both of #601's commits. ExUnit's full name is
`Elixir.Radiator.Outline.NodeRepositoryTest::test create_node/1 with invalid data returns error changeset`.

What the probe keeps:
- Both pull requests change that file, so the maker puts it in the hidden test command (`grading.acceptance`).
- The probe's `settle/4` leaves the file out of the existing-tests command (`skipped_on_unchanged`), the fix made
  after the mass run.
- `Eab.BundleProbe.observe/2` keeps the file among the hidden tests. Its refusal for the reference run takes only
  states other than `passed`, `excluded` and `skipped` (`state not in ~w(passed excluded skipped)`). The file holds
  18 required tests and none of the starting failures: #599's one starting failure is in `podcast_test.exs`, and
  #601's 47 are in other files.

What the grader counts: `Eab.Grader` passes a run only when every test passed, or was excluded by a tag the task
permits. These tasks permit none (`permitted_exclusion_tags: []`). With the reference patch the hidden tests give
158 passed and 1 skipped for #599, and 151 passed and 1 skipped for #601, so neither run passes.

The verdict the factory gives: `Eab.Factory.first_failure/2` reports the first failing part of the reference control.
`submission.passed` is false for the same reason, so the answer is `reference_existing_tests_fail`. Yet the existing
tests passed on the reference: 7 of 7 for #599. The reason names the wrong part. The engine's own detail is "Fixture
qualification failed for radiator-pr-599; see its saved control evidence". The controls ran in full before the drop:
32.4 s for #599 and 116.9 s for #601.

Which of the six it hits: #599 and #601. #603, #523 and #525 do not run that file among their hidden tests. #521
does: the file is new in #521, and at its merge commit the test carries no tag. #603 has the file only in its existing tests, which `settle/4`
already leaves out, and it was checked.

The smallest change that settles it: one word in `observe/2`. Drop `skipped` from the states it lets through
(`state not in ~w(passed excluded)`). The probe would then refuse such a task as `reference_fails_hidden`, naming
the skipped test, before any control runs. The task is lost, but its verdict says why. A change that keeps both
tasks would do for hidden files what `settle/4` does for existing ones:
- leave a hidden test file out of the hidden command when the reference skips one of its tests and the file holds no
  starting failure;
- this loses the file's 18 passing tests as protection, since a skipped test fails the existing-tests command as well.

Neither change is made in this job.

## Time and bytes

- **Wall time** of the six, from each try's start to its end: 191, 502, 733, 122, 212 and 112 s, in all 1,872 s.
  Per checked task that is 624 s (est.: the six's time over the three checked). The three checked ones took 733,
  212 and 112 s each. Import took 0 or 1 s each, and export 1, 0 and 0 s.
- **Disk:**
  - Free bytes on the machine's disk: 846,603,390,976 before the controller started (10:22:50), 842,204,360,704 after
    it stopped (10:55:58). The difference is 4,399,030,272 bytes, the model job's writes included.
  - The six tries' own changes add up to 4,368,596,992 bytes. Per checked task that is 1,456,198,997 bytes (est.:
    the six's bytes over the three checked).
  - The three checked tasks' own tries used 544,260,096, 264,413,184 and 211,984,384 bytes. Their folders hold
    52,351 bytes (#603) and 143,093 bytes for all three.
- **Build cache** (Docker's API): 45,603,394,463 bytes in 968 entries before, 47,829,750,613 bytes in 1,067 entries
  after, a change of 2,226,356,150 bytes.
- **Images:** [`images.tsv`](images.tsv) names the 17 the job added, by id, name and bytes.
  - The engine built 15, all labelled with this job's label: per pull request a project image (the same id as its
    `seed-` tag, 964,211,854 to 985,646,964 bytes) and a Postgres snapshot (489,288,964 to 489,653,579 bytes).
  - For #599 and #521, the first of each Elixir/OTP pair, it also built a toolchain image (902,033,372 and
    898,184,747 bytes).
  - For #599 it built a layout image (432,794,061 bytes), the same tag as the set-up's with a new id because of the
    labels.
  - It pulled 2 Elixir base images by digest: 1.17.2/27.0.1 (254,182,376 bytes) and 1.16.2/26.0.2 (250,332,095).
  - Docker's sizes add up to 11,524,385,403 bytes, more than the disk used, because images share layers.

## How it ran

- **The controller:** `elixir-task-factory:hb-20261112`, built on this machine from the factory at `2b53afa`. The
  factory's code at `main` (`e449252`) differs from it only in `README.md`, compared file by file.
- **Kept apart from the controller of the model job and from the bench:**
  - its own container `factory-hb3`, node `factory_hb3@127.0.0.1` and Erlang port mapper on 127.0.0.1:4511;
  - its own data folder and task folder;
  - the labels `task-factory=1` and `task-factory-job=hb3` on the controller and on everything the engine started or
    built;
  - `--cpu-shares 256` and the Hex cache id `etf-hex-packages-v1`;
  - one preparation worker and a look-ahead of one.
- **One check at a time:** `check --concurrency 1` with one id, and the next pull request only after the previous
  one's export.
- **The watcher** (`watch.sh`) sampled every 10 s and applied the job's stop rules: free bytes under 700,000,000,000,
  the 1-minute load above 20 in two readings 300 s apart, and a bench run (a container of the bench's images or
  names). None fired. The model job had a container up in 156 of the 189 samples.
- **ex338's 26:** the owner's decision came while #521 was being checked. The 26 ex338 ids went into the job's
  `hold.txt`, and `one.sh`, which starts anew for each pull request, was given the check that ends with exit code 3
  for a held id before any step. The driver then passed over all 26 in 8 s.

Things that went wrong in the run, and what was done:
- **The driver's first start, 10:23:29:** `all.sh` named the watcher's sample file after it had given `OUT` a new
  value, so `one.sh` stopped with an error after #599's check, at the line that reads the samples, and wrote no row.
  The driver was stopped while #601 was being checked. #601's check and its `one.sh` ran to their end.
- **The fix:** a try's row moved to `row.sh`, which writes it from the try's files alone, and both rows were written
  from those files. The driver started again at 10:35:42 and went on with #603.
- **The watcher:** the first start's watcher sampled to 10:35:05 and the second start's from 10:35:42, so every check
  had samples throughout.
- **Wrong try numbers in the log:** the second start's driver printed "try 2" in its end lines for first tries,
  because `rows()` changed its caller's variable. The rows record try 1. The `all.sh` here has the fix; the running
  driver kept its loaded copy.
- **`table.sh`** was corrected twice (a `printf` format that starts with `-`, and the disk column) before its
  tables were written.

## Files

| File | What |
|---|---|
| [`tasks.tsv`](tasks.tsv) | One line per try, and one per pull request not run. Columns: the folder's origin, verdict, step, reason; seconds of make, import, check and export; the engine's step times; the load at start and end and the highest during the check; settled or not; the images' bytes; the build cache's change; the disk used; start and end |
| [`counts.tsv`](counts.tsv) | Pull requests per verdict, step and reason, by their last try |
| [`images.tsv`](images.tsv) | Every image the job added: the try, id, names and bytes |
| [`numbers.tsv`](numbers.tsv) | The brief's 32 pull requests in order: radiator's six, then ex338's 26 |
| `run/controller.sh` | Starts, stops and calls the controller (several labels; the preparation limits as settings) |
| `run/all.sh` | The driver: `stage` (the lists' templates, tables, Git caches and the copied task folders), `run` (one pull request at a time, then a second try for each one not settled) |
| `run/one.sh` | One pull request: the copied folder imported, or the folder made again with `make_one.exs` and imported; `check`; `export` of a checked task; the snapshots around it |
| `run/make_one.exs` | The bundle maker, the source check and the import check for one pull request, inside the controller |
| `run/row.sh` | A try's result line, from its folder's files |
| `run/watch.sh` | The samples and the stop rules |
| `run/state.sh` | A snapshot of the machine's Docker and load |
| `run/table.sh` | The three tables |

## Exact commands

On the data-mining machine, as root, with `WORK` the factory's work folder and `J=$WORK/jobs/hb3`. The scripts of
`run/` and `numbers.tsv` are copied there first, and the census and screen tables of both projects go into
`$J/tables/`.

```bash
cd $J
run/state.sh > out/state_0_before.txt
CTL=$WORK/ctl-hb3 NAME=factory-hb3 SOURCES=$J IMAGE=elixir-task-factory:hb-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb3 EPMD_PORT=4511 PREPARE_WORKERS=1 PREPARE_AHEAD=1 run/controller.sh up
WORK=$WORK JOB=$J CTL=$WORK/ctl-hb3 NAME=factory-hb3 \
  CACHE_radiator=$WORK/ctl-retry/data/retry-radiator/cache CACHE_ex338=$WORK/ctl-redis-ex338/data/all/cache \
  COPY_radiator=$WORK/ctl-retry/data/retry-radiator/tasks \
  COPY_ex338="$WORK/ctl-redis-ex338/data/proofs/tasks $WORK/ctl-redis-ex338/data/proofs2/tasks" run/all.sh stage
WORK=$WORK JOB=$J CTL=$WORK/ctl-hb3 NAME=factory-hb3 JOB_LABEL=task-factory-job=hb3 TASK_LABEL=task-factory=1 \
  setsid nohup run/all.sh run >> out/run.log 2>&1 < /dev/null &
# the 26 ex338 ids, one per line, into out/hold.txt (the owner's decision)
export OUT=$J/out NUMBERS=$J/numbers.tsv HELD_REASON="left for later on the owner's word"
run/table.sh tasks > out/tasks.tsv; run/table.sh counts > out/counts.tsv; run/table.sh images > out/images.tsv
CTL=$WORK/ctl-hb3 NAME=factory-hb3 run/controller.sh stop
run/state.sh > out/state_9_end.txt
```

A row written again from a try's files, as for #599 and #601:

```bash
OUT=$J/out/radiator-pr-599/1 WATCH=$J/out/watch.tsv REPOSITORY=https://github.com/podlove/radiator NUMBER=599 \
  ID=radiator-pr-599 run/row.sh
```

## Provenance and licence

The pull requests and their code are podlove/radiator's (MIT, as the tasks' `licence` field reads it). The tables
hold their numbers, the versions read from their files, test names, and the ids and names of the images the engine
built from them.
