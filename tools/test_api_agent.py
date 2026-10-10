"""Offline test for tools/api_agent.py (no network, fake client): tool boundaries, cost cap, turn cap, path escapes,
redaction, prompt-cache placement and the status/list commands.

  py tools/test_api_agent.py
"""
import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import api_agent as A  # noqa: E402

FAKE_KEY = "sk-ant-test-FAKEKEY-0123456789abcdef"
PASS, FAIL = [], []


def check(name, ok, detail=""):
    (PASS if ok else FAIL).append(name)
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  -> {detail}"))


class FakeStream:
    def __init__(self, msg):
        self.msg = msg

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def get_final_message(self):
        return self.msg


class FakeMessages:
    def __init__(self, script):
        self.script = script
        self.calls = []

    def stream(self, **params):
        self.calls.append(json.loads(json.dumps(params)))
        step = self.script[min(len(self.calls) - 1, len(self.script) - 1)]
        return FakeStream(type("Msg", (), step)())


class FakeClient:
    def __init__(self, script):
        self.messages = FakeMessages(script)


def tool_step(uses, usage=None):
    return {"content": [{"type": "text", "text": "looking"}] +
                       [{"type": "tool_use", "id": f"tu_{i}", "name": n, "input": inp} for i, (n, inp) in enumerate(uses)],
            "usage": usage or {"input_tokens": 1000, "output_tokens": 100}, "stop_reason": "tool_use"}


def end_step(text, usage=None, stop="end_turn"):
    return {"content": [{"type": "text", "text": text}],
            "usage": usage or {"input_tokens": 1000, "output_tokens": 100}, "stop_reason": stop}


def make_repo(base):
    repo = os.path.join(base, "repo")
    os.makedirs(os.path.join(repo, "sub"))
    os.makedirs(os.path.join(repo, "tools"))
    os.makedirs(os.path.join(repo, ".git"))
    os.makedirs(os.path.join(repo, ".tripo"))
    w = lambda p, s: open(os.path.join(repo, p), "w", encoding="utf-8").write(s)  # noqa: E731
    w("a.txt", "alpha\nbeta\nkey " + FAKE_KEY + "\n")
    w("sub/b.luau", "local SECRET_WORD = 1\n" * 1000)
    w(".env", "ANTHROPIC_API_KEY=" + FAKE_KEY + "\nSECRET_WORD=1\n")
    w(".env.local", "SECRET_WORD=2\n")
    w(".git/config", "SECRET_WORD\n")
    w(".tripo/x.json", "SECRET_WORD\n")
    w("tools/test_dummy.py", "import os, sys\nprint('dummy ran', 'key-absent' if 'ANTHROPIC_API_KEY' not in os.environ else 'KEY-LEAK', sys.argv[1:])\n")
    w("tools/test_studio.py", "import studio_mcp\n")
    w("tools/other.py", "print('x')\n")
    open(os.path.join(base, "outside.txt"), "w").write("outside\n")
    return repo


