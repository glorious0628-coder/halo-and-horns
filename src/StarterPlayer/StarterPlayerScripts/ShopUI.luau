-- ShopUI.luau : the Robux shop (SPEC A23-75, user 2026-10-08: 2x XP · 2x Gold · VIP passes, halo / horn looks and the
-- private server, prices "추천 가격대로") as the Panels window "Shop", added through Panels.Register (BB13). It takes
-- the old change-ticket shop's id (A23-28: no change tickets in the beta - 최종 검수 10/14 removed their rows).
-- Layout (이미지 개발 2026-10-08; one list for PC and phones, the window scrolls when the screen is short):
--   Passes - six cards, three a row (plan 10/13 §1-A #6: + the Sticker Pack and the Bubble Pack, A23-143 / A23-144; a
--     locked sticker / bubble opens the Shop with { Focus = kind }: that card wears a gold rim).
--     The words are Config.PassInfo (the card lines, Screen = this window's words; the VIP emote is not promised -
--     it is not built). The live switch PassSales (GameState SwitchPassSales = false) dims every [Buy] to "Not on sale"
--     (owned passes and looks keep working). A card is one tap target (the navy PanelCard plate): the icon in a rim slot (VIP = SlotLegendary's
--     crown rim, Private Server = SlotRare, the boosts = RewardSlot), the name, up to three short lines and a capsule
--     at the bottom - gold "199 R$" = buy, green "Owned", dimmed "Coming soon" while the pass id is 0 (A23-75).
--     Roblox's own dialog confirms every purchase. The private server is sold on the game page only (Roblox has no
--     in-game prompt for it), so its card says where to get it.
--   Looks - my side's halo / horn looks (Config.Looks; no side or Neutral: all of them) as rim tiles with a capsule:
--     price / Wear / Wearing (tap again = take it off, through the SetLook remote once it exists). 검수 2026-10-08: the
--     section shows once looks are picked and listed (no "coming soon" teaser before that).
--   A soft last line: ask a grown-up first. No timers, no "best value" badges, no pop-ups (A23-75: no pressure).
-- Server (게임성 개발 2, docs/design/gamepass_server_2026-10-08.md): Config.GamePasses[Kind] = { Id, Price, Attr } and
-- the player attributes it sets after UserOwnsGamePassAsync (PassXP2 · PassGold2 · PassVIP, LooksOwned "a,b",
-- LookOn). Until that lands the A23-75 prices and these proposed names stand in (ids 0 = "Coming soon").
-- Studio only: LocalPlayer attribute ShopPreview = true shows the picked looks (layout photos).
-- Also here (A23-75 screens): the VIP crown on name tags is fitted on each client (CROWN below).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local ShopUI = {}
local TAG = "ShopUI"
local C = nil
local player = Players.LocalPlayer

-- the pass cards, left to right (Price = the A23-75 price; Config.GamePasses[Kind] overrides Id / Price / Attr).
-- Badge = the picked round pass badge (A23-75 "둥근 배지 B", 이미지 생성 2): once its Config.UIArt key has an id the
-- card shows it alone (it has its own rim); until then the stand-in Icon sits in the Slot rim
local PASSES = {
	{ Kind = "XP2", Badge = "IconPassXP2", Icon = "IconExp", Slot = "RewardSlot", Price = 199, Attr = "PassXP2" },
	{ Kind = "Gold2", Badge = "IconPassGold2", Icon = "IconGoldPile", Slot = "RewardSlot", Price = 149, Attr = "PassGold2" },
	{ Kind = "VIP", Badge = "IconPassVIP", Icon = "Crown", Slot = "SlotLegendary", Price = 249, Attr = "PassVIP" },
	-- plan 10/13 §1-A #6 (A23-143 / A23-144): approved art stands in until a pass badge is drawn (a sticker, a speech bubble)
	{ Kind = "Stickers", Badge = "IconPassStickers", Icon = "EmoHeart", Slot = "RewardSlot", Price = 99, Attr = "PassStickers" },
	{ Kind = "Bubbles", Badge = "IconPassBubbles", Icon = "BarkBubble", Slot = "RewardSlot", Price = 99, Attr = "PassBubbles" },
	{ Kind = "PrivateServer", Badge = "IconPrivateServer", Icon = "IconTravel", Slot = "SlotRare", Price = 100, Info = true },
}

