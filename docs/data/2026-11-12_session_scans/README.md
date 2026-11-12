# The session scans on the teacher's first 16 sessions (E87, E109)

The two session rules of [the dataset's rules](../../dataset_rules.md), section 6, built as
[`factory/tools/session_scans.py`](../../../factory/tools/session_scans.py) (what it counts:
[`SESSION_SCANS.md`](../../../factory/tools/SESSION_SCANS.md)) and run once on every stored session of the teacher's
first run ([teacher_first_sessions](../2026-11-12_teacher_first_sessions/README.md)): 16 attempts at 15 cases of
`axelclark/ex338`, 13 kept and 3 not kept. A session is dropped when it read or printed a file of a dependency whose
licence is outside the list (`quotes_dependency_outside_licence_list`) or a file of a held-out project's own package
(`quotes_held_out`), and marked, apart from the verdict, when a command tried to reach the network
(`tries_to_leave_sandbox`, E109).

**Result: all 13 kept sessions stay kept.** No session quoted a dependency outside the licence list, none quoted a
held-out project's package, and nothing is left for a reading by hand: all 16 sessions `pass`.

- **4 sessions quoted dependency files, 15 files in all, every one under MIT or Apache-2.0:** `ex338-pr-1350`
  (kept): Ecto SQL 3.11.3 (Apache-2.0), Phoenix 1.7.12 (MIT) and Plug 1.16.1 (Apache-2.0), one file each;
  `ex338-pr-1457` (kept): Phoenix 1.7.21, 4 files, and Plug 1.18.0, 3 files; `ex338-pr-1460` (kept): EctoEnum 1.4.0
  (MIT), 3 files; `ex338-pr-1451` (not kept): Jason 1.4.4 (Apache-2.0), 2 files. No standard-library file was read.
- **2 sessions tried to reach the network, 7 tries in all; every one failed, as the sandbox has none:**
  - `ex338-pr-1350` (kept), 4 tries in 3 turns: turn 18 `git ls-remote` of a GitHub URL naming the project's
    repository, turn 19 a name lookup of github.com and a `/dev/tcp` connection to it, turn 44 a `/dev/tcp`
    connection to a public address. This is the try registry E109 was opened for; the scan finds it and three more.
  - `ex338-pr-1446` (not kept), 3 tries in 2 turns: turn 21 `git ls-remote` of the project's repository, turn 84 a
    name lookup of the Ubuntu package archive and `apt-get update`.
  - Apart from these, two probes of the case's own database on `localhost` (`ex338-pr-1446` turn 18,
    `ex338-pr-1450` turn 11) are recorded as `loopback`: the database shares the sandbox's network, so they do not
    leave it.
