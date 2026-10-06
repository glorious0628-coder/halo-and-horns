"""HUD layout B (SPEC A23-40; was v2 A23-26) offline check: HudLayout.Compute on PC, phone and tablet screens.

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/HudLayout.luau, injected into tools/fixtures/hud_layout_offline.luau,
with the installed official Luau CLI (build/luau_cli_0_741). No Studio, network or Roblox API calls.

Screens: MainGui logical units are derived exactly like UIKit.applyScale (Config.UI ScaleMin / ScaleMax / DesktopScaleMult /
DesktopScaleMin / DesktopScaleMax, reference height 720) and the touch jump button like Roblox's TouchJump (70 px on
screens whose short side <= 500, else 120 px). The approved rects come from docs/design/hud_layout_B_imgdev_2026-10-06.json
(PC = 검수's docs/design/hud_layout_B_2026-10-06.json, phone = 이미지 개발 by the A23-40 rules).

Checks (named, collected): every item on screen below the top bar, except [메뉴] and the war meter, which sit IN the
Roblox top bar row (A23-40 보강, user 2026-10-06): centred on the bar's middle like Roblox's buttons, inside its free part
(GuiService.TopbarInset = env.Topbar; screens with Roblox's menu opened wide included), no taller than a Roblox button,
[메뉴] a Roblox-button square 12 px from the free right end; the chips / next event / notify right under the bar; the
[메뉴] fold-out room (out.fold) along the bar first, then down, clear of Roblox's buttons, the war meter, minimap, quest
lines, face / bars and combat buttons with the four menu tiles (+ the phone row's overflow) in one row (A23-40 정정); no two items overlap (circles as circles) on every
supported screen and pressable items keep >= 2 logical units apart; touch targets >= 60 logical units (portrait, round
combat buttons, the quest lines block, every icon tile, both potion cells: cell = (W - Gap) / 2); nothing pressable on the
jump button or in the thumbstick zone (x < 0.4W, y > H/3); blocks stay at their edges (minimap + quest top-left, PC face /
bars / tiles bottom-centre clear of the corner cluster, phone plate + tiles top-right); the tile row fits 8 tiles on the PC
reference and >= 5 on phones; one centre column for the meter, the chip row, the next-event line and notify, clear of the
left / right blocks; the two reference screens reproduce the sheet within 1 px (potion gap 6 px included); HudLayout stays
a pure module.

Exceptions: EXCEPTIONS names screens where one check cannot hold for lack of room, with the reason. The check is
replaced by a weaker one (e.g. the potions must reach the thumbstick zone edge) and the screen is listed in the report's
"exceptions" with the measured value; an exception that is no longer needed fails ("exception still needed").

Mutations: in-memory copies of HudLayout with one rule broken each; each must make a check fail that passes on the
real source. --no-mutations skips them and the status is then "passed-no-mutations" (never "passed").

Usage: py tools/test_hud_layout.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/hud_layout_B_offline_2026-10-06.json (+ .png drawing of every screen)
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/fixtures/hud_layout_offline.luau"
LAYOUT_REL = "src/StarterPlayer/StarterPlayerScripts/HudLayout.luau"
LAYOUT = ROOT / LAYOUT_REL
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
SHEET = ROOT / "docs/design/hud_layout_B_imgdev_2026-10-06.json"
OUT = ROOT / "docs/art/verification_2026-10-06/hud_layout_B_offline_2026-10-06.json"
PNG = OUT.with_suffix(".png")

INSET = 58  # Roblox top bar (real px) on both reference screens of the approved sheet
SMALL_PC_PX = 500  # HudLayout.luau SMALL_PC: a desktop window shorter than this uses the phone sheet
ROBLOX_LEFT = 164  # where Roblox's own top bar buttons end (GuiService.TopbarInset.Min.X, UiSandbox PC + phone 2026-10-06)

# (name, touch, screen px w, h, reference screen, supported, top inset px, MainGui safe area px or None[, Roblox
# buttons' right end px when not ROBLOX_LEFT])
SCREENS = [
    ("pc_1280x720", False, 1280, 720, True, True, INSET, None),
    ("pc_1024x768", False, 1024, 768, False, True, INSET, None),
    ("pc_1366x768", False, 1366, 768, False, True, INSET, None),
    ("pc_1920x1080", False, 1920, 1080, False, True, INSET, None),
    ("pc_1280x1024", False, 1280, 1024, False, True, INSET, None),
    ("pc_1024x600", False, 1024, 600, False, True, INSET, None),
    ("pc_800x600", False, 800, 600, False, True, INSET, None),
    ("pc_800x720_narrow", False, 800, 720, False, True, INSET, None),
    ("pc_1280x720_inset36", False, 1280, 720, False, True, 36, None),
    # Roblox's own menu opened wide in the top bar (chat + menu + more): the war meter keeps clear of it
    ("pc_1280x720_unibar_wide", False, 1280, 720, False, True, INSET, None, 560),
    # short desktop windows (< 500 px tall) lay out on the phone sheet (HudLayout SMALL_PC; main Studio 655x340 /
    # 573x354 had the quest lines run into the face group on the desktop sheet, 검수 2026-10-06)
    ("pc_655x340_small", False, 655, 340, False, True, INSET, None),
    ("pc_573x354_small", False, 573, 354, False, True, INSET, None),
    ("pc_700x450_small", False, 700, 450, False, True, INSET, None),
    # a very short window: overlaps are accepted there, but everything must stay on screen below the top bar
    ("pc_1280x240_short", False, 1280, 240, False, False, INSET, None),
    ("phone_749x361", True, 749, 361, True, True, INSET, None),
    ("phone_749x361_notch", True, 749, 361, False, True, INSET, (655, 340)),
    ("phone_844x390", True, 844, 390, False, True, INSET, None),
    ("phone_667x375", True, 667, 375, False, True, INSET, None),
    ("phone_568x320", True, 568, 320, False, True, INSET, None),
    # Android 640x360 with its 48 px navigation bar: the potion cells only reach 60du by growing to the left
    ("phone_592x360_navbar", True, 592, 360, False, True, INSET, None),
    ("tablet_1024x768", True, 1024, 768, False, True, INSET, None),
    ("tablet_1180x820", True, 1180, 820, False, True, INSET, None),
]

# (screen, check, reason): a check that cannot hold on that screen for lack of room (named, explained, reported)
EXCEPTIONS = [
    ("phone_568x320", "tap size potions cell width",
     "4-inch phone (iPhone SE 1st gen class, 568x320 px): the whole layout scales to k = 1.011 du/px, so the potions "
     "rect is 113du wide. Growing to the left (right edge kept: Q sits 6du to its right) stops at the thumbstick zone "
     "edge x = 0.4W = 302.9du, which leaves 120.5du: two cells of 57.2du with the approved 6 px gap (60.2du only with "
     "no gap at all). The cells stay below 60du (~43 real px) here; spec decision needed."),
    # A23-40 보강: [메뉴] and the war meter share the Roblox top bar with Roblox's own buttons (164 px). Where the bar
    # cannot hold Roblox's buttons + the war meter (>= 240du) + [메뉴] + 4 thumb-size fold squares, the fold-out's
    # first line beside [메뉴] holds fewer and the rest wrap to the next line right under the bar
    ("phone_568x320", "fold holds the menu tiles in one line",
     "568 px wide phone: 164 px of Roblox buttons + the 240du war meter + [메뉴] leave room for 2 fold squares in the "
     "bar; the other 2 wrap to the line right under it (A23-40 보강)."),
    ("phone_592x360_navbar", "fold holds the menu tiles in one line",
     "592 px wide (Android nav bar): the bar holds 3 fold squares beside [메뉴]; the 4th wraps under the bar."),
    ("pc_573x354_small", "fold holds the menu tiles in one line",
     "573 px wide desktop window on the phone sheet: Roblox's buttons + the war meter + [메뉴] leave room for 3 fold "
     "squares in the bar; the 4th wraps under it (A23-40 보강, like the narrow phones)."),
    ("phone_749x361_notch", "fold holds the menu tiles in one line",
     "655 px safe area (notch): 164 px Roblox buttons + war meter + [메뉴] + 4 squares need ~670 px; 3 squares fit "
     "in the bar, the 4th wraps under it."),
]

# (name, exact text, replacement) in HudLayout.luau: each must match exactly once. The final on-screen clamp (r.Y) has no
# mutation since SMALL_PC: windows short enough to push items off the desktop sheet now use the phone sheet, which the
# safe-area factor always fits (the clamp stays as a guard; "every item on screen" still runs on every screen). The centre column's narrowing / room
# clamp is defensive in layout B (no supported screen squeezes the column: the left, centre and right blocks all scale
# with the same k), so it has no mutation here; the column checks still run on every screen.
MUTATIONS = [
    ("short desktop windows keep the desktop sheet", "local sheet = touch or HudLayout.SmallDesktop(env)",
     "local sheet = touch"),
    ("touch targets may shrink to 30", "local MIN_TAP = 60", "local MIN_TAP = 30"),
    ("round touch buttons never grow back", "			if r.W < MIN_TAP then", "			if false then"),
    ("potions never grow back", "if pot.H < MIN_TAP then pot.Y, pot.H = pot.Y + pot.H - MIN_TAP, MIN_TAP end", ""),
    ("grown portrait covers the plate", "r.X, r.W = r.X + g, math.max(1, r.W - g)", "r.X, r.W = r.X, r.W"),
    ("grown portrait covers the tile row", "out.tiles.Y += g", ""),
    ("touch tiles may shrink below a thumb", "local size = touch and math.max(tiles.H, MIN_TAP) or tiles.H",
     "local size = tiles.H"),
    ("tile count ignores the gap", "+ 1e-6))\n\t-- [메뉴]: a Roblox-button-sized square",
     "+ 1e-6)) + 1\n\t-- [메뉴]: a Roblox-button-sized square"),
    ("tiles touch", "local TILE_GAP = 3", "local TILE_GAP = 0"),
    ("touch quest lines may shrink below a thumb", "if out.quest.H < MIN_TAP then out.quest.H = MIN_TAP end", ""),
    ("top-right items anchored to the left edge",
     "X, Y = W - (ref.W - x) * k, top + (y - ref.Inset) * k", "X, Y = x * k, top + (y - ref.Inset) * k"),
    ("top-left items ignore the real top bar",
     "X, Y = x * k, top + (y - ref.Inset) * k", "X, Y = x * k, y * k"),
    ("phone plate anchored like the PC (bottom-centre)", '{ 502, 62, 45, 45 }, "TR" }', '{ 502, 62, 45, 45 } }'),
    ("narrow phone safe area not shrunk",
     "k *= math.min(1, W / (ref.W / ref.Scale), H / (ref.H / ref.Scale))", "k *= 1"),
    ("centre column touches its neighbours", "local GAP = 8", "local GAP = 0"),
    ("PC face group never steps aside", "if maxX > limit then", "if false then"),
    ("PC face group ignores the left margin", "local shift = math.min(maxX - limit, math.max(0, minX - GAP))",
     "local shift = maxX - limit"),
    ("touch cluster ignores the jump button", "elseif jump and rj then", "elseif false then"),
    ("cluster measured from the jump centre only", "if x >= rj[1] then", "if true then"),
    ("auto not kept above the jump button", "if y + r[4] <= rj[2] then", "if false then"),
    ("touch combo stays bottom-centre", 'if anchor == "BC" and jump then anchor = "BR" end', ""),
    ("desktop attack rect drifted", 'attack = { "BR", { 1146, 592, 118, 118 }', 'attack = { "BR", { 1146, 598, 118, 118 }'),
    ("desktop tiles rect drifted", 'tiles = { "BC", { 420, 640, 440, 52 }', 'tiles = { "BC", { 420, 646, 440, 52 }'),
    ("phone skill Q rect drifted", "{ 455, 252, 72, 72 }", "{ 455, 262, 72, 72 }"),
    # A23-49: the X skill button
    ("phone X skill rect drifted", "{ 580, 164, 72, 72 }", "{ 580, 150, 72, 72 }"),
    ("desktop X skill rect drifted", "{ 1186, 499, 77, 77 }", "{ 1196, 499, 77, 77 }"),
    ("round buttons may sit on the phone tile row",
     "if r.X < tiles.X + tiles.W and r.X + r.W > tiles.X and r.Y < rowBottom then r.Y = rowBottom end", ""),
    ("phone quest rect drifted", "{ 98, 62, 150, 45 }", "{ 98, 62, 170, 45 }"),
    ("potions never widen", "if minX < pot.X then pot.X, pot.W = minX, potRight - minX end", ""),
    ("potions grow into the stick zone",
     "if pot.Y + pot.H > H * STICK.Y then minX = math.max(minX, W * STICK.X) end", ""),
    ("potion gap drifted", "local POTION_GAP = 6", "local POTION_GAP = 2"),
    # A23-40 정정: [메뉴] top-right + its fold-out room
    ("menu not at the bar's right end", "menu.X = bar.X1 - TOPBAR.Edge / s - mSize", "menu.X = bar.X1 - 40 / s - mSize"),
    ("menu under the bar", "menu.Y = barMid - mSize / 2", "menu.Y = bar.Y1 + 4 / s"),
    ("touch menu may shrink below a thumb", "local mSize = touch and math.max(btn, TOPBAR.Tap / s) or btn", "local mSize = btn"),
    ("menu bigger than a Roblox button", "local btn = math.min(TOPBAR.Button, math.max(1, barPx - 4)) / s",
     "local btn = 52 / s"),
    # A23-40 보강: the war meter in the Roblox top bar row
    ("war meter not in the top bar", 'war_meter = { "TB",', 'war_meter = { "TC",'),
    ("top bar items follow the UIScale", "h = math.min(r[4], TOPBAR.Button, math.max(1, barPx - 4)) / s", "h = r[4] * k"),
    ("war meter not centred on the bar", "X, Y = W / 2 + (x - ref.W / 2) * k, barMid - h / 2",
     "X, Y = W / 2 + (x - ref.W / 2) * k, bar.Y0"),
    ("bar row on the bar's middle, not Roblox's buttons'", "local barMid = bar.Y1 - TOPBAR.Bottom / s - btn / 2",
     "local barMid = (bar.Y0 + bar.Y1) / 2"),
    ("Roblox's buttons not kept clear",
     "if c.Y < bar.Y1 and c.Y + c.H > bar.Y0 then leftEdge = math.max(leftEdge, bar.X0 + GAP) end", ""),
    ("no fold room left beside [메뉴]", "rightEdge = math.min(rightEdge, o.X - FOLD_MIN * (o.W + fGapRow) - GAP)",
     "rightEdge = math.min(rightEdge, o.X - GAP)"),
    ("info rows not under the bar", 'chips = { "TC", { 516, 62, 248, 22 }', 'chips = { "TC", { 516, 112, 248, 22 }'),
    # (the fold's Roblox-buttons blocker is defensive: the war meter always sits between them and [메뉴] in the bar, so no
    # supported screen reaches it; "fold first line in the top bar" still checks that the line stays right of them)
    ("fold may cover the war meter", "local FOLD_OVER = { tiles = true,", "local FOLD_OVER = { war_meter = true, tiles = true,"),
    ("fold lines ignore every item", "if o.Y < y0 + fSize and o.Y + o.H > y0 and o.X < m.X - 0.01 then", "if false then"),
    ("fold one square too many", "return math.max(0, math.floor((right - left + fGap) / (fSize + fGap) + 1e-6))",
     "return math.max(0, math.floor((right - left + fGap) / (fSize + fGap) + 1e-6)) + 1"),
    ("fold lines go up", "local y, step = m.Y, fSize + fGap", "local y, step = m.Y, -(fSize + fGap)"),
    ("fold covers the thumbstick zone", "table.insert(blockers, rect(0, H * STICK.Y, W * STICK.X, H - H * STICK.Y))", ""),
    ("phone tile row stops short", "{ 502, 112, 239, 45 }", "{ 502, 112, 191, 45 }"),
    ("fold squares touch", "local fGap = sheet and tileGap or FOLD_GAP * k", "local fGap = 0"),
]


def config_ui() -> dict:
    """UIKit.applyScale's numbers from Config.UI (UIKit falls back to the same defaults)."""
    text = CONFIG.read_text(encoding="utf-8-sig")
    block = re.search(r"^Config\.UI\s*=\s*\{(.*?)\n\}", text, re.S | re.M)
    body = block.group(1) if block else ""
    out = {"ScaleMin": 0.75, "ScaleMax": 1.25, "DesktopScaleMult": 0.8, "DesktopScaleMin": 0.6, "DesktopScaleMax": 1.0}
    for key in out:
        m = re.search(rf"\b{key}\s*=\s*([0-9.]+)", body)
        if m:
            out[key] = float(m.group(1))
    return out


