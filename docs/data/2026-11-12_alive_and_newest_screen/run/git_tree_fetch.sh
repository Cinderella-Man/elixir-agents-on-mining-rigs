#!/usr/bin/env bash
# The files that name the toolchain at a list of commits, read from the clones with git in place of GitHub's GraphQL API.
# It writes the same files as 2026-11-12_next_ten_screen/run/periods_fetch.sh, so that folder's periods_run.sh (and the
# copy here) reads them unchanged:
#   1. per batch of BATCH commits, trees_<k>.json shaped like the GraphQL answer: for candidate i, c<i>s {oid} (the
#      starting commit), c<i>r {entries: [{name, oid}]} (the root tree), c<i>w (`.github/workflows`) and c<i>a
#      (`.github/actions`, each folder with its entries), null where the folder is absent; and trees_<k>.cand;
#   2. need.tsv (kind, blob id, path: `.tool-versions`, `mise.toml`, `.mise.toml`, `Dockerfile`, `mix.exs`,
#      `.travis.yml`, `.drone.yml`, `.gitlab-ci.yml`, each workflow, each `action.yml`), the blobs fetched in one request
#      per repository, and blobs.jsonl ({kind, oid, name, text, truncated}).
#   CAND    TSV: slug (owner__name), number, merged_at, commit (run/newest.sh or alive_heads.sh write it)
#   CLONES  the clones (alive_clone.sh); RAW  where to write ($RAW/periods/<slug>/)
#   MODE    parent (default): the starting commit is the first parent of the commit given (a merge commit);
#           self: the commit given (a branch head)
#   BATCH   commits per trees file (default 25)
# A merge commit missing from the clone (a pull request merged into another branch) is fetched by its id; if GitHub
# does not serve it, the candidate's starting commit is null, which periods_run.sh reports as `missing`.
set -euo pipefail
: "${CAND:?}"; : "${CLONES:?}"; : "${RAW:?}"
MODE="${MODE:-parent}"; BATCH="${BATCH:-25}"
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/guard.sh"
mkdir -p "$RAW/periods/logs"
log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$RAW/periods/logs/fetch.log"; }
entries() {  # entries <git dir> <tree-ish>: [{name, oid}] of the blobs and trees, or null when the path is absent
  if git -C "$1" cat-file -e "$2" 2> /dev/null || git -C "$1" rev-parse -q --verify "$2^{tree}" > /dev/null 2>&1; then
    git -C "$1" -c core.quotepath=off ls-tree "$2" | jq -R -s -c 'split("\n") | map(select(length > 0) | capture("^(?<mode>\\S+) (?<type>\\S+) (?<oid>\\S+)\\t(?<name>.*)$") | {name, oid, type})'
  else echo null; fi
}
slugs="${SLUGS:-$(cut -f1 "$CAND" | sort -u)}"
for slug in $slugs; do
  guard || exit 3
  repo="${slug/__//}"; dir="$RAW/periods/$slug"; g="$CLONES/$slug.git"
  [ -d "$g" ] || { log "STOP $repo: no clone at $g"; exit 3; }
  n=$(awk -F'\t' -v s="$slug" '$1 == s' "$CAND" | wc -l)
  log "$repo: $n commits, mode $MODE"
  rm -rf "$dir"; mkdir -p "$dir"
  awk -F'\t' -v s="$slug" '$1 == s && $4 == "-" { print $2 "\t" $3 }' "$CAND" > "$dir/missing_merge.tsv"
  awk -F'\t' -v s="$slug" '$1 == s && $4 != "-" { print $2 "\t" $4 "\t" $3 }' "$CAND" | split -l "$BATCH" -d -a 4 - "$dir/batch_"
  fetched_ids=0
  for b in "$dir"/batch_*; do
    [ -e "$b" ] || continue
    k=${b##*_}; i=0
    while IFS=$'\t' read -r num sha _; do
      i=$((i + 1))
      if ! git -C "$g" cat-file -e "$sha^{commit}" 2> /dev/null; then
        git -C "$g" fetch -q --no-tags origin "$sha" 2> /dev/null || true
        fetched_ids=$((fetched_ids + 1))
      fi
      if [ "$MODE" = self ]; then start=$(git -C "$g" rev-parse -q --verify "$sha^{commit}" 2> /dev/null || true)
      else start=$(git -C "$g" rev-parse -q --verify "$sha^1" 2> /dev/null || true); fi
      if [ -z "$start" ]; then
        jq -n -c --arg i "$i" '{("c\($i)s"): null, ("c\($i)r"): null, ("c\($i)w"): null, ("c\($i)a"): null}'
        continue
      fi
      root=$(entries "$g" "$start^{tree}")
      wf=$(entries "$g" "$start:.github/workflows")
      act=null
      acts=$(entries "$g" "$start:.github/actions")
      if [ "$acts" != null ]; then
        act=$(printf '%s' "$acts" | jq -r '.[] | select(.type == "tree") | .name' | while read -r d; do
                jq -n -c --arg d "$d" --argjson e "$(entries "$g" "$start:.github/actions/$d")" '{name: $d, object: {entries: ($e // [])}}'
              done | jq -s -c '{entries: .}')
      fi
      jq -n -c --arg i "$i" --arg s "$start" --argjson r "$root" --argjson w "$wf" --argjson a "$act" \
        '{("c\($i)s"): {oid: $s}, ("c\($i)r"): {entries: $r}, ("c\($i)w"): (if $w == null then null else {entries: $w} end), ("c\($i)a"): $a}'
    done < "$b" | jq -s -c '{data: {repository: add}}' > "$dir/trees_$k.json"
    mv "$b" "$dir/trees_$k.cand"
  done
  # the distinct blobs to read: kind, oid, name (the same selection as periods_fetch.sh)
  jq -r '
    .data.repository | to_entries[] | select(.key | test("^c[0-9]+[rwa]$")) | .key as $k | .value as $v | select($v != null)
    | if ($k | endswith("r")) then
        $v.entries[] | select(.name | test("^(\\.tool-versions|mise\\.toml|\\.mise\\.toml|Dockerfile|mix\\.exs|\\.travis\\.yml|\\.drone\\.yml|\\.gitlab-ci\\.yml)$"))
        | [ (if .name == ".tool-versions" then "tv" elif (.name | test("mise\\.toml$")) then "mise" elif .name == "Dockerfile" then "docker" elif .name == "mix.exs" then "mix" else "ci" end), .oid, .name ] | @tsv
      elif ($k | endswith("w")) then
        $v.entries[] | select(.name | test("\\.ya?ml$")) | ["ci", .oid, ".github/workflows/" + .name] | @tsv
      else
        $v.entries[] | .name as $d | (.object.entries // [])[] | select(.name | test("^action\\.ya?ml$")) | ["action", .oid, ".github/actions/" + $d + "/" + .name] | @tsv
      end' "$dir"/trees_*.json | sort -u -k1,1 -k2,2 > "$dir/need.tsv"
  # one request for every blob not yet in the clone, then the texts
  cut -f2 "$dir/need.tsv" | sort -u > "$dir/oids.txt"
  if [ -s "$dir/oids.txt" ]; then
    git -C "$g" -c fetch.negotiationAlgorithm=noop fetch -q origin --no-tags --no-write-fetch-head --recurse-submodules=no \
      --filter=blob:none --stdin < "$dir/oids.txt" 2> "$dir/blob_fetch.err" || log "$repo: the blob fetch said: $(head -c 300 "$dir/blob_fetch.err")"
  fi
  : > "$dir/blobs.jsonl"
  while IFS=$'\t' read -r kind oid fname; do
    if GIT_NO_LAZY_FETCH=1 git -C "$g" cat-file blob "$oid" > "$dir/blob.tmp" 2> /dev/null; then
      jq -R -s -c --arg oid "$oid" --arg kind "$kind" --arg name "$fname" '{kind: $kind, oid: $oid, name: $name, text: ., truncated: false}' "$dir/blob.tmp"
    else
      jq -n -c --arg oid "$oid" --arg kind "$kind" --arg name "$fname" '{kind: $kind, oid: $oid, name: $name, text: null, truncated: false}'
    fi
  done < "$dir/need.tsv" >> "$dir/blobs.jsonl"
  rm -f "$dir/blob.tmp"
  log "$repo: done, $(wc -l < "$dir/need.tsv") files read ($(jq -s 'map(select(.text == null)) | length' "$dir/blobs.jsonl") without text), $fetched_ids merge commits fetched by id, $(find "$dir" -name 'trees_*.json' | wc -l) trees files"
done
