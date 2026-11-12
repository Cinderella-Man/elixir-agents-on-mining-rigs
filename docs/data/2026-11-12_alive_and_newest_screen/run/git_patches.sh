#!/usr/bin/env bash
# Screening: the per-file patches of the repair test from the clones, in place of GitHub's REST API (pulls/N/files,
# which needs a sign-in for this many requests). For each pull request whose patch the repair test needs (repair.sh's
# rule: both pull requests of a named pair that is not a revert change code or tests) and that
# $RAW/patches/<slug>/<n>.json does not hold yet:
#   - its head, from GitHub's refs/pull/<n>/head (50 refs per request);
#   - its merge commit, from the census (column merge_commit), fetched by its id when the clone lacks it;
#   - git diff -M <merge commit's first parent>...<head>: the changes on the pull request's branch since it left the
#     base branch, the comparison GitHub's files list makes (base...head), turned into that list's JSON by diff_files.jq.
# When git cannot make it (the head or the merge commit is not served, or the head is already on the base branch, so the
# series' start is unknown), the public page https://github.com/<repo>/pull/<n>.diff gives the same comparison, one
# request every PAUSE seconds (default 4). A pull request neither gives has no file; the log says which.
#   WORK    folder with pairs_<slug>.tsv (relate.sh); writes need_<slug>.txt there
#   CENSUS  census folder (prs_<slug>.tsv.gz)
#   CLONES  the clones (blob:none); RAW  writes $RAW/patches/<slug>/<n>.json and $RAW/patches/git_patches.log
#   NEED    optional: a file of `slug<TAB>number` lines made in place of the need lists (made even when a file exists;
#           used to compare with GitHub's own files lists)
set -euo pipefail
: "${WORK:?}"; : "${CENSUS:?}"; : "${CLONES:?}"; : "${RAW:?}"
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/guard.sh"
mkdir -p "$RAW/patches"
plog="$RAW/patches/git_patches.log"
if [ -n "${NEED:-}" ]; then slugs=$(cut -f1 "$NEED" | sort -u)
else slugs=$(for p in "$WORK"/pairs_*.tsv; do s=$(basename "$p" .tsv); echo "${s#pairs_}"; done); fi
for slug in $slugs; do
  repo="${slug/__//}"; g="$CLONES/$slug.git"; dir="$RAW/patches/$slug"; mkdir -p "$dir"
  if [ -n "${NEED:-}" ]; then
    awk -F'\t' -v s="$slug" '$1 == s { print $2 }' "$NEED" | sort -n -u > "$dir/todo.txt"
  else
    awk -F'\t' '$6 == 0 && $8 > 0 && $9 > 0 { print $1; print $2 }' "$WORK/pairs_$slug.tsv" | sort -n -u > "$WORK/need_$slug.txt"
    while read -r n; do [ -s "$dir/$n.json" ] || echo "$n"; done < "$WORK/need_$slug.txt" > "$dir/todo.txt"
  fi
  todo=$(wc -l < "$dir/todo.txt")
  echo "$(date -u +%FT%TZ) $repo: $todo pull requests to diff" | tee -a "$plog"
  [ "$todo" -gt 0 ] || continue
  guard || exit 3
  [ -d "$g" ] || { echo "STOP $repo: no clone at $g" | tee -a "$plog"; exit 3; }
  gzip -dc "$CENSUS/prs_$slug.tsv.gz" | awk -F'\t' 'NR > 1 { print $1 "\t" $10 }' > "$dir/merge.tsv"
  # the heads, 50 refs per request; a batch that fails is fetched one ref at a time
  split -l 50 "$dir/todo.txt" "$dir/headbatch_"
  for b in "$dir"/headbatch_*; do
    specs=$(awk '{ printf "+refs/pull/%s/head:refs/pr/%s ", $1, $1 }' "$b")
    # shellcheck disable=SC2086
    if ! git -C "$g" fetch -q --no-tags origin $specs 2> /dev/null; then
      while read -r n; do git -C "$g" fetch -q --no-tags origin "+refs/pull/$n/head:refs/pr/$n" 2> /dev/null || true; done < "$b"
    fi
    rm -f "$b"; sleep 1
  done
  made=0; failed=0
  while read -r n; do
    m=$(awk -F'\t' -v n="$n" '$1 == n { print $2 }' "$dir/merge.tsv")
    why=""
    if [ -z "$m" ] || [ "$m" = "-" ]; then why="no_merge_commit"
    else
      git -C "$g" cat-file -e "$m^{commit}" 2> /dev/null || git -C "$g" fetch -q --no-tags origin "$m" 2> /dev/null || true
      git -C "$g" cat-file -e "$m^{commit}" 2> /dev/null || why="merge_commit_not_served"
    fi
    [ -z "$why" ] && { git -C "$g" rev-parse -q --verify "refs/pr/$n" > /dev/null || why="head_not_served"; }
    # a head already on the base branch (a rebase merge that kept the commits, or a fast-forward): the merge commit's
    # first parent is then inside the pull request's own series, and git cannot tell where the series starts
    [ -z "$why" ] && git -C "$g" merge-base --is-ancestor "refs/pr/$n" "$m" && why="head_on_base_branch"
    if [ -z "$why" ]; then
      if git -C "$g" -c core.quotepath=off diff --no-color --no-ext-diff -M "$m^1...refs/pr/$n" > "$dir/$n.diff" 2> "$dir/$n.err" \
         && jq -R -s -c -f "$here/diff_files.jq" "$dir/$n.diff" > "$dir/$n.json.tmp"; then
        mv "$dir/$n.json.tmp" "$dir/$n.json"; made=$((made + 1))
        echo "$repo	$n	ok	$m	$(jq length "$dir/$n.json") files" >> "$plog"
      else why="diff_failed:$(head -c 200 "$dir/$n.err" | tr '\n\t' '  ')"; fi
      rm -f "$dir/$n.diff" "$dir/$n.err" "$dir/$n.json.tmp"
    fi
    # when git cannot make it: the public page https://github.com/<repo>/pull/<n>.diff (the same comparison), one request
    # every PAUSE seconds
    if [ -n "$why" ]; then
      sleep "${PAUSE:-4}"
      code=$(curl -sSL --max-time 60 -A 'Mozilla/5.0 (compatible; repository-check)' -o "$dir/$n.diff" -w '%{http_code}' "https://github.com/$repo/pull/$n.diff" 2> /dev/null || echo 000)
      if [ "$code" = 200 ] && jq -R -s -c -f "$here/diff_files.jq" "$dir/$n.diff" > "$dir/$n.json.tmp"; then
        mv "$dir/$n.json.tmp" "$dir/$n.json"; made=$((made + 1))
        echo "$repo	$n	ok_from_diff_page($why)	${m:--}	$(jq length "$dir/$n.json") files" >> "$plog"; why=""
      else why="$why;diff_page_$code"; fi
      rm -f "$dir/$n.diff" "$dir/$n.json.tmp"
    fi
    if [ -n "$why" ]; then failed=$((failed + 1)); echo "$repo	$n	$why	${m:--}	-" >> "$plog"; fi
  done < "$dir/todo.txt"
  rm -f "$dir/todo.txt" "$dir/merge.tsv"
  echo "$(date -u +%FT%TZ) $repo: $made made, $failed without a patch" | tee -a "$plog"
done
