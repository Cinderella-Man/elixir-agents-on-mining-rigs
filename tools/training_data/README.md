# The converter: from a stored teacher session to a training record for Qwen3.8-27B

A stored session is what the task factory's engine wrote while the teacher solved one case: every request, every
reply stream and the agent's own log. The converter turns one stored session into one **record**:

1. the conversation as the list of messages the Elixir SWE Bench's server would have received for it;
2. the text the recorded chat template writes for those messages, byte for byte;
3. which stretches of that text the teacher wrote and which it only read.

Training computes the loss on the teacher's stretches only. The target is fixed by
[`docs/data/2026-11-12_target_text_qwen38_27b/`](../../docs/data/2026-11-12_target_text_qwen38_27b/README.md)
(registry E103): the template inside the bench's model file, the route the bench's agent speaks, and the 13
differences between that route and the one the teacher's sessions were recorded on. The plan this is step 3 of:
[sessions to training data](../../docs/research/finetuning/research_notes/sessions_to_training_data_qwen38_27b.md).
The first run, with its numbers: [`docs/data/2026-11-12_converter_qwen38_27b/`](../../docs/data/2026-11-12_converter_qwen38_27b/README.md).

## The rule: the converter adds no text of its own

Every byte of a record's text comes from one of three places:

- **the stored session:** the system text, the description, the teacher's thinking, calls and closing words, the
  tool results;
- **the recorded template:** the tokens, tags and line breaks around them, and the sentences of its system turn;
- **the recorded fixed text:** the agent's four tool definitions, in the bytes the bench's server receives.

The converter holds none of the template's text in its own source. It finds out which characters the template wrote
by rendering the template twice: once with the real messages, once with every piece of content replaced by a marker.
What stands between the markers is the template's. Putting the content back must give the first rendering, character
for character, or the conversion stops ([`render.py`](render.py)). Where an answer starts is found the same way: the
prompt that asks for answer *k* is the template's rendering of the messages before it, with its generation prompt.

It writes no thinking for an answer that has none, cuts nothing, and summarizes nothing.

## Files

| File | What |
|---|---|
| [`convert_session.py`](convert_session.py) | one stored session to one record |
| [`convert_sessions.py`](convert_sessions.py) | every session an index lists, with a table of the records |
| [`check_records.py`](check_records.py) | checks every record of a folder and prints the numbers per session |
| [`bridge.py`](bridge.py) | reads a stored attempt; moves it from the recorded route to the bench's route |
| [`render.py`](render.py) | renders the template; finds who wrote which character |
| [`record.py`](record.py) | builds the record: provenance, sizes, counts |
| [`switches.py`](switches.py) | the named switches and their defaults |
| [`verify.py`](verify.py) | the checks of one record |
| [`tests/`](tests/) | the tests, on made-up conversations only |

Needs Python 3.12 or newer and Jinja2 (3.1.6 was used). Nothing else. No model, no network, no GPU.

## Commands

The recorded template, tool definitions and fixed system text are read from this repository's target-text folder.
`TARGET_TEXT` names another copy of that folder; `TEMPLATE`, `TOOLS` and `SYSTEM_BEFORE` name single files.

```bash
# one session
python3 -I tools/training_data/convert_session.py --attempt $ATTEMPT --out $OUT/record.json

# every kept session of an index (the raw-sessions repository's sessions.tsv), then the checks and the numbers
python3 -I tools/training_data/convert_sessions.py --index $SESSIONS/sessions.tsv --root $SESSIONS --kept yes --out $OUT
python3 -I tools/training_data/check_records.py --records $OUT --out $TABLES

# the tests
python3 -I tools/training_data/tests/test_converter.py
```

`$ATTEMPT` is the engine's folder of one attempt (`request-NNNN.json`, `response-NNNN.sse`, `pi-events.jsonl`,
`attempt.json`, with `run.json` one level up). `--switch name=value` changes a switch; it may be repeated.

A session that cannot be converted gives no record. The reason is printed with hashes, lengths and counts, never with
the session's text, and the exit code is 2. `check_records.py` exits with 1 when a check fails.

## What is read

