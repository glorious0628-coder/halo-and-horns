-- H-1 가방 창 (게임성 개발 4, 2026-10-12): runs the real Config.luau and the real BagUI.luau (tools/test_bag_ui.py) on
-- small doubles: Players.LocalPlayer attributes, a recording Instance tree, a Panels registry that builds the window with a
-- recording kit, UIKit art doubles, Settings / QuickSlots doubles. Inputs: CONFIG_SOURCE, BAG_SOURCE. Every check is named.
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

------------------------------------------------------------------ an Instance tree double
local made = {}
local signals = {}
local ISA = {
	TextButton = { GuiButton = true, GuiObject = true }, ImageButton = { GuiButton = true, GuiObject = true },
	TextLabel = { GuiObject = true }, ImageLabel = { GuiObject = true }, Frame = { GuiObject = true },
	ScrollingFrame = { GuiObject = true },
}
local omt = {}
local function newObj(class, props)
	local o = setmetatable({ __p = { ClassName = class, Name = class, Children = {}, ZIndex = 1, CanvasPosition = vec(0, 0),
		AbsoluteSize = vec(0, 0), ImageTransparency = 0 } }, omt)
	for k, v in props or {} do o[k] = v end
	table.insert(made, o)
	return o
end
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
		GetPropertyChangedSignal = function(self, prop)
			return { Connect = function(_, f)
				local rec = { Obj = self, Prop = prop, Fn = f, Live = true }
				table.insert(signals, rec)
				return { Disconnect = function() rec.Live = false end }
			end }
		end,
		SetAttribute = function(self, k, v) rawget(self, "__p")["@" .. k] = v end,
		GetAttribute = function(self, k) return rawget(self, "__p")["@" .. k] end,
	}
	if methods[k] then return methods[k] end
	return rawget(o, "__p")[k]
end
omt.__newindex = function(o, k, v)
	local p = rawget(o, "__p")
	if k == "Parent" then
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
local function textIn(root, s)
	for _, d in descendants(root) do
		if type(d.Text) == "string" and string.find(d.Text, s, 1, true) then return d end
	end
	return nil
end

------------------------------------------------------------------ doubles
local NOW = 1000
local CLOCK = 100
local hum = { Health = 50, MaxHealth = 100 }
local attrs = { Class = "Warrior", Faction = "Halo", Level = 10, WeaponOwnedMask = 0b1011, WeaponTier = 2, WeaponEnhance = 3,
	HPPotionCount = 5, MPPotionCount = 0, HPPotionReadyAt = 0, MPPotionReadyAt = 0, Mana = 40, MaxMana = 100,
	BankGold = 1200, CarriedGold = 34, DataLoaded = true, InCombatUntil = 0 }
local player = { GetAttribute = function(_, k) return attrs[k] end }
local Util = {
	Warn = function(...) print("WARN", ...) end,
	Now = function() return NOW end,
	FormatInt = function(n)
		local s = tostring(math.floor(n))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end,
	GetHumanoid = function() return hum end,
	IsAlive = function() return true end,
}
local L10nReg = {}
local L10n = { Register = function(path, t) L10nReg[path] = t return t end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function(_, n) return shared end, FindFirstChild = function() return nil end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	return nil
end }
local mods = { Config = Config, Util = Util, L10n = L10n }

local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance = game, Instance
env.require = function(n) return mods[n] end
env.workspace = { GetServerTimeNow = function() return NOW end }
env.os = setmetatable({ clock = function() return CLOCK end }, { __index = os })
env.task = { spawn = function() end, defer = function(f, ...) f(...) end, delay = function() end }
local bf = assert(loadstring(BAG_SOURCE, "=BagUI"))
setfenv(bf, env)
local BagUI = bf()

