#!/usr/bin/env bash
# Part 1, step 4. The versions of the main dependencies in the `mix.lock` at the root of each clone's head (one blob
# fetch per repository). A Hex package gives its version; a dependency from git gives `git:<first 7 of its commit>`;
# a package not in the lock gives `-`.
#   CLONES  the clones     PKGS  the packages (default below)
# Writes a TSV to stdout: repo, head, the number of packages in the lock, one column per package.
set -euo pipefail
: "${CLONES:?}"
PKGS="${PKGS:-phoenix phoenix_live_view phoenix_html ecto ecto_sql postgrex oban bandit plug_cowboy absinthe ash broadway req swoosh}"
printf 'repo\thead\tlock_packages'; for p in $PKGS; do printf '\t%s' "$p"; done; printf '\n'
for d in "$CLONES"/*.git; do
  [ -d "$d" ] || continue
  slug=$(basename "$d" .git); repo="${slug/__//}"; head=$(git -C "$d" rev-parse HEAD)
  if git -C "$d" cat-file -e "HEAD:mix.lock" 2> /dev/null; then
    git -C "$d" show HEAD:mix.lock | awk -F'"' -v OFS='\t' -v repo="$repo" -v head="$head" -v pkgs="$PKGS" '
      /^[ \t]*"[a-z0-9_]+": \{:hex,/ { n++; v[$2] = $4; next }
      /^[ \t]*"[a-z0-9_]+": \{:git,/ { n++; v[$2] = "git:" substr($6, 1, 7); next }
      /^[ \t]*"[a-z0-9_]+": \{/ { n++; v[$2] = "other"; next }
      END { k = split(pkgs, P, " "); out = repo OFS head OFS n + 0; for (i = 1; i <= k; i++) out = out OFS ((P[i] in v) ? v[P[i]] : "-"); print out }'
  else
    k=$(printf '%s\n' $PKGS | wc -l); printf '%s\t%s\tno_mix.lock' "$repo" "$head"; for i in $(seq "$k"); do printf '\t-'; done; printf '\n'
  fi
done
