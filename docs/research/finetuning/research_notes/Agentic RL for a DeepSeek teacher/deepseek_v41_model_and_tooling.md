# DeepSeek V4 / V4.1 (focus: DeepSeek-V4.1-Flash-1017) as a model to post-train and as an agentic data generator

Research date: 2026-11-03. Labels: **[maker]** = DeepSeek's own claim; **[measured, third party]** = a number someone other than DeepSeek reports from their own run (still self-reported, not reproduced here); **[secondary]** = news or aggregator; **(my arithmetic)** = hand calculation; **Inference** = my reading, not a source statement.

## Q1. Family map: which V4 / V4.1 models exist, their sizes, architecture, Engram, context, thinking modes, tool format, tokenizer

### Takeaway
As of 2026-11-03, DeepSeek has released eleven V4-family checkpoints. Only one V4.1 line exists: **DeepSeek-V4.1-Flash** (September 2026) and its minor update **DeepSeek-V4.1-Flash-1017** (17 October 2026). There is **no V4.1-Pro or non-Flash V4.1**; DeepSeek calls V4.1-Flash "the smallest model in our new architecture family". V4.1-Flash is a 552B-backbone multimodal MoE with a separate 196B Engram n-gram memory. It activates 8B parameters per token in prefill and 16B in decode, has a 1M-token context and a numeric reasoning effort from 1 to 100, and uses the XML-style "DSML" tool-call format.

### Cited Findings

