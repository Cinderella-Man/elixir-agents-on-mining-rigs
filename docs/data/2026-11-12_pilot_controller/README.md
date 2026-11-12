# Pilot job P2: the factory's controller installed on the build machine

The controller of `factory/` (the task factory's copy of the bench engine) built into a Docker image and started once on
the 7-GPU machine, with no task in it, then stopped. Its image and its data folder stay. Nothing was checked and no
model was run.

## What was installed

- Image `elixir-task-factory:pilot`: 779 MB as `docker images` lists it (193,566,061 bytes as `docker image inspect`
  reports its size), built from `factory/` as on `main` after job T5. The only edit to `factory/Dockerfile` is the
  removed line `COPY cases cases`; the build needed no other edit. No image was pulled: every base image was already
  on the machine.
- Controller `factory`, started by `run/controller.sh up`: host networking, no published port, Erlang's port mapper
  and distribution on 127.0.0.1 (`EPMD_PORT` 4455, node `factory@127.0.0.1`), memory collection off
  (`EAB_MEMORY=off`), data in `$WORK/factory/data`, the Docker socket mounted, `run/docker_shim.sh` first in its
  `PATH` as `docker`. The controller's container carries `--label pascal-quants=1` and `--cpu-shares 256`; the shim
  adds both to every `docker run` the engine makes.
- There is no web page any more (job T1), so "up" means that the release answers `rpc`.

## Commands

```bash
HOST=<ssh destination> WORK=<folder on the machine> run/sync.sh          # from the editing machine
export WORK=<folder> RUN=<folder of run/> IMAGE=elixir-task-factory:pilot
SRC=<folder>/src run/controller.sh build      # through docker:cli (Buildx), at most the image's own 2 schedulers
run/controller.sh up
TASK=<task folder> run/proofs.sh              # the three proofs below
run/controller.sh rpc 'IO.inspect(Eab.Inventory.all())'
run/controller.sh down                        # data and image stay
```

## The proofs (output of `run/proofs.sh`)

(a) The controller answers; the inventory holds no task:

```
[]
```

(b) `System.find_executable("docker")` inside it:

```
"/opt/shim/docker"
```

(c) `Eab.Candidates.import/1` on the made-up task `ledgerette-pr-1` of `factory/test/support/tasks/`, copied into the
data folder (`data/incoming/`). It returned the reference, `Eab.Candidates.read!/1` read the stored candidate back,
and the store holds it under `data/candidates/ledgerette-pr-1/<version>/`:

```
%{"id" => "ledgerette-pr-1", "version" => "edda2a046dffccddd29eaa4f13aa27a0108b92ac59f570ebf0a839e10d439995"}
"ledgerette-pr-1"
```

The container: labels `pascal-quants=1`, `cpu_shares=256`, `network=host`, no published ports; the only listening
BEAM socket is on 127.0.0.1. `Eab.Inventory.all/0` stays empty after the import: the engine's inventory still reads
`cases/` under its root (job T6 changes that), and an imported candidate lives in the candidate store.

## Disk and images

| | `/` free | `/` used |
|---|---|---|
| before | 621 GB | 1117 GB |
| after | 620 GB | 1118 GB |

The one new image is `elixir-task-factory:pilot`. Build cache from the Buildx run stays in Docker's builder.

## Files

| File | What it is |
|---|---|
| `run/controller.sh` | `build`, `up`, `rpc`, `down` |
| `run/docker_shim.sh` | the `docker` that adds the label and the CPU share |
| `run/proofs.sh` | the three proofs and the container's settings |
| `run/sync.sh` | copies `factory/` and `run/` to the machine |
