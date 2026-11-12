# The Elixir/OTP pairs the dataset's projects need, added to the factory's image table

Registry row E84. A task is built on the Elixir and OTP of its own starting commit, read from the commit's files by
the factory's toolchain resolver (`factory/lib/eab/toolchain.ex`, factory README section 3.5) and looked up in the
image table `factory/config/toolchain_images.json`. A pair the table lacks is refused as `no_image:<elixir>/<otp>`.
The table held 13 pairs, and the screen of the dataset projects' newest candidates
([2026-11-12_alive_and_newest_screen](../2026-11-12_alive_and_newest_screen/README.md), its `classes.tsv` of 12:32)
found most of them on pairs it lacked: mbta/screens 0 of 150 on a pair the table held, supabase/realtime 0 of 150,
oli-torus 0 of 150, sanbase2 0 of 150. This job added every pair from Elixir 1.18 up that those candidates and the
projects' heads need, proved each one, and made no task.

The job began on the 21 projects of the first list. At 12:17 the owner cut the list to 16
([2026-11-12_dataset_projects](../2026-11-12_dataset_projects/README.md)); this page counts the 16, and three pairs
proved for the five that left serve none of the 16 and were not added (below).

**Result:** 23 pairs added, so the table holds 36. Each image was pulled by its digest on the data-mining machine,
started, named its own pair, and installed Hex 2.5.3 the way the engine's recipe does. One pair failed the Hex
install and stays out: Elixir 1.18.0 with OTP 27.1.3 (the TLS error of OTP 27.2). The factory now serves 994 of the
16 projects' 1,270 screened candidates with an image of Elixir 1.18 or newer (336 before), and all 16 heads. Two fixes
in the resolver came with it: a CI file's `${{ env.NAME }}` is read, and a line equal to the version named wins over a
longer one. The factory's tests: the format check passes; 245 passed, 0 failed, 10 excluded without Docker, and
255 passed, 0 failed with it (the last record 243 and 253); the parity test 6 of 6, not edited.

## The pairs added

Newest first. "Candidates" are the screened candidates whose image is that line after this job, by project; "heads"
the projects whose newest commit it serves. All three proofs passed for each. The full lines with their digests are
in [pairs.tsv](pairs.tsv) and in the table itself.

