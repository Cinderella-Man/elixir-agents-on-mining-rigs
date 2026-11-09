# Base models to fine-tune for agentic Elixir coding: ~5–15B, with 20–40B for comparison (as of 2026-11-02)

Conventions used throughout:
- Web facts carry a link. Most benchmark numbers are vendor-reported on the vendor's own harness, so compare them only within one table ([Hashnode roundup](https://hashnode.com/blog/best-open-weight-llms) makes the same warning).
- "repo:" links are files in this project (`llms-on-crypto-mining-rigs/`).
- "est." marks an estimate. Every rig speed for a model that has not run on the rig is an estimate, scaled only from project numbers. Nothing was run and no weights were downloaded.
- "my calc" marks arithmetic done in these notes.
- Model pages were read through a summarising fetch tool, so a field shown as "not stated" means the fetch did not show it, not that the source lacks it.

## Full candidate table: what exists, and which real models sit near "a 9B model"

### Takeaway
"A 9B model" means, in practice, **Qwen3.5-9B** (Feb 2026, Apache-2.0, hybrid dense): the only other model at that size is the older Nemotron-Nano-9B-v2. The nearby sizes are Granite 4.1 8B, LFM2.5-8B-A1B, Ministral 3 8B/14B, Gemma 4 12B and Bolt-E4B. No smaller Qwen3.8 exists, and I found no new ~9B coding model in the last three months: recent small-model releases are 27B dense (Qwen3.8-27B, Aug) or 30–33B-A3B MoE (Laguna XS 2.1, North Mini Code, Nemotron 3.5 Lightning).

### Cited Findings

**Tier 1: ~5–15B**

