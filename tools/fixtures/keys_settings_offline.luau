-- BB1 key map (Config.Keybinds / Config.KeyMap / Keybinds.luau) + BB2 saved settings (Config.SanitizeSettings,
-- DataService, SettingsService.luau, Settings.luau), run offline.
-- tools/test_keys_settings.py injects the CURRENT repository sources before this file (CONFIG_SOURCE, UTIL_SOURCE,
-- NET_SOURCE, DATA_SOURCE, SERVICE_SOURCE, KEYBINDS_SOURCE, SETTINGS_SOURCE). Only engine boundaries are doubles: a
-- virtual clock (os.clock / task.delay), cached EnumItems, remotes, UserInputService, ContextActionService,
-- ProximityPromptService, GuiService and a DataStore table. The real Util runs (Signal, RateLimit). No Studio, no
-- network, no DataStore. Every check is named and collected (a failure never aborts the run); the result is one JSON line.

------------------------------------------------------------------ check collection
local results, order, findings = {}, {}, {}
local total, failedCount = 0, 0
local currentGroup = "setup"
local groupWarnings = {}

local function check(ok, name, detail)
	total += 1
	local key = currentGroup .. " :: " .. name
	local r = results[key]
	if not r then
		r = { Group = currentGroup, Name = name, Pass = 0, Fail = 0 }
		results[key] = r
		table.insert(order, key)
	end
	if ok then
		r.Pass += 1
	else
		r.Fail += 1
		failedCount += 1
		if r.Fail <= 3 then print("CHECK_FAIL " .. key .. " :: " .. tostring(detail or "")) end
		r.First = r.First or tostring(detail or "")
	end
	return ok == true
end

local function finding(text)
	table.insert(findings, { Group = currentGroup, Text = text })
end

