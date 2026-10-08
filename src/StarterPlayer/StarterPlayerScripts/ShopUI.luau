-- ShopUI.luau : the Robux shop (SPEC A23-75, user 2026-10-08: 2x XP · 2x Gold · VIP passes, halo / horn looks and the
-- private server, prices "추천 가격대로") as the Panels window "Shop", added through Panels.Register (BB13). It takes
-- the old change-ticket shop's id; the ticket rows stay at the bottom while a ticket is on sale (검수 2026-10-07).
-- Layout (이미지 개발 2026-10-08; one list for PC and phones, the window scrolls when the screen is short):
--   Passes - the four cards in one row (the phone window is 780 du wide too: 177 du = 133 px cards, all four seen
--     at once). A card is one tap target (the navy PanelCard plate): the icon in a rim slot (VIP = SlotLegendary's
--     crown rim, Private Server = SlotRare, the boosts = RewardSlot), the name, up to three short lines and a capsule
--     at the bottom - gold "199 R$" = buy, green "Owned", dimmed "Coming soon" while the pass id is 0 (A23-75).
--     Roblox's own dialog confirms every purchase. The private server is sold on the game page only (Roblox has no
--     in-game prompt for it), so its card says where to get it.
--   Looks - my side's halo / horn looks (Config.Looks; no side or Neutral: all of them) as rim tiles with a capsule:
--     price / Wear / Wearing (tap again = take it off, through the SetLook remote once it exists). 검수 2026-10-08: the
--     section shows once looks are picked and listed (no "coming soon" teaser before that).
--   Change Tickets - the two old rows while a ticket product has an id.
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
	{ Kind = "PrivateServer", Badge = "IconPrivateServer", Icon = "IconTravel", Slot = "SlotRare", Price = 100, Info = true },
}

-- English only (A23-48), short words for kids (glossary 2026-10-06)
local T = {
	Title = "Shop",
	Names = { XP2 = "2x XP", Gold2 = "2x Gold", VIP = "VIP", PrivateServer = "Private Server" },
	Lines = {
		XP2 = "Level up twice as fast!",
		Gold2 = "Get twice the gold!",
		VIP = "Crown name tag, VIP chat and emote.",
		PrivateServer = "Play with just your friends.",
	},
	PriceF = "%s R$",
	MonthF = "%s R$ / mo",
	Owned = "Owned",
	Soon = "Coming soon",
	Wear = "Wear",
	Wearing = "Wearing",
	LooksSideF = "Looks for %s",
	Looks = "Looks",
	Tickets = "Change Tickets",
	TicketF = "%s · you have %d",
	SoonToast = "Not on sale yet. Check back soon!",
	OwnedToast = "You already have this!",
	ServerToast = "Get a private server on the game page: open Servers, then Create.",
	Note = "Always ask a grown-up before you buy.",
}

