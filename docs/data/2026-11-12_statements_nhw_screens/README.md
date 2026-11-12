# The teacher writes the statements of the nerves_hub_web and screens cases (E9, E81)

The teacher model, DeepSeek-V4.1-Flash-1017 (Unsloth's `UD-IQ1_M`, revision `2688c0c3` of
`unsloth/DeepSeek-V4.1-Flash-1017-GGUF`), served by Strata on the 7-GPU machine, wrote the statements of checked
cases of two of the dataset's projects: `nerves-hub/nerves_hub_web` (27 cases) and `mbta/screens` (19 cases), 46 in
the list. Each request went from the data-mining machine, one at a time, and each answer went through the leak check
before anything was written. The tool is [`factory/tools/statements/`](../../../factory/tools/statements/README.md),
unchanged since it wrote the first 16 statements
([`2026-11-12_statements_first_20`](../2026-11-12_statements_first_20/README.md)): the same instruction text (SHA-256
`5e7fc3d6…`), the same leak rule (`statements-leak-v1`), at most 3 answers per case.

**Result: 36 of the 46 cases have a statement that passed the leak check.** 26 passed on the first answer, 7 on the
second and 3 on the third.
- **1 case has no statement after 3 answers:** `nerves-hub-web-pr-3146` (a feature). Each of its three answers held
  one item that only the change holds.
- **9 cases of `mbta/screens` were not written:** the run was stopped at 20:29:26 UTC on 2026-11-12, before its end.
  The first answer for `screens-pr-3310` was being generated and was cut; the 8 cases after it had not started
  ([`run/tasks_left.txt`](run/tasks_left.txt)).
- 16 of the 52 answers were rejected, on 11 cases. The rejected answers took 6,361.5 s, 47.6 % of the answers' time.
- The 37 cases that ended took 13,530 s by the wall clock, one after another, from 16:34:06 to 20:19:39 UTC; the cut
  request ran for another 588 s.

| Project | Kind | Cases | With a statement | No accepted answer | Not written | Passed on answer 1 / 2 / 3 | Answers | Rejected | Seconds |
|---|---|---:|---:|---:|---:|---|---:|---:|---:|
| `nerves-hub/nerves_hub_web` | bug fix | 10 | 10 | 0 | 0 | 8 / 2 / 0 | 12 | 2 | 969 |
| `nerves-hub/nerves_hub_web` | feature | 17 | 16 | 1 | 0 | 10 / 3 / 3 | 28 | 12 | 10,364 |
| `mbta/screens` | bug fix | 9 | 6 | 0 | 3 | 6 / 0 / 0 | 6 | 0 | 699 |
| `mbta/screens` | feature | 10 | 4 | 0 | 6 | 2 / 2 / 0 | 6 | 2 | 1,498 |
| both | both | 46 | 36 | 1 | 9 | 26 / 7 / 3 | 52 | 16 | 13,530 |

*Seconds* is the wall time of the cases that ended, from the driver's own record ([`tasks.tsv`](tasks.tsv)); the 588 s
of the cut request are not in it. Every sum by group: [`totals.tsv`](totals.tsv).

## Which cases

| Project | Cases | Bug fixes | Features | Merged | From |
|---|---:|---:|---:|---|---|
| `nerves-hub/nerves_hub_web` | 27 | 10 | 17 | 2026-10-01 to 2026-11-10 | [`2026-11-12_tasks_nerves_hub_web`](../2026-11-12_tasks_nerves_hub_web/README.md) |
| `mbta/screens` | 19 | 9 | 10 | 2026-08-26 to 2026-11-03 | [`2026-11-12_cases_mbta_screens`](../2026-11-12_cases_mbta_screens/README.md) |

- Every case passed the gate, the licence scan and the hold-out check in the job that made it, and is built on
  Elixir 1.18 or later.
- `screens-pr-3307` was not in the list: when the list was made it failed the licence scan. It has no statement.
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
  length limit are the server's own defaults. The server's `/props` before the run were the same, field for field, as
  before the first statements: temperature 1.0, top_p 1.0, no generation limit, one slot, a 262,144-token window.
