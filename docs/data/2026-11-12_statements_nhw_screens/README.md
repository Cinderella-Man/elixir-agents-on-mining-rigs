# The teacher writes the statements of the nerves_hub_web and screens cases (E9, E81)

The teacher model, DeepSeek-V4.1-Flash-1017 (Unsloth's `UD-IQ1_M`, revision `2688c0c3` of
`unsloth/DeepSeek-V4.1-Flash-1017-GGUF`), served by Strata on the 7-GPU machine, writes the statement of each checked
case of two of the dataset's projects: the 27 cases of `nerves-hub/nerves_hub_web` and the 19 cases of `mbta/screens`
that pass the licence scan, 46 in all. Each request goes from the data-mining machine, one at a time, and each answer
goes through the leak check before anything is written. The tool is
[`factory/tools/statements/`](../../../factory/tools/statements/README.md), unchanged since it wrote the first 16
statements ([`2026-11-12_statements_first_20`](../2026-11-12_statements_first_20/README.md)): the same instruction
text (SHA-256 `5e7fc3d6…`), the same leak rule (`statements-leak-v1`), at most 3 answers per case.

**Result:** the run began on 2026-11-12 at 16:34:06 UTC; its tables are added to this page when it ends.

## Which cases

| Project | Cases | Bug fixes | Features | Merged | From |
|---|---:|---:|---:|---|---|
| `nerves-hub/nerves_hub_web` | 27 | 10 | 17 | 2026-10-01 to 2026-11-10 | [`2026-11-12_tasks_nerves_hub_web`](../2026-11-12_tasks_nerves_hub_web/README.md) |
| `mbta/screens` | 19 | 9 | 10 | 2026-08-26 to 2026-11-03 | [`2026-11-12_cases_mbta_screens`](../2026-11-12_cases_mbta_screens/README.md) |

- Every case passed the gate, the licence scan and the hold-out check in the job that made it, and is built on
  Elixir 1.18 or later.
- `screens-pr-3307` is left out: it is checked, but it fails the licence scan.
- The kind is the maker's `task_kind` as it stands in each `case.json`. The maker labels some bug fixes as features
  (registry row E108); no label was changed for this run.
- Before the run no case folder held `ticket.md` or `statement.json`, and each case's starting commit was in its
  project's clone ([`cases_before.tsv`](cases_before.tsv), written by `run/make_list.sh`).
- The order is one project after the other, each newest merged first ([`run/tasks.txt`](run/tasks.txt)).

## The method

As for the first statements ([the method there](../2026-11-12_statements_first_20/README.md#the-method), with the
instruction text in full):

- **One request per answer:** one user message, the text of `instruction.md` with the case's parts filled in (the
  repository's name, the kind, the engine's own instruction text, the change and the hidden tests, each in full), sent
  to the server's `/chat/completions` with the model's name and nothing else. Sampling, the thinking effort and the
  length limit are the server's own defaults. The server's `/props` before the run are the same, field for field, as
  before the first statements: temperature 1.0, top_p 1.0, no generation limit, one slot, a 262,144-token window.
- **The voice** (`docs/dataset_rules.md`, section 5): a developer typing a request to a coding agent in their own
  repository. A bug fix is short and plain; a feature is a long specification.
- **The statement is the model's alone:** the text between the answer's `<statement>` and `</statement>` lines, with
  the white space at its two ends dropped and one newline added. No statement is edited by hand.
- **The leak check** (`statements-leak-v1`, [the rule](../../../factory/tools/statements/README.md#the-leak-rule-statements-leak-v1))
  rejects a statement that holds a line or an identifier that only the change holds, a hidden test's name or file, a
  changed file's name, or the pull request's number or a commit hash. A rejected answer is asked for again with a note
  listing what was rejected, at most 3 answers per case. A case with no accepted answer after 3 gets no statement and
  is reported as such.
- **The stop rules:** a server error does not use up an answer; three in a row, a request that waits more than 10
  minutes for the server, a bench run on the machine or less than 50,000,000,000 bytes free stop the run.
- **Before the run** the tool's own tests ran in the tooling image: 11 of 11 pass.

## Files

| File | What it holds |
|---|---|
| `README.md` | this page |
| `cases_before.tsv` | the 46 cases before the run: project folder, case, kind, merge date, pull request, starting commit, the bytes of the change and of the hidden tests, and that no statement was there |
| `run/tasks.txt` | the 46 cases in the order they ran |
| `run/make_list.sh` | makes the list and `cases_before.tsv`; refuses a list with a case that already has a statement |
| `run/run_all.sh` | the driver: one case at a time, the checks before each, the stop rules |
| `run/wait_cases.sh` | waits for a number of ended cases or the run's end |
| `run/summarize.exs` | the tables, from the driver's records |

## Commands

On the data-mining machine, in the factory's tooling image `etf-tooling:20261112`; every container with the labels
`task-factory=1` and `task-factory-job=hb-statements2` and a CPU share of 256:

```sh
WORK=<the factory's work folder> CLONES=<the folder of the jobs' clones> OUT=<job>/run SKIP=screens-pr-3307 \
  run/make_list.sh nerves-hub__nerves_hub_web=hb-nhw/cache/nerves-hub__nerves_hub_web.git \
                   mbta__screens=hb-screens/cache/mbta__screens.git
docker run --rm --label task-factory=1 --cpu-shares 256 -v <factory>/tools/statements:/tools:ro etf-tooling:20261112 \
  bash -c 'cd /tmp && elixir -r /tools/statement.ex /tools/statement_test.exs'
WORK=<the factory's work folder> TOOLS=<factory>/tools/statements CLONES=<the folder of the jobs' clones> OUT=<out> \
MODEL_URL=<the server's base URL, ending in /v1> KEY_FILE=<the file holding the server's key> MODEL=deepseek-v41-flash \
IMAGE=etf-tooling:20261112 LABEL=task-factory=1 JOB_LABEL=task-factory-job=hb-statements2 PREFIX=etf-statements2 \
CPU_SHARES=256 MIN_FREE=50000000000 \
WRITER_MODEL=DeepSeek-V4.1-Flash-1017 \
WRITER_FILE="unsloth/DeepSeek-V4.1-Flash-1017-GGUF, UD-IQ1_M, revision 2688c0c3" \
WRITER_PRESET="the preset deepseek-v41-flash on Strata v0.2.13: temperature 1.0, top_p 1.0, no generation limit, reasoning effort high (the server's defaults), context 262144, one slot" \
  setsid nohup run/run_all.sh run/tasks.txt > <out>/launch.log 2>&1 < /dev/null &
OUT=<out> run/wait_cases.sh 46
docker run --rm --label task-factory=1 --cpu-shares 256 -v <out>:/out:ro -v <job>/run:/run:ro \
  -v <WORK>/tasks:/tasks:ro -v <tables>:/tables etf-tooling:20261112 \
  elixir /run/summarize.exs /out /run/tasks.txt /tasks /tables
```

## Provenance and licence

The cases come from `nerves-hub/nerves_hub_web` (Apache-2.0) and `mbta/screens` (MIT), each licence checked at every
case's starting commit by the licence scan of the job that made it. The statements are the teacher model's output from
each case's own change and tests; no other text goes into them, and no text written by Claude. The model's own terms
for its output were not read in this job.
