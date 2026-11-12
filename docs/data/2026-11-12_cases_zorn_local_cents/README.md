# zorn/local_cents in the task factory: the project's set-up and its checked cases (2026-11-12)

Registry rows [E68](../../../experiments.md) (the task factory's pilot) and E82 (the 16 dataset projects).
`zorn/local_cents` is one of the 16 applications of the dataset
([2026-11-12_dataset_projects](../2026-11-12_dataset_projects/README.md)): a desktop expense tracker (Phoenix 1.8,
LiveView 1.2, a Tauri shell) that stores each book as an Automerge document through a Rust library of its own. This
job set the project up in the task factory, ran its own test suite once in the engine, and made and checked its
candidates one at a time, newest merged first, until 20 cases are good or the list runs out. Everything ran on the
data-mining machine through a controller of its own, built from the factory's `main` at `f3c2082`, while other task
jobs used the same Docker daemon.

## Result

**Milestone 1 (2026-11-12 19:04): 5 good cases of 9 pull requests tried; 12 candidates still to run.** A case is good
when the gate checked it and it passes both scans. This page is brought up to date at each milestone.

- **The project needs Rust, and gets it from Ubuntu's own packages.** Its data layer is a Rustler library compiled from
  the project's own source (`native/ex_automerge`, crates `automerge`, `autosurgeon`, `rustler`) every time the module
  `LocalCents.Tracking.ExAutomerge` compiles; nothing is precompiled. Ubuntu's plain `rustc`/`cargo` (1.75) cannot read
  the project's `Cargo.lock` (format 4), so the recipe installs the distribution's versioned packages `rustc-1.97` and
  `cargo-1.97` (Rust 1.97.1 from `noble-updates`) and puts `/usr/lib/rust-1.97/bin` first on `PATH`. No other download.
  The project's CI installs Rust's current stable release with `rustup` instead (section 1).
- **No database and no other service.** `ecto` is used only for embedded schemas and forms; there is no `ecto_sql`,
  no `postgrex` and no Repo. A book is a file in a folder each test sets for itself.
- **The project's own suite passes whole** at the newest candidate's starting commit: 402 passed (6 doctests, 396
  tests), 0 failed, 0 excluded, in 20.5 s.
- **Good (5): 275, 263, 254, 250 and 241,** merged 2026-08-11 to 2026-08-18, all features (the maker's label and the
  written rule agree for all five). 241 changes the Rust library itself: the library was rebuilt inside the test
  containers, with no network, from the packages the image keeps.
- **Every good case is older than the project's licence file** (`LICENSE`, MIT, added 2026-08-31). The licence scan
  fails them for "no licence" at their starting commits; they count under the owner's rule for such cases (rules page,
  section 9: "Yes, count them"): one author, the licence's holder, wrote every file they touch, and the licence is
  unchanged on `main` (section 4).
- **Left out so far (3), and 1 to run again:** 296 and 289 (the only candidates newer than the licence) and 242 have
  no existing test left to protect (`no_existing_tests`), the pull request's own reason. 270 was dropped at the second
  round as unstable while the machine's 1-minute load reached 15.38; it is run once more at the end.
