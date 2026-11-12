# The teacher writes the statements of the first ex338 tasks (job P7; E9, E68, E81)

The teacher model, DeepSeek-V4.1-Flash-1017 (Unsloth's `UD-IQ1_M`, revision `2688c0c3` of
`unsloth/DeepSeek-V4.1-Flash-1017-GGUF`), served by Strata v0.2.13 on the 7-GPU machine, wrote the statement of each
checked task of `axelclark/ex338` built on Elixir 1.18 or later: 16 tasks. Each request went from the data-mining
machine, one at a time, and each answer went through the leak check before anything was written. The tool is
[`factory/tools/statements/`](../../../factory/tools/statements/README.md). The server's own timings of every request
are recorded for E81.

**Result: 16 of 16 tasks have a statement that passed the leak check:** 12 on the first answer, 2 on the second and 2
on the third. 6 of the 22 answers were rejected, all for text that only the change holds (below). A statement took
4,247 s in all for the 16 by the wall clock (one task after another, from 10:07:09 to 11:17:59 UTC on 2026-11-12):
344 s for the 6 bug fixes and 3,903 s for the 10 features. Of the 22 answers' 4,226.0 s, the server spent 3,605.4 s
generating (85.3 %) and 619.9 s reading prompts (14.7 %); no request waited for the server longer than 0.1 s. The
16 tasks were imported into a controller, whose import check accepted every statement, and its inventory lists each
with `ticket.md` and `statement.json`.

## Which tasks

The checked tasks of ex338 that pass both the licence scan and the hold-out check
([P6](../2026-11-12_pilot_licence_holdout/README.md), [P6, second batch](../2026-11-12_pilot_licence_holdout_r2/README.md))
and are built on Elixir 1.18 or later (the dataset's rule `elixir_before_1.18`, `docs/dataset_rules.md`, section 2),
newest merged first: the 16 tasks of the maker's second ex338 run ([P5 r2](../2026-11-12_pilot_tasks_ex338_r2/README.md)),
merged from 2024-10-06 to 2026-09-09. 6 are bug fixes and 10 are features by the maker's `task_kind`.

The list changed twice during the job, on the owner's word, and the folder keeps the job's name:

1. **The first list** was the first 10 radiator and the first 10 ex338 tasks by id. 7 radiator statements were
   written with the first instruction ([`instruction_v1.md`](instruction_v1.md)), each passing the leak check, and the
   8th request was stopped when `podlove/radiator` left the dataset (its projects: `docs/dataset_rules.md`, section 1). Those 7
   statements were deleted from their task folders. Their requests stay in the timing table below
   ([`table_radiator_v1.md`](table_radiator_v1.md)): they are measurements of the server, not dataset content.
2. **The instruction changed** to the second version ([`instruction_v2.md`](instruction_v2.md)) before any ex338
   request was sent: a developer's own request to a coding agent, short and plain for a bug fix, long and detailed
   for a feature. Every ex338 statement here was written with it.
3. **Tasks built on Elixir older than 1.18 left the dataset** while the ex338 list ran. The four older ex338 tasks at
   the end of the list (pull requests 1313, 1310, 1302, 1300, built on Elixir 1.16.1) were cut before they started.

## The method

**One request per answer:** one user message, the text of `instruction.md` with the task's parts filled in, sent to
the server's `/chat/completions` with the model's name and nothing else. Sampling, the thinking effort and the length
limit are the server's own defaults, read from its `/props` before the run: temperature 1.0, top_p 1.0, no generation
limit, one slot, a 262,144-token window; the chat template's thinking effort is "high" when the request names none.
The parts filled in:
- the repository's name and the task kind (`bug fix` or `feature`);
- the engine's own instruction text, which the solver reads beside the statement (`Eab.TaskContract.instructions/1`:
  the task kind, the test command, the rule about adding a test);
- the change (`reference.patch`) and the hidden tests (`reference-tests.patch`), each in full;
- on a retry, the list of items the earlier answer was rejected for.

**The statement is the model's alone:** the text between the answer's `<statement>` and `</statement>` lines, with
the white space at its two ends dropped and one newline added. No statement was edited by hand. The thinking text is
not part of it; it is kept with the raw answers, which are not published.

