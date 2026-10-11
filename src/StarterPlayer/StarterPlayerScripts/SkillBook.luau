-- SkillBook.luau (게임성 개발 1, BB9 스킬 창; SPEC A23-49 / A23-60 / A23-71 / A23-78 / A23-113 / A23-116, design
-- docs/design/skill_kit_beta_2026-10-06.md §6-4, docs/design/skills18_2026-10-10.md "스킬 창 글(진영 줄)"): the Panels
-- window "Skills" the HUD's Skills tile and the K key open (both stay locked until the first skill, Config.HudReveal).
--   rows    : the basic attack, then Q · Z · X (a slot whose flag is off - Config.Skills.ZEnabled / XEnabled - has no
--             row, like SkillBar). A row = the skill icon (the SkillBar order: Skill_<Class>_<Slot>_<Faction>, the kit
--             icon, the base class's), the name (Config.SkillDef: the faction's own name), the key (keyboards only,
--             Keybinds.Label), DescEn, one numbers line (MP · cooldown · shape · hit) and the faction line: Q / Z
--             Config.Skills.Text.QZHalo / QZHorns, X XHalo / XHorns / XArtisan (A23-116, dev3's words)
--   state   : live from the attributes (Panels' 0.25 s update): Ready / seconds left (SkillReadyAt*) / Need MP (Mana) /
--             "Unlocks at Lv N" + [Where to hunt] (the Travel window, its Recommended zone) for a slot not learned yet
--   passive : my class's stat lines, my faction's perks, my fall / redeem marks (Config.Rebirth)
--   keys    : [Change keys] opens Settings on its Keys tab (keyboards only)
-- PC first (A23-98); no new art (the approved skill / weapon icons, the Panels kit). Game text: English only (A23-48).
-- Presentation only: the server decides every cast. No remote.
-- Public API: SkillBook.Init(C), SkillBook.Start(), SkillBook.IsReady(), SkillBook.Open(),
-- SkillBook.Rows(ctx) -> rows, SkillBook.State(row, ctx) -> text, kind, SkillBook.Passive(ctx) -> sections (all pure;
-- ctx = { Class, Faction, Level, SkillSlots, Rebirths, Mana, Now, Ready = { Q, Z, X }, Tier, FallMarks, RedeemMarks,
-- Keyboard, Preview })
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local SkillBook = {}
local C = nil
local TAG = "SkillBook"

local T = {
	Window = "Skills",
	Slots = { "Q", "Z", "X" },
	Action = { Attack = "Attack", Q = "SkillQ", Z = "SkillZ", X = "SkillX" }, -- Keybinds actions
	Ready = { Q = "SkillReadyAt", Z = "SkillReadyAtZ", X = "SkillReadyAtX" }, -- server attributes (Util.Now time)
	Flag = { Z = "ZEnabled", X = "XEnabled" },
	SlotIndex = { Q = 1, Z = 2, X = 3 },
	Unlock = { Q = 5, Z = 15, X = 25 }, -- A23-71; Config.Skills.Unlock wins
	Reuse = { Blacksmith = "Warrior", Alchemist = "Mage" }, -- the artisan kits borrow the base class's Q / Z art
	Icon = 64, RowH = 84, RightW = 150, ButtonH = 40, -- du; a row >= 64 on phones (BB9)
	Name = 20, Body = 16, Small = 15, -- text px (>= 15, 검수 10/10)
	-- game text: English only (A23-48), short and easy; the skill words live in Config.Skills.Text
	Text = {
		Title = "Skills",
		Default = { Q = "Skill", Z = "Skill 2", X = "Skill 3" }, -- a slot whose kit has no name yet (SkillBar's words)
		Attack = "Attack",
		Punch = "Punch",
		PunchDesc = "No weapon yet. A quick punch at the closest monster.",
		Every = "%s s per hit",
		Reach = "Reach %d",
		HitsAll = "Hits all in front",
		Hits = "Hits %d",
		Splash = "Blast %d",
		MageMP = "%d MP per hit",
		Hit = "Hit x%s",
		Wait = "%.1f s",
		Passive = "Passive",
		FallMarks = "Fall marks x%d: gold +%d%%",
		RedeemMarks = "Redeem marks x%d: XP +%d%%",
		ChangeKeys = "Change keys",
		-- used only when Config.Skills.Text misses a word
		Ready = "Ready", NeedMP = "Need MP", UnlocksAt = "Unlocks at Lv%d", WhereToHunt = "Where to hunt",
		Cost = "Costs %d MP", Cooldown = "%s s cooldown",
	},
	Shape = { SelfCircle = "Circle", TargetCircle = "Circle", Roar = "Circle", Line = "Line", Chain = "Chain",
		Field = "Field", Hop = "Hop" },
}
local S = { Ready = false }
local VIEW = { Rows = {} } -- the open window's skill rows: { Row, State = TextLabel, Button = GuiObject? }

local function num(v, d)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
	return v
end

local function words()
	local s = type(Config.Skills) == "table" and Config.Skills or {}
	return type(s.Text) == "table" and s.Text or {}
end

-- a skill word from Config.Skills.Text, else ours
local function word(key)
	local w = words()[key]
	if type(w) == "string" and w ~= "" then return w end
	return T.Text[key] or ""
end

-- 3 -> "3", 1.5 -> "1.5"
local function short(n)
	n = num(n, 0)
	if math.abs(n - math.floor(n + 0.5)) < 1e-6 then return tostring(math.floor(n + 0.5)) end
	return string.format("%.1f", n)
end

local function classOf(ctx)
	local c = ctx.Class
	if type(c) ~= "string" or type(Config.Classes) ~= "table" or not Config.Classes[c] then return "Warrior" end
	return c
end

local function factionOf(ctx)
	local f = ctx.Faction
	if type(f) ~= "string" or f == "" then return "None" end
	return f
end

local function slotOn(slot, ctx)
	if slot == "Q" then return true end
	local s = type(Config.Skills) == "table" and Config.Skills or {}
	return s[T.Flag[slot]] == true or ctx.Preview == true
end

local function unlockLevel(slot)
	local u = type(Config.Skills) == "table" and Config.Skills.Unlock or nil
	return math.floor(num(type(u) == "table" and u[slot] or nil, T.Unlock[slot] or 1))
end

-- learned: the saved SkillSlots or what the level / rebirths open (Config.SkillSlotsFor, the server's rule)
local function learned(slot, ctx)
	local idx = T.SlotIndex[slot] or 99
	if num(ctx.SkillSlots, 0) >= idx then return true end
	if type(Config.SkillSlotsFor) == "function" then
		local ok, n = pcall(Config.SkillSlotsFor, num(ctx.Level, 1), num(ctx.Rebirths, 0))
		if ok and num(n, 0) >= idx then return true end
	end
	return num(ctx.Level, 1) >= unlockLevel(slot)
end

local function kitOf(class, faction)
	if type(Config.SkillKit) == "function" then
		local ok, k = pcall(Config.SkillKit, class, faction)
		if ok and type(k) == "string" and k ~= "" then return k end
	end
	return class
end

-- the faction line of a slot (A23-116): Q / Z heal or steal HP, X its own extra; the artisan guild only on X
function SkillBook.FactionLine(slot, faction)
	if slot == "X" then
		if faction == "Halo" then return word("XHalo") end
		if faction == "Horns" then return word("XHorns") end
		if faction == "Neutral" then return word("XArtisan") end
		return nil
	end
	if faction == "Halo" then return word("QZHalo") end
	if faction == "Horns" then return word("QZHorns") end
	return nil
end

-- "Costs 20 MP · 3 s cooldown · Area 9 · Hit x6"
local function numbersLine(def)
	local parts = {}
	if num(def.MP, 0) > 0 then table.insert(parts, string.format(word("Cost"), math.floor(num(def.MP, 0)))) end
	if num(def.CD, 0) > 0 then table.insert(parts, string.format(word("Cooldown"), short(def.CD))) end
	local shape = T.Shape[def.Shape or ""]
	if shape == "Circle" and num(def.Radius, 0) > 0 then
		table.insert(parts, string.format(word("ShapeCircle"), math.floor(num(def.Radius, 0))))
	elseif shape == "Line" and num(def.Len, 0) > 0 then
		table.insert(parts, string.format(word("ShapeLine"), math.floor(num(def.Len, 0))))
	elseif shape == "Chain" and num(def.Hits, 0) > 0 then
		table.insert(parts, string.format(word("ShapeChain"), math.floor(num(def.Hits, 0))))
	elseif shape == "Field" and num(def.Duration, 0) > 0 then
		table.insert(parts, string.format(word("ShapeField"), math.floor(num(def.Duration, 0))))
	elseif shape == "Hop" and num(def.Hop, 0) > 0 then
		table.insert(parts, string.format(word("ShapeHop"), math.floor(num(def.Hop, 0))))
	end
	local mult = num(def.Mult, 0)
	if mult > 0 then table.insert(parts, string.format(T.Text.Hit, short(mult))) end
	return table.concat(parts, " · ")
end

local function skillRow(slot, ctx)
	local class, faction = classOf(ctx), factionOf(ctx)
	local def = nil
	if type(Config.SkillDef) == "function" then
		local ok, d = pcall(Config.SkillDef, class, faction, slot)
		if ok and type(d) == "table" then def = d end
	end
	def = def or {}
	local kit = kitOf(class, faction)
	local icons = { "Skill_" .. class .. "_" .. slot .. "_" .. faction, "Skill_" .. kit .. "_" .. slot }
	if T.Reuse[kit] then table.insert(icons, "Skill_" .. T.Reuse[kit] .. "_" .. slot) end
	table.insert(icons, "Skill_Warrior_Q")
	return {
		Slot = slot, Action = T.Action[slot],
		Name = (type(def.NameEn) == "string" and def.NameEn ~= "") and def.NameEn or T.Text.Default[slot],
		Desc = type(def.DescEn) == "string" and def.DescEn or "",
		Numbers = numbersLine(def),
		FactionLine = SkillBook.FactionLine(slot, faction),
		Faction = faction,
		Icons = icons,
		Locked = not learned(slot, ctx),
		Unlock = unlockLevel(slot),
		MP = num(def.MP, 0), CD = num(def.CD, 0),
	}
end

local function attackRow(ctx)
	local class, faction = classOf(ctx), factionOf(ctx)
	local tier = math.max(0, math.floor(num(ctx.Tier, 0)))
	local p = type(Config.AttackProfile) == "function" and Config.AttackProfile(class, tier, faction) or Config.Classes[class]
	local bare = p.Unarmed == true
	local parts = { string.format(T.Text.Every, short(p.SwingInterval)), string.format(T.Text.Reach, math.floor(num(p.Range, 0))) }
	if p.Pattern == "Around" or num(p.Targets, 1) <= 0 then
		table.insert(parts, T.Text.HitsAll)
	elseif num(p.Targets, 1) > 1 then
		table.insert(parts, string.format(T.Text.Hits, math.floor(num(p.Targets, 1))))
	end
	if p.Pattern == "Splash" and num(p.Splash, 0) > 0 then
		table.insert(parts, string.format(T.Text.Splash, math.floor(num(p.Splash, 0))))
	end
	local mageMP = type(Config.Vitals) == "table" and num(Config.Vitals.MageSwingCost, 0) or 0
	if not bare and class == "Mage" and mageMP > 0 then table.insert(parts, string.format(T.Text.MageMP, mageMP)) end
	local card = type(Config.ClassCard) == "function" and Config.ClassCard(class, faction) or nil
	local icons = { "IconAttack" }
	if not bare then
		local wc = (type(Config.IsTamer) == "function" and Config.IsTamer(class, faction)) and "Tamer" or class
		icons = { "Weapon_" .. wc .. "_T" .. tier .. "_" .. faction, "Weapon_" .. wc .. "_T" .. tier, "IconAttack" }
	end
	return {
		Slot = "Attack", Action = T.Action.Attack,
		Name = bare and T.Text.Punch or T.Text.Attack,
		Desc = bare and T.Text.PunchDesc or (type(card) == "table" and type(card.Desc) == "string" and card.Desc or ""),
		Numbers = table.concat(parts, " · "),
		Icons = icons,
		Locked = false,
	}
end

-- the window's rows: the basic attack, then each skill slot that is in the game today. Pure
function SkillBook.Rows(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local rows = { attackRow(ctx) }
	for _, slot in T.Slots do
		if slotOn(slot, ctx) then table.insert(rows, skillRow(slot, ctx)) end
	end
	return rows
end

-- a row's live state: text, kind ("lock" | "wait" | "mp" | "ready"); the attack row has none (nil). Pure
function SkillBook.State(row, ctx)
	if type(row) ~= "table" or row.Slot == "Attack" then return nil, nil end
	ctx = type(ctx) == "table" and ctx or {}
	if row.Locked then return string.format(word("UnlocksAt"), row.Unlock), "lock" end
	local ready = type(ctx.Ready) == "table" and num(ctx.Ready[row.Slot], 0) or 0
	local left = ready - num(ctx.Now, 0)
	if left > 0.05 then return string.format(T.Text.Wait, left), "wait" end
	if num(ctx.Mana, 0) < row.MP then return word("NeedMP"), "mp" end
	return word("Ready"), "ready"
end

-- the passive part: { { Title, Lines } } - my class's stats, my faction's perks, my marks. Pure
function SkillBook.Passive(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local class, faction = classOf(ctx), factionOf(ctx)
	local out = {}
	local card = type(Config.ClassCard) == "function" and Config.ClassCard(class, faction) or nil
	if type(card) == "table" and type(card.Stats) == "table" and #card.Stats > 0 then
		table.insert(out, { Title = Config.ClassName(class, faction), Lines = { table.concat(card.Stats, " · ") } })
	end
	local fd = type(Config.Factions) == "table" and Config.Factions[faction] or nil
	if faction ~= "None" and type(fd) == "table" and type(fd.Perks) == "table" and #fd.Perks > 0 then
		table.insert(out, { Title = fd.Name, Lines = table.clone(fd.Perks), Faction = faction })
	end
	local rb = type(Config.Rebirth) == "table" and Config.Rebirth or {}
	local marks = {}
	local fall, redeem = math.floor(num(ctx.FallMarks, 0)), math.floor(num(ctx.RedeemMarks, 0))
	if fall > 0 then
		table.insert(marks, string.format(T.Text.FallMarks, fall, math.floor(fall * num(rb.FallGoldPer, 0) * 100 + 0.5)))
	end
	if redeem > 0 then
		table.insert(marks, string.format(T.Text.RedeemMarks, redeem, math.floor(redeem * num(rb.RedeemXPPer, 0) * 100 + 0.5)))
	end
	if #marks > 0 then table.insert(out, { Title = T.Text.Passive, Lines = marks }) end
	return out
end

local function attr(name, default)
	local v = LocalPlayer:GetAttribute(name)
	if v == nil then return default end
	return v
end

local function context()
	local now = 0
	pcall(function() now = Util.Now() end)
	return {
		Class = attr("Class", "Warrior"), Faction = attr("Faction", "None"), Level = attr("Level", 1),
		SkillSlots = attr("SkillSlots", 0), Rebirths = attr("Rebirths", 0), Mana = attr("Mana", 0), Now = now,
		Ready = { Q = attr(T.Ready.Q, 0), Z = attr(T.Ready.Z, 0), X = attr(T.Ready.X, 0) },
		Tier = attr("WeaponTier", 0), FallMarks = attr("FallMarks", 0), RedeemMarks = attr("RedeemMarks", 0),
		Keyboard = UserInputService.KeyboardEnabled,
		Preview = RunService:IsStudio() and attr("SkillBarPreview", false) == true,
	}
end

----------------------------------------------------------------- drawing
-- 검수 10/11 (main photo: ~11 px in a short PC window): every label takes the UIKit text style (Title for names /
-- titles / the state, Body for the rest), whose floors are real screen px (PC 18 px Body), then gets its colour back
local function label(kit, parent, text, size, color, bold)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = bold and Enum.Font.GothamBold or kit.Font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.LayoutOrder = kit.NextOrder()
	l.Parent = parent
	local ui = C and C.UIKit
	if type(ui) == "table" and type(ui.StyleText) == "function" then
		pcall(ui.StyleText, l, bold and "Title" or "Body")
		l.TextColor3 = color
	end
	return l
end

local function list(parent, gap, horizontal)
	local l = Instance.new("UIListLayout")
	l.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	l.VerticalAlignment = horizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.Parent = parent
end

local function icon(kit, parent, keys)
	local size = UDim2.fromOffset(T.Icon, T.Icon)
	local ui = C and C.UIKit
	local img = nil
	if type(ui) == "table" and type(ui.ArtImage) == "function" then
		for _, key in keys do
			local has = type(ui.ArtId) ~= "function" or ui.ArtId(key) ~= nil
			if has then
				local ok, made = pcall(ui.ArtImage, key, { Name = "Icon", Size = size })
				if ok and made then
					img = made
					break
				end
			end
		end
	end
	if not img then -- code fallback: a round tile
		img = Instance.new("Frame")
		img.Name = "Icon"
		img.Size = size
		img.BackgroundColor3 = kit.Palette.Button
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = img
	end
	img.LayoutOrder = kit.NextOrder()
	img.Parent = parent
end

local STATE_COLOR = { ready = "Good", wait = "SubText", mp = "Bad", lock = "SubText" }

local function paintState(kit, view, ctx)
	local text, kind = SkillBook.State(view.Row, ctx)
	if not view.State then return end
	view.State.Text = text or ""
	view.State.TextColor3 = kit.Theme[STATE_COLOR[kind or ""] or "SubText"] or kit.Theme.SubText
end

local function keyOf(row, ctx)
	if not ctx.Keyboard then return nil end
	local kb = C and C.Keybinds
	if type(kb) ~= "table" or type(kb.Label) ~= "function" then return nil end
	local ok, k = pcall(kb.Label, row.Action)
	if ok and type(k) == "string" and k ~= "" then return k end
	return nil
end

local function drawRow(kit, parent, row, ctx)
	local f = Instance.new("Frame")
	f.Name = "Row_" .. row.Slot
	f.BackgroundColor3 = kit.Palette.Button
	f.BackgroundTransparency = row.Locked and 0.75 or 0.6
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, T.RowH)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = kit.NextOrder()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = f
	list(f, 12, true)
	f.Parent = parent
	icon(kit, f, row.Icons)
	-- middle: name (+ key), what it does, the numbers, the faction line
	local mid = Instance.new("Frame")
	mid.Name = "Info"
	mid.BackgroundTransparency = 1
	mid.Size = UDim2.new(1, -(T.Icon + T.RightW + 24), 0, 0)
	mid.AutomaticSize = Enum.AutomaticSize.Y
	mid.LayoutOrder = kit.NextOrder()
	list(mid, 3)
	mid.Parent = f
	local key = keyOf(row, ctx)
	local name = label(kit, mid, key and (row.Name .. "  [" .. key .. "]") or row.Name, T.Name,
		row.Locked and kit.Theme.SubText or kit.Theme.Text, true)
	name.Name = "Name"
	if row.Desc ~= "" then label(kit, mid, row.Desc, T.Body, kit.Theme.Text).Name = "Desc" end
	if row.Numbers ~= "" then label(kit, mid, row.Numbers, T.Small, kit.Theme.SubText).Name = "Numbers" end
	if row.FactionLine then
		local fd = type(Config.Factions) == "table" and Config.Factions[row.Faction] or nil
		local fl = label(kit, mid, row.FactionLine, T.Small, (fd and fd.Color) or kit.Theme.Gold, true)
		fl.Name = "FactionLine"
	end
	-- right: the live state (+ [Where to hunt] while locked)
	local right = Instance.new("Frame")
	right.Name = "State"
	right.BackgroundTransparency = 1
	right.Size = UDim2.new(0, T.RightW, 0, 0)
	right.AutomaticSize = Enum.AutomaticSize.Y
	right.LayoutOrder = kit.NextOrder()
	list(right, 6)
	right.Parent = f
	if row.Slot == "Attack" then return end
	local view = { Row = row }
	view.State = label(kit, right, "", T.Body, kit.Theme.SubText, true)
	view.State.Name = "StateText"
	view.State.TextXAlignment = Enum.TextXAlignment.Center
	if row.Locked then
		local b = kit.Button(right, word("WhereToHunt"), kit.Palette.Button, UDim2.fromOffset(T.RightW, T.ButtonH), function()
			kit.Open("Travel")
		end)
		b.LayoutOrder = kit.NextOrder()
		view.Button = b
	end
	paintState(kit, view, ctx)
	table.insert(VIEW.Rows, view)
end

local function drawPassive(kit, parent, ctx)
	local sections = SkillBook.Passive(ctx)
	if #sections == 0 then return end
	local head = label(kit, parent, T.Text.Passive, T.Name, kit.Theme.Gold, true)
	head.Name = "PassiveTitle"
	for _, sec in sections do
		local box = Instance.new("Frame")
		box.Name = "Passive"
		box.BackgroundColor3 = kit.Palette.Button
		box.BackgroundTransparency = 0.7
		box.BorderSizePixel = 0
		box.Size = UDim2.new(1, 0, 0, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.LayoutOrder = kit.NextOrder()
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = box
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
		pad.Parent = box
		list(box, 3)
		box.Parent = parent
		local fd = sec.Faction and type(Config.Factions) == "table" and Config.Factions[sec.Faction] or nil
		label(kit, box, sec.Title, T.Body, (fd and fd.Color) or kit.Theme.Text, true)
		-- one wrapped paragraph (five bullet rows made the window too tall once the text floors grew)
		label(kit, box, table.concat(sec.Lines, " · "), T.Small, kit.Theme.SubText).Name = "PassiveLines"
	end
end

local function build(parent, kit)
	VIEW.Rows = {}
	local ctx = context()
	for _, row in SkillBook.Rows(ctx) do drawRow(kit, parent, row, ctx) end
	drawPassive(kit, parent, ctx)
	if ctx.Keyboard then
		local b = kit.Button(parent, T.Text.ChangeKeys, kit.Palette.Button, UDim2.fromOffset(200, T.ButtonH), function()
			kit.Open("Settings", { Tab = "Keys" })
		end)
		b.LayoutOrder = kit.NextOrder()
	end
	return function()
		local now = context()
		for _, view in VIEW.Rows do paintState(kit, view, now) end
	end
end

local function cleanup()
	VIEW.Rows = {}
end

function SkillBook.IsReady()
	return S.Ready
end

function SkillBook.Open()
	local panels = C and C.Panels
	if not S.Ready or type(panels) ~= "table" or type(panels.Open) ~= "function" then return false end
	return (pcall(panels.Open, T.Window))
end

function SkillBook.Init(registry)
	C = registry
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the skill window is off")
		return
	end
	S.Ready = panels.Register(T.Window, {
		Title = T.Text.Title,
		-- what changes the rows (the live state - Mana, SkillReadyAt* - repaints in the update instead)
		Rebuild = { Class = true, Faction = true, Level = true, SkillSlots = true, Rebirths = true, WeaponTier = true,
			FallMarks = true, RedeemMarks = true },
		Build = build,
		Cleanup = cleanup,
	}) == true
end

function SkillBook.Start() end

return SkillBook
