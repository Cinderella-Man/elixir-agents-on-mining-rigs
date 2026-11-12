"""Tests of session_scans.py on made-up sessions (standard library only; no text of any real session).

usage: python3 -I factory/tools/test_session_scans.py
"""
import argparse
import ipaddress
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import session_scans as ss  # noqa: E402

HOLDOUT = os.path.join(HERE, "..", "config", "holdout.json")

# A made-up case's dependency table, in deps-table's columns
DEPS = [
    ["own", "shop", "shop", "", "", "the project's own application", "", "no", "", "_build/"],
    ["hex", "goodlib", "goodlib", "1.2.0", "MIT", "allowed", "https://github.com/made-up/goodlib", "no", "",
     "hex_metadata.config"],
    ["hex", "copyleft_lib", "copyleft_lib", "0.3.1", "GPL-3.0", "outside", "https://github.com/made-up/copyleft_lib",
     "no", "", "hex_metadata.config"],
    ["hex", "ash", "ash", "3.0.0", "MIT", "allowed", "https://github.com/ash-project/ash", "", "",
     "hex_metadata.config"],
    ["hex", "dataloader", "dataloader", "2.0.0", "MIT", "allowed", "https://github.com/absinthe-graphql/dataloader",
     "", "", "hex_metadata.config"],
    ["hex", "quietlib", "quietlib", "0.1.0", "", "none declared", "", "no", "", "hex_metadata.config"],
    ["git", "gitdep", "gitdep", "0123456789ab", "", "git dependency: licence not read",
     "https://github.com/made-up/gitdep.git", "no", "", "mix.lock"],
    ["stdlib", "elixir", "elixir", "", "", "Elixir", "", "no", "", "elixir/lib"],
    ["stdlib", "stdlib", "stdlib", "6.2.1", "", "Erlang/OTP", "", "no", "", "erlang/lib"],
    ["tool", "hex", "hex", "2.5.3", "", "Mix archive: licence not read", "", "no", "", "MIX_HOME/archives"],
]


def bash(command, output="", exit_code=0):
    return ("bash", {"command": command}, output, exit_code)


def read(path, output="line one\nline two\n", error=False):
    return ("read", {"path": path}, output, 1 if error else 0)


class Session:
    """Writes one made-up session in the engine's layout: <attempt>/engine/<case>/pi-events.jsonl (and, when
    `requests` is set, the last request-NNNN.json with the tool results the model was shown), plus case/case.json."""

    def __init__(self, root, calls, case="shop-pr-7", attempt="20260101-000000-0000abcd", shown=None):
        self.dir = os.path.join(root, case, attempt)
        cdir = os.path.join(self.dir, "engine", case)
        os.makedirs(cdir)
        os.makedirs(os.path.join(self.dir, "case"))
        with open(os.path.join(self.dir, "case", "case.json"), "w") as f:
            json.dump({"repository": {"url": "https://github.com/made-up/shop", "revision": "0" * 40}}, f)
        ev = [{"type": "session", "cwd": "/workspace", "id": "s1", "version": 3}]
        ids = []
        for i, (tool, args, output, code) in enumerate(calls):
            tid = f"call_{i}"
            ids.append(tid)
            ev.append({"type": "turn_start"})
            ev.append({"type": "tool_execution_start", "toolCallId": tid, "toolName": tool, "args": args})
            text = output + (f"\n\nCommand exited with code {code}" if tool == "bash" and code else "")
            result = {"content": [{"type": "text", "text": text}]}
            if tool == "bash":
                result["structuredContent"] = {"exit_code": code, "output": output, "wall_time_seconds": 0.1}
            if code:
                result["isError"] = True
            ev.append({"type": "tool_execution_end", "toolCallId": tid, "toolName": tool, "result": result})
            ev.append({"type": "turn_end"})
        with open(os.path.join(cdir, "pi-events.jsonl"), "w") as f:
            f.writelines(json.dumps(e) + "\n" for e in ev)
        if shown is not None:
            msgs = [{"role": "user", "content": [{"type": "tool_result", "tool_use_id": ids[i], "content": "x"}]}
                    for i in shown]
            with open(os.path.join(cdir, f"request-{len(calls) - 1:04d}.json"), "w") as f:
                json.dump({"messages": msgs}, f)


