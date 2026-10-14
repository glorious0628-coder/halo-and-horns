"""Top-centre HUD overlap (최종 검수 10/14, user photo while playing: 'Crown War · 9:38', the quest marker and
'Golden Goose 3:43' piled up at the top centre), offline.

Rules now:
1. HUD.TopBottom() = the DRAWN bottom (du) of the war meter with its plate / info line (they reach below
   Rects.war_meter) and of the status chips row while it shows (L.DrawnBottom over AbsolutePosition / AbsoluteSize).
2. EventHUD's next-event chip (goose / Pumpkin King) starts at V2.EventTop(eventY, HUD.TopBottom(), 6): never above the
   drawn HUD bottom + 6 - one column top to bottom (PC and phone). EventHUD.TopBottom() = that chip's bottom.
3. QuestMarker keeps its icon centre at least QuestMarker.TopLimit({HUD, EventHUD bottoms}, TopBar, HalfY, 8): the
   on-screen marker is clamped under that band and the edge indicator's track box starts there.
Extracted and run (official Luau CLI): L.DrawnBottom, V2.EventTop, QuestMarker.TopLimit, with PC and phone numbers from
HudLayout (war_meter 13..55 / 15..53, chips 62 / 62, event 88 / 81) and a war line drawn past its rect; checks that the
war band, the event chip and the marker icon never overlap. Static: the call sites. Mutations: each must fail a check.
Report: docs/art/verification_2026-10-14/offline_hud_top_overlap_2026-10-14.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"HUD": SPS / "HUD.luau", "EV": SPS / "EventHUD.luau", "QM": SPS / "QuestMarker.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_hud_top_overlap_2026-10-14.json"
CUTS = {"HUD": [("function L.DrawnBottom(list, rootY, s)", "\nend\n")],
        "EV": [("V2.TopGap = 6\n", ""), ("function V2.EventTop(evY, hudBottom, gap)", "\nend\n")],
        "QM": [("T.TopGap = 8\n", ""), ("function QuestMarker.TopLimit(bottoms, topBar, halfY, gap)", "\nend\n")]}

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function num(v, d) v = tonumber(v) if v == nil or v ~= v then return d or 0 end return v end
L, V2, QuestMarker, T = {}, {}, {}, { TopBar = 60, HalfY = 24 }
local f = assert(loadstring(PART, "=Part"))
setfenv(f, setmetatable({ L = L, V2 = V2, QuestMarker = QuestMarker, T = T, num = num }, { __index = getfenv() }))
f()
local function g(y, h) return { AbsolutePosition = { Y = y }, AbsoluteSize = { Y = h } } end
-- 1) drawn bottom
check(L.DrawnBottom({ g(20, 40), g(30, 70) }, 10, 1) == 90, "the lowest drawn bottom (px -> du)", L.DrawnBottom({ g(20, 40), g(30, 70) }, 10, 1))
check(L.DrawnBottom({ g(20, 40) }, 0, 0.5) == 120, "UIScale 0.5: px / 0.5", L.DrawnBottom({ g(20, 40) }, 0, 0.5))
check(L.DrawnBottom({ g(500, 0) }, 0, 1) == nil and L.DrawnBottom({}, 0, 1) == nil, "nothing drawn: nil", "")
-- 2) the event chip under the drawn HUD
check(V2.EventTop(62, 70, 6) == 76 and V2.EventTop(88, 70, 6) == 88 and V2.EventTop(62, nil, 6) == 62,
	"event chip: max(its row, HUD bottom + 6); no HUD = its row", V2.EventTop(62, 70, 6))
check(V2.EventTop(62, 70) == 62 + 14, "default gap = 6", V2.EventTop(62, 70))
-- 3) the marker's top band
check(QuestMarker.TopLimit({ 70, 98 }, 60, 24, 8) == 130 and QuestMarker.TopLimit({}, 60, 24, 8) == 84
	and QuestMarker.TopLimit(nil, 60, 24, 8) == 84, "marker: under the lowest bottom + gap + half icon; else the top bar rule",
	QuestMarker.TopLimit({ 70, 98 }, 60, 24, 8))
-- 4) the three never overlap: PC (war rect 13..55, drawn to 70; chips empty -> the chip rises to 62) and phone
local function overlap(a0, a1, b0, b1) return a0 < b1 and b0 < a1 end
for _, case in { { "PC", 13, 70, 62, 22 }, { "phone", 15, 66, 62, 18 }, { "PC chips shown", 13, 84, 88, 22 } } do
	local name, warTop, hudBottom, evRow, evH = case[1], case[2], case[3], case[4], case[5]
	local evY = V2.EventTop(evRow, hudBottom, V2.TopGap)
	local evBottom = evY + evH
	local markY = QuestMarker.TopLimit({ hudBottom, evBottom }, T.TopBar, T.HalfY, T.TopGap)
	local m0, m1 = markY - T.HalfY, markY + T.HalfY
	check(not overlap(warTop, hudBottom, evY, evBottom) and not overlap(warTop, hudBottom, m0, m1) and not overlap(evY, evBottom, m0, m1),
		name .. ": war band, event chip and marker icon do not overlap",
		("war %d-%d event %d-%d marker %d-%d"):format(warTop, hudBottom, evY, evBottom, m0, m1))
end
print(("TOP_OVERLAP_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("EV", "the event chip ignores the HUD", "return math.max(evY, hudBottom + (tonumber(gap) or V2.TopGap))", "return evY"),
    ("EV", "the event chip touches the HUD", "V2.TopGap = 6\n", "V2.TopGap = 0\n"),
    ("QM", "the marker ignores the bands",
     "if type(b) == \"number\" and b == b then lim = math.max(lim, b + (tonumber(gap) or T.TopGap) + (tonumber(halfY) or 0)) end", ""),
    ("QM", "the marker's centre on the band edge", "b + (tonumber(gap) or T.TopGap) + (tonumber(halfY) or 0)", "b"),
    ("HUD", "the drawn bottom without its height", "local y = (g.AbsolutePosition.Y + h - rootY) / s", "local y = (g.AbsolutePosition.Y - rootY) / s"),
    ("QM", "the on-screen marker not clamped", "\t\tly = math.min(math.max(ly, topLimit()), H - T.HalfY) -- never in the top band (war line / chips / event chip)\n", ""),
    ("QM", "the edge track ignores the band", "local box = { mx, math.max(my, topLimit()), W - mx, H - my }",
     "local box = { mx, math.max(my, T.TopBar + T.HalfY), W - mx, H - my }"),
    ("EV", "the chip placed at its row", "local evY = V2.EventTop(V2.eventY(rects, V2.chipsShown()) or ev.Y, V2.hudBottom(), V2.TopGap)",
     "local evY = V2.eventY(rects, V2.chipsShown()) or ev.Y"),
    ("HUD", "the war info line not measured", "for _, g in { ui.warPlate, ui.warInfo } do", "for _, g in {} do"),
    ("HUD", "the chips row not measured", "\tif HUD.ChipsShown() then table.insert(list, ui.chips) end\n", ""),
    ("EV", "the chip's bottom not published", "\t\t\tV2.EventBottom = evY + num(ev.H)\n", ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str, end: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    if end == "":
        return start
    b = text.find(end, a)
    return text[a:b + len(end)] if b >= 0 else ""


def statics(src: dict) -> list[tuple[str, bool]]:
    h, e, q = src["HUD"], src["EV"], src["QM"]
    return [
        ("HUD.TopBottom measures the war meter + plate + info line and the chips row",
         "function HUD.TopBottom()" in h and "for _, g in { ui.warPlate, ui.warInfo } do" in h
         and "if HUD.ChipsShown() then table.insert(list, ui.chips) end" in h),
        ("EventHUD places the event chip with V2.EventTop under HUD.TopBottom",
         "local evY = V2.EventTop(V2.eventY(rects, V2.chipsShown()) or ev.Y, V2.hudBottom(), V2.TopGap)" in e
         and "V2.EventBottom = evY + num(ev.H)" in e and "function EventHUD.TopBottom()" in e),
        ("QuestMarker clamps the on-screen marker and the edge track under the band",
         "ly = math.min(math.max(ly, topLimit()), H - T.HalfY)" in q and "local box = { mx, math.max(my, topLimit()), W - mx, H - my }" in q
         and q.index("local function topLimit()") < q.index("local function placeEdge(")),
    ]


def run(src: dict) -> tuple[int, int, str]:
    part = "\n".join(cut(src[k], s, e) for k, lst in CUTS.items() for s, e in lst)
    text = "local PART = " + lua_str(part) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "top_overlap.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"TOP_OVERLAP_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    found = all(cut(src[k], s, e) for k, lst in CUTS.items() for s, e in lst)
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
    ok = found and failed == 0 and checks > 3 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