-- English only (A23-48), short words for kids (glossary 2026-10-06): Config.PassInfo (plan 10/13 §1-A #6)
local INFO = type(Config.PassInfo) == "table" and Config.PassInfo or {}
local T = type(INFO.Screen) == "table" and INFO.Screen or {}

-- layout in canvas du (Panels' phone UIScale 0.75: 100 du = 75 px). Card = Pad · Slot · name · three lines · capsule ·
-- Pad. Text floors are real px (Roblox applies UITextSizeConstraint after UIScale, UiSandbox 2026-10-08): the lines'
-- StyleMinPx 11 renders 15 px on phones (rubric >= 14) and 14 px on a 720p PC - the Body floor (19 px on phones) wrapped
-- 'Crown name tag, VIP chat and emote.' into four lines. Plan 10/13: six cards three a row (Slot 92 -> 70, CardH 266 ->
-- 251: both rows fit a 720p PC window without scrolling; phones scroll to the second row - tools/test_shop_layout.py)
local L = {
	Cols = 3, Gap = 10, CardH = 251, Pad = 10, Slot = 70, Icon = 0.62, NameH = 28, NameSize = 22, NameMinPx = 12,
	LinesMinPx = 11,
	LineSize = 15, CapsH = 40, CapsSize = 22, LookCols = 4, LookH = 178, LookSlot = 84, HeadH = 30, HeadSize = 20,
	Guard = 0.35, -- s: a fast second tap on the [메뉴] square must not land on a card (CR-L26)
	Focus = { Color = Color3.fromRGB(255, 210, 60), Thickness = 3 }, -- the asked card's rim ({ Focus = kind })
}
-- Studio-only sample looks for the layout photos: the four the user picked (A23-75, 2026-10-08: halo Ice · Gold,
-- horns Lava · Shadow; ids 0 = "Coming soon", the pictures are stand-ins until their badges are drawn)
local SAMPLE_LOOKS = {
	HaloIce = { Faction = "Halo", Name = "Ice Halo", Price = 99, Order = 1 }, -- ids = Config.LookThemes (icons Look..id)
	HaloGold = { Faction = "Halo", Name = "Gold Halo", Price = 99, Order = 2 },
	HornsLava = { Faction = "Horns", Name = "Lava Horns", Price = 99, Order = 1 },
	HornsShadow = { Faction = "Horns", Name = "Shadow Horns", Price = 99, Order = 2 },
}

------------------------------------------------------------------ helpers
local function uikit()
	local u = C and C.UIKit
	return type(u) == "table" and u or nil
end

local function attrOf(name, default)
	local v = player:GetAttribute(name)
	if v == nil then return default end
	return v
end

-- one pass's live numbers: Config.GamePasses[Kind] (게임성 개발 2) over the A23-75 stand-ins
-- 2-C #10 (최종 검수 10/14): the card prices are Roblox's own - MarketplaceService:GetProductInfo(id, infoType)
-- .PriceInRobux (regional prices and sales: the same number as the buy window). Read once per id in the background
-- (pcall), cached for the session; until then, on a failure, without a price (not for sale) or with id 0: the Config
-- price. A new price repaints the open shop (PRICE.Refresh). fetch(id, infoType) -> info is for the offline test.
local PRICE = { Cache = {}, Busy = {}, Refresh = nil, Fetch = nil, SubFetch = nil }
-- one background read per key: call() -> info (pcall), read(info) -> the price or nil (nil / a failure is remembered as
-- false = the fallback from then on); the first answer repaints the open shop
function PRICE.Ask(key, fallback, call, read)
	local v = PRICE.Cache[key]
	if v ~= nil then return v == false and fallback or v end
	if not PRICE.Busy[key] then
		PRICE.Busy[key] = true
		task.spawn(function()
			local ok, price = pcall(function()
				local info = call()
				return type(info) == "table" and read(info) or nil
			end)
			PRICE.Cache[key] = (ok and price ~= nil) and price or false
			PRICE.Busy[key] = nil
			if PRICE.Refresh then pcall(PRICE.Refresh) end
		end)
	end
	return fallback
end
function ShopUI.LivePrice(id, infoType, fallback, fetch)
	id = math.floor(tonumber(id) or 0)
	if id <= 0 then return fallback end
	local get = fetch or PRICE.Fetch or function(i, t) return MarketplaceService:GetProductInfo(i, t) end
	return PRICE.Ask(tostring(infoType) .. ":" .. id, fallback, function() return get(id, infoType) end, function(info)
		local price = tonumber(info.PriceInRobux)
		return (price and price >= 0) and math.floor(price) or nil
	end)
end
-- A23-182 subscription card: GetSubscriptionProductInfoAsync("EXP-...") the same way -> Roblox's own price text
-- (DisplayPrice, the player's local money) or a PriceInRobux number; id "" / failure / neither = the Config R$ price
function ShopUI.SubPrice(id, fallback, fetch)
	if type(id) ~= "string" or id == "" or id == "0" then return fallback end
	local get = fetch or PRICE.SubFetch or function(i) return MarketplaceService:GetSubscriptionProductInfoAsync(i) end
	return PRICE.Ask("Sub:" .. id, fallback, function() return get(id) end, function(info)
		if type(info.DisplayPrice) == "string" and info.DisplayPrice ~= "" then return info.DisplayPrice end
		local robux = tonumber(info.PriceInRobux)
		return (robux and robux >= 0) and math.floor(robux) or nil
	end)
end
ShopUI._PRICE = PRICE -- tools/test_shop_price.py

local function passDef(p)
	local all = type(Config.GamePasses) == "table" and Config.GamePasses or {}
	local cfg = type(all[p.Kind]) == "table" and all[p.Kind] or {}
	return {
		Id = math.floor(tonumber(cfg.Id) or 0),
		Price = ShopUI.LivePrice(cfg.Id, Enum.InfoType.GamePass, tonumber(cfg.Price) or tonumber(cfg.PriceHint) or p.Price),
		Attr = type(cfg.Attr) == "string" and cfg.Attr or p.Attr,
	}
end

-- a pass card's name (Config.GamePasses[kind].Name; the private server = Screen.PrivateName) and its line
-- (Config.PassInfo[kind].Line; the private server card adds Config.PrivateServer.Text, A23-90: rewards are halved there)
local function passName(p)
	if p.Info then return T.PrivateName or p.Kind end
	local cfg = type(Config.GamePasses) == "table" and Config.GamePasses[p.Kind] or nil
	return type(cfg) == "table" and type(cfg.Name) == "string" and cfg.Name or p.Kind
end

local function passLine(p)
	local row = INFO[p.Kind]
	local line = type(row) == "table" and type(row.Line) == "string" and row.Line or nil
	local ps = Config.PrivateServer
	if p.Info and type(ps) == "table" and type(ps.Text) == "string" and ps.Text ~= "" then
		line = line and (line .. "\n" .. ps.Text) or ps.Text
	end
	return line
end

-- the live switch PassSales (SwitchService -> GameState SwitchPassSales): false = no [Buy] (nil = not sent yet = on)
local function salesOn()
	local gs = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
	return not (gs and gs:GetAttribute("SwitchPassSales") == false)
end

local function myFaction()
	local f = attrOf("Faction", "None")
	return type(f) == "string" and f or "None"
end

local function ownsLook(id)
	local owned = attrOf("LooksOwned", "")
	return type(owned) == "string" and table.find(string.split(owned, ","), id) ~= nil
end

-- the looks to show, in order: my side's (Halo / Horns), else every side's. A look with Unlock (A23-77 attendance:
-- Sprout 14 · Starlight 50 · Platinum 100 days) is never sold - it shows here only once owned, to wear it
local function lookList()
	local defs = Config.Looks
	if RunService:IsStudio() and attrOf("ShopPreview", false) == true then defs = SAMPLE_LOOKS end
	local mine = myFaction()
	local list = {}
	for id, def in (type(defs) == "table" and defs or {}) do
		if type(def) == "table" and (mine ~= "Halo" and mine ~= "Horns" or def.Faction == mine)
			and (def.Unlock == nil or ownsLook(id)) then
			table.insert(list, { Id = id, Def = def })
		end
	end
	table.sort(list, function(a, b)
		local fa, fb = tostring(a.Def.Faction), tostring(b.Def.Faction)
		if fa ~= fb then return fa < fb end
		local oa, ob = tonumber(a.Def.Order) or 99, tonumber(b.Def.Order) or 99
		if oa ~= ob then return oa < ob end
		return a.Id < b.Id
	end)
	return list
end


local function hasRemote(name)
	return type(Net.Names) == "table" and table.find(Net.Names, name) ~= nil
end

-- A23-79 beta metrics (ComeBack.Metric, dev1): PassView when the cards show, PurchasePrompt before Roblox's buy window;
-- the pass argument is the Config.Analytics.PassIds kind (XP2 / Gold2 / VIP / Look)
local function metric(id, arg)
	local cb = C and C.ComeBack
	if type(cb) == "table" and type(cb.Metric) == "function" then pcall(cb.Metric, id, arg) end
end

-- A23-182 (user 10/14, 정정: Fast Travel = a monthly subscription): the subscription cards under the passes, one a row of
-- Config.SubscriptionInfo (game dev 2: { [kind] = { Id = "EXP-…", Name, Line, Price, Attr?, Icon? } }) whose Id is a real
-- subscription id ("" / 0 = no card); a tap = MarketplaceService:PromptSubscriptionPurchase; Attr (default "Sub"..kind,
-- e.g. SubFastTravel, set by the server) = subscribed. Pure (tools/test_fast_travel_ui.py)
function ShopUI.SubCards()
	local all = type(Config.SubscriptionInfo) == "table" and Config.SubscriptionInfo or {}
	local out = {}
	for kind, d in all do
		if type(kind) == "string" and type(d) == "table" and type(d.Id) == "string" and d.Id ~= "" and d.Id ~= "0"
			and type(d.Name) == "string" then
			table.insert(out, { Kind = kind, Id = d.Id, Name = d.Name, Line = type(d.Line) == "string" and d.Line or nil,
				Price = tonumber(d.Price) or 0, Attr = type(d.Attr) == "string" and d.Attr or ("Sub" .. kind),
				Icon = type(d.Icon) == "string" and d.Icon or "IconTravel" })
		end
	end
	table.sort(out, function(a, b) return a.Kind < b.Kind end)
	return out
end

local function promptSub(id, kind)
	metric("PurchasePrompt", kind)
	local ok, err = pcall(MarketplaceService.PromptSubscriptionPurchase, MarketplaceService, player, id)
	if not ok then Util.Warn(TAG, "PromptSubscriptionPurchase failed: " .. tostring(err)) end
end

local function prompt(id, kind)
	metric("PurchasePrompt", kind)
	local ok, err = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, id)
	if not ok then Util.Warn(TAG, "PromptGamePassPurchase failed: " .. tostring(err)) end
end

local function playClick()
	local fx = C and C.Fx
	if type(fx) == "table" and type(fx.PlaySound) == "function" then pcall(fx.PlaySound, "Click") end
end

-- a rim slot with an icon centred in it (the code fallback: a navy rounded square with a gold rim, IMG-R4)
local function rimSlot(u, part, icon, props)
	local slot = u.ArtImage(part, props)
	if not slot then
		slot = Instance.new("Frame")
		slot.Name, slot.AnchorPoint, slot.Position, slot.Size = props.Name, props.AnchorPoint, props.Position, props.Size
		slot.BorderSizePixel = 0
		slot.BackgroundColor3 = Color3.fromRGB(22, 32, 70)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.18, 0)
		c.Parent = slot
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(255, 210, 60)
		st.Thickness = 2
		st.Parent = slot
		slot.Parent = props.Parent
	end
	u.ArtImage(icon, {
		Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(L.Icon, L.Icon), ScaleType = Enum.ScaleType.Fit, Parent = slot,
	})
	return slot
end

-- a pass card's picture: the round badge alone once it is uploaded, else the stand-in icon in its rim slot
local function passArt(u, p, props)
	if p.Badge and u.ArtId(p.Badge) then
		local badge = u.ArtImage(p.Badge, props)
		if badge then return badge end
	end
	return rimSlot(u, p.Slot, p.Icon, props)
end

-- a whole-card tap target: the PanelCard plate, the press feel, the click sound; `onTap` after the open guard
local function cardButton(u, kit, parent, name, onTap, openedAt)
	local card = Instance.new("TextButton")
	card.Name = name
	card.Text = ""
	card.AutoButtonColor = false
	card.BackgroundTransparency = 1
	card.BorderSizePixel = 0
	card.LayoutOrder = kit.NextOrder()
	card.Parent = parent
	u.ArtFrame("PanelCard", { Name = "Plate", Size = UDim2.fromScale(1, 1), ZIndex = 0, Parent = card },
		{ BackgroundColor3 = kit.Theme.Bg, CornerRadius = UDim.new(0, 14), StrokeColor = kit.Theme.Gold,
			StrokeThickness = 2, StrokeTransparency = 0.3 })
	if type(u.ButtonFeel) == "function" then pcall(u.ButtonFeel, card) end
	card.Activated:Connect(function()
		if os.clock() < openedAt + L.Guard then return end
		playClick()
		local ok, err = pcall(onTap)
		if not ok then Util.Warn(TAG, "card tap failed: " .. tostring(err)) end
	end)
	return card
end

-- a grid frame that grows with its cells (cell height fixed, width = 1 / cols of the row)
local function grid(kit, parent, name, cols, cellH, count)
	local rows = math.max(1, math.ceil(count / cols))
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, rows * cellH + (rows - 1) * L.Gap)
	f.LayoutOrder = kit.NextOrder()
	local g = Instance.new("UIGridLayout")
	-- 1 du short of the exact share: whole-pixel cells must not add up past the row (UiSandbox 2026-10-08: the 4th card
	-- wrapped to a hidden second row on every screen)
	g.CellSize = UDim2.new(1 / cols, -L.Gap * (cols - 1) / cols - 1, 0, cellH)
	g.FillDirectionMaxCells = cols
	g.CellPadding = UDim2.fromOffset(L.Gap, L.Gap)
	g.FillDirection = Enum.FillDirection.Horizontal
	g.HorizontalAlignment = Enum.HorizontalAlignment.Center
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = f
	f.Parent = parent
	return f