| Pair | Image tag (`hexpm/elixir:`) | Digest (`sha256:`) | Candidates | Heads |
|---|---|---|---|---|
| 1.20.5/29.1.2 | `1.20.5-erlang-29.1.2-ubuntu-noble-20261110` | `45f348a8…` | 5: dispatch (before on 1.20.4/29.1.2) | dispatch, flick |
| 1.20.4/29.1.1 | `1.20.4-erlang-29.1.1-ubuntu-noble-20260917` | `d6bafec5…` | 0 | jola.dev |
| 1.20.4/29.0.6 | `1.20.4-erlang-29.0.6-ubuntu-noble-20261024.1` | `27ad0b9b…` | 0 | youcongress |
| 1.20.3/28.3.3 | `1.20.3-erlang-28.3.3-ubuntu-noble-20260810` | `737cb889…` | 0 | croniq |
| 1.20.2/29.0.4 | `1.20.2-erlang-29.0.4-ubuntu-noble-20260730.1` | `e9301bad…` | 197: sanbase2 108, ambry 80, local_cents 9 | ambry, sanbase2, local_cents |
| 1.20.2/29.0.3 | `1.20.2-erlang-29.0.3-ubuntu-noble-20260610` | `935b5dda…` | 0 | notesclub |
| 1.20.2/29.0.2 | `1.20.2-erlang-29.0.2-ubuntu-noble-20260509.1` | `7e283082…` | 38: mbta/screens | — |
| 1.20.2/28.5.0.3 | `1.20.2-erlang-28.5.0.3-ubuntu-noble-20260610` | `f5f17916…` | 4: local_cents | — |
| 1.20.1/28.5.0.2 | `1.20.1-erlang-28.5.0.2-ubuntu-noble-20260509.1` | `89da83c1…` | 9: flick | — |
| 1.20.1/28.5 | `1.20.1-erlang-28.5-ubuntu-noble-20260509.1` | `73a56a08…` | 8: local_cents | — |
| 1.20.0/29.0.1 | `1.20.0-erlang-29.0.1-ubuntu-noble-20260509.1` | `37229009…` | 1: ambry | — |
| 1.19.5/28.5.0.4 | `1.19.5-erlang-28.5.0.4-ubuntu-noble-20260730.1` | `435d3028…` | 123: realtime | realtime |
| 1.19.5/28.5 | `1.19.5-erlang-28.5-ubuntu-noble-20260509.1` | `e0acecfc…` | 4: source-academy | source-academy |
| 1.19.5/28.3.2 | `1.19.5-erlang-28.3.2-ubuntu-noble-20260509.1` | `f471c668…` | 2: jola.dev | — |
| 1.19.5/28.3.1 | `1.19.5-erlang-28.3.1-ubuntu-noble-20260509.1` | `386aed59…` | 3: source-academy | — |
| 1.19.4/28.4 | `1.19.4-erlang-28.4-ubuntu-noble-20260509.1` | `ce3d7722…` | 42: sanbase2 | — |
| 1.19.4/28.3 | `1.19.4-erlang-28.3-ubuntu-noble-20260509.1` | `fa312d3b…` | 8: youcongress | — |
| 1.19.2/28.1.1 | `1.19.2-erlang-28.1.1-ubuntu-noble-20260509.1` | `bedf531f…` | 150: oli-torus | oli-torus |
| 1.19.1/28.1.1 | `1.19.1-erlang-28.1.1-ubuntu-noble-20260509.1` | `9623a535…` | 7: ambry | — |
| 1.18.4/28.0.2 | `1.18.4-erlang-28.0.2-ubuntu-noble-20260509.1` | `3f9b359f…` | 5: jola.dev | — |
| 1.18.4/27.3.4.10 | `1.18.4-erlang-27.3.4.10-ubuntu-noble-20260509.1` | `0034a20e…` | 27: realtime | — |
| 1.18.4/26.2.5.21 | `1.18.4-erlang-26.2.5.21-ubuntu-noble-20260810` | `18ca0c7f…` | 23: croniq | — |
| 1.18.3/27.3.3 | `1.18.3-erlang-27.3.3-ubuntu-noble-20260509.1` | `17af9f80…` | 7: source-academy | — |

Four lines serve only a project's head: that project's newest screened candidates were made before its head moved to
the pair. They were asked for by the brief, which named the heads' pairs as well.

## The three proofs

`run/prove.sh`, one container per proof from the pinned image, as the user 1000:1000 (the engine's workspace user
has that id), with the label `task-factory=1` and a CPU share of 256:
1. **The image starts:** `true` exits 0.
2. **It is the pair:** `elixir --version` names `Elixir <elixir>`, and the OTP release's `OTP_VERSION` file is the
   OTP of the line (four parts where the line has four, e.g. 28.5.0.4).
3. **Hex installs the way the engine does:** the `hexpm/elixir` images hold no CA certificates, and the engine's
   recipe installs the base's `ca-certificates` package before Hex (`lib/eab/fixtures.ex`, `dockerfile/4`). So the
   proof installs that package as root, then runs the recipe's command for Elixir 1.14 and newer as the user,
   `mix local.hex 2.5.3 --force && mix local.rebar --force`, and `mix hex.info` must name Hex 2.5.3. Run first
   without the certificates, the install stops with `no_cacerts_found`; that trial run is not counted.

27 pairs were proved; all started and named their pair, and 26 installed Hex. The one that did not:

