# Study order: what to do first, and why (2026-11-09)

A proposed order for the registry's rows, from the [survey](idea_survey_2026-11.md). The rows and their evidence are
there and in [experiments.md](../../../experiments.md); this page only orders them. Times are estimates (est.).
[plan.md](../../plan.md) stays the plan of record until this order is adopted.

## The order in six lines

1. **Measure before building:** the bar, the ceiling and the failure diagnostics in one block (E1, E13, E20, E15).
2. **Build the task factory first among the build work** (E46 to E51, then E36, E8 and E37, screened by E12, split by
   E18 and E53).
   Every later step consumes its tasks.
3. **Try the cheapest candidates early:** the rules block in the chat template (E39) and the effort setting (E16).
4. **Then the cut** (E2, E3 with E22 and E23, E4 with E21's arms), judged by KLD, by tokens per solved case and on
   the dev lane before the bench.
5. **Then training:** the student's baseline (E10 with E38), teacher sessions (E9), the repair of the cut file (E26).
6. **Reinforcement learning last,** and only if fine-tuning gains.

## Three facts behind the order

- **Flash-Next fails mostly by running out of budget.** 7 of 10 and 5 of 9 failures of its two published files
  ended at the 65,536-token budget ([data](../../data/2026-11-09_bench_runs_read/README.md)). Whether those attempts
  were close is unknown, and it decides between "make it more efficient" and "teach it more".
- **Nobody has measured the ceiling.** If Flash-Next at high precision scores no more than the 2-bit bar, cutting
  experts to buy precision is unlikely to win on this bench, however good the KLD.
- **The bench resolves est. 2.5–3.0 cases between two three-seed series.** A one-case gain cannot be shown on it, so
  small gains need a larger lane and a rule fixed in advance.

## Step 0: no GPU needed

These can start before the 7-GPU machine is free.

| Row | Work | Kind | Gives |
|---|---|---|---|
| E17 | the rule for "beats the bar", and six seeds for the bar | a decision | every later comparison |
| E19 | the sibling and fork rules in E12 (the reserved list is dropped: the bench will not grow for some time) | code | a mining pool that stays clean |
| E46, E51 | the first wave of 40 projects and the licence allow-list ([guide](task_collection_guide.md)) | a decision | what may be mined |
| E47 | one mirror per project in a GitHub organisation made for the dataset | setup | stable places to clone from |
| E49, E50 | the sandbox rules and the environment recipes for third-party projects | code | project code that can be run safely |
| E36, E52 | list the repositories of SWE-rebench V2's 416 Elixir tasks; count Open-SWE-Traces' Elixir sessions | metadata queries | whether E8 and E9 start from ready rows |
| E8, E12, E37 | the mining code with the hold-out, for applications, frameworks and libraries | code | tasks in the bench's case format |
| Q526 | the nine grader gates as checks on every mined task | code | tasks that can be trusted |
| E39 | the text of the rules block | writing, by the owner or an approved writer | the cheapest candidate |
| E20 | the census script for saved transcripts | code | failure classes per run |
| E27 | the design of the trainer that reads a file's quantized experts, and a two-layer toy | design, code | whether the repair can run at home |

Desk reads that sharpen later steps:
- the code behind [arXiv 2607.16721](https://github.com/anik-jha/moep): does its LoRA and router recipe carry over
  to Flash-Next's graph;
- RAZOR's full text: can its score come from the sister repo's existing collector;
- North Mini Code's and HERO's training-data provenance and engine support (E38);
- the hosted training service's terms (the registry's Q533).

## Step 1: the first GPU block is measurement

| Order | Row | Runs | What it settles |
|---|---|---:|---|
| 1a | E1, the bar: both rig files | 6 | the number every candidate must beat |
| 1a | E13, the ceiling: Swift IQ3_S | 3 | whether precision is worth cases |
| 1a | E20 and E15 on the bar's evidence | under 1 | why attempts fail; whether capped attempts were close |
| 1b | E16, the effort arm on the better bar file | 3 | the bar's best setting |
| 1b | E39, the rules block on the better bar file | 3 | whether text alone beats the bar |
| 1c | three more seeds of the bar | 3 | a six-seed bar, when a candidate comes near |

A run is 20 attempts. The published Pi runs generated between 657,391 and 945,855 tokens each.

**What step 1a decides:**

| Outcome | Reading | What goes first |
|---|---|---|
| The ceiling is 3 or more cases above the bar | precision is worth cases | the cut: E2, E3, E4, straight to the bench |
| Less than 3 cases, and most failures end at the budget | file quality shows in tokens, not in cases | efficiency: E39, E16, E29; the cut is judged on tokens per solved case and the dev lane |
| Less than 3 cases, and most failures end below the budget with failing tests | the model lacks Elixir knowledge or skill | training: tasks, teacher sessions, then E10 and E26 |

## Step 2: tasks and the cut

- **Tasks:** E36's rows and E8's own mining, in E37's three strata, screened by E12 and E19 and checked by the
  gates. Split by repository into training, calibration, held-out KLD text and the dev lane (E18).
- **The teacher's yield:** the registry's Q524 on 50 mined tasks through the maker's API needs no GPU. It sets how
  many kept sessions a given budget buys.
- **The cut:** E2's text and reference logits, E3's rankings with E22 and E23, then E4's arms from E21. Each arm
  gets KLD on Elixir and general text, then the dev lane, and only the best goes to the bench. E31 measures draft
  acceptance on that file before it goes to a rig. E24 joins if the engine accepts per-layer expert counts.

## Step 3: training

- **The student:** score the untuned candidates (E10 with E38) on the dev lane and the bench. E44, the agent check
  of an untuned 35B-A3B file, can run whenever a rig is free: it is the only rig work that needs no winner.
- **Fine-tune** the best candidate on the kept teacher sessions, with the shortest solve per task (E41). Three
  bench seeds against its base and the bar. E43 picks its rig file.
- **Repair the cut** with E26, at home through E27 or on a rented node (E28). Check that the repaired tensors
  differ from the unrepaired ones before trusting any score. Then E29.
- **E40** if E39 gained; **E42** as an arm of the first fine-tune.
- **Self-training rounds** (E54 with E55 and E56, judged on E57) after the first fine-tune: at most two, stopping at
  the first round without a gain ([report](../finetuning/reports/Recursive%20self-improvement%20for%20an%20Elixir%20model.md)).
- **Reinforcement learning** (Q485, Q486, Q531) only if those rounds are still gaining when they stop being cheap.

## What waits

- E5, E6, E7 and E25 until E4 has a best file.
- E30's published derivatives until the bar exists; they need downloads.
- The parked rows E32–E35 and E45, each with its reopening condition in the registry.

## What not to do first

- Any training of Flash-Next before E13: a repair aims at the uncut model, and E13 says whether that target is above
  the bar.
- Reinforcement learning before a fine-tune gains.
- Merging, layer drops and the vocabulary trim before the expert cut: each is judged on the cut file.
- More single-seed bench runs of new candidates: one run cannot rank neighbours.

## Decisions that unblock the most

1. The first wave of projects (E46) and the licence allow-list (E51). Mining cannot start without them.
2. The GitHub organisation for the mirrors (E47).
3. The download of SWE-rebench V2's Elixir rows (E36).
4. The decision rule and the six-seed bar (E17).
5. Who writes the rules block (E39).
6. DeepSeek as an approved writer, and the API spend for Q524 (est. $10–35).
7. A rented 8-GPU node for one repair run (E28), est. a few hundred dollars at list prices, which were not read
   again for this page.
8. Downloads of the extra student candidates (E38) and the published derivatives (E30).
