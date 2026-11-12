# Pilot job P6, second batch: the licence scan and the hold-out check on the other 34 checked tasks (E68)

The first batch of job P6 ([data](../2026-11-12_pilot_licence_holdout/README.md)) checked 16 of ex338's tasks. This
batch runs the same tools, unchanged, on the 34 checked tasks that had not been through either check: 27 of
`podlove/radiator` (pull requests merged from 2023-11-28 to 2026-10-26) and 7 of `axelclark/ex338` (merged from
2024-03-20 to 2024-04-14). The tools are in [`factory/tools/`](../../../factory/tools/README.md). No task was moved
or deleted: the per-task tables are the result.

## Result

| Check | radiator (27 tasks) | ex338 (7 tasks) | What failed |
|---|---:|---:|---|
| Licence: root licence at the starting commit is MIT, Apache-2.0 or BSD | 27 of 27 | 7 of 7 | nothing: `LICENSE`, MIT, in all 65 distinct commits; `provenance.json` says MIT for all 34 |
| Licence: every project file the task touches has an `ok` verdict | 26 of 27 | 6 of 7 | `radiator-pr-572` and `ex338-pr-1283`, one file each, the same file: `assets/vendor/sortable.js`, added by the pull request (in its reference patch and its partial fix) and marked `exclude:vendored` in the merge tree. It is a minified copy of SortableJS (1.15.0 in radiator, 1.15.2 in ex338) whose first line names the MIT licence and SortableJS's repository. 316 (task, file) pairs in radiator, 315 `ok`; 67 in ex338, 66 `ok` |
| Hold-out (a): repository not among the 12 projects, their organisations or names | 27 of 27 | 7 of 7 | nothing: `podlove/radiator`, `axelclark/ex338` |
| Hold-out: no case id or held-out repository name in any task text | 27 of 27 | 7 of 7 | nothing: 44 names looked for, 0 found |
| Hold-out (b): no 8- or 12-word span shared with the bench's 20 cases, other than boilerplate | 24 of 27, 3 `review` | 7 of 7 | `radiator-pr-500`, `-546` and `-645` each share one or two 8-word spans of the class `to-read` with one bench case (pinchflat's). Read by eye, each is boilerplate (below). No 12-word span is `to-read` in any task |

**Licence: 32 of 34 pass. Hold-out: 31 of 34 pass and 3 are `review`; all three hits read as boilerplate, so none fails
on reading.** No task is held out by repository or name. The manager decides what is dropped.

### Dependencies

The lock files of the 34 starting commits hold 164 Hex packages (378 package versions) and 3 git packages (4 locks).
By the licences each package declares for its locked version (`deps.tsv`; per project `deps.summary.tsv`):

| Class | Package versions | Packages |
|---|---:|---|
| only MIT, Apache-2.0 or BSD, by SPDX id | 353 | |
| the same, spelled otherwise (`Apache 2.0`, `Apache 2`, `BSD`, `BSD 2-Clause`) | 12 | 9: `cowboy_telemetry`, `metrics`, `nimble_parsec`, `parse_trans`, `telemetry`, `telemetry_metrics`, `telemetry_poller`, `unicode_util_compat`, `yamerl` |
| **outside the three** | 10 | 5: `cowboy` (ISC), `cowlib` (ISC), `ranch` (ISC), `file_system` (WTFPL), `open_api_spex` (MPL-2.0) |
| **several declared, some outside** | 3 | 2: `bcrypt_elixir` (`BSD-3-Clause`, `ISC`, `BSD-4-Clause`), `poolboy` (`Unlicense`, `Apache 2.0`) |
| git dependency, read by hand (`gitdeps.tsv`) | 4 locks | 3: `daisyui` and `heroicons` (two commits) are MIT; **`web_inspector` has no licence** at the pinned commit |

- **Per project:** ex338 locks 71 packages (86 versions: 72 plus 6 allowed, 5 outside plus 2 several, 1 git); radiator
  locks 149 (328 versions: 306 plus 9 allowed, 8 outside plus 1 several, 4 git locks).
