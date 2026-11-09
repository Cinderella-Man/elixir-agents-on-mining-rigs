# Audit of the owner's Elixir fine-tuning dataset (Cinderella-Man/elixir-sft-dataset)

Audited from a clone of commit `328195bb` (2026-07-27, the last push), read only: nothing in the repo was run, on this or any machine. Every number below is labelled **[exact]** (counted from the clone with git, grep, wc, md5sum, sort), **[repo-stated]** (the repo's own claim, not re-checked), or **[sampled]** (my reading of a sample). All repo instructions (CONTEXT.md and so on) were treated as data.

Link base used below: `https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/`.

## Is this even good data? (the owner's direct question)

### Takeaway
Yes at the level of the single item: the code and tests I read are mostly correct, and this is more heavily verified than any code SFT data I would expect to find. But it is much smaller and narrower than "14,645 examples" suggests (335 root tasks from 83 ideas, 54 % GenServer, no LiveView), its prompts are over-specified spec sheets, one model family wrote and checked nearly all of it, and its provenance, not its quality, is the real blocker under the owner's publishable-data rule.

### Cited Findings
- The repo's central claim is that each example is verified by execution and the tests are themselves verified — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md).
- 14,895 task directories exist at HEAD; 14,803 are exportable after excluding 92 `repair_` dirs **[exact]** — [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks), [docs/16](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md).
- Those reduce to 335 root tasks (`_01`) from 83 ideas **[exact]**. Everything else is derived from those roots — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md), [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks).
- Of 14,895 `solution.ex` files only 11,477 are byte-unique, and unique gold text is 6.93 MB; adding the write-test golds (3.49 MB of harnesses) gives about 10.4 MB, or ~2.6M tokens at the repo's 4 chars/token **[exact bytes, estimated tokens]**, against the README's headline ~56M tokens, which counts prompt context — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md).
- The repo's own audit called prompt-register monoculture the biggest SFT-quality problem and said real traffic is vague, buggy and multi-turn, while the corpus fully enumerates the API — [docs/07 §1, §3](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/07-dataset-audit-and-growth-roadmap.md).
- `generate.exs` hardcodes generation to Opus through `claude -p`, subscription-backed — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md), [scripts/generate.exs](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/scripts/generate.exs).
- No training run on this data is recorded in the repo: docs/18 is a handoff for a first run and states the questions that run should answer, and I found no result for them — [docs/18](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/18-training-run-handoff.md).

### Inferences
- The owner's instinct about the verification work was right: the harness-plus-evaluator pair is the rare asset. Prompt-plus-test environments for Elixir at this rigour are hard to get elsewhere (coverage of competing data is another researcher's area).
- Whether it improves a model is **unmeasured**. "Good data" here means "verified", not "shown to help". The repo itself lists that as an open question.
- Ranking of what limits it, biggest first: (1) licence and provenance, (2) only 335 root tasks, and variations of one idea are not fully independent of each other, (3) one voice and over-specified prompts, (4) coverage gaps. Item-level correctness is not on that list.

### Gaps
- Effect on any model: no training run exists to judge from.
- Nothing was executed, so "passes its tests" and all sweep results are repo claims, backed only by the ledgers in `logs/`.

## What is in the repo, and how are tasks produced, validated and reviewed?

### Takeaway
It is a Mix project holding `tasks/` (the corpus), an evaluator (`lib/eval_task/`), an Opus-driven generation loop (`lib/gen_task/`), about 60 scripts and 20 design docs. Quality control is a stack of about a dozen gates, and `logs/` holds 34,722 tracked evidence files.

