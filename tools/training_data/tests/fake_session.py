"""Write a made-up session into a folder, in the engine's own files and shapes.

Nothing here is a real session: the tests give every description, thought, command and output. The only real text is
the fixed text the target-text folder records (the agent's system text and its four tool definitions), which every
session shares.

A session is described by a dict:

    {"case": "shop-pr-1", "run": "20260101-000000-0000beef",
     "instructions": "...\n", "description": "...\n",
     "turns": [
        {"thinking": "..." or None, "text": "..." or None,
         "calls": [{"name": "bash", "raw": '{"command":"ls"}'}],     # raw: the JSON text as the model wrote it
         "results": [{"content": "...", "is_error": False}],
         "stop": "tool_use"},
        {"thinking": "...", "text": "Done.", "stop": "end_turn"}],
     "reply_to_last_request": True,       # False: the last request has no reply file
     "stop_reason": "agent_completed", "passed": True}

A call may carry "agent_reading": the object the agent made of a cut-off call (raw is then not valid JSON).
"""
import json
import os


def _dump(value, ascii_only=False):
    # the engine writes every object's keys in alphabetical order
    return json.dumps(value, sort_keys=True, ensure_ascii=ascii_only, indent=2)


def _chunks(text, size=7):
    return [text[index:index + size] for index in range(0, len(text), size)] or [""]


def _stream(turn, ids):
    events, index = [], 0

    def add(event):
        events.append("event: %s\ndata: %s\n" % (event["type"], json.dumps(event, ensure_ascii=False)))

    add({"type": "message_start", "message": {"id": "msg_made_up", "type": "message", "role": "assistant",
                                               "model": "made-up-teacher", "content": [], "stop_reason": None,
                                               "stop_sequence": None,
                                               "usage": {"input_tokens": 1, "output_tokens": 0}}})
    if turn.get("thinking") is not None:
        add({"type": "content_block_start", "index": index,
             "content_block": {"type": "thinking", "thinking": "", "signature": ""}})
        for piece in _chunks(turn["thinking"]):
            add({"type": "content_block_delta", "index": index, "delta": {"type": "thinking_delta", "thinking": piece}})
        add({"type": "content_block_stop", "index": index})
        index += 1
    if turn.get("text") is not None:
        add({"type": "content_block_start", "index": index, "content_block": {"type": "text", "text": ""}})
        for piece in _chunks(turn["text"]):
            add({"type": "content_block_delta", "index": index, "delta": {"type": "text_delta", "text": piece}})
        add({"type": "content_block_stop", "index": index})
        index += 1
    for call, call_id in zip(turn.get("calls") or [], ids):
        add({"type": "content_block_start", "index": index,
             "content_block": {"type": "tool_use", "id": call_id, "name": call["name"], "input": {}}})
        for piece in _chunks(call["raw"], 11):
            add({"type": "content_block_delta", "index": index,
                 "delta": {"type": "input_json_delta", "partial_json": piece}})
        add({"type": "content_block_stop", "index": index})
        index += 1
    add({"type": "message_delta", "delta": {"stop_reason": turn.get("stop", "tool_use"), "stop_sequence": None},
         "usage": {"input_tokens": 1, "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0,
                   "output_tokens": 1}})
    add({"type": "message_stop"})
    return "\n".join(events) + "\n"


def _call_value(call):
    if "agent_reading" in call:
        return call["agent_reading"]
    return json.loads(call["raw"])


def _sorted(value):
    """A value with every object's keys in alphabetical order, as the stored requests hold a call's input."""
    return json.loads(json.dumps(value, sort_keys=True))


