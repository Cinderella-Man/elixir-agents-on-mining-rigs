# The bracket: the rig's 2-bit file against a high-precision file on the Elixir SWE Bench (2026-11-10)

Two files of one model, Qwen3.8-Flash-Next, on the Elixir SWE Bench (20 cases, the Pi agent, three seeds each):
Swift GSQ-RCO Q2_0, the file the rig serves, and Swift GSQ-RCO IQ3_S, the high-precision end. Registry rows:
[E1](../../../experiments.md) (the bar) and [E13](../../../experiments.md) (the ceiling).

**Result.** None yet: the first series (Q2_0, seed 101) started on 2026-11-10. This page describes the setup; the
tables are added when the six series have ended.

**What it decides.** If the two files pass the same cases, file quality is not what limits the rig's model, and work
on better files moves down. If IQ3_S passes three cases or more above Q2_0, better files are the first lever.

## Setup

| | |
|---|---|
| Bench | Elixir SWE Bench, inventory `elixir-agent-benchmark-v5`, 20 cases, checkout `5e5f88f9`, Pi 1.2.0, frozen release `ea0af77d…9920` |
| Run settings | the bench's defaults for a local server, as its published local series ran: window 262,144 tokens, 8,192 tokens a reply, 65,536 generated tokens a case, no compaction, the full history kept, one attempt at a time |
| Seeds | 101, 102, 103 (the bench's seeds for a local series) |
| Thinking | `xhigh`, the model's template default: the server sets no effort and the rendered prompt opens with "Reasoning effort is set to xhigh". Declared to the bench as `xhigh` |
| Engine | Miner Llama v3 (`1551f5fe1`), the release build, one slot |
| Server line | `-ngl 99 -fa on -c 262144 -np 1 --ctx-checkpoints 4 --cache-ram 0 --jinja --reasoning-format deepseek --temp 1.0 --top-p 0.95 --top-k 20 --min-p 0 -b 2048 -ub 512 -fit off --metrics --no-webui` |
| Sampling | the release preset's: temperature 1.0, top-p 0.95, top-k 20, min-p 0. The bench removes the agent's own sampling fields, so the server's values apply |
| Left out of the release preset | the MTP draft, the nine-card split and the Pascal switches (the rig's speed settings) |
| Files | Swift GSQ-RCO Q2_0 and Swift GSQ-RCO IQ3_S, each with the n-gram table in a third shard (the same table file for both) |
| Machines | the two servers on the 7-GPU machine: Q2_0 on one RTX 3080 12 GB and two RTX 3090s, IQ3_S on three RTX 3090s. The bench's controller and its test containers on a second machine, which reaches each server's port through an ssh tunnel |
| Memory on the cards after loading | Q2_0 8,845 + 19,112 + 19,216 = 47,173 MiB; IQ3_S 20,802 + 21,370 + 21,412 = 63,584 MiB |

- **Both servers stay loaded;** the bench runs one series at a time, started from its dashboard with the server's
  address, the seed and the thinking preset.
- **Checked before the first run:** on both servers the bench's token-count route and the generation report the same
  prompt tokens for a request with tools (326 and 326), and both answer with a tool call
  ([run/count_check.py](run/count_check.py)).
- **Every request is kept by the bench,** per case: the request, its event stream with the server's token counters,
  and the counted tokens. The bench also samples the server's RAM and VRAM during each run.
- **Counts only.** The 7-GPU machine is shared, so no time is read from these runs: passes, generated tokens, model
  calls, attempts stopped at the budget, peak prompt tokens per attempt and prompt tokens processed anew per call.
- **Swift Qwen3.8-Flash-Next Pascal Q2 GGUF (`pmix-q2-fast`), E1's second file, is not part of these runs.**

## Files

| File | What it holds |
|---|---|
| [run/bracket.env.example](run/bracket.env.example) | the variables `serve.sh` reads (paths, cards, ports) |
| [run/serve.sh](run/serve.sh) | one llama-server for one file; records the line as run, the cards' memory and the rendered template |
| [run/tunnel.sh](run/tunnel.sh) | keeps the servers' ports forwarded to the machine that runs the bench |
| [run/count_check.py](run/count_check.py) | compares the token-count route with a generation's prompt tokens for a request with tools |
| [run/counts.py](run/counts.py) | the count tables of one run, from the bench's evidence |
| [run/fit_delta.py](run/fit_delta.py) | a cut file's memory per card, from its source's measured load and both files' headers |
| [run/start_e448.sh](run/start_e448.sh), [run/stop_e448.sh](run/stop_e448.sh) | the server for the 448-expert file, through `serve.sh` (cards by PCI bus id) |

## Commands

On the 7-GPU machine, from the work folder, with `bracket.env` filled in:

```bash
. run/bracket.env
for t in q2 iq3s; do bash run/serve.sh up $t $WORK/serve/$t; done
for p in $PORT_q2 $PORT_iq3s; do python3 -I run/count_check.py http://127.0.0.1:$p; done
```

On the machine that runs the bench:

```bash
SERVER_SSH="<the 7-GPU machine>" PORTS="18210 18220" setsid -f nohup bash tunnel.sh > tunnel.log 2>&1 < /dev/null
```

In the bench's dashboard, per series: server `http://127.0.0.1:18210` (Q2_0) or `http://127.0.0.1:18220` (IQ3_S),
seed 101, 102 or 103, thinking preset `xhigh`, every other setting at its default.

The tables of one finished run (the run's folder copied out of the bench's container to the 7-GPU machine):

```bash
docker exec <bench container> tar -C /data/runs -cf - $RUN_ID | ssh <the 7-GPU machine> "tar -C $WORK/runs -xf -"
python3 -I run/counts.py --data $WORK --run $RUN_ID --label q2-seed101 --out $WORK/tables/q2-seed101
```

## The third file: IQ3_S cut to 448 experts per layer (E65)

Swift GSQ-RCO IQ3_S with 448 of its 512 experts kept in every layer, chosen by the sister repo's agent routing counts
(its Q890 and Q891, `scripts/gguf_prune.py`): shards 1 and 2 are cut, shard 3 is the same n-gram table, and every kept
tensor is the maker's bytes. It is 6,025.6 MiB (6.32 GB) smaller than IQ3_S; agent KLD 0.122 against IQ3_S's 0.118.
Registry row [E65](../../../experiments.md). It runs three seeds in the same harness and settings as IQ3_S, served on
the three cards IQ3_S used, with the same server line, at port 18230.

| | |
|---|---|
| Files | `Swift-Qwen3.8-Flash-Next-GSQ-RCO-IQ3_S-e448-0000{1,2,3}-of-00003.gguf`: 14,333,664,032 and 34,291,936,704 bytes (md5 `adec55215a0415f00aa39aadd08212a0`, `e6ee17adddf5b4979e847bea2a2a9e92`), and the table shard, 28,800,138,432 bytes (md5 `98ce140e641bc5d68af9f31df0f1c048`) |
| Projected memory on the cards | 18,824 + 19,326 + 19,409 = 57,559 MiB at the 262,144-token window ([run/fit_delta.py](run/fit_delta.py)): IQ3_S's measured load less the weight bytes the cut removed from each card's layers, read from both files' headers. llama.cpp's default split gives both files layers 0-16, 17-32 and 33-47 plus the output layer on the three cards |
| Memory on the cards after loading | 18,824 + 19,324 + 19,410 = 57,558 MiB (2026-11-11), within 2 MiB of the projection on each card |
| Series | seed 101 started on 2026-11-11; seeds 102 and 103 follow |

```bash
. run/bracket.env
bash run/start_e448.sh plan      # writes serve/iq3s-e448/server.cmd and shows the cards' memory; starts nothing
bash run/start_e448.sh           # starts only if each card in CARDS_iq3s_e448 holds under 500 MiB
bash run/stop_e448.sh
```

On the machine that runs the bench, a second tunnel beside the first, for this port only:

```bash
SERVER_SSH="<the 7-GPU machine>" PORTS=18230 PIDFILE=tunnel-18230.pid setsid -f nohup bash tunnel.sh > tunnel-18230.log 2>&1 < /dev/null
```

In the dashboard: server `http://127.0.0.1:18230`, seed 101, 102 or 103, thinking preset `xhigh`, every other
setting at its default. Each finished run joins the results page as a series of its own:

```bash
mix eab.results add run.json --quantized-by 'ukisai' --quantization 'IQ3_S-e448' \
  --note 'IQ3_S with 448 of 512 experts kept per layer (agent routing counts; every kept tensor is the maker'"'"'s bytes)'
```

## Provenance

- The bench: [Cinderella-Man/elixir-swe-bench](https://github.com/Cinderella-Man/elixir-swe-bench), checkout
  `5e5f88f9`, unchanged.
- The files: UkisAI's Swift-1.5 GSQ-RCO Q2_0 and IQ3_S of Qwen3.8-Flash-Next, re-sharded so that the n-gram table is
  a shard of its own (`scripts/gguf_reshard.py` in the sister repo); the weights are the makers' bytes.
- The engine: [Miner Llama](https://github.com/Cinderella-Man/miner-llama) v3.0, commit `1551f5fe1`.
- Licence: the scripts in this folder are under this repository's MIT licence.
