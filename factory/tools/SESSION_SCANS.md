# Session scans: what a teacher session may quote, and tries to leave the sandbox

`session_scans.py` applies the two session rules of [the dataset's rules](../../docs/dataset_rules.md), section 6
(registry E87), and marks the sessions in which a command tried to reach the network (registry E109). It reads one
stored session and the case's dependency table, and gives one verdict line per session with its evidence. It drops
nothing itself: it writes tables, and whoever builds the dataset applies them. Standard library only; tests in
`test_session_scans.py` (`python3 -I factory/tools/test_session_scans.py`), on made-up sessions only.

## What it reads

- **The session:** Pi's own log of the attempt, `<case>/pi-events.jsonl` in the engine's run folder: every tool call
  (`read`, `edit`, `write`, `bash`) with its arguments, and the result the model was shown. On the first 16 sessions
  every result in this log is the same text as the `tool_result` in the last stored request (`request-NNNN.json`),
  so the log is what came into the conversation. When the requests are stored, a result the model never saw (the
  last call of a session stopped by its token budget) is flagged `sent: no`; it is still scanned.
- **The case's dependency table:** made by `session_scans.py deps-table` from the sandbox image the session ran in
  (the `image` of the engine's `runtime.json`): the workspace's `mix.lock`, each dependency's
  `deps/<dep>/hex_metadata.config` (its name, version, licences and links, exactly as installed), and the names of the
  dependency, build, toolchain and Mix-archive folders. A licence is classed by `task_licence.licence_class`, the rule
  the task scan uses. `task_licence.py deps`'s `deps.tsv` is read too; its rows lack the links, so the hold-out
  column is then taken from the package names alone.
- **The held-out projects:** `../config/holdout.json` (the bench's 12 projects, their repositories and organisations).

## Where dependency files live in the sandbox

The factory's workspace image runs the agent in `/workspace` with `HEX_HOME=/opt/hex` and `MIX_HOME=/opt/mix`:

| Folder | What it holds | Counted as |
|---|---|---|
| `/workspace/deps/<dep>/` | each dependency's sources and `hex_metadata.config` | that dependency |
| `/workspace/_build/<env>/lib/<app>/` | the compiled applications (`ebin/`, `priv/`) | that dependency; the project's own application is the project |
| `/opt/hex/packages/hexpm/<package>-<version>.tar` | Hex's package cache (empty in the finished image) | that dependency |
| `/opt/mix/archives/` | Mix's archives (Hex itself) | a toolchain file, `unclear` when quoted |
| `/usr/local/lib/elixir/lib/<app>/` | Elixir's own applications (elixir, eex, ex_unit, iex, logger, mix) | standard library |
| `/usr/local/lib/erlang/lib/<app>-<vsn>/` and the rest of `/usr/local/lib/erlang/` | Erlang/OTP | standard library |

A relative path is resolved against the command's working folder (`cd` is followed within a command). Other roots
are given with `--workspace`, `--elixir-root`, `--otp-root`, `--hex-home` and `--mix-home`; `~/.hex` and `~/.mix`
under any home are recognised by their names.

**How the standard library is told apart:** by those two install folders, or, in a stack frame
(`(elixir 1.18.3) lib/enum.ex:2546: ...`), by the application's name: Elixir's six, and the OTP applications listed in
the image's `erlang/lib/`. Its reads are counted apart (`stdlib_quote_files`); they are neither in the list nor held
out.

## What counts as a quote

A file's content came into the conversation:

- a `read` of the file, or an `edit` of it (its result shows the changed lines);
- a shell command that gives the file, a glob of files, or a folder's files through `find -exec`, `xargs` or a
  `for` loop, to a printing program (cat, sed, head, tail, less, awk, nl, an editor view, a search of that one file,
  ...), or names it in an interpreter's code (`elixir -e`, `python -c`, `mix run`), when the output holds any line
  that is not an error message. When the command prints several files, each is counted and the evidence says that
  the output is shared. A one-file search with line numbers (`grep -n`) quotes the file only when its output holds a
  numbered line;
- a search whose output lines carry the file's path and the line (`path:12:...`, `path-12-...`, `path:...`),
  wherever the search started (`grep -rn ... .` from the project reaches `deps/`).

Not quotes, counted apart:

- `listing`: file names only (ls, find, tree, wc, `grep -l`, `grep -c`, an output line that is only a path);
- `trace`: a path in a stack frame, a warning, an error message, or a `path:line` reference in other text;
- `mention`: a path inside other text (a file's comment, a printed data structure);
- `no_content`: a read or a print that showed nothing of the file (only error lines, or a search without a hit);
- `write`: a file the model wrote; nothing of it was shown.

A compiler message that shows a line of a dependency's file in its code frame (`12 │ ...` above `└─ deps/...`) is
`unclear`. A path in a search pattern, a here-document written to a file, or an interpreter's load path
(`-pa _build/test/lib/<app>/ebin`, `ERL_LIBS`) is not a target.

## Verdicts

| Verdict | When | The rules page |
|---|---|---|
| `drop` with `quotes_dependency_outside_licence_list` | a quoted dependency's licence class is `outside` | section 6 and 9 |
| `drop` with `quotes_held_out` | a quoted dependency's source link is a held-out repository | section 6 |
| `unclear` | a quoted file whose dependency the table does not know, whose licence the table could not read (`none declared`, a git dependency, several licences with some outside), whose hold-out is unclear (by a held-out project's organisation but not its repository, or named like a held-out project with no source link), a Hex or Mix file, a compiler code frame of a dependency, files printed under the dependencies' root with no package known, or no dependency table | read by hand |
| `pass` | none of these | |

Both drop reasons are listed when both hold. A drop is the verdict even when other findings are unclear.

**The mark `tries_to_leave_sandbox`** is apart from the verdict: a command tried to reach the network or the project's
upstream repository. The kinds: `http_client` (curl, wget, ...), `git_remote` (clone, fetch, pull, push, ls-remote,
remote update, submodule update), `dev_tcp` and `dev_udp` (a `/dev/tcp/host/port` path), `raw_socket` (nc, ncat,
telnet, socat), `remote_shell` (ssh, scp, sftp), `name_lookup` (getent hosts, nslookup, dig, host, ping),
`package_registry` (`mix deps.get`, `mix deps.update`, `mix hex.*`, `mix local.hex`, `mix archive.install`,
apt-get, pip, npm, gem, ...) and `code_network` (code that opens a connection: `:httpc`, `:gen_tcp.connect`, `Req`,
`HTTPoison`, `urllib`, ...). Programs count only where a command starts (`which curl` and `curl --version` are not
tries); a `bash -c` string and a here-document fed to a shell are opened. A try at a loopback host (`localhost`,
`127.0.0.1`: the case's own database shares the sandbox's network) is recorded apart as `loopback`. A host is kept as
its name; an address is written as its kind (`ipv4:public`), never its digits. `(the project's repository)` marks a URL
that names the case's own repository.

## Tables

`deps-table` writes one row per dependency (`DEPS_COLUMNS`):

| Column | What it is |
|---|---|
| `kind` | `hex`, `git`, `unknown` (a folder in `deps/` not in `mix.lock`), `own` (the project's application), `tool` (a Mix archive), `stdlib` |
| `package`, `app`, `version` | the dependency's folder name, its application name and its version (for git, the locked commit) |
| `licences`, `class` | the licences its Hex metadata declares, and their class (`allowed`, `allowed, not an SPDX id`, `outside`, `several, some outside`, `none declared`, `git dependency: licence not read`, `not in the sandbox` for a locked package the sandbox did not fetch) |
| `links`, `holdout`, `holdout_note` | its metadata's links; `held`, `unclear` or `no`, and why |
| `source` | where the row came from |

`scan` writes `PREFIX.sessions.tsv` (one verdict line per session), `PREFIX.evidence.tsv` (one row per finding) and
`PREFIX.json` (the counts).

| `sessions.tsv` column | What it is |
|---|---|
| `project`, `case`, `attempt`, `kept` | the session; `kept` from the sessions index (`--index`) |
| `verdict`, `drop_reasons` | `pass`, `drop` or `unclear`, and the drop reasons |
| `tries_to_leave_sandbox` | `yes` when any command tried to reach the network |
| `tool_calls` | the session's tool calls |
| `dep_quote_files`, `dep_quote_packages` | the distinct dependency files quoted, and per package and version with its licence class: how many |
| `outside_quotes`, `held_out_quotes` | the distinct files behind each drop reason |
| `unclear_findings`, `unclear_items` | the findings left for a reading by hand, and what each is |
| `stdlib_quote_files` | the distinct standard-library files quoted |
| `listings`, `trace_lines`, `mention_lines` | listings (a command or an output line each), and the output lines of each kind |
| `no_content_reads` | reads and prints that showed nothing of the file |
| `network_tries`, `network_detail`, `loopback_probes` | the tries, each with its turn, kind and host; the loopback probes |
| `results_not_sent` | tool results the model never saw (empty when the requests are not stored) |

| `evidence.tsv` column | What it is |
|---|---|
| `turn`, `call`, `tool` | the model call (1 is the first; `request-NNNN.json` is turn − 1), the tool call's number in the session, the tool |
| `finding` | `quote`, `listing`, `trace`, `mention`, `no_content`, `write`, `unclear`, `network_try`, `loopback` |
| `category`, `package`, `version`, `licences`, `class`, `rule` | `dependency`, `stdlib`, `tool` or `network`; for a quote, its dependency row and the rule applied (`in_list`, `outside`, `held`, `unclear`, `stdlib`) |
| `target`, `how`, `lines` | the file's path (a host for the network); the program, tool or line kind; the output lines it showed |
| `sent`, `note` | whether the model saw the result; why, where it helps |

Never the quoted text: paths, names, licences, turns and counts only.

## Limits

- Content that left a dependency through another file (copied into the project, then printed there) is counted as
  the project's.
- A documentation lookup (`h Module` in IEx, `Code.fetch_docs/1`) prints a module's docs with no path; it is not
  seen.
- Text the model writes from memory is not a quote; only tool results are read.
- The hold-out check reads the package's own source links; a held-out project's package published from another
  repository is seen only by its name.

## Running

```sh
python3 -I factory/tools/session_scans.py deps-table --sandbox SANDBOX_DIR --out DEPS_DIR/<case>.tsv
python3 -I factory/tools/session_scans.py scan --deps DEPS_DIR --index sessions.tsv --out OUT/scan SESSION_DIR ...
```

The first run, with the scripts that extract each sandbox's metadata and run both steps in a container with no
network: [`docs/data/2026-11-12_session_scans/`](../../docs/data/2026-11-12_session_scans/README.md).
