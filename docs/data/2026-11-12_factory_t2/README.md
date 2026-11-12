# The task factory without the other harness and the cloud back ends (2026-11-12)

Job T2 of the [task factory](../../../factory/README.md) (section 7), for registry row [E68](../../../experiments.md):
the Claude Code harness, the Claude API back end and the ChatGPT subscription back end are removed. With them gone,
the factory cannot produce a session by a cloud model at all: a run is served only by a llama.cpp or Strata server,
under Pi. The bench's own checks ran and were compared, test by test, with job T6's runs
([2026-11-12_factory_t6](../2026-11-12_factory_t6/README.md)). Everything ran on the CPU of the 7-GPU machine, in the
tooling image `eab-tooling:dev` that T0 built, on 2026-11-12 between 03:27 and 03:42 (UTC+1).

## Result

- **The project compiles with warnings as errors, the format check passes, and every test passes.**

  | Run | Passed | Failed | Excluded | T6 |
  |---|---:|---:|---:|---|
  | `MIX_ENV=test mix test --warnings-as-errors` | 195 | 0 | 6 | 226, 2, 8 |
  | the same with `EAB_DOCKER_TESTS=1` and the Docker socket | 200 | 0 | 1 | 232, 2, 2 |

- **Every test that still exists ends as in T6** (199 tests, both runs). 35 tests are gone, each with a dropped part
  (34 with their files, 1 removed from `pi_test`), and 2 tests of `runs_test` were written again for Pi under new
  names (in the table they show as `gone: test removed` and `new`; below).
- **The parity test passes untouched,** 6 of 6 in both runs; `test/eab/bench_parity_test.exs` was not edited.
  `lib/eab/pi.ex`, `lib/eab/thinking.ex` and the files of `priv/pi/` have their bytes; of `lib/eab/pi_gateway.ex`
  only the two cloud clauses of `exchange/2` and their routes went, and the clause for llama.cpp and Strata is as it was.
- **`pi_test` passes** (all of its tests, both runs) without its one ChatGPT case.
- The excluded tests: without Docker, the 6 Docker tests; with Docker, the browser test (left out, as in T0 to T6).
  T6 also excluded `claude_code_hook_test` (no `python3` in the image) and, without Docker, `claude_code_docker_test`.

### The tests that are gone or changed

