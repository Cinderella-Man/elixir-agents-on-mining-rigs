#!/usr/bin/env bash
# repro.sh: the workspace's `git add -A` outside the engine, in fresh containers from one workspace image IMAGE (the
# engine's own, as a check left it), with the limits of the engine's workspace container (no network, no
# capabilities, 4 GB, 2 CPUs, 512 processes) and the user agent. Three containers, one after another:
#   1. facts: the tracked files, the loose objects, and one file's stat data in the index against the file itself;
#   2. `git add -A` as the engine runs it, timed, with no time limit (LIMIT seconds at most, default 600);
#   3. `git update-index -q --refresh` first (it rereads the files' stat data into the index without writing
#      objects), then `git add -A`, both timed.
# Each container's output goes to OUT/repro_<n>.txt, with the load average and the time before and after.
# Environment: IMAGE, OUT, FILE (a tracked file for step 1), LABEL (pascal-quants=1), CPU_SHARES (256), LIMIT (600).
set -uo pipefail
: "${IMAGE:?}" "${OUT:?}" "${FILE:?}"
LABEL=${LABEL:-pascal-quants=1}
CPU_SHARES=${CPU_SHARES:-256}
LIMIT=${LIMIT:-600}
box() {
  docker run --rm --label "$LABEL" --cpu-shares "$CPU_SHARES" --network none --cap-drop ALL \
    --security-opt no-new-privileges --memory 4g --cpus 2 --pids-limit 512 --tmpfs /tmp:rw,nosuid,size=512m \
    -u agent -w /workspace -e FILE="$FILE" -e LIMIT="$LIMIT" "$IMAGE" bash -lc "$1"
}
stamp() { echo "== $(date -u +%FT%TZ) load $(cut -d' ' -f1-3 /proc/loadavg)"; }
{ stamp; box '
  echo "tracked files: $(git ls-files | wc -l)"
  git count-objects -v
  echo "== the index entry of $FILE"; git ls-files --debug -- "$FILE"
  echo "== the file"; stat -c "ctime: %Z  mtime: %Y  dev: %d  ino: %i  uid: %u  gid: %g  size: %s" "$FILE"
  echo "== git diff-files (stat only): entries whose stat data differ"; git diff-files --name-only | wc -l
'; stamp; } > "$OUT/repro_1.txt" 2>&1
{ stamp; box 'start=$(date +%s.%N); timeout "$LIMIT" git add -A; rc=$?; end=$(date +%s.%N)
  echo "git add -A: exit $rc, $(awk "BEGIN {printf \"%.1f\", $end - $start}") s"'; stamp; } > "$OUT/repro_2.txt" 2>&1
{ stamp; box 'start=$(date +%s.%N); git update-index -q --refresh; rc=$?; mid=$(date +%s.%N)
  timeout "$LIMIT" git add -A; rc2=$?; end=$(date +%s.%N)
  echo "git update-index -q --refresh: exit $rc, $(awk "BEGIN {printf \"%.1f\", $mid - $start}") s"
  echo "then git add -A: exit $rc2, $(awk "BEGIN {printf \"%.1f\", $end - $mid}") s"'; stamp; } > "$OUT/repro_3.txt" 2>&1
echo done > "$OUT/repro.done"
