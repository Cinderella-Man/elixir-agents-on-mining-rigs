#!/usr/bin/env bash
# catch.sh: for each `git add -A` that starts in one of the engine's workspace containers (an exec_create in
# events.sh's EVENTS), waits WAIT seconds and, if that git is still running, records in OUT/catch_<container>.txt
# what it is doing, read from inside the container as the workspace's own user: the processes with their state and
# kernel wait channel, git's open files and current system call, git's configuration, and the files git would visit
# that are not regular files or folders. Read-only. Stops after COUNT catches.
# Environment: EVENTS, OUT, WAIT (15), COUNT (2), USER_ID (1000).
set -uo pipefail
: "${EVENTS:?}" "${OUT:?}"
WAIT=${WAIT:-15}
COUNT=${COUNT:-2}
USER_ID=${USER_ID:-1000}
n=0
tail -n 0 -F "$EVENTS" | while read -r line; do
  case $line in *'"exec_create: timeout -k 5 120 bash -lc git add -A"'*) ;; *) continue ;; esac
  name=$(printf '%s' "$line" | jq -r '.Actor.Attributes.name')
  sleep "$WAIT"
  f="$OUT/catch_$name.txt"
  docker exec -u "$USER_ID" -w /workspace "$name" sh -c '
    date -u +%FT%TZ
    pid=$(pgrep -x git | head -n 1)
    [ -n "$pid" ] || { echo "git has ended"; exit 0; }
    echo "== processes (pid, state, wait channel, elapsed, cpu, command)"
    ps -eo pid,stat,wchan:32,etime,pcpu,args
    echo "== git $pid: wchan $(cat /proc/$pid/wchan); syscall $(cat /proc/$pid/syscall 2>&1)"
    echo "== git $pid: open files"; ls -l /proc/$pid/fd
    echo "== git $pid: status"; grep -E "^(State|VmRSS|voluntary|nonvoluntary)" /proc/$pid/status
    sleep 5; echo "== after 5 s: syscall $(cat /proc/$pid/syscall 2>&1); ctxt $(grep -E "^voluntary" /proc/$pid/status)"
    echo "== git config"; git config -l --show-origin
    echo "== .git"; ls -la .git
    echo "== not regular files or folders, outside .git"; find . -path ./.git -prune -o ! -type f ! -type d -print | head -n 50
    echo "== git status --porcelain --ignored (first 40 lines)"; timeout 20 git status --porcelain --ignored | head -n 40
  ' > "$f" 2>&1
  n=$((n + 1))
  [ "$n" -ge "$COUNT" ] && exit 0
done
