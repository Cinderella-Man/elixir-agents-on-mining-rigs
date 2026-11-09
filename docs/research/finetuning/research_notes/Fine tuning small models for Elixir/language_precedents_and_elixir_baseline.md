# Language-specific fine-tuning precedents and the Elixir baseline (as of 2026-11-02)

Scope note for the report writer: the owner's own dataset (`Cinderella-Man/elixir-sft-dataset`) is not counted anywhere below. "pp" means percentage points. Numbers are self-reported by their authors unless marked otherwise. Hand arithmetic (differences between two quoted numbers) is mine and is marked "computed" where it matters.

## Elixir/BEAM: has anyone fine-tuned a model for Elixir, Erlang, Gleam, Phoenix, LiveView or Ash?

### Takeaway
Yes for Elixir: about ten attempts exist, and exactly two have measured results. The best is jmarceno's October 2026 pair (Gemma 4 12B and Qwen2.5-Coder-3B, 31/128 to 46/128 and 45/128 on a private executable harness); the other is a 2025 ACL workshop paper on StarCoder2 and DeepSeek-Coder with weak, mixed gains. For Gleam there is one strong academic result; for Erlang one 2023 proof of concept with no retrieved score. I found no measured attempt for Phoenix, LiveView, Ash or Ecto, and none at all that measures agentic work.

### Cited Findings

**Attempts with a measured result**

