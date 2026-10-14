-- Offline checks for VillageFundUI.luau (A23-178 B; contract docs/design/village_fund_server_2026-10-14.md §8) with the
-- real Config.luau and Util.luau. The runner (tools/test_village_fund_ui.py) prepends CONFIG_SOURCE, UTIL_SOURCE and
-- UI_SOURCE. Roblox is replaced by small doubles: Vector3 with + / - / Magnitude, Instance-like tables (attributes,
-- IsA, FindFirstAncestorWhichIsA, Emit), workspace (descendants + DescendantAdded), ReplicatedStorage attributes and
-- the GameState folder, the Panels / kit / UIKit.ArtBar doubles, Net (FireServer recorder + OnClientEvent), the player
-- and the character, os.clock as a number. When Config.VillageFund is not on this branch yet (game dev 2's server
-- branch dev2-village-fund adds it), its table as dev 2 wrote it (message 10/14: Text keys, Spots.Halo only) is put in.
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

-- Vector3
local vmt = {}
local function v3(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __v3 = true }, vmt) end
vmt.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__index = function(self, k)
	if k == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z) end
	return nil
end

-- instances
local imt = {}
imt.__index = function(self, k)
	local m = rawget(imt, "methods")[k]
	if m then return m end
	if k == "Activated" or k == "AncestryChanged" then local s = signal() rawset(self, k, s) return s end
	return nil
