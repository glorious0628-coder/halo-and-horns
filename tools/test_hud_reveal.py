"""HUD "show it when it is needed" check (검수 2026-10-09, UI clutter review ③④; looks = 이미지 개발, when = 개발 1).

Runs, in the official Luau CLI (build/luau_cli_0_741), the CURRENT pure parts cut out of the sources:
  * Config.HudReveal.Shows - the potion pair once a potion is held, HP under half once, or from Lv5; the pouch once gold
    is carried, or from Lv5;
  * HUD.ChipFoldSig - what counts as a change of the status chips (the set without In Combat, the zone kind, the luck
    words).
Static: the chips start closed (1안 ②, 10/14), a change does not open them, a press shows them TapSeconds (5); the Lucky chip
says the bonus over the base rare chance and hides without one ("Lucky +%s%%"), a press says what it means; VitalsUI
shows the potion row by Config.HudReveal and keeps it; HUD's pouch line too. Mutations: in-memory copies with one rule
broken each; each must be caught.

Usage: py tools/test_hud_reveal.py
Report: docs/art/verification_2026-10-09/offline_hud_reveal_2026-10-09.json
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
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau", "HUD": SPS / "HUD.luau",
         "EVENT": SPS / "EventHUD.luau", "VITALS": SPS / "VitalsUI.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_hud_reveal_2026-10-09.json"

STATIC = [
    # 최종 검수 10/14 상단 HUD 1안 ②: the row starts closed (danger words, the Safe Zone icon, one buff icon, '+N'), a
    # change no longer opens it by itself, a press opens it TapSeconds (5) and it closes again
    ("chips: closed by default, a change does not open them, a press shows them 5 s", "HUD", [
        "L.ChipFold.Auto, L.ChipFold.ShowSeconds, L.ChipFold.TapSeconds, L.ChipFold.Token = true, 3, 5, 0\n",
        "L.ChipFold = { Folded = true, OnTap = nil, MaxIcons = 3 }", "\tL.ChipFold.Sig = sig\nend\n",
        "\t\tif cf.Token == token and cf.Auto then HUD.SetChipsFolded(true) end -- a photo preview (Auto off) stays\n",
        "\tL.FoldLater(L.ChipFold.TapSeconds)\n", "L.ChipFold.OnTap = L.ChipFoldTap",
        '\tL.WatchChipFold(L.ChipFoldSig(wantKey, attr("ZoneTown", false) == true, attr("ZonePvP", false) == true, luck))\n']),
    ("Lucky chip words (Config.ClientText.EventHUD, 10/14)", "CONFIG", ['\tLuckShort = "Lucky +%s%%",\n']),
    ("Lucky chip: the bonus only, hidden without one; a press explains", "EVENT", [
        "\t\treturn Config.RareChance(events) - ((Config.Luck and Config.Luck.BaseRare) or 0)\n",
        "\tif not ok or type(bonus) ~= \"number\" or bonus <= 1e-9 then return nil end -- no bonus today: no chip\n"]),
    ("Lucky chip press (the row open): one toast", "HUD", [
        "\tif key == \"Luck\" then\n\t\tpcall(UIKit.Toast, TXT.LuckTap, \"info\")\n"]),
    ("Lucky chip press: its words (Config.ClientText.HUD)", "CONFIG", ['\tLuckTap = "Rare drops come a bit more often today!",']),
    ("potion row: Config.HudReveal, kept once shown, Level watched", "VITALS", [
        "\tif ui.Row and not ui.PotionSeen then\n", "\t\tui.PotionSeen = Config.HudReveal.Shows(\"Potions\",",
        "\t\tif ui.Row.Visible ~= ui.PotionSeen then ui.Row.Visible = ui.PotionSeen end\n", "\tLevel = true,"]),
    ("검수 10/09: the guide's floating name chip and its ground line are off (Config.Nudges GuideLabel / GuideBeam)", "HUD", [
        "\tif (Config.Nudges or {}).GuideLabel ~= false then\n\t\t-- 검수 2026-10-08",
        "\tif (Config.Nudges or {}).GuideBeam ~= false then\n\t\tlocal beam = Instance.new(\"Beam\")"]),
    ("Config.Nudges.GuideLabel = false, GuideBeam = false", "CONFIG", ["\tGuideLabel = false, --", "\tGuideBeam = false, --"]),
    ("pouch line: Config.HudReveal, kept once shown", "HUD", [
        '\tL.PouchOn = L.PouchOn or Config.HudReveal.Shows("Pouch", { Level = num("Level", 0), Carried = carried })\n',
        "\tlocal fits = L.PouchOn == true and need <="]),
]
MUTATIONS = [
    ("HUD", "the ground line is back", "\tif (Config.Nudges or {}).GuideBeam ~= false then\n", "\tif true then\n"),
    ("CONFIG", "GuideBeam switched on", "\tGuideBeam = false, --", "\tGuideBeam = true, --"),
    ("HUD", "the guide name chip is back", "\tif (Config.Nudges or {}).GuideLabel ~= false then\n\t\t-- 검수 2026-10-08",
     "\tif true then\n\t\t-- 검수 2026-10-08"),
    ("CONFIG", "GuideLabel switched on", "\tGuideLabel = false, --", "\tGuideLabel = true, --"),
    ("CONFIG", "potions from Lv1", "Config.HudReveal = { Level = 5, LowHP = 0.5,", "Config.HudReveal = { Level = 1, LowHP = 0.5,"),
    ("CONFIG", "potions hidden at the start again", "LowHP = 0.5, PotionsAlways = true }", "LowHP = 0.5, PotionsAlways = false }"),
    ("CONFIG", "low HP never counts", "or (maxHP > 0 and hp > 0 and hp < maxHP * Config.HudReveal.LowHP)", ""),
    ("CONFIG", "the pouch always shows", "\t\treturn (tonumber(s.Carried) or 0) > 0\n", "\t\treturn true\n"),
    ("HUD", "every fight unfolds the chips", '\tlocal keys = string.gsub(tostring(wantKey or ""), "Combat,", "")\n',
     '\tlocal keys = tostring(wantKey or "")\n'),
    ("HUD", "a zone change is no change", '(town and "T" or (pvp and "P" or "W"))', '"W"'),
    ("HUD", "never folds", "\t\tif cf.Token == token and cf.Auto then HUD.SetChipsFolded(true) end -- a photo preview (Auto off) stays\n", ""),
    ("HUD", "the row starts open", "L.ChipFold = { Folded = true, OnTap = nil, MaxIcons = 3 }", "L.ChipFold = { Folded = false, OnTap = nil, MaxIcons = 3 }"),
    ("EVENT", "the total chance again", "\t\treturn Config.RareChance(events) - ((Config.Luck and Config.Luck.BaseRare) or 0)\n",
     "\t\treturn Config.RareChance(events)\n"),
    ("VITALS", "the potion row hides again", "\tif ui.Row and not ui.PotionSeen then\n", "\tif ui.Row then\n"),
    ("HUD", "the pouch hides again", '\tL.PouchOn = L.PouchOn or Config.HudReveal.Shows(', '\tL.PouchOn = Config.HudReveal.Shows('),
]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local Config = {}
local HUD = {}
local L = {}
for _, src in { SHOWS_SOURCE, SIG_SOURCE } do
	local f = assert(loadstring(src, "=part"))
	setfenv(f, setmetatable({ Config = Config, HUD = HUD, L = L }, { __index = getfenv() }))
	f()
end
local S = Config.HudReveal.Shows
-- 검수 10/09 (user: "quick slots!"): the potion pair shows from the start
check("PotionsAlways: the potion row from the start (Lv1, nothing held)", Config.HudReveal.PotionsAlways == true
	and S("Potions", { Level = 1, Potions = 0, HP = 100, MaxHP = 100 }) == true and S("Potions", {}) == true)
check("PotionsAlways leaves the pouch rule alone", S("Pouch", { Level = 1, Carried = 0 }) == false)
Config.HudReveal.PotionsAlways = false -- the old rule below (kept for a switch back)
check("Lv1, no potion, full HP: no potion row", S("Potions", { Level = 1, Potions = 0, HP = 100, MaxHP = 100 }) == false)
check("a potion in the bag: the row", S("Potions", { Level = 1, Potions = 1, HP = 100, MaxHP = 100 }) == true)
check("HP under half: the row", S("Potions", { Level = 1, Potions = 0, HP = 40, MaxHP = 100 }) == true)
check("HP exactly half: not yet", S("Potions", { Level = 1, Potions = 0, HP = 50, MaxHP = 100 }) == false)
check("dead (HP 0) is not 'low'", S("Potions", { Level = 1, Potions = 0, HP = 0, MaxHP = 100 }) == false)
check("Lv5: the row", S("Potions", { Level = 5, Potions = 0, HP = 100, MaxHP = 100 }) == true)
check("not loaded (nil level): no row", S("Potions", {}) == false)
check("pouch: no gold, Lv1 -> hidden", S("Pouch", { Level = 1, Carried = 0 }) == false)
check("pouch: carried gold -> shown", S("Pouch", { Level = 1, Carried = 3 }) == true)
check("pouch: Lv5 -> shown", S("Pouch", { Level = 5, Carried = 0 }) == true)
local sig = HUD.ChipFoldSig
check("In Combat coming and going is no change", sig("Zone,Luck,Combat,", true, false, "Lucky +2%") == sig("Zone,Luck,", true, false, "Lucky +2%"))
check("a new chip is a change", sig("Zone,Luck,Rookie,", true, false, "x") ~= sig("Zone,Luck,", true, false, "x"))
check("town -> wild is a change", sig("Zone,", true, false, "x") ~= sig("Zone,", false, false, "x"))
check("wild -> PvP is a change", sig("Zone,", false, false, "x") ~= sig("Zone,", false, true, "x"))
check("new luck words are a change", sig("Luck,", false, false, "Lucky +2%") ~= sig("Luck,", false, false, "Lucky +4%"))
check("the same state is the same key", sig("Zone,", true, false, nil) == sig("Zone,", true, false, nil))
print(("HUD_REVEAL_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''


def cut(text: str, pattern: str, what: str) -> str:
    m = re.search(pattern, text, re.S)
    if not m:
        raise ValueError(what + " missing")
    return m.group(0)


def run(src: dict) -> tuple[int, int, str]:
    try:
        shows = cut(src["CONFIG"], r"Config\.HudReveal = \{[^\n]*\}\nfunction Config\.HudReveal\.Shows\(kind, s\)\n.*?\nend\n", "HudReveal")
        sig = cut(src["HUD"], r"function HUD\.ChipFoldSig\(wantKey, town, pvp, luck\)\n.*?\nend\n", "ChipFoldSig")
    except ValueError as e:
        return 0, 1, str(e)
    text = (f"local SHOWS_SOURCE = [==========[{shows}]==========]\nlocal SIG_SOURCE = [==========[{sig}]==========]\n"
            + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "hud_reveal.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"HUD_REVEAL_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    for name, key, needles in STATIC:
        ok = all(src[key].count(n) == 1 for n in needles)
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(STATIC), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
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
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