end

-- a section title; `badge` = a Config.UIArt key drawn left of the words once it has an id (the looks badge)
local function header(u, kit, parent, text, badge)
	local label = u.StyledLabel({
		Name = "Header", Text = text, Size = UDim2.new(1, 0, 0, L.HeadH), TextSize = L.HeadSize,
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = kit.NextOrder(), Parent = parent,
	}, "Title")
	if badge and u.ArtId(badge) then
		-- the label's UIPadding moves its children too: the badge goes back into the padded room (UiSandbox 2026-10-08:
		-- it sat on "Lo" of "Looks for Knights of Light")
		u.ArtImage(badge, { Name = "Badge", Position = UDim2.fromOffset(-(L.HeadH + 6), 0),
			Size = UDim2.fromOffset(L.HeadH, L.HeadH), Parent = label })
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, L.HeadH + 6)
		pad.Parent = label
	end
	return label
end

-- the words of a card / tile: the name (Title style, one line: a long name shrinks to L.NameMinPx instead of the
-- Title floor) and the lines (Body style, wrapped), both centred
local function cardWords(u, card, name, lines, top, linesH)
	local label = u.StyledLabel({
		Name = "Name", Text = name, Position = UDim2.fromOffset(4, top), Size = UDim2.new(1, -8, 0, L.NameH),
		TextSize = L.NameSize, TextScaled = true, Parent = card,
	}, "Title")
	label:SetAttribute("StyleMinPx", L.NameMinPx)
	local tc = label:FindFirstChildOfClass("UITextSizeConstraint")
	if tc then tc.MaxTextSize = L.NameSize end
	if not lines then return end
	local body = u.StyledLabel({
		Name = "Lines", Text = lines, Position = UDim2.fromOffset(L.Pad, top + L.NameH + 2),
		Size = UDim2.new(1, -2 * L.Pad, 0, linesH), TextSize = L.LineSize, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = card,
	}, "Body")
	body:SetAttribute("StyleMinPx", L.LinesMinPx)
