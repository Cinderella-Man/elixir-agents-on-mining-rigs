#!/usr/bin/env python3
"""The frame of requests recorded on Pi's OpenAI-style route (E103).

Reads a tar stream of attempt folders on standard input: <attempt>/request-NNNN.json and <attempt>/usage-NNNN.json,
as the engine's gateway recorded them. Nothing read is written to disk as it is. The script writes, into $OUT:

  report_openai.json            counts, hashes and shapes only
  first_request.frame.json      the first request of $FRAME_ATTEMPT, every piece of content replaced by a placeholder
  middle_request.frame.json     request number $FRAME_STEP of the same attempt, the same way
  pi_system_text_before_instructions.txt, pi_system_text_after_instructions.txt, pi_tools_openai.json
                                the fixed text, written only when it is the same bytes in every attempt read

    tar -cf - <attempt folders' request and usage files> | OUT=out FRAME_ATTEMPT=<attempt> FRAME_STEP=3 python3 -I frame_openai.py
"""
import collections
import hashlib
import json
import os
import re
import sys
import tarfile

OUT = os.environ.get("OUT", ".")
FRAME_ATTEMPT = os.environ.get("FRAME_ATTEMPT", "")
FRAME_STEP = int(os.environ.get("FRAME_STEP", "3"))
MIN_ATTEMPTS = int(os.environ.get("MIN_ATTEMPTS", "4"))  # a wrapper line must be seen in this many attempts

TESTS = {
    "behavioral": "Add or change a test that fails in its test body on the starting source and passes after your "
    "change. Compilation/setup failures do not count.",
    "preservation": "Add or change a test covering the stated contract or preserved behavior. No behavioral "
    "regression on the starting source is required for this refactor.",
    "optional": "Run the relevant tests; additional tests are optional.",
}
BROWSER = (
    "Chromium and Playwright are preinstalled. Node tests can import process.env.EAB_BROWSER_MODULE. Bind any test "
    "web server to loopback and close browsers/servers after each suite."
)
INSTRUCTIONS = re.compile(
    r"Complete the (?P<kind>[a-z_]+) task in /workspace\. Investigate the source and run the relevant tests\.\n"
    r"Test command: (?P<test>[^\n]+)\.\n"
    r"(?P<tests>[^\n]+)\n"
    r"(?P<required>(?:Required outcome \([^)\n]+\): [^\n]*\n)+|\n)"  # with no such line the text has an empty line
    r"Dependencies are prepared\. The workspace is offline\. Preserve existing behavior and do not weaken tests\.\n"
    r"(?P<extra>[^\n]*)\n"
    r"Allowed edit prefixes: (?P<prefixes>[^\n]+)\.\n"
    r"When finished, give a short summary\. Your current patch is then checked in a fresh workspace\.\n"
    r"Model and tool calls are unlimited\. Limits: (?P<max>\d+) generated tokens total, (?P<window>\d+) context "
    r"tokens including up to (?P<response>\d+) response tokens\.\n"
    r"History is never compacted\. If a budget is exhausted, the current patch is graded\.\n"
    r"Task details: (?P<details>\{[^\n]*\})\n"
)
WRAPPER = re.compile(r'<file name="/tmp/eab-ticket\.md">\n(?P<text>.*)\n</file>\n', re.S)
GUIDE = re.compile(r'(<project_instructions path=")[^"\n]*(">\n).*?(\n</project_instructions>)', re.S)
CALL_ID = re.compile(r"[A-Za-z0-9]{32}")


def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def compact(value):
    return json.dumps(value, separators=(",", ":"), ensure_ascii=False)


def split_system(text):
    start = text.find("<addendum>\n")
    end = text.find("\n</addendum>", start)
    if start < 0 or end < 0:
        return None
    start += len("<addendum>\n")
    return text[:start], text[start:end], text[end:]


