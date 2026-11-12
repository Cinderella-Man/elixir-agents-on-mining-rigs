# The target text: what the bench's server shows Qwen3.8-27B, recorded before the converter is written (E103)

The training text must be, byte for byte, what the Elixir SWE Bench's server shows the tuned model. This folder
records that text's frame from the bench's own run of the untuned Qwen3.8-27B (Unsloth's UD-Q6_K_L file, seed 101,
7 of 20 cases, run `20261111-232701-52ed4580`), beside the frame of the teacher's recorded sessions. Everything was
read; nothing was run on the bench, no model was asked anything, and nothing of the bench was changed.

**Only the frame is here.** Every case description, requirement sentence, project file, command, command output
and model answer was replaced by a placeholder such as `<CASE TEXT>` before anything was saved. The fixed parts stay:
Pi 1.2.0's system text and tool definitions, the engine's instruction sentences, the wrappers, the template and the
special tokens. The hold-out rule is in [`docs/plan.md`](../../plan.md).

Registry row: [E103](../../../experiments.md). The plan this is step 1 of:
[sessions to training data](../../research/finetuning/research_notes/sessions_to_training_data_qwen38_27b.md).

## Result

1. **The template is not the maker's current file.** The bench's GGUF holds Unsloth's variant of the maker's
   template: 9,993 bytes, SHA-256 `12827f24b742ea4e80cdc12dbcf9622227056b9f797252a3149263d4f9aaadce`, the same in
   all 20 attempts' records and the hash in the bench's published result. The maker's current
   `chat_template.jinja` is 9,004 bytes, SHA-256 `af16f654…`. For a Pi conversation the three files (Unsloth's, the
   maker's current, the maker's earlier) write the same text: checked on the two frames here with Jinja2
   (section 1).
2. **Tool calls travel in the template's own form.** The model writes
   `<tool_call>`, `<function=NAME>`, `<parameter=NAME>` … and the server turns that into structured calls. The server
   build the bench used has a handler written for exactly this form and no generic JSON form at all (section 2).
   In 1,068 of the run's 1,157 follow-up calls the server took the model's previous reply from its cache, whole or
   all but one token, which it can only do when the template writes the reply back as the tokens the model produced.
3. **Pi's fixed text is the same on both routes.** The system text before the instruction text is the same 2,664
   characters in all 20 bench attempts and all 15 teacher attempts read; the four tool definitions have the same
   values; the file wrapper around the description and Pi's own words around tool output are the same.
4. **The converter's job is the envelope, not the text:** 13 differences, listed in section 5.
5. **Six things need a live server** (section 6). None of them was tried here.

## What was read

