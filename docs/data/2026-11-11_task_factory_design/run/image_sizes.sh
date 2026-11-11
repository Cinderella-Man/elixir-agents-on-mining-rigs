#!/usr/bin/env bash
# Sizes of the bench's prepared images on the machine that holds them, by kind, from `docker images` alone.
# Docker counts shared layers in every image, so the sizes do not add up. Reads only.
#
# usage: bash image_sizes.sh     prints one line per kind (bench_images.tsv), then the saved database images by size
set -euo pipefail

docker images --format '{{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}' | grep -E '^elixir-agent-benchmark:' | python3 -c "
import re, statistics, sys
kinds = {}
for line in sys.stdin:
    tag, iid, size = line.rstrip('\n').split('\t')
    m = re.match(r'elixir-agent-benchmark:([a-z]+)-', tag)
    kind = m.group(1) if m else tag
    number = re.match(r'[0-9.e+]+', size).group(0)
    gb = float(number) * {'GB': 1, 'MB': 1e-3, 'kB': 1e-6, 'B': 1e-9}[size[len(number):]]
    kinds.setdefault(kind, {})[iid] = gb
for kind, images in sorted(kinds.items()):
    v = sorted(images.values())
    if len(v) >= 3:
        print(f'{kind}: {len(v)} distinct images; smallest {v[0]:.2f} GB, median {statistics.median(v):.2f} GB, '
              f'largest {v[-1]:.2f} GB')
"

docker images --format '{{.Repository}}:{{.Tag}}\t{{.Size}}' | grep -E 'snapshot|sealed' \
  | sed -E 's/[0-9a-f]{40,}/<id>/' | sort | uniq -c | sort -k3