def run_scan(calls, deps=DEPS, shown=None, with_table=True):
    tmp = tempfile.mkdtemp()
    s = Session(tmp, calls, shown=shown)
    table = os.path.join(tmp, "deps.tsv")
    if with_table:
        with open(table, "w") as f:
            f.write("\t".join(ss.DEPS_COLUMNS) + "\n")
            f.writelines("\t".join(r) + "\n" for r in deps)
    out = os.path.join(tmp, "out")
    a = argparse.Namespace(sessions=[s.dir], deps=table, holdout=HOLDOUT, index=None, out=out,
                           workspace="/workspace", elixir_root="/usr/local/lib/elixir",
                           otp_root="/usr/local/lib/erlang", hex_home="/opt/hex", mix_home="/opt/mix")
    ss.scan(a)

    def rows(path):
        with open(path) as f:
            head = f.readline().rstrip("\n").split("\t")
            return [dict(zip(head, ln.rstrip("\n").split("\t"))) for ln in f]
    return rows(out + ".sessions.tsv")[0], rows(out + ".evidence.tsv")


def found(ev, finding, **kw):
    return [e for e in ev if e["finding"] == finding and all(e[k] == v for k, v in kw.items())]


class Verdicts(unittest.TestCase):
    def test_clean_session_passes(self):
        v, ev = run_scan([read("lib/shop.ex"), bash("cd /workspace && mix test", "3 tests, 0 failures"),
                          ("edit", {"path": "lib/shop.ex", "edits": []}, "Successfully replaced text.", 0)])
        self.assertEqual(v["verdict"], "pass")
        self.assertEqual(v["tries_to_leave_sandbox"], "no")
        self.assertEqual(ev, [])

    def test_dependency_inside_the_list_passes(self):
        v, ev = run_scan([bash("cd /workspace && cat deps/goodlib/lib/goodlib.ex", "defmodule A do\nend\n")])
        self.assertEqual(v["verdict"], "pass")
        self.assertEqual(v["dep_quote_files"], "1")
        q = found(ev, "quote", package="goodlib")
        self.assertEqual(len(q), 1)
        self.assertEqual((q[0]["rule"], q[0]["class"], q[0]["how"], q[0]["lines"]), ("in_list", "allowed", "cat", "2"))
        self.assertEqual(q[0]["target"], "/workspace/deps/goodlib/lib/goodlib.ex")

    def test_dependency_outside_the_list_is_dropped(self):
        v, ev = run_scan([bash("sed -n '1,20p' deps/copyleft_lib/lib/c.ex", "x\ny\n")])
        self.assertEqual((v["verdict"], v["drop_reasons"]), ("drop", "quotes_dependency_outside_licence_list"))
        self.assertEqual(v["outside_quotes"], "1")
        self.assertEqual(found(ev, "quote")[0]["licences"], "GPL-3.0")

    def test_held_out_package_is_dropped(self):
        v, ev = run_scan([read("deps/ash/lib/ash/resource.ex")])
        self.assertEqual((v["verdict"], v["drop_reasons"]), ("drop", "quotes_held_out"))
        self.assertEqual(found(ev, "quote")[0]["rule"], "held")
        # also when only a search's output lines show it
        v, ev = run_scan([bash("grep -rn defmacro deps/ash/lib", "deps/ash/lib/ash/dsl.ex:12:  defmacro x\n")])
        self.assertEqual(v["drop_reasons"], "quotes_held_out")
        self.assertEqual(found(ev, "quote")[0]["how"], "search output")

    def test_listing_only_is_not_dropped(self):
        v, ev = run_scan([
            bash("ls deps/copyleft_lib/lib", "c.ex\nd.ex\n"),
            bash("find deps/copyleft_lib -name '*.ex'", "deps/copyleft_lib/lib/c.ex\ndeps/copyleft_lib/lib/d.ex\n"),
            bash("grep -rl encode deps/copyleft_lib", "deps/copyleft_lib/lib/c.ex\n"),
            bash("grep -rc encode deps/copyleft_lib", "deps/copyleft_lib/lib/c.ex:3\n")])
        self.assertEqual(v["verdict"], "pass")
        self.assertEqual(v["dep_quote_files"], "0")
        self.assertTrue(found(ev, "listing", package="copyleft_lib"))
        self.assertFalse(found(ev, "quote"))

    def test_path_inside_a_stack_trace_is_not_dropped(self):
        out = ("  1) test it works (ShopTest)\n"
               "     ** (RuntimeError) boom\n"
               "     code: Shop.run()\n"
               "     stacktrace:\n"
               "       (copyleft_lib 0.3.1) lib/copyleft_lib/x.ex:12: CopyleftLib.X.f/1\n"
               "       (shop 0.1.0) deps/copyleft_lib/lib/copyleft_lib/use.ex:3: Shop.Web.call/2\n"
               "       (elixir 1.18.3) lib/enum.ex:1714: Enum.map/2\n"
               "       test/shop_test.exs:5: (test)\n"
               "warning: deprecated, see deps/copyleft_lib/lib/copyleft_lib/old.ex:40\n")
        v, ev = run_scan([bash("mix test", out, 2),
                          bash("cat deps/copyleft_lib/lib/missing.ex",
                               "cat: deps/copyleft_lib/lib/missing.ex: No such file or directory", 1)])
        self.assertEqual(v["verdict"], "pass")
        # two stack frames and a warning in the test run, and the path in cat's error message
        self.assertEqual(v["trace_lines"], "5")
        self.assertEqual(sum(int(e["lines"]) for e in found(ev, "trace", package="copyleft_lib")), 4)
        self.assertTrue(found(ev, "trace", category="stdlib", package="elixir"))
        self.assertEqual(len(found(ev, "no_content", package="copyleft_lib")), 1)

    def test_standard_library_file_is_counted_apart(self):
        v, ev = run_scan([bash("cat /usr/local/lib/elixir/lib/elixir/lib/enum.ex | head -40", "defmodule Enum do\n"),
                          read("/usr/local/lib/erlang/lib/stdlib-6.2.1/src/lists.erl")])
        self.assertEqual(v["verdict"], "pass")
        self.assertEqual(v["stdlib_quote_files"], "2")
        self.assertEqual(v["dep_quote_files"], "0")
        self.assertEqual({e["package"] for e in found(ev, "quote", category="stdlib")}, {"elixir", "stdlib"})

    def test_unknown_dependency_is_unclear(self):
        v, ev = run_scan([bash("cat deps/mystery/lib/m.ex", "x\n")])
        self.assertEqual(v["verdict"], "unclear")
        self.assertIn("mystery: not in the dependency table", v["unclear_items"])

    def test_licence_not_read_and_held_out_maybe_are_unclear(self):
        for path, item in (("deps/gitdep/lib/g.ex", "gitdep: licence not read (git dependency"),
                           ("deps/quietlib/lib/q.ex", "quietlib: licence not read (none declared)"),
                           ("deps/dataloader/lib/dataloader.ex", "dataloader: hold-out unclear (source link")):
            v, ev = run_scan([read(path)])
            self.assertEqual(v["verdict"], "unclear", path)
            self.assertIn(item, v["unclear_items"])
        self.assertIn("organisation", found(ev, "quote")[0]["note"])

    def test_no_table_is_unclear(self):
        v, _ev = run_scan([bash("mix test", "ok")], with_table=False)
        self.assertEqual(v["verdict"], "unclear")

    def test_two_findings_are_both_reported(self):
        v, ev = run_scan([bash("cat deps/copyleft_lib/lib/c.ex", "x\n"), read("deps/ash/lib/ash.ex"),
                          bash("git ls-remote https://github.com/made-up/shop.git", "fatal: unable to access", 128)])
        self.assertEqual(v["verdict"], "drop")
        self.assertEqual(v["drop_reasons"], "quotes_dependency_outside_licence_list,quotes_held_out")
        self.assertEqual(v["tries_to_leave_sandbox"], "yes")
        self.assertIn("turn 3: git_remote github.com (the project's repository)", v["network_detail"])


