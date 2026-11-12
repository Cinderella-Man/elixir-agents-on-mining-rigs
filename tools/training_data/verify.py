"""Check a finished record against itself and against the template: nothing here trusts the conversion.

verify(record, raw_bytes, fixed) returns a list of problems, each a short sentence without session text. An empty
list means: the template's text built from the record's messages is the stored text, the spans cover it exactly
once, every span holds what it says it holds, and no span of the teacher's holds fixed text.
"""
import hashlib
import json

from record import FORMAT, dump, fixed_lines
from render import MARKUP_KINDS, TEACHER_KINDS, Renderer, content_text, parsed

KNOWN_KINDS = TEACHER_KINDS + MARKUP_KINDS + (
    "begin_token", "tools", "system", "system_fixed", "instructions", "system_rest", "description", "user",
    "tool_result",
)


def verify(record, raw, fixed):
    problems = []

    def bad(sentence):
        problems.append(sentence)

    if record.get("format") != FORMAT:
        return ["the record's format is %r, not %r" % (record.get("format"), FORMAT)]
    if raw is not None and dump(record) != raw:
        bad("the file is not the record's own way of writing it (keys sorted, one line)")

    text, spans, turns = record["text"], record["spans"], record["turns"]
    messages, tools = record["messages"], record["tools"]
    switches = record["provenance"]["switches"]
    if hashlib.sha256(text.encode("utf-8")).hexdigest() != record["text_sha256"]:
        bad("the text's hash is not the stored one")
    if record["provenance"]["template"]["sha256"] != fixed.template_sha256:
        return problems + ["the template at hand is not the one the record was made with"]
    if tools != fixed.tools:
        bad("the record's tool definitions are not the recorded ones")

    # 1. the template's text, built again from the messages
    renderer = Renderer(fixed.template, switches)
    again = renderer.render(messages, tools, add_generation_prompt=False)
    if again != text:
        bad("the template's text for the record's messages is not the stored text: %d characters against %d, "
            "sha256 %s against %s" % (len(again), len(text), hashlib.sha256(again.encode("utf-8")).hexdigest(),
                                      record["text_sha256"]))

    # 2. the spans cover the text exactly once, in order, in characters and in bytes
    position, at = 0, 0
    for number, span in enumerate(spans):
        if span["kind"] not in KNOWN_KINDS:
            bad("span %d has the unknown kind %r" % (number, span["kind"]))
        if span["start"] != position or span["end"] <= span["start"]:
            bad("span %d does not start where the one before it ends, or is empty" % number)
            break
        size = len(text[span["start"]:span["end"]].encode("utf-8"))
        if span["byte_start"] != at or span["byte_end"] != at + size:
            bad("span %d has wrong byte offsets" % number)
        position, at = span["end"], at + size
    if position != len(text):
        bad("the spans end at character %d, the text at %d" % (position, len(text)))

    # 3. each answer's stretch ends with the end token, and spans lie on the right side of it
    #    and what stands before an answer is the prompt the template writes for the request that asks for it
    end_token = switches["end_token"]
    answers = [index for index, message in enumerate(messages) if message["role"] == "assistant"]
    if [turn["message"] for turn in turns] != answers:
        bad("the answers listed are not the assistant messages")
    for turn in turns:
        if text[turn["end"] - len(end_token):turn["end"]] != end_token:
            bad("answer %d does not end with the end token" % turn["turn"])
        prompt = renderer.render(messages[:turn["message"]], tools, add_generation_prompt=True)
        if text[:turn["start"]] != prompt:
            bad("the text before answer %d is not the prompt the template writes for the request that asks for it"
                % turn["turn"])
    for number, span in enumerate(spans):
        inside = [turn for turn in turns if turn["start"] <= span["start"] and span["end"] <= turn["end"]]
        if span["kind"] in TEACHER_KINDS + ("turn_markup",):
            if len(inside) != 1 or inside[0]["turn"] != span.get("turn"):
                bad("span %d (%s) is not inside its own answer" % (number, span["kind"]))
        elif inside or any(span["start"] < turn["end"] and turn["start"] < span["end"] for turn in turns):
            bad("span %d (%s) reaches into an answer" % (number, span["kind"]))

    # 4. every span holds what it says it holds, and every piece of content has its span
    template_messages = parsed(messages)
    expected = {}  # (kind, message, call, param) -> text
    system, users = [], 0
    for index, message in enumerate(template_messages):
        role = message["role"]
        if role == "system":
            system.append(renderer.trim(content_text(message.get("content"))))
        elif role == "user":
            kind = "description" if users == 0 else "user"
            users += 1
            expected[(kind, index, None, None)] = renderer.trim(content_text(message.get("content")))
        elif role == "tool":
            expected[("tool_result", index, None, None)] = renderer.trim(content_text(message.get("content")))
        elif role == "assistant":
            thinking = message.get("reasoning_content")
            expected[("thinking", index, None, None)] = renderer.trim(thinking if isinstance(thinking, str) else "")
            expected[("answer", index, None, None)] = renderer.trim(content_text(message.get("content")))
            for number, call in enumerate(message.get("tool_calls") or []):
                function = call["function"]
                expected[("call_name", index, number, None)] = function["name"]
                for name, value in (function.get("arguments") or {}).items():
                    expected[("param_name", index, number, name)] = name
                    expected[("param_value", index, number, name)] = (
                        value if isinstance(value, str) else renderer.tojson(value)
                    )
    expected = {key: value for key, value in expected.items() if value != ""}

    found, system_found, tools_found = {}, [], {}
    for span in spans:
        piece = text[span["start"]:span["end"]]
        kind = span["kind"]
        if kind in ("system", "system_fixed", "instructions", "system_rest"):
            system_found.append(piece)
        elif kind == "tools":
            tools_found[span.get("tool")] = piece
        elif kind in TEACHER_KINDS or kind in ("description", "user", "tool_result"):
            key = (kind, span.get("message"), span.get("call") if kind not in ("thinking", "answer", "tool_result")
                   else None, span.get("param") if kind in ("param_name", "param_value") else None)
            if key in found:
                bad("two spans claim the same piece: %s of message %s" % (kind, span.get("message")))
            found[key] = piece
    if found != expected:
        missing = sorted(str(key) for key in set(expected) - set(found))
        extra = sorted(str(key) for key in set(found) - set(expected))
        wrong = sorted(str(key) for key in set(found) & set(expected) if found[key] != expected[key])
        bad("spans and messages disagree: %d pieces without a span, %d spans without a piece, %d with other text"
            " (first: %s)" % (len(missing), len(extra), len(wrong), (missing + extra + wrong)[:3]))
    if "".join(system_found) != "".join(system):
        bad("the system spans do not hold the system text")
    if tools_found != {index: renderer.tojson(tool) for index, tool in enumerate(tools)}:
        bad("the tool spans do not hold the tool definitions as the template writes them")
    fixed_spans = [span for span in spans if span["kind"] == "system_fixed"]
    if len(fixed_spans) != 1 or text[fixed_spans[0]["start"]:fixed_spans[0]["end"]] != fixed.system_before:
        bad("the agent's fixed system text is not one span holding the recorded text")

    # 5. no span of the teacher's holds fixed text
    lines = fixed_lines(text, spans)
    holding = sum(
        1 for span in spans
        if span["kind"] in TEACHER_KINDS and any(line in text[span["start"]:span["end"]] for line in lines)
    )
    if holding:
        bad("%d spans of the teacher's hold a line of the fixed text" % holding)
    if holding != record["checks"].get("teacher_spans_holding_a_fixed_line"):
        bad("the record's own count of such spans is another one")

    # 6. the fixed text at the start of the record
    stated = record["fixed_text"]
    head = text[:stated["characters"]]
    if hashlib.sha256(head.encode("utf-8")).hexdigest() != stated["sha256"] or (
        fixed_spans and stated["characters"] != fixed_spans[0]["end"]
    ):
        bad("the stated fixed text is not the start of the text up to the end of the agent's fixed system text")

    # 7. the messages can be read back unchanged
    if json.loads(dump(record).decode("utf-8"))["messages"] != messages:
        bad("the messages do not survive writing and reading the record")
    return problems