### Cited Findings
- Layout: `tasks/` 313 MB, `logs/` 257 MB, `docs/` 904 KB (20 numbered docs plus `prototypes/`), `scripts/` 848 KB (63 entries), `lib/` 636 KB, `test/` 1.2 MB **[exact]** — [repo tree](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb). GitHub reports 107 MB, which is the compressed size.
- `results/` holds one empty file, so no exported JSONL is in the repo (0 `train.jsonl`/`val.jsonl` tracked **[exact]**). Export is a build step: `mix run scripts/export_dataset.exs` — [docs/16 §6](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md).
- `.claude/` holds only an empty `skills/` folder and `.agents/` holds one third-party skill (`grill-me`, from `mattpocock/skills`) — neither touches the data — [skills-lock.json](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/skills-lock.json).
- `logs/` is listed in `.gitignore`, yet 34,722 files in it are tracked **[exact]**, including 1,098 attempt-chain folders in `logs/attempts` — [.gitignore](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/.gitignore).
- CONTEXT.md is mostly historical: its "At a glance" still says 165 task dirs and "all hand-authored", and two banners at the top warn it is out of date; the current reading order is rule section, STATUS, docs/14 — [CONTEXT.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/CONTEXT.md).
- Gates the repo describes **[repo-stated]**: perfect score (compiles, zero warnings, all tests green, style), per-function raise mutants, semantic-mutant kill floor, blind solve, repair guards, canonical format, embed staleness, flake ledger, benchmark decontamination, Dialyzer on `@spec`s — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md).
- The README's scoring formula is `tests·0.7 + analysis·0.2 + compilation·0.1` with four hard-fail conditions — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md).
- Latest full sweep **[repo-stated]**: perfect-score pass on 14,884 tasks, FIM mutation all pass, whole-solution mutation pass on touched families only — [STATUS.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/STATUS.md).
- Ledger counts **[exact, historic rows, so they include findings fixed since]**: 1,366 Dialyzer rows (1,312 clean, 50 warnings, 4 waived); 359 flake rows; 417 rubric rows; 395 semantic-review verdict rows (233 with a confirmed finding); raw review findings by class were 850 harness gaps, 236 gold defects, 54 prompt defects — [logs/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/logs).
- Those LLM reviews found real bugs in golds that had already passed every gate, for example a wrong elapsed formula in `074_001` and a gold in `061_001` that ignored the prompt's required scheduling method — [docs/19](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/19-gold-defect-triage.md). The same doc also records reviewer hallucinations, later refuted against the current file.
- All docs/19 findings are reported closed on 2026-07-22 — [docs/15](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/15-completed-work-log.md). docs/19 itself still shows 38 unstruck `- [ ]` lines **[exact]**; I read them as stale checkboxes, since docs/15 is the stated record.
- The repo snapshot is mid-run: STATUS says the extension loop was running at the last push and README numbers are dated 2026-07-19, so disk counts differ slightly (tfim 6,658 on disk vs 6,515 in the README, seeds 335 vs 332) — [STATUS.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/STATUS.md).

### Inferences
- "Perfect score" is necessary, not sufficient, by the repo's own evidence: gold defects passed all gates until an LLM reader caught them. That review reached roots, so derived shapes inherit fixes through cascades; more undiscovered defects are likely at a low rate.
- The style gate is weaker than "every public function is documented" reads. It was a presence check in the version CONTEXT documents, and I saw public functions with no `@spec`/`@doc` in `024_001` and `061_001`.

### Gaps
- I skimmed rather than read `docs/10`, `docs/12`, `docs/14`, `docs/15`. CONTEXT.md's per-family catalogue (roughly line 530 on) was read by heading only.
- Current status of `lib/eval_task/analysis.ex` was not read, so the "presence check" point rests on CONTEXT plus my samples.

## Status and category census: what is covered, what is missing?

### Takeaway
54 % of roots are GenServers. Plain OTP and stdlib are deep; web is thin but real; LiveView, Channels, `gen_statem`, protocols, Mix tasks, Oban, Broadway and telemetry are absent. Macros barely appear.

### Cited Findings
- Tasks by shape at HEAD **[exact]**: roots 335 (of which 6 multi-file), code FIM 3,558, test FIM 6,658, spec FIM 1,824, bugfix 964, write-tests 331, TDD 326, dedoc 326, adapt 249, dialogue 182, style 50, repair 92 (not exported) — [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks).
- Each idea has 4 variations (`b` = 001–004), and only 3 ideas have a fifth; family size runs from 106 to 295 dirs **[exact]** — [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks).
- There is no per-task status field; `tasks/tasks.md` and `tasks_external.md` catalogue ~1,000 ideas, of which 83 are built (8.3 %) — [docs/07 §1](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/07-dataset-audit-and-growth-roadmap.md).
- Root-solution feature census, number of 335 roots whose `solution.ex` matches **[exact, grep over-counts slightly]** — [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks):

| Feature | Roots | Feature | Roots |
|---|---:|---|---:|
| `use GenServer` | 181 | `defmacro` / `__using__` | 4 / 4 |
| `:ets.` | 21 | `@behaviour` | 10 |
| Task.async family | 23 | `Registry.` | 3 |
| `Plug.Conn` / `use Plug` | 20 | Supervisor family | 5 |
| Changeset (or `cast(`) | 17 | `use Ecto.Schema` | 8 |
| `Process.monitor` | 16 | Ecto.Query | 7 |
| `Stream.` | 14 | Phoenix controller/router | 4 |
| StreamData | 4 | Ecto.Migration | 8 |

