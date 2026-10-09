"""Monster name tag danger colour (검수 2026-10-09, system review ④).

Runs the CURRENT Config.MonsterDanger (Tier / LevelOf, cut out of Config.luau) in the official Luau CLI with small
MonsterTypes / Zones doubles: Weak (gray) when the monster is 5+ levels below me, Even (white), Strong (yellow) 3+ above,
Deadly (red) 8+ above; the level = the model's Level attribute (dev2, later), else its zone's MinLevel (+5 for a boss).
Static: MonsterLabels colours every shown name tag with it and leaves a golden monster's gold alone; the real Config's
zones give the meadow / woods / ruins levels. Mutations: each must be caught.

Usage: py tools/test_monster_danger.py
Report: docs/art/verification_2026-10-09/offline_monster_danger_2026-10-09.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "LABELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/MonsterLabels.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-09/offline_monster_danger_2026-10-09.json"

STATIC = [
    ("MonsterLabels colours each shown name tag", "LABELS", ["\t\tif name and r.Name then S.Danger(r) end\n",
     "\tlocal color = (monLv and myLv) and D.Colors[D.Tier(myLv, monLv)] or D.Colors.Even\n"]),
    ("a golden monster keeps its gold", "LABELS", ['\tif not model or model:GetAttribute("Golden") == true then return end\n']),
]
MUTATIONS = [
    ("CONFIG", "no red", '\tif d >= B.Deadly then return "Deadly" end\n', ""),
    ("CONFIG", "no gray", '\tif d <= B.Weak then return "Weak" end\n', ""),
    ("CONFIG", "yellow from one level up", "Fallback = { Weak = -6, Strong = 3,", "Fallback = { Weak = -6, Strong = 1,"),
    ("CONFIG", "dev2's band ignored", "\tif type(Config.MonsterDanger) == \"function\" then return Config.MonsterDanger(myLevel, monsterLevel) end\n", ""),
    ("CONFIG", "dev2's MonsterLevel ignored", "\tif type(Config.MonsterLevel) == \"function\" then return Config.MonsterLevel(kind) end\n", ""),
    ("CONFIG", "the Level attribute ignored", "\tif lv and lv == lv and lv > 0 then return math.floor(lv) end\n", ""),
    ("CONFIG", "bosses as their zone", "((def.Boss == true) and Config.MonsterDangerLook.Fallback.Boss or 0)", "0"),
    ("LABELS", "golden tags recoloured", '\tif not model or model:GetAttribute("Golden") == true then return end\n',
     "\tif not model then return end\n"),
    ("LABELS", "never coloured", "\t\tif name and r.Name then S.Danger(r) end\n", ""),
]

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local Config = {
	Zones = { SlimeMeadow = { MinLevel = 1 }, GoblinWoods = { MinLevel = 10 }, SkeletonRuins = { MinLevel = 25 } },
	MonsterTypes = { Slime = { Zone = "SlimeMeadow" }, GoblinBrute = { Zone = "GoblinWoods" },
		Skeleton = { Zone = "SkeletonRuins" }, KingSlime = { Zone = "SlimeMeadow", Boss = true } },
}
local f = assert(loadstring(DANGER_SOURCE, "=MonsterDangerLook"))
setfenv(f, setmetatable({ Config = Config, Color3 = { fromRGB = function(r, g, b) return { r, g, b } end } }, { __index = getfenv() }))
f()
local L = Config.MonsterDangerLook
-- the old argument order (monster, me) in these checks; Tier itself takes (myLevel, monsterLevel) like dev2
local D = { LevelOf = L.LevelOf, Colors = L.Colors, Tier = function(m, me) return L.Tier(me, m) end }
check("a slime for a Lv1: Even (white)", D.Tier(D.LevelOf("Slime"), 1) == "Even")
check("a slime for a Lv10: Weak (gray)", D.Tier(D.LevelOf("Slime"), 10) == "Weak")
check("5 levels below: still Even (dev2 band -6)", D.Tier(5, 10) == "Even")
check("6 levels below: Weak", D.Tier(4, 10) == "Weak")
check("a woods brute for a Lv5: Strong (yellow)", D.Tier(D.LevelOf("GoblinBrute"), 5) == "Strong", D.Tier(10, 5))
check("2 levels above: Even", D.Tier(12, 10) == "Even")
check("a ruins skeleton for a Lv12: Deadly (red)", D.Tier(D.LevelOf("Skeleton"), 12) == "Deadly")
check("a boss = its zone + 5", D.LevelOf("KingSlime") == 6)
check("the Level attribute wins", D.LevelOf("Slime", 18) == 18 and D.Tier(D.LevelOf("Slime", 18), 10) == "Deadly")
check("a broken Level attribute falls back", D.LevelOf("Slime", 0 / 0) == 1 and D.LevelOf("Slime", "x") == 1)
check("unknown kind: no level (the tag stays white)", D.LevelOf("Nope") == nil)
-- once dev2-mlevel is in: its band and its levels win
Config.MonsterDanger = function(me, m) return "DEV2:" .. tostring(me) .. ":" .. tostring(m) end
Config.MonsterLevel = function(kind) return kind == "Slime" and 3 or 1 end
check("dev2's Config.MonsterDanger(myLevel, monsterLevel) is used when there", L.Tier(7, 9) == "DEV2:7:9")
check("dev2's Config.MonsterLevel(kind) is used when there", L.LevelOf("Slime") == 3 and L.LevelOf("Slime", 20) == 20)
Config.MonsterDanger, Config.MonsterLevel = nil, nil
check("four colours", D.Colors.Weak and D.Colors.Even and D.Colors.Strong and D.Colors.Deadly)
print(("DANGER_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''


def run(src: dict) -> tuple[int, int, str]:
    m = re.search(r"Config\.MonsterDangerLook = \{.*?\nfunction Config\.MonsterDangerLook\.Tier\(myLevel, monsterLevel\)\n.*?\nend\n",
                  src["CONFIG"], re.S)
    if not m:
        return 0, 1, "Config.MonsterDangerLook missing"
    text = f"local DANGER_SOURCE = [==========[{m.group(0)}]==========]\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "danger.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
    out = proc.stdout + proc.stderr
    mm = re.search(r"DANGER_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(mm[2]) if mm else 1
    for name, key, needles in STATIC:
        ok = all(src[key].count(n) == 1 for n in needles)
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(mm[1]) if mm else 0) + len(STATIC), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        m = dict(src)
        m[key] = src[key].replace(old, new)
        caught = hits == 1 and run(m)[1] > 0
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
