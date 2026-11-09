# Collecting Elixir training data: tasks, projects, licences and safety (2026-11-09)

How a public dataset for training Elixir coding agents is built, written for someone who has not built one before:
what a task is, how tasks differ from the cases of the Elixir SWE Bench, where the projects come from, which licences
they need, and how to run other people's code without risk. The project list is in
[docs/data/2026-11-09_elixir_project_pool](../../data/2026-11-09_elixir_project_pool/README.md). Nothing here is
legal advice.

## The short answers

| Question | Answer |
|---|---|
| Do we need many projects? | Not to start. The first published results of this kind used 10 or 11 big projects. Breadth matters later, because the model is judged on projects it never saw. A first wave of 40 projects, then a few hundred, is the proposal. |
| Do tasks need prepared branches that show the fix, like the bench's cases? | No. A training task is one row of data: a repository, a commit, and patches. The bench prepares branches by hand because it has 20 cases that must stay frozen and reviewed. Thousands of training tasks are made and checked by scripts. |
| Do we need a fork of every project? | Not to make tasks: a commit id pins the code. Forks are still worth having as mirrors, so the data keeps working if a project is deleted or rewritten. One mirror per project, in a GitHub organisation made for this, with no branch per task. |
| Do the projects need a particular licence? | Yes, because the published sessions contain their code. Only licences that allow copying and changing the code with a notice: MIT, Apache-2.0 and BSD. Not GPL, AGPL, LGPL or MPL, not source-available licences, not "no licence". |
| Can a project hack us? | Listing, forking and cloning run none of a project's code. Fetching dependencies, compiling and testing do. Those steps run only inside locked containers with no secrets and no network. Popular projects lower the odds; the container is what protects. |
| Can all of it be public? | Yes, if every step uses only publishable inputs: permissive code, task texts from an approved writer, sessions from a model whose terms allow it. The export ships the licences and notices with the data. |

## 1. What is being collected

- **A session** is one recorded attempt of a model at one task: it reads files, runs commands, edits code and ends
  with a patch. A session is kept only if tests that the model never saw pass on its patch. Sessions are the
  training examples.
- **A task** is what a session starts from:
  - a project at one exact commit;
  - a short statement of what to do;
  - tests that fail before the right change and pass after it;
  - a recipe for an environment in which the project builds and its tests run.
- **The teacher** is the strong model that works through the tasks. The student learns from the kept sessions.

So there are two things to build: a set of tasks, and the sessions on them.

## 2. A bench case and a training task are different things

| | A case of the Elixir SWE Bench | A training task |
|---|---|---|
| Purpose | to measure a model | to teach one |
| How many | 20 | thousands |
| Made by | hand: reviewed, three qualification rounds, two blind successes of a strong model | scripts, with automatic checks |
| Stored as | a prepared branch in a fork, a draft pull request for provenance, and a bundle of patches (acceptance, reference, incomplete, integrity) | one row of data: repository, commit, patches, test names, environment |
| Hidden tests | written or hardened by the curator | the pull request's own tests, or the project's existing tests |
| Statement | a hand-written ticket, as short as possible | written from the change and the failing tests by an approved writer |
| A flawed one costs | a wrong score | one wasted attempt |

The bench's care is right for a measuring tool and too slow for training data. Training tolerates a little noise;
it does not tolerate a few dozen tasks.

## 3. Three ways to make a task

### 3.1 From a merged pull request

Real work that a maintainer accepted.

1. Find merged pull requests that changed both code (`lib/`) and tests (`test/`).
2. The commit just before the pull request is the starting state.
3. Split the pull request in two: its test changes and its code changes.
4. Check it by running, in the environment:
   - with only the new tests applied, at least one test fails (the "fail-to-pass" tests);
   - with the code changes applied too, those tests pass;
   - tests that passed before still pass ("pass-to-pass").
5. A pull request that fails a check is dropped. In two public pipelines 1.7 % and 2.5 % of pull requests survived
   (Scale-SWE: 100,000 of 6,000,000; SWE-bench: 2,294 of about 90,000).

The model later sees the starting state and the statement. The new tests stay hidden and grade its patch.

### 3.2 A planted bug

