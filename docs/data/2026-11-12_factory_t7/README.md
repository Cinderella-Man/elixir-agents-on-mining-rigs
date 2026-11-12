# Factory job T7: the factory's own name, and the labels and CPU share set by the engine (E68)

`factory/README.md` section 7, row T7; section 6, changes 1 and 6. Until now a small wrapper in front of `docker`
added the build machine's label and a low CPU share to every `docker run`. The engine now does it itself, from two
settings, and the factory's names outside the container are its own, so that a factory and a bench controller on
one machine can never touch each other's images or containers. With the two settings unset, the engine's
`docker run` arguments are the bench's, and every name the model can meet inside the container stays.

## What changed

- **Change 1, the labels and the share.** New `lib/eab/docker_settings.ex`: `EAB_DOCKER_LABELS` (a list of
  `key=value`, separated by commas or white space) and `EAB_CPU_SHARES` (a whole number of at least 2), read in
  `config/runtime.exs` outside the test environment. `Eab.Sandbox.start/2` puts the labels and `--cpu-shares` after
  its own two labels on each of the three `docker run` calls (workspace, Postgres, ClickHouse); the `--cpus` and
  `--memory` flags are not touched. The labels go on every image the engine builds (`fixtures.ex` `build/3`,
  `agent_image.ex`, `service_images.ex`); a snapshot it commits takes the labels of its container. Unset, nothing is
  added. A label that is not `key=value`, or a share below 2, raises.
- **Change 6, the name.** Image tags start with `elixir-task-factory:` (was `elixir-agent-benchmark:`) in
  `agent_image.ex`, `build_cache.ex`, `fixtures.ex`, `service_images.ex`, and in the guards of `retention.ex` and
  `storage.ex`; the label keys are `etf.installation` and `etf.run`, container names start with `etf-`
  (`sandbox.ex`); `config/benchmark.json` is `config/factory.json`, with the id `elixir-task-factory-v1` and no
  scoring text; the release is `factory` (`mix.exs`, `Dockerfile`: `bin/factory`); the Compose service, its image
  (`factory:local`) and its volume are `factory`; the report is titled "Task run report". The modules keep `Eab` and
  the settings `EAB_`.
- **Kept, because the model can meet them inside a container:** `/workspace`, `/opt/pi`, `/opt/eab-seed`,
  `/tmp/eab-ticket.md`, `/opt/eab-attempt`, `/opt/eab-grade`, `/opt/eab-state`, `EAB_BASH_TIMEOUT_SECONDS`, the Git
  author `Benchmark`, `Initial task workspace`, the provider `benchmark`, `Benchmark <reason> reached`, and the
  recipe's build-stage names (`/opt/eab-build-seed.exs`, `/opt/eab-force-add.txt`, `mix eab.seed`,
  `eab-hex-packages-v1`). A search of `lib/`, `config/`, `Dockerfile`, `compose.yaml` and `mix.exs` for
  `elixir-agent-benchmark`, `eab.installation`, `eab.run`, a container prefix `eab-`, `benchmark.json`, `bin/eab`
  and `Benchmark report` finds nothing.
- **Tests.** `bench_parity_test.exs`: only its three allowed lines, `@name_prefix "etf-"`,
  `@installation_label "etf.installation"`, `@run_label "etf.run"`. New `docker_settings_test.exs` (4 tests, a
  stand-in `docker`: unset adds nothing; set, the exact arguments of the three `docker run` calls; labels alone and
  share alone; bad values refused) and `docker_settings_docker_test.exs` (1 test, real containers and images). The tag
  prefix in `storage_test`, `baseline_docker_test`, `task_grading_docker_test` and `bundle_probe_docker_test`;
  `config/factory.json` in `inventory_test` and `fixtures_test`; the test-made names `eab-snapshot-check-`,
  `eab-seed-check-` and `eab-pi-check-` became `etf-…` (`baseline_docker_test`, `build_seed_docker_test`,
  `pi_docker_test`).

## Commands (on the build machine, in the work folder with `src/` and `run/`)

```
WORK=$PWD LABEL=pascal-quants=1 run/checks.sh t7c    # format, unit tests, Docker tests (wrapper kept), proof.sh
WORK=$PWD run/compare.sh t4b_unit t4b_docker t7c_unit t7c_docker > tests_compared.tsv
WORK=$PWD LABEL=pascal-quants=1 run/release.sh       # build the controller's image, ask bin/factory, remove it
```

