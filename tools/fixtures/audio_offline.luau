-- Offline checks for Audio.luau (quality ① sound effects to 검수's table, docs/design/lines_pack_2026-10-06.md §6). The
-- runner (tools/test_audio.py) prepends CONFIG_SOURCE and AUDIO_SOURCE (the current Config.luau / Audio.luau text).
-- Roblox is replaced by small doubles: Vector3 maths, Sound / Folder / SoundGroup instances (Play sets IsPlaying, the
-- test ends them), signals fired by hand, task.delay / task.spawn queues, a workspace.Monsters folder, a LocalPlayer
-- (with a character) and GameState with attributes, and the Fx / Notify / Quests remotes.
-- Every check is named (group :: check) and collected, never asserted. No Studio, Roblox API or network calls.

local Named, order = {}, {}
local checks, failed = 0, 0
local function check(group, name, ok, detail)
	checks += 1
	local key = group .. " :: " .. name
	local n = Named[key]
	if not n then
		n = { Group = group, Name = name, Pass = 0, Fail = 0 }
		Named[key] = n
		table.insert(order, key)
	end
	if ok then
		n.Pass += 1
	else
		n.Fail += 1
		failed += 1
		if not n.FirstFailure then n.FirstFailure = tostring(detail or "") end
		print(("CHECK_FAIL %s :: %s :: %s"):format(group, name, tostring(detail or "")))
	end
end

local function encode(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" then return (string.format("%.4f", v):gsub("%.?0+$", "")) end
	if t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			if c == '"' then return '\\"' end
			if c == "\\" then return "\\\\" end
			return string.format("\\u%04x", string.byte(c))
		end) .. '"'
	end
	if t ~= "table" then return '"' .. tostring(v) .. '"' end
	if #v > 0 or next(v) == nil then
		local parts = {}
		for _, x in ipairs(v) do table.insert(parts, encode(x)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do if type(k) ~= "table" then table.insert(keys, tostring(k)) end end
	table.sort(keys)
	local parts = {}
	for _, k in keys do table.insert(parts, encode(k) .. ":" .. encode(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end

----------------------------------------------------------------- engine doubles
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
local function rgb(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, __kind = "Color3" } end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function typeofDouble(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end

local function signal()
	local s = { Fns = {} }
	function s:Connect(fn)
		table.insert(self.Fns, fn)
		return { Disconnect = function() end }
	end
	function s:Once(fn) return self:Connect(fn) end
	function s:Fire(...)
		for _, fn in self.Fns do fn(...) end
	end
	return s
end

local function attrHolder(o)
	o.Attr = o.Attr or {}
	o.AttrSignals = {}
	function o:GetAttribute(k) return self.Attr[k] end
	function o:SetAttribute(k, v)
		self.Attr[k] = v
		local s = self.AttrSignals[k]
		if s then s:Fire() end
	end
	function o:GetAttributeChangedSignal(k)
		self.AttrSignals[k] = self.AttrSignals[k] or signal()
		return self.AttrSignals[k]
	end
	return o
end

local PLAYS = {} -- { Name, Id, Speed, Volume, Group } per Play()
local SOUNDS_MADE = {}
local function newInstance(class)
	local o = { __kind = "Instance", ClassName = class, Name = class, Children = {} }
	o.IsA = function(self, c) return c == self.ClassName or c == "Instance" end
	o.Destroy = function(self) self.Destroyed = true end
	if class == "Sound" then
		o.IsPlaying = false
		o.Volume, o.PlaybackSpeed, o.SoundId, o.TimePosition = 0.5, 1, "", 0
		o.Play = function(self)
			self.IsPlaying = true
			table.insert(PLAYS, { Name = self.Name, Id = self.SoundId, Speed = self.PlaybackSpeed, Volume = self.Volume,
				Group = self.SoundGroup and self.SoundGroup.Name or nil, Sound = self })
		end
		o.Stop = function(self) self.IsPlaying = false end
		table.insert(SOUNDS_MADE, o)
	end
	if class == "SoundGroup" then o.Volume = 1 end
	return o
end
local function endAll()
	for _, s in SOUNDS_MADE do s.IsPlaying = false end
end

local DELAYS = {}
local taskDouble = {
	spawn = function(fn, ...) fn(...) end,
	delay = function(t, fn, ...) table.insert(DELAYS, { T = t, Fn = fn, Args = table.pack(...) }) end,
	defer = function(fn, ...) fn(...) end,
	wait = function() return 0 end,
}
local function runDelays(maxT)
	local list = DELAYS
	DELAYS = {}
	for _, d in list do
		if d.T <= maxT then d.Fn(table.unpack(d.Args, 1, d.Args.n)) else table.insert(DELAYS, d) end
	end
end
local function waitClock(sec)
	local t0 = os.clock()
	while os.clock() - t0 < sec do end
end

local MONSTERS = { Name = "Monsters", Children = {} }
function MONSTERS:GetChildren() return self.Children end
local function addMonster(kind, x, z)
	local m = attrHolder({ __kind = "Instance", ClassName = "Model", Name = kind, Attr = { MonsterKind = kind } })
	m.IsA = function(_, c) return c == "Model" or c == "Instance" end
	m.GetPivot = function() return { Position = vec(x, 3, z) } end
	table.insert(MONSTERS.Children, m)
	return m
end
addMonster("Slime", 10, 0)
addMonster("Skeleton", 40, 0)
addMonster("Goblin", 80, 0)
addMonster("LittleGhost", 120, 0)
addMonster("Slime", 11, 1)
addMonster("Slime", 9, -1)
local CAMERA = { OnScreen = true } -- what WorldToViewportPoint answers for "on screen"
local WORKSPACE = { FindFirstChild = function(_, n) if n == "Monsters" then return MONSTERS end return nil end,
	CurrentCamera = { WorldToViewportPoint = function(_, p) return p, CAMERA.OnScreen end } }
local SERVER = { T = 1000 } -- Util.Now() (server time) for the world timers

local ME = 111
local ROOT = { Position = vec(0, 3, 0), IsA = function(_, c) return c == "BasePart" end }
local HUM = { Health = 100, MaxHealth = 100, IsA = function(_, c) return c == "Humanoid" end, StateChanged = signal() }
local CHAR = {
	FindFirstChild = function(_, n) if n == "HumanoidRootPart" then return ROOT end return nil end,
	FindFirstChildOfClass = function(_, c) if c == "Humanoid" then return HUM end return nil end,
	WaitForChild = function(_, n) if n == "Humanoid" then return HUM end return nil end,
}
-- AutoCombatEnabled and the potion counts arrive with the save (not there at the join)
local PLAYER = attrHolder({ UserId = ME, Name = "Me", Character = CHAR, CharacterAdded = signal(),
	Attr = { Faction = "Halo", DataLoaded = true, Honor = 3, Infamy = 0 } })
local GAMESTATE = attrHolder({ Name = "GameState", Attr = { PumpkinKingActive = false, GhostKingActive = false, GooseActive = false } })
local REMOTES = { Fx = { OnClientEvent = signal() }, Notify = { OnClientEvent = signal() }, Quests = { OnClientEvent = signal() },
	Announce = { OnClientEvent = signal() }, OpenPanel = { OnClientEvent = signal() }, PetList = { OnClientEvent = signal() } }
local HEART = signal()
local PRELOADED = 0

local function envFor()
	local services = {
		Players = { LocalPlayer = PLAYER },
		RunService = { Heartbeat = HEART, RenderStepped = signal() },
		SoundService = { Name = "SoundService" },
		ContentProvider = { PreloadAsync = function(_, list) PRELOADED += #list end },
		HttpService = { JSONDecode = function(_, s) return { decoded = s } end },
	}
	local shared = { WaitForChild = function(_, n) return { __module = n } end }
	services.ReplicatedStorage = { WaitForChild = function() return shared end }
	local game = { GetService = function(_, n) return services[n] or {} end }
	return { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec, zero = vec(0, 0, 0) },
		Color3 = { new = function(r, g, b) return rgb(r * 255, g * 255, b * 255) end, fromRGB = rgb,
			fromHSV = function() return rgb(0, 0, 0) end },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
		NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
		NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"),
		CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum, typeof = typeofDouble,
		game = game, workspace = WORKSPACE, task = taskDouble, print = function() end,
		Instance = { new = newInstance } }
end

local function execute(name, text, env)
	local fn, err = loadstring(text, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end

local function load()
	local env = envFor()
	local Config = execute("Config", CONFIG_SOURCE, env)
	local Net = { Get = function(n) return REMOTES[n] end, GameState = function() return GAMESTATE end }
	local Util = { Warn = function() end, Now = function() return SERVER.T end }
	env.require = function(m)
		local n = type(m) == "table" and m.__module
		if n == "Net" then return Net end
		if n == "Util" then return Util end
		return Config
	end
	local Audio = execute("Audio", AUDIO_SOURCE, env)
	return Audio, Config
end

local function events(plan)
	local out = {}
	for _, p in plan do table.insert(out, p.Event) end
	return table.concat(out, ",")
end
local function find(plan, event)
	for _, p in plan do
		if p.Event == event then return p end
	end
	return nil
end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

----------------------------------------------------------------- planning
local Audio, Config = load()
local A = Config.Audio
local ctx = { Me = ME, Faction = "Halo", Combo = 1, HP = 100, MaxHP = 100,
	KindAt = function(p)
		local best, bestD = nil, 8
		for _, m in MONSTERS.Children do
			local d = (m.GetPivot().Position - p).Magnitude
			if d < bestD then best, bestD = m.Attr.MonsterKind, d end
		end
		return best
	end,
	Near = function(p) return (p - vec(0, 3, 0)).Magnitude end }
local function swing(t)
	local d = { UserId = ME, Class = "Warrior", Manual = true, ContactDelay = 0.23, Pos = vec(5, 3, 0) }
	for k, v in t or {} do d[k] = v end
	return Audio.Plan("Swing", d, ctx)
end
local function hit(x, z, crit, k) return { P = vec(x, 3, z), A = 3, C = crit == true, K = k or "M" } end

do
	local g = "swing"
	local p = swing()
	check(g, "my manual Warrior swing = SwingWarrior now, full volume", #p == 1 and p[1].Event == "SwingWarrior"
		and p[1].At == 0 and near(p[1].Volume, 1) and near(p[1].SpeedMul, 1) and p[1].Auto == false, encode(p))
	p = swing({ Manual = false })
	check(g, "an auto swing is marked Auto (played at AutoMul)", p[1] and p[1].Auto == true, encode(p))
	p = swing({ Class = "Archer", LaunchDelay = 0.22 })
	check(g, "Archer: one SwingArrow when the arrow leaves (sound_gaps A1)", #p == 1 and p[1].Event == "SwingArrow"
		and near(p[1].At, 0.22), encode(p))
	p = swing({ Class = "Archer", LaunchDelay = 0.22, Hits = { hit(80, 0) } })
	check(g, "Archer: one target = one arrow", #p == 2 and p[1].Event == "SwingArrow" and p[2].Event == "HitHeavy", encode(p))
	p = swing({ Class = "Archer", LaunchDelay = 0.22, Hits = { hit(80, 0), hit(40, 0) } })
	local second = p[2]
	check(g, "Archer: 2+ targets = a second arrow 0.068 s later at 1.10x and 0.85 volume (§4-2 5)", p[1].Event == "SwingArrow"
		and second ~= nil and second.Event == "SwingArrow" and near(second.At, 0.22 + 0.068) and near(second.SpeedMul, 1.1)
		and near(second.Volume, 0.85), encode(p))
	p = swing({ Class = "Mage", LaunchDelay = 0.3 })
	check(g, "Halo mage: SwingMageHalo, its peak (0.20 s in) on the launch (sound_gaps A2)", p[1] and p[1].Event == "SwingMageHalo"
		and near(p[1].At, 0.1), encode(p))
	ctx.Faction = "Horns"
	p = swing({ Class = "Mage", LaunchDelay = 0.3 })
	check(g, "Horns mage: SwingMageHorns", p[1] and p[1].Event == "SwingMageHorns" and near(p[1].At, 0.1), encode(p))
	ctx.Faction = "Halo"
	local keep = A.Files.SwingMageHalo
	A.Files.SwingMageHalo = ""
	p = swing({ Class = "Mage", LaunchDelay = 0.3 })
	check(g, "a faction file not uploaded yet: the old SwingMage at once", p[1] and p[1].Event == "SwingMage" and p[1].At == 0, encode(p))
	A.Files.SwingMageHalo = keep
	ctx.Faction = "Neutral"
	p = swing({ Class = "Mage", LaunchDelay = 0.3 })
	check(g, "the Guild's alchemist: the old SwingMage at once", p[1] and p[1].Event == "SwingMage" and p[1].At == 0, encode(p))
	check(g, "Neutral Alchemist: 0.9x", near(swing({ Class = "Mage" })[1].SpeedMul, 0.9), "")
	check(g, "Neutral Blacksmith: 0.85x", near(swing({ Class = "Warrior" })[1].SpeedMul, 0.85), "")
	p = swing({ Class = "Archer", Style = "PetHeadbutt" })
	check(g, "pet tamer: SwingTamer at once", p[1] and p[1].Event == "SwingTamer" and p[1].At == 0, encode(p))
	ctx.Faction = "Halo"
	p = swing({ Style = "Punch" })
	check(g, "bare hands: a short Warrior swish (1.3x, 0.6 volume)", p[1] and p[1].Event == "SwingWarrior"
		and near(p[1].SpeedMul, 1.3) and near(p[1].Volume, 0.6), encode(p))
	p = swing({ UserId = 222, Pos = vec(20, 3, 0) })
	check(g, "another player's swing 20 studs away: Others", p[1] and p[1].Event == "SwingWarrior" and p[1].Others == true, encode(p))
	p = swing({ UserId = 222, Pos = vec(60, 3, 0) })
	check(g, "another player's swing 60 studs away is silent", #p == 0, encode(p))
	p = Audio.Plan("Swing", { UserId = 222, Class = "Warrior", Manual = true }, ctx)
	check(g, "another player's swing without a place is silent", #p == 0, encode(p))
end

do
	local g = "hits"
	local p = swing({ Hits = { hit(10, 0) } })
	local h = find(p, "HitSoft")
	check(g, "a slime hit = HitSoft at ContactDelay", h ~= nil and near(h.At, 0.23), encode(p))
	check(g, "a skeleton hit = HitHeavy", find(swing({ Hits = { hit(40, 0) } }), "HitHeavy") ~= nil, "")
	check(g, "a goblin hit = HitHeavy", find(swing({ Hits = { hit(80, 0) } }), "HitHeavy") ~= nil, "")
	check(g, "a little ghost hit = HitSoft", find(swing({ Hits = { hit(120, 0) } }), "HitSoft") ~= nil, "")
	p = swing({ Hits = { hit(10, 0, true) } })
	check(g, "a critical slime hit = HitSoft + the HitCrit layer at the contact (§4-2 6)", events(p) == "SwingWarrior,HitSoft,HitCrit"
		and near(find(p, "HitCrit").At, 0.23), events(p))
	p = swing({ Hits = { hit(10, 0), hit(11, 1, true) } })
	check(g, "a crit on a later target adds no layer", events(p) == "SwingWarrior,HitSoft", events(p))
	p = swing({ Hits = { hit(10, 0), hit(11, 1) } })
	check(g, "two slimes = one HitSoft", events(p) == "SwingWarrior,HitSoft", events(p))
	p = swing({ Hits = { hit(10, 0), hit(11, 1), hit(9, -1) } })
	h = find(p, "HitSoft")
	check(g, "three slimes = one HitSoft, louder and lower (x1.25, x0.95)", events(p) == "SwingWarrior,HitSoft" and h ~= nil
		and near(h.Volume, 1.25) and near(h.SpeedMul, 0.95), encode(p))
	h = find(swing({ Hits = { hit(10, 0) } }), "HitSoft")
	check(g, "one slime: the plain volume and speed", h ~= nil and near(h.Volume, 1) and h.SpeedMul == nil, encode(h or {}))
	h = find(swing({ Hits = { hit(120, 0) } }), "HitSoft")
	check(g, "a ghost squishes higher (x1.15)", h ~= nil and near(h.SpeedMul, 1.15), encode(h or {}))
	p = swing({ Hits = { hit(0, 0, false, "P") } })
	check(g, "a player hit = HitHeavy", find(p, "HitHeavy") ~= nil, events(p))
	p = swing({ Hits = { hit(0, 0, false, "G") } })
	check(g, "a golden goose hit honks (no hit thud)", events(p) == "SwingWarrior,GooseHonk", events(p))
	p = swing({ Hits = { hit(0, 0, false, "G"), hit(10, 0) } })
	check(g, "goose + slime: squish and honk", find(p, "HitSoft") ~= nil and find(p, "GooseHonk") ~= nil, events(p))
	h = find(swing({ Manual = false, Hits = { hit(80, 0) } }), "HitHeavy")
	check(g, "auto hits are marked Auto", h ~= nil and h.Auto == true, encode(h or {}))
	h = find(swing({ ContactDelay = 5, Hits = { hit(80, 0) } }), "HitHeavy")
	check(g, "contact time clamped to 1 s", h ~= nil and near(h.At, 1), encode(h or {}))
	h = find(swing({ UserId = 222, Pos = vec(20, 3, 0), Hits = { hit(80, 0) } }), "HitHeavy")
	check(g, "another player's hit near me: Others", h ~= nil and h.Others == true, encode(h or {}))
end

do
	local g = "skills"
	local function rel(t)
		local d = { UserId = ME, Class = "Mage", ContactDelay = 0.35, Pos = vec(5, 3, 0) }
		for k, v in t or {} do d[k] = v end
		return Audio.Plan("Release", d, ctx)
	end
	local p = rel()
	local s = find(p, "SkillCast")
	check(g, "my skill = SkillCast with my class's swing file (a Halo mage: SwingMageHalo)", s ~= nil and s.File == "SwingMageHalo", encode(p))
	check(g, "a Q skill also gets my faction's layer (§4-2 4: Q / Z / X)", find(p, "SkillHalo") ~= nil, events(p))
	s = find(rel({ LaunchDelay = 0.3 }), "SkillCast")
	check(g, "the cast sounds at the launch, not at the press", s ~= nil and near(s.At, 0.3), encode(s or {}))
	check(g, "X as Halo adds SkillHalo", find(rel({ Slot = "X" }), "SkillHalo") ~= nil, "")
	ctx.Faction = "Horns"
	check(g, "X as Horns adds SkillHorns", find(rel({ Slot = "X" }), "SkillHorns") ~= nil, "")
	ctx.Faction = "Neutral"
	check(g, "X as Neutral: no layer", #rel({ Slot = "X" }) == 1, events(rel({ Slot = "X" })))
	ctx.Faction = "Halo"
	s = find(rel({ Auto = true }), "SkillCast")
	check(g, "an auto skill is marked Auto", s ~= nil and s.Auto == true, encode(s or {}))
	p = rel({ Hits = { hit(10, 0) } })
	s = find(p, "HitSoft")
	check(g, "skill hits land at ContactDelay", s ~= nil and near(s.At, 0.35), encode(p))
	p = rel({ UserId = 222, Pos = vec(30, 3, 0) })
	s = find(p, "SkillCast")
	check(g, "another player's skill near me: Others, no layer", s ~= nil and s.Others == true and #p == 1, encode(p))
	-- sound_gaps B13: a Z / X cast (SkillService Fx "Skill": no launch / contact times, From = the caster)
	local function cast(t)
		local d = { UserId = ME, Class = "Warrior", Slot = "Z", From = vec(5, 3, 0), Center = vec(15, 3, 0), Hits = { hit(80, 0) } }
		for k, v in t or {} do d[k] = v end
		return Audio.Plan("Skill", d, ctx)
	end
	p = cast()
	s = find(p, "SkillCast")
	local hh = find(p, "HitHeavy")
	check(g, "a Z cast: SkillCast with my class file at once + my faction layer + its hit right after", s ~= nil and s.File == "SwingWarrior"
		and s.At == 0 and find(p, "SkillHalo") ~= nil and hh ~= nil and near(hh.At, A.SkillContact), encode(p))
	check(g, "an X cast too", find(cast({ Slot = "X" }), "SkillCast") ~= nil, "")
	s = find(cast({ Auto = true }), "SkillCast")
	check(g, "an auto Z / X cast is marked Auto", s ~= nil and s.Auto == true, encode(s or {}))
	p = cast({ UserId = 222, From = vec(30, 3, 0) })
	check(g, "another player's Z cast near me: Others, no layer", find(p, "SkillCast") ~= nil and find(p, "SkillCast").Others == true
		and find(p, "SkillHalo") == nil, encode(p))
	check(g, "another player's Z cast far away is silent", #cast({ UserId = 222, From = vec(90, 3, 0) }) == 0, "")
end

do
	local g = "rewards"
	local function coin(combo)
		ctx.Combo = combo
		local c = find(Audio.Plan("Reward", { Gold = 3 }, ctx), "ComboCoin")
		return c and c.Speed
	end
	local p = Audio.Plan("Reward", {}, ctx)
	check(g, "a kill pops and rings the combo coin", find(p, "KillPop") ~= nil and find(p, "ComboCoin") ~= nil, events(p))
	check(g, "kill 1 = 0.80", near(coin(1), 0.8), tostring(coin(1)))
	check(g, "kill 3 = 0.8 x 2^(4/12)", near(coin(3), 0.8 * 2 ^ (4 / 12)), tostring(coin(3)))
	check(g, "kill 8 = 1.60 (the top)", near(coin(8), 1.6), tostring(coin(8)))
	check(g, "kill 30 stays at 1.60", near(coin(30), 1.6), tostring(coin(30)))
	ctx.Combo = 10
	check(g, "kill 10 = ComboMilestone", find(Audio.Plan("Reward", {}, ctx), "ComboMilestone") ~= nil, "")
	ctx.Combo = 11
	check(g, "kill 11 = no milestone", find(Audio.Plan("Reward", {}, ctx), "ComboMilestone") == nil, "")
	ctx.Combo = 1
	check(g, "enhance success = ScrollSuccess", events(Audio.Plan("Enhance", { Success = true }, ctx)) == "ScrollSuccess", "")
	check(g, "enhance failure = ScrollFail", events(Audio.Plan("Enhance", { Success = false }, ctx)) == "ScrollFail", "")
	-- sound_wiring_r4 / onepass: my drop (Loot), a plunder (Plunder / GoldPickup), a king falls (KingDefeat)
	local lootPlan = Audio.Plan("Loot", { Items = { { Item = "Enh70", Name = "Enhance Scroll 70%", N = 1 } } }, ctx)
	check(g, "an enhance scroll drop = Loot at its own pitch", events(lootPlan) == "Loot" and lootPlan[1].Speed == nil, events(lootPlan))
	lootPlan = Audio.Plan("Loot", { Items = { { Item = "Move70", Name = "Transfer Scroll 70%", N = 1 } } }, ctx)
	check(g, "a transfer scroll drop = Loot", events(lootPlan) == "Loot", events(lootPlan))
	lootPlan = Audio.Plan("Loot", { Items = { { Item = "Jelly", Name = "Jelly", N = 2 }, { Weapon = 3, Name = "Iron Sword" } } }, ctx)
	check(g, "a weapon drop = one Loot at 0.92x", events(lootPlan) == "Loot" and near(lootPlan[1].Speed, 0.92), events(lootPlan))
	check(g, "materials and potions alone are silent",
		#Audio.Plan("Loot", { Items = { { Item = "Jelly", Name = "Jelly", N = 3 }, { Potion = "HP", Name = "HP Potion", N = 1 } } }, ctx) == 0, "")
	check(g, "a Loot packet without items is silent", #Audio.Plan("Loot", {}, ctx) == 0, "")
	check(g, "my pocket taken = Plunder", events(Audio.Plan("Plunder", { Victim = ME, Thief = 222, Amount = 30 }, ctx)) == "Plunder", "")
	check(g, "I took it = GoldPickup", events(Audio.Plan("Plunder", { Victim = 222, Thief = ME, Amount = 30 }, ctx)) == "GoldPickup", "")
	check(g, "someone else's plunder is silent", #Audio.Plan("Plunder", { Victim = 222, Thief = 333, Amount = 30 }, ctx) == 0, "")
	check(g, "the revenge refund = GoldPickup for the victim",
		events(Audio.Plan("Plunder", { Victim = ME, Thief = 222, Amount = 30, Refund = true }, ctx)) == "GoldPickup", "")
	check(g, "a king falls = KingDefeat for everyone", events(Audio.Plan("KingDefeat", { Key = "PumpkinKing", Contributors = { 222 } }, ctx)) == "KingDefeat", "")
	local kd = Audio.Plan("KingDefeat", { Key = "GhostKing", Contributors = { 222, ME } }, ctx)
	check(g, "a paid contributor also hears KillPop + coin 0.25 s later",
		events(kd) == "KingDefeat,KillPop,ComboCoin" and near(kd[2].At, 0.25), events(kd))
	check(g, "the onepass ids are wired (no empty file)",
		A.Files.Loot ~= "" and A.Files.Spend ~= "" and A.Files.RankUp ~= "" and A.Files.SkillLearn ~= "" and A.Files.GooseArrive ~= ""
			and A.Files.CrownHalo ~= "" and A.Files.KingDefeat ~= "" and A.Files.Plunder ~= ""
			and type(A.Sounds.Loot) == "table" and type(A.Sounds.CrownHorns) == "table" and type(A.Sounds.Plunder) == "table", "")
	for _, k in { "Bank", "Rare" } do
		check(g, "gold outside kills = GoldPickup", events(Audio.Plan(k, { Amount = 9 }, ctx)) == "GoldPickup", k)
	end
	local keepEquip = A.Files.Equip
	A.Files.Equip = ""
	check(g, "a weapon bought / equipped = GoldPickup until Equip is uploaded", events(Audio.Plan("Upgrade", {}, ctx)) == "GoldPickup", "")
	A.Files.Equip = "rbxassetid://Equip"
	check(g, "a weapon bought / equipped = Equip once it is uploaded (sound_gaps C2)", events(Audio.Plan("Upgrade", {}, ctx)) == "Equip", "")
	A.Files.Equip = keepEquip
	check(g, "my level up = LevelUp", events(Audio.Plan("LevelUp", { UserId = ME }, ctx)) == "LevelUp", "")
	check(g, "another player's level up is silent", #Audio.Plan("LevelUp", { UserId = 222 }, ctx) == 0, "")
	check(g, "a big hit (30% of my HP) = HurtBig", events(Audio.Plan("Hurt", { Amount = 30 }, ctx)) == "HurtBig", "")
	check(g, "a small hit is quiet", #Audio.Plan("Hurt", { Amount = 5 }, ctx) == 0, "")
	ctx.HP = 20
	check(g, "a small hit under 30% HP = HurtBig", events(Audio.Plan("Hurt", { Amount = 5 }, ctx)) == "HurtBig", "")
	ctx.HP = 100
	check(g, "unknown kinds and bad data are silent", #Audio.Plan("Plunder", {}, ctx) == 0 and #Audio.Plan("Swing", "x", ctx) == 0
		and #Audio.Plan(nil, {}, ctx) == 0, "")
end

do
	-- the world sounds (sound_gaps B1-B10; server signals of docs/design/sound_server_2026-10-07.md)
	local g = "world"
	check(g, "my KO = KO (B1)", events(Audio.Plan("KO", { By = 222, Lost = 10 }, ctx)) == "KO", "")
	check(g, "the goose leaving 30 studs away = GooseEnd (B3)", events(Audio.Plan("GooseEnd", { Pos = vec(30, 3, 0) }, ctx)) == "GooseEnd", "")
	check(g, "the goose leaving far away is quiet", #Audio.Plan("GooseEnd", { Pos = vec(400, 3, 0) }, ctx) == 0, "")
	check(g, "a goose end without a place is quiet", #Audio.Plan("GooseEnd", { Winner = "Halo" }, ctx) == 0, "")
	local s = Audio.Plan("Stomp", { UserId = 222, Pos = vec(10, 3, 0) }, ctx)
	check(g, "a stomp within 15 studs = KaijuStomp at full volume (B4)", events(s) == "KaijuStomp" and near(s[1].Volume, 1), encode(s))
	s = Audio.Plan("Stomp", { UserId = 222, Pos = vec(37.5, 3, 0) }, ctx)
	check(g, "a stomp 37.5 studs away = half volume", events(s) == "KaijuStomp" and near(s[1].Volume, 0.5), encode(s))
	check(g, "a stomp 60+ studs away is quiet", #Audio.Plan("Stomp", { UserId = 222, Pos = vec(70, 3, 0) }, ctx) == 0, "")
	check(g, "StompVolume: 1 up to 15 studs, 0 from 60", near(Audio.StompVolume(0), 1) and near(Audio.StompVolume(15), 1)
		and near(Audio.StompVolume(60), 0) and near(Audio.StompVolume(500), 0), "")
	check(g, "TickAt: crossing 3 / 2 / 1 s left = 1.0 / 1.12 / 1.26 (B7)", near(Audio.TickAt(3.1, 2.9), 1)
		and near(Audio.TickAt(2.1, 1.9), 1.12) and near(Audio.TickAt(1.1, 0.9), 1.26), "")
	check(g, "TickAt: no crossing, no first value, no tick after 0", Audio.TickAt(2.9, 2.6) == nil and Audio.TickAt(nil, 2.9) == nil
		and Audio.TickAt(0.9, 0.1) == nil and Audio.TickAt(0.5, -0.2) == nil, "")
	check(g, "AnnounceSound: someone else's Jackpot / FirstMax only (B10)", Audio.AnnounceSound({ Key = "Jackpot" }) == "JackpotOther"
		and Audio.AnnounceSound({ Key = "FirstMax" }) == "JackpotOther" and Audio.AnnounceSound({ Key = "RareWeapon" }) == nil
		and Audio.AnnounceSound({ Key = "Jackpot", Self = true }) == nil and Audio.AnnounceSound({ Key = "Jackpot", Event = true }) == nil
		and Audio.AnnounceSound("Jackpot") == nil, "")
	ctx.Combo = 1
	local r = Audio.Plan("Reward", { Gold = 30, Golden = true }, ctx)
	check(g, "a golden kill = KillPop + GoldenKill, its coin 0.1 s later", events(r) == "KillPop,GoldenKill,ComboCoin"
		and near(find(r, "ComboCoin").At, 0.1), encode(r))
	r = Audio.Plan("Reward", { Gold = 3 }, ctx)
	check(g, "a plain kill: no golden sound, the coin at 0.05 s", find(r, "GoldenKill") == nil and near(find(r, "ComboCoin").At, 0.05), encode(r))
	ctx.FirstWeapon = true
	check(g, "my first weapon's Upgrade is quiet (C1: HUD's first-weapon moment plays PowerUp)", #Audio.Plan("Upgrade", { Tier = 1 }, ctx) == 0, "")
	ctx.FirstWeapon = nil
	check(g, "a later weapon's Upgrade still rings", #Audio.Plan("Upgrade", { Tier = 2 }, ctx) == 1, "")
	for _, e in { "KO", "Respawn", "GooseEnd", "KaijuStomp", "KaijuSiren", "WarFinal30", "CountTick", "GoldenSpot", "GoldenKill",
		"ZoneEnterPvP", "JackpotOther" } do
		local d = A.Sounds[e]
		check(g, "every world sound has an entry with an uploaded id and sane numbers", type(d) == "table" and type(d.File) == "string"
			and type(A.Files[d.File]) == "string" and A.Files[d.File] ~= "" and d.Volume > 0 and d.Volume <= 0.85 and (d.Max or 0) >= 1, e)
	end
	check(g, "the golden kill keeps its own pool (the spot's 10 s gap never eats it)", A.Sounds.GoldenKill.File == "GoldenSpot"
		and A.Sounds.GoldenKill.Gap < 1 and A.Sounds.GoldenSpot.Gap >= 10, "")
end

do
	local g = "config"
	local used = { "SwingWarrior", "SwingMage", "SwingMageHalo", "SwingMageHorns", "SwingArrow", "SwingTamer", "HitSoft",
		"HitHeavy", "HitCrit", "KillPop", "ComboCoin", "ComboMilestone", "LevelUp", "PowerUp", "Jump", "WindowOpen", "WindowClose",
		"Deny", "AutoOn", "AutoOff", "Purify", "Devour", "PumpkinKing", "GhostKing", "GooseHonk", "GooseArrive", "QuestDone",
		"GoldPickup", "ScrollSuccess", "ScrollFail", "Tap", "SkillCast", "SkillHalo", "SkillHorns", "HurtBig", "Potion", "QuestNew",
		"RankDown", "TalkBlip", "Equip", "Spend", "RankUp", "SkillLearn", "SkillReady" }
	for _, e in used do
		local d = A.Sounds[e]
		local files = d and (d.Files or (d.File and { d.File })) or {}
		local okFiles = e == "SkillCast" or #files > 0
		for _, f in files do okFiles = okFiles and type(A.Files[f]) == "string" end
		check(g, "every event has an entry, its files and sane numbers", type(d) == "table" and okFiles
			and type(d.Volume) == "number" and d.Volume > 0 and d.Volume <= 1 and (d.Max or 0) >= 1 and (d.Gap or -1) >= 0
			and type(d.Speed) == "table" and d.Speed[1] <= d.Speed[2], e)
	end
	for _, sw in A.Swing do check(g, "every swing file is a known file", type(A.Files[sw]) == "string", sw) end
	local function vol(e) return A.Sounds[e].Volume end
	local maxCombat = 0
	for e, d in A.Sounds do
		if d.Combat then maxCombat = math.max(maxCombat, d.Volume) end
	end
	check(g, "combat sounds stay at 0.40 or less", maxCombat <= 0.40, tostring(maxCombat))
	local biggest = 0
	for _, d in A.Sounds do biggest = math.max(biggest, d.Volume) end
	check(g, "level up is the loudest (0.85)", near(vol("LevelUp"), 0.85) and near(biggest, 0.85), tostring(biggest))
	check(g, "purify and devour are the same size", near(vol("Purify"), vol("Devour")), "")
	check(g, "kings never under 0.85x", A.Sounds.PumpkinKing.Speed[1] >= 0.85 and A.Sounds.GhostKing.Speed[1] >= 0.85, "")
	check(g, "each king has its own file (sound_gaps A6)", A.Sounds.PumpkinKing.File == "PumpkinKing" and A.Sounds.GhostKing.File == "GhostKing", "")
	check(g, "the kings hold the duck 1.6 s", near(A.Duck.SecondsBy.PumpkinKing, 1.6) and near(A.Duck.SecondsBy.GhostKing, 1.6), "")
	check(g, "big hurts have their own file (sound_gaps A5)", A.Sounds.HurtBig.File == "HurtBig" and A.Files.HurtBig ~= "", "")
	check(g, "duck: level up, both kings and scroll success", A.Duck.By.LevelUp and A.Duck.By.PumpkinKing
		and A.Duck.By.GhostKing and A.Duck.By.ScrollSuccess and near(A.Duck.Mul, 0.5) and near(A.Duck.Seconds, 1.2), "")
	check(g, "others 0.35x within 40 studs, 8 at once", near(A.OthersMul, 0.35) and A.OthersRange == 40 and A.MaxPlaying == 8, "")
	check(g, "talk voices: the shard high, the Horns guide low", A.Talk.Default == 1 and A.Talk.Shard > 1 and A.Talk.Horns < 1, "")
	-- sound_gaps A8: the Sound keys the server's Notify lines send all have an entry (silent until uploaded)
	for _, k in { "Equip", "Spend", "RankUp", "QuestDone", "GoldPickup", "ScrollSuccess", "ScrollFail", "Deny" } do
		check(g, "every Notify Sound key the server sends is a Config.Audio event", type(A.Sounds[k]) == "table", k)
	end
	check(g, "the archer swing is the arrow; the pet dash whistles", A.Swing.Archer == "SwingArrow" and A.Swing.PetDash == "SwingTamer", "")
	check(g, "the faction mage files (Halo / Horns)", A.SwingFaction.Mage.Halo == "SwingMageHalo" and A.SwingFaction.Mage.Horns == "SwingMageHorns", "")
	check(g, "purify takes its two files in turn", A.Sounds.Purify.Alternate == true and #A.Sounds.Purify.Files == 2, "")
	check(g, "round-4 uploads wired (arrow, mage files, hits, crit, power-up, jump, purify b)", A.Files.SwingArrow ~= ""
		and A.Files.SwingMageHalo ~= "" and A.Files.SwingMageHorns ~= "" and A.Files.HitSoft ~= "" and A.Files.HitHeavy ~= ""
		and A.Files.HitCrit ~= "" and A.Files.PowerUp ~= "" and A.Files.Jump ~= "" and A.Files.Purify_b ~= "", "")
	check(g, "the goose arrival ducks the combat sounds", A.Duck.By.GooseArrive == true, "")
	-- sound_gaps 2026-10-10 (batch 8 + B / C, game dev 1): every new event, its uploaded file and sane numbers
	local new10 = { "QuestOpen", "QuestTab", "StampPress", "Chest7Open", "WelcomeBack", "TipDing", "DiaryPage", "CandyPlop",
		"KingHelpHome", "KingTickleCoins", "Warp", "WarpIn", "SecretFound", "PetLevelUp", "MarkerMove", "BlipBright", "BlipGleam",
		"BlipFolk" }
	for _, e in new10 do
		local d = A.Sounds[e]
		local f = d and A.Files[d.File]
		check(g, "sound_gaps 10/10: each new event has its uploaded file and sane numbers", type(d) == "table"
			and type(f) == "string" and string.find(f, "^rbxassetid://%d+$") ~= nil and type(d.Volume) == "number" and d.Volume > 0
			and d.Volume <= 0.6 and (d.Max or 0) >= 1 and (d.Gap or -1) >= 0 and type(d.Speed) == "table" and d.Speed[1] <= d.Speed[2]
			and not d.Combat, e)
	end
	check(g, "13차: the pet's level up has its own file, smaller than mine", A.Sounds.PetLevelUp.File == "PetLevel"
		and A.Sounds.PetLevelUp.Volume < A.Sounds.LevelUp.Volume, "")
	check(g, "A23-105 Settings: a 'Weather effects' toggle, on by default, kept by SanitizeSettings",
		Config.Settings.Defs.Weather and Config.Settings.Defs.Weather.Type == "Bool" and table.find(Config.Settings.Order, "Weather") ~= nil
		and Config.Settings.Text.WeatherEn == "Weather effects" and Config.Data.Defaults.Settings.Weather == true
		and Config.SanitizeSettings({ V = 4, Weather = false }).Weather == false and Config.SanitizeSettings({}).Weather == true, "")
	check(g, "13차: the marker's tick is the quiet DiamondTick", A.Sounds.MarkerMove.File == "DiamondTick"
		and A.Sounds.MarkerMove.Volume <= 0.25, "")
	for _, e in { "PetCall", "PetStow", "LanternOn" } do
		local d = A.Sounds[e]
		check(g, "13차: each new event has its uploaded file", type(d) == "table" and type(A.Files[d.File]) == "string"
			and string.find(A.Files[d.File], "^rbxassetid://%d+$") ~= nil and d.Volume <= 0.6, e)
	end
	local WL = A.Weather and A.Weather.Loops
	check(g, "A23-105 weather air: Rain / RainRoof / Night / WinterWind ids, quiet, a 1.5 s fade", WL and A.Weather.Fade == 1.5
		and WL.Rain.Id == "rbxassetid://126445007194331" and WL.RainRoof.Id == "rbxassetid://76655204420103"
		and WL.Night.Id == "rbxassetid://99972569683856" and WL.WinterWind.Id == "rbxassetid://113002054407080"
		and WL.Rain.Volume <= 0.4 and WL.RainRoof.Volume < WL.Rain.Volume, encode(A.Weather))
	check(g, "blips: Bright and Sir Gleam by story Speaker", A.Blips.Bright == "BlipBright" and A.Blips.Gleam == "BlipGleam", "")
	local Z = A.ZoneAmbient
	check(g, "the towns' air: HaloDay / HornsDen at 0.25 with a 1.5 s fade", Z and Z.Volume == 0.25 and Z.Fade == 1.5
		and Z.Tracks.HaloTown == "rbxassetid://76688623617177" and Z.Tracks.HornsTown == "rbxassetid://112972652651947", encode(Z))
end

do
	local g = "sound_gaps 10/10 plan"
	local p = Audio.Plan("Attendance", { Slot = 3, Days = 3, Box = false }, ctx)
	check(g, "an attendance claim = StampPress now, replacing the claim's QuestDone", events(p) == "StampPress" and p[1].At == 0
		and p[1].Replace == "QuestDone", encode(p))
	p = Audio.Plan("Attendance", { Slot = 7, Days = 7, Box = true }, ctx)
	check(g, "the 7-day box: Chest7Open BoxAfter s after the stamp", events(p) == "StampPress,Chest7Open"
		and near(p[2].At, A.BoxAfter), encode(p))
	check(g, "the King Slime card: Help = KingHelpHome", events(Audio.Plan("FinisherEnd", { Pick = "Help" }, ctx)) == "KingHelpHome", "")
	check(g, "... Tickle = KingTickleCoins", events(Audio.Plan("FinisherEnd", { Pick = "Tickle" }, ctx)) == "KingTickleCoins", "")
	check(g, "... no pick = quiet", #Audio.Plan("FinisherEnd", { Pick = "None" }, ctx) == 0, "")
	p = Audio.Plan("Loot", { Items = { { Item = "Candy", N = 2 } } }, ctx)
	check(g, "my drop with candy = CandyPlop", events(p) == "CandyPlop", encode(p))
	p = Audio.Plan("Loot", { Items = { { Item = "Jelly", N = 1 } } }, ctx)
	check(g, "a drop without candy stays as before (materials quiet)", #p == 0, encode(p))
	p = Audio.Plan("KO", { By = 222, Tip = "Tip: slimes cannot read. You can." }, ctx)
	check(g, "a KO with a fun tip (EG05): KO, then TipDing KOTipAfter s later", events(p) == "KO,TipDing"
		and near(p[2].At, A.KOTipAfter), encode(p))
	check(g, "a KO without one: KO only", events(Audio.Plan("KO", { By = 222 }, ctx)) == "KO", "")
	check(g, "IsWarp: 300 studs in one frame standing still = a warp", Audio.IsWarp(300, 0, 0.016) == true, "")
	check(g, "IsWarp: 30 studs is a step, not a warp", Audio.IsWarp(30, 0, 0.016) == false, "")
	check(g, "IsWarp: a long fall (100 studs in a half-second hitch at 200 studs/s) is not a warp",
		Audio.IsWarp(100, 200, 0.5) == false, "")
	check(g, "IsWarp: 100 studs at a run in one frame = a warp", Audio.IsWarp(100, 16, 0.016) == true, "")
	local function loops(st)
		local t = {}
		for k in Audio.WeatherLoops(st) do table.insert(t, k) end
		table.sort(t)
		return table.concat(t, ",")
	end
	check(g, "WeatherLoops: rain in the open = Rain", loops({ Weather = "Rain", Phase = "Day", Enabled = true }) == "Rain", "")
	check(g, "WeatherLoops: rain under a roof = RainRoof", loops({ Weather = "Rain", Phase = "Day", Enabled = true,
		Covered = true }) == "RainRoof", "")
	check(g, "WeatherLoops: snow = WinterWind", loops({ Weather = "Snow", Phase = "Day", Enabled = true }) == "WinterWind", "")
	check(g, "WeatherLoops: a clear night = Night (crickets)", loops({ Weather = "Clear", Phase = "Night", Enabled = true }) == "Night", "")
	check(g, "WeatherLoops: a rainy night = the rain only", loops({ Weather = "Rain", Phase = "Night", Enabled = true }) == "Rain", "")
	check(g, "WeatherLoops: weather effects off = no rain / wind (a snowy night keeps its crickets)",
		loops({ Weather = "Rain", Phase = "Day", Enabled = false }) == "" and loops({ Weather = "Snow", Phase = "Night",
		Enabled = false }) == "Night", "")
	check(g, "WeatherLoops: no state yet = quiet", loops(nil) == "" and loops({}) == "", "")
end

----------------------------------------------------------------- runtime
do
	local g = "runtime"
	local settings = { Sfx = 1 }
	local open = { Panels = false, Hold = false, Intro = false }
	local C = { Settings = { Get = function(k) return settings[k] end }, Panels = { IsOpen = function() return open.Panels end },
		UIKit = { ShouldHoldBanners = function() return open.Hold end }, Intro = { IsOpen = function() return open.Intro end } }
	-- every file gets an id except SwingMage (to check a silent event)
	for f in A.Files do A.Files[f] = "rbxassetid://" .. f end
	A.Files.SwingMage = ""
	local fx = Config.Sounds
	Audio.Init(C)
	Audio.Start()
	check(g, "our files mute Fx's swing / skill / coin", fx.Swing == "" and fx.Release == "" and fx.Coin == "", encode(fx))
	check(g, "Fx's click becomes our Tap", fx.Click == "rbxassetid://Tap", tostring(fx.Click))
	check(g, "uploaded files are preloaded", PRELOADED >= 30, tostring(PRELOADED))

	table.clear(PLAYS)
	check(g, "an event without an id never plays", Audio.Play("SwingMage") == false and #PLAYS == 0, tostring(#PLAYS))
	check(g, "an event with an id plays", Audio.Play("KillPop") == true and #PLAYS == 1, tostring(#PLAYS))
	local p = PLAYS[1]
	local sp = A.Sounds.KillPop.Speed
	check(g, "volume = the table's Volume", p and near(p.Volume, A.Sounds.KillPop.Volume), encode(p or {}))
	check(g, "speed inside the table's range", p and p.Speed >= sp[1] - 1e-9 and p.Speed <= sp[2] + 1e-9, encode(p or {}))
	check(g, "combat sounds go to the ducked group", p and p.Group == "SfxCombat", tostring(p and p.Group))
	check(g, "the same event inside its cooldown is skipped", Audio.Play("KillPop") == false, "")
	endAll()
	waitClock(0.06)
	table.clear(PLAYS)
	Audio.Play("HitSoft", { Auto = true })
	p = PLAYS[1]
	check(g, "auto plays at AutoMul", p and near(p.Volume, A.Sounds.HitSoft.Volume * A.AutoMul), encode(p or {}))
	check(g, "HitSoft plays its one round-4 file", p and p.Id == "rbxassetid://HitSoft", encode(p or {}))
	waitClock(0.06)
	Audio.Play("HitSoft", { Others = true })
	p = PLAYS[2]
	check(g, "other players' sounds at OthersMul", p and near(p.Volume, A.Sounds.HitSoft.Volume * A.OthersMul), encode(p or {}))
	waitClock(0.06)
	Audio.Play("HitSoft")
	waitClock(0.06)
	check(g, "a 4th HitSoft while 3 still play is skipped (Max 3)", Audio.Play("HitSoft") == false and #PLAYS == 3, tostring(#PLAYS))
	endAll()
	-- 8 at once at most
	table.clear(PLAYS)
	for _, e in { "WindowOpen", "WindowClose", "Deny", "AutoOn", "AutoOff", "Purify", "Devour", "QuestDone", "Potion" } do
		Audio.Play(e)
	end
	check(g, "never more than 8 sounds at once", #PLAYS == 8, tostring(#PLAYS))
	endAll()
	settings.Sfx = 0
	check(g, "Sound effects 0 = silent", Audio.Play("GoldPickup") == false, "")
	settings.Sfx = 0.5
	table.clear(PLAYS)
	Audio.Play("GoldPickup")
	p = PLAYS[1]
	check(g, "Sound effects 0.5 halves the volume", p and near(p.Volume, A.Sounds.GoldPickup.Volume * 0.5), encode(p or {}))
	settings.Sfx = 1
	endAll()
	table.clear(PLAYS)
	Audio.Play("PumpkinKing")
	p = PLAYS[1]
	check(g, "the Pumpkin King plays its own file at 1.0x (sound_gaps A6)", p and p.Id == "rbxassetid://PumpkinKing"
		and near(p.Speed, 1), encode(p or {}))
	local combatGroup = nil
	for _, s in SOUNDS_MADE do
		if s.SoundGroup and s.SoundGroup.Name == "SfxCombat" then combatGroup = s.SoundGroup end
	end
	check(g, "a big moment ducks the combat sounds to 0.5", combatGroup ~= nil and near(combatGroup.Volume, 0.5),
		tostring(combatGroup and combatGroup.Volume))
	runDelays(1.3)
	check(g, "a king holds the duck longer than 1.2 s (§4-2 10)", combatGroup ~= nil and near(combatGroup.Volume, 0.5),
		tostring(combatGroup and combatGroup.Volume))
	runDelays(1.7)
	check(g, "and they come back after 1.6 s", combatGroup ~= nil and near(combatGroup.Volume, 1), tostring(combatGroup and combatGroup.Volume))
	endAll()
	Audio.Play("LevelUp")
	local ducked = combatGroup ~= nil and near(combatGroup.Volume, 0.5)
	runDelays(1.3)
	check(g, "a level up ducks for 1.2 s only", ducked and near(combatGroup.Volume, 1), tostring(combatGroup and combatGroup.Volume))
	waitClock(0.55) -- Deny played in the 8-at-once check: past its 0.5 s cooldown
	table.clear(PLAYS)
	check(g, "'No' (SkillBar) plays Deny", Audio.Play("No") == true and PLAYS[1] and PLAYS[1].Id == "rbxassetid://Deny", encode(PLAYS[1] or {}))
	endAll()
	table.clear(PLAYS)
	check(g, "talk blips ride the speaker's speed", Audio.Talk("Shard") == true and PLAYS[1] and PLAYS[1].Speed > 1.38
		and PLAYS[1].Speed < 1.52, encode(PLAYS[1] or {}))
	endAll()
	waitClock(0.06)
	table.clear(PLAYS)
	Audio.Talk("Horns")
	check(g, "the Horns guide talks low", PLAYS[1] and PLAYS[1].Speed > 0.73 and PLAYS[1].Speed < 0.82, encode(PLAYS[1] or {}))
	endAll()
	-- sound_gaps A12: Purify takes its two files in turn (a skipped play never moves the turn)
	local gap = A.Sounds.Purify.Gap
	A.Sounds.Purify.Gap = 0
	table.clear(PLAYS)
	for _ = 1, 16 do
		Audio.Play("Purify")
		endAll()
	end
	local ids = {}
	for i, pl in PLAYS do ids[i] = pl.Id end
	local both = { ["rbxassetid://Purify"] = true, ["rbxassetid://Purify_b"] = true }
	local turns = #ids == 16
	for i = 1, #ids do
		if not both[ids[i]] or (i > 1 and ids[i] == ids[i - 1]) then turns = false end
	end
	check(g, "purify alternates its two files (16 plays: a, b, a, b ...)", turns, encode(ids))
	A.Sounds.Purify.Gap = gap
	settings.Sfx = 0
	Audio.Play("Purify")
	settings.Sfx = 1
	table.clear(PLAYS)
	A.Sounds.Purify.Gap = 0
	Audio.Play("Purify")
	A.Sounds.Purify.Gap = gap
	check(g, "a muted (skipped) purify keeps the turn", PLAYS[1] and PLAYS[1].Id == ids[#ids - 1],
		encode({ PLAYS[1] and PLAYS[1].Id, ids[#ids - 1] }))
	endAll()

	-- sound_spec §4-2 11 overlaps (real plays; the cooldowns opened for the check)
	local gaps = {}
	for _, k in { "LevelUp", "QuestDone", "QuestNew" } do
		gaps[k] = A.Sounds[k].Gap
		A.Sounds[k].Gap = 0
	end
	local function playedName(word)
		for _, pl in PLAYS do
			if string.find(pl.Name, word, 1, true) then return true end
		end
		return false
	end
	table.clear(PLAYS)
	table.clear(DELAYS)
	Audio.Play("LevelUp")
	check(g, "QuestDone right after a LevelUp is dropped (§4-2 11)", Audio.Play("QuestDone") == false and not playedName("QuestDone"),
		encode(PLAYS))
	waitClock(0.45)
	endAll()
	check(g, "QuestDone 0.45 s after it plays", Audio.Play("QuestDone") == true, encode(PLAYS))
	local qd = PLAYS[#PLAYS] and PLAYS[#PLAYS].Sound
	Audio.Play("LevelUp")
	check(g, "a LevelUp right after a QuestDone stops it", qd ~= nil and qd.IsPlaying == false and playedName("LevelUp"),
		tostring(qd and qd.IsPlaying))
	endAll()
	waitClock(0.45)
	table.clear(PLAYS)
	table.clear(DELAYS)
	Audio.Play("QuestDone")
	check(g, "QuestNew right after QuestDone waits", Audio.Play("QuestNew") == false and not playedName("QuestNew"), encode(PLAYS))
	local waited = nil
	for _, d in DELAYS do
		if d.Args[1] == "QuestNew" then waited = d end
	end
	check(g, "... until 0.6 s after the QuestDone", waited ~= nil and waited.T > 0.5 and waited.T <= 0.6, tostring(waited and waited.T))
	runDelays(0.7)
	check(g, "then it plays", playedName("QuestNew"), encode(PLAYS))
	for k, v in gaps do A.Sounds[k].Gap = v end
	endAll()
	-- the goose's reward line waits until 1.5 s after GooseEnd (§4-2 11)
	table.clear(PLAYS)
	table.clear(DELAYS)
	Audio.Play("GooseEnd")
	REMOTES.Notify.OnClientEvent:Fire({ Text = "Goose gold!", Kind = "good", Sound = "GoldPickup" })
	check(g, "a reward line right after GooseEnd waits (the big one first)", playedName("GooseEnd") and not playedName("GoldPickup"),
		encode(PLAYS))
	runDelays(1.6)
	check(g, "... and plays 1.5 s later", playedName("GoldPickup"), encode(PLAYS))
	endAll()

	-- listeners: what Audio.Play is asked for
	local asked = {}
	local real = Audio.Play
	Audio.Play = function(event, opts)
		table.insert(asked, { Event = event, Opts = opts })
		return true
	end
	local function last() return asked[#asked] and asked[#asked].Event end
	local function clear() table.clear(asked) end

	PLAYER:SetAttribute("AutoCombatEnabled", true)
	check(g, "the saved auto value arriving after the join is quiet", #asked == 0, tostring(last()))
	PLAYER:SetAttribute("DataLoaded", false)
	PLAYER:SetAttribute("AutoCombatEnabled", false)
	check(g, "auto changing before the data is loaded is quiet", #asked == 0, tostring(last()))
	PLAYER:SetAttribute("DataLoaded", true)
	PLAYER:SetAttribute("AutoCombatEnabled", true)
	check(g, "auto on -> AutoOn", last() == "AutoOn", tostring(last()))
	PLAYER:SetAttribute("AutoCombatEnabled", false)
	check(g, "auto off -> AutoOff", last() == "AutoOff", tostring(last()))
	clear()
	PLAYER:SetAttribute("Honor", 5)
	PLAYER:SetAttribute("Infamy", 2)
	check(g, "points going up are quiet (Purify / Devour come with the Choice Fx)", #asked == 0, tostring(last()))
	REMOTES.Fx.OnClientEvent:Fire("Choice", { Option = "Good" })
	check(g, "a good story choice -> Purify", last() == "Purify", tostring(last()))
	REMOTES.Fx.OnClientEvent:Fire("Choice", { Option = "Evil" })
	check(g, "an evil story choice -> Devour", last() == "Devour", tostring(last()))
	clear()
	REMOTES.Fx.OnClientEvent:Fire("Choice", { Option = "Maybe" })
	check(g, "an unknown choice is quiet", #asked == 0, tostring(last()))
	clear()
	PLAYER:SetAttribute("Honor", 4)
	check(g, "my own side's points down (A23-58) -> RankDown", last() == "RankDown", tostring(last()))
	clear()
	PLAYER:SetAttribute("Infamy", 1)
	check(g, "the other side's points down are quiet", #asked == 0, tostring(last()))
	PLAYER:SetAttribute("Faction", "Horns")
	PLAYER:SetAttribute("Infamy", 0)
	PLAYER:SetAttribute("Honor", 0)
	check(g, "points reset by a faction change are quiet", #asked == 0, tostring(last()))
	PLAYER:SetAttribute("Faction", "Halo")
	PLAYER:SetAttribute("HPPotionCount", 3)
	check(g, "potion counts arriving with the save are quiet", #asked == 0, tostring(last()))
	PLAYER:SetAttribute("HPPotionCount", 2)
	check(g, "an HP potion used -> Potion", last() == "Potion", tostring(last()))
	clear()
	PLAYER:SetAttribute("HPPotionCount", 5)
	check(g, "buying potions is quiet", #asked == 0, tostring(last()))

	GAMESTATE:SetAttribute("PumpkinKingActive", true)
	check(g, "a king already there at the join is quiet", #asked == 0, tostring(last()))
	GAMESTATE:SetAttribute("PumpkinKingActive", false)
	waitClock(3.05)
	GAMESTATE:SetAttribute("PumpkinKingActive", true)
	check(g, "the Pumpkin King arrives -> PumpkinKing", last() == "PumpkinKing", tostring(last()))
	GAMESTATE:SetAttribute("GhostKingActive", true)
	check(g, "the Ghost King arrives -> GhostKing", last() == "GhostKing", tostring(last()))
	GAMESTATE:SetAttribute("GooseActive", true)
	check(g, "the golden goose appears -> GooseArrive (sound_gaps A7)", last() == "GooseArrive" and #asked == 3, tostring(last()))
	GAMESTATE:SetAttribute("GooseActive", false)
	clear()
	Audio.Play = function(event, opts)
		table.insert(asked, { Event = event, Opts = opts })
		return event ~= "GooseArrive" -- no GooseArrive file yet
	end
	GAMESTATE:SetAttribute("GooseActive", true)
	check(g, "no GooseArrive file yet: the honk stands in", #asked == 2 and asked[1].Event == "GooseArrive" and last() == "GooseHonk",
		encode(asked))
	Audio.Play = function(event, opts)
		table.insert(asked, { Event = event, Opts = opts })
		return true
	end
	clear()
	HUM.StateChanged:Fire("HumanoidStateType.Running", "HumanoidStateType.Jumping")
	check(g, "my jump -> Jump (sound_gaps A11)", last() == "Jump" and #asked == 1, encode(asked))
	HUM.StateChanged:Fire("HumanoidStateType.Jumping", "HumanoidStateType.Freefall")
	HUM.StateChanged:Fire("HumanoidStateType.Freefall", "HumanoidStateType.Landed")
	check(g, "falling and landing are quiet", #asked == 1, encode(asked))
	clear()

	REMOTES.Notify.OnClientEvent:Fire({ Text = "Not enough gold", Kind = "bad" })
	check(g, "a 'bad' notice -> Deny", last() == "Deny", tostring(last()))
	REMOTES.Notify.OnClientEvent:Fire({ Text = "Quest done", Kind = "reward" })
	check(g, "a 'reward' notice -> QuestDone", last() == "QuestDone", tostring(last()))
	clear()
	REMOTES.Notify.OnClientEvent:Fire({ Text = "Hello", Kind = "info" })
	check(g, "an 'info' notice is quiet", #asked == 0, tostring(last()))
	REMOTES.Notify.OnClientEvent:Fire({ Text = "You were robbed!", Kind = "bad", Sound = "None" })
	check(g, "Sound = 'None' keeps even a 'bad' notice quiet", #asked == 0, tostring(last()))
	REMOTES.Notify.OnClientEvent:Fire({ Text = "Daily chest: 30 gold", Kind = "good", Sound = "GoldPickup" })
	check(g, "the payload's Sound key plays", last() == "GoldPickup", tostring(last()))
	REMOTES.Notify.OnClientEvent:Fire({ Text = "Next quest", Kind = "reward", Sound = "None" })
	check(g, "the line after a completion stays quiet (Sound None)", last() == "GoldPickup" and #asked == 1, tostring(last()))
	clear()

	REMOTES.Quests.OnClientEvent:Fire({ { Id = "T1" }, { Id = "D1" } })
	check(g, "the first quest list is quiet", #asked == 0, tostring(last()))
	REMOTES.Quests.OnClientEvent:Fire({ { Id = "T1" }, { Id = "D1" } })
	check(g, "the same list again is quiet", #asked == 0, tostring(last()))
	REMOTES.Quests.OnClientEvent:Fire({ { Id = "D1" }, { Id = "M1_2" } })
	check(g, "a new quest id -> QuestNew", last() == "QuestNew", tostring(last()))
	clear()

	HEART:Fire(0.016)
	open.Panels = true
	HEART:Fire(0.016)
	check(g, "a window opens -> WindowOpen", last() == "WindowOpen", tostring(last()))
	HEART:Fire(0.016)
	check(g, "a window staying open is quiet", #asked == 1, tostring(#asked))
	open.Panels = false
	HEART:Fire(0.016)
	check(g, "a window closes -> WindowClose", last() == "WindowClose", tostring(last()))

	clear()
	table.clear(DELAYS)
	REMOTES.Fx.OnClientEvent:Fire("Reward", { Gold = 3 })
	runDelays(0.1)
	REMOTES.Fx.OnClientEvent:Fire("Reward", { Gold = 3 })
	runDelays(0.1)
	local coins = {}
	for _, a in asked do
		if a.Event == "ComboCoin" then table.insert(coins, a.Opts and a.Opts.Speed) end
	end
	check(g, "two kills in a row: the second coin a step higher", #coins == 2 and near(coins[1], 0.8)
		and near(coins[2], 0.8 * 2 ^ (2 / 12)), encode(coins))
	runDelays(10)
	clear()
	REMOTES.Fx.OnClientEvent:Fire("Reward", { Gold = 3 })
	runDelays(0.1)
	local c1 = nil
	for _, a in asked do
		if a.Event == "ComboCoin" then c1 = a.Opts and a.Opts.Speed end
	end
	check(g, "after the combo time the coin starts low again", near(c1, 0.8), tostring(c1))
	clear()
	REMOTES.Fx.OnClientEvent:Fire("Swing", { UserId = ME, Class = "Warrior", Manual = true, ContactDelay = 0.23,
		Pos = vec(5, 3, 0), Hits = { hit(10, 0) } })
	check(g, "the swing plays now, the hit waits for the contact", last() == "SwingWarrior" and #asked == 1, encode(asked))
	runDelays(0.3)
	check(g, "then the slime squishes", last() == "HitSoft", tostring(last()))

	-- the world listeners (sound_gaps B1-B10)
	local w = "world listeners"
	local function poll(t)
		SERVER.T = t
		waitClock(0.26) -- Audio's Poll (0.25 s)
		HEART:Fire(0.016)
	end
	clear()
	-- B9: into a PvP place, not right after a teleport, nothing on the way out
	PLAYER:SetAttribute("ZonePvP", false)
	check(w, "the first ZonePvP value is quiet", #asked == 0, tostring(last()))
	PLAYER:SetAttribute("ZonePvP", true)
	check(w, "into a PvP place -> ZoneEnterPvP (B9)", last() == "ZoneEnterPvP" and #asked == 1, encode(asked))
	clear()
	PLAYER:SetAttribute("ZonePvP", false)
	check(w, "leaving a PvP place is quiet", #asked == 0, tostring(last()))
	poll(1001) -- the poll keeps my position
	ROOT.Position = vec(300, 3, 0)
	PLAYER:SetAttribute("ZonePvP", true)
	check(w, "a PvP place reached by a teleport (300 studs at once) is quiet", #asked == 0, tostring(last()))
	ROOT.Position = vec(0, 3, 0)
	PLAYER:SetAttribute("ZonePvP", false)
	-- B1: knocked out, then back
	clear()
	REMOTES.Fx.OnClientEvent:Fire("KO", { By = 222, Lost = 10 })
	check(w, "knocked out -> KO (B1)", last() == "KO", tostring(last()))
	PLAYER.CharacterAdded:Fire(CHAR)
	check(w, "my next character after the KO -> Respawn", last() == "Respawn", tostring(last()))
	clear()
	PLAYER.CharacterAdded:Fire(CHAR)
	check(w, "a later character without a KO is quiet", #asked == 0, tostring(last()))
	-- B3 / B4 through the real Fx remote
	REMOTES.Fx.OnClientEvent:Fire("GooseEnd", { Pos = vec(30, 3, 0), Winner = "Halo" })
	check(w, "the goose leaves near me -> GooseEnd (B3)", last() == "GooseEnd", tostring(last()))
	clear()
	REMOTES.Fx.OnClientEvent:Fire("Stomp", { UserId = 222, Pos = vec(30, 3, 0), Radius = 12 })
	local st = asked[1]
	check(w, "a kaiju stomp 30 studs away -> KaijuStomp at 2/3 volume (B4)", st ~= nil and st.Event == "KaijuStomp"
		and near(st.Opts.Volume, 2 / 3), encode(asked))
	-- B5: the kaiju alarm
	clear()
	GAMESTATE:SetAttribute("KaijuPhase", "Siren")
	check(w, "the kaiju alarm -> KaijuSiren (B5)", last() == "KaijuSiren", tostring(last()))
	clear()
	GAMESTATE:SetAttribute("KaijuPhase", "Active")
	check(w, "the kaiju walking is quiet (its stomps come as Fx)", #asked == 0, tostring(last()))
	-- B7: the war round's last 30 s (faction, in the game 30 s+) and the 3-2-1
	clear()
	GAMESTATE:SetAttribute("WarRoundEndsAt", 1040) -- joined at 1000 (server time)
	poll(1009)
	poll(1010.5)
	check(w, "a player in the game only 10 s gets no WarFinal30", #asked == 0, encode(asked))
	GAMESTATE:SetAttribute("WarRoundEndsAt", 5031)
	poll(5000)
	check(w, "31 s left is quiet", #asked == 0, encode(asked))
	poll(5001.5)
	check(w, "30 s left -> WarFinal30 (B7)", last() == "WarFinal30", encode(asked))
	clear()
	poll(5002)
	check(w, "WarFinal30 once per round", #asked == 0, encode(asked))
	poll(5027.8)
	poll(5028.1)
	local tk = asked[#asked]
	check(w, "3 s left -> CountTick at 1.0x", tk ~= nil and tk.Event == "CountTick" and near(tk.Opts.Speed, 1), encode(asked))
	poll(5029.1)
	tk = asked[#asked]
	check(w, "2 s left -> CountTick at 1.12x", tk ~= nil and tk.Event == "CountTick" and near(tk.Opts.Speed, 1.12), encode(asked))
	poll(5030.1)
	tk = asked[#asked]
	check(w, "1 s left -> CountTick at 1.26x", tk ~= nil and tk.Event == "CountTick" and near(tk.Opts.Speed, 1.26), encode(asked))
	clear()
	poll(5031.2)
	check(w, "the end itself adds no tick", #asked == 0, encode(asked))
	PLAYER:SetAttribute("Faction", "Neutral")
	GAMESTATE:SetAttribute("WarRoundEndsAt", 6031)
	poll(6000)
	poll(6001.5)
	check(w, "no faction: no WarFinal30", #asked == 0, encode(asked))
	PLAYER:SetAttribute("Faction", "Halo")
	GAMESTATE:SetAttribute("WarRoundEndsAt", 0)
	-- the kaiju siren's 3-2-1
	GAMESTATE:SetAttribute("KaijuPhase", "Siren")
	GAMESTATE:SetAttribute("KaijuEndsAt", 7010)
	clear()
	poll(7006.8)
	poll(7007.1)
	tk = asked[#asked]
	check(w, "the kaiju siren's 3-2-1 (B5 + B7)", tk ~= nil and tk.Event == "CountTick" and near(tk.Opts.Speed, 1), encode(asked))
	GAMESTATE:SetAttribute("KaijuPhase", "Active")
	GAMESTATE:SetAttribute("KaijuEndsAt", 0)
	-- the goose's 3-2-1 is for its hitters
	GAMESTATE:SetAttribute("GooseActive", false)
	GAMESTATE:SetAttribute("GooseActive", true)
	GAMESTATE:SetAttribute("GooseEndsAt", 8010)
	clear()
	poll(8006.8)
	poll(8007.1)
	check(w, "the goose's 3-2-1 is quiet for players who never hit it", #asked == 0, encode(asked))
	REMOTES.Fx.OnClientEvent:Fire("Swing", { UserId = ME, Class = "Warrior", Manual = true, Pos = vec(5, 3, 0),
		Hits = { hit(0, 0, false, "G") } })
	poll(8007.5)
	clear()
	poll(8008.1)
	tk = asked[#asked]
	check(w, "a goose hitter hears its 3-2-1", tk ~= nil and tk.Event == "CountTick" and near(tk.Opts.Speed, 1.12), encode(asked))
	GAMESTATE:SetAttribute("GooseActive", false)
	GAMESTATE:SetAttribute("GooseEndsAt", 0)
	-- B8: golden monsters coming into view
	clear()
	local gold = addMonster("Slime", 20, 0)
	gold:SetAttribute("Golden", true)
	CAMERA.OnScreen = false
	poll(9000)
	check(w, "a golden monster off screen is quiet", #asked == 0, encode(asked))
	CAMERA.OnScreen = true
	poll(9000.3)
	check(w, "a golden monster on screen within 50 studs -> GoldenSpot (B8)", last() == "GoldenSpot", encode(asked))
	clear()
	poll(9000.6)
	check(w, "GoldenSpot once per monster", #asked == 0, encode(asked))
	local far = addMonster("Slime", 200, 0)
	far:SetAttribute("Golden", true)
	poll(9000.9)
	check(w, "a golden monster 200 studs away is quiet", #asked == 0, encode(asked))
	-- B10: someone else's jackpot line
	clear()
	REMOTES.Announce.OnClientEvent:Fire({ Key = "Jackpot", Args = { Name = "Bo" }, Grade = "Epic" })
	check(w, "someone else's jackpot line -> JackpotOther (B10)", last() == "JackpotOther", tostring(last()))
	clear()
	REMOTES.Announce.OnClientEvent:Fire({ Key = "Jackpot", Args = {}, Self = true })
	REMOTES.Announce.OnClientEvent:Fire({ Key = "RareWeapon", Args = {} })
	REMOTES.Announce.OnClientEvent:Fire({ Key = "PumpkinKing", Args = {}, Event = true })
	check(w, "my own line, rare-weapon lines and event lines are quiet", #asked == 0, encode(asked))
	-- C1: my first weapon's Upgrade is quiet (HUD's first-weapon moment plays PowerUp)
	clear()
	PLAYER:SetAttribute("WeaponTier", 0)
	PLAYER:SetAttribute("WeaponTier", 1)
	REMOTES.Fx.OnClientEvent:Fire("Upgrade", { Tier = 1 })
	check(w, "my first weapon's Upgrade is quiet", #asked == 0, encode(asked))
	waitClock(1.55)
	PLAYER:SetAttribute("WeaponTier", 2)
	REMOTES.Fx.OnClientEvent:Fire("Upgrade", { Tier = 2 })
	check(w, "a later weapon -> Equip", last() == "Equip", encode(asked))
	clear()
	PLAYER:SetAttribute("WeaponTier", 0)
	REMOTES.Fx.OnClientEvent:Fire("Upgrade", { Tier = 1 })
	check(w, "an Upgrade while still bare-handed is quiet too", #asked == 0, encode(asked))
	-- A23-68 #4 / A23-3 (검수 10/08): while the first steps (or the opening, a picker) hold the world's banners, their
	-- sounds wait too; a normal toast still shows, so it still sounds
	local h = "held alarms"
	check(h, "NotifySound: a held announce banner has no sound, the same banner later has", Audio.NotifySound({ Kind = "announce",
		Sound = "GooseArrive" }, true) == nil and Audio.NotifySound({ Kind = "announce", Sound = "GooseArrive" }, false) == "GooseArrive"
		and Audio.NotifySound({ Kind = "bad" }, true) == "Deny", "")
	open.Hold = true
	check(h, "Audio.Held while the first steps hold the banners", Audio.Held() == true, "")
	clear()
	GAMESTATE:SetAttribute("KaijuPhase", "Siren")
	check(h, "no kaiju alarm in the first steps", #asked == 0, encode(asked))
	GAMESTATE:SetAttribute("KaijuEndsAt", 10010)
	poll(10006.8)
	poll(10007.1)
	check(h, "no 3-2-1 in the first steps", #asked == 0, encode(asked))
	GAMESTATE:SetAttribute("KaijuPhase", "Active")
	GAMESTATE:SetAttribute("KaijuEndsAt", 0)
	GAMESTATE:SetAttribute("WarRoundEndsAt", 11031)
	poll(11000)
	poll(11001.5)
	check(h, "no war 30 s call in the first steps", #asked == 0, encode(asked))
	GAMESTATE:SetAttribute("WarRoundEndsAt", 0)
	GAMESTATE:SetAttribute("GooseActive", false)
	GAMESTATE:SetAttribute("GooseActive", true)
	GAMESTATE:SetAttribute("PumpkinKingActive", false)
	GAMESTATE:SetAttribute("PumpkinKingActive", true)
	check(h, "no goose or crown arrival in the first steps", #asked == 0, encode(asked))
	GAMESTATE:SetAttribute("GooseActive", false)
	GAMESTATE:SetAttribute("PumpkinKingActive", false)
	REMOTES.Notify.OnClientEvent:Fire({ Text = "The goose is here!", Kind = "announce", Sound = "GooseArrive" })
	REMOTES.Announce.OnClientEvent:Fire({ Key = "Jackpot", Args = { Name = "Bo" }, Grade = "Epic" })
	check(h, "no sound for a held announce banner or an announce line", #asked == 0, encode(asked))
	REMOTES.Notify.OnClientEvent:Fire({ Text = "Not enough gold", Kind = "bad" })
	check(h, "a normal toast still sounds in the first steps (it still shows)", last() == "Deny", tostring(last()))
	open.Hold = false
	open.Intro = true
	clear()
	GAMESTATE:SetAttribute("KaijuPhase", "Siren")
	check(h, "the opening holds the alarms too", #asked == 0, encode(asked))
	GAMESTATE:SetAttribute("KaijuPhase", "Active")
	open.Intro = false
	clear()
	GAMESTATE:SetAttribute("KaijuPhase", "Siren")
	check(h, "after the first [Claim] the alarm rings again", last() == "KaijuSiren", tostring(last()))
	GAMESTATE:SetAttribute("KaijuPhase", "Active")
	Audio.Play = real

	-- A23-100 music + 점검표 sound 60 water (게임성 개발 1 2026-10-10)
	local m = "music"
	local M, AM = A.Music, A.Ambient
	check(m, "Config: the Halo / Horns town tracks, quieter than the effects, a 1.5 s crossfade",
		M.Tracks.HaloTown == "rbxassetid://108661141883977" and M.Tracks.HornsTown == "rbxassetid://123430641290441"
		and M.Volume > 0 and M.Volume <= 0.6 and M.Fade == 1.5 and M.DuckMul < 1, encode(M))
	check(m, "Config: the water loops, 3D within 40 studs, six Halo waterfall spots",
		AM.Fountain.Id ~= "" and AM.Waterfall.Id ~= "" and AM.Fountain.MaxDistance == 40 and AM.Waterfall.MaxDistance == 40
		and #AM.Waterfall.Spots == 6, encode(AM))
	local SD = Config.Settings
	check(m, "Settings: a Music volume row (0..1 by 0.1, default 1, right after Sound effects)",
		SD.Defs.Music and SD.Defs.Music.Min == 0 and SD.Defs.Music.Max == 1 and SD.Defs.Music.Step == 0.1
		and Config.Data.Defaults.Settings.Music == 1 and SD.Order[2] == "Music" and SD.Text.MusicEn == "Music"
		and Config.SanitizeSettings({ Music = 0.34 }).Music == 0.3 and Config.SanitizeSettings({}).Music == 1)
	check(m, "MusicTrack: the zone's id, nothing where a zone has none", Audio.MusicTrack("HaloTown") == M.Tracks.HaloTown
		and Audio.MusicTrack("Outskirts") == nil and Audio.MusicTrack(nil) == nil)
	local zones8 = { "HaloTown", "HornsTown", "Crossroads", "SlimeMeadow", "GoblinWoods", "SkeletonRuins", "PumpkinPatch", "HauntedHollow" }
	local all8 = true
	for _, z in zones8 do
		if type(M.Tracks[z]) ~= "string" or not string.find(M.Tracks[z], "^rbxassetid://%d+$") then all8 = false end
	end
	check(m, "Config: a track for each of the eight zones (소리 만들기 9d2e3b2)", all8, encode(M.Tracks))
	check(m, "Config: the four boss layers on their zone + GameState flag", M.Boss.SlimeMeadow.Active == "SlimeKingActive"
		and M.Boss.PumpkinPatch.Active == "PumpkinKingActive" and M.Boss.HauntedHollow.Active == "GhostKingActive"
		and M.Boss.SkeletonRuins.Active == "ClatterActive" and M.Boss.SlimeMeadow.Id ~= M.Tracks.SlimeMeadow, encode(M.Boss))
	local function musicSounds(id)
		local out = {}
		for _, so in SOUNDS_MADE do
			if so.Name == "Music" and (id == nil or so.SoundId == id) and not so.Destroyed then table.insert(out, so) end
		end
		return out
	end
	settings.Music, settings.Sfx = 1, 1
	PLAYER:SetAttribute("ZoneId", "Outskirts")
	PLAYER:SetAttribute("ZoneId", "HaloTown")
	local halo = musicSounds(M.Tracks.HaloTown)[1]
	check(m, "entering the Halo town starts its track: looped, in the Music group, from silence", halo ~= nil and halo.IsPlaying
		and halo.Looped == true and halo.Volume == 0 and halo.SoundGroup and halo.SoundGroup.Name == "Music",
		halo and encode({ V = halo.Volume, L = halo.Looped }) or "nil")
	local function beat(sec) for _ = 1, math.floor(sec / 0.25 + 0.5) do HEART:Fire(0.25) end end
	beat(0.75)
	check(m, "... fading in (half way at half the fade)", halo and near(halo.Volume, M.Volume / 2), halo and halo.Volume)
	beat(1)
	check(m, "... and holds the music volume", halo and near(halo.Volume, M.Volume), halo and halo.Volume)
	check(m, "the same zone again: no second track", Audio.SetZoneMusic("HaloTown") == false and #musicSounds() == 1, #musicSounds())
	PLAYER:SetAttribute("ZoneId", "HornsTown")
	local horns = musicSounds(M.Tracks.HornsTown)[1]
	beat(0.75)
	check(m, "into the Horns town: a crossfade (the old down, the new up)", horns and halo and near(horns.Volume, M.Volume / 2)
		and near(halo.Volume, M.Volume / 2), horns and halo and (horns.Volume .. "/" .. halo.Volume) or "nil")
	beat(1)
	check(m, "... the old track stops and goes", halo.IsPlaying == false and halo.Destroyed == true and near(horns.Volume, M.Volume))
	PLAYER:SetAttribute("ZoneId", "Outskirts")
	beat(2)
	check(m, "a zone without a track (the outskirts): quiet (the last one faded out)", horns.IsPlaying == false and #musicSounds() == 0,
		#musicSounds())
	-- the boss layer
	local function layers()
		local out = {}
		for _, so in SOUNDS_MADE do
			if so.Name == "MusicBoss" and not so.Destroyed then table.insert(out, so) end
		end
		return out
	end
	check(m, "BossLayer: the layer only while its boss is out", Audio.BossLayer("SlimeMeadow", GAMESTATE) == nil
		and Audio.BossLayer("HaloTown", GAMESTATE) == nil and Audio.BossLayer("SlimeMeadow", nil) == nil)
	PLAYER:SetAttribute("ZoneId", "SlimeMeadow")
	local meadow = musicSounds(M.Tracks.SlimeMeadow)[1]
	beat(2)
	meadow.TimePosition = 12.5
	check(m, "the meadow track, no layer while King Slime is away", meadow and near(meadow.Volume, M.Volume) and #layers() == 0, #layers())
	GAMESTATE:SetAttribute("SlimeKingActive", true)
	local layer = layers()[1]
	check(m, "King Slime out: his layer starts at the track's TimePosition, looped, in the Music group, from silence",
		layer and layer.SoundId == M.Boss.SlimeMeadow.Id and layer.IsPlaying and layer.Looped and near(layer.TimePosition, 12.5)
		and layer.Volume == 0 and layer.SoundGroup and layer.SoundGroup.Name == "Music",
		layer and encode({ T = layer.TimePosition, V = layer.Volume }) or "nil")
	beat(2)
	check(m, "... fading in to the music volume", layer and near(layer.Volume, M.Volume), layer and layer.Volume)
	GAMESTATE:SetAttribute("SlimeKingActive", false)
	beat(2)
	check(m, "King Slime gone: the layer fades out and stops, the track stays", layer.IsPlaying == false and layer.Destroyed == true
		and meadow.IsPlaying and #layers() == 0)
	GAMESTATE:SetAttribute("SlimeKingActive", true)
	local layer2 = layers()[1]
	beat(2)
	PLAYER:SetAttribute("ZoneId", "Crossroads")
	beat(2)
	check(m, "leaving the meadow during the boss: track and layer both fade out", layer2 and layer2.IsPlaying == false
		and meadow.IsPlaying == false and #layers() == 0, #layers())
	GAMESTATE:SetAttribute("SlimeKingActive", false)
	PLAYER:SetAttribute("ZoneId", "Outskirts")
	beat(2)
	PLAYER:SetAttribute("ZoneId", "HaloTown")
	local again = musicSounds(M.Tracks.HaloTown)[1]
	local group = again and again.SoundGroup
	settings.Music = 0.3
	endAll()
	waitClock(3.1) -- GooseArrive's Gap (earlier tests dropped their duck ends with table.clear(DELAYS))
	Audio.Play("GooseArrive")
	check(m, "a big moment (Duck.By) dips the music too", group and near(group.Volume, 0.3 * M.DuckMul), group and group.Volume)
	runDelays(100)
	check(m, "... and it comes back to the Music setting", group and near(group.Volume, 0.3), group and group.Volume)
	settings.Music = 0.7
	Audio.RefreshVolumes()
	check(m, "the Music setting is the group's volume", group and near(group.Volume, 0.7), group and group.Volume)
	settings.Music = 1
	Audio.RefreshVolumes()
	-- water
	local spots = 0
	for _, so in SOUNDS_MADE do
		if so.Name == "AmbientWaterfall" and so.Looped and so.Parent and so.Parent.Name == "WaterfallSound" then spots += 1 end
	end
	check(m, "a waterfall sound at each of the six Halo spots", spots >= 6, spots)
	local hub = newInstance("Part")
	local w = Audio.Ambient(hub, "Fountain")
	check(m, "a fountain's water: looped, 3D 40 studs, at its volume x Sound effects", w and w.Looped and w.Parent == hub
		and w.RollOffMaxDistance == 40 and near(w.Volume, AM.Fountain.Volume), w and w.Volume)
	settings.Sfx = 0.5
	Audio.RefreshVolumes()
	check(m, "... the Sound effects setting turns it down", w and near(w.Volume, AM.Fountain.Volume * 0.5), w and w.Volume)
	settings.Sfx = 1
	check(m, "no part / no kind: nothing", Audio.Ambient(nil, "Fountain") == nil and Audio.Ambient(hub, "Nope") == nil)

	-- sound_gaps 2026-10-10 (batch 8 + B / C, game dev 1)
	local q = "sound_gaps 10/10"
	-- Replace: the stamp stops the claim's QuestDone (either order)
	endAll()
	waitClock(1.05)
	table.clear(PLAYS)
	Audio.Play("QuestDone")
	local qd = PLAYS[1] and PLAYS[1].Sound
	Audio.Play("StampPress", { Replace = "QuestDone" })
	check(q, "StampPress stops the QuestDone that just started", qd ~= nil and qd.IsPlaying == false and playedName("StampPress"),
		encode(PLAYS))
	endAll()
	waitClock(1.05)
	table.clear(PLAYS)
	Audio.Play("StampPress", { Replace = "QuestDone" })
	check(q, "... and a QuestDone right after it stays quiet", Audio.Play("QuestDone") == false and not playedName("QuestDone"),
		encode(PLAYS))
	waitClock(0.35)
	check(q, "... but not for long (ReplaceWithin)", Audio.Play("QuestDone") == true, "")
	endAll()
	-- listeners from here: what Audio.Play is asked for
	local asked2 = {}
	local real2 = Audio.Play
	Audio.Play = function(event, opts)
		table.insert(asked2, { Event = event, Opts = opts })
		return true
	end
	local function last2() return asked2[#asked2] and asked2[#asked2].Event end
	local function clear2() table.clear(asked2) end
	-- the windows with their own opening
	local win = { Id = nil, Card = false, Kind = nil, Page = nil }
	C.Panels.CurrentId = function() return open.Panels and win.Id or nil end
	C.PauseCard = { IsOpen = function() return win.Card end, OpenKind = function() return win.Card and win.Kind or nil end }
	C.KingDiary = { FocusPage = function() return win.Page end }
	HEART:Fire(0.016)
	clear2()
	local function openPanel(id)
		win.Id, open.Panels = id, true
		HEART:Fire(0.016)
		local ev = last2()
		open.Panels = false
		HEART:Fire(0.016)
		return ev
	end
	check(q, "the quest window opens with QuestOpen", openPanel("Journal") == "QuestOpen", tostring(last2()))
	check(q, "... and closes with WindowClose", last2() == "WindowClose", tostring(last2()))
	win.Page = 3
	check(q, "the King Diary opened on a page ([Read]) = DiaryPage", openPanel("Diary") == "DiaryPage", tostring(last2()))
	win.Page = nil
	check(q, "the King Diary opened without a page = WindowOpen", openPanel("Diary") == "WindowOpen", tostring(last2()))
	local brightId, plainId = nil, nil
	for id, def in Config.StoryQuests.Defs do
		if def.Speaker == "Bright" and not brightId then brightId = id end
		if def.Speaker == nil and not plainId then plainId = id end
	end
	REMOTES.OpenPanel.OnClientEvent:Fire("Story", { Id = brightId, St = 1 })
	check(q, "Bright's story page opens with her blip", brightId ~= nil and openPanel("Story") == "BlipBright", tostring(last2()))
	REMOTES.OpenPanel.OnClientEvent:Fire("Story", { Id = plainId, St = 1 })
	check(q, "a page without a blip speaker = WindowOpen", plainId ~= nil and openPanel("Story") == "WindowOpen", tostring(last2()))
	REMOTES.OpenPanel.OnClientEvent:Fire("Shop", { Id = brightId })
	check(q, "another window's OpenPanel leaves the story speaker alone", openPanel("Story") == "WindowOpen", tostring(last2()))
	check(q, "any other window = WindowOpen", openPanel("Shop") == "WindowOpen", tostring(last2()))
	local keepQO = A.Files.QuestOpen
	A.Files.QuestOpen = ""
	check(q, "an own sound not uploaded = WindowOpen", openPanel("Journal") == "WindowOpen", tostring(last2()))
	A.Files.QuestOpen = keepQO
	local function openCard(kind)
		win.Card, win.Kind = true, kind
		HEART:Fire(0.016)
		local ev = last2()
		win.Card = false
		HEART:Fire(0.016)
		return ev
	end
	check(q, "the welcome-back card opens with WelcomeBack", openCard("Back") == "WelcomeBack", tostring(last2()))
	check(q, "... a card closing = WindowClose", last2() == "WindowClose", tostring(last2()))
	check(q, "a tip card opens with TipDing", openCard("Tip") == "TipDing", tostring(last2()))
	check(q, "the pause card opens with WindowOpen", openCard("Pause") == "WindowOpen", tostring(last2()))
	-- an easter egg found: a hidden quest's row first showing
	clear2()
	REMOTES.Quests.OnClientEvent:Fire({ { Id = "story:M2_3" } })
	clear2()
	REMOTES.Quests.OnClientEvent:Fire({ { Id = "story:M2_3" }, { Id = "story:EG02", Story = { Id = "EG02" } } })
	check(q, "a hidden quest's row showing = SecretFound (not QuestNew)", last2() == "SecretFound" and #asked2 == 1, encode(asked2))
	REMOTES.Quests.OnClientEvent:Fire({ { Id = "story:M2_3" }, { Id = "story:EG02", Story = { Id = "EG02" } } })
	check(q, "... the same row again is quiet", #asked2 == 1, encode(asked2))
	REMOTES.Quests.OnClientEvent:Fire({ { Id = "story:M2_3" }, { Id = "story:EG02", Story = { Id = "EG02" } },
		{ Id = "story:M3_1", Story = { Id = "M3_1" } } })
	check(q, "a plain new quest is still QuestNew", last2() == "QuestNew", tostring(last2()))
	-- my pets
	clear2()
	REMOTES.PetList.OnClientEvent:Fire({ Equipped = "p1", List = { { Uid = "p1", Sp = "BabySlime", Lv = 2 } } })
	check(q, "the first pet list is quiet", #asked2 == 0, encode(asked2))
	REMOTES.PetList.OnClientEvent:Fire({ Equipped = "p1", List = { { Uid = "p1", Sp = "BabySlime", Lv = 2, XP = 5 } } })
	check(q, "pet XP alone is quiet", #asked2 == 0, encode(asked2))
	REMOTES.PetList.OnClientEvent:Fire({ Equipped = "p1", List = { { Uid = "p1", Sp = "BabySlime", Lv = 3 } } })
	check(q, "my pet's level up = PetLevelUp", last2() == "PetLevelUp" and #asked2 == 1, encode(asked2))
	clear2()
	REMOTES.PetList.OnClientEvent:Fire({ Equipped = "", List = { { Uid = "p1", Sp = "BabySlime", Lv = 3 } } })
	check(q, "the follower put away = PetStow", last2() == "PetStow" and #asked2 == 1, encode(asked2))
	clear2()
	REMOTES.PetList.OnClientEvent:Fire({ Equipped = "", List = { { Uid = "p1", Sp = "BabySlime", Lv = 3, XP = 9 } } })
	check(q, "a list with no follower before or now is quiet", #asked2 == 0, encode(asked2))
	REMOTES.PetList.OnClientEvent:Fire({ Equipped = "p2", List = { { Uid = "p1", Lv = 3 }, { Uid = "p2", Sp = "BabySlime", Lv = 1 } } })
	check(q, "a pet starting to follow = PetCall (its first Lv is quiet)", last2() == "PetCall" and #asked2 == 1, encode(asked2))
	clear2()
	REMOTES.PetList.OnClientEvent:Fire({ Equipped = "p2", List = { { Uid = "p1", Lv = 3 }, { Uid = "p2", Sp = "BabySlime", Lv = 1, XP = 3 } } })
	check(q, "the same follower again is quiet", #asked2 == 0, encode(asked2))
	-- the quest marker's goal
	local mk = { Tag = "zone:SlimeMeadow", Shown = true }
	C.QuestMarker = { TargetTag = function() return mk.Tag, mk.Shown end }
	waitClock(1.05) -- MarkerQuiet after the QuestDone above
	clear2()
	HEART:Fire(0.016)
	check(q, "the marker's first goal is quiet", #asked2 == 0, encode(asked2))
	mk.Tag = "blacksmith"
	HEART:Fire(0.016)
	check(q, "a new goal on screen = MarkerMove", last2() == "MarkerMove" and #asked2 == 1, encode(asked2))
	clear2()
	mk.Tag = nil
	HEART:Fire(0.016)
	mk.Tag = "blacksmith"
	HEART:Fire(0.016)
	check(q, "a blink of no goal is not a new goal", #asked2 == 0, encode(asked2))
	mk.Shown, mk.Tag = false, "story:npc"
	HEART:Fire(0.016)
	mk.Shown = true
	HEART:Fire(0.016)
	check(q, "a goal that changed while the marker was hidden is quiet", #asked2 == 0, encode(asked2))
	real2("QuestNew", { Waited = true })
	mk.Tag = "zone:Crossroads"
	HEART:Fire(0.016)
	check(q, "no MarkerMove right on top of a quest's own sound", #asked2 == 0, encode(asked2))
	-- the town's air (HaloDay / HornsDen)
	local function airs(id)
		local out = {}
		for _, so in SOUNDS_MADE do
			if so.Name == "ZoneAir" and not so.Destroyed and (id == nil or so.SoundId == id) then table.insert(out, so) end
		end
		return out
	end
	PLAYER:SetAttribute("ZoneId", "Outskirts")
	beat(2)
	check(q, "no air outside the towns", #airs() == 0, #airs())
	PLAYER:SetAttribute("ZoneId", "HaloTown")
	local air = airs(A.ZoneAmbient.Tracks.HaloTown)[1]
	check(q, "the Halo town's air: looped, in the Sound effects group, from silence", air ~= nil and air.IsPlaying
		and air.Looped == true and air.Volume == 0 and air.SoundGroup and air.SoundGroup.Name == "Sfx",
		air and encode({ V = air.Volume, G = air.SoundGroup and air.SoundGroup.Name }) or "nil")
	beat(2)
	check(q, "... fading in to 0.25", air and near(air.Volume, 0.25), air and air.Volume)
	settings.Sfx = 0.5
	beat(1)
	check(q, "... under the Sound effects setting", air and near(air.Volume, 0.125), air and air.Volume)
	settings.Sfx = 1
	PLAYER:SetAttribute("ZoneId", "HornsTown")
	local den = airs(A.ZoneAmbient.Tracks.HornsTown)[1]
	beat(2)
	check(q, "into the Horns town: HornsDen in, the Halo air out and gone", den and near(den.Volume, 0.25) and air.IsPlaying == false
		and air.Destroyed == true, den and den.Volume)
	PLAYER:SetAttribute("ZoneId", "Crossroads")
	beat(2)
	check(q, "a zone without air: quiet again", #airs() == 0 and den.Destroyed == true, #airs())
	-- 13차 dusk lamps
	clear2()
	GAMESTATE:SetAttribute("DayPhase", "Day")
	check(q, "the first DayPhase (with the join) is quiet", #asked2 == 0, encode(asked2))
	GAMESTATE:SetAttribute("DayPhase", "Dusk")
	check(q, "dusk: the lamps come on = LanternOn", last2() == "LanternOn" and #asked2 == 1, encode(asked2))
	GAMESTATE:SetAttribute("DayPhase", "Night")
	check(q, "night after dusk is quiet", #asked2 == 1, encode(asked2))
	GAMESTATE:SetAttribute("DayPhase", nil)
	GAMESTATE:SetAttribute("DayPhase", "Dusk")
	check(q, "a dusk with no phase before it (a fresh server value) is quiet", #asked2 == 1, encode(asked2))
	-- A23-105 weather air
	local wx = { Weather = "Rain", Phase = "Day", Enabled = true, Covered = false }
	C.WeatherFx = { State = function() return wx end }
	local function wloop(key)
		for _, so in SOUNDS_MADE do
			if so.Name == "Weather" .. key and not so.Destroyed then return so end
		end
		return nil
	end
	local WL = A.Weather.Loops
	beat(0.75)
	local rain = wloop("Rain")
	check(q, "rain starts its loop from silence in the Sound effects group, fading in", rain and rain.Looped and rain.IsPlaying
		and rain.SoundGroup and rain.SoundGroup.Name == "Sfx" and near(rain.Volume, WL.Rain.Volume * 0.5),
		rain and rain.Volume)
	beat(1)
	check(q, "... to its volume", rain and near(rain.Volume, WL.Rain.Volume), rain and rain.Volume)
	wx.Covered = true
	beat(2)
	local roof = wloop("RainRoof")
	check(q, "under a roof: RainRoof in, the open rain out and gone", roof and near(roof.Volume, WL.RainRoof.Volume)
		and rain.Destroyed == true and wloop("Rain") == nil, roof and roof.Volume)
	settings.Sfx = 0.5
	beat(1)
	check(q, "the weather air follows the Sound effects setting", roof and near(roof.Volume, WL.RainRoof.Volume * 0.5), roof and roof.Volume)
	settings.Sfx = 1
	wx.Weather, wx.Phase, wx.Covered = "Clear", "Night", false
	beat(2)
	local night = wloop("Night")
	check(q, "a clear night: crickets, the rain gone", night and near(night.Volume, WL.Night.Volume) and roof.Destroyed == true, night and night.Volume)
	wx.Phase = "Day"
	beat(2)
	check(q, "morning: quiet again", wloop("Night") == nil and night.Destroyed == true, "")
	wx.Weather = "Rain"
	beat(0.5)
	local rain2 = wloop("Rain")
	check(q, "rain coming back starts a new live loop", rain2 ~= nil and rain2 ~= rain and rain2.IsPlaying and rain2.Volume > 0,
		rain2 and rain2.Volume)
	wx.Weather = "Clear"
	beat(2)
	C.WeatherFx = nil
	-- a warp (the server moving me far at once)
	clear2()
	table.clear(DELAYS)
	ROOT.Position = vec(0, 3, 0)
	HEART:Fire(0.016)
	clear2()
	ROOT.Position = vec(500, 3, 0)
	HEART:Fire(0.016)
	check(q, "moved 500 studs in one frame = Warp", last2() == "Warp" and #asked2 == 1, encode(asked2))
	runDelays(A.WarpInAfter + 0.01)
	check(q, "... then WarpIn WarpInAfter s later", last2() == "WarpIn" and #asked2 == 2, encode(asked2))
	clear2()
	ROOT.Position = vec(510, 3, 0)
	HEART:Fire(0.016)
	check(q, "a normal step is quiet", #asked2 == 0, encode(asked2))
	PLAYER.CharacterAdded:Fire(CHAR)
	clear2()
	ROOT.Position = vec(0, 3, 0)
	HEART:Fire(0.016)
	check(q, "the jump to a new character's spawn is not a warp", #asked2 == 0, encode(asked2))
	Audio.Play = real2
end

local list = {}
for _, key in order do table.insert(list, Named[key]) end
print("AUDIO_RESULT_JSON " .. encode({ Checks = checks, Failed = failed, Named = list }))
if failed == 0 then print(("AUDIO_OFFLINE_OK checks=%d Studio/API calls=0"):format(checks)) end
