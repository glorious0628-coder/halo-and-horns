-- BB8 Hero window (CharacterUI, 게임성 개발 1, 2026-10-12): runs the real Config.luau and the real CharacterUI.luau
-- (tools/test_character_ui.py) on small doubles: Players.LocalPlayer attributes, a recording Instance tree, a Panels registry
-- that builds the window with a recording kit, UIKit art doubles, a fake GearSlots, a fake PetWindow. Inputs: CONFIG_SOURCE,
-- UI_SOURCE. Every check is named.
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
vmt.__index = vmt
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function ud(sx, ox, sy, oy) return { X = { Scale = sx or 0, Offset = ox or 0 }, Y = { Scale = sy or 0, Offset = oy or 0 } } end
local UDim2 = {
	new = function(sx, ox, sy, oy) return ud(sx, ox, sy, oy) end,
	fromOffset = function(x, y) return ud(0, x, 0, y) end,
	fromScale = function(x, y) return ud(x, 0, y, 0) end,
}
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = UDim2, UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, cfgEnv)
local Config = fn()

------------------------------------------------------------------ an Instance tree double
local omt = {}
local function newObj(class, props)
	local o = setmetatable({ __p = { ClassName = class, Name = class, Children = {}, ZIndex = 1, CanvasPosition = vec(0, 0),
		AbsoluteSize = vec(0, 0) } }, omt)
	for k, v in props or {} do o[k] = v end
	return o
end
local ISA = {
	TextButton = { GuiButton = true, GuiObject = true }, ImageButton = { GuiButton = true, GuiObject = true },
	TextLabel = { GuiObject = true }, ImageLabel = { GuiObject = true }, Frame = { GuiObject = true },
	ScrollingFrame = { GuiObject = true },
}
omt.__index = function(o, k)
	local methods = {
		GetChildren = function(self) return table.clone(rawget(self, "__p").Children) end,
		Destroy = function(self)
			local p = rawget(self, "__p")
			if p.Parent then
				local kids = rawget(p.Parent, "__p").Children
				local i = table.find(kids, self)
				if i then table.remove(kids, i) end
			end
			p.Parent = nil
			p.Destroyed = true
		end,
		IsA = function(self, c)
			local cls = rawget(self, "__p").ClassName
			return cls == c or (ISA[cls] ~= nil and ISA[cls][c] == true)
		end,
		FindFirstChild = function(self, name)
			for _, ch in rawget(self, "__p").Children do if ch.Name == name then return ch end end
			return nil
		end,
		FindFirstChildOfClass = function(self, c)
			for _, ch in rawget(self, "__p").Children do if ch.ClassName == c then return ch end end
			return nil
		end,
	}
	if methods[k] then return methods[k] end
	return rawget(o, "__p")[k]
end
omt.__newindex = function(o, k, v)
	local p = rawget(o, "__p")
	if k == "Parent" then
		if p.Destroyed and v ~= nil then error("The Parent property of " .. tostring(p.Name) .. " is locked") end
		if p.Parent then
			local kids = rawget(p.Parent, "__p").Children
			local i = table.find(kids, o)
			if i then table.remove(kids, i) end
		end
		p.Parent = v
		if v then table.insert(rawget(v, "__p").Children, o) end
		return
	end
	p[k] = v
end
local Instance = { new = function(c) return newObj(c) end }

local function descendants(root, out)
	out = out or {}
	for _, ch in rawget(root, "__p").Children do
		table.insert(out, ch)
		descendants(ch, out)
	end
	return out
end
local function find(root, name)
	for _, d in descendants(root) do if d.Name == name then return d end end
	return nil
end
local function findAll(root, pat)
	local out = {}
	for _, d in descendants(root) do
		if type(d.Name) == "string" and string.find(d.Name, pat) then table.insert(out, d) end
	end
	return out
end
local function inside(root, obj)
	local p = obj
	while p do
		if rawequal(p, root) then return true end
		p = p.Parent
	end
	return false
end
local function names(list)
	local out = {}
	for _, o in list do table.insert(out, o.Name) end
	return table.concat(out, ",")
end

------------------------------------------------------------------ doubles
local NOW, CLOCK = 1000, 100
local hum = { Health = 50, MaxHealth = 250, WalkSpeed = 16 }
local attrs = {}
local function resetAttrs()
	for k in attrs do attrs[k] = nil end
	for k, v in { Class = "Warrior", Faction = "Halo", Level = 10, WeaponOwnedMask = 11, WeaponTier = 2, WeaponEnhance = 3,
		CombatPower = 1234, DataLoaded = true, InCombatUntil = 0, TitlesOwned = "", TitleSel = "", MaxMana = 100,
		ClassChosen = true, Nickname = "Glory" } do
		attrs[k] = v
	end
end
resetAttrs()
local player = { UserId = 4242, DisplayName = "Glory_RBX", GetAttribute = function(_, k) return attrs[k] end }
local ALIVE = true
local warns = {}
local Util = {
	Warn = function(...) table.insert(warns, table.concat({ ... }, " ")) end,
	Now = function() return NOW end,
	FormatInt = function(n)
		local s = tostring(math.floor(n))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end,
	GetHumanoid = function() return hum end,
	IsAlive = function() return ALIVE end,
}
local L10nReg = {}
local L10n = { Register = function(path, t) L10nReg[path] = t return t end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function() return shared end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	return nil
end }
local mods = { Config = Config, Util = Util, L10n = L10n }
local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance = game, Instance
env.require = function(n) return mods[n] end
env.os = setmetatable({ clock = function() return CLOCK end }, { __index = os })
env.task = { spawn = function() end, defer = function(f, ...) f(...) end, delay = function() end }

