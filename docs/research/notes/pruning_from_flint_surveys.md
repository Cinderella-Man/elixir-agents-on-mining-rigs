# Pruning heads, experts and layers: findings from the Flint speed surveys (2026-10-22/23)

Three sections from two surveys of ways to make Flint decode faster on the P106 rig. They live here, beside the other
work on making models smaller:
- 3.11 and 3.12 from [survey C, trained changes](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/research/notes/quant_speed_c_retraining.md);
- 3.7 from [survey A, file-only changes](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/research/notes/quant_speed_a_file_only.md).

Their conventions and the rig time model are in those surveys.

### 3.11 Attention head pruning, fewer query heads, low-rank q/o

#### Takeaway
- q and o projections are a third of Flint's active parameters.
- Halving the query heads (32 → 16, keeping 4 KV heads) or factoring q/o to rank ~512–683 saves ~411–514 M parameters per token: +9–12 % at Q4_1 (my calc). Low-rank gains less because it adds 2 launches per layer.
- Recovering quality needs distillation budgets of tens of billions of tokens. Not feasible on our hardware; not recommended.

#### Cited findings
- Minitron's width pruning (heads, MLP and embedding channels) needed ~94 B tokens with a corrected teacher ([arXiv 2408.11796](https://arxiv.org/abs/2408.11796), P).
- No post-hoc query-head-reduction result for a sliding-window/sink model was found.

#### Inferences
**My calc:**
- 32 → 16 heads: q and o shrink to 2048 × 2048 → −4.19 M × 2 × 49 = −411 M parameters → −257 MB at Q4_1 → −3.8 ms → **+11–12 %**.
- With Q8_0 attention (UD-mirror): −436 MB → +15–17 %.
- Rank 683: same parameter saving, but +98 launches (+0.6 ms) → **+9–10 %**.
- Rank 512: −514 M parameters → −321 MB → +12 %.
- KV cache is unchanged (still 4 KV heads), so there is no long-context gain.

#### Gaps
- No published post-hoc result for this kind of model.

#### Experiment ideas
None recommended. If wanted: rank-sweep the SVD energy of `q_proj`/`o_proj` per layer (minutes on the PC). If 683 singular values hold < 95 % of the energy, drop the idea.

**Carries over to Qwen3.6?** Less to gain: only 10 attention layers; the GDN projections dominate.

---

### 3.12 Expert pruning (REAP and similar)

#### Takeaway
- Pruning 25–50 % of experts shrinks the file. It does not change bytes per token: still 6 experts per token, and card count does not change speed on this rig.
- So: no decode speed-up.
- Use it only to fit Flint on fewer cards or to free VRAM for KV and slots. It has a measurable quality cost.