def tools_checks(base, repo):
    out = os.path.join(base, "jobs", "t0")
    os.makedirs(out)
    red = A.Redactor([FAKE_KEY])
    T = A.Tools(repo, out, False, red)
    call = T.call
    t, e = call("read_file", {"path": "a.txt"})
    check("read_file ok + line numbers", not e and "1\talpha" in t, t)
    check("read_file redacts the key", FAKE_KEY not in t and "[redacted]" in t, t)
    for p in ["../outside.txt", os.path.join(base, "outside.txt"), ".env", ".ENV", ".env.local", "sub/../.env",
              ".git/config", ".tripo/x.json", "sub/../../outside.txt"]:
        t, e = call("read_file", {"path": p})
        check(f"read_file blocked: {p}", e and t.startswith("Error"), t)
    t, e = call("read_file", {"path": "sub/b.luau", "start_line": 10, "end_line": 12})
    check("read_file line range", not e and "10\t" in t and "12\t" in t and "13\t" not in t, t)
    t, e = call("list_dir", {"path": "."})
    check("list_dir hides .env/.git/.tripo", not e and "a.txt" in t and ".env" not in t and ".git" not in t and ".tripo" not in t, t)
    t, e = call("list_dir", {"path": ".."})
    check("list_dir blocked: ..", e, t)
    t, e = call("glob", {"pattern": "**/*"})
    check("glob hides denied", not e and "sub/b.luau" in t and ".env" not in t and ".git" not in t, t)
    t, e = call("glob", {"pattern": "../*"})
    check("glob blocked: ../*", e, t)
    t, e = call("grep", {"pattern": "SECRET_WORD", "max_results": 5})
    lines = [x for x in t.splitlines() if x.startswith("sub/b.luau:")]
    check("grep cap 5 + cut note", len(lines) == 5 and "cut at 5" in t, t)
    check("grep never reads .env/.git/.tripo", ".env" not in t and ".git" not in t and ".tripo" not in t, t)
    t, e = call("grep", {"pattern": "SECRET_WORD", "max_results": 100000})
    check("grep hard cap 400", len([x for x in t.splitlines() if ":" in x and "cut" not in x]) == A.LIMITS["grep_max"], len(t))
    t, e = call("grep", {"pattern": "(", "path": "."})
    check("grep bad regex -> error", e, t)
    t, e = call("grep", {"pattern": "x", "path": "../"})
    check("grep blocked: ../", e, t)
    t, e = call("run_test", {"path": "tools/test_dummy.py"})
    check("run_test off by default", e and "off" in t, t)
    t, e = call("write_note", {"name": "f.md", "content": "hello " + FAKE_KEY})
    note = os.path.join(out, "notes", "f.md")
    check("write_note ok in notes/", not e and os.path.isfile(note), t)
    check("write_note redacts the key", FAKE_KEY not in open(note, encoding="utf-8").read())
    t, e = call("write_note", {"name": "f.md", "content": "+more", "append": True})
    check("write_note append", not e and open(note, encoding="utf-8").read().endswith("+more"))
    for n in ["../usage.json", "../../evil.md", "../result.md", "result.md", os.path.join(base, "evil.md"), "", "sub/../../x.md"]:
        t, e = call("write_note", {"name": n, "content": "x"})
        check(f"write_note blocked: {n!r}", e, t)
    check("nothing written outside notes", not os.path.exists(os.path.join(base, "evil.md"))
          and not os.path.exists(os.path.join(out, "usage.json")) and not os.path.exists(os.path.join(base, "jobs", "evil.md")))
    t, e = call("nope", {})
    check("unknown tool -> error", e, t)
    t, e = call("read_file", {"path": "a.txt", "bogus": 1})
    check("bad args -> error", e, t)

    G = A.Tools(A.ROOT, out, False, red)
    t, e = G.call("git_readonly", {"args": ["log", "-1", "--oneline"]})
    check("git log ok", not e and t.startswith("exit 0"), t)
    for args in [["push"], ["commit", "-m", "x"], ["config", "user.name"], ["diff", "--output=x.txt"],
                 ["diff", "--no-index", "a", "b"], ["show", "HEAD:.env"], ["log", "--ext-diff"], ["-c", "x=y", "log"], []]:
        t, e = G.call("git_readonly", {"args": args})
        check(f"git blocked: {args}", e, t)
    check("git --output wrote nothing", not os.path.exists(os.path.join(A.ROOT, "x.txt")))
    # 검수 API review 10/10 blocker: git diff with paths outside the repository reads any file (it acts like --no-index)
    win = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "win.ini")
    outside = os.path.join(base, "outside.txt")
    for args in [["diff", win, outside], ["diff", "C:/Windows/win.ini", "C:/Windows/system.ini"], ["diff", "--", win],
                 ["diff", "HEAD", "--", "../outside.txt"], ["diff", "--", "C:/Windows/win.ini"], ["show", "HEAD:../x.txt"],
                 ["show", "C:/Windows/win.ini"], ["diff", "-Ofile.txt"], ["diff", "-O", "file.txt"], ["log", "-n", "C:/x"],
                 ["log", "--format=../x"], ["diff", "no_such_rev_zz9"], ["log", "--", ".envrc"], ["diff", "--git-dir=.."],
                 ["diff", "../outside.txt", "a.txt"], ["log", "--", "tools/../../x"]]:
        t, e = G.call("git_readonly", {"args": args})
        check(f"git outside blocked: {args}", e and "[fonts]" not in t.lower(), t)
    for args in [["log", "--format=%h", "-n", "2"], ["diff", "HEAD~1", "HEAD", "--stat"], ["show", "HEAD:tools/api_agent.py"],
                 ["diff", "HEAD~1..HEAD", "--", "tools/api_agent.py"], ["log", "-3", "--oneline", "--", "tools"],
                 ["rev-parse", "HEAD"]]:
        t, e = G.call("git_readonly", {"args": args})
        check(f"git allowed: {args}", not e and t.startswith("exit 0"), t[:200])

    # secrets by name and links out of the repository (junction on Windows, symlink elsewhere)
    for rel, body in [("secret.pem", "PEMDATA"), ("id_rsa", "RSADATA"), (".envrc", "ENVRC"), ("keys/server.key", "KEYDATA"),
                      (".git-credentials", "CREDDATA")]:
        os.makedirs(os.path.dirname(os.path.join(repo, rel)) or repo, exist_ok=True)
        open(os.path.join(repo, rel), "w").write(body + " SECRET_WORD\n")
        t, e = call("read_file", {"path": rel})
        check(f"read blocked by name: {rel}", e and body not in t, t)
    t, e = call("grep", {"pattern": "PEMDATA|RSADATA|ENVRC|KEYDATA|CREDDATA"})
    check("grep skips secret names", "DATA" not in t and "ENVRC" not in t, t)
    out_dir = os.path.join(base, "outside_dir")
    os.makedirs(out_dir, exist_ok=True)
    open(os.path.join(out_dir, "far.txt"), "w").write("FARAWAY SECRET\n")
    link = os.path.join(repo, "linked")
    try:
        import _winapi
        _winapi.CreateJunction(out_dir, link)
    except (ImportError, OSError):
        os.symlink(out_dir, link, target_is_directory=True)
    t, e = call("grep", {"pattern": "FARAWAY"})
    check("grep does not follow a junction out", "FARAWAY" not in t, t)
    t, e = call("glob", {"pattern": "**/far.txt"})
    check("glob does not list through a junction", "far.txt" not in t, t)
    t, e = call("read_file", {"path": "linked/far.txt"})
    check("read through a junction blocked", e and "FARAWAY" not in t, t)
    t, e = call("list_dir", {"path": "."})
    check("list_dir hides the junction out", "linked" not in t, t)

    # temporary worktree: the Luau CLI is copied in, and it is removed again (also when the run fails early)
    src = os.path.join(base, "wtsrc")
    os.makedirs(os.path.join(src, "build", "luau_cli_0_741"))
    open(os.path.join(src, "build", "luau_cli_0_741", "luau.exe"), "w").write("x")
    open(os.path.join(src, ".gitignore"), "w").write("build/\n")
    open(os.path.join(src, "f.txt"), "w").write("hello\n")
    g = lambda *a: subprocess.run(["git", "-C", src, *a], capture_output=True, text=True)  # noqa: E731
    g("init", "-q")
    g("add", "f.txt", ".gitignore")
    g("-c", "user.email=t@t", "-c", "user.name=t", "commit", "-q", "-m", "init")
    old_wt = A.WORKTREE_ROOT
    A.WORKTREE_ROOT = os.path.join(base, "wt")
    try:
        p = os.path.join(A.WORKTREE_ROOT, "j1")
        made = A.prepare_worktree(src, "HEAD", p)
        check("worktree made + Luau CLI copied", os.path.isfile(os.path.join(made, "build", "luau_cli_0_741", "luau.exe"))
              and os.path.isfile(os.path.join(made, "f.txt")))
        ok, msg = A.drop_worktree(src, p)
        check("worktree dropped", ok and not os.path.exists(p) and "j1" not in g("worktree", "list").stdout, msg)

        class Boom:
            class messages:
                @staticmethod
                def stream(**kw):
                    raise RuntimeError("early failure")
        pf = os.path.join(base, "wt_prompt.md")
        open(pf, "w", encoding="utf-8").write("x")
        a = A.parser().parse_args(["run", "--prompt-file", pf, "--out", os.path.join(A.JOBS_ROOT, "wtfail"), "--repo-dir", src,
                                   "--make-worktree", "HEAD"])
        try:
            A.run_job(a, client=Boom(), key=FAKE_KEY)
            raised = False
        except RuntimeError:
            raised = True
        wt = os.path.join(A.WORKTREE_ROOT, "wtfail")
        check("failed run removes its worktree", raised and not os.path.exists(wt) and "wtfail" not in g("worktree", "list").stdout,
              g("worktree", "list").stdout)
        u = json.load(open(os.path.join(A.JOBS_ROOT, "wtfail", "usage.json"), encoding="utf-8"))
        check("usage.json records the worktree removal", u.get("worktree_removed") is True, u)
    finally:
        A.WORKTREE_ROOT = old_wt

    R = A.Tools(repo, out, True, red)
    os.environ["ANTHROPIC_API_KEY_TEST_PROBE"] = "x"
    old = os.environ.get("ANTHROPIC_API_KEY")
    os.environ["ANTHROPIC_API_KEY"] = FAKE_KEY
    try:
        t, e = R.call("run_test", {"path": "tools/test_dummy.py", "args": ["--fast"]})
    finally:
        os.environ.pop("ANTHROPIC_API_KEY_TEST_PROBE", None)
        if old is None:
            os.environ.pop("ANTHROPIC_API_KEY", None)
        else:
            os.environ["ANTHROPIC_API_KEY"] = old
    check("run_test runs in worktree", not e and "exit 0" in t and "dummy ran" in t and "--fast" in t, t)
    check("run_test strips key env", "key-absent" in t, t)
    for p, args in [("tools/other.py", []), ("tools/test_studio.py", []), ("../repo/tools/test_dummy.py", []),
                    ("tools/test_dummy.py", ["; del x"]), ("tools/test_dummy.py", ["a b"]), ("tools\\..\\a.txt", [])]:
        t, e = R.call("run_test", {"path": p, "args": args})
        check(f"run_test blocked: {p} {args}", e, t)