local fired, kitOpened, attrFns, buttons = {}, {}, {}, {}
local gameAttrs = { WarBlessing = "Horns" }
local kit = { -- what Panels.Register hands to Build
	Font = "Font.Gotham", Theme = { Gold = "gold", Text = "text", SubText = "sub", Good = "good", Bad = "bad" },
	Palette = { Button = "button", DarkText = "dark", Free = "free" },
	Button = function(parent, text, color, size, onClick, textColor)
		local b = newObj("TextButton", { Text = text, Color = color, OnClick = onClick, Parent = parent })
		table.insert(buttons, b)
		return b
	end,
	Paint = function(b, color) b.PaintColor = color end,
	SetEnabled = function(b, en) b.Enabled = en end,
	Fire = function(name, ...) table.insert(fired, { name, ... }) end,
	Open = function(id) table.insert(kitOpened, id) end,
	OnAttr = function(f) table.insert(attrFns, f) end,
}
local function artObj(class, name, props)
	local o = newObj(class, { Image = name })
	for k, v in props or {} do
		if k ~= "Parent" then o[k] = v end
	end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local UIKit = { -- C.UIKit
	ArtImage = function(name, props) return artObj("ImageLabel", name, props) end,
	ArtFrame = function(name, props) return artObj("Frame", name, props) end,
	ArtButton = function(name, props, onClick)
		local b = artObj("ImageButton", name, props)
		b.OnClick = onClick
		return b
	end,
	ItemIcon = function(id, props)
		local o = artObj("ImageLabel", "Icon:" .. tostring(id), props)
		o.ItemId = id
		return o
	end,
	HeadshotImage = function(userId) return "headshot:" .. tostring(userId) end,
	StyleText = function(l, style) l.Style = style end,
	GameAttr = function(name, d) if gameAttrs[name] ~= nil then return gameAttrs[name] end return d end,
	Tx = function(t, key, ...)
		local s = t[key .. "En"] or t[key]
		if type(s) ~= "string" then return "" end
		if select("#", ...) > 0 then return string.format(s, ...) end
		return s
	end,
}

local opened = nil
-- loads a fresh CharacterUI and runs its Init on a fresh Panels double; extra = more registry modules (GearSlots, PetWindow)
local function boot(extra, source)
	local reg, regCalls = {}, {}
	local panels = {
		Register = function(id, opts) table.insert(regCalls, id) reg[id] = opts return true end,
		Open = function(id, arg) opened = { id, arg } return true end,
		Has = function(id) return id == "Pet" end,
	}
	local C = { Panels = panels, UIKit = UIKit }
	for k, v in extra or {} do C[k] = v end
	local f = assert(loadstring(source or UI_SOURCE, "=CharacterUI"))
	setfenv(f, env)
	local M = f()
	M.Init(C)
	return M, reg, regCalls, C
