#!/usr/bin/env python3
"""How much of each prompt the server took from its cache (E103).

Reads the closing usage record of every recorded reply stream on standard input, one per line, as
`grep -H '"timings"' */response-*.sse` prints them: `<attempt>/response-NNNN.sse:data: {...}`. Those records hold
numbers only. A call's prompt is the conversation so far as the chat template writes it; the cache holds the previous
prompt and what the model then wrote. So `cache_n` of call k against `prompt_tokens + completion_tokens` of call k-1
says whether the template writes the model's last reply back as the same tokens the model produced.

    grep -H '"timings"' */response-*.sse | CALLS=out/calls_by_message.json python3 -I cache_reuse.py
"""
import collections
import json
import os
import re
import sys

calls = collections.defaultdict(dict)
for line in sys.stdin:
    match = re.match(r"(?:.*/)?([^/]+)/response-(\d+)\.sse:data: (\{.*\})\s*$", line)
    if not match:
        continue
    record = json.loads(match[3])
    usage, timings = record.get("usage") or {}, record.get("timings") or {}
    calls[match[1]][int(match[2])] = {
        "prompt": usage.get("prompt_tokens"),
        "completion": usage.get("completion_tokens"),
        "cached": (usage.get("prompt_tokens_details") or {}).get("cached_tokens"),
        "cache_n": timings.get("cache_n"),
        "prompt_n": timings.get("prompt_n"),
    }

# Optional: the shape of each reply (which tools it called, whether it held text), written by frame_openai.py.
shapes = json.load(open(os.environ["CALLS"])) if os.environ.get("CALLS") else {}

gap = collections.Counter()
first = collections.Counter()
same_fields = collections.Counter()
by_shape = collections.defaultdict(collections.Counter)
total = pairs = 0
for attempt, steps in calls.items():
    for step, call in steps.items():
        total += 1
        same_fields["cached_tokens == cache_n: %s" % (call["cached"] == call["cache_n"])] += 1
        same_fields["cache_n + prompt_n == prompt_tokens: %s" % (call["cache_n"] + call["prompt_n"] == call["prompt"])] += 1
        previous = steps.get(step - 1)
        if previous is None:
            first["first call of an attempt, cache_n %s" % ("0" if call["cache_n"] == 0 else "above 0")] += 1
            continue
        pairs += 1
        missed = previous["prompt"] + previous["completion"] - call["cache_n"]
        gap[missed] += 1
        replies = shapes.get(attempt) or []
        if step - 1 < len(replies):
            reply = replies[step - 1]
            kind = "0" if missed == 0 else "1" if missed == 1 else "more"
            tools = set(reply["tools"])
            labels = ["all replies"]
            labels.append("with text beside the calls" if reply["text"] else "no text beside the calls")
            labels.append("%d call%s" % (len(reply["tools"]), "" if len(reply["tools"]) == 1 else "s"))
            labels += ["calls %s" % name for name in sorted(tools)]
            if reply["values_that_are_not_text"]:
                labels += ["a value that is not text: %s" % v for v in sorted(set(reply["values_that_are_not_text"]))]
            else:
                labels.append("every value is text")
            if reply["thinking_edges"] not in (None, [0, 1]):
                labels.append("thinking does not end with exactly one line break")
            if len(reply.get("forms") or []) == 1 and not reply["text"]:
                labels.append("one call, no text: %s" % reply["forms"][0])
            for label in labels:
                by_shape[label][kind] += 1

report = {
    "attempts": len(calls),
    "calls": total,
    "calls_with_a_call_before_them": pairs,
    "first_calls": dict(first),
    "field_checks": dict(same_fields),
    "previous prompt_tokens + completion_tokens - cache_n: value -> calls": {
        str(value): count for value, count in sorted(gap.items(), key=lambda item: (-item[1], item[0]))[:25]
    },
    "values_listed": min(25, len(gap)),
    "distinct_values": len(gap),
    "calls that missed more than 1 token": sum(count for value, count in gap.items() if value > 1),
    "smallest value above 1": min([value for value in gap if value > 1], default=None),
    "largest value": max(gap, default=None),
    "smallest value": min(gap, default=None),
    "by the shape of the reply before the call: calls that missed 0, 1 or more tokens": {
        label: {kind: counts.get(kind, 0) for kind in ("0", "1", "more")} for label, counts in sorted(by_shape.items())
    },
}
json.dump(report, sys.stdout, indent=1)
print()
