"""③ 망치질 판정 공용 모듈 (게임성 개발 4, 2026-10-12; SPEC A23-56 / A23-127 / A23-133, design
docs/design/hammer_minigame_2026-10-12.md, 게임성 검수 10/12 계약 고침), offline.

Runs the CURRENT src/ReplicatedStorage/Shared/CraftMini.luau in the official Luau CLI (tools/fixtures/craft_mini_offline.luau).
Checks: the agreed numbers (5 strikes, 1.2 s rings, 0.35 s rest, 40 ms forgiven, windows 70 / 130 / 200 ms, 20 s timeout);
the fixed schedule (T_i, appear, close, the live ring and its shrink, nothing in the rest / before / after); every grade
boundary both sides (+40 forgiven) and Miss for no press / not a number / out of range; the score lines 13 (+2) and 9 (+1)
and +0 never failing; the server check (at most 50 ms earlier, 250 ms later + 1.5 x ping); a whole session (a real
player's Perfects, missing / late strikes, made-up Perfect numbers sent at the wrong times, a claimed offset its arrival
disproves, strikes too close, no strikes = Skip = +0). Mutations: each must be caught (above all: 'an offset that its
arrival disproves still counts', 게임성 검수 10/12).

Usage: py tools/test_craft_mini.py
Report: docs/art/verification_2026-10-12/offline_craft_mini_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"MINI": ROOT / "src/ReplicatedStorage/Shared/CraftMini.luau"}
FIXTURE = ROOT / "tools/fixtures/craft_mini_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_craft_mini_2026-10-12.json"

MUTATIONS = [
    ("MINI", "an offset that its arrival disproves still counts (게임성 검수 10/12)",
     "\treturn d >= -T.Early and d <= T.Late + T.JitterMul * ping\n", "\treturn true\n"),
    ("MINI", "Accept skips the server check", "if s.At >= prevAt + T.Rest and CraftMini.Check(s.Ms, serverMs, ping) then",
     "if s.At >= prevAt + T.Rest then"),
    ("MINI", "only the ping now counts (게임성 검수 10/12)", "\treturn math.max(a, b)\n", "\treturn a\n"),
    ("MINI", "a strike's own ping ignored", "math.max(CraftMini.Ping(pingMs, startPingMs), CraftMini.Ping(s.Ping))",
     "CraftMini.Ping(pingMs, startPingMs)"),
    ("MINI", "no early limit", "\treturn d >= -T.Early and d <= T.Late", "\treturn d <= T.Late"),
    ("MINI", "ping not counted", "d <= T.Late + T.JitterMul * ping", "d <= T.Late"),
    ("MINI", "no input delay forgiven", "\tlocal e = math.abs(ms - T.Lag)\n", "\tlocal e = math.abs(ms)\n"),
    ("MINI", "Perfect window wider", "{ \"Perfect\", 70 }", "{ \"Perfect\", 90 }"),
    ("MINI", "Good window narrower", "{ \"Good\", 200 }", "{ \"Good\", 180 }"),
    ("MINI", "a strict boundary", "\t\tif e <= w[2] then return w[1] end\n", "\t\tif e < w[2] then return w[1] end\n"),
    ("MINI", "+2 line moved", "PlusAt = { { 2, 13 }, { 1, 9 } }", "PlusAt = { { 2, 12 }, { 1, 9 } }"),
    ("MINI", "+1 line moved", "PlusAt = { { 2, 13 }, { 1, 9 } }", "PlusAt = { { 2, 13 }, { 1, 10 } }"),
    ("MINI", "the schedule ignores the rest", "\treturn startAt + i * T.Ring + (i - 1) * T.Rest\n", "\treturn startAt + i * T.Ring\n"),
    ("MINI", "rings close at their target", "+ (T.Windows[#T.Windows][2] + T.Lag) / 1000", "+ 0"),
    ("MINI", "the rest has a live ring", "\t\tif t >= CraftMini.Appear(startAt, i) and t < CraftMini.Closes(startAt, i) then",
     "\t\tif t >= CraftMini.Appear(startAt, i) and t < CraftMini.Appear(startAt, i) + T.Ring + T.Rest then"),
    ("MINI", "unknown grades score", "\t\tpoints += T.Points[g] or 0\n", "\t\tpoints += T.Points[g] or 1\n"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(src: dict) -> tuple[int, int, str]:
    text = "local MINI_SOURCE = " + lua_str(src["MINI"]) + "\n" + FIXTURE.read_text(encoding="utf-8")
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "craft_mini.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=60)
    out = proc.stdout + proc.stderr
    m = re.search(r"CRAFT_MINI_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    return (int(m[1]) if m else 0), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