end

-- the capsule at a card's bottom (a Panels button: gold Buy / green Free / blue default, dimmed when disabled); its
-- words run up to CapsSize (Panels buttons stop at 20 du = 15 px on phones; the price reads 16.5 px)
local function capsule(kit, card, onTap)
	local b = kit.Button(card, "", kit.Palette.Button, UDim2.new(1, -2 * L.Pad, 0, L.CapsH), onTap)
	b.TextSize = L.CapsSize
	local cap = b:FindFirstChildOfClass("UITextSizeConstraint")
	if cap and cap.MaxTextSize < L.CapsSize then cap.MaxTextSize = L.CapsSize end
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 1, -L.Pad)
	return b
end

-- the capsule's state: words, colour, enabled; repainted only when it changes
local function setCapsule(kit, cell, text, color, enabled)
	local key = text .. "|" .. tostring(color) .. "|" .. tostring(enabled)
	if cell.Key == key then return end
	cell.Key = key
	cell.Button.Text = text
	kit.Paint(cell.Button, color)
	kit.SetEnabled(cell.Button, enabled)
end

------------------------------------------------------------------ the window
local function tapPass(kit, p)
	local d = passDef(p)
	if p.Info then kit.Toast(T.ServerToast, "bad"); return end
	if d.Attr and attrOf(d.Attr, false) == true then kit.Toast(T.OwnedToast, "bad"); return end
	if d.Id <= 0 then kit.Toast(T.SoonToast, "bad"); return end
	if not salesOn() then kit.Toast(T.OffToast, "bad"); return end
	prompt(d.Id, p.Kind)
