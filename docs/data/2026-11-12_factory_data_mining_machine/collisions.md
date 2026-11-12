# What the factory shares with the bench on the data-mining machine

Every name the factory's controller and one task check create, write or use, checked against the data-mining
machine's Docker and sockets on 2026-11-12 before anything started (read only, `run/state.sh`), with the bench's
controller running there and no bench run. The factory's code is public `main` at the start of the job plus the two
switches of README section 6, change 10.

| What the factory uses | Where in the code | On the machine | Shared? What was done |
|---|---|---|---|
| BuildKit cache mount `id=eab-hex-packages-v1` (Hex packages) in both `mix deps.get` lines of the workspace recipe | `factory/lib/eab/fixtures.ex` (`dockerfile/4`) | the bench's cache mount with that id is in the default builder (55.19 MB, used 53 times, last used 12 days before) | **Yes.** New switch `EAB_HEX_CACHE_ID` (section 6, change 10), default the bench's id; the controller and the Docker tests ran with `etf-hex-packages-v1` |
| The tooling image the Docker tests build from, `eab-tooling:dev` | nine `test/eab/*_docker_test.exs` files | no such image; the name is the bench's | **Yes, by name.** New test switch `EAB_TOOLING_IMAGE` (default the bench's tag); the tests ran on `etf-tooling:20261112` |
| Erlang's port mapper of the controller (host network) | the release's default, 4369 | the bench's `epmd` listens on 0.0.0.0:4369 and [::]:4369 | **Yes with defaults; an existing switch.** `ERL_EPMD_PORT=4510` (free), `ERL_EPMD_ADDRESS=127.0.0.1`, distribution on the loopback |
| Node name | `RELEASE_NODE=factory_hb@127.0.0.1` | registered in the factory's own port mapper | No |
| Web port | none (no web server since T1) | the bench serves 127.0.0.1:4000 | No |
| Controller container | `factory-hb` | not taken | No |
| Image tags | `etf-tooling:20261112`, `elixir-task-factory:hb-20261112`, and the engine's `elixir-task-factory:*` | none of either prefix on the machine; the bench's 141 images are `elixir-agent-benchmark:*` | No. The factory removes only images whose tags all carry `elixir-task-factory:` and that its own records name; the bench only `elixir-agent-benchmark:` |
| Base images of the controller's `Dockerfile` | `node@sha256:d6aa754f…`, `hexpm/elixir@sha256:73e79b5a…` (by digest), `ubuntu:24.04` | the first two present, untagged (the bench's tooling bases); `ubuntu:24.04` absent | Shared read only (no tag moves). `ubuntu:24.04` pulled by the controller's build |
| The tooling image's layers | the `Dockerfile` stages `pi` and `tooling` | the bench's builds left the same layers in the default builder | Shared read only: every step of the tooling build was cached |
| Engine's containers | `etf-<16 hex>`, `-db`, `-ch`, `-redis` | the bench's are `eab-…` | No |
| Engine's container labels | `etf.installation`, `etf.run`, plus `EAB_DOCKER_LABELS` (`task-factory=1`) | the bench removes only containers with its own `eab.*` labels | No |
| Networks | none created (`--network=none`, `container:<name>-db`) | `bridge`, `host`, `none` | No |
| Volumes | none named; a database container's anonymous volume goes with `docker rm -f -v`; the controller's `VOLUME /data` gets the data folder bound to it | one, the bench's `elixir-swe-bench_benchmark-data` | No |
| Host folders | the factory's work folder only: `ctl-hb/` (data, task folder, logs), `jobs/setup/`, `src/` | the bench's folders are elsewhere | No |
| Paths inside containers | `/opt/eab-seed`, `/opt/eab-state`, `/opt/eab-attempt`, `/opt/eab-grade`, `/tmp/eab-release-files` | inside the factory's own containers only | No (kept for parity, README section 2) |
| Daemon-wide: the builder's garbage collection | — | rule 0 prunes local sources, cache mounts and Git checkouts unused for 48 h only above 12.1 GiB (they held 0.45 GB); rules 1 to 3 prune only below 174.2 GiB free (852.6 GB free) | Shared by nature on one daemon; with these numbers the factory's builds cannot make the collector evict the bench's entries |
