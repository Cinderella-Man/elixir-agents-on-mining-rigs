"""The licence check of factory task folders (E51): every project file a task touches must have a passing verdict
from upstream/license_scan.py (unchanged) on the project's tree, and the dependencies' licences are listed.

A task passes when every file it touches (task_folder.py) has a verdict starting with `ok` in the scan of the
starting commit's tree (files the task does not add) and in the scan of the merge commit's tree (files the task does
not delete). A file found in neither tree fails as `missing`.

usage:
  python task_licence.py tree-licence TREE
      the tree's root licence file: name, sha256, families (license_scan's signatures), and the holder regex taken
      from its first copyright line; one JSON line. check_tasks.sh passes the families and the regex to
      license_scan.py.
  python task_licence.py scan-trees --trees DIR COMMIT [...]
      for each DIR/<commit>/ not yet scanned: DIR/<commit>.licence.json (tree-licence's line), then
      upstream/license_scan.py on the tree with --license <its families, or NONE> --holders <its regex>, writing
      DIR/<commit>.scan.tsv and .scan.json.
  python task_licence.py join --trees DIR --out PREFIX TASK_DIR [...]
      DIR holds <commit>.scan.tsv (license_scan.py's table) and <commit>.licence.json (tree-licence's line) for
      every starting and merge commit. Writes PREFIX.files.tsv (task, path, sources, verdict at start, verdict at
      merge, pass), PREFIX.tasks.tsv (one row per task) and PREFIX.commits.tsv (one row per commit).
  python task_licence.py locks --trees DIR --out TSV TASK_DIR [...]
      the Hex and git dependencies in mix.lock of each starting commit (DIR/<commit>/mix.lock), one row per
      (package, version) with the tasks and commits that lock it.
  python task_licence.py deps --locks TSV --hex DIR --out PREFIX
      DIR holds <name>-<version>.head: the first bytes of each package's tarball from the Hex repository, enough to
      hold its metadata.config. Writes PREFIX.tsv: package, version, the licences the package declares for that
      version, and whether they are all MIT, Apache-2.0 or BSD.
Standard library only.
"""
import argparse
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "upstream"))
import license_scan  # noqa: E402  (upstream, unchanged)
import task_folder  # noqa: E402

ALLOWED_SPDX = {"MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause"}
# spellings packages use for the same three licences; reported as "allowed, not an SPDX id"
LOOSE = [(re.compile(r"^mit( license)?$", re.I), "MIT"),
         (re.compile(r"^apache(\s|-)?(license)?[\s,-]*(v(ersion)?\s*)?2(\.0)?( license)?$", re.I), "Apache-2.0"),
         (re.compile(r"^apache$", re.I), "Apache-2.0?"),
         (re.compile(r"^(new |modified |simplified )?bsd([\s-]?[23][\s-]?clause)?( license)?$", re.I), "BSD")]


def tree_licence(tree):
    names = sorted(n for n in os.listdir(tree) if os.path.isfile(os.path.join(tree, n))
                   and re.match(r"^(LICEN[CS]E|COPYING)(\.md|\.txt)?$", n, re.I))
    if not names:
        return {"file": "", "sha256": "", "families": [], "holders": ""}
    path = os.path.join(tree, names[0])
    data = open(path, "rb").read()
    text = data.decode("utf-8", errors="replace")
    fams = license_scan.families_in(text)
    holders = ""
    m = license_scan.COPYRIGHT.search(text)
    if m:
        h = re.sub(r"^\s*(\(c\)|©)?\s*[\d\s,\-–]*", "", m[1]).strip().rstrip(".")
        holders = re.escape(h) if h else ""
    return {"file": names[0], "sha256": hashlib.sha256(data).hexdigest(), "families": fams, "holders": holders}


def scan_trees(a):
    import subprocess
    for c in a.commits:
        tree = os.path.join(a.trees, c)
        if os.path.exists(tree + ".scan.tsv"):
            continue
        lic = tree_licence(tree)
        with open(tree + ".licence.json", "w") as f:
            json.dump(lic, f)
        out = subprocess.run([sys.executable, "-I", os.path.join(HERE, "upstream", "license_scan.py"), tree,
                              "--license", ",".join(lic["families"]) or "NONE", "--holders", lic["holders"],
                              "--exclude", ".checked-out", "--out", tree + ".scan"],
                             check=True, capture_output=True, text=True).stdout
        print(c, out.strip())


def read_scan(path):
    out = {}
    with open(path, encoding="utf-8") as f:
        head = f.readline().rstrip("\n").split("\t")
        for line in f:
            row = dict(zip(head, line.rstrip("\n").split("\t")))
            out[row["path"]] = row
    return out


