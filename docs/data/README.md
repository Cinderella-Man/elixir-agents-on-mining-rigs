# Data behind the results

One folder per experiment, `docs/data/<date>_<experiment>/`. Each holds:
- a `README.md`: what it measured, a link to its result, a table of the files, the exact commands, provenance and
  licence;
- the curated tables (CSV, TSV, Markdown);
- the scripts that ran it, in `run/`.

| Folder | Experiment | Result |
|---|---|---|
| [2026-11-09_bench_runs_read](2026-11-09_bench_runs_read/README.md) | E14: budget hits and tokens per solved case in the bench's published runs | 7 of the Flash-Next Coder's 10 failures and 5 of Gyro-L's 9 ended at the 65,536-token budget; DeepSeek UD-IQ1_M used 28,736 tokens per passed case, the Flash-Next files 32,639 and 39,421 |
| [2026-11-09_elixir_project_pool](2026-11-09_elixir_project_pool/README.md) | E46: the Elixir repositories training tasks could be mined from, by licence and tier | 1,182 repositories with 100 or more stars; 929 permissive candidates outside the bench (tier A 171, B 264, C 494) with 153,104 merged pull requests |
| [2026-11-10_bracket](2026-11-10_bracket/README.md) | E1, E13: Swift GSQ-RCO Q2_0 against Swift GSQ-RCO IQ3_S on the Elixir SWE Bench, three seeds each | running since 2026-11-10, no result yet; both files fit at the bench's 262,144-token window (47,173 and 63,584 MiB on the cards) |
