#!/usr/bin/env bash
# Step 2. Raw pages -> one row per merged pull request with flags only. Titles and bodies are read here to compute
# the flags and are written nowhere that is committed: the title key (a lower-cased title, used to find which pull
# request a revert reverts) stays in $WORK.
#   RAW   the folder fetch_meta.sh wrote
#   WORK  output folder; writes $WORK/meta_<owner>__<name>.tsv, sorted by merge time, then number
# Columns: number, epoch, author_type, body_chars, ai_signals, closing, mentions_all, title_key, revert_target_title,
#          revert_start, revert_word
#   ai_signals   `;`-joined names of the signals that fired, `-` if none:
#                footer       the body says "Generated with/by <tool>" or links a coding tool's page
#                coauthor     the body has a Co-Authored-By trailer naming a coding tool
#                statement    the body says it was written/generated/created/drafted/implemented with or by a coding
#                             tool or "an AI"
#                merge_commit the merge commit's message has one of the three above
#                author_login the author's login is a coding tool's agent account
#   closing      issues GitHub records as closed by the pull request: `N`, or `owner/name#N` for another repository
#   mentions_all every `#N`, `<this repository>#N`, and `github.com/<this repository>/(pull|issues)/N` in title and body
#                (not its own number), `;`-joined
#   revert_start the title starts with revert, reverts, reverted or reverting
#   revert_word  the title has the word revert (or a form of it) anywhere
set -euo pipefail
: "${RAW:?raw pages}"; : "${WORK:?output folder}"
mkdir -p "$WORK"
for dir in "$RAW"/meta/*__*/; do
  slug=$(basename "$dir"); repo="${slug/__//}"
  re=$(printf '%s' "$repo" | sed 's/[.]/\\./g')      # the repository's own name as a regular expression
  jq -r --arg repo "$repo" --arg re "$re" '
    def tools: "claude|anthropic|copilot|cursor|codex|gemini|devin|aider|windsurf|chatgpt|openai|opencode|cline";
    def footer($t): ($t | test("generated\\s+(with|by)\\s+(\\[\\s*)?(" + tools + ")"; "i"))
                    or ($t | test("claude\\.com/claude-code|claude\\.ai/code|anthropic\\.com/claude-code"; "i"));
    def coauthor($t): ($t | test("co-authored-by:[^\\n]*(" + tools + ")"; "i"));
    def statement($t): ($t | test("(written|authored|generated|created|drafted|implemented|coded)\\s+(with|by|using)\\s+(the\\s+help\\s+of\\s+)?(" + tools + "|an?\\s+(ai|llm))\\b"; "i"));
    def norm: ascii_downcase | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");
    .data.repository.pullRequests.nodes[]
    | . as $p
    | (($p.title // "") | gsub("[\\t\\r\\n]+"; " ")) as $title
    | ($p.body // "") as $body
    | ($p.mergeCommit.message // "") as $mc
    | ($p.author.login // "-") as $login
    | (($title + "\n" + $body)) as $text
    | ([ $text | scan("(?:^|[^A-Za-z0-9_/&.-])#([0-9]+)(?![0-9])") | .[0] ]
       + [ $text | scan("(?<![A-Za-z0-9_/.-])" + $re + "#([0-9]+)(?![0-9])") | .[0] ]
       + [ $text | scan("github\\.com/" + $re + "/(?:pull|issues)/([0-9]+)(?![0-9])") | .[0] ]
       | map(tonumber) | map(select(. != $p.number)) | unique | map(tostring) | join(";")) as $mentions
    | ([ (if footer($body) then "footer" else empty end),
         (if coauthor($body) then "coauthor" else empty end),
         (if statement($body) then "statement" else empty end),
         (if (footer($mc) or coauthor($mc) or statement($mc)) then "merge_commit" else empty end),
         (if ($login | test("^(claude|copilot|copilot-swe-agent|devin-ai-integration|codex|cursor|openai-codex|chatgpt-codex-connector)(\\[bot\\])?$|copilot-swe-agent|devin-ai"; "i")) then "author_login" else empty end)
       ] | join(";")) as $ai
    | ([ $p.closingIssuesReferences.nodes[]
         | if .repository.nameWithOwner == $repo then (.number | tostring)
           else (.repository.nameWithOwner + "#" + (.number | tostring)) end ] | join(";")) as $closing
    | (($title | capture("^\\s*Revert\\s+[\"“](?<t>.*)[\"”]\\s*$"; "i") | .t | norm) // "") as $rtt
    | [ $p.number,
        ($p.mergedAt | fromdateiso8601),
        ($p.author.__typename // "-"),
        ($body | length),
        (if $ai == "" then "-" else $ai end),
        (if $closing == "" then "-" else $closing end),
        (if $mentions == "" then "-" else $mentions end),
        ($title | norm),
        (if $rtt == "" then "-" else $rtt end),
        ($title | test("^\\s*revert(s|ed|ing)?\\b"; "i")),
        ($title | test("\\brevert"; "i"))
      ] | @tsv' "$dir"/pr_*.json | sort -t$'\t' -k2,2n -k1,1n > "$WORK/meta_$slug.tsv"
  echo "$repo: $(wc -l < "$WORK/meta_$slug.tsv") rows"
done
