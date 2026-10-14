-- KingDiary.luau (게임성 개발 1, SPEC A23-79 #4 "호박 대왕 일기 + 사탕 단지"; server = 게임성 개발 3's DiaryService,
-- docs/design/return_server_2026-10-08.md): the King Diary book and the candy jar, Panels window "Diary" with two tabs.
--   Diary: the 9 pages are Config.Halloween.Banter.Days (the two kings' lines of each day); DiaryPages (attribute 0..9,
--   DiaryService) are open. Page N belongs to the N-th day from Banter.DayOneStart (10/31 KST); a closed page says when
--   it opens (a day still to come) or how (beat a king together, any day already here). Page 9's Ghost King line has the
--   server's only %d (kings beaten on this server): the book leaves that sentence out. Nine pages = the title Party
--   Guest 2026 (Config.Diary.Title).
--   Candy Jar (open after the season too): Config.CandyJar.Trades -> a title (Config.TitleDefs) for candy; my candy =
--   the owner's "Inventory" payload (Items.Candy), my titles = TitlesOwned. [Trade] fires c->s "CandyTrade"(id); the
--   server takes the candy (or says "You need N candy.") and gives the title. No stats, nothing sold.
--   Fx "DiaryPage" { Page, Today, Late } -> a calm card "Page N is open!" [Read] (PauseCard "Tip": waits for a quiet
--   screen) that opens the book on that page; Fx "DiaryDone" {} -> the shared reward popup (glow + sparkles, no rays).
--   The server already shows "King Diary: page N!" / "New title: …" lines. The quest window's Event tab links here.
-- Game text: English only (A23-48), short and easy. Presentation only: the server owns every page, candy and title.
-- Public API: KingDiary.Init(C), KingDiary.Start(), KingDiary.IsReady(), KingDiary.Open(arg?), KingDiary.TodayPage(now),
-- KingDiary.Pages(ctx) -> rows, KingDiary.JarRows(ctx) -> rows, KingDiary.KingLine(key, text), KingDiary.OnFx(kind, data),
-- KingDiary.OnInventory(payload), KingDiary.Trade(id) -> bool (pure parts take ctx = { Pages, Now, Candy, Titles }).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local KingDiary = {}
local C = nil
local TAG = "KingDiary"

local T = {
	Window = "Diary",
	Remote = "CandyTrade",
	TabH = 40,
	TradeGap = 1.2, -- s: one [Trade] at a time (Config.RateLimits.CandyTrade + a margin)
	KST = 9 * 3600,
	Months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" },
	-- game text: English only (A23-48)
	Text = Config.ClientText.KingDiary, -- the words: Config.ClientText.KingDiary (moved 10/14)
}
local S = { Ready = false, Tab = "Diary", Page = nil, Candy = 0, TradeAt = -math.huge }
local VIEW = { Kit = nil, Tabs = nil, Body = nil }

local function hw() return type(Config.Halloween) == "table" and Config.Halloween or {} end
local function banter() return type(hw().Banter) == "table" and hw().Banter or {} end
local function days() return type(banter().Days) == "table" and banter().Days or {} end

local function dateOf(t)
	local d = os.date("!*t", math.floor(t) + T.KST)
	return string.format("%s %d", T.Months[d.month] or "?", d.day)
end

-- the page today belongs to (1 before the first day; never past the last page)
function KingDiary.TodayPage(now)
	local first = tonumber(banter().DayOneStart) or 0
	local n = #days()
	if n < 1 then return 0 end
	if now < first then return 1 end
	return math.clamp(math.floor((now - first) / 86400) + 1, 1, n)
end

local function seasonOn(now)
	return hw().Enabled ~= false and now < (tonumber(hw().EndsAt) or 0)
end

