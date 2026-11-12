# The converter's first run: 13 kept teacher sessions as training records for Qwen3.8-27B (Q539)

The converter ([`tools/training_data/`](../../../tools/training_data/README.md)) turns a stored teacher session into
a training record: the messages the Elixir SWE Bench's server would have received, the text the recorded chat
template writes for them, and which stretches of that text the teacher wrote. This folder holds its first run: the
13 kept sessions of `axelclark/ex338`, and the 3 sessions of that project that were not kept, converted only to see
that the converter does not fail on them.

**Only numbers are here.** No session text, no case text and no record: the records stay on the data-mining machine
until the sessions have passed the scans of [the dataset's rules](../../dataset_rules.md).

Registry row: [Q539](../../../experiments.md). The target it converts to:
[the target text](../2026-11-12_target_text_qwen38_27b/README.md) (E103). The plan this is step 3 of:
[sessions to training data](../../research/finetuning/research_notes/sessions_to_training_data_qwen38_27b.md).

## Result

1. **It works on all 13 kept sessions.** 13 of 13 converted, and every record passed every check: the template's
   text built again from the record's messages is the stored text; the spans cover the text exactly once; the text
   before each of the 382 answers is the prompt the template writes for the request that asks for it; no span of
   the teacher's holds fixed text; the fixed text at the start (6,733 bytes, SHA-256 `4296c7bd…`) is the same in all
   13. The 3 sessions that were not kept converted and passed the same checks.
2. **The teacher wrote 827,364 of the 2,867,960 bytes (28.8 %).** It only read 1,990,973 bytes (69.4 %). The other
   49,623 bytes (1.7 %) are the template's own characters inside the answers: the tags of a call, the end of the
   thinking block, the end token. The student must write those too, so the loss covers 876,987 bytes (30.6 %).
3. **The byte test is green for all four recorded frames,** and the three recorded template files write the same
   text for all 13 sessions.
4. **The same input gives the same bytes:** the 13 records made a second time, by another Python (3.12.16 against
   3.14.4), are the same files, byte for byte.
5. **Most open switches change nothing in these 13 sessions.** The two rules for trimming give the same text in 13 of
   13; so do both template-engine white-space settings, both values of `preserve_thinking`, and the three shapes of
   an answer without thinking. What does change the text: the order of a call's parameters (6 of 13 sessions), the
   JSON spelling of the tool lines (13 of 13), a begin token (13 of 13), and a reasoning effort other than `xhigh`
   (13 of 13).
6. **Still open:** the six points of the target-text folder that need a live server. Each is now a named switch,
   or is listed as having none (below).

## The numbers per session

[`tables/kept/sessions.tsv`](tables/kept/sessions.tsv) has every column, with the full hashes and the same sizes in
characters.

| Case | Run | Answers | Tool calls | Answers without thinking | Bytes the teacher wrote | The template's bytes inside answers | Bytes only read | Text, bytes | Record's SHA-256 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| ex338-pr-1350 | 20261112-153206-f5d6163e | 65 | 87 | 1 | 180,935 | 8,966 | 341,530 | 531,431 | `e6e12e034ef0…` |
| ex338-pr-1390 | 20261112-151610-54d3f177 | 38 | 49 | 3 | 106,123 | 4,971 | 167,468 | 278,562 | `f46db13334cb…` |
| ex338-pr-1392 | 20261112-150900-3157aa83 | 21 | 25 | 1 | 39,536 | 2,429 | 83,320 | 125,285 | `1ed04e71c346…` |
| ex338-pr-1394 | 20261112-160105-8e8bc313 | 32 | 43 | 5 | 59,297 | 4,260 | 172,725 | 236,282 | `24dca656eeba…` |
| ex338-pr-1395 | 20261112-145221-bbcf6549 | 14 | 17 | 1 | 23,076 | 1,735 | 64,849 | 89,660 | `9b5185286106…` |
| ex338-pr-1411 | 20261112-144837-26fdf2e0 | 13 | 17 | 1 | 10,152 | 1,715 | 55,804 | 67,671 | `bbcf95a304ce…` |
| ex338-pr-1450 | 20261112-140710-417194c7 | 20 | 24 | 0 | 28,095 | 2,576 | 70,530 | 101,201 | `5c2ffe4dc364…` |
| ex338-pr-1452 | 20261112-131816-8c1b102a | 31 | 48 | 1 | 83,565 | 4,620 | 251,941 | 340,126 | `b9ea9754ab1b…` |
| ex338-pr-1457 | 20261112-130557-011a1bb0 | 41 | 44 | 0 | 61,138 | 4,786 | 157,886 | 223,810 | `b4a992245dc6…` |
| ex338-pr-1458 | 20261112-125647-9e23dbf9 | 19 | 23 | 0 | 43,096 | 2,183 | 174,100 | 219,379 | `def7bd6c4de6…` |
| ex338-pr-1460 | 20261112-123709-68fbd7b4 | 50 | 60 | 4 | 122,463 | 6,236 | 240,168 | 368,867 | `da65983265c9…` |
| ex338-pr-1461 | 20261112-123224-21ff4ec2 | 12 | 16 | 1 | 19,190 | 1,700 | 63,400 | 84,290 | `ad50d29fa1b1…` |
| ex338-pr-1463 | 20261112-122138-217eee81 | 26 | 36 | 1 | 50,698 | 3,446 | 147,252 | 201,396 | `26157d2d0c8c…` |
| **All 13** | | **382** | **489** | **19** | **827,364** | **49,623** | **1,990,973** | **2,867,960** | |

- An answer is one reply of the teacher: a model call. The 13 sessions end with a closing answer each; none was cut
  off by the reply limit.
- The answers without thinking are kept as they are; no thinking is written for the teacher. The template writes
  empty thinking lines for them. Whether they are trained on is not decided here: each is marked in its record
  (`turns[].thinking` is false).
- The 13 records are 6,819,245 bytes together; a record holds the messages and the text, so the conversation twice.

### Whose text it is

[`tables/kept/kinds.tsv`](tables/kept/kinds.tsv) has the same per session.

| Kind of span | Whose | Spans | Bytes | Share of the text |
|---|---|---:|---:|---:|
| tool results | read | 489 | 1,777,617 | 62.0 % |
| thinking | the teacher's | 363 | 538,705 | 18.8 % |
| parameter values | the teacher's | 667 | 271,966 | 9.5 % |
| the rest of the system text (the project's guide, the working folder) | read | 13 | 55,425 | 1.9 % |
| the template's characters outside the answers | the template's | 962 | 53,511 | 1.9 % |
| the template's characters inside the answers | the template's | 2,218 | 49,623 | 1.7 % |
| the four tool definitions | read | 52 | 38,324 | 1.3 % |
| the agent's fixed system text | read | 13 | 34,632 | 1.2 % |
| the descriptions, in the agent's wrapper | read | 13 | 20,729 | 0.7 % |
| the instruction texts | read | 13 | 10,735 | 0.4 % |
| answer text (the closing words of each session) | the teacher's | 13 | 10,486 | 0.4 % |
| parameter names | the teacher's | 667 | 4,249 | 0.1 % |
| tool names | the teacher's | 489 | 1,958 | 0.1 % |
| **All** | | | **2,867,960** | |

The longest tool result is 31,662 bytes (ex338-pr-1350). The template's trim removed 757 characters in all, at the
ends of texts.

### What the conversion counted while it compared its sources

[`tables/kept/checks.tsv`](tables/kept/checks.tsv), summed in [`tables/kept/summary.json`](tables/kept/summary.json).

| Check | In the 13 sessions |
|---|---:|
| calls whose parameter order was read from the reply stream | 489 of 489 |
| answers of a stored request that differ from the reply stream that wrote them | 0 |
| differences between the conversation and the agent's own log of it | 0 |
| spans of the teacher's that hold a tag or special token of the template | 0 |
| spans of the teacher's that hold a line of the fixed text | 0 |
| read spans (descriptions, tool results, system text) that hold a tag or special token of the template | 0 |
| texts the two trim rules would cut differently | 0 |
| parameter values the template writes as JSON (numbers, the lists of an `edit` call) | 176 |
| of them with non-ASCII characters | 1 |
| of them with `<`, `>`, `&` or `'` | 60 |
| tool lines with `<`, `>`, `&` or `'` | 1 of 4, in every session |

## What each switch changes

The 13 sessions converted again with one switch moved, or with another template file, against the first run:
[`tables/switch_effects.tsv`](tables/switch_effects.tsv). Every one of these conversions passed the checks. The
switches, their defaults and what settles each: [`tables/switches.tsv`](tables/switches.tsv).

| Change | Sessions whose text changes, of 13 | Text of the 13, bytes |
|---|---:|---:|
| the first run (every switch at its default) | | 2,867,960 |
| `trim=c_isspace` | 0 | 2,867,960 |
| `param_order=sorted` | 6 | 2,867,960 |
| `integral_floats=keep` | 0 | 2,867,960 |
| `json_ensure_ascii=true` | 1 | 2,867,966 |
| `json_escape_html=true` | 13 | 2,873,590 |
| `json_item_separator=,` | 13 | 2,867,222 |
| `json_key_separator=:` | 13 | 2,866,806 |
| `begin_token=<\|endoftext\|>` | 13 | 2,868,129 |
| `enable_thinking=true` | 0 | 2,867,960 |
| `reasoning_effort=xhigh` | 0 | 2,867,960 |
| `reasoning_effort=high` | 0 | 2,867,960 |
| `reasoning_effort=medium` | 13 | 2,865,243 |
| `reasoning_effort=low` | 13 | 2,867,037 |
| `preserve_thinking=true` | 0 | 2,867,960 |
| `preserve_thinking=false` | 0 | 2,867,960 |
| `jinja_trim_blocks=false` | 0 | 2,867,960 |
| `jinja_lstrip_blocks=false` | 0 | 2,867,960 |
| `no_thinking_field=empty` | 0 | 2,867,960 |
| `no_thinking_field=null` | 0 | 2,867,960 |
| `final_tool_calls_field=empty` | 0 | 2,867,960 |
| the maker's template of 2026-11-07, its generation tags removed | 0 | 2,867,960 |
| the maker's template of 2026-08-13 | 0 | 2,867,960 |

## What is still open, and what settles it

The target-text folder lists six points that only a server with the bench's model file can settle (its section 6).
The proof run (E105) settles them. For each: the switch, its default, and how much of these 13 sessions depends on
it.

| # | Open point | Switch and default | In these 13 sessions |
|---:|---|---|---|
| 1 | Is a begin token put before the text? | `begin_token`, empty | the first bytes of all 13 |
| 1 | How are the tool lines written: spacing, `<`, `>`, `'`, non-ASCII? | `json_item_separator` `, `, `json_key_separator` `: `, `json_escape_html` false, `json_ensure_ascii` false | the four tool lines of all 13, and 176 parameter values; one tool line holds an apostrophe |
| 1 | In what order are a tool line's keys? | no switch: the tool definitions are an input file. The recorded file has the bench's order | the four tool lines of all 13 |
| 1 | Which characters does the server trim at the ends of a text? | `trim`, `jinja2` | nothing: both rules give the same 13 texts |
| 1 | The white space between the template's blocks | `jinja_trim_blocks`, `jinja_lstrip_blocks`, both true | nothing: the template sets its own white space, and both settings give the same 13 texts |
| 2 | Does the server's preset turn thinking on, and with which effort? | `enable_thinking` unset, `reasoning_effort` unset: the template's defaults, on and `xhigh` | one sentence at the top of all 13. `medium` has no sentence, `low` has another |
| 2 | Does the preset keep earlier thinking? | `preserve_thinking`, unset: kept | nothing: a session has one user message, so the template keeps every answer's thinking either way |
| 3 | The server's own word on the format | no switch: the converter follows the target-text folder, the template is applied directly | |
| 4 | What does the model write, raw, for a call with a number? | `param_order` `stream`, `integral_floats` `as_integers` | 6 sessions hold a call whose parameters the teacher wrote in another order than the alphabetical one; no number has a fraction |
| 5 | Why the server's cache missed one token after most replies | no switch: that is about tokens, not text | |
| 6 | Does a tuned model file's template write the same text? | the template is an input file; `strip_generation_tags` true | nothing under Jinja2: both of the maker's files give the same 13 texts |

Two more choices have no effect on the text, only on the shape of a message, because the bench's records hold no
example of either: an answer without thinking (`no_thinking_field`, the key is left out) and an answer without calls
(`final_tool_calls_field`, the key is left out).

**Not decided here, because they are training decisions:** whether the 19 answers without thinking carry loss
(registry Q540); how a session longer than the training window is cut (E104). The records give both the numbers.

**Not checked here:** token counts. The bench's records pair 1,177 requests with the server's exact prompt-token
count (the target-text folder, section 7); a check of this renderer against them needs the student's tokenizer and
has not been run.

## A correction to the target-text folder

It says the order in which the teacher wrote a call's parameters is kept in the reply streams and in the agent's
event log. In the stored files only the reply streams keep it. The engine writes every object of the event log with
its keys in alphabetical order: all 5,420 lines of the 16 sessions' logs, and the 10 calls of 736 that the teacher
wrote in another order are alphabetical there. The converter reads the order from the reply streams.

## The sessions that were not kept

Converted into a folder of their own, to see that the converter does not fail on them. They are never training data.
[`tables/not_kept/sessions.tsv`](tables/not_kept/sessions.tsv).

| Case | Run | Answers | Tool calls | Answers without thinking | Answers cut off by the reply limit | Text, bytes | Checks failed |
|---|---|---:|---:|---:|---:|---:|---:|
| ex338-pr-1394 | 20261112-145706-2c3a6c63 | 24 | 39 | 1 | 0 | 277,490 | 0 |
| ex338-pr-1446 | 20261112-141318-80795bd9 | 98 | 111 | 3 | 0 | 643,161 | 0 |
| ex338-pr-1451 | 20261112-133250-aad90564 | 82 | 97 | 7 | 2 | 582,732 | 0 |

ex338-pr-1451 ran out of its token budget. Two of its replies were cut off in the middle of a call. For the one
inside the session the stored request holds what the agent read of the call. The other is the last reply, which is
in no request: its call comes from the agent's log. The tool result the agent made after that last reply was never
shown to the model and is not in the record, and the agent's empty error message at the end is left out. All of
that is counted in [`tables/not_kept/checks.tsv`](tables/not_kept/checks.tsv).

## Files

| File | What |
|---|---|
| [`tables/kept/sessions.tsv`](tables/kept/sessions.tsv) | one row per kept session: answers, calls, sizes in bytes and characters, the record's and the text's SHA-256, failed checks |
| [`tables/kept/kinds.tsv`](tables/kept/kinds.tsv) | spans, characters and bytes per kind of span, per session and summed |
| [`tables/kept/checks.tsv`](tables/kept/checks.tsv) | each record's own counts |
| [`tables/kept/summary.json`](tables/kept/summary.json) | the sums, the one form of the fixed text, the converter's version |
| [`tables/kept/run.json`](tables/kept/run.json) | the converter's version and source hashes, the template's hash, every switch's value, the software |
| [`tables/not_kept/`](tables/not_kept/) | the same five files for the 3 sessions that were not kept |
| [`tables/switch_effects.tsv`](tables/switch_effects.tsv) | what each switch changes |
| [`tables/switches.tsv`](tables/switches.tsv) | the switches: default, other values, what each decides, what settles it |
| [`run/first_run.sh`](run/first_run.sh) | the tests, the two conversions and their checks |
| [`run/again_in_image.sh`](run/again_in_image.sh) | the second conversion with another Python, compared byte for byte |
| [`run/switch_effects.sh`](run/switch_effects.sh), [`run/switch_effects.py`](run/switch_effects.py) | the conversions with one switch moved |

The converter's version in these records is `b0da3dc57a3e…` ([`tables/kept/run.json`](tables/kept/run.json) lists
the hash of each of its four source files); the template is `12827f24…`.

## Commands

Paths come from the environment: `SRC` (a checkout of this repository), `SESSIONS` (the clone of the raw-sessions
repository), `OUT` and `OUT_NOT` (where the records go), `TABLES` (where the tables go), `WORK` (a folder of one's
own), `PACKAGES` (the folder that holds the machine's `jinja2` and `markupsafe` packages).

```bash
# the tests, the 13 kept sessions with their checks, then the 3 that were not kept
SRC=$SRC SESSIONS=$SESSIONS OUT=$OUT OUT_NOT=$OUT_NOT TABLES=$TABLES bash run/first_run.sh

# the 13 again with Python 3.12.16 in a container without network, compared byte for byte with the first run
SRC=$SRC SESSIONS=$SESSIONS OUT=$OUT WORK=$WORK PACKAGES=$PACKAGES bash run/again_in_image.sh

# the 13 again with one switch moved, 22 times
SRC=$SRC SESSIONS=$SESSIONS OUT=$OUT WORK=$WORK TABLES=$TABLES bash run/switch_effects.sh
```

Everything ran on the data-mining machine, which has no GPU, at the lowest priority: Python 3.14.4 with Jinja2
3.1.6; the second conversion in the image `python:3.12-slim-bookworm` (Python 3.12.16) with the machine's own Jinja2
3.1.6 mounted read only. Nothing was downloaded. No model was asked anything. The stored sessions were read and not
changed.

## Provenance and licence

- **The sessions:** this project's own, the teacher's first run
  ([`docs/data/2026-11-12_teacher_first_sessions/`](../2026-11-12_teacher_first_sessions/README.md)). Nothing of
  their text is in this folder.
- **The template, the tool definitions and the agent's fixed system text:** as recorded in
  [the target-text folder](../2026-11-12_target_text_qwen38_27b/README.md), with their licences there.
- **The tables and scripts:** this repository's own.