- **jmarceno/Elixir-Gemma-4-12B** (repo created 2026-10-04). Base is the Gemma 4 12B QAT instruct checkpoint. On a 128-task executable harness (one Elixir module per task, must parse, compile and pass tests on Elixir 1.20.2 / OTP 29, one completion at temperature 0, 16,384-token context, llama.cpp, both models as 4-bit GGUF): 31/128 (24.2%) to 46/128 (35.9%), +11.7 pp, +48% relative. Warning-free output rose from 46.9% to 58.6%. By area: stdlib 6 to 10, errors 8 to 11, OTP 2 to 4, BEAM 1 to 3, abstractions 1 to 3 (all out of 16). — [Model card](https://huggingface.co/jmarceno/Elixir-Gemma-4-12B); creation date from [HF API listing](https://huggingface.co/api/models?author=jmarceno&limit=50)
- **jmarceno/Elixir-Qwen2.5-Coder-3B** (created 2026-10-04). Base is Qwen2.5-Coder-3B-Instruct with one transformer block added (36 to 37 layers, about 3.16B parameters). Same harness, both as Q8_0: 31/128 (24.2%) to 45/128 (35.2%), +10.9 pp, +45%. Binaries 0 to 5, abstractions 5 to 9, core 3 to 6, collections 4 to 6 (of 16). Warning-free 60.2% to 74.2%. Carries the Qwen Research License, so commercial use needs a separate licence. — [Model card](https://huggingface.co/jmarceno/Elixir-Qwen2.5-Coder-3B)
- **What jmarceno trained on** (the model cards omit this; it comes from the dataset cards, published 2026-10-26): 4,712 SFT rows in 10 configs, of which `evalfmt-v0` (1,656 rows, frozen) was used for the first Gemma/Qwen round and `evalfmt-v2` (2,778 rows: 2,222 solve, 556 repair) is current. Rows are synthetic original task specs with canonical answers run through a compile plus ExUnit plus static-contract scorer, shipped only at zero test failures. `evalfmt-v2` family counts: core 580, otp 536, binaries 448, beam 304, functional 256, abstractions 250, collections 170, errors 130, stdlib 104. The card names Gemma 4 12B, Qwen3.5-9B, Qwen2.5-Coder and MiniCPM5-1B as trained on it, says continued-pretraining corpora are published separately without a link, keeps the 128 eval tasks private, and states the data is not intended for multi-turn agentic work or repository-scale refactors. — [elixir-sft card](https://huggingface.co/datasets/jmarceno/elixir-sft)
- **jmarceno preference data**: 909 rows (654 DPO pairs, 76 KTO examples, 179 on-policy rows), mined from failures of `gemma12b-elixir-cpt-q4` (40/128) and `qwen35-9b-elixir-cpt-sft-q5` (46/128) and re-targeted onto new tasks. Largest weakness buckets: format-hygiene 114, enum-state 99, err-swallow 42. Seven on-policy rounds target a depth-expanded Qwen2.5-Coder-3B checkpoint. No per-stage gains are reported. — [elixir-preference card](https://huggingface.co/datasets/jmarceno/elixir-preference)
- **Andriushchenko and Ivanov, ACL SRW, July 2025** ("Evaluating Tokenizer Adaptation Methods for LLMs on Low-Resource Programming Languages"). Fine-tuned StarCoder2-3B and DeepSeek-Coder-1.3B on 224,000 raw code samples from Stack v2 (Elixir subset 1.8M files), one epoch, LR 5e-5. Elixir pass@1 base to fine-tuned: MultiPL-E HumanEval 9.28 to 16.10 and 15.01 to 16.68; MBPP 6.87 to 10.47 and 4.11 to 6.70; McEval (50 tasks) 20 to 28 and 38 to 28 (a fall for DeepSeek). ZeTT tokenizer adaptation on DeepSeek reached 17.79 (HumanEval) and 22.36 (MBPP), or 24.66 on MBPP with the original tokenizer. Python collapsed after tuning, e.g. StarCoder2 HumanEval 30.43 to 4.26 and MBPP 41.98 to 0.19. — [ACL paper PDF](https://aclanthology.org/2025.acl-srw.57.pdf). The repos under `datapaf/*_elixir` (March to May 2025, near-empty cards) look like these weights: the paper's code lives at [github.com/datapaf/LRPLTokenizerAdaptations](https://aclanthology.org/2025.acl-srw.57.pdf) and the [HF listing](https://huggingface.co/api/models?search=elixir&limit=100&sort=lastModified) shows matching ft/fvt/focus/zett names for StarCoder2 and DeepSeek.
- Same paper, unexpected transfer: DeepSeek-Coder fine-tuned on **Racket** scored 17.68 on Elixir MBPP against 4.11 for base and 6.70 for the Elixir fine-tune, which the authors attribute to functional idioms such as recursion with accumulators. — [ACL paper PDF](https://aclanthology.org/2025.acl-srw.57.pdf)

**Attempts with no measured result**

| Attempt | Date | Base | Data | Method | Result |
|---|---|---|---|---|---|
| arpieb personal-copilot LoRAs | Nov 2023 | StarCoderBase 3B and 7B | The Stack dedup, Elixir subset | QLoRA, FIM, 2,000 steps, RTX 4090 | None; called a first pass — [card](https://huggingface.co/arpieb/peft-lora-starcoderbase-7b-personal-copilot-elixir) |
| DockYard tutorial (Sean Moriarity) | 2023-12-12 | deepseek-coder-1.3b-base | elixir-nx org repos; run capped at 200 batches | FIM in pure Elixir (Axon) | None; author warns no gain is guaranteed — [post](https://dockyard.com/blog/2023/12/12/code-models-in-elixir-how-to-create-a-code-copilot) |
| ceperaltab/elixir-model-qwen | Dec 2025 | Qwen2.5-Coder-7B | Not identified on the card; a 2,052-row LiveBeats/Phoenix 1.7 chat set by the same user exists | LoRA, 1 epoch, LR 2e-4 | None — [model](https://huggingface.co/ceperaltab/elixir-model-qwen), [data](https://huggingface.co/datasets/ceperaltab/elixir-golden-dataset) |
| nmaroulis/elixir-qwen-9b-gguf | Apr 2026 | Qwen3.5-9B (from file names) | Not stated; same user's 44,791-row undocumented ShareGPT set and 1,518-row chain-of-thought set generated with DeepSeek V4 Pro | Unsloth | None — [model](https://huggingface.co/nmaroulis/elixir-qwen-9b-gguf), [data 1](https://huggingface.co/datasets/nmaroulis/elixir-trainning-sharegpt), [data 2](https://huggingface.co/datasets/nmaroulis/elixir-thinking-v3) |
| jmarceno Qwen3.5-9B and MiniCPM5-1B runs | 2026 | As named | elixir-sft | SFT, CPT | Qwen3.5-9B stage scored 46/128; no public weights in the listing — [preference card](https://huggingface.co/datasets/jmarceno/elixir-preference), [author listing](https://huggingface.co/api/models?author=jmarceno&limit=50) |

**Corpora with no attached model**: `beyond369/curated-elixir-the-stack-v3` (about 543K to 564K files, Stack v3 subset, 1.5 to 25 KB, tree-sitter validated, tagged by pattern such as genserver, ecto, phoenix; 2026-09-05) — [card](https://huggingface.co/datasets/beyond369/curated-elixir-the-stack-v3); `mvkvc/stack_elixir` and `mvkvc/hex_elixir` (Nov 2023), `verify-ppt/marin-starcoderdata_elixir` (Apr 2026) and `joelkoch/elixir_generated` (Feb 2025) — [HF listing](https://huggingface.co/api/datasets?search=elixir&limit=100&sort=lastModified). Search results flag the last as generic template text — [viewer](https://huggingface.co/datasets/joelkoch/elixir_generated).

**BEAM siblings**

- **Gleam, academic, June 2026** (Giagnorio, Martin-Lopez, Bavota; a BEAM language treated as "no-resource"). Zero-shot mostly under 20%, near 0 on McEval-Hard. Qwen 3 8B Base: HumanEval 1.62 zero-shot, 18.57 after LoRA further pre-training on 18,767 files (28.3M tokens), 51.88 after adding instruction transfer. Qwen 2.5 Coder 32B Base: 1.95, 32.99, 56.23. Fine-tuning Qwen 2.5 Coder 32B Instruct on 13,534 functions (3.6M tokens): 6.49 to 24.74. GPT-4o zero-shot 7.60, 5-shot 15.45. The 8B model with instruction transfer beat the 32B Instruct model in every tested setting. — [arXiv 2606.16827](https://arxiv.org/html/2606.16827v1)
- **Gleam, community**: `kasuboski/gemma-4-e4b-gleam-sft`, LoRA on Gemma 4 E4B, 13,538 pairs (9,355 Gleam plus anti-forgetting mixes). No evaluation. The card admits Haskell syntax leakage from 156 Haskell anti-forgetting rows. — [model](https://huggingface.co/kasuboski/gemma-4-e4b-gleam-sft). Its instruction data is 14,053 pairs generated by gpt-oss-120b with no syntax validation — [gleam-instruct](https://huggingface.co/datasets/kasuboski/gleam-instruct); the corpus is 22,581 files from 1,528 repos, snapshot 2026-05-28 — [gleam-code-corpus](https://huggingface.co/datasets/kasuboski/gleam-code-corpus).
- **Erlang**: `szalontaib/erlang-refactoring`, training data (about 1.79 GB) for deep-learning refactoring of non-idiomatic Erlang using formally verified data (Szalontai, Bereczky, Horpácsi, 2023). The card reports no results. — [dataset](https://huggingface.co/datasets/szalontaib/erlang-refactoring). No fine-tuned Erlang coding LLM turned up: the model search for "erlang" returns only the unrelated Chinese Erlangshen family. — [HF listing](https://huggingface.co/api/models?search=erlang&limit=50)
- **Phoenix, LiveView, Ash, BEAM, OTP name searches**: nothing relevant on Hugging Face. Reflection's Beam-1.0-501B-A23B family matches on name and carries a code tag, but nothing in its listing ties it to BEAM languages. — [models "phoenix"](https://huggingface.co/api/models?search=phoenix&limit=100&sort=lastModified), [models "beam"](https://huggingface.co/api/models?search=beam&limit=100&sort=lastModified), [datasets "otp"](https://huggingface.co/api/datasets?search=otp&limit=100&sort=lastModified)

**Community discussion**

- Elixir Forum: jurraca asked on 2026-02-26 whether anyone had tuned a model on Elixir/OTP knowledge and proposed a local quantized model under 500 MB, saying large models write Elixir reasonably but struggle with OTP patterns. No attempt is described. — [thread](https://elixirforum.com/t/fine-tuning-a-model-on-elixir-otp-knowledge/74432)
- Elixir Forum 2024: proposals to tune on top Hex packages and to build a canonical Hexdocs embeddings store, with concerns about licensing and stale forum posts. No attempt. — [thread](https://elixirforum.com/t/llm-supremacy-for-elixir/67104)
- ElixirConf 2025 and 2026: searches found agent and LLM-evaluation talks (Leopardi's "Agentic Elixir", Guimarães's Tribunal) but no fine-tuning talk. — [Agentic Elixir](https://www.elixirconf.eu/talks/agentic-elixir/), [forum listing of EU 2026 talks](https://elixirforum.com/t/elixirconf-eu-2026-malaga-slides-and-links/75144)
- Elixir-native training exists as tutorials only: LoRA with Axon (October 2024) and an Nx port of an LLM book (2026, GPT-2 spam classification). — [awesome-ml-gen-ai-elixir](https://github.com/georgeguimaraes/awesome-ml-gen-ai-elixir)

### Inferences
- The honest statement is "tried, measured twice, modest." The one Elixir-specific measurement leaves about 64% of tasks failing after tuning, which reads as open territory, not a solved problem.
- jmarceno's gain is probably optimistic. The preference rows were mined from failures in its own evaluations, with 40/128 and 46/128 quoted from them, so weaknesses seen on an eval pack may have steered training even with zero prompt collisions. The cards do not say which pack those were, so this is a risk, not a finding.
- 31 to 46 of 128 is a small sample: an unpaired two-proportion test gives z of about 2.1 (hand calculation), and one task is 0.78 pp. A paired test needs per-task results that are not public.
- Gemma 12B and Qwen 3B tied at 31/128 at base despite a fourfold size gap. That suggests the harness measures Elixir knowledge both lack rather than general capacity.
- Comparing `gemma12b-elixir-cpt-q4` (40) with the base (31) and the release (46) hints that continued pretraining gave most of the gain and later stages the rest. The checkpoint's exact recipe is unstated, so treat this as a lead to verify.
- The Racket-to-Elixir transfer in the ACL paper suggests a functional-language corpus may be useful extra training data for Elixir. It is a single result on a weak base model.

### Gaps
- jmarceno's training recipe, CPT corpus size and location, per-stage gains, harness contents and any frontier score on the same harness are not public. No independent reproduction found, and no forum or blog post by the author surfaced.
- Reddit is not reachable by the search tool, and GitHub search returned only generic Qwen fine-tune repos. Private or unpublished attempts, and any Hugging Face repo without "elixir" in its name, would be missed.
- Replies in the 2026 forum thread could not be retrieved: the tag page implies three, a later fetch showed none.
- Whether `ceperaltab/elixir-model-qwen` really used the golden dataset is not stated. Neither its card nor the dataset card says so.
- The Erlang refactoring paper's scores were not retrieved.

## Elixir tooling for LLMs that competes with fine-tuning

### Takeaway
The Elixir ecosystem has put its effort into feeding frontier models better context at runtime (Tidewave, usage rules, Hexdocs search, ElixirLS MCP), not into training. Almost none of it has a controlled measurement; the only numbers are Ash's small flagship eval, where usage rules added 15 to 23 pp. Nothing here replaces a local model's Elixir knowledge, and all of it can stack with one if the model can call tools.

### Cited Findings
- **Tidewave**: a development toolkit (IDE, toolbar, desktop app, CLI) for Phoenix and Rails plus several JS stacks that connects an agent to the running app. Supported agents named are Claude Code, Codex, OpenCode and Copilot. The site shows no measured evidence. — [tidewave.ai](https://tidewave.ai/). The Phoenix package runs as a dev-only MCP server on the app's own port, with documentation pinned to the exact Hex versions in the project. — [Hex readme](https://readme.hex.pm/tidewave/0.8.0), [listing](https://mcpservers.org/servers/tidewave-ai/tidewave_phoenix)
- **usage_rules** (Ash): gathers `usage-rules.md` files from dependencies into AGENTS.md or CLAUDE.md, generates skills, ships Elixir and OTP rules, and offers `mix usage_rules.search_docs`. The README concedes nobody yet knows what makes a great rules file, and gives no data. — [repo](https://github.com/ash-project/usage_rules)
- **ash-project/evals**: YAML evals of type write-code-and-assert, with and without usage rules. The README says only a few evals exist, they are not in CI, and agentic benchmarks are planned. — [repo](https://github.com/ash-project/evals). The flagship report, 5 iterations, undated, total eval count not shown: Claude Sonnet 4 100.0% with rules against 77.8% without, GPT-4.1 95.0 against 80.0, Gemini 2.5 Pro 90.0 against 66.7. — [flagship report](https://raw.githubusercontent.com/ash-project/evals/main/reports/flagship.md)
- **Ash AI**: Ash integration with tool calling, plus a dev MCP server plug. — [docs](https://ash-ai.hexdocs.pm/readme.md), [awesome list](https://github.com/georgeguimaraes/awesome-ml-gen-ai-elixir)
- **hexdocs-mcp**: semantic search over Hex docs (SQLite vectors, Ollama embeddings), about 70 stars, no retrieval-quality data. — [repo](https://github.com/bradleygolden/hexdocs-mcp)
- **ElixirLS MCP**: the community language server has an opt-in MCP server with model-oriented text tools, enabled by `elixirLS.mcpEnabled`. — [forum post](https://elixirforum.com/t/elixirls-mcp-server/71992), [docs](https://docsearch.algolia.com/mcp/docs/repo/elixir-lsp/elixir-ls)
- **Expert**: Next LS was archived on 2025-10-08 with focus moved to Expert, the official language server. One editor extension added experimental Expert support in May 2026 and still defaults to ElixirLS. I found no Expert MCP server. — [next-ls repo](https://github.com/elixir-tools/next-ls), [Nova extension](https://extensions.panic.com/extensions/raulchedrese/raulchedrese.elixir-ls/)
- **Bumblebee and Nx**: Bumblebee v0.7.0 offers pre-trained Axon models for inference and training; a tracker showed a last push on 2026-04-02. It is an in-app inference path, not a coding-assistant competitor. — [docs](https://bumblebee.hexdocs.pm/Bumblebee.html), [tracker](https://gittrend.io/repo/elixir-nx/bumblebee). DockYard's 2024 roadmap said quantization was inference-only. — [DockYard](https://dockyard.com/blog/2024/08/20/where-are-nx-axon-bumblebee-headed)
- **Dashbit / José Valim** (2026-02-05): argues immutability, verified doctests, ecosystem stability, warnings as non-blocking feedback and runtime introspection make Elixir suit LLMs. He admits the Tencent study measured single-pass generation and that for agents, "we don't have the receipts" (Valim). — [Dashbit](https://dashbit.co/blog/why-elixir-best-language-for-ai)
- **Community layer**: Claude Code plugins and skills ([claude-code-elixir](https://github.com/georgeguimaraes/claude-code-elixir), [claude-elixir-phoenix](https://github.com/oliver-kriska/claude-elixir-phoenix)), ExSlop Credo checks that flag AI-style code, and Elixir LLM eval frameworks Tribunal, Aludel and Hallmark. — [awesome list](https://github.com/georgeguimaraes/awesome-ml-gen-ai-elixir)
- One author's two-build plugin test gave 0 against 46 tests and a better Credo result, but it was a single run with many changed variables, and both builds needed manual functional testing. — [forum](https://elixirforum.com/t/sharing-my-claude-code-plugin-for-elixir-development/74119)

### Inferences
- For a frontier model on a real project, these tools are the fine-tune's real competitor and they are nearly free. A local fine-tune competes on cost, latency and privacy (the motive in the 2026 forum post), not on beating Opus-class models with context.
- The Ash report suggests context on a framework's API can be worth 15 to 23 pp. That is about twice the gain of the best Elixir fine-tune, though on a different, smaller, framework-specific task set by frontier models. Library knowledge belongs in context; language idiom and syntax belong in weights.

### Gaps
- No controlled study of Tidewave, Hexdocs MCP or ElixirLS MCP on task success. The Ash report has no date or eval count.
- Expert's current MCP status could not be confirmed, nor Bumblebee's 2026 LLM architecture coverage.

## How models do at Elixir today, and where they fail

### Takeaway
Elixir looks excellent on AutoCodeBench but that result is fragile: the problems were translated from Python, not manually verified, and the paper's own filter failed to remove easy ones in low-resource languages. A 2026 LeetCode test shows Elixir well behind Python, and the only OTP/BEAM-targeted harness shows small open models at 24%. Measured failures are binaries, BEAM primitives, OTP, abstractions and compile warnings; failures in Ecto, LiveView, process-based tests, macros and hallucinated Hex APIs are anecdote or simply unmeasured.

### Cited Findings

**AutoCodeBench (Tencent, 2025-08), 198 Elixir problems, 3,920 total across 20 languages**

- Elixir has the highest union upper bound, 97.5% against a 74.8 average. — [paper](https://arxiv.org/html/2508.09101v1)
- Elixir pass@1 (paper tables), full set: Claude Opus 4 82.3 non-reasoning and 80.3 reasoning; o4-mini 82.3; Kimi-K2 80.3; Qwen3-235B-Thinking 79.8; DeepSeek-Coder-33B-Instruct 67.7; Qwen3-32B 65.2 reasoning and 52.0 non-reasoning; Qwen3-14B 62.1 and 42.4; Qwen2.5-Coder-32B 59.6; Seed-Coder-8B-Instruct 57.1; DeepSeek-Coder-6.7B-Instruct 47.5; Qwen2.5-Coder-7B 47.0; Qwen3-8B 43.9 and 41.4; Qwen2.5-Coder-1.5B 35.4; Qwen3-4B 33.3; Qwen3-1.7B 20.7 and 17.2. — [paper](https://arxiv.org/html/2508.09101v1)
- Base models with 3-shot prompts, 50 Elixir problems (AutoCodeBench-Complete): DeepSeek-Coder-V2-Base 52.0 (average 39.0), Seed-Coder-8B-Base 48.0, Qwen2.5-Coder-7B 46.0 (average 24.6), DeepSeek-Coder-6.7B-Base 44.0, Qwen3-8B-Base 34.0. — [paper](https://arxiv.org/html/2508.09101v1)
- Caveats from the paper itself: Elixir is one of 14 languages built by approximate translation from unused problems, with Python as Elixir's source; manual verification covered only six other languages; and the filtering model is weak in low-resource languages and may leave simple problems in. The paper does not itself attribute Elixir's score to this. — [paper](https://arxiv.org/html/2508.09101v1)
- AutoCodeBench-V2 (December 2025, updated 2026-02-17) publishes its leaderboard only as an image, so no 2026-model Elixir figure was extractable. — [V2 README](https://github.com/Tencent-Hunyuan/AutoCodeBenchmark/blob/main/AutoCodeBench-V2/README.md), [project page](https://autocodebench.github.io/)
- Tasks are described as self-contained function-writing problems graded by sandboxed tests — [CodeMySpec explainer](https://codemyspec.com/blog/autocodebench-explained) (a vendor selling Elixir tooling, per [its other post](https://codemyspec.com/blog/why-elixir-is-the-best-language-for-llms)). The paper says its seed code spans function, class and file level, and does not describe the Elixir tasks separately. — [paper](https://arxiv.org/html/2508.09101v1)

**Other benchmarks**

- **McEval** (June 2024, about 50 tasks per language), code generation pass@1, Elixir with Erlang and all-language average: GPT-4o 66 / 44 / 65.2; GPT-4 Turbo 56 / 38 / 63.4; DeepSeekCoder-33B 50 / 40 / 54.3; mCoder 7B 44 / 52 / 46.7; DeepSeekCoder-1.5-7B 40 / 40 / 46.0; CodeQwen-1.5-7B 38 / 38 / 45.5; Codestral 22B 34 / 24 / 50.5; Qwen1.5-72B 18 / 24 / 35.8; Codegemma 7B 4 / 4 / 30.7. Most models here sit near or below their own average on Elixir, the opposite of AutoCodeBench. — [McEval HTML](https://ar5iv.labs.arxiv.org/html/2406.07436)
- **LeetCode test** (2026-03-08, 100 algorithmic problems, judge acceptance): Python / Java / Elixir: claude-sonnet-4-5 50 / 52 / 35; gemini-2.5-flash 82 / 82 / 39; gemini-3-flash-preview 84 / 93 / 83; gpt-5-mini 93 / 94 / 63; grok-code-fast-1 73 / 65 / 30. The Python-Elixir gap is significant for all but gemini-3-flash-preview. — [Hackernoon](https://hackernoon.com/comparing-llms-coding-abilities-across-programming-languages)
- **MultiPL-E** includes Elixir (the repo lists an Elixir support pull request, and search results place it in the v0.5.0 additions) — [repo](https://github.com/nuprl/MultiPL-E). I found no frontier or current mid-size scores for it. McEval's list of 11 languages taken from the BigCode leaderboard does not name Elixir — [McEval PDF](https://arxiv.org/pdf/2406.07436). The only published Elixir figures found: StarCoder2-3B 9.28 and DeepSeek-Coder-1.3B 15.01 on HumanEval; 6.87 and 4.11 on MBPP. — [ACL paper PDF](https://aclanthology.org/2025.acl-srw.57.pdf)
- **jmarceno 128-task harness**: 24.2% for both Gemma 4 12B QAT and Qwen2.5-Coder-3B. — [card 1](https://huggingface.co/jmarceno/Elixir-Gemma-4-12B), [card 2](https://huggingface.co/jmarceno/Elixir-Qwen2.5-Coder-3B)
- **Not covering Elixir**: SWE-bench Multilingual (C, C++, Go, Java, JS, TS, PHP, Ruby, Rust — [site](https://www.swebench.com/multilingual.html)), Multi-LCB (12 languages — [listing](https://benchmarklist.com/benchmarks/multi_lcb_extending_livecodebench_to_multiple_programming_languages/)).
- No dedicated Elixir LLM leaderboard turned up. The closest are ash-project/evals and a tool list. — [repo](https://github.com/ash-project/evals), [awesome list](https://github.com/georgeguimaraes/awesome-ml-gen-ai-elixir)

**Failure modes by area, with strength of evidence**

| Area | Evidence | Strength |
|---|---|---|
| OTP / GenServer | Gemma 12B 2/16 to 4/16 on OTP tasks — [card](https://huggingface.co/jmarceno/Elixir-Gemma-4-12B); forum poster's claim on design patterns — [thread](https://elixirforum.com/t/fine-tuning-a-model-on-elixir-otp-knowledge/74432); wrong callback arities — [guide](https://claudify.tech/blog/claude-code-elixir) | Measured for small open models; anecdote for frontier |
| BEAM primitives | 1/16 to 3/16 — [card](https://huggingface.co/jmarceno/Elixir-Gemma-4-12B) | Measured, small models |
| Binaries, bit syntax | Qwen 3B 0/16 to 5/16 — [card](https://huggingface.co/jmarceno/Elixir-Qwen2.5-Coder-3B); weakness tags bin-endian, bin-size-guard, bin-signed — [preference data](https://huggingface.co/datasets/jmarceno/elixir-preference) | Measured, small models |
| Abstractions | Gemma 1/16 base, Qwen 3B 5/16 base — cards above | Measured; the card does not define the category |
| Error handling | err-swallow is a top bucket (42 rows) — [preference card](https://huggingface.co/datasets/jmarceno/elixir-preference); Gemma base 8/16 — [card](https://huggingface.co/jmarceno/Elixir-Gemma-4-12B) | Measured, small models |
| Compile warnings | 40 to 53% of base completions carry warnings (computed from warning-free 60.2% and 46.9%) — cards above | Measured, the only numbers found |
| Imperative habits | `if` chains, reduce-for-everything, `Enum.at` indexing, unmatched `Repo` results — [Vaughan](https://codex.danielvaughan.com/2026/04/26/codex-cli-elixir-phoenix-teams-tidewave-mcp-functional-agent-workflows/) | Unmeasured |
| Ecto | Forgotten preloads leading to NotLoaded errors at runtime; unmatched `Repo.insert` — [Vaughan](https://codex.danielvaughan.com/2026/04/26/codex-cli-elixir-phoenix-teams-tidewave-mcp-functional-agent-workflows/) | Unmeasured |
| LiveView | Confused callback return shapes — [Vaughan](https://codex.danielvaughan.com/2026/04/26/codex-cli-elixir-phoenix-teams-tidewave-mcp-functional-agent-workflows/); logic in templates, missed `handle_info` — [CodeMySpec](https://codemyspec.com/blog/spec-driven-development-elixir) | Unmeasured, vendor source |
| Process-based tests | Tests that skip Phoenix.LiveViewTest or Ecto sandbox helpers — [CodeMySpec](https://codemyspec.com/blog/spec-driven-development-elixir); test-suite startup cost in agent loops — [Leopardi](https://www.elixirconf.eu/talks/agentic-elixir/) | Unmeasured |
| Typespecs | GPT-5.5 weak on complex typespecs; the author states no benchmark exists — [Vaughan](https://codex.danielvaughan.com/2026/04/26/codex-cli-elixir-phoenix-teams-tidewave-mcp-functional-agent-workflows/) | Unmeasured |
| Hallucinated Hex APIs | No Elixir study found. General figure: about 19.7% of LLM-recommended packages did not exist in a 2025 study — [Wikipedia summary](https://en.wikipedia.org/wiki/Slopsquatting); Gemini stuck on a JWT library — [HN](https://news.ycombinator.com/item?id=44186496) | Anecdote plus general figure |
| Stale Phoenix versions | LiveView 1.1 changed behaviour that broke templates — [forum](https://forum.elixirforum.com/t/question-with-heex-code-when-updating-the-version-of-liveview/72004); Valim argues stability limits staleness — [Dashbit](https://dashbit.co/blog/why-elixir-best-language-for-ai) | No LLM measurement |
| Macros | Nothing found | Gap |

- Model reputation is anecdotal: 2025 HN commenters ranked Claude ahead for Elixir and criticised Gemini — [HN](https://news.ycombinator.com/item?id=44186496); a 2026 forum user preferred GPT-5.3 Codex for idiomatic Elixir — [forum](https://elixirforum.com/t/sharing-my-claude-code-plugin-for-elixir-development/74119).

### Inferences
- Headroom by tier, reading all of the above together: frontier models pass about 80% of AutoCodeBench's Elixir tasks and 30 to 83% of LeetCode tasks, so function-level headroom is modest and benchmark-dependent. Mid-size open models (7B to 32B) sit at 40 to 65%. On tasks that actually target OTP, BEAM and binaries, small open models start at 24% and reach 36% after tuning.
- The contrast between Qwen2.5-Coder-7B at 47% on AutoCodeBench and Qwen2.5-Coder-3B at 24% on the Elixir harness (different models and tasks, so indicative only) suggests general algorithmic Elixir is learned while OTP and BEAM specifics are not. Python-translated tasks cannot show OTP competence at all.
- McEval and LeetCode undercut the "Elixir is the easiest language" reading. The likelier story is that Elixir syntax is learnable and that benchmark construction drives the headline.
- Nobody has published a frontier score on an OTP-focused harness, so whether frontier models share the OTP weakness is unknown. The owner could fill this gap with a held-out, Elixir-specific evaluation.

### Gaps
- McEval figures come from an automated read of the HTML table; the PDF was too small to confirm by eye, so check them before quoting. They are also from 2024.
- No Elixir numbers for 2026 mid-size open models (Qwen3.6, Qwen3.8, Gemma 4 base beyond the harness) except jmarceno's two baselines.
- No measurement of LiveView, Ecto, macro, supervision-tree or test-writing correctness anywhere. No study of hallucinated Hex packages or functions.
- Many failure lists come from vendors or skill authors with an interest in the fix.

## Other languages, with numbers

### Takeaway
Language-specific tuning repeatedly works when the base model is weak at the language: gains of 10 to 16 pp for Kotlin, 7 to 14 pp for Rust and for OCaml/Racket, 44 to 47 pp for COBOL, and small models beating far larger ones on Pharo, Verilog, Chisel, COBOL, Rust and Gleam on at least some benchmarks. Most community fine-tunes (Go, Zig, Luau) publish no baseline comparison. I found no Swift fine-tune and no Isabelle fine-tune.

### Cited Findings

| Language | Attempt, date | Base, size | Data | Method | Gain vs base | Vs bigger model | Source |
|---|---|---|---|---|---|---|---|
| Kotlin | JetBrains Kotlin ML Pack, 2024-05 | CodeLlama 7B, DeepSeek 6.7B, 1.3B | KStack 4M files; KStack-clean 25K; KExercises 15K tasks (3.5M tokens) | Fine-tune | HumanEval-Kotlin: CodeLlama 26.09 to 29.19 KStack, 37.89 clean, 42.24 KExercises; DeepSeek 7B 40.99 to 55.28; 1.3B 26.71 to 36.65. Completion flat | Not tested | [arXiv](https://arxiv.org/html/2405.19250v1) |
| Rust | Strand-Rust-Coder, 2025-10 | Qwen2.5-Coder 14B | 191,008 peer-ranked synthetic from 2,383 crates | LoRA r64, 3 epochs | Hold-out 0.29 to 0.43; RustEvo2 0.30 to 0.43; HumanEval-Rust 0.78 to 0.76 | Beat GPT-5-Codex 0.28 and Sonnet 4.5 0.21 on RustEvo2; lost on hold-out 0.47, 0.46 | [report](https://huggingface.co/blog/Fortytwo-Network/strand-rust-coder-tech-report) |
| Swift | None found. SwiftEval (2025): 28 tasks, 44 models; open leaders DeepSeek Coder V2 236B 0.82, Codestral 0.73, StarCoder2 3B 0.22 | n/a | n/a | Benchmark only | n/a | n/a | [SwiftEval](https://arxiv.org/pdf/2505.24324), [leaderboard](https://swifteval.macpaw.com/) |
| Haskell | van Dam et al., 2024-03 | CodeGPT, UniXcoder (small) | 201,921 train samples | Fine-tune, line completion | HumanEval-Haskell EM 5.80 to 15.42, 5.31 to 13.10 | Not tested; still below Python and Java tuned scores | [arXiv](https://arxiv.org/html/2403.15185v1) |
| OCaml, Racket, R, Julia, Lua | MultiPL-T, OOPSLA 2024 | StarCoderBase 1B, 15B; CodeLlama 34B, 70B | 37,592 to 48,194 compiler- and test-validated translations of Python | Fine-tune 7 to 10 epochs | 15B: OCaml 6.9 to 19.9; Racket 11.8 to 21.0; R 10.2 to 17.3; Julia 21.1 to 35.2; Lua 26.6 to 31.0. CodeLlama-70B: 23.2 to 29.3; 21.9 to 33.1; 23.0 to 28.5; 41.9 to 44.5; 41.7 to 44.9. DeepSeek-33B Base Racket 23.3 to 36.6 | Reached state of the art for Racket, OCaml, Lua per authors | [arXiv](https://arxiv.org/html/2308.09895v6) |
| OCaml | Jane Street, 2025 talk | Custom, size undisclosed | Workstation snapshots about every 20 s, green-red-green build transitions, LLM-written prompts to diffs | SFT then RL against parse, type-check, compile, test | No numbers. Raw-code training failed to teach editing | Not stated | [talk](https://ai.engineer/talks/building-ai-powered-developer-tools-at-jane-street) |
| R, Racket | Giagnorio et al., 2025-01 | DeepSeek Coder 1B, 7B, 33B; Code Llama 7B, 13B | 37,592 R, 40,489 Racket | FT vs in-context | 1B: R 13.9 to 16.7, Racket 7.0 to 18.4. 33B: R 30.2 to 25.3, Racket 32.5 to 28.0 (worse) | Few-shot lifts 33B to 38.3 on R; Copilot 41.1 | [arXiv PDF](https://arxiv.org/pdf/2501.19085) |
| Solidity | Chain-GPT Solidity-LLM, date not on card | CodeGen 2B | 1B tokens pretrain, 650K instructions | Pretrain then FT | About 83% compile, 72% gas; no base number in text | Card calls it top on compile and gas, weaker than GPT-4.5 on security | [card](https://huggingface.co/Chain-GPT/Solidity-LLM) |
| Verilog | CodeV, 2024-07 | CodeLlama 7B, DeepSeek 6.7B, CodeQwen 7B | About 165K pairs from 1.5M+ files, GPT-3.5 summaries | Fine-tune | Not reported in what I read | VerilogEval 77.6 / 53.2 vs GPT-4 60.0 / 43.5 | [arXiv](https://arxiv.org/html/2407.10424v3) |
| Verilog | RTLCoder, 2023-12 | 7B | Size not stated in abstract | Fine-tune | n/a | Beat GPT-3.5 on main benchmarks and GPT-4 on VerilogEval Machine | [arXiv](https://arxiv.org/abs/2312.08617) |
| Chisel | ChiseLLM, 2025-04 | Qwen2.5 7B, 32B | About 8.3K Chisel files as seed; reasoning traces distilled from DeepSeek-R1 | Full-parameter FT | 7B syntax +18.85%; 32B Pass@5 +26.32% (abstract and intro differ on the metric) | 32B near DeepSeek-R1 671B: RTLLM decompile 54.32 vs 55.25, GPT-4o 44.50 | [arXiv](https://arxiv.org/html/2504.19144v1) |
| Lean 4 | Goedel-Prover-V2, 2025-08 | 8B | Size not retrieved | Scaffolded data synthesis, self-correction | miniF2F 84.6 at 32 samples, 90.2 at 8192 | Beats DeepSeek-Prover-V2 671B at 82.4 / 88.9 on miniF2F | [paper](https://arxiv.org/pdf/2508.03613), [DeepSeek](https://arxiv.org/pdf/2504.21801) |
| Coq / Rocq | Rango, 2024-12 | Fine-tuned LLM, base not retrieved | CoqStoq | FT plus retrieval | 32.0% of theorems, 29% more than Tactician; retrieval of proofs added 47% | Not tested | [arXiv](https://arxiv.org/pdf/2412.14063) |
| Isabelle | None found | | | | | | |
| COBOL | COBOL-Coder, 2026-04 | Qwen2.5-Coder 7B, 14B | About 703,750 instances (31,492 compiled GitHub programs, 173K synthetic pairs, 153K Q&A) | Compiler-gated curation, FT | COBOLEval Pass@1 0.68 to 44.70, 2.74 to 49.33; compile 10.27 to 73.80 | GPT-4o 16.40, GPT-4 15.75, Mainframer 13B 11.64 | [arXiv](https://arxiv.org/html/2604.03986v1) |
| COBOL | XMainframe, 2024-08 | DeepSeek-Coder | Not retrieved | FT | About 30% better MCQ than base | Summarisation about six times GPT-3.5 (authors' metric) | [HF paper](https://huggingface.co/papers/2408.04660) |
| Ansible | Wisdom (IBM), 2023-05 | CodeGen | About 1.1M Ansible plus 2.2M YAML (secondary summary) | YAML pretrain then FT | About 1% over tuned CodeGen on schema and EM | BLEU 66.67 vs Codex-Davinci-002 50.4 | [arXiv](https://arxiv.org/abs/2305.02783v4), [summary](https://liner.com/ko/review/automated-code-generation-for-information-technology-tasks-in-yaml-through) |
| Pharo | Kier et al., 2026-07 | Qwen2.5 Coder 0.5B to 7B, Mellum 4B | 387,159 methods, 324,725 FT instances | LoRA CPT then FT | HumanEval+ r-AST 7B 45.24, CPT alone 27.65, SFT 52.76 | SFT 7B beat Qwen3 Coder 480B 45.13 and Claude 4.5 Sonnet 51.53 on r-AST | [arXiv PDF](https://arxiv.org/pdf/2607.04939) |
| Gleam, MoonBit | Giagnorio et al., 2026-06 | Qwen 2.5 Coder 32B, Qwen 3 8B, 32B | 18,767 and 3,609 files; 13,534 and 2,444 functions | LoRA PT, FT, instruction transfer | See the Elixir section | 8B with transfer beat 32B Instruct | [arXiv](https://arxiv.org/html/2606.16827v1) |
| Luau | Luau-Devstral-24B, 2025 | Devstral Small 24B | 25.9M lines, 0.45B tokens, 19.6K doc pages | LoRA r64, 2 epochs | None published | None | [card](https://huggingface.co/TorpedoSoftware/Luau-Devstral-24B-Instruct-v0.1) |
| Luau | qode1; DeepSeek and Code Llama LoRAs | Qwen2.5-Coder 7B and others | Various | LoRA | qode-luau-95 scores not retrieved; others loss only | None | [listing](https://app.alphaneural.io/models/qodelabs/qode1), [LoRA](https://huggingface.co/darwinkernelpanic/deepseek-coder-6.7b-instruct-luau/blob/main/README.md) |
| Zig | ZigNet, 2025-10 | Qwen2.5-Coder 7B | 13,756 examples from Zig 0.13 to 0.15 docs | QLoRA, 3 epochs | Claims 100% on own tests, no baseline | None | [card](https://huggingface.co/fulgidus/zignet-qwen2.5-coder-7b) |
| Zig | Akita, 2025-05 | Qwen3-8B | About 900 KB of docs and cookbook | LoRA, 5 epochs | Self-described partial: invented `@splat` explanation, code did not compile | None | [post](https://akitaonrails.com/en/2025/05/03/teaching-recent-zig-to-your-llm-training-loras-sort-of/) |
| Go | smcleod Golang Coder v3; MistralXGo; LLM-GO; Gopilot | Llama 3.1 8B; Mistral 7B; custom; 290M | 45,565 items for smcleod | LoRA; custom training | No benchmarks | None | [smcleod](https://huggingface.co/smcleod/llama-3-1-8b-smcleod-golang-coder-v3), [MistralXGo](https://huggingface.co/devadigaprathamesh/MistralXGo-7B), [Gopilot](https://awesome.ecosyste.ms/projects/github.com%2Fdhbrojas%2Fgopilot) |

- **Surveys**: a TOSEM-accepted review of 111 papers (2020 to 2024) on low-resource and domain-specific languages; fine-tuning and prompting are the most common improvement methods. — [arXiv 2410.03981](https://arxiv.org/pdf/2410.03981). The 2026 "no-resource" paper extends this with Gleam and MoonBit. — [arXiv 2606.16827](https://arxiv.org/html/2606.16827v1)
- **Conflicts**: Strand's model card reports 48% hold-out against GPT-4o in one copy and GPT-5-Codex in another, while its report lists 0.43 (0.50 at ckpt3200) — [card copy](https://huggingface.co/Mungert/Strand-Rust-Coder-14B-v1-GGUF/blob/main/README.md), [report](https://huggingface.co/blog/Fortytwo-Network/strand-rust-coder-tech-report). The COBOL-Coder paper's RQ1 text and its table differ by 1 pp on compile rate — [arXiv](https://arxiv.org/html/2604.03986v1).
- **Pharo context**: at repo level with recently edited methods as context, 7B SFT reached ChrF 75.96 and CrystalBLEU 58.99 against Qwen3 Coder 69.36 and 51.59; Claude 4.5 Sonnet stayed ahead at 83.02 and 70.52, with possible data contamination noted. A 4-bit 7B lost only 0.61% pass@1. — [arXiv PDF](https://arxiv.org/pdf/2607.04939)

### Inferences
- The Strand HumanEval-Rust result (no gain) and the Kotlin completion result (flat) suggest tuning helps on tasks the data resembles, and does not raise all boats.
- The "small tuned beats big general" claims are real but benchmark-selective: Strand beats frontier models on RustEvo2 and loses on HumanEval-Rust; ChiseLLM trails R1 on one VerilogEval spec task and leads on another.
- Elixir is a harder case than COBOL or Pharo for a dramatic win, because base models already know its syntax (AutoCodeBench-Complete 34 to 52 for small base models). Expect Kotlin- or Rust-sized gains on general tasks, with more on neglected areas like OTP and binaries.

### Gaps
- Swift: no fine-tune found; absence from one search is not proof. SwiftEval's own fine-tuning status is unknown.
- Solidity baseline numbers are only in a figure. mAInframer's original COBOLEval numbers could not be fetched (bloop.ai refused the connection); COBOL-Coder's table gives them as re-run figures.
- Kimina-Prover and Goedel data sizes, and Rango's base model, were not retrieved. Lean figures date from 2025.
- Racket, Julia, and Haskell gains on a realistic benchmark beyond MultiPL-E style are not covered here.

## What transfers: which recipe gave the largest gain, how much data, is there a threshold?

### Takeaway
The strongest recipe in the literature is a two-stage one: continued pretraining on raw code from the base (not instruct) checkpoint, followed by instruction fine-tuning or instruction transfer, with data gated by a compiler and tests. There is no sharp threshold: 15K to 25K clean examples moved Kotlin by 10 to 16 pp while 4M raw files moved it by 1 to 3 pp, so quality beats volume by a wide margin. Very large instruct models can get worse on tens of thousands of examples, and tuned models lose other languages.

### Cited Findings

**Data volume against gain**

| Examples | Language, model | Gain | Source |
|---|---|---|---|
| About 900 KB docs | Zig, Qwen3-8B | Partial, no numbers | [post](https://akitaonrails.com/en/2025/05/03/teaching-recent-zig-to-your-llm-training-loras-sort-of/) |
| About 1.7K to 4.7K verified, plus CPT of unknown size, plus up to 909 preference rows | Elixir, Gemma 12B and Qwen 3B | +10.9 to +11.7 pp | [SFT card](https://huggingface.co/datasets/jmarceno/elixir-sft), [model card](https://huggingface.co/jmarceno/Elixir-Gemma-4-12B) |
| 8.3K files plus distilled reasoning | Chisel | +18.85% syntax on 7B | [arXiv](https://arxiv.org/html/2504.19144v1) |
| 13.5K functions, 3.6M tokens | Gleam FT, 32B Instruct | About +18 pp HumanEval, +24 pp MBPP | [arXiv](https://arxiv.org/html/2606.16827v1) |
| 15K tasks, 3.5M tokens | Kotlin KExercises | +9.9 to +16.2 pp | [arXiv](https://arxiv.org/html/2405.19250v1) |
| 18.8K files, 28.3M tokens | Gleam PT, 8B and 32B Base | +17 to +44 pp, up to +54 pp with transfer | [arXiv](https://arxiv.org/html/2606.16827v1) |
| 25K files, 22M tokens | Kotlin KStack-clean | +11.8 pp | [arXiv](https://arxiv.org/html/2405.19250v1) |
| 37K to 48K | Five languages, MultiPL-T | +3 to +14 pp | [arXiv](https://arxiv.org/html/2308.09895v6) |
| 191K | Rust | +13 to +14 pp, none on HumanEval-Rust | [report](https://huggingface.co/blog/Fortytwo-Network/strand-rust-coder-tech-report) |
| 202K | Haskell | EM +7.8 to +9.6 | [arXiv](https://arxiv.org/html/2403.15185v1) |
| 224K raw files | Elixir, 1.3B and 3B | +1.7 to +6.8 pp on HumanEval, negative on one McEval | [ACL](https://aclanthology.org/2025.acl-srw.57.pdf) |
| 704K | COBOL | +44 to +47 pp | [arXiv](https://arxiv.org/html/2604.03986v1) |
| 4M raw files | Kotlin KStack | +1.2 to +3.1 pp | [arXiv](https://arxiv.org/html/2405.19250v1) |

**Quality over volume**

- Kotlin's own conclusion is that small high-quality sets outperform the larger raw corpus. — [arXiv](https://arxiv.org/html/2405.19250v1)
- MultiPL-T reports that tuning on The Stack barely helped and could hurt, while validated translations gave large gains. Plain synthetic data was weak because LLMs write poor programs in low-resource languages. — [arXiv](https://arxiv.org/html/2308.09895v6), [abstract page](https://arxiv.org/pdf/2308.09895)
- COBOL-Coder, curated with compiler validation and back-translation filtering, compares with the earlier Mainframer fine-tune at similar compile rates (73.80 against 69.17) but Pass@1 of 44.70 against 6.16 at 7B. — [arXiv](https://arxiv.org/html/2604.03986v1)

**Two-stage training**

- Pharo: continued pre-training alone improved AST-aware completion and hurt realistic random-span completion, while the supervised stage closed that gap. — [arXiv PDF](https://arxiv.org/pdf/2607.04939)
- Gleam: pretraining was the strongest single technique but yields base models that cannot follow instructions. Instruction transfer, which adds the weight difference between an instruct model and its base to the pretrained base, gained about 12 pp on average and up to 33 pp. — [arXiv](https://arxiv.org/html/2606.16827v1)
- Solidity and Ansible follow the same pretrain then fine-tune pattern. — [Solidity card](https://huggingface.co/Chain-GPT/Solidity-LLM), [Ansible](https://arxiv.org/abs/2305.02783v4)

**Model size**

- Fine-tuning suits smaller LLMs; in-context learning is a cheap safe bet as models grow; 33B regressed after tuning, attributed to too little data. — [No Silver Bullet](https://arxiv.org/pdf/2501.19085)
- Contradicted in part by MultiPL-T, where CodeLlama 34B and 70B and DeepSeek-Coder-Base-33B all gained. — [arXiv](https://arxiv.org/html/2308.09895v6)
- COBOL-Coder's 14B beat its 7B only slightly. — [arXiv](https://arxiv.org/html/2604.03986v1)

**Other levers**

- Instruction-following transfers across languages: CodeQwen fine-tuned on Python-only instructions improved in most other languages. — [McEval PDF](https://arxiv.org/pdf/2406.07436)
- Reasoning traces distilled from a strong model (ChiseLLM) and RL against a checker (DeepSeek-Prover-V2, Jane Street) are the other strong patterns. — [ChiseLLM](https://arxiv.org/html/2504.19144v1), [DeepSeek-Prover-V2](https://arxiv.org/pdf/2504.21801), [Jane Street](https://ai.engineer/talks/building-ai-powered-developer-tools-at-jane-street)
- ZeTT tokenizer adaptation helped Elixir MBPP but is complex and lowered Python. — [ACL](https://aclanthology.org/2025.acl-srw.57.pdf)
- Quantization costs little after tuning: Q4_K_M lost 0.61% pass@1 on the 7B Pharo model. — [arXiv PDF](https://arxiv.org/pdf/2607.04939)
- Forgetting: Elixir-tuned StarCoder2 dropped Python to near zero; Gleam anti-forgetting data introduced Haskell leakage. — [ACL](https://aclanthology.org/2025.acl-srw.57.pdf), [Gleam card](https://huggingface.co/kasuboski/gemma-4-e4b-gleam-sft)

### Inferences
- The size conflict dissolves in part if the base-versus-instruct distinction matters: No Silver Bullet tuned 33B **Instruct** (Racket 32.5 down to 28.0), while MultiPL-T tuned 33B **Base** (23.3 up to 36.6) on the same dataset family and benchmark. Gleam shows the same order: base with pretraining beat instruct with fine-tuning. A plausible rule is to train from the base checkpoint and restore instructions afterwards. This is my cross-paper reading (settings differ), not a tested claim, and it is worth testing directly.
- Practical bracket: for models up to about 8B, gains appear from 10K to 25K clean, verified examples; a few thousand can move an executable harness when targeted at weaknesses (jmarceno). Millions of raw files only earn their cost as a pretraining stage.
- The base-rate effect dominates: tuning gains are largest where the base is near zero (COBOL, Gleam) and smallest where it already knows the language. Elixir sits in the middle.
- Elixir has a large raw corpus (1.8M Stack v2 files, about 550K curated Stack v3 files) plus a strong compiler-and-ExUnit gate, so both stages of the recipe are available. Elixir's checker also suits RL or DPO on execution results.
- Forgetting matters more for Phoenix than for a pure-language target, since real projects mix HEEx, JS, CSS and SQL.

### Gaps
- No controlled data-volume curve exists for any niche language; MultiPL-T's curve is only in a figure and I could not read its values.
- jmarceno's stage-by-stage contribution, the exact gain from DPO/KTO, and any test of base-then-transfer on Elixir are unavailable.
- The instruction-transfer result has not been independently replicated in anything I found.

## Does language-specific tuning help agentic work, or only completion and single-function generation?

### Takeaway
I found no study that measures a language-specific fine-tune in a multi-turn agent loop, on any language. All measured gains are on completion, single functions or single modules, with repo-level completion the nearest stretch. Adjacent evidence suggests tool access helps niche languages especially, and that agent-format training can help but from a very low level.

### Cited Findings
- The closest fine-tuning result is language-agnostic: Qwen2.5-Coder-7B fully fine-tuned on 5,016 SWE-Smith trajectories plus 145 curated ones rose from 5/300 to 11/300 on SWE-bench Multilingual. — [SWE-Bench++](https://arxiv.org/html/2512.17419v1)
- Jane Street's OCaml work is the nearest language-specific precedent: training on raw code did not teach the model to answer editing requests, so they built prompt-to-diff examples from real work and used RL against builds and tests. No metric was published, and the 50/50 A/B setup was described as a capability, not an outcome. — [talk](https://ai.engineer/talks/building-ai-powered-developer-tools-at-jane-street)
- Strand's per-task results show where tuning does and does not reach beyond generation: test_generation 0.00 to 0.51 and refactoring 0.04 to 0.20, but bug_detection 0.09 to 0.00 and optimisation flat. — [report](https://huggingface.co/blog/Fortytwo-Network/strand-rust-coder-tech-report)
- A NeurIPS 2025 workshop paper from Microsoft reports tool calling works especially well for low-resource languages, better than on high-resource ones, while agentic workflows and RAG favour high-resource ones. No numbers in what I could retrieve. — [NeurIPS page](https://neurips.cc/virtual/2025/loc/san-diego/131706), [listing](https://www.microsoft.com/en-us/research/people/singhmukul/publications/)
- Agentic improvement without fine-tuning: ReChisel's reflection loop on Chisel, and RocqStar's agentic prover at up to 60% of CoqPilot theorems. — [ReChisel](https://arxiv.org/pdf/2505.19734), [RocqStar](https://arxiv.org/pdf/2505.22846v1)
- jmarceno's data card explicitly excludes multi-turn agentic use. — [elixir-sft](https://huggingface.co/datasets/jmarceno/elixir-sft)
- Valim says the agentic case for Elixir rests on reasoning, not measurement. — [Dashbit](https://dashbit.co/blog/why-elixir-best-language-for-ai)
- Ash lists agentic benchmarks as planned only. — [evals](https://github.com/ash-project/evals)
- Leopardi's talk flags test-suite startup time as a real cost in agent loops. — [ElixirConf EU](https://www.elixirconf.eu/talks/agentic-elixir/)
- The Pharo study's strongest context effect came from recently changed methods, not signatures alone, which hints at what an agent should feed a tuned model. — [arXiv PDF](https://arxiv.org/pdf/2607.04939)

### Inferences
- Single-module pass rates are a poor proxy under the project's metric of realistic agent sessions: none of the precedents shows that their gains survive tool use, growing context and repair loops. A tuned model that loses tool-calling discipline could score higher on modules and lower in sessions.
- Data shape matters: Jane Street's experience and the SWE-Smith result suggest agentic ability needs agent-shaped data (diffs, tool calls, error-to-fix pairs), and prompt-to-module pairs alone may not deliver it. A repair-from-compiler-error set is the most agent-like form of single-turn data, and jmarceno's 556 repair rows and Strand's refactoring gain hint that it is learnable.
- A measured, Elixir-specific agentic comparison of tuned against base would be a first for any language.

### Gaps
- No evaluation of any language-specific fine-tune with an agent scaffold such as SWE-agent, Claude Code or OpenCode. No Elixir task exists in the multi-language agent benchmarks checked (SWE-bench Multilingual; SWE-PolyBench covers Java, JS, TS, Python — [repo](https://github.com/amazon-science/SWE-PolyBench)).
- Microsoft's paper's numbers were not retrievable, and whether its low-resource languages include anything functional is unknown.
- The effect of fine-tuning on tool-call formatting or context handling at low-resource languages has not been measured anywhere I found.