local reg = {}
local root, update = nil, nil -- the open window's body and its 0.25 s update (set when it is built)
local openArg = nil -- the arg of the last Panels.Open (Panels hands it to every rebuild)
local fired, rebuilds = {}, 0
local attrFns = {}
local buttons = {}
local lastResult, lastAt = nil, nil
local kit
kit = {
	Font = "Font.Gotham", Theme = { Gold = "gold", Text = "text", SubText = "sub", Good = "good", Bad = "bad" },
	Palette = { Button = "button", DarkText = "dark", Free = "free", Buy = "buy" },
	Button = function(parent, text, color, size, onClick, textColor)
		local b = newObj("TextButton", { Text = text, Color = color, OnClick = onClick, Parent = parent })
		table.insert(buttons, b)
		return b
	end,
	Paint = function(b, color, textColor) b.PaintColor = color end,
	SetEnabled = function(b, en) b.Enabled = en end,
	Fire = function(name, ...) table.insert(fired, { name, ... }) end,
	-- Panels' render: the built window's Cleanup, its body cleared, Build again (a new width for a size change)
	Rebuild = function()
		rebuilds += 1
		if not root then return end
		reg.Bag.Cleanup()
		for _, ch in root:GetChildren() do ch:Destroy() end
		update = reg.Bag.Build(root, kit, openArg)
	end,
	OnAttr = function(f) table.insert(attrFns, f) end,
}
local panels = {
	Register = function(id, opts) reg[id] = opts return true end,
	LastEnhance = function() return lastResult, lastAt end,
	Open = function() end,
}
local settings = { BagSort = "Default", BagWide = false }
local Settings = {
	Get = function(k) return settings[k] end,
	Set = function(k, v)
		local probe = { BagSort = settings.BagSort, BagWide = settings.BagWide }
		probe[k] = v
		settings[k] = Config.SanitizeSettings(probe)[k]
		return true
	end,
}
local quick = { "", "", "" }
local QuickSlots = {
	Get = function() return table.clone(quick) end,
	Set = function(i, item) quick[i] = item return true end,
}
local function artObj(class, name, props)
	local o = newObj(class, { Image = name })
	for k, v in props or {} do
		if k ~= "Parent" then o[k] = v end
	end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local UIKit = {
	Gui = nil,
	ArtImage = function(name, props) return artObj("ImageLabel", name, props) end,
	ArtFrame = function(name, props) return artObj("Frame", name, props) end,
	ArtButton = function(name, props, onClick)
		local b = artObj("ImageButton", name, props)
		b.OnClick = onClick
		return b
	end,
	ItemIcon = function(id, props)
		if id == "Petal" then return nil end -- an item whose icon is not drawn yet (UiSandbox 10/12)
		local o = artObj("ImageLabel", "Icon:" .. tostring(id), props)
		o.ItemId = id
		return o
	end,
	StyleText = function(l, style) l.Style = style end,
	Tx = function(t, key, ...)
		local s = t[key .. "En"] or t[key]
		if type(s) ~= "string" then return "" end
		if select("#", ...) > 0 then return string.format(s, ...) end
		return s
	end,
}
BagUI.Init({ Panels = panels, UIKit = UIKit, Settings = Settings, QuickSlots = QuickSlots })
local T = BagUI._T
do -- Panels clears the built window's kit.OnAttr callbacks on cleanup (REG.CleanupBuilt)
	local realCleanup = reg.Bag.Cleanup
	reg.Bag.Cleanup = function()
		table.clear(attrFns)
		realCleanup()
	end
end
local TXT = T.TXT

------------------------------------------------------------------ 0. registered
local o = reg.Bag
check(o ~= nil and BagUI.IsReady(), "the window \"Bag\" is registered (the HUD Bag tile / I key open it)")
check(o.FixedBody == true and o.Rebuild == false, "a fixed body (tabs stay put) that redraws itself (Rebuild = false)")
check(o.Title() == "Bag", "the title is Bag", o.Title())
check(L10nReg["BagUI.TXT"] == TXT, "the words are a registered L10n table (BagUI.TXT, A23-111)")
check(type(o.Width) == "function" and o.Width() == BagUI.WindowWidth(false), "narrow by default: Panels gets the narrow width", o.Width())
settings.BagWide = true
check(o.Width() == BagUI.WindowWidth(true) and BagUI.WindowWidth(true) <= 780 and BagUI.WindowWidth(false) < BagUI.WindowWidth(true),
	"wide asks for the wide width (<= the 780 du window max)", BagUI.WindowWidth(true))
settings.BagWide = false

------------------------------------------------------------------ 1. the model
local function ctxOf(t)
	local c = { Items = { Jelly = 12, SlimeCore = 2, Enh70 = 3, Move30 = 1, Nope = 4, CaptainBadge = 1 }, Enhance = { [1] = 0, [2] = 3, [4] = 1 },
		ItemSeq = { Jelly = 9, SlimeCore = 4, Enh70 = 7, Move30 = 2, PotionHP = 5, CaptainBadge = 1 }, WeaponSeq = { [1] = 1, [2] = 3, [4] = 8 },
		Mask = 0b1011, Equipped = 2, Level = 10, Class = "Warrior", Faction = "Halo", Potions = { HP = 5, MP = 0 } }
	for k, v in t or {} do c[k] = v end
	return c
