-- Offline checks for ChoiceCardUI.luau (gameplay_plan 2-A #3; servers ChoiceCard.luau + FinisherService.luau) with the
-- real Config.luau and Util.luau. The runner (tools/test_choice_card_ui.py) prepends CONFIG_SOURCE, UTIL_SOURCE and
-- UI_SOURCE. Roblox is replaced by small doubles: Instance-like tables, a Panels double (Register / Open / Close /
-- CurrentId: Open runs the window's Build, Close its Cleanup), the window kit double (Row / Column / Text / ChoiceButton /
-- SetEnabled), Net (Get(name) -> FireServer recorder + OnClientEvent), PauseCard.Busy, Fx.LastFightAt, the players and
-- their characters, os.clock as a number, task.delay recorded.
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

local imt = {}
imt.__index = function(self, k)
	local m = rawget(imt, "methods")[k]
	if m then return m end
	if k == "Activated" or k == "AncestryChanged" then local s = signal() rawset(self, k, s) return s end
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
	FindFirstChildOfClass = function(self, cl)
		for _, c in self.Children do if c.ClassName == cl then return c end end
		return nil
	end,
	GetChildren = function(self) return table.clone(self.Children) end,
	GetDescendants = function(self)
		local out = {}
		for _, c in self.Children do
			table.insert(out, c)
			for _, d in c:GetDescendants() do table.insert(out, d) end
		end
		return out
	end,
	SetAttribute = function(self, k, v) rawset(self, "Attr_" .. k, v) end,
	GetAttribute = function(self, k) return rawget(self, "Attr_" .. k) end,
	IsA = function(self, cl) return self.ClassName == cl or (cl == "BasePart" and self.ClassName == "Part") end,
	Destroy = function(self)
		local p = rawget(self, "Parent")
		if p then
			local i = table.find(p.Children, self)
			if i then table.remove(p.Children, i) end
		end
		rawset(self, "Parent", nil)
		self.Destroyed = true
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
		if (c.ClassName == "TextLabel" or c.ClassName == "TextButton") and c.Text then table.insert(out, c.Text) end
		texts(c, out)
	end
	return out
end
local function hasText(root, s)
	for _, t in texts(root) do if string.find(t, s, 1, true) then return true end end
	return false
end

local CLOCK = 100
local cfgEnv = setmetatable({
	game = { GetService = function() return setmetatable({}, { __index = function() return function() return nil end end }) end },
	Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }, Vector2 = ctor("Vector2"), UDim2 = ctor("UDim2"),
	UDim = ctor("UDim"),
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
setfenv(ufn, setmetatable({ game = cfgEnv.game, warn = function() end, Random = { new = function() return {} end },
	workspace = { GetServerTimeNow = function() return 1790000000 end } }, { __index = getfenv() }))
local Util = ufn()
Util.Now = function() return 1790000000 end

-- players and characters
local ATTR = {}
local function character(hip)
	local char = inst("Model")
	local root = inst("Part")
	root.Name, root.Size = "HumanoidRootPart", { X = 2, Y = 2, Z = 1 }
	root.Parent = char
	local hum = inst("Humanoid")
	hum.Health, hum.HipHeight = 100, hip or 2
	hum.Parent = char
	return char, root, hum
end
local LP = { UserId = 7, Name = "Me" }
function LP:GetAttribute(k) return ATTR[k] end
local myChar, myRoot, myHum = character(2)
LP.Character = myChar
local OTHER = { UserId = 9, Name = "Friend" }
local otherChar, otherRoot = character(1.5)
OTHER.Character = otherChar
local PLAYERS = { [7] = LP, [9] = OTHER }

-- Net double
local FIRED, REMOTES = {}, {}
local function remote(name)
	if not REMOTES[name] then
		REMOTES[name] = { OnClientEvent = signal(), FireServer = function(_, ...) table.insert(FIRED, { name, ... }) end }
	end
	return REMOTES[name]
end
local Net = { Get = function(name) return remote(name) end }

-- Panels + kit doubles
local REGISTERED, OPENS, CLOSES = {}, 0, 0
local CURRENT, BODY, UPDATE = nil, nil, nil
local ENABLED = {}
local kit = {
	Theme = { Gold = "gold", SubText = "sub" },
	Row = function(parent, h, gap) local f = inst("Frame") f.Name = "Row" f.H = h f.Parent = parent return f end,
	Column = function(parent, sx, ox, gap) local f = inst("Frame") f.Name = "Column" f.Parent = parent return f end,
	Text = function(parent, text, opts)
		local l = inst("TextLabel")
		l.Name = (opts and opts.Name) or "Text"
		l.Text = text
		l.Color = opts and opts.Color
		l.Parent = parent
		return l
	end,
	ChoiceButton = function(parent, side, text, size, onClick)
		local b = inst("TextButton")
		b.Name, b.Text, b.Side, b.Click = "Button", text, side, onClick
		b.Parent = parent
		ENABLED[b] = true
		return b
	end,
	SetEnabled = function(b, on) ENABLED[b] = on end,
}
local BUSY = false
local C = {
	PauseCard = { Busy = function() return BUSY end },
	Fx = { LastFightAt = nil },
	UIKit = { ArtBar = function(props)
		local f = inst("Frame")
		f.Name = props.Name
		f.Parent = props.Parent
		local bar = { Fraction = nil }
		return f, function(x) bar.Fraction = x f.Fraction = x end, nil
	end },
	Panels = {
		Register = function(id, opts) REGISTERED[id] = opts return true end,
		CurrentId = function() return CURRENT end,
		Open = function(id)
			local o = REGISTERED[id]
			if CURRENT and REGISTERED[CURRENT] and REGISTERED[CURRENT].Cleanup then REGISTERED[CURRENT].Cleanup() end
			OPENS += 1
			CURRENT = id
			BODY = inst("Frame")
			UPDATE = o and o.Build(BODY, kit) or nil
		end,
		Close = function()
			if CURRENT and REGISTERED[CURRENT] and REGISTERED[CURRENT].Cleanup then REGISTERED[CURRENT].Cleanup() end
			CLOSES += 1
			CURRENT, BODY, UPDATE = nil, nil, nil
		end,
	},
}
local DELAYS = {}
local HEART = signal()
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then
			return { LocalPlayer = LP, GetPlayerByUserId = function(_, id) return PLAYERS[id] end }
		end
		if n == "ReplicatedStorage" then
			return { WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end }
		end
		if n == "RunService" then return { Heartbeat = HEART } end
		return {}
	end },
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end },
	UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromScale = function(x, y) return { x, 0, y, 0 } end,
		fromOffset = function(x, y) return { 0, x, 0, y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = cfgEnv.Color3, ColorSequence = cfgEnv.ColorSequence, NumberRange = cfgEnv.NumberRange,
	NumberSequence = cfgEnv.NumberSequence,
	Enum = enum,
	Instance = { new = inst },
	typeof = function(v) return (type(v) == "table" and getmetatable(v) == imt) and "Instance" or typeof(v) end, -- ChoiceCardUI.Dim
	os = { clock = function() return CLOCK end, time = os.time, date = os.date },
	task = { spawn = function() end, defer = function() end, wait = function() end,
		delay = function(t, fn) table.insert(DELAYS, { At = CLOCK + t, Fn = fn }) end },
	require = function(m)
		if m.__module == "Config" then return Config end
		if m.__module == "Util" then return Util end
		if m.__module == "Net" then return Net end
		return {}
	end,
}, { __index = getfenv() })
local fn = assert(loadstring(UI_SOURCE, "=ChoiceCardUI"))
setfenv(fn, env)
local UI = fn()
UI.Init(C)
UI.Start()
local T = UI._T
local function fx(kind, data) remote("Fx").OnClientEvent:Fire(kind, data) end
local function runDelays()
	local due = {}
	for i = #DELAYS, 1, -1 do
		if DELAYS[i].At <= CLOCK then table.insert(due, table.remove(DELAYS, i)) end
	end
	for _, d in due do d.Fn() end