- Zero roots match: LiveView, Phoenix Channels/PubSub, `Ecto.Multi`, `gen_statem`, GenStage/Broadway, Oban, Absinthe, Nx, `defprotocol`/`defimpl`, `Mix.Task`, telemetry, `use Application`, HTTP clients **[exact]** — [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks).
- The audit's coverage table agrees: LiveView, Channels, Oban, Absinthe and HTTP clients at 0 realised ideas, and it notes `req`, `nx`, `explorer`, `phoenix_live_view` and `mox` are installed but unused — [docs/07 §1, §7](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/07-dataset-audit-and-growth-roadmap.md). Its "macros: 0" figure is older; 4 roots use `defmacro` today.
- Multi-file work is 6 roots: `016_001`, `017_001`, `018_001`, `019_001`, `021_001`, `102_001`, all `<file path=…>` bundles **[exact]**. No task is a full Mix project; the evaluator's kit supplies the Phoenix host — [lib/eval_task/phoenix_kit.ex](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/lib/eval_task/phoenix_kit.ex), [016_001 manifest](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/tasks/016_001_paginated_list_endpoint_01/manifest.exs).
- Ideas skew to infrastructure toys (limiters, breakers, caches, CRDTs, "Mini S3", "Mini Prometheus"); daily Phoenix/Ecto application work is a minority. The audit notes the catalogue itself tilts toward reimplementing libraries rather than using them — [docs/07 §7.2](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/07-dataset-audit-and-growth-roadmap.md).

### Inferences
- For a model aimed at Phoenix/Ecto application work, this corpus covers the wrong half of Elixir. For OTP-flavoured library code, it is strong.
- The missing shapes could not be fixed by more derivation, only by new roots.

### Gaps
- Grep counts text matches, not real use (for example a mention in a `@moduledoc`), so treat the census as ±a few.

## Record format, tests, versions, and the split

### Takeaway
A sample is a directory with `prompt.md`, `solution.ex` and (for roots) `test_harness.exs`, exported as chat JSONL. Elixir 1.20.2 / OTP 29 is pinned. The split is family-atomic, deterministic and thin (17 root tasks in val), and it has one real leak: val family `065` is the same Saga problem as train family `070`.

