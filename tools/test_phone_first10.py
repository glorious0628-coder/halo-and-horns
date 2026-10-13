"""Phone first 10 minutes (A23-160 ③, 최종 검수 10/13 evening: "폰 첫 10분 읽힘 - 글자 크기·버튼 겹침·40px 미만"), offline.

Runs, in the official Luau CLI, the CURRENT HUD L.LayoutPlate cut out of HUD.luau with stub parts:
1. The power line ('Lv 1 · Power 0'): its row sits on Rects.power_line; its tap area (ui.powerHit) sits over the row -
   PC exactly the row, touch from the row down to the XP bar's bottom and at least L.PowerTap real px tall (44: a finger)
   at the phone's 0.75 UIScale (the 10/13 phone audit: OpenCharacter 87 x 12 px).
Static: the tap area is NOT a child of the PowerLine row (its UIListLayout laid the full-size button out as the first
word and pushed the text past the row's right end - main photos 10/12 PC 'Lv 10 · Power 424 · Pouch 0' right of the
bars, phone 'Lv 1 · Power 0' into the potion ring); L.RefreshWindows shows / hides ui.powerHit. Mutations: each caught.

Usage: py tools/test_phone_first10.py
Report: docs/art/verification_2026-10-14/offline_phone_first10_2026-10-14.json (do not commit)
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = "src/StarterPlayer/StarterPlayerScripts/"
FILES = {"HUD": ROOT / (SPS + "HUD.luau"), "UIKIT": ROOT / (SPS + "UIKit.luau")}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_phone_first10_2026-10-14.json"
CUTS = {"HUD": ("function L.LayoutPlate(R)", "\nend\n"),
        "UIKIT": ("function UIKit.TapExtents(rect, others, px)", "\nend\n")}

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local UDim2 = { fromOffset = function(x, y) return { X = x, Y = y } end }
local function part() return {} end
local function plate(touch, scale)
	local ui = { portraitHolder = part(), powerRow = part(), xpFrame = part(), powerHit = part() }
	local L = { PowerTap = tonumber(HUD_POWER_TAP), CheckPouch = function() end }
	local C = { VitalsUI = { PlaceBars = function() end } }
	local env = setmetatable({ ui = ui, L = L, C = C, UDim2 = UDim2, IS_TOUCH = touch,
		currentScale = function() return scale end }, { __index = getfenv() })
	local f = assert(loadstring(PLATE_SOURCE, "=LayoutPlate"))
	setfenv(f, env)
	f()
	return L, ui
end
local function rects(px, py, pw, ph, xy, xh)
	return { portrait = { X = 0, Y = 0, W = 60, H = 60 }, hp_bar = {}, mp_bar = {},
		power_line = { X = px, Y = py, W = pw, H = ph }, xp_bar = { X = px, Y = xy, W = pw, H = xh } }
end

check(tonumber(HUD_POWER_TAP) and tonumber(HUD_POWER_TAP) >= 44, "L.PowerTap is a finger (>= 44 real px)", HUD_POWER_TAP)

-- PC: the tap area is exactly the row
do
	local L, ui = plate(false, 0.8)
	L.LayoutPlate(rects(482, 570, 375, 16, 614, 8))
	local h, r = ui.powerHit, ui.powerRow
	check(r.Position and r.Position.X == 482 and r.Position.Y == 570 and r.Size.X == 375 and r.Size.Y == 16,
		"PC: the row on Rects.power_line", r.Size and r.Size.X)
	check(h.Position and h.Position.X == 482 and h.Position.Y == 570 and h.Size.X == 375 and h.Size.Y == 16,
		"PC: the tap area = the row", h.Size and (h.Size.X .. "x" .. h.Size.Y))
end

-- phone 655 x 340 safe area (the 10/13 audit): row 328,316 117 x 16, XP bar to 354 + 6
do
	local L, ui = plate(true, 0.75)
	L.LayoutPlate(rects(328, 316, 117, 16, 354, 6))
	local h = ui.powerHit
	local top, bottom = h.Position.Y, h.Position.Y + h.Size.Y
	check(h.Position.X == 328 and h.Size.X == 117, "phone: the tap area as wide as the row", h.Size.X)
	check(math.abs(bottom - 360) < 0.01, "phone: the tap area reaches the XP bar's bottom", bottom)
	check(top <= 316 + 0.01, "phone: the tap area covers the row's top", top)
	check(h.Size.Y * 0.75 >= 44 - 0.01, "phone: the tap area >= 44 real px tall", h.Size.Y * 0.75)
	check(h.Size.Y * 0.75 <= 44 + 0.01, "phone: no taller than it must be (stays off the tile row)", h.Size.Y * 0.75)
end

-- phone where the row + bars already exceed a finger: no growth upwards
do
	local L, ui = plate(true, 0.75)
	L.LayoutPlate(rects(300, 300, 200, 30, 360, 10))
	local h = ui.powerHit
	check(h.Position.Y == 300 and h.Size.Y == 70, "phone: a tall group keeps its own top", h.Position.Y .. "/" .. h.Size.Y)
end

-- 2. UIKit.TapExtents: invisible tap strips around a small button (touch), never past half the gap to a sibling button
do
	local UIKit = {}
	local f = assert(loadstring(TAP_SOURCE, "=TapExtents"))
	setfenv(f, setmetatable({ UIKit = UIKit }, { __index = getfenv() }))
	f()
	local te = UIKit.TapExtents
	local px = tonumber(UIKIT_TAP_PX)
	check(px and px >= 44, "UIKit.Tap.Px is a finger (>= 44 real px)", UIKIT_TAP_PX)
	local e = te({ X = 356, Y = 271, W = 150, H = 30 }, {}, 44)
	check(e.T == 7 and e.B == 7 and e.L == 0 and e.R == 0, "lone Equip 150 x 30: 7 px above and below, none at the sides",
		e.T .. "/" .. e.B .. "/" .. e.L .. "/" .. e.R)
	e = te({ X = 443, Y = 231, W = 28, H = 28 }, { { X = 478, Y = 231, W = 28, H = 28 } }, 44)
	check(e.T == 8 and e.B == 8 and e.L == 8 and e.R == 3.5, "Sort 28 x 28 beside Size (7 px gap): right side stops at 3.5 px",
		e.T .. "/" .. e.B .. "/" .. e.L .. "/" .. e.R)
	-- stacked action buttons 6 px apart: each grows 3 px into the gap, the outer sides the full 7
	e = te({ X = 0, Y = 36, W = 150, H = 30 }, { { X = 0, Y = 0, W = 150, H = 30 }, { X = 0, Y = 72, W = 150, H = 30 } }, 44)
	check(e.T == 3 and e.B == 3, "between two stacked buttons: half the 6 px gap each way", e.T .. "/" .. e.B)
	e = te({ X = 0, Y = 0, W = 150, H = 30 }, { { X = 0, Y = 36, W = 150, H = 30 } }, 44)
	check(e.T == 7 and e.B == 3, "top of a stack: full strip above, half gap below", e.T .. "/" .. e.B)
	-- tabs side by side (no vertical neighbour): full strips above and below
	e = te({ X = 147, Y = 48, W = 86, H = 30 }, { { X = 238, Y = 48, W = 86, H = 30 }, { X = 330, Y = 48, W = 86, H = 30 } }, 44)
	check(e.T == 7 and e.B == 7 and e.R == 0, "a tab beside tabs: 7 px up and down, nothing sideways (wide enough)",
		e.T .. "/" .. e.B .. "/" .. e.R)
	-- a button touching its neighbour gets no strip on that side
	e = te({ X = 0, Y = 30, W = 150, H = 30 }, { { X = 0, Y = 0, W = 150, H = 30 } }, 44)
	check(e.T == 0 and e.B == 7, "touching neighbour above: no strip there", e.T .. "/" .. e.B)
	-- a finger-sized button: nothing
	e = te({ X = 0, Y = 0, W = 60, H = 45 }, {}, 44)
	check(e.T == 0 and e.B == 0 and e.L == 0 and e.R == 0, "a 60 x 45 button: no strips", e.T)
	-- a neighbour not level with the button does not limit it
	e = te({ X = 0, Y = 100, W = 150, H = 30 }, { { X = 400, Y = 60, W = 50, H = 30 } }, 44)
	check(e.T == 7, "a button off to the side does not limit the strip above", e.T)
end

print(string.format("PHONE10_SUMMARY checks=%d failed=%d", checks, failed))
'''

MUTATIONS = [
    ("HUD", "the tap area keeps the row's height on a phone", "\t\tif IS_TOUCH then\n\t\t\tbottom = math.max(bottom, xp.Y + xp.H)",
     "\t\tif false then\n\t\t\tbottom = math.max(bottom, xp.Y + xp.H)"),
    ("HUD", "the tap area is not placed", "\t\tui.powerHit.Position = UDim2.fromOffset(pl.X, top)",
     "\t\tui.powerHit.Position = UDim2.fromOffset(pl.X, pl.Y)"),
    ("HUD", "a smaller finger", "L.PowerTap = 44 ", "L.PowerTap = 30 "),
    ("UIKIT", "strips ignore the neighbours", "\t\tif overX and o.Y + o.H <= rect.Y then up =",
     "\t\tif false and o.Y + o.H <= rect.Y then up ="),
    ("UIKIT", "strips take the whole gap", "up = math.min(up, (rect.Y - (o.Y + o.H)) / 2)",
     "up = math.min(up, (rect.Y - (o.Y + o.H)))"),
    ("UIKIT", "no side strips for a narrow button", "needX = math.max(0, px - rect.H) / 2, math.max(0, px - rect.W) / 2",
     "needX = math.max(0, px - rect.H) / 2, 0"),
    ("UIKIT", "a smaller tap target", "UIKit.Tap = { Px = 44 }", "UIKit.Tap = { Px = 36 }"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(key: str, text: str) -> str:
    start, end = CUTS[key]
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    return text[a:b + len(end)] if b >= 0 else ""


def power_tap(hud: str) -> str:
    m = re.search(r"^L\.PowerTap = (\d+(?:\.\d+)?) ", hud, re.M)
    return m[1] if m else "nil"


def run(src: dict) -> tuple[int, int, str]:
    m = re.search(r"^UIKit\.Tap = \{ Px = (\d+(?:\.\d+)?) \}", src["UIKIT"], re.M)
    text = ("local PLATE_SOURCE = " + lua_str(cut("HUD", src["HUD"])) + "\nlocal HUD_POWER_TAP = "
            + lua_str(power_tap(src["HUD"])) + "\nlocal TAP_SOURCE = " + lua_str(cut("UIKIT", src["UIKIT"]))
            + "\nlocal UIKIT_TAP_PX = " + lua_str(m[1] if m else "nil") + "\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "phone_first10.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"PHONE10_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def statics(src: dict) -> list[tuple[str, bool]]:
    h, u = src["HUD"], src["UIKIT"]
    return [
        ("the power tap area is not a child of the PowerLine row (its UIListLayout)", "L.PowerHit(ui.powerRow)" not in h
         and "ui.powerHit = L.PowerHit(parent)" in h),
        ("the power tap area draws over the row", "ui.powerHit.ZIndex = ui.powerRow.ZIndex + 2" in h),
        ("L.RefreshWindows shows / hides ui.powerHit", "for _, hit in { ui.portraitHit, ui.powerHit } do" in h),
        ("every UIKit press button gets the strips through wirePress (same handler as Activated)",
         "\tbtn.Activated:Connect(fire)\n\tUIKit.TapPad(btn, fire)\n" in u),
        ("the strips are touch-only", "if not UserInputService.TouchEnabled or typeof(btn) ~= \"Instance\"" in u),
        ("no strips in a button that lays out / clips its children, or with NoTapPad",
         "btn:GetAttribute(\"NoTapPad\") == true or btn.ClipsDescendants" in u
         and "btn:FindFirstChildWhichIsA(\"UIGridStyleLayout\")" in u),
        ("the strips sit outside the button (a press on the button keeps its own feel)",
         'place("TapPadTop", e.T >= 1, -e.L, -e.T, w, e.T)' in u and 'place("TapPadBottom", e.B >= 1, -e.L, size.Y, w, e.B)' in u),
    ]


STATIC_MUTATIONS = [
    ("UIKIT", "wirePress skips the strips", "\tbtn.Activated:Connect(fire)\n\tUIKit.TapPad(btn, fire)\n",
     "\tbtn.Activated:Connect(fire)\n"),
    ("UIKIT", "strips on PCs too", "if not UserInputService.TouchEnabled or typeof(btn) ~= \"Instance\"",
     "if typeof(btn) ~= \"Instance\""),
    ("UIKIT", "strips inside a list layout", "\n\t\t\tor btn:FindFirstChildWhichIsA(\"UIGridStyleLayout\")", ""),
    ("HUD", "the tap area back inside the row", "ui.powerHit = L.PowerHit(parent)", "ui.powerHit = L.PowerHit(ui.powerRow)"),
    ("HUD", "RefreshWindows forgets the power tap", "for _, hit in { ui.portraitHit, ui.powerHit } do",
     "for _, hit in { ui.portraitHit } do"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    found = all(cut(k, src[k]) for k in CUTS)
    checks, failed, out = run(src)
    print(out.strip())
    st = [{"check": n, "ok": ok} for n, ok in statics(src)]
    for s in st:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        m = dict(src)
        m[key] = src[key].replace(old, new)
        caught = hits == 1 and run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    for key, name, old, new in STATIC_MUTATIONS:
        hits = src[key].count(old)
        m = dict(src)
        m[key] = src[key].replace(old, new)
        caught = hits == 1 and not all(ok for _, ok in statics(m))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = found and failed == 0 and checks > 0 and all(s["ok"] for s in st) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": st, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
