#!/usr/bin/env python3
"""Check every record in a folder, and print the numbers per session.

    python3 -I check_records.py --records <folder> [--out <folder for the tables>]

For each record: the template's text built again from its messages equals its stored text; the spans cover the text
exactly once; every span holds what it says it holds; no span of the teacher's holds fixed text. Across the
records: the fixed text at the start is the same in all of them. Prints numbers only, never session text.

Writes sessions.tsv (one row per record), kinds.tsv (bytes and characters per kind of span), checks.tsv (each
record's own counts) and summary.json into --out, when given. Exits with 1 when a check fails.
"""
import argparse
import csv
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from bridge import Fixed, default_fixed_paths, sha_bytes  # noqa: E402
from verify import verify  # noqa: E402

SESSION_COLUMNS = (
    "project", "case", "run", "kept", "ends_with", "turns", "tool_calls", "answers_without_thinking",
    "answers_cut_by_the_reply_limit", "teacher_bytes", "turn_markup_bytes", "read_bytes", "text_bytes",
    "teacher_characters", "turn_markup_characters", "read_characters", "text_characters",
    "longest_tool_result_bytes", "record_bytes", "record_sha256", "text_sha256", "problems",
)
SUMMED = (
    "turns", "tool_calls", "answers_without_thinking", "answers_cut_by_the_reply_limit", "teacher_bytes",
    "turn_markup_bytes", "read_bytes", "text_bytes", "teacher_characters", "turn_markup_characters",
    "read_characters", "text_characters", "record_bytes",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--records", required=True)
    parser.add_argument("--out")
    arguments = parser.parse_args()

    fixed = Fixed(*default_fixed_paths())
    paths = sorted(
        path for path in glob.glob(os.path.join(arguments.records, "**", "*.json"), recursive=True)
        if os.path.basename(path) != "run.json"
    )
    rows, kinds, checks, problems_all, fixed_texts, versions, switch_sets = [], [], [], [], {}, set(), set()
    for path in paths:
        with open(path, "rb") as handle:
            raw = handle.read()
        record = json.loads(raw.decode("utf-8"))
        problems = verify(record, raw, fixed)
        session, sizes, counts = record["session"], record["sizes"], record["counts"]
        name = "%s %s" % (session["case"], session["run"])
        for problem in problems:
            problems_all.append("%s: %s" % (name, problem))
        fixed_texts.setdefault((record["fixed_text"]["sha256"], record["fixed_text"]["bytes"]), []).append(name)
        versions.add(record["provenance"]["converter"]["version"])
        switch_sets.add(json.dumps(record["provenance"]["switches"], sort_keys=True))
        row = {"project": session.get("project", ""), "case": session["case"], "run": session["run"],
               "kept": session.get("kept", ""), "ends_with": session["ends_with"],
               "record_bytes": len(raw), "record_sha256": sha_bytes(raw), "text_sha256": record["text_sha256"],
               "problems": len(problems)}
        for column in SESSION_COLUMNS:
            if column in counts:
                row[column] = counts[column]
            elif column in sizes:
                row[column] = sizes[column]
        rows.append(row)
        for kind, entry in sorted(sizes["by_kind"].items()):
            kinds.append({"case": session["case"], "run": session["run"], "kind": kind, **entry})
        for check, value in sorted(record["checks"].items()):
            checks.append({"case": session["case"], "run": session["run"], "check": check, "value": value})

    if len(fixed_texts) > 1:
        problems_all.append("the fixed text at the start is not the same in every record: %d forms" % len(fixed_texts))
    if len(versions) > 1:
        problems_all.append("the records were made by %d versions of the converter" % len(versions))
    if len(switch_sets) > 1:
        problems_all.append("the records were made with %d sets of switches" % len(switch_sets))

    total = {column: sum(row[column] for row in rows) for column in SUMMED}
    kind_totals = {}
    for entry in kinds:
        into = kind_totals.setdefault(entry["kind"], {"spans": 0, "characters": 0, "bytes": 0})
        for unit in into:
            into[unit] += entry[unit]
    check_totals = {}
    for entry in checks:
        if isinstance(entry["value"], bool):
            check_totals.setdefault(entry["check"], {"true": 0, "false": 0})["true" if entry["value"] else "false"] += 1
        else:
            check_totals[entry["check"]] = check_totals.get(entry["check"], 0) + entry["value"]
    summary = {
        "records": len(rows),
        "records_with_problems": sum(1 for row in rows if row["problems"]),
        "problems": problems_all,
        "fixed_text_forms": [
            {"sha256": sha, "bytes": size, "records": len(names)} for (sha, size), names in sorted(fixed_texts.items())
        ],
        "converter_versions": sorted(versions),
        "sum": total,
        "by_kind": kind_totals,
        "checks": check_totals,
    }

    def table(name, columns, lines):
        if not arguments.out:
            return
        with open(os.path.join(arguments.out, name), "w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
            writer.writerow(columns)
            for line in lines:
                writer.writerow([line.get(column, "") for column in columns])

    if arguments.out:
        os.makedirs(arguments.out, exist_ok=True)
    table("sessions.tsv", SESSION_COLUMNS, rows + [dict(total, project="sum", case="", run="", kept="")])
    table("kinds.tsv", ("case", "run", "kind", "spans", "characters", "bytes"),
          kinds + [dict(entry, case="sum", run="", kind=kind) for kind, entry in sorted(kind_totals.items())])
    table("checks.tsv", ("case", "run", "check", "value"), checks)
    if arguments.out:
        with open(os.path.join(arguments.out, "summary.json"), "w", encoding="utf-8") as handle:
            json.dump(summary, handle, indent=2, sort_keys=True)
            handle.write("\n")

    shown = ("case", "run", "turns", "tool_calls", "answers_without_thinking", "teacher_bytes", "read_bytes",
             "text_bytes", "problems", "record_sha256")
    print("\t".join(shown))
    for row in rows:
        print("\t".join(str(row.get(column, "")) for column in shown))
    print("\t".join(str(dict(total, case="sum", run="", problems=len(problems_all), record_sha256="").get(column, ""))
                    for column in shown))
    for problem in problems_all:
        print("PROBLEM %s" % problem)
    print("%d records, %d problems, %d form(s) of the fixed text" % (len(rows), len(problems_all), len(fixed_texts)))
    sys.exit(1 if problems_all else 0)


if __name__ == "__main__":
    main()
