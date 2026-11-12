# Task factory job T10: one made-up task from end to end through a controller (2026-11-12)

Trimming job T10 of [`factory/README.md`](../../../factory/README.md), section 7, for registry row
[E68](../../../experiments.md). One made-up task went through a controller built from the finished code, by
`bin/factoryctl` only: imported, checked, exported, run against a stand-in model server, and listed as a kept
session. A second attempt with a wrong change ended as not passed and was not listed.

**Result:**

| Step | Call | Outcome |
|---|---|---|
| import | `factoryctl import /data/incoming` | `imported` |
| check | `factoryctl check ledgerette-pr-1`, then `factoryctl job <job>` | `checked` in 42,598 ms: source from the mirror, prepared, probed, controls and second round held (2 hidden tests fail first and pass after, partial fix present and rejected, 0 tests changed in the second round) |
| export | `factoryctl export /data/export ledgerette-pr-1` | exported, with `results.tsv` |
| run, right change | `factoryctl start-run http://127.0.0.1:18110 ledgerette-pr-1` | run `completed` in 25.4 s; the attempt `completed`, 7 model calls, 263 generated tokens, grade passed |
| kept sessions | `factoryctl kept <run>` | 1 kept session, 0 unverified |
| run, wrong change | the same against the wrong conversation | run `completed` in 12.7 s; the attempt `completed`, 4 model calls, 149 generated tokens, grade **not passed** (the hidden test of the debit fails) |
| kept sessions | `factoryctl kept <run>` | 0 kept, 0 unverified |

One bug was fixed: `bin/factoryctl` printed a warning of the Erlang VM before the JSON answer, so its output was
not JSON (below). Every test passes with the fix (counts below); the parity test is untouched.

## What ran

All on the 7-GPU machine's CPU, in containers labelled `pascal-quants=1` with a CPU share of 256; no GPU was used.
The scripts are in [`run/`](run/) and take hosts and paths from the environment.

| File | What it does |
|---|---|
| [`run/controller.sh`](run/controller.sh) | builds the controller's image (`build`), starts one controller with a new data folder, the task folder mounted writable and a mirror folder read only (`up`), removes it (`down`). No wrapper in front of `docker`: the engine adds the labels and the share from `EAB_DOCKER_LABELS` and `EAB_CPU_SHARES` |
| [`run/make_task.exs`](run/make_task.exs), [`run/make_task.sh`](run/make_task.sh) | make the made-up task `ledgerette-pr-1` (`factory/test/support/tasks/`) runnable: a Git repository of the made-up project with its starting commit and its merge commit, a bare mirror of it, and the task with the real commits and trees and a statement |
| [`run/standin.mjs`](run/standin.mjs), [`run/standin.sh`](run/standin.sh) | the stand-in model server and its container |
| [`run/watch.sh`](run/watch.sh) | records the labels and the CPU share of every container started while it runs |
| [`first_request.json`](first_request.json) | the first request the stand-in received (below) |

### The task

The made-up task `ledgerette-pr-1` is a bug fix in two files of a made-up ledger with no dependencies, with a partial
fix (the reference without its second file). Its folder is the test fixture's, with four changes so that a real
controller can fetch and build it:
- `repository.revision` and the four commits and trees of `provenance.json` are those of a real Git repository made
  from the made-up project's source (`Eab.MadeUpTasks.write_source!/1`), with the reference and its tests applied as the
  merge commit. Its GitHub address stays made up, so the upstream fetch fails and the source comes from the mirror
  (`EAB_MIRRORS`, a JSON file naming `file:///mirror/ledgerette.git`);
- `runtime.image` is the pinned `hexpm/elixir` 1.18.3 / OTP 27.3 image of the ex338 recipe, already on the machine;
- `ticket.md` holds two made-up sentences, and `statement.json` names the writer `test-fixture` with the note "made-up
  statement for factory job T10: a test fixture, never training data".

### The stand-in model server

