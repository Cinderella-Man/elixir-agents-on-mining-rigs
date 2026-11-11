#!/usr/bin/env bash
# flatten.sh's rows -> prs_<owner>__<name>.tsv: every changed path classed, the flags, and "followed by".
#   WORK  folder with flat_<owner>__<name>.tsv (flatten.sh's output)
#   OUT   output folder; writes $OUT/prs_<owner>__<name>.tsv (run_all.sh gzips a file over 1 MB)
# Written for mawk (no asort, no gensub). Flags are 1 or 0.
#
# Classes, first match wins; an umbrella path "apps/<app>/x" is classed as "x":
#   tests       test/
#   migrations  priv/<repo>/migrations/   (priv/repo/migrations/ and the like)
#   deps        mix.exs, mix.lock
#   config      config/
#   ci          .github/                  (any path, not only under apps/)
#   assets      assets/, priv/static/
#   impl        .ex .heex .eex .leex under lib/
#   web         the same extensions under web/ (the Phoenix 1.2 layout, before lib/<app>_web/); counted apart, so
#               that impl stays as defined above
#   docs        .md anywhere, docs/, guides/
#   other       everything else
# Flags:
#   bot              author type Bot, a login ending in [bot], or a login containing dependabot or renovate
#   deps_only        at least one path, every path is mix.exs or mix.lock
#   deps_only_js     at least one path, every path is mix.exs, mix.lock or a JavaScript manifest or lock file
#                    (package.json, package-lock.json, yarn.lock, pnpm-lock.yaml, npm-shrinkwrap.json)
#   docs_only        at least one path, every path is in class docs
#   revert           flatten.sh's flag: the title starts with revert, reverts, reverted or reverting, or the body starts
#                    with "Reverts <ref>#N", or the head branch is GitHub's "revert-<N>-<branch>"
#   both_impl_tests  at least one impl path and at least one tests path
#   impl_2_5         2 to 5 impl paths
#   both_impl_tests_web, impl_2_5_web   the same two with web paths counted as implementation too
# Followed by: later merged pull requests (merged after this one, within 30 days of its merge time) that
#   - touch at least one of the same test files (a "_test.exs" file under test/, same path), or
#   - mention "#<number>" or "<this repository>#<number>" in their title or body.
#   The mentions of bot-authored pull requests are not read: a dependency bump's body copies the dependency's release
#   notes, whose "#<number>" are that project's numbers. Their mentions column is "-".
# "Later" is the order of merge time, then of number.
set -euo pipefail
: "${WORK:?flat rows}"; : "${OUT:?output folder}"
mkdir -p "$OUT"
for flat in "$WORK"/flat_*.tsv; do
  slug=$(basename "$flat" .tsv); slug=${slug#flat_}
  awk -F'\t' -v OFS='\t' '
    function cls(p,   q) {
      q = p; sub(/^apps\/[^\/]+\//, "", q)
      if (q ~ /^test\//) return "tests"
      if (q ~ /^priv\/[^\/]+\/migrations\//) return "migrations"
      if (q ~ /^mix\.(exs|lock)$/) return "deps"
      if (q ~ /^config\//) return "config"
      if (p ~ /^\.github\//) return "ci"
      if (q ~ /^assets\// || q ~ /^priv\/static\//) return "assets"
      if (q ~ /^lib\// && q ~ /\.(ex|heex|eex|leex)$/) return "impl"
      if (q ~ /^web\// && q ~ /\.(ex|heex|eex|leex)$/) return "web"
      if (p ~ /\.md$/ || p ~ /^docs\// || p ~ /^guides\//) return "docs"
      return "other"
    }
    function isjs(p,   b) {
      b = p; sub(/^.*\//, "", b)
      return (b == "package.json" || b == "package-lock.json" || b == "yarn.lock" || b == "pnpm-lock.yaml" || b == "npm-shrinkwrap.json")
    }
    function addset(i, key, n) {   # per-row sets as ";"-delimited strings, kept unique
      if (index(";" fb[key, i] ";", ";" n ";") == 0) fb[key, i] = (fb[key, i] == "" ? n : fb[key, i] ";" n)
    }
    function sortjoin(s,   a, n, i, j, t, out) {   # numeric sort of a ";"-joined list
      if (s == "") return "-"
      n = split(s, a, ";")
      for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] + 0 > t + 0; j--) a[j + 1] = a[j]; a[j + 1] = t }
      out = a[1]; for (i = 2; i <= n; i++) out = out ";" a[i]
      return out
    }
    BEGIN { DAY30 = 30 * 86400 }
    {
      r++
      num[r] = $1; ep[r] = $2; at[r] = $3; author[r] = $4; atype[r] = $5; base[r] = $6; add[r] = $7; del[r] = $8
      chg[r] = $9; mc[r] = $10; lab[r] = $11; closes[r] = $12; rev[r] = ($13 == "true") ? 1 : 0; reverts[r] = $14
      ment[r] = $15; listed[r] = $16; paths[r] = $17
      idx[$1] = r
      np = split($17, P, ";")
      n_impl[r] = n_tests[r] = n_mig[r] = n_cfg[r] = n_assets[r] = n_deps[r] = n_docs[r] = n_ci[r] = n_other[r] = n_web[r] = 0
      jsonly = 1; mixonly = 1
      for (k = 1; k <= np; k++) {
        c = cls(P[k])
        if (c == "impl") n_impl[r]++; else if (c == "tests") n_tests[r]++; else if (c == "migrations") n_mig[r]++
        else if (c == "config") n_cfg[r]++; else if (c == "assets") n_assets[r]++; else if (c == "deps") n_deps[r]++
        else if (c == "docs") n_docs[r]++; else if (c == "ci") n_ci[r]++; else if (c == "web") n_web[r]++; else n_other[r]++
        if (c != "deps") mixonly = 0
        if (c != "deps" && !isjs(P[k])) jsonly = 0
        if (c == "tests" && P[k] ~ /_test\.exs$/ && !((r SUBSEP P[k]) in seen)) {
          seen[r SUBSEP P[k]] = 1
          tf[P[k]] = tf[P[k]] (tf[P[k]] == "" ? "" : " ") r      # rows touching this test file, ascending
        }
      }
      deps_only[r] = (np > 0 && listed[r] > 0 && mixonly) ? 1 : 0
      deps_js[r] = (np > 0 && listed[r] > 0 && jsonly) ? 1 : 0
      docs_only[r] = (listed[r] > 0 && n_docs[r] == listed[r]) ? 1 : 0
      lg = tolower(author[r])
      bot[r] = (atype[r] == "Bot" || lg ~ /\[bot\]$/ || lg ~ /dependabot/ || lg ~ /renovate/) ? 1 : 0
      if (bot[r]) ment[r] = "-"     # a bot body copies the changelog of the dependency, whose #N are not ours
      both[r] = (n_impl[r] > 0 && n_tests[r] > 0) ? 1 : 0
      i25[r] = (n_impl[r] >= 2 && n_impl[r] <= 5) ? 1 : 0
      bothw[r] = (n_impl[r] + n_web[r] > 0 && n_tests[r] > 0) ? 1 : 0
      i25w[r] = (n_impl[r] + n_web[r] >= 2 && n_impl[r] + n_web[r] <= 5) ? 1 : 0
    }
    END {
      # followed by, through shared test files
      for (f in tf) {
        m = split(tf[f], R, " ")
        for (a = 1; a <= m; a++) for (b = a + 1; b <= m; b++)
          if (ep[R[b]] - ep[R[a]] <= DAY30) addset(R[a], "t", num[R[b]])
      }
      # followed by, through mentions
      for (j = 1; j <= r; j++) {
        if (ment[j] == "-") continue
        m = split(ment[j], M, ";")
        for (a = 1; a <= m; a++) {
          if (!(M[a] in idx)) continue
          i = idx[M[a]]
          if (i < j && ep[j] - ep[i] <= DAY30) addset(i, "m", num[j])
        }
      }
      print "number", "merged_at", "author", "bot", "base", "additions", "deletions", "changed_files", "files_listed", "merge_commit", "labels", "closes_issues", \
            "n_impl", "n_tests", "n_migrations", "n_config", "n_assets", "n_deps", "n_docs", "n_ci", "n_other", "n_web", \
            "deps_only", "deps_only_js", "docs_only", "revert", "reverts", "both_impl_tests", "impl_2_5", "both_impl_tests_web", "impl_2_5_web", \
            "followed_by_tests", "followed_by_mentions", "followed_by_n", "mentions", "paths"
      for (i = 1; i <= r; i++) {
        u = fb["t", i]; v = fb["m", i]; w = u
        if (v != "") { mm = split(v, V, ";"); for (k = 1; k <= mm; k++) if (index(";" w ";", ";" V[k] ";") == 0) w = (w == "" ? V[k] : w ";" V[k]) }
        nf = (w == "") ? 0 : split(w, W, ";")
        print num[i], at[i], author[i], bot[i], base[i], add[i], del[i], chg[i], listed[i], mc[i], lab[i], closes[i], \
              n_impl[i], n_tests[i], n_mig[i], n_cfg[i], n_assets[i], n_deps[i], n_docs[i], n_ci[i], n_other[i], n_web[i], \
              deps_only[i], deps_js[i], docs_only[i], rev[i], reverts[i], both[i], i25[i], bothw[i], i25w[i], \
              sortjoin(u), sortjoin(v), nf, ment[i], paths[i]
      }
    }' "$flat" > "$OUT/prs_$slug.tsv"
  echo "$slug: $(($(wc -l < "$OUT/prs_$slug.tsv") - 1)) rows, $(du -k "$OUT/prs_$slug.tsv" | cut -f1) KiB"
done
