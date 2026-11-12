# The statement writer and its leak check

A task's statement (`ticket.md`, with `statement.json`: [factory README](../../README.md), section 3.4) is written by
the teacher model from the task's own files, and a check outside the engine rejects a statement that gives the fix
away (the design note `docs/research/notes/task_factory_on_the_bench_engine.md`, section 5, job P7; registry rows
Q480 and Q526). The statement is the model's alone: the tool takes the text between the answer's `<statement>` and
`</statement>` lines, drops the white space at its two ends and adds one newline. Nothing else is changed, and no
statement is edited, trimmed, reordered or repaired by hand. The model's thinking text is not part of it.

## Files

| File | What it does |
|---|---|
| `instruction.md` | the text the model is sent, with the task's parts filled in: the repository's name, the task kind, the engine's own instruction text (the solver sees it beside the statement), the change (`reference.patch`) and the hidden tests (`reference-tests.patch`); on a retry, the items an earlier statement was rejected for |
| `statement.ex` | `Statements.Diff` (reads a Git diff), `Statements.Task` (reads a task folder; the engine's text as `Eab.TaskContract.instructions/1` builds it; every line of the starting commit's tree, from a Git clone), `Statements.Leak` (the leak rule), `Statements.Prompt` (the request and the statement's extraction), `Statements.Client` (one request through Erlang's HTTP client), `Statements.Writer` (one task, up to three answers) |
| `write_statement.exs` | one task: the leak items, then the requests, then `ticket.md` and `statement.json` on a pass |
| `leak_check.exs` | the leak check alone, on a statement already written |
| `statement_test.exs` | the tests: a made-up project in a temporary Git repository, a task that changes it, each rule, the extraction, the request, and the writer's retries with a stand-in server |

Standard library only (Elixir 1.18 or later, for `JSON`; Erlang's `:json.format/1`), so it runs in the factory's
tooling image:

```sh
elixir -r statement.ex statement_test.exs
MODEL_URL=<base URL ending in /v1> MODEL_KEY_FILE=<file holding the key> MODEL=<served name> \
WRITER_MODEL=<model> WRITER_FILE=<file and revision> WRITER_PRESET=<server and settings> \
  elixir -r statement.ex write_statement.exs <task folder> <Git clone with the task's commits> <out folder>
elixir -r statement.ex leak_check.exs <task folder> <Git clone> [statement file]
```

`write_statement.exs` exits 0 when a statement passed and was written, 10 when none of `TRIES` (3) answers passed, 13
after three server errors in a row (an error does not use up a try; the same request is sent again after 30 s), and
14 when the server was busy: an answer that waited more than `MAX_WAIT_MS` (600,000) before the server began on it
(its wall time less the server's own prompt and generation times), or no answer within `TIMEOUT_MS` (3,600,000).

## One request

One user message (`instruction.md`, filled in) to the server's `/chat/completions`, with the model's name and
nothing else: sampling, the thinking effort and the length limit are the server's own defaults. On a rejected
statement the next request is the same text with a note that lists what was rejected, so the model can avoid it.

## The leak rule (`statements-leak-v1`)

The check reads the task folder (`reference.patch`, `reference-tests.patch`, `case.json`, `provenance.json`) and
every text line of the starting commit's tree (`git grep -h -I -e '' <commit>`). Identifiers are matches of
`[A-Za-z_][A-Za-z0-9_]*[?!]?`, dotted module names of `[A-Z][A-Za-z0-9_]*(\.[A-Z][A-Za-z0-9_]*)+`. A statement fails
when it contains any of these:

| Rule | What the statement may not contain | How it is matched |
|---|---|---|
| L1 | a line the fix adds that is in neither the starting tree nor the hidden tests' added lines, of 20 or more non-blank characters | runs of white space made one space, in the line and in the statement; the line as a substring |
| L2 | an identifier or dotted module name that the fix's added lines hold and neither the starting tree nor the hidden tests' added lines hold | a code-like identifier (with `_`, a lower-case letter or digit before a capital, or ending in `?` or `!`) and a dotted name: as a whole identifier anywhere; any other such identifier of 3 or more characters: only in code form (in backticks, before `(` or `/<digit>`, or after a `.`) |
| L3 | the name of a `test`, `describe` or `property` that the hidden tests add, of 3 or more words; a module the hidden tests define that the starting tree does not | the name without case, with runs of white space made one space, as a substring; the module as a whole name |
| L4 | the path or file name of a hidden test file, unless the engine's test command (shown to the solver) names it | without case; the file name not preceded by a letter, digit, `_`, `/`, `.` or `-`, nor followed by a letter, digit or `_` |
| L5 | the path or file name of a file the fix adds, changes or deletes | as L4 |
| L6 | the pull request's number, or the start of the starting or merge commit's hash | `#N`, `pull/N`, `PR N`, `pull request N` (without case); 7 to 40 hex digits that begin either hash |

An identifier that the hidden tests use is not a leak (L2 leaves it out): the tests call the code by those names, so a
statement must be able to name them, as the bench's feature specifications name the public interface they require.
An identifier the starting tree already holds is not a leak either: the solver can read it.

A statement with no text between the tags fails as `no_statement`. Every hit is recorded with its rule and item.
