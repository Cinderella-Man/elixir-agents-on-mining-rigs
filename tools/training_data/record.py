"""The training record of one stored teacher session: the messages, the template's text and who wrote which part.

README.md in this folder states the record's format field by field.
"""
import hashlib
import json
import os
import re

import bridge as bridge_module
import switches as switches_module
from bridge import ConversionError, sha_bytes, sha_text
from render import C_ISSPACE, MARKUP_KINDS, TEACHER_KINDS, Renderer

FORMAT = "teacher-session-training-record/1"
SOURCES = ("bridge.py", "render.py", "record.py", "switches.py")
READ_KINDS = ("tools", "system_fixed", "instructions", "system_rest", "system", "description", "user", "tool_result")
# a tag or a special token, as the template's own output shows them: <|name|>, <name>, </name>, <name=
TAG = re.compile(r"<\|[^|<>\s]+\|>|</?[A-Za-z_]+[>=]")


def converter_version():
    """A hash of this converter's source: the same source gives the same version on every machine."""
    here = os.path.dirname(os.path.abspath(__file__))
    digest, files = hashlib.sha256(), {}
    for name in SOURCES:
        with open(os.path.join(here, name), "rb") as handle:
            files[name] = sha_bytes(handle.read())
        digest.update(("%s %s\n" % (name, files[name])).encode("utf-8"))
    return digest.hexdigest(), files


