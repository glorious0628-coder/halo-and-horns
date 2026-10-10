"""Town people notice my lean (게임성 개발 1, SPEC A23-64 ① / A23-113 ⑥), offline.

Runs, in the official Luau CLI, the CURRENT TownReact.luau (Choose / Step / Say / TownOf) with the CURRENT Config.luau
(Config.TownReact, Config.TownReactLines) and fake Roblox objects: the nearest tagged town person within Range speaks a
line from Config.TownReactLines for my faction / rank; it waits Every s before speaking again; only one bubble at a time
(Show s); nothing while a window is open, before DataLoaded / ClassChosen, or beyond Range; a new TownPick is said first
once (the join's saved one is not); the same person never says the same line twice in a row; the bubble is MonsterLabels'
B.Make with the sentence size and goes after Show s. Static: ClientMain loads it after MonsterLabels; B.Make takes the
size. Mutations: each must be caught.

Usage: py tools/test_town_react.py
Report: docs/art/verification_2026-10-10/offline_town_react_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "src/StarterPlayer/StarterPlayerScripts/TownReact.luau"
MAIN = ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"
LABELS = ROOT / "src/StarterPlayer/StarterPlayerScripts/MonsterLabels.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_town_react_2026-10-10.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local V3 = {}
V3.__add = function(a, b) return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, V3) end
V3.__sub = function(a, b) return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, V3) end
V3.__index = function(v, k) if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end end
local Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
local function ctor() return setmetatable({}, { __index = function() return function(...) return { ... } end end }) end
local EnumT = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end })
local base = { Vector3 = Vector3, Vector2 = ctor(), Color3 = ctor(), BrickColor = ctor(), Rect = ctor(), UDim2 = ctor(),
	UDim = ctor(), NumberRange = ctor(), NumberSequence = ctor(), ColorSequence = ctor(), NumberSequenceKeypoint = ctor(),
	ColorSequenceKeypoint = ctor(), CFrame = ctor(), TweenInfo = ctor(), Font = ctor(), Enum = EnumT,
	workspace = { GetServerTimeNow = function() return 1790000000 end } }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, setmetatable(base, { __index = getfenv() }))
local Config = cf()
local R = Config.TownReact

local ATTR = { DataLoaded = true, ClassChosen = true, Faction = "Halo", Honor = 0, Infamy = 0 }
local OPEN = false
local said = {}
local delays = {}
local function npc(name, pos, town)
	local m = { Name = name, Pos = pos, Attr = { Town = town }, Head = { Name = "Head" } }
	function m:IsA(c) return c == "Model" end
	function m:IsDescendantOf() return true end
	function m:GetPivot() return { Position = self.Pos } end
	function m:GetAttribute(n) return self.Attr[n] end
	function m:FindFirstChild(n) if n == "Head" then return self.Head end end
	return m
end
local folk = { npc("Folk1", Vector3.new(10, 0, 0), "HaloTown"), npc("Folk2", Vector3.new(20, 0, 0), "HaloTown"),
	npc("Folk3", Vector3.new(200, 0, 0), "HaloTown") }
local B = { Out = 0.18 }
function B.Make(root, offsetY, text, kind, size)
	local bb = { Name = "BarkBubble", Parent = root, Size = size, Kind = kind }
	function bb:Destroy() self.Parent = nil end
	table.insert(said, { Root = root, Text = text, Size = size, Bubble = bb })
	return bb, function() bb.Faded = true end
end
local registry = { MonsterLabels = { Bark = B }, Panels = { IsOpen = function() return OPEN end } }
local LocalPlayer = { GetAttribute = function(_, n) return ATTR[n] end,
	Character = { FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return { Position = Vector3.new(0, 0, 0) } end end } }
local function service(name)
	if name == "Players" then return { LocalPlayer = LocalPlayer } end
	if name == "CollectionService" then return { GetTagged = function(_, tag) return tag == R.Tag and folk or {} end } end
	return { WaitForChild = function() return { WaitForChild = function() return "Config" end } end }
end
local env = {
	game = { GetService = function(_, n) return service(n) end },
	require = function() return Config end,
	workspace = {},
	math = setmetatable({ random = function(a, b) return a end }, { __index = math }), -- the first of the pool
	task = { spawn = function() end, wait = function() end, delay = function(t, fn) table.insert(delays, { T = t, Fn = fn }) end },
}
local f = assert(loadstring(MOD_SOURCE, "=TownReact"))
setfenv(f, setmetatable(env, { __index = getfenv() }))
local TR = f()
TR.Init(registry)
local function runDelays() for _, d in delays do d.Fn() end delays = {} end

local rankLines = Config.TownReactLines({ Faction = "Halo", Honor = 0, Infamy = 0, Town = "HaloTown" })
check(#rankLines > 0, "the Halo rank 1 lines exist", #rankLines)
local who, line = TR.Step(100)
check(who == folk[1], "the nearest town person in range speaks", who and who.Name)
check(line and table.find(rankLines, line) ~= nil, "... a line from Config.TownReactLines", line)
check(#said == 1 and said[1].Root == folk[1].Head and said[1].Size and said[1].Size[1] > 150, "the bubble over its head, sentence-sized", #said)
check(said[1].Bubble.Name == "TownReactBubble", "named TownReactBubble", said[1].Bubble.Name)
runDelays()
check(said[1].Bubble.Faded and said[1].Bubble.Parent == nil, "fades and goes after Show s", "")
check(TR.Step(101) == nil, "one bubble at a time (Show s)", "")
local w2 = TR.Step(100 + R.Show + 1)
check(w2 == folk[2], "then the next person (the first waits Every s)", w2 and w2.Name)
check(TR.Step(100 + 2 * (R.Show + 1)) == nil, "both wait their Every s; the far one never speaks", "")
local w3 = TR.Step(100 + R.Every + 1)
check(w3 == folk[1], "after Every s the first speaks again", w3 and w3.Name)
check(said[#said].Text ~= said[1].Text or #rankLines < 2, "never the same line twice in a row for one person", said[#said].Text)

OPEN = true
check(TR.Step(1000) == nil, "nothing while a window is open", "")
OPEN = false
ATTR.DataLoaded = false
check(TR.Step(1001) == nil, "nothing before my data", "")
ATTR.DataLoaded = true

-- a new town pick is said first, once
local pickId = nil
for _, id in R.Order do
	local def = Config.StoryQuests.Defs[id]
	local lt = R.Text.Good and R.Text.Good[id]
	if def and type(lt) == "string" and (type(def.Factions) ~= "table" or def.Factions.Halo) then pickId = id break end
end
check(pickId ~= nil, "a Halo town pick with a Good line exists", pickId)
ATTR.TownPick = pickId .. ":Good"
local _, l1 = TR.Step(2000)
check(l1 == R.Text.Good[pickId], "a new town pick is said first", l1)
local _, l2 = TR.Step(2000 + R.Show + 1)
local _, l3 = TR.Step(2000 + 2 * (R.Show + 1))
check(l2 ~= nil and l2 ~= R.Text.Good[pickId], "... once (the next person says a random line)", tostring(l2) .. "/" .. tostring(l3))

-- the join's saved pick is not said first
TR.State.Pick = { Init = false }
local _, j = TR.Step(5000)
check(j ~= R.Text.Good[pickId] or #Config.TownReactLines({ Faction = "Halo", TownPick = ATTR.TownPick, Town = "HaloTown" }) <= 1,
	"the join's saved pick is old news (not forced first)", j)

-- Choose (pure)
check(TR.Choose({}, nil, nil, false, function() return 1 end) == nil, "no lines: quiet", "")
check(TR.Choose({ "a", "b" }, "b", "a", false, function() return 1 end) == "b", "never the last line again", "")
check(TR.Choose({ "a", "b" }, "b", nil, true, function() return 1 end) == "b", "a fresh pick first", "")
check(TR.Choose({ "a" }, nil, "a", false, function() return 1 end) == "a", "one line only: it may repeat", "")

-- far away: nothing
local back = folk
folk = { npc("Far", Vector3.new(R.Range + 5, 0, 0), "HaloTown") }
check(TR.Step(9000) == nil, "beyond Range: nothing", "")
folk = back
print(("TOWN_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("anyone at any distance", "local best, bestD = nil, num(R.Range, 30)", "local best, bestD = nil, math.huge"),
    ("no wait per person", "S.NextAt[best] = now + num(R.Every, 30)", "S.NextAt[best] = now"),
    ("bubbles pile up", "S.BusyUntil = now + num(R.Show, 4) + 0.5", "S.BusyUntil = now"),
    ("talks over windows", "or windowOpen() then return nil end", "then return nil end"),
    ("talks before data", 'if attr("DataLoaded") ~= true or attr("ClassChosen") ~= true or windowOpen()', "if windowOpen()"),
    ("the new pick never first", "if pickFresh and type(pickLine) == \"string\" then return pickLine end", ""),
    ("the pick said every time", "if line == pickLine then S.Pick.Said = true end", ""),
    ("the join's pick said first", "S.Pick = { Init = true, Value = pick, At = now, Said = true } -- the join's saved pick is old news",
     "S.Pick = { Init = true, Value = pick, At = now, Said = false }"),
    ("repeats its last line", "if l ~= last then table.insert(pool, l) end", "table.insert(pool, l)"),
    ("never goes", "if bubble.Parent then bubble:Destroy() end", ""),
    ("bark-sized bubble", "pcall(B.Make, head, T.Lift, line, nil, T.Size)", "pcall(B.Make, head, T.Lift, line, nil, nil)"),
]
STATIC = [
    ("ClientMain loads TownReact after MonsterLabels", lambda m, s, lb: '"StoryNpcs", "TownReact", ' in m
     and m.find('"MonsterLabels"') < m.find('"TownReact"')),
    ("B.Make takes a size", lambda m, s, lb: "function B.Make(root, offsetY, text, kind, size)" in lb
     and "if type(size) == \"table\" and tonumber(size[1]) and tonumber(size[2]) then w, h = tonumber(size[1]), tonumber(size[2]) end" in lb),
    ("lines only from Config.TownReactLines (no text of its own)", lambda m, s, lb: "Config.TownReactLines(" in s
     and not re.search(r'line = "[A-Z]', s)),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(mod: str, config: str) -> tuple[int, int, str]:
    text = "local CONFIG_SOURCE = " + lua_str(config) + "\nlocal MOD_SOURCE = " + lua_str(mod) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "town.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"TOWN_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    mod = MOD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    main_src = MAIN.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    labels = LABELS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    checks, failed, out = run(mod, config)
    print(out.strip())
    statics = [{"check": n, "ok": bool(fn(main_src, mod, labels))} for n, fn in STATIC]
    for s in statics:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for name, old, new in MUTATIONS:
        hits = mod.count(old)
        caught = hits == 1 and run(mod.replace(old, new), config)[1] > 0
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
