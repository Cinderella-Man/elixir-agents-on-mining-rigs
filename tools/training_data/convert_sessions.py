#!/usr/bin/env python3
"""Convert every session an index lists, one record each.

    python3 -I convert_sessions.py --index <sessions.tsv> --root <folder> --kept yes --out <folder>

The index is a tab-separated table with a header and the columns project, case, attempt, kept and path (the layout
of the raw-sessions repository). An attempt's folder is <root>/<path>/engine/<case>; --layout changes that. Only
rows whose kept column equals --kept are converted. Stored sessions are read and never changed.

Writes into --out:
  <project>/<case>__<attempt>.json   the records
  records.tsv                        one row per record: its hash and its counts
  errors.tsv                         one row per session that could not be converted, with the reason (no text)
  run.json                           the converter's version, the template's hash, the switches, the software

Exits with 2 when a session could not be converted.
"""
import argparse
import csv
import json
import os
import platform
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import jinja2  # noqa: E402

import record as record_module  # noqa: E402
import switches as switches_module  # noqa: E402
from bridge import ConversionError, Fixed, default_fixed_paths  # noqa: E402
from convert_session import convert, summary  # noqa: E402
from render import RenderError  # noqa: E402

COLUMNS = (
    "project", "case", "run", "kept", "record", "record_bytes", "record_sha256", "text_sha256",
    "fixed_text_sha256", "turns", "tool_calls", "answers_without_thinking", "teacher_bytes", "turn_markup_bytes",
    "read_bytes", "text_bytes",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--index", required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--kept", required=True, choices=("yes", "no"))
    parser.add_argument("--out", required=True)
    parser.add_argument("--layout", default="{path}/engine/{case}")
    parser.add_argument("--project", action="append", default=[], help="only this project (may be repeated)")
    parser.add_argument("--switch", action="append", default=[], metavar="NAME=VALUE")
    arguments = parser.parse_args()

    given = switches_module.parse_assignments(arguments.switch)
    fixed = Fixed(*default_fixed_paths())
    with open(arguments.index, encoding="utf-8", newline="") as handle:
        rows = [row for row in csv.DictReader(handle, delimiter="\t", quoting=csv.QUOTE_NONE)]
    rows = [row for row in rows if row["kept"] == arguments.kept
            and (not arguments.project or row["project"] in arguments.project)]
    rows.sort(key=lambda row: (row["project"], row["case"], row["attempt"]))

    os.makedirs(arguments.out, exist_ok=True)
    done, failed = [], []
    for row in rows:
        folder = os.path.join(arguments.root, arguments.layout.format(**row))
        name = os.path.join(row["project"], "%s__%s.json" % (row["case"], row["attempt"]))
        label = {"project": row["project"], "kept": row["kept"]}
        try:
            record, data = convert(folder, os.path.join(arguments.out, name), given, label, fixed)
        except (ConversionError, RenderError) as error:
            failed.append({"project": row["project"], "case": row["case"], "run": row["attempt"],
                           "error": type(error).__name__, "reason": str(error)})
            print("NOT CONVERTED %s %s: %s" % (row["case"], row["attempt"], error), file=sys.stderr)
            continue
        line = summary(record, data, name)
        line.update({"project": row["project"], "kept": row["kept"]})
        if line["run"] != row["attempt"]:
            failed.append({"project": row["project"], "case": row["case"], "run": row["attempt"],
                           "error": "RunIdDiffers", "reason": "the run's own record names another run id"})
        done.append(line)
        print("converted %s %s: %d turns, %d bytes of text" % (
            row["case"], row["attempt"], line["turns"], line["text_bytes"]), file=sys.stderr)

    with open(os.path.join(arguments.out, "records.tsv"), "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(COLUMNS)
        for line in done:
            writer.writerow([line[column] for column in COLUMNS])
    with open(os.path.join(arguments.out, "errors.tsv"), "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(("project", "case", "run", "error", "reason"))
        for line in failed:
            writer.writerow([line[column] for column in ("project", "case", "run", "error", "reason")])
    version, files = record_module.converter_version()
    with open(os.path.join(arguments.out, "run.json"), "w", encoding="utf-8") as handle:
        json.dump({
            "format": record_module.FORMAT,
            "converter": {"version": version, "files": files},
            "template": {"name": fixed.template_name, "sha256": fixed.template_sha256},
            "tools_sha256": fixed.tools_sha256,
            "system_fixed_sha256": fixed.system_before_sha256,
            "switches": switches_module.resolve(given),
            "kept": arguments.kept,
            "sessions_listed": len(rows),
            "records": len(done),
            "not_converted": len(failed),
            "software": {"python": platform.python_version(), "jinja2": jinja2.__version__},
        }, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print("%d of %d sessions converted, %d not" % (len(done), len(rows), len(failed)))
    sys.exit(2 if failed else 0)


if __name__ == "__main__":
    main()