end

local function tapLook(kit, look)
	local id, def = look.Id, look.Def
	if ownsLook(id) then
		if not hasRemote("SetLook") then kit.Toast(T.SoonToast, "bad"); return end
		kit.Fire("SetLook", attrOf("LookOn", "") == id and "" or id) -- tap the worn one again = take it off
		return
	end
	local passId = math.floor(tonumber(def.PassId or def.Id) or 0)
	if passId <= 0 then kit.Toast(T.SoonToast, "bad"); return end
	if not salesOn() then kit.Toast(T.OffToast, "bad"); return end
	prompt(passId, "Look")
end

local function refreshPass(kit, cell)
	local p, d = cell.Pass, passDef(cell.Pass)
	if p.Info then
		setCapsule(kit, cell, string.format(T.MonthF, Util.FormatInt(d.Price)), kit.Palette.Button, true)
	elseif d.Attr and attrOf(d.Attr, false) == true then
		setCapsule(kit, cell, T.Owned, kit.Palette.Free, true)
	elseif d.Id <= 0 then
		setCapsule(kit, cell, T.Soon, kit.Palette.Button, false)
	elseif not salesOn() then
		setCapsule(kit, cell, T.Off, kit.Palette.Button, false)
	else
		setCapsule(kit, cell, string.format(T.PriceF, Util.FormatInt(d.Price)), kit.Palette.Buy, true)
	end
