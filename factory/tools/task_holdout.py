"""The hold-out check of factory task folders (E12): no task comes from the bench's 12 projects, and no task shares
text with the bench's 20 cases.

(a) Repository: the task's repository is not one of the projects, organisations, repositories or names of
    config/holdout.json (the rule of Eab.BundleMaker.holdout!/3). The case ids (`<project>-pr-<n>`) and the held-out
    repositories (`owner/name`) are also looked for in every text of the task.
(b) Text: every N-word span (default 8 and 12) of every file of the task folder (task_folder.task_texts: all files
    but the fixed integrity.patch) against the spans of the bench's case files (BENCH_FILES: the ticket, case.json
    with its requirement sentences, the hidden and upstream tests, the reference patch, the partial fix and the docs
    patch). Words are the lowercased, whitespace-split words of upstream/heldout_check.py (agx.words), and a span
    keeps the first case file it was seen in, as heldout_check.py does.

Each hit is classed:
  common       the span occurs in the cases of two or more of the bench's projects: text no single held-out
               project owns (diff headers, ExUnit and Phoenix idiom, the shared case.json layout)
  syntax       once the diff markers (`+`, `-`) are dropped, fewer than three of its words are outside a fixed
               list of Elixir, HEEx and diff tokens (SYNTAX: end, do, def, else, nil, ->, `\"\"\"`, @doc, |>, ...)
  own-tree     the span's code view (diff markers dropped, cut at a `diff --git` line) already occurs in the task's
               own project at its starting commit (--trees DIR/<commit>/): the project had the text before the pull
               request, so it did not come from the case
  to-read      neither; a person reads it before the task is used
A task passes when (a) passes, no name is found, and it has no `to-read` hit.

The tables name the task, its file, the case and the case's file, and a span id (the first 12 hex digits of the
span's SHA-256), never the span's text. --local-spans FILE writes the spans themselves to FILE for reading on the
machine that holds the cases; that file is deleted with the cases and never committed.

usage: python task_holdout.py --bench CASES_DIR [--holdout holdout.json] [--trees DIR] [--n 8,12] --out PREFIX
                              [--local-spans FILE] TASK_DIR [...]
  writes PREFIX.hits.tsv, PREFIX.tasks.tsv and PREFIX.json (counts)
Standard library only.
"""
import argparse
import hashlib
import json
import os
import re
import sys
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import task_folder  # noqa: E402

BENCH_FILES = ["ticket.md", "case.json", "acceptance.patch", "reference-tests.patch", "upstream-tests.patch",
               "reference.patch", "incomplete.patch", "upstream-docs.patch"]


def words(text):
    """upstream/heldout_check.py's words (agx.words)."""
    return text.lower().split()


def span_id(span):
    return hashlib.sha256(span.encode()).hexdigest()[:12]


def held(repository_url, holdout):
    parts = urlparse(repository_url).path.strip("/").split("/")
    owner, name = (parts + ["", ""])[:2]
    low = str.lower
    repo = f"{owner}/{name}".lower()
    reasons = []
    if low(owner) in map(low, holdout["organisations"]):
        reasons.append("organisation")
    if repo in map(low, holdout["repositories"]) or repo in (low(p["repository"]) for p in holdout["projects"]):
        reasons.append("repository")
    if low(name) in map(low, holdout["names"]):
        reasons.append("name")
    return reasons


# Elixir, HEEx and diff tokens that carry no wording of their own
SYNTAX = {"+", "-", "end", "do", "def", "defp", "else", "nil", "->", "_", '"""', "@doc", "@moduledoc", "|>", "fn",
          "</div>", "<div>", "=", ",", "(", ")", "[", "]", "{", "}", ":ok", "true", "false", "when", "case", "cond",
          "if", "end)", "end,", "%{", "@impl", "do:", "diff", "--git"}


def code_view(span):
    """The span's words with diff markers dropped and cut at a file boundary (`diff --git`): what the project's own
    files would hold. Returns the longest piece."""
    w = span.split(" ")
    pieces, cur, i = [], [], 0
    while i < len(w):
        if w[i] == "diff" and i + 1 < len(w) and w[i + 1] == "--git":
            pieces.append(cur)
            cur, i = [], i + 4   # diff --git a/<path> b/<path>
            continue
        t = w[i]
        if t not in ("+", "-"):
            cur.append(t[1:] if len(t) > 1 and t[0] in "+-" and (t[1].isalpha() or t[1] in "@%{:<\"")
                       else t)
        i += 1
    pieces.append(cur)
    return tuple(max(pieces, key=len))


def is_syntax(span):
    """Fewer than three words outside SYNTAX once the diff markers are dropped."""
    return len([t for t in code_view(span) if t not in SYNTAX]) < 3


