"""세세한 게임성 묶음 1 (최종 검수 10/18, docs/review/detail_audit_2026-10-17.md, user A23-230 "아주 세세한 것 까지도"):
#1 a press within 0.25 s of the swing being ready is kept once and swings when ready (HUD.SwingPlan + Fx.SwingReadyIn);
#8 a potion press that cannot work (cooldown, full, none ...) shakes its slot with the Deny sound (VitalsUI.Request ->
sent / why, QuickSlots.Refuse = UIKit.Refuse); #9 an empty slot's key opens the bag like its button when I hold a
potion (QuickSlots.EmptyOpens); #6 the moment HP first goes under 30%: one heart sound + the potion slot shines, once
per 20 s (MOTION.LowWarnDue / LowWarnStep, the edge throb was already there); #13 the coin only for a kill that paid
gold (Fx.rewardNow and Audio's ComboCoin), the kill pop always; #14 no coin on an enhance success (Audio's
ScrollSuccess / ScrollFail only).
The pure functions run in the official Luau CLI cut out of their files; the wiring is checked as source. Mutations: each
must be caught.
Usage: py tools/test_detail_batch1.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"HUD": SPS / "HUD.luau", "FX": SPS / "Fx.luau", "QS": SPS / "QuickSlots.luau", "VIT": SPS / "VitalsUI.luau",
         "AUDIO": SPS / "Audio.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"


def cut(src: str, start: str, end: str = "\nend\n") -> str:
    i = src.index(start)
    return src[i:src.index(end, i) + len(end)]


def lua_run(src: dict[str, str]) -> tuple[bool, str]:
    hud = src["HUD"]
    fx = src["FX"]
    qs = src["QS"]
    code = "local L, HUD, MOTION, QuickSlots = {}, {}, {}, {}\n"
    code += re.search(r"L\.SwingBuffer = \{[^\n]*\}\n", hud).group(0)
    code += cut(hud, "function HUD.SwingPlan(")
    code += re.search(r"MOTION\.LowWarn = \{[^\n]*\}\n", fx).group(0)
    code += cut(fx, "function MOTION.LowWarnDue(")
    code += cut(qs, "function QuickSlots.EmptyOpens(")
    code += r'''
local checks, failed = 0, 0
local function check(ok, name, d) checks += 1 if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(d)) end end
check(HUD.SwingPlan(0, false) == "fire", "#1 ready: swing now")
check(HUD.SwingPlan(0.2, false) == "queue", "#1 0.2 s early: kept once")
check(HUD.SwingPlan(0.2, true) == "skip", "#1 one kept already: no second (one press = one swing)")
check(HUD.SwingPlan(0.6, false) == "fire", "#1 far too early: as before (the server's own answer)")
check(HUD.SwingPlan(0.25, false) == "queue" and HUD.SwingPlan(0.26, false) == "fire", "#1 the window is 0.25 s")
check(MOTION.LowWarnDue(false, true, 100, -math.huge) == true, "#6 just went under 30%: warn")
check(MOTION.LowWarnDue(true, true, 100, -math.huge) == false, "#6 still low: once per fall")
check(MOTION.LowWarnDue(false, true, 110, 100) == false and MOTION.LowWarnDue(false, true, 121, 100) == true,
	"#6 at most once per 20 s")
check(MOTION.LowWarnDue(false, false, 100, -math.huge) == false, "#6 not low: nothing")
check(QuickSlots.EmptyOpens(true, 0) == true, "#9 an empty slot's button opens the bag")
check(QuickSlots.EmptyOpens(nil, 0) == false and QuickSlots.EmptyOpens(nil, 2) == true,
	"#9 its key opens it too when I hold a potion (none = nothing)")
print(("BATCH_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as fh:
        fh.write(code)
        path = fh.name
    r = subprocess.run([str(BINARY), path], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    out = r.stdout + r.stderr
    m = re.search(r"BATCH_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (r.returncode == 0 and m is not None and m.group(2) == "0"), out


STATIC = [
    ("#1 the swing press asks the plan first and keeps one press until ready", "HUD", [
        "\tlocal plan = HUD.SwingPlan(wait, L.SwingBuffer.Queued)\n\tif plan == \"skip\" then return false end",
        "\t\ttask.delay(wait + L.SwingBuffer.Margin, function()\n\t\t\tL.SwingBuffer.Queued = false\n\t\t\tif not inputAllowed() then return end\n\t\t\tL.SwingFaced()",
        "function L.SwingFaced()\n\tif not L.SwingGate() then return end\n"]),
    ("#1 Fx tells how long until the next swing (PredictSwing's own interval)", "FX", [
        "return math.max(0, asNum(prof.SwingInterval, 1) - P.Gap - (os.clock() - P.LastSwing))"]),
    ("#8 VitalsUI.Request says whether the drink went out", "VIT", ["\treturn requestPotion(kind)\n", "\t\treturn false, label\n"]),
    ("#8 a refused potion press shakes the slot (key and button)", "QS", [
        "\t\t\tif ok and sent == false then QuickSlots.Refuse(i) end", "return pcall(kit.Refuse, w.Button)"]),
    ("#9 an empty slot: the key opens the bag when I hold a potion", "QS", [
        "local panels = QuickSlots.EmptyOpens(button, potions) and C and C.Panels"]),
    ("#6 the low-HP warning runs every frame: heart sound + the potion slot shines", "FX", [
        "local okL, errL = pcall(MOTION.LowWarnStep)", "\tFx.PlaySound(\"LowHeart\")\n", "if type(qs) == \"table\" and type(qs.Glow) == \"function\" then pcall(qs.Glow) end"]),
    ("#13 the coin only for a kill that paid gold (Fx and Audio)", "FX", ["\tif asNum(data.Gold, 0) > 0 then Fx.PlaySound(\"Coin\") end"]),
    ("#13 Audio: ComboCoin only with gold, the kill pop always", "AUDIO", [
        "\t\tadd(out, \"KillPop\", 0)\n", "if num(data.Gold, 0) > 0 then add(out, \"ComboCoin\""]),
]

MUTATIONS = [
    ("HUD", "#1 no keeping (the early press lost again)", "\tif wait <= 0 or wait > L.SwingBuffer.Window then return \"fire\" end", "\tdo return \"fire\" end"),
    ("HUD", "#1 a second kept press", "\treturn queued and \"skip\" or \"queue\"", "\treturn \"queue\""),
    ("FX", "#6 warns every frame", "return low == true and wasLow ~= true and", "return low == true and"),
    ("FX", "#6 no 20 s gap", "(tonumber(lastAt) or -math.huge) >= MOTION.LowWarn.Gap", "(tonumber(lastAt) or -math.huge) >= 0"),
    ("QS", "#9 the key never opens the bag", "\treturn button == true or (tonumber(potions) or 0) > 0", "\treturn button == true"),
    ("QS", "#8 no shake", "\t\t\tif ok and sent == false then QuickSlots.Refuse(i) end", "\t\t\tlocal _ = 0"),
    ("FX", "#13 the coin on every kill again", "\tif asNum(data.Gold, 0) > 0 then Fx.PlaySound(\"Coin\") end", "\tFx.PlaySound(\"Coin\")"),
]


def statics(src):
    return [(n, all(x in src[k] for x in needles)) for n, k, needles in STATIC]


def main() -> int:
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    ok, out = lua_run(src)
    for line in out.splitlines():
        if line.startswith(("CHECK_", "BATCH_")) or "error" in line.lower():
            print(line)
    st = statics(src)
    for n, g in st:
        print(("STATIC_OK " if g else "STATIC_FAIL ") + n)
    caught = 0
    for k, name, old, new in MUTATIONS:
        if src[k].count(old) != 1:
            print(f"MUTATION MISSED {name} (matched {src[k].count(old)})")
            continue
        mut = dict(src)
        mut[k] = src[k].replace(old, new)
        try:
            bad = not lua_run(mut)[0] or not all(g for _, g in statics(mut))
        except Exception:  # noqa: BLE001 - a mutation that breaks the cut = caught
            bad = True
        caught += 1 if bad else 0
        print(("MUTATION caught  " if bad else "MUTATION MISSED ") + name)
    passed = ok and all(g for _, g in st) and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (statics {sum(g for _, g in st)}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
