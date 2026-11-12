# ambry-app/ambry in the task factory: the project's set-up and 20 checked cases (2026-11-12)

Registry rows [E68](../../../experiments.md) (the pilot of the task factory) and E82 (newest Elixir first, from alive
applications). ambry is one of the dataset's 16 applications ([the list](../2026-11-12_dataset_projects/README.md)).
Its newest usable pull requests were checked as cases, one at a time, on the data-mining machine on 2026-11-12 (UTC+1),
in two jobs on one controller of their own, while other case jobs, a check job and a teacher run used the same Docker
daemon:

- **the first job** (13:16 to 14:27): the set-up, the project's own suite and 3 checked cases, on a controller built
  from the factory's `main` at `772f3bd`;
- **the second job** (14:36 to 19:07): toward 15 cases, then 20 (the owner, 16:10: "I would do 20 each because there
  could be more issues / unsolved"), on the same controller (name, node, data folder) rebuilt twice: at 14:38 from
  `main` at `0d99a67` (each service image under a tag of its own installation), and at 16:39 from `014fbe9`, which adds
  a bare program as a release file (section 6) so that ambry's recipe can install `shaka-packager` (the owner, 16:25:
  "I think we can add this program to the docker image for ambry's tests").

## Result

- **20 cases are checked, and all 20 pass the licence scan and the hold-out check:** 18 features and 2 bug fixes
  (pull requests 1235 and 1234). They come from 44 pull requests tried (50 tries), newest merged first.
- **The project's set-up:** the recipe
  ([`factory/recipes/ambry-app__ambry.json`](../../../factory/recipes/ambry-app__ambry.json)) needs Elixir 1.20.2 with
  OTP 29.0.4, Postgres 18.6, the distribution package `ffmpeg`, and since 16:39 `shaka-packager` 3.4.2 as a release
  file. Every checked case is built on 1.20.2 / 29.0.4.
- **The project's own suite passes** at two starting commits: pull request 1290's, **2,157 passed, 0 failed, 1
  skipped, in 91.0 s**; and pull request 1263's, the first with `shaka-packager` in the image, **1,738 passed, 0
  failed, 1 skipped, in 69.9 s**.
- **Of the 24 pull requests left out:** 15 are the pull request's own cause; 2 are probably the pull request's (the
  same timed test failed in both tries); 3 are not settled after two tries; 4 are probably the machine's and were not
  run again. The first job's one drop caused by the factory (1284, a shared image tag) passed on its second try.
- **What is left:** 45 older candidates are ready and were not reached (the job stopped at 20); 3 are left out by the
  rules (two on OTP 27.2, one on Elixir 1.16).
- **One finding about the project's tests:** a family of LiveView tests that wait for background work with
  `render_async` (its default limit, 100 ms), most of them in the inbox form's test file, failed now and then on the
  busy machine. Eight of the 24 drops trace to them (section 2).

## 1. The project's set-up

| What | Value | Where it comes from |
|---|---|---|
| Elixir / OTP | 1.20.2 / 29.0.4, image `hexpm/elixir:1.20.2-erlang-29.0.4-ubuntu-noble-20260730.1` (pinned by digest) | `.tool-versions`, read by the toolchain resolver; the image table's line (E84) |
| Database | Postgres 18.6 (`postgres:18.6-alpine`, pinned) | the CI file starts `postgres` with no version, so the recipe's default |
| Other services | none | no Redis client in `mix.exs`; CI starts only Postgres |
| System packages | `ffmpeg` (`runtime.packages`) | CI installs it (`AnimMouse/setup-ffmpeg`); the application reads audio files with `ffprobe` (`lib/ambry/media/`) |
| Release file | `shaka-packager` 3.4.2: `packager-linux-x64` from the project's GitHub release page, installed as `/usr/local/bin/shaka-packager` (kind `bin`) | CI and the project's Dockerfile download that file to that path; up to pull request 1263 the application calls it (`lib/ambry/media/processor/shared.ex`) |
| Database set-up | `mix ecto.create --quiet`, `mix ecto.migrate --quiet` | the project's `ecto.setup` alias |
| Whole-suite command | `mix test` | `grading.preservation`; the project's `test` alias creates and migrates the database first |
| Licence | MIT (`LICENSE` at every starting commit) | |

