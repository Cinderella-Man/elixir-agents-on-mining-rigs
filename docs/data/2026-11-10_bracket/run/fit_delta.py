#!/usr/bin/env python3
"""Memory per card for a cut file, from a measured load of its uncut source and the two files' headers, on the CPU.
  python3 -I fit_delta.py --measured 20802,21370,21412 --total 24576 SOURCE_LAYERS.tsv CUT_LAYERS.tsv
SOURCE_LAYERS.tsv and CUT_LAYERS.tsv are `split_plan.py --layers` outputs (the sister repo's scripts/split_plan.py:
each block's MiB and the output layer, from the GGUF headers). --measured is the source's MiB on each card after
loading at the same settings (serve.sh's fit.txt). llama.cpp's default split (no -ts) puts layer il on the first card
whose share of the free memory, summed, exceeds il / (n_layer + 1), the output layer last; with equal free memory the
cut file gets the same layers per card, and its KV cache, recurrent state and compute buffers are the source's (same
architecture, window and batch). So each card's projection is the source's measured MiB less the weight MiB the cut
removed from that card's layers. --free gives each card's free MiB before the load if they differ (default equal).
Prints one row per card: layers, source and cut weight MiB, the measured and projected MiB, and the MiB left free.
Standard library only.
"""
import argparse, bisect


def read_layers(path):
    blocks, output = [], 0.0
    with open(path) as f:
        next(f)
        for line in f:
            cols = line.rstrip("\n").split("\t")
            if cols[0] == "output":
                output = float(cols[2])
            else:
                blocks.append(float(cols[2]))
    return blocks, output


def default_split(n_layer, free):
    cum, s = [], 0.0
    for v in free:
        s += v
        cum.append(s)
    cum = [c / s for c in cum]
    act = n_layer + 1  # -ngl 99: every block plus the output layer
    return [bisect.bisect_right(cum, il / act) for il in range(act)]  # card of each block, then the output's


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("cut")
    ap.add_argument("--measured", required=True, help="the source's MiB on each card after loading")
    ap.add_argument("--total", type=float, default=24576.0, help="each card's memory, MiB")
    ap.add_argument("--free", help="free MiB per card before the load (default equal)")
    a = ap.parse_args()
    src, src_out = read_layers(a.source)
    cut, cut_out = read_layers(a.cut)
    assert len(src) == len(cut), "the two files have different layer counts"
    measured = [float(v) for v in a.measured.split(",")]
    n = len(measured)
    free = [float(v) for v in a.free.split(",")] if a.free else [1.0] * n
    dev = default_split(len(src), free)
    print("card\tlayers\tsource_weights_mib\tcut_weights_mib\tmeasured_mib\tprojected_mib\tfree_mib")
    for c in range(n):
        idx = [il for il in range(len(src)) if dev[il] == c]
        s = sum(src[il] for il in idx) + (src_out if dev[-1] == c else 0.0)
        k = sum(cut[il] for il in idx) + (cut_out if dev[-1] == c else 0.0)
        proj = measured[c] - (s - k)
        span = f"{idx[0]}-{idx[-1]}" + ("+output" if dev[-1] == c else "") if idx else "-"
        print(f"{c}\t{span}\t{s:.1f}\t{k:.1f}\t{measured[c]:.0f}\t{proj:.0f}\t{a.total - proj:.0f}")
    print(f"total\t\t{sum(src) + src_out:.1f}\t{sum(cut) + cut_out:.1f}\t{sum(measured):.0f}\t"
          f"{sum(measured) - (sum(src) + src_out - sum(cut) - cut_out):.0f}\t")


if __name__ == "__main__":
    main()