- **ISC, since 2026-11-12:** the guide's table now allows ISC (E51, decided while this batch ran); the tool's list is
  still the three licences, so the tables mark `cowboy`, `cowlib` and `ranch` as `outside`. With ISC allowed they
  pass, and what stays outside is `file_system` (WTFPL), `open_api_spex` (MPL-2.0), `bcrypt_elixir` (its list names
  `BSD-4-Clause` as well as ISC), `poolboy` (its list names `Unlicense`) and the git dependency `web_inspector`.
- **Outside the three, by task:** every one of the 34 tasks locks at least one of `cowboy`, `cowlib`, `ranch`
  (the web server of any Phoenix application), so that part of the class does not tell tasks apart. The others:
  `bcrypt_elixir` is locked by 11 tasks (7 of ex338, 4 of radiator), `poolboy` by 7 (ex338), `file_system` by
  radiator's 500, 510 and 541, `open_api_spex` by 645 and `web_inspector` by 593 and 594. The rows are in
  `deps.outside.tsv`.
- **Beyond the first batch:** its five packages outside the three (`cowboy`, `cowlib`, `ranch`, `bcrypt_elixir`,
  `poolboy`) recur; this batch adds `file_system`, `open_api_spex` and `web_inspector`. The first batch's open item,
  the licence of `heroicons`, is closed: both of its commits (`0435d4c`, `88ab3a0`) carry the MIT licence.
- **The git dependencies were read by hand** from each repository's licence file at the commit the lock file pins
  (`run/git_dep_licences.sh` fetches the file, a person read it): `daisyui` at `22ecff5`, MIT, one copyright line;
  `heroicons` at `0435d4c` and at `88ab3a0`, MIT, with the same standard text and a different copyright line each.
  `web_inspector` at `5648328` has 40 tree entries and none is a licence file, and neither its `mix.exs` nor its
  `README.md` mentions a licence or a copyright, so the commit states no licence.
- **The guide's rows for the rest (section 8):** WTFPL needs a read, MPL-2.0 is a "no", Unlicense is "not for now", a
  repository with no licence is "no permission". Whether a dependency's licence decides a task is for the manager and
  the owner.

### Dependencies that belong to a held-out project

Not one of the tool's rules, which look at the task's own repository and text; added because radiator is built on
Ash. By package name, and by the GitHub organisation or repository in each package's own metadata links
(`deps.holdout.tsv`), 33 locked package versions belong to the held-out project `ash` or its organisation:
`ash`, `ash_admin`, `ash_json_api`, `ash_oban`, `ash_phoenix`, `ash_postgres`, `ash_sql`, `ash_state_machine`, `crux`,
`igniter`, `igniter_js`, `iterex`, `reactor`, `spark`, `splode` and `usage_rules`. Four tasks lock them: radiator's
`639`, `641`, `643` (13, 13 and 15 of these packages) and `645` (16); the other 30 lock none (`deps.holdout.tasks.tsv`).
The task text and the files a task touches are radiator's own; what the rule leaves open is a session that reads
`deps/ash` or another of these packages, which would put held-out project code into the session. Nothing is
decided here.

### Radiator's licence file over the commits the tasks start from

The tasks' commits run from 2023-11-27 to 2026. Of radiator's 52 distinct commits, 49 hold a `LICENSE` with SHA-256
`e6cbd45…` ("Copyright (c) 2024 Podlove") and 3 hold one with `8088fd6…` ("Copyright (c) 2019 Podlove"): the starting
and merge commits of pull request 500 and the starting commit of pull request 510. The two files have the same
1,064 bytes and differ in one line, the year in the copyright line; the text is MIT in both, and the scan's family is
`MIT` at all 52. So the licence file changed once, in the year, inside pull request 510 (its starting commit has
2019, its merge commit 2024), and the licence did not change. ex338's 13 commits hold one `LICENSE` (SHA-256
`a87fdbe…`), the file of the first batch.

### Files the scan did not pass, in any tree (`licence.nonok.tsv`)

Across the 65 trees (155 to 1,032 files each for radiator, 467 to 482 for ex338) every file is `ok` except these;
none is touched by a task except `sortable.js` above:
- `exclude:vendored`: `assets/vendor/` files (`sortable.js` in 28 trees, `topbar.js` in 52, `heroicons.js`, a whole
  `heroicons/` folder of 878 files in 6, `daisyui.js`, `daisyui-theme.js`, `quill.js`, `quill.snow.css`, `luxon.js`);
