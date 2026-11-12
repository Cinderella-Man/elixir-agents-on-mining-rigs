#!/usr/bin/env python3
"""Write a request frame as a chat template writes it, with Python's Jinja2 (E103).

This is NOT the server's own rendering. It follows what was read in the server's source for the build the bench
used: the template is applied directly; a tool call's `arguments` text is parsed into an object first; `tojson`
writes `, ` and `: ` separators, keeps the keys' order and leaves non-ASCII text as it is. Jinja2 runs with the
settings the Transformers library uses (trim_blocks and lstrip_blocks). The server's `/apply-template` settles the
real bytes.

    python3 -I render_frame.py <template.jinja> <frame.json> > prompt.txt
    python3 -I render_frame.py --same <frame.json> <template.jinja> <template.jinja> ...   # do they write the same text?
"""
import hashlib
import json
import re
import sys

from jinja2.sandbox import ImmutableSandboxedEnvironment


def raise_exception(message):
    raise ValueError(message)


def tojson(value, ensure_ascii=False, indent=None, separators=None, sort_keys=False):
    return json.dumps(value, ensure_ascii=ensure_ascii, indent=indent,
                      separators=tuple(separators) if separators else (", ", ": "), sort_keys=sort_keys)


def load(path):
    with open(path, encoding="utf-8", newline="") as handle:
        source = handle.read()
    # The maker's newer file marks the model's own text for training with two tags that write nothing.
    return re.sub(r"\{%-?\s*(?:end)?generation\s*-?%\}", "", source)


def render(template_path, frame):
    environment = ImmutableSandboxedEnvironment(trim_blocks=True, lstrip_blocks=True)
    environment.filters["tojson"] = tojson
    environment.globals["raise_exception"] = raise_exception
    messages = []
    system = frame.get("system")
    if system is not None:  # an Anthropic-style frame carries the system text beside the messages
        raise ValueError("this script renders OpenAI-style frames only")
    for message in frame["messages"]:
        message = dict(message)
        if message.get("tool_calls"):
            calls = []
            for call in message["tool_calls"]:
                function = dict(call["function"])
                if isinstance(function.get("arguments"), str):
                    function["arguments"] = json.loads(function["arguments"])
                calls.append({**call, "function": function})
            message["tool_calls"] = calls
        messages.append(message)
    return environment.from_string(load(template_path)).render(
        messages=messages, tools=frame.get("tools"), add_generation_prompt=True
    )


def main():
    arguments = sys.argv[1:]
    if arguments and arguments[0] == "--same":
        with open(arguments[1], encoding="utf-8") as handle:
            frame = json.load(handle)
        texts = [render(path, frame) for path in arguments[2:]]
        for path, text in zip(arguments[2:], texts):
            print("%s  %d characters  sha256 %s" % (path.split("/")[-1], len(text), hashlib.sha256(text.encode()).hexdigest()))
        print("the same text" if len(set(texts)) == 1 else "DIFFERENT text")
        return
    with open(arguments[1], encoding="utf-8") as handle:
        frame = json.load(handle)
    sys.stdout.write(render(arguments[0], frame))


if __name__ == "__main__":
    main()
