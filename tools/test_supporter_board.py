"""SupporterBoard offline check (SPEC A23-75: the VIP supporters board from GameState SupporterNames).

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/SupporterBoard.luau in tools/fixtures/supporter_board_offline.luau
with the installed official Luau CLI (build/luau_cli_0_741): CollectionService, GameState and Instance.new are small
doubles. Static: ClientMain loads SupporterBoard; no purchase prompt in it (no pressure, A23-75).
Mutations: in-memory copies with one rule broken each; each must make a check fail. Status "passed" only when the
fixture passes, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-08/offline_supporter_board_2026-10-08.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
BOARD = SCRIPTS / "SupporterBoard.luau"
CLIENT_MAIN = SCRIPTS / "ClientMain.client.luau"
FIXTURE = ROOT / "tools/fixtures/supporter_board_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-08/offline_supporter_board_2026-10-08.json"

MUTATIONS = [
    ("no cap of 30", "\t\t\tif #out >= T.Max then break end\n", ""),
    ("empty lines kept", "\t\tif name ~= \"\" then\n", "\t\tif true then\n"),
    ("the board never redraws", "\t\tgs:GetAttributeChangedSignal(T.Attr):Connect(redrawAll)\n", ""),
    ("a late board stays blank", "\t\tCollectionService:GetInstanceAddedSignal(T.Tag):Connect(function(part) pcall(draw, part) end)\n", ""),
    ("a new SurfaceGui every redraw", "\tlocal gui = part:FindFirstChild(T.Gui)\n", "\tlocal gui = nil\n"),
    ("no names shown", "\tlocal rows = SupporterBoard.Rows(SupporterBoard.Names(S.GameState and S.GameState:GetAttribute(T.Attr)))\n",
     "\tlocal rows = { T.Empty }\n"),
    ("old rows pile up", "\t\tif string.sub(ch.Name, 1, 3) == \"Row\" then ch:Destroy() end\n", ""),
    ("all rows in one label", "\t\trow.Text = text\n", "\t\trow.Text = table.concat(rows, \"\\n\")\n"),
    ("long names not cut", "\t\t\tif utf8.len(name) and utf8.len(name) > T.NameMax then\n", "\t\t\tif false then\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: str, name: str):
    path = ROOT / f"build/supporter_board_offline{name}.luau"
    path.write_text("local BOARD_SOURCE = " + lua_str(src) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"SUPPORTER_BOARD_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    src = BOARD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(src, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = src.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(src.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    cm = CLIENT_MAIN.read_text(encoding="utf-8-sig")
    order = re.search(r"local ORDER = \{([^}]*)\}", cm)
    names = re.findall(r'"([A-Za-z]+)"', order[1]) if order else []
    code = "\n".join(line.split("--", 1)[0] for line in src.splitlines())
    static = [
        ("ClientMain loads SupporterBoard", "SupporterBoard" in names),
        ("no purchase prompt on the board (no pressure)", "PromptGamePassPurchase" not in code and "PromptProductPurchase" not in code),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in (BOARD, CLIENT_MAIN)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "limitations": "Doubles instead of the engine: how the names fit on the real 3D board is a Studio photo check "
                             "after the board is placed (Edit tool) and the server fills SupporterNames."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
