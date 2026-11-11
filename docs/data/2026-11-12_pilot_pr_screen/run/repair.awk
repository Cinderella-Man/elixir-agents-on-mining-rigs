# Step 5, awk part: does the later pull request of a named pair change lines that the earlier one added?
# Inputs, in this order (names from -v):
#   PAIRS  pairs_<slug>.tsv from relate.awk: earlier, later, route, days, rank_gap, is_revert, shared, nrep_earlier, nrep_later
#   FILES  files_<slug>.tsv (files.jq): number, path after, path before, status, has_patch
#   LINES  lines_<slug>.tsv (lines.jq): number, sign, path, line number, text
# Output (stdout): earlier, later, route, days, rank_gap, status, shared_files, patch_missing, lines_matched,
#   lines_same_place, repaired
#   status  tested | revert | no_code_or_test_in_earlier | no_code_or_test_in_later
#   shared_files   code or test files the later one changes that the earlier one also changed (by path; a renamed file
#                  by its old name in the later one)
#   patch_missing  1 if one of those shared files has no patch in either pull request (GitHub leaves out the patch of a
#                  binary or very large diff), so the test could not read it
#   lines_matched  the lines that the later one removes (or changes) that the earlier one added, in the same file:
#                  compared by text with the spaces trimmed and collapsed, lines of 12 characters or more only (so `end`,
#                  `else`, `)` and the like do not count), each added line matched at most as often as it was added
#   lines_same_place  of those, the lines that also stand at the same line number (the earlier one's new line number is
#                  the later one's old line number): true when nothing else changed the file in between
#   repaired       1 if lines_matched is at least 1, else 0 ("-" when not tested)
# A revert pair (the later one reverts the earlier one) is not a repair; it is listed with status revert.
BEGIN { FS = "\t"; OFS = "\t"; MINLEN = (MINLEN == "") ? 12 : MINLEN + 0 }   # -v MINLEN=n sets the shortest line that counts
function norm(t) { gsub(/\\t/, " ", t); gsub(/[ ]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t); return t }
FILENAME == FILES {
  n = $1
  fk = ++nf[n]; fnew[n, fk] = $2; fold[n, fk] = $3; fhas[n, fk] = $5
  newhas[n, $2] = $5
  next
}
FILENAME == LINES {
  n = $1; t = norm($5)
  if (length(t) < MINLEN) next
  if ($2 == "+") { addc[n, $3, t]++; addpos[n, $3, $4] = t }
  else { k = ++nr[n]; rf[n, k] = $3; rt[n, k] = t; rl[n, k] = $4 }
  next
}
FILENAME == PAIRS {
  e = $1; l = $2; route = $3; days = $4; gap = $5; isrev = $6; shared = $7; ne = $8; nl = $9
  status = "tested"
  if (isrev == 1) status = "revert"
  else if (ne == 0) status = "no_code_or_test_in_earlier"
  else if (nl == 0) status = "no_code_or_test_in_later"
  if (status != "tested") { print e, l, route, days, gap, status, "-", "-", "-", "-", "-"; next }
  # shared files and missing patches
  sf = 0; miss = 0
  for (k = 1; k <= nf[l]; k++) {
    o = fold[l, k]
    if ((e, o) in newhas) { sf++; if (fhas[l, k] == 0 || newhas[e, o] == 0) miss = 1 }
  }
  # matching lines
  matched = 0; same = 0; nu = 0
  for (k = 1; k <= nr[l]; k++) {
    key = e SUBSEP rf[l, k] SUBSEP rt[l, k]
    if (addc[key] - used[key] > 0) {
      used[key]++; ulist[++nu] = key; matched++
      if (((e, rf[l, k], rl[l, k]) in addpos) && addpos[e, rf[l, k], rl[l, k]] == rt[l, k]) same++
    }
  }
  for (k = 1; k <= nu; k++) delete used[ulist[k]]
  print e, l, route, days, gap, status, sf, miss, matched, same, (matched >= 1) ? 1 : 0
}
