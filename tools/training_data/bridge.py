"""From a stored teacher session to the messages the bench's server would have received.

The teacher's sessions are recorded on the agent's Anthropic-style route; the student is tested on the OpenAI-style
route. This module moves every piece of a session from the first form to the second, as
docs/data/2026-11-12_target_text_qwen38_27b/README.md, section 5, lists it. It writes no text of its own: every
string in its output is a string of the stored session or of the fixed text that folder records.
"""
import glob
import hashlib
import json
import os
import re


class ConversionError(Exception):
    """A session that cannot be converted. Carries hashes, lengths and counts, never the session's text."""

    def __init__(self, code, message, facts=None):
        super().__init__("%s: %s%s" % (code, message, " " + json.dumps(facts, sort_keys=True) if facts else ""))
        self.code = code
        self.facts = facts or {}


def sha_bytes(data):
    return hashlib.sha256(data).hexdigest()


def sha_text(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def fact(text):
    """What may be said about a text in an error: its length and its hash."""
    return {"characters": len(text), "sha256": sha_text(text)}


def compact(value):
    """JSON without spaces and with the keys in their own order: what the agent's JSON.stringify writes."""
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


# ---------------------------------------------------------------------------------------------------------------
# The fixed text the target-text folder records
# ---------------------------------------------------------------------------------------------------------------

class Fixed:
    """The template, the tool definitions and the agent's fixed system text, each read from its recorded file."""

    def __init__(self, template_path, tools_path, system_before_path):
        with open(template_path, "rb") as handle:
            raw = handle.read()
        self.template = raw.decode("utf-8")
        self.template_sha256 = sha_bytes(raw)
        self.template_bytes = len(raw)
        self.template_name = os.path.basename(template_path)
        with open(tools_path, "rb") as handle:
            raw = handle.read()
        self.tools = json.loads(raw.decode("utf-8"))
        self.tools_sha256 = sha_bytes(raw)
        self.tools_name = os.path.basename(tools_path)
        with open(system_before_path, "rb") as handle:
            raw = handle.read()
        self.system_before = raw.decode("utf-8")
        self.system_before_sha256 = sha_bytes(raw)
        self.system_before_name = os.path.basename(system_before_path)


def default_fixed_paths(environ=None):
    """The recorded files: from the environment (TEMPLATE, TOOLS, SYSTEM_BEFORE), else from this repository."""
    environ = os.environ if environ is None else environ
    here = os.path.dirname(os.path.abspath(__file__))
    folder = environ.get("TARGET_TEXT") or os.path.join(
        here, "..", "..", "docs", "data", "2026-11-12_target_text_qwen38_27b"
    )
    return (
        environ.get("TEMPLATE") or os.path.join(folder, "templates", "bench_gguf_chat_template.jinja"),
        environ.get("TOOLS") or os.path.join(folder, "fixed", "pi_tools_openai.json"),
        environ.get("SYSTEM_BEFORE") or os.path.join(folder, "fixed", "pi_system_text_before_instructions.txt"),
    )


# ---------------------------------------------------------------------------------------------------------------
# Reading a stored attempt
# ---------------------------------------------------------------------------------------------------------------

NUMBERED = re.compile(r"-(\d+)\.[a-z]+$")


def read_stream(data):
    """One recorded reply stream: the blocks the model wrote and why it stopped."""
    blocks, stop, unknown = {}, None, 0
    for line in data.decode("utf-8").split("\n"):
        line = line.rstrip("\r")
        if not line.startswith("data:"):
            continue
        payload = line[5:].strip()
        if payload == "[DONE]":
            continue
        try:
            event = json.loads(payload)
        except ValueError:
            unknown += 1
            continue
        kind = event.get("type")
        if kind == "content_block_start":
            start = event.get("content_block") or {}
            block = {"type": start.get("type")}
            if block["type"] == "thinking":
                block["thinking"] = start.get("thinking") or ""
                block["signature"] = start.get("signature") or ""
            elif block["type"] == "text":
                block["text"] = start.get("text") or ""
            elif block["type"] == "tool_use":
                block["id"] = start.get("id")
                block["name"] = start.get("name")
                block["raw"] = ""
            blocks[event.get("index")] = block
        elif kind == "content_block_delta":
            block = blocks.get(event.get("index"))
            delta = event.get("delta") or {}
            if block is None:
                unknown += 1
            elif delta.get("type") == "thinking_delta" and block["type"] == "thinking":
                block["thinking"] += delta.get("thinking") or ""
            elif delta.get("type") == "signature_delta" and block["type"] == "thinking":
                block["signature"] += delta.get("signature") or ""
            elif delta.get("type") == "text_delta" and block["type"] == "text":
                block["text"] += delta.get("text") or ""
            elif delta.get("type") == "input_json_delta" and block["type"] == "tool_use":
                block["raw"] += delta.get("partial_json") or ""
            else:
                unknown += 1
        elif kind == "message_delta":
            stop = (event.get("delta") or {}).get("stop_reason", stop)
        elif kind not in ("message_start", "content_block_stop", "message_stop", "ping"):
            unknown += 1
    return {"blocks": [blocks[index] for index in sorted(blocks)], "stop_reason": stop, "unknown_events": unknown}


class Attempt:
    """One stored attempt, read and never changed: the files this converter needs, each with its hash."""

    def __init__(self, folder):
        self.folder = os.path.abspath(folder)
        self.run_folder = os.path.dirname(self.folder)
        self.case = os.path.basename(self.folder)
        self.inputs = []

        requests = self._numbered("request-*.json")
        if not requests:
            raise ConversionError("no_request", "the attempt folder holds no request file")
        self.request_index = max(requests)
        self.request = json.loads(self._read(requests[self.request_index]).decode("utf-8"))

        self.replies = {}
        for index, path in sorted(self._numbered("response-*.sse").items()):
            self.replies[index] = read_stream(self._read(path))

        self.pi_messages = None
        path = os.path.join(self.folder, "pi-events.jsonl")
        if os.path.exists(path):
            for line in self._read(path).decode("utf-8").split("\n"):
                if '"agent_end"' not in line:
                    continue
                event = json.loads(line)
                if event.get("type") == "agent_end":
                    self.pi_messages = event.get("messages")

        self.record = self._json(os.path.join(self.folder, "attempt.json"))
        self.instructions = self._text(os.path.join(self.folder, "instructions.md"))
        self.prompt = self._text(os.path.join(self.folder, "prompt.md"))
        run = self._json(os.path.join(self.run_folder, "run.json"))
        self.run_id = (run or {}).get("id")

    def _numbered(self, pattern):
        found = {}
        for path in glob.glob(os.path.join(self.folder, pattern)):
            match = NUMBERED.search(path)
            if match:
                found[int(match[1])] = path
        return found

    def _read(self, path):
        with open(path, "rb") as handle:
            data = handle.read()
        self.inputs.append(
            {"path": os.path.relpath(path, self.run_folder), "bytes": len(data), "sha256": sha_bytes(data)}
        )
        return data

    def _json(self, path):
        return json.loads(self._read(path).decode("utf-8")) if os.path.exists(path) else None

    def _text(self, path):
        return self._read(path).decode("utf-8") if os.path.exists(path) else None


# ---------------------------------------------------------------------------------------------------------------
# The bridge
# ---------------------------------------------------------------------------------------------------------------

def one_key_everywhere(value):
    """True when no object inside the value has two keys: then the order of its keys cannot be wrong."""
    if isinstance(value, dict):
        return len(value) <= 1 and all(one_key_everywhere(item) for item in value.values())
    if isinstance(value, list):
        return all(one_key_everywhere(item) for item in value)
    return True


def as_the_agent_writes_numbers(value, counter):
    """A number with a fraction of zero becomes an integer, as JSON.stringify writes it (120.0 -> 120)."""
    if isinstance(value, dict):
        return {key: as_the_agent_writes_numbers(item, counter) for key, item in value.items()}
    if isinstance(value, list):
        return [as_the_agent_writes_numbers(item, counter) for item in value]
    if isinstance(value, float) and value.is_integer() and abs(value) < 1e21:
        counter["numbers_rewritten"] = counter.get("numbers_rewritten", 0) + 1
        return int(value)
    return value


class Bridge:
    """Builds the bench-route messages of one conversation, and keeps the counts the record reports."""

    def __init__(self, fixed, switches):
        self.fixed = fixed
        self.switches = switches
        self.messages = []
        self.turns = []  # one entry per assistant message
        self.counts = {}
        self.pending = []  # call ids waiting for their results, in order

    def count(self, name, by=1):
        self.counts[name] = self.counts.get(name, 0) + by

    # -- the parts of a request --------------------------------------------------------------------------------

    def tools(self, tools):
        """Difference 4: the tool definitions, re-shaped; the bench's bytes come from the recorded file."""
        reshaped = []
        for tool in tools or []:
            if sorted(tool.keys()) != ["description", "input_schema", "name"]:
                raise ConversionError("tool_shape", "a tool definition has other keys than the recorded ones",
                                      {"keys": sorted(tool.keys())})
            reshaped.append({"function": {"description": tool["description"], "name": tool["name"],
                                          "parameters": tool["input_schema"]}, "type": "function"})
        if reshaped != self.fixed.tools:
            raise ConversionError(
                "tools_differ", "the session's tool definitions are not the recorded ones",
                {"session": fact(json.dumps(reshaped, sort_keys=True, ensure_ascii=False, separators=(",", ":"))),
                 "recorded": fact(json.dumps(self.fixed.tools, sort_keys=True, ensure_ascii=False,
                                             separators=(",", ":")))},
            )
        return self.fixed.tools

    def system(self, system):
        """Differences 1 and 2: the system text moves into the first message; its cache mark is dropped."""
        if isinstance(system, str):
            text = system
        elif isinstance(system, list) and len(system) == 1 and isinstance(system[0].get("text"), str):
            if system[0].get("type") != "text":
                raise ConversionError("system_shape", "the system part is not a text part")
            text = system[0]["text"]
        else:
            raise ConversionError("system_shape", "the system text is not one text part")
        before = self.fixed.system_before
        if not text.startswith(before):
            raise ConversionError(
                "system_text_differs", "the system text does not start with the agent's recorded fixed text",
                {"session_start": fact(text[: len(before)]), "recorded": fact(before)},
            )
        self.messages.append({"content": text, "role": "system"})

    def message(self, message, reply=None):
        role, content = message.get("role"), message.get("content")
        if role == "assistant":
            self.assistant(content, reply, source="request")
        elif role == "user":
            self.user(content)
        else:
            raise ConversionError("message_role", "a message has a role this converter does not know",
                                  {"role": str(role)})

    def user(self, content):
        """Differences 3, 11 and 12: the description keeps its one text part; each tool result becomes a message
        of its own; cache marks and error marks are dropped."""
        if isinstance(content, str):
            self.messages.append({"content": [{"text": content, "type": "text"}], "role": "user"})
            return
        kinds = {block.get("type") for block in content}
        if kinds == {"text"}:
            parts = []
            for block in content:
                if not isinstance(block.get("text"), str):
                    raise ConversionError("user_shape", "a text part holds no text")
                parts.append({"text": block["text"], "type": "text"})
            self.messages.append({"content": parts, "role": "user"})
        elif kinds == {"tool_result"}:
            for block in content:
                if not isinstance(block.get("content"), str):
                    raise ConversionError("tool_result_shape", "a tool result is not one text")
                expected = self.pending.pop(0) if self.pending else None
                if expected != block.get("tool_use_id"):
                    self.count("tool_results_out_of_order")
                if block.get("is_error"):
                    self.count("tool_results_marked_error")
                self.count("tool_results")
                self.messages.append(
                    {"content": block["content"], "role": "tool", "tool_call_id": block.get("tool_use_id")}
                )
        else:
            raise ConversionError("user_shape", "a user message mixes kinds of parts this converter does not know",
                                  {"kinds": sorted(str(kind) for kind in kinds)})

    def assistant(self, blocks, reply, source, pi_message=None):
        """Differences 5 to 10: thinking, answer text and calls move into one message of the bench's shape."""
        if not isinstance(blocks, list):
            raise ConversionError("assistant_shape", "an assistant message is not a list of blocks")
        order = [block.get("type") for block in blocks]
        rank = {"thinking": 0, "text": 1, "tool_use": 2}
        if any(kind not in rank for kind in order):
            raise ConversionError("assistant_shape", "an assistant message holds a block this converter does not know",
                                  {"blocks": [str(kind) for kind in order]})
        if [rank[kind] for kind in order] != sorted(rank[kind] for kind in order) or order.count("thinking") > 1 \
                or order.count("text") > 1:
            raise ConversionError("assistant_shape", "an assistant message's blocks are not thinking, text, calls",
                                  {"blocks": order})

        thinking = next((block for block in blocks if block["type"] == "thinking"), None)
        text = next((block for block in blocks if block["type"] == "text"), None)
        calls = [block for block in blocks if block["type"] == "tool_use"]
        reply_calls = [block for block in (reply or {}).get("blocks", []) if block["type"] == "tool_use"]
        pi_calls = [block for block in (pi_message or {}).get("content", []) if block.get("type") == "toolCall"]

        out = {"content": text["text"] if text is not None else None, "role": "assistant"}
        if thinking is not None:
            if thinking.get("signature"):
                self.count("signatures_dropped")
            out["reasoning_content"] = thinking.get("thinking") or ""
        elif self.switches["no_thinking_field"] == "empty":
            out["reasoning_content"] = ""
        elif self.switches["no_thinking_field"] == "null":
            out["reasoning_content"] = None

        orders = []
        if calls:
            out["tool_calls"] = []
            for index, call in enumerate(calls):
                written = reply_calls[index] if index < len(reply_calls) else None
                noted = pi_calls[index] if index < len(pi_calls) else None
                value, how = self.call_input(call, written, noted, source)
                orders.append(how)
                self.count("param_order_" + how)
                self.count("tool_calls")
                self.count("calls_" + str(call.get("name")))
                out["tool_calls"].append(
                    {"function": {"arguments": compact(value), "name": call.get("name")},
                     "id": call.get("id"), "type": "function"}
                )
                self.pending.append(call.get("id"))
        elif self.switches["final_tool_calls_field"] == "empty":
            out["tool_calls"] = []

        self.turns.append({
            "turn": len(self.turns),
            "message": len(self.messages),
            "source": source,
            "stop_reason": (reply or {}).get("stop_reason"),
            "thinking_block": thinking is not None,
            "calls": len(calls),
            "param_order": orders,
        })
        self.messages.append(out)

    def call_input(self, call, written, noted, source):
        """Difference 9: the order of a call's parameters is the teacher's own, read from the reply stream."""
        stored = call.get("input") if source == "request" else None
        parsed = None
        if written is not None:
            raw = written.get("raw") or ""
            try:
                parsed = json.loads(raw) if raw.strip() else {}
            except ValueError:
                parsed = None
        if source == "reply":
            # the last reply is in no request: the stream is the only record of it
            if isinstance(parsed, dict):
                value, how = parsed, "stream"
            elif noted is not None and isinstance(noted.get("arguments"), dict):
                value, how = noted["arguments"], "agent_log_cut_call"  # the agent's own reading of a cut-off call
            else:
                raise ConversionError("cut_call_without_value",
                                      "the last reply's call is cut off and the agent's log does not hold it")
        else:
            if not isinstance(stored, dict):
                raise ConversionError("call_shape", "a call's input is not an object")
            if self.switches["param_order"] == "sorted":
                value, how = stored, "sorted"
            elif isinstance(parsed, dict) and parsed == stored:
                value, how = parsed, "stream"
            elif one_key_everywhere(stored):
                value, how = stored, "request_one_key"
            else:
                value, how = stored, "request_sorted"
        if self.switches["integral_floats"] == "as_integers":
            value = as_the_agent_writes_numbers(value, self.counts)
        return value, how


def match_replies(messages, replies):
    """Which reply stream wrote which assistant message of the request: matched by the calls' ids."""
    by_ids = {}
    for index, reply in replies.items():
        ids = tuple(block.get("id") for block in reply["blocks"] if block["type"] == "tool_use")
        if ids:
            by_ids.setdefault(ids, index)
    matched = []
    for message in messages:
        if message.get("role") != "assistant" or not isinstance(message.get("content"), list):
            matched.append(None)
            continue
        ids = tuple(block.get("id") for block in message["content"] if block.get("type") == "tool_use")
        matched.append(by_ids.get(ids))
    return matched


def bridge_request(request, fixed, switches, replies=None):
    """One stored request as the bench's server would have received the same conversation."""
    bridge = Bridge(fixed, switches)
    tools = bridge.tools(request.get("tools"))
    bridge.system(request.get("system"))
    messages = request.get("messages") or []
    matched = match_replies(messages, replies or {})
    for message, index in zip(messages, matched):
        reply = (replies or {}).get(index) if index is not None else None
        if message.get("role") == "assistant" and replies is not None:
            if reply is None:
                bridge.count("replies_not_matched")
            else:
                compare_reply(bridge, message["content"], reply)
        bridge.message(message, reply)
    return bridge, tools


def compare_reply(bridge, blocks, reply):
    """A stored request's assistant message against the reply stream that wrote it: counts of differences."""
    def texts(source, kind, key):
        return [block.get(key) or "" for block in source if block.get("type") == kind]

    if texts(blocks, "thinking", "thinking") != texts(reply["blocks"], "thinking", "thinking"):
        bridge.count("stream_thinking_differs")
    if texts(blocks, "text", "text") != texts(reply["blocks"], "text", "text"):
        bridge.count("stream_text_differs")
    ours = [(block.get("id"), block.get("name")) for block in blocks if block.get("type") == "tool_use"]
    theirs = [(block.get("id"), block.get("name")) for block in reply["blocks"] if block["type"] == "tool_use"]
    if ours != theirs:
        bridge.count("stream_calls_differ")
    if reply.get("unknown_events"):
        bridge.count("stream_unknown_events", reply["unknown_events"])


def bridge_attempt(attempt, fixed, switches):
    """A whole stored attempt: the last request's conversation, then the last reply, which is in no request."""
    bridge, tools = bridge_request(attempt.request, fixed, switches, attempt.replies)
    pi_assistants = [
        message for message in (attempt.pi_messages or []) if message.get("role") == "assistant"
    ]
    last = attempt.replies.get(attempt.request_index)
    if last is None or (not last["blocks"] and last["stop_reason"] is None):
        bridge.count("no_last_reply")
    else:
        if last.get("unknown_events"):
            bridge.count("stream_unknown_events", last["unknown_events"])
        position = len(bridge.turns)
        noted = pi_assistants[position] if position < len(pi_assistants) else None
        blocks = []
        for block in last["blocks"]:
            if block["type"] == "tool_use":
                blocks.append({"type": "tool_use", "id": block.get("id"), "name": block.get("name")})
            else:
                blocks.append(block)
        bridge.assistant(blocks, last, source="reply", pi_message=noted)
    if attempt.pi_messages is not None:
        compare_agent_log(bridge, attempt.pi_messages)
    return bridge, tools


def compare_agent_log(bridge, pi_messages):
    """The conversation against the agent's own log of it (its closing list of messages): counts of differences."""
    def joined(message, kind, key):
        return "".join(block.get(key) or "" for block in message.get("content") or [] if block.get("type") == kind)

    ours = bridge.messages
    system = next((m for m in pi_messages if m.get("role") == "system"), None)
    if system is not None:
        text, sections = ours[0]["content"], system.get("sections")
        if system.get("content"):
            same = system["content"] == text
        elif isinstance(sections, dict) and sections:
            # the log holds the system text as its sections, stored without their order: every section must be
            # in the text, and together with one empty line between two of them they must fill it
            parts = [part for part in sections.values() if part]
            same = all(isinstance(part, str) and part in text for part in parts) and (
                sum(len(part) for part in parts) + 2 * (len(parts) - 1) == len(text)
            )
        else:
            same = False
        if not same:
            bridge.count("agent_log_system_differs")

    mine = [m for m in ours if m["role"] == "assistant"]
    theirs = [m for m in pi_messages if m.get("role") == "assistant"]
    dropped = [m for m in theirs if m.get("stopReason") == "error" and not m.get("content")]
    theirs = [m for m in theirs if not (m.get("stopReason") == "error" and not m.get("content"))]
    if dropped:
        bridge.count("agent_log_error_messages_left_out", len(dropped))
    if len(mine) != len(theirs):
        bridge.count("agent_log_answer_count_differs")
    for a, b in zip(mine, theirs):
        if (a.get("reasoning_content") or "") != joined(b, "thinking", "thinking"):
            bridge.count("agent_log_thinking_differs")
        if (a.get("content") or "") != joined(b, "text", "text"):
            bridge.count("agent_log_text_differs")
        a_calls = [(c["id"], c["function"]["name"], json.loads(c["function"]["arguments"]))
                   for c in a.get("tool_calls") or []]
        b_calls = [(c.get("id"), c.get("name"), c.get("arguments"))
                   for c in b.get("content") or [] if c.get("type") == "toolCall"]
        if a_calls != b_calls:
            bridge.count("agent_log_calls_differ")

    mine = [m for m in ours if m["role"] == "tool"]
    theirs = [m for m in pi_messages if m.get("role") == "toolResult"]
    if len(theirs) > len(mine):
        bridge.count("tool_results_after_the_last_reply", len(theirs) - len(mine))
    elif len(theirs) < len(mine):
        bridge.count("agent_log_tool_result_count_differs")
    for a, b in zip(mine, theirs):
        text = "".join(part.get("text") or "" for part in b.get("content") or [] if part.get("type") == "text")
        if a["content"] != text or a["tool_call_id"] != b.get("toolCallId"):
            bridge.count("agent_log_tool_results_differ")