**The release file.** `https://github.com/shaka-project/shaka-packager/releases/download/v3.4.2/packager-linux-x64`,
9,426,208 bytes, SHA-256 `7bdefe5a25fe84535c6c1a425f4c3c6b65fa85c441c2aeba01254b3c0f4b1956`. The release publishes
no checksum file and GitHub shows no digest for this asset (it predates them), so the checksum was computed from the
one download; the size equals the one GitHub lists. The download redirects to `release-assets.githubusercontent.com`;
the controller allows exactly `github.com` and that host (`EAB_RELEASE_FILE_HOSTS`). The file was fetched once and
put into the controller's store under its checksum, where the engine found and reused it ("Reusing release file");
the image build checks the checksum again. In the built image, `shaka-packager --version` prints
`packager version v3.4.2-c819dea-release`. The program's licence is a BSD 3-clause licence (Google LLC, its `LICENSE`
at `v3.4.2`); it is a tool in the test image only and is not part of any case.

**What the build fetches by itself.** Beside the Hex packages, the project's own dependencies fetch four things during
`mix deps.get` and `mix compile`, with no change to the recipe: the git dependency `boundary` (pinned by `mix.lock`),
and three prebuilt native libraries from their GitHub release pages (`mdex_native` through `rustler_precompiled`;
`lazy_html` and `vix` through `elixir_make`, `vix`'s with `libvips`).

### The project's own tests

One run of the whole suite at each of two starting commits, through the engine's own runner, in a fresh workspace
container with a fresh database and no network:

| Starting commit of | Image | ExUnit | Failed | Skipped | ExUnit time | Engine time | Prepared in | Table |
|---|---|---|---:|---:|---:|---:|---:|---|
| pull request 1290 | without `shaka-packager` | 2,157 passed (8 doctests, 2,149 tests) | 0 | 1 | 91.0 s | 92.4 s | 163.7 s | `project_tests.tsv` |
| pull request 1263 | with `shaka-packager` | 1,738 passed | 0 | 1 | 69.9 s | 73.8 s | 142.3 s | `project_tests_1263.tsv` |

- **No test fails at either commit.** The engine's own verdict is "not passed" only because of the one skipped test,
  a test of `test/ambry/people_test.exs` that the project marks `@tag :skip`: the grader passes no skipped test
  (`factory/README.md`, section 2.2). A case whose hidden tests include it is dropped as `skipped_test` (three were).
- Both preparations were cold for their toolchain (1263's because the release file changes the image's recipe); every
  case after each was seeded from that build.

## 2. The cases

The candidates are the screening's for this project
([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)), with the images the resolver
gives them since E84 ([2026-11-12_newer_elixir_versions](../2026-11-12_newer_elixir_versions/README.md)): 92 since
2024. They were taken newest merged first, one at a time: the bundle maker with the resolver (`make_one.exs`),
`factoryctl import`, `factoryctl check` with one task at a time, then `factoryctl export` of a checked task.

The order of the work:
1. the first job: pull requests 1290 back to 1281 (9 tried, 3 checked);
2. 1284 again (its first try was lost to the factory's shared tag): checked;
3. the 13 candidates that needed nothing more (1280 back to 1265, and 1013): 4 checked;
4. second tries of four whose drop pointed to the machine or could not be read (1280, 1277, 1276, 1013): none checked;
5. with `shaka-packager` in the recipe, the older candidates from 1263 backwards: 22 tried (1263 back to 1224), 12
   checked; the driver tried 1230 a second time by its own rule (its first try ran with the load over 12). The job
   stopped at 20 checked.

`cases_ambry.tsv` holds one line per try (50 tries of 44 pull requests), with the merge date, Elixir/OTP, kind,
verdict, step, reason, whose cause (`whose.tsv`), the wall time of each step, the engine's step times, the load, the
job's own images and the machine's disk change. `counts.tsv` counts the pull requests by their last try:

| Pull requests | Verdict | Step | Reason |
|---:|---|---|---|
| 20 | checked | | |
| 6 | dropped | probe | `start_run_did_not_finish` |
| 4 | dropped | probe | `reference_fails_hidden` |
| 3 | dropped | second round | `unstable` |
| 3 | dropped | probe | `skipped_test` |
| 2 | dropped | probe | `no_starting_failure` |
| 1 | refused | maker | `patch_over_1_mib` |
| 1 | refused | maker | `no_test_part` |
| 1 | refused | maker | `no_test_names` |
| 1 | refused | maker | `no_existing_tests` |
| 1 | dropped | probe | `no_existing_tests` |
| 1 | dropped | controls | `starting_failures_differ` |

**Whose cause, by each pull request's last try** (`whose.tsv`, written from each drop's detail):

| Whose | Pull requests | What |
|---|---|---|
| the pull request's | 15: 1290, 1289, 1288, 1287, 1269, 1268, 1267, 1266, 1265, 1263, 1260, 1259, 1250, 1242, 1240 | hidden tests that already pass (2); features whose tests call code the fix adds, so they cannot compile before it (5); the skipped test among the hidden tests (3); no test file, no changed test body, or no existing test left to protect (4); a patch over 1 MiB (1) |
| probably the pull request's | 2: 1277, 1230 | the same timed test failed on the reference fix in both tries |
| not settled | 3: 1280, 1276, 1013 | two tries, each failing in another place: for 1280 and 1276 a different timed test each time; for 1013 a run that did not finish, once on the reference fix and once on the unchanged project (the probe keeps no output, registry E80) |
| probably the machine's | 4: 1286, 1241, 1238, 1236 | a timed test that ended differently between rounds or failed once; 1286 was not run again by this job's brief, the other three because 20 cases were checked first |

**The timed tests.** ambry's LiveView tests wait for background work with `render_async`, whose default limit is
100 ms. On the busy machine (other case jobs, a check job and a teacher run beside this one; the 1-minute load up to
17.05 on 28 threads), such a test sometimes ran past its limit: "expected async processes to finish within 100ms" on
1280's reference fix, while the same test passed in ten other runs of the same check. Eight of the 24 drops trace to
tests of this kind (1286, 1280, 1277, 1276, 1241, 1238, 1236, 1230), seven of them in
`test/ambry_web/live/admin/inbox_live/form_test.exs`; in several checked cases the engine also left that file out of
the existing tests as failing on the reference. A quieter machine would likely settle some of these drops; a longer
limit would be a change to the project's own tests, which a case does not make.

**The 20 checked cases** (`checked_cases.tsv`; the exported folders are in the project's task folder on the
data-mining machine, `WORK/tasks/ambry-app__ambry/`):

| Case | Merged | Kind | Hidden tests required | Fail before the fix | Existing-test files kept | Left out | Partial fix | Marks |
|---|---|---|---:|---:|---:|---:|---|---|
| `ambry-pr-1284` | 2026-08-22 | feature | 72 | 2 | 3 | 0 | present | `adds_migration`, `ai_written` |
| `ambry-pr-1283` | 2026-08-22 | feature | 129 | 4 | 3 | 0 | present | `ai_written` |
| `ambry-pr-1282` | 2026-08-22 | feature | 22 | 11 | 3 | 0 | present | `adds_migration`, `ai_written` |
| `ambry-pr-1281` | 2026-08-21 | feature | 16 | 2 | 5 | 0 | present | `touches_assets`, `ai_written` |
| `ambry-pr-1279` | 2026-08-21 | feature | 34 | 6 | 3 | 1 | present | `touches_assets`, `ai_written` |
| `ambry-pr-1275` | 2026-08-20 | feature | 48 | 12 | 3 | 0 | present | `ai_written` |
| `ambry-pr-1274` | 2026-08-20 | feature | 65 | 3 | 4 | 0 | present | `adds_migration`, `ai_written` |
| `ambry-pr-1272` | 2026-08-19 | feature | 289 | 32 | 6 | 0 | present | `ai_written` |
| `ambry-pr-1261` | 2026-08-17 | feature | 38 | 17 | 7 | 1 | present | `ai_written` |
| `ambry-pr-1243` | 2026-08-15 | feature | 161 | 1 | 1 | 0 | present | `touches_assets`, `ai_written` |
| `ambry-pr-1237` | 2026-08-13 | feature | 469 | 119 | 6 | 5 | present | |
| `ambry-pr-1235` | 2026-08-13 | bug fix | 106 | 9 | 4 | 6 | present | `ai_written` |
| `ambry-pr-1234` | 2026-08-13 | bug fix | 142 | 2 | 8 | 2 | present | `ai_written` |
| `ambry-pr-1233` | 2026-08-13 | feature | 143 | 45 | 3 | 14 | present | `ai_written` |
| `ambry-pr-1232` | 2026-08-12 | feature | 252 | 43 | 4 | 3 | present | `touches_assets`, `ai_written` |
| `ambry-pr-1231` | 2026-08-12 | feature | 108 | 30 | 3 | 5 | present | `ai_written` |
| `ambry-pr-1227` | 2026-08-11 | feature | 254 | 5 | 5 | 0 | present | `ai_written` |
| `ambry-pr-1226` | 2026-08-11 | feature | 164 | 35 | 4 | 0 | present | `ai_written` |
| `ambry-pr-1225` | 2026-08-11 | feature | 173 | 22 | 8 | 9 | present | `adds_migration`, `touches_assets`, `ai_written` |
| `ambry-pr-1224` | 2026-08-11 | feature | 216 | 7 | 1 | 2 | present | |

"Left out" counts the existing-test files the engine set aside as failing on the reference fix; every case keeps at
least one. Every case has a partial fix that the controls reject. Five passed with the load over 12 during the check
(1231, 1227, 1226, 1225 and 1224; marked "not settled" in `cases_ambry.tsv`): a pass under load stands.

**The kinds.** 18 features and 2 bug fixes. The dataset's balance rule (neither kind under 30 %,
[the rules](../../dataset_rules.md), section 7) is applied across projects, not inside one; ambry adds to the
features' side.