def join(a):
    tasks = [task_folder.read_task(d) for d in task_folder.task_dirs(a.tasks)]
    scans, lic = {}, {}

    def scan(commit):
        if commit not in scans:
            p = os.path.join(a.trees, f"{commit}.scan.tsv")
            scans[commit] = read_scan(p) if os.path.exists(p) else None
            lp = os.path.join(a.trees, f"{commit}.licence.json")
            lic[commit] = json.load(open(lp)) if os.path.exists(lp) else None
        return scans[commit]

    frows, trows = [], []
    for t in tasks:
        s0, s1 = scan(t["start"]), scan(t["fixed"]) if t["fixed"] else None
        if s0 is None:
            raise SystemExit(f"no scan of the starting commit {t['start']} of {t['id']}")
        failing = []
        for rel in sorted(t["files"]):
            src = t["files"][rel]
            v0 = s0[rel]["verdict"] if rel in s0 else "-"
            v1 = (s1[rel]["verdict"] if rel in s1 else "-") if s1 is not None else "not scanned"
            seen = [v for v in (v0, v1) if v not in ("-", "not scanned")]
            ok = bool(seen) and all(v.startswith("ok") for v in seen)
            why = "" if ok else ("missing" if not seen else ";".join(sorted(set(v for v in seen if not v.startswith("ok")))))
            if not ok:
                failing.append(f"{rel} ({why})")
            frows.append([t["id"], rel, ",".join(f"{k}={v}" for k, v in sorted(src.items())), v0, v1,
                          "pass" if ok else "fail:" + why])
        l0 = lic[t["start"]] or {}
        fam = l0.get("families") or []
        root_ok = bool(fam) and set(fam) <= {"MIT", "Apache-2.0", "BSD"}
        verdict = "pass" if root_ok and not failing else "fail"
        trows.append([t["id"], t["start"], l0.get("file", ""), "+".join(fam) or "none", t["provenance_licence"] or "",
                      str(len(t["files"])), str(len(t["files"]) - len(failing)), verdict,
                      ("" if root_ok else "root licence not MIT, Apache-2.0 or BSD; ") + "; ".join(failing)])
    with open(a.out + ".files.tsv", "w") as f:
        f.write("task\tpath\tsources\tverdict_start\tverdict_merge\tresult\n")
        f.writelines("\t".join(r) + "\n" for r in frows)
    with open(a.out + ".tasks.tsv", "w") as f:
        f.write("task\tstart\tlicence_file\tlicence_families\tprovenance_licence\tfiles_touched\tfiles_passing\t"
                "licence_result\tfailing\n")
        f.writelines("\t".join(r) + "\n" for r in trows)
    with open(a.out + ".commits.tsv", "w") as f:
        f.write("commit\tlicence_file\tlicence_sha256\tfamilies\tfiles\tok\tok_notice\treview\texclude\texclude_kinds\n")
        for c in sorted(scans):
            s, l_ = scans[c], lic[c] or {}
            if s is None:
                continue
            vs = [r["verdict"] for r in s.values()]
            kinds = {}
            for v in vs:
                if v.startswith("exclude"):
                    kinds[v] = kinds.get(v, 0) + 1
            f.write("\t".join([c, l_.get("file", ""), l_.get("sha256", ""), "+".join(l_.get("families") or []),
                               str(len(vs)), str(sum(v == "ok" for v in vs)),
                               str(sum(v.startswith("ok:") for v in vs)), str(sum(v.startswith("review") for v in vs)),
                               str(sum(v.startswith("exclude") for v in vs)),
                               ",".join(f"{k}={n}" for k, n in sorted(kinds.items()))]) + "\n")
    print(json.dumps({"tasks": len(trows), "pass": sum(r[7] == "pass" for r in trows),
                      "files": len(frows), "files_failing": sum(r[5] != "pass" for r in frows)}))


LOCK_HEX = re.compile(r'^\s*"([^"]+)":\s*\{:hex,\s*:"?([A-Za-z0-9_]+)"?,\s*"([^"]+)"', re.M)
LOCK_GIT = re.compile(r'^\s*"([^"]+)":\s*\{:git,\s*"([^"]+)",\s*"([0-9a-f]+)"', re.M)