-- one king's line: "<King name>: "<words>"" without a sentence holding the server's %d
function KingDiary.KingLine(key, text)
	if type(text) ~= "string" then return nil end
	local words = string.gsub(text, "%s*[^%.!%?]*%%d[^%.!%?]*[%.!%?]", "")
	local def = Config.MonsterTypes and Config.MonsterTypes[key]
	local name = type(def) == "table" and def.Name or tostring(key)
	return string.format(banter().Format or "%s: \"%s\"", name, words)
end

-- the book: { Page, Head, Open, Lines = { string } | nil, Note = string | nil }
function KingDiary.Pages(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local open = math.floor(tonumber(ctx.Pages) or 0)
	local now = tonumber(ctx.Now) or os.time()
	local first = tonumber(banter().DayOneStart) or 0
	local today, live = KingDiary.TodayPage(now), seasonOn(now)
	local order = {}
	for _, b in type(hw().Bosses) == "table" and hw().Bosses or {} do
		if type(b) == "table" and type(b.Key) == "string" then table.insert(order, b.Key) end
	end
	local rows = {}
	for i, day in days() do
		local row = { Page = i, Head = string.format(T.Text.PageHead, i, dateOf(first + (i - 1) * 86400)), Open = i <= open }
		if row.Open then
			row.Lines = {}
			for _, key in order do
				local line = type(day) == "table" and KingDiary.KingLine(key, day[key]) or nil
				if line then table.insert(row.Lines, line) end
			end
		elseif not live then
			row.Note = T.Text.Closed
		elseif i > today then
			row.Note = string.format(T.Text.Soon, dateOf(first + (i - 1) * 86400))
		else
			row.Note = T.Text.Locked
		end
		table.insert(rows, row)
	end
	return rows
end

-- the jar: { Id, Name, Candy, Owned, CanTrade }
function KingDiary.JarRows(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local candy = math.floor(tonumber(ctx.Candy) or 0)
	local owned = {}
	for id in string.gmatch(type(ctx.Titles) == "string" and ctx.Titles or "", "[^,]+") do owned[id] = true end
	local rows = {}
	local jar = type(Config.CandyJar) == "table" and Config.CandyJar.Trades or {}
	for _, e in type(jar) == "table" and jar or {} do
		local def = type(e) == "table" and Config.TitleDefs and Config.TitleDefs[e.Title]
		if def then
			local cost = math.max(1, math.floor(tonumber(e.Candy) or 1))
			local mine = owned[e.Title] == true
			table.insert(rows, { Id = e.Id, Name = def.NameEn or def.Name or e.Title, Candy = cost, Owned = mine,
				CanTrade = not mine and candy >= cost })
		end
	end
	return rows
end

----------------------------------------------------------------- the window
local function attr(name)
	return LocalPlayer and LocalPlayer:GetAttribute(name) or nil
end

local function context()
	local panels = C and C.Panels
	if not S.HasCandy and type(panels) == "table" and type(panels.ItemCount) == "function" then
		local ok, n = pcall(panels.ItemCount, "Candy")
		if ok and type(n) == "number" then S.Candy = math.floor(n) end
	end
	return { Pages = attr("DiaryPages"), Now = os.time(), Candy = S.Candy, Titles = attr("TitlesOwned") }
end

function KingDiary.Trade(id)
	if os.clock() - S.TradeAt < T.TradeGap then return false end
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	local remote = folder and folder:FindFirstChild(T.Remote)
	if not remote or not remote:IsA("RemoteEvent") then return false end
	S.TradeAt = os.clock()
	return (pcall(remote.FireServer, remote, id))
end

local function label(kit, parent, text, size, color, width)
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
	l.LayoutOrder = kit.NextOrder()
	l.Parent = parent
	return l
end

local function block(kit, parent, name)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = kit.Palette.Button
	f.BackgroundTransparency = 0.6
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.LayoutOrder = kit.NextOrder()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 10)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = f
	f.Parent = parent
	return f
end

local function vlist(parent, gap, horizontal)
	local list = Instance.new("UIListLayout")
	list.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	list.Parent = parent
end

local function drawDiary(kit, body)
	local ctx = context()
	local pages = KingDiary.Pages(ctx)
	local open = math.floor(tonumber(ctx.Pages) or 0)
	local def = Config.TitleDefs and Config.TitleDefs[Config.Diary and Config.Diary.Title or ""]
	local head = string.format(T.Text.Count, math.min(open, #pages), #pages)
	if #pages > 0 and open >= #pages and def then
		head = string.format(T.Text.AllRead, def.NameEn or def.Name)
	end
	local h = label(kit, body, head, 20, kit.Theme.Gold)
	h.Font = Enum.Font.GothamBold
	local focus = nil
	for _, row in pages do
		local f = block(kit, body, "Page" .. row.Page)
		vlist(f, 4)
		local hl = label(kit, f, row.Head, 18, row.Page == S.Page and kit.Theme.Gold or kit.Theme.Text)
		hl.Font = Enum.Font.GothamBold
		if row.Open then
			for _, line in row.Lines do label(kit, f, line, 17, kit.Theme.Text) end
		else
			f.BackgroundTransparency = 0.8
			label(kit, f, row.Note or "", 16, kit.Theme.SubText)
		end
		if row.Page == S.Page then focus = f end
	end
	if focus then
		task.defer(function()
			if focus.Parent and body.Parent then
				pcall(function() body.CanvasPosition = Vector2.new(0, math.max(0, focus.AbsolutePosition.Y - body.AbsolutePosition.Y)) end)
			end
		end)
	end
end

local function drawJar(kit, body)
	local ctx = context()
	local h = label(kit, body, string.format(T.Text.Candy, math.floor(tonumber(ctx.Candy) or 0)), 20, kit.Theme.Gold)
	h.Font = Enum.Font.GothamBold
	label(kit, body, T.Text.JarNote, 16, kit.Theme.SubText)
	for _, row in KingDiary.JarRows(ctx) do
		local f = block(kit, body, "Jar" .. tostring(row.Id))
		vlist(f, 8, true)
		local name = label(kit, f, row.Name, 18, kit.Theme.Text, UDim2.new(1, -230, 0, 0))
		name.Font = Enum.Font.GothamBold
		local cost = label(kit, f, string.format(T.Text.Cost, row.Candy), 16, kit.Theme.Gold, UDim2.fromOffset(110, 0))
		cost.TextXAlignment = Enum.TextXAlignment.Right
		if row.Owned then
			local o = label(kit, f, T.Text.Owned, 16, kit.Theme.SubText, UDim2.fromOffset(96, 0))
			o.TextXAlignment = Enum.TextXAlignment.Center
		else
			local b = kit.Button(f, T.Text.Trade, kit.Theme.Good, UDim2.fromOffset(96, 34), function()
				KingDiary.Trade(row.Id)
			end)
			b.LayoutOrder = kit.NextOrder()
			if type(kit.SetEnabled) == "function" then pcall(kit.SetEnabled, b, row.CanTrade) end
		end
	end
end

local function paintTabs()
	local kit = VIEW.Kit
	if not (kit and VIEW.Tabs) then return end
	for id, b in VIEW.Tabs do
		local on = S.Tab == id
		kit.Paint(b, on and kit.Theme.Gold or kit.Palette.Button, on and kit.Palette.DarkText or kit.Theme.Text)
	end
end

local function drawBody()
	local kit, body = VIEW.Kit, VIEW.Body
	if not (kit and body) then return end
	for _, ch in body:GetChildren() do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
	if S.Tab == "Jar" then drawJar(kit, body) else drawDiary(kit, body) end
	paintTabs()
end

local function showTab(id)
	S.Tab = id == "Jar" and "Jar" or "Diary"
	drawBody()
end

local function build(parent, kit, arg)
	VIEW.Kit = kit
	S.Page = nil
	if type(arg) == "table" then
		if arg.Tab == "Jar" or arg.Tab == "Diary" then S.Tab = arg.Tab end
		if type(arg.Page) == "number" then S.Tab, S.Page = "Diary", math.floor(arg.Page) end
	end
	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.new(1, 0, 0, T.TabH)
	vlist(bar, 6, true)
	bar.Parent = parent
	VIEW.Tabs = {}
	for i, id in { "Diary", "Jar" } do
		local b = kit.Button(bar, id == "Jar" and T.Text.TabJar or T.Text.TabDiary, kit.Palette.Button, UDim2.new(0.5, -3, 1, 0),
			function() showTab(id) end)
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
	vlist(body, 8)
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
	VIEW.Kit, VIEW.Tabs, VIEW.Body = nil, nil, nil
end

function KingDiary.IsReady()
	return S.Ready
end

-- the page the open book was asked to show ([Read] on a page card), nil = opened without one (Audio: DiaryPage)
function KingDiary.FocusPage()
	return VIEW.Kit ~= nil and S.Page or nil
end

function KingDiary.Open(arg)
	local panels = C and C.Panels
	if not S.Ready or type(panels) ~= "table" or type(panels.Open) ~= "function" then return false end
	return (pcall(panels.Open, T.Window, arg))
end

-- the owner's "Inventory" payload: my candy (the jar redraws while open)
function KingDiary.OnInventory(payload)
	if type(payload) ~= "table" or type(payload.Items) ~= "table" then return end
	local n = tonumber(payload.Items.Candy) or 0
	S.Candy = (n == n and n >= 0 and n < math.huge) and math.floor(n) or 0
	S.HasCandy = true -- a payload of my own came: Panels' cache is no longer needed
	if VIEW.Body and S.Tab == "Jar" then pcall(drawBody) end
end

function KingDiary.OnFx(kind, data)
	if kind == "DiaryPage" then
		local page = type(data) == "table" and tonumber(data.Page) or nil
		local pc = C and C.PauseCard
		if not page or type(pc) ~= "table" or type(pc.Show) ~= "function" then return false end
		page = math.floor(page)
		return pc.Show("Tip", { Title = T.Text.CardTitle, Text = string.format(T.Text.CardPage, page),
			Go = { Text = T.Text.CardRead, Window = T.Window, Arg = { Page = page } } })
	elseif kind == "DiaryDone" then
		local kit = C and C.UIKit
		local def = Config.TitleDefs and Config.TitleDefs[Config.Diary and Config.Diary.Title or ""]
		if type(kit) ~= "table" or type(kit.RewardPopup) ~= "function" or not def then return false end
		local ok = pcall(kit.RewardPopup, {
			Title = T.Text.Title,
			Lines = { string.format(T.Text.DoneLine, #days()), string.format(T.Text.DoneTitle, def.NameEn or def.Name) },
			Button = T.Text.DoneOK,
			Faction = LocalPlayer and LocalPlayer:GetAttribute("Faction") or nil,
		})
		return ok
	end
	return nil
end

function KingDiary.Init(registry)
	C = registry
	local panels = C and C.Panels
	if type(panels) ~= "table" or type(panels.Register) ~= "function" then
		Util.Warn(TAG, "Panels.Register is missing; the diary is off")
		return
	end
	S.Ready = panels.Register(T.Window, {
		Title = T.Text.Title,
		FixedBody = true,
		Rebuild = { DiaryPages = true, TitlesOwned = true },
		Build = build,
		Cleanup = cleanup,
	}) == true
end

function KingDiary.Start()
	task.spawn(function()
		local ok, err = pcall(function()
			Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
				pcall(KingDiary.OnFx, kind, data)
			end)
			Net.Get("Inventory").OnClientEvent:Connect(function(payload)
				pcall(KingDiary.OnInventory, payload)
			end)
		end)
		if not ok then Util.Warn(TAG, "remote hookup failed: " .. tostring(err)) end
	end)
end

return KingDiary
