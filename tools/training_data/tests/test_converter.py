#!/usr/bin/env python3
"""Tests of the converter. Every conversation here is made up; no text of a real session or case is used.

    python3 -I tools/training_data/tests/test_converter.py -v

The recorded target text is read from TARGET_TEXT, or from this repository's
docs/data/2026-11-12_target_text_qwen38_27b/.
"""
import copy
import hashlib
import importlib.util
import json
import os
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.dirname(HERE)
sys.path.insert(0, TOOL)
sys.path.insert(0, HERE)

import bridge  # noqa: E402
import record as record_module  # noqa: E402
import switches as switches_module  # noqa: E402
from bridge import Attempt, ConversionError, Fixed, bridge_request, default_fixed_paths  # noqa: E402
from convert_session import convert  # noqa: E402
from fake_session import write_session  # noqa: E402
from render import MARKUP_KINDS, TEACHER_KINDS, Renderer, RenderError  # noqa: E402
from verify import verify  # noqa: E402

TARGET = os.environ.get("TARGET_TEXT") or os.path.join(
    TOOL, "..", "..", "docs", "data", "2026-11-12_target_text_qwen38_27b"
)
FIXED = Fixed(*default_fixed_paths())
DEFAULTS = switches_module.defaults()


def recorded_renderer():
    """The target-text folder's own way of rendering a frame: its run/render_frame.py, loaded as it is."""
    spec = importlib.util.spec_from_file_location("render_frame", os.path.join(TARGET, "run", "render_frame.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def frame(name):
    with open(os.path.join(TARGET, "frames", name), encoding="utf-8") as handle:
        return json.load(handle)


def text_of(record, span):
    return record["text"][span["start"]:span["end"]]


def spans_of(record, kind, **where):
    return [span for span in record["spans"]
            if span["kind"] == kind and all(span.get(key) == value for key, value in where.items())]


def tree_hashes(folder):
    out = {}
    for base, _, names in os.walk(folder):
        for name in names:
            path = os.path.join(base, name)
            with open(path, "rb") as handle:
                out[os.path.relpath(path, folder)] = (hashlib.sha256(handle.read()).hexdigest(),
                                                      os.stat(path).st_mtime_ns)
    return out


PLAIN = {
    "turns": [{"thinking": "The ticket is clear. Nothing to run.", "text": "Nothing had to change.",
               "stop": "end_turn"}],
}
TWO_CALLS = {
    "turns": [
        {"thinking": "I will run the cart tests first, then look for where the total is built.",
         "calls": [{"name": "bash", "raw": '{"command":"mix test test/shop/cart_test.exs","timeout":120}'},
                   {"name": "bash", "raw": '{"command":"grep -n total lib/shop/cart.ex"}'},
                   {"name": "read", "raw": '{"path":"lib/shop/cart.ex","offset":10,"limit":5}'}],
         "results": [{"content": "1 test, 1 failure\n"}, {"content": "14:  def total(cart) do\n"},
                     {"content": "  def total(cart) do\n    cart.sum\n  end\n\n[40 more lines in file. Use offset=15 to continue.]"}]},
        {"thinking": "The discount is never subtracted.",
         "text": "I will change the total.",
         "calls": [{"name": "edit", "raw": json.dumps(
             {"path": "lib/shop/cart.ex",
              "edits": [{"oldText": "cart.sum", "newText": "cart.sum - cart.discount"}]})}],
         "results": [{"content": "Successfully replaced 1 block(s) in lib/shop/cart.ex."}]},
        {"thinking": "Done.", "text": "The total now subtracts the discount.", "stop": "end_turn"},
    ],
}


class Case(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="converter-test-")
        self.addCleanup(shutil.rmtree, self.root, True)

    def session(self, spec, name="a"):
        return write_session(os.path.join(self.root, name), TARGET, spec)

    def convert(self, spec, given=None, name="a"):
        folder = self.session(spec, name)
        record, data = convert(folder, os.path.join(self.root, name + ".json"), given, {"project": "made-up"}, FIXED)
        self.assertEqual(verify(record, data, FIXED), [])
        return record, data


class TheByteTest(unittest.TestCase):
    """For every frame the target-text folder holds, the converter's text is what the recorded template writes."""

    def setUp(self):
        self.theirs = recorded_renderer()
        self.template = os.path.join(TARGET, "templates", "bench_gguf_chat_template.jinja")
        self.renderer = Renderer(FIXED.template, DEFAULTS)

    def test_the_template_is_the_recorded_one(self):
        self.assertEqual(FIXED.template_sha256, "12827f24b742ea4e80cdc12dbcf9622227056b9f797252a3149263d4f9aaadce")
        self.assertEqual(FIXED.template_bytes, 9993)

    def test_bench_frames(self):
        for name in ("bench_first", "bench_middle"):
            with self.subTest(frame=name):
                request = frame(name + "_request.frame.json")
                ours = self.renderer.render(request["messages"], request["tools"], add_generation_prompt=True)
                with open(os.path.join(TARGET, "frames", name + "_prompt.rendered_from_frame.txt"), "rb") as handle:
                    stored = handle.read()
                self.assertEqual(ours.encode("utf-8"), stored)
                self.assertEqual(ours, self.theirs.render(self.template, request))
                self.assertEqual(request["tools"], FIXED.tools)

    def test_teacher_frames(self):
        with open(os.path.join(TARGET, "frames", "bench_middle_prompt.rendered_from_frame.txt"),
                  encoding="utf-8", newline="") as handle:
            bench = handle.read()
        for name in ("teacher_first", "teacher_middle"):
            with self.subTest(frame=name):
                request = frame(name + "_request.frame.json")
                bridged, tools = bridge_request(request, FIXED, DEFAULTS)
                ours = self.renderer.render(bridged.messages, tools, add_generation_prompt=True)
                theirs = self.theirs.render(self.template, {"messages": bridged.messages, "tools": tools})
                self.assertEqual(ours.encode("utf-8"), theirs.encode("utf-8"))
                # the fixed text is the bench's, byte for byte: everything up to the end of the agent's fixed text
                head = ours.index(FIXED.system_before) + len(FIXED.system_before)
                self.assertEqual(ours[:head], bench[:head])
                # and the frame of the turns is the bench's: a bridged message has the bench's keys
                for message in bridged.messages:
                    if message["role"] == "tool":
                        self.assertEqual(sorted(message), ["content", "role", "tool_call_id"])
                    if message["role"] == "assistant" and message.get("tool_calls"):
                        self.assertEqual(sorted(message["tool_calls"][0]), ["function", "id", "type"])
                        self.assertEqual(sorted(message["tool_calls"][0]["function"]), ["arguments", "name"])

    def test_layout_of_every_frame(self):
        for name in ("bench_first", "bench_middle", "teacher_first", "teacher_middle"):
            with self.subTest(frame=name):
                request = frame(name + "_request.frame.json")
                if "system" in request:
                    bridged, tools = bridge_request(request, FIXED, DEFAULTS)
                    messages = bridged.messages
                else:
                    messages, tools = request["messages"], request["tools"]
                text, spans, turns = self.renderer.layout(messages, tools, add_generation_prompt=True)
                self.assertEqual(text, self.renderer.render(messages, tools, add_generation_prompt=True))
                self.assertEqual(spans[0]["start"], 0)
                self.assertEqual(spans[-1]["end"], len(text))
                for a, b in zip(spans, spans[1:]):
                    self.assertEqual(a["end"], b["start"])
                self.assertEqual(len(turns), sum(1 for m in messages if m["role"] == "assistant"))

    def test_the_three_recorded_templates_write_the_same_text(self):
        request = frame("teacher_middle_request.frame.json")
        bridged, tools = bridge_request(request, FIXED, DEFAULTS)
        texts = set()
        for name in ("bench_gguf_chat_template.jinja", "maker_chat_template_2026-08-13.jinja",
                     "maker_chat_template_2026-11-07.jinja"):
            with open(os.path.join(TARGET, "templates", name), encoding="utf-8", newline="") as handle:
                texts.add(Renderer(handle.read(), DEFAULTS).render(bridged.messages, tools, True))
        self.assertEqual(len(texts), 1)


class MadeUpSessions(Case):
    def test_a_plain_exchange(self):
        record, _ = self.convert(PLAIN)
        self.assertEqual([m["role"] for m in record["messages"]], ["system", "user", "assistant"])
        self.assertEqual(record["counts"]["turns"], 1)
        self.assertEqual(record["counts"]["tool_calls"], 0)
        self.assertEqual(record["session"]["ends_with"], "answer")
        last = record["messages"][-1]
        self.assertEqual(last["content"], "Nothing had to change.")
        self.assertEqual(last["reasoning_content"], "The ticket is clear. Nothing to run.")
        self.assertNotIn("tool_calls", last)
        self.assertEqual([text_of(record, s) for s in spans_of(record, "thinking")],
                         ["The ticket is clear. Nothing to run."])
        self.assertEqual([text_of(record, s) for s in spans_of(record, "answer")], ["Nothing had to change."])
        # the description keeps the agent's wrapper; the template trims the line break after it
        self.assertEqual(text_of(record, spans_of(record, "description")[0]),
                         record["messages"][1]["content"][0]["text"].strip())
        # the text ends with the end of the answer's turn, and no prompt for another answer follows
        self.assertEqual(record["turns"][-1]["end"], len(record["text"]) - 1)

    def test_several_tool_calls_in_one_answer(self):
        record, _ = self.convert(TWO_CALLS)
        first = record["messages"][2]
        self.assertEqual(len(first["tool_calls"]), 3)
        self.assertIsNone(first["content"])
        # the arguments are JSON without spaces, in the order the teacher wrote them, not the stored sorted order
        self.assertEqual(first["tool_calls"][0]["function"]["arguments"],
                         '{"command":"mix test test/shop/cart_test.exs","timeout":120}')
        self.assertEqual(first["tool_calls"][2]["function"]["arguments"],
                         '{"path":"lib/shop/cart.ex","offset":10,"limit":5}')
        self.assertEqual([m["role"] for m in record["messages"][3:6]], ["tool", "tool", "tool"])
        self.assertEqual(record["messages"][3]["tool_call_id"], first["tool_calls"][0]["id"])
        names = [text_of(record, s) for s in spans_of(record, "param_name", turn=0, call=2)]
        self.assertEqual(names, ["path", "offset", "limit"])
        values = [text_of(record, s) for s in spans_of(record, "param_value", turn=0, call=2)]
        self.assertEqual(values, ["lib/shop/cart.ex", "10", "5"])
        self.assertEqual(record["turns"][0]["param_order"], ["stream", "stream", "stream"])
        # the nested order too: the teacher wrote oldText before newText
        edit = record["messages"][6]["tool_calls"][0]["function"]["arguments"]
        self.assertLess(edit.index("oldText"), edit.index("newText"))
        self.assertLess(edit.index('"path"'), edit.index('"edits"'))
        value = [s for s in spans_of(record, "param_value", turn=1) if s.get("written_as_json")]
        self.assertEqual([text_of(record, s) for s in value],
                         ['[{"oldText": "cart.sum", "newText": "cart.sum - cart.discount"}]'])
        # text beside a call is the answer's content
        self.assertEqual(record["messages"][6]["content"], "I will change the total.")
        self.assertEqual(record["counts"]["tool_calls"], 4)
        self.assertEqual(record["counts"]["calls_by_tool"], {"bash": 2, "edit": 1, "read": 1})
        self.assertEqual(record["counts"]["answers_with_text"], 2)
        # the three results of one answer share one stretch of text with no answer in between
        results = spans_of(record, "tool_result", turn=0)
        self.assertEqual(len(results), 3)
        self.assertEqual(text_of(record, results[0]), "1 test, 1 failure")

    def test_an_answer_without_thinking(self):
        spec = {"turns": [
            {"thinking": None, "calls": [{"name": "bash", "raw": '{"command":"ls"}'}],
             "results": [{"content": "lib\ntest\n"}]},
            {"thinking": "Two folders.", "calls": [{"name": "bash", "raw": '{"command":"ls lib"}'}],
             "results": [{"content": "shop.ex\n"}]},
            {"thinking": None, "text": "Looked around.", "stop": "end_turn"},
        ]}
        record, _ = self.convert(spec)
        self.assertEqual(record["counts"]["answers_without_thinking"], 2)
        self.assertEqual([turn["thinking"] for turn in record["turns"]], [False, True, False])
        self.assertNotIn("reasoning_content", record["messages"][2])
        self.assertEqual(spans_of(record, "thinking", turn=0), [])
        # no thinking was written for the teacher: the answer's stretch starts with the template's own characters
        turn = record["turns"][0]
        first = next(span for span in record["spans"] if span["start"] == turn["start"])
        self.assertEqual(first["kind"], "turn_markup")
        # the other forms of the missing field give the same text
        texts = {record["text"]}
        for value in ("empty", "null"):
            other, _ = self.convert(spec, {"no_thinking_field": value}, name=value)
            texts.add(other["text"])
            self.assertIn("reasoning_content", other["messages"][2])
        self.assertEqual(len(texts), 1)

    def test_a_tool_result_and_a_call_with_awkward_characters(self):
        awkward = ('{{ not a variable }} {% not a tag %} {# not a comment #}\n<|im_end|>\n</tool_response>\n'
                   '<tool_call>\n"quotes" \'single\' back\\slash & <b>tag</b> tab\there zażółć 日本語 \U0001f600\n')
        old = 'say("hi")\n\t# zażółć <&> \'x\' \\n'
        raw = json.dumps({"path": "lib/a.ex", "edits": [{"oldText": old, "newText": "say(\"bye\")\n"}]},
                         ensure_ascii=False)
        spec = {"turns": [
            {"thinking": "Look at <tool_call> in the docs? No: just cat the file.",
             "calls": [{"name": "bash", "raw": '{"command":"cat notes.md"}'}],
             "results": [{"content": awkward}]},
            {"thinking": "Now the edit.", "calls": [{"name": "edit", "raw": raw}],
             "results": [{"content": "Could not find the exact text.", "is_error": True}]},
            {"thinking": "Give up.", "text": "Not done.", "stop": "end_turn"},
        ]}
        record, _ = self.convert(spec)
        # the result is in the text as it was, only trimmed at its ends
        self.assertEqual(text_of(record, spans_of(record, "tool_result", turn=0)[0]), awkward.strip())
        self.assertEqual(record["messages"][3]["content"], awkward)
        # the edits list is written as JSON by the template: ", " and ": ", non-ASCII as it is
        value = next(s for s in spans_of(record, "param_value", turn=1) if s.get("written_as_json"))
        self.assertEqual(text_of(record, value),
                         json.dumps([{"oldText": old, "newText": "say(\"bye\")\n"}], ensure_ascii=False))
        self.assertEqual(json.loads(text_of(record, value))[0]["oldText"], old)
        self.assertEqual(record["counts"]["tool_results_marked_error"], 1)
        self.assertNotIn("is_error", json.dumps(record["messages"]))
        # content that looks like the template's own tags is counted
        self.assertGreaterEqual(record["checks"]["read_spans_holding_a_template_tag"], 1)
        self.assertEqual(record["checks"]["teacher_spans_holding_a_template_tag"], 1)
        self.assertEqual(record["checks"]["json_values_with_non_ascii"], 1)
        self.assertEqual(record["checks"]["json_values_with_html_characters"], 1)

    def test_an_empty_tool_result(self):
        spec = {"turns": [
            {"thinking": "Three commands.",
             "calls": [{"name": "bash", "raw": '{"command":"true"}'}, {"name": "bash", "raw": '{"command":"echo"}'},
                       {"name": "bash", "raw": '{"command":"touch a"}'}],
             "results": [{"content": ""}, {"content": " \n\t\n"}, {"content": "(no output)"}]},
            {"thinking": "Fine.", "text": "Done.", "stop": "end_turn"},
        ]}
        record, _ = self.convert(spec)
        self.assertEqual(record["counts"]["tool_results"], 3)
        self.assertEqual([m["content"] for m in record["messages"][3:6]], ["", " \n\t\n", "(no output)"])
        # an empty result is written as nothing between the template's own lines: it has no span
        results = spans_of(record, "tool_result")
        self.assertEqual([text_of(record, s) for s in results], ["(no output)"])
        self.assertEqual(record["checks"]["characters_cut_by_trim"] >= 4, True)

    def test_a_very_long_tool_result(self):
        long = "".join("line %06d of a made-up log, with some words to fill it\n" % number for number in range(9000))
        self.assertGreater(len(long), 400000)
        spec = {"turns": [
            {"thinking": "Print everything.", "calls": [{"name": "bash", "raw": '{"command":"cat big.log"}'}],
             "results": [{"content": long}]},
            {"thinking": "Long.", "text": "Read it.", "stop": "end_turn"},
        ]}
        record, _ = self.convert(spec)
        span = spans_of(record, "tool_result")[0]
        self.assertEqual(text_of(record, span), long.strip())
        self.assertEqual(record["counts"]["longest_tool_result_bytes"], len(long.strip().encode("utf-8")))
        self.assertEqual(record["sizes"]["by_kind"]["tool_result"]["bytes"], len(long.strip().encode("utf-8")))
        self.assertEqual(record["sizes"]["teacher_bytes"] + record["sizes"]["turn_markup_bytes"]
                         + record["sizes"]["read_bytes"], record["sizes"]["text_bytes"])

    def test_a_session_that_ends_at_a_limit_with_a_cut_off_answer(self):
        spec = {
            "stop_reason": "token_budget", "passed": False, "agent_error_at_the_end": True,
            "turns": [
                {"thinking": "A long command.",
                 "calls": [{"name": "bash", "raw": '{"command":"python3 - <<EOF\\nprint(1)\\npri',
                            "agent_reading": {"command": "python3 - <<EOF\nprint(1)\npri"}}],
                 "results": [{"content": "The reply was cut off.", "is_error": True}], "stop": "max_tokens"},
                {"thinking": "Again, shorter.", "calls": [{"name": "bash", "raw": '{"command":"mix test"}'}],
                 "results": [{"content": "3 tests, 0 failures\n"}]},
                {"thinking": "One more look",
                 "calls": [{"name": "edit", "raw": '{"path":"lib/a.ex","edits":[{"oldText":"a","newTe',
                            "agent_reading": {"path": "lib/a.ex", "edits": [{"oldText": "a"}]}}],
                 "results": [{"content": "The reply was cut off.", "is_error": True}], "stop": "max_tokens"},
            ],
        }
        record, _ = self.convert(spec)
        self.assertEqual(record["session"]["stop_reason"], "token_budget")
        self.assertEqual(record["session"]["graded_passed"], False)
        self.assertEqual(record["counts"]["answers_cut_by_the_reply_limit"], 2)
        self.assertEqual([turn["stop_reason"] for turn in record["turns"]], ["max_tokens", "tool_use", "max_tokens"])
        # a cut-off call inside the session: the stored request holds what the agent read of it
        self.assertEqual(record["turns"][0]["param_order"], ["request_one_key"])
        # the last reply is in no request: what the agent read of its cut-off call comes from the agent's log
        self.assertEqual(record["turns"][2]["param_order"], ["agent_log_cut_call"])
        self.assertEqual(json.loads(record["messages"][-1]["tool_calls"][0]["function"]["arguments"]),
                         {"path": "lib/a.ex", "edits": [{"oldText": "a"}]})
        # the record ends with the model's last reply; the result that came after it was never shown to the model
        self.assertEqual(record["messages"][-1]["role"], "assistant")
        self.assertEqual(record["checks"]["tool_results_after_the_last_reply"], 1)
        self.assertEqual(record["checks"]["agent_log_error_messages_left_out"], 1)
        self.assertEqual(record["session"]["ends_with"], "answer")

    def test_a_session_whose_last_request_has_no_reply(self):
        spec = {"stop_reason": "token_budget", "passed": False, "reply_to_last_request": False, "turns": [
            {"thinking": "Run the tests.", "calls": [{"name": "bash", "raw": '{"command":"mix test"}'}],
             "results": [{"content": "3 tests, 1 failure\n"}]},
            {},
        ]}
        record, _ = self.convert(spec)
        self.assertEqual(record["session"]["ends_with"], "request")
        self.assertEqual(record["messages"][-1]["role"], "tool")
        self.assertEqual(record["counts"]["turns"], 1)
        self.assertEqual(record["checks"]["no_last_reply"], 1)
        # the text ends with the turn that holds the results; no answer follows, and none is asked for
        self.assertEqual(record["spans"][-1]["kind"], "prompt_markup")

    def test_the_messages_come_back_unchanged(self):
        record, data = self.convert(TWO_CALLS)
        read = json.loads(data.decode("utf-8"))
        self.assertEqual(read["messages"], record["messages"])
        self.assertEqual(read["tools"], FIXED.tools)
        self.assertEqual(Renderer(FIXED.template, read["provenance"]["switches"]).render(
            read["messages"], read["tools"]), read["text"])
        self.assertEqual(record_module.dump(read), data)

    def test_the_same_input_gives_the_same_bytes(self):
        one, data_one = self.convert(TWO_CALLS, name="one")
        two, data_two = self.convert(TWO_CALLS, name="two")  # the same session in another folder
        self.assertEqual(data_one, data_two)
        folder = os.path.join(self.root, "one", "20260101-000000-0000beef", "shop-pr-1")
        _, again = convert(folder, None, None, {"project": "made-up"}, FIXED)
        self.assertEqual(again, data_one)

    def test_the_stored_session_is_not_changed(self):
        folder = self.session(TWO_CALLS)
        before = tree_hashes(os.path.dirname(folder))
        convert(folder, os.path.join(self.root, "out", "r.json"), None, None, FIXED)
        self.assertEqual(tree_hashes(os.path.dirname(folder)), before)

    def test_the_provenance(self):
        folder = self.session(TWO_CALLS)
        record, _ = convert(folder, None, {"trim": "c_isspace"}, None, FIXED)
        provenance = record["provenance"]
        self.assertEqual(provenance["template"]["sha256"], FIXED.template_sha256)
        self.assertEqual(provenance["switches"]["trim"], "c_isspace")
        self.assertEqual(sorted(provenance["switches"]), sorted(switches_module.SWITCHES))
        self.assertEqual(record["session"]["run"], "20260101-000000-0000beef")
        self.assertEqual(record["session"]["case"], "shop-pr-1")
        version, files = record_module.converter_version()
        self.assertEqual(provenance["converter"], {"version": version, "files": files})
        self.assertEqual(sorted(files), sorted(record_module.SOURCES))
        paths = [item["path"] for item in provenance["inputs"]]
        self.assertIn("run.json", paths)
        self.assertIn("shop-pr-1/request-0002.json", paths)
        self.assertNotIn("shop-pr-1/request-0001.json", paths)  # only the last request is read
        self.assertEqual(sum(1 for path in paths if path.endswith(".sse")), 3)
        for item in provenance["inputs"]:
            with open(os.path.join(os.path.dirname(folder), item["path"]), "rb") as handle:
                data = handle.read()
            self.assertEqual((item["bytes"], item["sha256"]), (len(data), hashlib.sha256(data).hexdigest()))
        self.assertNotIn(self.root, json.dumps(record))

    def test_every_character_has_a_source(self):
        """The converter adds no text of its own: content spans are the session's, the rest is the template's."""
        record, _ = self.convert(TWO_CALLS)
        sources = [json.dumps(FIXED.tools[i], ensure_ascii=False, separators=(", ", ": ")) for i in range(4)]
        for message in record["messages"]:
            if isinstance(message.get("content"), str):
                sources.append(message["content"])
            elif isinstance(message.get("content"), list):
                sources.extend(part["text"] for part in message["content"])
            sources.append(message.get("reasoning_content") or "")
            for call in message.get("tool_calls") or []:
                sources.append(call["function"]["name"])
                arguments = json.loads(call["function"]["arguments"])
                for name, value in arguments.items():
                    sources.append(name)
                    sources.append(value if isinstance(value, str)
                                   else json.dumps(value, ensure_ascii=False, separators=(", ", ": ")))
        template_text = set()
        for span in record["spans"]:
            piece = text_of(record, span)
            if span["kind"] in MARKUP_KINDS:
                template_text.add(piece)
            else:
                self.assertTrue(any(piece in source for source in sources), span["kind"])
        # the template's own characters do not depend on the session: another session gives the same pieces
        other, _ = self.convert({"turns": [
            {"thinking": "Other words.", "calls": [{"name": "bash", "raw": '{"command":"pwd","timeout":5}'},
                                                   {"name": "bash", "raw": '{"command":"id"}'},
                                                   {"name": "read", "raw": '{"path":"a","offset":1,"limit":2}'}],
             "results": [{"content": "/workspace"}, {"content": "uid=0"}, {"content": "x"}]},
            {"thinking": "More.", "text": "Words.", "calls": [{"name": "edit", "raw": json.dumps(
                {"path": "b", "edits": [{"oldText": "1", "newText": "2"}]})}], "results": [{"content": "ok"}]},
            {"thinking": "End.", "text": "Bye.", "stop": "end_turn"},
        ], "description": "Another made-up ticket.\n", "instructions": "Other made-up instructions.\n"}, name="other")
        other_text = {text_of(other, span) for span in other["spans"] if span["kind"] in MARKUP_KINDS}
        self.assertEqual(template_text, other_text)
        self.assertEqual(record["fixed_text"], other["fixed_text"])

    def test_the_spans_say_who_wrote_what(self):
        record, _ = self.convert(TWO_CALLS)
        kinds = {span["kind"] for span in record["spans"]}
        self.assertEqual(kinds, {"prompt_markup", "tools", "system_fixed", "instructions", "system_rest",
                                 "description", "thinking", "turn_markup", "call_name", "param_name", "param_value",
                                 "tool_result", "answer"})
        self.assertEqual(text_of(record, spans_of(record, "system_fixed")[0]), FIXED.system_before)
        self.assertEqual(text_of(record, spans_of(record, "instructions")[0]),
                         "Complete the made-up task.\nTask details: {}\n")
        self.assertEqual(len(spans_of(record, "tools")), 4)
        for turn in record["turns"]:
            inside = [s for s in record["spans"] if turn["start"] <= s["start"] and s["end"] <= turn["end"]]
            self.assertTrue(all(s["kind"] in TEACHER_KINDS + ("turn_markup",) for s in inside))
            self.assertEqual(sum(s["end"] - s["start"] for s in inside), turn["end"] - turn["start"])
            self.assertEqual(record["text"][turn["end"] - len("<|im_end|>"):turn["end"]], DEFAULTS["end_token"])
        sizes = record["sizes"]
        self.assertEqual(sizes["teacher_bytes"], sum(
            len(text_of(record, s).encode("utf-8")) for s in record["spans"] if s["kind"] in TEACHER_KINDS))
        self.assertEqual(record["checks"]["teacher_spans_holding_a_fixed_line"], 0)
        self.assertTrue(record["checks"]["system_fixed_found"])
        self.assertTrue(record["checks"]["instructions_found"])
        self.assertTrue(record["checks"]["description_file_found"])
        # the reply streams and the agent's own log agree with the stored request: no difference is counted
        self.assertEqual([name for name in record["checks"] if "differ" in name and name.startswith(
            ("stream_", "agent_log_"))], [])
        self.assertEqual(record["checks"]["param_order_stream"], 4)


class Switches(Case):
    def test_an_unknown_switch_or_value_is_refused(self):
        with self.assertRaises(ValueError):
            switches_module.resolve({"no_such_switch": "x"})
        with self.assertRaises(ValueError):
            switches_module.resolve({"trim": "sometimes"})
        self.assertEqual(switches_module.parse_assignments(['begin_token="<|x|>\\n"', "trim=c_isspace"]),
                         {"begin_token": "<|x|>\n", "trim": "c_isspace"})

    def test_trim(self):
        spec = {"turns": [
            {"thinking": "Print.", "calls": [{"name": "bash", "raw": '{"command":"cat a"}'}],
             "results": [{"content": "ends with a no-break space \n"}]},
            {"thinking": "Seen.", "text": "Done.", "stop": "end_turn"},
        ]}
        wide, _ = self.convert(spec, name="wide")
        narrow, _ = self.convert(spec, {"trim": "c_isspace"}, name="narrow")
        self.assertEqual(text_of(wide, spans_of(wide, "tool_result")[0]), "ends with a no-break space")
        self.assertEqual(text_of(narrow, spans_of(narrow, "tool_result")[0]), "ends with a no-break space ")
        self.assertEqual(wide["checks"]["texts_the_two_trim_rules_cut_differently"], 1)
        plain, _ = self.convert(TWO_CALLS, name="plain")
        self.assertEqual(plain["checks"]["texts_the_two_trim_rules_cut_differently"], 0)

    def test_begin_token(self):
        plain, _ = self.convert(PLAIN, name="plain")
        begun, _ = self.convert(PLAIN, {"begin_token": "<|endoftext|>"}, name="begun")
        self.assertEqual(begun["text"], "<|endoftext|>" + plain["text"])
        self.assertEqual(begun["spans"][0], {"kind": "begin_token", "start": 0, "end": 13, "byte_start": 0,
                                             "byte_end": 13})
        self.assertEqual(begun["turns"][0]["start"], plain["turns"][0]["start"] + 13)

    def test_param_order_and_numbers(self):
        spec = {"turns": [
            {"thinking": "Read.", "calls": [{"name": "read", "raw": '{"path":"a.ex","offset":10.0,"limit":2e1}'}],
             "results": [{"content": "x"}]},
            {"thinking": "Seen.", "text": "Done.", "stop": "end_turn"},
        ]}
        record, _ = self.convert(spec, name="stream")
        self.assertEqual(record["messages"][2]["tool_calls"][0]["function"]["arguments"],
                         '{"path":"a.ex","offset":10,"limit":20}')
        self.assertEqual(record["checks"]["numbers_rewritten"], 2)
        kept, _ = self.convert(spec, {"integral_floats": "keep"}, name="keep")
        self.assertEqual(kept["messages"][2]["tool_calls"][0]["function"]["arguments"],
                         '{"path":"a.ex","offset":10.0,"limit":20.0}')
        by_name, _ = self.convert(spec, {"param_order": "sorted"}, name="sorted")
        self.assertEqual([text_of(by_name, s) for s in spans_of(by_name, "param_name")], ["limit", "offset", "path"])
        self.assertEqual(by_name["turns"][0]["param_order"], ["sorted"])

    def test_json_switches_change_only_values_written_as_json(self):
        raw = json.dumps({"path": "a.ex", "edits": [{"oldText": "<ż>", "newText": "&'"}]}, ensure_ascii=False)
        spec = {"turns": [
            {"thinking": "Edit ż.", "calls": [{"name": "edit", "raw": raw}], "results": [{"content": "ok ż <>"}]},
            {"thinking": "Seen.", "text": "Done.", "stop": "end_turn"},
        ]}
        plain, _ = self.convert(spec, name="plain")
        ascii_only, _ = self.convert(spec, {"json_ensure_ascii": "true"}, name="ascii")
        html, _ = self.convert(spec, {"json_escape_html": "true"}, name="html")
        tight, _ = self.convert(spec, {"json_item_separator": ",", "json_key_separator": ":"}, name="tight")

        def value(record):
            return text_of(record, next(s for s in record["spans"] if s.get("written_as_json")))

        self.assertEqual(value(plain), '[{"oldText": "<ż>", "newText": "&\'"}]')
        self.assertEqual(value(ascii_only), '[{"oldText": "<\\u017c>", "newText": "&\'"}]')
        self.assertEqual(value(html), '[{"oldText": "\\u003cż\\u003e", "newText": "\\u0026\\u0027"}]')
        self.assertEqual(value(tight), '[{"oldText":"<ż>","newText":"&\'"}]')
        for record in (ascii_only, html, tight):
            self.assertEqual(text_of(record, spans_of(record, "tool_result")[0]), "ok ż <>")
            self.assertEqual(text_of(record, spans_of(record, "thinking")[0]), "Edit ż.")
        self.assertNotEqual(plain["fixed_text"]["sha256"], tight["fixed_text"]["sha256"])  # the tool lines change

    def test_template_variables(self):
        low, _ = self.convert(TWO_CALLS, {"reasoning_effort": "low"}, name="low")
        plain, _ = self.convert(TWO_CALLS, name="plain")
        self.assertNotEqual(low["text"], plain["text"])
        self.assertEqual(low["text"][low["spans"][1]["start"]:], plain["text"][plain["spans"][1]["start"]:])
        same, _ = self.convert(TWO_CALLS, {"enable_thinking": "true", "preserve_thinking": "true",
                                           "reasoning_effort": "xhigh"}, name="same")
        self.assertEqual(same["text"], plain["text"])
        # a session has one user message, so dropping the thinking before the last user message changes nothing
        dropped, _ = self.convert(TWO_CALLS, {"preserve_thinking": "false"}, name="dropped")
        self.assertEqual(dropped["text"], plain["text"])
        # with a later user message the earlier thinking is dropped: not one text that only grows, so refused
        messages = copy.deepcopy(plain["messages"]) + [
            {"content": [{"text": "A made-up second question.", "type": "text"}], "role": "user"},
            {"content": "A made-up second answer.", "reasoning_content": "Think again.", "role": "assistant"},
        ]
        Renderer(FIXED.template, DEFAULTS).layout(messages, FIXED.tools)
        with self.assertRaises(RenderError):
            Renderer(FIXED.template, switches_module.resolve({"preserve_thinking": "false"})).layout(
                messages, FIXED.tools)


class TheReadme(unittest.TestCase):
    def test_it_names_every_switch_and_every_kind_of_span(self):
        with open(os.path.join(TOOL, "README.md"), encoding="utf-8") as handle:
            readme = handle.read()
        for name in switches_module.SWITCHES:
            self.assertIn("`%s`" % name, readme)
        for kind in TEACHER_KINDS + MARKUP_KINDS + record_module.READ_KINDS + ("begin_token",):
            if kind != "system":  # a system text that does not split, which the converter refuses
                self.assertIn("`%s`" % kind, readme)
        self.assertIn(record_module.FORMAT, readme)


class Refusals(Case):
    def test_another_system_text_is_refused_without_quoting_it(self):
        spec = dict(PLAIN, system_text="A made-up system text that is not the agent's.\n")
        folder = self.session(spec)
        with self.assertRaises(ConversionError) as caught:
            convert(folder, os.path.join(self.root, "r.json"), None, None, FIXED)
        self.assertEqual(caught.exception.code, "system_text_differs")
        self.assertNotIn("made-up system text", str(caught.exception))
        self.assertEqual(caught.exception.facts["recorded"]["sha256"], FIXED.system_before_sha256)
        self.assertEqual(caught.exception.facts["recorded"]["characters"], 2664)
        self.assertFalse(os.path.exists(os.path.join(self.root, "r.json")))

    def test_other_tools_are_refused(self):
        tools = [{"description": "A made-up tool.", "input_schema": {"type": "object"}, "name": "guess"}]
        folder = self.session(dict(PLAIN, tools=tools))
        with self.assertRaises(ConversionError) as caught:
            convert(folder, None, None, None, FIXED)
        self.assertEqual(caught.exception.code, "tools_differ")
        self.assertNotIn("made-up tool", str(caught.exception))

    def test_a_character_that_cannot_be_written_is_refused(self):
        spec = {"ascii_json": True, "turns": [
            {"thinking": "Print.", "calls": [{"name": "bash", "raw": '{"command":"cat a"}'}],
             "results": [{"content": "half a character: \ud83d"}]},
            {"thinking": "Seen.", "text": "Done.", "stop": "end_turn"},
        ]}
        folder = self.session(spec)
        with self.assertRaises(ConversionError) as caught:
            convert(folder, os.path.join(self.root, "r.json"), None, None, FIXED)
        self.assertEqual(caught.exception.code, "text_not_utf8")
        self.assertFalse(os.path.exists(os.path.join(self.root, "r.json")))

    def test_the_check_notices_an_answer_that_starts_in_the_wrong_place(self):
        record, _ = self.convert(TWO_CALLS)
        changed = copy.deepcopy(record)
        changed["turns"][1]["start"] -= 1
        self.assertTrue(any("before answer 1" in problem for problem in verify(changed, None, FIXED)))

    def test_the_switch_table_lists_every_switch(self):
        table = switches_module.table().split("\n")
        self.assertEqual(table[0].split("\t")[0], "switch")
        self.assertEqual([line.split("\t")[0] for line in table[1:] if line], list(switches_module.SWITCHES))

    def test_a_block_the_converter_does_not_know_is_refused(self):
        request = frame("teacher_middle_request.frame.json")
        request = copy.deepcopy(request)
        request["messages"][1]["content"].insert(0, {"type": "redacted_thinking", "data": "x"})
        with self.assertRaises(ConversionError):
            bridge_request(request, FIXED, DEFAULTS)

    def test_the_check_notices_a_changed_record(self):
        record, data = self.convert(TWO_CALLS)
        changed = copy.deepcopy(record)
        changed["text"] = changed["text"].replace("cart tests", "cart test ", 1)
        self.assertTrue(verify(changed, None, FIXED))
        changed = copy.deepcopy(record)
        span = next(s for s in changed["spans"] if s["kind"] == "thinking")
        span["end"] += 1
        self.assertTrue(verify(changed, None, FIXED))
        changed = copy.deepcopy(record)
        changed["messages"][3]["content"] += "x"
        self.assertTrue(verify(changed, None, FIXED))
        changed = copy.deepcopy(record)
        thinking = next(s for s in changed["spans"] if s["kind"] == "thinking")
        changed["messages"][2]["reasoning_content"] = FIXED.system_before.split("\n")[0]
        self.assertTrue(verify(changed, None, FIXED))
        self.assertEqual(verify(record, data, FIXED), [])
        self.assertTrue(verify(record, data + b" ", FIXED))


if __name__ == "__main__":
    unittest.main()