end
local function button(side)
	return BODY and BODY:FindFirstChild(side .. "Button", true)
end

local F = Config.Finisher
local king = F.Cards.SlimeKing
local scr = Config.ChoiceCard.Screen

-- 0) wiring
check("registers the Panels window 'ChoiceCard'", REGISTERED.ChoiceCard ~= nil and T.S.Ready == true)
check("listens to Fx", #remote("Fx").OnClientEvent.Fns == 1)
check("Config.ChoiceCard.Screen words", type(scr) == "table" and type(scr.Item) == "string" and type(scr.Gold) == "string"
	and type(scr.Seconds) == "string" and type(scr.Later) == "number")

-- 1) pure lines
check("reward: item + count", UI.RewardLine({ Item = "Jelly", N = 2 }) == string.format(scr.Item, 2, Config.Loot.Items.Jelly.Name),
	UI.RewardLine({ Item = "Jelly", N = 2 }))
check("reward: gold", UI.RewardLine({ Gold = 1234 }) == string.format(scr.Gold, Util.FormatInt(1234)), UI.RewardLine({ Gold = 1234 }))
check("reward: XP (ChoiceCard.Text.XP)", UI.RewardLine({ XP = 6 }) == string.format(Config.ChoiceCard.Text.XP, "6"),
	UI.RewardLine({ XP = 6 }))
