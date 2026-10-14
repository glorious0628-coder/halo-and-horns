-- Offline checks for AttendanceUI.luau (plan 10/13 §1-A #5, SPEC A23-77; server = AttendanceService) with the real
-- Config.luau (Config.Attendance, HuntValue, Loot, Looks, TitleDefs) and the real Util.luau. The runner
-- (tools/test_attendance_ui.py) prepends CONFIG_SOURCE, UTIL_SOURCE and UI_SOURCE. Roblox is replaced by small doubles:
-- Instance-like tables, a Panels double (Register / Open), a window kit double (Text / Button / SetEnabled / Fire /
-- OnAttr), UIKit art doubles (ArtImage / ArtFrame / ArtId / LightText / InkText from Config.UIArt.Parts), PauseCard
-- (Busy / IsOpen / Waiting), TweenService recording its tweens, the player's attributes, os.clock / os.time numbers.
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
	return setmetatable({ ClassName = class, Name = class, Children = {}, Visible = true }, imt)
end
local function texts(root, out)
	out = out or {}
	for _, c in root.Children do
		if c.ClassName == "TextLabel" or c.ClassName == "TextButton" then table.insert(out, c.Text) end
		texts(c, out)
	end
	return out
end
local function find(root, name)
	return root:FindFirstChild(name, true)
end

local CLOCK, TIME = 100, 1760000000
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
local ufn = assert(loadstring(UTIL_SOURCE, "=Util"))
setfenv(ufn, setmetatable({ game = cfgEnv.game, warn = function() end, Random = { new = function() return {} end } },
	{ __index = getfenv() }))
local Util = ufn()
local A = Config.Attendance
local T = A.Text

-- the player, the other modules
local ATTR = { AttendSlot = 3, AttendReady = true, AttendDays = 2, Level = 1, ClassChosen = true, Faction = "Halo",
	TutorialStep = 99 }
local LP = { UserId = 7 }
function LP:GetAttribute(k) return ATTR[k] end
local REGISTERED, OPENED, TWEENS = {}, {}, {}
local BUSY = { Busy = false, Open = false, Waiting = false }
local function artId(name)
	local part = Config.UIArt and Config.UIArt.Parts and Config.UIArt.Parts[name]
	return type(part) == "table" and type(part.Id) == "string" and part.Id ~= "" and part.Id or nil
end
local function withProps(o, props)
	for k, v in props do if k ~= "Parent" then o[k] = v end end
	if props.Parent then o.Parent = props.Parent end
	return o
end
local C = {
	PauseCard = { Busy = function() return BUSY.Busy end, IsOpen = function() return BUSY.Open end,
		Waiting = function() return BUSY.Waiting end },
	UIKit = {
		ArtId = artId,
		ArtImage = function(name, props)
			local id = artId(name)
			if not id then return nil end
			local img = inst("ImageLabel")
			img.Image, img.ImageTransparency, img.Art = id, 0, name
			return withProps(img, props or {})
		end,
		ArtFrame = function(name, props)
			local f = inst(artId(name) and "ImageLabel" or "Frame")
			f.Art = name
			return withProps(f, props or {})
		end,
		LightText = function(props) local l = inst("TextLabel") l.Light = true return withProps(l, props) end,
		InkText = function(props) local l = inst("TextLabel") return withProps(l, props) end,
	},
	Panels = {
		Register = function(id, opts) REGISTERED[id] = opts return true end,
		Open = function(id, arg) table.insert(OPENED, { id, arg }) end,
	},
}

local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = LP } end
		if n == "ReplicatedStorage" then
			return { WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end }
		end
		if n == "TweenService" then
			return { Create = function(_, obj, info, goal)
				local tw = { Obj = obj, Goal = goal, Played = false }
				function tw:Play() self.Played = true end
				table.insert(TWEENS, tw)
				return tw
			end }
		end
		return {}
	end },
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromScale = function(x, y) return { x, 0, y, 0 } end,
		fromOffset = function(x, y) return { 0, x, 0, y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = cfgEnv.Color3,
	TweenInfo = cfgEnv.TweenInfo,
	Enum = enum,
	Instance = { new = inst },
	os = { clock = function() return CLOCK end, time = function() return TIME end, date = os.date },
	task = { spawn = function() end, defer = function() end, delay = function() end, wait = function() end },
	require = function(m)
		if m.__module == "Config" then return Config end
		if m.__module == "Util" then return Util end
		return {}
	end,
}, { __index = getfenv() })
local function load()
	local fn = assert(loadstring(UI_SOURCE, "=AttendanceUI"))
	setfenv(fn, env)
	local m = fn()
	m.Init(C)
	m.Start()
	return m
