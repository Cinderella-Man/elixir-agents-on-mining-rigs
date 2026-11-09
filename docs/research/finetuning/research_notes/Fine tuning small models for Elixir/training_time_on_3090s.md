# Training time on 5 × RTX 3090: fine-tuning and RL for a ~9B model (as of 2026-11-02)

Labels used below. **Local** = measured on this machine or in this project. **Measured** = a third party's run. **Vendor** = a maker's own claim. **Estimate** = my arithmetic, never measured on this box. Nothing here was run.
Reference model for all sums: Qwen3.5-9B, because its config is public ([config.json](https://huggingface.co/Qwen/Qwen3.5-9B/raw/main/config.json)). Another 9B model changes the numbers a little, not the conclusions.

## How long will it take? (the owner's question)

### Takeaway
A LoRA fine-tune of 20k samples of ~1k tokens for 3 epochs takes about 13–22 hours on five 3090s, about €10 of electricity. Trajectory training of 2,000 sessions takes 12–23 hours per epoch, full-weight training works only by sharding across all five cards, and a DeepSWE-scale RL run is out of reach (about 2.5 months); a 1/8-scale version takes 5–9 days per run.

### Cited Findings
- Every card-speed figure below rests on one third-party 3090 report and physics scaling; I found no published tokens/s for fine-tuning a 9B model on a 3090 — [Zagitta report](https://github.com/Zagitta/gpu-unlock/issues/75); see the throughput section.
- DeepSWE used 64 H100s for six days — [Together AI](https://together.ai/blog/deepswe).

### Inferences
All **Estimate**, likely case first, best case in brackets. Arithmetic is in the sections below. kWh at 1.6 kW for five cards; € at €0.30/kWh.

| Job | Cards | Wall time | kWh | € |
|---|---|---:|---:|---:|
| A. LoRA, 5k samples × 1k tok, 1 epoch | 5 | 1.8 h (1.1 h) | 3 | 1 |
| A. LoRA, 20k, 3 epochs | 5 | 22 h (13 h) | 35 | 10 |
| A. LoRA, 100k, 3 epochs | 5 | 4.5 d (2.7 d) | 174 | 52 |
| B. Full-weight, 20k, 3 epochs | 5 (sharded) | 37 h (24 h) | 59 | 18 |
| C. Trajectories, 2,000 × 20k tok, 1 epoch | 5 | 23 h (12 h) | 36 | 11 |
| C. Trajectories, 10,000 × 20k tok, 1 epoch | 5 | 4.7 d (2.5 d) | 181 | 54 |
| D. GRPO on code, 1,000 iterations, `mix test` reward | 5 | 3.9 d (2.1 d) | 150 | 45 |
| E. Multi-turn RL, 64 trajectories × 200 steps | 5 | 9 d (4.6 d) | 347 | 104 |
| E. DeepSWE batch, 512 trajectories × 200 steps | 5 | ~72–77 d | ~2,900 | ~870 |

### Gaps
- Every wall time above carries roughly ±40 % until the one-day smoke test (last section) measures tokens/s on this card.

## What does this machine give a trainer?

### Takeaway
Five 24 GB cards on unequal links: as last recorded, likely x8, x8, x4, x1, x1, with no GPU peer-to-peer. That is fine for LoRA and bad for anything that moves full weights between cards.

### Cited Findings
- **Local, latest state:** 5 × RTX 3090 + 2 × RTX 3080, ~125 GiB RAM, 5900X, Ubuntu 26.04, 2 TB NVMe, CUDA 12.9 and 13.4 side by side — project notes.
- **Local:** indices 2–6 are the 3090s, capped at 250 W; the 3080s are indices 0–1, capped at 220 W — machine notes.
- **Local:** GPUs 5 and 6 run at PCIe x8 and GPU 2 at x4, and Strata's timing then measured 1.7–3.4 GB/s per link — machine notes.
- **Local:** the V100s that sat at slots 3 and 4 were on x1 links, and a dump on them fell to ~280 tok/s against ~1,650 on the x8 path — [drafter.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/drafter.md), project log. One note says "x1 and x4" for those two cards — [transfer_v100.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/transfer_v100.md). The 3080s are also x1 — project rules.
- **Local:** the two newest 3090s sit in the slots the V100s used — machine notes.
- **Local:** rules: containers labelled `pascal-quants=1`, one build at a time, no driver changes — project rules. Training runs are allowed on the box but speed measurements are not — machine rules. A quant-machine speed test is run like a rig benchmark, in a quiet window — project notes.

### Inferences
- The 3090s are not equal. Working assumption for all sums: x8, x8, x4, x1, x1. Usable x1 bandwidth is taken as ~1 GB/s (gen3 x1 is ~1 GB/s; the x8 links measured 3.4 GB/s at most, so x1 could be lower).
- A step's sync speed is set by the slowest rank, so one x1 card sets the all-reduce rate for all five.
- A throughput log from a training run is arguably a training run, but timing it on purpose is a speed test under the machine's rules. The owner should OK the smoke test explicitly.

### Gaps
- Current link widths and PCIe generation are not recorded anywhere I could read. Whether the slots are risers, chipset lanes or M.2 adapters is also unrecorded. This one `nvidia-smi` query (under load, since links drop at idle) is the first step of the smoke test.
- PSU rating and chassis airflow: not in the files.

## What fits in 24 GB?

### Takeaway
LoRA in BF16 fits, tightly, at about 2k tokens, with a ceiling near 6–8k. 32k-token trajectories do not fit one 3090 in BF16, and even 4-bit tops out around 24–29k. Full-weight training does not fit one card at all and needs about 72–88 GB. BF16 itself is fine on the 3090.

### Cited Findings
- **Vendor:** Unsloth's Qwen3.5 guide gives 22 GB for BF16 LoRA on the 9B, and full fine-tuning at about 4× that — [Unsloth Qwen3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune). Its generic table gives 9B at 6.5 GB (4-bit) and 24 GB (16-bit), without stating sequence length or batch — [Unsloth requirements](https://unsloth.ai/docs/get-started/fine-tuning-for-beginners/unsloth-requirements).
- **Vendor:** that guide's example uses `max_seq_length = 2048`, batch 1, accumulation 4, `adamw_8bit`, r = 16 and advises starting small; it recommends against 4-bit for every Qwen3.5 model, citing higher-than-normal quantization differences — [Unsloth Qwen3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune).
- **Vendor:** Unsloth reports Qwen3-8B using about 19 GB per GPU in its DDP example — [Unsloth DDP guide](https://unsloth.ai/docs/basics/multi-gpu-training-with-unsloth/ddp).
- **Vendor:** for Llama 3.1 8B at 20K context and 8 generations, Unsloth lists 54.3 GB in all: 42 GB training memory and 9.8 GB GRPO memory — [Unsloth RL guide](https://unsloth.ai/docs/get-started/reinforcement-learning-rl-guide).
- **Vendor:** on an H100, Llama-3.1-8B 4-bit reaches 47,500 context in GRPO (two generations minimum), inside a pool described as 64 GB; Qwen2.5-14B at 32,768 tokens and 8 generations peaks at 43,042 MiB with Standby — [Unsloth memory-efficient RL](https://unsloth.ai/docs/get-started/reinforcement-learning-rl-guide/memory-efficient-rl).
- Qwen3.5-9B: hidden 4096, 32 layers, vocabulary 248,320, untied output head, intermediate 12,288, 4 KV heads of 256; only 8 of 32 layers are full attention — [config.json](https://huggingface.co/Qwen/Qwen3.5-9B/raw/main/config.json).
- **Local:** long sessions trained in pieces of 4,096 target positions because pieces of 16,384 ran out of memory on 24 GB cards, for the small MTP head — [drafter.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/drafter.md).
- **Local:** BF16 is the project's training precision on RTX cards — [drafter.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/drafter.md). Humming's BF16 kernels need SM80+, which is why vLLM's SLQ presets ran on the 3090s (SM86) — machine notes.
- **Measured:** on an RTX 4060, BF16 ran at 0.57× of FP16 (360 against 628 tok/s), though at different sequence lengths (1,024 against 2,048) — [arXiv 2509.12229](https://arxiv.org/pdf/2509.12229).

### Inferences
**Estimate.** Memory per token of sequence, from the config:
- Layer boundaries kept by gradient checkpointing: 32 × 4096 × 2 B = **262 KB/token**. Check: Unsloth's 8B at 20K × 8 = 160k tokens × 262 KB = 41.9 GB, which matches its 42 GB (assuming that 8B also has 32 layers of 4096, from memory).
- Layer being recomputed: about 20 hidden-sized tensors × 8 KB = 164 KB/token, doubled for gradients: **~330 KB/token**.
- Logits: 248,320 × 2 B = **497 KB/token** in BF16 and about 1 MB in FP32. The 248k vocabulary is the single biggest item.

| Sequence | Boundaries | Active layer | All logits | With BF16 weights (19 GB) + LoRA (0.7 GB) | Fits one 3090? |
|---|---:|---:|---:|---:|---|
| 2k | 0.5 GB | 0.7 GB | 1.0 GB | 21.9 GB | Yes; matches Unsloth's 22 GB |
| 8k | 2.1 GB | 2.6 GB | 4.0 GB | 28.4 GB | No as is; ~24.5 GB with the fixes below |
| 32k | 8.4 GB | 10.5 GB | 15.9 GB | 54.5 GB | No; ~43 GB with logits cut to the 25 % generated tokens |

- Fixes: compute logits only at labelled positions, drop the vision tower (~0.8 GB).
- `logits_to_keep` can take an index tensor in at least one causal-LM implementation; check it against the installed transformers — [Liger kernel snippet](https://hub.harborframework.com/tasks/featurebench/linkedin__liger-kernel.c856fbab.test_mini_models.96209d55.lv1).
- **Second route to the same ceiling:** Unsloth's 47,500 × 2 tokens in a ~64 GB pool implies (64 − 6 GB) / 95k ≈ 0.6 MB/token. On a 3090 that gives (24 − 19) / 0.6 MB ≈ **8k tokens** in BF16 and (24 − 6.5) / 0.6 MB ≈ **29k tokens** in 4-bit. This is rough, since that pool figure is loosely described, but it lands where the table does.
- **Ceilings for one 3090, batch 1 (Estimate):** BF16 ~6–8k, 8-bit ~16–18k, 4-bit ~24–29k. So 32k needs model-parallel over 3 BF16 cards (2 cards to ~24k), or trimmed sessions. For 1k-token SFT, BF16 leaves room for a micro-batch of ~5k tokens (4–5 samples); 8-bit allows ~16.
- **Answer on 32k trajectories:** not on one 24 GB card. On Qwen3.5 the 4-bit route also goes against Unsloth's advice; 8-bit is the first thing to test. Cutting old tool output so sessions stay under 16k is cheaper than either.
- **Full-weight state:** 18 GB weights + 18 GB gradients + 36 GB Adam = 72 GB; Unsloth's rule gives 88 GB. Plain DDP needs all of it per card, so it's impossible on 24 GB. Only sharding or model-parallel works.

### Gaps
- I found no measured peak-VRAM figure for a 9B model at 8k or 32k on any 24 GB card. Unsloth's "context-length benchmarks" section was not found.
- How Unsloth's `use_gradient_checkpointing="unsloth"` saves VRAM is not documented in the pages I read, so I did not count any RAM offload.
- Quality cost of 8-bit against BF16 base weights on Qwen3.5: no source found.

## How fast is one RTX 3090 on a 9B model?

### Takeaway
Working figure for BF16 LoRA with gradient checkpointing at the 250 W cap: **180 tok/s likely, 280 tok/s best** (Estimate). No one has published this directly. Several indirect anchors agree within ±40 %, and several popular figures online are impossible.

### Cited Findings
- **Measured:** 4 × 3090, Unsloth, 1.7B model, LoRA r16, BF16, 512 tokens × 16 samples (~8,192 tokens/step, ~85.5 TFLOPs/step): 10.80 s per step at 240 W stock (~7.9 TFLOPS), 8.71 s at 240 W on a clock-unlocked card, 7.24 s at ~314 W draw unlocked (~11.8 TFLOPS) — [Zagitta report](https://github.com/Zagitta/gpu-unlock/issues/75). It uses a third-party unlock, and the report doesn't say whether the 4-card runs were DDP.
- **Measured:** same report, vLLM TP4 on 27B/31B BF16: prefill 1,500–1,640 tok/s across four cards, 23.3–25.4 TFLOPS per GPU — [Zagitta report](https://github.com/Zagitta/gpu-unlock/issues/75).
- **Measured:** RTX 4060, Qwen2.5-1.5B, bitsandbytes backend: 500 tok/s (seq 512, batch 1), 628 tok/s (seq 2,048, batch 2, FP16, paged 8-bit optimizer), 8.06 GB peak — [arXiv 2509.12229](https://arxiv.org/pdf/2509.12229).
- **Measured on the same model:** Qwen3.5-9B LoRA r16 with Unsloth and TRL on one B200: 491 examples, max 8,192 tokens, batch 32, 0.2 samples/s, about 41 minutes — [model card](https://huggingface.co/Shreyansh327/qwen3.5-9b-swegym-lora-full).
- **Vendor:** Unsloth claims ~1.5× speed and ~50 % less VRAM than FA2 setups on Qwen3.5, with slow first start from kernel compilation; no absolute times — [Unsloth Qwen3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune).
- **Formula:** training costs about 6 FLOPs per parameter per token — [JHU slides](https://self-supervised.cs.jhu.edu/sp2024/files/slides/21.scaling-lms.pdf), [nanoGPT notes on 6N + 12LHQT](https://deepwiki.com/karpathy/nanoGPT/7.2-model-sizing-and-flop-estimation).
- **Discarded figures:** Codesota's 3.2 samples/s for 8B at 2k tokens, batch unstated, method not given — [Codesota](https://www.codesota.com/hardware/rtx-3090). InsiderLLM's 300–400 tok/s for 14B is labelled expected, not measured — [InsiderLLM](https://insiderllm.com/guides/lora-training-consumer-hardware/). GIGAGPU's 33.3 samples/s has no stated model or length — [GIGAGPU](https://gigagpu.com/best-gpu-for-fine-tuning-llms/).

### Inferences
**Estimate.** 9B costs 6 × 9B = 54 GFLOPs per token. The Zagitta step confirms the formula: 85.5 T / 8,192 tok = 10.4 G/token = 6.1 × 1.7B.

| Anchor | Sum | 9B on a 3090 |
|---|---|---:|
| Zagitta stock, 240 W | 7.9 T ÷ 54 G | **146 tok/s** |
| Zagitta unlocked, 240 W | 9.8 T ÷ 54 G | 181 tok/s |
| Zagitta unlocked, ~314 W | 11.8 T ÷ 54 G | 219 tok/s |
| RTX 4060 scaled | 628 × 9 G = 5.7 T; assume a 3090 is 2–3× a 4060 (unsourced) = 11–17 T | 210–320 tok/s |
| Inference ceiling | 23.3 T ÷ 18 G = 1,294 tok/s forward; checkpointed training is ~4× forward | ~320 tok/s |
| B200 on the same model | ≤ 0.2 × 8,192 = ≤ 1,640 tok/s; assume B200 is 6–10× a 3090 (unsourced) | ≤ 165–270 tok/s |

- Small models waste more time per FLOP than big ones, so the 1.7B anchors probably undershoot a 9B. Hence 180 likely and 280 best, at 250 W with stock firmware.
- Codesota's figure would be 6,400 tok/s × 48 G = 307 TFLOPS, about 12× the card's reported rate. It can't mean 2k-token samples. InsiderLLM's would be 29 TFLOPS sustained, above the measured inference rate.
- **Long sequences:** the attention term is small on this model because only 8 of 32 layers are full attention: about +11 % FLOPs at 20k tokens and +17 % at 32k. A model with full attention in all 32 layers pays about +29 % and +47 %. This uses the 12LHQT term from memory, as L layers × H heads × Q head size × T context.
- For sums I use 145 likely / 240 best at ~20k tokens, and ×0.8 for a quantized base (bitsandbytes decodes weights each forward; assumption, no source isolates it).

### Gaps
- No measured 3090 tok/s for a 7–14B LoRA, from Unsloth, Axolotl or anyone else, despite targeted searches.
- The H100 and B200 ratios to a 3090 for LLM training are assumptions. I found no good direct comparison.

## Does it scale to five cards, and with what tools?

### Takeaway
Yes for LoRA: gradients are about 160 MB, so sync takes ~0.3 s per step even on x1 and costs ~1 % against steps of tens of seconds. Open-source Unsloth does DDP via `torchrun` as of late 2026, though its speed claims have no independent multi-GPU measure. Full-weight sync over x1 costs minutes, so use sharding with big micro-batches, or model-parallel at one card's speed.

### Cited Findings
- **Vendor:** Unsloth works with DDP via `torchrun`/`accelerate`; the page still calls setup manual and says official support is coming — [Unsloth multi-GPU](https://unsloth.ai/docs/basics/multi-gpu-training-with-unsloth).
- **Vendor:** the DDP guide auto-enables on >1 GPU, shows Qwen3-8B at ~1.1 it/s on 2 × H100 and says throughput grows about linearly; it covers LoRA and 4-bit but gives no multiplier and doesn't discuss gradient checkpointing — [Unsloth DDP guide](https://unsloth.ai/docs/basics/multi-gpu-training-with-unsloth/ddp).
- Tracking issue #2435 was closed on 2026-06-11 as added through merged PRs. An issue about the pricing page calling free multi-GPU "coming soon" was closed 2026-10-19, and a commenter on 2026-10-29 said a free-tier run used all three GPUs — [issue #8903](https://github.com/unslothai/unsloth/issues/8903). A PR adds DDP to Unsloth Studio; merge state unconfirmed — [PR #12663](https://github.com/unslothai/unsloth/pull/12663).
- `device_map = "balanced"` is Unsloth's way to load a model too big for one GPU — [Unsloth multi-GPU](https://unsloth.ai/docs/basics/multi-gpu-training-with-unsloth).
- Axolotl: DDP by default, DeepSpeed ZeRO 1–3, FSDP2 only; pick the ZeRO stage that offloads least; ZeRO-3 can offload parameters and optimizer to CPU; LoRA FSDP checkpoints save adapter tensors only; full checkpoints assemble on rank 0's CPU — [Axolotl multi-GPU](https://docs.axolotl.ai/docs/multi-gpu.html).
- **Measured:** PCIe gen3 x16 through the host bridge on 4 × RTX A6000: NCCL busbw 4.3 GB/s; plain DDP gave only ~2×; BF16 gradients plus accumulation 4 gave 3.54–3.66× (88–89 % efficiency against the accumulating single-GPU baseline). Models were 124M and 355M, with about 130 ms compute against ~170 ms all-reduce — [PyTorch forum](https://discuss.pytorch.org/t/ddp-on-a-pcie-only-4x-rtx-a6000-no-nvlink-plain-ddp-gave-2x-bf16-gradient-compression-plus-accumulation-gave-3-6x/225650).
- **Measured:** forcing `NCCL_P2P_LEVEL=SYS` there cut bandwidth to 2.3 GB/s and hurt throughput — [same post](https://discuss.pytorch.org/t/ddp-on-a-pcie-only-4x-rtx-a6000-no-nvlink-plain-ddp-gave-2x-bf16-gradient-compression-plus-accumulation-gave-3-6x/225650).
- **Measured:** consumer GPUs stage through host memory without a modified driver: on eight RTX 5090s, P2P raised all-reduce busbw from 14.75 to 27.34 GB/s on Gen5 x16 — [arXiv 2608.27370](https://arxiv.org/html/2608.27370v2). The project records no P2P on this box — project rules.
- **Measured (third party, as cited in the project's notes):** link width made no measurable difference to layer-split decode across two 3090s on x1-class links (94.91 against 95.75 t/s). This is decode, not training — [multigpu_pascal_performance.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/multigpu_pascal_performance.md).

### Inferences
**Estimate.** An all-reduce takes S / algbw, and in the forum data algbw = busbw × n / (2(n−1)) (2.9 × 1.5 = 4.3). For five ranks with an x1 card, busbw ≈ 1 GB/s, so algbw ≈ 0.62 GB/s.

| What is synced | Size | Sync per step on x1 | Compared with |
|---|---:|---:|---|
| LoRA r=16 (~40 M params, FP32) | 160 MB | 0.26 s | 28 s micro-batch (5k tok at 180 tok/s): ~1 % |
| LoRA r=64 | 640 MB | 1.0 s | ~4 % |
| Full weights, BF16 gradients | 18 GB | 29 s | DDP can't hold this anyway |
| Full weights, FP32 gradients | 36 GB | 58 s | as above |

- LoRA param count: 16 × (in + out) over ~7 projections ≈ 1.2 M per layer × 32 ≈ 40 M.
- The forum's 2× came from a sync larger than its compute. Here compute is ~100× the sync, so PCIe isn't what limits LoRA. Stragglers, checkpoints and eval are. DDP efficiency: **0.85 likely, 0.92 best**, against 0.88–0.89 measured there. Five cards: 180 × 5 × 0.85 = **765 tok/s**, best 280 × 5 × 0.92 = **1,290 tok/s**.
- Sort samples by length so ranks finish together. Keep NCCL's default P2P level. Use accumulation.
- **Full-weight on five cards (Estimate):**
  - FSDP2 or ZeRO-3 at 72 GB ÷ 5 = 14.4 GB per card, leaving ~8 GB for activations.
  - Each card moves about 0.8 × 18 GB twice forward (gather plus checkpoint recompute) and once back: ~43 GB per micro-batch, 43–86 s on x1 at 1–0.5 GB/s.
  - At 16k tokens per card, 89 s of compute: 80k tokens in 132–175 s = 457–606 tok/s. At 32k per card: 606–724 tok/s.
  - Use **450 likely, 700 best**: about 2.5–3.9× one card, not 5×.
- **Model-parallel** (`device_map`) sends only ~130 MB of hidden state per card boundary, so x1 is fine, but only one card works at a time: ~160 tok/s (best 250).
- **One LoRA per GPU** is the best mode for sweeps: five independent runs (seeds, learning rates, ranks), no sync, no PCIe dependence, one run's wall time for five answers. Use it before any DDP run.
- Two model-parallel replicas under DDP (a rank owning two GPUs) is not a stock Trainer path. Treat it as custom.

### Gaps
- **No source measures DDP on x1 or x4 links.** My x1 sums assume bandwidth maps to busbw directly.
- `nccl-tests` on this box will replace the 1 GB/s assumption.
- Unsloth's DDP speed, its interaction with gradient checkpointing and any behaviour on mixed link widths: unmeasured in public.

## Time estimates for modes A–E

### Takeaway
LoRA, trajectory and GRPO runs are all practical in hours to days on five cards. One card is 4–6× slower and needs a quantized base for trajectories. Multi-turn RL at DeepSWE scale is not realistic here; a 1/8-batch version is possible but is a 1–2 week bet per run, worth trying only after A, C and D work.

### Cited Findings
- DeepSWE: 4,500 tasks, 64 H100s, six days, 512 containers per iteration (batch 64, 8 passes), generation timeout 20 minutes, test limit 5 minutes; validation curve over 200 RL steps went from 23 % to 42 % Pass@1 — [Together AI](https://together.ai/blog/deepswe). The model card repeats the 200 steps — [DeepSWE-Preview](https://huggingface.co/agentica-org/DeepSWE-Preview).
- Those containers overloaded Docker's API and crashed `dockerd` at thousands of containers; the fix was Kubernetes, with worker nodes of ~200 cores and 6 TB+ NVMe — [Together AI](https://together.ai/blog/deepswe).
- NVIDIA's Nemotron SWE-RL used 512 GPUs on 64 nodes (32 for generation), batch 512–1,024, contexts 131k–197k, concurrency 768 — [NVIDIA docs](https://docs.nvidia.com/nemotron/latest/nemotron/super3/rl/swe.html).
- **Vendor:** Unsloth's GRPO guidance: wait for at least 300 steps, ~12 h minimum, 1,000+ steps on some tasks, at least 500 rows, 8 generations per prompt in the example — [Unsloth RL guide](https://unsloth.ai/docs/get-started/reinforcement-learning-rl-guide).
- **Local:** the project's sandbox: one container per session, no network, 2 GB, 512 processes, `--cpu-shares 256`, and Elixir sandboxes already exist — [agentic_data README](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agentic_data/README.md).

### Inferences
**(A) SFT LoRA, 1k tokens per sample. Estimate.** Rates: 1 card 180 (280) tok/s, 5 cards 765 (1,290) tok/s. Time = tokens ÷ rate; 3 epochs = ×3. Example: 20k × 1k = 20 M; 20 M ÷ 765 = 26,144 s = 7.3 h.

| Samples | Tokens per epoch | 1 card, 1 epoch | 1 card, 3 epochs | 5 cards, 1 epoch | 5 cards, 3 epochs |
|---|---:|---:|---:|---:|---:|
| 5k | 5 M | 7.7 h (5.0) | 23 h (15) | 1.8 h (1.1) | 5.4 h (3.2) |
| 20k | 20 M | 31 h (20) | 3.9 d (2.5) | 7.3 h (4.3) | 22 h (13) |
| 100k | 100 M | 6.4 d (4.1) | 19 d (12) | 36 h (22) | 4.5 d (2.7) |

**(B) Full-weight SFT, same data. Estimate.** Five cards use FSDP2 or ZeRO-3 at 450 (700) tok/s. One card cannot hold the state, so its figures assume ZeRO-3 with parameters and optimizer offloaded to RAM on an x8 slot: 16k tokens in 89 s + 16 s of weight transfers + 5 s Adam = ~145 tok/s at best, say 110 (150).

| Samples | 1 card offloaded, 1 epoch | 1 card, 3 epochs | 5 cards, 1 epoch | 5 cards, 3 epochs |
|---|---:|---:|---:|---:|
| 5k | 13 h (9) | 38 h (28) | 3.1 h (2.0) | 9.3 h (6.0) |
| 20k | 51 h (37) | 6.3 d (4.6) | 12 h (7.9) | 37 h (24) |
| 100k | 11 d (7.7) | 32 d (23) | 2.6 d (1.7) | 7.7 d (5.0) |

Checkpoints with optimizer state are ~54 GB each, so limit how many are kept. Host RAM of 125 GiB holds a 72 GB gathered checkpoint.

**(C) Trajectories, mean 20k tokens: 10 M / 40 M / 200 M tokens per epoch. Estimate.** For 10k and 30k means, scale by 0.5 and 1.5; at 30k expect ~10 % lower speed too. Per-card 145 (240) tok/s BF16; quantized 116 (204).

| Setup | Rate tok/s | 500 traj | 2,000 traj | 10,000 traj |
|---|---:|---:|---:|---:|
| 1 card, quantized base (≤ ~24k tokens) | 116 (204) | 24 h (14) | 96 h (55) | 20 d (11) |
| 5 cards, 1-card replicas, quantized base; 8-bit ≤ ~16k, 4-bit ≤ ~24k, longer sessions trimmed | 493 (918) | 5.6 h (3.0) | 23 h (12) | 4.7 d (2.5) |
| 4 cards, two BF16 replicas of 2 cards (≤ ~24k; custom) | 261 (456) | 11 h (6.1) | 43 h (24) | 8.9 d (5.1) |
| 5 cards, one BF16 model-parallel replica (32k fits) | 130 (220) | 21 h (13) | 3.6 d (2.1) | 18 d (11) |

Sums: 5 × 116 × 0.85 = 493; 5 × 240 × 0.85 × 0.9 = 918; 2 × 145 × 0.9 = 261; 2 × 240 × 0.95 = 456. Each row is one epoch.

**(D) Single-turn GRPO with `mix test` reward. Estimate.** One iteration: 16 prompts × 8 samples = 128 completions of ~1,000 generated tokens plus ~300 prompt tokens: 128k generated, 166k to train on. Five cards are time-sliced between vLLM and training.

| Phase | 5 cards, likely | 5 cards, best | 1 card, likely | 1 card, best |
|---|---:|---:|---:|---:|
| Generate at 1,000 (1,400) tok/s per card | 26 s | 18 s | 128 s | 91 s |
| Swap between vLLM and trainer | 15 s | 10 s | 20 s | 10 s |
| `mix test` at ~5 s each, 10 parallel on 12 cores | 64 s | overlaps training | overlaps training | overlaps training |
| Train on 166k tokens | 217 s | 129 s | 922 s | 593 s |
| Other (eval, logging) | ~18 s | ~23 s | 0 | 0 |
| **Per iteration** | **~340 s** | **~180 s** | **~1,070 s** | **~694 s** |
| 300 iterations | 28 h | 15 h | 3.7 d | 2.4 d |
| 1,000 iterations | 3.9 d | 2.1 d | 12 d | 8.0 d |

- Compile and test are the safe part: 128 runs per iteration needs 2 runs/s at most, within reach of 12 cores (~7,200 runs/h at 5 s each, 10 parallel).
- Bad code that hangs must be cut by a timeout. Plan a 30 s cap: at 10 % hung that adds ~40 s per iteration.
- Single-turn prompts fit one card comfortably: 8 × 1.3k tokens fits as micro-batches.
- The two 3080s (10 and 12 GB) could run vLLM all the time on a 4-bit 9B while the 3090s train, ending the time-slicing: est. 1,600 tok/s together gives 128k tokens in 80 s, overlapping training. Cost: +440 W.

**(E) Multi-turn agent RL. Estimate.**
- **Top down:** 64 H100 × 144 h ÷ 200 steps = 46 H100-hours per RL step. Assume H100 ≈ 3.5 × 3090 and 9B ≈ 1/3.5 of 32B per token: those factors cancel, leaving 46 3090-hours per step, or 9.2 h on five cards. 200 steps ≈ **77 days**.
- **Bottom up, batch 64** (trajectories of 20k tokens, 20 turns, ~5k generated):
  - Generation: ~20 min (8 best) by the project's measured session rate below.
  - Learner: 1.28 M tokens ÷ 493 = 43 min (23 best); on BF16 replicas 82 min.
  - Swaps: ~2 min.
  - Total **~65 min per step (33 best)**. 200 steps = 13,000 min = **9.0 d (4.6 d)**.
  - Batch 512 is ×8: ~72 d, agreeing with the top-down figure.
- **Split:** time-slicing all five cards is about as good as a fixed split. With 2 cards generating and 3 learning, generation of 64 sessions takes ~62 min and learning 72 min, at the cost of a stale policy if they overlap.
- **Context limits on serving:** KV for Qwen3.5-9B's 8 full layers: 8 × 2 × (4 × 256) × 2 B = 33 KB/token. A 3090 with ~16 GB free holds ~490k tokens, about 24 sessions of 20k, so 64–120 sessions is fine on five cards. A model with full attention in all 32 layers holds ~4× fewer.
- **Sandboxes:** 64 containers at once is nowhere near the thousands that broke `dockerd`, so plain Docker is fine and Kubernetes isn't needed. 1,280 tool calls × ~2 s of CPU ÷ 10 cores = ~4 min of a 20-minute generation phase.
- **Is (E) realistic?** At DeepSWE's batch, no. At batch 64 it's feasible but unproven: gradients are 8× noisier per step, sparse rewards need success rates well above zero, and the runs need every card for 1–2 weeks, with likely more than one attempt. DeepSWE's rise from 23 % to 42 % used a 512 batch, so it says nothing about 64. Do it last, on a small Elixir task set. Filtering teacher sessions to those that pass tests and training on them with (C) is a far cheaper first test, at ~1 day of cards. How close that gets to RL is unknown.

### Gaps
- No measured `mix test` time per sandbox on this box; the 5 s is a guess. The project's docs record session wall times but not per-run test times.
- Sessions per hour for a 9B student are not measured: 20 min scales from Flint's rate.
- Whether fewer than 512 trajectories per step learns at all on a task like this: I found no published small-batch agent-RL result. DeepSWE's training context limit, max steps and rollout/learner split are also unpublished — [Together AI](https://together.ai/blog/deepswe).
- rLLM's own training script defaults could not be read; its Mintlify mirror returns 410 — [rLLM docs](https://rllm-project.readthedocs.io/en/latest/examples/swe/).

## Data generation: can this box produce trajectories with an open teacher?

### Takeaway
Yes, with a 35–40B teacher. This box already made 1,177 gated agent sessions in about nine hours in 2026-10. Five 3090s should do ~120–155 sessions/h, so 2,000 sessions take ~13–17 h and 10,000 about 3 days. A 122B teacher costs ~6–10× more per session, so use it for a small gold set only.

### Cited Findings
- **Local:** long run 1: 21:28 to 06:37, all seven GPUs, 1,177 sessions through every gate (1,053 verified), 18,885 turns, 15.4 M generated tokens. Writers: vLLM NVFP4 on two 3090s made 567, vLLM on two 3080s + a 3090 made 524, llama-server Q8_0 on two V100s made 86 — [agentic_data_pipeline.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/agentic_data_pipeline.md).
- **Local:** Flint (40B-A2.5B) NVFP4 in vLLM, pipeline-parallel over two 3090s, 160 requests in flight, single-turn: ~2.4–2.7k answer tokens/s, 2.25k averaged over the first 10 minutes, ~8–9 M tokens/hour; KV cache held 204,344 tokens at 9.94 GiB per card next to 11.5 / 12.1 GB of weights — [drafter.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/drafter.md).
- **Local:** Flint's reasoning runs long: over 8,000 tokens before writing a test file — [agentic_data README](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agentic_data/README.md).
- **Local:** two 3090s in llama.cpp G3 at 96 slots managed ~350 tok/s, ~7× below vLLM — [drafter.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/drafter.md).
- **Local:** vLLM 0.31.0 with Humming ran on these 3090s, with CUDA 13 kept inside its own environment — machine notes.
- **Measured:** vLLM on a 3090: ~1,122 tok/s batch on Llama-2 7B, from a search excerpt of the paper's table — [arXiv 2404.11502](https://arxiv.org/pdf/2404.11502). Trinity Nano at concurrency 8, 512 in / 256 out: 1,446 tok/s BF16 and 1,711 W4A16 maximum; its parameter count isn't stated — [Arcee docs](https://docs.arcee.ai/quick-deploys/consumer-hardware/vllm).
- **Vendor:** ~4,000 tok/s on one A100 40GB (Llama 3.2 3B, 4-bit, vLLM) — [Unsloth RL guide](https://unsloth.ai/docs/get-started/reinforcement-learning-rl-guide).

### Inferences
**Estimate.**
- **Measured session rate:** 567 sessions ÷ 9.15 h = **62 sessions/h on two 3090s**, net of gates and stage turnover. Pro rata 7.4 M generated tokens ÷ 9.15 h = 225 tok/s, about 1/10 of its single-turn rate. Agent sessions are far slower than batched prompts, so plan on session rates, not tok/s. Mean session: 15.4 M ÷ 1,177 = 13.1k generated tokens over 16 turns.
- **Five 3090s:** two writers plus a spare gives 62 + 57 ≈ **120 sessions/h**; pro-rata best **155/h**. Pairs that cross x1 links should be fine, given the link-width result above, but test it.

| Sessions | Likely | Best |
|---|---:|---:|
| 500 | 4.2 h | 3.2 h |
| 2,000 | 17 h | 13 h |
| 10,000 | 3.5 d | 2.7 d |

- That counts gated sessions only. If the teacher passes the Elixir task half the time and you keep only passes, double those times.
- **Single-turn teacher answers:** two pairs at ~8–9 M tok/h = ~17 M tok/h. 100k answers × 800 tokens = 80 M = ~4.7 h, far faster than training on them (36 h).
- **Generation rate for a 9B student on vLLM:** ~1,000 tok/s per 3090 at BF16-to-W4A16 (likely), 1,400 (best); under long contexts, 500–1,000. Scaled from 1,122 at 7B and the Arcee figures.
- **122B teacher:** A10B against A2.5B is ~4× FLOPs per token. 4-bit weights ~61 GB across five cards leave ~12 GB of KV per card. Ceiling 1.2k per card × 5 ÷ 4 = 1.5k tok/s, realistically 0.6–1.2k. With the measured agent ratio of ~0.1: 60–110 tok/s, or **12–22 sessions/h**. 2,000 sessions = 3.8–7 d using all five cards.
- **Storage is trivial:** 20k tokens ≈ 80 KB of JSON; 10,000 sessions ≈ 1 GB. Don't copy the drafter's dump pipeline (37 KB per token): raw text is all training needs.

### Gaps
- No vLLM or SGLang throughput for a Qwen3.5-9B on a 3090 was found, and none for the 122B in vLLM.
- SGLang on Ampere: no 3090 measurement found. The project's notes say its Flint kernels target Blackwell and Hopper — [flint_speedups.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/flint_speedups.md). I would use vLLM, which is proven on this box.
- Unsloth's guide says vLLM lacks Qwen3.5 for GRPO and cites 0.16; that's old against 0.33.0 but I could not confirm 0.33.0's support. Serving through a separate vLLM needs a check.
- Teacher success rate on Elixir tasks: not measured here.

## Power, thermals and cloud

### Takeaway
Keep the 250 W cap: it costs ~7–17 % speed and saves ~8–18 % energy per token. Five cards draw ~1.6 kW at the wall, so a run costs €1–€55 and the mini-RL run ~€100. RunPod's cheapest equivalent costs 2–5× that in cash, though it buys time and 80 GB cards where 24 GB blocks you.

### Cited Findings
- **Local:** caps are 250 W on the 3090s and 220 W on the 3080s — machine notes.
- **Measured:** four 3090s at 237–250 W drew ~1,328 W at the wall; idle ~39 W per card; one card at ~314 W ran at 70 °C open-air — [Zagitta report](https://github.com/Zagitta/gpu-unlock/issues/75).
- **Measured:** Puget's quad-3090 ResNet-50 test kept over 95 % of speed at 280 W, and they suggest 250 W at ~93 % is reasonable; it is TensorFlow, not LLM training — [Puget Systems](https://www.pugetsystems.com/labs/hpc/quad-rtx3090-gpu-wattage-limited-maxq-tensorflow-performance-1974/).
- **Measured:** LoRA: 8.71 s at 240 W against 7.24 s at ~314 W on unlocked cards — [Zagitta report](https://github.com/Zagitta/gpu-unlock/issues/75).
- Eurostat's EU average household price for H1 2026 was ~€0.28/kWh, with Germany and Belgium at €0.36, as reported secondhand — [Brussels Times](https://www.brusselstimes.com/2384846/eu-electricity-prices-ease-in-2026-but-remain-elevated-after-energy-crisis).
- RunPod (page dated 2026-10-28), per GPU-hour, Secure / Community: RTX 3090 24 GB $0.50 / $0.22; RTX 4090 24 GB $0.89 / $0.34; RTX 5090 32 GB $1.19 / $0.69; A40 48 GB $0.59 / $0.35; A100 80 GB $1.79 / $1.19–1.39; H100 PCIe $2.89 / $1.99; H100 SXM $3.99 / $2.69 — [RunPod](https://www.runpod.io/pricing).
- Lambda, per GPU-hour: H100 $3.99–4.29, A100 80 GB $2.79, A6000 48 GB $1.09; no 3090 or 4090 listed — [Lambda](https://lambda.ai/pricing).
- Vast.ai's live grid was empty when fetched — [Vast.ai](https://vast.ai/pricing). Secondhand trackers put a 3090 at ~$0.35 and a 4090 at ~$0.29–0.50 — [comparison blog](https://dev.to/abdulrahman_maslmany/cloud-gpu-pricing-guide-2026-runpod-vs-lambda-vs-aws-vs-vastai-29e4); [tracker](https://altstreet.investments/tools/gpu/gpu-price-comparison).

### Inferences
**Estimate.**
- **Wall power, five cards at 250 W:** 1,250 W + ~350 W rest of system (from the 1,328 W reading) = **~1.6 kW**. At 350 W: ~2.1 kW.
- **One card at 250 W:** 250 W + 4 × 39 W + two idle 3080s ~60 W + ~180 W system = **~0.65 kW**.
- **Energy per token:** one card 650 W ÷ 180 tok/s = 3.6 J; five cards 1,600 ÷ 765 = 2.1 J. Running all five is cheaper per token than one, because the idle cards draw power anyway.
- **Cap:** Puget: 93 % speed at 71 % card power; at the wall (0.93 / 1.6) ÷ (1 / 2.1) = 1.22× tokens per kWh. Zagitta: 240 W against 314 W is 0.83× speed at 0.76× power, ~1.09× efficiency. So the cap saves 8–18 % of energy at a cost of 7–17 % wall time. Raise it only for a deadline.
- **Assumed price: €0.30/kWh.** Scale linearly for the real tariff.
- **Thermals:** a 5-card load lasting days at 250 W is new for this box, though run 1 held all seven GPUs for nine hours. Watch for slowdowns and log temperatures; one card reached 70 °C at 314 W in open air, which says little about a closed chassis.

| Job (likely) | Home | RunPod 5 × 3090 Community / Secure | RunPod H100 PCIe (assume 3.5× a 3090) |
|---|---:|---:|---:|
| LoRA 20k × 3 (60 M tok) | 22 h, 35 kWh, €10 | 22 h: $24 / $55 | 26.5 h: $53–77 |
| Trajectories 2,000 × 20k | 23 h, 36 kWh, €11 | 23 h: $25 / $56 | ~22 h in BF16 at 500 tok/s: $44–64 |
| Full-weight 20k × 3 | 37 h, 59 kWh, €18 | 37 h: $41 / $93 (likely faster on full x16 links) | ~33 h: $66–96; 80 GB is just enough with 8-bit Adam |
| Multi-turn RL, batch 64, 200 steps | 9 d, 347 kWh, €104 | $239 / $543 | ~155 h × 2 cards: ~$620–900 |
| DeepSWE as published (9,216 H100-h) | ~72–77 d, ~2,900 kWh | ~$1,900–4,600 (72–77 d × 5 cards) | $18,300–26,600 |

- Home figures exclude wear and exclude the cost of blocking the quant queue, which is the real price: the FN rows wait while training runs. Rented cards also have full-width links, so RunPod's multi-GPU rows are conservative.
- Rent when: a job needs 8k+ tokens in BF16 per card (80 GB cards solve the memory problem outright), or a deadline matters. Otherwise home wins on cash by 2–5×.

### Gaps
- GPU memory-junction temperatures for 3090s under multi-day LLM training: no source. `nvidia-smi` on GeForce may not show them.
- Multi-GPU availability and real speeds on Community pods vary. Prices are list prices.
- Eurostat figures are secondhand; the owner's actual tariff is unknown.

## Export path: LoRA to GGUF to the P106 rig

### Takeaway
The path is well-worn and takes under an hour of machine time: merge to BF16, convert, imatrix, quantize, relay to the rig. Train in BF16 or quantized, but always merge onto the BF16 base.

### Cited Findings
- **Vendor:** Unsloth writes GGUF directly with `save_pretrained_gguf` (q4_k_m, q8_0, f16) and merged BF16 with `save_pretrained_merged(..., save_method = "merged_16bit")`; if a model behaves worse in another runtime, suspect the chat template or EOS token first — [Unsloth Qwen3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune).
- **Local:** the project's imatrix recipe: `llama-imatrix` on a Q8_0 copy of BF16, 550 chunks of 512; own and Unsloth's imatrix came out equal within noise — [experiments.md Q12](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/quants/experiments.md).
- **Local:** builds and tarballs happen on the quant machine and relay to the rig; rig models live on a USB disk — project rules. `bench/agent_check` is the rig measurement — project rules.

### Inferences
**Estimate**, all on the quant machine except the last step:
1. Merge adapter into the BF16 base, in RAM or on one card: <5 min. Never merge against a 4-bit base.
2. `convert_hf_to_gguf.py` to BF16/F16: ~5 min, ~18 GB.
3. `llama-imatrix`, 281,600 tokens at ~1,000 tok/s on a 3090: ~5 min. Calibrate on Elixir text as well as general text, since the model is now specialised (idea, not tested).
4. `llama-quantize --imatrix` to Q4_K_M or the project's mixes: <10 min on CPU.
5. Relay ~5.5 GB to the rig at 35–53 MB/s: ~2–3 min.
6. On the rig: one-prompt check under Miner Llama, then `bench/agent_check`, with chat template checked against the training template.

Also keep the adapter itself. llama.cpp can apply LoRA at load, but merging is simpler for the rig's kernels.

### Gaps
- Whether Miner Llama's Pascal kernels cover a merged Qwen3.5-9B in the project's fast formats: not checked here.
- Whether imatrix calibrated on Elixir beats general text: no evidence.

## Recommended stack and the one-day smoke test

### Takeaway
Use two containers: Unsloth for LoRA (DDP via `torchrun`) and a separate vLLM 0.33 for generation, with Axolotl 0.21 as the fallback when FSDP2 or ZeRO-3 is needed. For RL use ART or a small own loop on top of the project's existing Elixir sandbox, and add rLLM + verl only if (E) gets a go. A one-day test will replace every estimate here.

### Cited Findings
- Versions on PyPI: Unsloth 2026.10.11 (torch <2.15, transformers ≤5.17, trl ≤1.15, Python <3.15) — [PyPI](https://pypi.org/pypi/unsloth/json). TRL 1.17.1, which includes GRPOTrainer — [PyPI](https://pypi.org/pypi/trl/json). vLLM 0.33.0 pins torch 2.14.0 with CUDA 13 extras, Python ≥3.11 — [PyPI](https://pypi.org/pypi/vllm/json). Axolotl 0.21.1 (2026-10-27), torch ≥2.13 and <2.15, Python ≥3.12 — [PyPI](https://pypi.org/pypi/axolotl/json). torch 2.15.0 is the latest — [PyPI](https://pypi.org/pypi/torch/json).
- Unsloth's image is `unsloth/unsloth`, needs driver 570.26 or newer and the NVIDIA Container Toolkit — [Unsloth Docker](https://unsloth.ai/docs/get-started/install/docker).
- A March 2026 survey of 16 RL libraries: ART is adapter-first with an Unsloth backend and cheap LoRA swaps but synchronous; TRL colocates simply but can't overlap generation and training; verl, SkyRL and slime are Ray or Megatron based, built for scale; PRIME-RL needs FSDP2; Atropos restarts vLLM to sync — [HF survey](https://huggingface.co/blog/async-rl-training-landscape).
- vLLM loads LoRA at runtime through `/v1/load_lora_adapter`, with `load_inplace` for continuously updated adapters, and warns to use it only in trusted environments — [vLLM LoRA](https://docs.vllm.ai/en/latest/features/lora/). Sleep mode level 1 moves weights to CPU and drops the KV cache — [vLLM sleep mode](https://docs.vllm.ai/en/latest/features/sleep_mode/).
- For Qwen3.5 under GRPO, Unsloth says to set `fast_inference=False` — [Unsloth Qwen3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune).
- rLLM's DeepSWE training wraps verl and targets Kubernetes — [rLLM training docs](https://rllm-project.readthedocs.io/en/latest/core-concepts/training/), [rLLM SWE docs](https://rllm-project.readthedocs.io/en/latest/examples/swe/).
- **Local:** several trainers on one HDD starved each other — [drafter.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/drafter.md). Downloads need the owner's OK — project rules.

### Inferences
**Stack (recommendation):**
| Job | Tool | Pins |
|---|---|---|
| SFT LoRA to ~6k tokens, sweeps | Unsloth in `unsloth/unsloth`, `torchrun --nproc_per_node=5` or five single-GPU jobs | torch 2.14.x, trl ≤1.15 |
| Full-weight, or anything Unsloth can't shard | Axolotl 0.21.1 own image, FSDP2 or ZeRO-3 | torch 2.14.x |
| Generation, teacher and student | vLLM 0.33.0, own container | as pinned |
| GRPO (D) | ART with Unsloth backend first, else a small loop: vLLM adapter hot-load + trainer | |
| Multi-turn RL (E) | same loop plus the project's `bench/agentic_data` sandbox; rLLM + verl only if that scales badly | plain Docker |

- **Docker fit:** containers bring their own CUDA user space through the torch wheels, so the host's CUDA 12.9 and 13.4 toolkits don't matter, only driver 595.99.02. Nothing requires a driver change. Trainer and vLLM need different pins (trl, torch extras), so don't share an image.
- **Run flags:** `--label pascal-quants=1`, GPUs pinned by UUID (2–6), `--shm-size=32g` (NCCL stages through host memory here), data and checkpoints on the NVMe, not an HDD. Sandboxes stay `--network none --cpu-shares 256`. Keep `NCCL_DEBUG=INFO` on for the first runs.

**One-day smoke test (needs: owner's OK for the model download and for timing a run):**
1. `nvidia-smi --query-gpu=index,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,power.limit --format=csv` during load. Record the true links.
2. Build `nccl-tests` in a container; `all_reduce_perf` on all five, then on x8 + x8 + x4. This replaces the 1 GB/s assumption.
3. One 3090 on x8: Qwen3.5-9B BF16 LoRA r16, 1k-token samples, 200 steps. Record tok/s, `max_memory_allocated`, power. Pass if ≥ ~140 tok/s.
4. Sequence sweep at batch 1: 2k, 4k, 8k, 16k, 32k in BF16, then 8-bit. Record the OOM point. This answers the 32k question for good.
5. DDP on five cards with the same data: pass if ≥ 4× one card. If the x1 cards drag, compare against three cards.
6. vLLM student at 64 long-context sessions: tok/s and KV use. 100 `mix test` sandboxes at 10 parallel: runs/s.
7. Merge, convert, quantize, relay, one prompt on the rig under Miner Llama.

A pass on 3, 4 and 5 turns the tables above into measured figures, by rescaling each row by measured tok/s ÷ 180.

**Order of real work:** five parallel one-card LoRA runs on 5k samples (~8 h for one epoch each), then DDP on 20k, then trajectories, then GRPO, then (E) only if the earlier steps show a gap RL could close.

### Gaps
- Exact Docker tags with torch 2.14 and CUDA 13 for Axolotl and vLLM: not verified. Build from the PyPI pins if none match.
- ART's support for Qwen3.5 and for a custom Elixir reward with a sandbox: not read. Check before committing to it.
- Whether all pins install together on sm_86: only a build on the box shows that. The one-build-at-a-time rule applies.