end
local CLASSES = { BasePart = { Part = true }, Instance = true }
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
		local function walk(o) for _, c in o.Children do table.insert(out, c) walk(c) end end
		walk(self)
		return out
	end,
	IsA = function(self, cl) return self.ClassName == cl or (CLASSES[cl] and type(CLASSES[cl]) == "table" and CLASSES[cl][self.ClassName]) == true end,
	FindFirstAncestorWhichIsA = function(self, cl)
		local p = rawget(self, "Parent")
		while p do
			if type(p) == "table" and p.IsA and p:IsA(cl) then return p end
			p = rawget(p, "Parent")
		end
		return nil
	end,
	GetAttribute = function(self, k) return self.Attrs and self.Attrs[k] or nil end,
	SetAttribute = function(self, k, v) self.Attrs = self.Attrs or {} self.Attrs[k] = v end,
	Emit = function(self, count) self.Emitted = (self.Emitted or 0) + count end,
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
local ADDED = signal()
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
		if (c.ClassName == "TextLabel" or c.ClassName == "TextButton") and c.Text and c.Visible ~= false then table.insert(out, c.Text) end
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
	Vector3 = { new = v3 }, Vector2 = ctor("Vector2"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
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
local CONTRACT = false
if type(Config.VillageFund) ~= "table" then
	CONTRACT = true
	Config.VillageFund = { Enabled = true, Step = 1000, PerDay = 3, Points = 1,
		Spots = { Halo = { Pos = v3(22, 10, -590), Lift = 3, Radius = 16, Zone = "HaloTown", Model = "Town_Halo_Fountain3" } },
		Goals = { Lanterns = 30000, Fireworks = 100000 },
		Text = { Title = "Village Fund", Today = "Today %d/%d", Poor = "You need %s gold.",
			Full = "That's %d for today. Come back tomorrow!", Closed = "The village fund is closed for now.",
			Halo = { Prompt = "Share gold", Give = "Share %s gold", Done = "You shared gold!", Lanterns = "Lanterns!",
				Fireworks = "Fireworks!" },
			Horns = { Prompt = "Show off gold", Give = "Show off %s gold", Done = "You showed off gold!",
				Lanterns = "Lanterns!", Fireworks = "Fireworks!" } } }
end
local VF = Config.VillageFund
-- the Horns fountain is placed when Horns town is rebuilt (contract §2): a test spot for this run only
VF.Spots = VF.Spots or {}
VF.Spots.Horns = VF.Spots.Horns or { Pos = v3(400, 10, 300), Radius = 16 }
local HALO, HORNS = VF.Spots.Halo, VF.Spots.Horns
local SCR = Config.VillageFundScreen

-- world doubles
local WS = inst("Workspace")
WS.DescendantAdded = ADDED
local function add(o, parent)
	o.Parent = parent
	ADDED:Fire(o)
	for _, d in o:GetDescendants() do ADDED:Fire(d) end
end
local RSATTR, RSSIG = {}, {}
local GS = inst("Folder")
GS.Name = "GameState"
GS.Attrs = { DayPhase = "Day" }
local function rsSignal(k) RSSIG[k] = RSSIG[k] or signal() return RSSIG[k] end
local RS = {
	WaitForChild = function() return { WaitForChild = function(_, m) return { __module = m } end } end,
	GetAttribute = function(_, k) return RSATTR[k] end,
	GetAttributeChangedSignal = function(_, k) return rsSignal(k) end,
	FindFirstChild = function(_, n) return n == "GameState" and GS or nil end,
}
-- the fund attributes live on GameState (VillageFundService); the change signal is fired on both
local function setRS(k, v) GS.Attrs[k] = v rsSignal(k):Fire() end
local UIS = { TouchEnabled = false, KeyboardEnabled = true }
local GUI = { ReducedMotionEnabled = false }

-- the player
local ATTR, PSIG = { Faction = "Halo" }, {}
local LP = { UserId = 7, Name = "Me" }
function LP:GetAttribute(k) return ATTR[k] end
function LP:GetAttributeChangedSignal(k) PSIG[k] = PSIG[k] or signal() return PSIG[k] end
local function setAttr(k, v) ATTR[k] = v if PSIG[k] then PSIG[k]:Fire() end end
local char = inst("Model")
local root = inst("Part")
root.Name = "HumanoidRootPart"
root.Position = HALO.Pos + v3(4, 3, 2)
root.Parent = char
local hum = inst("Humanoid")
hum.Health = 100
hum.Parent = char
LP.Character = char

-- Net double
local FIRED, REMOTES = {}, {}
local function remote(name)
	if not REMOTES[name] then
		REMOTES[name] = { OnClientEvent = signal(), FireServer = function(_, ...) table.insert(FIRED, { name, select("#", ...), ... }) end }
	end
	return REMOTES[name]
end
local Net = { Get = function(name) return remote(name) end }

-- Panels + kit doubles
local REGISTERED, OPENS, CLOSES = {}, 0, 0
local CURRENT, BODY = nil, nil
local ENABLED = {}
local kit = {
	Theme = { Gold = "gold", SubText = "sub" },
	Palette = { Free = "free", Button = "button" },
	Row = function(parent, h, gap) local f = inst("Frame") f.Name = "Row" f.H = h f.Parent = parent return f end,
	Column = function(parent) local f = inst("Frame") f.Name = "Column" f.Parent = parent return f end,
	Text = function(parent, text, opts)
		local l = inst("TextLabel")
		l.Name = (opts and opts.Name) or "Text"
		l.Text = text
		l.Parent = parent
		return l
	end,
	Button = function(parent, text, color, size, onClick)
		local b = inst("TextButton")
		b.Name, b.Text, b.Color, b.Click = "Button", text, color, function() if ENABLED[b] ~= false then onClick() end end
		b.Parent = parent
		ENABLED[b] = true
		return b
	end,
	SetEnabled = function(b, on) ENABLED[b] = on end,
}
local BAR = { Fraction = nil }
local C = {
	UIKit = { ArtBar = function(props)
		local f = inst("Frame")
		f.Name = props.Name
		f.Parent = props.Parent
		return f, function(x) BAR.Fraction = x end, nil
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
			if o then o.Build(BODY, kit) end
		end,
		Close = function()
			if CURRENT and REGISTERED[CURRENT] and REGISTERED[CURRENT].Cleanup then REGISTERED[CURRENT].Cleanup() end
			CLOSES += 1
			CURRENT, BODY = nil, nil
		end,
	},
}
local env = setmetatable({
	game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = LP } end
		if n == "ReplicatedStorage" then return RS end
		if n == "UserInputService" then return UIS end
		if n == "GuiService" then return GUI end
		return {}
	end },
	workspace = WS,
	Vector2 = { new = function(x, y) return { X = x, Y = y } end },
	Vector3 = { new = v3 },
	UDim2 = { new = function(a, b, c, d) return { a, b, c, d } end, fromScale = function(x, y) return { x, 0, y, 0 } end,
		fromOffset = function(x, y) return { 0, x, 0, y } end },
	UDim = { new = function(a, b) return { a, b } end },
	Color3 = cfgEnv.Color3, ColorSequence = cfgEnv.ColorSequence, NumberRange = cfgEnv.NumberRange,
	NumberSequence = cfgEnv.NumberSequence, NumberSequenceKeypoint = cfgEnv.NumberSequenceKeypoint,
	Enum = enum,
	Instance = { new = inst },
	Random = { new = function() return { NextInteger = function(_, a) return a end, NextNumber = function() return 0.5 end } end },
	typeof = function(v)
		if type(v) == "table" and rawget(v, "__v3") then return "Vector3" end
		if type(v) == "table" and rawget(v, "ClassName") then return "Instance" end
		return typeof(v)
	end,
	os = { clock = function() return CLOCK end, time = os.time, date = os.date },
	task = { spawn = function() end, defer = function() end, wait = function() end, delay = function() end },
	require = function(m)
		if m.__module == "Config" then return Config end
		if m.__module == "Util" then return Util end
		if m.__module == "Net" then return Net end
		return {}
	end,
}, { __index = getfenv() })

