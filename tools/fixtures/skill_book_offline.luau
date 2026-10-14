-- BB9 스킬 창 (게임성 개발 1, 2026-10-11): runs the real Config.luau and the real SkillBook.luau
-- (tools/test_skill_book.py) on small doubles: Players.LocalPlayer attributes, RunService / UserInputService, a Panels
-- registry that builds the window with a recording kit, UIKit.ArtImage / ArtId, Keybinds.Label.
-- Inputs: CONFIG_SOURCE, BOOK_SOURCE. Every check is named and counted.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end

local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()
local W = Config.Skills.Text

-- doubles
local NOW = 1000
local attrs = { Class = "Warrior", Faction = "Halo", Level = 6, SkillSlots = 1, Rebirths = 0, Mana = 100,
	SkillReadyAt = 0, WeaponTier = 1, FallMarks = 0, RedeemMarks = 0 }
local player = { GetAttribute = function(_, k) return attrs[k] end }
local UIS = { KeyboardEnabled = true }
local Util = { Warn = function(...) print("WARN", ...) end, Now = function() return NOW end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function(_, n) return shared end, FindFirstChild = function() return nil end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	if n == "RunService" then return { IsStudio = function() return false end } end
	if n == "UserInputService" then return UIS end
	return nil
end }
local mods = { Config = Config, Util = Util }
local made = {}
local Instance = { new = function(c)
	local o = { ClassName = c }
	table.insert(made, o)
	return o
end }

local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance = game, Instance
env.require = function(n) return mods[n] end
local bf = assert(loadstring(BOOK_SOURCE, "=SkillBook"))
setfenv(bf, env)
local SkillBook = bf()

local reg = {}
local buttons, opened = {}, {}
local order = 0
local kit = {
	Font = "Font.Gotham", Theme = { Gold = "gold", Text = "text", SubText = "sub", Good = "good", Bad = "bad" },
	Palette = { Button = "button", DarkText = "dark" },
	NextOrder = function() order += 1 return order end,
	Button = function(parent, text, color, size, onClick)
		local b = { ClassName = "TextButton", Text = text, OnClick = onClick, Parent = parent }
		table.insert(buttons, b)
		return b
	end,
	Open = function(id, arg) table.insert(opened, { id, arg }) end,
}
local TRAVEL_ON = true -- A23-182: the Travel window = Fast Travel subscribers (Panels.TravelOn)
local panels = { Register = function(id, opts) reg[id] = opts return true end, TravelOn = function() return TRAVEL_ON end }
local arts = {}
local UIKit = {
	ArtId = function(name) return arts[name] end,
	StyleText = function(l, style)
		l.Style = style
		l.TextColor3 = "white" -- the real style paints the words; the window puts its colour back
		return l
	end,
	ArtImage = function(name, props)
		local o = { ClassName = "ImageLabel", Image = name, Name = props.Name }
		table.insert(made, o)
		return o
	end,
}
local keyLabels = { Attack = "F", SkillQ = "Z", SkillZ = "X", SkillX = "C" }
local Keybinds = { Label = function(a) return keyLabels[a] or "" end }
SkillBook.Init({ Panels = panels, UIKit = UIKit, Keybinds = Keybinds })

local function texts()
	local out = {}
	for _, o in made do
		if o.ClassName == "TextLabel" then table.insert(out, o) end
	end
	return out
end
local function textOf(name)
	for _, o in texts() do if o.Name == name then return o end end
	return nil
end
local function hasText(s)
	for _, o in texts() do if o.Text == s then return true end end
	return false
end
local function findText(pat)
	for _, o in texts() do if type(o.Text) == "string" and string.find(o.Text, pat, 1, true) then return o end end
	return nil
end
local function btn(text)
	for _, b in buttons do if b.Text == text then return b end end
	return nil
end
local update = nil
local function open()
	table.clear(buttons)
	table.clear(made)
	table.clear(opened)
	update = reg.Skills.Build({ ClassName = "ScrollingFrame" }, kit)
end
local function rowOf(rows, slot)
	for _, r in rows do if r.Slot == slot then return r end end
	return nil
end
local function ctx(t)
	local c = { Class = "Warrior", Faction = "Halo", Level = 30, SkillSlots = 3, Rebirths = 0, Mana = 100, Now = NOW,
		Ready = {}, Tier = 1 }
	for k, v in t or {} do c[k] = v end
	return c
end