#### Cited findings
- REAP ([arXiv 2510.13999](https://arxiv.org/abs/2510.13999), ICLR 2026, P; [repo](https://github.com/CerebrasResearch/reap); [Cerebras blog](https://www.cerebras.ai/blog/reap), S).
  - Router-weighted expert-activation pruning, one-shot, no healing.
  - 50 % pruning of Qwen3-Coder-480B kept 97.6 % of non-agentic coding and 96.7 % of SWE-Bench.
  - [cerebras/Qwen3-Coder-REAP-25B-A3B](https://huggingface.co/cerebras/Qwen3-Coder-REAP-25B-A3B) (20 % pruned) shows mixed ±2-point changes.
- Expert merging and pruning are covered in `models_large_moe_and_compression.md`.

#### Inferences
- **Speed: 0 %** (my calc).
- **Memory:** 25 % pruning turns a 26 GB file into ~20 GB, fitting 4 cards with more KV room. 5 vs 9 cards measured the same speed.

#### Gaps
- REAP has no Flint adapter. A calibration pass needs transformers' Flint (feasible).

#### Experiment ideas
None for speed.

**Carries over to Qwen3.6?** Same: no speed gain.

---

### 3.7 Layer pruning, skipping and MoE-specific skipping

**Takeaway.**
- **Nothing here reaches +15 % speed at the quality bar.**
- **Layer pruning:** ≈ +2 % per layer, with a sharp collapse risk.
- **Expert pruning:** gives no single-stream speed at all on this rig, because bytes per token don't change.
- **Static expert reduction (6 → 4):** already measured, +9 % served at KLD 0.316 → 0.555.
- **New in Sept–Oct 2026:** k₂-normalized top-k reduction (training-free, Qwen3.6) and several expert-pruning papers.

**Cited findings**
- **Dense layer pruning without healing:**
  - SLEB ([arXiv 2402.09025](https://arxiv.org/abs/2402.09025); P): removing 10 % of blocks takes LLaMA-2-7B wikitext PPL from 5.47 to 6.95, at 1.10–1.13× speed.
  - Gromov et al. ([arXiv 2403.17887](https://arxiv.org/abs/2403.17887); P): the Qwen family collapses at about 20 % of layers removed.
  - ShortGPT ([arXiv 2403.03853](https://arxiv.org/abs/2403.03853); P): Llama2-7B −27 % of layers kept MMLU but XSum fell from 19.4 to 0.7.
- **`llama-quantize --prune-layers`** ([PR #13037](https://github.com/ggml-org/llama.cpp/pull/13037), merged 2025-06-22, checked):
  - It rewrites `block_count` but not the per-layer arrays, so the output fails to load ([issue #27976](https://github.com/ggml-org/llama.cpp/issues/27976), closed as stale 2026-10-13, checked).
  - The fix PR #28597 was closed unmerged on 2026-10-20 (helper agent).
  - Flint has per-layer arrays (`sliding_window_pattern`, `rope_pattern`, possibly `expert_feed_forward_length`), so they would need fixing with gguf-py.
- **New, k₂ normalization** ([Chen & Yao, arXiv 2609.04575](https://arxiv.org/abs/2609.04575), 2026-09-04; P): run k₁ experts, normalise by the top-k₂ mass. Qwen3.6-35B-A3B 8 → 4 experts costs −0.35 MMLU instead of −4.65. Softmax routers only.
- **ACE** ([arXiv 2609.05228](https://arxiv.org/abs/2609.05228); P) is calibration-free slot skipping but needs runtime logic.
- **New expert pruning:**
  - RAZOR ([2609.30465](https://arxiv.org/abs/2609.30465), 2026-09-24): beats REAP by 2.1–5.6 points on Qwen3.6-35B-A3B at 25–50 %.
  - HOPE ([2609.18916](https://arxiv.org/abs/2609.18916)): second-order.
  - OMP-MoE ([2609.31631](https://arxiv.org/abs/2609.31631)): Qwen3-30B-A3B at 50 % keeps 93.3 %.
  - OptEP ([2610.27123](https://arxiv.org/abs/2610.27123), 2026-10-19).
  - All P, via the helper agent.
- **Measured on the rig** (`docs/benchmarks/2026-10-22-flint.md`): 6 → 5 experts +4 % served (KLD 0.379), 6 → 4 +9 % (KLD 0.555).
- **Not found:** any shared-expert-skipping measurement, any whole-layer pruning of a Qwen3-MoE or Qwen3.6 model, or any Flint data.

**Inferences (my calc)**
- **One MoE layer** costs ≈ 44.6 M params per token (0.55 ms at UD-mirror's mix) plus ~40 launches (0.2–0.28 ms), so ≈ 0.8 ms (≈ 2 %). The +15 % bar needs ~7 layers (14 %), where the literature shows large losses.
- **Skipping the shared expert in all layers** saves ≈ 5.3 ms (12 %), almost certainly catastrophically. Per-layer skipping needs a patch and a sensitivity scan; expected gain per layer is 0.11 ms.
- **For Flint's sigmoid router with weight normalization,** the k₂ trick is: keep the top k₁ experts, with weights s_i / Σ_{top-k₂} s_j. A ~10-line change in `build_moe_ffn`: take the top-6, sum their weights, then view the first k₁. Worth a 1-hour CPU KLD test, because it could make 6 → 5 nearly free. The speed gain stays ≤ 9 %, so it only stacks.
- **Expert caching** (`--moe-cache-mib`) serves experts kept in host RAM. With every expert resident in VRAM, as here, it has nothing to do.

**Experiment idea (low priority) — A12.**
- Patch `build_moe_ffn` with an env switch `MOE_K1=5` (select top-6, normalise over all 6, keep the first 5 slots).
- CPU KLD with the Q8_0 file: k₁ ∈ {5, 4} against the standard override (`expert_used_count=5/4`), ≈ 15 min per run.
- If 6 → 5 costs < 0.01 KLD, add it to the stack: +4 % served.

