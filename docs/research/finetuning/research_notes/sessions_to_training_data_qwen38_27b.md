# From the teacher's kept sessions to a fine-tuned Qwen3.8-27B: the training format, the sizes and the way to the bench (2026-11-12)

What has to happen between "the teacher's kept sessions" and "a fine-tuned Qwen3.8-27B that is tested on the Elixir SWE
Bench". Desk work: nothing was trained, converted or started for this note.

Labels. **Counted** = counted in this project's own records on 2026-11-12. **Read** = read that day in the maker's own
file, page or paper, linked. **Est.** = this note's arithmetic, never measured. The sessions' text is not quoted
anywhere here: only shapes and counts are given.

Registry rows: the converter [Q539](../../../../experiments.md), thinking and masking Q540, the recipe Q482, the
memory and speed probe Q477, the student E10, the rented node E28, the session scans E87, and the new rows E103 (the
target text), E104 (long sessions), E105 (the proof run) and E106 (the bench file).

## 1. The path in short

1. **Pin the target text:** record exactly what the bench's server shows Qwen3.8-27B for a Pi conversation (E103).
2. **Scan and select:** the two session scans (E87), at most 3 kept sessions per case and the balance rules
   ([rules](../../../dataset_rules.md), sections 6 and 7).
3. **Convert:** each kept session becomes one token sequence in the student's own chat template, with a mask that
   says which tokens the model wrote (Q539).
4. **Probe:** one hour on the training cards: how long a sequence fits, and tokens per second (Q477).
5. **Prove the path small:** about 30 sessions through conversion, a short training, the merge, the GGUF and one case
   of the dataset that was held back from training (E105).
6. **Train:** a LoRA on the kept sessions (Q482, E10).
7. **Make the bench file:** merge onto the full-precision weights, convert, quantize the base and the tuned model by
   one recipe, the trained template inside the file (E106).
8. **Test:** the bench's 20 cases, three seeds, against the untuned base and the teacher's 16 of 20 (E10).
9. **The rig:** the rig-sized file and its time per task (E43, E44).

## 2. What a kept session holds

**Counted** on the first six kept sessions (2026-11-12, one project, three bug fixes and three features, seed 101, the
teacher at its maker's temperature 1.0).

### 2.1 The files of an attempt

| File | What it is |
|---|---|
| `request-NNNN.json` | every request Pi sent to the model server, whole: the opening text, the tool definitions and the conversation so far |
| `response-NNNN.sse` | the server's streamed answer to that request |
| `usage-NNNN.json` | prompt and answer tokens of that call, as the server counted them |
| `pi-events.jsonl` | Pi's own event log; its last `agent_end` record lists the whole conversation in Pi's own neutral form |
| `prompt.md`, `instructions.md` | the case's description, and the bench's fixed instruction text for this case |
| `pi-config.json` | Pi's version, lock-file hash and settings for the attempt |
| `attempt.json` | the outcome, the settings, and the served model's own chat template and capabilities as the server reported them |
| `model.patch`, `grade.json`, `submission.json` | the patch and its grading |
| `activity.log`, `build.log`, `qualification.json`, `runtime.json`, `agent-progress.json` | the run's log, the workspace build, the case's controls |

### 2.2 The shape of a conversation

- **The route.** For the teacher's server Pi speaks the Anthropic-style messages route. A request has `system` (one
  text part), `tools` (four: `read`, `bash`, `edit`, `write`, each a name, a description and a parameter schema),
  `messages`, `max_tokens` 8,192, `seed` 101 and `stream`.
- **The opening text** is Pi's system prompt, 11,108 to 11,523 characters in the six sessions (11,386, 11,394, 11,523,
  11,482, 11,409 and 11,108). Pi builds it from seven sections; in one session they measured: preamble 169 characters,
  tools 339, rules 839, docs 1,298, the bench's instruction text 796, the project's own guide for coding agents 7,918
  (a file of the repository that Pi reads from the workspace), working directory 23. Two sessions of the same project
  differ only in the instruction text (772 and 901 characters); everything before it (2,664 characters) and after it
  (7,958 characters) is identical.