-- prompts placed before the client starts: Halo's with its attribute, Horns' found by its spot
local haloPart = inst("Part")
haloPart.Position = HALO.Pos
local haloPrompt = inst("ProximityPrompt")
haloPrompt.Name, haloPrompt.Enabled, haloPrompt.ActionText, haloPrompt.ObjectText = "FundPrompt", true, "", ""
haloPrompt.Attrs = { Faction = "Halo", ActionKey = "Config.VillageFund.Text.Halo.Prompt", ObjectKey = "Config.VillageFund.Text.Title" }
haloPrompt.Parent = haloPart
haloPart.Parent = WS
local hornsPart = inst("Part")
hornsPart.Position = HORNS.Pos + v3(1, 0, 1)
local hornsPrompt = inst("ProximityPrompt")
hornsPrompt.Name, hornsPrompt.Enabled, hornsPrompt.ActionText = "FundPrompt", true, ""
hornsPrompt.Attrs = { ActionKey = "Config.VillageFund.Text.Nope.Prompt" }
hornsPrompt.Parent = hornsPart
hornsPart.Parent = WS
local otherPrompt = inst("ProximityPrompt")
otherPrompt.Name, otherPrompt.Enabled = "CraftPrompt", true
otherPrompt.Parent = hornsPart

local fn = assert(loadstring(UI_SOURCE, "=VillageFundUI"))
setfenv(fn, env)
local UI = fn()
UI.Init(C)
UI.Start()
local T = UI._T
local function open(state) remote("FundOpen").OnClientEvent:Fire(state) end
local function give() return BODY and BODY:FindFirstChild("GiveButton", true) end
local function label(n) return BODY and BODY:FindFirstChild(n, true) end
local function fundFired() local c = 0 for _, f in FIRED do if f[1] == "FundGive" then c += 1 end end return c end

-- 0) wiring
check("registers the Panels window 'VillageFund'", REGISTERED.VillageFund ~= nil and T.S.Ready == true)
check("listens to FundOpen", #remote("FundOpen").OnClientEvent.Fns == 1)
check("Config.VillageFundScreen words", type(SCR) == "table" and type(SCR.Gold) == "string" and type(SCR.Close) == "string"
	and type(SCR.Lead) == "table" and type(SCR.Lead.Halo) == "string" and type(SCR.Lead.Horns) == "string")
check("no copy of the server's words in the card table", SCR.Title == nil and SCR.Today == nil and SCR.Give == nil
	and SCR.Poor == nil and SCR.Full == nil)
check("the server's words exist (Config.VillageFund.Text)", type(VF.Text) == "table" and type(VF.Text.Poor) == "string"
	and type(VF.Text.Full) == "string" and type(VF.Text.Closed) == "string" and type(VF.Text.Today) == "string"
	and type(VF.Text.Title) == "string" and type(VF.Text.Halo.Give) == "string" and type(VF.Text.Horns.Give) == "string")
check("the window title is the server's Title", REGISTERED.VillageFund.Title() == VF.Text.Title)

-- 1) pure
local base = { Faction = "Halo", Today = 0, PerDay = 3, Step = 1000, Gold = 2500, Week = 2900, Sum = 12000,
	Goals = { Lanterns = 30000, Fireworks = 100000 }, Level = 0 }
