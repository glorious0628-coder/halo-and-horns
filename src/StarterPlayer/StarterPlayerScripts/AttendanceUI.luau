-- AttendanceUI.luau (게임성 개발 1, plan docs/design/gameplay_plan_2026-10-13.md §1-A #5; SPEC A23-77 "출석 = 모은 날 수";
-- server = AttendanceService, contract docs/design/attendance_server_2026-10-08.md): the attendance board, Panels window
-- "Attendance" (the HUD [Menu] square "Gifts"). Presentation only: the server owns every claim, slot and reward.
--   The 7 slots of Config.Attendance.Board in a row: Day N, its reward icons (Config.HuntValue at my level, the 2x passes
--   counted like ProgressionService does; slot 7 = the weekly box), a stamp (StampClaimed) on the slots taken this
--   round; the slot that pays next glows (today) or waits (tomorrow). Under it one line of what that slot gives, [Claim]
--   (c->s "ClaimAttendance", no arguments) while AttendReady, else "Come back tomorrow!", the days collected with the next
--   milestone (RibbonDays art) and a calm line: a missed day resets nothing. No clock, no countdown (contract).
--   A slot that turns stamped while the window is open pops its stamp (the Fx "Attendance" sound is Audio's).
--   Opens by itself once a KST day when a claim is open, on a calm screen (PauseCard.Busy), after the first mission
--   (TutorialStep Done) and - for a player who never claimed - after L.FirstWait s of play (not in the first minutes).
--   [Menu] and the square glow while a claim is open (HUD).
-- Player attributes (AttendanceService): AttendReady, AttendSlot (1..7, the slot the next claim pays), AttendDays.
-- Game text: English only (A23-48), Config.Attendance.Text (the server's words + this window's).
-- Public API: AttendanceUI.Init(C), AttendanceUI.Start(), AttendanceUI.IsReady(), AttendanceUI.Open(), AttendanceUI.Ready()
-- (a claim is open: the HUD glow); pure: AttendanceUI.Parts(def, level, pass), AttendanceUI.Board(ctx),
-- AttendanceUI.Line(parts), AttendanceUI.Goal(days, faction), AttendanceUI.AutoOpen(ctx).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local AttendanceUI = {}
local C = nil
local TAG = "AttendanceUI"

-- layout (du) and timing
local L = {
	Window = "Attendance", Width = 720, -- Panels FRAME.Pad 18 each side -> 684 du of content
	Remote = "ClaimAttendance",
	Gap = 8, CellH = 128, DayH = 22, CountH = 20, Pad = 5, MaxParts = 2,
	TopH = 64, Ribbon = 64, ButtonW = 260, ButtonH = 56,
	ClaimWait = 3, -- s the button stays "pending" after a press without an answer (then it unlocks again)
	FirstWait = 600, -- s of play before the board opens by itself for a player who never claimed (not the first minutes)
	Poll = 2, -- s between the auto-open checks
	Pop = { From = 1.8, Time = 0.35 }, -- the stamp's pop
	Faded = 0.55, -- ImageTransparency of a stamped slot's icons
	-- the ribbon's empty disc (이미지 생성 2 measured: centre 0.497, 0.407, size 0.432 x 0.412; digits inside ~70 %)
	Disc = { X = 0.497, Y = 0.407, W = 0.30, H = 0.29 },
	Icons = { Gold = "IconCoin", XP = "IconExp", HP = "IconPotionHP", MP = "IconPotionMP", Box = "IconWeeklyBox",
		Stamp = "StampClaimed" },
	Rim = { Today = Color3.fromRGB(255, 210, 60), Next = Color3.fromRGB(150, 160, 200), Other = Color3.fromRGB(70, 78, 110) },
	Card = Color3.fromRGB(22, 32, 70), -- the code fallback of a slot (IMG-R4)
}
local S = { Ready = false, ClaimAt = -math.huge, OpenedDay = -1, Joined = os.clock() }
local VIEW = { Kit = nil, Cells = nil, Line = nil, Button = nil, Days = nil, Goal = nil, Ribbon = nil, Disc = nil,
	Shown = false }

---------------------------------------------------------------------------------------------------- text (pure)
local function att() return type(Config.Attendance) == "table" and Config.Attendance or {} end

-- the board's words (Config.Attendance.Text[key], formatted)
local function tx(key, ...)
	local t = type(att().Text) == "table" and att().Text or {}
	local s = t[key]
	if type(s) ~= "string" then return "" end
	if select("#", ...) == 0 then return s end
	local ok, out = pcall(string.format, s, ...)
	return ok and out or s
end

local function int(v, default)
	v = tonumber(v)
	if not v or v ~= v or v == math.huge or v == -math.huge then return default or 0 end
	return math.floor(v)
end

local function itemName(id)
	local loot = type(Config.Loot) == "table" and Config.Loot or {}
	local def = type(loot.Items) == "table" and loot.Items[id] or nil
	if type(def) == "table" and type(def.Name) == "string" then return def.Name end
	local pot = type(loot.Text) == "table" and type(loot.Text.Potion) == "table" and loot.Text.Potion[id] or nil
	return type(pot) == "string" and pot or tostring(id)
end

local function itemIcon(id)
	if L.Icons[id] then return L.Icons[id] end
	local items = type(Config.Loot) == "table" and Config.Loot.Items or nil
	local def = type(items) == "table" and items[id] or nil
	return type(def) == "table" and def.Icon or nil
end

-- the materials `minutes` of hunting the level zone's main monster drop on average (AttendanceService.materialsFor:
-- Config.Economy.KillsPerMinute x minutes x P x N of each Material row, rounded)
local function materials(level, minutes)
	local out = {}
	local zone = Config.QuestZoneForLevel(level)
	local kind = type(Config.ZoneMainMonster) == "table" and Config.ZoneMainMonster[zone] or nil
	local rows = kind and type(Config.Loot) == "table" and Config.Loot.Tables[kind] or nil
	for _, row in type(rows) == "table" and rows or {} do
		local def = type(row.Item) == "string" and Config.Loot.Items[row.Item] or nil
		if def and def.Kind == "Material" then
			local n = math.floor(Config.Economy.KillsPerMinute * minutes * (tonumber(row.P) or 0) * (tonumber(row.N) or 1) + 0.5)
			if n > 0 then table.insert(out, { Id = row.Item, N = n }) end
		end
	end
	return out
