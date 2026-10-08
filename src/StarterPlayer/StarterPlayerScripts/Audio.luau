-- Audio.luau : the game's sound effects (quality ①, docs/design/quality_ideas_2026-10-06.md §1 = BB23's first half),
-- built to 검수's sound table (docs/design/lines_pack_2026-10-06.md §6; events, volumes, speeds, copies, cooldowns in
-- Config.Audio). It only LISTENS - it never edits Fx or HUD (both sit near Luau's 200-local limit):
--   "Fx" remote (the packets Fx draws):
--     Swing   -> the class swing (Warrior / Mage / Archer, bare hands a short Warrior swish, the pet tamer's whistle;
--                Neutral Blacksmith / Alchemist pitched lower; Halo / Horns mages their faction file timed so its peak
--                lands on the launch; the bow's arrow when it leaves, a second arrow for 2+ targets), then ONE hit sound
--                when the hits land (ContactDelay): HitSoft for slimes / ghosts / pumpkins (ghosts higher), HitHeavy for
--                everything else and players, louder / lower for HitMany.From+ monsters, + HitCrit when the first
--                target is a critical hit; a golden goose hit honks. Other players' swings: x OthersMul within OthersRange.
--     Release (Q) / Skill (Z, X: sound_gaps B13) -> SkillCast (my class swing file at 0.85x) at the launch + my
--                faction's layer (SkillHalo / SkillHorns) on every slot, then the hit sound; Fx's own skill sound is
--                muted once our swing files exist
--     Reward (my kill) -> KillPop + ComboCoin one scale step higher per kill (Config.Audio.Combo, reset after
--                Config.Combo.ResetSeconds) + ComboMilestone at Config.Combo.Milestones (x10 / 25 / 50 / 100)
--     Enhance -> ScrollSuccess / ScrollFail; Upgrade -> Equip (GoldPickup until its file); Bank / Rare -> GoldPickup;
--     LevelUp (mine) -> LevelUp; Hurt (a hit taking HurtBigFrac of my max HP, or leaving me under 30 %) -> HurtBig
--   GameState: PumpkinKingActive / GhostKingActive turning on -> PumpkinKing / GhostKing; GooseActive -> GooseArrive
--     (GooseHonk until its file)
--   my attributes: AutoCombatEnabled -> AutoOn / AutoOff; Honor up -> Purify, Infamy up -> Devour (GDD §0); my own
--     faction's points going down (A23-58, not a faction change) -> RankDown; HP / MP potion count down -> Potion.
--     Values that arrive with the save never sound. My humanoid jumping -> Jump (sound_gaps A11).
--   "Notify" remote: payload.Sound (dev2 2c5e84e, sound_spec §4-1) = the Config.Audio key of that line, "None" = no
--   sound; without it kind "bad" -> Deny, "reward" -> QuestDone; "Quests" remote: a new quest id -> QuestNew;
--   Fx "Choice" { Option = "Good" | "Evil" } (the story choice itself, to the chooser) -> Purify / Devour
--   windows: C.Panels / C.WorldMap / C.PlayerListUI IsOpen() turning on / off -> WindowOpen / WindowClose
--   world (sound_gaps B1-B10, server signals of docs/design/sound_server_2026-10-07.md): Fx KO (mine) -> KO, my next
--     character within RespawnWithin s -> Respawn; Fx GooseEnd near me -> GooseEnd; Fx Stomp -> KaijuStomp by distance
--     (Audio.StompVolume); GameState KaijuPhase -> 'Siren' -> KaijuSiren; 30 s left of WarRoundEndsAt (once per round,
--     faction set, joined 30 s ago) -> WarFinal30; CountTick 3-2-1 (1.0 / 1.12 / 1.26x) before a war round ends, before a
--     kaiju siren ends and - for players who hit it - before the goose leaves; ZonePvP false -> true (not within SpawnCalm
--     s of a spawn / teleport) -> ZoneEnterPvP; a golden monster first on screen within GoldenRange studs -> GoldenSpot
--     (once per monster), a golden kill -> GoldenKill (the same file) with its coin 0.1 s later; the "Announce" remote:
--     someone else's Jackpot / FirstMax line -> JackpotOther
--   overlaps (sound_spec §4-2 11): QuestDone within LevelSkip s of a LevelUp is dropped (a LevelUp right after it stops
--     it); QuestNew waits until QuestNewAfter s after QuestDone; a reward line right after GooseEnd / a crown waits until
--     BigFirst s after it; my first weapon's Upgrade is quiet (HUD's first-weapon moment plays PowerUp)
-- Rules (§6): every event keeps its own pool of Max copies (a new play is skipped when all are busy) and its cooldown;
-- at most MaxPlaying sounds at once; auto combat plays Auto sounds at AutoMul; the big moments (Duck.By) lower the
-- combat sounds to Duck.Mul for Duck.Seconds; the Sound effects setting (Settings "Sfx" 0..1) scales everything and 0
-- is silent. An event whose file id is "" never plays, so nothing changes before the uploads. Fx's old defaults
-- (Config.Sounds Swing / Release / Coin) are muted on this client once our files exist; Click becomes our Tap.
--
-- Public API: Audio.Init(C), Audio.Start(), Audio.Play(event, opts?) -> bool (opts { File, Speed, SpeedMul, Volume,
--   Auto, Others }), Audio.Talk(speaker?) -> bool (typewriter blips, quality ②), Audio.Plan(kind, data, ctx) -> list of
--   { Event, At, File?, SpeedMul?, Speed?, Volume, Auto?, Others? } (pure: what one Fx packet plays; the offline test
--   drives it), Audio.OnFx(kind, data), Audio.StompVolume(studs) -> 0..1, Audio.TickAt(prevLeft, left) -> CountTick speed?,
--   Audio.AnnounceSound(payload) -> event? (pure helpers of the world sounds). "No" (SkillBar) is an alias of Deny.
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
	HitMany = type(A.HitMany) == "table" and A.HitMany or { From = 3, Volume = 1.25, Speed = 0.95 },
	GhostSpeed = tonumber(A.GhostSpeed) or 1.15,
	GhostKinds = type(A.GhostKinds) == "table" and A.GhostKinds or {},
	ArrowDouble = type(A.ArrowDouble) == "table" and A.ArrowDouble or { From = 2, After = 0.068, Speed = 1.10, Volume = 0.85 },
	MagePeak = tonumber(A.MagePeak) or 0.20,
	SkillContact = tonumber(A.SkillContact) or 0.12,
	HurtBigFrac = tonumber(A.HurtBigFrac) or 0.15,
	HurtLowFrac = 0.3,
	LootKinds = type(A.LootKinds) == "table" and A.LootKinds or { Enhance = true, Transfer = true },
	LootWeaponSpeed = tonumber(A.LootWeaponSpeed) or 0.92,
	KingPrize = tonumber(A.KingPrize) or 0.25, -- s after KingDefeat: a contributor's KillPop + coin
	LootItems = type(Config.Loot) == "table" and type(Config.Loot.Items) == "table" and Config.Loot.Items or {},
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
	-- overlaps (sound_spec §4-2 11)
	FirstWeaponHold = 1.5, -- s: an Upgrade this soon after my first weapon (WeaponTier 0 -> 1+) stays quiet
	LevelSkip = 0.4, -- s: QuestDone this close to a LevelUp is dropped
	QuestNewAfter = 0.6, -- s: a new quest waits this long after QuestDone
	BigFirst = 1.5, -- s: a reward line right after one of BigEvents waits this long
	BigEvents = { GooseEnd = true, CrownHalo = true, CrownHorns = true },
	-- the world (sound_gaps B1-B10)
	RespawnWithin = 60, -- s after my KO: my next character = Respawn
	GooseEndRange = 120, -- studs: the goose's goodbye is heard this near
	Stomp = { Full = 15, Zero = 60 }, -- studs: KaijuStomp x1 within Full, fading to silence at Zero
	SpawnCalm = 3, -- s after a spawn / teleport: no ZoneEnterPvP
	Jump = 40, -- studs moved between two polls = a teleport (pads, travel)
	WarFinal = 30, -- s left in a war round = WarFinal30
	Ticks = { 1, 1.12, 1.26 }, -- CountTick speeds at 3 / 2 / 1 s left
	GoldenRange = 50, -- studs: a golden monster this near and on screen = GoldenSpot
	Poll = 0.25, -- s between the timer / golden checks
	JackpotKeys = { Jackpot = true, FirstMax = true }, -- Announce lines of others that ring (not RareWeapon)
}