1. Take a commit where the project's tests pass.
2. Change one thing with the language's own parser: flip a comparison, drop a clause, swap two arguments
   (the registry's Q478).
3. Keep the change only if at least one existing test now fails.
4. The task is to make the tests pass again; undoing the change is the known fix.

It costs no model time and gives hundreds of tasks per project. In SWE-smith's comparison, bugs made this way gave
93 % of the value of bugs taken from real pull requests
([report](../finetuning/reports/Fine%20tuning%20small%20models%20for%20Elixir.md)).

### 3.3 A removed function body

Remove the body of a function that tests cover; the task is to write it again. The sister repo's pipeline already
does this on Elixir's standard library.

### 3.4 The statement

The statement is never the issue or pull-request text: a repository's licence does not clearly cover those, and they
often leak the answer or leave it out. A writer on the approved list writes the statement from the change and the
failing tests, and a check rejects statements that give the fix away (Q480, Q526).

## 4. What one task looks like as data

A proposal, close to what SWE-rebench V2 publishes:

| Field | Example | Note |
|---|---|---|
| `task_id` | `phoenix-pr-1234` | made up for this page |
| `kind` | `pull_request`, `planted_bug` or `removed_body` | |
| `repository`, `mirror` | upstream and its mirror | |
| `base_commit` | a 40-character commit id | the starting state |
| `licence` | `MIT` | read at that commit, not today |
| `environment` | Elixir 1.16.2, OTP 26.2, setup commands | section 6 |
| `statement` | a few sentences | with its writer's id |
| `fix_patch` | the reference change | never shown to the model |
| `test_patch` or `bug_patch` | the hidden tests, or the planted change | |
| `fail_to_pass`, `pass_to_pass` | test names | what grading checks |
| `provenance` | pull request number, merge date | |

Nothing in a row needs a branch. Whoever runs the task checks out `base_commit`, applies `bug_patch` if there is
one, removes the history, and starts the model there.

## 5. Where the code lives: pointers, mirrors and branches

| Style | Who uses it | How a task finds its code | Fits |
|---|---|---|---|
| Pointer | SWE-bench, SWE-rebench V2 | the upstream repository and a commit id; patches in the row | large sets; nothing to maintain |
| Mirror with a branch per task | SWE-smith | a copy of the repository in the maker's GitHub organisation, one branch per task with the bug applied | browsing a task on GitHub; tens of thousands of branches to keep |
| Prepared fork | the Elixir SWE Bench | a hand-prepared baseline branch and a reference branch per case | a few frozen, reviewed cases |

**Proposal: pointers, plus one mirror per project.**
- A row points at a commit; the patches travel in the row. No branch per task.
- Each project is forked once into a GitHub organisation made for the dataset, not into a personal account. The
  fork is a mirror: it keeps the commits reachable if the project is deleted, renamed or rewritten, and gives every
  user of the dataset one stable place to clone from.
- GitHub's terms allow forking any public repository on GitHub (section D.5). The fork changes nothing about the
  code's licence.
- GitHub Actions stay switched off in that organisation, so no project's workflow ever runs there.

## 6. Environments: making an old commit build

A pull request from 2019 needs the Elixir of 2019. For each project and period the pipeline has to find:
- **the Elixir and Erlang/OTP versions:** from `.tool-versions`, the `elixir:` requirement in `mix.exs`, and the
  project's CI file; images for old versions exist (`hexpm/elixir`);
- **the dependencies:** fetched once, by the lock file, into a cache that later runs use offline;
- **services:** applications need a database; libraries usually need nothing;
- **proof:** the project's own test suite passes at that commit before any task is made from it.

One image per project and period serves all its tasks. This is the slowest part to automate. SWE-rebench V2's
builder (MIT) has an installer agent and an Elixir base image to start from.

## 7. Collecting the sessions, and how many are enough

1. For each task, start a fresh container with the starting state and no network.
2. The teacher works in the same harness the student will run in, several attempts per task.
3. After each attempt, the hidden tests are applied and run. A passing attempt is kept; the shortest passing attempt
   per task is preferred.
4. Everything is recorded: the messages with the model's reasoning and tool calls, the tool results, the model and
   its file, the settings, the task row, the verdict.
5. Checks run over the whole set before export (section 11).

**How much data others used:**

| Work | Tasks | Projects | Sessions |
|---|---:|---:|---:|
| SWE-Gym | 2,438 | 11 | 491, still improving with more |
| R2E-Gym (subset) | 4,600 | 10 | — |
| SWE-smith | about 50,000 | 128 | about 5,000 |
| SWE-rebench V2 (issue-linked) | 32,079, of them 416 Elixir | over 3,600 | — |
| Scale-SWE | 100,000 | 5,200 | 71,498 |
| NVIDIA Open-SWE-Traces | — | — | 1,138,945 |

From this project's earlier research: a first knee at 800 to 1,500 sessions if R2E-Gym's result carries over, about
2.5 points per doubling from 400 to 16,000 in SERA. No Elixir-only set of sessions was found; whether Open-SWE-Traces
holds Elixir sessions is not counted yet (E52). **A first target of 2,000 kept sessions on 1,000 to 2,000 tasks from
40 projects is enough to learn whether it works.** The 416 Elixir tasks in SWE-rebench V2 may cover part of it
(E36).

## 8. Licences

**Why they matter here.** A session quotes the project: the files the model reads, the patch it writes, the test
output. Publishing sessions is publishing parts of that code, so the code's licence has to allow it.

| Licence | Among the 1,182 repositories | Use | Why |
|---|---:|---|---|
| MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause | 826 by GitHub's reading | yes | copying and changing are allowed if the notices are kept; the sister repo's pipeline already works under this rule |
| ISC, 0BSD, Unlicense, CC0-1.0, MIT-0 | 18 | yes, once added to the allow-list (E51) | the same kind of terms, or fewer |
| No licence GitHub can name | 285 | only after a read: 125 are permissive by their Hex package or licence file, 141 have no licence file under the usual names, 17 have custom or unclear terms, 2 are copyleft | no licence means no permission |
| MPL-2.0, LGPL | 10 | no | changed files must stay under the same licence: workable, but it splits the dataset's terms |
| GPL, AGPL | 42 | no | the rows quoting them would have to carry that licence |
| Source-available (Business Source, Elastic, "community" licences) | among the 17 | no | they restrict use |
| WTFPL | 1 | after a read | informal terms |

**Rules that follow:**
1. **The licence at the task's commit counts,** not today's. Projects change licences.
2. **Scan every file,** not the repository's label: vendored code, test fixtures and assets often carry other terms.
   The sister repo's `license_scan.py` gives each file a verdict, and a workspace holds only files that pass.
3. **Dependencies have their own licences.** The model may read a dependency's source under `deps/`. A session that
   quotes a file without a passing verdict is left out.
4. **The dataset ships the notices:** each project's licence text, its copyright line, its repository and commit,
   and a note that the projects do not endorse the dataset. Apache-2.0 also asks for the project's `NOTICE` file and
   a statement that files were changed.
5. **No issue or pull-request discussion text.** GitHub's terms put contributions to a repository under its licence
   (section D.6), but comments are only licensed for viewing on GitHub.
6. **Each row names its licence,** as SWE-rebench V2 and Open-SWE-Traces do.
7. **The model's own text** follows the model's terms. DeepSeek's weights are MIT and its API terms allow training
   on outputs ([report](../finetuning/reports/Agentic%20RL%20for%20a%20DeepSeek%20teacher.md)).

## 9. Safety

**Where the risk is.**

| Step | Does project code run? | Risk |
|---|---|---|
| Reading GitHub and Hex metadata (this page's list) | no | none |
| Forking on GitHub | no | none, with Actions off |
| Cloning, without submodules | no | low: git does not run a repository's hooks on clone |
| Opening a clone in an editor with an Elixir language server | **yes**: it compiles the project | avoid outside a container |
| `mix deps.get` | the package manager runs, and `mix.exs` is code | a Hex client before 2.4.2 skipped a checksum check on locked dependencies (CVE-2026-32148) |
| `mix compile`, `mix test` | **yes**: the project's code and every dependency's compile-time code | full, by design |

Elixir's package manager and registry were audited in early 2026 for the Erlang Ecosystem Foundation: nine findings,
none critical and one high, with the high, medium and low ones fixed by 2026-04-03
([report](https://hex.pm/reports/2026/paraxial.pdf)). That is a sign of a cared-for ecosystem, not a guarantee about
any one package.

**Rules:**
1. Project code runs only in containers, on a machine that is not anyone's laptop.
2. A container holds no secret: no SSH key, no token for GitHub or Hugging Face, no cloud credential, no mounted home
   folder, no Docker socket.
3. The network is on only for the dependency download, which runs once per image with a current Hex. Building,
   testing and every model session run with the network off.
4. Not root, a read-only root file system, limits on memory, processes and time.
5. A fresh container per attempt; nothing an attempt writes is reused.
6. The workspace has a single commit, so no contributor's name or e-mail from the history reaches a session.
7. Output from a container is data. Nothing in it is run or followed as an instruction outside.

**What the project list adds.** Tiers A and B hold long-lived projects with many users, where a planted backdoor
is least likely. That lowers risk; rules 1 to 7 are what would contain one.

## 10. The project pool

From GitHub's and Hex's public metadata on 2026-11-09
([data](../../data/2026-11-09_elixir_project_pool/README.md)):
- 1,182 Elixir repositories have 100 or more stars.
- 929 are candidates with a permissive licence, outside the bench's projects: 171 in tier A, 264 in tier B, 494 in
  tier C. They hold 153,104 merged pull requests.
- 156 need their licence read by hand, 52 are copyleft, and 45 are held out: the bench's projects and their
  organisations' other repositories.

**The first wave** is the 40 tier-A repositories with the most merged pull requests, 51,592 between them. By kind:

| Kind | Examples from the first wave |
|---|---|
| The language and its frameworks | elixir-lang/elixir, phoenixframework/phoenix, phoenix_live_view, elixir-ecto/ecto, ecto_sql, elixir-plug/plug, oban-bg/oban, elixir-nx/nx, nerves-project/nerves |
| Libraries | swoosh, tesla, credo, bandit, floki, mint, ex_aws, faker, wallaby, bamboo, quantum-core, postgrex, explorer, membrane_core, surface, sentry-elixir |
| Applications | firezone, logflare, supabase/realtime, supavisor, papercups, farmbot_os |

Applications matter most, because the bench's cases are application work, and they are the scarcest: many open
Elixir applications are AGPL (teslamate, keila, claper) and so are out.

At the two published survival rates the first wave would give est. 880 to 1,290 tasks from real pull requests, and
all 929 candidates est. 2,600 to 3,800. Planted bugs add to that without limit.

## 11. What gets published

| Piece | Where | Content |
|---|---|---|
| The project list | this repository | every project, its licence, tier and counts |
| The tasks | a Hugging Face dataset | the rows of section 4 |
| The sessions | a Hugging Face dataset | messages, tool calls and results, model and settings, task id, verdict, licence |
| Licences and notices | inside both datasets | `LICENSE`, `LICENSES/`, `NOTICE`, a card naming every licence |
| The code | this repository and the sister repo | the scripts that made all of it |

The sister repo's export already writes this layout for its standard-library sessions, with a gate that refuses a
row whose inputs are not all approved.

## 12. The order of work

1. Approve the licence allow-list (E51) and the first wave (E46).
2. Create the mirror organisation and fork the first wave (E47).
3. Count SWE-rebench V2's and Open-SWE-Traces' Elixir rows and see which repositories they cover (E36, E52).
4. Build the sandbox rules for third-party projects (E49) and the environment recipes (E50).
5. Mine tasks from the first wave, in three strata (E8, E37), screened against the bench (E12) and gated (Q526).
6. Split by date and repository (E53): the newest pull requests and some whole repositories go to the dev lane.
7. Run the teacher (E9), keep the passing sessions, export and publish (E48).

## Sources

- SWE-bench: https://arxiv.org/abs/2310.06770
- SWE-smith and its guides: https://arxiv.org/abs/2504.21798, https://swesmith.com/guides/env_construction/,
  https://swesmith.com/guides/harnesses/
- SWE-rebench V2: https://arxiv.org/abs/2602.23866, https://huggingface.co/datasets/nebius/SWE-rebench-V2,
  https://github.com/SWE-rebench/SWE-rebench-V2
- Scale-SWE: https://arxiv.org/abs/2602.09892
- SWE-Gym: https://arxiv.org/abs/2412.21139
- NVIDIA Open-SWE-Traces: https://huggingface.co/datasets/nvidia/Open-SWE-Traces, https://arxiv.org/abs/2606.16038
- GitHub Terms of Service, section D: https://docs.github.com/en/site-policy/github-terms/github-terms-of-service
- Hex Package Manager Penetration Test (Paraxial.io, 2026-04-03): https://hex.pm/reports/2026/paraxial.pdf
- CVE-2026-32148: https://osv.dev/vulnerability/EEF-CVE-2026-32148
- The sister repo's data pipeline and its licence notes:
  [agentic data](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/bench/agentic_data/README.md),
  [pipeline note](https://github.com/Cinderella-Man/llms-on-crypto-mining-rigs/blob/main/docs/research/notes/agentic_data_pipeline.md)
