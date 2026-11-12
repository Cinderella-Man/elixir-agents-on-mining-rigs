# The text of one `git diff` (run with -R -s) as the list GitHub's REST API gives for a pull request's files
# (pulls/N/files): [{filename, status, previous_filename, patch, additions, deletions}], so that the pilot's files.jq and
# lines.jq read it unchanged. `patch` holds the hunks from the first `@@` line, as GitHub gives them; a file with no hunk
# (binary, a rename with no change, a mode change) has none. status is added, removed, renamed or modified.
def path_of($s): if $s == null or $s == "/dev/null" then null else ($s | sub("^[ab]/"; "")) end;
split("\n")
| reduce .[] as $l ({files: [], cur: null};
    if ($l | startswith("diff --git ")) then
      (if .cur != null then .files += [.cur] else . end)
      | .cur = {git: ($l | capture("^diff --git a/(?<a>.*) b/(?<b>.*)$") // {a: null, b: null}),
                status: "modified", from: null, to: null, old: null, new: null, hunk: false, lines: [], additions: 0, deletions: 0}
    elif .cur == null then .
    elif .cur.hunk then
      if $l == "" then .
      elif ($l | startswith("+")) then .cur.lines += [$l] | .cur.additions += 1
      elif ($l | startswith("-")) then .cur.lines += [$l] | .cur.deletions += 1
      else .cur.lines += [$l] end
    elif ($l | startswith("new file mode")) then .cur.status = "added"
    elif ($l | startswith("deleted file mode")) then .cur.status = "removed"
    elif ($l | startswith("rename from ")) then .cur.status = "renamed" | .cur.from = $l[12:]
    elif ($l | startswith("rename to ")) then .cur.to = $l[10:]
    elif ($l | startswith("--- ")) then .cur.old = $l[4:]
    elif ($l | startswith("+++ ")) then .cur.new = $l[4:]
    elif ($l | startswith("@@")) then .cur.hunk = true | .cur.lines += [$l]
    else . end)
| (if .cur != null then .files + [.cur] else .files end)
| map(. as $f
    | { filename: (if $f.status == "renamed" then $f.to
                   elif $f.status == "removed" then (path_of($f.old) // $f.git.a)
                   else (path_of($f.new) // $f.git.b) end),
        status: $f.status,
        previous_filename: (if $f.status == "renamed" then $f.from else null end),
        patch: (if ($f.lines | length) > 0 then ($f.lines | join("\n")) else null end),
        additions: $f.additions, deletions: $f.deletions })
