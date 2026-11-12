#!/usr/bin/env python3
"""Read-only. Summarises what a case's change does inside one file that the licence scan
left out as too large to read.

Run on the data-mining machine:
    python3 -I - <case folder> <path of the file inside the project>  < read_large_file_hunks.py

For each patch in the case folder that touches the file it prints: the number of added and
removed lines, the JSON keys on those lines with counts (for a lock file), every licence
name the added lines carry, any line that looks like a licence notice or a copyright line,
and the longest added lines cut short. It writes nothing.
"""
import collections
import os
import re
import sys

case_dir, target = sys.argv[1], sys.argv[2]
NOTICE = re.compile(r"(?i)copyright|licensed under|permission is hereby|all rights reserved|gnu general|mozilla public|creative commons|SPDX-License")
KEY = re.compile(r'^\s*"([^"]+)"\s*:')
LIC = re.compile(r'^\s*"license"\s*:\s*"([^"]*)"')

for name in sorted(os.listdir(case_dir)):
    if not name.endswith(".patch"):
        continue
    path = os.path.join(case_dir, name)
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    inside, added, removed, hunks = False, [], [], 0
    for line in lines:
        if line.startswith("diff --git "):
            inside = line.rstrip().endswith(" b/" + target)
            continue
        if not inside:
            continue
        if line.startswith("@@"):
            hunks += 1
        elif line.startswith("+") and not line.startswith("+++"):
            added.append(line[1:])
        elif line.startswith("-") and not line.startswith("---"):
            removed.append(line[1:])
    if not hunks:
        continue
    print(f"== {name}: {hunks} hunks, {len(added)} lines added, {len(removed)} lines removed in {target}")
    print(f"   bytes added: {sum(len(x) + 1 for x in added)}")
    # count the well-known lock-file keys, and everything else as package names
    KNOWN_KEYS = ["version", "resolved", "integrity", "dev", "optional", "peer", "license", "engines", "node",
                  "dependencies", "peerDependencies", "optionalDependencies", "devDependencies", "bin", "funding",
                  "url", "type", "requires", "cpu", "os", "hasInstallScript", "deprecated", "peerDependenciesMeta",
                  "name", "lockfileVersion", "packages", "npm", "inBundle", "bundleDependencies", "license"]
    keys = collections.Counter()
    brackets = 0
    not_json = []
    for x in added:
        s = x.strip()
        if s in ("{", "}", "},", "[", "]", "],", ""):
            brackets += 1
            continue
        m = KEY.match(x)
        if not m:
            not_json.append(x)
            continue
        k = m.group(1)
        keys[k if k in KNOWN_KEYS else "(a package name, a path under node_modules, or a version range)"] += 1
    print(f"   added lines that are only brackets or blank: {brackets}")
    print("   added lines by JSON key:")
    for k, n in keys.most_common():
        print(f"      {n:6d}  {k}")
    print(f"   added lines that are not a JSON key line: {len(not_json)}")
    for x in not_json[:8]:
        print(f"      | {x[:140]}")
    lic = collections.Counter(m.group(1) for m in (LIC.match(x) for x in added) if m)
    print(f"   licence names on added lines (package information): {dict(lic) if lic else 'none'}")
    lic_r = collections.Counter(m.group(1) for m in (LIC.match(x) for x in removed) if m)
    print(f"   licence names on removed lines: {dict(lic_r) if lic_r else 'none'}")
    notes = [x for x in added if NOTICE.search(x)]
    print(f"   added lines that look like a licence notice or a copyright line: {len(notes)}")
    for x in notes[:8]:
        print(f"      | {x.strip()[:160]}")
    longest = sorted(added, key=len, reverse=True)[:3]
    print("   the three longest added lines, cut at 160:")
    for x in longest:
        print(f"      | {x.strip()[:160]}")
