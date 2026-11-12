#!/usr/bin/env bash
# The whole job on the data-mining machine, one stage at a time: `job.sh <stage>`. Each stage writes
# $WORK/logs/<stage>.log and, when it ends, $WORK/logs/<stage>.done holding its exit status.
#   WORK      the job's folder on the machine (clones/, raw/, work/, out/, logs/)
#   PUB       a copy of this public repository (docs/data and factory/config are read)
#   SRC_RAW   the earlier job's raw folder (pages and REST patches of five of the 21), copied once (stage raw)
#   GITHUB_TOKEN_FILE  a file holding a read-only GitHub token (stage fetch only; never printed)
#   BENCH_KEEP  the name of the bench container that runs all day on the machine (guard.sh)
#   NOW       the reference time of part 1, seconds since 1970 (default: now)
# Stages, in order: raw, select, clone, history, archived, deps, heads (part 1); fetch, census, screen, compare,
# newest, periods, classes (part 2); then deps and heads again, so the table carries the census counts of all; and
# classes16: the classes again for the 16 projects the list kept, with the floor of Elixir 1.18 the rules set.
set -uo pipefail
: "${WORK:?}"; : "${PUB:?}"
stage="${1:?stage}"
export PILOT="$PUB/docs/data"
here="$(cd "$(dirname "$0")" && pwd)"
export LIST="$PILOT/2026-11-09_elixir_project_pool/approved_app_first_batch.tsv"
export HOLDOUT="$PUB/factory/config/holdout.json" TABLE="$PUB/factory/config/toolchain_images.json"
export CLONES="$WORK/clones" RAW="$WORK/raw" REPOS="$WORK/out/selected.tsv"
OUTD="$WORK/out"; WK="$WORK/work"
TEN_CENSUS="$PILOT/2026-11-12_next_ten_screen/census"
PILOT_CENSUS="$PILOT/2026-11-11_pilot_pr_census"; PILOT_SCREEN="$PILOT/2026-11-12_pilot_pr_screen"
# the two the pilot screened (only their newest candidates' pairs are read), the five whose pages the earlier job
# fetched, and every application of the selection
TWO="axelclark__ex338 nerves-hub__nerves_hub_web"
FIVE="mbta__screens supabase__realtime hexpm__hexpm ambry-app__ambry source-academy__backend"
ALL=$( [ -f "$REPOS" ] && awk -F'\t' 'NR > 1 { s = $1; sub("/", "__", s); printf "%s ", s }' "$REPOS" )
SCREENED=$(for s in $ALL; do case " $TWO " in *" $s "*) ;; *) printf '%s ' "$s" ;; esac; done)
mkdir -p "$WORK/logs" "$OUTD" "$WK" "$CLONES" "$RAW"
run() {
  case "$stage" in
    raw)      [ -d "$RAW/meta" ] || cp -a "${SRC_RAW:?}/." "$RAW/" ;;
    select)   "$here/select.sh" > "$REPOS" && wc -l < "$REPOS" ;;
    clone)    nice -n 19 "$here/alive_clone.sh" ;;
    history)  nice -n 19 "$here/alive_history.sh" > "$OUTD/alive_history.tsv" ;;
    archived) nice -n 19 "$here/alive_archived.sh" > "$OUTD/alive_archived.tsv" ;;
    deps)     nice -n 19 "$here/alive_deps.sh" > "$OUTD/alive_deps.tsv" \
              && HIST="$OUTD/alive_history.tsv" CENSUS_DIRS="$OUTD/census $TEN_CENSUS $PILOT_CENSUS" "$here/census_window.sh" > "$OUTD/alive_census_window.tsv" ;;
    heads)    HIST="$OUTD/alive_history.tsv" ARCH="$OUTD/alive_archived.tsv" DEPS="$OUTD/alive_deps.tsv" CENS="$OUTD/alive_census_window.tsv" OUT="$OUTD" \
              PILOTS="${TWO//__//}" EARLIER="${FIVE//__//}" nice -n 19 "$here/alive_table.sh" ;;
    fetch)    SKIP="${FIVE//__//} ${TWO//__//}" LAST="Simon-Initiative/oli-torus santiment/sanbase2" nice -n 19 "$here/fetch_new.sh" ;;
    census)   WORK="$WK" OUT="$OUTD" nice -n 19 "$here/census.sh" && cat "$OUTD/census/summary.tsv" ;;
    screen)   CENSUS="$OUTD/census" WORK="$WK" OUT="$OUTD" nice -n 19 "$here/run_screen.sh" ;;
    compare)  mkdir -p "$OUTD/screen" && CENSUS="$OUTD/census" WORK="$WK" SLUGS="hexpm__hexpm ambry-app__ambry" nice -n 19 "$here/compare_patches.sh" | tee "$OUTD/screen/compare_patches.tsv" ;;
    newest)   { SLUGS="$SCREENED" CENSUS="$OUTD/census" SCREEN="$OUTD/screen" nice -n 19 "$here/newest.sh"
                SLUGS="$TWO" CENSUS="$PILOT_CENSUS" SCREEN="$PILOT_SCREEN" nice -n 19 "$here/newest.sh"; } > "$WK/cand.tsv" \
              && cut -f1 "$WK/cand.tsv" | sort | uniq -c ;;
    periods)  CAND="$WK/cand.tsv" MODE=parent nice -n 19 "$here/git_tree_fetch.sh" \
              && OUT="$OUTD/periods" SLUGS="$(cut -f1 "$WK/cand.tsv" | sort -u | tr '\n' ' ')" nice -n 19 "$here/periods_run.sh" ;;
    classes)  OUT="$OUTD" SLUGS="$ALL" EXTRA_SCREEN="$PILOT_SCREEN" nice -n 19 "$here/classes.sh" ;;
    classes16) S16=$(awk -F'\t' 'NR > 1 { s = $1; sub("/", "__", s); printf "%s ", s }' "$PILOT/2026-11-12_dataset_projects/projects.tsv")
              OUT="$OUTD" SLUGS="$S16" FLOOR=1.18 CDIR=classes_16 EXTRA_SCREEN="$PILOT_SCREEN" nice -n 19 "$here/classes.sh" ;;
    *) echo "unknown stage $stage" >&2; return 2 ;;
  esac
}
rm -f "$WORK/logs/$stage.done"
{ echo "$(date -u +%FT%TZ) start $stage"; run; rc=$?; echo "$(date -u +%FT%TZ) end $stage: $rc"; } > "$WORK/logs/$stage.log" 2>&1
echo "$rc" > "$WORK/logs/$stage.done"