- **Counted apart, not quotes:** 49 listings (file names only) in 2 sessions, 189 lines of stack frames and
  messages naming a dependency or standard-library file in 9 sessions, 116 lines that mention a dependency path in
  other text in 3 sessions (the engine's own seed file of paths and checksums, which two sessions printed, and lists
  of the build's load paths), and 1 search of one dependency file without a hit.
- **One tool result was never shown to the model:** the last call of `ex338-pr-1451`, stopped by its token budget.
  It is scanned anyway and holds nothing.

## Per session

| Case | Attempt | Kept | Verdict | Dependency files quoted | Network tries | Listings | Trace lines | Mention lines |
|---|---|---|---|---|---|---|---|---|
| ex338-pr-1350 | 20261112-153206-f5d6163e | yes | pass | 3: ecto_sql 1, phoenix 1, plug 1 | 4 | 35 | 9 | 60 |
| ex338-pr-1390 | 20261112-151610-54d3f177 | yes | pass | 0 | 0 | 0 | 11 | 1 |
| ex338-pr-1392 | 20261112-150900-3157aa83 | yes | pass | 0 | 0 | 0 | 0 | 0 |
| ex338-pr-1394 | 20261112-145706-2c3a6c63 | no | pass | 0 | 0 | 0 | 0 | 0 |
| ex338-pr-1394 | 20261112-160105-8e8bc313 | yes | pass | 0 | 0 | 0 | 0 | 0 |
| ex338-pr-1395 | 20261112-145221-bbcf6549 | yes | pass | 0 | 0 | 0 | 0 | 0 |
| ex338-pr-1411 | 20261112-144837-26fdf2e0 | yes | pass | 0 | 0 | 0 | 0 | 0 |
| ex338-pr-1446 | 20261112-141318-80795bd9 | no | pass | 0 | 3 | 14 | 3 | 55 |
| ex338-pr-1450 | 20261112-140710-417194c7 | yes | pass | 0 | 0 | 0 | 8 | 0 |
| ex338-pr-1451 | 20261112-133250-aad90564 | no | pass | 2: jason 2 | 0 | 0 | 29 | 0 |
| ex338-pr-1452 | 20261112-131816-8c1b102a | yes | pass | 0 | 0 | 0 | 2 | 0 |
| ex338-pr-1457 | 20261112-130557-011a1bb0 | yes | pass | 7: phoenix 4, plug 3 | 0 | 0 | 95 | 0 |
| ex338-pr-1458 | 20261112-125647-9e23dbf9 | yes | pass | 0 | 0 | 0 | 0 | 0 |
| ex338-pr-1460 | 20261112-123709-68fbd7b4 | yes | pass | 3: ecto_enum 3 | 0 | 0 | 29 | 0 |
| ex338-pr-1461 | 20261112-123224-21ff4ec2 | yes | pass | 0 | 0 | 0 | 3 | 0 |
| ex338-pr-1463 | 20261112-122138-217eee81 | yes | pass | 0 | 0 | 0 | 0 | 0 |

## The dependency tables

Each case's table was read from the sandbox image its session ran in (`run/extract_sandbox.sh`), offline: the
workspace's `mix.lock` and every `deps/<dep>/hex_metadata.config`, as installed. The 15 cases have 69 or 81 or 84
dependency folders each. Packages in them that the scan would not have passed, had a session quoted them (none was
quoted):

| Package | Cases | Why |
|---|---|---|
| bcrypt_elixir 3.1.0, 3.3.0 | 15 | its metadata lists BSD-3-Clause, ISC and BSD-4-Clause; BSD-4-Clause is outside the list, and Hex does not say whether the three are a choice or parts: `unclear` |
| poolboy 1.5.2 | 6 | Unlicense and Apache 2.0: `unclear` for the same reason |
| heroicons (git) | 15 | a git dependency with no Hex metadata: licence not read, `unclear` |
| igniter 0.5.51 | 14 | its source link is `ash-project/igniter`: the organisation of a held-out project (Ash), not its repository; hold-out `unclear` |
| vega_lite 0.1.9, 0.1.11 | 15 | its source link is `livebook-dev/vega_lite`: the organisation of a held-out project (Livebook), not its repository; hold-out `unclear` |

No package of the 15 tables is a held-out project's own.

## Files

| File | What it is |
|---|---|
| [`verdicts.tsv`](verdicts.tsv) | one verdict line per session (columns in [`SESSION_SCANS.md`](../../../factory/tools/SESSION_SCANS.md)) |
| [`evidence.tsv`](evidence.tsv) | one row per finding: turn, tool call, finding, package, version, licence, path or host, how, lines; never the quoted text |
| [`deps_by_case.tsv`](deps_by_case.tsv) | the 15 cases' dependency tables, with a `case` column first |
| [`summary.json`](summary.json) | the counts |
| [`run/extract_sandbox.sh`](run/extract_sandbox.sh) | reads each case's dependency metadata from its sandbox image (no network, read-only root, removed after) |
| [`run/scan.sh`](run/scan.sh) | makes the dependency tables and runs the scan, in a Python container with no network |

## Exact commands

On the data-mining machine, as its work user, in the job's folder (`$JOB`), with `$SESSIONS` the private copy of the
raw sessions (the engine's run folders, byte for byte, with their index `sessions.tsv`):

```sh
# the tests, on made-up sessions: 32 tests, OK (Python 3.12.16)
docker run --rm --network none --cpu-shares 256 -v $JOB/src:$JOB/src:ro -w /tmp python:3.12-slim-bookworm \
  python -I -W error::ResourceWarning $JOB/src/factory/tools/test_session_scans.py

SESSIONS=$SESSIONS WORK=$JOB/work PROJECT=axelclark__ex338 run/extract_sandbox.sh
SESSIONS=$SESSIONS WORK=$JOB/work OUT=$JOB/out TOOLS=$JOB/src/factory/tools PROJECT=axelclark__ex338 run/scan.sh
```

## Provenance

- The tool at this commit: `session_scans.py` SHA-256 `2d0bed2832535cc0a27b68390f9c7b44ebe630fbe9518fecb419302ee627e03d`,
  its tests `d6f7043e602d52b88189f1e966004c051c1491c39c9d6814420e70cc0ccf3c0d`, `task_licence.py` (unchanged)
  `58a4ff6af69b9084147f3d164e42c9e4c3248d36748d83af688de7bb9be32118`, `config/holdout.json`
  `905db1a985ceed776ad6b76c48a6c202ceac421e8f771eb12a30074f51ca8d39`.
- Python image `python:3.12-slim-bookworm`, id `sha256:935c3c5b12357a7e10caa9c1e6ca5692344d97cf229832ef584be2cec9fc03df`.
- The sessions: the 16 attempts of [teacher_first_sessions](../2026-11-12_teacher_first_sessions/README.md), read in
  the owner's private copy, which is not published. On all 16, every tool result in Pi's log equals the result in the
  last stored request, so the log is what the model was shown.
- The sandbox images: the 15 workspace images named in each attempt's `runtime.json`, still on the data-mining
  machine; their metadata was read on 2026-11-12, the scan ran at 20:15 UTC.
- No model was asked anything, nothing was downloaded, and no stored session was changed.

## Licence

The tables hold paths, package names, licence names, links and counts taken from the packages' own metadata, and no
text of any session or package. The dataset's own licence is not final ([rules](../../dataset_rules.md), section 9).
