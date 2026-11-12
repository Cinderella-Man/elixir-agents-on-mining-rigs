#!/usr/bin/env python3
"""The chat template a model server reported, out of an attempt's record (E103).

Reads one line on standard input: the `"chat_template": "..."` line of an attempt.json, as
`grep -m1 '"chat_template": ' attempt.json` prints it. Only that line leaves the record. Writes the template's own
bytes to the file named by $OUT_FILE and prints their length and SHA-256.

    grep -m1 '"chat_template": ' <attempt>/attempt.json | OUT_FILE=template.jinja python3 -I template_from_attempt.py
"""
import hashlib
import json
import os
import sys

line = sys.stdin.buffer.read().decode("utf-8").strip()
key = '"chat_template": '
if not line.startswith(key):
    sys.exit("not a chat_template line")
template = json.loads(line[len(key):].rstrip(","))
data = template.encode("utf-8")
with open(os.environ.get("OUT_FILE", "chat_template.jinja"), "wb") as handle:
    handle.write(data)
print(len(data), "bytes,", template.count("\n"), "line breaks, sha256", hashlib.sha256(data).hexdigest())