- `exclude:binary`: icons, JPEG, PNG and WebP images;
- `exclude:CC-NC`: `priv/repo/seeds/license.exs` in 4 trees (the starting and merge commits of radiator's pull
  requests 639 and 641). It is a seed list of Creative Commons licence names and URLs, which includes the
  non-commercial ones: data about licences, not code under one. A false positive of the scan's name match;
- `review:CC`: a feed fixture and two tests that name a Creative Commons licence
  (`test/support/fixtures/feeds/minimal.xml`, `test/radiator/podcasts/feed_sync/translator_test.exs`,
  `test/radiator/feeds/parser/handler_test.exs`) in 4 trees (pull requests 643 and 645). Not read further; no task
  touches them. Under the guide's rule 2 a workspace would hold only files that pass.

## The hold-out check, and what its hits are

Every file of each task folder but `integrity.patch` was compared with the bench's case files by lowercased,
whitespace-split words, as in the first batch: the bench side is 126,397 words (84,584 distinct 8-word and 90,118
distinct 12-word spans), the 34 tasks 161,464 words. Each shared span is classed, and only `to-read` would stop a task:

| Class | Distinct spans, 8 words | 12 words | (task, span) pairs, 8 words | 12 words | radiator 8 / 12 | ex338 8 / 12 |
|---|---:|---:|---:|---:|---:|---:|
| `common` (the span is in the cases of two or more of the bench's projects) | 11 | 3 | 317 | 90 | 247 / 69 | 70 / 21 |
| `syntax` (fewer than three words outside a fixed list of Elixir, HEEx and diff tokens) | 14 | 0 | 19 | 0 | 14 / 0 | 5 / 0 |
| `own-tree` (already in the project's tree at the starting commit) | 13 | 0 | 30 | 0 | 30 / 0 | 0 / 0 |
| `to-read` (none of these) | 4 | 0 | 4 | 0 | 4 / 0 | 0 / 0 |

(A span can be `own-tree` for one task and `to-read` for another: two of the four `to-read` spans are.)

I read the text of all 45 distinct (class, span) pairs on the build machine before the cases were deleted from it.
By kind, without the cases' text:
- **`common`: boilerplate.** 13 of the 14 spans are the layout the factory's one format took from the bench's
  `case.json` or repeats in `provenance.json`: the test folder and test-file suffix lists, and the baseline's two
  Ecto commands (`mix ecto.create` and `mix ecto.migrate`, which two or more of the bench's projects list as well).
  The 14th is a run of closing lines followed by `describe` in a diff. Every task has 10 of the 8-word `common` spans
  (11 in `radiator-pr-556`, 4 in radiator's last four tasks, whose baseline is another command) and, but for those
  four, 3 of the 12-word ones; they sit in `case.json` and `provenance.json`.
- **`syntax`: boilerplate.** Runs of closing lines (`end`, a closing `div`, `end)`), `@impl true`, `@doc """`, and
  the openers of the Ash sections that every Ash resource has (`attributes do`, `actions do`, `calculations do`),
  with at most two words of their own.
- **`own-tree`: boilerplate, not from the case.** The opening of an Ecto migration as `mix ecto.gen.migration` writes
  it, an `@doc` opening, the Ash resource openers, and lines of ExUnit tests (a `test` line, `describe`, an Ash
  error-tuple assertion): each occurs in radiator's own tree at the task's starting commit, so radiator had it
  before the pull request.
- **`to-read`: boilerplate on reading, listed for the manager.** All four spans are in `holdout.hits.tsv` (5 rows, as
  two of them occur in two files) and name the same case, pinchflat's:

| Task | File | Case file | Longest shared run (words, with / without diff markers) | What it is | How told |
|---|---|---|---:|---|---|
| `radiator-pr-500` | `reference.patch`, `incomplete.patch` | `reference.patch` | 11 / 7 | the opening lines of an Ecto migration (`use Ecto.Migration`, `def change do`) and its `alter` | the migration scaffold that `mix ecto.gen.migration` writes plus one keyword; the same span is `own-tree` for another radiator task |
| `radiator-pr-546` | `reference.patch` | `reference.patch` | 9 / 7 | the end of a function and the `@doc` opening of a function that returns a list | an idiom of three content words; the same span is `own-tree` for another radiator task |
| `radiator-pr-645` | `upstream-docs.patch` | `ticket.md` | 9 / 9 (two spans) | a Markdown table's rule row, bars and dashes only | punctuation; the dash-and-bar tokens are not in the `syntax` list, which is why the tool left it `to-read` |

  The longest run sharing the 8-word span, extended in both texts (`holdout.runs.tsv`, lengths only), is 11 words at
  most, so none reaches 12 words.

A positive control on a radiator task, a copy of `radiator-pr-541` whose hidden tests were replaced by one bench case's
hidden tests (`livebook-pr-2219`), gave 526 `to-read` spans of 8 words and 550 of 12 words, all naming that case, and
the result `review`. The repository rule was controlled in the first batch (five addresses) and is the same code.

## What was checked, and how

The method is the first batch's: the `LICENSE` file of each distinct commit's tree (65: radiator's 52 and ex338's 13)
scanned by the sister repository's `license_scan.py` with the tree's own licence family and holder, a verdict for every
file the task's four patches and its test-file lists touch (`licence.files.tsv`: 383 pairs, 381 `ok`), the lock file's
packages with their declared licences from the metadata inside each package's Hex tarball (the first 1 MiB of each of
378 tarballs, 42,295,296 bytes in all; nothing extracted), and the hold-out comparison with its three classes. The
trees are checked out from clones through a temporary index. Both clones are partial (cloned without file
contents), so the contents of the 2,129 files the trees need that the copies lacked (radiator 2,008, ex338 121) were
fetched once into the copies, 1,903,750 bytes (`run/fetch_blobs.sh`), before the run; the clones the other jobs use
were not changed. Wall time of the whole pass, 65 checkouts included: 81 seconds. The containers ran with
`--network none` and `--cpu-shares 256`; the Hex fetch, the fetch of file contents and the git dependencies' licence
files were the only network steps.

Added in this batch, with their scripts in `run/` and no change to `factory/tools/`:
- `run/git_dep_licences.sh` fetches the licence file of each git dependency at its pinned commit;
- `run/extra_checks.py` writes `deps.outside.tsv`, `deps.holdout.tsv`, `deps.holdout.tasks.tsv`, `deps.summary.tsv`
  and `holdout.runs.tsv`;
- `run/nonok_files.sh` writes `licence.nonok.tsv`.

The tools did not fail on radiator: `task_licence.py` read radiator's lock files and licence files, and
`task_holdout.py` classed its spans, as they did on ex338.

## What the checks cannot tell

- The licence scan reads notices. A file copied from elsewhere without its notice passes.
- `exclude:vendored` fails a task that adds a vendored file by its path, whatever the file's own header says: both
  failures here are a minified SortableJS that names MIT in its first line. The scan does not weigh that header.
- The dependency licences are what each package declares, not a scan of its files. Whether a list of several
  licences (`bcrypt_elixir`, `poolboy`) is a choice or a combination is not stated by Hex.
- A git dependency has no declaration; its licence file was read by hand at one commit, and `web_inspector`'s repository
  may add a licence later, which does not cover the pinned commit.
- The hold-out check finds shared wording of 8 words or more. A task that restates a case in other words, or shares
  shorter runs, passes. Statements (`ticket.md`) do not exist yet and must be checked when written.
- The `syntax` class is a fixed word list: it lacks Markdown table rules, which is why `radiator-pr-645` stays
  `review`. Not changed here, so that the tool's result is the one the tables show.
- `own-tree` trusts that the text was in radiator or ex338 before the pull request; it does not prove where they got it.
- The held-out dependency table goes by package metadata; a held-out project's code vendored into a package under
  another name would not show.

## Files

| File | What it holds |
|---|---|
| `licence.tasks.tsv` | per task: root licence file and families, `provenance.json`'s licence, files touched and passing, the result |
| `licence.files.tsv` | per (task, file): which parts of the task name it, the verdict at the starting and merge commits, the result |
| `licence.commits.tsv` | per commit: the licence file's SHA-256, the scan's counts by verdict |
| `licence.nonok.tsv` | the files that did not pass the scan in any tree, with the number of trees |
| `deps.tsv` | per locked package version: the declared licences, the class, the number of tasks that lock it |
| `deps.outside.tsv` | per (task, package): the locked packages outside the three licences and the git dependencies |
| `deps.summary.tsv` | per project and class: package versions and distinct packages |
| `deps.holdout.tsv`, `deps.holdout.tasks.tsv` | the packages that belong to a held-out project, and per task how many it locks |
| `gitdeps.tsv` | the git dependencies: the licence file fetched at the pinned commit, its SHA-256, what was read |
| `holdout.tasks.tsv` | per task: the repository check, name hits, shared spans by class for 8 and 12 words, the result |
| `holdout.hits.tsv` | per hit: task, task file, span length, the case's name and file, a span id (12 hex digits of its SHA-256), the class; never the text |
| `holdout.runs.tsv` | per `to-read` hit: the longest shared run around it, in words; lengths only |
| `holdout.json` | the check's counts |
| `run/` | `fetch_blobs.sh`, `run_p6_rest.sh`, `git_dep_licences.sh`, `extra_checks.sh` with `extra_checks.py`, `nonok_files.sh` |

## Exact commands

On the build machine, in a scratch folder: copies of the 34 task folders (`TASKS`), copies of bare partial clones of
`podlove/radiator` and `axelclark/ex338` (`CLONE_RADIATOR`, `CLONE_EX338`; the originals stay), a checkout of this
repository (`SRC`), the bench's case files copied to a temporary folder without `admission.json` (`BENCH`), the image
`python:3.12-slim-bookworm` that was already on the machine.

```sh
# the bench's cases, copied for the run and deleted after it (never into a repository)
tar -C <the bench's cases/ folder> --exclude=admission.json --exclude=README.md -cf - . | tar -C "$BENCH" -xf -

# file contents the partial clones lack, once, into the copies
CLONE=$CLONE_RADIATOR TASKS=$TASKS REPO=podlove/radiator WORK=$WORK  $SRC/docs/data/2026-11-12_pilot_licence_holdout_r2/run/fetch_blobs.sh
CLONE=$CLONE_EX338    TASKS=$TASKS REPO=axelclark/ex338  WORK=$WORK  $SRC/docs/data/2026-11-12_pilot_licence_holdout_r2/run/fetch_blobs.sh

# both checks
WORK=$WORK TASKS=$TASKS CLONES="$CLONE_RADIATOR $CLONE_EX338" BENCH=$BENCH SRC=$SRC LABEL=<label> \
  $SRC/docs/data/2026-11-12_pilot_licence_holdout_r2/run/run_p6_rest.sh

# the git dependencies' licence files, the extra tables, the files that did not pass
WORK=$WORK $SRC/docs/data/2026-11-12_pilot_licence_holdout_r2/run/git_dep_licences.sh
WORK=$WORK TASKS=$TASKS BENCH=$BENCH SRC=$SRC LABEL=<label> $SRC/docs/data/2026-11-12_pilot_licence_holdout_r2/run/extra_checks.sh
WORK=$WORK $SRC/docs/data/2026-11-12_pilot_licence_holdout_r2/run/nonok_files.sh
```

The positive control, as run, with the cases still in `BENCH`: a copy of one task folder with one case's
`reference-tests.patch` in place of its own, then `python -I factory/tools/task_holdout.py --bench "$BENCH" --holdout
factory/config/holdout.json --trees "$WORK/trees" --out <control>/holdout <the copy>` in the same container as the
other steps. The `$WORK/trees` folder, the control and the bench copy are deleted after the run.

## Provenance and licence

The tasks are cut from `podlove/radiator` and `axelclark/ex338`, both MIT at every commit used. The tables hold file
paths, verdicts, package names, the licences their metadata declares and the bench cases' names, never their text.
`license_scan.py` and `heldout_check.py` are copied from the sister repository, origin in `factory/tools/README.md`.
