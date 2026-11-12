#!/usr/bin/env bash
# Job P3 for axelclark/ex338, end to end, run on the machine with Docker and the installed controller.
# Environment: JOB (a folder of this job's own, holding these scripts and the recipe), WORK (the controller's folder,
# as for controller.sh; its data is WORK/factory/data), RUN (the folder with controller.sh and docker_shim.sh from
# docs/data/2026-11-12_pilot_controller/run/), CANDIDATES (candidates_first.tsv of 2026-11-12_pilot_pr_screen),
# CENSUS (prs_axelclark__ex338.tsv of 2026-11-11_pilot_pr_census).
set -euo pipefail
: "${JOB:?}" "${WORK:?}" "${RUN:?}" "${CANDIDATES:?}" "${CENSUS:?}"
cd "$JOB"
DATA=$WORK/factory/data
df -BG / | tail -1 > df_before.txt

# 1. The periods: the toolchain of each starting commit of the first 30 candidates.
[ -d ex338.git ] || git clone -q --bare --filter=blob:none https://github.com/axelclark/ex338.git ex338.git
awk -F'\t' '$1=="axelclark/ex338" && $2<=30 {print $3}' "$CANDIDATES" > nums.txt
awk -F'\t' 'NR==FNR{n[$1]=1;next} ($1 in n){print $1"\t"$2"\t"$10}' nums.txt "$CENSUS" > merges.tsv
GIT_DIR=ex338.git ./periods.sh < merges.tsv > periods_raw.tsv

# 2. The images the recipe pins (the engine pulls them again by digest).
docker pull --quiet hexpm/elixir:1.18.3-erlang-27.3-ubuntu-noble-20260509.1
docker pull --quiet postgres:14.24-alpine

# 3. The probe task for the newest candidate of the newest period, staged where the controller sees it.
merge=$(awk -F'\t' '$1==1460{print $3}' merges.tsv)
rm -rf probe && mkdir probe
GIT_DIR=ex338.git RECIPE=axelclark__ex338.json REPO=axelclark/ex338 PROJECT=ex338 NUMBER=1460 MERGE="$merge" \
  MERGED_AT=2026-08-02T17:03:49Z OUT=probe/ex338-pr-1460 ./make_probe.sh
mkdir -p "$DATA/p3/probe"
cp -r probe/ex338-pr-1460 "$DATA/p3/probe/"
cp prepare.exs tests.exs "$DATA/p3/"

# 4. Preparation and the two test rounds through the controller, each in a process of its own; wait on the markers.
rm -f watch.stop
OUT=$JOB/labels.txt STOP=$JOB/watch.stop setsid nohup ./watch_labels.sh > /dev/null 2>&1 < /dev/null &
WORK=$WORK RUN=$RUN "$RUN/controller.sh" up
WORK=$WORK "$RUN/controller.sh" rpc 'spawn(fn -> Code.eval_file("/data/p3/prepare.exs") end)'
until [ -e "$DATA/p3/prepare.done" ]; do sleep 30; done
WORK=$WORK "$RUN/controller.sh" rpc 'spawn(fn -> Code.eval_file("/data/p3/tests.exs") end)'
until [ -e "$DATA/p3/tests.done" ]; do sleep 10; done
touch watch.stop
WORK=$WORK "$RUN/controller.sh" down

# 5. The per-test table of both rounds, and the cost.
{ printf 'test\tround1\tround2\n'
  jq -r --slurpfile b "$DATA/p3/tests_round2.json" \
    '.tests | to_entries[] | [.key, .value, $b[0].tests[.key]] | @tsv' "$DATA/p3/tests_round1.json" | sort; } > tests.tsv
docker images --format '{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}' | grep -E '^elixir-agent-benchmark:' > images.txt
df -BG / | tail -1 > df_after.txt