`run/checks.sh` is job T4's, plus a record of Docker's container and image events during the Docker tests and a last
step, `run/proof.sh`. `run/proof.sh` runs only `docker_settings_docker_test.exs` with **no wrapper** in front of
`docker`, with `EAB_DOCKER_LABELS=pascal-quants=1` and `EAB_CPU_SHARES=256`. `run/release.sh` is new. `test.sh`,
`docker_shim.sh`, `t0_formatter.exs` and `compare.sh` are the earlier jobs' (`docs/data/2026-11-12_factory_t0/run/`,
`docs/data/2026-11-12_factory_t4/`). Every step runs with `mix test --warnings-as-errors`. A first run (`t7`) gave
the same counts; `t7b` is the run after the test-made names `eab-seed-check-` and `eab-pi-check-` were renamed (191
and 197 passed); `t7c` is the run after the rebase onto job P5 r2's change to the bundle maker (E74), which brought
2 new tests, and is the one reported here.

## Counts

| | T4 | T7 |
|---|---|---|
| format check | passes | passes |
| without Docker | 187 passed, 0 failed, 5 excluded | 193 passed, 0 failed, 6 excluded |
| with `EAB_DOCKER_TESTS=1` | 192 passed, 0 failed, 0 excluded | 199 passed, 0 failed, 0 excluded |
| `proof.sh` (no wrapper) | | 1 passed |

`tests_compared.tsv` (200 lines, the first is the header): 192 tests end as in T4, none differs, none is gone; 7 are
new and pass: 4 in `docker_settings_test`, the Docker test (excluded without Docker), and the 2 of `bundle_maker_test`
that P5 r2 added (on T4's tree it counted 189 and 194). `bench_parity_test` passes 6
of 6 in both runs.

## Proof: the labels and the share on the engine's own containers

From `proof.sh` (no wrapper; the engine's settings `pascal-quants=1` and the test's own `etf.check=<id>`, share 256).
One workspace with Postgres and ClickHouse, started by `Eab.Sandbox`:

| Container | Labels (besides the image's own) | CPU share | CPU limit |
|---|---|---:|---:|
| `etf-eb20be51ae2ee08e` (workspace) | `etf.installation`, `etf.run`, `etf.check`, `pascal-quants=1` | 256 | 2 CPUs |
| `etf-eb20be51ae2ee08e-db` (Postgres) | the same | 256 | 1 CPU |
| `etf-eb20be51ae2ee08e-ch` (ClickHouse) | the same | 256 | 2 CPUs |

The two database images the engine built (`elixir-task-factory:layout-…`) and the Postgres snapshot it committed
(`elixir-task-factory:snapshot-…`) carry `etf.check` and `pascal-quants=1`, and every one of their tags starts with
`elixir-task-factory:`. In the Docker run with the wrapper (which adds `--cpu-shares 256` first), the same test sets
the share 300 and reads 300 on all three containers: the engine's flag comes after the wrapper's, and Docker keeps
the last.

Docker's events during the Docker tests and `proof.sh` of `t7b` and `t7c`: every container created on the machine
carried `pascal-quants=1`. The containers the engine started are named `etf-…` and carry `etf.installation` (the
one `etf-…` container without it is `pi_docker_test`'s own); no container named `eab-…` carried an `etf.*` label,
and every image tag the runs made starts with `elixir-task-factory:` or with a test's own `etf-…` name. During `t7b`
another job's tests and controller, on the code before T7, made `eab-…` containers and `elixir-agent-benchmark:` tags
with test ids this code no longer has; during `t7c` (70 containers created) no tag `elixir-agent-benchmark:` or
`eab-…` was made at all. No container and no `elixir-task-factory:` or `etf-` image of these runs was left
afterwards.

## The controller's image

`run/release.sh` built the image from this folder (`mix compile --warnings-as-errors && mix release`: "Release created
at …/rel/factory"), then ran `bin/factory eval` once, with no controller started, with
`EAB_DOCKER_LABELS=pascal-quants=1,etf.check=release` and `EAB_CPU_SHARES=256`. It read the labels
`["pascal-quants=1", "etf.check=release"]`, the share 256, the arguments
`--label pascal-quants=1 --label etf.check=release --cpu-shares 256`, and the inventory id `elixir-task-factory-v1`.
The image was removed afterwards. Its build installs the Ubuntu packages of the `Dockerfile`'s `app` stage, as the
earlier builds did.

Free space on `/` of the build machine: 647,626,375,168 bytes before (04:10:49), 645,954,576,384 after (04:33:38);
other jobs ran at the same time.
