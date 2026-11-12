#!/usr/bin/env bash
# Convert the kept sessions a second time, with another Python (a container image), and compare every record with
# the first run's, byte for byte. Jinja2 is not in the image: the machine's own copy is mounted read only.
#
#   SRC, SESSIONS, OUT  as in first_run.sh (OUT is the first run's folder, read only here)
#   WORK      a folder of one's own for the second set of records
#   IMAGE     the image (default python:3.12-slim-bookworm)
#   PACKAGES  the folder that holds the machine's jinja2 and markupsafe packages
#   SITE      the image's site-packages folder
#   NAME      the container's name
set -euo pipefail
: "${SRC:?}" "${SESSIONS:?}" "${OUT:?}" "${WORK:?}" "${PACKAGES:?}"
IMAGE=${IMAGE:-python:3.12-slim-bookworm}
SITE=${SITE:-/usr/local/lib/python3.12/site-packages}
NAME=${NAME:-converter-again}
PROJECT=${PROJECT:-axelclark__ex338}
mkdir -p "$WORK/again"
docker run --rm --name "$NAME" --network none --cpu-shares 128 --user "$(id -u):$(id -g)" \
  -v "$SRC:/src:ro" -v "$SESSIONS:/sessions:ro" -v "$WORK/again:/again" \
  -v "$PACKAGES/jinja2:$SITE/jinja2:ro" -v "$PACKAGES/markupsafe:$SITE/markupsafe:ro" \
  -e PYTHONDONTWRITEBYTECODE=1 "$IMAGE" sh -c "
    python -I /src/tools/training_data/tests/test_converter.py 2>&1 | tail -n 4 &&
    python -I /src/tools/training_data/convert_sessions.py --index /sessions/sessions.tsv --root /sessions \
      --kept yes --project $PROJECT --out /again"
same=0; other=0
for record in "$OUT"/*/*.json; do
  if cmp -s "$record" "$WORK/again/${record#"$OUT"/}"; then same=$((same + 1)); else other=$((other + 1)); fi
done
cmp -s "$OUT/records.tsv" "$WORK/again/records.tsv" && echo "records.tsv: the same bytes" || echo "records.tsv: DIFFERENT"
grep -h '"python"\|"jinja2"' "$OUT/run.json" "$WORK/again/run.json" | sort | uniq -c
echo "records the same bytes: $same; different: $other"
[ "$other" = 0 ]