def ui_scale(touch: bool, camera_h: float, ui: dict) -> float:
    if touch:
        return min(max(camera_h / 720, ui["ScaleMin"]), ui["ScaleMax"])
    return min(max(camera_h / 720 * ui["DesktopScaleMult"], ui["DesktopScaleMin"]), ui["DesktopScaleMax"])


def jump_rect(w: float, h: float) -> dict:
    """Roblox TouchJump: size 70 (short side <= 500) or 120, at (W - (1.5 size - 10), H - size - 20 | H - 1.75 size)."""
    small = min(w, h) <= 500
    size = 70 if small else 120
    return {"X": w - (size * 1.5 - 10), "Y": h - size - 20 if small else h - size * 1.75, "W": size, "H": size}


def cases(ui: dict) -> list[dict]:
    """Every screen once (layout B has no pouch line: the pouch rides the power line or hides)."""
    out = []
    for name, touch, pw, ph, ref, supported, inset, safe, *more in SCREENS:
        s = ui_scale(touch, ph, ui)
        gw, gh = safe or (pw, ph)
        left = more[0] if more else ROBLOX_LEFT
        env = {"W": gw / s, "H": gh / s, "Scale": s, "Inset": inset, "Touch": touch,
               # GuiService.TopbarInset in MainGui logical units: Roblox's buttons end at `left`, the bar is `inset` tall
               "Topbar": {"X0": left / s, "Y0": 0, "X1": gw / s, "Y1": inset / s}}
        if touch:
            j = jump_rect(gw, gh)
            env["Jump"] = {k: v / s for k, v in j.items()}
        sheet = touch or ph < SMALL_PC_PX  # HudLayout SMALL_PC: short desktop windows use the phone sheet
        out.append({"Name": name, "Base": name, "Pouch": False, "Touch": touch, "Sheet": sheet,
                    "Ref": ref, "Supported": supported, "PxW": gw, "PxH": gh, "Env": env})
    return out


