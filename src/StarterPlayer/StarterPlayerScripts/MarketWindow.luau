-- MarketWindow.luau (게임성 개발 4, C-6 거래소 창; SPEC A23-127 · A23-133 · A23-130 · A23-111 · A23-98, contract
-- docs/design/market_window_2026-10-12.md §1 the window, §2 the remotes, §6 the agreed answers - §6 wins):
-- the Panels window "Market" (the bag's look: grade slots, the Panels capsule tabs / buttons), CLIENT ONLY. The server
-- (C-5) is not in the game yet: every remote is looked up by name when it is used (a missing one = the window says
-- TXT.Resting and sends nothing); everything shows only while Config.FeatureOn("Market") is on.
--   tabs    : Buy · Sell · Mine; the bottom line is my gold (bank + carried)
--   Buy     : kinds (Materials · Scrolls · Tonics · Weapons) + a search box (my own filter on the item's name, no request)
--             + the MarketIndex rows of the kind (icon, name, Low price, Count); right: the picked key's MarketPage rows
--             (count, +N, price, time left) with [Buy] and the pages. [Buy] = MarketBuy(id, price) once; Gate.Buy's key
--             text (Config.Market.Text) switches it off; a weapon key "W:T:P" shows my class's name / icon and is off when
--             I own that tier
--   Sell    : my sellable things from the last Inventory payload (Material · Enhance · Transfer · Tonic · Treat items and
--             the Spares "T:P" -> n; no worn weapon, no HP / MP potions) -> MarketBrowse(key, 1) gives Ref / Min / Max
--             (and the cheapest rows as a hint); count, price, "You get" (price - 10%), [List] = MarketList(kind, id, n,
--             price) ("I" + the item id, "W" + the spare key "T:P"); Gate.List's key text / "Wait %s" (Gate.ListIn) off
--   Mine    : MarketMine rows (Open: time left + [Cancel]; Sold: Paid / Paying…; Expired / Cancel: back in the bag),
--             Waiting, Today; a dot on the tab when a row became Sold since I last looked
-- The client never computes a gate (§6-4): the server's Gate keys come in MarketIndex / MarketMine. Display only: the
-- server checks every request again and its notices are Config.Market.Text keys (no second line here, A23-130).
-- Requests: one per remote per its interval (Config.RateLimits[name] when it exists) + a margin; MarketIndex at most
-- every 30 s (the server caches it 30 s); after a Buy / List / Cancel the Mine rows and the open page are asked again.
-- Text: short English in TXT (L10n key "MarketWindow.TXT.*", A23-111); item names through Config (UIKit.Tx). PC first.
-- Public API: MarketWindow.Init(C), MarketWindow.Start(), MarketWindow.IsReady(), MarketWindow.On(),
-- MarketWindow.Open(tab?), MarketWindow.OnIndex / OnPage / OnMine(payload), MarketWindow.Buy(id, price),
-- MarketWindow.List(), MarketWindow.Cancel(id), MarketWindow.Pump(); pure: MarketWindow.KeyInfo(key, ctx),
-- MarketWindow.IndexRows(ctx, kind, query), MarketWindow.SellEntries(ctx), MarketWindow.Fee(price), MarketWindow.TimeText(sec)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local L10n = require(Shared:WaitForChild("L10n"))

local MarketWindow = {}
local C = nil
local TAG = "MarketWindow"
local LocalPlayer = Players.LocalPlayer

-- player text (A23-130: short; A23-111: keys "MarketWindow.TXT.<field>"); the server's notices are Config.Market.Text
local TXT = {
	Title = "Market",
	Menu = "Market",
	Tabs = { Buy = "Buy", Sell = "Sell", Mine = "Mine" },
	Kinds = { Material = "Materials", Scroll = "Scrolls", Tonic = "Tonics", Weapon = "Weapons" }, -- the bag's words
	Search = "Search",
	Price = "Price",
	Buy = "Buy",
	List = "List",
	Cancel = "Cancel",
	Checking = "Checking…",
	Owned = "Owned",
	Wait = "Wait %s",
	Refused = "Not now.", -- a key the client has no text for
	Resting = "The market is resting.",
	Pick = "Pick one.",
	Empty = "Nothing here.",
	NoneToSell = "Nothing to sell.",
	Count = "×%d",
	Plus = "+%d",
	Page = "%d / %d",
	Of = "%d / %d",
	Prev = "◀",
	Next = "▶",
	Less = "−",
	More = "+",
	All = "All",
	OnSale = "On sale",
	Offer = "×%d  %s",
	Range = "%s – %s",
	YouGet = "You get %s",
	Sold = "Sold",
	Paid = "Paid",
	Paying = "Paying…",
	Back = "Back in your bag",
	Today = "Today: %d listed · %d bought",
	-- artisan contract ⑤ (10/14): an hour or more reads "1h 05m" (it read "1:05" like 65 s did)
	Hours = "%dh %02dm",
}
L10n.Register("MarketWindow.TXT", TXT)

-- layout (du = MainGui units) and fixed rules
local L = {
	Window = "Market",
	Tabs = { "Buy", "Sell", "Mine" },
	Kinds = { "Material", "Scroll", "Tonic", "Weapon" },
	Pad = 18, Width = 560, -- Panels FRAME.Pad (window rim -> content, each side); the bag's width
	TabH = 40, BarH = 40, RowGap = 8, KindH = 36, SearchH = 36, PageH = 36, HeadH = 44, BtnH = 44,
	LeftW = 250, Split = 12, RowH = 56, RowSlot = 44, BuyW = 74, PageRowH = 48, MineRowH = 58,
	Big = 84, CoinW = 26, StepW = 40, AllW = 56, CancelW = 100,
	Size = { Name = 19, Row = 17, Body = 16, Small = 15 },
	Inner = { X = 76 / 512, Y = 80 / 512, W = 360 / 512, H = 356 / 512 }, -- the slot parts' icon box (BagUI L.Inner)
	Slot = { Common = "SlotCommon", Fine = "SlotUncommon", Rare = "SlotRare", Epic = "SlotEpic", Legend = "SlotLegendary",
		Mythic = "SlotLegendary" },
	-- the bag's grades of its items (a Config.Loot.Items[id].Grade wins)
	ItemGrade = { SlimeCore = "Fine", BruteHorn = "Fine", KnightCrest = "Fine", CaptainBadge = "Rare",
		Enh70 = "Fine", Move70 = "Fine", Enh30 = "Rare", Move30 = "Rare", Enh10 = "Epic", Move10 = "Epic" },
	-- Config.Loot.Items[id].Kind -> the Buy kind; also the kinds that can be sold (§1: no quest things, no HP / MP potions)
	ItemKind = { Material = "Material", Enhance = "Scroll", Transfer = "Scroll", Tonic = "Tonic", Treat = "Tonic" },
	-- the client -> server remotes this window sends, and the seconds between two (Config.RateLimits[name] wins)
	Sends = { "MarketIndex", "MarketBrowse", "MarketMine", "MarketBuy", "MarketList", "MarketCancel" },
	Gaps = { MarketIndex = 1, MarketBrowse = 1, MarketMine = 1, MarketBuy = 6, MarketList = 6, MarketCancel = 6 },
	GapMargin = 0.15, -- s over the interval (the server drops a 2nd request inside it without a reply)
	IndexEvery = 30, -- s: MarketIndex is cached 30 s on the server
	MineEvery = 10, -- s: the open window asks for its Mine rows again (a sale, Paid, Gate)
	Timeout = 3, -- s after a Buy / List / Cancel: the answer is taken as in; Mine rows and the page are asked again
	Fee = 0.10, -- A23-133: the market's cut of a sale
	MaxDigits = 9, MaxQuery = 24, HintRows = 3, MaxWaiting = 5,
}

-- state (everything the server told me stays here between two openings of the window)
local S = {
	Ready = false, Started = false, LastArg = nil,
	Tab = "Buy", Kind = "Material", Query = "",
	BuyKey = nil, BuyPage = 1, -- the picked Buy key and its page
	SellKey = nil, SellN = 1, SellPrice = nil, -- the picked Sell key, how many, the typed price (nil = Ref)
	Index = nil, IndexVer = 0, -- { Rows = { { Key, Low, Count } }, At }
	Pages = {}, Meta = {}, PageVer = 0, -- [key][page] = { Page, Pages, Rows, At }; [key] = { Ref, Min, Max }
	Mine = nil, MineVer = 0, -- { Rows, Waiting, Today }
	Gate = { Buy = "", List = "", ListIn = 0 }, GateAt = 0, -- the server's gate keys (§6-4)
	SeenSold = {}, -- [row id] = true: a Sold row I looked at on the Mine tab
	Pending = nil, -- { Name, Id, At }: a Buy / List / Cancel waiting for its answer
	ReadyAt = {}, -- [remote] = os.clock() when the next send is allowed
	WantMine = false, WantIndex = false, WantPage = nil, -- what to ask when the interval allows
	IndexNext = 0, MineNext = 0,
}
local VIEW = {} -- the open window: Kit, Parent, Body, Bottom, Tabs, Timers, Sig
local refreshParts, redraw -- (defined with the drawing below)

---------------------------------------------------------------------------------------------------- small helpers
local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function attr(name, d)
	local v = LocalPlayer and LocalPlayer:GetAttribute(name)
	if v == nil then return d end
	return v
end

local function tx(t, key, ...)
	local ui = C and C.UIKit
	if type(ui) == "table" and type(ui.Tx) == "function" then
		local ok, s = pcall(ui.Tx, t, key, ...)
		if ok and type(s) == "string" then return s end
	end
	local s = t[key .. "En"] or t[key]
	if type(s) ~= "string" then return "" end
	if select("#", ...) > 0 then
		local ok, out = pcall(string.format, s, ...)
		return ok and out or s
	end
	return s
end

local function gradeDef(id)
	return Config.WeaponGrades[id] or Config.WeaponGrades.Common
end

local function weaponGradeId(tier)
	local info = Config.WeaponInfo[tier]
	return (info and Config.WeaponGrades[info.Grade]) and info.Grade or "Common"
end

local function itemGradeId(id, def)
	local g = type(def) == "table" and def.Grade or nil
	if type(g) == "string" and Config.WeaponGrades[g] then return g end
	return L.ItemGrade[id] or "Common"
end

local function money(n)
	return Util.FormatInt(math.max(0, math.floor(num(n, 0))))
end

-- the switch (§0: off = no menu entry, Open does nothing, nothing drawn)
function MarketWindow.On()
	return type(Config.FeatureOn) == "function" and Config.FeatureOn("Market") == true
end

-- a refusal / notice key -> its text: Config.Market.Text[key] when it exists, else the key's own fallback
local function noteText(key)
	local market = type(Config.Market) == "table" and Config.Market or nil
	local texts = market and type(market.Text) == "table" and market.Text or nil
	if texts and texts[key] ~= nil then
		local s = tx(texts, key)
		if s ~= "" then return s end
	end
	if key == "Resting" then return tx(TXT, "Resting") end
	return tx(TXT, "Refused")
end
MarketWindow.NoteText = noteText

-- seconds -> "m:ss" (under an hour) or "1h 05m" (TXT.Hours; "h:mm" looked the same as m:ss - 3900 s and 65 s both "1:05")
function MarketWindow.TimeText(sec)
	sec = math.max(0, math.floor(num(sec, 0)))
	if sec >= 3600 then
		return tx(TXT, "Hours", sec // 3600, (sec % 3600) // 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- the market's cut and what the seller gets (A23-133: price - floor(price x 10%))
function MarketWindow.Fee(price)
	price = math.max(0, math.floor(num(price, 0)))
	local fee = math.floor(price * L.Fee)
	return fee, price - fee
end

local function lastInventory()
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.LastInventory) ~= "function" then return {} end
	local ok, payload = pcall(panels.LastInventory)
	return (ok and type(payload) == "table") and payload or {}
end

local function hasRemote(name)
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local r = folder and folder:FindFirstChild(name)
	return r ~= nil and r:IsA("RemoteEvent")
end

-- the market is resting: a remote it needs is not there (the server's C-5 is not in this game yet)
local function resting()
	for _, name in L.Sends do
		if not hasRemote(name) then return true end
	end
	return false
end
MarketWindow.IsResting = resting

local function gapOf(name)
	local limits = type(Config.RateLimits) == "table" and Config.RateLimits or {}
	return math.max(0, num(limits[name], L.Gaps[name] or 1)) + L.GapMargin
end

-- sends one request unless the remote is missing or its interval has not passed; true when sent
local function send(name, ...)
	local kit = VIEW.Kit
	local now = os.clock()
	if not kit or not hasRemote(name) or now < (S.ReadyAt[name] or 0) then return false end
	kit.Fire(name, ...)
	S.ReadyAt[name] = now + gapOf(name)
	return true
end

local function gapOn(name)
	return os.clock() < (S.ReadyAt[name] or 0)
end

---------------------------------------------------------------------------------------------------- the model (pure)
local function owns(ctx, tier)
	local mask = math.max(0, math.floor(num(ctx.Mask, 0)))
	return tier == math.floor(num(ctx.Equipped, 0)) or bit32.btest(mask, bit32.lshift(1, tier - 1))
end

-- one market key as the window shows it: "I:<itemId>" or "W:<tier>:<plus>" (my class's name / icon); nil when the
-- client does not know it. ctx = { Class, Faction }. { Key, Kind (Material | Scroll | Tonic | Weapon), Id? , Tier?, Plus,
-- Name, Title (Name + "+N"), Icon, Grade, Color, Rank, Spare? ("T:P", the Sell id of a weapon) }
function MarketWindow.KeyInfo(key, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	if type(key) ~= "string" then return nil end
	local id = string.match(key, "^I:(.+)$")
	if id then
		local def = Config.Loot.Items[id]
		local kind = type(def) == "table" and L.ItemKind[def.Kind] or nil
		if not kind then return nil end
		local grade = itemGradeId(id, def)
		local name = tx(def, "Name")
		return { Key = key, Kind = kind, Id = id, Name = name, Title = name, Icon = id, Grade = grade, Plus = 0,
			Color = typeof(def.Color) == "Color3" and def.Color or gradeDef(grade).Color,
			Rank = table.find(Config.Loot.Order or {}, id) or 1000 }
	end
	local t, p = string.match(key, "^W:(%d+):(%d+)$")
	local tier, plus = tonumber(t), tonumber(p)
	if not (tier and plus and Config.Weapons[tier]) then return nil end
	plus = math.clamp(math.floor(plus), 0, Config.Loot.MaxEnhance)
	local grade = weaponGradeId(tier)
	local name = Config.WeaponName(tier, ctx.Class, ctx.Faction)
	return { Key = key, Kind = "Weapon", Tier = tier, Plus = plus, Name = name,
		Title = plus > 0 and (name .. " " .. tx(TXT, "Plus", plus)) or name,
		Icon = Config.WeaponArtKey(tier, ctx.Class, ctx.Faction), Grade = grade, Color = gradeDef(grade).Color, Rank = tier,
		Spare = string.format("%d:%d", tier, plus) }
end

local function infoLess(a, b)
	if a.Rank ~= b.Rank then return a.Rank < b.Rank end
	if a.Plus ~= b.Plus then return a.Plus < b.Plus end
	local na, nb = string.lower(a.Name), string.lower(b.Name)
	if na ~= nb then return na < nb end
	return a.Key < b.Key
end

-- the Buy list of one kind: the MarketIndex rows whose item name has the query in it (my own filter, no request).
-- ctx = { Class, Faction, Index = { Rows = { { Key, Low, Count } } } }; a row = { Key, Info, Low, Count }
function MarketWindow.IndexRows(ctx, kind, query)
	ctx = type(ctx) == "table" and ctx or {}
	local out = {}
	local rows = type(ctx.Index) == "table" and type(ctx.Index.Rows) == "table" and ctx.Index.Rows or {}
	local q = string.lower(type(query) == "string" and query or "")
	for _, r in rows do
		local info = MarketWindow.KeyInfo(r.Key, ctx)
		if info and info.Kind == kind and (q == "" or string.find(string.lower(info.Name), q, 1, true)) then
			table.insert(out, { Key = r.Key, Info = info, Low = r.Low, Count = r.Count })
		end
	end
	table.sort(out, function(a, b) return infoLess(a.Info, b.Info) end)
	return out
end

-- my sellable things (§1): items of the kinds Material · Enhance · Transfer · Tonic · Treat and the Spares "T:P" -> n.
-- ctx = { Items, Spares, Class, Faction }; an entry = { Key, Info, Count }
function MarketWindow.SellEntries(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local out = {}
	local items = type(ctx.Items) == "table" and ctx.Items or {}
	local ids = table.clone(Config.Loot.Order or {})
	local extra = {}
	for id in Config.Loot.Items do
		if not table.find(ids, id) then table.insert(extra, id) end
	end
	table.sort(extra)
	for _, id in extra do table.insert(ids, id) end
	for _, id in ids do
		local n = math.floor(num(items[id], 0))
		local info = n >= 1 and MarketWindow.KeyInfo("I:" .. id, ctx) or nil
		if info then table.insert(out, { Key = info.Key, Info = info, Count = n }) end
	end
	local spares = {}
	for key, n in type(ctx.Spares) == "table" and ctx.Spares or {} do
		local t, p = string.match(tostring(key), "^(%d+):(%d+)$")
		-- artisan contract ⑤: no tier-1 spare (the free class weapon; the server refuses W:1:*)
		if t and tonumber(t) <= 1 then t = nil end
		local info = t and MarketWindow.KeyInfo("W:" .. t .. ":" .. p, ctx) or nil
		n = math.floor(num(n, 0))
		if info and n >= 1 then table.insert(spares, { Key = info.Key, Info = info, Count = n }) end
	end
	table.sort(spares, function(a, b) return infoLess(a.Info, b.Info) end)
	for _, e in spares do table.insert(out, e) end
	return out
end

local function context()
	local inv = lastInventory()
	local class = attr("Class")
	local faction = attr("Faction")
	return { Items = type(inv.Items) == "table" and inv.Items or {}, Spares = type(inv.Spares) == "table" and inv.Spares or {},
		Class = (type(class) == "string" and Config.Classes[class]) and class or "Warrior",
		Faction = type(faction) == "string" and faction or "None",
		Mask = num(attr("WeaponOwnedMask"), 0), Equipped = num(attr("WeaponTier"), 0), Index = S.Index }
end

local function goldNow()
	return math.max(0, math.floor(num(attr("BankGold"), 0) + num(attr("CarriedGold"), 0)))
end

-- the price the seller means, clamped to the server's Min..Max (Ref when nothing is typed); nil while the range is unknown
local function sellPrice()
	local m = S.Meta[S.SellKey]
	if not m then return nil end
	local p = math.floor(num(S.SellPrice, m.Ref or m.Min or 1))
	if m.Min then p = math.max(p, math.floor(m.Min)) end
	if m.Max then p = math.min(p, math.floor(m.Max)) end
	return math.max(p, 1)
end

local function listWait()
	return math.max(0, S.Gate.ListIn - (os.clock() - S.GateAt))
end

---------------------------------------------------------------------------------------------------- the server's words
local function readGate(g)
	if type(g) ~= "table" then return end
	S.Gate = { Buy = type(g.Buy) == "string" and g.Buy or "", List = type(g.List) == "string" and g.List or "",
		ListIn = math.max(0, num(g.ListIn, 0)) }
	S.GateAt = os.clock()
end

local function wantOpenPage()
	if S.Tab == "Buy" and S.BuyKey then
		S.WantPage = { Key = S.BuyKey, Page = S.BuyPage }
	elseif S.Tab == "Sell" and S.SellKey then
		S.WantPage = { Key = S.SellKey, Page = 1 }
	end
end

-- s->c MarketIndex { Rows = { { Key, Low, Count } }, At, Gate? }
function MarketWindow.OnIndex(payload)
	if type(payload) ~= "table" or type(payload.Rows) ~= "table" then return end
	local rows = {}
	for _, r in payload.Rows do
		if type(r) == "table" and type(r.Key) == "string" and num(r.Low, nil) and math.floor(num(r.Count, 0)) >= 1 then
			table.insert(rows, { Key = r.Key, Low = math.max(0, math.floor(r.Low)), Count = math.floor(r.Count) })
		end
	end
	S.Index = { Rows = rows, At = num(payload.At, 0) }
	S.IndexVer += 1
	readGate(payload.Gate)
	if VIEW.Kit then refreshParts() end
end

-- s->c MarketPage { Key, Page, Pages, Rows = { { Id, Price, N, Plus, Left } }, Ref, Min, Max }
function MarketWindow.OnPage(payload)
	if type(payload) ~= "table" or type(payload.Key) ~= "string" or type(payload.Rows) ~= "table" then return end
	local page = math.max(1, math.floor(num(payload.Page, 1)))
	local rows = {}
	for _, r in payload.Rows do
		if type(r) == "table" and (type(r.Id) == "string" or type(r.Id) == "number") and num(r.Price, nil) then
			table.insert(rows, { Id = r.Id, Price = math.max(0, math.floor(r.Price)), N = math.max(1, math.floor(num(r.N, 1))),
				Plus = math.max(0, math.floor(num(r.Plus, 0))), Left = math.max(0, num(r.Left, 0)) })
		end
	end
	S.Pages[payload.Key] = S.Pages[payload.Key] or {}
	S.Pages[payload.Key][page] = { Page = page, Pages = math.max(page, math.floor(num(payload.Pages, page))), Rows = rows,
		At = os.clock() }
	local meta = S.Meta[payload.Key] or {}
	for _, f in { "Ref", "Min", "Max" } do
		if num(payload[f], nil) then meta[f] = payload[f] end
	end
	S.Meta[payload.Key] = meta
	S.PageVer += 1
	if VIEW.Kit then refreshParts() end
end

-- s->c MarketMine { Rows = { { Id, Key, N, Plus, Price, State, Left, Paid } }, Waiting, Today = { Lists, Buys }, Gate? }
function MarketWindow.OnMine(payload)
	if type(payload) ~= "table" then return end
	local rows = {}
	for _, r in type(payload.Rows) == "table" and payload.Rows or {} do
		local state = type(r) == "table" and r.State or nil
		if (state == "Open" or state == "Sold" or state == "Cancel" or state == "Expired") and type(r.Key) == "string"
			and (type(r.Id) == "string" or type(r.Id) == "number") then
			table.insert(rows, { Id = r.Id, Key = r.Key, N = math.max(1, math.floor(num(r.N, 1))), Plus = math.max(0, math.floor(num(r.Plus, 0))),
				Price = math.max(0, math.floor(num(r.Price, 0))), State = state, Left = math.max(0, num(r.Left, 0)), Paid = r.Paid == true,
				At = os.clock() })
		end
	end
	local waiting = type(payload.Waiting) == "table" and #payload.Waiting or math.max(0, math.floor(num(payload.Waiting, 0)))
	local today = type(payload.Today) == "table" and payload.Today or nil
	S.Mine = { Rows = rows, Waiting = waiting,
		Today = today and { Lists = math.max(0, math.floor(num(today.Lists, 0))), Buys = math.max(0, math.floor(num(today.Buys, 0))) } or nil }
	S.MineVer += 1
	readGate(payload.Gate)
	-- the Mine rows I asked for after the Buy / List / Cancel are its answer: the page is asked again too
	if S.Pending and (S.MineAskedAt or -1) >= S.Pending.At then
		S.Pending = nil
		wantOpenPage()
	end
	if VIEW.Kit then refreshParts() end
end

-- sends what is wanted as far as the intervals allow (the open window's 0.25 s update and every click call it)
function MarketWindow.Pump()
	if not (VIEW.Kit and MarketWindow.On()) or resting() then return end
	local now = os.clock()
	local p = S.Pending
	if p and now - p.At >= L.Timeout then
		S.Pending = nil
		S.WantMine = true
		wantOpenPage()
		refreshParts()
	end
	if now >= S.MineNext then S.WantMine = true end
	if S.Tab == "Buy" and now >= S.IndexNext then S.WantIndex = true end -- the Buy list's own 30 s
	if S.WantMine and send("MarketMine") then
		S.WantMine, S.MineNext, S.MineAskedAt = false, now + L.MineEvery, now
	end
	if S.WantIndex and now >= S.IndexNext and send("MarketIndex") then
		S.WantIndex, S.IndexNext = false, now + L.IndexEvery
	end
	local w = S.WantPage
	if w and send("MarketBrowse", w.Key, w.Page) then S.WantPage = nil end
end

---------------------------------------------------------------------------------------------------- drawing helpers
local function ui() return C and C.UIKit end

local function label(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = VIEW.Kit and VIEW.Kit.Font or Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	for k, v in props or {} do
		if k ~= "Style" then l[k] = v end
	end
	l.Parent = parent
	local kit = ui()
	if props and props.Style == false then
		-- a tight caption scaled down to fit its box, at most `size` (CraftWindow: the styled text floor cut "Lv 20")
		l.TextScaled = true
		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = size
		tc.Parent = l
		return l
	end
	if type(kit) == "table" and type(kit.StyleText) == "function" then
		pcall(kit.StyleText, l, (props and props.Style) or "Body")
		l.TextColor3 = color
	end
	return l
end

local function colorOf(name)
	local kit = VIEW.Kit
	local th = kit and kit.Theme or {}
	if name == "Gold" then return th.Gold end
	if name == "Good" then return th.Good end
	if name == "Bad" then return th.Bad end
	if name == "Sub" then return th.SubText end
	return th.Text
end

-- one approved grade slot with the icon in its Inner box (the bag's look); no icon art = the name's first letter
local function slot(parent, gradeId, icon, size, name, mark)
	local kit = ui()
	local box = kit.ArtFrame(gradeId and L.Slot[gradeId] or "SlotEmpty", { Name = name or "Slot", Size = UDim2.fromOffset(size, size),
		Parent = parent }, { BackgroundColor3 = Color3.fromRGB(16, 20, 40), CornerRadius = UDim.new(0, 10),
		StrokeColor = gradeId and gradeDef(gradeId).Color or Color3.fromRGB(60, 66, 96), StrokeThickness = 2 })
	if icon then
		local props = { Name = "Icon", Position = UDim2.fromScale(L.Inner.X, L.Inner.Y), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
			ScaleType = Enum.ScaleType.Fit, ZIndex = (tonumber(box.ZIndex) or 1) + 1 }
		local img = kit.ItemIcon(icon, props)
		if img then
			img.Parent = box
		elseif type(mark) == "table" and type(mark.Text) == "string" then
			label(box, string.upper(string.match(mark.Text, "%w") or "?"), math.floor(size * 0.42),
				typeof(mark.Color) == "Color3" and mark.Color or Color3.new(1, 1, 1), { Name = "Letter", AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
					TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = props.ZIndex, Style = "Number" })
		end
	end
	return box
end

local function rim(box)
	local f = Instance.new("Frame")
	f.Name = "Picked"
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(1, 1)
	f.Size = UDim2.new(1, -2, 1, -2)
	f.ZIndex = (tonumber(box.ZIndex) or 1) + 4
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = f
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = colorOf("Gold")
	st.Thickness = 3
	st.Parent = f
	f.Parent = box
end

local function clear(frame)
	if not frame then return end
	for _, ch in frame:GetChildren() do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
end

local function listLayout(frame, gap, center, horizontal)
	local list = frame:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	if center then list.HorizontalAlignment = Enum.HorizontalAlignment.Center end
	if horizontal then list.FillDirection = Enum.FillDirection.Horizontal end
	list.Parent = frame
	return list
end

local function plain(parent, name, props)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	for k, v in props or {} do f[k] = v end
	f.Parent = parent
	return f
end

local function scrollBox(parent, name, props)
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.ScrollBarThickness = 6
	s.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	for k, v in props or {} do s[k] = v end
	s.Parent = parent
	return s
end

-- a one-line line in the middle of a frame
local function middleLine(parent, text, color)
	return label(parent, text, L.Size.Body, color or colorOf("Sub"), { Name = "Status", AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.3, 0), Size = UDim2.new(0.8, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center })
end

-- the approved text-box art (InputField) with a TextBox in it; returns the art frame and the TextBox
local function inputBox(parent, name, text, placeholder, props)
	local kit = ui()
	local aprops = { Name = name, Parent = parent }
	for k, v in props or {} do aprops[k] = v end
	local art = kit.ArtFrame("InputField", aprops, { BackgroundColor3 = Color3.fromRGB(236, 226, 200), CornerRadius = UDim.new(0, 8) })
	local tb = Instance.new("TextBox")
	tb.Name = "Input"
	tb.AutoLocalize = false -- A23-179: what a player types stays as it is
	tb.BackgroundTransparency = 1
	tb.BorderSizePixel = 0
	tb.ClearTextOnFocus = false
	tb.MultiLine = false
	tb.Font = VIEW.Kit and VIEW.Kit.Font or Enum.Font.GothamMedium
	tb.TextSize = L.Size.Body
	tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.PlaceholderText = placeholder
	tb.Text = text
	tb.Position = UDim2.fromOffset(14, 0)
	tb.Size = UDim2.new(1, -28, 1, 0)
	local kitUi = ui()
	if type(kitUi) == "table" and type(kitUi.StyleText) == "function" then pcall(kitUi.StyleText, tb, "Body", true) end
	local colors = type(Config.UIArt) == "table" and type(Config.UIArt.Colors) == "table" and Config.UIArt.Colors or {}
	if colors.Ink then tb.TextColor3 = colors.Ink end
	if colors.InkSoft then tb.PlaceholderColor3 = colors.InkSoft end
	tb.Parent = art
	return art, tb
end

local function coinLine(parent, text, color)
	local kit = ui()
	local coin = kit.ArtImage("IconCoin", { Name = "Coin", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(L.CoinW, L.CoinW) })
	if coin then coin.Parent = parent end
	label(parent, text, L.Size.Body, color, { Name = "Gold", AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, L.CoinW + 6, 0.5, 0), Size = UDim2.new(0.5, 0, 1, 0), TextWrapped = false, Style = "Number" })
end

-- a Panels capsule button placed by hand (the kit sets its layout order; here it sits in a frame)
local function capsule(parent, text, color, size, onClick, props)
	local kit = VIEW.Kit
	local b = kit.Button(parent, text, color, size, onClick)
	for k, v in props or {} do b[k] = v end
	return b
end

-- one list row of a thing in its grade slot: the title, the right column's two short lines (Right1 over Right2)
local function itemRow(list, info, i, o)
	local row = Instance.new("TextButton")
	row.Name = "Row_" .. info.Key
	row.Text = ""
	row.AutoButtonColor = false
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, L.RowH)
	row.LayoutOrder = i
	row.Parent = list
	row.Activated:Connect(o.OnClick)
	local z = (tonumber(row.ZIndex) or 1) + 1
	local slotBox = slot(row, info.Grade, info.Icon, L.RowSlot, "Slot", { Text = info.Name, Color = info.Color })
	slotBox.Position = UDim2.fromOffset(4, (L.RowH - L.RowSlot) / 2)
	local x = L.RowSlot + 12
	label(row, info.Title, L.Size.Small, info.Color or colorOf("Text"), { Name = "Name", Position = UDim2.fromOffset(x, 4),
		Size = UDim2.new(1, -(x + o.RightW), 1, -8), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = z })
	if o.Right1 then
		label(row, o.Right1, L.Size.Small, o.Right1Color or colorOf("Gold"), { Name = "Right1", AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 9), Size = UDim2.fromOffset(o.RightW - 6, 18), TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false, ZIndex = z, Style = false })
	end
	if o.Right2 then
		label(row, o.Right2, L.Size.Small, colorOf("Sub"), { Name = "Right2", AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 31), Size = UDim2.fromOffset(o.RightW - 6, 18), TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false, ZIndex = z, Style = false })
	end
	if o.Picked then rim(row) end
	return row
end

local function tickTimers()
	local now = os.clock()
	for _, group in VIEW.Timers or {} do
		for _, fn in group do fn(now) end
	end
end

---------------------------------------------------------------------------------------------------- Buy
-- the [Buy] button of one page row: its words and whether it is on (the gate's own key text wins, §6-4)
local function buyState(row, info, ctx)
	local text = tx(TXT, "Buy")
	local p = S.Pending
	if p then
		if p.Name == "MarketBuy" and p.Id == row.Id then return tx(TXT, "Checking"), false end
		return text, false
	end
	if S.Gate.Buy ~= "" then return noteText(S.Gate.Buy), false end
	if info.Kind == "Weapon" and owns(ctx, info.Tier) then return tx(TXT, "Owned"), false end
	if gapOn("MarketBuy") then return text, false end
	return text, true
end

local function pageEntry(key, page)
	local byPage = key and S.Pages[key]
	return byPage and byPage[page] or nil
end

local function drawIndex(ctx)
	local list = VIEW.IndexList
	if not (list and list.Parent) then return end
	local keptY = list.CanvasPosition.Y
	clear(list)
	-- the picked key stays while it is in this kind; else the kind's first row (its page is asked for)
	local all = MarketWindow.IndexRows(ctx, S.Kind, "")
	local found = false
	for _, r in all do
		if r.Key == S.BuyKey then found = true end
	end
	if not found then
		S.BuyKey, S.BuyPage = all[1] and all[1].Key or nil, 1
		wantOpenPage()
	end
	local rows = MarketWindow.IndexRows(ctx, S.Kind, S.Query)
	if #rows == 0 then
		middleLine(list, tx(TXT, "Empty"))
		return
	end
	for i, r in rows do
		local key = r.Key
		itemRow(list, r.Info, i, { RightW = 76, Right1 = money(r.Low), Right2 = tx(TXT, "Count", r.Count), Picked = key == S.BuyKey,
			OnClick = function() MarketWindow.PickBuy(key) end })
	end
	list.CanvasPosition = Vector2.new(0, keptY)
end

-- one listing of the picked key: count (+N), price, time left, [Buy]
local function offerRow(frame, r, info, ctx, entry, i)
	local kit = VIEW.Kit
	local row = plain(frame, "Offer_" .. tostring(r.Id), { Size = UDim2.new(1, 0, 0, L.PageRowH), LayoutOrder = i })
	local count = tx(TXT, "Count", r.N)
	if r.Plus > 0 then count = count .. " " .. tx(TXT, "Plus", r.Plus) end
	label(row, count, L.Size.Small, colorOf("Text"), { Name = "Count", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(58, 22), TextWrapped = false, Style = false })
	label(row, money(r.Price), L.Size.Body, colorOf("Gold"), { Name = "Price", AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 60, 0.5, 0), Size = UDim2.fromOffset(78, 22), TextWrapped = false, Style = false })
	local left = r.Left
	local timeLabel = label(row, MarketWindow.TimeText(left - (os.clock() - entry.At)), L.Size.Small, colorOf("Sub"), { Name = "Left",
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 140, 0.5, 0), Size = UDim2.fromOffset(44, 22), TextWrapped = false,
		Style = false })
	table.insert(VIEW.Timers.Page, function(now)
		if timeLabel.Parent then timeLabel.Text = MarketWindow.TimeText(left - (now - entry.At)) end
	end)
	local text, enabled = buyState(r, info, ctx)
	local id, price = r.Id, r.Price
	local b = capsule(row, text, kit.Palette.Buy or kit.Palette.Button, UDim2.fromOffset(L.BuyW, 36), function()
		MarketWindow.Buy(id, price)
	end, { Name = "Buy", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
	kit.SetEnabled(b, enabled)
end

local function drawPage(ctx)
	local right = VIEW.Right
	if not (right and right.Parent) then return end
	clear(right)
	VIEW.Timers.Page = {}
	local kit = VIEW.Kit
	local info = S.BuyKey and MarketWindow.KeyInfo(S.BuyKey, ctx) or nil
	if not info then
		middleLine(right, tx(TXT, "Pick"))
		return
	end
	local head = plain(right, "Head", { Size = UDim2.new(1, 0, 0, L.HeadH) })
	local big = slot(head, info.Grade, info.Icon, 40, "Slot", { Text = info.Name, Color = info.Color })
	big.Position = UDim2.fromOffset(0, 2)
	label(head, info.Title, L.Size.Row, info.Color or colorOf("Text"), { Name = "Title", Position = UDim2.fromOffset(50, 0),
		Size = UDim2.new(1, -50, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, Style = "Title" })
	local entry = pageEntry(S.BuyKey, S.BuyPage)
	if not entry then
		middleLine(right, tx(TXT, "Checking"))
		return
	end
	local top = L.HeadH + 4
	local frame = scrollBox(right, "Offers", { Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -(top + L.PageH + L.RowGap)) })
	listLayout(frame, 4, false)
	for i, r in entry.Rows do offerRow(frame, r, info, ctx, entry, i) end
	local pager = plain(right, "Pager", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, L.PageH) })
	local prev = capsule(pager, tx(TXT, "Prev"), kit.Palette.Button, UDim2.fromOffset(64, L.PageH), function() MarketWindow.Page(-1) end,
		{ Name = "Prev", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) })
	kit.SetEnabled(prev, entry.Page > 1)
	label(pager, tx(TXT, "Page", entry.Page, entry.Pages), L.Size.Body, colorOf("Text"), { Name = "Page", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, -140, 1, 0), TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false, Style = "Number" })
	local nxt = capsule(pager, tx(TXT, "Next"), kit.Palette.Button, UDim2.fromOffset(64, L.PageH), function() MarketWindow.Page(1) end,
		{ Name = "Next", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
	kit.SetEnabled(nxt, entry.Page < entry.Pages)
end

local function buildBuy(body)
	local kit = VIEW.Kit
	local kinds = plain(body, "Kinds", { Size = UDim2.new(1, 0, 0, L.KindH) })
	listLayout(kinds, 6, false, true)
	local n = #L.Kinds
	for i, id in L.Kinds do
		local b = capsule(kinds, tx(TXT.Kinds, id), kit.Palette.Button, UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), function()
			MarketWindow.ShowKind(id)
		end, { Name = "Kind_" .. id, LayoutOrder = i })
		local on = S.Kind == id
		kit.Paint(b, on and kit.Theme.Gold or kit.Palette.Button, on and kit.Palette.DarkText or kit.Theme.Text)
	end
	local top = L.KindH + L.RowGap
	local _, tb = inputBox(body, "Search", S.Query, tx(TXT, "Search"), { Position = UDim2.fromOffset(0, top),
		Size = UDim2.fromOffset(L.LeftW, L.SearchH) })
	VIEW.Search = tb
	tb:GetPropertyChangedSignal("Text"):Connect(function()
		local text = tb.Text
		if #text > L.MaxQuery then
			tb.Text = string.sub(text, 1, L.MaxQuery)
			return
		end
		S.Query = text
		if VIEW.Kit == kit then drawIndex(context()) end
	end)
	local listTop = top + L.SearchH + L.RowGap
	VIEW.IndexList = scrollBox(body, "Index", { Position = UDim2.fromOffset(0, listTop), Size = UDim2.new(0, L.LeftW, 1, -listTop) })
	listLayout(VIEW.IndexList, 6, false)
	VIEW.Right = plain(body, "Right", { Position = UDim2.fromOffset(L.LeftW + L.Split, top),
		Size = UDim2.new(1, -(L.LeftW + L.Split), 1, -top) })
end

---------------------------------------------------------------------------------------------------- Sell
local function sellEntry(ctx)
	for _, e in MarketWindow.SellEntries(ctx) do
		if e.Key == S.SellKey then return e end
	end
	return nil
end

-- [List]: its words and whether it is on. price = the clamped price (nil while Min / Max are not known)
local function listState(price)
	local text = tx(TXT, "List")
	local p = S.Pending
	if p then return p.Name == "MarketList" and tx(TXT, "Checking") or text, false end
	if S.Gate.List ~= "" then return noteText(S.Gate.List), false end
	local wait = listWait()
	if wait > 0 then return tx(TXT, "Wait", MarketWindow.TimeText(wait)), false end
	if not price then return tx(TXT, "Checking"), false end
	if gapOn("MarketList") then return text, false end
	return text, true
end

local function updateYou()
	local l = VIEW.YouGet
	if not (l and l.Parent) then return end
	local price = sellPrice()
	local _, get = MarketWindow.Fee(price or 0)
	l.Text = price and tx(TXT, "YouGet", money(get)) or ""
end

local function drawSellList(ctx)
	local list = VIEW.List
	if not (list and list.Parent) then return end
	local keptY = list.CanvasPosition.Y
	clear(list)
	local entries = MarketWindow.SellEntries(ctx)
	local found = false
	for _, e in entries do
		if e.Key == S.SellKey then found = true end
	end
	if not found then
		S.SellKey, S.SellN, S.SellPrice = entries[1] and entries[1].Key or nil, 1, nil
		wantOpenPage()
	end
	if #entries == 0 then
		middleLine(list, tx(TXT, "NoneToSell"))
		return
	end
	for i, e in entries do
		local key = e.Key
		itemRow(list, e.Info, i, { RightW = 60, Right1 = tx(TXT, "Count", e.Count), Right1Color = colorOf("Text"), Picked = key == S.SellKey,
			OnClick = function() MarketWindow.PickSell(key) end })
	end
	list.CanvasPosition = Vector2.new(0, keptY)
end

local function drawSellDetail(ctx)
	local det = VIEW.Detail
	if not (det and det.Parent) then return end
	if VIEW.Focus then
		VIEW.Dirty = true -- the price box has the keyboard: it is drawn again when it lets go
		return
	end
	VIEW.Dirty = false
	VIEW.Timers.Sell = {}
	VIEW.YouGet = nil
	clear(det)
	local kit = VIEW.Kit
	local entry = sellEntry(ctx)
	if not entry then
		middleLine(det, tx(TXT, #MarketWindow.SellEntries(ctx) == 0 and "NoneToSell" or "Pick"))
		return
	end
	local info = entry.Info
	listLayout(det, 6, true)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local big = slot(det, info.Grade, info.Icon, L.Big, "Big", { Text = info.Name, Color = info.Color })
	big.LayoutOrder = nextOrder()
	label(det, info.Title, L.Size.Name, info.Color or colorOf("Text"), { Name = "Name", Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder(), Style = "Title" })
	-- the cheapest rows now on sale (MarketBrowse page 1) as a hint
	local first = pageEntry(S.SellKey, 1)
	if first and #first.Rows > 0 then
		label(det, tx(TXT, "OnSale"), L.Size.Small, colorOf("Sub"), { Name = "OnSale", Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder() })
		for i = 1, math.min(L.HintRows, #first.Rows) do
			local r = first.Rows[i]
			label(det, tx(TXT, "Offer", r.N, money(r.Price)), L.Size.Small, colorOf("Text"), { Name = "Hint" .. i,
				Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = nextOrder() })
		end
	end
	-- how many: - / + / All
	local n = math.clamp(S.SellN, 1, entry.Count)
	S.SellN = n
	local counts = plain(det, "CountRow", { Size = UDim2.new(1, 0, 0, L.StepW), LayoutOrder = nextOrder() })
	listLayout(counts, 6, false, true)
	local less = capsule(counts, tx(TXT, "Less"), kit.Palette.Button, UDim2.fromOffset(L.StepW, L.StepW),
		function() MarketWindow.SellCount(-1) end, { Name = "Less", LayoutOrder = 1 })
	label(counts, tx(TXT, "Of", n, entry.Count), L.Size.Body, colorOf("Text"), { Name = "Count", LayoutOrder = 2,
		Size = UDim2.new(1, -(2 * L.StepW + L.AllW + 18), 1, 0), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
		Style = "Number" })
	local more = capsule(counts, tx(TXT, "More"), kit.Palette.Button, UDim2.fromOffset(L.StepW, L.StepW),
		function() MarketWindow.SellCount(1) end, { Name = "More", LayoutOrder = 3 })
	local all = capsule(counts, tx(TXT, "All"), kit.Palette.Button, UDim2.fromOffset(L.AllW, L.StepW),
		function() MarketWindow.SellCount("All") end, { Name = "All", LayoutOrder = 4 })
	kit.SetEnabled(less, n > 1)
	kit.SetEnabled(more, n < entry.Count)
	kit.SetEnabled(all, n < entry.Count)
	-- the price: numbers only, clamped to Min..Max (Ref at first)
	local price = sellPrice()
	local _, tb = inputBox(det, "PriceBox", price and tostring(price) or "", tx(TXT, "Price"), { Size = UDim2.new(1, 0, 0, L.SearchH),
		LayoutOrder = nextOrder() })
	VIEW.PriceBox = tb
	tb:GetPropertyChangedSignal("Text"):Connect(function()
		local digits = (string.gsub(tb.Text, "%D", ""))
		if #digits > L.MaxDigits then digits = string.sub(digits, 1, L.MaxDigits) end
		if digits ~= tb.Text then
			tb.Text = digits
			return
		end
		S.SellPrice = tonumber(digits)
		updateYou()
	end)
	tb.Focused:Connect(function() VIEW.Focus = true end)
	tb.FocusLost:Connect(function()
		VIEW.Focus = false
		local p = sellPrice()
		if p then
			S.SellPrice = p
			tb.Text = tostring(p)
		end
		updateYou()
		if VIEW.Dirty and VIEW.Kit == kit then refreshParts() end
	end)
	local meta = S.Meta[S.SellKey]
	if meta and meta.Min and meta.Max then
		label(det, tx(TXT, "Range", money(meta.Min), money(meta.Max)), L.Size.Small, colorOf("Sub"), { Name = "Range",
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = nextOrder() })
	end
	VIEW.YouGet = label(det, "", L.Size.Body, colorOf("Gold"), { Name = "YouGet", Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder() })
	updateYou()
	local text, enabled = listState(price)
	local lb = capsule(det, text, kit.Palette.Buy or kit.Palette.Button, UDim2.new(1, 0, 0, L.BtnH), function() MarketWindow.List() end,
		{ Name = "List", LayoutOrder = nextOrder() })
	kit.SetEnabled(lb, enabled)
	if not S.Pending and S.Gate.List == "" and listWait() > 0 then
		table.insert(VIEW.Timers.Sell, function()
			local wait = listWait()
			if lb.Parent and wait > 0 then lb.Text = tx(TXT, "Wait", MarketWindow.TimeText(wait)) end
		end)
	end
end

local function buildSell(body)
	VIEW.List = scrollBox(body, "List", { Size = UDim2.new(0, L.LeftW, 1, 0) })
	listLayout(VIEW.List, 6, false)
	VIEW.Detail = scrollBox(body, "Detail", { Position = UDim2.fromOffset(L.LeftW + L.Split, 0),
		Size = UDim2.new(1, -(L.LeftW + L.Split), 1, 0), ScrollBarThickness = 4 })
end

---------------------------------------------------------------------------------------------------- Mine
local function mineRow(list, r, info, ctx, i)
	local kit = VIEW.Kit
	local row = plain(list, "Mine_" .. tostring(r.Id), { Size = UDim2.new(1, 0, 0, L.MineRowH), LayoutOrder = i })
	local z = (tonumber(row.ZIndex) or 1) + 1
	local slotBox = slot(row, info.Grade, info.Icon, L.RowSlot, "Slot", { Text = info.Name, Color = info.Color })
	slotBox.Position = UDim2.fromOffset(4, (L.MineRowH - L.RowSlot) / 2)
	local title = info.Title
	if info.Kind ~= "Weapon" and r.Plus > 0 then title = title .. " " .. tx(TXT, "Plus", r.Plus) end
	label(row, title, L.Size.Small, info.Color or colorOf("Text"), { Name = "Name", Position = UDim2.fromOffset(L.RowSlot + 12, 4),
		Size = UDim2.fromOffset(150, L.MineRowH - 8), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = z })
	label(row, tx(TXT, "Count", r.N), L.Size.Small, colorOf("Text"), { Name = "Count", Position = UDim2.fromOffset(218, 9),
		Size = UDim2.fromOffset(84, 18), TextWrapped = false, ZIndex = z, Style = false })
	-- artisan contract ⑤: a sold listing shows what I get (price - the market's cut), like "You get" when listing
	local shown = r.Price
	if r.State == "Sold" then shown = select(2, MarketWindow.Fee(r.Price)) end
	label(row, money(shown), L.Size.Small, colorOf("Gold"), { Name = "Price", Position = UDim2.fromOffset(218, 31),
		Size = UDim2.fromOffset(84, 18), TextWrapped = false, ZIndex = z, Style = false })
	local x = 310
	if r.State == "Open" then
		local left = r.Left
		local timeLabel = label(row, MarketWindow.TimeText(left - (os.clock() - r.At)), L.Size.Small, colorOf("Sub"), { Name = "Left",
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(56, 22), TextWrapped = false,
			ZIndex = z, Style = false })
		table.insert(VIEW.Timers.Mine, function(now)
			if timeLabel.Parent then timeLabel.Text = MarketWindow.TimeText(left - (now - r.At)) end
		end)
		local p = S.Pending
		local text = (p and p.Name == "MarketCancel" and p.Id == r.Id) and tx(TXT, "Checking") or tx(TXT, "Cancel")
		local id = r.Id
		local b = capsule(row, text, kit.Palette.Button, UDim2.fromOffset(L.CancelW, 36), function() MarketWindow.Cancel(id) end,
			{ Name = "Cancel", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
		kit.SetEnabled(b, p == nil and not gapOn("MarketCancel"))
	elseif r.State == "Sold" then
		label(row, tx(TXT, "Sold"), L.Size.Small, colorOf("Good"), { Name = "State", Position = UDim2.fromOffset(x, 9),
			Size = UDim2.fromOffset(190, 18), TextWrapped = false, ZIndex = z, Style = false })
		label(row, tx(TXT, r.Paid and "Paid" or "Paying"), L.Size.Small, r.Paid and colorOf("Sub") or colorOf("Gold"), { Name = "Paid",
			Position = UDim2.fromOffset(x, 31), Size = UDim2.fromOffset(190, 18), TextWrapped = false, ZIndex = z, Style = false })
	else -- Expired / Cancel: the things are back
		label(row, tx(TXT, "Back"), L.Size.Small, colorOf("Sub"), { Name = "State", AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, x, 0.5, 0), Size = UDim2.fromOffset(190, 40), ZIndex = z })
	end
end

local function drawMine(ctx)
	local list = VIEW.MineList
	if not (list and list.Parent) then return end
	local keptY = list.CanvasPosition.Y
	clear(list)
	VIEW.Timers.Mine = {}
	local mine = S.Mine
	if not mine then
		middleLine(list, tx(TXT, "Checking"))
		return
	end
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	if mine.Today then
		label(list, tx(TXT, "Today", mine.Today.Lists, mine.Today.Buys), L.Size.Small, colorOf("Sub"), { Name = "Today",
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() })
	end
	for i = 1, math.min(mine.Waiting, L.MaxWaiting) do
		label(list, tx(TXT, "Checking"), L.Size.Body, colorOf("Gold"), { Name = "Waiting" .. i, Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = nextOrder(), TextWrapped = false })
	end
	local shown = 0
	for _, r in mine.Rows do
		local info = MarketWindow.KeyInfo(r.Key, ctx)
		if info then
			shown += 1
			mineRow(list, r, info, ctx, nextOrder())
		end
		if r.State == "Sold" and S.Tab == "Mine" then S.SeenSold[r.Id] = true end -- I looked at it
	end
	if shown == 0 and mine.Waiting == 0 then
		middleLine(list, tx(TXT, "Empty"))
	end
	list.CanvasPosition = Vector2.new(0, keptY)
end

local function buildMine(body)
	VIEW.MineList = scrollBox(body, "Mine", { Size = UDim2.fromScale(1, 1) })
	listLayout(VIEW.MineList, 6, false)
end

---------------------------------------------------------------------------------------------------- the window
local function soldNew()
	local n = 0
	for _, r in S.Mine and S.Mine.Rows or {} do
		if r.State == "Sold" and not S.SeenSold[r.Id] then n += 1 end
	end
	return n
end

-- the tabs (the Panels capsules, gold = open: the bag's look) and a dot on Mine for a sale I have not looked at
local function paintTabs()
	local kit = VIEW.Kit
	if not (kit and VIEW.Tabs) then return end
	for _, id in L.Tabs do
		local b = VIEW.Tabs[id]
		if b then
			local on = S.Tab == id
			kit.Paint(b, on and kit.Theme.Gold or kit.Palette.Button, on and kit.Palette.DarkText or kit.Theme.Text)
			local old = b:FindFirstChild("NewCount")
			if old then old:Destroy() end
			local n = (id == "Mine" and not on) and soldNew() or 0
			if n > 0 then
				local dot = ui().ArtImage("BadgeDot", { Name = "NewCount", AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(24, 24), ZIndex = (tonumber(b.ZIndex) or 1) + 3 })
				if dot then
					label(dot, tostring(n), 15, Color3.new(1, 1, 1), { Name = "N", Size = UDim2.fromScale(1, 1),
						TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = dot.ZIndex + 1, Style = "Number" })
					dot.Parent = b
				end
			end
		end
	end
end

local function drawBottom()
	local bottom = VIEW.Bottom
	if not bottom then return end
	clear(bottom)
	coinLine(bottom, Util.FormatInt(goldNow()), colorOf("Gold"))
end

-- what the open window shows depends on (the update redraws the parts when it changes)
local function sigOf(ctx)
	local p = S.Pending
	local parts = { S.Tab, S.Kind, tostring(S.BuyKey), S.BuyPage, tostring(S.SellKey), S.SellN, S.IndexVer, S.PageVer, S.MineVer,
		ctx.Class, ctx.Faction, ctx.Mask, ctx.Equipped, p and (p.Name .. tostring(p.Id)) or "-", tostring(gapOn("MarketBuy")),
		tostring(gapOn("MarketList")), tostring(gapOn("MarketCancel")), tostring(listWait() > 0), S.Gate.Buy, S.Gate.List }
	for _, e in MarketWindow.SellEntries(ctx) do
		table.insert(parts, e.Key .. "=" .. e.Count)
	end
	return table.concat(parts, "|")
end

-- the data zones of the open tab again (a payload, a click, an inventory change, an interval that ran out)
function refreshParts()
	local body = VIEW.Body
	if not (VIEW.Kit and body and body.Parent) then return end
	if VIEW.Resting ~= resting() then
		redraw()
		return
	end
	if not VIEW.Resting then
		local ctx = context()
		if S.Tab == "Buy" then
			drawIndex(ctx)
			drawPage(ctx)
		elseif S.Tab == "Sell" then
			drawSellList(ctx)
			drawSellDetail(ctx)
		else
			drawMine(ctx)
		end
	end
	paintTabs()
	drawBottom()
	VIEW.Sig = sigOf(context())
end

-- the tab's own layout again (a tab / kind change, the market waking up or resting)
function redraw()
	local body = VIEW.Body
	if not (VIEW.Kit and body and body.Parent) then return end
	clear(body)
	VIEW.IndexList, VIEW.Right, VIEW.Search, VIEW.List, VIEW.Detail, VIEW.MineList = nil, nil, nil, nil, nil, nil
	VIEW.PriceBox, VIEW.YouGet, VIEW.Focus, VIEW.Dirty = nil, nil, false, false
	VIEW.Timers = { Page = {}, Sell = {}, Mine = {} }
	VIEW.Resting = resting()
	if VIEW.Resting then
		middleLine(body, noteText("Resting"))
	elseif S.Tab == "Buy" then
		buildBuy(body)
	elseif S.Tab == "Sell" then
		buildSell(body)
	else
		buildMine(body)
	end
	refreshParts()
end

---------------------------------------------------------------------------------------------------- actions
function MarketWindow.ShowTab(id)
	if not table.find(L.Tabs, id) or not VIEW.Kit then return end
	S.Tab = id
	if id == "Buy" then S.WantIndex = true end
	wantOpenPage()
	redraw()
	MarketWindow.Pump()
end

function MarketWindow.ShowKind(id)
	if not table.find(L.Kinds, id) or not VIEW.Kit then return end
	S.Kind, S.BuyKey, S.BuyPage = id, nil, 1
	redraw()
	MarketWindow.Pump()
end

function MarketWindow.PickBuy(key)
	if type(key) ~= "string" or not VIEW.Kit then return end
	S.BuyKey, S.BuyPage = key, 1
	wantOpenPage()
	refreshParts()
	MarketWindow.Pump()
end

-- ◀ / ▶ (delta -1 / 1) inside the picked key's Pages
function MarketWindow.Page(delta)
	local entry = pageEntry(S.BuyKey, S.BuyPage)
	if not entry or not VIEW.Kit then return end
	local page = math.clamp(S.BuyPage + (delta < 0 and -1 or 1), 1, entry.Pages)
	if page == S.BuyPage then return end
	S.BuyPage = page
	wantOpenPage()
	refreshParts()
	MarketWindow.Pump()
end

function MarketWindow.PickSell(key)
	if type(key) ~= "string" or not VIEW.Kit then return end
	S.SellKey, S.SellN, S.SellPrice = key, 1, nil
	VIEW.Focus = false
	wantOpenPage()
	refreshParts()
	MarketWindow.Pump()
end

-- how many to list: -1 / 1 or "All"
function MarketWindow.SellCount(how)
	local entry = sellEntry(context())
	if not entry or not VIEW.Kit then return end
	if how == "All" then
		S.SellN = entry.Count
	else
		S.SellN = math.clamp(S.SellN + (num(how, 0) < 0 and -1 or 1), 1, entry.Count)
	end
	VIEW.Focus = false
	refreshParts()
end

-- [Buy]: MarketBuy(id, price) with the price I saw, once (one request at a time; the server checks the price again)
function MarketWindow.Buy(id, price)
	if not (VIEW.Kit and MarketWindow.On()) then return false end
	local ctx = context()
	local info = S.BuyKey and MarketWindow.KeyInfo(S.BuyKey, ctx) or nil
	local entry = pageEntry(S.BuyKey, S.BuyPage)
	local row = nil
	for _, r in entry and entry.Rows or {} do
		if r.Id == id then row = r end
	end
	if not (row and info and row.Price == price) then return false end
	local _, enabled = buyState(row, info, ctx)
	if not enabled or not send("MarketBuy", row.Id, row.Price) then return false end
	S.Pending = { Name = "MarketBuy", Id = row.Id, At = os.clock() }
	refreshParts()
	return true
end

-- [List]: MarketList(kind, id, n, price): "I" + the item id, "W" + the spare key "T:P"
function MarketWindow.List()
	if not (VIEW.Kit and MarketWindow.On()) then return false end
	local entry = sellEntry(context())
	local price = sellPrice()
	if not entry then return false end
	local _, enabled = listState(price)
	if not enabled then return false end
	local n = math.clamp(S.SellN, 1, entry.Count)
	local kind, id = "I", entry.Info.Id
	if entry.Info.Kind == "Weapon" then kind, id = "W", entry.Info.Spare end
	if not send("MarketList", kind, id, n, price) then return false end
	S.Pending = { Name = "MarketList", Id = entry.Key, At = os.clock() }
	refreshParts()
	return true
end

-- [Cancel] on an Open row: MarketCancel(id)
function MarketWindow.Cancel(id)
	if not (VIEW.Kit and MarketWindow.On()) or S.Pending or gapOn("MarketCancel") then return false end
	local row = nil
	for _, r in S.Mine and S.Mine.Rows or {} do
		if r.Id == id and r.State == "Open" then row = r end
	end
	if not row or not send("MarketCancel", row.Id) then return false end
	S.Pending = { Name = "MarketCancel", Id = row.Id, At = os.clock() }
	refreshParts()
	return true
end

---------------------------------------------------------------------------------------------------- Panels
-- attributes that redraw the open window (the gold line only for the gold)
MarketWindow.Watched = { Class = true, Faction = true, WeaponOwnedMask = true, WeaponTier = true }
MarketWindow.WatchedGold = { BankGold = true, CarriedGold = true }

local function build(parent, kit, arg)
	VIEW = { Kit = kit, Parent = parent, Tabs = {}, Timers = { Page = {}, Sell = {}, Mine = {} } }
	if not MarketWindow.On() then return nil end -- off: nothing at all
	-- Panels hands every rebuild the arg of its last Open: one arg table is applied once (a rebuild keeps my tab)
	if arg == S.LastArg then arg = nil else S.LastArg = arg end
	if type(arg) == "table" and table.find(L.Tabs, arg.Tab) then S.Tab = arg.Tab end
	local bar = plain(parent, "Tabs", { Size = UDim2.new(1, 0, 0, L.TabH) })
	listLayout(bar, 6, false, true)
	local n = #L.Tabs
	for i, id in L.Tabs do
		local b = kit.Button(bar, tx(TXT.Tabs, id), kit.Palette.Button, UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), function()
			MarketWindow.ShowTab(id)
		end)
		b.Name = "Tab_" .. id
		b.LayoutOrder = i
		VIEW.Tabs[id] = b
	end
	VIEW.Body = plain(parent, "Body", { Position = UDim2.fromOffset(0, L.TabH + L.RowGap),
		Size = UDim2.new(1, 0, 1, -(L.TabH + L.BarH + 2 * L.RowGap)) })
	VIEW.Bottom = plain(parent, "Bottom", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, L.BarH) })
	kit.OnAttr(function(name)
		local gold = MarketWindow.WatchedGold[name]
		if not (gold or MarketWindow.Watched[name]) or VIEW.Queued then return end
		VIEW.Queued = true
		task.defer(function()
			VIEW.Queued = false
			if VIEW.Kit ~= kit then return end
			if gold then drawBottom() else refreshParts() end
		end)
	end)
	S.WantMine, S.WantIndex = true, true
	redraw()
	MarketWindow.Pump()
	-- Panels' 0.25 s update: the requests the intervals allow, the clocks, and what changed (inventory, intervals)
	return function()
		if VIEW.Kit ~= kit then return end
		MarketWindow.Pump()
		if VIEW.Resting ~= resting() then
			redraw()
		elseif sigOf(context()) ~= VIEW.Sig then
			refreshParts()
		end
		tickTimers()
	end
end

local function cleanup()
	VIEW = {}
end

local function hook(name, fn)
	local function on(r)
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(fn, payload)
			if not ok then Util.Warn(TAG, name .. ": " .. tostring(err)) end
		end)
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local r = folder and folder:FindFirstChild(name)
	if r and r:IsA("RemoteEvent") then
		on(r)
		return
	end
	task.spawn(function()
		local f = ReplicatedStorage:WaitForChild("Remotes", 60)
		local rr = f and f:WaitForChild(name, 60)
		if rr and rr:IsA("RemoteEvent") then on(rr) end -- no remote = the market server is not in this game
	end)
end

function MarketWindow.IsReady()
	return S.Ready
end

-- opens the window (on a tab: "Buy" | "Sell" | "Mine"); nothing while the switch is off
function MarketWindow.Open(tab)
	if not MarketWindow.On() then return end
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Open) ~= "function" then return end
	panels.Open(L.Window, type(tab) == "string" and { Tab = tab } or nil)
end

function MarketWindow.Init(registry)
	C = registry
	hook("MarketIndex", MarketWindow.OnIndex) -- before any Start: a push is never missed
	hook("MarketPage", MarketWindow.OnPage)
	hook("MarketMine", MarketWindow.OnMine)
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the market window is off")
		return
	end
	S.Ready = panels.Register(L.Window, {
		Build = build,
		Title = function() return tx(TXT, "Title") end,
		FixedBody = true,
		Rebuild = false,
		Width = function() return L.Width end,
		Menu = function() return MarketWindow.On() and tx(TXT, "Menu") or nil end,
		Cleanup = cleanup,
	}) == true
end

function MarketWindow.Start()
	S.Started = true
end

-- offline tests
MarketWindow._T = { TXT = TXT, L = L, S = S, View = function() return VIEW end }

return MarketWindow
