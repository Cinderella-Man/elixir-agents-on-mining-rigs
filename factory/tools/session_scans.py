"""The session scans of the dataset's rules (docs/dataset_rules.md, section 6; registry E87, with the mark of E109).

A session is the teacher's whole attempt at one case. This tool reads what the agent stored of it (Pi's own log,
`<case>/pi-events.jsonl`: every tool call and the result the model was shown) and the case's dependency table, and
gives one verdict line per session with its evidence:

  quotes_dependency_outside_licence_list   the session read or printed a file of a dependency whose licence is
                                           outside the list (MIT, Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC)
  quotes_held_out                          the session read or printed a file of a held-out project's own package
                                           (config/holdout.json: the bench's 12 projects)
  unclear                                  a quoted dependency the table does not know, whose licence it could not
                                           read, or that may or may not belong to a held-out project; read by hand
  pass                                     none of these
and, apart from the verdict, the mark
  tries_to_leave_sandbox                   a command tried to reach the network or the project's upstream repository
                                           (E109; what happens to such a session is the owner's decision)

What counts as a quote: the file's content came into the conversation. That is a `read` tool call on the file, an
`edit` of it (its result shows the changed lines), or a shell command whose output shows lines of it: a printing
program (cat, sed, head, tail, less, awk, nl, an editor view, a search of one file, ...) given the file or a glob of
files, an interpreter given the file, `find -exec cat`, or a search whose output lines carry the file's path and the
line (`path:12:...`, `path-12-...`, `path:...`). A shell command quotes the files it gives a printing program whenever
its output holds any line that is not an error message; when it prints project files too, the evidence says that the
output is shared. Nothing but error lines, or a search without a hit, is not a quote (`no_content`). Not quotes, and
counted apart: a bare listing of file names (`listing`: ls, find, grep -l or -c, a line that is only a path), a path
inside an error message, a warning or a stack frame (`trace`), and a path inside other text (`mention`). A compiler
message that shows a line of a dependency's file in its code frame is `unclear`. A file of Elixir's or Erlang's own
standard library (the toolchain's install folders, or an application of the toolchain in a stack frame) is neither a
dependency of the list nor held out: its quotes are counted apart (`stdlib`). Hex's and Mix's own files (MIX_HOME,
HEX_HOME) are not in the table: a quote of one is `unclear`.

Where dependency files live in the factory's sandbox (the workspace image, `/workspace` with HEX_HOME=/opt/hex and
MIX_HOME=/opt/mix): the sources in `/workspace/deps/<dep>/`, the compiled applications in
`/workspace/_build/<env>/lib/<app>/`, Hex's package cache in `/opt/hex/packages/hexpm/<package>-<version>.tar`; Mix's
archives (Hex itself) in `/opt/mix/archives/`. The toolchain: Elixir in `/usr/local/lib/elixir/`, Erlang/OTP in
`/usr/local/lib/erlang/`. Other roots are given with --workspace, --elixir-root, --otp-root, --hex-home, --mix-home.

The evidence is paths, package names, licences, turn numbers and counts, never the quoted content. Hosts in the
network column are names; an address is written as its kind (`ipv4:public`), never its digits.

usage:
  python session_scans.py deps-table --sandbox DIR [--holdout holdout.json] --out TSV
      DIR holds what the case's sandbox image has: mix.lock, deps/<dep>/hex_metadata.config, and the lists
      deps.list, build.list, elixir.list, otp.list, archives.list (one name per line; run/extract_sandbox.sh in the
      data folder writes them). Writes the case's dependency table (columns below).
  python session_scans.py scan --deps TSV_OR_DIR [--holdout holdout.json] [--index sessions.tsv] --out PREFIX
                               SESSION_DIR [...]
      SESSION_DIR is an attempt folder (holding engine/<case>/pi-events.jsonl) or the engine's case folder itself.
      With a directory, --deps reads <dir>/<case id>.tsv for each session. --index (the sessions repository's
      sessions.tsv) gives each attempt's `kept`. Writes PREFIX.sessions.tsv (one verdict line per session),
      PREFIX.evidence.tsv (one row per finding) and PREFIX.json (counts).
Standard library only.
"""
import argparse
import fnmatch
import ipaddress
import json
import os
import posixpath
import re
import shlex
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "upstream"))
import task_licence  # noqa: E402  (licence_class, LOCK_HEX, LOCK_GIT: the task scan's own rules)

DEPS_COLUMNS = ["kind", "package", "app", "version", "licences", "class", "links", "holdout", "holdout_note",
                "source"]
SESSION_COLUMNS = ["project", "case", "attempt", "kept", "verdict", "drop_reasons", "tries_to_leave_sandbox",
                   "tool_calls", "dep_quote_files", "dep_quote_packages", "outside_quotes", "held_out_quotes",
                   "unclear_findings", "unclear_items", "stdlib_quote_files", "listings", "trace_lines",
                   "mention_lines", "no_content_reads", "network_tries", "network_detail", "loopback_probes",
                   "results_not_sent"]
EVIDENCE_COLUMNS = ["project", "case", "attempt", "turn", "call", "tool", "finding", "category", "package", "version",
                    "licences", "class", "rule", "target", "how", "lines", "sent", "note"]

IN_LIST = {"allowed", "allowed, not an SPDX id"}
ELIXIR_APPS = {"elixir", "eex", "ex_unit", "iex", "logger", "mix"}

# ---------------------------------------------------------------------------------------------------------------
# the dependency table


def erl_bins(text):
    return re.findall(r'<<"((?:[^"\\]|\\.)*)"(?:/utf8)?>>', text)


def hex_metadata(text):
    """name, app, version, licences and links of a hex_metadata.config (Erlang terms, as Hex writes them)."""
    # top-level terms start a line; the same keys nested in `requirements` are indented
    def field(name):
        m = re.search(r'^\{<<"' + name + r'">>\s*,\s*<<"((?:[^"\\]|\\.)*)"(?:/utf8)?>>\s*\}', text, re.M)
        return m[1] if m else ""
    lic = re.search(r'^\{<<"licenses">>\s*,\s*\[(.*?)\]\s*\}', text, re.S | re.M)
    links = re.search(r'^\{<<"links">>\s*,\s*\[(.*?)\]\s*\}\s*\.', text, re.S | re.M)
    urls = [u for u in erl_bins(links[1]) if re.match(r"https?://", u)] if links else []
    return {"name": field("name"), "app": field("app"), "version": field("version"),
            "licences": erl_bins(lic[1]) if lic else [], "links": urls}


SOURCE_LINK = re.compile(r"https?://(?:www\.)?(?:github\.com|gitlab\.com|codeberg\.org|bitbucket\.org)/"
                         r"([^/\s]+)/([^/\s#?]+)", re.I)


def link_repos(links):
    out = []
    for u in links:
        m = SOURCE_LINK.match(u)
        if m:
            out.append(f"{m[1]}/{re.sub(r'[.]git$', '', m[2])}".lower())
    return out


