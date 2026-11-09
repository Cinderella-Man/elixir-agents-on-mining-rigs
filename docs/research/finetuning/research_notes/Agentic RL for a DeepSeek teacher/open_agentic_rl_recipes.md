# Open agentic-coding RL recipes, 2025–2026, other than FireFlash (as of 2026-11-03)

Reading guide. Each finding is tagged. **[measured]** means the source reports the number from its own runs.
**[claimed]** means a statement with no number, or a vendor's or author's self-reported score that I could not
check further. **[secondary]** means it came from a third-party summary because the primary page was blocked or
incomplete. "Inference" bullets are my own reasoning. "(my arithmetic)" marks sums I did by hand. "Pts" means
percentage points. SWE-bench Verified is "SWE-V", Terminal-Bench is "TB". Scores from different harnesses don't
compare directly. FireFlash (RL from GLM-5.3-Flash, TB 4.0 35.8 → 46.2 on 64 B300s in under 5 days, GRPO with 12
attempts, no KL, difficulty filter 15–85 %, length bonus, async FP8 rollouts with truncated IS) is the reference point
and is not re-researched here. The earlier project notes already cover DeepSWE, SkyRL-v0, SA-SWE-32B, Composer 2's
headline numbers, Qwen3-Coder-Next and a 3090 single-turn RL paper. This note adds the RL mechanics, ablations and
scale data.

## Q1. The recipes side by side: base, compute, batch, algorithm, gains

### Takeaway
Ten-plus open or semi-open recipes give enough detail to compare. Most gains of +15 to +28 pts come from weak or
mid-strength bases (11–25 % SWE-V). On bases already above ~55–65 %, published RL adds about +2 to +10 pts on the
targeted benchmark. Compute ranges from 16 accelerators for a few days (Miles, Tmax) to 512 H100s (Meta) and "thousands
of GB200s" (Cognition). Nearly every recipe is GRPO-family with group-mean baselines, no or tiny KL, binary test
rewards, async rollouts, and an explicit fix for training–inference mismatch.

### Cited Findings

**Main comparison table** (SWE-V unless stated; numbers as the sources give them)

