"""Reads a task folder in the factory's one format (factory/README.md, section 3): which files of the project a
task touches, and which texts it holds.

A task touches a project file when its reference patch, its hidden tests (reference-tests.patch), its partial fix
(incomplete.patch), its documentation patch (upstream-docs.patch) or one of its test commands (grading.acceptance,
grading.preservation, and the files grading.preservation_left_out names) names it. integrity.patch is left out: it
is the factory's fixed early-exit control, not project code.

usage: python task_folder.py files TASK_DIR [...]        one TSV row per (task, path): source, status
       python task_folder.py revisions TASK_DIR [...]    one row per task: id, starting commit, merge commit
Standard library only.
"""
import json
import os
import re
import shlex
import sys

PATCHES = ["reference.patch", "reference-tests.patch", "incomplete.patch", "upstream-docs.patch"]
# the texts of a task, for the hold-out check: every file of the folder but the fixed early-exit control
TEXT_SKIP = {"integrity.patch"}


def read_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def patch_files(text):
    """[(path, status)] of a git patch: status added, deleted, renamed-from, renamed-to or modified."""
    out, cur = [], None

    def flush():
        if cur:
            a, b, st = cur
            if st == "added":
                out.append((b, "added"))
            elif st == "deleted":
                out.append((a, "deleted"))
            elif a != b:
                out.extend([(a, "renamed-from"), (b, "renamed-to")])
            else:
                out.append((a, "modified"))

    for line in text.splitlines():
        m = re.match(r"^diff --git a/(.+?) b/(.+)$", line)
        if m:
            flush()
            cur = [m[1], m[2], "modified"]
        elif cur and line.startswith("new file mode"):
            cur[2] = "added"
        elif cur and line.startswith("deleted file mode"):
            cur[2] = "deleted"
        elif cur and line.startswith("rename from "):
            cur[0] = line[len("rename from "):]
        elif cur and line.startswith("rename to "):
            cur[1] = line[len("rename to "):]
    flush()
    return out


def command_files(cmd):
    """Paths named by a `mix test ...` command (a `:line` suffix dropped)."""
    if not cmd:
        return []
    args = shlex.split(cmd)
    return [re.sub(r":\d+(?::\d+)*$", "", a) for a in args[2:] if not a.startswith("-")
            and ("/" in a or a.endswith(".exs"))]


def read_task(task_dir):
    case = read_json(os.path.join(task_dir, "case.json"))
    prov = read_json(os.path.join(task_dir, "provenance.json"))
    grading = case.get("grading") or {}
    files = {}   # path -> {source: status}
    for p in PATCHES:
        path = os.path.join(task_dir, p)
        if os.path.exists(path):
            with open(path, encoding="utf-8", errors="replace") as f:
                for rel, st in patch_files(f.read()):
                    files.setdefault(rel, {})[p] = st
    for key in ("acceptance", "preservation"):
        for rel in command_files(grading.get(key)):
            files.setdefault(rel, {})[f"grading.{key}"] = "named"
    for item in grading.get("preservation_left_out") or []:
        rel = item.get("file") if isinstance(item, dict) else item
        if rel:
            files.setdefault(rel, {})["grading.preservation_left_out"] = "named"
    return {"id": case["id"], "dir": task_dir, "project": case.get("project"),
            "repository": case["repository"]["url"], "start": case["repository"]["revision"],
            "fixed": prov.get("fixed_revision"), "provenance_licence": prov.get("licence"), "files": files}


def task_texts(task_dir):
    """(file name, text) of every file of the folder, integrity.patch left out."""
    for n in sorted(os.listdir(task_dir)):
        p = os.path.join(task_dir, n)
        if n in TEXT_SKIP or not os.path.isfile(p):
            continue
        with open(p, encoding="utf-8", errors="replace") as f:
            yield n, f.read()


def task_dirs(args):
    """Task folders from the arguments: a task folder itself (it holds case.json) or a folder of task folders."""
    out = []
    for a in args:
        if os.path.exists(os.path.join(a, "case.json")):
            out.append(a)
        else:
            out += [os.path.join(a, n) for n in sorted(os.listdir(a)) if os.path.exists(os.path.join(a, n, "case.json"))]
    return out


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("files", "revisions"):
        print(__doc__, file=sys.stderr)
        return 2
    tasks = [read_task(d) for d in task_dirs(sys.argv[2:])]
    if sys.argv[1] == "revisions":
        print("task\trepository\tstart\tfixed")
        for t in tasks:
            print(f"{t['id']}\t{t['repository']}\t{t['start']}\t{t['fixed'] or ''}")
    else:
        print("task\tpath\tsources")
        for t in tasks:
            for rel in sorted(t["files"]):
                src = ",".join(f"{k}={v}" for k, v in sorted(t["files"][rel].items()))
                print(f"{t['id']}\t{rel}\t{src}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
