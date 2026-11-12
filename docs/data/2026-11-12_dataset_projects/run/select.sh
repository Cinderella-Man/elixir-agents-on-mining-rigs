#!/bin/sh
# Selects the dataset's projects from the pool table of approved applications.
#
#   select.sh <approved_app_first_batch.tsv> <cutoff YYYY-MM-DD> chosen     the projects that pass every rule
#   select.sh <approved_app_first_batch.tsv> <cutoff YYYY-MM-DD> left_out   the other applications, each with the
#                                                                          first rule it fails
#
# The rules, in the order they are tested (columns of the pool table):
#   1. group        is "application"
#   2. licence      is MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause or ISC (the repository's stated licence; the
#                   licence of every file a task touches is checked again per task, at the task's commit)
#   3. last_pushed  is on or after the cutoff (six months before the day of the decision)
#   4. mix_elixir   names Elixir 1.18 or newer (the first "1.NN" in the requirement string)
set -eu
TABLE=$1
CUTOFF=$2
MODE=${3:-chosen}

awk -F'\t' -v cutoff="$CUTOFF" -v mode="$MODE" '
function fails(   minor, a) {
  if ($3 != "application") return "not an application"
  if (!($6 == "MIT" || $6 == "Apache-2.0" || $6 == "BSD-2-Clause" || $6 == "BSD-3-Clause" || $6 == "ISC")) return "licence outside the list: " $6
  if ($14 < cutoff) return "not pushed to since " cutoff " (last push " $14 ")"
  if (!match($12, /1\.[0-9]+/)) return "mix.exs states no Elixir version"
  split(substr($12, RSTART, RLENGTH), a, ".")
  minor = a[2] + 0
  if (minor < 18) return "mix.exs asks for Elixir " $12
  return ""
}
NR == 1 {
  if (mode == "chosen") print "repo\tmirror\tlicence\tlicence_file_reads_as\tmerged_prs\telixir_share\tuses\tmix_elixir\tservice_deps\tlast_pushed"
  else print "repo\tlicence\tmerged_prs\tmix_elixir\tlast_pushed\tfirst_rule_failed"
  next
}
$3 == "application" {
  why = fails()
  if (mode == "chosen" && why == "") print $1 "\t" $5 "\t" $6 "\t" $7 "\t" $9 "\t" $10 "\t" $11 "\t" $12 "\t" $13 "\t" $14
  if (mode != "chosen" && why != "") print $1 "\t" $6 "\t" $9 "\t" $12 "\t" $14 "\t" why
}' "$TABLE"