-- monster kinds whose hit is the soft one (slimes, ghosts, pumpkins); everything else is heavy
local SOFT = type(A.SoftKinds) == "table" and A.SoftKinds or {}
local SWING = type(A.Swing) == "table" and A.Swing or {}
local SWING_FACTION = type(A.SwingFaction) == "table" and A.SwingFaction or {}
local MAGE_FILES = {} -- the faction mage files (their peak comes MagePeak after the start)
for _, byFaction in SWING_FACTION do
	if type(byFaction) == "table" then
		for _, f in byFaction do MAGE_FILES[f] = true end
	end
end
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
	Turn = {}, -- [event] = plays so far of an Alternate event (its files taken in turn)
	FirstWeaponAt = -math.huge, KOAt = -math.huge, SpawnAt = -math.huge, MovedAt = -math.huge, BigAt = -math.huge,
	PollAt = -math.huge, LastPos = nil, -- the timer / golden poll and my last polled position (teleport check)
	JoinedAt = math.huge, -- server time of Start (WarFinal30 needs WarFinal s in the game)
	Left = {}, -- [timer] = its seconds left at the last poll (CountTick)
	WarFinalFor = nil, -- the WarRoundEndsAt whose WarFinal30 already rang
	GooseHit = false, -- I hit the goose this visit (its 3-2-1 is for the hitters)
	GoldenSeen = setmetatable({}, { __mode = "k" }), -- golden monsters already announced
	GameState = nil,
}

