-- GearSlots.luau (게임성 개발 4, 2026-10-12; contract: header of CharacterUI.luau, "GearSlots contract"): the six gear cells inside
-- the Hero window's "EquipSlots" frame - row 1 Weapon · Armor · Ring, row 2 Pet, row 3 Pet Armor · Pet Acc (CharacterUI's
-- columns / rows) - each a 64 du cell with its one word under it. CharacterUI calls Build(frame, { Refresh = fn }) once and
-- Refresh() on every open; it draws no cell itself while this module works.
--   Weapon: the worn weapon (attributes WeaponTier / WeaponEnhance / Class / Faction): its art in the grade slot, "+N" top-left;
--           none = the empty slot. Pressing it opens the owned weapons (CharacterUI.ShowView("Weapons"), else the bag's Gear tab).
--   Pet:    the following pet (EquippedPet species id, PetLv): its icon in the common slot, "Lv N" bottom-right; none = the
--           empty slot. Pressing it opens the Pet window.
--   Armor · Ring · Pet Armor · Pet Acc: the server's gear is not in the game yet (C-7): empty cells, not pressable.
--           Cells(ctx).Gear = { Armor = { Icon, Grade, Plus, Name }, ... } is where it will drop in.
-- The frame Size is the bounding box of the cells (always 3 rows: pets are not known here); opts.Refresh runs when it changes.
-- Display only (the server checks every request). Text: short English in TXT (L10n "GearSlots.TXT", A23-111). PC first.
-- Public API: GearSlots.Init(C), GearSlots.Start(), GearSlots.Build(frame, opts), GearSlots.Refresh(),
-- pure: GearSlots.Cells(ctx) -> { { Id, Kind, Name?, Icon?, Art?, Grade?, Plus?, Lv?, Empty } }, GearSlots.FrameSize() -> w, h
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local L10n = require(Shared:WaitForChild("L10n"))

local GearSlots = {}
local C = nil
local TAG = "GearSlots"
local LocalPlayer = Players.LocalPlayer

local TXT = Config.ClientText.GearSlots -- the words: Config.ClientText.GearSlots (moved 10/14)
L10n.Register("GearSlots.TXT", TXT)

-- the same numbers as CharacterUI's L (cell, gaps, columns, rows) and the bag's grade slot parts
local L = {
	Cell = 64, ColGap = 14, CapH = 18, RowGap = 10,
	Order = { "Weapon", "Armor", "Ring", "Pet", "PetArmor", "PetAcc" },
	Kinds = { Weapon = "Weapon", Pet = "Pet", Armor = "Gear", Ring = "Gear", PetArmor = "Gear", PetAcc = "Gear" },
	Cols = { Weapon = 0, Armor = 1, Ring = 2, Pet = 0, PetArmor = 0, PetAcc = 1 },
	Rows = { Weapon = 0, Armor = 0, Ring = 0, Pet = 1, PetArmor = 2, PetAcc = 2 },
	Inner = { X = 76 / 512, Y = 80 / 512, W = 360 / 512, H = 356 / 512 }, -- the slot parts' icon box (as the bag)
	Slot = { Common = "SlotCommon", Fine = "SlotUncommon", Rare = "SlotRare", Epic = "SlotEpic", Legend = "SlotLegendary",
		Mythic = "SlotLegendary" },
	Size = { Count = 16, Small = 15 },
	Watch = { "WeaponTier", "WeaponEnhance", "Class", "Faction", "EquippedPet", "PetLv" },
}
local S = { Frame = nil, Opts = nil, Drawn = {}, Connected = false }

local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function attr(name)
	return LocalPlayer and LocalPlayer:GetAttribute(name) or nil
end

local function ui()
	local kit = C and C.UIKit
	return type(kit) == "table" and kit or nil
end

local function tx(t, key, ...)
	local kit = ui()
	if kit and type(kit.Tx) == "function" then
		local ok, s = pcall(kit.Tx, t, key, ...)
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

---------------------------------------------------------------------------------------------------- pure
-- ctx = { Tier, Plus, Class, Faction, Pet, PetLv, Gear? }. A cell = { Id, Kind = "Weapon" | "Pet" | "Gear", Name?, Icon?, Art? (the icon is
-- an approved art part, not an item icon), Grade?, Plus?, Lv?, Empty }
function GearSlots.Cells(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local gear = type(ctx.Gear) == "table" and ctx.Gear or {}
	local cells = {}
	for _, id in L.Order do
		local cell = { Id = id, Kind = L.Kinds[id], Empty = true }
		if id == "Weapon" then
			local tier = math.floor(num(ctx.Tier, 0))
			if tier >= 1 and tier <= Config.MaxWeaponTier and type(Config.WeaponInfo[tier]) == "table" then
				local grade = Config.WeaponInfo[tier].Grade
				cell.Empty = false
				cell.Name = Config.WeaponName(tier, ctx.Class, ctx.Faction)
				cell.Icon = Config.WeaponArtKey(tier, ctx.Class, ctx.Faction)
				cell.Grade = Config.WeaponGrades[grade] and grade or "Common"
				cell.Plus = math.clamp(math.floor(num(ctx.Plus, 0)), 0, Config.Loot.MaxEnhance)
			end
		elseif id == "Pet" then
			local def = type(ctx.Pet) == "string" and Config.Pets.Species[ctx.Pet] or nil
			if type(def) == "table" then
				cell.Empty = false
				cell.Name, cell.Icon, cell.Art, cell.Grade = def.Name, def.Icon, true, "Common"
				cell.Lv = math.clamp(math.floor(num(ctx.PetLv, 1)), 1, Config.Pets.MaxLv)
			end
		else
			local g = gear[id]
			if type(g) == "table" and g.Icon ~= nil then -- the server's gear (C-7) drops in here
				cell.Empty = false
				cell.Name, cell.Icon, cell.Grade = g.Name, g.Icon, L.Slot[g.Grade] and g.Grade or "Common"
				cell.Plus = math.max(0, math.floor(num(g.Plus, 0)))
			end
		end
		table.insert(cells, cell)
	end
	return cells
end

-- the bounding box of the six cells + captions (du)
function GearSlots.FrameSize()
	local cols, rows = 0, 0
	for _, id in L.Order do
		cols, rows = math.max(cols, L.Cols[id]), math.max(rows, L.Rows[id])
	end
	return (cols + 1) * L.Cell + cols * L.ColGap, (rows + 1) * (L.Cell + L.CapH) + rows * L.RowGap
end

local function context()
	local pet = attr("EquippedPet")
	return { Tier = attr("WeaponTier"), Plus = attr("WeaponEnhance"), Class = attr("Class"), Faction = attr("Faction"),
		Pet = type(pet) == "string" and pet or "", PetLv = attr("PetLv") }
end

---------------------------------------------------------------------------------------------------- drawing
local function label(parent, text, size, color, props)
	local l = Instance.new("TextLabel")
	local kit = ui()
	l.BackgroundTransparency = 1
	l.Font = kit and kit.Font or Enum.Font.GothamMedium
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	for k, v in props do
		if k ~= "Style" then l[k] = v end
	end
	l.Parent = parent
	if props.Style ~= false and kit and type(kit.StyleText) == "function" then
		pcall(kit.StyleText, l, props.Style or "Body")
		l.TextColor3 = color
	end
	return l
end

local function theme(name, default)
	local kit = ui()
	local th = kit and kit.Theme
	return type(th) == "table" and th[name] or default
end

local function slot(frame, cell, onClick)
	local kit = ui()
	local part = cell.Grade and L.Slot[cell.Grade] or "SlotEmpty"
	local def = cell.Grade and Config.WeaponGrades[cell.Grade]
	local fb = { BackgroundColor3 = Color3.fromRGB(16, 20, 40), CornerRadius = UDim.new(0, 10),
		StrokeColor = def and def.Color or Color3.fromRGB(60, 66, 96), StrokeThickness = 2 }
	local props = { Name = "Cell_" .. cell.Id, Size = UDim2.fromOffset(L.Cell, L.Cell), Parent = frame,
		Position = UDim2.fromOffset(L.Cols[cell.Id] * (L.Cell + L.ColGap), L.Rows[cell.Id] * (L.Cell + L.CapH + L.RowGap)) }
	if onClick then return (kit.ArtButton(part, props, onClick, fb)) end
	return (kit.ArtFrame(part, props, fb))
end

-- the picture in the Inner box (an art part or an item icon); the first letter of the name when it has no picture yet
local function putIcon(box, cell)
	local kit = ui()
	local props = { Name = "Icon", Position = UDim2.fromScale(L.Inner.X, L.Inner.Y), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
		ScaleType = Enum.ScaleType.Fit, ZIndex = (tonumber(box.ZIndex) or 1) + 1 }
	local img = cell.Icon and (cell.Art and kit.ArtImage(cell.Icon, props) or ((not cell.Art) and kit.ItemIcon(cell.Icon, props))) or nil
	if img then
		img.Parent = box
	else
		local letter = string.upper(string.match(tostring(cell.Name or ""), "%w") or "?")
		label(box, letter, math.floor(L.Cell * 0.42), Color3.new(1, 1, 1), { Name = "Letter", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
			TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = props.ZIndex, Style = "Number" })
	end
end

-- the one word under a cell: shrinks to fit, no text-size floor (as BagUI's worn row)
local function caption(frame, id)
	local inset = 6
	local x, y = L.Cols[id] * (L.Cell + L.ColGap), L.Rows[id] * (L.Cell + L.CapH + L.RowGap)
	local cap = label(frame, tx(TXT.Slots, id), L.Size.Small, theme("SubText", Color3.new(1, 1, 1)), { Name = "Cap_" .. id,
		Position = UDim2.fromOffset(x - inset, y + L.Cell + 2), Size = UDim2.fromOffset(L.Cell + 2 * inset, L.CapH - 2),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextScaled = true, Style = false })
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = L.Size.Small
	tc.Parent = cap
	return cap
end

local function call(fn, ...)
	if type(fn) ~= "function" then return false end
	local ok, err = pcall(fn, ...)
	if not ok then Util.Warn(TAG, "press failed: " .. tostring(err)) end
	return ok
end

-- what a press does (Weapon, Pet only); looked up at the press, the other windows may load later
local PRESS = {
	Weapon = function()
		local ch = C and C.CharacterUI
		if type(ch) == "table" and type(ch.ShowView) == "function" then return call(ch.ShowView, "Weapons") end
		local bag = C and C.BagUI
		if type(bag) == "table" then return call(bag.Open, "Gear") end
		return false
	end,
	Pet = function()
		local pw = C and C.PetWindow
		if type(pw) == "table" then return call(pw.Open) end
		return false
	end,
}

local function clearDrawn()
	for _, o in S.Drawn do pcall(o.Destroy, o) end
	S.Drawn = {}
end

local function draw()
	local frame, kit = S.Frame, ui()
	if not (frame and kit) then return end
	clearDrawn()
	for _, cell in GearSlots.Cells(context()) do
		local act = PRESS[cell.Kind]
		local box = slot(frame, cell, act)
		table.insert(S.Drawn, box)
		if not cell.Empty then
			putIcon(box, cell)
			local z = (tonumber(box.ZIndex) or 1) + 3
			if (cell.Plus or 0) > 0 then
				label(box, "+" .. tostring(cell.Plus), L.Size.Count, theme("Gold", Color3.new(1, 1, 1)), { Name = "Plus",
					Position = UDim2.fromOffset(4, 1), Size = UDim2.new(1, -8, 0, L.Size.Count + 2), TextWrapped = false, ZIndex = z,
					Style = "Number" })
			end
			if cell.Lv then
				label(box, tx(TXT, "PetLv", cell.Lv), L.Size.Count, Color3.new(1, 1, 1), { Name = "Lv", AnchorPoint = Vector2.new(1, 1),
					Position = UDim2.new(1, -4, 1, -1), Size = UDim2.new(1, -8, 0, L.Size.Count + 2),
					TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, ZIndex = z, Style = "Number" })
			end
		end
		table.insert(S.Drawn, caption(frame, cell.Id))
	end
end

local function redraw()
	local ok, err = pcall(draw)
	if not ok then Util.Warn(TAG, "draw failed: " .. tostring(err)) end
end

-- sets the frame's Size to the cells' bounding box; the owner is told only when it changed
local function fitFrame()
	local frame = S.Frame
	local w, h = GearSlots.FrameSize()
	local ok, cw, ch = pcall(function() return frame.Size.X.Offset, frame.Size.Y.Offset end)
	if ok and cw == w and ch == h then return end
	frame.Size = UDim2.fromOffset(w, h)
	if S.Opts and type(S.Opts.Refresh) == "function" then call(S.Opts.Refresh) end
end

function GearSlots.Build(frame, opts)
	S.Frame, S.Opts = frame, type(opts) == "table" and opts or nil
	draw() -- takes the old cells away first (a frame made again is built again); a failing draw = no GearSlots (CharacterUI's fallback)
	fitFrame()
	if not S.Connected and LocalPlayer then
		S.Connected = true
		for _, name in L.Watch do
			LocalPlayer:GetAttributeChangedSignal(name):Connect(redraw)
		end
	end
end

function GearSlots.Refresh()
	if S.Frame then redraw() end
end

function GearSlots.Init(registry)
	C = registry
end

function GearSlots.Start() end

-- offline tests
GearSlots._T = { TXT = TXT, L = L, S = S }

return GearSlots
