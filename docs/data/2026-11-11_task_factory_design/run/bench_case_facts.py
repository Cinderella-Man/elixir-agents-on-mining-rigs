"""Facts about the Elixir SWE Bench's case folders, read from each case.json, provenance.json and the file sizes.
Reads only; standard library only.

usage: BENCH=<checkout of Cinderella-Man/elixir-swe-bench> python3 bench_case_facts.py
  prints, per case, the fields of bench_cases.tsv
"""
import glob
import hashlib
import json
import os

cases = os.path.join(os.environ["BENCH"], "cases")
for manifest in sorted(glob.glob(os.path.join(cases, "*", "case.json"))):
    folder = os.path.dirname(manifest)
    case = os.path.basename(folder)
    s = json.load(open(manifest))
    p = json.load(open(os.path.join(folder, "provenance.json")))
    g = s["grading"]

    def size(name):
        return os.path.getsize(os.path.join(folder, name))

    integrity = hashlib.sha256(open(os.path.join(folder, "integrity.patch"), "rb").read()).hexdigest()[:8]
    print(case, "|", s.get("task_kind"), "| services", ",".join(s.get("services", {})) or "-",
          "| adapter", g["adapter"], "| timeout", s.get("test_timeout"))
    print("   required", len(g["required"]), "starting", len(g["starting_failures"]),
          "requirements", len(g["requirements"]), "| integrity", integrity)
    print("   ticket", size("ticket.md"), "| reference", size("reference.patch"),
          "| incomplete", size("incomplete.patch"), "| acceptance", size("acceptance.patch"))
    print("   provenance keys", sorted(p))
    print("   preparation files", json.dumps(p.get("preparation", {}).get("files")),
          "| upstream issue", p.get("upstream", {}).get("issue"))
