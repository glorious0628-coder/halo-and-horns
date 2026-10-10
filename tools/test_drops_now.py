"""'Your drops now' line (게임성 개발 1, 검수 2026-10-10 조사 '피할 것 6'), offline.

Runs, in the official Luau CLI, the CURRENT Config.DropsNow with the CURRENT Config.luau: x1 with nothing; a bully or
this week's outlaw x Config.Bully.Penalty.DropMult (0.5, once even when both); the weekly top 3 (RankReward) x
Config.Ranking.RewardMult (1.1); both multiply; the reasons are short words. Static: the bag's 'What Monsters Drop'
adds the line only when it is not x1, from the player's own attributes; LootService still uses the same attributes and
numbers. Mutations: each must be caught.

Usage: py tools/test_drops_now.py
Report: docs/art/verification_2026-10-10/offline_drops_now_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
PANELS = ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau"
LOOT = ROOT / "src/ServerScriptService/LootService.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_drops_now_2026-10-10.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function ctor() return setmetatable({}, { __index = function() return function(...) return { ... } end end }) end
local base = { Vector3 = ctor(), Vector2 = ctor(), Color3 = ctor(), BrickColor = ctor(), Rect = ctor(), UDim2 = ctor(),
	UDim = ctor(), NumberRange = ctor(), NumberSequence = ctor(), ColorSequence = ctor(), NumberSequenceKeypoint = ctor(),
	ColorSequenceKeypoint = ctor(), CFrame = ctor(), TweenInfo = ctor(), Font = ctor(),
	Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end }),
	workspace = { GetServerTimeNow = function() return 1790000000 end } }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, setmetatable(base, { __index = getfenv() }))
local Config = cf()
local function near(a, b) return math.abs(a - b) < 1e-9 end
local m, why = Config.DropsNow({})
check(near(m, 1) and #why == 0, "nothing: x1, no reasons", m)
m, why = Config.DropsNow({ Outlaw = true })
check(near(m, Config.Bully.Penalty.DropMult) and why[1] == "Outlaw", "an outlaw: x0.5 (Outlaw)", m)
m, why = Config.DropsNow({ BullyStacks = 2 })
check(near(m, Config.Bully.Penalty.DropMult) and why[1] == "Bully", "a bully: x0.5 (Bully)", m)
m = Config.DropsNow({ BullyStacks = 1 })
check(near(m, Config.Bully.Penalty.DropMult), "one bully stack is enough", m)
m, why = Config.DropsNow({ BullyStacks = 1, Outlaw = true })
check(near(m, Config.Bully.Penalty.DropMult) and #why == 1, "bully and outlaw at once: x0.5 once", m)
m, why = Config.DropsNow({ RankReward = "Halo:1" })
check(near(m, Config.Ranking.RewardMult) and why[1] == "Top 3 this week", "the weekly top 3: x1.1", m)
m, why = Config.DropsNow({ Outlaw = true, RankReward = "Halo:1" })
check(near(m, Config.Bully.Penalty.DropMult * Config.Ranking.RewardMult) and #why == 2, "both multiply", m)
m = Config.DropsNow({ BullyStacks = 0, RankReward = "" })
check(near(m, 1), "0 stacks and an empty reward: x1", m)
print(("DROPS_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("the penalty ignored", "mult *= tonumber(pen.DropMult) or 1", "mult *= 1"),
    ("the top 3 ignored", "mult *= tonumber(Config.Ranking.RewardMult) or 1", "mult *= 1"),
    ("one stack is not a bully", "(tonumber(s.BullyStacks) or 0) >= 1", "(tonumber(s.BullyStacks) or 0) >= 2"),
    ("an empty reward counts", 'type(s.RankReward) == "string" and s.RankReward ~= ""', 'type(s.RankReward) == "string"'),
]
STATIC = [
    ("the line only when not x1", lambda p, l: "if math.abs(dm - 1) > 1e-6 then" in p and 'Name = "DropsNow"' in p),
    ("from the player's own attributes", lambda p, l: 'Config.DropsNow({ BullyStacks = player:GetAttribute("BullyStacks"), Outlaw = player:GetAttribute("Outlaw"),' in p
     and 'RankReward = player:GetAttribute("RankReward") })' in p),
    ("LootService still uses the same attributes and numbers", lambda p, l: 'num(player:GetAttribute("BullyStacks")) >= 1 or player:GetAttribute("Outlaw") == true' in l
     and 'player:GetAttribute("RankReward")' in l and "info.DropMult = num(pen.DropMult, 1)" in l
     and "info.RowBonus = num(Config.Ranking.RewardMult, 1)" in l),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str) -> tuple[int, int, str]:
    text = "local CONFIG_SOURCE = " + lua_str(config) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "drops.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"DROPS_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    panels = PANELS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    loot = LOOT.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    checks, failed, out = run(config)
    print(out.strip())
    statics = [{"check": n, "ok": bool(fn(panels, loot))} for n, fn in STATIC]
    for s in statics:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for name, old, new in MUTATIONS:
        hits = config.count(old)
        caught = hits == 1 and run(config.replace(old, new))[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = failed == 0 and checks > 0 and all(s["ok"] for s in statics) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": statics, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
