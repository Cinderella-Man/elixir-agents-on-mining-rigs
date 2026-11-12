#!/usr/bin/env bash
# sync.sh: copy the factory folder, this run/ folder and the two tables to the build machine (run on the editing
# machine). The copy keeps WORK/src/.local, where Mix keeps its downloaded dependencies and compiled files.
# Environment: HOST (an ssh destination), WORK (the folder on HOST),
# REPO (the local checkout of this repository; default: four folders up from this script).
set -euo pipefail
: "${HOST:?HOST=<ssh destination>}" "${WORK:?WORK=<folder on HOST>}"
REPO=${REPO:-$(cd "$(dirname "$0")/../../../.." && pwd)}
ssh "$HOST" "mkdir -p '$WORK/src' '$WORK/run' '$WORK/tables'"
rsync -a --delete --chown=1000:1000 --exclude /.local "$REPO/factory/" "$HOST:$WORK/src/"
rsync -a "$(dirname "$0")/" "$HOST:$WORK/run/"
rsync -a "$REPO/docs/data/2026-11-11_pilot_pr_census/prs_axelclark__ex338.tsv" \
  "$REPO/docs/data/2026-11-12_pilot_pr_screen/screen_axelclark__ex338.tsv" "$HOST:$WORK/tables/"
