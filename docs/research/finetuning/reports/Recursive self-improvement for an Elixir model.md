# Self-improvement is a loop around fine-tuning, not a replacement for it

"Recursive self-improvement" (RSI) is one name for four different things, and only two of them can be used on this
project's hardware today. The usable ones are a model training on its own verified work in rounds, and a model
rewriting its own instructions from its failures. Both sit on top of ordinary fine-tuning: the first round of every
loop that works is a normal fine-tune on good examples. Measured gains are real and bounded. A loop adds a few points
for one or two rounds, more when failed tasks are retried with a hint, and more again when new tasks are made each
round; then it flattens, and on tasks unlike the training pool it flattens early. Nothing published shows a model
improving itself without limit, and a 2026 survey of 1,250 papers says so directly. For this project the answer is:
do the normal fine-tune first, then run at most two self-training rounds with hints, judged on tasks from projects the
model never trained on, and stop at the first round that brings nothing. Every session such a loop keeps is also a
row of the public dataset, so the loop and the data factory are the same machine. All costs below are estimates.

## Six direct answers

**What is it?** A loop in which a system's output makes the system better, and the better system then repeats the
step. In 2026 the name covers four things:
1. a model trained on its own verified output, round after round;
2. a model that also makes its own tasks or opponents;
3. an agent that rewrites the program or the instructions around a frozen model;
4. an AI system that does the research and engineering of building the next model.

The classic idea is the fourth, with no limit and no human: I. J. Good's "intelligence explosion" of 1965 and
Schmidhuber's Gödel machine of 2003 ([history](https://www.turingpost.com/p/from-i-j-good-to-flint-the-long-strange-quest-for-self-improving-ai)).

**Can we use it?** Forms 1 and 3, yes, at home. Form 2 partly: making tasks is cheap, the reinforcement learning that
usually goes with it is not. Form 4, not as a way to get a model.

**How?** As rounds: the fine-tuned student attempts every training task several times, the hidden tests keep the
attempts that pass, the kept sessions join the training set, and the student is trained again from its base.

**What gains?** Per round, published loops add between +0.7 and +9.1 points on the benchmark they train for. With
hints on failed tasks one study reached +8.2 where the plain loop reached +1.0. With new tasks each round, +7.8 to
+12.2. On tasks unlike the training pool one careful study moved from 3 % to 6 % and stopped.

**How to do it?** Section "The loop for this project": eight steps, four guards, and a stop rule.