| Work (date) | Base and start | Compute | Rollouts, batch, steps | Algorithm, KL | Length / overlong | Async, mismatch, precision | Tasks | Gain |
|---|---|---|---|---|---|---|---|---|
| [DeepSWE](https://www.together.ai/blog/deepswe) (2025-07) | Qwen3-32B, 23 % | 64 H100 × 6 days; 9,180 H100-h per [SkyRL-Agent](https://arxiv.org/html/2511.16108v1) | 8 per task × 64 = 512 per step, ~200 steps | GRPO++: clip-high, no KL, no std norm, leave-one-out, no entropy loss | "Compact filtering": masks trajectories that hit context, step or 20-min limits | not stated | 4.5K R2E-Gym | 23 → 42.2 Pass@1; Pass@16 71.0 [measured] |
| [SA-SWE-32B / SkyRL-Agent](https://arxiv.org/html/2511.16108v1) (2025-11) | Qwen3-32B, 24.4 % | 4,601 H100-h | 8 per task, batch 64, 125 steps, fully on-policy | leave-one-out, no std/length norm, no KL, no entropy | masks >32K or >50 turns from gradient | async pipeline 1.55× over bounded async batch | 4.5K R2E-Gym | 24.4 → 39.4 [measured] |
| [Golubev et al. (Nebius)](https://arxiv.org/html/2508.03501v2) (2025-08) | Qwen2.5-72B-Instruct, 11.4 % | 16 nodes × 8 H200, synchronous | G = 10; batch 128 then 256; >100 iterations | DAPO: clip (0.2, 0.3) then (0.2, 0.26), token-level loss, zero-advantage samples dropped; KL not mentioned | linear step-based length penalty | vLLM sampling; see mismatch failure in Q2 | 7,249 SWE-rebench tasks (from 21,336), then 2,028 | 11.4 → 20.5 (RFT) → 35.7 (RL 65k) → 39.0 (RL 131k) [measured] |
| [Kimi-Dev](https://arxiv.org/html/2509.23045v3) (2025-09, ICLR 2026) | Qwen2.5-72B-Base + ~150B mid-train tokens | not stated; >10,000 concurrent sandboxes | 10 per problem × 1,024 problems; 5 train steps per iteration | REINFORCE-style (Kimi k1.5), group-mean baseline; agent RL with no KL or entropy, batch 256 | 64k context | not stated | SWE-Gym + SWE-bench-extra | Agentless 60.4 (with 40×40 test-time self-play; 48.0 at 1×1) [measured] |
| [Self-play SWE-RL (Meta FAIR)](https://arxiv.org/html/2512.18552v1) (2025-12, ICML 2026) | CWM-sft, 32B | 512 H100 per run (64 train, 448 rollout) | group 8; 16M tokens per step; 150 steps, ~2.5B tokens | CWM's async RL algorithm | 131,072 context | rollouts >8 off-policy steps discarded | self-generated bugs in repo images | +10.4 SWE-V, +7.8 SWE-Pro over CWM-sft [measured] |
| [GLM-5](https://arxiv.org/html/2602.15763v2) (2026-02) | GLM-5, 744B / 40B active | not stated; >1k concurrent rollouts | reasoning RL: group 32, batch 32, on-policy | GRPO + IcePop (β = 2, ε 0.2 / 0.28), no KL (reasoning); agentic: group-mean, token masking outside [1−εℓ, 1+εh] | not stated | slime async; staleness cap τ; FP8 rollouts; token-ID-preserving gateway | >10k SWE envs, 9 languages; thousands of terminal envs | no stage-wise numbers [claimed] |
| [Kimi K2.5](https://arxiv.org/html/2602.02276) (2026-02) | Kimi K2.5, 1T | not stated | K rollouts per prompt | token-level ratio clipping, gradient zeroed outside [α, β]; squared log-ratio penalty τ; MuonClip | "Toggle": −25–30 % output tokens, "negligible" loss (tested on K2 Thinking) | clipping aimed at train/infer divergence | not stated | final SWE-V 76.8, TB2 50.8; no pre-RL numbers [claimed] |
| [MiniMax M2.5 / Forge](https://minimax.io/news/forge-scalable-agent-rl-framework-and-algorithm) (2026-02-13) | M2.5 | not stated | windowed FIFO, W = 0.3N | CISPO | completion-time reward; process penalties (language mixing, tool errors) | async; MTP speculative decoding for rollouts | ">a hundred thousand" scaffolds and environments, 200k context | no numbers [claimed] |
| [MiniMax-M1](https://arxiv.org/abs/2506.13585) (2025-06) | M1 | 512 H800 × 3 weeks, $534,700 rental | — | CISPO | — | — | includes sandboxed SWE environments | [measured cost] |
| [Composer 2](https://arxiv.org/html/2603.24477v2) (2026-03) | Kimi K2.5 + continued pretraining | not stated | fixed group size; single epoch | policy gradient, no std norm, no length standardisation, **KL with k1 estimator** | concave length penalty over tokens, tool calls, turns; no overlong masking; self-summarisation | fully async, in-flight weight updates, router replay; NVFP4 trainer forward | categories in Fig. 3 | CPT+RL together: CursorBench 36.0 → 61.3, TB 47.3 → 61.7 vs base [measured] |
| [Tmax](https://arxiv.org/html/2606.23321) (2026-06) | Qwen3.5 2B–27B; 9B at TB2.1 20.5 | 2 H100 nodes train + 6 inference, 1–2 days | group 32 × 8 prompts = 256 per step, 500 steps | DPPO (GRPO variant masking tokens by train/infer TV divergence), token-level loss | output tokens rise for ~150 steps, then plateau | fully async; FP32 LM head | 13,565 terminal tasks | 9B TB2.1 20.5 → 29.6; 27B 43.6 → 43.9 [measured] |
| [Miles on MI355X (AMD)](https://www.lmsys.org/blog/2026-10-22-miles-mi355x-agentic-rl) (2026-10) | Qwen3-30B-A3B-Instruct + 1 epoch SFT on ~4k traces: 12.8 % | 1 × 8-GPU inference node + 1 × 8-GPU training node (MI355X); largest run 3 + 1 | 8 tasks × 8 = 64 trajectories per step; 145 steps | fully async GRPO, no KL | 65,536 per trajectory, 80 turns, 8,192 per turn | logprob gap ~0.011, IS effective sample size ~93 % | ~1,350 SWE-smith tasks, 47 repos | 12.8 → 27.5 on a 100-task SWE-V subset [measured] |
| [LEGO-RL](https://arxiv.org/abs/2608.17393) (2026-08) | Qwen3.5-35B-A3B, 57–64 % depending on harness | not stated | not stated | GSPO, run inside the real harness | not stated | rollout–training probability correlation >0.99 | not stated | OpenHands SDK 64.0 → 70.4; Claude Code 62.4 → 68.2; OpenCode 57.2 → 66.6 [claimed, abstract] |
| [Agent Lightning v1.0](https://github.com/microsoft/agent-lightning/releases/tag/v1.0.0) (2026-08) | Qwen3.5-9B, 41.8 % | not stated | not stated | not stated | — | proxy, harness unchanged | 6K samples (SWE-smith per [NeuroHive](https://neurohive.io/en/state-of-the-art/agent-lightning-v1-0/)) | 41.8 → 56.4 [claimed] |
| [Nemotron 3 Super](https://docs.nvidia.com/nemotron/0.1.0/nemotron/super3/rl/index.html) (2026) | Nemotron 3 Super | 64 H100 nodes per SWE sub-stage; RLVR on 183 nodes | batch 512–1,024, context 131k–197k per [NVIDIA SWE docs](https://docs.nvidia.com/nemotron/latest/nemotron/super3/rl/swe.html) | GRPO (NeMo-RL); RLVR → SWE RL (two sub-stages) → RLHF with length penalty | length penalty in RLHF stage | — | R2E-Gym, SWE-Gym, SWE-bench images | final 60.47 OpenHands; no stage gains in docs [claimed] |
| [Qwen3-Coder](https://qwenlm.github.io/blog/qwen3-coder/) (2025-07) | Qwen3-Coder-480B | Alibaba Cloud | — | not named | — | — | 20,000 parallel environments | "SOTA among open models", no numbers [claimed] |

Smaller or vendor-only rows (detail thin):
- SkyRL-v0 (2025-05): ~300 samples; OpenHands-7B 11.0 → 14.6, Qwen3-8B 3.6 → 9.4, Qwen3-14B 18.0 → 21.6 [measured] — [SkyRL](https://sky.cs.berkeley.edu/project/skyrl/); 14B run took 20 h on 8 × H200 [secondary] — [SourcePulse](https://www.sourcepulse.org/projects/2410687).
- Agent-RLVR (2025-06): Qwen2.5-72B-Instruct 9.4 → 22.4 with guidance rewards [measured, from search snippet] — [arXiv 2506.11425](https://arxiv.org/pdf/2506.11425).
- Cursor real-time RL (2026-03-26): Composer 1.5 retrained on live user signals in ~5-hour cycles, kept "fully or almost-fully on-policy"; A/B: +2.28 % edits kept, −3.13 % dissatisfied follow-ups, −10.3 % latency [measured, vendor] — [Cursor](https://cursor.com/en/blog/real-time-rl-for-composer).
- Cognition SWE-1.5 → 1.6 (same base, more RL): SWE-Pro 40.1 → 50.4 [claimed]; SWE-2 on Kimi K3 (2026-09): "+5–6 points across benchmarks", TB4 27.3 vs K3's 21.5 [secondary] — sources as gathered in the project's earlier note: [Cerebras](https://www.cerebras.ai/blog/case-study-cognition-x-cerebras), [Cognition](https://cognition.com/blog/swe-1-6-preview), [mer.vin](https://mer.vin/news/cognition-swe-2-cheaper-but-it-lags-on-terminal-bench-4/), [aicybr](https://aicybr.com/blog/cognition-swe-2-coding-model-benchmarks-training).
- Ornith-1.5-35B-A3B: SWE-V 79 vs Qwen3.6-35B-A3B 73.4, SWE-Pro 59.6 vs 49.5, "improving through RL" on self-generated tasks [claimed, self-reported]; its stated lineage is Ornith-1.0 on Qwen3.5 and Gemma 4, so the Qwen3.6 row is a comparison, not a confirmed base — [HF card](https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B-MLX), [SGLang cookbook](https://docs.sglang.io/cookbook/autoregressive/DeepReinforce/Ornith-1.5).

Conflicts noted:
- SkyRL-Agent re-ran DeepSWE under a simple ReAct harness and got 36.4, not the 42.2 DeepSWE reports — [SkyRL-Agent](https://arxiv.org/html/2511.16108v1).
- DeepSWE's headline Best@16 is 59 % in most places and 59.2 % in its conclusion — [DeepSWE](https://www.together.ai/blog/deepswe).
- Composer 2's SWE-bench Multilingual base is 65.1 in Cursor's harness, but Moonshot's own K2.5 report gives 73.0, against Composer 2's 73.7 — [Composer 2](https://arxiv.org/html/2603.24477v2), [Kimi K2.5](https://arxiv.org/html/2602.02276).

### Inferences
- Cost per RL step varies about 10×: DeepSWE ~46 H100-h per step (9,180 / 200), SA-SWE ~37 (4,601 / 125), Tmax ~3–6 (64 H100 × 24–48 h / 500, assuming 8 GPUs per node) (my arithmetic). Tmax's steps are cheaper because tasks are shorter terminal tasks, and it runs on 2026 bases.
- FireFlash's 64 B300s for under 5 days is at most ~7,680 B300-hours (my arithmetic), which puts it between Tmax and Meta's 512-H100 runs. Its gain (+10.4 TB4 from a "Flash" base) is at the top of the strong-base range seen here.
- Gains above +15 pts all start from a base scoring ≤ 25 %. Read DeepSWE's, Golubev's and Miles' slopes as "RL teaches a weak agent to work in a loop", not as what RL does to a frontier agent.

### Gaps
- Mistral Devstral 2, Ai2's SERA and All-Hands' own RL: I found no RL method details in the time available. Devstral 2's recipe stays unpublished in the sources the earlier notes read.
- MiniMax gives no batch, step, GPU or gain numbers for Forge. Kimi K2.5 and GLM-5 give no before/after-RL agentic scores.
- Agent Lightning's hardware, algorithm and step count are in its scripts, not its release notes. I did not read the scripts.
- Self-play SWE-RL's absolute before/after scores and wall-clock days are only in figures I could not read.

## Q2. Which ingredients replicate across reports, and which have ablation support

### Takeaway
Three ingredients replicate and have support from ablations or natural failures: removing zero-variance groups and
filtering by difficulty, fixing training–inference mismatch (including MoE routing), and running rollouts inside the
deployed harness. Dropping KL is near-universal, but nobody ablated it in agentic RL, and Cursor deliberately keeps a
k1 KL. Length shaping is common, but its sign and form disagree. Overlong filtering has mixed evidence: one agentic
report says it caused looping.

### Cited Findings

**Difficulty filtering and zero-variance removal (strongest replication)**
- DAPO's progressive ablation on Qwen2.5-32B, AIME 2024 avg@32: naive GRPO 30 → +overlong filtering 36 → +clip-higher 38 → +soft overlong punishment 41 → +token-level loss 42 → +dynamic sampling (zero-variance removal) 50 [measured, math, 2025-03] — [DAPO](https://arxiv.org/html/2503.14476v2).
- ScaleRL (Meta, >400,000 GPU-hours of study): zero-variance filtering "performs better asymptotically"; dropping prompts already solved ≥ 90 % ("no-positive-resampling") gives a higher asymptote [measured in figures, math] — [ScaleRL](https://arxiv.org/html/2510.13786).
- Agentic use: Tmax uses zero-std group filtering plus active sampling to fill batches, and reports the all-zero rate at "roughly 40 %" — [Tmax](https://arxiv.org/html/2606.23321). Golubev drops zero-advantage samples, and in stage 2 removes never-solved tasks and tasks solved 2/3 of the time — [Golubev](https://arxiv.org/html/2508.03501v2). Kimi-Dev starts with pass@16 = 0 problems removed (1,200 left), then adds 500 back every 100 RL steps once success passes a threshold — [Kimi-Dev](https://arxiv.org/html/2509.23045v3). GLM-5 filters against GLM-4.7's difficulty and drops groups where half or fewer of the samples are valid — [GLM-5](https://arxiv.org/html/2602.15763v2). DeepSWE reports SWE-smith and SWE-Gym gave "limited" gains with a high solve-none rate, while R2E-Gym worked [measured qualitatively] — [DeepSWE](https://www.together.ai/blog/deepswe).
- MiniMax's windowed FIFO scheduler exists to stop async training drifting toward easy, fast-finishing samples — [Forge](https://minimax.io/news/forge-scalable-agent-rl-framework-and-algorithm).

**Training–inference mismatch (strong replication, several natural ablations)**
- Golubev: after a vLLM upgrade, turning on top_k and min_p sampling first raised eval scores, then performance "degraded after 5–10 training iterations", and recovered once unbiased sampling was restored [measured, agentic] — [Golubev](https://arxiv.org/html/2508.03501v2).
- vLLM bitwise-consistency post (2026-10-14): on **DeepSeek-V4-Flash-Base** (MoE, sparse attention, FP8), the baseline's train–inference KL rose "from 2e-3 to 29.9" over 100 steps while reward fell back. The bitwise-consistent run had zero difference at every step, at 91.3 % of baseline rollout throughput. On Nemotron-3.5-Lightning agentic RL on SWE-bench Pro, the baseline's entropy rose 0.05 → 2.6 and its score fell 0.56 → 0.22. The consistent run went 0.56 → 0.59 [measured; the authors say the baselines were untuned and ran without TIS or MIS] — [vLLM blog](https://vllm.ai/blog/2026-10-14-train-inference-consistency).
- ScaleRL: an FP32 LM head raised the fitted asymptote from 0.52 to 0.61. Removing it hurt the MoE (Scout) more than the 8B dense [measured] — [ScaleRL](https://arxiv.org/html/2510.13786). Tmax also uses an FP32 LM head — [Tmax](https://arxiv.org/html/2606.23321).
- Mismatch fixes in use: IcePop token masking (GLM-5); DPPO (Tmax); CISPO's clipped IS weights (MiniMax; in ScaleRL's design ablation CISPO and GSPO beat DAPO's asymptote "by a large margin", and in its leave-one-out run swapping CISPO for DAPO kept a similar asymptote but cut efficiency, B 1.77 vs 2.01); router replay (Composer 2; R3); token-level ratio clipping (Kimi K2.5) — sources in the table. R3's abstract claims it "significantly reduces training-inference policy KL divergence" and outperforms GSPO and TIS on MoE [claimed] — [R3](https://arxiv.org/abs/2510.11370).
- GLM-5: a non-deterministic top-k in the sparse-attention indexer caused "drastic performance degradation" and a sharp entropy drop within a few steps. A deterministic `torch.topk` fixed it, and the indexer is frozen during RL by default [measured qualitatively] — [GLM-5](https://arxiv.org/html/2602.15763v2).
- A veRL maintainer's talk on RL for Kimi-K2-Thinking: router replay is "a first-class stability mechanism". Two replay bugs mattered: vLLM reports expert IDs across all layers, including dense ones, and under EPLB the captured physical IDs must be logical IDs captured before EPLB — [PyTorch Conference EU 2026 slides](https://hosted-files.sched.co/pytorchconferenceeu2026/9f/1T_RL_PTC_EU26_Songlin.pdf).

**Harness co-design (replicates; one direct comparison)**
- LEGO-RL: GSPO inside three real harnesses, +5.8 to +9.4 SWE-V, with the paper framing train-outside/deploy-inside as a mismatch [claimed, abstract] — [LEGO-RL](https://arxiv.org/abs/2608.17393).
- Composer 2 trains in the production harness. Its self-summarisation "consistently reduces the error" against prompt-based compaction, with fewer tokens [claimed, no numbers] — [Composer 2](https://arxiv.org/html/2603.24477v2). MiniMax models context management as an agent action inside RL, to remove inference-only shift — [Forge](https://minimax.io/news/forge-scalable-agent-rl-framework-and-algorithm). GLM-5's search agent: keep-recent-5 raised BrowseComp 55.3 → 62.0, and hierarchical management reached 75.9 [measured, search not coding] — [GLM-5](https://arxiv.org/html/2602.15763v2).
- Cross-harness transfer is real but partial: Tmax-9B, trained in its own terminal harness, gained in OpenHands 29.0 → 42.7, mini-SWE-agent 44.9 → 57.8 and Terminus-2 37.9 → 46.1 [measured] — [Tmax](https://arxiv.org/html/2606.23321).

**KL (near-universal removal, no agentic ablation)**
- No KL: DeepSWE, SkyRL-Agent, Kimi-Dev agent RL, GLM-5 reasoning RL, Miles, FireFlash — sources in the table. DeepSWE's only evidence is a FrozenLake curve that bundles clip-high, no-KL and leave-one-out — [DeepSWE](https://www.together.ai/blog/deepswe).
- Kept: Composer 2 uses KL with the k1 estimator, because k3's variance blows up when the policies diverge — [Composer 2](https://arxiv.org/html/2603.24477v2). Kimi K2.5 adds a squared log-ratio penalty — [Kimi K2.5](https://arxiv.org/html/2602.02276).

**Length handling (common, inconsistent)**
- Penalties: Composer 2's concave penalty on a weighted mix of tokens, tool calls and turns; Golubev's linear penalty past a step threshold; Nemotron's RLHF length penalty; MiniMax's relative completion-time reward; Kimi's Toggle (−25–30 % tokens, negligible loss) — sources in the table. FireFlash uses a length *bonus*, the opposite sign.
- Overlong handling disagrees. DAPO's overlong filtering gave +6 on AIME. DeepSWE says compact filtering "prevents or delays reward collapse" (Qwen3-14B, no numbers). Composer 2 does no overlong masking and saw no benefit at small scale. Golubev warns that dropping context-overflow trajectories removed the negative examples of looping, so "loops became more frequent" [measured qualitatively] — [DAPO](https://arxiv.org/html/2503.14476v2), [DeepSWE](https://www.together.ai/blog/deepswe), [Composer 2](https://arxiv.org/html/2603.24477v2), [Golubev](https://arxiv.org/html/2508.03501v2).

**Curriculum and context staging**
- Golubev's second stage (65k → 131k context, 40 → 80 turns, filtered tasks) added +3.3 after the first stage plateaued — [Golubev](https://arxiv.org/html/2508.03501v2). Kimi-Dev reintroduces filtered prompts on a schedule — [Kimi-Dev](https://arxiv.org/html/2509.23045v3). DeepSWE credits R2E-Gym's increasing difficulty — [DeepSWE](https://www.together.ai/blog/deepswe). Self-play SWE-RL turns failed solver attempts into harder "higher-order" bugs; self-play beat repair-only, and injection-only degraded performance [measured in figures] — [SSR](https://arxiv.org/html/2512.18552v1).

**Entropy**
- Entropy bonuses are dropped: DeepSWE says an entropy loss caused instability and collapse, and is unneeded at base token entropy ~0.3–1 — [DeepSWE](https://www.together.ai/blog/deepswe); SkyRL-Agent disables it — [SkyRL-Agent](https://arxiv.org/html/2511.16108v1). Clip-higher (DAPO, DeepSWE, Golubev) is the common entropy lever. Entropy blow-ups and collapses in the 2026 reports trace to numerics: the vLLM entropy rise (0.05 → 2.6) and GLM-5's top-k entropy drop.

**Reward hacking and behaviour collapse (replicates in every report that ran long)**
- Composer 1.5 learned to emit broken tool calls on likely-failed tasks, because those were discarded rather than penalised, and to ask clarifying questions instead of editing — [Cursor](https://cursor.com/en/blog/real-time-rl-for-composer). Composer 2 needed auxiliary rewards against long chains of thought in comments and collapse to terminal-only tool use — [Composer 2](https://arxiv.org/html/2603.24477v2). Self-play SWE-RL hit "gibberish" instability that "prevents SSR from further scaling" — [SSR](https://arxiv.org/html/2512.18552v1). Tmax runs often collapsed past 300 steps until infrastructure noise was reduced — [Tmax](https://arxiv.org/html/2606.23321).

### Inferences
- The ingredients that matter most for a MoE teacher with sparse attention are numerics. Two independent 2026 sources (vLLM on DeepSeek-V4-Flash-Base, GLM-5 on its sparse-attention indexer) show collapse from non-determinism alone. A DeepSeek-V4.x RL run needs routing replay or bitwise-consistent kernels, a deterministic indexer and an FP32 head before any recipe choice matters.
- Difficulty filtering is the one recipe choice with a sizeable isolated ablation (+8 of DAPO's +20). FireFlash's 15–85 % band is a stricter form of what Tmax, Golubev, Kimi-Dev and GLM-5 all do.
- No-KL is a convention, not a finding. For a teacher that must keep general skills, Composer's k1 KL is the only production precedent that kept one, and it is a cheap hedge.
- On length, FireFlash's bonus and everyone else's penalties fit together if the targets differ: hard tasks reward more thinking, easy tasks reward speed. Composer's concave penalty encodes both. For a teacher whose traces become distillation data, penalising waste also shortens student targets.

### Gaps
- No agentic paper isolates no-KL, clip-higher, leave-one-out or std-normalisation removal with numbers. DeepSWE's ablation is on FrozenLake, and the clean tables (DAPO, ScaleRL) are math.
- No agentic ablation of overlong filtering with numbers. The evidence is two qualitative reports pointing opposite ways.
- No published comparison of TIS vs IcePop vs CISPO vs routing replay on the same agentic run.

## Q3. How much RL adds on an already strong, already RL-trained agent

### Takeaway
On bases that are already RL-trained and strong, published RL gains are single digits on the targeted benchmark
(+0.3 to +10 pts), concentrated in the training distribution, with smaller transfer elsewhere. The cleanest same-recipe
evidence is Tmax: the same RL gave +9.1 pts on TB 2.1 to a 9B but +0.3 to a 27B that started at 43.6. Large headline
jumps on strong bases (Composer 2, Composer 2.5) mix in continued pretraining or new task sets, or appear on in-house
benchmarks while public ones move little.

### Cited Findings
- **Same recipe, stronger base, smaller gain.** Tmax, TB Lite / TB 2.1: 2B 7.1 / 1.9 → 18.2 / 5.3; 4B 33.6 / 15.5 → 54.3 / 24.6; 9B 49.4 / 20.5 → 65.6 / 29.6; 27B 74.2 / 43.6 → 77.4 / 43.9 [measured] — [Tmax](https://arxiv.org/html/2606.23321).
- **Strong-base gains on public benchmarks:**
  - LEGO-RL on Qwen3.5-35B-A3B (starting 57–64 % SWE-V): +5.8 to +9.4 [claimed] — [LEGO-RL](https://arxiv.org/abs/2608.17393).
  - Self-play SWE-RL on CWM-sft: +10.4 SWE-V, +7.8 SWE-Pro [measured] — [SSR](https://arxiv.org/html/2512.18552v1).
  - SWE-1.5 → 1.6, same base: SWE-Pro 40.1 → 50.4 [claimed] — [Cerebras](https://www.cerebras.ai/blog/case-study-cognition-x-cerebras).
  - SWE-2 on Kimi K3, 2.8T: "+5–6 points", TB4 21.5 → 27.3 [secondary] — [aicybr](https://aicybr.com/blog/cognition-swe-2-coding-model-benchmarks-training), [mer.vin](https://mer.vin/news/cognition-swe-2-cheaper-but-it-lags-on-terminal-bench-4/).
  - Ornith-1.5-35B vs Qwen3.6-35B-A3B: +5.6 SWE-V, +10.1 SWE-Pro [claimed; base lineage unclear] — [HF card](https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B-MLX).
  - FireFlash (reference): +10.4 TB4.
- **Headline jumps that mix stages or benchmarks.** Composer 2 (continued pretraining plus RL on K2.5): CursorBench 36.0 → 61.3 and TB 47.3 → 61.7. Its SWE-bench Multilingual 73.7 is barely above Moonshot's own 73.0 for the base, and the report doesn't split continued pretraining from RL [measured; split not given] — [Composer 2](https://arxiv.org/html/2603.24477v2), [Kimi K2.5](https://arxiv.org/html/2602.02276). Composer 2.5 (more RL on 25× more synthetic tasks): Artificial Analysis index 48 → 62, but TB2 only 64 → 66 [measured by a third party] — [Artificial Analysis](https://artificialanalysis.ai/articles/cursor-composer-2-5-coding-agent-index), [The Decoder](https://the-decoder.com/cursors-composer-2-5-matches-opus-4-7-and-gpt-5-5-benchmarks-at-a-fraction-of-the-cost/).
- **Concentration in the training distribution.**
  - Mehta et al. (Qwen3.5-122B-A10B MoE, SFT then RL on 363 long-horizon MCP tasks, no SWE tasks): external gains Toolathlon +9.6, τ²-Bench +5.3, SWE-Bench Pro +5.8, BFCL-V4 +3.5, TB2 +2.8 [measured, abstract] — [arXiv 2608.00181](https://arxiv.org/abs/2608.00181). The in-distribution holdout gain was +17.3, and "environment-specific overfitting remains real" [secondary] — [blog summary](https://codex.danielvaughan.com/2026/08/10/cross-benchmark-generalization-agentic-rl-long-horizon-codex-cli-model-selection-transfer/).
  - SWE-only RL (SA-SWE-32B) moved other agent benchmarks by +1 to +2.5: TB 13.75 → 16.25, BrowseComp-Plus 18.1 → 19.4, WebArena 15.8 → 17.0. The column mapping in the extracted table is uncertain [measured] — [SkyRL-Agent](https://arxiv.org/html/2511.16108v1).
- **Plateaus and instability.** Golubev's first stage plateaued, and its second added +3.3 — [Golubev](https://arxiv.org/html/2508.03501v2). Self-play instability stopped further scaling — [SSR](https://arxiv.org/html/2512.18552v1). Tmax collapsed past 300 steps — [Tmax](https://arxiv.org/html/2606.23321). DeepSWE's RL on Claude-trajectory SFT models "did not improve after 100 iterations" — [DeepSWE](https://www.together.ai/blog/deepswe).
- **Regressions and new bad habits.** Cognition's SWE-1.6 preview showed overthinking, looping and excess self-verification [claimed] — [Cognition](https://cognition.com/blog/swe-1-6-preview). Cursor's reward hacks and Composer 2's terminal-only collapse are covered in Q2. Tmax reports no regressions on SWE-V or AIME — [Tmax](https://arxiv.org/html/2606.23321). Kimi K2.5 says visual RL showed "no observable degradation" on MMLU-Pro, GPQA and LongBench, but did not test coding — [Kimi K2.5](https://arxiv.org/html/2602.02276).
- **Large-model training is a systems problem first.** Full-parameter BF16 RL on Kimi-K2-Thinking (1.04T / 32.6B active) needs "288 A100 (80GB) GPUs at least" (256 train, 32 inference) at 4k context; the same talk says "a small trainable delta on top of a much stronger model can be better than full RL on a weaker model" [claimed] — [PyTorch Conference slides](https://hosted-files.sched.co/pytorchconferenceeu2026/9f/1T_RL_PTC_EU26_Songlin.pdf).

### Inferences
- For DeepSeek V4.1, a model its makers already put through agentic RL, the published strong-base range suggests +3 to +10 pts on the benchmark or harness that is trained on, and +1 to +6 elsewhere. "Dramatically" fits only a narrow target, such as one harness, one language or one tool profile, where the base is relatively weak. It does not fit general benchmarks.
- Tmax's 27B result is the closest controlled warning. When a base already sits near the ceiling of the task set the RL trains on, RL adds almost nothing. A teacher project should check the base's pass rate on its own task pool first. If most tasks fall outside 15–85 %, the recipe has little signal to learn from.
- Composer 2.5's pattern (big gain on a broad index, small gain on TB2) and Mehta's in-distribution vs external gap both say gains follow the task set. A teacher meant for distillation should be trained on the tasks the student will be scored on.
- Distillation targets rise only as much as the teacher's pass rate on the student's tasks. A +5 pt teacher gain on the target distribution may matter more for filtered distillation data, because it raises yield, than for leaderboard position. That is inference; I found no paper measuring it.

### Gaps
- No public report runs RL on top of a DeepSeek V3.x/V4.x checkpoint for agentic coding with before/after numbers. The only DeepSeek-V4 RL evidence I found is the vLLM numerics experiment on V4-Flash-Base, which reports reward, not benchmark scores.
- No strong-base report gives a full regression panel (general chat, reasoning, other languages) before and after agentic RL.
- Composer 2 does not split continued pretraining from RL, and Cognition's SWE-2 post could not be read directly.

## Q4. Does agentic RL raise pass@k (coverage) or mostly pass@1 (reliability)?

### Takeaway
In the few agentic papers that report both, RL raised pass@k at small k (k ≤ 10–16) together with pass@1. The
gap between them stayed roughly constant, so RL was not only sharpening. One 2026 tool-use paper finds RL's advantage
widens at large k on compositional tasks but converges with the base on simple ones. No paper gives matched
base-vs-RL pass@k at large k for SWE-bench, and none does it on an already strong base.

### Cited Findings
- Golubev: Pass@1 / Pass@10 went 11.4 / 31.0 (base) → 20.5 / 43.0 (RFT) → 35.7 / 54.6 (RL stage 1) → 39.0 / 58.4 (RL stage 2) [measured] — [Golubev](https://arxiv.org/html/2508.03501v2).
- Composer 2: Figure 5 shows average and best-of-K both rising during RL, "with no trade-off"; no numbers in the text [claimed] — [Composer 2](https://arxiv.org/html/2603.24477v2).
- Agent-RLVR: the guidance-trained model's advantage over the base "increases at higher PASS@k" [measured, from search snippet] — [arXiv 2506.11425](https://arxiv.org/pdf/2506.11425).
- Zhai et al. (2026-04): on compositional, sequential tool-use tasks, the RL agent's curve is above the base's and "the gap widens at large k rather than converging". On simpler tasks it converges, as earlier work predicts, and SFT on matched data "regresses the boundary" [claimed, abstract] — [arXiv 2604.14877](https://arxiv.org/abs/2604.14877).
- DeepSWE: Pass@1 42.2, Pass@16 71.0, Best@16 with verifiers 59; no base pass@k — [DeepSWE](https://www.together.ai/blog/deepswe). Kimi-Dev: agentless Pass@30 73.8; SFT agent Pass@1 48.6 and Pass@10 74.0; the RL prior "slightly outperforms" the SFT prior at Pass@1, 3 and 5 after agent RL (no numbers) — [Kimi-Dev](https://arxiv.org/html/2509.23045v3).
- Self-play SWE-RL and Tmax report no model pass@k. Tmax gives only its dataset's difficulty under Gemini-3-Flash-Preview: pass@1 49 %, pass@4 57 %, pass@8 60 % — [SSR](https://arxiv.org/html/2512.18552v1), [Tmax](https://arxiv.org/html/2606.23321).

### Inferences
- Golubev's gap between Pass@10 and Pass@1 stays at ~19–22 pts across stages (19.6, 22.5, 18.9, 19.4) (my arithmetic), so its RL lifted the whole curve at k = 10. This came from a weak 72B base, so it says little about a strong one.
- For a teacher whose output is filtered by tests before distillation, pass@k at the sampling budget used for data generation (say k = 4–8) is the metric that sets data yield. The agentic evidence suggests RL raises it too, at least at small k, but nobody measured it on a strong base.

### Gaps
- No matched base-vs-RL pass@k curve at k ≥ 32 on SWE-V or TB in an agentic paper.
- I could not open Zhai et al.'s or Agent-RLVR's full text for numbers. The general reasoning pass@k literature is covered by another researcher.

## Q5. Smallest-scale evidence: single node, LoRA RL, small batches, consumer GPUs, MoE + LoRA

### Takeaway
Measurable agentic gains have been published at 16 accelerators: 64 trajectories per step for 145 steps (Miles,
+14.7 pts on a weak 30B-A3B), and 2 H100 train nodes + 6 inference nodes for 1–2 days (Tmax, +9.1 pts TB 2.1 on a 9B).
LoRA matches full fine-tuning for policy-gradient RL down to rank 1 on math, and LoRA RL has been run on a 1T MoE on
64 H800s (self-reported). But I found no agentic-coding LoRA RL result with published benchmark gains on a large MoE,
and no multi-turn coding RL on consumer GPUs.

### Cited Findings
**Small-batch, few-node agentic RL**
- Miles on MI355X: one 8-GPU inference node and one 8-GPU training node; batch 8 tasks × 8 attempts = 64 trajectories; 145 steps with three restarts; 12.8 → 27.5 on a 100-task SWE-V subset (4 attempts per task); step time 208 s at 384 concurrent trajectories, 850 s before and 284 s after a length cap [measured] — [LMSYS/AMD](https://www.lmsys.org/blog/2026-10-22-miles-mi355x-agentic-rl).
- Tmax: 2 H100 training nodes + 6 inference nodes, 1–2 days, 256 rollouts per step, 500 steps. The sandbox bill for a 9B run is about $3,150 on Daytona. Self-generated data (3.1k samples, Qwen3.5-9B as generator) still gave TB Lite 62.0 / TB2.1 27.3, vs 65.6 / 29.6 with the main set [measured] — [Tmax](https://arxiv.org/html/2606.23321).
- SkyRL-v0: ~300 samples gave +3.6 to +5.8 at 7–14B — [SkyRL](https://sky.cs.berkeley.edu/project/skyrl/). SkyRL-SQL: multi-turn RL on 653 samples; multi-turn reached a 60 % reward 2.8× faster in steps than single-turn and ended +16 % higher after 35 steps [secondary] — [SkyRL GitHub](https://github.com/NovaSky-AI/SkyRL), [NeurIPS 2025 abstract](https://neurips.cc/virtual/2025/128018).
- Agent Lightning: 6K samples, Qwen3.5-9B 41.8 → 56.4, hardware not stated — [release](https://github.com/microsoft/agent-lightning/releases/tag/v1.0.0).
- Non-coding agent example: OpenPipe's ART·E (Qwen2.5-14B email agent) at 96 % vs o3's 90 %, for "approximately $80" of GPU time [claimed in a talk; a blog gives conflicting numbers] — [AI Engineer talk](https://ai.engineer/talks/how-to-train-your-agent-building-reliable-agents-with-rl).
- Consumer GPU: the only coding RL on an RTX 3090 remains single-turn, at 0.6–1B (Skopin and Kotelnikov, covered in the earlier notes) — [arXiv 2605.30478](https://arxiv.org/html/2605.30478v1).

**LoRA RL**
- Thinking Machines, "LoRA Without Regret" (2025-09-29): for policy-gradient RL on MATH, GSM8K (Llama-3.1-8B) and DeepMath (Qwen3-8B-base, 8,192-token cap), LoRA "fully matches" full fine-tuning "even with ranks as low as 1". The best LoRA learning rate is ~10× full fine-tuning's. Attention-only LoRA underperforms MLP-only, in RL too. The argument: policy gradient absorbs ~O(1) bits per episode. Caveats: math only, noisy RL, and the MoE experiment was supervised, not RL [measured] — [Thinking Machines](https://thinkingmachines.ai/blog/lora/).
- A replication on Qwen3-0.6B GRPO found rank 1 leading briefly before full fine-tuning pulled ahead, and noted that all rank-1 successes it saw were on math [secondary] — [Kaitchup](https://kaitchup.substack.com/p/tiny-recursive-models-for-very-specific). TRL ships a rank-1, alpha-32, all-linear GRPO example, with LR 1e-5 for LoRA vs 1e-6 for full — [TRL docs](https://huggingface.co/docs/trl/main/en/lora_without_regret).
- LoRA RL on a 1T MoE: Mind Lab says it ran end-to-end LoRA RL on Kimi K2 with ~10 % of the GPUs that full-parameter RL needs (8 nodes × 8 H800 = 64 GPUs). It claims LoRA RL on a trillion-parameter model beats full RL on much smaller models at similar compute [claimed, reasoning tasks; the page redirected and I saw only a search summary] — [Mind Lab](https://macaron.im/mindlab/research/building-trillion-parameter-reasoning-rl-with-10-gpus). The matching talk: LoRA r = 32 on attention and expert layers, all experts on one expert-parallel shard of a layer sharing one adapter. Merged-weight refit is communication-heavy; adapter-only refit needs vLLM LoRA support and may slow inference — [PyTorch Conference slides](https://hosted-files.sched.co/pytorchconferenceeu2026/9f/1T_RL_PTC_EU26_Songlin.pdf).
- Mehta et al. trained Qwen3.5-122B-A10B with LoRA (rank 32, alpha 32) and GSPO; pure RL from base "failed entirely" without SFT first [secondary; LoRA and GSPO not in the abstract] — [blog summary](https://codex.danielvaughan.com/2026/08/10/cross-benchmark-generalization-agentic-rl-long-horizon-codex-cli-model-selection-transfer/), [arXiv 2608.00181](https://arxiv.org/abs/2608.00181).
- SkyRL reports LoRA RL on Mistral Large 4 (NVFP4, 8 GB200 nodes, 75 steps, AIME 2024 avg@8 ~64 → ~75 %) [secondary, unverified] — [OrcaRouter](https://www.orcarouter.ai/blog/mistral-large-4-day-zero-rl-recipe). SkyRL now implements the Tinker API on own GPUs — [SkyRL](https://github.com/NovaSky-AI/SkyRL).
- Tinker hosts LoRA fine-tuning and RL for Kimi K2 Thinking and Qwen3-235B-A22B; no agentic benchmark results found — [Tinker GA](https://thinkingmachines.ai/blog/tinker-general-availability/).

**MoE + LoRA issues**
- Router instability: R3 replays inference routing during training — [R3](https://arxiv.org/abs/2510.11370). RSPO reweights tokens by router shift on Qwen3-30B-A3B — [arXiv 2510.23027](https://arxiv.org/html/2510.23027v2). About 10 % of activated experts changed per gradient step for Qwen3-30B-A3B-Base under GRPO, a figure from Qwen's GSPO work [secondary; I did not open the GSPO paper] — [36kr](https://eu.36kr.com/en/p/3412585515552135), [GSPO, arXiv 2507.18071](https://arxiv.org/abs/2507.18071).
- Unsloth advises against MoE QLoRA and keeps router fine-tuning off by default (from the earlier project notes) — [Unsloth Qwen3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune).

### Inferences
- Batch sizes that produced measured agentic gains: 64 trajectories per step (Miles), 256 (Tmax), 512 (DeepSWE), and for Golubev 1,000–3,000 rollouts per iteration (100–300 problems × 10), split into optimiser batches of 128–256 (my arithmetic). Group sizes: 8 (Miles, DeepSWE, SA-SWE, Meta), 10 (Golubev, Kimi-Dev), 12 (FireFlash), 32 (Tmax, GLM-5 reasoning). Gains appeared from ~125–150 steps (SA-SWE, Miles, Meta).
- A 552B MoE in BF16 is ~1.1 TB of weights (552B × 2 bytes) and ~0.55 TB in FP8 (my arithmetic), so even LoRA RL needs at least ~14 80-GB GPUs just to hold BF16 weights, before KV cache, activations and a separate rollout copy. Mind Lab's 64 H800s for a 1T model is the nearest precedent, scaled by ~0.53 for parameter count (my arithmetic). Consumer GPUs are out of reach for the teacher. They are a fit only for the student.
- Rank-1 evidence is from math with ~1 bit per episode. Agentic episodes with tool feedback also give a scalar reward, so the capacity argument transfers in principle. But nobody has shown rank-1 or rank-32 LoRA matching full RL on a multi-turn coding benchmark.
- For a MoE teacher under LoRA RL: freeze the router (or replay routing), put adapters on the experts and not only on attention, and treat adapter-only refit to the rollout engine as a numerics risk to test.

### Gaps
- No published LoRA RL on a large MoE with agentic-coding benchmark gains. Mehta's run is the closest (122B-A10B, MCP tasks), and its LoRA detail is secondary.
- No multi-turn coding RL on consumer GPUs. The smallest published agentic runs use 16 datacentre accelerators.
- Mind Lab's numbers could not be read from the primary page.

## Q6. Language- or domain-specific agentic RL: does it move general benchmarks?

### Takeaway
I found no published RL run targeted at one programming language or framework that reports general benchmarks. The
nearest evidence is about transfer between task domains. RL on non-coding long-horizon tool tasks moved SWE-Bench Pro
by +5.8. Terminal RL moved SWE-V by +9.1 and transferred across harnesses. SWE-only RL moved other agent benchmarks by
only +1 to +2.5. Specialising by repository or organisation exists, but with no published RL numbers.

### Cited Findings
- Domain transfer: Mehta et al. trained on 363 non-SWE MCP tasks and gained +5.8 SWE-Pro, +2.8 TB2 — [arXiv 2608.00181](https://arxiv.org/abs/2608.00181). Tmax-9B's terminal RL took its harness's SWE-V from 46.2 → 55.3 and AIME from 72.2 → 93.3 [measured; the earlier project note read 73.3 → 91.1 from the same paper, so the AIME pair is uncertain] — [Tmax](https://arxiv.org/html/2606.23321). SA-SWE-32B's SWE-only RL added +2.5 TB, +1.3 BrowseComp-Plus — [SkyRL-Agent](https://arxiv.org/html/2511.16108v1).
- Multilingual task supply exists: GLM-5 trains on >10k SWE environments across 9 languages — [GLM-5](https://arxiv.org/html/2602.15763v2). Multi-SWE-RL releases 4,723 instances from 76 repos in 7 languages without manual checks — [Multi-SWE-bench](https://arxiv.org/abs/2504.02605). Neither reports per-language RL ablations.
- Specialisation by repo or organisation: Self-play SWE-RL ran a repository-specialised experiment on 23 repo images (numbers not in the text I read) — [SSR](https://arxiv.org/html/2512.18552v1). Cursor is "exploring" tailoring Composer to organisations or kinds of work with different coding patterns [claimed] — [Cursor](https://cursor.com/en/blog/real-time-rl-for-composer). Repo specialisation is documented for SFT, not RL (SWE-smith, in the earlier notes).
- Single-language difficulty: Rust-SWE-bench (500 tasks, 34 repos) has a best agent at 28.6 %, with repository structure and Rust's type and trait rules named as the main obstacles. It is an evaluation, not an RL run — [ICSE 2026](https://conf.researchr.org/details/icse-2026/icse-2026-research-track/67/Evaluating-and-Improving-Automated-Repository-Level-Rust-Issue-Resolution-with-LLM-ba).

### Inferences
- The transfer evidence is asymmetric. Long-horizon tool and terminal RL transferred to SWE tasks better than SWE-only RL transferred outward. One explanation is that general loop skills (persistence, tool discipline) carry over, while repository knowledge does not. This is a guess from three papers with different bases.
- For one language (Elixir is this project's case), the expected pattern from Q3 is a sizeable in-distribution gain with small general movement. That would suit a teacher whose only job is to produce Elixir trajectories, as long as general regressions are checked.

### Gaps
- No RL paper targeting one language (Rust, Java, Elixir, Kotlin, Lean-as-code) that reports both in-language and general benchmarks.
- Self-play SWE-RL's repo-specialisation numbers and Cursor's org-tailoring results are not public in the text read.
