# Pruning and the lottery ticket hypothesis (2026-11-09)

What removing weights can save on a P106 rig, and whether lottery tickets help. This comes from the read of
[Linear programming for weight-space programming](https://nathan.rs/posts/weight-space-lp/); the post itself (an LP
that picks the fewest weights to *change* to stop reasoning loops) is covered in
[weight_space_lp.md](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/research/notes/weight_space_lp.md).

## 1. Reading fewer bytes: pruning

**The idea has an older form.** The LP's pattern, "the fewest nonzeros such that the outputs stay within ε on real
inputs", is a pruning method from 2017: [Net-Trim](https://arxiv.org/abs/1611.05162) (Aghasi et al., NeurIPS 2017)
minimizes each layer's L1 norm subject to its outputs staying close on training data. It was shown on MNIST-sized
networks.

**On a P106, only patterns the kernel can skip save bytes:**
- whole experts;
- whole channels (an expert's intermediate neurons: rows of gate and up, columns of down);
- whole quantization blocks.

**Unstructured sparsity pays for its index.** A bitmap costs 1 bit per weight, so at b bits a weight and sparsity s
the cost is 1 + (1 − s) · b bits. That saves bytes only when s > 1/b:
- above 50 % sparsity at 2 bits;
- above 18 % at 5.5 bits (Q5_K).

Pascal also has no sparse tensor cores.

**At equal bytes, quantizing beats pruning down to about 3 bits:**
- [Zhou et al., EMNLP Findings 2025](https://aclanthology.org/2025.findings-emnlp.645/): quantization keeps more than
  pruning on small models.
- [arXiv 2607.16721](https://arxiv.org/abs/2607.16721) (July 2026) on Qwen3.6-35B-A3B and Gemma-4-26B-A4B: half the
  experts can go with no detectable loss on the code benchmark, and the damage lands outside coding. Pruning wins only
  where quantizing would drop below 3 bits a weight. Flash-Next at 2 bits is in that regime.
- The mining-rigs registry agrees. In its Q891, IQ3_S cut to 416 experts beat IQ3_XXS on agent text (0.131 against 0.176) and code
  (0.043 against 0.054) but lost on wiki (0.724 against 0.248).
- The LP's way of choosing would apply to expert cuts too: minimize the experts kept, subject to each agent-text
  token's routed output staying within ε. It is a cheaper cousin of Q898's searched expert set and is parked with it
  (Q1142).

**Activation sparsity skips weights per token instead of removing them.**
[TEAL](https://arxiv.org/abs/2408.14690) (ICLR 2025) reaches 40–50 % sparsity across the whole model without training,
with decode speed-ups of up to 1.53× at 40 % and 1.8× at 50 % on GPUs. It is Q622 in the mining-rigs registry, planned. My files store quant blocks
along the input dimension, so skipping input columns needs a column-major layout, and a k-token verify pass reads the
union of the active columns.

## 2. The lottery ticket hypothesis (Frankle and Carbin, ICLR 2019)

**What it says.** A dense, randomly initialized network contains a subnetwork that, trained alone from the same
initial values, matches the full network's accuracy in at most the same number of steps. That subnetwork is the
"winning ticket". Finding one:
- train;
- prune the smallest weights (20 % per round for the fully connected layers);
- reset the survivors to their initial values;
- repeat.

On MNIST and CIFAR-10 (Lenet, Conv-2/4/6, VGG-19, ResNet-18), the tickets are at most 10–20 % of the original size.
Given fresh random initial values instead, they do far worse. For VGG-19 and ResNet-18, tickets appeared only at the
lower learning rate or with warmup.

**Why it doesn't help the rig:**
1. It is a training method: each ticket costs several full training runs of the dense network. I don't train Flint,
   Flash-Next or Ornith, and a pretraining run at their size is out of reach. For larger networks, the authors' later
   work rewinds to an early training checkpoint instead of the initial values, which still needs that training run.
2. Its tickets are unstructured, so the bitmap arithmetic in section 1 applies. At 2 bits there is no byte saving
   below 50 % sparsity, and Pascal has no sparse kernels.
3. Its practical heir for language models is one-shot pruning of trained models (SparseGPT, Wanda), and the
   registry covers that pruning in its structured forms (section 1).

**Where it could apply** is a network I train myself: the drafter heads (the mining-rigs registry's Q20) and the fine-tuning work. But a head
reads est. 0.19 GB a guess, and what limits it on the P106 is its launches (the mining-rigs registry's Q20 and its book, chapter 8), not its bytes. A
narrower dense head is a plain training choice, not a ticket. Parked as Q1141. It reopens with a kernel that skips
whole quant blocks, where a block-level ticket would read fewer bytes, or with a trained network whose cost is its
bytes.

## Sources

- Aghasi, Abdi, Nguyen, Romberg, Net-Trim (NeurIPS 2017): https://arxiv.org/abs/1611.05162
- Zhou et al., Revisiting Pruning vs Quantization for Small Language Models (EMNLP Findings 2025):
  https://aclanthology.org/2025.findings-emnlp.645/
- Jha, Half the Experts, All the Code (2026): https://arxiv.org/abs/2607.16721
- Liu et al., TEAL: Training-Free Activation Sparsity in Large Language Models (ICLR 2025):
  https://arxiv.org/abs/2408.14690
- Frankle, Carbin, The Lottery Ticket Hypothesis (ICLR 2019): https://arxiv.org/abs/1803.03635
