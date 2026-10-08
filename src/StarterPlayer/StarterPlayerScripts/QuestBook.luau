-- QuestBook.luau (게임성 개발 1, SPEC A23-81 "Q = 전체 퀘스트 창", user 2026-10-08 15:05): the quest window, Panels id
-- "Journal" (the Q key since A23-78; the HUD's ▼ button and a phone tap on the quest lines open it too). Five tabs
-- (Config.QuestTabs.Order: Main · Side · Daily · Event · Faction; Config.QuestTab(id, kind) sorts a quest), each with
-- In progress / Available / Done.
--   In progress = the HUD's quest rows of that tab (HUD.QuestEntries: the server's rows - quests in progress or ready to
--   claim, the same tables the HUD lines use) + info lines nobody claims: the live world events on Event (golden goose,
--   Pumpkin / Ghost King, kaiju, the crown war's next crown) and my wanted stars on Faction.
--   Available / Done = the server's quest book (HUD.QuestBook: { Available = { row }, Done = { id | row } }, row =
--   { Id, Text, Tab? }, 게임성 개발 3) when it comes; until then Done = the main chain before my main quest
--   (Config.StoryQuests.Main), the first mission once it is over, what I finished this session (HUD.QuestDoneSession)
--   and today's daily count.
-- A row = the quest's words and 3/5; [Claim] / [New] when the HUD's rules allow (HUD.QuestCanClaim / QuestCanReroll ->
-- HUD.QuestClaim / QuestReroll); a press on the row closes the window and guides me there like the HUD lines
-- (HUD.QuestGo). Redraws on HUD.QuestsChanged while open. Game text: English only (A23-48), short and easy.
-- Public API: QuestBook.Init(C), QuestBook.Start(), QuestBook.IsReady(), QuestBook.Toggle(open?), QuestBook.ShowTab(id),
-- QuestBook.TabOf(entry), QuestBook.Sections(tab, ctx) -> { InProgress, Available, Done } (pure: ctx = { Entries, Book,
-- DoneSession, Attr = fn(name), GameAttr = fn(name), Now }; the offline test drives it).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local QuestBook = {}
local C = nil
local TAG = "QuestBook"

local T = {
	Window = "Journal",
	TabH = 40,
	RowText = 18,
	NumText = 16,
	BtnW = 84,
	BtnH = 34,
	-- game text: English only (A23-48)
	Text = {
		Title = "Quests",
		InProgress = "In progress",
		Available = "Available",
		Done = "Done",
		EmptyInProgress = "Nothing to do here right now.",
		EmptyAvailable = "Nothing new right now.",
		EmptyDone = "Nothing finished yet.",
		Claim = "Claim",
		Reroll = "New",
		FirstMission = "First mission",
		DailyToday = "Daily quests today: %d/%d",
		Goose = "The Golden Goose is here!",
		PumpkinKing = "The Pumpkin King is here!",
		GhostKing = "The Ghost King is here!",
		Kaiju = "A kaiju is loose!",
		War = "Crown War: next crown in %s",
		Wanted = "Wanted stars: %d",
		TabCount = "%s %d",
	},
}
local S = { Ready = false, Tab = "Main", Conn = nil }
local VIEW = { Parent = nil, Kit = nil, Tabs = nil, Body = nil } -- the open window's parts (nil while closed)

local function tabs() return Config.QuestTabs.Order end

-- the tab of one HUD quest row
function QuestBook.TabOf(e)
	if type(e) ~= "table" then return Config.QuestTabs.Default end
	return Config.QuestTab(e.Id, e.Kind)
end

local function storyDef(id)
	local sid = type(id) == "string" and string.match(id, "^story:(.+)$") or nil
	local defs = Config.StoryQuests and Config.StoryQuests.Defs
	return sid, (sid and type(defs) == "table") and defs[sid] or nil
end

-- the words for a quest id the server only named (book rows): the story title, else the id
local function titleOf(id, text)
	if type(text) == "string" and text ~= "" then return text end
	local _, def = storyDef(id)
	if def and type(def.Title) == "string" then return def.Title end
	return tostring(id)
end

