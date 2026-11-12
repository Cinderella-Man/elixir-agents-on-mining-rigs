# Factory job T8: extra packages and release files per task, and the mirror as backup (E68)

`factory/README.md` section 7, row T8; section 6, changes 3 and 4, with change 3 widened to a release file. The
third pilot application, `nerves-hub/nerves_hub_web`, cannot start its tests without the program `fwup`, which its
own CI installs from fwup's `.deb` on GitHub, not from the distribution, and some of its tests need the distribution
packages `xdelta3` and `mtools` ([pilot data](../2026-11-12_pilot_env_nerves_hub_web/)). A task can now ask for both
kinds. A task that asks for nothing extra gets the bench's workspace recipe byte for byte.

## What changed

- **Distribution packages.** `runtime.packages`, a list of package names, each matching `[a-z0-9][a-z0-9+.-]*`
  (at most 100 characters, no repeats), so a name cannot carry a shell command. One more line in the toolchain stage,
  right after the bench's own system packages, installs them with `apt-get` (or `apk` on an Alpine image).
- **Release files.** `runtime.release_files`, a list of `{"url", "sha256", "kind"}`; the one kind is `deb`. The URL
  must be `https`, with no user part, on a host in `EAB_RELEASE_FILE_HOSTS` (empty by default). New
  `lib/eab/release_files.ex`: before the image build the engine fetches each file, following redirects only to
  allowed hosts, checks its SHA-256, keeps it in its data folder and puts it into the build folder under its SHA-256.
  One more line mounts that folder for that step only, checks each SHA-256 again with `sha256sum -c` and installs the
  files with `apt-get install`; a mismatch fails the build. The URL never enters the recipe.
- **Both lists** are checked by `Eab.TaskContract.runtime_extras!/1` (the import check also refuses a host that is
  not allowed), and are part of `runtime`, which already keys the image and the build seed. Absent or empty, the
  recipe is the bench's.
- **The mirror.** `lib/eab/source.ex` fetches the commit by its id from upstream; when that fails, from the mirror
  named for the repository in the JSON file `EAB_MIRRORS` points at. The revision and the tree are checked either
  way. The receipt has `"fetched_from": "upstream"`, or `"mirror"` and the mirror's address.
- `config/runtime.exs` reads `EAB_RELEASE_FILE_HOSTS` and `EAB_MIRRORS`; `compose.yaml` passes them through.
- **Tests.** `task_contract_test` (1 new: valid lists, 23 refused forms and hosts, and no host allowed by default),
  `fixtures_test` (1 new: the recipe with each list and both, empty lists give the bench's recipe, the lines key the
  build seed), new `release_files_test.exs` (2: fetch through an allowed redirect, reuse, a wrong checksum, a host
  and a redirect that are not allowed, with a stand-in for the HTTP client), `source_test` (1 new, two local
  repositories: from upstream, from the mirror when upstream is gone, a wrong tree from the mirror, a mirror without
  the commit, no mirror named) and new `runtime_extras_docker_test.exs` (2, below). `bench_parity_test.exs` is
  untouched.

**The Docker test.** It takes a made-up task's recipe with one distribution package (`xdelta3`) and one release file,
a `.deb` the test builds itself with `dpkg-deb` and serves to the engine's fetch through a stand-in HTTP client, and
builds the lines the recipe adds on the tooling image as the base. Both are installed (`dpkg-query`), both programs
run, and the file leaves no copy in the image. A second build with a file whose bytes do not match its checksum
fails at `sha256sum -c` and leaves no image. The rest of the toolchain stage is not built, because it downloads the
bench's build tools and Hex; the one download is `xdelta3` from the base image's distribution. No real release file
was fetched.

## Files

| File | What it holds |
|---|---|
| `README.md` | this page |
| `tests_compared.tsv` | one line per test: its state in T7's two runs and in T8's two runs, and the verdict (`same`, `differs`, `gone: …`, `new`) |

The code is in `factory/`, this repository's licence; the tables are made from the test runs, nothing third-party.

## Commands (on the build machine, in the work folder with `src/` and `run/`)

```
export WORK=$PWD LABEL=pascal-quants=1
TAG=t8_format run/test.sh format
TAG=t8_unit run/test.sh unit
TAG=t8_docker run/test.sh docker
run/compare.sh t7c_unit t7c_docker t8_unit t8_docker > tests_compared.tsv
```

`test.sh`, `docker_shim.sh`, `t0_formatter.exs` and `compare.sh` are the earlier jobs'
([T0](../2026-11-12_factory_t0/README.md), [T4](../2026-11-12_factory_t4/)); no new script. Every step runs
`mix test --warnings-as-errors`. A first run (`t8a`) gave the same unit counts (198 passed, 8 excluded) and a format
failure in one new test, fixed before `t8`.

## Counts

| | T7 (`t7c`) | T8 |
|---|---|---|
| format check | passes | passes |
| without Docker | 193 passed, 0 failed, 6 excluded | 198 passed, 0 failed, 8 excluded |
| with `EAB_DOCKER_TESTS=1` | 199 passed, 0 failed, 0 excluded | 206 passed, 0 failed, 0 excluded |

`tests_compared.tsv` (207 lines, the first is the header): 199 tests end as in T7, none differs, none is gone; 7 are
new and pass (the 2 Docker tests are excluded without Docker). `bench_parity_test` passes 6 of 6 in both runs,
untouched.

Free space on the build machine's `/`: 645,939,388,416 bytes before (04:38:48), 641,449,549,824 after (04:49:44),
with other jobs running at the same time. No image or container of this job is left.

## `nerves-hub/nerves_hub_web`

Its recipe would add `"packages": ["xdelta3", "mtools"]` and fwup's `.deb` for amd64 as a release file with its
SHA-256, and the installation would allow GitHub's hosts (the releases host and the host its downloads redirect to).
Fetching that file waits for the owner's word; the recipe is unchanged.
