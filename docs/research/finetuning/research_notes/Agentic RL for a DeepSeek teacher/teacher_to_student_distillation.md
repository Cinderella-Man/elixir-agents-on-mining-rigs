# Teacher→student distillation for agentic coding (state of the evidence, 2026-11-03)

Scope: what the literature says about using a big open-weight teacher (here a DeepSeek-V4.1-class MoE with a tokenizer
different from Qwen-family students) to make 9B-class and 30B-A3B-class students better at agentic coding, and whether
improving the teacher first pays. It builds on, and does not repeat, the project's earlier notes on trajectory SFT
(SWE-Gym, R2E-Gym, SWE-smith, OpenSWE, Tmax, MiMo distill) and small-vs-big evidence.

Tags on each finding: **[M]** a number I read in the cited paper, card or post (table or text); **[C]** a claim by the
authors that I read only at abstract or summary level, with no number I could check; **[S]** a secondary source or a
search-engine summary, not read in the original. Everything under "Inferences" is my reasoning, not a source. Sums,
ratios and differences I computed are marked "(my arithmetic)".

## Q1. Teacher strength vs student gain: does a stronger, or RL-improved, teacher give a better student?

### Takeaway
A stronger teacher helps only when the student is large enough and "close" enough to it. In the one controlled
agentic-coding comparison found (SERA), the stronger GLM-4.6 teacher gave a Qwen3-32B student +2.9 points on SWE-bench
Verified and an 8B student nothing (31.7 vs 31.7). Outside agentic work, benchmark-stronger teachers often produce worse
training data (OpenThoughts: QwQ-32B beat DeepSeek-R1 as a teacher), and students below ~3–7B lose from strong teachers
and long traces. RL-trained teachers are reported to be easier to distil from than SFT-trained teachers at equal score
(Train4Merge, abstract level). No study compares the same teacher's agentic data before and after RL for an SFT student.

