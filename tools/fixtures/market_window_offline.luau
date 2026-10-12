-- C-6 거래소 창 (게임성 개발 4, 2026-10-12): runs the real Config.luau and the real MarketWindow.luau
-- (tools/test_market_window.py) on small doubles: Players.LocalPlayer attributes, a recording Instance tree (TextBox
-- events included), a Panels registry that builds the window with a recording kit, UIKit art doubles, a Remotes folder
-- whose remotes appear when the test says so (the market server C-5 is not in the game yet; the test fires the s->c
-- remotes MarketIndex / MarketPage / MarketMine itself). Inputs: CONFIG_SOURCE, WINDOW_SOURCE. Every check is named.
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
local savedMarket = Config.Market -- (the market's own Config table is the server branch's: absent today)
Config.Market = nil
check(Config.Features.Market == false, "Config.Features.Market is off in the game today", Config.Features.Market)
-- a test-only item of another kind (never sellable): a quest thing
Config.Loot.Items.ZQuest = { Kind = "Quest", Name = "Quest Note", Sell = 0, Color = Color3.fromRGB(200, 200, 200), Icon = "IconQuestNote" }

------------------------------------------------------------------ an Instance tree double (TextBox events included)
local ISA = {
	TextButton = { GuiButton = true, GuiObject = true }, ImageButton = { GuiButton = true, GuiObject = true },
	TextLabel = { GuiObject = true }, ImageLabel = { GuiObject = true }, Frame = { GuiObject = true },
	ScrollingFrame = { GuiObject = true }, TextBox = { GuiObject = true },
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
		GetPropertyChangedSignal = function(self, prop)
			local q = rawget(self, "__p")
			return { Connect = function(_, f)
				q.Changed = q.Changed or {}
				q.Changed[prop] = f
			end }
		end,
	}
	if methods[k] then return methods[k] end
	if k == "Activated" then return { Connect = function(_, f) p.OnActivate = f end } end
	if k == "Focused" then return { Connect = function(_, f) p.OnFocused = f end } end
	if k == "FocusLost" then return { Connect = function(_, f) p.OnFocusLost = f end } end
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
	local old = p[k]
	p[k] = v
	if old ~= v and p.Changed and p.Changed[k] then p.Changed[k]() end
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
	if root == nil then return nil end
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
local function names(list)
	local out = {}
	for _, d in list do table.insert(out, d.Name) end
	return table.concat(out, ",")
end

------------------------------------------------------------------ doubles
local CLOCK = 100
local attrs = { Class = "Warrior", Faction = "Halo", Level = 12, BankGold = 1200, CarriedGold = 34, WeaponOwnedMask = 1, WeaponTier = 1,
	HPPotionCount = 5 }
local player = { GetAttribute = function(_, k) return attrs[k] end }
local Util = {
	Warn = function(...) print("WARN", ...) end,
	FormatInt = function(n)
		local s = tostring(math.floor(n))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end,
}
local L10nReg = {}
local L10n = { Register = function(path, t) L10nReg[path] = t return t end }
local handlers = {} -- [remote name] = the module's OnClientEvent handler
local remoteObjs = {}
local function addRemote(name)
	remoteObjs[name] = { IsA = function(_, c) return c == "RemoteEvent" end,
		OnClientEvent = { Connect = function(_, f) handlers[name] = f end } }
end
local remotes = { FindFirstChild = function(_, n) return remoteObjs[n] end, WaitForChild = function(_, n) return remoteObjs[n] end }
local shared = { WaitForChild = function(_, n) return n end }
local RS = { WaitForChild = function(_, n) return n == "Shared" and shared or remotes end,
	FindFirstChild = function(_, n) return n == "Remotes" and remotes or nil end }
local game = { GetService = function(_, n)
	if n == "Players" then return { LocalPlayer = player } end
	if n == "ReplicatedStorage" then return RS end
	return nil
end }
local mods = { Config = Config, Util = Util, L10n = L10n }

local env = setmetatable(table.clone(base), { __index = getfenv() })
env.game, env.Instance = game, Instance
env.typeof = function(v)
	if type(v) == "table" and type(v.IsA) == "function" then return "Instance" end
	return typeof(v)
end
env.require = function(n) return mods[n] end
env.os = setmetatable({ clock = function() return CLOCK end }, { __index = os })
local spawned = {}
env.task = { spawn = function(f) table.insert(spawned, f) end, defer = function(f, ...) f(...) end, delay = function() end,
	wait = function() end }
local wf = assert(loadstring(WINDOW_SOURCE, "=MarketWindow"))
setfenv(wf, env)
local MarketWindow = wf()

local reg = {}
local root, update = nil, nil -- the open window's body and its 0.25 s update
local openArg = nil
local fired = {}
local attrFns = {}
local opened = {} -- Panels.Open calls
local inventory = { Items = {}, Spares = {} }
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
	ArtImage = function(name, props) return artObj("ImageLabel", name, props) end,
	ArtFrame = function(name, props) return artObj("Frame", name, props) end,
	ItemIcon = function(id, props)
		if id == "Petal" then return nil end -- an item whose icon is not drawn yet
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
MarketWindow.Init({ Panels = panels, UIKit = UIKit })
local T = MarketWindow._T
local TXT = T.TXT
local S = T.S

local function open(arg)
	if root then
		reg.Market.Cleanup()
		table.clear(attrFns)
	end
	root = newObj("Frame", { Name = "Root" })
	openArg = arg
	update = reg.Market.Build(root, kit, arg)