local function num(v, default)
	v = tonumber(v)
	if v == nil or v ~= v or math.abs(v) == math.huge then return default end
	return v
end

-- a file's uploaded id (nil = not uploaded yet: the event stays silent or plays its stand-in)
local function idOf(file)
	local id = type(file) == "string" and FILES[file] or nil
	if type(id) ~= "string" or id == "" then return nil end
	return id
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

-- what the hits of one swing / skill sound like. ctx.KindAt(pos) names the monster a "M" hit landed on. sound_spec
-- §4-2 6: ONE material hit (HitSoft for slimes / ghosts / pumpkins, HitHeavy for everything else and players) -
-- Many = HitMany.From+ monsters (louder, a little lower), Ghost = a soft hit whose first monster is a ghost (higher) -
-- Crit = the first target is a critical hit (the HitCrit layer), Goose = a golden goose was hit; Targets = how many
-- targets (monsters, players, the goose)
local function hitEvent(hits, ctx)
	local r = { Event = nil, Crit = false, Many = false, Ghost = false, Goose = false, Targets = 0 }
	if type(hits) ~= "table" then return r end
	local monsters, heavy, firstKind = 0, false, nil
	for i, h in hits do
		if type(h) == "table" and i <= 16 then
			if i == 1 and h.C == true then r.Crit = true end
			if h.K == "G" then
				r.Goose = true
				r.Targets += 1
			elseif h.K == "P" then
				heavy = true
				r.Targets += 1
			elseif h.K == "M" then
				monsters += 1
				r.Targets += 1
				local kind = nil
				if type(ctx.KindAt) == "function" then
					local ok, k = pcall(ctx.KindAt, h.P)
					kind = ok and k or nil
				end
				if monsters == 1 then firstKind = kind end
				if not (type(kind) == "string" and SOFT[kind]) then heavy = true end
			end
		end
	end
	if heavy then
		r.Event = "HitHeavy"
	elseif monsters > 0 then
		r.Event = "HitSoft"
		r.Ghost = type(firstKind) == "string" and T.GhostKinds[firstKind] == true
	end
	r.Many = r.Event ~= nil and monsters >= num(T.HitMany.From, 3)
	return r