end

-- one board slot's rewards at my level: { { Kind = "Gold" | "XP" | "Item", Id, N, Icon } } in the server's pay order
-- (potion, item, materials; then gold, XP). pass = { Gold2 = bool, XP2 = bool }: x Config.PassBoost.Mult like
-- ProgressionService (attendance gold is an earned source)
function AttendanceUI.Parts(def, level, pass)
	local parts = {}
	if type(def) ~= "table" then return parts end
	level = math.clamp(int(level, 1), 1, int(Config.Levels and Config.Levels.MaxLevel, 1))
	pass = type(pass) == "table" and pass or {}
	local mult = math.max(1, tonumber(Config.PassBoost and Config.PassBoost.Mult) or 1)
	local function item(id, n)
		n = int(n, 1)
		if type(id) == "string" and n >= 1 then
			table.insert(parts, { Kind = "Item", Id = id, N = n, Icon = itemIcon(id) })
		end
	end
	if def.Potion then item(def.Potion, def.N) end
	if def.Item then item(def.Item, def.N) end
	if (tonumber(def.MaterialMin) or 0) > 0 then
		for _, m in materials(level, def.MaterialMin) do item(m.Id, m.N) end
	end
	if (tonumber(def.GoldMin) or 0) > 0 then
		local gold = Config.HuntValue(level, def.GoldMin)
		gold = math.floor(gold * (pass.Gold2 == true and mult or 1))
		if gold > 0 then table.insert(parts, { Kind = "Gold", N = gold, Icon = L.Icons.Gold }) end
	end
	if (tonumber(def.XPMin) or 0) > 0 then
		local _, xp = Config.HuntValue(level, def.XPMin)
		xp = math.floor(xp * (pass.XP2 == true and mult or 1))
		if xp > 0 then table.insert(parts, { Kind = "XP", N = xp, Icon = L.Icons.XP }) end
	end
	return parts