def holdout_status(package, links, holdout):
    """held / unclear / no, and why. A package is a held-out project's own when its source link is that project's
    repository; one by a held-out organisation, or one named like a held-out project with no link that settles it,
    is unclear."""
    repos = {r.lower() for r in holdout["repositories"]} | {p["repository"].lower() for p in holdout["projects"]}
    orgs = {o.lower() for o in holdout["organisations"]}
    names = {n.lower() for n in holdout["names"]}
    lr = link_repos(links)
    hit = [r for r in lr if r in repos]
    if hit:
        return "held", f"source link {hit[0]} is a held-out repository"
    org = [r for r in lr if r.split("/")[0] in orgs]
    if org:
        return "unclear", f"source link {org[0]}: a held-out project's organisation, not its repository"
    low = package.lower()
    named = low in names or any(low.startswith(n + "_") for n in names)
    if named and not lr:
        return "unclear", "named like a held-out project, and no source link"
    if named:
        return "no", f"named like a held-out project, but its source link is {lr[0]}"
    return "no", ""


def read_text(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def read_list(path):
    if not os.path.exists(path):
        return []
    return [x.strip() for x in read_text(path).splitlines() if x.strip()]


def deps_table(a):
    holdout = load_json(a.holdout)
    root = a.sandbox
    rows = {}
    lock_text = read_text(os.path.join(root, "mix.lock")) \
        if os.path.exists(os.path.join(root, "mix.lock")) else ""
    lock_hex = {k: (pkg, ver) for k, pkg, ver in task_licence.LOCK_HEX.findall(lock_text)}
    lock_git = {k: (url, ref) for k, url, ref in task_licence.LOCK_GIT.findall(lock_text)}
    dep_dirs = read_list(os.path.join(root, "deps.list"))
    for d in sorted(set(dep_dirs) | set(lock_hex) | set(lock_git)):
        meta_path = os.path.join(root, "deps", d, "hex_metadata.config")
        if os.path.exists(meta_path):
            m = hex_metadata(read_text(meta_path))
            source = "hex_metadata.config"
            if d in lock_hex and lock_hex[d][1] != m["version"]:
                source += f" (mix.lock says {lock_hex[d][1]})"
            if d not in dep_dirs:
                source += " (not in deps/)"
            ho, note = holdout_status(m["name"] or d, m["links"], holdout)
            rows[d] = ["hex", d, m["app"] or d, m["version"], " | ".join(m["licences"]),
                       task_licence.licence_class(m["licences"]), " ".join(m["links"]), ho, note, source]
        elif d in lock_git:
            url, ref = lock_git[d]
            ho, note = holdout_status(d, [url], holdout)
            rows[d] = ["git", d, d, ref[:12], "", "git dependency: licence not read", url, ho, note,
                       "mix.lock" + ("" if d in dep_dirs else " (not in deps/)")]
        elif d in lock_hex:
            ho, note = holdout_status(lock_hex[d][0], [], holdout)
            rows[d] = ["hex", d, d, lock_hex[d][1], "", "not in the sandbox", "", ho, note,
                       "mix.lock (no hex_metadata.config in deps/)"]
        else:
            ho, note = holdout_status(d, [], holdout)
            rows[d] = ["unknown", d, d, "", "", "not in mix.lock", "", ho, note, "deps/ only"]
    for app in read_list(os.path.join(root, "build.list")):
        if app not in rows and app not in {r[2] for r in rows.values()}:
            rows[app] = ["own", app, app, "", "", "the project's own application", "", "no", "", "_build/"]
    for app in read_list(os.path.join(root, "elixir.list")):
        rows.setdefault(app, ["stdlib", app, app, "", "", "Elixir", "", "no", "", "elixir/lib"])
    for entry in read_list(os.path.join(root, "otp.list")):
        app, _, vsn = entry.partition("-")
        rows.setdefault(app, ["stdlib", app, app, vsn, "", "Erlang/OTP", "", "no", "", "erlang/lib"])
    for entry in read_list(os.path.join(root, "archives.list")):
        name, _, vsn = entry.partition("-")
        rows.setdefault("archive:" + name, ["tool", name, name, vsn, "", "Mix archive: licence not read", "", "no",
                                            "", "MIX_HOME/archives"])
    with open(a.out, "w", encoding="utf-8") as f:
        f.write("\t".join(DEPS_COLUMNS) + "\n")
        for r in sorted(rows.values(), key=lambda r: (["own", "hex", "git", "unknown", "tool", "stdlib"].index(r[0]),
                                                      r[1])):
            f.write("\t".join(x.replace("\t", " ") for x in r) + "\n")
    counts = {}
    for r in rows.values():
        counts.setdefault(r[0], {}).setdefault(r[5], 0)
        counts[r[0]][r[5]] += 1
    print(json.dumps({"rows": len(rows), "kinds": counts,
                      "holdout": {h: sum(r[7] == h for r in rows.values()) for h in ("held", "unclear")}}))


class Deps:
    """A case's dependency table, read from deps-table's TSV (or task_licence.py's deps.tsv, whose rows lack the
    links, the app and the hold-out columns: those are then taken from the names)."""

    def __init__(self, path, holdout):
        self.by_name, self.by_app, self.stdlib, self.own, self.tools = {}, {}, set(), set(), {}
        with open(path, encoding="utf-8") as f:
            head = f.readline().rstrip("\n").split("\t")
            for ln in f:
                r = dict(zip(head, ln.rstrip("\n").split("\t")))
                kind = r.get("kind", "")
                if kind == "stdlib":
                    self.stdlib.add(r["package"])
                    continue
                if kind == "own":
                    self.own.add(r["package"])
                    continue
                if kind == "tool":
                    self.tools[r["package"]] = r
                    continue
                if not r.get("holdout"):
                    r["holdout"], r["holdout_note"] = holdout_status(r["package"], r.get("links", "").split(),
                                                                     holdout)
                r["app"] = r.get("app") or r["package"]
                self.by_name[r["package"]] = r
                self.by_app.setdefault(r["app"], r)

    def get(self, name):
        return self.by_name.get(name) or self.by_app.get(name)


# ---------------------------------------------------------------------------------------------------------------
# paths


class Roots:
    def __init__(self, a):
        self.ws = a.workspace.rstrip("/")
        self.elixir = a.elixir_root.rstrip("/")
        self.otp = a.otp_root.rstrip("/")
        self.hex = a.hex_home.rstrip("/")
        self.mix = a.mix_home.rstrip("/")


def resolve(path, cwd, roots):
    """An absolute, normalised path. `~` (the agent's home) is kept as the root `/~`, so `~/.hex` and `~/.mix` are
    still recognised by their names."""
    p = path.strip()
    if p.startswith("~/") or p == "~":
        p = "/~" + p[1:]
    if not p.startswith("/"):
        p = posixpath.join(cwd, p)
    return posixpath.normpath(p)


HOME_HEX = re.compile(r"/\.hex/")
HOME_MIX = re.compile(r"/\.mix/")


def classify_path(path, cwd, roots, deps):
    """(category, package, rest) of a path: dependency, stdlib, tool, project or other. `package` may be a glob,
    or "" for a dependency root itself (deps/, _build/test/lib/)."""
    p = resolve(path, cwd, roots)
    ws = roots.ws
    for prefix, kind in ((ws + "/deps", "deps"), (ws + "/_build", "build")):
        if p == prefix or p.startswith(prefix + "/"):
            parts = p[len(prefix) + 1:].split("/") if p != prefix else []
            if kind == "build":   # _build/<env>/lib/<app>/...
                if len(parts) < 2 or parts[1] != "lib":
                    return ("dependency", "", "/".join(parts))
                parts = parts[2:]
            if not parts or parts[0] == "":
                return ("dependency", "", "")
            name, rest = parts[0], "/".join(parts[1:])
            if deps is not None and name in deps.own:
                return ("project", name, rest)
            return ("dependency", name, rest)
    if p == roots.elixir or p.startswith(roots.elixir + "/"):
        parts = p[len(roots.elixir) + 1:].split("/")
        app = parts[1] if len(parts) > 1 and parts[0] == "lib" else "elixir"
        return ("stdlib", app, "/".join(parts))
    if p == roots.otp or p.startswith(roots.otp + "/"):
        parts = p[len(roots.otp) + 1:].split("/")
        app = parts[1].split("-")[0] if len(parts) > 1 and parts[0] == "lib" else "erts"
        return ("stdlib", app, "/".join(parts))
    # HEX_HOME and MIX_HOME, or the default ~/.hex and ~/.mix of any home
    hm = HOME_HEX.search(p)
    for rest in ([p[len(roots.hex) + 1:]] if p.startswith(roots.hex + "/") else []) + ([p[hm.end():]] if hm else []):
        m = re.match(r"packages/[^/]+/([A-Za-z0-9_]+)-(\d[^/]*)\.tar$", rest)
        return ("dependency", m[1], rest) if m else ("tool", "hex", rest)
    mm = HOME_MIX.search(p)
    for rest in ([p[len(roots.mix) + 1:]] if p.startswith(roots.mix + "/") else []) + ([p[mm.end():]] if mm else []):
        m = re.match(r"archives/([a-z_]+)-", rest)
        return ("tool", m[1] if m else "mix", rest)
    if p == ws or p.startswith(ws + "/"):
        return ("project", "", p[len(ws) + 1:])
    # a toolchain at another root: .../lib/elixir/lib/<app>/... or .../erlang/lib/<app>-<vsn>/...
    m = re.search(r"/lib/elixir/lib/(" + "|".join(ELIXIR_APPS) + r")/", p)
    if m:
        return ("stdlib", m[1], p)
    m = re.search(r"/erlang/lib/([a-z_]+)-\d[^/]*/", p)
    if m:
        return ("stdlib", m[1], p)
    return ("other", "", p)


# paths as they appear inside output lines: deps/<dep>/..., _build/<env>/lib/<app>/..., toolchain and Hex paths
PATH_IN_TEXT = re.compile(r"(?<![\w/.-])((?:\.{1,2}/|/[\w.-]+(?:/[\w.-]+)*/)?(?:deps|_build/[\w-]+/lib)/[\w.*-]+"
                          r"(?:/[^\s:'\"`,;()\[\]{}<>|]*)?|/usr/local/lib/(?:elixir|erlang)/[^\s:'\"`,;()\[\]{}<>|]*|"
                          r"(?:/opt/hex|/opt/mix|~/\.hex|~/\.mix)/[^\s:'\"`,;()\[\]{}<>|]*)")
STACK_FRAME = re.compile(r"^\s*(?:\[[^\]]*\]\s*)?\(([a-z][a-z0-9_]*) (\d[^)]*)\) (\S+?):(\d+)(?::\d+)?:")
GREP_LINE = re.compile(r"^(\S+?)[:-](\d+)[:-]")
GREP_FILE_LINE = re.compile(r"^(\S+?\.[A-Za-z0-9]+):(?!\d)")
DIAG_SNIPPET = re.compile(r"^\s*\d+\s*│")
DIAG_POINTER = re.compile(r"^\s*└─\s*(\S+?):(\d+)")
ERROR_LINE = re.compile(r"(No such file or directory|cannot open|cannot access|Is a directory|Permission denied|"
                        r"command not found|not a regular file|^(?:bash|sh|zsh): |^\S+: (?:invalid|unrecognized|"
                        r"illegal) option|^Usage: |^usage: |^Try '.*--help')")
TRACE_CONTEXT = re.compile(r"^\s*(?:\*\* |warning:|error:|\(\w+ \d|└─|│|\d+\s*│|==> |Compiling |stacktrace:|"
                           r"code: |left: |right: |at )")
LS_LONG = re.compile(r"^[-dlcbps][-rwxsStT@+.]{9,10}\s")

# ---------------------------------------------------------------------------------------------------------------
# shell commands

PRINTERS = {"cat", "tac", "head", "tail", "sed", "awk", "gawk", "mawk", "nl", "less", "more", "most", "bat", "batcat",
            "view", "vi", "vim", "nvim", "nano", "ed", "ex", "xxd", "od", "hexdump", "strings", "cut", "sort", "uniq",
            "column", "diff", "colordiff", "fold", "fmt", "pr", "paste", "rev", "iconv", "jq", "yq", "base64", "zcat",
            "zless", "zmore", "bzcat", "xzcat", "grep", "egrep", "fgrep", "rg", "ag", "ack", "pygmentize",
            "highlight", "comm", "join", "expand", "unexpand"}
GREPS = {"grep", "egrep", "fgrep", "rg", "ag", "ack"}
LISTERS = {"ls", "find", "tree", "du", "stat", "file", "wc", "md5sum", "sha1sum", "sha256sum", "sha512sum",
           "realpath", "readlink", "test", "[", "basename", "dirname", "exa", "eza", "fd", "fdfind", "locate"}
INTERPRETERS = {"elixir", "iex", "erl", "escript", "python", "python3", "ruby", "node", "perl", "php", "lua"}
PREFIXES = {"sudo", "env", "nice", "nohup", "time", "stdbuf", "ionice", "exec", "then", "do", "else", "elif", "if",
            "while", "until", "!", "{", "(", "xargs", "builtin"}
# options that take a value, per program (the value is not a file)
VALUE_OPTS = {
    "grep": {"-e", "-f", "-m", "-A", "-B", "-C", "-d", "-D", "--include", "--exclude", "--exclude-dir",
             "--exclude-from", "--regexp", "--file", "--max-count", "--context", "--after-context",
             "--before-context", "--label", "--color", "--colour"},
    "rg": {"-e", "-f", "-g", "--glob", "--iglob", "-t", "--type", "-T", "--type-not", "-m", "--max-count", "-A", "-B",
           "-C", "-M", "--max-columns", "-j", "--threads", "--sort", "--sortr", "-r", "--replace", "--regexp",
           "--file", "-E", "--encoding"},
    "sed": {"-e", "-f", "-l", "--expression", "--file"},
    "awk": {"-f", "-v", "-F"},
    "head": {"-n", "-c", "--lines", "--bytes"}, "tail": {"-n", "-c", "--lines", "--bytes", "-s"},
    "cut": {"-d", "-f", "-c", "-b"}, "sort": {"-k", "-t", "-o", "-S", "-T"}, "nl": {"-b", "-n", "-w", "-s", "-v"},
    "xxd": {"-l", "-s", "-c", "-g"}, "od": {"-A", "-t", "-N", "-j", "-w"}, "strings": {"-n", "-t"},
    "bat": {"-r", "--line-range", "-l", "--language", "-H", "--highlight-line"}, "fold": {"-w"},
    "find": {"-name", "-iname", "-path", "-ipath", "-type", "-maxdepth", "-mindepth", "-newer", "-regex", "-size",
             "-mtime", "-printf", "-exec", "-execdir", "-wholename"},
    "column": {"-s", "-c", "-t"}, "jq": {"--arg", "--argjson"}, "timeout": {"-s", "-k", "--signal"},
    "ls": {"-I", "--ignore", "-w"},
}
VALUE_OPTS["egrep"] = VALUE_OPTS["fgrep"] = VALUE_OPTS["grep"]
VALUE_OPTS["ag"] = VALUE_OPTS["ack"] = {"-G", "--ignore-dir", "-A", "-B", "-C", "-m", "--ignore"}
VALUE_OPTS["gawk"] = VALUE_OPTS["mawk"] = VALUE_OPTS["awk"]
VALUE_OPTS["batcat"] = VALUE_OPTS["bat"]
SCRIPT_FIRST = {"grep", "egrep", "fgrep", "rg", "ag", "ack", "sed", "awk", "gawk", "mawk", "jq", "yq"}
SCRIPT_OPTS = {"-e", "-f", "--regexp", "--file", "--expression"}


def split_command(cmd):
    """The simple commands of a shell command line, in order, and the bodies of its here-documents. Splits at
    unquoted ;, &, &&, ||, |, newlines and parentheses; keeps $(...) and backticks inside their command."""
    segs, heredocs, cur = [], [], []
    i, n, quote, depth = 0, len(cmd), None, 0
    pending = []      # here-document delimiters waiting for the end of the line
    while i < n:
        c = cmd[i]
        if quote:
            cur.append(c)
            if c == "\\" and quote == '"' and i + 1 < n:
                cur.append(cmd[i + 1])
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            if cmd[i + 1] == "\n":
                i += 2
                continue
            cur.append(c + cmd[i + 1])
            i += 2
            continue
        if c in "'\"`" and not (c == "`" and depth):
            quote = c
            cur.append(c)
            i += 1
            continue
        if cmd.startswith("$(", i):
            depth += 1
            cur.append("$(")
            i += 2
            continue
        if c == ")" and depth:
            depth -= 1
            cur.append(c)
            i += 1
            continue
        if cmd.startswith("<<", i) and not cmd.startswith("<<<", i):
            m = re.match(r"<<(-?)\s*(['\"]?)([A-Za-z_][\w-]*)\2", cmd[i:])
            if m:
                pending.append((m[3], m[1] == "-", len(segs)))
                cur.append(m[0])
                i += len(m[0])
                continue
        # `2>&1`, `&>file`, `>&2` redirect; they do not end a command
        redirect = c == "&" and ((i > 0 and cmd[i - 1] in "<>") or cmd.startswith("&>", i))
        if depth == 0 and (c in ";\n()|" or (c == "&" and not redirect)):
            if "".join(cur).strip():
                segs.append("".join(cur).strip())
            cur = []
            if c == "\n" and pending:
                # the here-documents' bodies follow this line
                j = i + 1
                for delim, strip_tabs, owner in pending:
                    body = []
                    while j < n:
                        e = cmd.find("\n", j)
                        line = cmd[j:] if e < 0 else cmd[j:e]
                        j = n if e < 0 else e + 1
                        if (line.lstrip("\t") if strip_tabs else line) == delim:
                            break
                        body.append(line)
                    heredocs.append((owner, "\n".join(body)))
                pending = []
                i = j
                continue
            i += 2 if cmd.startswith(("&&", "||"), i) else 1
            continue
        cur.append(c)
        i += 1
    if "".join(cur).strip():
        segs.append("".join(cur).strip())
    # each here-document with the command it feeds
    return segs, [(segs[o] if o < len(segs) else "", body) for o, body in heredocs]


def tokens(seg):
    try:
        return shlex.split(seg, comments=False, posix=True)
    except ValueError:
        return seg.split()


def program_of(toks):
    """(program, args, via_xargs) of a simple command's tokens, past assignments and prefixes (sudo, env, timeout N,
    xargs, ...)."""
    i, via_xargs = 0, False
    while i < len(toks):
        t = toks[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", t):
            i += 1
            continue
        if t in PREFIXES:
            via_xargs = via_xargs or t == "xargs"
            i += 1
            while i < len(toks) and toks[i].startswith("-"):
                i += 2 if toks[i] in ("-n", "-I", "-P", "-L", "-d", "-s", "-u", "-g", "-c") else 1
            continue
        if t == "timeout":
            i += 1
            while i < len(toks) and toks[i].startswith("-"):
                i += 2 if toks[i] in VALUE_OPTS["timeout"] else 1
            i += 1          # the duration
            continue
        return posixpath.basename(t), toks[i + 1:], via_xargs
    return "", [], via_xargs


def takes_value(a, vopts):
    """An option that is followed by its value: `-A`, `--include`, or a cluster of short flags ending in one (`-rnA`)."""
    if a in vopts:
        return True
    return bool(re.match(r"^-[A-Za-z]{2,}$", a)) and ("-" + a[-1]) in vopts


def file_args(prog, args):
    """The arguments of a program that name files or folders (not options, option values, patterns or scripts)."""
    vopts = VALUE_OPTS.get(prog, set())
    out, skip_script = [], prog in SCRIPT_FIRST
    for a in args:
        if a in SCRIPT_OPTS or a.startswith(("--regexp=", "--file=", "--expression=")) or (
                re.match(r"^-[A-Za-z]+$", a) and a[-1] in "ef" and prog not in ("awk", "gawk", "mawk")) or (
                prog in ("awk", "gawk", "mawk") and a == "-f"):
            skip_script = False
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--":
            out.extend(args[i + 1:])
            break
        if a.startswith("-") and len(a) > 1:
            i += 2 if takes_value(a, vopts) else 1
            continue
        if prog == "find" and a in ("!", "\\!", "{}", ";", "\\;", "+"):
            i += 1
            continue
        if skip_script:
            skip_script = False
            i += 1
            continue
        out.append(a)
        i += 1
    return out


def short_flags(args, vopts):
    """The letters of the short-flag clusters (`-rnl` gives r, n, l), option values left out."""
    out, i = set(), 0
    while i < len(args):
        a = args[i]
        if re.match(r"^-[A-Za-z]+$", a):
            out.update(a[1:])
        i += 2 if takes_value(a, vopts) else 1
    return out


def grep_list_mode(prog, args):
    """The search prints file names or counts only (grep -l, -L, -c, -q; rg --files ...)."""
    if any(a in ("--files-with-matches", "--files-without-match", "--count", "--quiet", "--silent", "--files",
                 "--count-matches") for a in args):
        return True
    return bool(short_flags(args, VALUE_OPTS.get(prog, set())) & set("lLcq"))


def grep_shows_names(prog, args, n_files, has_dir):
    """The search's output lines carry the file's name: a folder searched, several files, or -H. A single file
    searched without -H shows bare lines, so the file is known only from the command."""
    f = short_flags(args, VALUE_OPTS.get(prog, set()))
    if "--no-filename" in args or ("h" in f and prog not in ("rg",)) or (prog == "rg" and "-I" in args):
        return False
    return "H" in f or "--with-filename" in args or n_files > 1 or has_dir


def grep_searches(prog, args):
    """The search reads files or folders it is given (not only its input stream)."""
    f = short_flags(args, VALUE_OPTS.get(prog, set()))
    return bool(file_args(prog, args)) or prog in ("rg", "ag", "ack") or bool(f & set("rR")) or \
        "--recursive" in args


NET_PROGRAMS = {"curl": "http_client", "wget": "http_client", "http": "http_client", "https": "http_client",
                "aria2c": "http_client", "lynx": "http_client", "links": "http_client", "w3m": "http_client",
                "nc": "raw_socket", "ncat": "raw_socket", "netcat": "raw_socket", "telnet": "raw_socket",
                "socat": "raw_socket", "ssh": "remote_shell", "scp": "remote_shell", "sftp": "remote_shell",
                "ftp": "remote_shell", "ping": "name_lookup", "ping6": "name_lookup", "traceroute": "name_lookup",
                "nslookup": "name_lookup", "dig": "name_lookup", "host": "name_lookup", "drill": "name_lookup",
                "whois": "name_lookup"}
GIT_REMOTE = {"clone", "fetch", "pull", "push", "ls-remote", "archive"}
MIX_NET = re.compile(r"^(deps\.get|deps\.update|hex\.[\w.]+|local\.hex|local\.rebar|archive\.install|"
                     r"escript\.install|igniter\.install)$")
PKG_NET = {"pip": {"install", "download"}, "pip3": {"install", "download"}, "npm": {"install", "i", "ci", "update",
           "view", "info", "add"}, "npx": None, "yarn": {"add", "install", "upgrade"}, "pnpm": {"add", "install"},
           "gem": {"install", "fetch"}, "apt": {"install", "update"}, "apt-get": {"install", "update"},
           "cargo": {"install"}, "go": {"get", "install"}, "rebar3": {"get-deps", "upgrade"}}
DEV_TCP = re.compile(r"/dev/(tcp|udp)/([^/\s'\"]+)/(\d+)")
CODE_NET = re.compile(r"(:httpc\.request|:gen_tcp\.connect|:ssl\.connect|:gen_udp\.open|:inet\.gethostbyname|"
                      r":inet_res\.|\bReq\.(?:get|post|put|request|new)\b|\bHTTPoison\.|\bFinch\.request|"
                      r"\bTesla\.|\bMint\.HTTP\.connect|\burllib\.request|\burlopen\(|\brequests\.(?:get|post)|"
                      r"\bsocket\.create_connection|\bhttp\.client|\bfetch\(\s*['\"]https?:)")
URL = re.compile(r"\b(?:https?|ftp|git|ssh)://(?:[^@/\s'\"]+@)?(\[[0-9a-fA-F:]+\]|[^/:\s'\"]+)")


def host_kind(host):
    h = host.strip("[]").lower()
    if not h:
        return ""
    try:
        ip = ipaddress.ip_address(h)
    except ValueError:
        return h
    fam = "ipv4" if ip.version == 4 else "ipv6"
    if ip.is_loopback or ip.is_unspecified:
        return f"{fam}:loopback"
    if ip.is_private or ip.is_link_local:
        return f"{fam}:private"
    return f"{fam}:public"


def is_loopback(host):
    return host in ("localhost", "localhost.localdomain", "ip6-localhost") or host.endswith(":loopback")


def first_host(args):
    for a in args:
        m = URL.search(a)
        if m:
            return host_kind(m[1])
    for a in args:
        if a.startswith("-"):
            continue
        m = re.match(r"^(?:[^@/\s]+@)?(\[[0-9a-fA-F:]+\]|[A-Za-z0-9][\w.-]*\.[A-Za-z]{2,}|\d{1,3}(?:\.\d{1,3}){3}|"
                     r"localhost)(?::\S*)?$", a)
        if m:
            return host_kind(m[1])
    return ""


INFO_ONLY = {"--version", "-V", "--help", "-h", "-v", "-version", "-help"}


SHELLS = {"bash", "sh", "zsh", "dash"}


def simple_commands(command):
    """Every simple command of a command line, with `bash -c '...'` strings and here-documents fed to a shell opened
    in turn: (text it came from, segment, program, args, via_xargs). The `bash -c` segment itself is not returned.
    A here-document fed to any other program (`cat > file <<EOF`) is data, not commands."""
    texts, seen, k = [command], set(), 0
    while k < len(texts):
        segs, heredocs = split_command(texts[k])
        for owner, h in heredocs:
            if program_of(tokens(owner))[0] in SHELLS and h not in seen:
                seen.add(h)
                texts.append(h)
        for seg in segs:
            prog, args, via_xargs = program_of(tokens(seg))
            if prog in ("bash", "sh", "zsh", "dash") and "-c" in args:
                i = args.index("-c")
                if i + 1 < len(args) and args[i + 1] not in seen:
                    seen.add(args[i + 1])
                    texts.append(args[i + 1])
                continue
            yield k, seg, prog, args, via_xargs
        k += 1


def network_tries(command, repo_name):
    """Every try in a command to reach the network: (kind, host, upstream). `host` is a name, an address's kind or
    "" when the command does not say; `upstream` is yes when a URL names the project's own repository. Programs are
    taken only where a command starts (so `which curl` is not a try); device paths and network calls in code are
    looked for anywhere in the command, once."""
    out = []
    for _k, seg, prog, args, _x in simple_commands(command):
        kind, host = None, ""
        if prog in NET_PROGRAMS:
            if args and all(a in INFO_ONLY for a in args):
                continue
            kind, host = NET_PROGRAMS[prog], first_host(args)
        elif prog == "getent" and args and args[0] in ("hosts", "ahosts", "ahostsv4", "ahostsv6"):
            kind, host = "name_lookup", first_host(args[1:]) or (host_kind(args[1]) if len(args) > 1 else "")
        elif prog == "git":
            ci = args.index("-C") if "-C" in args else -2     # git -C <dir> fetch: the folder is not a subcommand
            sub = [a for j, a in enumerate(args) if not a.startswith("-") and j != ci + 1]
            if sub and (sub[0] in GIT_REMOTE or (sub[0] == "remote" and len(sub) > 1 and
                                                 sub[1] in ("update", "show", "prune")) or
                        (sub[0] == "submodule" and len(sub) > 1 and sub[1] in ("update", "sync", "add"))):
                kind, host = "git_remote", first_host(args)
        elif prog == "mix" and args and MIX_NET.match(args[0]):
            kind, host = "package_registry", "hex.pm"
        elif prog in PKG_NET and (PKG_NET[prog] is None or (args and args[0] in PKG_NET[prog])):
            kind, host = "package_registry", first_host(args)
        if kind:
            up = "yes" if repo_name and re.search(r"[/:]" + re.escape(repo_name) + r"(?:\.git)?(?:[/\s'\"]|$)",
                                                   seg) else "no"
            out.append((kind, host, up))
    for m in DEV_TCP.finditer(command):
        out.append(("dev_" + m[1], host_kind(m[2]), "no"))
    m = CODE_NET.search(command)      # code that opens a connection: one try per command
    if m:
        u = URL.search(command[m.start():m.start() + 300]) or URL.search(command)
        out.append(("code_network", host_kind(u[1]) if u else "", "no"))
    return out


# ---------------------------------------------------------------------------------------------------------------
# reading a session


def find_events(d):
    if os.path.exists(os.path.join(d, "pi-events.jsonl")):
        return os.path.join(d, "pi-events.jsonl")
    hits = []
    for root, dirs, files in os.walk(d):
        if "pi-events.jsonl" in files:
            hits.append(os.path.join(root, "pi-events.jsonl"))
    if len(hits) != 1:
        raise SystemExit(f"{d}: expected one pi-events.jsonl, found {len(hits)}")
    return hits[0]


def session_ids(events_path):
    case_dir = os.path.dirname(events_path)
    case = os.path.basename(case_dir)
    up = os.path.dirname(case_dir)
    attempt = os.path.basename(os.path.dirname(up)) if os.path.basename(up) == "engine" else os.path.basename(up)
    return case, attempt, case_dir


def result_text(r):
    if not isinstance(r, dict):
        return str(r or "")
    return "".join(c.get("text", "") for c in r.get("content", []) if isinstance(c, dict))


def read_session(events_path):
    """The session's cwd, its tool calls in order (turn, call, tool, args, result text, error, exit code) and the ids
    of the tool results the model was shown (from the last request, when the requests are stored)."""
    cwd, turn, calls, started = "", 0, [], {}
    with open(events_path, encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            t = e.get("type")
            if t == "session":
                cwd = e.get("cwd") or cwd
            elif t == "turn_start":
                turn += 1
            elif t == "tool_execution_start":
                started[e["toolCallId"]] = (turn, e.get("toolName", ""), e.get("args") or {})
            elif t == "tool_execution_end":
                tn, tool, args = started.pop(e["toolCallId"], (turn, e.get("toolName", ""), {}))
                r = e.get("result") or {}
                sc = r.get("structuredContent") if isinstance(r.get("structuredContent"), dict) else {}
                calls.append({"id": e["toolCallId"], "turn": tn, "tool": tool, "args": args,
                              "text": result_text(r), "error": bool(r.get("isError") or e.get("isError")),
                              "exit": sc.get("exit_code")})
    for k, (tn, tool, args) in started.items():   # started, never ended
        calls.append({"id": k, "turn": tn, "tool": tool, "args": args, "text": "", "error": True, "exit": None})
    for i, c in enumerate(calls, 1):
        c["call"] = i
    case_dir = os.path.dirname(events_path)
    reqs = sorted(x for x in os.listdir(case_dir) if re.match(r"request-\d+\.json$", x))
    shown = None
    if reqs:
        shown = set()
        last = load_json(os.path.join(case_dir, reqs[-1]))
        for m in last.get("messages", []):
            if isinstance(m.get("content"), list):
                for c in m["content"]:
                    if isinstance(c, dict) and c.get("type") == "tool_result":
                        shown.add(c.get("tool_use_id"))
    return cwd or "/workspace", calls, shown


# ---------------------------------------------------------------------------------------------------------------
# the scan of one session


class Finder:
    def __init__(self, deps, roots, holdout):
        self.deps, self.roots, self.holdout = deps, roots, holdout

    def expand(self, package):
        """A package position with a glob, matched against the table's dependencies."""
        if not any(ch in package for ch in "*?["):
            return [package]
        names = sorted(self.deps.by_name) if self.deps else []
        return [n for n in names if fnmatch.fnmatch(n, package)] or [package]

    def judge(self, category, package):
        """licence class, version, licences and the rule (in_list, outside, held, unclear) of a quoted package."""
        if category == "stdlib":
            return {"rule": "stdlib", "class": "standard library", "version": "", "licences": ""}
        if category == "tool":
            row = self.deps.tools.get(package) if self.deps else None
            return {"rule": "unclear", "class": row["class"] if row else "a toolchain file the table does not know",
                    "version": row["version"] if row else "", "licences": "", "note": "a file of Mix's or Hex's own"}
        row = self.deps.get(package) if self.deps else None
        if row is None:
            return {"rule": "unclear", "class": "not in the dependency table", "version": "", "licences": "",
                    "note": "not in the dependency table"}
        rules, notes = [], []
        if row["holdout"] == "held":
            rules.append("held")
        elif row["holdout"] == "unclear":
            notes.append(f"hold-out unclear ({row.get('holdout_note', '')})")
        cls = row["class"]
        if cls == "outside":
            rules.append("outside")
        elif cls not in IN_LIST:
            notes.append(f"licence not read ({cls})")
        if not rules and notes:
            rules.append("unclear")
        return {"rule": "+".join(rules) or "in_list", "class": cls, "version": row["version"],
                "licences": row["licences"], "note": "; ".join(notes)}


SOURCE_EXT = re.compile(r"\.(exs?|erl|hrl|eex|heex|leex|sface|js|mjs|ts|css|scss|md|markdown|json|txt|config|lock|"
                        r"toml|ya?ml|html|sql|c|h|cc|cpp|rs|zig|sh|app\.src|src|xrl|yrl|po|pot|csv)$")


def looks_like_file(rest):
    """A dependency path that names a file (or a glob of files), not a folder."""
    last = rest.split("/")[-1] if rest else ""
    return bool(last) and ("." in last.lstrip(".") or any(ch in last for ch in "*?["))


class Call:
    """What one tool call showed of dependency and standard-library files."""

    def __init__(self, c, shown):
        self.c, self.shown, self.rows = c, shown, []
        self.quoted = set()

    def add(self, finder, finding, category, package, target, how, lines, note="", rule=None):
        c = self.c
        j = finder.judge(category, package) if finding == "quote" else {}
        self.rows.append({"turn": c["turn"], "call": c["call"], "tool": c["tool"], "finding": finding,
                          "category": category, "package": package, "version": j.get("version", ""),
                          "licences": j.get("licences", ""), "class": j.get("class", ""),
                          "rule": rule or j.get("rule", ""), "target": target, "how": how, "lines": lines,
                          "sent": "" if self.shown is None else ("yes" if c["id"] in self.shown else "no"),
                          "note": "; ".join(x for x in (note, j.get("note", "")) if x)})
        if finding == "quote":
            self.quoted.add((target, package))


def output_lines(text):
    lines = text.splitlines()
    if lines and re.match(r"^Command exited with code \d+$", lines[-1].strip()):
        lines = lines[:-1]
    return lines


def scan_file_tool(call, finder, roots, deps, cwd0):
    """read, edit and write: the tool names the file."""
    c = call.c
    path = c["args"].get("path") or c["args"].get("file_path") or ""
    lines = output_lines(c["text"])
    cat, pkg, rest = classify_path(path, cwd0, roots, deps)
    if cat in ("dependency", "stdlib", "tool") and pkg:
        p = resolve(path, cwd0, roots)
        if c["tool"] == "write":
            call.add(finder, "write", cat, pkg, p, "write", 0, note="the model wrote this file; nothing of it shown")
        elif c["error"] or not c["text"].strip():
            call.add(finder, "no_content", cat, pkg, p, c["tool"], 0)
        else:
            call.add(finder, "quote", cat, pkg, p, c["tool"], len(lines))
        return
    n = sum(1 for ln in lines if PATH_IN_TEXT.search(ln))
    if n:
        call.add(finder, "mention", "dependency", "", "", "inside a file's text", n)


def command_side(command, cwd0, roots, deps, finder):
    """The files a shell command gives to its programs. Returns (printed, listed, searches, out_cwd):
    printed: {(path, package): (category, how, from_search)} - files a printing program or interpreter is given;
    listed: the same for programs that only list names; searches: the searches that read files or folders."""
    printed, listed, searches = {}, {}, []
    cwd, out_cwd = cwd0, None
    loop_vars, piped = {}, []      # `for f in <paths>` values; the files a lister last named (for xargs)
    for _k, seg, prog, args, via_xargs in simple_commands(command):
        if prog in ("cd", "pushd"):
            if args and not re.search(r"[$`*]", args[0]) and args[0] != "-":
                cwd = resolve(args[0], cwd, roots)
            continue
        if prog == "for" and len(args) >= 2 and args[1] == "in":
            loop_vars[args[0]] = args[2:]
            continue
        fargs = []
        for a in file_args(prog, args):
            m = re.fullmatch(r"\$\{?(\w+)\}?", a)
            fargs.extend(loop_vars.get(m[1], [a]) if m else [a])
        targets = []
        interp = prog in INTERPRETERS or (prog == "mix" and args[:1] in (["run"], ["eval"]))
        # an interpreter's code names its files anywhere; other programs through their arguments and through
        # command substitutions ($(...), `...`), never through a search pattern or a script
        subs = [x for pair in re.findall(r"\$\(([^)]*)\)|`([^`]*)`", seg) for x in pair if x]
        where = seg if interp else " ".join(subs)
        cand = fargs + [m[1] for m in PATH_IN_TEXT.finditer(where) if m[1] not in fargs]
        for a in cand:
            if a.startswith("-"):
                continue
            cat, pkg, rest = classify_path(a, cwd, roots, deps)
            if cat in ("dependency", "stdlib", "tool"):
                for p in (finder.expand(pkg) if pkg else [""]):
                    targets.append((cat, p, resolve(a, cwd, roots), rest))
        if via_xargs and not targets and not fargs and prog in PRINTERS:
            targets = list(piped)           # find deps/x ... | xargs cat: the files the lister named
        if prog in LISTERS:
            piped = targets
        if prog in GREPS and grep_searches(prog, args):
            searches.append((prog, args))
            out_cwd = out_cwd or cwd
        if not targets:
            continue
        how = prog + (" via xargs" if via_xargs else "")
        if prog in GREPS and grep_list_mode(prog, args):
            for cat, pkg, path, rest in targets:
                listed[(path, pkg)] = (cat, how)
        elif prog in GREPS:
            n_files = sum(1 for t in targets if looks_like_file(t[3]))
            has_dir = any(not looks_like_file(t[3]) for t in targets)
            names = grep_shows_names(prog, args, n_files, has_dir)
            numbered = "n" in short_flags(args, VALUE_OPTS.get(prog, set())) or "--line-number" in args
            for cat, pkg, path, rest in targets:
                if names:
                    continue                  # its output lines name the files (output side)
                # a search of one file shows bare lines; with -n each starts with its number
                printed.setdefault((path, pkg), (cat, how, True, numbered))
        elif prog in PRINTERS:
            for cat, pkg, path, rest in targets:
                printed[(path, pkg)] = (cat, how, False, False)
        elif interp:
            for cat, pkg, path, rest in targets:
                if pkg and SOURCE_EXT.search(rest.split("/")[-1] if rest else ""):
                    printed[(path, pkg)] = (cat, how, False, False)
        elif prog in LISTERS:
            ex = [i for i, x in enumerate(args) if x in ("-exec", "-execdir", "-ok")]
            runs = posixpath.basename(args[ex[0] + 1]) if ex and ex[0] + 1 < len(args) else ""
            for cat, pkg, path, rest in targets:
                if prog == "find" and runs in PRINTERS:
                    printed[(path, pkg)] = (cat, "find -exec " + runs, False, False)
                else:
                    listed[(path, pkg)] = (cat, how)
    return printed, listed, searches, out_cwd or cwd


def classify_line(ln, ref, in_list_search):
    stripped = LS_LONG.sub("", ln).strip().rstrip("/")
    if re.match(rf"^{re.escape(ref)}:\d+$", stripped):
        return "listing"                       # grep -c
    if DIAG_POINTER.match(ln) or ERROR_LINE.search(ln) or TRACE_CONTEXT.match(ln) or \
            re.search(rf"{re.escape(ref)}:\d+", ln):
        return "trace"
    if stripped == ref or stripped.split()[-1:] == [ref] and len(stripped.split()) <= 9 or \
            (in_list_search and stripped.startswith(ref)):
        return "listing"
    return "mention"


def output_side(call, finder, roots, deps, lines, searches, out_cwd):
    """Lines of a shell command's output that name dependency or standard-library files: search lines
    (`path:12:...`, quotes), stack frames and messages (traces), bare paths (listings), other text (mentions)."""
    reading = any(not grep_list_mode(p, a) for p, a in searches)
    list_search = any(grep_list_mode(p, a) for p, a in searches)
    per_file, counts = {}, {}
    for ln in lines:
        m = STACK_FRAME.match(ln)
        if m:
            app, path = m[1], m[3]
            cat, pkg = "", ""
            if path.startswith(("deps/", "/", "_build/", "./deps/")):
                cat, pkg, _r = classify_path(path, roots.ws, roots, deps)
            if not pkg:
                if deps and app in deps.own:
                    continue
                if app in ELIXIR_APPS or (deps and app in deps.stdlib) or (
                        not deps and app in ("stdlib", "kernel", "erts", "compiler")):
                    cat, pkg = "stdlib", app
                else:
                    row = deps.get(app) if deps else None
                    cat, pkg = "dependency", row["package"] if row else app
            if cat in ("dependency", "stdlib"):
                counts[("trace", cat, pkg, "stack frame")] = counts.get(("trace", cat, pkg, "stack frame"), 0) + 1
            continue
        refs = [x[1] for x in PATH_IN_TEXT.finditer(ln)]
        gm = (GREP_LINE.match(ln) or GREP_FILE_LINE.match(ln)) if reading else None
        if gm:
            cat, pkg, rest = classify_path(gm[1], out_cwd, roots, deps)
            if cat in ("dependency", "stdlib", "tool") and pkg:
                p = resolve(gm[1], out_cwd, roots)
                per_file.setdefault((p, pkg), [cat, 0])[1] += 1
                continue
        for ref in refs:
            cat, pkg, rest = classify_path(ref, out_cwd, roots, deps)
            if cat not in ("dependency", "stdlib", "tool") or not pkg:
                continue
            what = classify_line(ln, ref, list_search)
            counts[(what, cat, pkg, "output line")] = counts.get((what, cat, pkg, "output line"), 0) + 1
    # a compiler message that shows a line of a dependency's file (a code frame above its └─ pointer)
    for i, ln in enumerate(lines):
        m = DIAG_POINTER.match(ln)
        if m and any(DIAG_SNIPPET.match(x) for x in lines[max(0, i - 6):i]):
            cat, pkg, rest = classify_path(m[1], out_cwd, roots, deps)
            if cat == "dependency" and pkg:
                call.add(finder, "unclear", cat, pkg, resolve(m[1], out_cwd, roots), "compiler code frame", 1,
                         note="a compiler message shows a line of this dependency's file", rule="unclear")
    for (p, pkg), (cat, n) in sorted(per_file.items()):
        call.add(finder, "quote", cat, pkg, p, "search output", n)
    return counts


def scan_bash(call, finder, roots, deps, cwd0, repo_name):
    c = call.c
    command = c["args"].get("command") or ""
    for kind, host, up in network_tries(command, repo_name):
        if is_loopback(host):
            call.add(finder, "loopback", "network", "", host, kind, 0)
        else:
            call.add(finder, "network_try", "network", "", host, kind, 0,
                     note="names the project's repository" if up == "yes" else "")
    lines = output_lines(c["text"])
    content = [ln for ln in lines if ln.strip() and not ERROR_LINE.search(ln)]
    printed, listed, searches, out_cwd = command_side(command, cwd0, roots, deps, finder)
    counts = output_side(call, finder, roots, deps, lines, searches, out_cwd)
    searched = {(t, p) for t, p in call.quoted}
    numbered_lines = sum(1 for ln in content if re.match(r"^\d+[:-]", ln))
    shared = len(printed) > 1          # several files (or one glob over several packages) share the output
    for (path, pkg), (cat, how, from_search, numbered) in sorted(printed.items()):
        if from_search and ((path, pkg) in searched or any(p == pkg for _t, p in searched)):
            continue                          # the search's own output lines named the file
        if not content or (numbered and not numbered_lines):
            call.add(finder, "no_content", cat, pkg, path, how, 0,
                     note="nothing but error lines, or a search without a hit")
            continue
        if not pkg:
            call.add(finder, "unclear", "dependency", "", path, how, len(content),
                     note="printed files under the dependencies' root; which package is not known", rule="unclear")
            continue
        n = numbered_lines if numbered and not shared else len(content)
        call.add(finder, "quote", cat, pkg, path, how, n,
                 note="the output is shared with other printed files" if shared else "")
    for (path, pkg), (cat, how) in sorted(listed.items()):
        if (path, pkg) not in call.quoted:
            call.add(finder, "listing", cat, pkg, path, how + " (command)", 0)
    for (what, cat, pkg, how), n in sorted(counts.items()):
        call.add(finder, what, cat, pkg, "", how, n)


def scan_session(events_path, finder, roots, repo_name):
    cwd0, calls, shown = read_session(events_path)
    findings = []
    for c in calls:
        call = Call(c, shown)
        if c["tool"] in ("read", "edit", "write"):
            scan_file_tool(call, finder, roots, finder.deps, cwd0)
        elif c["tool"] == "bash":
            scan_bash(call, finder, roots, finder.deps, cwd0, repo_name)
        findings.extend(call.rows)
    return calls, findings, shown


def verdict_row(project, case, attempt, kept, calls, findings, shown):
    q = [f for f in findings if f["finding"] == "quote"]
    dep_q = [f for f in q if f["category"] == "dependency"]
    outside = [f for f in q if "outside" in f["rule"].split("+")]
    held = [f for f in q if "held" in f["rule"].split("+")]
    unclear = [f for f in findings if f["rule"] == "unclear"]
    reasons = []
    if outside:
        reasons.append("quotes_dependency_outside_licence_list")
    if held:
        reasons.append("quotes_held_out")
    verdict = "drop" if reasons else ("unclear" if unclear else "pass")
    pk = {}
    for f in dep_q:
        pk.setdefault((f["package"], f["version"], f["class"]), set()).add(f["target"])
    nets = [f for f in findings if f["finding"] == "network_try"]

    def lines_of(what):
        return sum(max(f["lines"], 1) for f in findings if f["finding"] == what)
    return [project, case, attempt, kept, verdict, ",".join(reasons), "yes" if nets else "no", str(len(calls)),
            str(len({f["target"] for f in dep_q})),
            "; ".join(f"{p} {v} ({c}): {len(paths)}" for (p, v, c), paths in sorted(pk.items())),
            str(len({f["target"] for f in outside})), str(len({f["target"] for f in held})),
            str(len(unclear)),
            "; ".join(sorted({f"{f['package'] or '?'}: {f['note'] or f['class']}" for f in unclear})),
            str(len({f["target"] for f in q if f["category"] == "stdlib"})),
            str(lines_of("listing")), str(lines_of("trace")), str(lines_of("mention")),
            str(sum(1 for f in findings if f["finding"] == "no_content")), str(len(nets)),
            "; ".join(f"turn {f['turn']}: {f['how']} {f['target'] or '(no host named)'}"
                      + (" (the project's repository)" if f["note"] else "") for f in nets),
            str(sum(1 for f in findings if f["finding"] == "loopback")),
            "" if shown is None else str(sum(1 for c in calls if c["id"] not in shown))]


def read_index(path):
    out = {}
    if not path:
        return out
    with open(path, encoding="utf-8") as f:
        head = f.readline().rstrip("\n").split("\t")
        for ln in f:
            r = dict(zip(head, ln.rstrip("\n").split("\t")))
            out[r.get("attempt", "")] = r
    return out


def scan(a):
    holdout = load_json(a.holdout)
    roots = Roots(a)
    index = read_index(a.index)
    srows, erows = [], []
    for d in a.sessions:
        ev = find_events(d)
        case, attempt, case_dir = session_ids(ev)
        table = os.path.join(a.deps, case + ".tsv") if os.path.isdir(a.deps) else a.deps
        deps = Deps(table, holdout) if os.path.exists(table) else None
        repo_name, project = "", index.get(attempt, {}).get("project", "")
        cj = None
        for p in (os.path.join(case_dir, "..", "..", "case", "case.json"), os.path.join(case_dir, "case.json")):
            if os.path.exists(p):
                cj = load_json(p)
                break
        if cj:
            url = (cj.get("repository") or {}).get("url", "")
            parts = url.rstrip("/").split("/")
            repo_name = re.sub(r"\.git$", "", parts[-1]) if parts else ""
            project = project or ("__".join(parts[-2:]) if len(parts) >= 2 else "")
        finder = Finder(deps, roots, holdout)
        calls, findings, shown = scan_session(ev, finder, roots, repo_name)
        if deps is None:
            findings.append({"turn": 0, "call": 0, "tool": "", "finding": "unclear", "category": "", "package": "",
                             "version": "", "licences": "", "class": "", "rule": "unclear", "target": table,
                             "how": "no dependency table", "lines": 0, "sent": "", "note": "no dependency table"})
        kept = index.get(attempt, {}).get("kept", "")
        srows.append(verdict_row(project, case, attempt, kept, calls, findings, shown))
        for f in findings:
            erows.append([project, case, attempt] + [str(f[k]) for k in EVIDENCE_COLUMNS[3:]])
    with open(a.out + ".sessions.tsv", "w", encoding="utf-8") as f:
        f.write("\t".join(SESSION_COLUMNS) + "\n")
        f.writelines("\t".join(x.replace("\t", " ") for x in r) + "\n" for r in srows)
    with open(a.out + ".evidence.tsv", "w", encoding="utf-8") as f:
        f.write("\t".join(EVIDENCE_COLUMNS) + "\n")
        f.writelines("\t".join(x.replace("\t", " ").replace("\n", " ") for x in r) + "\n" for r in erows)
    summary = {"sessions": len(srows),
               "verdicts": {v: sum(r[4] == v for r in srows) for v in ("pass", "drop", "unclear")},
               "kept": {v: sum(r[4] == v for r in srows if r[3] == "yes") for v in ("pass", "drop", "unclear")},
               "drop_reasons": {x: sum(x in r[5].split(",") for r in srows)
                                for x in ("quotes_dependency_outside_licence_list", "quotes_held_out")},
               "tries_to_leave_sandbox": sum(r[6] == "yes" for r in srows),
               "findings": {}}
    for r in erows:
        summary["findings"][r[6]] = summary["findings"].get(r[6], 0) + 1
    with open(a.out + ".json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=1)
    print(json.dumps(summary))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("deps-table")
    s.add_argument("--sandbox", required=True)
    s.add_argument("--holdout", default=os.path.join(HERE, "..", "config", "holdout.json"))
    s.add_argument("--out", required=True)
    s = sub.add_parser("scan")
    s.add_argument("sessions", nargs="+")
    s.add_argument("--deps", required=True)
    s.add_argument("--holdout", default=os.path.join(HERE, "..", "config", "holdout.json"))
    s.add_argument("--index")
    s.add_argument("--out", required=True)
    s.add_argument("--workspace", default="/workspace")
    s.add_argument("--elixir-root", default="/usr/local/lib/elixir")
    s.add_argument("--otp-root", default="/usr/local/lib/erlang")
    s.add_argument("--hex-home", default="/opt/hex")
    s.add_argument("--mix-home", default="/opt/mix")
    a = ap.parse_args()
    {"deps-table": deps_table, "scan": scan}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
