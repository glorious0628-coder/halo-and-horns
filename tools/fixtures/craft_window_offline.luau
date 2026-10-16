-- ③-3 제작 창 (게임성 개발 4, 2026-10-12): runs the real Config.luau and the real CraftWindow.luau
-- (tools/test_craft_window.py) on small doubles: Players.LocalPlayer attributes, a recording Instance tree, a Panels
-- registry that builds the window with a recording kit, UIKit art doubles, the CraftInfo remote, CollectionService
-- benches, the Crossroads anvil, CraftView.IsOpen. Inputs: CONFIG_SOURCE, WINDOW_SOURCE. Every check is named.
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
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
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
-- 장인 ② (게임성 개발 2, 10/14): the shipped W1 is gone (tier 1 = the free class weapon); the window's groups keep a test-only
-- W1 with its old numbers, and W2 is the first craft from N0's harvest (3 herbs + 2 copper)
assert(Config.Craft.Recipes.W1 == nil, "the shipped W1 is gone (장인 ②)")
Config.Craft.Recipes.W1 = { Role = "Smith", Kind = "Weapon", Tier = 1, Lv = 1, Gold = 10, Mats = { Jelly = 5, CopperOre = 2 }, XP = 10 }
Config.Features.Crafting = true
-- test-only recipe: an alchemist item (Kind Item, x2). GPT review 10/16: the shipped gear (G / R / PA / PC) and potion
-- (AP1 / AP2) rows are listed now, with their real numbers
Config.Craft.Recipes.ZTestItem = { Role = "Alch", Kind = "Item", Item = "Jelly", N = 2, Lv = 1, Gold = 5, Mats = { Petal = 1 }, XP = 5 }

------------------------------------------------------------------ an Instance tree double
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
	return o
