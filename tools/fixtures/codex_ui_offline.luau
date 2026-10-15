-- tools/fixtures/codex_ui_offline.luau : runs the real Config.luau (CONFIG_SOURCE) and the real CodexUI.luau (CODEX_SOURCE),
-- put in front by tools/test_codex_ui.py, on small doubles: an Instance tree with signals, Players.LocalPlayer
-- attributes, a Net with remotes, a Panels that builds a registered window, a UIKit with the art parts, a TweenService that
-- finishes at once, task.delay / task.defer queues run by hand, a RenderStepped fired by hand. No Studio, no models (the
-- 3D monster and the camera are checked in Studio photos: tools/play_codex_photos.py). Every check is named and counted.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if ok then
		print("CHECK_OK " .. name)
	else
		failed += 1
		print("CHECK_FAIL " .. name .. (detail ~= nil and (" :: " .. tostring(detail)) or ""))
	end
end

------------------------------------------------------------------ values
local vmt = {}
vmt.__index = vmt
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, vmt) end
local v2mt = {}
v2mt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y) end
	return v2mt[k]
end
local function v2(x, y) return setmetatable({ X = x or 0, Y = y or 0, __type = "Vector2" }, v2mt) end
local function rgb(r, g, b) local c = vec(r, g, b); c.__type = "Color3"; return c end
function v2mt.Lerp(a, b, t) return v2(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t) end
v2mt.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
v2mt.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local Vector2 = { new = v2, zero = v2(0, 0) }
local base = { Vector3 = { new = vec, zero = vec(0, 0, 0), yAxis = vec(0, 1, 0) }, Vector2 = Vector2,
	Color3 = { new = function(r, g, b) return rgb(r, g, b) end, fromRGB = function(r, g, b) return rgb(r / 255, g / 255, b / 255) end,
		fromHSV = rgb }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"),
	ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
	Font = ctor("Font"), Enum = enum }
local cfgEnv = setmetatable(table.clone(base), { __index = getfenv() })
cfgEnv.workspace = { GetServerTimeNow = function() return 1790000000 end }
local cfgFn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(cfgFn, cfgEnv)
local Config = cfgFn()

------------------------------------------------------------------ signals + an Instance tree
local live = {} -- [signal name] = connections not yet disconnected (RenderStepped, InputEnded ...)
local function signal(tag)
	local s = { fns = {} }
	function s:Connect(fn)
		local c = { on = true }
		if tag then live[tag] = (live[tag] or 0) + 1 end
		table.insert(self.fns, { c = c, fn = fn })
		function c:Disconnect()
			if self.on then
				self.on = false
				if tag then live[tag] -= 1 end
			end
		end
		return c
	end
	function s:Fire(...)
		for _, e in table.clone(self.fns) do
			if e.c.on then e.fn(...) end
		end
	end
	return s
end
local ISA = {
	Frame = { "GuiObject", "GuiBase2d" }, ImageLabel = { "GuiObject", "GuiBase2d" }, TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiObject", "GuiButton", "GuiBase2d" }, ImageButton = { "GuiObject", "GuiButton", "GuiBase2d" },
	ViewportFrame = { "GuiObject", "GuiBase2d" }, ScreenGui = { "LayerCollector", "GuiBase2d" }, Folder = {}, Model = {},
}
local SIGNALS = { InputBegan = true, InputChanged = true, InputEnded = true, MouseLeave = true, MouseEnter = true,
	Activated = true, MouseMoved = true, Completed = true, OnClientEvent = true }
local omt = {}
local function newObj(class, props)
	local o = setmetatable({ __p = { ClassName = class, Name = class, Children = {}, Attrs = {}, Signals = {}, ZIndex = 1,
		Visible = true, AbsoluteSize = v2(230, 310), AbsolutePosition = v2(100, 100) } }, omt)
	for k, v in props or {} do o[k] = v end
	return o
end
local METHODS = {}
function METHODS.GetChildren(self) return table.clone(rawget(self, "__p").Children) end
function METHODS.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, ch in rawget(o, "__p").Children do
			table.insert(out, ch)
			walk(ch)
		end
	end
	walk(self)
	return out
end
function METHODS.Destroy(self)
	local p = rawget(self, "__p")
	if p.Parent then
		local kids = rawget(p.Parent, "__p").Children
		local i = table.find(kids, self)
		if i then table.remove(kids, i) end
	end
	p.Parent = nil
	p.Destroyed = true
end
function METHODS.FindFirstChild(self, name, deep)
	for _, ch in rawget(self, "__p").Children do
		if ch.Name == name then return ch end
	end
	if deep then
		for _, ch in rawget(self, "__p").Children do
			local f = ch:FindFirstChild(name, true)
			if f then return f end
		end
	end
	return nil
end
function METHODS.IsA(self, cls)
	local class = rawget(self, "__p").ClassName
	if class == cls or cls == "Instance" then return true end
	return table.find(ISA[class] or {}, cls) ~= nil
end
function METHODS.FindFirstChildOfClass(self, cls)
	for _, ch in rawget(self, "__p").Children do
		if ch.ClassName == cls then return ch end
	end
	return nil
