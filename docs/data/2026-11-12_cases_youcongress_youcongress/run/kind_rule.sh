#!/usr/bin/env bash
# kind_rule.sh: each task folder's kind by the bundle maker's written rule (a feature when the reference adds a file or
# a public function it does not also remove, else a bug fix), read one line at a time, beside the kind its case.json
# carries. The maker's own reading (Eab.BundleMaker.task_kind/1) matches `^\+\s*def` across lines, so an added blank
# line before an unchanged `def` counts as an added function there.
#   kind_rule.sh DEST > kind_rule.tsv
# Prints: task, kind in case.json, kind by the written rule, files added, public functions added (added minus removed,
# by name), and the names.
set -euo pipefail
export LC_ALL=C
DEST=${1:?the folder of task folders}
printf 'task\tkind_case_json\tkind_by_rule\tfiles_added\tpublic_functions_added\tnames\n'
for d in "$DEST"/*/; do
  p=$d/reference.patch
  [ -f "$p" ] || continue
  added=$(grep -c '^new file mode ' "$p" || true)
  defs() { sed -nE "s/^\\$1[[:space:]]*def[[:space:]]+([a-z_][A-Za-z0-9_?!]*).*/\\1/p" "$p" | sort; }
  names=$(comm -23 <(defs +) <(defs -) | tr '\n' ' ' | sed 's/ $//')
  n=$(printf '%s' "$names" | wc -w)
  if [ "$added" -gt 0 ] || [ "$n" -gt 0 ]; then k=feature; else k=bug_fix; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(basename "$d")" "$(jq -r .task_kind "$d/case.json")" "$k" "$added" "$n" "${names:--}"
done