| Source | What | How much |
|---|---|---|
| The bench's run of Qwen3.8-27B (the maintainer's own records, with permission, read only, in place) | each attempt's `attempt.json`: the template line; one attempt's model block | 20 attempts |
| | recorded requests `request-NNNN.json` | 74: the first and the last of every attempt, and every request of three attempts (7, 13 and 20) |
| | the closing usage record of every reply stream `response-NNNN.sse` (numbers only) | 1,177 |
| | one reply stream's first and last events; how every reply ended | 1 and 1,177 |
| | one attempt's `pi-config.json` (Pi's settings) and its first usage record | 1 |
| The teacher's sessions (this project's own, on the data-mining machine, read only, the job still running) | recorded requests and reply streams; one attempt's `pi-config.json` | 15 attempts, 538 requests: a snapshot at 15:53 UTC on 2026-11-12 |
| The maker's repository `Qwen/Qwen3.8-27B` | `chat_template.jinja` at revisions `37561816e66b` (2026-11-07, current) and `8c0b3d30f3ae` (before it) | 2 files |
| The quantizer's repository `unsloth/Qwen3.8-27B-GGUF` at `4af51b3542f7` | the template in its GGUF metadata, as the Hub reports it | SHA-256 `12827f24…`, the bench's |
| llama.cpp's source at commit `7775ffb7e48f` (the server reported build `b1-7775ffb`) | chat formats, the template engine's `tojson`, the JSON type, the server's README | read, not run |
| The engine's gateway (`lib/eab/pi_gateway.ex`, `thinking.ex`, `model.ex`; the bench's own and [the factory's copy](../../../factory/README.md)) | what is sent to the server and what is recorded | the llama.cpp path is the same code in both |

**How the content was kept out.** The scripts in [`run/`](run/) read each request in memory and write only
placeholders, counts and hashes. The fixed text was saved only where it was the same bytes in every attempt read:
20 attempts of 12 projects for the bench, so nothing of one case or one project can be in it.

## 1. The template the server used

| File | Bytes | SHA-256 | From |
|---|---:|---|---|
| [`templates/bench_gguf_chat_template.jinja`](templates/bench_gguf_chat_template.jinja) | 9,993 | `12827f24b742ea4e80cdc12dbcf9622227056b9f797252a3149263d4f9aaadce` | the server's own report (`/props`), saved in every attempt's `attempt.json`; it is the template inside `Qwen3.8-27B-UD-Q6_K_L.gguf` |
| [`templates/maker_chat_template_2026-11-07.jinja`](templates/maker_chat_template_2026-11-07.jinja) | 9,004 | `af16f654968d47d09a6c604e00370b12dbc21f76456f59c9e98b82e84d9f6375` | `Qwen/Qwen3.8-27B`, revision `37561816e66b5b9153b1b64c10968c18c1e6f4a0`, "Add a response template and generation tags (#236)" |
| [`templates/maker_chat_template_2026-08-13.jinja`](templates/maker_chat_template_2026-08-13.jinja) | 8,952 | `c3cf9e34abf4f9e36c2d72165aa9c132d3e2a725b6c2586aaa3a8af9d7a81041` | the same repository, revision `8c0b3d30f3ae96f5c7f774de704bf0ada83e422a` (the file as uploaded on 2026-08-13) |

**The bench's template is the maker's earlier file with Unsloth's changes.** Its last line says so:
`{#- Unsloth fixes - developer role, merged system messages, tool calling #}`. Against the maker's earlier file:

1. Several `system` or `developer` messages at the start are merged into one system turn. The maker's file takes
   only the first message as the system text.
2. A reasoning effort of `high` is read as `xhigh`.
3. A tool call's arguments are written only when they are an object. A non-empty JSON string raises an error
   ("Parse them into an object"); the maker's file would iterate over whatever it is given.
4. A tool call without a name raises an error.
5. The error "No user query found in messages" is gone.
6. A later `system` or `developer` message raises an error, as before, but the check is written differently.

**The maker's current file differs from its earlier one in one thing:** `{%- generation %}` and
`{%- endgeneration %}` around each assistant turn's own text. They write nothing; training code reads them as "these
tokens are the model's". The bench's template has no such tags. The server build the bench used knows both tags
(`common/jinja/parser.cpp`), so a GGUF that carries the maker's current file would load.

**The three files write the same text for a Pi conversation.** Rendered with Jinja2 (the settings the Transformers
library uses, the generation tags removed, arguments given as objects), all three give the same bytes for the
first-request frame (7,751 characters, SHA-256 `8ff67afa…`) and for the middle-request frame (8,609 characters,
SHA-256 `86449ca0…`): [`run/render_frame.py --same`](run/render_frame.py). That is Jinja2's rendering, not the
server's.

**So the training text is rendered with `12827f24…`,** and the GGUF that is tested must hold a template that writes
the same text. The fingerprint to check inside a tuned file is the rendered text of a fixed conversation, not only
the template's hash: two different files here give the same text.

What the server reported about the template, in every attempt's record: `supports_tools`, `supports_tool_calls`,
`supports_parallel_tool_calls`, `supports_object_arguments`, `supports_preserve_reasoning`,
`supports_reasoning_effort`, `supports_system_role`, `supports_string_content` and `supports_typed_content`, all
true; begin token `<|endoftext|>`, end token `<|im_end|>`; one slot; a 262,144-token window.

## 2. How tool calls travel

**The server reads the template's own form.** Three kinds of evidence, none of them the server's log:

- **The build's source.** At commit `7775ffb7e48f` the chat formats are `Content-only`, `peg-simple`,
  `peg-native`, `peg-gemma4` and `peg-minimax-m3` (`common/chat.h`): the older generic handler, which asked every
  model for calls as JSON, is not in this build. A template that holds `<tool_call>`, `<function=` and
  `<parameter=` gets the handler the source calls "Qwen3-Coder XML tool calls, also used by … Qwen3.5"
  (`common/chat.cpp`, `common/parsers/qwen3-coder.cpp`); the bench's template holds all three. That handler applies
  the template directly to make the prompt, names its format `peg-native`, takes the thinking from `<think>` to
  `</think>`, and reads each parameter as `<parameter=NAME>`, a line break, the value, a line break,
  `</parameter>`: a value whose schema type is not text is read as JSON. With tools in the request it also builds
  a grammar for that form.
- **The cache.** The closing record of each reply stream says how many prompt tokens came from the server's cache.
  The cache holds the previous prompt and the reply the model then generated. Of the 1,157 calls that follow
  another call, 746 missed 1 token of that and 322 missed none ([`tables/report_cache_reuse.json`](tables/report_cache_reuse.json)).
  So for 1,068 replies (92.3 %) the template wrote the reply back as exactly the tokens the model had produced:
  the model's own writing is the template's form.
- **The recorded stream.** The server sends the reply as `reasoning_content` pieces, then `tool_calls` pieces
  (`index`, `id`, `type: "function"`, the function's `name`, the `arguments` as growing JSON text), then
  `finish_reason: "tool_calls"`. Of the 1,177 replies 1,156 ended that way, 9 with `stop` (a final answer) and 12
  with `length` (the 8,192-token limit of one reply).

**One tool call and one tool result, as the template writes them** (from
[`frames/bench_middle_prompt.rendered_from_frame.txt`](frames/bench_middle_prompt.rendered_from_frame.txt), which is
the middle-request frame rendered with Jinja2; placeholders in angle brackets and capitals):

```text
<|im_start|>assistant
<think>
<MODEL THINKING>
</think>

<tool_call>
<function=bash>
<parameter=command>
<COMMAND>
</parameter>
</function>
</tool_call>
<tool_call>
<function=bash>
<parameter=command>
<COMMAND>
</parameter>
</function>
</tool_call><|im_end|>
<|im_start|>user
<tool_response>
<OUTPUT OF THE COMMAND>
</tool_response>
<tool_response>
<OUTPUT OF THE COMMAND>
</tool_response><|im_end|>
<|im_start|>assistant
<think>
```

What the template does, read in its source:

- **The system turn** is: `<|im_start|>system`, a line break, the effort sentence ("Reasoning effort is set to
  xhigh. …") and an empty line, the `# Tools` block (a heading, a sentence, `<tools>`, one JSON line per tool,
  `</tools>`, the format instruction and the `<IMPORTANT>` reminder), an empty line, the caller's system text with
  the white space at its ends removed, `<|im_end|>` and a line break.
- **Every text is trimmed at both ends:** the system text, the user's text, the thinking, the answer text and each
  tool result. So the description's turn ends `</file><|im_end|>`, without the line break Pi sends after `</file>`,
  and a tool result that ends with a line break (1,108 of the 1,387 read) is written without it.
- **An assistant turn** is `<think>`, a line break, the thinking, a line break, `</think>`, an empty line, the
  answer text if any, then the calls. Text before a call is followed by an empty line; a second call follows the
  first after one line break. **A turn without thinking still gets the thinking lines,** empty:
  `<think>`, two line breaks, `</think>`.
- **A parameter** is `<parameter=NAME>`, a line break, the value, a line break, `</parameter>`, a line break, in the
  order of the call's own arguments. A text value is written as it is. Any other value is written as JSON by the
  server's `tojson`: `, ` between items and `: ` after a key, keys in their own order, non-ASCII text as it is
  (`common/jinja/value.cpp`). So `timeout`, `offset` and `limit` are bare numbers, and the `edits` list of an `edit`
  call is one line such as `[{"newText": "…", "oldText": "…"}]`.
- **Tool results** that follow each other share one `user` turn, each between `<tool_response>` and
  `</tool_response>` lines.
- **Earlier thinking stays.** Pi sent `reasoning_content` back in all 1,157 assistant messages read, and the
  template keeps it unless `preserve_thinking` is set to false.
- **The next reply starts after** `<|im_start|>assistant`, a line break, `<think>` and a line break.

**One place where the model's writing and the template's differ.** In 89 of the 1,157 calls the server reused less
of the cache (65 tokens or more were missed). They cluster in replies that call `read` with a line number: of the
replies with one call and no text, `read` with `path`, `limit` and `offset` missed in 35 of 52, with `path` and
`offset` in 6 of 8, with `path` alone in 4 of 58; `bash` with a command alone missed in 7 of 377. What the model
writes differently there is not in the records (section 6).

## 3. The bench's request, as a frame (the OpenAI-style route)

Files: [`frames/bench_first_request.frame.json`](frames/bench_first_request.frame.json) (request 0 of attempt
`livebook-pr-2527`) and [`frames/bench_middle_request.frame.json`](frames/bench_middle_request.frame.json) (request
3 of the same attempt, 9 messages). Counts: [`tables/report_openai.json`](tables/report_openai.json).

- **The route:** `POST /v1/chat/completions`. Before each call the engine asks
  `POST /v1/chat/completions/input_tokens` with the same body and requires the reply's `prompt_tokens` to equal
  that count. So every recorded request has the server's exact prompt-token count beside it (`usage-NNNN.json`).
- **Pi's settings for this route** (`pi-config.json`): `api: "openai-completions"`, `maxTokensField: "max_tokens"`,
  `supportsDeveloperRole: false`, `supportsReasoningEffort: false`, `supportsStore: false`,
  `supportsUsageInStreaming: true`; the model entry has `reasoning: true`, a 262,144-token window and 8,192 tokens
  a reply. The teacher's attempts have the same Pi version, lock-file hash and settings block, with
  `api: "anthropic-messages"` and `allowEmptySignature: true`.
- **The record is taken to be the body the server received,** apart from white space. The engine decodes Pi's
  request, removes Pi's sampling and thinking controls, sets `model`, `stream`, `max_tokens` and `seed`, adds
  `stream_options`, and encodes that value twice with one JSON library: once for the record, once for the
  server. The record has every object's keys in alphabetical order: `function` before `type`; `description`,
  `name`, `parameters`; each schema's properties (`limit`, `offset`, `path`). The server's JSON type keeps the
  order it receives (`common/json.h`), so that would be the order of each tool's JSON line in the prompt. Pi's own
  order (`path` first) does not reach the server.
- **The top level,** the same seven keys in all 74 requests: `max_tokens` (8,192 in 70; the rest of the
  65,536-token budget in 4), `messages`, `model`, `seed` (101), `stream` (true), `stream_options`
  (`{"include_usage": true}`), `tools`. No temperature, no reasoning effort, no template settings: the server's
  preset decides.
- **`tools`:** Pi's four (`read`, `bash`, `edit`, `write`), each
  `{"function": {"description", "name", "parameters"}, "type": "function"}`; the same bytes in all 74 requests
  ([`fixed/pi_tools_openai.json`](fixed/pi_tools_openai.json), 2,841 bytes, SHA-256 `b72b0ec5…`).
- **Message 1, `system`:** `content` is one string. It is Pi's fixed text
  ([`fixed/pi_system_text_before_instructions.txt`](fixed/pi_system_text_before_instructions.txt), 2,664
  characters, SHA-256 `259fed2d…`, the same in 20 of 20 attempts), then the engine's instruction text, then
  [`fixed/pi_system_text_after_instructions.txt`](fixed/pi_system_text_after_instructions.txt) (37 characters: the
  end of the `<addendum>` block and the `<cwd>` block; 19 of 20 attempts). The one attempt whose project has a
  guide for coding agents carries it between the two, in a `<project_context>` block.
- **The instruction text** has the same sentences in 20 of 20 attempts; the frame shows them with their values
  replaced. Per case: the kind (`bug_fix` 12, `feature` 8), the test command, 2 to 6 `Required outcome (ID): …`
  lines (2 lines in 8 attempts, 3 in 6, 5 in 5, 6 in 1), the allowed folders, and a `Task details:` JSON object with
  the keys `environment` (11 attempts), `environment` and `verification` (6) or `edition` and `verification` (3).
  One attempt has a sentence about a browser where the others have an empty line.
- **Message 2, `user`:** `content` is a list of one part, `{"text": …, "type": "text"}`. The text is
  `<file name="/tmp/eab-ticket.md">`, a line break, the description (which ends with a line break), a line break,
  `</file>`, a line break; 20 of 20.
- **An `assistant` message** has four keys, 1,157 of 1,157: `content` (null in 888, text in 269),
  `reasoning_content` (always text, ending with one line break, as the server returned it), `role`, and
  `tool_calls`: 1 call in 932, 2 in 220, 3 in 5. A call is `{"function": {"arguments", "name"}, "id", "type":
  "function"}`. `arguments` is JSON text without spaces, as `JSON.stringify` writes it (1,387 of 1,387), with the
  keys in the order the model wrote them. The `id` is 32 letters and digits.
- **A `tool` message** has three keys, 1,387 of 1,387: `content` (always one string), `role`, `tool_call_id`. One
  message per call, in the order of the calls.
- **Pi's own words around a tool's output** (each form with its count in the table file): a command with no output
  gives `(no output)`; a command that fails gets an empty line and `Command exited with code N` after its output;
  a file cut short gets an empty line and `[N more lines in file. Use offset=N to continue.]`; `edit` answers
  `Successfully replaced N block(s) in PATH.` or one of its error sentences; `write` answers
  `Successfully wrote to PATH`. An error has no mark of its own on this route: it is only in the text.
- **Every request repeats the conversation so far, unchanged** (37 of 37 pairs in the three attempts read whole),
  and the last answer of a session is in no request: it is in the last reply stream.
- **The tools the untuned model called:** `bash` 989, `read` 283, `edit` 85, `write` 30.

## 4. The teacher's request, as a frame (the Anthropic-style route)

Files: [`frames/teacher_first_request.frame.json`](frames/teacher_first_request.frame.json) and
[`frames/teacher_middle_request.frame.json`](frames/teacher_middle_request.frame.json) (requests 0 and 3 of one
attempt). Counts: [`tables/report_anthropic.json`](tables/report_anthropic.json).

- **The route:** `POST /v1/messages`. The top level has `max_tokens`, `messages`, `model`, `seed`, `stream`,
  `system` and `tools`, in all 538 requests.
- **`system`** is a list of one part, `{"cache_control", "text", "type": "text"}`. The text is built the same way:
  the same 2,664 characters first (15 of 15 attempts, the bench's bytes), the instruction text, then the same 37
  characters (6 attempts) or the project's guide in the same `<project_context>` block (9 attempts).
- **The instruction text** has the bench's sentences with two differences: an empty line where the bench has its
  `Required outcome` lines, and `Task details: {}`. 15 of 15.
- **`tools`:** `{"description", "input_schema", "name"}`, the same four tools with the same values as the bench's.
- **The first message** is the description in the same file wrapper, as one text part that also carries a
  `cache_control` mark.
- **An `assistant` message** is a list of blocks: `thinking` (`{"signature": "", "thinking", "type"}`), `text`,
  and `tool_use` (`{"id", "input", "name", "type"}`, the `id` being `call_` and 24 hex digits, `input` an object).
  Of 523 messages, 498 are thinking and calls, 24 are calls with no thinking, 1 has text too. Calls per message:
  1 in 397, 2 in 100, 3 in 25, 4 in 1.
- **Tool results** come back in one `user` message, a list of `tool_result` blocks
  (`{"content", "is_error", "tool_use_id", "type"}`), `content` always one string, in the order of the calls. 41 of
  676 are marked `is_error: true`. The texts have Pi's same words.
- **Cache marks:** two `cache_control` marks in every request (the system part and the last block), moving as the
  conversation grows. With them set aside, every request repeats the one before it (523 of 523 pairs).
- **The order of a call's parameters is lost in the requests:** the engine's re-encoding sorts the keys of `input`.
  The reply streams keep the teacher's own order (`path` before `edits` in 4 of 123 `edit` calls, `oldText` before
  `newText` in 8), and so does Pi's event log.
- **The tools the teacher called:** `bash` 544, `edit` 123, `read` 7, `write` 2.

## 5. The differences the converter must bridge

| # | Part | The teacher's record | What the bench's server is sent | For the converter |
|---:|---|---|---|---|
| 1 | The system text's place | top-level `system`, a list of one text part | the first message, role `system`, `content` one string | move it; the text itself is not changed |
| 2 | Cache marks | two `cache_control` keys in every request | none | drop them |
| 3 | The description's message | one text part with a cache mark | one text part, keys `text` and `type` | drop the mark; the wrapper is the same bytes |
| 4 | Tool definitions | `{"description", "input_schema", "name"}` | `{"function": {"description", "name", "parameters"}, "type": "function"}`, keys in alphabetical order at every level | re-shape; take the bench's bytes from `fixed/pi_tools_openai.json` |
| 5 | Thinking | a `thinking` block with an empty `signature` | `reasoning_content`, a string | move the text; the signature has no place |
| 6 | A reply without thinking | 24 of 523 replies | none of 1,157: the untuned model always thought | the template writes empty thinking lines for it; whether such replies are trained on is a decision |
| 7 | Answer text beside calls | a `text` block (1 of 523) | `content`, a string (269 of 1,157), else null | move it; null when there is none |
| 8 | A tool call | a `tool_use` block, `input` an object | an entry of `tool_calls`, `arguments` the object as JSON text | re-shape; the template writes each parameter by name, so the JSON text's own spacing never reaches the model |
| 9 | The order of a call's parameters | sorted in the requests; the teacher's own order only in the reply streams and Pi's event log | the model's own order | read the order from the reply stream or the event log, not from the request |
| 10 | Call ids | `call_` and 24 hex digits | 32 letters and digits | any; the template writes no id |
| 11 | Tool results | one `user` message with a list of `tool_result` blocks | one `tool` message per result, `content` a string | split; the template joins results that follow each other into one turn |
| 12 | The error mark | `is_error` on each result (41 of 676 true) | no mark | drop it; the error is in the result's text |
| 13 | What only the server adds | not in any record | the effort sentence and the `# Tools` block before the system text, the special tokens, the thinking lines, the trimming of every text | never written by the converter: the template makes them |

**Differences the converter does not bridge,** because no text may be written into a session: the instruction text
of a bench case has 2 to 6 requirement lines and a filled `Task details` object where a training case has an empty
line and `{}` ([the factory's README](../../../factory/README.md), section 2.1); and what is in a project's guide.

**Not part of any prompt:** `model`, `seed`, `max_tokens`, `stream`, `stream_options`.

## 6. What the files cannot settle

Each needs the server with this GGUF loaded, or its log. None was tried.

1. **The prompt's exact bytes.** Sections 2 and 3 are the template's source, the server's source and a Jinja2
   rendering. The server's own rendering of one request settles the tool lines (spacing, the alphabetical key
   order, how `<`, `>` and non-ASCII characters are written), the white space between blocks, and whether a begin
   token is put before the text. The server's README names `POST /apply-template` with `messages` as its only option; whether it also
   takes `tools` in this build is not stated there.
2. **The settings the server's preset gives the template:** `enable_thinking`, `reasoning_effort`,
   `preserve_thinking`. The bench records the effort `xhigh` as declared by the operator, not as reported by the
   server, and its requests carry none. The template's own defaults are thinking on, `xhigh`, earlier thinking kept;
   the records agree with thinking on and kept. Whether the effort sentence was in the prompt is not recorded.
3. **The server's own word on the format** (its log, or `chat_format` in a slot's settings). It is not in the
   bench's records: the one `chat_format` there is the server's default for a request without tools,
   `Content-only`. The server's log of that night was not looked for. By the source it is `peg-native`, through the
   handler named in section 2.
4. **What the model writes for a `read` call with `offset` or `limit`,** raw, before the server parses it: the one
   place where the template did not write the reply back as the model wrote it (section 2).
5. **Why 746 calls missed 1 token and 322 missed none.** The records hold the counts, not the reason.
6. **That a tuned GGUF renders the same text.** A file converted from the maker's current folder will carry the
   maker's current template, with the generation tags. The Jinja2 check says the text is the same; the server's
   rendering of the tuned file is the proof.

## 7. A check the records already allow

The bench's records pair 1,177 requests with the server's exact prompt-token count. A renderer that claims to write
what the server writes can be tested against them without a model and without a card: render the request, count
tokens with the model's tokenizer, compare. It has to run where the records are, reading them in place, because the
requests hold the bench's cases. `POST /v1/chat/completions/input_tokens` gives the same count for any body from a
running server, also without generating.

## Files

| File | What |
|---|---|
| [`templates/`](templates/) | the three template files of section 1, byte for byte |
| [`fixed/pi_system_text_before_instructions.txt`](fixed/pi_system_text_before_instructions.txt) | Pi 1.2.0's system text up to and including the `<addendum>` line: 2,664 bytes, no line break added |
| [`fixed/pi_system_text_after_instructions.txt`](fixed/pi_system_text_after_instructions.txt) | the text after the instruction text when the project has no guide: 37 bytes |
| [`fixed/pi_tools_openai.json`](fixed/pi_tools_openai.json) | the four tool definitions as the bench's server receives them: one line, 2,841 bytes |
| [`frames/bench_first_request.frame.json`](frames/bench_first_request.frame.json), [`frames/bench_middle_request.frame.json`](frames/bench_middle_request.frame.json) | two requests of the bench's run, content replaced |
| [`frames/bench_first_prompt.rendered_from_frame.txt`](frames/bench_first_prompt.rendered_from_frame.txt), [`frames/bench_middle_prompt.rendered_from_frame.txt`](frames/bench_middle_prompt.rendered_from_frame.txt) | those two frames as the bench's template writes them under Jinja2: not the server's rendering |
| [`frames/teacher_first_request.frame.json`](frames/teacher_first_request.frame.json), [`frames/teacher_middle_request.frame.json`](frames/teacher_middle_request.frame.json) | two requests of one teacher session, content replaced |
| [`tables/report_openai.json`](tables/report_openai.json) | counts and hashes over the bench's 74 requests |
| [`tables/report_anthropic.json`](tables/report_anthropic.json) | counts and hashes over the teacher's 538 requests and their reply streams |
| [`tables/report_cache_reuse.json`](tables/report_cache_reuse.json) | cache reuse over the bench's 1,177 calls, and by the shape of the reply before each call |
| [`run/`](run/) | the five scripts |

The placeholders: `<CASE TEXT …>`, `<KIND>`, `<TEST COMMAND>`, `<ID>`, `<FOLDERS>`, `<THE PROJECT'S OWN GUIDE FOR
CODING AGENTS>`, `<PATH OF THE GUIDE>`, `<MODEL THINKING>`, `<MODEL TEXT>`, `<COMMAND>`, `<PATH>`, `<TEXT>`,
`<NUMBER>`, `<N MORE LIKE IT>`, `<CALL ID n>`, `<OUTPUT OF THE COMMAND>`, `<FILE TEXT>`.

## Commands

Hosts and paths come from the environment: `BENCH` (the name of the bench controller's container), `RUN` (the run's
folder inside it), `RUNS` (the teacher job's runs folder), `WORK` (a folder of one's own on the machine that runs the
scripts; it was deleted afterwards), `ATTEMPT` (an attempt's name). The bench's files were read with `cat`, `grep`
and `tar` only and piped to the scripts; no file of the bench was copied to a disk.

```bash
# 1. the template the server reported, and its hash; the same line in every attempt
docker exec $BENCH sh -c "grep -m1 '\"chat_template\": ' $RUN/$ATTEMPT/attempt.json" \
  | OUT_FILE=$WORK/bench_gguf_chat_template.jinja python3 -I run/template_from_attempt.py
docker exec $BENCH sh -c "cd $RUN && for d in */; do [ -f \$d/attempt.json ] && grep '\"chat_template\": ' \$d/attempt.json | sed 's/^ *//' | sha256sum; done | sort | uniq -c"

# 2. the maker's files
curl -sSL -o $WORK/maker_chat_template.jinja      https://huggingface.co/Qwen/Qwen3.8-27B/resolve/37561816e66b5b9153b1b64c10968c18c1e6f4a0/chat_template.jinja
curl -sSL -o $WORK/maker_chat_template_prev.jinja https://huggingface.co/Qwen/Qwen3.8-27B/resolve/8c0b3d30f3ae96f5c7f774de704bf0ada83e422a/chat_template.jinja
sha256sum $WORK/*.jinja; diff -u $WORK/maker_chat_template.jinja $WORK/bench_gguf_chat_template.jinja

# 3. the bench's frame: the first and last request of every attempt, and every request of three attempts
docker exec $BENCH sh -c "cd $RUN && { for d in */; do d=\${d%/}; [ -f \$d/attempt.json ] || continue; \
    ls \$d/request-*.json | head -n 1; ls \$d/request-*.json | tail -n 1; ls \$d/usage-*.json | head -n 1; done; \
    ls livebook-pr-2527/request-*.json livebook-pr-2527/usage-*.json guardian-pr-748/request-*.json \
       guardian-pr-748/usage-*.json cachex-pr-341/request-*.json cachex-pr-341/usage-*.json; } | sort -u | tar -cf - -T -" \
  | OUT=$WORK/bench FRAME_ATTEMPT=livebook-pr-2527 FRAME_STEP=3 python3 -I run/frame_openai.py

# 4. cache reuse: the closing usage record of every reply stream (numbers only)
docker exec $BENCH sh -c "cd $RUN && grep -H '\"timings\"' */response-*.sse" \
  | CALLS=$WORK/bench/calls_by_message.json python3 -I run/cache_reuse.py > $WORK/bench/report_cache_reuse.json

# 5. the teacher's frame, and the fixed text compared with the bench's
RUNS=$RUNS OUT=$WORK/teacher BENCH=$WORK/bench FRAME_ATTEMPT=20261112-122138-217eee81/ex338-pr-1463 FRAME_STEP=3 \
  python3 -I run/frame_anthropic.py

# 6. the frames as the template writes them, and the three templates compared
for f in first middle; do
  python3 -I run/render_frame.py $WORK/bench_gguf_chat_template.jinja $WORK/bench/${f}_request.frame.json \
    > $WORK/bench/${f}_prompt.rendered_from_frame.txt
  python3 -I run/render_frame.py --same $WORK/bench/${f}_request.frame.json $WORK/bench_gguf_chat_template.jinja \
    $WORK/maker_chat_template_prev.jinja $WORK/maker_chat_template.jinja
done
```

The scripts ran with Python 3.14.4 and Jinja2 3.1.6, at the lowest priority.

## Provenance and licence

- **The templates:** `Qwen/Qwen3.8-27B` and `unsloth/Qwen3.8-27B-GGUF`, both marked Apache-2.0 on the Hub. The
  files here are copies, unchanged.
- **Pi's system text and tool definitions:** written by Pi 1.2.0 (`@earendil-works/pi-coding-agent`, MIT), copied
  from recorded requests.
- **The instruction sentences:** the engine's own, the same as in [`factory/`](../../../factory/README.md).
- **The bench's records:** the maintainer's data. Nothing of a case, a project or an answer is in this folder.
- **The teacher's sessions:** this project's own. Only their frame is here; the sessions are published separately,
  after the scans (E87).