end
local UI = load()

-- 1) one slot's rewards at my level (the server's AttendanceService.pay)
local function minutes(level, m) local g, x = Config.HuntValue(level, m) return g, x end
local p = UI.Parts(A.Board[1], 1)
check("slot 1: 2 HP potions (the potion icon)", #p == 1 and p[1].Kind == "Item" and p[1].Id == "HP" and p[1].N == 2
	and p[1].Icon == "IconPotionHP", p[1] and p[1].Id)
local g3 = minutes(1, 3)
p = UI.Parts(A.Board[2], 1)
check("slot 2: 3 minutes of gold at Lv1 (Config.HuntValue)", #p == 1 and p[1].Kind == "Gold" and p[1].N == g3 and g3 > 0
	and p[1].Icon == "IconCoin", p[1] and p[1].N)
p = UI.Parts(A.Board[2], 1, { Gold2 = true })
check("... x2 with the 2x Gold pass (an earned source)", p[1].N == g3 * Config.PassBoost.Mult, p[1].N)
p = UI.Parts(A.Board[2], 1, { XP2 = true })
check("... the 2x XP pass leaves the gold alone", p[1].N == g3, p[1].N)
p = UI.Parts(A.Board[3], 1)
check("slot 3: one Enhance Scroll 70% (its own icon)", #p == 1 and p[1].Id == "Enh70" and p[1].N == 1
	and p[1].Icon == Config.Loot.Items.Enh70.Icon, p[1] and p[1].Id)
p = UI.Parts(A.Board[5], 1)
local jelly = math.floor(Config.Economy.KillsPerMinute * 4 * 0.30 + 0.5)
check("slot 5: 3 HP potions + 4 minutes of meadow material (Jelly, the server's formula)", #p == 2 and p[1].Id == "HP"
	and p[1].N == 3 and p[2].Id == "Jelly" and p[2].N == jelly and jelly == 14 and p[2].Icon == "IconJelly",
	p[2] and (p[2].Id .. " " .. p[2].N))
p = UI.Parts(A.Board[5], 30)
check("slot 5 at Lv30: the ruins' bones", p[2] and p[2].Id == "Bone" and p[2].N > 0, p[2] and p[2].Id)
local _, x5 = minutes(1, 5)
p = UI.Parts(A.Board[6], 1, { XP2 = true })
check("slot 6: 5 minutes of XP, x2 with the 2x XP pass", #p == 1 and p[1].Kind == "XP" and p[1].N == x5 * Config.PassBoost.Mult
	and p[1].Icon == "IconExp", p[1] and p[1].N)
local g10, x10 = minutes(12, 10)
p = UI.Parts(A.Board[7], 12)
check("slot 7 (Lv12): the scroll, 10 minutes of gold and XP", #p == 3 and p[1].Id == "Enh30" and p[2].Kind == "Gold"
	and p[2].N == g10 and p[3].Kind == "XP" and p[3].N == x10, #p)
check("a broken level counts as Lv1", UI.Parts(A.Board[2], -5)[1].N == g3 and UI.Parts(A.Board[2], 0 / 0)[1].N == g3)
-- A23-167 ②: a slot's art for PauseCard's "tomorrow's gift" card (my level from the attributes)
check("slot art: slot 1 = its potion, slot 2 = the coin", UI.SlotIcon(1) == "IconPotionHP" and UI.SlotIcon(2) == "IconCoin",
	tostring(UI.SlotIcon(1)) .. " " .. tostring(UI.SlotIcon(2)))
check("slot art: the weekly box slot = the box", A.Board[7].Box == true and UI.SlotIcon(7) == "IconWeeklyBox", UI.SlotIcon(7))
check("slot art: no such slot = nil", UI.SlotIcon(0) == nil and UI.SlotIcon(99) == nil and UI.SlotIcon("x") == nil)

-- 2) the line under the board: the server's words and order (gold, XP, items)
local line = UI.Line(UI.Parts(A.Board[7], 12))
local want = string.format(T.Gold, Util.FormatNumber(g10)) .. " · " .. string.format(T.XP, Util.FormatNumber(x10)) .. " · "
	.. string.format(T.Item, Config.Loot.Items.Enh30.Name)
