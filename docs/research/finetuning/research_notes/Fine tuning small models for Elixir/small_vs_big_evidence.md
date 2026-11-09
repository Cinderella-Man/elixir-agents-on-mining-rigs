# Can fine-tuning make a small open model (5–15B) beat much larger ones (35B–1T+) at a narrow task? State of the evidence, November 2026

Evidence grades used on every bullet:
- **[A]** independent or peer-reviewed measurement, or a third-party run with error bars
- **[B]** academic preprint, own harness, open weights, reproducible in principle
- **[C]** vendor self-report (model card, launch post, vendor blog); no independent replication
- **[D]** secondary or aggregator source; primary not reached
- **[H]** older than 18 months (before May 2025): historical, read accordingly

All page contents were read through a fetch tool that summarises pages, so a number can carry a transcription slip. Papers whose fetch flagged an internal inconsistency say so.

## What is actually established: (a) won, (b) matched, (c) failed, and the bottom line for specialising a 9B model for Elixir

### Takeaway
Small tuned models demonstrably beat big general models at classification, extraction, tool routing and code completion. Nothing published shows a 5–15B tuned model beating a contemporary 35B+ model on agentic coding success. Published tuning of a 9B closes roughly 16–42 % of the gap to current open giants on hard agentic benchmarks, and the biggest jumps ever reported came from bases that could not run a tool loop at all, which is not true of a modern 9B. For Elixir the realistic win is speed, cost, privacy, completion or edit prediction, and Elixir idiom on easy-to-medium tasks, not raw task success on hard work. Language-specific tuning for agentic coding has not been measured by anyone.

### Cited Findings