end
function METHODS.FindFirstAncestorWhichIsA(self, cls)
	local p = rawget(self, "__p").Parent
	while p do
		if p:IsA(cls) then return p end
		p = rawget(p, "__p").Parent
	end
	return nil
end
function METHODS.SetAttribute(self, k, v) rawget(self, "__p").Attrs[k] = v end
function METHODS.GetAttribute(self, k) return rawget(self, "__p").Attrs[k] end
function METHODS.WaitForChild(self, name) return self:FindFirstChild(name) end
function METHODS.GetPropertyChangedSignal(self, prop)
	local p = rawget(self, "__p")
	p.Changed = p.Changed or {}
	p.Changed[prop] = p.Changed[prop] or signal("Changed")
	return p.Changed[prop]
end
omt.__index = function(o, k)
	if METHODS[k] then return METHODS[k] end
	local p = rawget(o, "__p")
	if SIGNALS[k] then
		p.Signals[k] = p.Signals[k] or signal()
		return p.Signals[k]
	end
	return p[k]
end
omt.__newindex = function(o, k, v)
	local p = rawget(o, "__p")
	if k == "Parent" then
		if p.Parent then
			local kids = rawget(p.Parent, "__p").Children
			local i = table.find(kids, o)
			if i then table.remove(kids, i) end
		end
		p.Parent = v
		if v then table.insert(rawget(v, "__p").Children, o) end
		return
	end
	p[k] = v
end

------------------------------------------------------------------ services
local DELAYS, DEFERS, WAITS = {}, {}, {} -- task.delay / task.defer / coroutines waiting in task.wait
local function runWaits()
	local list = WAITS
	WAITS = {}
	for _, co in list do
		local ok, err = coroutine.resume(co)
		if not ok then error(err) end
		if coroutine.status(co) == "suspended" then table.insert(WAITS, co) end
	end
end
local function runDelays()
	local list = DELAYS
	DELAYS = {}
	for _, d in list do d() end
end
local function runDefers()
	for _ = 1, 50 do
		if #DEFERS == 0 then return end
		local list = DEFERS
		DEFERS = {}
		for _, d in list do d() end
	end
end
local player = newObj("Player", { Name = "Tester", UserId = 1 })
player:SetAttribute("Faction", "Halo")
local Players = { LocalPlayer = player }
local remotes, fired = {}, {}
local Net = {
	Get = function(name)
		remotes[name] = remotes[name] or { OnClientEvent = signal(), FireServer = function(_, ...)
			table.insert(fired, { name, ... })
		end }
		return remotes[name]
	end,
}
local warns = {}
local Util = {
	Warn = function(tag, msg) table.insert(warns, tostring(tag) .. ": " .. tostring(msg)) end,
	FormatInt = function(n)
		n = math.floor((tonumber(n) or 0) + 0.5)
		local s = tostring(math.abs(n))
		local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1,")))
		if string.sub(out, 1, 1) == "," then out = string.sub(out, 2) end
		return (n < 0 and "-" or "") .. out
	end,
}
local shared = newObj("Folder", { Name = "Shared" })
for _, n in { "Config", "Net", "Util" } do newObj("ModuleScript", { Name = n, Parent = shared }) end
local MODS = { Config = Config, Net = Net, Util = Util }
local RS = newObj("Folder", { Name = "ReplicatedStorage" })
shared.Parent = RS
local render = signal("RenderStepped")
local RunService = { RenderStepped = render, IsStudio = function() return false end }
local UIS = { InputEnded = signal("InputEnded"), InputChanged = signal("UISChanged") }
local tweens = 0
local TweenService = { Create = function(_, obj, _, props)
	local tw = { Completed = signal() }
	function tw:Play()
		tweens += 1
		for k, v in props do obj[k] = v end
		self.Completed:Fire()
	end
	return tw
end }
local GuiService = { GetGuiInset = function() return v2(0, 36) end }
local workspaceObj = newObj("Workspace")
local game = { GetService = function(_, name)
	return ({ Players = Players, ReplicatedStorage = RS, RunService = RunService, TweenService = TweenService,
		UserInputService = UIS, GuiService = GuiService })[name]
end }

------------------------------------------------------------------ UIKit + Panels
local reduced, hold = false, false
local toasts, popups = {}, {}
local ARTIDS = { IconMonSlime = "rbxassetid://1", IconMonGoblin = "rbxassetid://2" }
local gui = newObj("ScreenGui", { Name = "MainGui", IgnoreGuiInset = true })
local uiScale = newObj("UIScale", { Name = "UIScale", Scale = 1, Parent = gui })
local bodyAbs = v2(684, 480) -- the body's AbsoluteSize (real px) Panels gives the window
local function apply(o, props, skip)
	for k, v in props or {} do
		if not (skip and skip[k]) then o[k] = v end
	end
	return o
