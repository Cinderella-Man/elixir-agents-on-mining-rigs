# Elixir agents on mining rigs

Old crypto-mining rigs with nine NVIDIA P106 cards (6 GB each, PCIe 1.0 x1, a 4 GB host) can run large language
models: [Miner Llama](https://github.com/Cinderella-Man/miner-llama) and the
[llms-on-crypto-mining-rigs](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs) guide run
Qwen3.8-Flash-Next at 2 bits (Swift GSQ-RCO Q2_0) at 20.40 tok/s in a realistic coding-agent session. This project asks a narrower question:

**Can a model that fits such a rig be as good as Qwen3.8-Flash-Next, or better, at agentic Elixir work, and still
be fast?**

Not an all-round model: a model that fixes real Elixir repositories inside a coding agent. The test is the
[Elixir SWE Bench](https://github.com/Cinderella-Man/elixir-swe-bench)
([results](https://cinderella-man.github.io/elixir-swe-bench/)): 20 historical pull requests from 12 public Elixir
projects. The Pi coding agent works in an isolated Docker workspace, and executable tests grade each fix. There is no
AI judge.

## Where things stand

The bench's published runs (cases passed of 20; one value per run):

| Model | File | Size | Passed |
|---|---|---:|---|
| Opus 5.5 | hosted | — | 18, 17, 18 |
| Sonnet 5.5 | hosted | — | 18, 18 |
| DeepSeek-V4.1-Flash-1017 | Unsloth UD-IQ1_M | 250,404,346,724 B | 16 |
| DeepSeek-V4.1-Flash-1017 | ISTA DASLab GSQ-RCO-Coder IQ2_XXS | 182,718,858,272 B | 12 |
| Qwen3.8-Flash-Next | Agention Gyro-L TQ3_0 | 108,312,517,120 B | 11 |
| Qwen3.8-Flash-Next | ISTA DASLab GSQ-RCO-Coder IQ1_M | 58,408,584,928 B | 10 |
| Ornith-1.5-122B | Unsloth UD-Q5_K_XL | 94,600,939,520 B | 7 |
| Ornith-1.5-122B | Unsloth UD-Q3_K_XL | 59,750,254,592 B | 6 |
| Flint | Unsloth Q8_0 | 42,295,606,400 B | 6 |

Two things follow:
- **The rig's Flash-Next files have no score yet:** Swift GSQ-RCO Q2_0 (the 20.40 tok/s line) and Swift
  Qwen3.8-Flash-Next Pascal Q2 GGUF (`pmix-q2-fast`). Scoring both is step one (E1), and the better one is the bar to
  beat.
- **A strong open teacher exists.** DeepSeek-V4.1-Flash-1017 solves 16 of 20 even at 1-bit, but it is far too large
  for a rig.

## Two ways to get there

1. **Shrink Qwen3.8-Flash-Next for Elixir** (no training). A mixture-of-experts model routes each token to a few of
   its experts, and Elixir agent work uses only part of them:
   - keep the experts Elixir sessions use;
   - merge experts that compute nearly the same thing;
   - drop layers that barely change the result;
   - trim the vocabulary to the tokens the work uses;
   - spend the bytes this frees on more bits per weight.

   Every cut is judged against the full-precision model on Elixir agent text, then on the bench.
2. **Teach a small, fast model from the teacher.** The teacher works through Elixir tasks mined from other projects'
   pull requests, and only sessions whose fixes pass the project's own tests are kept. A small mixture-of-experts model
   with about 3B active parameters learns from them. Such a model runs several times faster on the rig than
   Flash-Next.

The two can meet: prune Flash-Next, then repair what the cut lost with a short fine-tune on the teacher's sessions.

The plan, its order and its gates are in [docs/plan.md](docs/plan.md). Every idea, tried or not, has a row in
[experiments.md](experiments.md).

## What counts as a win

1. Any model, at any size or precision, that beats the rig's Flash-Next file on the bench, three seeds each. That
   alone shows the method works.
2. That model in a form that fits nine 6 GB cards.
3. That form fast on the rig, measured as time per task in a coding-agent session.

## The data behind every result

Each experiment publishes its tables, exact commands and scripts in `docs/data/<date>_<experiment>/`
([index](docs/data/README.md)).

## Licence

MIT, see [LICENSE](LICENSE). Model files and datasets keep their makers' licences.
