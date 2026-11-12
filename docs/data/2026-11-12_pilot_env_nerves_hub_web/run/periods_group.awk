# Groups the rows of periods.sh into periods: one period per toolchain the engine must provide (Elixir, OTP, the
# Postgres image, the ClickHouse image). Elixir and OTP come from .tool-versions, or from CI's Elixir image when
# .tool-versions names none. Periods are numbered from the newest (P01). Writes periods.tsv (each candidate with its
# period) and, with SUMMARY set, the per-period summary to that file.
# Usage: awk -F'\t' -v SUMMARY=periods_summary.tsv -f periods_group.awk periods_raw.tsv > periods.tsv
function field(tv, name,    n, i, parts, kv) {
  n = split(tv, parts, ";")
  for (i = 1; i <= n; i++) { split(parts[i], kv, " "); if (kv[1] == name) return kv[2] }
  return ""
}
NR == 1 { header = $0; next }
{
  row[NR] = $0
  if ($2 == "missing") { key[NR] = "missing"; } else {
    el = field($4, "elixir"); er = field($4, "erlang")
    if (el == "") { el = ($9 == "-" ? "?" : $9); er = "-" }
    pg = $10; gsub(/(circleci|cimg)\//, "", pg)
    key[NR] = el "\t" er "\t" pg "\t" $11
  }
  k = key[NR]
  count[k]++
  if (!(k in last) || $3 > last[k]) last[k] = $3
  if (!(k in first) || $3 < first[k]) first[k] = $3
  installs[k, $12] = 1; tests[k, $13] = 1
}
END {
  n = 0
  for (k in count) if (k != "missing") order[++n] = k
  # newest last merge first
  for (i = 1; i <= n; i++) for (j = i + 1; j <= n; j++) if (last[order[j]] > last[order[i]]) { t = order[i]; order[i] = order[j]; order[j] = t }
  for (i = 1; i <= n; i++) label[order[i]] = sprintf("P%02d", i)
  label["missing"] = "missing"
  print "period\t" header
  for (r = 2; r <= NR; r++) print label[key[r]] "\t" row[r]
  if (SUMMARY != "") {
    print "period\tfrom\tto\tcandidates\telixir\totp\tpostgres\tclickhouse\tci_installs\tci_test" > SUMMARY
    order[n + 1] = "missing"
    for (i = 1; i <= n + (("missing" in count) ? 1 : 0); i++) {
      k = order[i]; inst = ""; tst = ""
      for (c in installs) { split(c, p, SUBSEP); if (p[1] == k) inst = inst (inst == "" ? "" : " || ") p[2] }
      for (c in tests) { split(c, p, SUBSEP); if (p[1] == k) tst = tst (tst == "" ? "" : " || ") p[2] }
      kk = (k == "missing" ? "-\t-\t-\t-" : k)
      print label[k] "\t" substr(first[k], 1, 10) "\t" substr(last[k], 1, 10) "\t" count[k] "\t" kk "\t" inst "\t" tst > SUMMARY
    }
  }
}
