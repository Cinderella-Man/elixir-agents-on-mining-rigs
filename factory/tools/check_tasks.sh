#!/usr/bin/env bash
# The licence scan and the hold-out check on a list of factory task folders (factory/tools/README.md).
#
#   WORK=<scratch and output folder> CLONES="<git dir> ..." [BENCH_CASES=<the bench's cases/ folder>] \
#   [HEX_FETCH=1] [IMAGE=python:3.12-slim-bookworm] [DOCKER_RUN_ARGS="--cpu-shares 256"] \
#     factory/tools/check_tasks.sh TASK_DIR_OR_FOLDER_OF_TASKS [...]
#
# On the host it needs git, tar, docker and (for HEX_FETCH=1) curl. It reads the clones and never writes to them:
# each commit's tree is checked out through a temporary index file in WORK. Python runs only in a container with
# no network; the one network step, HEX_FETCH=1, runs curl on the host and fetches the first 1 MiB of each locked
# Hex package's tarball (enough for its metadata.config), once per package and version.
#
# Writes in WORK: revisions.tsv; trees/<commit>/ and trees/<commit>.{licence.json,scan.tsv,scan.json};
# licence.{files,tasks,commits}.tsv; locks.tsv; hex/; deps.tsv; holdout.{hits.tsv,tasks.tsv,json} (when
# BENCH_CASES is set; LOCAL_SPANS=<file> also writes the shared spans' text there, for reading only).
set -euo pipefail

: "${WORK:?set WORK}"
: "${CLONES:?set CLONES to one or more git directories that hold the commits of the tasks}"
IMAGE=${IMAGE:-python:3.12-slim-bookworm}
DOCKER_RUN_ARGS=${DOCKER_RUN_ARGS:---cpu-shares 256}
HEX_REPO=${HEX_REPO:-https://repo.hex.pm}
TOOLS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
HOLDOUT=${HOLDOUT:-$TOOLS/../config/holdout.json}
HOLDOUT=$(cd "$(dirname "$HOLDOUT")" && pwd)/$(basename "$HOLDOUT")
[ $# -gt 0 ] || { echo "usage: $0 TASK_DIR_OR_FOLDER [...]" >&2; exit 2; }
mkdir -p "$WORK/trees" "$WORK/hex"
WORK=$(cd "$WORK" && pwd)

TASKS=()
for t in "$@"; do TASKS+=("$(cd "$t" && pwd)"); done

# every path the container reads is mounted at its own path
MOUNTS=(-v "$TOOLS:$TOOLS:ro" -v "$WORK:$WORK" -v "$HOLDOUT:$HOLDOUT:ro")
for t in "${TASKS[@]}"; do MOUNTS+=(-v "$t:$t:ro"); done
[ -n "${BENCH_CASES:-}" ] && { BENCH_CASES=$(cd "$BENCH_CASES" && pwd); MOUNTS+=(-v "$BENCH_CASES:$BENCH_CASES:ro"); }

py() {
  # shellcheck disable=SC2086
  docker run --rm --network none $DOCKER_RUN_ARGS -u "$(id -u):$(id -g)" -w "$WORK" "${MOUNTS[@]}" \
    "$IMAGE" "$@"
}

echo "== revisions"
py python -I "$TOOLS/task_folder.py" revisions "${TASKS[@]}" > "$WORK/revisions.tsv"
COMMITS=$(tail -n +2 "$WORK/revisions.tsv" | cut -f3,4 | tr '\t' '\n' | grep -E '^[0-9a-f]{40}$' | sort -u)

echo "== trees"
for c in $COMMITS; do
  [ -f "$WORK/trees/$c/.checked-out" ] && continue
  g=""
  for cl in $CLONES; do
    if git --git-dir="$cl" cat-file -e "$c^{commit}" 2>/dev/null; then g=$cl; break; fi
  done
  [ -n "$g" ] || { echo "no clone holds $c" >&2; exit 1; }
  rm -rf "$WORK/trees/$c" && mkdir -p "$WORK/trees/$c"
  GIT_INDEX_FILE="$WORK/trees/$c.index" git --git-dir="$g" read-tree "$c"
  GIT_INDEX_FILE="$WORK/trees/$c.index" git --git-dir="$g" --work-tree="$WORK/trees/$c" checkout-index -a -f
  rm -f "$WORK/trees/$c.index"
  touch "$WORK/trees/$c/.checked-out"
done

echo "== licence scan per tree"
# shellcheck disable=SC2086
py python -I "$TOOLS/task_licence.py" scan-trees --trees "$WORK/trees" $COMMITS

echo "== licence per task"
py python -I "$TOOLS/task_licence.py" join --trees "$WORK/trees" --out "$WORK/licence" "${TASKS[@]}"

echo "== dependencies"
py python -I "$TOOLS/task_licence.py" locks --trees "$WORK/trees" --out "$WORK/locks.tsv" "${TASKS[@]}"
if [ "${HEX_FETCH:-0}" = 1 ]; then
  tail -n +2 "$WORK/locks.tsv" | awk -F'\t' '$1=="hex"{print $2"\t"$3}' | while IFS=$'\t' read -r p v; do
    f="$WORK/hex/$p-$v.head"
    [ -s "$f" ] && continue
    # the repository may ignore the byte range; head stops the transfer after 1 MiB either way
    { curl -sSf -A "task-licence-check" -r 0-1048575 "$HEX_REPO/tarballs/$p-$v.tar" 2>/dev/null || true; } \
      | head -c 1048576 > "$f.part" || true
    if [ -s "$f.part" ]; then mv "$f.part" "$f"; else echo "fetch failed: $p $v" >&2; rm -f "$f.part"; fi
  done
fi
py python -I "$TOOLS/task_licence.py" deps --locks "$WORK/locks.tsv" --hex "$WORK/hex" --out "$WORK/deps"

if [ -n "${BENCH_CASES:-}" ]; then
  echo "== hold-out"
  extra=()
  [ -n "${LOCAL_SPANS:-}" ] && extra=(--local-spans "$LOCAL_SPANS")
  py python -I "$TOOLS/task_holdout.py" --bench "$BENCH_CASES" --holdout "$HOLDOUT" --trees "$WORK/trees" \
    --out "$WORK/holdout" "${extra[@]}" "${TASKS[@]}"
fi
echo "== done"
