"""Render bench-route messages with the recorded chat template, and say where every part of the text came from.

The text is made by the template alone, under Jinja2, the way docs/data/2026-11-12_target_text_qwen38_27b/run/
render_frame.py does it. To learn which characters the template wrote and which it copied from a message, the same
template is rendered a second time with every piece of content replaced by a marker. The text between the markers is
the template's; putting the content back must give the first rendering, character for character, or the conversion
stops. So this module holds no text of the template: no token, no tag, no line break of its own.
"""
import json
import re

from jinja2.sandbox import ImmutableSandboxedEnvironment

C_ISSPACE = " \t\n\v\f\r"
GENERATION_TAGS = re.compile(r"\{%-?\s*(?:end)?generation\s*-?%\}")
MARKERS = (("", ""), ("", ""), ("\U000f0000", "\U000f0001"))
TEACHER_KINDS = ("thinking", "answer", "call_name", "param_name", "param_value")
MARKUP_KINDS = ("prompt_markup", "turn_markup")


class RenderError(Exception):
    """The template and the conversation do not fit the way this converter needs. Carries no session text."""


def raise_exception(message):
    raise RenderError("the template refused the conversation: %s" % message)


class ToolSlot:
    """Stands for one tool definition while the layout is rendered."""

    def __init__(self, marker):
        self.marker = marker


def parsed(messages):
    """The messages as the server hands them to the template: a call's arguments text parsed into an object."""
    out = []
    for message in messages:
        message = dict(message)
        if message.get("tool_calls"):
            calls = []
            for call in message["tool_calls"]:
                function = dict(call["function"])
                if isinstance(function.get("arguments"), str):
                    function["arguments"] = json.loads(function["arguments"])
                calls.append({**call, "function": function})
            message["tool_calls"] = calls
        out.append(message)
    return out


def content_text(content):
    """A message's content as the template's own macro joins it: text, or the text parts of a list."""
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        if any(not isinstance(item, dict) or not isinstance(item.get("text"), str) or item.get("type") != "text"
               for item in content):
            raise RenderError("a message's content holds a part that is not text")
        return "".join(item["text"] for item in content)
    raise RenderError("a message's content is neither text nor a list of parts")