check("reward: two parts joined", string.find(UI.RewardLine({ Item = "Petal", N = 2, Gold = 4 }), " · ", 1, true) ~= nil)
check("reward: nothing -> empty", UI.RewardLine({}) == "" and UI.RewardLine(nil) == "")
check("score: my side +1", UI.ScoreLine("Honor", 1, nil) == string.format(F.Text.Score, "Honor", 1), UI.ScoreLine("Honor", 1))
check("score: the other side -1, Infamy shown as Mischief (A23-166)", UI.ScoreLine("Infamy", -1, nil)
	== string.format(F.Text.ScoreDown, "Mischief", 1) and scr.Stat.Infamy == "Mischief", UI.ScoreLine("Infamy", -1))
check("score: Mischief +1 on the Horns side", UI.ScoreLine("Infamy", 1, nil) == string.format(F.Text.Score, "Mischief", 1)
	and not string.find(UI.ScoreLine("Infamy", 1, nil), "Infamy", 1, true), UI.ScoreLine("Infamy", 1))
check("score 0: no hint lines (A23-191)", UI.ScoreLine("Honor", 0, "Full") == "" and UI.ScoreLine("Honor", 0, "Zero")
	== "" and UI.ScoreLine("None", 0, "Neutral") == "")
check("score 0, no hint: nothing", UI.ScoreLine("Honor", 0, nil) == "")

-- 2) the finisher card (timed): opens at once, the words from Config.Finisher.Cards
fx("FinisherCard", { Id = 4, Kind = "SlimeKing", Seconds = 10, Stat = "Honor",
	Help = { Item = "Jelly", N = 2, Score = 1 }, Tickle = { Gold = 4, Score = -1 } })
check("a finisher card opens the window at once", CURRENT == "ChoiceCard" and OPENS == 1, CURRENT)
check("its title = the boss card's Title", REGISTERED.ChoiceCard.Title() == king.Text.Title, REGISTERED.ChoiceCard.Title())
check("two choice buttons: Good = Help words, Evil = Tickle words", button("Good") and button("Good").Text == king.Text.Help
	and button("Good").Side == "Good" and button("Evil") and button("Evil").Text == king.Text.Tickle and button("Evil").Side == "Evil")
check("under them what each gives and does", hasText(BODY, UI.RewardLine({ Item = "Jelly", N = 2 }))
	and hasText(BODY, UI.RewardLine({ Gold = 4 })) and hasText(BODY, string.format(F.Text.Score, "Honor", 1))
	and hasText(BODY, string.format(F.Text.ScoreDown, "Honor", 1)))