### The rest of the project's candidates

`candidates_ambry.tsv` (all 92 screened candidates since 2024, with what each needs and where it stands):

| Status | Pull requests | Why |
|---|---:|---|
| tried | 44 | above |
| ready, not tried | 45 | 1223 back to 1094: Elixir 1.20.2 / OTP 29.0.4 (37), 1.20.0 / 29.0.1 (1) and 1.19.1 / 28.1.1 (7); each needs `shaka-packager`, now in the recipe. Not reached: the job stopped at 20 checked |
| left out | 3 | 995 (`no_image:1.18.2/27.2.2`) and 966 (`no_image:1.18.1/27.2`): OTP 27.2 is never built; 820: `elixir_before_1.18` (1.16.2) |

## 3. The licence scan and the hold-out check

Run on each checked case, one at a time, with the factory's tools unchanged
([`factory/tools/`](../../../factory/tools/README.md)), in a Python container with no network; the Hex metadata was
fetched with `HEX_FETCH=1`. The slowest case took 31 s.

- **Licence:** all 20 pass. Every starting commit carries the MIT licence file, and all 466 files the cases touch pass
  (`licence_tasks.tsv`, `licence_files.tsv`). The scans of the second job's last 12 cases ran on a newer tool that also
  writes `root_licence` and `root_proof` (`ok:licence-file` for all 12); for the 8 earlier cases these columns are
  `-`.
