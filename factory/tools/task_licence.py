"""The licence check of factory task folders (E51): every project file a task touches must have a passing verdict
from upstream/license_scan.py (unchanged) on the project's tree, and the dependencies' licences are listed.

A task passes when every file it touches (task_folder.py) has a verdict starting with `ok` in the scan of the
starting commit's tree (files the task does not add) and in the scan of the merge commit's tree (files the task does
not delete). A file found in neither tree fails as `missing`.

The project's root licence comes from a licence file at the root (LICENSE, LICENCE or COPYING, with or without .md or
.txt). When the root has none, a licence stated in the root README counts (docs/dataset_rules.md, section 9; the
owner, 2026-11-12: "Yes, accept it"): the statement must name one licence of the list in plain words and be the
project's own, and the file, its sha256, the sentence and its line are recorded as the proof. A licence file, where
there is one, still decides. `root` in tree-licence's line says which:
  ok:licence-file           the root licence file's families are all in the list
  ok:readme-statement       no licence file; the README states one licence of the list as the project's own
  fail:licence-file         the root licence file's families are not all in the list (or none was recognised)
  fail:no-licence           no licence file, and no statement in the README
  fail:readme-outside       the README's own statement names a licence outside the list (or an unclear one)
  fail:readme-several       the README's own statements name two or more licences of the list
A README sentence is the project's own when it sits in a section headed License, Licence, Licensing or Copyright
(not one about third-party code or credits), or elsewhere when its subject is the project ("this project",
"this software", ...) followed by "licensed/released/distributed/available under". A sentence that speaks of other
code (uses, includes, depends on, third-party, vendored, icons, fonts, ...) is a mention, not a statement.

usage:
  python task_licence.py tree-licence TREE
      the tree's root licence: file (the licence file, or the README with the statement), sha256, families
      (license_scan's family names), the holder regex taken from its first copyright line, source, root, statement,
      line and mentions; one JSON line. check_tasks.sh passes the families and the regex to license_scan.py.
  python task_licence.py scan-trees --trees DIR COMMIT [...]
      for each DIR/<commit>/ not yet scanned: DIR/<commit>.licence.json (tree-licence's line), then
      upstream/license_scan.py on the tree with --license <its families, or NONE> --holders <its regex>, writing
      DIR/<commit>.scan.tsv and .scan.json.
  python task_licence.py join --trees DIR --out PREFIX TASK_DIR [...]
      DIR holds <commit>.scan.tsv (license_scan.py's table) and <commit>.licence.json (tree-licence's line) for
      every starting and merge commit. Writes PREFIX.files.tsv (task, path, sources, verdict at start, verdict at
      merge, pass), PREFIX.tasks.tsv (one row per task; its last two columns, root_licence and root_proof, are the
      starting commit's root result and, for a README statement, "<file>@<commit>:<line>: <sentence>") and
      PREFIX.commits.tsv (one row per commit).
  python task_licence.py locks --trees DIR --out TSV TASK_DIR [...]
      the Hex and git dependencies in mix.lock of each starting commit (DIR/<commit>/mix.lock), one row per
      (package, version) with the tasks and commits that lock it.
  python task_licence.py deps --locks TSV --hex DIR --out PREFIX
      DIR holds <name>-<version>.head: the first bytes of each package's tarball from the Hex repository, enough to
      hold its metadata.config. Writes PREFIX.tsv: package, version, the licences the package declares for that
      version, and whether they are all MIT, Apache-2.0, BSD or ISC (ISC added by the owner on 2026-11-12).
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

ALLOWED_SPDX = {"MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause", "ISC"}
# license_scan.py's families a project's root licence may have
ROOT_FAMILIES = {"MIT", "Apache-2.0", "BSD", "ISC"}
# spellings packages use for the same licences; reported as "allowed, not an SPDX id"
LOOSE = [(re.compile(r"^mit( license)?$", re.I), "MIT"),
         (re.compile(r"^apache(\s|-)?(license)?[\s,-]*(v(ersion)?\s*)?2(\.0)?( license)?$", re.I), "Apache-2.0"),
         (re.compile(r"^apache$", re.I), "Apache-2.0?"),
         (re.compile(r"^(new |modified |simplified )?bsd([\s-]?[23][\s-]?clause)?( license)?$", re.I), "BSD"),
         (re.compile(r"^isc( license)?$", re.I), "ISC")]


def root_allowed(families):
    """True when the root licence file has at least one family and every family is in the list."""
    return bool(families) and set(families) <= ROOT_FAMILIES


def root_code(lic):
    """The root result of one commit's tree-licence line. A line written before the README rule has no `root`."""
    if not lic:
        return "not scanned"
    if lic.get("root"):
        return lic["root"]
    if not lic.get("file"):
        return "fail:no-licence"
    return "ok:licence-file" if root_allowed(lic.get("families") or []) else "fail:licence-file"