A Node server (no dependencies) in a container of its own on the pinned Node image of `factory/priv/pi/runtime.json`,
listening on the host's loopback only, which the controller reaches through its host network. It answers what
`Eab.Model.discover/2` reads (`/health`, `/v1/models`, `/props`, as a llama.cpp server with a 262,144-token context),
the prompt count (`/v1/chat/completions/input_tokens`: the request's JSON bytes divided by 4, rounded up), and each
chat request with the next step of a fixed conversation as one streamed answer in the llama.cpp format, with its
usage, as `factory/test/eab/pi_docker_test.exs` does. The step is the number of assistant messages in the request.
It fills Pi's `edit` arguments from the tool's own declared parameters (`path` and `edits[]` of `oldText`/`newText`
in Pi 1.2.0).

| Conversation | Steps |
|---|---|
| `good` | `read lib/ledgerette.ex`; `edit` it (debits subtract); `read lib/ledgerette/format.ex`; `edit` it (a clause for negative amounts); `write test/debit_test.exs` (two tests, one per change); `bash mix test test/debit_test.exs test/ledgerette_test.exs`; a two-sentence summary |
| `wrong` | `read lib/ledgerette/format.ex`; `edit` it; `write test/format_sign_test.exs`; a summary. The debit is left unfixed |

### Commands

On the machine, with `WORK` the job's folder, `DATA` a new data folder:

```sh
export SRC=$WORK/src DATA=<new data folder> TASKS=$WORK/tasks MIRROR=$WORK/mirror NAME=factory-t10
export NODE_IMAGE=node@sha256:d6aa754f16b3197301076f047b5def2f02ea1dbbc2ca920407d46d7ec7f87b20 OUT=$WORK/standin
SRC=$SRC run/controller.sh build                                  # elixir-task-factory:t10
TASK_IMAGE='hexpm/elixir:1.18.3-erlang-27.3-ubuntu-noble-20260509.1@sha256:05d0223efb52293e146b2b20fee462fd1372264fdd9491d9ea222dbf527c703f' \
  WORK=$WORK run/make_task.sh                                     # the task into $DATA/incoming, the mirror into $WORK/mirror
OUT=$WORK/out run/watch.sh &
run/controller.sh up
$SRC/bin/factoryctl import /data/incoming
$SRC/bin/factoryctl check ledgerette-pr-1                         # {"ok": "check-20261112-040838-e88409"}
$SRC/bin/factoryctl job check-20261112-040838-e88409              # until "status": "done"
$SRC/bin/factoryctl export /data/export ledgerette-pr-1
run/standin.sh up good
$SRC/bin/factoryctl start-run http://127.0.0.1:18110 ledgerette-pr-1   # {"ok": "20261112-041014-c15c1eec"}
$SRC/bin/factoryctl status                                        # until "run": null
$SRC/bin/factoryctl kept 20261112-041014-c15c1eec
run/standin.sh down; run/standin.sh up wrong
$SRC/bin/factoryctl start-run http://127.0.0.1:18110 ledgerette-pr-1   # {"ok": "20261112-041125-3a4eb85f"}
$SRC/bin/factoryctl kept 20261112-041125-3a4eb85f
run/standin.sh down; LOG=$WORK/out/controller.log run/controller.sh down
```

Import, check and job ran with `bin/factoryctl` as on `main` before this job; export and every later call with the
fixed one. A second `check` of the same task (job `check-20261112-041224-560a25`, `checked` in 19,393 ms) ran only to
record the check's own containers with the watcher, whose first start had failed on a format error (`{{.ID}}` in
place of `{{.Actor.ID}}`; the committed `watch.sh` is the fixed one). The committed `standin.sh` mounts the server
at `/opt/standin/` inside its container; the run used another folder there, nothing else differs.

## The answers, as printed

`import` (before the fix: the first two lines are the VM's warning):

```text
=ESOCK WARNING MSG==== 12-Nov-2026::04:08:17.011411 ===
[UNIX-ESSIO] Failed open sctp dynamic library: libsctp.so.1
{
  "ok": [
    {
      "folder": "ledgerette-pr-1",
      "id": "ledgerette-pr-1",
      "result": "imported"
    }
  ]
}
```

`job`, the result of the check (abridged: the file hashes and the per-step times other than the two longest):

```json
{"verdict": "checked", "probe": "ok", "hidden_failing_first": 2, "hidden_passing_after": 2,
 "partial_control": {"present": true}, "preservation": "mix test test/ledgerette_test.exs",
 "preservation_files": 1, "preservation_left_out": [],
 "second_round": {"changed": [], "empty_passed": false, "reference_passed": true, "same": true},
 "source_ms": 629, "prepare_ms": 16026, "total_ms": 42598}
```

`export`: `{"ok": {"exported": ["ledgerette-pr-1"], "refused": []}}`, and `results.tsv`:

```text
id	verdict	dropped_at	reason	hidden_failing_first	hidden_passing_after	partial	partial_reason	preservation_files	left_out	second_round_changed	total_ms
ledgerette-pr-1	checked			2	2	true		1	0	0	42598
```

`kept` for the right attempt: `"status": "completed"`, `"cases": 1`, `"unverified": []` and one entry in `"kept"`
with `"case": "ledgerette-pr-1"`, `"folder": "/data/runs/20261112-041014-c15c1eec/ledgerette-pr-1"`,
`"generation": 1` and the files below. For the wrong attempt: `"status": "completed"`, `"cases": 1`, `"kept": []`,
`"unverified": []`. The wrong attempt's grade: submitted tests passed (the model's own test), preservation passed,
acceptance failed (`Elixir.Ledgerette.NegativeTest::test debits lower the balance`); the run's score 0 of 1.

