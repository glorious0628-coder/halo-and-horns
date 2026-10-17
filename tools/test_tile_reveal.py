"""Bottom menu tiles: all shown, locked until needed (게임성 개발 1, SPEC A23-113 ③ + 고침 2026-10-10), offline.

Runs, in the official Luau CLI, the CURRENT HUD L.PickTiles / L.RefreshLocks / L.TileLocked / L.TileWiggle /
L.RevealReady / L.RevealState / L.TilePop cut out of HUD.luau with the CURRENT Config.luau (Config.HudReveal.TileShows /
TileWord): every tile is on the row from the start (user "처음부터 다 보이고, 그 자물쇠 해놓자"); Bag and Map are open; the
hero is locked ("Lv 2") until the first level up, the skills ("Lv <Unlock.Q>") until the first skill (SkillSlots >= 1
or, A23-193, a skill waiting at the teacher: SkillLearnReady >= 1), the pet ("Get pet") until a pet (following, or any in the pet list), the ranking ("Story 1") until
story:M1_4 is in the quest book's Done (or a later chapter's main row); a tile once open stays open this session; the
lock goes with a pop when it opens in play, never at the join (first 3 s after DataLoaded), never with reduced motion; a
locked tile's press wiggles it (Rotation tweens back to 0; nothing with reduced motion). Static: L.TileTap returns early
on a locked tile; the tile build makes UIKit.TileLock(btn, icon, label); Level / SkillSlots / EquippedPet re-check at once.
Mutations: each must be caught.

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
local pops, wiggles = {}, {}
local function button(id)
	local b = { Visible = false, Id = id, Kids = {}, Rotation = 0 }
	function b:FindFirstChild(n) return self.Kids[n] end
	return b
end
local function lockFor()
	local o = { Locked = false, Word = nil }
	function o.Set(on, word) o.Locked = on == true o.Word = on and word or nil end
	return o
end
local ui = { tiles = {} }
for _, d in { { "Character", 2 }, { "Bag", 1 }, { "Skills", 4 }, { "Map", 1 }, { "Ranking", 5 }, { "Pet", 6 } } do
	local t = { Def = { Id = d[1], Keep = d[2], Text = d[1] == "Character" and "Hero" or d[1] }, Button = button(d[1]) }
	if Config.HudReveal.Tiles[d[1]] then t.Lock = lockFor() end
	table.insert(ui.tiles, t)
end
-- 게임성 검수 10/13: the windows Panels has (L.TileOpens asks L.TileWindow); the hero's goes away in the last scene
local WINDOWS = { Character = "Hero", Bag = "Bag", Skills = "SkillBook", Pet = "PetWindow", Map = "Map" }
local L = { Rects = { tiles = { Count = 6 } }, TileWindow = function(def) return WINDOWS[def.Id] end }
local questState = {}
local env = {
	Config = Config, ui = ui, L = L, questState = questState, IS_TOUCH = false,
	C = { PetWindow = { Lists = function() return PETLIST end } },
	attr = function(n, d) local v = ATTR[n] if v == nil then return d end return v end,
	num = function(n, d) return tonumber(ATTR[n]) or d end,
	UIKit = { ReducedMotion = function() return REDUCED end },
	Instance = { new = function(cls) local o = { ClassName = cls } return o end },
	TweenService = { Create = function(_, obj, info, goal)
		return { Completed = { Connect = function() end, Wait = function() end }, Play = function()
			if goal.Rotation ~= nil then table.insert(wiggles, goal.Rotation) obj.Rotation = goal.Rotation
			elseif obj.Parent then table.insert(pops, obj.Parent.Id .. ":" .. tostring(obj.Scale) .. ">" .. tostring(goal.Scale)) end
		end }
	end },
	TweenInfo = base.TweenInfo, Enum = EnumT,
	task = { spawn = function(fn, ...) fn(...) end },
	os = { clock = function() return CLOCK end },
}
local f = assert(loadstring(HUD_SOURCE, "=Tiles"))
setfenv(f, setmetatable(env, { __index = getfenv() }))
f()

local function tile(id) for _, t in ui.tiles do if t.Def.Id == id then return t end end end
local function shown()
	local out = {}
	for _, t in ui.tiles do if t.Button.Visible then table.insert(out, t.Def.Id) end end
	table.sort(out)
	return table.concat(out, ",")
end
local function locked()
	local out = {}
	for _, t in ui.tiles do if L.TileLocked(t.Def.Id) then table.insert(out, t.Def.Id) end end
	table.sort(out)
	return table.concat(out, ",")
end
local function pick() L.PickTiles() return locked() end
local ALL = "Bag,Character,Map,Pet,Ranking,Skills"
local q = Config.Skills and Config.Skills.Unlock and Config.Skills.Unlock.Q or 5

-- the join
ATTR.Level = 1
pick()
ATTR.DataLoaded = true
check(pick() == "Character,Pet,Ranking,Skills", "a new player: hero, skills, pet, ranking locked", locked())
check(shown() == ALL, "... and every tile still on the row", shown())
check(tile("Character").Lock.Word == "Lv 2" and tile("Skills").Lock.Word == "Lv " .. q and tile("Pet").Lock.Word == "Get a pet"
	and tile("Ranking").Lock.Word == "Story 1", "the small condition words", tostring(tile("Skills").Lock.Word))
check(not L.TileLocked("Bag") and not L.TileLocked("Map"), "Bag and Map are open", "")
CLOCK += 5
pick()
check(#pops == 0, "nothing pops at the join", table.concat(pops, ","))
L.TileWiggle("Skills")
check(#wiggles >= 3 and tile("Skills").Button.Rotation == 0, "a locked tile's press wiggles it back to straight", table.concat(wiggles, ","))
REDUCED = true
wiggles = {}
L.TileWiggle("Skills")
check(#wiggles == 0, "no wiggle with reduced motion", #wiggles)
REDUCED = false
ATTR.Level = 2
check(pick() == "Pet,Ranking,Skills", "the first level up opens the hero tile", locked())
check(pops[1] == "Character:0.4>1" and #pops == 1, "... with one pop (a scale 0.4 -> 1 on the tile)", table.concat(pops, ","))
pick()
check(#pops == 1, "a second check does not pop it again", table.concat(pops, ","))
ATTR.Level = q - 1
check(string.find(pick(), "Skills") ~= nil, "skills still locked one level before the first skill", locked())
ATTR.Level = q
check(string.find(pick(), "Skills") ~= nil, "A23-193: the level alone does not open the skills tile", locked())
check(tile("Skills").Lock.Word == "Quest", "playtest r2: at the level, still locked: 'Quest' (not 'Lv 5')", tostring(tile("Skills").Lock.Word))
ATTR.SkillLearnReady = 1
check(string.find(pick(), "Skills") == nil, "A23-193: a skill waiting at the teacher opens the skills tile", locked())
ATTR.Level = 1
check(pick() == "Pet,Ranking", "a tile once open stays open (a rebirth to Lv1)", locked())
PETLIST = { List = {}, Equipped = "" }
check(string.find(pick(), "Pet") ~= nil, "an empty pet list keeps the pet locked", locked())
PETLIST = { List = { { Id = "p1" } }, Equipped = "" }
check(string.find(pick(), "Pet") == nil, "a pet in my list opens the pet tile", locked())
questState.All = { { Id = "story:M1_4", Pinned = true } }
check(pick() == "Ranking", "an M1 row showing: the ranking stays locked", locked())
questState.Book = { Done = { "story:M1_3", "story:M1_2" } }
check(pick() == "Ranking", "M1_3 done is not enough", locked())
questState.Book = { Done = { "story:M1_4", "story:M1_3" } }
check(pick() == "" and tile("Ranking").Lock.Word == nil, "story:M1_4 done opens the ranking (word gone)", locked())
check(shown() == ALL, "the row never changed", shown())

-- a second player: server skill slots, a following pet, a chapter 2 row; reduced motion = no pop
L.TileSeen = {}
L.RevealAt = nil
for _, t in ui.tiles do if t.Lock then t.Lock.Set(false) end end
questState.Book, questState.All, PETLIST = nil, nil, nil
ATTR = { DataLoaded = true, Level = 1 }
pops = {}
pick()
CLOCK += 5
pick()
REDUCED = true
ATTR.SkillSlots = 1
check(string.find(pick(), "Skills") == nil, "SkillSlots >= 1 opens the skills tile at any level", locked())
check(#pops == 0, "reduced motion: no pop", table.concat(pops, ","))
REDUCED = false
ATTR.EquippedPet = "pup"
check(string.find(pick(), "Pet") == nil, "a following pet opens the pet tile", locked())
questState.All = { { Id = "story:M2_1", Pinned = true } }
check(string.find(pick(), "Ranking") == nil, "a chapter 2 main row opens the ranking", locked())

-- a returning player: first check before my data, then level 12 + a pet + the book a moment later - no pops
L.TileSeen = {}
L.RevealAt = nil
for _, t in ui.tiles do if t.Lock then t.Lock.Set(false) end end
questState.All, questState.Book = nil, nil
ATTR = {}
pops = {}
pick()
ATTR = { DataLoaded = true, Level = 12, SkillSlots = 1, EquippedPet = "pup" }
check(pick() == "Ranking", "a returning player's tiles open with the data", locked())
CLOCK += 1
questState.Book = { Done = { "story:M1_4" } }
check(pick() == "" and #pops == 0, "... and the quest book a moment later: still no pops", table.concat(pops, ","))

-- 게임성 검수 10/13 (A23-99: the hero tile only said "Coming soon!"): a tile with nothing to open stays locked like the
-- others - its level word before the level, its own name after it, no pop; its window coming opens it
L.TileSeen = {}
L.RevealAt = nil
for _, t in ui.tiles do if t.Lock then t.Lock.Set(false) end end
questState.All, questState.Book, PETLIST = nil, nil, nil
WINDOWS.Character = nil
ATTR = { DataLoaded = true, Level = 1 }
pops = {}
pick()
CLOCK += 5
pick()
check(L.TileLocked("Character") and tile("Character").Lock.Word == "Lv 2", "10/13: no hero window, Lv 1: locked, 'Lv 2'",
	tostring(tile("Character").Lock.Word))
ATTR.Level = 2
pick()
check(L.TileLocked("Character") and tile("Character").Lock.Word == "Hero" and #pops == 0,
	"10/13: no hero window, Lv 2: still locked, its own name under the lock, no pop", tostring(tile("Character").Lock.Word))
WINDOWS.Character = "Hero"
pick()
check(not L.TileLocked("Character"), "10/13: its window comes - the hero tile opens", locked())

-- the row's room still trims by Keep (locked tiles count like any other)
for _, t in ui.tiles do t.Button.Visible = false end
ui.tileKey = nil
L.Rects.tiles.Count = 3
L.PickTiles()
check(shown() == "Bag,Character,Map", "a 3-tile row keeps Bag, Map, then the hero (Keep order)", shown())
print(("TILES_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("tiles hidden again", "local want = table.clone(ui.tiles)", "local want = {}"),
    ("never locked", "\t\t\tpcall(t.Lock.Set, locked, word)\n", ""),
    ("an open tile locks again", "local open = was == true or Config.HudReveal.TileShows(id, st)", "local open = Config.HudReveal.TileShows(id, st)"),
    ("pops at the join", "if was == false and ready and opens then L.TilePop(t.Button) end", "if was ~= true then L.TilePop(t.Button) end"),
    ("no pop at all", "if was == false and ready and opens then L.TilePop(t.Button) end -- opened in play (not at the join)", ""),
    # 게임성 검수 10/13: a tile with nothing to open
    ("a tile with nothing to open shows open ('Coming soon!' again)",
     "\t\tlocal locked = not (open and opens)\n\t\tlocal word = (open and not opens) and t.Def.Text",
     "\t\tlocal locked = not open\n\t\tlocal word = (open and not opens) and t.Def.Text"),
    ("its level word stays after the level", "local word = (open and not opens) and t.Def.Text or Config.HudReveal.TileWord(id, st)",
     "local word = Config.HudReveal.TileWord(id, st)"),
    ("'Lv 5' stays at Lv 5", "Config.HudReveal.TileWord(id, st) -- (nothing to open", "Config.HudReveal.TileWord(id) -- (nothing to open"),
    ("pops while still locked", "if was == false and ready and opens then L.TilePop(t.Button) end", "if was == false and ready then L.TilePop(t.Button) end"),
    ("the join timer only on change", "local ready = L.RevealReady() -- every check", "local ready = true -- every check"),
    ("pops with reduced motion", "if not btn or UIKit.ReducedMotion() then return end", "if not btn then return end"),
    ("no wiggle", "for _, r in { 7, -6, 4, -2, 0 } do", "for _, r in {} do"),
    ("wiggles with reduced motion", "function L.TileWiggle(id)\n\tif UIKit.ReducedMotion() then return end", "function L.TileWiggle(id)"),
    ("the pet list ignored", "hasPet = ok and type(list) == \"table\" and type(list.List) == \"table\" and #list.List > 0 or false", "hasPet = false"),
    ("an empty pet list counts", "and #list.List > 0 or false", "or false"),
    ("a later chapter row ignored", "if ch and ch >= 2 then done = true end", ""),
    ("chapter 1 rows count", "if ch and ch >= 2 then done = true end", "if ch and ch >= 1 then done = true end"),
    ("server skill slots ignored", "SkillSlots = num(\"SkillSlots\", 0)", "SkillSlots = 0"),
]
CONFIG_MUTATIONS = [
    ("the hero open from the start", 'if rule == "LevelUp" then return (tonumber(s.Level) or 1) >= 2 end', 'if rule == "LevelUp" then return true end'),
    ("A23-193: the level opens the skills tile again", "return (tonumber(s.SkillSlots) or 0) >= 1 or (tonumber(s.LearnReady) or 0) >= 1",
     "return (tonumber(s.SkillSlots) or 0) >= 1 or (tonumber(s.Level) or 1) >= q"),
    ("the ranking open from the start", 'if rule == "Chapter" then return s.ChapterDone == true end', 'if rule == "Chapter" then return true end'),
    ("no level in the skills word", "return string.format(w, q)", "return w"),
]
STATIC = [
    ("a locked tile's press only wiggles (TileTap returns first)",
     "function L.TileTap(def)\n\tif L.TileLocked(def.Id) then\n\t\tL.TileWiggle(def.Id) -- A23-113 ③: locked = a small wiggle only (no window, no notice)\n\t\treturn\n\tend"),
    ("the tile build makes UIKit.TileLock(btn, icon, label)", "local ok, lock = pcall(UIKit.TileLock, btn, icon, label)"),
    ("the phones' fold copies lock too", "local ok, lock = pcall(UIKit.TileLock, b, icon, lbl)"),
    ("a locked fold square only wiggles (the fold stays open)",
     "function L.FoldTap(def)\n\tif L.TileLocked(def.Id) then -- A23-113 ③: a locked square only wiggles (the fold stays open)\n\t\tL.TileWiggle(def.Id)\n\t\treturn\n\tend"),
    ("the row in the order the tiles open (Bag, Map, Hero, Skills, Pet, Ranking)",
     '{ Id = "Bag", Icon = "IconBag", Window = "Bag", Alt = "Items", Key = "Bag", Keep = 1 },\n\t\t{ Id = "Map", Icon = "GlyphMap", Map = true, Key = "Map", Keep = 1 },\n\t\t{ Id = "Character",'),
    ("Level / SkillSlots / EquippedPet re-check at once", 'for _, name in { "Level", "SkillSlots", "SkillLearnReady", "EquippedPet" } do\n\t\tLocalPlayer:GetAttributeChangedSignal(name):Connect(L.RefreshLocks)'),
    ("the 1 s refresh still checks (PickTiles -> RefreshLocks)", "\tif L.PickTiles() then requestLayout() end\nend"),
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
