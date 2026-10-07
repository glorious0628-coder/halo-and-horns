-- Audio.luau : the game's sound effects (quality ①, docs/design/quality_ideas_2026-10-06.md §1 = BB23's first half),
-- built to 검수's sound table (docs/design/lines_pack_2026-10-06.md §6; events, volumes, speeds, copies, cooldowns in
-- Config.Audio). It only LISTENS - it never edits Fx or HUD (both sit near Luau's 200-local limit):
--   "Fx" remote (the packets Fx draws):
--     Swing   -> the class swing (Warrior / Mage / Archer, bare hands a short Warrior swish, the pet tamer's whistle;
--                Neutral Blacksmith / Alchemist pitched lower), then ONE hit sound when the hits land (ContactDelay):
--                HitSoft for slimes / ghosts / pumpkins, HitHeavy for everything else, players, crits and swings that
--                hit HitHeavyAt+ monsters; a golden goose hit honks. Other players' swings: x OthersMul within OthersRange.
--     Release -> SkillCast (my class swing file at 0.85x) + on the X skill my faction's layer (SkillHalo / SkillHorns),
--                then the hit sound; Fx's own skill sound is muted once our swing files exist
--     Reward (my kill) -> KillPop + ComboCoin one scale step higher per kill (Config.Audio.Combo, reset after
--                Config.Combo.ResetSeconds) + ComboMilestone at Config.Combo.Milestones (x10 / 25 / 50 / 100)
--     Enhance -> ScrollSuccess / ScrollFail; Bank / Upgrade / Rare -> GoldPickup; LevelUp (mine) -> LevelUp;
--     Hurt (a hit taking HurtBigFrac of my max HP, or leaving me under 30 %) -> HurtBig
--   GameState: PumpkinKingActive / GhostKingActive turning on -> PumpkinKing / GhostKing; GooseActive -> GooseHonk
--   my attributes: AutoCombatEnabled -> AutoOn / AutoOff; Honor up -> Purify, Infamy up -> Devour (GDD §0); my own
--     faction's points going down (A23-58, not a faction change) -> RankDown; HP / MP potion count down -> Potion.
--     Values that arrive with the save never sound.
--   "Notify" remote: payload.Sound (dev2 2c5e84e, sound_spec §4-1) = the Config.Audio key of that line, "None" = no
--   sound; without it kind "bad" -> Deny, "reward" -> QuestDone; "Quests" remote: a new quest id -> QuestNew;
--   Fx "Choice" { Option = "Good" | "Evil" } (the story choice itself, to the chooser) -> Purify / Devour
--   windows: C.Panels / C.WorldMap / C.PlayerListUI IsOpen() turning on / off -> WindowOpen / WindowClose
-- Rules (§6): every event keeps its own pool of Max copies (a new play is skipped when all are busy) and its cooldown;
-- at most MaxPlaying sounds at once; auto combat plays Auto sounds at AutoMul; the big moments (Duck.By) lower the
-- combat sounds to Duck.Mul for Duck.Seconds; the Sound effects setting (Settings "Sfx" 0..1) scales everything and 0
-- is silent. An event whose file id is "" never plays, so nothing changes before the uploads. Fx's old defaults
-- (Config.Sounds Swing / Release / Coin) are muted on this client once our files exist; Click becomes our Tap.
--
-- Public API: Audio.Init(C), Audio.Start(), Audio.Play(event, opts?) -> bool (opts { File, Speed, SpeedMul, Volume,
--   Auto, Others }), Audio.Talk(speaker?) -> bool (typewriter blips, quality ②), Audio.Plan(kind, data, ctx) -> list of
--   { Event, At, File?, SpeedMul?, Speed?, Volume, Auto?, Others? } (pure: what one Fx packet plays; the offline test
--   drives it), Audio.OnFx(kind, data). "No" (SkillBar) is an alias of Deny.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local LocalPlayer = Players.LocalPlayer

local Audio = {}

local TAG = "Audio"
local C = nil -- client registry (set in Init)

local A = type(Config.Audio) == "table" and Config.Audio or {}
local FILES = type(A.Files) == "table" and A.Files or {}
local SOUNDS = type(A.Sounds) == "table" and A.Sounds or {}

----------------------------------------------------------------- tuning
local T = {
	AutoMul = tonumber(A.AutoMul) or 0.5,
	OthersMul = tonumber(A.OthersMul) or 0.35,
	OthersRange = tonumber(A.OthersRange) or 40,
	MaxPlaying = tonumber(A.MaxPlaying) or 8,
	HitHeavyAt = tonumber(A.HitHeavyAt) or 3,
	HurtBigFrac = tonumber(A.HurtBigFrac) or 0.15,
	HurtLowFrac = 0.3,
	Duck = type(A.Duck) == "table" and A.Duck or { Mul = 0.5, Seconds = 1.2, By = {} },
	Combo = type(A.Combo) == "table" and A.Combo or { Base = 0.8, Top = 1.6, Steps = { 0, 2, 4, 5, 7, 9, 11, 12 } },
	ComboReset = tonumber(Config.Combo and Config.Combo.ResetSeconds) or 4,
	ContactDefault = 0.25, -- s: when the hits land if the packet has no ContactDelay
	LaunchDefault = 0.22,
	PunchVolume = 0.6,
	Windows = { "Panels", "WorldMap", "PlayerListUI" },
	Kings = { PumpkinKingActive = "PumpkinKing", GhostKingActive = "GhostKing" },
	QuietStart = 3, -- s after Start: GameState flags that flip now came with the join
	FactionCalm = 3, -- s after a faction change: points falling to 0 are not a RankDown
	NearMonster = 8, -- studs: the monster a hit belongs to
	Life = 4, -- s: a copy that never ends (an id that does not load) is freed after this
	Aliases = { No = "Deny" },
}

-- monster kinds whose hit is the soft one (slimes, ghosts, pumpkins); everything else is heavy
local SOFT = type(A.SoftKinds) == "table" and A.SoftKinds or {}
local SWING = type(A.Swing) == "table" and A.Swing or {}
local NEUTRAL_SPEED = type(A.NeutralSpeed) == "table" and A.NeutralSpeed or {}
local TALK = type(A.Talk) == "table" and A.Talk or { Default = 1 }
local MILESTONES = {}
for _, m in (Config.Combo and Config.Combo.Milestones) or {} do
	if type(m) == "table" and type(m[1]) == "number" then MILESTONES[m[1]] = true end
end

----------------------------------------------------------------- state
local S = {
	Folder = nil, Groups = {}, -- SoundGroups "Sfx" and "SfxCombat" (the combat one is ducked)
	Pools = {}, -- [event] = { Sound, ... } (up to Max)
	Last = {}, -- [event] = os.clock() of the last start
	Combo = 0, ComboToken = 0, DuckToken = 0,
	Win = {}, -- [module name] = last IsOpen()
	QuestIds = nil, -- ids of the last quest list (nil until the first list)
	PlayToken = setmetatable({}, { __mode = "k" }), -- [Sound] = its latest play
	FactionAt = -math.huge,
	StartedAt = 0, WarnAt = {},
}

local function num(v, default)
	v = tonumber(v)
	if v == nil or v ~= v or math.abs(v) == math.huge then return default end
	return v
end

local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (S.WarnAt[key] or -math.huge) < 10 then return end
	S.WarnAt[key] = now
	Util.Warn(TAG, tostring(msg))
end

----------------------------------------------------------------- planning (pure)
local function add(out, event, at, extra)
	local p = { Event = event, At = at or 0, Volume = 1 }
	for k, v in extra or {} do p[k] = v end
	table.insert(out, p)
	return p
end

-- the one hit sound of a swing / skill (nil = no hit). ctx.KindAt(pos) names the monster a "M" hit landed on
local function hitEvent(hits, ctx)
	if type(hits) ~= "table" then return nil end
	local monsters, heavy, goose = 0, false, false
	for i, h in hits do
		if type(h) == "table" and i <= 16 then
			if h.K == "G" then
				goose = true
			elseif h.K == "P" then
				heavy = true
			elseif h.K == "M" then
				monsters += 1
				if h.C == true then
					heavy = true
				else
					local kind = nil
					if type(ctx.KindAt) == "function" then
						local ok, k = pcall(ctx.KindAt, h.P)
						kind = ok and k or nil
					end
					if not (type(kind) == "string" and SOFT[kind]) then heavy = true end
				end
			end
		end
	end
	if heavy or monsters >= T.HitHeavyAt then return "HitHeavy", goose end
	if monsters > 0 then return "HitSoft", goose end
	return nil, goose
end

local function planHits(out, data, at, extra, ctx)
	local event, goose = hitEvent(data.Hits, ctx)
	if event then add(out, event, at, extra) end
	if goose then add(out, "GooseHonk", at, extra) end
end

-- the swing file and speed factor of a packet's class / weapon style (+ the bare-hands volume)
local function swingOf(data, faction)
	local style = type(data.Style) == "string" and data.Style or nil
	local class = type(data.Class) == "string" and data.Class or "Warrior"
	local file = (style and SWING[style]) or SWING[class] or SWING.Warrior or "SwingWarrior"
	local speedMul, volume = 1, 1
	if style == "Punch" then
		speedMul, volume = num(A.PunchSpeed, 1.3), T.PunchVolume
	elseif not style and faction == "Neutral" then
		speedMul = num(NEUTRAL_SPEED[class], 1)
	end
	return file, speedMul, volume
end

-- what one Fx packet plays on this client. ctx = { Me = my UserId, Faction = my faction, Combo = this kill's number in
-- the combo (Reward), KindAt = function(pos) -> monster kind?, Near = function(pos) -> studs from me?, HP, MaxHP }
function Audio.Plan(kind, data, ctx)
	local out = {}
	if type(kind) ~= "string" or type(data) ~= "table" or type(ctx) ~= "table" then return out end
	local uid = num(data.UserId, nil)
	local own = uid ~= nil and uid == ctx.Me
	if kind == "Swing" or kind == "Release" then
		local others = false
		if not own then
			-- other players' combat: quieter, and only near me (UI sounds stay mine)
			local at = typeof(data.Pos) == "Vector3" and data.Pos or data.From
			local d = type(ctx.Near) == "function" and at ~= nil and ctx.Near(at) or nil
			if uid == nil or d == nil or d > T.OthersRange then return out end
			others = true
		end
		local auto = (kind == "Swing" and data.Manual ~= true) or (kind == "Release" and data.Auto == true)
		local extra = { Auto = auto, Others = others }
		local file, speedMul, volume = swingOf(data, own and ctx.Faction or data.Faction)
		if kind == "Swing" then
			local at = 0
			if file == SWING.Archer and data.Style == nil then
				at = math.clamp(num(data.LaunchDelay, T.LaunchDefault), 0, 1) -- the bow twangs when the arrow leaves
			end
			local event = (file == "SwingMage" and "SwingMage") or (file == "SwingArcher" and "SwingArcher")
				or (file == "SwingTamer" and "SwingTamer") or "SwingWarrior"
			add(out, event, at, { Auto = auto, Others = others, SpeedMul = speedMul, Volume = volume })
		else
			add(out, "SkillCast", 0, { Auto = auto, Others = others, File = file })
			if own and data.Slot == "X" then
				local layer = (ctx.Faction == "Halo" and "SkillHalo") or (ctx.Faction == "Horns" and "SkillHorns") or nil
				if layer then add(out, layer, 0, { Auto = auto }) end
			end
		end
		planHits(out, data, math.clamp(num(data.ContactDelay, T.ContactDefault), 0, 1), extra, ctx)
	elseif kind == "Reward" then -- the server sends it to the killer only
		local combo = math.max(1, math.floor(num(ctx.Combo, 1)))
		local steps = T.Combo.Steps
		local step = num(steps[math.min(combo, #steps)], 0)
		local speed = math.min(num(T.Combo.Top, 1.6), num(T.Combo.Base, 0.8) * 2 ^ (step / 12))
		add(out, "KillPop", 0)
		add(out, "ComboCoin", 0.05, { Speed = speed })
		if MILESTONES[combo] then add(out, "ComboMilestone", 0.15) end
	elseif kind == "Choice" then -- the story choice itself (sound_spec §4-1; the server sends it to the chooser only)
		if data.Option == "Good" then
			add(out, "Purify", 0)
		elseif data.Option == "Evil" then
			add(out, "Devour", 0)
		end
	elseif kind == "Enhance" then
		add(out, data.Success == true and "ScrollSuccess" or "ScrollFail", 0)
	elseif kind == "Bank" or kind == "Upgrade" or kind == "Rare" then
		add(out, "GoldPickup", 0)
	elseif kind == "LevelUp" then
		if own then add(out, "LevelUp", 0) end
	elseif kind == "Hurt" then
		local amount, maxHP = num(data.Amount, 0), num(ctx.MaxHP, 0)
		local hp = num(ctx.HP, maxHP)
		if maxHP > 0 and amount > 0 and (amount >= maxHP * T.HurtBigFrac or hp < maxHP * T.HurtLowFrac) then
			add(out, "HurtBig", 0)
		end
	end
	return out
end

----------------------------------------------------------------- playback
local function sfxMult()
	local st = C and C.Settings
	if type(st) == "table" and type(st.Get) == "function" then
		local ok, v = pcall(st.Get, "Sfx")
		if ok and type(v) == "number" and v == v then return math.clamp(v, 0, 1) end
	end
	return 1
end

local function idOf(file)
	local id = type(file) == "string" and FILES[file] or nil
	if type(id) ~= "string" or id == "" then return nil end
	return id
end

-- the file an event plays this time (Files = variants: one at random); nil = no id yet
local function fileOf(def, override)
	if type(override) == "string" then return idOf(override) and override or nil end
	if type(def.Files) == "table" and #def.Files > 0 then
		local ready = {}
		for _, f in def.Files do
			if idOf(f) then table.insert(ready, f) end
		end
		if #ready == 0 then return nil end
		return ready[math.random(1, #ready)]
	end
	return idOf(def.File) and def.File or nil
end

local function playingCount()
	local n = 0
	for _, pool in S.Pools do
		for _, s in pool do
			if s.IsPlaying then n += 1 end
		end
	end
	return n
end

-- a free copy of the event's pool (made up to Max), or nil when all of them are playing
local function freeSound(event, def)
	local pool = S.Pools[event]
	if not pool then
		pool = {}
		S.Pools[event] = pool
	end
	for _, s in pool do
		if not s.IsPlaying then return s end
	end
	if #pool >= math.max(1, math.floor(num(def.Max, 1))) then return nil end
	local s = Instance.new("Sound")
	s.Name = "Sfx_" .. event .. "_" .. (#pool + 1)
	s.Parent = S.Folder
	table.insert(pool, s)
	return s
end

function Audio.Play(event, opts)
	if type(event) ~= "string" then return false end
	event = T.Aliases[event] or event
	local def = SOUNDS[event]
	if type(def) ~= "table" or not S.Folder then return false end
	opts = type(opts) == "table" and opts or {}
	local file = fileOf(def, opts.File)
	if not file then return false end
	local mult = sfxMult()
	if mult <= 0 then return false end
	local now = os.clock()
	local last = S.Last[event]
	if last and now - last < num(def.Gap, 0.03) then return false end
	if playingCount() >= T.MaxPlaying then return false end
	local s = freeSound(event, def)
	if not s then return false end
	S.Last[event] = now
	local speed = num(opts.Speed, nil)
	if not speed then
		local range = type(def.Speed) == "table" and def.Speed or { 1, 1 }
		local lo, hi = num(range[1], 1), num(range[2] or range[1], 1)
		speed = lo + (hi - lo) * math.random()
	end
	speed *= num(opts.SpeedMul, 1)
	local volume = num(def.Volume, 0.5) * num(opts.Volume, 1) * mult
	if opts.Auto == true and def.Auto == true then volume *= T.AutoMul end
	if opts.Others == true then volume *= T.OthersMul end
	local ok, err = pcall(function()
		local id = idOf(file)
		if s.SoundId ~= id then s.SoundId = id end
		s.Volume = math.clamp(volume, 0, 3)
		s.PlaybackSpeed = math.clamp(speed, 0.25, 4)
		s.SoundGroup = def.Combat == true and S.Groups.Combat or S.Groups.Sfx
		s.TimePosition = 0
		s:Play()
		-- a copy that never ends (an id that does not load) is freed; a later play of the same copy keeps its own token
		local token = (S.PlayToken[s] or 0) + 1
		S.PlayToken[s] = token
		task.delay(T.Life, function()
			if S.PlayToken[s] == token and s.IsPlaying then s:Stop() end
		end)
	end)
	if not ok then
		warnThrottled("play", "play " .. event .. " failed: " .. tostring(err))
		return false
	end
	-- the big moments lower the combat sounds for a moment (§6)
	if T.Duck.By and T.Duck.By[event] and S.Groups.Combat then
		S.DuckToken += 1
		local token = S.DuckToken
		S.Groups.Combat.Volume = num(T.Duck.Mul, 0.5)
		task.delay(num(T.Duck.Seconds, 1.2), function()
			if S.DuckToken == token and S.Groups.Combat then S.Groups.Combat.Volume = 1 end
		end)
	end
	return true
end

-- typewriter blips (quality ②): Config.Audio.Talk[speaker] = blip speed (the shard high, the Horns guide low)
function Audio.Talk(speaker)
	local speed = num(TALK[speaker], nil) or num(TALK.Default, 1)
	return Audio.Play("TalkBlip", { Speed = speed * (1 + (math.random() * 2 - 1) * 0.04) })
end

----------------------------------------------------------------- listeners
local function myRoot()
	local char = LocalPlayer and LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

-- the monster nearest to a hit position (hits carry positions only)
local function kindAt(pos)
	if typeof(pos) ~= "Vector3" then return nil end
	local folder = workspace:FindFirstChild("Monsters")
	if not folder then return nil end
	local best, bestD = nil, T.NearMonster
	for _, m in folder:GetChildren() do
		if m:IsA("Model") then
			local ok, pivot = pcall(m.GetPivot, m)
			if ok then
				local d = (pivot.Position - pos).Magnitude
				if d < bestD then best, bestD = m, d end
			end
		end
	end
	return best and best:GetAttribute("MonsterKind") or nil
end

local function nearMe(pos)
	local root = myRoot()
	if not root or typeof(pos) ~= "Vector3" then return nil end
	return (root.Position - pos).Magnitude
end

local function bumpCombo()
	S.Combo += 1
	S.ComboToken += 1
	local token = S.ComboToken
	task.delay(T.ComboReset, function()
		if S.ComboToken == token then S.Combo = 0 end
	end)
end

function Audio.OnFx(kind, data)
	if kind == "Reward" then bumpCombo() end
	local hum = LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local plan = Audio.Plan(kind, data, {
		Me = LocalPlayer and LocalPlayer.UserId,
		Faction = LocalPlayer and LocalPlayer:GetAttribute("Faction"),
		Combo = S.Combo,
		KindAt = kindAt,
		Near = nearMe,
		HP = hum and hum.Health or nil,
		MaxHP = hum and hum.MaxHealth or nil,
	})
	for _, p in plan do
		if p.At > 0 then
			task.delay(p.At, Audio.Play, p.Event, p)
		else
			Audio.Play(p.Event, p)
		end
	end
end

-- the sound of one Notify line: payload.Sound wins ("None" = silent), else the kind ("bad" -> Deny, "reward" ->
-- QuestDone), else nothing
function Audio.NotifySound(payload)
	if type(payload) ~= "table" then return nil end
	local sound = payload.Sound
	if type(sound) == "string" and sound ~= "" then
		if sound == "None" then return nil end
		return sound
	end
	if payload.Kind == "bad" then return "Deny" end
	if payload.Kind == "reward" then return "QuestDone" end
	return nil
end

-- calls fn(previous, value) on every change of inst's attribute
local function watch(inst, key, fn)
	local last = inst:GetAttribute(key)
	inst:GetAttributeChangedSignal(key):Connect(function()
		local prev = last
		last = inst:GetAttribute(key)
		local ok, err = pcall(fn, prev, last)
		if not ok then warnThrottled("attr", key .. ": " .. tostring(err)) end
	end)
end

local function loaded()
	return LocalPlayer ~= nil and LocalPlayer:GetAttribute("DataLoaded") == true
end

local function watchMe()
	watch(LocalPlayer, "AutoCombatEnabled", function(prev, v)
		if prev == nil or not loaded() then return end
		if v == true and prev ~= true then
			Audio.Play("AutoOn")
		elseif v ~= true and prev == true then
			Audio.Play("AutoOff")
		end
	end)
	watch(LocalPlayer, "Faction", function() S.FactionAt = os.clock() end)
	for _, stat in { "Honor", "Infamy" } do
		watch(LocalPlayer, stat, function(prev, v)
			if type(prev) ~= "number" or type(v) ~= "number" or not loaded() then return end
			if v > prev then
				return -- Purify / Devour come with the Choice Fx (the choice itself, not every point change)
			elseif v < prev and os.clock() - S.FactionAt > T.FactionCalm then
				-- A23-58: my own side's points going down (an off-side choice); a faction change resets both quietly
				local mine = LocalPlayer:GetAttribute("Faction")
				if (mine == "Halo" and stat == "Honor") or (mine == "Horns" and stat == "Infamy") then Audio.Play("RankDown") end
			end
		end)
	end
	for _, key in { Config.PotionStockKey and Config.PotionStockKey("HP") or "HPPotionCount",
		Config.PotionStockKey and Config.PotionStockKey("MP") or "MPPotionCount" } do
		watch(LocalPlayer, key, function(prev, v)
			if type(prev) == "number" and type(v) == "number" and v < prev and loaded() then Audio.Play("Potion") end
		end)
	end
end

local function watchGame()
	local ok, gs = pcall(Net.GameState)
	if not ok or not gs then return end
	local function fresh() return os.clock() - S.StartedAt >= T.QuietStart end
	for key, event in T.Kings do
		watch(gs, key, function(prev, v)
			if v == true and prev ~= true and fresh() then Audio.Play(event) end
		end)
	end
	watch(gs, "GooseActive", function(prev, v)
		if v == true and prev ~= true and fresh() then Audio.Play("GooseHonk") end
	end)
end

local function pollWindows()
	for _, name in T.Windows do
		local m = C and C[name]
		if type(m) == "table" and type(m.IsOpen) == "function" then
			local ok, open = pcall(m.IsOpen)
			open = ok and open == true
			local was = S.Win[name]
			if was ~= nil and was ~= open then Audio.Play(open and "WindowOpen" or "WindowClose") end
			S.Win[name] = open
		end
	end
end

-- the quest list (CR-L50 "Quests" remote): a quest id that was not there before = a new quest (not the first list)
function Audio.OnQuests(payload)
	local list = payload
	if type(payload) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, payload)
		list = ok and decoded or nil
	elseif type(payload) == "table" and type(payload.Quests) == "table" then
		list = payload.Quests
	end
	if type(list) ~= "table" then return end
	local ids, fresh = {}, false
	for _, e in list do
		if type(e) == "table" and e.Id ~= nil then
			local id = tostring(e.Id)
			ids[id] = true
			if S.QuestIds and not S.QuestIds[id] then fresh = true end
		end
	end
	S.QuestIds = ids
	if fresh then Audio.Play("QuestNew") end
end

-- our files replace Fx's defaults on this client (Config.Sounds: Swing -> the class swings, Release -> SkillCast,
-- Coin -> ComboCoin / GoldPickup, Click -> Tap); the old built-in files stay only while ours have no id
local function takeOver()
	local fx = Config.Sounds
	if type(fx) ~= "table" then return end
	if idOf("SwingWarrior") then
		fx.Swing = ""
		fx.Release = ""
	end
	if idOf("ComboCoin") then fx.Coin = "" end
	local tap = idOf("Tap")
	if tap then fx.Click = tap end
end

----------------------------------------------------------------- lifecycle
function Audio.Init(registry)
	C = registry
end

function Audio.Start()
	S.StartedAt = os.clock()
	local folder = Instance.new("Folder")
	folder.Name = "AudioSfx"
	folder.Parent = SoundService
	S.Folder = folder
	for key, name in { Sfx = "Sfx", Combat = "SfxCombat" } do
		local group = Instance.new("SoundGroup")
		group.Name = name
		group.Volume = 1
		group.Parent = SoundService
		S.Groups[key] = group
	end
	takeOver()

	-- preload every uploaded file so the first swing is never silent
	task.spawn(function()
		local list = {}
		for _, id in FILES do
			if type(id) == "string" and id ~= "" then
				local s = Instance.new("Sound")
				s.SoundId = id
				table.insert(list, s)
			end
		end
		if #list > 0 then
			local ok, err = pcall(function() ContentProvider:PreloadAsync(list) end)
			if not ok then warnThrottled("preload", "preload failed: " .. tostring(err)) end
		end
		for _, s in list do s:Destroy() end
	end)

	if LocalPlayer then watchMe() end
	task.spawn(watchGame)
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(pollWindows)
		if not ok then warnThrottled("windows", "window watch failed: " .. tostring(err)) end
	end)
	-- the remotes normally exist already; never block the other client modules' Start on them
	task.spawn(function()
		Net.Get("Fx").OnClientEvent:Connect(function(kind, data)
			local ok, err = pcall(Audio.OnFx, kind, data)
			if not ok then warnThrottled("fx", tostring(kind) .. ": " .. tostring(err)) end
		end)
	end)
	task.spawn(function()
		Net.Get("Notify").OnClientEvent:Connect(function(payload)
			local event = Audio.NotifySound(payload)
			if event then Audio.Play(event) end
		end)
	end)
	task.spawn(function()
		Net.Get("Quests").OnClientEvent:Connect(function(payload)
			local ok, err = pcall(Audio.OnQuests, payload)
			if not ok then warnThrottled("quests", tostring(err)) end
		end)
	end)
	print("[Audio] started")
end

return Audio
