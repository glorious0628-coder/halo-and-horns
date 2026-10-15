-- Offline checks for QuestBook.luau (SPEC A23-81: Q = the whole quest window, five tabs, In progress / Available /
-- Done) with the real Config.luau (Config.QuestTabs / Config.QuestTab, StoryQuests, Tutorial, Quests). The runner
-- (tools/test_quest_window.py) prepends CONFIG_SOURCE and BOOK_SOURCE. Roblox is replaced by small doubles: Instance-like
-- tables, a Panels double (Register / Open / Close / CurrentId), a window kit double (Button, Paint, Attr, GameAttr,
-- NextOrder, Close), a HUD double (QuestEntries, QuestBook, QuestDoneSession, QuestCanClaim / QuestCanReroll, QuestClaim /
-- QuestReroll / QuestGo, QuestsChanged). Every check is named; no Studio, Roblox API or network calls.
local checks, failed = 0, 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failed += 1
		print(("CHECK_FAIL %s :: %s"):format(name, tostring(detail or "")))
	end
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function signal()
	local s = { Fns = {} }
	function s:Connect(f) table.insert(self.Fns, f) return { Disconnect = function() end } end
	function s:Fire(...) for _, f in self.Fns do f(...) end end
	return s
end

-- Instance-like tables (Parent / Children / FindFirstChild / Destroy / Activated)
local imt = {}
imt.__index = function(self, k)
	local m = rawget(imt, "methods")[k]
	if m then return m end
	if k == "Activated" then local s = signal() rawset(self, k, s) return s end
	return nil
end
imt.methods = {
	FindFirstChild = function(self, n) for _, c in self.Children do if c.Name == n then return c end end return nil end,
	GetChildren = function(self) return table.clone(self.Children) end,
	IsA = function(self, cl)
		if cl == "GuiButton" then return self.ClassName == "TextButton" end
		return self.ClassName == cl
	end,
	Destroy = function(self)
		local p = rawget(self, "Parent")
		if p then
			local i = table.find(p.Children, self)
			if i then table.remove(p.Children, i) end
		end
		rawset(self, "Parent", nil)
	end,
}
imt.__newindex = function(self, k, v)
	if k == "Parent" then
		local old = rawget(self, "Parent")
		if old then
			local i = table.find(old.Children, self)
			if i then table.remove(old.Children, i) end
		end
		rawset(self, "Parent", v)
		if type(v) == "table" and v.Children then table.insert(v.Children, self) end
		return
	end
	rawset(self, k, v)
end
local function inst(class)
	return setmetatable({ ClassName = class, Name = class, Children = {} }, imt)
end
local function descendants(root, out)
	out = out or {}
	for _, c in root.Children do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end

local NOW = 5000
-- the Studio preview hook (RunService:IsStudio() + the local attribute QuestBookPreview)
local STUDIO = false
local LPATTR, LPSIG = {}, {}
local LP = {
	GetAttribute = function(_, n) return LPATTR[n] end,
	SetAttribute = function(_, n, v) LPATTR[n] = v if LPSIG[n] then LPSIG[n]:Fire() end end,
	GetAttributeChangedSignal = function(_, n) LPSIG[n] = LPSIG[n] or signal() return LPSIG[n] end,
}
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "RunService" then return { IsStudio = function() return STUDIO end } end
		if n == "Players" then return { LocalPlayer = LP } end
		if n == "ReplicatedStorage" then
			return { WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end }
		end
		return setmetatable({}, { __index = function() return function() return nil end end })
	end },
	Vector3 = ctor("Vector3"), Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromScale = function(x, y) return { x, 0, y, 0 } end,
		fromOffset = function(x, y) return { 0, x, 0, y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = { new = function(...) return { ... } end, fromRGB = function(...) return { ... } end, fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function(...) return { ... } end }, Enum = enum,
	Instance = { new = inst },
	typeof = function(v) return type(v) end,
	task = { delay = function() end, spawn = function(f, ...) f(...) end, wait = function() end, defer = function(f, ...) f(...) end },
	warn = function() end, print = print,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, env)
local Config = cfn()
env.require = function(m)
	if m.__module == "Config" then return Config end
	return { Warn = function() end, Now = function() return NOW end }
