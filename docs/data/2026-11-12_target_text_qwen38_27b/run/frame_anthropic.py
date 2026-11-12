#!/usr/bin/env python3
"""The frame of the teacher's sessions, recorded on Pi's Anthropic-style route, beside the bench's frame (E103).

Reads the attempt folders under $RUNS in place (<run>/<attempt>/request-NNNN.json, response-NNNN.sse), read only, and
only attempts that have an attempt.json. Writes into $OUT:

  report_anthropic.json           counts, hashes and shapes only
  teacher_first_request.frame.json, teacher_middle_request.frame.json
                                  two requests of $FRAME_ATTEMPT, every piece of content replaced by a placeholder

With $BENCH set to the folder frame_openai.py wrote, the report also says whether Pi's fixed text is the same bytes
on both routes.

    RUNS=<the job's runs folder> OUT=out BENCH=out FRAME_ATTEMPT=<run>/<attempt> FRAME_STEP=3 python3 -I frame_anthropic.py
"""
import collections
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frame_openai import (  # noqa: E402
    WRAPPER, compact, instructions_frame, result_form, sha, split_system, tail_frame,
)

RUNS = os.environ.get("RUNS", ".")
OUT = os.environ.get("OUT", ".")
BENCH = os.environ.get("BENCH", "")
FRAME_ATTEMPT = os.environ.get("FRAME_ATTEMPT", "")
FRAME_STEP = int(os.environ.get("FRAME_STEP", "3"))
CALL_ID = re.compile(r"call_[0-9a-f]{24}")


def input_frame(value):
    """A tool call's input object with its values replaced: the keys and their order stay."""

    def blank(key, item):
        if isinstance(item, str):
            return "<%s>" % {"command": "COMMAND", "path": "PATH"}.get(key, "TEXT")
        if isinstance(item, bool) or item is None:
            return item
        if isinstance(item, (int, float)):
            return "<NUMBER>"
        if isinstance(item, list):
            if item and all(isinstance(entry, dict) for entry in item):
                one = {k: blank(k, v) for k, v in item[0].items()}
                return [one] + (["<%d MORE LIKE IT>" % (len(item) - 1)] if len(item) > 1 else [])
            return ["<LIST>"]
        return {"<OBJECT>": ""}

    if not isinstance(value, dict):
        return "<INPUT THAT IS NOT AN OBJECT>"
    return {key: blank(key, item) for key, item in value.items()}


def edges(text):
    """How a text starts and ends: the white space the student's template would trim."""
    lead, trail = text[: len(text) - len(text.lstrip())], text[len(text.rstrip()):]
    name = lambda part: "none" if part == "" else "line breaks only" if set(part) == {"\n"} else "other space"
    return "starts with: %s; ends with: %s" % (name(lead), name(trail))


def block_frame(block, ids, names):
    out = {}
    kind = block.get("type")
    for key, value in block.items():
        if key in ("type", "name", "is_error", "cache_control"):
            out[key] = value
        elif key == "id":
            ids.setdefault(value, "<CALL ID %d>" % (len(ids) + 1))
            names[value] = (block.get("name"), block.get("input"))
            out[key] = ids[value]
        elif key == "tool_use_id":
            out[key] = ids.get(value, "<CALL ID NOT SEEN>")
        elif key == "input":
            out[key] = input_frame(value)
        elif key == "thinking":
            out[key] = "<MODEL THINKING>" if value else value
        elif key == "signature":
            out[key] = value if value == "" else "<SIGNATURE>"
        elif key == "text":
            out[key] = "<MODEL TEXT>" if value else value
        elif key == "content" and kind == "tool_result":
            name, parsed = names.get(block.get("tool_use_id"), (None, None))
            out[key] = result_form(name, value, parsed) if isinstance(value, str) else "<TYPED CONTENT>"
        else:
            out[key] = "<VALUE OF A KEY THIS SCRIPT DOES NOT KNOW>"
    return out