check("slot 7's line = '+gold · +XP · +Enhance Scroll 30%'", line == want, line)
line = UI.Line(UI.Parts(A.Board[5], 1))
check("slot 5's line names the potions and the jelly with counts", line == "+HP Potion x3 · +Jelly x14", line)

-- 3) the board
local b = UI.Board({ Slot = 3, Ready = true, Days = 2, Level = 1, ClassChosen = true })
local st = {}
for _, r in b.Rows do st[r.Slot] = r.State end
check("slot 3 open: 1-2 stamped, 3 today, 4-7 later", #b.Rows == 7 and st[1] == "Got" and st[2] == "Got" and st[3] == "Today"
	and st[4] == "Later" and st[7] == "Later" and b.Pays == 3 and b.Ready and not b.WeekDone, table.concat(st, ","))
check("slot 7 is the box", b.Rows[7].Box and not b.Rows[6].Box)
b = UI.Board({ Slot = 3, Ready = false, Days = 2, ClassChosen = true })
check("taken today: slot 3 waits for tomorrow", b.Rows[3].State == "Next" and not b.Ready and b.Rows[2].State == "Got")
b = UI.Board({ Slot = 1, Ready = false, Days = 7, ClassChosen = true })
local all = true
for _, r in b.Rows do all = all and r.State == "Got" end
check("the weekly box taken today: the whole board stays stamped", b.WeekDone and all and b.Pays == 1)
b = UI.Board({ Slot = 1, Ready = true, Days = 7, ClassChosen = true })
check("the next day: a fresh board, slot 1 today", not b.WeekDone and b.Rows[1].State == "Today" and b.Rows[7].State == "Later")
b = UI.Board({ Slot = 1, Ready = false, Days = 0, ClassChosen = false })
check("no class yet: nothing stamped, slot 1 waits", not b.WeekDone and b.Rows[1].State == "Next" and b.Rows[2].State == "Later")
b = UI.Board({ Slot = 1, Ready = false, Days = 0, ClassChosen = true })
check("no day collected yet: never 'week done'", not b.WeekDone and b.Rows[1].State == "Next")
b = UI.Board({ Slot = 1, Ready = false, Days = 9, ClassChosen = false })
check("no class right now (a class change): not 'week done' either", not b.WeekDone and b.Rows[7].State == "Later")
b = UI.Board({ Slot = 99, Ready = true, Days = 3, ClassChosen = true })
check("a broken slot reads as slot 1", b.Pays == 1 and b.Rows[1].State == "Today")

-- 4) the next milestone
local goal = UI.Goal(0, "Halo")
check("0 days: 7 days for the Regular title", goal and goal.Days == 7 and goal.Text == "7 days: Regular title", goal and goal.Text)
goal = UI.Goal(7, "Halo")
check("7 days: 14 days = my side's sprout look", goal and goal.Days == 14 and goal.Text == "14 days: Sprout Halo", goal and goal.Text)
goal = UI.Goal(13, "Horns")
check("... the Horns' look for a Horn", goal and goal.Text == "14 days: Sprout Horns", goal and goal.Text)
-- final review 10/13 ②: never a reward that does not exist - the 14-day looks are not the artisans'. 최종 검수 10/14
-- (publish4: 27 days showed the 50-day ribbon): the 28-day name frame IS drawn now (NameTagPrefs) -> 28 is a goal while
-- its ribbon art is in; with no art it is skipped again
goal = UI.Goal(20, "Neutral")
check("past 14: the 28-day name frame with its ribbon", goal and goal.Days == 28 and goal.Text == "28 days: Name frame", goal and goal.Text)
goal = UI.Goal(27, "Halo")
check("27 days (the photo): 28 days = the name frame", goal and goal.Days == 28 and goal.Text == "28 days: Name frame", goal and goal.Text)
goal = UI.Goal(7, "Neutral")
check("an artisan at 7: no look of its own at 14 -> 28's frame", goal and goal.Days == 28, goal and goal.Text)
local keepId = Config.UIArt.Parts.RibbonDays28.Id
Config.UIArt.Parts.RibbonDays28.Id = ""
goal = UI.Goal(20, "Neutral")
check("no ribbon art: the frame is not promised -> 50 days' title", goal and goal.Days == 50
	and goal.Text == "50 days: Super Regular title", goal and goal.Text)
