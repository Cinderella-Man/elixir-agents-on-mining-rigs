# The task factory without its web page, results page, run series and comparison (2026-11-12)

Job T1 of the [task factory](../../../factory/README.md) (section 7), for registry row [E68](../../../experiments.md).
The parts of the copied engine that publish and show bench results were removed, and with them Phoenix, LiveView and
the web server. The bench's own checks then ran on what is left and were compared, test by test, with job T0's runs
([2026-11-12_factory_t0](../2026-11-12_factory_t0/README.md)). Everything ran on the CPU of the 7-GPU machine, in the
tooling image `eab-tooling:dev` that T0 built, on 2026-11-12 between 01:44 and 01:51 (UTC+1).

## Result

- **The project compiles with warnings as errors and without Phoenix.** The format check passes.
- **Every test that remains ends as it did in T0,** in both runs. Of T0's 298 tests, 225 remain and 73 are gone.

  | Run | Passed | Failed | Excluded | T0 (with its two new tests) |
  |---|---:|---:|---:|---|
  | `MIX_ENV=test mix test --warnings-as-errors` | 176 | 42 | 7 | 226, 65, 7 |
  | the same with `EAB_DOCKER_TESTS=1` and the Docker socket | 181 | 42 | 2 | 231, 65, 2 |

  The 42 failures are tests that failed in T0 for the same reason: 41 need the bench's cases, which are never copied
  here, and 1 reads a bench file that was not copied (`scripts/install-claude-code-kit.sh`, in the dropped
  `claude_code_test`). The 23 fewer failures are the dropped tests that read `results-page/index.html` (16) or need
  the bench's cases (7), all in removed files.
- **The parity test passes, untouched:** `test/eab/bench_parity_test.exs` 6 of 6 in both runs; its file and every
  file it pins are unchanged.
- The two test runs were made twice, before and after a format fix of one blank line in `lib/eab/runs.ex`; both pairs
  give the same state for every test. The tables are from the second pair.

### The tests that are gone

| Test file | Tests | In T0 | Why |
|---|---:|---|---|
| `test/eab_web/dashboard_test.exs` | 19 | 11 passed, 8 failed | its file is removed: the web page |
| `test/eab/results_test.exs` | 16 | 10 passed, 6 failed | its file is removed: the results page |
| `test/eab/log_sections_test.exs` | 13 | passed | its file is removed: the log sections |
| `test/eab/series_test.exs` | 9 | failed | its file is removed: the run series |
| `test/eab_web/chatgpt_test.exs` | 5 | passed | its file is removed: every test drives the web page (`EabWeb.Endpoint`, `Phoenix.LiveViewTest`) |
| `test/eab/comparison_test.exs` | 1 | passed | its file is removed: the comparison |
| `test/eab/claude_code_test.exs` | 10 of 21 | passed | removed from a file that stays until T2: they post to `lib/eab_web/claude_code_controller.ex` through Phoenix's test connection |

The states are the same with and without Docker. One assertion also went from a test that stays:
`runs_test` "Claude Code validation runs record their harness and are never publishable" no longer checks that
`Eab.Results.export!/1` refuses a validation run. That test failed in T0 and fails now, at its start, because it needs
the bench's cases.

## What was removed and changed

Removed (25 files): `lib/eab_web/` (8), `lib/mix/tasks/eab.results.ex`, `lib/eab/results.ex` and `lib/eab/results/`
(3), `lib/eab/series.ex`, `lib/eab/comparison.ex`, `lib/eab/log_sections.ex`, `priv/static/assets/` (2),
`priv/admitted_validation_runs.json`, and the six test files above.

Changed:

| File | Change |
|---|---|
| `mix.exs` | `phoenix`, `phoenix_live_view`, `phoenix_html`, `bandit` and `lazy_html` and the `assets` alias go; `plug_crypto` becomes a direct dependency, because `lib/eab/chatgpt_auth.ex` (dropped in T2) calls `Plug.Crypto.secure_compare/2`. `jose` stays for the same file. |
| `mix.lock` | Written by `mix deps.clean --unlock --unused`: 14 packages leave (`bandit`, `cc_precompiler`, `elixir_make`, `fine`, `lazy_html`, `phoenix`, `phoenix_html`, `phoenix_live_view`, `phoenix_pubsub`, `phoenix_template`, `plug`, `thousand_island`, `websock`, `websock_adapter`). No package was added or downloaded, and the tooling image was not rebuilt. |
| `lib/eab/application.ex` | The endpoint goes; Phoenix's PubSub becomes an Elixir `Registry` named `Eab.PubSub`. |
| `lib/eab/runs.ex` | The `series:` option goes. `subscribe/0` and the change broadcast use the `Registry`, with the same `:runs_changed` message, because `runs_test` waits on it. |
| `config/config.exs`, `config/runtime.exs` | The endpoint's settings, Phoenix's settings and the session secret go. |
| `Dockerfile`, `compose.yaml` | `mix assets`, the copy of the run list, the results-page mount and the web port go. |
| `.formatter.exs`, `.dockerignore`, `.gitignore` | The LiveView formatter plug-in and the lines for the page's copied script files go. |
| `test/eab/claude_code_test.exs`, `test/eab/runs_test.exs` | The tests and the assertion named above, with the helpers only they used. |

Nothing that section 2 of the factory's README holds was edited.

## Files

| File | What it holds |
|---|---|
| [tests_compared.tsv](tests_compared.tsv) | One row per test (298): its state in T0's two runs with the new tests (`unit_t0`, `docker_t0`) and in T1's two runs, the verdict (`same`, `gone: file removed`, `gone: test removed`), and the cause T0 gave for a failure. |
| [run/compare.sh](run/compare.sh) | Builds that table from the per-test lines that T0's `run/test.sh` writes. |

The other scripts are T0's, unchanged: [sync.sh, test.sh and the formatter](../2026-11-12_factory_t0/run/).

## Exact commands

On the editing machine, after each edit of `factory/`:

```bash
HOST=<build machine> WORK=<work folder> docs/data/2026-11-12_factory_t0/run/sync.sh
```

On the build machine, in `WORK` (T0's scripts in `run/`, with `compare.sh` copied beside them), with
`LABEL=<key>=<value>` for every container started (`CPU_SHARES` is 256):

```bash
docker run --rm --label $LABEL --cpu-shares 256 --cpus=2 --user 1000:1000 -e HOME=/tmp -e HEX_HOME=/tmp/hex \
  -v $PWD/src:/app -w /app eab-tooling:dev mix deps.clean --unlock --unused
WORK=$PWD LABEL=$LABEL TAG=t1_format2 run/test.sh format
WORK=$PWD LABEL=$LABEL TAG=t1_unit2 run/test.sh unit
WORK=$PWD LABEL=$LABEL TAG=t1_docker2 run/test.sh docker --exclude module:Elixir.Eab.BrowserDockerTest
WORK=$PWD run/compare.sh unit_t0 docker_t0 t1_unit2 t1_docker2 tests_per_test.tsv > tests_compared.tsv
```

`mix.lock` was copied back from the build machine into `factory/`. `browser_docker_test` is left out of the Docker run
as in T0 (it downloads Playwright). The first format check failed on one missing blank line after `subscribe/0` in
`lib/eab/runs.ex`; after the fix it passes.

## Images and disk

No image was pulled or built. Free space on `/`, which holds Docker's data: 666,569,756,672 bytes before,
666,182,066,176 after. The test runs removed every container they started.

## Provenance and licence

The code under test is the bench's engine as copied into `factory/` (see its README, section 1, for the licence
question), with this job's removals and edits. The script here is this repository's. The table holds only test names,
states and causes.