end
local function close()
	if root then reg.Market.Cleanup() end
	table.clear(attrFns)
	root, update = nil, nil
end
local function fireAttr(name)
	for _, f in table.clone(attrFns) do f(name) end
end
local function firedNames()
	local out = {}
	for _, f in fired do table.insert(out, f[1]) end
	return table.concat(out, ",")
end
local function last()
	return fired[#fired]
end
local function lastIs(name, ...)
	local f = fired[#fired]
	if not f or f[1] ~= name then return false end
	local want = { ... }
	for i = 1, #want do
		if f[i + 1] ~= want[i] then return false end
	end
	return #f == #want + 1
end
local function tick(dt)
	CLOCK += dt or 0
	if update then update() end
end
local function tabs() return find(root, "Tabs") end

------------------------------------------------------------------ 0. registered; the switch is off
local o = reg.Market
check(o ~= nil and MarketWindow.IsReady(), "the window \"Market\" is registered")
check(o.FixedBody == true and o.Rebuild == false, "a fixed body that redraws itself (Rebuild = false)")
check(o.Title() == "Market", "the title is Market", o.Title())
check(L10nReg["MarketWindow.TXT"] == TXT, "the words are a registered L10n table (MarketWindow.TXT, A23-111)")
check(type(o.Width) == "function" and o.Width() == 560, "about 560 du wide like the bag", o.Width())
check(#spawned == 3 and handlers.MarketIndex == nil and handlers.MarketPage == nil and handlers.MarketMine == nil,
	"no market remotes yet: the three s->c remotes wait for their name in a spawn")
check(o.Menu() == nil, "switch off: no menu entry")
MarketWindow.Open("Buy")
check(#opened == 0, "switch off: Open does nothing")
open(nil)
check(update == nil and #root:GetChildren() == 0, "switch off: a built window draws nothing")
close()

Config.Features.Market = true
check(o.Menu() == "Market", "switch on: the menu entry says Market", o.Menu())
MarketWindow.Open("Sell")
MarketWindow.Open()
check(#opened == 2 and opened[1][1] == "Market" and opened[1][2].Tab == "Sell" and opened[2][2] == nil,
	"Open(tab) -> Panels.Open(\"Market\", { Tab }); no tab = no arg")
check(MarketWindow.NoteText("NeedLevelBuy") == "Not now." and MarketWindow.NoteText("Resting") == TXT.Resting,
	"no Config.Market: a notice key has its own TXT fallback (Refused / Resting)")

------------------------------------------------------------------ 1. no remotes: Resting, nothing sent
open(nil)
check(find(root, "Status") and find(root, "Status").Text == TXT.Resting, "no remotes: the window says Resting in the middle",
	find(root, "Status") and find(root, "Status").Text)
check(find(root, "Tab_Buy") and find(root, "Tab_Sell") and find(root, "Tab_Mine")
	and find(root, "Tab_Buy").Text == "Buy" and find(root, "Tab_Sell").Text == "Sell" and find(root, "Tab_Mine").Text == "Mine",
	"the three tabs Buy · Sell · Mine")
check(find(find(root, "Bottom"), "Gold").Text == "1,234", "my gold (bank + carried) at the bottom", find(find(root, "Bottom"), "Gold").Text)
check(find(root, "Kind_Material") == nil and #findAll(root, "^Row_") == 0, "no lists while the market rests")
for _ = 1, 4 do tick(1) end
check(#fired == 0, "no remotes: nothing is ever sent")
find(root, "Tab_Sell").OnClick()
check(#fired == 0 and find(root, "Status") ~= nil, "a tab click while resting sends nothing")
find(root, "Tab_Buy").OnClick()
addRemote("MarketIndex") -- only some of the remotes are there: still resting (it needs them all)
addRemote("MarketMine")
tick(1)
check(#fired == 0 and find(root, "Status") ~= nil, "a missing remote (MarketBrowse ...): still resting, still nothing sent")
Config.Market = { Text = { Resting = "Market is closed.", NeedLevelBuy = "Lv 5", NeedLevelList = "Lv 10", DayLimit = "20 a day" } }
check(MarketWindow.NoteText("Resting") == "Market is closed." and MarketWindow.NoteText("Zzz") == "Not now.",
	"Config.Market.Text[key] when it exists, else the fallback")
Config.Market.Text.Resting = nil

------------------------------------------------------------------ 2. the market wakes up: the s->c remotes bind, the first requests
for _, n in { "MarketBrowse", "MarketBuy", "MarketList", "MarketCancel", "MarketPage" } do addRemote(n) end
local run = spawned
spawned = {}
for _, f in run do f() end
check(type(handlers.MarketIndex) == "function" and type(handlers.MarketPage) == "function" and type(handlers.MarketMine) == "function",
	"the s->c remotes bind when they appear")
CLOCK += 1
update()
check(firedNames() == "MarketMine,MarketIndex", "the remotes are there: the window leaves Resting and asks Mine + Index", firedNames())
check(find(root, "Status") == nil or find(root, "Status").Text ~= TXT.Resting, "no Resting line any more")
check(S.ReadyAt.MarketMine and S.ReadyAt.MarketIndex and math.abs(S.ReadyAt.MarketMine - (CLOCK + 1.15)) < 1e-9,
	"Mine / Index: 1 s (no Config.RateLimits entry) + 0.15 s margin", S.ReadyAt.MarketMine)
update()
check(#fired == 2, "nothing more inside the interval")

------------------------------------------------------------------ 3. Buy: kinds, the index, search
check(find(root, "Kind_Material").Text == "Materials" and find(root, "Kind_Scroll").Text == "Scrolls"
	and find(root, "Kind_Tonic").Text == "Tonics" and find(root, "Kind_Weapon").Text == "Weapons",
	"the kinds: Materials · Scrolls · Tonics · Weapons (the bag's words)")
check(find(root, "Kind_Material").PaintColor == "gold" and find(root, "Kind_Scroll").PaintColor == "button" and find(root, "Tab_Buy").PaintColor == "gold",
	"the open kind and the open tab are gold")
check(find(find(root, "Index"), "Status").Text == TXT.Empty, "no index yet: one short line")
local INDEX = { Rows = { { Key = "I:Jelly", Low = 3, Count = 40 }, { Key = "I:Petal", Low = 6, Count = 9 }, { Key = "I:SlimeCore", Low = 10, Count = 5 },
	{ Key = "I:Enh70", Low = 300, Count = 2 }, { Key = "I:Move70", Low = 200, Count = 1 }, { Key = "I:MightTonic", Low = 20, Count = 4 },
	{ Key = "I:PetTreat", Low = 12, Count = 3 }, { Key = "W:3:2", Low = 500, Count = 1 }, { Key = "W:2:0", Low = 120, Count = 2 },
	{ Key = "I:Nope", Low = 1, Count = 1 }, { Key = "W:99:0", Low = 1, Count = 1 }, { Key = "I:ZQuest", Low = 1, Count = 1 },
	{ Key = "I:Bone", Low = "x", Count = 2 }, { Key = "I:Bone", Low = 5, Count = 0 } }, At = 1, Gate = { Buy = "", List = "", ListIn = 0 } }
handlers.MarketIndex(INDEX)
local idx = find(root, "Index")
check(names(findAll(idx, "^Row_")) == "Row_I:Jelly,Row_I:Petal,Row_I:SlimeCore",
	"the Materials rows in the bag's order; unknown keys, quest things, bad rows are not shown", names(findAll(idx, "^Row_")))
local jelly = find(idx, "Row_I:Jelly")
check(find(jelly, "Name").Text == "Jelly" and find(jelly, "Right1").Text == "3" and find(jelly, "Right2").Text == "×40",
	"a row: the name, the Low price, the Count", find(jelly, "Right1").Text .. " " .. find(jelly, "Right2").Text)
check(find(jelly, "Icon:Jelly") ~= nil and find(jelly, "Slot").Image == "SlotCommon", "the icon in the bag's grade slot")
check(find(find(idx, "Row_I:Petal"), "Letter") ~= nil and find(find(idx, "Row_I:Petal"), "Letter").Text == "F",
	"no icon art yet: the name's first letter in the slot")
check(find(jelly, "Picked") ~= nil and S.BuyKey == "I:Jelly", "the first row is picked (gold rim)")
check(find(find(root, "Right"), "Status").Text == TXT.Checking, "its page is not here yet: Checking…")
update()
check(lastIs("MarketBrowse", "I:Jelly", 1), "the picked key's page is asked (MarketBrowse(key, 1))", firedNames())
-- scrolls / tonics: Enhance + Transfer are Scrolls, Tonic + Treat are Tonics
find(root, "Kind_Scroll").OnClick()
check(names(findAll(find(root, "Index"), "^Row_")) == "Row_I:Enh70,Row_I:Move70" and find(root, "Kind_Scroll").PaintColor == "gold",
	"Scrolls: Enhance and Transfer scrolls", names(findAll(find(root, "Index"), "^Row_")))
find(root, "Kind_Tonic").OnClick()
check(names(findAll(find(root, "Index"), "^Row_")) == "Row_I:MightTonic,Row_I:PetTreat", "Tonics: tonics and Pet Treat",
	names(findAll(find(root, "Index"), "^Row_")))
find(root, "Kind_Material").OnClick()
check(S.BuyKey == "I:Jelly", "back on Materials: the first row again")
-- search: my own filter on the English name, no request
local nFired = #fired
local search = find(find(root, "Search"), "Input")
search.Text = "SLIME"
check(names(findAll(find(root, "Index"), "^Row_")) == "Row_I:SlimeCore" and S.Query == "SLIME", "the search box filters by the name (any case)",
	names(findAll(find(root, "Index"), "^Row_")))
check(#fired == nFired, "a search sends no request")
search.Text = "flower"
check(names(findAll(find(root, "Index"), "^Row_")) == "Row_I:Petal", "the search reads the item's English name, not its key (Flower Petal)",
	names(findAll(find(root, "Index"), "^Row_")))
search.Text = "zzz"
check(find(find(root, "Index"), "Status").Text == TXT.Empty and #findAll(find(root, "Index"), "^Row_") == 0, "nothing matches: one short line")
search.Text = ""
check(#findAll(find(root, "Index"), "^Row_") == 3, "an empty search shows all again")
search.Text = "jel"
find(root, "Kind_Tonic").OnClick()
check(find(find(root, "Search"), "Input").Text == "jel" and #findAll(find(root, "Index"), "^Row_") == 0, "the search stays over a kind change")
find(root, "Kind_Material").OnClick()
find(find(root, "Search"), "Input").Text = ""

------------------------------------------------------------------ 4. Buy: the page rows, Buy once, pages, the gate, weapons
local function jellyPage(page, pages, rows)
	return { Key = "I:Jelly", Page = page, Pages = pages, Ref = 3, Min = 1, Max = 50, Rows = rows or { { Id = "a1", Price = 3, N = 10, Plus = 0, Left = 125 },
		{ Id = "a2", Price = 4, N = 1, Plus = 0, Left = 3599 }, { Id = 7, Price = 5, N = 2, Plus = 0, Left = 30 }, { Id = "bad", Price = "x" } } }
end
handlers.MarketPage(jellyPage(1, 3))
local right = find(root, "Right")
check(find(find(right, "Head"), "Title").Text == "Jelly", "the picked key's name over its rows")
check(names(findAll(right, "^Offer_")) == "Offer_a1,Offer_a2,Offer_7", "the page's rows (a bad row is not shown)", names(findAll(right, "^Offer_")))
local a1 = find(right, "Offer_a1")
check(find(a1, "Count").Text == "×10" and find(a1, "Price").Text == "3" and find(a1, "Left").Text == "2:05",
	"a row: count, price, time left m:ss", find(a1, "Count").Text .. " " .. find(a1, "Price").Text .. " " .. find(a1, "Left").Text)
check(find(find(right, "Offer_a2"), "Left").Text == "59:59" and MarketWindow.TimeText(3600) == "1:00" and MarketWindow.TimeText(3725) == "1:02"
	and MarketWindow.TimeText(0) == "0:00" and MarketWindow.TimeText(-5) == "0:00", "time left: m:ss under an hour, h:mm from an hour")
check(find(a1, "Buy").Text == "Buy" and find(a1, "Buy").Enabled == true and find(a1, "Buy").Color == "buy", "[Buy] on")
check(find(find(right, "Pager"), "Page").Text == "1 / 3" and find(find(right, "Pager"), "Prev").Enabled == false
	and find(find(right, "Pager"), "Next").Enabled == true, "the pages: 1 / 3, ◀ off, ▶ on")
tick(5)
check(find(find(right, "Offer_a1"), "Left").Text == "2:00" and find(find(find(root, "Right"), "Offer_a1"), "Left").Text == "2:00",
	"the clock runs (5 s later 2:00)")
-- Buy once
fired = {}
find(find(root, "Right"), "Offer_a1"):FindFirstChild("Buy").OnClick()
check(#fired == 1 and lastIs("MarketBuy", "a1", 3), "[Buy] sends MarketBuy(id, the price I saw) once", firedNames())
right = find(root, "Right")
check(find(find(right, "Offer_a1"), "Buy").Text == TXT.Checking and find(find(right, "Offer_a1"), "Buy").Enabled == false
	and find(find(right, "Offer_a2"), "Buy").Text == "Buy" and find(find(right, "Offer_a2"), "Buy").Enabled == false,
	"while waiting: Checking… on that row, every [Buy] off")
find(find(right, "Offer_a1"), "Buy").OnClick()
find(find(right, "Offer_a2"), "Buy").OnClick()
check(#fired == 1, "a second click (a stale button) sends nothing")
check(S.ReadyAt.MarketBuy and math.abs(S.ReadyAt.MarketBuy - (CLOCK + 6.15)) < 1e-9, "Buy: 6 s + 0.15 s margin", S.ReadyAt.MarketBuy)
tick(3.1)
check(firedNames():find("MarketMine", 1, true) ~= nil and select(2, firedNames():gsub("MarketBrowse", "")) >= 1 and last()[1] ~= "MarketBuy",
	"3 s after the Buy: the Mine rows and the open page are asked again", firedNames())
check(find(find(find(root, "Right"), "Offer_a1"), "Buy").Text == "Buy" and find(find(find(root, "Right"), "Offer_a1"), "Buy").Enabled == false,
	"the answer is in; the button waits out the Buy interval")
tick(3.1)
check(find(find(find(root, "Right"), "Offer_a1"), "Buy").Enabled == true, "after the interval [Buy] is on again")
-- the gate keys (§6-4): the client never computes a gate
handlers.MarketIndex({ Rows = INDEX.Rows, At = 2, Gate = { Buy = "NeedLevelBuy", List = "", ListIn = 0 } })
local b1 = find(find(find(root, "Right"), "Offer_a1"), "Buy")
check(b1.Text == "Lv 5" and b1.Enabled == false, "Gate.Buy = a key: [Buy] off with the key's Config.Market.Text", b1.Text)
fired = {}
b1.OnClick()
check(#fired == 0, "a click on a gated [Buy] sends nothing")
handlers.MarketIndex({ Rows = INDEX.Rows, At = 2, Gate = { Buy = "Zzz", List = "", ListIn = 0 } })
check(find(find(find(root, "Right"), "Offer_a1"), "Buy").Text == "Not now.", "a gate key without a text: the key's own fallback (Refused)")
handlers.MarketIndex({ Rows = INDEX.Rows, At = 2, Gate = { Buy = "", List = "", ListIn = 0 } })
check(find(find(find(root, "Right"), "Offer_a1"), "Buy").Enabled == true, "Gate.Buy \"\" = on")
-- pages
fired = {}
find(find(root, "Right"), "Pager"):FindFirstChild("Next").OnClick()
check(S.BuyPage == 2 and find(find(root, "Right"), "Status").Text == TXT.Checking, "▶: page 2, Checking… until it comes")
tick(0)
check(lastIs("MarketBrowse", "I:Jelly", 2), "▶ asks MarketBrowse(key, 2)", firedNames())
handlers.MarketPage(jellyPage(2, 3, { { Id = "b1", Price = 6, N = 3, Plus = 0, Left = 90 } }))
right = find(root, "Right")
check(names(findAll(right, "^Offer_")) == "Offer_b1" and find(find(right, "Pager"), "Page").Text == "2 / 3" and find(find(right, "Pager"), "Prev").Enabled == true,
	"page 2: its rows, 2 / 3, ◀ on")
fired = {}
MarketWindow.Page(1)
tick(0)
check(#fired == 0 and S.BuyPage == 3, "page 3 asked inside the Browse interval: wait")
tick(1.2)
check(lastIs("MarketBrowse", "I:Jelly", 3), "...and sent when the interval allows (the latest page)", firedNames())
handlers.MarketPage(jellyPage(3, 3, { { Id = "c1", Price = 9, N = 1, Plus = 0, Left = 90 } }))
check(find(find(find(root, "Right"), "Pager"), "Next").Enabled == false, "the last page: ▶ off")
MarketWindow.Page(1)
check(S.BuyPage == 3, "no page past the last")
MarketWindow.Page(-1)
MarketWindow.Page(-1)
check(S.BuyPage == 1, "◀ back to page 1")
tick(1.2)

-- weapons: "W:T:P" with my class's name / icon; off when I own that tier
find(root, "Kind_Weapon").OnClick()
local widx = find(root, "Index")
check(names(findAll(widx, "^Row_")) == "Row_W:2:0,Row_W:3:2", "Weapons: by tier", names(findAll(widx, "^Row_")))
local w32 = find(widx, "Row_W:3:2")
local wname = Config.WeaponName(3, "Warrior", "Halo")
check(find(w32, "Name").Text == wname .. " +2" and find(find(widx, "Row_W:2:0"), "Name").Text == Config.WeaponName(2, "Warrior", "Halo"),
	"a weapon key shows my class's weapon name (+N when it has one)", find(w32, "Name").Text)
check(find(w32, "Icon:" .. Config.WeaponArtKey(3, "Warrior", "Halo")) ~= nil, "...and my class's weapon icon")
check(S.BuyKey == "W:2:0", "the first weapon row is picked")
w32.OnActivate()
check(S.BuyKey == "W:3:2" and find(find(root, "Index"), "Row_W:3:2"):FindFirstChild("Picked") ~= nil, "a tap picks a row")
tick(1.2)
check(lastIs("MarketBrowse", "W:3:2", 1), "picking asks its page", firedNames())
handlers.MarketPage({ Key = "W:3:2", Page = 1, Pages = 1, Ref = 480, Min = 300, Max = 900, Rows = { { Id = "w1", Price = 500, N = 1, Plus = 2, Left = 60 } } })
local w1 = find(find(root, "Right"), "Offer_w1")
check(find(w1, "Count").Text == "×1 +2" and find(w1, "Buy").Enabled == true, "a weapon row: count and +N; [Buy] on (I do not own tier 3)", find(w1, "Count").Text)
attrs.WeaponOwnedMask = 1 + 4
fireAttr("WeaponOwnedMask")
w1 = find(find(root, "Right"), "Offer_w1")
check(find(w1, "Buy").Enabled == false and find(w1, "Buy").Text == TXT.Owned, "I own tier 3: [Buy] off (Owned)")
attrs.WeaponOwnedMask, attrs.WeaponTier = 1, 3
fireAttr("WeaponTier")
check(find(find(find(root, "Right"), "Offer_w1"), "Buy").Enabled == false, "the worn weapon's tier counts as owned")
attrs.WeaponTier = 1
fireAttr("WeaponTier")
check(find(find(find(root, "Right"), "Offer_w1"), "Buy").Enabled == true, "not owned any more: on")
attrs.Class = "Mage"
fireAttr("Class")
check(find(find(root, "Index"), "Row_W:3:2"):FindFirstChild("Name").Text == Config.WeaponName(3, "Mage", "Halo") .. " +2"
	and find(find(root, "Index"), "Row_W:3:2"):FindFirstChild("Icon:" .. Config.WeaponArtKey(3, "Mage", "Halo")) ~= nil,
	"my class changes: the names and icons follow")
attrs.Class = "Warrior"
fireAttr("Class")
find(root, "Kind_Material").OnClick()

------------------------------------------------------------------ 5. Sell
inventory = { Items = { Jelly = 12, Petal = 1, Enh70 = 2, MightTonic = 3, PetTreat = 1, Nope = 5, ZQuest = 2 },
	Spares = { ["3:2"] = 2, ["2:0"] = 1, x = 4, ["99:0"] = 1 } }
find(root, "Tab_Sell").OnClick()
local sl = find(root, "List")
check(names(findAll(sl, "^Row_")) == "Row_I:Enh70,Row_I:Jelly,Row_I:Petal,Row_I:MightTonic,Row_I:PetTreat,Row_W:2:0,Row_W:3:2",
	"Sell: materials, scrolls, tonics, Pet Treat and the spares; no quest thing, no unknown id, no bad spare, no HP potion",
	names(findAll(sl, "^Row_")))
check(find(find(sl, "Row_I:Jelly"), "Right1").Text == "×12" and find(find(sl, "Row_W:3:2"), "Right1").Text == "×2"
	and find(find(sl, "Row_W:3:2"), "Name").Text == Config.WeaponName(3, "Warrior", "Halo") .. " +2", "each row: the name and how many I have")
check(S.SellKey == "I:Enh70" and find(sl, "Row_I:Enh70"):FindFirstChild("Picked") ~= nil, "the first thing is picked")
local det = find(root, "Detail")
check(find(det, "List").Text == TXT.Checking and find(det, "List").Enabled == false,
	"no price range yet: [List] says Checking…, off")
fired = {}
tick(1.2)
check(lastIs("MarketBrowse", "I:Enh70", 1), "picking asks MarketBrowse(key, 1) for Ref / Min / Max", firedNames())
local ENH = { Key = "I:Enh70", Page = 1, Pages = 1, Ref = 250, Min = 100, Max = 900, Rows = { { Id = "e1", Price = 300, N = 1, Plus = 0, Left = 100 },
	{ Id = "e2", Price = 310, N = 2, Plus = 0, Left = 100 }, { Id = "e3", Price = 320, N = 1, Plus = 0, Left = 100 },
	{ Id = "e4", Price = 999, N = 1, Plus = 0, Left = 100 } } }
handlers.MarketPage(ENH)
det = find(root, "Detail")
check(find(det, "Hint1").Text == "×1  300" and find(det, "Hint2").Text == "×2  310" and find(det, "Hint3").Text == "×1  320" and find(det, "Hint4") == nil
	and find(det, "OnSale") ~= nil, "the 3 cheapest rows as a hint", find(det, "Hint1") and find(det, "Hint1").Text)
check(find(det, "Input").Text == "250" and find(det, "YouGet").Text == "You get 225", "the price starts at Ref; You get = price - 10%",
	find(det, "Input").Text .. " / " .. find(det, "YouGet").Text)
check(find(det, "Range").Text == "100 – 900", "the range Min – Max", find(det, "Range").Text)
check(select(2, MarketWindow.Fee(250)) == 225 and MarketWindow.Fee(250) == 25 and MarketWindow.Fee(9) == 0 and select(2, MarketWindow.Fee(15)) == 14
	and select(2, MarketWindow.Fee(1)) == 1, "the fee is floor(price x 10%)")
check(find(det, "List").Text == "List" and find(det, "List").Enabled == true, "[List] on")
-- how many
check(find(det, "Count").Text == "1 / 2" and find(det, "Less").Enabled == false and find(det, "More").Enabled == true, "count 1 / 2: - off, + on")
find(det, "More").OnClick()
det = find(root, "Detail")
check(find(det, "Count").Text == "2 / 2" and find(det, "More").Enabled == false and find(det, "All").Enabled == false, "+: 2 / 2, + and All off")
find(det, "Less").OnClick()
check(find(find(root, "Detail"), "Count").Text == "1 / 2", "-: 1 / 2")
find(find(root, "Detail"), "All").OnClick()
check(S.SellN == 2 and find(find(root, "Detail"), "Count").Text == "2 / 2", "All: every one I have")
MarketWindow.SellCount(1)
check(S.SellN == 2, "no more than I have")
-- the price: numbers only, clamped to Min..Max
det = find(root, "Detail")
local tb = find(det, "Input")
tb.OnFocused()
tb.Text = "12ab3"
check(tb.Text == "123" and S.SellPrice == 123 and find(det, "YouGet").Text == "You get 111", "the price box takes numbers only (12ab3 -> 123), You get 111",
	tb.Text .. " / " .. find(det, "YouGet").Text)
tb.Text = "5"
check(find(det, "YouGet").Text == "You get 90", "below Min: the line counts Min (100 -> 90)", find(det, "YouGet").Text)
tb.OnFocusLost()
check(tb.Text == "100" and S.SellPrice == 100, "leaving the box clamps it to Min", tb.Text)
tb.OnFocused()
tb.Text = "99999"
tb.OnFocusLost()
check(tb.Text == "900", "above Max: Max", tb.Text)
tb.OnFocused()
tb.Text = ""
tb.OnFocusLost()
check(tb.Text == "250", "an empty box goes back to Ref", tb.Text)
-- the box keeps the keyboard while an inventory push redraws the rest
tb.OnFocused()
inventory.Items.Jelly = 13
tick(0)
check(find(find(root, "Detail"), "Input") == tb and find(find(find(root, "List"), "Row_I:Jelly"), "Right1").Text == "×13",
	"an inventory push while I type: the list updates, the price box stays")
tb.OnFocusLost()
check(find(find(root, "Detail"), "Input") ~= tb and find(find(root, "Detail"), "Input").Text == "250", "...and the detail is drawn again when it lets go")
inventory.Items.Jelly = 12
tick(0)
-- List: kind "I" with the item id
fired = {}
find(find(root, "Detail"), "List").OnClick()
check(#fired == 1 and lastIs("MarketList", "I", "Enh70", 2, 250), "[List] sends MarketList(\"I\", itemId, n, price)", firedNames() .. (last() and (" " .. tostring(last()[4]) .. " " .. tostring(last()[5])) or ""))
check(find(find(root, "Detail"), "List").Text == TXT.Checking and find(find(root, "Detail"), "List").Enabled == false, "while waiting: Checking…")
find(find(root, "Detail"), "List").OnClick()
check(#fired == 1, "[List] once")
check(S.ReadyAt.MarketList and math.abs(S.ReadyAt.MarketList - (CLOCK + 6.15)) < 1e-9, "List: 6 s + 0.15 s margin")
tick(3.1)
check(select(2, firedNames():gsub("MarketMine", "")) >= 1 and select(2, firedNames():gsub("MarketBrowse", "")) >= 1,
	"3 s after the List: Mine and the open page are asked again", firedNames())
-- a spare weapon: kind "W" with the key "T:P"
tick(7)
find(find(root, "List"), "Row_W:3:2").OnActivate()
check(S.SellKey == "W:3:2" and S.SellN == 1 and S.SellPrice == nil, "a spare is picked (count 1, price back to Ref)")
fired = {}
tick(0)
check(lastIs("MarketBrowse", "W:3:2", 1), "...its page is asked", firedNames())
handlers.MarketPage({ Key = "W:3:2", Page = 1, Pages = 1, Ref = 480, Min = 300, Max = 900, Rows = {} })
det = find(root, "Detail")
check(find(det, "Name").Text == Config.WeaponName(3, "Warrior", "Halo") .. " +2" and find(det, "Input").Text == "480" and find(det, "OnSale") == nil,
	"the spare's detail: its name, Ref 480, no hint rows")
fired = {}
find(det, "List").OnClick()
check(lastIs("MarketList", "W", "3:2", 1, 480) and #fired == 1, "[List] for a spare: MarketList(\"W\", \"3:2\", n, price)", firedNames())
tick(7)
-- the gate (§6-4): Gate.List's key text, then Wait
handlers.MarketMine({ Rows = {}, Waiting = 0, Gate = { Buy = "", List = "DayLimit", ListIn = 0 } })
local lb = find(find(root, "Detail"), "List")
check(lb.Text == "20 a day" and lb.Enabled == false, "Gate.List = a key: [List] off with its text", lb.Text)
fired = {}
lb.OnClick()
check(#fired == 0, "a click on a gated [List] sends nothing")
handlers.MarketMine({ Rows = {}, Waiting = 0, Gate = { Buy = "", List = "", ListIn = 65 } })
lb = find(find(root, "Detail"), "List")
check(lb.Text == "Wait 1:05" and lb.Enabled == false, "Gate.ListIn > 0: Wait m:ss, off", lb.Text)
tick(10)
check(find(find(root, "Detail"), "List").Text == "Wait 0:55", "the wait counts down", find(find(root, "Detail"), "List").Text)
tick(56)
lb = find(find(root, "Detail"), "List")
check(lb.Text == "List" and lb.Enabled == true, "the wait is over: [List] on again", lb.Text)
-- nothing to sell
local savedInv = inventory
inventory = { Items = {}, Spares = {} }
tick(0)
check(find(find(root, "List"), "Status").Text == TXT.NoneToSell and find(find(root, "Detail"), "Status").Text == TXT.NoneToSell
	and S.SellKey == nil, "nothing to sell: one short line")
inventory = savedInv

------------------------------------------------------------------ 6. Mine
local MINE = { Rows = {
	{ Id = "m1", Key = "I:Jelly", N = 5, Plus = 0, Price = 40, State = "Open", Left = 300, Paid = false },
	{ Id = "m2", Key = "W:3:2", N = 1, Plus = 2, Price = 480, State = "Sold", Left = 0, Paid = false },
	{ Id = "m3", Key = "I:Enh70", N = 1, Plus = 0, Price = 300, State = "Sold", Left = 0, Paid = true },
	{ Id = "m4", Key = "I:Petal", N = 2, Plus = 0, Price = 8, State = "Expired", Left = 0, Paid = false },
	{ Id = "m5", Key = "I:Jelly", N = 1, Plus = 0, Price = 2, State = "Cancel", Left = 0, Paid = false },
	{ Id = "m6", Key = "Q:bad", N = 1, Plus = 0, Price = 1, State = "Open", Left = 5 },
	{ Id = "m7", Key = "I:Jelly", N = 1, Plus = 0, Price = 1, State = "Weird", Left = 5 } },
	Waiting = 2, Today = { Lists = 3, Buys = 1 }, Gate = { Buy = "", List = "", ListIn = 0 } }
handlers.MarketMine(MINE)
local dot = find(find(root, "Tab_Mine"), "NewCount")
check(dot ~= nil and find(dot, "N").Text == "2", "a dot on Mine: 2 rows became Sold since I looked", dot and find(dot, "N").Text)
find(root, "Tab_Mine").OnClick()
local mine = find(root, "Mine")
check(names(findAll(mine, "^Mine_")) == "Mine_m1,Mine_m2,Mine_m3,Mine_m4,Mine_m5", "Mine: my rows (a bad key / state is not shown)", names(findAll(mine, "^Mine_")))
local m1 = find(mine, "Mine_m1")
check(find(m1, "Name").Text == "Jelly" and find(m1, "Count").Text == "×5" and find(m1, "Price").Text == "40" and find(m1, "Left").Text == "5:00"
	and find(m1, "Cancel").Text == "Cancel" and find(m1, "Cancel").Enabled == true, "Open: key name, count, price, time left, [Cancel]")
check(find(find(mine, "Mine_m2"), "State").Text == "Sold" and find(find(mine, "Mine_m2"), "Paid").Text == TXT.Paying
	and find(find(mine, "Mine_m3"), "Paid").Text == "Paid" and find(find(mine, "Mine_m2"), "Cancel") == nil,
	"Sold: Sold + Paying… / Paid; no [Cancel]")
check(find(find(mine, "Mine_m2"), "Name").Text == Config.WeaponName(3, "Warrior", "Halo") .. " +2", "a sold weapon: its name and +N")
check(find(find(mine, "Mine_m4"), "State").Text == "Back in your bag" and find(find(mine, "Mine_m5"), "State").Text == "Back in your bag"
	and find(find(mine, "Mine_m4"), "Cancel") == nil, "Expired / Cancel: Back in your bag")
check(find(mine, "Waiting1").Text == TXT.Checking and find(mine, "Waiting2").Text == TXT.Checking and find(mine, "Waiting3") == nil,
	"Waiting buys: a Checking… row each")
check(find(mine, "Today").Text == "Today: 3 listed · 1 bought", "the Today counts, small", find(mine, "Today").Text)
check(find(find(root, "Tab_Mine"), "NewCount") == nil and find(root, "Tab_Mine").PaintColor == "gold", "looking at Mine takes the dot away")
find(root, "Tab_Buy").OnClick()
check(find(find(root, "Tab_Mine"), "NewCount") == nil, "...and it stays away")
local MINE2 = { Rows = { table.unpack(MINE.Rows, 1, 5) }, Waiting = 0, Today = MINE.Today }
table.insert(MINE2.Rows, { Id = "m8", Key = "I:Jelly", N = 1, Plus = 0, Price = 3, State = "Sold", Left = 0, Paid = false })
handlers.MarketMine(MINE2)
dot = find(find(root, "Tab_Mine"), "NewCount")
check(dot ~= nil and find(dot, "N").Text == "1", "a new Sold row: the dot is back (1)")
find(root, "Tab_Mine").OnClick()
check(find(find(root, "Tab_Mine"), "NewCount") == nil and find(find(root, "Mine"), "Waiting1") == nil, "seen again; no Waiting rows left")
-- Cancel
Config.RateLimits.MarketCancel = 2
fired = {}
check(MarketWindow.Cancel("m2") == false and #fired == 0, "no [Cancel] for a Sold row")
find(find(find(root, "Mine"), "Mine_m1"), "Cancel").OnClick()
check(#fired == 1 and lastIs("MarketCancel", "m1"), "[Cancel] sends MarketCancel(id)", firedNames())
check(find(find(find(root, "Mine"), "Mine_m1"), "Cancel").Text == TXT.Checking and find(find(find(root, "Mine"), "Mine_m1"), "Cancel").Enabled == false,
	"while waiting: Checking…, off")
find(find(find(root, "Mine"), "Mine_m1"), "Cancel").OnClick()
check(#fired == 1, "[Cancel] once")
check(math.abs(S.ReadyAt.MarketCancel - (CLOCK + 2.15)) < 1e-9, "Config.RateLimits[name] wins over the default (2 + 0.15)", S.ReadyAt.MarketCancel - CLOCK)
S.MineNext = 0
tick(0.5)
check(lastIs("MarketMine"), "a Mine request inside the 3 s", firedNames())
handlers.MarketMine(MINE)
check(S.Pending == nil and find(find(find(root, "Mine"), "Mine_m1"), "Cancel").Text == "Cancel", "the Mine answer after the Cancel ends the wait (and asks the page)")
check(find(find(find(root, "Mine"), "Mine_m1"), "Cancel").Enabled == false, "...the button waits out its interval")
tick(2)
check(find(find(find(root, "Mine"), "Mine_m1"), "Cancel").Enabled == true, "after the interval [Cancel] is on")
Config.RateLimits.MarketCancel = nil

------------------------------------------------------------------ 7. requests: one per remote per interval, Index every 30 s
S.MineNext = 0
tick(2)
fired = {}
open({ Tab = "Buy" })
check(#fired == 0, "reopening inside the intervals sends nothing (Mine, Index, Browse still waiting out theirs)", firedNames())
tick(1.2)
local n1 = select(2, firedNames():gsub("MarketMine", ""))
check(n1 == 1 and select(2, firedNames():gsub("MarketIndex", "")) == 0, "...Mine once the interval has passed; Index not (30 s)", firedNames())
tick(1.2)
check(select(2, firedNames():gsub("MarketMine", "")) == 1, "no second Mine inside its 10 s poll")
tick(31)
check(select(2, firedNames():gsub("MarketIndex", "")) == 1, "the Buy tab asks Index again after 30 s", firedNames())
tick(1.2)
check(select(2, firedNames():gsub("MarketIndex", "")) == 1, "...once")
check(math.abs(S.IndexNext - S.ReadyAt.MarketIndex) > 20, "Index: the 30 s cache is its own wait")
fired = {}
handlers.MarketIndex(INDEX)
handlers.MarketPage(jellyPage(1, 1))
check(#fired == 0, "payloads from the server send nothing")

------------------------------------------------------------------ 8. the open arg: a Tab once; a rebuild keeps my tab
open({ Tab = "Mine" })
check(S.Tab == "Mine" and find(root, "Tab_Mine").PaintColor == "gold", "opened on Mine (the quests' [Go])")
find(root, "Tab_Sell").OnClick()
reg.Market.Cleanup()
table.clear(attrFns)
for _, ch in root:GetChildren() do ch:Destroy() end
update = reg.Market.Build(root, kit, openArg)
check(S.Tab == "Sell", "a rebuild with the same arg keeps my tab")
open({ Tab = "Zzz" })
check(S.Tab == "Sell", "an unknown tab in the arg is ignored")
open({ Tab = "Buy" })
check(S.Tab == "Buy", "a new Open arg is applied")
find(root, "Tab_Mine").OnClick()
find(root, "Tab_Buy").OnClick()
check(find(root, "Tab_Buy").PaintColor == "gold" and find(root, "Tab_Mine").PaintColor == "button", "the tabs repaint")

------------------------------------------------------------------ 9. the switch goes off again
Config.Features.Market = false
check(o.Menu() == nil, "switch off again: no menu entry")
fired = {}
local before = #opened
MarketWindow.Open("Mine")
check(#opened == before, "...and Open does nothing")
open(nil)
check(update == nil and #root:GetChildren() == 0 and #fired == 0, "...and a built window draws and sends nothing")
check(MarketWindow.Buy("a1", 3) == false and MarketWindow.List() == false and MarketWindow.Cancel("m1") == false and #fired == 0,
	"...and no action sends")
close()

print(string.format("MARKET_WINDOW_SUMMARY checks=%d failed=%d", checks, failed))
