-- Offline checks for KingDiary.luau (SPEC A23-79 #4: the King Diary book + the candy jar; server = DiaryService) with
-- the real Config.luau (Config.Halloween.Banter / Bosses / EndsAt, Config.CandyJar, Config.TitleDefs, Config.Diary,
-- Config.MonsterTypes). The runner (tools/test_king_diary.py) prepends CONFIG_SOURCE and DIARY_SOURCE. Roblox is
-- replaced by small doubles: Instance-like tables, a Panels double (Register / Open / ItemCount), a window kit double
-- (Button / Paint / SetEnabled / NextOrder), PauseCard.Show and UIKit.RewardPopup recorders, the Remotes folder
-- (CandyTrade recording FireServer), the Fx / Inventory remotes, the player's attributes, os.clock / os.time numbers.
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
	function s:Fire(...) for _, f in table.clone(self.Fns) do f(...) end end
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
	FindFirstChild = function(self, n, deep)
		for _, c in self.Children do
			if c.Name == n then return c end
			if deep then local f = c:FindFirstChild(n, true) if f then return f end end
		end
		return nil
	end,
	GetChildren = function(self) return table.clone(self.Children) end,
	IsA = function(self, cl) return self.ClassName == cl end,
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
local function texts(root, out)
	out = out or {}
	for _, c in root.Children do
		if c.ClassName == "TextLabel" then table.insert(out, c.Text) end
		texts(c, out)
	end
	return out
end

local CLOCK, TIME = 100, 0
local cfgEnv = setmetatable({
	game = { GetService = function() return setmetatable({}, { __index = function() return function() return nil end end }) end },
	Vector3 = ctor("Vector3"), Vector2 = ctor("Vector2"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
	Color3 = { new = function(...) return { ... } end, fromRGB = function(...) return { ... } end, fromHSV = function() return {} end },
	BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), NumberRange = ctor("NumberRange"),
	NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), Font = ctor("Font"),
	TweenInfo = { new = function(...) return { ... } end }, Enum = enum, Instance = { new = function() return {} end },
	typeof = function(v) return type(v) end, warn = function() end,
}, { __index = getfenv() })
local cfn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfn, cfgEnv)
local Config = cfn()
local HW = Config.Halloween
local DAY1 = HW.Banter.DayOneStart
TIME = DAY1 + 4 * 86400 + 600 -- Nov 4 (page 5's day)

-- the player, the remotes, the other modules
local ATTR = { DiaryPages = 2, TitlesOwned = "PumpkinPal", Faction = "Halo" }
local LP = { UserId = 7 }
function LP:GetAttribute(k) return ATTR[k] end
local TRADES = {}
local REMOTE = {}
function REMOTE:IsA(c) return c == "RemoteEvent" end
function REMOTE:FireServer(...) table.insert(TRADES, table.pack(...)) end
local REMOTES = {}
function REMOTES:FindFirstChild(n) if n == "CandyTrade" then return REMOTE end return nil end
local FX, INV = signal(), signal()
local CARDS, POPUPS, REGISTERED, OPENED = {}, {}, {}, {}
local ITEMCOUNT = { Candy = 33 }
local C = {
	PauseCard = { Show = function(kind, data) table.insert(CARDS, { kind, data }) return true end },
	UIKit = { RewardPopup = function(opts) table.insert(POPUPS, opts) return { Close = function() end } end },
	Panels = {
		Register = function(id, opts) REGISTERED[id] = opts return true end,
		Open = function(id, arg) table.insert(OPENED, { id, arg }) end,
		ItemCount = function(id) return ITEMCOUNT[id] or 0 end,
	},
}

local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = LP } end
		if n == "ReplicatedStorage" then
			return {
				WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end,
				FindFirstChild = function(_, n2) if n2 == "Remotes" then return REMOTES end return nil end,
			}
		end
		return {}
	end },
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromScale = function(x, y) return { x, 0, y, 0 } end,
		fromOffset = function(x, y) return { 0, x, 0, y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Enum = enum,
	Instance = { new = inst },
	os = { clock = function() return CLOCK end, time = function() return TIME end, date = os.date },
	task = { spawn = function(f, ...) f(...) end, defer = function() end, delay = function() end },
	require = function(m)
		if m.__module == "Config" then return Config end
		if m.__module == "Net" then
			return { Get = function(n) if n == "Fx" then return { OnClientEvent = FX } end
				if n == "Inventory" then return { OnClientEvent = INV } end return {} end }
		end
		return { Signal = { new = signal }, Warn = function() end }
	end,
}, { __index = getfenv() })
local function load()
	local fn = assert(loadstring(DIARY_SOURCE, "=KingDiary"))
	setfenv(fn, env)
	local m = fn()
	m.Init(C)
	m.Start()
	return m
