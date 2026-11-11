# Shared awk functions (mawk: no asort, no gensub). The path classes are the census's, copied from its derive.sh.
# Classes, first match wins; an umbrella path "apps/<app>/x" is classed as "x":
#   tests, migrations, deps (mix.exs, mix.lock), config, ci (.github/), assets (assets/, priv/static/),
#   impl (.ex .heex .eex .leex under lib/), web (the same under web/), docs, other
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
# a path whose lines the repair test compares: code (impl, web) or tests
function repairable(p,   c) { c = cls(p); return (c == "impl" || c == "web" || c == "tests") }
# is the number n in the ";"-joined list s?
function inlist(s, n) { return (s != "-" && s != "" && index(";" s ";", ";" n ";") > 0) }
# do two ";"-joined lists share an element?
function share(a, b,   n, i, A) {
  if (a == "-" || b == "-" || a == "" || b == "") return 0
  n = split(a, A, ";")
  for (i = 1; i <= n; i++) if (index(";" b ";", ";" A[i] ";") > 0) return 1
  return 0
}
# add n to a ";"-joined set (unique)
function addto(s, n) { if (s == "" || s == "-") return n; if (inlist(s, n)) return s; return s ";" n }
