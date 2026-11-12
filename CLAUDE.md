# elixir-agents-on-mining-rigs

Small, fast Elixir coding-agent models for old crypto-mining rigs (nine NVIDIA P106-090 6 GB cards, PCIe 1.0 x1, no
peer-to-peer, 2 Celeron cores, 4 GB of host RAM). The goal, the measures and the order of work are in `README.md` and
`docs/plan.md`; read both before starting anything. The engine is Miner Llama, and its benchmarks and rig documentation
live in the sister repo `llms-on-crypto-mining-rigs`.

## The rules that shape every result

- **Hold-out:** nothing that shapes a model (training tasks, calibration text, the statistics that choose experts or
  layers) may come from the Elixir SWE Bench's 12 projects (the list is in `docs/plan.md`). Check with E12 before use.
- **Task success is the bench:** all 20 cases, three seeds, one harness per comparison. KLD only picks candidates.
- **Speed is agentic:** time per task in a coding-agent session on the rig. Single-request tok/s is a diagnostic.
- **Exact numbers:** each number is one run with its file, build and settings. Repeats are listed by value, never as
  a range, and estimates are marked est.
- **The model's machine runs only the model:** task making, task checks and the project containers of the teacher's
  sessions run on a separate data-mining machine with no GPU, one task at a time. Beside the model server they fought
  it for processor, memory and disk, and their tests timed out, which reads as a failed task (2026-11-12, E76).
- **Every idea gets a row in `experiments.md` at once,** however small. Ideas the evidence argues against stay as
  parked rows with the reason and what would reopen them.
- **Search both registries before adding an idea:** this `experiments.md`, and the sister repo's
  [registry](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/quants/experiments.md). The sister
  holds the finished expert-cut runs (Q232, Q890, Q891) and every engine, format and speculation idea (run-time expert
  skipping, activation sparsity). Ideas about running a model faster without changing it go there.

## The data behind every result

An experiment is done when `docs/data/<date>_<experiment>/` holds:
- its `README.md` (what it measured, the result link, a file table, exact commands, provenance and licence);
- its curated tables;
- its scripts, in `run/`.

Its registry row links that folder, and `docs/data/README.md` has its row. Scripts take hosts and paths from the
environment (`RIG`, `CLIENT`, `WORK`, `MODELS`, `MODEL`, `BIN`, `OUT`), so the script that ran is the one committed.
Files stay under 1 MB (gzip up to ~3 MB), and only data whose licence allows publishing goes here.

## This repo is public

- Never commit hostnames, tailnet or domain names, usernames, IP or MAC addresses, GPU UUIDs, serial numbers or
  private paths, in docs, scripts, logs or commit messages.
- Keep raw output, logs and transcripts out; summarize what they show.
- Write docs as finished specs: state the facts plainly, with no review commentary.