def exceptions_table() -> list[dict]:
    return [{"Screen": screen, "Check": check, "Reason": reason} for screen, check, reason in EXCEPTIONS]


def to_lua(value) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(float(value)) if isinstance(value, float) else str(value)
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(value, list):
        return "{" + ", ".join(to_lua(v) for v in value) + "}"
    if isinstance(value, dict):
        parts = []
        for k, v in value.items():
            key = k if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", k) else f"[{to_lua(k)}]"
            parts.append(f"{key} = {to_lua(v)}")
        return "{" + ", ".join(parts) + "}"
    raise TypeError(type(value))


def lua_long(text: str) -> str:
    eq = "===="
    while f"]{eq}]" in text:
        eq += "="
    return f"[{eq}[{text}]{eq}]"


def sheet_table() -> dict:
    data = json.loads(SHEET.read_text(encoding="utf-8"))
    items = [{"Id": it["id"], "Round": it.get("shape") == "round", "Pc": it["pc"], "Phone": it["phone"]} for it in data["items"]]
    zones = [{"Name": z["name_ko"], "Pc": z["pc"], "Phone": z["phone"]} for z in data["reserved_zones"]]
    return {"Items": items, "Zones": zones}


def make_harness(layout_source: str, sheet: dict, screens: list[dict]) -> str:
    head = (f"local HUDLAYOUT_SOURCE = {lua_long(layout_source)}\n"
            f"local V2 = {to_lua(sheet)}\n"
            f"local CASES = {to_lua(screens)}\n"
            f"local EXCEPTIONS = {to_lua(exceptions_table())}\n")
    return head + FIXTURE.read_text(encoding="utf-8")


