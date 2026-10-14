"""최종 검수 10/14 상단 HUD 1안 (Codex build/codex/hud_top_design.md option 1 + 최종 검수's decisions), offline.

① HUD.WarGeometry: the crown FLOATS over the track (its image rect CrownGap px clear: 6 PC / 4 phone), crown 24 / 22 px,
   track 14 px, badges 40 / 36 px inside the meter's ends and centred on the track (BadgeGap 8 to it), the plate around
   the track only (never past the badges' bottom); all REAL px (du x UIScale). No time / words on the bar (the badge
   scores stay); a press opens the small war window (Config.WarInfo, HUD.WarInfoLines: time left or NoRound, "Halo 12 :
   9 Horns"); no NEW! tag on the war bar.
② HUD.ChipPlan: danger chips (Bully / Outlaw / Wanted, the PvP zone) always show with their words, never counted or in
   '+N'; closed = the Safe Zone as its icon + ONE buff icon (the first of L.ChipBuffs that has an icon) + '+N'; open (a
   press) = the others with their words up to `fit`; no chips -> no row. The status row starts ChipTop.Gap under the war
   meter's drawn bottom, 36 / 44 px tall, words >= 18 / 19 px, wraps only for the danger names.
③ V2.PickEvent: one event chip - the kaiju on me (class 2) > the live king / open goose (3) > the nearest coming one (4);
   a tie keeps the chip shown now (no swapping). Its NEW! sits INSIDE its right end (UIKit NewTagInside), dropped when
   the chip cannot widen; the chip 40 / 44 px, words >= 18 / 19 px; the notify rows start under it.
Extracted and run with the CURRENT HUD.luau / EventHUD.luau / Config.luau; statics for the wiring; mutations.
Report: docs/art/verification_2026-10-14/offline_hud_top_1an_2026-10-14.json (do not commit)
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
FILES = {"HUD": SPS / "HUD.luau", "EV": SPS / "EventHUD.luau", "UIKIT": SPS / "UIKit.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_hud_top_1an_2026-10-14.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function near(a, b) return math.abs(a - b) < 1e-6 end

-- ① the war meter
for _, row in { { false, 0.8, 360, 52.5, 24, 6, 40 }, { true, 0.75, 320, 50.7, 22, 4, 36 } } do
	local touch, s, w, h, crownPx, gapPx, badgePx = table.unpack(row)
	local g = HUD.WarGeometry(w, h, s, touch)
	local dev = touch and "phone" or "PC"
	check(near(g.Crown.S * s, crownPx) and near(g.Track.H * s, 14) and near(g.Badge.S * s, badgePx),
		dev .. ": crown " .. crownPx .. " px, track 14 px, badges " .. badgePx .. " px (real px)", g.Crown.S * s)
	check(near((g.Track.Y - (g.Crown.Y + g.Crown.S)) * s, gapPx),
		dev .. ": the crown's image rect " .. gapPx .. " px OVER the track (no overlap)", (g.Track.Y - (g.Crown.Y + g.Crown.S)) * s)
	check(near(g.Badge.CY, g.Track.Y + g.Track.H / 2) and near(g.Track.X, g.Badge.S + 8 / s) and near(g.Track.W, w - 2 * g.Track.X),
		dev .. ": badges inside the ends, centred on the track, the track 8 px from them", g.Track.X)
	check(g.Plate.Y <= g.Track.Y and g.Plate.Y + g.Plate.H >= g.Track.Y + g.Track.H and g.Plate.Y + g.Plate.H <= g.Bottom + 1e-6,
		dev .. ": the plate around the track, never past the badges' bottom", g.Plate.Y + g.Plate.H)
	check(near(g.Bottom, g.Badge.CY + g.Badge.S / 2), dev .. ": the drawn bottom = the badges' bottom", g.Bottom)
end
local t1, s1 = HUD.WarInfoLines(1000 + 534, 1000, 12, 9)
check(t1 == "Next crown in 8:54" and s1 == "Halo 12 : 9 Horns", "war window: time left + both scores", t1 .. " | " .. s1)
local t2 = HUD.WarInfoLines(0, 1000, 0, 0)
check(t2 == Config.WarInfo.Text.NoRound, "war window: no round -> NoRound, never a clock", t2)

-- ② the status chips
local danger = { Bully = true, Outlaw = true, Wanted = true }
local buffs = { "Boost", "Luck", "Blessing", "Rookie", "Private", "Protected", "Size" }
local iconOK = { Zone = true, Boost = true, Luck = true, Rookie = true, Private = true, Blessing = true }
local function plan(keys, open, fit, town, pvp, icons)
	local p = HUD.ChipPlan(keys, danger, icons or iconOK, buffs, open, fit, town, pvp)
	local out = {}
	for _, r in p.Show do table.insert(out, r.Key .. (r.Icon and "*" or "")) end
	return table.concat(out, ","), p.More
end
local keys = { "Outlaw", "Wanted", "Zone", "Luck", "Boost", "Rookie" }
local a, m = plan(keys, false, 2, true, false)
check(a == "Outlaw,Wanted,Zone*,Boost*" and m == 2, "closed: danger words, the Safe Zone icon, ONE buff icon (Boost), +2", a .. " +" .. m)
a, m = plan(keys, true, 2, true, false)
check(a == "Outlaw,Wanted,Zone,Luck" and m == 2, "open: the others with words up to fit", a .. " +" .. m)
a, m = plan(keys, false, 0, true, false)
check(a == "Outlaw,Wanted" and m == 4, "no room: the danger names still show, never in +N", a .. " +" .. m)
a, m = plan({ "Bully", "Zone", "Luck" }, false, 2, false, true)
check(a == "Bully,Zone,Luck*" and m == 0, "a PvP zone is a danger chip (words)", a .. " +" .. m)
a, m = plan({ "Zone", "Protected", "Luck" }, false, 2, true, false, { Zone = true, Luck = true })
check(a == "Zone*,Luck*" and m == 1, "a buff without an icon is skipped for the one buff icon", a .. " +" .. m)
a, m = plan({}, false, 2, true, false)
check(a == "" and m == 0, "nothing to show: no row", a)
a, m = plan({ "Combat", "Kaiju" }, false, 2, false, false)
check(a == "" and m == 2, "closed: other states wait behind +N", a .. " +" .. m)

-- ③ one event chip
local K, KI, G = "Kaiju", "King", "Goose"
local function pick(c, cur) return V2.PickEvent(c, cur) end
check(pick({ { Inst = G, Class = 4, In = 5 }, { Inst = K, Class = 2, In = 0 } }) == K, "the kaiju on me beats a coming goose")
check(pick({ { Inst = G, Class = 4, In = 5 }, { Inst = KI, Class = 3, In = 0 } }) == KI, "a live king beats a coming goose")
check(pick({ { Inst = G, Class = 4, In = 300 }, { Inst = KI, Class = 4, In = 90 } }) == KI, "two coming: the nearest")
check(pick({ { Inst = G, Class = 4, In = 90 }, { Inst = KI, Class = 4, In = 90 } }, G) == G, "a tie keeps the chip shown now")
check(pick({ { Inst = G, Class = 3, In = 0 }, { Inst = KI, Class = 3, In = 0 } }, KI) == KI, "same class now: no swapping")
check(pick({ { Inst = G, Class = 4, In = 300 }, { Inst = KI, Class = 4, In = 20 } }, G) == KI, "a nearer one still takes over")
check(pick({}) == nil, "no event: no chip")
print(("HUD_TOP_1AN_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("HUD", "the crown on the track again", "\tlocal trackY = crownY + crown + px(\"CrownGap\")\n", "\tlocal trackY = crownY + crown * 0.6\n"),
    ("HUD", "badges outside the ends again", "\tlocal trackX = badge + px(\"BadgeGap\")\n", "\tlocal trackX = badge / 2\n"),
    ("HUD", "the plate down past the badges", "\tlocal plateH = math.min(trackH + 2 * pad, cy + badge / 2 - plateY)\n", "\tlocal plateH = trackH + 6 * pad + badge\n"),
    ("HUD", "danger chips in '+N'", "\t\tif danger[k] or (k == \"Zone\" and zoneDanger) then\n", "\t\tif false then\n"),
    ("HUD", "every buff as an icon", "\t\t\tpicked[b] = true\n\t\t\tbreak\n", "\t\t\tpicked[b] = true\n"),
    ("HUD", "the Safe Zone with words when closed", "\tif table.find(rest, \"Zone\") and safeZone and iconOK.Zone then picked.Zone = true end\n", ""),
    ("HUD", "the war window shows a clock with no round", "local time = endsAt > now and", "local time = true and"),
    ("EV", "a tie swaps chips", "\t\tif c.Inst == current and c.Class == best.Class", "\t\tif false and c.Inst == current"),
    ("EV", "the kaiju waits behind a coming goose", "Inst = ui.KaijuChip, Class = 2, In = 0", "Inst = ui.KaijuChip, Class = 5, In = 0"),
    ("CONFIG", "the war window words missing", '\t\tNoRound = "A new round starts soon.",\n', ""),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find("\nend\n", a)
    return text[a:b + 5] if b >= 0 else ""


def block(text: str, start: str, end: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    return text[a:b + len(end)] if b >= 0 else ""


def run(src: dict) -> tuple[int, int, str]:
    h, e, c = src["HUD"], src["EV"], src["CONFIG"]
    wartop = block(h, "L.WarTop = {", "}\n")
    prelude = ("local HUD, V2, L = {}, {}, {}\nlocal function num(v) return tonumber(v) or 0 end\n"
               "local Util = { FormatTime = function(t) t = math.floor(t) return string.format('%d:%02d', t // 60, t % 60) end }\n"
               "local function fmtScore(v) return tostring(math.floor(v)) end\n"
               "function L.Tx(t, key, ...) return string.format(t[key], ...) end\n"
               "local Config = { Factions = { Halo = { Name = 'Halo' }, Horns = { Name = 'Horns' } } }\n"
               + block(c, "Config.WarInfo = {", "\n}\n") + "\n" + wartop + "\n")
    parts = [cut(h, "function HUD.WarGeometry(w, h, s, touch)"), cut(h, "function HUD.ChipPlan("),
             cut(h, "function HUD.WarInfoLines(endsAt, now, halo, horns)"), cut(e, "function V2.PickEvent(cands, current)")]
    code = prelude + "\n".join(parts) + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "hud_top_1an.luau"
        p.write_text(code, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"HUD_TOP_1AN_SUMMARY checks=(\d+) failed=(\d+)", out)
    st = statics(src)
    out += "".join(("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + n for n, ok in st)
    return (int(m[1]) if m else 0) + len(st), (int(m[2]) if m else 1) + sum(1 for _, ok in st if not ok), out


def statics(src: dict) -> list[tuple[str, bool]]:
    h, e, u = src["HUD"], src["EV"], src["UIKIT"]
    return [
        ("① LayoutWar places every piece from HUD.WarGeometry; the crown follows the split over the track; no NEW! on the bar",
         "local g = HUD.WarGeometry(wf, h, currentScale(), IS_TOUCH)" in h and "L.WarCrownX = L.WarCrownFrac(frac)" in h
         and "pcall(UIKit.NewTag, ui.war)" not in h and "pcall(UIKit.NewTag, ui.warBar)" not in h and "ui.warTime" not in h),
        ("① a press on the bar opens the war window (Panels, registered in HUD.Start)",
         "\topen.Activated:Connect(function() pcall(L.OpenWarInfo) end)\n" in h and "C.Panels.Open(L.WarInfoId)" in h
         and "pcall(L.RegisterWarInfo)" in h),
        ("② the status row: under the war meter's drawn bottom + Gap, 36 / 44 px tall, words >= 18 / 19 px, wraps, presses open it",
         "local warBottom = (ui.war.Visible and L.WarGeo) and (wm.Y + L.WarGeo.Bottom + CT.Gap / s) or ch.Y" in h
         and "local textDu = math.ceil((IS_TOUCH and CT.TextPxTouch or CT.TextPx) / s)" in h and "Wraps = true," in h
         and "L.ChipTop = { Row = 36, RowTouch = 44, Gap = 8, TextPx = 18, TextPxTouch = 19, Icon = 24, IconTouch = 24 }" in h
         and "pcall(L.ChipPress, key)" in h and "L.ChipDanger = { Bully = true, Outlaw = true, Wanted = true }" in h),
        ("③ one event chip (V2.PickEvent, the kaiju too), 40 / 44 px, words >= 18 / 19 px, the notify rows under it",
         "eventInst = V2.PickEvent(cands, V2.EventCur)" in e and "{ Inst = ui.KaijuChip, Class = 2, In = 0 }" in e and "setVisible(ui.KaijuChip, eventInst == ui.KaijuChip)" in e
         and "L.EventTop = { H = 40, HTouch = 44, TextPx = 18, TextPxTouch = 19," in e and "\tV2.EventMinText()\n" in e
         and "local y, last = math.max(top, V2.EventBottom and math.ceil(V2.EventBottom + gap) or top), nil" in e),
        ("③ NEW! INSIDE the event chip's right end (dropped when it cannot widen; the words keep clear)",
         'chip:SetAttribute("NewTagInside",' in e and "if res > 0 and natural + res > num(ev.W) then" in e
         and 'local inside = tonumber(target:GetAttribute("NewTagInside"))' in u
         and "local right = G.Right + ((SQ.NewRes or 0) > 0 and (SQ.NewRes - G.Right) or 0)" in e),
    ]


STATIC_MUTATIONS = [
    ("HUD", "the status row on the war meter", "(wm.Y + L.WarGeo.Bottom + CT.Gap / s)", "(wm.Y)"),
    ("EV", "the NEW! sticks out again", 'chip:SetAttribute("NewTagInside",', 'chip:SetAttribute("NewTagOutside",'),
    ("EV", "the notify rows over the event chip", "local y, last = math.max(top, V2.EventBottom and math.ceil(V2.EventBottom + gap) or top), nil",
     "local y, last = top, nil"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS + STATIC_MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = failed == 0 and checks > 20 and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Extracted")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