-- layout in canvas du (Panels' phone UIScale 0.75: 100 du = 75 px). Card = Pad · Slot · name · three lines · capsule ·
-- Pad. Text floors are real px (Roblox applies UITextSizeConstraint after UIScale, UiSandbox 2026-10-08): the lines'
-- StyleMinPx 11 renders 15 px on phones (rubric >= 14) and 14 px on a 720p PC - the Body floor (19 px on phones) wrapped
-- 'Crown name tag, VIP chat and emote.' into four lines
local L = {
	Cols = 4, Gap = 10, CardH = 266, Pad = 10, Slot = 92, Icon = 0.62, NameH = 28, NameSize = 22, NameMinPx = 12,
	LinesMinPx = 11,
	LineSize = 15, CapsH = 40, CapsSize = 22, LookCols = 4, LookH = 178, LookSlot = 84, HeadH = 30, HeadSize = 20, TicketH = 64,
	Guard = 0.35, -- s: a fast second tap on the [메뉴] square must not land on a card (CR-L26)
}
-- Studio-only sample looks for the layout photos: the four the user picked (A23-75, 2026-10-08: halo Ice · Gold,
-- horns Lava · Shadow; ids 0 = "Coming soon", the pictures are stand-ins until their badges are drawn)
local SAMPLE_LOOKS = {
	IceHalo = { Faction = "Halo", Name = "Ice Halo", Icon = "IconRankHonor", Price = 99, Order = 1 },
	GoldHalo = { Faction = "Halo", Name = "Gold Halo", Icon = "IconRankHonor", Price = 99, Order = 2 },
	LavaHorns = { Faction = "Horns", Name = "Lava Horns", Icon = "IconRankInfamy", Price = 99, Order = 1 },
	ShadowHorns = { Faction = "Horns", Name = "Shadow Horns", Icon = "IconRankInfamy", Price = 99, Order = 2 },
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
local function passDef(p)
	local all = type(Config.GamePasses) == "table" and Config.GamePasses or {}
	local cfg = type(all[p.Kind]) == "table" and all[p.Kind] or {}
	return {
		Id = math.floor(tonumber(cfg.Id) or 0),
		Price = tonumber(cfg.Price) or tonumber(cfg.PriceHint) or p.Price,
		Attr = type(cfg.Attr) == "string" and cfg.Attr or p.Attr,
	}
end

local function myFaction()
	local f = attrOf("Faction", "None")
	return type(f) == "string" and f or "None"
end

-- the looks to show, in order: my side's (Halo / Horns), else every side's
local function lookList()
	local defs = Config.Looks
	if RunService:IsStudio() and attrOf("ShopPreview", false) == true then defs = SAMPLE_LOOKS end
	local mine = myFaction()
	local list = {}
	for id, def in (type(defs) == "table" and defs or {}) do
		if type(def) == "table" and (mine ~= "Halo" and mine ~= "Horns" or def.Faction == mine) then
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

local function ownsLook(id)
	local owned = attrOf("LooksOwned", "")
	return type(owned) == "string" and table.find(string.split(owned, ","), id) ~= nil
end

local function hasRemote(name)
	return type(Net.Names) == "table" and table.find(Net.Names, name) ~= nil
end

local function prompt(id)
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
		u.ArtImage(badge, { Name = "Badge", Size = UDim2.fromOffset(L.HeadH, L.HeadH), Parent = label })
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
	if p.Info then kit.Toast(T.ServerToast, "info"); return end
	if d.Attr and attrOf(d.Attr, false) == true then kit.Toast(T.OwnedToast, "info"); return end
	if d.Id <= 0 then kit.Toast(T.SoonToast, "info"); return end
	prompt(d.Id)
end

local function tapLook(kit, look)
	local id, def = look.Id, look.Def
	if ownsLook(id) then
		if not hasRemote("SetLook") then kit.Toast(T.SoonToast, "info"); return end
		kit.Fire("SetLook", attrOf("LookOn", "") == id and "" or id) -- tap the worn one again = take it off
		return
	end
	local passId = math.floor(tonumber(def.PassId or def.Id) or 0)
	if passId <= 0 then kit.Toast(T.SoonToast, "info"); return end
	prompt(passId)
end

local function refreshPass(kit, cell)
	local p, d = cell.Pass, passDef(cell.Pass)
	if p.Info then
		setCapsule(kit, cell, string.format(T.MonthF, Util.FormatInt(d.Price)), kit.Palette.Button, true)
	elseif d.Attr and attrOf(d.Attr, false) == true then
		setCapsule(kit, cell, T.Owned, kit.Palette.Free, true)
	elseif d.Id <= 0 then
		setCapsule(kit, cell, T.Soon, kit.Palette.Button, false)
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
	else
		setCapsule(kit, cell, string.format(T.PriceF, Util.FormatInt(tonumber(def.Price) or 99)), kit.Palette.Buy, true)
	end
end

local function ticketsOnSale()
	for _, kind in { "Class", "Faction" } do
		local p = Config.ProductByKind(kind)
		if p and (tonumber(p.Id) or 0) ~= 0 then return true end
	end
	return false
end

local function buildTickets(u, kit, parent, rows)
	header(u, kit, parent, T.Tickets)
	for _, kind in { "Class", "Faction" } do
		local p = Config.ProductByKind(kind)
		local row = Instance.new("Frame")
		row.Name = "Ticket" .. kind
		row.BackgroundColor3 = kit.Palette.Row
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, L.TicketH)
		row.LayoutOrder = kit.NextOrder()
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = row
		row.Parent = parent
		local label = u.StyledLabel({
			Name = "Label", Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -200, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left, TextSize = 18, TextWrapped = true, Parent = row,
		}, "Body")
		local b = kit.Button(row, "", kit.Palette.Buy, UDim2.fromOffset(170, 46), function()
			if not p or (tonumber(p.Id) or 0) == 0 then kit.Toast(T.SoonToast, "info"); return end
			local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, p.Id)
			if not ok then Util.Warn(TAG, "PromptProductPurchase failed: " .. tostring(err)) end
		end)
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, -10, 0.5, 0)
		local onSale = p ~= nil and (tonumber(p.Id) or 0) ~= 0
		b.Text = onSale and string.format(T.PriceF, tostring(p.PriceHint)) or T.Soon
		kit.SetEnabled(b, onSale)
		table.insert(rows, { Label = label, Name = (p and p.Name) or kind,
			Attr = kind == "Class" and "ClassTickets" or "FactionTickets" })
	end