local function with(t) local s = table.clone(base) for k, v in t do s[k] = v end return s end
check("reason: nothing in the way", UI.Reason(base) == nil, UI.Reason(base))
check("reason: less gold than one gift = Poor", UI.Reason(with({ Gold = 999 })) == "Poor")
check("reason: 3 today = Full (even when poor too)", UI.Reason(with({ Today = 3 })) == "Full" and UI.Reason(with({ Today = 3, Gold = 0 })) == "Full")
check("reason: the server's Why wins", UI.Reason(with({ Why = "Closed", Can = false })) == "Closed"
	and UI.Reason(with({ Why = "Poor", Gold = 99999 })) == "Poor")
check("reason: Can = false without a Why = Closed", UI.Reason(with({ Can = false })) == "Closed" and UI.Reason(with({ Can = true })) == nil)
local cl = UI.CardLines(base)
check("Halo card: Share + Honor", string.find(cl.Lead, "Share", 1, true) ~= nil and string.find(cl.Lead, "Honor +1", 1, true) ~= nil, cl.Lead)
check("the card names the towns by their game names (glossary)", string.find(cl.Lead, "Halo Citadel", 1, true) ~= nil
	and string.find(UI.CardLines(with({ Faction = "Horns" })).Lead, "Horns Den", 1, true) ~= nil, cl.Lead)
check("reason: knocked out = Closed, past the reach = Far (before the server's own)", UI.Reason(base, { Dead = true }) == "Closed"
	and UI.Reason(base, { Far = true }) == "Far" and UI.Reason(with({ Today = 3 }), { Far = true }) == "Far"
	and UI.CardLines(base, { Far = true }).Reason == SCR.Far and UI.CardLines(base, { Far = true }).CanGive == false)
check("Horns card: Show off + Mischief", string.find(UI.CardLines(with({ Faction = "Horns" })).Lead, "Show off", 1, true) ~= nil
	and string.find(UI.CardLines(with({ Faction = "Horns" })).Lead, "Mischief +1", 1, true) ~= nil)
check("Today 0/3, my gold, Share 1,000 gold", cl.Today == string.format(VF.Text.Today, 0, 3) and cl.Gold == "Your gold: 2,500"
	and cl.Give == string.format(VF.Text.Halo.Give, "1,000") and UI.CardLines(with({ Faction = "Horns" })).Give
	== string.format(VF.Text.Horns.Give, "1,000")
	and cl.CanGive == true and cl.Reason == nil, cl.Today .. " | " .. cl.Gold .. " | " .. cl.Give)
check("the reason line is the server's own words", UI.CardLines(with({ Gold = 10 })).Reason == string.format(VF.Text.Poor, "1,000")
	and UI.CardLines(with({ Today = 3 })).Reason == string.format(VF.Text.Full, 3) and UI.CardLines(with({ Today = 3 })).CanGive == false
	and UI.CardLines(with({ Why = "Closed", Can = false })).Reason == VF.Text.Closed)
check("prompt words: the Config path in the key, unknown = empty", UI.Word("Config.VillageFund.Text.Halo.Prompt") == VF.Text.Halo.Prompt
	and UI.Word("Config.VillageFund.Text.Nope") == "" and UI.Word("Config.VillageFund.Text") == "" and UI.Word("x") == "" and UI.Word(nil) == "")
check("a Neutral / no-side state never gives", UI.CardLines(with({ Faction = "Neutral" })).CanGive == false
	and UI.CardLines(with({ Faction = false })).CanGive == false)
local b0, b1, b2 = UI.BarParts(0, base.Goals), UI.BarParts(30000, base.Goals), UI.BarParts(150000, base.Goals)
check("bar: empty / lanterns at 30% / full at fireworks", b0.Fill == 0 and b0.Level == 0 and math.abs(b1.Fill - 0.3) < 1e-9
	and b1.Level == 1 and b1.Mark == 0.3 and b2.Fill == 1 and b2.Level == 2)
