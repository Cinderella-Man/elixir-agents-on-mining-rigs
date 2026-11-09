# Experiments, their extensions and new ideas: a survey (2026-11-09)

A desk survey of every planned experiment in this project, what the literature and the published bench runs add to
each, and the new ideas that came out of it. Nothing ran on a GPU. Each idea has a registry row
([experiments.md](../../../experiments.md), E13–E45), and the order to study them in is in
[study_order_2026-11.md](study_order_2026-11.md).

Conventions:
- A number from a paper is the authors' own unless marked. "(abstract)" means only the abstract or listing was read;
  the other papers were read through a summarising fetch, so check a number in the source before building on it.
- Sizes and times marked est. are my arithmetic from the sister repo's measured tables.
- Speed levers that leave the model unchanged belong to the sister repo and are only pointed at here (section 5).

## Summary

1. **The published runs already show where Flash-Next loses: the generation budget.** 7 of the Flash-Next Coder's 10
   failures and 5 of Gyro-L's 9 ended at the 65,536-token budget. On the 7 cases that DeepSeek and both Flash-Next
   files passed, DeepSeek generated 111,533 tokens, Gyro-L 162,887 and the Coder 207,513
   ([data](../../data/2026-11-09_bench_runs_read/README.md), E14). Tokens per solved case is therefore a measure of
   its own: it decides bench passes and time per task on the rig.
2. **Track A has a ceiling, and nobody has measured it.** A cut without training is not expected to beat the uncut
   model at high precision. If that model scores no more than the 2-bit bar, a cut alone should not be expected to
   beat the bar. Measure it with the bar (E13).
3. **Twenty cases and three seeds resolve only large gains:** est. 2.5–3.0 cases between two three-seed series
   (section 1.3). Small gains need a larger lane (E18) and a decision rule fixed in advance (E17).
4. **The Elixir cut needs no new quantizer.** Slicing the published 3-bit files reaches Swift Q2_0's size: IQ3_XXS at
   384 experts is est. 34,800 MiB and IQ3_S at 320 est. 34,400 MiB, against 35,730 MiB (E21).
5. **Repair after a cut has a published recipe that needs no teacher:** self-distillation with the routed experts
   frozen (E26). Running it at home needs a trainer that reads the file's quantized experts (E27); the stock route
   needs 8 GPUs of 70 GB or more (E28).
6. **Mined tasks have a head start.** SWE-rebench V2, a public dataset under CC BY 4.0, lists Elixir among its 20
   languages, and its builder ships an Elixir base image (E36). Fourteen framework and
   library repositories outside the bench hold 21,260 merged pull requests (E37).
7. **The bench plans to grow to 100–200 cases from more projects.** A project mined for training today cannot join
   the bench later, so the reserved list comes before any mining (E19).
8. **The student has no 2-bit problem but a long way to go.** A 35B model with 3B active fits nine cards at 8 bits.
   The published runs of larger relatives passed 6 and 7 cases against Flash-Next's 10 and 11.
9. **The cheapest candidate is text, not weights:** a short block of Elixir working rules inside the file's chat
   template (E39).
10. **Two new student candidates exist:** North Mini Code and HERO-35B-A3B (E38).

## 1. Measurement

### 1.1 What the published runs show (E14, done)

The table and its files are in [docs/data/2026-11-09_bench_runs_read](../../data/2026-11-09_bench_runs_read/README.md).
Three readings matter for the plan:

- **Compression shows up as tokens.** DeepSeek's 1-bit file failed 4 cases, 1 at the budget. Its pruned 2-bit Coder
  failed 8, 6 at the budget, with 37,518 tokens per passed case against 28,736. This agrees with
  [arXiv 2607.16721](https://arxiv.org/abs/2607.16721): one repair turn erased the 2-bit model's single-shot penalty
  (0.860 pooled against 0.858 for Q8). A damaged model still gets there, with more turns, and the budget then cuts it
  off.
- **So a better file at equal bytes should be seen first in tokens per solved case and in budget hits,** before it
  is seen in cases passed.
- **The harness comparison is confounded twice.** The hosted series ran in another harness and with a declared,
  unenforced budget of 262,144 tokens.

### 1.2 The ceiling (E13)

The bar (E1) is the rig's 2-bit file. Track A's files approach the uncut model at high precision, so that model's
score is the expected ceiling of every cut that is not trained. It is an expectation, not a law: published prunes
have landed above their base on single benchmarks (REAP: Kimi-K2 on SWE-bench Verified 0.554 → 0.580 at a quarter of
the experts removed, [survey](expert_pruning_survey.md)). The published points here are single runs of other
makers' builds: Gyro-L at about 3 bits passed 11 and the 256-expert Coder passed 10.

- **What to run:** Swift's GSQ-RCO IQ3_S (agent KLD 0.121 against the Q8_0 reference in the sister repo's Q217; Q2_0
  is 0.285), three seeds, in E1's harness and settings. Swift's Q8_0 only if IQ3_S and the bar differ.