Config.UIArt.Parts.RibbonDays28.Id = keepId
goal = UI.Goal(28, "Halo")
check("50 days: the title + my look", goal and goal.Text == "50 days: Super Regular title + Star Halo", goal and goal.Text)
local zp, zc = UI.Sizes(true), UI.Sizes(false)
check("a phone's rows are shorter ([Claim] fits), the top row's two lines inside it", zp.CellH < zc.CellH and zp.TopH < zc.TopH
	and zp.ButtonH < zc.ButtonH and zp.GoalY + zp.GoalH <= zp.TopH and zc.GoalY + zc.GoalH <= zc.TopH and zc.CellH == 128, zp.CellH)
check("after 100: nothing left", UI.Goal(100, "Halo") == nil and UI.Goal(250, "Horns") == nil)

-- 5) opening by itself
local ctx = { Ready = true, Step = 99, Done = 99, Days = 3, Played = 30, Day = 50, OpenedDay = -1 }
check("a claim open, first mission done, calm: opens", UI.AutoOpen(ctx) == true)
ctx.OpenedDay = 50
check("once a day", UI.AutoOpen(ctx) == false)
ctx.OpenedDay, ctx.Step = 49, 2
check("not during the first mission", UI.AutoOpen(ctx) == false)
ctx.Step, ctx.Days = 99, 0
check("a first claim waits for 10 minutes of play", UI.AutoOpen(ctx) == false)
ctx.Played = 601
check("... then opens", UI.AutoOpen(ctx) == true)
ctx.Busy = true
check("never over something else (PauseCard.Busy)", UI.AutoOpen(ctx) == false)
ctx.Busy, ctx.Ready = false, false
check("nothing to claim: no window", UI.AutoOpen(ctx) == false)

-- 6) the window
local W = REGISTERED.Attendance
check("Init registers 'Attendance' (its own width, the title from Config)", W ~= nil and W.Width == 720
	and type(W.Title) == "function" and W.Title() == "Daily Gifts" and UI.IsReady())
local ENABLED, FIRED, ATTRFNS = {}, {}, {}
local order = 0
local kit = {
	Palette = { Free = "free", Button = "btn" }, Theme = { Gold = "gold", SubText = "sub", Text = "text" },
	NextOrder = function() order += 1 return order end,
	SetEnabled = function(btn, on) ENABLED[btn] = on end,
	Fire = function(name, ...) table.insert(FIRED, table.pack(name, ...)) end,
	OnAttr = function(fn) table.insert(ATTRFNS, fn) end,
	Text = function(parent, text, opts)
		local l = inst("TextLabel")
		l.Text, l.Name = text, opts and opts.Name or "Text"
		l.Parent = parent
		return l
	end,
	Button = function(parent, text, color, size, fn)
		local b2 = inst("TextButton")
		b2.Text, b2.Color = text, color
		b2.Parent = parent
		b2.Activated:Connect(fn)
		return b2
	end,
}
local function attrChanged(name, value)
	ATTR[name] = value
	for _, fn in ATTRFNS do fn(name) end
