# The teacher's first sessions: DeepSeek solves the ex338 cases (E9, E81)

The teacher model, DeepSeek-V4.1-Flash-1017 (Unsloth's `UD-IQ1_M`, as in
[the statements job](../2026-11-12_statements_first_20/README.md)), served by Strata on the 7-GPU machine, solved the
checked cases of `axelclark/ex338` through the task factory: Pi 1.2.0 with its four tools, the bench's instruction
text and the engine's own limits, one attempt per case, one case at a time, the project containers on the
data-mining machine. This is the first run of the teacher on training cases (E9), and the first measure of where a
session's time goes (E81).

**Result: 13 of 15 cases give a kept session.** 15 of the 16 cases were attempted; the 16th was left out before the
run because its check fails on this machine (below). 16 sessions ran: one case ran twice, because its first session
failed for the machine's own reason (a database time-out during grading) and, by the dataset's rules, does not count
as an attempt. All 6 bug fixes were kept, and 7 of the 9 features. **The job took 13,856 s by the wall clock**, from
the first session's start to the last one's end: **3.38 kept sessions per hour**, 1,066 s per kept session.

**Where the time goes:** of the 16 sessions' 13,331.3 s, the model **generated for 7,526.7 s (56.5 %)** and **read
prompts for 5,204.5 s (39.0 %)**, both by the server's own timings; the rest of the model's wait (network, the
engine's token count, streaming) was 82.5 s (0.6 %), and **the tools and tests on the data-mining machine took 517.3 s
(3.9 %)**. Of the 16 runs' 13,851 s, the sessions were 96.2 %, grading 3.4 % (464.8 s) and the run's preparation 0.4 %
(54.8 s). **The server keeps the conversation:** of the 41,196,099 prompt tokens of the 586 model calls, it reused
40,345,528 (97.9 %) from the call before and read 850,571 new ones (2.1 %); no call after a session's first was read
in full. It read the new parts at 163.4 tok/s and generated at 49.7 tok/s overall.

## Which cases

The 16 checked cases of `tasks/axelclark__ex338.r2` ([P5 r2](../2026-11-12_pilot_tasks_ex338_r2/README.md)), built on
Elixir 1.18.3, each with a description written by the teacher and passed by the leak check
([statements](../2026-11-12_statements_first_20/README.md)): 6 bug fixes and 10 features by the maker's `task_kind`,
taken newest merged first ([`run/tasks.txt`](run/tasks.txt)). The controller's import accepted all 16 and its
inventory lists each with `ticket.md` and a `statement.json` whose SHA-256 matches ([`inventory.tsv`](inventory.tsv)).

**Checked again here first.** The controller is new, so it held no saved controls. The factory's preparation with no
model (`Eab.Runs.prepare/1`: the workspace images, the database, and the grader's controls with their second round)
ran on the 16, one at a time, in 1,360 s ([`checks.tsv`](checks.tsv)). 14 passed. Two did not, both on the same
existing test of the project, `Ex338.FantasyTeamTest` "owned_players/1 returns all active players on a team for select
option", which only these two cases run:
- `ex338-pr-1460`: in the second round the test failed with the reference change after passing in the first. Checked
  once more (91 s for the two), it passed, and it was attempted.
- `ex338-pr-1398`: with the reference change the test failed in its body both times. **Left out of this run**: a case
  whose fix does not pass here cannot grade a session fairly. The test passed in the case's making on the 7-GPU
  machine, so it is unstable, not wrong; leaving its file out of the case's existing tests is a case-making change,
  not done here.

## The method

- **The controller:** `elixir-task-factory:run-20261112`, built on the data-mining machine from this repository's
  `factory/` at `02adabd`, with the set-up's switches (its own data folder, node name, port mapper and Hex cache id;
  [set-up](../2026-11-12_factory_data_mining_machine/README.md)); one preparation at a time and one task ahead
  (`EAB_PREPARE_AHEAD=1`, `EAB_PREPARE_WORKERS=1`); every container with the label `task-factory=1` and a CPU share of
  256. The parity test (`test/eab/bench_parity_test.exs`) passes in the tooling image built from the same source: 6 of
  6. So what the model sees is the bench's.
- **One factory run per case** ([`run/drive.sh`](run/drive.sh)): `start_run` on that one case with no settings, so the
  engine's defaults hold: 65,536 generated tokens in all, a 262,144-token window, 8,192 per answer, seed 101, no
  compaction; the thinking effort is the server's own preset ("high" in its set-up; the engine records it as not
  reported, since the server's `/props` does not show it). The next run starts only when the last has ended, so no
  preparation and no other attempt of this job ran beside a session. The model was asked nothing else meanwhile.
- **The server's own timings:** Strata's streamed answers carry no timings, so the engine records none. Strata's
  status page (`GET /metrics`) lists its last 12 requests with their prompt tokens, the part reused from before, and
  the milliseconds of reading and of generation. [`run/metrics_log.py`](run/metrics_log.py) read it every 10 s and kept
  each request once. Each of the 586 model calls was matched to its record by order, time and equal token counts
  (prompt and generated): 586 of 586 matched, and no other request reached the server during the sessions.
- **The session's time** is the run's phase "running" (Pi working) up to "grading", from the run's own events; the
  model's wait per call runs from the engine's request file to its answer file (file times, to the second, so the
  "other model" time of a session can come out slightly below zero). Tools and the rest = the session minus the
  model's wait.
- **Stop rules** read every 20 s: a bench run on the same Docker; free space on `/` under 50,000,000,000 bytes (700 GB
  until the owner lowered it during the run); the server busy with another request for 10 minutes; three model errors
  or three sessions without a tool call in a row. None fired.
- **Sorting the failed sessions** follows `docs/dataset_rules.md` section 6: the machine's fault, a gap in the
  description, or the teacher's own.

## The sessions

Times in seconds; tokens as the engine counted them, equal to the server's. "Read" is the new prompt tokens the
server read; "reused" the rest. Every call after the first of a session reused the conversation before it.

| Case | Kind | Description bytes | Ended | Patch | Kept | Session s | Turns | Tool calls | Prompt tokens | Read | Generated | Reading s | Generating s | Tools and rest s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `ex338-pr-1463` | bug fix | 507 | done | passed | yes | 610.6 | 26 | 36 | 996,719 | 42,921 | 14,263 | 289.4 | 305.3 | 10.6 |
| `ex338-pr-1461` | bug fix | 553 | done | passed | yes | 248.6 | 12 | 16 | 205,125 | 17,679 | 5,824 | 116.0 | 103.3 | 28.6 |
| `ex338-pr-1460` | feature | 4,069 | done | passed | yes | 1,133.5 | 50 | 60 | 3,483,025 | 69,265 | 35,671 | 408.8 | 680.2 | 39.5 |
| `ex338-pr-1458` | feature | 2,598 | done | passed | yes | 514.3 | 19 | 23 | 779,922 | 49,969 | 11,170 | 264.6 | 228.9 | 17.3 |
| `ex338-pr-1457` | feature | 1,347 | done | passed | yes | 703.1 | 41 | 44 | 1,681,882 | 44,871 | 17,910 | 293.4 | 362.8 | 43.1 |
| `ex338-pr-1452` | bug fix | 743 | done | passed | yes | 850.8 | 31 | 48 | 1,955,819 | 75,219 | 23,846 | 399.5 | 426.8 | 17.8 |
| `ex338-pr-1451` | feature | 6,237 | token budget | step 2 | no | 2,023.4 | 82 | 97 | 8,863,376 | 98,801 | 65,536 | 676.7 | 1,272.3 | 57.4 |
| `ex338-pr-1450` | bug fix | 323 | done | passed | yes | 336.8 | 20 | 24 | 372,866 | 18,921 | 7,922 | 153.8 | 161.1 | 19.8 |
| `ex338-pr-1446` | feature | 2,831 | done | step 2 | no | 2,095.2 | 98 | 111 | 11,400,330 | 117,496 | 58,717 | 675.2 | 1,310.6 | 88.2 |
| `ex338-pr-1411` | bug fix | 340 | done | passed | yes | 196.3 | 13 | 17 | 167,401 | 16,079 | 3,126 | 123.5 | 60.5 | 10.3 |
| `ex338-pr-1395` | bug fix | 613 | done | passed | yes | 251.0 | 14 | 17 | 246,968 | 18,732 | 6,740 | 120.5 | 117.8 | 13.0 |
| `ex338-pr-1394`, first | feature | 1,855 | done | step 2 (machine) | no | 679.2 | 24 | 39 | 1,045,050 | 60,208 | 17,685 | 311.4 | 339.1 | 26.2 |
| `ex338-pr-1392` | feature | 2,421 | done | passed | yes | 390.6 | 21 | 25 | 462,020 | 24,573 | 10,963 | 181.0 | 198.0 | 12.6 |
| `ex338-pr-1390` | feature | 2,764 | done | passed | yes | 930.3 | 38 | 49 | 1,939,220 | 49,441 | 29,635 | 316.5 | 568.8 | 41.3 |
| `ex338-pr-1350` | feature | 2,063 | done | passed | yes | 1,718.0 | 65 | 87 | 6,243,815 | 99,132 | 48,389 | 582.4 | 1,065.8 | 61.0 |
| `ex338-pr-1394`, second | feature | 1,855 | done | passed | yes | 649.6 | 32 | 43 | 1,352,561 | 47,264 | 17,014 | 291.8 | 325.4 | 30.6 |
| **16 sessions** | | | | **13 passed** | **13** | **13,331.3** | **586** | **736** | **41,196,099** | **850,571** | **374,411** | **5,204.5** | **7,526.7** | **517.3** |

"Done" is the engine's `agent_completed` (Pi gave its summary); "token budget" means the 65,536 generated tokens were
used up and the patch as it stood was graded. Each kept session is listed by the factory's `kept` with a sealed
receipt. The full columns, with each run's id, its preparation and grading time and the model's wait, are in
[`sessions.tsv`](sessions.tsv); one row per model call in [`calls.tsv`](calls.tsv); the sums in
[`totals.json`](totals.json).

**By kind:** the 6 bug fixes, all kept, took 2,494.1 s of session time (116 turns, 61,721 generated tokens); the 9
features, 7 kept, took 10,837.2 s over 10 sessions (470 turns, 312,690 generated tokens). The two features not kept
are the two longest sessions (2,023.4 s and 2,095.2 s); with the machine's failed session they hold 4,797.8 s, 36.0 %
of all session time.

## Sessions not kept, by whose fault

| Session | Fault (`docs/dataset_rules.md` section 6) | What failed |
|---|---|---|
| `ex338-pr-1394`, first | `machine_fault` | step 2 never ran a test: the database migration in the grading container gave up waiting for a connection ("connection not available and request was dropped from queue after 2998ms"). The hidden tests (7 of 7) and the existing tests again (step 4) passed in the same grading. Run again as the rules say; the second session was kept. The machine's 1-minute load was 6.04 then (`load.tsv`) |
| `ex338-pr-1451` | `teacher_failure` | the 65,536 generated tokens ran out after 82 turns. 121 of 122 hidden tests pass; the one that fails, `Ex338.DraftPicks.DraftPickTest` "owner_changeset/2 error when the player doesn't exist", wants the "is invalid" error the description asks for. One of the model's own tests also fails (step 2) |
| `ex338-pr-1446` | `teacher_failure` | the league page it changed reads the logged-in user from an assign it never sets (`KeyError` for `:current_user`), so 4 of 63 hidden tests fail, and so does an existing test of that page (step 2). The description is not short of anything these tests check |

## Does each turn read the whole conversation again?

No. Within a session the server reused the previous call's prompt and its answer: in 448 of the 570 calls after a
session's first, the reused part was exactly the previous prompt plus the previous answer; in the other 122 it was
6,874 tokens less in all (1,838 at most in one call), and never under half of the previous prompt. Only each
session's first call was read whole: 27.3, 26.2, 29.4, 28.2, 27.0, 26.1, 31.6, 26.7, 28.0, 17.5, 16.4, 18.8, 19.3,
20.2 and 20.0 s for 3,814, 3,844, 4,720, 4,294, 4,019, 3,808, 5,145, 3,685, 4,335, 1,831, 1,881, 2,179, 2,322, 2,413
and 2,186 tokens, in run order.
The second session of `ex338-pr-1394` reused 2,178 of its first prompt's 2,179 tokens (0.6 s): its first session's
identical first prompt, an hour and five sessions earlier, was still held. Read whole every turn, the 41,196,099
prompt tokens would have taken about 70 hours at 163.4 tok/s (est.).

**Reading is slow for short additions.** A call adds the last tool results, usually short. The 176 calls that added
under 100 tokens took 584.1 ms each on average for 39.3 tokens (67 tok/s); the 205 that added from 100 to 999
tokens, 4,359.7 ms for 358.3 tokens (82 tok/s); the 102 that added 3,000 or more, 205.6 tok/s. So reading takes 39.0 %
of the time while it covers 2.1 % of the prompt.

**The speeds per session**, in run order: reading the new tokens 148.3, 152.4, 169.4, 188.8, 152.9, 188.3, 146.0,
123.0, 174.0, 130.2, 155.5, 193.3, 135.8, 156.2, 170.2 and 162.0 tok/s; generating 46.7, 56.4, 52.4, 48.8, 49.4, 55.9,
51.5, 49.2, 44.8, 51.7, 57.2, 52.2, 55.4, 52.1, 45.4 and 52.3 tok/s (374,411 tokens in 7,526.7 s, 49.7 tok/s; the
statements' long answers ran at 42.4). The data-mining machine ran other case-making jobs throughout; its 1-minute
load, read once a minute from 12:37 UTC (215 readings), was lowest at 3.15 (14:58) and highest at 12.23 (15:29).

## What would make it faster

- **Generation is the largest share (56.5 %).** At 10 tok/s more (59.7 against 49.7), generation would take 16.8 %
  less, about 9.5 % of the session time (est.).
- **Prompt reading is the second (39.0 %),** almost all of it the short new parts of each turn: 67 tok/s for
  additions under 100 tokens and 82 tok/s for those from 100 to 999. Twice as fast would save about 19.5 % (est.).
  Why short additions read so slowly is a question for the server (E81).
- **The data-mining machine is not the limit:** tools and tests 3.9 %, grading 3.4 %, preparation 0.4 %.
- **Long sessions cost most and fail most:** the three sessions not kept hold 36.0 % of the session time.

## What happened during the job

- **12:21 UTC:** the driver's first start misread `start_run`'s answer (a run id, not a record) and stopped watching
  while the run went on. The fixed driver took that same run over at 12:22 (`ADOPT_RUN`) and started nothing twice.
- **13:15:** the owner lowered the free-space stop from 700 GB to 50 GB; the driver was restarted with it and took over
  the run in progress (`ex338-pr-1457`). Free space on `/` went from 794,467,504,128 bytes at 12:21 to
  705,021,272,064 at 14:59, mostly other jobs' images.
- **14:45 to 14:55 (about):** the editing machine restarted. Only the watchers on it stopped; the driver on the
  data-mining machine ran on, and no session was affected.
- **15:09:** `ex338-pr-1394`'s first session failed for the machine's reason; the case was added once more at the end
  of the list ([`run/tasks_run2.txt`](run/tasks_run2.txt)).
- Times are the data-mining machine's clock (UTC), which reads about 6 minutes behind the editing machine's.

## Files

| File | What it holds |
|---|---|
| `README.md` | this page |
| `sessions.tsv` | one row per session: kind, description bytes, run id, how it ended, the first failed step, kept, the run's, preparation's, session's and grading's seconds, turns, tool calls, prompt, generated and largest-prompt tokens, the server's new and reused tokens, reading, generating, model-wait, other-model and tools-and-rest seconds, calls matched, calls read in full, other requests |
| `calls.tsv` | one row per model call (586): when it was sent, its wall time, prompt tokens, reused and new tokens, reading ms, generated tokens, generating ms, time to the first token, how the answer stopped, tool calls, matched |
| `totals.json` | the sums of `sessions.tsv`, by kind as well |
| `cases.tsv` | the driver's own record: one line per run |
| `checks.tsv` | the checks of the 16 cases in this controller and the two rechecks |
| `inventory.tsv` | the controller's inventory of the 16 cases after import |
| `load.tsv` | the data-mining machine's load once a minute from 12:37 UTC, with the count of running containers (all jobs) |
| `run/build.sh`, `run/test.sh`, `run/t0_formatter.exs`, `run/docker_shim.sh` | the set-up's scripts, unchanged: the images, and the parity test |
| `run/controller.sh` | the set-up's controller script, with the preparation's look-ahead and workers from the environment and the key file mounted read only |
| `run/prepare.sh` | import, inventory, and the checks with no model |
| `run/drive.sh` | one run per case, the stop rules, the record |
| `run/metrics_log.py` | the server's per-request timings |
| `run/load_log.sh` | the machine's load |
| `run/collect.py` | the tables above, from the engine's files and the server's records |
| `run/tasks.txt`, `run/tasks_recheck.txt`, `run/tasks_run.txt`, `run/tasks_run2.txt` | the 16 cases; the two checked again; the 15 run; the list of the restarted driver, with `ex338-pr-1394` again at its end |

The sessions themselves (messages, tool calls, thinking, patches) are not published here: the two scans that must
pass first (`docs/dataset_rules.md` section 6) are not built yet.

## Commands

On the data-mining machine; every container with the label `task-factory=1` and a CPU share of 256:

```sh
SRC=<factory> OUT=<out>/build LABEL=task-factory=1 TOOLING_IMAGE=etf-tooling:run-20261112 \
  IMAGE=elixir-task-factory:run-20261112 sh -c 'run/build.sh tooling && run/build.sh controller'
SRC=<factory> OUT=<out>/parity IMAGE=etf-tooling:run-20261112 LABEL=task-factory=1 HEX_CACHE_ID=etf-hex-packages-v1 \
  sh -c 'run/test.sh deps && TAG=parity run/test.sh unit test/eab/bench_parity_test.exs'
export CTL=<controller folder> NAME=factory-run SRC=<factory> CONTROLLER=$PWD/run/controller.sh \
  SOURCES=<the folder of the 16 case folders> KEY_FILE=<the file holding the server's key>
IMAGE=elixir-task-factory:run-20261112 HEX_CACHE_ID=etf-hex-packages-v1 LABEL=task-factory=1 EPMD_PORT=4513 \
  PREPARE_AHEAD=1 PREPARE_WORKERS=1 run/controller.sh up
TASKS=run/tasks.txt OUT=<out>/prepare run/prepare.sh
TASKS=run/tasks_recheck.txt OUT=<out>/prepare_recheck run/prepare.sh
MODEL_URL=<the server, without /v1> TASKS=run/tasks_run.txt OUT=<out>/run run/drive.sh
OUT=<out>/run run/load_log.sh
MIN_FREE=50000000000 ADOPT_RUN=<run> ADOPT_TASK=ex338-pr-1457 ADOPT_STARTED=<its start> MODEL_URL=<the server> \
  TASKS=run/tasks_run2.txt OUT=<out>/run run/drive.sh
RUNS=$CTL/data/runs DRIVE_OUT=<out>/run TASKS=$CTL/tasks DEST=<out>/tables python3 -I run/collect.py
run/controller.sh stop
```

`drive.sh` and `metrics_log.py` read the key from `KEY_FILE` and pass it on without writing it anywhere; no record of
this job holds it (checked with the key file as a pattern).

## Provenance and licence

The cases come from `axelclark/ex338`, MIT at every case's starting commit (each case's `provenance.json`; the licence
scan). The descriptions are the teacher's ([statements](../2026-11-12_statements_first_20/README.md)). These tables are
measurements of the engine and the server; they hold no session text.