end

local function refreshLook(kit, cell)
	local id, def = cell.Look.Id, cell.Look.Def
	if ownsLook(id) then
		local on = attrOf("LookOn", "") == id
		setCapsule(kit, cell, on and T.Wearing or T.Wear, on and kit.Palette.Free or kit.Palette.Button, true)
	elseif math.floor(tonumber(def.PassId or def.Id) or 0) <= 0 then
		setCapsule(kit, cell, T.Soon, kit.Palette.Button, false)
	elseif not salesOn() then
		setCapsule(kit, cell, T.Off, kit.Palette.Button, false)
	else
		local price = ShopUI.LivePrice(def.PassId or def.Id, Enum.InfoType.GamePass, tonumber(def.Price) or 99)
		setCapsule(kit, cell, string.format(T.PriceF, Util.FormatInt(price)), kit.Palette.Buy, true)
	end
end

local function buildShop(parent, kit, arg)
	local u = uikit()
	local focus = type(arg) == "table" and arg.Focus or nil -- a locked sticker / bubble: its pass card (StickerUI)
	if not u then return nil end
	local openedAt = os.clock()
	local passCells, lookCells = {}, {}

	-- passes: four cards in one row
	local cards = grid(kit, parent, "Passes", L.Cols, L.CardH, #PASSES)
	local linesTop = L.Pad + L.Slot + 4
	local linesH = L.CardH - linesTop - L.NameH - 2 - 6 - L.CapsH - L.Pad
	for _, p in PASSES do
		local cell = { Pass = p }
		local card = cardButton(u, kit, cards, "Pass" .. p.Kind, function() tapPass(kit, p) end, openedAt)
		passArt(u, p, {
			Name = "Slot", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, L.Pad),
			Size = UDim2.fromOffset(L.Slot, L.Slot), ScaleType = Enum.ScaleType.Fit, Parent = card,
		})
		cardWords(u, card, passName(p), passLine(p), linesTop, linesH)
		if focus == p.Kind then
			local rim = Instance.new("UIStroke")
			rim.Name = "Focus"
			rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			rim.Color, rim.Thickness = L.Focus.Color, L.Focus.Thickness
			rim.Parent = card
		end
		cell.Button = capsule(kit, card, function()
			if os.clock() >= openedAt + L.Guard then tapPass(kit, p) end
		end)
		refreshPass(kit, cell)
		table.insert(passCells, cell)
		if not p.Info then metric("PassView", p.Kind) end -- one a kind per open (ComeBack keeps its own gap)
	end

	-- A23-182: the subscriptions (Fast Travel), one card each, under the passes
	local subCells = {}
	local subs = ShopUI.SubCards()
	if #subs > 0 then
		local scards = grid(kit, parent, "Subscriptions", L.Cols, L.CardH, #subs)
		for _, sd in subs do
			local function tapSub()
				if attrOf(sd.Attr, false) == true then kit.Toast(T.OwnedToast, "bad"); return end
				promptSub(sd.Id, sd.Kind)
			end
			local card = cardButton(u, kit, scards, "Sub" .. sd.Kind, tapSub, openedAt)
			rimSlot(u, "SlotRare", sd.Icon, {
				Name = "Slot", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, L.Pad),
				Size = UDim2.fromOffset(L.Slot, L.Slot), ScaleType = Enum.ScaleType.Fit, Parent = card,
			})
			cardWords(u, card, sd.Name, sd.Line, linesTop, linesH)
			local cell = { Sub = sd }
			cell.Button = capsule(kit, card, function()
				if os.clock() >= openedAt + L.Guard then tapSub() end
			end)
			table.insert(subCells, cell)
		end
	end
	local function refreshSubs()
		for _, cell in subCells do
			if attrOf(cell.Sub.Attr, false) == true then
				setCapsule(kit, cell, T.Owned, kit.Palette.Free, true)
			else
				local price = ShopUI.SubPrice(cell.Sub.Id, cell.Sub.Price) -- 2-C #10: Roblox's price (text or R$)
				local text = type(price) == "string" and string.format(T.MonthTextF, price)
					or string.format(T.MonthF, Util.FormatInt(price))
				setCapsule(kit, cell, text, kit.Palette.Buy, true)
			end
		end
	end
	refreshSubs()

	-- looks: my side's rim tiles (nothing while no look is listed yet)
	local looks = lookList()
	local mine = myFaction()
	local side = (mine == "Halo" or mine == "Horns") and Config.Factions[mine] or nil
	if #looks > 0 then
		metric("PassView", "Look")
		header(u, kit, parent, side and string.format(T.LooksSideF, tostring(side.Name)) or T.Looks, "IconPassLooks")
		local tiles = grid(kit, parent, "Looks", L.LookCols, L.LookH, #looks)
		for _, look in looks do
			local cell = { Look = look }
			local tile = cardButton(u, kit, tiles, "Look" .. look.Id, function() tapLook(kit, look) end, openedAt)
			-- the look's own icon (Config.Looks Icon, else the UIArt key 'Look'..id) once drawn, else my side's rank emblem
			local own = type(look.Def.Icon) == "string" and look.Def.Icon or ("Look" .. look.Id)
			local icon = u.ArtId(own) and own or (look.Def.Faction == "Horns" and "IconRankInfamy" or "IconRankHonor")
			rimSlot(u, "SlotEpic", icon, {
				Name = "Slot", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, L.Pad),
				Size = UDim2.fromOffset(L.LookSlot, L.LookSlot), ScaleType = Enum.ScaleType.Fit, Parent = tile,
			})
			cardWords(u, tile, tostring(look.Def.Name or look.Id), nil, L.Pad + L.LookSlot + 2, 0)
			cell.Button = capsule(kit, tile, function()
				if os.clock() >= openedAt + L.Guard then tapLook(kit, look) end
			end)
			refreshLook(kit, cell)
			table.insert(lookCells, cell)
		end
	end

	kit.Text(parent, T.Note, { Color = kit.Theme.SubText, Size = 15, Align = Enum.TextXAlignment.Center })

	local function refreshAll()
		for _, cell in passCells do refreshPass(kit, cell) end
		refreshSubs()
		for _, cell in lookCells do refreshLook(kit, cell) end
	end
	PRICE.Refresh = refreshAll -- 2-C #10: a price read later repaints this shop
	return refreshAll
