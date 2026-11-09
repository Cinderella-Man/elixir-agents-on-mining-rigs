# What the bench's published runs show about failures (2026-11-09)

A read of the Elixir SWE Bench's published results, with no new model run. It asks why attempts fail and how many
tokens a solved case costs. Registry row: [E14](../../../experiments.md).

**Result.** In the Pi series, most Flash-Next failures end at the 65,536-token generation budget, and heavier
compression of the same model goes with more tokens per solved case:

| Series (one run each, seed 101) | Passed | Failed | Failed at the budget | Failed below it | Passed at the budget | Tokens per passed case | Model calls per passed case |
|---|---:|---:|---:|---:|---:|---:|---:|
| DeepSeek-V4.1-Flash-1017, Unsloth UD-IQ1_M | 16 | 4 | 1 | 3 | 0 | 28,736 | 46.3 |
| DeepSeek-V4.1-Flash-1017, ISTA DASLab GSQ-RCO-Coder IQ2_XXS | 12 | 8 | 6 | 2 | 1 | 37,518 | 66.9 |
| Qwen3.8-Flash-Next, Agention Gyro-L TQ3_0 | 11 | 9 | 5 | 4 | 1 | 32,639 | 61.9 |
| Qwen3.8-Flash-Next, ISTA DASLab GSQ-RCO-Coder IQ1_M | 10 | 10 | 7 | 3 | 2 | 39,421 | 78.9 |
| Ornith-1.5-122B, Unsloth UD-Q5_K_XL | 7 | 13 | 4 | 9 | 1 | 32,334 | 76.9 |
| Ornith-1.5-122B, Unsloth UD-Q3_K_XL | 6 | 14 | 3 | 11 | 0 | 23,567 | 53.2 |
| Flint, Unsloth Q8_0 | 6 | 14 | 6 | 8 | 1 | 41,933 | 93.8 |

What follows from it:
- **The budget converts slow work into failures.** A local attempt stops at 65,536 generated tokens and its current
  patch is graded. 7 of the Coder's 10 failures and 5 of Gyro-L's 9 ended there. Whether those attempts were close to
  a fix is not in the published data (E15 reruns them with twice the budget).
- **The two DeepSeek files differ mostly in budget hits.** The 1-bit file failed 4 cases, 1 at the budget. The pruned
  2-bit Coder failed 8, 6 at the budget, and used 37,518 tokens per passed case against 28,736.
- **On the same solved cases the teacher writes far less.** On the 7 cases that DeepSeek UD-IQ1_M and both Flash-Next
  files passed, DeepSeek generated 111,533 tokens, Gyro-L 162,887 and the Flash-Next Coder 207,513
  ([common_passes.tsv](common_passes.tsv)).
- **Three cases set the ceiling for local models here.** No Pi series passed `ash-pr-3031`, `livebook-pr-2800` or
  `vutuv-pr-1759`.
- **One run of 20 cases cannot rank near neighbours.** The two Flash-Next files (10 and 11 passed) disagree on 7
  cases: the Coder alone passed 3, Gyro-L alone 4. The two Ornith-1.5-122B files (6 and 7) disagree on 5.

The hosted series ran in another harness with a declared, unenforced budget of 262,144 tokens, so their rows in
[series.tsv](series.tsv) are not comparable with the Pi rows.

## Files

| File | What it holds |
|---|---|
| [series.tsv](series.tsv) | one row per published series: passes, failures split at the budget, generated tokens, tokens and model calls per passed case |
| [cases.tsv](cases.tsv) | one row per attempt: model, file, harness, run, seed, case, passed, generated tokens, model calls, budget |
| [common_passes.tsv](common_passes.tsv) | generated tokens on the cases that DeepSeek UD-IQ1_M, Gyro-L and the Flash-Next Coder all passed |
| [run/extract.sh](run/extract.sh) | the `jq` script that made the three tables |

## Commands

```bash
curl -s -o results.json https://cinderella-man.github.io/elixir-swe-bench/results.json
RESULTS=results.json OUT=. bash run/extract.sh
```

## Provenance

- Source: the bench's published `results.json`, fetched 2026-11-09, sha256
  `2deea749af8c062ddca568014372fc291d247184911f327f6aba0239c63d9c02` (benchmark `elixir-agent-benchmark-v5`, 20 cases).
- That file names the Flash-Next Coder series `Qwen3.8-Flash-Next-GSQ-RCO`; the tables keep its spelling.
- "At the budget" means the attempt's generated tokens reached the series' generation budget (`settings.max_tokens`).
  Generated tokens include reasoning and tool-call syntax, as the bench counts them.
- The bench and its results are the work of [Cinderella-Man/elixir-swe-bench](https://github.com/Cinderella-Man/elixir-swe-bench).
- Licence: the tables and the script in this folder are under this repository's MIT licence.