end
omt.__index = function(o, k)
	local p = rawget(o, "__p")
	local methods = {
		GetChildren = function(self) return table.clone(rawget(self, "__p").Children) end,
		Destroy = function(self)
			local q = rawget(self, "__p")
			if q.Parent then
				local kids = rawget(q.Parent, "__p").Children
				local i = table.find(kids, self)
				if i then table.remove(kids, i) end
			end
			q.Parent = nil
			q.Destroyed = true
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
	if k == "Activated" then
		return { Connect = function(_, f) p.OnActivate = f end }
	end
	return p[k]
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

------------------------------------------------------------------ doubles
local CLOCK = 100
local attrs = { Class = "Warrior", Faction = "Neutral", ClassChosen = true, Level = 1, BankGold = 1200, CarriedGold = 34,
	AutoCombatUnlocked = false, AutoCombatEnabled = false }
local attrSig = {} -- [attribute] = the module's change handler
local player = { GetAttribute = function(_, k) return attrs[k] end,
	GetAttributeChangedSignal = function(_, k) return { Connect = function(_, f) attrSig[k] = f end } end }
local rootPos = vec(0, 0, 0)
local hasRoot = true
local alive = true
local Util = {
	Warn = function(...) print("WARN", ...) end,
	Now = function() return 1000 end,
	FormatInt = function(n)
		local s = tostring(math.floor(n))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end,
	GetRoot = function() return hasRoot and { Position = rootPos } or nil end,
	IsAlive = function() return alive end,
}
local L10nReg = {}
local WORDS = { en = { ["Config.Craft.Text.Prompt"] = "Craft", ["Config.Craft.Text.Stations.Smith"] = "Anvil",
	["Config.Craft.Text.Stations.Alch"] = "Cauldron" }, ko = { ["Config.Craft.Text.Prompt"] = "제작", ["Config.Craft.Text.Stations.Smith"] = "모루" } }
local curLang = "en"
local L10n = { Register = function(path, t) L10nReg[path] = t return t end,
	T = function(key, _, lang) return (WORDS[lang] or WORDS.en)[key] or key end, LangOf = function() return curLang end }
local handlers = {}
local remotes = { FindFirstChild = function(_, name)
	return { IsA = function(_, c) return c == "RemoteEvent" end,
		OnClientEvent = { Connect = function(_, f) handlers[name] = f end } }
end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function() return shared end, FindFirstChild = function(_, n) return n == "Remotes" and remotes or nil end }
local benches = {}
local function benchPart(role, x)
	return { Position = vec(x, 0, 0), IsA = function(_, c) return c == "BasePart" end,
		GetAttribute = function(_, k) return k == "Role" and role or nil end }
end
local tagAdded, tagRemoved = nil, nil
local CS = { GetTagged = function(_, tag) return tag == Config.Craft.StationTag and benches or {} end,
	GetInstanceAddedSignal = function() return { Connect = function(_, f) tagAdded = f end } end,
	GetInstanceRemovedSignal = function() return { Connect = function(_, f) tagRemoved = f end } end }
-- a workbench part with the server's "CraftPrompt" (ActionText / ObjectText "", the two keys as attributes)
local function promptPart(action, object)
	local a = { ActionKey = action, ObjectKey = object }
	return { Name = "CraftPrompt", ActionText = "", ObjectText = "", Enabled = true,
		IsA = function(_, c) return c == "ProximityPrompt" end, GetAttribute = function(_, k) return a[k] end }
end
local function station(role, x, prompt)
	local s = { Position = vec(x, 0, 0), Kids = {}, Prompt = prompt }
	s.IsA = function(_, c) return c == "BasePart" end
	s.GetAttribute = function(_, k) return k == "Role" and role or nil end
	s.FindFirstChild = function(_, n) return s.Kids[n] end
	s.ChildAdded = { Connect = function(_, f) s.OnChild = f return { Disconnect = function() s.OnChild = nil end } end }
	if prompt then s.Kids.CraftPrompt = prompt end
	return s
end
local anvil = nil -- the Crossroads anvil part while it exists
local function node(children)
	return { FindFirstChild = function(_, n) return children[n] end }
end
local ws = { GetServerTimeNow = function() return 1000 end, FindFirstChild = function(_, n)
	if n ~= "Map" or not anvil then return nil end
	return node({ Landmarks = node({ ArtisanGuild = node({ Anvil = anvil }) }) })
end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	if n == "CollectionService" then return CS end
	return nil
end }
local mods = { Config = Config, Util = Util, L10n = L10n, Net = { Names = { "CraftStart" } } } -- UnpackSpare added in §contract ③

local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance, env.workspace = game, Instance, ws
-- the doubles with an IsA method are Instances (benches, prompts, the recording tree)
env.typeof = function(v)
	if type(v) == "table" and type(v.IsA) == "function" then return "Instance" end
	return typeof(v)
end
env.require = function(n) return mods[n] end
env.os = setmetatable({ clock = function() return CLOCK end }, { __index = os })
local spawned = {}
env.task = { spawn = function(f) table.insert(spawned, f) end, defer = function(f, ...) f(...) end, delay = function() end,
	wait = function() end }
local wf = assert(loadstring(WINDOW_SOURCE, "=CraftWindow"))
setfenv(wf, env)
local CraftWindow = wf()

local reg = {}
local root, update = nil, nil -- the open window's body and its 0.25 s update
local openArg = nil
local fired = {}
local attrFns = {}
local opened = {} -- Panels.Open calls
local panelOpen = false
local inventory = { Items = { Jelly = 12, Petal = 1, CopperOre = 4 } }
local kit
kit = {
	Font = "Font.Gotham", Theme = { Gold = "gold", Text = "text", SubText = "sub", Good = "good", Bad = "bad" },
	Palette = { Button = "button", DarkText = "dark", Free = "free", Buy = "buy" },
	Button = function(parent, text, color, size, onClick)
		return newObj("TextButton", { Text = text, Color = color, OnClick = onClick, Parent = parent })
	end,
	Paint = function(b, color) b.PaintColor = color end,
	SetEnabled = function(b, en) b.Enabled = en end,
	Fire = function(name, ...) table.insert(fired, { name, ... }) end,
	OnAttr = function(f) table.insert(attrFns, f) end,
}
local panels = {
	Register = function(id, opts) reg[id] = opts return true end,
	LastInventory = function() return inventory end,
	Open = function(id, arg) table.insert(opened, { id, arg }) end,
	IsOpen = function() return panelOpen end,
}
local ringOpen = false
local CraftView = { IsOpen = function() return ringOpen end }
local function artObj(class, name, props)
	local o = newObj(class, { Image = name })
	for k, v in props or {} do
		if k ~= "Parent" then o[k] = v end
	end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end
local barFraction = nil
local langFn = nil -- UIKit.LangChanged's handler
local UIKit = {
	ArtImage = function(name, props) return artObj("ImageLabel", name, props) end,
	ArtFrame = function(name, props) return artObj("Frame", name, props) end,
	ArtButton = function(name, props, onClick)
		local b = artObj("ImageButton", name, props)
		b.OnClick = onClick
		return b
	end,
	ArtBar = function(props)
		local f = artObj("Frame", "BarTrack", props)
		f.Text = props.Text
		return f, function(x) barFraction = x end, nil
	end,
	ItemIcon = function(id, props)
		if id == "Petal" or id == "Herb" then return nil end -- items whose icon is not drawn yet (Herb: W2's first material, 장인 ②)
		local o = artObj("ImageLabel", "Icon:" .. tostring(id), props)
		o.ItemId = id
		return o
	end,
	StyleText = function(l, style) l.Style = style end,
	Lang = function() return curLang end,
	LangChanged = { Connect = function(_, f) langFn = f end },
	Tx = function(t, key, ...)
		local s = t[key .. "En"] or t[key]
		if type(s) ~= "string" then return "" end
		if select("#", ...) > 0 then return string.format(s, ...) end
		return s
	end,
}
CraftWindow.Init({ Panels = panels, UIKit = UIKit, CraftView = CraftView })
local T = CraftWindow._T
local TXT = T.TXT
local K = Config.Craft

local function open(arg)
	if root then
		reg.Craft.Cleanup()
		table.clear(attrFns)
	end
	root = newObj("Frame", { Name = "Root" })
	openArg = arg
	panelOpen = true
	update = reg.Craft.Build(root, kit, arg)
end
local function close()
	if root then reg.Craft.Cleanup() end
	table.clear(attrFns)
	root, update, panelOpen = nil, nil, false
end
local function fireAttr(name)
	for _, f in table.clone(attrFns) do f(name) end
end
local function ids(list)
	local out = {}
	for _, e in list do table.insert(out, e.Id) end
	return table.concat(out, ",")
end
local function ctxOf(t)
	local c = { Faction = "Neutral", ClassChosen = true, Class = "Warrior", Items = { Jelly = 12, Petal = 1, CopperOre = 4 },
		Gold = 100, Info = nil, Level = 1 }
	for k, v in t or {} do c[k] = v end
	return c
end
local function entry(list, id)
	for _, e in list do if e.Id == id then return e end end
	return nil
end

------------------------------------------------------------------ 0. registered
local o = reg.Craft
check(o ~= nil and CraftWindow.IsReady(), "the window \"Craft\" is registered")
check(o.FixedBody == true and o.Rebuild == false, "a fixed body that redraws itself (Rebuild = false)")
check(o.Title() == "Crafting", "the title is Crafting", o.Title())
check(L10nReg["CraftWindow.TXT"] == TXT, "the words are a registered L10n table (CraftWindow.TXT, A23-111)")
check(type(o.Width) == "function" and o.Width() == 2 * 18 + 270 + 12 + 240 and o.Width() <= 780, "its own width (<= the 780 du max)", o.Width())
check(type(handlers.CraftInfo) == "function", "CraftInfo is bound at Init (the join's info is never missed)")
check(o.Menu() == "Crafting", "the menu entry for an artisan while crafting is on", o.Menu())
attrs.Faction = "Halo"
check(o.Menu() == nil, "no menu entry outside the artisan guild")
attrs.Faction = "Neutral"
attrs.ClassChosen = false
check(o.Menu() == nil, "no menu entry before the class is chosen")
attrs.ClassChosen = true
Config.Features.Crafting = false
check(o.Menu() == nil, "no menu entry while crafting is off (Config.Features.Crafting)")
Config.Features.Crafting = true

------------------------------------------------------------------ 1. the model
check(CraftWindow.RoleOf(ctxOf()) == "Smith" and CraftWindow.RoleOf(ctxOf({ Class = "Mage" })) == "Alch"
	and CraftWindow.RoleOf(ctxOf({ Class = "Archer" })) == "Tame", "artisan class -> role (Warrior Smith · Mage Alch · Archer Tame)")
check(CraftWindow.RoleOf(ctxOf({ Faction = "Horns" })) == nil and CraftWindow.RoleOf(ctxOf({ ClassChosen = false })) == nil,
	"no role outside the guild / before the class")
local list = CraftWindow.Entries(ctxOf())
check(ids(list) == "W1,W2,W3,G1,R1,W4,W5,G2,R2,W6,G3,R3,W7,W9", "the smith's recipes, lowest level first (then tier); W7 / W9 since C1; armor / rings listed (GPT review 10/16: Gear was hidden)", ids(list))
do -- GPT review 10/16: gear and potion rows (they were left out, so AP1 / AP2 and the armor / rings could not be made)
	local g1, r2 = entry(list, "G1"), entry(list, "R2")
	check(g1 and g1.Name == "Armor I" and g1.Grade == "Fine" and g1.Stat == "HP +6%" and g1.Wear == 10 and g1.Lv == 8 and g1.Locked,
		"a gear row: '<slot> <tier>', the tier's grade, its stat, the level to wear it, locked below its craft level", g1 and (g1.Name .. "|" .. tostring(g1.Stat)))
	check(r2 and r2.Name == "Ring II" and r2.Grade == "Rare" and r2.Stat == "Attack +8%" and r2.Icon == "GearRing",
		"a ring row (no icon art yet: the slot's letter)", r2 and r2.Name)
	local alch = CraftWindow.Entries(ctxOf({ Class = "Mage" }))
	local ap1, ap2 = entry(alch, "AP1"), entry(alch, "AP2")
	check(ap1 and ap1.Name == "HP Potion" and ap1.Icon == "IconPotionHP" and ap1.N == 2 and ap2 and ap2.Name == "MP Potion"
		and ap2.Icon == "IconPotionMP", "the alchemist's first potions (AP1 HP / AP2 MP, x2 each)", ap1 and ap1.Name)
	local tame = CraftWindow.Entries(ctxOf({ Class = "Archer" }))
	local pa1 = entry(tame, "PA1")
	check(pa1 and pa1.Name == "Pet Armor I" and pa1.Stat == "Pet XP +20%" and pa1.Wear == nil, "the tamer's pet gear (no player level to wear)", pa1 and pa1.Name)
	local dv = CraftWindow.Detail(g1, ctxOf())
	local function lineWith(v, t) for _, l in v.Lines do if string.find(l.Text, t, 1, true) then return l end end return nil end
	check(lineWith(dv, "HP +6%") ~= nil and lineWith(dv, "Use from Lv 10") ~= nil, "the gear's detail: its stat and the level to wear it")
end
do -- C1 made W7 / W9's boss materials real, so a test recipe keeps the "material not in the game = hidden" rule covered
	K.Recipes.WTEST = { Role = "Smith", Kind = "Weapon", Tier = 2, Lv = 1, Gold = 1, Mats = { NoSuchMaterial = 1 }, XP = 1 }
	local l2 = CraftWindow.Entries(ctxOf())
	check(entry(l2, "WTEST") == nil and #l2 == #list, "a recipe with a material not in the game (a test id) stays hidden", ids(l2))
	K.Recipes.WTEST = nil
	K.Recipes.XTEST = { Role = "Smith", Kind = "Mystery", Lv = 1, Gold = 1, Mats = { Jelly = 1 }, XP = 1 }
	check(entry(CraftWindow.Entries(ctxOf()), "XTEST") == nil, "a recipe kind the window does not know stays hidden")
	K.Recipes.XTEST = nil
end
do -- (a test id: 개발 3's own alchemist recipes A1~A4 join Config later)
	local alch = CraftWindow.Entries(ctxOf({ Class = "Mage" }))
	local onlyAlch = #alch >= 1
	for _, e in alch do
		if K.Recipes[e.Id].Role ~= "Alch" then onlyAlch = false end
	end
	check(onlyAlch and entry(alch, "ZTestItem") ~= nil and entry(alch, "W1") == nil, "only my role's recipes (the alchemist sees hers)", ids(alch))
end
check(#CraftWindow.Entries(ctxOf({ Faction = "Halo" })) == 0, "nothing for a non-artisan")
local w2 = entry(list, "W2")
local mats = {}
for _, m in w2.Mats do table.insert(mats, m.Id .. "=" .. m.Have .. "/" .. m.Need .. (m.Short and "!" or "")) end
check(table.concat(mats, " ") == "Herb=0/3! CopperOre=4/2", "materials in the loot order with have / need, short marked",
	table.concat(mats, " "))
check(w2.MatsShort and not w2.Ready and not w2.Locked, "a short material: not ready")
local w1 = entry(list, "W1")
check(w1.Ready and not w1.GoldShort and w1.Gold == 10 and w1.XP == 10, "W1: everything there -> ready")
check(entry(CraftWindow.Entries(ctxOf({ Gold = 5 })), "W1").GoldShort and not entry(CraftWindow.Entries(ctxOf({ Gold = 5 })), "W1").Ready,
	"too little gold: not ready")
check(entry(list, "W3").Locked, "W3 needs craft Lv 5 (Lv 1 before any CraftInfo)")
check(not entry(CraftWindow.Entries(ctxOf({ Info = { Role = "Smith", Lv = 5 } })), "W3").Locked, "craft Lv 5 opens W3")
check(entry(CraftWindow.Entries(ctxOf({ Info = { Role = "Alch", Lv = 20 } })), "W3").Locked, "another role's level never counts")
check(ids(CraftWindow.Entries(ctxOf({ Info = { Role = "Smith", Lv = 1, On = { W1 = true } } }))) == "W1",
	"the server's On list (what it can make now: weapons wait for the spares) hides the rest")
check(w1.Icon == Config.WeaponArtKey(1, "Warrior", "Neutral") and w1.Name == Config.WeaponName(1, "Warrior", "Neutral"),
	"the weapon's name / icon for my class", w1.Icon)
local a1 = entry(CraftWindow.Entries(ctxOf({ Class = "Mage" })), "ZTestItem")
check(a1 and a1.N == 2 and a1.Icon == "Jelly" and a1.Kind == "Item", "an item recipe: its item icon and count")

------------------------------------------------------------------ 2. reasons (the server's order)
local base2 = ctxOf({ Items = { Jelly = 0 }, Gold = 0 })
local w3 = entry(CraftWindow.Entries(base2), "W3")
check(CraftWindow.Reason(w3, ctxOf({ Faction = "Halo" })) == "NotArtisan", "not an artisan first")
check(CraftWindow.Reason(w3, ctxOf({ Auto = true, Far = true })) == "Auto", "auto combat before the distance")
check(CraftWindow.Reason(w3, ctxOf({ Far = true })) == "Far", "the distance before the level")
check(CraftWindow.Reason(w3, base2) == "NeedLevel", "the level before the materials")
local w1b = entry(CraftWindow.Entries(base2), "W1")
check(CraftWindow.Reason(w1b, base2) == "NeedMats", "the materials before the gold")
check(CraftWindow.Reason(entry(CraftWindow.Entries(ctxOf({ Gold = 0 })), "W1"), ctxOf({ Gold = 0 })) == "NeedGold", "then the gold")
check(CraftWindow.Reason(w1, ctxOf()) == nil, "nothing against it: no reason")

------------------------------------------------------------------ 3. the header
local lv = CraftWindow.LevelView(ctxOf())
check(lv.Text == "Blacksmith Lv 1" and lv.Bar == "0 / " .. Config.CraftXPToNext(1) and lv.Fraction == 0,
	"Blacksmith Lv 1, 0 / 40 before any CraftInfo", lv.Text .. " " .. lv.Bar)
lv = CraftWindow.LevelView(ctxOf({ Info = { Role = "Smith", Lv = 3, XP = 52, Need = 207 } }))
check(lv.Text == "Blacksmith Lv 3" and lv.Bar == "52 / 207" and math.abs(lv.Fraction - 52 / 207) < 1e-9, "level, XP / next, the bar's fill", lv.Bar)
lv = CraftWindow.LevelView(ctxOf({ Info = { Role = "Smith", Lv = K.MaxLv, XP = 0, Need = 0 } }))
check(lv.Bar == "Max" and lv.Fraction == 1, "Max at the top level")
check(CraftWindow.LevelView(ctxOf({ Class = "Archer" })).Text == "Pet Tamer Lv 1", "the tamer's own name")

------------------------------------------------------------------ 4. the detail
local function lineWith(v, s)
	for _, l in v.Lines do if string.find(l.Text, s, 1, true) then return l end end
	for _, l in v.Notes do if string.find(l.Text, s, 1, true) then return l end end
	return nil
end
local v = CraftWindow.Detail(w1, ctxOf())
check(v.Title == w1.Name and v.Grade == w1.Grade and v.Action.Text == "Forge" and v.Action.Enabled and v.Status == nil,
	"a ready recipe: its name, Forge on, no status line")
check(lineWith(v, "Attack ") ~= nil and lineWith(v, "+10 craft XP") ~= nil and v.Gold.Text == "10" and not v.Gold.Short,
	"attack, the craft XP, the gold")
local w5v = CraftWindow.Detail(entry(list, "W5"), ctxOf({ Level = 3 }))
check(lineWith(w5v, "Use from Lv 20") ~= nil, "a weapon above my hunting level says from which level it is usable")
local w2v = CraftWindow.Detail(w2, ctxOf())
check(w2v.Status and w2v.Status.Text == K.Text.NeedMats and w2v.Status.Color == "Bad" and not w2v.Action.Enabled,
	"short materials: the server's own notice text, Forge off", w2v.Status and w2v.Status.Text)
check(w2v.Mats[1].Text == "0 / 3" and w2v.Mats[1].Short and not w2v.Mats[2].Short, "each material: have / need, short in red")
v = CraftWindow.Detail(entry(CraftWindow.Entries(ctxOf({ Info = { Role = "Smith", Lv = 1, Made = { W1 = 2 } } })), "W1"), ctxOf())
check(lineWith(v, "Made 2") ~= nil, "how many I made (CraftInfo.Made)")
v = CraftWindow.Detail(w1, ctxOf({ Pending = true }))
check(v.Action.Text == TXT.Checking and not v.Action.Enabled, "a start waiting: Checking…, off")
v = CraftWindow.Detail(w1, ctxOf({ Gap = true }))
check(v.Action.Text == "Forge" and not v.Action.Enabled, "inside the start interval: off")
v = CraftWindow.Detail(a1, ctxOf({ Class = "Mage" }))
check(v.Action.Text == "Brew" and v.Count == 2, "the alchemist's button says Brew; x2 on the slot")
v = CraftWindow.Detail(nil, ctxOf({ Faction = "Halo" }))
check(v.Status and v.Status.Text == K.Text.NotArtisan and v.Action == nil, "not an artisan: the server's line, no button")
v = CraftWindow.Detail(nil, ctxOf({ Class = "Archer" }))
check(v.Status and v.Status.Text == TXT.None and v.Action == nil, "no recipe yet: one short line")
v = CraftWindow.Detail(w1, ctxOf({ Info = { Role = "Smith", Lv = K.MaxLv, Need = 0 } }))
check(lineWith(v, "craft XP") == nil, "no craft XP line at the top level")

------------------------------------------------------------------ 5. the window
open(nil)
local rows = findAll(root, "^Row_")
check(#rows == 14 and rows[1].Name == "Row_W1", "a row per recipe", #rows)
check(find(find(root, "Row_W1"), "Picked") ~= nil and find(find(root, "Row_W2"), "Picked") == nil, "the first ready recipe is picked (gold rim)")
check(find(find(root, "Row_W1"), "Ready") ~= nil and find(find(root, "Row_W2"), "Ready") == nil, "a gold check on what I can make now")
check(find(find(root, "Row_W3"), "Lv").Text == "Lv 5" and find(find(root, "Row_W3"), "Lv").TextColor3 == "bad", "a locked row's level in red")
check(find(root, "Level").Text == "Blacksmith Lv 1" and find(root, "XPBar") ~= nil and barFraction == 0, "the header: level + XP bar")
check(find(find(root, "Bottom"), "Gold").Text == "1,234", "my gold (bank + carried) at the bottom", find(find(root, "Bottom"), "Gold").Text)
check(find(root, "Detail").VerticalScrollBarInset == "ScrollBarInset.ScrollBar" and find(root, "List").VerticalScrollBarInset == "ScrollBarInset.ScrollBar",
	"both columns keep their words out from under the scroll bar (UiSandbox 10/12: \"5 / 30\" was cut)")
local forge = find(root, "Forge")
check(forge and forge.Text == "Forge" and forge.Enabled == true and forge.Color == "buy", "Forge on for W1 (the gold button)")
check(find(root, "Mat_Jelly") ~= nil and find(root, "Mat_Petal") == nil, "the picked recipe's materials only")
check(find(find(root, "Row_W6"), "Lv").TextScaled == true and find(find(find(root, "Row_W6"), "Lv"), "UITextSizeConstraint") ~= nil
	and find(find(root, "Mat_Jelly"), "Name").TextScaled == true, "the row's level and a material's name shrink to fit (UiSandbox 10/12: \"Lv 20\" ran into the name)")
find(root, "Row_W2").OnActivate()
check(T.S.Sel == "W2" and find(find(root, "Row_W2"), "Picked") ~= nil and find(root, "Forge").Enabled == false, "a tap picks a row; W2 is short -> Forge off")
check(find(find(root, "Mat_Herb"), "Letter") ~= nil and find(find(root, "Mat_Herb"), "Count").Text == "0 / 3",
	"a material without icon art shows its letter; its count line")
check(find(root, "Status").Text == K.Text.NeedMats, "the reason under the cost")
find(root, "Forge").OnClick()
check(#fired == 0, "a click on Forge with a reason against it (a stale button) sends nothing")
-- Forge
find(root, "Row_W1").OnActivate()
find(root, "Forge").OnClick()
check(#fired == 1 and fired[1][1] == "CraftStart" and fired[1][2] == "W1", "Forge sends CraftStart(recipeId)")
find(root, "Forge").OnClick()
check(#fired == 1 and find(root, "Forge").Text == TXT.Checking and find(root, "Forge").Enabled == false, "one start at a time: Checking…, off")
-- the ring opens (CraftView closes this window), then closes: the window comes back on the recipe
ringOpen = true
CLOCK += 0.5
CraftWindow.Watch()
close()
CLOCK += 7
CraftWindow.Watch()
check(#opened == 0, "the window stays shut while the ring is on screen")
ringOpen = false
CraftWindow.Watch()
check(#opened == 1 and opened[1][1] == "Craft" and opened[1][2].Select == "W1", "after the ring the window opens again on the same recipe")
CraftWindow.Watch()
check(#opened == 1, "once")
-- a refusal: no ring within the wait, the button comes back after the interval
open({ Select = "W1" })
CLOCK += 10
fired = {}
find(root, "Forge").OnClick()
check(#fired == 1, "a new start after the interval")
CLOCK += 3.05
CraftWindow.Watch()
check(T.S.Await == nil and find(root, "Forge").Text == "Forge" and find(root, "Forge").Enabled == false,
	"no answer in 3 s (a refusal notice): back to Forge, still inside the interval")
CLOCK += 0.2
update()
check(find(root, "Forge").Enabled == true, "after the interval the update turns it on")
panelOpen = true
ringOpen = true
find(root, "Forge").OnClick()
CraftWindow.Watch()
ringOpen = false
CraftWindow.Watch()
check(#opened == 1, "another window open after the ring: this one does not push in")
panelOpen = true
-- the distance to my bench
fired = {}
CLOCK += 10
benches = { benchPart("Smith", 30) }
update()
check(find(root, "Status") and find(root, "Status").Text == K.Text.Far and find(root, "Forge").Enabled == false, "my bench 30 studs away: Far, off")
benches = { benchPart("Smith", 30), benchPart("Alch", 5) }
update()
check(find(root, "Status") and find(root, "Status").Text == K.Text.Far, "another role's bench does not count")
benches = { benchPart("Smith", 30), benchPart("Smith", 10) }
update()
check(find(root, "Status") == nil and find(root, "Forge").Enabled == true, "the nearest bench of my role within 12 studs: on")
benches = {}
anvil = benchPart(nil, 50)
update()
check(find(root, "Status") and find(root, "Status").Text == K.Text.Far, "no guild bench yet: the Crossroads anvil counts (50 studs: Far)")
anvil = nil
update()
check(find(root, "Status") == nil, "no bench in sight: the server decides (not Far)")
hasRoot = false
update()
check(find(root, "Status") == nil, "no character: not Far")
hasRoot = true
-- auto combat
attrs.AutoCombatUnlocked, attrs.AutoCombatEnabled = true, true
fireAttr("AutoCombatEnabled")
check(find(root, "Status") and find(root, "Status").Text == K.Text.Auto, "auto combat on: its notice, off")
attrs.AutoCombatEnabled = false
fireAttr("AutoCombatEnabled")
check(find(root, "Status") == nil, "auto combat off again: on")
-- new materials (the Inventory push through Panels) redraw in the update
find(root, "Row_W2").OnActivate()
inventory = { Items = { Jelly = 12, Petal = 1, Herb = 3, CopperOre = 4 } }
update()
check(find(root, "Forge").Enabled == true and find(find(root, "Mat_Herb"), "Count").Text == "3 / 3", "new herbs: W2 ready in place")
-- gold
attrs.BankGold, attrs.CarriedGold = 0, 20
fireAttr("BankGold")
check(find(find(root, "Bottom"), "Gold").Text == "20" and find(root, "Status").Text == K.Text.NeedGold, "gold spent elsewhere: NeedGold")
attrs.BankGold = 1200
fireAttr("BankGold")
-- CraftInfo
handlers.CraftInfo({ Role = "Smith", Lv = 5, XP = 30, Need = 447, Made = { W1 = 3, bad = "x" } })
check(find(root, "Level").Text == "Blacksmith Lv 5" and find(find(root, "Row_W3"), "Lv").TextColor3 == "sub", "a CraftInfo redraws: Lv 5, W3 open")
check(T.S.Info.Made.W1 == 3 and T.S.Info.Made.bad == nil, "Made keeps numbers only")
handlers.CraftInfo({ Lv = 9 })
check(T.S.Info.Lv == 5, "a CraftInfo without a role is ignored")
handlers.CraftInfo({ Role = "Smith", Lv = 99, XP = -5, On = { "W1", W2 = true } })
check(T.S.Info.Lv == K.MaxLv and T.S.Info.XP == 0 and T.S.Info.On.W1 and T.S.Info.On.W2, "Lv clamped, XP >= 0, On as a list or a set")
check(#findAll(root, "^Row_") == 2, "the On list hides the rest in the window")
handlers.CraftInfo({ Role = "Smith", Lv = 5, XP = 30, Need = 447 })
-- the open arg once
open({ Select = "W4" })
check(T.S.Sel == "W4", "opened on a recipe (arg.Select)")
find(root, "Row_W1").OnActivate()
-- Panels' rebuild (a size change): Cleanup, the body cleared, its OnAttr callbacks gone, Build with the last arg
reg.Craft.Cleanup()
table.clear(attrFns)
for _, ch in root:GetChildren() do ch:Destroy() end
update = reg.Craft.Build(root, kit, openArg)
check(T.S.Sel == "W1", "a rebuild with the same arg keeps my pick")
-- not an artisan
attrs.Faction = "Halo"
fireAttr("Faction")
check(#findAll(root, "^Row_") == 0 and find(root, "Status").Text == K.Text.NotArtisan and find(root, "Forge") == nil,
	"left the guild: no rows, the server's line, no button")
check(find(root, "List") == nil and find(root, "Detail") == nil and find(root, "Status").Parent.Name == "Body",
	"an empty window: the line in the middle, no empty columns (UiSandbox 10/12)")
attrs.Faction = "Neutral"
close()
-- the poll loop
check(#spawned == 0, "no loop before Start")
local smithP = promptPart("Config.Craft.Text.Prompt", "Config.Craft.Text.Stations.Smith")
local alchP = promptPart("Config.Craft.Text.Prompt", "Config.Craft.Text.Stations.Alch")
local oddP = promptPart("Config.Craft.Text.Nope", nil)
benches = { station("Smith", 400, smithP), station("Alch", 420, alchP), station("Smith", 440, oddP) }
attrs.Faction, attrs.Class, attrs.ClassChosen = "Neutral", "Warrior", true
CraftWindow.Start()
CraftWindow.Start()
check(#spawned == 1, "Start runs one watch loop")


------------------------------------------------------------------ 6. the workbench prompts (개발 3 dev3-craft2: CraftPrompt with ActionKey / ObjectKey)
local w1, w2 = CraftWindow.Words("Config.Craft.Text.Prompt", "Config.Craft.Text.Stations.Smith", "en")
check(w1 == "Craft" and w2 == "Anvil", "the prompt's words from its keys", w1 .. "/" .. w2)
w1, w2 = CraftWindow.Words("Config.Craft.Text.Nope", nil, "en")
check(w1 == "" and w2 == "", "an unknown / missing key is no word (never the key itself)")
check(smithP.ActionText == "Craft" and smithP.ObjectText == "Anvil" and alchP.ObjectText == "Cauldron",
	"Start writes every bench's words", smithP.ActionText .. "/" .. smithP.ObjectText)
check(oddP.ActionText == "" and oddP.ObjectText == "", "a bench with unknown keys keeps its blank words")
check(smithP.Enabled == true and alchP.Enabled == false, "a blacksmith sees the anvil's prompt, not the cauldron's")
attrs.Faction = "Halo"
attrSig.Faction()
check(smithP.Enabled == false and alchP.Enabled == false, "not an artisan: no workbench prompt (it would only say NotArtisan)")
attrs.Faction, attrs.Class = "Neutral", "Mage"
attrSig.Class()
check(smithP.Enabled == false and alchP.Enabled == true, "an alchemist: the cauldron's prompt only")
curLang = "ko"
langFn("ko")
check(alchP.ActionText == "제작" and smithP.ObjectText == "모루", "the language changes the words", alchP.ActionText)
curLang = "en"
local late = station("Alch", 500, nil)
tagAdded(late)
local lateP = promptPart("Config.Craft.Text.Prompt", "Config.Craft.Text.Stations.Alch")
late.Kids.CraftPrompt = lateP
late.OnChild(lateP)
check(lateP.ActionText == "Craft" and lateP.ObjectText == "Cauldron" and lateP.Enabled == true,
	"a bench tagged later and its prompt added after the tag get the words")
tagRemoved(late)
check(late.OnChild == nil, "a bench that leaves stops being watched")
attrs.Class = "Warrior"

------------------------------------------------------------------ 7. the tamer (개발 3 dev3-tamer: summons + research, switch Research)
check(type(handlers.TamerInfo) == "function", "TamerInfo is bound at Init (no remote = research is not on that server)")
-- 개발 3's shapes (not on this branch's Config yet)
Config.Craft.Recipes.S1 = { Role = "Tame", Kind = "Pet", Species = "BabySlime", Family = "Slime", Research = 150, Spd = { 5, 8 },
	Lv = 1, Gold = 100, Mats = { Jelly = 30, SlimeCore = 5 }, XP = 40 }
Config.Craft.Text.NeedResearch = "Research this monster more first."
local tameCtx = ctxOf({ Class = "Archer", Items = { Jelly = 40, SlimeCore = 6 }, Gold = 500 })
check(entry(CraftWindow.Entries(tameCtx), "S1") == nil and not CraftWindow.ResearchOn(), "research off: no summon in the list")
Config.Research = { Stages = { 50, 150, 400, 1000, 2500 }, Treat = "PetTreat", TreatXP = 20,
	Text = { Names = { Slime = "Slime", Goblin = "Goblin", Skeleton = "Skeleton", Ghost = "Ghost" } } }
Config.Features.Research = true
check(CraftWindow.ResearchOn(), "research on (switch + table)")
local s1 = entry(CraftWindow.Entries(tameCtx), "S1")
check(s1 and s1.Name == "Baby Slime" and s1.Icon == "IconPetBabySlime" and s1.ResearchHave == 0 and s1.ResearchShort and not s1.Ready,
	"a summon: the pet's name and icon, its research still short", s1 and s1.Name)
check(entry(CraftWindow.Entries(ctxOf({ Items = { Jelly = 40, SlimeCore = 6 }, Gold = 500 })), "S1") == nil, "a blacksmith never sees the summon")
tameCtx.Tamer = { Pts = { Slime = 120 } }
s1 = entry(CraftWindow.Entries(tameCtx), "S1")
check(s1.ResearchHave == 120 and CraftWindow.Reason(s1, tameCtx) == "NeedResearch", "120 / 150 Slime research: NeedResearch")
local shortCtx = ctxOf({ Class = "Archer", Items = { Jelly = 1 }, Gold = 0, Tamer = { Pts = { Slime = 10 } } })
check(CraftWindow.Reason(entry(CraftWindow.Entries(shortCtx), "S1"), shortCtx) == "NeedResearch",
	"the research before the materials and the gold (the server's order)")
local lockCtx = ctxOf({ Class = "Archer", Tamer = { Pts = { Slime = 10 } } })
Config.Craft.Recipes.S1.Lv = 5
check(CraftWindow.Reason(entry(CraftWindow.Entries(lockCtx), "S1"), lockCtx) == "NeedLevel", "the craft level before the research")
Config.Craft.Recipes.S1.Lv = 1
local sv = CraftWindow.Detail(s1, tameCtx)
local function vline(v, s)
	for _, l in v.Lines do if string.find(l.Text, s, 1, true) then return l end end
	return nil
end
check(vline(sv, "Speed +5–8%") ~= nil, "the summon's speed range", sv.Lines[1] and sv.Lines[1].Text)
check(vline(sv, "Slime research 120 / 150") and vline(sv, "Slime research 120 / 150").Color == "Bad"
	and sv.Status.Text == Config.Craft.Text.NeedResearch and sv.Action.Text == "Make" and not sv.Action.Enabled,
	"the research line in red, the server's notice, Make off")
tameCtx.Tamer.Pts.Slime = 150
s1 = entry(CraftWindow.Entries(tameCtx), "S1")
sv = CraftWindow.Detail(s1, tameCtx)
check(s1.Ready and vline(sv, "Slime research 150 / 150").Color == "Good" and sv.Action.Enabled, "150 / 150: ready, Make on")
-- the research rows
local rr = CraftWindow.ResearchRows({ Pts = { Slime = 160, Goblin = 2600, Bat = 9 }, Stages = { 50, 150, 400, 1000, 2500 } })
local fams = {}
for _, r in rr do table.insert(fams, r.Family) end
check(table.concat(fams, ",") == "Slime,Goblin,Skeleton,Ghost", "every named family in order (an unnamed one is not listed)",
	table.concat(fams, ","))
check(rr[1].Stage == 2 and rr[1].Bar == "160 / 400" and math.abs(rr[1].Fraction - 0.4) < 1e-9, "Slime 160: stage 2, 160 / 400", rr[1].Bar)
check(rr[2].Stage == 5 and rr[2].Bar == "Max" and rr[2].Fraction == 1, "Goblin past the last stage: Max")
check(rr[3].Stage == 0 and rr[3].Bar == "0 / 50", "no points: stage 0, 0 / 50")
check(CraftWindow.ResearchRows(nil)[1].Bar == "0 / 50", "no TamerInfo yet: Config's stages")
check(CraftWindow.ResearchRows({ Pts = { Slime = 150 } })[1].Stage == 2, "exactly at a stage's points: that stage")
check(CraftWindow.ResearchRows({ Pts = { Slime = 149 } })[1].Stage == 1, "one point short: the stage before")
Config.Research.Text.Names.Ghost = nil
local noGhost = CraftWindow.ResearchRows(nil)
check(#noGhost == 3 and noGhost[3].Family == "Skeleton", "a family without a name is not listed (the server never names its stages)")
Config.Research.Text.Names.Ghost = "Ghost"
-- the window: the tamer's tabs
attrs.Class = "Archer"
inventory = { Items = { Jelly = 40, SlimeCore = 6 } }
handlers.TamerInfo({ Pts = { Slime = 60, Goblin = "x", [3] = 4 }, Sum = { Slime = 1 }, Stages = { 50, 150, 400, 1000, 2500 } })
check(T.S.Tamer.Pts.Slime == 60 and T.S.Tamer.Pts.Goblin == nil and T.S.Tamer.Sum.Slime == 1, "TamerInfo keeps numbers by family only")
open(nil)
check(find(root, "Tabs").Visible == true and find(root, "Tab_Make") and find(root, "Tab_Research"), "a tamer gets Make · Research tabs")
check(find(root, "Tab_Make").PaintColor == "gold" and find(root, "Row_S1") ~= nil, "Make open first: the summon row")
find(root, "Tab_Research").OnClick()
check(find(root, "Fam_Slime") ~= nil and find(root, "Row_S1") == nil and find(root, "Tab_Research").PaintColor == "gold",
	"the research tab: the families instead of the recipes")
check(find(find(root, "Fam_Slime"), "Stage").Text == "Stage 1" and find(find(root, "Fam_Slime"), "Bar").Text == "60 / 150",
	"Slime: Stage 1, 60 / 150", find(find(root, "Fam_Slime"), "Bar").Text)
handlers.TamerInfo({ Pts = { Slime = 151 }, Sum = {}, Stages = { 50, 150, 400, 1000, 2500 } })
check(find(find(root, "Fam_Slime"), "Stage").Text == "Stage 2", "a TamerInfo while open redraws the research")
find(root, "Tab_Make").OnClick()
check(find(root, "Row_S1") ~= nil and find(root, "Fam_Slime") == nil, "back to Make")
attrs.Class = "Warrior"
fireAttr("Class")
check(find(root, "Tabs").Visible == false and find(root, "Fam_Slime") == nil, "a blacksmith: no tabs (research is the tamer's)")
close()
Config.Features.Research = false

------------------------------------------------------------------ artisan contract ③: a made weapon -> [Use it]
do
	local w3 = entry(CraftWindow.Entries(ctxOf({ Level = 50 })), "W3")
	local sp = { ["3:0"] = 1, ["3:2"] = 1, ["4:0"] = 5, bad = 3, ["3:1"] = 0 }
	local function pw(t, p) return 100 + t * 10 + p end
	local c3 = ctxOf({ Level = 50, UnpackOn = true, Spares = sp, Mask = 1, PowerNow = 100, Power = pw })
	local plan = CraftWindow.SparePlan(w3, c3)
	check(plan and plan.Key == "3:2" and plan.Plus == 2 and plan.Count == 2 and plan.Owned == false and plan.Use == true,
		"③ the best +N of the recipe's tier, all of its spares counted (0 / odd keys / other tiers not)", plan and plan.Key)
	check(CraftWindow.SparePlan(w3, ctxOf({ Level = 50, UnpackOn = false, Spares = sp })) == nil,
		"③ no UnpackSpare on the server: no spare line, no button")
	check(CraftWindow.SparePlan(w3, ctxOf({ Level = 50, UnpackOn = true, Spares = { ["4:0"] = 5 } })) == nil
		and CraftWindow.SparePlan(entry(CraftWindow.Entries(ctxOf()), "W1") and { Kind = "Item" }, c3) == nil,
		"③ no spare of this tier / not a weapon: nothing")
	local v3 = CraftWindow.Detail(w3, c3)
	check(v3.Use and v3.Use.Text == TXT.Use and v3.Use.Enabled == true and v3.Use.Key == "3:2", "③ [Use it] for a made weapon I don't own")
	check(lineWith(v3, "In your bag ×2") ~= nil, "③ how many wait in the bag")
	local p = lineWith(v3, "Power 100 → 132")
	check(p ~= nil and p.Color == "Good", "③ Power now → with it (+N of the best spare), green when up", p and p.Text)
	check(lineWith(v3, "Attack " .. Util.FormatInt(math.floor(Config.WeaponDamage(3, 50, 2)))) ~= nil, "③ the attack counts the spare's +N")
	local down = CraftWindow.Detail(w3, ctxOf({ Level = 50, UnpackOn = true, Spares = sp, Mask = 1, PowerNow = 500, Power = pw }))
	check(lineWith(down, "Power 500 → 132") and lineWith(down, "Power 500 → 132").Color == "Bad", "③ red when it is weaker")
	local same = CraftWindow.Detail(w3, ctxOf({ Level = 50, PowerNow = 130, Power = pw }))
	check(lineWith(same, "Power 130 → 130") and lineWith(same, "Power 130 → 130").Color == "Sub" and same.Use == nil,
		"③ no spare: Power with a +0 one, grey when equal, no button")
	local min3 = math.floor(tonumber(Config.Weapons[3].MinLevel) or 1)
	if min3 > 1 then
		local low = CraftWindow.Detail(w3, ctxOf({ Level = 1, UnpackOn = true, Spares = sp, Mask = 1, PowerNow = 100, Power = pw }))
		check(lineWith(low, "Power") == nil and lineWith(low, "Use from") ~= nil, "③ a weapon my level can't use: no power line")
	end
	local owned = CraftWindow.Detail(w3, ctxOf({ Level = 50, UnpackOn = true, Spares = sp, Mask = 1 + 4 }))
	local ownedPlan = CraftWindow.SparePlan(w3, ctxOf({ Level = 50, UnpackOn = true, Spares = sp, Mask = 1 + 4 }))
	check(owned.Use == nil and lineWith(owned, TXT.SpareOwned) ~= nil and ownedPlan.Owned == true and ownedPlan.Use == false, "③ I own the tier already: a line, no button (the server says Owned)")
	local busy = CraftWindow.Detail(w3, ctxOf({ Level = 50, UnpackOn = true, Spares = sp, Mask = 1, Unpacking = true }))
	check(busy.Use and busy.Use.Text == TXT.Checking and busy.Use.Enabled == false, "③ one at a time: Checking…, off")

	-- the window
	table.insert(mods.Net.Names, "UnpackSpare")
	attrs.Level, attrs.WeaponOwnedMask = 50, 1
	inventory = { Items = { Jelly = 12, Petal = 1, CopperOre = 4 }, Spares = { ["2:1"] = 1 } }
	fired = {}
	open(nil)
	find(root, "Row_W2").OnActivate()
	local use = find(root, "Use")
	check(use and use.Text == TXT.Use and use.Enabled == true and use.Color == "free" and find(root, "Forge") ~= nil,
		"③ the window: [Use it] under the start button", use and use.Text)
	use.OnClick()
	check(#fired == 1 and fired[1][1] == "UnpackSpare" and fired[1][2] == "2:1", "③ [Use it] sends UnpackSpare(\"T:P\")",
		fired[1] and fired[1][1])
	check(find(root, "Use").Text == TXT.Checking and find(root, "Use").Enabled == false, "③ waiting: Checking…, off")
	find(root, "Use").OnClick()
	check(#fired == 1, "③ a second press while it waits sends nothing")
	CLOCK += 0.5
	CraftWindow.WatchUnpack()
	check(#fired == 1 and T.S.Unpack ~= nil, "③ no weapon bit yet: still waiting")
	attrs.WeaponOwnedMask = 3
	inventory = { Items = { Jelly = 12, Petal = 1, CopperOre = 4 }, Spares = {} }
	CraftWindow.WatchUnpack()
	check(#fired == 2 and fired[2][1] == "EquipWeapon" and fired[2][2] == 2 and T.S.Unpack == nil,
		"③ the bit came: the weapon is worn (EquipWeapon)", fired[2] and fired[2][1])
	check(find(root, "Use") == nil, "③ the spare is gone: no button")
	-- no answer: the button comes back, nothing worn
	attrs.WeaponOwnedMask = 1
	inventory = { Items = { Jelly = 12, Petal = 1, CopperOre = 4 }, Spares = { ["2:0"] = 2 } }
	CraftWindow.Redraw()
	fired = {}
	find(root, "Use").OnClick()
	CLOCK += 3.1
	CraftWindow.WatchUnpack()
	check(#fired == 1 and T.S.Unpack == nil and find(root, "Use").Enabled == true, "③ no answer in 3 s: the button again, nothing worn")
	-- a level too low to use it: made mine, not worn
	attrs.Level = 1
	fired = {}
	CraftWindow.Redraw()
	if min3 > 1 then
		find(root, "Row_W3").OnActivate()
		inventory.Spares = { ["3:0"] = 1 }
		CraftWindow.Redraw()
		find(root, "Use").OnClick()
		attrs.WeaponOwnedMask = 1 + 4
		CraftWindow.WatchUnpack()
		check(#fired == 1 and fired[1][1] == "UnpackSpare", "③ my level can't use it yet: made mine, not worn")
	end
	close()
	attrs.Level, attrs.WeaponOwnedMask = 1, nil
	table.remove(mods.Net.Names)
end

print(string.format("CRAFT_WINDOW_SUMMARY checks=%d failed=%d", checks, failed))