local function clock(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- a book row (string id or { Id, Text, Tab?, Kind? }) and its tab
local function bookRow(r)
	if type(r) == "string" then
		local _, def = storyDef(r)
		return { Kind = "Done", Text = titleOf(r, nil), Tab = Config.QuestTab(r, def and def.Kind or nil) }
	elseif type(r) == "table" and r.Id ~= nil then
		local _, def = storyDef(r.Id)
		local tab = type(r.Tab) == "string" and r.Tab or Config.QuestTab(r.Id, r.Kind or (def and def.Kind) or nil)
		return { Kind = "Done", Text = titleOf(r.Id, r.Text), Tab = tab }
	end
	return nil
end

-- the three sections of one tab (pure)
function QuestBook.Sections(tab, ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local attr = type(ctx.Attr) == "function" and ctx.Attr or function() return nil end
	local gattr = type(ctx.GameAttr) == "function" and ctx.GameAttr or function() return nil end
	local hud = C and C.HUD
	local canClaim = ctx.CanClaim or (type(hud) == "table" and hud.QuestCanClaim) or function() return false end
	local canReroll = ctx.CanReroll or (type(hud) == "table" and hud.QuestCanReroll) or function() return false end
	local out = { InProgress = {}, Available = {}, Done = {} }
	local mainId = nil
	for _, e in type(ctx.Entries) == "table" and ctx.Entries or {} do
		if type(e) == "table" then
			if e.Story and e.Kind == "Main" and type(e.Story.Id) == "string" then mainId = e.Story.Id end
			if QuestBook.TabOf(e) == tab then
				local nums = nil
				if e.ShowProgress ~= false and type(e.Progress) == "number" and type(e.Target) == "number" then
					nums = string.format("%d/%d", math.floor(math.min(e.Progress, e.Target)), math.floor(e.Target))
				end
				table.insert(out.InProgress, { Kind = "Quest", Entry = e, Text = tostring(e.Text or ""), Nums = nums,
					CanClaim = canClaim(e) == true, CanReroll = canReroll(e) == true })
			end
		end
	end
	-- info lines nobody claims
	if tab == "Event" then
		local now = tonumber(ctx.Now) or 0
		if gattr("GooseActive") == true then table.insert(out.InProgress, { Kind = "Info", Text = T.Text.Goose }) end
		if gattr("PumpkinKingActive") == true then table.insert(out.InProgress, { Kind = "Info", Text = T.Text.PumpkinKing }) end
		if gattr("GhostKingActive") == true then table.insert(out.InProgress, { Kind = "Info", Text = T.Text.GhostKing }) end
		local kaiju = gattr("KaijuPhase")
		if kaiju == "Siren" or kaiju == "Active" then table.insert(out.InProgress, { Kind = "Info", Text = T.Text.Kaiju }) end
		local warEnds = tonumber(gattr("WarRoundEndsAt")) or 0
		if warEnds > now then
			table.insert(out.InProgress, { Kind = "Info", Text = string.format(T.Text.War, clock(warEnds - now)) })
		end
	elseif tab == "Faction" then
		local stars = math.floor(tonumber(attr("WantedStars")) or 0)
		if stars > 0 then table.insert(out.InProgress, { Kind = "Info", Text = string.format(T.Text.Wanted, stars) }) end
	end
	-- the server's book, when it sends one
	local book = type(ctx.Book) == "table" and ctx.Book or nil
	if book then
		for _, r in type(book.Available) == "table" and book.Available or {} do
			local row = bookRow(r)
			if row and row.Tab == tab then
				row.Kind = "Available"
				table.insert(out.Available, row)
			end
		end
		for _, r in type(book.Done) == "table" and book.Done or {} do
			local row = bookRow(r)
			if row and row.Tab == tab then table.insert(out.Done, row) end
		end
		return out
	end
	-- no book yet: what the client can tell
	local seen = {}
	local function done(text)
		if type(text) == "string" and text ~= "" and not seen[text] then
			seen[text] = true
			table.insert(out.Done, { Kind = "Done", Text = text })
		end
	end
	if tab == "Main" then
		local steps = Config.Tutorial and Config.Tutorial.Steps
		local doneStep = type(steps) == "table" and tonumber(steps.Done) or 99
		local step = tonumber(attr("TutorialStep"))
		if (step and step >= doneStep) or mainId then done(T.Text.FirstMission) end
		local chain = Config.StoryQuests and Config.StoryQuests.Main
		if mainId and type(chain) == "table" then
			for _, id in chain do
				if id == mainId then break end
				done(titleOf("story:" .. id, nil))
			end
		end
	elseif tab == "Daily" then
		local slots = Config.Quests and tonumber(Config.Quests.Slots) or 3
		local claims = math.floor(tonumber(attr("DailyClaims")) or 0)
		if claims > 0 then table.insert(out.Done, { Kind = "Info", Text = string.format(T.Text.DailyToday, math.min(claims, slots), slots) }) end
	end
	for _, d in type(ctx.DoneSession) == "table" and ctx.DoneSession or {} do
		if type(d) == "table" and Config.QuestTab(d.Id, d.Kind) == tab then
			local _, def = storyDef(d.Id)
			done((def and def.Title) or d.Text)
		end
	end
	return out
end

----------------------------------------------------------------- the window
local function hudCall(name, ...)
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud[name]) == "function" then
		local ok, res = pcall(hud[name], ...)
		if ok then return res end
		Util.Warn(TAG, name .. " failed: " .. tostring(res))
	end
	return nil
end

local function context()
	local kit = VIEW.Kit
	return {
		Entries = hudCall("QuestEntries") or {},
		Book = hudCall("QuestBook"),
		DoneSession = hudCall("QuestDoneSession") or {},
		Attr = function(name) return kit and kit.Attr(name, nil) end,
		GameAttr = function(name) return kit and kit.GameAttr(name, nil) end,
		Now = Util.Now(),
	}
end

local function label(kit, parent, text, size, color, order, width)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = width or UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.Font = kit.Font
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.LayoutOrder = order or 0
	l.Parent = parent
	return l
end

-- one row: the words (+ 3/5), [Claim] / [New]; a press on a quest row guides me there and closes the window
local function drawRow(kit, parent, row)
	local f = Instance.new(row.Kind == "Quest" and "TextButton" or "Frame")
	f.Name = row.Kind
	f.BackgroundColor3 = kit.Palette.Button
	f.BackgroundTransparency = row.Kind == "Quest" and 0.55 or 0.8
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = kit.NextOrder()
	if f:IsA("TextButton") then
		f.Text = ""
		f.AutoButtonColor = false
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = f
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = f
	local buttons = (row.CanClaim and 1 or 0) + (row.CanReroll and 1 or 0)
	local reserve = buttons * (T.BtnW + 8) + (row.Nums and 64 or 0)
	local color = row.Kind == "Done" and kit.Theme.SubText or kit.Theme.Text
	label(kit, f, row.Text, T.RowText, color, 1, UDim2.new(1, -reserve, 0, 0))
	if row.Nums then
		local n = label(kit, f, row.Nums, T.NumText, kit.Theme.Gold, 2, UDim2.fromOffset(56, 0))
		n.TextXAlignment = Enum.TextXAlignment.Right
	end
	if row.CanClaim then
		local b = kit.Button(f, T.Text.Claim, kit.Theme.Good, UDim2.fromOffset(T.BtnW, T.BtnH), function()
			hudCall("QuestClaim", row.Entry)
		end)
		b.LayoutOrder = 3
	end
	if row.CanReroll then
		local b = kit.Button(f, T.Text.Reroll, kit.Palette.Button, UDim2.fromOffset(T.BtnW, T.BtnH), function()
			hudCall("QuestReroll", row.Entry)
		end)
		b.LayoutOrder = 4
	end
	if row.Kind == "Quest" then
		f.Activated:Connect(function()
			if hudCall("QuestGo", row.Entry) and VIEW.Kit then VIEW.Kit.Close() end
		end)
	end
	f.Parent = parent
	return f
end

local function section(kit, parent, title, rows, empty)
	local h = label(kit, parent, title, 20, kit.Theme.Gold, kit.NextOrder())
	h.Font = Enum.Font.GothamBold
	if #rows == 0 then
		label(kit, parent, empty, 16, kit.Theme.SubText, kit.NextOrder())
		return
	end
	for _, row in rows do drawRow(kit, parent, row) end
end

local function paintTabs()
	local kit = VIEW.Kit
	if not (kit and VIEW.Tabs) then return end
	local ctx = context()
	for id, b in VIEW.Tabs do
		local on = S.Tab == id
		kit.Paint(b, on and kit.Theme.Gold or kit.Palette.Button, on and kit.Palette.DarkText or kit.Theme.Text)
		local n = #QuestBook.Sections(id, ctx).InProgress
		local name = Config.QuestTabs.Names[id] or id
		b.Text = n > 0 and string.format(T.Text.TabCount, name, n) or name
	end
end

local function drawBody()
	local kit, body = VIEW.Kit, VIEW.Body
	if not (kit and body) then return end
	for _, ch in body:GetChildren() do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
	local sec = QuestBook.Sections(S.Tab, context())
	section(kit, body, T.Text.InProgress, sec.InProgress, T.Text.EmptyInProgress)
	section(kit, body, T.Text.Available, sec.Available, T.Text.EmptyAvailable)
	section(kit, body, T.Text.Done, sec.Done, T.Text.EmptyDone)
	paintTabs()
end

function QuestBook.ShowTab(id)
	if not table.find(tabs(), id) then return end
	S.Tab = id
	drawBody()
end

-- the tab of my 'now do' quest when the window opens without one asked for
local function startTab()
	local entries = hudCall("QuestEntries") or {}
	local first = entries[1]
	return first and QuestBook.TabOf(first) or "Main"
end

local function build(parent, kit, arg)
	VIEW.Parent, VIEW.Kit = parent, kit
	if type(arg) == "table" and table.find(tabs(), arg.Tab) then
		S.Tab = arg.Tab
	elseif not S.Opened then
		S.Tab = startTab()
	end
	S.Opened = true
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, T.TabH)
	local bl = Instance.new("UIListLayout")
	bl.FillDirection = Enum.FillDirection.Horizontal
	bl.SortOrder = Enum.SortOrder.LayoutOrder
	bl.Padding = UDim.new(0, 6)
	bl.Parent = bar
	bar.Parent = parent
	VIEW.Tabs = {}
	local n = #tabs()
	for i, id in tabs() do
		local b = kit.Button(bar, Config.QuestTabs.Names[id] or id, kit.Palette.Button,
			UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), function() QuestBook.ShowTab(id) end)
		b.LayoutOrder = i
		VIEW.Tabs[id] = b
	end
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, T.TabH + 10)
	body.Size = UDim2.new(1, 0, 1, -(T.TabH + 10))
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
	body.ScrollBarThickness = 6
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = body
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 2), UDim.new(0, 12)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 2), UDim.new(0, 8)
	pad.Parent = body
	body.Parent = parent
	VIEW.Body = body
	drawBody()
	return nil
