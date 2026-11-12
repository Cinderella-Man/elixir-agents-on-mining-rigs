#!/usr/bin/env bash
# Job P3 for podlove/radiator, end to end, run on the machine with Docker and the installed controller image.
# Environment: JOB (a folder of this job's own, holding these scripts and the recipe), WORK (the folder of a controller
# of this job's own; its data is WORK/NAME/data), NAME (the controller's name; default factory-radiator), EPMD_PORT
# (Erlang's port mapper for it; must differ from any other controller's; default 4456), RUN (the folder with
# controller.sh and docker_shim.sh from docs/data/2026-11-12_pilot_controller/run/), CANDIDATES (candidates_first.tsv
# of 2026-11-12_pilot_pr_screen), CENSUS (prs_podlove__radiator.tsv of 2026-11-11_pilot_pr_census).
# STEPS: which parts to run (default "periods pull probe prepare tests tables").
set -euo pipefail
: "${JOB:?}" "${WORK:?}" "${RUN:?}" "${CANDIDATES:?}" "${CENSUS:?}"
export NAME=${NAME:-factory-radiator} EPMD_PORT=${EPMD_PORT:-4456} WORK RUN
STEPS=${STEPS:-periods pull probe prepare tests tables}
NUMBER=647
cd "$JOB"
DATA=$WORK/$NAME/data
has() { case " $STEPS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
[ -e df_before.txt ] || df -BG / | tail -n 1 > df_before.txt

# 1. The periods: the toolchain of each starting commit of the first 30 candidates (radiator has 19).
if has periods; then
  [ -d radiator.git ] || git clone -q --bare --filter=blob:none https://github.com/podlove/radiator.git radiator.git
  awk -F'\t' '$1=="podlove/radiator" && $2<=30 {print $3}' "$CANDIDATES" > nums.txt
  awk -F'\t' 'NR==FNR{n[$1]=1;next} ($1 in n){print $1"\t"$2"\t"$10}' nums.txt "$CENSUS" | sort -k1,1nr > merges.tsv
  GIT_DIR=radiator.git ./periods.sh < merges.tsv > periods_raw.tsv
fi

# 2. The Elixir image the recipe pins (Postgres 18.6 was already on the machine by the same digest).
if has pull; then
  docker pull --quiet hexpm/elixir:1.20.3-erlang-29.0.5-ubuntu-noble-20260810
  docker pull --quiet postgres:18.6-alpine
fi

# 3. The probe task for the newest candidate of the newest period, staged where the controller sees it.
if has probe; then
  merge=$(awk -F'\t' -v n=$NUMBER '$1==n{print $3}' merges.tsv)
  merged=$(awk -F'\t' -v n=$NUMBER '$1==n{print $2}' merges.tsv)
  rm -rf probe && mkdir probe
  GIT_DIR=radiator.git RECIPE=podlove__radiator.json REPO=podlove/radiator PROJECT=radiator NUMBER=$NUMBER \
    MERGE="$merge" MERGED_AT="$merged" OUT=probe/radiator-pr-$NUMBER ./make_probe.sh
  mkdir -p "$DATA/p3/probe"
  rm -rf "$DATA/p3/probe/radiator-pr-$NUMBER"
  cp -r probe/radiator-pr-$NUMBER "$DATA/p3/probe/"
  cp prepare.exs tests.exs "$DATA/p3/"
fi

# 4. Preparation and the two test rounds through the controller, each in a process of its own; wait on the markers.
if has prepare || has tests; then
  rm -f watch.stop
  OUT=$JOB/labels.txt STOP=$JOB/watch.stop setsid nohup ./watch_labels.sh > /dev/null 2>&1 < /dev/null &
  "$RUN/controller.sh" up
  trap 'touch "$JOB/watch.stop"; "$RUN/controller.sh" down' EXIT
  if has prepare; then
    rm -f "$DATA/p3/prepare.done"
    date -u +%FT%TZ > prepare_start.txt
    "$RUN/controller.sh" rpc 'spawn(fn -> Code.eval_file("/data/p3/prepare.exs") end)'
    until [ -e "$DATA/p3/prepare.done" ]; do sleep 30; done
    cat "$DATA/p3/prepare.done"
    grep -q '^ok' "$DATA/p3/prepare.done" || exit 1
  fi
  if has tests; then
    rm -f "$DATA/p3/tests.done"
    "$RUN/controller.sh" rpc 'spawn(fn -> Code.eval_file("/data/p3/tests.exs") end)'
    until [ -e "$DATA/p3/tests.done" ]; do sleep 10; done
    cat "$DATA/p3/tests.done"
  fi
fi

# 5. The per-test table of both rounds, and the cost.
if has tables; then
  { printf 'test\tround1\tround2\n'
    jq -r --slurpfile b "$DATA/p3/tests_round2.json" \
      '.tests | to_entries[] | [.key, .value, $b[0].tests[.key]] | @tsv' "$DATA/p3/tests_round1.json" | sort; } > tests.tsv
  docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}' | grep -E '^elixir-agent-benchmark:' > images.txt
  df -BG / | tail -n 1 > df_after.txt
fi
