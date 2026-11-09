# FireFlash: the agentic RL recipe (agenteconomics.org, 2026-11-02), its cited papers and tools, and what carries over to a small budget

Research date: 2026-11-03. Primary source: the post itself ([FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe), 21,538 characters, read in five passes). Every number below is the authors' own unless a third-party source is named. Labels used throughout: **measured** = a number the post reports from its own runs (not independently reproduced); **claimed** = a qualitative or causal statement with no number or table behind it; **(my arithmetic)** = computed by hand from cited numbers; **(inference)** = my reading, not stated by any source.

## What FireFlash did: the full recipe as stated in the post

### Takeaway
FireFlash is full-parameter, fully asynchronous GRPO on GLM-5.3-Flash (321B total, 17.4B active) for terminal and coding agents, run in under 5 days on 64 B300s, with three pillars: difficulty-filtered and gate-verified tasks, an RL objective tuned for stale FP8 rollouts (TIS + score centering + a success offset + a length bonus), and one Claude Code-style harness used for both training and evaluation. Your summary of the post is accurate in every number I checked; the few points where the post disagrees with itself are listed in the last section.

### Cited Findings
- **Authors and date:** Wenbo Hu, Jesse Cai, Po-nien Kung, Yuxuan Lu, Di Wu, Huimin Zeng (these five marked alphabetical), Nanyun Peng, Dakuo Wang, Kai-Wei Chang; dated 2 November 2026. The post states no affiliation, and the site's home page names no lab or university either. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe); [Agent Economics home](https://agenteconomics.org/)
- **Headline (Table 1, pass@1 averaged over 5 trials, FireFlash run in the authors' harness, baseline = GLM-5.3-Flash's official published entry):** Terminal-Bench 4.0 35.8 → 46.2 (+10.4); DeepSWE v1.1 63.4 → 68.8 (+5.4); SWE-Bench Pro Verified 58.2 → 63.3 (+5.1). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Positioning claims:** on Terminal-Bench 4.0 FireFlash passes Fable 5 and GLM-5.3, on DeepSWE v1.1 it passes "Fable 5.1", and on SWE-Bench Pro Verified it passes Kimi K3 and GPT-5.6 Sol. Of the more than forty models and effort settings plotted, only four cost less per trial, and none of those scores above 35.8 %. Every model that scores higher costs at least twice as much per trial. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Cost per trial on TB 4.0, priced at GLM-5.3-Flash's list rate "since we serve the model ourselves":** FireFlash $0.72, Fable 5 at maximum effort $22.02, GPT-6.1 Terra $1.49 (55.6 %), GLM-5.3 $8.27 (41.8 %). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Model and trained parameters:** GLM-5.3-Flash, 321B total and 17.4B active. All 320B language parameters are trained, including the MTP layer; the vision tower and the DSA indexer are frozen. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Infrastructure:** fully asynchronous, with half the GPUs on the trainer (slime, BF16, EP32, CP16) and half on rollout (SGLang engines at TP8, FP8 weights, FP8 KV cache, MTP speculative decoding with 3 draft steps, **1.38×** decode speed-up). Weights are pushed over NCCL after every step. A turn sampled more than 6 weight versions ago gets no gradient. The trainer–rollout log-prob gap rises only from **0.065** at one version of staleness to **0.08** at four to six versions. Key lesson 1: idle GPUs cost more than stale rollouts. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Sandbox:** each attempt runs in its own Firecracker microVM (AgentENV), forked from a per-task parent VM and graded in a separate grader VM, with no network. This cut rollout groups lost to infrastructure errors from **12 % to 0.5 %**. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Task selection:** each candidate task is profiled with at least 5 base-model rollouts (the prose; Table 4 says at least 4) under the exact training configuration: the same harness, reasoning effort, context window, turn budget and sandbox. Tasks with a 15–85 % initial pass rate are kept, which cut zero-signal rollout groups from **48 % to 10.2 %**. Pool mean pass rate 0.3–0.5, with 10–20 % hard but verified tasks. A never-solved task is kept only if its reference solution passes or a human audits it; the audit found that among never-solved tasks "nearly half were broken rather than hard". A task is retired only when every attempt on every visit solves it. Key lesson 2: spend rollouts only where the model is uncertain. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Task mix (Figure 3):** long-horizon agentic work 52 % = own long-horizon agentic tasks 30 % + hard tier 11 % + own long-horizon coding skills 9 % + MiMo-TB (public) 1 % + Tasksmith (public) 1 %. Software engineering 48 % = MiMo-code (public) 18 % + own SWE tasks, mostly Python, 18 % + own SWE tasks in TypeScript/Go/Python/JavaScript/Rust 12 %. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **The nine gates every new task must pass (Figure 4):** (1) the reference solution passes in the training sandbox through the exact training pipeline; (2) nothing unstated: every requirement the grader checks is in the prompt; (3) runs offline; (4) boots every time, never hangs; (5) no leaked answer in the environment; (6) no free credit: doing nothing or submitting boilerplate scores 0; (7) robust tests: any correct solution passes; (8) survives bad output: malformed agent output is scored, never a crash; (9) deterministic: the same output always gets the same score. Key lesson 3: a task the model never solves is often broken, so verify every grader first. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Reward:** one terminal reward R in [0,1] per attempt. Long-horizon tasks: 1.0 only if every check passes, at most 0.5 otherwise, at most 0.3 if a skill gate fails. SWE tasks: 1.0 for full resolution, 0 if the patch breaks a passing test, otherwise half the fraction of fail-to-pass tests resolved. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Advantage (GRPO, 12 attempts per task):** a solve enters as R′ = 1.5 ("success offset"); any other attempt as R′ = 0.5 × R, so the best near-miss (R = 0.5) counts 0.25. A = (R′ − mean R′)/std R′ + (b − mean b)/0.5, where the length bonus is b = 0.2 × (1 − tokens / max tokens among the group's solves) for a solve when the group has at least 2 solves, otherwise 0. The bonus "reduces tokens per solve to 0.84×" with no drop in evaluation accuracy. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Objective details:** truncated importance sampling clipped to [0.5, 2.0], with only 1–3 % of tokens hitting the clip; score centering over the sampler's top-32 log-probs removes the residual drift toward the stale FP8 sampler and costs **7.6 %** of step time. Per-attempt loss is normalised by token count with a 2,048-token floor on the denominator, so short rollouts cannot dominate. No KL, no entropy bonus. Entropy falls from about 0.46 to 0.33 in a healthy run, and rising entropy is the early warning of instability (key lesson 5: correct stale, low-precision samples rather than discard them). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Step (Table 4):** 32 tasks × 12 attempts = 384 trajectories per step and one optimizer update per step, LR 2.4e-6, 5-step warmup, gradient clip 0.5. Groups with uniform rewards are dropped and resampled, except up to 2 all-pass groups whose longest solve uses at least 1.2× the tokens of the shortest (kept for the length bonus). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Harness:** Claude Code conventions with four tools (Bash, Read, Write, Edit), native tool calls, retained reasoning history, maximum reasoning effort. Training and evaluation use the same harness, and unit tests check that code and prompts match (key lesson 4: the harness is part of the model). Each attempt gets 192K context, ≤200 turns, ≤3 h, and ≤4 compactions. State-preserving compaction triggers at 85 % of context and keeps the prefix cache by appending a sectioned summary prompt (summary up to 64K tokens, newest ~27K kept verbatim). Commands write stdout to files and return a truncated preview naming the file. Long commands continue in the background instead of dying at timeout. These cut per-trial cost by about a third; prompt guidelines (in-place edits, single-pass writes, no sleep polling) save a further 16 %. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Harness alone, before RL (Table 3, GLM-5.3-Flash on TB 4.0):** official Claude Code entry 35.8 % pass@1, $0.36 per trial, $1.01 per solve; the authors' harness 40.2 %, $0.46 per trial, $1.11 per solve. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **DeepSeek:** the post does not mention DeepSeek anywhere. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)