- **The voice** (`docs/dataset_rules.md`, section 5): a developer typing a request to a coding agent in their own
  repository. A bug fix is short and plain; a feature is a long specification.
- **The statement is the model's alone:** the text between the answer's `<statement>` and `</statement>` lines, with
  the white space at its two ends dropped and one newline added. No statement was edited by hand.
- **The leak check** (`statements-leak-v1`, [the rule](../../../factory/tools/statements/README.md#the-leak-rule-statements-leak-v1))
  rejects a statement that holds a line or an identifier that only the change holds, a hidden test's name or file, a
  changed file's name, or the pull request's number or a commit hash. A rejected answer is asked for again with a note
  listing what was rejected, at most 3 answers per case. A case with no accepted answer after 3 gets no statement.
- **The stop rules:** a server error does not use up an answer; three in a row, a request that waits more than 10
  minutes for the server, a bench run on the machine or less than 50,000,000,000 bytes free stop the run. None
  happened: no server error, the longest wait 6.0 s, and 532,740,284,416 bytes free at the end.
- **Before the run** the tool's own tests ran in the tooling image: 11 of 11 pass.
- **After the run** each written `ticket.md` was read again: its SHA-256 equals the one in its `statement.json` and
  the one of the accepted answer's text, for 36 of 36 ([`sha_check.tsv`](sha_check.tsv)).

## The cases

| Project | Case | Kind | Answers | Accepted | Seconds | Statement (bytes) | Rejected for |
|---|---|---|---:|---|---:|---:|---|
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3261` | feature | 1 | yes | 338 | 4866 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3259` | feature | 1 | yes | 193 | 2566 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3258` | feature | 1 | yes | 150 | 1934 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3257` | bug_fix | 1 | yes | 52 | 731 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3256` | bug_fix | 1 | yes | 62 | 524 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3255` | bug_fix | 1 | yes | 34 | 427 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3254` | bug_fix | 2 | yes | 95 | 670 | answer 1: L1 `{:error, %{error: "unauthorized"}}` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3235` | feature | 2 | yes | 474 | 3468 | answer 1: L1 `:ignore_deleted_product` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3233` | feature | 1 | yes | 164 | 4075 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3159` | feature | 2 | yes | 1006 | 6925 | answer 1: L2 `not_waiting` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3155` | bug_fix | 2 | yes | 262 | 1084 | answer 1: L1 `{:error, :already_exists}` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3156` | bug_fix | 1 | yes | 113 | 737 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3153` | feature | 1 | yes | 142 | 2595 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3146` | feature | 3 | no: no accepted answer after 3 | 982 | none | answer 1: L1 `:missing_verification_san`; answer 2: L2 `ownership_error_message`; answer 3: L1 `verification certificate.` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3142` | feature | 1 | yes | 293 | 6377 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3140` | bug_fix | 1 | yes | 80 | 517 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3139` | feature | 1 | yes | 228 | 3951 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3138` | feature | 3 | yes | 1677 | 9759 | answer 1: L2 `fast_forward`; answer 2: L2 `not_an_approval_step` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3124` | bug_fix | 1 | yes | 119 | 574 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3145` | feature | 1 | yes | 81 | 1520 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3113` | feature | 1 | yes | 253 | 3475 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3115` | bug_fix | 1 | yes | 108 | 1044 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3108` | feature | 3 | yes | 1738 | 8185 | answer 1: L1 `Copy the secret now. It is only shown once, and cannot be retrieved again.`, L2 `deactivated_by_id`, L3 `device shared secrets`; answer 2: L1 `"deactivated_at" => nil,` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3111` | feature | 2 | yes | 541 | 2182 | answer 1: L1 `{:error, {:fwup_too_old, required, installed}}` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3100` | feature | 3 | yes | 1703 | 4240 | answer 1: L2 `anti_replay`, L2 `early_data`; answer 2: L3 `tls 1.3 session tickets` |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3097` | bug_fix | 1 | yes | 44 | 388 |  |
| `nerves-hub/nerves_hub_web` | `nerves-hub-web-pr-3082` | feature | 1 | yes | 401 | 3735 |  |
| `mbta/screens` | `screens-pr-3388` | bug_fix | 1 | yes | 173 | 842 |  |
| `mbta/screens` | `screens-pr-3387` | bug_fix | 1 | yes | 49 | 450 |  |
| `mbta/screens` | `screens-pr-3363` | feature | 2 | yes | 642 | 3010 | answer 1: L1 `Delete inactive evergreen and wayfinding content which ended before the` |
| `mbta/screens` | `screens-pr-3358` | bug_fix | 1 | yes | 138 | 927 |  |
| `mbta/screens` | `screens-pr-3356` | bug_fix | 1 | yes | 84 | 447 |  |
| `mbta/screens` | `screens-pr-3353` | feature | 1 | yes | 137 | 2168 |  |
| `mbta/screens` | `screens-pr-3343` | feature | 2 | yes | 420 | 3489 | answer 1: L1 `Delete evergreen content tied to alerts that are no longer present in`, L2 `alerts?` |
| `mbta/screens` | `screens-pr-3341` | bug_fix | 1 | yes | 70 | 532 |  |
| `mbta/screens` | `screens-pr-3319` | bug_fix | 1 | yes | 185 | 1120 |  |
| `mbta/screens` | `screens-pr-3306` | feature | 1 | yes | 299 | 2426 |  |
| `mbta/screens` | `screens-pr-3310` | bug_fix | 0 | no: stopped | 588 | none |  |
| `mbta/screens` | `screens-pr-3281` | feature | 0 | no: not run |  | none |  |
| `mbta/screens` | `screens-pr-3293` | bug_fix | 0 | no: not run |  | none |  |
| `mbta/screens` | `screens-pr-3284` | feature | 0 | no: not run |  | none |  |
| `mbta/screens` | `screens-pr-3287` | feature | 0 | no: not run |  | none |  |
| `mbta/screens` | `screens-pr-3286` | bug_fix | 0 | no: not run |  | none |  |
| `mbta/screens` | `screens-pr-3265` | feature | 0 | no: not run |  | none |  |
| `mbta/screens` | `screens-pr-3255` | feature | 0 | no: not run |  | none |  |
| `mbta/screens` | `screens-pr-3250` | feature | 0 | no: not run |  | none |  |

*Answers* counts the answers the model gave; *seconds* is the case's wall time, all its answers together. "no:
stopped" is the cut request; "no: not run" are the 8 cases that had not started. One row per case with the
statement's SHA-256: [`cases.tsv`](cases.tsv). The statements themselves: `statements/<case>/ticket.md` with
`statement.json`.

**The statements by kind:**
- the 16 bug fixes are plain text with no headings and no lists, from 388 to 1,120 bytes: 731, 524, 427, 670, 1,084,
  737, 517, 574, 1,044 and 388 bytes for nerves_hub_web's 3257, 3256, 3255, 3254, 3155, 3156, 3140, 3124, 3115 and
  3097; 842, 450, 927, 447, 532 and 1,120 bytes for screens' 3388, 3387, 3358, 3356, 3341 and 3319;
- the 20 features are specifications, from 1,520 to 9,759 bytes: 4,866, 2,566, 1,934, 3,468, 4,075, 6,925, 2,595,
  6,377, 3,951, 9,759, 1,520, 3,475, 8,185, 2,182, 4,240 and 3,735 bytes for nerves_hub_web's 3261, 3259, 3258, 3235,
  3233, 3159, 3153, 3142, 3139, 3138, 3145, 3113, 3108, 3111, 3100 and 3082; 3,010, 2,168, 3,489 and 2,426 bytes for
  screens' 3363, 3353, 3343 and 3306.

## What the leak check rejected

16 of the 52 answers, for 20 items ([`rejections.tsv`](rejections.tsv)):

| Rule | Items | What they are |
|---|---:|---|
| L1, a line only the change holds | 10 | five error values or atoms that are a whole line of the change (`{:error, %{error: "unauthorized"}}`, `{:error, :already_exists}`, `{:error, {:fwup_too_old, required, installed}}`, `:ignore_deleted_product`, `:missing_verification_san`); one line of a map (`"deactivated_at" => nil,`); three lines of page text the change adds (`Copy the secret now. It is only shown once, and cannot be retrieved again.`, and the first line of a paragraph in two pages of screens); the last line of a wrapped sentence in the change's documentation (`verification certificate.`) |
| L2, an identifier only the change holds | 8 | `not_waiting`, `ownership_error_message`, `fast_forward`, `not_an_approval_step`, `deactivated_by_id`, `anti_replay`, `early_data`, `alerts?` |
| L3, the name of a hidden test or `describe` block | 2 | `device shared secrets` and `tls 1.3 session tickets`: the names of two `describe` blocks, each also the feature's own name in plain words |

None named a file, the pull request or a commit. `nerves-hub-web-pr-3146` was rejected three times, each time for one
new item: `:missing_verification_san`, then `ownership_error_message`, then `verification certificate.`.

## The server's timings (E81)

| Requests | Answers | Wall time (s) | Reading: tokens, s, tok/s | Generating: tokens, s, tok/s | Drafted tokens accepted |
|---|---:|---:|---|---|---|
| all | 52 | 13,364.8 | 462,799, 2,053.2 s, 225.4 tok/s | 461,876, 11,298.7 s, 40.9 tok/s | 255,223 of 481,961 (53.0 %) |
| nerves_hub_web | 40 | 11,193.9 | 385,721, 1,651.4 s, 233.6 tok/s | 393,672, 9,531.2 s, 41.3 tok/s | 218,062 of 410,156 (53.2 %) |
| screens | 12 | 2,170.9 | 77,078, 401.8 s, 191.8 tok/s | 68,204, 1,767.5 s, 38.6 tok/s | 37,161 of 71,805 (51.8 %) |
| bug fixes | 18 | 1,588.0 | 79,615, 484.8 s, 164.2 tok/s | 42,609, 1,100.4 s, 38.7 tok/s | 22,996 of 44,962 (51.1 %) |
| features | 34 | 11,776.8 | 383,184, 1,568.4 s, 244.3 tok/s | 419,267, 10,198.3 s, 41.1 tok/s | 232,227 of 436,999 (53.1 %) |

The totals are sums over the requests; the speeds in the table below are each one request.
- **Generation is most of the time:** 84.5 % of the 52 answers' wall time, reading 15.4 %, waiting 12.9 s in all. For
  the bug fixes generation is 69.3 % and reading 30.5 %; for the features 86.6 % and 13.3 %.
- **Per request** the slowest generation was 24.0 tok/s (`screens-pr-3358`, 2,411 tokens) and the fastest 47.8 tok/s
  (`nerves-hub-web-pr-3111`, second answer, 8,418 tokens).
- **Reading is faster on longer prompts:** 99.1 tok/s for 1,624 tokens (`nerves-hub-web-pr-3145`), 336.6 tok/s for
  24,945 tokens (`nerves-hub-web-pr-3108`, second answer).
- **The prompt cache reused nothing:** `cache_n` is 0 in all 52 requests. A retry differs from the request before it
  only in the note of rejected items, which sits before the change and the tests, so it was read again in full.
- **No request waited for another client:** the longest gap between a request's wall time and the server's own times
  is 6.0 s (`nerves-hub-web-pr-3108`, second answer).

| Case | Kind | Answers | Verdicts | Wall time (s) | Waited (s) | Prompt tokens | Generated tokens | Reading (tok/s) | Generating (tok/s) | Drafted tokens accepted |
|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| `nerves-hub-web-pr-3261` | feature | 1 | pass | 334.4 | 0.1 | 8258 | 12056 | 213.9 | 40.8 | 6176 of 12772 |
| `nerves-hub-web-pr-3259` | feature | 1 | pass | 187.5 | 0.9 | 3656 | 6083 | 127.9 | 38.5 | 2953 of 6389 |
| `nerves-hub-web-pr-3258` | feature | 1 | pass | 145.8 | 0.0 | 4935 | 4528 | 158.7 | 39.5 | 2241 of 4514 |
| `nerves-hub-web-pr-3257` | bug_fix | 1 | pass | 45.3 | 0.1 | 2465 | 1004 | 125.1 | 39.3 | 517 of 1076 |
| `nerves-hub-web-pr-3256` | bug_fix | 1 | pass | 57.4 | 0.0 | 2149 | 1368 | 100.9 | 37.9 | 722 of 1444 |
| `nerves-hub-web-pr-3255` | bug_fix | 1 | pass | 30.9 | 0.0 | 1795 | 615 | 108.7 | 43.0 | 333 of 657 |
| `nerves-hub-web-pr-3254` | bug_fix | 2 | leak, pass | 32.1, 59.9 | 0.0, 0.0 | 2328, 2371 | 596, 1792 | 132.4, 142.8 | 41.2, 41.4 | 311 of 662; 947 of 1947 |
| `nerves-hub-web-pr-3235` | feature | 2 | leak, pass | 284.6, 186.1 | 0.1, 0.0 | 7426, 7463 | 9835, 6063 | 180.1, 183.4 | 40.4, 41.7 | 5055 of 10490; 3147 of 6125 |
| `nerves-hub-web-pr-3233` | feature | 1 | pass | 160.5 | 0.1 | 5284 | 4423 | 167.3 | 34.3 | 2262 of 4679 |
| `nerves-hub-web-pr-3159` | feature | 2 | leak, pass | 478.2, 522.8 | 0.1, 0.0 | 17850, 17886 | 15599, 19957 | 289.6, 308.0 | 37.5, 42.9 | 8022 of 15892; 10963 of 20447 |
| `nerves-hub-web-pr-3155` | bug_fix | 2 | leak, pass | 92.9, 153.4 | 0.1, 1.9 | 3918, 3956 | 2586, 5192 | 119.4, 155.4 | 43.1, 41.2 | 1478 of 2762; 2992 of 5338 |
| `nerves-hub-web-pr-3156` | bug_fix | 1 | pass | 101.2 | 0.1 | 2324 | 3203 | 120.4 | 39.2 | 1716 of 3431 |
| `nerves-hub-web-pr-3153` | feature | 1 | pass | 137.1 | 0.0 | 2991 | 4165 | 132.7 | 36.4 | 2036 of 4293 |
| `nerves-hub-web-pr-3146` | feature | 3 | leak, leak, leak | 392.2, 259.0, 323.1 | 0.5, 0.0, 0.0 | 10984, 11023, 11028 | 14555, 9336, 12241 | 262.7, 259.5, 269.4 | 41.6, 43.1, 43.4 | 7961 of 14802; 5270 of 9831; 7225 of 12696 |
| `nerves-hub-web-pr-3142` | feature | 1 | pass | 287.6 | 0.1 | 11386 | 9023 | 238.4 | 37.6 | 4915 of 9151 |
| `nerves-hub-web-pr-3140` | bug_fix | 1 | pass | 74.2 | 0.1 | 3325 | 1949 | 113.8 | 43.4 | 1092 of 2039 |
| `nerves-hub-web-pr-3139` | feature | 1 | pass | 223.1 | 0.1 | 7923 | 7256 | 186.8 | 40.2 | 3934 of 7817 |
| `nerves-hub-web-pr-3138` | feature | 3 | leak, leak, pass | 538.2, 560.1, 574.0 | 0.1, 0.0, 0.0 | 22949, 22984, 22993 | 18160, 21282, 18368 | 282.8, 319.3, 316.9 | 39.7, 43.6, 36.6 | 9883 of 18649; 11735 of 21098; 9719 of 18876 |
| `nerves-hub-web-pr-3124` | bug_fix | 1 | pass | 116.0 | 0.1 | 12936 | 2215 | 251.9 | 34.3 | 1124 of 2403 |
| `nerves-hub-web-pr-3145` | feature | 1 | pass | 78.3 | 0.0 | 1624 | 2426 | 99.1 | 39.2 | 1273 of 2428 |
| `nerves-hub-web-pr-3113` | feature | 1 | pass | 248.5 | 0.1 | 10503 | 8055 | 223.5 | 40.0 | 4319 of 8421 |
| `nerves-hub-web-pr-3115` | bug_fix | 1 | pass | 100.5 | 0.0 | 6150 | 2321 | 170.4 | 36.1 | 1295 of 2475 |
| `nerves-hub-web-pr-3108` | feature | 3 | leak, leak, pass | 672.3, 609.6, 452.8 | 0.1, 6.0, 0.0 | 24886, 24945, 24954 | 24205, 20546, 15504 | 317.8, 336.6, 334.7 | 40.8, 38.8, 41.0 | 13668 of 24733; 11400 of 21916; 8409 of 16524 |
| `nerves-hub-web-pr-3111` | feature | 2 | leak, pass | 324.1, 213.6 | 0.1, 0.0 | 6559, 6605 | 12252, 8418 | 167.2, 175.7 | 43.0, 47.8 | 7287 of 12860; 5231 of 8936 |
| `nerves-hub-web-pr-3100` | feature | 3 | leak, leak, pass | 487.3, 768.1, 443.1 | 0.1, 0.0, 0.0 | 11864, 11903, 11913 | 20580, 31101, 17170 | 247.1, 252.9, 250.1 | 46.9, 43.1, 43.4 | 12998 of 21978; 17059 of 32725; 9402 of 17856 |
| `nerves-hub-web-pr-3097` | bug_fix | 1 | pass | 40.1 | 0.1 | 2176 | 799 | 104.4 | 41.6 | 424 of 778 |
| `nerves-hub-web-pr-3082` | feature | 1 | pass | 398.1 | 0.0 | 7053 | 16845 | 178.1 | 47.0 | 10568 of 18246 |
| `screens-pr-3388` | bug_fix | 1 | pass | 170.6 | 0.0 | 2824 | 6258 | 120.9 | 42.5 | 3431 of 6768 |
| `screens-pr-3387` | bug_fix | 1 | pass | 46.6 | 0.0 | 1675 | 1238 | 99.6 | 41.6 | 653 of 1282 |
| `screens-pr-3363` | feature | 2 | leak, pass | 323.1, 316.7 | 0.0, 0.1 | 6892, 6935 | 11935, 11666 | 174.9, 173.4 | 42.1, 42.2 | 6346 of 12601; 6540 of 12226 |
| `screens-pr-3358` | bug_fix | 1 | pass | 135.8 | 0.0 | 5227 | 2411 | 148.1 | 24.0 | 1228 of 2386 |
| `screens-pr-3356` | bug_fix | 1 | pass | 81.4 | 0.0 | 5666 | 1882 | 168.4 | 39.5 | 999 of 2089 |
| `screens-pr-3353` | feature | 1 | pass | 133.8 | 0.0 | 9943 | 3898 | 258.6 | 40.9 | 2088 of 4203 |
| `screens-pr-3343` | feature | 2 | leak, pass | 216.6, 201.0 | 1.1, 0.0 | 5396, 5443 | 7834, 7130 | 159.8, 163.5 | 43.1, 42.5 | 4557 of 8300; 3961 of 7472 |
| `screens-pr-3341` | bug_fix | 1 | pass | 68.0 | 0.1 | 1652 | 2196 | 105.4 | 42.0 | 1231 of 2273 |
| `screens-pr-3319` | bug_fix | 1 | pass | 181.8 | 0.1 | 16678 | 4984 | 313.1 | 38.8 | 2503 of 5152 |
| `screens-pr-3306` | feature | 1 | pass | 295.4 | 0.1 | 8747 | 6772 | 224.9 | 26.4 | 3624 of 7053 |
| `screens-pr-3310` | bug_fix | 0 |  |  |  |  |  |  |  |  |
| `screens-pr-3281` | feature | 0 |  |  |  |  |  |  |  |  |
| `screens-pr-3293` | bug_fix | 0 |  |  |  |  |  |  |  |  |
| `screens-pr-3284` | feature | 0 |  |  |  |  |  |  |  |  |
| `screens-pr-3287` | feature | 0 |  |  |  |  |  |  |  |  |
| `screens-pr-3286` | bug_fix | 0 |  |  |  |  |  |  |  |  |
| `screens-pr-3265` | feature | 0 |  |  |  |  |  |  |  |  |
| `screens-pr-3255` | feature | 0 |  |  |  |  |  |  |  |  |
| `screens-pr-3250` | feature | 0 |  |  |  |  |  |  |  |  |

Each number is one request; a case with several answers lists them by value, in order. Every row with all its fields:
[`tries.tsv`](tries.tsv).

## The stop, and what a later run needs

- The run was stopped by cutting the list after the case in progress and stopping that case's container. The cut
  request's answer was not kept; its request is in the run's records.
- **The driver records the container's exit code, and the Erlang VM leaves with 0 on SIGTERM.** So `tasks.tsv` reads
  `exit 0` for `screens-pr-3310`, which has no statement. The tables here take a case's outcome from its
  `result.json`, which a stopped case does not have. A later start of `run/run_all.sh` with the same `OUT` would skip
  this case: start it with a new `OUT` and [`run/tasks_left.txt`](run/tasks_left.txt).
- `nerves-hub-web-pr-3146` is not in `run/tasks_left.txt`: it had its 3 answers.

## Files

| File | What it holds |
|---|---|
| `README.md` | this page |
| `statements/<case>/ticket.md`, `statement.json` | the 36 statements and their records: the writer (model, file and revision, the server's preset and defaults, the instruction's SHA-256), `ticket_sha256`, `written`, the answer it came from, the leak rule |
| `cases.md`, `cases.tsv` | one row per case: project, case, kind, answers, accepted or not, seconds, the statement's bytes, what each rejected answer was rejected for |
| `tries.md`, `tries.tsv` | one row per answer: times, token counts, the server's timings (`prompt_n`, `cache_n`, `prompt_ms`, `predicted_ms`, the speeds, `draft_n`, `draft_n_accepted`), the bytes of the thinking and of the answer, the leak hits |
| `rejections.tsv` | one row per rejected item: case, answer, rule, item |
| `totals.tsv` | sums by project and kind |
| `sha_check.tsv` | each `ticket.md`'s SHA-256 against its `statement.json` and the accepted answer's text |
| `tasks.tsv` | the driver's own record: each case's exit code, start, end and seconds |
| `cases_before.tsv` | the 46 cases before the run: project folder, case, kind, merge date, pull request, starting commit, the bytes of the change and of the hidden tests, and that no statement was there |
| `run/tasks.txt`, `run/tasks_left.txt` | the 46 cases in the order they were to run; the 9 that were not written |
| `run/make_list.sh` | makes the list and `cases_before.tsv`; refuses a list with a case that already has a statement |
| `run/run_all.sh` | the driver: one case at a time, the checks before each, the stop rules |
| `run/wait_cases.sh` | waits for a number of ended cases or the run's end |
| `run/summarize.exs` | the tables, from the driver's records |
| `run/collect.sh` | copies the statements out of the case folders and packs the raw records |

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
# the stop: the list cut after the case in progress, then that case's container stopped
truncate -s "$(head -n 38 run/tasks.txt | wc -c)" run/tasks.txt && docker stop -t 5 etf-statements2-screens-pr-3310
docker run --rm --label task-factory=1 --cpu-shares 256 -v <out>:/out:ro -v <job>/run:/run:ro \
  -v <WORK>/tasks:/tasks:ro -v <tables>:/tables etf-tooling:20261112 \
  elixir /run/summarize.exs /out /run/tasks.txt /tasks /tables
WORK=<the factory's work folder> OUT=<out> DEST=<a new folder> RAW=<archive> run/collect.sh run/tasks.txt
```

`run/tasks.txt` here is the list of 46 as it was at the start; the tables were made from it.

## Provenance and licence

The cases come from `nerves-hub/nerves_hub_web` (Apache-2.0) and `mbta/screens` (MIT), each licence checked at every
case's starting commit by the licence scan of the job that made it. The statements are the teacher model's output from
each case's own change and tests; no other text went into them, and no text written by Claude. The model's own terms
for its output were not read in this job.