check("a countdown for the timed card", BODY:FindFirstChild("TimeBar", true) ~= nil and BODY:FindFirstChild("Seconds", true)
	and BODY:FindFirstChild("Seconds", true).Text == string.format(scr.Seconds, 10), BODY:FindFirstChild("Seconds", true)
	and BODY:FindFirstChild("Seconds", true).Text)
CLOCK += 3
HEART:Fire()
check("the countdown runs", BODY:FindFirstChild("Seconds", true).Text == string.format(scr.Seconds, 7)
	and math.abs((BODY:FindFirstChild("TimeBar", true).Fraction or 0) - 0.7) < 1e-6, BODY:FindFirstChild("Seconds", true).Text)
button("Good").Click()
check("a pick fires FinisherPick (id, 'Help') once", #FIRED == 1 and FIRED[1][1] == "FinisherPick" and FIRED[1][2] == 4
	and FIRED[1][3] == "Help", FIRED[1] and table.concat({ tostring(FIRED[1][1]), tostring(FIRED[1][2]), tostring(FIRED[1][3]) }, ","))
check("both buttons lock after a pick", ENABLED[button("Good")] == false and ENABLED[button("Evil")] == false)
button("Evil").Click()
check("no second pick while waiting", #FIRED == 1, #FIRED)
fx("CardEnd", { Id = 4, Side = "Good" })
check("a ChoiceCard end does not close a finisher card", CURRENT == "ChoiceCard")
fx("FinisherEnd", { Id = 3, Pick = "Help" })
check("another id's end changes nothing", CURRENT == "ChoiceCard")
fx("FinisherEnd", { Id = 4, Pick = "Help" })
check("its end closes the window", CURRENT == nil and UI.Current() == nil, CURRENT)

-- 3) a timed card nobody picks closes when its time is up
fx("FinisherCard", { Id = 5, Kind = "CaptainClatter", Seconds = 10, Stat = "Infamy",
	Help = { Item = "Enh70", N = 1, Score = -1 }, Tickle = { Gold = 300, Score = 1 } })
check("Captain Clatter's words", button("Good") and button("Good").Text == F.Cards.CaptainClatter.Text.Help)
CLOCK += 10.1
local before = #FIRED
T.Pick("Good") -- the window still shows (no frame yet) but the time is up
check("no pick after the time", #FIRED == before, #FIRED - before)
HEART:Fire()
check("time up: the window closes, the card is gone", CURRENT == nil and UI.Current() == nil, CURRENT)

-- 4) a saved ChoiceCard card waits for a calm screen
C.Fx.LastFightAt = CLOCK - 1
fx("Card", { Id = 11, Kind = "FlowerPatch", Title = Config.ChoiceCard.Kinds.FlowerPatch.Title, Stat = "Honor",
	Good = { Label = "Replant it", XP = 6, Score = 1 }, Evil = { Label = "Pick the petals", Item = "Petal", N = 2, Score = -1 } })
