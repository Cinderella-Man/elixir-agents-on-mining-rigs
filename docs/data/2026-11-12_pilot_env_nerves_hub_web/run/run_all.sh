#!/usr/bin/env bash
# Job P3 for nerves-hub/nerves_hub_web, end to end, run on the machine with Docker and the installed controller image.
# Environment: JOB (a folder of this job's own, holding these scripts and the recipe), WORK (the folder of a controller
# of this job's own; its data is WORK/NAME/data), NAME (the controller's name; default factory-nhw), EPMD_PORT
# (Erlang's port mapper for it; must differ from any other controller's; default 4459), RUN (the folder with
# controller.sh and docker_shim.sh from docs/data/2026-11-12_pilot_controller/run/), SCREEN
# (screen_nerves-hub__nerves_hub_web.tsv of 2026-11-12_pilot_pr_screen), CENSUS (prs_nerves-hub__nerves_hub_web.tsv.gz
# of 2026-11-11_pilot_pr_census).
# STEPS: which parts to run (default "periods pull probe prepare tests stub tables").
set -euo pipefail
: "${JOB:?}" "${WORK:?}" "${RUN:?}" "${SCREEN:?}" "${CENSUS:?}"
export NAME=${NAME:-factory-nhw} EPMD_PORT=${EPMD_PORT:-4459} WORK RUN
STEPS=${STEPS:-periods pull probe prepare tests stub tables}
NUMBER=3155
ID=nerves-hub-web-pr-$NUMBER
COMMAND="mix test --exclude mtools"
cd "$JOB"
DATA=$WORK/$NAME/data
has() { case " $STEPS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
[ -e df_before.txt ] || df -BG / | tail -n 1 > df_before.txt

# 1. The periods: the toolchain of the starting commit of every candidate (705), from a full bare clone.
if has periods; then
  [ -d nhw-full.git ] || git clone -q --bare https://github.com/nerves-hub/nerves_hub_web.git nhw-full.git
  awk -F'\t' 'NR>1 && $4=="candidate" {print $1}' "$SCREEN" > nums.txt
  zcat -f "$CENSUS" | awk -F'\t' 'NR==FNR{n[$1]=1;next} ($1 in n){print $1"\t"$2"\t"$10}' nums.txt - | sort -k1,1nr > merges.tsv
  GIT_DIR=nhw-full.git ./periods.sh < merges.tsv > periods_raw.tsv
fi

# 2. The images the recipe pins. The Elixir image and Postgres 18.6 were already on the machine.
if has pull; then
  docker pull --quiet hexpm/elixir:1.20.3-erlang-29.0.5-ubuntu-noble-20260810
  docker pull --quiet postgres:18.6-alpine
  docker pull --quiet clickhouse/clickhouse-server:25.4.2.31
fi

# 3. The probe task for the newest candidate of the period with the most candidates, staged for the controller.
if has probe; then
  merge=$(awk -F'\t' -v n=$NUMBER '$1==n{print $3}' merges.tsv)
  merged=$(awk -F'\t' -v n=$NUMBER '$1==n{print $2}' merges.tsv)
  rm -rf probe && mkdir probe
  GIT_DIR=nhw-full.git RECIPE=nerves-hub__nerves_hub_web.json REPO=nerves-hub/nerves_hub_web PROJECT=nerves-hub-web \
    NUMBER=$NUMBER MERGE="$merge" MERGED_AT="$merged" LICENCE=Apache-2.0 OUT=probe/$ID ./make_probe.sh
  mkdir -p "$DATA/p3/probe"
  rm -rf "$DATA/p3/probe/$ID"
  cp -r probe/$ID "$DATA/p3/probe/"
  cp prepare.exs tests.exs "$DATA/p3/"
fi

# 4. Preparation, the two test rounds, and the two diagnostic rounds with a stand-in fwup, each in a process of its
#    own inside the controller; wait on the markers.
if has prepare || has tests || has stub; then
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
  for round in tests stub; do
    has $round || continue
    stub=0; [ $round = stub ] && stub=1
    rm -f "$DATA/p3/$round.done"
    "$RUN/controller.sh" rpc "System.put_env(%{\"P3_TAG\" => \"$round\", \"P3_COMMAND\" => \"$COMMAND\", \"P3_STUB_FWUP\" => \"$stub\"}); spawn(fn -> Code.eval_file(\"/data/p3/tests.exs\") end)"
    until [ -e "$DATA/p3/$round.done" ]; do sleep 15; done
    cat "$DATA/p3/$round.done"
  done
fi

# 5. The per-test tables of both pairs of rounds, and the cost.
if has tables; then
  for round in tests stub; do
    [ -e "$DATA/p3/${round}_round2.json" ] || continue
    { printf 'test\tround1\tround2\n'
      jq -r --slurpfile b "$DATA/p3/${round}_round2.json" \
        '.tests | to_entries[] | [.key, .value, ($b[0].tests[.key] // "-")] | @tsv' "$DATA/p3/${round}_round1.json" | sort; } > $round.tsv
  done
  docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}' | grep -E '^elixir-agent-benchmark:' > images.txt
  df -BG / | tail -n 1 > df_after.txt
fi