- **What it decides:** if the ceiling is not clearly above the bar, cuts alone are unlikely to win on this bench, and
  a win has to come from training (E26, E29, E10) or from the context arm (E39). E4 would then be judged on tokens per
  solved case and on the dev lane.
- **It also calibrates KLD.** It gives the first pair of (agent KLD, cases passed) for one model: 0.285 against 0.121.

### 1.3 Noise, the decision rule and a dev lane (E17, E18)

**How much rerun noise to expect (est.).** A run's score varies by Σ pᵢ(1 − pᵢ) over the cases, pᵢ being each
case's pass rate. Two single runs of related files disagree on 5 cases (the two Ornith-1.5-122B files) and on 7
(the two Flash-Next files). If all of that were rerun noise, Σ pᵢ(1 − pᵢ) would be 2.5 to 3.5, and:

| Comparison | Smallest difference in mean cases passed that two-sided 95 % separates (est.) |
|---|---|
| 3 seeds against 3 seeds | 2.5 to 3.0 cases |
| 3 seeds against a 6-seed bar | 2.2 to 2.6 cases |
| 6 seeds against 6 seeds | 1.8 to 2.1 cases |

These are upper estimates, since part of the disagreement is the files' real difference. Hosted Opus 5.5 is far
steadier: its three runs differ on one case.

**What follows:**
- Fix the rule for "beats the bar" before any candidate runs (E17). A proposal: a higher mean over three seeds, and
  a one-sided paired test over the 60 case-seed pairs at p < 0.1. The bar gets six seeds, because every comparison
  reuses it.