check("a saved card waits while I fight", CURRENT == nil and UI.Current() ~= nil, CURRENT)
CLOCK += 5
BUSY = true
T.TryShow()
check("... and while the screen is busy (PauseCard)", CURRENT == nil)
BUSY = false
CURRENT = "Bag"
T.TryShow()
check("... and while another window is open", CURRENT == "Bag")
CURRENT = nil
myHum.Health = 0
T.TryShow()
check("... and while I am dead", CURRENT == nil)
myHum.Health = 100
T.TryShow()
check("calm: it opens", CURRENT == "ChoiceCard" and REGISTERED.ChoiceCard.Title() == Config.ChoiceCard.Kinds.FlowerPatch.Title)
check("a saved card has no countdown", BODY:FindFirstChild("TimeBar", true) == nil)
check("its lines (XP / petals, Honor +1 / -1)", hasText(BODY, UI.RewardLine({ XP = 6 })) and hasText(BODY, UI.RewardLine({ Item = "Petal", N = 2 })))
-- closed by hand: comes back after Later s
C.Panels.Close()
check("closed by hand: it waits", CURRENT == nil and UI.Current() ~= nil)
T.TryShow()
check("... not again at once", CURRENT == nil)
CLOCK += scr.Later + 0.1
T.TryShow()
check("... again after Later s", CURRENT == "ChoiceCard")
button("Evil").Click()
check("a pick fires CardAction (id, 'Evil')", FIRED[#FIRED][1] == "CardAction" and FIRED[#FIRED][2] == 11 and FIRED[#FIRED][3] == "Evil")
-- no answer: the buttons unlock after Wait (the Start loop does it; here by hand like it)
CLOCK += T.L.Wait + 0.1
local n = #FIRED
button("Good").Click()
check("no answer within Wait: a new pick may go", #FIRED == n + 1, #FIRED - n)
fx("CardEnd", { Id = 11, Side = "Good" })
check("the end closes it", CURRENT == nil and UI.Current() == nil)

-- 5) a new card while another shows replaces it
fx("Card", { Id = 12, Kind = "FlowerPatch", Stat = "None", Good = { Label = "A", XP = 6, Score = 0, Hint = "Neutral" },
	Evil = { Label = "B", Item = "Petal", N = 2, Score = 0, Hint = "Neutral" } })
fx("FinisherCard", { Id = 6, Kind = "SlimeKing", Seconds = 10, Stat = "None",
	Help = { Item = "Jelly", N = 2, Score = 0, Hint = "Neutral" }, Tickle = { Gold = 4, Score = 0, Hint = "Neutral" } })
check("the newer (timed) card shows", CURRENT == "ChoiceCard" and UI.Current() and UI.Current().Id == 6 and button("Good").Text == king.Text.Help)
check("a neutral player reads no hint line (A23-191)", not hasText(BODY, "No good or evil points"))
check("the saved card is held back, not lost", T.S.Held and T.S.Held.Id == 12)
fx("FinisherEnd", { Id = 6, Pick = "None" })
check("the timed card over: the saved card comes back", CURRENT == nil and UI.Current() and UI.Current().Id == 12
	and T.S.Held == nil)
T.TryShow()
check("... and opens on the calm screen", CURRENT == "ChoiceCard" and button("Good") and button("Good").Text == "A")
-- the held card's own end while the timed one shows drops it
fx("FinisherCard", { Id = 7, Kind = "SlimeKing", Seconds = 10, Stat = "Honor",
	Help = { Item = "Jelly", N = 2, Score = 1 }, Tickle = { Gold = 4, Score = -1 } })
fx("CardEnd", { Id = 12, Side = "None" })
check("a held card that ended is dropped", T.S.Held == nil and UI.Current().Id == 7)
CLOCK += 11
HEART:Fire()
check("the timed card ran out: nothing comes back", UI.Current() == nil and CURRENT == nil)
-- 최종 검수 10/14 MINOR 1: a card from the other server while a timed card runs waits; the timed card stays
fx("FinisherCard", { Id = 8, Kind = "SlimeKing", Seconds = 10, Stat = "Honor",
	Help = { Item = "Jelly", N = 2, Score = 1 }, Tickle = { Gold = 4, Score = -1 } })
fx("Card", { Id = 13, Kind = "FlowerPatch", Stat = "None", Good = { Label = "A", XP = 6, Score = 0, Hint = "Neutral" },
	Evil = { Label = "B", Item = "Petal", N = 2, Score = 0, Hint = "Neutral" } })
check("a card over a running timed card waits: the timed card stays", CURRENT == "ChoiceCard" and UI.Current()
	and UI.Current().Id == 8 and button("Good") and button("Good").Text == king.Text.Help and T.S.Held and T.S.Held.Id == 13)
fx("Card", { Id = 14, Kind = "FlowerPatch", Seconds = 120, Stat = "None", Good = { Label = "C", XP = 6, Score = 0, Hint = "Neutral" },
	Evil = { Label = "D", Item = "Petal", N = 2, Score = 0, Hint = "Neutral" } })
check("a newer card from the same server replaces the held one", UI.Current().Id == 8 and T.S.Held and T.S.Held.Id == 14)
fx("FinisherEnd", { Id = 8, Pick = "Help" })
T.TryShow()
check("the timed card over: the waiting card shows", CURRENT == "ChoiceCard" and UI.Current() and UI.Current().Id == 14
	and T.S.Held == nil and button("Good") and button("Good").Text == "C")
fx("CardEnd", { Id = 14, Side = "None" })
check("... and its end closes it", UI.Current() == nil and CURRENT == nil)

-- 5b) A23-191: no points left today (Hint "Full") = that button dims, no words; the other stays bright
fx("FinisherCard", { Id = 9, Kind = "SlimeKing", Seconds = 10, Stat = "Honor",
	Help = { Item = "Jelly", N = 2, Score = 0, Hint = "Full" }, Tickle = { Gold = 4, Score = -1 } })
check("a Full option's button dims, the other does not", button("Good") and button("Good"):GetAttribute("Dimmed") == true
	and (tonumber(button("Good").TextTransparency) or 0) >= 0.5 and button("Evil") and button("Evil"):GetAttribute("Dimmed") == nil)
check("... and no hint words under it", not hasText(BODY, "No more points today"))
fx("FinisherEnd", { Id = 9, Pick = "None" })

-- 6) bad payloads
fx("Card", { Id = "x" })
fx("FinisherCard", { Id = 1, Kind = "SlimeKing" })
fx("Card", nil)
check("broken cards are ignored", UI.Current() == nil and CURRENT == nil)