end
local cells = BagUI.Cells(ctxOf())
local byKey = {}
for _, c in cells do byKey[c.Key] = c end
check(byKey["W:1"] and byKey["W:2"] and byKey["W:4"] and not byKey["W:3"], "owned weapons (mask bits) only", "")
check(byKey["W:2"].Equipped and byKey["W:2"].Plus == 3 and not byKey["W:1"].Equipped, "the equipped weapon and each weapon's own +N")
check(byKey["P:HP"] and byKey["P:HP"].Count == 5 and byKey["P:MP"] and byKey["P:MP"].Count == 0,
	"every quick slot potion has its slot, an empty one at 0 (게임성 검수 10/12: its quick slots stay reachable)")
check(not byKey["I:Nope"], "unknown item ids never show")
check(byKey["I:Jelly"].Tab == "Material" and byKey["I:Enh70"].Tab == "Scroll" and byKey["P:HP"].Tab == "Use" and byKey["W:4"].Tab == "Gear",
	"each kind on its tab (Gear · Use · Scrolls · Materials)")
check(byKey["I:SlimeCore"].Grade == "Fine" and byKey["I:Move30"].Grade == "Rare" and byKey["I:Jelly"].Grade == "Common"
	and byKey["I:CaptainBadge"].Grade == "Rare" and byKey["I:Enh70"].Grade == "Fine", "item grades (BB6: Fine / Rare / Epic scrolls and drops)")
check(byKey["W:4"].Grade == "Rare" and byKey["W:4"].Icon == "Weapon_Warrior_T4", "weapon grade + the class's weapon icon", byKey["W:4"].Icon)
check(byKey["I:Enh70"].Icon == "Enh70", "item icons go through UIKit.ItemIcon by item id (the scroll band)")
cells = BagUI.Cells(ctxOf({ Spares = { ["4:2"] = 3, ["99:0"] = 1, ["x"] = 2 } }))
local spare = nil
for _, c in cells do if c.Kind == "Spare" then spare = c end end
check(spare and spare.Tier == 4 and spare.Plus == 2 and spare.Count == 3 and spare.Tab == "Gear", "A23-127 spares ('tier:plus') show on Gear", spare and spare.Key)
local nspare = 0
for _, c in cells do if c.Kind == "Spare" then nspare += 1 end end
check(nspare == 1, "a bad spare key / tier is ignored", nspare)

-- new things (seq above the base the first payload set, not looked at yet)
cells = BagUI.Cells(ctxOf({ SeqBase = 5, SeenSeq = { ["I:Enh70"] = 7 } }))
byKey = {}
for _, c in cells do byKey[c.Key] = c end
check(byKey["I:Jelly"].New and byKey["W:4"].New and not byKey["I:Enh70"].New and not byKey["I:SlimeCore"].New,
	"new = gained after the bag's first data and not looked at")
cells = BagUI.Cells(ctxOf())
check(not cells[1].New, "no base yet = nothing is new (the first login shows no dots)")

------------------------------------------------------------------ 2. sorting
local mats = BagUI.TabCells(BagUI.Cells(ctxOf({ Items = { Jelly = 1, SlimeCore = 1, Bone = 1, KnightCrest = 1 },
	ItemSeq = { Jelly = 1, SlimeCore = 4, Bone = 9, KnightCrest = 2 } })), "Material")
local function keys(list)
	local out = {}
	for _, c in list do table.insert(out, c.Id or c.Key) end
	return table.concat(out, ",")