end
local bfn = assert(loadstring(BOOK_SOURCE, "=QuestBook"))
setfenv(bfn, env)
local Book = bfn()

-- quest rows like HUD.parseQuests makes them
local function row(id, kind, text, p, t, extra)
	local e = { Id = id, Kind = kind, Text = text, Progress = p or 0, Target = t or 1, CanClaim = true, ShowProgress = true }
	for k, v in extra or {} do e[k] = v end
	return e
end
local MAIN = row("story:M1_3", "Main", "Talk to the fountain", 0, 1, { Pinned = true, Story = { Id = "M1_3", St = 1 } })
local SIDE = row("story:S3", "Sub", "Find the lost jelly", 1, 3, { Story = { Id = "S3", St = 1 } })
local HALO = row("story:H2", "Sub", "Find Bright's lantern", 0, 1, { Story = { Id = "H2", St = 1 } })
local GOOSE = row("story:S1", "Sub", "Chase the goose", 0, 1, { Story = { Id = "S1", St = 1 } })
local KILL = row("Kill", "Daily", "Defeat slimes", 3, 5, { Slot = 1 })
local GOLD = row("Gold", "Daily", "Earn gold", 50, 50, { Slot = 2 })
local JOB = row("job:1", "Job", "Board job", 0, 2)
local ENTRIES = { MAIN, SIDE, HALO, GOOSE, KILL, GOLD, JOB }
local function claimRule(e) return e.Progress >= e.Target and e.CanClaim and (e.Pinned or e.Kind == "Daily" or e.Kind == "Sub") end
local function rerollRule(e) return e.Progress < e.Target and not e.Pinned and e.Slot ~= nil end
local ATTR, GATTR = { TutorialStep = 99, DailyClaims = 1, WantedStars = 0 }, {}
local function ctx(extra)
	local c = { Entries = ENTRIES, Book = nil, DoneSession = {}, Attr = function(n) return ATTR[n] end,
		GameAttr = function(n) return GATTR[n] end, Now = NOW, CanClaim = claimRule, CanReroll = rerollRule }
	for k, v in extra or {} do c[k] = v end
	return c
end
local function texts(rows)
	local out = {}
	for _, r in rows do table.insert(out, r.Text) end
	return table.concat(out, " | ")
end

-- 1) the tab of a quest (Config.QuestTabs, one table)
check("tutorial and main story -> Main", Book.TabOf(row("tutorial", "Tutorial", "x")) == "Main" and Book.TabOf(MAIN) == "Main")
check("a side story and a board job -> Side", Book.TabOf(SIDE) == "Side" and Book.TabOf(JOB) == "Side")
check("Halo / Horns / guild stories -> Faction", Book.TabOf(HALO) == "Faction"
	and Book.TabOf(row("story:R5", "Sub", "x")) == "Faction" and Book.TabOf(row("story:N1", "Sub", "x")) == "Faction")
check("goose / crown war stories -> Event", Book.TabOf(GOOSE) == "Event" and Book.TabOf(row("story:GW4", "Sub", "x")) == "Event")
check("every daily / extra slot -> Daily", Book.TabOf(KILL) == "Daily" and Book.TabOf(row("Plunder", "Extra", "x", 0, 1, { Slot = 3 })) == "Daily")
check("an unknown kind -> the default tab", Book.TabOf(row("x", "Mystery", "x")) == Config.QuestTabs.Default)
check("five tabs in the user's order", table.concat(Config.QuestTabs.Order, ",") == "Main,Side,Daily,Event,Faction")