def tree_words(root):
    for d, subdirs, names in os.walk(root):
        subdirs[:] = [s for s in subdirs if s != ".git"]
        for n in names:
            p = os.path.join(d, n)
            if os.path.islink(p) or not os.path.isfile(p):
                continue
            try:
                with open(p, "rb") as f:
                    data = f.read(4 * 1024 * 1024)
                if b"\0" in data[:8192]:
                    continue
                yield words(data.decode("utf-8", errors="replace"))
            except OSError:
                pass


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tasks", nargs="+")
    ap.add_argument("--bench", required=True)
    ap.add_argument("--holdout", default=os.path.join(HERE, "..", "config", "holdout.json"))
    ap.add_argument("--trees")
    ap.add_argument("--n", default="8,12")
    ap.add_argument("--out", required=True)
    ap.add_argument("--local-spans")
    a = ap.parse_args()
    ns = [int(x) for x in a.n.split(",")]
    holdout = json.load(open(a.holdout))

    cases = sorted(c for c in os.listdir(a.bench) if os.path.isdir(os.path.join(a.bench, c)))
    spans = {n: {} for n in ns}      # span -> (case, file) first seen, as heldout_check.py keeps it
    projects = {n: {} for n in ns}   # span -> set of bench projects it occurs in
    bench_words = 0
    for c in cases:
        proj = re.sub(r"-pr-\d+$", "", c)
        for fn in BENCH_FILES:
            p = os.path.join(a.bench, c, fn)
            if not os.path.exists(p):
                continue
            w = words(open(p, encoding="utf-8", errors="replace").read())
            bench_words += len(w)
            for n in ns:
                for i in range(len(w) - n + 1):
                    s = " ".join(w[i:i + n])
                    spans[n].setdefault(s, (c, fn))
                    projects[n].setdefault(s, set()).add(proj)
    names = sorted(set(cases) | {r.lower() for r in holdout["repositories"]} |
                   {p["repository"].lower() for p in holdout["projects"]})

    tasks = [task_folder.read_task(d) for d in task_folder.task_dirs(a.tasks)]
    hits, name_hits, task_words = [], [], 0
    for t in tasks:
        for fn, text in task_folder.task_texts(t["dir"]):
            low = text.lower()
            for nm in names:
                if re.search(r"(?<![a-z0-9_])" + re.escape(nm) + r"(?![a-z0-9_])", low):
                    name_hits.append((t["id"], fn, nm))
            w = words(text)
            task_words += len(w)
            for n in ns:
                for i in range(len(w) - n + 1):
                    s = " ".join(w[i:i + n])
                    src = spans[n].get(s)
                    if src:
                        hits.append({"task": t["id"], "start": t["start"], "file": fn, "n": n, "case": src[0],
                                     "case_file": src[1], "span": s,
                                     "class": "common" if len(projects[n][s]) > 1 else None})

    for h in hits:
        if h["class"] is None and is_syntax(h["span"]):
            h["class"] = "syntax"
    # own-tree: look for the remaining hits' code views in each starting commit's tree
    if a.trees:
        by_start = {}
        for h in hits:
            if h["class"] is None:
                v = code_view(h["span"])
                by_start.setdefault(h["start"], {}).setdefault(len(v), set()).add(v)
        found = {}
        for start, want in by_start.items():
            root = os.path.join(a.trees, start)
            if not os.path.isdir(root):
                continue
            got = set()
            for w in tree_words(root):
                for k, vs in want.items():
                    for i in range(len(w) - k + 1):
                        v = tuple(w[i:i + k])
                        if v in vs:
                            got.add(v)
            found[start] = got
        for h in hits:
            if h["class"] is None and code_view(h["span"]) in found.get(h["start"], set()):
                h["class"] = "own-tree"
    for h in hits:
        h["class"] = h["class"] or "to-read"

    with open(a.out + ".hits.tsv", "w") as f:
        f.write("task\tfile\twords\tcase\tcase_file\tspan_id\tclass\n")
        seen = set()
        for h in hits:
            k = (h["task"], h["file"], h["n"], h["case"], h["case_file"], h["span"])
            if k in seen:
                continue
            seen.add(k)
            f.write(f"{h['task']}\t{h['file']}\t{h['n']}\t{h['case']}\t{h['case_file']}\t{span_id(h['span'])}\t"
                    f"{h['class']}\n")
    rows = []
    for t in tasks:
        th = [h for h in hits if h["task"] == t["id"]]
        reasons = held(t["repository"], holdout)
        nh = [x for x in name_hits if x[0] == t["id"]]
        cnt = lambda n, c=None: len({h["span"] for h in th if h["n"] == n and (c is None or h["class"] == c)})  # noqa
        to_read = len({h["span"] for h in th if h["class"] == "to-read"})
        result = "fail" if reasons else ("review" if nh or to_read else "pass")
        row = [t["id"], t["repository"], "held:" + "+".join(reasons) if reasons else "pass", str(len(nh))]
        for n in ns:
            row += [str(cnt(n, c)) for c in (None, "common", "syntax", "own-tree", "to-read")]
        rows.append(row + [result])
    with open(a.out + ".tasks.tsv", "w") as f:
        cols = ["task", "repository", "repository_check", "name_hits"]
        for n in ns:
            cols += [f"spans{n}", f"spans{n}_common", f"spans{n}_syntax", f"spans{n}_own_tree", f"spans{n}_to_read"]
        f.write("\t".join(cols + ["holdout_result"]) + "\n")
        f.writelines("\t".join(r) + "\n" for r in rows)
    summary = {"cases": len(cases), "bench_words": bench_words, "bench_spans": {n: len(spans[n]) for n in ns},
               "tasks": len(tasks), "task_words": task_words, "names_looked_for": len(names),
               "name_hits": [list(x) for x in name_hits],
               "hits": {n: {c: len({(h["task"], h["span"]) for h in hits if h["n"] == n and h["class"] == c})
                            for c in ("common", "syntax", "own-tree", "to-read")} for n in ns},
               "results": {r: sum(x[-1] == r for x in rows) for r in ("pass", "review", "fail")}}
    with open(a.out + ".json", "w") as f:
        json.dump(summary, f, indent=1)
    if a.local_spans:
        with open(a.local_spans, "w") as f:
            json.dump(sorted({(h["n"], h["class"], span_id(h["span"]), h["span"]) for h in hits}), f, indent=0)
    print(json.dumps(summary))


if __name__ == "__main__":
    sys.exit(main())
