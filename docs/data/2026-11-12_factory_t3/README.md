# Factory job T3: the memory collector removed (E68)

`factory/README.md` section 7, row T3. The memory collector sampled the model host's memory over SSH for the bench's
results page. No training measure needs it, and what the model sees under Pi and what a pass means do not depend on
it.

## Removed

- `lib/eab/memory_monitor.ex`, `lib/eab/memory_collector/cli.ex`, `sampler.ex`, `weights.ex`;
- `test/eab/memory_monitor_test.exs` (8 tests), `test/support/memory_collector.mjs`.

## Edited (files that stay)

- `runs.ex`: no monitor is started, finished or recovered; a run has no `"memory"` field and no `memory_updated`
  message; a run starts without memory settings.
- `report.ex`: the line about sampled memory is gone. `application.ex`: the supervisor of the monitors is gone.
- `config/runtime.exs`: the `EAB_MEMORY*` settings and the helper that read them. `compose.yaml`: its six
  `EAB_MEMORY*` variables. `.formatter.exs`: the path of the uncopied collector project.
- `Dockerfile`: `openssh-client` is no longer installed (nothing else calls `ssh`).
- `runs_test.exs`: the memory case became "a run starts with no memory settings and finalizes on completion, error
  and cancellation": it sets no memory setting and asserts that the run, the saved record and the report carry no
  memory.
- Left alone: `model_identity.ex` keeps `from_files/1` (a kept file, tested in `model_identity_test`); nothing in
  `lib/` calls it now.

## Commands (the tooling image, on the build machine)

```
WORK=$PWD LABEL=pascal-quants=1 run/checks.sh t3     # format check, unit tests, tests with EAB_DOCKER_TESTS=1
WORK=$PWD run/compare.sh t2b_unit t2b_docker t3_unit t3_docker > tests_compared.tsv
```

The scripts are those of job T0, unchanged (`docs/data/2026-11-12_factory_t0/run/`). The tests run with
`mix test --warnings-as-errors`; the browser test is left out.

## Counts

| | T2 | T3 |
|---|---|---|
| format check | passes | passes |
| without Docker | 195 passed, 0 failed, 6 excluded | 187 passed, 0 failed, 6 excluded |
| with `EAB_DOCKER_TESTS=1` | 200 passed, 0 failed, 1 excluded | 192 passed, 0 failed, 1 excluded |

`tests_compared.tsv` (203 lines, the first is the header): 192 tests are the same as in T2 (the browser test is excluded in both), 8 are gone with
`memory_monitor_test.exs`, 1 is gone from `runs_test` (the memory case) and 1 is new in `runs_test` (its rewrite,
passes). `bench_parity_test` passes 6 of 6, untouched.

Free space on `/` of the build machine: 648,602,107,904 bytes before (03:45:42), 648,405,893,120 after (03:50:09);
other jobs ran at the same time.
