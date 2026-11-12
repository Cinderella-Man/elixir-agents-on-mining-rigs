# Step 7: summary.tsv from the stream summarize.sh builds: screen rows as "S<TAB>repo<TAB>row", pairs as "P<TAB>row".
# COPY of 2026-11-12_pilot_pr_screen/run/summarize.awk with one change: the years of the cand_y<year> columns come from -v Y0 and -v Y1
# (the pilot's were fixed at 2016 to 2026). Everything else is unchanged.
# Columns after the two prefix fields of a screen row (the screen file's own columns, in order): number, merged_at, year,
# verdict, reason, reason_pr, rules, group, code_files, test_files, adds_migration, touches_assets, ai_tool, ai_signals,
# named_by, reverted_by, repaired_by, repair_of, repair_chain, touched_again_tests, issue_linked, body_chars, base_main.
BEGIN {
  FS = "\t"; OFS = "\t"
  nr = split("no_code_change no_test_change bot dependency_only docs_only ci_only mix_files revert reverted_later repaired_by", RULE, " ")
  ny = 0; for (y = Y0 + 0; y <= Y1 + 0; y++) YR[++ny] = y      # -v Y0, -v Y1: the years of the cand_y<year> columns
  nsig = split("footer coauthor statement merge_commit author_login", SIG, " ")
  nrepo = 0
}
$1 == "S" {
  repo = $2
  if (!(repo in seen)) { seen[repo] = 1; order[++nrepo] = repo }
  c[repo, "merged"]++
  verdict = $6; reason = $7; group = $10
  if (verdict == "candidate") {
    c[repo, "candidates"]++
    if (group == "1") c[repo, "cand_group_1"]++; else if (group == "2-5") c[repo, "cand_group_2_5"]++; else c[repo, "cand_group_6plus"]++
    c[repo, "cand_y" $5]++
    if ($15 == 1) c[repo, "cand_ai"]++; else c[repo, "cand_not_ai"]++
    if ($13 == 1) c[repo, "cand_migration"]++
    if ($14 == 1) c[repo, "cand_assets"]++
    if ($17 != "-") c[repo, "cand_named"]++
    if ($22 != "-") c[repo, "cand_touched_again"]++
    if ($23 == 1) c[repo, "cand_issue_linked"]++
    if ($25 == 0) c[repo, "cand_nonmain_base"]++
    if ($20 != "-") c[repo, "cand_repair"]++
    if (group == "2-5" && $13 == 0 && $14 == 0) c[repo, "cand_2_5_clean"]++
  } else { c[repo, "rejected"]++; c[repo, "first_" reason]++ }
  n = split($9, H, ";")
  for (k = 1; k <= n; k++) if (H[k] != "-") c[repo, "hit_" H[k]]++
  if ($15 == 1) {
    c[repo, "merged_ai"]++
    m = split($16, G, ";"); for (k = 1; k <= m; k++) c[repo, "merged_ai_" G[k]]++
  }
  if ($17 != "-") c[repo, "prs_named"]++
  if ($19 != "-") c[repo, "prs_repaired"]++
  if ($20 != "-") c[repo, "prs_repairing"]++
  # a chain is counted once, at its last pull request (the one that is not repaired itself)
  if ($19 == "-" && $21 + 0 >= 3) c[repo, "chains_3plus"]++
  if ($19 == "-" && $21 + 0 >= 4) c[repo, "chains_4plus"]++
  if ($19 == "-" && $21 + 0 >= 2) c[repo, "chains_all"]++
  next
}
$1 == "P" {
  # repo, earlier, later, route, days, rank_gap, status, shared_files, patch_missing, lines_matched, lines_same_place, repaired
  repo = $2; c[repo, "pairs_named"]++
  if ($5 ~ /mention/) c[repo, "pairs_via_mention"]++
  if ($5 ~ /issue/) c[repo, "pairs_via_issue"]++
  if ($8 == "tested") { c[repo, "pairs_tested"]++; if ($9 == 0) c[repo, "pairs_tested_no_shared_file"]++; if ($10 == 1) c[repo, "pairs_patch_missing"]++
    if ($13 == 1) { c[repo, "pairs_repaired"]++; if ($12 >= 1) c[repo, "pairs_repaired_same_place"]++ } }
  else if ($8 == "revert") c[repo, "pairs_revert"]++
  else c[repo, "pairs_no_code_or_test"]++
  next
}
END {
  nc = 0
  COL[++nc] = "merged"; COL[++nc] = "candidates"; COL[++nc] = "rejected"
  for (k = 1; k <= nr; k++) COL[++nc] = "first_" RULE[k]
  for (k = 1; k <= nr; k++) COL[++nc] = "hit_" RULE[k]
  COL[++nc] = "pairs_named"; COL[++nc] = "pairs_via_mention"; COL[++nc] = "pairs_via_issue"; COL[++nc] = "pairs_tested"; COL[++nc] = "pairs_tested_no_shared_file"; COL[++nc] = "pairs_revert"; COL[++nc] = "pairs_no_code_or_test"
  COL[++nc] = "pairs_patch_missing"; COL[++nc] = "pairs_repaired"; COL[++nc] = "pairs_repaired_same_place"
  COL[++nc] = "prs_named"; COL[++nc] = "prs_repaired"; COL[++nc] = "prs_repairing"; COL[++nc] = "chains_all"; COL[++nc] = "chains_3plus"; COL[++nc] = "chains_4plus"
  COL[++nc] = "cand_group_1"; COL[++nc] = "cand_group_2_5"; COL[++nc] = "cand_group_6plus"
  for (k = 1; k <= ny; k++) COL[++nc] = "cand_y" YR[k]
  COL[++nc] = "cand_ai"; COL[++nc] = "cand_not_ai"
  COL[++nc] = "merged_ai"; for (k = 1; k <= nsig; k++) COL[++nc] = "merged_ai_" SIG[k]
  COL[++nc] = "cand_migration"; COL[++nc] = "cand_assets"; COL[++nc] = "cand_named"; COL[++nc] = "cand_touched_again"
  COL[++nc] = "cand_repair"; COL[++nc] = "cand_issue_linked"; COL[++nc] = "cand_nonmain_base"; COL[++nc] = "cand_2_5_clean"
  line = "repo"; for (k = 1; k <= nc; k++) line = line OFS COL[k]
  print line
  for (i = 1; i <= nrepo; i++) {
    line = order[i]
    for (k = 1; k <= nc; k++) { v = c[order[i], COL[k]] + 0; line = line OFS v; tot[COL[k]] += v }
    print line
  }
  line = "Together"; for (k = 1; k <= nc; k++) line = line OFS tot[COL[k]]
  print line
}
