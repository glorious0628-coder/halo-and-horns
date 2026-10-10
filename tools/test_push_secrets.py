"""push_paths secrets scan (검수 2026-10-10: the core of a pre-push AI check, our way), offline.

Runs the CURRENT tools/push_paths.py scan_paths / secret_name on temporary files with FAKE keys built at run time (no
real key is ever written here): refused names (.env, .env.local, .tripo/..., *.pem, id_rsa*; .env.example passes),
key shapes found with the right line numbers (TRIPO_API_KEY=value, sk-ant-, a PRIVATE KEY block, a long tsk_ token),
the bare 'TRIPO_API_KEY=' line in AGENTS.md style passes, ordinary files and binaries pass, and the scan's result and
the tool's printed lines never hold the secret value. Static: main() scans before hashing / pushing and exits on a
find. No git or network calls.

Usage: py tools/test_push_secrets.py
Report: docs/art/verification_2026-10-10/offline_push_secrets_2026-10-10.json
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/push_paths.py"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_push_secrets_2026-10-10.json"


def load():
    spec = importlib.util.spec_from_file_location("push_paths_under_test", TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    mod = load()
    checks = []

    def check(name, ok):
        checks.append({"check": name, "ok": bool(ok)})
        print(("CHECK_OK  " if ok else "CHECK_FAIL ") + name)

    fake = {
        "tripo": "TRIPO_API_KEY" + "=" + "tsk" + "_" + "Ab12" * 8,
        "ant": "token: " + "sk-" + "ant-" + "api03-" + "Zz9" * 8,
        "pem": "-----BEGIN " + "RSA " + "PRIVATE KEY-----",
        "tsk": "key = " + "tsk" + "_" + "Qx7Q" * 7,
    }
    values = ["Ab12" * 8, "Zz9" * 8, "Qx7Q" * 7]
    with tempfile.TemporaryDirectory() as d:
        dd = Path(d)
        (dd / "notes.txt").write_text("line one\n" + fake["tripo"] + "\nline three\n", encoding="utf-8")
        (dd / "cfg.lua").write_text("a\nb\n" + fake["ant"] + "\n", encoding="utf-8")
        (dd / "key.txt").write_text(fake["pem"] + "\nMIIB...\n", encoding="utf-8")
        (dd / "tok.py").write_text("x = 1\n" + fake["tsk"] + "\n", encoding="utf-8")
        (dd / "agents.md").write_text("The key lives in .env (TRIPO_API_KEY=). Never print it.\n", encoding="utf-8")
        (dd / "ok.luau").write_text("local x = 1\nreturn x\n", encoding="utf-8")
        (dd / "vendor.md").write_text("export " + "TRIPO_API_KEY" + "=" + "your_api_key\napi_key = " + "tsk" + "_"
                                      + "your_key_here_1234567890\n", encoding="utf-8")
        (dd / "img.png").write_bytes(b"\x89PNG\x00\x00" + fake["tripo"].encode())
        p = lambda n: str(dd / n).replace("\\", "/")
        found = mod.scan_paths([p("notes.txt"), p("cfg.lua"), p("key.txt"), p("tok.py"), p("agents.md"), p("ok.luau"), p("img.png"), p("vendor.md")])
        where = {(Path(f[0]).name, f[1]) for f in found}
        check("TRIPO_API_KEY=value found on its line (2)", ("notes.txt", 2) in where)
        check("an sk-ant- key found on its line (3)", ("cfg.lua", 3) in where)
        check("a PRIVATE KEY block found on its line (1)", ("key.txt", 1) in where)
        check("a long tsk_ token found on its line (2)", ("tok.py", 2) in where)
        check("the bare 'TRIPO_API_KEY=' (AGENTS.md style) passes", not any(n == "agents.md" for n, _ in where))
        check("an ordinary file passes", not any(n == "ok.luau" for n, _ in where))
        check("placeholder values in docs (your_api_key, your_key_here) pass", not any(n == "vendor.md" for n, _ in where))
        check("a binary file is not read", not any(n == "img.png" for n, _ in where))
        check("the result never holds a value", not any(v in str(found) for v in values))
    names = {
        ".env": True, "sub/.env.local": True, ".env.example": False, ".tripo/session.json": True, "keys/server.pem": True,
        "home/id_rsa": True, "home/id_rsa.pub": True, "src/Env.luau": False, "docs/tripo_notes.md": False,
    }
    for n, bad in names.items():
        check(f"name {n}: {'refused' if bad else 'passes'}", (mod.secret_name(n) is not None) == bad)
    src = TOOL.read_text(encoding="utf-8")
    main_src = src[src.find("def main():"):]
    check("main() scans before hashing / pushing", 0 < main_src.find("found = scan_paths(paths)") < main_src.find("blobs = {}"))
    check("a find stops the push (sys.exit) and prints file:line only",
          "sys.exit(\"push 중단" in main_src and "{p}{'' if n is None else ':' + str(n)} ({reason})" in main_src)
    check("the tool file itself passes its own scan", not mod.scan_paths([str(TOOL)]))
    check("this test file passes the scan (fakes are built at run time)", not mod.scan_paths([str(Path(__file__))]))
    failed = sum(0 if c["ok"] else 1 for c in checks)
    status = "passed" if failed == 0 else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": len(checks), "failed": failed, "results": checks, "status": status,
                               "contract": __doc__.split("Usage")[0].strip()}, indent=2, ensure_ascii=False) + "\n",
                   encoding="utf-8")
    print(f"Status: {status} (checks {len(checks)}, failed {failed})")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