end
local root = inst("Frame")
local update = W.Build(root, kit, nil)
local board = find(root, "Board")
local cells = {}
for i = 1, 7 do cells[i] = board and board:FindFirstChild("Slot" .. i) end
check("seven slots in the board row", board and cells[1] and cells[7] and #board.Children >= 7, board and #board.Children)
local words = table.concat(texts(root), "|")
check("Day 1 .. Day 7 on the slots", words:find("Day 1", 1, true) and words:find("Day 7", 1, true), words:sub(1, 80))
local stamp1, stamp3 = find(cells[1], "Stamp"), find(cells[3], "Stamp")
check("the taken slots wear the stamp, today's not yet", stamp1 and stamp1.Visible == true and stamp3 and stamp3.Visible == false)
check("today's slot glows gold, thick", cells[3]:FindFirstChild("Rim").Thickness == 4
	and cells[3]:FindFirstChild("Rim").Color[1] == 255 and cells[4]:FindFirstChild("Rim").Thickness == 1)
check("slot 7 shows the weekly box art", find(cells[7], "Box") and find(cells[7], "Box").Art == "IconWeeklyBox")
check("slot 5 shows two rewards (potion + jelly)", find(cells[5], "Part1") and find(cells[5], "Part2")
	and find(find(cells[5], "Part2"), "Count").Text == "x14", find(cells[5], "Part2") and find(find(cells[5], "Part2"), "Count").Text)
local pays = find(root, "Pays")
check("the line: today's slot and what it gives", pays and pays.Text == "Today · Day 3: +Enhance Scroll 70%", pays and pays.Text)
local btn = find(root, "ClaimButton")
check("[Claim!] on while a claim is open", btn and btn.Text == "Claim!" and ENABLED[btn] == true and btn.Color == "free")
check("days collected + the next milestone", find(root, "Collected").Text == "Days collected: 2"
	and find(root, "Goal").Text == "7 days: Regular title")
check("the ribbon of the next milestone with its number", find(root, "Ribbon") and find(root, "Ribbon").Art == "RibbonDays7"
	and find(root, "Disc").Text == "7")
check("the calm line: a missed day resets nothing", words:find(T.Note, 1, true) ~= nil)
-- [Claim]
btn.Activated:Fire()
check("[Claim] asks the server once, no arguments", #FIRED == 1 and FIRED[1][1] == "ClaimAttendance" and FIRED[1].n == 1)
btn.Activated:Fire()
check("a second press before the answer is dropped, the button waits", #FIRED == 1 and ENABLED[btn] == false)
CLOCK += 3.5
update()
check("no answer in 3 s: the button unlocks", ENABLED[btn] == true)
btn.Activated:Fire()
check("... and can ask again", #FIRED == 2)
-- the server's answer
TWEENS = {}
ATTR.AttendDays = 3
ATTR.AttendReady = false
attrChanged("AttendSlot", 4)
check("the answer: slot 3 stamped with a pop", stamp3.Visible == true and stamp3:FindFirstChild("Pop").Scale == 1.8
	and #TWEENS >= 1 and TWEENS[#TWEENS].Goal.Scale == 1 and TWEENS[#TWEENS].Played, #TWEENS)
local before = #TWEENS
update()
check("an already stamped slot does not pop again", #TWEENS == before and stamp1:FindFirstChild("Pop").Scale ~= 1.8)
local g4 = minutes(1, 3)
check("then: 'Come back tomorrow!' off, the line says tomorrow's slot", btn.Text == "Come back tomorrow!" and ENABLED[btn] == false
	and pays.Text == "Tomorrow · Day 4: " .. string.format(T.Gold, Util.FormatNumber(g4)), pays.Text)
check("days collected redrawn", find(root, "Collected").Text == "Days collected: 3")
CLOCK += 5
btn.Activated:Fire()
check("nothing to claim: a press sends nothing", #FIRED == 2, #FIRED)
-- the weekly box taken
ATTR.AttendSlot, ATTR.AttendDays = 1, 7
TWEENS = {}
attrChanged("AttendReady", false)
local stamped = 0
for i = 1, 7 do if find(cells[i], "Stamp").Visible then stamped += 1 end end
check("week done: all seven stamped, the line says so", stamped == 7 and pays.Text == T.WeekDone, pays.Text)
check("the next milestone moves on (14 days: my side's look)", find(root, "Goal").Text == "14 days: Sprout Halo"
	and find(root, "Ribbon").Image == artId("RibbonDays14") and find(root, "Disc").Text == "14")
W.Cleanup()

-- 7) opening by itself (the module's tick)
ATTR.AttendSlot, ATTR.AttendReady, ATTR.AttendDays = 2, true, 1
OPENED = {}
check("opened by hand today: it does not open by itself again", UI.Tick() == false and #OPENED == 0)
local UI2 = load()
check("a calm screen, a claim open: Tick opens the board", UI2.Tick() == true and OPENED[1] and OPENED[1][1] == "Attendance")
check("the same day: not again", UI2.Tick() == false and #OPENED == 1)
UI2 = load()
BUSY.Busy = true
check("a busy screen: waits", UI2.Tick() == false and #OPENED == 1)
BUSY.Busy, BUSY.Waiting = false, true
check("a waiting pause card goes first", UI2.Tick() == false)
BUSY.Waiting = false
ATTR.TutorialStep = 1
check("the first mission: waits", UI2.Tick() == false)
ATTR.TutorialStep = 99
check("then it opens", UI2.Tick() == true and #OPENED == 2)
TIME += 86400
check("the next KST day: once more", UI2.Tick() == true and #OPENED == 3)
check("Ready() = the HUD glow (a claim open)", UI2.Ready() == true)
ATTR.AttendReady = false
check("... off once taken", UI2.Ready() == false)

print(("ATTENDANCE_UI_SUMMARY checks=%d failed=%d"):format(checks, failed))
if failed == 0 then print("ATTENDANCE_UI_OFFLINE_OK") end
