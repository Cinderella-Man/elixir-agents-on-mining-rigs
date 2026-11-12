#!/usr/bin/env python3
"""Turn one stored teacher session into its training record.

    python3 -I convert_session.py --attempt <the attempt's folder> --out <record.json> [--switch name=value ...]

The attempt's folder is the engine's own: request-NNNN.json, response-NNNN.sse, pi-events.jsonl, attempt.json, with
run.json one level up. It is read and never changed. The template, the tool definitions and the agent's fixed
system text come from the recorded target text: the environment's TEMPLATE, TOOLS and SYSTEM_BEFORE, or TARGET_TEXT
for the folder that holds all three, or this repository's docs/data/2026-11-12_target_text_qwen38_27b/.

Prints one line of JSON with the record's hash and counts. On a session it cannot convert it writes nothing, prints
the reason with hashes and lengths (never text) and exits with 2.
"""
import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import record as record_module  # noqa: E402
import switches as switches_module  # noqa: E402
from bridge import Attempt, ConversionError, Fixed, default_fixed_paths, sha_bytes  # noqa: E402
from render import RenderError  # noqa: E402


def summary(record, data, path):
    sizes, counts = record["sizes"], record["counts"]
    return {
        "record": path,
        "record_bytes": len(data),
        "record_sha256": sha_bytes(data),
        "text_sha256": record["text_sha256"],
        "fixed_text_sha256": record["fixed_text"]["sha256"],
        "case": record["session"]["case"],
        "run": record["session"]["run"],
        "turns": counts["turns"],
        "tool_calls": counts["tool_calls"],
        "answers_without_thinking": counts["answers_without_thinking"],
        "teacher_bytes": sizes["teacher_bytes"],
        "turn_markup_bytes": sizes["turn_markup_bytes"],
        "read_bytes": sizes["read_bytes"],
        "text_bytes": sizes["text_bytes"],
    }


def convert(attempt_folder, out_path, given_switches=None, label=None, fixed=None):
    """Convert one attempt and write its record. Returns (record, bytes)."""
    fixed = fixed or Fixed(*default_fixed_paths())
    attempt = Attempt(attempt_folder)
    record = record_module.build(attempt, fixed, given_switches, label)
    data = record_module.dump(record)
    if out_path:
        os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
        temporary = out_path + ".part"
        with open(temporary, "wb") as handle:
            handle.write(data)
        os.replace(temporary, out_path)
    return record, data


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--attempt", required=True, help="the engine's folder of one attempt")
    parser.add_argument("--out", required=True, help="the record to write")
    parser.add_argument("--project", help="the project's name, stored in the record")
    parser.add_argument("--kept", choices=("yes", "no"), help="whether the session was kept, stored in the record")
    parser.add_argument("--switch", action="append", default=[], metavar="NAME=VALUE")
    arguments = parser.parse_args()
    label = {}
    if arguments.project:
        label["project"] = arguments.project
    if arguments.kept:
        label["kept"] = arguments.kept
    try:
        record, data = convert(
            arguments.attempt, arguments.out, switches_module.parse_assignments(arguments.switch), label
        )
    except (ConversionError, RenderError) as error:
        print(json.dumps({"error": type(error).__name__, "reason": str(error)}), file=sys.stderr)
        sys.exit(2)
    print(json.dumps(summary(record, data, arguments.out), sort_keys=True))


if __name__ == "__main__":
    main()
