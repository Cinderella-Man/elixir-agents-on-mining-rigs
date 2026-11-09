# Plan

The goal and what counts as a win are in the [README](../README.md). This page sets the measures, the hold-out rule
and the order of work. Row ids (E1, E2, …) are in the registry, [experiments.md](../experiments.md).

## Measures

- **Task success:** the [Elixir SWE Bench](https://github.com/Cinderella-Man/elixir-swe-bench), all 20 cases, the
  Pi harness, three seeds per model. The result is the number of cases passed in each run. Compare models only within
  one harness.
- **Closeness to the full model, for every cut:** KLD of the cut model's next-token distribution against Qwen3.8-Flash-Next
  Q8_0 on held-out Elixir agent text (E2), and on general text, so a cut that only moves the loss elsewhere shows.
  Q8_0 stands in for BF16, as in the sister repo. KLD picks candidates, and the bench decides.
- **Speed:** time per task in a coding-agent session on the rig, with the sister repo's
  [agent check](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/tree/main/bench/agent_check).
  Single-request tok/s is a diagnostic only.
- **Numbers are quoted per run:** the file, the build and the settings, with repeats listed by value, never as a range.

## Hold-out rule

The bench's 20 cases come from 12 projects: absinthe, accent, ash, beacon, cachex, guardian, live_beats, livebook,
operately, pinchflat, plausible-analytics and vutuv. **Nothing that shapes a model may come from these 12 projects:**
not training tasks, not calibration text for pruning, and not the statistics that choose experts or layers. E12
checks every task, text and session against them before use.

## Track A: shrink Qwen3.8-Flash-Next for Elixir (no training)

Why it can work:
- A mixture-of-experts layer sends each token to 10 of its 512 experts, and narrow work uses only part of them.
- arXiv 2607.16721 (July 2026) removed half the experts of two MoE models with no detectable loss on code. In their
  equal-memory comparison, pruning beat quantizing only where quantizing would drop below 3 bits a weight, and the
  rig's Flash-Next files are at 2.
- The sister repo found the same split on general agent text: Swift IQ3_S cut to 416 experts beat the uncut IQ3_XXS on
  agent text (KLD 0.131 against 0.176) and on code (0.043 against 0.054), but lost on wiki text (0.724 against 0.248)
  ([registry Q891](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/quants/experiments.md)).

Order:
1. **E2:** Elixir agent text (calibration and a held-out KLD set) and Q8_0 reference logits on it.
2. **E3:** expert usage on that text, per layer: how concentrated Elixir routing is, and how it differs from general
   agent text.
3. **E4:** the Elixir expert cut, keeping 384, 320 or 256 of 512 experts per layer, with the freed bytes spent on more
   bits for the kept ones. Each file must fit at or below Swift Q2_0's 35,730 MiB on the cards. KLD first, then the
   bench.
4. **E5, E6, E7:** merged near-duplicate experts, dropped layers, a trimmed vocabulary. Each is tried on the best E4
   file and kept only if its KLD stays within noise.
5. **E11:** a short repair fine-tune on the teacher's sessions, once track B has them.

## Track B: teach a small model from the teacher

Why it can work:
- DeepSeek-V4.1-Flash-1017 solves 16 of 20 cases even at 1-bit (Unsloth UD-IQ1_M).
- Tuned small models win on narrow work, and nobody has measured a language-specific tune inside a multi-turn agent
  loop ([report](research/finetuning/reports/Fine%20tuning%20small%20models%20for%20Elixir.md)).
- Only sessions whose fixes pass `mix test` are kept, so the student learns from verified work.

Order:
1. **E8:** mine tasks. Merged pull requests with tests, from Elixir projects outside the 12, in the bench's case
   format (a prepared baseline, tests that fail before the fix and pass after). E12 screens each one.
2. **E9:** teacher sessions on them. Several attempts per task in Pi; a session is kept when its fix passes the
   held-back tests. Measure sessions per hour first, since that sets how much data there can be.
3. **E10:** pick the student by scoring the candidates untuned (about 3B active parameters: Ornith-1.5-35B-A3B,
   Qwen3.6-35B-A3B). Then a LoRA fine-tune on the kept sessions, three bench seeds against its own base and against
   the bar, and finally its rig-sized file and its speed on the rig.
4. Later, reinforcement learning with the tests as the reward, only if fine-tuning gains.

Earlier research on this track is in [research/finetuning](research/finetuning/), with its notes:
- [Fine tuning small models for Elixir](research/finetuning/reports/Fine%20tuning%20small%20models%20for%20Elixir.md):
  which bases can be tuned, cost estimates, and why agentic data matters (registry rows Q472–Q503).
- [Agentic RL for a DeepSeek teacher](research/finetuning/reports/Agentic%20RL%20for%20a%20DeepSeek%20teacher.md):
  filtering sessions and the teacher's pass rate (Q524–Q545).

Research on shrinking models:
- [expert_pruning_survey.md](research/notes/expert_pruning_survey.md): REAP, REAM, merging, domain pruning, available
  pruned files;
- [pruning_from_flint_surveys.md](research/notes/pruning_from_flint_surveys.md): pruning heads, experts and layers;
- [pruning_and_lottery_tickets.md](research/notes/pruning_and_lottery_tickets.md): what pruning saves in bytes on a
  P106, and why lottery tickets don't help.

The registry rows for these, Q239 to Q1142, are at the end of [experiments.md](../experiments.md).

A survey of every row, its extensions and new ideas (2026-11-09):
- [idea_survey_2026-11.md](research/notes/idea_survey_2026-11.md): what the published bench runs and the literature add
  to each experiment, and rows E13–E45;
- [study_order_2026-11.md](research/notes/study_order_2026-11.md): a proposed order for all of them, starting with the
  bar, the ceiling and the task factory.

## Where work runs

- **The rig** (nine P106-090 6 GB cards) runs only what needs it: the speed of a candidate and whether it fits.
- **A 7-GPU machine** (five RTX 3090, two RTX 3080) runs the rest: the teacher, fine-tuning, reference logits, KLD,
  file building and bench runs.
- Quality never needs the rig: the same file gives the same answers on any card that runs the same engine.