end
local UIKit = {
	Gui = gui,
	ArtFrame = function(name, props) return apply(newObj("ImageLabel", { Part = name }), props, { Parent = true }), true end,
	ArtImage = function(name, props) return apply(newObj("ImageLabel", { Part = name }), props) end,
	ArtButton = function(name, props, onClick)
		local b = apply(newObj("ImageButton", { Part = name }), props, { Text = true, TextSize = true, Parent = true })
		local label = newObj("TextLabel", { Name = "Label", Text = props.Text, Parent = b })
		b.Activated:Connect(function() onClick(b) end)
		if props.Parent then b.Parent = props.Parent end
		return b, label, true
	end,
	InkText = function(props) return apply(newObj("TextLabel", { Ink = true }), props) end,
	LightText = function(props) return apply(newObj("TextLabel", { Light = true }), props) end,
	Toast = function(text, kind) table.insert(toasts, { Text = text, Kind = kind }) end,
	RewardPopup = function(opts)
		local f = newObj("Frame", { Name = "RewardPopup", Parent = gui })
		table.insert(popups, opts)
		return { Frame = f, Close = function() f:Destroy() end }
	end,
	ReducedMotion = function() return reduced end,
	ShouldHoldBanners = function() return hold end,
	ArtId = function(name) return ARTIDS[name] end,
}
local REG, opened = {}, nil
local KIT = {
	Button = function(parent, text, _, size, fn)
		local b = newObj("TextButton", { Text = text, Size = size, Parent = parent })
		b.Activated:Connect(fn)
		return b
	end,
	Paint = function(b, bg) b.Painted = bg end,
	Theme = { Gold = "gold", Text = "text", SubText = "sub" }, Palette = { Button = "btn", DarkText = "dark" }, Font = "font",
}
local Panels = {
	CurrentId = function() return opened and opened.Id or nil end,
	Register = function(id, opts)
		REG[id] = opts
		return true
	end,
	Open = function(id, arg)
		local opts = REG[id]
		if not opts then return false end
		if opened then Panels.Close() end
		local root = newObj("Frame", { Name = "Content", Parent = gui, AbsoluteSize = bodyAbs })
		opened = { Id = id, Root = root }
		opts.Build(root, KIT, arg)
		return true
	end,
	Close = function()
		if not opened then return end
		REG[opened.Id].Cleanup()
		opened.Root:Destroy()
		opened = nil
	end,
}

------------------------------------------------------------------ load CodexUI
local realTypeof = typeof
local env = setmetatable({ game = game, workspace = workspaceObj, Instance = { new = function(c) return newObj(c) end },
	typeof = function(v)
		if type(v) == "table" and rawget(v, "__type") then return rawget(v, "__type") end
		return realTypeof(v)
	end,
	require = function(m) return MODS[m.Name] end,
	task = { delay = function(_, fn) table.insert(DELAYS, fn) end, defer = function(fn) table.insert(DEFERS, fn) end,
		spawn = function(fn)
			local co = coroutine.create(fn)
			local ok, err = coroutine.resume(co)
			if not ok then error(err) end
			if coroutine.status(co) == "suspended" then table.insert(WAITS, co) end
		end,
		wait = function() coroutine.yield() end } }, { __index = function(_, k)
	if base[k] ~= nil then return base[k] end
	return getfenv()[k]
end })
local codexFn = assert(loadstring(CODEX_SOURCE, "=CodexUI"))
setfenv(codexFn, env)
local CodexUI = codexFn()
local T = CodexUI._T
local plays = {}
local C = { UIKit = UIKit, Panels = Panels, Audio = { Play = function(e) table.insert(plays, e) end } }
CodexUI.Init(C)
check(REG.Codex ~= nil and REG.Codex.FixedBody == true and REG.Codex.Width == T.L.Width and type(REG.Codex.Cleanup) == "function",
	"Init: the Panels window 'Codex' (fixed body, its width, a cleanup)")
check(type(REG.Codex.Title) == "function" and REG.Codex.Title() == "Monster Codex · 0/11 cards",
	"the window title = Config.Codex.Text.Name + my count", REG.Codex.Title and REG.Codex.Title())
CodexUI.Start()
check(remotes.Codex ~= nil and remotes.CodexUp ~= nil, "Start listens to 'Codex' and 'CodexUp'")
check(Config.Codex.ServerToast == false, "Config.Codex.ServerToast is off (the lines come from the screen)")

------------------------------------------------------------------ pure parts
local t0 = os.time({ year = 2026, month = 10, day = 13, hour = 12 })
local v = CodexUI.View("Slime", nil, "Halo")
check(v.Known == false and v.Stage == 0 and v.Look == "None" and v.Name == "???" and v.KillsText == "Not met yet"
	and v.Lore == "" and v.NextText == "" and v.DropsText == "", "a card not met: ???, no story, no drops", v.Name)
v = CodexUI.View("Slime", { Kills = 1, Golden = 0, Stage = 1, First = t0 }, "Halo")
check(v.Known and v.StageName == "Card" and v.Look == "Card" and v.Name == "Shard Slime" and v.KillsText == "Defeated: 1"
	and v.NextText == "Silver at 100", "Slime, 1 kill: Card, its name, 'Silver at 100'", v.NextText)