class WhatCountsAsAQuote(unittest.TestCase):
    def test_search_lines_from_the_project_root_and_inside_a_dependency(self):
        v, ev = run_scan([
            bash('cd /workspace && grep -rn "ICS" . --include=*.ex',
                 "./deps/goodlib/lib/g.ex:12:  x\n./lib/shop.ex:3:  y\n"),
            bash("cd deps/copyleft_lib && grep -rn foo .", "./lib/c.ex:3:  foo()\n./lib/c.ex-4-  bar()\n")])
        self.assertEqual(v["drop_reasons"], "quotes_dependency_outside_licence_list")
        self.assertEqual(found(ev, "quote", package="goodlib")[0]["target"], "/workspace/deps/goodlib/lib/g.ex")
        self.assertEqual(found(ev, "quote", package="copyleft_lib")[0]["lines"], "2")

    def test_search_of_one_file_shows_bare_lines(self):
        v, ev = run_scan([bash('grep -n "def " deps/copyleft_lib/lib/c.ex', "3:  def a, do: 1\n")])
        self.assertEqual(v["drop_reasons"], "quotes_dependency_outside_licence_list")
        self.assertEqual(found(ev, "quote")[0]["how"], "grep")
        v, ev = run_scan([bash('grep -n "nothing" deps/copyleft_lib/lib/c.ex', "", 1)])
        self.assertEqual(v["verdict"], "pass")
        self.assertTrue(found(ev, "no_content"))

    def test_a_numbered_search_without_a_numbered_line_found_nothing(self):
        v, ev = run_scan([bash("sed -n '1,3p' deps/goodlib/lib/a.ex && grep -n nothing deps/copyleft_lib/lib/c.ex",
                               "x\ny\nz\n", 1)])
        self.assertEqual(v["verdict"], "pass")
        self.assertTrue(found(ev, "quote", package="goodlib"))
        self.assertTrue(found(ev, "no_content", package="copyleft_lib"))

    def test_a_file_searched_then_printed_keeps_both_rows(self):
        v, ev = run_scan([bash("grep -rn foo deps/goodlib/lib | head && sed -n '1,9p' deps/goodlib/lib/g.ex",
                               "deps/goodlib/lib/g.ex:3: foo\nline\nline\n")])
        self.assertEqual(sorted(e["how"] for e in found(ev, "quote")), ["search output", "sed"])
        self.assertEqual(v["dep_quote_files"], "1")

    def test_a_pattern_naming_a_dependency_is_not_a_target(self):
        v, ev = run_scan([bash('grep -rn "deps/copyleft_lib" lib', 'lib/shop.ex:3:  @path "deps/copyleft_lib"\n')])
        self.assertEqual(v["verdict"], "pass")
        self.assertTrue(found(ev, "mention", package="copyleft_lib"))

    def test_load_paths_of_an_interpreter_are_not_quotes(self):
        v, _ev = run_scan([bash("elixir -pa _build/test/lib/copyleft_lib/ebin -e 'IO.puts(:ok)'", "ok\n"),
                           bash("ERL_LIBS=_build/test/lib elixir /tmp/check.exs", "ok\n")])
        self.assertEqual(v["verdict"], "pass")
        v, _ev = run_scan([bash("elixir -e 'IO.puts File.read!(\"deps/copyleft_lib/lib/c.ex\")'", "x\n")])
        self.assertEqual(v["verdict"], "drop")

    def test_a_glob_quotes_every_dependency_it_matches(self):
        v, ev = run_scan([bash("cat deps/*/mix.exs", "defmodule A.MixProject do\n")])
        self.assertEqual(v["verdict"], "drop")
        self.assertIn("copyleft_lib", {e["package"] for e in found(ev, "quote")})
        self.assertIn("the output is shared", found(ev, "quote", package="goodlib")[0]["note"])

    def test_loops_and_xargs(self):
        v, ev = run_scan([bash("for f in deps/copyleft_lib/lib/*.ex; do echo $f; cat $f; done", "x\n")])
        self.assertEqual(v["verdict"], "drop")
        v, ev = run_scan([bash("find deps/copyleft_lib -name '*.ex' | xargs cat | head -20", "x\n")])
        self.assertEqual(v["verdict"], "drop")
        self.assertEqual(found(ev, "quote")[0]["how"], "cat via xargs")
        v, _ev = run_scan([bash("find deps/copyleft_lib -name '*.ex' | wc -l", "3\n")])
        self.assertEqual(v["verdict"], "pass")

    def test_find_exec_cat_and_heredoc_body(self):
        v, _ev = run_scan([bash("find deps/copyleft_lib -name '*.ex' -exec cat {} \\;", "x\n")])
        self.assertEqual(v["verdict"], "drop")
        # a here-document's body is written to a file, not run: its words are not programs or targets
        v, _ev = run_scan([bash("cat > /tmp/n.txt <<'EOF'\ncat deps/copyleft_lib/lib/c.ex\ncurl https://example.org\n"
                                "EOF\necho done", "done\n")])
        self.assertEqual(v["verdict"], "pass")

    def test_a_mention_inside_a_project_file(self):
        v, ev = run_scan([read("lib/shop_web/components.ex", "# icons come from the deps/gitdep folder\n")])
        self.assertEqual(v["verdict"], "pass")
        self.assertEqual(v["mention_lines"], "1")

    def test_a_result_the_model_never_saw_is_flagged(self):
        v, ev = run_scan([bash("cat deps/goodlib/lib/a.ex", "x\n"), bash("cat deps/goodlib/lib/b.ex", "y\n")],
                         shown=[0])
        self.assertEqual(v["results_not_sent"], "1")
        self.assertEqual([e["sent"] for e in found(ev, "quote")], ["yes", "no"])


