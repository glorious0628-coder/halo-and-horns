"""Offline test for tools/api_agent.py (no network, fake client): tool boundaries, read_image (limits, resize, cap), cost cap, turn cap, path escapes,
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
                 ["diff", "../outside.txt", "a.txt"], ["log", "--", "tools/../../x"], ["log", "-L1,5:../outside.txt"],
                 ["log", "-L", "1,5:C:/Windows/win.ini"], ["log", "-L1,5:.env"]]:
        t, e = G.call("git_readonly", {"args": args})
        check(f"git outside blocked: {args}", e and "[fonts]" not in t.lower(), t)
    for args in [["log", "--format=%h", "-n", "2"], ["diff", "HEAD~1", "HEAD", "--stat"], ["show", "HEAD:tools/api_agent.py"],
                 ["diff", "HEAD~1..HEAD", "--", "tools/api_agent.py"], ["log", "-3", "--oneline", "--", "tools"],
                 ["rev-parse", "HEAD"], ["log", "-L1,3:tools/api_agent.py", "-n", "1"]]:
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
        made = A.prepare_worktree(src, "HEAD", p, sparse=False)
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


def image_checks(base, repo):
    """read_image: repo-only png/jpg/webp, long edge cut to 1568 px, size/pixel limits, per-run cap (검수 10/11)"""
    import base64
    from PIL import Image
    os.makedirs(os.path.join(repo, "img"), exist_ok=True)
    Image.new("RGBA", (100, 50), (255, 0, 0, 128)).save(os.path.join(repo, "img", "small.png"))
    Image.new("RGB", (3000, 2000), (0, 128, 255)).save(os.path.join(repo, "img", "big.jpg"), quality=80)
    Image.new("RGB", (1000, 2400), (10, 200, 10)).save(os.path.join(repo, "img", "tall.webp"))
    Image.new("RGB", (8, 8)).save(os.path.join(repo, "img", "pic.bmp"))
    open(os.path.join(repo, "img", "fake.png"), "w").write("not an image\n")
    Image.new("RGB", (8, 8)).save(os.path.join(repo, ".env.png"))
    Image.new("RGB", (8, 8)).save(os.path.join(repo, ".git", "x.png"))
    Image.new("RGB", (8, 8)).save(os.path.join(base, "outside.png"))
    Image.new("RGB", (8, 8)).save(os.path.join(base, "outside_dir", "far.png"))  # reached only through the junction
    out = os.path.join(base, "jobs", "timg")
    os.makedirs(out)
    T = A.Tools(repo, out, False, A.Redactor([FAKE_KEY]), max_images=3)

    def decoded(blocks):
        img = [b for b in blocks if b.get("type") == "image"][0]["source"]
        return img["media_type"], Image.open(io.BytesIO(base64.b64decode(img["data"])))

    t, e = T.call("read_image", {"path": "img/small.png"})
    ok = not e and isinstance(t, list) and [b["type"] for b in t] == ["text", "image"]
    check("read_image png -> text + image blocks", ok, t if not ok else "")
    if ok:
        media, im = decoded(t)
        check("read_image small png kept size + alpha", media == "image/png" and im.size == (100, 50) and im.mode == "RGBA",
              (media, im.size, im.mode))
        check("read_image text: original and sent size", "original 100x50" in t[0]["text"] and "sent 100x50" in t[0]["text"]
              and "scaled down" not in t[0]["text"], t[0]["text"])
    t, e = T.call("read_image", {"path": "img/big.jpg"})
    ok = not e and isinstance(t, list)
    check("read_image big jpg ok", ok, t)
    if ok:
        media, im = decoded(t)
        check("read_image long edge cut to 1568", media == "image/jpeg" and im.size == (1568, 1045), (media, im.size))
        check("read_image text says scaled down", "original 3000x2000" in t[0]["text"] and "sent 1568x1045" in t[0]["text"]
              and "scaled down" in t[0]["text"], t[0]["text"])
    t, e = T.call("read_image", {"path": "img/tall.webp"})
    ok = not e and isinstance(t, list)
    check("read_image webp ok (tall: height cut)", ok and decoded(t)[1].size == (653, 1568), t if not ok else decoded(t)[1].size)
    for p in ["../outside.png", os.path.join(base, "outside.png"), ".env.png", ".git/x.png", "img/../../outside.png",
              "linked/far.png", "img/pic.bmp", "a.txt", "img/fake.png", "img/none.png", "img"]:
        t, e = T.call("read_image", {"path": p})
        check(f"read_image blocked: {p}", e and isinstance(t, str) and t.startswith("Error"), t)
    old = dict(A.LIMITS)
    try:
        T2 = A.Tools(repo, out, False, A.Redactor([FAKE_KEY]))  # T is at its cap already
        A.LIMITS["image_file_bytes_max"] = 100
        t, e = T2.call("read_image", {"path": "img/big.jpg"})
        check("read_image: file too large", e and "too large" in t, t)
        A.LIMITS.update(old)
        A.LIMITS["image_pixels_max"] = 1000
        t, e = T2.call("read_image", {"path": "img/big.jpg"})
        check("read_image: too many pixels", e and "too large" in t, t)
    finally:
        A.LIMITS.clear()
        A.LIMITS.update(old)
    check("refused reads do not count", len(T.images_sent) == 3 and T2.images_sent == [], (T.images_sent, T2.images_sent))
    t, e = T.call("read_image", {"path": "img/small.png"})
    check("read_image cap (3) reached", e and "cap" in t, t)
    check("cap: still 3 sent", T.images_sent == ["img/small.png", "img/big.jpg", "img/tall.webp"], T.images_sent)


def write_checks(base):
    """write mode (검수 2026-10-11): write/edit/delete/commit only inside the temporary worktree, run_test gating, the runner's
    push to api/<name> only (a local bare repository stands in for origin), refused branches, usage.json / result.md"""
    g = lambda repo, *a: subprocess.run(["git", "-C", repo, *a], capture_output=True, text=True, encoding="utf-8")  # noqa: E731
    origin = os.path.join(base, "origin.git")
    src = os.path.join(base, "wsrc")
    subprocess.run(["git", "init", "-q", "--bare", origin], check=True)
    subprocess.run(["git", "init", "-q", src], check=True)
    for k, v in (("user.name", "Test"), ("user.email", "t@example.com"), ("core.autocrlf", "false"), ("commit.gpgsign", "false")):
        g(src, "config", k, v)
    g(src, "remote", "add", "origin", origin)
    os.makedirs(os.path.join(src, "src"))
    os.makedirs(os.path.join(src, "tools"))
    os.makedirs(os.path.join(src, "docs"))
    for rel, data in [("AGENTS.md", b"rules\n"), ("src/a.luau", b"local a = 1\nlocal b = 2\nlocal b = 3\n"),
                      ("tools/test_ok.py", b"print('ok ran')\n"), ("docs/note.md", b"line1\r\nline2\r\n"),
                      (".gitignore", b"build/\nignored.txt\n"), ("other.txt", b"other\n")]:
        with open(os.path.join(src, rel), "wb") as f:
            f.write(data)
    g(src, "add", "-A")
    g(src, "commit", "-q", "-m", "init")
    g(src, "branch", "-M", "main")
    r = g(src, "push", "-q", "origin", "main")
    check("write: local origin ready", r.returncode == 0, r.stderr)
    main_before = g(origin, "rev-parse", "refs/heads/main").stdout.strip()
    head_before = g(src, "rev-parse", "HEAD").stdout.strip()
    branches_before = g(src, "branch", "--list").stdout

    old_wt = A.WORKTREE_ROOT
    A.WORKTREE_ROOT = os.path.join(base, "wtw")
    try:
        wt = A.prepare_worktree(src, "HEAD", os.path.join(A.WORKTREE_ROOT, "tw"), sparse=False)
        out = os.path.join(base, "jobs", "tw")
        os.makedirs(out)
        red = A.Redactor([FAKE_KEY])
        ctx = A.WriteCtx("api/tw", head_before, "HEAD", "claude-sonnet-5-5", "tw")
        T = A.Tools(wt, out, True, red, write=ctx)
        t, e = T.call("write_file", {"path": "src/new/b.luau", "content": "return 1\nreturn 2\n"})
        check("write: new file in a new folder", not e and "created src/new/b.luau" in t
              and open(os.path.join(wt, "src", "new", "b.luau"), "rb").read() == b"return 1\nreturn 2\n", t)
        t, e = T.call("write_file", {"path": "docs/note.md", "content": "line1\nline2\nline3\n"})
        check("write: an existing CRLF file stays CRLF", not e and open(os.path.join(wt, "docs", "note.md"), "rb").read()
              == b"line1\r\nline2\r\nline3\r\n", t)
        t, e = T.call("edit_file", {"path": "src/a.luau", "old_string": "local a = 1", "new_string": "local a = 10"})
        check("edit: unique string", not e and b"local a = 10\n" in open(os.path.join(wt, "src", "a.luau"), "rb").read(), t)
        t, e = T.call("edit_file", {"path": "src/a.luau", "old_string": "local b =", "new_string": "local c ="})
        check("edit: not unique -> error", e and "2 times" in t, t)
        t, e = T.call("edit_file", {"path": "src/a.luau", "old_string": "local b =", "new_string": "local c =", "replace_all": True})
        check("edit: replace_all", not e and open(os.path.join(wt, "src", "a.luau")).read().count("local c =") == 2, t)
        t, e = T.call("edit_file", {"path": "src/a.luau", "old_string": "nope nope", "new_string": "x"})
        check("edit: not found -> error", e and "not found" in t, t)
        t, e = T.call("edit_file", {"path": "docs/note.md", "old_string": "line1\nline2", "new_string": "A\nB"})
        check("edit: multi-line old_string on a CRLF file", not e and open(os.path.join(wt, "docs", "note.md"), "rb").read()
              == b"A\r\nB\r\nline3\r\n", t)
        t, e = T.call("edit_file", {"path": "src/none.luau", "old_string": "a", "new_string": "b"})
        check("edit: missing file -> error", e, t)
        for p in ["../outside.txt", os.path.join(base, "outside.txt"), ".env", ".env.local", "sub/../.env", ".git/config", ".git",
                  ".GIT/hooks/pre-commit", ".github/workflows/x.yml", "build/x.luau", ".claude/settings.json", "AGENTS.md",
                  "agents.MD", "CLAUDE.md", ".gitattributes", "docs/.gitmodules", "tools/run.bat", "tools/x.PS1", "tools/x.sh",
                  "x.exe", "x.dll", "src/a.luau.", "src/a.luau ", "src/a.luau:evil", "C:/Windows/x.txt", "/abs.txt", "", "  ",
                  ".", "src/..", "src/../../outside.txt", ".tripo/x.json", "id_rsa", "keys/server.pem"]:
            t, e = T.call("write_file", {"path": p, "content": "x"})
            check(f"write blocked: {p!r}", e and t.startswith("Error"), t)
        check("write blocked: nothing written outside", open(os.path.join(base, "outside.txt")).read() == "outside\n"
              and not os.path.exists(os.path.join(wt, ".env")) and not os.path.exists(os.path.join(wt, ".github")))
        t, e = T.call("delete_file", {"path": ".git/HEAD"})
        check("delete blocked: .git/HEAD", e and os.path.exists(os.path.join(wt, ".git")), t)
        t, e = T.call("delete_file", {"path": "src"})
        check("delete blocked: a folder", e and "folder" in t, t)
        t, e = T.call("delete_file", {"path": "../outside.txt"})
        check("delete blocked: outside", e, t)
        t, e = T.call("delete_file", {"path": "other.txt"})
        check("delete: a file", not e and not os.path.exists(os.path.join(wt, "other.txt")), t)
        old = dict(A.LIMITS)
        try:
            A.LIMITS["write_file_bytes_max"] = 10
            t, e = T.call("write_file", {"path": "src/big.luau", "content": "x" * 50})
            check("write: file size limit", e and "too large" in t and not os.path.exists(os.path.join(wt, "src", "big.luau")), t)
            A.LIMITS.update(old)
            A.LIMITS["write_total_bytes_max"] = ctx.bytes + 5
            t, e = T.call("write_file", {"path": "src/more.luau", "content": "x" * 50})
            check("write: total byte budget", e and "budget" in t, t)
            A.LIMITS.update(old)
            # an edit costs the new text only, not the whole file (a big Config.luau edited many times)
            with open(os.path.join(wt, "src", "huge.luau"), "w", encoding="utf-8") as f:
                f.write("-- pad\n" * 20000 + "local marker = 1\n")
            before = ctx.bytes
            t, e = T.call("edit_file", {"path": "src/huge.luau", "old_string": "local marker = 1", "new_string": "local marker = 2"})
            check("edit: the budget counts the new text, not the whole file", not e and ctx.bytes - before == 16,
                  f"{t} / +{ctx.bytes - before}")
            A.LIMITS["write_total_bytes_max"] = ctx.bytes + 20
            t, e = T.call("edit_file", {"path": "src/huge.luau", "old_string": "local marker = 2", "new_string": "local marker = 3"})
            check("edit: a small edit of a huge file fits a small budget", not e, t)
            t, e = T.call("edit_file", {"path": "src/huge.luau", "old_string": "local marker = 3", "new_string": "local marker = 4" + "x" * 40})
            check("edit: a big new text still hits the budget", e and "budget" in t, t)
            A.LIMITS.update(old)
            A.LIMITS["write_files_max"] = len(ctx.touched)
            t, e = T.call("write_file", {"path": "src/another.luau", "content": "x"})
            check("write: file count limit", e and "too many" in t, t)
        finally:
            A.LIMITS.clear()
            A.LIMITS.update(old)

        # a read-only job has no write tools
        RO = A.Tools(wt, out, True, red)
        for name, a in [("write_file", {"path": "x.txt", "content": "x"}), ("edit_file", {"path": "src/a.luau", "old_string": "a",
                        "new_string": "b"}), ("delete_file", {"path": "src/a.luau"}), ("git_commit", {"message": "m", "paths": ["a"]})]:
            t, e = RO.call(name, a)
            check(f"read-only job: {name} refused", e and "write tools are off" in t, t)

        # git_commit: only the listed paths, the runner's trailer, the shared tree untouched
        with open(os.path.join(wt, "src", "dirty.luau"), "w") as f:
            f.write("dirty\n")
        t, e = T.call("git_commit", {"message": "새 파일과 수정", "paths": ["src/new/b.luau", "src/a.luau", "other.txt"]})
        check("git_commit ok", not e and t.startswith("committed "), t)
        msg = g(wt, "log", "-1", "--format=%B").stdout.strip()
        check("git_commit: runner trailer is the last line", msg.splitlines()[-1] == "Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
              and msg.startswith("새 파일과 수정") and "api_agent job tw" in msg, msg)
        files = g(wt, "show", "--name-status", "--format=", "HEAD").stdout
        check("git_commit: only the listed paths (deleted file too)", "src/new/b.luau" in files and "src/a.luau" in files
              and "other.txt" in files and "dirty.luau" not in files and "note.md" not in files, files)
        check("git_commit: other work stays uncommitted", "dirty.luau" in g(wt, "status", "--porcelain").stdout
              and "note.md" in g(wt, "status", "--porcelain").stdout)
        check("git_commit: recorded", len(ctx.commits) == 1 and ctx.commits[0]["subject"] == "새 파일과 수정", ctx.commits)
        check("git_commit: the shared tree's HEAD and branches are untouched", g(src, "rev-parse", "HEAD").stdout.strip() == head_before
              and g(src, "branch", "--list").stdout == branches_before)
        t, e = T.call("git_commit", {"message": "again", "paths": ["src/a.luau"]})
        check("git_commit: nothing to commit -> error", e and "nothing to commit" in t, t)
        for a in [{"message": "", "paths": ["src/a.luau"]}, {"message": "m", "paths": []}, {"message": "m", "paths": ["../x"]},
                  {"message": "m", "paths": [".env"]}, {"message": "m", "paths": [".git/config"]}, {"message": "m", "paths": ["C:/x"]},
                  {"message": "m", "paths": [123]}, {"message": "m", "paths": "src/a.luau"}]:
            t, e = T.call("git_commit", a)
            check(f"git_commit blocked: {a}", e, t)

        # run_test: allowed while no script differs from the base, refused after a .py changes (unless allowed)
        t, e = T.call("run_test", {"path": "tools/test_ok.py"})
        check("run_test ok while only Luau/docs changed", not e and "ok ran" in t, t)
        T.call("write_file", {"path": "tools/test_new.py", "content": "import os\nos.system('echo pwned > pwned.txt')\n"})
        t, e = T.call("run_test", {"path": "tools/test_new.py"})
        check("run_test refused: a new .py differs from the base", e and "refused" in t and "test_new.py" in t
              and not os.path.exists(os.path.join(wt, "pwned.txt")), t)
        t, e = T.call("run_test", {"path": "tools/test_ok.py"})
        check("run_test refused: any test, once a .py differs", e and "refused" in t, t)
        T.call("git_commit", {"message": "py", "paths": ["tools/test_new.py"]})
        t, e = T.call("run_test", {"path": "tools/test_ok.py"})
        check("run_test refused: also after the .py is committed", e and "refused" in t, t)
        ctx2 = A.WriteCtx("api/tw", head_before, "HEAD", "claude-sonnet-5-5", "tw", allow_modified_py=True)
        t, e = A.Tools(wt, out, True, red, write=ctx2).call("run_test", {"path": "tools/test_ok.py"})
        check("run_test allowed with --allow-run-modified-py", not e and "ok ran" in t, t)
        ok, msg2 = A.drop_worktree(src, wt)
        check("write: worktree dropped", ok, msg2)

        # push_branch: api/<name> only
        wt2 = A.prepare_worktree(src, "HEAD", os.path.join(A.WORKTREE_ROOT, "tw2"), sparse=False)
        for b in ["main", "master", "api/../main", "api/", "api", "feature/x", "api/a b", "api/x.lock", "api/x..y", "refs/heads/main",
                  "api/x;rm", "origin/api/x", "api/" + "x" * 80, "", None, "API/x"]:
            ok, note = A.push_branch(wt2, b)
            check(f"push refused: {b!r}", ok is False and "refused" in note, note)
        check("push refused: origin untouched", g(origin, "rev-parse", "refs/heads/main").stdout.strip() == main_before
              and "api/" not in g(origin, "branch", "--list").stdout)
        A.drop_worktree(src, wt2)

        # a full run through run_job: the runner pushes, the shared tree keeps its branches
        script = [tool_step([("write_file", {"path": "src/feature.luau", "content": "return 'feature'\n"}),
                             ("edit_file", {"path": "src/a.luau", "old_string": "local a = 1", "new_string": "local a = 2"}),
                             ("git_commit", {"message": "기능 추가", "paths": ["src/feature.luau", "src/a.luau"]}),
                             ("write_file", {"path": "src/left.luau", "content": "not committed\n"}),
                             ("write_file", {"path": ".env", "content": "KEY=1"})]),
                  end_step("REPORT: feature added")]
        fc = FakeClient(script)
        a = run_args(base, "wjob", "do it", "--repo-dir", src, "--make-worktree", "HEAD", "--write", "--branch", "api/t1")
        m = A.run_job(a, client=fc, key=FAKE_KEY)
        outd = os.path.join(A.JOBS_ROOT, "wjob")
        u = json.load(open(os.path.join(outd, "usage.json"), encoding="utf-8"))
        code = u.get("code") or {}
        check("run: done", m["status"] == "done" and u["status"] == "done", m["status"])
        check("run: usage code (branch, commit, files, push)", code.get("branch") == "api/t1" and code.get("pushed") is True
              and len(code.get("commits", [])) == 1 and sorted(code.get("files_changed", [])) == ["src/a.luau", "src/feature.luau"]
              and code.get("base") == head_before and code["commits"][0]["subject"] == "기능 추가", code)
        check("run: uncommitted change reported", code.get("uncommitted") == ["src/left.luau"], code.get("uncommitted"))
        res_blocks = fc.messages.calls[1]["messages"][2]["content"]
        check("run: the .env write was refused", res_blocks[4].get("is_error") is True and "denied" in res_blocks[4]["content"], res_blocks[4])
        pushed = g(origin, "rev-parse", "refs/heads/api/t1").stdout.strip()
        check("run: origin has api/t1 at the commit", pushed == code["head"] and pushed != main_before, pushed)
        check("run: origin main untouched, no other new branch", g(origin, "rev-parse", "refs/heads/main").stdout.strip() == main_before
              and sorted(g(origin, "for-each-ref", "--format=%(refname)").stdout.split()) == ["refs/heads/api/t1", "refs/heads/main"])
        check("run: pushed tree has the change and no .env", g(origin, "show", "api/t1:src/a.luau").stdout.startswith("local a = 2")
              and g(origin, "cat-file", "-e", "api/t1:.env").returncode != 0 and g(origin, "cat-file", "-e", "api/t1:src/left.luau").returncode != 0)
        check("run: shared tree untouched (HEAD, branches, files)", g(src, "rev-parse", "HEAD").stdout.strip() == head_before
              and g(src, "branch", "--list").stdout == branches_before and not os.path.exists(os.path.join(src, "src", "feature.luau"))
              and open(os.path.join(src, "src", "a.luau")).read().startswith("local a = 1"))
        check("run: worktree removed", u.get("worktree_removed") is True and not os.path.exists(os.path.join(A.WORKTREE_ROOT, "wjob")), u)
        res = open(os.path.join(outd, "result.md"), encoding="utf-8").read()
        check("run: result.md summary", "REPORT: feature added" in res and "api/t1" in res and "기능 추가" in res and "src/left.luau" in res, res)
        p0 = fc.messages.calls[0]
        names = [t["name"] for t in p0["tools"]]
        check("run: write tools listed, write_note last with the cache breakpoint", {"write_file", "edit_file", "delete_file", "git_commit"} <= set(names)
              and names[-1] == "write_note" and p0["tools"][-1].get("cache_control") == {"type": "ephemeral"}, names)
        check("run: write-mode system prompt names the branch", "api/t1" in p0["system"][0]["text"] and "TEMPORARY git worktree" in p0["system"][0]["text"])
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            A.cmd_status(A.parser().parse_args(["status", "wjob"]))
        check("status shows the code line", "code: branch api/t1 commits 1 files 2 pushed True uncommitted 1" in buf.getvalue(), buf.getvalue())
        # a read-only job's tools carry no write tools
        fcr = FakeClient([end_step("x")])
        A.run_job(run_args(base, "rjob", "look", "--repo-dir", src), client=fcr, key=FAKE_KEY)
        check("read-only run: no write tools in the request", not ({"write_file", "edit_file", "delete_file", "git_commit"}
              & {t["name"] for t in fcr.messages.calls[0]["tools"]}))

        # no commits -> nothing is pushed
        fc2 = FakeClient([tool_step([("write_file", {"path": "src/x.luau", "content": "x\n"})]), end_step("no commit")])
        A.run_job(run_args(base, "wnone", "do", "--repo-dir", src, "--make-worktree", "HEAD", "--write", "--branch", "api/t2"),
                  client=fc2, key=FAKE_KEY)
        u2 = json.load(open(os.path.join(A.JOBS_ROOT, "wnone", "usage.json"), encoding="utf-8"))
        check("run without commits: nothing pushed", u2["code"]["pushed"] is False and "no commits" in u2["code"]["push_note"]
              and g(origin, "rev-parse", "--verify", "--quiet", "refs/heads/api/t2").returncode != 0, u2["code"])
        # a stopped job (turn cap) with a commit still pushes it
        fc3 = FakeClient([tool_step([("write_file", {"path": "src/y.luau", "content": "y\n"}),
                                     ("git_commit", {"message": "y", "paths": ["src/y.luau"]})])])
        m3 = A.run_job(run_args(base, "wstop", "do", "--repo-dir", src, "--make-worktree", "HEAD", "--write", "--branch", "api/t3",
                                "--max-turns", "2"), client=fc3, key=FAKE_KEY)
        u3 = json.load(open(os.path.join(A.JOBS_ROOT, "wstop", "usage.json"), encoding="utf-8"))
        check("run stopped by the turn cap: commit still pushed", m3["status"] == "stopped_turns" and u3["code"]["pushed"] is True
              and g(origin, "rev-parse", "--verify", "--quiet", "refs/heads/api/t3").returncode == 0, u3["code"])
        check("run stopped: wrap-up asks to commit", "git_commit" in json.dumps(fc3.messages.calls[1]["messages"][-1]))

        # bad option combinations stop before anything exists
        for extra, label in [(["--write", "--branch", "api/x"], "--write without --make-worktree"),
                             (["--make-worktree", "HEAD", "--write"], "--write without --branch"),
                             (["--make-worktree", "HEAD", "--branch", "api/x"], "--branch without --write"),
                             (["--make-worktree", "HEAD", "--write", "--branch", "main"], "branch main"),
                             (["--make-worktree", "HEAD", "--write", "--branch", "feature/x"], "branch outside api/"),
                             (["--make-worktree", "HEAD", "--write", "--branch", "api/../x"], "branch with .."),
                             (["--make-worktree", "HEAD", "--write", "--branch", "api/x y"], "branch with a space")]:
            try:
                A.run_job(run_args(base, "bad", "x", "--repo-dir", src, *extra), client=FakeClient([end_step("x")]), key=FAKE_KEY)
                check(label, False, "no SystemExit")
            except SystemExit:
                check(label + " refused", not os.path.exists(os.path.join(A.WORKTREE_ROOT, "bad")))
            shutil.rmtree(os.path.join(A.JOBS_ROOT, "bad"), ignore_errors=True)
        check("origin never got another branch", sorted(g(origin, "for-each-ref", "--format=%(refname)").stdout.split())
              == ["refs/heads/api/t1", "refs/heads/api/t3", "refs/heads/main"])
    finally:
        A.WORKTREE_ROOT = old_wt


def sparse_checks(base):
    """--make-worktree is sparse by default (검수 2026-10-11: the full checkout is ~6 GB / 10 minutes): /src /tools /docs /AGENTS.md
    /.gitignore, --sparse-extra adds paths, --full-checkout restores everything; bad extras are refused before anything exists"""
    from PIL import Image
    g = lambda repo, *a: subprocess.run(["git", "-C", repo, *a], capture_output=True, text=True, encoding="utf-8")  # noqa: E731
    src = os.path.join(base, "spsrc")
    subprocess.run(["git", "init", "-q", src], check=True)
    for k, v in (("user.name", "Test"), ("user.email", "t@example.com"), ("core.autocrlf", "false"), ("commit.gpgsign", "false")):
        g(src, "config", k, v)
    for rel in ["AGENTS.md", ".gitignore", "src/a.luau", "tools/t.py", "docs/d.md", "art/big.bin", "art/review/pic/p.txt",
                "art/review/other/q.txt", "place/x.rbxlx", "root.txt"]:
        full = os.path.join(src, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as f:
            f.write("build/\n" if rel == ".gitignore" else rel + "\n")
    Image.new("RGB", (40, 30), (200, 40, 40)).save(os.path.join(src, "art", "review", "pic", "p.png"))
    g(src, "add", "-A")
    g(src, "commit", "-q", "-m", "init")
    ex = lambda wt, rel: os.path.exists(os.path.join(wt, *rel.split("/")))  # noqa: E731
    old_wt = A.WORKTREE_ROOT
    A.WORKTREE_ROOT = os.path.join(base, "wtsp")
    try:
        check("sparse patterns: defaults", A.sparse_patterns() == ["/src/", "/tools/", "/docs/", "/AGENTS.md", "/.gitignore"], A.sparse_patterns())
        check("sparse patterns: extras anchored", A.sparse_patterns(["art/review/pic/", "root.txt"])[-2:] == ["/art/review/pic/", "/root.txt"])
        wt = A.prepare_worktree(src, "HEAD", os.path.join(A.WORKTREE_ROOT, "s1"))
        check("sparse: the default folders are there", all(ex(wt, x) for x in ["AGENTS.md", ".gitignore", "src/a.luau", "tools/t.py", "docs/d.md"]))
        check("sparse: art/, place/ and root files are not", not any(ex(wt, x) for x in ["art", "place", "root.txt", "art/big.bin"]))
        check("sparse: git status is clean (no phantom deletions)", g(wt, "status", "--porcelain").stdout.strip() == "", g(wt, "status", "--porcelain").stdout)
        check("sparse: the shared repo keeps every file and is not sparse", all(ex(src, x) for x in ["art/big.bin", "place/x.rbxlx", "root.txt"])
              and g(src, "config", "--get", "core.sparseCheckout").stdout.strip() == "", g(src, "config", "--get", "core.sparseCheckout").stdout)
        ok, msg = A.drop_worktree(src, wt)
        check("sparse: worktree dropped", ok and not os.path.exists(wt), msg)

        wt = A.prepare_worktree(src, "HEAD", os.path.join(A.WORKTREE_ROOT, "s2"), extra=["art/review/pic/", "root.txt"])
        check("sparse-extra: a folder and a file are added", ex(wt, "art/review/pic/p.png") and ex(wt, "art/review/pic/p.txt") and ex(wt, "root.txt"))
        check("sparse-extra: siblings stay out", not ex(wt, "art/review/other/q.txt") and not ex(wt, "art/big.bin"))
        T = A.Tools(wt, os.path.join(base, "jobs"), True, A.Redactor([FAKE_KEY]))
        t, e = T.call("read_image", {"path": "art/review/pic/p.png"})
        check("sparse-extra: read_image reaches the extra picture", not e and isinstance(t, list) and t[1]["type"] == "image", t)
        t, e = T.call("read_file", {"path": "art/big.bin"})
        check("sparse: a file outside the sparse set is simply not there", e and "not found" in t, t)
        A.drop_worktree(src, wt)

        wt = A.prepare_worktree(src, "HEAD", os.path.join(A.WORKTREE_ROOT, "s3"), sparse=False)
        check("full checkout: everything is there", all(ex(wt, x) for x in ["art/big.bin", "place/x.rbxlx", "root.txt", "art/review/other/q.txt"]))
        A.drop_worktree(src, wt)

        for bad in ["../x", "/abs", "C:/x", ".env", ".env.local", "a/.git/b", ".git", ".tripo/x", "a*b", "!x", "a\\b", "", "art/../src", "./art",
                    "a//b", "a?b", "a[b]", "#c", "x\x00y", None, 5, "id_rsa", "keys/a.pem"]:
            try:
                A.sparse_patterns([bad])
                check(f"sparse-extra refused: {bad!r}", False, "no SystemExit")
            except SystemExit:
                check(f"sparse-extra refused: {bad!r}", True)

        # through run_job: patterns reach usage.json and the system prompt; wrong option combinations stop first
        fc = FakeClient([end_step("done")])
        A.run_job(run_args(base, "spjob", "look", "--repo-dir", src, "--make-worktree", "HEAD", "--sparse-extra", "art/review/pic/"),
                  client=fc, key=FAKE_KEY)
        u = json.load(open(os.path.join(A.JOBS_ROOT, "spjob", "usage.json"), encoding="utf-8"))
        check("run: usage.json lists the sparse patterns", u.get("sparse") == ["/src/", "/tools/", "/docs/", "/AGENTS.md", "/.gitignore", "/art/review/pic/"], u.get("sparse"))
        sysm = fc.messages.calls[0]["system"][0]["text"]
        check("run: the model is told the worktree is sparse", "SPARSE" in sysm and "/art/review/pic/" in sysm and "test_rank_marks" in sysm)
        check("run: the sparse worktree is gone afterwards", u.get("worktree_removed") is True)
        fc = FakeClient([end_step("done")])
        A.run_job(run_args(base, "fulljob", "look", "--repo-dir", src, "--make-worktree", "HEAD", "--full-checkout"), client=fc, key=FAKE_KEY)
        u = json.load(open(os.path.join(A.JOBS_ROOT, "fulljob", "usage.json"), encoding="utf-8"))
        check("run --full-checkout: no sparse note", u.get("sparse") is None and "SPARSE" not in fc.messages.calls[0]["system"][0]["text"], u.get("sparse"))
        for extra, label in [(["--sparse-extra", "art/"], "--sparse-extra without --make-worktree"),
                             (["--full-checkout"], "--full-checkout without --make-worktree"),
                             (["--make-worktree", "HEAD", "--full-checkout", "--sparse-extra", "art/"], "--sparse-extra with --full-checkout"),
                             (["--make-worktree", "HEAD", "--sparse-extra", "../x"], "a bad --sparse-extra")]:
            try:
                A.run_job(run_args(base, "badsp", "x", "--repo-dir", src, *extra), client=FakeClient([end_step("x")]), key=FAKE_KEY)
                check(label, False, "no SystemExit")
            except SystemExit:
                check(label + " refused", not os.path.exists(os.path.join(A.WORKTREE_ROOT, "badsp")))
            shutil.rmtree(os.path.join(A.JOBS_ROOT, "badsp"), ignore_errors=True)
        check("no worktree left behind", [x for x in g(src, "worktree", "list").stdout.splitlines() if "wtsp" in x] == [],
              g(src, "worktree", "list").stdout)
    finally:
        A.WORKTREE_ROOT = old_wt


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

    # read_image in a run: the image goes to the model, the transcript keeps no base64, usage.json counts it, --max-images
    fc = FakeClient([tool_step([("read_image", {"path": "img/small.png"}), ("read_image", {"path": "img/big.jpg"})]),
                     end_step("SAW IT")])
    m = A.run_job(run_args(base, "img", "look", "--repo-dir", repo, "--max-images", "1"), client=fc, key=FAKE_KEY)
    sent = fc.messages.calls[1]["messages"][2]["content"]
    first, second = sent[0], sent[1]
    check("run img: image block reaches the model", isinstance(first["content"], list)
          and first["content"][1]["type"] == "image" and len(first["content"][1]["source"]["data"]) > 100, first)
    check("run img: --max-images 1 refuses the 2nd", second.get("is_error") is True and "cap" in second["content"], second)
    trans = open(os.path.join(A.JOBS_ROOT, "img", "transcript.jsonl"), encoding="utf-8").read()
    check("run img: transcript has no base64", "base64 chars omitted" in trans
          and first["content"][1]["source"]["data"][:40] not in trans, len(trans))
    u = json.load(open(os.path.join(A.JOBS_ROOT, "img", "usage.json"), encoding="utf-8"))
    check("run img: usage.json images + cap", u["images"] == ["img/small.png"] and u["max_images"] == 1 and m["status"] == "done", u)
    check("run img: system prompt names the cap", "at most 1 images" in fc.messages.calls[0]["system"][0]["text"])
    check("read_image tool listed", any(t["name"] == "read_image" for t in fc.messages.calls[0]["tools"]))

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
        image_checks(base, repo)
        loop_checks(base, repo)
        write_checks(base)
        sparse_checks(base)
    finally:
        A.JOBS_ROOT = old_root
        shutil.rmtree(base, ignore_errors=True)
    print(f"\n{len(PASS)} passed, {len(FAIL)} failed")
    sys.exit(1 if FAIL else 0)


if __name__ == "__main__":
    main()