end
local Diary = load()

-- 1) the day's page
check("before 10/31: page 1 is today's", Diary.TodayPage(DAY1 - 3600) == 1)
check("10/31: page 1", Diary.TodayPage(DAY1) == 1 and Diary.TodayPage(DAY1 + 86399) == 1)
check("11/02: page 3", Diary.TodayPage(DAY1 + 2 * 86400 + 5) == 3)
check("long after: never past page 9", Diary.TodayPage(DAY1 + 40 * 86400) == 9)

-- 2) the kings' lines
check("a king's line: its name and its words", Diary.KingLine("PumpkinKing", "Hi!") == 'Pumpkin King: "Hi!"', Diary.KingLine("PumpkinKing", "Hi!"))
local nine = Diary.KingLine("GhostKing", HW.Banter.Days[9].GhostKing)
check("page 9's server number is left out", nine == 'Ghost King: "Truce! Fine, you\'re all invited!"', nine)

-- 3) the book
local rows = Diary.Pages({ Pages = 2, Now = TIME })
check("nine pages", #rows == 9, #rows)
check("page 1: its date and both kings' lines", rows[1].Head == "Page 1 · Oct 31" and rows[1].Open and #rows[1].Lines == 2
	and rows[1].Lines[1] == 'Pumpkin King: "' .. HW.Banter.Days[1].PumpkinKing .. '"'
	and rows[1].Lines[2] == 'Ghost King: "' .. HW.Banter.Days[1].GhostKing .. '"', rows[1].Head)
check("page 2 open, page 3 closed", rows[2].Open and not rows[3].Open and rows[3].Lines == nil)
check("a day already here: beat a king together", rows[3].Note == "Beat a king together to open this page!" and rows[5].Note == rows[3].Note,
	rows[3].Note)
check("a day still to come: when it opens", rows[6].Note == "Opens on Nov 5." and rows[9].Head == "Page 9 · Nov 8", rows[6].Note)
local allLines = {}
for _, r in Diary.Pages({ Pages = 9, Now = TIME }) do for _, l in r.Lines do table.insert(allLines, l) end end
check("every open page has no %d", #allLines == 18 and not table.concat(allLines, "|"):find("%%d"), #allLines)
rows = Diary.Pages({ Pages = 4, Now = HW.EndsAt + 10 })
check("after the season: the closed pages stay closed", rows[4].Open and rows[5].Note == "This page stayed closed." and rows[9].Note == rows[5].Note,
	rows[5].Note)

-- 4) the jar
local jar = Diary.JarRows({ Candy = 60, Titles = "PumpkinPal" })
check("two trades: names and candy from Config", #jar == 2 and jar[1].Name == "Pumpkin Pal" and jar[1].Candy == 50
	and jar[2].Name == "Candy Keeper" and jar[2].Candy == 200, #jar)
check("an owned title cannot be traded again", jar[1].Owned and not jar[1].CanTrade)
check("too little candy: no trade", not jar[2].Owned and not jar[2].CanTrade)
jar = Diary.JarRows({ Candy = 250, Titles = "Regular,CandyKeeperX" })
check("enough candy, not owned: both can trade", jar[1].CanTrade and jar[2].CanTrade and not jar[2].Owned)

-- 5) the Fx
FX:Fire("DiaryPage", { Page = 3, Today = 5, Late = true })
local card = CARDS[1]
check("a new page: a calm card 'Page 3 is open!' [Read] -> the book on page 3", card and card[1] == "Tip"
	and card[2].Title == "King Diary" and card[2].Text == "Page 3 is open!" and card[2].Go.Text == "Read"
	and card[2].Go.Window == "Diary" and card[2].Go.Arg.Page == 3, card and card[2].Text)
FX:Fire("DiaryPage", {})
check("no page number: no card", #CARDS == 1)
FX:Fire("DiaryDone", {})
local pop = POPUPS[1]
check("the whole book: the reward popup with the new title", pop and pop.Title == "King Diary" and pop.Lines[1] == "You read all 9 pages!"
	and pop.Lines[2] == "New title: Party Guest 2026" and (pop.Rewards == nil or #pop.Rewards == 0) and pop.Faction == "Halo",
	pop and pop.Lines and pop.Lines[2])

-- 6) trading
check("[Trade] asks the server with the jar id", Diary.Trade("PumpkinPal") == true and TRADES[1] and TRADES[1].n == 1 and TRADES[1][1] == "PumpkinPal")
check("a second press at once is dropped", Diary.Trade("CandyKeeper") == false and #TRADES == 1)
CLOCK += 1.3
check("... and sent after the gap", Diary.Trade("CandyKeeper") == true and #TRADES == 2)

-- 7) the window
check("Init registers 'Diary' (rebuilt on new pages / titles)", REGISTERED.Diary ~= nil and REGISTERED.Diary.Rebuild.DiaryPages
	and REGISTERED.Diary.Rebuild.TitlesOwned and Diary.IsReady())
local BUTTONS, ENABLED, OPENSUB = {}, {}, {}
local order = 0
local kit = {
	Font = "Font", Palette = { Button = "btn", DarkText = "dark" }, Theme = { Gold = "gold", Text = "text", SubText = "sub", Good = "good" },
	NextOrder = function() order += 1 return order end,
	Paint = function(b, color) b.Painted = color end,
	SetEnabled = function(b, on) ENABLED[b] = on end,
	Open = function(id, arg) table.insert(OPENSUB, { id, arg }) end,
	Button = function(parent, text, color, size, fn)
		local b = inst("TextButton")
		b.Text = text
		b.Parent = parent
		b.Activated:Connect(fn)
		table.insert(BUTTONS, b)
		return b
	end,
}
local root = inst("Frame")
REGISTERED.Diary.Build(root, kit, { Page = 2 })
local body = root:FindFirstChild("Body")
check("the book: nine page blocks", body and body:FindFirstChild("Page1") and body:FindFirstChild("Page9") ~= nil)
local all = table.concat(texts(body), "\n")
check("the count line, page 1's words, page 3's how-to", all:find("Pages: 2/9", 1, true) and all:find(HW.Banter.Days[1].PumpkinKing, 1, true)
	and all:find("Beat a king together", 1, true) and not all:find(HW.Banter.Days[3].PumpkinKing, 1, true), all:sub(1, 80))
local p2 = body:FindFirstChild("Page2")
check("the asked page is marked", p2 and p2.Children[2] and p2:FindFirstChild("TextLabel").TextColor3 == "gold")
-- the jar tab, its candy from Panels' cache until my own Inventory payload comes
root = inst("Frame")
BUTTONS = {}
REGISTERED.Diary.Build(root, kit, { Tab = "Jar" })
body = root:FindFirstChild("Body")
all = table.concat(texts(body), "\n")
check("the jar: my candy (Panels' cache), the note, both titles", all:find("Your candy: 33", 1, true) and all:find("Pumpkin Pal", 1, true)
	and all:find("Candy Keeper", 1, true) and all:find("Titles are just for fun", 1, true), all:sub(1, 80))
local tradeBtns = {}
for _, b in BUTTONS do if b.Text == "Trade" then table.insert(tradeBtns, b) end end
check("an owned title shows 'Owned', the other a [Trade] that is off (33 < 200)", #tradeBtns == 1 and ENABLED[tradeBtns[1]] == false
	and all:find("Owned", 1, true), #tradeBtns)
INV:Fire({ Items = { Candy = 240 } })
all = table.concat(texts(body), "\n")
local on = nil
for _, b in BUTTONS do if b.Text == "Trade" and b.Parent and b.Parent.Parent == body then on = b end end
check("my own Inventory payload redraws the jar: 240 candy, [Trade] on", all:find("Your candy: 240", 1, true) and on and ENABLED[on] == true,
	all:sub(1, 40))
CLOCK += 2
TRADES = {}
if on then on.Activated:Fire() end
check("pressing [Trade] sends that jar id", TRADES[1] and TRADES[1][1] == "CandyKeeper", TRADES[1] and TRADES[1][1])
ITEMCOUNT.Candy = 5
root = inst("Frame")
REGISTERED.Diary.Build(root, kit, { Tab = "Jar" })
all = table.concat(texts(root:FindFirstChild("Body")), "\n")
check("after my own payload the cache is not read again", all:find("Your candy: 240", 1, true) ~= nil, all:sub(1, 40))
-- a new module without its own payload yet
local Diary2 = load()
REGISTERED.Diary.Build(root, kit, { Tab = "Jar" })
check("Open asks Panels for the window", Diary2.Open({ Tab = "Jar" }) == true and OPENED[#OPENED][1] == "Diary" and OPENED[#OPENED][2].Tab == "Jar")
ATTR.DiaryPages = 9
root = inst("Frame")
REGISTERED.Diary.Build(root, kit, { Tab = "Diary" })
all = table.concat(texts(root:FindFirstChild("Body")), "\n")
check("the whole book: the head names the title", all:find("You read every page! Title: Party Guest 2026", 1, true) ~= nil, all:sub(1, 60))

print(("KING_DIARY_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("KING_DIARY_OFFLINE_OK") end