class NetworkTries(unittest.TestCase):
    def kinds(self, command):
        return [(k, h) for k, h, _u in ss.network_tries(command, "shop")]

    def test_each_kind_of_try(self):
        public = str(ipaddress.IPv4Address(0x01010101))     # made at run time: no address in the file
        cases = {
            "curl -s https://example.org/x": [("http_client", "example.org")],
            "wget http://example.org/f.tar": [("http_client", "example.org")],
            "git clone https://github.com/made-up/shop.git /tmp/s": [("git_remote", "github.com")],
            "cd /workspace && git fetch origin": [("git_remote", "")],
            "git pull": [("git_remote", "")],
            "timeout 10 git ls-remote https://github.com/x/shop.git 2>&1 | head": [("git_remote", "github.com")],
            "git -C /tmp/s fetch --all": [("git_remote", "")],
            f"timeout 5 bash -c 'exec 3<>/dev/tcp/{public}/443' 2>&1": [("dev_tcp", "ipv4:public")],
            "nc -zv example.org 443": [("raw_socket", "example.org")],
            "ssh git@github.com": [("remote_shell", "github.com")],
            "getent hosts github.com || true": [("name_lookup", "github.com")],
            "mix deps.get": [("package_registry", "hex.pm")],
            "MIX_ENV=test mix hex.info goodlib": [("package_registry", "hex.pm")],
            "pip install requests": [("package_registry", "")],
            "python3 -c \"import urllib.request; urllib.request.urlopen('https://example.org')\"":
                [("code_network", "example.org")],
            "elixir -e ':inets.start(); :httpc.request(~c\"https://example.org\")'": [("code_network", "example.org")],
        }
        for cmd, want in cases.items():
            self.assertEqual(self.kinds(cmd), want, cmd)

    def test_not_tries(self):
        for cmd in ("which curl wget git python3", "curl --version", 'grep -rn "github.com" lib', "cat .git/config",
                    "git status && git diff", "command -v nc", "mix test", "echo https://example.org"):
            self.assertEqual(self.kinds(cmd), [], cmd)

    def test_loopback_is_recorded_apart(self):
        v, ev = run_scan([bash("(command -v nc && nc -zv localhost 5432) 2>&1", "open"),
                          bash("bash -c '</dev/tcp/127.0.0.1/5432' && echo open", "open")])
        self.assertEqual(v["tries_to_leave_sandbox"], "no")
        self.assertEqual(v["loopback_probes"], "2")
        self.assertEqual(v["verdict"], "pass")

    def test_the_mark_does_not_change_the_verdict(self):
        v, ev = run_scan([bash("curl https://example.org", "curl: (6) Could not resolve host", 6)])
        self.assertEqual((v["verdict"], v["tries_to_leave_sandbox"], v["network_tries"]), ("pass", "yes", "1"))
        self.assertEqual(found(ev, "network_try")[0]["turn"], "1")