def system_frame(text):
    parts = split_system(text)
    if parts is None:
        return "<SYSTEM TEXT OF ANOTHER SHAPE>"
    before, body, after = parts
    frame, _ = instructions_frame(body)
    return before + (frame if frame is not None else "<INSTRUCTION TEXT>\n") + tail_frame(after)


def request_frame(request):
    out = {}
    ids, names = {}, {}
    for key, value in request.items():
        if key == "system":
            out[key] = [
                {k: (system_frame(v) if k == "text" else v) for k, v in part.items()} for part in value
            ] if isinstance(value, list) else system_frame(value)
        elif key == "messages":
            messages = []
            for index, message in enumerate(value):
                content = message.get("content")
                if index == 0 and isinstance(content, list) and len(content) == 1 and WRAPPER.fullmatch(
                    content[0].get("text", "")
                ):
                    text = '<file name="/tmp/eab-ticket.md">\n<CASE TEXT, ENDING WITH A LINE BREAK>\n</file>\n'
                    part = {k: (text if k == "text" else v) for k, v in content[0].items()}
                    messages.append({k: ([part] if k == "content" else v) for k, v in message.items()})
                elif isinstance(content, list):
                    blocks = [block_frame(block, ids, names) for block in content]
                    messages.append({k: (blocks if k == "content" else v) for k, v in message.items()})
                else:
                    messages.append({k: ("<TEXT>" if k == "content" else v) for k, v in message.items()})
            out[key] = messages
        else:
            out[key] = value
    return out


def stream_calls(path):
    """The tool calls of one recorded reply stream, their inputs as the server wrote them (the key order is kept)."""
    names, pieces = {}, collections.defaultdict(str)
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if not line.startswith("data:"):
                    continue
                try:
                    event = json.loads(line[5:])
                except ValueError:
                    continue
                if event.get("type") == "content_block_start" and event["content_block"].get("type") == "tool_use":
                    names[event["index"]] = event["content_block"].get("name")
                elif event.get("type") == "content_block_delta" and event["delta"].get("type") == "input_json_delta":
                    pieces[event["index"]] += event["delta"].get("partial_json", "")
    except OSError:
        return []
    return [(names[index], pieces[index]) for index in sorted(names)]