def run_args(base, job, prompt, *extra):
    pf = os.path.join(base, "prompt.md")
    open(pf, "w", encoding="utf-8").write(prompt)
    return A.parser().parse_args(["run", "--prompt-file", pf, "--out", os.path.join(A.JOBS_ROOT, job), *extra])


def loop_checks(base, repo):
    # full run: tools then a final report
    fc = FakeClient([tool_step([("read_file", {"path": "a.txt"}), ("write_note", {"name": "n.md", "content": "note"}),
                                ("read_file", {"path": ".env"})]),
                     end_step("REPORT: all good")])
    m = A.run_job(run_args(base, "full", "review it", "--repo-dir", repo), client=fc, key=FAKE_KEY)
    out = os.path.join(A.JOBS_ROOT, "full")
    check("full: done", m["status"] == "done" and m["turns"] == 2, m)
    expect = 2 * (1000 * 2.0 + 100 * 10.0) / 1e6
    check("full: cost from usage", abs(m["cost_usd"] - expect) < 1e-9, (m["cost_usd"], expect))
    res = open(os.path.join(out, "result.md"), encoding="utf-8").read()
    check("full: result.md has report", "REPORT: all good" in res and "notes/n.md" in res, res)
    trans = open(os.path.join(out, "transcript.jsonl"), encoding="utf-8").read()
    kinds = [json.loads(x)["kind"] for x in trans.splitlines()]
    check("full: transcript records", kinds == ["request0", "response", "tool_results", "response"], kinds)
    check("full: key never in outputs", all(FAKE_KEY not in open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
                                            for d, _, fs in os.walk(out) for f in fs))
    usage = json.load(open(os.path.join(out, "usage.json"), encoding="utf-8"))
    check("full: usage.json totals", usage["tokens"]["input"] == 2000 and usage["tokens"]["output"] == 200 and usage["status"] == "done", usage)
    p0, p1 = fc.messages.calls
    check("cache: system breakpoint", p0["system"][0].get("cache_control") == {"type": "ephemeral"}, p0["system"])
    check("cache: last tool breakpoint", p0["tools"][-1].get("cache_control") == {"type": "ephemeral"}
          and all("cache_control" not in t for t in p0["tools"][:-1]))
    check("cache: top-level automatic", p0.get("cache_control") == {"type": "ephemeral"})
    check("no forced tool_choice", "tool_choice" not in p0)
    check("model default sonnet", p0["model"] == "claude-sonnet-5-5", p0["model"])
    res_blocks = p1["messages"][2]["content"]
    check("tool_result ids match", [b["tool_use_id"] for b in res_blocks if b["type"] == "tool_result"] == ["tu_0", "tu_1", "tu_2"])
    check("blocked read sent as is_error", res_blocks[2].get("is_error") is True and "denied" in res_blocks[2]["content"], res_blocks[2])
    check("key redacted in request to model", FAKE_KEY not in json.dumps(p1), "")

    # cost cap: $2 per turn (1M input tokens on sonnet), cap $3 -> 2 calls, then stop
    big = {"input_tokens": 1_000_000, "output_tokens": 0}
    fc = FakeClient([tool_step([("list_dir", {})], big)])
    m = A.run_job(run_args(base, "budget", "go", "--repo-dir", repo, "--max-usd", "3"), client=fc, key=FAKE_KEY)
    check("budget: stopped", m["status"] == "stopped_budget" and len(fc.messages.calls) == 2, (m["status"], len(fc.messages.calls)))
    check("budget: wrap-up told to model", any(b.get("type") == "text" and "[runner]" in b.get("text", "")
                                               for b in fc.messages.calls[1]["messages"][-1]["content"]))
    res = open(os.path.join(A.JOBS_ROOT, "budget", "result.md"), encoding="utf-8").read()
    check("budget: result.md saved with reason", "금액 상한" in res and "looking" in res, res)

    # cache pricing: reads at the cache rate, writes at 1.25x / 2x
    c = A.turn_cost({"input_tokens": 0, "output_tokens": 0, "cache_read_input_tokens": 1_000_000,
                     "cache_creation_input_tokens": 2_000_000,
                     "cache_creation": {"ephemeral_5m_input_tokens": 1_000_000, "ephemeral_1h_input_tokens": 1_000_000}},
                    "claude-opus-5-5")
    check("cost: cache read/write rates", abs(c - (0.20 + 4 * 1.25 + 4 * 2.0)) < 1e-9, c)
    check("cost: haiku price", abs(A.turn_cost({"input_tokens": 1_000_000, "output_tokens": 1_000_000}, "claude-haiku-5-5") - 0.60) < 1e-9)

    # turn cap
    fc = FakeClient([tool_step([("list_dir", {})])])
    m = A.run_job(run_args(base, "turns", "go", "--repo-dir", repo, "--max-turns", "3"), client=fc, key=FAKE_KEY)
    check("turns: stopped at 3", m["status"] == "stopped_turns" and len(fc.messages.calls) == 3, (m["status"], len(fc.messages.calls)))
    check("turns: wrap-up before last call", "[runner]" in json.dumps(fc.messages.calls[2]["messages"][-1]))

    # refusal, haiku/opus names
    fc = FakeClient([end_step("", stop="refusal")])
    m = A.run_job(run_args(base, "refuse", "go", "--repo-dir", repo, "--model", "haiku"), client=fc, key=FAKE_KEY)
    check("refusal: status", m["status"] == "refused" and fc.messages.calls[0]["model"] == "claude-haiku-5-5", m)

    # guards on the job folder and tests
    for job, extra, label in [(None, [], "out outside jobs root"), ("full", [], "existing job needs --overwrite")]:
        try:
            if job is None:
                a = A.parser().parse_args(["run", "--prompt-file", os.path.join(base, "prompt.md"), "--out", os.path.join(base, "elsewhere")])
            else:
                a = run_args(base, job, "x", "--repo-dir", repo)
            A.run_job(a, client=FakeClient([end_step("x")]), key=FAKE_KEY)
            check(label, False, "no SystemExit")
        except SystemExit:
            check(label, True)
    main = A.main_tree_of(A.ROOT)
    try:
        A.run_job(run_args(base, "tests_main", "x", "--repo-dir", main, "--allow-tests"), client=FakeClient([end_step("x")]), key=FAKE_KEY)
        check("--allow-tests refused on shared main tree", False, "no SystemExit")
    except SystemExit:
        check("--allow-tests refused on shared main tree", True)

    # status / list
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        A.cmd_status(A.parser().parse_args(["status", "full"]))
        A.cmd_list(None)
    s = buf.getvalue()
    check("status + list print", "job full  done" in s and "budget" in s and "total ~$" in s, s)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    base = tempfile.mkdtemp(prefix="api_agent_test_")
    old_root = A.JOBS_ROOT
    A.JOBS_ROOT = os.path.join(base, "jobs")
    try:
        repo = make_repo(base)

        tools_checks(base, repo)
        loop_checks(base, repo)
    finally:
        A.JOBS_ROOT = old_root
        shutil.rmtree(base, ignore_errors=True)
    print(f"\n{len(PASS)} passed, {len(FAIL)} failed")
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
