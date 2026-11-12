# Field notes on offloading MoE experts, read for this project (2026-11-12)

A read of one outside article: Alexey Fateev, "Everything I learned offloading MoE experts on 4x RTX 3090"
([X article](https://x.com/superalesha/article/2120840758223688028), 2026-11-12, 27 pages). It reports four months of
running DeepSeek V4.1 Flash, Qwen3.8 Flash Next, GLM-5.3 Flash and MiniMax M3.1 Flash on four RTX 3090 cards, with the
experts that do not fit on the cards kept in main memory. This note says what it claims, what carries over to this
project, and what does not. Nothing was run for it.

**The short answer.** The article's main subject (which experts stay on the cards) is a small lever for the teacher on
the 7-GPU machine: by that machine's own numbers, experts outside the cards account for at most about 2.6 ms of a
24.94 ms generated token (est.). Its side findings matter more here: prompt reading is bound by the bytes that cross the
card links, short speed tests mislead, power caps cost speed where one card works at a time, and an expert's pick count
is the wrong score for deciding whether to delete it. The rig takes almost nothing from the offloading parts: it has no
main memory to offload to.

*Tags: **[article]** stated in the article, measured on its hardware, not checked here. **[engine]** read in the engine's
own repository at the version the 7-GPU machine runs ([Strata](https://github.com/Niko1221/Strata) v0.2.13, commit
`d2f0964`), through fetched pages; exact defaults still have to be read on the machine. **[project]** measured by this
project or its sister repo. **[est.]** arithmetic of this note, never run.*

## 1. The article's hardware against ours

| | The article | The 7-GPU machine (the teacher) | The rig (the student) |
|---|---|---|---|
| Cards | 4 × RTX 3090, 96 GB | 5 × RTX 3090 and 2 × RTX 3080, 142 GB | 9 × P106-090, 54 GB |
| Card links | PCIe 3.0 x16 each, 13 GB/s a card, peer-to-peer on | PCIe 2.0: two at x8, one at x4, four at x1; no peer-to-peer | PCIe 1.0 x1, no peer-to-peer |
| Processor | EPYC 7642, 48 cores, Zen 2 | Ryzen 9 5900X, 12 cores, Zen 3 | 2 Celeron cores, no AVX |
| Main memory | 2, then 4, then 8 channels of DDR4, up to 503 GiB | 2 channels, about 125 GiB | 4 GB |
| Power cap | 300 W a card | 250 W (RTX 3090), 220 W (RTX 3080) | 75 W |

A PCIe 2.0 x1 link carries at most 0.5 GB/s, 26 times less than the article's 13 GB/s; the machine's x4 and x8 links
were timed at 1.7 to 3.4 GB/s by the engine's own start-up probe [project]. Every statement of the article that
involves a copy to a card has to be re-priced by that factor before it is used here.

## 2. The cost model, applied to the teacher

**The claim [article].** With experts outside the cards, time per token = a constant part + misses per token × the
cost of one miss. A miss is a routed expert that is not on a card. Its DeepSeek fit on four cards: one speculative
round takes 22.4 ms + 5.1 ms × rows + 13.4 ms × rows × miss rate (R² 0.9997). Once misses are cheap the constant part
decides: on its DeepSeek set-up 10 GB more card memory for experts was worth +1.8 % by calculation, and one kernel
change gave +5.6 %. Its rule: before freeing card memory for experts, check what share of a token goes to misses.

**Our numbers [project].** The teacher is DeepSeek-V4.1-Flash-1017 UD-IQ1_M: 40 layers, 384 experts a layer, 6 picked
per token, 132.2 GB of routed experts.

| Configuration (the machine's set-up notes, 2026-11-06, 10 prompts of 300 tokens) | Experts outside the cards | Generation | Per token |
|---|---:|---:|---:|
| 5 cards, drafter, a host thread per card | 43 GB | 36.8 tok/s | 27.17 ms |
| 7 cards, drafter, a host thread per card (as deployed) | 20 GB | 40.1 tok/s | 24.94 ms |
| The half-cut Coder file, 5 cards, no drafter | 2 GB | 49.0 tok/s | 20.41 ms |
| The half-cut Coder file, 7 cards, no drafter | none | 47.0 tok/s | 21.28 ms |

- **Two more cards cost 0.87 ms a round** (21.28 against 20.41 ms on the Coder file, one run each): about 0.43 ms a
  card. The hand-off between cards is cheap, also on x1 links.
- **In real work a round is 51.42 ms and yields 2.18 tokens** (my calc from E81's statement requests: 152,911 tokens
  generated in 3,605.4 s, 82,800 of 162,181 drafted tokens accepted, so 70,111 rounds of 3.31 rows).
- **Moving 23 GB of experts onto cards saved 2.63 ms a token [est.]:** the 2.23 ms between the 5-card and 7-card lines,
  plus the two extra cards' 0.87 ms spread over 2.18 tokens a round. The 20 GB still outside are picked less often
  than the 23 GB that moved (the engine places by pick count), so all remaining misses together cost less than that.
- **So misses are at most about 10.5 % of a generated token here (2.63 of 24.94 ms) [est.],** and a better hot set
  can win back only part of it. The other 89 % is the constant part: the cards' own compute, the fixed cost of a round,
  and the number of tokens a round yields.

**Two readings in the set-up notes that the article corrects.**

1. The notes say "the CPU lane did 0.1–0.9 % of the expert work". The article names this exact log line as a trap: it
   counts prompt reading too, where thousands of picks per turn all go to the cards; its own value was 0.1–0.9 % while
   generation ran at 8–15 % misses [article]. The line is in the engine's source [engine]. The share of misses in
   generation on the 7-GPU machine is therefore not known; the engine prints it per request (`vram_hit=`, `cpu=`,
   `pcie=`) [engine].
2. The notes put the limit at "the hand-off between cards", because the cards on x1 links showed 56–95 % busy. The
   Coder runs above price a card's hand-off at about 0.43 ms. The engine can print where a round's time goes
   (`DS4_ROUND_TIMES`, `DS4_PROF`) [engine]; that is the measurement to take before any other.

## 3. Finding by finding

Carries over: **yes**, **partly**, **no**. T = the teacher on the 7-GPU machine, R = the rig, S = the student's expert
cuts and the teacher's data run.

| # | The article's finding, with its numbers | T | R | S | Why |
|---:|---|---|---|---|---|
| 1 | Speed follows misses: GLM-5.3 Flash, 66 % of experts on the cards 36 tok/s, 78 % 45, 92 % 57 (a simulator on real routing traces) | partly | no | no | 85 % of the teacher's expert bytes are on the cards already (section 2). The rig holds every expert on a card |
| 2 | Measure the skew first. DeepSeek: the top 100 of 384 experts a layer take 70 % of picks, the top 200 89 %. Qwen3.8 Flash Next: 24 % of experts on a card give 74–79 % hits. GLM: the cold half still takes 41 %. MiniMax: placement by usage 64–69 % hits against 61 % at random. Rule of thumb: if a usage profile beats random by under 10 points, build on a live cache | yes | no | partly | The teacher is the strongly skewed model. For S, Flash-Next's skew on agent text is measured (sister repo Q232: 90 % of a layer's routings need a median of 242 of 512 experts) |
| 3 | Your traffic is your profile. Coverage of the top 180 of 384 on 68K tokens of real agent sessions: 94 % ranked on the same tokens, 86 % from earlier weeks of similar work, 86 % from synthetic sessions with real turn structure, 68 % from the profile shipped with the engine. By its placement model 51 % against 30 % of picks off the cards, about 36 against 42 tok/s by calculation | yes | no | yes | The teacher's pack carries the shipped profile [project]. For S it is the method of E3, with a number for what a wrong source costs |
| 4 | Placement rule: per card, experts by share of picks per byte, smoothed 0.9 × profile + 0.1 × uniform, one free slot a layer. Variants (no byte weighting, one shared budget) all within 1–2 % | no | no | no | Nothing to change: the rule is fine, the profile matters |
| 5 | Validate a profile on a later slice of traffic at the real memory budget, against the ideal and the shipped profile. A short profile looked better on itself (80.5 % with 64 experts against 57.6 %) and was worse on real sessions (68 % against 86 %) | yes | no | yes | E93 below |
| 6 | Profile traps: the engine adds counts on every run (freeze a copy per test arm); a profile may never be saved; a profile is mostly prompt reading (thousands of picks a turn against hundreds); one domain leaves experts with zero picks (a vision slice left 29 a layer unused, code and agent 0, the full corpus none); per-domain rankings differ (Spearman against the global ranking: agent 0.895, code 0.850, reasoning 0.818, knowledge 0.745, chat 0.713) | yes | no | yes | The engine writes counts back after each request and has a read-only switch [engine]. For S: E94 |
| 7 | A live cache beats any static set (MiniMax simulator: random 61 %, static 64–69 %, live with up to 8 swaps a token 87–93 %, perfect eviction 97–99 %). Short answers do not warm it (tool calls of 23–132 tokens: 71–76 % hits against 85–93 %). It makes output non-deterministic (1 of 99 answers equal at temperature 0). Less hysteresis was slower (36.4 against 39–40 tok/s) | partly | no | no | The teacher's engine has such a cache, on by default [engine]. Agent turns are short answers. Freeze it for quality checks |
| 8 | Warming the cache from the prompt: +21–24 % in a short test, zero in free generation, first token 0.3–1.9 s later | no | no | no | Do not try |
| 9 | Prefetching the "almost picked" experts of the last token did nothing (GLM). Predicting the next layer's routing from this layer's router input: top-8 catches 84–90 %. A copy takes longer than a layer, so it is a hint, not a prefetch, on PCIe 3.0 | no | no | no | Links here are slower still |
| 10 | Where to serve a miss. On DeepSeek and MiniMax the processor won: switching the copy path off for generation gave +17 % on DeepSeek. On GLM the copy won (24.9 → 45–46 tok/s). What decides: the processor's real cost in the build, and calibration under load, not at idle (0.6 ms at idle, 1.2–4.2 ms under load) | yes | no | no | A copy over an x1 link is est. 26 times dearer than the article's; see section 4 |
| 11 | A build flag made the processor path 3.6 times faster on Zen 2 (an instruction that runs in microcode there) | no | no | no | The machine's processor is Zen 3, where the instruction is native. The engine shipped the Zen 2 fix in a 0.2.4 point release [engine] |
| 12 | Memory bandwidth shows only when the processor computes misses: 4 → 8 channels gave +7–17 % on one card and nothing on two. How channels are populated matters more than the count; memory modules overheat without airflow (22.7 → 6.6 tok/s) | partly | no | no | With 20 GB outside the cards the processor's share is small. It matters for the machine's single-card presets |
| 13 | "Near memory": pinning threads near their memory channels was −10 to +3 %; threads on both hardware threads of a core were worse everywhere. The right thread count mattered: 46 threads on 48 cores 20–60 tok/s, 32 threads about 75 | partly | no | no | One memory node here. The thread count is a setting of the teacher's engine [engine] |
| 14 | More cards as a layer split: the second card gave +31–38 %, the third and fourth nothing for generation (118–129 tok/s on 2, 3 and 4 cards), only prompt reading grows (1,930 → 3,390 → 3,850 → 4,080 tok/s at 64K). Cards run one after another | partly | yes | no | Matches ours: 5 → 7 cards gained only through fewer misses. On the rig a card fewer is a hop fewer (sister repo Q964) |
| 15 | Tensor-parallel wins only with everything on the cards (GLM 48.3 → 66–68 tok/s); with offloading every rank waits for a miss. Expert-parallel in generation: −34 % | no | no | no | The engine refuses its tensor-parallel mode on this card set [project]; no peer-to-peer on either machine |
| 16 | Prompt reading: each chunk needs almost every expert of a layer (1,300 rows touch 70–80 % of the experts outside the cards), so all of them cross the links per chunk. A chunk of N rows touches an expert of pick share p with probability 1 − exp(−6·N·p). Larger chunks help long prompts (8192: +15 % at 128K, −7 % at 32K) | yes | no | yes | The teacher's reading speed follows the bytes outside the cards over slow links; section 4 |
| 17 | Its own engine work for reading: direct copies from pinned memory for every format (430 → 2,199 tok/s at 32K), idle cards' links used in parallel (a 1.5K re-read 42 % faster), card memory lent to prompt buffers | no | no | no | These are the author's builds. Not settings of the released engine |
| 18 | Reading was not bound by experts at long context on MiniMax (attention read its cache from host memory): profile before deciding | yes | yes | no | The rig's long prompts are attention-bound (sister repo Q163) |
| 19 | Speculative decoding on an offloaded MoE still wins, less: every extra row picks its own experts. Dense model on cards 2.75–3.62×; Flash-Next 1.44–1.46×; DeepSeek 1.2–1.4× | yes | yes | no | Ours: the drafter is worth about 29 % of generation [project]. The rig's rows are in the sister repo |
| 20 | Where acceptance is lost: the confidence cut-off (0.35 → 0.5 gave +8–15 % on one engine, 0.65 was worse); the draft vocabulary (a Cyrillic one took acceptance from 32 % to 54 % with no training); the model's own entropy at temperature 1 (Flash-Next picks its own top token in 79 % of positions, so no drafter gains more than +20 %); on DeepSeek the cut-off proposes 2.1–2.4 of 5 drafts and accepts 82–85 % of them, without it 3.21 tokens a round | yes | yes | yes | Ours: 2.31 drafts a round, 51 % accepted, 2.18 tokens a round (section 2). E99 is the entropy part |
| 21 | The main model's quant did not change acceptance (3.21 against 3.19 tokens a round) | — | yes | yes | Evidence for E31 |
| 22 | Fine-tuning drafters on one's own data never paid: +3.5 % speed (two thirds of it from the vocabulary change), and 3.17–3.20 against 3.215 tokens a round | — | yes | yes | Keeps the sister repo's Q572 parked; for a tuned student, change the draft's vocabulary before training a draft |
| 23 | Judge a drafter offline by simulating rounds in order, each starting at the last reject (within 1–2 % of the engine). Fixed anchors overstate (3.03 against 2.50 tokens a round). Compute the ceiling first, write the threshold before the run | — | yes | no | Proposed for the sister registry |
| 24 | Fewer bits put more experts on the cards. Flash-Next on two cards: IQ3_S 16,869 experts, code 164–166 tok/s, KL 0.144; UD-IQ4_XS 12,949, 146–149, 0.101; UD-Q4_K_XL 9,798, 117–119, 0.056. Models lose quality to quantization at very different rates (GLM at 2.05 / 3.05 / 4.05 bits KL 0.19 / 0.068 / 0.035, Flash-Next 0.068 / 0.018 / 0.0067) | no | no | yes | The teacher's file is fixed. For S: a base's tolerance to low bits has to be measured per base (E43) |
| 25 | KL and NLL do not catch garbage: a 1.62-bit DeepSeek file passed on logits and wrote nonsense in one language | — | — | yes | The bench stays the measure |
| 26 | Do not cut experts. Pick frequency against real importance (REAP): correlation −0.22 on GLM; router weight × input norm tracks REAP at 0.947 without running the experts. GLM cut to 108 of 288 by REAP: 19–22 of 25 tasks against 4–9 for frequency or random | — | — | yes | Our cuts so far are ranked by frequency. E91, E92 |
| 27 | Banning the experts that are not on a card: KL 0.372 with 34 % banned, 0.650 with 50 %, against 0.047 for the full 3.05-bit file and 0.121 for the full 2.05-bit file | no | no | no | Do not try. The sister repo's Q455 and Q468 stay parked |
| 28 | Merging removed experts into kept ones against plain pruning: output error 0.449 against 0.146 on one layer; mean cosine between GLM's experts 0.016 | — | — | yes | Against E5 as planned; E95 is the cheap check first |
| 29 | A cut against fewer bits: 1–1. Qwen3.6-35B-A3B with half its experts cut on code calibration scored 146 of 164 on HumanEval+, the same as the full Q4 and above the full Q2 (121). Laguna S 2.1 with half cut lost to the full Q2 (119 against 138) | — | — | yes | E4 already runs both at equal bytes for Flash-Next; E96 does it for the student's base |
| 30 | A cut saves memory, not time per token, while the model fits: on that Qwen3.6 cut prompt reading +25.7 %, generation +1.6 % | — | yes | yes | On the rig the memory saved becomes fewer cards (E96) |
| 31 | Fewer experts per token (MiniMax top-3 or top-2 of 4): NLL +46 % and up to +250 %, rejected | no | no | no | Ours: 5 of 6 on the teacher gave 41.2 against 40.1 tok/s and was not used [project]; the sister repo's Q6 says the same for Flint |
| 32 | Agent sessions are bound by generation, not reading: a live DeepSeek session of 295 turns: 2,903 s generating, 884 s reading (77 / 23); 243 new prompt tokens a turn at the median; 263 of 294 turns continue exactly; 4 reads from scratch took 24 % of all reading time | yes | yes | yes | Ours so far: 85.3 / 14.7 on statement requests (E81). Section 4 says why reading may weigh more in our sessions |
| 33 | What paid for sessions: the engine's prompt cache (2K added to 200K: 3.5–3.9 s against 121 s); never changing the prompt's start (0 % reused, 157 s for 196K); conversations kept in memory and on disk; preparing only the new part of a prompt (first event 1.2–2 s → 0.14 s) | yes | yes | yes | E98. The rig's side is in the sister registry (Q260, Q111, Q774) |
| 34 | A sampled model sometimes writes a token split the tokenizer would not (about 1 in 1,000); re-tokenized history then differs and a recurrent cache rolls back (30–54K tokens read again). Fix: match the prefix by text | — | yes | no | Found and fixed in the sister repo (Q260); the article confirms the cause on another engine |
| 35 | Loading: experts from NVMe in 45 s against 3.5–8 min from a SATA SSD; keep the page cache when memory allows; huge-page compaction can hang a large copy (one start took 12 min); with no swap a neighbour's memory use crashed the engine | partly | no | no | The teacher loads in about 4 minutes [project]. The neighbour point is why the model's machine runs only the model |
| 36 | How to measure: replay real sessions (A against A: 0.06 % on session time); decode only by free generation (forced answers overstate acceptance, 0.89–0.90 against 0.83–0.86); thresholds written first (0.5 % session, 1.5 % median read, 5 % decode); compare inside one A-B-A-B run; quality by bit-exactness where the math is kept, else a ruler from the stock engine's own spread | yes | yes | yes | E97 |
| 37 | Traps: a short test promised +27 %, free generation gave +2 %; synthetic prompts 42 tok/s, real sessions 26; a test with the cache off overstated the processor's share 2×; silent fallbacks (a drafter that quietly is not loaded); power caps mixed in one table (one card at a time: 220 → 350 W gave +78 %; all cards busy: nothing); another program on a card changed the cache size and the output; a forgotten monitor polling the driver cut generation to 11–20 tok/s; a leftover server measured instead of the new one; timing by stream chunks | yes | yes | yes | Section 4, and the rules of E97 |

## 4. What follows for the teacher (settings belong to the 7-GPU machine's own notes)

These are ideas about running the same model faster. They are listed here because E81 asks where the teacher's time
goes; each needs the maintainer's word for a speed test, and none is a result.

1. **Where a round's time goes, from the engine itself.** One real session with the engine's round and stage timers
   on, and the per-request counters read for generation alone. It settles both readings of section 2.
2. **Power caps.** In a layer split one card works at a time. During the machine's 47-minute stress test the first
   two cards were busy 9–13 % of the time and reported the power cap as a clock limit for 247 and 337 of 2,810 s
   [project]: about as long as they worked. The article's gain from watts equals the share of time spent computing,
   +78 % from 220 to 350 W with one card at a time [article]. A higher cap for this preset is the largest untested
   lever for generation [est.]. Two cards dropped off the bus under load on 2026-11-04, at these caps and on other
   slots, so a higher cap is the maintainer's call and needs the stress test again.
3. **Prompt reading over slow links.** A 1,340-token prompt took 14.5 s (92.5 tok/s) and an 18,968-token prompt
   59.3 s (319.9 tok/s) in E81's requests. Reading speed followed the bytes outside the cards: with 43.2 GB outside,
   an 8K prompt read at 109.0 and 111.3 tok/s; with 29.2 GB, at 187.3 and 173.4 [project]. By the article's formula a
   243-token turn still touches est. a third of the experts outside the cards. Three levers: faster links (a firmware
   setting holds every link at PCIe 2.0), fewer bytes outside the cards (E100), and the engine's threshold between its
   two prompt paths: below 96 new tokens the processor computes the experts it holds, above it they are streamed to
   the cards once per chunk, "the same on every box" (`DS4_PICK_MIN`) [engine]. The engine's makers measured the
   crossover at 120–140 tokens on a box with fast links; on x1 links it is est. far higher.
4. **A profile from our own sessions** in place of the shipped one, frozen, validated on later sessions (finding 5).
   Worth a part of section 2's 10.5 % for generation, and more for reading small turns [est.].
5. **The drafter's confidence cut-off,** swept on replayed sessions (`--dspark-conf`, and a cumulative cut that is off
   by default on these cards) [engine]. One earlier run at 0.3 gave 35.6 against 34.6 tok/s [project].
6. **The processor threads.** By default one expert thread per physical core (12) beside one host thread per card (7)
   [engine]. An earlier engine on this machine gained 3 % from keeping the two apart [project].
7. **Two conversations at once.** The engine's own table for four cards: one answer alone 41 tok/s, two together 53 in
   total, four together 73 [engine]. In a layer split the cards idle most of a token. It is E101, gated on the rule
   of one conversation at a time.

## 5. What follows for the student's expert cuts

- **The ranking.** The finished cuts (the sister repo's Q891, and E65) rank experts by how often they are picked. The
  article measured that score against importance at −0.22 on one model, and frequency-ranked cuts at the level of
  random ones. Flash-Next's mild cut held up (E65: 15 of 20 against 14 at seed 101), which fits: the bottom 64 of 512
  carry 0.39 % of agent routings. The deeper arms of E4 (384, 320, 256) are where the ranking decides. E91 reads the
  data in hand first; E92 adds the cheap score to E22.
- **The calibration text.** A ranking from one kind of text calls experts dead that another kind needs; our own
  Q891 lost general text the same way (wiki KLD 0.153 → 0.446 at 464 experts). Elixir agent sessions hold several
  kinds of text. E94 counts them apart; E93 validates on projects the ranking did not see.
- **Merging.** E5 plans to merge near-duplicate experts. On GLM the experts are almost orthogonal and merging was
  three times worse than pruning on one layer. The published results for Qwen models are closer (REAM 69.3 against
  REAP 68.5 on Qwen3-Next-80B, [survey](expert_pruning_survey.md)). E95 measures the similarity before any merge is
  built.
- **What a cut buys.** Memory, not time per token. On the rig memory becomes cards, and a card fewer is a hop fewer.
  E96 makes that the stated gain of a cut and tests the student's base cut against the same base at fewer bits.
- **The teacher is not cut.** The published half-cut of the teacher passed 12 of 20 bench cases against 16 for the
  uncut 1-bit file (one run each, E14).

## 6. What the article says does not work

So that none of it is tried here: warming the cache from the prompt (finding 8); prefetching "almost picked" experts
(9); pinning threads to near memory, or using both hardware threads of a core (13); a third and fourth card for
generation speed (14); tensor-parallel or expert-parallel generation with experts outside the cards (15); a "faster"
cache with less hysteresis (7); banning experts that are not on a card (27); merging experts on a model whose experts
are orthogonal (28); fewer experts per token (31); fine-tuning a drafter on one's own data (22); computing a chunk's
rare experts on the processor during prompt reading (re-read time −20–32 %, quality failed every threshold); a fused
prompt-reading path (+13 %, KL 0.053 against stock); a static hot set on a weakly skewed model (2); short tests as
evidence (37).

## 7. Rows

E91 to E102 in the [registry](../../../experiments.md). Ideas about running a model faster without changing it are
proposed to the sister repo's registry and to the 7-GPU machine's own notes, not listed here.
