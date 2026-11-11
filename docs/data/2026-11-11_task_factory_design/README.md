# The counts behind the task-factory design (2026-11-11)

Three small reads for the design note
[A task factory on the bench's engine](../../research/notes/task_factory_on_the_bench_engine.md) (registry row
[E68](../../../experiments.md)). Nothing was built, cloned or run: the reads are of GitHub's metadata, of the Elixir
SWE Bench's case folders, and of Docker's image list.

**Result.**
- **The pilot repositories.** Of the latest 200 merged pull requests, 110 (`nerves-hub/nerves_hub_web`), 64
  (`axelclark/ex338`) and 100 (`podlove/radiator`) come from a person and change both code and tests. Bots wrote 63,
  86 and 32. In `nerves_hub_web`, 107 of the 110 carry Claude Code's "Generated with" footer in their description;
  in its pull requests merged in 2023 and 2024, 0 of 69 do.
- **The bench's 20 cases.** 17 share one identical early-exit patch. 9 list hand-made preparation files in their
  fork. 9 record a curator's extension or correction of the upstream fix. 3 record an upstream issue. Tickets are 53
  to 1,044 bytes for the 12 bug fixes and 366 to 10,884 bytes for the 8 features.
- **The bench's prepared images.** A project image at one commit has a median size of 1.07 GB as Docker lists it,
  and its toolchain image 0.90 GB. Shared layers are counted in every image, so the sizes do not add up.

These are counts of metadata. They bound the number of usable pull requests from above; the yield is what the pilot
measures.

## Files

| File | What it holds |
|---|---|
| [pr_sample.tsv](pr_sample.tsv) | one row per count, one column per pilot repository: authors, code and test changes, code files per pull request, migrations, assets, dependency files, closing issues, description lengths, AI-tool marks |
| [bench_cases.tsv](bench_cases.tsv) | one row per bench case: kind, services, test adapter, test time limit, numbers of required tests, starting failures and requirement sentences, sizes of the ticket and the patches, preparation files, curator changes, whether an upstream issue is recorded, which early-exit patch it has |
| [bench_images.tsv](bench_images.tsv) | one row per kind of prepared image: distinct images, smallest, median and largest size |
| [run/pr_sample.sh](run/pr_sample.sh) | the GitHub CLI queries behind `pr_sample.tsv` |
| [run/bench_case_facts.py](run/bench_case_facts.py) | the read of the case folders behind `bench_cases.tsv` |
| [run/image_sizes.sh](run/image_sizes.sh) | the summary of `docker images` behind `bench_images.tsv` |

## How the counts were made

**Pull requests** (2026-11-11). `gh pr list --state merged --limit 200` with the file list of each pull request, and
the counting in the same call's `--jq`:

```bash
bash run/pr_sample.sh
```

- "Code" is a file under `lib/` ending in `.ex`, `.heex`, `.eex` or `.leex`. "Test" is a file under `test/` ending
  in `_test.exs`.
- A bot is an author GitHub marks as one, or a login containing `dependabot`, `renovate` or `[bot]`.
- The file list stops at 100 files per pull request. One pull request in each sample reached that.
- A closing issue is one GitHub lists in `closingIssuesReferences`.
- The Claude Code footer is the text "Generated with Claude Code" in the description, with or without a link. The
  other marks are the words `claude`, `copilot`, `codex`, `cursor` and `co-authored-by` anywhere in the description.
- The 2023 to 2024 window for `nerves_hub_web` is `--search "merged:2023-01-01..2024-12-31" --limit 300`. How many
  pull requests that query returned was not recorded.
- The script as committed was run once and gave the table's numbers.

**Bench cases.** Read at commit `28c064ca` of
[Cinderella-Man/elixir-swe-bench](https://github.com/Cinderella-Man/elixir-swe-bench):

```bash
BENCH=<checkout of the bench> python3 run/bench_case_facts.py
```

- `preparation_files` is the length of `provenance.json`'s `preparation.files`; `not_listed` means the key is absent.
- `curator_change` names the keys `curator_extension` and `curator_correction` present in `provenance.json`.
- `integrity_patch`: `common` is the patch 17 cases share (its SHA-256 starts `9345cf52`); `variant` adds the same
  file with a different hunk header; `own_file_name` adds the same line in a file of another name.
- The table was written by hand from the output of an inline form of this script. The committed form has the same
  statements with the checkout taken from `BENCH`, and was not run again.

**Images.** On the machine that holds the bench's prepared images, 2026-11-11:

```bash
bash run/image_sizes.sh
```

- An image's kind is the first word of its tag after `elixir-agent-benchmark:`.
- That machine holds several generations of each case, so there are more images than cases.
- `docker images` shows each image's whole size, shared layers included. It does not show the size an image holds
  alone.
- The Postgres and ClickHouse rows come from the script's second listing; their medians were worked out by hand.
- The committed form is a tidied copy of the inline commands that ran, and was not run again.

## Provenance and licence

The pull-request counts come from GitHub's public API. No description, title or file content of any pull request is
stored here. The case facts come from the bench's public repository. This folder's tables and scripts are under this
repository's licence.
