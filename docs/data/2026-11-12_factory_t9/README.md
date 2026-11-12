# Factory job T9: the entry points for scripts and the second round of controls (E68)

`factory/README.md` section 7, row T9 (section 6, changes 5 and 8). The factory gets one module a script calls,
`Eab.Factory`, and a wrapper, `bin/factoryctl`; the engine's own controls get a second round.

## What changed

- **The second round** (change 8), in `Eab.Grader.qualify/3` (`lib/eab/grader.ex`): after a first round that holds,
  the unchanged project and the reference are graded again in fresh containers (two more calls of `grade/4`), and the
  new `second_round/4` compares every named test of the existing tests, the hidden tests and the regression step, and
  each control's verdict, with the first round. This is the strict rule; all 16 checked ex338 tasks of the pilot met
  it (`docs/data/2026-11-12_pilot_tasks_ex338_r2/`). A task whose outcomes moved is not valid, and the saved controls
  carry `second_round` with the tests that changed (`<control>/<step>: <test>: <before> -> <after>`). Because it is in
  `qualify/3`, it holds for every check and for the controls a run repeats before its first attempt. The grading of
  one patch (`factory/README.md` 2.2) is not touched.
- **The entry points** (change 5), in the new `lib/eab/factory.ex`: `import/2`, `check/2`, `export/2`, `start_run/4`,
  `kept_sessions/1`, `status/0`, `job/1`, and `cli/1`, which `bin/factoryctl` calls through the release's `rpc`
  command. `check/2` runs the sequence of the pilot's gate script (`docs/data/2026-11-12_pilot_tasks_ex338_r2/run/gate.exs`)
  in a background job, on a copy of each task: the import check, the source check, the preparation, the probe
  (`Eab.BundleProbe.finish/4`, called as it stands), the same three again, and the controls with their second round.
  A task that passes replaces its folder with the probed copy; a dropped task stays as it was. One result per task is
  written as it finishes. How to call each one: `factory/README.md`, section 9.
- `lib/eab/candidates.ex`: the limits on a folder's files moved into `files!/1`, which `import/1` and
  `Eab.Factory.import/2` both call.
- `Dockerfile`: one line, `COPY config/holdout.json`, so that `import` in the controller can read the hold-out list.
- Tests: `test/eab/factory_test.exs` (6 tests), `test/eab/factory_docker_test.exs` (1 test, Docker only), one new test
  in `test/eab/grader_test.exs`. No test was weakened or removed; the parity test is not edited.

## What the tests cover

| Entry point | Test | How |
|---|---|---|
| `import/2` | `factory_test` "import copies valid task folders and refuses ..." | six folders of made-up tasks: one imported, one `unchanged`, and the refusals `exists_with_other_bytes`, `holdout` (a repository of the bench's organisations), `import_check` (a missing file) and `folder_not_named_by_id` |
| `check/2` | `factory_test` "check runs the gate in a background job ..." | three made-up tasks with the steps that need Docker replaced: one checked (its folder becomes the probed copy), one dropped at `second_round` by a made-up unstable test (a starting failure that passes when graded again; the result names it), one dropped by the probe |
| `check/2` | `factory_docker_test` | two made-up tasks with the real probe and the real controls, second round included; only the source check and the preparation are replaced (the made-up repositories do not exist; the image is built from the tooling image). Both are checked, with `second_round.same` |
| second round | `grader_test` "the second round of controls names every test ..." | `Grader.second_round/4` on made-up grades: the same results, a made-up unstable hidden test, and an existing test gone with the reference's verdict |
| `export/2` | `factory_test` "export copies checked tasks ..." | a checked task is copied with `results.tsv`, an unchecked one refused (`not_checked`), a task changed after its check refused (`changed_since_check`) |
| `start_run/4` | `factory_test` "start_run refuses a task without a statement ..." | refused before the model server is asked; a task with a statement starts a run against a stand-in endpoint, with the runner replaced (a teacher run against a stand-in model server is job T10) |
| `kept_sessions/1` | `factory_test` "kept_sessions lists ..." | a made-up finished run with sealed receipts: one kept, one failed, one error, one whose grade changed after sealing (listed as `unverified`) |
| `status/0`, `cli/1` | `factory_test` "status says which jobs run ..." | a running check is listed with its progress, a second check of its task is refused, `cli(["status"])` prints the same as JSON |

## Commands (the tooling image, on the build machine)

```
WORK=$PWD LABEL=pascal-quants=1 run/checks.sh t9c    # format check, unit tests, tests with EAB_DOCKER_TESTS=1
WORK=$PWD run/compare.sh t8_unit t8_docker t9c_unit t9c_docker > tests_compared.tsv
```

`run/checks.sh` is job T4's (`docs/data/2026-11-12_factory_t4/run/`); `test.sh`, `docker_shim.sh`,
`t0_formatter.exs` and `compare.sh` are job T0's (`docs/data/2026-11-12_factory_t0/run/`), all unchanged; no new
script. The tests run with `mix test --warnings-as-errors`. Jobs T7 and T8 landed while this one ran, so it ran the
checks three times: `t9` on the tree of the reference on `main` when it started (P5 r2's last run, `r2c`), `t9b`
after the rebase onto T7 (against T7's final run, `t7c`), and `t9c` after the rebase onto T8, the pushed tree
(against T8's run, `t8`). `tests_compared.tsv` is `t9c` against `t8`.

## Counts

| | P5 r2 (`r2c`) | `t9` | T7 (`t7c`) | `t9b` | T8 (`t8`) | `t9c` (pushed) |
|---|---|---|---|---|---|---|
| format check | passes | passes | passes | passes | passes | passes |
| without Docker: passed, failed, excluded | 189, 0, 5 | 196, 0, 6 | 193, 0, 6 | 200, 0, 7 | 198, 0, 8 | 205, 0, 9 |
| with `EAB_DOCKER_TESTS=1` | 194, 0, 0 | 202, 0, 0 | 199, 0, 0 | 207, 0, 0 | 206, 0, 0 | 214, 0, 0 |

In each comparison the same 8 tests are new (6 in `factory_test`, 1 in `factory_docker_test`, excluded without
Docker, 1 in `grader_test`) and every other test ends as in the reference: 194 against `r2c`, 199 against `t7c`, 206
against `t8` (`tests_compared.tsv`, 215 lines with the header). None differs, none is gone. `bench_parity_test`
passes 6 of 6 in every run and is not edited by this job.

Free space on `/` of the build machine: 646,171,283,456 bytes before (04:30:00), 636,741,484,544 after (04:58:28);
other jobs ran at the same time.