| Tests | T6 | Now | Why |
|---|---|---|---|
| `anthropic_test` (6), `openai_test` (7), `chatgpt_auth_test` (8) | passed | gone | their files are removed with `anthropic.ex`, `openai.ex` and `chatgpt_auth.ex` |
| `claude_code_test` (11: 9 passed, 2 failed) | as in T6 | gone | removed with `claude_code.ex` and `claude_code/`; the 2 failures were T6's only failures (one read an uncopied bench file, one needed a task in the inventory) |
| `claude_code_docker_test` (1) | excluded, passed | gone | removed with the harness |
| `claude_code_hook_test` (1) | excluded in both | gone | removed with the harness, with `test/claude_code/hook_test.py` |
| `pi_test` "fresh Pi sessions send identical initial prompts and tools" | passed | gone | the one case that runs Pi against the ChatGPT back end's settings (the cut list names it) |
| `runs_test` "Claude Code validation runs record their harness and are never publishable" | passed | written again as "validation runs record their harness and are never publishable", passed | the same checks on a Pi run (validation flag, harness, sealed code version, the report's sentence), without the Claude Code version; it also checks that an endpoint naming `claude_code`, `anthropic` or `openai_subscription` is refused |
| `runs_test` "dry attempts and escape tests run one case, unscored and unpublishable" | passed | written again as "dry attempts run one case, unscored and unpublishable", passed | the same checks for two dry attempts on a Pi endpoint; the escape test was Claude Code's check and is now refused |

## What changed

| File | Change |
|---|---|
| removed: `lib/eab/claude_code.ex`, `lib/eab/claude_code/` (4 files), `lib/eab/anthropic.ex`, `lib/eab/openai.ex`, `lib/eab/chatgpt_auth.ex` | the harness and the two cloud back ends |
| removed: `priv/claude_code/` (11 files) | the harness's kit, prompts and tools |
| removed: `test/eab/claude_code_test.exs`, `claude_code_docker_test.exs`, `claude_code_hook_test.exs`, `anthropic_test.exs`, `openai_test.exs`, `chatgpt_auth_test.exs`, `test/claude_code/hook_test.py`, `test/support/chatgpt_fixture_helper.exs` | their tests |
| `lib/eab/agent.ex` | every attempt runs Pi; the soft-limit budget sentence of the cloud back ends went. The local budget sentence and `instructions/2` are unchanged. |
| `lib/eab/harness.ex` | Pi only. |
| `lib/eab/model.ex` | the three branches for the cloud back ends and Claude Code went from `settings/2` and `unchanged!/2`; `settings/2` refuses an endpoint that names any back end other than `llama_cpp` or `strata`; `request/4`, used only by the hosted transports, went. |
| `lib/eab/pi_gateway.ex` | the two cloud clauses of `exchange/2` and their routes went. |
| `lib/eab/runs.ex`, `lib/eab/checkpoints.ex`, `lib/eab/report.ex` | the escape test and the Claude Code version went; the dry attempt stays (it runs under Pi). The report lost its words about the cloud back ends and Claude Code transcripts. |
| `lib/eab/evidence.ex` | the links to files only the dropped parts wrote, and two summary fields. |
| `lib/eab/release.ex` | `account_id` (the ChatGPT subscription's) left the endpoint fields of an experiment id; a local endpoint has none. |
| `lib/eab/application.ex` | the ChatGPT sign-in and the Claude Code broker left the supervision tree. |
| `mix.exs`, `mix.lock` | `jose` and `plug_crypto` left; Mix wrote `mix.lock` again (2 packages leave, nothing downloaded). `test/support/` is set as ignored by the test loader (below). |
| `test/test_helper.exs` | the ChatGPT helper and the `python` exclusion went. |
| `test/eab/pi_test.exs`, `test/eab/runs_test.exs` | as in the table above. |
| `Dockerfile` | the copy of `priv/claude_code` went. |

`lib/eab/pi.ex` keeps its bytes, so its `config/4` still has branches for the two cloud back ends. They cannot be
reached: `Model.settings/2` refuses such an endpoint before a run starts, and the gateway accepts only the routes of
llama.cpp and Strata.

**`test_ignore_filters` in `mix.exs`.** Since T5, ExUnit warns that `test/support/made_up_tasks.exs` matches no test
pattern. With `--warnings-as-errors` that warning ends the suite with exit code 1 after every test has run. In T5 to
T6 the suite also had failing tests, so it already ended with exit code 2 and the warning did not change the outcome.
Now that every test passes, the warning alone failed the run (`t2a`: 195 and 200 passed, exit code 1). The setting
tells the loader that the helpers under `test/support/` hold no tests; no test is added or left out by it (`t2b`).

## Files

| File | What it holds |
|---|---|
| [tests_compared.tsv](tests_compared.tsv) | One row per test (238): its state in T6's two runs (`t6b_unit`, `t6b_docker`) and in this job's two runs (`t2b_unit`, `t2b_docker`), and the verdict (`same`, `gone: file removed`, `gone: test removed`, `new`). |

No new script: the checks are [T5's checks.sh](../2026-11-12_factory_t5/run/checks.sh), with T0's
[sync.sh and test.sh](../2026-11-12_factory_t0/run/) and T1's [compare.sh](../2026-11-12_factory_t1/run/compare.sh).

## Exact commands

On the editing machine, after each edit of `factory/`:

```bash
HOST=<build machine> WORK=<work folder> docs/data/2026-11-12_factory_t0/run/sync.sh
```

On the build machine, in `WORK`, with `LABEL=<key>=<value>` for every container started (`CPU_SHARES` is 256):

```bash
docker run --rm --label $LABEL --cpu-shares 256 --cpus=2 --network none --user 1000:1000 -e HOME=/tmp \
  -e HEX_HOME=/tmp/hex -v $PWD/src:/app -w /app eab-tooling:dev mix deps.clean --unlock --unused
WORK=$PWD LABEL=$LABEL run/checks.sh t2b
WORK=$PWD run/compare.sh t6b_unit t6b_docker t2b_unit t2b_docker > tests_compared.tsv
```

Before the table's runs (`t2b`): the first run (`t2`) failed one new assertion in each test run: the refusal of a
cloud endpoint was asked for while the previous run's containers were still being cleaned up, so the answer was
"Previous containers are still being cleaned up"; the test now waits for the cleanup first, as the test's other
runs do. The second run (`t2a`) passed every test (195 and 200) and ended with exit code 1 on the loader's warning
described above.

## Images and disk

No image was pulled or built for keeps; nothing was downloaded. The Docker test builds one image from
`eab-tooling:dev` and removes it. Free space on `/`, which holds Docker's data: 651,069,378,560 bytes before (03:27),
648,621,727,744 after (03:42). Other jobs ran on the machine at the same time. The test runs removed every container they started.

## Provenance and licence

The code under test is the bench's engine as copied into `factory/` (see its README, section 1, for the licence
question), with this job's edits. The made-up tasks are invented for these tests. The table holds only test names and
states.