check(v.Lore == Config.Codex.Lore.Slime.Halo, "the back speaks with my side's voice (Halo)", v.Lore)
check(v.Where == "Found in: Squishy Meadow", "where it lives = its zone's name", v.Where)
check(v.DropsText == "Drops: Jelly", "drops = its materials only (no scrolls / potions)", v.DropsText)
check(v.FirstText == "First met: Oct 13, 2026", "the first day", v.FirstText)
v = CodexUI.View("Slime", { Kills = 150, Golden = 0, Stage = 1, First = 0 }, "Horns")
check(v.Stage == 2 and v.Look == "Silver" and v.NextText == "Gold Holo at 1,000" and v.Lore == Config.Codex.Lore.Slime.Horns,
	"150 kills read as Silver even if the stage says 1; 'Gold Holo at 1,000'; the Horns voice", v.NextText)
check(v.FirstText == "First met: Before the Codex", "an old card's day = 'Before the Codex'", v.FirstText)
v = CodexUI.View("Slime", { Kills = 1000, Golden = 0, Stage = 3 }, nil)
check(v.Look == "Holo" and v.NextText == "Top stage!" and v.Lore == Config.Codex.Lore.Slime.Neutral,
	"1000 kills: Gold Holo, top stage; no side = the Neutral voice", v.NextText)
v = CodexUI.View("SlimeKing", { Kills = 10, Golden = 3, Stage = 2 }, "Halo", true)
check(v.Boss and v.Stage == 2 and v.NextText == "Gold Holo at 30" and v.HasFoil == false and v.Foil == false and v.Look == "Silver",
	"a boss: 1 / 10 / 30 steps, never a Gold Foil card", v.NextText)
v = CodexUI.View("SlimeKing", { Kills = 1, Golden = 0, Stage = 1 }, "Halo")
local drops = table.concat(v.Drops, ",")
check(string.find(drops, "Royal Jelly", 1, true) and string.find(drops, "Slime Core", 1, true) and not string.find(drops, "Scroll", 1, true),
	"the King Slime's drops (Royal Jelly, Slime Core ...)", drops)
v = CodexUI.View("Goblin", { Kills = 5, Golden = 1, Stage = 1 }, "Halo", true)
check(v.HasFoil and v.Foil and v.Look == "Foil" and v.StageName == "Gold Foil", "a golden one beaten: the Gold Foil card", v.StageName)
v = CodexUI.View("Goblin", { Kills = 5, Golden = 0, Stage = 1 }, "Halo", true)
check(not v.HasFoil and not v.Foil and v.Look == "Card", "no golden one yet: asking for the foil shows the card")
check(CodexUI.Date(0) == "Before the Codex" and CodexUI.Date(nil) == "Before the Codex", "Date(0 / nil) = Before the Codex")
local p1 = CodexUI.Page({ Slime = { Kills = 3, Golden = 0, Stage = 1 }, BigSlime = { Kills = 1, Stage = 1 } }, 1)
check(p1 and p1.Name == "Squishy Meadow" and p1.Total == 4 and p1.Owned == 2 and not p1.Done, "page 1: the meadow, 2 of 4",
	p1 and (p1.Name .. " " .. p1.Owned .. "/" .. p1.Total))
check(CodexUI.Page({}, 4) == nil, "no page 4 in series 1")
local owned, total = CodexUI.Count({ Slime = { Kills = 3, Stage = 1 }, Goblin = { Kills = 1, Stage = 1 }, Bogus = { Kills = 9 } })
check(owned == 2 and total == 11, "count: 2 / 11 (an unknown kind is not a card)", owned .. "/" .. total)
local x, y = CodexUI.Tilt(2, 0)
check(x == 1 and y == 0, "tilt clamps to -1..1")
x, y = CodexUI.Tilt(1, 1)
check(math.abs(math.sqrt(x * x + y * y) - 1) < 1e-9, "tilt stays inside the circle")
check(CodexUI.MomentOf("Card") == "Reveal" and CodexUI.MomentOf("Golden") == "Reveal" and CodexUI.MomentOf("Silver") == "Evolve"
	and CodexUI.MomentOf("Holo") == "Evolve" and CodexUI.MomentOf("Page") == "Popup" and CodexUI.MomentOf("Glow") == "Popup"
	and CodexUI.MomentOf("Bogus") == nil, "moments: Card / Golden reveal, Silver / Holo evolve, Page / Glow popup")
