# The bundle maker, proved on three pull requests of ex338 (2026-11-12)

Job P4 of the [task factory](../../research/notes/task_factory_on_the_bench_engine.md) (section 9), for registry row
[E68](../../../experiments.md). The bundle maker turns one screened pull request into one task folder in the one
format (`schema_version: 3`), or refuses it with a reason. How it works and what it refuses is in the
[factory's README](../../../factory/README.md), section 3.5. Everything ran on the CPU of the 7-GPU machine, in the
tooling image `eab-tooling:dev` that job T0 built, on 2026-11-12 between 02:36 and 02:53 (UTC+1). The project was not
prepared and its tests were not run: that is the next job.

## Result

- **The maker made all three task folders,** and each passes the engine's source check and its import check:

  | Pull request | Kind of pull request | Task | Code files | Test files | Hidden test names | `task_kind` | Partial fix | Source check (`Eab.Provenance.verify/3`) | Import (`Eab.Candidates.import/1`) |
  |---|---|---|---:|---:|---:|---|---|---|---|
  | [#1460](https://github.com/axelclark/ex338/pull/1460) | 2 to 5 code files (rank 1 of `candidates_first.tsv`) | `ex338-pr-1460` | 5 | 1 | 16 | `feature` | the first variant | passed | accepted |
  | [#1463](https://github.com/axelclark/ex338/pull/1463) | one code file | `ex338-pr-1463` | 1 | 1 | 1 | `bug_fix` | the first variant | passed | accepted |
  | [#1394](https://github.com/axelclark/ex338/pull/1394) | adds a migration | `ex338-pr-1394` | 5 (4 in `lib/`, 1 migration) | 1 | 2 | `feature` | the first variant | passed | accepted |

  All three are squash merges: the starting commit is the merge commit's first parent, and its difference changes
  exactly the census's paths (no walk back). None changes a documentation file, so no task has
  `upstream-docs.patch`. The licence read at each starting commit is MIT.
- **The test names and the partial fix are a first reading,** from the diff, because the format needs both before
  any run: the tests whose body the pull request adds or changes, and the reference with its first file (or, for
  #1463, its first hunk) left out. `Eab.BundleProbe.finish/4` replaces both with what runs observe once the project
  is prepared. It was tested on the made-up tasks, not on these three.
- **The recipe is job P3's** (`factory/recipes/axelclark__ex338.json`,
  [2026-11-12_pilot_env_ex338](../2026-11-12_pilot_env_ex338/README.md)), with both images pinned by digest. All
  three starting commits name Elixir 1.18.3 and Erlang 27.3 in `.tool-versions`, the period that recipe was proved
  on. A first round (02:37) ran with a provisional recipe this job wrote from the project's files, before P3's
  landed; it made the same three folders, which passed both checks too. When P3's recipe landed, the maker was
  changed to accept its `grading.test_suffixes` (the fixed `["_test.exs"]`), the provisional recipe was dropped, and
  the three folders were made and checked again (02:53). The tables here are from that second round.
- **The factory's checks:** the format check passes, and the project compiles with warnings as errors. Every test
  ends as in job T5's runs, and the 8 new tests pass:

  | Run | Passed | Failed | Excluded | T5 |
  |---|---:|---:|---:|---|
  | `MIX_ENV=test mix test --warnings-as-errors` | 201 | 24 | 8 | 194, 24, 7 |
  | the same with `EAB_DOCKER_TESTS=1` and the Docker socket | 207 | 24 | 2 | 199, 24, 2 |

  The 24 failures are T5's, unchanged (22 need tasks in the inventory, job T6; 2 are in `claude_code_test`, which
  goes in T2). The new tests: 7 in `test/eab/bundle_maker_test.exs` (a squash merge made, checked by the engine's
  source check on a local repository and imported; a rebase merge walked back two first parents; the refusals; the
  test names; the variants; observing and searching on made-up runs; the hold-out list and the recipe's fields), and 1
  in `test/eab/bundle_probe_docker_test.exs` (the names observed and the partial fix searched on the two made-up
  ledger tasks in containers, after which both pass the engine's controls). The parity test passes 6 of 6, untouched.
- **Disk:** free on `/` 665,987,051,520 bytes before the job (02:31) and 660,172,935,168 after (02:53); other jobs
  ran on the machine at the same time, and this job's work folder holds 66,314,240 bytes (its copy of the factory
  with Mix's files, the fetched commits, the task folders of both rounds and the logs).

## The result lines

[results.tsv](results.tsv), one line per pull request, as `make` wrote it:

```text
repository	number	id	result	reason	start_revision	walked	code_files	test_files	docs_files	hidden_tests	task_kind	partial	licence	recipe	detail
https://github.com/axelclark/ex338	1460	ex338-pr-1460	made	-	a502f92e38a4b6286e6db51d7771c10899cf635c	0	5	1	0	16	feature	first_variant	MIT	final	-
https://github.com/axelclark/ex338	1463	ex338-pr-1463	made	-	345e0c7e015b8e93c0cc23277152a35db35e675e	0	1	1	0	1	bug_fix	first_variant	MIT	final	-
https://github.com/axelclark/ex338	1394	ex338-pr-1394	made	-	f846028ad8b2641da1814ff519cefc65482656a1	0	5	1	0	2	feature	first_variant	MIT	final	-
```

[verify.tsv](verify.tsv), as `verify` wrote it (task, source check, import with the stored version):

```text
ex338-pr-1394	passed	accepted 947e9d8767019e85da4fac307abaab0b9fe2b5f18223bfab892ca5fd86785b0b
ex338-pr-1460	passed	accepted f2abac5eb646d929251dde70c0c8e124df948dde4abbdfc13ce63a84c156e40c
ex338-pr-1463	passed	accepted 91a2d24785978114d41a722f21efc0634e871849428a155969b6143621a0ace9
```

## Files

| File | What it holds |
|---|---|
| `results.tsv` | the maker's result line for each of the three pull requests |
| `verify.tsv` | the source check and the import check for each task folder |
| `tests_compared.tsv` | every test of both runs, its state in job T5's run and in this job's (`absent` for a test that is not in that run) |
| `tasks/<id>/` | the three task folders as the maker wrote them: `case.json`, `provenance.json`, `reference.patch`, `reference-tests.patch`, `integrity.patch`, `incomplete.patch` (each file under 15 KB) |
| `run/sync.sh` | copies the factory folder, this `run/` folder and the census and screen tables to the build machine |
| `run/make.sh` | runs the maker (`make`) or the source and import checks (`verify`) in the tooling image |
| `run/make_tasks.exs` | the script `make.sh` runs with `mix run` |
| `run/checks.sh` | the format check and the tests, without and with Docker, with job T0's `test.sh` |

## Exact commands

On the editing machine:

```sh
HOST=<build machine> WORK=<work folder> docs/data/2026-11-12_pilot_bundle_maker/run/sync.sh
```

On the build machine, after copying job T0's `test.sh`, `docker_shim.sh` and `t0_formatter.exs`
([2026-11-12_factory_t0/run/](../2026-11-12_factory_t0/README.md)) into `WORK/run/` and Mix's folder `.local/` from an
earlier work folder into `WORK/src/`:

```sh
cd "$WORK"
WORK=$PWD LABEL=pascal-quants=1 CENSUS=prs_axelclark__ex338.tsv SCREEN=screen_axelclark__ex338.tsv TAG=p4_make2 \
  run/make.sh make --repository https://github.com/axelclark/ex338 --numbers 1460,1463,1394
WORK=$PWD LABEL=pascal-quants=1 TAG=p4_verify2 run/make.sh verify
WORK=$PWD LABEL=pascal-quants=1 run/checks.sh p4c
```

`make.sh` runs the container with the network, because the maker fetches each merge commit and its first parent by
id from GitHub, and the source check fetches both again. The containers carry the label and a CPU share of 256.

## How the three were chosen

`candidates_first.tsv` lists only pull requests with 2 to 5 code files and no migration, so it holds the first kind
only. #1460 is its rank 1. The other two are the newest candidates of their kind in
[the screen's table](../2026-11-12_pilot_pr_screen/screen_axelclark__ex338.tsv): #1463 (one code file) and #1394
(`adds_migration`).

## Provenance and licence

- The merge commits and changed paths are the census's
  ([2026-11-11_pilot_pr_census](../2026-11-11_pilot_pr_census/README.md)); the verdicts and marks are the screen's
  ([2026-11-12_pilot_pr_screen](../2026-11-12_pilot_pr_screen/README.md)).
- The commits were fetched by id from <https://github.com/axelclark/ex338>, the only download of this job.
- The task folders' patches are the project's code and tests, under its MIT licence (copyright Axel Clark, the
  `LICENSE` file at each starting commit). The manifests, the provenance records and the early-exit patch are written
  by the maker; no statement was written.
