"""Three extra tables for a run of factory/tools/check_tasks.sh, written beside its output. They add what the tool's
own tables leave out and change none of them. Standard library only; run it in the same Python container.

  python -I extra_checks.py deps  --tools DIR --work DIR --holdout FILE TASK_DIR [...]
      deps.outside.tsv   per (task, package): the packages of each task's lock file whose declared licences are not
                         all MIT, Apache-2.0 or BSD, and its git dependencies (whose licence the tool does not read)
      deps.holdout.tsv   per package version: Hex packages that belong to a held-out project (by package name, by the
                         GitHub organisation or repository in the package's own metadata links), with the number of
                         tasks that lock them
      deps.holdout.tasks.tsv  per task: how many such packages its lock file holds, and which
      deps.summary.tsv   per project and licence class: package versions and distinct packages locked by its tasks
  python -I extra_checks.py runs  --tools DIR --work DIR --bench DIR TASK_DIR [...]
      holdout.runs.tsv   for each `to-read` hit of the work folder's holdout.hits.tsv: the longest run of words that
                         the task's file and the case's file share around the 8-word span, counted with and without
                         the diff markers. Lengths only, never text.
"""
import argparse
import csv
import json
import os
import re
import sys


def load_tsv(path):
    with open(path, encoding="utf-8") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def package_links(head_path, task_licence):
    """owner/repo of the GitHub links in a package's metadata.config (the first bytes of its Hex tarball)."""
    if not os.path.exists(head_path):
        return []
    meta = task_licence.tar_member(open(head_path, "rb").read(), "metadata.config")
    if meta is None:
        return []
    text = meta.decode("utf-8", "replace")
    m = re.search(r'\{<<"links">>\s*,\s*\[(.*?)\]\s*\}', text, re.S)
    if not m:
        return []
    return sorted({f"{o}/{r}" for o, r in re.findall(r"https?://github\.com/([^/\"]+)/([^/\"#?]+)", m[1])})


def deps(a, task_folder, task_licence):
    holdout = json.load(open(a.holdout))
    orgs = {o.lower() for o in holdout["organisations"]}
    names = {n.lower() for n in holdout["names"]}
    repos = {r.lower() for r in holdout["repositories"]} | {p["repository"].lower() for p in holdout["projects"]}
    info = {}
    for r in load_tsv(os.path.join(a.work, "deps.tsv")):
        info[(r["kind"], r["package"], r["version"])] = r
    tasks = [task_folder.read_task(d) for d in task_folder.task_dirs(a.tasks)]
    outside, held, held_by_task, by_repo = [], {}, {}, {}
    for t in tasks:
        p = os.path.join(a.work, "trees", t["start"], "mix.lock")
        if not os.path.exists(p):
            continue
        text = open(p, encoding="utf-8").read()
        found = [("hex", pkg, ver) for _k, pkg, ver in task_licence.LOCK_HEX.findall(text)]
        found += [("git", key, f"{url}#{ref}") for key, url, ref in task_licence.LOCK_GIT.findall(text)]
        for key in found:
            r = info.get(key)
            if r is None:
                continue
            by_repo.setdefault(re.sub(r"-pr-\d+$", "", t["id"]), {})[key] = r["class"]
            if r["class"] not in ("allowed", "allowed, not an SPDX id"):
                outside.append([t["id"], r["kind"], r["package"], r["version"], r["licences"], r["class"]])
            if key[0] == "hex":
                links = package_links(os.path.join(a.work, "hex", f"{key[1]}-{key[2]}.head"), task_licence)
                why = []
                if key[1].lower() in names:
                    why.append("package name")
                if any(x.split("/")[0].lower() in orgs for x in links):
                    why.append("organisation")
                if any(x.lower() in repos for x in links):
                    why.append("repository")
                if why:
                    h = held.setdefault(key, {"links": links, "why": why, "tasks": set()})
                    h["tasks"].add(t["id"])
                    held_by_task.setdefault(t["id"], set()).add(key[1])
    with open(os.path.join(a.work, "deps.outside.tsv"), "w") as f:
        f.write("task\tkind\tpackage\tversion\tlicences\tclass\n")
        f.writelines("\t".join(x) + "\n" for x in sorted(outside))
    with open(os.path.join(a.work, "deps.holdout.tsv"), "w") as f:
        f.write("package\tversion\tgithub\theld_out_by\ttasks\n")
        for (kind, pkg, ver), h in sorted(held.items()):
            f.write(f"{pkg}\t{ver}\t{','.join(h['links'])}\t{'+'.join(h['why'])}\t{len(h['tasks'])}\n")
    with open(os.path.join(a.work, "deps.summary.tsv"), "w") as f:
        f.write("project\tclass\tpackage_versions\tdistinct_packages\n")
        for proj, keys in sorted(by_repo.items()):
            classes = sorted(set(keys.values()))
            for c in classes + ["(all)"]:
                ks = [k for k, v in keys.items() if c == "(all)" or v == c]
                f.write(f"{proj}\t{c}\t{len(ks)}\t{len({k[1] for k in ks})}\n")
    with open(os.path.join(a.work, "deps.holdout.tasks.tsv"), "w") as f:
        f.write("task\theld_out_packages\tpackages\n")
        for t in tasks:
            pk = sorted(held_by_task.get(t["id"], ()))
            f.write(f"{t['id']}\t{len(pk)}\t{','.join(pk)}\n")
    print(json.dumps({"outside_rows": len(outside), "tasks_with_outside": len({x[0] for x in outside}),
                      "tasks_with_held_out_packages": len(held_by_task),
                      "held_out_package_versions": len(held),
                      "held_out_packages": sorted({k[1] for k in held})}))