- Add a dev lane of 60–80 mined tasks from repositories that no training task comes from (the registry's Q473,
  made a gate by E18). Every candidate is scored there first; the bench runs only for candidates that pass. This
  also limits how often the 20 cases are looked at: after ten candidates, the best of them looks better by chance.
  [Miller 2024](https://arxiv.org/abs/2411.00640) gives the standard errors for paired and clustered questions.
- The bench's own growth to 100 cases would more than halve the noise in the pass rate (est., 1/√n).

### 1.4 Three cheap diagnostics (E15, E16, E20)

- **E15, twice the budget on the attempts that hit it.** One seed of the bar file, only the capped attempts, at
  131,072 tokens. Passes there were slow but on track; failures were lost. It is a diagnostic, never a series.
- **E16, the effort setting.** The published Flash-Next runs used xhigh. Less thinking saves budget, but the
  GSQ-RCO maintainer reports that medium effort "has degraded significantly" on these quants
  ([discussion](https://huggingface.co/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF/discussions/18)). One arm at
  "high", three seeds; the better setting becomes the bar's.
- **E20, a failure census of the saved transcripts.** Each failed attempt gets one class: budget hit, tests still
  failing, a file edited outside the allowed paths, no patch, a loop (the sister repo's Q1138 rules), a malformed
  tool call. It also counts how often an attempt reads a dependency's source under `deps/` or asks `mix help` before
  using a library, in passes against failures. CPU only, on saved evidence.

### 1.5 Reserve projects before mining (E19)

The bench's plan is "roughly 100–200 cases in total" with "additional Elixir projects"
([expansion plan](https://github.com/Cinderella-Man/elixir-swe-bench/blob/main/docs/benchmark-expansion-plan.md)).
The hold-out rule names today's 12 projects only. Three additions close the gap:
- a list of projects reserved for the bench's growth, fixed before E8 mines anything;
- sibling repositories of the 12: the same organisation's extension packages (Ash's and Absinthe's ecosystems,
  Livebook's Kino) can carry the twin of a bench pull request;
- forks and vendored copies of the 12, matched by file hashes, not by name.

## 2. Track A: shrinking Qwen3.8-Flash-Next

### 2.1 What the cut can and cannot buy

From the sister repo's measurements of Swift's files
([variants note](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/research/notes/flash_next_variants.md),
[first run](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/models/qwen3.8-flash-next/README.md)):
- A token reads 3.5 GB of dense tensors and 0.66 GB of routed experts in Swift Q2_0. The 2026-11-03 profile put
  routed experts at about 26 of 136 ms per token.
- So cutting experts frees bytes and changes speed very little. The freed bytes can be spent three ways:
  1. **more bits for the kept experts** (E4's plan): better answers, and slower expert reads unless the format has a
     Pascal kernel as fast as Q2_0's;
  2. **fewer cards:** a smaller file can sit on fewer cards, and each card boundary costs a host round trip (the
     sister repo's Q964);
  3. **room** for context or a drafter.
- Only dropping layers (E6) or trimming the output layer (E7) removes dense reads.

### 2.2 The arms of E4, by slicing published files (E21)

The sister repo's Q891 cut Swift IQ3_S by slicing its tensors, with no re-quantization, and measured 43,028 MiB at
416 experts. The same arithmetic gives the arms that fit under Swift Q2_0's 35,730 MiB:

| Arm | On the cards (est.) | What is known |
|---|---:|---|
| Swift IQ3_XXS cut to 384 experts | 34,800 MiB | uncut: agent KLD 0.176 |
| Swift IQ3_S cut to 320 experts | 34,400 MiB | uncut 0.118; at 416 experts 0.131; a cut to 320 drops 4.5 % of general agent routings, 12.6 % in the worst layer (Q232) |
| Swift IQ3_S cut to 256 experts | 28,400 MiB | drops 9.2 % of routings, 22.3 % in the worst layer |
| `pmix-q2-fast` cut to 384 experts | 27,600 MiB | spends the bytes on fewer cards, not on bits |

Swift Q2_0 itself scores 0.285 on agent text. Two cautions:
- **The format decides the speed.** The sister repo measured IQ3_XXS at 20.5 ps a weight on a P106 and estimates
  Q2_0 at 3–6. A 3-bit arm needs a Pascal-fast expert format (`pmix-iq3-fast`, or the N2P/N3P-128 formats of Q928)
  before it goes to a rig.
- **Agent-ranked cuts lose general knowledge:** wiki KLD went from 0.153 to 0.724 at 416 experts. For this project
  that is accepted, but the model still has to read English tickets, so the KLD set keeps a general text.

### 2.3 Choosing the experts (E22, E23, E24)

E3 ranks by routing counts and REAP saliency. Three findings since then say to compare rankings, not assume one:
- **The best ranking differs by model family.** In [2607.16721](https://arxiv.org/abs/2607.16721), REAP was best on
  Qwen3.6-35B-A3B (HumanEval+ 0.896 at half the experts, base 0.890) but lost 16.5 points on Gemma-4-26B-A4B, where
  plain routing mass kept 0.890 of 0.927. Random selection collapsed on both.
- **RAZOR** ([2609.30465](https://arxiv.org/abs/2609.30465), abstract) scores an expert by the output change its
  deletion causes once the survivors are renormalized and the router refills its slot. It beat REAP by 2.12 to 5.59
  points in four settings and needs forward passes only.
- **STEP** ([ICML 2026](https://icml.cc/virtual/2026/poster/66320), abstract) weights tokens by their loss instead
  of treating all tokens alike. The sister repo's Q936 makes the same point from the other side: 89.6 % of its agent
  text is tool results, so counts mostly reflect reading, not writing.

E22 runs two or three rankings on E2's text and compares the kept sets and their KLD at equal size.

**The calibration mix matters as much as the method (E23).** One practitioner's Qwen3.6-35B-A3B prune
([write-up](https://fengwang.github.io/posts/qwen-pruning-rtx5090/)) found pure-code calibration left two MMLU
categories at 0.0 % and a 70/30 code-to-general mix restored them to 33.3 % and 34.3 % while tool calling rose from
44.0 % to 51.0 %. Replacing code with agent sessions cost tool-call parameter precision (ToolCall-15 97 to 90). So
E3's Elixir ranking gets a second arm with a general share, and the tool-call spans are kept (Q897).

**Per-layer budgets (E24).** E4 keeps the same number in every layer, but Q232's worst layer loses 22.3 % of its
routings at 256 where the mean is 9.2 %. Keeping more experts where routing is flat and fewer where it is peaked
gives the same bytes for less lost routing. RAZOR selects under a layerwise budget, and
[Martin et al.](https://arxiv.org/abs/2605.28042) (abstract) use per-layer capacity for translation specialists.
First check: whether the engine reads a different expert count per layer.

### 2.4 Channels inside experts (E25)

[FlexMoE](https://arxiv.org/abs/2606.27866) (abstract) prunes hidden channels inside each expert instead of whole
experts: about 99.8 % of base performance at half the routed-expert parameters on Qwen2-57B-A14B, without
fine-tuning. For Flash-Next that means fewer than 640 channels per expert: every routing target stays, and the
bytes read per token for experts fall too. The gate and up rows slice cleanly. The down projection's columns do not,
so it needs re-quantizing. After E4.

### 2.5 Merging, layers, vocabulary (E5, E6, E7)

- **E5, merging.** REAP's paper found plain merging (HC-SMoE, M-SMoE) loses over 5 % on coding at a quarter of the
  experts merged. REAM, which merges into REAP-chosen centroids, slightly beat REAP at that level
  ([survey](expert_pruning_survey.md)). E5 should start from REAM's form, not from clustering alone.
- **E6, dropping layers.** Each of the 48 layers is est. 2 % of a token's time, so this is Track A's one speed
  lever. Published layer drops lose quality fast without repair, and the repair one study recommends is tuning
  the output layer and the last three layers in full ([Lu et al.](https://arxiv.org/abs/2411.15558)), which needs
  full-precision training of Flash-Next (parked as E33). Without repair, expect one or two layers at most.
- **E7, vocabulary.** Unchanged. It needs the exact fallback, since Elixir sessions still contain arbitrary text.

### 2.6 Repair after the cut (E26, E27, E28, E29)

E11 planned a LoRA on the teacher's sessions and so waited for all of Track B. The recipe in
[2607.16721](https://arxiv.org/abs/2607.16721) needs none of it:
- the targets are the uncut model's own answers on the calibration chats (1,863 of them);
- LoRA of rank 64 on the attention, linear-attention and shared-expert projections, and the router trained in full:
  95.2M parameters, 0.86 % of the model;
- the routed experts stay frozen and byte-identical;
- under three hours; at a quarter of the experts kept, HumanEval+ went from 0.787 to 0.841 (52 % of the gap to
  the base), and general perplexity from 30.9 to 9.4.

This fits a cut GGUF well: the sliced 3-bit experts are reused as they are, and only the dense tensors and the
router are written again, at the higher precision they already have. The paper also warns that two of its recovery
runs silently evaluated the unrepaired model; it now requires a byte-level tensor diff before trusting a number.

**The obstacle is where to train.**
- **The stock route does not fit at home.** ModelScope's guide for Flash-Next
  ([page](https://swift.readthedocs.io/en/latest/BestPractices/Qwen3_8-Flash-Next-Best-Practice.html)) trains a LoRA
  on 8 GPUs and measures 75.6 GiB per GPU at 2,048 tokens and 93.3 GiB at 8,192. The 7-GPU machine has five cards of
  24 GB.
- **Training against different experts than the served ones can make things worse.** The practitioner above trained
  with 4-bit experts and served FP8: training loss fell, and HumanEval+ went from 73.2 % to 67.7 % and MMLU from
  33.6 % to 9.4 %. The trainable layers had adapted to the 4-bit noise.
- **E27, a trainer that reads the file's own experts.** A PyTorch forward of Flash-Next whose routed experts are the
  GGUF's quantized blocks, dequantized one layer at a time, with the dense tensors in BF16. All 512 experts are 34 GB
  as Q2_0 codes and less when cut, so it fits five 24 GB cards, and the model trains against exactly the experts it
  is served with. It has to match the engine's logits on the same text before any training.
- **E28, a rented 8-GPU node** for one repair run on a BF16 cut checkpoint. It is simple, but it trains against
  BF16 experts and serves 3-bit ones, the reverse of the mismatch above, and that has not been measured.

**E29, Flash-Next's own shortest verified solves.** After the repair, the same trainer can fit the model to its own
passing sessions on mined tasks, the shortest per task. It needs no template conversion and no other writer, and it
aims at the measured weakness, tokens per solved case. One round of this gave a weak 72B agent +9.1 points and a
32B agent 19.0 to 19.7 ([report](../finetuning/reports/Agentic%20RL%20for%20a%20DeepSeek%20teacher.md)), so the
expected gain is small and is measured in tokens first.

### 2.7 Free evidence and one dependency (E30, E31)

- **E30, published derivatives.** Makers have already post-trained a 256-expert Flash-Next (Groot-65B-A6B) and
  fine-tuned the model for agentic work (Tinfield-1, with a rig-sized build), and several REAP, REAM and RAZOR prunes
  exist ([variants note](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/research/notes/flash_next_variants.md)).
  None has an agentic score. One bench seed each tells whether post-training after a cut, or agentic tuning of this
  model, moves Elixir at all. They are yardsticks: their training data is not checked.
- **E31, draft acceptance.** The rig's 20.40 tok/s line uses drafts trained against the uncut model. A cut or tuned
  model may accept fewer drafted tokens. The acceptance rate of the existing drafts on the best cut file is a ratio,
  measurable off the rig, and it should be known before the file goes to a rig.

### 2.8 Parked

| Row | Idea | Why parked | Reopens when |
|---|---|---|---|
| E32 | Tune one routing bias per expert with forward passes only (SPSA on KLD) | no published evidence; E26 trains the router with gradients | neither E27 nor E28 is available |
| E33 | Repair layer drops by tuning the output layer and the last layers in full | needs full-precision training of Flash-Next | E6 finds a drop within KLD noise and E28 is approved |
| E34 | Train routed experts for Elixir | changes 2-bit tensors, so it needs a learned-rounding quantizer run again and full-precision training | E28 is approved and a GSQ-RCO reproduction at 2–3 bits exists |
| E35 | Re-quantize the uncut model with Elixir calibration | the public reproduction of the method stops at 3.5 bits; slicing reaches the same bytes | E13 puts IQ3_S far above Q2_0 on the bench and E4's slices lose it |

## 3. Track B: teaching a small model

### 3.1 Tasks (E36, E37)

**SWE-rebench V2** ([paper](https://arxiv.org/abs/2602.23866),
[issue-linked set](https://huggingface.co/datasets/nebius/SWE-rebench-V2),
[PR set](https://huggingface.co/datasets/nebius/SWE-rebench-V2-PRs),
[builder](https://github.com/SWE-rebench/SWE-rebench-V2)):
- 32,079 issue-linked tasks with pre-built Docker images and 126,300 tasks derived from pull requests, in 20
  languages, Elixir among them. Both sets are CC BY 4.0, and each row records its repository's licence.
- A row holds the repository, base commit, fix patch, test patch, the tests that fail before and pass after, and an
  install configuration.
- The builder is MIT and has an Elixir base Dockerfile (`elixir:1.16`); the paper lists its ExUnit log parser.
- **Not known yet:** how many rows are Elixir and from which repositories. The dataset server returned a temporary
  error on 2026-11-09, so counting them is the first step.
- **Before use:** E12 and E19 screen the rows (the card warns that other benchmarks were not filtered out). The
  PR-derived task statements are written by an LLM, so statements are rewritten by an approved writer. The tuples of
  commit, patch and tests come from the repositories themselves.

**The pool for our own mining (E37).** Merged pull requests on 2026-11-09 (GitHub search, `is:pr is:merged`):

| Repository | Licence on GitHub | Merged pull requests |
|---|---|---:|
| elixir-lang/elixir | Apache-2.0 | 8,242 |
| phoenixframework/phoenix | MIT | 3,122 |
| elixir-ecto/ecto | Apache-2.0 | 2,133 |
| phoenixframework/phoenix_live_view | MIT | 2,007 |
| exercism/elixir | MIT | 1,172 |
| elixir-lang/ex_doc | not detected | 1,077 |
| elixir-plug/plug | not detected | 697 |
| oban-bg/oban | Apache-2.0 | 591 |
| elixir-tesla/tesla | MIT | 542 |
| rrrene/credo | MIT | 484 |
| elixir-ecto/ecto_sql | Apache-2.0 | 439 |
| elixir-mint/mint | Apache-2.0 | 333 |
| wojtekmach/req | Apache-2.0 | 213 |
| elixir-broadway/broadway | Apache-2.0 | 208 |

That is 21,260 merged pull requests in 14 repositories outside the bench's 12. GitHub lists 435 Elixir repositories
with 200 or more stars pushed since 2025. The share that yields a valid task is unknown. "Not detected" means the
licence file needs the per-file scan, as planned.

**Mine applications as well as libraries.** The bench's cases are application work: Phoenix, LiveView and Ecto
with a database. The registry's Q479 mines Hex packages, which are libraries. Permissively licensed applications
exist: firezone, logflare, supabase/realtime and asciinema-server are Apache-2.0 on GitHub, and sequin is MIT. AGPL
applications stay out. Results are reported by stratum: application, framework, library.

### 3.2 The teacher

The bench has already answered the first question of the registry's Q524: DeepSeek-V4.1-Flash-1017 passed 16 of 20
at 1 bit, with the fewest tokens per passed case of any Pi series (28,736). What remains unmeasured is its pass rate
and cost on mined tasks, which sets the size of the dataset. Its solves are also the shortest of any Pi series, which
is what the student should imitate.

### 3.3 The student (E38, E43, E44)

- **The distance.** The 35B candidates have no bench score. Their larger relatives passed 6 and 7 (Ornith-1.5-122B)
  and 6 (Flint), against 10 and 11 for Flash-Next. Published gains from tuning on agent sessions are +5 to +13
  points on hard benchmarks ([report](../finetuning/reports/Fine%20tuning%20small%20models%20for%20Elixir.md)),
  which is one to three cases here. Beating the bar with a student is therefore the long shot of the two tracks, and
  the only one that changes speed.
- **Two more candidates (E38):**
  - **North Mini Code** (Cohere, 2026-06-09): 30B with 3B active, 128 experts with 8 active, Apache-2.0;
    SWE-bench Verified 61.0 % pass@1 in mini-SWE-agent, trained with SFT then RL on unit-test rewards
    ([post](https://huggingface.co/blog/CohereLabs/introducing-north-mini-code)). Its engine support on Pascal is
    not checked.
  - **HERO-35B-A3B** ([code](https://github.com/XLearning-SCU/HERO), Apache-2.0): Qwen3.5-35B-A3B trained by RL to
    solve with fewer tokens, resolution first and efficiency second. That targets the budget failures directly.
  - Both need their training data's provenance read before they can be a base, and a download.
- **No 2-bit problem (E43).** A 35B-A3B model is est. 37 GB at Q8_0, so it fits nine cards with room, and a LoRA's
  small changes are not rounded away. Gains from fine-tuning before quantization shrink sharply at 2 bits
  ([arXiv 2307.08072](https://arxiv.org/abs/2307.08072), from a search summary), which is Track A's risk, not this
  one's. The student's rig file is chosen on time per solved task among Q4, Q5 and Q8 builds.
- **Measure the speed premise early (E44).** The README says such a model "runs several times faster on the rig".
  The measured single-request numbers for Qwen3.6-35B-A3B Q4_0 are 29.0 and 31.1 tok/s on the v1 engine, and
  Flash-Next's agentic number is 20.40. An agent check of an untuned 35B-A3B file needs only a rig and settles the
  ratio before any training.

### 3.4 Context before weights (E39, E40)

- **E39, rules inside the chat template.** The registry's Q475 planned a docs context arm, but the bench's harness
  is fixed. The file's chat template is part of the model artifact and of a series' identity, so a short block of
  working rules can live there: library sources and docs are under `deps/`, read them before using an API; compile
  before testing; do not edit outside the task's paths. Evidence points both ways: a docs index lifted one eval from
  53 % to 100 % ([report](../finetuning/reports/Fine%20tuning%20small%20models%20for%20Elixir.md)), and context files
  lowered success and raised cost by over 20 % in another study
  ([report](../finetuning/reports/Agentic%20RL%20for%20a%20DeepSeek%20teacher.md)). Three seeds against the same
  file without the block. The text comes from the owner or an approved writer.
- **E40, bake the rules in.** If E39 gains, [Prompt Baking](https://arxiv.org/abs/2409.13697) turns the prompt into
  weights: the model with the rules in context teaches the same model without them, by KL on its token
  distributions. It needs no verified sessions and has no tokenizer gap.

### 3.5 Efficiency and small arms (E41, E42)

- **E41, efficiency as a training target.** Keep the shortest verified solve per task (already in Q528) and order
  training by turn count (Q540). For the RL stage, HERO's lesson is to switch the efficiency term on only after
  resolution is learned, and [CodeGrep](https://arxiv.org/abs/2608.05886) reports the term works better on the
  advantage than on the reward.
- **E42, diagnostic-to-fix pairs.** The AST transforms of Q478 produce compiler and test output with a known fix.
  Short sessions of (output, edit) are a cheap first stage that is shaped like the loop.

### 3.6 Parked

| Row | Idea | Why parked | Reopens when |
|---|---|---|---|
| E45 | An Elixir steering vector added at decode time | no evidence that a direction carries library knowledge | the sister repo's loop-steering vector (Q1139) changes agent outcomes |

## 4. Where a win can come from

A judgement, to be replaced by E1 and E13:
- **Most likely to beat the bar at rig size:** a cut 3-bit Flash-Next (E4, E21) with a self-distilled repair (E26),
  if the ceiling (E13) is above the bar. It does not get faster per token; it can get faster per task.
- **Cheapest possible win:** the rules block (E39).
- **Largest prize, lowest odds:** a tuned 3B-active student (E10), the only route to a model that is faster per
  token.
- **What compounds whichever wins:** the task factory (E8, E36, E37 with E12 and E19) and the dev lane (E18).

## 5. Noticed, but the sister repo's

These change how a model runs, not what it is: routing fewer experts on confident tokens (Q618), a concise-reasoning
steering vector (Q267), the loop census and its fix (Q1138–Q1140), a cold tier for rarely used experts (Q238), fewer
card boundaries for a smaller file (Q964). The first three lower tokens or time per task, so their results bear on
E14's measure.

## Sources

- Jha, Half the Experts, All the Code (2026): https://arxiv.org/abs/2607.16721 (code: https://github.com/anik-jha/moep)
- Feng Wang, Pruning Qwen3.6-35B-A3B for RTX 5090: https://fengwang.github.io/posts/qwen-pruning-rtx5090/
- RAZOR: Pruning Replaceable Experts in LLMs: https://arxiv.org/abs/2609.30465
- STEP, Less Token, More Signal (ICML 2026): https://icml.cc/virtual/2026/poster/66320
- FlexMoE: https://arxiv.org/abs/2606.27866
- Martin et al., Extracting Small Translation Specialists from LLMs: https://arxiv.org/abs/2605.28042
- Lu et al., Reassessing Layer Pruning in LLMs: https://arxiv.org/abs/2411.15558
- ModelScope, Qwen3.8-Flash-Next best practice: https://swift.readthedocs.io/en/latest/BestPractices/Qwen3_8-Flash-Next-Best-Practice.html
- SWE-rebench V2: https://arxiv.org/abs/2602.23866, https://huggingface.co/datasets/nebius/SWE-rebench-V2,
  https://huggingface.co/datasets/nebius/SWE-rebench-V2-PRs, https://github.com/SWE-rebench/SWE-rebench-V2
- Cohere, Introducing North Mini Code: https://huggingface.co/blog/CohereLabs/introducing-north-mini-code
- HERO, Doing More with Less Tokens: https://github.com/XLearning-SCU/HERO
- CodeGrep: https://arxiv.org/abs/2608.05886
- Bhargava et al., Prompt Baking: https://arxiv.org/abs/2409.13697
- Liu et al., Do Emergent Abilities Exist in Quantized Large Language Models: https://arxiv.org/abs/2307.08072
- Miller, Adding Error Bars to Evals: https://arxiv.org/abs/2411.00640
- Elixir SWE Bench results and expansion plan: https://cinderella-man.github.io/elixir-swe-bench/,
  https://github.com/Cinderella-Man/elixir-swe-bench/blob/main/docs/benchmark-expansion-plan.md
- Sister repo: [expert usage (Q232)](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/data/2026-11-04_expert_usage/README.md),
  [usage cuts (Q891)](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/data/2026-11-04_gguf_prune/README.md),
  [Flash-Next file quality (Q217)](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/data/2026-11-03_flash_next_quality/README.md)