- **The first user message** is the case's description inside Pi's file wrapper: `<file name="/tmp/eab-ticket.md">`, a
  line break, the description, two line breaks, `</file>`, a line break. 43 characters around the description.
- **Then turns.** An assistant message holds an optional thinking block and one or more tool calls. The next user
  message holds one tool result per call. The six sessions have 173 such assistant messages with 227 tool calls
  (`bash` 188, `edit` 37, `read` 2, `write` 0); 166 of the 173 carry a thinking block; 13 of the 227 results are marked
  as errors.
- **The end.** The last answer is a thinking block and a short text (771 characters in one session). It is in the last
  `response` file and in Pi's event log, not in any request.
- **Every request repeats the conversation so far, unchanged:** each request's messages start with the messages of the
  request before it (25 of 25, 11 of 11, 49 of 49, 18 of 18, 40 of 40 and 30 of 30 pairs, cache markers set aside). A
  session is one text that only grows.

### 2.3 Sizes

| Case | Kind | Model calls | Tool calls | Generated tokens | Largest prompt, tokens | Thinking, characters | Tool-call inputs, characters | Tool results, characters | Session, seconds |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| ex338-pr-1463 | bug fix | 26 | 36 | 14,263 | 56,625 | 38,466 | 10,179 | 128,510 | 610.6 |
| ex338-pr-1461 | bug fix | 12 | 16 | 5,824 | 23,105 | 12,003 | 6,309 | 46,107 | 248.6 |
| ex338-pr-1460 | feature | 50 | 60 | 35,671 | 104,612 | 72,909 | 48,728 | 215,454 | 1,133.5 |
| ex338-pr-1458 | feature | 19 | 23 | 11,170 | 60,798 | 28,919 | 13,153 | 154,030 | 514.3 |
| ex338-pr-1457 | feature | 41 | 44 | 17,910 | 62,551 | 45,645 | 14,982 | 137,120 | 703.1 |
| ex338-pr-1452 | bug fix | 31 | 48 | 23,846 | 96,513 | 38,134 | 43,058 | 232,396 | 850.8 |
| **All six** | | **179** | **227** | **108,684** | sum 404,204 | 236,076 | 136,409 | 913,617 | 4,060.9 |

- Tokens are the teacher's server's counts, with the teacher's tokenizer. "Largest prompt" is the last request: the
  whole session up to the final answer. The mean of the six is 67,367 tokens (404,204 / 6).
- The character columns come from the last request of each session, so they leave out the final answer; tool-call
  inputs are counted as JSON.
- **Whose text it is,** by characters of the last requests (1,381,447 in all): tool results 913,617 (66.1 %); the
  teacher's own writing 372,485 (27.0 %: thinking 17.1 %, tool calls 9.9 %); the opening (system text 68,302, tool
  definitions 16,968, descriptions with their wrapper 10,075) 95,345 (6.9 %).
- Tool results: the largest is 27,508 characters; 44 of the 227 are longer than 8,000 characters.
- Thinking blocks: the longest is 16,287 characters; the median per session is 312, 150, 199, 549.5, 521.5 and 180.
- The six sessions took 4,272 s of wall clock and all six were kept: 5.056 kept sessions an hour.

### 2.4 The fixed text against the written text

| Text | Whose | Same in every session? |
|---|---|---|
| Pi's preamble, tool notes, rules and docs sections | Pi 1.2.0 | yes |
| The four tool definitions | Pi 1.2.0 | yes (one hash in all six sessions) |
| The instruction text | the bench's code, filled per case (kind, test command, allowed folders, budgets) | the sentences yes, the values per case |
| The project's guide for coding agents | the project's repository | per project and commit; absent where a project has none |
| The file wrapper around the description | Pi | yes |
| The description | the teacher, written before the session | per case |
| Tool results | the workspace: the project's files, compiler and tests, cut by Pi's own limits | per session |
| Thinking, tool calls, the final summary | the teacher, in the session | per session: this is what the student learns to write |

## 3. What Qwen3.8-27B expects