def instructions_frame(body):
    """The instruction text with its values replaced; None when it does not have the known sentences."""
    match = INSTRUCTIONS.fullmatch(body)
    if not match:
        return None, None
    tests = [name for name, sentence in TESTS.items() if sentence == match["tests"]]
    required = match["required"].count("Required outcome (")
    lines = [
        "Complete the <KIND> task in /workspace. Investigate the source and run the relevant tests.",
        "Test command: <TEST COMMAND>.",
        match["tests"] if tests else "<UNKNOWN TEST SENTENCE>",
    ]
    lines += ["Required outcome (<ID>): <CASE TEXT>"] * required if required else [""]
    lines += [
        "Dependencies are prepared. The workspace is offline. Preserve existing behavior and do not weaken tests.",
        match["extra"] if match["extra"] in ("", BROWSER) else "<ANOTHER LINE>",
        "Allowed edit prefixes: <FOLDERS>.",
        "When finished, give a short summary. Your current patch is then checked in a fresh workspace.",
        "Model and tool calls are unlimited. Limits: %s generated tokens total, %s context tokens including up to "
        "%s response tokens." % (match["max"], match["window"], match["response"]),
        "History is never compacted. If a budget is exhausted, the current patch is graded.",
        "Task details: " + ("{}" if match["details"] == "{}" else "<CASE TEXT AS ONE JSON OBJECT>"),
        "",
    ]
    facts = {
        "kind": match["kind"],
        "tests_sentence": tests[0] if tests else "unknown",
        "required_outcome_lines": required,
        "line_after_dependencies": {"": "empty", BROWSER: "the browser sentence"}.get(match["extra"], "another"),
        "limits": "%s/%s/%s" % (match["max"], match["window"], match["response"]),
        "task_details_keys": ",".join(sorted(json.loads(match["details"]).keys())) or "none: {}",
    }
    return "\n".join(lines), facts


def tail_frame(tail):
    return GUIDE.sub(
        lambda m: m.group(1) + "<PATH OF THE GUIDE>" + m.group(2) + "<THE PROJECT'S OWN GUIDE FOR CODING AGENTS>"
        + m.group(3),
        tail,
    )


def arguments_frame(name, raw):
    """A tool call's arguments string with its values replaced: keys, their order and the JSON style stay."""
    try:
        value = json.loads(raw)
    except ValueError:
        return "<ARGUMENTS THAT ARE NOT JSON>", None
    if not isinstance(value, dict):
        return "<ARGUMENTS THAT ARE NOT AN OBJECT>", None

    def blank(key, item):
        if isinstance(item, str):
            return '"<%s>"' % {"command": "COMMAND", "path": "PATH"}.get(key, "TEXT")
        if isinstance(item, bool) or item is None:
            return json.dumps(item)
        if isinstance(item, (int, float)):
            return "<NUMBER>"
        if isinstance(item, list):
            if item and all(isinstance(entry, dict) for entry in item):
                keys = list(item[0].keys())
                one = "{" + ",".join('"%s":%s' % (k, blank(k, item[0][k])) for k in keys) + "}"
                return "[" + one + (",<%d MORE LIKE IT>" % (len(item) - 1) if len(item) > 1 else "") + "]"
            return "[<LIST>]"
        return "{<OBJECT>}"

    return "{" + ",".join('"%s":%s' % (key, blank(key, item)) for key, item in value.items()) + "}", value


def norm(line):
    return re.sub(r"\d+", "N", line)[:140]


# Pi's own text around a tool's output. Each is kept in a frame only where the whole result has that form.
EXIT = re.compile(r"(?s)(?P<output>.*?)\n\nCommand exited with code \d+")
MORE = re.compile(r"(?s)(?P<output>.*?)\n\n\[\d+ more lines in file\. Use offset=\d+ to continue\.\]")
NOTE = re.compile(r"\[[^\[\]\n]*\]")


def result_form(name, content, arguments):
    """The form of one tool result: Pi's fixed words stay, everything else becomes a placeholder."""
    path = arguments.get("path") if isinstance(arguments, dict) else None
    if name == "bash":
        if content == "(no output)":
            return "(no output)"
        match = EXIT.fullmatch(content)
        if match:
            inner = "(no output)" if match["output"] == "(no output)" else "<OUTPUT OF THE COMMAND>"
            return inner + "\n\nCommand exited with code <NUMBER>"
        return "<OUTPUT OF THE COMMAND>"
    if name == "read":
        if MORE.fullmatch(content):
            return "<FILE TEXT>\n\n[<NUMBER> more lines in file. Use offset=<NUMBER> to continue.]"
        last = content.rstrip("\n").split("\n")[-1]
        if NOTE.fullmatch(last) and "\n" in content:
            return "<FILE TEXT>\n" + re.sub(r"\d+", "<NUMBER>", last)
        if "\n" not in content and isinstance(path, str) and path and path in content:
            return re.sub(r"\d+", "<NUMBER>", content.replace(path, "<PATH>"))[:200]
        return "<FILE TEXT>"
    if name in ("edit", "write"):
        if "\n" not in content and isinstance(path, str) and path and path in content:
            return re.sub(r"\d+", "<NUMBER>", content.replace(path, "<PATH>"))[:200]
        return "<RESULT OF %s, NOT ONE LINE WITH THE PATH>" % name.upper()
    return "<RESULT OF A TOOL>"