local q = {}
for i = 1, 12 do CodexUI.Push(q, { Event = "Card", Kind = "Slime", N = i }) end
CodexUI.Push(q, { Event = "Nope" })
CodexUI.Push(q, "bad")
check(#q == Config.Codex.Screen.Moment.Max and q[1].N == 5, "the queue keeps the newest " .. Config.Codex.Screen.Moment.Max, #q)
check(CodexUI.Fit(2, 30) > CodexUI.Fit(1, 30) and CodexUI.Fit(1, 30) > 0, "a bigger monster stands further from the camera")
-- the moment's card follows its event (a Studio show with the card's own lower stage)
local mcard = CodexUI.MomentCard({ Event = "Holo", Kind = "Slime", Card = { Kills = 12, Golden = 0, Stage = 1, First = t0 } })
check(mcard.Stage == 3 and mcard.Kills == 12, "a Holo moment draws Gold Holo even when its card says 1", mcard.Stage)
check(CodexUI.MomentCard({ Event = "Silver", Stage = 2 }, { Kills = 3, Stage = 1 }).Stage == 2, "a Silver moment: at least Silver")
check(CodexUI.MomentCard({ Event = "Golden", Card = { Kills = 4, Stage = 1 } }).Golden == 1, "a Golden moment owns its foil")
check(CodexUI.MomentCard({ Event = "Card", Card = { Kills = 1, Stage = 3 } }).Stage == 3, "never lowers a stage")
-- the moment's size: a big screen keeps it whole, a short one shrinks it to half its height
check(CodexUI.MomentFit(1053) == 1 and CodexUI.MomentFit(0) == 1, "a 1316 px screen (1053 du): the moment at full size")
local f520 = CodexUI.MomentFit(520)
check(f520 < 1 and (T.L.Moment.H + T.L.Moment.Line) * f520 <= 520 * T.L.Moment.Room + 1e-6, "a phone (520 du): the moment shrinks to half the height",
	f520)
-- every series-1 kind reads (name, zone, a story line per side)
local bad = {}
for _, kind in Config.Codex.Order do
	for _, side in { "Halo", "Horns", "Neutral" } do
		local w = CodexUI.View(kind, { Kills = 1, Stage = 1 }, side)
		if w.Name == "???" or w.Where == "Found in: " or w.Lore == "" then table.insert(bad, kind .. "/" .. side) end
	end