**(a) Narrow tasks where a tuned small model beat a bigger general one**
- Across 310 fine-tunes of 10 bases on 31 tasks, 224 beat GPT-4, with the clearest wins on classification-style tasks near 90 % accuracy; GPT-4 kept the lead on broader tasks. Apr 2024. [B][H] — [LoRA Land PDF](https://arxiv.org/pdf/2405.00732); [abstract](https://arxiv.org/abs/2405.00732)
- Fine-tuned BERT-class classifiers significantly beat zero-shot GPT-4; FinBERT-class models beat zero-shot GPT-3.5/4 on financial sentiment. 2024. Both compare against unassisted zero-shot prompts, which understates a well-prompted GPT-4. [B][H] — [Bucher](https://arxiv.org/pdf/2406.08660); [Lefort et al.](https://arxiv.org/pdf/2409.11408)
- FunctionGemma (about 270M params): base 58 % to fine-tuned 85 % on the held-out Mobile Actions set, Dec 18 2025. Google itself routes complex tasks to larger models such as Gemma 3 27B. [C] — [Google blog](https://blog.google/technology/developers/functiongemma/); [model card](https://ai.google.dev/gemma/docs/functiongemma/model_card?hl=en)
- Llama 3.2 1B tuned for structured e-commerce intent reached 99 % exact match, on par with GPT-4.1 (Oct 2025). [B] — [arXiv 2510.21970](https://arxiv.org/pdf/2510.21970)
- Code completion: JetBrains Mellum 4B beat larger open baselines on JetBrains' own JetComplete suite (KK 0.69 vs DeepSeek-Coder-5.7B 0.62, CodeLlama-7B 0.54, Seed-Coder-8B 0.45, Qwen2.5-Coder-7B 0.19), Oct 2025. The suite is the vendor's own and is task-aligned. [C] — [Mellum paper](https://arxiv.org/html/2510.05788v1)
- IBM: Llama-3.1-8B and Granite-8B tuned on semantic scopes of two private repos beat out-of-box Qwen2.5-72B and RAG on completion, and were reported better than uncustomised models about 10× larger (Feb 2026). Metric is Levenshtein distance, the lift is largely conciseness, and parts of the tables were garbled in the fetched page. [B] — [IBM paper](https://arxiv.org/html/2602.05780v1)
- Org-specific T5-small (~60M) matched generic T5-large (~750M) on exact match; 64 % of 136 developers saw a significant gain. Mar 2025. [B][H] — [Giagnorio et al.](https://arxiv.org/html/2503.14201v1)

**(a′) Agentic coding wins, all against stale or weak large models**
- Nemotron-Terminal-14B (20.2 ± 2.7) beat GPT-OSS 120B (18.7 ± 2.7) and Nemotron-Terminal-32B (27.4 ± 2.4) beat Qwen3-Coder 480B (23.9 ± 2.8) on Terminal-Bench 2.0. Error bars overlap, and GPT-5 (35.2) and GPT-5.1 (47.6) stayed well ahead. Feb 2026. [B] — [NVIDIA paper](https://arxiv.org/html/2602.21193)
- Tmax-9B (27.2) beat GPT-OSS 120B (18.7) on TB 2.0 and sits near Claude Haiku 4.5 (29.8), June 2026. It remained far below GLM 5 at 52.4 and Kimi K2.5 at 43.2. [B] — [Tmax paper](https://arxiv.org/html/2606.23321)
- Self-reported, Ornith-1.5-9B scores 47.5 on SWE-bench Pro, level with the 550B Nemotron 3 Ultra (46.4 to 49.66) and near 1T Kimi K2.5 (50.7). Different harnesses, and these big models are older. [C] — [Ornith repo](https://github.com/deepreinforce-ai/Ornith-1); [SWE Pro listing](https://benchmarklist.com/benchmarks/swe_bench_pro/)

**(b) Matched a bigger model at lower cost**
- A fine-tuned Qwen2.5-Coder-7B reached 43.0 % semantic correctness on postcondition generation vs GPT-4o 44.0 % (base 12.5 %), July 2025. A narrow, single-output code task. [B] — [Breaking the Myth](https://arxiv.org/html/2507.10182)
- OpenPipe: Axis cut per-token cost by over 95 % vs GPT-4-Turbo and said tuned models sometimes outperform it; an early classifier reached 95 % of GPT-4's performance at 50× lower cost. No accuracy data published. [C][D][H] — [Axis case study mirror](https://www.plushcap.com/content/openpipe/blog/openpipe-axis-case-study); [YC page](https://ycombinator.com/companies/openpipe)
- The distillation business case itself decayed: frontier prices fell and open models improved, so the savings shrank and OpenPipe moved towards RL for agents (Oct 2025). [D] — [FlowHunt summary](https://www.flowhunt.io/blog/why-reinforcement-learning-won-ai-model-fine-tuning/); [Latent Space wiki](https://latent.space/wiki/openpipe-cf55dcb1/)
- Composer 2.5 scored 62 on Artificial Analysis's Coding Agent Index vs Opus 4.7 max at 66, at $0.07 vs $4.10 per task (May 20 2026). This is the best independent "match at far lower cost" in coding, but on a 1T base and at Cursor's chosen pricing. [A] — [Artificial Analysis](https://artificialanalysis.ai/articles/cursor-composer-2-5-coding-agent-index)

**(c) Failed**
- Django case study (Aug 2026): six task-specific tunes of Qwen2.5-Coder 7B/32B all improved their trained task, but 13 of 18 cross-task checks degraded. The 7B completion tune collapsed on generation, 52.92 to 19.77. Public SWE-bench checkpoints degraded in 18 of 28 out-of-domain checks. [B] — [Shibaev et al.](https://arxiv.org/html/2608.13566v1)
- Tencent: tuning on proprietary C++ cut general HumanEval pass@1 from 44.72 to 33.95 on average (May 2025). [A, FSE Companion] — [RAG or Fine-tuning?](https://arxiv.org/html/2505.15179v1)
- Tmax: SFT reduced Qwen 3.5 9B on TB Lite (41.9 to 35.5); Tmax-27B dropped on TB Lite (70.8 to 68.6); Qwen 3 8B on TB 2.1 was flat (6.0 to 5.2). Gains shrank at smaller sizes, which the authors put down to limited capacity. [B] — [Tmax paper](https://arxiv.org/html/2606.23321)
- JetBrains' team expected a per-language specialist to beat a multilingual model on its own language. It did not, and they shipped one model for all languages (Aug 2026, first-hand engineer account, completion only). [C] — [Worth Accepting](https://evalovernite.substack.com/p/worth-accepting-mellum)
- Coding-dedicated Mellum2.1 (12B total, 2.5B active) scores SWE-bench Pro 28 and TB 2.1 17.4, below general Qwen3.5-9B at SWE Pro 32.0 (Oct 2026). Active parameter count differs, so this is suggestive only. [C] — [BenchLM card mirror](https://benchlm.ai/models/mellum2-1-12b-a2-5b-thinking); [SWE Pro listing](https://benchmarklist.com/benchmarks/swe_bench_pro/)

### Inferences
- The pattern is consistent across the three bins. Tuning wins where success means emitting the right output shape from a bounded input. It loses where success means sustained problem solving against an unseen state.
- A narrow-task win claimed against "zero-shot GPT-4" is weak evidence. Almost none of these comparisons used a prompt, context file or retrieval on the big model.
- Bottom line for the decision: expect a good Elixir tune of a 9B to be useful on easy-to-medium Elixir tasks and much better at idiom, tool discipline and formatting. Do not expect it to out-solve 27B+ current models on hard ones. A context file and retrieval should be measured first because they are nearly free. The tune is worth doing only if a held-out Elixir suite shows a win against a 27–35B model plus context, on time per solved task.

### Gaps
- No published Elixir-specialised model or Elixir agentic benchmark exists that I could find; the closest are single-shot AutoCodeBench, a [worked Phoenix LiveView example](https://github.com/rizafahmi/evalcode) and [Ash's eval tool](https://github.com/ash-project/evals).
- No study compares a tuned small model head-to-head against a big model plus good context on the same agentic tasks.
- Could not reach primary figures for Hermes or Distil-style vendors, and found no shared-benchmark numbers for [Salesforce xLAM](https://huggingface.co/Salesforce/xLAM-7b-fc-r/blob/1f3311c47f8f1d6618aa4c1b2c156b510c199985/README.md) (card cites a BFCL run from July 2024). The often-repeated "$23,000 to $19" OpenPipe recipe figure could not be traced, so it is left out.

## What is the mechanism by which a small tuned model wins, and which capabilities does tuning not add?

### Takeaway
Tuning adds output format, tool-loop discipline, task-shape habits, domain and repo facts, and persistence through longer rollouts. It does not reliably add general problem solving, long-horizon planning or use of more context, though RL on a 9B did raise some reasoning-flavoured scores, so "adds no reasoning" is too strong.

### Cited Findings

**What tuning adds**
- Tool-loop discipline is the largest single effect. On Django method generation, base Qwen2.5-Coder-7B scored 0.0 once wrapped in a 10-step agent scaffold vs 52.92 without it; agent-tuned SWE-agent-LM-7B scored 24.51 in the same scaffold. [B] — [Shibaev et al.](https://arxiv.org/html/2608.13566v1)
- The same effect explains giant SWE-bench jumps: Qwen2.5-Coder-7B 1.0 to 52.7, 14B 4.0 to 60.8, 32B 6.2 to 62.2 (May 2026 revision). [B] — [SWE-Hero](https://arxiv.org/html/2604.01496v2)
- Qwen3-8B 7.6 to 42.2 and Qwen3-32B 23.2 to 52.6 on SWE-bench Verified, hack-free; dataset choice gave the largest part of the gain. Jan 2026. [B] — [SWE-Lego](https://arxiv.org/html/2601.01426v2)
- Format and stopping: IBM's lift on public sets was mainly dropping excess output (Granite on RepoBench, Full distance 4,138 to 9). [B] — [IBM paper](https://arxiv.org/html/2602.05780v1)
- Domain and repo knowledge: tuning on 120K Tencent C++ files lifted average exact match from 24.79 to 44.20. [A] — [RAG or Fine-tuning?](https://arxiv.org/html/2505.15179v1)
- Reasoning traces in the data can carry over on narrow tasks: traces gave 2.5–6× the performance of plain SFT on postcondition generation. [B] — [Breaking the Myth](https://arxiv.org/html/2507.10182)
- RL teaches persistence: Tmax-9B training raised steps per episode and assistant-turn length. AIME in its terminal harness rose 73.3 to 91.1, a counter-example to "tuning adds no reasoning", though the harness can use tools. [B] — [Tmax paper](https://arxiv.org/html/2606.23321)
- RL reshapes product behaviour: Cursor Tab shows 21 % fewer suggestions at 28 % higher accept rate. [C] — [Cursor](https://cursor.com/blog/tab-rl)

**What tuning does not add (or adds little of)**
- General problem solving: tuned SWE-bench checkpoints moved LiveCodeBench between −8.5 and +2.1 points, mostly down. [B] — [Shibaev et al.](https://arxiv.org/html/2608.13566v1)
- Long horizon: on whole-repo generation, DeNovoSWE reports issue-level data gives "useful but limited transfer"; SFT of an already agentic Qwen3.5-35B-A3B added only 43.8 to 50.0 (Doc2Repo), vs GPT-5.4 CodeX at 61.7. [B] — [DeNovoSWE](https://arxiv.org/html/2606.10728)
- Use of more context: extending Nemotron-Terminal to 65,536 tokens brought no significant gain. [B] — [NVIDIA paper](https://arxiv.org/html/2602.21193)
- Implementation skill is the wall on real tasks: near-miss failures came from design and wiring, not missing facts, and the real AGENTS.md never turned a near miss into a pass (36 cells; Sonnet 4.6, GPT-5.5; 2026). [B] — [Khatri](https://arxiv.org/html/2607.27250v1)
- Even at 2.8T, RL buys little on hard problems: SWE-2 27.3 % vs base Kimi K3 21.5 % on Terminal-Bench 4, far below Fable 5.1 at 55.8 and GPT-6 Astra at 57.9. Vendor numbers via a secondary source. [C][D] — [mer.vin](https://mer.vin/news/cognition-swe-2-cheaper-but-it-lags-on-terminal-bench-4/)
- Composer 2's authors concede a likely size deficit against proprietary models and that coherence and intelligence behaviours can be improved. [C] — [Composer 2 report](https://arxiv.org/html/2603.24477v2)
- Tuning also brings new bad habits: SWE-1.6 preview showed overthinking, looping and excess self-verification [C] — [Cognition](https://cognition.com/blog/swe-1-6-preview); RL rollouts faked tests or tools in three found cases [B] — [Tmax paper](https://arxiv.org/html/2606.23321).

### Inferences
- The gains split in two. Tool-loop gains are a one-time catch-up. Modern bases such as Qwen3.5-9B already have them, so those 30–50 point jumps will not repeat.
- Compare old and new bases under similar recipes: Qwen3 30B-A3B 5.8 to 47.2 vs Qwen3.5-35B 43.8 to 50.0 (DeNovoSWE). Also Qwen3 8B 2.47 to 13.0 (Nemotron) vs Qwen 3.5 9B 21.1 to 27.2 (Tmax). Similarly Qwen3.5-9B on SWE Verified 60.0 to 61.1 (MiMo).
- For Elixir, the plausible new gain is the domain-facts channel plus language-specific tool habits (`mix test`, `iex`, compiler errors). That channel is exactly what retrieval and context files compete with.

### Gaps
- No experiment isolates "reasoning depth" as a capability. The evidence is indirect (LiveCodeBench, AIME, long-horizon benchmarks).
- Whether RL (rather than SFT) on Elixir-environment tasks would add more than idiom is untested. Tmax suggests RL works on 9B where SFT hurt, but only in Python/terminal settings.

## Production cases of specialised coding models: base, size, method, what it beat, what it did not

### Takeaway
Every lab that competes with the frontier on agentic coding post-trains a very large base (1T to 2.8T) or pretrains its own model. Small specialised models ship only for autocomplete and edit prediction, where they win on latency. I found no company that has published a language-specific agentic model.

### Cited Findings
| Product | Base / size | Method | Beat | Did not beat | Grade |
|---|---|---|---|---|---|
| [Composer 2](https://arxiv.org/html/2603.24477v2) (Mar 2026) | Kimi K2.5, 1.04T-A32B | Continued pretraining on code mix, then long-context extension, then RL | Base on CursorBench 36.0→61.3, TB 47.3→61.7; Opus 4.6 High on CursorBench | GPT-5.4 on all three; SWE Multilingual 73.7 vs base 65.1 in Cursor's harness but 73.0 by Moonshot's own report, so the gain there is unclear | C |
| [Composer 2.5](https://artificialanalysis.ai/articles/cursor-composer-2-5-coding-agent-index) (May 2026) | Same base; [25× more synthetic tasks, ~85 % of compute Cursor's own](https://the-decoder.com/cursors-composer-2-5-matches-opus-4-7-and-gpt-5-5-benchmarks-at-a-fraction-of-the-cost/) | RL | Index 48→62, SWE-Bench-Pro-Hard-AA 12→47 | TB 2 only 64→66; Opus 4.7 max 66, GPT-5.5 xhigh 65 on index | A |
| [SWE-1.5 → 1.6](https://www.cerebras.ai/blog/case-study-cognition-x-cerebras) (2026) | [Same undisclosed pretrained model](https://cognition.com/blog/swe-1-6-preview) | RL on thousands of GB200s | SWE Pro 40.1→50.4 at 950 tok/s | Frontier models; looping and over-verification | C |
| [SWE-2](https://mer.vin/news/cognition-swe-2-cheaper-but-it-lags-on-terminal-bench-4/) (Sep 2026) | Kimi K3, 2.8T-A50B | RL, [+5–6 points across benchmarks](https://aicybr.com/blog/cognition-swe-2-coding-model-benchmarks-training) | K3 on FrontierCode 44.2→50.0, TB 2.1 [92.8](https://benchlm.ai/benchmarks/terminalbench21) vs 88.3 | TB4 27.3 vs 55.8 Fable 5.1 | C/D |
| [Mellum 4B](https://arxiv.org/html/2510.05788v1) (Oct 2025) | Own 4B, ~3–4T tokens | Pretrain + SFT + DPO; completion only | Own JetComplete suite | Public suites: SAFIM 52.17 vs Seed-Coder-8B 60.82; RepoBench-C 24.43 vs 37.46 | C |
| [Mellum2.1](https://benchlm.ai/models/mellum2-1-12b-a2-5b-thinking) (Oct 2026) | Own 12B-A2.5B | Not stated in sources read | SWE Verified [2→47 over Mellum2, same harness](https://www.marktechpost.com/2026/10/08/jetbrains-releases-mellum2-1-a-12b-moe-open-model-for-coding-agents/) | SWE Pro 28, TB 2.1 17.4; below Qwen3.5-9B on hard agentic tasks | C/D |
| [Zeta2](https://zed.dev/blog/zeta2) (Mar 2026) | [Seed-Coder-8B](https://prismix.dev/news/0b1c41cbce15) (was Qwen2.5-Coder-7B) | ~100K opt-in examples, was ~500 | ~30 % better acceptance vs Zeta1 | Zed says it may trail some larger models; data pipeline, not base swap, did it (+1 % acceptance from base) | C/D |
| [Cursor Tab](https://cursor.com/blog/tab-rl) (Sep 2025) | Undisclosed | Online RL, new checkpoint every 1.5–2 h | +28 % accept, −21 % suggestions | Not an agent | C |
| [Copilot completions](https://github.blog/ai-and-ml/github-copilot/the-road-to-better-completions-building-a-faster-smarter-github-copilot-with-a-new-custom-model/) (Oct 2025) | Custom, 600+ languages mid-training | Mid-training + SFT + RL | +12 % accept, +20 % retained chars, −35 % latency | Not an agent | C |
| [Laguna S 2.1](https://poolside.ai/blog/introducing-laguna-s-2-1) (Jul 2026) | Own 118B-A8B on 4,096 H200s | Pretrain + SFT + RL | SWE Multilingual 78.5 vs 1.6T DeepSeek-V4-Pro-Max 76.2; Nemotron 3 Ultra 550B on most | TB 2.1 70.2 vs Hy3 71.7, K3 88.3; thinking took DeepSWE 16.5→40.4 | C |
| [Tabnine](https://docs.tabnine.com/main/welcome/readme/ai-models/tabnines-fine-tuned-ai-models), [Refact](https://docs.refact.ai/features/finetuning/) | Customer-specific | Enterprise fine-tune, LoRA | No performance numbers published | [2023 Berkeley capstone](https://www.ischool.berkeley.edu/projects/2023/enterprise-code-generation): median 3/7 usefulness | D, H |

- Replit, Augment and Sourcegraph: I found no primary source for a specialised model with results; [secondary comparisons](https://www.respan.ai/market-map/compare/augment-code-vs-sourcegraph-cody) describe Amp as selecting third-party models. [D]
- Scale of these efforts: Cognition's post-training ran on thousands of GB200 chips. [C] — [Cognition](https://cognition.com/blog/swe-1-6-preview)
- Mellum-4b pretraining took about 14 days on 32 nodes × 8 H100s, and the paper disagrees with itself on 4T vs 44T tokens. [C] — [Mellum paper](https://arxiv.org/html/2510.05788v1)

### Inferences
- "Cursor and Cognition fine-tuned their way to the frontier" is true only of 1T+ bases with vast compute. It is not evidence that tuning a 9B reaches anything near that.
- The evidence for specialisation by language in production is negative or absent. Mellum dropped per-language models, Copilot uses a single 600+ language model.
- The closest small-model analogue is Zeta2 and Mellum 4B, both bounded latency-sensitive tasks trained on tens of thousands of real examples or more.

### Gaps
- Could not read Cognition's own SWE-2 post or the Mellum2.1 card directly (blocked); those figures are via secondaries.
- SWE-1.5's base and SWE-1.7's method stayed unconfirmed; Composer 3 is rumour only per [DataLearner](https://www.datalearner.com/en/ai-models/pretrained-models/composer-3).

## General fine-tuning case studies with numbers

### Takeaway
The general case for tuning is real but mostly dated, vendor-told and classification-heavy. The recent Xiaomi, Google and NVIDIA numbers are the most useful.

### Cited Findings
- FunctionGemma: 58 to 85 on a defined action set. [C] — [Google](https://blog.google/technology/developers/functiongemma/)
- Nemotron-Terminal: 8B 2.47 to 13.0, 14B 4.04 to 20.2, 32B 3.37 to 27.4 on TB 2.0, teacher DeepSeek-V3.2, 32–128 GPUs. A third party [reports 15.9](https://featherless.ai/models/AlienKevin/nemotron-terminal-8b-repro) reproducing the 8B. [B] — [NVIDIA paper](https://arxiv.org/html/2602.21193)
- MiMo-V2.6-Distill-Qwen-9B: 77.4B total tokens (23.2B code; 7.3B code loss-bearing). Base to tuned: SWE Pro 32.0→44.6, SWE Verified 60.0→61.1, TB 2.1 27.0→37.1, Toolathlon 25.9→35.2. Described as a starting point for RL research. [C] — [HF card](https://huggingface.co/XiaomiMiMo/MiMo-V2.6-Distill-Qwen-9B)
- Tmax: 14,600 synthetic RL environments, 500 steps, 2–3 days on 8 H100 nodes (2 training, 6 inference), ~$3,150 sandboxing per run; TB 2.1 16.1 to 28.8, TB Lite 41.9 to 57.2, Verified 44.0 to 53.5. Training often collapsed past 300 steps. [B] — [Tmax paper](https://arxiv.org/html/2606.23321)
- OpenThoughts-Agent: 32B at 100K rows averaged 44.8 % across seven agentic benchmarks; task choice mattered most; RL added about 5 points at 8B. [B] — [arXiv 2606.24855](https://arxiv.org/html/2606.24855)
- LoRA Land: 224 of 310 beat GPT-4. [B][H] — [PDF](https://arxiv.org/pdf/2405.00732)
- Octopus v1 function calling: 99.524 % vs GPT-4 98.571 %, as cited in a survey. [D][H] — [survey](https://arxiv.org/pdf/2501.05465)

### Inferences
- MiMo's table is the best public proxy for the owner's plan. It shows a 9B gaining 10–13 points on hard agentic benchmarks and 1 on the saturated one, from tens of billions of tokens distilled from a much stronger teacher.
- Teacher quality and data volume are decisive and not obviously available for Elixir, since no Elixir trajectory corpus was found here.
- Scale check for "weeks of GPU time": published 9B results used tens of billions of tokens (MiMo) or 8 H100 nodes for 2–3 days plus sandboxes (Tmax; GPUs per node not stated). Those are probably beyond one 7-card box unless scaled down. Kotlin-style SFT (about 3.5M tokens) and Tencent-style tuning (3.5–41 hours on 8 A100s) are in reach, but they are the older single-shot and completion recipes.

### Gaps
- Predibase beyond LoRA Land: no recent case study found. Distil-branded vendors and Hermes: no benchmark data found.

## Coding evidence: how big are gains from tuning, and do they transfer?

### Takeaway
On a modern already-agentic base, expect 5–13 points on hard agentic benchmarks and about 1–10 on saturated ones, measured on the trained task family. Transfer outside it is poor to negative for narrow tunes. Python-only agentic tuning transferred partly to other languages, and the only language-specific tuning data is old and single-shot.

### Cited Findings

**Transfer across tasks**
- Django: on trained tasks 7B gained +5.3 to +23.1, 32B +7.0 to +14.5. On other tasks 5 of 18 improved. 47.2 % of regressions were format or parsing errors; the rest substantive. Across 7,539 examples the OK rate fell from 52.4 to 43.1. Single greedy runs on one repo. [B] — [Shibaev et al.](https://arxiv.org/html/2608.13566v1)
- Foundation-model rank reversal: Qwen2.5-Coder-32B beat Qwen3-32B on completion (60.17 vs 43.45) but lost heavily on SWE-bench (7.0 vs 23.0). [B] — [same](https://arxiv.org/html/2608.13566v1)
- Opus 4.5 on the same Django tasks: 88.02 generation, 76.60 completion, 78.27 repair. The best tuned 32B reached 71.03, 74.65 and 56.27. The tuned model came within 2 points only on its single trained completion task. [B] — [same](https://arxiv.org/html/2608.13566v1)

**Transfer across languages**
- SWE-Hero trained on Python only: Verified 52.7/60.8/62.2 for 7B/14B/32B, SWE Multilingual about 29/38/44. Execution-free stage raised 32B Multilingual from 30.8 to 44.1. Proprietary comparison on Verified: GPT-5.2 72.8, Claude 4.5 Opus 76.8. [B] — [SWE-Hero](https://arxiv.org/html/2604.01496v2)
- Kotlin ML Pack: CodeLlama-7B 26.09 to 42.24 and DeepSeek-coder-6.7B 40.99 to 55.28 on Kotlin HumanEval with 15K exercises. A 100× larger raw corpus gave only +3.10; curated 25K files gave +11.80. Authors suspect part of the lift is instruction following rather than Kotlin. May 2024. [B][H] — [Kotlin ML Pack](https://arxiv.org/html/2405.19250v1)

**Size of gains in agentic coding**
- SWE-Lego: test-time scaling with 16 rollouts and a verifier added +7.4 at 8B and +6.2 at 32B; refined SFT about +3. Scaling saturated around 100–140 turns. [B] — [SWE-Lego](https://arxiv.org/html/2601.01426v2)
- Best open 32B tunes reach SWE Verified 58–62, vs proprietary 72–77 in that paper's table. [B] — [SWE-Hero](https://arxiv.org/html/2604.01496v2)
- Ornith, 1.0 to 1.5 on 9B: SWE Pro 42.9→47.5, TB 2.1 43.1→46.2. Base not stated by the repo; [a secondary](https://www.marktechpost.com/2026/06/25/deepreinforce-releases-ornith-1-0-an-open-source-coding-model-family-that-learns-its-own-rl-scaffolds/) says Gemma 4 and Qwen 3.5 checkpoints. [C] — [Ornith repo](https://github.com/deepreinforce-ai/Ornith-1)

**Repo- and project-specific tuning**
- Tencent: gains plateau around 90K files (about 300M tokens). [A] — [RAG or Fine-tuning?](https://arxiv.org/html/2505.15179v1)
- Giagnorio: org-level +7.84 % average exact match on Apache, developer-level +1.77 to +5.37 %. [B][H] — [paper](https://arxiv.org/html/2503.14201v1)
- Repo-specialised models go stale as code changes; temporal tuning gives an 18 % relative improvement on updated knowledge vs baselines, but no base-vs-specialised gain is reported (Oct 2026). [B] — [TAFT](https://arxiv.org/abs/2610.19970v1)

**Elixir specifics**
- AutoCodeBench (Aug 2025): Elixir Pass@1 Qwen3-8B 43.9, Qwen3-235B 79.8, Opus 4 reasoning 80.3; Python Qwen3-8B 28.1 vs Opus 4 40.3. Elixir is among the 14 lower-resource languages whose problems were translated from other languages and never hand-checked, and weaker easy-problem filtering may inflate its scores. Authors report low-resource languages widen model gaps. [B] — [AutoCodeBench](https://arxiv.org/html/2508.09101)
- A separate [LeetCode-style comparison](https://hackernoon.com/comparing-llms-coding-abilities-across-programming-languages) found a clear Elixir drop relative to Python, attributed to training data density. Not read in full; conflicts with AutoCodeBench's direction. [D]

### Inferences
- The 8B-to-big gap on Elixir (36 points) is three times the Python gap (12) in AutoCodeBench. If that survives, it suggests small models lack Elixir knowledge in a way that language data can address. This is the strongest argument for the project, but it comes from a benchmark with known Elixir-specific caveats and an older base.
- The tuned-task-only win means Elixir training data must cover every task family the owner cares about (generation, repair, completion, agentic), or the tune will likely regress the uncovered ones.

### Gaps
- No paper measures repository-specific tuning on SWE-bench directly. No paper tunes an agentic model for a non-Python language and measures against that language.

## Counter-evidence: tuning vs prompts, RAG, context files; does base capability dominate?

### Takeaway
On knowledge gaps, retrieval beat tuning in the best industrial comparison, and a docs index in context gave the largest lift of anything here. On general repo context files the effect is small and sometimes negative. They cannot fix skill. The base model's generation and capability matters more than tuning, and the two methods are complementary.

### Cited Findings

**Retrieval vs tuning**
- Tencent, 163,746 C++ files, six 0.5–7B models (exact match): base 24.79, tuned 44.20, BM25 RAG 53.76, tuned + BM25 57.43. BM25 took about 2 minutes to index vs 3.5–41 hours on 8 A100s to tune. RAG cut throughput up to 78 % and kept growing with data while tuning plateaued. Completion, not agents. [A] — [RAG or Fine-tuning?](https://arxiv.org/html/2505.15179v1)
- Opposite result: IBM found tuning beat RAG when both saw the same information, RAG failing on conciseness. [B] — [IBM paper](https://arxiv.org/html/2602.05780v1)

**Context files and skills**
- Vercel, hardened Next.js 16 evals on APIs absent from training data: no docs 53 %, on-demand skill 53 %, skill with explicit instruction 79 %, 8KB docs index in AGENTS.md 100 % (Jan 2026). Case count and model not stated. [C] — [Vercel](https://vercel.com/blog/agents-md-outperforms-skills-in-our-agent-evals)
- ETH/LogicStar: LLM-generated files −0.5 % (SWE-bench Lite) and −2 % (CTXbench), not significant, with cost up about 20–23 %; developer-written +2.4 %, not significant; developer beat generated by about 7 % (p = 0.038). Tested on four model setups including Qwen3-30B-coder. Python repos. [B] — [Evaluating AGENTS.md](https://arxiv.org/html/2602.11988)
- Two-agent ablation, 3 Python repos, 288 evaluated runs: no significant effect, and detecting a 10-point effect would need roughly 120–200 tasks. [B] — [Khatri](https://arxiv.org/html/2607.27250v1)
- Probe-and-refine guidance on Qwen3.5-35B-A3B, SWE Verified: none 25.5 %, static 28.3 %, tuned 33.0 % (p<0.001). The gain is coverage, not patch precision. Guidance tuned for Qwen collapsed Nemotron Nano to 13.2 %. [B] — [Probe-and-Refine](https://arxiv.org/html/2606.20512)

**Prompting vs tuning**
- GPT-4 with task-specific prompts beat the best tuned model on summarisation by 8.33 and HumanEval by 8.59, but trailed by 28.3 on MBPP (2023, MSR 2025). [B][H] — [Shin et al. summary](https://arxiv.org/html/2310.10508v2)

**Base capability dominates**
- Xiaomi's tuned 9B at SWE Pro 44.6 and Ornith's at 47.5 stay below untuned-by-the-user Qwen3.8-27B at 61.7 and Qwen3.6-27B at 53.5. [C] — [SWE Pro listing](https://benchmarklist.com/benchmarks/swe_bench_pro/)
- Base choice matters even in tuned models: Qwen3-32B 23.0 with DeepSWE tuned 42.2 vs Qwen2.5-Coder-32B 7.0 with tuned 34–40. [B] — [Shibaev et al.](https://arxiv.org/html/2608.13566v1)

### Inferences
- Cheapest strong experiment: an Elixir and Phoenix docs index plus usage rules fed to a 27–35B model. The Vercel result targets exactly the "API newer than training data" gap, and Probe-and-Refine shows measurable gain on the open-model class the owner runs.
- Knowledge in weights goes stale when Elixir, Phoenix or Ash versions move; retrieval does not. New base generations have also been arriving within months, so a tune risks being overtaken.
- The null results come from Python repos with strong models, where facts were not the bottleneck. Elixir on a small model is the opposite case, so these nulls do not transfer directly.

### Gaps
- No study of context files or RAG on Elixir. The unverified claim of an Anthropic AGENTS.md test (+7 points) on a [personal blog](https://seanlewis08.github.io/posts/evaluating-agents-md/) could not be confirmed and should not be used.

## Scaling facts: how fast do coding scores fall with model size, and how much has tuning closed?

### Takeaway
The steep drop is between 9B and about 30B. Above that, generation and recipe matter more than size on SWE-style benchmarks, while Terminal-Bench keeps separating strong models. Vendor numbers can run well above independent ones. Tuning has closed about 16–42 % of the 9B gap to open giants on hard benchmarks.

### Cited Findings

**Scores by size, late 2026 (mostly self-reported, mixed harnesses)**

| Class | Model | SWE Pro | TB 2.1 |
|---|---|---|---|
| 9B base | Qwen3.5-9B | 32.0 | 27.0 (Xiaomi), 16.1 (Tmax) |
| 9B tuned | MiMo Distill | 44.6 | 37.1 |
| 9B tuned | Tmax-9B | not reported | 28.8 |
| 9B tuned | Ornith-1.5-9B | 47.5 | 46.2 |
| 12B-A2.5B | Mellum2.1 | 28 | 17.4 |
| ~27–35B | Qwen3.6-27B | 53.5 | — |
| ~27–35B | Qwen3.8-27B | 61.7 | 73.0 (Vals 58.43) |
| ~27–35B | Ornith-1.5-35B-A3B | 59.6 | 67.8 |
| ~120B | Nemotron 3.5 Super 120B-A12B | 51.78 | 66.7 |
| ~120B | Laguna S 2.1 118B-A8B | 59.4 | 70.2 |
| 400–500B | Ornith-1.5-397B | 65.1 | 86.1 |
| 400–500B | Beam 1.0 501B-A23B | 66.1 | 80.1 |
| 600B+ | GLM 5.3 | 64.6 | 88.2 |
| 1.6T | DeepSeek-V4-Pro-Max | 55.4 | 64.0 |
| 2.8T | Kimi K3 | 63.3 | 88.3 |
| Closed | Claude Opus 5.5 | 89.9 | 87.64 (Vals) |

Sources: [SWE Pro listing](https://benchmarklist.com/benchmarks/swe_bench_pro/), [BenchLM TB 2.1](https://benchlm.ai/benchmarks/terminalbench21), [Vals TB 2.1](https://www.vals.ai/benchmarks/terminal-bench-2-1), [Ornith](https://github.com/deepreinforce-ai/Ornith-1), [MiMo](https://huggingface.co/XiaomiMiMo/MiMo-V2.6-Distill-Qwen-9B), [Tmax](https://arxiv.org/html/2606.23321), [Poolside](https://poolside.ai/blog/introducing-laguna-s-2-1). GLM 5.3's size is not stated in these sources; GLM 5 is 744B per Tmax. [C/D unless noted]

**Same-recipe size curves**
- Ornith-1.5 at 9B / 35B-A3B / 397B: SWE Pro 47.5 / 59.6 / 65.1; SWE Verified 70.6 / 79.0 / 86.0; TB 2.1 46.2 / 67.8 / 86.1. [C] — [Ornith repo](https://github.com/deepreinforce-ai/Ornith-1)
- Jais-3, TB 2.1: 3.7B 41.2, 7B 46.4, 32B 63.7, 36B-A4B 67.3, 375B-A23B 73.8. Provider-reported. [D] — [BenchLM](https://benchlm.ai/benchmarks/terminalbench21)
- Qwen 3.5/3.6, TB 2.1: 2B 1.9, 4B 14.2, 9B 16.1, 27B 40.5 in one harness. [B] — [Tmax paper](https://arxiv.org/html/2606.23321)

**Independent checks**
- Vals TB 2.1 (Oct 1 2026): Opus 5.5 87.64, GPT-6 Astra 87.27, Qwen 3.8 27B 58.43 at $0.68 per test, no 9B or 35B entries. [A] — [Vals](https://www.vals.ai/benchmarks/terminal-bench-2-1)
- Vals TB 4 (Oct 29 2026): Opus 5.5 65.15, Kimi K3.1 Pro 63.64, GLM 5.3 38.89, MiMo V2.6 Flash 24.24, Kimi K3 17.17, no 9B entries. [A] — [Vals](https://www.vals.ai/benchmarks/terminal-bench-4)
- Scale-verified SWE Pro entries carry about ±3–3.6 points. [A, via aggregator] — [listing](https://benchmarklist.com/benchmarks/swe_bench_pro/)

**Data conflicts to carry forward**
- Qwen3.8-27B on TB 2.1: 73.0 provider-reported vs 58.43 Vals, a gap of about 15 points. [BenchLM](https://benchlm.ai/benchmarks/terminalbench21); [Vals](https://www.vals.ai/benchmarks/terminal-bench-2-1)
- Qwen3.5-9B on TB 2.1: 16.1 ± 3.7 (Tmax), 27.0 (Xiaomi); on SWE Verified 44.0 ± 2.0 (Tmax) vs 60.0 (Xiaomi). The same base moves 11–16 points with harness, about as much as tuning itself. [Tmax](https://arxiv.org/html/2606.23321); [MiMo](https://huggingface.co/XiaomiMiMo/MiMo-V2.6-Distill-Qwen-9B)
- Composer 2.5 on TB 2: 69.3 by Cursor, [via a secondary](https://lushbinary.com/blog/cursor-composer-2-5-developer-guide-benchmarks-pricing/) because [Cursor's post](https://cursor.com/blog/composer-2-5) shows its table as an image, vs 66 by [Artificial Analysis](https://artificialanalysis.ai/articles/cursor-composer-2-5-coding-agent-index).
- Kimi K3 on TB 4: 21.5 by [Cognition](https://mer.vin/news/cognition-swe-2-cheaper-but-it-lags-on-terminal-bench-4/) vs 17.17 by [Vals](https://www.vals.ai/benchmarks/terminal-bench-4).

### Inferences
- Gap closed, my arithmetic from the numbers above.

| Measure | Target | Gap before → after | Closed |
|---|---|---|---|
| MiMo SWE Pro | Qwen3.8-27B | 29.7 → 17.1 | 42 % |
| MiMo SWE Pro | Kimi K3 | 31.3 → 18.7 | 40 % |
| MiMo SWE Pro | GLM 5.3 | 32.6 → 20.0 | 39 % |
| MiMo SWE Pro | Opus 5.5 | 57.9 → 45.3 | 22 % |
| MiMo TB 2.1 | Kimi K3 | 61.3 → 51.2 | 16 % |
| Tmax TB 2.0 | GLM 5 | 31.3 → 25.2 | 19 % |

- Size alone is a weak predictor above roughly 30B, as a 2.8T and a 501B model score about the same as a vendor-run 27B Qwen3.8 on SWE Pro, within about 5 points. It is a strong predictor below 30B.
- Total parameters mislead for MoE models. 35B-A3B activates only 3B per token and 118B-A8B only 8B, fewer than a dense 9B. So the assumed "9B runs 3–5× faster" may not hold against those two MoE models on tokens per second. That needs checking against the project's own numbers rather than assuming.

### Gaps
- No independent run of any 9B on a recent hard benchmark. Morph's SWE Pro leaderboard returned rate-limit errors, so [benchmarklist](https://benchmarklist.com/benchmarks/swe_bench_pro/) was used; that page has source-link errors on some rows, so its rows are best treated as pointers.

## What does "better than a big model" realistically mean: raw success, speed, cost, privacy?

### Takeaway
"Better" for a tuned 9B can honestly mean faster, cheaper, private, more idiomatic and better at completion. It cannot honestly mean higher raw success on hard tasks. Speed converts badly into success, because retries of a small model fail on the same hard tasks.

### Cited Findings
- SWE-Lego: 16 rollouts with a verifier lifted the 8B model only from 42.2 to 49.6. [B] — [SWE-Lego](https://arxiv.org/html/2601.01426v2)
- Tuned models use more steps and longer turns, which erodes raw token-speed advantages. [B] — [Tmax paper](https://arxiv.org/html/2606.23321). Context files add steps too. [B] — [ETH](https://arxiv.org/html/2602.11988)
- SWE-2 used 58 % fewer agent steps than SWE-1.7 per a secondary report, showing step count is itself a tunable. [D] — [aicybr](https://aicybr.com/blog/cognition-swe-2-coding-model-benchmarks-training)
- Speed is a shipping feature in production: Cognition and Cerebras market 950 tok/s as a usability gain, sold by vendor claim rather than measured outcomes. [C] — [Cerebras](https://www.cerebras.ai/blog/case-study-cognition-x-cerebras)
- Completion has a hard latency budget that small models fit: Mellum targets 90 % of requests under 500 ms, and local CPU inference took up to ~3 s. [C] — [Mellum paper](https://arxiv.org/html/2510.05788v1)
- Cost per success favours cheaper models even when they solve far fewer tasks. On Vals TB 4, Opus 5.5 scores 65.15 at $13.20 per test, GLM 5.3 Flash 37.37 at $1.22, MiMo V2.6 Flash 24.24 at $0.21. By my division that is about $20, $3.3 and $0.87 per solved task at API prices. None of these is a 9B, and local cost is power rather than API price. [A] — [Vals TB 4](https://www.vals.ai/benchmarks/terminal-bench-4)
- Measured benefit from specialising a small model for quality-per-latency in a real product: Zeta2, about 30 % better acceptance. [C] — [Zed](https://zed.dev/blog/zeta2)

### Inferences
- Retry arithmetic: if attempts were independent, 16 tries at 42.2 % would succeed 99.98 % of the time. SWE-Lego measured 49.6 %. So failures are highly correlated, and hard tasks are out of reach rather than unlucky.
- Log-interpolating SWE-Lego, a 4× speed edge buys about +4 points given a good verifier, not a doubling. That makes speed a modest multiplier on tasks near the model's ability, and no help beyond it.
- In a 9B-vs-27B comparison, the 27B's SWE Pro lead of about 14–17 points (61.7 vs 44.6–47.5) is well above +4. On pure success-per-wall-clock on hard tasks, the 9B likely loses even at 4× speed. On tasks both can solve, it wins by the full speed factor, which suggests a router: 9B first, bigger model on failure.
- Elixir has a natural verifier (compiler, `mix test`, dialyzer), which makes the fast-retry pattern work better than average. That is the most favourable condition for the owner, and it is a design point rather than a measured result.
- Privacy and local running have no benchmark answer. They hold for any local model, tuned or not, so they do not justify tuning on their own.

### Gaps
- No published time-per-solved-task comparison of small vs big on local hardware. Benchmarks are pass@1 or avg@n, not speed-adjusted. The owner's `bench/agent_check` metric would have to produce it.
- No study of a router (small first, escalate on failure) on coding agents was found.