### Cited Findings
- Export row: `messages` (user is `prompt.md` verbatim, assistant is the gold in one ```elixir fence) plus `metadata` (`task`, `shape`, `family`, `split`, `sample_weight`, `family_size`, shas, `difficulty_tier`, screen counts); no system prompt — [docs/16 §2](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md).
- Gold per shape is defined there; the exception is `write_test`, whose gold is the harness, and FIM is exported as ordinary chat rather than `<PRE>/<SUF>/<MID>` — [docs/16 §2.1–2.2](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md).
- `dialogue` rows are multi-turn from real captured attempts; the doc recommends final-turn-only loss, because the intermediate turns are rejected code — [docs/16 §5b](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md).
- Versions: `.tool-versions` pins `elixir 1.20.2-otp-29` and `erlang 29.0.3`; CI reads the same file via `erlef/setup-beam`, with Postgres 16 for the single DB task; the README warns that gate results reproduce only on the pin — [.tool-versions](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/.tool-versions), [validate.yml](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/.github/workflows/validate.yml), [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md).
- Split rule: val iff the first 8 hex of sha256("split-v1:" + idea number), mod 20, equals 0 — [docs/16 §3](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md). I recomputed this over the 83 ideas and got exactly `032, 065, 073, 108` **[exact]**, matching [docs/18](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/18-training-run-handoff.md).
- Val is 605 exportable dirs at HEAD (170 + 130 + 143 + 162) but only **17 root tasks** (4 + 5 + 4 + 4) **[exact]**. docs/18 gives 594 examples at the `export-v1-14645` tag.
- A family-atomic split exists because 91.7 % within-family overlap is built in; a random split measures memorisation — [docs/16 §1](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md).
- **Leak found:** `065_001` (val) and `070_001` (train) are both named `saga_compensating_transaction_coordinator`. Both define `Saga.new/0`, `Saga.step/4` and `Saga.execute/2` with the same semantics, differing mainly in the error tuple — [065_001 prompt](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/tasks/065_001_saga_compensating_transaction_coordinator_01/prompt.md), [070_001 prompt](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/tasks/070_001_saga_compensating_transaction_coordinator_01/prompt.md). Text overlap is low (19 shared lines of 96 and 145 unique lines in the golds, excluding blanks and `end` **[exact]**), so this is an idea leak, not a copy.
- Repeated top-level module names across ideas: `Saga` (065, 070) and `LRUCache` (006, 041) **[exact]**. Other same-concept pairs in train: `001`/`101` sliding-window counting, `007_003`/`110_001` percentiles — [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks).
- Benchmark decontamination reports 0 exact and 0 near matches against 786 rows of MultiPL-E, McEval and Exercism **[repo-stated]**, with idea-level overlap conceded — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md).

### Inferences
- With 17 roots, a solve-rate estimate has a standard error of about ±12 points at 50 % (my calculation), too coarse to compare two fine-tunes; all 335 roots, on a model that never trained on them, would give about ±2.7.
- The split is honest engineering with a small flaw. Moving ideas 065 and 070 into the same split, a one-line `split-v2`, removes the Saga leak. Keeping val at 4 of 83 ideas stays the larger weakness.
- Results on code using the 1.20 pin may not transfer to older Elixir: the corpus legally uses newer stdlib, such as `JSON` in `131_001`.

### Gaps
- Near-duplicates were spot-checked by name and by reading, not computed corpus-wide; a proper n-gram or embedding pass should run on the quant machine.

## Quality sample: what did 28 tasks actually look like?

### Takeaway
Gold code is correct-looking and competent, sometimes excellent, with recurring small idiom warts. Tests are usually strong. The weakest part is prompts: strikingly complete, often unnaturally so, and a few visibly reverse-engineered from the tests. Derived shapes range from genuinely useful (dialogue, adapt, write-tests) to near-empty (spec FIM, one-token bugfix).

### Cited Findings
Judgements below are mine **[sampled]**, picked across categories, not the first 20: 18 roots and 10 derived tasks. Ten roots had their prompt and all or most of their gold read; the other eight were read in part, as stated per row. Harnesses were read in full for none; I used the opening of two, test-name lists for three, and mutant ledgers. "Mutants" is the last ledger row for that task in [semantic_mutants.jsonl](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/logs/semantic_mutants.jsonl); "blind" is green rows over all rows in [screen_blind.jsonl](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/logs/screen_blind.jsonl). Some of those rows predate later prompt or gold fixes. Task paths are all under [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks).

**Roots**

| Task (area; read depth) | Prompt realism | Gold | Tests: would a wrong answer pass? |
|---|---|---|---|
| `076_001_trie` (data structure; all of P+G, harness part) | Good, conversational | Good. Leftover bodiless `defp`; doc says the marker is only cleared, code also prunes | Strong on spec (mutants 14/14; blind 3/3), but ASCII only, so a byte-based trie passes |
| `091_001_workflow_state_machine` (business; P+G) | Fine, but a complete transition table leaves nothing to infer | Excellent, tight, idiomatic | Strong (10/10; blind 2/2) |
| `100_001_totp` (security; P+most of G) | Good, grounded in the RFC | Very good | Strong: RFC vectors. 31/40; survivors cluster in base32 tail arithmetic (blind 2/4) |
| `086_001_shopping_cart` (business; P+G) | Weak. Floats for money, and a section saying totals "are asserted to within" ±0.001 | Correct. `%Cart{}` in specs instead of `t()`; `@enforce_keys` on defaulted fields; doc examples are not valid doctests | Strong: boundary 9/10, threshold crossing (23/23; blind 4/7) |
| `061_001_parallel_map` (concurrency; P+G) | Poor. Forbids `Task.async_stream`, the idiomatic tool | Works, but traps exits in the caller and polls `yield_many(20)`; helper has no `@spec`; doc example is not real output | Strong and real-timing-based: peak ≤ 3, peak ≥ 2, kills. 22/29; blind 1/7, keep class |
| `024_001_webhook_receiver` (Plug; P+G) | Good ticket voice; uses Stripe's header name but not Stripe's format | Clean, `Plug.Crypto.secure_compare`. Client functions lack `@spec`/`@doc` | Mostly strong (32/33). Survivor: fallback `verify/3` clause `:error -> :ok` |
| `016_001_paginated_list` (Phoenix/Ecto, multi-file; P+G) | Realistic, but appended text discusses "test fixtures" and how "the tests dispatch" | Good; references `Item.t()` with no `@type t`; several modules lack `@moduledoc` | 14/20; the survivors I checked include equivalents (page default is 1) |
| `074_001_custom_exunit_assertion_helpers` (macros; P+most of G) | Poorest seen. Requires labels with "no digit characters in between" and an invented readiness rule | Correct macros and `bind_quoted`, but `unless` | 18/18; blind 5/8. docs/19 records a wrong elapsed formula that passed gates until review |
| `005_001_pubsub_event_bus` (OTP; P+most of G) | Formal "Specification" voice, adequate | Solid, correct monitor cleanup | Good (10/11) |
| `131_001_streaming_json_parser` (data; P+G) | Prescribes each step, so "parser" reduces to splitting lines | Good, modern `JSON`. `case bool` where `if` fits | 23/27; survivors are unit constants timing can't pin |
| `032_001_json_to_ecto_ingestion` (Ecto, val; P, first 70 lines of G) | Self-contradicting: "large" file but mandates `File.read/1` | Long (12.8 KB); tells insert from update by a one-second timestamp tolerance, a hack | Not assessed |
| `041_001_lru_cache_ets` (ETS; first 46 prompt lines) | 7.7 KB; fixes table names, visibility and counter increments. Spec, not request | Not read | 13/13 |
| `075_001_generators` (StreamData; P head, G head) | Long ticket, exhaustive | Good, odd `alias StreamData, as: SD` | Not assessed |
| `036_001_markdown_parser` (parsing; prompt only) | **Best seen**, sounds like a person | Not read | 5/5, small |
| `065_001` / `070_001` saga (prompts only) | Clear; same problem twice | Not read | Not assessed |
| `001_004_penalty_escalation` (OTP; prompt and harness heads) | Dense bullet spec | Not read | Fake `Clock` Agent, deterministic |
| `625_001_mini_s3` (prompt head) | "Design brief" for a whole service in one GenServer | Not read | Not assessed |

**Derived shapes** (prompt head and tail, plus gold)

| Task | What it is | Value |
|---|---|---|
| `dialog_001_003_hierarchical_limiter_01_audit` | Spec, failed attempt, real test failure, accepted fix | **High.** Real debugging data. Only 24 of 182 have a second attempt, 5 a third |
| `adapt_061_002_fail_fast_parallel_map_with_cancellation` | Existing module plus new spec gives modified module | **High.** Real brownfield skill |
| `wt_076_001_trie` | Module and spec give a test suite | **High**, but the template demands `async: false` on all 331 prompts while 32 golds use `async: true` **[exact]** |
| `076_001_trie_03` (code FIM) | One private helper, blanked | Medium-high. Good context; the prose nearly dictates the answer ("Start the local result as `[acc]`") |
| `tdd_076_001_trie` | Tests as spec | Medium; gold is a byte copy of the root |
| `dedoc_076_001_trie` | Strip docs, restore them | Medium; gold is a byte copy of the root |
| `tfim_076_001_trie_02` | Whole module and suite, one test blanked | Low. Gold is 114 bytes, a four-line test |
| `bugfix_005_001_pubsub_event_bus_01` | One token flipped (`:ok` to `:error` in `init/1`), and 18 of 18 tests fail | Low. Bug is trivial, and the gold is the whole parent module |
| `style_024_002_replay_protected_timestamped_webhook_receiver_01_00` | Add missing `@spec`s | Low. Teaches the house rubric |
| `specfim_041_001_lru_cache_backed_by_ets_02` | Write `@spec start_link(keyword()) :: GenServer.on_start()` | **Near zero.** That exact gold appears 161 times |

Corpus-level counts backing this:
- Idiom **[exact]**: `unless` appears 42 times in 33 of 335 roots. It is soft-deprecated from Elixir 1.18 — [Elixir 1.18 changelog](https://elixir.hexdocs.pm/1.18.0/changelog.html). `String.to_atom` in 5 roots, `@impl` in 180 of 335, `Process.sleep` in 5 gold solutions.
- Openers **[exact]**: `Write me` 54, `# Design` 48, `Hey —` 27, `I need` 14, `# Specification:` 14, `# Ticket:` 13; 211 of 335 start with a Markdown heading. A script exists to rewrite the former "Write me an Elixir…" openers into such voices by LLM, so much of this variety is itself Opus output — [rewrite_seed_registers.exs](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/scripts/rewrite_seed_registers.exs).
- Prompts **[exact]**: 292 of 335 contain "single file"; 291 contain a stdlib-only phrase; 335 name the module or API in backticks; 33 carry an "interface contract" section; 16 mention tests or the harness.
- Harness idioms **[exact]**: `:sys.get_state` in 0 of 335; `Process.sleep` in 86; `assert_receive` in 89; a fake `Clock` in 64; `async: false` in 302 and `async: true` in 33, so `async: false` reaches far past the 181 GenServer roots.
- Harness size **[exact]**: 7,269 tests over 335 roots, median 21 per root (p10 14, p90 31, max 52).
- Semantic mutant kill rate, latest row per root **[exact from ledger]**: median about 86 %, p10 about 66 %. The repo reports 83.7 % corpus-wide on 2026-07-23 and warns all rows are now stale by construction — [STATUS.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/STATUS.md).

### Inferences
- The tests are this repo's best feature. Of the roots whose harness I assessed, I would call most strong. Weak spots are specific: unstated inputs (Unicode in the trie), unreachable clauses, timing constants.
- Prompts tell a model what to do so exactly that the hard part of real requests, deciding the design, is absent. The gates push the same way: a blind-solve gate rewards adding detail until Opus passes, which is how lines such as the `074_001` label rule arise. Fixing a real defect (hidden requirements) created another (unnatural specificity).
- 33 of 335 is a tolerable rate for test-aware prompts, and it is trivially filterable.
- Gold style is consistent but opinionated: banner comments (179 roots) and `@spec` on private functions are house habits rather than community norms, and a model will learn them.
- `unless` is a cheap automated fix: `mix format --migrate` handles it, per the changelog.

### Gaps
- 28 tasks is a small sample; it can show kinds of problems, not their rates. Harnesses were mostly judged by test names plus ledger rows.
- Some mutant survivors are equivalent mutants, and the repo's measure does not separate them cleanly.

## Provenance and licence

### Takeaway
There is no licence of any kind, ever, in the repo's history. Most roots added from July 2026 were generated by Claude Opus through a subscription-backed CLI; the April roots came from a manual workflow that used an LLM the repo doesn't name; and later edits to root files were largely made in commits with a Claude Fable 5 co-author trailer. On its face this conflicts with the owner's publishable-data rule, and it needs the owner's decision before any published model trains on it.

### Cited Findings
- GitHub reports `license: null`, and `git log` over `LICENSE*`/`COPYING` across all history returns 0 commits **[exact]** — [repo](https://github.com/Cinderella-Man/elixir-sft-dataset). No licence statement exists in the README or `mix.exs`.
- Generation model: the README and the code both say Opus, invoked as `claude -p --model opus`, with `ANTHROPIC_API_KEY` unset so the CLI uses the subscription login — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md), [lib/gen_task/opus.ex](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/lib/gen_task/opus.ex). The comment in `generate.exs` says a session default such as Fable can never silently become the generation model, without giving a reason — [generate.exs](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/scripts/generate.exs).
- Who writes what in the loop: Opus writes `prompt.md` and `test_harness.exs` in one step, then solves the prompt into `solution.ex` without seeing the tests, then repairs on failure — [lib/gen_task/base.ex](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/lib/gen_task/base.ex). Most derived shapes are minted deterministically from those files, so they inherit the same provenance — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md).
- Ledgers **[exact]**: `usage.jsonl` has 7,453 calls, 7,035 `opus` and 418 `sonnet`, with logged cost summing to about $1,666; `runs.jsonl` records model `opus` on 7,678 rows — [logs/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/logs).
- Timeline **[exact, git]**: of 330 roots I could date, 106 were first added in April 2026 and 224 in July 2026; 5 could not be dated, because of renames. `runs.jsonl` confirms 133 distinct `a_b` accepted as base or variation; the other July additions are unreconciled. All 675 commits are authored by the owner; 540 carry a `Claude Fable 5` co-author trailer, 22 `Claude Opus 5`, 18 `Claude Opus 4.8`; the first trailer is dated 2026-07-08 — [commit history](https://github.com/Cinderella-Man/elixir-sft-dataset/commits/328195bb).
- Hand-era authorship: CONTEXT says "all hand-authored", but its own section 6 calls the workflows LLM-driven, and the meta-prompt `tasks/single_shot_prompt.md` asks for "a prompt that I could give to AI" — [CONTEXT.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/CONTEXT.md), [single_shot_prompt.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/tasks/single_shot_prompt.md). The model for that era is not named anywhere I found.
- Edits since: 295 of 330 root golds have more than one commit on them **[exact]**, though many are formatting or renames. Of 118 commits touching root `solution.ex` files, 70 carry a Fable 5 trailer, 3 Opus 5, 3 Opus 4.8, and 42 none; commits touching root prompts show 59 Fable 5, and root harnesses 107 Fable 5 **[exact]**. For example, `061_001`'s gold last changed in a Fable-trailered commit dated 2026-07-22. A trailer shows the session's assistant, not who wrote each line.
- Third-party text is in the repo: `test/fixtures/benchmarks/benchmarks.jsonl` (839 KB) is tracked and holds MultiPL-E, McEval and Exercism snapshots — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md). It is a decontamination fixture, not training data, but it carries its own licences.
- Outside the repo, for the writer: Anthropic's consumer terms page, effective 8 October 2025 as fetched, bars using the services to build competing products or services, and its prohibited-use list also refers to work "to develop or train any artificial intelligence or machine learning algorithms or models". It also assigns the user Anthropic's rights in Outputs, subject to compliance with the terms — [Consumer Terms](https://www.anthropic.com/legal/consumer-terms). That reading came through a summarising fetch tool, so how those two parts of the clause connect must be read in the original.

### Inferences
- Three separate questions: (a) others' right to use the repo: without a licence, default copyright applies, so nobody else has a grant; adding a LICENSE is cheap but does not settle (b) or (c). (b) Provider terms on training a model with Claude outputs. (c) The strength of any copyright in machine-generated text.
- Under the owner's standing rule (strict, publishable sources with licence and provenance checked), this dataset should be treated as **not cleared** for a published model until (b) is decided. This is a flag, not legal advice.
- The uses differ in kind. Measuring a model with the harnesses puts no Claude text into its weights; SFT does; and RL does too, since prompts and reward signal come from Opus-written files. Whether any of them is acceptable is the owner's call, and the RL row below should not be read as a way around the issue.

### Gaps
- Which subscription plan was used; the repo says only "subscription-backed", and which terms apply depends on the plan.
- Which terms version applied at generation time (April and July 2026). The page fetched shows an October 2025 date.
- The hand-era author model, and how much text from each era survives in today's golds.
- Why the 91 July roots beyond the 133 in `runs.jsonl` aren't in that ledger; the ledger begins on 2026-07-03, and some may be earlier loop runs or moved dirs.

## Is the QA independent?

### Takeaway
Not really: every LLM check is Claude. The "independent model" of the blind-solve screen is Opus, the author model, in a fresh context, so the gate proves a prompt suffices for Opus, not for a small model or a person.

### Cited Findings
- README: "an independent model solving from the prompt alone must succeed" — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md). The ledger shows all 1,528 rows with `"model":"opus"` **[exact]** — [screen_blind.jsonl](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/logs/screen_blind.jsonl).
- Screen outcome **[exact]**: 1,115 green and 413 red rows over 338 tasks; 6 tasks never went green: `020_002`, `020_003`, `020_004`, `025_002`, `041_004`, `045_003`.
- Tier using the docs/16 majority-of-last-3 rule, recomputed **[exact]**: 308 `blind_solvable`, 27 `keep_class`, 0 unscreened.
- The screen's comment concedes a failure may mean a too-weak solver — [screen_blind_solve.exs](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/scripts/screen_blind_solve.exs). The docs/16 G9 note says single verdicts are "luck-contaminated" — [docs/16 §2](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md).
- The rubric's "second model family" is Sonnet by default; both judges score the same rubric — [rubric_judge.exs](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/scripts/rubric_judge.exs). Reviewer hallucinations were found by hand — [docs/19](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/19-gold-defect-triage.md).
- The one non-Claude solver file in the corpus is a failed Qwen3.5-4B trie — [CONTEXT.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/CONTEXT.md).

