#!/usr/bin/env bash
# Periods, step 1. For every candidate of the repositories in $CAND, the files its starting commit (the first parent of
# its merge commit) holds that name the toolchain, through GitHub's GraphQL API. Nothing is cloned.
#   1. per batch of candidates: the starting commit's id, its root tree, `.github/workflows` and `.github/actions`
#      (entry names and blob ids only);
#   2. per repository: the text of each distinct blob once (`.tool-versions`, `mise.toml`, `.mise.toml`, `Dockerfile`,
#      `mix.exs`, `.travis.yml`, `.drone.yml`, `.gitlab-ci.yml`, each workflow, each `action.yml`).
# Checks GitHub's GraphQL budget before each repository and stops, writing nothing more, if the repository's queries
# (and a reserve) would not fit in what is left.
#   CAND     TSV: slug (owner__name), number, merged_at, merge_commit (candidates only; run/candidates.sh writes it)
#   RAW      raw folder (NOT committed; workflow text is not a pull request's title or body, but stays out anyway)
#   BATCH    candidates per tree query (default 25); BLOBS blobs per text query (default 40)
#   RESERVE  GraphQL points to keep unspent (default 300)
# Writes $RAW/periods/<slug>/trees_<k>.json (+ trees_<k>.cand), $RAW/periods/<slug>/blobs.jsonl ({kind, oid, name, text}).
set -euo pipefail
: "${CAND:?}"; : "${RAW:?}"
BATCH="${BATCH:-25}"; BLOBS="${BLOBS:-40}"; RESERVE="${RESERVE:-300}"
mkdir -p "$RAW/periods/logs"
log() { echo "$(date -u +%FT%TZ) $*" | tee -a "$RAW/periods/logs/fetch.log"; }
gql() {  # gql <outfile> <query>: up to 4 tries
  local f="$1" q="$2"
  for try in 1 2 3 4; do
    if gh api graphql -f query="$q" > "$f" 2> "$f.err" && jq -e '.data and (.errors | not)' "$f" > /dev/null 2>&1; then rm -f "$f.err"; return 0; fi
    sleep $((try * 5))
  done
  echo "FAILED: $f" >&2; cat "$f.err" >&2; return 1
}
slugs="${SLUGS:-$(cut -f1 "$CAND" | sort -u)}"
for slug in $slugs; do
  repo="${slug/__//}"; owner="${repo%%/*}"; name="${repo##*/}"; dir="$RAW/periods/$slug"
  n=$(awk -F'\t' -v s="$slug" '$1 == s' "$CAND" | wc -l)
  need=$(( n / BATCH + 2 + 150 + RESERVE ))      # tree queries, and room for the blob queries (est. 150)
  have=$(gh api rate_limit --jq '.resources.graphql.remaining')
  if [ "$have" -lt "$need" ]; then log "STOP $repo: GraphQL remaining $have, needs about $need"; exit 3; fi
  log "$repo: $n candidates, GraphQL remaining $have, needs about $need"
  rm -rf "$dir"; mkdir -p "$dir"
  awk -F'\t' -v s="$slug" '$1 == s && $4 == "-" { print $2 "\t" $3 }' "$CAND" > "$dir/missing_merge.tsv"      # candidates GitHub gives no merge commit for
  awk -F'\t' -v s="$slug" '$1 == s && $4 != "-" { print $2 "\t" $4 "\t" $3 }' "$CAND" | split -l "$BATCH" -d -a 4 - "$dir/batch_"
  for b in "$dir"/batch_*; do
    k=${b##*_}
    q='query{ rateLimit{cost remaining} repository(owner:"'"$owner"'",name:"'"$name"'"){'
    i=0
    while IFS=$'\t' read -r num sha _; do
      i=$((i + 1))
      q="$q c${i}s: object(expression:\"$sha^1\"){oid}"
      q="$q c${i}r: object(expression:\"$sha^1:\"){... on Tree{entries{name oid}}}"
      q="$q c${i}w: object(expression:\"$sha^1:.github/workflows\"){... on Tree{entries{name oid}}}"
      q="$q c${i}a: object(expression:\"$sha^1:.github/actions\"){... on Tree{entries{name object{... on Tree{entries{name oid}}}}}}"
    done < "$b"
    q="$q } }"
    gql "$dir/trees_$k.json" "$q"
    cp "$b" "$dir/trees_$k.cand"; rm -f "$b"
    sleep 1
  done
  # the distinct blobs to read: kind, oid, name
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
  log "$repo: $(wc -l < "$dir/need.tsv") distinct files to read"
  : > "$dir/blobs.jsonl"
  split -l "$BLOBS" -d -a 4 "$dir/need.tsv" "$dir/needb_"
  for b in "$dir"/needb_*; do
    q='query{ repository(owner:"'"$owner"'",name:"'"$name"'"){'
    while IFS=$'\t' read -r kind oid fname; do q="$q o$oid: object(oid:\"$oid\"){... on Blob{text isTruncated}}"; done < "$b"
    q="$q } }"
    gql "$b.json" "$q"
    # join each answer with its kind and name
    awk -F'\t' '{ print $2 "\t" $1 "\t" $3 }' "$b" | while IFS=$'\t' read -r oid kind fname; do
      jq -c --arg oid "$oid" --arg kind "$kind" --arg name "$fname" '.data.repository["o" + $oid] | {kind: $kind, oid: $oid, name: $name, text: .text, truncated: .isTruncated}' "$b.json"
    done >> "$dir/blobs.jsonl"
    rm -f "$b" "$b.json"
    sleep 1
  done
  log "$repo: done, $(wc -l < "$dir/blobs.jsonl") files read, $(find "$dir" -name 'trees_*.json' | wc -l) tree queries"
done