local function runGroup(name, fn)
	currentGroup = name
	groupWarnings = {}
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
	check(ok, "group ran to the end without a Lua error", err)
	check(#groupWarnings == 0, "no warnings (Signal handler errors, Util.Warn, timer errors)", groupWarnings[1])
end

local function recordWarn(...)
	local parts = {}
	for i = 1, select("#", ...) do table.insert(parts, tostring((select(i, ...)))) end
	table.insert(groupWarnings, table.concat(parts, " "))
end

------------------------------------------------------------------ helpers
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[deepCopy(k)] = deepCopy(x) end
	return out
end

local function show(v)
	if type(v) ~= "table" then return tostring(v) end
	local parts = {}
	for k, x in v do table.insert(parts, tostring(k) .. "=" .. show(x)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function deepEq(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b or (a ~= a and b ~= b) end -- NaN equals NaN here
	for k, v in a do
		if not deepEq(v, b[k]) then return false end
	end
	for k in b do
		if a[k] == nil then return false end
	end
	return true
end

local function execute(name, source, env, ...)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn(...)
end

-- plain signal (engine events / remotes); the modules' own signals are the real Util.Signal
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
			return { Disconnect = function() local i = table.find(callbacks, fn); if i then table.remove(callbacks, i) end end }
		end,
		Fire = function(_, ...) for _, fn in table.clone(callbacks) do fn(...) end end,
	}
end

-- EnumItems: one cached table per Enum.<Type>.<Name>, so identity comparisons behave like Roblox
local ENUM
do
	local types = {}
	ENUM = setmetatable({}, { __index = function(_, typeName)
		local t = types[typeName]
		if not t then
			local cache = {}
			t = setmetatable({}, { __index = function(_, itemName)
				local e = cache[itemName]
				if not e then
					e = { Name = itemName, EnumType = typeName, __kind = "EnumItem" }
					cache[itemName] = e
				end
				return e
			end })
			types[typeName] = t
		end
		return t
	end })
end
local function typeofDouble(v) return type(v) == "table" and v.__kind or type(v) end

local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local function nativeEnv()
	return { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
		NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
		NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
		Font = ctor("Font"), Enum = ENUM }
end

local function seededRandom(seed)
	local state = seed % 2147483647
	if state <= 0 then state += 2147483646 end
	local r = {}
	local function nextFloat()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
	function r:NextNumber(a, b)
		local v = nextFloat()
		if a ~= nil then return a + (b - a) * v end
		return v
	end
	function r:NextInteger(a, b) return math.min(b, a + math.floor(nextFloat() * (b - a + 1))) end
	return r
end

-- virtual clock: os.clock() and task.delay / task.defer of one world (server and client may share one)
local function newClock(start)
	local c = { Now = start or 100, Queue = {}, Serial = 0 }
	function c:Delay(t, fn, ...)
		self.Serial += 1
		table.insert(self.Queue, { At = self.Now + math.max(0, tonumber(t) or 0), Serial = self.Serial, Fn = fn, Args = table.pack(...) })
	end
	function c:Advance(dt)
		local target = self.Now + dt
		while true do
			local best, index = nil, nil
			for i, item in self.Queue do
				if item.At <= target and (best == nil or item.At < best.At or (item.At == best.At and item.Serial < best.Serial)) then
					best, index = item, i
				end
			end
			if not best then break end
			table.remove(self.Queue, index)
			if best.At > self.Now then self.Now = best.At end
			local ok, err = pcall(best.Fn, table.unpack(best.Args, 1, best.Args.n))
			if not ok then table.insert(groupWarnings, "timer error: " .. tostring(err)) end
		end
		self.Now = target
	end
	function c:Env()
		local clock = self
		return {
			os = setmetatable({ clock = function() return clock.Now end }, { __index = os }),
			task = {
				delay = function(t, fn, ...) clock:Delay(t, fn, ...) end,
				defer = function(fn, ...) clock:Delay(0, fn, ...) end,
				spawn = function(fn, ...) fn(...) end,
				wait = function() error("unexpected yield (task.wait)") end,
			},
		}
	end
	return c
end

local function folderDouble(children)
	local f = { __kind = "Instance", ClassName = "Folder", Children = children or {} }
	for k, v in f.Children do f[k] = v end -- ReplicatedStorage.Shared.Config style indexing (DataService)
	function f:FindFirstChild(name) return self.Children[name] end
	function f:WaitForChild(name) return self.Children[name] or error("WaitForChild would yield: " .. tostring(name)) end
	function f:IsA(kind) return kind == "Folder" end
	return f
end

local function newPlayer(name, userId, parent)
	local p = { __kind = "Instance", ClassName = "Player", Name = name, DisplayName = name, UserId = userId, Parent = parent, Attrs = {} }
	function p:IsA(kind) return kind == "Player" end
	function p:GetAttribute(k) return self.Attrs[k] end
	function p:SetAttribute(k, v) self.Attrs[k] = v end
	return p
end

local function loadUtil(game, clockEnv, ws)
	return execute("Util", UTIL_SOURCE, { game = game, workspace = ws or {}, os = clockEnv.os, warn = recordWarn,
		print = function() end, Random = { new = function() return seededRandom(1) end } })
end

local CONFIG = execute("Config", CONFIG_SOURCE, nativeEnv())
local function freshConfig(zEnabled, xEnabled)
	local c = execute("Config", CONFIG_SOURCE, nativeEnv())
	if zEnabled then c.Skills.ZEnabled = true end
	if xEnabled then c.Skills.XEnabled = true end
	return c
end
-- SKL-1 (A23-49): the skill keys that exist only while their Config.Skills flag is on
local SKILL_FLAGS = { SkillZ = "ZEnabled", SkillX = "XEnabled" }
local function flagLive(config, id)
	local f = SKILL_FLAGS[id]
	return f == nil or config.Skills[f] == true
end

------------------------------------------------------------------ contract tables (docs/design/beta_basics_2026-10-05.md)
-- BB1 defaults: Id, Key, Pad (A23-21: the pad layout is fixed; "" = none in the contract table). User 2026-10-08 (MMO keys):
-- I bag, E hero (equipment), K skills, M map, Q quest list -> the skills Z / X / C, Interact G; I no longer reserved
local CONTRACT_ACTIONS = {
	{ "Attack", "F", "ButtonR2" }, { "SkillQ", "Z", "ButtonL2" }, { "SkillZ", "X", "ButtonL1" }, { "SkillX", "C", "ButtonR3" },
	{ "Auto", "R", "ButtonR1" },
	{ "GhostHold", "T", "DPadRight" }, { "PotionHP", "One", "DPadUp" }, { "PotionMP", "Two", "DPadDown" },
	{ "Interact", "G", "ButtonX" }, { "Upgrade", "U", "" }, { "Bag", "I", "" }, { "Character", "E", "" }, { "Skills", "K", "" },
	{ "Ranking", "L", "" }, { "Help", "H", "" }, { "Journal", "Q", "" }, { "Map", "M", "DPadLeft" }, { "Menu", "B", "ButtonY" },
}
local WINDOWS = { Bag = true, Character = true, Skills = true, Ranking = true, Help = true, Journal = true }
-- user 2026-10-08: these answer before their windows exist (like their HUD tiles), so they are live without Panels
local SOON = { Character = true, Skills = true, Ranking = true, Journal = true }
local ALL_WINDOWS = { "Bag", "Character", "Skills", "Ranking", "Help", "Journal" }
local CONTRACT_RESERVED = { "Escape", "Slash", "Tab", "Backquote", "Return", "KeypadEnter", "Space", "LeftShift", "RightShift",
	"W", "A", "S", "D", "O", "Comma", "Period", "PageUp", "PageDown", "Up", "Down", "Left", "Right", "F9", "F10", "F11", "F12" }
local DIGITS = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
local EXPECTED_USABLE, RESERVED_SET, ALLOWED_LIST = {}, {}, {}
do
	for _, n in CONTRACT_RESERVED do RESERVED_SET[n] = true end
	for c = string.byte("A"), string.byte("Z") do table.insert(ALLOWED_LIST, string.char(c)) end
	for _, d in DIGITS do
		table.insert(ALLOWED_LIST, d)
		table.insert(ALLOWED_LIST, "Keypad" .. d) -- the contract's Keypad0-Keypad9 under their Roblox names
	end
	for i = 1, 8 do table.insert(ALLOWED_LIST, "F" .. i) end
	for _, n in { "Minus", "Equals", "LeftBracket", "RightBracket", "Semicolon", "Quote", "BackSlash", "LeftControl", "LeftAlt", "CapsLock" } do
		table.insert(ALLOWED_LIST, n)
	end
	for _, n in ALLOWED_LIST do
		if not RESERVED_SET[n] then EXPECTED_USABLE[n] = true end
	end
end
-- Enum.KeyCode names known to exist in Roblox (offline list; the contract key names must be real)
local REAL_KEYCODES = {}
do
	for c = string.byte("A"), string.byte("Z") do REAL_KEYCODES[string.char(c)] = true end
	for _, d in DIGITS do REAL_KEYCODES[d] = true; REAL_KEYCODES["Keypad" .. d] = true end
	for i = 1, 15 do REAL_KEYCODES["F" .. i] = true end
	for _, n in { "Minus", "Equals", "LeftBracket", "RightBracket", "Semicolon", "Quote", "BackSlash", "LeftControl", "LeftAlt",
		"CapsLock", "Escape", "Slash", "Tab", "Backquote", "Return", "KeypadEnter", "Space", "LeftShift", "RightShift", "Comma",
		"Period", "PageUp", "PageDown", "Up", "Down", "Left", "Right", "ButtonA", "ButtonB", "ButtonX", "ButtonY", "ButtonR1",
		"ButtonR2", "ButtonL1", "ButtonL2", "ButtonR3", "ButtonL3", "DPadUp", "DPadDown", "DPadLeft", "DPadRight" } do
		REAL_KEYCODES[n] = true
	end
end
local NOT_ALLOWED = { "Home", "End", "Insert", "Delete", "RightControl", "RightAlt", "LeftSuper", "F13", "Keypad1", "Backspace",
	"NumLock", "ButtonR2", "Unknown", "f", "", " F" }
local SETTINGS_DEFAULTS = { V = 4, Keys = {}, Sfx = 1, Music = 1, Shake = true, DmgNum = "All", Tags = "All", KeyBadges = false, Lang = "Auto", BagSort = "Default",
	Cam = "Follow", PvPCards = false } -- Cam: A23-91 (the console-style Follow is the default again, user 10/09); PvPCards: 검수 10/09 (first PvP zone cards seen); Music: A23-100
local SETTINGS_DEFS = {
	Sfx = { Type = "Number", Min = 0, Max = 1, Step = 0.1 },
	Music = { Type = "Number", Min = 0, Max = 1, Step = 0.1 }, -- A23-100 (the background music)
	Shake = { Type = "Bool" },
	DmgNum = { Type = "Enum", Options = { "All", "Off" } },
	Tags = { Type = "Enum", Options = { "All", "Near", "Off" } },
	KeyBadges = { Type = "Bool" },
	Lang = { Type = "Enum", Options = { "Auto", "ko", "en" } },
	BagSort = { Type = "Enum", Options = { "Default", "Grade", "Count" } },
	Cam = { Type = "Enum", Options = { "Follow", "Free" } }, -- A23-65
	PvPCards = { Type = "Bool" }, -- 검수 10/09
}
local SFX_GRID = {}
for i = 0, 10 do SFX_GRID[i / 10] = true end
local COLLISION_TEXT = "New action [%s] has no key: %s is already used. Pick one in Settings." -- story text checker: <= 14 words (검수 2026-10-07)

local function defaultOf(config, id) return config.Keybinds.ById[id] and config.Keybinds.ById[id].Key end
local function liveAll(config, except)
	local s = {}
	for _, a in config.Keybinds.Actions do
		if flagLive(config, a.Id) and not (except and except[a.Id]) then s[a.Id] = true end
	end
	return s
end
local function boundCount(map)
	local n = 0
	for _, v in map do if v ~= "" then n += 1 end end
	return n
end
local function noDuplicateKeys(map)
	local seen = {}
	for id, v in map do
		if v ~= "" then
			if seen[v] then return false, v .. " " .. seen[v] .. "/" .. id end
			seen[v] = id
		end
	end
	return true
end

-- the BB1 / BB2 collision rule written from the contract text (independent of Config.KeyMap)
local function referenceKeyMap(config, sparse, live)
	local keys = type(sparse) == "table" and sparse or {}
	local function isLive(def)
		if live ~= nil then return live[def.Id] == true end
		return flagLive(config, def.Id)
	end
	-- review of 27246d1: Interact (NoClear, prompt keys only) may not be saved empty or on a keypad / symbol key
	local PROMPT = {}
	for c = string.byte("A"), string.byte("Z") do PROMPT[string.char(c)] = true end
	for _, n in { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "LeftControl", "LeftAlt",
		"F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8" } do PROMPT[n] = true end
	local function explicit(def)
		local v = keys[def.Id]
		if type(v) ~= "string" then return false end
		if def.Id == "Interact" then return v ~= "" and #v <= 24 and EXPECTED_USABLE[v] == true and PROMPT[v] == true end
		return v == "" or (#v <= 24 and EXPECTED_USABLE[v] == true)
	end
	local map, taken, collisions = {}, {}, {}
	for _, def in config.Keybinds.Actions do map[def.Id] = "" end
	for _, def in config.Keybinds.Actions do
		if isLive(def) and explicit(def) and keys[def.Id] ~= "" and not taken[keys[def.Id]] then
			map[def.Id] = keys[def.Id]
			taken[keys[def.Id]] = true
		end
	end
	for _, def in config.Keybinds.Actions do
		if isLive(def) and not explicit(def) and def.Key ~= "" then
			if taken[def.Key] then
				table.insert(collisions, def.Id)
			else
				map[def.Id] = def.Key
				taken[def.Key] = true
			end
		end
	end
	-- Interact always ends with a key: it takes E back from whoever got it (that one is reported instead)
	local ia = config.Keybinds.ById.Interact
	if ia and isLive(ia) and map.Interact == "" then
		for id, k in map do
			if k == ia.Key and id ~= "Interact" then
				map[id] = ""
				table.insert(collisions, id)
			end
		end
		local i = table.find(collisions, "Interact")
		if i then table.remove(collisions, i) end
		map.Interact = ia.Key
	end
	return map, collisions
end

local function key(name) return { UserInputType = ENUM.UserInputType.Keyboard, KeyCode = ENUM.KeyCode[name] } end
local function pad(name) return { UserInputType = ENUM.UserInputType.Gamepad1, KeyCode = ENUM.KeyCode[name] } end

------------------------------------------------------------------ worlds
-- client: the real Settings + Keybinds modules (ClientMain order: Settings, Keybinds; Init both, then Start both)
local function clientWorld(opts)
	opts = opts or {}
	local w = { Clock = opts.Clock or newClock(100), Toasts = {}, Sends = {}, Registered = {}, ChangedFires = 0 }
	local clock = w.Clock
	local config = freshConfig(opts.ZEnabled, opts.XEnabled)
	w.Config = config
	for _, id in opts.Windows or {} do w.Registered[id] = true end
	local cenv = clock:Env()
	-- opts.Device = { Keyboard, Touch, Mouse } (review B5 device table); else opts.Touch = a phone, default = a desktop
	local dev = opts.Device
	local uis = { TouchEnabled = if dev then dev.Touch == true else opts.Touch == true,
		KeyboardEnabled = if dev then dev.Keyboard == true else opts.Touch ~= true,
		MouseEnabled = if dev then dev.Mouse == true else opts.Touch ~= true,
		InputBegan = signal(), InputEnded = signal() }
	function uis:GetFocusedTextBox() return nil end
	local cas = { Bound = {}, Order = {} }
	function cas:BindActionAtPriority(name, fn, _touch, priority, ...)
		self.Bound[name] = { Fn = fn, Priority = priority, Inputs = { ... } }
		table.insert(self.Order, name)
	end
	function cas:UnbindAction(name) self.Bound[name] = nil end
	local pps = { Enabled = true, PromptShown = signal() }
	local gui = { MenuOpened = signal() }
	local ws = { DescendantAdded = signal(), Items = {} }
	function ws:GetDescendants() return table.clone(self.Items) end
	w.UIS, w.CAS, w.PPS, w.Gui, w.Workspace = uis, cas, pps, gui, ws
	local remotes = {}
	for _, name in { "SetSettings", "Settings" } do
		local r = { __kind = "Instance", ClassName = "RemoteEvent", Name = name, OnClientEvent = signal() }
		function r:IsA(kind) return kind == "RemoteEvent" end
		function r:FireServer(...)
			local args = deepCopy(table.pack(...)) -- the network copies the arguments
			table.insert(w.Sends, { Name = name, At = clock.Now, N = args.n, Blob = args[1] })
			if w.Wire then w.Wire(name, args) end
		end
		remotes[name] = r
	end
	w.Remotes = remotes
	local rs = folderDouble({ Shared = folderDouble({ Config = "Config", Util = "Util" }), Remotes = folderDouble(remotes) })
	local services = { ReplicatedStorage = rs, UserInputService = uis, ContextActionService = cas, GuiService = gui,
		ProximityPromptService = pps, RunService = { IsStudio = function() return false end },
		Players = { LocalPlayer = newPlayer("Me", 1, nil) } }
	local game = { GetService = function(_, name) return assert(services[name], "service " .. tostring(name)) end }
	local util = loadUtil(game, cenv, ws)
	local modules = { Config = config, Util = util }
	local env = { game = game, workspace = ws, typeof = typeofDouble, Enum = ENUM, Vector3 = { zero = vec(0, 0, 0), new = vec },
		os = cenv.os, task = cenv.task, print = function() end, warn = recordWarn,
		Instance = { new = function(kind) error("Instance.new(" .. tostring(kind) .. ") offline") end },
		require = function(m) return assert(modules[m], "unexpected require " .. tostring(m)) end }
	local settings = execute("Settings", SETTINGS_SOURCE, env)
	local keybinds = execute("Keybinds", KEYBINDS_SOURCE, env)
	w.ST, w.KB = settings, keybinds
	local panels = { Has = function(id) return w.Registered[id] == true end }
	local uikit = { Toast = function(msg, kind) table.insert(w.Toasts, { Text = msg, Kind = kind }) end }
	w.C = { Settings = settings, Keybinds = keybinds, UIKit = uikit, Panels = panels }
	settings.Init(w.C)
	keybinds.Init(w.C)
	keybinds.Changed:Connect(function(map)
		w.ChangedFires += 1
		w.LastMap = map
	end)
	function w:Start()
		settings.Start()
		keybinds.Start()
	end
	function w:Echo(seq, st)
		remotes.Settings.OnClientEvent:Fire({ Seq = seq, Settings = deepCopy(st) })
	end
	function w:Prompt(later)
		local p = { __kind = "Instance", ClassName = "ProximityPrompt", KeyboardKeyCode = ENUM.KeyCode.Unknown, Parent = ws }
		function p:IsA(kind) return kind == "ProximityPrompt" end
		table.insert(ws.Items, p)
		if later then ws.DescendantAdded:Fire(p) end
		return p
	end
	function w:Capture() -- the keyboard capture binding (BB3) currently bound, or nil (not the camera key sink)
		for i = #cas.Order, 1, -1 do
			local b = cas.Bound[cas.Order[i]]
			if b and cas.Order[i] ~= "HH_CameraKeySink" then return b, cas.Order[i] end
		end
		return nil
	end
	if opts.NoStart ~= true then w:Start() end
	return w
end

-- server: the real SettingsService + real Util (RateLimit on the virtual clock); PlayerService / Net are doubles
local function serverWorld(opts)
	opts = opts or {}
	local s = { Clock = opts.Clock or newClock(100), Sent = {}, Ready = {}, Data = {}, Calls = 0, Pushes = 0 }
	local clock = s.Clock
	local config = freshConfig(false)
	s.Config = config
	local cenv = clock:Env()
	local remotes = {}
	local net = {}
	function net.Get(name)
		if not remotes[name] then
			local r = { Name = name, OnServerEvent = signal() }
			function r:FireClient(p, payload)
				table.insert(s.Sent, { Name = name, Player = p, Payload = deepCopy(payload), At = clock.Now })
				if s.Wire then s.Wire(name, p, deepCopy(payload)) end
			end
			function r:FireAllClients(payload)
				table.insert(s.Sent, { Name = name, Player = "ALL", Payload = deepCopy(payload), At = clock.Now })
			end
			remotes[name] = r
		end
		return remotes[name]
	end
	function net.Notify() end
	local players = { __kind = "Instance", Name = "Players" }
	local services = { ReplicatedStorage = folderDouble({ Shared = folderDouble({ Config = "Config", Util = "Util", Net = "Net" }) }),
		Players = players }
	local game = { GetService = function(_, name) return assert(services[name], "service " .. tostring(name)) end }
	local util = loadUtil(game, cenv)
	local modules = { Config = config, Util = util, Net = net }
	local ps = { PlayerReady = signal() }
	function ps.IsReady(p) return s.Ready[p] == true end
	function ps.GetData(p) return s.Data[p] end
	local env = { game = game, workspace = {}, typeof = typeofDouble, Enum = ENUM, os = cenv.os, task = cenv.task,
		print = function() end, warn = recordWarn,
		require = function(m) return assert(modules[m], "unexpected require " .. tostring(m)) end }
	local svc = execute("SettingsService", SERVICE_SOURCE, env)
	svc.Init({ PlayerService = ps })
	svc.Start()
	s.Service, s.PS = svc, ps
	local serial = 0
	function s:Join(data, ready)
		serial += 1
		local p = newPlayer("P" .. serial, 9000 + serial, players)
		self.Data[p] = data or { Version = 3, Settings = config.SanitizeSettings(nil) }
		if ready ~= false then self:MakeReady(p) end
		return p
	end
	function s:MakeReady(p)
		self.Ready[p] = true
		local before = #self.Sent
		ps.PlayerReady:Fire(p, self.Data[p])
		self.Pushes += #self.Sent - before
		for i = before + 1, #self.Sent do self.Sent[i].Push = true end
	end
	function s:Call(p, ...)
		self.Calls += 1
		net.Get("SetSettings").OnServerEvent:Fire(p, ...)
	end
	function s:SentTo(p)
		local out = {}
		for _, e in self.Sent do
			if e.Name == "Settings" and e.Player == p then table.insert(out, e) end
		end
		return out
	end
	return s
end

-- client + server over a fake network (shared clock; latency(name, direction) seconds each way)
local function linkedWorld(opts)
	local clock = newClock(100)
	local server = serverWorld({ Clock = clock })
	local client = clientWorld({ Clock = clock, Windows = opts.Windows, NoStart = true })
	local player = server:Join(opts.Data, false)
	local latency = opts.Latency or function() return 0.08 end
	client.Wire = function(_name, args)
		clock:Delay(latency("up"), function() server:Call(player, table.unpack(args, 1, args.n)) end)
	end
	server.Wire = function(name, p, payload)
		if p ~= player then return end
		clock:Delay(latency("down"), function() client.Remotes[name].OnClientEvent:Fire(payload) end)
	end
	return { Clock = clock, Server = server, Client = client, Player = player }
end

-- DataService with a DataStore table (as tools/fixtures/a23_14_offline.luau)
local function dataWorld(rows)
	local f = { Rows = rows or {}, Spawned = {} }
	local config = freshConfig(false)
	local players = { __kind = "Instance", Name = "Players" }
	local store = {}
	function store:GetAsync(k) return deepCopy(f.Rows[k]) end
	function store:UpdateAsync(k, fn)
		local nextValue = fn(deepCopy(f.Rows[k]))
		if nextValue ~= nil then f.Rows[k] = deepCopy(nextValue) end
		return deepCopy(f.Rows[k])
	end
	local util = { DeepCopy = deepCopy, FormatNumber = tostring, Random = seededRandom(7),
		Warn = function(tag, msg) if tag ~= "DataService" then table.insert(groupWarnings, tag .. ": " .. tostring(msg)) end end,
		RateLimit = function() return true end, Now = function() return 1000 end, IsAlive = function() return true end,
		Signal = { new = signal } }
	local services = { Players = players, ReplicatedStorage = { Shared = { Config = "Config", Util = "Util" } },
		DataStoreService = { GetDataStore = function() return store end }, RunService = { IsStudio = function() return true end },
		HttpService = { GenerateGUID = function() return "guid-keys" end } }
	local env = { game = { JobId = "offline-keys", GetService = function(_, name) return assert(services[name], name) end },
		workspace = {}, typeof = typeofDouble, print = function() end, warn = function() end,
		task = { spawn = function(fn) table.insert(f.Spawned, fn) end, wait = function() error("unexpected yield") end,
			delay = function() end, defer = function(fn, ...) fn(...) end },
		require = function(name)
			if name == "Config" then return config elseif name == "Util" then return util end
			error("unexpected require " .. tostring(name))
		end }
	local ds = execute("DataService", DATA_SOURCE, env)
	ds.Init({})
	ds.Start()
	f.Spawned[1]() -- the DataStore probe; the autosave loop is never started
	f.Spawned = {}
	f.DS, f.Config = ds, config
	function f:Key(userId) return config.Data.KeyPrefix .. tostring(userId) end
	function f:Load(userId)
		local p = newPlayer("D" .. userId, userId, players)
		return ds.Load(p), p
	end
	return f
end

------------------------------------------------------------------ 1. Config contract
runGroup("config-contract", function()
	local KB = CONFIG.Keybinds
	check(type(KB) == "table" and type(KB.Actions) == "table", "Config.Keybinds.Actions exists")
	check(#KB.Actions == #CONTRACT_ACTIONS, "18 actions (BB1 table + SKL-1 SkillX)", #KB.Actions)
	local validGroups = { Combat = true, Potion = true, Window = true, Other = true }
	for i, want in CONTRACT_ACTIONS do
		local a = KB.Actions[i] or {}
		local id = want[1]
		check(a.Id == id, "Actions order = the BB1 defaults table", i .. " " .. tostring(a.Id))
		check(a.Key == want[2], "default PC key = BB1 table", id .. " " .. tostring(a.Key))
		check((a.Pad or "") == want[3], "fixed gamepad button = BB1 table (A23-21)", id .. " " .. tostring(a.Pad))
		check(validGroups[a.Group] == true, "Group is Combat / Potion / Window / Other", id .. " " .. tostring(a.Group))
		check((a.Group == "Window") == (WINDOWS[id] == true) and (not WINDOWS[id] or a.Window == id),
			"the six window actions (Group Window, Window = Panels id) and only them", id .. " " .. show({ a.Group, a.Window }))
		check((id == "PotionHP" or id == "PotionMP") == (a.Group == "Potion"), "potion actions are the Potion group", id)
		check(type(a.Label) == "string" and a.Label ~= "" and type(a.LabelEn) == "string" and a.LabelEn ~= "",
			"every action has Label + LabelEn", id)
		check(type(a.Button) == "string" and a.Button ~= "" and type(a.ButtonEn) == "string" and a.ButtonEn ~= "",
			"every action has a touch name (Button + ButtonEn, A23-21)", id)
		check((SKILL_FLAGS[id] ~= nil) == (a.Flag ~= nil) and (SKILL_FLAGS[id] == nil or a.Flag == "Skills." .. SKILL_FLAGS[id]),
			"only SkillZ / SkillX have a Flag (Config.Skills.ZEnabled / XEnabled)", id .. " " .. tostring(a.Flag))
		check(REAL_KEYCODES[a.Key] == true and (want[3] == "" or REAL_KEYCODES[a.Pad] == true),
			"default key and pad names are real Enum.KeyCode names", id)
	end
	check(CONFIG.Skills and CONFIG.Skills.ZEnabled == false and CONFIG.Skills.XEnabled == false,
		"Config.Skills.ZEnabled / XEnabled = false (on at the 10/20 skill decision, SKL-1)")
	-- Reserved / Allowed
	local reserved = {}
	for _, n in KB.Reserved or {} do reserved[n] = true end
	check(deepEq(reserved, RESERVED_SET), "Config.Keybinds.Reserved = the BB1 Reserved set", show(reserved))
	local names = {}
	for n in EXPECTED_USABLE do names[n] = true end
	for n in RESERVED_SET do names[n] = true end
	for _, n in NOT_ALLOWED do names[n] = true end
	for _, n in KB.Allowed or {} do names[n] = true end
	for n in names do
		check(CONFIG.KeyUsable(n) == (EXPECTED_USABLE[n] == true),
			"KeyUsable = Allowed (A-Z, 0-9, F1-F8, keypad digits, symbols, LeftControl, LeftAlt, CapsLock) minus Reserved", n)
		check(CONFIG.KeyReserved(n) == (RESERVED_SET[n] == true), "KeyReserved = the Reserved set", n)
	end
	for _, n in KB.Allowed or {} do check(REAL_KEYCODES[n] == true, "every Allowed name is a real Enum.KeyCode name", n) end
	for _, n in CONTRACT_RESERVED do check(REAL_KEYCODES[n] == true, "every Reserved name is a real Enum.KeyCode name", n) end
	check(CONFIG.KeyUsable(string.rep("A", 25)) == false and CONFIG.KeyUsable(5) == false and CONFIG.KeyUsable(nil) == false,
		"KeyUsable: non-strings and 25+ characters are never usable")
	finding("BB1 lists Allowed 'Keypad0-Keypad9'; Roblox names them KeypadZero..KeypadNine, so those names are stored "
		.. "(KeyUsable('Keypad1') = " .. tostring(CONFIG.KeyUsable("Keypad1")) .. ", KeyLabel('Keypad1') = "
		.. tostring(CONFIG.KeyLabel("Keypad1")) .. ").")
	-- pad, rate limit, data, settings definitions
	check(deepEq(KB.PadWired, { Attack = true, SkillQ = true }), "only R2 attack / L2 skill are wired (as before BB1; BB21 wires the rest)",
		show(KB.PadWired))
	check(CONFIG.RateLimits.SetSettings == 1, "Config.RateLimits.SetSettings = 1", CONFIG.RateLimits.SetSettings)
	check(deepEq(CONFIG.Data.Defaults.Settings, SETTINGS_DEFAULTS), "Config.Data.Defaults.Settings = the BB2 defaults",
		show(CONFIG.Data.Defaults.Settings))
	check(CONFIG.Data.Version == 3, "Config.Data.Version stays 3 (the settings blob and A23-69's Stats are additive)", CONFIG.Data.Version)
	check(table.find(CONFIG.Data.Mirrored, "Settings") == nil, "Settings is not mirrored to attributes")
	local ST = CONFIG.Settings or {}
	local defs = {}
	for k, d in ST.Defs or {} do
		defs[k] = { Type = d.Type, Min = d.Min, Max = d.Max, Step = d.Step, Options = d.Options }
	end
	check(deepEq(defs, SETTINGS_DEFS), "Config.Settings.Defs = the BB2 definitions", show(defs))
	for k in SETTINGS_DEFS do
		check(type(ST.Text[k]) == "string" and ST.Text[k] ~= "" and type(ST.Text[k .. "En"]) == "string" and ST.Text[k .. "En"] ~= "",
			"every setting has Korean + English text", k)
	end
	check(ST.Text.KeyCollision == COLLISION_TEXT, "the collision toast text is the BB2 sentence (English)", ST.Text.KeyCollision)
	check(type(ST.Text.KeyCollisionEn) == "string" and select(2, string.gsub(ST.Text.KeyCollisionEn, "%%s", "")) == 2,
		"the English collision toast takes the same two values", ST.Text.KeyCollisionEn)
	check(ST.MaxBlobKeys == 16, "Config.Settings.MaxBlobKeys = 16", ST.MaxBlobKeys)
	check(KB.None == "None" and KB.NoneEn == "None", "unbound label None (English)")
	-- default map
	local map, collisions = CONFIG.KeyMap({}, nil)
	for _, want in CONTRACT_ACTIONS do
		local expected = SKILL_FLAGS[want[1]] and "" or want[2]
		check(map[want[1]] == expected, "KeyMap({}) = the BB1 defaults (SkillZ / SkillX have no key while their Flags are off)",
			want[1] .. " " .. tostring(map[want[1]]))
	end
	check(#collisions == 0 and count(map) == #CONTRACT_ACTIONS, "KeyMap({}): one entry per action (18 with SKL-1 SkillX), no collisions", show({ count(map), collisions }))
	local zmap = CONFIG.KeyMap({}, liveAll(freshConfig(true)))
	local zc = freshConfig(true)
	local zmap2 = zc.KeyMap({}, nil)
	check(zmap.SkillZ == "X" and zmap2.SkillZ == "X", "with Config.Skills.ZEnabled the Z skill gets its key X", show({ zmap.SkillZ, zmap2.SkillZ }))
end)

------------------------------------------------------------------ 2. KeyMap collision rule
runGroup("keymap-rules", function()
	local C = CONFIG
	local live = liveAll(C)
	-- 1. explicit first in Actions order; an explicit key already taken becomes "" (and is not a collision)
	local map, col = C.KeyMap({ Attack = "Z", SkillQ = "Z" }, live)
	check(map.Attack == "Z" and map.SkillQ == "" and #col == 0,
		"explicit entries first in Actions order: the later explicit holder of a taken key gets '' (not reported)", show({ map.Attack, map.SkillQ, col }))
	map, col = C.KeyMap({ Menu = "F" }, live)
	check(map.Menu == "F" and map.Attack == "" and col[1] == "Attack" and #col == 1,
		"an explicit key beats an earlier action's default; that default-only action is '' and reported", show({ map.Menu, map.Attack, col }))
	-- BB2 acceptance: Keys = { Attack = 'Q' } loaded after Journal = Q came (the 10/08 layout)
	map, col = C.KeyMap({ Attack = "Q" }, live)
	check(map.Attack == "Q" and map.Journal == "" and #col == 1 and col[1] == "Journal",
		"BB2: a saved Attack = Q keeps Q; the Journal action gets '' and is reported once", show({ map.Attack, map.Journal, col }))
	map, col = C.KeyMap({ Attack = "Q" }, nil)
	check(map.Attack == "Q" and map.Journal == "" and col[1] == "Journal", "server view (liveSet nil = every Flag-on action) gives the same",
		show({ map.Attack, map.Journal, col }))
	-- non-live actions hold no key and take no part
	local noBag = liveAll(C, { Bag = true })
	map, col = C.KeyMap({ Bag = "X" }, noBag)
	check(map.Bag == "" and boundCount(map) == 15 and #col == 0, "a non-live window holds no key even with a saved key", show({ map.Bag, col }))
	map, col = C.KeyMap({ Map = "I" }, noBag)
	check(map.Map == "I" and map.Bag == "" and #col == 0, "a non-live window's default key blocks nothing (no collision)", show({ map.Map, col }))
	map, col = C.KeyMap({ Map = "I" }, live)
	check(map.Map == "I" and map.Bag == "" and col[1] == "Bag", "once the window is live, its default-only key collides and is reported",
		show({ map.Map, map.Bag, col }))
	-- the Z skill flag
	map, col = C.KeyMap({ Attack = "X" }, nil)
	check(map.Attack == "X" and map.SkillZ == "" and #col == 0, "Flag off: SkillZ is not live (no key, no collision)", show({ map.SkillZ, col }))
	map = C.KeyMap({ SkillZ = "X" }, nil)
	local xHolder = nil
	for id, v in map do if v == "X" then xHolder = id end end
	check(map.SkillZ == "" and xHolder == nil, "Flag off: a saved SkillZ key binds nothing", show({ map.SkillZ, xHolder }))
	local zc = freshConfig(true)
	map, col = zc.KeyMap({ Attack = "X" }, nil)
	check(map.SkillZ == "" and col[1] == "SkillZ", "Flag on: the new SkillZ default collides with my Attack = X and is reported", show({ map.SkillZ, col }))
	-- explicit "" = unbound by choice (never reported, its default stays free)
	map, col = C.KeyMap({ Attack = "" }, live)
	local fHolder = nil
	for id, v in map do if v == "F" then fHolder = id end end
	check(map.Attack == "" and #col == 0 and fHolder == nil, "explicit '' leaves the action unbound and is not reported", show({ map.Attack, col, fHolder }))
	-- invalid saved values fall back to the default
	for _, bad in { "Escape", "W", "Home", string.rep("A", 30), 5, true, {} } do
		map = C.KeyMap({ Attack = bad }, live)
		check(map.Attack == "F", "a reserved / unknown / non-string saved key falls back to the default", show(bad))
	end
	local badMaps = table.pack(nil, 5, "x", true)
	for i = 1, badMaps.n do
		map, col = C.KeyMap(badMaps[i], nil)
		check(map.Attack == "F" and map.Menu == "B" and #col == 0, "a non-table sparse map = the defaults", tostring(badMaps[i]))
	end
	-- never wipe all keys
	local all = {}
	for _, a in C.Keybinds.Actions do all[a.Id] = "X" end
	map = C.KeyMap(all, live)
	check(map.Attack == "X" and map.Interact == "G" and boundCount(map) == 2,
		"every action saved on one key: the first live action keeps it, Interact keeps G (never all blank)",
		show(map))
	map = C.KeyMap({ Attack = "Z" }, live)
	check(boundCount(map) == 15 and map.SkillQ == "", "one changed key costs at most the one colliding default", boundCount(map))
	-- fuzz against the contract rule
	local rnd = seededRandom(424242)
	local pool = { "", "X", "V", "N", "F", "Q", "G", "J", "M", "B", "One", "KeypadOne", "LeftControl", "Escape", "W", "Home",
		string.rep("Z", 30), 5, true }
	local ids = {}
	for _, a in C.Keybinds.Actions do table.insert(ids, a.Id) end
	for i = 1, 400 do
		local sparse = {}
		for _, id in ids do
			if rnd:NextNumber() < 0.35 then sparse[id] = pool[rnd:NextInteger(1, #pool)] end
		end
		local liveSet = nil
		if i % 3 ~= 0 then
			liveSet = {}
			for _, id in ids do
				if rnd:NextNumber() < 0.75 then liveSet[id] = true end
			end
		end
		local m, c = C.KeyMap(sparse, liveSet)
		local rm, rc = referenceKeyMap(C, sparse, liveSet)
		check(deepEq(m, rm) and deepEq(c, rc), "KeyMap = the BB2 collision rule (fuzz, 400 saves x live sets)",
			show({ sparse = sparse, got = m, want = rm, gotC = c, wantC = rc }))
		local okDup, dup = noDuplicateKeys(m)
		check(okDup, "no two actions ever share a key (fuzz)", dup)
		local liveCount, explicitBlank = 0, 0
		for _, id in ids do
			local isLive = (liveSet == nil and SKILL_FLAGS[id] == nil) or (liveSet ~= nil and liveSet[id] == true)
			if isLive then
				liveCount += 1
				if sparse[id] == "" then explicitBlank += 1 end
			elseif liveSet ~= nil then
				check(m[id] == "", "non-live actions hold no key (fuzz)", id)
			end
		end
		check(liveCount == explicitBlank or boundCount(m) > 0, "never wipes all keys (fuzz)", show(sparse))
	end
end)

------------------------------------------------------------------ 3. labels and key tokens
runGroup("keylabel-fillkeys", function()
	local C = CONFIG
	local cases = { { "One", "1" }, { "Zero", "0" }, { "Nine", "9" }, { "LeftControl", "Ctrl" }, { "LeftAlt", "Alt" }, { "CapsLock", "Caps" },
		{ "KeypadOne", "Num1" }, { "KeypadZero", "Num0" }, { "KeypadNine", "Num9" }, { "Keypad1", "Num1" }, { "Keypad7", "Num7" },
		{ "Minus", "-" }, { "Equals", "=" }, { "BackSlash", "\\" }, { "Quote", "'" }, { "Semicolon", ";" }, { "LeftBracket", "[" },
		{ "F", "F" }, { "F5", "F5" }, { "Q", "Q" }, { "", "None" } }
	for _, c in cases do
		check(C.KeyLabel(c[1]) == c[2], "Config.KeyLabel cases ('One'->'1', 'LeftControl'->'Ctrl', 'Keypad1'->'Num1', ''->'None')",
			c[1] .. " -> " .. tostring(C.KeyLabel(c[1])))
	end
	check(C.KeyLabel(nil) == "None" and C.KeyLabel(5) == "None", "KeyLabel(nil / non-string) = None")
	check(C.KeyLabel("", true) == "None" and C.KeyLabel("One", true) == "1", "KeyLabel English: '' -> None")
	-- server-side token fill (StoryQuestService uses Config.FillKeys(text, Config.KeyMap(keys, nil)))
	local unlocked = C.StoryQuests.Text.Unlocked
	check(string.find(unlocked, "{Auto}", 1, true) ~= nil and string.find(unlocked, "with R ", 1, true) == nil,
		"the auto-combat unlock text carries the {Auto} token, no fixed R", unlocked)
	check(string.find(C.FillKeys(unlocked, C.KeyMap({}, nil)), "with R (", 1, true) ~= nil, "{Auto} -> R by default")
	check(string.find(C.FillKeys(unlocked, C.KeyMap({ Auto = "V" }, nil)), "with V (", 1, true) ~= nil, "{Auto} -> the player's key (V)")
	local stepText = nil
	for _, q in C.StoryQuests.Defs or {} do
		for _, st in q.Steps or {} do
			if type(st.Text) == "string" and string.find(st.Text, "{Auto}", 1, true) then stepText = st.Text end
		end
	end
	check(stepText ~= nil and C.FillKeys(stepText, C.KeyMap({}, nil)) == "Turn on Auto Battle (R)",
		"the auto-combat quest step reads 'Turn on Auto Battle (R)' by default", tostring(stepText))
	check(C.Text.GhostButton == "Ghost grab ({GhostHold})" and C.FillKeys(C.Text.GhostButton, C.KeyMap({}, nil)) == "Ghost grab (T)",
		"GhostButton = 'Ghost grab ({GhostHold})' -> T", C.Text.GhostButton)
	check(C.FillKeys("{Foo} {Auto}", C.KeyMap({}, nil)) == "{Foo} R", "unknown {tokens} stay")
	check(C.FillKeys("{Auto}", C.KeyMap({ Auto = "" }, nil)) == "None" and C.FillKeys("{Auto}", C.KeyMap({ Auto = "" }, nil), true) == "None",
		"an unbound action fills as None")
end)

------------------------------------------------------------------ 4. SanitizeSettings
runGroup("sanitize", function()
	local C = CONFIG
	local S = C.SanitizeSettings
	local fieldSet = { V = true, Keys = true, Sfx = true, Music = true, Shake = true, DmgNum = true, Tags = true, KeyBadges = true, Lang = true,
		BagSort = true, Cam = true, PvPCards = true }
	local bads = table.pack(nil, 5, "x", true, {})
	for i = 1, bads.n do
		check(deepEq(S(bads[i]), SETTINGS_DEFAULTS), "nil / non-table / empty -> the defaults", tostring(bads[i]))
	end
	local out = S({ Foo = 1, Seq = 7, Version = 9, V = 5, Keys = { Nope = "X", [1] = "Y" }, Sfx = 0.5 })
	local keys = {}
	for k in out do keys[k] = true end
	check(deepEq(keys, fieldSet) and out.V == 4 and out.Sfx == 0.5 and count(out.Keys) == 0,
		"unknown top-level keys and unknown action ids are dropped (V = 4, A23-78 / A23-91)", show(out))
	-- Keys
	out = S({ Keys = { Attack = "Escape" } })
	check(out.Keys.Attack == nil and C.KeyMap(out.Keys, nil).Attack == "F", "BB2 test value Keys.Attack = 'Escape' is rejected (Attack stays F)",
		show(out.Keys))
	for _, r in CONTRACT_RESERVED do
		check(S({ Keys = { Attack = r } }).Keys.Attack == nil, "every Reserved key is rejected", r)
	end
	for _, n in NOT_ALLOWED do
		if n ~= "" then check(S({ Keys = { Attack = n } }).Keys.Attack == nil, "keys outside Allowed are rejected", n) end
	end
	for n in EXPECTED_USABLE do
		if n ~= "F" then check(S({ Keys = { Attack = n } }).Keys.Attack == n, "every usable key is kept", n) end
	end
	check(S({ Keys = { Attack = string.rep("A", 1000) } }).Keys.Attack == nil, "a 1000-character key name is rejected")
	for _, v in { 5, true, {}, false } do
		check(S({ Keys = { Attack = v } }).Keys.Attack == nil, "non-string key values are dropped", show(v))
	end
	out = S({ Keys = { Attack = "F", Map = "M", SkillQ = "Z", Menu = "X" } })
	check(deepEq(out.Keys, { Menu = "X" }), "entries equal to the default are dropped (sparse)", show(out.Keys))
	out = S({ Keys = { Attack = "" } })
	check(out.Keys.Attack == "", "'' (unbound by choice) is kept")
	out = S({ Keys = { Map = "X", Menu = "X" } })
	check(out.Keys.Map == "X" and out.Keys.Menu == "", "BB2 test value 'two actions on one key': the later one is saved as ''", show(out.Keys))
	local okDup = noDuplicateKeys(C.KeyMap(out.Keys, nil))
	check(okDup, "two actions on one key never both bind it")
	-- numbers
	local sfx = { { 5, 1 }, { -3, 0 }, { 0.34, 0.3 }, { 0.36, 0.4 }, { 0.04, 0 }, { 0.96, 1 }, { 0.7, 0.7 }, { 1, 1 }, { 0, 0 },
		{ 0.5, 0.5 }, { 1e300, 1 } }
	for _, c in sfx do
		check(S({ Sfx = c[1] }).Sfx == c[2], "Sfx clamped to 0..1 and snapped to the 0.1 step (BB2 test value Sfx = 5 -> 1)",
			tostring(c[1]) .. " -> " .. tostring(S({ Sfx = c[1] }).Sfx))
	end
	for _, bad in { 0 / 0, math.huge, -math.huge, "0.5", true, {} } do
		check(S({ Sfx = bad }).Sfx == 1, "NaN / +-inf / non-numbers -> the default 1", tostring(bad))
	end
	-- bools / enums
	for _, v in { "true", 1, 0, {} } do
		local o = S({ Shake = v, KeyBadges = v })
		check(o.Shake == true and o.KeyBadges == false, "bools must be boolean (else the default; key hints off since 10/08)",
			show(v))
	end
	local o = S({ Shake = false, KeyBadges = false })
	check(o.Shake == false and o.KeyBadges == false, "false is kept")
	for k, def in SETTINGS_DEFS do
		if def.Type == "Enum" then
			for _, opt in def.Options do check(S({ V = 4, [k] = opt })[k] == opt, "every enum option is kept (a V4 blob)", k .. "=" .. opt) end
			for _, bad in { "x", string.upper(def.Options[1]), string.rep("한", 1000), 3, true } do
				check(S({ [k] = bad })[k] == SETTINGS_DEFAULTS[k], "values outside Options -> the default (incl. a 1000-character string)",
					k .. "=" .. string.sub(tostring(bad), 1, 12))
			end
		end
	end
	check(S({ DmgNum = "Near" }).DmgNum == "All" and S({ Tags = "Near" }).Tags == "Near", "Near exists for Tags only")
	-- fuzz invariants
	local rnd = seededRandom(99)
	local ids = {}
	for _, a in C.Keybinds.Actions do table.insert(ids, a.Id) end
	local keyPool = { "", "X", "F", "Q", "G", "J", "M", "One", "KeypadOne", "Escape", "W", "Home", string.rep("Y", 30), 7, false }
	local anyPool = { 0 / 0, math.huge, -1, 0.25, 0.55, 2, "All", "Off", "Near", "ko", "en", "Grade", true, false, "x", {} }
	for _ = 1, 300 do
		local blob = { Keys = {}, V = rnd:NextInteger(1, 4) } -- A23-78 / A23-91: V1 to V4 blobs
		for _, id in ids do
			if rnd:NextNumber() < 0.3 then blob.Keys[id] = keyPool[rnd:NextInteger(1, #keyPool)] end
		end
		for k in SETTINGS_DEFS do
			if rnd:NextNumber() < 0.6 then blob[k] = anyPool[rnd:NextInteger(1, #anyPool)] end
		end
		if rnd:NextNumber() < 0.3 then blob.Junk = 1 end
		local before = deepCopy(blob)
		local r = S(blob)
		check(deepEq(blob, before), "SanitizeSettings never changes its input", show(blob))
		local rk = {}
		for k in r do rk[k] = true end
		check(deepEq(rk, fieldSet) and r.V == 4, "output fields are exactly V, Keys and the settings (Music too, A23-100)", show(rk))
		check(SFX_GRID[r.Sfx] == true, "Sfx is always on the 0.1 grid inside 0..1", tostring(r.Sfx))
		if type(blob.Sfx) == "number" and blob.Sfx == blob.Sfx and math.abs(blob.Sfx) ~= math.huge then
			check(math.abs(r.Sfx - math.clamp(blob.Sfx, 0, 1)) <= 0.05 + 1e-9, "Sfx = the nearest step of the clamped value", tostring(blob.Sfx))
		else
			check(r.Sfx == 1, "a non-finite / non-number Sfx -> 1", tostring(blob.Sfx))
		end
		for k, def in SETTINGS_DEFS do
			if def.Type == "Bool" then
				-- A23-78: a V1 blob's KeyBadges is the default (off) whatever it held
				local kept = type(blob[k]) == "boolean" and not (k == "KeyBadges" and blob.V < 2)
				check(r[k] == (if kept then blob[k] else SETTINGS_DEFAULTS[k]),
					"bools: a boolean is kept, anything else is the default", k .. " " .. tostring(blob[k]) .. " V" .. blob.V)
			elseif def.Type == "Enum" then
				-- A23-91: a blob before V4 gets the Cam default (Follow) whatever it held
				local valid = type(blob[k]) == "string" and table.find(def.Options, blob[k]) ~= nil and not (k == "Cam" and blob.V < 4)
				check(r[k] == (valid and blob[k] or SETTINGS_DEFAULTS[k]), "enums: an option is kept, anything else is the default",
					k .. " " .. tostring(blob[k]))
			end
		end
		local used = {}
		for id, v in r.Keys do
			check(C.Keybinds.ById[id] ~= nil and type(v) == "string" and (v == "" or EXPECTED_USABLE[v] == true) and v ~= defaultOf(C, id),
				"saved keys: known action ids, '' or a usable key, never the default", id .. "=" .. tostring(v))
			check(blob.Keys[id] == v or v == "", "a saved key always comes from the blob (or is blanked by the one-key rule)", id)
			if v ~= "" and SKILL_FLAGS[id] == nil then
				check(used[v] == nil, "no two Flag-on actions save the same key", v)
				used[v] = id
			end
		end
		check(deepEq(S(r), r), "SanitizeSettings is idempotent", show(r))
	end
end)

------------------------------------------------------------------ 4b. A23-78 key hints: settings V2 migration
-- user 2026-10-08: key hints off by default. Saves written before settings V2 still carry the old KeyBadges = true;
-- SanitizeSettings drops it once (V < 2, no V, NaN) and keeps every other value; a V2 blob keeps the player's pick.
runGroup("a23-78 key hints migration", function()
	local S = CONFIG.SanitizeSettings
	check(CONFIG.Settings.Version == 4 and CONFIG.Data.Defaults.Settings.V == 4, "settings version 4 (Config.Settings + the default blob)",
		tostring(CONFIG.Settings.Version) .. " / " .. tostring(CONFIG.Data.Defaults.Settings.V))
	local old = S({ V = 1, KeyBadges = true, Sfx = 0.4, Shake = false, Tags = "Near", Lang = "en", BagSort = "Grade",
		Cam = "Free", DmgNum = "Off", Keys = { Map = "X" } })
	check(old.KeyBadges == false and old.V == 4, "an old V1 save with key hints on: off once, saved as V4", show(old))
	check(old.Sfx == 0.4 and old.Shake == false and old.Tags == "Near" and old.Lang == "en" and old.BagSort == "Grade"
		and old.Cam == "Follow" and old.DmgNum == "Off" and old.Keys.Map == "X",
		"every other V1 setting stays as it was (Cam: the V4 default, A23-91)", show(old))
	check(S({ KeyBadges = true }).KeyBadges == false, "no V (a blob from before BB2's V): key hints off", "")
	check(S({ V = 0 / 0, KeyBadges = true }).KeyBadges == false and S({ V = "2", KeyBadges = true }).KeyBadges == false
		and S({ V = 1.9, KeyBadges = true }).KeyBadges == false, "a broken V (NaN / a string / 1.9) counts as old", "")
	check(S({ V = 2, KeyBadges = true }).KeyBadges == true, "V2: key hints the player turned on stay on", "")
	check(S({ V = 7, KeyBadges = true }).KeyBadges == true, "a newer V keeps the pick too", "")
	check(S(old).KeyBadges == false and S(S(old)).V == 4, "sanitizing again changes nothing (the migration runs once)", "")
	local back = S({ V = old.V, KeyBadges = true, Sfx = old.Sfx })
	check(back.KeyBadges == true and back.Sfx == 0.4, "after the migration the player turns them on again: kept", show(back))
	check(S({ V = 1, KeyBadges = false }).KeyBadges == false and S({ V = 2, KeyBadges = false }).KeyBadges == false,
		"off stays off", "")
	-- DataService: an old row (V1 + true) loads with key hints off; the next visit keeps a V2 true
	local k = function(id) return CONFIG.Data.KeyPrefix .. tostring(id) end
	local f = dataWorld({
		[k(601)] = { Version = 3, Level = 3, Faction = "Halo", ClassChosen = true, TutorialStep = 99,
			Settings = { V = 1, Keys = {}, Sfx = 0.3, Shake = true, DmgNum = "All", Tags = "All", KeyBadges = true, Lang = "Auto",
				BagSort = "Default", Cam = "Follow" } },
		[k(602)] = { Version = 3, Level = 3, Faction = "Halo", ClassChosen = true, TutorialStep = 99,
			Settings = { V = 2, Keys = {}, Sfx = 0.3, Shake = true, DmgNum = "All", Tags = "All", KeyBadges = true, Lang = "Auto",
				BagSort = "Default", Cam = "Follow" } },
	})
	local d1 = f:Load(601)
	check(d1 ~= nil and d1.Settings.KeyBadges == false and d1.Settings.V == 4 and d1.Settings.Sfx == 0.3,
		"load: a V1 save with key hints on -> off, V4, the rest kept", d1 and show(d1.Settings))
	local d2 = f:Load(602)
	check(d2 ~= nil and d2.Settings.KeyBadges == true and d2.Settings.V == 4, "load: a V2 save keeps key hints on",
		d2 and show(d2.Settings))
end)

------------------------------------------------------------------ 4c. A23-91 camera: settings V4 migration
-- user 2026-10-09 ("콘솔 게임처럼"): the console-style Follow is the default again. V3 (10/08-09) turned every save to Free;
-- SanitizeSettings gives a blob from before V4 (V < 4, no V, NaN) the Follow default once and keeps every other value; a
-- V4 blob keeps the player's pick (Free too).
runGroup("a23-91 camera migration", function()
	local S = CONFIG.SanitizeSettings
	check(CONFIG.Data.Defaults.Settings.Cam == "Follow", "the default camera is Follow (A23-91)", tostring(CONFIG.Data.Defaults.Settings.Cam))
	local old = S({ V = 3, Cam = "Free", KeyBadges = true, Sfx = 0.4, Shake = false, Tags = "Near", Lang = "en", BagSort = "Grade",
		DmgNum = "Off", Keys = { Map = "X" } })
	check(old.Cam == "Follow" and old.V == 4, "a V3 save on Free: Follow once, saved as V4", show(old))
	check(old.KeyBadges == true and old.Sfx == 0.4 and old.Shake == false and old.Tags == "Near" and old.Lang == "en"
		and old.BagSort == "Grade" and old.DmgNum == "Off" and old.Keys.Map == "X", "every other V3 setting stays as it was", show(old))
	check(S({ V = 1, Cam = "Free" }).Cam == "Follow" and S({ Cam = "Free" }).Cam == "Follow", "V1 / no V on Free: Follow", "")
	check(S({ V = 0 / 0, Cam = "Free" }).Cam == "Follow" and S({ V = "4", Cam = "Free" }).Cam == "Follow"
		and S({ V = 3.9, Cam = "Free" }).Cam == "Follow", "a broken V (NaN / a string / 3.9) counts as old", "")
	check(S({ V = 4, Cam = "Free" }).Cam == "Free", "V4: a Free the player picked stays", "")
	check(S({ V = 8, Cam = "Free" }).Cam == "Free", "a newer V keeps the pick too", "")
	check(S(old).Cam == "Follow" and S(S(old)).V == 4, "sanitizing again changes nothing (the migration runs once)", "")
	local back = S({ V = old.V, Cam = "Free", Sfx = old.Sfx })
	check(back.Cam == "Free" and back.Sfx == 0.4, "after the migration the player picks Free again: kept", show(back))
	check(S({ V = 3, Cam = "Follow" }).Cam == "Follow" and S({ V = 4, Cam = "Follow" }).Cam == "Follow", "Follow stays Follow", "")
	-- DataService: a V3 row on Free loads Follow; a V4 row on Free stays Free
	local k = function(id) return CONFIG.Data.KeyPrefix .. tostring(id) end
	local f = dataWorld({
		[k(611)] = { Version = 3, Level = 3, Faction = "Halo", ClassChosen = true, TutorialStep = 99,
			Settings = { V = 3, Keys = {}, Sfx = 0.3, Shake = true, DmgNum = "All", Tags = "All", KeyBadges = true, Lang = "Auto",
				BagSort = "Default", Cam = "Free" } },
		[k(612)] = { Version = 3, Level = 3, Faction = "Halo", ClassChosen = true, TutorialStep = 99,
			Settings = { V = 4, Keys = {}, Sfx = 0.3, Shake = true, DmgNum = "All", Tags = "All", KeyBadges = false, Lang = "Auto",
				BagSort = "Default", Cam = "Free" } },
	})
	local d1 = f:Load(611)
	check(d1 ~= nil and d1.Settings.Cam == "Follow" and d1.Settings.V == 4 and d1.Settings.KeyBadges == true and d1.Settings.Sfx == 0.3,
		"load: a V3 save on Free -> Follow, V4, the rest kept", d1 and show(d1.Settings))
	local d2 = f:Load(612)
	check(d2 ~= nil and d2.Settings.Cam == "Free" and d2.Settings.V == 4, "load: a V4 save keeps Free", d2 and show(d2.Settings))
end)

------------------------------------------------------------------ 5. DataService (old saves, Version 3, round trip)
runGroup("dataservice-settings", function()
	local k = function(id) return CONFIG.Data.KeyPrefix .. tostring(id) end
	local rows = {
		[k(501)] = { Version = 3, Level = 4, Faction = "Halo", Class = "Warrior", ClassChosen = true, TutorialStep = 99 },
		[k(502)] = { Version = 3, Level = 2, Faction = "Horns", ClassChosen = true, TutorialStep = 99,
			Settings = { V = 9, Keys = { Attack = "Escape", Map = "X", Menu = "X", Nope = "Y" }, Sfx = 0 / 0, Shake = "no", DmgNum = 3,
				Tags = "Near", Lang = "en", BagSort = "Grade", Junk = { 1, 2 } } },
		[k(503)] = { Version = 3, Level = 1, TutorialStep = 99, Settings = "broken" },
		[k(504)] = { Version = 2, Level = 7, Faction = "Halo", Class = "Mage", ClassChosen = true, TutorialStep = 99, Quests = {} },
	}
	local f = dataWorld(rows)
	local d1 = f:Load(501)
	check(d1 ~= nil and deepEq(d1.Settings, SETTINGS_DEFAULTS), "BB2: an old save without Settings loads with the defaults",
		d1 and show(d1.Settings))
	check(d1 ~= nil and d1.Version == 3, "Version stays 3", d1 and d1.Version)
	local d2 = f:Load(502)
	check(d2 ~= nil and deepEq(d2.Settings, { V = 4, Keys = { Map = "X", Menu = "" }, Sfx = 1, Music = 1, Shake = true, DmgNum = "All", Tags = "Near",
		KeyBadges = false, Lang = "en", BagSort = "Grade", Cam = "Follow", PvPCards = false }), "a broken Settings blob is repaired field by field on load", d2 and show(d2.Settings))
	local d3 = f:Load(503)
	check(d3 ~= nil and deepEq(d3.Settings, SETTINGS_DEFAULTS), "Settings = a string -> the defaults", d3 and show(d3.Settings))
	local d4 = f:Load(504)
	check(d4 ~= nil and d4.Version == 3 and deepEq(d4.Settings, SETTINGS_DEFAULTS), "a v2 save migrates to v3 with default Settings",
		d4 and show({ d4.Version, d4.Settings }))
	-- round trip: a changed blob is saved and comes back on the next visit
	local d, p = f:Load(505)
	check(d ~= nil and deepEq(d.Settings, SETTINGS_DEFAULTS), "a brand-new player starts with the defaults")
	if d then
		d.Settings = f.Config.SanitizeSettings({ Sfx = 0.4, Keys = { Attack = "J", Map = "" }, Lang = "en" })
		check(f.DS.Save(p, false) == true, "DataService.Save works")
		local row = f.Rows[f:Key(505)]
		check(row and deepEq(row.Settings, d.Settings), "the saved row holds the settings", row and show(row.Settings))
		local again = dataWorld(deepCopy(f.Rows))
		local back = again:Load(505)
		check(back ~= nil and deepEq(back.Settings, d.Settings) and back.Version == 3, "the next visit (another server) loads the same settings",
			back and show(back.Settings))
	end
end)

------------------------------------------------------------------ 6. SettingsService remotes
runGroup("service-remote", function()
	local s = serverWorld()
	local C = s.Config
	-- PlayerReady push
	local saved = C.SanitizeSettings({ Sfx = 0.3, Keys = { Attack = "J" } })
	local p = s:Join({ Version = 3, Settings = deepCopy(saved) })
	local q = s:Join()
	local toP = s:SentTo(p)
	check(#toP == 1 and toP[1].Payload.Seq == 0 and deepEq(toP[1].Payload.Settings, saved),
		"PlayerReady: one push { Seq = 0, saved settings }", show(toP))
	check(#s:SentTo(q) == 1, "every player gets their own push")
	for _, e in s.Sent do check(e.Player ~= "ALL", "Settings is never sent to all clients") end
	-- zero arguments = send me mine
	s.Clock:Advance(2)
	local before = #s.Sent
	s:Call(p)
	local last = s.Sent[#s.Sent]
	check(#s.Sent == before + 1 and last.Player == p and last.Payload.Seq == 0 and deepEq(last.Payload.Settings, s.Data[p].Settings),
		"zero arguments: echo { Seq = 0, my settings } to me only", show(last))
	-- argument count and type
	s.Clock:Advance(2)
	local snap = deepCopy(s.Data[p].Settings)
	before = #s.Sent
	s:Call(p, { Seq = 5, Sfx = 0.1 }, "extra")
	check(#s.Sent == before and deepEq(s.Data[p].Settings, snap), "two arguments: refused (nothing saved, nothing sent)")
	for _, bad in { "Sfx", 5, true } do
		s:Call(p, bad)
		check(#s.Sent == before and deepEq(s.Data[p].Settings, snap), "a non-table blob is refused", tostring(bad))
	end
	s:Call(p, nil)
	check(#s.Sent == before, "one nil argument is not 'zero arguments' (refused)")
	-- blob size
	local big = { Seq = 1, Sfx = 0.1 }
	for i = 1, 15 do big["J" .. i] = i end
	check(count(big) == 17, "fixture: 17-key blob")
	s:Call(p, big)
	check(#s.Sent == before and deepEq(s.Data[p].Settings, snap), "a blob with more than 16 top-level keys is refused")
	big.J15 = nil
	s:Call(p, big)
	local e = s.Sent[#s.Sent]
	check(#s.Sent == before + 1 and e.Payload.Seq == 1 and s.Data[p].Settings.Sfx == 0.1 and s.Data[p].Settings.J1 == nil,
		"a 16-key blob is accepted (junk dropped) and echoed", show(e and e.Payload))
	-- Seq clamp
	local seqCases = { { -5, 0 }, { 2 ^ 40, 2 ^ 31 }, { 3.7, 3 }, { 0 / 0, 0 }, { "7", 0 }, { math.huge, 2 ^ 31 }, { -math.huge, 0 }, { 12, 12 } }
	for _, c in seqCases do
		s.Clock:Advance(1.1)
		before = #s.Sent
		s:Call(p, { Seq = c[1], Sfx = 0.2 })
		local got = s.Sent[#s.Sent]
		check(#s.Sent == before + 1 and got.Payload.Seq == c[2], "Seq: an integer clamped to 0..2^31 (missing / NaN / string = 0)",
			tostring(c[1]) .. " -> " .. tostring(got and got.Payload.Seq))
	end
	-- rate limit (Config.RateLimits.SetSettings = 1): a dropped call gets no answer and changes nothing
	s.Clock:Advance(1.1)
	s:Call(p, { Seq = 20, Sfx = 0.5 })
	before = #s.Sent
	s:Call(p, { Seq = 21, Sfx = 0.6 })
	check(#s.Sent == before and s.Data[p].Settings.Sfx == 0.5, "a second call inside 1 s is dropped silently (nothing saved or sent)")
	s.Clock:Advance(0.5)
	s:Call(p, { Seq = 22, Sfx = 0.7 })
	check(#s.Sent == before and s.Data[p].Settings.Sfx == 0.5, "still inside 1 s after 0.5 s: dropped")
	s.Clock:Advance(0.55)
	s:Call(p, { Seq = 23, Sfx = 0.8 })
	check(#s.Sent == before + 1 and s.Data[p].Settings.Sfx == 0.8 and s.Sent[#s.Sent].Payload.Seq == 23,
		"1.05 s after the last accepted call: accepted (dropped calls never extend the wait)")
	-- not ready
	local r = s:Join(nil, false)
	before = #s.Sent
	s:Call(r, { Seq = 1, Sfx = 0.2 })
	s:Call(r)
	check(#s.Sent == before and s.Data[r].Settings.Sfx == 1, "a player who is not ready gets nothing and saves nothing")
	s:MakeReady(r)
	check(#s:SentTo(r) == 1, "becoming ready pushes the settings once")
	s:Call(r, { Seq = 2, Sfx = 0.4 })
	check(s.Data[r].Settings.Sfx == 0.4 and #s:SentTo(r) == 2, "calls made before ready do not use up the rate limit")
	-- the BB2 test values, sanitized before saving; the echo is what was saved
	s.Clock:Advance(1.1)
	s:Call(p, { Seq = 30, Keys = { Attack = "Escape", Map = "X", Menu = "X", Foo = "Y", Bag = string.rep("A", 1000) }, Sfx = 5,
		Shake = "yes", DmgNum = "Near", Tags = "Near", Lang = string.rep("한", 1000), Foo = 1 })
	local want = { V = 4, Keys = { Map = "X", Menu = "" }, Sfx = 1, Music = 1, Shake = true, DmgNum = "All", Tags = "Near", KeyBadges = false,
		Lang = "Auto", BagSort = "Default", Cam = "Follow", PvPCards = false }
	e = s.Sent[#s.Sent]
	check(deepEq(s.Data[p].Settings, want), "BB2 test values (Escape, Sfx 5, unknown key, 1000-char string, two actions one key) are cleaned before saving",
		show(s.Data[p].Settings))
	check(e.Player == p and e.Payload.Seq == 30 and deepEq(e.Payload.Settings, want), "the echo carries the cleaned value and the blob's Seq",
		show(e.Payload))
	-- owner only
	for _, x in s.Sent do
		if x.Name == "Settings" then
			check(x.Player == p or x.Player == q or x.Player == r, "every Settings send has one owner")
		end
	end
	check(#s:SentTo(q) == 1, "another player's calls are never sent to me")
	-- SettingsService.Get / KeyMap
	local t = s:Join({ Version = 3 })
	check(deepEq(s.Service.Get(t), SETTINGS_DEFAULTS) and deepEq(s.Data[t].Settings, SETTINGS_DEFAULTS), "Get repairs a missing Settings table")
	check(s.Service.KeyMap(p).Map == "X" and s.Service.KeyMap(p).Menu == "" and s.Service.KeyMap(p).Attack == "F", "KeyMap(player) = Config.KeyMap of the saved keys")
	-- a player whose data is gone (left): no error, nothing sent
	local gone = s:Join()
	s.Data[gone] = nil
	before = #s.Sent
	s.Clock:Advance(1.1)
	s:Call(gone, { Seq = 1, Sfx = 0.3 })
	check(#s.Sent == before and s.Service.Get(gone) == nil, "no data (player left): nothing sent, no error")
end)

------------------------------------------------------------------ 7. Keybinds lookups
runGroup("keybinds-core", function()
	local w = clientWorld()
	local K = w.KB
	check(K.Get("Attack") == ENUM.KeyCode.F and K.Get("Map") == ENUM.KeyCode.M and K.Get("PotionHP") == ENUM.KeyCode.One,
		"Get(action) = the Enum.KeyCode of the default key")
	check(K.Get("SkillZ") == nil and K.Get("Bag") == nil and K.Get("Nope") == nil, "Get = nil for unbound / non-live / unknown actions")
	for _, pair in { { "F", "Attack" }, { "Z", "SkillQ" }, { "R", "Auto" }, { "T", "GhostHold" }, { "One", "PotionHP" }, { "Two", "PotionMP" },
		{ "G", "Interact" }, { "U", "Upgrade" }, { "M", "Map" }, { "B", "Menu" } } do
		check(K.ActionFor(key(pair[1])) == pair[2], "default keys F Z R T 1 2 G U M B -> their actions (the 10/08 layout)",
			pair[1] .. " -> " .. tostring(K.ActionFor(key(pair[1]))))
	end
	-- user 2026-10-08: the Soon window keys answer before their windows exist (like their HUD tiles)
	for _, pair in { { "E", "Character" }, { "K", "Skills" }, { "L", "Ranking" }, { "Q", "Journal" } } do
		check(K.ActionFor(key(pair[1])) == pair[2] and K.IsLive(pair[2]), "Soon window keys E K L Q are live before their windows",
			pair[1] .. " -> " .. tostring(K.ActionFor(key(pair[1]))))
	end
	for _, n in { "I", "H", "J", "X", "C", "W", "Escape" } do
		check(K.ActionFor(key(n)) == nil, "keys of windows that do not exist yet (bag, help), the flagged skills and free keys do nothing", n)
	end
	check(K.ActionFor(pad("ButtonR2")) == "Attack" and K.ActionFor(pad("ButtonL2")) == "SkillQ", "pad R2 = attack, L2 = skill (as before BB1)")
	for _, b in { "ButtonR1", "ButtonL1", "DPadUp", "DPadDown", "DPadLeft", "DPadRight", "ButtonX", "ButtonY" } do
		check(K.ActionFor(pad(b)) == nil, "the other pad buttons are data only until BB21", b)
	end
	check(K.ActionFor({ UserInputType = ENUM.UserInputType.Gamepad1, KeyCode = ENUM.KeyCode.F }) == nil
		and K.ActionFor({ UserInputType = ENUM.UserInputType.Keyboard, KeyCode = ENUM.KeyCode.ButtonR2 }) == nil,
		"keyboard keys only from the keyboard, pad buttons only from Gamepad1")
	check(K.ActionFor({ UserInputType = ENUM.UserInputType.MouseButton1, KeyCode = ENUM.KeyCode.Unknown }) == nil and K.ActionFor(nil) == nil
		and K.ActionFor({ UserInputType = ENUM.UserInputType.Keyboard, KeyCode = "F" }) == nil, "mouse / nil / malformed input -> nil")
	check(K.PadFor("Attack") == ENUM.KeyCode.ButtonR2 and K.PadFor("Menu") == ENUM.KeyCode.ButtonY and K.PadFor("Upgrade") == nil
		and K.PadFor("Nope") == nil, "PadFor = the fixed pad button (nil when none)")
	check(K.Label("Auto") == "R" and K.Label("PotionHP") == "1" and K.Label("Bag") == "None" and K.Label("Nope") == "",
		"Label: key labels on keyboards ('1' for One, None when unbound)", show({ K.Label("Auto"), K.Label("PotionHP"), K.Label("Bag") }))
	-- touch-only device (A23-21): button names instead of keys
	w.UIS.TouchEnabled, w.UIS.KeyboardEnabled = true, false
	for _, a in w.Config.Keybinds.Actions do
		check(K.Label(a.Id) == a.Button, "touch-only: Label = the button name", a.Id .. " " .. tostring(K.Label(a.Id)))
	end
	check(K.Fill(w.Config.Text.GhostButton, true) == "Ghost grab", "touch-only: the '(T)' key part is hidden", K.Fill(w.Config.Text.GhostButton, true))
	w.UIS.KeyboardEnabled = true -- touch laptop with a keyboard: keys again
	check(K.Label("Auto") == "R", "touch screen + keyboard: key labels")
	w.UIS.TouchEnabled = false
	-- English
	w.ST.Set("Lang", "en")
	check(K.Label("Bag") == "None", "Lang = en: unbound = None")
	w.UIS.TouchEnabled, w.UIS.KeyboardEnabled = true, false
	check(K.Label("Auto") == w.Config.Keybinds.ById.Auto.ButtonEn, "Lang = en on touch: ButtonEn")
	w.UIS.TouchEnabled, w.UIS.KeyboardEnabled = false, true
	w.ST.Set("Lang", "Auto")
	-- text tokens
	check(K.Fill(w.Config.Text.GhostButton, true) == "Ghost grab (T)" and K.Fill("{Auto}키") == "R키" and K.Fill("{Foo}") == "{Foo}",
		"Fill: '{GhostHold}' -> T, '{Auto}' -> R, unknown tokens stay")
	check(K.StripKeys(w.Config.Text.GhostButton) == "Ghost grab", "StripKeys drops the '(T)' group")
	check(#K.Collisions() == 0 and K.IsCapturing() == false, "no collisions by default; not capturing")
	check(K.IsLive("Attack") and not K.IsLive("Bag") and not K.IsLive("SkillZ") and K.IsLive("Journal"),
		"IsLive: Flag on and (windows) registered or Soon")
	check(K.WindowFor("Bag") == "Bag" and K.WindowFor("Journal") == "Journal" and K.WindowFor("Attack") == nil and K.WindowFor("Menu") == nil,
		"WindowFor: the Panels id of a window action only")
end)

------------------------------------------------------------------ 8. Keybinds.SetLocal / Clear / Reset / Apply
runGroup("keybinds-setlocal", function()
	local w = clientWorld()
	w:Echo(0, {})
	local K = w.KB
	local fires = w.ChangedFires
	local ok, reason, other = K.SetLocal("Attack", "Z")
	check(ok == true and reason == "Swap" and other == "SkillQ", "SetLocal onto a live holder's key = swap", show({ ok, reason, other }))
	check(K.KeyName("Attack") == "Z" and K.KeyName("SkillQ") == "F", "swap: the holder gets my old key", show({ K.KeyName("Attack"), K.KeyName("SkillQ") }))
	check(K.ActionFor(key("Z")) == "Attack" and K.ActionFor(key("F")) == "SkillQ", "the keys work at once")
	check(w.ChangedFires == fires + 1 and w.LastMap and w.LastMap.Attack == "Z", "Changed fires once with the new map")
	check(deepEq(w.ST.Get("Keys"), { Attack = "Z", SkillQ = "F" }), "Settings.Keys holds only the changes", show(w.ST.Get("Keys")))
	w.LastMap.Attack = "V"
	check(K.KeyName("Attack") == "Z", "the Changed map is a copy")
	ok, reason, other = K.SetLocal("Attack", ENUM.KeyCode.F)
	check(ok == true and reason == "Swap" and other == "SkillQ" and K.KeyName("Attack") == "F" and K.KeyName("SkillQ") == "Z",
		"swap back with an Enum.KeyCode argument", show({ ok, reason, other }))
	check(deepEq(w.ST.Get("Keys"), {}), "back on the defaults: nothing saved", show(w.ST.Get("Keys")))
	fires = w.ChangedFires
	ok, reason = K.SetLocal("Attack", "F")
	check(ok == true and reason == nil and w.ChangedFires == fires, "the current key again: ok, nothing changes")
	ok, reason = K.SetLocal("Map", "X")
	check(ok == true and reason == nil and K.KeyName("Map") == "X" and K.ActionFor(key("X")) == "Map" and K.ActionFor(key("M")) == nil,
		"a free key: set, the old key does nothing", show({ ok, reason, K.KeyName("Map") }))
	check(K.Clear("Upgrade") == true and K.KeyName("Upgrade") == "" and K.ActionFor(key("U")) == nil and K.Label("Upgrade") == "None"
		and K.Get("Upgrade") == nil, "Clear: no key (None), U does nothing")
	check(#K.Collisions() == 0 and w.ST.Get("Keys").Upgrade == "", "a cleared action is saved as '' and never reported")
	ok, reason, other = K.SetLocal("Upgrade", "R")
	check(ok == true and reason == "Swap" and other == "Auto" and K.KeyName("Auto") == "" and K.KeyName("Upgrade") == "R",
		"swap from an unbound action: the holder gets ''", show({ ok, reason, other, K.KeyName("Auto") }))
	local refusals = { { "W", "Reserved" }, { "Escape", "Reserved" }, { "Space", "Reserved" }, { "F9", "Reserved" }, { "Tab", "Reserved" },
		{ "Home", "NotAllowed" }, { "Keypad1", "NotAllowed" }, { "RightControl", "NotAllowed" }, { string.rep("A", 30), "NotAllowed" },
		{ 5, "NotAllowed" }, { nil, "NotAllowed" } }
	for _, c in refusals do
		local beforeKeys = w.ST.Get("Keys")
		ok, reason = K.SetLocal("Attack", c[1])
		check(ok == false and reason == c[2] and deepEq(w.ST.Get("Keys"), beforeKeys) and K.KeyName("Attack") == "F",
			"Reserved / not Allowed keys are refused and change nothing", tostring(c[1]) .. " " .. show({ ok, reason }))
	end
	for _, id in { "Bag", "SkillZ", "Nope" } do
		ok, reason = K.SetLocal(id, "X")
		check(ok == false and reason == "NotLive", "non-live / unknown actions cannot be set", id .. " " .. show({ ok, reason }))
		check(K.Clear(id) == false, "non-live / unknown actions cannot be cleared", id)
	end
	fires = w.ChangedFires
	K.Reset()
	local allDefault = true
	for _, want in CONTRACT_ACTIONS do
		local expected = (SKILL_FLAGS[want[1]] or (WINDOWS[want[1]] and not SOON[want[1]])) and "" or want[2]
		if K.KeyName(want[1]) ~= expected then allDefault = false end
	end
	check(allDefault and deepEq(w.ST.Get("Keys"), {}) and w.ChangedFires == fires + 1, "Reset: every key back to the default (Changed once)")
	fires = w.ChangedFires
	K.Apply({})
	check(w.ChangedFires == fires, "Apply with the same keys: no Changed")
	K.Apply({ Attack = "V" })
	check(w.ChangedFires == fires + 1 and K.KeyName("Attack") == "V", "Apply with new keys: Changed once")
	K.Apply({ Attack = "Escape" })
	check(K.KeyName("Attack") == "F", "Apply cleans the keys (Escape -> the default)")
end)

------------------------------------------------------------------ 9. live set (Panels registration, Flag)
runGroup("keybinds-live", function()
	local w = clientWorld()
	w:Echo(0, {})
	local K = w.KB
	check(K.ActionFor(key("I")) == nil and K.ActionFor(key("T")) == "GhostHold", "before the bag exists: I does nothing, T = ghost hold")
	-- the bag key opens the older Items window until a Bag window is registered (Alt, the HUD tile's rule)
	w.Registered.Items = true
	K.Refresh()
	check(K.ActionFor(key("I")) == "Bag" and K.IsLive("Bag") and K.WindowFor("Bag") == "Items",
		"Items registered (Alt): I = bag, it opens Items", show({ K.ActionFor(key("I")), K.WindowFor("Bag") }))
	w.Registered.Items = nil
	K.Refresh()
	check(K.ActionFor(key("I")) == nil and K.WindowFor("Bag") == "Bag", "Items gone: I does nothing again")
	w.Registered.Bag = true
	local fires = w.ChangedFires
	K.Refresh()
	check(K.ActionFor(key("I")) == "Bag" and K.IsLive("Bag") and w.ChangedFires == fires + 1,
		"Refresh after Panels registers Bag: I = bag (Changed fired)")
	w.Registered.Items = true
	check(K.WindowFor("Bag") == "Bag", "its own window wins over the Alt once both exist")
	w.Registered.Items = nil
	check(K.ActionFor(key("T")) == "GhostHold", "I = bag only, T = ghost hold")
	local ok, reason, other = K.SetLocal("Attack", "I")
	check(ok and reason == "Swap" and other == "Bag" and K.KeyName("Bag") == "F", "a window key swaps like any key", show({ ok, reason, other }))
	w.Registered.Bag = nil
	K.Refresh()
	check(K.KeyName("Bag") == "" and K.KeyName("Attack") == "I" and K.ActionFor(key("F")) == nil,
		"a window that is no longer registered holds no key")
	-- a saved key of a window that is not registered must not block a later live action (BB1: non-live actions hold no key
	-- and take no part in swaps)
	local w2 = clientWorld()
	w2:Echo(0, { Keys = { Bag = "X" } })
	check(w2.KB.KeyName("Bag") == "" and w2.KB.KeyName("Map") == "M" and w2.KB.ActionFor(key("X")) == nil,
		"a saved key of an unregistered window holds nothing")
	local ok2, reason2 = w2.KB.SetLocal("Map", "X")
	check(ok2 == true and w2.KB.KeyName("Map") == "X" and w2.KB.ActionFor(key("X")) == "Map",
		"SetLocal(Map, X) gives Map the key X although the unregistered Bag window has X saved",
		show({ ok = ok2, reason = reason2, map = w2.KB.KeyName("Map"), saved = w2.ST.Get("Keys") }))
	check(deepEq(w2.ST.Get("Keys"), { Map = "X" }), "the stale Bag entry on X goes back to its default (not '')", show(w2.ST.Get("Keys")))
	local ok3 = w2.KB.SetLocal("Attack", "X")
	check(ok3 == true and w2.KB.KeyName("Attack") == "X", "the same with an action before Bag in the Actions order")
	w2.Registered.Bag = true
	w2.KB.Refresh()
	check(w2.KB.KeyName("Bag") == "I" and #w2.KB.Collisions() == 0, "once registered, Bag gets its default key I")
	-- a stale entry on the key the swapped holder receives (my old key) must not blank that holder
	local w3 = clientWorld()
	w3:Echo(0, { Keys = { Bag = "F" } })
	local ok4, reason4, other4 = w3.KB.SetLocal("Attack", "M")
	check(ok4 == true and reason4 == "Swap" and other4 == "Map" and w3.KB.KeyName("Attack") == "M" and w3.KB.KeyName("Map") == "F"
		and w3.KB.ActionFor(key("F")) == "Map", "swap: the holder gets my old key although an unregistered window has it saved",
		show({ ok4, reason4, other4, w3.KB.KeyName("Map"), w3.ST.Get("Keys") }))
	check(w3.ST.Get("Keys").Bag == nil, "and that stale entry goes back to its default", show(w3.ST.Get("Keys")))
	-- Flag on: the Z skill is live (its pad button is not wired yet)
	local xw = clientWorld({ XEnabled = true })
	check(xw.KB.ActionFor(key("C")) == "SkillX" and xw.KB.Label("SkillX") == "C" and xw.KB.ActionFor(key("X")) == nil,
		"Config.Skills.XEnabled (SKL-1): C = SkillX, X (the Z skill's key) stays free while ZEnabled is off")
	local z = clientWorld({ ZEnabled = true })
	check(z.KB.ActionFor(key("X")) == "SkillZ" and z.KB.ActionFor(pad("ButtonL1")) == nil and z.KB.Label("SkillZ") == "X",
		"Config.Skills.ZEnabled: X = SkillZ")
	-- every window registered at Start
	local all = clientWorld({ Windows = ALL_WINDOWS })
	for _, pair in { { "I", "Bag" }, { "E", "Character" }, { "K", "Skills" }, { "L", "Ranking" }, { "H", "Help" }, { "Q", "Journal" } } do
		check(all.KB.ActionFor(key(pair[1])) == pair[2], "registered windows: I E K L H Q open their windows", pair[1])
	end
	-- user 2026-10-08: I = the bag, so Roblox's I camera zoom is sunk above the camera (O stays the camera's)
	local sink = all.CAS.Bound.HH_CameraKeySink
	check(sink ~= nil and #sink.Inputs == 1 and sink.Inputs[1] == ENUM.KeyCode.I and sink.Priority == 3000
		and sink.Fn() == ENUM.ContextActionResult.Sink, "the bag key I is sunk above the camera's zoom (only I, O stays free)",
		sink and show({ sink.Priority, #sink.Inputs }))
	all.KB.SetLocal("Bag", "V")
	check(all.CAS.Bound.HH_CameraKeySink == nil, "the bag moved off I: no sink, Roblox zooms on I again")
	check(all.KB.SetLocal("Map", "O") == false and all.CAS.Bound.HH_CameraKeySink == nil,
		"O stays Roblox's zoom (reserved): it cannot be set, nothing sunk")
	all.KB.SetLocal("Bag", "I")
	check(all.CAS.Bound.HH_CameraKeySink ~= nil, "the bag back on I: sunk again")
	-- 10/08 Play check: a CAS-sunk key reaches UserInputService as processed (the real I opened nothing), so the sink
	-- hands the press on itself as not processed and the UserInputService copy is skipped
	local seenB, seenE = {}, {}
	all.KB.Began:Connect(function(i, gp) table.insert(seenB, { i, gp }) end)
	all.KB.Ended:Connect(function(i, gp) table.insert(seenE, { i, gp }) end)
	local fn = all.CAS.Bound.HH_CameraKeySink.Fn
	local res = fn("HH_CameraKeySink", ENUM.UserInputState.Begin, key("I"))
	fn("HH_CameraKeySink", ENUM.UserInputState.End, key("I"))
	check(res == ENUM.ContextActionResult.Sink and #seenB == 1 and seenB[1][2] == false and seenB[1][1].KeyCode == ENUM.KeyCode.I
		and #seenE == 1 and seenE[1][2] == false, "the sink hands the I press on as not processed (HUD opens the bag)",
		show({ #seenB, #seenE }))
	all.UIS.InputBegan:Fire(key("I"), true)
	all.UIS.InputEnded:Fire(key("I"), true)
	check(#seenB == 1 and #seenE == 1, "the UserInputService copy of a sunk key is skipped (one press, never two)",
		show({ #seenB, #seenE }))
	all.UIS.InputBegan:Fire(key("K"), false)
	check(#seenB == 2, "the other keys still come through UserInputService", #seenB)
	local focused = all.UIS.GetFocusedTextBox
	all.UIS.GetFocusedTextBox = function() return {} end
	check(fn("HH_CameraKeySink", ENUM.UserInputState.Begin, key("I")) == ENUM.ContextActionResult.Pass and #seenB == 2,
		"typing in a TextBox: the sink passes I on (no bag)")
	all.UIS.GetFocusedTextBox = focused
	local plain = clientWorld()
	check(plain.CAS.Bound.HH_CameraKeySink == nil, "no action on I / O (the bag window not there yet): nothing sunk")
end)

------------------------------------------------------------------ 10. collisions + the once-per-session toast
runGroup("keybinds-collisions", function()
	local w = clientWorld({ Windows = ALL_WINDOWS })
	local K = w.KB
	check(#w.Toasts == 0, "no toast on a clean start")
	w:Echo(0, { Keys = { Attack = "Q" } })
	check(K.KeyName("Attack") == "Q" and K.KeyName("Journal") == "" and deepEq(K.Collisions(), { "Journal" }),
		"BB2: saved Attack = Q keeps Q; Journal = 없음 and is reported", show({ K.KeyName("Attack"), K.KeyName("Journal"), K.Collisions() }))
	local want = string.format(w.Config.Settings.Text.KeyCollision, "Quest list", "Q")
	check(#w.Toasts == 1 and w.Toasts[1].Text == want, "one toast: 'New action [Quest list] has no key: …'", show(w.Toasts))
	w:Echo(0, { Keys = { Attack = "Q" } })
	K.Refresh()
	K.Apply({ Attack = "Q" })
	check(#w.Toasts == 1, "the toast shows once per action per session", #w.Toasts)
	K.Apply({ Attack = "Q", Menu = "M" })
	check(K.KeyName("Map") == "" and #w.Toasts == 2 and string.find(w.Toasts[2].Text, "[Map]", 1, true) ~= nil,
		"another action's collision gets its own toast", show(w.Toasts))
	local c = K.Collisions()
	table.insert(c, "Junk")
	check(#K.Collisions() == 2, "Collisions() returns a copy")
	-- Init alone (before Start) never toasts; Start shows the pending collision once
	local late = clientWorld({ Windows = ALL_WINDOWS, NoStart = true })
	late.ST.Set("Keys", { Attack = "Q" })
	late.KB.Apply({ Attack = "Q" })
	check(#late.Toasts == 0, "no toast before Start")
	late:Start()
	check(#late.Toasts == 1, "Start shows the pending collision toast once", #late.Toasts)
end)

------------------------------------------------------------------ 11. key capture (BB3 API)
runGroup("keybinds-capture", function()
	local w = clientWorld()
	w:Echo(0, {})
	local K = w.KB
	local res = {}
	local function cb(...) table.insert(res, table.pack(...)) end
	check(K.Capture("Map", cb) == true and K.IsCapturing() and w.PPS.Enabled == false, "Capture: capturing, interact prompts off")
	local b = w:Capture()
	check(b ~= nil and b.Priority >= 4000 and b.Inputs[1] == ENUM.UserInputType.Keyboard, "the capture sinks keyboard keys at priority 4000+",
		b and show({ b.Priority }))
	local sunk = b and b.Fn("capture", ENUM.UserInputState.Begin, key("X"))
	check(sunk == ENUM.ContextActionResult.Sink, "the captured key is sunk")
	check(res[1] and res[1][1] == "Set" and res[1][2] == "X" and K.KeyName("Map") == "X" and not K.IsCapturing() and w.PPS.Enabled == true
		and w:Capture() == nil, "a free key: Set, the binding is removed, prompts on again", show(res[1]))
	res = {}
	K.Capture("Attack", cb)
	w:Capture().Fn("capture", ENUM.UserInputState.Begin, key("Z"))
	check(res[1] and res[1][1] == "Swap" and res[1][2] == "Z" and res[1][3] == "SkillQ" and K.KeyName("SkillQ") == "F",
		"a held key: Swap (the other action reported)", show(res[1]))
	check(w.Toasts[#w.Toasts] and w.Toasts[#w.Toasts].Text == string.format(w.Config.Settings.Text.Swapped, "Z", "F"),
		"swap toast names both keys", show(w.Toasts[#w.Toasts]))
	for _, c in { { "W", "Reserved", "Reserved" }, { "Space", "Reserved", "Reserved" }, { "Home", "NotAllowed", "NotAllowed" } } do
		res = {}
		local beforeKey = K.KeyName("Attack")
		K.Capture("Attack", cb)
		w:Capture().Fn("capture", ENUM.UserInputState.Begin, key(c[1]))
		check(res[1] and res[1][1] == c[2] and K.KeyName("Attack") == beforeKey and not K.IsCapturing()
			and w.Toasts[#w.Toasts].Text == w.Config.Settings.Text[c[3]], "refused key: result + toast, key unchanged", c[1] .. " " .. show(res[1]))
	end
	res = {}
	K.Capture("Attack", cb)
	w:Capture().Fn("capture", ENUM.UserInputState.Begin, key("Escape"))
	check(res[1] and res[1][1] == "Cancel" and not K.IsCapturing(), "Esc cancels")
	res = {}
	K.Capture("Attack", cb)
	w.Clock:Advance(5.2)
	check(res[1] and res[1][1] == "Timeout" and not K.IsCapturing() and w.PPS.Enabled == true, "5 s without a key: Timeout")
	res = {}
	K.Capture("Attack", cb)
	w.Gui.MenuOpened:Fire()
	check(res[1] and res[1][1] == "Cancel" and not K.IsCapturing(), "the Roblox menu (Esc) cancels")
	check(K.Capture("Bag", cb) == false and not K.IsCapturing() and w.PPS.Enabled == true, "a non-live action cannot be captured")
end)

------------------------------------------------------------------ 12. prompts + Dispatch / input forwarding
runGroup("keybinds-prompts-dispatch", function()
	local w = clientWorld({ NoStart = true })
	local early = w:Prompt(false)
	w:Start()
	w:Echo(0, {})
	local K = w.KB
	check(early.KeyboardKeyCode == ENUM.KeyCode.G, "prompts already in the world use the Interact key (G since 10/08)")
	K.SetLocal("Interact", "Y")
	local late = w:Prompt(true)
	local shown = { __kind = "Instance", ClassName = "ProximityPrompt", KeyboardKeyCode = ENUM.KeyCode.E, Parent = w.Workspace,
		IsA = function(_, kind) return kind == "ProximityPrompt" end }
	w.PPS.PromptShown:Fire(shown)
	check(early.KeyboardKeyCode == ENUM.KeyCode.Y and late.KeyboardKeyCode == ENUM.KeyCode.Y and shown.KeyboardKeyCode == ENUM.KeyCode.Y,
		"a changed Interact key re-applies to every prompt (existing, added, shown)")
	-- review of 27246d1: Interact can never be emptied (NoClear) and only takes keys the prompt UI draws
	local cleared, why = K.Clear("Interact")
	check(cleared == false and why == "NoClear" and early.KeyboardKeyCode == ENUM.KeyCode.Y,
		"Interact cannot be cleared: prompts keep their key", show({ cleared, why }))
	for _, bad in { "CapsLock", "KeypadOne", "Minus" } do
		local okSet, reason = K.SetLocal("Interact", bad)
		check(okSet == false and reason == "NotAllowed" and early.KeyboardKeyCode == ENUM.KeyCode.Y,
			"Interact refuses keys the prompt UI cannot draw (" .. bad .. ")", show({ okSet, reason }))
	end
	local began, ended = {}, {}
	K.Began:Connect(function(i, gp) table.insert(began, { i, gp }) end)
	K.Ended:Connect(function(i, gp) table.insert(ended, { i, gp }) end)
	check(K.Dispatch({ KeyCode = ENUM.KeyCode.F }) == "Attack" and #began == 1 and #ended == 1 and began[1][2] == false
		and ended[1][1].UserInputState == ENUM.UserInputState.End, "Dispatch: press + release through Began / Ended, returns the action")
	check(K.Dispatch({ KeyCode = ENUM.KeyCode.ButtonR2, UserInputType = ENUM.UserInputType.Gamepad1, State = "Begin", GameProcessed = true }) == "Attack"
		and #began == 2 and #ended == 1 and began[2][2] == true, "Dispatch: pad input, Begin only, gameProcessed passed on")
	check(K.Dispatch(nil) == nil and K.Dispatch({ KeyCode = "F" }) == nil and #began == 2, "Dispatch ignores malformed input")
	w.UIS.InputBegan:Fire(key("Q"), true)
	w.UIS.InputEnded:Fire(key("Q"), false)
	check(#began == 3 and began[3][2] == true and #ended == 2, "every UserInputService press / release is forwarded (with gameProcessed)")
end)

------------------------------------------------------------------ 13. Settings client (pending blob, rate, echoes)
runGroup("settings-client", function()
	local w = clientWorld({ NoStart = true })
	local ST = w.ST
	-- a server that answers every blob 0.08 s later with that blob (the pull is answered by hand below)
	w.Wire = function(name, args)
		local b = args[1]
		if name == "SetSettings" and args.n == 1 and type(b) == "table" then
			w.Clock:Delay(0.08, function() w:Echo(b.Seq, w.Config.SanitizeSettings(b)) end)
		end
	end
	local flags = {}
	ST.Changed:Connect(function(_, fromServer) table.insert(flags, fromServer) end)
	w:Start()
	check(#w.Sends == 1 and w.Sends[1].Name == "SetSettings" and w.Sends[1].N == 0, "Start pulls once: SetSettings with zero arguments",
		show(w.Sends))
	check(ST.Loaded() == false, "not loaded before the server answers")
	check(ST.Set("Sfx", 0.5) == true and ST.Get("Sfx") == 0.5 and flags[#flags] == false, "Set works locally at once (Changed fromServer = false)")
	w.Clock:Advance(3)
	check(#w.Sends == 1, "nothing is sent before the first server value")
	w:Echo(0, { Sfx = 1, Shake = false, Keys = { Map = "X" } })
	check(ST.Loaded() and ST.Get("Sfx") == 0.5 and ST.Get("Shake") == false and ST.Get("Keys").Map == "X",
		"first server value: the server wins, except my unsent change", show(ST.All()))
	check(flags[#flags] == true, "Changed fromServer = true for an echo")
	check(#w.Sends == 2 and w.Sends[2].N == 1 and w.Sends[2].Blob.Seq == 1 and w.Sends[2].Blob.Sfx == 0.5 and w.Sends[2].Blob.Shake == false,
		"the waiting change goes out once the first value arrived (Seq 1, full blob)", show(w.Sends[2]))
	local blob = w.Sends[2].Blob or {}
	local bk = {}
	for k in blob do bk[k] = true end
	check(count(blob) <= 16 and deepEq(bk, { V = true, Keys = true, Sfx = true, Music = true, Shake = true, DmgNum = true, Tags = true, KeyBadges = true,
		Lang = true, BagSort = true, Cam = true, PvPCards = true, Seq = true }), "the blob = the sanitized settings + Seq (<= 16 keys)", show(bk))
	check(ST.Set("Nope", 1) == false and ST.Set("Seq", 3) == false, "unknown fields are refused")
	w.Clock:Advance(3)
	local n = #w.Sends
	ST.Set("Sfx", 5)
	check(ST.Get("Sfx") == 1, "Set cleans like the server (Sfx 5 -> 1)")
	w.Clock:Advance(3)
	n = #w.Sends
	check(ST.Set("Keys", { Attack = "Escape", Map = "X" }) == true, "Set(Keys) with a reserved key")
	w.Clock:Advance(3)
	check(#w.Sends == n and ST.Get("Keys").Attack == nil, "a cleaned value equal to the current one sends nothing")
	-- rapid changes: one send per 1.05 s, the last value always goes out
	local spamStart = #w.Sends
	for i = 1, 12 do
		ST.Set("Sfx", (i % 10) / 10)
		w.Clock:Advance(0.25)
	end
	w.Clock:Advance(3)
	local interval = w.Config.RateLimits.SetSettings + 0.05
	local okGap, worst = true, math.huge
	for i = 2, #w.Sends do
		local gap = w.Sends[i].At - w.Sends[i - 1].At
		worst = math.min(worst, gap)
		if gap < interval - 1e-9 then okGap = false end
	end
	check(okGap, "never two sends inside RateLimits.SetSettings + 0.05 s (pull included)", worst)
	check(#w.Sends - spamStart <= 5, "12 changes in 3 s -> at most 5 sends", #w.Sends - spamStart)
	check(w.Sends[#w.Sends].Blob.Sfx == ST.Get("Sfx") and ST.Get("Sfx") == 0.2, "the last change always goes out", show(w.Sends[#w.Sends].Blob))
	-- change, then close the window 0.3 s later (Flush): no second send inside the limit, the last change is sent
	ST.Set("Tags", "Near")
	local tA = w.Sends[#w.Sends].At
	check(w.Sends[#w.Sends].Blob.Tags == "Near", "a change with a free slot goes out at once")
	w.Clock:Advance(0.3)
	ST.Set("Tags", "Off")
	w.Clock:Advance(0.3)
	n = #w.Sends
	ST.Flush()
	check(#w.Sends == n, "Flush inside the limit does not send at once")
	w.Clock:Advance(2)
	check(#w.Sends == n + 1 and w.Sends[#w.Sends].Blob.Tags == "Off" and w.Sends[#w.Sends].At - tA >= interval - 1e-9,
		"Flush: the pending blob goes out at the slot time (one send)", show({ #w.Sends - n, w.Sends[#w.Sends].At - tA }))
	-- echoes
	local seq = w.Sends[#w.Sends].Blob.Seq
	local fires = #flags
	w:Echo(seq - 1, { Sfx = 0, Tags = "All" })
	check(ST.Get("Sfx") == 0.2 and ST.Get("Tags") == "Off" and #flags == fires, "an echo older than the newest Seq sent is ignored",
		show(ST.All()))
	w:Echo(seq, { Sfx = 0.7, Tags = "Off", Lang = "ko" })
	check(ST.Get("Lang") == "ko" and ST.Get("Sfx") == 0.7 and flags[#flags] == true, "the newest echo: the server value wins")
	w.Clock:Advance(2)
	ST.Set("Sfx", 0.9)
	local sentSeq = w.Sends[#w.Sends].Blob.Seq
	ST.Set("BagSort", "Count")
	w:Echo(sentSeq, { Sfx = 0.9, BagSort = "Default", Lang = "ko", Tags = "Off" })
	check(ST.Get("BagSort") == "Count" and ST.Get("Sfx") == 0.9, "a change still waiting to be sent survives an echo", show(ST.All()))
	w.Clock:Advance(2)
	check(w.Sends[#w.Sends].Blob.BagSort == "Count" and w.Sends[#w.Sends].Blob.Seq == sentSeq + 1, "and goes out next")
	local junk = table.pack(nil, "x", { Seq = 99 }, { Seq = 99, Settings = "x" }, { Seq = 0 / 0, Settings = { Sfx = 0 } })
	for i = 1, junk.n do
		local beforeAll = ST.All()
		w.Remotes.Settings.OnClientEvent:Fire(junk[i])
		check(deepEq(ST.All(), beforeAll), "malformed Settings payloads are ignored", show(junk[i]))
	end
	-- review: a blob the server drops (its 1 s limit is measured on arrival) gets no echo -> it is sent again
	local d = clientWorld()
	d:Echo(0, {})
	d.Clock:Advance(2) -- the pull's slot is over
	d.ST.Set("Sfx", 0.4)
	local first = #d.Sends
	local firstSeq = d.Sends[first].Blob and d.Sends[first].Blob.Seq or -1
	check(first == 2 and d.Sends[first].Blob.Sfx == 0.4, "the change goes out", show(d.Sends))
	d.Clock:Advance(2.9)
	check(#d.Sends == first, "no resend while the echo may still come (slot + 2 s)", #d.Sends - first)
	d.Clock:Advance(0.3)
	local re = d.Sends[#d.Sends]
	check(#d.Sends == first + 1 and re.Blob.Sfx == 0.4 and re.Blob.Seq == firstSeq + 1,
		"no echo: the same value goes out again with a new Seq", show(re))
	d:Echo(re.Blob.Seq, re.Blob)
	d.Clock:Advance(20)
	check(#d.Sends == first + 1 and d.ST.Get("Sfx") == 0.4, "the echo of the newest blob ends the resends", #d.Sends - first)
	-- only an older echo arrives: the newest blob is still resent in full
	d.ST.Set("Shake", false) -- s1 now (the slot is free)
	local s1 = d.Sends[#d.Sends].Blob.Seq
	d.Clock:Advance(0.3)
	d.ST.Set("Tags", "Off") -- s2 at the next slot (s1 + 1.05 s)
	d.Clock:Advance(0.9)
	local s2 = d.Sends[#d.Sends].Blob.Seq
	d:Echo(s1, { Sfx = 0.4, Shake = false }) -- older than s2: ignored
	check(d.ST.Get("Tags") == "Off", "the older echo changes nothing")
	d.Clock:Advance(3.5) -- s2 + 3.05 s: no echo for s2
	local last = d.Sends[#d.Sends]
	check(s2 == s1 + 1 and last.Blob.Seq == s2 + 1 and last.Blob.Tags == "Off" and last.Blob.Shake == false and last.Blob.Sfx == 0.4,
		"an older echo does not count: the newest blob is resent in full", show({ s1, s2, last.Blob }))
	local okGap = true
	for i = 2, #d.Sends do
		if d.Sends[i].At - d.Sends[i - 1].At < d.Config.RateLimits.SetSettings + 0.05 - 1e-9 then okGap = false end
	end
	check(okGap, "resends keep the 1.05 s send slot")
	d:Echo(last.Blob.Seq, last.Blob)
	-- a server that never answers (its data is gone): a few resends, then quiet until the next change
	local e = clientWorld()
	e:Echo(0, {})
	e.Clock:Advance(2)
	e.ST.Set("Sfx", 0.3)
	local base = #e.Sends
	e.Clock:Advance(120)
	check(#e.Sends - base == 5, "no answer at all: 5 resends, then it stops", #e.Sends - base)
	e.ST.Set("Sfx", 0.6)
	check(#e.Sends - base == 6 and e.Sends[#e.Sends].Blob.Sfx == 0.6, "the next change is sent again", #e.Sends - base)
end)

------------------------------------------------------------------ 14. client + server over a fake network
runGroup("integration", function()
	local saved = CONFIG.SanitizeSettings({ Keys = { Attack = "Q" }, Sfx = 0.3 })
	local L = linkedWorld({ Windows = ALL_WINDOWS, Data = { Version = 3, Settings = deepCopy(saved) } })
	local client, server, p = L.Client, L.Server, L.Player
	client:Start()
	L.Clock:Advance(0.5)
	check(client.ST.Loaded() == false and #server.Sent == 0, "the pull reaches the server before the player is ready: no answer")
	server:MakeReady(p)
	L.Clock:Advance(0.5)
	check(client.ST.Loaded() and client.ST.Get("Sfx") == 0.3 and client.KB.KeyName("Attack") == "Q" and client.KB.KeyName("Journal") == "",
		"PlayerReady push: saved keys + settings arrive (Attack Q, Journal 없음)")
	check(#client.Toasts == 1, "the Journal collision is told once", #client.Toasts)
	-- change a key, close the window 0.3 s later
	client.KB.SetLocal("Map", "N")
	L.Clock:Advance(0.3)
	client.ST.Flush()
	L.Clock:Advance(3)
	check(server.Data[p].Settings.Keys.Map == "N" and server.Data[p].Settings.Keys.Attack == "Q", "the key change is saved on the server",
		show(server.Data[p].Settings.Keys))
	-- spam: 20 changes in 2 s
	for i = 1, 20 do
		client.ST.Set("Sfx", (i % 11) / 10)
		L.Clock:Advance(0.1)
	end
	L.Clock:Advance(4)
	local echoes = 0
	local last, okGap = nil, true
	for _, e in server.Sent do
		if e.Name == "Settings" and e.Player == p then
			echoes += 1
			if not e.Push then
				if last and e.At - last < 1 - 1e-9 then okGap = false end
				last = e.At
			end
		end
	end
	local accepted = echoes - server.Pushes
	check(server.Calls - 1 == accepted, "no call is dropped by the server's 1 s limit (every call after the early pull is answered)",
		show({ calls = server.Calls, accepted = accepted }))
	check(okGap, "the server handles at most one call per second")
	check(server.Data[p].Settings.Sfx == 0.9 and client.ST.Get("Sfx") == 0.9 and deepEq(server.Data[p].Settings, client.ST.All()),
		"after the spam the server holds exactly the client's last value", show({ server.Data[p].Settings.Sfx, client.ST.Get("Sfx") }))
	-- rejoin on another server: the same keys and settings
	local again = linkedWorld({ Windows = ALL_WINDOWS, Data = { Version = 3, Settings = deepCopy(server.Data[p].Settings) } })
	again.Server:MakeReady(again.Player)
	again.Client:Start()
	again.Clock:Advance(2)
	check(again.Client.KB.KeyName("Map") == "N" and again.Client.KB.KeyName("Attack") == "Q" and again.Client.ST.Get("Sfx") == 0.9,
		"rejoin: the keys and settings are the same")
	-- network jitter beyond the 0.05 s margin (finding only: the contract fixes the margin)
	local up = { 0.08, 0.3, 0.05 }
	local upIndex = 0
	local J = linkedWorld({ Data = { Version = 3, Settings = CONFIG.SanitizeSettings(nil) }, Latency = function(dir)
		if dir == "down" then return 0.08 end
		upIndex += 1
		return up[math.min(upIndex, #up)]
	end })
	J.Server:MakeReady(J.Player)
	J.Client:Start()
	J.Clock:Advance(2)
	J.Client.ST.Set("Sfx", 0.1)
	J.Clock:Advance(0.1)
	J.Client.ST.Set("Sfx", 0.2)
	J.Clock:Advance(1.5)
	local droppedSeq = J.Client.Sends[#J.Client.Sends].Blob and J.Client.Sends[#J.Client.Sends].Blob.Seq
	local answered = false
	for _, ev in J.Server.Sent do
		if ev.Name == "Settings" and ev.Payload and ev.Payload.Seq == droppedSeq then answered = true end
	end
	check(not answered and J.Server.Data[J.Player].Settings.Sfx == 0.1,
		"jitter: blobs sent 1.05 s apart reach the server 0.80 s apart, the second is dropped (no answer)",
		show({ droppedSeq, J.Server.Data[J.Player].Settings.Sfx }))
	J.Clock:Advance(6)
	check(J.Server.Data[J.Player].Settings.Sfx == 0.2 and J.Client.ST.Get("Sfx") == 0.2,
		"jitter: the client sends the dropped blob again, the last change is saved",
		show({ J.Server.Data[J.Player].Settings.Sfx, J.Client.ST.Get("Sfx") }))
end)

------------------------------------------------------------------ 15. Net names (real Net source)
runGroup("net-names", function()
	local net = execute("Net", NET_SOURCE, { game = { GetService = function(_, n) return { Name = n } end } })
	check(table.find(net.Names, "SetSettings") ~= nil and table.find(net.Names, "Settings") ~= nil, "Net.Names has SetSettings and Settings")
	local seen, dup = {}, nil
	for _, n in net.Names do
		if seen[n] then dup = n end
		seen[n] = true
	end
	check(dup == nil, "no duplicate remote names", dup)
end)

------------------------------------------------------------------ 16. key hints: one rule (review B5, 2026-10-06)
-- Every key badge / key hint asks Keybinds.ShowsKeys() (= UserInputService.KeyboardEnabled == true): a touch laptop with a
-- keyboard shows keys; a phone, a tablet with a mouse but no keyboard and a gamepad do not. Keybinds runs for real. The HUD
-- quest-row filler (L.QuestText), WorldMap.ShowsKeys / HintText, both map-hint blocks (BindKey, Open), Intro's TXT table
-- and Intro.SkipText are cut from the CURRENT sources by tools/test_keys_settings.py (SNIPPETS) and run against it; each
-- chunk is loaded again per device, as the module would load on that device.
local HINT_DEVICES = {
	{ Name = "desktop: keyboard + mouse", Keyboard = true, Touch = false, Mouse = true },
	{ Name = "touch laptop: keyboard + touch + mouse", Keyboard = true, Touch = true, Mouse = true },
	{ Name = "tablet with a keyboard, no mouse", Keyboard = true, Touch = true, Mouse = false },
	{ Name = "phone: touch only", Keyboard = false, Touch = true, Mouse = false },
	{ Name = "tablet with a mouse, no keyboard", Keyboard = false, Touch = true, Mouse = true },
	{ Name = "gamepad / console: no keyboard, no touch", Keyboard = false, Touch = false, Mouse = false },
}
-- WorldMap TXT double (the real strings live in WorldMap.luau; only the {Map} token matters here)
local WM_TXT = { HintMouse = "드래그: 이동 · 휠: 확대/축소 · {Map} / Esc: 닫기", HintTouch = "드래그: 이동 · 두 손가락: 확대/축소" }
local SNIPPET_NAMES = { "HudQuestText", "WorldMapFns", "WorldMapBindHint", "WorldMapOpenHint", "IntroTxt", "IntroSkipText" }

-- runs one cut chunk in env (globals behind it); returns its value or nil + why
local function snippet(name, env)
	local code = type(SNIPPETS) == "table" and SNIPPETS[name] or nil
	if type(code) ~= "string" or code == "" then return nil, name .. " not found in the source" end
	local fn, err = loadstring(code, "=" .. name)
	if not fn then return nil, err end
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	local ok, out = pcall(fn)
	if not ok then return nil, out end
	return out
end

runGroup("key-hints-one-rule", function()
	for _, name in SNIPPET_NAMES do
		check(type(SNIPPETS) == "table" and type(SNIPPETS[name]) == "string" and SNIPPETS[name] ~= "",
			"the key-hint code is found in HUD / WorldMap / Intro (cut for these behaviour checks)", name)
	end
	for _, d in HINT_DEVICES do
		local keys = d.Keyboard -- the one rule
		local w = clientWorld({ Device = d })
		w:Echo(0, {})
		local K = w.KB
		local ById = w.Config.Keybinds.ById
		local autoBtn = ById.Auto.Button
		-- Keybinds (touchOnly = not ShowsKeys)
		check(K.ShowsKeys() == keys, "Keybinds.ShowsKeys() = KeyboardEnabled (touch laptop: yes; phone, mouse tablet, gamepad: no)",
			d.Name .. " " .. tostring(K.ShowsKeys()))
		check(K.Label("Auto") == (keys and "R" or autoBtn) and K.Label("PotionHP") == (keys and "1" or ById.PotionHP.Button),
			"Keybinds.Label: key labels exactly where keys are shown, button names on every device without a keyboard",
			d.Name .. " " .. show({ K.Label("Auto"), K.Label("PotionHP") }))
		local ghost, auto = K.Fill(w.Config.Text.GhostButton, true), K.Fill("{Auto}키")
		check(ghost == (keys and "Ghost grab (T)" or "Ghost grab") and auto == (keys and "R키" or autoBtn .. "키"),
			"Keybinds.Fill: the '(T)' key part and '{Auto}' follow ShowsKeys", d.Name .. " " .. show({ ghost, auto }))
		local cw = clientWorld({ Device = d, Windows = ALL_WINDOWS })
		cw:Echo(0, { Keys = { Attack = "Q" } })
		check(deepEq(cw.KB.Collisions(), { "Journal" }) and #cw.Toasts == (keys and 1 or 0),
			"the key-collision toast shows only where keys are shown", d.Name .. " " .. show(cw.Toasts))
		-- HUD quest rows (L.QuestText; IS_TOUCH / UserInputService are there only for the old device test)
		local hud, hudErr = snippet("HudQuestText", { C = w.C, Config = w.Config, IS_TOUCH = d.Touch, UserInputService = w.UIS })
		local row = "자동 전투 켜기 ({Auto})"
		local q1 = hud and hud.QuestText(row)
		check(q1 == (keys and "자동 전투 켜기 (R)" or "자동 전투 켜기 (" .. autoBtn .. ")"),
			"HUD L.QuestText: the current key where keys are shown, the button name without a keyboard",
			d.Name .. " " .. tostring(q1 or hudErr))
		K.Clear("Auto")
		local q2 = hud and hud.QuestText(row)
		check(q2 == (keys and "자동 전투 켜기" or "자동 전투 켜기 (" .. autoBtn .. ")"),
			"HUD L.QuestText: an unbound key drops the '(…)' group only where keys are shown", d.Name .. " " .. tostring(q2 or hudErr))
		K.Reset()
		-- WorldMap hint
		local hintKeys = "드래그: 이동 · 휠: 확대/축소 · M / Esc: 닫기"
		local wm, wmErr = snippet("WorldMapFns", { C = w.C, UserInputService = w.UIS, TXT = WM_TXT })
		-- HintText is only shown where keys are shown (its {Map} would read as the button name elsewhere)
		check(wm ~= nil and wm.ShowsKeys() == keys and (not keys or wm.HintText() == hintKeys),
			"WorldMap.ShowsKeys() = Keybinds.ShowsKeys(); HintText names the map key", d.Name .. " " .. tostring(wmErr))
		local env = { WorldMap = wm, TXT = WM_TXT, UserInputService = w.UIS, C = w.C }
		local openHint, openErr = snippet("WorldMapOpenHint", env)
		local label = { Text = "" }
		if openHint and wm then pcall(openHint, label) end
		check(label.Text == (keys and hintKeys or WM_TXT.HintTouch),
			"WorldMap.Open: the key hint where keys are shown, the touch hint without a keyboard",
			d.Name .. " " .. tostring(openErr or label.Text))
		local bindHint, bindErr = snippet("WorldMapBindHint", env)
		label = { Text = "BEFORE" }
		if bindHint and wm then pcall(bindHint, label) end
		check(label.Text == (keys and hintKeys or "BEFORE"),
			"WorldMap.BindKey: the new map key goes into the hint only where keys are shown",
			d.Name .. " " .. tostring(bindErr or label.Text))
		local early = snippet("WorldMapFns", { C = {}, UserInputService = w.UIS, TXT = WM_TXT })
		check(early ~= nil and early.ShowsKeys() == d.Keyboard, "WorldMap.ShowsKeys before Keybinds is up = KeyboardEnabled", d.Name)
		-- Intro skip button
		local txt, txtErr = snippet("IntroTxt", { STORY = {}, UserInputService = w.UIS })
		local intro, introErr = nil, txtErr
		if txt then intro, introErr = snippet("IntroSkipText", { C = w.C, TXT = txt, UserInputService = w.UIS }) end
		local skip = intro and intro.SkipText()
		check(skip == "Skip ▶" .. (keys and " (Enter)" or ""), "Intro.SkipText: '(Enter)' exactly where keys are shown",
			d.Name .. " " .. tostring(skip or introErr))
		local introEarly = txt and snippet("IntroSkipText", { C = {}, TXT = txt, UserInputService = w.UIS })
		local skipEarly = introEarly and introEarly.SkipText()
		check(skipEarly == "Skip ▶" .. (d.Keyboard and " (Enter)" or ""),
			"Intro.SkipText before Keybinds is up: '(Enter)' only with a keyboard", d.Name .. " " .. tostring(skipEarly))
	end
end)

------------------------------------------------------------------ 17. Interact keeps a key the prompt draws (review of 27246d1)
-- Keybinds.SetLocal swap guard: another action may take Interact's key only when Interact can hold that action's old key
-- (Interact: NoClear + prompt keys only). Keybinds.Capture refuses keys the action cannot hold before SetLocal, with a toast.
runGroup("keybinds-interact-guard", function()
	local w = clientWorld()
	w:Echo(0, {})
	local K = w.KB
	local prompt = w:Prompt(true)
	local G, V = ENUM.KeyCode.G, ENUM.KeyCode.V
	check(prompt.KeyboardKeyCode == G and K.KeyName("Interact") == "G", "start: Interact = G, the prompt draws G")
	for _, old in { "CapsLock", "KeypadOne", "Minus", "" } do
		local tag = old == "" and "(none)" or old
		K.Reset()
		if old == "" then K.Clear("Attack") else K.SetLocal("Attack", old) end
		local saved = deepCopy(w.ST.Get("Keys"))
		local fires = w.ChangedFires
		local ok, reason, other = K.SetLocal("Attack", "G")
		check(K.KeyName("Attack") == old and ok == false and reason == "NotAllowed" and other == nil,
			"swap guard: an action whose old key Interact cannot hold (CapsLock, KeypadOne, Minus, none) cannot take G",
			tag .. " " .. show({ ok = ok, reason = reason, other = other, attack = K.KeyName("Attack"), interact = K.KeyName("Interact") }))
		check(K.KeyName("Interact") == "G" and K.KeyName("Attack") == old and K.ActionFor(key("G")) == "Interact"
			and prompt.KeyboardKeyCode == G and deepEq(w.ST.Get("Keys"), saved) and #K.Collisions() == 0 and w.ChangedFires == fires,
			"a refused swap changes nothing: Interact and its prompt keep G, nothing saved, no collision, no Changed",
			tag .. " " .. show({ K.KeyName("Interact"), K.KeyName("Attack"), w.ST.Get("Keys"), K.Collisions() }))
	end
	K.Reset()
	K.SetLocal("Attack", "V")
	local ok, reason, other = K.SetLocal("Attack", "G")
	check(ok == true and reason == "Swap" and other == "Interact" and K.KeyName("Attack") == "G" and K.KeyName("Interact") == "V"
		and prompt.KeyboardKeyCode == V, "swap guard lets a key the prompt draws through: Attack V -> G, Interact and its prompt get V",
		show({ ok, reason, other, K.KeyName("Interact") }))
	K.Reset()
	K.SetLocal("Attack", "CapsLock")
	ok, reason = K.SetLocal("Interact", "CapsLock")
	check(ok == false and reason == "NotAllowed" and K.KeyName("Interact") == "G" and K.KeyName("Attack") == "CapsLock"
		and prompt.KeyboardKeyCode == G, "Interact cannot be swapped onto another action's key the prompt cannot draw (CapsLock)",
		show({ ok, reason }))
	K.Reset()
	ok, reason, other = K.SetLocal("Interact", "Z")
	check(ok == true and reason == "Swap" and other == "SkillQ" and K.KeyName("Interact") == "Z" and K.KeyName("SkillQ") == "G"
		and prompt.KeyboardKeyCode == ENUM.KeyCode.Z, "Interact swapped onto a drawable key (Z): the holder gets G, the prompt Z",
		show({ ok, reason, other }))
	-- capture (BB3): keys Interact cannot hold are refused with a NotAllowed toast; V is taken
	K.Reset()
	local res = {}
	local function cb(...) table.insert(res, table.pack(...)) end
	for _, bad in { "CapsLock", "KeypadOne", "" } do
		local tag = bad == "" and "(empty)" or bad
		res = {}
		local toasts = #w.Toasts
		local started = K.Capture("Interact", cb)
		local b = w:Capture()
		if b then b.Fn("capture", ENUM.UserInputState.Begin, key(bad)) end
		check(started == true and res[1] ~= nil and res[1][1] == "NotAllowed" and res[1][2] == bad and not K.IsCapturing()
			and w.PPS.Enabled == true, "capture refuses keys Interact cannot hold (CapsLock, KeypadOne, empty): NotAllowed",
			tag .. " " .. show(res[1]))
		local last = w.Toasts[#w.Toasts]
		check(#w.Toasts == toasts + 1 and last ~= nil and last.Text == w.Config.Settings.Text.NotAllowed and last.Kind == "bad",
			"the capture refusal tells the player (one NotAllowed toast)", tag .. " " .. show(last))
		check(K.KeyName("Interact") == "G" and prompt.KeyboardKeyCode == G and deepEq(w.ST.Get("Keys"), {}),
			"a refused capture keeps Interact on G (its prompt too), nothing saved", tag .. " " .. show(w.ST.Get("Keys")))
	end
	res = {}
	local toasts = #w.Toasts
	check(K.Capture("Interact", cb) == true, "capture of Interact starts")
	local b = w:Capture()
	if b then b.Fn("capture", ENUM.UserInputState.Begin, key("V")) end
	check(res[1] ~= nil and res[1][1] == "Set" and res[1][2] == "V" and K.KeyName("Interact") == "V" and prompt.KeyboardKeyCode == V
		and #w.Toasts == toasts and deepEq(w.ST.Get("Keys"), { Interact = "V" }) and not K.IsCapturing(),
		"capture accepts V for Interact: Set, the prompt draws V, saved, no toast", show(res[1]))
end)

------------------------------------------------------------------ summary
local list = {}
for _, k in order do
	local r = results[k]
	table.insert(list, { Group = r.Group, Name = r.Name, Pass = r.Pass, Fail = r.Fail, FirstFailure = r.First })
end
local function enc(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then
		if v ~= v or math.abs(v) == math.huge then return "null" end
		return (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%d", v) or string.format("%.17g", v)
	end
	if t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c)
			return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" })[c] or string.format("\\u%04x", string.byte(c))
		end) .. '"'
	end
	if #v > 0 or next(v) == nil then
		local parts = {}
		for _, x in ipairs(v) do table.insert(parts, enc(x)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do table.insert(keys, k) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local parts = {}
	for _, k in keys do table.insert(parts, enc(tostring(k)) .. ":" .. enc(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end
print("KEYS_SETTINGS_RESULT_JSON " .. enc({ Checks = total, Failed = failedCount, Named = list, Findings = findings }))
if failedCount == 0 then
	print("KEYS_SETTINGS_OFFLINE_OK checks=" .. total .. " Studio/API calls=0")
else
	print("KEYS_SETTINGS_OFFLINE_FAILED checks=" .. total .. " failed=" .. failedCount)
end