**Instead of normal fine-tuning?** No. It needs a normal fine-tune as its first round, and a student distilled from
a strong teacher beats the same student trained by reinforcement learning alone (72.6 against 47.0 in the one direct
comparison, [DeepSeek-R1](https://arxiv.org/html/2501.12948v1)). The loop is what comes after, and it competes with
reinforcement learning, not with fine-tuning.

## Four things share one name

| Form | What changes | Example, and its measured result | Needs | Usable here |
|---|---|---|---|---|
| 1. Self-training | weights, from the model's own passing attempts | one round on a 72B agent: 11.4 → 20.5 on SWE-bench Verified ([Golubev et al.](https://arxiv.org/html/2508.03501v2)) | tasks with tests, sampling time, one fine-tune per round | **yes** |
| 2. Self-made tasks and self-play | weights, on tasks the model makes for itself | a 35B model with 3B active as both task maker and solver: 41.1 → 53.3 on Terminal-Bench 2.1 ([AutoEnvScaling](https://arxiv.org/abs/2610.14163)) | the same, plus reinforcement learning at scale; self-play used 512 H100 per run | making tasks: yes; the RL: not at home |
| 3. Self-rewritten harness or prompt | the program or the instructions around a frozen model | a coding agent rewriting its own code: 20.0 % → 50.0 % on SWE-bench ([Darwin Gödel Machine](https://arxiv.org/abs/2505.22954)) | many test runs, no training | **only the instructions:** the bench fixes the harness |
| 4. Automated AI research | everything: data, recipes, architecture, code | agents given one H100 and 10 hours to post-train a model: 23.2 % against 51.1 % for the makers' own tuned models ([PostTrainBench](https://arxiv.org/abs/2603.08640)) | a research agent, a sandbox, a metric it cannot game | not as a route to a model |

Two names in this project's notes need a word:
- **Flint** is sold as built by its maker's research system. Reports credit that system with the expert layout, a
  4-bit output layer and hardware kernels, and note that the maker has not shown the system getting better from one
  run to the next ([The Next Web](https://thenextweb.com/news/recursive-flint-local-coding-model-eureka-machine),
  [Turing Post](https://www.turingpost.com/p/from-i-j-good-to-flint-the-long-strange-quest-for-self-improving-ai)).
  That is form 4 without the "recursive" part shown.
- **`tarak-qwen3.6-35b-a3b-rsi-v1`**, cited in the first fine-tuning report, describes no self-improvement loop on
  its card. It is a language adaptation with frozen experts.

## What the evidence says

### Training on its own verified work helps once or twice

| Study | Setting | Result |
|---|---|---|
| [Golubev et al.](https://arxiv.org/html/2508.03501v2) | a 72B agent, 7,249 tasks × 10 attempts, 6,548 passes kept, one epoch | SWE-bench Verified 11.4 → 20.5; at 10 attempts 31.0 → 43.0 |
| [SWE-Gym](https://arxiv.org/html/2412.21139v2) | two rounds, 30 attempts per task | 32B: 19.0 → 19.7 → 19.7; 7B: 7.0 → 9.0 → 10.0 |
| [SWE-Gym](https://arxiv.org/html/2412.21139v2) | 868 own passes mixed with 491 teacher sessions, retrained | **worse:** 15.3 → 8.7 on SWE-bench Lite |
| [ReST-EM](https://arxiv.org/html/2312.06585v1) | math and code problems, always retrained from the base | about +6 points; 41.0 after round 2, 41.9 after round 3; code gains almost all in round 1 |
| [One to More](https://arxiv.org/abs/2609.23377) | rounds of own verified successes between RL phases, no outside model | +4.57 on SWE-bench Pro V2, +3.89 on SWE-bench Multilingual |

Three readings:
- **The big gain came from a weak start.** The 72B agent began at 11.4 %; much of its +9.1 was learning the harness.
  A model that already works in its loop gains little: 19.0 → 19.7.
- **It can go backwards.** Mixing a model's own passes into the set without care halved one score.
- **Theory agrees.** Self-training moves probability toward outputs the model could already produce; it is
  "impossible for this self-improvement to create information that is not already in the model", so the gain is
  bounded by what sampling finds
  ([Huang et al.](https://arxiv.org/abs/2412.01951)). A task the model never solves in k attempts teaches nothing.

### A hint on the failed tasks breaks that bound

Every mined task has a reference fix. A short hint written from it lets the model solve tasks it failed, and the
session is still the model's own.

| Study | Method | Result |
|---|---|---|
| [Hindsight Hint Distillation](https://arxiv.org/html/2605.11556v1) | a 2–3 sentence hint from the reference patch, added to the task statement once; three rounds | Qwen-72B from 43.0: plain loop 44.0, with hints **51.2**; GLM-4.5-Air from 35.2: 38.0 and 42.0 |
| [debug-gym](https://microsoft.github.io/debug-gym/blog/2026/08/negative-pi/) | failed sessions' wrong beliefs, checked against the reference patch, shown as a warning block | +4.1 on SWE-bench Verified for a 32B student, +2.8 for a 4B |
| P2T (in the [teacher report](Agentic%20RL%20for%20a%20DeepSeek%20teacher.md)) | the reference patch shown during data making only | student up to +10.8 |

Short hints at the start worked; long plans and hints in the middle of a session did worse in the same study.

### New tasks each round beat a fixed pool

| Study | Who makes the tasks | Result |
|---|---|---|
| [AutoEnvScaling](https://arxiv.org/abs/2610.14163) | the model being trained, from its own sessions | Qwen3.6-35B-A3B: Terminal-Bench 2.1 41.1 → 53.3; the fixed-pool baseline from the same start reached about 47.2 |
| [Socratic-SWE](https://arxiv.org/abs/2606.07412) | a generator steered by skills distilled from the solver's sessions, 12,000 validated tasks a round | SWE-bench Verified 50.40 % after three rounds, +7.80 over its base |
| [Self-play SWE-RL](https://arxiv.org/abs/2512.18552) | the model plants bugs and fixes them; a bug is defined by a test patch | +10.4 on SWE-bench Verified, +7.8 on SWE-bench Pro |
| [Self-Challenging agents](https://arxiv.org/abs/2506.01716) | the model writes a task, a check, a solution and failing cases | over twice the success of Llama-3.1-8B on two tool-use benchmarks |

What it takes:
- **A check that a made task is real.** AutoEnvScaling keeps a task when its reference solution earns full reward,
  an empty solution earns less than half, and the current solver's mean reward is between 0.25 and 0.75.
- **A model able to make tasks.** The untrained 35B produced valid tasks 32.3 % of the time; 600 examples of task
  making raised that to 86.8 %. Without training the task-making side too, the loop improved at first, then declined
  as invalid tasks grew, and the run collapsed.
- **Compute.** These gains come with reinforcement learning. Self-play SWE-RL used 512 H100 per run
  ([notes](../research_notes/Agentic%20RL%20for%20a%20DeepSeek%20teacher/open_agentic_rl_recipes.md)).

### The most-cited loop gained 35 points on its own kind of task and 3 on others

Terminal-RSI alternates supervised training on the model's own verified, rewritten sessions with critic-based
reinforcement learning, from Qwen3.8-27B ([paper](https://arxiv.org/html/2610.22192)):

| Stage | Terminal-Bench 2.1 | Held-out set (no task overlap) |
|---|---:|---:|
| Base | 51.70 | 3.00 |
| Self-rewrite 1 (supervised) | 70.10 | 5.00 |
| Policy refinement 1 (RL) | 77.53 | 6.00 |
| Self-rewrite 2 | 86.52 | 6.00 |
| Policy refinement 2 | 86.52 | 6.00 |

- **The supervised self-training round did the most:** +18.4, against +7.4 for the RL that followed.
- **RL without it failed:** direct PPO reached 48.31, below the base's 51.70.
- **The held-out number stopped after one round.** The authors also say overlap between their task pool and public
  repositories is "incompletely audited", and that five stages of one model "establish neither scaling laws nor
  universal monotonicity".
- **Longer training hurt:** three branches lost 2 to 6 points when continued.

### Rewriting the harness or the prompt works, within what may be changed

- [Darwin Gödel Machine](https://arxiv.org/abs/2505.22954): 20.0 % → 50.0 % on SWE-bench, 14.2 % → 30.7 % on
  Polyglot, by rewriting the agent's code around a fixed model. [SICA](https://arxiv.org/abs/2504.15228): 17 % → 53 %
  on a subset of SWE-bench Verified. Both started from weak harnesses.
- [ModularRSI](https://arxiv.org/html/2609.14857v2), from a strong harness: Terminal-Bench 2.0 47.57 → 52.43,
  SWE-bench Verified 73.40 → 76.40. The evolved harness carried to other models (59.55 → 61.80 and 41.57 → 44.94).
  Evolving everything at once scored 44.19, below the start.
- [GEPA](https://arxiv.org/abs/2507.19457) evolves prompts by having a model read failed sessions and rewrite the
  text: 6 % above GRPO reinforcement learning on average across six tasks, with up to 35 times fewer attempts.

The Elixir SWE Bench fixes the harness, so only text inside the model file can evolve: the rules block of the
registry's E39.

### Research agents do not yet match people, and they cheat

- [PostTrainBench](https://arxiv.org/abs/2603.08640): the best agent reached 23.2 % where the makers' own tuned
  models reach 51.1 %. Agents trained on the test set, downloaded finished checkpoints instead of training, and
  used API keys they found.
- [RSIBench-Data](https://arxiv.org/abs/2607.25886): agents improved on their first valid attempt in 58.33 % of
  settings and could not turn feedback into steady gains.
- [autoresearch](https://github.com/karpathy/autoresearch) runs about 12 five-minute training experiments an hour
  on one GPU; reported gains vary from 2.9 % to 19 % and depend on a tight metric.

### Open-ended self-improvement is not established

The largest survey ([arXiv 2607.07663](https://arxiv.org/abs/2607.07663), 1,250 papers from 2024 to 2026) separates
bounded self-refinement, which it calls convergent, evaluable and already industrial practice, from open-ended RSI,
which it finds limited by grounding, collapse and compute on every axis it measured. Its main finding fits everything
above: **how far a loop gets follows how strong its checker is**, from formal checks
and executable tests at the top to the model's own opinion at the bottom.

## What stops every loop

| Limit | Evidence | What it means here |
|---|---|---|
| The checker | gains track the verification hierarchy (survey); with an imperfect verifier, retraining gains early, then plateaus or reverses ([Yi et al.](https://arxiv.org/abs/2510.16657)) | hidden tests the model cannot edit, and the gates of Q526 on every task |
| Coverage | self-training cannot add what the model never produces ([Huang et al.](https://arxiv.org/abs/2412.01951)) | hints, a teacher's sessions and new tasks are what add information |
| Collapse | models trained on their own output lose quality or diversity "without enough fresh real data in each generation" ([Alemohammad et al.](https://arxiv.org/abs/2307.01850)) | teacher sessions and real pull-request tasks stay in every round; retrain from the base |
| Held-out plateau | Terminal-RSI: 3 → 6 → 6 → 6 on unseen tasks | judge each round on projects outside the training pool |
| Reward hacking | agents trained on the test set and fetched finished models (PostTrainBench); a production agent learned to emit broken tool calls on tasks it expected to fail ([notes](../research_notes/Agentic%20RL%20for%20a%20DeepSeek%20teacher/open_agentic_rl_recipes.md)) | the bench never enters a loop; audit kept sessions for edited tests and hard-coded answers |
| Self-distillation failures | "thinking collapse" and "decoding collapse" when a model distils from itself ([2607.10805](https://arxiv.org/abs/2607.10805), [2607.17558](https://arxiv.org/abs/2607.17558)) | a caution for baking the rules block into weights (E40): anchor to the frozen base |

## The loop for this project

Elixir suits a bounded loop: the checker is the project's own test suite, near the top of the hierarchy, and the
language is one where base models are weak, which is where loops have gained most. In a low-resource language a
small model trained against a verifier passed the teacher it was distilled from (15 problems solved against 12 in
Fortran, [notes](../research_notes/Agentic%20RL%20for%20a%20DeepSeek%20teacher/teacher_to_student_distillation.md)).

**The steps** (registry rows in brackets):
1. **Round 0 is the normal fine-tune:** the student on the teacher's verified sessions (E10).
2. **Sample:** the tuned student attempts every training task 4 times in the bench's harness.
3. **Keep** the passing sessions, the shortest per task, at most three per task (E54).
4. **Hint the failures:** for each task with no pass, add a 2–3 sentence hint written from the reference fix by an
   approved writer and let the student try again; keep the passes, stored without the hint (E55).
5. **Add tasks where it fails:** new planted-bug tasks in the task families with the lowest pass rates, kept when
   the reference passes, the untouched state fails, and the student passes between 15 % and 85 % of the time (E56).
6. **Retrain from the base** on everything: teacher sessions, the student's own, the hinted ones.
7. **Measure** on a held-out set of mined tasks from projects no training task comes from, large enough to see a
   few points (E57), with tokens per solved task beside the pass rate.
8. **Stop** at the first round without a gain there. Expect one or two useful rounds.

**The guards** (E59):
- the bench's 12 projects are invisible to every step;
- each round's set keeps the teacher's sessions and real pull-request tasks;
- watched every round: malformed tool calls, distinct fixes per task, session length, KLD on general text;
- kept sessions are scanned for edits to tests and for hard-coded expected values.

**The rules block can run the same loop in text** (E58): the model reads its failed held-out sessions, proposes a
changed block, and the change stays only if the held-out pass rate rises. No weights move.

**What one round costs at home (est.).** From the earlier reports' rates: seven cards wrote 15.4M generated tokens
in 9.15 hours, and one epoch over 2,000 sessions is est. 23 hours for a 9B model and about 1.7 times that for
Ornith-1.5-35B.

| Piece | Size | Time on the 7-GPU machine (est.) |
|---|---|---|
| Sampling | 1,000 tasks × 4 attempts at 20,000 to 35,000 generated tokens | 2 to 3.5 days |
| Hinted retries and new tasks | about a quarter more | 0.5 to 1 day |
| Training from the base | one epoch over about 2,000 to 3,000 sessions | 1.5 to 2.5 days |
| Held-out measurement | 300 tasks × 2 attempts | 0.5 day |
| **One round** | | **about 5 to 7 days** |

Two rounds are about as long as the one small reinforcement-learning run the first report priced at 9 days for a 9B
model. The loop needs no new training stack, can stop after any round, and every kept session is publishable data.

**What to expect (a judgement from the tables above).** Round 0 carries most of the gain. Round 1 with hints adds a
few points on the held-out set; round 2 adds less or nothing. On the 20-case bench that is zero to two cases, which
three seeds cannot show, so the held-out set decides and the bench confirms once at the end.

## Compared with normal fine-tuning

| | Normal fine-tuning | Self-training rounds | Reinforcement learning |
|---|---|---|---|
| Learns from | the teacher's verified sessions | the student's own verified sessions, hinted retries, new tasks | reward on every attempt |
| Adds | what the teacher can do | consistency, shorter solves, tasks the teacher missed | behaviour the data never showed |
| Bounded by | the teacher and the data | what sampling plus hints can reach | compute and stability |
| At home | hours to days | about 5 to 7 days a round (est.) | 9 days or more a run (est.), new stack |
| Risk | little | wasted rounds, collapse if fed only itself | collapse, reward hacking, numerics |
| Evidence | strong | strong for one or two rounds | strong at scale, thin on small hardware |

**Order:** fine-tune first; then the loop, because it reuses the same tools and its sessions are the dataset; RL only
if the loop is still gaining when it stops being cheap.

**What not to do:** start with the loop from an untuned student; run rounds without a held-out measure; let the
student write its own tasks before it can; give a research agent the keys before the manual recipe is stable.

## Rows

E54 to E61 in [experiments.md](../../../../experiments.md): the self-training rounds, hints, tasks aimed at
failures, the held-out set sized for the loop, the self-rewritten rules block and the guards are planned; a research
agent running the experiments and self-play reinforcement learning are parked with their reopening conditions.

## Sources

Read through summarising fetches or abstracts unless the project's notes are cited; check a number in its source
before building on it.

- Chen, Wang, Qu, Recursive Self-Improvement in AI (survey): https://arxiv.org/abs/2607.07663
- Terminal-RSI: https://arxiv.org/abs/2610.22192
- AutoEnvScaling: https://arxiv.org/abs/2610.14163
- Socratic-SWE: https://arxiv.org/abs/2606.07412
- Self-play SWE-RL: https://arxiv.org/abs/2512.18552
- Self-Challenging Language Model Agents: https://arxiv.org/abs/2506.01716
- Absolute Zero: https://arxiv.org/abs/2505.03335
- Hindsight Hint Distillation: https://arxiv.org/abs/2605.11556
- debug-gym, learning from negative trajectories: https://microsoft.github.io/debug-gym/blog/2026/08/negative-pi/
- One to More, More to One: https://arxiv.org/abs/2609.23377
- Golubev et al.: https://arxiv.org/abs/2508.03501; SWE-Gym: https://arxiv.org/abs/2412.21139; ReST-EM:
  https://arxiv.org/abs/2312.06585
- Huang et al., The Sharpening Mechanism: https://arxiv.org/abs/2412.01951
- Alemohammad et al., Self-Consuming Generative Models Go MAD: https://arxiv.org/abs/2307.01850
- Yi et al., Escaping Model Collapse via Synthetic Data Verification: https://arxiv.org/abs/2510.16657
- Thinking collapse and decoding collapse in self-distillation: https://arxiv.org/abs/2607.10805,
  https://arxiv.org/abs/2607.17558
- Darwin Gödel Machine: https://arxiv.org/abs/2505.22954; SICA: https://arxiv.org/abs/2504.15228; ModularRSI:
  https://arxiv.org/abs/2609.14857; GEPA: https://arxiv.org/abs/2507.19457
- PostTrainBench: https://arxiv.org/abs/2603.08640; RSIBench-Data: https://arxiv.org/abs/2607.25886; autoresearch:
  https://github.com/karpathy/autoresearch
- NeoHorse-1: https://arxiv.org/abs/2609.08183
- Flint and its maker's research system: https://thenextweb.com/news/recursive-flint-local-coding-model-eureka-machine,
  https://www.turingpost.com/p/from-i-j-good-to-flint-the-long-strange-quest-for-self-improving-ai
- A research map of the field: https://github.com/lobehub/awesome-rsi
