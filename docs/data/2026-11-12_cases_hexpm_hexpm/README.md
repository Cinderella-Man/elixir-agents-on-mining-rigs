# hexpm/hexpm: the project's set-up in the task factory, and its checked cases (2026-11-12)

Registry row [E68](../../../experiments.md) (the pilot of the task factory). `hexpm/hexpm` is one of the dataset's 16
applications ([rules](../../dataset_rules.md)). The first run wrote the project's recipe, ran the project's whole test
suite once through the engine, and made and checked its newest candidates one at a time, newest merged first, until 3
were checked, through a controller built from this repository's `main` at `e1d56cb`. The second run took the project
toward 20 checked cases the same way, through the same controller built again from `main` at `6c3fc4e` (the service
image fix of `0d99a67` and the licence scan's README rule), after the licence scan learned the dataset's rule for a
licence stated in the README (section 4). Everything ran on the data-mining machine (28 threads, 30 GiB, no GPU),
while other task-making jobs and one job that uses the model shared the machine. Times are the data-mining machine's
(UTC+1).

## Result

- **The project runs in the engine with one extra package:** `postgresql-client`, so that `mix ecto.load` can load the
  project's saved database layout (`priv/repo/structure.sql`). Nothing else was added: no release file, no other
  service than Postgres.
- **The whole suite passes** at the starting commit of the newest candidate, pull request 2118, on Elixir 1.20.4 with
  OTP 29.1.2 and Postgres 18.6: ExUnit's summary **5,313 passed (32 properties, 5,281 tests), 0 failed, 0 excluded, in
  105.1 s**. The engine's record is complete: 5,313 records, all distinct.
- **15 cases checked of 23 tried** (4 in the first run, 19 in the second; section 3): 10 features and 5 bug fixes.
  Dropped: 3 at the probe as `no_starting_failure`, 3 at the probe as `no_existing_tests`, 1 at the probe as
  `start_run_did_not_finish`, and 1 refused by the maker as `binary_file`, all the pull requests' own causes. The last
  check of every case was settled; one first check was not (2077, highest load 12.21) and was run again.
- **Both scans pass for all 15.** The licence scan passes on the project's README statement, as the dataset's rules
  allow when a repository has no licence file at its root (rules, section 9): the README's licence section, "Licensed
  under the Apache License, Version 2.0", at line 252 or 192 of the starting commit's `README.md`
  (`licence_root.tsv` has the file's hash, the line and the sentence for each case). Every file the 15 cases touch
  (186 files) passes the per-file scan at both commits. The hold-out check passes for all 15.

## 1. The project's set-up

The recipe is [`factory/recipes/hexpm__hexpm.json`](../../../factory/recipes/hexpm__hexpm.json), a template: the
toolchain resolver reads each commit's Elixir, OTP and Postgres from the commit's own files.

| What | Value | Where it comes from |
|---|---|---|
| Elixir and OTP | 1.20.4 and 29.1, served by `hexpm/elixir:1.20.4-erlang-29.1.2-ubuntu-noble-20261024.1` (the table's newest 29.1 line) | the CI workflow's job environment (`elixir: 1.20.4`, `otp: 29.1`) at every candidate tried; the project has no `.tool-versions` |
| Database | Postgres 18.6 (`postgres:18.6-alpine`, pinned by digest) | the CI workflow starts `postgres:18` |
| Other services | none | no Redis client in `mix.exs`; the CI starts only Postgres |
| System package | `postgresql-client` (Ubuntu's, `psql` 16) | the project's `test` alias runs `ecto.load --skip-if-loaded`, and Ecto loads `structure.sql` with `psql`; the layout was written by `pg_dump` 14.23, which `psql` 16 reads |
| Database commands | `mix ecto.create --quiet`, `mix ecto.load --skip-if-loaded --quiet`, `mix ecto.migrate --quiet` | the template's first candidate, taken when `mix.exs` names `ecto.load` in an alias; otherwise create and migrate only |
| Build | `mix compile` after the engine's own dependency steps | the bench's default recipe |
| Whole-suite command | `mix test` | the CI workflow's test job |
| Excluded tags | none | the project's `test_helper.exs` excludes nothing |

What the build fetches besides Hex packages, all as the project's own `mix.exs` and `mix.lock` ask:
- three dependencies from GitHub at the commits `mix.lock` pins (`finch`, `git_diff`, `hex_core`);
- the compiled parts of three packages, from the packages' own release pages through their build steps: `lumis`
  0.10.6 and `mdex_native` 0.3.1 (`rustler_precompiled`; their files in the image are named
  `...-nif-2.15-x86_64-unknown-linux-gnu.so`) and `lazy_html` 0.1.13 (`cc_precompiler`). nerves_hub_web's build
  does the same.

The project's CI also runs a job against the Hex client's own repository (`test-hex`) and a Docker build; neither is
part of the project's test suite, and neither is used.

**The screening's view:** of the project's 150 newest candidates (merged 2026-11-11 back), all 150 get an image since
the table holds Elixir 1.20.4 with OTP 29.1.2; 78 need nothing more, and 72 have a CI file that installs Rust (all of
them merged on or before 2026-10-06). The 4 tried here are the 4 newest of the 78.

## 2. The project's own suite

A hand-made probe task for pull request 2118 (`run/make_probe.sh`, with its own id and a 1,800-second limit for one
test command) was prepared through the controller (`run/prepare.exs`) in 131.2 s cold (the engine's own step 125.5 s:
the toolchain image with `postgresql-client`, the workspace image, the Postgres database with `structure.sql` loaded),
and the whole suite ran once through the engine's own runner (`run/tests.exs`), in a fresh workspace container with a
fresh database and no network. `project_tests.tsv`:

| Run | ExUnit tests | Passed | Failed | Excluded | ExUnit time | Engine time | Return code | Output | Engine: finished |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 1 | 5,313 (32 properties, 5,281 tests) | 5,313 | 0 | 0 | 105.1 s | 106.5 s | 0 | 887,347 bytes | yes (5,313 records, all distinct) |

## 3. The candidates

Newest merged first, from the screening's list ([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md)),
one at a time: made with the bundle maker and the toolchain resolver through the controller (`run/make_one.exs`),
imported with `factoryctl import`, checked with `factoryctl check --concurrency 1`, and a checked task exported to the
factory's task folder. A check is settled when the 1-minute load stayed under 12 during it. `tasks_hexpm.tsv` has one
line per try with every column (the first run's 4 lines, then the second run's); the engine's step times are in
seconds. The second run took the 73 candidates that need nothing more and that the first run had not tried
(`kinds.tsv`, column `needs` `-`, without 2118, 2119, 2113, 2112 and 2109), newest merged first.

| Run | Pull request | Merged | Elixir/OTP | Kind | Verdict | Step | Reason | Whose | Make | Check (prepare / probe / controls) | Load at start → end (highest in the check) | This job's images added (Docker's bytes) |
|---|---|---|---|---|---|---|---|---|---:|---|---|---:|
| 1 | 2118 | 2026-11-11 | 1.20.4/29.1 | bug fix | dropped | probe | `no_existing_tests` | the pull request's | 5 s (an earlier start) | 50 s (0.1 / 45.9 / -) | 5.39 → 6.58 (5.5) | 0 |
| 1 | 2119 | 2026-11-11 | 1.20.4/29.1 | feature | **checked** | - | - | - | 6 s | 280 s (68.6 / 80.5 / 121.9) | 6.58 → 6.68 (8.8) | 1,702,309,990 |
| 1 | 2113 | 2026-11-08 | 1.20.4/29.1 | feature | **checked** | - | - | - | 6 s | 941 s (58.2 / 360.9 / 519.6) | 6.68 → 6.00 (9.57) | 1,702,290,798 |
| 1 | 2112 | 2026-11-08 | 1.20.4/29.1 | feature | **checked** | - | - | - | 5 s | 370 s (51.7 / 140.8 / 167.9) | 6.00 → 10.48 (9.97) | 1,702,263,669 |
| 2 | 2111 | 2026-11-07 | 1.20.4/29.1 | feature | **checked** | - | - | - | 6 s | 401 s (73.8 / 113.5 / 204.7) | 10.10 → 8.39 (9.32) | 2,135,021,313 |
| 2 | 2099 | 2026-11-06 | - | - | refused | maker | `binary_file` | the pull request's | 5 s | - | 8.39 → 8.28 (-) | 0 |
| 2 | 2110 | 2026-11-06 | 1.20.4/29.1 | feature | **checked** | - | - | - | 6 s | 560 s (64.4 / 171.4 / 319.5) | 9.30 → 8.11 (11.28) | 1,698,752,758 |
| 2 | 2108 | 2026-11-05 | 1.20.4/29.1 | bug fix | dropped | probe | `no_existing_tests` | the pull request's | 20 s | 171 s (65.0 / 97.8 / -) | 8.11 → 9.39 (11.38) | 1,698,737,054 |
| 2 | 2103 | 2026-11-04 | 1.20.4/29.1 | bug fix | dropped | probe | `start_run_did_not_finish` | the pull request's | 10 s | 130 s (89.9 / 31.1 / -) | 9.39 → 8.42 (9.66) | 1,698,505,553 |
| 2 | 2104 | 2026-11-04 | 1.20.4/29.1 | feature | **checked** | - | - | - | 6 s | 470 s (50.9 / 148.1 / 265.0) | 8.42 → 7.42 (9.27) | 1,698,484,409 |
| 2 | 2097 | 2026-11-03 | 1.20.4/29.1 | feature | **checked** | - | - | - | 5 s | 1,202 s (117.7 / 493.1 / 586.0) | 7.30 → 5.70 (9.34) | 1,698,467,976 |
| 2 | 2098 | 2026-11-03 | 1.20.4/29.1 | feature | **checked** | - | - | - | 10 s | 190 s (53.4 / 44.7 / 87.2) | 5.70 → 8.95 (9.03) | 1,698,423,373 |
| 2 | 2096 | 2026-11-02 | 1.20.4/29.1 | bug fix | **checked** | - | - | - | 5 s | 270 s (52.6 / 96.5 / 113.5) | 8.95 → 6.48 (9.1) | 1,698,427,302 |
| 2 | 2095 | 2026-11-02 | 1.20.4/29.1 | feature | **checked** | - | - | - | 15 s | 981 s (52.7 / 360.8 / 558.1) | 6.48 → 5.77 (8.46) | 1,698,375,587 |
| 2 | 2094 | 2026-11-02 | 1.20.4/29.1 | bug fix | **checked** | - | - | - | 5 s | 360 s (56.2 / 125.3 / 176.5) | 6.64 → 6.98 (6.94) | 1,698,370,179 |
| 2 | 2092 | 2026-11-01 | 1.20.4/29.1 | bug fix | dropped | probe | `no_starting_failure` | the pull request's | 10 s | 181 s (128.1 / 48.5 / -) | 8.10 → 9.51 (9.62) | 1,694,940,710 |
| 2 | 2091 | 2026-10-31 | 1.20.4/29.1 | bug fix | **checked** | - | - | - | 10 s | 291 s (77.5 / 80.9 / 124.5) | 9.31 → 10.14 (10.14) | 1,694,907,513 |
| 2 | 2085 | 2026-10-27 | 1.20.4/29.1 | bug fix | **checked** | - | - | - | 10 s | 251 s (72.8 / 39.0 / 132.5) | 10.05 → 9.30 (11.16) | 1,692,438,600 |
| 2 | 2081 | 2026-10-24 | 1.20.4/29.1 | bug fix | dropped | probe | `no_existing_tests` | the pull request's | 6 s | 140 s (68.2 / 69.7 / -) | 9.30 → 12.54 (10.54) | 1,692,183,302 |
| 2 | 2077 | 2026-10-23 | 1.20.4/29.1 | bug fix | checked, **not settled** | - | - | - | 10 s | 430 s (148.1 / 104.6 / 176.6) | 13.06 → 9.18 (12.21) | 1,682,980,523 |
| 2 | 2077 (try 2) | 2026-10-23 | 1.20.4/29.1 | bug fix | **checked** | - | - | - | - | 261 s (0.1 / 101.8 / 157.5) | 7.08 → 6.88 (8.34) | 0 |
| 2 | 2074 | 2026-10-22 | 1.20.4/29.1 | bug fix | dropped | probe | `no_starting_failure` | the pull request's | 6 s | 80 s (62.5 / 15.7 / -) | 9.89 → 9.26 (9.41) | 1,682,966,295 |
| 2 | 2060 | 2026-10-17 | 1.20.4/29.1 | bug fix | dropped | probe | `no_starting_failure` | the pull request's | 6 s | 140 s (126.2 / 8.2 / -) | 9.26 → 7.50 (8.67) | 1,679,811,272 |
| 2 | 2056 | 2026-10-17 | 1.20.4/29.1 | feature | **checked** | - | - | - | 5 s | 250 s (49.4 / 84.7 / 116.0) | 7.50 → 7.08 (8.51) | 1,679,811,418 |

- **2118:** its only existing test file near the change is the test file the pull request changes, and that file's
  starting version fails on the reference fix (the pull request changes the behaviour the old tests asserted). The
  probe left it out (`fails_on_reference`), and no existing test was left. The same drop was seen in an earlier start
  of the run (section 5).
- **2099:** the pull request adds an image (`priv/static/images/blog/028_key_permissions.png`, a blog post's), which a
  task folder's text patches cannot carry; the maker refuses it (`factory/README.md`, "What it refuses").
- **2108, 2081:** dropped like 2118: no existing test file is left to protect once the ones that fail on the
  reference are left out.
- **2092, 2074, 2060:** `no_starting_failure`: no hidden test fails in its body on the unchanged project (the tests
  the pull request adds or changes already pass before its fix).
- **2077:** its first check was not settled (the load reached 12.21 during it, 13.06 at its start), so the run checked
  it again at the end of its phase, settled (highest 8.34): checked both times. The first check left 2 existing test
  files out as `fails_on_reference` and the second none; the case exported is the second's, with 3 existing test
  files kept.
- **2103:** the hidden tests did not complete on the unchanged project. The probe's two runs together took 31.1 s, far
  under the test limit, so this is not a time-out; the engine keeps no output of the probe's runs, so the error cannot
  be read (most likely the hidden tests do not compile without the fix). The rules count "cannot run at all" as the
  pull request's cause (section 4 of the rules, `no_starting_failure`'s line).
- **The checked cases** (`checked.tsv`, from the engine's result of each):

| Case | Kind | Hidden tests failing first | Passing after | Existing test files kept | Left out (`fails_on_reference`) | Partial fix | Second round agrees |
|---|---|---:|---:|---:|---:|---|---|
| 2119 | feature | 1 | 53 | 2 | 0 | present | yes |
| 2113 | feature | 4 | 84 | 2 | 2 | present | yes |
| 2112 | feature | 5 | 100 | 1 | 3 | present | yes |
| 2111 | feature | 5 | 117 | 8 | 1 | present | yes |
| 2110 | feature | 16 | 293 | 6 | 0 | present | yes |
| 2104 | feature | 9 | 236 | 7 | 0 | present | yes |
| 2097 | feature | 44 | 431 | 7 | 13 | present | yes |
| 2098 | feature | 1 | 6 | 1 | 0 | present | yes |
| 2096 | bug fix | 9 | 17 | 1 | 1 | present | yes |
| 2095 | feature | 34 | 171 | 4 | 5 | present | yes |
| 2094 | bug fix | 1 | 130 | 2 | 0 | present | yes |
| 2091 | bug fix | 1 | 42 | 1 | 0 | present | yes |
| 2085 | bug fix | 7 | 45 | 2 | 1 | present | yes |
| 2077 | bug fix | 7 | 259 | 3 | 0 | present | yes |
| 2056 | feature | 7 | 94 | 4 | 0 | present | yes |

- **Marks for reporting** (the screening's table): 2098 carries the screening's AI-tool mark (such pull requests are
  used and marked, rules section 3) and changes assets; 2097, 2110 and 2095 add a database migration. The others carry
  none of the three. The checked cases may edit `lib/` and `test/`, and also `priv/` (2098, 2110, 2095) and
  `config/` and `priv/` (2097), as their reference fixes do.
- **The kinds.** The maker gives a case its kind (a feature when the fix adds a file or a public function it does not
  also remove, else a bug fix). `kinds.tsv` reads the same rule ahead from the project's history for every candidate
  (`run/kinds.sh`), so that the run can prefer a kind that falls short: by that reading the 73 candidates are 30 bug
  fixes and 43 features. The read-ahead agreed with the made folder for 22 of the 23 cases made so far; for 2056 it
  read a bug fix and the maker made a feature. The change rewrites the one-line public function `parse_search` as a
  longer one: the read-ahead sees it removed and added again, so nothing new, while the maker counts it as added. Why
  the maker's reading differs was not looked into.

**Counts by reason** (`counts.tsv`, each pull request by its last try): checked 15; dropped at the probe,
`no_starting_failure`, 3; dropped at the probe, `no_existing_tests`, 3; dropped at the probe,
`start_run_did_not_finish`, 1; refused by the maker, `binary_file`, 1. Drops by whose cause: the pull request's 8, the
factory's 0, the machine's 0.

**One more pull request was checked out of order, 2109** (merged 2026-11-06, the 7th newest): a stop of the run left
its check running alone in the controller (section 5), and it was let finish. It was **dropped at the second round as
`unstable`**: one test of `HexpmWeb.API.OAuthControllerTest`, among its hidden tests, passed on the reference in the
first round and failed in the second. The load was 9.04 when it ended. The engine keeps no output of a second-round run,
so why the test failed cannot be read. By the rules it is the pull request's cause (an unstable test); it was seen once
and was not run again. It is not counted in the table above.

## 4. Licence and hold-out

Run on each checked task, one at a time (`run/run_scans.sh`, which calls `run/scans.sh` and through it
`factory/tools/check_tasks.sh` of `main` at `6c3fc4e`), in a Python container with no network; Hex metadata was
fetched for the dependency list. The first run's 3 tasks were scanned again with the README rule. `scans.tsv`,
`licence_root.tsv`, `licence_files.tsv`, `holdout_tasks.tsv`, `deps_flagged.tsv`:

| Task | Licence result | Root licence | Files touched | Files passing | Hold-out result | Name hits | Shared 8-word runs (`common` / own tree) | Shared 12-word runs |
|---|---|---|---:|---:|---|---:|---:|---:|
| 2119 | pass | `ok:readme-statement`, Apache-2.0 | 4 | 4 | pass | 0 | 7 (7 / 0) | 0 |
| 2113 | pass | `ok:readme-statement`, Apache-2.0 | 6 | 6 | pass | 0 | 7 (7 / 0) | 0 |
| 2112 | pass | `ok:readme-statement`, Apache-2.0 | 11 | 11 | pass | 0 | 7 (7 / 0) | 0 |
| 2111 | pass | `ok:readme-statement`, Apache-2.0 | 17 | 17 | pass | 0 | 7 (7 / 0) | 0 |
| 2110 | pass | `ok:readme-statement`, Apache-2.0 | 14 | 14 | pass | 0 | 11 (7 / 4) | 0 |
| 2104 | pass | `ok:readme-statement`, Apache-2.0 | 14 | 14 | pass | 0 | 7 (7 / 0) | 0 |
| 2097 | pass | `ok:readme-statement`, Apache-2.0 | 56 | 56 | pass | 0 | 8 (7 / 1) | 0 |
| 2098 | pass | `ok:readme-statement`, Apache-2.0 | 4 | 4 | pass | 0 | 7 (7 / 0) | 0 |
| 2096 | pass | `ok:readme-statement`, Apache-2.0 | 6 | 6 | pass | 0 | 7 (7 / 0) | 0 |
| 2095 | pass | `ok:readme-statement`, Apache-2.0 | 23 | 23 | pass | 0 | 7 (7 / 0) | 0 |
| 2094 | pass | `ok:readme-statement`, Apache-2.0 | 4 | 4 | pass | 0 | 7 (7 / 0) | 0 |
| 2091 | pass | `ok:readme-statement`, Apache-2.0 | 2 | 2 | pass | 0 | 7 (7 / 0) | 0 |
| 2085 | pass | `ok:readme-statement`, Apache-2.0 | 6 | 6 | pass | 0 | 8 (7 / 1) | 0 |
| 2077 | pass | `ok:readme-statement`, Apache-2.0 | 11 | 11 | pass | 0 | 7 (7 / 0) | 0 |
| 2056 | pass | `ok:readme-statement`, Apache-2.0 | 8 | 8 | pass | 0 | 7 (7 / 0) | 0 |

- **The project's licence proof** (rules, section 9: a licence stated in the README counts when the repository has no
  licence file at its root). hexpm has no `LICENSE`, `LICENCE` or `COPYING` file at its root at any of these commits.
  Its `README.md` ends with a section headed "License" that holds the project's copyright line (Six Colors AB, 2015)
  and the Apache License's own notice. `task_licence.py` (`main` at `6c3fc4e`) reads that section and records for
  every case, from the case's starting commit (`licence_root.tsv`): the file `README.md`, its SHA-256, the line and
  the sentence. The README has three versions across the 15 starting commits (SHA-256 `2018150056342b9a...` for 6
  cases and `7cedbe3d417eeb7e...` for 5, the sentence at line 252; `f2d1551f552dcb60...` for 4, at line 192); the
  sentence is the same in all: "Licensed under the Apache License, Version 2.0 (the "License"); you may not use this
  file except in compliance with the License." It names one licence of the list in plain words and sits in the project's own
  licence section (the section's next paragraph, the licence's address on apache.org, names the same licence). The one
  other licence the README names is outside that section: line 98 says the IP-to-country database file the production
  site uses is under CC BY 4.0, and the tool counts it as a mention, not as the project's statement (`mentions` 1). So
  the root result is `ok:readme-statement`, the scan's own family is Apache-2.0 and its holder Six Colors AB, and
  every touched file's verdict is `ok` at both commits. The task folders' `provenance.json` still record the licence
  as `NOASSERTION`: the bundle maker reads only a licence file, and its reading is a first guess on which the licence
  scan has the last word (`Eab.BundleMaker`'s own note).
- **The locked dependencies** (the same 158 in every task; `deps_flagged.tsv` lists those not plainly allowed,
  with the number of tasks that lock each): the three GitHub dependencies (`finch`, `git_diff`, `hex_core`, the last
  at two commits across the tasks), whose licences the tool does not read; `bcrypt_elixir` 3.3.2, which lists
  BSD-3-Clause, ISC and BSD-4-Clause; and three spelled loosely (`BSD`, `Apache 2.0`). These matter for sessions
  (rules, section 6), not for the tasks.
- **Hold-out:** the repository is not held out, no task names a held-out project, and every shared 8-word run is
  `common` (it occurs in the cases of two or more of the bench's projects) or `own-tree` (the project already held it
  at the starting commit). No run needs reading.

## 5. How the run went

The job used the driver scripts of [2026-11-12_tasks_nerves_hub_web](../2026-11-12_tasks_nerves_hub_web/README.md),
with this project's names. The run was started five times; only the fifth gives the table above. The four earlier
starts gave no verdict except the two checks named:

1. **The maker could not read its Git cache** (`fetch_failed`, "detected dubious ownership"): the cache had been copied
   as the machine's work user, and the controller runs as root. 2118, 2119, 2113, 2112 and 2111 were refused at once,
   and the run was stopped by hand. Fixed by giving the cache to root.
2. **The driver could not remove the maker's earlier files** (owned by root) and ended each pull request at once. The
   run was stopped by hand. Meanwhile 2109 had been made and its check started; it ran to its end alone (section 3).
   The earlier files were removed.
3. **The driver could not read the engine's job records**, which the engine writes readable by root only, so it waited
   on 2118's finished check without end. Its check had ended in 104 s: dropped at the probe, `no_existing_tests`. The
   driver was stopped and from then on ran as root, as the other jobs' drivers do.
4. **Every pull request ended before its first step with exit code 126:** `one.sh` passed Docker's whole image list as
   one argument to `jq`, and with the images on the machine by then (149,026 bytes as JSON) that argument passed the
   kernel's 131,072-byte limit for one argument. **This job's `run/one.sh` writes the list to a file instead;** the
   rest of the script is unchanged. The scripts it was copied from have the same limit.

**The second run** started once, from the first run's controller folder, data and maker's Git cache, with these
changes:

1. **The controller was built again** from this repository's `main` at `6c3fc4e` (`run/build.sh`; image
   `elixir-task-factory:hexpm-20261112-6c3fc4e`). That code holds the service image fix of `0d99a67`: each controller
   keeps its database layout image under a tag of its own installation, so another controller's build of the same
   recipe can no longer remove it ("content digest ... not found" at `prepare`). The old container was removed and a
   new one made with the same name, node, port, folders, labels and limits; the engine's data stayed.
2. **A failure that is the machine's is run again at once.** `run/all.sh` now runs a try again when its row is not
   checked and its reason or detail shows a time-out, a lost database connection or a lost image (second try in
   `<id>/2`). None was needed so far.
3. **Its own list and counts:** `numbers.txt` is the 73 candidates of section 3, and `TARGET` and `MAX_TRIED` count
   this run's rows only. The stop line for free bytes is 50,000,000,000.
4. **Phases, for the two kinds.** The job asked for both kinds, and for the kind with fewer than 3 cases after 10 to
   be preferred. Phase 1 (`TARGET=7`, 10 cases in all) gave 9 features and 1 bug fix, so phase 2 put the candidates
   the read-ahead calls bug fixes first (`numbers_phase2.txt` order) until 15 cases. Then the target became 20 (the
   owner: spares for cases the teacher model cannot solve), with bug fixes preferred until the project has 6, then
   newest first again. Phase 3 (`run/next_phase.sh`, newest first, `TARGET=17`) started at once, but the project had
   only 5 bug fixes, not 6 (2056, read as a bug fix, was made a feature): its first candidate, 2083, was let finish,
   every later one was held (`out/hold.txt`, which `one.sh` skips), and `run/phases.sh` took over: rounds of
   `all.sh`, bug fixes first and one more checked case per round while the project has fewer than 6 bug fixes, then
   newest first until 17 checked in this run (20 in all).

## 6. Disk and load

- **This job's images** carry its label: one toolchain image (879 MB by Docker, its layers shared), six workspace
  images (the probe's, 2109's, 2118's, 2119's, 2113's, 2112's; 329.1 MB each unique, 325.6 MB for 2109's) and five
  Postgres snapshots (61.8 MB each unique). About 2.3 GB in all (est., from Docker's unique sizes).
- **This job's folders:** the controller's data and task folders 393,732,990 bytes, the job folder 272,559,706 bytes
  (with the project's clone and the job's records), the 3 exported task folders 94,564 bytes.
- **The machine:** free bytes on the system disk 798,025,519,104 when the job started (13:16) and 751,960,117,248 when
  the controller stopped (14:29), with every job's use in it. The 1-minute load was 1.82 at the start; during the
  checks it ran from 5.39 to 9.97 on 28 threads.
- **The engine's own limits:** one preparation worker and one check at a time (`--concurrency 1`); the engine has no
  switch for build jobs, and every workspace container runs Erlang with 2 schedulers (the engine's `ERL_FLAGS
  "+S 2:2"`). Every container carried the labels `task-factory=1` and `task-factory-job=hb-hexpm` and a CPU share of
  256; no stop rule fired (free bytes never under 700,000,000,000; load never above 26).

## Files

| File | What it holds |
|---|---|
| `tasks_hexpm.tsv` | one line per try, the first run's final start and then the second run: the try, number, id, merge date, Elixir/OTP read, kind, folder origin, verdict, step, reason, the driver's step times, the engine's step times, load at start and end and the highest during the check, settled, the bytes of every image the machine gained meanwhile (all jobs'; images share layers), the build cache's change, the disk bytes used (all jobs'), start, end, and this job's own images and their bytes (the images the try added that carry this job's label) |
| `counts.tsv` | pull requests per verdict, step and reason, each by its last try |
| `checked.tsv` | per checked case: kind, hidden tests failing first and passing after, existing test files kept and left out, the partial fix, the second round |
| `kinds.tsv` | the screening's 150 newest candidates in order: merge date, starting and merge commits, the toolchain need, and the kind read ahead by the maker's rule, with the files and public functions the fix adds |
| `project_tests.tsv` | the whole-suite run: the engine's verdict and counts, ExUnit's summary, the output's size |
| `scans.tsv` | per task: the licence result, the root licence families, files touched and passing, the scan's reasons, the hold-out result, name hits, seconds |
| `licence_root.tsv` | per task: the root licence's result, the file it was read from and that file's SHA-256, the families, the holder, and for a README statement its line, its sentence and the count of other licence mentions |
| `licence_files.tsv` | per task and touched file: which patches touch it, the scan's verdict at the starting and the merge commit, the result |
| `holdout_tasks.tsv` | per task: the repository check, name hits, and the shared 8- and 12-word runs by class |
| `deps_flagged.tsv` | the locked dependencies whose licence is not plainly in the list, with the number of tasks that lock each |
| `run/` | the scripts that ran (below) |

## Commands

On the data-mining machine, as root (the engine's job records are readable by root only). `WORK` is the factory's
work folder (with `tasks/`), `JOB` this job's folder (with `run/`, `src/` = this repository's `factory/` at `e1d56cb`
plus this recipe, `tables/` = the screening's census and screen tables of hexpm, `numbers.txt` = the screening's 30
newest candidates, `hexpm.git` = a bare clone of the project, `cache/hexpm__hexpm.git` = a copy of it owned by root),
`CTL` the controller's folder.

```sh
SRC=$JOB/src OUT=$JOB/out IMAGE=elixir-task-factory:hexpm-20261112 LABEL=task-factory=1 run/build.sh controller
CTL=$CTL NAME=factory-hexpm SOURCES=$JOB IMAGE=elixir-task-factory:hexpm-20261112 HEX_CACHE_ID=etf-hex-packages-v1 \
  LABELS=task-factory=1,task-factory-job=hb-hexpm EPMD_PORT=4516 PREPARE_WORKERS=1 PREPARE_AHEAD=1 run/controller.sh up
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-hexpm CACHE=$JOB/cache run/all.sh stage

# the whole suite once at the starting commit of pull request 2118 (merge commit 7347bf2a)
JOB=$JOB DATA=$CTL/data GIT_DIR=$JOB/hexpm.git NAME=factory-hexpm NUMBER=2118 \
  MERGE=7347bf2aa2a01a2f669cbfdd0120fb7ac7170dda ROUNDS=1 TEST_TIMEOUT=1800 SUB=env OUT=$JOB/out/suite CTL=$CTL \
  JOB_LABEL=task-factory-job=hb-hexpm TASK_LABEL=task-factory=1 MAX_LOAD=26 MIN_FREE=700000000000 run/suite.sh
D=$CTL/data/env OUT=$JOB/out/suite ROUNDS=1 run/suite_tables.sh

# the cases: newest first, until 3 are checked or 12 tried
WORK=$WORK JOB=$JOB CTL=$CTL NAME=factory-hexpm JOB_LABEL=task-factory-job=hb-hexpm TASK_LABEL=task-factory=1 \
  TARGET=3 MAX_TRIED=12 MAX_LOAD=26 MIN_FREE=700000000000 run/all.sh run

# the licence scan and the hold-out check, one task at a time
SRC=$JOB/src DEST=$WORK/tasks/hexpm__hexpm CLONE=$JOB/hexpm.git BENCH_CASES=<the bench's cases/ folder> \
  OUT=$JOB/out/scans LABELS=task-factory=1,task-factory-job=hb-hexpm \
  run/scans.sh hexpm-pr-2119 hexpm-pr-2113 hexpm-pr-2112

# the tables (NUMBERS: the numbers tried, one per line)
for t in tasks counts images; do
  OUT=$JOB/out NUMBERS=$JOB/out/tried.txt PREFIX=hexpm TASKDIR=$CTL/data/hexpm/tasks \
    SCREEN_TSV=$JOB/tables/screen_hexpm__hexpm.tsv run/table.sh $t > $JOB/out/tables/$t.tsv
done
CTL=$CTL NAME=factory-hexpm run/controller.sh stop
```

The second run. `T` is its folder (with `run/`, a copy of the first run's scripts with the changes of section 5;
`src/` = this repository's `factory/` at `6c3fc4e`), `PUB` the first run's published tables.

```sh
# the licence tool's tests, in the Python image, from a copy of factory/tools (task_licence.py, its test,
# task_folder.py and upstream/)
cd <the copy> && docker run --rm --network none --label task-factory=1 --label task-factory-job=hb-hexpm \
  --cpu-shares 256 -u 1000:1000 -v "$PWD:$PWD:ro" -w "$PWD" python:3.12-slim-bookworm \
  python -I test_task_licence.py -v

# the controller, built again and made again with the first run's name, node, port and folders
SRC=$T/src OUT=$T/out IMAGE=elixir-task-factory:hexpm-20261112-6c3fc4e LABEL=task-factory=1 run/build.sh controller
docker rm factory-hexpm
CTL=$CTL NAME=factory-hexpm SOURCES=$JOB IMAGE=elixir-task-factory:hexpm-20261112-6c3fc4e \
  HEX_CACHE_ID=etf-hex-packages-v1 LABELS=task-factory=1,task-factory-job=hb-hexpm EPMD_PORT=4516 \
  PREPARE_WORKERS=1 PREPARE_AHEAD=1 run/controller.sh up

# the candidates and their kinds read ahead; numbers.txt = needs "-", without the five the first run tried
CLASSES=$JOB/tables/classes_hexpm.tsv CENSUS=$JOB/tables/prs_hexpm__hexpm.tsv CLONE=$JOB/hexpm.git \
  run/kinds.sh > $T/kinds.tsv

# the cases. Phase 1, newest first, until 7 more are checked (10 in all)
E="WORK=$WORK CTL=$CTL NAME=factory-hexpm JOB_LABEL=task-factory-job=hb-hexpm TASK_LABEL=task-factory=1 MAX_LOAD=26 \
  MIN_FREE=50000000000"
env $E JOB=$T TARGET=7 MAX_TRIED=60 run/all.sh run
# phase 2: numbers.txt = the tried ones, then the untried bug fixes (read-ahead), then the features; to 15 in all
env $E JOB=$T TARGET=12 MAX_TRIED=60 run/all.sh run
# phase 3 (newest first, to 20), started when phase 2's driver (pid D) ended; held after its first candidate
env $E T=$T AFTER=$T/logs/phase2.start DRIVER=$D PHASE=phase3 TARGET=17 MAX_TRIED=80 run/next_phase.sh
# then the rounds: bug fixes first while the project has fewer than 6, then newest first, to 17 in this run
env $E T=$T DEST=$WORK/tasks/hexpm__hexpm TARGET_FINAL=17 MIN_BUGFIX=6 MAX_TRIED=80 run/phases.sh

# the scans, one task at a time (the first run's three again)
JOB=$JOB T=$T WORK=$WORK BENCH_CASES=<the bench's cases/ folder> run/run_scans.sh hexpm-pr-2119 hexpm-pr-2113 ...

# the tables of this run, then the data folder's tables of both runs
awk -F'\t' 'NR > 1 && $1 == 1 {print $3}' $T/out/rows.tsv > $T/out/tried.txt
OUT=$T/out NUMBERS=$T/out/tried.txt PREFIX=hexpm TASKDIR=$CTL/data/hexpm/tasks \
  SCREEN_TSV=$JOB/tables/screen_hexpm__hexpm.tsv JOB_LABEL=task-factory-job=hb-hexpm RUN=$T/run run/tables.sh
PREV=$PUB PREV_OUT=$JOB/out OUT=$T/out SCANS=$T/out/scans DEST=$T/pub run/pub.sh
CTL=$CTL NAME=factory-hexpm run/controller.sh stop
```

`run/` holds `all.sh`, `one.sh` (its image list through a file, section 5), `row.sh`, `watch.sh`, `controller.sh`,
`build.sh`, `state.sh`, `make_one.exs`, `make_probe.sh`, `prepare.exs`, `tests.exs`, `env_tests.sh`, `suite.sh`,
`suite_tables.sh` and `table.sh` from the nerves_hub_web job, with this project's names in `all.sh`, `env_tests.sh`
and `table.sh`, a cap on the pull requests tried in `all.sh`, and `scans.sh`, new. The second run changed `all.sh`
(section 5) and added `kinds.sh`, `next_phase.sh`, `phases.sh`, `run_scans.sh`, `tables.sh` and `pub.sh`.

## Licence

The tables hold pull request numbers, dates, version pairs, reason names, file paths of the project, times and byte
counts; no code, title, body or patch text of the project. hexpm states the Apache License, Version 2.0 in its
README.