-- 2) In progress per tab
local s = Book.Sections("Main", ctx())
check("Main: the main quest in progress", #s.InProgress == 1 and s.InProgress[1].Entry == MAIN, texts(s.InProgress))
s = Book.Sections("Daily", ctx())
check("Daily: both daily slots, 3/5 shown", #s.InProgress == 2 and s.InProgress[1].Nums == "3/5", texts(s.InProgress))
check("Daily: [New] on an unfinished slot, [Claim] on a finished one", s.InProgress[1].CanReroll and not s.InProgress[1].CanClaim
	and s.InProgress[2].CanClaim and not s.InProgress[2].CanReroll)
s = Book.Sections("Side", ctx())
check("Side: the side story and the board job (not the Halo or goose stories)", texts(s.InProgress) == "Find the lost jelly | Board job",
	texts(s.InProgress))
check("Faction: the Halo story", texts(Book.Sections("Faction", ctx()).InProgress) == "Find Bright's lantern")
-- 3) info lines
GATTR.GooseActive, GATTR.PumpkinKingActive, GATTR.KaijuPhase, GATTR.WarRoundEndsAt = true, true, "Siren", NOW + 125
s = Book.Sections("Event", ctx())
check("Event: the goose story + the live events (goose, Pumpkin King, kaiju, crown war 2:05)",
	texts(s.InProgress) == "Chase the goose | The Golden Goose is here! | The Pumpkin King is here! | A Kaiju is loose! | Crown War: next crown in 2:05",
	texts(s.InProgress))
GATTR = {}
check("Event: no live event -> only the goose story", texts(Book.Sections("Event", ctx()).InProgress) == "Chase the goose")
-- A23-79 #4: the King Diary / candy jar links (only with the diary window, during the season or once I have a page)
ATTR.DiaryPages = 2
s = Book.Sections("Event", ctx({ HasDiary = true }))
check("Event: the diary (2/9) and the jar link to their window",
	texts(s.InProgress) == "Chase the goose | King Diary · 2/9 pages | Candy Jar · trade candy for a title"
	and s.InProgress[2].Kind == "Link" and s.InProgress[2].Window == "Diary" and s.InProgress[2].Arg.Tab == "Diary"
	and s.InProgress[3].Arg.Tab == "Jar", texts(s.InProgress))
check("no diary window: no links", texts(Book.Sections("Event", ctx()).InProgress) == "Chase the goose")
check("the links sit on the Event tab only", texts(Book.Sections("Side", ctx({ HasDiary = true })).InProgress) == "Find the lost jelly | Board job")
ATTR.DiaryPages = 0
check("after the season with no page: no links",
	texts(Book.Sections("Event", ctx({ HasDiary = true, Now = Config.Halloween.EndsAt + 1 })).InProgress) == "Chase the goose")
ATTR.DiaryPages = 3
check("after the season with pages: the links stay (the jar stays open)",
	#Book.Sections("Event", ctx({ HasDiary = true, Now = Config.Halloween.EndsAt + 1 })).InProgress == 3)
ATTR.DiaryPages = nil
ATTR.WantedStars = 3
check("Faction: my wanted stars", texts(Book.Sections("Faction", ctx()).InProgress) == "Find Bright's lantern | Wanted stars: 3")
ATTR.WantedStars = 0
-- 4) Done without a book: the main chain before my main quest, the first mission, today's dailies, this session
s = Book.Sections("Main", ctx())
-- 10/15: the main chain is Config's own list (M1_2 is gone) - its quests before M1_3, in order
local before = {}
for _, id in Config.StoryQuests.Main do
	if id == "M1_3" then break end
	table.insert(before, Config.StoryQuests.Defs[id].Title)
end
check("Main done: the first mission and the main chain before M1_3", texts(s.Done) == "First mission | "
	.. table.concat(before, " | "), texts(s.Done))
ATTR.TutorialStep = 1
s = Book.Sections("Main", ctx({ Entries = { row("tutorial", "Tutorial", "Defeat 5 slimes", 2, 5, { Pinned = true }) } }))
check("Main done: nothing while the first mission runs", #s.Done == 0, texts(s.Done))
ATTR.TutorialStep = 99
check("Daily done: today's count", texts(Book.Sections("Daily", ctx()).Done) == "Daily quests: 1/3")
s = Book.Sections("Side", ctx({ DoneSession = { { Id = "story:S4", Text = "x", Kind = "Sub" }, { Id = "Kill", Text = "Slimes 5/5", Kind = "Daily" } } }))
check("Side done: a story finished this session, by its title (not the daily)", texts(s.Done) == Config.StoryQuests.Defs.S4.Title,
	texts(s.Done))
check("Daily done: the daily finished this session", string.find(texts(Book.Sections("Daily",
	ctx({ DoneSession = { { Id = "Kill", Text = "Slimes 5/5", Kind = "Daily" } } })).Done), "Slimes 5/5", 1, true) ~= nil)
check("Available without a book: empty", #Book.Sections("Side", ctx()).Available == 0)
-- 5) the server's book (게임성 개발 3's contract: Available = subs waiting for a level (Text "Title · Opens at Lv N") or
-- ready (no Text), Done = "story:<id>", mains newest first then subs newest first)
local D = Config.StoryQuests.Defs
local BOOK = { Available = { { Id = "story:S6", Kind = "Sub", Level = 8, Text = "Lost thing · Opens at Lv 8" }, { Id = "story:S4", Kind = "Sub" },
	{ Id = "story:H2", Kind = "Sub", Level = 12, Text = "Lantern · Opens at Lv 12" }, { Id = "story:M1_4", Kind = "Main" } },
	Done = { "story:M1_4", "story:S0", "story:S2" } } -- 10/15: a main the guessed chain would never list (M1_1 is)
local SESSION = { { Id = "story:S3", Kind = "Sub", Text = "x" }, { Id = "Kill", Text = "Slimes 5/5", Kind = "Daily" } }
s = Book.Sections("Side", ctx({ Book = BOOK, DoneSession = SESSION }))
check("book: Side available = the server's 'Opens at Lv' words, else the story title", texts(s.Available) == "Lost thing · Opens at Lv 8 | "
	.. D.S4.Title, texts(s.Available))
check("book: Side done = the book's stories only (a story finished this session is in the book, no guesses)",
	texts(s.Done) == D.S0.Title, texts(s.Done))
check("book: Faction available = the Halo story", texts(Book.Sections("Faction", ctx({ Book = BOOK })).Available) == "Lantern · Opens at Lv 12")
check("book: Event done = the goose story", texts(Book.Sections("Event", ctx({ Book = BOOK })).Done) == D.S2.Title)
s = Book.Sections("Main", ctx({ Book = BOOK }))
check("book: the Main tab has no Available (the chain has no level gate)", #s.Available == 0, texts(s.Available))
check("book: Main done = the book's mains, then the first mission (no guessed chain)", texts(s.Done) == D.M1_4.Title .. " | First mission",
	texts(s.Done))
s = Book.Sections("Daily", ctx({ Book = BOOK, DoneSession = SESSION }))
check("book: Daily done = today's count + the dailies finished this session", texts(s.Done) == "Daily quests: 1/3 | Slimes 5/5", texts(s.Done))

-- 6) the window
local REGISTERED, OPENED, CLOSED, CURRENT = {}, {}, 0, nil
local PANELS = {
	Register = function(id, opts) REGISTERED[id] = opts return true end,
	Open = function(id, arg) table.insert(OPENED, { id, arg }) CURRENT = id end,
	Close = function() CLOSED += 1 CURRENT = nil end,
	CurrentId = function() return CURRENT end,
}
local CALLS = {}
local HUDD = { QuestsChanged = signal() }
for _, n in { "QuestClaim", "QuestReroll", "QuestGo" } do
	HUDD[n] = function(e) table.insert(CALLS, { n, e }) return true end
end
HUDD.QuestEntries = function() return ENTRIES end
HUDD.QuestBook = function() return nil end
HUDD.QuestDoneSession = function() return {} end
HUDD.QuestCanClaim = claimRule
HUDD.QuestCanReroll = rerollRule
Book.Init({ Panels = PANELS, HUD = HUDD })
Book.Start()
check("Init registers the 'Journal' window (the Q key opens it)", REGISTERED.Journal ~= nil and Book.IsReady() == true
	and REGISTERED.Journal.Title == "Quests" and REGISTERED.Journal.FixedBody == true)
local KITCLOSED, ORDER = 0, 0
local KIT = {
	Font = "Font.Gotham", Theme = { Text = "text", SubText = "sub", Gold = "gold", Good = "good" },
	Palette = { Button = "button", DarkText = "dark" },
	NextOrder = function() ORDER += 1 return ORDER end,
	Paint = function(b, bg, fg) b.Bg, b.Fg = bg, fg end,
	Attr = function(n) return ATTR[n] end, GameAttr = function(n) return GATTR[n] end,
	Close = function() KITCLOSED += 1 end,
	Button = function(parent, text, color, size, onClick)
		local b = inst("TextButton")
		b.Name = "Button"
		b.Text = text
		b.OnClick = onClick
		b.Parent = parent
		return b
	end,
}
local PARENT = inst("Frame")
REGISTERED.Journal.Build(PARENT, KIT, nil)
local bar = PARENT:FindFirstChild("Tabs")
local body = PARENT:FindFirstChild("Body")
local tabButtons = {}
for _, c in bar and bar.Children or {} do if c.Name == "Button" then table.insert(tabButtons, c) end end
check("the window has five tab buttons and a body", #tabButtons == 5 and body ~= nil, #tabButtons)
check("it opens on my 'now do' quest's tab (Main), painted gold, with counts", tabButtons[1].Bg == "gold" and tabButtons[1].Text == "Main 1"
	and tabButtons[3].Text == "Daily 2", tabButtons[1].Text .. " / " .. tostring(tabButtons[3].Text))
local function bodyRows()
	local out = {}
	for _, c in body.Children do if c.Name == "Quest" or c.Name == "Info" or c.Name == "Done" or c.Name == "Available" then table.insert(out, c) end end
	return out
end
check("Main body: the main quest row + the done rows (the first mission + the main chain before M1_3)", #bodyRows() == 2 + #before, #bodyRows())
Book.ShowTab("Daily")
local rows = bodyRows()
check("Daily tab: two quest rows + today's count", #rows == 3 and rows[1].Name == "Quest", #rows)
local newBtn, claimBtn = nil, nil
for _, d in descendants(body) do
	if d.Name == "Button" and d.Text == Config.ClientText.QuestBook.Reroll then newBtn = d end
	if d.Name == "Button" and d.Text == "Claim" then claimBtn = d end
end
check("Daily rows carry [New] and [Claim]", newBtn ~= nil and claimBtn ~= nil)
if newBtn then newBtn.OnClick() end
if claimBtn then claimBtn.OnClick() end
check("[New] asks HUD.QuestReroll, [Claim] HUD.QuestClaim for that quest", CALLS[1] and CALLS[1][1] == "QuestReroll" and CALLS[1][2] == KILL
	and CALLS[2] and CALLS[2][1] == "QuestClaim" and CALLS[2][2] == GOLD)
rows[1].Activated:Fire()
check("a press on a row guides there (HUD.QuestGo) and closes the window", CALLS[3] and CALLS[3][1] == "QuestGo" and CALLS[3][2] == KILL
	and KITCLOSED == 1)
ENTRIES = { MAIN }
HUDD.QuestsChanged:Fire()
check("the quest list changes -> the open window redraws (Daily: only today's count left)", #bodyRows() == 1, #bodyRows())
Book.ShowTab("Nope")
check("an unknown tab id changes nothing", #bodyRows() == 1)
REGISTERED.Journal.Cleanup()
ENTRIES = { MAIN, KILL }
HUDD.QuestsChanged:Fire()
check("a closed window does not redraw", #bodyRows() == 1)
-- A23-104 / 검수 10/10 (a Lv1 photo showed all five tabs): the tabs follow what there is
local ALL = { MAIN, SIDE, HALO, GOOSE, KILL, GOLD, JOB }
check("VisibleTabs: every tab has rows -> all five", table.concat(Book.VisibleTabs(ctx({ Entries = ALL })), ",") == "Main,Side,Daily,Event,Faction",
	table.concat(Book.VisibleTabs(ctx({ Entries = ALL })), ","))
check("VisibleTabs: DailyLocked hides Daily", table.concat(Book.VisibleTabs(ctx({ Entries = ALL, DailyLocked = true })), ",") == "Main,Side,Event,Faction")
check("VisibleTabs: a first-chapter list (the main quest only, dailies locked) -> Main only",
	table.concat(Book.VisibleTabs(ctx({ Entries = { MAIN }, DailyLocked = true })), ",") == "Main",
	table.concat(Book.VisibleTabs(ctx({ Entries = { MAIN }, DailyLocked = true })), ","))
local keepStep = ATTR.TutorialStep
ATTR.TutorialStep = 1 -- the first mission runs: nothing done yet either
check("VisibleTabs: Main shows even with nothing in it", table.concat(Book.VisibleTabs(ctx({ Entries = {}, DailyLocked = true })), ",") == "Main",
	table.concat(Book.VisibleTabs(ctx({ Entries = {}, DailyLocked = true })), ","))
ATTR.TutorialStep = keepStep
do
	local function tabTexts(P)
		local out = {}
		for _, c in P:FindFirstChild("Tabs").Children do if c.Name == "Button" then table.insert(out, (string.gsub(c.Text, " %d+$", ""))) end end
		return table.concat(out, ",")
	end
	ENTRIES = { MAIN }
	HUDD.DailyLocked = function() return true end
	local PV = inst("Frame")
	REGISTERED.Journal.Build(PV, KIT, { Tab = "Faction" })
	check("the window on the first chapter: only the Main tab (an asked empty tab falls back to Main)", tabTexts(PV) == "Main", tabTexts(PV))
	ENTRIES = { MAIN, SIDE }
	HUDD.QuestsChanged:Fire()
	check("a side quest comes: its tab appears", tabTexts(PV) == "Main,Side", tabTexts(PV))
	HUDD.DailyLocked = function() return false end
	ENTRIES = { MAIN, SIDE, KILL }
	HUDD.QuestsChanged:Fire()
	check("the daily jobs open: the Daily tab appears", tabTexts(PV) == "Main,Side,Daily", tabTexts(PV))
	REGISTERED.Journal.Cleanup()
	HUDD.DailyLocked = nil
	ENTRIES = { MAIN, KILL }
end
-- Toggle (Q / the HUD's ▼ / a phone tap)
Book.Toggle()
check("Toggle opens the window", OPENED[#OPENED] and OPENED[#OPENED][1] == "Journal")
Book.Toggle(true)
check("Toggle(true) while open keeps it open", #OPENED == 1)
Book.Toggle()
check("Toggle closes it again", CLOSED == 1 and CURRENT == nil)
Book.Toggle(false)
check("Toggle(false) while closed does nothing", CLOSED == 1)
-- a tab asked for
local P2 = inst("Frame")
ORDER = 0
ENTRIES = { MAIN, SIDE, HALO, GOOSE, KILL, GOLD, JOB } -- every tab has rows (empty tabs hide: A23-104 / 검수 10/10)
REGISTERED.Journal.Build(P2, KIT, { Tab = "Faction" })
local b2 = {}
for _, c in P2:FindFirstChild("Tabs").Children do if c.Name == "Button" then table.insert(b2, c) end end
check("Build({ Tab = 'Faction' }) opens that tab", b2[5].Bg == "gold", b2[5].Bg)
-- A23-79 #4: the Event tab's diary links open the diary window (kit.Open: a back button to the quests); a link is no
-- quest, so the tab shows no count for it
local SUBS = {}
KIT.Open = function(id, arg) table.insert(SUBS, { id, arg }) end
ATTR.DiaryPages = 1
Book.Init({ Panels = PANELS, HUD = HUDD, KingDiary = { IsReady = function() return true end } })
local P3 = inst("Frame")
REGISTERED.Journal.Build(P3, KIT, { Tab = "Event" })
local links, b3 = {}, {}
for _, c in P3:FindFirstChild("Body").Children do if c.Name == "Link" then table.insert(links, c) end end
for _, c in P3:FindFirstChild("Tabs").Children do if c.Name == "Button" then table.insert(b3, c) end end
check("Event tab: the diary and jar rows; no count on the tab for them (the goose story's 1 only)", #links == 2 and b3[4] and b3[4].Text == "Event 1",
	#links .. " " .. tostring(b3[4] and b3[4].Text))
if links[2] then links[2].Activated:Fire() end
check("a link opens the diary window on its tab", SUBS[1] and SUBS[1][1] == "Diary" and SUBS[1][2].Tab == "Jar")
ATTR.DiaryPages = nil

-- 검수 10/09: the Studio-only preview hook (이미지 개발's photos of every tab)
check("ParsePreview: a tab, full by default", select(2, Book.ParsePreview("Daily")) == "full" and Book.ParsePreview("Daily") == "Daily")
check("ParsePreview: a tab and a mode", select(2, Book.ParsePreview(" Side , long ")) == "long" and select(2, Book.ParsePreview("Main,EMPTY")) == "empty")
check("ParsePreview: '' / nil / an unknown tab / mode -> off", Book.ParsePreview("") == nil and Book.ParsePreview(nil) == nil
	and Book.ParsePreview("Shop") == nil and Book.ParsePreview("Main,huge") == nil and Book.ParsePreview(5) == nil)
local full = Book.PreviewContext("full", NOW)
for _, tab in Config.QuestTabs.Order do
	local sec = Book.Sections(tab, full)
	local quests = 0
	for _, r in sec.InProgress do if r.Kind == "Quest" then quests += 1 end end
	check("preview full: every tab has a quest row and something done", quests >= 1 and #sec.Done >= 1, tab .. " " .. quests .. " " .. #sec.Done)
	if tab ~= "Main" then check("preview full: Available filled where the tab has it", #sec.Available >= 1 or tab == "Daily" or tab == "Event", tab) end
end
local daily = Book.Sections("Daily", full).InProgress
local cl, rr = 0, 0
for _, r in daily do
	if r.CanClaim then cl += 1 end
	if r.CanReroll then rr += 1 end
end
check("preview full: the Daily tab shows a [Claim] and a [New]", cl == 1 and rr == 1, cl .. " " .. rr)
check("preview full: Event has the goose and the crown war lines", string.find(texts(Book.Sections("Event", full).InProgress), "Golden Goose is here", 1, true) ~= nil
	and string.find(texts(Book.Sections("Event", full).InProgress), "Crown War: next crown in 2:05", 1, true) ~= nil)
check("preview full: Faction shows the wanted stars", string.find(texts(Book.Sections("Faction", full).InProgress), "Wanted stars: 2", 1, true) ~= nil)
local emp = Book.PreviewContext("empty", NOW)
for _, tab in Config.QuestTabs.Order do
	local sec = Book.Sections(tab, emp)
	check("preview empty: every section empty (the empty words show)", #sec.InProgress == 0 and #sec.Available == 0 and #sec.Done == 0, tab)
end
local long = Book.Sections("Main", Book.PreviewContext("long", NOW)).InProgress[1]
check("preview long: the words get the long tail", long ~= nil and #long.Text > 60 and string.find(long.Text, "Slime Mayor", 1, true) ~= nil)
check("the sample words are English (no Hangul)", not string.find(texts(Book.Sections("Side", full).Available) .. texts(Book.Sections("Main", full).Done), "[\234-\237]"))
check("the preview leaves the samples alone", Book.PreviewContext("long", NOW).Entries[1].Text ~= Book.PreviewContext("long", NOW).Entries[1].Text .. "x"
	and not string.find(Book.PreviewContext("full", NOW).Entries[1].Text, "fountain", 1, true))
-- outside Studio the attribute does nothing (the Event window above is closed first, like Panels does)
REGISTERED.Journal.Cleanup()
OPENED, CLOSED, CURRENT = {}, 0, nil
Book.Init({ Panels = PANELS, HUD = HUDD })
Book.Start()
LP:SetAttribute("QuestBookPreview", "Daily")
check("outside Studio: QuestBookPreview is never read", #OPENED == 0)
-- in Studio: open on the tab with the samples, buttons do nothing, '' closes
STUDIO = true
LPSIG = {}
Book.Init({ Panels = PANELS, HUD = HUDD })
Book.Start()
LP:SetAttribute("QuestBookPreview", "Daily")
check("Studio: QuestBookPreview = 'Daily' opens the window", #OPENED == 1 and OPENED[1][1] == "Journal")
local P5 = inst("Frame")
ORDER = 0
REGISTERED.Journal.Build(P5, KIT, nil)
local b5, q5 = {}, {}
for _, c in P5:FindFirstChild("Tabs").Children do if c.Name == "Button" then table.insert(b5, c) end end
for _, c in P5:FindFirstChild("Body").Children do if c.Name == "Quest" then table.insert(q5, c) end end
check("Studio: on the Daily tab with the two sample dailies", b5[3] and b5[3].Bg == "gold" and #q5 == 2, #q5)
local calls0 = #CALLS
local claimBtn = nil
for _, d in descendants(P5) do if d.Name == "Button" and d.Text == "Claim" then claimBtn = d end end
if claimBtn then claimBtn.OnClick() end
if q5[1] then q5[1].Activated:Fire() end
check("Studio: [Claim] and a row press do nothing on samples", claimBtn ~= nil and #CALLS == calls0)
LP:SetAttribute("QuestBookPreview", "Faction,empty")
local qn = 0
for _, c in P5:FindFirstChild("Body").Children do if c.Name == "Quest" then qn += 1 end end
check("Studio: switching to 'Faction,empty' redraws the open window empty", qn == 0 and b5[5].Bg == "gold")
local closed0 = CLOSED
LP:SetAttribute("QuestBookPreview", "")
check("Studio: '' closes the window and the real rows come back", CLOSED == closed0 + 1)
REGISTERED.Journal.Cleanup()
STUDIO = false

-- 검수 10/09 (user OK): each tab shows its QuestTabIcon<tab> left of the word; no art = the word alone
do
	REGISTERED.Journal.Cleanup()
	local ART = { QuestTabIconMain = "rbxassetid://1", QuestTabIconDaily = "rbxassetid://3" }
	Book.Init({ Panels = PANELS, HUD = HUDD, UIKit = { ArtId = function(k) return ART[k] end } })
	local P6 = inst("Frame")
	REGISTERED.Journal.Build(P6, KIT, { Tab = "Main" })
	local tabsById = {}
	for _, c in P6:FindFirstChild("Tabs").Children do if c.Name == "Button" then table.insert(tabsById, c) end end
	local mainIcon = tabsById[1] and tabsById[1]:FindFirstChild("TabIcon")
	check("the Main tab shows its icon", mainIcon ~= nil and mainIcon.Image == "rbxassetid://1", tostring(mainIcon))
	check("the Daily tab shows its icon", tabsById[3] and tabsById[3]:FindFirstChild("TabIcon") ~= nil)
	check("a tab without art: no icon, no padding", tabsById[2] and tabsById[2]:FindFirstChild("TabIcon") == nil
		and tabsById[2]:FindFirstChild("UIPadding") == nil)
	check("the word moves right of the icon (padding)", tabsById[1] and tabsById[1]:FindFirstChild("UIPadding") ~= nil)
	REGISTERED.Journal.Cleanup()
end

-- 최종 검수 10/15 (Korean client: 'Go to Otto's Forge in the Crossroads' stayed English in the list): a row's words go
-- through UIKit.TrWord before drawing (whole sentence first, then the pieces of a "words · tail" row)
do
	local KO = { ["Talk to the fountain"] = "분수와 이야기해요", ["Hunt slimes"] = "슬라임 사냥", ["at the meadow"] = "초원에서" }
	local function fakeTr(x) return KO[x] or x end
	check("row words: a whole sentence is translated", Book.RowWords("Talk to the fountain", fakeTr) == "분수와 이야기해요")
	check("row words: a 'words · tail' row piece by piece", Book.RowWords("Hunt slimes · at the meadow", fakeTr) == "슬라임 사냥 · 초원에서",
		tostring(Book.RowWords("Hunt slimes · at the meadow", fakeTr)))
	check("row words: unknown words stay English", Book.RowWords("Collect 60 gold", fakeTr) == "Collect 60 gold")
	check("row words: no translator = unchanged", Book.RowWords("Talk to the fountain", nil) == "Talk to the fountain")
	check("row words: a throwing translator = unchanged", Book.RowWords("Talk to the fountain", function() error("x") end) == "Talk to the fountain")
	REGISTERED.Journal.Cleanup()
	ENTRIES = { MAIN }
	Book.Init({ Panels = PANELS, HUD = HUDD, UIKit = { ArtId = function() return nil end, TrWord = fakeTr } })
	local P7 = inst("Frame")
	REGISTERED.Journal.Build(P7, KIT, { Tab = "Main" })
	local drawn = nil
	local function walk(o)
		for _, c in o.Children do
			if c.Name == "Quest" then
				for _, l in c.Children do if l.Text and l.Text ~= "" and drawn == nil then drawn = l.Text end end
			end
			walk(c)
		end
	end
	walk(P7)
	check("the drawn quest row shows the translated words", drawn == "분수와 이야기해요", tostring(drawn))
	REGISTERED.Journal.Cleanup()
	Book.Init({ Panels = PANELS, HUD = HUDD })
end

print(("QUEST_BOOK_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("QUEST_BOOK_OFFLINE_OK") end