end

local function cleanup()
	VIEW.Parent, VIEW.Kit, VIEW.Tabs, VIEW.Body = nil, nil, nil, nil
end

function QuestBook.IsReady()
	return S.Ready
end

-- open (true) / close (false) / toggle (nil) the window
function QuestBook.Toggle(open)
	local panels = C and C.Panels
	if type(panels) ~= "table" then return end
	local current = type(panels.CurrentId) == "function" and panels.CurrentId() or nil
	if open == false or (open == nil and current == T.Window) then
		if current == T.Window then panels.Close(true) end
		return
	end
	if current ~= T.Window then panels.Open(T.Window) end
end

function QuestBook.Init(registry)
	C = registry
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the quest window is off")
		return
	end
	S.Ready = panels.Register(T.Window, {
		Title = T.Text.Title,
		FixedBody = true,
		Rebuild = { DailyClaims = true, TutorialStep = true, WantedStars = true },
		Build = build,
		Cleanup = cleanup,
	}) == true
end

function QuestBook.Start()
	local hud = C and C.HUD
	if type(hud) == "table" and type(hud.QuestsChanged) == "table" and type(hud.QuestsChanged.Connect) == "function" then
		S.Conn = hud.QuestsChanged:Connect(function()
			if VIEW.Body then
				local ok, err = pcall(drawBody)
				if not ok then Util.Warn(TAG, "redraw failed: " .. tostring(err)) end
			end
		end)
	end
end

return QuestBook
