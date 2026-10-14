"""A23-167 ① ③ ④ (게임성 개발 1, 2026-10-14; plan docs/design/gameplay_plan_2026-10-14.md §2-A ①②③), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau with:
1. HUD L.GoalTiers (cut out of HUD.luau): goal chip tier 2 'Next' = the nearest Config.GoalChips.Steps level above my
   level and past the level the tracker's own next-goal row names (QuestService GoalKind), Z / X skills only while their
   switch is on, no skill step after a rebirth, seasonal zones never, the rebirth level last; tier 3 'Big goal' = my
   side's crown (none for the Artisan Guild / no side); switched off = nothing. L.GoalTiersOn: phones tier 1 only.
2. DeathScreen.luau on doubles (attributes, CharacterAdded, the Fx remote): TotalXP across levels, Tally counts gains
   only (a deposit, spending, the pouch gold a KO costs never count; a side switch / rebirth only re-bases), the KO
   screen's 'This run' lines (XP, gold, items from my Fx "Loot", Honor for the Knights / Mischief for the Legion), none
   when nothing grew, a new character starts a new run.
3. FactionPicker.ChangeLines + Config.FactionChanges: three lines per side, the home town / guide names match
   Config.Zones[Config.HomeZoneId(side)] and Config.Tutorial.Welcome[side].Name, English only.
Static: the tracker refreshes the tiers (SetTracker, level / skills / side attributes), its room on small PC windows
counts them, the KO screen reads the run before it draws, the picker reserves the lines' room under the cards.
Mutations: each must be caught.

Usage: py tools/test_goal_chips.py
Report: docs/art/verification_2026-10-14/offline_goal_chips_2026-10-14.json (do not commit)
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
FILES = {"HUD": SPS / "HUD.luau", "DS": SPS / "DeathScreen.luau", "FP": SPS / "FactionPicker.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-14/offline_goal_chips_2026-10-14.json"
HUD_CUTS = [("function L.GoalTiers(", "\nend\n"), ("function L.GoalTiersOn()", "\nend\n")]
FP_CUT = ("function FactionPicker.ChangeLines(id)", "\nend\n")

FIXTURE = r'''
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name .. " :: " .. tostring(detail)) end
end
local function signal()
	local s = { Fns = {} }
	function s:Connect(fn) table.insert(self.Fns, fn) return {} end
	function s:Fire(...) for _, fn in self.Fns do fn(...) end end
	return s
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function vec(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end
local base = { Vector3 = { new = vec, zero = vec() }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
	NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"),
	CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cf = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cf, cfgEnv)
local Config = cf()

------------------------------------------------------------------ 1. goal chip tiers
local L = {}
local TOUCH = false
local hf = assert(loadstring(HUD_SOURCE, "=HUD"))
local hudEnv = setmetatable({ L = L, Config = Config }, { __index = function(_, k)
	if k == "IS_TOUCH" then return TOUCH end
	return getfenv()[k]
end })
setfenv(hf, hudEnv)
hf()
local G = Config.GoalChips
check(type(G) == "table" and G.Enabled == true and G.TouchTiers == 1, "Config.GoalChips on, phones tier 1 only", G and G.TouchTiers)
local Sk = Config.Skills
local q = Sk.Unlock.Q
local woods, ruins = Config.Zones.GoblinWoods.MinLevel, Config.Zones.SkeletonRuins.MinLevel
local rb0 = Config.RebirthLevel(0)
Sk.ZEnabled, Sk.XEnabled = false, false
local n, b = L.GoalTiers(1, 0, 0, "Halo", nil)
check(n == string.format("Next: Lv %d · first skill", q), "Lv1, no skill: Next = the first skill", n)
check(b == "Big goal: Win the Crown", "Knights: Big goal = the crown (short; the side is the line's colour)", b)
n, b = L.GoalTiers(1, 0, 0, "Horns", nil)
check(b == "Big goal: Win the Crown", "Legion: the same short crown line", b)
n, b = L.GoalTiers(3, 0, 0, "Neutral", nil)
check(b == nil and n ~= nil, "the Artisan Guild: no crown line (Next still)", tostring(b))
-- 최종 검수 10/14 MINOR: no crown line for Neutral / None / no side on purpose, not by a format error
local bigWords = G.Text.Big
G.Text.Big = "Big goal"
local _, bn = L.GoalTiers(3, 0, 0, "Neutral", nil)
local _, bx = L.GoalTiers(3, 0, 0, "None", nil)
local _, bz = L.GoalTiers(3, 0, 0, nil, nil)
local _, bh = L.GoalTiers(3, 0, 0, "Halo", nil)
check(bn == nil and bx == nil and bz == nil and bh == "Big goal", "Neutral / None / no side: no crown line even when the words need no side",
	tostring(bn) .. "/" .. tostring(bx) .. "/" .. tostring(bz) .. "/" .. tostring(bh))
G.Text.Big = bigWords
n = L.GoalTiers(3, 0, 0, "Halo", { NextGoal = true, GoalKind = "SkillIron" })
check(n == string.format("Next: Lv %d · Goblin Woods", woods), "the tracker says Lv5 skill + iron: Next = the woods", n)
n = L.GoalTiers(3, 0, 0, "Halo", { NextGoal = true, GoalKind = "IronLevel" })
check(n == string.format("Next: Lv %d · Goblin Woods", woods), "the tracker says the iron weapon level: Next = the woods", n)
n = L.GoalTiers(3, 0, 0, "Halo", { NextGoal = false, GoalKind = "SkillIron" })
check(n == string.format("Next: Lv %d · first skill", q), "a story / tutorial row: the nearest step", n)
n = L.GoalTiers(6, 0, 1, "Halo", { NextGoal = true, GoalKind = "Zone" })
check(n == string.format("Next: Lv %d · Skeleton Ruins", ruins), "Lv6, the tracker says the woods: Next = the ruins (Z off)", n)
n = L.GoalTiers(6, 0, 1, "Halo", { NextGoal = true, GoalKind = "IronDrop" })
check(n == string.format("Next: Lv %d · Goblin Woods", woods), "the King Slime row (no level): the nearest step", n)
Sk.ZEnabled = true
n = L.GoalTiers(11, 0, 1, "Halo", nil)
check(n == string.format("Next: Lv %d · new skill", Sk.Unlock.Z), "Z switched on: Lv11 Next = the Z skill", n)
n = L.GoalTiers(11, 0, 1, "Halo", { NextGoal = true, GoalKind = "Skill" })
check(n == string.format("Next: Lv %d · Skeleton Ruins", ruins), "the tracker says the Z skill: Next = the ruins", n)
n = L.GoalTiers(11, 0, 2, "Halo", nil)
check(n == string.format("Next: Lv %d · Skeleton Ruins", ruins), "Z learned: no Z step", n)
Sk.ZEnabled = false
n = L.GoalTiers(2, 1, 0, "Halo", nil)
check(n == string.format("Next: Lv %d · Goblin Woods", woods), "after a rebirth: no skill steps", n)
n = L.GoalTiers(30, 0, 1, "Halo", nil)
check(n == string.format("Next: Lv %d · Rebirth", rb0), "past the ruins: the rebirth level", n)
n = L.GoalTiers(rb0 - 2, 0, 1, "Halo", { NextGoal = true, GoalKind = "Rebirth" })
check(n == nil, "the tracker already says the rebirth: no Next line", tostring(n))
n = L.GoalTiers(52, 1, 1, "Halo", nil)
check(n == string.format("Next: Lv %d · Rebirth", Config.RebirthLevel(1)), "after a rebirth: its own rebirth level", n)
G.Enabled = false
n, b = L.GoalTiers(1, 0, 0, "Halo", nil)
check(n == nil and b == nil, "switched off: no tiers", tostring(n))
G.Enabled = true
TOUCH = false
check(L.GoalTiersOn() == true, "PC: tiers 2-3 on", "")
TOUCH = true
check(L.GoalTiersOn() == false, "phones: tier 1 only", "")
G.TouchTiers = 3
check(L.GoalTiersOn() == true, "phones with TouchTiers 3: on", "")
G.TouchTiers = 1
TOUCH = false

------------------------------------------------------------------ 2. KO screen 'This run'
local function obj(c)
	local o = { ClassName = c, Children = {} }
	setmetatable(o, { __newindex = function(t, k, v)
		rawset(t, k, v)
		if k == "Parent" and type(v) == "table" and v.Children then table.insert(v.Children, t) end
	end })
	o.Destroy = function(self)
		local p = rawget(self, "Parent")
		if p then local i = table.find(p.Children, self) if i then table.remove(p.Children, i) end end
		rawset(self, "Parent", nil)
	end
	return o
end
local GUI = obj("ScreenGui")
local FX = { OnClientEvent = signal() }
local ATTR = {}
local SIGS = {}
local ME = { UserId = 7, CharacterAdded = signal() }
function ME:GetAttribute(k) return ATTR[k] end
function ME:GetAttributeChangedSignal(k) SIGS[k] = SIGS[k] or signal() return SIGS[k] end
local function setAttr(k, v) ATTR[k] = v if SIGS[k] then SIGS[k]:Fire() end end
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game = { GetService = function(_, nm)
	if nm == "Players" then return { LocalPlayer = ME } end
	if nm == "ReplicatedStorage" then return { WaitForChild = function() return { WaitForChild = function(_, m) return m end } end } end
	if nm == "TweenService" then return { Create = function() return { Play = function() end } end } end
	return {}
end }
env.require = function(m)
	if m == "Config" then return Config end
	if m == "Net" then return { Get = function(x) return x == "Fx" and FX or nil end } end
	return { Warn = function(...) print("WARN", ...) end, FormatNumber = function(v) return tostring(v) end }
end
env.Instance = { new = obj }
env.typeof = function(v) if type(v) == "table" and v.ClassName then return "Instance" end return typeof(v) end
local SPAWN = false
local DELAYED = {}
env.task = { spawn = function(fn, ...) if SPAWN then fn(...) end end, wait = function() end,
	delay = function(_, fn) table.insert(DELAYED, fn) end }
local function runDelayed() local list = DELAYED DELAYED = {} for _, fn in list do fn() end end
local df = assert(loadstring(DS_SOURCE, "=DeathScreen"))
setfenv(df, env)
local DS = df()
DS.Init({ UIKit = { Gui = GUI, ReducedMotion = function() return true end } })

local x1 = Config.XPToNext(1)
check(DS.TotalXP(1, 7) == 7 and DS.TotalXP(2, 3) == x1 + 3, "TotalXP adds the levels below", DS.TotalXP(2, 3))
local got = { XP = 0, Gold = 0, Items = 0, Fame = 0 }
DS.Tally(got, { XP = 10, Gold = 100, Fame = 2, Faction = "Halo" }, { XP = 40, Gold = 90, Fame = 5, Faction = "Halo" })
check(got.XP == 30 and got.Gold == 0 and got.Fame == 3, "gains only (spent gold never counts)", got.XP .. "/" .. got.Gold .. "/" .. got.Fame)
DS.Tally(got, { XP = 40, Gold = 90, Faction = "Halo" }, { XP = 0, Gold = 500, Faction = "Horns" })
check(got.XP == 30 and got.Gold == 0, "a side switch only re-bases", got.Gold)
DS.Tally(got, { XP = 40, Gold = 90, Faction = "Halo", Rebirths = 0 }, { XP = 0, Gold = 500, Faction = "Halo", Rebirths = 1 })
check(got.Gold == 0, "a rebirth only re-bases", got.Gold)
DS.Tally(got, { XP = nil, Gold = 5, Faction = "Halo" }, { XP = 50, Gold = 5, Faction = "Halo" })
check(got.XP == 30, "an unknown old value adds nothing", got.XP)
local gl = DS.GotLines({ XP = 120, Gold = 45, Items = 3, Fame = 2 }, "Halo")
check(#gl == 4 and gl[1] == "+120 XP" and gl[2] == "+45 gold" and gl[3] == "+3 items" and gl[4] == "+2 Honor",
	"four lines: XP, gold, items, Honor", table.concat(gl, " | "))
gl = DS.GotLines({ XP = 0, Gold = 0, Items = 1, Fame = 4 }, "Horns")
check(#gl == 2 and gl[1] == "+1 item" and gl[2] == "+4 Mischief", "only what grew; one item; the Legion's Mischief", table.concat(gl, " | "))
gl = DS.GotLines({ XP = 0, Gold = 0, Items = 0, Fame = 9 }, "Neutral")
check(#gl == 0, "the Artisan Guild: no fame line", #gl)
local lines = DS.Lines({ By = "Monster", Name = "Slime" }, 2, { XP = 0, Gold = 0, Items = 0, Fame = 0 }, "Halo")
check(lines.GotTitle == nil and lines.Got1 == nil, "nothing grew: no 'This run' block", tostring(lines.GotTitle))
lines = DS.Lines({ By = "Monster", Name = "Slime" }, 2, { XP = 5, Gold = 0, Items = 0, Fame = 0 }, "Halo")
check(lines.GotTitle == "This run" and lines.Got1 == "+5 XP" and lines.Got2 == nil, "This run + one line", tostring(lines.Got1))

-- the whole flow on doubles: a run, gains, a deposit, a KO
ATTR = { Level = 1, XP = 0, CarriedGold = 0, BankGold = 100, Honor = 0, Faction = "Halo", Rebirths = 0 }
SPAWN = true
DS.Start()
SPAWN = false
setAttr("XP", x1 - 2)
setAttr("Level", 2) setAttr("XP", 3) -- a level up: Level then XP, read together
setAttr("CarriedGold", 40)
runDelayed()
setAttr("CarriedGold", 0) setAttr("BankGold", 140) -- a deposit: pouch -> vault (net 0)
runDelayed()
setAttr("Honor", 2)
setAttr("BankGold", 165) -- an angel courier puts 25 gold in my vault
FX.OnClientEvent:Fire("Loot", { Items = { { Item = "Scroll", N = 2 }, { Potion = "HP" } } })
FX.OnClientEvent:Fire("Loot", "bad")
setAttr("CarriedGold", 30) -- not read yet: the KO reads it (Flush)
FX.OnClientEvent:Fire("KO", { By = "Monster", Name = "King Slime", RespawnIn = 3, Lost = 30 })
local frame = GUI.Children[1]
local box = frame and frame.Children[1]
local texts = {}
for _, c in box and box.Children or {} do if c.ClassName == "TextLabel" and c.Visible then texts[c.Name] = c.Text end end
check(texts.GotTitle == "This run", "the KO screen shows 'This run'", tostring(texts.GotTitle))
check(texts.Got1 == ("+" .. (x1 + 3) .. " XP"), "XP across the level up", tostring(texts.Got1))
check(texts.Got2 == "+95 gold", "gold: the pouch gains, the vault courier, the deposit not twice, the last one read at the KO", tostring(texts.Got2))
check(texts.Got3 == "+3 items" and texts.Got4 == "+2 Honor", "items from my Fx Loot, Honor", tostring(texts.Got3) .. " / " .. tostring(texts.Got4))
check(texts.Lost == "Lost 30 pouch gold" and texts.Back == "Back in 3 s", "the old lines stay", tostring(texts.Lost))
setAttr("CarriedGold", 0) -- the KO took the pouch
runDelayed()
ME.CharacterAdded:Fire({})
check(not DS.IsOpen(), "my next character closes it", "")
setAttr("XP", 13)
runDelayed()
FX.OnClientEvent:Fire("KO", { By = "Fall", RespawnIn = 3 })
frame = GUI.Children[1]
box = frame and frame.Children[1]
texts = {}
for _, c in box and box.Children or {} do if c.ClassName == "TextLabel" and c.Visible then texts[c.Name] = c.Text end end
check(texts.Got1 == "+10 XP" and texts.Got2 == nil, "a new character starts a new run (only its own XP)", tostring(texts.Got1) .. " / " .. tostring(texts.Got2))

------------------------------------------------------------------ 3. faction picker lines
local FactionPicker = {}
local ff = assert(loadstring(FP_SOURCE, "=FactionPicker"))
setfenv(ff, setmetatable({ FactionPicker = FactionPicker, Config = Config }, { __index = getfenv() }))
ff()
for _, side in { "Halo", "Horns", "Neutral" } do
	local ls = FactionPicker.ChangeLines(side)
	local home = Config.Zones[Config.HomeZoneId(side)]
	local guide = Config.Tutorial.Welcome[side]
	check(#ls == 3, side .. ": three lines", #ls)
	check(ls[1] and home and string.find(ls[1], home.Name, 1, true) ~= nil, side .. ": line 1 = my home town's name", ls[1])
	check(ls[3] and guide and string.find(ls[3], guide.Name, 1, true) ~= nil, side .. ": line 3 = my guide's name", ls[3])
	local ascii = true
	for _, l in ls do if string.find(l, "[\128-\255]") then ascii = false end end
	check(ascii, side .. ": plain English", "")
end
check(#FactionPicker.ChangeLines("None") == 0, "no side: no lines", "")
print(("GOALCHIPS_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

MUTATIONS = [
    ("HUD", "Next repeats the tracker's step", "if (shown == nil or s.At > shown) and", "if true and"),
    ("HUD", "a reached level still shown", "if at and text and at > level then", "if at and text then"),
    ("HUD", "Z / X ignore their switch", '(s.Slot == "Q" or skills[s.Slot .. "Enabled"] == true)', "true"),
    ("HUD", "skills after a rebirth", "if i and need and rebirths < 1 and", "if i and need and"),
    ("HUD", "learned skills shown", "and i > skillSlots and", "and"),
    ("HUD", "the farthest step", "(best == nil or s.At < best.At)", "(best == nil or s.At > best.At)"),
    ("HUD", "phones show all tiers", "(not IS_TOUCH or (tonumber(G.TouchTiers) or 1) >= 2)", "true"),
    ("HUD", "Neutral leans on a format error", "local big = type(sideWord) == \"string\" and fmt(W.Big, sideWord) or nil",
     "local big = fmt(W.Big, W[faction])"),
    ("HUD", "the switch ignored", 'if type(G) ~= "table" or G.Enabled ~= true then return nil, nil end',
     'if type(G) ~= "table" then return nil, nil end'),
    ("DS", "spending counts", "and new[k] > old[k] then got[k]", "then got[k]"),
    ("DS", "a side switch adds", "if old.Faction ~= new.Faction or old.Rebirths ~= new.Rebirths then return end", ""),
    ("DS", "no Flush at the KO", "\tDeathScreen.Flush() -- A23-167 ③: the last change before the KO counts\n", ""),
    ("DS", "loot ignored", "G.Items += math.max(1, math.floor(tonumber(g.N) or 1))", "G.Items += 0"),
    ("DS", "never a new run", "LocalPlayer.CharacterAdded:Connect(function() DeathScreen.ResetRun() end)", "local _ = 1"),
    ("DS", "pouch only (vault ignored)", "(carried or 0) + (bank or 0)", "(carried or 0)"),
    ("DS", "Mischief for the Knights", 'faction == "Halo" and "GotHonor" or faction == "Horns" and "GotMischief"',
     'faction == "Halo" and "GotMischief" or faction == "Horns" and "GotMischief"'),
    ("CONFIG", "a wrong guide name", '"Your guide: Magpie"', '"Your guide: Mags"'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def cut(text: str, start: str, end: str) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(end, a)
    return text[a:b + len(end)] if b >= 0 else ""


def run(src: dict) -> tuple[int, int, str]:
    hud = "\n".join(cut(src["HUD"], s, e) for s, e in HUD_CUTS)
    fp = cut(src["FP"], *FP_CUT)
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal HUD_SOURCE = " + lua_str(hud)
            + "\nlocal DS_SOURCE = " + lua_str(src["DS"]) + "\nlocal FP_SOURCE = " + lua_str(fp) + "\n" + FIXTURE)
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "goal_chips.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=180)
    out = proc.stdout + proc.stderr
    m = re.search(r"GOALCHIPS_SUMMARY checks=(\d+) failed=(\d+)", out)
    return (int(m[1]) if m else 0), (int(m[2]) if m else 1), out


def tier_block(h: str) -> str:
    a = h.find("local tiers = {}")
    return h[a:h.find("tiers[3].TextColor3", a)] if a >= 0 else ""


def statics(src: dict) -> list[tuple[str, bool]]:
    h, ds, fp = src["HUD"], src["DS"], src["FP"]
    return [
        ("SetTracker refreshes the tiers", "\tt.Frame.Visible = label ~= nil\n\tL.RefreshGoalTiers(e)\n" in h),
        ("level / rebirths / skills / side refresh the tiers",
         'UIKit.OnAttr({ "Level", "Rebirths", "SkillSlots", "Faction" }, function() L.RefreshGoalTiers() end)' in h),
        ("the tiers draw only while on and the tracker shows", "if L.GoalTiersOn() and t.Frame.Visible then" in h),
        ("the tracker's room on small PC windows counts the tiers",
         "+ (L.GoalTiersOn() and (math.ceil(L.GoalTierSize(bodySize) * 1.2) * (1 + L.TierLines) + T.Gap * 2) or 0)" in h
         and "L.TierLines = 2" in h),
        ("the tiers sit under the progress line (LayoutOrder 4-5)", "LayoutOrder = 2 + i," in h),
        # 최종 검수 10/14 (user photo): a tier wraps (two lines at most), never a '…'; its box = its drawn text
        ("the tiers wrap, never cut, sized from their drawn text; tier 3 in my side's colour",
         "TextWrapped = true, TextTruncate = Enum.TextTruncate.None," in h and "Enum.TextTruncate.AtEnd" not in tier_block(h)
         and 'l:GetPropertyChangedSignal("TextBounds"):Connect(function() L.FitTierHeight(l) end)' in h
         and "local h = math.ceil(l.TextBounds.Y / math.max(0.05, currentScale()))" in h
         and 'local col = (f == "Halo" or f == "Horns") and factionColor(f) or ac("GoldText", Theme.Gold)' in h
         and 'Halo = "Win the Crown", Horns = "Win the Crown",' in src["CONFIG"]),
        ("the KO screen draws the Got labels", 'S.Labels["Got" .. i] = label(ui, box, "Got" .. i, look.GotSize, "Body", 4 + i)' in ds),
        ("the KO screen paints the run", "DeathScreen.Lines(S.Data, left, G, S.Faction)" in ds),
        ("the run's attributes are watched", re.search(r'for _, k in \{ "Level", "XP", "CarriedGold", "BankGold", "Honor", "Infamy", '
                                                       r'"Faction", "Rebirths" \} do\n\t+LocalPlayer:GetAttributeChangedSignal\(k\):Connect\(onAttr\)', ds) is not None),
        ("the picker builds the lines under each side's card", "\tbuildChanges(c, id)\n" in fp),
        ("the picker keeps room for the lines", "areaH = math.max(1, areaH - chH)" in fp
         and "local canvasH = math.ceil(cardH * LAY.BalancedHeight) + 2 * lift + chH" in fp),
    ]


STATIC_MUTATIONS = [
    ("HUD", "a tier cut with '…' again", "TextWrapped = true, TextTruncate = Enum.TextTruncate.None,",
     "TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd,"),
    ("HUD", "a tier's box ignores its drawn text", 'l:GetPropertyChangedSignal("TextBounds"):Connect(function() L.FitTierHeight(l) end)', ""),
    ("HUD", "the room counts one line for tier 3", "* (1 + L.TierLines) + T.Gap * 2) or 0)", "* 2 + T.Gap * 2) or 0)"),
    ("HUD", "tier 3 not in my side's colour", 'local col = (f == "Halo" or f == "Horns") and factionColor(f) or ac("GoldText", Theme.Gold)',
     'local col = ac("GoldText", Theme.Gold)'),
    ("CONFIG", "the long crown line again", 'Halo = "Win the Crown", Horns = "Win the Crown",',
     'Halo = "Win the Crown for the Knights", Horns = "Win the Crown for the Legion",'),
    ("HUD", "no tier refresh with the tracker", "\tt.Frame.Visible = label ~= nil\n\tL.RefreshGoalTiers(e)\n", "\tt.Frame.Visible = label ~= nil\n"),
    ("FP", "no room for the lines", "areaH = math.max(1, areaH - chH)", "areaH = math.max(1, areaH)"),
    ("DS", "the KO screen ignores the run", "DeathScreen.Lines(S.Data, left, G, S.Faction)", "DeathScreen.Lines(S.Data, left)"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    found = all(cut(src["HUD"], s, e) for s, e in HUD_CUTS) and cut(src["FP"], *FP_CUT) != ""
    checks, failed, out = run(src)
    print(out.strip())
    st = [{"check": n, "ok": ok} for n, ok in statics(src)]
    for s in st:
        print(("STATIC_OK  " if s["ok"] else "STATIC_FAIL ") + s["check"])
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
    for key, name, old, new in STATIC_MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = not all(ok for _, ok in statics(m))
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    ok = found and failed == 0 and checks > 0 and all(s["ok"] for s in st) and all(m["caught"] for m in muts)
    status = "passed" if ok else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "static": st, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
