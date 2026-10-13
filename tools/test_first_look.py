"""User's first look at the published place (최종 검수 10/13, fix/first-look-1), offline.

Runs, in the official Luau CLI, the CURRENT pieces cut out of the sources:
1. HUD L.FitFold (PC [Menu] fold): the 9th square (the tile row's overflow) no longer falls to a second line alone - when
   the squares need more than the first line they shrink to fit it, down to L.FoldMinFrac of [Menu]'s size, centred on
   the same line, the line's right end kept; too many for that = nil (the lines as before).
2. EventHUD V2.eventY: the next-event line (goose / king pill) rises into the status chip row when that row is empty
   (out of town the pill floated a whole empty row under the war meter); chips shown or unknown = its own row.
Static (user 10/14, PC fold one line): the PC row (HudLayout sheet) holds every L.Tiles tile, HudLayout.FOLD_WANT_PC =
#L.Fold, PC tile names go down to 8 px with a 6 px margin (FitMinPx / PickerFitPaddingX: UIKit's 11px floor held
'Monsters' / 'Settings' against the rim). Static: [Menu] glows only while its fold is shut (Gifts and [Menu] were both ringed), SetFold redraws it; the fold
shrink is PC only; the Codex tile reads "Monsters" (user: "코덱스 뭐야"); EventHUD places the line with V2.eventY and
HUD.ChipsShown exists. Mutations: each must be caught.

Usage: py tools/test_first_look.py
Report: docs/art/verification_2026-10-14/offline_first_look_2026-10-14.json (do not commit)
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
FILES = {"HUD": ROOT / (SPS + "HUD.luau"), "EVENT": ROOT / (SPS + "EventHUD.luau"),
         "LAYOUT": ROOT / (SPS + "HudLayout.luau")}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_first_look_2026-10-14.json"
CUTS = {"HUD": ("function L.FitFold(lines, size, gap, right, n)", "\nend\n"),
        "EVENT": ("function V2.eventY(rects, chipsShown)", "\nend\n")}

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

-- 1. L.FitFold
do
	local L = { FoldMinFrac = tonumber(MIN_FRAC) }
	local f = assert(loadstring(FOLD_SOURCE, "=FitFold"))
	setfenv(f, setmetatable({ L = L }, { __index = getfenv() }))
	f()
	check(L.FoldMinFrac and L.FoldMinFrac >= 0.8 and L.FoldMinFrac < 1, "L.FoldMinFrac a little under [Menu]'s size", MIN_FRAC)
	-- the user's PC (10/13): 8 squares of 44 on the first line, 4 apart, the line's right end at 1000; a second line below
	local size, gap, right = 44, 4, 1000
	local lines = { { X = right - 8 * (size + gap) + gap, Y = 10, Cols = 8 }, { X = right - 8 * (size + gap) + gap, Y = 60, Cols = 8 } }
	local s, one = L.FitFold(lines, size, gap, right, 9)
	check(s ~= nil and one and #one == 1 and one[1].Cols == 9, "9 squares for an 8-square line: one line of 9", s)
	check(s and near(s, (8 * (size + gap)) / 9 - gap), "... each a little smaller (the same line width)", s)
	check(s and s >= size * L.FoldMinFrac and s < size, "... not under the floor", s)
	check(one and near(one[1].X, lines[1].X), "... the line starts where the 8-square line did", one and one[1].X)
	check(one and near(one[1].Y + s / 2, lines[1].Y + size / 2), "... centred on the same line as [Menu]", one and one[1].Y)
	check(L.FitFold(lines, size, gap, right, 8) == nil, "8 squares fit as they are: nothing changes")
	check(L.FitFold(lines, size, gap, right, 4) == nil, "fewer: nothing changes")
	check(L.FitFold(lines, size, gap, right, 11) == nil, "11 would go under the floor: the lines as before")
	check(L.FitFold({}, size, gap, right, 9) == nil and L.FitFold(nil, size, gap, right, 9) == nil, "no lines: nil")
end

-- 2. V2.eventY
do
	local V2 = {}
	local function num(v, d) return type(v) == "number" and v or (d or 0) end
	local f = assert(loadstring(EVENT_SOURCE, "=eventY"))
	setfenv(f, setmetatable({ V2 = V2, num = num }, { __index = getfenv() }))
	f()
	local rects = { chips = { X = 0, Y = 62, W = 288, H = 22 }, event = { X = 0, Y = 88, W = 288, H = 22 } }
	check(V2.eventY(rects, false) == 62, "chip row empty: the pill rises into it", V2.eventY(rects, false))
	check(V2.eventY(rects, true) == 88, "chips shown: its own row", V2.eventY(rects, true))
	check(V2.eventY(rects, nil) == 88, "unknown: its own row", V2.eventY(rects, nil))
	check(V2.eventY({ event = { Y = 88 } }, false) == 88, "no chip rect: its own row")
	check(V2.eventY({ chips = { Y = 120 }, event = { Y = 88 } }, false) == 88, "never down")
	check(V2.eventY({}, false) == nil and V2.eventY(nil, false) == nil, "no event rect: nil")
end

print(string.format("FIRSTLOOK_SUMMARY checks=%d failed=%d", checks, failed))
'''

MUTATIONS = [
    ("HUD", "the floor ignored", "\tif s < size * L.FoldMinFrac then return nil end\n", ""),
    ("HUD", "the line moved off [Menu]'s centre", "Y = first.Y + (size - s) / 2, Cols = n", "Y = first.Y, Cols = n"),
    ("HUD", "shrinks when it already fits", "if not first or type(n) ~= \"number\" or n <= first.Cols or first.Cols < 1 then",
     "if not first or type(n) ~= \"number\" or first.Cols < 1 then"),
    ("HUD", "a smaller floor", "L.FoldMinFrac = 0.85", "L.FoldMinFrac = 0.5"),
    ("EVENT", "the pill stays down", "\tif chipsShown == false and type(chips) == \"table\"", "\tif false and type(chips) == \"table\""),
    ("EVENT", "unknown counts as empty", "\tif chipsShown == false and type(chips) == \"table\"", "\tif chipsShown ~= true and type(chips) == \"table\""),
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


def run(src: dict) -> tuple[int, int, str]:
    m = re.search(r"^L\.FoldMinFrac = (\d+(?:\.\d+)?)$", src["HUD"], re.M)
    text = ("local FOLD_SOURCE = " + lua_str(cut("HUD", src["HUD"])) + "\nlocal MIN_FRAC = " + lua_str(m[1] if m else "nil")
            + "\nlocal EVENT_SOURCE = " + lua_str(cut("EVENT", src["EVENT"])) + "\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "first_look.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"FIRSTLOOK_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def block_ids(h: str, name: str) -> list[str]:
    """the Id = "..." entries of the HUD table field `name = { ... }` (L.Tiles / L.Fold)"""
    m = re.search(r"^\t" + name + r" = \{\n(.*?)^\t\},", h, re.M | re.S)
    return re.findall(r'^\t\t\{ Id = "(\w+)"', m[1], re.M) if m else []


def pc_row(lay: str) -> int:
    """how many tiles the PC sheet row holds (TILE_GAP 3 px on the 1280x720 sheet)"""
    m = re.search(r'^\ttiles = \{ "BC", \{ [\d.]+, [\d.]+, ([\d.]+), ([\d.]+) \}', lay, re.M)
    return int((float(m[1]) + 3) // (float(m[2]) + 3)) if m else 0


def statics(src: dict) -> list[tuple[str, bool]]:
    h, e, lay = src["HUD"], src["EVENT"], src["LAYOUT"]
    want = re.search(r"^local FOLD_WANT_PC = (\d+)$", lay, re.M)
    tiles, fold = block_ids(h, "Tiles"), block_ids(h, "Fold")
    names = re.search(r"^L\.TileNamePxPC, L\.TileNamePadPC = 8, (\d+)$", h, re.M)
    return [
        ("[Menu] glows only while its fold is shut",
         'L.SetGlow("menu", ui.menuGlow, (settings or travel or attend) and ui.foldOpen ~= true)' in h),
        ("opening / closing the fold redraws the glow", "if L.RefreshMenuGlow then pcall(L.RefreshMenuGlow) end" in h
         and "L.RefreshMenuGlow = refreshMenuGlow" in h),
        ("the fold shrink is PC only", "\t\tif not IS_TOUCH then\n\t\t\tlocal s, lines = L.FitFold(g.Lines, g.Size, g.Gap, g.Right, #list)" in h),
        ("each layout starts from the base geometry", "g.Size, g.Lines = g.BaseSize or g.Size, g.BaseLines or g.Lines" in h
         and "BaseSize = f.Size, BaseLines = f.Lines" in h),
        ("the Codex tile reads 'Monsters'", re.search(r'^\tTileCodex = "Monsters",', h, re.M) is not None),
        ("EventHUD places the next-event line with V2.eventY", "local evY = V2.eventY(rects, V2.chipsShown()) or ev.Y" in e),
        ("HUD.ChipsShown exists", "function HUD.ChipsShown()" in h),
        # user 10/14: the PC fold in one line - every row tile (Monsters included) in the PC row, the war meter steps
        # left for exactly the L.Fold squares
        ("the PC row holds every row tile", len(tiles) > 0 and pc_row(lay) == len(tiles)),
        ("the meter steps left for all L.Fold squares", want is not None and len(fold) > 0 and int(want[1]) == len(fold)),
        # 10/14 (2): UIKit's 11px floor held them - PC names fit with a margin and may go down to 8 px (FitMinPx)
        ("PC tile names may go down to 8 px with a margin", names is not None and int(names[1]) >= 4),
        ("PC names carry their floor and margin to UIKit", 'label:SetAttribute("FitMinPx", L.TileNamePxPC)' in h
         and 'label:SetAttribute("PickerFitPaddingX", L.TileNamePadPC)' in h),
    ]


STATIC_MUTATIONS = [
    ("HUD", "both glow again", 'L.SetGlow("menu", ui.menuGlow, (settings or travel or attend) and ui.foldOpen ~= true)',
     'L.SetGlow("menu", ui.menuGlow, settings or travel or attend)'),
    ("HUD", "phones shrink too", "\t\tif not IS_TOUCH then\n\t\t\tlocal s, lines = L.FitFold(", "\t\tif true then\n\t\t\tlocal s, lines = L.FitFold("),
    ("HUD", "the old word", '\tTileCodex = "Monsters",', '\tTileCodex = "Codex",'),
    ("LAYOUT", "the PC row back to six", 'tiles = { "BC", { 424, 634, 438, 60 }', 'tiles = { "BC", { 424, 634, 375, 60 }'),
    ("LAYOUT", "the meter steps for one square fewer", "local FOLD_WANT_PC = 8", "local FOLD_WANT_PC = 7"),
    ("HUD", "a ninth fold square nobody counted", '\t\t{ Id = "Settings", Icon = "IconSettings"',
     '\t\t{ Id = "Extra", Icon = "IconHelp", Window = "Extra" },\n\t\t{ Id = "Settings", Icon = "IconSettings"'),
    ("HUD", "names back to 10 px", "L.TileNamePxPC, L.TileNamePadPC = 8, 6", "L.TileNamePxPC, L.TileNamePadPC = 10, 6"),
    ("HUD", "no margin", "L.TileNamePxPC, L.TileNamePadPC = 8, 6", "L.TileNamePxPC, L.TileNamePadPC = 8, 0"),
    ("HUD", "the floor never reaches UIKit", '\t\tlabel:SetAttribute("FitMinPx", L.TileNamePxPC)\n', ""),
    ("EVENT", "the line keeps its own row", "local evY = V2.eventY(rects, V2.chipsShown()) or ev.Y", "local evY = ev.Y"),
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