class Renderer:
    def __init__(self, template_source, switches):
        self.switches = switches
        source = template_source
        if switches["strip_generation_tags"] == "true":
            source = GENERATION_TAGS.sub("", source)
        self.source = source
        environment = ImmutableSandboxedEnvironment(
            trim_blocks=switches["jinja_trim_blocks"] == "true",
            lstrip_blocks=switches["jinja_lstrip_blocks"] == "true",
        )
        environment.filters["tojson"] = self._tojson_filter
        if switches["trim"] == "c_isspace":
            environment.filters["trim"] = lambda value, chars=None: str(value).strip(
                C_ISSPACE if chars is None else chars
            )
        environment.globals["raise_exception"] = raise_exception
        self.environment = environment
        self.template = environment.from_string(source)
        self.variables = {}
        for name in ("enable_thinking", "preserve_thinking"):
            if switches[name] != "unset":
                self.variables[name] = switches[name] == "true"
        if switches["reasoning_effort"] != "unset":
            self.variables["reasoning_effort"] = switches["reasoning_effort"]

    # -- the two filters whose behaviour the switches name --------------------------------------------------------

    def tojson(self, value, ensure_ascii=None, indent=None, separators=None, sort_keys=False):
        if ensure_ascii is None:
            ensure_ascii = self.switches["json_ensure_ascii"] == "true"
        if separators is None:
            separators = (self.switches["json_item_separator"], self.switches["json_key_separator"])
        text = json.dumps(value, ensure_ascii=ensure_ascii, indent=indent, separators=tuple(separators),
                          sort_keys=sort_keys)
        if self.switches["json_escape_html"] == "true":
            text = (text.replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
                    .replace("'", "\\u0027"))
        return text

    def _tojson_filter(self, value, *args, **kwargs):
        if isinstance(value, ToolSlot):
            return value.marker
        return self.tojson(value, *args, **kwargs)

    def trim(self, text):
        return self.environment.filters["trim"](text)

    # -- rendering ------------------------------------------------------------------------------------------------

    def _render(self, template_messages, tools, add_generation_prompt):
        return self.template.render(
            messages=template_messages, tools=tools, add_generation_prompt=add_generation_prompt, **self.variables
        )

    def render(self, messages, tools, add_generation_prompt=False):
        """The text the template writes for these messages, with the begin token the switches name before it."""
        return self.switches["begin_token"] + self._render(parsed(messages), tools, add_generation_prompt)

    # -- the layout: which characters came from where ---------------------------------------------------------------

    def layout(self, messages, tools, add_generation_prompt=False):
        """Returns (text, spans, turns).

        spans: every character of the text exactly once, in order; each span has a kind and where it came from.
        turns: for every assistant message, the stretch of text the model itself writes at test time: from the
        end of the prompt that asks for the answer to the end of the turn's end token.
        """
        template_messages = parsed(messages)
        text = self._render(template_messages, tools, add_generation_prompt)
        opening, closing = self._markers(text)
        pieces = []

        def mark(kind, real, **where):
            pieces.append(dict(where, kind=kind, text=real))
            return "%s%d%s" % (opening, len(pieces) - 1, closing)

        layout_messages = self._layout_messages(template_messages, mark)
        layout_tools = tools
        if tools and isinstance(tools, list):
            layout_tools = [ToolSlot(mark("tools", self.tojson(tool), tool=index)) for index, tool in enumerate(tools)]
        laid = self._render(layout_messages, layout_tools, add_generation_prompt)

        parts = re.split("%s(\\d+)%s" % (re.escape(opening), re.escape(closing)), laid)
        seen = [int(number) for number in parts[1::2]]
        if sorted(seen) != list(range(len(pieces))):
            missing = sorted(set(range(len(pieces))) - set(seen))
            twice = sorted({number for number in seen if seen.count(number) > 1})
            raise RenderError(
                "the template did not write every piece of content exactly once: left out %s, written twice %s"
                % ([self._where(pieces[number]) for number in missing[:5]],
                   [self._where(pieces[number]) for number in twice[:5]])
            )
        rebuilt = "".join(
            part if index % 2 == 0 else pieces[int(part)]["text"] for index, part in enumerate(parts)
        )
        if rebuilt != text:
            raise RenderError(
                "the layout does not give the template's text back: %d characters against %d"
                % (len(rebuilt), len(text))
            )

        turns = self._turns(template_messages, tools, text)
        spans = self._spans(parts, pieces, turns)
        begin = self.switches["begin_token"]
        if begin:
            for item in spans + turns:
                item["start"] += len(begin)
                item["end"] += len(begin)
            spans.insert(0, {"kind": "begin_token", "start": 0, "end": len(begin)})
            text = begin + text
        self._byte_offsets(text, spans, turns)
        return text, spans, turns

    def _markers(self, text):
        for opening, closing in MARKERS:
            if opening not in text and closing not in text and opening not in self.source \
                    and closing not in self.source:
                return opening, closing
        raise RenderError("the conversation holds every marker character this converter can use")

    @staticmethod
    def _where(piece):
        return {key: value for key, value in piece.items() if key != "text"}

    def _field(self, mark, kind, raw, **where):
        """A text the template trims before it writes it. An empty one is written as nothing and gets no span."""
        trimmed = self.trim(raw)
        if trimmed == "":
            return ""
        return mark(kind, trimmed, cut_by_trim=len(raw) - len(trimmed), **where)

    def _layout_messages(self, template_messages, mark):
        out, turn, pending, users = [], -1, [], 0
        for index, message in enumerate(template_messages):
            role = message.get("role")
            laid = dict(message)
            if role in ("system", "developer"):
                laid["content"] = self._field(mark, "system", content_text(message.get("content")), message=index)
            elif role == "user":
                kind = "description" if users == 0 else "user"
                users += 1
                laid["content"] = self._field(mark, kind, content_text(message.get("content")), message=index)
            elif role == "assistant":
                turn += 1
                pending = []
                thinking = message.get("reasoning_content")
                laid["reasoning_content"] = self._field(
                    mark, "thinking", thinking if isinstance(thinking, str) else "", message=index, turn=turn
                )
                laid["content"] = self._field(
                    mark, "answer", content_text(message.get("content")), message=index, turn=turn
                )
                calls = []
                for number, call in enumerate(message.get("tool_calls") or []):
                    function = call.get("function") or {}
                    arguments = function.get("arguments")
                    if arguments is None:
                        arguments = {}
                    if not isinstance(arguments, dict):
                        raise RenderError("a call's arguments are not an object")
                    where = {"message": index, "turn": turn, "call": number}
                    laid_arguments = {}
                    for name, value in arguments.items():
                        key = mark("param_name", name, param=name, **where)
                        if isinstance(value, str):
                            laid_arguments[key] = mark("param_value", value, param=name, **where) if value else ""
                        else:
                            laid_arguments[key] = mark("param_value", self.tojson(value), param=name,
                                                       written_as_json=True, **where)
                    calls.append({"type": "function", "function": {
                        "name": mark("call_name", function.get("name"), **where), "arguments": laid_arguments}})
                    pending.append((turn, number))
                if calls:
                    laid["tool_calls"] = calls
            elif role == "tool":
                where = {"message": index}
                if pending:
                    where["turn"], where["call"] = pending.pop(0)
                laid["content"] = self._field(mark, "tool_result", content_text(message.get("content")), **where)
            out.append(laid)
        return out

    def _turns(self, template_messages, tools, text):
        """Where each answer starts and ends, found with the template itself.

        The prompt that asks for answer k is the rendering of the messages before it with the generation prompt
        added: the answer starts where that prompt ends. It ends with the turn's end token.
        """
        end_token = self.switches["end_token"]
        turns = []
        for index, message in enumerate(template_messages):
            if message.get("role") != "assistant":
                continue
            prompt = self._render(template_messages[:index], tools, True)
            if not text.startswith(prompt):
                raise RenderError(
                    "the conversation is not one text that only grows: the prompt before message %d is not the "
                    "start of the whole text" % index
                )
            through = self._render(template_messages[: index + 1], tools, False)
            if not text.startswith(through):
                raise RenderError("the text up to message %d is not the start of the whole text" % index)
            at = through.rfind(end_token)
            if at < len(prompt):
                raise RenderError("message %d does not end with the end token" % index)
            turns.append({"turn": len(turns), "message": index, "start": len(prompt), "end": at + len(end_token)})
        return turns

    def _spans(self, parts, pieces, turns):
        spans, offset = [], 0
        for index, part in enumerate(parts):
            if index % 2 == 0:
                # the template's own characters: split where an answer starts or ends
                start, end = offset, offset + len(part)
                cuts = sorted({start, end} | {
                    edge for turn in turns for edge in (turn["start"], turn["end"]) if start < edge < end
                })
                for a, b in zip(cuts, cuts[1:]):
                    inside = next((turn for turn in turns if turn["start"] <= a and b <= turn["end"]), None)
                    span = {"kind": "turn_markup" if inside else "prompt_markup", "start": a, "end": b}
                    if inside:
                        span["turn"], span["message"] = inside["turn"], inside["message"]
                    spans.append(span)
                offset = end
            else:
                piece = pieces[int(part)]
                start, end = offset, offset + len(piece["text"])
                offset = end
                if start == end:
                    continue
                span = {key: value for key, value in piece.items() if key != "text"}
                span["start"], span["end"] = start, end
                inside = next((turn for turn in turns if turn["start"] <= start and end <= turn["end"]), None)
                crossing = any(
                    start < turn["end"] and turn["start"] < end and not (turn["start"] <= start and end <= turn["end"])
                    for turn in turns
                )
                teacher = piece["kind"] in TEACHER_KINDS
                if crossing or teacher != (inside is not None) or (teacher and inside["turn"] != piece["turn"]):
                    raise RenderError("a piece of content does not lie where its turn is: %s" % self._where(piece))
                spans.append(span)
        return spans

    @staticmethod
    def _byte_offsets(text, spans, turns):
        position, at = 0, 0
        edges = {}
        for point in sorted({edge for item in spans + turns for edge in (item["start"], item["end"])}):
            at += len(text[position:point].encode("utf-8"))
            position = point
            edges[point] = at
        for item in spans + turns:
            item["byte_start"], item["byte_end"] = edges[item["start"]], edges[item["end"]]