def main():
    count = collections.Counter
    report = {
        "attempts": 0,
        "requests_read": 0,
        "top_level_keys": count(),
        "values": collections.defaultdict(count),
        "tools": count(),
        "tool_keys": count(),
        "system_shape": count(),
        "system_before_instructions": count(),
        "system_after_instructions": count(),
        "instructions": collections.defaultdict(count),
        "first_user_message": count(),
        "cache_marks_per_request": count(),
        "role_pairs": count(),
        "assistant_blocks": count(),
        "thinking_block": count(),
        "thinking_text": count(),
        "text_block": count(),
        "tool_calls_per_assistant_message": count(),
        "tool_call": collections.defaultdict(count),
        "tool_call_inputs_in_requests": count(),
        "tool_call_inputs_in_reply_streams": count(),
        "tool_result_blocks": count(),
        "tool_result_forms": count(),
        "tool_results_follow_their_calls_in_order": count(),
        "grows_only": count(),
    }
    fixed = {"before": set(), "tools": set()}
    frames = {}

    for record in sorted(glob.glob(os.path.join(RUNS, "*", "*", "attempt.json"))):
        folder = os.path.dirname(record)
        attempt = os.path.relpath(folder, RUNS)
        paths = sorted(glob.glob(os.path.join(folder, "request-*.json")))
        if not paths:
            continue
        report["attempts"] += 1
        requests = {}
        for path in paths:
            with open(path, encoding="utf-8") as handle:
                requests[int(re.search(r"request-(\d+)\.json$", path)[1])] = json.load(handle)
        report["requests_read"] += len(requests)
        steps = sorted(requests)

        def unmarked(value):
            """A request's messages without the cache marks, which move from request to request."""
            if isinstance(value, dict):
                return {k: unmarked(v) for k, v in value.items() if k != "cache_control"}
            if isinstance(value, list):
                return [unmarked(v) for v in value]
            return value

        for step in steps:
            request = requests[step]
            report["top_level_keys"][",".join(request.keys())] += 1
            for key, value in request.items():
                if key not in ("messages", "tools", "system"):
                    report["values"][key][compact(value)] += 1
            as_openai = [
                {"function": {"description": t.get("description"), "name": t.get("name"),
                              "parameters": t.get("input_schema")}, "type": "function"}
                for t in request.get("tools") or []
            ]
            fixed["tools"].add(compact(as_openai))
            report["tools"]["as the bench's form, sha256 " + sha(compact(as_openai))] += 1
            for tool in request.get("tools") or []:
                report["tool_keys"][",".join(tool.keys())] += 1
            marks = json.dumps(request).count('"cache_control"')
            report["cache_marks_per_request"][str(marks)] += 1
        for earlier, later in zip(steps, steps[1:]):
            if later == earlier + 1:
                a, b = unmarked(requests[earlier]["messages"]), unmarked(requests[later]["messages"])
                report["grows_only"]["yes" if b[: len(a)] == a and len(b) > len(a) else "no"] += 1

        first = requests[steps[0]]
        system = first.get("system")
        if isinstance(system, list) and len(system) == 1 and isinstance(system[0].get("text"), str):
            report["system_shape"]["a list of one text part, keys %s" % ",".join(system[0].keys())] += 1
            text = system[0]["text"]
        elif isinstance(system, str):
            report["system_shape"]["text"] += 1
            text = system
        else:
            report["system_shape"]["another shape"] += 1
            text = None
        parts = split_system(text) if text else None
        if parts is None:
            report["system_before_instructions"]["not the known shape"] += 1
        else:
            before, body, after = parts
            fixed["before"].add(before)
            report["system_before_instructions"]["%d characters, sha256 %s" % (len(before), sha(before))] += 1
            after_frame = tail_frame(after)
            report["system_after_instructions"][
                "%d characters, sha256 %s%s"
                % (len(after_frame), sha(after_frame), "" if after_frame == after else " (with a project guide)")
            ] += 1
            _, facts = instructions_frame(body)
            report["instructions"]["known sentences"]["no" if facts is None else "yes"] += 1
            for key, value in (facts or {}).items():
                report["instructions"][key][str(value)] += 1
        user = first["messages"][0]
        content = user.get("content")
        if user["role"] == "user" and isinstance(content, list) and len(content) == 1:
            match = WRAPPER.fullmatch(content[0].get("text", ""))
            report["first_user_message"][
                "one text part, keys %s; %s" % (
                    ",".join(content[0].keys()),
                    "no file wrapper" if not match else "file wrapper, the text inside ends with %s"
                    % ("a line break" if match["text"].endswith("\n") else "no line break"),
                )
            ] += 1
        else:
            report["first_user_message"]["another shape"] += 1

        last = requests[steps[-1]]["messages"]
        names, pending = {}, []
        for previous, message in zip([None] + last, last):
            kinds = [b.get("type") for b in message["content"]] if isinstance(message.get("content"), list) else ["text"]
            label = message["role"] + (" (tool results)" if "tool_result" in kinds else "")
            before_label = "start"
            if previous is not None:
                previous_kinds = [b.get("type") for b in previous["content"]] if isinstance(previous.get("content"), list) else []
                before_label = previous["role"] + (" (tool results)" if "tool_result" in previous_kinds else "")
            report["role_pairs"]["%s -> %s" % (before_label, label)] += 1
            if not isinstance(message.get("content"), list):
                continue
            if message["role"] == "assistant":
                merged = []
                for kind in kinds:
                    if not merged or merged[-1] != kind:
                        merged.append(kind)
                report["assistant_blocks"][", ".join(merged)] += 1
                calls = [b for b in message["content"] if b.get("type") == "tool_use"]
                report["tool_calls_per_assistant_message"][str(len(calls))] += 1
                pending = [call["id"] for call in calls]
                for block in message["content"]:
                    if block.get("type") == "thinking":
                        report["thinking_block"][
                            "keys %s; signature %s" % (",".join(block.keys()), "empty" if block.get("signature") == "" else "not empty")
                        ] += 1
                        report["thinking_text"][edges(block.get("thinking") or "") if block.get("thinking") else "empty"] += 1
                    elif block.get("type") == "text":
                        report["text_block"][edges(block.get("text") or "") if block.get("text") else "empty"] += 1
                    elif block.get("type") == "tool_use":
                        names[block["id"]] = (block.get("name"), block.get("input"))
                        report["tool_call"]["keys"][",".join(block.keys())] += 1
                        report["tool_call"]["name"][str(block.get("name"))] += 1
                        report["tool_call"]["id"][
                            "call_ and 24 hex digits" if CALL_ID.fullmatch(block["id"]) else "another form"
                        ] += 1
                        report["tool_call_inputs_in_requests"][
                            "%s %s" % (block.get("name"), compact(input_frame(block.get("input"))))
                        ] += 1
            else:
                for block in message["content"]:
                    if block.get("type") != "tool_result":
                        continue
                    name, parsed = names.get(block.get("tool_use_id"), ("unknown", None))
                    order = bool(pending) and pending.pop(0) == block.get("tool_use_id")
                    report["tool_results_follow_their_calls_in_order"]["yes" if order else "no"] += 1
                    content = block.get("content")
                    report["tool_result_blocks"][
                        "keys %s; content is %s" % (",".join(block.keys()), type(content).__name__)
                    ] += 1
                    form = result_form(name, content, parsed) if isinstance(content, str) else "<TYPED CONTENT>"
                    report["tool_result_forms"][
                        "%s: %s | is_error %s" % (name, form.replace("\n", "\\n"), json.dumps(block.get("is_error")))
                    ] += 1

        for path in sorted(glob.glob(os.path.join(folder, "response-*.sse"))):
            for tool, raw in stream_calls(path):
                try:
                    value = json.loads(raw)
                except ValueError:
                    report["tool_call_inputs_in_reply_streams"]["%s <NOT JSON>" % tool] += 1
                    continue
                report["tool_call_inputs_in_reply_streams"]["%s %s" % (tool, compact(input_frame(value)))] += 1
                report["tool_call"]["input in the reply stream is compact JSON"][
                    "yes" if compact(value) == raw else "no"
                ] += 1

        if attempt == FRAME_ATTEMPT:
            for step, file in ((steps[0], "teacher_first_request.frame.json"),
                               (FRAME_STEP, "teacher_middle_request.frame.json")):
                if step in requests:
                    frames[file] = {"request": step, "messages": len(requests[step]["messages"])}
                    os.makedirs(OUT, exist_ok=True)
                    with open(os.path.join(OUT, file), "w", encoding="utf-8") as handle:
                        json.dump(request_frame(requests[step]), handle, indent=2, ensure_ascii=False)
                        handle.write("\n")

    report["frames"] = frames
    if BENCH:
        same = {}
        for key, file in (("before", "pi_system_text_before_instructions.txt"), ("tools", "pi_tools_openai.json")):
            path = os.path.join(BENCH, file)
            if os.path.exists(path) and len(fixed[key]) == 1:
                with open(path, encoding="utf-8", newline="") as handle:
                    theirs = handle.read()
                ours = next(iter(fixed[key]))
                if key == "tools":
                    same[file] = "the same values" if json.loads(theirs) == json.loads(ours) else "different"
                else:
                    same[file] = "the same bytes" if theirs == ours else "different"
            else:
                same[file] = "not compared: %d forms on this side" % len(fixed[key])
        report["against_the_bench"] = same
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "report_anthropic.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    json.dump(report, sys.stdout, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
