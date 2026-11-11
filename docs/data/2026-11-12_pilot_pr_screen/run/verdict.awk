# Step 6: the verdict of every merged pull request of one repository. Inputs: the base table relate.awk wrote, then the
# tested pairs repair.sh wrote. Output: the screen rows (stdout) and, with -v OUT_PAIRS=<file>, the pairs with the repo.
# -v REPO=<owner/name>.
#
# Verdict: `rejected` with the first of these rules that applies (the reason), else `candidate`:
#   no_code_change      no changed path in lib/ (.ex .heex .eex .leex) or, in ex338's older layout, web/
#   no_test_change      no changed `_test.exs` path under test/
#   bot                 the author is a bot
#   dependency_only     every path is mix.exs, mix.lock or a JavaScript manifest or lock file
#   docs_only           every path is documentation
#   ci_only             every path is under .github/
#   mix_files           the pull request changes mix.exs or mix.lock
#   revert              the pull request is a revert (its title starts with revert, or GitHub's revert branch or body)
#   reverted_later      a later merged pull request reverts it (reason_pr: the first one)
#   repaired_by         a later pull request of a named pair changes lines that it added (reason_pr: the first one)
# `rules` lists every rule that applies, in that order; the reason is the first.
# Marks (all rows): group by code files (1, 2-5, 6+), year, adds_migration, touches_assets, ai_tool (and ai_signals),
# named_by (later pull requests naming it), touched_again_tests (census: later pull requests changing the same test
# file within 30 days), repair_of (the earlier pull requests this one repairs) and repair_chain (how many pull requests
# the chain ending here has: this one and the ones it repairs, the ones they repair, ...; 0 if it repairs none).
BEGIN { FS = "\t"; OFS = "\t" }
FILENAME == BASE && FNR == 1 { next }
FILENAME == BASE {
  r++
  num[r] = $1; at[r] = $2; year[r] = $3; bm[r] = $4; bot[r] = $5; ncode[r] = $8; ntf[r] = $9; nmig[r] = $11; nassets[r] = $12
  ndeps[r] = $13; cionly[r] = $16; depsjs[r] = $17; docsonly[r] = $18; revflag[r] = $19; revby[r] = $21; namedby[r] = $22
  ftests[r] = $23; bodych[r] = $24; issue[r] = $25; ai[r] = $27
  idx[$1] = r
  next
}
{
  # a tested pair: earlier, later, route, days, rank_gap, status, shared_files, patch_missing, lines_matched, same_place, repaired
  npair++
  if ($6 == "tested") ntested++
  if ($6 == "revert") nrevpair++
  if ($11 == 1) {
    nrepaired++
    rb[$1] = addto(rb[$1], $2)
    ro[$2] = addto(ro[$2], $1)
  }
  if ($6 == "tested" && $8 == 1) nmiss++
  if ($6 == "tested" && $11 == 0 && $8 == 1) nmiss_unrep++
}
function first(s,   a) { split(s, a, ";"); return a[1] }
function minlist(s,   a, n, i, m) { n = split(s, a, ";"); m = a[1] + 0; for (i = 2; i <= n; i++) if (a[i] + 0 < m) m = a[i] + 0; return m }
END {
  # chain length, in order of merge: a pull request that repairs none is a chain of one; one that repairs others
  # extends the longest chain among them
  for (i = 1; i <= r; i++) {
    base_len[i] = 1
    if (ro[num[i]] != "") {
      m = split(ro[num[i]], E, ";"); best = 1
      for (k = 1; k <= m; k++) if ((E[k] in idx) && chain[idx[E[k]]] + 0 > best) best = chain[idx[E[k]]] + 0
      chain[i] = best + 1
    } else chain[i] = 1
  }
  print "number", "merged_at", "year", "verdict", "reason", "reason_pr", "rules", "group", "code_files", "test_files", "adds_migration", "touches_assets",
        "ai_tool", "ai_signals", "named_by", "reverted_by", "repaired_by", "repair_of", "repair_chain", "touched_again_tests", "issue_linked", "body_chars", "base_main"
  for (i = 1; i <= r; i++) {
    n = num[i]; rules = ""; reason = ""; rpr = "-"
    if (ncode[i] == 0) rules = rules ";no_code_change"
    if (ntf[i] == 0) rules = rules ";no_test_change"
    if (bot[i]) rules = rules ";bot"
    if (depsjs[i]) rules = rules ";dependency_only"
    if (docsonly[i]) rules = rules ";docs_only"
    if (cionly[i]) rules = rules ";ci_only"
    if (ndeps[i] > 0) rules = rules ";mix_files"
    if (revflag[i]) rules = rules ";revert"
    if (revby[i] != "-") rules = rules ";reverted_later"
    if (rb[n] != "") rules = rules ";repaired_by"
    rules = (rules == "") ? "-" : substr(rules, 2)
    if (rules == "-") { verdict = "candidate"; reason = "-" }
    else {
      verdict = "rejected"; reason = first(rules)
      if (reason == "reverted_later") rpr = minlist(revby[i])
      if (reason == "repaired_by") rpr = minlist(rb[n])
    }
    g = (ncode[i] == 0) ? "0" : (ncode[i] == 1) ? "1" : (ncode[i] <= 5) ? "2-5" : "6+"
    print n, at[i], year[i], verdict, reason, rpr, rules, g, ncode[i], ntf[i], (nmig[i] > 0) ? 1 : 0, (nassets[i] > 0) ? 1 : 0,
          (ai[i] != "-") ? 1 : 0, ai[i], namedby[i], revby[i], (rb[n] == "" ? "-" : rb[n]), (ro[n] == "" ? "-" : ro[n]),
          (ro[n] == "" ? 0 : chain[i]), ftests[i], issue[i], bodych[i], bm[i]
  }
  printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\n", REPO, npair, ntested, nrevpair, nrepaired, nmiss, nmiss_unrep > OUT_PAIRSTAT
}