class Parsing(unittest.TestCase):
    def test_split_command(self):
        segs, docs = ss.split_command("cd /w && cat > /tmp/a <<'EOF'\nx | y\nEOF\nA=$(find deps | wc -l); echo \"a;b\"")
        self.assertEqual(segs, ["cd /w", "cat > /tmp/a <<'EOF'", "A=$(find deps | wc -l)", 'echo "a;b"'])
        self.assertEqual(docs, [("cat > /tmp/a <<'EOF'", "x | y")])
        self.assertEqual(ss.split_command("mix test 2>&1 | tail -5 &>/dev/null")[0],
                         ["mix test 2>&1", "tail -5 &>/dev/null"])

    def test_program_of(self):
        self.assertEqual(ss.program_of(["timeout", "10", "git", "fetch"])[:2], ("git", ["fetch"]))
        self.assertEqual(ss.program_of(["FOO=1", "sudo", "-u", "x", "cat", "a"])[:2], ("cat", ["a"]))
        self.assertEqual(ss.program_of(["xargs", "-n", "1", "cat"]), ("cat", [], True))

    def test_file_args(self):
        self.assertEqual(ss.file_args("grep", ["-rn", "-A", "3", "pat", "deps/a", "lib"]), ["deps/a", "lib"])
        self.assertEqual(ss.file_args("grep", ["-e", "pat", "deps/a"]), ["deps/a"])
        self.assertEqual(ss.file_args("sed", ["-n", "1,5p", "deps/a/b.ex"]), ["deps/a/b.ex"])
        self.assertEqual(ss.file_args("head", ["-50", "deps/a/b.ex"]), ["deps/a/b.ex"])
        # an excluded path is a pattern, not a folder find is given
        self.assertEqual(ss.file_args("find", [".", "-iname", "*x*", "-not", "-path", "./deps/*"]), ["."])

    def test_classify_path(self):
        roots = ss.Roots(argparse.Namespace(workspace="/workspace", elixir_root="/usr/local/lib/elixir",
                                            otp_root="/usr/local/lib/erlang", hex_home="/opt/hex",
                                            mix_home="/opt/mix"))
        c = lambda p, cwd="/workspace": ss.classify_path(p, cwd, roots, None)[:2]  # noqa: E731
        self.assertEqual(c("~/.hex/packages/hexpm/jason-1.4.4.tar"), ("dependency", "jason"))
        self.assertEqual(c("~/.mix/archives/hex-2.5.3/hex-2.5.3/ebin/hex.app"), ("tool", "hex"))
        self.assertEqual(c("deps/plug/lib/plug.ex"), ("dependency", "plug"))
        self.assertEqual(c("lib/plug.ex", "/workspace/deps/plug"), ("dependency", "plug"))
        self.assertEqual(c("_build/test/lib/plug/ebin/plug.app"), ("dependency", "plug"))
        self.assertEqual(c("/usr/local/lib/erlang/lib/stdlib-6.2.1/src/lists.erl"), ("stdlib", "stdlib"))
        self.assertEqual(c("/opt/hex/packages/hexpm/plug-1.18.0.tar"), ("dependency", "plug"))
        self.assertEqual(c("/opt/mix/archives/hex-2.5.3/hex-2.5.3/ebin/hex.app"), ("tool", "hex"))
        self.assertEqual(c("lib/shop.ex"), ("project", ""))

    def test_host_kind_never_keeps_the_digits(self):
        self.assertEqual(ss.host_kind("127.0.0.1"), "ipv4:loopback")
        self.assertEqual(ss.host_kind(str(ipaddress.IPv4Address(0x0A000001))), "ipv4:private")
        self.assertEqual(ss.host_kind("Example.org"), "example.org")