**Read** on 2026-11-12 in the maker's repository ([card](https://huggingface.co/Qwen/Qwen3.8-27B),
[files](https://huggingface.co/Qwen/Qwen3.8-27B/tree/main)).

| Fact | Value | Where |
|---|---|---|
| Licence | Apache License 2.0, unmodified text, "Copyright 2026 Alibaba Cloud" | `LICENSE` |
| What the licence allows | derivative works and their distribution, with the licence copied, notices kept and changes stated. It does not name model weights; a fine-tune published under Apache-2.0 with the notice is the common reading, not legal advice | `LICENSE`, sections 2 and 4 |
| Kind | dense (not a mixture of experts), with a vision encoder and a multi-token-prediction head | card, `config.json` |
| Size | 27,320,697,856 parameters; 18 weight files, 55.6 GB in BF16 | the bench's result file; file list |
| Layers | 64, hidden size 5,120, feed-forward size 17,408; 48 linear-attention (Gated DeltaNet) layers and 16 full-attention layers, one full layer after every three linear ones | `config.json` |
| Vocabulary | 248,320 tokens, input and output tables not shared | `config.json` |
| Context | 262,144 tokens natively; the card names 1,000,000 with a scaling it warns about | card, `config.json` |
| Code | `Qwen3_5ForConditionalGeneration`, model type `qwen3_5`, written with Transformers 5.8.0.dev0 | `config.json` |
| Thinking | on by default; switched off per request with `enable_thinking`; depth by `reasoning_effort`: `xhigh` (the default), `medium`, `low`; `preserve_thinking` is on by default and keeps earlier turns' thinking in the conversation | card, template |
| Sampling the maker recommends with thinking | temperature 1.0, top-p 0.95, top-k 20, min-p 0.0, presence penalty 0.0, repetition penalty 1.0 | card |
| Tool calling | the card does not document the format; the template does | card |
| Fine-tuning | the card gives no guidance; the Hub lists 877 fine-tunes and 324 adapters of it | card |

**The chat template** ([`chat_template.jinja`](https://huggingface.co/Qwen/Qwen3.8-27B/blob/main/chat_template.jinja),
9 kB). It was read through a page reader that returns short quotes, so the sequences below are that reading; the
converter's first job is to hold the file itself by hash (E103).

- **Turns** are `<|im_start|>` + role + line break + text + `<|im_end|>` + line break. Nothing precedes the first turn.
- **The system turn** holds, when tools are given, a `# Tools` block: a sentence, `<tools>`, one JSON object per tool
  on its own line, `</tools>`, the format instruction and an `<IMPORTANT>` reminder of four rules. It also holds one
  fixed sentence for the reasoning effort (`xhigh` and `low` each have one, `medium` has none), and the caller's
  system text after a blank line.
- **An assistant turn** is: `<think>`, line break, the thinking, line break, `</think>`, a blank line, the answer text
  if any, then the tool calls.
- **A tool call** is `<tool_call>`, `<function=NAME>`, one `<parameter=NAME>` … `</parameter>` per argument, each on
  its own lines, `</function>`, `</tool_call>`. A text argument is written as it is; any other value is written as
  JSON. Several calls in one turn follow each other, one line break apart.
- **Tool results** go into a user turn: each result between `<tool_response>` and `</tool_response>` lines, and
  results that follow each other share one turn.
- **The prompt for the next answer** ends with `<|im_start|>assistant`, a line break and, with thinking on, an open
  `<think>` line. So the model's first generated token is the first token of its thinking.
- **Loss marks.** The template carries `{% generation %}` and `{% endgeneration %}` around each assistant turn's own
  text (thinking, answer, tool calls and the closing `<|im_end|>`), which training code reads as "these tokens are the
  model's".
- **It changed five days before this note:** `chat_template.jinja` and `tokenizer_config.json` were last changed by
  "Add a response template and generation tags (#236)". The file inside a GGUF made earlier is an older or a different
  one. The template is pinned by hash, never by name.

## 4. What the student is shown when it is tested

**Read** in the factory's copy of the bench's engine (`factory/lib/eab/pi.ex`, `pi_gateway.ex`, `thinking.ex`,
`factory/priv/pi/bridge.mjs`; same bytes as the bench's, `factory/README.md` section 2.1) and in the bench's published
result file for Qwen3.8-27B ([results](https://github.com/Cinderella-Man/elixir-swe-bench/tree/main/results-page/results),
series `6bb71013…`).

- **The bench's base run** (one seed of three so far): Qwen3.8-27B, Unsloth's UD-Q6_K_L file (24,170,553,344 bytes),
  a llama.cpp server (build `b1-7775ffb`) on two RTX 3090, Pi 1.2.0, context 262,144, reasoning effort `xhigh`, the
  server's sampling (temperature 1.0, top-k 20, top-p 0.95, min-p 0.05). Seed 101: **7 of 20 cases passed**; 3 attempts
  ended at the 65,536-token budget; 691,389 tokens generated in 1,177 model calls; 34,104 generated tokens per passed
  case (238,726 / 7); peak card memory 40,932,212,736 bytes; 6 h 58 min 47 s for the 20 cases. The template inside
  that file has SHA-256 `12827f24…`.
- **Two routes, one of them the student's.** For a llama.cpp server Pi speaks the OpenAI-style chat route: `messages`
  with the roles system, user, assistant and tool, the assistant's calls in `tool_calls`, and `tools` as function
  definitions. For the teacher's server Pi speaks the Anthropic-style route (section 2.2). The teacher's sessions are
  recorded in the second form; the student is tested, on the bench and on the rig, through the first.
- **The server makes the text.** The engine removes Pi's sampling and thinking controls, so the server's own preset
  rules. The server renders the messages and tools through the chat template stored inside the GGUF, and that text is
  what the model reads. The rig's engine does the same from the same file.
- **Earlier thinking stays in the conversation:** Pi sends each reply's reasoning back in the history (the sister
  repo's [agent check](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/bench/agent_check/README.md)),
  and the template keeps it by default. So a tested session, like a recorded one, is one text that only grows.

### 4.1 Where the training text must match byte for byte, and where it may differ

| Part | Rule | Why |
|---|---|---|
| The chat template | the same file, by hash, for rendering the training text and inside the GGUF that is tested | a different template is a different language of turns and calls |
| The template's settings | thinking on, effort `xhigh`, earlier thinking kept: the bench's settings | the effort sentence sits in the system turn of every request |
| The tool definitions | Pi 1.2.0's four tools as Pi sends them on the OpenAI-style route, written into the `<tools>` block by the serving engine's own JSON writer | spacing and key order of that JSON are part of the prompt; two JSON writers differ |
| Pi's system text and the file wrapper | byte for byte as Pi 1.2.0 builds them | pinned already by the factory's parity test |
| The instruction sentences | byte for byte the bench's | the same |
| Tool calls and tool results in the history | written as the template writes them from structured messages | at test time the server re-writes every earlier call from its parsed form |
| Tool results' text | as Pi returned it, cut only by Pi's own limits | a different cut in training teaches a different context |
| The project's guide, the description, the values in the instruction text | may differ: they are content | each case has its own |
| Requirement sentences and the task-details note | differ already: a training case has none, a bench case has 2 to 6 sentences and a note (`factory/README.md` 2.1) | known and recorded |
| Tool-call ids, the model's name, the seed | may differ | the template does not write them into the text |
| Which tokens carry loss | free | invisible at test time |

**Equality by construction.** The surest converter does not write the student's format itself. It builds the
OpenAI-style messages Pi would send and has the serving engine render them: llama.cpp's server answers
`/apply-template` with the exact prompt text for a list of messages and runs no model
([server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md)). A second rendering by the
training library's `apply_chat_template` must give the same bytes on a sample before either is trusted.

## 5. The format decisions

| # | Decision | Source |
|---|---|---|
| F1 | **The student's own format, not the teacher's.** The teacher's recorded calls are re-written into the student's template. | SWE-smith did the same: its experts used function calling, its student writes XML, so it "convert[s] the expert trajectories' function calling format into the XML style response" ([paper](https://arxiv.org/abs/2504.21798), appendix F.1) |
| F2 | **One sequence per session.** The conversation only grows (2.2, 4), so one pass over the whole text trains every turn. | counted here |
| F3 | **The thinking is kept,** as the student's thinking block. | SERA: 41.00 % with the teacher's reasoning against 23.00 % with tool calls only (Qwen3-32B, 4,200 sessions; [paper](https://arxiv.org/abs/2601.20789), table 8) |
| F4 | **Loss only on what the model wrote:** thinking, answer text, tool calls and the turn's end token. The system turn, the description and every tool result are read, not learned. | the template's own generation marks; TRL's `assistant_only_loss` and its pre-tokenized form with a `labels` column ([docs](https://huggingface.co/docs/trl/sft_trainer)) |
| F5 | **Tool results stay as they were returned.** No trimming, no summaries, no markers in place of old output. | section 4.1; SERA does "not truncate context history or tool outputs at any point during rollouts" (section 3.1). No text by another writer enters the data (the project's rule) |
| F6 | **Only kept sessions,** at most 3 per case, after the two scans. | the rules page, sections 6 and 7; SWE-smith's cap of 3; SWE-Gym and SWE-smith train on resolved sessions only |
| F7 | **A failed tool call inside a kept session stays,** and carries loss in the first run. Masking the wrong steps is a later arm. | SWE-Lego: +0.4 to +0.8 points from masking (Q540) |
| F8 | **Among a case's kept sessions the shorter ones are taken first.** | E41 |
| F9 | **A session that fits the training window is used whole. A longer one is cut at a turn boundary and keeps its start;** it is marked as cut. | SERA at a 32K window, 3,000 sessions: cut in order 43.00 %, only sessions that fit 40.60 %, cut at random 37.47 % (table 4); about a quarter of its sessions were longer than the window |
| F10 | **Nothing is cut inside a turn,** and no session is split into overlapping pieces in the first run. | pieces repeat the opening and multiply the tokens trained on (E104) |

What the published sets did, for comparison:

| Work | Sessions | Student | Training | Result |
|---|---:|---|---|---|
| [SWE-Gym](https://arxiv.org/abs/2412.21139) | 491 (mean 18,578.5 tokens, the longest 81,245) | Qwen-2.5-Coder 7B, 14B, 32B | all weights, 32,768-token window, learning rate 1e-4, at most 5 passes, 2 to 8 H100 | SWE-bench Verified 1.8 → 10.6, 4.0 → 16.4, 7.0 → 20.6 |
| [SWE-smith](https://arxiv.org/abs/2504.21798) | 5,000 (58 turns on average), at most 3 per task | Qwen-2.5-Coder 32B | all weights, 32,768-token window, learning rate 5e-5, 2 to 8 H100 | 40.2; 28.2 with 500 sessions |
| [SERA](https://arxiv.org/abs/2601.20789) | 16,000 and 25,000 | Qwen3-32B | all weights, 32K window, 3 passes, learning rate 1e-5 | 47.07 and 49.53 |
| [Nebius](https://nebius.com/blog/posts/openhands-trajectories-with-qwen3-coder-480b) | 32,161 (64.3 turns on average) | Qwen3-30B-A3B | all but the routers and embeddings, 131,072-token window, 5 passes, 16 B200 for 65 hours | 25.2 → 49.7 |

None of the four says how a session longer than its window was handled in training, and none says which tokens
carried the loss. All four trained all weights; a LoRA is this project's choice for its cards, not theirs. In one
comparison a rank-32 LoRA trailed full training by 13 % after this kind of training
([note](Agentic%20RL%20for%20a%20DeepSeek%20teacher/teacher_to_student_distillation.md), Q2).

### 5.1 The first recipe (a proposal, Q482)

| Setting | Value | From |
|---|---|---|
| Method | a LoRA; the base's weights stay as they are | the cards (section 7); all four published runs trained all weights |
| Rank and layers | rank 64 on the attention and feed-forward projections of the language layers; the vision layers frozen | SWE-Gym's LoRA for a 32B used rank 64; Unsloth's example uses 16 and switches the vision layers off for text data |
| Base precision | BF16 where the cards hold it, else 4-bit | Unsloth: 4-bit fits 24 GB, 16-bit needs more than 36 GB |
| Batch | 1 sequence a step, gradients gathered over 8 steps | the published runs' batch of 8; one long sequence fills the cards |
| Learning rate | 1e-4 | TRL's advice for adapters; Unsloth's example uses 2e-4 |
| Passes | 3, a checkpoint after each | SWE-smith and SERA: 3; SWE-Gym and Nebius: up to 5 |
| Order | sessions sorted from short to long | SWE-Lego's order by turn count, +2.0 and +2.2 points (Q540) |
| Which checkpoint | by the loss on sessions of one project left out of training, never by the bench | the hold-out rule |

## 6. A worked example

**Made up for this note.** The project, the command and the output are invented; it is never training data. It shows
one turn with two tool calls and the turn after it.

What the converter builds (the OpenAI-style form, shortened):

```json
[
  {"role": "system", "content": "<Pi's system text with the bench's instruction text>"},
  {"role": "user", "content": "<file name=\"/tmp/eab-ticket.md\">\nThe cart total ignores the discount code.\n\n</file>\n"},
  {"role": "assistant", "reasoning_content": "I will run the cart tests first, then look for where the total is built.",
   "content": "",
   "tool_calls": [
     {"type": "function", "function": {"name": "bash", "arguments": "{\"command\": \"mix test test/shop/cart_test.exs\"}"}},
     {"type": "function", "function": {"name": "bash", "arguments": "{\"command\": \"grep -n total lib/shop/cart.ex\"}"}}
   ]},
  {"role": "tool", "content": "1 test, 1 failure"},
  {"role": "tool", "content": "14:  def total(cart) do"}
]
```

What the template makes of it (the system turn shortened; ▶ and ◀ mark the tokens that carry loss):

```text
<|im_start|>system
[the template's tools block with Pi's four tools, its effort sentence, then Pi's system text]<|im_end|>
<|im_start|>user
<file name="/tmp/eab-ticket.md">
The cart total ignores the discount code.

</file>
<|im_end|>
<|im_start|>assistant
<think>
▶I will run the cart tests first, then look for where the total is built.
</think>

<tool_call>
<function=bash>
<parameter=command>
mix test test/shop/cart_test.exs
</parameter>
</function>
</tool_call>
<tool_call>
<function=bash>
<parameter=command>
grep -n total lib/shop/cart.ex
</parameter>
</function>
</tool_call><|im_end|>◀
<|im_start|>user
<tool_response>
1 test, 1 failure
</tool_response>
<tool_response>
14:  def total(cart) do
</tool_response><|im_end|>
<|im_start|>assistant
<think>
▶[the next turn's thinking and calls]<|im_end|>◀
```

The record written for training holds the token ids of that whole text and, per token, either the same id (inside
▶ ◀) or the ignore mark −100.

## 7. Sizes and times

All **Est.**; every figure here is replaced by the probe's measurement (Q477).

### 7.1 The data

- One session is one sequence of 23,105 to 104,612 tokens in the six counted (mean 67,367), by the teacher's
  tokenizer. The student's tokenizer will give other counts for the same text; not counted.
- 500 kept sessions, the size planned for the first run: 500 × 67,367 = 33,683,500 tokens a pass.
- 500 kept sessions need at least 167 cases at 3 kept sessions a case (500 / 3).
- The teacher's time for 500 kept sessions at 5.056 an hour: 98.9 hours, if every attempt is kept as the first six
  were.

### 7.2 Memory

- The weights in BF16: 27,320,697,856 × 2 bytes = 54.6 GB. A 4-bit copy for training: Unsloth names "17–19GB" for its
  4-bit file at inference ([guide](https://unsloth.ai/docs/models/qwen3.8/train)); 18 GB is used below.
- Unsloth's guide: "QLoRA works with 24GB", LoRA "needs >36GB", full training "4x more"; its example trains at 2,048
  tokens, batch 1.
- Memory per token of sequence, two ways. Lean: the layer outputs kept for the backward pass, 64 × 5,120 × 2 bytes =
  655,360 bytes a token. Cautious: 1.5 MB a token, which is the 0.6 MB a token read from a vendor's figure for a
  32-layer, 4,096-wide model ([note](Fine%20tuning%20small%20models%20for%20Elixir/training_time_on_3090s.md)) times 2.5
  (64 × 5,120 against 32 × 4,096).
- 85 % of card memory is taken as usable.

| Cards | Base | Free for the sequence | Fits, cautious | Fits, lean | Of the six sessions, whole |
|---|---|---:|---:|---:|---|
| one 24 GB card | 4-bit | 2.4 GB | 1,600 tokens | 3,662 tokens | none |
| five 24 GB cards, the model split over them | 4-bit | 84.0 GB | 56,000 | 128,174 | 1 cautious, 6 lean |
| five 24 GB cards, split | BF16 | 47.4 GB | 31,600 | 72,327 | 1 cautious, 4 lean |
| two rented 80 GB cards, split | BF16 | 81.4 GB | 54,267 | 124,206 | 1 cautious, 6 lean |
| four rented 80 GB cards, split | BF16 | 217.4 GB | 144,933 | 331,726 | 6 and 6 |

A model split over cards runs one card at a time, so it trains at about one card's speed.

### 7.3 Speed and time

- One RTX 3090 at its power cap, BF16 LoRA, long sequences: 145 tok/s for a 9B model (the earlier note's estimate,
  from one third party's measured run). By parameters: 145 × 9 / 27.32 = 47.8 tok/s for the 27B; with a 4-bit base
  × 0.8 = 38.2 tok/s. The extra cost of the 16 full-attention layers on long sequences is not added.
- An H100 is taken as 3.5 × an RTX 3090 (the earlier note's assumption, no source): 167.3 tok/s in BF16.

| Run | Where | Tokens a pass | Time a pass | Cost a pass |
|---|---|---:|---:|---:|
| 500 whole sessions | five RTX 3090, 4-bit base | 33,683,500 | 881,767 s = 10.2 days | the machine, held for that time |
| 500 sessions cut at 32,000 tokens (30,518 on average) | five RTX 3090, 4-bit base | 15,258,750 | 399,444 s = 4.6 days | the same |
| 500 whole sessions | four rented H100, BF16 | 33,683,500 | 201,336 s = 55.9 hours | 223.7 card-hours: $445 at $1.99, $646 at $2.89 |
| the proof run: 30 whole sessions | four rented H100, BF16 | 2,021,010 | 12,080 s = 3.4 hours | 13.4 card-hours: $27 at $1.99, $39 at $2.89 |
| the probe: one hour | four rented H100 | | 1 hour | $7.96 at $1.99, $11.56 at $2.89 |

Prices: RunPod's page updated 2026-11-09, H100 PCIe 80 GB, community $1.99 and secure $2.89 a card-hour
([page](https://www.runpod.io/pricing)); the same page lists an H200 (141 GB) at $3.59 and $5.29 and a B200 (180 GB)
at $5.98 and $7.99. Published runs used 3 to 5 passes (section 5).

### 7.4 The 7-GPU machine has three jobs that cannot share it

- The teacher uses all seven cards while it solves cases.
- Training needs the five RTX 3090.
- The bench's test of the student needs two RTX 3090 for 6 h 58 min 47 s a seed (the base's run): 20 h 56 min for
  three seeds, est.

So at home the order is: the teacher's data run, then training, then the test, each waiting for the one before. A
rented node takes training out of that queue: the teacher keeps solving while the student trains.

## 8. From the trained model to the bench and the rig

1. **Keep the adapter, and merge it onto the full-precision weights.** Never onto a 4-bit copy. Training against 4-bit
   weights and serving another quantization is a known risk (registry E27 holds one report of a loss).
2. **Convert** the merged weights to GGUF with llama.cpp's converter. The text model is one file; the vision part
   would be a second file and is not needed for the bench.
3. **The template inside the file** is the one the training text was rendered with: its hash is checked in the file's
   header before any run.
4. **Quantize the base and the tuned model by one recipe,** so the comparison measures the training and not the
   quantizer. The bench's base run used a maker's own mix (UD-Q6_K_L), which cannot be repeated on other weights.
5. **Check small first:** one prompt, then one checked case of the dataset that was held back from training, run by
   the factory against the tuned file, counting malformed tool calls. The bench is not used for this check.
6. **The test:** the bench's 20 cases, three seeds, the base's harness and settings (Pi 1.2.0, effort `xhigh`,
   context 262,144, the 65,536-token budget), against the untuned base by the same recipe and the teacher's 16 of 20.
   Beside cases passed: attempts that end at the budget and generated tokens per passed case (E14).
7. **The rig:** the file sizes the nine 6 GB cards hold, and time per task by the agent check (E43, E44). The dense
   Qwen3.8-27B ran at 7.5 tok/s on the rig at Q4_0 on 2026-10-22
   ([sister repo](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/what_i_tried.md)).

## 9. Qwen 4

Not released on 2026-11-12: the maker's Hugging Face page lists no model or collection of that name; its newest are
the Qwen3.8 files, updated five days earlier. If it is released before training starts, three things change and the
data does not: the template (the converter takes it as an input, so the sessions are rendered again), the memory and
speed sums of section 7 (by the new model's size and layers), and the base's score on the bench (a new three-seed
series). The sessions, the scans, the selection and the mask stay.

## 10. Not verified

- **The template's exact bytes.** Section 3 is a reading through short quotes. The order of the parts of the system
  turn, and whether an assistant turn without thinking gets an empty thinking block, are not known.
- **Which template the bench's GGUF holds.** Its hash is known (`12827f24…`); its text was not compared with the
  maker's current file, which changed on about 2026-11-07.
- **How the bench's server handles this template's tool calls:** with a handler of its own for this format, or with
  its generic one, which asks for calls in another form. llama.cpp's
  [list](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md) names no Qwen 3.x format. The
  server's log line `Chat format:` and one rendered prompt settle it (E103).
- **Pi's text on the two routes.** That Pi 1.2.0 builds the same system text, tool descriptions and file wrapper on
  the OpenAI-style route as on the recorded Anthropic-style one is assumed, not compared.
- **That Pi 1.2.0 sends earlier thinking back** on the OpenAI-style route with this template: read in the sister
  repo's notes for its agent check, not in a recorded bench request.
- **Whether `/apply-template` takes the tool list** in the bench's server build.
- **Every figure of section 7.** No memory or speed figure for training a 27B model on these cards was found
  published; the per-token memory, the speeds and the H100 ratio are assumptions.
- **Token counts by the student's tokenizer.**
- **Session sizes beyond one project:** six sessions of one application.
- **LoRA support for this model's Gated DeltaNet layers in the training libraries,** beyond Unsloth's statement that
  its guide covers the model.
- **SWE-smith's and SWE-Gym's handling of long sessions and of the loss mask:** not stated in either paper.

## 11. Sources

- Qwen3.8-27B: [card](https://huggingface.co/Qwen/Qwen3.8-27B), [files](https://huggingface.co/Qwen/Qwen3.8-27B/tree/main),
  [`config.json`](https://huggingface.co/Qwen/Qwen3.8-27B/blob/main/config.json),
  [`chat_template.jinja`](https://huggingface.co/Qwen/Qwen3.8-27B/blob/main/chat_template.jinja),
  [`LICENSE`](https://huggingface.co/Qwen/Qwen3.8-27B/blob/main/LICENSE); the maker's [page](https://huggingface.co/Qwen).
- The bench: [elixir-swe-bench](https://github.com/Cinderella-Man/elixir-swe-bench), its result file for Qwen3.8-27B.
- [SWE-smith](https://arxiv.org/abs/2504.21798), [SWE-Gym](https://arxiv.org/abs/2412.21139),
  [SERA](https://arxiv.org/abs/2601.20789),
  [Nebius](https://nebius.com/blog/posts/openhands-trajectories-with-qwen3-coder-480b).
- Tools: Unsloth's [Qwen3.8 guide](https://unsloth.ai/docs/models/qwen3.8/train), TRL's
  [SFT trainer](https://huggingface.co/docs/trl/sft_trainer), llama.cpp's
  [server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) and
  [function calling](https://github.com/ggml-org/llama.cpp/blob/master/docs/function-calling.md).
- Prices: [RunPod](https://www.runpod.io/pricing), updated 2026-11-09.
- This repository: [training time on RTX 3090s](Fine%20tuning%20small%20models%20for%20Elixir/training_time_on_3090s.md),
  [agentic against single-answer data](Fine%20tuning%20small%20models%20for%20Elixir/agentic_vs_sft_data.md),
  [teacher to student](Agentic%20RL%20for%20a%20DeepSeek%20teacher/teacher_to_student_distillation.md),
  [the factory](../../../../factory/README.md), [the dataset's rules](../../../dataset_rules.md).
