# One row per code or test file of a pull request: number, path after, path before, status, has_patch (1 or 0)
def code_or_test: test("^(apps/[^/]+/)?(test/|(lib|web)/.*\\.(ex|heex|eex|leex)$)");
(input_filename | capture("(?<n>[0-9]+)\\.json$") | .n) as $n
| .[]
| . as $f
| (if $f.status == "renamed" and $f.previous_filename != null then $f.previous_filename else $f.filename end) as $old
| select(($f.filename | code_or_test) or ($old | code_or_test))
| [$n, $f.filename, $old, $f.status, (if $f.patch != null then 1 else 0 end)] | @tsv