end

-- the parts as one line ("+120 gold · +Enhance Scroll 70%"): the server's words and order (AttendanceService.partsText:
-- gold, XP, then the items), so the claim's "Day N reward!" line reads the same
function AttendanceUI.Line(parts)
	local out = {}
	parts = type(parts) == "table" and parts or {}
	for _, kind in { "Gold", "XP" } do
		for _, p in parts do
			if p.Kind == kind then table.insert(out, tx(kind, Util.FormatNumber(p.N))) end
		end
	end
	for _, p in parts do
		if p.Kind == "Item" then
			table.insert(out, p.N > 1 and tx("ItemN", itemName(p.Id), p.N) or tx("Item", itemName(p.Id)))
		end
	end
	return table.concat(out, " · ")
end

-- the board: ctx = { Slot, Ready, Days, Level, ClassChosen, Pass } -> { Rows = { { Slot, Parts, Box, State } }, Pays,
-- Ready, WeekDone }. State: "Got" (stamped: taken this round), "Today" (a claim is open and pays it), "Next" (it pays
-- next, tomorrow), "Later". After the 7th slot the server starts at slot 1 again: a closed claim at slot 1 with days
-- collected and my class picked means today's claim was the weekly box - the whole board stays stamped until tomorrow.
function AttendanceUI.Board(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local board = type(att().Board) == "table" and att().Board or {}
	local n = #board
	local slot = int(ctx.Slot, 1)
	if slot < 1 or slot > n then slot = 1 end
	local ready = ctx.Ready == true
	local weekDone = not ready and slot == 1 and int(ctx.Days) > 0 and ctx.ClassChosen == true
	local rows = {}
	for i, def in board do
		local state = "Later"
		if weekDone or i < slot then
			state = "Got"
		elseif i == slot then
			state = ready and "Today" or "Next"
		end
		table.insert(rows, { Slot = i, Parts = AttendanceUI.Parts(def, ctx.Level, ctx.Pass), Box = def.Box == true, State = state })
	end
	return { Rows = rows, Pays = n > 0 and slot or nil, Ready = ready and n > 0, WeekDone = weekDone }
end

-- what a milestone really gives me: its title (TitleService) and my side's attendance looks (MonetizationService.GrantLook,
-- worn from the Shop's Looks). Not its Border (the 28-day name frame): no screen draws it yet
local function goalRewards(m, faction)
	local at = int(m.Days)
	local what = {}
	local def = m.Title and Config.TitleDefs and Config.TitleDefs[m.Title]
	if def then table.insert(what, tx("GoalTitle", tostring(def.NameEn or def.Name))) end
	local looks = {}
	for id, look in type(Config.Looks) == "table" and Config.Looks or {} do
		local need = type(look) == "table" and type(look.Unlock) == "table" and int(look.Unlock.Attendance) or 0
		if need == at and look.Faction == faction then table.insert(looks, { Id = id, Name = look.Name, Order = int(look.Order) }) end
	end
	table.sort(looks, function(a, b) return a.Order < b.Order end)
	for _, look in looks do table.insert(what, tostring(look.Name or look.Id)) end
	return what
end

-- the next milestone after `days` that really gives me something: { Days, Text } or nil. Final review 10/13: a milestone
-- with nothing real for me (the 28-day name frame nobody draws yet, the 14-day looks for an artisan) is skipped - the
-- board never promises a reward that does not exist
function AttendanceUI.Goal(days, faction)
	days = int(days)
	local list = {}
	for _, m in type(att().Milestones) == "table" and att().Milestones or {} do
		if type(m) == "table" and int(m.Days) > days then table.insert(list, m) end
	end
	table.sort(list, function(a, b) return int(a.Days) < int(b.Days) end)
	for _, m in list do
		local what = goalRewards(m, faction)
		if #what > 0 then return { Days = int(m.Days), Text = tx("Goal", int(m.Days), table.concat(what, " + ")) } end
	end
	return nil
end

-- open by itself? ctx = { Ready, Step, Done, Days, Played (s), Day, OpenedDay, Busy }: once a day, a claim open, the
-- first mission done, a calm screen, and for a first claim not before L.FirstWait s of play
function AttendanceUI.AutoOpen(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	if ctx.Ready ~= true or ctx.Busy == true then return false end
	if ctx.Day == nil or ctx.Day == ctx.OpenedDay then return false end
	if type(ctx.Step) ~= "number" or ctx.Step ~= (tonumber(ctx.Done) or 99) then return false end
	return int(ctx.Days) > 0 or (tonumber(ctx.Played) or 0) >= L.FirstWait
end

---------------------------------------------------------------------------------------------------- the window
local function kit() return C and C.UIKit or nil end

local function call(name, ...)
	local k = kit()
	if type(k) ~= "table" or type(k[name]) ~= "function" then return nil end
	local ok, a, b = pcall(k[name], ...)
	if ok then return a, b end
	return nil
end

local function attr(name)
	return LocalPlayer and LocalPlayer:GetAttribute(name) or nil
end

local function context()
	return { Slot = attr("AttendSlot"), Ready = attr("AttendReady") == true, Days = attr("AttendDays"), Level = attr("Level"),
		ClassChosen = attr("ClassChosen") == true, Pass = { Gold2 = attr("PassGold2") == true, XP2 = attr("PassXP2") == true } }
end

local function text(props, light)
	local t = call(light and "LightText" or "InkText", props)
	if t then return t end
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = light and Color3.new(1, 1, 1) or Color3.fromRGB(66, 40, 18)
	l.Font = Enum.Font.GothamBold
	for k, v in props do
		if k ~= "Parent" and k ~= "Title" and k ~= "Number" and k ~= "MaxTextSize" and k ~= "Color" then
			pcall(function() l[k] = v end)
		end
	end
	l.Parent = props.Parent
	return l
end

local function image(part, props)
	return call("ArtImage", part, props)
end

-- a square picture as big as its box allows (no measuring: the window may not be laid out yet)
local function square(img)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = img
	return img
end

-- a reward icon with its count under it, in the i-th of `count` columns
local function partIcon(parent, part, i, count)
	local holder = Instance.new("Frame")
	holder.Name = "Part" .. tostring(i)
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.fromScale((i - 0.5) / count, 0)
	holder.Size = UDim2.new(1 / count, count > 1 and -2 or 0, 1, 0)
	holder.Parent = parent
	local icon = part.Icon and image(part.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 1, -L.CountH), ZIndex = 3, Parent = holder }) or nil
	if icon then square(icon) end
	local n = part.Kind == "Item" and (part.N > 1 and ("x" .. tostring(part.N)) or "") or Util.FormatNumber(part.N)
	if not icon then n = (part.Kind == "Item" and itemName(part.Id) or part.Kind) .. " " .. n end
	text({ Name = "Count", Text = n, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 4, 0, L.CountH), TextScaled = true, MaxTextSize = 18, Number = true, ZIndex = 4, Parent = holder }, true)
	return icon