end

local function buildShop(parent, kit)
	local u = uikit()
	if not u then return nil end
	local openedAt = os.clock()
	local passCells, lookCells, ticketRows = {}, {}, {}

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
		cardWords(u, card, T.Names[p.Kind] or p.Kind, T.Lines[p.Kind], linesTop, linesH)
		cell.Button = capsule(kit, card, function()
			if os.clock() >= openedAt + L.Guard then tapPass(kit, p) end
		end)
		refreshPass(kit, cell)
		table.insert(passCells, cell)
	end

	-- looks: my side's rim tiles (nothing while no look is listed yet)
	local looks = lookList()
	local mine = myFaction()
	local side = (mine == "Halo" or mine == "Horns") and Config.Factions[mine] or nil
	if #looks > 0 then
		header(u, kit, parent, side and string.format(T.LooksSideF, tostring(side.Name)) or T.Looks, "IconPassLooks")
		local tiles = grid(kit, parent, "Looks", L.LookCols, L.LookH, #looks)
		for _, look in looks do
			local cell = { Look = look }
			local tile = cardButton(u, kit, tiles, "Look" .. look.Id, function() tapLook(kit, look) end, openedAt)
			rimSlot(u, "SlotEpic", tostring(look.Def.Icon or "IconRankHonor"), {
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

	if ticketsOnSale() then buildTickets(u, kit, parent, ticketRows) end
	kit.Text(parent, T.Note, { Color = kit.Theme.SubText, Size = 15, Align = Enum.TextXAlignment.Center })

	return function()
		for _, cell in passCells do refreshPass(kit, cell) end
		for _, cell in lookCells do refreshLook(kit, cell) end
		for _, r in ticketRows do
			r.Label.Text = string.format(T.TicketF, r.Name, math.floor(tonumber(attrOf(r.Attr, 0)) or 0))
		end
	end
end

------------------------------------------------------------------ VIP crown on name tags (A23-75)
-- The server adds VipCrown / VipPad to a VIP's nametag Line1 (CharacterVisuals, hidden); this client sizes and places
-- it from the name as it renders here: Height of the line's TextBounds (Denk One: about 0.8 of the letters), the art's
-- own width : height, Gap px before the first letter. The padding takes the crown's room, so crown + name stay one
-- centred group, and a long name that TextScaled shrinks takes the crown down with it.
local CROWN = { Height = 0.62, Gap = 3, Watched = setmetatable({}, { __mode = "k" }) }

function CROWN.Fit(label)
	local crown, pad = label:FindFirstChild("VipCrown"), label:FindFirstChild("VipPad")
	if not (crown and pad and crown:IsA("ImageLabel") and pad:IsA("UIPadding")) then return end
	local tb = label.TextBounds
	if tb.X < 1 or tb.Y < 1 then return end
	local ch = math.max(6, math.floor(tb.Y * CROWN.Height + 0.5))
	local cw = math.floor(ch * (tonumber(crown:GetAttribute("Aspect")) or 1.46) + 0.5)
	local room = cw + CROWN.Gap
	if pad.PaddingLeft.Offset ~= room then pad.PaddingLeft = UDim.new(0, room) end -- may re-scale the name: refit
	crown.Size = UDim2.fromOffset(cw, ch)
	-- the padded box's middle is the name's middle: half the name to the left, then the gap
	crown.Position = UDim2.new(0.5, -math.floor(tb.X / 2 + CROWN.Gap + 0.5), 0.5, -1)
	crown.Visible = true
end

function CROWN.Watch(label)
	if CROWN.Watched[label] then return end
	CROWN.Watched[label] = true
	local function fit()
		local ok, err = pcall(CROWN.Fit, label)
		if not ok then Util.Warn(TAG, "crown fit failed: " .. tostring(err)) end
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	label.ChildAdded:Connect(function(child)
		if child.Name == "VipCrown" or child.Name == "VipPad" then task.defer(fit) end
	end)
	fit()
end

function CROWN.Start()
	local function consider(d)
		if d.Name == "Line1" and d:IsA("TextLabel") and d.Parent and d.Parent.Name == "Nametag" then CROWN.Watch(d) end
	end
	workspace.DescendantAdded:Connect(consider)
	for _, d in workspace:GetDescendants() do consider(d) end
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
		Rebuild = { Faction = true, DataLoaded = true, ShopPreview = true },
		Build = buildShop,
	})
end

function ShopUI.Start()
	local ok, err = pcall(CROWN.Start)
	if not ok then Util.Warn(TAG, "crown watch failed: " .. tostring(err)) end
	print("[ShopUI] started")
end

return ShopUI
