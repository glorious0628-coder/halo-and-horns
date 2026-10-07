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
local WORKSPACE = { FindFirstChild = function(_, n) if n == "Monsters" then return MONSTERS end return nil end }

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
local REMOTES = { Fx = { OnClientEvent = signal() }, Notify = { OnClientEvent = signal() }, Quests = { OnClientEvent = signal() } }
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
	local Util = { Warn = function() end }
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
	check(g, "both kings share one file", A.Sounds.PumpkinKing.File == A.Sounds.GhostKing.File, "")
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
end

----------------------------------------------------------------- runtime
do
	local g = "runtime"
	local settings = { Sfx = 1 }
	local open = { Panels = false }
	local C = { Settings = { Get = function(k) return settings[k] end }, Panels = { IsOpen = function() return open.Panels end } }
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
	check(g, "the Pumpkin King rings the king bell at 0.90-0.95x", p and p.Id == "rbxassetid://KingBell" and p.Speed >= 0.9 - 1e-9
		and p.Speed <= 0.95 + 1e-9, encode(p or {}))
	local combatGroup = nil
	for _, s in SOUNDS_MADE do
		if s.SoundGroup and s.SoundGroup.Name == "SfxCombat" then combatGroup = s.SoundGroup end
	end
	check(g, "a big moment ducks the combat sounds to 0.5", combatGroup ~= nil and near(combatGroup.Volume, 0.5),
		tostring(combatGroup and combatGroup.Volume))
	runDelays(1.3)
	check(g, "and they come back after 1.2 s", combatGroup ~= nil and near(combatGroup.Volume, 1), tostring(combatGroup and combatGroup.Volume))
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
	Audio.Play = real
end

local list = {}
for _, key in order do table.insert(list, Named[key]) end
print("AUDIO_RESULT_JSON " .. encode({ Checks = checks, Failed = failed, Named = list }))
if failed == 0 then print(("AUDIO_OFFLINE_OK checks=%d Studio/API calls=0"):format(checks)) end
