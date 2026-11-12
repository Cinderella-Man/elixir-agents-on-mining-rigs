#!/usr/bin/env bash
# prove_all.sh: for each "elixir otp" line of PAIRS, the image lookup (lookup.sh pair) and, when one is found, the
# three proofs (prove.sh), one pair at a time, so at most one image is pulled at a time. Before each pair it waits
# while a container runs that is neither the factory's (label task-factory=1, or a name that starts with "etf-") nor
# the bench's standing service (BENCH_SERVICE), since that may be a bench run; it stops when the free space on / is
# under MIN_FREE bytes.
# Environment: SRC (the factory folder), PAIRS, OUT, LABEL, CA (prove.sh's, default apt), BENCH_SERVICE (elixir-swe-bench-benchmark-1), MIN_FREE
# (700000000000). Writes OUT/lookup.tsv, OUT/proofs.tsv, OUT/prove_all.log, and OUT/prove_all.done when it ends.
set -uo pipefail
: "${SRC:?}" "${PAIRS:?}" "${OUT:?}" "${LABEL:?}"
RUN=$(cd "$(dirname "$0")" && pwd)
BENCH_SERVICE=${BENCH_SERVICE:-elixir-swe-bench-benchmark-1}
MIN_FREE=${MIN_FREE:-700000000000}
mkdir -p "$OUT"
rm -f "$OUT/prove_all.done"
: > "$OUT/lookup.tsv"
: > "$OUT/proofs.tsv"
say() { printf '%s %s\n' "$(date -Is)" "$*" >> "$OUT/prove_all.log"; }
others() {
  docker ps --format '{{.Names}}\t{{.Label "task-factory"}}' |
    awk -F'\t' -v b="$BENCH_SERVICE" '$2 != "1" && $1 != b && $1 !~ /^etf-/ {print $1}'
}
rc=0
while read -r elixir otp; do
  [ -n "$elixir" ] || continue
  while [ -n "$(others)" ]; do
    say "waiting: other containers run: $(others | tr '\n' ' ')"
    sleep 60
  done
  free=$(df -B1 --output=avail / | tail -n 1 | tr -d ' ')
  if [ "$free" -lt "$MIN_FREE" ]; then
    say "stopped: free space on / is $free bytes, under $MIN_FREE"
    rc=3
    break
  fi
  say "pair $elixir/$otp (free $free bytes)"
  line=$(SRC=$SRC "$RUN/lookup.sh" pair "$elixir" "$otp" 2>> "$OUT/prove_all.log")
  printf '%s\n' "$line" >> "$OUT/lookup.tsv"
  if [ "$(printf '%s' "$line" | cut -f3)" = found ]; then
    image=$(printf '%s' "$line" | cut -f4 | jq -r .image)
    OUT=$OUT LABEL=$LABEL CA=${CA:-apt} "$RUN/prove.sh" "$elixir" "$otp" "$image" >> "$OUT/proofs.tsv"
    say "proved $(tail -n 1 "$OUT/proofs.tsv" | cut -f4-)"
  fi
done < "$PAIRS"
free=$(df -B1 --output=avail / | tail -n 1 | tr -d ' ')
say "end (free $free bytes)"
echo "$rc" > "$OUT/prove_all.done"