**Variants and dates**
- The Hugging Face "DeepSeek-V4" collection has 11 items. Sizes are as Hugging Face's safetensors metadata reports them:
  - DeepSeek-V4-Flash-Base 292B and DeepSeek-V4-Flash 291B
  - DeepSeek-V4-Pro-Base 1.6T and DeepSeek-V4-Pro 1.6T
  - DeepSeek-V4-Flash-DSpark 304B and DeepSeek-V4-Pro-DSpark 1.7T (updated Jul 4)
  - DeepSeek-V4-Flash-0731 304B (Aug 1)
  - DeepSeek-V4-Pro-0813 1.7T (Aug 13)
  - DeepSeek-V4-Flash-Vision-Exp 305B (Sep 1)
  - DeepSeek-V4.1-Flash 763B and DeepSeek-V4.1-Flash-1017 763B

  No V4.1-Pro or other V4.1 repo is listed. — [HF collection](https://huggingface.co/collections/deepseek-ai/deepseek-v4)
- **V4 preview (April 2026):**
  - V4-Pro has 1.6T total and 49B active parameters; V4-Flash has 284B total and 13B active. Both have a 1M context, a hybrid of Compressed Sparse Attention (CSA) and Heavily Compressed Attention (HCA), mHC residuals, the Muon optimizer and more than 32T pre-training tokens. The instruct models are mixed FP4 (experts) + FP8. — [V4-Pro model card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro)
  - LMSYS published its day-0 SGLang support on 2026-04-25 — [LMSYS blog](https://www.lmsys.org/blog/2026-04-25-deepseek-v4/). A secondary source dates the weights to 24 April 2026 — [aiweekly](https://aiweekly.co/alerts/deepseek-v4-pro-exits-preview-with-mit-licensed-17t-weights).
- **V4-Flash-0731** is "the official release of DeepSeek-V4-Flash, superseding the preview version, with substantially enhanced agentic capabilities". It uses the DSpark model structure (an attached speculative-decoding module) and adds `reasoning_effort` low/high/max. — [V4-Flash-0731 card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731)
- **V4-Pro-0813** is described as the Pro release that left preview, at 1.7T and about 893 GB with DSpark — [aiweekly, secondary](https://aiweekly.co/alerts/deepseek-v4-pro-exits-preview-with-mit-licensed-17t-weights). I did not open its card.
- **V4.1-Flash:**
  - DeepSeek's X announcement calls it "the smallest model in our new architecture family, with native visual understanding". On the API it replaced V4-Flash under the model name `deepseek-flash`, and the old V4-Flash names became aliases (search summary of the post) — [DeepSeek on X](https://x.com/deepseek_ai/status/2097930608790167907).
  - The technical report is arXiv 2609.19969v1, dated 17 Sep 2026 — [V4.1 report](https://arxiv.org/pdf/2609.19969).
  - The report says "our production deployment launched in September 2026" — [V4.1 report §5.1.4](https://arxiv.org/pdf/2609.19969).
- **V4.1-Flash-1017** is described as a "minor update" to V4.1-Flash. The card says it "reduces task execution time and output length". Licence MIT; 763B safetensors params; BF16/F32/F8_E4M3/I8 tensors. — [1017 card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017)

**V4.1-Flash architecture (from the report and config.json)**
- **Size:** 552B backbone parameters plus 196B Engram parameters. It activates 8B parameters per token during prefill and 16B during decode. — [V4.1 report §2.1](https://arxiv.org/pdf/2609.19969)
- **Layers:** 40 layers, split into a 20-layer causal encoder and a 20-layer decoder ("Causal Encoder-Decoder", CED, inspired by YOCO). The decoder's global KV is projected from the last encoder layer's hidden state, which "nearly halves prefill computation". — [V4.1 report §2.2](https://arxiv.org/pdf/2609.19969)
- **Attention (CSA2):** Compressed Sparse Attention 2 with three static layer modes:
  - Full: computes its own main KV and indexer, and picks top-K itself.
  - Reindex: reuses the earlier layer's KV and rescoring its keys.
  - Reuse: reuses both the KV and the earlier layer's top-K indices.
  - A Hierarchical Sparse Indexer in the decoder limits later indexers to a candidate pool of at most 2,048 blocks × 8 positions = 16,384 positions.
  - V4's CSA/HCA hybrid is replaced by pure CSA2. — [V4.1 report §2.3](https://arxiv.org/pdf/2609.19969)
- **Layer configuration:**
  - The first two encoder layers use sliding-window attention only. The other 18 encoder layers are CSA2 with compression ratio 2, in three groups of six (one Full layer, then five Reuse layers).
  - The 20 decoder layers are CSA2 with ratio 1 in five groups of four.
  - Indexer: 32 heads of dimension 128, top-k 512. Attention: 64 query heads of dimension 512, query compression dimension 1280. SWA window 128.
  - MoE in every block: 1 shared expert and 384 routed experts of intermediate size 2304, with 6 routed experts active per token. mHC expansion factor 4.
  - Vision encoder: 32 layers, hidden size 1024. — [V4.1 report §4.2.1](https://arxiv.org/pdf/2609.19969)
- **config.json:**
  - `DeepseekV41ForCausalLM` / `deepseek_v41`; vocab 129,280; hidden size 5,120; 40 layers; 64 heads with 1 KV head and head_dim 512.
  - q_lora_rank 1,280, o_lora_rank 1,024; index_topk 512.
  - 384 routed experts, 1 shared, 6 per token; moe_intermediate_size 2,304.
  - max_position_embeddings 1,048,576 (YaRN factor 16 over 65,536); sliding_window 128.
  - num_nextn_predict_layers 3; dspark block size 5 (128 routed experts, 3 per token).
  - FP8 quantization with ue8m0 scales and an FP4 expert dtype.
  - Engram: layer ids [1, 14], vocab 16,000,000, 8 heads × 256, compressed vocab 99,092. — [config.json](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017/blob/main/config.json)
- **KV cache:**
  - Global KV is 890 bytes per token, about 1/4 of V4-Flash's 3,514 bytes; V3.2 needed 48,068 and V1 389,120.
  - Persistent KV (on SSD or in host memory) is about 1/8 of V4-Flash's, thanks to "SWA Bounded Replay": SWA KV is no longer persisted and is rebuilt by replaying only the last n_win = 128 tokens.
  - The main KV is FP4 (E2M1 with one E4M3 scale per 16 channels), introduced through QAT during post-training; the SWA KV stays FP8. — [V4.1 report abstract, Fig. 1, §2.4.4, §3.2](https://arxiv.org/pdf/2609.19969)
- **Engram (conditional memory):**
  - It follows DeepSeek's earlier Engram design: tokenizer compression, multi-head hashing, context-aware gating and multi-branch integration. The short causal convolution is dropped.
  - The 196B parameters are split evenly across two modules, at layers 1 and 14. Each module uses N-gram orders {2, 3, 4} with 8 hash heads and an embedding dimension of 2048 per order. Each head indexes a table of about 16M entries, with sizes chosen as distinct primes. Tables and projections are FP8.
  - Addressing depends only on the input tokens and is deterministic, so rows "can be prefetched from host memory via background RDMA transfers". — [V4.1 report §2.4.2](https://arxiv.org/pdf/2609.19969)
- **Engram training:**
  - In pre-training the tables are trained, but not with Adam (whose optimizer state would be too large). They use a momentum update with Sinkhorn balancing, and the Engram learning rate is scaled 5×.
  - During DeepSeek's RL rollouts, "Engram embedding tables remain resident in GPU memory". — [V4.1 report §2.5, §3.1.3, §4.2.2](https://arxiv.org/pdf/2609.19969)
- **MTP and DSpark:**
  - DeepSeek "omit[s] the MTP module during backbone pre-training". Instead it trains DSpark separately after pre-training, with the backbone frozen.
  - DSpark has three Transformer blocks with SWA 128, drafts 5 positions in one pass, and adds a Markov head and a confidence head that schedule how much draft to verify.
  - In post-training, DSpark keeps training alongside the backbone without back-propagating into it, "enabling it to accelerate both online serving and rollout generation for RL and OPD". — [V4.1 report §2.1, §2.4.3](https://arxiv.org/pdf/2609.19969)
  - vLLM's recipe says the drafter adds about 14B parameters — [vLLM recipe](https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4.1-Flash).
- **Pre-training:**
  - 45T multimodal tokens, text to multimodal at 7:1, batch size 100.6M tokens, "no instability".
  - Sparse attention is trained from scratch at 64K sequence length, and context is extended to 1M at 34T tokens.
  - Optimizers: Muon and head-wise Muon for linear weights, AdamW for norms, Sinkhorn-balanced updates for embeddings, Engram and the head.
  - The vision encoder (DeepSeek-ViT) was pre-trained contrastively on about 47B image-text pairs and then trained autoregressively on 236B tokens with a 4B MoE. — [V4.1 report §4.1–4.2](https://arxiv.org/pdf/2609.19969)
- **Base model quality:** V4.1-Flash-Base matches or beats V4-Pro-Base on several base benchmarks. Examples: HumanEval 79.4 vs 76.8, BigCodeBench 60.6 vs 59.2, MMLU-Pro 74.1 vs 73.5. It is lower on SimpleQA-Verified (42.3 vs 55.2) and LongBench-V2 (45.2 vs 51.5). — [V4.1 report Table 1](https://arxiv.org/pdf/2609.19969)

**Context, thinking, tool calls, tokenizer**
- **Context and sampling:** 1M tokens; temperature 1.0, top_p 1.0 (0.95 also listed); max_tokens "≥ 256K". — [1017 card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017), [V4.1-Flash card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash)
- **Reasoning effort:** an integer b from 1 to 100, prepended to the system prompt as `Reasoning Effort: {effort} (range 1-100; ...)`. The public API exposes `max`/`high`/`low`, which map to 100/75/50. — [V4.1 report §5.1.4, Table 2](https://arxiv.org/pdf/2609.19969)
- **Conflicting tier mappings:**
  - Unsloth's guide adds `medium` = 62 and gives 75 as the default — [Unsloth docs](https://unsloth.ai/docs/models/deepseek-v4.1-flash).
  - vLLM's recipe says the default effort is 50 and also lists an `xhigh` tier — [vLLM recipe](https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4.1-Flash).

  These disagree and should be checked against `encoding.py`.
- **V4 thinking modes:** V4 had three discrete modes (Non-think, Think High, Think Max). Think Max injects a fixed system instruction. — [V4 report §5.1.1, Tables 2–3](https://arxiv.org/pdf/2606.19348)
- **Tool-call format (V4 series):** a "|DSML|" special token with an XML block: `<|DSML|tool_calls>`, then `<|DSML|invoke name="...">` and `<|DSML|parameter name="..." string="true|false">`. String values are written raw; other types as JSON. DeepSeek says XML "effectively mitigates escaping failures and reduces tool-call errors". — [V4 report §5.1.1, Table 4](https://arxiv.org/pdf/2606.19348)
- **V4.1 parsers:** vLLM uses `--tool-call-parser deepseek_v41` and `--reasoning-parser deepseek_v41`. Tool calls use DSML tags, and tool results come back in `<tool_result>` tags. — [vLLM recipe](https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4.1-Flash)
- **Interleaved thinking:** in tool-calling conversations, V4 keeps all reasoning across user-turn boundaries; in plain chat it drops earlier reasoning. Harnesses that simulate tools through user messages (for example Terminus) "may not trigger the tool-calling context path", and DeepSeek recommends non-think mode for them. — [V4 report §5.1.1, Fig. 7](https://arxiv.org/pdf/2606.19348)
- **Chat template:** none in Jinja. A Python reference `encoding/encoding.py` covers multi-turn chat, tool calls, thinking, numeric effort, mid-conversation system messages and images, and "deepseek-recipe" Rust libraries with Python bindings convert Messages / Chat Completions / Responses requests. — [1017 card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017)
- **Tokenizer:** vocab_size is 129,280 — [config.json](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017/blob/main/config.json). vLLM maintainers say V4.1 has its own tokenizer mode, parsers and config class, separate from V4 — [vLLM #56400 via search summary](https://github.com/vllm-project/vllm/issues/56400).

**Checkpoint size breakdown (vLLM recipe)**
- About 511 GB (476 GiB) on disk:
  - routed and DSpark experts (MXFP4): 259.5 GiB
  - Engram tables (FP8): 183.1 GiB
  - attention, dense projections and routers (FP8): 6.9 GiB
  - embedding and LM head (BF16) plus norms (FP32): 3.9 GiB
  - UE8M0 block scales: 21.9 GiB

  The recipe's planning figure is `vram_minimum_gb: 614`. — [vLLM recipe](https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4.1-Flash)
- The Transformers issue gives the checkpoint as about 510 GB, with each of the two Engram FP8 tables about 98 GB — [transformers #48755](https://github.com/huggingface/transformers/issues/48755). LMSYS gives 189 GiB for the two tables — [LMSYS V4.1 blog](https://www.lmsys.org/blog/2026-09-10-deepseek-v41/).

### Inferences
- **Parameter count:** the 763B safetensors count ≈ 552B backbone + 196B Engram + about 14B DSpark drafter + about 0.4B ViT, which totals about 762B (my arithmetic). The 763B on the card is therefore everything in the repo, not the "model size" in the usual sense.
- **Engram is static:** for serving, Engram behaves like a large lookup table that never needs GPU FLOPs. With only 2 modules × 3 orders × 8 heads rows touched per token, it lives naturally on host RAM or NVMe through mmap. That is why consumer engines can keep it off-GPU.
- **What "DeepSeek V4.1" means:** when the owner says "DeepSeek V4.1", the only open-weights candidate is V4.1-Flash, with 1017 as the current checkpoint. The "smallest model in our new architecture family" wording, and the report's "new starting point for our continued scaling efforts" (§1), suggest larger V4.1 models will follow, but none had been released as of the collection snapshot.

### Gaps
- Exact Hugging Face release dates for the V4.1-Flash and 1017 repos. The collection shows "18/17 days ago", and the "1017" suffix implies 17 Oct. The 1017 card gives no date.
- The V4-Pro-0813 card itself was not opened, so its 1.7T and 893 GB figures are secondary.
- The arXiv number of the V4 report (2606.19348) sits oddly against the April preview date; I did not resolve when the PDF was first published.

## Q2. Licence: weights, outputs and API terms

### Takeaway
The weights and code are under a plain MIT licence with no acceptable-use policy and nothing restricting outputs. DeepSeek's API terms (in force since 29 April 2026) go further: they assign output rights to the user and explicitly allow "training other models (such as model distillation)". Neither the open weights nor the API forbid using V4.1 outputs to train another model.

### Cited Findings
- **Weights and code:** the 1017 repository and its weights are under MIT. The LICENSE file is the standard MIT text ("Copyright (c) 2023 DeepSeek"), with no extra restrictions, no AUP, and nothing about outputs or training other models. — [LICENSE file](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017/blob/main/LICENSE), [1017 card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017)
- **Rest of the family:** V4-Pro, V4-Flash and V4-Flash-0731 are also MIT for repo and weights — [V4-Pro card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro), [V4-Flash-0731 card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731)
- **DeepSeek Open Platform (API) Terms of Service** (released 22 April 2026, effective 29 April 2026):
  - §4.2(2): "We assign any rights, title, and interests—if any—in the Outputs of the Services to you".
  - §4.2(3): users may use inputs and outputs for "training other models (such as model distillation)" and for derivative product development.
  - I found no non-compete clause. The restrictions are trademarks, infringing others' rights, export controls and sanctions, and API-key hygiene.
  - Revisions take effect seven days after release. — [Open Platform ToS](https://cdn.deepseek.com/policies/en-US/deepseek-open-platform-terms-of-service.html)
- **Consumer Terms of Use:** they carry a similar permission, conditioned on the use being "legal and adhere to these Terms" (search summary) — [DeepSeek Terms of Use](https://cdn.deepseek.com/policies/en-US/deepseek-terms-of-use.html)
- **Third-party hosting:** an NVIDIA NIM listing of V4-Pro mentions the NVIDIA Open Model Agreement, which covers NVIDIA's hosted packaging, not DeepSeek's licence (search summary) — [NVIDIA NIM](https://docs.api.nvidia.com/nim/reference/deepseek-ai-deepseek-v4-pro)
- **Disputed provenance:** OpenAI has alleged that DeepSeek distilled OpenAI outputs. These are OpenAI's claims, not findings. — [technology.org, secondary](https://www.technology.org/2026/02/13/deepseek-may-have-trained-on-openais-outputs-and-openai-is-not-amused/)
- **Training-data disclosure:** NVIDIA's card for V4.1 notes that the post-training corpus names, licences and collection procedures are not disclosed (search summary) — [NVIDIA NIM V4.1-Flash](https://docs.api.nvidia.com/nim/reference/nvidia-deepseek-v4_1-flash)

### Inferences
- **Generating training data:** for data generated locally from the open weights, MIT puts no conditions on the outputs. For data generated through DeepSeek's own API, §4.2(3) explicitly allows distillation. Both routes look clean for publishing a dataset or a fine-tune. A project with a "publishable data only" rule should still record the model version, the licence snapshot and the ToS date with each dataset.
- **Provenance:** the undisclosed post-training data and the distillation allegations are a provenance caveat to note in a dataset card, not a licence restriction.

### Gaps
- I did not read the full consumer Terms of Use page myself; that point comes from a search summary.
- I did not check third-party API hosts' terms (Fireworks, Novita, Together and others). Each host's own terms apply to outputs bought there.

## Q3. DeepSeek's post-training recipe, benchmark results (agentic coding first) and stated weaknesses

### Takeaway
- **V4:** DeepSeek trained domain specialists (SFT, then GRPO RL) and merged them into one model by multi-teacher, full-vocabulary on-policy distillation (OPD). This replaced V3.2's mixed RL stage.
- **V4.1:** the same SFT → RL → OPD recipe "without algorithmic modifications" (over 40 OPD teachers). DeepSeek credits "essentially all" of the gains to automated synthesis of agent tasks and environments, RL across many scaffolds, and merging RL checkpoints.
- **Results:** V4.1-Flash-1017 claims 77.0 on DeepSWE v1.1, above Opus-5 at 74.0 in DeepSeek's own table, and 42.3 on Terminal-Bench 4.0. V4.1 reports no SWE-bench Verified, Pro or Multilingual table, and there is no Elixir or functional-language data anywhere.

### Cited Findings

**V4 recipe (V4 report)**
- **Overall pipeline:** it "largely mirrored that of DeepSeek-V3.2", but "the mixed Reinforcement Learning (RL) stage was entirely replaced by On-Policy Distillation (OPD)". — [V4 report §5.1](https://arxiv.org/pdf/2606.19348)
- **Specialist training:** each domain specialist got SFT, then RL with GRPO "maintaining hyper-parameters closely aligned with our prior research". Separate specialists were trained for each reasoning mode, with different length penalties and context windows. — [V4 report §5.1.1](https://arxiv.org/pdf/2606.19348)
- **Generative Reward Model:** for hard-to-verify tasks, DeepSeek uses rubric-guided RL data and a Generative Reward Model (GRM), with "RL optimization directly to the GRM itself". The actor serves as the judge, and there are no scalar reward models. — [V4 report §5.1.1](https://arxiv.org/pdf/2606.19348)
- **On-policy distillation:** the loss is a weighted sum of reverse KL(π_θ ‖ π_Ei) over N experts, computed on student-sampled trajectories. DeepSeek uses full-vocabulary logit distillation rather than a token-level KL estimate (which has "high variance … and often causes training instability"), with "more than ten teacher models". — [V4 report §5.1.2](https://arxiv.org/pdf/2606.19348)
- **FP4 QAT:** applied during post-training to the MoE experts and the indexer QK path. The FP4→FP8 dequantization is lossless under a block-scale condition. — [V4 report §5.2.1](https://arxiv.org/pdf/2606.19348)
- **Internal coding benchmark (V4):** 30 tasks from real internal R&D (PyTorch, CUDA, Rust, C++). Pass rates: V4-Pro-Max 67 %, Claude Sonnet 4.5 47 %, Opus 4.5 70 %, Opus 4.6 Thinking 80 %.
- **Developer survey (V4):** of N = 85 DeepSeek developers, 52 % said V4-Pro was ready as their default coding model, 39 % leaned yes and under 9 % said no. They cited "trivial mistakes, misinterpretation of vague prompts, and occasional over-thinking". — [V4 report §5.4.4](https://arxiv.org/pdf/2606.19348)

**V4.1 recipe (V4.1 report §5)**
- **No new algorithms:** "In this release, we refrain from introducing novel post-training algorithms… our efforts are concentrated almost entirely on what the model is trained on rather than how." The pipeline:
  1. synthesizes verifiable tasks with reference solutions and rewards,
  2. builds interactive environments procedurally,
  3. filters, deduplicates and calibrates difficulty.

  DeepSeek: "the marginal return of engineering the data and environment pipeline substantially exceeds that of algorithmic novelty". — [V4.1 report §5.1](https://arxiv.org/pdf/2609.19969)
- **Task synthesis:**
  - A task is a triplet of problem, environment and verification system. The model itself is trained to construct tasks, with difficulty and correctness as reward signals.
  - Tasks are re-audited every time a new RL run uses them.
  - General-agent environments come from employee and partner workflows, mocked SaaS and enterprise tools, and failure cases. — [V4.1 report §5.1.1](https://arxiv.org/pdf/2609.19969)
- **Coding-agent environments** come from two sources: coding-agent sessions from employees and partners (filtered for complexity or poor model performance, deduplicated by trajectory) and public GitHub repositories above a star-count threshold. A multi-agent pipeline builds them:
  - a builder agent checks that the project builds and runs in a container, picks a commit, designs implementation directions and writes fail-to-pass and pass-to-pass checks;
  - a setup agent installs dependencies and removes solution leaks;
  - several solver agents attempt the task;
  - a QA agent checks environment errors, mismatches and "hackability";
  - a repair agent fixes issues and recalibrates difficulty. — [V4.1 report §5.1.1](https://arxiv.org/pdf/2609.19969)
- **RL on synthesized tasks:**
  - Large-scale asynchronous RL, scaled in compute and in number of scaffolds: multi-version Claude Code, OpenCode, Pi, and DeepSeek Harness in Standard and PTC modes.
  - Rollouts are split into an agent sandbox (runs the scaffold) and a worker container (normalizes trajectories).
  - "we use model merging to reinitialize successive RL runs… merge checkpoints from runs across scaffolds or configurations". — [V4.1 report §5.1.2, Figs. 7–8](https://arxiv.org/pdf/2609.19969)
- **RL scaling curves (Fig. 7, Minimal mode of DeepSeek Harness), read off the chart by me, so approximate:** over about 2,000 cumulative RL steps:
  - DeepSWE v1.1: about 57 → about 72 % pass@1
  - SWE-Bench Pro: about 60 → about 64.5 %
  - Terminal-Bench 2.1: about 80 → about 90 %
  - Terminal-Bench 3.0 (no-GPU): about 6 → about 28 %, with the last gain from extending context to 1M

  [V4.1 report Fig. 7](https://arxiv.org/pdf/2609.19969)
- **Sandbox scale (DSec):** DeepSeek's sandbox platform runs "millions of concurrent sandbox instances" and raised density from about 1,000 to over 2,500 live containers per node. — [V4.1 report §5.1.3](https://arxiv.org/pdf/2609.19969)
- **Reward hacking:** observed hacks include XFS-driver permission exploits, illegal memory access in AppArmor, "leaking answers from package mirror services", and deleting binaries or filesystems. DeepSeek's mitigations are per-sandbox AppArmor profiles, eBPF network policies, and treating a crash as a failed trajectory with a "repercussion" signal. — [V4.1 report §5.1.3](https://arxiv.org/pdf/2609.19969)
- **Effort-conditioned RL:**
  - Each prompt is sampled at several effort levels b.
  - Advantages are group-relative within each (prompt, b) subgroup.
  - A length penalty −min{C_max, k(b)·ℓ/L_norm} is applied, where k(b) decays exponentially with effort. — [V4.1 report §5.1.4](https://arxiv.org/pdf/2609.19969)
- **Async RL and OPD infrastructure:**
  - Rollout and training share the same devices, time-shared.
  - Dispatch is per sample, keyed to the GRPO group size.
  - Concatenated routing replay is used for samples that span checkpoints.
  - Length-bias controls: per-dataset concurrency limits, and discarding early short samples.
  - Off-policy ratio is bounded, and over-stale tokens are masked out of the loss.
  - Rollouts can be interrupted at any token, with KV and routing state persisted.
  - Final full-vocabulary OPD uses "over 40 teacher models", which may differ architecturally from the student. — [V4.1 report §5.2](https://arxiv.org/pdf/2609.19969)
- **Agent Team mode:** a lead agent spawns persistent teammates who share one checkout and a mailbox, and the mode is trained with RL. The reward combines task success, a collaboration bonus and a critical-path latency penalty. Preliminary results: ProgramBench Almost@1 30.04 % multi-agent vs 20.39 % single-agent at 8 h; FrontierSWE v2 Mean@5 32.90 % vs 28.20 % at 20 h. — [V4.1 report §5.3.5, Fig. 10](https://arxiv.org/pdf/2609.19969)
- **Compute:** neither report gives pre- or post-training GPU-hours in the pages I read (see Gaps).

**Benchmarks: agentic coding (all [maker])**

V4 preview, Max mode:

| Benchmark | V4-Pro | V4-Flash |
|---|---|---|
| SWE-bench Verified | 80.6 | 79.0 |
| SWE-bench Pro | 55.4 | 52.6 |
| SWE-bench Multilingual | 76.2 | 73.3 |
| Terminal-Bench 2.0 | 67.9 | 56.9 |
| LiveCodeBench | 93.5 | 91.6 |
| Codeforces | 3206 | 3052 |

The V4-Pro card adds that V4-Flash-Max "trails it on pure knowledge tasks and the most complex agentic workflows". — [V4-Pro card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro)

V4-Flash-0731 (minimal DeepSeek Harness, max effort):

| Benchmark | V4-Flash-0731 | V4-Flash preview | Opus-4.8 |
|---|---|---|---|
| Terminal-Bench 2.1 | 82.7 | 61.8 | 85.0 |
| DeepSWE | 54.4 | 7.3 | 58.0 |
| NL2Repo | 54.2 | 39.4 | 69.7 |
| Toolathlon-Verified | 70.3 | 49.7 | 76.2 |

[V4-Flash-0731 card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash-0731)

V4.1-Flash, Max effort (report Table 3):

| Benchmark | V4.1-Flash | V4-Pro | V4-Flash | Opus-5 | GPT-5.6 Sol | K3 | GLM-5.3 |
|---|---|---|---|---|---|---|---|
| Terminal-Bench 2.1 | 90.6 | 87.9 | 82.7 | 89.1 | 88.8 | 88.3 | 88.2 |
| Terminal-Bench 3.0 | 30.0 | 11.8 | 7.6 | 43.3 | 34.4 | — | — |
| Terminal-Bench 4.0 | 31.2 | 12.4 | 7.0 | 51.8 | 39.9 | — | — |
| DeepSWE v1.1 | 74.2 | 62.7 | 54.4 | 74.0 | 73.0 | 67.5 | 66.9 |
| ProgramBench | 20.3 | 15.5 | — | 37.0 | — | — | — |
| NL2Repo | 65.4 | 61.5 | 54.2 | 75.3 | — | — | — |
| Codeforces | 3471 | 3348 | 3289 | — | — | — | — |

Notes on this table:
- "—" means the value was not captured here (or, for ProgramBench V4-Flash, not reported); the source table may list more of the competitor scores.
- The Hugging Face card's own table gives NL2Repo for V4.1-Flash as **64.0**, against **65.4** in the report and in the 1017 card's comparison column. This is a small inconsistency.

[V4.1 report Table 3](https://arxiv.org/pdf/2609.19969), [V4.1-Flash card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash)

V4.1-Flash-1017 vs V4.1-Flash:

| Benchmark | 1017 | V4.1-Flash | Opus 5 |
|---|---|---|---|
| Terminal-Bench 4.0 | 42.3 | 31.2 | 51.8 |
| DeepSWE v1.1 | 77.0 | 74.2 | 74.0 |
| ProgramBench | 29.1 | 20.3 | 37.0 |
| NL2Repo | 68.2 | 65.4 | 75.3 |
| AutomationBench v1.0.6 | 60.5 | 54.8 | 50.3 |
| Agents' Last Exam | 35.4 | 31.8 | 28.6 |
| Apex Bench v1.1 | 72.1 | 64.6 | 65.8 |
| HLE (no tools) | 42.6 | 36.8 | 56.3 |

- Harness notes on the card: "Claude Code for Terminal-Bench 4.0; Mini-SWE-V2 for DeepSWE v1.1".
- The card's eval-results block also lists "cwe-bench Resolve Rate 57" and "Terminal-Bench Science 12.9". I could not tell what "cwe-bench" is; it may be a typo. — [1017 card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017)

**Scaffold sensitivity (V4.1-Flash, Max effort)**

| Benchmark | Claude Code | Codex | OpenCode | Pi | mini-SWE | DSH Minimal | DSH Standard | DSH PTC |
|---|---|---|---|---|---|---|---|---|
| DeepSWE v1.1 (N = 8) | 69.8 | 65.6 | 65.5 | 66.2 | 74.2 | 72.6 | 70.5 | 67.6 |
| Terminal-Bench 2.1 (N = 3, no network) | 88.0 | 84.1 | 85.0 | 86.1 | 90.3 | 90.6 | 85.8 | 85.8 |

[V4.1 report Table 4](https://arxiv.org/pdf/2609.19969)

**Effort trade-off**
- Raising effort from 25 to 100 lifts the 8-benchmark reasoning average from 67.1 to 76.3, DeepSWE from 66.0 to 74.2 and Terminal-Bench 2.1 from 82.4 to 90.6, at about 2.5× the output tokens.
- "the 60–80 range already recovers most of the accuracy … at less than half of its token budget". Going to 100 lengthens agent trajectories 1.6–1.8× "for only marginal improvements". — [V4.1 report §5.3.2–5.3.3, Fig. 9](https://arxiv.org/pdf/2609.19969)

**Evaluation hygiene:** DeepSeek restricts internet access, strips Git histories and purges package caches. Even so, it saw exploit-seeking during testing, such as decompiling Ubuntu packages in CyberGym. — [V4.1 report §5.3.1](https://arxiv.org/pdf/2609.19969)

**Multilingual coding and Elixir:**
- The V4.1 report has no per-language coding table. Its only language statement is that the pre-training corpus adds recent code "to cover a broader range of programming languages". — [V4.1 report §4.1](https://arxiv.org/pdf/2609.19969)
- V4's only multilingual agentic number is SWE-bench Multilingual: 76.2 for Pro and 73.3 for Flash — [V4-Pro card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro).
- No Elixir, Erlang/BEAM or functional-language results turned up in the reports or a targeted search — [search: V4 Elixir benchmarks](https://arxiv.org/pdf/2606.19348).

**Weaknesses DeepSeek names**
- **V4.1:**
  - "a gap with giant models remains on science-oriented agentic tasks, such as Terminal-Bench 4.0 … that require expert-level domain knowledge".
  - A multimodal gap remains against closed systems.
  - "Potential selection errors in CSA2 and approximate state reconstruction in SWA Bounded Replay may still cause capability degradation in untested boundary cases". The cases DeepSeek names are sparse retrieval over long contexts and resumption at cache boundaries.
  - A gap remains to "Fable-5 and GPT-6 Astra" on "complex, high-difficulty reasoning and edge cases". — [V4.1 report §1, §6](https://arxiv.org/pdf/2609.19969)
- **V4:** a "relatively complex" architecture, and training-stability tricks (Anticipatory Routing, SwiGLU clamping) whose "underlying principles remain insufficiently understood". — [V4 report §6](https://arxiv.org/pdf/2606.19348)

### Inferences
- **The 1017 Terminal-Bench 4.0 jump is not clean.** The 31.2 → 42.3 comparison may mix harnesses: the V4.1 report evaluates code agents with DeepSeek Harness Minimal, while the 1017 card says Claude Code was used for TB 4.0. Read it as indicative.
- **DeepSeek's lesson favours data over algorithms.** That is good news for a small team: stock GRPO/DAPO plus a well-built environment pipeline (verifiable fail-to-pass tasks from real repos, QA and anti-hack agents, multi-scaffold rollouts) is the recipe, not a secret algorithm. The agent-team pipeline for building tasks is directly reusable for Elixir repositories.
- **Elixir is a genuine unknown.** DeepSWE, Terminal-Bench, NL2Repo and SWE-bench Multilingual give no evidence on Elixir. The owner's 20-case elixir-swe-bench would be the first data point. The model's strength across scaffolds (69.8–74.2 on DeepSWE) suggests it would work as a teacher in an off-the-shelf harness such as Claude Code, OpenCode or Pi.
- **Use effort 60–80 for data generation.** DeepSeek's own curve says this keeps most of the quality at under half the tokens, which matters when local decode is about 20–40 tok/s.

### Gaps
- Compute for pre- and post-training (GPU-hours, cluster size) for V4 and V4.1. It was not in the pages I read; I did not read V4 report pp. 34–43 or V4.1 pp. 46–50.
- The number and domains of V4's specialists beyond "more than ten teacher models".
- The exact GRPO variant and settings (clipping, KL, group size).
- SWE-bench Verified, Pro and Multilingual for V4.1-Flash or 1017. Only the Fig. 7 SWE-Bench Pro RL curve exists (about 64–65 %, my reading of the chart).
- Which languages DeepSWE v1.1 and NL2Repo cover.
- Independent (non-DeepSeek) agentic-coding evaluations of 1017. A search for community impressions (r/LocalLLaMA etc.) found none.

## Q4. Trainability today: SFT, LoRA and RL frameworks for V4 / V4.1, and the hardware they need

### Takeaway
V4.1-Flash can be RL-trained today, but only on datacenter clusters through Megatron-based stacks: **Miles** (full RL validated on 16 × GB300, and LoRA RL validated on 16 × H200, merged 27 Oct 2026), the **mcore-bridge** layer behind ms-swift/Megatron-SWIFT (merged 20 Sep 2026, tested only on a 4-layer slice), and an **NVIDIA NeMo AutoModel** recipe (16 nodes, EP64). There is no consumer-GPU or CPU-offload LoRA path for V4.1: KTransformers' MXFP4-on-CPU LoRA covers only the April V4-Flash. Hugging Face Transformers support is still an open PR. Unsloth, LLaMA-Factory, verl, slime, DeepSpeed and torchtitan show no V4.1 training support.

### Cited Findings

**V4.1-Flash**
- **Miles (RadixArk), full RL:**
  - DeepSeek-V4.1-Flash RL runs on the standard Miles image: a Megatron-Core plugin for training and SGLang for rollouts, with DP/TP/SP/EP/PP/CP.
  - The trainer implements the shared attention state (CSA2), mHC and Engram. The frozen FP8 Engram tables are backed by host memory and "excluded from weight synchronization", so **Engram is not trained**.
  - Training reproduces the engine's FP4 rounding for compressed latents and indexer Q/K, and FP8 for the SWA cache, with straight-through gradients.
  - Rollout Routing Replay feeds the sampled expert choices back into training; the indexer top-k is recomputed, not replayed.
  - Validated on **16 × GB300** (TP4, EP16, 128 samples per step, colocated). On DAPO-Math-17K, mean reward went from 0.51 to 0.78 over 80 steps, trainer–rollout per-token KL stayed at 0.0012–0.0017, and the run passed 120 steps without failure. — [LMSYS V4.1 blog](https://www.lmsys.org/blog/2026-09-10-deepseek-v41/)
- **Miles LoRA RL (PR #4205, merged 27 Oct 2026):**
  - LoRA targets attention (`wq_a`, `wkv`, `wq_b`, `wo_b`, and `wo_a` as a grouped LoRA) and the **shared expert** (w1/w3/w2). It does **not** adapt routed experts, the compressor, the indexer or Engram. Rank 16, default learning rate 1e-5.
  - Full 40-layer model trained on **2 × 8 H200** (TP4/EP16, colocated). Rollout runs on one 16-GPU SGLang engine (BF16) or two TP8 engines (FP8); SGLang serves the LoRA adapters.
  - FP8 rollout runs of 100 steps took about 307–340 s per step, kept KL around 0.0027–0.0028 and raised mean reward by about 0.11 (0.745→0.856 at lr 5e-5; 0.703→0.812 at 1e-5). The task is not stated in what I extracted.
  - The BF16 run stopped at step 43 at about 945 s per step.
  - Limitations: no routed-expert adapters and no multi-LoRA. — [Miles PR #4205](https://github.com/radixark/miles/pull/4205)
- **Modal's Miles fork:** it has PRs for multi-LoRA on V4.1 and for prefetching Engram tables (each table about 95 GiB). A search summary says the multi-LoRA path found "Megatron-Bridge has no V4.1 mapping", so it could not build, load or export through Megatron-Bridge. — [modal-projects/miles PR #15](https://github.com/modal-projects/miles/pull/15), [PR #30](https://github.com/modal-projects/miles/pull/30)
- **ModelScope mcore-bridge PR #201** ("Support dpsk-4.1 sft and rl"), merged 20 Sep 2026:
  - Adds the deepseek_v41 bridge: CSA2 compressor and indexer, Single-Pass mHC, **trainable** Engram modules, a vision tower and aligner, and DSpark/MTP weight mapping (the draft stack frozen).
  - Adds FP8/FP4 dequantization, and lets RL weight sync skip Engram export.
  - Fixes LoRA export: it writes 155 `lora_A` and 155 `lora_B` tensors.
  - Tested parallelism: PP2, PP2×VPP2, PP2×EP2, PP2×DP2, CP2, packing. Loss differences of 0.0003–0.018 % were measured, but **only on a tiny 4-layer model**.
  - Engram inference was removed (its forward fails loudly). It needs a Megatron build with `megatron.core.models.hybrid`. — [mcore-bridge PR #201](https://github.com/modelscope/mcore-bridge/pull/201)
- **NVIDIA NeMo AutoModel:**
  - It has a `deepseek_v41` implementation whose Engram modules shard tables across ranks — [NeMo AutoModel Engram](https://docs.nvidia.com/nemo/automodel/nemo-automodel/nemo_automodel/components/models/deepseek_v41/engram).
  - Its documented V4.1-Flash recipe is an image-text fine-tune (`deepseek_v41_flash_medpix_4k_ep64.yaml`) on **16 nodes**: FSDP2, EP64, TP/PP/CP 1, BF16, activation checkpointing, tilelang attention, HybridEP dispatcher. The page does not say whether it is LoRA or full fine-tuning. — [NeMo AutoModel V4.1-Flash](https://docs.nvidia.com/nemo/automodel/model-coverage/vision-language-models/deepseek-ai/DeepSeek-V4.1-Flash)
- **Hugging Face Transformers:**
  - Issue #48755 (opened 13 Sep 2026) is still open. It links PR #48721 (text backbone `DeepseekV41ForCausalLM`) and PR #48768 (vision, a draft that depends on #48721), and neither is shown merged.
  - The PR claims `from_pretrained`/`generate`, expert parallelism and 1M context. It says nothing on training or PEFT. — [transformers #48755](https://github.com/huggingface/transformers/issues/48755)
  - The model card nevertheless shows `AutoModelForCausalLM` with `device_map="auto"` — [V4.1-Flash card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash).
- **vLLM:** LoRA support for V4.1-Flash is an open feature request (#57166, opened 16 Sep 2026, assigned, no PR) — [vLLM #57166](https://github.com/vllm-project/vllm/issues/57166).
- **Unsloth:** it ships GGUFs and a guide for V4.1 but does not say it supports fine-tuning V4.1 — [Unsloth docs](https://unsloth.ai/docs/models/deepseek-v4.1-flash), [Unsloth GGUF](https://huggingface.co/unsloth/DeepSeek-V4.1-Flash-1017-GGUF).
- **Hosted:** Fireworks lists fine-tuning (LoRA) as supported for V4.1 Flash and the 1017 checkpoint. Prices and details are out of scope here. — [Fireworks 1017](https://fireworks.ai/models/deepseek-ai/deepseek-v4p1-flash-1017)

**V4 / V4-Flash (closest precedent)**
- **ms-swift / Megatron-SWIFT** supports V4-Flash:
  - LoRA example: 8 GPUs, EP8, TP1, rank 16, alpha 32, max_length 4096, MTP layer 1. Full fine-tuning example: 64 GPUs (EP8 × PP8).
  - No TP (waiting on Megatron-Core) and no blockwise FP4 training: FP4 experts are converted to FP8/BF16 on load.
  - LoRA with FP8 is "not recommended" because FP8 rounding can wipe out the LoRA delta; merge against BF16 instead.
  - The doc lists no LoRA target modules; GPU type and memory were shown only in an image. — [ms-swift V4 best practice](https://swift.readthedocs.io/en/v4.4/_sources/BestPractices/deepseek-v4.md.txt)
- **verl:**
  - v0.9.0 (14 Aug): end-to-end DeepSeek-V4 GRPO with a Megatron-Bridge actor and reference, vLLM rollout and FP8/MXFP4 weight transfer; long-context CP fixes; 256-GPU GRPO launchers in the "mlite" backend; V4-Flash GRPO on AMD.
  - v0.9.1 (20 Sep): SGLang rollout weight sync, and bf16 fake-quant QAT for V4.
  - No V4.1 mention. — [verl releases](https://github.com/verl-project/verl/releases)
  - A preview PR targets "exact 0-diff true-on-policy RL" for V4 on Megatron and vLLM — [verl PR #7688](https://github.com/verl-project/verl/pull/7688).
- **Megatron-Bridge:** DeepSeek V4 merged on main (20 May 2026) and is listed in the 0.5.0 release (search summary) — [Megatron-Bridge](https://github.com/NVIDIA-NeMo/Megatron-Bridge).
- **KTransformers v0.7.2** (15 Oct):
  - Adds LoRA fine-tuning for the **April V4-Flash checkpoint**. "Routed experts remain in native MXFP4 on CPU, while attention and other non-expert modules run on GPU", and LoRA forward/backward runs on the frozen MXFP4 experts.
  - Integrates LLaMA-Factory SFT, with SGLang adapter inference.
  - The release gives no hardware or throughput figures and does not mention V4.1 or Engram. — [KTransformers v0.7.2](https://github.com/kvcache-ai/ktransformers/releases/tag/v0.7.2)
- **NeMo AutoModel** documents V4-Flash LLM fine-tuning, with the full 43-layer schedule needing multiple nodes (search summary) — [NeMo AutoModel V4-Flash](https://docs.nvidia.com/nemo/automodel/model-coverage/large-language-models/deepseek-ai/DeepSeek-V4-Flash)
- **slime:** I found no V4 or V4.1 support in its README (search summary) — [verl/slime search](https://github.com/NVIDIA-NeMo/Megatron-Bridge)
- **Open question on merges:** a Hugging Face discussion asks whether a merged V4-Flash fine-tune can keep the FP4+FP8 format or must be BF16 — [V4-Flash discussion #40](https://huggingface.co/deepseek-ai/DeepSeek-V4-Flash/discussions/40) (not opened).

### Inferences
- **Weight memory (my arithmetic):** the native checkpoint without Engram is about 476 − 183.1 ≈ 293 GiB. The target box has about 142 GB VRAM ≈ 132 GiB plus about 125 GiB RAM, about 257 GiB in all. So even the frozen weights in their shipped precision do not fit in VRAM + RAM combined, before activations, LoRA state or Engram. With no CPU-offload LoRA engine for V4.1, **local LoRA SFT or RL of V4.1-Flash is not feasible** with today's tools. The mining rigs are inference-only and far smaller.
- **Smallest validated setups:** the smallest validated V4.1 training is Miles LoRA RL on 16 × H200, plus a separate 16-GPU SGLang rollout engine or the same GPUs colocated. Full RL is validated on 16 × GB300. Plan on two 8-GPU H200/B200-class nodes as the practical minimum for V4.1 RL, and one node at most for small-batch LoRA SFT. This last point is my extrapolation; nobody reports single-node V4.1 LoRA.
- **What LoRA can adapt today:** the only verified V4.1 LoRA covers attention and the shared expert, not the routed experts. The Engram tables are frozen in Miles but trainable in mcore-bridge. For style and format adaptation (Elixir idioms, a harness's tool protocol), attention + shared-expert LoRA is the cheap path. Knowledge-heavy adaptation (a new language's library surface) may need routed-expert or Engram updates, which no released tool supports at scale.
- **Precedent path:** KTransformers' V4-Flash LoRA (MXFP4 experts on CPU) is the closest consumer-hardware route. Porting it to V4.1 would also need CSA2/CED and an Engram mmap. Nothing like that is announced.

### Gaps
- Merge status of the Transformers PRs #48721 and #48768, and whether they support backprop.
- Whether ms-swift's user docs and LLaMA-Factory expose V4.1 (only the bridge PR was found).
- DeepSpeed and torchtitan support for V4 or V4.1: nothing found.
- Measured memory per GPU and tokens per second for any V4.1 SFT run.
- Any LoRA on routed experts for V4 or V4.1.
- KTransformers' hardware requirements for V4-Flash LoRA (RAM, AMX/AVX-512).

## Q5. Third-party fine-tunes and RL runs of V4 / V4.1 (and V3.x precedent) for agentic coding

### Takeaway
I found **no published third-party agentic-coding fine-tune or RL run of V4 or V4.1 with measured benchmark gains**. The 65 "finetunes" of V4.1-Flash-1017 on Hugging Face are abliterations, "uncensored" variants and format conversions. The only measured third-party post-training results are framework validation runs (Miles on DAPO-Math, Miles LoRA RL reward curves), not coding-agent improvements.

### Cited Findings
- **Hugging Face finetunes:** the base-model filter shows 65 finetunes of V4.1-Flash-1017. All 30 on page 1 are abliterated, obliterated or uncensored variants, or MLX/GGUF/FP8/BF16/TP-split conversions; none is labelled code, SWE, agent or RL. — [HF finetunes of 1017](https://huggingface.co/models?other=base_model:finetune:deepseek-ai/DeepSeek-V4.1-Flash-1017)
- **Card counts:** the 1017 card lists 8 adapters, 65 finetunes, 3 merges and 175 quantizations; the original V4.1-Flash card lists 25 finetunes. — [1017 card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash-1017), [V4.1-Flash card](https://huggingface.co/deepseek-ai/DeepSeek-V4.1-Flash)
- **Miles framework validation:**
  - DAPO-Math-17K: reward 0.51 → 0.78 in 80 steps on 16 × GB300 — [LMSYS V4.1 blog](https://www.lmsys.org/blog/2026-09-10-deepseek-v41/)
  - LoRA RL: about +0.11 mean reward over 100 steps on 16 × H200 — [Miles PR #4205](https://github.com/radixark/miles/pull/4205)

  Neither is an agentic-coding benchmark.
- **rockycode:** a coding-agent harness for the V4 series that runs SWE-bench Verified and is described as groundwork for fine-tuning small models. It is a plan, not a released fine-tune (search summary). — [rockycode on PyPI](https://pypi.org/project/rockycode/0.1.2/)
- **Pruned variant:** a pruned V4-Flash variant exists (ubicloud "DeepSeek-V4-Flash-Pruned-35B"). I did not check its method or results. — [ubicloud](https://huggingface.co/ubicloud/DeepSeek-V4-Flash-Pruned-35B)
- **Hosted fine-tuning:** Fireworks offers LoRA fine-tuning for V4.1 Flash and 1017, but publishes no customer results — [Fireworks](https://fireworks.ai/models/deepseek-ai/deepseek-v4p1-flash-1017).

### Inferences
- **A gap to fill:** a measured agentic RL run on V4.1-Flash, even LoRA on attention and the shared expert, would be among the first public ones. The flip side is that there is no community recipe to copy and no evidence yet of how much LoRA moves DeepSWE-style scores at this scale.
- **Generic path:** with no V4/V4.1 precedent, the realistic route is to use V4.1-Flash as a **teacher** that generates verified trajectories (SFT or distillation into a smaller student), or to rent multi-node RL. That matches DeepSeek's own reliance on OPD from many teachers.

### Gaps
- **V3.x precedents:** from my background knowledge, third-party post-trains of the DeepSeek V3/R1 671B MoE exist, for example Microsoft MAI-DS-R1, Perplexity R1-1776 and Deep Cogito's v2 671B. My one search did not surface primary sources, so I have **not verified** their compute or results here, and none was an agentic-coding RL run as far as I know.
- Pages 2–3 of the HF finetune listing (35 repos) were not checked.
- Adapters (8) and merges (3) were not inspected.

## Q6. Serving at batch for data generation: engines, concurrency, throughput, quantized files, and what fits on the target hardware

### Takeaway
At datacenter scale, V4.1-Flash is an excellent batch agent server.
- **4 × H200 (vLLM):** the whole 1M context fits, with a 15.3M-token KV pool and 14.55× concurrency at 1M.
- **4 × B200 (SGLang):** a 20M-token KV pool and 169–510 tok/s per user on live agentic traffic.
- **8 × H200 (two SGLang copies):** 276–287 agent turns per minute at 64–96 simulated developers.

On consumer GPUs, every working engine is effectively single-stream or few-stream: dsx about 35–41 tok/s on 2 × 3090, one conversation; dsv41-flash-offload 19–27 tok/s aggregate at 1–4 streams on 1 × 3090 + 256 GiB RAM. llama.cpp support is still a PR branch. None of them has shown many concurrent agent sessions with expert offload.

### Cited Findings

**Datacenter engines**
- **vLLM (0.31.0+ required):**
  - Verified on H200, B200, B300, GB200, GB300 and MI300X/325X/350X/355X. No Ampere or H100 is listed.
  - Recommended: TP4 + Engram offload on H200; TP2 or DEP4/DEP8 on Blackwell.
  - Engram CPU offload is `--engram-config '{"cpu_offload":true}'` (pinned host memory read via UVA, "output is unchanged"). DSpark is `method: dspark`, 5 tokens.
  - DGX Station GB300 aggregate decode is 90.5 / 124 / 168 / 302 / 378 / 416–423 tok/s at 1 / 2 / 4 / 8 / 12 / 16 streams. MI355X TP8 at c = 1 reached p50 696.9 tok/s per user with TTFT p50 0.17 s. — [vLLM recipe](https://recipes.vllm.ai/deepseek-ai/DeepSeek-V4.1-Flash)
- **vLLM field report, 4 × H200 TP4** [measured, third party]: the full 1,048,576 context fits with 32.52 GiB of KV, holding 15,258,438 tokens, which gives 14.55× concurrency at 1M. Over 48 h it served 36,607 requests with 0 errors and a DSpark acceptance length of 3.43. — [vLLM #56400](https://github.com/vllm-project/vllm/issues/56400)
- **SGLang** (day-0 support, LMSYS, 10 Sep 2026):
  - Engram host table via `SGLANG_ENABLE_DSV41_ENGRAM_HOST_TABLE=1`. On 4 × GB300, host offload raised KV capacity by 36 % with "comparable decode throughput and TTFT".
  - Decoder tail-only SWA replay raised prefill throughput 1.56× on 8 × H200 and 1.37× on 4 × GB300. — [LMSYS V4.1 blog](https://www.lmsys.org/blog/2026-09-10-deepseek-v41/)
- **SGLang community production recipe, 4 × B200 TP4/EP4** [measured, third party], 1017 checkpoint, a 24-hour agentic coding measurement on 17–18 Oct 2026:
  - KV pool about 20.0M tokens at 1M context; 74.5 GiB of weights per GPU plus 2.1 GiB for DSpark; Engram in host RAM.
  - Per-user decode: 510 tok/s at 1 running request, 346 at 2–8, 169 at 9–16.
  - TTFT p50/p90/p99: 0.39 / 1.45 / 6.0 s; prefix-cache hit rate 96.7 %.
  - Traffic never exceeded 20 in flight. An InferenceX sweep on the same topology "collapsed at 128 concurrent requests".
  - Two patches were needed: a thinking/reasoning-parser fix and an encoding fix. — [caiovicentino 4×B200 recipe](https://github.com/caiovicentino/deepseek-v4.1-flash-sglang-4x-b200)
- **8 × H200 as two TP4 SGLang 0.5.21 copies (HelixML "Ramjet")** [measured, third party]:
  - Simulated agentic coding sessions. Prompts averaged 37–44K tokens and reached about 120K before compaction; prompt-cache hits were 90–94 %.
  - Agent turns per minute: 131–140 at 16 developers, 217 at 32, 276 at 64, 287 at 96, with no failures.
  - On a 262k copy, a single request runs at 354 tok/s and 16 concurrent requests at 189 tok/s each; a 1M copy gives 312 and 75 tok/s.
  - Two copies beat one 8-GPU engine by 23–59 %. DSpark roughly tripled single-request speed. DSpark's buffer does not fit at the full 1M context. — [HelixML Ramjet](https://helix.ml/blog/ramjet-deepseek-v41-flash-h200)
- **V4 for comparison (LMSYS):** single-batch decode of 266 tok/s for V4-Flash on H200 and 199 tok/s for V4-Pro on B200 at 4K context — [LMSYS V4 blog via search summary](https://www.lmsys.org/blog/2026-04-25-deepseek-v4/). NVIDIA publishes NVFP4 checkpoints of V4.1-Flash and 1017 (Blackwell) — [nvidia/…-1017-NVFP4](https://huggingface.co/nvidia/DeepSeek-V4.1-Flash-1017-NVFP4).

**Consumer and offload engines**
- **dsx** (Rust/CUDA, MIT):
  - **Model file:** for V4.1-Flash-1017 it uses a single 252 GB GGUF ("T16" trellis format) containing the experts, Q8_0 dense weights, an IQ4_NL Engram table and the tokenizer, plus an optional `vision.safetensors`. — [dsx README](https://github.com/lxe/dsx), [current-state](https://github.com/lxe/dsx/blob/main/docs/current-state.md)
  - **Reference rig:** 2 × RTX 3090, i7-12700K, 128 GB RAM, NVMe.
  - **Build requirements:** CUDA 13, AVX2 CPU ("AVX-VNNI or AVX-512 VNNI is preferred"), builds for sm_70, sm_86, sm_89 and sm_120. — [dsx README](https://github.com/lxe/dsx)
  - **Placement:** "dsx uses every visible GPU, up to six: one main GPU and up to five expert GPUs". The main GPU holds the dense weights, the KV cache and an adaptive expert cache. GPUs on slow links (under half the main GPU's bandwidth) hold fixed expert sets. The CPU computes its experts from a RAM arena (110 GB recorded). "experts that fit nowhere stay in the file". — [dsx placement](https://github.com/lxe/dsx/blob/main/docs/placement.md)
  - **Decode speed:** 34.9 tok/s (36.8 with defer = 3) on a 3K prompt; 36.7 → 41.0 tok/s with optional FP8 Engram projections (generated text differs); 31.63 tok/s at 128K context in a cold smoke check.
  - **Prefill speed:** 1,007.84 tok/s on an 8K prompt.
  - **V100 path:** 21–23 tok/s decode and 467 tok/s prefill on 2 × V100-32GB with 108 GB RAM. — [dsx current-state](https://github.com/lxe/dsx/blob/main/docs/current-state.md), [dsx README](https://github.com/lxe/dsx)
  - **Quality:** KL 0.196, top-1 80.9 %, perplexity 9.54 on the "Lucebox 8×1024" prefill eval. The page warns the result is "not an independent quality estimate", since the gains were tuned on the same eval. A Q6_K-Engram variant (about 302 GB) gives KL 0.194 and top-1 81.4 %. Decode-path KL is about 0.208 without deferral and 0.237 at defer rank 3. The page does not name its reference; project notes say FP8. — [dsx current-state](https://github.com/lxe/dsx/blob/main/docs/current-state.md)
  - **Concurrency:** default `--cache-sessions 1`. Multi-conversation caching is "implemented but not yet validated at runtime". No batching is described. It serves OpenAI- and Anthropic-compatible APIs. — [dsx current-state](https://github.com/lxe/dsx/blob/main/docs/current-state.md), [dsx README](https://github.com/lxe/dsx)
- **dsv41-flash-offload** (vLLM 0.13 + exllamav3):
  - **Model and hardware:** EXL3 3.0 bpw (219.3 GB) on **1 × RTX 3090**, with **256 GiB RAM minimum** (about 194 GiB of pinned experts), AVX2/FMA/F16C, 24+ cores, and about 458 GB of NVMe. The FP8 Engram tables (about 203 GB) are memory-mapped from NVMe.
  - **Decode:** 19.3 / 24.0 / 26.6 tok/s aggregate at 1 / 2 / 4 streams (`--max-num-seqs 4`).
  - **Prefill:** 690–790 tok/s from 8K to 261K.
  - **Soak test:** 30 minutes with 4 workers, 0 errors.
  - **Prefill fidelity:** top-1 0.9856 and mean KL 0.0068 against a full-vocabulary reference, which fails its own guard. Status: "candidate". — [dsv41-flash-offload](https://github.com/0xSero/dsv41-flash-offload)
- **llama.cpp:**
  - PR #28696 ("model : add DeepSeek V4.1") is closed and was narrowed to conversion, with the runtime on a fork. It is text only (no MTP or vision). Its missing two-level candidate mask caps context at about 16K. Q2_K is the lowest usable rung. DGX Spark Q2_K reached 2.3–2.8 tok/s. Only `-np 1` was shown, and no KLD was given. — [llama.cpp PR #28696](https://github.com/ggml-org/llama.cpp/pull/28696)
  - Unsloth uses its own PR #30817 (branch `deepseek41`) — [Unsloth docs](https://unsloth.ai/docs/models/deepseek-v4.1-flash).
  - Claims about mainline support conflict: one upload says it loads "from build b11870", while ISTA-DASLab says it was unsupported as of 23 Oct 2026 — [Abiray GGUF](https://huggingface.co/Abiray/DeepSeek-V4.1-Flash-1017-Uncensored-GSQ-RCO-IQ2_XXS-GGUF), [ISTA-DASLab via Interfaze](https://interfaze.ai/models/ista-daslabdeepseek-v41-flash-1017-gsq-rco-gguf), [cliecy GGUF](https://huggingface.co/cliecy/DeepSeek-V4.1-Flash-1017-UD-IQ2XS-GGUF).

**Unsloth GGUF sizes and quality**

KL / top-1 are against the official reference, on wiki1100 and long17k. The "rest" column is the part that must sit in RAM or VRAM; the Engram can stay on SSD through mmap.

| Quant | Engram | Rest | Total | KL / top-1 (wiki1100) | KL / top-1 (long17k) |
|---|---|---|---|---|---|
| UD-IQ1_S | IQ4_NL 110.6 GB | 122.4 GB | 233.0 GB | 0.457 / 82.8 % | 0.364 / 85.1 % |
| UD-IQ1_M | 110.6 GB | 139.8 GB | 250.4 GB | 0.314 / 87.1 % | — |
| UD-IQ2_XXS | Q5_K 135.2 GB | 165.3 GB | 300.5 GB | 0.203 / 90.5 % | — |
| UD-Q2_K_XL | 135.2 GB | 199.6 GB | 334.8 GB | 0.138 / 91.5 % | 0.0879 / 93.3 % |
| UD-IQ3_XXS | Q6_K 161.3 GB | 233.5 GB | 394.7 GB | 0.0625 / 94.6 % | — |
| UD-Q3_K_XL | MXFP8 202.8 GB | 282.3 GB | 485.1 GB | 0.0204 / 96.5 % | — |
| UD-Q4_K_XL | 202.8 GB | 297.9 GB | 500.7 GB | 0.0090 / 98.2 % | — |
| UD-Q8_K_XL | 202.8 GB | 305.6 GB | 508.4 GB | 0.00476 / 98.5 % | — |

- RAM/VRAM needs with Engram on SSD: 128–145 GB at 1-bit, 176–205 GB at 2-bit, 256–290 GB at 3-bit.
- Six-test benchmark average: UD-Q8_K_XL 87.68, UD-Q2_K_XL 87.49, UD-IQ1_S 83.53.
- The Engram quant can be swapped (MXFP8 / Q6_K / Q5_K / IQ4_NL). Unsloth gives no tok/s hardware figures.

[Unsloth docs](https://unsloth.ai/docs/models/deepseek-v4.1-flash), [Unsloth GGUF repo](https://huggingface.co/unsloth/DeepSeek-V4.1-Flash-1017-GGUF)

- **Other quants:** a community Q4_K_M is listed at 414 GiB — [mrfakename GGUF](https://huggingface.co/mrfakename/DeepSeek-V4.1-Flash-1017-GGUF).
- **KTransformers and ik_llama.cpp:** no V4.1 support found (KTransformers v0.7.2 covers V4-Flash only) — [KTransformers v0.7.2](https://github.com/kvcache-ai/ktransformers/releases/tag/v0.7.2)

### Inferences

**dsx on the target 7-GPU box (my arithmetic and inference)**
- dsx would use 6 of the 7 cards. The 3090 and 3080 are both sm_86, which dsx builds for.
- Six cards give about 5 × 24 + 12 = 132 GB of VRAM. With about 110–115 GB of RAM arena on a 125 GiB host, about 240+ GB of the 252 GB T16 file is resident, so most experts sit on GPUs and only a few stay "in the file".
- The PCIe x1 cards will be classed as slow-link and given fixed expert sets.
- The Zen 3 CPU has AVX2 but no AVX-VNNI or AVX-512 VNNI, so dsx's CPU expert kernel runs on its slower path. With most experts on GPUs, the CPU share should be small.
- Expect single-stream speed at least in dsx's 2 × 3090 range of 30–40 tok/s, but **one conversation at a time**. Multi-session caching is unvalidated.

**llama.cpp on the same box (my arithmetic)**
- UD-Q2_K_XL needs 199.6 GB for its non-Engram weights. That fits in 142 GB VRAM + about 58 GB of RAM, leaving about 75 GB of RAM as page cache for a 135.2 GB Q5_K Engram mmap'd from NVMe.
- Quality: KL 0.138 and top-1 91.5 % (wiki1100), far better than IQ1_S. But the runtime is an unmerged PR branch, the #28696 version capped context at about 16K, and parallel slots are untested.
- UD-IQ1_S (122.4 GB) would fit entirely in VRAM, but at KL 0.457 it is poor as a teacher.
- dsx's T16 (KL 0.196, top-1 80.9 %) and Unsloth's UD-IQ2_XXS (KL 0.203, top-1 90.5 %) were measured on **different evals and references**, so the top-1 figures are not comparable. Nothing here says which local file is the better teacher; running both on the same eval would settle it.

**Mining rigs (9 × P106-090 6 GB, about 54 GB VRAM, 4 GB host RAM, PCIe 1.0 x1, sm_61)**
- Even the smallest file's non-Engram weights (122.4 GB) are more than twice the rig's VRAM, and 4 GB of host RAM cannot back an expert arena or Engram page cache.
- No V4.1 engine targets sm_61: dsx builds for sm_70/86/89/120, and vLLM/SGLang need Hopper or newer.
- **V4.1-Flash does not fit on the rigs** in any form found.

**Data-generation economics (illustrative, my arithmetic)**
- One 8 × H200 node at about 276 turns/min (64 sessions) gives about 16,600 agent turns per hour.
- A local single-stream engine at about 35 tok/s needs about 43 s of decode alone for a 1,500-token turn, about 84 turns per hour, before prefill and tool time.
- So local serving suits **teacher spot-checks, small Elixir task sets and quality comparisons**. Bulk trajectory generation for SFT or RL needs a rented 4–8 GPU H200/B200 node running vLLM or SGLang, or the DeepSeek API, whose terms allow training on outputs (see Q2).
- Agentic prompts at 90–97 % prefix-cache hit rates (reported) make prefix caching essential; every serious deployment above relies on it.

### Gaps
- No measured multi-session throughput on consumer GPUs with expert offload beyond dsv41-flash-offload's 4 streams. dsx multi-session is unvalidated, and llama.cpp `-np > 1` was not reported for V4.1.
- Merge status of Unsloth's llama.cpp PR #30817, and whether its version still has the about-16K context cap.
- No ik_llama.cpp or KTransformers V4.1 serving evidence.
- No published H100 (80 GB) or 8 × B200 single-copy V4.1 throughput sweep. The vLLM recipe does not list H100.
- Whether the dsx KL / top-1 reference is the FP8 checkpoint. It is stated in project notes but not on the page.
