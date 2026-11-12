# A second try of the mass run's drops, through a controller built from today's code (2026-11-12)

Registry row [E68](../../../experiments.md). The mass run of [2026-11-12_pilot_tasks_all](../2026-11-12_pilot_tasks_all/README.md)
dropped 14 pull requests for reasons that were the factory's or the machine's rather than the pull request's. This
run tried them again with a controller built from public `main` at `8b8bb99` (`elixir-task-factory:retry`), and it
is the first real list that went through the factory's own entry points (`import`, `check`, `export` through
`bin/factoryctl`, [section 9](../../../factory/README.md)) instead of the hand-driven gate script. Everything ran on
the CPU of the 7-GPU machine on 2026-11-12 between 07:56 and 08:24 (UTC+1), three pull requests at once, while three
other jobs used the same Docker daemon and disk (load average 8.59 at 08:02, 11.31 at 08:07, 12.70 at 08:09 and 17.87
at 08:23); the diagnostic runs, the reproduction and
the tests followed between 08:37 and 09:03, while a copy of 258 GB was being written to the same disk.

## Result

**14 listed, 11 tried through `check`, 1 checked (ex338 #1331), 3 refused by the maker (OTP 27.2).**

| Cause in the mass run | Pull requests | Tried | Checked now | Still dropped, and why |
|---|---|---:|---:|---|
| the probe kept a test file with a skipped test (fixed in `main` since) | radiator #599, #601, #603 | 3 | 0 | none reached the controls this time, all three for the disk's load: #599 and #603 at the probe (the test command could not get a Postgres connection within 2 s), #601 at the preparation (the same time-out in `mix ecto.migrate`) |
| "Workspace command failed" with no output (radiator 1.18.3/27.3) | radiator #611, #613, #615 | 3 | 0 | **explained and reproduced** (below): the workspace's `git add -A` hit its 120-second limit in the first control of #611 and #615; #613 is now dropped by the probe for its own reason (its only existing test file has a skipped test) |
| possibly the load | radiator #521, #523, #525, ex338 #1331 | 4 | **1** | #1331 checked; #521, #523, #525 at the probe, for the disk's load: the test command could not get a Postgres connection within 2 s, on both sides |
| OTP 27.2 cannot install Hex | radiator #605, #606, #607, #609 | 1 | 0 | the next patch release, OTP 27.2.1, fails the same way (#607); the four stay refused, and #605, #606, #609 were refused by the maker (`no_image`) |

`tasks.tsv` has two lines per pull request, the mass run's line and this run's, in the columns of the mass run's
task tables; `changes.tsv` says in one line per pull request what changed.

### The unexplained failure: `git add -A` killed by its time limit

The engine's grader (`Eab.Grader`, README section 2.2, kept as the bench has it) starts each grade in a fresh
workspace container with `git add -A`, run through `Eab.Sandbox.command!/3` with its default limit of 120 seconds
(`timeout -k 5 120 bash -lc 'git add -A'`). In the first control of #611 (the unchanged project) that command ran
120.1 s and ended with exit code 124, `timeout`'s own; `git add -A` prints nothing, so the error was
"Workspace command failed: " with an empty output. #615 the same, 120.6 s, exit 124. Docker's event record
(`run/events.sh`) shows every command and its exit code; nothing else failed in those grades.

What git was doing, read inside #615's container 30 s into the command (`ps`, `/proc`, as the workspace's user):
it was in uninterruptible disk sleep (state `D`), its kernel wait channel `jbd2_log_wait_commit` (waiting for the
file system's journal to commit), at 2.5 % of a CPU, with `.git/index.lock` and one file of
`assets/vendor/phosphor/` (a vendored icon set) open, and about 76 waits per second. The radiator commits of the
1.18.3/27.3 period track 9,302 files, most of them those icons. The same command is slow in other workspaces too,
but under the limit: ex338 #1331's six grades ran `git add -A` in 35.7, 15.0, 50.8, 2.5, 2.1 and 12.9 s.

**Reproduced outside the engine** (`run/repro.sh`, three fresh containers from #615's own workspace image with the
workspace container's limits, one after another; load average 10.74, 9.74, 10.64 and 10.20 at their starts and end):
1. all 9,307 tracked files differ from git's index in their stat data: the index holds inode 29528129 and an older
   change time for `assets/vendor/phosphor/fill/behance-logo-fill.svg`, the container shows inode 30164765
   (`git diff-files` lists all 9,307); the repository's 9,371 objects are all loose, none packed;
2. `git add -A` alone: stopped by the reproduction's own limit of 240 s (exit 124, 243.0 s);
3. `git update-index -q --refresh` first: 0.2 s, and then `git add -A`: 0.0 s, exit 0.

So the mechanism: in a fresh container every tracked file's inode differs from the one in the index, `git add -A`
therefore adds every file again, and since each object already exists git refreshes its time stamp; that write to a
file of the image's layer makes Docker's overlay file system copy it up and wait for the disk, 9,371 times. On a
disk other jobs keep busy that crosses 120 s. Refreshing the index's stat data first reads the files but writes no
object, and the add after it has nothing to do. The fix cannot be in the grader or the workspace recipe (README
section 2); two places outside it would do: the task's `runtime.before_test_commands` with
`git update-index -q --refresh`, or the maker refusing workspaces above a number of tracked files. Neither is done
here (registry row E78). The same `git add -A` runs, with a limit of 60 s, after every tool call of a teacher's
session (`Eab.Sandbox.patch/1`), so these workspaces would break sessions too.

### The other drops

- **#599, #521, #523, #525** (and **#603** on the reference): the probe's hidden-test command exited with code 1
  (an error of `mix` itself, not test failures, which exit 2) after 6.9, 5.6, 5.6 and 7.8 s; in the mass run the
  same tasks' runs finished. `check` keeps no output of these runs (below), so after the check the gate's two
  diagnostic runs were made again for them, one task at a time, with their output (`run/diag.exs`). For #599,
  #521 and #523, on the unchanged project and on the reference alike, the run stops before any test, in the test
  alias's `mix ecto.create`: "The database for Radiator.Repo couldn't be created: connection not available and
  request was dropped from queue after 2000ms" (#599's reference: a `DBConnection.ConnectionError`), while the
  Postgres beside it had logged "ready to accept connections". The disk was the bottleneck: the host's I/O pressure
  (`/proc/pressure/io`, the share of time every running task waited on I/O) was 78.98 % over five minutes at
  08:50 and 85.12 % at 08:53, with 7, 7, 6 and 8 processes blocked in four samples at 08:50, the last three with
  25 % of the CPU time in I/O wait. So these are drops of the load, and these pull requests themselves were not
  tested; they need a third try on a quiet disk. #525's diagnostic run stopped when Docker itself stalled on
  removing a container ("removal of container … is already in progress"), and #603's was not reached.
- **#601**: the preparation's `mix ecto.migrate --quiet` failed on the same Postgres time-out (its wording:
  "dropped from queue after 2999ms"), after 3.5 s.
- **#613**: the probe now leaves out `test/radiator_web/live/outline_live_test.exs` as `skipped_on_unchanged` (the
  mass run's fix of `settle/4`), and that was its only existing test file, so `no_existing_tests`. The fix also
  left that file out of #611's command. These are the fix's first effects on real tasks.
- **#607 with OTP 27.2.1**: the image `hexpm/elixir:1.18.2-erlang-27.2.1-ubuntu-noble-20260509.1` installs its
  packages, then `mix local.hex 2.5.3 --force` fails with the same TLS alert as 27.2's: `unsupported_certificate`,
  `key_usage_mismatch`, from builds.hex.pm. The image table's note says so now; no pair of OTP 27.2 is added.
- **#1331**: checked (3 hidden tests fail first and pass after, partial fix present, second round the same), 361.9 s.

## What the entry points did differently from the hand-driven script

The mass run's `gate.exs` called the engine's functions one by one; `bin/factoryctl check` runs the same sequence as
one job (`Eab.Factory.check/2`). What differed in this run:

1. **No diagnostic runs.** The gate ran the hidden tests on the unchanged project and on the reference before the
   probe and saved both outputs (`diag_start.txt`, `diag_reference.txt`); `check` does not, so a probe drop
   (`start_run_did_not_finish`, `reference_run_did_not_finish`) comes with no output at all, and the columns
   `start_counts` and `reference_counts` are filled only when the controls ran.
2. **No output of any run is kept.** A drop's `detail` is the exception's message only; for the time-out above it
   is "Workspace command failed: ". The gate saved the controls' evidence beside each row; `check` leaves it in the
   data folder's `controls/<id>.json` only when the controls got as far as saving it.
3. **The detail was cut after its first 2,000 characters.** For a failed toolchain build that keeps the build's
   start and loses the error at its end (#607's 54 kB log). Fixed: a long detail keeps its first 300 and last
   1,700 characters.
4. **No time for the probe, the controls, or a step that failed.** Fixed: `probe_ms`, `controls_ms`, and
   `<step>_ms` for the failing step too. In this run's table the probe and control times come from the job's
   `progress.log`, to the second (`run/table.sh`).
5. **Other step names.** A failure inside the controls before they save their evidence is `controls`/`error`; the
   gate called it `gate_prepare`/`environment`. The gate's second preparation is `prepare_after_probe`.
6. **The task folder.** `import` copies the made folders into the controller's task folder (a mount; the made
   folders must be inside the controller's own mounts, here `/data/<list>/tasks`); `check` replaces a checked
   task's folder by its probed copy and leaves a dropped one as imported, with the probed copy in
   `factory/jobs/<job>/work/<id>/`; `export` copies the checked folders with `results.tsv`. A dropped task's result
   reads its fields (partial fix, command files, failing-first count) from that copy's manifest, so for a task
   dropped before the probe rewrote it they are the maker's.
7. **The second round** runs inside the controls (`Eab.Grader.qualify/3`), so there is no separate time for it.
8. **The maker has no entry point**: the folders were made with the proofs' `make.exs` through the release's `rpc`,
   as before. `factoryctl` itself worked as section 9 says, the VM's warning lines filtered out.

## The fix in `factory/`

`lib/eab/factory.ex`: a result holds the time of every step, the probe (`probe_ms`), the controls with their second
round (`controls_ms`) and a step that failed included; a long `detail` keeps its first 300 and last 1,700 characters.
One new test in `test/eab/factory_test.exs`. `config/toolchain_images.json`: the note says OTP 27.2.1 fails too,
with its comment in `toolchain_test.exs`. No file of README section 2 changed; the parity test is untouched.

**Tests** (the tooling image `eab-tooling:dev`, as the trimming jobs ran them): the format check passes; without
Docker 232 passed, 0 failed, 10 excluded (the mass run's count on `main` that morning: 231, 0, 10; the one more is
the new test); after the last edit (one blank line the format check asked for) the three touched files again, 31 of
31 (`toolchain_test`, `factory_test`, `bench_parity_test`). **The tests with Docker gave no verdict:** they ran from
08:38 to 09:03 on the choked disk, 131 of the 133 tests that ran passed, and the run broke off before the rest of
the suite's 242; the two failures (`bundle_probe_docker_test`, `build_seed_docker_test`) are the engine's own
"Command watchdog expired", in files this change does not touch, and `factory_docker_test` was not reached. They
need a run on a quiet disk.

## The order of the work, and the disk floor

The job's brief set a floor of 572,835,543,040 free bytes on `/`. Free space fell under it during the check
(553,171,542,016 at its end), with this run's own folders at 413 MB, so the run stopped there and the controller was
taken down. The floor had in fact been lowered on the owner's word while the check ran, to 134,454,282,076 bytes with
a disk allowance of 280 GB, because the owner was copying 258 GB onto the same disk; this run learnt of it at 08:37
and then made the diagnostic runs, the reproduction and the tests with Docker, on a restarted controller. At 09:03:15
the controller was stopped from outside this run (`SIGTERM`, as another job's controller at the same time), and the
Docker tests ended in the same second. `run/catch.sh` ran during the check; it fired on another job's containers, so
#615's git was read by hand with the same commands.

## Files

| File | What it holds |
|---|---|
| `tasks.tsv` | two lines per pull request (`run`: `mass_run`, `retry`), in the columns of the mass run's task tables; the retry's columns are explained in `run/table.sh` |
| `changes.tsv` | one line per pull request: the cause group, the verdict of each run, what changed |
| `git_add.tsv` | every `git add -A` of this run's workspaces: task, start, seconds, exit code |
| `run/` | `retry.sh` (stage, make, import, check, export), `events.sh` and `events_table.sh` (Docker's event record and its tables), `catch.sh` (what a running `git add -A` waits on), `diag.exs` (the gate's two diagnostic runs, with their output, through the controller), `repro.sh` (the `git add -A` reproduction), `table.sh` and `side_by_side.sh` (the tables) |

The checked task folder is kept on the build machine, not published.

## Exact commands

On the build machine, with the factory at `8b8bb99` in `JOB/src`, this folder's `run/` and the proofs' `make.exs` in
`JOB/run`, the T10 job's [`controller.sh`](../2026-11-12_factory_t10/run/controller.sh), the census and screen tables
in `JOB/tables`, and a new data folder `CTL`:

```sh
SRC=$JOB/src IMAGE=elixir-task-factory:retry run/controller.sh build
OUT=$JOB/out setsid nohup run/events.sh &
IMAGE=elixir-task-factory:retry NAME=factory-retry EPMD_PORT=4530 DATA=$CTL/data TASKS=$CTL/tasks MIRROR=$CTL/mirror \
  run/controller.sh up
export FACTORY=$JOB/src RUN=$JOB/run DATA=$CTL/data NAME=factory-retry OUT=$JOB/out HOLDOUT=$JOB/src/config/holdout.json
# per list: SUB, REPOSITORY, RECIPE, CENSUS, SCREEN, TABLE and NUMBERS (radiator 599 601 603 611 613 615 521 523 525;
# ex338 1331; radiator 607 with the table plus the two 27.2.1 lines; radiator 605 606 609 with the table as it is)
run/retry.sh stage; run/retry.sh make; run/retry.sh import
NAME=factory-retry $FACTORY/bin/factoryctl check --concurrency 3 radiator-pr-607 radiator-pr-611 radiator-pr-613 \
  radiator-pr-615 ex338-pr-1331 radiator-pr-599 radiator-pr-601 radiator-pr-603 radiator-pr-521 radiator-pr-523 radiator-pr-525
NAME=factory-retry $FACTORY/bin/factoryctl export /data/export/retry ex338-pr-1331
run/table.sh $CTL/data <job> otp-radiator retry-ex338 retry-radiator refused-radiator > tasks_retry.tsv
run/side_by_side.sh order.txt tasks_retry.tsv tasks_radiator.tsv tasks_ex338.tsv > tasks.tsv
# after the check, with the controller up again on the same data folder: the diagnostic runs, through the release's rpc
#   System.put_env(%{"DIAG_JOB" => "<job>", "DIAG_IDS" => "radiator-pr-599 radiator-pr-521 radiator-pr-523
#   radiator-pr-525 radiator-pr-603", "DIAG_OUT" => "/data/diag"}); spawn(fn -> Code.eval_file("/data/diag.exs") end)
IMAGE=<#615's workspace image> OUT=$JOB/out FILE=assets/vendor/phosphor/fill/behance-logo-fill.svg LIMIT=240 run/repro.sh
```

The OTP 27.2.1 lines were looked up with `factory/scripts/toolchain_image.sh elixir 1.18.1 27.2.1` and `1.18.2 27.2.1`.

## Disk and images

- Free on `/`: 602,591,866,880 bytes at 07:56:24, 601,918,324,736 at the check's start (07:59:59), 594,012,368,896
  at 08:09:21 and 553,171,542,016 at its end (08:23:42), with the three other jobs writing at the same time; this
  run's own folders hold 413 MB. Later, with the owner's copy on the disk: 517,440,307,200 at 08:37:40,
  482,335,428,608 at 08:53:10 and 453,843,324,928 at 09:05:38.
- Built: `elixir-task-factory:retry` (191,523,808 bytes as `docker image inspect` reports it). Pulled:
  `hexpm/elixir:1.18.2-erlang-27.2.1-ubuntu-noble-20260509.1` (80,493,146 bytes). The engine built a toolchain,
  workspace and database image per period and commit as in the mass run, most from the build cache.

## Provenance and licence

The pull requests and their code are podlove/radiator's and axelclark/ex338's (MIT, as the tasks' `licence` field
reads it); the tables hold their numbers, the versions read from their files and test file names.