def message_frame(message, ids, names):
    role = message["role"]
    out = {}
    for key, value in message.items():
        if key == "role":
            out[key] = value
        elif key == "tool_calls":
            calls = []
            for call in value:
                ids.setdefault(call["id"], "<CALL ID %d>" % (len(ids) + 1))
                frame, parsed = arguments_frame(call["function"]["name"], call["function"]["arguments"])
                names[call["id"]] = (call["function"]["name"], parsed)
                item = {}
                for k, v in call.items():
                    if k == "id":
                        item[k] = ids[v]
                    elif k == "function":
                        item[k] = {fk: (frame if fk == "arguments" else fv) for fk, fv in v.items()}
                    else:
                        item[k] = v
                calls.append(item)
            out[key] = calls
        elif key == "tool_call_id":
            out[key] = ids.get(value, "<CALL ID NOT SEEN>")
        elif key == "reasoning_content":
            out[key] = "<MODEL THINKING>" if value else value
        elif key == "content":
            if role == "tool":
                name, parsed = names.get(message.get("tool_call_id"), (None, None))
                out[key] = result_form(name, value, parsed) if isinstance(value, str) else "<TYPED CONTENT>"
            elif value is None or value == "":
                out[key] = value
            elif isinstance(value, str):
                out[key] = "<MODEL TEXT>" if role == "assistant" else "<TEXT>"
            else:
                out[key] = "<TYPED CONTENT>"
        else:
            out[key] = "<VALUE OF A KEY THIS SCRIPT DOES NOT KNOW>"
    return out


def request_frame(request):
    out = {}
    ids, names = {}, {}
    for key, value in request.items():
        if key == "messages":
            messages = []
            for index, message in enumerate(value):
                if index == 0 and message["role"] == "system":
                    before, body, after = split_system(message["content"])
                    frame, _ = instructions_frame(body)
                    text = before + (frame if frame is not None else "<INSTRUCTION TEXT>\n") + tail_frame(after)
                    messages.append({k: (text if k == "content" else v) for k, v in message.items()})
                elif index == 1 and message["role"] == "user":
                    parts = message["content"]
                    if isinstance(parts, list) and len(parts) == 1 and WRAPPER.fullmatch(parts[0].get("text", "")):
                        text = '<file name="/tmp/eab-ticket.md">\n<CASE TEXT, ENDING WITH A LINE BREAK>\n</file>\n'
                        part = {k: (text if k == "text" else v) for k, v in parts[0].items()}
                        messages.append({k: ([part] if k == "content" else v) for k, v in message.items()})
                    else:
                        messages.append({k: ("<CASE TEXT>" if k == "content" else v) for k, v in message.items()})
                else:
                    messages.append(message_frame(message, ids, names))
            out[key] = messages
        else:
            out[key] = value
    return out