-- 7) the afterglow
fx("Afterglow", { UserId = 7, Side = "Good", Seconds = 60 })
local att = myRoot:FindFirstChild("AfterglowAt")
local em = att and att:FindFirstChild("Afterglow")
check("Good: an emitter at my feet", em ~= nil and att.Position.Y < -2.5, att and att.Position and att.Position.Y)
check("Good = round gold sparkles (built-in sparkle texture, gold)", em and string.find(em.Texture, "sparkles", 1, true)
	and em.Color.Args and em.Color.Args[1][1] == 255)
fx("Afterglow", { UserId = 9, Side = "Evil", Seconds = 60 })
local att2 = otherRoot:FindFirstChild("AfterglowAt")
local em2 = att2 and att2:FindFirstChild("Afterglow")
check("Evil on another player: purple smoke (built-in smoke texture)", em2 ~= nil and string.find(em2.Texture, "smoke", 1, true)
	and em2.Color.Args[1][3] > em2.Color.Args[1][1])
fx("Afterglow", { UserId = 7, Side = "Evil", Seconds = 60 })
local count = 0
for _, c in myRoot.Children do if c.Name == "AfterglowAt" then count += 1 end end
check("a new glow replaces mine (the old one stops)", em.Enabled == false, em.Enabled)
CLOCK += 3
runDelays()
count = 0
for _, c in myRoot.Children do if c.Name == "AfterglowAt" then count += 1 end end
check("... and goes after its fade", count == 1, count)
CLOCK += 60
runDelays()
CLOCK += 3
runDelays()
count = 0
for _, c in myRoot.Children do if c.Name == "AfterglowAt" then count += 1 end end
check("after Seconds the glow ends", count == 0, count)
fx("Afterglow", { UserId = 7, Side = "None", Seconds = 60 })
fx("Afterglow", { UserId = 99, Side = "Good", Seconds = 60 })
count = 0
for _, c in myRoot.Children do if c.Name == "AfterglowAt" then count += 1 end end
check("no glow for 'None' or an unknown player", count == 0)
local saved = Config.Afterglow.Enabled
Config.Afterglow.Enabled = false
fx("Afterglow", { UserId = 7, Side = "Good", Seconds = 60 })
check("the Afterglow switch off: none", myRoot:FindFirstChild("AfterglowAt") == nil)
Config.Afterglow.Enabled = saved

print(("CHOICE_CARD_UI_SUMMARY checks=%d failed=%d"):format(checks, failed))
