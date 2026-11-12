# Pilot job P6: the licence scan and the hold-out check on the 16 checked ex338 tasks (E68)

Job P6 of the design note's pilot list (`docs/research/notes/task_factory_on_the_bench_engine.md`, section 9), on
the 16 checked tasks of P5's second run ([data](../2026-11-12_pilot_tasks_ex338_r2/README.md)). The tools are in
[`factory/tools/`](../../../factory/tools/README.md) and run on any list of task folders.

## Result

| Check | Tasks passing | What failed |
|---|---:|---|
| Licence: root licence at the starting commit is MIT, Apache-2.0 or BSD | 16 of 16 | nothing: every starting commit has `LICENSE`, MIT, copyright Axel Clark; `provenance.json` says MIT for all 16 |
| Licence: every project file the task touches has an `ok` verdict | 16 of 16 | nothing: 119 (task, file) pairs, 119 `ok` |
| Hold-out (a): repository not among the 12 projects, their organisations or names | 16 of 16 | nothing: `axelclark/ex338` |
| Hold-out: no case id or held-out repository name in any task text | 16 of 16 | nothing: 44 names looked for, 0 found |
| Hold-out (b): no 8- or 12-word span shared with the bench's 20 cases, other than boilerplate | 16 of 16 | nothing: every shared span is `common`, `syntax` or `own-tree` (below), none `to-read` |

**Both checks pass on all 16 tasks.** No task was moved or deleted; the tables are the result.

Dependencies: the starting commits lock 90 distinct Hex packages (140 package versions; 15 commits lock 90 packages,
one locks 72) and one git dependency. By the licences each package declares for its locked version: 78 packages
declare only MIT, Apache-2.0 or BSD by SPDX id; 7 declare them in other spellings (`Apache 2.0`, `BSD`); **5 declare
a licence outside the three:** `cowboy`, `cowlib` and `ranch` (ISC only), `bcrypt_elixir` (`BSD-3-Clause`, `ISC`,
`BSD-4-Clause`) and `poolboy` (`Unlicense`, `Apache 2.0`). The git dependency (`heroicons`, at two commits) has no
Hex metadata, and its licence was not read. The full table is `deps.tsv`.

What the guide's section 8 says about this: rule 3, "dependencies have their own licences": a session may read a
dependency's source under `deps/`, and a session that quotes a file without a passing verdict is left out. ISC sits
in the "not for now" row (E51), so a file of `cowboy`, `cowlib` or `ranch` would not pass. Whether a dependency's
licence also decides a task is not decided here.

## What was checked, and how

**The licence scan.** For each of the 23 distinct commits (16 starting commits and the merge commits that are not
also a starting commit), the tree was checked out from a clone and scanned with the sister repository's
`license_scan.py`, unchanged, with the tree's own licence family and holder taken from its root `LICENSE`. Every
tree gives the same picture (`licence.commits.tsv`): between 482 and 556 files, all `ok` but the licence file
(`ok:licence-file`), 21 binary files (`exclude:binary`: 20 PNG images and one icon) and `assets/vendor/sortable.js`
(`exclude:vendored`). No file carries a copyleft or other foreign licence notice. Per task, the files its reference
patch, hidden tests, partial fix and docs patch touch, and the test files its two test commands and its
`preservation_left_out` list name, were looked up in the starting tree (unless the task adds the file) and in the
merge tree (unless it deletes it). No task touches a binary or vendored file. `licence.files.tsv` lists every pair
with its verdicts.

**The dependencies.** The `mix.lock` of each starting commit gives the package, the version and the source. The
licences are those in the `metadata.config` of the package's own tarball for that version, from the Hex repository,
read from the tarball's first bytes; the package's code was not extracted or read.

**The hold-out check.** (a) The repository against `factory/config/holdout.json`, with the rule of
`Eab.BundleMaker.holdout!/3`. (b) Every file of each task folder but `integrity.patch` (the factory's fixed
early-exit text, the same in every task by design) against the bench's case files: `ticket.md`, `case.json` (with
the requirement sentences), `acceptance.patch`, `reference-tests.patch`, `upstream-tests.patch`, `reference.patch`,
`incomplete.patch` and `upstream-docs.patch`; the review record `admission.json` was left out. The method is
`heldout_check.py`'s: lowercased, whitespace-split words, and every run of 8 and of 12 words. The bench side has
126,397 words (84,584 distinct 8-word and 90,118 distinct 12-word spans), the 16 tasks 39,452 words.

