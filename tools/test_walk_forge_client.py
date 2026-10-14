"""A23-88 client part (게임성 개발 3's contract docs/design/walk_to_forge_server_2026-10-09.md; 검수 10/09: no ground
line, no words - Config.Nudges GuideBeam / GuideLabel are off).

Runs, in the official Luau CLI, the CURRENT HUD.PadGlowOn / HUD.TravelPulse (cut out of HUD.luau): after the first
weapon (TutorialStep Guide = 1) the meadow travel pad glows while I am in the Crossroads, and [Menu] + its Travel square
pulse until I open Travel once; neither at the Forge step (3), in the meadow step (2), after the mission (99) or with
its Config.Nudges switch off. Static: the Forge step's target stays the anvil (QuestTarget), the pad glow is a soft
local Highlight on the pad (no Beam, no BillboardGui), refreshGuides drives it, a press on the Travel square ends the
pulse, the switches are in Config. Mutations: each must be caught.

Usage: py tools/test_walk_forge_client.py
Report: docs/art/verification_2026-10-09/offline_walk_forge_client_2026-10-09.json
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
FILES = {"HUD": SPS / "HUD.luau", "QT": SPS / "QuestTarget.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "WM": SPS / "WorldMap.luau", "MM": SPS / "MiniMap.luau", "QM": SPS / "QuestMarker.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_walk_forge_client_2026-10-09.json"

STATIC = [
    ("the Forge step points at the anvil (QuestTarget)", "QT",
     ['\tif step == K.ForgeStep then\n\t\treturn pack(smithFrom(myZone, pos), "blacksmith", TXT.Blacksmith, K.Town, not smithWalk(myZone))\n']),
    ("refreshGuides drives the pad glow", "HUD",
     ['\tL.PadGlow(HUD.PadGlowOn(step, zone, (Config.Nudges or {}).PadGlow), zone)\n',
      '\tlocal pad = on and L.PadIn(zone or "Crossroads") or nil\n',
      '\tlocal ok, pad = pcall(qt.TownPad, zone, TUT_GUIDE_ZONE)\n']),
    ("the pad glow is a soft local Highlight on the meadow pad (no line, no words)", "HUD",
     ['\tlocal h = Instance.new("Highlight")\n', '\th.Adornee = pad\n', '\th.FillTransparency = 0.85\n',
      'pads:FindFirstChild("Pad_" .. TUT_GUIDE_ZONE)']),
    ("[Menu] + Travel pulse with the rule; a press on Travel ends it", "HUD",
     ['\tL.SetGlow("menu", ui.menuGlow, settings or travel or attend)\n', '\tL.SetGlow("travel", ui.travelGlow, travel)\n',
      '\t\t\tif copy.Id == "Travel" then L.TravelSeen = true end -- A23-88: the Travel pulse is done\n',
      '\t\tif def.Id == "Travel" and not row then ui.travelGlow = makeGlow(b, UDim.new(0, 10)) end -- A23-88\n']),
    # 빛 마을 점검 #52 (2026-10-10): the town plazas' own pads on the big map and the minimap (the pad glyph)
    ("the big map marks the town pads (TravelTo outside the Crossroads) with the pad glyph", "WM",
     ['\t\tif zone and zone.Id ~= "Crossroads" then landmark("TownPad" .. i, GLYPH.Pad, COL.Pad, part.Position, nil, 15) end\n']),
    ("the minimap marks the town pads too, upright, at most MaxPads", "MM",
     ['\t\tif zone and zone.Id ~= "Crossroads" and used < T.MaxPads then\n',
      '\t\t\t\tmark = textMark("TownPad" .. used, TXT.Pad, T.PadGlyph, COL.Pad, 6, ui.canvas)\n',
      '\t\t\t\tif S.upright then table.insert(S.upright, mark) end\n', '\ttownPads()\n']),
    # 검수 10/10 (7b5fbf42 / a2c1512a review)
    ("Reduced Motion: a row tap turns the marker gold for FlashTime s (no tween)", "QM",
     ['\tif UIKit.ReducedMotion() then\n\t\tfor _, e in tinted do e[1][e[2]] = COL.Flash end\n',
      '\tFlashTime = 0.3,', '\t\t\tlocal back = S.claim and COL.Claim or COL.Go\n']),
    ("the HUD row tap goes straight to a landmark a walk away (no Travel window)", "HUD",
     ['\tlocal walkTo = spot ~= nil and L.ForgeWalk[zone] == true and L.ForgeWalk[target] == true\n',
      '\tif Config.Zones[target] and zone ~= target and not walkTo then\n']),
    ("빛 마을 점검 #1 / #30: a talk row through a town NPC guides to her when far, opens near", "HUD",
     ['\t\tlocal npc = type(st.Npc) == "string" and type(qt) == "table" and type(qt.StoryNpc) == "function" and qt.StoryNpc(st.Npc) or nil\n',
      '\t\tif npc and root and Util.FlatDistance(root.Position, npc.Position) > (tonumber(Config.StoryQuests.NpcRange) or 16) then\n']),
    ("the maps mark BasePart pads only", "MM",
     ['\t\tlocal part = p:IsA("BasePart") and p or nil -- 검수 10/10: BaseParts only (ZoneService connects only those)\n']),
    ("Config: no ground line / name chip, pad glow and Travel pulse on", "CONFIG",
     ["\tGuideBeam = false, --", "\tGuideLabel = false, --", "\tPadGlow = true,\n", "\tTravelPulse = true,\n"]),
]
MUTATIONS = [
    ("HUD", "the pad glows in every zone",
     '\treturn on ~= false and step == TUT_GUIDE_STEP and (zone == "Crossroads" or zone == "HaloTown" or zone == "HornsTown")\n',
     "\treturn on ~= false and step == TUT_GUIDE_STEP\n"),
    ("HUD", "the pad glows at the Forge step", '\treturn on ~= false and step == TUT_GUIDE_STEP and (zone == "Crossroads"',
     '\treturn on ~= false and (step == TUT_GUIDE_STEP or step == 3) and (zone == "Crossroads"'),
    # 빛 마을 점검 #52 (2026-10-10): the towns' own meadow pads glow too (L.PadIn finds them)
    ("HUD", "the town pads never glow",
     'step == TUT_GUIDE_STEP and (zone == "Crossroads" or zone == "HaloTown" or zone == "HornsTown")\n',
     'step == TUT_GUIDE_STEP and zone == "Crossroads"\n'),
    ("HUD", "the town glow takes the Crossroads pad", "\tlocal pad = on and L.PadIn(zone or \"Crossroads\") or nil\n",
     "\tlocal pad = on and L.PadIn(\"Crossroads\") or nil\n"),
    ("HUD", "the Travel pulse never ends", "\treturn on ~= false and seen ~= true and step == TUT_GUIDE_STEP\n",
     "\treturn on ~= false and step == TUT_GUIDE_STEP\n"),
    ("HUD", "the switch ignored", "\treturn on ~= false and seen ~= true and step == TUT_GUIDE_STEP\n",
     "\treturn seen ~= true and step == TUT_GUIDE_STEP\n"),
    ("HUD", "a press on Travel does not end it", '\t\t\tif copy.Id == "Travel" then L.TravelSeen = true end -- A23-88: the Travel pulse is done\n', ""),
    ("CONFIG", "the ground line is back", "\tGuideBeam = false, --", "\tGuideBeam = true, --"),
]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local HUD = {}
for _, src in { PAD_SOURCE, PULSE_SOURCE } do
	local f = assert(loadstring(src, "=part"))
	setfenv(f, setmetatable({ HUD = HUD, TUT_GUIDE_STEP = 1 }, { __index = getfenv() }))
	f()
end
local P, T = HUD.PadGlowOn, HUD.TravelPulse
check("after the first weapon, in the Crossroads: the pad glows", P(1, "Crossroads", true) == true)
check("default switch (nil) counts as on", P(1, "Crossroads", nil) == true)
check("빛 마을 점검 #52: in my home town its own meadow pad may glow (none placed = nothing to light)",
	P(1, "HaloTown", true) == true and P(1, "HornsTown", true) == true)
check("... never in the meadow or the woods", P(1, "SlimeMeadow", true) == false and P(1, "GoblinWoods", true) == false)
check("the Forge step (3): no pad glow", P(3, "Crossroads", true) == false)
check("hunting (2) / done (99): no pad glow", P(2, "Crossroads", true) == false and P(99, "Crossroads", true) == false)
check("switch off: no pad glow", P(1, "Crossroads", false) == false)
check("after the first weapon: Travel pulses", T(1, nil, true) == true)
check("Travel opened once: no more pulse", T(1, true, true) == false)
check("other steps: no Travel pulse", T(3, nil, true) == false and T(2, nil, true) == false and T(99, nil, true) == false)
check("switch off: no Travel pulse", T(1, nil, false) == false)
print(("WALK_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''


def run(src: dict) -> tuple[int, int, str]:
    hud = src["HUD"]
    pad = re.search(r"\nfunction HUD\.PadGlowOn\(step, zone, on\)\n.*?\nend\n", hud, re.S)
    pulse = re.search(r"\nfunction HUD\.TravelPulse\(step, seen, on\)\n.*?\nend\n", hud, re.S)
    if not pad or not pulse:
        return 0, 1, "HUD.PadGlowOn / HUD.TravelPulse missing"
    text = (f"local PAD_SOURCE = [==========[{pad.group(0)}]==========]\n"
            f"local PULSE_SOURCE = [==========[{pulse.group(0)}]==========]\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "walk.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"WALK_SUMMARY checks=(\d+) failed=(\d+)", out)
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
