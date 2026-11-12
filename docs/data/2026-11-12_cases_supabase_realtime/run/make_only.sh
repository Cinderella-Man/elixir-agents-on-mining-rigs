#!/usr/bin/env bash
# make_only.sh: the bundle maker alone for each number of NUMBERS, one at a time, through a running controller
# (make_one.exs: the task folder, the source check and the import check). No preparation, no check, no container:
# used for the pull requests after the first when the project's environment cannot be prepared, so that each one's
# folder, Elixir/OTP pair and task kind are still recorded. The folders stay in the controller's data
# (CTL/data/LIST/tasks/); none is imported or exported.
# Environment: CTL (the controller's folder; data in CTL/data, staged by all.sh stage), NAME (the controller), LIST
# (realtime), NUMBERS (a file, one number per line), REPOSITORY, PREFIX (realtime: the maker names a task after the
# repository), CENSUS, SCREEN (file names in CTL/data/LIST/tables), OUT (where each one's maker files are copied,
# OUT/<id>/).
# Writes OUT/make_only.tsv: number, id, result, reason, start_revision, elixir_otp, task_kind, hidden_tests,
# source_check, import, make_ms, verify_ms, wall_s, load_start, load_end, free_before, free_after.
set -euo pipefail
: "${CTL:?}" "${NAME:?}" "${LIST:?}" "${NUMBERS:?}" "${REPOSITORY:?}" "${PREFIX:?}" "${CENSUS:?}" "${SCREEN:?}" "${OUT:?}"
P=$CTL/data/$LIST
rpc() { printf '%s\n' "$1" | docker exec -i "$NAME" sh -c 'IFS= read -r c; exec bin/factory rpc "$c"'; }
free_b() { df --output=avail -B1 / | tail -1 | tr -d ' '; }
load1() { cut -d' ' -f1 /proc/loadavg; }
mkdir -p "$OUT"
printf 'number\tid\tresult\treason\tstart_revision\telixir_otp\ttask_kind\thidden_tests\tsource_check\timport\tmake_ms\tverify_ms\twall_s\tload_start\tload_end\tfree_before\tfree_after\n' \
  > "$OUT/make_only.tsv"
for n in $(cat "$NUMBERS"); do
  id=$PREFIX-pr-$n
  o=$OUT/$id
  rm -rf "$o"; mkdir -p "$o"
  l0=$(load1); f0=$(free_b); t0=$(date +%s)
  rm -f "$P/out/$n/make.done"
  rpc "System.put_env(%{\"P5_DIR\" => \"/data/$LIST\", \"NUMBER\" => \"$n\", \"REPOSITORY\" => \"$REPOSITORY\", \"CENSUS\" => \"$CENSUS\", \"SCREEN\" => \"$SCREEN\"}); spawn(fn -> Code.eval_file(\"/data/$LIST/make_one.exs\") end)" > /dev/null
  until [ -e "$P/out/$n/make.done" ]; do sleep 2; done
  wall=$(($(date +%s) - t0))
  cp -a "$P/out/$n/." "$o/"
  m() { awk -F'\t' -v c="$1" 'NR == 1 {for (i = 1; i <= NF; i++) k[$i] = i} NR == 2 {print (c in k ? $k[c] : "-")}' "$o/make.tsv" 2>/dev/null || echo -; }
  v() { awk -F'\t' -v c="$1" 'NR == 1 {for (i = 1; i <= NF; i++) k[$i] = i} NR == 2 {print (c in k ? $k[c] : "-")}' "$o/verify.tsv" 2>/dev/null || echo -; }
  printf '%s\t' "$n" "$id" "$(m result)" "$(m reason)" "$(m start_revision)" "$(m toolchain)" "$(m task_kind)" "$(m hidden_tests)" \
    "$(v source_check)" "$(v import | cut -d' ' -f1)" "$(v make_ms)" "$(v verify_ms)" "$wall" "$l0" "$(load1)" "$f0" >> "$OUT/make_only.tsv"
  free_b >> "$OUT/make_only.tsv"
  echo "$(date -Is) $id: $(m result) $(m reason) $(m toolchain) $(m task_kind)"
done
date -Is > "$OUT/make_only.done"