### Cited Findings
**Agentic / code, teacher swapped with the student held fixed**
- SERA (Ai2, arXiv 2601.20789, Jan 2026), Table 1: Qwen3-32B trained on GLM-4.6 trajectories scored 49.5 ± 1.9 % on
  SWE-bench Verified at 32K context (54.2 % at 64K), against 46.6 ± 0.7 % (51.7 %) with GLM-4.5-Air trajectories. The
  8B student scored 31.7 ± 0.9 % (GLM-4.6) and 31.7 ± 0.4 % (GLM-4.5-Air): no gain from the stronger teacher at 8B.
  **[M]** — [SERA](https://arxiv.org/abs/2601.20789)
- SERA, Figure 3: GLM-4.5-Air "matches GLM-4.6 at low and intermediate sample sizes, then saturates"; the curves cross,
  so the stronger teacher's advantage appears only with more data. **[C]** (figure values not in the text) —
  [SERA](https://arxiv.org/html/2601.20789v2)
- SERA, Appendix B: GLM-4.5-Air is called a "much better teacher" than Claude 3.7 Sonnet despite similar SWE-bench
  scores (38.47 % with 4,933 samples on Qwen3-32B vs SWE-smith's 32.60 % with 6,402 samples on Qwen2.5-32B), but the
  students and sample sizes differ, so the teacher effect is not isolated. In Table 2, with the teacher held fixed (Claude
  3.7, 4,776 samples), SERA's pipeline gave 30.00 % vs SWE-smith's 25.27 %, so pipeline effects are as large as teacher
  effects. **[M]** — [SERA](https://arxiv.org/html/2601.20789v2)
- CLI-Universe (arXiv 2606.22883, June 2026): 6k trajectories each from Kimi-K2.6 or DeepSeek-V4-Pro distilled into
  Qwen3-32B gave 33.4 vs 31.2 on Terminal-Bench 2.0; the authors conclude the pipeline does not need a specific frontier
  teacher. A DeepSeek-V4-family teacher therefore worked for a Qwen student through plain trajectory SFT. **[M]** —
  [CLI-Universe](https://arxiv.org/html/2606.22883)
- SWE-TRACE mixed a closed frontier teacher (cleaner long-horizon decomposition) with an open one (mainly MiniMax 2.5,
  broader rollout coverage), with no isolating ablation. **[S]** — [SWE-TRACE](https://arxiv.org/html/2604.14820v1)

**Reasoning / general, teacher swapped with the student held fixed**
- OpenThoughts (arXiv 2506.04178), Table 8, student Qwen2.5-7B-Instruct: QwQ-32B as teacher gave 44.2 (code data) and
  44.2 (math data) average, DeepSeek-R1 42.3 / 41.6, Phi-4-reasoning-plus 29.0 / 30.6, although DeepSeek-R1 beats QwQ-32B
  by 9 % on CodeElo, 8 % on GPQA Diamond and 23 % on JEEBench. Authors: "Models with better performance are not
  necessarily better teachers". **[M]** — [OpenThoughts](https://arxiv.org/html/2506.04178)
- "Small Models Struggle to Learn from Strong Reasoners" (arXiv 2502.12143), large-vs-small teacher gap
  (P_Large − P_Small, average of five math benchmarks): Qwen2.5 students 0.5B −3.5, 1.5B −0.8, 3B +0.3, 7B +6.6, 14B +3.0,
  32B +6.5; Llama 1B −1.9, 3B +1.6, 8B +0.5, 70B +4.3. Long-vs-short CoT gap: Qwen 0.5B −4.7, 1.5B −7.1, 3B −3.1,
  7B +1.7, 14B +4.9, 32B +13.7. Teachers: Qwen2.5-72B vs 3B-Instruct, Llama3.1-70B vs 8B, Gemma2-27B vs 9B (large/small);
  QwQ-32B-Preview vs Qwen2.5-32B-Instruct (long/short). **[M]** — [Li et al.](https://arxiv.org/html/2502.12143v3)
- Same paper, Mix Distillation on Qwen2.5-3B (MATH 7.5k): long CoT 40.3, short 43.4, strong-teacher 39.7, weak-teacher
  39.4, Mix-Long (1:4 long:short) 45.9, Mix-Large (1:4 strong:weak) 45.8. **[M]** — [Li et al.](https://arxiv.org/html/2502.12143v3)
- Hugging Face TRL distillation post (Apr 2026), Qwen3-4B student, on-policy: the Qwen3-235B-A22B teacher scored about
  10 points above the Qwen3-30B-A3B teacher on AIME25, yet "the students ended up at similar levels"; with the 235B
  teacher, GPQA Diamond fell about 10 % after step 40, which the authors suspect is a capacity gap. **[M]** (blog) —
  [HF TRL](https://huggingfacetb-trl-distillation-trainer.hf.space/)
- MOPD (Xiaomi, arXiv 2606.30406, June 2026; used in MiMo-V2-Flash post-training): per a secondary write-up, a same-origin
  teacher starts at per-token KL ≈ 0.04 to the student; swapping in a stronger external Qwen3-235B-A22B raises it to
  ≈ 0.19, entropy collapses (0.30 → 0.21) and accuracy degrades, and the top-k loss diverges around step 18. **[S]** —
  [vessl.ai summary](https://vessl.ai/en/blog/on-policy-distillation-part-1); abstract: [MOPD](https://arxiv.org/abs/2606.30406)
- "Rethinking On-Policy Distillation" (arXiv 2604.13016): OPD succeeds only if teacher and student share compatible
  thinking patterns and the teacher offers capability the student has not seen; "a higher-scoring teacher alone is not
  sufficient". **[C]** — [Li et al. 2026](https://arxiv.org/abs/2604.13016)
- "Unmasking On-Policy Distillation" (arXiv 2605.10889): the best configuration "depends jointly on the student model's
  capacity and the target task"; teacher guidance is noisy where the student already does well. **[C]** —
  [Armandpour et al.](https://arxiv.org/abs/2605.10889)
- "Every Coin Has Two Sides" (arXiv 2608.16647): same-origin teacher–student pairs transfer broadly (across languages,
  horizons, domains); cross-origin pairs mostly fit the trained distribution. **[C]** — [Li et al. 2026b](https://arxiv.org/abs/2608.16647)
- Distillation Scaling Laws (Apple, arXiv 2502.08606, ICML 2025): distillation beats supervised training when a teacher
  already exists or many students share it; if the teacher must be trained for a single student, supervised training is
  generally preferable. **[C]** — [Busbridge et al.](https://arxiv.org/abs/2502.08606)

**RL-improved teacher vs non-RL teacher**
- Train4Merge (arXiv 2609.32303, Sep–Oct 2026): with teachers and students sharing a Qwen3.5-9B initialization and
  teachers compared at similar task performance, RL-trained teachers "yield stronger students and higher recovery of
  teacher performance gains across all three domains" (agentic, reasoning, perception) under OPD; RL teachers drift less
  from the shared initialization and keep higher top-K overlap with the student. No numbers on the abstract page. **[C]**
  — [Train4Merge](https://arxiv.org/abs/2609.32303)
- Thinking Machines (Oct 2025): distilling an RL-trained teacher back into the pre-RL model on-policy matched the RL
  policy in 7–10× fewer gradient steps, about 50–100× less compute (AIME recovered in under 10 steps vs ~70 for RL).
  **[M]** — [Thinking Machines](https://thinkingmachines.ai/blog/on-policy-distillation/)

### Inferences
- For a 9B student, "make the teacher dramatically better" is unlikely to buy much imitation quality by itself: SERA's
  8B gained 0.0 from a clearly stronger teacher, and the HF 4B student gained nothing from a teacher 10 AIME points
  stronger. The teacher's improvement pays mainly through (a) yield: more tasks verified per teacher-hour, (b) coverage
  of hard tasks that the weaker teacher cannot solve at all, and (c) the 30B-class student, which in SERA kept improving
  with the stronger teacher's data.
- DeepSeek → Qwen is a cross-origin pair (different pre-training, tokenizer and chat/thinking format). The OPD papers
  above say distance hurts; for SFT, OpenThoughts' result that a Qwen-family teacher (QwQ) beat DeepSeek-R1 for a Qwen
  student fits the same pattern, though OpenThoughts does not attribute it to family. A Qwen-family teacher (for example
  a larger Qwen3.5/Ornith model) may be a better *distiller* for Qwen students even if DeepSeek is the better *solver*;
  the two roles can be split (DeepSeek finds solutions, a same-family model or the student itself re-expresses them).
- Train4Merge suggests that if the teacher is improved, RL is the better way to do it than SFT, but its evidence is
  same-initialization OPD, which does not apply directly to a cross-family SFT pipeline.

### Gaps
- No controlled agentic-coding study that trains the same student on the same teacher's trajectories before and after
  that teacher's RL. Train4Merge is closest but is OPD with a shared initialization, and its numbers were not readable.
- SERA's 8B result is a single endpoint; I could not find how much data the 8B students used or their scaling curve.
- MOPD's teacher-swap numbers come from a secondary write-up; the paper's own tables were not read.

## Q2. RL the teacher then distil, or RL the student directly?

### Takeaway
In every head-to-head found, distilling a stronger RL-trained model into a small one beat RL on the small model, at a
fraction of the compute: DeepSeek-R1 72.6 vs 47.0 AIME on Qwen-32B, Qwen3-8B 74.4 vs 67.6 AIME'24 at about a tenth of
the GPU hours, SERA's SFT about 26× cheaper than RL for equal SWE-bench Verified. Distillation is capped by the teacher,
though. Where the teacher is weak (a niche language), RL with a verifier on the student beat distillation outright. The
consistent recipe is distil first, then RL the student. Spending on the teacher pays when many students or many sessions
share it.

### Cited Findings
- DeepSeek-R1 (arXiv 2501.12948), Table 6: QwQ-32B-Preview 50.0 AIME'24 pass@1 / 90.6 MATH-500 / 54.5 GPQA-D / 41.9 LCB;
  DeepSeek-R1-Zero-Qwen-32B (RL on Qwen-32B-Base for over 10K steps) 47.0 / 91.6 / 55.0 / 40.2; DeepSeek-R1-Distill-
  Qwen-32B (SFT on 800k R1-curated samples) 72.6 / 94.3 / 62.1 / 57.2. Conclusions: distillation "yields excellent
  results", while going beyond current limits "may still require more powerful base models and larger-scale RL". The
  distilled models got SFT only; the authors note RL on them gives "significant further gains" but did not report it.
  **[M]** — [DeepSeek-R1](https://arxiv.org/html/2501.12948v1). Difference: +25.6 AIME points for distillation over RL
  (my arithmetic).
- Qwen3 (arXiv 2505.09388), Section 4.5 "Strong-to-Weak Distillation": students 0.6B–14B dense and 30B-A3B; teachers
  Qwen3-32B or Qwen3-235B-A22B; an off-policy phase (SFT on teacher outputs in /think and /no_think) then an on-policy
  phase (student samples, logits aligned to the teacher by KL). Table 21, Qwen3-8B from the same off-policy checkpoint:
  off-policy 55.0 AIME'24 / 42.8 AIME'25 / 42.0 LCB v5; +RL 67.6 / 55.5 / 52.9 at 17,920 GPU hours; +on-policy
  distillation 74.4 / 65.5 / 60.3 at 1,800 GPU hours. Pass@64 rose with distillation (90.0 → 93.3 AIME'24) and stayed
  flat with RL. **[M]** — [Qwen3](https://arxiv.org/html/2505.09388). Ratio ≈ 10× fewer GPU hours (my arithmetic).
- Thinking Machines (Kevin Lu et al., 27 Oct 2025), Qwen3-8B-Base student: off-policy SFT on 400k OpenThoughts-3 prompts
  (QwQ-32B traces) reached 60 % AIME'24; on-policy distillation from that checkpoint reached 70 % in ~150 steps (~77K
  prompts × 4 samples); SFT is extrapolated to need ~2M prompts for 70 %. FLOPs: on-policy distillation 8.4e19 (teacher)
  + 8.2e19 (student) vs 3.4e21 + 1.5e21 for SFT-2M, a 9–30× cost reduction; RL reached ~68 % at about SFT-2M's cost.
  LoRA rank 32 trailed full fine-tuning by 13 % after SFT and 6 % after on-policy distillation. **[M]** —
  [Thinking Machines](https://thinkingmachines.ai/blog/on-policy-distillation/)
- SERA: SFT on soft-verified GLM trajectories is "26× cheaper than RL" (SkyRL) and "57× cheaper" than SWE-smith-style
  data to reach equal SWE-bench Verified; SERA-32B cost about 40 GPU-days (~$2,000) for data and training. **[C]** (cost
  figures from the paper's own accounting) — [SERA](https://arxiv.org/abs/2601.20789)
- MOPD (secondary summary): OPD reached teacher-level SWE performance in about 30K SWE samples, against the full
  150–180K budget for Mix-RL. **[S]** — [vessl.ai](https://vessl.ai/en/blog/on-policy-distillation-part-1)
- Agnostics (arXiv 2508.04865), Fortran: a Sonnet 4 Thinking teacher solved 12 Ag-LCB-Fortran problems; Qwen3-4B SFT on
  its 1,987 synthesized solutions scored 3, 3 and 2 after 1–3 epochs; the RL-trained Qwen3-4B-CF-X scored 15. On OCaml,
  RL'd Qwen3-4B/8B scored 7/7 vs Sonnet 4's 6. **[M]** — [Agnostics](https://arxiv.org/html/2508.04865)
- CodeV-R1 (Verilog, arXiv 2505.24183): DeepSeek-R1-generated ~87K examples distilled into Qwen2.5-Coder-7B gave 56.2 %
  on RTLLM v1.1; adaptive DAPO RL on ~3.1K filtered problems then gave 72.9 %, which the authors say beats the 671B
  DeepSeek-R1 by 8.1 points. The distilled-only model stays below the teacher. **[S]** (search summary of the paper and
  model card) — [CodeV-R1](https://arxiv.org/abs/2505.24183), [model card](https://huggingface.co/zhuyaoyu/CodeV-R1-Distill-Qwen-7B)
- Distillation Scaling Laws: if a teacher must be trained just to produce one student, supervised learning is generally
  preferable; distillation wins when the teacher exists or is shared by many students. **[C]** —
  [Busbridge et al.](https://arxiv.org/abs/2502.08606)

### Inferences
- The owner's plan, RL the teacher and then distil, matches the pattern the labs use (R1, Qwen3, MiMo's MOPD), where one
  expensive RL'd teacher serves a family of students. It is justified to the extent that the improved teacher is reused:
  for several students (9B, 35B-A3B, future bases) and for many sessions. If only one 9B student is ever trained, RL on
  the student (with distilled warm-start) may be the cheaper route by the scaling-law argument.
- The teacher improvement most worth paying for is the one the student cannot get any other way: solving Elixir tasks the
  base teacher fails. Agnostics and CodeV-R1 show that the student's distilled ceiling sits below the teacher in a
  language where the teacher is weak, while RL with a verifier pushed past it.
- Final RL on the student is still worth planning: every pipeline that beat its teacher (CodeV-R1, Agnostics) did it in
  an RL stage after distillation, and R1's authors report further gains from RL on distilled models.

### Gaps
- No agentic-coding head-to-head of "RL the 9B directly" vs "distil from an RL'd big teacher" at matched compute. SERA's
  26× is a cost-to-equal-score claim against one RL baseline, not a matched study.
- No source estimates the compute to RL a 500B-class MoE teacher on agentic tasks relative to RL on a 9B student.

## Q3. On-policy distillation, and does it work across tokenizers (DeepSeek → Qwen)?

### Takeaway
On-policy distillation (the student samples, the teacher scores every token with reverse KL) is the strongest
post-SFT method measured: it beat RL in Qwen3 and Thinking Machines at 10–30× less compute. It needs teacher log-probs
on the student's tokens, which is natural only with a shared tokenizer. Cross-tokenizer variants exist (ULD, GOLD, BPM,
CompassOPD), but they lose part of the gain as vocabularies diverge (GOLD recovered 60 % of the teacher on Qwen → Llama
against 80–90 % same-tokenizer). None has been shown on multi-turn tool use, and multi-turn OPD has its own failure mode:
student errors compound. For a DeepSeek teacher and Qwen students, sequence-level trajectory SFT is the practical route
today. Same-family OPD or self-distillation can follow as a second stage.

### Cited Findings
**Method lineage**
- GKD (Agarwal et al., arXiv 2306.13649, ICLR 2024): train the student on its own sequences with teacher feedback and
  flexible divergences. **[C]** — [GKD](https://arxiv.org/abs/2306.13649)
- MiniLLM (Gu et al., arXiv 2306.08543, ICLR 2024): reverse KL optimized on-policy, 120M–13B models. **[C]** —
  [MiniLLM](https://arxiv.org/abs/2306.08543)
- Thinking Machines: per-token reverse KL(π_student‖π_teacher) used as a negative advantage in the RL importance-sampling
  loss, discount 0; called "unhackable" and mode-seeking. The teacher needs a single forward pass over the student's
  sampled tokens; log-prob computation parallelizes cheaply and FLOP counts overstate its practical cost. The post does
  not discuss tokenizers. **[M]** — [Thinking Machines](https://thinkingmachines.ai/blog/on-policy-distillation/)
- Thinking Machines, personalization: Qwen3-8B midtrained on internal documents (70 % documents, 30 % chat) went 18 → 36 %
  on internal QA while IF-eval fell 85 → 79 %; on-policy distillation from the original model restored IF-eval to 83 %
  with QA at 41 %. SFT on the model's own samples at temperature 1.0 degraded IF-eval at every learning rate tried.
  **[M]** — [Thinking Machines](https://thinkingmachines.ai/blog/on-policy-distillation/)
- Qwen3 and MiMo use same-family teachers for on-policy distillation: Qwen3-32B/235B → smaller Qwen3 [M]
  ([Qwen3](https://arxiv.org/html/2505.09388)); MOPD, multi-teacher OPD deployed in MiMo-V2-Flash, on Qwen3-30B-A3B,
  beating Mix-RL, Cascade RL, off-policy fine-tuning and parameter merging **[C]** ([MOPD](https://arxiv.org/abs/2606.30406)).

**Cross-tokenizer**
- GOLD (Hugging Face, 29 Oct 2025; June 2026 update to UTF-8 byte-offset alignment) extends Universal Logit Distillation
  (ULD, offline-only) to on-policy training with sequence alignment (grouping tokens with the same visible text) and
  log-prob merging. Countdown task: same-tokenizer Qwen3-4B-Instruct → Qwen2.5-1.5B reached 0.6515 (teacher 0.7145),
  recovering over 80 % of the teacher across teacher sizes; cross-tokenizer Qwen3-4B → Llama-3.2-1B: GOLD +25 % over the
  student's start and 60 % teacher recovery, against ULD's +5 % and 10 %. Student score tracked tokenizer similarity:
  Qwen2.5 0.6515 (similarity 0.99997), Llama 0.4235 (0.64), Gemma-3-1b 0.0305 (0.063). Gains appeared only after about
  step 1,000 in the Llama run; experiments are one math task plus one domain case; "student performance is capped by the
  teacher". No multi-turn or tool-use runs. **[M]** — [GOLD post](https://huggingfaceh4-on-policy-distillation.hf.space/)
- GOLD in TRL lives under `trl.experimental.gold` (GOLDConfig, GOLDTrainer); `use_uld_loss=True` plus
  `teacher_tokenizer_name_or_path` enable cross-tokenizer training. **[S]** — [TRL docs](https://huggingface.co/docs/trl/gold_trainer)
- Byte-Prefix Marginalization (arXiv 2607.22334, July 2026): maps the teacher's next-token distribution onto the student's
  vocabulary in byte space (exact on > 99 % of positions, a lower bound elsewhere); teachers Qwen3-32B, GLM-Z1-9B-0414 and
  MiniMax-M2.7; +3.7 to +6.6 points six-benchmark avg@8 (math and programming) over the strongest cross-tokenizer
  baselines. No agentic experiments. **[C]** — [BPM](https://arxiv.org/abs/2607.22334)
- CompassOPD (arXiv 2609.10154, Sep 2026, work in progress): cross-family OPD "weakens ... even after tokenizer
  alignment"; transferring only the teacher family's within-family likelihood shift gives up to +5.50 points average
  reasoning accuracy over standard cross-family OPD. For an MoE teacher the low-capability reference is built from the
  teacher itself by reducing expert activation (+3.43 over OPD). No agentic experiments. **[C]** —
  [CompassOPD](https://arxiv.org/abs/2609.10154)
- "Revisiting On-Policy Distillation: Empirical Failure Modes and Simple Fixes" (arXiv 2603.25562) is listed as handling
  tokenizer mismatch with truncated reverse KL and top-K support matching. **[S]** (list entry, not read) —
  [awesome-on-policy-distillation](https://github.com/chrisliu298/awesome-on-policy-distillation)

**Agentic, multi-turn OPD (same tokenizer)**
- FutureBridge-OPD (arXiv 2608.01953, Aug 2026): Qwen3-32B → Qwen3-1.7B on ALFWorld, WebShop and ScienceWorld; "student
  deviations may accumulate over time"; validating teacher bridges by the student's continuation beats vanilla OPD by
  16.6 points on average. **[C]** — [FTB](https://arxiv.org/abs/2608.01953)
- SOD (arXiv 2605.07725, May–Aug 2026): "erroneous tool calls tend to cascade across subsequent reasoning steps",
  inflating student–teacher divergence; step-wise reweighting gives up to +20.86 % over the next-best baseline; a 0.6B
  student reaches 26.13 % on AIME 2025. **[C]** — [SOD](https://arxiv.org/abs/2605.07725)
- SCoRe (arXiv 2509.14257, ICML 2026): the student rolls out, a 72B teacher corrects only the earliest error, the student
  is fine-tuned on the corrected trajectories, then short-horizon RL runs from the verified prefix; a 7B student "closes
  the agentic performance gap" with the 72B teacher on 12 benchmarks. **[C]** — [SCoRe](https://arxiv.org/abs/2509.14257)
- A student-centred distillation work used Qwen3-32B as on-policy teacher for Qwen3-8B because teacher and student
  "typically need to come from the same family". **[S]** — search summary of [arXiv 2509.14257](https://arxiv.org/html/2509.14257v3)

**Cost of teacher scoring vs teacher generation**
- Thinking Machines FLOP table: on-policy distillation used 8.4e19 teacher FLOPs vs 8.5e20 for generating the 400K SFT
  set and 3.4e21 for the extrapolated 2M set. **[M]** — [Thinking Machines](https://thinkingmachines.ai/blog/on-policy-distillation/)
- Hugging Face TRL (12 Apr 2026), "Distilling 100B+ models 40× faster": the teacher runs as an external vLLM server
  returning top-k log-probs; request batching cut p99 latency ~10×; binary encoding of top-k log-probs cut payload ~5×
  and latency a further 25 %; a generation buffer raised student rollout throughput from ~204 to 8,494 tok/s (41.7×,
  generation only). Same-family pairs only (Qwen3-235B-A22B → Qwen3-4B; Gemma 4 31B → E2B); no multi-turn. **[M]** —
  [HF TRL](https://huggingfacetb-trl-distillation-trainer.hf.space/)

### Inferences
- DeepSeek → Qwen OPD would stack three penalties the literature names separately: cross-tokenizer alignment noise
  (GOLD), cross-family distance (CompassOPD, Every Coin, MOPD's KL jump), and multi-turn error compounding (SOD, FTB).
  No paper tests the combination. Treat it as a research project, not a recipe.
- Three practical alternatives avoid the tokenizer problem: (1) **sequence-level trajectory SFT** from DeepSeek (works;
  CLI-Universe used a DeepSeek-V4 teacher this way); (2) after that SFT, **same-family OPD** from a larger Qwen-tokenizer
  model (e.g. a 35B-A3B Qwen-family model teaching a 9B, which share a tokenizer per the earlier project report); (3)
  **self-distillation with demonstrations in context** (Shenfeld et al.'s SDFT, Q4), where the student conditioned on a
  DeepSeek trajectory acts as its own teacher, so no foreign tokenizer is involved. Options 2 and 3 have no
  agentic-coding evidence yet.
- Scoring is cheaper than generating for a local teacher at one conversation at a time. Scoring a student rollout is one
  prefill pass over the whole trajectory, with no decode, and prefill runs far faster than decode on any engine. Agentic
  contexts are mostly tool output, though, so the teacher still prefills tens of thousands of tokens per rollout, and
  the engine must return top-k log-probs per position. OPD also needs live sandboxes for the student's rollouts, so it
  has RL's environment cost.

### Gaps
- No cross-tokenizer OPD result on any multi-turn, tool-use or SWE task; no published tokenizer-similarity figure for
  DeepSeek-V3/V4 vs Qwen3.5 vocabularies (GOLD's metric).
- No measured cost of teacher scoring vs teacher generation for agentic trajectories, and no data on OPD with a teacher
  served by a llama.cpp-class engine rather than vLLM.

## Q4. Which teacher data helps a small agentic student most?

### Takeaway
The ablations agree on four points. Keep the teacher's reasoning (SERA: 41.0 vs 23.0 without it). Do not throw away
near-misses, but mask their wrong steps instead of imitating them (SWE-Lego +1.2 from semi-resolved runs, +0.4–0.8 from
error masking; raw failures cost 5.2 points in CLI-Universe). Order or curate by length and difficulty (SWE-Lego's
curriculum +2.0–2.2). Specialized depth on one codebase beats generic breadth for that codebase (SERA). Strict
verification matters less than expected for SWE patches: SERA found soft- and unverified trajectories comparable up to
7.4k samples, and OpenThoughts found answer filtering useless. Data in the student's own distribution helps retention,
though the evidence is outside agentic coding.

### Cited Findings
**Verifier-filtered successes vs failures and recovery**
- SWE-Lego (arXiv 2601.01426), Table 5, SWE-bench Verified: all resolved 14.6k trajectories 40.4 %; minus low-quality
  resolved 14.1k 41.0 %; plus 4.0k semi-resolved (right files localized, fix failed) 18.1k 42.2 %. Figure 7 (8B / 32B):
  error masking + curriculum 42.2 / 52.6; without masking 41.8 / 51.8; without curriculum 40.2 / 50.4; without both
  39.4 / 48.8. **[M]** — [SWE-Lego](https://arxiv.org/html/2601.01426v2)
- CLI-Universe, Section 4.2.2: the 6k successful trajectories gave 33.4 on Terminal-Bench 2.0 vs 28.2 for the full 10k
  set including failures (the appendix's statement that failures are kept conflicts with the main results). **[M]** —
  [CLI-Universe](https://arxiv.org/html/2606.22883). Adding ~4k failures cost 5.2 points (my arithmetic).
- Step Rejection Fine-Tuning (JetBrains, arXiv 2605.10674): a critic LLM labels erroneous steps, their loss is masked but
  they stay in context; on SWE-bench Verified, RFT (discard unresolved) adds 2.4 % and SRFT 3.7 %, reaching 32.2 %.
  **[C]** — [SRFT](https://arxiv.org/abs/2605.10674). A JetBrains blog reportedly shows SFT on *failed* SWE-smith
  trajectories alone lifting Qwen2.5-Coder-32B from 7.0 % to 27.7 %, with ≤ 24 % of steps clearly wrong in 20 checked
  runs. **[S]** (search summary; the page returned HTTP 403) — [JetBrains Research](https://blog.jetbrains.com/research/2026/06/step-rejection-fine-tuning/)
- Terminal-World (arXiv 2605.20876) reportedly found that dropping failure trajectories hurt more than shrinking the
  dataset, and that a negative SFT loss on failures hurt further. **[S]** (search summary; not on the abstract page) —
  [Terminal-World](https://arxiv.org/abs/2605.20876)
- SERA, Section 5.1: soft-verification thresholds r = 0.0, 0.25, 0.75, 1.0 (line-level recall of the patch against the
  first rollout's patch) "perform similarly up to 7,400 samples" (Kruskal–Wallis p = .066); unverified T1 trajectories
  perform comparably. **[M]** — [SERA](https://arxiv.org/html/2601.20789v2)
- OpenThoughts, Table 7 (math): no filtering 65.6, random 64.8, shortest answers 63.7, GPT verification 61.4; "none gave
  significant performance improvements". **[M]** — [OpenThoughts](https://arxiv.org/html/2506.04178)
- CoderForge failed trajectories average 18–28 % more steps than successful ones; training used successes only (no
  ablation). **[M]** — [Together AI](https://www.together.ai/blog/coderforge-preview)

**Thinking traces vs none**
- SERA, Table 8 (Qwen3-32B, 4,200 T2 trajectories from GLM-4.5-Air): with reasoning 41.00 ± 1.31 %; tool calls only
  23.00 %. **[M]** — [SERA](https://arxiv.org/html/2601.20789v2)
- Long CoT hurts students below ~7B and helps from 7B upward (Qwen 7B +1.7, 14B +4.9, 32B +13.7; Q1). Average lengths:
  long CoT 3,384.7 tokens, short 575.7. **[M]** — [Li et al.](https://arxiv.org/html/2502.12143v3)

**Short vs long trajectories**
- SWE-Lego: turn count correlates with resolve rate at r = −0.95; a curriculum Easy (0–50 turns) → Medium (50–70) →
  Hard (70–100), each stage adding the previous data, beats a learned difficulty scorer by 0.5 and adds 2.0 (8B) and
  2.2 (32B) points. Rollouts plateau beyond ~140 turns. **[M]** — [SWE-Lego](https://arxiv.org/html/2601.01426v2)
- SERA, Table 4 (32K training window, ~24 % of trajectories longer than 32K): ordered truncation 43.00 %, keeping only
  trajectories that fit 40.60 %, random truncation 37.47 %. **[M]** — [SERA](https://arxiv.org/html/2601.20789v2)
- SWE-smith, difficulty subsets of 500 trajectories at difficulty 2/4/6/8 gave 12.4 / 10.8 / 13.6 / 12.2 % on SWE-bench
  Verified: no strong difficulty correlation. **[M]** — [SWE-smith](https://arxiv.org/html/2504.21798v2)

**Teacher-written vs student-rewritten (self-distillation)**
- Self-Distillation Fine-Tuning (Yang et al., arXiv 2402.13669): rewriting targets into the model's own distribution
  before SFT reduces forgetting; reported jailbreak-safe rate 80.77 % vs 54.81 % for vanilla SFT on GSM8K. **[S]** (number
  from a search summary) — [SDFT 2024](https://arxiv.org/abs/2402.13669)
- "I Learn Better If You Speak My Language" (arXiv 2402.11192, EMNLP 2024): fine-tuning on LLM-generated responses beats
  human responses mainly because of "familiarity" (lower pre-training perplexity), which also helps retain other skills.
  **[C]** — [Ren et al.](https://arxiv.org/abs/2402.11192)
- SDFT (Shenfeld et al., arXiv 2601.19897, 2026): one model is both student and teacher; the teacher copy sees a
  demonstration in context; the student samples and minimizes reverse KL to it (on-policy self-distillation for
  continual learning). TRL ships an SDFT trainer. **[S]** — [SDFT 2026](https://arxiv.org/pdf/2601.19897)
- On-policy data from a weak student hurt: adding 868 student trajectories to SWE-Gym's 491 dropped Lite 15.3 → 8.7 %
  (from the earlier project notes). **[M]** — [SWE-Gym](https://arxiv.org/html/2412.21139v2)

**Multiple solutions per task**
- OpenThoughts, Table 6 (science): 16 answers per question 36.2 overall vs 4× 35.8 vs 1× 35.0 (exact dedup); math best
  at 4×. **[M]** — [OpenThoughts](https://arxiv.org/html/2506.04178)
- SWE-smith caps each instance at 3 trajectories (repeatedly solved easy instances hurt). **[M]** —
  [SWE-smith](https://arxiv.org/html/2504.21798v2). CoderForge kept all passing runs: 155,144 over 51,201 tasks, ≈ 3.0
  per task (my arithmetic). **[M]** — [Together AI](https://www.together.ai/blog/coderforge-preview)

**Environment diversity vs per-task (per-repo) depth**
- SERA, Table 3: 8,000 trajectories per repo (3k soft-verified T2 + 5k filtered T1, from pools of 46–54k) gave Django
  52.23 % vs the GLM-4.5-Air teacher's 51.20 %, Sympy 51.11 vs 48.89, Sphinx 37.14 vs 43.51; pure Django data reached
  teacher level at ~8,000 samples while pure general data did not at 16,000 (Figure 4); a 4k + 4k two-repo mix averaged
  48.15. **[M]** — [SERA](https://arxiv.org/html/2601.20789v2)
- SWE-Lego: real tasks (avg 3.7 files, 138 lines) give "depth", synthetic (1.0 file, 18.8 lines) "breadth"; 5,010 valid
  real + 9,100 synthetic trajectories used together. **[M]** — [SWE-Lego](https://arxiv.org/html/2601.01426v2)
- OpenThoughts, Table 4 (code): top 2 question sources 41.3 overall vs 16 sources 36.4; "source quality matters more
  than diversity". **[M]** — [OpenThoughts](https://arxiv.org/html/2506.04178)

### Inferences
- For an Elixir pipeline: keep DeepSeek's thinking and convert it to the student's `<think>` format. Keep resolved and
  near-miss sessions and mask the steps a compiler or test run proves wrong (Elixir's `mix compile` and `mix test` are
  cheap step-level critics). Do not train on raw failures. Cap at 2–3 sessions per task. Order training by turn count.
- SERA's per-repo result is the most encouraging datum for a niche-language plan: a student matched its teacher on one
  codebase with ~8k trajectories. Elixir is a "codebase family" in this sense, but only if the teacher is good at it
  (Q7).
- The SFT-on-teacher vs self-rewrite question is open for agents. A cheap test is to have the student re-generate each
  DeepSeek turn conditioned on the teacher's turn (SDFT-style), then compare against plain SFT on held-out tasks.

### Gaps
- No agentic study compares teacher-written vs student-rewritten trajectories, and no thinking-trace ablation at 7–9B
  for agentic coding (SERA's is at 32B).
- SRFT's base score, Terminal-World's numbers and the JetBrains failed-only result could not be read in the original.

## Q5. Data-volume knees for agentic trajectory distillation into 7–14B and 30B-A3B students

### Takeaway
No hard knee has been shown for 32B-class students. SERA's curve on Qwen3-32B rises about 2.5 points per doubling from
400 to 16,000 trajectories (33.5 → 46.6 %). The R2E-Gym 14B knee near 800 trajectories in the earlier notes remains the
only small-model saturation point. 8B students sit 15–20 points lower than 32B on the same data (SERA 31.7 vs 49.5;
CLI-Universe 10.9 vs 33.4). The best 30B-A3B datum is Nebius: ~32k successful Qwen3-Coder-480B runs took
Qwen3-30B-A3B from 25.2 to 49.7 %. Nearly every large open set was written by one teacher, Qwen3-Coder-480B
(Apache-2.0). SERA's teachers are GLM-4.6 (MIT) and GLM-4.5-Air.

### Cited Findings
| Work | Student(s) | Trajectories | Teacher (licence) | Result | Tag |
|---|---|---|---|---|---|
| [SERA](https://arxiv.org/html/2601.20789v2) Table 11 | Qwen3-32B, 3 seeds | 400 / 750 / 1,500 / 3,000 / 4,200 / 7,400 / 16,000 | GLM-4.5-Air | 33.47 / 36.40 / 38.87 / 39.67 / 41.80 / 44.00 / 46.60 % SWE-bench Verified (32K); data cost $75 → $2,987 self-hosted | [M] |
| [SERA](https://arxiv.org/html/2601.20789v2) Table 9 | Qwen3-32B | 16k vs 25k T2; 16k T2 + 9k T1 | GLM-4.6 ([MIT](https://huggingface.co/zai-org/GLM-4.6)) | 47.07 / 49.53 / 49.00 %; scaling fit R² > 0.95 | [M] |
| [SERA](https://arxiv.org/abs/2601.20789) Table 1 | Qwen3-8B | not stated | GLM-4.6 / GLM-4.5-Air | 31.7 / 31.7 % | [M] |
| [Nebius](https://nebius.com/blog/posts/openhands-trajectories-with-qwen3-coder-480b) | Qwen3-30B-A3B-Instruct-2507; Qwen3-235B-A22B | 32,161 successful of 67,074 (3,792 issues, 1,823 repos); 8.9B / 5.3B tokens seen, 5 / 3 epochs, 131K context | Qwen3-Coder-480B ([Apache-2.0](https://huggingface.co/Qwen/Qwen3-Coder-480B-A35B-Instruct)) | 30B-A3B: 25.2 → 49.7 % (100 turns), 25.7 → 50.3 % (500); SWE-rebench Sept 11.8 → 28.1; 235B: 45.2 → 59.9 %; teacher 64.7 % | [M] |
| [CoderForge](https://www.together.ai/blog/coderforge-preview) | Qwen3-32B; Qwen3-4B | 155,144 passing (6.70B tokens, median 38,052 tokens per trajectory) | Qwen3-Coder-480B | 32B 59.4 % pass@1 (epoch 3.13); 4B 43.0 % (epoch 5); no scaling curve | [M] |
| [SWE-Lego](https://arxiv.org/html/2601.01426v2) | Qwen3-8B / 32B | 14.1k–18.1k | Qwen3-Coder-480B | 8B 42.2 %, 32B 52.6 % after refined SFT; 32B base 23.2 % + 25.6 from data + 3.8 refined SFT | [M] |
| [CLI-Universe](https://arxiv.org/html/2606.22883) | Qwen3-8B / 14B / 32B | 6k successful | Kimi-K2.6 (and DeepSeek-V4-Pro) | TB 2.0: 2.5 → 10.9, 4.0 → 23.0, 3.4 → 33.4; 8B "improves steadily as data scales", no saturation | [M] |
| [SWE-smith](https://arxiv.org/html/2504.21798v2) | Qwen2.5-32B | 500 → 5,016 | Claude 3.5 / 3.7 Sonnet, GPT-4o (fail the rule) | 28.2 % → 40.2 % | [M] |
| [MOPD summary](https://vessl.ai/en/blog/on-policy-distillation-part-1) | Qwen3-30B-A3B | ~30K SWE samples (OPD) | same-origin teachers | teacher-level SWE vs 150–180K samples for Mix-RL | [S] |

- SERA specialization: ~8,000 per-repo trajectories (~$1,300) match the teacher on Django. **[M]** —
  [SERA](https://arxiv.org/html/2601.20789v2)
- From the earlier project notes (not re-read here): R2E-Gym's 14B saturated near 800 samples while its 32B improved to
  3,200; OpenSWE reached 62.4 % with ~13k GLM-4.7 trajectories at 32B; MiMo-V2.6-Distill-Qwen-9B used 77.4B tokens. —
  [R2E-Gym](https://arxiv.org/html/2504.07164v1), [OpenSWE](https://arxiv.org/html/2603.13023v3)

Derived figures (my arithmetic):
- SERA 400 → 16,000 is 40× (≈ 5.3 doublings) for +13.1 points, ≈ 2.5 points per doubling. Per step: 750 → 1,500 +2.5;
  1,500 → 3,000 +0.8; 3,000 → 7,400 (≈ 1.3 doublings) +4.3; 7,400 → 16,000 (≈ 1.1 doublings) +2.6. Self-hosted data cost
  ≈ $0.19 per trajectory ($2,987 / 16,000).
- Nebius closes 62 % of the student–teacher gap at 30B-A3B ((49.7 − 25.2) / (64.7 − 25.2)) and 75 % at 235B
  ((59.9 − 45.2) / (64.7 − 45.2)). 8.9B tokens over 5 epochs ≈ 1.8B unique tokens; if all 32,161 successes were used,
  ≈ 55k tokens per trajectory (the number used is not stated). Teacher pass rate ≈ 48 % (32,161 / 67,074).
- CoderForge teacher pass rate ≈ 60 % (155,144 / 258,134); ≈ 43k tokens per passing trajectory on average (6.70B /
  155,144).

### Inferences
- If the earlier project estimate of 5–10 kept sessions per hour for a one-conversation DeepSeek teacher holds, 2,000
  sessions take ~200–400 teacher-hours and SERA's 16,000 take ~1,600–3,200 (my arithmetic). Published gains at 32B kept
  coming at 16k, so a local teacher cannot reach the volumes where open sets are measured. The natural split: general
  agentic skill from the open Qwen3-Coder-480B sets (Q6), and DeepSeek reserved for Elixir sessions, where volume needs
  are SERA-specialization-sized (thousands, not tens of thousands).
- A 9B student should be expected to plateau lower and earlier than a 30B-class one (R2E-Gym's 14B knee, SERA's flat 8B
  across teachers). Measure a learning curve at roughly 500 / 1,000 / 2,000 Elixir sessions before committing teacher
  time.

### Gaps
- No published learning curve for a 7–9B or a 30B-A3B student on agentic trajectories beyond single endpoints; SERA-8B's
  and SERA-14B's data sizes and curves were not found.
- Kimi-Dev and the Ornith training sets were not covered in this pass. The licences of Kimi-K2.6, DeepSeek-V4-Pro and
  GLM-4.5-Air were not checked here.

## Q6. Open agentic trajectory datasets from open-weight teachers that could pass a strict provenance rule

### Takeaway
Several large open sets come from an Apache-2.0 teacher (Qwen3-Coder-480B) or an MIT one (GLM-4.6), under CC-BY-4.0 or
ODC-By. The cleanest under a strict "no proprietary-model text" rule is Nebius's SWE-rebench-OpenHands-trajectories
(real GitHub issues, CC-BY-4.0). Next come NVIDIA's Nemotron-SWE-v1, whose problem statements were re-written by
Qwen3-Coder-480B, and the SWE-rebench split of CoderForge. Anything built on SWE-smith's or R2E-Gym's original task text
inherits proprietary-model involvement (o3-mini bugs, LM-written issues) unless the issue text was regenerated. All of
these sets are Python, none Elixir.

### Cited Findings
| Dataset | Size | Teacher (licence) | Task source and who wrote the prompts / tests | Data licence | Provenance verdict (strict rule) |
|---|---|---|---|---|---|
| [nebius/SWE-rebench-openhands-trajectories](https://nebius.com/blog/posts/openhands-trajectories-with-qwen3-coder-480b) | 67,074 runs, 32,161 successful; 3,792 issues, 1,823 Python repos | Qwen3-Coder-480B, OpenHands 0.54 | Real GitHub issues from SWE-rebench; who wrote tests not stated | CC-BY-4.0 (data), Apache-2.0 (models) [M] | Likely passes (issues human-written); a third party reports raw rows with empty or broken tool calls ([asaverren](https://huggingface.co/datasets/asaverren/openhands-train-ready), [S]) |
| [nvidia/Nemotron-SWE-v1](https://huggingface.co/datasets/nvidia/Nemotron-SWE-v1) | "59k" trajectories (one r2e_gym subset of 51,029; viewer ~34.8k rows) | Qwen3-Coder-480B, OpenHands | SWE-Gym and R2E-Gym-Subset; problem statements generated by Qwen3-Coder-480B; tests not stated | CC-BY-4.0, some subsets BSD-3-Clause [M] | Likely passes on text; check test origin and whether only resolved runs are included |
| [nvidia/SWE-Zero-openhands-trajectories](https://huggingface.co/datasets/nvidia/SWE-Zero-openhands-trajectories) | 318,115 runs, 118,092 issues | Qwen3-Coder-480B, OpenHands | SWE-Gym, SWE-Gym-Raw, R2E-Gym-Subset, SWE-Fixer-Train-110K, SWE-rebench; issue statements by Qwen3-Coder-480B; **execution-free** (not test-verified) | CC-BY-4.0; repos MIT/Apache/BSD [M] | Text passes; unverified quality |
| [togethercomputer/CoderForge-Preview](https://huggingface.co/datasets/togethercomputer/CoderForge-Preview) | 258,134 runs (155,144 pass), 51,201 tasks, 1,655 repos | Qwen3-Coder-480B (per [blog](https://www.together.ai/blog/coderforge-preview)) | SWE-smith 37,221 tasks, R2E-Gym 4,216, SWE-Rebench 9,764; repos filtered to permissive licences by scancode | No dataset-level licence on the card; per-row repo licence (MIT, Apache-2.0, …) [M] | SWE_Rebench split (77k runs, 44.7k passing) likely passes; SWE_Smith split inherits o3-mini-generated bugs ([SWE-smith](https://arxiv.org/html/2504.21798v2), [M]) and LM-written issues; licence unclear |
| [allenai SERA sets](https://huggingface.co/collections/allenai/open-coding-agents), e.g. [Sera-4.6-Lite-T2](https://huggingface.co/datasets/allenai/Sera-4.6-Lite-T2) | 36,083 trajectories (25k used for SERA-32B); six other GLM-4.5-Air / GLM-4.6 sets | GLM-4.6 ([MIT](https://huggingface.co/zai-org/GLM-4.6)); GLM-4.5-Air | Soft Verified Generation on 121 SWE-smith *codebases* (repos only), starting from a randomly sampled function; the card does not say which model wrote the problem statements | ODC-By, "intended for research and educational use" [M] | Likely passes if the teacher wrote all text (the paper's pipeline suggests so, unverified); the research-use wording needs reading |
| [nex-agi/agent-sft](https://huggingface.co/datasets/nex-agi/agent-sft) | 69,008 examples (agentic_code 24,796, agent 11,749, tool_call 9,737, html 8,332, chat 2,079) | DeepSeek-V3.1-Nex-N1 (licence not checked) | Queries "reselected from the NEX-N1 training dataset"; their authorship not stated ([Nex-N1 paper, arXiv 2512.04987](https://huggingface.co/collections/nex-agi/nex-n1)) | ODC-By [M] | Unknown: prompt provenance not stated |
| [SWE-Lego](https://arxiv.org/abs/2601.01426) | 14.1k–18.1k trajectories (32,119 instances) | Qwen3-Coder-480B, OpenHands 0.53 | Real + synthetic; synthetic issue statements by an unnamed "LLM" | Not found; "will be open-sourced" [M] | Unknown |
| [CLI-Universe-6K](https://arxiv.org/html/2606.22883) (terminal tasks) | 6k successful | Kimi-K2.6, DeepSeek-V4-Pro | Tasks, environments and tests built by unnamed LLM agents; GPT-5.4 (Codex) used as a judge | Release and licence not stated [M] | Unknown; the judge role is a proprietary involvement the owner must rule on |

- From the earlier notes (not re-checked): Lambda's Hermes traces (Kimi-K2.5, GLM-5.1, Apache-2.0, prompt authorship
  unstated) and OpenSWE (GLM-4.7 teacher, conflicting licence statements) — [Lambda](https://huggingface.co/datasets/lambda/hermes-agent-reasoning-traces),
  [OpenSWE card](https://huggingface.co/datasets/GAIR/OpenSWE).
- Fail the rule outright: SWE-smith trajectories (Claude 3.7 Sonnet teacher; o3-mini for LM-rewrite bugs) —
  [SWE-smith](https://arxiv.org/html/2504.21798v2); SWE-Gym (gpt-4o, Claude) and R2E-Gym (Sonnet) trajectories, per the
  earlier notes.

### Inferences
- A clean general-skill base for a Qwen-family student: Nebius SWE-rebench trajectories, plus Nemotron-SWE-v1 and the
  SWE_Rebench split of CoderForge after a test-origin check. All three share one teacher and one scaffold (OpenHands), so
  they teach OpenHands tool names; the deployed harness differs, so the data needs re-templating or a small share of
  harness-native sessions (the earlier notes found wrong-profile tool calls in the project's own pilot).
- These sets would also make the student imitate Qwen3-Coder-480B, which may suit Qwen-family students better than
  DeepSeek data on the familiarity argument (Q1, Q4), and leaves DeepSeek's budget for Elixir.

### Gaps
- SWE-rebench's own pipeline (whether any LLM rewrote or filtered issue text) and R2E-Gym's test origin were not
  verified here.
- I found no open agentic-coding trajectory set in Elixir, Erlang or Gleam, nor any written by DeepSeek-V4/V4.1, GLM-5,
  MiniMax-M2.x or Kimi-K2.6 with stated licences and prompt provenance.

## Q7. Low-resource languages: does the teacher's own weakness cap the student?

### Takeaway
Yes, when the student only imitates. In Fortran a Sonnet 4 teacher that solved 12 problems produced a distilled 4B
solving 2–3. In Verilog the DeepSeek-R1-distilled 7B stayed below R1 (56.2 % on RTLLM v1.1). In Chisel the distilled 32B
approached but did not pass its teacher. Students passed their teachers only after RL against a verifier (Agnostics'
RL'd 4B: 15 vs the teacher's 12 in Fortran; CodeV-R1 after RL: 72.9 %, above R1). I found no Elixir, Gleam, Erlang or
Haskell distillation study.

### Cited Findings
- Agnostics (arXiv 2508.04865): the authors argue distillation should work poorly when large models are weak in the
  language; Fortran results (Table 5): teacher (Sonnet 4 Thinking, 32K reasoning, ~$96, 1,987 training items) 12, base
  Qwen3-4B 0, distilled 3 / 3 / 2 after 1 / 2 / 3 epochs, RL'd Qwen3-4B-CF-X 15. RL'd 4B/8B on Ag-LCB-X: Lua 23/25,
  Julia 22/25, R 15/19 vs Qwen3-32B 22/26/17 and Llama 3.3 70B 25/22/13; OCaml 7/7 vs Sonnet 4 6 and Llama 70B 7;
  Fortran 15/17 vs Sonnet 4 6 and Llama 70B 3. Agnostics also cites MultiPL-T's ~30 % translation success rate as making
  rejection sampling expensive for low-resource languages. **[M]** — [Agnostics](https://arxiv.org/html/2508.04865)
- CodeV-R1 (Verilog): distilled from DeepSeek-R1 (with DeepSeek-V3 writing the problem descriptions) to 56.2 % RTLLM v1.1;
  after RL 72.9 %, said to beat DeepSeek-R1 by 8.1 points on RTLLM v1.1 and 3.3 on v2. **[S]** —
  [CodeV-R1](https://arxiv.org/abs/2505.24183)
- ChiseLLM (Chisel, from the earlier language-precedents note): R1-distilled reasoning traces; the 32B came near DeepSeek-R1
  671B on one metric (54.32 vs 55.25). **[M]** (earlier note) — [ChiseLLM](https://arxiv.org/html/2504.19144v1)
- Code-repair transfer study (arXiv 2406.14867): distilling code-repair ability "has language dependent benefits" that
  waver in low-resource languages, where reasoning and code-correction ability are only weakly correlated. **[C]** —
  [Wong et al.](https://arxiv.org/abs/2406.14867)
- GOLD lists "student performance is capped by the teacher" as a limitation of on-policy distillation in general.
  **[M]** — [GOLD post](https://huggingfaceh4-on-policy-distillation.hf.space/)

### Inferences
- For Elixir the cap is the teacher's verified Elixir pass rate, and that is the strongest argument for the first half of
  the owner's plan. Making DeepSeek better at Elixir (RL or rejection sampling against `mix compile` and `mix test`)
  raises both the ceiling and the yield of every student distilled from it. Making it better at generic Python agentic
  work does little for Elixir students.
- The same evidence argues for keeping an RL stage on the student. With cheap Elixir verifiers, the student can be pushed
  past the teacher's Elixir ceiling the way Agnostics and CodeV-R1 were, without relying on the teacher.
- Teacher weakness is measurable before any training. Per-task pass@k of DeepSeek on a held-out Elixir set predicts which
  tasks can enter the distillation set at all; tasks the teacher never solves need RL or hints, not distillation.

### Gaps
- No study distils a big teacher into a small model for Elixir, Gleam, Erlang, Haskell or Pharo inside an agent loop;
  all the low-resource evidence above is single-turn (competitive programming, RTL generation).
- No published Elixir score for DeepSeek-V4.1-Flash-1017 was found in this pass, so its weakness or strength as an
  Elixir teacher is unmeasured.