def root_ok(lic):
    return root_code(lic).startswith("ok")


def root_proof(lic, commit):
    """For a README statement: <file>@<commit>:<line>: <sentence>, on one line; else the licence file's name."""
    if not lic or not lic.get("file"):
        return ""
    if lic.get("source") == "readme-statement":
        sent = re.sub(r"\s+", " ", lic.get("statement", "")).strip()
        return f"{lic['file']}@{commit}:{lic.get('line', 0)}: {sent}"
    return f"{lic['file']}@{commit}"


# The licences of the list, named in plain words (license_scan's family names). BSD counts only with its clause
# count or as the new/modified/revised/simplified BSD licence; a bare "BSD" is unclear.
PLAIN_ALLOWED = [
    ("Apache-2.0", re.compile(r"\bApache(?:[ -]Software)?(?:[ -]Licen[cs]e)?,?[ -]*(?:Version|v\.?)?[ -]*2(?:\.0)?\b"
                              r"|apache\.org/licenses/LICENSE-2\.0", re.I)),
    ("MIT", re.compile(r"\bMIT\b|\bExpat [Ll]icen[cs]e\b")),
    ("BSD", re.compile(r"\bBSD[- ]?(?:2|3|[Tt]wo|[Tt]hree)[- ]?[Cc]lause\b|\b(?:2|3|[Tt]wo|[Tt]hree)[- ][Cc]lause BSD\b|"
                       r"\b(?:[Nn]ew|[Mm]odified|[Rr]evised|[Ss]implified)\s+BSD\b")),
    ("ISC", re.compile(r"\bISC\b")),
]
# Licences outside the list named in plain words, and unclear names; license_scan's own signatures are added.
PLAIN_OUTSIDE = [
    ("GPL", re.compile(r"\b(?:A|L)?GPL(?:v?\d(?:\.\d)?)?\b|General Public Licen[cs]e")),
    ("MPL", re.compile(r"\bMPL\b|Mozilla Public Licen[cs]e", re.I)),
    ("EPL", re.compile(r"\bEPL\b|Eclipse Public Licen[cs]e", re.I)),
    ("EUPL", re.compile(r"\bEUPL\b|European Union Public Licen[cs]e", re.I)),
    ("CC", re.compile(r"Creative Commons|\bCC[- ]?BY\b|\bCC0\b", re.I)),
    ("SSPL-BUSL", re.compile(r"Server Side Public Licen[cs]e|Business Source Licen[cs]e|\bBUSL\b|\bSSPL\b|"
                             r"Commons Clause|Elastic Licen[cs]e", re.I)),
    ("Unlicense", re.compile(r"\bUnlicense\b", re.I)),
    ("WTFPL", re.compile(r"\bWTFPL\b", re.I)),
    ("Apache-1", re.compile(r"\bApache(?:[ -]Software)?(?:[ -]Licen[cs]e)?,?[ -]*(?:Version|v\.?)?[ -]*1(?:\.[01])?\b",
                            re.I)),
    ("BSD-4-Clause", re.compile(r"\bBSD[- ]?(?:4|[Ff]our)[- ]?[Cc]lause\b|\b(?:4|[Ff]our)[- ][Cc]lause BSD\b|"
                                r"\b[Oo]riginal BSD\b")),
    ("BSD-unclear", re.compile(r"\bBSD\b")),
    ("public-domain", re.compile(r"\bpublic domain\b", re.I)),
]
README_NAME = re.compile(r"^README(?:\.(?:md|markdown|txt|rst))?$", re.I)
LICENCE_HEADING = re.compile(r"\blicen[cs]e|\blicensing\b|\bcopyright\b", re.I)
# a heading about other people's code, even when it says "licence"
OTHERS_HEADING = re.compile(r"third[- ]?party|dependenc|credit|acknowledg|attribution|vendor|thanks|contribut", re.I)
# a sentence that speaks of other code than the project's own (not "use", "including" or "derived from", which the
# licence texts themselves say)
OTHERS = re.compile(r"\b(?:uses|using|makes use of|depends on|depending on|dependenc(?:y|ies)|includes|bundles|"
                    r"bundled|vendor(?:ed|s)?|third[- ]?party|icons?|fonts?|artwork|logos?|illustrations?|"
                    r"based on|forked from|courtesy of|copied from|borrowed from|adapted from|ported from|"
                    r"libraries|packages|plugins|gems|crates|built with|powered by)\b", re.I)
