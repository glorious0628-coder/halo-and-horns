-- QuestBook.luau (게임성 개발 1, SPEC A23-81 "Q = 전체 퀘스트 창", user 2026-10-08 15:05): the quest window, Panels id
-- "Journal" (the Q key since A23-78; the HUD's ▼ button and a phone tap on the quest lines open it too). Five tabs
-- (Config.QuestTabs.Order: Main · Side · Daily · Event · Faction; Config.QuestTab(id, kind) sorts a quest), each with
-- In progress / Available / Done.
--   In progress = the HUD's quest rows of that tab (HUD.QuestEntries: the server's rows - quests in progress or ready to
--   claim, the same tables the HUD lines use) + info lines nobody claims: the live world events on Event (golden goose,
--   Pumpkin / Ghost King, kaiju, the crown war's next crown) and my wanted stars on Faction.
--   Available / Done = the server's quest book (HUD.QuestBook, 게임성 개발 3's contract on the "Quests" remote:
--   { Available = { { Id = "story:<id>", Kind = "Sub", Level?, Text? } }, Done = { "story:<id>" } }; a sub waiting for
--   a level comes with Text "Title · Opens at Lv N", a ready one with no Text = its story title). The main chain has no
--   level gate, so the Main tab has no Available section (검수 10/08). Done also lists what the book does not keep: the
--   first mission once it is over, today's daily count and what I finished this session that is no story quest
--   (HUD.QuestDoneSession). Until a book comes, Done = the main chain before my main quest (Config.StoryQuests.Main) too.
-- A row = the quest's words and 3/5; [Claim] / [New] when the HUD's rules allow (HUD.QuestCanClaim / QuestCanReroll ->
-- HUD.QuestClaim / QuestReroll); a press on the row closes the window and guides me there like the HUD lines
-- (HUD.QuestGo). Redraws on HUD.QuestsChanged while open. Game text: English only (A23-48), short and easy.
-- Public API: QuestBook.Init(C), QuestBook.Start(), QuestBook.IsReady(), QuestBook.Toggle(open?), QuestBook.ShowTab(id),
-- QuestBook.TabOf(entry), QuestBook.Sections(tab, ctx) -> { InProgress, Available, Done } (pure: ctx = { Entries, Book,
-- DoneSession, Attr = fn(name), GameAttr = fn(name), Now }; the offline test drives it).
-- Studio-only check hook (이미지 개발's photos, 검수 10/09): the local attribute QuestBookPreview = "<Tab>" or
-- "<Tab>,<mode>" (full | empty | long; full by default) opens the window on that tab with sample rows
-- (QuestBook.PreviewContext; [Claim] / [New] / a row press do nothing then); "" closes it and the real rows come
-- back. Never read outside Studio.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local QuestBook = {}
local C = nil
local TAG = "QuestBook"

local T = {
	Window = "Journal",
	TabH = 40,
	TabIcon = 22, -- 검수 10/09 (user OK): the tab's QuestTabIcon<tab> left of its word
	RowText = 18,
	NumText = 16,
	BtnW = 84,
	BtnH = 34,
	-- game text: English only (A23-48)
	Text = Config.ClientText.QuestBook, -- the words: Config.ClientText.QuestBook (moved 10/14)
}
T.NoAvailable = { Main = true } -- tabs without an Available section (the main chain is never waiting to be picked up)
-- the Studio preview's sample rows (QuestBook.PreviewContext): one or more per tab, a claimable and a rerollable daily
T.Preview = {
	Modes = { full = true, empty = true, long = true },
	Long = " and then come back to the fountain in the Crossroads to tell everyone",
	Entries = {
		{ Id = "story:M1_3", Kind = "Main", Story = { Id = "M1_3" }, Text = "Help the Slime Mayor", Progress = 2, Target = 3 },
		{ Id = "job:1", Kind = "Job", Text = "Bring jelly drops to the board", Progress = 1, Target = 3 },
		{ Id = "Kill", Kind = "Daily", Slot = 1, Text = "Defeat Slime ×5", Progress = 5, Target = 5 },
		{ Id = "Gold", Kind = "Daily", Slot = 2, Text = "Collect 60 gold", Progress = 20, Target = 60 },
		{ Id = "story:S1", Kind = "Sub", Text = "Find the Golden Goose", Progress = 0, Target = 1 },
		{ Id = "story:H1", Kind = "Sub", Text = "Light the hero's lantern", Progress = 1, Target = 2 },
	},
	Available = {
		{ Id = "story:PreviewSide", Kind = "Sub", Text = "The lost lamb · Opens at Lv 8" },
		{ Id = "story:PreviewSide2", Kind = "Sub", Text = "Fix the old bridge" },
		{ Id = "story:R1", Kind = "Sub", Text = "The red flag · Opens at Lv 12" },
	},
	Done = {
		{ Id = "story:M1_1", Kind = "Main", Text = "Meet the guide" },
		{ Id = "story:M1_2", Kind = "Main", Text = "Your first weapon" },
		{ Id = "story:PreviewSideDone", Kind = "Sub", Text = "Help the farmer" },
		{ Id = "story:S2", Kind = "Sub", Text = "Feed the goose" },
		{ Id = "story:H2", Kind = "Sub", Text = "A gift for the castle" },
	},
	Attr = { TutorialStep = 99, DailyClaims = 1, WantedStars = 2 },
	GameAttr = { GooseActive = true },
	WarIn = 125,
}
local S = { Ready = false, Tab = "Main", Conn = nil, Preview = nil }
local VIEW = { Parent = nil, Kit = nil, Tabs = nil, Body = nil } -- the open window's parts (nil while closed)

local function tabs() return Config.QuestTabs.Order end

-- A23-104 / 검수 10/10 (a Lv1 photo showed all five tabs): the tabs the window shows (pure) - Daily is hidden while the
-- server says DailyLocked, and a tab with nothing in it (no row in progress, available or done) is hidden until it
-- has one; Main (the first tab) always shows
function QuestBook.VisibleTabs(ctx)
	ctx = type(ctx) == "table" and ctx or {}
	local out = {}
	for i, id in tabs() do
		local keep = i == 1
		if not keep and not (id == "Daily" and ctx.DailyLocked == true) then
			local sec = QuestBook.Sections(id, ctx)
			keep = #sec.InProgress + #sec.Available + #sec.Done > 0
		end
		if keep then table.insert(out, id) end
	end
	return out
end

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
		-- A23-79 #4: the King Diary (a page opens when a king is beaten together) and the candy jar, while the season runs
		-- or once I have a page (the jar stays open after the season); a press opens that window (KingDiary.luau)
		local hw = Config.Halloween
		local pages = math.floor(tonumber(attr("DiaryPages")) or 0)
		local live = type(hw) == "table" and hw.Enabled ~= false and now < (tonumber(hw.EndsAt) or 0)
		local total = type(hw) == "table" and type(hw.Banter) == "table" and type(hw.Banter.Days) == "table" and #hw.Banter.Days or 0
		if ctx.HasDiary == true and total > 0 and (live or pages > 0) then
			table.insert(out.InProgress, { Kind = "Link", Text = string.format(T.Text.Diary, math.min(pages, total), total),
				Window = "Diary", Arg = { Tab = "Diary" } })
			table.insert(out.InProgress, { Kind = "Link", Text = T.Text.Jar, Window = "Diary", Arg = { Tab = "Jar" } })
		end
	elseif tab == "Faction" then
		local stars = math.floor(tonumber(attr("WantedStars")) or 0)
		if stars > 0 then table.insert(out.InProgress, { Kind = "Info", Text = string.format(T.Text.Wanted, stars) }) end
	end
	-- the server's book, when it sends one (story quests only; newest first)
	local book = type(ctx.Book) == "table" and ctx.Book or nil
	local seen = {}
	local function done(text)
		if type(text) == "string" and text ~= "" and not seen[text] then
			seen[text] = true
			table.insert(out.Done, { Kind = "Done", Text = text })
		end
	end
	if book then
		if not T.NoAvailable[tab] then
			for _, r in type(book.Available) == "table" and book.Available or {} do
				local row = bookRow(r)
				if row and row.Tab == tab then
					row.Kind = "Available"
					table.insert(out.Available, row)
				end
			end
		end
		for _, r in type(book.Done) == "table" and book.Done or {} do
			local row = bookRow(r)
			if row and row.Tab == tab then done(row.Text) end
		end
	end
	-- what the book does not keep (and, with no book yet, what the client can tell)
	if tab == "Main" then
		local steps = Config.Tutorial and Config.Tutorial.Steps
		local doneStep = type(steps) == "table" and tonumber(steps.Done) or 99
		local step = tonumber(attr("TutorialStep"))
		if (step and step >= doneStep) or mainId then done(T.Text.FirstMission) end
		local chain = Config.StoryQuests and Config.StoryQuests.Main
		if not book and mainId and type(chain) == "table" then
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
		local story = type(d) == "table" and storyDef(d.Id) ~= nil
		if type(d) == "table" and Config.QuestTab(d.Id, d.Kind) == tab and not (book and story) then
			local _, def = storyDef(d.Id)
			done((def and def.Title) or d.Text)
		end
	end
	return out
end

----------------------------------------------------------------- the Studio preview (pure parts)
-- "<Tab>" / "<Tab>,<mode>" -> tab, mode (nil for "" / an unknown tab / an unknown mode)
function QuestBook.ParsePreview(v)
	if type(v) ~= "string" then return nil end
	local tab, mode = string.match(v, "^%s*(%a+)%s*,?%s*(%a*)%s*$")
	if not tab or not table.find(tabs(), tab) then return nil end
	mode = (mode == nil or mode == "") and "full" or string.lower(mode)
	if not T.Preview.Modes[mode] then return nil end
	return tab, mode
end

-- the sample context for QuestBook.Sections (mode full | empty | long; now = the clock for the crown war line)
function QuestBook.PreviewContext(mode, now)
	local P = T.Preview
	local empty = mode == "empty"
	local function copy(list)
		local out = {}
		if empty then return out end
		for _, r in list do
			local c = table.clone(r)
			if mode == "long" then c.Text = c.Text .. P.Long end
			table.insert(out, c)
		end
		return out
	end
	local gattr = empty and {} or table.clone(P.GameAttr)
	if not empty then gattr.WarRoundEndsAt = (tonumber(now) or 0) + P.WarIn end
	local attr = empty and {} or P.Attr
	return {
		Entries = copy(P.Entries),
		Book = { Available = copy(P.Available), Done = copy(P.Done) },
		DoneSession = {},
		HasDiary = false,
		Attr = function(name) return attr[name] end,
		GameAttr = function(name) return gattr[name] end,
		Now = tonumber(now) or 0,
		CanClaim = function(e) return e.Progress >= e.Target end,
		CanReroll = function(e) return e.Kind == "Daily" and e.Progress < e.Target end,
	}
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
	if S.Preview then return QuestBook.PreviewContext(S.Preview, Util.Now()) end
	local kit = VIEW.Kit
	return {
		Entries = hudCall("QuestEntries") or {},
		Book = hudCall("QuestBook"),
		DailyLocked = hudCall("DailyLocked") == true,
		DoneSession = hudCall("QuestDoneSession") or {},
		HasDiary = C and type(C.KingDiary) == "table" and type(C.KingDiary.IsReady) == "function" and C.KingDiary.IsReady() or false,
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

-- 최종 검수 10/15 (Korean client: the list row 'Go to Otto's Forge in the Crossroads' stayed English, like the HUD goal
-- line did - HUD.QuestGoal): the server sends the English sentence, so translate it by its English text (UIKit.TrWord)
-- before drawing; a "words · tail" row is tried whole first, then piece by piece. English client = unchanged
function QuestBook.RowWords(text, trWord)
	if type(text) ~= "string" or text == "" or type(trWord) ~= "function" then return text end
	local ok, out = pcall(trWord, text)
	if ok and type(out) == "string" and out ~= "" and out ~= text then return out end
	if not string.find(text, " · ", 1, true) then return text end
	local parts = {}
	for piece in string.gmatch(text .. " · ", "(.-) · ") do
		local okp, p = pcall(trWord, piece)
		table.insert(parts, (okp and type(p) == "string" and p ~= "") and p or piece)
	end
	return table.concat(parts, " · ")
end

local function rowWords(text)
	local ui = C and C.UIKit
	return QuestBook.RowWords(text, type(ui) == "table" and ui.TrWord or nil)
end

-- one row: the words (+ 3/5), [Claim] / [New]; a press on a quest row guides me there and closes the window
local function drawRow(kit, parent, row)
	local press = row.Kind == "Quest" or row.Kind == "Link"
	local f = Instance.new(press and "TextButton" or "Frame")
	f.Name = row.Kind
	f.BackgroundColor3 = kit.Palette.Button
	f.BackgroundTransparency = press and 0.55 or 0.8
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
	-- 퀘스트 바이블 §15 P1 ③: a quest row (not the main story: it always shows) can be pinned to the HUD, at most 2
	local canPin = row.Kind == "Quest" and type(row.Entry) == "table" and row.Entry.Kind ~= "Main" and not S.Preview
	local buttons = (row.CanClaim and 1 or 0) + (row.CanReroll and 1 or 0) + (canPin and 1 or 0)
	local reserve = buttons * (T.BtnW + 8) + (row.Nums and 64 or 0)
	local color = row.Kind == "Done" and kit.Theme.SubText or kit.Theme.Text
	label(kit, f, rowWords(row.Text), T.RowText, color, 1, UDim2.new(1, -reserve, 0, 0))
	if row.Nums then
		local n = label(kit, f, row.Nums, T.NumText, kit.Theme.Gold, 2, UDim2.fromOffset(56, 0))
		n.TextXAlignment = Enum.TextXAlignment.Right
	end
	if row.CanClaim then
		local b = kit.Button(f, T.Text.Claim, kit.Theme.Good, UDim2.fromOffset(T.BtnW, T.BtnH), function()
			if S.Preview then return end -- sample rows: nothing to claim
			hudCall("QuestClaim", row.Entry)
		end)
		b.LayoutOrder = 3
	end
	if canPin then
		local pinned = hudCall("IsPinned", row.Entry) == true
		local b
		b = kit.Button(f, pinned and T.Text.Unpin or T.Text.Pin, pinned and kit.Theme.Gold or kit.Palette.Button,
			UDim2.fromOffset(T.BtnW, T.BtnH), function()
				local res = hudCall("TogglePin", row.Entry)
				if res == nil then
					local ui = C and C.UIKit
					if type(ui) == "table" and type(ui.Refuse) == "function" then pcall(ui.Refuse, b) end -- two pins already
					return
				end
				task.defer(QuestBook.Redraw)
			end)
		b.Name = "Pin"
		b.LayoutOrder = 5
	end
	if row.CanReroll then
		local b = kit.Button(f, T.Text.Reroll, kit.Palette.Button, UDim2.fromOffset(T.BtnW, T.BtnH), function()
			if S.Preview then return end
			hudCall("QuestReroll", row.Entry)
		end)
		b.LayoutOrder = 4
	end
	if row.Kind == "Quest" then
		f.Activated:Connect(function()
			if S.Preview then return end
			if hudCall("QuestGo", row.Entry) and VIEW.Kit then VIEW.Kit.Close() end
		end)
	elseif row.Kind == "Link" then
		f.Activated:Connect(function()
			if VIEW.Kit then VIEW.Kit.Open(row.Window, row.Arg) end -- with a back button to the quests
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
		local n = 0
		for _, r in QuestBook.Sections(id, ctx).InProgress do
			if r.Kind ~= "Link" then n += 1 end -- a window link is no quest to count
		end
		local name = Config.QuestTabs.Names[id] or id
		b.Text = n > 0 and string.format(T.Text.TabCount, name, n) or name
	end
end

local makeTabs -- (below: the tab buttons of the visible tabs)

-- the open window drawn again (a pin changed)
function QuestBook.Redraw()
	if VIEW.Body then pcall(QuestBook.DrawBody) end
end

local function drawBody()
	local kit, body = VIEW.Kit, VIEW.Body
	if not (kit and body) then return end
	for _, ch in body:GetChildren() do
		if not ch:IsA("UIListLayout") and not ch:IsA("UIPadding") then ch:Destroy() end
	end
	local ctx = context()
	-- the tab set follows what there is (a tab appears with its first row, Daily once the daily jobs open)
	local vis = S.Preview and tabs() or QuestBook.VisibleTabs(ctx) -- the Studio photos show every tab
	if not table.find(vis, S.Tab) then S.Tab = vis[1] or Config.QuestTabs.Default end
	if table.concat(vis, ",") ~= VIEW.TabSig then makeTabs(vis) end
	local sec = QuestBook.Sections(S.Tab, ctx)
	section(kit, body, T.Text.InProgress, sec.InProgress, T.Text.EmptyInProgress)
	if not T.NoAvailable[S.Tab] then section(kit, body, T.Text.Available, sec.Available, T.Text.EmptyAvailable) end
	section(kit, body, T.Text.Done, sec.Done, T.Text.EmptyDone)
	paintTabs()
end
QuestBook.DrawBody = drawBody

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

-- the tab's icon (Config.UIArt QuestTabIcon<tab>, 이미지 생성 2) left of its word; no art = the word alone
local function tabIcon(b, id)
	local ui = C and C.UIKit
	local ok, img = false, nil
	if type(ui) == "table" and type(ui.ArtId) == "function" then ok, img = pcall(ui.ArtId, "QuestTabIcon" .. id) end
	if not ok or type(img) ~= "string" or img == "" then return nil end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, T.TabIcon + 6)
	pad.Parent = b
	local icon = Instance.new("ImageLabel")
	icon.Name = "TabIcon"
	icon.BackgroundTransparency = 1
	icon.Image = img
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.Position = UDim2.new(0, -3, 0.5, 0) -- in the padding, just left of the word
	icon.Size = UDim2.fromOffset(T.TabIcon, T.TabIcon)
	icon.ZIndex = (tonumber(b.ZIndex) or 1) + 2
	icon.Parent = b
	return icon
end

-- the tab buttons of the visible tabs (made again when that set changes)
function makeTabs(vis)
	local kit, bar = VIEW.Kit, VIEW.Bar
	if not (kit and bar) then return end
	for _, ch in bar:GetChildren() do
		if ch:IsA("GuiButton") then ch:Destroy() end
	end
	VIEW.Tabs = {}
	VIEW.TabSig = table.concat(vis, ",")
	local n = math.max(1, #vis)
	for i, id in vis do
		local b = kit.Button(bar, Config.QuestTabs.Names[id] or id, kit.Palette.Button,
			UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0), function()
				-- sound_gaps 2026-10-10: the tab's own sound instead of the Click (NoClick); the open tab again = silent
				local audio = C and C.Audio
				if id ~= S.Tab and type(audio) == "table" and type(audio.Play) == "function" then pcall(audio.Play, "QuestTab") end
				QuestBook.ShowTab(id)
			end)
		pcall(b.SetAttribute, b, "NoClick", true)
		b.LayoutOrder = i
		tabIcon(b, id)
		VIEW.Tabs[id] = b
	end
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
	VIEW.Bar = bar
	VIEW.TabSig = nil
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
	VIEW.Parent, VIEW.Kit, VIEW.Tabs, VIEW.Body, VIEW.Bar, VIEW.TabSig = nil, nil, nil, nil, nil, nil
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
		Rebuild = { DailyClaims = true, TutorialStep = true, WantedStars = true, DiaryPages = true },
		Build = build,
		Cleanup = cleanup,
	}) == true
end

-- the Studio hook: QuestBookPreview changed
local function applyPreview(v)
	local tab, mode = QuestBook.ParsePreview(v)
	if tab then
		S.Preview, S.Tab, S.Opened = mode, tab, true
		if VIEW.Body then drawBody() else QuestBook.Toggle(true) end
	elseif S.Preview then
		S.Preview = nil
		QuestBook.Toggle(false)
	end
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
	if RunService:IsStudio() then
		local lp = Players.LocalPlayer
		if lp then
			lp:GetAttributeChangedSignal("QuestBookPreview"):Connect(function()
				local ok, err = pcall(applyPreview, lp:GetAttribute("QuestBookPreview"))
				if not ok then Util.Warn(TAG, "preview failed: " .. tostring(err)) end
			end)
		end
	end
end

return QuestBook
