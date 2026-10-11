-- BagUI.luau (게임성 개발 4, H-1 / BB7 가방 창; SPEC A23-32 · A23-19 · A23-99 · A23-130 · A23-98 · A23-127 · A23-133, design
-- docs/design/beta_basics_2026-10-05.md BB7 'user decision 2026-10-06' block, art sheet art/review/s2/b7_slots_glyphs_sheet.png):
-- the Panels window "Bag" (the HUD's Bag tile and the I key open it; until it is registered they opened the old "Items").
--   tabs    : Gear · Use · Scrolls · Materials, each with the count of things new since it was last looked at (BadgeDot)
--   grid    : the approved dark grade slots (SlotCommon / Uncommon / Rare / Epic / Legendary, SlotEmpty fills the rest of
--             the rows), the icon in the slot's Inner box, count bottom-right (not at 1), +N top-left, a gold check on the
--             equipped weapon, a dot on a new thing. No slot limit. Gear starts with the worn row: Weapon · Armor · Ring ·
--             Pet gear (A23-133; armor / rings / pet gear have no server data yet, so those three stay empty places)
--   detail  : the picked thing on the right - big slot, name in its grade colour, short lines (attack, power change,
--             level lock, count, sell price, which seen monsters drop it) and its buttons: Equip (EquipWeapon), Drink
--             (UsePotion) + quick slot 1 / 2 / 3 (QuickSlots.Set), Use for a scroll -> pick the weapon(s) in the grid ->
--             Enhance / Move (UseItem) with the chance and the fail result shown before anything is sent
--   bottom  : my gold (bank + carried), the sort (Newest · Name · Grade · Type, saved as Settings.BagSort, Newest =
--             the server's ItemSeq / WeaponSeq order) and narrow (4 columns) / wide (8 columns) (Settings.BagWide)
-- Data: the owner's "Inventory" remote ({ Items, Enhance, Seen, ItemSeq, WeaponSeq, Spares? }; bound here too) + the
-- player attributes. Display only: the server checks every request. No selling here yet (A23-127: Otto buys
-- materials and spares; that screen comes with the server's SellItem / spares).
-- Text: short English in TXT (L10n key "BagUI.TXT.*", A23-111); item names through Config (UIKit.Tx). PC first (A23-98).
-- Public API: BagUI.Init(C), BagUI.Start(), BagUI.IsReady(), BagUI.Open(tab?), BagUI.OnInventory(payload),
-- pure: BagUI.Cells(ctx) -> cells, BagUI.Sort(cells, mode) -> cells, BagUI.Columns(widthDu, wide) -> n,
-- BagUI.WindowWidth(wide) -> du, BagUI.Detail(cell, ctx) -> view, BagUI.PotionState(p) -> text, enabled,
-- BagUI.Pick(mode, cell, ctx) -> mode, BagUI.CellEnabled(mode, cell) -> bool
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local L10n = require(Shared:WaitForChild("L10n"))

local BagUI = {}
local C = nil
local TAG = "BagUI"
local LocalPlayer = Players.LocalPlayer

-- player text (A23-130: short; A23-111: keys "BagUI.TXT.<field>")
local TXT = {
	Title = "Bag",
	Tabs = { Gear = "Gear", Use = "Use", Scroll = "Scrolls", Material = "Materials" },
	Sorts = { Default = "Newest", Name = "Name", Grade = "Grade", Kind = "Type" },
	Worn = { Weapon = "Weapon", Armor = "Armor", Ring = "Ring", PetGear = "Pet" }, -- one short word per slot (UiSandbox 10/12: "Pet gear" ran into "Ring")
	Equip = "Equip", Equipped = "Equipped", FromLv = "From Lv %d", InFight = "In a fight", Checking = "Checking…",
	Attack = "Attack %s",
	Power = "Power %s → %s",
	PowerNow = "Power %s",
	Spare = "Spare",
	Count = "×%d",
	Drink = "Drink", Full = "Full", Empty = "Empty", Wait = "%d s", Quick = "Quick slot",
	Use = "Use", Cancel = "Cancel", Enhance = "Enhance", Move = "Move",
	ScrollEnh = "+%d on success · %d%%",
	ScrollMove = "Moves all + to another weapon · %d%%",
	PickEnhance = "Pick a weapon.",
	PickFrom = "Pick the weapon to take + from.",
	PickTo = "Pick the weapon to get +%d.",
	ConfirmEnh = "%s\n+%d → +%d · %d%% chance", -- UiSandbox 10/12: "+0 → +1" no longer breaks in the 200 du column
	ConfirmMove = "%s +%d →\n%s +%d · %d%% chance",
	FailDown = "A fail may drop it 1 step. Weapons never break!",
	FailKeep = "Nothing changes on a fail.",
	SellsFor = "Sells for %s each",
	From = "From: %s",
}
L10n.Register("BagUI.TXT", TXT)

-- layout (du = MainGui units) and fixed rules
local L = {
	Window = "Bag",
	Tabs = { "Gear", "Use", "Scroll", "Material" },
	Sorts = { "Default", "Name", "Grade", "Kind" }, -- the Settings.BagSort options, the sort button cycles them
	Cell = 60, Gap = 5, -- a slot and the space between (>= 60 du tap target, BB7)
	Scroll = 12, -- the grid's scroll bar + its inset
	DetailW = 200, Split = 12, -- the detail column and the space left of it
	Pad = 18, -- Panels FRAME.Pad (window rim -> content, each side)
	Narrow = 4, Wide = 8, -- columns (A23-32: 4 <-> 8 or more)
	TabH = 40, BarH = 40, RowGap = 8, Round = 38, CoinW = 26,
	WornCap = 18, -- the worn row's word under each slot
	WornInset = 6, -- du: the worn row starts this far in, each word reaches this far past its slot (UiSandbox: "Weapo")
	Big = 84, -- the detail's slot
	BtnH = 40, QuickW = 46,
	Size = { Name = 19, Body = 16, Small = 15, Count = 16, Tab = 18 },
	-- the slot parts' icon box (Config.UIArt SlotCommon ... Inner = Rect(76, 80, 436, 436) of 512)
	Inner = { X = 76 / 512, Y = 80 / 512, W = 360 / 512, H = 356 / 512 },
	Slot = { Common = "SlotCommon", Fine = "SlotUncommon", Rare = "SlotRare", Epic = "SlotEpic", Legend = "SlotLegendary",
		Mythic = "SlotLegendary" },
	-- grades of the bag's items (BB6: materials Common; the 70% scrolls and the Prince / Brute / Knight drops Fine,
	-- 30% Rare, 10% Epic; the weekly Captain's Badge Rare). A Config.Loot.Items[id].Grade wins
	ItemGrade = { SlimeCore = "Fine", BruteHorn = "Fine", KnightCrest = "Fine", CaptainBadge = "Rare",
		Enh70 = "Fine", Move70 = "Fine", Enh30 = "Rare", Move30 = "Rare", Enh10 = "Epic", Move10 = "Epic" },
	-- kinds: the Type sort order and the tab each lives on (Armor / Ring / PetGear: A23-133, no data yet)
	KindOrder = { Weapon = 1, Spare = 2, Armor = 3, Ring = 4, PetGear = 5, Potion = 10, Enhance = 20, Transfer = 21, Material = 30 },
	KindTab = { Weapon = "Gear", Spare = "Gear", Armor = "Gear", Ring = "Gear", PetGear = "Gear", Potion = "Use",
		Enhance = "Scroll", Transfer = "Scroll", Material = "Material" },
	Worn = { "Weapon", "Armor", "Ring", "PetGear" },
	GapMargin = 0.15, -- s over Config.RateLimits[remote] (the server drops a 2nd request inside it without a reply)
	PendingTimeout = 3, -- s without an answer -> the request stops waiting (quietly)
	MaxFrom = 3, -- monster names on the 'From:' line
}

-- state: S.Data = the last Inventory payload (validated); S.SeqBase = the newest order number when the first payload
-- came (older things are never 'new'); S.SeenSeq[key] = the order number the player has looked at
local S = {
	Ready = false,
	Data = { Items = {}, Enhance = {}, Seen = {}, ItemSeq = {}, WeaponSeq = {}, Spares = {} },
	Version = 0,
	SeqBase = nil,
	SeenSeq = {},
	Tab = "Gear",
	Sel = nil, -- key of the picked cell
	Mode = nil, -- a scroll being used: { Item, Tier?, From?, To? }
	Pending = nil, -- { Kind = "Use" | "Equip", SentAt, ReadyAt, Item?, Count?, Tier?, WeaponTier?, Answered? }
	ReadyAt = {}, -- [remote] = os.clock() when the next send is allowed
	Note = nil, -- one status line (a timeout)
	Result = nil, ResultAt = -math.huge, -- the last scroll result Panels got (Panels.LastEnhance)
	Shown = {}, -- [tab] = true: shown since the window opened (its new things count as seen when it is left)
}
local pullInventory -- (defined with the data below)
local VIEW = {} -- the open window: Kit, Parent, Body, Grid, Detail, Bar, Tabs = { [tab] = button }, Sig

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

local function setting(key, d)
	local st = C and C.Settings
	if type(st) == "table" and type(st.Get) == "function" then
		local ok, v = pcall(st.Get, key)
		if ok and v ~= nil then return v end
	end
	return d
end

local function owns(mask, tier)
	return bit32.btest(math.max(0, math.floor(num(mask, 0))), bit32.lshift(1, tier - 1))
end

local function enhOf(enh, tier)
	local n = type(enh) == "table" and (enh[tier] or enh[tostring(tier)]) or nil
	return math.clamp(math.floor(num(n, 0)), 0, Config.Loot.MaxEnhance)
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

local function itemKind(def)
	local k = type(def) == "table" and def.Kind or nil
	if k == "Enhance" or k == "Transfer" or k == "Material" then return k end
	return "Material"
end

---------------------------------------------------------------------------------------------------- the model (pure)
-- every thing in the bag. ctx = { Items, Enhance, ItemSeq, WeaponSeq, Spares, Mask, Equipped, Level, Class, Faction,
-- Potions = { [quick item] = count }, SeqBase, SeenSeq }. A cell = { Key, Kind, Tab, Id?, Tier?, Plus, Count, Grade,
-- Rank, Name, Icon, Color?, Seq, Equipped?, New? }
function BagUI.Cells(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local out = {}
	local function seqNew(cell)
		cell.Tab = L.KindTab[cell.Kind]
		cell.Rank = gradeDef(cell.Grade).Rank or 1
		local base = ctx.SeqBase
		local seen = type(ctx.SeenSeq) == "table" and ctx.SeenSeq[cell.Key] or nil
		cell.New = type(base) == "number" and cell.Seq > base and cell.Seq > num(seen, 0)
		table.insert(out, cell)
	end
	local equipped = math.floor(num(ctx.Equipped, 0))
	local wseq = type(ctx.WeaponSeq) == "table" and ctx.WeaponSeq or {}
	for tier = 1, Config.MaxWeaponTier do
		if owns(ctx.Mask, tier) or tier == equipped then
			seqNew({ Key = "W:" .. tier, Kind = "Weapon", Tier = tier, Plus = enhOf(ctx.Enhance, tier), Count = 1,
				Grade = weaponGradeId(tier), Name = Config.WeaponName(tier, ctx.Class, ctx.Faction),
				Icon = Config.WeaponArtKey(tier, ctx.Class, ctx.Faction), Seq = math.floor(num(wseq[tier] or wseq[tostring(tier)], 0)),
				Equipped = tier == equipped })
		end
	end
	-- A23-127 spares ("tier:plus" -> n) once the server sends them
	if type(ctx.Spares) == "table" then
		local keys = {}
		for key in ctx.Spares do table.insert(keys, key) end
		table.sort(keys)
		for _, key in keys do
			local t, p = string.match(key, "^(%d+):(%d+)$")
			local tier, n = tonumber(t), math.floor(num(ctx.Spares[key], 0))
			if tier and Config.Weapons[tier] and n >= 1 then
				seqNew({ Key = "S:" .. key, Kind = "Spare", Tier = tier, Plus = math.clamp(tonumber(p) or 0, 0, Config.Loot.MaxEnhance),
					Count = n, Grade = weaponGradeId(tier), Name = Config.WeaponName(tier, ctx.Class, ctx.Faction),
					Icon = Config.WeaponArtKey(tier, ctx.Class, ctx.Faction), Seq = 0 })
			end
		end
	end
	local iseq = type(ctx.ItemSeq) == "table" and ctx.ItemSeq or {}
	local qs = type(Config.QuickSlots) == "table" and Config.QuickSlots or {}
	for _, item in type(qs.Order) == "table" and qs.Order or {} do
		local def = type(qs.Items) == "table" and qs.Items[item] or nil
		local n = math.floor(num(type(ctx.Potions) == "table" and ctx.Potions[item], 0))
		-- 게임성 검수 10/12: a quick slot potion keeps its slot at 0 (its quick slot buttons stay reachable - KO1 'Put
		-- the potion in a quick slot' after drinking them all; Drink is off, the icon dimmed)
		if type(def) == "table" and def.Use == "Potion" then
			seqNew({ Key = "P:" .. item, Kind = "Potion", Id = item, Plus = 0, Count = n, Grade = "Common",
				Name = tx(def, "Name"), Icon = def.Icon, Seq = math.floor(num(iseq["Potion" .. tostring(def.Kind)], 0)) })
		end
	end
	local loot = Config.Loot
	local done = {}
	local ids = table.clone(loot.Order)
	local extra = {}
	for id in loot.Items do
		if not table.find(ids, id) then table.insert(extra, id) end
	end
	table.sort(extra)
	for _, id in extra do table.insert(ids, id) end
	for _, id in ids do
		local def = loot.Items[id]
		local n = math.floor(num(type(ctx.Items) == "table" and ctx.Items[id], 0))
		if def and not done[id] and n >= 1 then
			done[id] = true
			seqNew({ Key = "I:" .. id, Kind = itemKind(def), Id = id, Plus = 0, Count = n, Grade = itemGradeId(id, def),
				Name = tx(def, "Name"), Icon = id, Color = def.Color, Seq = math.floor(num(iseq[id], 0)) })
		end
	end
	return out
end

-- the cells of one tab in the chosen order (mode = a Settings.BagSort option; unknown -> Newest)
function BagUI.Sort(cells, mode)
	local list = table.clone(cells)
	local function kind(c) return L.KindOrder[c.Kind] or 99 end
	local function nameLess(a, b)
		local na, nb = string.lower(a.Name or ""), string.lower(b.Name or "")
		if na ~= nb then return na < nb end
		if a.Plus ~= b.Plus then return a.Plus > b.Plus end
		return a.Key < b.Key
	end
	local less
	if mode == "Name" then
		less = nameLess
	elseif mode == "Grade" then
		less = function(a, b)
			if a.Rank ~= b.Rank then return a.Rank > b.Rank end
			if kind(a) ~= kind(b) then return kind(a) < kind(b) end
			return nameLess(a, b)
		end
	elseif mode == "Kind" then
		less = function(a, b)
			if kind(a) ~= kind(b) then return kind(a) < kind(b) end
			if a.Rank ~= b.Rank then return a.Rank > b.Rank end
			return nameLess(a, b)
		end
	else -- Newest (A23-32 default): the bigger order number first
		less = function(a, b)
			if a.Seq ~= b.Seq then return a.Seq > b.Seq end
			if a.Rank ~= b.Rank then return a.Rank > b.Rank end
			return nameLess(a, b)
		end
	end
	table.sort(list, less)
	return list
end

function BagUI.TabCells(cells, tab)
	local out = {}
	for _, c in cells do
		if c.Tab == tab then table.insert(out, c) end
	end
	return out
end

-- grid width (du) of n columns, and the window width a narrow / wide bag asks Panels for
local function gridW(cols)
	return cols * L.Cell + (cols - 1) * L.Gap + L.Scroll
end

function BagUI.WindowWidth(wide)
	return 2 * L.Pad + gridW(wide and L.Wide or L.Narrow) + L.Split + L.DetailW
end

-- columns that fit the content width (a window Panels had to make narrower than asked keeps at least 3)
function BagUI.Columns(widthDu, wide)
	local want = wide and L.Wide or L.Narrow
	local room = num(widthDu, 0) - L.Split - L.DetailW - L.Scroll
	if room <= 0 then return want end
	local fit = math.floor((room + L.Gap) / (L.Cell + L.Gap))
	return math.clamp(math.min(want, fit), 3, want)
end

-- a potion's button. p = { Count, ReadyAt, Now, Amount, Max, Sip, Busy } -> text, enabled
function BagUI.PotionState(p)
	local count = math.floor(num(p.Count, 0))
	local left = num(p.ReadyAt, 0) - num(p.Now, 0)
	if left > 0 then return tx(TXT, "Wait", math.ceil(left)), false end
	if count <= 0 then return tx(TXT, "Empty"), false end -- UiSandbox 10/12: a dimmed "Drink" read as on
	if p.Busy then return tx(TXT, "Drink"), false end
	if num(p.Amount, 0) >= num(p.Max, 1) and p.Sip ~= true then return tx(TXT, "Full"), false end
	return tx(TXT, "Drink"), true
end

-- may this weapon cell be tapped while a scroll is being used (mode)?
function BagUI.CellEnabled(mode, cell)
	if not mode then return true end
	if type(cell) ~= "table" or cell.Kind ~= "Weapon" then return false end
	local def = Config.Loot.Items[mode.Item]
	if not def then return false end
	local max = Config.Loot.MaxEnhance
	if def.Kind == "Enhance" then return cell.Plus < max end
	if not mode.From then return cell.Plus > 0 end
	return cell.Tier == mode.From or cell.Plus < max
end

-- the next scroll step after tapping a weapon cell
function BagUI.Pick(mode, cell)
	if not mode or not BagUI.CellEnabled(mode, cell) then return mode end
	local def = Config.Loot.Items[mode.Item]
	if def.Kind == "Enhance" then return { Item = mode.Item, Tier = cell.Tier } end
	if not mode.From then return { Item = mode.Item, From = cell.Tier } end
	if cell.Tier == mode.From then return { Item = mode.Item } end
	return { Item = mode.Item, From = mode.From, To = cell.Tier }
end

-- the scroll step dropped back to its last valid part (scroll used up, weapon at +Max, empty source, gone)
local function validMode(mode, cells)
	local def = mode and Config.Loot.Items[mode.Item]
	if not mode or not def or def.Kind == "Material" then return nil end
	local byTier, count = {}, 0
	for _, c in cells do
		if c.Kind == "Weapon" then byTier[c.Tier] = c end
		if c.Key == "I:" .. mode.Item then count = c.Count end
	end
	if count < 1 then return nil end
	local max = Config.Loot.MaxEnhance
	if def.Kind == "Enhance" then
		local w = mode.Tier and byTier[mode.Tier]
		if mode.Tier and (not w or w.Plus >= max) then return { Item = mode.Item } end
		return mode
	end
	local from, to = mode.From and byTier[mode.From], mode.To and byTier[mode.To]
	if mode.From and (not from or from.Plus <= 0) then return { Item = mode.Item } end
	if mode.To and (not to or mode.To == mode.From or to.Plus >= max) then return { Item = mode.Item, From = mode.From } end
	return mode
end
BagUI.ValidMode = validMode

local function failLine(before)
	if before <= 0 then return tx(TXT, "FailKeep") end
	if num(Config.Loot.FailDropChance, 0) <= 0 then return tx(TXT, "FailKeep") end
	return tx(TXT, "FailDown")
end

local function pct(x)
	return math.floor(num(x, 0) * 100 + 0.5)
end

-- the seen monsters that drop item id ("Slime, Slime Prince, …")
local function dropsFrom(id, seen)
	local names = {}
	for _, kind in Config.MonsterTypeOrder or {} do
		local rows = Config.Loot.Tables[kind]
		if rows and type(seen) == "table" and seen[kind] and (type(Config.MonsterActive) ~= "function" or Config.MonsterActive(kind)) then
			for _, row in rows do
				local b = type(row.BelowLevel) == "table" and row.BelowLevel or nil
				if row.Item == id or (b and b.Item == id) then
					local m = Config.MonsterTypes[kind]
					local name = m and tx(m, m.Short and "Short" or "Name") or kind
					if not table.find(names, name) then table.insert(names, name) end
					break
				end
			end
		end
	end
	if #names == 0 then return nil end
	local shown = {}
	for i = 1, math.min(#names, L.MaxFrom) do shown[i] = names[i] end
	return table.concat(shown, ", ") .. (#names > L.MaxFrom and ", …" or "")
end

-- what the detail column shows for a cell (a scroll's result is the server's toast, not repeated here: A23-130).
-- ctx = { Level, Combat, Pending, Mode, Seen, Note, Power(tier, plus)
-- -> number, PowerNow, Potion(item) -> { Count, ReadyAt, Now, Amount, Max, Sip }, Cells }. view = { Title, Color, Sub,
-- SubColor, Lines = { { Text, Color? } }, Actions = { { Id, Text, Enabled, Color = "Free" | "Buy" | "Button" } },
-- Quick = item? (the quick slot row), Status = { Text, Color }? }
function BagUI.Detail(cell, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local view = { Lines = {}, Actions = {} }
	local function line(text, color) table.insert(view.Lines, { Text = text, Color = color }) end
	local function act(id, text, enabled, color) table.insert(view.Actions, { Id = id, Text = text, Enabled = enabled ~= false, Color = color or "Button" }) end
	local pending = ctx.Pending
	if ctx.Note then view.Status = { Text = ctx.Note, Color = "Bad" } end
	local mode = ctx.Mode
	local sdef = mode and Config.Loot.Items[mode.Item]
	if sdef then
		-- a scroll is being used: its steps replace whatever was picked
		local byTier = {}
		for _, c in ctx.Cells or {} do
			if c.Kind == "Weapon" then byTier[c.Tier] = c end
		end
		view.Title, view.Color, view.Icon, view.Grade = tx(sdef, "Name"), sdef.Color, mode.Item, itemGradeId(mode.Item, sdef)
		local max = Config.Loot.MaxEnhance
		local go = nil
		if sdef.Kind == "Enhance" then
			local w = mode.Tier and byTier[mode.Tier]
			if w then
				local plus = math.max(0, math.floor(num(sdef.Plus, 0)))
				line(tx(TXT, "ConfirmEnh", w.Name, w.Plus, math.min(max, w.Plus + plus), pct(sdef.Chance)), "Gold")
				line(failLine(w.Plus), "Sub")
				go = "Enhance"
			else
				line(tx(TXT, "PickEnhance"), "Gold")
			end
		else
			local from, to = mode.From and byTier[mode.From], mode.To and byTier[mode.To]
			if from and to then
				line(tx(TXT, "ConfirmMove", from.Name, from.Plus, to.Name, math.min(max, to.Plus + from.Plus), pct(sdef.Chance)), "Gold")
				line(tx(TXT, "FailKeep"), "Sub")
				go = "Move"
			elseif from then
				line(tx(TXT, "PickTo", from.Plus), "Gold")
			else
				line(tx(TXT, "PickFrom"), "Gold")
			end
		end
		if go then
			if pending and pending.Kind == "Use" and not pending.Answered then
				act(go, tx(TXT, "Checking"), false, "Free")
			elseif ctx.Combat then
				act(go, tx(TXT, "InFight"), false, "Free") -- the button says why (A23-130: no second line)
			else
				act(go, tx(TXT, go), pending == nil, "Free")
			end
		end
		act("Cancel", tx(TXT, "Cancel"), true, "Button")
		return view
	end
	if type(cell) ~= "table" then return view end
	local g = gradeDef(cell.Grade)
	view.Title, view.Icon, view.Grade, view.Plus, view.Count = cell.Name, cell.Icon, cell.Grade, cell.Plus, cell.Count
	view.Color = (cell.Kind == "Weapon" or cell.Kind == "Spare") and g.Color or (cell.Color or g.Color)
	view.Sub = string.rep("★", g.Stars or 1) .. " " .. tx(g, "Name") .. (cell.Kind == "Spare" and (" · " .. tx(TXT, "Spare")) or "")
	view.SubColor = g.Color
	local level = math.max(1, math.floor(num(ctx.Level, 1)))
	if cell.Kind == "Weapon" or cell.Kind == "Spare" then
		line(tx(TXT, "Attack", Util.FormatInt(math.floor(Config.WeaponDamage(cell.Tier, level, cell.Plus)))))
		if cell.Kind == "Spare" then
			if cell.Count > 1 then line(tx(TXT, "Count", cell.Count)) end
			return view
		end
		local now = type(ctx.PowerNow) == "number" and ctx.PowerNow or nil
		local with = type(ctx.Power) == "function" and ctx.Power(cell.Tier, cell.Plus) or nil
		if cell.Equipped and now then
			line(tx(TXT, "PowerNow", Util.FormatInt(now)))
		elseif now and with and Config.WeaponUsable(cell.Tier, level) then -- a locked weapon: no power it can't give yet
			line(tx(TXT, "Power", Util.FormatInt(now), Util.FormatInt(with)), with > now and "Good" or (with < now and "Sub" or nil))
		end
		local source = Config.WeaponSource(cell.Tier)
		if type(source) == "string" and source ~= "" then
			local info = Config.WeaponInfo[cell.Tier]
			line(info and tx(info, "Source") or source, "Sub")
		end
		if cell.Equipped then
			act("Equip", tx(TXT, "Equipped"), false, "Button")
		elseif not Config.WeaponUsable(cell.Tier, level) then
			act("Equip", tx(TXT, "FromLv", math.floor(num(Config.Weapons[cell.Tier].MinLevel, 1))), false, "Button")
		elseif pending and pending.Kind == "Equip" and pending.Tier == cell.Tier then
			act("Equip", tx(TXT, "Checking"), false, "Free")
		elseif ctx.Combat then
			act("Equip", tx(TXT, "InFight"), false, "Free")
		else
			act("Equip", tx(TXT, "Equip"), pending == nil, "Free")
		end
	elseif cell.Kind == "Potion" then
		line(tx(TXT, "Count", cell.Count))
		local p = type(ctx.Potion) == "function" and ctx.Potion(cell.Id) or { Count = cell.Count }
		local text, ok = BagUI.PotionState(p)
		act("Drink", text, ok, "Free")
		view.Quick = cell.Id
	elseif cell.Kind == "Enhance" or cell.Kind == "Transfer" then
		local def = Config.Loot.Items[cell.Id]
		line(tx(TXT, "Count", cell.Count))
		if cell.Kind == "Enhance" then
			line(tx(TXT, "ScrollEnh", math.floor(num(def.Plus, 0)), pct(def.Chance)))
		else
			line(tx(TXT, "ScrollMove", pct(def.Chance)))
		end
		if ctx.Combat then
			act("Use", tx(TXT, "InFight"), false, "Buy")
		else
			act("Use", tx(TXT, "Use"), true, "Buy")
		end
	else
		local def = Config.Loot.Items[cell.Id]
		line(tx(TXT, "Count", cell.Count))
		-- the Forge's sell-all takes monster materials only: a gathered / boss thing (a Source) shows no price until it can be
		-- sold one at a time (SellItem, later) - 게임성 검수 10/12
		if def and def.Source == nil and num(def.Sell, 0) > 0 then line(tx(TXT, "SellsFor", Util.FormatInt(math.floor(def.Sell)))) end
		local from = dropsFrom(cell.Id, ctx.Seen)
		if from then line(tx(TXT, "From", from), "Sub") end
	end
	return view
end

---------------------------------------------------------------------------------------------------- data
-- the owner's "Inventory" payload: known item ids with a count >= 1, +N per tier, the seen monsters, the order numbers
-- and (A23-127, later) the spares; anything else is ignored
function BagUI.OnInventory(payload)
	if type(payload) ~= "table" then return end
	local loot = Config.Loot
	local items, enh, seen, iseq, wseq, spares = {}, {}, {}, {}, {}, {}
	for id, n in type(payload.Items) == "table" and payload.Items or {} do
		local c = num(n, 0)
		if type(id) == "string" and loot.Items[id] ~= nil and c >= 1 then items[id] = math.floor(c) end
	end
	local src = type(payload.Enhance) == "table" and payload.Enhance or {}
	for tier = 1, Config.MaxWeaponTier do enh[tier] = enhOf(src, tier) end
	for kind, v in type(payload.Seen) == "table" and payload.Seen or {} do
		if type(kind) == "string" and v == true and loot.Tables[kind] then seen[kind] = true end
	end
	for k, v in type(payload.ItemSeq) == "table" and payload.ItemSeq or {} do
		if type(k) == "string" and num(v, nil) then iseq[k] = math.max(0, math.floor(v)) end
	end
	local ws = type(payload.WeaponSeq) == "table" and payload.WeaponSeq or {}
	for tier = 1, Config.MaxWeaponTier do wseq[tier] = math.max(0, math.floor(num(ws[tier] or ws[tostring(tier)], 0))) end
	for k, v in type(payload.Spares) == "table" and payload.Spares or {} do
		if type(k) == "string" and string.match(k, "^%d+:%d+$") and num(v, 0) >= 1 then spares[k] = math.floor(v) end
	end
	S.Data = { Items = items, Enhance = enh, Seen = seen, ItemSeq = iseq, WeaponSeq = wseq, Spares = spares }
	S.Version += 1
	if S.SeqBase == nil then
		local top = 0
		for _, v in iseq do top = math.max(top, v) end
		for _, v in wseq do top = math.max(top, v) end
		S.SeqBase = top
	end
	BagUI.Redraw()
end

-- 게임성 검수 10/12: the Inventory push can reach Panels' listener before this one is bound; take Panels' copy then
pullInventory = function()
	if S.Version > 0 then return end
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.LastInventory) ~= "function" then return end
	local ok, payload = pcall(panels.LastInventory)
	if ok and type(payload) == "table" then pcall(BagUI.OnInventory, payload) end
end

local function bind()
	local function hook(r)
		r.OnClientEvent:Connect(function(payload)
			local ok, err = pcall(BagUI.OnInventory, payload)
			if not ok then Util.Warn(TAG, "inventory error: " .. tostring(err)) end
		end)
	end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild("Inventory")
	if remote and remote:IsA("RemoteEvent") then
		hook(remote)
		return
	end
	task.spawn(function()
		local f = ReplicatedStorage:WaitForChild("Remotes", 30)
		local r = f and f:WaitForChild("Inventory", 30)
		if r and r:IsA("RemoteEvent") then hook(r) else Util.Warn(TAG, "remote missing: Inventory") end
	end)
end

-- the model's input from the cached payload + the attributes
local function context()
	local d = S.Data
	local potions = {}
	local qs = type(Config.QuickSlots) == "table" and Config.QuickSlots.Items or {}
	for item, def in qs do
		if type(def) == "table" and type(def.Stock) == "string" then potions[item] = num(attr(def.Stock), 0) end
	end
	local class = attr("Class")
	return { Items = d.Items, Enhance = d.Enhance, ItemSeq = d.ItemSeq, WeaponSeq = d.WeaponSeq, Spares = d.Spares,
		Mask = num(attr("WeaponOwnedMask"), 0), Equipped = num(attr("WeaponTier"), 0), Level = num(attr("Level"), 1),
		Class = (type(class) == "string" and Config.Classes[class]) and class or "Warrior",
		Faction = type(attr("Faction")) == "string" and attr("Faction") or "None", Potions = potions,
		SeqBase = S.SeqBase, SeenSeq = S.SeenSeq }
end

local function inCombat()
	return num(attr("InCombatUntil"), 0) > Util.Now()
end

local function potionInput(item)
	local def = Config.QuickSlots.Items[item]
	if type(def) ~= "table" then return { Count = 0 } end
	local amount, max = 0, 1
	if def.Kind == "HP" then
		local hum = Util.GetHumanoid(LocalPlayer)
		if hum then amount, max = hum.Health, hum.MaxHealth end
	else
		amount, max = num(attr("Mana"), 0), num(attr("MaxMana"), num(Config.Vitals.MaxMana, 100))
	end
	local sip = type(Config.FirstKO) == "table" and Config.FirstKO.SipAttr or "PotionSip"
	local kaiju = attr("KaijuState")
	return { Count = num(attr(def.Stock), 0), ReadyAt = num(attr(def.ReadyAt), 0), Now = workspace:GetServerTimeNow(),
		Amount = amount, Max = max, Sip = attr(sip) == true,
		Busy = attr("DataLoaded") ~= true or not Util.IsAlive(LocalPlayer) or kaiju == "Active" or kaiju == "Siren"
			or os.clock() < (S.ReadyAt.UsePotion or 0) }
end

-- seconds between two sends of one remote (the server's rate limit + a margin)
local function gap(key)
	local v = num(type(Config.RateLimits) == "table" and Config.RateLimits[key], 0.4)
	return math.max(0, v) + L.GapMargin
end

-- sends one request unless one is waiting or the server would still drop it; true when sent
local function send(key, pending, ...)
	local kit = VIEW.Kit
	local now = os.clock()
	if not kit or (pending and S.Pending) or now < (S.ReadyAt[key] or 0) then return false end
	kit.Fire(key, ...)
	S.ReadyAt[key] = now + gap(key)
	if pending then
		pending.SentAt, pending.ReadyAt = now, S.ReadyAt[key]
		S.Pending, S.Note = pending, nil
	end
	return true
end

-- a waiting request answered (the count / weapon changed, a newer result) and past the server's interval, or timed
-- out; true when something changed
local function checkPending()
	local p = S.Pending
	if not p then return false end
	local now, changed = os.clock(), false
	if not p.Answered then
		local done = false
		if p.Kind == "Use" then
			done = math.floor(num(S.Data.Items[p.Item], 0)) ~= p.Count or S.ResultAt > p.SentAt
		elseif p.Kind == "Equip" then
			done = math.floor(num(attr("WeaponTier"), 0)) ~= p.WeaponTier
		end
		if done then
			p.Answered, changed = true, true
		elseif now - p.SentAt >= L.PendingTimeout then
			S.Pending = nil -- 게임성 검수 10/12: a refusal already got the server's toast; no second line (A23-130)
			return true
		end
	end
	if p.Answered and now >= (p.ReadyAt or 0) then S.Pending, changed = nil, true end
	return changed
end

-- the newest scroll result Panels got from the Fx "Enhance" payload
local function pollResult()
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.LastEnhance) ~= "function" then return false end
	local ok, r, at = pcall(panels.LastEnhance)
	if not ok or type(r) ~= "table" or type(at) ~= "number" or at <= S.ResultAt then return false end
	S.Result, S.ResultAt = r, at
	return true
end

-- the new things of a tab the player has looked at stop being new
local function markSeen(tab)
	for _, c in BagUI.Cells(context()) do
		if c.Tab == tab and c.New then S.SeenSeq[c.Key] = c.Seq end
	end
end

---------------------------------------------------------------------------------------------------- drawing
local function ui() return C and C.UIKit end

local function scaleOf()
	local kit = ui()
	local gui = type(kit) == "table" and kit.Gui or nil
	local sc = gui and gui:FindFirstChildOfClass("UIScale")
	local s = sc and sc.Scale or 1
	return (type(s) == "number" and s > 0.05) and s or 1
end

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
	if props and props.Style == false then return l end -- a tiny caption that shrinks to fit (no text-size floor)
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

-- one approved grade slot (an ImageButton when onClick) with the icon in its Inner box; nil art = UIKit's fallback.
-- mark = { Text, Color }: what shows when the icon has no art yet (UiSandbox 10/12: Petal / Captain's Badge were blank)
local function slot(parent, gradeId, icon, size, onClick, name, mark)
	local kit = ui()
	local part = gradeId and L.Slot[gradeId] or "SlotEmpty"
	local box
	if onClick then
		box = kit.ArtButton(part, { Name = name or "Cell", Size = UDim2.fromOffset(size, size), Parent = parent }, onClick,
			{ BackgroundColor3 = Color3.fromRGB(16, 20, 40), CornerRadius = UDim.new(0, 10),
				StrokeColor = gradeId and gradeDef(gradeId).Color or Color3.fromRGB(60, 66, 96), StrokeThickness = 2 })
	else
		box = kit.ArtFrame(part, { Name = name or "Cell", Size = UDim2.fromOffset(size, size), Parent = parent },
			{ BackgroundColor3 = Color3.fromRGB(16, 20, 40), CornerRadius = UDim.new(0, 10),
				StrokeColor = gradeId and gradeDef(gradeId).Color or Color3.fromRGB(60, 66, 96), StrokeThickness = 2 })
	end
	if icon then
		local props = { Name = "Icon", Position = UDim2.fromScale(L.Inner.X, L.Inner.Y), Size = UDim2.fromScale(L.Inner.W, L.Inner.H),
			ScaleType = Enum.ScaleType.Fit, ZIndex = (tonumber(box.ZIndex) or 1) + 1 }
		local img = kit.ItemIcon(icon, props)
		if img then
			img.Parent = box
		elseif type(mark) == "table" and type(mark.Text) == "string" then
			local letter = string.upper(string.match(mark.Text, "%w") or "?")
			label(box, letter, math.floor(size * 0.42), typeof(mark.Color) == "Color3" and mark.Color or Color3.new(1, 1, 1),
				{ Name = "Letter", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(L.Inner.W, L.Inner.H), TextXAlignment = Enum.TextXAlignment.Center,
					TextWrapped = false, ZIndex = props.ZIndex, Style = "Number" })
		end
	end
	return box
end

-- the corner words of a cell: count bottom-right (not at 1), +N top-left
local function corners(box, cell)
	local z = (tonumber(box.ZIndex) or 1) + 3
	if cell.Count > 1 or (cell.Kind == "Potion" and cell.Count <= 0) then
		label(box, tostring(cell.Count), L.Size.Count, Color3.new(1, 1, 1), { Name = "Count", AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -1), Size = UDim2.new(1, -8, 0, L.Size.Count + 2), TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false, ZIndex = z, Style = "Number" })
	end
	if cell.Plus > 0 then
		label(box, "+" .. tostring(cell.Plus), L.Size.Count, colorOf("Gold"), { Name = "Plus", Position = UDim2.fromOffset(4, 1),
			Size = UDim2.new(1, -8, 0, L.Size.Count + 2), TextWrapped = false, ZIndex = z, Style = "Number" })
	end
	local kit = ui()
	if cell.Equipped then
		local check = kit.ArtImage("GlyphCheck", { Name = "Equipped", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 2),
			Size = UDim2.fromOffset(18, 18), ImageColor3 = colorOf("Gold"), ZIndex = z })
		if check then check.Parent = box end
	elseif cell.New then
		local dot = kit.ArtImage("BadgeDot", { Name = "New", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -1, 0, 1),
			Size = UDim2.fromOffset(14, 14), ZIndex = z })
		if dot then dot.Parent = box end
	end
end

local function selectStroke(box)
	local f = Instance.new("Frame")
	f.Name = "Picked"
	f.BackgroundTransparency = 1
	f.Position = UDim2.fromOffset(3, 3)
	f.Size = UDim2.new(1, -6, 1, -6)
	f.ZIndex = (tonumber(box.ZIndex) or 1) + 4
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.14, 0)
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
		if not ch:IsA("UIGridLayout") and not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
end

local function sortMode()
	local m = setting("BagSort", "Default")
	return table.find(L.Sorts, m) and m or "Default"
end

local function isWide()
	return setting("BagWide", false) == true
end

-- the cells of the open tab in the saved order, and the picked one (the first when none / gone)
local function tabView()
	local all = BagUI.Cells(context())
	S.Mode = validMode(S.Mode, all)
	local list = BagUI.Sort(BagUI.TabCells(all, S.Tab), sortMode())
	local picked = nil
	for _, c in all do
		if c.Key == S.Sel then picked = c end
	end
	if (not picked or picked.Tab ~= S.Tab) and not S.Mode then
		picked = list[1]
		S.Sel = picked and picked.Key or nil
	end
	return all, list, picked
end

local function tap(cell)
	if S.Mode then
		S.Mode = BagUI.Pick(S.Mode, cell)
		S.Result, S.Note = nil, nil
	else
		S.Sel = cell.Key
		S.Note = nil
	end
	BagUI.Redraw()
end

local function drawWorn(parent, all, cols)
	local frame = Instance.new("Frame")
	frame.Name = "Worn"
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(L.WornInset, 0)
	frame.Size = UDim2.new(0, gridW(cols) - L.Scroll, 0, L.Cell + L.WornCap)
	frame.Parent = parent
	local weapon = nil
	for _, c in all do
		if c.Kind == "Weapon" and c.Equipped then weapon = c end
	end
	for i, kind in L.Worn do
		local x = (i - 1) * (L.Cell + L.Gap)
		local box
		if kind == "Weapon" and weapon then
			box = slot(frame, weapon.Grade, weapon.Icon, L.Cell, function() tap(weapon) end, "Worn" .. kind, { Text = weapon.Name })
			corners(box, { Count = 1, Plus = weapon.Plus, Equipped = false })
			if S.Sel == weapon.Key and not S.Mode then selectStroke(box) end
		else
			box = slot(frame, nil, nil, L.Cell, nil, "Worn" .. kind)
		end
		box.Position = UDim2.fromOffset(x, 0)
		-- the word fits its own column (UiSandbox 10/12: on a very short window the styled text floor cut "Weapon"):
		-- a plain caption scaled down to fit, at most Size.Small
		local cap = label(frame, tx(TXT.Worn, kind), L.Size.Small, colorOf("Sub"), { Name = "WornCap" .. kind,
			Position = UDim2.fromOffset(x - L.WornInset, L.Cell + 2), Size = UDim2.fromOffset(L.Cell + 2 * L.WornInset, L.WornCap - 2),
			TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextScaled = true, Style = false })
		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = L.Size.Small
		tc.Parent = cap
	end
	return L.Cell + L.WornCap + L.RowGap
end

local function drawGrid(area, all, list, cols)
	local top = 0
	if S.Tab == "Gear" then top = drawWorn(area, all, cols) end
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(0, top)
	grid.Size = UDim2.new(1, 0, 1, -top)
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	grid.ScrollBarThickness = 6
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(L.Cell, L.Cell)
	layout.CellPadding = UDim2.fromOffset(L.Gap, L.Gap)
	layout.FillDirectionMaxCells = cols
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	grid.Parent = area
	VIEW.Grid = grid
	for i, cell in list do
		local box = slot(grid, cell.Grade, cell.Icon, L.Cell, function() tap(cell) end, "Cell_" .. cell.Key,
			{ Text = cell.Name, Color = cell.Color })
		box.LayoutOrder = i
		corners(box, cell)
		if cell.Kind == "Potion" and cell.Count <= 0 then
			local icon = box:FindFirstChild("Icon")
			if icon then icon.ImageTransparency = 0.55 end
		end
		if S.Mode then
			if not BagUI.CellEnabled(S.Mode, cell) then
				box.ImageTransparency = 0.55
				local icon = box:FindFirstChild("Icon")
				if icon then icon.ImageTransparency = 0.55 end
			end
			local m = S.Mode
			if cell.Kind == "Weapon" and (m.Tier == cell.Tier or m.From == cell.Tier or m.To == cell.Tier) then selectStroke(box) end
		elseif cell.Key == S.Sel then
			selectStroke(box)
		end
	end
	-- empty dark slots fill the rows on screen and the last row (no slot limit, A23-32)
	local h = select(2, BagUI.LayoutSize()) - top
	local rows = h > L.Cell and math.floor((h + L.Gap) / (L.Cell + L.Gap)) or 6
	local total = math.max(rows * cols, math.ceil(#list / cols) * cols)
	for i = #list + 1, total do
		local box = slot(grid, nil, nil, L.Cell, nil, "Empty")
		box.LayoutOrder = i
	end
end

local function drawDetail(frame, all, picked)
	clear(frame)
	local kit = VIEW.Kit
	local view = BagUI.Detail(picked, {
		Level = num(attr("Level"), 1), Combat = inCombat(), Pending = S.Pending, Mode = S.Mode, Seen = S.Data.Seen,
		Note = S.Note, Cells = all,
		PowerNow = type(Config.CombatPowerOf) == "function" and Config.CombatPowerOf(LocalPlayer) or nil,
		Power = function(tier, plus) return Config.CombatPowerOf(LocalPlayer, tier, plus) end,
		Potion = potionInput,
	})
	VIEW.DetailSig = nil
	if not view.Title then return view end
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = frame
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local big = slot(frame, view.Grade, view.Icon, L.Big, nil, "Big", { Text = view.Title, Color = view.Color })
	big.LayoutOrder = nextOrder()
	if type(picked) == "table" and picked.Kind == "Potion" and picked.Count <= 0 and not S.Mode then
		local icon = big:FindFirstChild("Icon")
		if icon then icon.ImageTransparency = 0.55 end
	end
	if view.Plus or view.Count then corners(big, { Count = view.Count or 1, Plus = view.Plus or 0 }) end
	label(frame, view.Title, L.Size.Name, view.Color or colorOf("Text"), { Name = "Name", Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder(), Style = "Title" })
	if view.Sub then
		label(frame, view.Sub, L.Size.Small, view.SubColor or colorOf("Sub"), { Name = "Grade", Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = nextOrder() })
	end
	for i, ln in view.Lines do
		label(frame, ln.Text, ln.Color == "Sub" and L.Size.Small or L.Size.Body, colorOf(ln.Color), { Name = "Line" .. i,
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() })
	end
	if view.Status then
		label(frame, view.Status.Text, L.Size.Body, colorOf(view.Status.Color), { Name = "Status", Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() })
	end
	local palette = kit.Palette or {}
	for _, a in view.Actions do
		local color = a.Color == "Free" and palette.Free or (a.Color == "Buy" and palette.Buy or palette.Button)
		local b = kit.Button(frame, a.Text, color, UDim2.new(1, 0, 0, L.BtnH), function() BagUI.Act(a.Id, picked) end)
		b.Name = "Act_" .. a.Id
		b.LayoutOrder = nextOrder()
		kit.SetEnabled(b, a.Enabled)
	end
	if view.Quick then
		local qs = C and C.QuickSlots
		local cur = (type(qs) == "table" and type(qs.Get) == "function") and qs.Get() or {}
		label(frame, tx(TXT, "Quick"), L.Size.Small, colorOf("Sub"), { Name = "QuickTitle", Size = UDim2.new(1, 0, 0, L.Size.Small + 4),
			LayoutOrder = nextOrder() })
		local row = Instance.new("Frame")
		row.Name = "Quick"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, L.BtnH)
		row.LayoutOrder = nextOrder()
		local rl = Instance.new("UIListLayout")
		rl.FillDirection = Enum.FillDirection.Horizontal
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		rl.Padding = UDim.new(0, 6)
		rl.Parent = row
		row.Parent = frame
		local count = num(type(Config.QuickSlots) == "table" and Config.QuickSlots.Count, 3)
		for i = 1, count do
			local on = cur[i] == view.Quick
			local b = kit.Button(row, tostring(i), on and kit.Theme.Gold or palette.Button, UDim2.fromOffset(L.QuickW, L.BtnH - 2),
				function() BagUI.Act("Quick" .. i, picked) end, on and palette.DarkText or nil)
			b.Name = "Quick" .. i
			b.LayoutOrder = i
		end
	end
	return view
end

local function paintTabs(all)
	local kit = VIEW.Kit
	if not (kit and VIEW.Tabs) then return end
	local new = {}
	for _, c in all do
		if c.New then new[c.Tab] = (new[c.Tab] or 0) + 1 end
	end
	for _, id in L.Tabs do
		local b = VIEW.Tabs[id]
		if b then
			local on = S.Tab == id
			kit.Paint(b, on and kit.Theme.Gold or kit.Palette.Button, on and kit.Palette.DarkText or kit.Theme.Text)
			local old = b:FindFirstChild("NewCount")
			if old then old:Destroy() end
			local n = (not on) and (new[id] or 0) or 0
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

local function roundButton(parent, name, glyph, onClick)
	local kit = ui()
	local b = kit.ArtButton("BtnRound", { Name = name, Size = UDim2.fromOffset(L.Round, L.Round), Parent = parent }, onClick,
		{ Color = VIEW.Kit and VIEW.Kit.Palette.Button, CornerRadius = UDim.new(0.5, 0) })
	local g = kit.ArtImage(glyph, { Name = "Glyph", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.6, 0.6), ZIndex = (tonumber(b.ZIndex) or 1) + 1 })
	if g then g.Parent = b end
	return b
end

local function drawBar(bar)
	clear(bar)
	local kit = ui()
	local gold = math.max(0, math.floor(num(attr("BankGold"), 0) + num(attr("CarriedGold"), 0)))
	local coin = kit.ArtImage("IconCoin", { Name = "Coin", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(L.CoinW, L.CoinW) })
	if coin then coin.Parent = bar end
	label(bar, Util.FormatInt(gold), L.Size.Body, colorOf("Gold"), { Name = "Gold", AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, L.CoinW + 6, 0.5, 0), Size = UDim2.new(0.4, 0, 1, 0), TextWrapped = false, Style = "Number" })
	local wide = isWide()
	local size = roundButton(bar, "Size", wide and "GlyphShrink" or "GlyphExpand", function() BagUI.Act("Size") end)
	size.AnchorPoint = Vector2.new(1, 0.5)
	size.Position = UDim2.new(1, 0, 0.5, 0)
	local sort = roundButton(bar, "Sort", "GlyphSort", function() BagUI.Act("Sort") end)
	sort.AnchorPoint = Vector2.new(1, 0.5)
	sort.Position = UDim2.new(1, -(L.Round + 8), 0.5, 0)
	label(bar, tx(TXT.Sorts, sortMode()), L.Size.Small, colorOf("Text"), { Name = "SortName", AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(2 * L.Round + 16), 0.5, 0), Size = UDim2.fromOffset(90, L.Round),
		TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
end

-- the whole body again (data / tab / sort / size changes); the grid keeps its scroll
function BagUI.Redraw()
	local body = VIEW.Body
	if not (VIEW.Kit and body and body.Parent) then return end
	local keptY = VIEW.Grid and VIEW.Grid.Parent and VIEW.Grid.CanvasPosition.Y or 0
	local keepTab = VIEW.GridTab == S.Tab
	checkPending()
	local all, list, picked = tabView()
	S.Shown[S.Tab] = true
	local width = BagUI.LayoutSize()
	local cols = BagUI.Columns(width, isWide())
	VIEW.Cols = cols
	VIEW.LayoutSig = BagUI.LayoutSig()
	clear(body)
	local area = Instance.new("Frame")
	area.Name = "GridArea"
	area.BackgroundTransparency = 1
	area.Size = UDim2.new(0, gridW(cols), 1, 0)
	area.Parent = body
	drawGrid(area, all, list, cols)
	if keepTab and VIEW.Grid then VIEW.Grid.CanvasPosition = Vector2.new(0, keptY) end
	VIEW.GridTab = S.Tab
	-- the detail scrolls when a short screen can't hold it all
	local detail = Instance.new("ScrollingFrame")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.BorderSizePixel = 0
	detail.Position = UDim2.fromOffset(gridW(cols) + L.Split, 0)
	detail.Size = UDim2.new(1, -(gridW(cols) + L.Split), 1, 0)
	detail.CanvasSize = UDim2.new()
	detail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detail.ScrollingDirection = Enum.ScrollingDirection.Y
	detail.ScrollBarThickness = 4
	detail.Parent = body
	VIEW.Detail = detail
	VIEW.Picked = picked
	drawDetail(detail, all, picked)
	VIEW.Sig = BagUI.LiveSig(picked)
	paintTabs(all)
	if VIEW.Bar then drawBar(VIEW.Bar) end
end

-- the detail column again (a request answered, the fight tag, a potion's cooldown), its scroll kept; anything that
-- changes the grid (a scroll step dropping back, the picked thing gone) redraws the whole body
function BagUI.RedrawDetail()
	local d = VIEW.Detail
	if not (VIEW.Kit and d and d.Parent) then return end
	checkPending()
	local all = BagUI.Cells(context())
	if validMode(S.Mode, all) ~= S.Mode then
		BagUI.Redraw()
		return
	end
	local picked = nil
	for _, c in all do
		if c.Key == S.Sel then picked = c end
	end
	if not S.Mode and (not picked or picked.Tab ~= S.Tab) then
		BagUI.Redraw()
		return
	end
	local y = d.CanvasPosition.Y
	VIEW.Picked = picked
	drawDetail(d, all, picked)
	d.CanvasPosition = Vector2.new(0, y)
	VIEW.Sig = BagUI.LiveSig(picked)
end

-- the window's content width and the grid area's height (du; not measured yet: the asked width, 0)
function BagUI.LayoutSize()
	local parent = VIEW.Parent
	local s = scaleOf()
	local w = parent and parent.AbsoluteSize.X / s or 0
	if w < 1 then w = BagUI.WindowWidth(isWide()) - 2 * L.Pad end
	local h = parent and parent.AbsoluteSize.Y / s or 0
	h = h >= 1 and (h - L.TabH - L.BarH - 2 * L.RowGap) or 0
	return w, h
end

-- columns x rows on screen: a change redraws the grid
function BagUI.LayoutSig()
	local w, h = BagUI.LayoutSize()
	return tostring(BagUI.Columns(w, isWide())) .. "x" .. tostring(math.floor((h + L.Gap) / (L.Cell + L.Gap)))
end

-- what the 0.25 s update watches without a data change: the fight tag, a potion's state, the pending request
function BagUI.LiveSig(picked)
	local parts = { inCombat() and "c" or "", S.Pending and (S.Pending.Answered and "a" or "p") or "", S.Note or "" }
	if type(picked) == "table" and picked.Kind == "Potion" then
		local text, ok = BagUI.PotionState(potionInput(picked.Id))
		table.insert(parts, text .. tostring(ok))
	end
	return table.concat(parts, "|")
end

function BagUI.ShowTab(id)
	if not table.find(L.Tabs, id) then return end
	if id ~= S.Tab then
		markSeen(S.Tab)
		S.Mode, S.Result = nil, nil
	end
	S.Tab = id
	BagUI.Redraw()
end

-- button handlers (cell = the picked cell when the detail was drawn)
function BagUI.Act(id, cell)
	local kit = VIEW.Kit
	if not kit then return end
	if id == "Sort" then
		local i = table.find(L.Sorts, sortMode()) or 1
		local st = C and C.Settings
		if type(st) == "table" and type(st.Set) == "function" then pcall(st.Set, "BagSort", L.Sorts[i % #L.Sorts + 1]) end
		BagUI.Redraw()
	elseif id == "Size" then
		local st = C and C.Settings
		if type(st) == "table" and type(st.Set) == "function" then pcall(st.Set, "BagWide", not isWide()) end
		kit.Rebuild(true) -- Panels lays the window out again at the new width (opts.Width)
	elseif id == "Equip" and type(cell) == "table" and cell.Kind == "Weapon" then
		if inCombat() then return end
		if send("EquipWeapon", { Kind = "Equip", Tier = cell.Tier, WeaponTier = math.floor(num(attr("WeaponTier"), 0)) }, cell.Tier) then
			BagUI.Redraw()
		end
	elseif id == "Drink" and type(cell) == "table" and cell.Kind == "Potion" then
		local def = Config.QuickSlots.Items[cell.Id]
		local _, ok = BagUI.PotionState(potionInput(cell.Id))
		if ok and def and send("UsePotion", nil, def.Kind) then BagUI.Redraw() end
	elseif string.sub(id, 1, 5) == "Quick" and type(cell) == "table" and cell.Kind == "Potion" then
		local i = tonumber(string.sub(id, 6))
		local qs = C and C.QuickSlots
		if i and type(qs) == "table" and type(qs.Set) == "function" then
			local cur = type(qs.Get) == "function" and qs.Get() or {}
			pcall(qs.Set, i, cur[i] == cell.Id and "" or cell.Id)
		end
		BagUI.Redraw()
	elseif id == "Use" and type(cell) == "table" and (cell.Kind == "Enhance" or cell.Kind == "Transfer") then
		if inCombat() then return end
		markSeen(S.Tab)
		S.Mode, S.Result, S.Note = { Item = cell.Id }, nil, nil
		S.Tab = "Gear"
		BagUI.Redraw()
	elseif id == "Cancel" then
		local item = S.Mode and S.Mode.Item
		S.Mode, S.Result, S.Note = nil, nil, nil
		if item then
			S.Tab, S.Sel = "Scroll", "I:" .. item
		end
		BagUI.Redraw()
	elseif (id == "Enhance" or id == "Move") and S.Mode then
		if inCombat() then return end
		local m = S.Mode
		local args = id == "Enhance" and { m.Item, m.Tier } or { m.Item, m.From, m.To }
		if (id == "Enhance" and not m.Tier) or (id == "Move" and not (m.From and m.To)) then return end
		if send("UseItem", { Kind = "Use", Item = m.Item, Count = math.floor(num(S.Data.Items[m.Item], 0)) }, table.unpack(args)) then
			S.Result = nil
			BagUI.Redraw()
		end
	end
end

---------------------------------------------------------------------------------------------------- the window
local function build(parent, kit, arg)
	VIEW = { Kit = kit, Parent = parent, Tabs = {} }
	S.Shown = {}
	pullInventory()
	-- 게임성 검수 10/12: Panels hands every rebuild (a size change) the arg of its last Open; one arg table is applied
	-- once, so a rebuild never jumps back to the opening tab / a cancelled scroll step
	if arg == S.LastArg then arg = nil else S.LastArg = arg end
	if type(arg) == "table" and table.find(L.Tabs, arg.Tab) then
		S.Tab, S.Mode = arg.Tab, nil
		if type(arg.Select) == "string" then S.Sel = arg.Select end
	end
	-- arg.Use = a scroll id: straight into its step (a scroll notice / Studio photos), with arg.Tier (enhance) or
	-- arg.From / arg.To (transfer) already picked; the step drops back to what is valid (validMode)
	local use = type(arg) == "table" and type(arg.Use) == "string" and Config.Loot.Items[arg.Use] or nil
	if use and use.Kind ~= "Material" then
		S.Tab, S.Sel, S.Result, S.Note = "Gear", "I:" .. arg.Use, nil, nil
		S.Mode = { Item = arg.Use, Tier = tonumber(arg.Tier), From = tonumber(arg.From), To = tonumber(arg.To) }
	end
	-- tabs (the Panels capsules, gold = open: the same look as the quest and settings tabs)
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, L.TabH)
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Padding = UDim.new(0, 6)
	bl.Parent = bar
	bar.Parent = parent
	local n = #L.Tabs
	for i, id in L.Tabs do
		local b = kit.Button(bar, tx(TXT.Tabs, id), kit.Palette.Button, UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), function()
			BagUI.ShowTab(id)
		end)
		b.Name = "Tab_" .. id
		b.LayoutOrder = i
		VIEW.Tabs[id] = b
	end
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(0, L.TabH + L.RowGap)
	body.Size = UDim2.new(1, 0, 1, -(L.TabH + L.BarH + 2 * L.RowGap))
	body.Parent = parent
	VIEW.Body = body
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.new(0, 0, 1, 0)
	bottom.Size = UDim2.new(1, 0, 0, L.BarH)
	bottom.Parent = parent
	VIEW.Bar = bottom
	-- data changes redraw in place (Rebuild = false: no full window rebuild)
	kit.OnAttr(function(name)
		if BagUI.WatchBar[name] then -- 게임성 검수 10/12: a coin picked up repaints the gold line, not the grid
			if VIEW.BarQueued then return end
			VIEW.BarQueued = true
			task.defer(function()
				VIEW.BarQueued = false
				if VIEW.Kit == kit and VIEW.Bar then drawBar(VIEW.Bar) end
			end)
		elseif BagUI.Watch[name] then
			if VIEW.Queued then return end
			VIEW.Queued = true
			task.defer(function()
				VIEW.Queued = false
				BagUI.Redraw()
			end)
		end
	end)
	-- the first real layout / a screen size change: redraw when the columns or the rows on screen change (the body
	-- frame stays between builds: the connection goes with the window, cleanup)
	VIEW.SizeConn = parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if VIEW.Kit ~= kit then return end
		if BagUI.LayoutSig() ~= VIEW.LayoutSig then BagUI.Redraw() end
	end)
	BagUI.Redraw()
	-- Panels' 0.25 s update: an answered / timed-out request, a new scroll result, the fight tag or a potion's state
	return function()
		if VIEW.Kit ~= kit then return end
		local changed = checkPending()
		if pollResult() then
			changed = true
			if S.Pending and S.Pending.Kind == "Use" then checkPending() end
		end
		if changed or BagUI.LiveSig(VIEW.Picked) ~= VIEW.Sig then BagUI.RedrawDetail() end
	end
end

-- attributes that redraw the open bag
BagUI.Watch = { WeaponOwnedMask = true, WeaponTier = true, WeaponEnhance = true, Level = true, Class = true, Faction = true,
	HPPotionCount = true, MPPotionCount = true, DataLoaded = true, QuickSlots = true }
BagUI.WatchBar = { BankGold = true, CarriedGold = true } -- only the gold line

local function cleanup()
	local conn = VIEW.SizeConn
	if conn and type(conn.Disconnect) == "function" then pcall(conn.Disconnect, conn) end
	markSeen(S.Tab)
	S.Mode, S.Result, S.Note = nil, nil, nil
	VIEW = {}
end

function BagUI.IsReady()
	return S.Ready
end

-- opens the bag (on a tab: "Gear" | "Use" | "Scroll" | "Material")
function BagUI.Open(tab)
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Open) ~= "function" then return end
	panels.Open(L.Window, type(tab) == "string" and { Tab = tab } or nil)
end

function BagUI.Init(registry)
	C = registry
	bind() -- before any Start, so the first Inventory payload is never missed
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the bag is off")
		return
	end
	S.Ready = panels.Register(L.Window, {
		Build = build,
		Title = function() return tx(TXT, "Title") end,
		FixedBody = true,
		Rebuild = false,
		Width = function() return BagUI.WindowWidth(isWide()) end,
		Cleanup = cleanup,
	}) == true
end

function BagUI.Start()
	pullInventory()
end

-- offline tests
BagUI._T = { TXT = TXT, L = L, S = S }

return BagUI