- **Time per checked case** (the engine's own count): 558.5, 339.5, 351.8, 176.4 and 154.8 s for 275, 263, 254, 250
  and 241. The first case also built the shared toolchain image; each later case is seeded from the one before.
- **Disk per checked case:** a workspace image of about 2.79 GB by Docker's size, of which about 433 MB is its own
  (Docker's rounded unique size in [`own_images.tsv`](own_images.tsv)); the shared toolchain image is 2.36 GB.

## 1. The project's set-up

The recipe is [`factory/recipes/zorn__local_cents.json`](../../../factory/recipes/zorn__local_cents.json). It is a
template (it has a `toolchain` block): the maker resolves each starting commit's Elixir and OTP from its
`.tool-versions`. Of the 21 candidates, 9 read 1.20.2 with OTP 29.0.4, 4 read 1.20.2 with OTP 28.5.0.3 and 8 read
1.20.1 with OTP 28.5; the image table has all three pairs. No CI file starts a service and no Redis client is a
dependency, so no candidate gets a service.

| Field | Value | Why |
|---|---|---|
| `runtime.image` (default) | `hexpm/elixir:1.20.2-erlang-29.0.4-ubuntu-noble-20260730.1`, pinned by digest | the image table's line for the pair the newest candidates name |
| `runtime.packages` | `rustc-1.97`, `cargo-1.97` | the Rust compiler and Cargo for the project's own Rustler library. They are Ubuntu's own packages (`noble-updates`, Rust 1.97.1). The plain `rustc`/`cargo` packages are 1.75, which cannot read `Cargo.lock` format 4; the image's package lists offer versioned builds from 1.74 to 1.97, and 1.97 is the newest |
| `runtime.environment.PATH` | `/usr/lib/rust-1.97/bin` first, then the image's own `PATH` | the versioned packages install `cargo` and `rustc` there; Rustler calls `cargo` by that name. The engine's login shell keeps this `PATH` (checked in the image) |
| `runtime.environment.CARGO_HOME` | `/opt/eab-seed/cargo` | Cargo's downloaded crates stay in the image the tests run in (the engine copies `/workspace` and `/opt/eab-seed` into it), so a case that changes the Rust code can rebuild it with no network |
| `runtime.environment.CARGO_BUILD_JOBS` | `4` | at most 4 build jobs on the shared machine |
| `runtime.setup_commands` | `mix compile`, then `test -e priv/native/ex_automerge.so \|\| mix compile --force` | Rustler writes the library to `priv/native/`, which is not in Git. A build seeded from an earlier case keeps `_build` and `deps` but not `priv/native`, so the module counts as compiled while its library is gone; the second command compiles the project again in that case only |
| `services` | none | no database: `ecto` only for embedded schemas and forms (no `ecto_sql`, no `postgrex`, no Repo); the data is Automerge documents in files |
| `baseline` | `{"mode": "prepared", "commands": []}` | a case without services has no database baseline |
| `permitted_exclusion_tags` | none | `test/test_helper.exs` is `ExUnit.start()` |
| `test_timeout` | 240 (the default) | |
| `grading.preservation` (the whole-suite command) | `mix test` | |

**Why Rust is needed, and not only in CI.** `lib/local_cents/tracking/ex_automerge.ex` has `use Rustler, otp_app:
:local_cents, crate: "ex_automerge"`: compiling that module runs `cargo` on `native/ex_automerge` (crates `rustler`
0.38.0, `automerge` 0.11.0 at the newest candidates and 0.10.0 at the older ones, `autosurgeon` 0.13 or 0.12; 90 crates
at the newest candidate) and loads the built library when the application starts. Every book is read and written through it, so
without Rust the project neither compiles nor runs. Cargo builds into the project's own `target/` (release mode),
which is in `.gitignore`. Three candidates change the Rust code themselves (242, 241 and 112).

**What the project's own build fetches** besides its Hex packages, all pinned by `mix.lock` or `Cargo.lock`: the 90
crates from crates.io (`Cargo.lock`); the Git dependencies `elixirkit` (`livebook-dev/elixirkit` at `16d19dd3`,
Apache-2.0 by its own `LICENSE`) and `heroicons` (`tailwindlabs/heroicons` at tag v2.2.0, a sparse checkout of its
`optimized/` icons only, so its licence file is not in the checkout and was not read here); and the prebuilt native
files of `mdex_native` (`rustler_precompiled`) and `lazy_html` (`cc_precompiler`) from those packages' release
pages, inside the packages' own build steps, as for hexpm and sanbase2.

## 2. The project's own tests

At the starting commit of pull request 296 (`a7213208`, the newest candidate), a hand-made probe task
([`run/make_probe.sh`](run/make_probe.sh)) was prepared through the controller and the whole suite ran once through
the engine's own runner, in a fresh workspace container with no network ([`run/suite.sh`](run/suite.sh)).

- **The preparation** took 300.9 s, cold (no earlier build to seed from). It compiled the project twice: the recipe's
  first check of the built library named the wrong file (`libex_automerge.so`); the file name was corrected before the
  cases ran.
- **The suite: all of it passes.** ExUnit's own summary: **402 passed (6 doctests, 396 tests), 0 failed, 0 excluded,
  in 20.5 s** (18.3 s async, 2.1 s sync; `max_cases: 4`); the engine's run took 21.4 s and recorded 402 rows for 402
  distinct names, every one passed. Output 67,696 bytes. Table: [`project_tests.tsv`](project_tests.tsv); no test
  failed. The only other line in the output is Erlang's warning that it finds no `libsctp.so.1`, which changes nothing
  here.

## 3. The cases

The list ([`list.tsv`](list.tsv), made by [`run/list.sh`](run/list.sh) from the screening's class table of the 16
projects): local_cents's 21 screened candidates, newest merged first, merged 2026-07-08 to 2026-09-10, none on an
Elixir older than 1.18. The screening marks all 21 as needing Rust (`toolchain:rust`); the recipe serves that, so all
21 are listed (`SERVED=toolchain:rust`). The driver ([`run/all.sh`](run/all.sh)) takes them one at a time through
[`run/one.sh`](run/one.sh): the bundle maker, the import, `factoryctl check --concurrency 1`, the export of a checked
task, then the licence scan and the hold-out check ([`run/scans.sh`](run/scans.sh), the factory's `tools/` unchanged).
Then [`run/licence_later.sh`](run/licence_later.sh) applies the rule for a case older than the project's licence
(section 4).

[`cases.tsv`](cases.tsv) has one line per try: the merge date, the resolved Elixir/OTP, the kind, the verdict, the step
and reason of a drop, the wall time of each step, the engine's own step times, the 1-minute load at the start and the
end and its highest value during the check, the bytes of this job's own images the try added, the two scans and whose
cause a drop is ([`causes.tsv`](causes.tsv) holds the reading). The machine ran nine jobs at once; every check so far
saw a 1-minute load between 12.06 and 15.38 on its 28 threads, so none is marked settled (the job's own mark, under 12).

| Pull request | Merged | Kind | Verdict | Step, reason | Hidden tests failing first / passing after | Licence | Hold-out |
|---|---|---|---|---|---|---|---|
| 296 | 2026-09-10 | - | refused | maker, no_existing_tests | - | - | - |
| 289 | 2026-09-01 | - | refused | maker, no_existing_tests | - | - | - |
| 275 | 2026-08-18 | feature | checked | - | 6 / 49 | pass (licence later, section 4) | pass |
| 270 | 2026-08-18 | feature | dropped, to run again | second_round, unstable | - | - | - |
| 263 | 2026-08-17 | feature | checked | - | 8 / 42 | pass (licence later) | pass |
| 254 | 2026-08-15 | feature | checked | - | 3 / 4 | pass (licence later) | pass |
| 250 | 2026-08-14 | feature | checked | - | 9 / 18 | pass (licence later) | pass |
| 242 | 2026-08-11 | bug_fix | dropped | probe, no_existing_tests | 9 / 9 | - | - |
| 241 | 2026-08-11 | feature | checked | - | 3 / 18 | pass (licence later) | pass |

Counts by the last try: [`counts.tsv`](counts.tsv).

**The balance of kinds** (rules page, section 7): all good cases so far are features. Once 10 are good and one kind has
fewer than 3, the driver makes a candidate of the other kind but defers it; every candidate still runs, since the list
is shorter than the target.

## 4. The licence

The project's licence file `LICENSE` (MIT, "Copyright (c) 2026 Mike Zornek") was added by commit `e55e080a` on
2026-08-31 (pull request 284), with a README sentence that names it; it has not changed since, and `main` holds the same
bytes ([`licence_proof.tsv`](licence_proof.tsv)). The project began on 2026-05-24. Only 296 and 289 start after the
licence; the other 19 candidates start from commits without it, and the licence scan fails each of them at the root
(`fail:no-licence`), while every file they touch passes on its own.

The owner's rule (rules page, section 9, 2026-11-12: "Yes, count them") counts such a case when the project states a
licence of the list later and still at its newest commit, every file the case touches was written only by that
licence's holder, no touched file carries another notice, and the record is kept. [`authors_cases.tsv`](authors_cases.tsv)
reads every candidate's changed files ([`run/authors.sh`](run/authors.sh)); [`licence_later.tsv`](licence_later.tsv)
and [`licence_later_files.tsv`](licence_later_files.tsv) read every checked case's touched files as the scan lists them
(the patches' files and the existing test files the case names), each with every commit up to the case's merge commit
that touched it, by author ([`run/licence_later.sh`](run/licence_later.sh)). For every good case: one human author, the
licence's holder; no bot commit on a touched file (the project's 6 bot commits are dependency bumps of other files);
and every touched file passes the scan on its own. Co-author lines that name AI tools (Copilot Autofix, Claude Sonnet
4.6) are recorded there, as for any candidate. A case with another author in a touched file would be left out as
`no_licence_at_commit`; none was.

**The hold-out check** found no held-out name and no shared span to read in any checked case
([`scans.tsv`](scans.tsv)).

**Dependencies, for the later scan of sessions** ([`deps.tsv`](deps.tsv)): of the 85 locked packages, every Hex package
declares a licence of the list (`yamerl` spells BSD-2-Clause as "BSD 2-Clause"); the two Git dependencies are read by
hand in section 1.

## 5. Files

| File | What it holds |
|---|---|
| [`cases.tsv`](cases.tsv) | one line per try (above); the pull requests not reached have one line "not run" |
| [`counts.tsv`](counts.tsv) | the pull requests by their last try's verdict, step and reason |
| [`causes.tsv`](causes.tsv) | the drops read by a person: whose cause, and why |
| [`good.tsv`](good.tsv) | every checked case with its licence and hold-out results, its kind, whether it counts and its licence verdict |
| [`scans.tsv`](scans.tsv) | the two scans per checked case: licence file and family, files touched and passing; the hold-out's checks and span counts |
| [`licence_proof.tsv`](licence_proof.tsv) | the licence file: the commit and date that added it, its pull request, copyright line and SHA-256, whether `main` still holds it, and the README sentence |
| [`authors_cases.tsv`](authors_cases.tsv) | per candidate: whether its starting and merge commits hold the licence, and the authors of its changed files |
| [`licence_later.tsv`](licence_later.tsv) | per checked case: the scan's result and the rule of section 4, with its verdict |
| [`licence_later_files.tsv`](licence_later_files.tsv) | per checked case and touched file: the commits, their authors, bot commits and co-author lines |
| [`licence_large.tsv`](licence_large.tsv) | the checked cases whose licence result fails only on files set aside as too large (none) |
| [`deps.tsv`](deps.tsv) | the locked packages of the checked cases, their declared licences and class, and how many cases lock them |
| [`own_images.tsv`](own_images.tsv) | every image of this job: id, tags, Docker's size and its unique size |
| [`list.tsv`](list.tsv) | the 21 screened candidates and each one's status in this job |
| [`project_tests.tsv`](project_tests.tsv) | the project's own suite: the engine's verdict, ExUnit's summary, the output's size |
| [`run/`](run/) | the scripts that ran: `controller.sh`, `build.sh`, `state.sh`, `watch.sh`; the suite (`suite.sh`, `env_tests.sh`, `make_probe.sh`, `prepare.exs`, `tests.exs`, `suite_tables.sh`); the cases (`list.sh`, `resolve.exs`, `all.sh`, `one.sh`, `make_one.exs`, `row.sh`, `scans.sh`); the licence and kinds (`authors.sh`, `licence_later.sh`, `kind_rule.sh`); the tables (`table.sh`, `collect.sh`) |

## 6. Exact commands

On the data-mining machine, as root, with `WORK` the factory's work folder, `JOB=$WORK/jobs/hb-localcents` (this
folder's `run/`, the factory's folder as `src/` at `f3c2082` with the recipe, `tables/` with the screening's census,
screen and class tables of the project, `local_cents-full.git` a full clone), `CTL=$WORK/ctl-hb-localcents`:

```sh
# the controller, apart from the other jobs' and the bench's
SRC=$JOB/src OUT=$JOB/logs IMAGE=elixir-task-factory:localcents-20261112 LABEL=task-factory=1 $JOB/run/build.sh controller
CTL=$CTL SOURCES=$JOB IMAGE=elixir-task-factory:localcents-20261112 NAME=factory-localcents \
  LABELS=task-factory=1,task-factory-job=hb-localcents HEX_CACHE_ID=etf-hex-packages-v1 EPMD_PORT=4526 \
  PREPARE_WORKERS=1 PREPARE_AHEAD=1 $JOB/run/controller.sh up
# the list, the stage, and the resolver over all 21 (no case made)
CLASSES=$JOB/tables/classes_local_cents.tsv OUT=$JOB/tables N=21 SERVED=toolchain:rust $JOB/run/list.sh && cp $JOB/tables/numbers.txt $JOB/
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-localcents $JOB/run/all.sh stage
cp $JOB/numbers.txt $JOB/run/resolve.exs $CTL/data/localcents/
CTL=$CTL NAME=factory-localcents $JOB/run/controller.sh rpc 'System.put_env(%{"P5_DIR" => "/data/localcents", "REPOSITORY" => "https://github.com/zorn/local_cents", "CENSUS" => "prs_zorn__local_cents.tsv", "SCREEN" => "screen_zorn__local_cents.tsv"}); spawn(fn -> Code.eval_file("/data/localcents/resolve.exs") end)'
# the project's own suite, once, at pull request 296's starting commit
JOB=$JOB OUT=$JOB/suite CTL=$CTL NAME=factory-localcents JOB_LABEL=task-factory-job=hb-localcents TASK_LABEL=task-factory=1 \
  MAX_LOAD=26 MIN_FREE=50000000000 DATA=$CTL/data GIT_DIR=$JOB/local_cents-full.git NUMBER=296 \
  MERGE=056fdde3fd3f0838b8f91ed1fec61ea32de0337c IMAGE=<the image table's line for 1.20.2/29.0.4> ROUNDS=1 SUB=env \
  TEST_TIMEOUT=1800 $JOB/run/suite.sh
D=$CTL/data/env OUT=$JOB/suite_tables ROUNDS=1 $JOB/run/suite_tables.sh
# the cases (a temporary copy of the bench's cases for the hold-out check first; deleted at the end)
BENCH_SRC=<the bench's cases folder> BENCH=$JOB/bench_cases OUT=$JOB/scans $JOB/run/scans.sh cases
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-localcents JOB_LABEL=task-factory-job=hb-localcents TASK_LABEL=task-factory=1 \
  TARGET=20 MAX_TRIES=21 KIND_AFTER=10 KIND_MIN=3 MAX_LOAD=26 MIN_FREE=50000000000 $JOB/run/all.sh run
# the licence record, the rule for cases older than the licence, the kinds by the written rule
G=$JOB/local_cents-full.git NUMBERS=$JOB/numbers.txt CLASSES=$JOB/tables/classes_local_cents.tsv \
  CENSUS=$JOB/tables/prs_zorn__local_cents.tsv HOLDER='Mike Zornek' OUT=$JOB/authors $JOB/run/authors.sh
OUT=$JOB/out SCANS=$JOB/scans AUTHORS=$JOB/authors DEST=$WORK/tasks/zorn__local_cents G=$JOB/local_cents-full.git \
  HOLDER='Mike Zornek' $JOB/run/licence_later.sh
$JOB/run/kind_rule.sh $WORK/tasks/zorn__local_cents > $JOB/out/kind_rule.tsv
# the tables
JOB=$JOB WORK=$WORK CTL=$CTL PUB=<this folder> JOB_LABEL=task-factory-job=hb-localcents $JOB/run/collect.sh
```

The watcher stops the job when a bench run starts, when free space on `/` falls under 50,000,000,000 bytes, or when
the 1-minute load is above 26 in two readings 300 s apart.

## 7. Provenance and licence

The project's code is MIT (`LICENSE`, since 2026-08-31; section 4). The tables hold pull request numbers, commit ids,
file names, test names and the author names the commits carry, never pull request titles, bodies or patch text. The
scripts in `run/` are this repository's; most are the sanbase2 job's scripts on the same machine, with that project's
names replaced by this one's.
