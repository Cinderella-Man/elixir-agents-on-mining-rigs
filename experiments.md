# Experiments registry

Every idea gets a row here as soon as it is written down, however small; that is what keeps work from being done twice.
Ideas the evidence argues against stay as rows marked **parked**, with the reason and what would reopen them. The
order of work is in [docs/plan.md](docs/plan.md).

**Now (2026-11-09):** the project starts. Nothing has run yet.

| # | Idea | Status | Result | Runs on, needs |
|---|---|---|---|---|
| E1 | **The bar:** the rig's Flash-Next files on the Elixir SWE Bench. Swift GSQ-RCO Q2_0 (the 20.40 tok/s line on Miner Llama v3) and Swift Qwen3.8-Flash-Next Pascal Q2 GGUF (`pmix-q2-fast`), all 20 cases, Pi harness, three seeds each. The better file is the bar every candidate must beat | planned 2026-11-09 | — | the 7-GPU machine (quality does not need the rig) |
| E2 | **Elixir agent text** for calibration and KLD: agent sessions on E8's tasks (the teacher's and Flash-Next's own), split into a calibration set and a held-out KLD set, with Qwen3.8-Flash-Next Q8_0 reference logits on both and on a general text base | planned 2026-11-09 | — | 7-GPU machine; E8, E12 |
| E3 | **Expert usage on Elixir agent text:** per-layer routing counts and REAP saliency (the sister repo's Q232 method), against the same ranking on general agent text: how many experts carry 99 % of Elixir routings | planned 2026-11-09 | — | 7-GPU machine; E2 |
| E4 | **The Elixir expert cut:** keep 384, 320 or 256 of 512 experts per layer by E3's ranking, and quantize the kept experts at the bits the freed bytes allow, at or below Swift Q2_0's 35,730 MiB on the cards. KLD on Elixir and general text, then the bench for the best. Evidence: arXiv 2607.16721, the sister repo's Q891 | planned 2026-11-09 | — | 7-GPU machine; E3 |
| E5 | **Merge near-duplicate experts:** cluster each layer's experts by their outputs on Elixir text and merge each cluster into one (usage-weighted, HC-SMoE / MC-SMoE style), the router's ids mapped to the merged expert; on the best E4 file | planned 2026-11-09 | — | 7-GPU machine; E4 |
| E6 | **Drop layers:** rank layers by how little they change the residual on Elixir text (input/output cosine, ShortGPT style) and drop one to four; Flash-Next mixes recurrent and attention layers, so each kind is tested apart | planned 2026-11-09 | — | 7-GPU machine; E4 |
| E7 | **Trim the vocabulary:** drop embedding and output-head rows for tokens that never appear in Elixir agent and general code text, with an exact fallback to the full head (as in the sister repo's draft shortlist), saving head bytes each token | planned 2026-11-09 | — | 7-GPU machine, then the rig for speed; E2 |
| E8 | **Mine Elixir tasks:** merged pull requests with tests from Elixir projects outside the bench's 12, in the bench's case format (a prepared baseline, tests that fail before and pass after the fix); several hundred | planned 2026-11-09 | — | code work, then the 7-GPU machine for qualification; E12 |
| E9 | **Teacher sessions:** DeepSeek-V4.1-Flash-1017 in Pi on E8's tasks, several attempts per task, a session kept when the held-back tests pass; pass rate per task recorded, sessions per hour measured first | planned 2026-11-09 | — | 7-GPU machine; E8 |
| E10 | **The student:** score about-3B-active MoE bases untuned (Ornith-1.5-35B-A3B, Qwen3.6-35B-A3B), then a LoRA fine-tune of the best on E9's kept sessions; three bench seeds against its base and E1's bar; then its rig-sized file and its time per task on the rig | planned 2026-11-09 | — | 7-GPU machine, then the rig; E1, E9 |
| E11 | **Prune and heal:** E4's best cut followed by a short LoRA on E9's sessions (arXiv 2607.16721: a light fine-tune recovers about half of what an aggressive cut loses); first, whether a LoRA on the cut Flash-Next fits the 7-GPU machine | planned 2026-11-09 | — | 7-GPU machine; E4, E9 |
| E12 | **Contamination guard:** every mined task, calibration text and session checked against the bench's 12 projects (repository, file paths, pull-request text) and dropped on a match | planned 2026-11-09 | — | code work; before E2, E8 |