def run_harness(binary: Path, text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=300)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("HUD_LAYOUT_RESULT_JSON "):
            result = json.loads(line[len("HUD_LAYOUT_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


GROUP_COLOUR = {
    "portrait": (240, 200, 80), "hp_bar": (220, 70, 70), "mp_bar": (70, 110, 230), "power_line": (240, 200, 80),
    "xp_bar": (90, 190, 240), "minimap": (90, 170, 110), "war_meter": (200, 160, 240),
    "chips": (170, 170, 190), "event": (250, 160, 60), "notify": (230, 230, 230), "tiles": (240, 170, 90),
    "quest": (250, 220, 150), "combo": (255, 255, 255),
    "potions": (230, 90, 120), "ghost": (160, 160, 255), "q": (110, 190, 255), "z": (110, 190, 255), "x": (110, 190, 255),
    "auto": (255, 215, 0), "attack": (230, 80, 50), "menu": (255, 140, 200), "fold": (255, 140, 200),
}
ROUND = {"portrait", "ghost", "q", "z", "x", "auto", "attack", "minimap"}


def draw(result: dict) -> bool:
    """One sheet with every screen drawn at real px (scaled to fit): grey = top bar, dark red = jump button."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return False
    screens = list(result.get("Cases", {}).items())
    if not screens:
        return False
    cell_w, cols = 520, 4
    rows = (len(screens) + cols - 1) // cols
    cells = []
    for name, case in screens:
        pw, ph = case["Px"]
        k = cell_w / max(pw, 1)
        cells.append((name, case, k, int(ph * k) + 22))
    row_h = [max(c[3] for c in cells[r * cols:(r + 1) * cols]) for r in range(rows)]
    img = Image.new("RGB", (cols * (cell_w + 12) + 12, sum(row_h) + 12 * (rows + 1)), (24, 26, 34))
    d = ImageDraw.Draw(img)
    y0 = 12
    for r in range(rows):
        x0 = 12
        for name, case, k, _ in cells[r * cols:(r + 1) * cols]:
            pw, ph = case["Px"]
            s = case["Scale"]
            d.text((x0, y0), f"{name}  UIScale {s:.3f}", fill=(230, 230, 230))
            oy = y0 + 18
            d.rectangle([x0, oy, x0 + pw * k, oy + ph * k], fill=(54, 70, 62), outline=(120, 120, 120))
            d.rectangle([x0, oy, x0 + pw * k, oy + case["Top"] * s * k], fill=(70, 70, 76))
            bar = case.get("Bar")
            if bar:  # Roblox's own buttons (left of the bar's free part)
                d.rectangle([x0, oy + bar["Y0"] * s * k, x0 + bar["X0"] * s * k, oy + bar["Y1"] * s * k], fill=(40, 40, 44))
            if case.get("Touch"):
                d.rectangle([x0, oy + ph / 3 * k, x0 + 0.4 * pw * k, oy + ph * k], outline=(110, 110, 110))
            jump = case.get("Jump")
            if jump:
                d.ellipse([x0 + jump["X"] * s * k, oy + jump["Y"] * s * k, x0 + (jump["X"] + jump["W"]) * s * k,
                           oy + (jump["Y"] + jump["H"]) * s * k], outline=(160, 40, 40), width=2)
            for rid, rr in case["Rects"].items():
                box = [x0 + rr["X"] * s * k, oy + rr["Y"] * s * k, x0 + (rr["X"] + rr["W"]) * s * k,
                       oy + (rr["Y"] + rr["H"]) * s * k]
                colour = GROUP_COLOUR.get(rid, (200, 200, 200))
                if rid in ROUND:
                    d.ellipse(box, outline=colour, width=2)
                elif rid == "tiles" and rr.get("Size"):
                    # the tiles that fit (Count squares of Size, Gap apart) from the row's left edge
                    t = rr["Size"] * s * k
                    gp = rr.get("Gap", 0) * s * k
                    for i in range(int(rr.get("Count", 0))):
                        tx = box[0] + i * (t + gp)
                        d.rectangle([tx, box[1], tx + t, box[1] + t], outline=colour, width=1)
                elif rid == "fold" and rr.get("Size"):
                    # the fold-out squares ([메뉴] tiles): every line right-aligned one gap left of [메뉴]
                    t = rr["Size"] * s * k
                    gp = rr.get("Gap", 0) * s * k
                    for ln in rr.get("Lines") or []:
                        for col in range(int(ln["Cols"])):
                            tx = x0 + ln["X"] * s * k + col * (t + gp)
                            ty = oy + ln["Y"] * s * k
                            d.rectangle([tx, ty, tx + t, ty + t], outline=(150, 90, 130), width=1)
                elif rid == "potions" and rr.get("Gap"):
                    # the two cells (HP, MP) side by side, Gap apart
                    cell = (rr["W"] - rr["Gap"]) / 2 * s * k
                    d.rectangle([box[0], box[1], box[0] + cell, box[3]], outline=colour, width=1)
                    d.rectangle([box[2] - cell, box[1], box[2], box[3]], outline=colour, width=1)
                else:
                    d.rectangle(box, outline=colour, width=1)
            x0 += cell_w + 12
        y0 += row_h[r] + 12
    PNG.parent.mkdir(parents=True, exist_ok=True)
    img.save(PNG)
    return True


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    parser.add_argument("--no-mutations", action="store_true")
    args = parser.parse_args()
    binary = args.luau.resolve()
    compiler = binary.with_name("luau-compile" + binary.suffix)
    if not binary.is_file() or not compiler.is_file():
        print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
        return 1
    raw = {p: p.read_bytes() for p in (LAYOUT, FIXTURE, SHEET, CONFIG)}
    source = raw[LAYOUT].decode("utf-8-sig").replace("\r\n", "\n")
    ui = config_ui()
    screens = cases(ui)
    sheet = sheet_table()

    compiled = subprocess.run([str(compiler), str(LAYOUT), str(FIXTURE)], cwd=ROOT, stdout=subprocess.DEVNULL,
                              stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace", timeout=120)
    mutations = []
    with tempfile.TemporaryDirectory(prefix="hud_layout_") as tmp:
        tmpdir = Path(tmp)
        real_run = run_harness(binary, make_harness(source, sheet, screens), tmpdir, "hud_layout_real.luau")
        baseline = failing_keys(real_run["result"])
        if not args.no_mutations:
            jobs = []
            for name, old, new in MUTATIONS:
                hits = source.count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "applied": False, "caught": False,
                                      "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                jobs.append((name, make_harness(source.replace(old, new, 1), sheet, screens)))

            def work(index_job):
                index, (name, text) = index_job
                run = run_harness(binary, text, tmpdir, f"hud_layout_mutant_{index:02d}.luau")
                new_fail = sorted(failing_keys(run["result"]) - baseline)
                crashed = run["result"] is None
                return {"mutation": name, "applied": True, "caught": crashed or bool(new_fail), "crashed": crashed,
                        "newFailingChecks": new_fail[:6], "newFailingCount": len(new_fail)}

            with ThreadPoolExecutor(max_workers=6) as pool:
                mutations.extend(pool.map(work, enumerate(jobs)))

    changed = [p.relative_to(ROOT).as_posix() for p, b in raw.items() if p.read_bytes() != b]
    result = real_run["result"] or {}
    named = result.get("Named", [])
    failing = [n for n in named if n.get("Fail", 0) > 0]
    real_ok = (real_run["result"] is not None and not failing
               and re.search(r"HUD_LAYOUT_OFFLINE_OK checks=(\d+) Studio/API calls=0", real_run["stdout"]) is not None)
    caught = sum(1 for m in mutations if m.get("caught"))
    applied = sum(1 for m in mutations if m.get("applied"))
    mutations_ok = all(m.get("applied") and m.get("caught") for m in mutations)
    if compiled.returncode == 0 and real_ok and not changed and mutations_ok:
        status = "passed-no-mutations" if args.no_mutations else "passed"
    else:
        status = "failed"
    drawn = draw(result) if real_run["result"] else False
    min_gaps = {name: c.get("MinGap") for name, c in result.get("Cases", {}).items()}
    press_gaps = {name: c.get("MinPressGap") for name, c in result.get("Cases", {}).items()}
    exceptions = [{"screen": e["Screen"], "check": e["Check"], "reason": e["Reason"],
                   "measuredDu": round(e["Measured"], 2), "neededDu": e["Need"]} for e in result.get("Exceptions", [])]
    report = {
        "status": status,
        "mutationsSkipped": args.no_mutations,
        "checks": result.get("Checks", 0),
        "failedChecks": result.get("Failed", 0),
        "namedChecks": len(named),
        "namedChecksFailing": len(failing),
        "failing": [{"group": n["Group"], "check": n["Name"], "failures": n["Fail"], "firstFailure": n.get("FirstFailure")}
                    for n in failing],
        "exceptions": exceptions,
        "screens": [{"name": c["Name"], "touch": c["Touch"], "reference": c["Ref"], "supported": c["Supported"],
                     "pouchLine": c["Pouch"], "mainGuiPx": [c["PxW"], c["PxH"]], "uiScale": round(c["Env"]["Scale"], 4),
                     "logical": [round(c["Env"]["W"], 2), round(c["Env"]["H"], 2)], "insetPx": c["Env"]["Inset"],
                     "jumpLogical": c["Env"].get("Jump"), "minGap": min_gaps.get(c["Name"]),
                     "minPressableGap": press_gaps.get(c["Name"])} for c in screens],
        "uiScaleConfig": ui,
        "mutations": {"total": len(MUTATIONS), "applied": applied, "caught": caught, "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if real_run["result"] else (real_run["stderr"].strip() or real_run["stdout"].strip())[-2000:],
        "drawing": PNG.relative_to(ROOT).as_posix() if drawn else None,
        "rects": {name: c.get("Rects") for name, c in result.get("Cases", {}).items()},
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(b).hexdigest() for p, b in raw.items()},
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "contract": "SPEC A23-26 HUD v2 via HudLayout.Compute(env) -> { [id] = {X,Y,W,H} } in MainGui logical units: "
                    "items keep their approved distance to their edge (TL / TC / TR / BC; BR to the PC corner or the live "
                    "touch jump button), top rows follow the real top-bar inset, narrow phone safe areas shrink the whole "
                    "layout, touch targets >= 60du (the rail re-spaces so grown buttons never touch; both potion cells, "
                    "the potions rect growing up and then left up to the thumbstick zone, Gap published as out.potions.Gap), "
                    "pressable items >= 2du apart, the touch quest board >= 48du tall, env.PouchLine adds pouch_line under "
                    "the XP bar and moves only the minimap, one centre column "
                    "(meter, chip row with zone / luck / status chips, notify) between the left and right blocks with >= 240du for the meter, "
                    "everything on screen below the top bar; the reference screens match the approved sheet within 1 px.",
        "limitations": "Pure-function check only: no Roblox engine, so text fit, art, real GuiInset / safe insets, the real "
                       "TouchGui (assumed to share MainGui's safe area), chat window size and the PlayerList are estimates. "
                       "Studio captures at 1280x720 / 749x361 / 844x390 are separate evidence.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    shown = 0
    for line in real_run["stdout"].splitlines():
        if line.startswith("HUD_LAYOUT_OFFLINE"):
            print(line)
        elif line.startswith("CHECK_FAIL") and shown < 60:
            shown += 1
            print(line)
    if not real_run["result"]:
        print(real_run["stderr"], end="")
    for name, gap in min_gaps.items():
        if gap:
            press = press_gaps.get(name) or {}
            print(f"MIN_GAP {name}: {gap['Gap']:.2f}du ({gap['Pair']}); pressable {press.get('Gap', 0):.2f}du "
                  f"({press.get('Pair', '')})")
    for e in exceptions:
        print(f"EXCEPTION {e['screen']} :: {e['check']}: {e['measuredDu']}du < {e['neededDu']}du")
    for m in mutations:
        print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
              + ("" if m.get("applied") else f" ({m.get('note')})"))
    if mutations:
        print(f"MUTATIONS caught={caught}/{applied} (of {len(MUTATIONS)})")
    if args.no_mutations:
        print("MUTATIONS SKIPPED")
    if changed:
        print(f"SOURCES CHANGED DURING RUN: {changed}")
    print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
          f"assertions {result.get('Checks', 0) - result.get('Failed', 0)}/{result.get('Checks', 0)}")
    print(f"Status: {status}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}" + (f" (+ {PNG.relative_to(ROOT).as_posix()})" if drawn else ""))
    return 0 if status in ("passed", "passed-no-mutations") else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"HUD layout offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