end
check(#bad == 0, "all 11 kinds: a name, a zone, a story line for each side", table.concat(bad, ","))

------------------------------------------------------------------ the layout (최종 검수 10/13 review)
local lay = CodexUI.Layout(604, 440)
check(lay.CardH > 310 and lay.SlotH > 168 and lay.TabW == 197, "a 604 x 440 body: the card and slots bigger than before, 197 tabs",
	lay.CardW .. "x" .. lay.CardH .. " " .. lay.SlotH .. " " .. lay.TabW)
local full = CodexUI.Layout(684, 480)
check(full.Top + full.RowY + T.L.ButtonH >= 480 - 2 and full.Top + 2 * full.SlotH + T.L.Gap >= 480 - 2 and full.TabW == 220,
	"the full window (684 x 480): the card row and the two slot rows reach the bottom (no empty half)",
	full.CardH .. "/" .. full.SlotH)
for _, ww in { 684, 604 } do
	for _, hh in { 560, 480, 404, 360, 330, 300 } do
		local l = CodexUI.Layout(ww, hh)
		local fits = l.Top + l.RowY + T.L.ButtonH <= hh and l.Top + 2 * l.SlotH + T.L.Gap <= hh
		check(fits and 3 * l.TabW + 2 * T.L.TabGap <= ww and l.LeftW + T.L.ColGap + l.RightW <= ww and l.CardW <= l.RightW
			and 3 * T.L.ButtonW + 12 <= l.RightW, "a body " .. ww .. " x " .. hh .. ": everything inside (buttons, both slot rows, columns)",
			l.CardW .. "x" .. l.CardH .. "/" .. l.SlotH)
		check(math.abs(l.CardW / l.CardH - 230 / 310) < 0.01, "a body " .. ww .. " x " .. hh .. ": the card keeps its shape")
	end
end
local ll = CodexUI.Layout(0, 0)
check(ll.CardH == CodexUI.Layout(684, 470).CardH, "a body not laid out yet: the PC size")
-- the zone names fit a tab at a 720p PC floor (18 real px / UIScale 0.8 = 22.5 du, ~0.58 em a letter in GothamBold - the
-- 720p main photo is the real check)
local longest = 0
for _, page in Config.Codex.Pages do longest = math.max(longest, #Config.Zones[page.Id].Name) end
check(longest * 0.65 * 22.5 <= CodexUI.Layout(684, 480).TabW - 8, "the longest zone name fits its tab at a 720p floor", longest)

------------------------------------------------------------------ data + the window
remotes.Codex.OnClientEvent:Fire({ V = 1, Cards = { Slime = { Kills = 12, Golden = 0, Stage = 1, First = t0 }, Bogus = { Kills = 5 } },
	Glow = false })
check(T.S.Cards.Slime and T.S.Cards.Slime.Kills == 12 and T.S.Cards.Bogus == nil, "the snapshot is repaired (only series-1 kinds)")
Panels.Open("Codex")
local opens = 0
for _, f in fired do if f[1] == "CodexOpen" then opens += 1 end end
check(opens == 1, "opening the window asks for my codex (CodexOpen)", opens)
Panels.Close()
Panels.Open("Codex")
opens = 0
for _, f in fired do if f[1] == "CodexOpen" then opens += 1 end end
check(opens == 1, "opened again at once: no second CodexOpen (rate gap)", opens)
local VIEW = T.VIEW
local slots = 0
for _, ch in VIEW.Grid:GetChildren() do if string.sub(ch.Name, 1, 4) == "Slot" then slots += 1 end end
check(slots == 4, "page 1 shows its 4 cards", slots)
check(REG.Codex.Title() == "Monster Codex · 1/11 cards", "the title counts my cards", REG.Codex.Title())
check(#VIEW.Tabs == 3 and VIEW.Tabs[1].Text == "Squishy Meadow" and VIEW.Tabs[1].Painted == "gold", "3 zone tabs, the open one gold")
local big = VIEW.Big
check(T.S.Kind == "Slime" and big.NameText.Text == "Shard Slime" and big.KillsText.Text == "Defeated: 12", "the big card = Slime",
	big.NameText.Text)
check(big.ViewFrame.ImageColor3.X == 1 and big.Icon.Visible == true and big.Icon.Image == "rbxassetid://1",
	"a met card in colour; no model -> the approved IconMonSlime picture")
check(big.StageText.Text == "Card" and big.Sheen.Visible == false and big.FrontRim.Color == Config.Codex.Screen.Rim.Card,
	"Card stage: the Card rim, no sheen")
-- the other slots: silhouettes
local bigSlime = VIEW.Grid:FindFirstChild("SlotBigSlime")
check(bigSlime ~= nil and bigSlime.Part == "SlotEmpty", "a card not met sits in SlotEmpty")
-- a tab
VIEW.Tabs[2].Activated:Fire()
slots = 0
for _, ch in VIEW.Grid:GetChildren() do if string.sub(ch.Name, 1, 4) == "Slot" then slots += 1 end end
check(slots == 3 and T.S.Kind == "Goblin" and VIEW.Tabs[2].Painted == "gold", "tab 2: the woods' 3 cards, the first chosen", slots)
check(VIEW.Big.ViewFrame.ImageColor3.X == 0 and VIEW.Big.NameText.Text == "???", "a card not met: black silhouette, ???")
-- flip: not on an unknown card
local function click(c)
	local input = { UserInputType = "UserInputType.MouseButton1", Position = v2(150, 150) }
	c.Holder.InputBegan:Fire(input)
	UIS.InputEnded:Fire(input)
end
click(VIEW.Big)
check(T.S.Back == false and VIEW.Big.BackPlate.Visible == false, "an unknown card does not turn over")
VIEW.Tabs[1].Activated:Fire()
click(VIEW.Big)
check(T.S.Back == true and VIEW.Big.BackPlate.Visible == true and VIEW.Big.FrontPlate.Visible == false
	and VIEW.Big.Lines.Lore.Text == Config.Codex.Lore.Slime.Halo, "a click turns the card: the back with my side's line")
check(VIEW.Buttons.FlipText.Text == "Front", "[Flip] reads 'Front' on the back")
VIEW.Buttons.Flip.Activated:Fire()
check(T.S.Back == false and VIEW.Big.FrontPlate.Visible == true, "[Flip] turns it back")
-- tilt by the mouse
local c = VIEW.Big
c.Holder.InputChanged:Fire({ UserInputType = "UserInputType.MouseMovement", Position = v2(100 + 230, 100 - 36 + 155) })
check(c.Want.X > 0.99 and math.abs(c.Want.Y) < 0.02, "the mouse on the card's right edge tilts it right (the top bar inset counted)",
	c.Want.X .. "," .. c.Want.Y)
render:Fire(0.1)
check(c.Tilt.X > 0.3 and c.Tilt.X < 1, "the tilt eases toward the mouse", c.Tilt.X)
check(math.abs(c.FaceFrame.Rotation - c.Tilt.X * T.L.Tilt.Roll) < 1e-9, "a small roll follows the tilt")
c.Holder.MouseLeave:Fire()
check(c.Want.X == 0 and c.Want.Y == 0, "the mouse leaves: back to flat")
VIEW.Buttons.Tilt.Activated:Fire()
render:Fire(0.1)
check(T.S.Auto == true and (c.Want.X ~= 0 or c.Want.Y ~= 0), "[Auto tilt] sways it by itself")
VIEW.Buttons.Tilt.Activated:Fire()
-- a moment while the window is open: the card redrawn, the line a toast
remotes.CodexUp.OnClientEvent:Fire({ Event = "Silver", Kind = "Slime", Stage = 2, Card = { Kills = 100, Golden = 0, Stage = 2, First = t0 },
	Text = "Slime card is now Silver! +60 gold · +100 XP" })
check(#T.S.Queue == 0 and #toasts == 0, "window open: no moment and no toast (A23-191, user 10/14)", #toasts)
check(T.S.Cards.Slime.Stage == 2 and VIEW.Big.StageText.Text == "Silver" and VIEW.Big.Sheen.Visible == true,
	"window open: the card redrawn at Silver (sheen on)")
-- slots are kept: a flip, the foil, a choice and a fresh snapshot never build them again (최종 검수 10/13 review)
local function slotsNow()
	local out = {}
	for _, ch in VIEW.Grid:GetChildren() do if string.sub(ch.Name, 1, 4) == "Slot" then out[ch.Name] = ch end end
	return out
end
local before = slotsNow()
local function same(a, b)
	for k, v in a do if b[k] ~= v then return false end end
	for k, v in b do if a[k] ~= v then return false end end
	return true
end
VIEW.Buttons.Flip.Activated:Fire()
VIEW.Buttons.Flip.Activated:Fire()
check(same(before, slotsNow()), "a flip keeps the slots (no new 3D views)")
VIEW.Grid:FindFirstChild("SlotBigSlime").Activated:Fire()
check(same(before, slotsNow()) and T.S.Kind == "BigSlime" and VIEW.Slots.BigSlime.Rim.Thickness == 4
	and VIEW.Slots.Slime.Rim.Thickness == 2, "choosing a card keeps the slots, moves the gold rim")
VIEW.Grid:FindFirstChild("SlotSlime").Activated:Fire()
remotes.Codex.OnClientEvent:Fire({ V = 1, Cards = { Slime = { Kills = 13, Golden = 0, Stage = 1, First = t0 } }, Glow = false })
check(same(before, slotsNow()) and VIEW.Big.KillsText.Text == "Defeated: 13", "a fresh snapshot redraws in place", VIEW.Big.KillsText.Text)
remotes.Codex.OnClientEvent:Fire({ V = 1, Cards = { Slime = { Kills = 13, Golden = 0, Stage = 1, First = t0 },
	FlowerSlime = { Kills = 1, Golden = 0, Stage = 1, First = t0 } }, Glow = false })
local after = slotsNow()
check(after.SlotFlowerSlime ~= before.SlotFlowerSlime and after.SlotFlowerSlime.Part == "SlotCommon" and after.SlotSlime == before.SlotSlime,
	"a card just met: only its slot is made again (SlotCommon)")
-- the window in a 720p PC body (UIScale 0.8) and a phone held sideways, and when the body changes
uiScale.Scale = 0.8
local root = VIEW.Root
root.AbsoluteSize = v2(684 * 0.8, 404 * 0.8)
root:GetPropertyChangedSignal("AbsoluteSize"):Fire()
local want = CodexUI.Layout(684, 404)
local hs = VIEW.Big.Holder.Size
check(hs.Args[1] == want.CardW and hs.Args[2] == want.CardH and VIEW.Row.Position.Args[2] == want.RowY
	and VIEW.Tabs[1].Size.Args[2] == want.TabW, "a 720p body (UIScale 0.8): the card and its buttons sized to fit", tostring(hs.Args[2]))
uiScale.Scale = 0.75
root.AbsoluteSize = v2(684 * 0.75, 330 * 0.75)
root:GetPropertyChangedSignal("AbsoluteSize"):Fire()
want = CodexUI.Layout(684, 330)
check(VIEW.Big.Holder.Size.Args[2] == want.CardH and VIEW.GridLayout.CellSize.Args[2] == want.SlotH
	and want.Top + want.RowY + T.L.ButtonH <= 330, "a phone sideways (330 high): the buttons stay inside", want.CardH)
uiScale.Scale = 1
root.AbsoluteSize = v2(684, 480)
root:GetPropertyChangedSignal("AbsoluteSize"):Fire()
-- ⓑ one name: the slot says the card's own name
check(VIEW.Slots.Slime.Name.Text == "Shard Slime" and VIEW.Big.NameText.Text == "Shard Slime",
	"the slot and the big card say the same name", VIEW.Slots.Slime.Name.Text)
check(VIEW.Slots.Slime.Name.TextWrapped == true and VIEW.Slots.Slime.Name.TextScaled == false,
	"the slot's name wraps onto a second line (no 'Shard...')")
local flexItem = VIEW.Slots.Slime.Mini.Holder:FindFirstChildOfClass("UIFlexItem")
check(VIEW.Slots.Slime.Name.AutomaticSize == "AutomaticSize.Y" and flexItem ~= nil and flexItem.FlexMode == "UIFlexMode.Fill"
	and VIEW.Slots.Slime.Name.Parent == VIEW.Slots.Slime.Mini.Holder.Parent,
	"the slot's name box grows with its lines and the card takes the rest (main3: 'Goblin' hidden)")
-- ⓐ a hidden window (its frame not shown) is closed for the moments: the card moment comes, not a toast
root.Visible = false
local toastsBefore = #toasts
remotes.CodexUp.OnClientEvent:Fire({ Event = "Silver", Kind = "BigSlime", Stage = 2, Card = { Kills = 100, Golden = 0, Stage = 2, First = t0 },
	Text = "Slime Prince card is now Silver!", Debug = true })
check(#toasts == toastsBefore and #T.S.Queue == 1, "a hidden window: the moment waits its turn (no toast)", #T.S.Queue)
table.clear(T.S.Queue)
root.Visible = true
-- the chime: the open window's toast rang it
check(#plays == 1 and plays[1] == "QuestDone", "the open window's reward toast rings QuestDone", #plays)
-- closing lets go of everything
Panels.Close()
check((live.RenderStepped or 0) == 0 and (live.InputEnded or 0) == 0 and (live.Changed or 0) == 0 and T.VIEW.Root == nil,
	"closing disconnects the motion, input and size watch", tostring(live.RenderStepped) .. "/" .. tostring(live.InputEnded) .. "/"
	.. tostring(live.Changed))

------------------------------------------------------------------ moments
-- not loaded yet: waits
remotes.CodexUp.OnClientEvent:Fire({ Event = "Card", Kind = "Goblin", Stage = 1, Card = { Kills = 1, Golden = 0, Stage = 1, First = t0 },
	Text = "New card: Goblin! +48 gold · +84 XP" })
check(#T.S.Queue == 1 and gui:FindFirstChild("CodexMoment") == nil and #DELAYS >= 1, "before my data: the moment waits (a retry)")
player:SetAttribute("DataLoaded", true)
hold = true
runDelays()
check(gui:FindFirstChild("CodexMoment") == nil and #T.S.Queue == 1, "the tutorial holds banners: still waiting")
hold = false
runDelays()
local m = gui:FindFirstChild("CodexMoment")
check(m ~= nil and #T.S.Queue == 0 and T.S.Busy == true, "a quiet screen: the card moment shows")
check(m and m.Position.Args[2] == 0.5 and m.AnchorPoint.Y == 0.5, "the moment is centred on the screen (below the event line)")
local mc = m and m:FindFirstChild("CodexCard")
local line = m and m:FindFirstChild("Line")
check(line == nil, "최종 검수 10/15 (feedback_audit #1): no line under the moment card", line and line.Text)
check(#plays == 2 and plays[2] == "QuestDone", "a card moment rings QuestDone", #plays)
local front = mc and mc:FindFirstChild("Face"):FindFirstChild("Front")
local view = front and front:FindFirstChild("Monster3D")
check(view ~= nil and view.ImageColor3.X == 0, "a new card starts as its silhouette")
render:Fire(0.05)
for _ = 1, 20 do render:Fire(0.05) end
-- (the clock: the sway runs on os.clock; give it time by stepping until it swaps or 2 s pass)
local start = os.clock()
while view.ImageColor3.X == 0 and os.clock() - start < 2 do render:Fire(0.016) end
check(view.ImageColor3.X == 1, "the silhouette lights up into the card (mid-sway)")
-- another one waits while this shows; the Page moment = the reward popup
remotes.CodexUp.OnClientEvent:Fire({ Event = "Page", Page = 2, Title = "GoblinScholar",
	Text = "Goblin Woods page done! New title: Goblin Scholar" })
check(#T.S.Queue == 1 and #popups == 0, "a second moment waits its turn")
runDelays() -- the card's time is up
check(gui:FindFirstChild("CodexMoment") == nil, "the card goes when its time is up")
runDefers()
check(#popups == 0 and gui:FindFirstChild("RewardPopup") == nil and #toasts == 0,
	"a page done: no popup and no toast (A23-191, user 10/14)", #popups)
check(#plays == 3, "a page done still rings QuestDone", #plays)
runWaits()
runDelays()
runDefers()
check(T.S.Busy == false and #T.S.Queue == 0, "the popup closed: the queue is free")
-- an Evolve moment starts at the old stage
remotes.CodexUp.OnClientEvent:Fire({ Event = "Holo", Kind = "Slime", Card = { Kills = 12, Golden = 0, Stage = 1, First = t0 },
	Text = "Slime card is now Gold Holo!", Debug = true })
m = gui:FindFirstChild("CodexMoment")
local stageText = m and m:FindFirstChild("CodexCard"):FindFirstChild("Face"):FindFirstChild("Front"):FindFirstChild("Stage")
check(stageText ~= nil and stageText.Text == "Silver", "Gold Holo: the card shows Silver first", stageText and stageText.Text)
start = os.clock()
while stageText.Text == "Silver" and os.clock() - start < 2 do render:Fire(0.016) end
check(stageText.Text == "Gold Holo", "... and sways into Gold Holo")
-- a click ends it early
m:FindFirstChild("CodexCard").InputBegan:Fire({ UserInputType = "UserInputType.MouseButton1" })
check(gui:FindFirstChild("CodexMoment") == nil, "a click on the card ends the moment")
runDefers()
runDelays() -- its own timer, already done: nothing more
check(T.S.Busy == false, "after the click the queue is free")
-- reduced motion: the card shows its new look at once
reduced = true
remotes.CodexUp.OnClientEvent:Fire({ Event = "Golden", Kind = "Goblin", Card = { Kills = 9, Golden = 1, Stage = 1, First = t0 },
	Text = "Gold Foil card: Goblin!" })
m = gui:FindFirstChild("CodexMoment")
local st2 = m and m:FindFirstChild("CodexCard"):FindFirstChild("Face"):FindFirstChild("Front"):FindFirstChild("Stage")
check(st2 ~= nil and st2.Text == "Gold Foil", "reduced motion: the Gold Foil card at once", st2 and st2.Text)
runDelays()
runDefers()
reduced = false
check(#warns == 0, "no warnings", table.concat(warns, " | "))

print(string.format("CODEX_UI_SUMMARY checks=%d failed=%d", checks, failed))
