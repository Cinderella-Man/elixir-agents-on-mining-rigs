# Closed-form weight edits and the Kinetic engine (2026-11-11)

Two posts found on X, read with one question: can either help an Elixir model that has to fit a P106 rig?

What I read:
- the Kaggle notebook [engine-transfer](https://www.kaggle.com/code/nandakishorconvai/engine-transfer) (Nandakishor
  M., Apache-2.0): its code and the printed output of its saved run (two T4 cards, 56.9 minutes, `vegaml` 0.16.1,
  transformers 5.20.2);
- the PyPI page of its teacher, [vegaml](https://pypi.org/project/vegaml/);
- [Veloresearch/kinetic](https://github.com/Veloresearch/kinetic) (Apache-2.0): the README, the docs pages on devices,
  speed, models and benchmarks, the roadmap and the four issues.

I ran neither. Every number below is the authors' own, read from their output or their pages.

## The short answer

- **The notebook is real and its code is careful, but the post claims more than its own output shows.** The edited
  Qwen3.5-0.8B gained 4.9 points on the tasks it aimed at and lost 6.5 points on ARC-Easy.
- **It does not fit this project's work.** It writes one answer token of a multiple-choice prompt. An agent's work is
  long generated text and tool calls, and the fine-tune (E10) covers that. Parked as E66.
- **Its solve is useful where the target is exact:** repairing an expert cut against the uncut model, with no
  trainer. That is the new row E67.
- **Kinetic is a new inference engine, so it is the mining-rigs repo's ground, not this one's.** It cannot run on the
  rig, and its speed ideas are already rows in that repo's registry.

## 1. What the notebook does

**The teacher.** vegaml's "engine" is a trained 14.3M-parameter model with a 0.84M-parameter task adapter. It reads
the hidden states of a frozen Qwen3.5-0.8B and answers typed questions (a choice, a yes or no, a score). It generates
no text.

**The student.** A plain copy of the same Qwen3.5-0.8B. Each question is a prompt that lists the options with short
codes (A, B, C, or syllables such as `ba` past 26 options). The answer is the one token after `Answer:`.

**The edit.** No gradient steps. For one layer's MLP output matrix (`down_proj`), on 512 of its 3,584 input columns:
1. forward passes read what those columns see at the answer token of every training row;
2. the wanted change of the final hidden state is worked out from the teacher's probabilities, through the
   pseudo-inverse of the readout;
3. one ridge least-squares solve gives the weight change: `dW = Rᵀ K (Kᵀ K + λ n C)⁻¹`. C is the covariance of what
   must not move: the rest of each prompt, ordinary text, and the answers of the protected tasks;
4. a dose of that change is written if it passes caps on how far ordinary text and protected answers move.

The code's own docstring calls step 3 "the MEMIT normal equations restricted to the columns S". MEMIT
([arXiv 2210.07229](https://arxiv.org/abs/2210.07229)) is the 2022 method for writing many facts into a model. What
the notebook changes is the target: a teacher's answer distribution in place of a fact.

**The name.** "Weight-space programming" is from Takehi, Teoh, Zhang and Khattab (MIT CSAIL, 2026), where an LLM
agent edits weights by hand. The sister repo read it on 2026-11-09
([weight_space_lp.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/research/notes/weight_space_lp.md)).
That paper's own control shows the limit: an edit removes an obstacle, it does not add a skill the model lacks.

## 2. The post against the notebook's own output

| The post says | The notebook printed |
|---|---|
| "No new dataset and no training" | The edit takes no gradient steps. The teacher is a trained model. It labelled 2,765 rows, and gold labels chose which 11 of 35 tasks to transfer |
| "a closed-form solve that took 46 milliseconds" | 45.6 ms is the linear algebra alone. The edit took 2,550 s with its forward passes and dose checks |
| "makes better decisions on its own" | The 11 aimed tasks, 638 held-out rows: 0.495 → 0.544. JevBench (231 items, never used): 0.550 → 0.528 |
| "it still knows what it knew before" | ARC-Easy, 200 questions: 0.705 → 0.640. WikiText-2 perplexity: 28.75 → 29.17. Capitals: 1.000 → 1.000 |
| "will replace fine tuning" | No fine-tune was run on the same rows, so there is nothing to compare |

More from the same output:
- **The student gets a fifth of the teacher's lead.** The teacher's published run on the same held-out rows averages
  0.729 over the 11 tasks (my calc from the notebook's reference column). The edit closed 0.049 of that 0.234 gap.
- **One task carries 39 % of the gain:** `jailbreak_cls` went from 0.561 to 0.772. The other ten average +0.033 (my
  calc).
- **Its own caps refused most of the edit.** Of 6 steps, 2 wrote anything (layers 19 and 23, each at the smallest
  dose, 0.25). The second round wrote nothing. 1,048,271 weights changed, 0.139 % of the model.
- **"Protected" tasks moved as much as aimed ones:** `unfair_tos` 0.246 → 0.509, `hellaswag` 0.300 → 0.417,
  `cruxeval_output` 0.650 → 0.567, `medqa_usmle` 0.475 → 0.407. Each task has 60 rows, so one row is 1.7 points.
- **Free text shifted too:** after the edit, "The main causes of the French Revolution were" continues as a lettered
  option list.

## 3. What it means here

**Why the edit itself is parked (E66).**
- It moves the probabilities of one token at one position. A bench case is thousands of generated tokens over many
  turns.
- It needs a teacher that reads the same model and beats it. Here the teacher is a larger model that writes whole
  sessions, and the student learns from them by fine-tuning (E9, E10).
- At its best it took a fifth of its teacher's lead and cost 6.5 points on an unrelated test.

**Where the solve fits (E67).** Step 3 is plain ridge regression, and it works when the target is known exactly.
Here that case exists: after an expert cut, the uncut model gives the exact output every layer should have had.
- Per layer, solve for a correction to the shared expert's down projection so that the cut layer's output matches
  the uncut layer's on calibration tokens. Where the cut changes nothing the target is zero, which is the notebook's
  protection term for free.
- It needs forward passes and one solve per layer, no trainer. The routed experts stay byte-identical, as in E26.
- It is the layer-wise reconstruction of one-shot pruning ([SparseGPT](https://arxiv.org/abs/2301.00774)) and of
  EoRA ([arXiv 2410.21271](https://arxiv.org/abs/2410.21271)), applied to an expert cut. I know of no published
  result for that case, so the row carries no estimate.
- Open points: the corrected tensor is quantized again at its own type, and 3-bit rounding may swallow a small
  correction; a linear fix on one dense tensor cannot stand in for a missing expert's non-linear work.
- The calibration text obeys the hold-out rule (E12).

## 4. Kinetic

**What it is.** An inference engine in Rust that reads GGUF files, published on 2026-11-10: 12 commits by one
author, version 0.1.0.

**Its numbers.** One laptop (Ryzen 5 6600H, RTX 3060 Laptop 6 GB) against llama.cpp b12001, measured by the author.
The benchmarks page in its own docs has TBD in all 13 rows. I found no independent run.

| LFM3 1.7B Q4_K_M on the GPU, tokens per second | llama.cpp | Kinetic |
|---|---:|---:|
| edit (rename a variable, return the whole file) | 229.7 | 1033.7 |
| generate | 194.3 | 198.4 |
| prompt, 512 tokens | 7642.7 | 6820.6 |

The 4.5× is the edit test, where drafted tokens are copied from the prompt and checked in one pass. New text is
generated at llama.cpp's speed.

**It cannot run on the rig:**
- its CUDA path starts at the Turing generation (compute capability 7.5); a P106 is Pascal (6.1);
- it uses the first GPU only; two GPUs are on its roadmap, and the rig has nine;
- its Vulkan path runs no mixture-of-experts models;
- its architecture list has no Flash-Next.

**Its ideas are the sister repo's ground** and are rows in its registry already: drafting by copying from the context
(Q53, Q64), drafting from earlier requests (Q161), the model's own prediction block (Q43, Q226), prompt-state reuse
(Q111), one launch per token (Q88), an exact output layer that scores only rows that can win (Q414), experts split
between GPU and system memory (Q57). The rig also measured why the edit test's gain does not carry over: checking
2.90 tokens in one step took 57.7 ms against 25.9 ms for one token (Q19, 2026-10-23), so at that cost copy drafting
gave 1.26× on file rewrites and about 1.03× overall (Q64).

## Rows

- E66: a teacher's one-token decisions written into the weights by a closed-form solve (parked);
- E67: a closed-form repair of an expert cut, no trainer (planned).

## Sources

- The notebook: https://www.kaggle.com/code/nandakishorconvai/engine-transfer
- vegaml: https://pypi.org/project/vegaml/
- Meng et al., Mass-Editing Memory in a Transformer (MEMIT, 2022): https://arxiv.org/abs/2210.07229
- Takehi, Teoh, Zhang, Khattab, Sparks of Weight-Space Programming (MIT CSAIL, 2026):
  https://rikiyat.github.io/blog/weight-space-programming/
- Frantar and Alistarh, SparseGPT (2023): https://arxiv.org/abs/2301.00774
- Liu et al., EoRA: Training-free Compensation for Compressed LLM with Eigenspace Low-Rank Approximation (2024):
  https://arxiv.org/abs/2410.21271
- Kinetic: https://github.com/Veloresearch/kinetic