def runs(a, task_folder, task_holdout):
    tasks = {t["id"]: t for t in (task_folder.read_task(d) for d in task_folder.task_dirs(a.tasks))}
    rows = [r for r in load_tsv(os.path.join(a.work, "holdout.hits.tsv")) if r["class"] == "to-read"]
    out = []
    seen = set()
    for h in rows:
        key = (h["task"], h["file"], h["case"], h["case_file"], h["span_id"])
        if key in seen:
            continue
        seen.add(key)
        n = int(h["words"])
        text = dict(task_folder.task_texts(tasks[h["task"]]["dir"]))[h["file"]]
        tw = task_holdout.words(text)
        ti = [i for i in range(len(tw) - n + 1) if task_holdout.span_id(" ".join(tw[i:i + n])) == h["span_id"]]
        cw = task_holdout.words(open(os.path.join(a.bench, h["case"], h["case_file"]),
                                     encoding="utf-8", errors="replace").read())
        best = (0, 0)
        for i in ti:
            span = tw[i:i + n]
            for j in range(len(cw) - n + 1):
                if cw[j:j + n] != span:
                    continue
                lo = 0
                while i - lo - 1 >= 0 and j - lo - 1 >= 0 and tw[i - lo - 1] == cw[j - lo - 1]:
                    lo += 1
                hi = 0
                while i + n + hi < len(tw) and j + n + hi < len(cw) and tw[i + n + hi] == cw[j + n + hi]:
                    hi += 1
                run = tw[i - lo:i + n + hi]
                cand = (len(run), len([w for w in run if w not in ("+", "-")]))
                best = max(best, cand)
        out.append([h["task"], h["file"], h["case"], h["case_file"], h["span_id"], str(best[0]), str(best[1])])
    with open(os.path.join(a.work, "holdout.runs.tsv"), "w") as f:
        f.write("task\tfile\tcase\tcase_file\tspan_id\tlongest_run_words\tlongest_run_words_without_diff_markers\n")
        f.writelines("\t".join(x) + "\n" for x in out)
    print(json.dumps({"to_read_pairs": len(out)}))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name in ("deps", "runs"):
        s = sub.add_parser(name)
        s.add_argument("--tools", required=True)
        s.add_argument("--work", required=True)
        s.add_argument("tasks", nargs="+")
        if name == "deps":
            s.add_argument("--holdout", required=True)
        else:
            s.add_argument("--bench", required=True)
    a = ap.parse_args()
    sys.path.insert(0, a.tools)
    sys.path.insert(0, os.path.join(a.tools, "upstream"))
    import task_folder
    if a.cmd == "deps":
        import task_licence
        deps(a, task_folder, task_licence)
    else:
        import task_holdout
        runs(a, task_folder, task_holdout)


if __name__ == "__main__":
    sys.exit(main())