end

local function planHits(out, data, at, extra, ctx)
	local h = hitEvent(data.Hits, ctx)
	if h.Event then
		local p = add(out, h.Event, at, extra)
		if h.Many then p.Volume, p.SpeedMul = num(T.HitMany.Volume, 1.25), num(T.HitMany.Speed, 0.95) end
		if h.Ghost then p.SpeedMul = num(p.SpeedMul, 1) * T.GhostSpeed end
		if h.Crit then add(out, "HitCrit", at, extra) end
	end
	if h.Goose then add(out, "GooseHonk", at, extra) end
	return h
end

-- the swing file and speed factor of a packet's class / weapon style (+ the bare-hands volume); a class with faction
-- files (sound_gaps A2: Halo / Horns mages) uses the caster's file once it is uploaded
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
	local byFaction = not style and SWING_FACTION[class] or nil
	local own = type(byFaction) == "table" and type(faction) == "string" and byFaction[faction] or nil
	if own and idOf(own) then file = own end
	return file, speedMul, volume
end

-- what one Fx packet plays on this client. ctx = { Me = my UserId, Faction = my faction, Combo = this kill's number in
-- the combo (Reward), KindAt = function(pos) -> monster kind?, Near = function(pos) -> studs from me?, HP, MaxHP }
function Audio.Plan(kind, data, ctx)
	local out = {}
	if type(kind) ~= "string" or type(data) ~= "table" or type(ctx) ~= "table" then return out end
	local uid = num(data.UserId, nil)
	local own = uid ~= nil and uid == ctx.Me
	if kind == "Swing" or kind == "Release" or kind == "Skill" then
		local others = false
		if not own then
			-- other players' combat: quieter, and only near me (UI sounds stay mine)
			local at = typeof(data.Pos) == "Vector3" and data.Pos or data.From
			local d = type(ctx.Near) == "function" and at ~= nil and ctx.Near(at) or nil
			if uid == nil or d == nil or d > T.OthersRange then return out end
			others = true
		end
		local auto = (kind == "Swing" and data.Manual ~= true) or (kind ~= "Swing" and data.Auto == true)
		local extra = { Auto = auto, Others = others }
		local file, speedMul, volume = swingOf(data, own and ctx.Faction or data.Faction)
		local contact = kind == "Skill" and T.SkillContact or num(data.ContactDelay, T.ContactDefault)
		if kind == "Swing" then
			local at = 0
			if data.Style == nil and file == SWING.Archer then
				at = math.clamp(num(data.LaunchDelay, T.LaunchDefault), 0, 1) -- the arrow sounds when it leaves the bow
			elseif data.Style == nil and MAGE_FILES[file] then
				at = math.clamp(num(data.LaunchDelay, T.LaunchDefault) - T.MagePeak, 0, 1) -- the file's peak on the launch
			end
			local event = SOUNDS[file] and file or "SwingWarrior"
			add(out, event, at, { Auto = auto, Others = others, SpeedMul = speedMul, Volume = volume })
			-- sound_spec §4-2 5: a bow shot that hits 2+ targets lets a second arrow fly right after
			local double = T.ArrowDouble
			if data.Style == nil and file == SWING.Archer and hitEvent(data.Hits, ctx).Targets >= num(double.From, 2) then
				add(out, event, at + num(double.After, 0.068), { Auto = auto, Others = others,
					SpeedMul = speedMul * num(double.Speed, 1.1), Volume = volume * num(double.Volume, 0.85) })
			end
		else
			-- Release = the Q skill, Skill = Z / X (SkillService; no launch time: at once). §4-2 4: the cast at the
			-- launch, my faction's layer on every slot
			local launch = kind == "Release" and math.clamp(num(data.LaunchDelay, 0), 0, 1) or 0
			add(out, "SkillCast", launch, { Auto = auto, Others = others, File = file })
			if own then
				local layer = (ctx.Faction == "Halo" and "SkillHalo") or (ctx.Faction == "Horns" and "SkillHorns") or nil
				if layer then add(out, layer, launch, { Auto = auto }) end
			end
		end
		planHits(out, data, math.clamp(contact, 0, 1), extra, ctx)
	elseif kind == "Reward" then -- the server sends it to the killer only
		local combo = math.max(1, math.floor(num(ctx.Combo, 1)))
		local steps = T.Combo.Steps
		local step = num(steps[math.min(combo, #steps)], 0)
		local speed = math.min(num(T.Combo.Top, 1.6), num(T.Combo.Base, 0.8) * 2 ^ (step / 12))
		local golden = data.Golden == true -- sound_spec GoldenKill: the GoldenSpot file, the coin 0.1 s later
		add(out, "KillPop", 0)
		if golden then add(out, "GoldenKill", 0) end
		add(out, "ComboCoin", golden and 0.1 or 0.05, { Speed = speed })
		if MILESTONES[combo] then add(out, "ComboMilestone", 0.15) end
	elseif kind == "Choice" then -- the story choice itself (sound_spec §4-1; the server sends it to the chooser only)
		if data.Option == "Good" then
			add(out, "Purify", 0)
		elseif data.Option == "Evil" then
			add(out, "Devour", 0)
		end
	elseif kind == "Enhance" then
		add(out, data.Success == true and "ScrollSuccess" or "ScrollFail", 0)
	elseif kind == "Upgrade" then -- sound_gaps C2: a weapon bought / equipped = Equip (GoldPickup until its file)
		if ctx.FirstWeapon == true then return out end -- my first weapon: HUD's first-weapon moment plays PowerUp (C1)
		local equip = SOUNDS.Equip
		add(out, (type(equip) == "table" and idOf(equip.File)) and "Equip" or "GoldPickup", 0)
	elseif kind == "Loot" then -- sound_wiring_r4: my drop rings only for a scroll or a weapon (the weapon a little lower)
		local weapon, scroll = false, false
		for _, g in (type(data) == "table" and type(data.Items) == "table") and data.Items or {} do
			local def = type(g) == "table" and g.Item ~= nil and T.LootItems[g.Item] or nil
			if type(g) == "table" and g.Weapon ~= nil then weapon = true end
			if type(def) == "table" and T.LootKinds[def.Kind] then scroll = true end
		end
		if weapon then
			add(out, "Loot", 0, { Speed = T.LootWeaponSpeed })
		elseif scroll then
			add(out, "Loot", 0)
		end
	elseif kind == "Plunder" then -- sound_gaps B2 (dev2 sound_server: to everyone { From, To, Amount, Victim, Thief, Refund? })
		local me = ctx.Me
		if me ~= nil and type(data) == "table" then
			if data.Refund == true then
				if data.Victim == me then add(out, "GoldPickup", 0) end -- the revenge refund (the victim only)
			elseif data.Victim == me then
				add(out, "Plunder", 0)
			elseif data.Thief == me then
				add(out, "GoldPickup", 0)
			end
		end
	elseif kind == "KingDefeat" then -- sound_gaps B11 (to everyone { Key, Kind, Pos, Contributors }): the fall for all,
		-- my KillPop + coin T.KingPrize s later when I was paid
		add(out, "KingDefeat", 0)
		for _, uid in (type(data) == "table" and type(data.Contributors) == "table") and data.Contributors or {} do
			if uid == ctx.Me then
				add(out, "KillPop", T.KingPrize)
				add(out, "ComboCoin", T.KingPrize + 0.05)
				break
			end
		end
	elseif kind == "KO" then -- sound_gaps B1 (BB14: the server sends it to the one knocked out only)
		add(out, "KO", 0)
	elseif kind == "GooseEnd" then -- B3 { Pos, Winner, Coop } to everyone: heard near the goose only
		local d = type(ctx.Near) == "function" and typeof(data.Pos) == "Vector3" and ctx.Near(data.Pos) or nil
		if d ~= nil and d <= T.GooseEndRange then add(out, "GooseEnd", 0) end
	elseif kind == "Stomp" then -- B4 { UserId, Pos, Radius } to everyone: loud near the kaiju, silent far away
		local d = type(ctx.Near) == "function" and typeof(data.Pos) == "Vector3" and ctx.Near(data.Pos) or nil
		local v = d ~= nil and Audio.StompVolume(d) or 0
		if v > 0 then add(out, "KaijuStomp", 0, { Volume = v }) end
	elseif kind == "Bank" or kind == "Rare" then
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

-- KaijuStomp's volume factor d studs from the stomp (B4): 1 within Stomp.Full, 0 from Stomp.Zero, a straight line between
function Audio.StompVolume(d)
	d = num(d, math.huge)
	local full, zero = num(T.Stomp.Full, 15), num(T.Stomp.Zero, 60)
	if d <= full then return 1 end
	if d >= zero then return 0 end
	return (zero - d) / (zero - full)
end

-- a timer going from prevLeft to left seconds: crossing 3 / 2 / 1 s left -> that CountTick's speed (B7), else nil
function Audio.TickAt(prevLeft, left)
	if type(prevLeft) ~= "number" or type(left) ~= "number" then return nil end
	for i, at in { 3, 2, 1 } do
		if prevLeft > at and left <= at and left > at - 1 then return T.Ticks[i] end
	end
	return nil
end

-- the sound of one "Announce" line ({ Key, Args, Grade, Self?, Event? }): someone else's Jackpot / FirstMax -> JackpotOther
-- (B10; my own line and the server-wide event lines stay quiet here)
function Audio.AnnounceSound(payload)
	if type(payload) ~= "table" or payload.Self == true or payload.Event == true then return nil end
	return T.JackpotKeys[payload.Key] == true and "JackpotOther" or nil
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

-- the file an event plays this time (Files = variants: one at random, or in turn with Alternate - the turn moves on
-- only when the play really starts, Audio.Play); nil = no id yet
local function fileOf(def, override, event)
	if type(override) == "string" then return idOf(override) and override or nil end
	if type(def.Files) == "table" and #def.Files > 0 then
		local ready = {}
		for _, f in def.Files do
			if idOf(f) then table.insert(ready, f) end
		end
		if #ready == 0 then return nil end
		if def.Alternate == true then return ready[(S.Turn[event] or 0) % #ready + 1] end
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
	local file = fileOf(def, opts.File, event)
	if not file then return false end
	local mult = sfxMult()
	if mult <= 0 then return false end
	local now = os.clock()
	-- §4-2 11: QuestDone this close to a LevelUp is dropped; QuestNew waits until QuestNewAfter s after QuestDone
	if event == "QuestDone" and now - (S.Last.LevelUp or -math.huge) < T.LevelSkip then return false end
	if event == "QuestNew" and opts.Waited ~= true then
		local wait = T.QuestNewAfter - (now - (S.Last.QuestDone or -math.huge))
		if wait > 0 then
			task.delay(wait, Audio.Play, "QuestNew", { Waited = true })
			return false
		end
	end
	local last = S.Last[event]
	if last and now - last < num(def.Gap, 0.03) then return false end
	if playingCount() >= T.MaxPlaying then return false end
	local s = freeSound(event, def)
	if not s then return false end
	S.Last[event] = now
	if def.Alternate == true then S.Turn[event] = (S.Turn[event] or 0) + 1 end
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
	-- §4-2 11: a LevelUp right after a QuestDone stops it; a big moment holds the reward lines right after it (afterBig)
	if event == "LevelUp" and now - (S.Last.QuestDone or -math.huge) < T.LevelSkip then
		for _, q in S.Pools.QuestDone or {} do
			if q.IsPlaying then q:Stop() end
		end
	end
	if T.BigEvents[event] then S.BigAt = now end
	-- the big moments lower the combat sounds for a moment (§6)
	if T.Duck.By and T.Duck.By[event] and S.Groups.Combat then
		S.DuckToken += 1
		local token = S.DuckToken
		S.Groups.Combat.Volume = num(T.Duck.Mul, 0.5)
		local hold = type(T.Duck.SecondsBy) == "table" and num(T.Duck.SecondsBy[event], nil) or nil
		task.delay(hold or num(T.Duck.Seconds, 1.2), function()
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

-- a spawn / teleport in the last SpawnCalm s (a jump of more than Jump studs since the last poll counts as one now)
local function movedJustNow()
	local root = myRoot()
	local now = os.clock()
	if root and S.LastPos and (root.Position - S.LastPos).Magnitude > T.Jump then S.MovedAt = now end
	return now - math.max(S.SpawnAt, S.MovedAt) < T.SpawnCalm
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
	local me = LocalPlayer and LocalPlayer.UserId
	local own = type(data) == "table" and data.UserId ~= nil and data.UserId == me
	if kind == "KO" then S.KOAt = os.clock() end -- my next character = Respawn
	if kind == "TravelDone" and own then S.MovedAt = os.clock() end -- the server moved me: no ZoneEnterPvP right now
	if own and type(data.Hits) == "table" then
		for _, h in data.Hits do
			if type(h) == "table" and h.K == "G" then S.GooseHit = true end -- the goose's 3-2-1 is for its hitters
		end
	end
	local hum = LocalPlayer and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	local plan = Audio.Plan(kind, data, {
		-- my first weapon (WeaponTier 0 -> 1+ just now, or still 0 when its Upgrade arrives): HUD plays PowerUp
		FirstWeapon = os.clock() - S.FirstWeaponAt < T.FirstWeaponHold
			or num(LocalPlayer and LocalPlayer:GetAttribute("WeaponTier"), 0) == 0,
		Me = me,
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
	watch(LocalPlayer, "WeaponTier", function(prev, v)
		if loaded() and num(prev, -1) == 0 and num(v, 0) >= 1 then S.FirstWeaponAt = os.clock() end
	end)
	watch(LocalPlayer, "ZonePvP", function(prev, v)
		-- B9: into a place where the other side may fight me (not right after a spawn / teleport; nothing on the way out)
		if v ~= true or prev ~= false or not loaded() then return end
		if not movedJustNow() then Audio.Play("ZoneEnterPvP") end
	end)
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
		-- sound_gaps A7: the goose arrives (its honk is for hitting it; it stands in until GooseArrive is uploaded)
		if v == true and prev ~= true and fresh() and not Audio.Play("GooseArrive") then Audio.Play("GooseHonk") end
		if v ~= true then S.GooseHit = false end
	end)
	watch(gs, "KaijuPhase", function(prev, v)
		-- B5: the kaiju alarm (its 3-2-1 comes from pollWorld)
		if v == "Siren" and prev ~= "Siren" and fresh() then Audio.Play("KaijuSiren") end
	end)
	S.GameState = gs
end

-- sound_gaps A11 (user): my own jumps (the moment the humanoid leaves the ground by a jump)
local function watchJump(char)
	local ok, hum = pcall(function() return char:WaitForChild("Humanoid", 5) end)
	if not (ok and hum and hum:IsA("Humanoid")) then return end
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then Audio.Play("Jump") end
	end)
end

-- one timer's CountTick (3-2-1 before endsAt) while `on`; the seconds left are kept for the next poll
local function tickFor(key, on, endsAt, nowServer)
	local left = endsAt - nowServer
	local prev = S.Left[key]
	S.Left[key] = (on and endsAt > 0) and left or nil
	if not on or endsAt <= 0 then return end
	local speed = Audio.TickAt(prev, left)
	if speed then Audio.Play("CountTick", { Speed = speed }) end
end

-- every Poll s: my teleports (ZoneEnterPvP calm), the war round's last 30 s (B7), the 3-2-1 before a war round ends,
-- before a kaiju siren ends and - for its hitters - before the goose leaves, and golden monsters coming into view (B8)
local function pollWorld()
	local now = os.clock()
	if now - S.PollAt < T.Poll then return end
	S.PollAt = now
	local root = myRoot()
	if root then
		if S.LastPos and (root.Position - S.LastPos).Magnitude > T.Jump then S.MovedAt = now end
		S.LastPos = root.Position
	end
	local gs = S.GameState
	if gs and LocalPlayer then
		local t = Util.Now()
		local warEnds = num(gs:GetAttribute("WarRoundEndsAt"), 0)
		local left = warEnds - t
		local faction = LocalPlayer:GetAttribute("Faction")
		if warEnds > 0 and S.WarFinalFor ~= warEnds and left <= T.WarFinal and left > T.WarFinal - 3
			and (faction == "Halo" or faction == "Horns") and t - S.JoinedAt > T.WarFinal then
			S.WarFinalFor = warEnds
			Audio.Play("WarFinal30")
		end
		tickFor("War", warEnds > 0, warEnds, t)
		tickFor("Kaiju", gs:GetAttribute("KaijuPhase") == "Siren", num(gs:GetAttribute("KaijuEndsAt"), 0), t)
		tickFor("Goose", gs:GetAttribute("GooseActive") == true and S.GooseHit, num(gs:GetAttribute("GooseEndsAt"), 0), t)
	end
	local folder = root and workspace:FindFirstChild("Monsters")
	local cam = workspace.CurrentCamera
	if not folder or not cam then return end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("Golden") == true and not S.GoldenSeen[m] then
			local ok, pivot = pcall(m.GetPivot, m)
			if ok and (pivot.Position - root.Position).Magnitude <= T.GoldenRange then
				local _, onScreen = cam:WorldToViewportPoint(pivot.Position)
				if onScreen then
					S.GoldenSeen[m] = true -- once per monster (seen while the event's Gap holds it = still seen)
					Audio.Play("GoldenSpot")
				end
			end
		end
	end
end

-- §4-2 11: a reward line right after GooseEnd / a crown waits until BigFirst s after that sound (the big one first)
local function afterBig(event)
	local wait = T.BigFirst - (os.clock() - S.BigAt)
	if wait > 0 and not T.BigEvents[event] and event ~= "Deny" then
		task.delay(wait, Audio.Play, event)
	else
		Audio.Play(event)
	end
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
	S.JoinedAt = Util.Now()
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

	if LocalPlayer then
		watchMe()
		pcall(function()
			LocalPlayer.CharacterAdded:Connect(function(char)
				S.SpawnAt = os.clock()
				if os.clock() - S.KOAt < T.RespawnWithin then -- B1: back after my KO
					S.KOAt = -math.huge
					Audio.Play("Respawn")
				end
				task.spawn(watchJump, char)
			end)
			if LocalPlayer.Character then task.spawn(watchJump, LocalPlayer.Character) end
		end)
	end
	task.spawn(watchGame)
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(pollWindows)
		if not ok then warnThrottled("windows", "window watch failed: " .. tostring(err)) end
		ok, err = pcall(pollWorld)
		if not ok then warnThrottled("world", "world watch failed: " .. tostring(err)) end
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
			if event then afterBig(event) end
		end)
	end)
	task.spawn(function()
		local announce = Net.Get("Announce")
		if not announce then return end
		announce.OnClientEvent:Connect(function(payload)
			local event = Audio.AnnounceSound(payload)
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