def write_session(root, fixed_folder, spec):
    """Writes <root>/<run>/<case>/… and <root>/<run>/run.json. Returns the attempt's folder."""
    case, run = spec.get("case", "shop-pr-1"), spec.get("run", "20260101-000000-0000beef")
    folder = os.path.join(root, run, case)
    os.makedirs(folder)

    def fixed_text(name):
        with open(os.path.join(fixed_folder, "fixed", name), encoding="utf-8", newline="") as handle:
            return handle.read()

    before = fixed_text("pi_system_text_before_instructions.txt")
    after = spec.get("system_tail", fixed_text("pi_system_text_after_instructions.txt"))
    tools = json.loads(fixed_text("pi_tools_openai.json"))
    instructions = spec.get("instructions", "Complete the made-up task.\nTask details: {}\n")
    system_text = spec.get("system_text", before + instructions + after)
    description = spec.get("description", "The cart total ignores the discount code.\n")
    first_text = '<file name="/tmp/eab-ticket.md">\n' + description + "\n</file>\n"
    request_tools = spec.get("tools", [
        {"description": tool["function"]["description"], "input_schema": tool["function"]["parameters"],
         "name": tool["function"]["name"]} for tool in tools
    ])

    messages = [{"role": "user", "content": [{"type": "text", "text": first_text}]}]
    # the agent's log holds the system text as sections, with an empty line between two of them in the text
    cut = system_text.find("\n\n")
    sections = {"preamble": system_text[:cut], "rest": system_text[cut + 2:]} if cut > 0 else {"all": system_text}
    agent_log = [
        {"role": "system", "content": "", "sections": sections, "timestamp": 1},
        {"role": "user", "content": [{"type": "text", "text": first_text}], "timestamp": 2},
    ]
    turns = spec["turns"]
    counter = 0
    for number, turn in enumerate(turns):
        last = number == len(turns) - 1
        ids = []
        for _ in turn.get("calls") or []:
            counter += 1
            ids.append("call_%024x" % counter)

        # the request that asks for this turn's reply: everything so far, cache marks on the system text and on the
        # last block
        marked = json.loads(json.dumps(messages))
        marked[-1]["content"][-1]["cache_control"] = {"type": "ephemeral"}
        request = {
            "max_tokens": 8192, "messages": marked, "model": "made-up-teacher", "seed": 101, "stream": True,
            "system": [{"cache_control": {"type": "ephemeral"}, "text": system_text, "type": "text"}],
            "tools": request_tools,
        }
        with open(os.path.join(folder, "request-%04d.json" % number), "w", encoding="utf-8") as handle:
            handle.write(_dump(request, spec.get("ascii_json", False)))
        if not (last and not spec.get("reply_to_last_request", True)):
            with open(os.path.join(folder, "response-%04d.sse" % number), "w", encoding="utf-8", newline="") as handle:
                handle.write(_stream(turn, ids))
            with open(os.path.join(folder, "usage-%04d.json" % number), "w", encoding="utf-8") as handle:
                handle.write(_dump({"input_tokens": 1, "output_tokens": 1}))
        else:
            continue

        blocks, log_blocks = [], []
        if turn.get("thinking") is not None:
            blocks.append({"type": "thinking", "thinking": turn["thinking"], "signature": ""})
            log_blocks.append({"type": "thinking", "thinking": turn["thinking"], "thinkingSignature": ""})
        if turn.get("text") is not None:
            blocks.append({"type": "text", "text": turn["text"]})
            log_blocks.append({"type": "text", "text": turn["text"]})
        for call, call_id in zip(turn.get("calls") or [], ids):
            value = _sorted(_call_value(call))
            blocks.append({"type": "tool_use", "id": call_id, "name": call["name"], "input": value})
            log_blocks.append({"type": "toolCall", "id": call_id, "name": call["name"], "arguments": value})
        messages.append({"role": "assistant", "content": blocks})
        stop = {"tool_use": "toolUse", "end_turn": "stop", "max_tokens": "length"}[turn.get("stop", "tool_use")]
        agent_log.append({"role": "assistant", "content": log_blocks, "stopReason": stop, "timestamp": 3})
        results = turn.get("results") or []
        if results:
            messages.append({"role": "user", "content": [
                {"type": "tool_result", "tool_use_id": call_id, "content": result["content"],
                 "is_error": bool(result.get("is_error"))} for result, call_id in zip(results, ids)
            ]})
            for result, call_id, call in zip(results, ids, turn["calls"]):
                agent_log.append({"role": "toolResult", "toolCallId": call_id, "toolName": call["name"],
                                  "content": [{"type": "text", "text": result["content"]}],
                                  "isError": bool(result.get("is_error")), "timestamp": 4})
    if spec.get("agent_error_at_the_end"):
        agent_log.append({"role": "assistant", "content": [], "stopReason": "error",
                          "errorMessage": "made-up budget message", "timestamp": 5})

    with open(os.path.join(folder, "pi-events.jsonl"), "w", encoding="utf-8") as handle:
        handle.write(json.dumps({"type": "agent_start"}, sort_keys=True) + "\n")
        handle.write(json.dumps({"type": "agent_end", "messages": agent_log, "willRetry": False},
                                sort_keys=True, ensure_ascii=spec.get("ascii_json", False)) + "\n")
    with open(os.path.join(folder, "attempt.json"), "w", encoding="utf-8") as handle:
        handle.write(_dump({
            "agent": {"lock_sha256": "0" * 64, "package": "made-up-agent", "version": "0.0.0"},
            "case": case, "status": "completed", "stop_reason": spec.get("stop_reason", "agent_completed"),
            "grade": {"passed": spec.get("passed", True)},
        }))
    with open(os.path.join(folder, "instructions.md"), "w", encoding="utf-8", newline="") as handle:
        handle.write(instructions)
    with open(os.path.join(folder, "prompt.md"), "w", encoding="utf-8", newline="") as handle:
        handle.write(description)
    with open(os.path.join(root, run, "run.json"), "w", encoding="utf-8") as handle:
        handle.write(_dump({"id": run, "status": "completed"}))
    return folder