### Inferences
- A 27 % red rate for the author model itself shows these tasks are hard. Expect far lower solve rates from small local models, which makes this a usable difficulty ladder for them: many tasks will be unsolved at first, and that is what an RL or eval set wants.
- Shared blind spots between authors and reviewers cannot be seen from inside this QA loop. Human Elixir review of even 20 roots, or a non-Claude reviewer, would add information that more Claude passes cannot.

### Gaps
- No human reviewer outside the owner is recorded; how many roots the owner read personally isn't stated.

## Fit for purpose: SFT, eval, RL, agentic seeds, single-file generation

### Takeaway
Best use is as an executable eval and RL environment set; second, a focused SFT set of roughly 2,600–3,200 examples; third, seeds for agentic trajectories, where its captured repair chains are valuable but few. Using all 14.8k rows with no weighting is the wrong way to use it. All of this depends on the provenance decision.

### Cited Findings
- Useful unit counts **[exact]**, from the shape counts plus md5 uniqueness over [tasks/](https://github.com/Cinderella-Man/elixir-sft-dataset/tree/328195bb/tasks):

| Shape | Rows | Unique golds | Identical to a root gold | Note |
|---|---:|---:|---:|---|
| Root (whole module) | 335 | 335 | — | The independent tasks |
| Code FIM | 3,558 | 3,166 | 0 | Median gold 277 B, prompt 9,954 B |
| Test FIM | 6,658 | 6,606 | 0 | Median gold 344 B, prompt 16,848 B |
| Spec FIM | 1,824 | 1,272 | 0 | Median gold 56 B |
| Bugfix | 964 | 326 | 326 | Prompt median 10,683 B |
| Adapt | 249 | 249 | 249 | Gold is a variation root |
| Dedoc / TDD | 326 each | 326 each | 326 each | Gold is the root |
| Dialogue | 182 | 180 | 88 | Prompt median 2,782 B |
| Style | 50 | 45 | 29 | |

- Root sizes **[exact]**, median (p10, p90, max): prompt 3,315 B (2,315, 5,706, 8,945) / 39 lines; solution 6,023 B (3,378, 9,792, 17,841) / 190 lines; harness 9,929 B (5,993, 15,836, 29,183) / 295 lines. Root text totals 1.23 MB of prompts, 2.16 MB of solutions, 3.54 MB of harnesses, about 1.7M tokens at 4 chars/token.
- Total corpus text **[exact]**: 197.0 MB of prompts, 22.8 MB of solutions, 19.4 MB of harnesses, so about 90 % of exported tokens are prompt context.
- The repo's own weights (1.0 / 0.5 / 0.25 per shape, [docs/16 §4](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/16-export-contract.md), [docs/18](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/18-training-run-handoff.md)) applied to the README's table give about 5,580 effective examples (my arithmetic). The README's own conservative count is 8,130.
- Quality filter on the 335 roots **[exact, by my definition]**: `blind_solvable`, single-file, no "interface contract" section, and last-ledger semantic kill rate at a threshold:

| Kill floor | Roots kept | Ideas kept | Code-FIM children |
|---|---:|---:|---:|
| ≥ 70 % | 238 | 81 | 2,557 |
| ≥ 80 % | 189 | 75 | 2,012 |
| ≥ 85 % | 154 | 65 | 1,595 |

  Of the 189, 99 are GenServers (52 %), so filtering doesn't reduce the skew.
- The evaluator gives one JSON verdict per candidate, each in its own BEAM with a wall-clock kill, default 240 s — [README.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/README.md). The docs already call execution grading the metric that matters — [docs/18 §3](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/18-training-run-handoff.md).
- Agentic raw material: 1,098 chains in `logs/attempts`, with 86 multi-attempt chains ending accepted at the 2026-07-12 survey — [docs/13 §0](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/13-existing-data-improvement-and-extension.md).

### Inferences
Ranked use, best first:

1. **Eval and RL environments (best fit).** 335 prompt-harness pairs with an existing grader; mean 21.7 tests per task gives a graded reward (pass fraction), not just pass/fail. This is the piece of the repo that competing data sources are least likely to have. Needed: run it inside a container, since candidate code executes; loosen the zero-warning and style terms for small models; keep timing-based tasks out or retried; run on the quant machine.
2. **SFT, as a filtered subset (useful).** For **single-file generation** the fit is good, with one distinction: roots are whole modules (median 190 lines), while code FIM is the true function-level shape (median gold 277 B, in full module context). The filter keeps 189–238 whole modules plus 2,000–2,550 FIM examples. Adding one write-tests row per kept root and the 182 dialogues gives about **2,570–3,200 examples** (my estimate). Bugfix, spec FIM, TDD, dedoc and style add little and should be capped or dropped first; test FIM can be capped per root.
3. **Agentic seeds (promising but thin).** The 182 dialogues are real spec-attempt-failure-fix chains, and only 24 have more than one failed attempt. They lack file tools, shell output and repository navigation, so they are not coding-agent traces. The prompts and tests could seed such episodes in a real agent harness, with the test run as the terminal reward.
4. **Plain SFT on everything (not recommended).** The set is dominated by test FIM (45 %) and near-copies, and the repo's own doc warns about drowning base tasks.

Comparison hook for the writer: this repo holds **335 root tasks (83 ideas), about 2,600–3,200 examples after a quality filter with FIM, and 14,803 raw rows**. Compare those three numbers against published volumes separately, because comparing 14.8k against others' independent examples would flatter it.

### Gaps
- Actual export not produced, so token counts use the 4 chars/token estimate and exclude the fence.
- BEAM eval time per task is unknown here, since nothing ran; RL throughput needs a measurement.
- Which small model's solve rate these tasks would give is unknown.

## Concrete improvements, ranked by value for effort

### Takeaway
First settle provenance, then spend effort on a held-out eval and on removing near-empty rows. New root coverage is the most valuable data work but costs the most, and it reopens the provenance question.

### Cited Findings
- The repo already parks register rewriting of about 2,700 prompts as its most expensive item pending evidence from a first run — [docs/18 §4](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/18-training-run-handoff.md).
- The audit's coverage roadmap names in-BEAM options: `Phoenix.LiveViewTest`, Oban Lite on SQLite, `Absinthe.run/3`, Ash on ETS — [docs/07 §1, §7.2](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/docs/07-dataset-audit-and-growth-roadmap.md).
- STATUS still owes a final sweep, export refresh and a corpus-wide re-measure of semantic mutants, because all rows are stale — [STATUS.md](https://github.com/Cinderella-Man/elixir-sft-dataset/blob/328195bb/STATUS.md).

### Inferences
Ranked by value for effort (mine):

1. **Decide provenance (hours, owner).** Read the terms for the plan actually used, name the April model if known, record the verdict. Blocks everything public.
2. **Add a LICENSE or an explicit "no licence yet" note, and a provenance section in the README (under an hour).** State Opus, the eras, and the Fable-assisted edits as fact.
3. **Fix the Saga split leak with `split-v2`, keeping 065 and 070 together (minutes).** Also grow val beyond 17 roots, with whole ideas, to about 40–60 roots spanning web and pure code (cheap, deterministic).
4. **Ship a curated "core" export (a day).** The filter above: drop spec FIM duplicates and one-token bugfixes, cap test FIM per root, keep weights. No LLM spend.
5. **Publish the export and an eval runner (a day).** A JSONL release plus a Docker image pinned to 1.20.2/OTP 29, so nobody must build an Elixir stack to use it. Exclude the third-party benchmark fixture.
6. **Run the mechanical idiom pass (hours on the quant machine).** `mix format --migrate` for `unless`; correct the `async: false` template contradiction on 32 write-test prompts; cascade as usual.
7. **Remove test-talk from 33 prompts (a day).** Sentences that discuss how tests assert can be reworded or the tasks excluded.
8. **Add non-Claude and human checks (days).** A non-Claude blind solver and reviewer on all roots, a human Elixir reviewer on 20–30, and solve rates from one small model to replace "Opus can solve it" with a real difficulty measure.
9. **Run a small first training run (days of GPU).** Measure before expanding; docs/18 §4 already lists what it decides.
10. **Add vague-prompt variants for existing roots (LLM cost).** Since harnesses don't change under rewording, each root can gain underspecified prompts that keep the API contract in a separate hidden file. This raises realism more than voice rewriting did.
11. **Add new roots for the gaps (largest cost, highest long-term value).** LiveView, Channels, `Ecto.Multi`, Oban, `gen_statem`, protocols, Mix tasks, real macros, and ordinary context-module app work. Choose the author model only after step 1. Reuse-minded note: real public, permissively licensed Elixir repos could supply prompts-from-code with far cleaner provenance; other researchers cover that.

### Gaps
- Effort figures are my estimates, not measured.
- The value of items 7 and 10 depends on a training run that hasn't happened.
