# Licence and hold-out checks for task folders

Two checks every task must pass before it, or a session on it, is used for training or published (design note
`docs/research/notes/task_factory_on_the_bench_engine.md`, sections 4.2 and 8; guide
`docs/research/notes/task_collection_guide.md`, section 8):

1. **Licence (E51):** every project file the task touches has a passing verdict from the per-file licence scan, read
   on the project's tree at the task's commits; the project's root licence is MIT, Apache-2.0 or BSD. The licences
   of the locked Hex dependencies are listed beside it.
2. **Hold-out (E12):** the task's repository is not one of the bench's 12 projects or their organisations
   (`config/holdout.json`), and no text of the task shares a run of 8 or 12 words with the bench's 20 cases, except
   text that several held-out projects share or that the task's own project already held.

The checks drop nothing: they write tables, and whoever runs the factory decides.

## Files

| File | What it does |
|---|---|
| `check_tasks.sh` | the wrapper: checks out each commit's tree from a clone (through a temporary index, so the clone is only read), runs the steps below in a Python container with no network, and fetches the Hex metadata with `curl` on the host when `HEX_FETCH=1` |
| `task_folder.py` | the reader of a task folder in the one format (`factory/README.md`, section 3): the project files a task touches (its four patches and its three test-file lists) and its texts |
| `task_licence.py` | `scan-trees` (the root licence file, then `upstream/license_scan.py` on each tree), `join` (a verdict per touched file and per task), `locks` (the packages in each starting commit's `mix.lock`), `deps` (each package's own licences for the locked version, from the `metadata.config` in its Hex tarball) |
| `task_holdout.py` | the repository and name check, and the 8- and 12-word spans against the bench's case files, with each hit classed `common`, `own-tree` or `to-read` |
| `upstream/license_scan.py`, `upstream/heldout_check.py` | the sister repository's two tools, copied unchanged (origin below) |

## Running

```sh
WORK=<scratch folder> CLONES="<git dir> ..." BENCH_CASES=<the bench's cases/ folder> HEX_FETCH=1 \
DOCKER_RUN_ARGS="--label <label> --cpu-shares 256" LOCAL_SPANS=$WORK/LOCAL_spans.json \
  factory/tools/check_tasks.sh <task folder or folder of task folders> ...
```

- `CLONES`: git directories that hold the tasks' starting and merge commits; the first that holds a commit is used.
- `BENCH_CASES`: unset skips the hold-out text check. The case files are read in place and must never be copied into
  a repository; `LOCAL_SPANS` (inside `WORK`) holds the shared spans' text for reading on the same machine and is
  deleted with the cases.
- `IMAGE`: any Python 3.9+ image (default `python:3.12-slim-bookworm`); the scripts use the standard library only.

Output in `WORK`: `licence.tasks.tsv`, `licence.files.tsv`, `licence.commits.tsv`, `deps.tsv`, `locks.tsv`,
`holdout.tasks.tsv`, `holdout.hits.tsv`, `holdout.json`, and the scan of each tree in `trees/<commit>.scan.tsv`.

## Rules the scripts apply

- A touched file is checked in the starting commit's tree (unless the task adds it) and in the merge commit's tree
  (unless the task deletes it). It passes when every verdict found starts with `ok` (`ok`, `ok:notice`,
  `ok:licence-file`); `review:` and `exclude:` fail.
- The scan's own licence family and holder regex come from the root licence file at that commit (its signature
  families and its first copyright line).
- A hold-out hit is `common` when its span occurs in the cases of two or more of the bench's projects, `own-tree`
  when it occurs in the task's project at the starting commit, else `to-read`. A task with a `to-read` hit or a name
  hit is `review` until someone reads it; one whose repository is held out is `fail`.
- The tables carry a span id (12 hex digits of the span's SHA-256), never the span's text.

## Origin of the copied tools

| File | Repository | Commit | Path | SHA-256 |
|---|---|---|---|---|
| `upstream/license_scan.py` | `github.com/Cinderella-Man/llms-on-crypto-mining-rigs` | `8901e4aac8990d4e6d6f3ea698a3008d2932d1d9` (last change; unchanged at `cfcc4ee4d36a560280af78ee685411315d1409b1`) | `bench/agentic_data/license_scan.py` | `29d1a84760e206faec05e3cc2b1fc782dde3d8451e62f14db778c6ea179c96ce` |
| `upstream/heldout_check.py` | the same | the same | `bench/agentic_data/heldout_check.py` | `4d824121950822168f1f0f329b6a063cfdb7a7df4c4b9d506fb9be4a1396e92e` |

`license_scan.py` runs as it is. `heldout_check.py` is kept for its method only: it imports the sister's `agx.py`,
which loads the sister's sandbox at import time, and it reads the sister's session format, so `task_holdout.py`
reimplements its two parts (lowercased whitespace-split words, and N-word spans that keep the first file they were
seen in) with a reader for task folders.