| Pair | What failed | Candidates it would serve |
|---|---|---|
| 1.18.0/27.1.3 | `mix local.hex`: the TLS handshake with builds.hex.pm ends in `unsupported_certificate`, `key_usage_mismatch`, the error of OTP 27.2 and 27.2.1 (the table's note) | 1, flick (it also lacks a Postgres 16 line) |

The table's note now names OTP 27.1.3 beside 27.2, and `toolchain_test` refutes it.

## The pairs left out

| Pair | Why | Candidates of the 16 |
|---|---|---|
| 1.18.1/27.2 | OTP 27.2 is never added (the table's note) | 1: ambry |
| 1.18.2/27.2.2 | a patch release of OTP 27.2 | 1: ambry |
| 1.18.0/27.1.3 | the Hex proof failed (above) | 1: flick |
| 1.19.7/28.1.1, 1.18.0/27.3.4.13, 1.18.1/27.3.4.12 | proved (all three proofs passed), but they serve only safira's head, refiner's head, and hexpm/preview's head and 1 candidate: projects that left the list at 12:17 | 0 |
| 1.20.4/29.1 | hexpm's CI names OTP `29.1` through setup-beam, which takes the newest 29.1 release; the table's 1.20.4/29.1.2 serves it by prefix, and an exact line would change that | 0 lost: hexpm's 129 were already served |
| below Elixir 1.18 | the dataset's floor (`elixir_before_1.18`, dataset rules section 2) | 1.17.3/27.3.4 mbta/screens 105, 1.16.2/26.2.1 youcongress 40, 1.13.4/25.3.2 source-academy 25, 1.14.2/25 dispatch 19, notesclub 7 on four pairs, 1.17.3/27.0.1 flick 1, 1.16.2/26.2.3 ambry 1 |

## Per project

From `run/resolve.exs`: the real resolver over every screened candidate's starting commit and each head (the
commit's root files and `.github/workflows/`, read from the screen's clones), once with the table before this job and
once after. "Served" means the image is a line of Elixir 1.18 or newer. "Another need" counts the served candidates
for which the screen notes something else the factory lacks today (a Postgres or other service line, a release
file, Rust or Python); those are for each project's own job. [summary.tsv](summary.tsv); every commit in
[resolve_before.tsv](resolve_before.tsv) and [resolve_after.tsv](resolve_after.tsv).

| Project | Candidates screened | Served before | Served after | Of those, another need | Not served after |
|---|---|---|---|---|---|
| ambry-app/ambry | 92 | 1 | 89 | 67 | 1.18.1/27.2 1, 1.18.2/27.2.2 1, below 1.18: 1 |
| axelclark/ex338 | 42 | 17 | 17 | 0 | below 1.18: 25 |
| bikebrigade/dispatch | 51 | 5 | 5 | 0 | below 1.18: 46 |
| blablatdinov/croniq | 24 | 0 | 23 | 23 | below 1.18: 1 |
| hexpm/hexpm | 150 | 150 | 150 | 72 | — |
| joladev/jola.dev | 7 | 0 | 7 | 2 | — |
| mbta/screens | 150 | 7 | 45 | 0 | below 1.18: 105 |
| nerves-hub/nerves_hub_web | 150 | 150 | 150 | 150 | — |
| notesclub/notesclub | 7 | 0 | 0 | 0 | below 1.18: 7 |
| santiment/sanbase2 | 150 | 0 | 150 | 42 | — |
| Simon-Initiative/oli-torus | 150 | 0 | 150 | 150 | — |
| source-academy/backend | 39 | 0 | 14 | 6 | below 1.18: 25 |
| supabase/realtime | 150 | 0 | 150 | 0 | — |
| youcongress/youcongress | 57 | 0 | 8 | 0 | below 1.18: 49 |
| zorn/flick | 30 | 6 | 15 | 0 | 1.18.0/27.1.3 1, below 1.18: 14 |
| zorn/local_cents | 21 | 0 | 21 | 21 | — |
| **All 16** | **1,270** | **336** | **994** | **533** | **276** |

"Served before" is the same resolver code with the old table. Only one pick changed for a commit served before:
dispatch's 5 candidates and its head, which name `1.20` and `29`, move from 1.20.4/29.1.2 to 1.20.5/29.1.2, the newest
pair that matches, as setup-beam reads those versions. ex338's 17 stay on 1.18.3/27.3 (below).

## How the resolver reads the loose versions

| Project, where | The files say | Line taken | Right? |
|---|---|---|---|
| dispatch, CI | setup-beam `elixir-version: '1.20'`, `otp-version: '29'` | 1.20.5/29.1.2 | yes: setup-beam (version-type loose, its default) takes the newest release that starts with each |
| hexpm, CI | setup-beam, `otp-version: ${{ env.otp }}` with `env: otp: 29.1`, `elixir: 1.20.4` | 1.20.4/29.1.2 | yes, the same rule |
| croniq head | `.tool-versions` `elixir 1.20.3 1.20.1 1.20.2`, no `erlang` line; CI setup-beam `otp-version: '28.3'` | 1.20.3/28.3.3 | yes: Elixir from `.tool-versions` (its first version), OTP the newest 28.3 as setup-beam takes it; Docker Hub has no image for 1.20.3 with OTP 28.3 itself |
| croniq, older | CI setup-beam `'1.18'`, `'26'` | 1.18.4/26.2.5.21 | yes: the newest 1.18 and the newest OTP 26 with an image for it |
| realtime, older | `.tool-versions` and `mise.toml` `erlang 27`; `mise.lock` pins 27.3.4.10 at all 27 commits | 1.18.4/27.3.4.10 | yes: the line added is the locked version, the only 1.18.4/27 line. The resolver does not read `mise.lock` |
| realtime, newer | `mise.toml` `erlang = "28.5.0.4"` (four parts) | 1.19.5/28.5.0.4 | yes: four parts are read and matched exactly |
| source-academy, 2025 to 2026 | CI `env: ELIXIR_VERSION: 1.18.3`, `OTP_VERSION: 27.3.3`, then `elixir-version: ${{ env.ELIXIR_VERSION }}`; `mix.exs` `~> 1.10` | 1.18.3/27.3.3 (before: `no_image:1.10/-`) | fixed in this job (below) |
| ex338 | `.tool-versions` `erlang 27.3` | 1.18.3/27.3 | yes, kept by the second fix (below) |

### The two fixes

1. **`${{ env.NAME }}` in a CI file** (`ci_versions/1`, `env_version/2`): source-academy's workflows set the versions
   as `env:` values and pass them to setup-elixir by reference. The resolver read nothing there and fell back to
   `mix.exs`'s `~> 1.10`, so 7 candidates the project builds on 1.18.3/27.3.3 were refused as `no_image:1.10/-`, and
   one on 1.19.5/28.3.1 got 1.19.5/28.4.1 (it read `~> 1.19` and no OTP). Now a value `${{ env.NAME }}` is the
   version of the file's own `NAME:` line; a name the file does not set gives nothing, as before. Test: "a workflow's
   ${{ env.NAME }} is the version its env block sets for NAME".
2. **An equal line wins over a longer one** (`image/4`): the resolver took the newest line that matches by prefix,
   so `27.3` matched both 1.18.3/27.3 and the new 1.18.3/27.3.3 and took 27.3.3. With the new lines that would have
   moved ex338 (`erlang 27.3`) to 27.3.3, source-academy's `28.5` to 28.5.0.4 and local_cents's `28.5` to 28.5.0.2,
   none of which the projects name. Now, in each of the two versions, a line equal to the version named wins; a
   version with fewer parts still takes the newest line that matches. The old table had no such overlap, so no pick
   made with it changes. Test: "a line equal to the version named wins over a longer one; a shorter version takes
   the newest line".

`toolchain_test`'s table test also checks that every image's tag names its own pair and that no pair is listed twice.

## Tests

`run/tests.sh` (the test steps of [2026-11-12_factory_data_mining_machine](../2026-11-12_factory_data_mining_machine/README.md),
copied into `run/`) in the tooling image `etf-tooling:20261112`, as the user 1000:1000, two CPUs, CPU share 256, on
the final tree (36 lines):

| Step | Result | The last record (E84's 1.20.4/29.1.2 line, nerves_hub_web's gaps) |
|---|---|---|
| format check | passes | passes |
| without Docker (`--warnings-as-errors`) | 245 passed, 0 failed, 10 excluded | 243 passed |
| with Docker | 255 passed, 0 failed | 253 passed |
| parity test (`test/eab/bench_parity_test.exs`) | 6 of 6, file not edited | 6 of 6 |

The two new tests are in `toolchain_test` (23 tests there, all passed). Two earlier runs: on the tree before the
second fix and the second batch of pairs, 244 passed without Docker and 254 with it, with the format check failing on
one line of a new test (fixed); on the 39-line table, 245 and 255, 0 failed.

## Files

| File | What |
|---|---|
| [pairs.tsv](pairs.tsv) | the 27 pairs proved: the image with its digest, the pull and the three proofs, the candidates and heads each serves after this job (0 for the four not added), the versions the image printed (and the Hex error) |
| [summary.tsv](summary.tsv) | per project: candidates, served before and after, served with another need, what is not served |
| [resolve_before.tsv](resolve_before.tsv), [resolve_after.tsv](resolve_after.tsv) | every screened candidate of the 16 and each head: repository, pull request number (`head` for the head), starting commit, the Elixir and OTP the resolver reads and from which file, the line it takes (`ok:<pair>`) or the refusal, `exact` or `prefix` |
| [lookup.tsv](lookup.tsv) | the Docker Hub lookups of the 27 pairs, as `run/lookup.sh pair` printed them |
| `run/lookup.sh` | the lookups: `pair`, through `factory/scripts/toolchain_image.sh`, and `otps`/`elixirs` listings for the loose versions |
| `run/prove.sh`, `run/prove_all.sh` | the three proofs for one pair, and the driver over a list of pairs (one pull at a time; waits while a container that is neither the factory's nor the bench's standing service runs; stops under 700,000,000,000 free bytes) |
| `run/tests.sh`, `run/test.sh`, `run/t0_formatter.exs`, `run/docker_shim.sh` | the factory's checks |
| `run/list.sh`, `run/resolve.sh`, `run/resolve.exs`, `run/summary.sh`, `run/pairs_table.sh` | the commits to read, the resolver over them in the tooling image, and the two tables |

## Commands

On the data-mining machine, as the user that owns the factory folder; `WORK` is its job folder, `SRC` a copy of
`factory/` from this commit, `CLONES` and `CLASSES` the screen's clones and `classes.tsv`, `PROJECTS` the dataset's
`projects.tsv`, `OLD_TABLE` the table before this job (`git show 87895b4:factory/config/toolchain_images.json`).

```bash
export SRC=$WORK/src LABEL=task-factory=1
# 1. lookups and proofs, one pair per line ("1.20.5 29.1.2"), two batches as the screen grew
PAIRS=$WORK/pairs.txt OUT=$WORK/out/all CA=apt run/prove_all.sh
PAIRS=$WORK/pairs2.txt OUT=$WORK/out/all2 CA=apt run/prove_all.sh
# 2. the factory's checks
OUT=$WORK/out/tests IMAGE=etf-tooling:20261112 HEX_CACHE_ID=etf-hex-packages-v1 run/tests.sh
# 3. the resolver over every screened commit and each head, with the old and the new table
CLASSES=$CLASSES CLONES=$CLONES PROJECTS=$PROJECTS run/list.sh > $WORK/out/list.tsv
export CLONES LIST=$WORK/out/list.tsv IMAGE=etf-tooling:20261112
TABLE=$OLD_TABLE run/resolve.sh > resolve_before.tsv
TABLE=$SRC/config/toolchain_images.json run/resolve.sh > resolve_after.tsv
CLASSES=$CLASSES run/summary.sh resolve_before.tsv resolve_after.tsv > summary.tsv
run/pairs_table.sh resolve_after.tsv $WORK/out/all/proofs.tsv $WORK/out/all2/proofs.tsv > pairs.tsv
```

## Provenance and licence

The images are the Hex team's `hexpm/elixir` builds on Docker Hub (ubuntu-noble bases), each pinned by the digest
Docker Hub listed for its tag on 2026-11-12. The candidates and their starting commits are the screen's, from the
projects' public GitHub repositories; the version files were read from local clones. Free space on the machine's
disk went from 831,329,062,912 bytes before the first pull to 815,651,303,424 after the last tests (other jobs wrote to the
same disk meanwhile); 27 images were pulled, one per pair (1.20.5/29.1.2 by the trial run of the scripts). No task
was made or checked, no project's environment was set up, and no request went to a model. These tables and scripts
are published under this repository's licence.
