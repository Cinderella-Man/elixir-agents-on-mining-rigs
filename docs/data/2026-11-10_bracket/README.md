# The bracket: the rig's 2-bit file against a high-precision file on the Elixir SWE Bench (2026-11-10)

Two files of one model, Qwen3.8-Flash-Next, on the Elixir SWE Bench (20 cases, the Pi agent, three seeds each):
Swift GSQ-RCO Q2_0, the file the rig serves, and Swift GSQ-RCO IQ3_S, the high-precision end. A third file, IQ3_S cut
to 448 of 512 experts per layer, runs in the same harness ([below](#the-third-file-iq3_s-cut-to-448-experts-per-layer-e65)).
Registry rows: [E1](../../../experiments.md) (the bar), [E13](../../../experiments.md) (the ceiling) and
[E65](../../../experiments.md) (the cut file).

**Result, seed 101 only.** Seed 101 has ended for all three files; seeds 102 and 103 have not run. One case is 5
points of the 20.

| File | Passed of 20 | Failed | Attempts stopped at the generation budget | Generated tokens, 20 attempts | Model calls, 20 attempts | Generated tokens per passed case | Model calls per passed case |
|---|---|---|---|---|---|---|---|
| Swift GSQ-RCO Q2_0 | 14 | 6 | 5 | 895,310 | 1,921 | 42,230.7 | 95.1 |
| Swift GSQ-RCO IQ3_S | 14 | 6 | 2 | 862,612 | 1,544 | 34,185.6 | 67.4 |
| Swift GSQ-RCO IQ3_S cut to 448 experts per layer | 15 | 5 | 5 | 902,318 | 1,590 | 40,776.1 | 72.8 |

All three runs: seed 101, thinking `xhigh`, window 262,144 tokens, 65,536 generated tokens a case, 20 of 20 attempts
completed, none stopped at the window. The passes are the bench's own grades in each run's `run.json`. The tables
come from [run/counts.py](run/counts.py): [tables/q2-seed101](tables/q2-seed101),
[tables/iq3s-seed101](tables/iq3s-seed101) and [tables/iq3s-e448-seed101](tables/iq3s-e448-seed101), each with
`series.tsv` (the row above), `attempts.tsv` (one row per case) and `calls.tsv` (one row per model call). "Stopped at
the generation budget" is the bench's stop reason `token_budget`; the generated tokens of an attempt reached 65,536 in
7 attempts of Q2_0, 6 of IQ3_S and 7 of the cut file, because an attempt that ends itself in the call that reaches the
budget keeps the stop reason `agent_completed`. The per-passed-case columns sum the passed attempts and divide by the
number passed.

Pass or fail per case (the bench's order):

| Case | Q2_0 | IQ3_S | IQ3_S, 448 experts |
|---|---|---|---|
| plausible-pr-5939 | pass | pass | pass |
| plausible-pr-6449 | pass | pass | pass |
| plausible-pr-5956 | pass | pass | pass |
| livebook-pr-2219 | pass | pass | pass |
| livebook-pr-2527 | pass | pass | pass |
| livebook-pr-2663 | pass | pass | pass |
| livebook-pr-2800 | fail | fail | fail |
| livebook-pr-2822 | pass | pass | pass |
| livebook-pr-3076 | pass | pass | pass |
| accent-pr-183 | fail | pass | pass |
| ash-pr-3031 | fail | fail | fail |
| livebeats-pr-37 | pass | pass | pass |
| operately-pr-1069 | pass | pass | pass |
| operately-pr-1205 | pass | pass | pass |
| absinthe-pr-1176 | pass | fail | fail |
| cachex-pr-341 | fail | fail | pass |
| guardian-pr-748 | pass | pass | pass |
| pinchflat-pr-610 | fail | pass | pass |
| beacon-pr-687 | pass | fail | fail |
| vutuv-pr-1759 | fail | fail | fail |
| **Passed** | **14** | **14** | **15** |

The three files have the same outcome on 15 cases: 12 passed by all three and 3 failed by all three (livebook-pr-2800,
ash-pr-3031, vutuv-pr-1759). On the other 5: accent-pr-183 and pinchflat-pr-610 pass in both IQ3_S files and fail in
Q2_0; absinthe-pr-1176 and beacon-pr-687 pass in Q2_0 and fail in both IQ3_S files; cachex-pr-341 passes only in the
cut file.

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
| [tables/](tables) | `series.tsv`, `attempts.tsv` and `calls.tsv` of each finished run, from `counts.py` (seed 101: `q2-seed101`, `iq3s-seed101`, `iq3s-e448-seed101`) |

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

The three seed-101 tables above, with `WORK` the work folder on the 7-GPU machine. The copy runs on the machine that
runs the bench, the tables on the 7-GPU machine at low CPU priority (no GPU, nothing else running):

```bash
# on the machine that runs the bench, once per run
docker exec <bench container> tar -C /data/runs -cf - $RUN_ID | ssh <the 7-GPU machine> "nice -n 19 tar -C $WORK/runs -xf -"

# on the 7-GPU machine, in $WORK
nice -n 19 python3 -I run/counts.py --data $WORK --run 20261110-100513-80595be0 --label q2-seed101 --out $WORK/tables/q2-seed101
nice -n 19 python3 -I run/counts.py --data $WORK --run 20261110-192333-3dd3f555 --label iq3s-seed101 --out $WORK/tables/iq3s-seed101
nice -n 19 python3 -I run/counts.py --data $WORK --run 20261111-064414-a40d01b1 --label iq3s-e448-seed101 --out $WORK/tables/iq3s-e448-seed101
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
| Series | seed 101 ended on 2026-11-11 with 15 of 20 cases passed (run `20261111-064414-a40d01b1`, [tables](tables/iq3s-e448-seed101)); seeds 102 and 103 have not run |
| Routing text | the experts were chosen by the sister repo's agent routing counts on its publishable agent sessions; whether any of that text comes from the bench's 12 projects (E12) is not yet checked |

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