- **Hold-out:** all 20 pass: the repository is not held out, no held-out name appears, and of the 8- and 12-word runs
  shared with the bench's 20 cases none is to be read (all boilerplate, syntax or the project's own tree;
  `holdout_tasks.tsv`, and `holdout_hits.tsv` with span ids only).
- **Dependencies** (`deps.tsv`: each locked dependency once per version, with the number of cases whose starting
  commit locks it): 96 rows declare an allowed licence by SPDX id; `natural_order` declares "Apache 2.0" (allowed, not
  an SPDX id); the git dependency `boundary` is not read by the tool and carries the MIT licence (its `LICENSE` and
  `mix.exs`, read from the project's built image in the first job). So every dependency is under an allowed licence.
- **A held-out library as a dependency:** ambry depends on `absinthe`, `absinthe_plug` and `absinthe_relay`, the
  bench's held-out project's own packages, and on `dataloader` from the same GitHub organisation. This is allowed for a
  task ([the rules](../../dataset_rules.md), section 4); a session that reads or prints a file of the held-out
  project's own package is dropped as `quotes_held_out` (section 6).

## 4. Time, load and disk

- **Per checked case:** the check took 250 s at the shortest (1282) and 761 s at the longest (1272); the median of
  the 20 is 490.5 s and the mean 498.2 s (every value in `cases_ambry.tsv`, with the engine's own preparation, probe
  and controls times). Making a folder took at most 11 s and an export at most 2 s. With a seeded build, a preparation took
  under a minute; the two cold ones are in section 1.
- **The second job:** 41 tries (35 first tries, 6 second tries) with 14,170 s of checks in all, from 14:38:53 to
  19:00:51; then the scans of the 17 new cases, in two batches (5 at 16:25, 12 from 19:01) and the tables.
- **Load:** the highest 1-minute load during the second job was 17.05 on 28 threads (18:18:11, sampled every 10 s by
  the driver's watcher), never near the stop rule of 26. Seven tries ran with the load over 12 ("not settled"), all
  after 18:10.
- **Disk:** free space on `/` went from 748,751,982,592 bytes (14:36) to 590,571,921,408 bytes (19:07), most of it the
  other jobs'. At the end, 85 images carried this job's label, with 10,526,466,775 bytes that no other image shares
  (Docker's count); the job folder held 445,728,870 bytes, the controller's folder 805,026,988 and the 20 task folders
  3,281,803.

## 5. Faults found, and what was done

- **The factory's shared image tag** (found in the first job): every controller built the database layout image under
  one tag, so controllers on one Docker removed each other's image and a case could fail at `prepare` with "content
  digest … not found". Fixed in the factory at `0d99a67` (each image also under its installation's own tag); the
  controller was rebuilt from it, and pull request 1284 then passed.
- **The probe and the second round keep no output** (registry E80): for 1013 and 1277 the cause could only be read
  from the patches and the result's one-line detail.
- **The job's own scripts:** the first job fixed two faults in the drivers it copied (the driver must run as root to
  read the controller's records; the image list goes to `jq` through a file, not as one argument). This job's tables
  gained a `try` column (`final_tables.sh`) and two scripts (`own_images.sh`, `scan_tables.sh`) for what was done by
  hand before.

## 6. A bare program as a release file (the factory's change at `014fbe9`)

The factory's release files knew one kind, a `.deb` (`runtime.release_files`, `factory/README.md` section 6, change
3). `shaka-packager` is published as a bare program, so the change adds a kind `bin`:

- `factory/lib/eab/task_contract.ex`: a `bin` entry also carries the `name` it is installed under (letters, digits and
  `+ . _ -`, starting with a letter or digit, so it holds no path and no shell; no name twice); a `deb` entry still
  has exactly its three keys.
- `factory/lib/eab/release_files.ex`: a `bin` file is fetched, checked and kept like a `deb`, as `<sha256>.bin`.
- `factory/lib/eab/fixtures.ex`: the same toolchain line checks every file's SHA-256, installs the `deb` files with
  `apt-get`, then copies each program to `/usr/local/bin/<name>` with `install -m 0755`. A line with `deb` files only
  is unchanged, byte for byte.
- Tests: `task_contract_test` (valid and refused programs and names), `fixtures_test` (the line for a program, and for
  a program beside a package), `release_files_test` (one new test: a program fetched through a redirect, checked, kept
  and staged), and `runtime_extras_docker_test`, whose made-up task's image now also gets a self-made program, which is
  then on the path, executable by anyone, and runs.

The factory's own checks on the data-mining machine (`run/code_tests.sh`, with the earlier jobs' `test.sh`): the format
check passes; it compiles with warnings as errors; 246 passed and 10 excluded without Docker, 256 passed with Docker
(`0d99a67`: 245 and 255); the parity test with the bench (`bench_parity_test.exs`, what the model is shown) 6 of 6.
The first run failed the format check for one missing blank line in a test; fixed and run again in full.

## Files

| File | What it holds |
|---|---|
| `project_tests.tsv`, `project_tests_1263.tsv` | the runs of the project's suite at pull request 1290's and 1263's starting commits |
| `cases_ambry.tsv` | one line per try (50): merge date, Elixir/OTP, kind, verdict, step, reason, whose cause, step times, the engine's step times, the load, the job's own images, the machine's disk change |
| `whose.tsv` | whose cause each try's drop is, and why, by case and try |
| `counts.tsv` | the pull requests per verdict, step and reason, by their last try |
| `checked_cases.tsv` | the 20 checked cases: merge date, Elixir/OTP, kind, hidden tests, failures before the fix, existing-test files kept and left out, partial fix, marks |
| `candidates_ambry.tsv` | the 92 screened candidates: Elixir/OTP, the image now, what else they need, where each stands |
| `licence_tasks.tsv`, `licence_files.tsv` | the licence scan: per case, and per touched file |
| `holdout_tasks.tsv`, `holdout_hits.tsv` | the hold-out check: per case, and per shared span (ids only) |
| `deps.tsv` | the locked dependencies of the 20 starting commits, their declared licences and how many cases lock each |
| `run/build.sh`, `run/controller.sh`, `run/state.sh`, `run/watch.sh`, `run/row.sh`, `run/make_one.exs`, `run/make_probe.sh`, `run/prepare.exs`, `run/tests.exs`, `run/suite.sh`, `run/suite_tables.sh` | nerves_hub_web's job scripts of 2026-11-12, unchanged |
| `run/env_tests.sh` | the project's own tests (probe, prepare, suite), with the project as settings |
| `run/one.sh` | one pull request: make, import, check, export; the image list through a file |
| `run/all.sh` | the driver: newest first, until `TARGET` checked or `MAX_TRIED` tried; a second try for a check that was not settled and did not pass, or for the numbers in `RETRY` (`ONLY_RETRY=1`: only those) |
| `run/table.sh` | the per-try table, the counts and the images from the driver's rows |
| `run/own_images.sh` | the job's own images now (Docker's API) and per try |
| `run/final_tables.sh` | `cases_ambry.tsv` (one line per try) and `candidates_ambry.tsv` |
| `run/scan.sh` | the licence scan and the hold-out check, one case at a time |
| `run/scan_tables.sh` | the scan's public tables, merged from the per-case folders |
| `run/code_tests.sh` | the factory's own checks for a code change, in order; with `run/test.sh`, `run/docker_shim.sh` and `run/t0_formatter.exs` (the earlier factory jobs' scripts, unchanged) |