check("bar: the config goals when the state has none", UI.BarParts(VF.Goals.Lanterns, nil).Level == 1)
check("prompt: only my own side's", UI.PromptOn("Halo", "Halo") and UI.PromptOn("Horns", "Horns") and not UI.PromptOn("Horns", "Halo")
	and not UI.PromptOn("Halo", "Neutral") and not UI.PromptOn("Halo", nil) and not UI.PromptOn(nil, "Halo"))
local p1, p2d, p2n, pp = UI.FxPlan(1, "Night", false, false), UI.FxPlan(2, "Day", false, false), UI.FxPlan(2, "Night", false, false),
	UI.FxPlan(2, "Night", true, false)
check("town: lanterns from level 1, fireworks only level 2 at night", p1.Lanterns and not p1.Fireworks and p2d.Lanterns
	and not p2d.Fireworks and p2n.Fireworks and not UI.FxPlan(0, "Night", false, false).Lanterns)
check("town: phones get fewer lanterns and particles", pp.Lights < p2n.Lights and pp.Mult < 1 and p2n.Mult == 1
	and UI.FxPlan(1, "Day", false, true).Mult < 1)

-- 2) the fountain prompts
check("my side's prompt stays on, the other side's goes off", haloPrompt.Enabled == true and hornsPrompt.Enabled == false,
	tostring(haloPrompt.Enabled) .. "/" .. tostring(hornsPrompt.Enabled))
check("other prompts are not touched", otherPrompt.Enabled == true)
check("the prompt's words come from its keys", haloPrompt.ActionText == VF.Text.Halo.Prompt and haloPrompt.ObjectText == VF.Text.Title
	and hornsPrompt.ActionText == "", haloPrompt.ActionText)
setAttr("Faction", "Horns")
check("a side switch swaps them (Horns found by its fountain spot)", haloPrompt.Enabled == false and hornsPrompt.Enabled == true)
setAttr("Faction", "Neutral")
check("Neutral: every fund prompt off", haloPrompt.Enabled == false and hornsPrompt.Enabled == false)
setAttr("Faction", "Halo")
local late = inst("ProximityPrompt")
late.Name, late.Enabled, late.Attrs = "FundPrompt", true, { Faction = "Horns" }
add(late, hornsPart)
check("a prompt made later is set too", late.Enabled == false and haloPrompt.Enabled == true)

-- 3) the card
open(with({ Faction = "Neutral" }))
open(nil)
check("broken / no-side states open nothing", CURRENT == nil and OPENS == 0)
open(base)
check("FundOpen opens the card", CURRENT == "VillageFund" and OPENS == 1 and UI.State() ~= nil)
check("the card reads the lines", hasText(BODY, "Today 0/3") and hasText(BODY, "Your gold: 2,500") and give()
	and give().Text == string.format(VF.Text.Halo.Give, "1,000")
	and hasText(BODY, SCR.Close), table.concat(texts(BODY or inst("Frame")), " | "))
check("[Give] is on, no reason line", ENABLED[give()] == true and label("Reason").Visible == false)
check("the weekly bar: the state's Sum until the attributes come (not the week number)", math.abs((BAR.Fraction or -1) - 0.12) < 1e-9
	and hasText(BODY, "Town this week: 12,000 gold"), BAR.Fraction)
