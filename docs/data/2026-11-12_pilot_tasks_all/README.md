# Every candidate the toolchain resolver serves, made and checked (2026-11-12)

Registry rows [E68](../../../experiments.md) and [E72](../../../experiments.md). With the resolver of
[2026-11-12_maker_toolchain](../2026-11-12_maker_toolchain/README.md), the bundle maker serves 64 of
podlove/radiator's 105 screened candidates and 31 of axelclark/ex338's 305. This run made and checked them, radiator
first, through the same controller (`elixir-task-factory:e72`, built from the resolver's commit) and the same
scripts as that job's proofs. Everything ran on the CPU of the 7-GPU machine on 2026-11-12 between 05:26 and 07:18
(UTC+1), while other jobs used the same Docker daemon. No pull request started after 07:15.

## Result

| Repository | Candidates served | Tried | Checked | Dropped | Not tried (time bound) |
|---|---:|---:|---:|---:|---:|
| podlove/radiator | 64 | 64 | **27** | 37 | 0 |
| axelclark/ex338 | 31 | 12 | **7** | 5 | 19 |

**Where they were dropped** (`summary.tsv`; README section 4 of the factory names the checks):

| Check | Reason | radiator | ex338 | Whose |
|---|---|---:|---:|---|
| the maker | `no_existing_tests`: no existing test file is changed or matches a changed code file | 3 | 0 | the pull request |
| prepare | the image cannot install Hex: OTP 27.2's `ssl` rejects the certificate of builds.hex.pm (`key_usage_mismatch`); all 4 pull requests of the pairs 1.18.1/27.2 and 1.18.2/27.2 | 4 | 0 | ours (the image table) |
| the probe | `start_run_did_not_finish`: the hidden tests do not compile on the unchanged project (they use a module or struct the fix adds) | 9 | 1 | the pull request |
| the probe | `reference_run_did_not_finish`: ex338 #1331, checked in the proofs; both diagnostic runs finished here (57 passed on the reference) | 0 | 1 | most likely a flaky run under load |
| the probe | `no_starting_failure`: no hidden test fails in its body before the fix | 5 | 1 | the pull request |
| the probe | `no_existing_tests`: every named existing file fails, or does not finish, on one side | 10 | 1 | mostly the pull request (it changes those tests); 3 possibly the load (below) |
| the controls | `reference_existing_tests_fail`: every test passed, but a skipped test fails the grader's existing-tests step | 3 | 0 | ours (the probe; fixed, below) |
| the controls | `starting_failures_differ` (ex338 #1307) | 0 | 1 | the project (a test that changes between runs) |
| the controls | "Workspace command failed" with no output, in the gate's own preparation or controls; all 3 pull requests of the pair 1.18.3/27.3 in radiator | 3 | 0 | not known |

**By toolchain period** (`by_period.tsv`): radiator 1.17.2/27.0.1 (its 2024 rewrite) gave 19 of 32 checked;
1.19.5/28.4.1 2 of 2; 1.15.7/26.0.2 2 of 5; 1.20.3/29.0.5 2 of 6; 1.16.2/26.0.2 1 of 6; 1.16.3/26.2.5 1 of 1;
1.19.2/28.1 0 of 4 (3 `no_starting_failure`); 1.18.x 0 of 7 (above). ex338 1.16.1/26.2.1 gave 7 of 12; its 19
pull requests of 1.17.2/27.0.1 (2) and 1.18.3/27.3 (17) were not tried before 07:15. Job P5 had checked 16 of
ex338's 1.18.3/27.3 pull requests with the hand-written recipe; they are kept apart (below).

**Concurrency.** The gate started with 5 pull requests at once. Under the machine's load (load average 11) two
pull requests failed with database time-outs ("connection not available and request was dropped from queue after
2999ms"): radiator #541 and #542. The run was stopped at 05:40 and went on with 3 at once; #541 and #542 were run
again and both became checked tasks (#542 was also checked in the proofs). Of the other 8 pull requests that had
ended at 5 at once, 3 were compile errors before the fix and 2 were checked; #521, #523 and #525 ended as
`no_existing_tests` with files that failed or did not finish, and #521's diagnostic run shows the same database
time-out, so those three may be the load's; they were not run again (after the time bound). ex338 #1331 (above) may be the same.

**The fixes from these lists:**
- **The probe** (`lib/eab/bundle_probe.ex`, `settle/4`) kept an existing test file with a skipped test, but the
  grader passes the existing-tests step only when every test passed or was excluded by a permitted tag (README
  section 2.2). A skipped test now leaves its file out, as `skipped_on_unchanged` or `skipped_on_reference`; one new
  case in `bundle_maker_test`. This run's controller predates the fix, so radiator #599, #601 and #603 were dropped
  at the controls; with the fix their files with the skipped test would be left out by the probe.
- **The image table:** the two OTP 27.2 pairs were removed (`config/toolchain_images.json`, with the reason in its
  note), so those commits are now refused as `no_image:1.18.1/27.2` and `no_image:1.18.2/27.2`; `toolchain_test`
  checks that no OTP 27.2 pair is in the table. No other line was needed: both lists resolved with the 14-pair
  table of the proofs.

### Time and disk (rough planning figures)

- **Wall time:** 76 pull requests tried in 111 min (05:26 to 07:17), 34 checked tasks, about 3.3 min of wall time
  per checked task with 3 at once (est.).
- **Steps of a checked task**, means over the 27 of radiator and the 7 of ex338 (columns `prepare_s` to `total_s`
  of the two task tables): radiator prepare 77.3 s, probe 99.1 s, controls 66.2 s, second round 44.1 s, in all
  307.3 s; ex338 76.4 s, 83.5 s, 51.1 s, 55.4 s, in all 283.0 s. Most commits reused a build seed of an earlier
  commit of the same period.
- **Disk:** free on `/` fell from 634,110,418,944 bytes (05:24) to 603,030,773,760 (07:18): 31.1 GB for 76 pull
  requests with other jobs running, about 0.9 GB per checked task (est.). Six `hexpm/elixir` bases were pulled by
  digest (`docker image inspect` sizes): 1.15.7/26.0.2 80,172,180 bytes, 1.16.2/26.0.2 80,561,772, 1.17.1/26.2.5
  80,885,531, 1.18.1/27.2 80,472,058, 1.18.2/27.2 80,492,708 and 1.19.2/28.1 82,681,052; the engine built a
  toolchain, workspace and database image per period and commit as in the proofs.

## Files

| File | What it holds |
|---|---|
| `tasks_radiator.tsv`, `tasks_ex338.tsv` | one line per pull request: the resolved toolchain, made, source check, import, prepared, hidden tests on the unchanged project (failing in their body, and all counts) and on the reference, the partial fix, each control (accepted or rejected), the second round, the verdict or the check it was dropped at and why, the files of its existing-tests command and those left out, the time of each step |
| `summary.tsv` | per repository: checked, dropped by check and reason, not tried |
| `by_period.tsv` | per repository and toolchain pair: tried, checked, dropped, not tried, the drops by cause |
| `run/` | `pool.sh` (the chain), `pool_table.sh` (the task tables); the controller and the gate are [the proofs' scripts](../2026-11-12_maker_toolchain/run/) |

The checked task folders are kept on the build machine, not published.

## Exact commands

On the build machine, with the work folder of [the proofs](../2026-11-12_maker_toolchain/README.md) (`JOB_ROOT`
with `src/`, `tables/`, `run/` holding that folder's scripts and this one's), the controller's folder `CTL`, and
`JOB_ROOT/radiator-pool/numbers.txt` and `JOB_ROOT/ex338-pool/numbers.txt` made from the `resolved` lines of the
proofs' `resolve` runs (`resolve_radiator.tsv`, `resolve_ex338.tsv` there):

```sh
WORK=$CTL NAME=factory-e72 IMAGE=elixir-task-factory:e72 EPMD_PORT=4472 run/controller.sh up
JOB_ROOT=$JOB_ROOT WORK=$CTL NAME=factory-e72 P5_CONCURRENCY=5 P5_DEADLINE=$(date -d 07:15 +%s) \
  P5_MIN_FREE=566000000000 run/pool.sh
# stopped at 05:40 (controller.sh down, the controller's own containers removed); radiator's remaining ids, with
# #541 and #542 again, written to CTL/factory-e72/data/radiator-pool/ids.txt; the controller started again
JOB_ROOT=$JOB_ROOT WORK=$CTL NAME=factory-e72 P5_CONCURRENCY=3 P5_DEADLINE=$(date -d 07:15 +%s) \
  P5_MIN_FREE=566000000000 run/pool.sh resume
WORK=$CTL NAME=factory-e72 run/controller.sh down
run/pool_table.sh $CTL/factory-e72/data/radiator-pool $CTL/factory-e72/data/radiator-all/out/resolve.tsv > tasks_radiator.tsv
run/pool_table.sh $CTL/factory-e72/data/ex338-pool $CTL/factory-e72/data/ex338-all/out/resolve.tsv > tasks_ex338.tsv
```

The gate (`gate.exs`) starts no pull request after `P5_DEADLINE` or with less than `P5_MIN_FREE` bytes free; such
a pull request's row says `not_tried` and why.

## Tests

After the two fixes, on the tree rebased onto `origin/main` (with T10, E71 and P6), against that `origin/main` run the
same hour: format check passes; without Docker 231 passed, 0 failed, 10 excluded (reference the same); with Docker
241 passed, 0 failed (reference the same); all 241 tests end as in the reference. The fixes add one case to the
settling test of `bundle_maker_test` and one assertion to `toolchain_test`, so the counts do not change. The parity
test passed 6 of 6 and was not edited; no file of README section 2 changed.

## Provenance and licence

The pull requests and their code are podlove/radiator's and axelclark/ex338's (MIT, as the tasks' `licence` field
reads it); the tables hold their numbers, the versions read from their files and test file names.
