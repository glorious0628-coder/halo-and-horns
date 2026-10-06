"""HUD layout v2 (SPEC A23-26) offline check: HudLayout.Compute on PC, phone and tablet screens.

Runs the CURRENT src/StarterPlayer/StarterPlayerScripts/HudLayout.luau, injected into tools/fixtures/hud_layout_offline.luau,
with the installed official Luau CLI (build/luau_cli_0_741). No Studio, network or Roblox API calls.

Screens: MainGui logical units are derived exactly like UIKit.applyScale (Config.UI ScaleMin / ScaleMax / DesktopScaleMult /
DesktopScaleMin / DesktopScaleMax, reference height 720) and the touch jump button like Roblox's TouchJump (70 px on
screens whose short side <= 500, else 120 px). The approved rects come from docs/design/hud_layout_v2_2026-10-06.json.

Checks (named, collected): every item on screen below the top bar; no two items overlap (circles as circles) on every
supported screen; touch targets >= 60 logical units; nothing pressable on the jump button, in the thumbstick zone
(x < 0.4W, y > H/3) or under the PC chat window; blocks stay at their edges; one centre column for the meter, the chip
row and notify, clear of the left / right blocks; the two reference screens reproduce the approved sheet within 1 px;
hiding the pet slot never moves the rail; HudLayout stays a pure module.

Mutations: in-memory copies of HudLayout with one rule broken each; each must make a check fail that passes on the
real source. --no-mutations skips them and the status is then "passed-no-mutations" (never "passed").

Usage: py tools/test_hud_layout.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/hud_layout_offline_2026-10-06.json (+ .png drawing of every screen)
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
SHEET = ROOT / "docs/design/hud_layout_v2_2026-10-06.json"
OUT = ROOT / "docs/art/verification_2026-10-06/hud_layout_offline_2026-10-06.json"
PNG = OUT.with_suffix(".png")

INSET = 58  # Roblox top bar (real px) on both reference screens of the approved sheet

# (name, touch, screen px w, h, reference screen, supported, top inset px, MainGui safe area px or None)
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
    # a very short window: overlaps are accepted there, but everything must stay on screen below the top bar
    ("pc_1280x240_short", False, 1280, 240, False, False, INSET, None),
    ("phone_749x361", True, 749, 361, True, True, INSET, None),
    ("phone_749x361_notch", True, 749, 361, False, True, INSET, (655, 340)),
    ("phone_844x390", True, 844, 390, False, True, INSET, None),
    ("phone_667x375", True, 667, 375, False, True, INSET, None),
    ("phone_568x320", True, 568, 320, False, True, INSET, None),
    ("tablet_1024x768", True, 1024, 768, False, True, INSET, None),
    ("tablet_1180x820", True, 1180, 820, False, True, INSET, None),
]

# (name, exact text, replacement) in HudLayout.luau: each must match exactly once
MUTATIONS = [
    ("touch targets may shrink to 30", "local MIN_TAP = 60", "local MIN_TAP = 30"),
    ("round touch buttons never grow back", "			if r.W < MIN_TAP then", "			if false then"),
    ("potions never grow back", "if pot.H < MIN_TAP then pot.Y, pot.H = pot.Y + pot.H - MIN_TAP, MIN_TAP end", ""),
    ("grown portrait covers the bars", "r.X, r.W = r.X + g, math.max(1, r.W - g)", "r.X, r.W = r.X, r.W"),
    ("rail spacing ignores the tap size", "local step = math.max(", "local step = math.min("),
    ("top-right items anchored to the left edge",
     "X, Y = W - (ref.W - x) * k, top + (y - ref.Inset) * k", "X, Y = x * k, top + (y - ref.Inset) * k"),
    ("top-left items ignore the real top bar",
     "X, Y = x * k, top + (y - ref.Inset) * k", "X, Y = x * k, y * k"),
    ("narrow phone safe area not shrunk",
     "k *= math.min(1, W / (ref.W / ref.Scale), H / (ref.H / ref.Scale))", "k *= 1"),
    ("centre column never narrows", "local w = math.max(math.min(r.W, room), math.min(MIN_CENTER, r.W))", "local w = r.W"),
    ("centre column touches its neighbours", "local GAP = 8", "local GAP = 0"),
    ("centre column ignores its room", "local cx = math.clamp(W / 2,", "local cx = (W / 2) or math.clamp(W / 2,"),
    ("touch cluster ignores the jump button", "elseif jump and rj then", "elseif false then"),
    ("cluster measured from the jump centre only", "if x >= rj[1] then", "if true then"),
    ("auto not kept above the jump button", "if y + r[4] <= rj[2] then", "if false then"),
    ("touch combo stays bottom-centre", 'if anchor == "BC" and jump then anchor = "BR" end', ""),
    ("luck pill drawn over the chips", "chips.X, chips.W = chips.X + lw + LUCK.Gap, chips.W - lw - LUCK.Gap", "local _ = lw"),
    ("desktop attack rect drifted", 'attack = { "BR", { 1144, 584, 120, 120 }', 'attack = { "BR", { 1144, 590, 120, 120 }'),
    ("phone skill Q rect drifted", "{ 455, 252, 72, 72 }", "{ 455, 262, 72, 72 }"),
    ("phone quest rect drifted", "{ 516, 116, 225, 36 }", "{ 516, 116, 245, 36 }"),
    ("everything may leave the screen", "r.Y = math.clamp(r.Y, top, math.max(top, H - r.H))", "r.Y = r.Y"),
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
    out = []
    for name, touch, pw, ph, ref, supported, inset, safe in SCREENS:
        s = ui_scale(touch, ph, ui)
        gw, gh = safe or (pw, ph)
        env = {"W": gw / s, "H": gh / s, "Scale": s, "Inset": inset, "Touch": touch}
        if touch:
            j = jump_rect(gw, gh)
            env["Jump"] = {k: v / s for k, v in j.items()}
        out.append({"Name": name, "Touch": touch, "Ref": ref, "Supported": supported, "PxW": gw, "PxH": gh, "Env": env})
    return out


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
            f"local CASES = {to_lua(screens)}\n")
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
    "xp_bar": (90, 190, 240), "minimap": (90, 170, 110), "war_meter": (200, 160, 240), "luck": (120, 200, 120),
    "chips": (170, 170, 190), "notify": (230, 230, 230), "pet": (240, 170, 90), "bag": (240, 170, 90),
    "map": (240, 170, 90), "menu": (240, 170, 90), "quest": (250, 220, 150), "combo": (255, 255, 255),
    "potions": (230, 90, 120), "ghost": (160, 160, 255), "q": (110, 190, 255), "z": (110, 190, 255),
    "auto": (255, 215, 0), "attack": (230, 80, 50),
}
ROUND = {"portrait", "ghost", "q", "z", "auto", "attack"}


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
    report = {
        "status": status,
        "mutationsSkipped": args.no_mutations,
        "checks": result.get("Checks", 0),
        "failedChecks": result.get("Failed", 0),
        "namedChecks": len(named),
        "namedChecksFailing": len(failing),
        "failing": [{"group": n["Group"], "check": n["Name"], "failures": n["Fail"], "firstFailure": n.get("FirstFailure")}
                    for n in failing],
        "screens": [{"name": c["Name"], "touch": c["Touch"], "reference": c["Ref"], "supported": c["Supported"],
                     "mainGuiPx": [c["PxW"], c["PxH"]], "uiScale": round(c["Env"]["Scale"], 4),
                     "logical": [round(c["Env"]["W"], 2), round(c["Env"]["H"], 2)], "insetPx": c["Env"]["Inset"],
                     "jumpLogical": c["Env"].get("Jump"), "minGap": min_gaps.get(c["Name"])} for c in screens],
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
                    "layout, touch targets >= 60du (the rail re-spaces so grown buttons never touch), one centre column "
                    "(meter, luck + chips row, notify) between the left and right blocks with >= 240du for the meter, "
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
            print(f"MIN_GAP {name}: {gap['Gap']:.2f}du ({gap['Pair']})")
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