## Commands

On the data-mining machine, as root, in a job folder `$JOB` holding `run/` (this folder's scripts), `src/` (the
factory folder of `main` with the recipe), `tables/` (the census, the screen and the classes table of the screening,
and `resolve_after.tsv`), `numbers.txt` (the numbers to try, newest merged first), `cache/` (a folder holding
`ambry-app__ambry.git`, a clone, for the maker) and `ambry.git` (a full clone); `$CTL` is the controller's folder and
`$WORK` the factory's work folder. The first job:

```sh
SRC=$JOB/src OUT=$JOB/out LABEL=task-factory=1 IMAGE=elixir-task-factory:ambry-20261112 $JOB/run/build.sh controller
CTL=$CTL NAME=factory-ambry SOURCES=$JOB IMAGE=elixir-task-factory:ambry-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-ambry EPMD_PORT=4518 PREPARE_WORKERS=1 PREPARE_AHEAD=1 $JOB/run/controller.sh up
JOB=$JOB OUT=$JOB/out/suite CTL=$CTL NAME=factory-ambry JOB_LABEL=task-factory-job=hb-ambry TASK_LABEL=task-factory=1 \
  DATA=$CTL/data GIT_DIR=$JOB/ambry.git NUMBER=1290 MERGE=d9cc0d78dbf146cb62da3b71c81cc01740571f39 ROUNDS=1 MAX_LOAD=26 \
  $JOB/run/suite.sh
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-ambry CACHE=$JOB/cache $JOB/run/all.sh stage
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-ambry OUT=$JOB/out/cases JOB_LABEL=task-factory-job=hb-ambry \
  TASK_LABEL=task-factory=1 TARGET=3 MAX_TRIED=12 MAX_LOAD=26 $JOB/run/all.sh run
```

