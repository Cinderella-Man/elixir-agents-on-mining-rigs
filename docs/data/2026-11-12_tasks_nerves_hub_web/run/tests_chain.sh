#!/usr/bin/env bash
# tests_chain.sh: the factory's tests in the tooling image, without Docker and then with it, one after the other
# (test.sh unit, then test.sh docker); writes OUT/chain.done at the end.
# Environment: as test.sh (SRC, OUT, IMAGE, LABEL, HEX_CACHE_ID).
set -uo pipefail
RUN=$(cd "$(dirname "$0")" && pwd)
rm -f "$OUT/chain.done"
"$RUN/test.sh" unit
"$RUN/test.sh" docker
echo "unit $(cat "$OUT/unit.done") docker $(cat "$OUT/docker.done")" > "$OUT/chain.done"
