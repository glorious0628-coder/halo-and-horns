"""QuestMarker top-edge check (검수 2026-10-09, UI clutter review ①: on the phone the quest marker's "23m" was cut off
above the screen's top edge over the crown war bar - photos main_checklist_0900/phone/09a_story_pop, 10_crossroads).

Runs the CURRENT QuestMarker.ClearOfHud (cut out of src/StarterPlayer/StarterPlayerScripts/QuestMarker.luau) with the
installed official Luau CLI (build/luau_cli_0_741): an on-screen target behind a HUD block rises just above it, but a
block with no room above it under the Roblox top bar sends the marker just below it (never above topY, never below
bottomY). Static: moveStep passes T.TopBar + T.HalfY and H - T.HalfY. Mutations: in-memory copies with one rule broken
each; each must make a check fail. Status "passed" only when the checks pass and every mutation is caught.

Usage: py tools/test_marker_top.py
Report: docs/art/verification_2026-10-09/offline_marker_top_2026-10-09.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MARKER = ROOT / "src/StarterPlayer/StarterPlayerScripts/QuestMarker.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_marker_top_2026-10-09.json"

CALL = "\t\tly = QuestMarker.ClearOfHud(lx, ly, S.hud, T.TopBar + T.HalfY, H - T.HalfY)\n"
MUTATIONS = [
    ("always rise above the block (the old rule)", "\t\tif not down and hit[2] >= topY then\n", "\t\tif true then\n"),
    ("always drop below the block", "\t\tif not down and hit[2] >= topY then\n", "\t\tif false then\n"),
    ("below without the bottom limit", "\t\t\tly = math.min(hit[4], bottomY)\n", "\t\t\tly = hit[4]\n"),
    ("one pass only", "\tfor _ = 1, #hud + 1 do\n", "\tfor _ = 1, 1 do\n"),
    ("going down may turn back up", "\t\tif not down and hit[2] >= topY then\n", "\t\tif hit[2] >= topY then\n"),
    ("moveStep ignores the top bar", CALL, "\t\tly = QuestMarker.ClearOfHud(lx, ly, S.hud, -math.huge, H - T.HalfY)\n"),
]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local QuestMarker = {}
local f = assert(loadstring(CLEAR_SOURCE, "=ClearOfHud"))
setfenv(f, setmetatable({ QuestMarker = QuestMarker }, { __index = getfenv() }))
f()
local clear = QuestMarker.ClearOfHud
-- the reference phone 655 x 340 du; top bar 60 + half the marker 40 = topY 100; bottomY = 340 - 40
local TOPY, BOTY = 100, 300
local war = { 220, -20, 440, 130 } -- the top-centre column (war meter + chips) inflated: no room above it
local stats = { 200, 190, 460, 340 } -- the bottom-centre block: room above it
local mini = { 10, 30, 180, 200 } -- top-left minimap + quest lines
check("behind the war bar: just below it, not above the screen", clear(330, 40, { war }, TOPY, BOTY) == 130, clear(330, 40, { war }, TOPY, BOTY))
check("behind the bottom stats: rises just above them (as before)", clear(330, 250, { stats }, TOPY, BOTY) == 190)
check("behind the minimap: below it", clear(90, 100, { mini }, TOPY, BOTY) == 200)
check("not behind any block: unchanged", clear(600, 150, { war, stats, mini }, TOPY, BOTY) == 150)
check("a block right under the war bar: down past both (never back up into the war bar)",
	clear(330, 40, { { 220, 120, 440, 210 }, war }, TOPY, BOTY) == 210, clear(330, 40, { { 220, 120, 440, 210 }, war }, TOPY, BOTY))
check("rising above the stats into free space: one step up", clear(330, 250, { stats, war }, TOPY, BOTY) == 190)
local tall = { 220, -20, 440, 330 }
check("a block down to the bottom: kept at bottomY", clear(330, 40, { tall }, TOPY, BOTY) == BOTY)
check("never above topY when it moves", clear(330, 40, { war }, TOPY, BOTY) >= TOPY)
check("no blocks (nil): unchanged", clear(330, 40, nil, TOPY, BOTY) == 40)
print(("MARKER_TOP_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''


def cut(src: str) -> str:
    m = re.search(r"\nfunction QuestMarker\.ClearOfHud\(lx, ly, hud, topY, bottomY\)\n.*?\nend\n", src, re.S)
    if not m:
        raise ValueError("QuestMarker.ClearOfHud is missing; update the extractor")
    return m.group(0)


def run(src: str) -> tuple[int, int, str]:
    text = f"local CLEAR_SOURCE = [==========[{cut(src)}]==========]\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "marker_top.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"MARKER_TOP_SUMMARY checks=(\d+) failed=(\d+)", out)
    # A23-221 ⑥: the distance's navy rim bolder over a white floor (once per new value, never growing)
    static_ok = CALL in src and "pcall(boldRim, ui.text)" in src and "if s.Thickness == last then return end" in src
    if not m:
        return 0, 1, out
    return int(m[1]), int(m[2]) + (0 if static_ok else 1), out + ("" if static_ok else "\nSTATIC_FAIL moveStep call")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = MARKER.read_text(encoding="utf-8")
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for name, old, new in MUTATIONS:
        hits = src.count(old)
        if hits != 1:
            muts.append({"name": name, "applied": False, "caught": False, "note": f"pattern matched {hits} times"})
            print(f"MUTATION MISSED {name} (pattern matched {hits} times; update MUTATIONS)")
            continue
        try:
            _, f2, _ = run(src.replace(old, new))
        except ValueError:
            f2 = 1
        muts.append({"name": name, "applied": True, "caught": f2 > 0})
        print(("MUTATION caught  " if f2 > 0 else "MUTATION MISSED ") + name)
    caught = sum(1 for m in muts if m["caught"])
    status = "passed" if failed == 0 and checks > 0 and caught == len(MUTATIONS) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