end

-- one slot: the plate, Day N, its icons, the stamp (hidden until taken)
local function newCell(parent, row)
	local cell = { Slot = row.Slot, Icons = {}, Got = nil }
	local plate = call("ArtFrame", "PanelCard", { Name = "Slot" .. row.Slot, LayoutOrder = row.Slot, Size = UDim2.fromScale(1, 1) },
		{ BackgroundColor3 = L.Card, CornerRadius = UDim.new(0, 12) })
	if not plate then
		plate = Instance.new("Frame")
		plate.Name = "Slot" .. row.Slot
		plate.LayoutOrder = row.Slot
		plate.BackgroundColor3 = L.Card
	end
	plate.Parent = parent
	local rim = Instance.new("UIStroke")
	rim.Name = "Rim"
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = plate
	cell.Plate, cell.Rim = plate, rim
	text({ Name = "Day", Text = tx("Day", row.Slot), Position = UDim2.fromOffset(0, L.Pad), Size = UDim2.new(1, 0, 0, L.DayH),
		TextScaled = true, MaxTextSize = 20, Title = true, ZIndex = 4, Parent = plate }, true)
	local body = Instance.new("Frame")
	body.Name = "Rewards"
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(L.Pad, L.Pad + L.DayH + 4)
	body.Size = UDim2.new(1, -2 * L.Pad, 1, -(2 * L.Pad + L.DayH + 4))
	body.Parent = plate
	cell.Body = body
	if row.Box then -- the weekly box alone (the line under the board says what is in it)
		local box = image(L.Icons.Box, { Name = "Box", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = body })
		if box then
			table.insert(cell.Icons, square(box))
		else
			text({ Name = "Box", Text = tx("Box"), Size = UDim2.fromScale(1, 1), TextScaled = true, TextWrapped = true,
				MaxTextSize = 18, ZIndex = 4, Parent = body }, true)
		end
	else -- at most two rewards side by side (slot 5: potions + materials)
		local count = math.max(1, math.min(L.MaxParts, #row.Parts))
		for i = 1, count do
			local icon = row.Parts[i] and partIcon(body, row.Parts[i], i, count) or nil
			if icon then table.insert(cell.Icons, icon) end
		end
	end
	local stamp = image(L.Icons.Stamp, { Name = "Stamp", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.86, 0.86), ZIndex = 6, Visible = false, Parent = plate })
	if stamp then
		square(stamp)
		local pop = Instance.new("UIScale")
		pop.Name = "Pop"
		pop.Parent = stamp
	end
	cell.Stamp = stamp
	return cell
end

local function paintCell(cell, row, animate)
	local got = row.State == "Got"
	cell.Rim.Color = row.State == "Today" and L.Rim.Today or (row.State == "Next" and L.Rim.Next or L.Rim.Other)
	cell.Rim.Thickness = row.State == "Today" and 4 or (row.State == "Next" and 2 or 1)
	for _, icon in cell.Icons do
		if icon.Parent then icon.ImageTransparency = got and L.Faded or 0 end
	end
	if cell.Stamp then
		cell.Stamp.Visible = got
		local pop = cell.Stamp:FindFirstChild("Pop")
		if got and animate and cell.Got == false and pop then -- just taken while I watch
			pop.Scale = L.Pop.From
			TweenService:Create(pop, TweenInfo.new(L.Pop.Time, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end
	cell.Got = got
end

local function refresh(animate)
	local k = VIEW.Kit
	if not (k and VIEW.Cells) then return end
	local ctx = context()
	local b = AttendanceUI.Board(ctx)
	for _, row in b.Rows do
		local cell = VIEW.Cells[row.Slot]
		if cell then paintCell(cell, row, animate) end
	end
	-- the slot that pays next, in words
	local pays = b.Pays and b.Rows[b.Pays] or nil
	local line = ""
	if b.WeekDone then
		line = tx("WeekDone")
	elseif pays then
		local what = AttendanceUI.Line(pays.Parts)
		if pays.Box then what = tx("Box") .. ": " .. what end
		line = tx(b.Ready and "Today" or "Next", pays.Slot, what)
	end
	VIEW.Line.Text = line
	-- [Claim]: open while a claim is (a press waits for the answer up to L.ClaimWait s)
	local waiting = os.clock() - S.ClaimAt < L.ClaimWait
	VIEW.Button.Text = b.Ready and tx("Claim") or tx("Wait")
	k.SetEnabled(VIEW.Button, b.Ready and not waiting)
	-- days collected + the next milestone on its ribbon
	local days = int(ctx.Days)
	VIEW.Days.Text = tx("Collected", days)
	local goal = AttendanceUI.Goal(days, attr("Faction"))
	VIEW.Goal.Text = goal and goal.Text or ""
	VIEW.Goal.Visible = goal ~= nil
	if VIEW.Ribbon then
		local ms = type(att().Milestones) == "table" and att().Milestones or {}
		local at = goal and goal.Days or int(ms[#ms] and ms[#ms].Days)
		local want = "RibbonDays" .. tostring(at)
		if VIEW.RibbonKey ~= want and call("ArtId", want) then
			VIEW.RibbonKey = want
			VIEW.Ribbon.Image = call("ArtId", want)
		end
		if VIEW.Disc then VIEW.Disc.Text = tostring(at) end
	end
end

local function claim()
	if attr("AttendReady") ~= true or os.clock() - S.ClaimAt < L.ClaimWait then return end
	S.ClaimAt = os.clock()
	local k = VIEW.Kit
	if k and type(k.Fire) == "function" then k.Fire(L.Remote) end
	refresh(false)
	task.delay(L.ClaimWait + 0.05, function()
		if VIEW.Shown then pcall(refresh, true) end
	end)
end

local function row(k, parent, name, h)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, h)
	f.LayoutOrder = k.NextOrder()
	f.Parent = parent
	return f
end

local function build(parent, k)
	VIEW.Kit, VIEW.Cells, VIEW.Shown, VIEW.RibbonKey = k, {}, true, nil
	S.OpenedDay = Config.DayIndex(os.time()) -- opened today (by hand or by itself): no second auto-open
	-- days collected + the next milestone
	local top = row(k, parent, "Days", L.TopH)
	local ms = type(att().Milestones) == "table" and att().Milestones or {}
	local first = ms[1] and ("RibbonDays" .. tostring(int(ms[1].Days))) or "RibbonDays7"
	VIEW.Ribbon = image(first, { Name = "Ribbon", Size = UDim2.fromOffset(L.Ribbon, L.Ribbon), Parent = top })
	VIEW.RibbonKey = VIEW.Ribbon and first or nil
	VIEW.Disc = nil
	if VIEW.Ribbon then
		VIEW.Disc = text({ Name = "Disc", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(L.Disc.X, L.Disc.Y),
			Size = UDim2.fromScale(L.Disc.W, L.Disc.H), TextScaled = true, Number = true, ZIndex = 3, Parent = VIEW.Ribbon }, false)
	end
	local left = VIEW.Ribbon and (L.Ribbon + 12) or 0
	VIEW.Days = text({ Name = "Collected", Text = "", Position = UDim2.fromOffset(left, 4), Size = UDim2.new(1, -left, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, MaxTextSize = 24, Title = true, Parent = top }, true)
	VIEW.Goal = text({ Name = "Goal", Text = "", Position = UDim2.fromOffset(left, 34), Size = UDim2.new(1, -left, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left, TextScaled = true, MaxTextSize = 20, Parent = top }, true)
	-- the 7 slots in one row
	local boardFrame = row(k, parent, "Board", L.CellH)
	local list = Instance.new("UIGridLayout")
	local board = type(att().Board) == "table" and att().Board or {}
	local n = math.max(1, #board)
	list.CellSize = UDim2.new(1 / n, -L.Gap * (n - 1) / n - 1, 1, 0) -- 1 du short: whole pixels never wrap the 7th
	list.CellPadding = UDim2.fromOffset(L.Gap, 0)
	list.FillDirectionMaxCells = n
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = boardFrame
	for _, r in AttendanceUI.Board(context()).Rows do
		VIEW.Cells[r.Slot] = newCell(boardFrame, r)
	end
	-- what the next slot gives, [Claim], the calm line
	VIEW.Line = k.Text(parent, "", { Name = "Pays", Size = 18, Align = Enum.TextXAlignment.Center, Color = k.Theme.Gold })
	local buttons = row(k, parent, "Claim", L.ButtonH)
	VIEW.Button = k.Button(buttons, tx("Claim"), k.Palette.Free, UDim2.fromOffset(L.ButtonW, L.ButtonH), claim)
	VIEW.Button.Name = "ClaimButton"
	VIEW.Button.AnchorPoint = Vector2.new(0.5, 0)
	VIEW.Button.Position = UDim2.fromScale(0.5, 0)
	k.Text(parent, tx("Note"), { Name = "Note", Size = 15, Align = Enum.TextXAlignment.Center, Color = k.Theme.SubText })
	k.OnAttr(function(name)
		if name == "AttendReady" or name == "AttendSlot" or name == "AttendDays" or name == "Level" or name == "Faction"
			or name == "PassGold2" or name == "PassXP2" or name == "ClassChosen" then
			if name == "AttendSlot" or name == "AttendReady" then S.ClaimAt = -math.huge end -- the answer came
			refresh(true)
		end
	end)
	refresh(false)
	return function() refresh(true) end
end

local function cleanup()
	VIEW.Kit, VIEW.Cells, VIEW.Line, VIEW.Button, VIEW.Days, VIEW.Goal, VIEW.Ribbon, VIEW.Disc = nil, nil, nil, nil, nil, nil,
		nil, nil
	VIEW.Shown = false
end

---------------------------------------------------------------------------------------------------- lifecycle
function AttendanceUI.IsReady()
	return S.Ready
end

-- a claim is open now (the HUD [Menu] glow)
function AttendanceUI.Ready()
	return S.Ready and attr("AttendReady") == true
end

-- A23-167 ②: one board slot's art for PauseCard's "tomorrow's gift" card - the weekly box, else its first reward's icon
-- at my level (the same icon its cell shows first); nil = no such slot
function AttendanceUI.SlotIcon(slot)
	local board = type(att().Board) == "table" and att().Board or {}
	local def = board[int(slot, 0)]
	if type(def) ~= "table" then return nil end
	if def.Box == true then return L.Icons.Box end
	local ctx = context()
	local parts = AttendanceUI.Parts(def, ctx.Level, ctx.Pass)
	return parts[1] and parts[1].Icon or nil
end

function AttendanceUI.Open()
	local panels = C and C.Panels
	if not S.Ready or type(panels) ~= "table" or type(panels.Open) ~= "function" then return false end
	return (pcall(panels.Open, L.Window))
end

local function busy()
	local pc = C and C.PauseCard
	if type(pc) ~= "table" or type(pc.Busy) ~= "function" then return true end
	local ok, b = pcall(pc.Busy)
	if not ok or b == true then return true end
	for _, fn in { "IsOpen", "Waiting" } do
		if type(pc[fn]) == "function" then
			local fine, on = pcall(pc[fn])
			if fine and on == true then return true end
		end
	end
	return false
end

function AttendanceUI.Tick()
	if not S.Ready or VIEW.Shown then return false end
	local steps = type(Config.Tutorial) == "table" and Config.Tutorial.Steps or {}
	local ctx = { Ready = attr("AttendReady") == true, Step = attr("TutorialStep"), Done = steps.Done, Days = attr("AttendDays"),
		Played = os.clock() - S.Joined, Day = Config.DayIndex(os.time()), OpenedDay = S.OpenedDay }
	if not AttendanceUI.AutoOpen(ctx) then return false end
	ctx.Busy = busy() -- (asked last: the checks above are cheap)
	if not AttendanceUI.AutoOpen(ctx) then return false end
	S.OpenedDay = ctx.Day
	return AttendanceUI.Open()
end

AttendanceUI._T = { L = L, S = S, VIEW = VIEW, Refresh = refresh, Claim = claim } -- tools/test_attendance_ui.py

function AttendanceUI.Init(registry)
	C = registry
	if att().Enabled == false then return end
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the attendance board is off")
		return
	end
	S.Ready = panels.Register(L.Window, {
		Title = function() return tx("Title") end,
		Width = L.Width,
		Build = build,
		Cleanup = cleanup,
	}) == true
end

function AttendanceUI.Start()
	if not S.Ready then return end
	task.spawn(function()
		while true do
			task.wait(L.Poll)
			local ok, err = pcall(AttendanceUI.Tick)
			if not ok then Util.Warn(TAG, "tick failed: " .. tostring(err)) end
		end
	end)
end

return AttendanceUI