def locks(a):
    tasks = [task_folder.read_task(d) for d in task_folder.task_dirs(a.tasks)]
    rows = {}
    for t in tasks:
        p = os.path.join(a.trees, t["start"], "mix.lock")
        if not os.path.exists(p):
            continue
        text = open(p, encoding="utf-8").read()
        for _key, pkg, ver in LOCK_HEX.findall(text):
            r = rows.setdefault(("hex", pkg, ver), {"tasks": set(), "commits": set()})
            r["tasks"].add(t["id"]), r["commits"].add(t["start"])
        for key, url, ref in LOCK_GIT.findall(text):
            r = rows.setdefault(("git", key, f"{url}#{ref}"), {"tasks": set(), "commits": set()})
            r["tasks"].add(t["id"]), r["commits"].add(t["start"])
    with open(a.out, "w") as f:
        f.write("kind\tpackage\tversion\ttasks\tcommits\n")
        for (kind, pkg, ver), r in sorted(rows.items()):
            f.write(f"{kind}\t{pkg}\t{ver}\t{len(r['tasks'])}\t{len(r['commits'])}\n")
    print(json.dumps({"rows": len(rows), "hex": sum(k[0] == "hex" for k in rows), "git": sum(k[0] == "git" for k in rows)}))


def tar_member(data, name):
    """A member of an (possibly truncated) ustar archive, read from its 512-byte headers."""
    off = 0
    while off + 512 <= len(data):
        h = data[off:off + 512]
        if h == b"\0" * 512:
            return None
        n = h[:100].rstrip(b"\0").decode("utf-8", "replace")
        size = int(h[124:136].rstrip(b"\0 ").decode() or "0", 8)
        if n == name:
            body = data[off + 512:off + 512 + size]
            return body if len(body) == size else None
        off += 512 + (size + 511) // 512 * 512
    return None


def licence_class(names):
    if not names:
        return "none declared"
    out = []
    for n in names:
        if n in ALLOWED_SPDX:
            out.append("allowed")
            continue
        loose = next((v for rx, v in LOOSE if rx.match(n.strip())), None)
        out.append("allowed, not an SPDX id" if loose and not loose.endswith("?") else "outside")
    if all(o == "allowed" for o in out):
        return "allowed"
    if all(o.startswith("allowed") for o in out):
        return "allowed, not an SPDX id"
    # Hex's list does not say whether several licences are a choice (A or B) or parts under each (A and B)
    if len(names) > 1 and any(o.startswith("allowed") for o in out):
        return "several, some outside"
    return "outside"


def deps(a):
    rows = []
    with open(a.locks, encoding="utf-8") as f:
        head = f.readline().rstrip("\n").split("\t")
        lines = [dict(zip(head, ln.rstrip("\n").split("\t"))) for ln in f]
    for r in lines:
        if r["kind"] != "hex":
            rows.append([r["kind"], r["package"], r["version"], "", "git dependency: licence not read", r["tasks"]])
            continue
        p = os.path.join(a.hex, f"{r['package']}-{r['version']}.head")
        if not os.path.exists(p):
            rows.append([r["kind"], r["package"], r["version"], "", "not fetched", r["tasks"]])
            continue
        meta = tar_member(open(p, "rb").read(), "metadata.config")
        if meta is None:
            rows.append([r["kind"], r["package"], r["version"], "", "metadata.config not in the fetched bytes",
                         r["tasks"]])
            continue
        text = meta.decode("utf-8", "replace")
        m = re.search(r'\{<<"licenses">>\s*,\s*\[(.*?)\]\s*\}', text, re.S)
        names = re.findall(r'<<"((?:[^"\\]|\\.)*)"(?:/utf8)?>>', m[1]) if m else []
        rows.append([r["kind"], r["package"], r["version"], " | ".join(names), licence_class(names), r["tasks"]])
    with open(a.out + ".tsv", "w") as f:
        f.write("kind\tpackage\tversion\tlicences\tclass\ttasks\n")
        f.writelines("\t".join(x) + "\n" for x in rows)
    counts = {}
    for x in rows:
        counts[x[4]] = counts.get(x[4], 0) + 1
    print(json.dumps({"rows": len(rows), "classes": counts}))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("tree-licence")
    s.add_argument("tree")
    s = sub.add_parser("scan-trees")
    s.add_argument("--trees", required=True)
    s.add_argument("commits", nargs="+")
    s = sub.add_parser("join")
    s.add_argument("--trees", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("tasks", nargs="+")
    s = sub.add_parser("locks")
    s.add_argument("--trees", required=True)
    s.add_argument("--out", required=True)
    s.add_argument("tasks", nargs="+")
    s = sub.add_parser("deps")
    s.add_argument("--locks", required=True)
    s.add_argument("--hex", required=True)
    s.add_argument("--out", required=True)
    a = ap.parse_args()
    if a.cmd == "tree-licence":
        print(json.dumps(tree_licence(a.tree)))
    else:
        {"scan-trees": scan_trees, "join": join, "locks": locks, "deps": deps}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
