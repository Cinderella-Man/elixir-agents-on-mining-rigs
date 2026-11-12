#!/usr/bin/env python3
"""One row of switch_effects.tsv: the records of a conversion with one thing changed, against the first run's.

    python3 -I switch_effects.py <label> <first run's records.tsv> <other records.tsv> <other errors.tsv> <check's last line>
"""
import csv
import re
import sys

label, first_path, other_path, errors_path, check_line = sys.argv[1:6]


def rows(path):
    try:
        with open(path, encoding="utf-8", newline="") as handle:
            return list(csv.DictReader(handle, delimiter="\t", quoting=csv.QUOTE_NONE))
    except OSError:
        return []


first = {(row["case"], row["run"]): row for row in rows(first_path)}
other = {(row["case"], row["run"]): row for row in rows(other_path)}
changed = sum(1 for key, row in other.items() if key in first and row["text_sha256"] != first[key]["text_sha256"])
fixed = sum(
    1 for key, row in other.items() if key in first and row["fixed_text_sha256"] != first[key]["fixed_text_sha256"]
)
match = re.match(r"(\d+) records, (\d+) problems", check_line or "")
print("\t".join(str(value) for value in (
    label, len(other), len(rows(errors_path)), changed,
    sum(int(row["text_bytes"]) for row in other.values()),
    sum(int(row["text_bytes"]) for key, row in first.items() if key in other),
    fixed, match[2] if match else "check did not run",
)))