def dump(record):
    """The record's bytes: one line of JSON, keys sorted at every level, as the bench's engine writes a request."""
    return (json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def split_system(spans, text, fixed, instructions):
    """The system text in three parts: the agent's fixed text, the instruction text, the rest."""
    out, found = [], {"system_fixed": False, "instructions": False}
    for span in spans:
        if span["kind"] != "system":
            out.append(span)
            continue
        piece, at = text[span["start"]:span["end"]], span["start"]
        cuts = []
        if piece.startswith(fixed.system_before):
            cuts.append(("system_fixed", len(fixed.system_before)))
            found["system_fixed"] = True
            if instructions and piece.startswith(instructions, len(fixed.system_before)):
                cuts.append(("instructions", len(instructions)))
                found["instructions"] = True
        if not cuts:
            out.append(span)
            continue
        cut_by_trim = span.get("cut_by_trim", 0)
        parts = []
        for kind, length in cuts:
            parts.append(dict(span, kind=kind, start=at, end=at + length, cut_by_trim=0))
            at += length
        if at < span["end"]:
            parts.append(dict(span, kind="system_rest", start=at, cut_by_trim=0))
        parts[-1]["cut_by_trim"] = cut_by_trim  # what the template's trim removed, counted once
        out.extend(parts)
    for span in out:
        span.pop("byte_start", None)
        span.pop("byte_end", None)
    Renderer._byte_offsets(text, out, [])
    return out, found


def sizes(text, spans):
    by_kind = {}
    for span in spans:
        entry = by_kind.setdefault(span["kind"], {"spans": 0, "characters": 0, "bytes": 0})
        entry["spans"] += 1
        entry["characters"] += span["end"] - span["start"]
        entry["bytes"] += span["byte_end"] - span["byte_start"]

    def total(kinds, unit):
        return sum(entry[unit] for kind, entry in by_kind.items() if kind in kinds)

    out = {"by_kind": by_kind, "text_characters": len(text), "text_bytes": len(text.encode("utf-8"))}
    for unit in ("characters", "bytes"):
        out["teacher_" + unit] = total(TEACHER_KINDS, unit)
        out["turn_markup_" + unit] = total(("turn_markup",), unit)
        out["read_" + unit] = out["text_" + unit] - out["teacher_" + unit] - out["turn_markup_" + unit]
    return out


def markup_atoms(text, spans):
    """The tags and special tokens the template itself wrote in this text."""
    atoms = set()
    for span in spans:
        if span["kind"] in MARKUP_KINDS:
            atoms.update(TAG.findall(text[span["start"]:span["end"]]))
    return sorted(atoms)


def fixed_lines(text, spans, shortest=40):
    """The longer lines of the fixed text: the template's own lines, the tool lines and the agent's fixed text."""
    lines = set()
    for span in spans:
        if span["kind"] in ("prompt_markup", "tools", "system_fixed"):
            for line in text[span["start"]:span["end"]].split("\n"):
                if len(line.strip()) >= shortest:
                    lines.add(line.strip())
    return lines


def content_checks(text, spans):
    """Counts that say whether an open switch matters for this session, and whether content looks like markup."""
    atoms = markup_atoms(text, spans)
    lines = fixed_lines(text, spans)
    counts = {
        "teacher_spans_holding_a_template_tag": 0,
        "teacher_spans_holding_a_fixed_line": 0,
        "read_spans_holding_a_template_tag": 0,
        "json_values": 0,
        "json_values_with_non_ascii": 0,
        "json_values_with_html_characters": 0,
        "tool_lines_with_non_ascii": 0,
        "tool_lines_with_html_characters": 0,
    }
    for span in spans:
        piece = text[span["start"]:span["end"]]
        kind = span["kind"]
        if kind in TEACHER_KINDS:
            if any(atom in piece for atom in atoms):
                counts["teacher_spans_holding_a_template_tag"] += 1
            if any(line in piece for line in lines):
                counts["teacher_spans_holding_a_fixed_line"] += 1
        elif kind in ("description", "user", "tool_result", "instructions", "system_rest", "system"):
            if any(atom in piece for atom in atoms):
                counts["read_spans_holding_a_template_tag"] += 1
        if span.get("written_as_json") or kind == "tools":
            prefix = "tool_lines" if kind == "tools" else "json_values"
            if kind != "tools":
                counts["json_values"] += 1
            if any(ord(character) > 127 for character in piece):
                counts[prefix + "_with_non_ascii"] += 1
            if any(character in piece for character in "<>&'"):
                counts[prefix + "_with_html_characters"] += 1
    return counts, atoms


def trim_counts(messages, trim):
    """How many characters the template's trim removed, and how many texts the two trim rules would cut
    differently (the trim switch)."""
    from render import content_text

    cut, differ = 0, 0
    for message in messages:
        texts = [content_text(message.get("content"))]
        if isinstance(message.get("reasoning_content"), str):
            texts.append(message["reasoning_content"])
        for value in texts:
            cut += len(value) - len(trim(value))
            if value.strip() != value.strip(C_ISSPACE):
                differ += 1
    return cut, differ


def build(attempt, fixed, given_switches=None, label=None):
    """One record from one stored attempt. Raises ConversionError or RenderError; never returns half a record."""
    values = switches_module.resolve(given_switches)
    bridged, tools = bridge_module.bridge_attempt(attempt, fixed, values)
    messages = bridged.messages
    renderer = Renderer(fixed.template, values)
    text, spans, regions = renderer.layout(messages, tools, add_generation_prompt=False)
    spans, found = split_system(spans, text, fixed, attempt.instructions)

    try:
        encoded = text.encode("utf-8")
    except UnicodeEncodeError as error:
        raise ConversionError("text_not_utf8", "the text holds a character that cannot be written as UTF-8",
                              {"position": error.start}) from None

    turns = []
    for info, region in zip(bridged.turns, regions):
        if info["message"] != region["message"]:
            raise ConversionError("turns_differ", "the bridge and the renderer count the answers differently")
        thinking = messages[info["message"]].get("reasoning_content")
        turn = dict(region)
        turn.update({
            "source": info["source"],
            "stop_reason": info["stop_reason"],
            "thinking": bool(isinstance(thinking, str) and renderer.trim(thinking)),
            "calls": info["calls"],
            "param_order": info["param_order"],
        })
        turns.append(turn)
    if len(bridged.turns) != len(regions):
        raise ConversionError("turns_differ", "the bridge and the renderer count the answers differently")

    fixed_end = max([span["end"] for span in spans if span["kind"] == "system_fixed"], default=0)
    sized = sizes(text, spans)
    checks, atoms = content_checks(text, spans)
    checks["characters_cut_by_trim"], checks["texts_the_two_trim_rules_cut_differently"] = trim_counts(
        messages, renderer.trim
    )
    checks["system_fixed_found"] = found["system_fixed"]
    checks["instructions_found"] = found["instructions"]
    if attempt.prompt is not None:
        first = next((m for m in messages if m["role"] == "user"), None)
        checks["description_file_found"] = bool(first) and attempt.prompt in first["content"][0]["text"]
    for name, value in sorted(bridged.counts.items()):
        if name.startswith(("stream_", "agent_log_", "replies_", "tool_results_out", "no_last", "signatures_",
                            "numbers_", "param_order_", "tool_results_after")):
            checks[name] = value

    counts = {
        "messages": len(messages),
        "turns": len(turns),
        "tool_calls": bridged.counts.get("tool_calls", 0),
        "tool_results": bridged.counts.get("tool_results", 0),
        "tool_results_marked_error": bridged.counts.get("tool_results_marked_error", 0),
        "answers_without_thinking": sum(1 for turn in turns if not turn["thinking"]),
        "answers_with_text": sum(1 for span in spans if span["kind"] == "answer"),
        "answers_cut_by_the_reply_limit": sum(1 for turn in turns if turn["stop_reason"] == "max_tokens"),
        "calls_by_tool": {name[len("calls_"):]: value for name, value in sorted(bridged.counts.items())
                          if name.startswith("calls_")},
        "longest_tool_result_bytes": max(
            [span["byte_end"] - span["byte_start"] for span in spans if span["kind"] == "tool_result"], default=0
        ),
        "longest_thinking_bytes": max(
            [span["byte_end"] - span["byte_start"] for span in spans if span["kind"] == "thinking"], default=0
        ),
    }

    version, files = converter_version()
    record_of = attempt.record or {}
    session = {
        "case": attempt.case,
        "run": attempt.run_id,
        "status": record_of.get("status"),
        "stop_reason": record_of.get("stop_reason"),
        "graded_passed": (record_of.get("grade") or {}).get("passed"),
        "agent": record_of.get("agent"),
        "model": attempt.request.get("model"),
        "last_request": attempt.request_index,
        "replies": len(attempt.replies),
        "ends_with": "answer" if turns and turns[-1]["source"] == "reply" else "request",
    }
    session.update(label or {})

    return {
        "format": FORMAT,
        "session": session,
        "provenance": {
            "converter": {"version": version, "files": files},
            "template": {"name": fixed.template_name, "bytes": fixed.template_bytes,
                         "sha256": fixed.template_sha256},
            "tools": {"name": fixed.tools_name, "sha256": fixed.tools_sha256},
            "system_fixed": {"name": fixed.system_before_name, "sha256": fixed.system_before_sha256},
            "switches": values,
            "inputs": sorted(attempt.inputs, key=lambda item: item["path"]),
        },
        "tools": tools,
        "messages": messages,
        "text": text,
        "text_sha256": hashlib.sha256(encoded).hexdigest(),
        "fixed_text": {"characters": fixed_end, "bytes": len(text[:fixed_end].encode("utf-8")),
                       "sha256": sha_text(text[:fixed_end])},
        "template_tags": atoms,
        "spans": spans,
        "turns": turns,
        "sizes": sized,
        "counts": counts,
        "checks": checks,
    }