## The kept session's files

`runs/20261112-041014-c15c1eec/ledgerette-pr-1/` in the controller's data folder, against the design note's
[section 7](../../research/notes/task_factory_on_the_bench_engine.md):

| Design note | Present |
|---|---|
| `prompt.md`, `instructions.md` | both |
| `pi-config.json` | yes |
| `request-NNNN.json`, `response-NNNN.sse`, `usage-NNNN.json` | `0000` to `0006`, 7 of each |
| `pi-events.jsonl` | yes, 60 lines |
| `model.patch` | yes: the two code changes and `test/debit_test.exs` |
| `attempt.json` | yes: `completed`, `agent_completed`, 7 calls, 263 generated tokens |
| `grade.json` | yes |
| `submission.json`, `checkpoints/<task>.json` | `submission.json` in the task's folder; `checkpoints/ledgerette-pr-1.json` one level up, in the run's folder |
| `runtime.json`, `qualification.json` | both |
| `activity.log`, `build.log` | both |

One file more than the list: `agent-progress.json` (the gateway's counters). The run's folder also holds
`events.jsonl`, `release.json`, `report.md`, `run.json` and `summary.json`.

## What the model is shown

[`first_request.json`](first_request.json) is the first request the stand-in received, byte for byte the engine's own
`request-0000.json` of the kept session (SHA-256 `96b6c97ee4c49182d65b4ae94ab8a5f4a6accd524b9e767a73f9555782305337`
for both). It holds Pi's own system prompt, the four tools `read`, `bash`, `edit`, `write` with Pi 1.2.0's
definitions, and one user message, the statement as Pi passes it (`<file name="/tmp/eab-ticket.md">`). The engine's
instructions are in the system prompt's `<addendum>`, and they are the text of `factory/README.md` section 2.1 line
for line, except the test command, `mix test test/ledgerette_test.exs.` in place of the placeholder. The allowed
folders are the README's, `lib/, test/`. `instructions.md` of the kept session holds the same text. The request's
settings: `max_tokens` 8192, `seed` 101, `stream` with usage, `model` the server's alias.

## Labels, share and names

Every container the engine started for this controller (installation `0f41df5b5c48e4d7408d2ccb5f5a38ca`), as
`docker inspect` read them when they started (`run/watch.sh`):

| Started by | Containers | Names | `pascal-quants` | CPU share | Image |
|---|---:|---|---|---:|---|
| the second check (`etf.run` = `check-20261112-041224-560a25-1`) | 8 | `etf-…` | `1` | 256 | the task's project image |
| the right run (`etf.run` = `20261112-041014-c15c1eec`) | 3 | `etf-…` | `1` | 256 | the agent image once (the attempt), the project image twice (grading) |
| the wrong run (`etf.run` = `20261112-041125-3a4eb85f`) | 3 | `etf-…` | `1` | 256 | the same |

The controller itself: `factory-t10`, label `pascal-quants=1`, CPU share 256, host network, image
`elixir-task-factory:t10`. The stand-in: `t10-standin`, label `pascal-quants=1`, CPU share 256, host network.

The images the engine used, by `docker image inspect`:

| Image | Tags | `pascal-quants` | Size (bytes) |
|---|---|---|---:|
| `sha256:c400702e4733…` | `elixir-task-factory:project-c400702e…`, `:project-e9b307bd…`, `:seed-c400702e…` | `1` | 247,441,978 |
| `sha256:2142a163eab0…` | `elixir-task-factory:agent-b6e195d5…` | `1` | 318,214,990 |
| `sha256:7522f7eeaecb…` | `elixir-task-factory:toolchain-7522f7ee…`, `:toolchain-ledgerette-pr-1` | `1` | 247,381,306 |

The toolchain image was built earlier on the same machine by another job with the same recipe lines (the same
`hexpm/elixir` image and environment); this controller found it by its inputs and added the tag
`toolchain-ledgerette-pr-1`. No image or container of this controller carries a bench name.

## The bug fixed: the wrapper's output was not JSON

In the controller's image the VM that `bin/factory rpc` starts prints a warning to standard output before the
answer, because the image has no `libsctp`:

```text
=ESOCK WARNING MSG==== 12-Nov-2026::04:08:38.039923 ===
[UNIX-ESSIO] Failed open sctp dynamic library: libsctp.so.1
```

So `bin/factoryctl`'s output could not be read as JSON. The wrapper now prints the answer from its first line that
opens a JSON object, and everything when no line does (when the rpc call itself fails, so that its error stays
visible); the exit code is the rpc call's. New test in `factory/test/eab/factory_test.exs`: a stand-in for `docker`
prints the same warning, then an answer, or an error with exit code 1.

## Tests

Run on the factory with the fix, in the tooling image, with job T9's scripts (`docs/data/2026-11-12_factory_t0/run/`
and job T9's `checks.sh`):

| Check | Result | T9 (`main` before this job) |
|---|---|---|
| `mix format --check-formatted` | passes | passes |
| `MIX_ENV=test mix test --warnings-as-errors` | 206 passed, 0 failed, 9 excluded (runs `t10` and `t10b`) | 205 passed, 0 failed, 9 excluded |
| the same with `EAB_DOCKER_TESTS=1` | 215 passed, 0 failed in run `t10`; 214 of 215 in run `t10b`, then the one that failed passed alone (below) | 214 passed, 0 failed, 0 excluded |

Run `t10` had the new test before `mix format` reflowed three of its lines (its format check failed on that file);
run `t10b` is the committed tree, and its format check passes. In `t10b` one Docker test failed:
`baseline_docker_test` "clean snapshots preserve both database families and independent writable clones", with
`No such image: sha256:962460f6…` while another job's Docker tests ran on the same machine, and again (`No such image:
sha256:2a9499b4…`) when run alone while that other job's tests still ran. Run once more alone after they had ended, it
passed (1 of 1). It passed in `t10`, on `main` (T9), and it touches neither file this job changed. Per test against
T9's runs: 213 end as in T9, 1 is new and passes (the wrapper's test), and the baseline test is the one that differs
in `t10b`.

After the rebase onto E72 (the toolchain resolver, which landed while this job ran: 223 and 232 tests pass), the
checks ran again on the pushed tree (run `t10e`): the format check passes; **224 passed, 0 failed, 9 excluded
without Docker, 233 passed, 0 failed with it**. `bench_parity_test` passes 6 of 6 in every run and was not edited.

## Images and downloads

| Image | How | Size |
|---|---|---|
| `elixir-task-factory:t10` (`sha256:e9ec30419b05…`) | built from `factory/` at the start of this job (13 of its steps from the build cache) | 191,499,143 bytes by `docker image inspect`, 771 MB by `docker images`; kept |
| `node@sha256:d6aa754f…` (Pi's pinned Node image) | pulled, for the stand-in | 80,839,209 bytes by `docker image inspect`, 332 MB by `docker images` |
| the agent image | built by the engine during the right run; its `npm ci` step came from the build cache, so no npm package was downloaded | 318,214,990 bytes |
| the project image | built by the engine during the first check | 247,441,978 bytes |

## Disk

Free on `/`: 636,021,116,928 bytes before (05:07:08 CET), 630,917,279,744 bytes after (05:31:33 CET), with other
jobs running on the same machine.

## Not verified

- The run reused the controls that `check` had saved ("Reusing checked fixture"), so the controls did not run again
  before the attempt; that they run again when the task or the grading code changed was not exercised here.
- A real model: the stand-in plays back a fixed conversation and reports made-up token counts; the token budget and
  the context budget were never near their limits.
- A task with a database service, or one whose source is fetched from GitHub itself.
