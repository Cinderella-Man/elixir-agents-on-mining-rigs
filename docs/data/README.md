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
| [2026-11-10_bracket](2026-11-10_bracket/README.md) | E1, E13, E65: Swift GSQ-RCO Q2_0 against Swift GSQ-RCO IQ3_S on the Elixir SWE Bench, three seeds each, and IQ3_S cut to 448 experts per layer | seed 101 ended for all three files: Swift GSQ-RCO Q2_0 14 of 20 cases passed, IQ3_S 14 of 20, IQ3_S cut to 448 experts 15 of 20; seeds 102 and 103 have not run; the three files fit at the bench's 262,144-token window (47,173, 63,584 and 57,558 MiB on the cards) |
| [2026-11-11_task_factory_design](2026-11-11_task_factory_design/README.md) | E68: the counts behind the task-factory design: the pilot repositories' latest merged pull requests, the bench's 20 case folders, its prepared images | of the latest 200 merged pull requests, 110 (nerves_hub_web), 64 (ex338) and 100 (radiator) come from a person and change both code and tests; in nerves_hub_web 107 of the 110 carry Claude Code's footer; 9 of the bench's 20 cases record a curator's change to the upstream fix |
| [2026-11-11_pilot_pr_census](2026-11-11_pilot_pr_census/README.md) | E68: the merged pull requests of the three pilot applications, from GitHub metadata: bots, dependency bumps, docs only, reverts, changes to both code and tests, and which are followed by another pull request within 30 days | 3,476 merged pull requests (nerves_hub_web 2,474, ex338 749, radiator 253); 1,260 change both `lib/` code and tests, 513 of those with 2 to 5 implementation files; 735 are by bots |
| [2026-11-12_pilot_pr_screen](2026-11-12_pilot_pr_screen/README.md) | E68: a verdict and a reason for every merged pull request of the three pilot applications, by the design note's screening rules that GitHub's metadata and the changed lines can decide, with marks, the pairs of pull requests that name each other and the repairs among them | 1,115 of 3,476 merged pull requests are candidates (nerves_hub_web 705, ex338 305, radiator 105); 138 named pairs, 111 of them tested, 49 repair the earlier pull request; 257 are marked as written with an AI tool |