| File of the attempt | Used for |
|---|---|
| the last `request-NNNN.json` | the conversation up to the last reply: the system text, the tool definitions, every message |
| every `response-NNNN.sse` | the order in which the teacher wrote each call's parameters; why each reply stopped; the last reply, which is in no request |
| `pi-events.jsonl` (its closing `agent_end` list) | a second record of the whole conversation, compared with the first; the agent's reading of a cut-off call in the last reply |
| `attempt.json` | how the attempt ended, whether its patch passed, the agent's version |
| `instructions.md`, `prompt.md` | where the instruction text and the description sit inside the text |
| `run.json`, one level up | the run's id |

Every file read is listed in the record with its size and SHA-256. Nothing is written into a stored session.

## The record

One JSON object on one line, UTF-8, with the keys sorted at every level (the way the bench's engine writes a
request), and a line break at the end. The record's hash is the SHA-256 of that file. The same session, the same
recorded files and the same switches give the same bytes on every machine: the record holds no time, no path of the
machine and no software version.

| Field | What it holds |
|---|---|
| `format` | `teacher-session-training-record/1` |
| `session.case`, `session.run` | the case's id and the run's id, from the attempt's own files |
| `session.project`, `session.kept` | the project and whether the session was kept, as the caller named them (`--project`, `--kept`, or the index's columns) |
| `session.status`, `session.stop_reason`, `session.graded_passed` | how the attempt ended and whether its patch passed, from `attempt.json` |
| `session.agent` | the agent's package, version and lock-file hash |
| `session.model` | the teacher's name as the stored request has it |
| `session.last_request`, `session.replies` | the number of the last request, and how many reply streams the attempt holds |
| `session.ends_with` | `answer` when the record ends with the model's last reply; `request` when the last request has no reply |
| `provenance.converter.version` | a SHA-256 over the converter's four source files (`bridge.py`, `render.py`, `record.py`, `switches.py`); `files` lists each one's hash |
| `provenance.template` | the template's file name, size and SHA-256 |
| `provenance.tools`, `provenance.system_fixed` | the recorded tool-definition file and fixed system text, by name and SHA-256 |
| `provenance.switches` | the value of every switch |
| `provenance.inputs` | every file read: its path inside the run's folder, its size, its SHA-256 |
| `tools` | the four tool definitions as the bench's server receives them |
| `messages` | the conversation on the bench's route (below) |
| `text` | what the template writes for `messages` and `tools` |
| `text_sha256` | the SHA-256 of `text` as UTF-8 |
| `fixed_text` | `characters`, `bytes` and `sha256` of the start of the text up to the end of the agent's fixed system text: the template's system lines, the tool lines and the agent's fixed text. It is the same in every session |
| `template_tags` | the tags and special tokens the template itself wrote in this text |
| `spans` | every character of `text` exactly once, in order (below) |
| `turns` | one entry per answer (below) |
| `sizes` | `by_kind`: spans, characters and bytes per kind of span; `text_*`, `teacher_*`, `turn_markup_*` and `read_*` in characters and bytes |
| `counts` | `messages`, `turns`, `tool_calls`, `tool_results`, `tool_results_marked_error`, `answers_without_thinking`, `answers_with_text`, `answers_cut_by_the_reply_limit`, `calls_by_tool`, `longest_tool_result_bytes`, `longest_thinking_bytes` |
| `checks` | what the conversion counted while it compared its sources (below) |

The request's other fields (`model`, `seed`, `max_tokens`, `stream`, `stream_options`) are part of no prompt and are
not in the record.

### `messages`

| Role | Keys | From |
|---|---|---|
| `system` | `content`: one text | the stored request's system text, unchanged |
| `user` (the description) | `content`: a list of one part, `text` and `type` | the first message, its cache mark dropped |
| `assistant` | `content`: the answer's text, or null; `reasoning_content`: the thinking; `tool_calls`: a list of `{"function": {"arguments", "name"}, "id", "type": "function"}` | one stored answer. `arguments` is JSON without spaces, the keys in the order the teacher wrote them |
| `tool` | `content`: one text; `tool_call_id` | one tool result |

An answer without thinking has no `reasoning_content` key. An answer without calls has no `tool_calls` key.

### `spans`

Each span has `kind`, `start` and `end` (characters of `text`, the end not included), `byte_start` and `byte_end`
(bytes of the UTF-8 text), and where it came from: `message` (its place in `messages`), `turn` (the answer's number),
`call` (the call's number in its answer), `param` (the parameter's name), `tool` (the tool's number).

| Kind | Whose | What |
|---|---|---|
| `thinking` | the teacher's | an answer's thinking |
| `answer` | the teacher's | an answer's text: words beside a call, or the closing words |
| `call_name` | the teacher's | the name of the tool a call names |
| `param_name` | the teacher's | a parameter's name |
| `param_value` | the teacher's | a parameter's value. `written_as_json: true` marks a value that is not text (a number, a list): the teacher's value in the template's JSON spelling |
| `turn_markup` | the template's | the template's characters inside an answer: the end of the thinking block, the tags of a call, the end token. The student writes them when it is tested |
| `prompt_markup` | the template's | the template's characters everywhere else: turn starts, the system turn's own sentences, the tags around a tool result, the start of the thinking block |
| `tools` | read | one tool definition, as the template writes it |
| `system_fixed` | read | the agent's fixed system text |
| `instructions` | read | the engine's instruction text for the case |
| `system_rest` | read | the rest of the system text: the project's guide for coding agents, the working folder |
| `description` | read | the case's description in the agent's file wrapper |
| `tool_result` | read | one tool result |
| `user` | read | a later user message (no session has one) |
| `begin_token` | the switch's | the text of the `begin_token` switch, when it is set |

A span of a text the template trims carries `cut_by_trim`: how many characters the template removed at its ends. A
text that is empty after trimming has no span.

### `turns`

| Field | What |
|---|---|
| `turn`, `message` | the answer's number, and its place in `messages` |
| `start`, `end`, `byte_start`, `byte_end` | the stretch the student writes when it is tested: from the end of the prompt that asks for the answer to the end of the turn's end token |
| `thinking` | false for an answer without thinking |
| `calls` | the number of calls |
| `stop_reason` | why the teacher's reply stopped, in the stored stream's word: `tool_use`, `end_turn`, `max_tokens` |
| `param_order` | per call, where the order of its parameters came from: `stream`, `sorted`, `request_one_key`, `request_sorted` or `agent_log_cut_call` (difference 9 below) |
| `source` | `request` for an answer the last request holds; `reply` for the last reply |

**The loss.** The stretches of `turns` are where the loss is computed: thinking, answer text, calls and the end
token, with the template's own characters between them, which the student must write too. Everything outside them
is read. `sizes.teacher_bytes` counts the teacher's own spans, `sizes.turn_markup_bytes` the template's characters
inside the answers, `sizes.read_bytes` the rest; the three add up to `sizes.text_bytes`.

An answer whose `stop_reason` is `max_tokens` was cut off by the reply limit. The template still closes its call and
its turn, so its stretch ends in characters the teacher did not reach. Such answers are counted
(`counts.answers_cut_by_the_reply_limit`), not removed.

### `checks`

Counts made during the conversion. A count that is zero is left out, except those marked "always".

| Name | What it counts |
|---|---|
| `param_order_stream`, `param_order_sorted`, `param_order_request_one_key`, `param_order_request_sorted`, `param_order_agent_log_cut_call` | calls by where their parameter order came from |
| `stream_thinking_differs`, `stream_text_differs`, `stream_calls_differ` | answers of the stored request that differ from the reply stream that wrote them |
| `stream_unknown_events` | stream events the converter does not know |
| `replies_not_matched` | answers of the stored request for which no reply stream was found |
| `agent_log_system_differs`, `agent_log_answer_count_differs`, `agent_log_thinking_differs`, `agent_log_text_differs`, `agent_log_calls_differ`, `agent_log_tool_results_differ`, `agent_log_tool_result_count_differs` | differences between the conversation and the agent's own log of it |
| `agent_log_error_messages_left_out` | empty error messages of the agent's log, which no model wrote |
| `tool_results_after_the_last_reply` | tool results the agent made after the last reply; the model never saw them and they are not in the record |
| `tool_results_out_of_order` | tool results that do not follow their calls in order |
| `no_last_reply` | 1 when the last request has no reply |
| `signatures_dropped` | thinking blocks that carried a signature |
| `numbers_rewritten` | numbers changed by the `integral_floats` switch |
| `characters_cut_by_trim` (always) | characters the template's trim removed, in all texts |
| `texts_the_two_trim_rules_cut_differently` (always) | texts for which the `trim` switch changes the result |
| `json_values`, `json_values_with_non_ascii`, `json_values_with_html_characters` (always) | parameter values written as JSON, and those for which `json_ensure_ascii` or `json_escape_html` changes the result |
| `tool_lines_with_non_ascii`, `tool_lines_with_html_characters` (always) | the same for the four tool lines |
| `teacher_spans_holding_a_template_tag`, `read_spans_holding_a_template_tag` (always) | spans whose text holds one of `template_tags` |
| `teacher_spans_holding_a_fixed_line` (always) | spans of the teacher's that hold a line of the fixed text of 40 characters or more |
| `system_fixed_found`, `instructions_found`, `description_file_found` (always) | whether the agent's fixed text, `instructions.md` and `prompt.md` were found where they belong |

## The 13 differences, and what the converter does with each

The numbers are those of the target-text folder's section 5.

| # | Part | What the converter does |
|---:|---|---|
| 1 | The system text's place | moves the text of the request's `system` part into the first message, role `system`. The text must start with the agent's recorded fixed text, or the session is refused |
| 2 | Cache marks | drops every `cache_control` key |
| 3 | The description's message | keeps the one text part with the keys `text` and `type` |
| 4 | Tool definitions | re-shapes the session's definitions, requires them to equal the recorded file's as values, and uses the recorded file's object, whose keys are in the bench's order |
| 5 | Thinking | moves the block's text into `reasoning_content`; the signature is dropped and counted |
| 6 | A reply without thinking | kept as it is, with no `reasoning_content` key. The template writes empty thinking lines for it. Counted per session |
| 7 | Answer text beside calls | moves the text block into `content`; null when there is none |
| 8 | A tool call | makes an entry of `tool_calls` whose `arguments` is the input object as JSON without spaces |
| 9 | The order of a call's parameters | takes it from the reply stream when the stream's value equals the stored request's (`stream`). Otherwise the stored, sorted order is used: `request_one_key` when no object in the value has two keys, so no order can be wrong; `request_sorted` when it can. A cut-off call in the last reply, which is in no request, takes the agent's own reading from its log (`agent_log_cut_call`) |
| 10 | Call ids | keeps the teacher's; the template writes no id |
| 11 | Tool results | one `tool` message per result, in the order of the calls |
| 12 | The error mark | dropped and counted; the error is in the result's text |
| 13 | What only the server adds | never written by the converter: the template makes it |

Not bridged, because no text may be written into a session: a bench case's instruction text has requirement lines
and a filled task-details object where a training case has an empty line and `{}`.

**One correction to the target-text folder.** It says the agent's event log keeps the teacher's own order of a
call's parameters. In the stored files it does not: the engine writes every object of that log with its keys in
alphabetical order. Counted on the 16 stored sessions of the first run: all 5,420 lines of the logs have every key
in alphabetical order, and the 10 calls of 736 that the teacher wrote in another order are alphabetical there. The
reply streams are the only record of the order.

## The switches

Every place where the target-text folder leaves a choice open is a named switch, with the template's own behaviour
as its default. A record stores all of them. The first six groups are that folder's six open points, which only a
live server with the model file can settle (the proof run, registry E105).

| Switch | Default | Other values | What it decides | Open point |
|---|---|---|---|---|
| `begin_token` | empty | any text | text put before the first turn. The template writes none; the server reported the begin token `<\|endoftext\|>` | 1 |
| `trim` | `jinja2` | `c_isspace` | which characters the template's `trim` removes at the ends of every text. `jinja2`: all Unicode white space. `c_isspace`: space, tab, line feed, vertical tab, form feed, carriage return, which is what the server's source does | 1 |
| `json_item_separator` | `, ` | any text | the text between two items where the template writes JSON: the tool lines, and parameter values that are not text | 1 |
| `json_key_separator` | `: ` | any text | the text after a key there | 1 |
| `json_ensure_ascii` | `false` | `true` | whether non-ASCII characters in such JSON are written as `\uXXXX` | 1 |
| `json_escape_html` | `false` | `true` | whether `<`, `>`, `&` and `'` in such JSON are written as `\uXXXX`, as Jinja2's stock filter does | 1 |
| `jinja_trim_blocks`, `jinja_lstrip_blocks` | `true` | `false` | the template engine's two white-space settings, which decide the white space between the template's blocks | 1 |
| `enable_thinking` | `unset` | `true`, `false` | the template variable of that name. Unset: the template's default, thinking on | 2 |
| `reasoning_effort` | `unset` | `xhigh`, `high`, `medium`, `low` | the template variable of that name. Unset: the template's default, `xhigh`, with its sentence at the top of the system turn | 2 |
| `preserve_thinking` | `unset` | `true`, `false` | the template variable of that name. With `false` the template drops the thinking of answers before the last user message. A session has one user message, so its text is the same either way | 2 |
| `param_order` | `stream` | `sorted` | the order of a call's parameters: the teacher's own, or the alphabetical order of the stored requests | 4 |
| `integral_floats` | `as_integers` | `keep` | a number the teacher wrote with a fraction of zero (`120.0`): written `120`, as the agent's `JSON.stringify` does before the server sees it, or kept | 4 |
| `strip_generation_tags` | `true` | `false` | remove the maker's generation tags before rendering. They write nothing, and Jinja2 does not know them | 6 |
| `no_thinking_field` | `omit` | `empty`, `null` | the `reasoning_content` key of an answer without thinking. The text is the same for all three; the bench's records hold no such answer | none: the message's shape only |
| `final_tool_calls_field` | `omit` | `empty` | the `tool_calls` key of an answer without calls. The text is the same; the bench's records hold no such message | none: the message's shape only |
| `end_token` | `<\|im_end\|>` | any text | the token that ends a turn, as the server reported it. An answer's stretch ends with it | none: recorded |

The template itself and the tool definitions are inputs (`TEMPLATE`, `TOOLS`), stored in the record by hash. A tuned
model file with another template (open point 6), or tool lines in another key order (open point 1), is a conversion
with another input file.

**Open points with no switch,** because nothing in the text can be changed until a server shows what differs:

- **3, the server's own word on the format.** The converter follows the target-text folder: the server applies the
  template directly.
- **5, why the server's cache missed one token after most replies.** That is about tokens, not text.
- **4, what the model writes raw for a call with a number.** The two switches above cover the two readings the
  records allow; another spelling of numbers would need a new switch.

**What the records say about each switch** is in each record's `checks`: for example, a session in which
`texts_the_two_trim_rules_cut_differently` is 0 gives the same text under both values of `trim`.

## What is refused

| Code | When |
|---|---|
| `system_text_differs` | the system text does not start with the agent's recorded fixed text. Both texts' lengths and hashes are printed |
| `tools_differ`, `tool_shape` | the session's tool definitions are not the recorded four |
| `system_shape`, `user_shape`, `assistant_shape`, `tool_result_shape`, `call_shape`, `message_role` | a message has a shape the target-text folder does not describe: a block of another kind, two thinking blocks, text after a call, a result that is not one text |
| `cut_call_without_value` | the last reply's call is cut off and the agent's log does not hold it |
| `no_request` | the folder holds no request |
| `text_not_utf8` | the text holds a character that cannot be written as UTF-8 |
| `RenderError` | the template refused the conversation, did not write a piece of content exactly once, or the conversation is not one text that only grows |

## What it does not do

- **Sessions longer than the training window are not cut.** That decision is registry E104; `sizes` and `counts`
  give it the numbers.
- **It does not decide what is training data.** It converts any session; only kept sessions that passed the scans
  of [the dataset's rules](../../docs/dataset_rules.md) are trained on.
- **It counts characters and bytes, not tokens.** Token counts need the student's tokenizer.
- **The text is Jinja2's rendering, not the server's.** That is the target-text folder's own limit; the switches
  are where a difference found on a live server is set.

## Tests

[`tests/test_converter.py`](tests/test_converter.py), 30 tests. Every conversation in them is made up
([`tests/fake_session.py`](tests/fake_session.py) writes it in the engine's own files and shapes); the only real
text is the recorded fixed text.

- **The byte test.** For the bench's two recorded frames the converter's text equals the stored rendering and the
  target-text folder's own renderer (`run/render_frame.py`, loaded as it is). For the teacher's two frames the
  bridged messages give the same bytes under both renderers, and the fixed text at the start equals the bench's. The
  three recorded templates write the same text.
- **Made-up sessions:** a plain exchange; several calls in one answer, with the teacher's parameter order; an
  answer without thinking; a tool result and a call with characters that look like template syntax, tags, quotes and
  non-ASCII text; empty and blank tool results; a tool result of 400,000 characters; a session that ends at a limit
  with a cut-off answer; a session whose last request has no reply.
- **The record:** the messages come back unchanged from the file; the same session in another folder gives the same
  bytes; the stored session's files are not changed; the provenance lists every file read with its hash; every
  character has a source; the check notices a changed text, span or message.
- **The switches:** each changes what it names and nothing else; unknown names and values are refused.
- **Refusals:** another system text and other tools are refused without quoting them.