### Inferences
- Of the 100 % mix, 20 % is labelled public (MiMo-TB 1 + Tasksmith 1 + MiMo-code 18). The rest, 69 % labelled "(ours)" plus the unlabelled 11 % hard tier, is in-house data whose provenance is not described (my arithmetic).
- A solve enters at R′ = 1.5 while partial credit is compressed to R′ ≤ 0.25 (SWE, where R ≤ 0.5) or ≤ 0.25 (long-horizon, R ≤ 0.5). The length term (b − mean b)/0.5 with b ≤ 0.2 can then add up to about +0.4 to the shortest solve's advantage (my arithmetic). The design pushes the policy hard toward full, short solves over partial progress (inference).

### Gaps
- The post gives no step count, step time, task-pool size, number of distinct tasks seen, total tokens, or learning curves.
- The post never says who wrote the "(ours)" tasks, tests or reference solutions (humans, the base model, or a proprietary model).

## What exactly was released, and under what licence

### Takeaway
Nothing beyond the blog post itself, as of 2026-11-03. "Open recipe" means a description of the recipe: I found no FireFlash weights, code, configs, task set, harness or grader code, and no licence. The base model (GLM-5.3-Flash) and every tool the post cites are open (MIT or Apache-2.0).

### Cited Findings
- The post's only release statement is a single sentence saying the authors are releasing the full recipe. It names no weights, code, data or licence, and links only third-party projects (AgentENV, slime, SGLang) and papers. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- The site's home page lists three posts (FireFlash, "When More Reasoning Stops Paying Off", "How Many Tokens Is Your AI Agent Wasting?"), with no GitHub, Hugging Face or licence links. — [Agent Economics home](https://agenteconomics.org/)
- Papers with Code lists the post (id 131779, date 2026-11-02) with only the blog as its source. It has no code repository, no model or dataset links, no arXiv ID and no licence. — [paperswithcode.co/paper/131779](https://paperswithcode.co/paper/131779)
- A Hugging Face/GitHub search for "FireFlash" returned only unrelated DFlash drafter repos (for example incoai/GLM-5.3-Flash-DFlash2). — [HF search result: incoai/GLM-5.3-Flash-DFlash2](https://huggingface.co/incoai/GLM-5.3-Flash-DFlash2)
- **Task provenance:** the post names no proprietary model (Claude, GPT, Gemini, Fable) as a generator or verifier of tasks, tests or reference solutions. Those names appear only as benchmark comparisons, and "Claude Code" only as a harness convention and a leaderboard entry. It is equally silent on how the "(ours)" tasks were made. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Base model licence:** GLM-5.3-Flash is MIT; its card says 320B total and 18B active in the introduction, while the HF metadata says 321B. It describes a hybrid sparse/linear-attention architecture with mHC and native multimodality. — [zai-org/GLM-5.3-Flash](https://huggingface.co/zai-org/GLM-5.3-Flash)
- **Public task sources in the mix:** the post does not link MiMo-TB, Tasksmith or MiMo-code. Xiaomi's MiMo-V2.6 release published RL environments: a third-party write-up says the MiMo-V2.6-RL-oss set has 7,780 tasks across five domains, including 64 terminal tasks, with graders, under Apache 2.0, while another blog says the checkpoints are MIT. — [towardsai write-up](https://pub.towardsai.net/what-xiaomis-7-780-mimo-tasks-reveal-about-training-agents-2788d4ce8a81); [MiMo-V2.6 report listing](https://hyper.ai/en/papers/2610.11959)
- A Hugging Face dataset "HF_ML_Tasksmith" holds 50 Harbor tasks generated with the tasksmith recipe in Repo2RLEnv. Its licence is "other", and source files keep their upstream repository licences. I could not confirm it is the "Tasksmith (public)" the post uses. — [HuggingEnvs/HF_ML_Tasksmith](https://huggingface.co/datasets/HuggingEnvs/HF_ML_Tasksmith)
- The cited tools are open: AgentENV is MIT, slime is Apache-2.0, and the score-centering reference code is MIT. — [AgentENV](https://github.com/kvcache-ai/AgentENV); [slime](https://github.com/THUDM/slime); [score-centering](https://github.com/martin-marek/score-centering)

### Inferences
- Because GLM-5.3-Flash is MIT, a FireFlash weight release would face no licence obstacle; the absence is the authors' choice or timing (inference).
- "MiMo-TB" and "MiMo-code" are very likely drawn from Xiaomi's MiMo-V2.6 RL environment release, but the post does not say so (inference).
- For a project restricted to publishable, licence-clean data, about 80 % of FireFlash's training mix is unknown-provenance in-house data and cannot be reused; only the public 20 % (MiMo/Tasksmith, licence to be checked per task) is a candidate (my arithmetic, inference).

### Gaps
- No FireFlash GitHub, HF model card, dataset card or arXiv version found as of 2026-11-03.
- I found no primary page (Xiaomi HF or GitHub) confirming the MiMo task licence; the 7,780 and Apache 2.0 figures come from a secondary source.

## What each component contributed, and how big it is against the +10.4 TB 4.0 gain

### Takeaway
Only one component has a benchmark ablation: the harness, +4.4 on TB 4.0 before any RL, which is about 42 % of the headline +10.4, leaving +6.0 for RL itself. Every other number is an efficiency or diagnostic metric (zero-signal groups, lost groups, decode speed, tokens per solve, cost), and none of the RL-objective pieces (TIS, score centering, success offset, loss floor, length bonus) has a with/without benchmark number. All results are single runs with no seeds or confidence intervals.

### Cited Findings
- **Harness:** TB 4.0 35.8 → 40.2 (+4.4) with identical weights; cost $0.36 → $0.46 per trial and $1.01 → $1.11 per solve (measured, Table 3). Compaction, file-redirected output and background execution cut per-trial cost by about a third, and prompt guidelines save a further 16 % (measured, no table). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Task selection (15–85 % band):** zero-signal groups 48 % → 10.2 % (measured, efficiency metric; no benchmark ablation). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Grader gates:** "nearly half" of never-solved tasks were broken (audit result, no count). No benchmark ablation. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Sandbox (AgentENV microVMs):** lost groups 12 % → 0.5 % (measured, infrastructure metric). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **MTP speculative decoding:** 1.38× decode speed-up at 3 draft steps (measured, throughput). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Staleness ≤6 versions:** log-prob gap 0.065 → 0.08 (measured diagnostic); no comparison with a synchronous or less-stale run. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **TIS:** 1–3 % of tokens clipped (measured diagnostic). **Score centering:** +7.6 % step time (measured); "removes residual drift" (claimed, no curve or number). **Success offset, loss floor of 2,048 tokens, no KL/entropy bonus:** design choices, no ablation. **Entropy** 0.46 → 0.33 (measured diagnostic). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Length bonus:** tokens per solve 0.84× "with no drop in evaluation accuracy" (measured on tokens, claimed on accuracy; no table, no baseline named). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)

### Inferences
- Decomposition of the TB 4.0 gain: harness +4.4 (4.4/10.4 = 42 %) and RL +6.0 (46.2 − 40.2; 6.0/10.4 = 58 %) (my arithmetic). Against the harness-matched pre-RL baseline, RL's own TB 4.0 gain is +6.0, not +10.4.
- The same harness confound applies to the other two benchmarks. DeepSWE's 63.4 baseline is the official entry run with mini-swe-agent (see the last section), and FireFlash ran in its own harness, so the +5.4 and +5.1 mix harness and RL effects in unknown proportions (inference).
- Selection makes far more of each step usable: groups with signal go from 52 % to 89.8 % of the sampled groups, ×1.73 (my arithmetic). Sandboxing makes 99.5 % instead of 88 % of groups survive, ×1.13 (my arithmetic). Combined, about ×1.95 more groups with learning signal per rollout GPU-hour, before MTP's 1.38× (my arithmetic, assuming the effects are independent, which the post does not show).
- Cost per solve: FireFlash $0.72 / 0.462 ≈ $1.56, against $1.11 for the base in the same harness, i.e. RL raised cost per solve by about 40 % (my arithmetic). Per trial it rose from $0.46 to $0.72, ×1.57 (my arithmetic). The 0.84× tokens-per-solve figure must therefore be relative to an RL run without the length bonus, not to the base model (inference).
- Statistical weight: TB 4.0 has 66 tasks (vals.ai), so one task is about 1.5 points, +10.4 is about 6.9 tasks, and the harness's +4.4 is about 2.9 tasks (my arithmetic). Averaging 5 trials reduces trial noise but not task-sampling noise. DeepSWE v1.1 has 113 tasks, so +5.4 is about 6 tasks, close to the leaderboard's own ±4 % interval for GLM-5.3-Flash. SWE-Bench Pro Verified has 731 instances, so +5.1 is about 37 tasks, the statistically strongest of the three gains (my arithmetic).

### Gaps
- No ablation of TIS vs TIS + SC vs no correction, of the success offset, of the length bonus on accuracy, of staleness, of the 15–85 % band against random tasks, or of the harness during training (a model trained in another harness). No training curves.

## What the cited papers (2609.20807, 2610.22192, 2609.08149) actually say

### Takeaway
Score centering (2609.20807) is a real, hyperparameter-free fix for training–inference mismatch drift. It was shown at 0.6B–30B on 8×H100 nodes (~6,180 H100-hours in total), helps most under staleness and harsh quantization (FP8 alone was already stable), and is cheap to adopt (MIT code, already integrated in verl, TRL, slime, SkyRL, prime-rl and Tinker). The "success offset" citation (2610.22192) is loose: that paper is Terminal-RSI, a PPO + GAE method on Qwen3.8-27B whose "Success-Prioritized Reward" adds one unit for strict success, and it has no GRPO term, no 1.5 constant and no training ablation of the reward.

### Cited Findings
- **2609.20807, "Score Centering Stabilizes Off-policy Reinforcement Learning" (Martin Marek, Max Ryabinin; v1 17 Sep 2026):** it argues that RL instability under training–inference mismatch (TIM) comes mainly from drift, a persistent bias that accumulates over steps, and derives an additive score-centering correction that cancels it. Score centering alone matches or beats importance-sampling methods under quantization, with the gap growing as mismatch worsens, and composed with IS it beats pure-IS baselines in the staleness experiments. — [arXiv 2609.20807](https://arxiv.org/abs/2609.20807)
- **The method:** the policy-gradient score of the sampled token, ∇log p(y_t), is replaced by itself minus the sampler-expected score Σ_v q_v ∇log p_v, where q is the sampler's and p the trainer's distribution. In practice it uses the sampler's top-k log-probs (k = 128 by default; the paper says k = 32 matches full centering), with the tail modelled by the trainer distribution and rescaled to the sampler's tail mass, and no hyperparameters. It composes with TIS (ratio clamp at 2) and MIS. — [arXiv 2609.20807 HTML](https://arxiv.org/html/2609.20807)
- **Setup:** Qwen3-0.6B-Instruct on Countdown, Qwen3-1.7B in a toy study, and Qwen3-30B-A3B-Base on the INTELLECT-2 math subset. REINFORCE with group-centred ±1 rewards, one SGD step per batch, batches of 64×8 (0.6B) and 16×8 (30B). TIM is simulated three ways: synthetic weight noise; a quantized sampler with a BF16 trainer (FP8, FP4-KV, INT8 W/A + INT4-KV at 30B); and staleness (inference engine updated every 64 steps). It ran mainly on 8×H100 SXM nodes, about 6,180 H100-hours in total. The paper does not mention LoRA. — [arXiv 2609.20807 HTML](https://arxiv.org/html/2609.20807)
- **Results (30B):** with an FP8 sampler even uncorrected PG trains stably (58 % training accuracy). With an FP4 KV cache, PG collapses within 200 steps, while SC reaches 52 % and TIS 51 %. With INT8 + INT4-KV, SC reaches 30 %, TIS 12 %, and all others end below 5 %. **At 0.6B:** under the largest synthetic noise only SC (alone or with TIS/MIS) trains stably, and under staleness SC + TIS/MIS is best. The overhead is within 1 % of wall-clock in the authors' JAX stack; they did not measure it in vLLM or SGLang. — [arXiv 2609.20807 HTML](https://arxiv.org/html/2609.20807)
- **Code:** the score-centering repo is MIT, mainly JAX with a PyTorch version of the loss; it lists integrations in verl, TRL, slime, Miles, prime-rl, Molt, SkyRL, Vime and Tinker, has a CPU test that SC cancels drift, and 225 stars. — [martin-marek/score-centering](https://github.com/martin-marek/score-centering)
- **2610.22192, "Terminal-RSI: Recursive Self-Improving Terminal Agents via Recursive Self-Rewrite and Policy-Refine" (Junyao Yang et al.; v1 15 Oct 2026, v3 30 Oct 2026; 26 pages):** it alternates trajectory self-rewrite (RSR) and policy refinement (RPR) from Qwen3.8-27B, introducing TB-GAE, a Family Dense Reward (FDR) and a Success-Prioritized Reward (SPR). Results: TB 4.0 19.84 %, TB 2.1 86.52 %, TB 3.0 16.95 %, TB Hard 79.00 %. — [arXiv 2610.22192](https://arxiv.org/abs/2610.22192)
- **SPR:** R = S + P/(P + D′_f) when the verification report is valid, otherwise R = S, so 0 ≤ R < 2 and success gets one extra unit. It is used with PPO, TB-GAE and a learned critic (KL and entropy coefficients 0), not GRPO. Evidence is offline only, on 4,352 fixed trajectories: mean success reward 1.01 (FDR) vs 1.50 (SPR), mean failure reward 0.41 vs 0.24, failures' share of reward mass 50.09 % vs 28.72 %. The authors say this isolates reward allocation, not training outcomes, and their one online comparison does not isolate SPR. — [arXiv 2610.22192 HTML](https://arxiv.org/html/2610.22192)
- **Terminal-RSI's stack and data:** slime coordination (from T1), Megatron, SGLang sampling and Harbor execution; a 3,000-task pool (2,400 semantic-verifier tasks + 600 terminal tasks). It names no proprietary model as a task or trajectory generator, and lists code at github.com/jyyang26/Terminal-RSI and weights on Hugging Face. On TB 4.0 it lists DeepSeek V4 Pro at 14.60 % and Gemini 3.8 Flash at 19.70 %. — [arXiv 2610.22192 HTML](https://arxiv.org/html/2610.22192)
- **2609.08149, "SWE-Bench Pro Verified: A Reliable Benchmark for Software Engineering Agents" (Pujun Zheng et al.; v1 8 Sep 2026, v3 9 Oct 2026; CC BY 4.0):** it has 731 instances and fixes SWE-Bench Pro's reward-hacking channels (fresh single-commit repos, deleted or hidden tests, disabled git hooks, gold patches filtered from metadata, hashed IDs, code-hosting domains blocked). Human experts revised 102 of 119 flagged instances and rejected 17. Evaluation uses mini-swe-agent. GLM-5.2 drops from 78.80 (baseline) to 57.32 (anti-hacking) and 59.51 (Verified), while DeepSeek-V4-Pro stays at 49.98 / 49.11 / 49.93. — [arXiv 2609.08149](https://arxiv.org/abs/2609.08149); [HTML v3](https://arxiv.org/html/2609.08149v3)

### Inferences
- FireFlash's constants (solve = 1.5, best near-miss = 0.25) match SPR's offline mean success (1.50) and mean failure (0.24) rewards almost exactly. FireFlash appears to have turned SPR's average allocation into fixed GRPO constants; the post calls this a "success offset in GRPO", which the cited paper never defines (inference).
- Score centering's own evidence says FP8 rollouts alone barely need correction. The benefit in FireFlash's setting most likely comes from the up-to-6-version staleness, where the paper shows SC + TIS beats TIS (inference). For a small synchronous on-policy run with BF16 rollouts, SC is cheap insurance rather than a requirement (inference).
- FireFlash's 7.6 % SC overhead vs the paper's <1 % suggests extracting top-32 log-probs from SGLang at 192K context is costlier than in the authors' JAX sampler (inference).
- Small scale is covered: SC was demonstrated at 0.6B on Countdown and at 30B-A3B, i.e. at single-node scale. Terminal-RSI shows a slime + Megatron + SGLang terminal-RL stack at 27B dense (inference from the two papers' setups).

### Gaps
- Neither paper tests LoRA. Score centering with LoRA, and inside SGLang/vLLM samplers, is untested in the papers themselves (the repo lists framework integrations but no results there).
- Terminal-RSI's GPU count is not stated.

## AgentENV and slime: what they provide and require, and DeepSeek V4/V4.1 support

### Takeaway
AgentENV (MIT) is Kimi K3's production sandbox platform: Firecracker microVMs from OCI images with snapshots and forks in under 100 ms and an E2B-compatible API. It needs only Linux ≥ 6.8 with /dev/kvm and documents a single-node install, so one KVM-capable machine can run it, at a scale that will be small. slime (Apache-2.0) is Megatron + SGLang RL with GLM-5.3-Flash support and a fully-async example, but its README lists DeepSeek only up to V3/V3.1/R1, with no V4 or V4.1. The only DeepSeek-V4 training path I found is ms-swift's Megatron-SWIFT (V4-Flash; LoRA on 8 GPUs, full-parameter at 64), with known Megatron-Core precision bugs.

### Cited Findings
- **AgentENV:** a distributed platform for agent environments used for Kimi K3's agentic RL. It runs Firecracker microVMs loaded on demand from OCI images via overlaybd ("1.5 million images in production"); snapshot-backed environments boot or resume in under 50 ms and pause in under 100 ms; incremental snapshots take under 100 ms; a running environment can fork into independent sandboxes. Snapshots go to S3-compatible storage or a shared filesystem, I/O runs through ublk, and memory ballooning gives 9.6× overcommit in production. It exposes an E2B-compatible HTTP API and an `aenv` CLI, with single-node (script or Docker), Docker Compose and Kubernetes installs. It requires Linux ≥ 6.8 and /dev/kvm (a PVM guide exists where KVM is unavailable). API traffic is authenticated but not encrypted. MIT licence, about 3.7k stars, no tagged releases. — [kvcache-ai/AgentENV](https://github.com/kvcache-ai/AgentENV)
- **slime:** Megatron for training and SGLang for rollout, Apache-2.0. Supported models include GLM-5.3-Flash, GLM-5.3, GLM-5.x and GLM-4.5–4.7; Qwen3.8, 3.6, 3.5, 3-Next, 3 MoE, 3 and 2.5; "DeepSeek (V3, V3.1, R1)"; Llama 3. DeepSeek V3.2/V4/V4.1 and Kimi are not listed. `examples/fully_async` is aimed at long-tail agentic generation, and multi-turn tool and sandbox loops are supported through custom generate functions (examples include coding_agent_rl). The README does not mention FP8 rollout, MTP training or LoRA; the downstream Miles fork adds LoRA and low-precision training. Minimum hardware is not stated. — [THUDM/slime](https://github.com/THUDM/slime)
- **Megatron-SWIFT (ms-swift) for DeepSeek-V4:** it states fine-tuning and RL support for DeepSeek-V4. Its examples use V4-Flash-Base and V4-Flash: BF16 LoRA on 8 GPUs (EP8) and a 64-card full-parameter example (PP8). FP8 blockwise training is supported, but an FP8 LoRA delta rounds to 0, so LoRA weights must be kept separate. MTP is supported (`mtp_num_layers 1`). It needs the Megatron-Core dev branch, has known precision deviations in Megatron-Core's DeepSeek-V4 operators (NVIDIA/Megatron-LM #4957), supports no TP, and supports no packing or padding-free batching. V4.1 and Engram are not mentioned. — [ms-swift DeepSeek-V4 best practices (mirror)](https://hjh-swift.readthedocs.io/en/latest/_sources/BestPractices/deepseek-v4.md.txt)
- **DeepSeek-V4.1-Flash-1017:** MIT; the HF safetensors metadata gives **763B** total parameters, with a 1M context. The card lists Terminal-Bench 4.0 **42.3** (Claude Code harness) and DeepSWE v1.1 **77.0** (Mini-SWE-V2 harness), against 31.2 / 74.2 for the earlier V4.1-Flash. It does not mention RL frameworks. — [deepseek-ai/DeepSeek-V4.1-Flash-1017](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017)

### Inferences
- The project note "552B plus a 196B Engram table" sums to 748B (my arithmetic), close to but not equal to the card's 763B metadata. The 15B difference could be MTP or vision weights; I could not confirm (inference).
- RL on DeepSeek-V4.1 with FireFlash's stack would need porting V4.1 (and its Engram table) into slime/Megatron and SGLang's RL weight-sync path, which no public source shows done (inference).
- Memory scale for full-parameter training: with mixed-precision Adam at about 16 bytes per parameter, GLM-5.3-Flash needs about 5.1 TB against the 32 trainer B300s' 9.2 TB (32 × 288 GB). DeepSeek-V4.1-Flash at 763B would need about 12.2 TB, about 2.4× GLM's need, before activations at 192K context (my arithmetic; the bytes-per-parameter figure is a standard rule of thumb, not from the post). Freezing the Engram table would reduce this.
- AgentENV on one machine: the requirements (kernel ≥ 6.8, KVM) are met by ordinary Linux workstations, so a single-node install should work; the overlaybd, ublk and S3 parts are designed for fleets (inference; the repo does not discuss consumer hardware).

### Gaps
- AgentENV's README does not describe a grader-VM pattern, network isolation, or Terminal-Bench, SWE-bench or Harbor task formats; FireFlash's per-task parent VM and separate grader VM are FireFlash's own use, not a documented AgentENV feature.
- I found no official ms-swift page (only a mirror) and no V4.1-specific support statement anywhere.

## Compute: GPU-hours, split, steps and trajectories

### Takeaway
At most about 7,680 B300 GPU-hours (64 × 5 days), split equally between rollout and training. The post gives no step count or step time, so total trajectories and tokens cannot be derived; only per-step sizes are known (384 trajectories, up to 192K context and 3 h each).

### Cited Findings
- 64 B300s (288 GB each), split evenly between trainer and rollout, under 5 days. Table 4, however, says "Half of the hundred-level B300 GPUs" (see the last section). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- Per step: 32 tasks × 12 attempts = 384 trajectories; each attempt ≤ 192K context, ≤ 200 turns, ≤ 3 h, ≤ 4 compactions. Rollout engines are TP8; the trainer uses EP32 and CP16. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- For scale: the score-centering paper's entire study used about 6,180 H100-hours. — [arXiv 2609.20807 HTML](https://arxiv.org/html/2609.20807)

### Inferences
- GPU-hours: 64 × 5 × 24 = 7,680 B300-hours at most, 3,840 on the trainer and 3,840 on rollout (my arithmetic).
- Rollout engines: 32 rollout GPUs / TP8 = 4 SGLang engines (my arithmetic, assuming one engine per TP8 group and no DP attention).
- Trainer memory: 32 × 288 GB = 9.2 TB (my arithmetic).
- Upper bound on tokens per step: 384 × 192K ≈ 73.7M tokens if every attempt filled its context once. With up to 4 compactions an attempt can generate more than 192K in total, so this is only an order of magnitude (my arithmetic).
- If steps took about 1 h (illustrative only; not stated), 120 h would give about 120 steps and about 46k trajectories (my arithmetic). The real figures are unknown.

### Gaps
- Steps, step time, distinct tasks seen, total trajectories, total tokens, rollout throughput and dollar cost of the run are all absent.

## What transfers to a far smaller budget, and what needs the big cluster

### Takeaway
Most of FireFlash's measured value transfers cheaply: the harness (+4.4 with no training), the nine grader gates, difficulty filtering profiled under exact training conditions, dropping uniform groups, the success offset, the length bonus and the 2,048-token loss floor are all engineering or reward-shaping. They apply equally to filtering teacher trajectories for SFT data. Score centering + TIS is cheap and proven small (0.6B). What does not transfer is the scale: full-parameter RL of a 300B-class MoE with FP8 async rollouts at 192K context and 3-hour attempts.

### Cited Findings
- The harness gain needs no training: +4.4 on TB 4.0 from tools, compaction at 85 %, file-redirected output with previews, background execution and prompt guidelines, with cost per trial down by a third plus 16 % from those features. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- Difficulty filtering needs only at least 4–5 rollouts per candidate task under the exact training configuration, and it cut zero-signal groups from 48 % to 10.2 %. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- The gates are checks on the task, not on the model: reference passes, null agent scores 0, deterministic scoring, offline boot, malformed-output survival. The audit found nearly half of never-solved tasks broken. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- Score centering works at 0.6B and 30B-A3B on 8×H100 nodes, and its code integrates with verl, TRL, slime, SkyRL, prime-rl and Tinker. — [arXiv 2609.20807 HTML](https://arxiv.org/html/2609.20807); [score-centering repo](https://github.com/martin-marek/score-centering)
- AgentENV documents a single-node install and needs only KVM and Linux ≥ 6.8. — [AgentENV](https://github.com/kvcache-ai/AgentENV)
- A 27B dense terminal-RL run (Terminal-RSI) on slime + Megatron + SGLang + Harbor reached 19.84 % on TB 4.0. — [arXiv 2610.22192](https://arxiv.org/abs/2610.22192)
- Xiaomi's MiMo-V2.6 open run reportedly took MiMo-V2.6-Distill-Qwen-9B from 37.1 to 52.8 on Terminal-Bench 2.1 (secondary source). — [towardsai write-up](https://pub.towardsai.net/what-xiaomis-7-780-mimo-tasks-reveal-about-training-agents-2788d4ce8a81)

### Inferences
- **Cheap, transferable now (no GPU cluster):**
  - The harness design (output-to-file previews, background execution, compaction at 85 % with a prefix-preserving summary, anti-polling prompt rules), used identically for data generation, training and evaluation.
  - The nine gates as a CI suite for every task.
  - 15–85 % pass-rate filtering profiled with the exact model, harness, context and turn budget that training will use.
  - The reward shaping: success offset, near-miss compression, length bonus only among ≥2 solves, and the 2,048-token normalisation floor.
  - Dropping and resampling uniform groups, and entropy as the early-warning metric (inference).
- **For the teacher → data-dump goal:** the gates and the 15–85 % filter double as a rejection-sampling filter for SFT trajectories from DeepSeek-V4.1-Flash. Keep only gate-verified full solves, prefer the shortest solve per task (the length-bonus logic), and record the harness exactly, since FireFlash shows that harness choice alone moves TB 4.0 by 4.4 points (inference).
- **Cheap, at small-model RL scale:** GRPO with 12 attempts, TIS [0.5, 2] and score centering on a ≤30B model with LoRA or full fine-tuning in verl, slime or SkyRL. LoRA itself is untested by either paper (inference).
- **Needs the big cluster:**
  - Full-parameter RL of a 321B or 763B MoE.
  - Async trainer/rollout halves with NCCL weight sync every step.
  - FP8 SGLang engines at TP8 with MTP.
  - 192K-context, 200-turn, 3-hour attempts × 384 per step.
  - Firecracker fleets with snapshot forking at hundreds of concurrent VMs.

  For DeepSeek-V4.1-Flash specifically, no public RL framework lists V4.1 support (inference).
- **Context-dependent:** async with ≤6-version staleness pays off only when attempts are long-tailed (hours); short attempts on a small model can run synchronously, making TIS/SC less critical (inference from the score-centering results, where FP8 alone was stable).

### Gaps
- The post gives no small-scale validation of its own recipe (no smaller GLM, no LoRA run), so transfer of the combined recipe below 300B is untested.

## Leaderboard placement: GLM-5.3-Flash, FireFlash and DeepSeek-V4.1-Flash-1017

### Takeaway
FireFlash appears on no independent leaderboard yet. Comparisons with DeepSeek-V4.1-Flash-1017 depend on the harness. Vendor-reported, V4.1-1017 is above FireFlash on DeepSWE v1.1 (77.0 vs 68.8) and below it on TB 4.0 (42.3 vs 46.2). On vals.ai's single-harness TB 4.0 table, V4.1-1017 (31.82 %) scores below FireFlash's own base GLM-5.3-Flash (37.37 %).

### Cited Findings
- **vals.ai Terminal-Bench 4.0 (updated 29 Oct 2026):** 66 community-contributed, maintainer-reviewed tasks. mini-swe-agent with a bash tool, 3 runs averaged (avg@3), no partial credit, an 8-hour agent limit, Daytona sandboxes. Scores and cost per test: Claude Opus 5.5 65.15 % ($13.20), Claude Sonnet 5.5 64.14 %, Kimi K3.1 Pro 63.64 %, Claude Fable 5.1 58.08 % ($17.18), GPT-6.1 Terra 49.49 % ($2.16), GPT-6 Sol 44.44 %, Claude Fable 5 41.41 % ($30.34), GLM 5.3 38.89 % ($9.37), **GLM 5.3 Flash 37.37 % ($1.22)**, **DeepSeek V4.1 Flash (1017) 31.82 % ($0.54)**, Kimi K3 17.17 %, DeepSeek V4 Pro 0813 14.14 %. No FireFlash entry. — [vals.ai TB 4.0](https://www.vals.ai/benchmarks/terminal-bench-4)
- The official tbench.ai leaderboard page rendered no rows to the fetch tool. BenchLM lists GLM-5.3-Flash at 35.76 % under Claude Code (sourced to Z.AI), which matches the post's 35.8 baseline. — [tbench.ai leaderboard](https://www.tbench.ai/leaderboard); [BenchLM TB 4.0](https://benchlm.ai/benchmarks/terminal-bench-4)
- **DeepSWE v1.1 leaderboard (updated 22 Sep 2026; 113 original tasks in 91 repositories and 5 languages, hand-written verifiers, canary GUID, all models on mini-swe-agent):** GLM-5.3-Flash [max] 63 % ±4 % ($0.24), DeepSeek V4 Pro 63 % ±6 %, Claude Fable 5 [xhigh] 70 % ±3 %, Kimi K3 69 % ±5 %, GPT-5.6 Sol 73 % ±3 %, deepseek-v4-flash 53 %, gpt-6-astra 74 %. No FireFlash, Fable 5.1 or V4.1-1017 entry. — [DeepSWE leaderboard](https://deepswe.datacurve.ai)
- The GLM-5.3-Flash card gives DeepSWE 63.4 with the mini-swe-agent harness (400K context), the post's baseline number. — [zai-org/GLM-5.3-Flash](https://huggingface.co/zai-org/GLM-5.3-Flash)
- DeepSeek's card reports TB 4.0 42.3 (Claude Code) and DeepSWE 77.0 (Mini-SWE-V2) for V4.1-Flash-1017, and on its own runs lists GLM-5.3 at 37.9 / 66.9 and Opus 5 at 51.8 / 74.0. — [DeepSeek-V4.1-Flash-1017 card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017)

### Inferences
- The project note (77.0 DeepSWE, 42.3 TB 4.0 for V4.1-Flash-1017) matches the vendor card, but these are vendor numbers in vendor-chosen harnesses. Independently (vals.ai, mini-swe-agent) V4.1-1017 is about 5.5 points below GLM-5.3-Flash on TB 4.0, i.e. FireFlash's starting point is the stronger terminal agent there (my arithmetic: 37.37 − 31.82 = 5.55).
- FireFlash's claim to pass "Fable 5.1" on DeepSWE (68.8) cannot be checked. DeepSWE's own leaderboard has Fable 5 at 70 % ±3 %, above FireFlash, and vals.ai has Fable 5.1 well above Fable 5 on TB 4.0 (58.08 vs 41.41), so passing Fable 5.1 but not Fable 5 is implausible on its face (inference).
- On cost, vals.ai prices GLM 5.3 Flash at $1.22 per TB 4.0 test vs the post's $0.36–0.46 (Claude Code / own harness); the post's self-served list-rate pricing and harness choices make its cost axis not comparable with third-party tables (inference).

### Gaps
- I found no FireFlash discussion on X, Hacker News or Reddit through the search tools, only the Papers with Code listing (the post is one day old).

## Inconsistencies and weak points in the post

### Takeaway
The post is a self-reported single run with a strong harness confound, no ablations of its RL-specific contributions, internal inconsistencies (GPU count, profiling samples, parameter counts), no contamination discussion, nothing released, and an unverifiable "Fable 5.1" comparison. Its infrastructure numbers (zero-signal 48 → 10.2 %, lost groups 12 → 0.5 %) are the most useful and least controversial parts.

### Cited Findings
- **GPU count:** the introduction says 64 B300s; Table 4 says "Half of the hundred-level B300 GPUs", and the intro also speaks of bringing frontier efficiency to "a hundred-GPU-scale cluster". — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Profiling samples:** the prose says at least 5 rollouts per task; Table 4 says at least 4 samples. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Parameter counts:** the post says 321B total / 17.4B active (320B language parameters trained); the GLM-5.3-Flash card's introduction says 320B / 18B, and its HF metadata 321B. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe); [zai-org/GLM-5.3-Flash](https://huggingface.co/zai-org/GLM-5.3-Flash)
- **Harness confound:** the baselines are official entries (TB 4.0 via Claude Code; DeepSWE via mini-swe-agent), while FireFlash runs in the authors' harness. The post shows the harness alone is worth +4.4 on TB 4.0. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe); [zai-org/GLM-5.3-Flash](https://huggingface.co/zai-org/GLM-5.3-Flash)
- **Contamination:** the post has no decontamination statement. The "No leaked answer" gate concerns the training environment, not overlap with benchmarks, and the post does not say whether its public sources (MiMo-TB, Tasksmith, MiMo-code) or its own SWE repos overlap the benchmarks. TB 4.0 tasks are community-contributed; SWE-Bench Pro Verified is built from public repositories (e.g. Ansible, qutebrowser, NodeBB, Open Library). — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe); [vals.ai TB 4.0](https://www.vals.ai/benchmarks/terminal-bench-4); [arXiv 2609.08149 HTML](https://arxiv.org/html/2609.08149v3)
- **Reward hacking:** SWE-Bench Pro Verified exists because hacking channels inflated scores (GLM-5.2 78.80 → 57.32 under anti-hacking). The post does not say whether FireFlash's own harness applied the benchmark's safeguards, such as blocked code-hosting domains and the fresh single-commit repos. — [arXiv 2609.08149 HTML](https://arxiv.org/html/2609.08149v3)
- **Statistics:** only pass@1 averaged over 5 trials, with no confidence intervals, seeds or pass@k. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)
- **Citation fit:** 2610.22192 does not contain a GRPO "success offset"; it defines SPR for PPO + GAE. — [arXiv 2610.22192 HTML](https://arxiv.org/html/2610.22192)
- **Cost axis:** self-served at GLM-5.3-Flash list rate, in the authors' harness, at maximum effort. — [FireFlash post](https://agenteconomics.org/posts/agentic-rl-recipe)

### Inferences
- The +10.4 headline overstates what RL did on TB 4.0; the harness-matched RL gain is +6.0 (my arithmetic), and on 66 tasks that is about 4 tasks (my arithmetic: 6.0 / 1.52).
- RL raised cost per solve by about 40 % ($1.11 → $1.56, my arithmetic), so the "Pareto frontier" claim rests on comparison with other models, not on RL making the base cheaper per solve (inference).
- The DeepSWE comparison with "Fable 5.1" is probably a typo for another model, or uses a Fable 5.1 entry not on the public leaderboard (inference).

### Gaps
- No independent replication, no third-party leaderboard entry, no released artefacts that would let anyone check the numbers.
