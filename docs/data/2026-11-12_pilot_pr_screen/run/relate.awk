# Step 3, awk part: input is the joined base table (the census row, then flatten_meta's row), sorted by merge time then
# number. Writes (names from -v):
#   OUT_BASE   one row per pull request: the counts this screen needs, the revert links, the pairs named by later ones
#   OUT_PAIRS  one row per named pair (earlier, later): the route, the days and merged pull requests between, whether
#              the later one is the earlier one's revert, how many repairable paths they share
#   OUT_REV    one row per pull request that looks like a revert, with how its target was found
#   REPO       the repository, owner/name
# Census columns 1-36, meta columns 37-47 (see the two flatten scripts).
#
# Named by a later pull request: a later merged pull request, within the next 50 merged pull requests and 30 days of
# this one's merge (whichever ends first), that (m) names this one by number in its title or body, or (i) closes an
# issue that this one closes too. The mentions of bot-authored pull requests are not read; a bot is never the later one.
# Reverts: the revert's target is the pull request named by GitHub's own pattern (the census's `reverts`: body starting
# "Reverts <ref>#N" or a head branch "revert-N-..."), else the latest earlier pull request whose title is the quoted
# title of a `Revert "<title>"`, else the one earlier merged pull request named in a title that starts with revert.
BEGIN {
  FS = "\t"; OFS = "\t"; DAY30 = 30 * 86400; WIN = 50
  # revert targets read by hand: HAND is a tab-separated file (repo, reverting, reverted, evidence)
  while (HAND != "" && (getline hl < HAND) > 0) { split(hl, HF, "\t"); if (HF[1] == REPO) hand[HF[2]] = HF[3] }
}
{
  r++
  num[r] = $1; at[r] = $2; bot[r] = $4; basebr[r] = $5; nimpl[r] = $13; ntests[r] = $14; nmig[r] = $15; nassets[r] = $17
  ndeps[r] = $18; ndocs[r] = $19; nci[r] = $20; nweb[r] = $22; depsjs[r] = $24; docsonly[r] = $25; crev[r] = $26
  crevnum[r] = $27; ftests[r] = $32; listed[r] = $9; paths[r] = $36
  btype[r] = $39; bodych[r] = $40; ai[r] = $41; closing[r] = $42; ment[r] = $43; tkey[r] = $44; rtt[r] = $45
  rstart[r] = ($46 == "true") ? 1 : 0; rword[r] = ($47 == "true") ? 1 : 0; ep[r] = $38
  census_ment[r] = $35; census_close[r] = $12
  idx[$1] = r
  if ($1 != $37) { print "row mismatch: census " $1 " meta " $37 > "/dev/stderr"; bad = 1 }
  np = split($36, P, ";")
  tf = 0; cp = 0
  for (k = 1; k <= np; k++) {
    if (cls(P[k]) == "tests" && P[k] ~ /_test\.exs$/) tf++
    if (repairable(P[k])) { cp++; rp[r] = (rp[r] == "" ? P[k] : rp[r] ";" P[k]) }
  }
  ntestfiles[r] = tf; nrepairable[r] = cp
  if (!(tkey[r] in titleidx)) titleidx[tkey[r]] = ""
  tlist[tkey[r]] = tlist[tkey[r]] (tlist[tkey[r]] == "" ? "" : " ") r      # rows with this title, ascending
}
END {
  if (bad) exit 1
  # the mentions the census read must be among the ones read here (this one also reads URLs)
  for (j = 1; j <= r; j++) {
    if (census_ment[j] == "-") continue
    m = split(census_ment[j], M, ";")
    for (a = 1; a <= m; a++) if (!inlist(ment[j], M[a])) { missing_ment++; print "census mention not found in mentions_all: pr " num[j] " -> " M[a] > "/dev/stderr" }
  }
  # issues: the census counted them, this reads their numbers
  for (j = 1; j <= r; j++) {
    nc = (closing[j] == "-") ? 0 : split(closing[j], C, ";")
    if (nc != census_close[j] && !(census_close[j] > 20)) { close_diff++ }
  }
  # reverts
  for (j = 1; j <= r; j++) {
    tgt[j] = 0; how[j] = "-"
    if (!(crev[j] == 1 || rstart[j] || rword[j])) continue
    if (crevnum[j] != "-" && (crevnum[j] in idx) && idx[crevnum[j]] < j) { tgt[j] = idx[crevnum[j]]; how[j] = "github_pattern" }
    else if (rtt[j] != "-" && (rtt[j] in tlist)) {
      m = split(tlist[rtt[j]], T, " ")
      for (a = 1; a <= m; a++) if (T[a] + 0 < j) { tgt[j] = T[a] + 0; how[j] = "quoted_title" }   # the latest earlier one
    }
    if (!tgt[j] && (num[j] in hand) && (hand[num[j]] in idx) && idx[hand[num[j]]] < j) { tgt[j] = idx[hand[num[j]]]; how[j] = "by_hand" }
    if (!tgt[j] && rstart[j] && ment[j] != "-") {
      m = split(ment[j], M, ";"); c = 0; last = 0
      for (a = 1; a <= m; a++) if ((M[a] in idx) && idx[M[a]] < j) { c++; last = idx[M[a]] }
      if (c == 1) { tgt[j] = last; how[j] = "named_in_title_or_body" }
    }
    nrev++
    print num[j], at[j], (crev[j] == 1) ? 1 : 0, rstart[j], rword[j], (tgt[j] ? num[tgt[j]] : "-"), how[j] > OUT_REV
    if (tgt[j]) revby[tgt[j]] = addto(revby[tgt[j]], num[j])
  }
  # named pairs
  for (i = 1; i <= r; i++) {
    for (j = i + 1; j <= r && j - i <= WIN; j++) {
      if (ep[j] - ep[i] > DAY30) break
      if (bot[j]) continue
      route = ""
      if (inlist(ment[j], num[i])) route = "mention"
      if (share(closing[i], closing[j])) route = (route == "" ? "issue" : route "+issue")
      if (route == "") continue
      shared = 0
      if (rp[i] != "" && rp[j] != "") {
        n1 = split(rp[i], A, ";")
        for (a = 1; a <= n1; a++) if (inlist(rp[j], A[a])) shared++
      }
      isrev = (tgt[j] == i) ? 1 : 0
      print num[i], num[j], route, int((ep[j] - ep[i]) / 86400 * 10) / 10, j - i, isrev, shared, nrepairable[i], nrepairable[j] > OUT_PAIRS
      namedby[i] = addto(namedby[i], num[j])
    }
  }
  print "num", "merged_at", "year", "base_main", "bot", "author_type", "files_listed", "n_code", "n_test_files", "n_tests_all", "n_migrations", "n_assets", "n_deps", "n_ci", "n_docs",
        "ci_only", "deps_only_js", "docs_only", "revert_flag", "reverts_num", "reverted_by", "named_by", "followed_by_tests", "body_chars", "issue_linked", "closing", "ai_signals", "paths_repairable" > OUT_BASE
  for (i = 1; i <= r; i++) {
    year = substr(at[i], 1, 4)
    bm = (basebr[i] == "main" || basebr[i] == "master") ? 1 : 0
    cionly = (listed[i] > 0 && nci[i] == listed[i]) ? 1 : 0
    issue = (closing[i] != "-") ? 1 : 0
    print num[i], at[i], year, bm, bot[i], btype[i], listed[i], nimpl[i] + nweb[i], ntestfiles[i], ntests[i], nmig[i], nassets[i], ndeps[i], nci[i], ndocs[i],
          cionly, depsjs[i], docsonly[i], (crev[i] == 1 || rstart[i]) ? 1 : 0, (tgt[i] ? num[tgt[i]] : "-"), (revby[i] == "" ? "-" : revby[i]),
          (namedby[i] == "" ? "-" : namedby[i]), ftests[i], bodych[i], issue, closing[i], ai[i], (rp[i] == "" ? "-" : rp[i]) > OUT_BASE
  }
  printf "%s: %d rows, %d revert-like, census mentions not found %d, closing-count differences %d\n", REPO, r, nrev, missing_ment + 0, close_diff + 0 > "/dev/stderr"
}