end
-- Panels: build the window in a fresh body / close it (Cleanup, then the window's children are destroyed)
local function openWin(reg, arg)
	table.clear(attrFns)
	local body = newObj("Frame", { Name = "FixedBody" })
	local update = reg.Character.Build(body, kit, arg)
	return body, update
end
local function closeWin(reg, body)
	reg.Character.Cleanup()
	table.clear(attrFns)
	for _, ch in body:GetChildren() do ch:Destroy() end
end
local function fireAttr(name)
	for _, f in table.clone(attrFns) do f(name) end
end

-- every text the window shows must be a TXT line, a Config name, or a number
local function fmtPattern(s)
	local out, i = { "^" }, 1
	while i <= #s do
		local c = string.sub(s, i, i)
		if c == "%" then
			if string.sub(s, i + 1, i + 1) == "%" then
				table.insert(out, "%%")
				i += 2
			else
				local spec = string.match(s, "^%%[%.%d]*[dsf]", i)
				table.insert(out, ".+")
				i += spec and #spec or 1
			end
		elseif string.match(c, "%p") then
			table.insert(out, "%" .. c)
			i += 1
		else
			table.insert(out, c)
			i += 1
		end
	end
	table.insert(out, "$")
	return table.concat(out)
end
local function txtPatterns(t, out)
	out = out or {}
	for _, v in t do
		if type(v) == "string" then
			table.insert(out, fmtPattern(v))
		elseif type(v) == "table" then
			txtPatterns(v, out)
		end
	end
	return out
end
local configWords = {}
do
	local function add(s) if type(s) == "string" then configWords[s] = true end end
	for tier = 1, Config.MaxWeaponTier do
		for _, class in { "Warrior", "Mage", "Archer" } do
			for _, faction in { "Halo", "Horns", "None" } do add(Config.WeaponName(tier, class, faction)) end
		end
	end
	for class, def in Config.Classes do
		for _, faction in { "Halo", "Horns", "None" } do add(Config.ClassName(class, faction)) end
		for _, s in def.Stats or {} do add(s) end
	end
	for _, def in Config.Factions do
		add(def.Name)
		for _, s in def.Perks or {} do add(s) end
	end
	for _, def in Config.TitleDefs do add(def.NameEn or def.Name) end
	for _, side in { "Halo", "Horns" } do
		for _, s in Config.Titles[side] do add(s) end
	end
	add(Config.Text.BareHands)
end
local strangers = {} -- texts that are neither
local function scanTexts(M, root)
	local pats = txtPatterns(M._T.TXT)
	local n = 0
	for _, d in descendants(root) do
		local t = d.Text
		if type(t) == "string" and t ~= "" and (d.ClassName == "TextLabel" or d.ClassName == "TextButton") then
			n += 1
			-- (the player's own nickname / display name is their data, not a word of ours)
			local ok = configWords[t] == true or string.match(t, "^[%d,%.%+%-]+$") ~= nil or string.match(t, "^%u$") ~= nil
				or (d.Name == "Nickname" and (t == attrs.Nickname or t == player.DisplayName))
			if not ok then
				for _, p in pats do
					if string.match(t, p) then ok = true break end
				end
			end
			if not ok then table.insert(strangers, t) end
		end
	end
	return n
end

------------------------------------------------------------------ 0. registered
local M, reg, regCalls, C = boot()
local o = reg.Character
check(#regCalls == 1 and regCalls[1] == "Character" and M.IsReady(), "the window registers as \"Character\" (the HUD Hero tile / E key open it)",
	table.concat(regCalls, ","))
check(o ~= nil and o.FixedBody == true and o.Rebuild == false and o.Width == 600, "a fixed body that redraws itself, 600 du wide")
check(o.Title() == "Hero", "the title is Hero", o.Title())
check(L10nReg["CharacterUI.TXT"] == M._T.TXT, "the words are a registered L10n table (CharacterUI.TXT, A23-111)")
M.Open("Stats")
check(opened and opened[1] == "Character" and type(opened[2]) == "table" and opened[2].Tab == "Stats", "Open(tab) opens \"Character\" on that tab")
M.Open()
check(opened[1] == "Character" and opened[2] == nil, "Open() opens it on its own tab")

------------------------------------------------------------------ 1. pure: weapons
local ctx = { Mask = 11, Equipped = 2, Level = 10, Class = "Warrior", Faction = "Halo", Enhance = { [2] = 3 } }
local function ids(rows)
	local out = {}
	for _, r in rows do table.insert(out, r.Tier) end
	return table.concat(out, ",")
end
local rows = M.Weapons(ctx)
check(ids(rows) == "2,4,1", "Weapons: the owned tiers, the worn one first, then by Damage", ids(rows))
check(ids(M.Weapons({ Mask = 11, Equipped = 0, Level = 10 })) == "4,2,1", "no worn weapon: by Damage only", ids(M.Weapons({ Mask = 11, Equipped = 0, Level = 10 })))
check(ids(M.Weapons({ Mask = 0x87, Equipped = 0, Level = 10 })) == "8,3,2,1", "by Damage, never by the tier number (T8 = 76 beats T3 = 38)",
	ids(M.Weapons({ Mask = 0x87, Equipped = 0, Level = 10 })))
check(ids(M.Weapons({ Mask = 8, Equipped = 2, Level = 10 })) == "2,4", "the worn one is listed even when its bit is missing", ids(M.Weapons({ Mask = 8, Equipped = 2, Level = 10 })))
check(not string.find("," .. ids(rows) .. ",", ",3,", 1, true), "an unowned tier is never listed")
local byTier = {}
for _, r in rows do byTier[r.Tier] = r end
check(byTier[2].Equipped and byTier[2].Plus == 3 and not byTier[1].Equipped and byTier[2].Usable and not byTier[4].Usable and byTier[4].MinLevel == 12,
	"rows: the worn flag, the own +N, Usable by the level, MinLevel")
check(M.Weapons({ Mask = 11, Equipped = 2, Level = 10, EquippedPlus = 5 })[1].Plus == 5, "the worn weapon takes the +N of the attributes")
check(byTier[4].Attack == math.floor(Config.WeaponDamage(4, 10, 0)), "Attack = the weapon at my level with its +N")
local pb = byTier[1]
local function es(row, c) local t, e = M.EquipState(row, c) return t, e end
local t, e = es(byTier[2], {})
check(t == "Equipped" and e == false, "EquipState: the worn weapon = Equipped, off", t)
t, e = es(byTier[4], {})
check(t == "From Lv 12" and e == false, "EquipState: below MinLevel = From Lv N, off", t)
t, e = es(pb, {})
check(t == "Equip" and e == true, "EquipState: another usable weapon = Equip, on", t)
t, e = es(pb, { Combat = true })
check(t == "In a fight" and e == false, "EquipState: in a PvP fight = In a fight, off", t)
t, e = es(pb, { Pending = { Tier = 1 } })
check(t == "Checking…" and e == false, "EquipState: its own request waiting = Checking…, off", t)
t, e = es(pb, { Pending = { Tier = 4 } })
check(t == "Equip" and e == false, "EquipState: another request waiting = Equip, off (one at a time)", t)

------------------------------------------------------------------ 2. pure: titles, pet, rank
local function tids(list)
	local out = {}
	for _, x in list do table.insert(out, x.Id .. (x.Current and "*" or "")) end
	return table.concat(out, ",")
end
local list = M.Titles({ Owned = "GrayLegend,BetaPioneer,Bogus", Sel = "GrayLegend" })
check(tids(list) == ",BetaPioneer,GrayLegend*", "Titles: Auto + the owned ones in Config.TitleOrder, the chosen one current", tids(list))
check(list[1].Name == "Auto", "the first is Auto", list[1].Name)
check(tids(M.Titles({ Owned = "", Sel = "" })) == "*", "no title owned: Auto only, current")
check(tids(M.Titles({ Owned = "BetaPioneer", Sel = "GrayLegend" })) == "*,BetaPioneer", "a selection I don't own falls back to Auto")
check(tids(M.Titles({ Owned = "Bogus", Sel = "Bogus" })) == "*", "an owned id with no definition is not listed and not current")
check(tids(M.Titles()) == "*", "no ctx: Auto")
check(M.PetState(nil) == nil and M.PetState({}) == nil, "PetState: nil without pets")
local ps = M.PetState({ { Equipped = false }, { Equipped = false } })
check(ps and ps.Count == 2 and ps.Equipped == nil, "PetState: pets but none following")
ps = M.PetState({ { Equipped = false }, { Equipped = true, Species = "X", Lv = 2 } })
check(ps and ps.Count == 2 and ps.Equipped and ps.Equipped.Lv == 2, "PetState: the worn pet and the count")
local n1, g1 = M.NextRank("Halo", 0)
check(n1 == "Knight" and g1 == 10, "NextRank: Halo 0 -> Knight, 10 to go", tostring(n1) .. tostring(g1))
n1, g1 = M.NextRank("Halo", 9)
check(n1 == "Knight" and g1 == 1, "NextRank: 9 points -> 1 to go")
n1, g1 = M.NextRank("Halo", 10)
check(n1 == "Paladin" and g1 == 40, "NextRank: exactly on a threshold = the one after it", tostring(n1) .. tostring(g1))
check(M.NextRank("Halo", 1000) == nil and M.NextRank("Horns", 5000) == nil, "NextRank: nil at the top")
n1, g1 = M.NextRank("Horns", 49)
check(n1 == "Warlord" and g1 == 1, "NextRank: Horns names", tostring(n1))
check(M.NextRank("None", 5) == nil, "NextRank: no side = nil")

------------------------------------------------------------------ 3. pure: stats
local rich = { Level = 15, MaxHealth = 300, MaxMana = 120, WalkSpeed = 16, Tier = 2, EquippedPlus = 3, Class = "Warrior", Faction = "Horns",
	SizeMult = 1.25, BullyStacks = 1, WantedStars = 2, RevengeUntil = NOW + 75, Now = NOW, Blessing = "Horns", Rebirths = 2,
	RebirthBonus = 0.1, FallMarks = 1, RedeemMarks = 0, Honor = 5, Infamy = 60 }
local function heads(rs)
	local out = {}
	for _, r in rs do if r.Kind == "Head" then table.insert(out, r.Id) end end
	return table.concat(out, ",")
end
local function rowOf(rs, id) -- a row, a card or a chip (ref_rpg_ui #5)
	for _, r in rs do if r.Kind ~= "Head" and r.Id == id then return r end end
	return nil
end
local srows = M.StatRows(rich)
-- 최종 검수 10/13 (ref_rpg_ui #1 / #2): pure
local dl, dc = M.DiffLine(100, 110)
local dl2, dc2 = M.DiffLine(1200, 1180)
local dl3, dc3 = M.DiffLine(50, 50)
check(dl == "Power +10" and dc == "Good" and dl2 == "Power -20" and dc2 == "Bad" and dl3 == "Power =" and dc3 == "Same"
	and M.DiffLine(nil, 5) == nil, "#2 DiffLine: up green, down red, equal grey, nothing without both", tostring(dl) .. "|" .. tostring(dl2))
local wy = M.PowerWhy("Attack", { Level = 5, Tier = 0 })
check(#wy == 2 and wy[1] == "Bare hands" and wy[2] == "Level 5", "#1 PowerWhy: bare hands + the level", table.concat(wy, ","))
check(heads(srows) == "Stats,Traits,Effects,Rebirth,Rank", "StatRows: every section when the data is there", heads(srows))
check(rowOf(srows, "MaxHP") and rowOf(srows, "MaxHP").Value == "300" and rowOf(srows, "Level").Value == "15", "StatRows: level and max HP")
check(rowOf(srows, "Next") and rowOf(srows, "Next").Value == "Dread Lord · 140 to go", "StatRows: the next rank and the points to go",
	rowOf(srows, "Next") and rowOf(srows, "Next").Value)
check(rowOf(srows, "Rank").Value == "Warlord" and rowOf(srows, "Infamy").Value == "60" and rowOf(srows, "Honor").Value == "5",
	"StatRows: rank, infamy and the other side's honor")
check(rowOf(srows, "Bully") and rowOf(srows, "Wanted") and rowOf(srows, "Revenge") and rowOf(srows, "Blessing") and rowOf(srows, "Size"),
	"StatRows: the effects that are on")
local minimal = M.StatRows({ Faction = "None" })
check(heads(minimal) == "Stats,Traits", "StatRows: no effects / rebirth / rank = no such heads", heads(minimal))
check(rowOf(minimal, "MaxHP") == nil, "StatRows: a value with no source leaves its row out")
local top = M.StatRows({ Faction = "Halo", Honor = 2000, Level = 5 })
check(rowOf(top, "Next").Value == "Top rank", "StatRows: at the top = Top rank", rowOf(top, "Next").Value)
check(heads(M.StatRows({ Faction = "Halo", Rebirths = 1 })):find("Rebirth", 1, true) ~= nil, "StatRows: one rebirth shows the Rebirth section")
-- 게임성 검수 10/12 (API review): the blessing is the winning side's only (gold and XP), the hit row is the base hit
check(rowOf(srows, "Blessing") and rowOf(srows, "Blessing").Text == "Gold & XP +25%", "10/12: my side's blessing = +gold and +XP",
	rowOf(srows, "Blessing") and rowOf(srows, "Blessing").Text)
-- 최종 검수 10/13 (ref_rpg_ui #5): cards for the numbers, chips for the traits / effects, no sentences
local kinds = {}
for _, r in srows do kinds[r.Kind] = (kinds[r.Kind] or 0) + 1 end
check((kinds.Line or 0) == 0 and (kinds.Card or 0) == 6 and rowOf(srows, "MaxHP").Kind == "Card" and rowOf(srows, "MaxHP").Icon == "IconHeart"
	and rowOf(srows, "Hit").Icon == "IconSword", "#5: six number cards with icons, no text lines", tostring(kinds.Card))
check(rowOf(srows, "Gold") and rowOf(srows, "Gold").Text == "Gold +25%" and rowOf(srows, "ATK").Text == "ATK +15%"
	and rowOf(srows, "Steal").Text == "HP steal 10%" and rowOf(srows, "Class1").Kind == "Chip",
	"#5: the Horn Legion's traits as number chips (Gold +25%, ATK +15%, HP steal 10%) + the class's", rowOf(srows, "Gold") and rowOf(srows, "Gold").Text)
local haloRows = M.StatRows({ Faction = "Halo", Level = 3, Class = "Mage" })
check(rowOf(haloRows, "XP") and rowOf(haloRows, "XP").Text == "XP +30%" and rowOf(haloRows, "HP").Text == "HP +20%"
	and rowOf(haloRows, "Heal") and rowOf(haloRows, "Gold") == nil, "#5: the Knights' traits (XP +30%, HP +20%, healing allies)")
check(rowOf(srows, "Bully").Text == "Bully -15%" and rowOf(srows, "NoAuto") ~= nil and rowOf(srows, "Size").Text == "Size ×1.25",
	"#5: the effects as chips (Size ×1.25, Bully -15%, No Auto Battle)", rowOf(srows, "Bully").Text)
local otherSide = table.clone(rich)
otherSide.Blessing = "Halo"
check(rowOf(M.StatRows(otherSide), "Blessing") == nil, "10/12: the other side's blessing is not mine (no row)")
check(rowOf(srows, "Hit") and rowOf(srows, "Hit").Label == "Base hit", "10/12: the hit row says Base hit (the server adds size / bully / wanted / aura)",
	rowOf(srows, "Hit") and rowOf(srows, "Hit").Label)
-- 게임성 검수 10/12: the server's other refusals dim [Equip] (dead, no class, a side weapon without a side)
local usable = { Tier = 7, Usable = true, NeedSide = true }
local _, onA = M.EquipState(usable, { Faction = "Halo" })
local _, offDead = M.EquipState(usable, { Faction = "Halo", Dead = true })
local _, offClass = M.EquipState(usable, { Faction = "Halo", NoClass = true })
local _, offSide = M.EquipState(usable, { Faction = "None" })
local _, onPlain = M.EquipState({ Tier = 1, Usable = true }, { Faction = "None" })
check(onA == true and offDead == false and offClass == false and offSide == false and onPlain == true,
	"10/12: Equip off when dead / no class / a side weapon without a side; on otherwise", tostring(onA) .. tostring(offDead)
	.. tostring(offClass) .. tostring(offSide) .. tostring(onPlain))

------------------------------------------------------------------ 4. the window without GearSlots (the fallback), no pets
resetAttrs()
local body, update = openWin(reg)
local frame = find(body, "EquipSlots")
check(frame ~= nil and inside(find(body, "SlotsView"), frame), "the EquipSlots frame sits in the Gear page's right column")
check(frame.Size.X.Offset == 220 and frame.Size.Y.Offset == 266 and frame.Position.X.Offset == 0, "its default size is 3 x 3 cells", frame.Size.X.Offset)
check(find(body, "Tab_Gear") and find(body, "Tab_Stats") and find(body, "Tab_Gear").PaintColor == "gold", "two tabs, Gear open (gold)")
local wc = find(frame, "Cell_Weapon")
check(wc ~= nil and wc.Image == "SlotCommon" and find(wc, "Plus") and find(wc, "Plus").Text == "+3", "fallback: the Weapon cell with its tier frame and +3")
check(find(frame, "Cell_Pet") == nil and find(frame, "Cap_Pet") == nil, "fallback: no Pet cell without pets")
local empties = findAll(frame, "^Empty_")
local allEmpty = #empties == 4
for _, em in empties do allEmpty = allEmpty and em.Image == "SlotEmpty" end
check(allEmpty and find(frame, "Empty_Armor") and find(frame, "Empty_Ring") and find(frame, "Empty_PetArmor") and find(frame, "Empty_PetAcc"),
	"fallback: Armor · Ring · Pet Armor · Pet Acc as four empty SlotEmpty cells", #empties)
check(find(frame, "Cap_Weapon").Text == "Weapon" and find(frame, "EmptyCap_PetArmor").Text == "Pet Armor", "fallback: the one short word under a cell")
check(find(body, "PowerNumber").Text == "1,234" and string.find(find(body, "Who").Text, "Lv 10", 1, true) ~= nil, "the left column: the Power number and Lv / class")
check(find(body, "Headshot").Image == "headshot:4242", "the headshot of my account")
-- 게임성 검수 10/12 (API review): Settings hides its Nickname row once this window exists -> the nickname lives here
check(find(body, "Nickname") and find(body, "Nickname").Text == "Glory", "10/12: my nickname under the portrait",
	find(body, "Nickname") and find(body, "Nickname").Text)
local changeName = find(body, "ChangeName")
check(changeName ~= nil and changeName.Text == "Change", "10/12: a [Change] button beside it")
if changeName and changeName.OnClick then changeName.OnClick() end
check(kitOpened[#kitOpened] == "Nickname", "10/12: [Change] opens the Nickname window", kitOpened[#kitOpened])
-- 최종 검수 10/13 (ref_rpg_ui #1): the power's two parts under it, a press lists their sources
local pa, ph = Config.PowerPartsOf(player)
check(pa == math.floor(Config.WeaponDamage(2, 10, 3) + 0.5) and ph == math.floor(Config.BaseHealth(10) + 0.5),
	"#1: Attack = the worn weapon at my level with its +N, Health = the level's base (points / gear off)", tostring(pa) .. "/" .. tostring(ph))
local chipA, chipH = find(body, "Part_Attack"), find(body, "Part_Health")
check(chipA and chipH and chipA.Image == "Chip" and find(chipA, "Icon").Image == "IconSword" and find(chipH, "Icon").Image == "IconHeart"
	and find(chipA, "Value").Text == tostring(pa) and find(chipH, "Value").Text == tostring(ph),
	"#1: [sword] Attack · [heart] Health chips under the power (Config.PowerPartsOf)", tostring(pa) .. "/" .. tostring(ph))
check(find(body, "PowerWhy") == nil, "#1: no sources until a chip is pressed")
chipA.OnClick()
local why = find(body, "PowerWhy")
local wname = Config.WeaponName(2, "Warrior", "Halo")
check(why and find(why, "Why1") and find(why, "Why1").Text == wname .. " +3" and find(why, "Why2").Text == "Level 10",
	"#1: Attack's sources: the weapon +N, the level", why and find(why, "Why1") and find(why, "Why1").Text)
find(body, "Part_Health").OnClick()
why = find(body, "PowerWhy")
check(why and find(why, "Why1").Text == "Level 10" and find(why, "Why2") == nil, "#1: Health's source: the level (points / armor while off)")
find(body, "Part_Health").OnClick()
check(find(body, "PowerWhy") == nil, "#1: the same chip again hides the sources")
check(find(body, "Title_Auto") and find(body, "Title_Auto").Color == "gold" and find(body, "Title_BetaPioneer") == nil, "the title list: Auto (current) only while no title is owned")
local nText = scanTexts(M, body)
-- a press on the Weapon cell opens the owned list
wc.OnClick()
check(M._T.S.View == "Weapons" and find(body, "WeaponsView").Visible == true and find(body, "SlotsView").Visible == false, "the Weapon cell opens the owned-weapons list")
local order = {}
for _, ch in find(body, "WeaponsView"):GetChildren() do
	if string.match(ch.Name, "^Weapon_%d$") then table.insert(order, ch.Name) end
end
check(table.concat(order, ",") == "Weapon_2,Weapon_4,Weapon_1", "the list: worn first, then by Damage", table.concat(order, ","))
check(find(body, "Equip_2").Text == "Equipped" and find(body, "Equip_2").Enabled == false and find(body, "Equip_4").Text == "From Lv 12"
	and find(body, "Equip_4").Enabled == false and find(body, "Equip_1").Text == "Equip" and find(body, "Equip_1").Enabled == true,
	"the buttons: Equipped / From Lv 12 (off) / Equip (on)")
check(find(body, "Power") ~= nil, "the usable rows show the power line")
local w1 = find(body, "Weapon_1")
local pl = w1 and find(w1, "Power")
local d1 = Config.CombatPowerOf(player, 1, 0) - Config.CombatPowerOf(player)
check(pl and ((d1 < 0 and pl.Text == "Power -" .. tostring(-d1) and pl.TextColor3 == "bad")
	or (d1 > 0 and pl.Text == "Power +" .. tostring(d1) and pl.TextColor3 == "good")),
	"#2: a weapon's power change = one coloured line (Power +N green / Power -N red)", pl and pl.Text)
nText += scanTexts(M, body)
find(body, "Equip_1").OnClick()
check(#fired == 1 and fired[1][1] == "EquipWeapon" and fired[1][2] == 1, "the [Equip] button sends EquipWeapon(tier) once", #fired)
find(body, "Back").OnClick()
check(M._T.S.View == "Slots" and find(body, "SlotsView").Visible == true, "Back returns to the gear cells")

-- Equip(tier): the same guards as the bag
fired = {}
M._T.S.Pending, M._T.S.ReadyAt = nil, {}
check(M.Equip(4) == false and #fired == 0, "Equip: a weapon above my level sends nothing")
check(M.Equip(3) == false and M.Equip(99) == false and M.Equip("x") == false and M.Equip(2) == false and #fired == 0,
	"Equip: unowned / unknown / not a number / already worn send nothing")
attrs.InCombatUntil = NOW + 5
check(M.Equip(1) == false and #fired == 0, "Equip: nothing in a PvP fight")
attrs.InCombatUntil = 0
attrs.Level = 20
check(M.Equip(4) == true and #fired == 1 and fired[1][1] == "EquipWeapon" and fired[1][2] == 4, "Equip(4): fires EquipWeapon once", #fired)
check(M.Equip(1) == false and #fired == 1, "a second press at once sends nothing")
CLOCK += 1
check(M.Equip(1) == false and #fired == 1, "one request at a time: past the rate gap but still waiting for the answer")
attrs.WeaponTier = 4
update()
check(M._T.S.Pending == nil, "the weapon change answers the request")
check(M.Equip(1) == true and #fired == 2 and fired[2][2] == 1, "after the answer the next Equip goes out")
M._T.S.Pending = nil
check(M.Equip(2) == false and #fired == 2, "the rate gap alone blocks a press inside it (no pending)")
CLOCK += 1
check(M.Equip(2) == true and #fired == 3 and fired[3][2] == 2, "past the gap it goes out")
check(M.Equip(2) == false, "an equip can't be asked twice in a row")

-- SetTitle(id)
fired = {}
attrs.TitlesOwned, attrs.TitleSel = "BetaPioneer,GrayLegend", ""
fireAttr("TitlesOwned")
check(find(body, "Title_Auto") and find(body, "Title_BetaPioneer") and find(body, "Title_GrayLegend"), "the title list shows Auto + the owned titles")
check(find(body, "Title_Auto").Color == "gold" and find(body, "Title_GrayLegend").Color == "button", "exactly the current one is gold")
CLOCK += 1
check(M.SetTitle("BetaPioneer") == true and #fired == 1 and fired[1][1] == "SetTitle" and fired[1][2] == "BetaPioneer", "SetTitle(id) fires SetTitle with the id")
check(M.SetTitle("GrayLegend") == false and #fired == 1, "a second SetTitle inside the rate gap sends nothing")
attrs.TitleSel = "BetaPioneer"
CLOCK += 1
check(M.SetTitle("BetaPioneer") == false and #fired == 1, "the title already shown sends nothing")
check(M.SetTitle("") == true and #fired == 2 and fired[2][2] == "", "Auto sends the empty id")
CLOCK += 1
check(M.SetTitle("ClatterStopper") == false and M.SetTitle(5) == false and #fired == 2, "a title I don't own / a non-string sends nothing")
find(body, "Title_GrayLegend").OnClick()
check(#fired == 3 and fired[3][1] == "SetTitle" and fired[3][2] == "GrayLegend", "the title button sends SetTitle")
nText += scanTexts(M, body)

-- attributes redraw in place
attrs.CombatPower = 999
fireAttr("CombatPower")
check(find(body, "PowerNumber").Text == "999", "a watched attribute redraws the left column")
attrs.CombatPower = 5000
fireAttr("SomethingElse")
check(find(body, "PowerNumber").Text == "999", "an unwatched attribute redraws nothing")

-- the Stats tab
attrs.Faction, attrs.Level, attrs.SizeMult, attrs.BullyStacks, attrs.WantedStars = "Horns", 15, 1.25, 1, 2
attrs.RevengeUntil, attrs.Rebirths, attrs.RebirthBonus, attrs.FallMarks, attrs.Honor, attrs.Infamy = NOW + 75, 2, 0.1, 1, 5, 60
find(body, "Tab_Stats").OnClick()
check(M._T.S.Tab == "Stats" and find(body, "StatsPage").Visible == true and find(body, "GearPage").Visible == false, "the Stats tab shows its page")
check(find(body, "Tab_Stats").PaintColor == "gold" and find(body, "Tab_Gear").PaintColor == "button", "the open tab is gold")
check(find(body, "Card_Level") and find(body, "Chip_Wanted") and find(body, "Stat_Next") and find(body, "Head_Effects")
	and find(find(body, "Card_MaxHP"), "Icon") and find(body, "Card_Level").Image == "Chip", "the Stats cards / chips / rows from the attributes")
check(find(find(body, "Stat_Next"), "Value").Text == "Dread Lord · 140 to go", "the next rank row", find(find(body, "Stat_Next"), "Value").Text)
nText += scanTexts(M, body)
closeWin(reg, body)
check(true, "the window closes without an error")
check(frame.Parent == nil, "Cleanup takes the EquipSlots frame out before Panels clears the window")

-- opened on a tab by its arg
resetAttrs()
body = openWin(reg, { Tab = "Stats" })
check(M._T.S.Tab == "Stats" and find(body, "StatsPage").Visible == true, "an arg Tab opens the Stats tab")
closeWin(reg, body)
body = openWin(reg, { Tab = "Bogus" })
check(M._T.S.Tab == "Gear" and find(body, "GearPage").Visible == true, "an unknown tab opens Gear")
closeWin(reg, body)
check(find(frame, "Cell_Weapon") ~= nil and frame.Parent == nil, "the fallback cells stay in the kept frame")
body = openWin(reg)
check(frame.Parent ~= nil and inside(body, frame) and #findAll(frame, "^Cell_Weapon$") == 1, "the next open puts the same frame back, the Weapon cell drawn once",
	#findAll(frame, "^Cell_Weapon$"))
closeWin(reg, body)

------------------------------------------------------------------ 5. fallback with pets
resetAttrs()
local petRowsData = { { Equipped = true, Species = "BabySlime", Lv = 3, Icon = "PetBabySlime", Name = "Jelly" } }
local PetWindow = { Rows = function() return petRowsData end, Lists = function() return {} end }
local M2, reg2 = boot({ PetWindow = PetWindow })
local body2 = openWin(reg2)
local frame2 = find(body2, "EquipSlots")
local pc = find(frame2, "Cell_Pet")
check(pc ~= nil and find(pc, "Plus") and find(pc, "Plus").Text == "Lv 3" and find(frame2, "Cap_Pet").Text == "Pet", "fallback with pets: the Pet cell with its level")
check(#findAll(frame2, "^Empty_") == 4, "fallback with pets: still four empty cells")
pc.OnClick()
check(kitOpened[#kitOpened] == "Pet", "the Pet cell opens the Pet window")
nText += scanTexts(M2, body2)
petRowsData[1].Equipped = false
M2.Refresh(true)
pc = find(frame2, "Cell_Pet")
check(pc ~= nil and find(pc, "Plus") == nil and #findAll(frame2, "^Cell_Pet$") == 1, "pets but none following: an empty Pet cell, drawn once")
petRowsData = {}
M2.Refresh(true)
check(find(frame2, "Cell_Pet") == nil, "the last pet gone: no Pet cell")
closeWin(reg2, body2)

------------------------------------------------------------------ 6. with GearSlots: it draws all six cells
resetAttrs()
local function fakeGear(log, failBuild)
	return {
		Build = function(frame, opts)
			table.insert(log.seq, "build")
			log.build += 1
			log.frame, log.opts = frame, opts
			if failBuild then
				newObj("Frame", { Name = "GCell_Junk", Parent = frame })
				error("boom")
			end
			for _, id in { "Weapon", "Armor", "Ring", "Pet", "PetArmor", "PetAcc" } do
				newObj("Frame", { Name = "GCell_" .. id, Parent = frame })
			end
		end,
		Refresh = function()
			table.insert(log.seq, "refresh")
			log.refresh += 1
		end,
	}
end
local glog = { build = 0, refresh = 0, seq = {} }
local M3, reg3 = boot({ GearSlots = fakeGear(glog), PetWindow = { Rows = function() return { { Equipped = true, Species = "X", Lv = 2, Name = "X" } } end } })
local body3 = openWin(reg3)
local frame3 = find(body3, "EquipSlots")
check(glog.build == 1 and glog.frame == frame3 and frame3.Name == "EquipSlots", "GearSlots.Build gets the EquipSlots frame, once")
check(type(glog.opts) == "table" and type(glog.opts.Refresh) == "function", "Build's opts carry a Refresh callback")
check(glog.seq[1] == "build" and glog.seq[2] == "refresh" and #glog.seq == 2, "Build first, then Refresh at the end of the open", table.concat(glog.seq, ","))
local kids = frame3:GetChildren()
local mine = 0
for _, ch in kids do if string.match(ch.Name, "^GCell_") then mine += 1 end end
check(#kids == 6 and mine == 6, "the frame holds exactly the six cells of GearSlots", names(kids))
check(#findAll(body3, "^Cell_") == 0 and #findAll(body3, "^Empty") == 0 and #findAll(body3, "^Cap_") == 0 and #findAll(body3, "^EmptyCap_") == 0,
	"CharacterUI draws no cell of its own: no Weapon cell, no Pet cell, no SlotEmpty placeholders")
M3.Refresh(true)
attrs.EquippedPet = "x"
fireAttr("EquippedPet")
check(#frame3:GetChildren() == 6 and #findAll(body3, "^Cell_") == 0, "a redraw keeps it that way (pets or not)")
check(find(body3, "Title_Auto") ~= nil and find(body3, "PowerNumber") ~= nil, "the rest of the window is still drawn")
local titles3 = find(body3, "Titles")
check(titles3.Position.X.Offset == 220 + M3._T.L.TitleGap, "the title list sits beside the default frame", titles3.Position.X.Offset)
-- GearSlots resizes its frame (no pet: one row less) and calls opts.Refresh
frame3.Size = UDim2.fromOffset(150, 120)
local okR, errR = pcall(glog.opts.Refresh)
check(okR and titles3.Position.X.Offset == 150 + M3._T.L.TitleGap, "opts.Refresh lays the window out around the frame's new size", errR or titles3.Position.X.Offset)
check(glog.refresh == 1 and glog.build == 1, "opts.Refresh is not a Build / Refresh again")
frame3.Size = UDim2.fromOffset(0, 0)
glog.opts.Refresh()
check(titles3.Position.X.Offset == 220 + M3._T.L.TitleGap, "a size that means nothing falls back to the default", titles3.Position.X.Offset)
frame3.Size = UDim2.fromOffset(150, 120)
glog.opts.Refresh()
closeWin(reg3, body3)
check(frame3.Parent == nil and #frame3:GetChildren() == 6, "closing keeps the frame and its cells")
check(pcall(glog.opts.Refresh), "opts.Refresh with the window closed is harmless")
body3 = openWin(reg3)
check(glog.build == 1 and glog.refresh == 2 and #glog.seq == 3 and glog.seq[3] == "refresh", "second open: no second Build, Refresh again", table.concat(glog.seq, ","))
check(inside(body3, frame3) and find(body3, "EquipSlots") == frame3 and #frame3:GetChildren() == 6, "the same frame (and cells) is back in the window")
check(frame3.Size.X.Offset == 150 and frame3.Size.Y.Offset == 120, "CharacterUI never writes the size of a GearSlots frame")
check(find(body3, "Titles").Position.X.Offset == 150 + M3._T.L.TitleGap, "the new window is laid out around the frame's size at once")
closeWin(reg3, body3)
body3 = openWin(reg3)
check(glog.build == 1 and glog.refresh == 3, "third open: still one Build, Refresh every open", glog.refresh)
find(body3, "Tab_Stats").OnClick()
check(#findAll(body3, "^Cell_") == 0, "the Stats tab draws no gear cell either")
closeWin(reg3, body3)

------------------------------------------------------------------ 7. GearSlots whose Build fails = no GearSlots
resetAttrs()
warns = {}
local flog = { build = 0, refresh = 0, seq = {} }
local M4, reg4 = boot({ GearSlots = fakeGear(flog, true) })
local body4 = openWin(reg4)
local frame4 = find(body4, "EquipSlots")
check(flog.build == 1 and #warns == 1 and flog.refresh == 0, "a failing Build is reported once and GearSlots.Refresh is not called", #warns)
check(find(frame4, "GCell_Junk") == nil and find(frame4, "Cell_Weapon") ~= nil and #findAll(frame4, "^Empty_") == 4,
	"what it half drew goes; the fallback cells are drawn instead")
closeWin(reg4, body4)
body4 = openWin(reg4)
check(flog.build == 1 and #findAll(find(body4, "EquipSlots"), "^Cell_Weapon$") == 1, "the next open does not Build again")
closeWin(reg4, body4)

-- GearSlots without Build = no GearSlots
local M5, reg5 = boot({ GearSlots = { Refresh = function() end } })
local body5 = openWin(reg5)
check(find(body5, "Cell_Weapon") ~= nil and #findAll(body5, "^Empty_") == 4, "a GearSlots table with no Build function: the fallback is drawn")
closeWin(reg5, body5)

------------------------------------------------------------------ 8. every text comes from TXT / Config
check(nText > 40, "the scan looked at the window's texts", nText)
check(#strangers == 0, "every text the window shows is a TXT line, a Config name or a number", table.concat(strangers, " | "))

print(string.format("CHARACTER_UI_SUMMARY checks=%d failed=%d", checks, failed))
