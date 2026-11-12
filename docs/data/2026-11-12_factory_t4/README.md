# Factory job T4: the browser support removed, measuring switched off (E68)

`factory/README.md` section 7, row T4. The browser support served one bench case; training tasks are graded by
ExUnit only. The factory records no elapsed time or speed, so every attempt starts with measuring off. The two files
the parity test watches most, `fixtures.ex` (the workspace recipe) and `agent.ex` (the instruction sentences), give
the bench's text byte for byte for a task without a browser.

## Removed

- `lib/eab/browser.ex`; `priv/fixtures/browser/package.json` and `package-lock.json` (the pinned Playwright bundle);
- `test/eab/browser_docker_test.exs` (1 test, which never ran here: it builds from the Playwright image).

## Edited (files that stay)

- `fixtures.ex`: the three browser calls (the bundle copy in `prepare/4`, the browser stage and the install lines in
  `dockerfile/4`) and the `plausible_ce` line (its `npm ci` in `tracker`) are gone.
- `agent.ex`: the browser sentence is gone and its line stays an empty line, as in the 19 bench cases without a
  browser; every attempt starts with `measure: false`, so `submit/7` no longer reads the run's `parallel_attempts`.
- `baseline.ex`: the default for the `plausible_ce` profile is gone; a task without a `baseline` block gets the
  prepared mode with no commands.
- `measurement.ex`: the reason given when nothing is measured is "Not measured: the factory records no elapsed time"
  (was the reason for parallel attempts). The module and `model_speed.ex` stay, because `pi.ex` calls them and keeps
  its bytes (`c087a89c`).
- Tests: `measurement_test` "a run with several parallel attempts records no elapsed time" became "an attempt started
  with measuring off records no elapsed time" (same body, the new sentence); `report_test` expects the new sentence;
  `baseline_test` named the dropped profile to get the policy with `mix ecto.create --quiet` and `mix ecto.migrate`
  and now states that policy as the task's `baseline` block, so it tests the same inputs.
- Not needed: `task_contract.ex` already refuses `runtime.browser` (T5), and `candidates.ex` accepts only the `mix`
  profile.

## Commands (the tooling image, on the build machine)

```
WORK=$PWD LABEL=pascal-quants=1 run/checks.sh t4b    # format check, unit tests, tests with EAB_DOCKER_TESTS=1
WORK=$PWD run/compare.sh t3_unit t3_docker t4b_unit t4b_docker > tests_compared.tsv
```

`run/checks.sh` is job T3's with the browser test's exclusion removed; the other scripts are job T0's, unchanged
(`docs/data/2026-11-12_factory_t0/run/`). The tests run with `mix test --warnings-as-errors`. A first run (`t4`)
failed only the format check (two files; same test results); `t4b` is the run after `mix format`'s two fixes.

## Counts

| | T3 | T4 |
|---|---|---|
| format check | passes | passes |
| without Docker | 187 passed, 0 failed, 6 excluded | 187 passed, 0 failed, 5 excluded |
| with `EAB_DOCKER_TESTS=1` | 192 passed, 0 failed, 1 excluded (the browser test) | 192 passed, 0 failed, 0 excluded |

`tests_compared.tsv` (195 lines, the first is the header): 191 tests end as in T3; 1 is gone with
`browser_docker_test.exs` (excluded in T3); the renamed `measurement_test` case shows as one removed and one new test
(passes in both runs). `bench_parity_test` passes 6 of 6 in both runs, untouched; `pi.ex` keeps its bytes.

Free space on `/` of the build machine: 648,386,547,712 bytes before (03:54:00), 647,622,983,680 after (04:02:49);
other jobs ran at the same time.