check("the lantern mark sits at 30%", label("LanternMark") and label("LanternMark").Position[1] == 0.3)
give().Click()
check("[Give] fires FundGive with no arguments", fundFired() == 1 and FIRED[#FIRED][2] == 0, FIRED[#FIRED] and FIRED[#FIRED][2])
check("... and locks until the answer", ENABLED[give()] == false)
T.Give() -- a second press that skips the button (double input): the module's own Wait still holds
check("a second press within Wait sends nothing (module guard)", fundFired() == 1, fundFired())
give().Click()
CLOCK += 0.5
give().Click()
check("no second gift before the answer / Wait", fundFired() == 1, fundFired())
open(with({ Today = 1, Gold = 1500 }))
check("the answer redraws the open card in place", OPENS == 1 and CURRENT == "VillageFund" and hasText(BODY, "Today 1/3")
	and hasText(BODY, "Your gold: 1,500") and ENABLED[give()] == true)
give().Click()
CLOCK += 1.1
T.Step(CLOCK)
check("no answer within Wait: [Give] unlocks", ENABLED[give()] == true and fundFired() == 2)
open(with({ Today = 2, Gold = 500 }))
check("poor: [Give] grey + the server's Poor line", ENABLED[give()] == false and label("Reason").Visible == true
	and label("Reason").Text == string.format(VF.Text.Poor, "1,000"))
give().Click()
check("a grey [Give] sends nothing", fundFired() == 2)
open(with({ Today = 3, Gold = 5000 }))
check("3 today: [Give] grey + the server's Full line", ENABLED[give()] == false and label("Reason").Text == string.format(VF.Text.Full, 3))
open(with({ Today = 0, Gold = 5000, Can = false, Why = "Closed" }))
check("the fund switched off: [Give] grey + Closed", ENABLED[give()] == false and label("Reason").Text == VF.Text.Closed)
setRS("FundHalo", 45000)
check("the bar follows FundHalo live", math.abs((BAR.Fraction or -1) - 0.45) < 1e-9 and hasText(BODY, "Town this week: 45,000 gold"),
	BAR.Fraction)
check("the goal marks are named", hasText(BODY, SCR.Lanterns .. " 30,000") and hasText(BODY, SCR.Fireworks .. " 100,000"))
local closeBtn = BODY:FindFirstChild("CloseButton", true)
closeBtn.Click()
check("[Close] closes it", CURRENT == nil)
open(with({ Today = 0, Gold = 5000 }))
root.Position = HALO.Pos + v3(HALO.Radius + 10, 0, 0)
T.Step(CLOCK)
check("walking away from the fountain closes the card", CURRENT == nil)
root.Position = HALO.Pos
open(with({ Today = 0, Gold = 5000 }))
setAttr("Faction", "Horns")
check("a side switch closes my old side's card", CURRENT == nil)
setAttr("Faction", "Halo")
-- MINOR ①: [Give] follows my KO / distance while the card is open
root.Position = HALO.Pos
open(with({ Today = 0, Gold = 5000 }))
hum.Health = 0
T.Step(CLOCK)
check("knocked out: [Give] grey + the server's Closed line", ENABLED[give()] == false and label("Reason").Text == VF.Text.Closed,
	label("Reason") and label("Reason").Text)
hum.Health = 100
T.Step(CLOCK)
check("back on my feet: [Give] on again", ENABLED[give()] == true and label("Reason").Visible == false)
root.Position = HALO.Pos + v3(HALO.Radius + 3, 0, 0)
T.Step(CLOCK)
check("past the fountain's reach (card still open): [Give] grey + 'Walk up'", CURRENT == "VillageFund" and ENABLED[give()] == false
	and label("Reason").Text == SCR.Far, label("Reason") and label("Reason").Text)
give().Click()
T.Give()
check("a gift from too far sends nothing", fundFired() == 2, fundFired())
root.Position = HALO.Pos
T.Step(CLOCK)
check("walking back: [Give] on", ENABLED[give()] == true)
closeBtn = BODY:FindFirstChild("CloseButton", true)
closeBtn.Click()
-- FIX 1: a prompt that fell out of the table (it was switched off before I had a side) is found again on a side change
T.S.Prompts[haloPrompt] = nil
haloPrompt.Enabled = false
setAttr("Faction", "Horns")
setAttr("Faction", "Halo")
check("a side pick finds a prompt the table lost and turns it on", haloPrompt.Enabled == true and T.S.Prompts[haloPrompt] == "Halo")
check("the prompt table holds its prompts (not weak)", getmetatable(T.S.Prompts) == nil)

-- 4) the town glow
setRS("FundLevelHalo", 1)
GS.Attrs.DayPhase = "Night"
T.Step(CLOCK)
local fxf = WS:FindFirstChild("VillageFundFx")
local town = fxf and fxf:FindFirstChild("Halo")
local lanterns, lit, safe = 0, 0, true
for _, c in town and town.Children or {} do
	if string.sub(c.Name, 1, 7) == "Lantern" then
		lanterns += 1
		if c:FindFirstChildOfClass("PointLight") and c:FindFirstChild("Glow") then lit += 1 end
		safe = safe and c.Anchored == true and c.CanCollide == false and c.CanQuery == false and c.CanTouch == false
	end
end
check("level 1: a ring of lanterns over my fountain", lanterns == 8 and lit == 8, lanterns .. " / " .. lit)
check("the lanterns are ghosts (anchored, no collision / queries / touch)", safe)
local burstPart = town and town:FindFirstChild("Fireworks")
check("level 1 at night: no fireworks", burstPart and (burstPart:FindFirstChild("Stars").Emitted or 0) == 0)
check("Horns town at level 0 shows nothing", fxf and fxf:FindFirstChild("Horns") == nil)
setRS("FundLevelHalo", 2)
T.Step(CLOCK)
local stars, confetti = burstPart:FindFirstChild("Stars"), burstPart:FindFirstChild("Confetti")
check("level 2 at night: a burst of stars and confetti", (stars.Emitted or 0) > 0 and (confetti.Emitted or 0) > 0)
check("the fireworks sit high over the fountain", burstPart.Position.Y == HALO.Pos.Y + T.L.Firework.Up)
local s1 = stars.Emitted
T.Step(CLOCK + 0.5)
check("one burst every few seconds, not every poll", stars.Emitted == s1)
T.Step(CLOCK + 5)
check("... and the next one comes", stars.Emitted > s1)
GS.Attrs.DayPhase = "Day"
local s2 = stars.Emitted
T.Step(CLOCK + 20)
check("level 2 by day: lanterns, no fireworks", stars.Emitted == s2 and town.Parent ~= nil)
UIS.TouchEnabled, UIS.KeyboardEnabled = true, false
T.Step(CLOCK + 21)
local pt = fxf:FindFirstChild("Halo")
local plights = 0
for _, c in pt and pt.Children or {} do if string.sub(c.Name, 1, 7) == "Lantern" then plights += 1 end end
local glow = pt and pt:FindFirstChild("Lantern1") and pt:FindFirstChild("Lantern1"):FindFirstChild("Glow")
check("a phone: fewer lanterns, softer glow", plights == T.L.Lantern.PhoneCount and glow and glow.Rate < T.L.Lantern.Rate,
	plights .. " / " .. tostring(glow and glow.Rate))
UIS.TouchEnabled, UIS.KeyboardEnabled = false, true
setRS("FundLevelHalo", 0)
T.Step(CLOCK + 22)
check("a new week (level 0): the lanterns go", fxf:FindFirstChild("Halo") == nil)
setRS("FundLevelHorns", 1)
T.Step(CLOCK + 23)
check("the other side's town lights up too (anyone walking in sees it)", fxf:FindFirstChild("Horns") ~= nil)
-- 개발 2 07ca5b92: the spot = the server's FundSpot part (the fountain model's pivot + Lift), not Config Pos
setRS("FundLevelHalo", 1)
T.Step(CLOCK + 29)
local before = fxf:FindFirstChild("Halo") and fxf:FindFirstChild("Halo"):FindFirstChild("Fireworks")
check("before the server's part: the lanterns stand on Config Pos", before and before.Position.X == HALO.Pos.X)
local vf = inst("Folder")
vf.Name = "VillageFund"
local spotPart = inst("Part")
spotPart.Name = "FundSpot_Halo"
spotPart.Position = HALO.Pos + v3(40, HALO.Lift, 0)
spotPart.Parent = vf
add(vf, WS)
setRS("FundLevelHalo", 1)
T.Step(CLOCK + 30)
local moved = fxf:FindFirstChild("Halo")
local fw = moved and moved:FindFirstChild("Fireworks")
check("the lanterns follow the server's fountain spot", fw and fw.Position.X == HALO.Pos.X + 40 and fw.Position.Y == HALO.Pos.Y + T.L.Firework.Up,
	fw and (fw.Position.X .. "," .. fw.Position.Y))
root.Position = HALO.Pos + v3(41, 0, 0)
open(with({ Today = 0, Gold = 5000 }))
T.Step(CLOCK + 31)
check("the reach is measured from the server's spot", CURRENT == "VillageFund" and ENABLED[give()] == true, label("Reason") and label("Reason").Text)
root.Position = HALO.Pos
T.Step(CLOCK + 32)
check("... and the card closes away from it (Config Pos is only the fallback)", CURRENT == nil)

print(("VILLAGE_FUND_UI_SUMMARY checks=%d failed=%d contract=%s"):format(checks, failed, tostring(CONTRACT)))