class DependencyTable(unittest.TestCase):
    def test_deps_table_from_a_sandbox(self):
        tmp = tempfile.mkdtemp()
        sb = os.path.join(tmp, "sandbox")
        for d in ("goodlib", "ash", "dataloader", "gitdep"):
            os.makedirs(os.path.join(sb, "deps", d))
        meta = ('{<<"links">>,[{<<"GitHub">>,<<"https://github.com/%s">>}]}.\n{<<"name">>,<<"%s">>}.\n'
                '{<<"version">>,<<"%s">>}.\n{<<"app">>,<<"%s">>}.\n{<<"licenses">>,[<<"%s">>]}.\n'
                '{<<"requirements">>,\n [[{<<"name">>,<<"other">>},\n   {<<"app">>,<<"other">>}]]}.\n')
        for name, repo, ver, lic in (("goodlib", "made-up/goodlib", "1.2.0", "MIT"),
                                     ("ash", "ash-project/ash", "3.0.0", "MIT"),
                                     ("dataloader", "absinthe-graphql/dataloader", "2.0.0", "MIT")):
            with open(os.path.join(sb, "deps", name, "hex_metadata.config"), "w") as f:
                f.write(meta % (repo, name, ver, name, lic))
        with open(os.path.join(sb, "mix.lock"), "w") as f:
            f.write('%{\n  "goodlib": {:hex, :goodlib, "1.2.0", "abc", [:mix], [], "hexpm", "def"},\n'
                    '  "gitdep": {:git, "https://github.com/made-up/gitdep.git", "0123456789abcdef", [tag: "v1"]},\n}\n')
        lists = {"deps.list": "goodlib\nash\ndataloader\ngitdep\n", "build.list": "goodlib\nash\nshop\n",
                 "elixir.list": "elixir\nmix\n", "otp.list": "stdlib-6.2.1\nkernel-10.2.3\n",
                 "archives.list": "hex-2.5.3\n"}
        for n, t in lists.items():
            with open(os.path.join(sb, n), "w") as f:
                f.write(t)
        out = os.path.join(tmp, "deps.tsv")
        ss.deps_table(argparse.Namespace(sandbox=sb, holdout=HOLDOUT, out=out))
        with open(out) as f:
            head = f.readline().rstrip("\n").split("\t")
            rows = {r["package"]: r for r in (dict(zip(head, ln.rstrip("\n").split("\t"))) for ln in f)}
        self.assertEqual(head, ss.DEPS_COLUMNS)
        self.assertEqual((rows["goodlib"]["version"], rows["goodlib"]["class"], rows["goodlib"]["app"]),
                         ("1.2.0", "allowed", "goodlib"))
        self.assertEqual(rows["ash"]["holdout"], "held")
        self.assertEqual(rows["dataloader"]["holdout"], "unclear")
        self.assertEqual((rows["gitdep"]["kind"], rows["gitdep"]["class"]), ("git", "git dependency: licence not read"))
        self.assertEqual(rows["shop"]["kind"], "own")
        self.assertEqual((rows["stdlib"]["kind"], rows["stdlib"]["version"]), ("stdlib", "6.2.1"))
        self.assertEqual(rows["hex"]["kind"], "tool")
        self.assertNotIn("other", rows)


if __name__ == "__main__":
    unittest.main(verbosity=2)