Each shared span is classed, and only `to-read` would stop a task:

| Class | What it is | Distinct spans | (task, span) pairs, 8 words | 12 words |
|---|---|---:|---:|---:|
| `common` | the span occurs in the cases of two or more of the bench's projects | 6 | 66 | 0 |
| `syntax` | with the diff markers dropped, fewer than three words outside a fixed list of Elixir, HEEx and diff tokens (`end`, `do`, `def`, `else`, `nil`, `->`, `"""`, `@doc`, `\|>`, `</div>`, ...) | 13 | 15 | 1 |
| `own-tree` | with the diff markers dropped, the span already occurs in ex338's own tree at the task's starting commit | 7 | 21 | 0 |
| `to-read` | none of these | 0 | 0 | 0 |

What boilerplate looked like here, by kind and without the cases' text:
- `common`: the layout of `case.json`, which the factory's one format keeps from the bench's (the test folders and
  suffixes, the baseline's two Ecto commands). Every task has 4 or 6 of these.
- `syntax`: runs of closing lines in a diff (`end`, a closing heredoc, closing `div` tags) and a short `else`
  branch returning `nil`. The one 12-word hit is of this kind.
- `own-tree`: the opening lines of an Ecto migration as `mix ecto.gen.migration` writes them, a LiveView test's
  `conn` and `live` lines, and a request header line with a bearer token; ex338 had each of them before the pull
  request.

Every shared span was also read by eye on the build machine before the cases were deleted, and each fits its class.
A positive control, a copy of one task whose hidden tests were replaced by one bench case's hidden tests, gave 533
`to-read` spans of 8 words and 557 of 12 words, all naming that case, and the result `review`; a second control
held out `livebook-dev/livebook` (organisation, repository, name), `livebook-dev/kino` (organisation), the bench's
fork of `ash` (repository, name) and any `*/guardian` (name), and passed `axelclark/ex338`.

## What the checks cannot tell

- The licence scan reads notices. A file copied from elsewhere without its notice passes.
- The dependency licences are what each package declares in its metadata, not a scan of its files; a package may
  hold files under other terms. Whether a list of several licences is a choice or a combination is not stated by Hex.
- The `heroicons` git dependency's licence was not read.
- The hold-out check finds shared wording of 8 words or more. A task that restates a bench case in other words, or
  shares shorter runs, passes. Statements (`ticket.md`) do not exist yet (P7); the tools check them when they do.
- `own-tree` trusts that the text was in ex338 before the pull request; it does not prove where ex338 got it.
- The `syntax` class is a fixed word list; a real overlap made only of such words would be missed, at 8 words a
  small risk.

## Files

| File | What it holds |
|---|---|
| `licence.tasks.tsv` | per task: root licence file and families, `provenance.json`'s licence, files touched and passing, the result |
| `licence.files.tsv` | per (task, file): which parts of the task name it, the verdict at the starting and the merge commit, the result |
| `licence.commits.tsv` | per commit: the licence file's SHA-256, the scan's counts by verdict |
| `deps.tsv` | per locked package version: the declared licences, the class, the number of tasks that lock it |
| `holdout.tasks.tsv` | per task: the repository check, name hits, shared spans by class for 8 and 12 words, the result |
| `holdout.hits.tsv` | per hit: task, task file, span length, the case's name and file, a span id (12 hex digits of its SHA-256), the class; never the text |
| `holdout.json` | the check's counts |
| `run/run_p6.sh` | the run, with hosts and paths from the environment |

## Exact commands

On the build machine, in a scratch folder, with a copy of the 16 task folders, a bare clone of `axelclark/ex338`,
the bench's case files (copied there for the run and deleted after it), and the image `python:3.12-slim-bookworm`
that was already on the machine:

```sh
WORK=<scratch>/work TASKS=<scratch>/tasks CLONE=<clone>.git BENCH=<scratch>/bench_cases SRC=<checkout> \
LABEL=<label> docs/data/2026-11-12_pilot_licence_holdout/run/run_p6.sh
```

Wall time of the final pass 4.3 s with the trees already scanned and the metadata fetched; the first full pass took
3 min 34 s. The Hex fetch was the only network step; the containers ran with `--network none` and
`--cpu-shares 256`.

## Provenance and licence

The tasks are cut from `axelclark/ex338` (MIT). The tables hold file paths, verdicts, package names and the
licences their metadata declares, and the bench cases' names, not their text. `license_scan.py` and
`heldout_check.py` are copied from the sister repository, origin in `factory/tools/README.md`.