end

------------------------------------------------------------------ VIP crown on name tags (A23-75)
-- The server adds VipCrown / VipPad to a VIP's nametag Line1 (CharacterVisuals, hidden); this client sizes and places
-- it from the name as it renders here: Height of the line's TextBounds (Denk One: about 0.8 of the letters), the art's
-- own width : height, Gap px before the first letter. The padding takes the crown's room, so crown + name stay one
-- centred group, and a long name that TextScaled shrinks takes the crown down with it.
local CROWN = { Height = 0.62, TitleK = 0.8, Gap = 3, Sweep = 1, Watched = setmetatable({}, { __mode = "k" }) }

-- A23-179 (review 10/14): the line's "[title]" is its own child label "Title" (translated; the name is not), placed
-- left of the crown (or of the name), its size from the name's rendered height; the pad takes both rooms
function CROWN.Fit(label)
	local crown, pad, title = label:FindFirstChild("VipCrown"), label:FindFirstChild("VipPad"), label:FindFirstChild("Title")
	if not (pad and pad:IsA("UIPadding")) then return end
	if crown and not crown:IsA("ImageLabel") then crown = nil end
	if title and not (title:IsA("TextLabel") and title.Text ~= "") then title = nil end
	if not (crown or title) then return end
	local tb = label.TextBounds
	if tb.X < 1 or tb.Y < 1 then return end
	local room, left = 0, math.floor(tb.X / 2 + CROWN.Gap + 0.5) -- left = px from the name's middle to the next piece
	if crown then
		local ch = math.max(6, math.floor(tb.Y * CROWN.Height + 0.5))
		local cw = math.floor(ch * (tonumber(crown:GetAttribute("Aspect")) or 1.46) + 0.5)
		local size = UDim2.fromOffset(cw, ch)
		-- the padded box's middle is the name's middle: half the name to the left, then the gap
		local pos = UDim2.new(0.5, -left, 0.5, -1)
		if crown.Size ~= size then crown.Size = size end
		if crown.Position ~= pos then crown.Position = pos end
		if not crown.Visible then crown.Visible = true end
		room += cw + CROWN.Gap
		left += cw + CROWN.Gap
	end
	if title then
		local ts = math.max(8, math.floor(tb.Y * CROWN.TitleK + 0.5))
		if title.TextSize ~= ts then title.TextSize = ts end
		local pos = UDim2.new(0.5, -left, 0.5, 0)
		if title.Position ~= pos then title.Position = pos end
		if not title.Visible then title.Visible = true end
		room += math.ceil(title.TextBounds.X) + CROWN.Gap
	end
	if pad.PaddingLeft.Offset ~= room then pad.PaddingLeft = UDim.new(0, room) end -- may re-scale the name: refit
