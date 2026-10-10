"""Bottom menu tiles show when needed (게임성 개발 1, SPEC A23-113 ③, 검수 2026-10-10), offline.

Runs, in the official Luau CLI, the CURRENT HUD L.PickTiles / L.RevealReady / L.RevealState / L.TilePop cut out of
HUD.luau with the CURRENT Config.luau (Config.HudReveal.TileShows): a new player sees Bag and Map only; the hero
(Character) comes at the first level up, the skills at the first skill (SkillSlots >= 1 or Config.Skills.Unlock.Q), the
pet with a pet (following, or any in the pet list), the ranking once story:M1_4 is in the quest book's Done (or a later
chapter's main row shows); a tile shown once stays this session; a tile that comes in during play pops in once (a
UIScale), never at the join (first 3 s after DataLoaded) and never with reduced motion; the row's Count still trims by
Keep. Static: Level / SkillSlots / EquippedPet changes re-pick at once. Mutations: each must be caught.

Usage: py tools/test_tile_reveal.py
Report: docs/art/verification_2026-10-10/offline_tile_reveal_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_tile_reveal_2026-10-10.json"
START, END = "function L.PickTiles()", "-- the shown tiles on Rects.tiles"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function ctor() return setmetatable({}, { __index = function() return function(...) return { ... } end end }) end
local EnumT = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end })
local base = { Vector3 = ctor(), Vector2 = ctor(), Color3 = ctor(), BrickColor = ctor(), Rect = ctor(), UDim2 = ctor(),
	UDim = ctor(), NumberRange = ctor(), NumberSequence = ctor(), ColorSequence = ctor(), NumberSequenceKeypoint = ctor(),
	ColorSequenceKeypoint = ctor(), CFrame = ctor(), TweenInfo = ctor(), Font = ctor(), Enum = EnumT,
	workspace = { GetServerTimeNow = function() return 1790000000 end } }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, setmetatable(base, { __index = getfenv() }))
local Config = cf()

local ATTR, CLOCK, REDUCED, PETLIST = {}, 100, false, nil
local pops = {}
local function button(id)
	local b = { Visible = false, Id = id, Kids = {} }
	function b:FindFirstChild(n) return self.Kids[n] end
	return b
end
local ui = { tiles = {} }
for _, d in { { "Character", 2 }, { "Bag", 1 }, { "Skills", 4 }, { "Map", 1 }, { "Ranking", 5 }, { "Pet", 6 } } do
	table.insert(ui.tiles, { Def = { Id = d[1], Keep = d[2] }, Button = button(d[1]) })
end
local L = { Rects = { tiles = { Count = 6 } } }
local questState = {}
local env = {
	Config = Config, ui = ui, L = L, questState = questState, IS_TOUCH = false,
	C = { PetWindow = { Lists = function() return PETLIST end } },
	attr = function(n, d) local v = ATTR[n] if v == nil then return d end return v end,
	num = function(n, d) return tonumber(ATTR[n]) or d end,
	UIKit = { ReducedMotion = function() return REDUCED end },
	Instance = { new = function(cls) local o = { ClassName = cls } return o end },
	TweenService = { Create = function(_, obj, info, goal)
		return { Completed = { Connect = function() end }, Play = function()
			if obj.Parent then table.insert(pops, obj.Parent.Id .. ":" .. tostring(obj.Scale) .. ">" .. tostring(goal.Scale)) end
		end }
	end },
	TweenInfo = base.TweenInfo, Enum = EnumT,
	os = { clock = function() return CLOCK end },
}
local f = assert(loadstring(HUD_SOURCE, "=Tiles"))
setfenv(f, setmetatable(env, { __index = getfenv() }))
f()

local function shown()
	local out = {}
	for _, t in ui.tiles do if t.Button.Visible then table.insert(out, t.Def.Id) end end
	table.sort(out)
	return table.concat(out, ",")
end
local function pick() L.PickTiles() return shown() end

-- the join: data not loaded yet, then loaded at level 1
ATTR.Level = 1
pick()
ATTR.DataLoaded = true
check(pick() == "Bag,Map", "a new player sees Bag and Map only", shown())
CLOCK += 5
pick()
check(#pops == 0, "nothing pops at the join", table.concat(pops, ","))
ATTR.Level = 2
check(pick() == "Bag,Character,Map", "the first level up brings the hero tile", shown())
check(pops[1] == "Character:0.4>1" and #pops == 1, "... which pops in once (a scale 0.4 -> 1 on the tile)", table.concat(pops, ","))
pick()
check(#pops == 1, "a second pick does not pop it again", table.concat(pops, ","))
ATTR.Level = 4
check(pick() == "Bag,Character,Map", "no skills tile before the first skill (Lv4)", shown())
local q = Config.Skills and Config.Skills.Unlock and Config.Skills.Unlock.Q or 5
ATTR.Level = q
check(string.find(pick(), "Skills") ~= nil, "the first skill level brings the skills tile", shown())
ATTR.Level = 1
check(string.find(pick(), "Skills") ~= nil and string.find(shown(), "Character") ~= nil, "a tile shown once stays (a rebirth to Lv1 keeps it)", shown())
check(string.find(shown(), "Pet") == nil, "no pet tile without a pet", shown())
PETLIST = { List = {}, Equipped = "" }
check(string.find(pick(), "Pet") == nil, "an empty pet list keeps the pet tile away", shown())
PETLIST = { List = { { Id = "p1" } }, Equipped = "" }
check(string.find(pick(), "Pet") ~= nil, "a pet in my list brings the pet tile", shown())
questState.All = { { Id = "story:M1_4", Pinned = true } }
check(string.find(pick(), "Ranking") == nil, "no ranking before the first chapter is done (an M1 row showing)", shown())
questState.Book = { Done = { "story:M1_3", "story:M1_2" } }
check(string.find(pick(), "Ranking") == nil, "M1_3 done is not enough", shown())
questState.Book = { Done = { "story:M1_4", "story:M1_3" } }
check(string.find(pick(), "Ranking") ~= nil, "story:M1_4 done brings the ranking tile", shown())

-- a second player: skill slots from the server, a following pet, a later chapter row; reduced motion = no pop
for _, t in ui.tiles do t.Button.Visible = false end
L.TileSeen = {}
ui.tileKey = nil
L.RevealAt = nil
questState.Book = nil
PETLIST = nil
ATTR = { DataLoaded = true, Level = 1 }
pops = {}
pick()
CLOCK += 5
pick()
REDUCED = true
ATTR.SkillSlots = 1
check(string.find(pick(), "Skills") ~= nil, "SkillSlots >= 1 brings the skills tile at any level", shown())
check(#pops == 0, "reduced motion: no pop", table.concat(pops, ","))
REDUCED = false
ATTR.EquippedPet = "pup"
check(string.find(pick(), "Pet") ~= nil, "a following pet brings the pet tile", shown())
questState.All = { { Id = "story:M2_1", Pinned = true } }
check(string.find(pick(), "Ranking") ~= nil, "a chapter 2 main row brings the ranking tile", shown())

-- a returning player: the HUD's first pick runs before my data, then level 12 + a pet arrive with it - no pops
for _, t in ui.tiles do t.Button.Visible = false end
L.TileSeen = {}
ui.tileKey = nil
L.RevealAt = nil
L.Rects.tiles.Count = 6
questState.All = nil
ATTR = {}
pops = {}
pick()
ATTR = { DataLoaded = true, Level = 12, EquippedPet = "pup" }
check(pick() == "Bag,Character,Map,Pet,Skills", "a returning player's tiles come with the data", shown())
CLOCK += 1
questState.Book = { Done = { "story:M1_4" } }
check(string.find(pick(), "Ranking") ~= nil and #pops == 0, "... and the quest book a moment later: still no pops", table.concat(pops, ","))

-- the row's room still trims by Keep
for _, t in ui.tiles do t.Button.Visible = false end
L.TileSeen = {}
ui.tileKey = nil
L.Rects.tiles.Count = 3
ATTR = { DataLoaded = true, Level = 30, EquippedPet = "pup" }
check(pick() == "Bag,Character,Map", "a 3-tile row keeps Bag, Map, then the hero (Keep order)", shown())
print(("TILES_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("every tile always shows", "if L.TileSeen[t.Def.Id] == true or Config.HudReveal.TileShows(t.Def.Id, st) then", "if true then"),
    ("a shown tile can go away", "if L.TileSeen[t.Def.Id] == true or Config.HudReveal.TileShows", "if Config.HudReveal.TileShows"),
    ("pops at the join", "if shown[t] and was == false and ready then", "if shown[t] and was ~= true then"),
    ("no pop at all", "if shown[t] and was == false and ready then L.TilePop(t.Button) end", ""),
    ("the join timer starts only at the first pop", "local ready = L.RevealReady()", "local ready = true"),
    ("pops with reduced motion", "if not btn or UIKit.ReducedMotion() then return end", "if not btn then return end"),
    ("the pet list ignored", "hasPet = ok and type(list) == \"table\" and type(list.List) == \"table\" and #list.List > 0 or false", "hasPet = false"),
    ("an empty pet list counts", "and #list.List > 0 or false", "or false"),
    ("a later chapter row ignored", "if ch and ch >= 2 then done = true end", ""),
    ("chapter 1 rows count", "if ch and ch >= 2 then done = true end", "if ch and ch >= 1 then done = true end"),
    ("server skill slots ignored", "SkillSlots = num(\"SkillSlots\", 0)", "SkillSlots = 0"),
]
CONFIG_MUTATIONS = [
    ("the hero tile from the start", 'if rule == "LevelUp" then return (tonumber(s.Level) or 1) >= 2 end', 'if rule == "LevelUp" then return true end'),
    ("the skills tile one level early", "return (tonumber(s.SkillSlots) or 0) >= 1 or (tonumber(s.Level) or 1) >= q",
     "return (tonumber(s.SkillSlots) or 0) >= 1 or (tonumber(s.Level) or 1) >= q - 1"),
    ("the ranking from the start", 'if rule == "Chapter" then return s.ChapterDone == true end', 'if rule == "Chapter" then return true end'),
]
STATIC = [
    ("Level / SkillSlots / EquippedPet re-pick at once", 'for _, name in { "Level", "SkillSlots", "EquippedPet" } do'),
    ("... through PickTiles + layout", "LocalPlayer:GetAttributeChangedSignal(name):Connect(function()\n\t\t\tif L.PickTiles() then requestLayout() end"),
    ("the 1 s refresh still re-picks", "\tif L.PickTiles() then requestLayout() end\nend"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(block: str, config: str) -> tuple[int, int, str]:
    text = "local CONFIG_SOURCE = " + lua_str(config) + "\nlocal HUD_SOURCE = " + lua_str(block) + "\n" + FIXTURE
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "tiles.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"TILES_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    a, b = src.find(START), src.find(END)
    block = src[a:b]
    checks, failed, out = run(block, config)
    print(out.strip())
    statics = [{"check": n, "ok": t in src} for n, t in STATIC]
    for s in statics:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
    muts = []
    for name, old, new in MUTATIONS:
        hits = block.count(old)
        caught = hits == 1 and run(block.replace(old, new), config)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    for name, old, new in CONFIG_MUTATIONS:
        hits = config.count(old)
        caught = hits == 1 and run(block, config.replace(old, new))[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = a >= 0 and b > a and failed == 0 and checks > 0 and all(s["ok"] for s in statics) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": statics, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
