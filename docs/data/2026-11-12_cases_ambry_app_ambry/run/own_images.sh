#!/usr/bin/env bash
# own_images.sh: the job's own Docker images, on the data-mining machine, from Docker's API.
#   own_images.sh now     every image that carries JOB_LABEL now (/system/df): id, names, bytes, the bytes no other
#                         image shares (its size minus its shared size), the label's value; no header
#   own_images.sh tries   per try in all.sh's rows (OUT/rows.tsv): of the images the try added (one.sh's
#                         images_added.tsv), those in NOW (the table above): how many, their bytes, their unique bytes
#                         now
# Environment: JOB_LABEL (key=value) for now; OUT and NOW for tries. Needs curl and jq.
set -euo pipefail
what=${1:?now|tries}
case $what in
now)
  : "${JOB_LABEL:?}"
  curl -s --unix-socket /var/run/docker.sock 'http://localhost/system/df?type=image' |
    jq -r --arg k "${JOB_LABEL%%=*}" --arg v "${JOB_LABEL#*=}" '.Images[] | select((.Labels // {})[$k] == $v) |
      [.Id, ((.RepoTags // []) | join(" ")), .Size, (.Size - .SharedSize), $v] | @tsv'
  ;;
tries)
  : "${OUT:?}" "${NOW:?}"
  printf 'id\ttry\town_images_added\town_images_bytes\town_images_unique_bytes_now\n'
  tail -n +2 "$OUT/rows.tsv" | while IFS=$'\t' read -r try _repo _number id _rest; do
    f=$OUT/$id/$try/images_added.tsv
    [ -f "$f" ] || f=/dev/null
    awk -F'\t' -v OFS='\t' -v i="$id" -v t="$try" '
      FILENAME == ARGV[1] {u[$1] = $4; next}
      ($1 in u) {n++; b += $3; ub += u[$1]}
      END {print i, t, n + 0, b + 0, ub + 0}' "$NOW" "$f"
  done
  ;;
*) echo "unknown table $what"; exit 2 ;;
esac