SELF_SUBJECT = re.compile(r"\b(?:this|our|the present)\s+(?:project|software|code(?:base)?|source(?: code)?|"
                          r"repository|repo|application|app|library|package|tool|work|program|site|website|server|"
                          r"service)\b[^.]{0,80}?\b(?:licen[cs]ed|released|distributed|available|published|"
                          r"provided|offered)\b[^.]{0,20}?\bunder\b", re.I)


def plain_licences(sentence):
    """(families of the list, families outside it or unclear) named in one sentence."""
    allowed, rest = [], sentence
    for fam, rx in PLAIN_ALLOWED:
        if rx.search(rest):
            allowed.append(fam)
            rest = rx.sub(" ", rest)
    outside = [fam for fam, rx in PLAIN_OUTSIDE if rx.search(rest)]
    # a licence text pasted whole (license_scan's signatures, for example the MIT grant)
    for f in license_scan.families_in(rest):
        if f in ROOT_FAMILIES:
            if f not in allowed:
                allowed.append(f)
        elif f not in outside:
            outside.append(f)
    return allowed, outside


def readme_blocks(text):
    """The README as paragraphs: (first line number, text, the licence-section flag). Markdown and reStructuredText
    headings start sections; a section headed License/Licence/Licensing/Copyright (not about others' code) is the
    licence section until the next heading of its level or higher."""
    lines = text.splitlines()
    blocks, cur, cur_line, in_lic, lic_level = [], [], 0, False, 0

    def flush():
        nonlocal cur
        if cur:
            blocks.append((cur_line, " ".join(cur), in_lic))
        cur = []

    i = 0
    while i < len(lines):
        raw = lines[i]
        s = raw.strip()
        title, level = None, 0
        m = re.match(r"^(#{1,6})\s+(.*?)\s*#*\s*$", s)
        nxt = lines[i + 1].strip() if i + 1 < len(lines) else ""
        if m:
            title, level = m[2], len(m[1])
        elif s and not s.startswith(("```", "~~~")) and re.fullmatch(r"(=+|-+|~+|\^+|\*+)", nxt) and len(nxt) >= 3 \
                and not re.fullmatch(r"[-=~^*]+", s):
            title, level = s, (1 if nxt[0] == "=" else 2)
            i += 1
        if title is not None:
            flush()
            if in_lic and level > lic_level:
                pass  # a subsection of the licence section
            else:
                in_lic = bool(LICENCE_HEADING.search(title)) and not OTHERS_HEADING.search(title)
                lic_level = level
            i += 1
            continue
        if not s or s.startswith(("```", "~~~")) or re.fullmatch(r"[-=*_]{3,}", s):
            flush()
            i += 1
            continue
        s = re.sub(r"^(?:>\s*)+|^(?:[-*+]|\d+[.)])\s+", "", s)  # quotes and list markers
        s = re.sub(r"!?\[([^\]]*)\]\(([^)]*)\)", r"\1 (\2)", s)  # links keep their text and target
        s = re.sub(r"[*_`]+", "", s)
        if not cur:
            cur_line = i + 1
        cur.append(s)
        i += 1
    flush()
    return blocks