The second job (the environment of the driver: `WORK`, `JOB`, `CTL`, `NAME=factory-ambry`, `OUT=$JOB/out/cases`,
`JOB_LABEL`, `TASK_LABEL` as above, `MAX_LOAD=26`, `MIN_FREE=50000000000`):

```sh
# the controller again, from main at 0d99a67 (the same folder, name and port; docker rm of the stopped container first)
SRC=$JOB/src OUT=$JOB/out/build-0d99a67 LABEL=task-factory=1 IMAGE=elixir-task-factory:ambry-20261112-b $JOB/run/build.sh controller
CTL=$CTL NAME=factory-ambry SOURCES=$JOB IMAGE=elixir-task-factory:ambry-20261112-b HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-ambry EPMD_PORT=4518 PREPARE_WORKERS=1 PREPARE_AHEAD=1 $JOB/run/controller.sh up
ONLY_RETRY=1 RETRY=1284 $JOB/run/all.sh run          # numbers.txt: the 21 newest, then 1013
TARGET=15 MAX_TRIED=22 $JOB/run/all.sh run
ONLY_RETRY=1 RETRY="1280 1277 1276 1013" $JOB/run/all.sh run
# the factory's change, checked in a copy of the factory folder ($CODE)
SRC=$CODE OUT=$JOB/out/code-bin IMAGE=etf-tooling:ambry-bin-20261112 LABEL=task-factory=1 \
  HEX_CACHE_ID=etf-hex-packages-v1 $JOB/run/code_tests.sh
# the controller again, from main at 014fbe9, with the release file's two hosts; the recipe staged again
SRC=$JOB/src OUT=$JOB/out/build-bin LABEL=task-factory=1 IMAGE=elixir-task-factory:ambry-20261112-c $JOB/run/build.sh controller
CTL=$CTL NAME=factory-ambry SOURCES=$JOB IMAGE=elixir-task-factory:ambry-20261112-c HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-ambry EPMD_PORT=4518 PREPARE_WORKERS=1 PREPARE_AHEAD=1 \
  RELEASE_FILE_HOSTS="github.com release-assets.githubusercontent.com" $JOB/run/controller.sh up
cp $JOB/src/recipes/ambry-app__ambry.json $CTL/data/ambry/recipe.json
JOB=$JOB OUT=$JOB/out/suite-1263 CTL=$CTL NAME=factory-ambry JOB_LABEL=task-factory-job=hb-ambry \
  TASK_LABEL=task-factory=1 DATA=$CTL/data GIT_DIR=$JOB/ambry.git NUMBER=1263 \
  MERGE=4ea49709b353ccc6818b75ff98f19371fc689606 ROUNDS=1 MAX_LOAD=26 MIN_FREE=50000000000 SUB=env-1263 $JOB/run/suite.sh
D=$CTL/data/env-1263 OUT=$JOB/out/suite-1263 ROUNDS=1 $JOB/run/suite_tables.sh
TARGET=20 MAX_TRIED=89 $JOB/run/all.sh run          # numbers.txt: the 21 newest, the 67 older, then 1013
# the scans, one case at a time, and the tables
SRC=$JOB/src DEST=$WORK/tasks/ambry-app__ambry WORK=$JOB/out/scan-job4 CLONES=$JOB/ambry.git \
  BENCH_SRC=<the bench's cases/ folder> LABELS=task-factory=1,task-factory-job=hb-ambry HEX_FETCH=1 $JOB/run/scan.sh <ids>
OUT=$JOB/out/cases NUMBERS=<the numbers tried> PREFIX=ambry TASKDIR=$CTL/data/ambry/tasks \
  SCREEN_TSV=$JOB/tables/screen_ambry-app__ambry.tsv $JOB/run/table.sh tasks > tasks.tsv
JOB_LABEL=task-factory-job=hb-ambry $JOB/run/own_images.sh now > own_images_now.tsv
OUT=$JOB/out/cases NOW=own_images_now.tsv $JOB/run/own_images.sh tries > own_images.tsv
TASKS=tasks.tsv OWN=own_images.tsv WHOSE=whose.tsv $JOB/run/final_tables.sh cases > cases_ambry.tsv
TASKS=tasks.tsv CLASSES=$JOB/tables/classes_ambry.tsv RESOLVE=$JOB/tables/resolve_after.tsv RELEASE_IN_RECIPE=1 \
  $JOB/run/final_tables.sh ready > candidates_ambry.tsv
OUT=. $JOB/run/scan_tables.sh <the 20 per-case scan folders>
CTL=$CTL NAME=factory-ambry $JOB/run/controller.sh stop
```

The suite's probe reads the project's clone with `git` as root; with the clone owned by another user, the run had
`GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0='*'` in its environment. `checked_cases.tsv`
was made with `jq` from each exported case's `case.json` and `provenance.json`. The release file was fetched once with
`curl -L` into a folder of its own and copied into the controller's store as `release-files/<sha256>.bin`.

## Provenance and licence

ambry is MIT (`LICENSE` at each starting commit, read by the maker and by the licence scan). `shaka-packager` is
under a BSD 3-clause licence (Google LLC) and sits only in the test image. The tables hold pull request numbers, merge
dates, file names, image names, test counts and times. They hold no source code, no pull request text and no test
text.
