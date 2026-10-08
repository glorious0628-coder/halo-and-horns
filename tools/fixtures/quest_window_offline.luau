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
local env = setmetatable({
	game = { GetService = function(_, n)
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
	texts(s.InProgress) == "Chase the goose | The Golden Goose is here! | The Pumpkin King is here! | A kaiju is loose! | Crown War: next crown in 2:05",
	texts(s.InProgress))
GATTR = {}
check("Event: no live event -> only the goose story", texts(Book.Sections("Event", ctx()).InProgress) == "Chase the goose")
ATTR.WantedStars = 3
check("Faction: my wanted stars", texts(Book.Sections("Faction", ctx()).InProgress) == "Find Bright's lantern | Wanted stars: 3")
ATTR.WantedStars = 0
-- 4) Done without a book: the main chain before my main quest, the first mission, today's dailies, this session
s = Book.Sections("Main", ctx())
check("Main done: the first mission and the main chain before M1_3", texts(s.Done) == "First mission | "
	.. Config.StoryQuests.Defs.M1_1.Title .. " | " .. Config.StoryQuests.Defs.M1_2.Title, texts(s.Done))
ATTR.TutorialStep = 1
s = Book.Sections("Main", ctx({ Entries = { row("tutorial", "Tutorial", "Defeat 5 slimes", 2, 5, { Pinned = true }) } }))
check("Main done: nothing while the first mission runs", #s.Done == 0, texts(s.Done))
ATTR.TutorialStep = 99
check("Daily done: today's count", texts(Book.Sections("Daily", ctx()).Done) == "Daily quests today: 1/3")
s = Book.Sections("Side", ctx({ DoneSession = { { Id = "story:S4", Text = "x", Kind = "Sub" }, { Id = "Kill", Text = "Slimes 5/5", Kind = "Daily" } } }))
check("Side done: a story finished this session, by its title (not the daily)", texts(s.Done) == Config.StoryQuests.Defs.S4.Title,
	texts(s.Done))
check("Daily done: the daily finished this session", string.find(texts(Book.Sections("Daily",
	ctx({ DoneSession = { { Id = "Kill", Text = "Slimes 5/5", Kind = "Daily" } } })).Done), "Slimes 5/5", 1, true) ~= nil)
check("Available without a book: empty", #Book.Sections("Side", ctx()).Available == 0)
-- 5) the server's book
local BOOK = { Available = { { Id = "story:S6", Kind = "Sub" }, { Id = "job:2", Text = "Carry crates", Kind = "Job" } },
	Done = { "story:S0", "story:M1_1", { Id = "Kill", Text = "Slimes", Kind = "Daily" } } }
s = Book.Sections("Side", ctx({ Book = BOOK }))
check("book: Side available = the story title and the job", texts(s.Available) == Config.StoryQuests.Defs.S6.Title .. " | Carry crates",
	texts(s.Available))
check("book: Side done = the S0 title only (the book replaces the guesses)", texts(s.Done) == Config.StoryQuests.Defs.S0.Title, texts(s.Done))
check("book: Main done = M1_1 only", texts(Book.Sections("Main", ctx({ Book = BOOK })).Done) == Config.StoryQuests.Defs.M1_1.Title)
check("book: Daily done = the daily row", texts(Book.Sections("Daily", ctx({ Book = BOOK })).Done) == "Slimes")

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
check("Main body: the main quest row + 3 done rows", #bodyRows() == 4, #bodyRows())
Book.ShowTab("Daily")
local rows = bodyRows()
check("Daily tab: two quest rows + today's count", #rows == 3 and rows[1].Name == "Quest", #rows)
local newBtn, claimBtn = nil, nil
for _, d in descendants(body) do
	if d.Name == "Button" and d.Text == "New" then newBtn = d end
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
REGISTERED.Journal.Build(P2, KIT, { Tab = "Faction" })
local b2 = {}
for _, c in P2:FindFirstChild("Tabs").Children do if c.Name == "Button" then table.insert(b2, c) end end
check("Build({ Tab = 'Faction' }) opens that tab", b2[5].Bg == "gold", b2[5].Bg)

print(("QUEST_BOOK_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("QUEST_BOOK_OFFLINE_OK") end