-- 0. registered
check(reg.Skills ~= nil and SkillBook.IsReady(), "the window \"Skills\" is registered (the HUD's Skills tile / K open it)")
local rb = reg.Skills and reg.Skills.Rebuild or {}
check(rb.Class and rb.Faction and rb.Level and rb.SkillSlots and rb.Rebirths and rb.WeaponTier,
	"it rebuilds when the class / faction / level / slots / rebirths / weapon change")
check(not rb.Mana and not rb.SkillReadyAt, "MP and cooldowns repaint in place (no rebuild)")
check(reg.Skills.Title == "Skills", "the title is Skills", reg.Skills.Title)
check(reg.Skills.KeepScroll == true, "a level up / new weapon redraw keeps the scroll (검수 10/11)", reg.Skills.KeepScroll)

-- 1. which rows
local rows = SkillBook.Rows(ctx())
check(#rows == 2 and rows[1].Slot == "Attack" and rows[2].Slot == "Q", "flags off: the attack + Q only (Z / X hidden like SkillBar)", #rows)
rows = SkillBook.Rows(ctx({ Preview = true }))
check(#rows == 4 and rows[3].Slot == "Z" and rows[4].Slot == "X", "preview: attack, Q, Z, X in order", #rows)

-- 2. names and the faction line (A23-116)
local q = rowOf(SkillBook.Rows(ctx()), "Q")
check(q.Name == "Halo Slam", "Halo Warrior Q is Halo Slam", q.Name)
check(q.FactionLine == W.QZHalo, "Halo Q has the QZHalo line", q.FactionLine)
check(string.find(q.Numbers, "Costs 20 MP", 1, true) and string.find(q.Numbers, "3 s cooldown", 1, true)
	and string.find(q.Numbers, "Area 9", 1, true) and string.find(q.Numbers, "Hit x6", 1, true) ~= nil,
	"Q numbers: MP 20 · 3 s · area 9 · x6", q.Numbers)
q = rowOf(SkillBook.Rows(ctx({ Class = "Mage", Faction = "Horns" })), "Q")
check(q.Name == "Purple Pop" and q.FactionLine == W.QZHorns, "Horns Mage Q is Purple Pop with the QZHorns line", q.Name)
local all = SkillBook.Rows(ctx({ Preview = true, Faction = "Horns" }))
check(rowOf(all, "Z").FactionLine == W.QZHorns and rowOf(all, "X").FactionLine == W.XHorns,
	"Horns: Z has QZHorns, X has XHorns", rowOf(all, "X").FactionLine)
all = SkillBook.Rows(ctx({ Preview = true, Faction = "Halo", Class = "Archer" }))
check(rowOf(all, "X").FactionLine == W.XHalo and rowOf(all, "X").Name == "Light Step", "Halo Archer X is Light Step with XHalo")
check(string.find(rowOf(all, "Z").Numbers, "Line 40", 1, true) ~= nil, "a Line skill shows its length", rowOf(all, "Z").Numbers)
check(string.find(rowOf(all, "X").Numbers, "Hop 10", 1, true) ~= nil, "a Hop skill shows its hop", rowOf(all, "X").Numbers)
all = SkillBook.Rows(ctx({ Preview = true, Faction = "Neutral", Class = "Warrior" }))
check(rowOf(all, "Q").Name == "Hammer Quake" and rowOf(all, "Q").FactionLine == nil, "the blacksmith's Q has no faction line")
check(rowOf(all, "X").FactionLine == W.XArtisan, "the artisan X has the XArtisan line", rowOf(all, "X").FactionLine)
all = SkillBook.Rows(ctx({ Preview = true, Faction = "Halo", Class = "Mage" }))
check(string.find(rowOf(all, "Z").Numbers, "Jumps 3", 1, true) and string.find(rowOf(all, "X").Numbers, "Field 5 s", 1, true) ~= nil,
	"Chain (4 targets = 3 jumps, Config.SkillNumbers) / Field shapes", rowOf(all, "X").Numbers)
check(rowOf(SkillBook.Rows(ctx({ Faction = "None" })), "Q").FactionLine == nil, "no side yet: no faction line")

-- 3. icons (the SkillBar order)
q = rowOf(SkillBook.Rows(ctx({ Class = "Mage", Faction = "Horns" })), "Q")
check(q.Icons[1] == "Skill_Mage_Q_Horns" and q.Icons[2] == "Skill_Mage_Q", "icon: own faction icon first, then the kit's", q.Icons[1])
q = rowOf(SkillBook.Rows(ctx({ Class = "Mage", Faction = "Neutral" })), "Q")
check(q.Icons[2] == "Skill_Alchemist_Q" and q.Icons[3] == "Skill_Mage_Q", "the alchemist borrows the mage icon", q.Icons[3])

-- 4. the live state
local function stateAt(c, slot)
	local r = rowOf(SkillBook.Rows(c), slot)
	return SkillBook.State(r, c)
end
local s, k = stateAt(ctx({ Level = 3, SkillSlots = 0 }), "Q")
check(s == string.format(W.UnlocksAt, 5) and k == "lock", "Lv3 with no skill: Unlocks at Lv5", s)
s, k = stateAt(ctx({ Level = 1, SkillSlots = 1 }), "Q")
check(k == "ready", "a saved skill slot stays learned at Lv1 (rebirth / class change)", k)
s, k = stateAt(ctx({ Level = 1, SkillSlots = 0, Rebirths = 1, Preview = true }), "X")
check(k == "ready", "after a rebirth all three are learned", k)
s, k = stateAt(ctx({ Level = 16, SkillSlots = 2, Preview = true }), "X")
check(k == "lock" and s == string.format(W.UnlocksAt, 25), "X waits for Lv25", s)
s, k = stateAt(ctx({ Ready = { Q = NOW + 2.4 } }), "Q")
check(s == "2.4 s" and k == "wait", "cooling down: seconds left", s)
s, k = stateAt(ctx({ Mana = 10 }), "Q")
check(s == W.NeedMP and k == "mp", "MP below the cost: Need MP", s)
s, k = stateAt(ctx({ Mana = 20 }), "Q")
check(s == W.Ready and k == "ready", "enough MP, no cooldown: Ready", s)
check(SkillBook.State(SkillBook.Rows(ctx())[1], ctx()) == nil, "the attack row has no state")

-- 5. the attack row
local a = SkillBook.Rows(ctx({ Tier = 0 }))[1]
check(a.Name == "Punch" and a.Icons[1] == "IconAttack", "bare hands: Punch", a.Name)
a = SkillBook.Rows(ctx({ Tier = 1 }))[1]
check(a.Name == "Attack" and string.find(a.Numbers, "Hits all in front", 1, true) ~= nil, "Warrior: hits all in front", a.Numbers)
check(a.Icons[1] == "Weapon_Warrior_T1_Halo" and a.Icons[2] == "Weapon_Warrior_T1", "the attack icon = my weapon", a.Icons[1])
a = SkillBook.Rows(ctx({ Class = "Mage", Tier = 1 }))[1]
check(string.find(a.Numbers, "2 MP per hit", 1, true) and string.find(a.Numbers, "Blast 7", 1, true) ~= nil, "Mage: MP per hit + blast", a.Numbers)
a = SkillBook.Rows(ctx({ Class = "Archer", Tier = 1 }))[1]
check(string.find(a.Numbers, "Hits 2", 1, true) and string.find(a.Numbers, "0.5 s per hit", 1, true) ~= nil, "Archer: 2 targets, 0.5 s", a.Numbers)
a = SkillBook.Rows(ctx({ Class = "Archer", Faction = "Neutral", Tier = 2 }))[1]
check(a.Icons[2] == "Weapon_Tamer_T2", "the tamer's attack icon is the tamer weapon", a.Icons[2])

-- 6. passive
local p = SkillBook.Passive(ctx())
check(#p >= 2 and p[1].Title == "Paladin" and p[2].Title == Config.Factions.Halo.Name and #p[2].Lines == #Config.Factions.Halo.Perks,
	"passive: class stats + my faction's perks", p[2] and p[2].Title)
p = SkillBook.Passive(ctx({ Faction = "None" }))
check(#p == 1, "no side yet: class stats only", #p)
p = SkillBook.Passive(ctx({ Faction = "Horns", FallMarks = 2, RedeemMarks = 1 }))
local marks = p[#p]
check(marks and marks.Lines[1] == "Fall marks x2: gold +10%" and marks.Lines[2] == "Redeem marks x1: XP +5%", "marks: count and bonus",
	marks and marks.Lines[1])

-- 7. drawing
arts["Skill_Warrior_Q"] = "rbxassetid://1"
attrs.Level, attrs.SkillSlots, attrs.Mana = 6, 1, 100
open()
check(type(update) == "function", "the build returns an update")
check(findText("Halo Slam  [Z]") ~= nil, "keyboard: the name shows its key", "")
check(findText(W.QZHalo) ~= nil and findText(W.QZHalo).TextColor3 == Config.Factions.Halo.Color, "the faction line in the side's colour")
local st = textOf("StateText")
check(st and st.Text == W.Ready and st.TextColor3 == "good", "Q reads Ready", st and st.Text)
local changeKeys = btn("Change keys")
check(changeKeys ~= nil, "keyboards get [Change keys]")
if changeKeys then changeKeys.OnClick() end
check(opened[1] and opened[1][1] == "Settings" and type(opened[1][2]) == "table" and opened[1][2].Tab == "Keys",
	"[Change keys] opens Settings on Keys", opened[1] and opened[1][1])
local icons = 0
for _, o in made do if o.ClassName == "ImageLabel" and o.Image == "Skill_Warrior_Q" then icons += 1 end end
check(icons == 1, "the Q icon falls back to the art that exists", icons)
local pl = findText(Config.Factions.Halo.Perks[1])
check(findText("Passive") ~= nil and pl ~= nil and pl.Name == "PassiveLines" and string.find(pl.Text, Config.Factions.Halo.Perks[1], 1, true) == 1
	and string.find(pl.Text, Config.Factions.Halo.Perks[2], 1, true) ~= nil, "the passive part is drawn (one paragraph per section)")
-- the text floors (검수 10/11): every label goes through UIKit.StyleText and keeps its own colour
local unstyled, titles, bodies = 0, 0, 0
for _, o in texts() do
	if o.Style == "Title" then titles += 1 elseif o.Style == "Body" then bodies += 1 else unstyled += 1 end
end
check(unstyled == 0 and titles > 0 and bodies > 0, "every label takes a UIKit text style (real px floors)", unstyled)
check(textOf("Name").Style == "Title" and textOf("Numbers").Style == "Body" and pl.Style == "Body",
	"names Title, numbers and passive lines Body", textOf("Numbers").Style)
check(findText(W.QZHalo).TextColor3 == Config.Factions.Halo.Color, "the style keeps the faction line colour")
-- layout (main photo skillbook_v2: 17 du too tall): the attack row has no state column, a skill row a narrow one
local stateFrames = {}
for _, o in made do if o.ClassName == "Frame" and o.Name == "State" then table.insert(stateFrames, o) end end
check(#stateFrames == 1, "only the skill row has a state column (not the attack row)", #stateFrames)
local sw = stateFrames[1] and stateFrames[1].Size and stateFrames[1].Size.Args[2]
check(sw == 110, "a learned skill's state column is narrow (110)", sw)
local infos = {}
for _, o in made do if o.ClassName == "Frame" and o.Name == "Info" then table.insert(infos, o.Size.Args[2]) end end
check(infos[1] == -(64 + 12) and infos[2] == -(64 + 110 + 24), "the attack words take the free room", infos[1])
-- live repaint
attrs.Mana = 5
update()
check(st.Text == W.NeedMP and st.TextColor3 == "bad", "MP drops: the open window says Need MP", st.Text)
attrs.Mana, attrs.SkillReadyAt = 100, NOW + 1.5
update()
check(st.Text == "1.5 s", "after a cast: seconds left", st.Text)
attrs.SkillReadyAt = 0
-- 검수 10/11: no "[None]" - a key that is not live, or a slot not learned yet, shows no key
keyLabels.SkillQ = Config.Keybinds.None
open()
check(findText("[" .. Config.Keybinds.None .. "]") == nil and hasText("Halo Slam"), "a key that is not live shows no '[None]'")
keyLabels.SkillQ = "Z"
attrs.Level, attrs.SkillSlots = 2, 0
open()
check(findText("Halo Slam  [Z]") == nil and hasText("Halo Slam"), "a slot not learned yet shows no key (keyboards)")
-- locked + touch
UIS.KeyboardEnabled = false
TRAVEL_ON = false
open()
check(btn(W.WhereToHunt) == nil, "no Fast Travel subscription: no [Where to hunt] (A23-182)")
TRAVEL_ON = true
open()
local hunt = btn(W.WhereToHunt)
check(hunt ~= nil, "a slot not learned: [Where to hunt]")
if hunt then hunt.OnClick() end
check(opened[1] and opened[1][1] == "Travel", "[Where to hunt] opens Travel (its Recommended zone)", opened[1] and opened[1][1])
check(btn("Change keys") == nil, "touch: no [Change keys]")
local lockedW = nil
for _, o in made do if o.ClassName == "Frame" and o.Name == "State" then lockedW = o.Size.Args[2] end end
check(lockedW == 150, "a locked row's column fits [Where to hunt] (150)", lockedW)
check(findText("[Z]") == nil and hasText("Halo Slam"), "touch: no key in the name")
UIS.KeyboardEnabled = true
attrs.Level, attrs.SkillSlots = 6, 1

print(string.format("SKILL_BOOK_SUMMARY checks=%d failed=%d", checks, failed))