def readme_statement(tree):
    """The root README's licence statement, or None when the root has no README."""
    names = sorted(n for n in os.listdir(tree) if os.path.isfile(os.path.join(tree, n)) and README_NAME.match(n))
    if not names:
        return None
    path = os.path.join(tree, names[0])
    with open(path, "rb") as f:
        data = f.read()
    text = data.decode("utf-8", errors="replace")
    own, mentions = [], 0
    for line, para, in_lic in readme_blocks(text):
        for sent in re.split(r"(?<=[.!?])\s+(?=[A-Z(\"'])", para):
            allowed, outside = plain_licences(sent)
            if not allowed and not outside:
                continue
            if OTHERS.search(sent) or not (in_lic or SELF_SUBJECT.search(sent)):
                mentions += 1
                continue
            own.append((line, sent.strip(), allowed, outside))
    holders = ""
    lic_text = "\n".join(p for _l, p, in_lic in readme_blocks(text) if in_lic)
    m = license_scan.COPYRIGHT.search(lic_text)
    if m:
        h = re.sub(r"^\s*(\(c\)|©)?\s*[\d\s,\-–]*", "", m[1]).strip().rstrip(".")
        h = re.split(r"\s+(?:Licen[cs]ed|Released|Distributed)\b", h)[0].strip().rstrip(".")
        holders = re.escape(h) if h else ""
    allowed = sorted({f for _l, _s, a, _o in own for f in a})
    outside = sorted({f for _l, _s, _a, o in own for f in o})
    if not own:
        root, families = "fail:no-licence", []
    elif outside:
        root, families = "fail:readme-outside", sorted(set(allowed) | set(outside))
    elif len(allowed) > 1:
        root, families = "fail:readme-several", allowed
    else:
        root, families = "ok:readme-statement", allowed
    first = own[0] if own else None
    if root.startswith("ok"):
        first = next(o for o in own if o[2])
    return {"file": names[0] if own else "", "sha256": hashlib.sha256(data).hexdigest() if own else "",
            "families": families, "holders": holders if own else "", "source": "readme-statement" if own else "none",
            "root": root, "statement": first[1] if first else "", "line": first[0] if first else 0,
            "mentions": mentions}


def tree_licence(tree):
    names = sorted(n for n in os.listdir(tree) if os.path.isfile(os.path.join(tree, n))
                   and re.match(r"^(LICEN[CS]E|COPYING)(\.md|\.txt)?$", n, re.I))
    if not names:
        found = readme_statement(tree)
        if found is not None:
            return found
        return {"file": "", "sha256": "", "families": [], "holders": "", "source": "none", "root": "fail:no-licence",
                "statement": "", "line": 0, "mentions": 0}
    path = os.path.join(tree, names[0])
    with open(path, "rb") as f:
        data = f.read()
    text = data.decode("utf-8", errors="replace")
    fams = license_scan.families_in(text)
    holders = ""
    m = license_scan.COPYRIGHT.search(text)
    if m:
        h = re.sub(r"^\s*(\(c\)|©)?\s*[\d\s,\-–]*", "", m[1]).strip().rstrip(".")
        holders = re.escape(h) if h else ""
    return {"file": names[0], "sha256": hashlib.sha256(data).hexdigest(), "families": fams, "holders": holders,
            "source": "licence-file", "root": "ok:licence-file" if root_allowed(fams) else "fail:licence-file",
            "statement": "", "line": 0, "mentions": 0}


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
        rok = root_ok(l0)
        verdict = "pass" if rok and not failing else "fail"
        trows.append([t["id"], t["start"], l0.get("file", ""), "+".join(fam) or "none", t["provenance_licence"] or "",
                      str(len(t["files"])), str(len(t["files"]) - len(failing)), verdict,
                      ("" if rok else f"root licence not MIT, Apache-2.0, BSD or ISC ({root_code(l0)}); ")
                      + "; ".join(failing), root_code(l0), root_proof(l0, t["start"])])
    with open(a.out + ".files.tsv", "w") as f:
        f.write("task\tpath\tsources\tverdict_start\tverdict_merge\tresult\n")
        f.writelines("\t".join(r) + "\n" for r in frows)
    with open(a.out + ".tasks.tsv", "w") as f:
        f.write("task\tstart\tlicence_file\tlicence_families\tprovenance_licence\tfiles_touched\tfiles_passing\t"
                "licence_result\tfailing\troot_licence\troot_proof\n")
        f.writelines("\t".join(r) + "\n" for r in trows)
    with open(a.out + ".commits.tsv", "w") as f:
        f.write("commit\tlicence_file\tlicence_sha256\tfamilies\tfiles\tok\tok_notice\treview\texclude\texclude_kinds\t"
                "root_licence\troot_proof\n")
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
                               ",".join(f"{k}={n}" for k, n in sorted(kinds.items())), root_code(l_),
                               root_proof(l_, c)]) + "\n")
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