**The leak check** (`statements-leak-v1`, the full rule in the [tool's README](../../../factory/tools/statements/README.md#the-leak-rule-statements-leak-v1))
reads the task folder and every text line of the starting commit's tree. A statement fails when it holds a line the
fix adds (L1) or an identifier the fix adds (L2) that neither the starting tree nor the hidden tests hold, the name
of a test or module the hidden tests add (L3), the path or name of a hidden test file (L4) or of a file the fix
changes (L5), or the pull request's number or a commit hash (L6). An identifier the hidden tests use is allowed: the
tests call the code by those names, as the bench's feature specifications name the interface they require.
A rejected answer is asked for again with a note listing what was rejected, at most 3 answers per task. A server
error does not use up a try; three in a row, a request that waits more than 10 minutes, a bench run on the machine or
less than 700,000,000,000 bytes free would have stopped the run (none happened).

**After the run:** the check ran again on each written `ticket.md` on its own (`leak_check.exs`, [`recheck.jsonl`](recheck.jsonl):
16 of 16 pass), and the 16 task folders were imported into the stopped controller from the factory's set-up
(`bin/factoryctl import`), which refuses a statement record that does not name its writer or does not hold
`ticket.md`'s SHA-256 ([`import.json`](import.json): 16 `imported`; [`inventory.tsv`](inventory.tsv)). The controller
was stopped again.

### The instruction (second version, the one every ex338 statement was written with)

````text
You are writing the request that a developer types to a coding agent working in their own repository, the Elixir
application {{repository}}. The agent gets the repository at the commit just before the change shown below, together
with your request, and nothing else: it never sees the change or the tests shown below. It must then make the change
itself. Afterwards the tests shown below are run on its work.

The task is a {{kind_words}}.

Write as that developer, to the agent, the way a developer really types a request in their own project. No title, no
ticket template, and no "Steps to reproduce", "Expected" or "Actual" headings.

- For a bug fix or any other change that is not a feature: short and plain, the way it is typed in a terminal: what
  goes wrong and where it shows, what it should do instead, and an example value or an error line when the developer
  would have one at hand. A few sentences, with no Markdown structure: no headings and no lists. It must still say
  enough that the fix a reader would make is the one the tests expect.
- For a feature: long and detailed, the way a developer writes it after having been questioned about it in depth
  until every decision was settled: the goal; every decision that was settled, with examples; the edge cases and what
  happens on errors; what is out of scope; what must stay compatible; and the names the rest of the code will use
  (module names, function names and arities, routes, schema fields, configuration keys) where the tests call or read
  them directly, because the agent's code must match those names exactly. Headings and lists are fine here.

Rules:
1. Do not say how to do it: no root cause, no solution steps, no names of files to change or create, no code from the
   change, and no names of functions, modules or fields that only the change introduces and the tests do not use.
2. Name a module, function, field, route or key only when it already exists in the repository, or when the tests
   below call or read it directly.
3. Do not mention tests, test files, test names, checks or grading. Do not mention the pull request, its number, its
   author or any commit.
4. Every behaviour the tests check must follow from your request and the existing code. Do not leave the agent to
   guess a product decision, and do not ask for anything the change and the tests do not support.
5. Write plain English. For anything that is not a feature, keep it as short as the task allows; for a feature, leave
   no settled decision out.
6. Apart from your request, the agent is told this, so do not repeat it:

{{engine_text}}

Answer with the request only, between a line `<statement>` and a line `</statement>`.
{{retry_note}}
## The change (the agent does not see it)

```diff
{{reference_patch}}
```

## The tests run afterwards (the agent does not see them)

```diff
{{reference_tests_patch}}
```
````

On a retry, `{{retry_note}}` is: "An earlier answer for this task was rejected because it contained the following,
which gives the change away or names the tests. Write it again without them:" and one line `- <item>` per item.

## The statements

| Task | Kind | Answers | Verdicts | Statement (bytes) | Wall time (s) | Waited (s) | Prompt tokens | Generated tokens | Reading (tok/s) | Generating (tok/s) | Drafted tokens accepted |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `ex338-pr-1463` | bug_fix | 1 | pass | 507 | 74.3 | 0.0 | 1764 | 2414 | 94.8 | 43.3 | 1387 of 2561 |
| `ex338-pr-1461` | bug_fix | 1 | pass | 553 | 45.1 | 0.0 | 2157 | 1205 | 116.3 | 45.4 | 696 of 1212 |
| `ex338-pr-1460` | feature | 1 | pass | 4069 | 322.5 | 0.1 | 8781 | 12360 | 237.9 | 43.3 | 6888 of 13182 |
| `ex338-pr-1458` | feature | 1 | pass | 2598 | 139.4 | 0.0 | 3444 | 4678 | 132.5 | 41.3 | 2353 of 4819 |
| `ex338-pr-1457` | feature | 1 | pass | 1347 | 88.1 | 0.0 | 2310 | 2823 | 118.7 | 41.2 | 1484 of 3063 |
| `ex338-pr-1452` | bug_fix | 1 | pass | 743 | 66.6 | 0.0 | 5182 | 1494 | 165.6 | 42.3 | 809 of 1589 |
| `ex338-pr-1451` | feature | 1 | pass | 6237 | 273.6 | 0.1 | 18968 | 9585 | 319.9 | 44.7 | 5405 of 9708 |
| `ex338-pr-1450` | bug_fix | 2 | leak, pass | 323 | 35.3, 30.2 | 0.0, 0.0 | 1580, 1614 | 797, 639 | 96.1, 105.4 | 42.3, 43.0 | 459 of 868; 340 of 666 |
| `ex338-pr-1446` | feature | 2 | leak, pass | 2831 | 365.9, 229.7 | 0.0, 0.0 | 8315, 8348 | 13930, 8127 | 235.8, 231.6 | 42.1, 42.0 | 7444 of 14860; 4206 of 8409 |
| `ex338-pr-1411` | bug_fix | 1 | pass | 340 | 26.9 | 0.0 | 1340 | 412 | 92.5 | 33.3 | 207 of 436 |
| `ex338-pr-1398` | feature | 3 | leak, leak, pass | 3387 | 334.7, 240.3, 329.9 | 0.0, 0.0, 0.0 | 7823, 7859, 7859 (7858 cached) | 10660, 8263, 13611 | 119.7, 177.7, 11.9 | 39.6, 42.2, 41.3 | 5514 of 11367; 4386 of 8824; 6935 of 14492 |
| `ex338-pr-1395` | bug_fix | 1 | pass | 613 | 57.5 | 0.0 | 2543 | 1473 | 115.5 | 41.6 | 795 of 1586 |
| `ex338-pr-1394` | feature | 1 | pass | 1855 | 191.8 | 0.0 | 3941 | 6409 | 146.1 | 38.9 | 3289 of 6980 |
| `ex338-pr-1392` | feature | 1 | pass | 2421 | 137.8 | 0.0 | 3303 | 4989 | 138.2 | 43.8 | 2789 of 5254 |
| `ex338-pr-1390` | feature | 1 | pass | 2764 | 333.7 | 0.0 | 4056 | 13105 | 147.2 | 42.8 | 7126 of 13965 |
| `ex338-pr-1350` | feature | 3 | leak, leak, pass | 2063 | 303.6, 274.3, 324.9 | 0.0, 0.0, 0.0 | 3639, 3728, 3739 | 12118, 10716, 13103 | 131.5, 136.3, 137.7 | 43.9, 43.4, 44.0 | 6912 of 12849; 5927 of 11448; 7449 of 14043 |

The first list's radiator requests, with the first instruction (statements removed: project outside the dataset):

| Task | Kind | Answers | Verdicts | Statement (bytes) | Wall time (s) | Waited (s) | Prompt tokens | Generated tokens | Reading (tok/s) | Generating (tok/s) | Drafted tokens accepted |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `radiator-pr-510` | feature | 1 | pass | 1756, removed | 119.2 | 0.0 | 5854 | 3167 | 139.4 | 41.0 | 1796 of 3333 |
| `radiator-pr-541` | bug_fix | 1 | pass | 923, removed | 263.8 | 0.0 | 7616 | 8888 | 171.9 | 40.5 | 4503 of 9421 |
| `radiator-pr-542` | bug_fix | 1 | pass | 1622, removed | 122.4 | 0.0 | 3344 | 4401 | 138.9 | 44.8 | 2534 of 4617 |
| `radiator-pr-550` | bug_fix | 1 | pass | 1289, removed | 229.3 | 0.0 | 3295 | 8782 | 147.4 | 42.4 | 4829 of 9746 |
| `radiator-pr-552` | feature | 1 | pass | 1292, removed | 217.4 | 0.0 | 3065 | 8601 | 137.4 | 44.1 | 4910 of 9216 |
| `radiator-pr-554` | feature | 2 | leak, pass | 1606, removed | 242.6, 254.1 | 0.0, 0.0 | 6950, 7010 | 8606, 9301 | 177.4, 184.4 | 42.3, 43.0 | 4665 of 9289; 5143 of 10045 |
| `radiator-pr-556` | feature | 1 | pass | 2023, removed | 293.6 | 0.0 | 6124 | 10891 | 163.4 | 42.5 | 5881 of 11580 |
| `radiator-pr-558` | feature | 0 | | none: stopped when the list changed | | | | | | | |

Each number is one request; a task with several answers lists them by value, in order. *Prompt tokens* is the
server's count; *reading* and *generating* are the server's own `prompt_per_second` and `predicted_per_second`;
*waited* is the request's wall time less the server's prompt and generation times. The third answer of
`ex338-pr-1398` repeated the second's prompt word for word (the same rejected items), and the server reused 7,858 of
its 7,859 tokens (`cache_n`), so its reading speed counts one token. Every row with all its fields:
[`tries.tsv`](tries.tsv); one row per task: [`statements.tsv`](statements.tsv). The statements themselves:
`statements/<task>/ticket.md` with `statement.json`.

**What the leak check rejected** (6 of 22 answers):

| Task | Answer | Rule and item |
|---|---|---|
| `ex338-pr-1450` | 1 | L2 `YOUR_TOKEN` (a placeholder in the page the change adds) |
| `ex338-pr-1446` | 1 | L2 `Private?` (a form label the change adds) |
| `ex338-pr-1398` | 1, 2 | L1 `Draft Grades & Analysis` (a page heading the change adds) |
| `ex338-pr-1350` | 1 | L1 `PRODID:-//Ex338 ICalendar//EN` and L1 a sentence of the page's link text, both lines the change adds |
| `ex338-pr-1350` | 2 | L2 `VCALENDAR`, `VEVENT` (iCalendar's own words, written in code form, which only the change holds) |

None named a function, a module or a file the change adds, a test or the pull request. On the first list, one of the
8 radiator answers was rejected (`radiator-pr-554`, answer 1: two error tuples and the atom
`node_count_not_consistent` that only the change holds).

**The statements by kind:** each of the 6 bug fixes is a few plain sentences (507, 553, 743, 323, 340 and 613 bytes
for 1463, 1461, 1452, 1450, 1411 and 1395); the 10 features are specifications with headings and lists (4,069, 2,598,
1,347, 6,237, 2,831, 3,387, 1,855, 2,421, 2,764 and 2,063 bytes for 1460, 1458, 1457, 1451, 1446, 1398, 1394, 1392,
1390 and 1350).

## The server's timings (E81)

| Requests | Answers | Wall time (s) | Reading: tokens, s, tok/s | Generating: tokens, s, tok/s | Drafted tokens accepted |
|---|---:|---:|---|---|---|
| ex338, instruction v2 | 22 | 4,226.0 | 104,435 read (112,293 in the prompts, 7,858 from the cache), 619.9 s, 168.5 tok/s | 152,911, 3,605.4 s, 42.4 tok/s | 82,800 of 162,181 (51.1 %) |
| radiator, instruction v1 (statements removed) | 8 | 1,742.6 | 43,258, 269.7 s, 160.4 tok/s | 62,637, 1,472.6 s, 42.5 tok/s | 34,261 of 67,247 (50.9 %) |
| the one-line question before the run | 1 | 1.0 | 43, 0.6 s, 70.5 tok/s | 20, 0.4 s, 46.2 tok/s | 13 of 20 |

The totals are sums over the requests; the speeds in the table of statements are each one request.
- **Generation is most of the time:** 85.3 % of the ex338 answers' wall time. Per request (each value in the table)
  the slowest was 33.3 tok/s (`ex338-pr-1411`, 412 tokens) and the fastest 45.4 tok/s (`ex338-pr-1461`). One
  answer's thinking and statement come in one stream, and the server reports their tokens together
  (`completion_tokens`; the raw answers keep the two texts apart).
- **Reading is faster on longer prompts:** 92.5 tok/s for 1,340 tokens (`ex338-pr-1411`), 319.9 tok/s for 18,968
  (`ex338-pr-1451`).
- **The prompt cache:** only a word-for-word repeat reused it (above); a retry whose note changed, and consecutive
  tasks whose prompts share the instruction's first lines, were read from the start (`cache_n` 0 in every other
  request).
- No request waited for another client: the largest gap between a request's wall time and the server's own times is
  0.1 s.

## Files

| File | What it holds |
|---|---|
| `README.md` | this page |
| `instruction_v1.md`, `instruction_v2.md` | the two instruction texts (SHA-256 `c8c8d908…` and `5e7fc3d6…`, recorded in each `statement.json` as `instruction_sha256`) |
| `statements/<task>/ticket.md`, `statement.json` | the 16 statements and their records: the writer (model, file and revision, the server's preset and defaults, the instruction's SHA-256), `ticket_sha256`, `written`, the answer it came from, the leak rule |
| `table.md` | the table of statements above |
| `tries.tsv` | one row per answer: times, token counts, the server's timings (`prompt_n`, `cache_n`, `prompt_ms`, `predicted_ms`, the speeds, `draft_n`, `draft_n_accepted`), the bytes of the thinking and of the answer, the leak hits |
| `statements.tsv` | one row per task: kind, outcome, answers, verdicts, the statement's bytes and SHA-256 |
| `tasks.tsv`, `run.log` | the driver's own record: each task's exit code, start, end and seconds; the free space before each task |
| `recheck.jsonl` | the leak check run again on each written statement |
| `import.json`, `inventory.tsv` | the controller's import of the 16 task folders, and its inventory after it |
| `table_radiator_v1.md`, `tries_radiator_v1.tsv`, `statements_radiator_v1.tsv` | the first list's 8 radiator requests (7 statements written, then removed; the 8th stopped when the list changed, recorded as a server error) |
| `run/run_all.sh` | the driver: one task at a time, the checks before each, the stop rules |
| `run/summarize.exs` | the tables, from the driver's records |
| `run/inventory_check.sh` | the controller's import and inventory |
| `run/tasks.txt`, `run/tasks_before_change.txt` | the 16 tasks as run, and the first list |

## Commands

On the data-mining machine, in the factory's tooling image `etf-tooling:20261112`; every container with the label
`task-factory=1` and a CPU share of 256:

```sh
WORK=<the factory's work folder> TOOLS=<factory>/tools/statements CLONES=<bare clones of the projects> OUT=<out> \
MODEL_URL=<the server's base URL, ending in /v1> KEY_FILE=<the file holding the server's key> MODEL=deepseek-v41-flash \
IMAGE=etf-tooling:20261112 LABEL=task-factory=1 \
WRITER_MODEL=DeepSeek-V4.1-Flash-1017 \
WRITER_FILE="unsloth/DeepSeek-V4.1-Flash-1017-GGUF, UD-IQ1_M, revision 2688c0c3" \
WRITER_PRESET="the preset deepseek-v41-flash on Strata v0.2.13: temperature 1.0, top_p 1.0, no generation limit, reasoning effort high (the server's defaults), context 262144, one slot" \
  run/run_all.sh run/tasks.txt
elixir run/summarize.exs <out> run/tasks.txt <WORK>/tasks
elixir -r <factory>/tools/statements/statement.ex <factory>/tools/statements/leak_check.exs <task folder> <clone>
CTL=<controller folder> NAME=<controller> SRC=<factory> CONTROLLER=<the set-up's controller.sh> \
IMPORT=<WORK>/tasks/<folder of the 16 tasks> OUT=<out> run/inventory_check.sh
```

The set-up's `controller.sh` is in [`2026-11-12_factory_data_mining_machine/run/`](../2026-11-12_factory_data_mining_machine/run/controller.sh).
The tool's tests (`elixir -r statement.ex statement_test.exs`): 11 of 11 pass with each instruction; the factory's
parity test (`test/eab/bench_parity_test.exs`): 6 of 6 with each.

## Provenance and licence

The tasks come from `axelclark/ex338`, MIT at every task's starting commit (each task's `provenance.json`; the licence
scan). The statements are the teacher model's output from the task's own change and tests; no other text went into
them, and no text written by Claude. The model's own terms for its output were not read in this job.