def main():
    attempts = collections.defaultdict(dict)
    usage = collections.defaultdict(dict)
    with tarfile.open(fileobj=sys.stdin.buffer, mode="r|") as stream:
        for member in stream:
            if not member.isfile():
                continue
            attempt, _, name = member.name.rpartition("/")
            attempt = attempt.split("/")[-1]
            match = re.fullmatch(r"(request|usage)-(\d+)\.json", name)
            if not match:
                continue
            value = json.load(stream.extractfile(member))
            (attempts if match[1] == "request" else usage)[attempt][int(match[2])] = value

    count = collections.Counter
    report = {
        "attempts": len(attempts),
        "requests_read": sum(len(v) for v in attempts.values()),
        "top_level_keys": count(),
        "values": collections.defaultdict(count),
        "tools": count(),
        "system_before_instructions": count(),
        "system_after_instructions": count(),
        "instructions": collections.defaultdict(count),
        "first_user_message": count(),
        "role_pairs": count(),
        "assistant_keys": count(),
        "assistant_content": count(),
        "assistant_reasoning": count(),
        "tool_calls_per_assistant_message": count(),
        "tool_call": collections.defaultdict(count),
        "tool_call_arguments": count(),
        "tool_message_keys": count(),
        "tool_message_content": count(),
        "tool_results_follow_their_calls_in_order": count(),
        "tool_result_forms": count(),
        "grows_only": count(),
    }
    by_message = {}
    first_lines = collections.defaultdict(lambda: collections.defaultdict(set))
    last_lines = collections.defaultdict(lambda: collections.defaultdict(set))
    fixed = {"before": set(), "after": set(), "tools": set()}

    for attempt, requests in sorted(attempts.items()):
        steps = sorted(requests)
        for step in steps:
            request = requests[step]
            report["top_level_keys"][",".join(request.keys())] += 1
            for key, value in request.items():
                if key not in ("messages", "tools"):
                    report["values"][key][compact(value)] += 1
            tools = compact(request.get("tools"))
            report["tools"][sha(tools)] += 1
            fixed["tools"].add(tools)
        for earlier, later in zip(steps, steps[1:]):
            if later == earlier + 1:
                a, b = requests[earlier]["messages"], requests[later]["messages"]
                report["grows_only"]["yes" if b[: len(a)] == a and len(b) > len(a) else "no"] += 1

        first = requests[steps[0]]
        system = first["messages"][0]
        parts = split_system(system["content"]) if isinstance(system.get("content"), str) else None
        if system["role"] != "system" or parts is None:
            report["system_before_instructions"]["not the known shape"] += 1
        else:
            before, body, after = parts
            fixed["before"].add(before)
            report["system_before_instructions"]["%d characters, sha256 %s" % (len(before), sha(before))] += 1
            after_frame = tail_frame(after)
            if after_frame == after:
                fixed["after"].add(after)
            report["system_after_instructions"][
                "%d characters, sha256 %s%s"
                % (len(after_frame), sha(after_frame), "" if after_frame == after else " (with a project guide)")
            ] += 1
            _, facts = instructions_frame(body)
            if facts is None:
                report["instructions"]["known sentences"]["no"] += 1
                # To the terminal only, never to a file: where each line of the unknown text starts.
                print(attempt, [norm(line)[:24] for line in body.split("\n")], file=sys.stderr)
            else:
                report["instructions"]["known sentences"]["yes"] += 1
                for key, value in facts.items():
                    report["instructions"][key][str(value)] += 1
        user = first["messages"][1] if len(first["messages"]) > 1 else {}
        parts = user.get("content")
        if isinstance(parts, list) and len(parts) == 1 and isinstance(parts[0].get("text"), str):
            match = WRAPPER.fullmatch(parts[0]["text"])
            shape = "one text part, keys %s; " % ",".join(parts[0].keys())
            if match:
                shape += "file wrapper, the text inside ends with %s" % (
                    "a line break" if match["text"].endswith("\n") else "no line break"
                )
            else:
                shape += "no file wrapper"
            report["first_user_message"][shape] += 1
        else:
            report["first_user_message"]["another shape: %s" % type(parts).__name__] += 1

        last = requests[steps[-1]]["messages"]
        names, pending, parsed_arguments = {}, [], {}
        for previous, message in zip([None] + last, last):
            report["role_pairs"]["%s -> %s" % (previous["role"] if previous else "start", message["role"])] += 1
            if message["role"] == "assistant":
                report["assistant_keys"][",".join(message.keys())] += 1
                content = message.get("content")
                report["assistant_content"][
                    "null" if content is None else "empty text" if content == "" else type(content).__name__
                ] += 1
                thinking = message.get("reasoning_content")
                if "reasoning_content" not in message:
                    kind = "no key"
                elif not isinstance(thinking, str):
                    kind = type(thinking).__name__
                elif thinking == "":
                    kind = "empty text"
                else:
                    kind = "text; starts with a line break: %s; ends with a line break: %s; other space at an end: %s" % (
                        "yes" if thinking.startswith("\n") else "no",
                        "yes" if thinking.endswith("\n") else "no",
                        "yes" if thinking.strip("\n") != thinking.strip() else "no",
                    )
                report["assistant_reasoning"][kind] += 1
                calls = message.get("tool_calls") or []
                report["tool_calls_per_assistant_message"][str(len(calls))] += 1
                pending = [call["id"] for call in calls]
                shape = {
                    "tools": [call["function"]["name"] for call in calls],
                    "text": isinstance(content, str) and content != "",
                    "text_edges": None
                    if not isinstance(content, str) or content == ""
                    else [len(content) - len(content.lstrip()), len(content) - len(content.rstrip())],
                    "thinking_edges": None
                    if not isinstance(thinking, str)
                    else [len(thinking) - len(thinking.lstrip()), len(thinking) - len(thinking.rstrip())],
                    "values_that_are_not_text": [],
                    "forms": [
                        "%s %s" % (call["function"]["name"],
                                   arguments_frame(call["function"]["name"], call["function"]["arguments"])[0])
                        for call in calls
                    ],
                }
                by_message.setdefault(attempt, []).append(shape)
                for call in calls:
                    function = call["function"]
                    names[call["id"]] = function["name"]
                    try:
                        parsed_arguments[call["id"]] = json.loads(function["arguments"])
                    except ValueError:
                        parsed_arguments[call["id"]] = None
                    if isinstance(parsed_arguments[call["id"]], dict):
                        shape["values_that_are_not_text"] += [
                            "%s.%s:%s" % (function["name"], key, type(item).__name__)
                            for key, item in parsed_arguments[call["id"]].items()
                            if not isinstance(item, str)
                        ]
                    report["tool_call"]["keys"][",".join(call.keys()) + " / " + ",".join(function.keys())] += 1
                    report["tool_call"]["type"][str(call.get("type"))] += 1
                    report["tool_call"]["name"][function["name"]] += 1
                    report["tool_call"]["id"][
                        "32 letters and digits" if CALL_ID.fullmatch(call["id"]) else "another form"
                    ] += 1
                    frame, value = arguments_frame(function["name"], function["arguments"])
                    report["tool_call_arguments"]["%s %s" % (function["name"], frame)] += 1
                    if value is not None:
                        same = compact(value) == function["arguments"]
                        report["tool_call"]["arguments are compact JSON, as JSON.stringify writes it"][
                            "yes" if same else "no"
                        ] += 1
            elif message["role"] == "tool":
                report["tool_message_keys"][",".join(message.keys())] += 1
                content = message.get("content")
                name = names.get(message.get("tool_call_id"), "unknown")
                order = bool(pending) and pending.pop(0) == message.get("tool_call_id")
                report["tool_results_follow_their_calls_in_order"]["yes" if order else "no"] += 1
                if not isinstance(content, str):
                    report["tool_message_content"]["%s: %s" % (name, type(content).__name__)] += 1
                    continue
                report["tool_message_content"][
                    "%s: text, %s" % (name, "empty" if content == "" else "ends with a line break"
                                      if content.endswith("\n") else "no line break at the end")
                ] += 1
                form = result_form(name, content, parsed_arguments.get(message.get("tool_call_id")))
                report["tool_result_forms"]["%s: %s" % (name, form.replace("\n", "\\n"))] += 1
                lines = content.split("\n")
                while len(lines) > 1 and lines[-1] == "":
                    lines.pop()
                first_lines[name][norm(lines[0])].add(attempt)
                last_lines[name][norm(lines[-1])].add(attempt)

    def common(table):
        return {
            name: [
                "%s  (%d attempts)" % (line, len(seen))
                for line, seen in sorted(lines.items(), key=lambda item: -len(item[1]))
                if len(seen) >= MIN_ATTEMPTS
            ][:12]
            for name, lines in table.items()
        }

    # To the terminal only, never to a file: lines of tool output that many attempts share. They are how Pi's own
    # words around an output were found (the forms in result_form); the lines themselves are content.
    print(json.dumps({"first lines": common(first_lines), "last lines": common(last_lines)}, indent=1),
          file=sys.stderr)

    os.makedirs(OUT, exist_ok=True)
    for name, key, file in (
        ("before", "system_before_instructions", "pi_system_text_before_instructions.txt"),
        ("after", "system_after_instructions", "pi_system_text_after_instructions.txt"),
        ("tools", "tools", "pi_tools_openai.json"),
    ):
        if len(fixed[name]) == 1 and (name == "after" or len(report[key]) == 1):
            with open(os.path.join(OUT, file), "w", encoding="utf-8", newline="") as handle:
                handle.write(next(iter(fixed[name])))

    # The shape of every reply (tools called, argument names, whether it held text): cache_reuse.py reads it.
    with open(os.path.join(OUT, "calls_by_message.json"), "w", encoding="utf-8") as handle:
        json.dump(by_message, handle)

    if FRAME_ATTEMPT in attempts:
        requests = attempts[FRAME_ATTEMPT]
        for step, file in ((min(requests), "first_request.frame.json"), (FRAME_STEP, "middle_request.frame.json")):
            if step in requests:
                with open(os.path.join(OUT, file), "w", encoding="utf-8") as handle:
                    json.dump(request_frame(requests[step]), handle, indent=2, ensure_ascii=False)
                    handle.write("\n")
                report.setdefault("frames", {})[file] = {
                    "request": step,
                    "prompt_tokens": usage.get(FRAME_ATTEMPT, {}).get(step, {}).get("input_tokens"),
                    "messages": len(requests[step]["messages"]),
                }
    with open(os.path.join(OUT, "report_openai.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False, sort_keys=False)
        handle.write("\n")
    json.dump(report, sys.stdout, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
