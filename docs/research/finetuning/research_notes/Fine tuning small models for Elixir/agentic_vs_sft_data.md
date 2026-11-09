# Agentic vs SFT data: what makes a small model better at agentic coding (as of 2026-11-02)

Reading guide. "Est." marks this note's own arithmetic. "Pts" means percentage points of resolve rate. SWE-bench numbers
from different papers use different scaffolds and models, so they show direction and order of magnitude, not a ranking.
Nearly every number is Pass@1 unless stated; Best@K needs K attempts plus a verifier, which is not affordable on the rig.
The assignment does not name the 9B, so these notes assume a Qwen3.5-9B class model. The quant machine is taken as
5 × RTX 3090 + 2 × RTX 3080.

## Q1. SFT from single prompt→answer: what does it improve for agentic use?

### Takeaway
Single-turn SFT raises code knowledge and single-turn benchmark scores, but I found no controlled study showing it helps
inside a tool loop. The evidence that does exist points to multi-turn trajectories or execution-scored RL as what moves
agent success. The owner's dataset is still valuable, because its tests make it a seed for tasks and for single-turn RL.

### Cited Findings
- Qwen-2.5-Coder-Instruct models, tested in a real agent loop (OpenHands) on SWE-bench Verified before any agent fine-tune, resolved only 1.8 % (7B), 4.0 % (14B) and 7.0 % (32B); 491 trajectories lifted them to 10.6, 16.4 and 20.6 — [SWE-Gym](https://arxiv.org/html/2412.21139v2).
- Newer bases start far higher with no agent fine-tune: Qwen3-14B with thinking at 18.0 % — [SkyRL](https://sky.cs.berkeley.edu/project/skyrl/); Qwen3-32B at 23 % — [DeepSWE](https://www.together.ai/blog/deepswe) to 24.4 % — [SkyRL-Agent](https://arxiv.org/html/2511.16108v1).
- Qwen3-Coder-Next's single-turn evidence is about knowledge benchmarks: rewriting web text moved EvalPlus 54.38→63.09, MultiPL-E 36.02→48.35, CRUXEval 57.13→58.94. No stage-wise SWE score is given for any SFT step — [Qwen3-Coder-Next, 2026-02-28](https://arxiv.org/html/2603.00729v1).
- Composer 2 links knowledge to agent outcome indirectly: in a study on Qwen3-Coder-30B-A3B at three compute levels, post-SFT cross-entropy loss predicted downstream RL reward — [Composer 2 report, 2026-03](https://arxiv.org/html/2603.24477v2). The company's post says lower pretraining loss improves RL results — [Cursor blog, 2026-03-27](https://cursor.com/blog/composer-2-technical-report).
- Thought traces matter in imitation: 34.4 % with them, 30.4 % without (the same paper also prints 34.2 %) — [R2E-Gym](https://arxiv.org/html/2504.07164v1).
- An earlier "agent" prompt set in this project was single turns with invented tool results (1,100 of 7,150 prompts, 2.5 % of tokens), and the project itself classed it as not agentic — [agentic_data_pipeline.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/agentic_data_pipeline.md).
- Hugging Face fine-tunes that do SFT on session data report no agentic evaluation at all: [empero-ai Qwen3.5-9B-Claude-Code](https://huggingface.co/empero-ai/Qwen3.5-9B-Claude-Code-GGUF) has no evaluation results; [DhruvalLabs Qwen3-8B](https://huggingface.co/DhruvalLabs/qwen3-8b-claude-agentic-fable5) gives only a loss and one example.

### Inferences
- A model trained on prompt→answer learns what good code looks like. It does not learn to read a failing test, pick the next tool, recover from a bad edit, or stop. The 1.8–7.0 % scores of a strong single-turn family are the best indirect evidence for this, though old tool formats may explain part of it.
- For a modern 9B the gap will be smaller, since current bases already work in a loop. Expect SFT's relative gain to be well below the 5× multiples of 2024–25 papers.
- Elixir knowledge is still likely a real limiter for a small model. Single-turn data should stay in the mix as a minority knowledge source, not as the main stage.

### Gaps
- No A/B test found of "single-turn SFT only" against a baseline, scored by agent success. This could be measured directly on the owner's stack.
- No published base score for a 9B Qwen3.5-class model on SWE-bench Verified or any Elixir task was found.

## Q2. Trajectory imitation: results, volume, lengths, and whether the harness must match

### Takeaway
Trajectory SFT is the best-evidenced cheap gain: ~500 trajectories gave +8 to +21 pts (the top figure compares SWE-smith's
28.2 % with SWE-Gym's 7.0 % base), thousands gave more, and the best SFT-only result I found at 32B is 62.4 % on 13k
trajectories from an open-weight teacher. Training on the deployed harness matters: it is standard at the top labs, and
the project's own data shows wrong-profile tool calls failing.

### Cited Findings

| Work (date) | Base | Trajectories | Teacher | Length and context | Result (SWE-bench Verified) |
|---|---|---|---|---|---|
| [SWE-Gym](https://arxiv.org/html/2412.21139v2) (ICML 2025) | Qwen2.5-Coder 7/14/32B | 491 | gpt-4o, Claude 3.5 Sonnet | ~19 turns, ~19k tokens; train 32,768 | 10.6 / 16.4 / 20.6 |
| [R2E-Gym](https://arxiv.org/html/2504.07164v1) (2025-04) | same | 3,321 from 2,048 tasks | Sonnet-3.5, t=0.2 | ≤ 40 steps, 32K; train 20K | 19.0 / 26.8 / 34.4 |
| [SWE-smith](https://arxiv.org/html/2504.21798v2) (2025-04, NeurIPS 2025) | Qwen2.5-Coder 7/32B | 5,016 from 8,686 instances | Claude 3.7 Sonnet, ≤ 75 steps | 75-step limit at test | 15.2 / 40.2 |
| [OpenSWE / daVinci-Env](https://arxiv.org/html/2603.13023v3) (2026-03) | Qwen2.5-32B/72B-Base | ~13,000 from ~9,000 envs | GLM-4.7 | up to 128k per example | 62.4 / 66.0 |
| [SWE-Universe](https://arxiv.org/html/2602.02361v2) (2026-02) | Qwen3-Next-80A3 | 500K (~30B tokens) | Qwen3-Coder-480B | ~60k tokens per trajectory (est.) | 50.3→61+, 2,000 steps |

- Learning curve points: 500 trajectories reached 28.2 % on a 32B — [SWE-smith](https://arxiv.org/html/2504.21798v2). In R2E-Gym the 14B saturated near 800 samples while the 32B kept improving up to 3,200 — [R2E-Gym](https://arxiv.org/html/2504.07164v1). SWE-Gym saw no saturation at 491 — [SWE-Gym](https://arxiv.org/html/2412.21139v2).
- Size gap survives equal data: 7B vs 32B was 15.2 vs 40.2 on SWE-smith and 19.0 vs 34.4 on R2E-Gym — [SWE-smith](https://arxiv.org/html/2504.21798v2), [R2E-Gym](https://arxiv.org/html/2504.07164v1).
- Only successful trajectories were kept, with per-instance caps of 3 (easy, repeatedly solved instances hurt) — [SWE-smith](https://arxiv.org/html/2504.21798v2), and a cap of 2 gave 9.7 % on 62 trajectories vs 9.3 % on 172 uncapped — [SWE-Gym](https://arxiv.org/html/2412.21139v2). OpenSWE samples four attempts per instance at t=1.0 and keeps only instances solved one or two times of four — [OpenSWE](https://arxiv.org/html/2603.13023v3).
- Teacher yield: Claude 3.7 Sonnet solved 36 % of 17,906 attempts — [SWE-smith](https://arxiv.org/html/2504.21798v2).
- On-policy data hurt in a small setting: adding 868 on-policy trajectories to the 491 dropped Lite from 15.3 % to 8.7 % — [SWE-Gym](https://arxiv.org/html/2412.21139v2).
- Repo specialisation works: 700 SymPy trajectories gave 21.2 % vs 13.6 % for the general model; a specialist stage on top of SWE-agent-LM-32B gave 42.4 % vs 33.3 %, with only 22 test instances and minor generalisation loss — [SWE-smith](https://arxiv.org/html/2504.21798v2).
- Performance rises roughly logarithmically with repo count (700 samples from 4, 25, 50 and 100 repos) — [SWE-smith](https://arxiv.org/html/2504.21798v2).
- Devstral (2025-05, Apache-2.0, 46.8 %) was built for OpenHands by Mistral and All Hands; I found no fine-tuning method or data recipe — [OpenHands](https://www.openhands.dev/blog/devstral-a-new-state-of-the-art-open-model-for-coding-agents), [Mistral](https://mistral.ai/fr/news/devstral).
- Nemotron-CORTEXA is not a fine-tune of a coding model on trajectories. It is an agent pipeline with a trained code embedding model and a localization agent, 68.2 % at $3.28 per problem — [NVIDIA](https://research.nvidia.com/labs/adlr/cortexa/). It is not evidence for or against trajectory data.
- Qwen3-Coder (2025-07) launch coverage reports 20,000 parallel environments for agent RL, from secondary sources only — [PromptLayer](https://blog.promptlayer.com/qwen3-coder-480b-a35b-instruct-the-open-source-ai-thats-redefining-code-generation/), [Willison](https://simonwillison.net/2025/Jul/22/qwen3-coder/). Qwen3-Coder-Next is the primary source: teacher trajectories across six scaffolds, execution-verified agent trajectories in SFT, and rule-based filtering of failed or malformed runs — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1).
- Hermes: Nous's batch runner produces trajectories in a ShareGPT-style format with tool statistics — [Nous docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/batch-processing). Lambda's Apache-2.0 traces hold 7,646 Kimi-K2.5 and 7,055 GLM-5.1 samples, avg 24.3 and 19.1 turns, 13.9 and 9.7 tool calls, with no statement of who wrote the prompts and no evaluation — [Lambda](https://huggingface.co/datasets/lambda/hermes-agent-reasoning-traces).
- OpenSWE: 45,320 Docker environments across ~12.8k repos, Python-targeted, gated, with conflicting licence statements (metadata "mixed-permissive-and-cc-by-4.0", card text AGPL-3.0) — [HF card](https://huggingface.co/datasets/GAIR/OpenSWE).
- DataClaw exports Claude Code, Codex, Gemini CLI, OpenCode and OpenClaw sessions to Hugging Face with redaction — [DataClaw](https://github.com/peteromallet/dataclaw). Hub docs warn such traces can contain secrets, private code and personal data — [HF docs](https://huggingface.co/docs/hub/agent-traces).
- Claude-trace fine-tunes exist on small models: Qwen3.5-9B on DataClaw sessions, LoRA r=64, no evaluation — [empero-ai](https://huggingface.co/empero-ai/Qwen3.5-9B-Claude-Code-GGUF); Qwen3-8B on Fable-5-traces, 4,665 rows, 580 steps, QLoRA on an RTX 4000 Ada 20 GB at 8,192 tokens — [DhruvalLabs](https://huggingface.co/DhruvalLabs/qwen3-8b-claude-agentic-fable5).

Harness match:
- Composer 2 trains with the same tools and harness as the deployed model, served by a shadow backend — [Composer 2 report](https://arxiv.org/html/2603.24477v2).
- Cognition retrained on an updated harness in a loop and attributes lower scores in other harnesses partly to more tool-call failures — [Cognition, 2025-10-29](https://cognition.com/blog/swe-1-5).
- Qwen3-Coder-Next takes the other route: 20 tool templates (the text's count is garbled, Table 12 lists 20), with SWE-bench Verified rising as template count rises (no numbers in the text), and 92.7 % average tool-format accuracy across five scaffolds — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1).
- SWE-Gym's training and evaluation both used the OpenHands CodeActAgent, without saying the system prompt was identical — [SWE-Gym](https://arxiv.org/html/2412.21139v2); SWE-smith's teacher and student share SWE-agent's interface — [SWE-smith](https://arxiv.org/html/2504.21798v2).
- Local evidence: in the Elixir pilot 8 of 169 tool calls went to the other profile's tool names — [agentic_data_pipeline.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/agentic_data_pipeline.md). The store's tool-call gain came only from answers using the same tools — [bench/agentic_data README](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agentic_data/README.md).

### Inferences
- The project's run 1 averages 16.0 turns and ~13,100 generated tokens per session (est., from 18,885 turns and 15.4 M tokens over 1,177 sessions), which sits inside published trajectory sizes.
- A 9B should get most of its first gain by 800–1,500 trajectories if the 14B's knee carries over, but base and teacher differ, so a learning curve must be measured.
- Exact harness training is the right default for one deployed agent. A small share of other tool formats (10–20 %) is cheap insurance, because the fix for a small team is simpler than Qwen's 20 templates.
- OpenSWE's jump to 62.4 % mixes more data, a longer context (128k) and a base rather than instruct model. It does not isolate data volume.

### Gaps
- Not found: any controlled test of "same tools, different system prompt". Published work reports matched harnesses or many templates, not the minimum match.
- Devstral's and Qwen3-Coder's actual data recipes are unpublished.
- Whether DataClaw or Fable-5 fine-tunes gain anything in an agent loop is unknown: no card reports it.

## Q3. RL with tests as reward: hardware, steps, minimum scale, consumer GPUs

### Takeaway
Multi-turn RL works, but published runs start around 4,600 H100-hours at 32B scale. The smallest reported gains are +3.6
to +5.8 pts on about 300 samples at 7–14B. Nobody has published multi-turn coding RL on a handful of consumer GPUs. Single-turn
RL with test rewards has been done on an RTX 3090, on very small models, and is the realistic RL entry point.

### Cited Findings

| Run (date) | Model | Tasks | Hardware and steps | Result |
|---|---|---|---|---|
| [DeepSWE](https://www.together.ai/blog/deepswe) (2025-07-02) | Qwen3-32B | ~4.5K R2E-Gym | 64 H100s, 6 days, ~200 steps; batch 64 × 8 = 512 containers per step; 9,180 H100-h per [SkyRL-Agent](https://arxiv.org/html/2511.16108v1) | 23 % → 42.2 % Pass@1, 59 % Best@16 |
| [SA-SWE-32B](https://arxiv.org/html/2511.16108v1) (2025-11) | Qwen3-32B | 4.5K R2E-Gym | 2×8 H100s, 4,601 H100-h, 125 steps; 32K context, 50 turns | 24.4 % → 39.4 % |
| [SkyRL-v0](https://sky.cs.berkeley.edu/project/skyrl/) (2025-05, updated 08) | OpenHands-7B, Qwen3-8B, Qwen3-14B | ~300 samples | not stated on the page; a [third-party summary](https://www.sourcepulse.org/projects/2410687) says 20 h on 8×H200 for the 14B | 11.0→14.6, 3.6→9.4, 18.0→21.6 |
| [SWE-Universe](https://arxiv.org/html/2602.02361v2) (2026-02) | Qwen3-30B-A3B | verifier signal as reward | not stated | Multilingual ~32 % → 42.0 % |
| [Composer 2](https://arxiv.org/html/2603.24477v2) (2026-03) | Kimi K2.5 | CPT + RL | B300s, 3 GPU regions, 4 CPU regions; no counts | CursorBench-3 36.0 → 61.3 (both stages) |
| [SWE-1.5](https://cognition.com/blog/swe-1-5) (2025-10-29) | unnamed open base | hand-built environments | thousands of GB200 chips; called relatively small scale | no before/after |
| [INTELLECT-3](https://www.primeintellect.ai/blog/intellect-3) (2025-12) | GLM-4.5-Air | public Hub environments | 512 H200s, ~2 months incl. ablations | no coding numbers in the text |

- Reward designs: DeepSWE uses a sparse pass/fail reward counted only when the agent deliberately submits, and masks observations — [DeepSWE](https://www.together.ai/blog/deepswe). Composer 2 adds a concave length penalty on a weighted mix of thinking, tool and message tokens, tool calls and turns, pushing easy tasks to be quick and hard tasks to think more — [Composer 2 report](https://arxiv.org/html/2603.24477v2). Qwen adds an unfinished-trajectory penalty, token-level penalties for malformed tool calls, and a git-based blocker against reward hacking; average turns rose from ~50 to ~130 during RL — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1). Cognition's graders combine tests, rubrics and a browser agent, with humans trying to break the graders — [Cognition](https://cognition.com/blog/swe-1-5).
- Algorithm details: GRPO++ uses leave-one-out advantage, no KL loss, no reward std normalisation, length normalisation, and compact filtering — [DeepSWE](https://www.together.ai/blog/deepswe). Composer 2 removes std normalisation and the length-standardisation term, does no overlong masking, and adds KL regularisation with the k1 estimator — [Composer 2 report](https://arxiv.org/html/2603.24477v2). The two recipes disagree on KL and on overlong handling.
- Thinking: non-thinking RL gave limited improvement in DeepSWE — [DeepSWE](https://www.together.ai/blog/deepswe). SkyRL-Agent altered the Qwen3 template to keep prior-turn thinking — [SkyRL-Agent](https://arxiv.org/html/2511.16108v1).
- Context: gains beyond 32K were ≤ 2 % at evaluation; 64K context and 100 steps were used — [DeepSWE](https://www.together.ai/blog/deepswe).
- Task curriculum matters: RL on SWE-smith and SWE-Gym gave limited gains and a high solve-none rate, while R2E-Gym worked best — [DeepSWE](https://www.together.ai/blog/deepswe).
- Infrastructure: Docker's API overloaded at scale, leading to Kubernetes with nodes of ~200 CPU cores and 6 TB NVMe — [DeepSWE](https://www.together.ai/blog/deepswe).
- Frameworks: rLLM holds the DeepSWE recipe — [rLLM](https://github.com/agentica-project/rllm/blob/main/examples/swe/README.md). SkyRL builds on VeRL and OpenHands — [SkyRL](https://sky.cs.berkeley.edu/project/skyrl/). prime-rl targets 1000+ GPUs with FSDP2 and vLLM and connects to Verifiers — [prime-rl](https://github.com/PrimeIntellect-ai/prime-rl). Verifiers v1 splits an environment into taskset, harness and runtime — [Prime Intellect](https://x.com/PrimeIntellect/status/2076447247693402301). Hermes's RL pipeline sits on Tinker-Atropos — [Nous docs](https://hermes-agent.nousresearch.com/docs/user-guide/features/rl-training). OpenEnv is Docker packaged, offers step/reset/state, and is still experimental at spec 0.1 — [OpenEnv](https://github.com/meta-pytorch/OpenEnv). Harbor runs each trial in a sandbox and has verifiers write reward files — [Harbor](https://github.com/harbor-framework/harbor/blob/main/AGENTS.md); it is also the Terminal-Bench 2.0 harness — [VentureBeat](https://venturebeat.com/ai/terminal-bench-2-0-launches-alongside-harbor-a-new-framework-for-testing).

Single-turn vs multi-turn:
- [Skopin and Kotelnikov, 2026-05-28](https://arxiv.org/html/2605.30478v1): trained on an RTX 3090 with LoRA (r=32), TRL, batch 1, 8 samples, 5 epochs, lr 1e-5, 374 MBPP training tasks. Qwen3-0.6B went 0.273 → 0.417; Llama3.2-1B went 0.349 → 0.389. No prior SFT step is described. Static-analysis reward alone gave 0.232–0.253 on the 0.6B, worse than baseline; unit-only and combined rewards were close, and combined did not consistently win on EvalPlus. The authors warn results may not transfer to long-horizon work.
- Qwen3-Coder-Next ran single-turn RL with unit tests from majority voting as one expert model, then distilled the experts into one model — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1).
- Hobby-scale: GRPO on GSM8K with a 0.5B model on 8 GB — [grpo-lab](https://github.com/gian-g3dai/grpo-lab); a write-test-revise loop on Qwen2.5-Coder-1.5B on a Colab A100 for 200 steps, single seed, labelled a reference implementation — [GRPO_implementation](https://github.com/sidd1196/GRPO_implementation); a tutorial with binary test rewards on HumanEval — [nilenso](https://blog.nilenso.com/blog/2026/01/28/reinforcement-learning-with-grpo/).

### Inferences
- Cost per step: 46 H100-h for DeepSWE and 37 for SA-SWE-32B (est., 9,180/200 and 4,601/125).
- A rough scale-down to 5 × RTX 3090 on a 9B with LoRA: dividing by 4 for 16 tasks × 8 rollouts and by 3.5 for model size, and multiplying by 3 for H100 vs 3090 (an assumption, no source), gives ~1.6 h per step, so 60 steps in ~4 days (est., ±2×). A bottom-up guess from generation and update times gives 30–60 min per step. Treat this as 2–5 days for a 60-step trial, with no precedent to confirm it.
- The 8-sample group needs real spread in outcomes, so tasks must be solved sometimes. The solve-none result implies filtering RL tasks by the current model's solve rate.
- Do not use dialyzer or credo as stand-alone rewards. The Ruff-only result shows a static-analysis reward can make correctness worse.
- Composer's length penalty is the piece most aligned with this project's metric. At rig speeds, reasoning tokens are time, and Flint can reason for more than 8,000 tokens in a turn ([bench/agentic_data README](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agentic_data/README.md)).

### Gaps
- No published multi-turn coding RL on consumer GPUs, and none on any model at ≤ 14B with verified hardware. The 20-hour figure for the 14B is third-party and unconfirmed.
- Training step counts, hardware and RL shares are missing for Qwen3-Coder-Next, Composer 2 and SWE-1.5.
- I found no 9B-scale single-turn RL result on code. The 3090 result is at 0.6–1B.
- OpenEnv, Harbor, Verifiers and Atropos were checked from their docs only, not run. Their fit to a Mix sandbox is unverified.

## Q4. Sequencing: is SFT first, then RL, the proven recipe?

### Takeaway
Top labs do pretraining or SFT first, then RL, but none publishes the budget split. A controlled negative exists: DeepSWE's
RL did not improve Sonnet-trained SFT models. SkyRL-v0 has a small positive on an SFT-trained 7B. Treat "SFT then RL" as
common practice, not as proven, and run both arms.

### Cited Findings
- Composer 2 does most compute at 32k, a shorter extension to 256k, a short SFT phase, then large-scale RL — [Composer 2 report](https://arxiv.org/html/2603.24477v2). No CPT/RL split is given in the text I read.
- Qwen3-Coder-Next does mid-training on trillions of tokens, then SFT, then expert models (including single-turn RL and SWE RL), then expert distillation. SFT and RL prompts are kept disjoint. No stage scores are published — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1).
- INTELLECT-3 ran SFT and RL with no split given — [INTELLECT-3](https://www.primeintellect.ai/blog/intellect-3).
- DeepSWE tried RL on four SFT models from Sonnet 3.7/4 trajectories, with and without thinking; none improved after 100 iterations, and those models were slightly weaker than SWE-agent-LM-32B — [DeepSWE](https://www.together.ai/blog/deepswe).
- SA-SWE-32B also reached 39.4 % by pure RL from base — [SkyRL-Agent](https://arxiv.org/html/2511.16108v1).
- Positive small-scale: RL on OpenHands-7B-Agent went 11.0 → 14.6 — [SkyRL](https://sky.cs.berkeley.edu/project/skyrl/).
- SFT alone reached 62.4 % on 32B — [OpenSWE](https://arxiv.org/html/2603.13023v3), well above pure-RL's 42.2 % on a different 32B — [DeepSWE](https://www.together.ai/blog/deepswe). Scaffolds, bases and contexts differ.
- Self-improvement by rejection sampling plateaued or hurt: on-policy addition cut Lite from 15.3 % to 8.7 %, and iterative rejection sampling on MoatlessTools plateaued for the 32B — [SWE-Gym](https://arxiv.org/html/2412.21139v2).

### Inferences
- Data that works for SFT may not work for RL. SWE-smith is strong under SFT and weak under RL per DeepSWE, likely because RL needs tasks at the right difficulty for the current policy, while SFT only needs a teacher that solved them.
- DeepSWE's stall may come from a low-entropy imitator or from Sonnet-style behaviour the student could not follow. This is a guess; the post gives no cause. It is why an RL trial should have a from-base arm as well as a from-SFT arm.
- Since no split is published, a budget share is this note's judgement: for a one-person project, give most of the effort to tasks and evaluation, since both SFT and RL use them, and treat RL as a time-boxed experiment after SFT flattens.

### Gaps
- No public budget share between SFT and RL. The Composer 2 PDF's figures may hold more than the HTML text I read.
- No test of SFT→RL on a small modern model with an open-weight teacher.

## Q5. Bootstrapping an Elixir gym

### Takeaway
The cheapest working route is parser-based bug injection plus commit mining on permissively licensed Hex packages, with
task statements written by an approved writer from the diff and test output. The project already has most of the pipeline.
I found no public SWE-style Elixir dataset, so this has to be built. A first 2,000 tasks is the right order.

### Cited Findings

Construction methods:
- SWE-smith: an agent installs a repo ($0.72 average, ~17 steps) and a human reviews it in 3–20 minutes; 128 repos took ~18 hours, and the whole project cost about $1,360 — [SWE-smith](https://arxiv.org/html/2504.21798v2).

| Bug strategy | Candidates | Yield | Cost per candidate | Resolved at 1,000 instances (7B) |
|---|---|---|---|---|
| Combine patches | 10,092 | 96.9 % | 0.00¢ | not tested |
| LM Modify | 17,887 | 56.0 % | 0.38¢ | 5.7 % |
| Procedural (13 AST transforms) | 15,641 | 40.2 % | 0.00¢ | 8.6 % |
| LM Rewrite | 4,173 | 35.0 % | 3.93¢ | 8.8 % |
| PR Mirror | 2,344 | 33.8 % | 5.53¢ | 9.2 % |

Table source: [SWE-smith](https://arxiv.org/html/2504.21798v2). Harder tasks gave no extra training value (12.4, 10.8, 13.6, 12.2 % across difficulty scores 2–8).

- R2E-Gym builds from commits, not issues, gets ~2.5× more problems than issue-based collection, limits commits to ≤ 5 non-test files, ≤ 100 lines and a 2,000-character patch, and generates tests where commits have none — [R2E-Gym](https://arxiv.org/html/2504.07164v1).
- Issue text: synthetic issues matched real ones at 27.8 % vs 28.0 % — [R2E-Gym](https://arxiv.org/html/2504.07164v1), and 7.7 % vs 7.8 %, with fixed templates worst at 6.4 %. Showing the fail-to-pass test directly leaked the criteria, and the student stopped writing reproduction scripts — [SWE-smith](https://arxiv.org/html/2504.21798v2).
- SWE-Universe splits a PR into test and fix patches and has a building agent write `evaluation.sh`, which must fail on the buggy state and pass on the fixed one; iterative validation raised build success from 82.6 % to 94 %, production non-hacked success was 75.9 %, and an LLM checks in the loop for superficial checks like grep matching — [SWE-Universe](https://arxiv.org/html/2602.02361v2). Its language list does not name Elixir.
- SWE-bench-Live: 1,319 tasks from issues since 2024, 93 repos, each with a Docker image, built by RepoLaunch — [SWE-bench-Live](https://arxiv.org/html/2505.23419v2). The later RepoLaunch paper reports nine languages and ~70 % build success — [RepoLaunch, 2026-03](https://arxiv.org/pdf/2603.05026). I did not read its full text.
- OpenSWE's yield was ~7.9 % of ~572,114 PRs at $19.66 per environment, nearly all GPU cost, with DeepSeek-V3.2 as builder — [OpenSWE](https://arxiv.org/html/2603.13023v3).
- Qwen kept injected bugs only if they failed existing tests and were fixed by reverting the patch — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1).
- SWE-Gym's human-heavy route took ~200 annotation hours, 10,000 CPU core hours and 6 TB of images for 2,438 tasks — [SWE-Gym](https://arxiv.org/html/2412.21139v2).

Elixir availability and licences:
- Hex shows Phoenix MIT ([hex.pm](https://hex.pm/packages/phoenix)), Ecto Apache-2.0 ([hex.pm](https://hex.pm/packages/ecto)), Ash MIT ([hex.pm](https://hex.pm/packages/ash)) and Oban Apache-2.0 ([hex.pm](https://hex.pm/packages/oban)).
- Elixir-specific evidence is thin: [evalcode](https://github.com/rizafahmi/evalcode) is a hand-made Phoenix LiveView evaluation with held-out tests. AutoCodeBench is reported to include Elixir among 20 languages, but I saw only a secondhand blog summary — [blog](https://allanmacgregor.com/posts/why-ai-coding-agents-love-elixir).
- GitHub's terms give other users a licence to public issues and comments through the service (D.5), and separately say content added to a licensed repository falls under that licence (D.6); they do not say that issue text is covered — [GitHub terms](https://docs.github.com/en/site-policy/github-terms/github-terms-of-service).

Reuse from the project ([bench/agentic_data](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agentic_data/README.md), [pipeline note](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/agentic_data_pipeline.md), [data folder](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/data/2026-10-26_agentic_data/README.md)):
- `workspace.py elixir`, `sandbox/ex_tool.exs` single-token mutations found with Elixir's parser (kept when 1–30 % of tests fail), `tasks.py`, `gate.py`, `heldout.py`, `license_scan.py`, the offline Elixir sandbox, and the doc-hash check that stops a fix from editing doctests.
- 41 of 59 stdlib modules make workspaces. The Elixir pilot verified 4 of 7 sessions, stage 1 only 1 of 4, stage 2 on `Version` 3 of 3. Run 1 covered 19 Elixir modules among 1,177 sessions.
- Section 3.2 already lists Elixir at the `v1.18.4` tag, Jason, Decimal, MIME and Earmark Parser as candidates; each needs the owner's download approval.
- Held out already: Livebook, Plausible Analytics, GenStage, the Nimble libraries; and no Exercism track may be a workspace.

### Inferences
- Procedural bugs give 93 % of PR Mirror's training value at zero model cost (8.6 vs 9.2, one ablation on a 7B). That favours extending `ex_tool.exs` from single tokens to SWE-smith-style AST transforms (drop a clause, remove a guard, swap a pipeline step, delete a `with` branch), which also gives multi-line bugs. Combine then makes them harder at almost no cost.
- Commit mining gives real multi-file tasks. Use `git log` over pinned tags, with R2E-Gym's size limits, and keep commits where tests change and fail before and pass after.
- Real issue text should be skipped. It is not clearly under the repository licence, and the evidence says back-translated statements lose nothing. Flint or another approved writer can write statements from diff plus test output. This breaks the current `gate.py tasks` rule that a statement is a filled template, so the gate needs a new statement type, with the same held-out checks. Commit messages and author names should stay out of statements.
- Keep statements free of test code to avoid SWE-smith's leak effect. The current templates name test files, which is fine for fix tasks but differs from "hidden tests" tasks; both types are useful.
- Elixir should build better than the cross-language figures, since Mix and Hex are standard across packages. Packages needing Postgres (Ecto SQL adapters, Oban, much of Ash) need a database in the sandbox, so start with pure-library packages. Elixir compile time is a per-attempt cost, so the image should precompile dependencies and the `_build` tree.
- Counts: 800–1,500 trajectories is the first knee to test, so at 50 % teacher success and a cap of 3 per task about 2,000 tasks is ample, spread over 25–40 packages because repo count pays logarithmically.
- Multi-file tasks from the owner's dataset: wrap each prompt, answer and tests as a Mix project, then group related answers into one project so the fix needs cross-module reading. These stay synthetic, so give them a minority share.

### Gaps
- Whether Hex's top packages' test suites run offline in the sandbox, and how many, is unmeasured. No yield figure exists for Elixir.
- The owner's dataset's provenance is not known to this note and must pass the same "who wrote it" check. Other researchers may cover it.
- Commit messages' licence status was not researched. Hex's own terms were not read.

## Q6. Teacher-generated data: terms, and open-weight teachers

### Takeaway
Claude, OpenAI and Gemini outputs cannot be used to train a model under their terms without permission, so nearly all
academic trajectory data and Claude-trace fine-tunes fail the owner's rule. Open-weight teachers work: OpenSWE reached 62.4 %
with GLM-4.7. Flint, Ornith and Qwen3.6 are already on hand and need no new terms if run locally.

### Cited Findings
- Anthropic Commercial Terms (effective 2025-06-17), D.4: a customer may not access the services to build a competing product, including training competing AI models, unless Anthropic approves. Customers own outputs, subject to compliance — [Anthropic](https://www.anthropic.com/legal/commercial-terms).
- Anthropic Consumer Terms (effective 2025-10-08), section 3: no developing competing products, and no developing or training AI or ML models with the services — [Anthropic](https://www.anthropic.com/legal/consumer-terms).
- Anthropic Usage Policy (page dated effective 2026-11-12, covering Claude Code too): "Use outputs to train an AI model" needs prior authorization, with model scraping and distillation as examples — [Anthropic](https://www.anthropic.com/legal/aup).
- OpenAI Terms of Use (effective 2026-01-01 per search rendering; the page returned HTTP 403 to my fetch): users may not use output to develop models that compete with OpenAI — [OpenAI](https://openai.com/policies/terms-of-use/). Business terms are worded differently, per a third-party record only — [ConductAtlas](https://conductatlas.com/platform/openai/openai-business-terms/provision/CA-P-059973/prohibition-on-using-output-to-develop-competing-ai-models/).
- Google Gemini API terms (effective 2026-03-23): no using the services to develop models that compete with them, and no reverse engineering or replicating the services — [Google](https://aistudio.google.com/docs/terms).
- Data affected: SWE-Gym used gpt-4o and Claude 3.5 Sonnet — [SWE-Gym](https://arxiv.org/html/2412.21139v2). R2E-Gym used Sonnet-3.5 — [R2E-Gym](https://arxiv.org/html/2504.07164v1). SWE-smith used Claude 3.7 Sonnet as teacher, o3-mini for bugs and Claude 3.5 Sonnet for installs — [SWE-smith](https://arxiv.org/html/2504.21798v2). DataClaw and Fable-5 sets are Claude or Codex sessions — [DataClaw](https://github.com/peteromallet/dataclaw), [Parable](https://huggingface.co/AnkitAI/Parable-Qwen3-8B-Claude-Fable-5-GGUF). The fine-tune cards list Apache-2.0 and carry no terms caveat — [empero-ai](https://huggingface.co/empero-ai/Qwen3.5-9B-Claude-Code-GGUF).
- Open teachers that worked: GLM-4.7 for OpenSWE — [OpenSWE](https://arxiv.org/html/2603.13023v3); Qwen's own 480B — [SWE-Universe](https://arxiv.org/html/2602.02361v2); Kimi-K2.5 and GLM-5.1 for Lambda's traces — [Lambda](https://huggingface.co/datasets/lambda/hermes-agent-reasoning-traces).
- Licences of models on hand: Flint Apache-2.0 ([model page](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/models/flint/README.md)), Ornith-1.5 MIT ([model page](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/models/ornith-1.5-122b/README.md)), Qwen3.6-35B-A3B Apache-2.0 ([model page](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/models/qwen3.6-35b-a3b/README.md)).
- Others, from secondary round-ups only: GLM-5.1 and DeepSeek V4 MIT, Kimi K2.6 modified MIT with an attribution clause for very large deployments, Kimi K3 a custom licence — [Faros](https://www.faros.ai/blog/open-weight-models), [Wavect](https://wavect.io/blog/open-weight-llm-comparison-2026/), [Morph](https://www.morphllm.com/best-open-source-coding-model-2026).

### Inferences
- The rule is simple: run an open-weight teacher on own hardware. Using a hosted API for an open model brings in that host's terms, which must then be read.
- Back-translation and bug writing count as teacher use too, so SWE-smith's and OpenSWE's task text is not automatically clean. SWE-smith's fails (o3-mini and Claude). OpenSWE's teacher models pass, but its licence statements conflict and its repos are mixed, including GPL.
- Lambda's traces pass on teachers but fail the owner's "who wrote the prompt" question until proved otherwise. "ShareGPT-style" there names a file format only, not ShareGPT data, but the prompts' source is unstated, so keep them out.
- Teacher strength matters less than task yield, since rejection sampling keeps only passes. Qwen3.6-35B-A3B or Ornith as teachers should be tested on 50 Elixir tasks; Flint's stage-2 result (3 of 3) is encouraging on a tiny sample.
- These are readings of published terms, not legal advice. Named approval from a provider would change the answer, and the owner's rule is stricter than the terms anyway.

### Gaps
- OpenAI's current page could not be opened directly; its effective date and wording come from search rendering.
- Hosted terms for GLM, Kimi, DeepSeek and Qwen APIs were not read, and I found no licence text speaking directly to training on outputs. Primary licence files for those models were not opened.

## Q7. Training mechanics for trajectories

### Takeaway
Train the student on the exact rendered token sequence, with loss only on generated spans, thinking kept, and long sessions
bucketed or capped at 16–32k. The project's session format already records `gen_ranges`, which is the mask. A 9B cannot
do full-weight training on one 24 GB card, so QLoRA is the default.

### Cited Findings
- Masking: DeepSWE masks observations from the loss — [DeepSWE](https://www.together.ai/blog/deepswe). OpenSWE uses multi-turn action masking in a modified slime — [OpenSWE](https://arxiv.org/html/2603.13023v3). Contrast: SWE-Universe's mid-training used 500K trajectories with no loss mask — [SWE-Universe](https://arxiv.org/html/2602.02361v2). Qwen3-Coder-Next masks highly repetitive segments and padding — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1).
- Context used for training: 8,192 on a 20 GB card (QLoRA, 8B, batch 2 × 8 accumulation) — [DhruvalLabs](https://huggingface.co/DhruvalLabs/qwen3-8b-claude-agentic-fable5); 20K — [R2E-Gym](https://arxiv.org/html/2504.07164v1); 32,768 on 2–8 H100s, full fine-tune, batch 8, lr 1e-4, up to 5 epochs — [SWE-Gym](https://arxiv.org/html/2412.21139v2); 32K with 50 turns for RL — [SkyRL-Agent](https://arxiv.org/html/2511.16108v1); up to 128k, batch 128, 5 epochs, lr 1e-5→1e-6 — [OpenSWE](https://arxiv.org/html/2603.13023v3); 32k raised to 262,144 in mid-training — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1). R2E-Gym used 2 epochs, batch 8, lr 1e-5 — [R2E-Gym](https://arxiv.org/html/2504.07164v1).
- Long-trajectory handling: compact filtering masks trajectories that hit context, step or time limits — [DeepSWE](https://www.together.ai/blog/deepswe); Composer 2 skips overlong masking and uses self-summarization, reporting lower error with fewer tokens — [Composer 2 report](https://arxiv.org/html/2603.24477v2); best-fit packing splits long documents into context-sized chunks — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1).
- Reasoning: keeping thoughts gave 34.4 vs 30.4 — [R2E-Gym](https://arxiv.org/html/2504.07164v1). Emergent DeepSWE behaviour was ~2K thinking tokens at localization and fix planning, and 100–200 at simple steps — [DeepSWE](https://www.together.ai/blog/deepswe).
- Axolotl has `roles_to_train` and `train_on_eos` in a published config — [example](https://huggingface.co/Edens-Gate/control-12b-r1-lora). I found no authoritative text on `tool` or `reasoning_content` masking; a third-party library describes the per-token assistant mask needed — [chat-bricks](https://chat-bricks.readthedocs.io/).
- Project facts: session files record exact ids and `gen_ranges`; `data/tokens.jsonl` ships ids and generated spans; a session is one append-only token sequence; tool outputs are cut at 20,000 characters (60 % head, 40 % tail); pi sends `reasoning_content` back in the history — [bench/agentic_data](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agentic_data/README.md), [pipeline note](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/agentic_data_pipeline.md), [agent_check](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agent_check/README.md).
- `train.py` still needs the "train only inside `gen_ranges`" change — [pipeline note](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/agentic_data_pipeline.md).

### Inferences
- Recipe: labels = token ids inside `gen_ranges`, everything else −100. This sidesteps template-parsing bugs, since the mask comes from generation. It covers tool-call tokens and reasoning.
- VRAM (est.): 9B at BF16 is ~18 GB of weights, so full-weight Adam (weights + gradients + two moments) needs ~72 GB, which rules out one 24 GB RTX 3090. With 4-bit weights (~5–6 GB), LoRA and gradient checkpointing, 32k tokens at batch 1 should fit in 24 GB, but this needs a test. The 8B at 8,192 on 20 GB is the only consumer data point.
- Five 3090s at batch 1 each is a small effective batch. Use accumulation to 8–16, matching published batch 8. Only LoRA gradients cross the bus, which suits cards without P2P.
- Length plan: rank sessions by length, bucket to reduce padding, cap at 32k, and for longer sessions cut at a turn boundary, keeping the system prompt and task and dropping old tool results' bodies (replace with a short marker). Do not cut inside a turn. A dropped result changes what the student sees, so mark such examples and compare with a run without them.
- Tool output handling should match deployment: a different cut in training teaches a different context. Check pi's output limit and use the same one in the data loop.
- Thinking should match what the deployed template sends. Since pi keeps reasoning in history, keep it in training context as well.
- Masking choice: use assistant-only loss for the agent stage. A separate no-mask pass over Hex code and test output could serve as a knowledge stage, following SWE-Universe, at low priority.
- To favour time per task, prefer the shorter of a task's successful sessions under the cap. It is a cheap imitation of Composer's length penalty.

### Gaps
- No published VRAM measurements for training 9B-class models at 16–32k on 24 GB cards.
- No study compares dropping old tool results against keeping them during training, or evaluates sliding-window training on agent success.
- Axolotl's and Unsloth's current tool-role behaviour was not verified from primary docs. Label inspection on real sessions is required.

## Q8. Eval design: proving a tuned 9B beats a bigger model on Elixir

### Takeaway
Extend `bench/agent_check` with a held-out, repo-level Elixir task set. Report success per task and successes per rig-hour
at a time cap, with paired comparisons. "Beats" should mean more verified tasks per hour on the rig, since equal-data
papers show size wins on raw Pass@1.

### Cited Findings
- `agent_check` already gives: fresh workspaces, pi headless, hidden tests, runaway caps, infrastructure re-runs, the proxy, replay, per-turn time to first token, per-attempt CSVs, oracle and empty-change validation of every task, and `paired_tasks.py` with margins and gates — [README](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agent_check/README.md).
- Its success rule: hidden tests pass and the visible test file is unchanged. Its release set is 12 bug fixes in 5–10 tool calls; the larger set is 82 Exercism tasks — [README](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/bench/agent_check/README.md).
- Contamination controls in the literature: SWE-Gym repos are separate from SWE-bench repos — [SWE-Gym](https://arxiv.org/html/2412.21139v2); DeepSWE filtered repos that overlap the test set — [DeepSWE](https://www.together.ai/blog/deepswe); R2E-Gym-Subset has no overlap — [R2E-Gym](https://arxiv.org/html/2504.07164v1); SFT and RL prompts disjoint — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1). SWE-bench-Live uses only issues since 2024 — [SWE-bench-Live](https://arxiv.org/html/2505.23419v2). Pretraining cut-offs are real: Qwen3-Coder-Next's corpus ran to 2025-09-30 — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1).
- Grader false positives are a real risk: Cognition found test gaps by having experts attack graders — [Cognition](https://cognition.com/blog/swe-1-5); Qwen needed a reward-hacking blocker — [Qwen3-Coder-Next](https://arxiv.org/html/2603.00729v1); SWE-Universe flags superficial verifiers — [SWE-Universe](https://arxiv.org/html/2602.02361v2).
- Hard benchmarks use terse real prompts with multi-file solutions — [Cursor](https://cursor.com/blog/composer-2-technical-report).
- Static analysis alone is a poor signal for correctness — [Skopin and Kotelnikov](https://arxiv.org/html/2605.30478v1).
- Exercism's Elixir track is MIT — [GitHub](https://github.com/exercism/elixir), and Exercism is already held out from workspaces — [pipeline note](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/v3/docs/research/notes/agentic_data_pipeline.md).

### Inferences
- Three lanes: (a) Exercism Elixir, ~40 tasks, a quick smoke check; (b) held-out repo tasks, the headline, with 60–80 tasks from 6–10 repos never in training (the project's list: Livebook, GenStage, the Nimble libraries, plus Plausible after checking its licence); (c) a few larger, Phoenix-style tasks, using `evalcode`'s idea, reported apart.
- Time split: held-out repos should use commits newer than both models' cut-offs, because a base model may have seen older Phoenix or Ecto code in pretraining. Repo holdout alone cannot catch that.
- Sample size (est.): if 30 % of pairs disagree, detecting 10 pts at 80 % power needs ~230 paired attempts, and 15 pts needs ~100. So 80 tasks × 3 attempts covers 10 pts, using a task-level bootstrap because attempts cluster.
- Score: primary is hidden `mix test` pass with tests unchanged. Secondary, reported apart and never as the pass rule: `mix compile --warnings-as-errors`, `mix format --check-formatted`, `mix credo --strict`, and `mix dialyzer`, all as "no new findings against the pre-task baseline", because many repos start with warnings. Precompute dialyzer's PLT in the task image, since building it per attempt would swamp timing.
- Measures per arm: Pass@1, minutes per task, minutes per success, successes per rig-hour with a fixed cap, turns, TTFT per turn, malformed and failed tool calls, runaways. Keep Best@K out, since the rig cannot afford it.
- Decision rule for "beats": set before running. Suggested: tuned 9B has more successes per rig-hour than the bigger model, with a 95 % interval above 1.0, and Pass@1 no worse than a stated margin. A smaller model may also win on context left over and on prompt speed, but that is an engine claim to measure, not assume.
- Compare three arms, not two: base 9B, tuned 9B, bigger model. Without the base arm any win could be size or speed, not training.
- Validate each task as `validate.py` does (oracle passes, empty change fails), and add a stricter step: a trivial stub attempt must fail, and a human or a second writer tries to game a sample of tasks.
- Rig rule: runs happen on the rig only in a quiet window, and quant-machine times are not speed results, per project rules.

### Gaps
- No public Elixir SWE-style benchmark to anchor against, so results are internal until the set is published.
- Dialyzer and credo run costs on Hex repos in the sandbox are unmeasured.
- The bigger comparison model and its cut-off are not named in the assignment.

## Q9. Decision comparison: SFT, trajectory imitation, RL

### Takeaway
On cost per unit of agentic gain, trajectory imitation from an open-weight teacher comes first, single-turn RL on the
owner's dataset second, and multi-turn RL last. All three rest on the same two assets, an Elixir task set and an Elixir evaluation.

### Cited Findings

| | Prompt→answer SFT | Trajectory imitation | Single-turn RL (tests) | Multi-turn RL (tests) |
|---|---|---|---|---|
| Teaches | knowledge, style | tool use, loop, recovery, when to stop | correctness, test-driven code | whole-task behaviour, efficiency, new strategies |
| Evidence inside a tool loop | none direct | strong: +8 to +21 pts at ~500 ([SWE-Gym](https://arxiv.org/html/2412.21139v2), [SWE-smith](https://arxiv.org/html/2504.21798v2)) | none direct; used as one expert at Qwen ([report](https://arxiv.org/html/2603.00729v1)) | strong: +15 to +19 pts at 32B ([DeepSWE](https://www.together.ai/blog/deepswe), [SkyRL-Agent](https://arxiv.org/html/2511.16108v1)) |
| Data for a first gain | owner's set | 500 trajectories, knee ~800 for 14B ([R2E-Gym](https://arxiv.org/html/2504.07164v1)) | 374 tasks, 8 samples each ([paper](https://arxiv.org/html/2605.30478v1)) | ~300 samples gave +3.6 to +5.8 at 7–14B ([SkyRL](https://sky.cs.berkeley.edu/project/skyrl/)) |
| Data at full scale | trillions of tokens at labs | 5k–13k trajectories; 500K at Qwen | not published | 4.5K tasks, ~64–100k rollouts (est.) |
| Published compute | not given for agent use | 2–8 H100s ([SWE-Gym](https://arxiv.org/html/2412.21139v2)); QLoRA on one 20 GB card ([card](https://huggingface.co/DhruvalLabs/qwen3-8b-claude-agentic-fable5)) | one RTX 3090 at 0.6–1B ([paper](https://arxiv.org/html/2605.30478v1)) | 4,601–9,180 H100-h ([SkyRL-Agent](https://arxiv.org/html/2511.16108v1)) |
| Data generation cost | none, already made | SWE-smith $1,360 for tasks ([paper](https://arxiv.org/html/2504.21798v2)); teacher runs on own GPUs | same tasks | sandboxes at 512 per step ([DeepSWE](https://www.together.ai/blog/deepswe)) |
| On 5 × 3090 at 9B (est.) | hours | sampling ~30–45 h for 2,000 kept, training hours to a day | 1–3 days | 2–5 days for 60 steps, 1–2 weeks for 125; no precedent |
| Main risk | no agentic effect | teacher style, Elixir yield | short-task overfit | stall, solve-none, infrastructure |

### Inferences
- The sampling estimate uses run 1's ~130 sessions per hour (1,177 sessions in ~9 h) and a 36–50 % keep rate, giving 4,000–5,600 attempts. Elixir compile times will lower that rate.
- The training estimate assumes ~30k tokens per session, 3 epochs and 5–15k tokens/s across five cards under QLoRA. That rate is an unsourced guess.
- The answer to the owner's question: prepare agentic data, and keep the existing dataset. Do not spend the next block of GPU time on more prompt→answer SFT.

### Gaps
- A cost per point cannot be given for any method on a 9B, because no such study exists.
- Consumer-card training throughput for trajectory SFT is unmeasured.

## Q10. Recommendation: what to build first and how much data each stage needs

### Takeaway
Build the Elixir evaluation first, then a task factory, then trajectory SFT with a measured learning curve. Add single-turn
RL on the owner's dataset, and run multi-turn RL only as a gated trial. Every stage reuses `bench/agent_check` and `bench/agentic_data`.

### Cited Findings
- Facts behind each stage are cited in Q2–Q8. Stage sizes below follow the SWE-smith yields and repo-count finding ([SWE-smith](https://arxiv.org/html/2504.21798v2)), the 14B knee at ~800 ([R2E-Gym](https://arxiv.org/html/2504.07164v1)), the OpenSWE solved-1-or-2-of-4 filter ([OpenSWE](https://arxiv.org/html/2603.13023v3)), and the single-turn setup ([paper](https://arxiv.org/html/2605.30478v1)).
- Project rules that apply: downloads need the owner's OK, and machine work goes through the project's queue, per project rules.

### Inferences

| Stage | Build | Data | Compute (est.) | Exit test |
|---|---|---|---|---|
| 0. Evaluation | Elixir lane in `agent_check`: pi, hidden `mix test`, three lanes from Q8, base 9B and bigger model baselines | 60–80 held-out repo tasks + ~40 Exercism | days of bench work, ~1–2 days GPU | baseline table; all tasks validated |
| 1. Task factory | extend `ex_tool.exs` to AST transforms; `tasks.py` for package tests and commit mining; back-translated statements in `gate.py`; approve 25–40 packages | 200 pilot, then ~2,000 tasks | CPU mostly | ≥ 1,500 tasks pass the gates |
| 2. Teacher trial | Qwen3.6-35B-A3B, Ornith, Flint on 50 tasks with the `pi` tool profile, 4 attempts each | 200 attempts | 1 day | pick teacher; mid-difficulty share known |
| 3. Trajectory SFT | loss on `gen_ranges`, QLoRA, cap 2–3 per task, keep tasks solved 1–2 of 4 | 500 → 1,000 → 2,000 kept sessions | 30–45 h sampling, hours per training | Pass@1 and minutes per success on lane (b), base vs tuned |
| 4. Single-turn RL | GRPO or GSPO with `mix test` reward on the owner's set; arm with a static penalty only as a side term | 400–2,000 tasks, 8 samples | 1–3 days | gain on lane (b), not just single-turn |
| 5. Multi-turn RL trial | from-SFT and from-base arms; pass/fail on explicit finish; second arm adds Composer's length penalty; filtered tasks | 300–500 tasks solved 10–70 %; 16 tasks × 8 rollouts | 2–5 days per arm for 60 steps | continue only if lane (b) gains ≥ ~3 pts or time per success drops clearly |
| 6. Specialist pass | SWE-smith-style stage on top: Phoenix or Ecto trajectories | ~700 sessions | hours | gain on those repos without loss elsewhere |

- Start with Stage 0. It is the only stage that cannot be skipped, and it can reveal that a base 9B is already competitive, or that Elixir syntax is the true limiter, which would change the plan.
- Framework choice: keep the project's own loop and sandbox for data, because the provenance chain depends on it. For Stage 5, try rLLM or SkyRL with the sandbox behind them, instead of adopting a new environment standard.
- Plain Docker should do for Stage 5, with one container per attempt and `--cpu-shares 256`: 128 containers per step is a quarter of DeepSWE's 512, the scale at which its Docker setup needed Kubernetes. This is untested here.
- Publication fits the owner's rule: Flint or another open teacher, Hex code under per-file scan, statements by an approved writer, and session gates. Open items for the owner: the teacher list, package approvals, and whether Ornith's or Qwen3.6's outputs go on the writer list in `sources.json`.
- New ideas here that need registry and queue rows under the project's rule: Elixir lane in `agent_check`; AST bug transforms for Elixir; commit-mined Hex tasks; back-translated statements and their gate; `gen_ranges` loss for SFT; 9B QLoRA VRAM probe at 16k/32k; teacher trial; single-turn RL on the owner's set; multi-turn RL trial with base and SFT arms; length-penalty reward; specialist pass; dialyzer and credo secondary scoring.

### Gaps
- The owner's dataset size, language share and provenance were not available to this note, so Stage 4's numbers are a range.
- The stage exit thresholds are judgement calls, not published standards.
- Whether a 9B can beat a larger model at equal Pass@1 is unknown. Published equal-data pairs favour size, so the likely win is in successes per hour, and only if the speed gap on the rig holds.