end
check(keys(BagUI.Sort(mats, "Default")) == "Bone,SlimeCore,KnightCrest,Jelly", "Newest: the latest gained first (A23-32 default)", keys(BagUI.Sort(mats, "Default")))
check(keys(BagUI.Sort(mats, "Name")) == "Jelly,Bone,KnightCrest,SlimeCore", "Name: by the shown name", keys(BagUI.Sort(mats, "Name")))
check(keys(BagUI.Sort(mats, "Grade")) == "KnightCrest,SlimeCore,Jelly,Bone", "Grade: the higher grade first, then the name", keys(BagUI.Sort(mats, "Grade")))
check(keys(BagUI.Sort(mats, "Bogus")) == keys(BagUI.Sort(mats, "Default")), "an unknown sort = Newest")
local gear = BagUI.Sort(BagUI.TabCells(BagUI.Cells(ctxOf({ Spares = { ["1:0"] = 1 } })), "Gear"), "Kind")
check(gear[1].Kind == "Weapon" and gear[#gear].Kind == "Spare", "Type: weapons before spares", gear[#gear].Kind)
check(gear[1].Tier == 4, "Type: within a kind the higher grade first", gear[1].Tier)
for _, m in T.L.Sorts do
	check(table.find(Config.Settings.Defs.BagSort.Options, m) ~= nil, "every sort is a Settings.BagSort option", m)
end
check(Config.Settings.Defs.BagWide and Config.Settings.Defs.BagWide.Type == "Bool" and Config.Data.Defaults.Settings.BagWide == false,
	"Settings.BagWide is a saved Bool, narrow by default")

------------------------------------------------------------------ 3. columns
check(BagUI.Columns(BagUI.WindowWidth(false) - 36, false) == 4, "narrow window: 4 columns", BagUI.Columns(BagUI.WindowWidth(false) - 36, false))
check(BagUI.Columns(BagUI.WindowWidth(true) - 36, true) == 8, "wide window: 8 columns", BagUI.Columns(BagUI.WindowWidth(true) - 36, true))
check(BagUI.Columns(450, true) < 8 and BagUI.Columns(450, true) >= 3, "a window Panels had to shrink keeps fewer (>= 3) columns", BagUI.Columns(450, true))
check(BagUI.Columns(0, true) == 8, "not measured yet: the asked columns")

------------------------------------------------------------------ 4. potions
local t, ok = BagUI.PotionState({ Count = 3, ReadyAt = NOW + 2.2, Now = NOW, Amount = 10, Max = 100 })
check(t == "3 s" and not ok, "cooling down: seconds left, off", t)
t, ok = BagUI.PotionState({ Count = 3, Now = NOW, Amount = 100, Max = 100 })
check(t == "Full" and not ok, "a full bar: Full, off", t)
t, ok = BagUI.PotionState({ Count = 3, Now = NOW, Amount = 100, Max = 100, Sip = true })
check(ok, "A23-110 KO1: PotionSip lets a full bar drink")
t, ok = BagUI.PotionState({ Count = 0, Now = NOW, Amount = 1, Max = 100 })
check(not ok and t == "Empty", "none left: Empty, off (UiSandbox 10/12)", t)
t, ok = BagUI.PotionState({ Count = 2, Now = NOW, Amount = 10, Max = 100, Busy = true })
check(not ok, "busy (just sent / dead / loading): off")
t, ok = BagUI.PotionState({ Count = 2, Now = NOW, Amount = 10, Max = 100 })
check(t == "Drink" and ok, "else Drink", t)

------------------------------------------------------------------ 5. scroll steps
cells = BagUI.Cells(ctxOf({ Enhance = { [1] = 0, [2] = 10, [4] = 1 } }))
byKey = {}
for _, c in cells do byKey[c.Key] = c end
local m = { Item = "Enh70" }
check(BagUI.CellEnabled(m, byKey["W:1"]) and not BagUI.CellEnabled(m, byKey["W:2"]), "enhance: a +Max weapon can't be picked")
check(not BagUI.CellEnabled(m, byKey["I:Jelly"]), "only weapons are picked")
check(BagUI.Pick(m, byKey["W:4"]).Tier == 4, "enhance: tapping a weapon picks it")
m = { Item = "Move30" }
check(not BagUI.CellEnabled(m, byKey["W:1"]) and BagUI.CellEnabled(m, byKey["W:4"]), "transfer: the source needs +1 or more")
m = BagUI.Pick(m, byKey["W:4"])
check(m.From == 4, "transfer: first tap = the source")
check(not BagUI.CellEnabled(m, byKey["W:2"]) and BagUI.CellEnabled(m, byKey["W:1"]), "transfer: a +Max weapon can't receive")
local m2 = BagUI.Pick(m, byKey["W:1"])
check(m2.From == 4 and m2.To == 1, "transfer: second tap = the receiver")
check(BagUI.Pick(m, byKey["W:4"]).From == nil, "transfer: tapping the source again drops it")
check(BagUI.ValidMode({ Item = "Enh70", Tier = 2 }, cells).Tier == nil, "a weapon that reached +Max drops out of the step")
check(BagUI.ValidMode({ Item = "Enh10" }, cells) == nil, "a used-up scroll ends the step")

------------------------------------------------------------------ 6. the detail column
local function detail(cell, t2)
	local c = { Level = 10, Combat = false, Seen = { Slime = true, BigSlime = true }, Cells = cells,
		PowerNow = 100, Power = function(tier, plus) return 100 + tier * 10 + plus end }
	for k, v in t2 or {} do c[k] = v end
	return BagUI.Detail(cell, c)
end
local function action(view, id)
	for _, a in view.Actions do if a.Id == id then return a end end
	return nil
end
local function lineWith(view, s)
	for _, l in view.Lines do if string.find(l.Text, s, 1, true) then return l end end
	return nil
end
cells = BagUI.Cells(ctxOf({ Mask = 0b1001011, Enhance = { [1] = 0, [2] = 3, [4] = 1 } }))
byKey = {}
for _, c in cells do byKey[c.Key] = c end
local v = detail(byKey["W:2"])
check(action(v, "Equip").Text == "Equipped" and not action(v, "Equip").Enabled, "the equipped weapon: Equipped, off")
check(lineWith(v, "Power 100") and not lineWith(v, "→"), "the equipped weapon: its power only", v.Lines[2] and v.Lines[2].Text)
check(lineWith(v, "Attack ") ~= nil, "weapons: the attack at my level with the +N")
v = detail(byKey["W:1"])
check(action(v, "Equip").Text == "Equip" and action(v, "Equip").Enabled, "another usable weapon: Equip")
check(lineWith(v, "Power 100 → 110") ~= nil, "Equip shows the power change first", v.Lines[2] and v.Lines[2].Text)
v = detail(byKey["W:7"] or byKey["W:4"])
local lockTier = byKey["W:7"] and 7 or 4
check(action(v, "Equip").Text == string.format("From Lv %d", Config.Weapons[lockTier].MinLevel) and not action(v, "Equip").Enabled,
	"below its MinLevel: From Lv N, off (A23-28)", action(v, "Equip").Text)
check(lineWith(v, "Power") == nil, "a weapon I can't equip yet shows no power change (UiSandbox 10/12)")
check(T.TXT.Worn.PetGear == "Pet" and #T.TXT.Worn.Weapon <= 6, "the worn row's words are one short word each (UiSandbox 10/12)")
v = detail(byKey["W:1"], { Combat = true })
check(action(v, "Equip").Text == "In a fight" and not action(v, "Equip").Enabled, "PvP fight tag: no weapon swap")
v = detail(byKey["W:1"], { Pending = { Kind = "Equip", Tier = 1 } })
check(action(v, "Equip").Text == "Checking…" and not action(v, "Equip").Enabled, "an equip waiting for the server: Checking…")
check(v.Color == Config.WeaponGrade(1).Color and string.find(v.Sub, "★", 1, true) ~= nil, "the name in its grade colour, stars + grade")
v = detail(byKey["P:HP"], { Potion = function() return { Count = 5, Now = NOW, Amount = 10, Max = 100 } end })
check(action(v, "Drink").Enabled and v.Quick == "HP", "a potion: Drink + its quick slot row")
v = detail(byKey["I:Enh70"])
check(action(v, "Use").Enabled and lineWith(v, "+1 on success · 70%") ~= nil, "a scroll: what it does + Use", v.Lines[2] and v.Lines[2].Text)
v = detail(byKey["I:Enh70"], { Combat = true })
check(not action(v, "Use").Enabled, "no scrolls in a PvP fight")
v = detail(byKey["I:Jelly"])
check(lineWith(v, "Sells for 2 each") and lineWith(v, "From: ") and #v.Actions == 0, "a material: its price + who drops it (seen monsters), no buttons")
check(string.find(lineWith(v, "From: ").Text, Config.MonsterTypes.Slime.Short or Config.MonsterTypes.Slime.Name, 1, true) ~= nil,
	"From: names a monster I defeated", lineWith(v, "From: ").Text)
v = detail(byKey["I:Jelly"], { Seen = {} })
check(lineWith(v, "From: ") == nil, "no defeated monster that drops it: no From line")
v = detail(nil, { Mode = { Item = "Enh70" } })
check(lineWith(v, "Pick a weapon.") and action(v, "Cancel") and not action(v, "Enhance"), "a scroll step: pick a weapon, Cancel")
v = detail(nil, { Mode = { Item = "Enh70", Tier = 2 } })
check(lineWith(v, "\n+3 → +4 · 70% chance") and action(v, "Enhance").Enabled, "enhance confirm: before → after + the chance before sending",
	v.Lines[1] and v.Lines[1].Text)
check(lineWith(v, "Weapons never break") ~= nil, "a +1 or more weapon: a fail may drop it one step (safe)")
v = detail(nil, { Mode = { Item = "Enh70", Tier = 1 } })
check(lineWith(v, TXT.FailKeep) ~= nil, "a +0 weapon: nothing changes on a fail")
v = detail(nil, { Mode = { Item = "Enh70", Tier = 2 }, Pending = { Kind = "Use", Answered = false } })
check(action(v, "Enhance").Text == "Checking…" and not action(v, "Enhance").Enabled, "a scroll use waiting: Checking…")
v = detail(nil, { Mode = { Item = "Move30", From = 4, To = 1 } })
check(action(v, "Move").Enabled and lineWith(v, "30% chance"), "transfer confirm: Move + the chance")
v = detail(nil, { Mode = { Item = "Enh70", Tier = 2 }, Combat = true })
check(not action(v, "Enhance").Enabled and action(v, "Enhance").Text == "In a fight" and v.Status == nil,
	"a fight: the confirm is off and its button says why (no second line)")

------------------------------------------------------------------ 7. data
BagUI.OnInventory({ Items = { Jelly = 12, Enh70 = 2, Bogus = 3, SlimeCore = -1 }, Enhance = { 0, 3, 0, 1 }, Seen = { Slime = true, Nope = true },
	ItemSeq = { Jelly = 10, Enh70 = 6, PotionHP = 3 }, WeaponSeq = { 1, 4, 0, 2 } })
local D = T.S.Data
check(D.Items.Jelly == 12 and D.Items.Bogus == nil and D.Items.SlimeCore == nil, "the payload keeps known ids with count >= 1")
check(D.Seen.Slime == true and D.Seen.Nope == nil, "seen monsters: known kinds only")
check(T.S.SeqBase == 10, "the first payload sets the base (nothing old is new)", T.S.SeqBase)
BagUI.OnInventory({ Items = { Jelly = 13, Enh70 = 2 }, Enhance = { 0, 3, 0, 1 }, ItemSeq = { Jelly = 11, Enh70 = 6, PotionHP = 3 }, WeaponSeq = { 1, 4, 0, 2 } })
check(T.S.SeqBase == 10, "later payloads keep the base")

------------------------------------------------------------------ 8. the window
root = newObj("Frame", { Name = "FixedBody", AbsoluteSize = vec(BagUI.WindowWidth(false) - 36, 540) })
update = o.Build(root, kit, nil)
local function cellsIn(tab)
	return findAll(root, "^Cell_")
end
check(#findAll(root, "^Tab_") == 4 and find(root, "Tab_Gear").Text == "Gear" and find(root, "Tab_Material").Text == "Materials",
	"four tabs: Gear · Use · Scrolls · Materials")
check(find(root, "Tab_Gear").PaintColor == "gold" and find(root, "Tab_Use").PaintColor == "button", "the open tab is gold")
check(find(root, "WornWeapon") and find(root, "WornArmor") and find(root, "WornRing") and find(root, "WornPetGear"),
	"Gear: the worn row Weapon · Armor · Ring · Pet gear (A23-133 places)")
check(find(root, "WornArmor").Image == "SlotEmpty" and find(root, "WornArmor").OnClick == nil, "armor / ring / pet gear: empty places for now")
check(find(root, "WornWeapon").Image == "SlotUncommon" or find(root, "WornWeapon").Image == "SlotCommon", "the worn weapon in its grade slot",
	find(root, "WornWeapon").Image)
local gearCells = cellsIn()
check(#gearCells == 3, "Gear lists the 3 owned weapons", #gearCells)
local empties = findAll(root, "^Empty$")
check(#empties >= 1 and (#gearCells + #empties) % 4 == 0, "empty dark slots fill the rows (4 columns)", #gearCells + #empties)
local first = gearCells[1]
check(first:FindFirstChild("Picked") ~= nil, "the first cell is picked when nothing was")
local eq = find(root, "Cell_W:2")
check(eq and find(eq, "Equipped") and find(eq, "Plus") and find(eq, "Plus").Text == "+3", "equipped check + its +3 top-left")
check(find(root, "Cell_W:4") and find(find(root, "Cell_W:4"), "Plus").Text == "+1" and find(find(root, "Cell_W:4"), "Count") == nil,
	"a count of 1 is not written")
-- tap + equip
find(root, "Cell_W:4").OnClick()
check(find(root, "Cell_W:4"):FindFirstChild("Picked") ~= nil and find(root, "Name").Text == Config.WeaponName(4, "Warrior", "Halo"),
	"tapping a cell picks it and shows it on the right")
attrs.Level = 20
BagUI.Redraw()
local act = find(root, "Act_Equip")
check(act and act.Enabled, "Equip is on for a usable weapon")
act.OnClick()
check(#fired == 1 and fired[1][1] == "EquipWeapon" and fired[1][2] == 4, "Equip sends EquipWeapon(tier)", fired[1] and fired[1][1])
find(root, "Act_Equip").OnClick()
check(#fired == 1, "no second send while the first waits")
check(find(root, "Act_Equip").Text == "Checking…", "the button waits for the answer")
attrs.WeaponTier = 4
for _, f in attrFns do f("WeaponTier") end
CLOCK += 1
update()
check(T.S.Pending == nil, "the weapon change answers the request")
-- the scroll tab -> use -> pick -> confirm -> send
find(root, "Tab_Scroll").OnClick()
check(find(root, "Tab_Scroll").PaintColor == "gold" and find(root, "Cell_I:Enh70") ~= nil, "Scrolls tab shows the scroll")
find(root, "Act_Use").OnClick()
check(T.S.Tab == "Gear" and T.S.Mode and T.S.Mode.Item == "Enh70", "Use: the weapons to pick from")
check(textIn(root, "Pick a weapon.") ~= nil, "it says to pick a weapon")
find(root, "Cell_W:2").OnClick()
check(T.S.Mode.Tier == 2 and textIn(root, "+3 → +4") ~= nil, "tapping a weapon shows the confirm")
find(root, "Act_Enhance").OnClick()
local last = fired[#fired]
check(last[1] == "UseItem" and last[2] == "Enh70" and last[3] == 2, "Enhance sends UseItem(scroll, tier)", last[1])
check(find(root, "Act_Enhance").Text == "Checking…", "the confirm waits")
lastResult, lastAt = { Tier = 2, Before = 3, After = 4, Success = true }, CLOCK + 0.1
CLOCK += 1
update()
check(T.S.Pending == nil and T.S.Mode and T.S.Mode.Tier == 2, "a result answers it; the same step stays for one-tap retries")
find(root, "Act_Cancel").OnClick()
check(T.S.Mode == nil and T.S.Tab == "Scroll" and T.S.Sel == "I:Enh70", "Cancel goes back to the scroll")
-- potions + quick slots
find(root, "Tab_Use").OnClick()
check(find(root, "Cell_P:HP") ~= nil and find(root, "Act_Drink") and find(root, "Quick1"), "Use: the potion with Drink + quick slots 1 2 3")
local mpCell = find(root, "Cell_P:MP")
check(mpCell and find(mpCell, "Count") and find(mpCell, "Count").Text == "0" and find(mpCell, "Icon").ImageTransparency > 0.3,
	"an empty potion keeps its slot: 0, dimmed (its quick slots stay reachable)")
mpCell.OnClick()
check(find(root, "Act_Drink") and not find(root, "Act_Drink").Enabled and find(root, "Quick1") ~= nil,
	"the empty potion: Drink off, quick slot buttons there")
find(root, "Cell_P:HP").OnClick()
local before = #fired
find(root, "Act_Drink").OnClick()
check(#fired == before + 1 and fired[#fired][1] == "UsePotion" and fired[#fired][2] == "HP", "Drink sends UsePotion(HP)")
find(root, "Quick2").OnClick()
check(quick[2] == "HP", "a quick slot button puts it there")
find(root, "Quick2").OnClick()
check(quick[2] == "", "again = takes it out")
-- sort + size
local sorts = {}
for _ = 1, 4 do
	find(root, "Sort").OnClick()
	table.insert(sorts, settings.BagSort)
end
check(table.concat(sorts, ",") == "Name,Grade,Kind,Default", "the sort button cycles Name → Grade → Type → Newest (saved)", table.concat(sorts, ","))
check(find(root, "SortName").Text == "Newest", "the sort's name is shown")
local rb = rebuilds
find(root, "Size").OnClick()
check(settings.BagWide == true and rebuilds == rb + 1, "the size button saves wide and lays the window out again")
check(find(root, "Size"):FindFirstChild("Glyph").Image == "GlyphShrink", "wide shows the shrink glyph")
settings.BagWide = false
check(find(root, "Gold").Text == "1,234", "the gold line = bank + carried", find(root, "Gold").Text)
attrs.BankGold = 2000
local g0 = find(root, "Grid")
for _, f in attrFns do f("BankGold") end
check(find(root, "Gold").Text == "2,034" and find(root, "Grid") == g0, "a coin repaints the gold line only, not the grid",
	find(root, "Gold").Text)
-- new things: a tab count, the dot, seen when the tab is left
BagUI.OnInventory({ Items = { Jelly = 14, Enh70 = 2, Bone = 1 }, Enhance = { 0, 3, 0, 1 },
	ItemSeq = { Jelly = 12, Enh70 = 6, PotionHP = 3, Bone = 13 }, WeaponSeq = { 1, 4, 0, 2 } })
local badge = find(find(root, "Tab_Material"), "NewCount")
check(badge and find(badge, "N").Text == "2", "the Materials tab counts its 2 new things", badge and find(badge, "N").Text)
find(root, "Tab_Material").OnClick()
check(find(find(root, "Cell_I:Bone"), "New") ~= nil, "a new thing has its dot while the tab is open")
find(root, "Tab_Gear").OnClick()
check(find(find(root, "Tab_Material"), "NewCount") == nil, "leaving the tab = seen (no count)")
find(root, "Tab_Material").OnClick()
check(find(find(root, "Cell_I:Bone"), "New") == nil, "and no dot")
-- the body measured later (a taller window): the grid redraws with more empty rows; one live size watcher
local function live()
	local n = 0
	for _, r in signals do if r.Live and r.Obj == root and r.Prop == "AbsoluteSize" then n += 1 end end
	return n
end
check(live() == 1, "one size watcher for the open window (the old ones are dropped)", live())
find(root, "Tab_Gear").OnClick()
local beforeEmpty = #findAll(root, "^Empty$")
root.AbsoluteSize = vec(BagUI.WindowWidth(false) - 36, 900)
for _, r in signals do if r.Live and r.Obj == root and r.Prop == "AbsoluteSize" then r.Fn() end end
check(#findAll(root, "^Empty$") > beforeEmpty, "a taller window fills more rows with empty slots", #findAll(root, "^Empty$"))
root.AbsoluteSize = vec(BagUI.WindowWidth(false) - 36, 540)
for _, r in signals do if r.Live and r.Obj == root and r.Prop == "AbsoluteSize" then r.Fn() end end
-- opened straight on a scroll's step (arg.Use [+ Tier])
reg.Bag.Cleanup()
for _, ch in root:GetChildren() do ch:Destroy() end
update = reg.Bag.Build(root, kit, { Use = "Enh70", Tier = 2 })
check(T.S.Tab == "Gear" and T.S.Mode and T.S.Mode.Item == "Enh70" and T.S.Mode.Tier == 2 and find(root, "Act_Enhance") ~= nil,
	"arg.Use opens the scroll's step on the weapons (with the picked weapon)")
reg.Bag.Cleanup()
for _, ch in root:GetChildren() do ch:Destroy() end
update = reg.Bag.Build(root, kit, { Use = "Jelly" })
check(T.S.Mode == nil, "arg.Use with a material is ignored")
-- the open arg is used once: a rebuild (size change) keeps the tab I moved to
openArg = { Tab = "Use" }
reg.Bag.Cleanup()
for _, ch in root:GetChildren() do ch:Destroy() end
update = reg.Bag.Build(root, kit, openArg)
check(T.S.Tab == "Use", "opened on its arg's tab")
find(root, "Tab_Gear").OnClick()
kit.Rebuild()
check(T.S.Tab == "Gear", "a rebuild with the same open arg keeps the tab I moved to (게임성 검수 10/12)", T.S.Tab)
openArg = nil
-- a fight flips the buttons in place
find(root, "Tab_Gear").OnClick()
find(root, "Cell_W:1").OnClick()
attrs.InCombatUntil = NOW + 5
local gridBefore = find(root, "Grid")
update()
check(find(root, "Act_Equip").Text == "In a fight", "the 0.25 s update shows the fight tag")
check(find(root, "Grid") == gridBefore, "a live change repaints the detail only (the grid stays)")
attrs.InCombatUntil = 0
update()
find(root, "Act_Equip").OnClick()
check(T.S.Pending ~= nil, "an equip waits for its answer")
CLOCK += 4
update()
check(T.S.Pending == nil and textIn(root, "No answer") == nil, "no answer: it stops waiting quietly (the server's toast says why)")
-- an item with no icon art yet: its name's first letter in its colour, not a blank slot (UiSandbox 10/12)
BagUI.OnInventory({ Items = { Jelly = 14, Enh70 = 2, Bone = 1, Petal = 6 }, Enhance = { 0, 3, 0, 1 },
	ItemSeq = { Jelly = 12, Enh70 = 6, PotionHP = 3, Bone = 13, Petal = 14 }, WeaponSeq = { 1, 4, 0, 2 } })
find(root, "Tab_Material").OnClick()
local petal = find(root, "Cell_I:Petal")
check(petal and find(petal, "Letter") and find(petal, "Letter").Text == "F", "no icon art: the first letter (Flower Petal = F)",
	petal and find(petal, "Letter") and find(petal, "Letter").Text)
local jelly = find(root, "Cell_I:Jelly")
check(jelly and find(jelly, "Letter") == nil, "an item with art shows its icon, no letter")

-- a payload that reached Panels before this module bound its listener: taken from Panels (LastInventory)
local bf2 = assert(loadstring(BAG_SOURCE, "=BagUI2"))
setfenv(bf2, env)
local Bag2 = bf2()
local reg2 = {}
Bag2.Init({ Panels = { Register = function(id, opts) reg2[id] = opts return true end,
	LastInventory = function() return { Items = { Jelly = 7 }, Enhance = {}, ItemSeq = { Jelly = 1 }, WeaponSeq = {} } end },
	UIKit = UIKit, Settings = Settings, QuickSlots = QuickSlots })
local root2 = newObj("Frame", { Name = "FixedBody2", AbsoluteSize = vec(BagUI.WindowWidth(false) - 36, 540) })
reg2.Bag.Build(root2, kit, { Tab = "Material" })
check(find(root2, "Cell_I:Jelly") ~= nil, "a payload Panels got first is taken from Panels (LastInventory)")

print(string.format("BAG_UI_SUMMARY checks=%d failed=%d", checks, failed))