end

function CROWN.Watch(label)
	if CROWN.Watched[label] then return end
	CROWN.Watched[label] = true
	local function fit()
		local ok, err = pcall(CROWN.Fit, label)
		if not ok then Util.Warn(TAG, "crown fit failed: " .. tostring(err)) end
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	label.ChildAdded:Connect(function(child)
		if child.Name == "VipCrown" or child.Name == "VipPad" or child.Name == "Title" then task.defer(fit) end
	end)
	fit()
end

function CROWN.Start()
	local function consider(d)
		if d.Name == "Line1" and d:IsA("TextLabel") and d.Parent and d.Parent.Name == "Nametag" then CROWN.Watch(d) end
	end
	workspace.DescendantAdded:Connect(consider)
	for _, d in workspace:GetDescendants() do consider(d) end
	-- UiSandbox 2026-10-08: a tag first laid out while it is not drawn (out of range, hidden) can change its TextBounds
	-- without the signal reaching us - a slow sweep over the crowned tags fits them again (writes only on a change)
	task.spawn(function()
		while true do
			task.wait(CROWN.Sweep)
			for label in CROWN.Watched do
				if label.Parent and (label:FindFirstChild("VipCrown") or label:FindFirstChild("Title")) then pcall(CROWN.Fit, label) end
			end
		end
	end)
end

------------------------------------------------------------------ lifecycle
function ShopUI.Init(registry)
	C = registry
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the shop window is off")
		return
	end
	panels.Register("Shop", {
		Title = T.Title,
		Rebuild = { Faction = true, DataLoaded = true, ShopPreview = true, LooksOwned = true }, -- an earned look appears
		Build = buildShop,
	})
end

function ShopUI.Start()
	local ok, err = pcall(CROWN.Start)
	if not ok then Util.Warn(TAG, "crown watch failed: " .. tostring(err)) end
	print("[ShopUI] started")
end

return ShopUI