| Model | Released | Total / active | Architecture | Licence | Context | Thinking | Tool format | Extras to drop | Source |
|---|---|---|---|---|---|---|---|---|---|
| **Qwen3.5-9B** | Feb 2026 (card citation) | 9B (Hub badge 10B), dense | 32 layers, hidden 4,096; 3 Gated DeltaNet + 1 Gated Attention repeated 8 times; FFN 12,288; vocab 248,320; MTP supported | Apache-2.0 | 262,144 (YaRN 1.01M, card warns it hurts short text) | On by default, `<think>`; `enable_thinking` via `chat_template_kwargs`; no `/think` soft switch | `qwen3_coder` parser, `qwen3` reasoning parser | Vision encoder (`--language-model-only` in vLLM) | [card](https://huggingface.co/Qwen/Qwen3.5-9B) |
| OmniCoder-9B (Tesslate) | Mar 2026 banner | as Qwen3.5-9B | LoRA r=64 fine-tune of Qwen3.5-9B, Axolotl, 425K+ agent traces | Apache-2.0 | 262,144 | `<think>` | Card says "flexible", not specified | Vision encoder | [card](https://huggingface.co/Tesslate/OmniCoder-9B) |
| Nemotron-Nano-9B-v2 | 2025 (vLLM already served it by Oct 2025) | 9B | Mamba-2 + MLP layers with four attention layers | NVIDIA Open Model License (secondary); HF card returned 401 | 128K | Reasoning model | Tool use listed; BFCL v3 66.9 | None | [listing](https://www.llmreference.com/provider/openrouter/nemotron-nano-9b-v2), [vLLM blog](https://vllm.ai/blog/2025-10-23-now_serving_nvidia_nemotron_with_vllm) |
| IBM Granite 4.1 8B | 2026-04-29 | 8B (metadata 9B), dense | Decoder-only GQA, RoPE, SwiGLU, RMSNorm, tied embeddings | Apache-2.0 | 131,072 | Not mentioned | JSON in `<tool_call>` tags, `<tools>` in system prompt | None | [card](https://huggingface.co/ibm-granite/granite-4.1-8b) |
| LFM2.5-8B-A1B | 2026 | 8.3B / 1.5B ([vLLM recipe](https://docs.vllm.ai/projects/recipes/en/latest/LiquidAI/LFM2.5.html) says ~1B) | MoE; 18 double-gated convolution + 6 GQA layers; vocab 128,000 | `lfm1.0` tag; terms not read | 128,000 | Reasoning, `<think>` | Pythonic calls between `<\|tool_call_start\|>` and `<\|tool_call_end\|>`, JSON optional | None | [card](https://huggingface.co/LiquidAI/LFM2.5-8B-A1B) |
| Gemma 4 12B Unified | Jun 2 2026 (Unified release) | 12B, dense | Encoder-free multimodal, per Axolotl's naming | Apache-2.0 | 262,144 | Hybrid, `<\|think\|>` in system prompt | `<\|tool_call>` … `<tool_call\|>` with `call:name{…}` and `<\|"\|>` string delimiters | Audio, vision (encoder-free, so whether they can be dropped is unverified) | [Unsloth](https://unsloth.ai/docs/models/gemma-4.md), [Google](https://ai.google.dev/gemma/docs/capabilities/function-calling), [Axolotl v0.18](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.18.0) |
| Ministral 3 8B / 14B | "2512" in name (inference: Dec 2025) | 8B, 14B | Multimodal; Base, Instruct and Reasoning variants | Not stated on page | 262,144 | Reasoning variant: `[THINK]…[/THINK]` | Native function calling, format not stated | Vision | [Unsloth](https://unsloth.ai/docs/models/tutorials/ministral-3.md) |
| Nemotron 3.5 Bolt-E4B | Oct 2026 (one roundup says weights landed Oct 15, unverified) | 8B / ~4B effective | Based on Gemma 4 E4B | Not stated | 64K | Configurable | Multi-turn tool calling, format not stated | Not stated | [Unsloth](https://unsloth.ai/docs/models/nemotron-3.5-bolt.md), [roundup](https://pasqualepillitteri.it/en/news/24368/best-open-weight-models-october-2026-compared) |

**Tier 2: 20–40B, for comparison**

| Model | Released | Total / active | Architecture | Licence | Context | Thinking | Tool format | Extras | Source |
|---|---|---|---|---|---|---|---|---|---|
| Qwen3.8-27B | Aug 2026 | 27B dense | 64 layers, hidden 5,120, Gated DeltaNet + Gated Attention, MTP | Apache-2.0 | 262,144 | On; `reasoning_effort` xhigh/medium/low; `preserve_thinking` on | Not stated on card; family parsers as Qwen3.5 | Vision, video | [card](https://huggingface.co/Qwen/Qwen3.8-27B) |
| Muse Glimmer 30B (Meta) | Not stated | ~29.6B dense | 52 layers, hidden 6,656, vocab 202,048 | Apache-2.0 | 131,072, up to 262,144 | low/medium/high/xhigh | Sequential tools, format not stated | Vision | [Unsloth](https://unsloth.ai/docs/models/muse-glimmer.md), [train guide](https://unsloth.ai/docs/models/muse-glimmer/train.md) |
| Gemma 4 31B | Not stated | 31B dense | Attention | Apache-2.0 | 262,144 | Hybrid | As 12B | Vision | [Unsloth](https://unsloth.ai/docs/models/gemma-4.md) |
| Gemma 4 26B-A4B | Not stated | 26B / 4B | MoE, 128 experts | Apache-2.0 | 262,144 | Hybrid | As 12B | Vision | [Unsloth](https://unsloth.ai/docs/models/gemma-4.md), [Axolotl v0.18](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.18.0) |
| Devstral Small 2 24B | "2512" (inference: Dec 2025) | 24B dense | Ministral 3 architecture, tuned from Mistral-Small-3.1-24B-Base | Apache-2.0 on card; [VentureBeat](https://venturebeat.com/ai/mistral-launches-powerful-devstral-2-coding-model-including-open-source) claims enterprise gating, unclear whether for this model | 256K | Not mentioned | `mistral` parser | Vision | [card](https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512) |
| Laguna XS 2.1 (Poolside) | Jul 2 2026 (collection date) | 33B / 3B | 40 layers, hidden 2,048, 256 × 512 experts, 8 per token, shared expert 512, sigmoid gating, 30 sliding (512) + 10 global, vocab 100,352 | OpenMDW-1.1 | 262,144 | Interleaved, preserved between tool calls | `poolside_v1` parser, OpenAI-compatible | Text only | [card](https://huggingface.co/poolside/Laguna-XS-2.1), [config](https://huggingface.co/poolside/Laguna-XS-2.1/raw/main/config.json) |
| North Mini Code 1.0 (Cohere) | Jun 9 2026 | 30B / 3B | 128 experts, 8 per token, sigmoid router, sliding + global 3:1 | Apache-2.0 (a secondary write-up claims a non-commercial note; the card does not show one) | 256K in, 64K out | Interleaved | `cohere_command4` parser plus `cohere_melody` | Text only | [card](https://huggingface.co/coherelabs/north-mini-code-1.0), [AA](https://artificialanalysis.ai/articles/north-mini-code-cohere-s-small-coding-focused-moe-model) |
| Nemotron 3.5 Lightning | 2026-08-11 | 30B / 3B ([AA](https://artificialanalysis.ai/articles/nemotron-3-5-lightning-launch) says 31.6B / 3.6B) | Hybrid Mamba-Transformer MoE, MTP | OpenMDW-1.1; weights, data and recipes published | 1M ([one listing](https://www.llmreference.com/model/nemotron-3.5-lightning) says 262,144) | Thinking and instruct modes | Not stated | Text only | [Unsloth](https://unsloth.ai/docs/models/nemotron-3.5.md), [AA](https://artificialanalysis.ai/articles/nemotron-3-5-lightning-launch) |
| GLM-4.7-Flash | Jan 2026 (fix dates) | 30B / ~3.6B | MoE; repo: `deepseek2` arch with MLA | Not stated on page | 202,752 | `glm45` reasoning parser | `glm47` parser | None noted | [Unsloth](https://unsloth.ai/docs/models/tutorials/glm-4.7-flash.md) |
| Qwen3.6-35B-A3B | Project baseline | 36B / 3B | 40 layers, 30 Gated DeltaNet + 10 attention, 256 × 512 experts, 8 per token | Apache-2.0 | 262,144 | `<think>` | Family parsers | Vision `mmproj` | repo: `models/qwen3.6-35b-a3b/README.md` |
| **Ornith-1.5-35B-A3B** | Project baseline | 36B / 3B | Same shapes as Qwen3.6; `qwen3_5_moe`; built on Qwen3.5 and Gemma4 with continued training and RL | MIT | 262,144 | `<think>` by default | `<tool_call>`; `qwen3_xml` (vLLM), `qwen3_coder` (SGLang) | Vision, 0.9 GB `mmproj` | [card](https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B), repo: `models/ornith-1.5-35b/README.md` |
| Flint (Recursive) | Project flagship | 39.8B / 2.5B ([Unsloth](https://unsloth.ai/docs/models/flint.md) benchmark notes say ~2B) | 49 layers (2 dense, 47 MoE), 35 sliding + 14 full attention, vocab 150,144 | Apache-2.0 | 262,144 | `reasoning_content`, keep in history | OpenAI-compatible, use checkpoint's template | Text only (none noted) | [card](https://huggingface.co/RecursiveSI/flint) |

**Newest releases checked, outside the size band**
- Unsloth's index lists newest first (order is an inference): DeepSeek-V4.1-Flash, Qwen3.8, Qwen3.8-Flash-Next, Flint, Mistral Large 4, Nemotron 3.5 Bolt, MiniMax-M3.1-Flash, GLM-5.3-Flash, Muse Spark Open — [Unsloth index](https://unsloth.ai/docs/models).
- Too large for this brief: GLM-5.3-Flash is 320B / 18B ([Unsloth](https://unsloth.ai/docs/models/glm-5.3-flash.md)), Reflection Beam is 501B ([Unite.AI](https://www.unite.ai/reflection-releases-beams-open-weights-under-apache-2-0-license/)), DeepSeek V4.1 Flash is 552B ([Hashnode](https://hashnode.com/blog/best-open-weight-llms)). I found no small DeepSeek or small GLM-5 model.
- Kimi K3.1 Pro weights were promised by Nov 4, with no repo visible on Oct 28 ([Hashnode](https://hashnode.com/blog/best-open-weight-llms) lists it as watch-list only).
- The project's dense-model note found no official smaller Qwen3.8, and community layer-pruned cuts of ~20B and ~17B have no standard benchmarks — repo: `docs/research/notes/dense_27b_speedups.md` (dated 2026-10-22). The Qwen3.8-27B card mentions no smaller size ([card](https://huggingface.co/Qwen/Qwen3.8-27B)).

### Inferences
- Qwen3.5-9B is dense: its card's overview describes a plain FFN of 12,288, and "sparse MoE" appears only as a family-level highlight. The project already treats its big sibling Qwen3.8-27B as dense `qwen35`.
- Every Qwen-family candidate (9B, 27B, 35B-A3B, Ornith) shares tokenizer size, `<think>` and `<tool_call>` conventions. A dataset and template built for one should move to another with little change. This is the strongest argument for starting in that family.
- Laguna XS 2.1 is the candidate closest to Flint's shape (hidden 2,048, 256 × 512 experts, sigmoid router, ~512 sliding window). Its differences from Flint are top-8 against top-6, shared expert 512 against 1,024, and 40 layers against 49.

### Gaps
- Nemotron-Nano-9B-v2's HF card returned 401; its licence and BFCL figure are from secondary listings.
- Licences not confirmed from primary text: Ministral 3, GLM-4.7-Flash, Bolt-E4B and the terms of `lfm1.0` (including any revenue limit).
- Phi-4 appeared only in aggregator summaries and was not verified. No Phi-5 or LFM3 turned up in search.
- Gemma 4's exact parameter counts for the 12B tier and whether its audio and vision paths can be removed from a text-only build.

## Coding quality: benchmarks and which small models a coding agent can use

### Takeaway
No model at ~9B has strong agentic numbers: Qwen3.5-9B scores 14.6 on Terminal-Bench 2.0 and its best-known coding fine-tune about 24–28, while most of the 30–36B MoE class scores 36–68 (Nemotron 3.5 Lightning only 24) and Qwen3.8-27B 73, on differing Terminal-Bench versions. Elixir data exists only in the owner's own Elixir SWE Bench, and no model under 40B has been run there except Flint (6 of 20, one seed).

### Cited Findings

**Coding benchmarks (vendor-reported unless marked; versions differ)**

| Model | SWE-bench Verified | SWE-bench Pro | Terminal-Bench | LiveCodeBench v6 | Tool / agent benchmark | Source |
|---|---|---|---|---|---|---|
| Qwen3.5-9B | — | — | 14.6 (2.0, as quoted on OmniCoder's card) | 65.6 | BFCL-V4 66.1, TAU2 79.1 | [card](https://huggingface.co/Qwen/Qwen3.5-9B), [OmniCoder](https://huggingface.co/Tesslate/OmniCoder-9B) |
| OmniCoder-9B | — | — | 23.6 % (21/89) in text, 28.1 in metadata (conflict) | — | — | [card](https://huggingface.co/Tesslate/OmniCoder-9B) |
| Gemma 4 12B | — | — | — | 72.0 | Tau2 69.0 | [Unsloth](https://unsloth.ai/docs/models/gemma-4.md) |
| Granite 4.1 8B | — | — | — | — | HumanEval 85.37, MBPP 87.30, BigCodeBench 35.00, BFCL v3 68.27 | [card](https://huggingface.co/ibm-granite/granite-4.1-8b) |
| LFM2.5-8B-A1B | — | — | — | — | BFCLv3 64.36, BFCLv4 48.50; makers say not the best fit for heavy programming | [card](https://huggingface.co/LiquidAI/LFM2.5-8B-A1B) |
| Qwen3.8-27B | — | 61.7 | 73.0 (2.1) | 90.3 | DeepSWE 1.1 42.2 | [card](https://huggingface.co/Qwen/Qwen3.8-27B) |
| Qwen3.6-27B | 77.2 | 50.2 | 60.7 (2.1); [OrcaRouter](https://www.orcarouter.ai/blog/qwen-3-8-27b-benchmarks) says 63.4 | — | SciCode 39.8 | [Unsloth, Meta's table](https://unsloth.ai/docs/models/muse-glimmer.md) |
| Muse Glimmer 30B | 76.0 | 51.2 | 51.7 (2.1) | — | SciCode 43.6 | [Unsloth](https://unsloth.ai/docs/models/muse-glimmer.md) |
| Gemma 4 31B | 66.6 | 36.9 | 43.4 (2.1) | 80.0 | Tau2 76.9 | [Unsloth Muse](https://unsloth.ai/docs/models/muse-glimmer.md), [Unsloth Gemma](https://unsloth.ai/docs/models/gemma-4.md) |
| Gemma 4 26B-A4B | — | — | — | 77.1 | Tau2 68.2 | [Unsloth](https://unsloth.ai/docs/models/gemma-4.md) |
| Devstral Small 2 | 68.0 | — | 22.5 (2) | — | SWE-bench Multilingual 55.7 | [card](https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512) |
| Laguna XS 2.1 | 70.9 | 47.6 (public) | 37.5 (2.0) | — | SWE-bench Multilingual 63.1 | [card](https://huggingface.co/poolside/Laguna-XS-2.1) |
| North Mini Code 1.0 | 67.6 | 40.2 | 36 (2) | — | AA Coding Index 33.4 | [card](https://huggingface.co/coherelabs/north-mini-code-1.0), [AA](https://artificialanalysis.ai/articles/north-mini-code-cohere-s-small-coding-focused-moe-model) |
| Nemotron 3.5 Lightning | Not found | — | 24 % (2.1, AA measured) | — | AA Intelligence 24; PinchBench 86 % | [AA](https://artificialanalysis.ai/articles/nemotron-3-5-lightning-launch), [Unsloth](https://unsloth.ai/docs/models/nemotron-3.5.md) |
| GLM-4.7-Flash | 59.2 | — | — | 64.0 | τ²-Bench 79.5, AA Coding Index 25.9 | [Unsloth](https://unsloth.ai/docs/models/tutorials/glm-4.7-flash.md), [AA](https://artificialanalysis.ai/articles/north-mini-code-cohere-s-small-coding-focused-moe-model) |
| Qwen3.6-35B-A3B | 73.4 | — | 52.5 (Terminus-2) | — | AA Coding Index 35.2, AA Intelligence 32 | [Ornith card](https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B), [AA North](https://artificialanalysis.ai/articles/north-mini-code-cohere-s-small-coding-focused-moe-model), [AA Lightning](https://artificialanalysis.ai/articles/nemotron-3-5-lightning-launch) |
| **Ornith-1.5-35B-A3B** | 79 | 59.6 | 67.8 (2.1, Terminus-2), 68.5 (Claude Code harness) | — | SWE-bench Multilingual 71.4, DeepSWE 22, NL2Repo 46.2 | [card](https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B) |
| Flint | 74.2 | 89.7 (Pro v2) | 54.9 (2.1) | 80.3 | IFEval 95.1 | [card](https://huggingface.co/RecursiveSI/flint), [Unsloth](https://unsloth.ai/docs/models/flint.md) |
| gpt-oss-20B | 34.0 (GLM's table) | — | — | 61.0 (GLM's table) | AA Intelligence 24.5 | [Unsloth GLM](https://unsloth.ai/docs/models/tutorials/glm-4.7-flash.md), [AA](https://artificialanalysis.ai/articles/north-mini-code-cohere-s-small-coding-focused-moe-model) |

**Independent checks**
- OrcaRouter's roundup says every Qwen3.8-27B figure comes from Alibaba and treats them as a ceiling until others replicate them — [OrcaRouter](https://www.orcarouter.ai/blog/qwen-3-8-27b-benchmarks).
- Artificial Analysis lists no Intelligence or Coding Index for Qwen3.5-9B: no public API, so no evaluation — [AA page](https://artificialanalysis.ai/models/qwen3-5-9b).
- Aider polyglot: the Hashnode roundup reports no Aider scores, and the Qwen3.8-27B card lists none. I found none for any candidate — [Hashnode](https://hashnode.com/blog/best-open-weight-llms), [card](https://huggingface.co/Qwen/Qwen3.8-27B).

**Elixir**
- The owner's [Elixir SWE Bench results](https://cinderella-man.github.io/elixir-swe-bench/results.json) hold the only per-model Elixir data I found. Series seen through the fetch tool, on 20 cases:

| Series | Score | Seeds done | Harness | File size |
|---|---|---|---|---|
| Sonnet 5.5 | 90.0 % | 2 of 3 | claude_code 2.1.308 | — |
| Opus 5.5 | 88.33 % (18, 17, 18 of 20) | 3 of 3 | claude_code 2.1.308 | — |
| Qwen3.8-Flash-Next-Gyro-L, TQ3_0 | 55 % (11/20) | 1 of 3 | pi 1.2.0 | 108.3 GB |
| Qwen3.8-Flash-Next-GSQ-RCO, IQ1_M | 50 % (10/20) | 1 of 3 | pi 1.2.0 | 58.4 GB |
| Ornith-1.5-122B, UD-Q5_K_XL | 35 % (7/20) | 1 of 3 | pi 1.2.0 | 94.6 GB |
| Flint, Q8_0 | 30 % (6/20) | 1 of 3 | pi 1.2.0 | 42.3 GB |
| Ornith-1.5-122B, UD-Q3_K_XL | 30 % (6/20) | 1 of 3 | pi 1.2.0 | 59.8 GB |

- The benchmark's method: an agent (pi) edits a broken project in Docker, executable tests grade it, and there is no AI judge or speed score — [elixir-agent-benchmark](https://github.com/Cinderella-Man/elixir-agent-benchmark). That repo's README describes an eleven-case freeze, while the published results use 20 cases.
- The one other Elixir benchmark found, [evalcode](https://github.com/rizafahmi/evalcode), is a Phoenix 1.8 LiveView CRM graded by held-out tests. Its results table lists a hosted model only.

**What agents can actually use**
- Qwen3.5-9B Q8_0 on one Intel B580 with `--jinja` and 32k context returned a tool call that looked correct from Claude Code — [setup report](https://chun-tao.notion.site/llama-cpp-Deployment-Claude-Code-Setup-35ea933dad9d802da264d155a93c1801). Qwen Code with LM Studio gave a positive first impression — [Medium](https://medium.com/@kevin.drapel/your-local-qwen-with-qwen-cli-and-lm-studio-564ffb4c1e9e). OpenCode's data page marks it as tool-capable — [OpenCode](https://opencode.ai/data/alibaba/qwen3-5-9b.md).
- Gemma 4 12B is reported as plug-and-play by some, while others report a loop at the first step at q8 and a repetition loop on a simple prompt — [Reddit snapshot](https://reddit.sentinel-team.org/posts/1txdcj9/snapshots/2026-06-13T02%3A56%3A06.64152Z). Setup guides exist, but they come from a vendor of cloud access — [haimaker](https://haimaker.ai/blog/gemma-4-12b-ollama-opencode-setup/).
- Ornith's card recommends OpenCode, Hermes Agent and OpenClaw against a local endpoint — [card](https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B).
- On the project's agent check (pi, twelve Python and JavaScript tasks), Flint Q8_0 and Ornith-1.5-122B UD-Q2_K_XL both finished 12 of 12 on Miner Llama v2 — repo: `models/flint/README.md`, `models/ornith-1.5-122b/README.md`.

### Inferences
- Benchmarks suggest a clear gap: at ~9B a model is a usable assistant in simple tool loops, but it is well short of the 30–36B MoE class on long agent tasks.
- Flint scores 74.2 on SWE-bench Verified yet 30 % on Elixir, and Claude scores 88–90 %. This hints that language knowledge limits the local models on Elixir, which is what a fine-tune can add. The evidence is thin: one seed, and the harness differs (pi against claude_code).
- The first useful measurement is a baseline on Elixir SWE Bench for Qwen3.5-9B, OmniCoder-9B and Ornith-1.5-35B before any training. Nothing below can be ranked on Elixir until that exists.

### Gaps
- No Elixir score for any model under 39B. No published Aider polyglot, and no independent SWE-bench, for any ≤15B model.
- `results.json` was read through a summarising fetch; a direct read may show series I missed.
- No r/LocalLLaMA thread on Qwen3.5-9B with opencode was indexed, so real-world reports are few.

## Fine-tuning support: recipes, and known problems

### Takeaway
The Qwen3.5 family has the best tooling: Unsloth and Axolotl both support it, and a 9B BF16 LoRA fits one RTX 3090. Gemma 4 is about as well supported but has more reported training bugs. Flint has no Transformers modelling code, so it cannot be fine-tuned with this stack today; Laguna and North Mini Code have no recipes I could find.

### Cited Findings

**Recipes and memory**

| Model | Unsloth | Axolotl | TRL | LoRA VRAM | Fits on 5 × 3090 (24 GB each)? | Source |
|---|---|---|---|---|---|---|
| Qwen3.5-9B | Yes; guide, 9B vision notebook named but unlinked | Yes (added 2026/03); OmniCoder used it | Generic via Transformers v5, no recipe found | **BF16 LoRA 22 GB** | One card per copy | [Unsloth](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md), [Axolotl docs](https://docs.axolotl.ai/), [OmniCoder](https://huggingface.co/Tesslate/OmniCoder-9B) |
| Qwen3.8-27B | Kaggle notebook | QLoRA config (v0.19) | Generic | QLoRA 24 GB; LoRA >36 GB ([3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md) says 56 GB for 27B) | QLoRA on one card at the limit; LoRA on 2–3 | [Unsloth](https://unsloth.ai/docs/models/qwen3.8/train.md), [Axolotl v0.19](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.19.0) |
| Qwen3.5/3.6-35B-A3B, Ornith-1.5-35B | MoE notebook (A100) | Qwen3.5 MoE listed | Generic | BF16 LoRA 74 GB; `device_map = "balanced"` for multi-GPU | 4 cards | [Unsloth](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md) |
| Gemma 4 12B | Guide covers it; A100 notebooks for 26B and 31B | Unified LoRA configs | Generic | Not given | Likely 1–2 (est. from 9B) | [Unsloth](https://unsloth.ai/docs/models/gemma-4/train.md), [Axolotl v0.18](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.18.0) |
| Gemma 4 26B-A4B | A100 notebook | NVFP4 LoRA config `examples/gemma4/26b-a4b-moe-nvfp4-lora.yaml` | Generic | LoRA >40 GB | 2 cards | [Unsloth](https://unsloth.ai/docs/models/gemma-4/train.md), [Axolotl v0.18](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.18.0) |
| Granite 4.1 | Notebook labelled 4.0, adapt the name | Not checked | Generic | Not given | Likely 1 | [Unsloth](https://unsloth.ai/docs/models/ibm-granite-4.1.md) |
| LFM2.5-8B-A1B | Card links Unsloth or TRL notebooks for SFT, DPO, GRPO | Not checked | **Yes, on the card** | ~24 GB+ just to serve at BF16 | 1–2 | [card](https://huggingface.co/LiquidAI/LFM2.5-8B-A1B), [vLLM](https://docs.vllm.ai/projects/recipes/en/latest/LiquidAI/LFM2.5.html) |
| Ministral 3 | Notebooks for 3B; 14B said to fit a free Colab GPU | Not checked | Generic | Not given | 1 | [Unsloth](https://unsloth.ai/docs/models/tutorials/ministral-3.md) |
| Muse Glimmer 30B | Kaggle notebooks | Not checked | Generic | QLoRA 22.57 GiB measured (r=16, 1,024 tokens, batch 1); LoRA >40 GB | QLoRA 1 card | [Unsloth](https://unsloth.ai/docs/models/muse-glimmer/train.md) |
| GLM-4.7-Flash | A100 notebook | Yes | Generic | 16-bit LoRA ~60 GB | 3 cards | [Unsloth](https://unsloth.ai/docs/models/tutorials/glm-4.7-flash.md), [Axolotl docs](https://docs.axolotl.ai/) |
| Nemotron 3.5 Lightning | Supported, memory counts all 30B | Mamba handling noted below | Generic | Not given | Unknown | [Unsloth](https://unsloth.ai/docs/models/nemotron-3.5.md) |
| Laguna XS 2.1 | None found | None found | None found | — | — | Card has no guidance, 13 finetunes on the Hub: [card](https://huggingface.co/poolside/Laguna-XS-2.1) |
| North Mini Code 1.0 | None found | None found | Needs Transformers from source | — | — | 4 finetunes on the Hub: [card](https://huggingface.co/coherelabs/north-mini-code-1.0) |
| **Flint** | No training guide | None found | Blocked | — | — | Card says "Transformers modeling code is not included yet"; yet 15 finetunes and 1 adapter are listed: [card](https://huggingface.co/RecursiveSI/flint) |

- Published precedent for the exact task: OmniCoder-9B, LoRA r=64 alpha=32, AdamW, lr 2e-4, BF16, Axolotl, 4 × H200 DDP, 425K+ trajectories — [card](https://huggingface.co/Tesslate/OmniCoder-9B).
- Qwen3.5-9B has over 1,200 listed finetunes and a separate Qwen3.5-9B-Base checkpoint — [card](https://huggingface.co/Qwen/Qwen3.5-9B).

**Known problems**
- **QLoRA advice conflicts.** The Qwen3.5 guide says 4-bit is not recommended for dense or MoE models, while the Qwen3.8 guide offers QLoRA on 24 GB — [3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md), [3.8 guide](https://unsloth.ai/docs/models/qwen3.8/train.md). Gemma's guide also advises against MoE QLoRA ([guide](https://unsloth.ai/docs/models/gemma-4/train.md)).
- **Gradient checkpointing.** Recipes use `use_gradient_checkpointing = "unsloth"`; on out-of-memory keep it on and cut batch size and `max_seq_length` — [Qwen3.8 guide](https://unsloth.ai/docs/models/qwen3.8/train.md).
- **Gemma shared-KV.** E2B and E4B gave gibberish and diverged with `use_cache=False`, which Unsloth says it fixed. 31B and 26B-A4B hit an empty-cache IndexError in Transformers, and multimodal losses of 13–15 are normal on small sizes — [guide](https://unsloth.ai/docs/models/gemma-4/train.md). Axolotl's 31B LoRA had gradient spikes, now capped with lr 5e-5 and `max_grad_norm` 0.1 — [v0.19](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.19.0).
- **Hybrid architectures.**
  - Qwen3.5 needs Transformers v5, and its Mamba Triton kernels make the first run slow to compile — [guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md).
  - Axolotl's Qwen3.5 attention patches broke on Transformers 5.15 (fixed), and Qwen3.5 sample packing crashed on non-contiguous `position_ids` (fixed) — [v0.19](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.19.0).
  - Nemotron's SSM state leaked across packed sequences because a Mamba2 scan ignored `seq_idx`, so that scan is now probed at startup — [v0.19](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.19.0).
- **Chat template and tools.**
  - None of Unsloth's Qwen3.5, Qwen3.8 or Gemma guides cover tool-call templates — [3.5](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md), [3.8](https://unsloth.ai/docs/models/qwen3.8/train.md), [Gemma](https://unsloth.ai/docs/models/gemma-4/train.md).
  - Qwen templates raise "System message must be at the beginning" when a harness sends a second system message — [llama.cpp #20733](https://github.com/ggml-org/llama.cpp/issues/20733). Community replacement templates exist, unverified — [example](https://huggingface.co/sudiptosarkar/Qwen-Fixed-Chat-Templates).
  - Qwen3-Instruct models were misdetected as thinking models, which sent tool calls into `reasoning_content` — [llama.cpp #20809](https://github.com/ggml-org/llama.cpp/issues/20809).
  - GGUF exports that behave worse elsewhere usually have a wrong chat template or EOS token — [guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md).
  - GLM-4.7-Flash looped until GGUFs were re-made with the correct sigmoid `scoring_func` — [Unsloth](https://unsloth.ai/docs/models/tutorials/glm-4.7-flash.md).
- **Thinking tokens.**
  - All three guides advise keeping at least 75 % reasoning examples to preserve reasoning — [Qwen3.5](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md), [Gemma](https://unsloth.ai/docs/models/gemma-4/train.md), [GLM](https://unsloth.ai/docs/models/tutorials/glm-4.7-flash.md).
  - History differs by model: Qwen3.5's page says prior turns should hold only the final output ([GGUF card](https://huggingface.co/unsloth/Qwen3.5-9B-GGUF)). Qwen3.8 has `preserve_thinking` on ([card](https://huggingface.co/Qwen/Qwen3.8-27B)), and Laguna, North and Flint ask that reasoning stays in history ([Laguna](https://huggingface.co/poolside/Laguna-XS-2.1), [North](https://huggingface.co/coherelabs/north-mini-code-1.0), [Flint](https://huggingface.co/RecursiveSI/flint)).

### Inferences
- The VRAM figures above come from short sequences. Agent traces are far longer than Muse Glimmer's measured 1,024 tokens, so a 22 GB 9B LoRA will likely not hold at agent length on 24 GB. OmniCoder needed 4 × H200. Plan for truncated or windowed traces, or a QLoRA, on the 3090s.
- Training data must be rendered with the template used at inference, and its history rule (thinking kept or stripped) must match, or tool discipline will degrade after export. For Qwen3.5-9B this means stripped prior-turn reasoning unless the template is changed.
- Flint's 15 Hub finetunes show that someone trained it, or that the tags are loose. Until a modelling file exists, a Flint fine-tune means writing and validating that code first.

### Gaps
- Whether Unsloth's 22 GB holds beyond short sequences, and any measured VRAM per sequence length for 9B.
- RTX 3090 (Ampere) compatibility of Axolotl's NVFP4 MoE-LoRA path, whose notes discuss Blackwell. I found no statement either way.
- How the Flint Hub finetunes were produced.
- TRL-specific recipes for most models. "Generic" above means no model-specific recipe was found.

## Dense vs mixture of experts as a fine-tuning target

### Takeaway
MoE saves nothing in training memory: a 35B-A3B LoRA needs 74 GB against 22 GB for 9B dense, because all experts stay loaded. MoE's advantage is speed and quality at inference. On this rig a 3B-active MoE should run about 1.5–2× faster than a 9B dense model (est.) and starts far stronger, but LoRA on fused experts is immature, so most of a MoE LoRA lands on attention and the shared expert.

### Cited Findings
- **Memory scales with total parameters.** Unsloth's BF16 LoRA table: 9B 22 GB, 27B 56 GB, 35B-A3B 74 GB, 122B-A10B 256 GB — [guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md). Its Nemotron page says the full 30B still count toward memory ([Unsloth](https://unsloth.ai/docs/models/nemotron-3.5.md)), and vLLM says all of LFM2.5-8B's experts stay in VRAM ([recipe](https://docs.vllm.ai/projects/recipes/en/latest/LiquidAI/LFM2.5.html)).
- **Precision.** Use BF16 for MoE; MoE QLoRA is not recommended, and router fine-tuning is off by default for stability — [guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md). GLM's page also disables the router by default ([Unsloth](https://unsloth.ai/docs/models/tutorials/glm-4.7-flash.md)).
- **Fused experts.**
  - One author's Qwen3.6-35B-A3B fine-tune says the 256 routed experts are fused tensors, so per-expert PEFT does not apply. They froze experts and router and trained r=16 on shared-expert and attention projections: ~8.4M trainable parameters, 0.024 % of the model — [card](https://friendli.ai/models/srallaba/tarak-qwen3.6-35b-a3b-rsi-v1).
  - A second card, seen only in a search snippet, says a plain PEFT merge on the fused base matches none of the expert LoRA weights, and that the fused layout needs Transformers ≥ 5.10. I could not confirm this on the [mirror page](https://friendli.ai/models/Writer/qwen3.6-35b-a3b-cigna-palmyra-asft-fp8-blockwise).
  - Unsloth's quickstart LoRA targets attention and dense MLP projections, and the snippet shows no expert targets — [search result of guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune).
- **Axolotl's expert path.**
  - ScatterMoE gained fused NVFP4 and bnb-4bit expert paths for Gemma 4 and DeepSeek-V4, with active VRAM nearly flat from 4k to 32k context — [v0.18](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.18.0).
  - Merging into quantized bases now dequantizes experts first, and `lora_rank_pattern` sets rank per module — [v0.18](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.18.0).
  - Gated DeltaNet LoRA projections use a fused kernel — [v0.18](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.18.0).
  - A dedicated Qwen3.5 MoE LoRA kernel is not described in those notes.
  - An overflow could corrupt memory in the grouped kernel for stacks over 2³¹ elements (fixed) — [v0.19](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.19.0).
- **Fine-tuning does move MoE models.** Ornith-1.5-35B, which continued training from Qwen3.5/Gemma4 lineage with RL, reports 67.8 on Terminal-Bench 2.1 and 79 on SWE-bench Verified, against 52.5 and 73.4 for Qwen3.6-35B-A3B — [card](https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B). That is a lab-scale training run, not a LoRA.
- **Fine-tuning moves dense models too.** OmniCoder's LoRA took Terminal-Bench from 14.6 to 23.6–28.1, self-reported — [card](https://huggingface.co/Tesslate/OmniCoder-9B).
- **On the rig, bytes read per token decide speed.** The dense Qwen3.8-27B ran at 7.5 tok/s where Qwen3.6-35B-A3B ran ~4.7× faster — repo: `docs/what_i_tried.md`. A 256-expert model reads 8 of 256 experts per layer, and dense tensors are ~75 % of a token's bytes — repo: `models/ornith-1.5-35b/README.md`.

### Inferences
- **Trainable coverage (my calc).** At r=16 a LoRA on all routed experts of a 40-layer 2,048 × 512 model is ~1.26B parameters (3 projections × 16 × 2,560 × 256 × 40). That is ~150× the 8.4M shared-plus-attention LoRA, and itself about 3.5 % of the model, so it costs real memory. Each expert sees only about 1 token in 32 at top-8, so per-expert updates are sparse. A shared-plus-attention-plus-Gated-DeltaNet LoRA sees every token, which suggests it will do most of the useful work. I found no measurement comparing the two.
- **Throughput (my calc, rough).** A 9B copy fits one 3090, so DDP uses five cards in parallel, and LoRA-only gradients are small. A 35B-A3B copy spans four cards, and `device_map` runs them one at a time. MoE computes about a third of the parameters per token, so 9B DDP comes out at about 1.7× the 35B throughput (5 ÷ 3). The two are the same order, so memory, not speed, is the real difference. Unverified: the box's PCIe layout could cut model-parallel throughput further.
- **Better target, dense or MoE?** For **iteration** the 9B dense wins: one card, simple merge, every weight reachable. For the **final product** the 3B-active MoE wins on both start quality and rig speed. Both are worth doing, and the shared family makes that cheap.
- A LoRA adds domain knowledge and habits; it is unlikely to close a 3× gap in long-task planning. Starting strength of the base should weigh heavily for agent work.

### Gaps
- No published comparison of LoRA on experts against LoRA on shared expert and attention, for coding or any domain.
- No measured training throughput per card for 9B dense against 35B-A3B.
- Exact Axolotl config keys for expert LoRA on `qwen3_5_moe`: the release notes describe kernels, not targets.

## GGUF, LoRA export, Miner Llama kernels and estimated rig speed

### Takeaway
Every candidate except possibly a brand-new variant has an architecture in the fork's tree, and any fine-tune should be merged in PyTorch, converted from BF16 and quantized as usual rather than run as a live adapter. By estimate, a 9B dense file reaches about 19–23 tok/s (Q4_0) on v2.0, about half of Flint, while Laguna and the 35B MoEs can approach 33–48 tok/s with work already planned.

### Cited Findings

**Engine support (read from the fork's tree at `37e717ff6`, `src/llama-arch.cpp`, `src/models/`)**
- Present: `flint`, `gemma4`, `laguna`, `lfm2moe`, `granite`, `granitehybrid`, `nemotron_h`, `nemotron_h_moe`, `cohere2moe`, `muse-glimmer`, `mistral3`, `mistral4`, `qwen35`, `qwen35moe`, `openai-moe`, `deepseek2`.
- The fork also ships `convert_lora_to_gguf.py` and `tools/export-lora`, plus `conversion/flint.py` and `conversion/laguna.py`.
- Laguna arrived upstream in [PR #25165](https://github.com/ggml-org/llama.cpp/pull/25165), merged 2026-07-22. That PR was CPU-first with CUDA deferred to follow-ups, so GPU behaviour needs checking. The Laguna card still says to build from the PR ([card](https://huggingface.co/poolside/Laguna-XS-2.1)), which predates the merge.
- Devstral Small 2 GGUFs needed llama.cpp PR #17945 ([card](https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512)).

**Kernel coverage (repo: `README.md`, `models/flint/README.md`, `docs/research/notes/model_branches.md`)**
- Pascal matrix-vector kernels cover Q4_0, Q4_1, Q5_0, Q8_0, Q5_K and IQ4_XS for any model. Q6_K is built and waiting for its rig gate, Q4_K is planned, and K-quant files run on upstream kernels today. These apply to any architecture.
- The persistent MoE kernel has compile-time shapes (hidden 2,048, 256 experts, top-6, widths 512 and 1,024), sigmoid-renormalized routing only, and covers Flint's shapes; it gave +5.6–8.8 % per token.
- Pipelined speculation works on attention-only models on v2.0. Hybrid recurrent models (Qwen3.5/3.6/3.8, Ornith) need the built but not yet timed Q162 work, and `--pipe-depth` fails on them in v2.0.

**LoRA export**
- Unsloth exports with `save_pretrained_gguf` (q4_k_m, q8_0, f16), or `save_pretrained_merged` with `merged_16bit` — [3.5 guide](https://unsloth.ai/docs/models/qwen3.5/fine-tune.md), [3.8 guide](https://unsloth.ai/docs/models/qwen3.8/train.md).
- A llama.cpp maintainer said the LoRA conversion script has trouble with tensors permuted during conversion and recommended merging in PyTorch, then converting — [issue, as summarised in search](https://github.com/ggerganov/llama.cpp/issues/7062). `convert_lora_to_gguf` was also reported to ignore `outtype` ([#10671](https://github.com/ggml-org/llama.cpp/issues/10671)).
- One community conversion of a Qwen3.6 LoRA needed a one-hunk fix to `conversion/qwen.py` around the reordered V heads. This is a single unverified source — [card](https://huggingface.co/ivanfromm/MiniMax-H3-Prompt-Rewriter-LoRA-GGUF).
- Multimodal checkpoints can stop `convert_lora_to_gguf.py` with an unmapped `vision_tower` tensor — [write-up](https://zenn.dev/akakagerengoku/articles/5561bf474b59fa).
- `llama-export-lora` merges adapters into a base and writes a new file, and its README does not say whether a quantized base is allowed — [README](https://github.com/ggml-org/llama.cpp/blob/master/tools/export-lora/README.md).
- OmniCoder-9B ships GGUF quants, including q4_k_m ([card](https://huggingface.co/Tesslate/OmniCoder-9B)), and the base has Q4_0 5.38 GB, Q4_K_M 5.68, Q6_K 7.46 and Q8_0 9.53 GB ([Unsloth GGUF](https://huggingface.co/unsloth/Qwen3.5-9B-GGUF)).

**Project anchors used for scaling (repo)**

| Anchor | Bytes per token | Measured | Project estimate | File |
|---|---|---|---|---|
| Flint Q8_0, v2, 262k, agent check | — | 29.3 tok/s plain, 44.6–45.9 with `--pipe-depth 4` | | `models/flint/README.md` |
| Qwen3.6 Q4_0, v1 | 2.08 GB | 29.0 (4 cards), 31.1 (5 cards), one request | 39–48 with Q6_K kernel and pipelining | `models/qwen3.6-35b-a3b/README.md`, `model_branches.md` |
| Ornith-1.5-35B | 2.02 GB (Q4_K_M) | not run | 19–23 Q4_K_M, 29–31 Q4_0, 30–36 with kernels, 16–20 Q8_0 | `models/ornith-1.5-35b/README.md` |
| Qwen3.8-27B Q4_0 | 15.33 GB | 4.3 with CUDA graphs; 7.5 with MTP on real chat requests | 6.7–7.1 with kernels, 7.2–7.7 with Q6_K, ×1.2–1.45 pipelined | `model_branches.md`, `docs/overview.md` |
| Llama-2-7B Q4_0, one card, stock | 3.75 GB | 19.5 | 27–31 with kernels | `model_branches.md` |
| Qwen3-30B-A3B Q4_K_M | ~1.9 GB (est.) | not run | ~22, 33–40 with kernels, ×1.3–1.5 pipelined | `model_branches.md` |

**Estimated rig speed (generation, one stream; ALL ESTIMATES, none of these models has run on the rig except where noted)**

Bytes per token ≈ file minus input embedding (my calc; headers not read). Q4_0 file sizes for models other than Qwen3.5-9B use 0.56 GB per billion parameters from its 5.38 GB file.

| Model, file | Est. GB per token | Scaled from | Est. tok/s on v2.0 | Est. tok/s with planned work | Notes |
|---|---|---|---|---|---|
| **Qwen3.5-9B Q4_0** | ~4.8 | Qwen3.8-27B ÷ 3.2; Llama-2 × 0.78 | **19–23** | 23–33 (Q6_K + Q162) | No pipelining on v2.0; 2 cards at least; head is ~16 % of bytes (my calc) |
| Qwen3.5-9B Q8_0 | ~8.5 | Flint's ~150 GB/s Q8_0 decode as a ceiling (≤ ~18) | 12–16 | 14–23 (Q162) | 2–3 cards |
| Granite 4.1 8B Q4_0 | ~4.3 | Llama-2 × 0.87 | 23–27 | 26–35 spread for pipelining | Attention-only |
| Gemma 4 12B Q4_0 | ~6.2 | Llama-2 × 0.60 | 16–19 | 18–25 pipelined | Attention-only, pipelining available today |
| Ministral 3 14B Q4_0 | ~7.3 | Llama-2 × 0.51 | 14–16 | 15–20 | Attention-only assumed |
| Devstral Small 2 Q4_0 | ~13 | Qwen3.8-27B × 1.15 | 8–9 | 9–12 | |
| Qwen3.8-27B Q4_0 | 15.33 | Measured 4.3 / 7.5 | 6.7–7.7 | 8.6–11 | |
| Muse Glimmer 30B, Gemma 4 31B Q4_0 | ~16.5 | Qwen3.8-27B × 0.93 | 6–7 | 7–10 | |
| Gemma 4 26B-A4B Q4_0 | ~2.6 | Qwen3.6 × 0.8 | 23–25 | 30–37 pipelined, today | Attention-only; expert file mix not read |
| North Mini Code Q4_K_M | ~1.9 | Qwen3-30B-A3B | ~22, 29–33 pipelined | 33–40 before pipelining, with K-quant kernels | Attention-only; 128 experts |
| Laguna XS 2.1 Q8_0 | ~3.2 | Flint × 0.83 by active parameters; −6–8 % without persistent kernel | 22–24, 33–38 pipelined | up to ~38 with a top-8 persistent kernel | Attention-only; **CUDA path unverified** |
| Qwen3.6, Ornith-1.5-35B Q4_0 | ~2.1 | Measured on Qwen3.6 | 29–31 | 39–48 (project estimate) | Fine-tuned file would be re-quantized |
| Flint Q8_0 | | **Measured** | **44.6–45.9** | | Not fine-tuneable today |
| LFM2.5-8B-A1B Q4_0 | ~0.85 | Bytes alone suggest ≥ 50 | Not estimated | | Convolution layers never measured on the rig |

### Inferences
- **Export path:** merge in PyTorch to BF16 safetensors, run the fork's `convert_hf_to_gguf` path, then quantize with the project's own recipes (P-Q5 and PK-Q4-i style files are built from BF16 in minutes: repo `models/ornith-1.5-35b/README.md`). Merging also gives a clean file that the Pascal kernels and pipelining see as a normal model.
- Do not serve a live `--lora` adapter on the rig. It would add extra operations per tensor, and the fork's kernel matching is built around the plain graph, so it likely loses kernel speed (inference from how the matcher is described, not tested).
- Since the merge changes all tensors, per-file artefacts built for a base model need rebuilding: importance matrices, screen files and drafters. MTP layers carried in the file were trained for the base weights, so their acceptance rate may fall (inference).
- Dense 9B on Q4_0 is near the Pascal-kernel-friendly case, but its Q6_K head is a sixth of its bytes. The Q6_K kernel and any head treatment matter more here than on the 27B.
- A 9B file costs little memory: at Q4_0 several copies could fit on nine cards, serving parallel conversations. That does not help a single agent.

### Gaps
- No Laguna, North, Gemma 4, Granite or Qwen3.5-9B run on the rig: all figures above are scaling estimates, and hidden sizes of 12B and Granite were not read.
- Whether Miner Llama's CUDA graph capture or pipelined speculation meets `laguna` and `gemma4` graphs correctly (sliding windows need `n_ubatch` ≥ slots: repo `model_branches.md`).
- North Mini Code's llama.cpp arch mapping: `cohere2moe` is an inference from the fork's arch list, not read from a GGUF header.
- Whether llama.cpp's tool-call parsing handles `poolside_v1` and `cohere_command4` output without their dedicated parsers.
- Whether `llama-export-lora` accepts a quantized base.

## Best starting point for agentic Elixir

### Takeaway
No base model is known to be good at Elixir. For tool discipline and size together, the best clean start is Qwen3.5-9B, and OmniCoder-9B shows what a LoRA can add, but its training traces come from proprietary models, which conflicts with this project's data rule.

### Cited Findings
- No Elixir score exists for any model under 39B; Flint scored 6 of 20 on one seed — [results](https://cinderella-man.github.io/elixir-swe-bench/results.json).
- OmniCoder-9B's card says it learned read-before-write, responding to LSP diagnostics and minimal edit diffs, and that tool calling works best with scaffolding like its training data — [card](https://huggingface.co/Tesslate/OmniCoder-9B). These behaviours are claims of the publisher, not measured by a third party.
- OmniCoder's traces come from Claude Opus 4.6, GPT-5.4, GPT-5.3-Codex and Gemini 3.1 Pro through Claude Code, OpenCode, Codex and Droid — [card](https://huggingface.co/Tesslate/OmniCoder-9B).
- The project's rule allows only strict, publishable sources for training — owner, 2026-10-25 (auto-memory "Publishable data only"; also the rule against ShareGPT prompts).
- Ornith-1.5-35B tops the 3B-active class across SWE-bench Multilingual 71.4, Terminal-Bench 67.8 and SWE-bench Verified 79, and was tuned with an RL loop on scaffolds — [card](https://huggingface.co/ornith-ai/Ornith-1.5-35B-A3B). Multilingual is the nearest public proxy for non-Python work; Laguna XS 2.1 scores 63.1 and Devstral Small 2 55.7 ([Laguna](https://huggingface.co/poolside/Laguna-XS-2.1), [Devstral](https://huggingface.co/mistralai/Devstral-Small-2-24B-Instruct-2512)).
- Qwen3.5-9B scores TAU2 79.1 and BFCL-V4 66.1 against Gemma 4 12B's Tau2 69.0, so its tool discipline looks better, while Gemma leads on LiveCodeBench, 72.0 to 65.6 — [Qwen](https://huggingface.co/Qwen/Qwen3.5-9B), [Gemma](https://unsloth.ai/docs/models/gemma-4.md).

### Inferences
- OmniCoder-9B's value is as a comparison and a proof of method. Using it as the base would inherit traces of unclear provenance, and it could not then be called clean under the owner's rule. This is a project-rule conclusion, not a legal one.
- Elixir traces should be generated from permissively licensed Elixir repositories and tests, in the exact template of the base. Another researcher covers data, so this is only the constraint from the base-model side.
- For size-class choice, tool discipline should outrank LiveCodeBench: Elixir SWE Bench is an agent task with tool loops, not a one-shot puzzle.

### Gaps
- Whether any Hub fine-tune targets Elixir or BEAM languages: none surfaced in search.
- Per-language results in Multilingual or AutoCodeBench for these models. One blog cites Elixir's strong AutoCodeBench showing across languages, which says nothing about which small model does best ([CodeMySpec](https://codemyspec.com/blog/why-elixir-is-the-best-language-for-llms)).

## Ranking, first pick, second pick, and what to avoid

### Takeaway
**First pick: Qwen3.5-9B** as the first fine-tune, for its size, recipes, licence and one-card LoRA. **Second pick: Ornith-1.5-35B-A3B**, the likely end product once the data and recipe are proven, since it shares the family and starts far stronger and faster on the rig. Keep Flint on watch; avoid dense models above 20B for the rig, and avoid Mamba hybrids and LFM for this purpose.

### Cited Findings
Evidence for each rank is in the sections above, cited at the point of each fact. This section's ordering is my judgement, so it is under Inferences.

### Inferences

| Rank | Model | Why | Main risk |
|---|---|---|---|
| **1** | **Qwen3.5-9B** (Apache-2.0) | BF16 LoRA in 22 GB on one 3090, so DDP on five; Unsloth and Axolotl recipes; 1,200+ finetunes; LoRA precedent (OmniCoder); `-Base` checkpoint for continued pretraining; `qwen35` in the fork; est. 19–23 tok/s Q4_0 | Weak agent start (Terminal-Bench 14.6); about half of Flint's speed; `--pipe-depth` waits on Q162; template system-message bug in harnesses |
| **2** | **Ornith-1.5-35B-A3B** (MIT) | Best 3B-active agentic numbers, Multilingual 71.4; same family, so data and template carry over; est. 29–31 tok/s Q4_0, 39–48 with planned work; BF16 base and imatrix were built earlier (repo; confirm they are still available) | 74 GB LoRA, four 3090s; expert LoRA immature, so mostly shared-plus-attention; continuation of a heavily tuned model may gain less |
| 3 | Gemma 4 12B (Apache-2.0) | Attention-only, so pipelining works today; LiveCodeBench 72.0; Unsloth and Axolotl | Community loops; custom tool syntax; shared-KV training history; no coding fine-tune precedent |
| 4 | Laguna XS 2.1 (OpenMDW-1.1) | Nearest to Flint's shape; attention-only; SWE-bench Verified 70.9; est. 33–38 tok/s pipelined | No recipe found; custom class; CUDA path unverified; ~70 GB LoRA (est. from 35B) |
| 5 | Gemma 4 26B-A4B (Apache-2.0) | Attention-only MoE; Axolotl ships an NVFP4 LoRA config; est. 30–37 tok/s pipelined | Fused-expert path on Ampere unverified; agentic scores not published |
| 6 | North Mini Code 1.0 (Apache-2.0) | Coding-tuned, attention-only, AA Coding Index 33.4 | No recipe; Transformers from source; custom parser |
| 7 | Granite 4.1 8B (Apache-2.0) | Small, attention-only, est. 23–27 tok/s, clean licence | No thinking, no agent evidence, BigCodeBench 35 |

**Watch**
- **Flint:** the rig's fastest (44.6–45.9 tok/s) and the model all engine work targets, with a Python-style SWE-bench Verified of 74.2. It has no Transformers modelling code. If that appears, or if the owner writes it, Flint moves to the top on rig grounds, though its Elixir start is only 30 %.
- **Qwen3.8-Flash-Next:** 50–55 % on Elixir SWE Bench, the best local result. Outside this size brief; `qwen-community-1.0` is a custom licence ([Hashnode](https://hashnode.com/blog/best-open-weight-llms)) and it needs 120 GiB on one B300 to train ([Axolotl v0.19](https://github.com/axolotl-ai-cloud/axolotl/releases/tag/v0.19.0)).

**Avoid, and why**
- **Qwen3.8-27B, Muse Glimmer 30B, Gemma 4 31B, Devstral Small 2:** strong or decent scores, but est. 6–9 tok/s on the rig as a single stream. The project measured the 27B at 4.3–7.5 tok/s. They suit a quality-first server, not this rig. Qwen3.8-27B remains useful as a reference or trace generator.
- **OmniCoder-9B as a base:** provenance of traces against the owner's data rule; conflicting Terminal-Bench figures on its own card. Use it as a yardstick.
- **Nemotron-Nano-9B-v2:** 2025 model, non-Apache licence per secondary sources, Mamba hybrid, no coding results.
- **Nemotron 3.5 Lightning:** Terminal-Bench 2.1 only 24 % per AA, and Mamba state handling adds training risk. Its published data and recipes are worth reading regardless.
- **LFM2.5-8B-A1B:** makers say it is not the best fit for heavy programming; no coding benchmarks; convolution layers unmeasured on the rig. It would be fast, so it could return as a drafter candidate rather than as a coder.
- **GLM-4.7-Flash:** overtaken (AA Coding Index 25.9, SWE-bench Verified 59.2), 60 GB LoRA, and the project notes `-fa off` on Pascal.
- **Ministral 3, Phi-4, Bolt-E4B:** no coding-agent evidence found.

**Suggested order of work**
1. When a GPU machine is on, baseline Qwen3.5-9B, OmniCoder-9B and Ornith-1.5-35B on Elixir SWE Bench with all three seeds, alongside Flint's missing seeds.
2. Fine-tune Qwen3.5-9B first to prove data, template, merge, GGUF and tool behaviour end to end.
3. Repeat on Ornith-1.5-35B with shared-plus-attention-plus-Gated-DeltaNet LoRA, using the same dataset, and compare on the same bench.
4. Decide by Elixir pass rate and agent-check speed, the project's own measure.

**What would change the ranking**
- If Ornith-1.5-35B's Elixir baseline is far above Qwen3.5-9B's and four cards are free, skip step 2's long run and go straight to Ornith after a short pilot.
- If Q162 proves slower than estimated on the rig, Gemma 4 12B or Laguna gain ground, because they do not need it.
- If a Flint modelling file appears, re-rank at once.

### Gaps
- The ranking rests on vendor benchmarks and scaled estimates, with no Elixir baseline for any candidate above except Flint, and no rig run of ranks 1, 3, 4, 5, 6 or 7.
