# One row per added and per removed line of the code and test files in a pull request's per-file patches:
#   number, sign (+ or -), path, line number, the line (tab, newline and backslash escaped by @tsv)
# An added line's path is the file's path after the pull request; a removed line's path is the path before it (the
# previous name of a renamed file). The line number is the new file's for an added line and the old file's for a
# removed one. Files without a patch (binary, too large) give no rows; files.jq lists them.
def code_or_test: test("^(apps/[^/]+/)?(test/|(lib|web)/.*\\.(ex|heex|eex|leex)$)");
(input_filename | capture("(?<n>[0-9]+)\\.json$") | .n) as $n
| .[]
| select(.patch != null)
| . as $f
| (if $f.status == "renamed" and $f.previous_filename != null then $f.previous_filename else $f.filename end) as $old
| select(($f.filename | code_or_test) or ($old | code_or_test))
| foreach ($f.patch | split("\n"))[] as $l (
    {o: 0, n: 0, out: null};
    if ($l | startswith("@@")) then
      (($l | capture("^@@ -(?<a>[0-9]+)(?:,[0-9]+)? \\+(?<b>[0-9]+)")) as $m
       | {o: ($m.a | tonumber), n: ($m.b | tonumber), out: null})
    elif ($l | startswith("+")) then {o: .o, n: (.n + 1), out: ["+", $f.filename, .n, ($l[1:])]}
    elif ($l | startswith("-")) then {o: (.o + 1), n: .n, out: ["-", $old, .o, ($l[1:])]}
    elif ($l | startswith("\\")) then {o: .o, n: .n, out: null}
    else {o: (.o + 1), n: (.n + 1), out: null} end;
    .out | select(. != null))
| [$n] + . | @tsv
