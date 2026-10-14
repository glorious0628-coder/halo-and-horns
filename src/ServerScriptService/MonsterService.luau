-- MonsterService.luau : monster rigs (procedural or custom visual), spawn/respawn with zone density and spawn spread,
-- AI loop, monster HP, kill rewards (MonsterKilled) and personal (tutorial) monsters.
-- World is Terrain (A10/A11): spawn/wander points are raycast onto walkable ground; monsters stay inside their own zone
-- rect, never chase into water and are recovered home when knocked out / sunk (A10-V3-2); stuck detection (A11-R5).
-- A15 hit feel: attacks are telegraphed (WindupAt -> AttackSeq), damage bumps HurtSeq, player hits shove (Shove).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local MonsterService = {}

-- fired once PER CONTRIBUTOR: (player, info). info.WarPoints = personal war points, info.WarShare = this player's
-- part of the faction pool points (WarPoints / same-faction contributors, CR-M18)
MonsterService.MonsterKilled = Util.Signal.new()
-- ③ monster barks (BarkService, Config.Barks): (rec, "Spot") when a monster picks a new target (a personal monster: the
-- first time it goes for its owner), (rec, "Hit") when a hit leaves it alive. Synchronous; handlers must not yield.
MonsterService.Moment = Util.Signal.new()

------------------------------------------------------------------ constants
local TAG = "MonsterService"
local MC = Config.Monsters

-- A3-M2 / A5-C1 density (fallbacks keep the service working if a Config key is missing). The per-kind targets
-- (ExtraPerPlayer / MaxZoneMult, seasonal counts) come from Config.MonsterTargets.
local DENSITY = Config.MonsterDensity or {}
local REEVAL_INTERVAL = DENSITY.ReevalInterval or 5
local MAX_SPAWNS_PER_KIND_PER_PASS = 8 -- smooths bursts when many players enter a zone at once

-- A7-1 spawn spread
local SPREAD = Config.SpawnSpread or {}
local SPREAD_ENABLED = SPREAD.Enabled ~= false
local SPREAD_THRESHOLD = SPREAD.StarvedThreshold or 2
local SPREAD_MIN = SPREAD.MinDist or 18
local SPREAD_MAX = SPREAD.MaxDist or 28
local SPREAD_TRIES = SPREAD.Tries or 6
local SPREAD_COUNT_RADIUS = 30

-- shared Config keys (G1) with fallbacks
local TUTORIAL = Config.Tutorial or {}
-- 3rd idea round #7: Cfg = Config.SpawnSpread.Tutorial; Hunters = [zoneId] = first-mission hunters (playersPerZone)
local TUT_SPAWN = { Cfg = (Config.SpawnSpread or {}).Tutorial or {}, Hunters = {} }
local CUSTOM = Config.CustomModels or {}
local CUSTOM_FOLDER = CUSTOM.FolderName or "CustomModels"
local GOLDEN_FILL_TRANSPARENCY = CUSTOM.GoldenFillTransparency or 1
local MIN_TEXT_SIZE = (Config.UI and Config.UI.MinTextSize) or 11
local NO_REAGGRO_SECONDS = MC.ReaggroDelay or 3 -- A3-M4
local PERSONAL_DISTANCE = TUTORIAL.SpawnDistance or 8 -- A4: ~8 studs in front of the player
local PERSONAL_LIFETIME = TUTORIAL.Lifetime or 120 -- A4: despawn after 120 s

-- AI tuning that is not in Config (private)
local RETURN_DONE_DIST = 6
local WANDER_RADIUS = 15
local WANDER_MIN, WANDER_MAX = 4, 8
local WANDER_TRIES = 4
local PERSONAL_FOLLOW_RADIUS = 80 -- A5-C3: a personal monster only tracks its owner when the owner is this close
local ZONE_MOVE_INSET = 6 -- A10-V3-2 (b): every MoveTo destination stays this far inside the monster's zone rect
local OUT_Y = -3 -- A10-V3-2 (c): root below this (water) -> walk home, no re-aggro
local DEEP_Y = -8 -- A10-V3-2 (c): root below this for more than DEEP_SECONDS -> PivotTo(Home)
local DEEP_SECONDS = 2
local MAX_SLOPE_ANGLE = 46 -- A11-R2: Terrain ridges (>= 50 deg) cannot be walked over
local STUCK_WINDOW = 1.5 -- A11-R5: moved < STUCK_MIN_MOVE in this many seconds while moving -> new destination
local STUCK_MIN_MOVE = 1
local ARRIVE_DIST = 3 -- "still trying to move" while the destination is farther than this
local DETOUR_MIN, DETOUR_MAX = 8, 14
local DETOUR_SECONDS = 2
local DETOUR_TRIES = 4
local CHASE_STUCK_GIVEUP = 2 -- stuck this many times on one target -> give up and go home

-- ground probing (A11-R1: Include only Config.GroundRoots: Terrain, Map.Ground, the bridges, "WalkGround" tags)
local GROUND_RAY_TOP = 150 -- above every ridge top
local GROUND_RAY_LENGTH = 320
local GROUND_MIN_Y, GROUND_MAX_Y = -2, 26 -- walkable ground (zone ground top Y = 0; 검수 2026-10-09: the meadow v4 hunting grass rises in 3 layers to 17.4, so up to 26); lower = shore
local GROUND_PARAMS_REFRESH = 10
local SPAWN_TRIES = 8

-- visuals
local BAR_MAX_DISTANCE = 80
-- monster motion review 2026-10-06 (survey 4-1): a killed monster's body stays DEATH_DESTROY - DEATH_SHRINK - 0.1 s
-- (0.75: the rigged fall / slime splat shows), then shrinks over DEATH_SHRINK; destroyed at DEATH_DESTROY.
-- A23-74 (user 2026-10-07 "왜 반투명한 애들이 생기냐고"): a monster body is never see-through (ART_DIRECTION: part
-- Transparency is 0 or 1): no fade, it stays opaque until the model is destroyed
local DEATH_SHRINK = 0.3
local DEATH_DESTROY = 1.15
local DEATH_PARTICLES = 15
-- an event monster that leaves undefeated (RemoveEvent(rec, true, true), the Pumpkin King going home): model attribute
-- "Leaving" (clients skip the dying-slime splat), floats up Rise studs while it shrinks away over Time s, no burst
local LEAVE = { Time = 1.2, Rise = 3 }
-- A23-74 (user 2026-10-07 "점점 합쳐지겠다"): only living records and dying bodies (Dying[model] = os.clock() after
-- which it must be gone) may stand in workspace.Monsters; Sweep removes any other copy (a body whose destroy never ran,
-- a monster model saved into the place) so no ghost stays where the living ones walk into it
local GHOST = { Dying = {}, Grace = 1 }
-- every visible part is welded to VisualRoot, which hangs off the root by the Weld VisualJoint (C0 = C1 = identity).
-- Clients tween VisualJoint.C0 locally (Fx.luau attack lunge / hit recoil); the server never writes C0 after spawn.
local VISUAL_ROOT_NAME = "VisualRoot"
local VISUAL_JOINT_NAME = "VisualJoint"
local VISUAL_ROOT_SIZE = 0.2
local ATTACK_SEQ_ATTR = "AttackSeq" -- +1 when a monster attack lands on a player (clients play the attack lunge)
-- user 2026-10-06 "몬스터들이 유저를 바라보면서 때리면 좋겠어": a monster in reach turns its body toward its target every
-- frame at TurnRate (smooth, never a snap) and keeps following a target that walks around it, from the wind-up to the
-- hit; the hit lands only once the target is within HitCos (+-30 deg) of the look direction, waiting up to MaxExtra s
-- longer (rechecked every Recheck s), else the swing misses. MaxExtra stays below the clients' wind-up pose grace
-- (Fx MOTION.TELE_GRACE 0.35, review 2026-10-06) so a late hit never lands after the pose has relaxed. Keep = s a
-- facing lasts after the last attack() call (the AI runs every MC.AIInterval). Active[rec] = { Target = Player,
-- Until = os.clock() deadline }.
local FACE = { TurnRate = math.rad(600), HitCos = math.cos(math.rad(30)), MaxExtra = 0.3, Recheck = 0.05, Keep = 0.6,
	Active = {} }
-- monster naturalness (user 2026-10-06 "몬스터들이 너무 경직된 느낌", survey 4-1): a wander walks at WanderPace of the
-- chase speed; every walk eases in from standing (RampStart + RampStep per AI tick up to full) and a wander slows to
-- half within ArriveSlow studs of its goal; a monster that spots a new target out of reach stops AlertHold s facing it
-- with a '!' (model attribute AlertAt, server time) before it chases (not again for that player within AlertAgain s);
-- a standing idle monster every LookEvery s either glances at a player within GlanceRange (one it may not chase) or
-- looks 40-110 deg to a side, turning at LookRate for LookTime s (FACE point looks).
local NATURAL = { WanderPace = 0.5, RampStart = 0.45, RampStep = 0.3, ArriveSlow = 4, AlertHold = 0.3, AlertAgain = 15,
	LookEvery = { 3, 7 }, LookRate = math.rad(90), LookTime = 0.9, GlanceRange = 20 }
-- A23-74 (user 2026-10-07 "점점 합쳐지겠다"): monsters keep a natural distance. No monster part collides (TECH_SPEC:
-- CanCollide = false, players walk through them), so the AI spaces them: a chaser walks to its own slot on a ring around
-- its target (body radius + PlayerRadius + RingGap, at most AttackRange - RingInside; one player's chasers get angles
-- spread so neighbours stand rA + rB apart; a full ring moves out to AttackRange - RingInside so more can attack, the
-- rest wait on further rings outside reach; the ring is centred Lead s ahead of a walking player), in reach it stands
-- for its swing and steps on to its slot between swings, and after every AI tick the end points of the coming tick's
-- walks are pushed apart where two bodies would overlap (closer than (rA + rB) x Overlap) or a body would be inside a
-- player: each push becomes a slide over the next tick (a deeper push slides faster, at most Speed studs/s; the
-- smaller one moves more, a boss never). A new monster (a boss too) spawns at least rA + rB + SpawnGap from every
-- living one.
-- Body radius = Radius[Def.Shape] x Def.Scale (a slime ball 1.5 x s: the Tripo meshes measure 3.0 / 3.5 / 5.4 studs).
-- Neighbours come from a Cell-stud grid rebuilt every AI tick (never every pair of the world). Review 2026-10-07: with
-- these, a player walking at 3 / 5 / 8 studs/s keeps 4 Shard + 2 King Slimes apart (tools/test_monster_spacing.py).
-- Review 2026-10-08: (1) at the zone edge a slide keeps the part along the zone's move line (only the part crossing it
-- is dropped and the other monster of a pair takes it), and a player's rings count only their part inside the line
-- (SEP.RingArc: fewer fit, the rest wait on the next ring) instead of slots past it all being clamped onto the line;
-- (2) a zone monster keeps its target TargetHold s and then switches only to a player TargetMargin studs closer
-- (SEP.Pick), so a monster between two players standing together no longer swaps target and slot every tick; after
-- the hold it never keeps a target out of AttackRange while another player is in reach (it stood there and swung at
-- nobody). Cutting a player's rings by the other players' bodies was tried and dropped: in groups of 3-4 it left most
-- chasers out of reach.
-- A23-87 the new kinds' extras (ranged shots, the flower ambush, partner spots): filled in its own section below
local MOB3 = {}
local SEP = {
	Radius = { Slime = 1.5, Humanoid = 1.25 },
	PlayerRadius = 1,
	RingGap = 1,
	RingInside = 0.5,
	Overlap = 1, -- review 2026-10-07: bodies touch at rA + rB (0.9 left a 10% overlap standing)
	Speed = 8, -- review 2026-10-07: was 3 (a pile behind a walking player outgrew the slides)
	Passes = 3, -- push rounds per AI tick (a push into a third monster is fixed the next round)
	MinPush = 0.05,
	Settle = 0.5, -- in reach: closer than this to its slot it stands
	Lead = 0.25, -- s: the chase ring and the player body are taken where a walking player will be (one AI tick on)
	LeadMax = 4, -- studs
	SpawnGap = 1.5,
	Cell = 8, -- >= the largest pair distance (two big regular kinds, or a boss + the biggest regular kind: A23-92 King
	-- Slime 4.8 + Slime Prince 2.7; a zone holds one boss at a time)
	TargetHold = 2, -- s: review 2026-10-08: a zone monster keeps a new target at least this long ...
	TargetMargin = 3, -- studs: ... and then switches only to a player this much closer (side by side never swap)
	Grid = {}, -- [cell key] = { rec, ... } this AI tick
	Live = {}, -- every movable living rec this AI tick
	Slots = {}, -- [rec] = { Player, Angle, Ring } this AI tick
	Push = {}, -- [rec] = { Delta, Done, Time } slides in progress (SEP.Step every Heartbeat)
}
-- A15 hit feel (server half): attack telegraph, pain reactions, swing shove. Tunables live in Config.HitReact (shared
-- with the client Fx); the fallbacks keep the service working without it. Model attribute contract for clients:
-- "WindupAt" changed -> wind-up pose (the hit follows REACT.WINDUP s later unless cancelled), "AttackSeq" +1 -> lunge
-- (the damage lands now), "HurtSeq" +1 -> pain reaction ("HurtBig" is written first: true = crit / big hit).
local HIT_REACT = Config.HitReact or {}
local REACT = {
	WINDUP = HIT_REACT.MonsterWindup or 0.28, -- s from "WindupAt" to the hit
	WINDUP_LEEWAY = HIT_REACT.WindupLeeway or 2, -- the hit still lands while the target is within AttackRange + this
	HURT_GAP = HIT_REACT.MonsterHurtGap or 0.15, -- at most one "HurtSeq" bump per monster per this many seconds
	BIG_FRACTION = HIT_REACT.BigHitFraction or 0.5, -- a hit of >= this fraction of MaxHP is "big"
	SHOVE_MAX = HIT_REACT.ShoveMax or 2, -- studs, upper bound of any shove (divided by the monster's body scale)
	SHOVE_TIME = HIT_REACT.ShoveTime or 0.12, -- s the shove slide takes
	SHOVE_GAP = HIT_REACT.ShoveGap or 0.5, -- min seconds between two shoves of one monster (no push-locking)
}
local WINDUP_AT_ATTR = "WindupAt" -- workspace:GetServerTimeNow() when the monster starts winding up an attack
local HURT_SEQ_ATTR = "HurtSeq" -- +1 when the monster takes damage and survives (throttled by REACT.HURT_GAP)
local HURT_BIG_ATTR = "HurtBig" -- written right before HurtSeq: true = crit or >= BIG_FRACTION of its MaxHP
local BAR_HIGH = Color3.fromRGB(80, 220, 120)
local BAR_LOW = Color3.fromRGB(255, 80, 80)
local EYE_COLOR = Color3.fromRGB(20, 20, 20)

local DISABLED_STATES = { -- A3-H2
	Enum.HumanoidStateType.Dead,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.Seated,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.PlatformStanding,
}

------------------------------------------------------------------ state
local S = nil
local records = {} -- [Id] = MonsterRecord (alive only)
local nextId = 0
local pending = {} -- [Kind] = respawns scheduled but not yet executed
local personal = {} -- [Player] = { [MonsterRecord] = true }
local monstersFolder = nil
local lastWarn = {} -- [key] = os.clock()
local groundParams, groundParamsAt = nil, -math.huge

local GLOBAL_CAP
do
	if type(DENSITY.GlobalCap) == "number" then
		GLOBAL_CAP = DENSITY.GlobalCap
	else
		local sum = 0
		for kind, n in Config.EffectiveMonsterCounts() do
			if not Config.MonsterOutsideCap(kind) then sum += n end -- add-on seasonal kinds sit outside the cap
		end
		GLOBAL_CAP = math.floor(sum * 1.7 + 0.5)
	end
end

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	local last = lastWarn[key]
	if last and now - last < 10 then return end
	lastWarn[key] = now
	Util.Warn(TAG, tostring(msg))
end

local function getMonstersFolder()
	if monstersFolder and monstersFolder.Parent then return monstersFolder end
	monstersFolder = Util.GetFolder(workspace, "Monsters")
	return monstersFolder
end

local function readyPlayers()
	if not S or not S.PlayerService then return {} end
	local ok, list = pcall(S.PlayerService.GetReadyPlayers)
	if ok and type(list) == "table" then return list end
	return {}
end

-- 3rd idea round #7: a player on the first mission's hunt (TutorialStep = Steps.Quest) standing in the guide zone
local function tutorialHunter(p, zoneId)
	return zoneId == TUTORIAL.GuideZone and p:GetAttribute("TutorialStep") == (TUTORIAL.Steps or {}).Quest
end

local function isPlayerInTown(player, pos)
	if Config.ZoneAt(pos).Town == true then return true end
	if S and S.ZoneService then
		local ok, town = pcall(S.ZoneService.IsTown, player)
		if ok and town == true then return true end
	end
	return false
end

-- CR-M18: faction id the war pool uses (same lookup as WarService: FactionService first, then the attribute)
local function factionOf(player)
	if S and S.FactionService and S.FactionService.GetFaction then
		local ok, f = pcall(S.FactionService.GetFaction, player)
		if ok and type(f) == "string" then return f end
	end
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

-- CR-M5: zone id of the player's root (nil without a character); attackers must stand in the monster's zone
local function zoneIdOf(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return nil end
	local r = Util.GetRoot(player)
	return r and Config.ZoneAt(r.Position).Id or nil
end

-- CR-M5: personal monsters only for their owner (any zone); zone monsters only for a player standing in their zone
-- (A10-V3-2a both ways: a monster that never chases out of its zone cannot be farmed from just outside it)
local function visibleTo(rec, forPlayer, forZone)
	if forPlayer == nil then return true end
	if rec.Owner ~= nil then return rec.Owner == forPlayer end
	return forZone ~= nil and rec.ZoneId == forZone
end

local function insideZone(zone, p, inset)
	return math.abs(p.X - zone.Center.X) <= zone.Size.X / 2 - inset
		and math.abs(p.Z - zone.Center.Z) <= zone.Size.Z / 2 - inset
end

-- A10-V3-2 (b): clamp a destination into the zone rect inset by ZONE_MOVE_INSET (keeps Y)
local function clampToZone(zone, p)
	if not zone then return p end
	local hx = math.max(0, zone.Size.X / 2 - ZONE_MOVE_INSET)
	local hz = math.max(0, zone.Size.Z / 2 - ZONE_MOVE_INSET)
	return Vector3.new(
		math.clamp(p.X, zone.Center.X - hx, zone.Center.X + hx),
		p.Y,
		math.clamp(p.Z, zone.Center.Z - hz, zone.Center.Z + hz)
	)
end

-- A11-R1: ground raycasts only see the walking ground (rebuilt every few seconds so a late MapBuilder pass is picked
-- up): Config.GroundRoots = Terrain, workspace.Map.Ground, the bridges and (halo_restart 2026-10-11) every instance
-- tagged Config.Ground.Tag "WalkGround" - the one rule the clients' Ground.luau uses too. Water is NOT ignored, so a
-- hit on the sea/river reports Material Water.
local function getGroundParams()
	local now = os.clock()
	if groundParams and now - groundParamsAt < GROUND_PARAMS_REFRESH then return groundParams end
	local list = Config.GroundRoots(workspace.Terrain, workspace:FindFirstChild("Map"),
		Util.Tagged((Config.Ground or {}).Tag or "WalkGround"))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	params.IgnoreWater = false
	groundParams, groundParamsAt = params, now
	return params
end

-- ground under (x, z): returns (groundY, isWater), or nil when nothing was hit
local function probeGround(x, z)
	local hit = workspace:Raycast(Vector3.new(x, GROUND_RAY_TOP, z), Vector3.new(0, -GROUND_RAY_LENGTH, 0), getGroundParams())
	if not hit then return nil, false end
	return hit.Position.Y, hit.Material == Enum.Material.Water
end

-- CR-L14: solid decoration a monster must not stand in (King Slime hill, goblin tents, broken pillars / arches):
-- Map.Decor children except the "Bridge_*" decks, plus Map.Landmarks. Non-collidable props (canopies, flowers, glows)
-- never count. Rebuilt every GROUND_PARAMS_REFRESH s like the ground params.
local blockCast = { Params = nil, At = -math.huge, Any = false }
local function getBlockParams()
	local now = os.clock()
	if blockCast.Params and now - blockCast.At < GROUND_PARAMS_REFRESH then return blockCast.Params end
	local list = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		local decor = map:FindFirstChild("Decor")
		if decor then
			for _, c in decor:GetChildren() do
				if string.sub(c.Name, 1, 7) ~= "Bridge_" then table.insert(list, c) end
			end
		end
		local landmarks = map:FindFirstChild("Landmarks")
		if landmarks then table.insert(list, landmarks) end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	params.IgnoreWater = true
	pcall(function()
		params.RespectCanCollide = true
	end)
	blockCast.Params, blockCast.At, blockCast.Any = params, now, #list > 0
	return params
end

-- CR-L14: true when a solid decor / landmark part stands on the ground point (ray from y + 40 down to y + 0.5)
local function occupied(x, y, z)
	local params = getBlockParams()
	if not blockCast.Any then return false end
	local ok, hit = pcall(function()
		return workspace:Raycast(Vector3.new(x, y + 40, z), Vector3.new(0, -39.5, 0), params)
	end)
	return ok and hit ~= nil
end

-- A23-129 (user 2026-10-11 "몹이 나무들을 뚫고 나오네"): a new monster's whole body must not overlap a map prop. The
-- CR-L14 centre ray above only sees collidable, queryable parts of Map.Decor / Landmarks, but the world kits' trees,
-- bushes and rocks are CanQuery = false meshes (a visible mesh without collision + an invisible collidable post) that no
-- raycast or GetPartBoundsInBox ever returns. So the server keeps its own index of prop boxes: every BasePart under
-- workspace.Map except Map.Ground, WalkGround-tagged floor parts, the Map children named in SKIP, invisible
-- non-collidable helpers (zone boxes, anchors, mist) and non-collidable ground cover / effects by name
-- (Config.SpawnClear.Pass: flowers, step stones, waterfall sheets, wisps). Bridges and tagged models are walked: their
-- rails, posts and lamps block, their deck never does (it is the ground there, under the FOOT gap). A world-kit tree (a
-- Model with one TrunkPost and a mesh named in Config.SpawnClear.Trees) blocks a disc round its trunk up to the canopy
-- bottom plus its mesh box above that (검수 2026-10-11: the full box closed half of the woods). The body is a column of
-- flat radius SEP.RadiusOf(def) from FOOT above the ground up to its height (buildRig: Slime 3 x Scale, Humanoid
-- 5 x Scale, + Float), so flat things whose top stays under FOOT (roads, decks, water planes) never count. A spawn try
-- whose body overlaps a prop is skipped like water (groundPoint def). The index is a CELL-stud grid built at the first
-- spawn (a failed first build leaves an empty one), then rebuilt in the background when the Map changed (its
-- DescendantAdded / Removing), checked every REFRESH s; a rebuild yields every BUDGET s, the old index serves meanwhile.
local CLEAR = {
	FOOT = 0.5,
	CELL = 16,
	REFRESH = 60,
	BUDGET = 0.002, -- s of work between two task.wait() of a background rebuild
	HEIGHT = { Slime = 3, Humanoid = 5 },
	SKIP = { Ground = true, Zones = true, Pads = true }, -- Map children that are never props
	Grid = nil, -- [cell key] = { entry, ... }; nil = not built yet (or no Map)
	At = -math.huge,
	Busy = false,
	Map = nil, -- the Map the index was built from
	Dirty = false, -- that Map changed (or the last rebuild failed): rebuilt at the next check
	Watched = false, -- its DescendantAdded / Removing are connected (unwatched = rebuilt at every check)
	Conns = {},
}

-- flat radius and height (studs) of a monster kind's body
function CLEAR.Body(def)
	local s = tonumber(def.Scale) or 1
	return SEP.RadiusOf(def), (CLEAR.HEIGHT[def.Shape] or CLEAR.HEIGHT.Humanoid) * s + math.max(0, tonumber(def.Float) or 0)
end

function CLEAR.Key(cx, cz)
	return cx * 65536 + cz
end

-- an index entry of one prop part, or nil for an invisible non-collidable helper. Vert = the local axis (1-3) that
-- stands upright (0 = a tilted part); EX / EZ / Lo / Hi = its world bounding box
function CLEAR.Entry(part)
	if part.Transparency >= 0.95 and not part.CanCollide then return nil end
	local cf, size = part.CFrame, part.Size
	local axes = { cf.XVector, cf.YVector, cf.ZVector }
	local half = { size.X / 2, size.Y / 2, size.Z / 2 }
	local ex, ey, ez, vert = 0, 0, 0, 0
	for i, a in axes do
		ex += math.abs(a.X) * half[i]
		ey += math.abs(a.Y) * half[i]
		ez += math.abs(a.Z) * half[i]
		if math.abs(a.Y) > 0.999 then vert = i end
	end
	local p = cf.Position
	return { Part = part, Axes = axes, Half = half, Vert = vert, X = p.X, Y = p.Y, Z = p.Z, EX = ex, EZ = ez,
		Lo = p.Y - ey, Hi = p.Y + ey }
end

-- true for a non-collidable ground-cover / effect part named in Config.SpawnClear.Pass and in no NotPass word (knee-high
-- flowers, step stones, waterfall sheets and foam, wisps): it never blocks a spawn
function CLEAR.Passes(part)
	local SC = Config.SpawnClear
	if type(SC) ~= "table" or SC.PassRule == false or part.CanCollide then return false end
	local name = part.Name
	for _, k in SC.NotPass or {} do
		if string.find(name, k, 1, true) then return false end
	end
	for _, k in SC.Pass or {} do
		if string.find(name, k, 1, true) then return true end
	end
	return false
end

-- the world-kit tree among one instance's children: exactly one BasePart named TrunkPost and exactly one MeshPart named
-- in Config.SpawnClear.Trees -> { Mesh, Post, Base, Canopy }; else nil (any mesh keeps its full box)
function CLEAR.TreeOf(kids)
	local SC = Config.SpawnClear
	if type(SC) ~= "table" or SC.TreeRule == false or type(SC.Trees) ~= "table" then return nil end
	local post, mesh, shape = nil, nil, nil
	for _, c in kids do
		if c:IsA("BasePart") then
			if c.Name == "TrunkPost" then
				if post then return nil end
				post = c
			elseif c:IsA("MeshPart") and type(SC.Trees[c.Name]) == "table" then
				if mesh then return nil end
				mesh, shape = c, SC.Trees[c.Name]
			end
		end
	end
	if not post or not mesh then return nil end
	return { Mesh = mesh, Post = post, Base = tonumber(shape.Base) or 0, Canopy = tonumber(shape.Canopy) or 0 }
end

-- the entries of a tree (TreeOf): a disc of Base x the mesh's wider plan size round the TrunkPost, from the mesh bottom
-- up to Canopy x its height, and the mesh box above that height; a tilted mesh (or a zero share) keeps its full box
function CLEAR.TreeEntries(t)
	local e = CLEAR.Entry(t.Mesh)
	if not e then return {} end
	if e.Vert == 0 or t.Base <= 0 or t.Canopy <= 0 then return { e } end
	local plan = 0
	for i, h in e.Half do
		if i ~= e.Vert then plan = math.max(plan, h * 2) end
	end
	local cut = e.Lo + t.Canopy * e.Half[e.Vert] * 2
	local p, r = t.Post.CFrame.Position, t.Base * plan
	local out = { { Part = t.Mesh, Disc = true, R = r, X = p.X, Y = (e.Lo + cut) / 2, Z = p.Z, EX = r, EZ = r, Lo = e.Lo,
		Hi = cut } }
	if cut < e.Hi then
		e.Lo = cut
		table.insert(out, e)
	end
	return out
end

-- true when the body column (flat radius r around (x, z), from lo up to hi) overlaps the entry's box
function CLEAR.Overlap(e, x, z, r, lo, hi)
	if e.Hi <= lo or e.Lo >= hi then return false end
	local dx, dz = x - e.X, z - e.Z
	if e.Disc then return dx * dx + dz * dz < (e.R + r) * (e.R + r) end -- a tree's trunk base (TreeEntries)
	if math.abs(dx) >= e.EX + r or math.abs(dz) >= e.EZ + r then return false end
	if e.Vert ~= 0 then
		-- an upright box (trees, bushes, rocks, walls): the circle against its flat rectangle
		local d2 = 0
		for i, a in e.Axes do
			if i ~= e.Vert then
				local out = math.abs(dx * a.X + dz * a.Z) - e.Half[i]
				if out > 0 then d2 += out * out end
			end
		end
		return d2 < r * r
	end
	-- a tilted box (a fallen log, a sideways post): the part's own axes on top of the world ones above, the body taken
	-- as its bounding box, so a near miss counts as blocked
	local dy, hb = (lo + hi) / 2 - e.Y, (hi - lo) / 2
	for i, a in e.Axes do
		local reach = e.Half[i] + r * math.abs(a.X) + hb * math.abs(a.Y) + r * math.abs(a.Z)
		if math.abs(dx * a.X + dy * a.Y + dz * a.Z) >= reach then return false end
	end
	return true
end

-- a new index of the props under workspace.Map and that Map (nil without a Map); yielding = a background rebuild
-- (task.wait() after every BUDGET s of work)
function CLEAR.Build(yielding)
	local map = workspace:FindFirstChild("Map")
	if not map then return nil end
	local skip = {}
	local ground = map:FindFirstChild("Ground")
	if ground then skip[ground] = true end
	-- 검수 2026-10-11 (spawnclear review): only the walking floors are skipped (a tagged part); tagged models and the
	-- bridges are walked, so their rails, posts and lamps block while a deck under the body never does (the FOOT gap)
	for _, t in Util.Tagged((Config.Ground or {}).Tag or "WalkGround") do
		if t:IsA("BasePart") then skip[t] = true end
	end
	for _, c in map:GetChildren() do
		if CLEAR.SKIP[c.Name] then skip[c] = true end
	end
	local grid, cell, t0 = {}, CLEAR.CELL, os.clock()
	local function add(e)
		for cx = math.floor((e.X - e.EX) / cell), math.floor((e.X + e.EX) / cell) do
			for cz = math.floor((e.Z - e.EZ) / cell), math.floor((e.Z + e.EZ) / cell) do
				local k = CLEAR.Key(cx, cz)
				local list = grid[k]
				if list then table.insert(list, e) else grid[k] = { e } end
			end
		end
	end
	local function walk(inst)
		local kids = inst:GetChildren()
		local tree = CLEAR.TreeOf(kids)
		for _, c in kids do
			if not skip[c] then
				if c:IsA("BasePart") then
					if tree and c == tree.Mesh then
						for _, e in CLEAR.TreeEntries(tree) do add(e) end
					elseif not CLEAR.Passes(c) then
						local e = CLEAR.Entry(c)
						if e then add(e) end
					end
					if yielding and os.clock() - t0 >= CLEAR.BUDGET then
						task.wait()
						t0 = os.clock()
					end
				end
				walk(c)
			end
		end
	end
	walk(map)
	return grid, map
end

-- watches `map` (once per Map object): anything added to it or removed from it marks the index dirty
function CLEAR.Watch(map)
	if CLEAR.Map == map and CLEAR.Watched then return end
	for _, c in CLEAR.Conns do pcall(function() c:Disconnect() end) end
	CLEAR.Conns, CLEAR.Map = {}, map
	local function mark() CLEAR.Dirty = true end
	CLEAR.Watched = pcall(function()
		table.insert(CLEAR.Conns, map.DescendantAdded:Connect(mark))
		table.insert(CLEAR.Conns, map.DescendantRemoving:Connect(mark))
	end)
end

-- the current index: built at once the first time (and while there is no Map yet); a failed first build leaves an empty
-- index, so later spawns take the background path instead of a full build on every try. Afterwards, checked every
-- REFRESH s, a background rebuild while the Map changed (or is unwatched / gone); the new index replaces the old one
-- only when the build worked and its Map is still in the workspace.
function CLEAR.Index()
	local now = os.clock()
	if CLEAR.Grid == nil then
		CLEAR.At = now
		local ok, grid, map = pcall(CLEAR.Build)
		if not ok then
			warnThrottled("spawnclear", "spawn clearance index: " .. tostring(grid))
			CLEAR.Grid, CLEAR.Dirty = {}, true
		elseif grid then
			CLEAR.Grid, CLEAR.Dirty = grid, false
			CLEAR.Watch(map)
		end
	elseif not CLEAR.Busy and now - CLEAR.At >= CLEAR.REFRESH
		and (CLEAR.Dirty or not CLEAR.Watched or CLEAR.Map == nil or CLEAR.Map.Parent ~= workspace) then
		CLEAR.At, CLEAR.Busy, CLEAR.Dirty = now, true, false
		task.spawn(function()
			local ok, grid, map = pcall(CLEAR.Build, true)
			if ok and grid and map.Parent == workspace then
				CLEAR.Grid = grid
				CLEAR.Watch(map)
			else
				CLEAR.Dirty = true -- the old index stays; tried again at the next check
				if not ok then warnThrottled("spawnclear", "spawn clearance index: " .. tostring(grid)) end
			end
			CLEAR.Busy = false
		end)
	end
	return CLEAR.Grid
end

-- the first prop part a body (flat radius r, height h) standing on ground point g overlaps, or nil
function CLEAR.Hit(g, r, h)
	local grid = CLEAR.Index()
	if not grid then return nil end
	local lo, hi, cell = g.Y + CLEAR.FOOT, g.Y + math.max(h, CLEAR.FOOT + 0.1), CLEAR.CELL
	local seen = {}
	for cx = math.floor((g.X - r) / cell), math.floor((g.X + r) / cell) do
		for cz = math.floor((g.Z - r) / cell), math.floor((g.Z + r) / cell) do
			for _, e in grid[CLEAR.Key(cx, cz)] or {} do
				if not seen[e] then
					seen[e] = true
					if CLEAR.Overlap(e, g.X, g.Z, r, lo, hi) then return e.Part end
				end
			end
		end
	end
	return nil
end

-- true when def's whole body fits on ground point g (no map prop inside it)
function CLEAR.Fits(g, def)
	local r, h = CLEAR.Body(def)
	return CLEAR.Hit(g, r, h) == nil
end

-- walkable ground point at (x, z) or nil (water, ridge, shore, inside solid decor). Second result: true when the ray
-- hit nothing at all (bare test place without Terrain / Map.Ground), so callers can fall back to the legacy flat Y = 0
-- behaviour.
-- maxY (optional): a higher top for this call (검수 2026-10-09: an event / boss spot on a hill, opts.MaxY of SpawnEvent)
-- def (optional, A23-129): the kind about to spawn there; nil too when a map prop stands inside its body (CLEAR). The
-- walks (wander, detours, slides) pass none: only new monsters are kept out of props.
local function groundPoint(x, z, maxY, def)
	local y, water = probeGround(x, z)
	if y == nil then return nil, true end
	if water or y < GROUND_MIN_Y or y > math.max(GROUND_MAX_Y, tonumber(maxY) or GROUND_MAX_Y) then return nil, false end
	if occupied(x, y, z) then return nil, false end -- CR-L14
	local g = Vector3.new(x, y, z)
	if def ~= nil and not CLEAR.Fits(g, def) then return nil, false end -- A23-129
	return g, false
end

-- unanchored monster part
local function newPart(props)
	local p = Instance.new(props.ClassName or "Part")
	if props.Shape then p.Shape = props.Shape end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "Parent" and k ~= "Shape" then
			p[k] = v
		end
	end
	return p
end

local function getCustomTemplate(id)
	local folder = ServerStorage:FindFirstChild(CUSTOM_FOLDER)
	if not folder then return nil end
	local t = folder:FindFirstChild(id)
	if t and (t:IsA("Model") or t:IsA("BasePart")) then return t end
	-- A23-45: a new kind without its own imported model yet borrows its family's (def.ModelFrom, scaled by def.Scale)
	local def = Config.MonsterTypes[id]
	local from = type(def) == "table" and def.ModelFrom or nil
	t = type(from) == "string" and from ~= id and folder:FindFirstChild(from) or nil
	if t and (t:IsA("Model") or t:IsA("BasePart")) then return t end
	return nil
end

------------------------------------------------------------------ counting (non-personal)
local function aliveCountOf(kind)
	local n = 0
	for _, rec in records do
		if rec.Alive and rec.Owner == nil and rec.Kind == kind then n += 1 end
	end
	return n
end

-- alive + pending regular monsters counted toward GLOBAL_CAP: event monsters (miniboss) and add-on seasonal kinds
-- (Config.MonsterOutsideCap, the little ghosts) are extra, so the season never thins the other zones
local function totalNonPersonal()
	local n = 0
	for _, rec in records do
		if rec.Alive and rec.Owner == nil and not rec.Event and not Config.MonsterOutsideCap(rec.Kind) then n += 1 end
	end
	for kind, c in pending do
		if not Config.MonsterOutsideCap(kind) then n += c end
	end
	return n
end

local function playersPerZone()
	local counts, hunters = {}, {}
	for _, p in readyPlayers() do
		local root = Util.GetRoot(p)
		if root then
			local id = Config.ZoneAt(root.Position).Id
			counts[id] = (counts[id] or 0) + 1
			if tutorialHunter(p, id) then hunters[id] = (hunters[id] or 0) + 1 end
		end
	end
	TUT_SPAWN.Hunters = hunters
	return counts
end

-- Config.MonsterTargets + the first-mission bonus: each hunter adds Tutorial Extra to the guide zone's tutorial monster
-- (never above Count x MaxZoneMult)
local function wantedTargets(zoneCounts)
	local wanted = Config.MonsterTargets(zoneCounts)
	local kind, zone = TUTORIAL.Monster, TUTORIAL.GuideZone
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	local n, extra = TUT_SPAWN.Hunters[zone] or 0, math.floor(tonumber(TUT_SPAWN.Cfg.Extra) or 0)
	if n > 0 and extra > 0 and def and def.Zone == zone and wanted[kind] then
		local cap = math.floor((tonumber(def.Count) or 0) * (tonumber((Config.MonsterDensity or {}).MaxZoneMult) or 2))
		wanted[kind] = math.max(wanted[kind], math.min(wanted[kind] + extra * n, cap))
	end
	return wanted
end

-- per kind: min(count + ExtraPerPlayer * (playersInZone - 1), count * MaxZoneMult) with the seasonal counts
-- (Config.MonsterTargets / Config.EffectiveMonsterCounts: an inactive seasonal kind = 0, a kind that took slots of a
-- base kind shares its growth, so a zone's total stays the same with the season on; cappedTargets keeps that true
-- under the GlobalCap)
local function targetCount(kind, zoneCounts)
	if not Config.MonsterTypes[kind] then return 0 end
	return wantedTargets(zoneCounts or playersPerZone())[kind] or 0
end

-- largest-remainder split of `total` over `keys` (in order) by `weight` (> 0 only); ties go to the earlier key
local function shareOut(keys, weight, total)
	local out, sum, fracs, used = {}, 0, {}, 0
	for _, k in keys do
		out[k] = 0
		sum += math.max(0, weight[k] or 0)
	end
	if sum <= 0 or total <= 0 then return out end
	for _, k in keys do
		local w = weight[k] or 0
		if w > 0 then
			local share = w * total / sum
			out[k] = math.floor(share)
			used += out[k]
			table.insert(fracs, { K = k, F = share - out[k], I = #fracs + 1 })
		end
	end
	table.sort(fracs, function(a, b)
		if a.F ~= b.F then return a.F > b.F end
		return a.I < b.I
	end)
	for _, fr in fracs do
		if used >= total then break end
		out[fr.K] += 1
		used += 1
	end
	return out
end

-- CR-L13: { [kind] = target } where the extras above each base Count share the GLOBAL_CAP room (GLOBAL_CAP - base
-- sum) in proportion to what each kind asks for (largest remainder), instead of MonsterTypeOrder filling the cap
-- first (busy meadow -> the ruins stayed at their base density). Seasonal kinds: one that took slots of a base kind
-- shares that kind's part of the room (Config.MonsterCapGroup), so every zone gets exactly its season-off capped
-- total; an add-on kind (Config.MonsterOutsideCap) keeps its own target outside the cap and takes no room.
local function cappedTargets(zoneCounts)
	zoneCounts = zoneCounts or playersPerZone()
	local targets, extras = {}, {}
	local groups, groupOf, groupExtra = {}, {}, {} -- cap groups in MonsterTypeOrder (first member's position)
	local baseSum, extraSum = 0, 0
	local wanted, counts = wantedTargets(zoneCounts), Config.EffectiveMonsterCounts()
	for _, kind in Config.MonsterTypeOrder do
		local def = Config.MonsterTypes[kind]
		if def and targets[kind] == nil then
			local t = wanted[kind] or 0
			if Config.MonsterOutsideCap(kind) then
				targets[kind] = t
			else
				local base = math.min(counts[kind] or 0, t)
				local g = Config.MonsterCapGroup(kind)
				targets[kind] = base
				extras[kind] = math.max(0, t - base)
				baseSum += base
				extraSum += extras[kind]
				if groupExtra[g] == nil then
					groupExtra[g] = 0
					table.insert(groups, g)
				end
				groupOf[kind] = g
				groupExtra[g] += extras[kind]
			end
		end
	end
	if extraSum <= 0 then return targets end
	local room = math.max(0, GLOBAL_CAP - baseSum)
	if room >= extraSum then
		for kind, e in extras do
			targets[kind] += e
		end
		return targets
	end
	-- the groups share the room, then each group's part goes to its kinds the same way
	local groupRoom = shareOut(groups, groupExtra, room)
	for _, g in groups do
		local members = {}
		for _, kind in Config.MonsterTypeOrder do
			if groupOf[kind] == g and not table.find(members, kind) then table.insert(members, kind) end
		end
		for kind, n in shareOut(members, extras, math.min(groupRoom[g] or 0, groupExtra[g])) do
			targets[kind] += n
		end
	end
	return targets
end

------------------------------------------------------------------ public queries
-- A23-92 (검수 2026-10-09): a big boss is hit at its body's edge, not only near its centre: the studs its body is wider
-- than a normal monster of its shape (0 for every other monster). GetMonstersInRadius / GetNearest and CombatService's
-- target search add it to the reach.
function MonsterService.HitPad(rec)
	local def = type(rec) == "table" and rec.Def or nil
	if type(def) ~= "table" or def.Boss ~= true then return 0 end
	return math.max(0, (tonumber(rec._radius) or SEP.RadiusOf(def)) - SEP.RadiusOf({ Shape = def.Shape, Scale = 1 }))
end

-- forPlayer (optional): only the monsters that player may hit (own personal ones + zone monsters of the zone the
-- player stands in, CR-M5). nil = every alive monster.
function MonsterService.GetMonstersInRadius(position, radius, forPlayer)
	local out = {}
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" then return out end
	local fz = zoneIdOf(forPlayer) -- CR-M5
	for _, rec in records do
		if rec.Alive and visibleTo(rec, forPlayer, fz) then
			local root = rec.Root
			if root and root.Parent and Util.FlatDistance(root.Position, position) <= radius + MonsterService.HitPad(rec) then
				table.insert(out, rec)
			end
		end
	end
	return out
end

function MonsterService.GetNearest(position, radius, maxCount, forPlayer)
	local out = {}
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" then return out end
	local found = {}
	local fz = zoneIdOf(forPlayer) -- CR-M5
	for _, rec in records do
		if rec.Alive and visibleTo(rec, forPlayer, fz) then
			local root = rec.Root
			if root and root.Parent then
				local d = Util.FlatDistance(root.Position, position)
				if d <= radius + MonsterService.HitPad(rec) then
					table.insert(found, { Rec = rec, D = d })
				end
			end
		end
	end
	table.sort(found, function(a, b) return a.D < b.D end)
	local limit = (type(maxCount) == "number" and maxCount >= 0) and math.floor(maxCount) or #found
	for i = 1, math.min(limit, #found) do
		out[i] = found[i].Rec
	end
	return out
end

function MonsterService.CountInRadius(position, radius, forPlayer)
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" then return 0 end
	local n = 0
	local fz = zoneIdOf(forPlayer) -- CR-M5
	for _, rec in records do
		if rec.Alive and visibleTo(rec, forPlayer, fz) then
			local root = rec.Root
			if root and root.Parent and Util.FlatDistance(root.Position, position) <= radius then
				n += 1
			end
		end
	end
	return n
end

-- SEP (A23-74): flat body radius of a monster kind in studs
function SEP.RadiusOf(def)
	if type(def) ~= "table" then return SEP.Radius.Slime end
	return (SEP.Radius[def.Shape] or SEP.Radius.Humanoid) * (tonumber(def.Scale) or 1)
end

-- SEP (A23-74): true when no living monster stands within radius + its own radius + SpawnGap of pt (flat). A full
-- scan: it only runs for spawn tries, never every tick.
function SEP.Clear(pt, radius)
	for _, rec in records do
		local root = rec.Alive and rec.Root or nil
		if root and root.Parent
			and Util.FlatDistance(root.Position, pt) < radius + (rec._radius or SEP.Radius.Slime) + SEP.SpawnGap then
			return false
		end
	end
	return true
end

------------------------------------------------------------------ spawn point (A7-1, grounded on Terrain per A10/A11)
-- Returns a point ON the ground (Y = ground height) inside def.Zone, or nil when every try landed on water / a ridge
-- (the density pass retries a few seconds later). A23-74: a try next to a living monster (SEP.Clear) is skipped; when
-- every try was crowded the first crowded ground point is used (the AI slides them apart), so density never starves.
-- A23-129: a try with a map prop inside the body (groundPoint def) is skipped like water, never even as the crowded
-- fallback; every try blocked = nil (no spawn this pass, the next pass tries again).
local function pickSpawnPoint(def, kind)
	local zone = Config.Zones[def.Zone]
	if not zone then return nil end
	local inset = MC.SpawnInset
	local anyHit = false
	local radius, crowded = SEP.RadiusOf(def), nil
	local function try(pt)
		local g, noHit = groundPoint(pt.X, pt.Z, nil, def)
		if not noHit then anyHit = true end
		if g and Config.ZoneAt(g).Id == def.Zone then
			if SEP.Clear(g, radius) then return g end
			crowded = crowded or g
		end
		return nil
	end
	-- A23-45 pack kinds (def.Pack = { Max, Radius }, the ghost minions in 3-4s): next to a living one of the kind whose
	-- pack (members within Radius x 1.5) is not full yet, else a free spot below = a new pack
	local pack = type(def.Pack) == "table" and kind ~= nil and def.Pack or nil
	if pack then
		local maxN, rad = math.max(2, tonumber(pack.Max) or 4), math.max(3, tonumber(pack.Radius) or 7)
		local members = {}
		for _, rec in records do
			if rec.Alive and rec.Owner == nil and rec.Kind == kind and rec.Root and rec.Root.Parent then
				table.insert(members, rec.Root.Position)
			end
		end
		for i = #members, 2, -1 do
			local j = Util.Random:NextInteger(1, i)
			members[i], members[j] = members[j], members[i]
		end
		for _, c in members do
			local n = 0
			for _, o in members do
				if Util.FlatDistance(c, o) <= rad * 1.5 then n += 1 end
			end
			if n < maxN then
				for _ = 1, 6 do
					local a = Util.Random:NextNumber(0, math.pi * 2)
					local d = Util.Random:NextNumber(3, rad)
					local pt = Vector3.new(c.X + math.cos(a) * d, 0, c.Z + math.sin(a) * d)
					if insideZone(zone, pt, inset) then
						local g = try(pt)
						if g then return g end
					end
				end
			end
		end
	end
	if SPREAD_ENABLED then
		-- a starved player (fewer monsters near than the threshold): a first-mission hunter first (3rd idea round #7,
		-- the tutorial monster in the guide zone, closer ring), then a Rookie, then the lowest level, then the fewest near
		local best = nil
		local tutKind = kind ~= nil and kind == TUTORIAL.Monster and def.Zone == TUTORIAL.GuideZone
		for _, p in readyPlayers() do
			if Util.IsAlive(p) then
				local root = Util.GetRoot(p)
				if root then
					local pos = root.Position
					local z = Config.ZoneAt(pos)
					if z.Id == def.Zone and not z.Town then
						local c = MonsterService.CountInRadius(pos, SPREAD_COUNT_RADIUS, p)
						local tut = tutKind and tutorialHunter(p, z.Id)
						if c < (tut and (TUT_SPAWN.Cfg.StarvedThreshold or 3) or SPREAD_THRESHOLD) then
							local cand = { Pos = pos, Count = c, Tut = tut == true, Rookie = p:GetAttribute("Rookie") == true,
								Level = tonumber(p:GetAttribute("Level")) or 1 }
							if best == nil or (cand.Tut ~= best.Tut and cand.Tut)
								or (cand.Tut == best.Tut and (cand.Rookie ~= best.Rookie and cand.Rookie
									or (cand.Rookie == best.Rookie and (cand.Level < best.Level
										or (cand.Level == best.Level and cand.Count < best.Count))))) then
								best = cand
							end
						end
					end
				end
			end
		end
		if best then
			local bestPos = best.Pos
			local minD = best.Tut and (TUT_SPAWN.Cfg.MinDist or 10) or SPREAD_MIN
			local maxD = best.Tut and (TUT_SPAWN.Cfg.MaxDist or 18) or SPREAD_MAX
			-- the first-mission ring is the half circle facing the zone middle (where the kid looks after the trip; the
			-- meadow entrance sits on the spawn-inset edge, so a full circle wastes half its tries) with twice the tries
			local face = best.Tut and math.atan2(zone.Center.Z - bestPos.Z, zone.Center.X - bestPos.X) or nil
			for _ = 1, face and SPREAD_TRIES * 2 or SPREAD_TRIES do
				local a = face and face + Util.Random:NextNumber(-math.pi / 2, math.pi / 2) or Util.Random:NextNumber(0, math.pi * 2)
				local d = Util.Random:NextNumber(minD, maxD)
				local pt = Vector3.new(bestPos.X + math.cos(a) * d, 0, bestPos.Z + math.sin(a) * d)
				if insideZone(zone, pt, inset) then
					local g = try(pt)
					if g then return g end
				end
			end
		end
	end
	for _ = 1, SPAWN_TRIES do
		local g = try(Util.RandomPointInZone(zone, inset))
		if g then return g end
	end
	if crowded then return crowded end -- A23-74: only crowded ground found this pass
	if not anyHit then
		-- no Terrain / Map.Ground under the zone at all (bare test place): legacy flat ground at Y = 0
		return Util.RandomPointInZone(zone, inset)
	end
	warnThrottled("spawnpoint_" .. def.Zone, "no walkable ground found in " .. def.Zone .. " this pass (water/ridge/props); retrying later")
	return nil
end

------------------------------------------------------------------ rig construction
local function makeBar(root, text, golden, offsetY)
	local bb = Instance.new("BillboardGui")
	bb.Name = "MonsterBar"
	bb.Size = UDim2.fromOffset(150, 34)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = BAR_MAX_DISTANCE
	bb.LightInfluence = 0
	bb.AlwaysOnTop = false

	local name = Instance.new("TextLabel")
	name.Name = "NameLabel"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Font = Enum.Font.GothamBold
	name.Text = text
	name.TextColor3 = golden and MC.GoldenColor or Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.TextScaled = true
	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MaxTextSize = 16
	tsc.MinTextSize = MIN_TEXT_SIZE
	tsc.Parent = name
	name.Parent = bb

	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.Position = UDim2.new(0.1, 0, 0, 23)
	back.Size = UDim2.new(0.8, 0, 0, 8)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	local c1 = Instance.new("UICorner")
	c1.CornerRadius = UDim.new(0, 4)
	c1.Parent = back
	back.Parent = bb

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BAR_HIGH
	fill.BorderSizePixel = 0
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(0, 4)
	c2.Parent = fill
	fill.Parent = back

	bb.Parent = root
	return fill
end

local function updateBar(rec)
	local fill = rec._fill
	if not fill or not fill.Parent then return end
	local r = (rec.MaxHP > 0) and math.clamp(rec.HP / rec.MaxHP, 0, 1) or 0
	fill.Size = UDim2.fromScale(r, 1)
	fill.BackgroundColor3 = BAR_LOW:Lerp(BAR_HIGH, r)
end

-- A1: clone a custom visual, scale it to the procedural body height, sit it on the floor facing the root.
-- Returns (visualModel, parts) or nil when the template is unusable.
local function buildCustomVisual(template, rootCF, bodyHeight, floorY)
	local clone = template:Clone()
	local visual
	if clone:IsA("BasePart") then
		visual = Instance.new("Model")
		clone.Parent = visual
		visual.PrimaryPart = clone
	else
		visual = clone
	end
	visual.Name = "CustomVisual"

	for _, d in visual:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Humanoid") then
			d:Destroy()
		end
	end

	local parts = {}
	for _, d in visual:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		visual:Destroy()
		return nil
	end

	-- face the root's look direction (the template's pivot orientation is treated as its "front")
	visual:PivotTo(CFrame.new(visual:GetPivot().Position) * rootCF.Rotation)

	-- scale so the bounding-box height matches the procedural body height
	local _, size = visual:GetBoundingBox()
	if size.Y > 0.01 then
		local factor = bodyHeight / size.Y
		local okScale, cur = pcall(visual.GetScale, visual)
		if not okScale or type(cur) ~= "number" or cur <= 0 then cur = 1 end
		pcall(visual.ScaleTo, visual, cur * factor)
	end

	-- bottom on the floor, centered under the root
	local bbCF, bbSize = visual:GetBoundingBox()
	local rootPos = rootCF.Position
	local delta = Vector3.new(
		rootPos.X - bbCF.Position.X,
		(floorY + bbSize.Y / 2) - bbCF.Position.Y,
		rootPos.Z - bbCF.Position.Z
	)
	visual:PivotTo(visual:GetPivot() + delta)
	return visual, parts
end

-- builds the model (not parented yet). Returns a table with Model, Root, VisualRoot, Humanoid, Fill, Parts, VisualParts,
-- BodyHeight, Hip.
local function buildRig(kind, def, golden, groundPos, faceTo)
	local s = def.Scale or 1
	local isSlime = def.Shape == "Slime"
	local rootSize, hip, bodyHeight, topAboveRoot
	if isSlime then
		rootSize = Vector3.new(2 * s, 2 * s, 2 * s)
		hip = 0.5 * s
		bodyHeight = 3 * s -- ball diameter; root center sits 1.5s above the floor
		topAboveRoot = 1.5 * s -- ball top
	else
		rootSize = Vector3.new(2 * s, 2 * s, 1 * s)
		hip = 2 * s
		bodyHeight = 5 * s -- legs bottom at the floor, head top 5s above it
		topAboveRoot = 2 * s -- head top
	end

	local floorY = groundPos.Y
	local rootY = floorY + hip + rootSize.Y / 2
	local rootPos = Vector3.new(groundPos.X, rootY, groundPos.Z)
	local rootCF
	if typeof(faceTo) == "Vector3" and Util.FlatDistance(faceTo, rootPos) > 0.1 then
		rootCF = CFrame.lookAt(rootPos, Vector3.new(faceTo.X, rootY, faceTo.Z))
	else
		rootCF = CFrame.new(rootPos) * CFrame.Angles(0, Util.Random:NextNumber(0, math.pi * 2), 0)
	end

	local model = Instance.new("Model")
	model.Name = kind

	local root = newPart({
		Name = "HumanoidRootPart",
		Size = rootSize,
		CFrame = rootCF,
		Transparency = 1,
		Massless = false,
	})
	root.Parent = model
	model.PrimaryPart = root

	-- invisible anchor for every visible part (see VISUAL_ROOT_NAME); starts exactly on the root
	local visualRoot = newPart({
		Name = VISUAL_ROOT_NAME,
		Size = Vector3.new(VISUAL_ROOT_SIZE, VISUAL_ROOT_SIZE, VISUAL_ROOT_SIZE),
		CFrame = rootCF,
		Transparency = 1,
		CanQuery = false,
		CastShadow = false,
	})
	visualRoot.Parent = model
	local joint = Instance.new("Weld")
	joint.Name = VISUAL_JOINT_NAME
	joint.Part0 = root
	joint.Part1 = visualRoot
	joint.C0 = CFrame.identity
	joint.C1 = CFrame.identity
	joint.Parent = visualRoot

	local bodyColor = golden and MC.GoldenColor or def.Color
	local darkColor = golden and MC.GoldenColor or def.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	local parts = {}
	local function add(props, offset)
		props.CFrame = rootCF * offset
		local p = newPart(props)
		p.Parent = model
		table.insert(parts, p)
		return p
	end

	if isSlime then
		add({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(3 * s, 3 * s, 3 * s), Color = bodyColor, Transparency = 0 },
			CFrame.new())
		for side = -1, 1, 2 do
			add({ Name = side < 0 and "EyeL" or "EyeR", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45 * s, 0.45 * s, 0.45 * s), Color = EYE_COLOR },
				CFrame.new(side * 0.5 * s, 0.35 * s, -1.33 * s))
		end
	else
		add({ Name = "Torso", Size = Vector3.new(2 * s, 2 * s, 1 * s), Color = darkColor }, CFrame.new())
		add({ Name = "Head", Size = Vector3.new(2 * s, 1 * s, 1 * s), Color = bodyColor }, CFrame.new(0, 1.5 * s, 0))
		add({ Name = "Left Arm", Size = Vector3.new(1 * s, 2 * s, 1 * s), Color = bodyColor }, CFrame.new(-1.5 * s, 0, 0))
		add({ Name = "Right Arm", Size = Vector3.new(1 * s, 2 * s, 1 * s), Color = bodyColor }, CFrame.new(1.5 * s, 0, 0))
		add({ Name = "Left Leg", Size = Vector3.new(1 * s, 2 * s, 1 * s), Color = darkColor }, CFrame.new(-0.5 * s, -2 * s, 0))
		add({ Name = "Right Leg", Size = Vector3.new(1 * s, 2 * s, 1 * s), Color = darkColor }, CFrame.new(0.5 * s, -2 * s, 0))
		for side = -1, 1, 2 do
			add({ Name = side < 0 and "EyeL" or "EyeR", Size = Vector3.new(0.3 * s, 0.3 * s, 0.05 * s), Color = EYE_COLOR },
				CFrame.new(side * 0.45 * s, 1.6 * s, -0.52 * s))
		end
	end

	-- A1 custom visual (procedural parts stay as an invisible hitbox)
	local visualParts = nil
	local template = getCustomTemplate(kind)
	if template then
		local ok, visual, vparts = pcall(buildCustomVisual, template, rootCF, bodyHeight, floorY)
		if ok and visual then
			for _, p in parts do p.Transparency = 1 end
			visual.Parent = model
			visualParts = vparts
			if golden then
				-- A23-74 (user 2026-10-07): a gold rim only (Config.CustomModels.GoldenFillTransparency 1); a fill is a flat
				-- half-see-through gold layer over the textured body (green + gold read as an olive ghost)
				local h = Instance.new("Highlight")
				h.Name = "GoldenTint"
				h.FillColor = MC.GoldenColor
				h.FillTransparency = GOLDEN_FILL_TRANSPARENCY
				h.OutlineColor = MC.GoldenColor
				h.OutlineTransparency = 0
				h.DepthMode = Enum.HighlightDepthMode.Occluded
				h.Parent = visual
			end
		elseif not ok then
			warnThrottled("custom_" .. kind, "custom model for " .. kind .. " failed: " .. tostring(visual))
		end
	end

	if golden then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "GoldenSparkle"
		pe.Color = ColorSequence.new(MC.GoldenColor)
		pe.Rate = 8
		pe.Lifetime = NumberRange.new(0.6, 1.1)
		pe.Speed = NumberRange.new(1, 3)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 0.8
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 * s), NumberSequenceKeypoint.new(1, 0) })
		pe.Parent = root
		local light = Instance.new("PointLight")
		light.Name = "GoldenLight"
		light.Color = MC.GoldenColor
		light.Range = 10 * s
		light.Brightness = 1.5
		light.Parent = root
	end

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = hip
	hum.WalkSpeed = def.Speed
	hum.AutoJumpEnabled = false
	hum.MaxSlopeAngle = MAX_SLOPE_ANGLE -- A11-R2
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.MaxHealth = 100
	hum.Health = 100
	hum.Parent = model

	local label = golden and ("Golden " .. def.Name) or def.Name
	-- def.Float: the client hovers the visual this many studs up (Fx WOBBLE), so the name bar goes up with it
	local fill = makeBar(root, label, golden, topAboveRoot + 1.6 + math.max(0, tonumber(def.Float) or 0))

	model:SetAttribute("MonsterKind", kind)
	model:SetAttribute("Golden", golden)
	-- body size for the client attack motion (lunge distance, lean pivot at the floor)
	model:SetAttribute("BodyHeight", bodyHeight)
	model:SetAttribute("RootHeight", rootY - floorY)

	return {
		Model = model,
		Root = root,
		VisualRoot = visualRoot,
		Humanoid = hum,
		Fill = fill,
		Parts = parts,
		VisualParts = visualParts,
		BodyHeight = bodyHeight,
		Hip = hip,
		Scale = s,
		RootOffset = rootY - floorY, -- root center height above the floor (used by PivotTo(Home))
	}
end

------------------------------------------------------------------ spawn / despawn
local function spawnMonster(kind, opts)
	local def = Config.MonsterTypes[kind]
	if not def then return nil end
	opts = opts or {}
	local owner = opts.Owner

	local golden
	if owner ~= nil or opts.Golden ~= nil then
		golden = opts.Golden == true
	elseif def.Boss == true then
		golden = false -- a miniboss is never a golden variant
	else
		golden = Util.Random:NextNumber() < MC.GoldenChance
	end

	-- point is ON the ground (its Y = ground height); never assume a flat Part floor (A10/A11 Terrain world)
	local point = opts.Position
	if typeof(point) ~= "Vector3" then
		-- A23-87: a flower patch (Ambush) / a partner's side (PartnerOf) first, else a normal spawn point
		point = ((def.Ambush or def.PartnerOf) and MOB3.Spot(def, kind)) or pickSpawnPoint(def, kind)
		if not point then return nil end
	end
	local rig = buildRig(kind, def, golden, point, opts.FaceTo)

	local maxHP
	if type(opts.HP) == "number" and opts.HP > 0 and opts.HP == opts.HP then
		maxHP = opts.HP
	else
		maxHP = def.HP * (golden and MC.GoldenHPMult or 1)
	end

	if owner then
		rig.Model:SetAttribute("OwnerUserId", owner.UserId)
	end
	-- system_review_round1 #6: the nametag's danger colour (game dev 1); the fights never read it
	rig.Model:SetAttribute("Level", Config.MonsterLevel(kind))

	-- parent, weld (visible parts to VisualRoot, which is jointed to the root), network owner, humanoid states.
	-- Gameplay (hits, AI, knockback) only uses the root; parts follow it through the joints.
	rig.Model.Parent = getMonstersFolder()
	local anchor = rig.VisualRoot or rig.Root
	for _, p in rig.Parts do
		Util.Weld(anchor, p)
	end
	if rig.VisualParts then
		for _, p in rig.VisualParts do
			Util.Weld(anchor, p)
		end
	end
	pcall(rig.Root.SetNetworkOwner, rig.Root, nil)
	for _, st in DISABLED_STATES do
		pcall(rig.Humanoid.SetStateEnabled, rig.Humanoid, st, false)
	end

	-- no server "alive" bob (the A1 HipHeight tween lifted every custom monster 0.18-0.45 studs off the floor twice a
	-- second: user 2026-10-06 "떠 있는 게 어색해"). Clients animate instead: MonsterMotion clips / Fx WOBBLE.

	nextId += 1
	local rec = {
		Id = nextId,
		Kind = kind,
		Def = def,
		ZoneId = def.Zone,
		Model = rig.Model,
		Root = rig.Root,
		Humanoid = rig.Humanoid,
		HP = maxHP,
		MaxHP = maxHP,
		Golden = golden,
		Home = point,
		Alive = true,
		Owner = owner,
		Event = opts.Event == true or nil, -- spawned by SpawnEvent: outside the regular pool, never respawns
		-- A23-110 (FirstKOService): a quiet personal monster's kill fires no MonsterKilled (no XP, gold, drops, cards, quest
		-- kills or boss counts); _onKilled(rec) tells its service of the kill (instead of MonsterKilled when quiet, after it
		-- otherwise); _strike(rec, target) deals its landed hits instead of Def.Damage
		Quiet = (owner ~= nil and opts.Quiet == true) or nil,
		_strike = (owner ~= nil and type(opts.Strike) == "function") and opts.Strike or nil,
		_onKilled = (owner ~= nil and type(opts.OnKilled) == "function") and opts.OnKilled or nil,
		-- A23-110: a practice personal monster (FirstKOService's retry King): its kill carries info.Practice = true (no
		-- finisher card, no drops) and pays the XP / gold of the kind opts.Practice names (else its own kind's)
		Practice = (owner ~= nil and opts.Practice ~= nil and opts.Practice ~= false)
			and ((type(opts.Practice) == "string" and Config.MonsterTypes[opts.Practice] ~= nil) and opts.Practice or kind) or nil,
		-- private
		_fill = rig.Fill,
		_scale = rig.Scale,
		_rootOffset = rig.RootOffset,
		_contributors = {},
		_hits = {}, -- [Player] = own hits (A23-27)
		_dmg = {}, -- [Player] = own damage, overkill excluded (A23-27)
		-- A23-113 ⑦: [Player] = own damage as shares of the MaxHP at each hit (a field boss's MaxHP follows its hunters),
		-- what the reward bar and the side share read
		_share = {},
		_nextAttackAt = 0,
		_nextWanderAt = os.clock() + Util.Random:NextNumber(1, WANDER_MAX),
		_noAggroUntil = 0,
		_returning = false,
		_target = nil,
		_goal = nil, -- last MoveTo destination (stuck detection, A11-R5)
		_stuckAt = nil,
		_stuckPos = nil,
		_chaseStuck = 0,
		_detour = nil,
		_detourUntil = 0,
		_deepSince = nil, -- A10-V3-2 (c): when the root first went below DEEP_Y
		_windup = nil, -- A15: token of the attack being wound up (the hit lands REACT.WINDUP s after it started)
		_hurtAt = -math.huge, -- A15: os.clock() of the last HurtSeq bump
		_shoveReadyAt = 0, -- A15: os.clock() when the next shove is allowed
		_radius = SEP.RadiusOf(def), -- A23-74: flat body radius (spacing)
	}
	records[rec.Id] = rec
	if type(def.Ambush) == "table" and owner == nil then MOB3.Hide(rec) end -- A23-87: waits hidden in the flowers
	return rec
end

local function emitDeathParticles(pos, color, scale)
	local fx = Instance.new("Part")
	fx.Name = "MonsterPop"
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.Transparency = 1
	fx.Size = Vector3.new(1, 1, 1)
	fx.CFrame = CFrame.new(pos)
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Speed = NumberRange.new(8, 16)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -25, 0)
	pe.LightEmission = 0.4
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 * scale), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = fx
	fx.Parent = Util.GetFolder(workspace, "Effects")
	pe:Emit(DEATH_PARTICLES)
	Debris:AddItem(fx, 1.5)
end

-- particle burst, the body holds (fall / splat) then shrinks to 0.2 in DEATH_SHRINK, destroyed at DEATH_DESTROY.
-- leaving = it goes home instead (LEAVE): no splat, no burst, it floats up while it shrinks away.
-- A23-74 (user 2026-10-07 "왜 반투명한 애들이 생기냐고"): no Transparency tween, the body stays opaque until it is
-- destroyed. A killed slime's CustomVisual keeps its size here: the clients splat it and shrink the puddle (Fx WOBBLE);
-- a server resize replicated over the splat and stood the body back up full size while it faded, so a dead slime read
-- as a living see-through one.
local function deathPop(rec, withParticles, leaving)
	local model, root, hum = rec.Model, rec.Root, rec.Humanoid
	if not model then return end
	if leaving then model:SetAttribute("Leaving", true) end -- set before the anchor below (clients test it on anchor)
	if hum and hum.Parent then
		hum.WalkSpeed = 0
	end
	if root and root.Parent then
		root.Anchored = true
		local bar = root:FindFirstChild("MonsterBar")
		if bar then bar.Enabled = false end
		if withParticles then
			emitDeathParticles(root.Position, rec.Golden and MC.GoldenColor or rec.Def.Color, rec._scale or 1)
		end
		if leaving then
			TweenService:Create(root, TweenInfo.new(LEAVE.Time, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
				{ CFrame = root.CFrame + Vector3.new(0, LEAVE.Rise, 0) }):Play()
		end
	end
	local hold = leaving and 0 or math.max(0, DEATH_DESTROY - DEATH_SHRINK - 0.1) -- TweenInfo DelayTime: the body stays
	local info = TweenInfo.new(leaving and LEAVE.Time or DEATH_SHRINK, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0,
		false, hold)
	local def = rec.Def
	local splatted = not leaving and type(def) == "table" and def.Shape == "Slime" and model:FindFirstChild("CustomVisual")
		or nil
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			-- the invisible joint anchor keeps its size; so does a slime body the clients splat
			if d ~= root and d.Name ~= VISUAL_ROOT_NAME and not (splatted and d:IsDescendantOf(splatted)) then
				TweenService:Create(d, info, { Size = d.Size * 0.2 }):Play()
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Light") or d:IsA("Highlight") then
			d.Enabled = false
		end
	end
	local life = leaving and LEAVE.Time + 0.1 or DEATH_DESTROY
	GHOST.Dying[model] = os.clock() + life + GHOST.Grace
	task.delay(life, function()
		if model then model:Destroy() end
	end)
end

local function removePersonalRef(rec)
	local owner = rec.Owner
	if not owner then return end
	local set = personal[owner]
	if set then
		set[rec] = nil
		if next(set) == nil then personal[owner] = nil end
	end
end

local scheduleRespawn -- forward

-- removes a record without rewards (timeout, owner left, model lost); leaving = float up and shrink away (LEAVE)
local function despawn(rec, fade, leaving)
	if not rec.Alive then return end
	rec.Alive = false
	records[rec.Id] = nil
	removePersonalRef(rec)
	if fade then
		deathPop(rec, false, leaving == true)
	elseif rec.Model then
		rec.Model:Destroy()
	end
end

-- A23-74 (user 2026-10-07): removes every child of workspace.Monsters that is neither a living record's model nor a
-- dying body still inside its time (GHOST.Dying); returns how many it removed
function GHOST.Sweep()
	local folder = getMonstersFolder()
	local live = {}
	for _, rec in records do
		if rec.Model then live[rec.Model] = true end
	end
	local now, removed = os.clock(), 0
	for _, child in folder:GetChildren() do
		local untilAt = GHOST.Dying[child]
		if not live[child] and not (untilAt and now < untilAt) then
			if pcall(child.Destroy, child) then removed += 1 end
		end
	end
	for model, untilAt in GHOST.Dying do
		if now >= untilAt or model.Parent == nil then GHOST.Dying[model] = nil end
	end
	if removed > 0 then warnThrottled("ghost", ("removed %d stray monster model(s) from workspace.Monsters"):format(removed)) end
	return removed
end

scheduleRespawn = function(kind)
	pending[kind] = (pending[kind] or 0) + 1
	task.delay(MC.RespawnDelay, function()
		pending[kind] = math.max(0, (pending[kind] or 0) - 1)
		local ok, err = pcall(function()
			local target = cappedTargets()[kind] or targetCount(kind) -- CR-L13
			if aliveCountOf(kind) < target and (Config.MonsterOutsideCap(kind) or totalNonPersonal() < GLOBAL_CAP) then
				spawnMonster(kind)
			end
		end)
		if not ok then warnThrottled("respawn", err) end
	end)
end

------------------------------------------------------------------ damage / death
local function killRecord(rec)
	rec.Alive = false
	rec.HP = 0
	records[rec.Id] = nil
	updateBar(rec)
	if rec.Quiet == true then
		-- A23-110: a quiet personal monster (FirstKOService's King) pays nothing and counts nowhere; its service hears it
		rec._contributors, rec._hits, rec._dmg, rec._share = {}, {}, {}, {}
		rec._manualAt, rec._firstAt = nil, nil
		deathPop(rec, true)
		removePersonalRef(rec)
		if rec._onKilled then
			local ok, err = pcall(rec._onKilled, rec)
			if not ok then warnThrottled("onKilled", err) end
		end
		return
	end

	local def = rec.Def
	local pos = (rec.Root and rec.Root.Parent) and rec.Root.Position or rec.Home
	local isPersonal = rec.Owner ~= nil
	local warPoints = 0
	if not isPersonal then
		warPoints = rec.Golden and Config.War.GoldenPoints or Config.War.MonsterPoints
	end
	local info = {
		Kind = rec.Kind,
		ZoneId = rec.ZoneId,
		Golden = rec.Golden,
		Position = pos,
		XP = def.XP * (rec.Golden and MC.GoldenXPMult or 1),
		Gold = def.Gold * (rec.Golden and MC.GoldenGoldMult or 1),
		WarPoints = warPoints,
		Personal = isPersonal,
		-- A23-90: a kill inside a PvP area (the ruins' Crown Pit) rolls its drop rows x the area's LootMult
		AreaMult = typeof(pos) == "Vector3" and (Config.PvPAreaAt(pos) or {}).LootMult or nil,
	}
	if rec.Practice then
		-- A23-110: a practice monster (the retry King) pays the XP / gold of its Practice kind and says so: info.Practice =
		-- no finisher card (FinisherService), no drops (LootService), no daily job (QuestService); a story quest's Kill row
		-- (StoryQuestService: Kind / ZoneId / Personal) still counts it as its own kind
		local pay = Config.MonsterTypes[rec.Practice] or def
		info.XP, info.Gold, info.Practice = pay.XP, pay.Gold, true
	end

	-- CR-M18: every contributor keeps the full personal WarPoints, but one kill adds WarPoints to a faction pool only
	-- once: WarShare = WarPoints / (contributors of that faction) (WarService.AddPoints(player, n, poolN))
	local now = os.clock()
	local eligible, perFaction, minors = {}, {}, {}
	local window = tonumber(def.ContributorWindow) or MC.ContributorWindow -- a miniboss fight is longer
	local minHits = tonumber(def.RewardMinHits) or 0
	if isPersonal then minHits = 0 end -- A23-110: only its owner hits a personal monster (no free riders: 2 skill hits count)
	-- A23-113 ⑦: the bar is a share of the boss: each hit counts as a share of the MaxHP it had then (_share), so a
	-- field boss that grew with its crowd never drops an early hunter under the bar (검수 bosshp_verify 2026-10-11)
	local minFrac = tonumber(def.RewardMinDamageFrac) or 0
	local share = type(rec._share) == "table" and rec._share or {}
	local function shareOf(p) -- a record made without _share (an old double): its raw damage / MaxHP
		local s = share[p]
		if type(s) ~= "number" then s = (tonumber(rec._dmg[p]) or 0) / math.max(1, tonumber(rec.MaxHP) or 1) end
		return s
	end
	-- 검수 2026-10-09 (Captain Clatter free riders): def.MinorShare > 0 = a contributor with the hits but under the
	-- damage share still gets MinorShare of the XP / gold (info.Minor: no drops, no card, no war points, not paid)
	local minorShare = math.clamp(tonumber(def.MinorShare) or 0, 0, 1)
	for p, t in rec._contributors do
		if p.Parent and now - t <= window and (rec._hits[p] or 0) >= minHits then
			if shareOf(p) >= minFrac - 1e-9 then
				local okF, f = pcall(factionOf, p)
				if not okF or type(f) ~= "string" then f = "None" end
				table.insert(eligible, { Player = p, Faction = f })
				perFaction[f] = (perFaction[f] or 0) + 1
			elseif minorShare > 0 and (rec._dmg[p] or 0) > 0 then
				table.insert(minors, p)
			end
		end
	end
	-- sound_gaps B11 (검수 2026-10-07): the UserIds this kill pays, kept on the record (sorted) for HalloweenService's
	-- KingDefeat Fx, which runs after the contributor tables below are cleared
	local paid = {}
	for _, e in eligible do table.insert(paid, e.Player.UserId) end
	table.sort(paid)
	rec.PaidUserIds = paid
	-- FB 6 (content_beyond_10min J): every hitter's own damage summed per side, kept for FieldBossService's defeat share
	-- line (Halo n% · Horns n%); Neutral / no side counts nowhere
	local sideDmg = { Halo = 0, Horns = 0 }
	for p in rec._dmg do -- A23-113 ⑦: shares of the boss at each hit (a raw sum would undercount early hits)
		local okF, f = pcall(factionOf, p)
		if okF and sideDmg[f] ~= nil then sideDmg[f] += math.max(0, shareOf(p)) end
	end
	rec.FactionDamage = sideDmg
	local manualAt = type(rec._manualAt) == "table" and rec._manualAt or {}
	-- A23-181 (user 10/14: 같이 잡은 몹의 사냥 명예·처치 수는 처음 친 사람 한 명에게): of the players this kill pays, the one
	-- who hit it first gets info.First = true (HuntFameService / WarService count only that one); a first hitter who left
	-- or fell out of the window = the earliest of those still paid. Drops, XP, gold, quests, codex, pets: every one as before
	local firstAt = type(rec._firstAt) == "table" and rec._firstAt or {}
	local firstP, firstN = nil, math.huge
	for _, cand in eligible do
		local n = tonumber(firstAt[cand.Player]) or math.huge
		if firstP == nil or n < firstN then firstP, firstN = cand.Player, n end
	end
	rec._contributors, rec._hits, rec._dmg, rec._share, rec._manualAt, rec._firstAt = {}, {}, {}, {}, {}, {}
	for _, e in eligible do
		local i = table.clone(info)
		i.WarShare = info.WarPoints / math.max(1, perFaction[e.Faction] or 1)
		i.SkillHit = type(rec._skillBy) == "table" and rec._skillBy[e.Player] == true -- story S0: "basic attacks only"
		-- king finisher card (docs/design/king_finisher_2026-10-08.md): an accepted manual hit within the window
		i.Manual = manualAt[e.Player] ~= nil and now - manualAt[e.Player] <= window
		-- BB38 metrics (TelemetryService: kills together / with a friend): how many earned this kill, and the others
		i.Party, i.Others = #eligible, {}
		for _, o in eligible do
			if o.Player ~= e.Player then table.insert(i.Others, o.Player) end
		end
		i.First = e.Player == firstP -- A23-181
		MonsterService.MonsterKilled:Fire(e.Player, i)
	end
	-- the free riders' small share (MinorShare of XP / gold only; LootService rolls nothing for info.Minor)
	for _, p in minors do
		local i = table.clone(info)
		i.Minor = true
		i.XP, i.Gold = info.XP * minorShare, info.Gold * minorShare
		i.WarPoints, i.WarShare = 0, 0
		i.Manual, i.SkillHit = false, false
		i.Party, i.Others = #eligible, {}
		i.First = false -- A23-181: a free rider is never the first hitter's credit
		MonsterService.MonsterKilled:Fire(p, i)
	end

	deathPop(rec, true)
	if isPersonal then
		removePersonalRef(rec)
		if rec._onKilled then -- A23-110: its service hears it after the kill (FirstKOService's rematch King)
			local okK, errK = pcall(rec._onKilled, rec)
			if not okK then warnThrottled("onKilled", errK) end
		end
	elseif not rec.Event then
		scheduleRespawn(rec.Kind)
	end
end

-- A15: pain reaction for clients ("HurtBig" first, then "HurtSeq" +1), at most once per REACT.HURT_GAP s per monster
local function markHurt(rec, amount, crit)
	local now = os.clock()
	if now - rec._hurtAt < REACT.HURT_GAP then return end
	local model = rec.Model
	if not model or not model.Parent then return end
	rec._hurtAt = now
	local big = crit == true or (rec.MaxHP > 0 and amount >= rec.MaxHP * REACT.BIG_FRACTION)
	model:SetAttribute(HURT_BIG_ATTR, big)
	local seq = model:GetAttribute(HURT_SEQ_ATTR)
	model:SetAttribute(HURT_SEQ_ATTR, (type(seq) == "number" and seq or 0) + 1)
end

-- crit (optional): the hit was a critical hit (only used for the "HurtBig" pain reaction). castId (optional, SKL-3): a
-- skill cast that hits the same monster again (a field's ticks) counts as one hit of that player (A23-27 RewardMinHits).
-- manual (optional, king finisher card): true = the player's own press (a swing / skill, never auto combat); the time of
-- the last accepted manual hit per player is kept (record._manualAt) and the kill passes info.Manual
function MonsterService.DamageMonster(record, amount, player, crit, castId, manual)
	if type(record) ~= "table" or not record.Alive then return false end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then return false end
	if record.Owner and record.Owner ~= player then return false end -- A5-C2
	-- CR-M5: a zone monster takes no damage from a player standing outside its zone (no HP change, no contribution)
	if record.Owner == nil and player and zoneIdOf(player) ~= record.ZoneId then return false end
	if record._hidden then MOB3.Show(record) end -- A23-87: a hit flower slime pops out
	if player then
		record._contributors[player] = os.clock()
		-- A23-181: when each player FIRST hit it (the kill's hunt honor / crown units go to one player: the earliest)
		record._firstAt = record._firstAt or {}
		if record._firstAt[player] == nil then
			record._firstSeq = (record._firstSeq or 0) + 1
			record._firstAt[player] = record._firstSeq
		end
		if manual == true then
			record._manualAt = record._manualAt or {}
			record._manualAt[player] = os.clock()
		end
		-- A23-27: own hits and damage per contributor (a def with RewardMinHits / RewardMinDamageFrac pays only those
		-- who met both); the overkill part of the last hit does not count. SKL-3: a cast counts once however often it
		-- hits (a field's ticks), also with other hits in between (검수 2026-10-07: the casts seen per player are a set)
		record._castOf = record._castOf or {}
		local seen = castId ~= nil and record._castOf[player] or nil
		if castId == nil or not (seen and seen[castId]) then
			record._hits[player] = (record._hits[player] or 0) + 1
			if castId ~= nil then
				seen = seen or {}
				seen[castId] = true
				record._castOf[player] = seen
			end
		end
		local dealt = math.min(amount, math.max(0, record.HP))
		record._dmg[player] = (record._dmg[player] or 0) + dealt
		if type(record._share) == "table" then -- every spawned record has it (a record made without it: raw damage / MaxHP)
			record._share[player] = (record._share[player] or 0) + dealt / math.max(1, tonumber(record.MaxHP) or 1)
		end
	end
	record.HP -= amount
	if record.HP > 0 then
		updateBar(record)
		local okHurt, errHurt = pcall(markHurt, record, amount, crit)
		if not okHurt then warnThrottled("hurt", errHurt) end
		MonsterService.Moment:Fire(record, "Hit") -- ③ barks
		return false
	end
	killRecord(record) -- the killing hit plays the death pop instead of a pain reaction
	return true
end

function MonsterService.ApplyKnockback(record, fromPosition, power)
	if type(record) ~= "table" or not record.Alive then return end
	if typeof(fromPosition) ~= "Vector3" or type(power) ~= "number" then return end
	local root = record.Root
	if not root or not root.Parent or root.Anchored then return end
	local d = root.Position - fromPosition
	local flat = Vector3.new(d.X, 0, d.Z)
	local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.zero
	root.AssemblyLinearVelocity = dir * power + Vector3.new(0, 25, 0)
end

-- A15: shove sweep params (Terrain + every collidable part under workspace.Map; water ignored), rebuilt like the
-- ground params so a late MapBuilder pass is picked up
local shoveSweep = { Params = nil, At = -math.huge }
local function getShoveParams()
	local now = os.clock()
	if shoveSweep.Params and now - shoveSweep.At < GROUND_PARAMS_REFRESH then return shoveSweep.Params end
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map then table.insert(list, map) end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	params.IgnoreWater = true
	pcall(function()
		params.RespectCanCollide = true -- invisible zone / pad volumes never block a shove
	end)
	shoveSweep.Params, shoveSweep.At = params, now
	return params
end

-- A15: subtle shove of a monster a player's hit landed on: the root slides `studs` (capped by REACT.SHOVE_MAX, divided
-- by the body scale so big monsters barely move) away from `fromPosition` over REACT.SHOVE_TIME. Skipped for anchored
-- (dying) roots, other players' personal monsters, a monster shoved less than REACT.SHOVE_GAP s ago, and whenever the
-- end point is not walkable ground (water / ridge / shore) in the zone the monster stands in (zone monsters: inside
-- their own zone rect inset by ZONE_MOVE_INSET, like every MoveTo). Returns true when a shove started.
function MonsterService.Shove(record, fromPosition, studs, player)
	if type(record) ~= "table" or not record.Alive then return false end
	if typeof(fromPosition) ~= "Vector3" then return false end
	if type(studs) ~= "number" or studs ~= studs or studs <= 0 then return false end
	if record.Owner and record.Owner ~= player then return false end -- A5-C2
	local now = os.clock()
	if now < record._shoveReadyAt then return false end
	local root = record.Root
	if not root or not root.Parent or root.Anchored then return false end

	local pos = root.Position
	local flat = Vector3.new(pos.X - fromPosition.X, 0, pos.Z - fromPosition.Z)
	if flat.Magnitude < 0.05 then
		local lv = root.CFrame.LookVector
		flat = Vector3.new(-lv.X, 0, -lv.Z) -- hit from right on top of it: push it backwards
		if flat.Magnitude < 0.05 then return false end
	end
	local dist = math.min(studs, REACT.SHOVE_MAX) / math.max(1, record._scale or 1)
	local delta = flat.Unit * dist
	local dest = pos + delta

	local here = Config.ZoneAt(pos).Id
	if Config.ZoneAt(dest).Id ~= here then return false end
	if record.Owner == nil then
		local zone = Config.Zones[record.ZoneId]
		if here ~= record.ZoneId or (zone and not insideZone(zone, dest, ZONE_MOVE_INSET)) then return false end
	end
	local g, noHit = groundPoint(dest.X, dest.Z)
	if not g and not noHit then return false end -- water / ridge / shore (noHit = bare test place: flat ground)
	-- never into a wall / gate / tree / rock / hillside at body height
	if workspace:Raycast(pos, delta + flat.Unit * 0.5, getShoveParams()) then return false end

	record._shoveReadyAt = now + REACT.SHOVE_GAP
	task.spawn(function()
		local ok, err = pcall(function()
			local done = 0
			while true do
				task.wait()
				if not record.Alive or not root.Parent or root.Anchored then break end
				local t = math.clamp((os.clock() - now) / math.max(REACT.SHOVE_TIME, 0.01), 0, 1)
				local f = 1 - (1 - t) * (1 - t) -- ease out
				root.CFrame = root.CFrame + delta * (f - done)
				done = f
				if t >= 1 then break end
			end
		end)
		if not ok then warnThrottled("shove", err) end
	end)
	return true
end

------------------------------------------------------------------ SKL-2 skill pull / push (SkillService)
-- A23-49 rule 9 (skill_kit §3 Pull / Push): a skill moves a monster it hit. "Pull": toward fromPosition (the caster) by
-- at most `studs`, stopping Stop studs short of it; "Push": away from fromPosition by `studs`. The distance is divided by
-- the body scale (big monsters move less); a boss (MonsterTypes Boss) never moves, nor another player's personal
-- monster. The end point must stay in the zone the monster stands in (a zone monster: inside its own zone rect inset
-- ZONE_MOVE_INSET and within LeashRadius of its home), on walkable ground, with no wall / decor in the way at body
-- height; when the full move is not allowed it tries the shorter Steps, else nothing. Slides over Time (ease out) like
-- Shove, which stays the small hit slide. Returns the studs moved (0 = none).
local DISPLACE = { Stop = 3, Time = 0.2, Steps = { 1, 0.75, 0.5, 0.25 }, HopDrop = 8 } -- HopDrop: SKL-3 HopReach
function DISPLACE.Slide(record, root, delta)
	local start = os.clock()
	record._shoveReadyAt = math.max(record._shoveReadyAt or 0, start + DISPLACE.Time) -- no hit shove fights the slide
	task.spawn(function()
		local ok, err = pcall(function()
			local done = 0
			while true do
				task.wait()
				if not record.Alive or not root.Parent or root.Anchored then break end
				local t = math.clamp((os.clock() - start) / DISPLACE.Time, 0, 1)
				local f = 1 - (1 - t) * (1 - t) -- ease out
				root.CFrame = root.CFrame + delta * (f - done)
				done = f
				if t >= 1 then break end
			end
		end)
		if not ok then warnThrottled("displace", err) end
	end)
end

function MonsterService.Displace(record, mode, fromPosition, studs, player)
	if type(record) ~= "table" or not record.Alive then return 0 end
	if (mode ~= "Pull" and mode ~= "Push") or typeof(fromPosition) ~= "Vector3" then return 0 end
	if type(studs) ~= "number" or studs ~= studs or studs <= 0 or studs == math.huge then return 0 end
	if record.Owner and record.Owner ~= player then return 0 end -- A5-C2
	local def = record.Def or Config.MonsterTypes[record.Kind]
	if type(def) == "table" and def.Boss then return 0 end
	local root = record.Root
	if not root or not root.Parent or root.Anchored then return 0 end
	local pos = root.Position
	local toCaster = Vector3.new(fromPosition.X - pos.X, 0, fromPosition.Z - pos.Z)
	local gap = toCaster.Magnitude
	if gap < 0.05 then return 0 end
	local dir = mode == "Pull" and toCaster.Unit or -toCaster.Unit
	local dist = studs / math.max(1, record._scale or 1)
	if mode == "Pull" then dist = math.min(dist, gap - DISPLACE.Stop) end
	if dist <= 0.05 then return 0 end
	local here = Config.ZoneAt(pos).Id
	local zone = record.Owner == nil and Config.Zones[record.ZoneId] or nil
	if record.Owner == nil and (here ~= record.ZoneId or not zone) then return 0 end
	for _, part in DISPLACE.Steps do
		local delta = dir * (dist * part)
		local dest = pos + delta
		local ok = Config.ZoneAt(dest).Id == here
		if ok and zone then
			ok = insideZone(zone, dest, ZONE_MOVE_INSET)
				and (typeof(record.Home) ~= "Vector3" or Util.FlatDistance(dest, record.Home) <= MC.LeashRadius)
		end
		if ok then
			local g, noHit = groundPoint(dest.X, dest.Z)
			ok = (g ~= nil or noHit) and not workspace:Raycast(pos, delta + dir * 0.5, getShoveParams())
		end
		if ok then
			DISPLACE.Slide(record, root, delta)
			return dist * part
		end
	end
	return 0
end

-- SKL-3 Taunt (Roar): the monster chases `player` first for `seconds` (os.clock). Bosses, the golden goose (not a
-- record) and personal monsters never; a living taunt by someone else is not taken over. True when taunted
function MonsterService.Taunt(record, player, seconds)
	if type(record) ~= "table" or not record.Alive or record.Owner ~= nil then return false end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
	if type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then return false end
	local def = record.Def or Config.MonsterTypes[record.Kind]
	if type(def) == "table" and def.Boss then return false end
	local now = os.clock()
	if record._tauntBy and record._tauntBy ~= player and now < (record._tauntUntil or 0) then return false end
	record._tauntBy, record._tauntUntil = player, now + math.min(seconds, 10)
	return true
end

-- SKL-3 Slow (fields): walk speed x mult for `seconds` (a boss gets half the slow: 0.5 -> x0.75); the strongest slow
-- running wins, a refresh extends it
function MonsterService.Slow(record, mult, seconds)
	if type(record) ~= "table" or not record.Alive then return false end
	if type(mult) ~= "number" or mult ~= mult or type(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return false
	end
	mult = math.clamp(mult, 0.1, 1)
	local def = record.Def or Config.MonsterTypes[record.Kind]
	if type(def) == "table" and def.Boss then mult = 1 - (1 - mult) / 2 end
	local now = os.clock()
	local running = record._slowUntil and now < record._slowUntil
	record._slowMult = running and math.min(record._slowMult or 1, mult) or mult
	record._slowUntil = math.max(running and record._slowUntil or 0, now + math.min(seconds, 10))
	return true
end

-- SKL-3 Hop (SkillService): how far a player may hop from `from` along the flat unit `dir`: the longest of `studs` x
-- DISPLACE.Steps that stays in the zone `from` stands in, lands on walkable ground (no water, ridge or decor; at most
-- HopDrop studs up or down from the ground under `from`) with no wall in between. 0 = nowhere
function MonsterService.HopReach(from, dir, studs)
	if typeof(from) ~= "Vector3" or typeof(dir) ~= "Vector3" then return 0 end
	if type(studs) ~= "number" or studs ~= studs or studs <= 0 or studs > 40 then return 0 end
	local here = Config.ZoneAt(from).Id
	local base = groundPoint(from.X, from.Z)
	for _, part in DISPLACE.Steps do
		local delta = dir * (studs * part)
		local dest = from + delta
		if Config.ZoneAt(dest).Id == here then
			local g, noHit = groundPoint(dest.X, dest.Z)
			local level = g == nil or base == nil or math.abs(g.Y - base.Y) <= DISPLACE.HopDrop
			if (g ~= nil or noHit) and level and not workspace:Raycast(from, delta + dir * 0.5, getShoveParams()) then
				return studs * part
			end
		end
	end
	return 0
end

------------------------------------------------------------------ event monsters (HalloweenService miniboss)
-- Spawns `kind` outside the regular pool: not in the density counts, never respawns, never golden unless opts.Golden.
-- opts.Near (Vector3) + opts.Radius: a walkable ground point in def.Zone within Radius of Near (never water, a ridge
-- or solid decor; opts.MaxY = a higher ground top allowed there, e.g. the King Slime's hill-top shrine); falls back to a
-- normal spawn point of the zone. Returns the record, or nil when no ground was found
-- this time (the caller retries). Otherwise it is a normal zone monster (AI, damage, rewards per contributor).
function MonsterService.SpawnEvent(kind, opts)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	if type(def) ~= "table" then return nil end
	if type(opts) ~= "table" then opts = {} end
	local pos = nil
	local near = opts.Near
	if typeof(near) == "Vector3" then
		local radius = math.max(0, tonumber(opts.Radius) or 30)
		-- A23-74 review: a boss keeps the spawn clearance too (SEP.Clear); when every try is crowded the first crowded
		-- point is used and SEP.Resolve slides the smaller monsters off it (a boss itself never slides)
		local body, crowded = SEP.RadiusOf(def), nil
		for i = 1, SPAWN_TRIES * 2 do
			local a = Util.Random:NextNumber(0, math.pi * 2)
			local d = (i == 1) and 0 or Util.Random:NextNumber(0, radius)
			local x, z = near.X + math.cos(a) * d, near.Z + math.sin(a) * d
			local g, noHit = groundPoint(x, z, opts.MaxY, def) -- A23-129: never inside a map prop
			if noHit then g = Vector3.new(x, 0, z) end -- bare test place: legacy flat ground
			if g and Config.ZoneAt(g).Id == def.Zone then
				if SEP.Clear(g, body) then
					pos = g
					break
				end
				crowded = crowded or g
			end
		end
		-- 검수 2026-10-11 (spawnclear review): every try within Radius has a prop in the body (the King's shrine marker is
		-- 0.5 stud clear): rings farther out (Radius + 3 / 6 / 9, 12 directions) before a normal spawn point of the zone
		for ring = 1, (pos or crowded) and 0 or 3 do
			local d = radius + 3 * ring
			for k = 0, 11 do
				local a = k * math.pi / 6
				local x, z = near.X + math.cos(a) * d, near.Z + math.sin(a) * d
				local g = groundPoint(x, z, opts.MaxY, def)
				if g and Config.ZoneAt(g).Id == def.Zone then
					if SEP.Clear(g, body) then
						pos = g
						break
					end
					crowded = crowded or g
				end
			end
			if pos then break end
		end
		pos = pos or crowded
	end
	if not pos then pos = pickSpawnPoint(def) end
	if not pos then return nil end
	local ok, rec = pcall(spawnMonster, kind, { Position = pos, Golden = opts.Golden == true, Event = true })
	if not ok then
		warnThrottled("event_" .. kind, rec)
		return nil
	end
	return rec
end

-- removes a living event monster without rewards (fades out unless fade == false; leaving = true: it goes home,
-- floating up and fading without the death shrink / splat, so nobody reads it as a kill); true when it was removed
function MonsterService.RemoveEvent(rec, fade, leaving)
	if type(rec) ~= "table" or rec.Event ~= true or not rec.Alive then return false end
	despawn(rec, fade ~= false, leaving == true)
	return true
end

-- A23-113 ⑦ (FieldBossService, a field boss's HP follows its hunters): a living event monster's new MaxHP; its HP keeps
-- the same fraction (rounded, never below 1 here) and the bar follows. true when it changed
function MonsterService.SetEventMaxHP(rec, maxHP)
	if type(rec) ~= "table" or rec.Event ~= true or not rec.Alive then return false end
	if type(maxHP) ~= "number" or maxHP ~= maxHP or maxHP <= 0 or maxHP == math.huge then return false end
	local old = tonumber(rec.MaxHP) or 0
	if old <= 0 or math.abs(maxHP - old) < 1e-6 then return false end
	local frac = math.clamp((tonumber(rec.HP) or 0) / old, 0, 1)
	rec.MaxHP = maxHP
	rec.HP = math.max(1, math.floor(frac * maxHP + 0.5))
	updateBar(rec)
	return true
end

-- A23-113 ⑦: a copy of every player's own damage on this monster so far (A23-27 _dmg: overkill excluded; players who
-- left stay in it until the kill)
function MonsterService.DamageTotals(rec)
	local out = {}
	if type(rec) ~= "table" or type(rec._dmg) ~= "table" then return out end
	for p, d in rec._dmg do
		if typeof(p) == "Instance" and type(d) == "number" and d > 0 then out[p] = d end
	end
	return out
end

-- A23-110: removes a living personal monster without rewards, like RemoveEvent (FirstKOService: the King leaves after
-- the first KO, or when its quest step is over); true when it was removed
function MonsterService.RemovePersonal(rec, fade, leaving)
	if type(rec) ~= "table" or rec.Owner == nil or not rec.Alive then return false end
	despawn(rec, fade ~= false, leaving == true)
	return true
end

-- A23-110: walkable ground under (x, z) as the monsters see it (groundPoint): the point, or nil + true when nothing is
-- hit there (a bare test place: flat ground), nil + false for water / a ridge / solid decor. kind (optional, A23-129,
-- tools/spawn_clear_probe.luau): nil + false too when a map prop stands inside that kind's body there
function MonsterService.GroundAt(x, z, kind)
	if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z then return nil, false end
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	return groundPoint(x, z, nil, def)
end

-- A23-129 (read-only, tools/spawn_clear_probe.luau): a spawn point for a zone monster kind exactly as a new one would
-- get it (pickSpawnPoint, nothing spawned), or nil
function MonsterService.PickSpawnPoint(kind)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	if type(def) ~= "table" then return nil end
	return pickSpawnPoint(def, kind)
end

------------------------------------------------------------------ personal monsters (A4 / A5-C2..C4)
function MonsterService.SpawnPersonal(player, monsterId, opts)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then return nil end
	if type(monsterId) ~= "string" or Config.MonsterTypes[monsterId] == nil then return nil end
	if type(opts) ~= "table" then opts = {} end

	-- one living personal monster of a kind per player: reuse it (A23-110: the record is the second result)
	local set = personal[player]
	if set then
		for rec in set do
			if rec.Alive and rec.Kind == monsterId and rec.Model and rec.Model.Parent then
				return rec.Model, rec
			end
		end
	end
	-- A23-110: opts.Distance = studs in front of the player (default PERSONAL_DISTANCE)
	local dist = tonumber(opts.Distance)
	if not dist or dist ~= dist or dist < 2 or dist > 40 then dist = PERSONAL_DISTANCE end

	-- ~8 studs in front of the player on walkable ground (then the sides / behind); fallback: the home-zone spawn.
	-- A23-129: a spot with a map prop inside the body is skipped; 검수 2026-10-11: all four blocked -> 12 directions at
	-- dist and at 1.5 x dist, the front first (the First-KO King by a tree); all blocked + Near: nil (the caller retries)
	local def = Config.MonsterTypes[monsterId]
	local pos, faceTo
	local root = Util.GetRoot(player)
	if root then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
		local base = root.Position
		local tries = {}
		for _, ang in { 0, math.pi / 2, -math.pi / 2, math.pi } do table.insert(tries, { ang, dist }) end
		for ring = 1, 2 do
			for k = 0, 11 do
				-- 0, +30, -30, +60, -60, ... 180 degrees; the first ring skips the four sides tried above
				local deg = math.ceil(k / 2) * 30 * (k % 2 == 1 and 1 or -1)
				if ring == 2 or deg % 90 ~= 0 then table.insert(tries, { math.rad(deg), ring == 1 and dist or dist * 1.5 }) end
			end
		end
		for _, t in tries do
			local ang = t[1]
			local c, s = math.cos(ang), math.sin(ang)
			local dir = Vector3.new(flat.X * c - flat.Z * s, 0, flat.X * s + flat.Z * c)
			local p = base + dir * t[2]
			local g, noHit = groundPoint(p.X, p.Z, nil, def)
			if g then
				pos = g
			elseif noHit then
				pos = Vector3.new(p.X, 0, p.Z) -- bare test place: legacy flat ground
			end
			if pos then break end
		end
		faceTo = base
	end
	if not pos and opts.Near == true then return nil end -- A23-110: by the player or not at all (no home-zone spot)
	if not pos then
		local faction = player:GetAttribute("Faction")
		local zone = Config.Zones[Config.HomeZoneId(type(faction) == "string" and faction or "None")] or Config.Zones.Crossroads
		local p = zone.Spawn + Vector3.new(0, 0, -PERSONAL_DISTANCE)
		-- 검수 2026-10-11: the town spot keeps the body out of props too (blocked = no spawn this time)
		local g, noHit = groundPoint(p.X, p.Z, nil, def)
		if not g and not noHit then return nil end
		pos = g or Vector3.new(p.X, 0, p.Z)
		faceTo = faceTo or zone.Spawn
	end

	local ok, rec = pcall(spawnMonster, monsterId, {
		Owner = player,
		Golden = opts.Golden == true,
		HP = tonumber(opts.HP),
		Position = pos,
		FaceTo = faceTo,
		Quiet = opts.Quiet == true, -- A23-110 (see spawnMonster)
		Strike = opts.Strike,
		OnKilled = opts.OnKilled,
		Practice = opts.Practice,
	})
	if not ok then
		warnThrottled("personal", rec)
		return nil
	end
	if not rec then return nil end

	personal[player] = personal[player] or {}
	personal[player][rec] = true
	-- A23-110: opts.Hold = s before its first swing (FirstKOService: the King drops from the sky first)
	local hold = tonumber(opts.Hold)
	if hold and hold == hold and hold > 0 then rec._nextAttackAt = os.clock() + math.min(hold, 10) end
	-- A23-113 ①: opts.LeapGrow / LeapGrowMax = studs its next landing circle grows after one that hit nobody, up to that
	-- much more (Config.BossLeap; FirstKOService's first King keeps hopping until it lands)
	local grow, growMax = tonumber(opts.LeapGrow), tonumber(opts.LeapGrowMax)
	if grow and grow == grow and grow > 0 then
		if not growMax or growMax ~= growMax then growMax = grow end
		rec._leapGrow, rec._leapGrowMax = math.min(grow, 40), math.clamp(growMax, 0, 40)
	end

	task.delay(PERSONAL_LIFETIME, function()
		if rec.Alive then despawn(rec, true, rec.Quiet == true) end -- A23-110: a quiet King goes home (no splat)
	end)
	return rec.Model, rec
end

local function onOwnerLeaving(player)
	local set = personal[player]
	if not set then return end
	personal[player] = nil
	for rec in set do
		if rec.Alive then
			rec.Alive = false
			records[rec.Id] = nil
			if rec.Model then rec.Model:Destroy() end
		end
	end
end

------------------------------------------------------------------ AI
local function findInfo(plist, player)
	for _, info in plist do
		if info.Player == player then return info end
	end
	return nil
end

-- A10-V3-2 (a) + A3-M4: a player this (non-personal) monster may chase: in the monster's own zone, not in a town,
-- not in the water
local function targetable(rec, info)
	-- A23-27: a boss (the Pumpkin King) leaves new players alone whatever their faction: Level < SafeBelowLevel OR
	-- PlaytimeSeconds < SafePlaySeconds (the PvP Rookie shield is not used: it means something else)
	local def = Config.MonsterTypes[rec.Kind]
	if def and def.Boss and typeof(info.Player) == "Instance" then
		local H = Config.Halloween or {}
		local lv = tonumber(info.Player:GetAttribute("Level")) or 1
		local played = tonumber(info.Player:GetAttribute("PlaytimeSeconds")) or 0
		if lv < (tonumber(H.SafeBelowLevel) or 0) or played < (tonumber(H.SafePlaySeconds) or 0) then return false end
	end
	-- user 2026-10-05: monsters always attack as usual (no window / rest state may become a safe spot to exploit)
	return not info.Town and info.Zone == rec.ZoneId and info.Pos.Y >= OUT_Y
end

-- FACE: the flat unit direction from the root to targetPos (nil when on top of it)
function FACE.Dir(root, targetPos)
	local pos = root.Position
	local flat = Vector3.new(targetPos.X - pos.X, 0, targetPos.Z - pos.Z)
	if flat.Magnitude < 0.1 then return nil end
	return flat.Unit
end

-- FACE: cos of the angle between the flat look direction and the target (1 = straight ahead, also when on top of it)
function FACE.Cos(root, targetPos)
	local dir = FACE.Dir(root, targetPos)
	local lv = root.CFrame.LookVector
	local look = Vector3.new(lv.X, 0, lv.Z)
	if not dir or look.Magnitude < 0.01 then return 1 end
	return look.Unit:Dot(dir)
end

-- FACE: one frame of turning (at most TurnRate * dt) around the root's own position, upright
function FACE.Turn(root, targetPos, dt, rate)
	local dir = FACE.Dir(root, targetPos)
	if not dir then return end
	local lv = root.CFrame.LookVector
	local cur = math.atan2(-lv.X, -lv.Z) -- CFrame.Angles(0, yaw, 0).LookVector = (-sin yaw, 0, -cos yaw)
	local diff = (math.atan2(-dir.X, -dir.Z) - cur + math.pi) % (2 * math.pi) - math.pi
	if math.abs(diff) < 0.01 then return end
	local stepMax = (rate or FACE.TurnRate) * dt
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, cur + math.clamp(diff, -stepMax, stepMax), 0)
end

-- FACE: every frame, each facing monster turns toward its target's current position (or a look's fixed Point at its
-- Rate); a facing ends when attack() has not renewed it for Keep s (and no wind-up is pending), when a look's Until
-- passes, or when the monster / target is gone
function FACE.Step(dt)
	if next(FACE.Active) == nil then return end
	local now = os.clock()
	for rec, f in FACE.Active do
		local root = rec.Root
		local live = rec.Alive and records[rec.Id] == rec and root ~= nil and root.Parent ~= nil and not root.Anchored
			and (now < f.Until or rec._windup ~= nil)
		local goal = nil
		if live and typeof(f.Point) == "Vector3" then
			goal = f.Point
		elseif live then
			local target = f.Target
			local troot = typeof(target) == "Instance" and target.Parent ~= nil and Util.IsAlive(target)
				and Util.GetRoot(target) or nil
			goal = troot and troot.Position or nil
		end
		if not goal then
			FACE.Active[rec] = nil
		else
			local ok, err = pcall(FACE.Turn, root, goal, math.min(dt, 0.1), f.Rate)
			if not ok then
				FACE.Active[rec] = nil
				warnThrottled("face", err)
			end
		end
	end
end

-- NATURAL: WalkSpeed for a walk at `pace` of the chase speed, eased in from standing (RampStart + RampStep per AI
-- tick); with `goal` it slows to half within ArriveSlow studs of it
function NATURAL.Pace(rec, pace, goal)
	local root = rec.Root
	local v = root.AssemblyLinearVelocity
	if v.X * v.X + v.Z * v.Z < 0.25 then rec._rampTicks = 0 else rec._rampTicks = (rec._rampTicks or 0) + 1 end
	local ramp = math.min(1, NATURAL.RampStart + NATURAL.RampStep * rec._rampTicks)
	local arrive = 1
	if typeof(goal) == "Vector3" then
		arrive = math.clamp(Util.FlatDistance(root.Position, goal) / NATURAL.ArriveSlow, 0.5, 1)
	end
	-- SKL-3 Slow (MonsterService.Slow): x _slowMult until _slowUntil
	local slow = (rec._slowUntil and os.clock() < rec._slowUntil) and (rec._slowMult or 1) or 1
	rec.Humanoid.WalkSpeed = (tonumber(rec.Def.Speed) or 12) * pace * ramp * arrive * slow
end

-- NATURAL: true while a monster stops with a '!' for a target it just spotted out of reach (AlertAt), facing it
function NATURAL.Alert(rec, info, dist, now)
	if rec._target ~= info.Player and dist > MC.AttackRange then
		rec._alerted = rec._alerted or setmetatable({}, { __mode = "k" })
		local seen = rec._alerted[info.Player]
		if seen == nil or now - seen > NATURAL.AlertAgain then
			rec._alerted[info.Player] = now
			rec._alertUntil = now + NATURAL.AlertHold
			if rec.Model then rec.Model:SetAttribute("AlertAt", workspace:GetServerTimeNow()) end
		end
	end
	if now >= (rec._alertUntil or 0) then return false end
	rec._goal = nil
	rec.Humanoid:MoveTo(rec.Root.Position)
	FACE.Active[rec] = { Target = info.Player, Until = now + FACE.Keep }
	return true
end

-- NATURAL: a standing idle monster sometimes looks around (a slow turn to a random side) or glances at a player within
-- GlanceRange (one it may not chase: in a town, another zone, its no-aggro pause). True when a look started.
function NATURAL.Idle(rec, pos, plist, now)
	local v = rec.Root.AssemblyLinearVelocity
	if v.X * v.X + v.Z * v.Z >= 0.25 or FACE.Active[rec] ~= nil or now < (rec._lookAt or 0) then return false end
	rec._lookAt = now + Util.Random:NextNumber(NATURAL.LookEvery[1], NATURAL.LookEvery[2])
	local point = nil
	for _, info in plist do
		if Util.FlatDistance(pos, info.Pos) <= NATURAL.GlanceRange then
			point = info.Pos
			break
		end
	end
	if not point then
		local lv = rec.Root.CFrame.LookVector
		local side = Util.Random:NextNumber() < 0.5 and -1 or 1
		local yaw = math.atan2(-lv.X, -lv.Z) + side * Util.Random:NextNumber(math.rad(40), math.rad(110))
		point = pos + Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)) * 5
	end
	FACE.Active[rec] = { Point = point, Rate = NATURAL.LookRate, Until = now + NATURAL.LookTime }
	return true
end

-- A15: the wound-up hit lands only if this wind-up is still the current one, the monster is alive and in the world
-- and the target is alive, still a valid target (owner / zone / town / water rules) and within AttackRange + leeway.
-- FACE: and only once the target is within +-30 deg of the look direction (rechecked while the body turns, up to
-- FACE.MaxExtra s more; then the swing misses). Bumps AttackSeq at the impact (clients play the lunge along the look
-- direction), then deals the damage. waited = s already spent past the wind-up.
local function landAttack(rec, token, target, waited)
	if rec._windup ~= token then return end
	waited = tonumber(waited) or 0
	local function cancel()
		if rec._windup == token then rec._windup = nil end
	end
	if not rec.Alive or records[rec.Id] ~= rec then return cancel() end
	local model, root = rec.Model, rec.Root
	if not model or not model.Parent or not root or not root.Parent or root.Anchored then return cancel() end
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent == nil or not Util.IsAlive(target) then
		return cancel()
	end
	local troot = Util.GetRoot(target)
	if not troot then return cancel() end
	local tpos = troot.Position
	if Util.FlatDistance(root.Position, tpos) > MC.AttackRange + REACT.WINDUP_LEEWAY then return cancel() end
	if rec.Owner then
		if target ~= rec.Owner or tpos.Y < OUT_Y or isPlayerInTown(target, tpos) then return cancel() end
	else
		if rec._returning then return cancel() end
		local info = { Player = target, Pos = tpos, Town = isPlayerInTown(target, tpos), Zone = Config.ZoneAt(tpos).Id }
		if not targetable(rec, info) then return cancel() end
	end
	if FACE.Cos(root, tpos) < FACE.HitCos then
		if waited >= FACE.MaxExtra then return cancel() end -- turned too slowly: the swing misses
		FACE.Active[rec] = { Target = target, Until = os.clock() + FACE.Keep } -- keep turning toward this target
		task.delay(FACE.Recheck, function()
			local ok, err = pcall(landAttack, rec, token, target, waited + FACE.Recheck)
			if not ok then
				cancel()
				warnThrottled("attack", err)
			end
		end)
		return
	end

	rec._windup = nil
	local seq = model:GetAttribute(ATTACK_SEQ_ATTR)
	model:SetAttribute(ATTACK_SEQ_ATTR, (type(seq) == "number" and seq or 0) + 1)
	if rec._strike then
		-- A23-110: its service deals the hit (FirstKOService: the King Slime's one hit on the quest step, the retry King)
		local ok, err = pcall(rec._strike, rec, target)
		if not ok then warnThrottled("strike", err) end
	elseif S and S.CombatService then
		S.CombatService.DamagePlayer(target, rec.Def.Damage, nil, false, rec.Kind) -- BB14: the KO screen names the monster
	end
end

-- in reach: stand still for a swing, keep facing the target (FACE, every frame) and start a wind-up when the cooldown
-- allows (the cooldown counts from the wind-up start; one wind-up at a time, so a monster never hits twice for one
-- attack). The body turns during the wind-up; the hit waits until the target is in front (landAttack). A23-74 (user
-- 2026-10-07): between swings it steps on to `slot` (its ring slot, SEP.ReachGoal) still facing the target (SEP.Rotate
-- turns AutoRotate off while it is in reach), so chasers of a walking player never pile up behind them.
local function attack(rec, info, now, slot)
	rec._goal = nil -- not "trying to move" (A11-R5): a blocked slot never counts as a stuck chase
	local walk = SEP.ReachGoal(rec, now, rec.Root.Position, slot, info)
	if walk then
		NATURAL.Pace(rec, 1)
		rec._walkTo = walk
		rec.Humanoid:MoveTo(walk)
	else
		rec.Humanoid:MoveTo(rec.Root.Position)
	end
	rec._inReach = true
	FACE.Active[rec] = { Target = info.Player, Until = os.clock() + FACE.Keep }
	if rec._windup ~= nil or now < rec._nextAttackAt then return end
	rec._nextAttackAt = now + MC.AttackCooldown
	local model = rec.Model
	if model then
		model:SetAttribute(WINDUP_AT_ATTR, workspace:GetServerTimeNow())
	end
	local token = {}
	rec._windup = token
	local target = info.Player
	task.delay(REACT.WINDUP, function()
		local ok, err = pcall(landAttack, rec, token, target, 0)
		if not ok then
			if rec._windup == token then rec._windup = nil end -- landAttack threw before clearing it
			warnThrottled("attack", err)
		end
	end)
end

-- A10-V3-2 (c): put the monster back on its home point (sunk in water / cannot walk back)
local function pivotHome(rec)
	local root = rec.Root
	local p = rec.Home + Vector3.new(0, rec._rootOffset or 3, 0)
	local lv = root.CFrame.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
	rec.Model:PivotTo(CFrame.lookAt(p, p + flat.Unit))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	rec.Humanoid:MoveTo(p)
	rec._goal = nil
	rec._stuckAt = nil
	rec._detour = nil
	rec._deepSince = nil
end

-- A10-V3-2 (c): below DEEP_Y for more than DEEP_SECONDS -> PivotTo(Home). Returns true when it teleported.
local function deepRecovery(rec, pos, now)
	if pos.Y >= DEEP_Y then
		rec._deepSince = nil
		return false
	end
	if rec._deepSince == nil then
		rec._deepSince = now
		return false
	end
	if now - rec._deepSince > DEEP_SECONDS then
		pivotHome(rec)
		return true
	end
	return false
end

-- A11-R5: true when the monster moved < STUCK_MIN_MOVE during the last STUCK_WINDOW s while trying to move
local function isStuck(rec, pos, now, trying)
	if not trying then
		rec._stuckAt = nil
		return false
	end
	if rec._stuckAt == nil then
		rec._stuckAt, rec._stuckPos = now, pos
		return false
	end
	if now - rec._stuckAt < STUCK_WINDOW then return false end
	local moved = Util.FlatDistance(pos, rec._stuckPos)
	rec._stuckAt, rec._stuckPos = now, pos
	return moved < STUCK_MIN_MOVE
end

-- A11-R5: a short sideways detour (8-14 studs, 60-150 deg off the blocked direction) on walkable ground in the zone
local function startDetour(rec, zone, pos, goal, now)
	local to = goal and Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z) or Vector3.zero
	local baseAng = to.Magnitude > 0.01 and math.atan2(to.Z, to.X) or Util.Random:NextNumber(0, math.pi * 2)
	for _ = 1, DETOUR_TRIES do
		local side = Util.Random:NextNumber() < 0.5 and -1 or 1
		local a = baseAng + side * Util.Random:NextNumber(math.rad(60), math.rad(150))
		local r = Util.Random:NextNumber(DETOUR_MIN, DETOUR_MAX)
		local p = clampToZone(zone, Vector3.new(pos.X + math.cos(a) * r, pos.Y, pos.Z + math.sin(a) * r))
		local g, noHit = groundPoint(p.X, p.Z)
		if noHit then g = p end
		if g and Util.FlatDistance(g, pos) > ARRIVE_DIST then
			rec._detour = g
			rec._detourUntil = now + DETOUR_SECONDS
			return
		end
	end
	rec._detour = nil
end

-- every non-personal MoveTo goes through here; `dest` is already clamped into the zone (A10-V3-2 b)
local function steer(rec, dest, pos, now, pace)
	local d = rec._detour
	if d then
		if now < rec._detourUntil and Util.FlatDistance(pos, d) > ARRIVE_DIST then
			dest = d
		else
			rec._detour = nil
		end
	end
	local f = FACE.Active[rec]
	if f and f.Point then FACE.Active[rec] = nil end -- NATURAL: a look-around never fights the walk
	pace = pace or 1
	NATURAL.Pace(rec, pace, pace < 1 and dest or nil) -- eases in; a wander also slows near its goal
	rec._goal = dest
	rec._walkTo = dest -- A23-74: SEP.Walk
	rec.Humanoid:MoveTo(dest)
end

-- wander point within WANDER_RADIUS of Home, clamped into the zone and on walkable ground (never water / ridge)
local function pickWanderPoint(rec, zone)
	for _ = 1, WANDER_TRIES do
		local a = Util.Random:NextNumber(0, math.pi * 2)
		local r = Util.Random:NextNumber(0, WANDER_RADIUS)
		local p = clampToZone(zone, rec.Home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
		local g, noHit = groundPoint(p.X, p.Z)
		if g then return g end
		if noHit then return p end -- bare test place without Terrain / Map.Ground: legacy flat behaviour
	end
	return nil
end

------------------------------------------------------------------ A23-113 ① big landings (Config.BossLeap)
-- Clients draw the circle (LandShadow) and the fall (Fx dropLift) from the model attributes; the server only decides who
-- is hit when it lands: a valid target inside DropRadius - Grace of DropPos (LEAP.Victim). rec._leap = the landing under
-- way { Token, Spot, Radius, Mult, Slam } (its token also sits in rec._windup, so no swing starts meanwhile).
local LEAP = {}

function LEAP.Num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

-- the kind's landing rule (Config.BossLeap.Kinds[kind]); nil = plain swings
function LEAP.Of(rec)
	local B = Config.BossLeap
	if type(B) ~= "table" or B.Enabled == false or type(B.Kinds) ~= "table" then return nil end
	local L = B.Kinds[rec.Kind]
	return (type(L) == "table" and L.Enabled ~= false) and L or nil
end

-- s from one leap's start to the next (never shorter than its warning)
function LEAP.Cycle(L)
	return math.max(LEAP.Num(L.Warn, 1) + 0.1, LEAP.Num(L.Cycle, MC.AttackCooldown))
end

-- x the plain hit: L.Mult, else a leap's Cycle / AttackCooldown (standing still costs what the swings did), a slam 1
function LEAP.Mult(L)
	local m = LEAP.Num(L.Mult, nil)
	if m then return math.max(0, m) end
	if L.Mode == "Slam" then return 1 end
	return LEAP.Cycle(L) / math.max(0.1, MC.AttackCooldown)
end

-- studs of the circle: Config.LandShadow.Radius[kind] (else Default) + what a personal King grew after misses
function LEAP.Radius(rec)
	local LS = type(Config.LandShadow) == "table" and Config.LandShadow or {}
	local radii = type(LS.Radius) == "table" and LS.Radius or {}
	local r = LEAP.Num(radii[rec.Kind], nil) or LEAP.Num(radii.Default, 10)
	return math.clamp(r + math.max(0, LEAP.Num(rec._leapExtra, 0)), LEAP.Num(LS.MinRadius, 3), LEAP.Num(LS.MaxRadius, 40))
end

-- one player when it lands: alive, the root within the circle (flat; YRange up / down) and a target it may hit (a
-- personal monster: its owner out of towns and water; else targetable: a boss's new-player rules, towns, zone, water)
function LEAP.Victim(rec, J, p)
	if typeof(p) ~= "Instance" or p.Parent == nil or not Util.IsAlive(p) then return false end
	local root = Util.GetRoot(p)
	if not root then return false end
	local pos = root.Position
	local B = type(Config.BossLeap) == "table" and Config.BossLeap or {}
	if Util.FlatDistance(pos, J.Spot) > math.max(0, J.Radius - math.max(0, LEAP.Num(B.Grace, 0.5))) then return false end
	if math.abs(pos.Y - J.Spot.Y) > math.max(0, LEAP.Num(B.YRange, 12)) then return false end
	local town = isPlayerInTown(p, pos)
	if rec.Owner then return p == rec.Owner and pos.Y >= OUT_Y and not town end
	return targetable(rec, { Player = p, Pos = pos, Town = town, Zone = Config.ZoneAt(pos).Id })
end

-- the landing: every victim once (a personal King's service strike(rec, player, Mult), else the plain hit x Mult); a
-- personal King that hit nobody grows its next circle by LeapGrow (up to LeapGrowMax more). Returns how many were hit
function LEAP.Land(rec, token)
	local J = rec._leap
	if type(J) ~= "table" or J.Token ~= token then return 0 end
	rec._leap = nil
	if rec._windup == token then rec._windup = nil end
	if not rec.Alive or records[rec.Id] ~= rec then return 0 end
	local model = rec.Model
	if not model or not model.Parent then return 0 end
	if J.Slam then
		local seq = model:GetAttribute(ATTACK_SEQ_ATTR)
		model:SetAttribute(ATTACK_SEQ_ATTR, (type(seq) == "number" and seq or 0) + 1) -- the swing clients play
	end
	local n = 0
	for _, p in Players:GetPlayers() do
		if LEAP.Victim(rec, J, p) then
			n += 1
			local ok, err = true, nil
			if rec._strike then
				ok, err = pcall(rec._strike, rec, p, J.Mult)
			elseif S and S.CombatService then
				ok, err = pcall(S.CombatService.DamagePlayer, p, (tonumber(rec.Def.Damage) or 1) * J.Mult, nil, false, rec.Kind)
			end
			if not ok then warnThrottled("leapHit", err) end
		end
	end
	if n == 0 and LEAP.Num(rec._leapGrow, 0) > 0 then
		rec._leapExtra = math.min(math.max(0, LEAP.Num(rec._leapGrowMax, 0)), LEAP.Num(rec._leapExtra, 0) + rec._leapGrow)
	end
	return n
end

-- starts a landing at `info` (Leap: onto the ground where it stands, the body moves there now; Slam: around itself).
-- false = no walkable ground there (in its zone) this time: it tries again RetryDelay s later
function LEAP.Start(rec, info, now, L)
	local root, model = rec.Root, rec.Model
	if not root or not root.Parent or not model or not model.Parent then return false end
	local B = type(Config.BossLeap) == "table" and Config.BossLeap or {}
	local slam = L.Mode == "Slam"
	local from = root.Position - Vector3.new(0, rec._rootOffset or 3, 0)
	local spot = from
	if not slam then
		local g, noHit = groundPoint(info.Pos.X, info.Pos.Z, L.MaxY)
		if noHit then g = Vector3.new(info.Pos.X, from.Y, info.Pos.Z) end -- bare test place: flat ground
		if not g or (rec.Owner == nil and Config.ZoneAt(g).Id ~= rec.ZoneId) then
			rec._nextAttackAt = now + math.max(0.1, LEAP.Num(B.RetryDelay, 0.5))
			return false
		end
		spot = g
	end
	local warn = math.clamp(LEAP.Num(L.Warn, 1), 0.3, 3)
	local token = {}
	local J = { Token = token, Spot = spot, Radius = LEAP.Radius(rec), Mult = LEAP.Mult(L), Slam = slam }
	rec._windup, rec._leap = token, J
	rec._nextAttackAt = now + (slam and MC.AttackCooldown or LEAP.Cycle(L))
	model:SetAttribute("DropPos", spot)
	model:SetAttribute("DropRadius", J.Radius)
	model:SetAttribute("DropTime", warn)
	model:SetAttribute("DropFrom", slam and spot or from)
	model:SetAttribute("DropHeight", slam and 0 or math.max(0, LEAP.Num(L.Height, 12)))
	model:SetAttribute("DropAt", Util.Now()) -- last: a new value = a new circle (LandShadow) and a new fall (Fx)
	if not slam then
		-- the body stands on the spot at once; clients draw it in the air above it, falling over DropTime
		local p = spot + Vector3.new(0, rec._rootOffset or 3, 0)
		local flat = Vector3.new(spot.X - from.X, 0, spot.Z - from.Z)
		if flat.Magnitude < 0.01 then
			local lv = root.CFrame.LookVector
			flat = Vector3.new(lv.X, 0, lv.Z)
		end
		if flat.Magnitude < 0.01 then flat = Vector3.new(0, 0, -1) end
		model:PivotTo(CFrame.lookAt(p, p + flat.Unit))
		root.AssemblyLinearVelocity = Vector3.zero
		rec.Humanoid:MoveTo(p)
		rec._goal, rec._walkTo, rec._stuckAt = nil, nil, nil
	end
	task.delay(warn, function()
		local ok, err = pcall(LEAP.Land, rec, token)
		if not ok then
			if type(rec._leap) == "table" and rec._leap.Token == token then rec._leap = nil end
			if rec._windup == token then rec._windup = nil end
			warnThrottled("leap", err)
		end
	end)
	return true
end

-- one AI step with a target `d` studs away: true when the landing rules took it (a landing started, or a leaper in reach
-- standing between leaps: it never swings); false = the plain chase / swing goes on (a slam counts that swing)
function LEAP.Try(rec, info, d, now)
	local L = LEAP.Of(rec)
	if not L then return false end
	local ready = rec._windup == nil and now >= rec._nextAttackAt
	if L.Mode == "Slam" then
		if not ready or d > MC.AttackRange then return false end
		rec._slamCount = (rec._slamCount or 0) + 1
		if rec._slamCount % math.max(1, math.floor(LEAP.Num(L.Every, 3))) ~= 0 then return false end
		return LEAP.Start(rec, info, now, L)
	end
	if d > LEAP.Num(L.Range, 14) then return false end
	if ready and LEAP.Start(rec, info, now, L) then return true end
	if d > MC.AttackRange then return false end -- between leaps out of reach: it walks closer
	rec.Humanoid:MoveTo(rec.Root.Position)
	FACE.Active[rec] = { Until = os.clock() + FACE.Keep, Target = info.Player } -- (its own line: test_halloween anchors on attack()'s)
	return true
end

------------------------------------------------------------------ A23-74 spacing (user 2026-10-07 "점점 합쳐지겠다")
function SEP.Key(cx, cz)
	return cx * 65536 + cz
end

-- a boss (the Pumpkin King, the Ghost King) is never slid aside
function SEP.Fixed(rec)
	return type(rec.Def) == "table" and rec.Def.Boss == true
end

-- chase ring: centre distance from the target player at which this monster stands (outside the player's body, in reach)
function SEP.Ring(rec)
	local r = rec._radius or SEP.Radius.Slime
	return math.min(MC.AttackRange - SEP.RingInside, r + SEP.PlayerRadius + SEP.RingGap)
end

-- smallest angle between ring neighbours a and b ({ R = ring, Rad = body radius }) so their bodies do not meet
function SEP.Gap(a, b)
	return 2 * math.asin(math.min(1, (a.Rad + b.Rad) / math.max(0.01, a.R + b.R)))
end

-- ring order: by angle, ties by id (Need and Spread must see the same neighbours)
function SEP.Before(a, b)
	if a.A ~= b.A then return a.A < b.A end
	return a.Id < b.Id
end

-- total angle a ring of `list` needs (the order of `list` is left alone)
function SEP.Need(list)
	if #list < 2 then return 0 end
	local sorted = table.clone(list)
	table.sort(sorted, SEP.Before)
	local sum = 0
	for i = 1, #sorted do
		sum += SEP.Gap(sorted[i], sorted[i % #sorted + 1])
	end
	return sum
end

-- pool adjacent violators on an unrolled run of angles: crowded neighbours merge into blocks packed exactly SEP.Gap
-- apart, each block centred on its members' own angles (the least total movement); the order never changes
function SEP.Pack(line)
	local blocks = {}
	for k, e in line do
		e.Off = 0
		local top = { First = k, Last = k, Sum = e.A, N = 1 } -- Sum / N = the block's start angle
		while #blocks > 0 do
			local prev = blocks[#blocks]
			local gap = SEP.Gap(line[prev.Last], line[top.First])
			if top.Sum / top.N - (prev.Sum / prev.N + line[prev.Last].Off) >= gap then break end
			local shift = line[prev.Last].Off + gap
			for j = top.First, top.Last do line[j].Off += shift end
			prev.Sum += top.Sum - top.N * shift
			prev.N += top.N
			prev.Last = top.Last
			table.remove(blocks)
			top = prev
		end
		table.insert(blocks, top)
	end
	for _, b in blocks do
		for j = b.First, b.Last do line[j].A = b.Sum / b.N + line[j].Off end
	end
end

-- spread the ring angles A of `list` (in place) so neighbours are SEP.Gap apart, each moving as little as possible and
-- the order kept: cut the circle after the neighbour pair with the most room, Pack the run; while the seam is still too
-- tight, cut again at the new widest room (each such pass merges the blocks across the old seam, so it ends within n
-- passes whenever SEP.Need <= 2 pi)
function SEP.Spread(list)
	local n = #list
	if n < 2 then return end
	local tau = 2 * math.pi
	table.sort(list, SEP.Before)
	local line = list
	for _ = 1, n do
		local cut, most = n, -math.huge
		for i = 1, n do
			local a, b = line[i], line[i % n + 1]
			local room = b.A - a.A + (i == n and tau or 0) - SEP.Gap(a, b)
			if room > most then cut, most = i, room end
		end
		local run = {}
		for k = 1, n do
			local idx = cut + k
			if idx > n then
				idx -= n
				line[idx].A += tau -- past the cut: one turn on
			end
			run[k] = line[idx]
		end
		SEP.Pack(run)
		line = run
		if line[1].A + tau - line[n].A >= SEP.Gap(line[n], line[1]) - 1e-6 then break end
	end
	for _, e in line do
		e.A = (e.A + math.pi) % tau - math.pi
	end
end

-- A23-74 review 2026-10-08 (zone edge): the rect a zone monster's MoveTo points and slides stay in (its zone rect inset
-- ZONE_MOVE_INSET, A10-V3-2 b) as { X0, X1, Z0, Z1 }, grown to take in the points given (a body already past the line
-- slides along it or back in, never further out); nil for a personal monster (it follows its owner anywhere)
function SEP.Box(rec, ...)
	if rec.Owner ~= nil then return nil end
	local zone = Config.Zones[rec.ZoneId]
	if not zone then return nil end
	local hx = math.max(0, zone.Size.X / 2 - ZONE_MOVE_INSET)
	local hz = math.max(0, zone.Size.Z / 2 - ZONE_MOVE_INSET)
	local box = { X0 = zone.Center.X - hx, X1 = zone.Center.X + hx, Z0 = zone.Center.Z - hz, Z1 = zone.Center.Z + hz }
	for _, at in { ... } do
		box.X0, box.X1 = math.min(box.X0, at.X), math.max(box.X1, at.X)
		box.Z0, box.Z1 = math.min(box.Z0, at.Z), math.max(box.Z1, at.Z)
	end
	return box
end

-- A23-74 review 2026-10-08 (zone edge): the part of the ring of radius r around (cx, cz) inside box, as the angles
-- { A0, A1 } (A0 < A1; the longest piece when the box cuts the ring more than once); nil when the whole ring is inside
-- (or no box), false when none of it is. Each side the ring crosses cuts out the arc around that side's outward
-- direction (half width acos(distance to the side / r)); the cuts are laid out from a point none of them covers, so a
-- cut across 0 never hides another one.
function SEP.Arc(cx, cz, r, box)
	if box == nil then return nil end
	local dx1, dx0, dz1, dz0 = box.X1 - cx, cx - box.X0, box.Z1 - cz, cz - box.Z0
	if r <= dx1 and r <= dx0 and r <= dz1 and r <= dz0 then return nil end
	local tau = 2 * math.pi
	local dirs, cuts = { 0, math.pi, math.pi / 2, -math.pi / 2 }, {} -- each side's outward direction
	for i, dist in { dx1, dx0, dz1, dz0 } do
		if dist <= -r then return false end
		if dist < r then
			local hw = math.acos(dist / r)
			table.insert(cuts, { S = dirs[i] - hw, L = 2 * hw })
		end
	end
	local start = nil -- the end of a cut no other cut covers (none: together they cover the ring)
	for _, c in cuts do
		local e = c.S + c.L
		local covered = false
		for _, o in cuts do
			local at = (e - o.S) % tau
			if at > 1e-9 and at < o.L - 1e-9 then covered = true end
		end
		if not covered then
			start = e
			break
		end
	end
	if start == nil then return false end
	for _, c in cuts do
		c.S = (c.S - start) % tau
		if c.S > tau - 1e-9 then c.S = 0 end
	end
	table.sort(cuts, function(a, b) return a.S < b.S end)
	local a0, a1, reach = nil, nil, 0 -- reach: how far the cuts so far go (the last one ends at the start: no gap there)
	for _, c in cuts do
		if c.S > reach and (a0 == nil or c.S - reach > a1 - a0) then a0, a1 = reach, c.S end
		reach = math.max(reach, c.S + c.L)
	end
	if a0 == nil then return false end
	return { A0 = a0 + start, A1 = a1 + start }
end

-- the angles inside the box the members of a ring (entries with R) all have: the overlap of their SEP.Arc pieces (each
-- taken within pi of the first one's middle; `known` keeps the pieces per radius for this player's rings); nil = the
-- whole ring for every member, false = none
function SEP.RingArc(ring, cx, cz, box, known)
	if box == nil then return nil end
	known = known or {}
	local a0, a1, ref = -math.huge, math.huge, nil
	for _, e in ring do
		local piece = known[e.R]
		if piece == nil then
			piece = { SEP.Arc(cx, cz, e.R, box) }
			known[e.R] = piece
		end
		local arc = piece[1]
		if arc == false then return false end
		if arc then
			local mid = (arc.A0 + arc.A1) / 2
			ref = ref or mid
			local shift = (mid - ref + math.pi) % (2 * math.pi) - math.pi - (mid - ref)
			a0, a1 = math.max(a0, arc.A0 + shift), math.min(a1, arc.A1 + shift)
		end
	end
	if ref == nil then return nil end
	if a1 <= a0 then return false end
	return { A0 = a0, A1 = a1 }
end

-- the run of `list` along arc: its members (copies when `copy`) with their angles moved by whole turns to within pi of
-- the arc's middle (the cut lies opposite, outside the arc), in order; and the angles A0..A1 the run may use: the arc,
-- narrowed at both ends when its ends lie closer around the back than the last and the first member need (a long arc)
function SEP.Run(list, arc, copy)
	local mid, tau = (arc.A0 + arc.A1) / 2, 2 * math.pi
	local run = {}
	for _, e in list do
		local m = copy and { Id = e.Id, R = e.R, Rad = e.Rad } or e
		m.A = mid + (e.A - mid + math.pi) % tau - math.pi
		table.insert(run, m)
	end
	table.sort(run, SEP.Before)
	local a0, a1 = arc.A0, arc.A1
	if #run > 1 then
		local short = SEP.Gap(run[#run], run[1]) - (tau - (a1 - a0))
		if short > 0 then a0, a1 = a0 + short / 2, a1 - short / 2 end
	end
	return run, a0, a1
end

-- true when the members of `list` fit on their ring: the whole ring (arc nil, SEP.Need <= 2 pi), or inside the arc
-- (the n - 1 SEP.Gap between neighbours along SEP.Run within its angles); never on a ring with no room (false). The list
-- is left alone.
function SEP.Fits(list, arc)
	if arc == nil then return SEP.Need(list) <= 2 * math.pi end
	if arc == false then return false end
	local run, a0, a1 = SEP.Run(list, arc, true)
	local need = 0
	for k = 2, #run do need += SEP.Gap(run[k - 1], run[k]) end
	return need <= a1 - a0
end

-- spread the angles A of `list` (in place) inside arc, like SEP.Spread on the whole ring: order kept, neighbours SEP.Gap
-- apart, each moving as little as possible (SEP.Pack on the run), then the run moved inside its angles (SEP.Run; needs
-- SEP.Fits)
function SEP.SpreadArc(list, arc)
	local run, a0, a1 = SEP.Run(list, arc, false)
	SEP.Pack(run)
	local total = 0
	for k = 2, #run do total += SEP.Gap(run[k - 1], run[k]) end
	local before = 0
	for k, e in run do
		if k > 1 then before += SEP.Gap(run[k - 1], e) end
		e.A = math.max(a0 + before, math.min(a1 - (total - before), e.A))
	end
	for _, e in run do
		e.A = (e.A + math.pi) % (2 * math.pi) - math.pi
	end
end

-- slots for the chasers of one player, closest first. The inner ring (in reach) stands at each one's own ring (r + 1 + 1);
-- A23-74 review: when they do not all fit there, it moves out to the widest ring still in reach (AttackRange -
-- RingInside, more of them can attack). Whoever does not fit waits on the next ring, just outside the bodies of the ring
-- before it (RingGap between), and so on: any number of chasers gets a slot that touches no other. Review 2026-10-08
-- (zone edge): the rings are taken around where the player will be (SEP.Ahead, like SEP.Goal) and only their part
-- inside the zone's move line counts (SEP.RingArc): near the edge fewer fit on a ring and the rest wait on the next
-- ones, every slot inside the line (before, slots past it were clamped onto the line and piled up there). A ring with
-- no room inside the line keeps its closest one, whose slot aiStep clamps onto the line; the next ring starts outside
-- that clamped spot (at a corner or ahead of a running player it can lie far beyond its ring). A personal monster
-- follows its owner anywhere, so a player with one among its chasers gets whole rings (the old clamp for the others).
function SEP.Surround(info, chasers)
	local p = info.Pos
	local rest = {}
	local box, personal = nil, false -- the zone's move rect (a player's zone monsters all share its zone)
	for _, rec in chasers do
		local pos = rec._sepPos
		local d = Util.FlatDistance(pos, p)
		if rec.Owner ~= nil and d > PERSONAL_FOLLOW_RADIUS then continue end -- a personal monster too far: it stands
		table.insert(rest, { Rec = rec, Id = rec.Id, D = d, A = math.atan2(pos.Z - p.Z, pos.X - p.X), R = SEP.Ring(rec),
			Rad = rec._radius or SEP.Radius.Slime })
		if rec.Owner ~= nil then personal = true else box = box or SEP.Box(rec) end
	end
	if personal then box = nil end
	table.sort(rest, function(a, b)
		if a.D ~= b.D then return a.D < b.D end
		return a.Id < b.Id
	end)
	local cx, cz = SEP.Ahead(info)
	local known = {} -- SEP.Arc pieces per ring radius
	local edge, inner = 0, true
	while #rest > 0 do
		local ring = rest
		rest = {}
		if inner then
			if not SEP.Fits(ring, SEP.RingArc(ring, cx, cz, box, known)) then
				for _, e in ring do e.R = MC.AttackRange - SEP.RingInside end
			end
		else
			for _, e in ring do e.R = edge + SEP.RingGap + e.Rad end
		end
		local arc = SEP.RingArc(ring, cx, cz, box, known)
		while #ring > 1 and not SEP.Fits(ring, arc) do
			table.insert(rest, 1, table.remove(ring)) -- the farthest waits on the next ring (rest stays closest first)
			arc = SEP.RingArc(ring, cx, cz, box, known)
		end
		if arc == nil then
			SEP.Spread(ring)
		elseif arc then
			SEP.SpreadArc(ring, arc)
		end
		for _, e in ring do
			local r = e.R
			if arc == false then -- no room inside the line: where aiStep's clamp puts its slot
				local x = math.clamp(cx + math.cos(e.A) * r, box.X0, box.X1)
				local z = math.clamp(cz + math.sin(e.A) * r, box.Z0, box.Z1)
				r = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
			end
			edge = math.max(edge, r + e.Rad)
			SEP.Slots[e.Rec] = { Player = info.Player, Angle = e.A, Ring = e.R }
		end
		inner = false
	end
end

-- start of an AI tick: snapshot the living monsters' positions and give every player's chasers (last tick's targets,
-- personal monsters for their owner) their ring slots
function SEP.Begin(list, plist)
	table.clear(SEP.Live)
	table.clear(SEP.Slots)
	local chasers = {}
	for _, rec in list do
		local root = rec.Alive and rec.Root or nil
		if root and root.Parent and not root.Anchored then
			rec._sepPos = root.Position
			rec._walkTo = nil -- this tick's step sets it when it walks (SEP.Walk)
			table.insert(SEP.Live, rec)
			local target = rec.Owner or (not rec._returning and rec._target or nil)
			if target ~= nil then
				chasers[target] = chasers[target] or {}
				table.insert(chasers[target], rec)
			end
		end
	end
	for player, recs in chasers do
		local info = findInfo(plist, player)
		if info then SEP.Surround(info, recs) end
	end
end

-- A23-74 review: where a walking player will be at the next AI tick (info.Vel x Lead s ahead, at most LeadMax studs;
-- without Vel: where it stands). Chase rings and the push out of a player body are centred there, so slots and slides
-- move with the player instead of trailing a tick behind (a pile behind them, the ones ahead walked into).
function SEP.Ahead(info)
	local p, v = info.Pos, info.Vel
	if v == nil then return p.X, p.Z end
	local lead = math.sqrt(v.X * v.X + v.Z * v.Z) * SEP.Lead
	local k = lead > SEP.LeadMax and SEP.LeadMax / lead or 1
	return p.X + v.X * SEP.Lead * k, p.Z + v.Z * SEP.Lead * k
end

-- where a chaser walks: its slot around info's player (else its own side of the player at its ring distance), on the
-- ring centred at SEP.Ahead; a slot on water / a ridge / in solid decor falls back to the player's position (the old
-- chase)
function SEP.Goal(rec, info)
	local p = info.Pos
	local slot = SEP.Slots[rec]
	local angle, ring
	if slot and slot.Player == info.Player then
		angle, ring = slot.Angle, slot.Ring
	else
		local pos = rec.Root.Position
		angle, ring = math.atan2(pos.Z - p.Z, pos.X - p.X), SEP.Ring(rec)
	end
	local cx, cz = SEP.Ahead(info)
	local x, z = cx + math.cos(angle) * ring, cz + math.sin(angle) * ring
	local g, noHit = groundPoint(x, z)
	if g then return g end
	if noHit then return Vector3.new(x, p.Y, z) end
	return p
end

-- A23-74 review: in reach of info's player, the spot it steps to this AI tick, or nil = stand still. It stands while a
-- wind-up is pending, when the cooldown is up (a wind-up starts now), within Settle of its slot, and when the slot fell
-- back into the player body (water / clamped at the zone edge; the body where the player will be, SEP.Ahead: a rear
-- slot of a walking player is close to where it stands now); otherwise it steps on to its slot between swings.
function SEP.ReachGoal(rec, now, pos, slot, info)
	if slot == nil or rec._windup ~= nil or now >= rec._nextAttackAt then return nil end
	if Util.FlatDistance(pos, slot) <= SEP.Settle then return nil end
	local ax, az = SEP.Ahead(info)
	local dx, dz = slot.X - ax, slot.Z - az
	if dx * dx + dz * dz < ((rec._radius or SEP.Radius.Slime) + SEP.PlayerRadius) ^ 2 then return nil end
	return slot
end

-- after each AI step: AutoRotate is off only while the monster is in reach (attack() set _inReach this tick), so FACE
-- alone turns the body to its target, also while it steps sideways to its slot; any other walk faces where it goes
function SEP.Rotate(rec)
	local hum = rec.Humanoid
	local want = rec._inReach ~= true
	rec._inReach = nil
	if hum and hum.Parent and hum.AutoRotate ~= want then hum.AutoRotate = want end
end

-- moves rec's end point for this tick by (x, z) (a Resolve pass; the sum becomes its slide). Review 2026-10-08 (zone
-- edge): the slide (end point - _sepFrom) keeps the body in its box (_sepBox, SEP.Box) all the way from where it stands
-- (_sepPos) to its MoveTo point (_walkTo; its walk end lies between, and a walk that gets there early stops there while
-- the rest of the slide still plays): only the part that would cross the zone's move line is dropped, so the body
-- slides along the line. Returns the dropped part (0, 0 when it all fit) for the other monster of a pair.
function SEP.Add(rec, x, z)
	local at = rec._sepAt
	local nx, nz = at.X + x, at.Z + z
	local box = rec._sepBox
	if box then
		local q, from = rec._sepPos, rec._sepFrom
		local goal = rec._walkTo or q
		local sx, sz = nx - from.X, nz - from.Z
		local cx = math.clamp(sx, box.X0 - math.min(q.X, goal.X), box.X1 - math.max(q.X, goal.X))
		local cz = math.clamp(sz, box.Z0 - math.min(q.Z, goal.Z), box.Z1 - math.max(q.Z, goal.Z))
		if cx ~= sx or cz ~= sz then
			cx = cx ~= sx and from.X + cx or nx
			cz = cz ~= sz and from.Z + cz or nz
			rec._sepAt = Vector3.new(cx, at.Y, cz)
			return nx - cx, nz - cz
		end
	end
	rec._sepAt = Vector3.new(nx, at.Y, nz)
	return 0, 0
end

-- A23-74 review: where a monster's own walk takes it by the end of this AI tick (the point this tick's step sent it to,
-- _walkTo, at its Humanoid's WalkSpeed; standing = where it is). Resolve separates these end points, so a chaser that
-- walks into a monster standing for its swing is held back before the bodies meet, not a tick after.
function SEP.Walk(rec)
	local pos, goal = rec._sepPos, rec._walkTo
	local hum = rec.Humanoid
	if goal == nil or hum == nil then return pos end
	local dx, dz = goal.X - pos.X, goal.Z - pos.Z
	local d = math.sqrt(dx * dx + dz * dz)
	local step = math.min(d, (tonumber(hum.WalkSpeed) or 0) * MC.AIInterval)
	if d < 1e-6 or step <= 0 then return pos end
	return Vector3.new(pos.X + dx * step / d, pos.Y, pos.Z + dz * step / d)
end

-- a pair whose end points are closer than (rA + rB) x Overlap: each end point moves its share of the overlap away from
-- the other (the smaller moves more, a boss never; review 2026-10-08: what one may not take, pinned at the zone's move
-- line, the other takes); true when it moved them
function SEP.Pair(a, b)
	local pa, pb = a._sepAt, b._sepAt
	local ra, rb = a._radius or SEP.Radius.Slime, b._radius or SEP.Radius.Slime
	local need = (ra + rb) * SEP.Overlap
	local dx, dz = pa.X - pb.X, pa.Z - pb.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d >= need then return false end
	local fa, fb = SEP.Fixed(a), SEP.Fixed(b)
	if fa and fb then return false end
	local o -- scale of (dx, dz) that covers the whole overlap
	if d < 0.05 then -- on the same spot: a fixed direction per pair (golden angle of the lower id)
		local ang = (math.min(a.Id, b.Id) * 2.39996) % (2 * math.pi)
		dx, dz, o = math.cos(ang), math.sin(ang), need
		if a.Id > b.Id then dx, dz = -dx, -dz end
	else
		o = (need - d) / d
	end
	local wa = fa and 0 or (fb and 1 or rb / (ra + rb))
	local wb = fb and 0 or (fa and 1 or ra / (ra + rb))
	local rx, rz = SEP.Add(a, dx * o * wa, dz * o * wa)
	if not fb then
		local sx, sz = SEP.Add(b, -dx * o * wb - rx, -dz * o * wb - rz)
		if not fa and (sx ~= 0 or sz ~= 0) then SEP.Add(a, -sx, -sz) end
	end
	return true
end

-- a monster whose end point is closer than (r + PlayerRadius) x Overlap to the player body at (ax, az) (where the
-- player will be, SEP.Ahead) moves out, away from it (a boss never); review 2026-10-08: pinned at the zone's move line
-- it moves along the line out of the body instead (to its own side first, by id when right in line, else the other
-- side); true when it moved
function SEP.Body(rec, ax, az, y)
	local pr = rec._sepAt
	local need = ((rec._radius or SEP.Radius.Slime) + SEP.PlayerRadius) * SEP.Overlap
	local dx, dz = pr.X - ax, pr.Z - az
	local d = math.sqrt(dx * dx + dz * dz)
	if d >= need or math.abs(pr.Y - y) >= 8 or SEP.Fixed(rec) then return false end
	local rx, rz
	if d < 0.05 then -- right on the player: a fixed direction per monster
		local ang = (rec.Id * 2.39996) % (2 * math.pi)
		rx, rz = SEP.Add(rec, math.cos(ang) * need, math.sin(ang) * need)
	else
		rx, rz = SEP.Add(rec, dx * (need - d) / d, dz * (need - d) / d)
	end
	if rx == 0 and rz == 0 then return true end
	local at = rec._sepAt
	local alongZ = rx ~= 0 -- pinned across x: out along z (else along x; in a corner z, the inside has room)
	local across = alongZ and at.X - ax or at.Z - az
	local along = alongZ and at.Z - az or at.X - ax
	local room = need * need - across * across
	if room <= along * along then return true end -- out of the body already
	local side = along > 0 and 1 or (along < 0 and -1 or (rec.Id % 2 == 0 and 1 or -1))
	for _, s in { side, -side } do
		local step = s * math.sqrt(room) - along
		local mx, mz = alongZ and 0 or step, alongZ and step or 0
		local ux, uz = SEP.Add(rec, mx, mz)
		if ux == 0 and uz == 0 then return true end
		SEP.Add(rec, ux - mx, uz - mz) -- that way is blocked too: take back the part it made
	end
	return true
end

-- the slide a monster at `pos` may make of `delta`, or nil: a zone monster in its own zone, kept in its box (SEP.Box
-- grown to take in pos; review 2026-10-08: only the part crossing the zone's move line is dropped, so it slides along
-- the line, where the old check refused the whole slide; with `after`, room is kept past the end for that much more),
-- staying in the zone it stands in, on walkable ground, no wall / decor in the way at body height (the Shove rules)
function SEP.Fit(rec, pos, delta, after)
	local here = Config.ZoneAt(pos).Id
	if rec.Owner == nil and here ~= rec.ZoneId then return nil end
	local box = SEP.Box(rec, pos)
	if box and after then -- room left past the end for `after` (more slide still to come)
		box.X0, box.X1 = box.X0 - math.min(0, after.X), box.X1 - math.max(0, after.X)
		box.Z0, box.Z1 = box.Z0 - math.min(0, after.Z), box.Z1 - math.max(0, after.Z)
	end
	local x, z = pos.X + delta.X, pos.Z + delta.Z
	if box and (x < box.X0 or x > box.X1 or z < box.Z0 or z > box.Z1) then
		delta = Vector3.new(math.max(box.X0, math.min(box.X1, x)) - pos.X, delta.Y,
			math.max(box.Z0, math.min(box.Z1, z)) - pos.Z)
	end
	local m = delta.Magnitude
	if m < 1e-3 then return nil end
	local dest = pos + delta
	if Config.ZoneAt(dest).Id ~= here then return nil end
	local g, noHit = groundPoint(dest.X, dest.Z)
	if not g and not noHit then return nil end
	if workspace:Raycast(pos, delta * ((m + 0.5) / m), getShoveParams()) ~= nil then return nil end
	return delta
end

-- end of an AI tick: where every monster will be at the end of the coming tick (its walk end point, SEP.Walk), up to
-- Passes rounds of moving overlapping end points apart (grid neighbours only; one move can push into a third monster,
-- the next round fixes that) and out of player bodies (where the player will be, SEP.Ahead); each monster's total move
-- becomes its slide, played smoothly by SEP.Step over that tick (at most Speed x AIInterval studs), so no pile builds
-- up behind a walking player. Review 2026-10-08: every slide stays in the monster's box (SEP.Add / SEP.Fit: along the
-- zone's move line, never across it)
function SEP.Resolve(plist)
	local cellSize = SEP.Cell
	table.clear(SEP.Grid)
	for _, rec in SEP.Live do
		local at = SEP.Walk(rec)
		rec._sepAt, rec._sepFrom = at, at
		rec._sepBox = SEP.Box(rec, rec._sepPos, rec._walkTo or rec._sepPos)
		local key = SEP.Key(math.floor(at.X / cellSize), math.floor(at.Z / cellSize))
		local cell = SEP.Grid[key]
		if cell then table.insert(cell, rec) else SEP.Grid[key] = { rec } end
	end
	for _ = 1, SEP.Passes do
		local moved = false
		for _, a in SEP.Live do
			local pa = a._sepFrom
			local cx, cz = math.floor(pa.X / cellSize), math.floor(pa.Z / cellSize)
			for ox = -1, 1 do
				for oz = -1, 1 do
					local cell = SEP.Grid[SEP.Key(cx + ox, cz + oz)]
					if cell then
						for _, b in cell do
							if b.Id > a.Id and SEP.Pair(a, b) then moved = true end
						end
					end
				end
			end
		end
		for _, info in plist do
			local ax, az = SEP.Ahead(info) -- the body where the player will be when this slide ends
			local cx, cz = math.floor(ax / cellSize), math.floor(az / cellSize)
			for ox = -1, 1 do
				for oz = -1, 1 do
					local cell = SEP.Grid[SEP.Key(cx + ox, cz + oz)]
					if cell then
						for _, rec in cell do
							if SEP.Body(rec, ax, az, info.Pos.Y) then moved = true end
						end
					end
				end
			end
		end
		if not moved then break end
	end
	for _, rec in SEP.Live do
		local q, at = rec._sepFrom, rec._sepAt
		local vx, vz = at.X - q.X, at.Z - q.Z
		local m = math.sqrt(vx * vx + vz * vz)
		local root = rec.Root
		if m >= SEP.MinPush and rec.Alive and root and root.Parent and not root.Anchored then
			local pos = root.Position
			if Util.FlatDistance(pos, rec._sepPos) <= 1 then -- not teleported home this tick
				local k = math.min(1, SEP.Speed * MC.AIInterval / m)
				local delta = Vector3.new(vx * k, 0, vz * k)
				for _, part in { 1, 0.5 } do
					local step = SEP.Fit(rec, pos, delta * part)
					if step then
						SEP.Push[rec] = { Delta = step, Done = 0, Time = MC.AIInterval }
						-- a walk ends at its MoveTo point wherever the slide put the body, so that point moves along
						-- (kept in the box too; review 2026-10-08: with room for the slide beyond it, since a walk that
						-- gets there early stops and the rest of the slide still plays)
						local goal = rec._walkTo
						local follow = goal ~= nil and rec.Humanoid and SEP.Fit(rec, Vector3.new(goal.X, pos.Y, goal.Z), step, step)
						if follow then
							rec._walkTo = goal + follow
							rec.Humanoid:MoveTo(rec._walkTo)
						end
						break
					end
				end
			end
		end
	end
end

-- A23-74 review 2026-10-08 (two players side by side): the player a zone monster chases now, or nil: the nearest one it
-- may chase (targetable) within AggroRadius (A10-V3-2 a), but while its current target (rec._target) is still one of
-- those it keeps it for TargetHold s from when it took it (rec._targetAt) and after that unless another is TargetMargin
-- studs closer. Before, a monster between two players standing together switched target (and ring slot) every tick.
-- Review 2026-10-08 (2nd round): after the hold, never a target out of AttackRange while another one is in reach:
-- pushed off its slot (into the other player's body) it stood in that player's reach forever and swung at nobody
-- (aiStep attacks only its target; with players under TargetMargin apart |dA - dB| <= |AB| keeps the margin from ever
-- being met). Review 2026-10-08 (3rd round): only after the hold, though: in a crowd a monster shoved across the reach
-- edge switched A -> B -> A every 0.5 s (its slot jumping each time); now it waits out TargetHold first (at most 2 s
-- idle). `free` (a taunt just ran out, SKL-3): no hold, the nearest one as before.
function SEP.Pick(rec, plist, pos, now, free)
	local best, bestD, cur, curD = nil, nil, nil, nil
	for _, info in plist do
		if targetable(rec, info) then
			local d = Util.FlatDistance(pos, info.Pos)
			if d <= MC.AggroRadius then
				if bestD == nil or d < bestD then best, bestD = info, d end
				if info.Player == rec._target then cur, curD = info, d end
			end
		end
	end
	if not free and cur ~= nil and best ~= cur
		and (now < (rec._targetAt or -math.huge) + SEP.TargetHold
			or (bestD > curD - SEP.TargetMargin and (curD <= MC.AttackRange or bestD > MC.AttackRange))) then
		return cur, curD
	end
	return best, bestD
end

-- every Heartbeat: move each sliding root along its Delta (spread evenly over Time)
function SEP.Step(dt)
	if next(SEP.Push) == nil then return end
	for rec, p in SEP.Push do
		local root = rec.Root
		if not rec.Alive or not root or not root.Parent or root.Anchored then
			SEP.Push[rec] = nil
		else
			local f = math.min(1 - p.Done, dt / p.Time)
			root.CFrame = root.CFrame + p.Delta * f
			p.Done += f
			if p.Done >= 1 - 1e-6 then SEP.Push[rec] = nil end
		end
	end
end

local function personalStep(rec, plist, now, pos)
	local owner = rec.Owner
	if owner.Parent == nil then
		despawn(rec, false)
		return
	end
	local info = findInfo(plist, owner)
	if not info or info.Town or info.Pos.Y < OUT_Y then
		rec.Humanoid:MoveTo(pos) -- sandbag: stand still (also never follow the owner into the water)
		return
	end
	local d = Util.FlatDistance(pos, info.Pos)
	if d <= PERSONAL_FOLLOW_RADIUS and not rec._spotted then
		rec._spotted = true
		MonsterService.Moment:Fire(rec, "Spot") -- ③ barks: it goes for its owner (the tutorial golden slime's line)
	end
	if d <= PERSONAL_FOLLOW_RADIUS and LEAP.Try(rec, info, d, now) then return end -- A23-113 ①: the personal King leaps
	if d > PERSONAL_FOLLOW_RADIUS then
		rec.Humanoid:MoveTo(pos)
	elseif d <= MC.AttackRange then
		attack(rec, info, now, SEP.Goal(rec, info)) -- A23-74: between swings it keeps to its ring slot
	else
		rec._walkTo = SEP.Goal(rec, info) -- A23-74: its ring slot, never into the player
		rec.Humanoid:MoveTo(rec._walkTo)
	end
end

------------------------------------------------------------------ A23-87 new kinds (ranged shots, flower ambush, partners)
-- Kid-safe ranged (검수 2026-10-09): a slow, big, telegraphed shot at where the target stood at the release; stepping
-- aside dodges it; only that target can be hit, with the same town / zone / water / new-player rules as a swing. The
-- client draws the shot from Fx "MonsterShot" { Id, Kind, From, To, Speed, Radius, Travel } (game dev 1).
MOB3.Serial = 0

function MOB3.Ranged(rec)
	local r = type(rec.Def) == "table" and rec.Def.Ranged or nil
	return type(r) == "table" and r or nil
end

local function num3(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

-- where a ranged monster stands: Stand studs from the target on its own side (flat)
function MOB3.StandGoal(pos, tpos, stand)
	local d = Vector3.new(pos.X - tpos.X, 0, pos.Z - tpos.Z)
	if d.Magnitude < 0.01 then d = Vector3.new(1, 0, 0) end
	return Vector3.new(tpos.X, pos.Y, tpos.Z) + d.Unit * math.max(0, num3(stand, 15))
end

-- the target's position when it may still be shot by rec (alive, in the world, within `reach`, a valid target), else nil
function MOB3.TargetPos(rec, target, reach)
	if not rec.Alive or records[rec.Id] ~= rec or rec._returning then return nil end
	local model, root = rec.Model, rec.Root
	if not model or not model.Parent or not root or not root.Parent or root.Anchored then return nil end
	if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent == nil or not Util.IsAlive(target) then
		return nil
	end
	local troot = Util.GetRoot(target)
	if not troot then return nil end
	local tpos = troot.Position
	if reach and Util.FlatDistance(root.Position, tpos) > reach then return nil end
	local seen = { Player = target, Pos = tpos, Town = isPlayerInTown(target, tpos), Zone = Config.ZoneAt(tpos).Id }
	if not targetable(rec, seen) then return nil end
	return tpos
end

-- in range: stand still facing the target, wind up (WindupAt, as a swing) when the cooldown allows
function MOB3.Shoot(rec, info, now)
	local R = MOB3.Ranged(rec)
	rec._goal = nil
	rec.Humanoid:MoveTo(rec.Root.Position)
	rec._inReach = true -- standing to shoot
	FACE.Active[rec] = { Until = os.clock() + FACE.Keep, Target = info.Player }
	if rec._windup ~= nil or now < rec._nextAttackAt then return end
	rec._nextAttackAt = now + math.max(0.5, num3(R.Cooldown, 3))
	if rec.Model then rec.Model:SetAttribute(WINDUP_AT_ATTR, workspace:GetServerTimeNow()) end
	local token = {}
	rec._windup = token
	local target = info.Player
	task.delay(math.max(0.1, num3(R.Windup, 0.9)), function()
		local ok, err = pcall(MOB3.Release, rec, token, target)
		if not ok then
			if rec._windup == token then rec._windup = nil end
			warnThrottled("shot", err)
		end
	end)
end

-- the release: the shot flies to where the target stands now (a miss when it moved out of range meanwhile)
function MOB3.Release(rec, token, target)
	if rec._windup ~= token then return end
	rec._windup = nil
	local R = MOB3.Ranged(rec)
	local tpos = R and MOB3.TargetPos(rec, target, num3(R.Range, 20) + REACT.WINDUP_LEEWAY)
	if not tpos then return end
	local from = rec.Root.Position
	local travel = Util.FlatDistance(from, tpos) / math.max(1, num3(R.Speed, 18))
	local seq = rec.Model:GetAttribute(ATTACK_SEQ_ATTR)
	rec.Model:SetAttribute(ATTACK_SEQ_ATTR, (type(seq) == "number" and seq or 0) + 1)
	MOB3.Serial += 1
	MOB3.Net = MOB3.Net or require(ReplicatedStorage.Shared.Net)
	local ok, err = pcall(MOB3.Net.Fx, nil, "MonsterShot", { Id = MOB3.Serial, Kind = rec.Kind, From = from, To = tpos,
		Speed = num3(R.Speed, 18), Radius = num3(R.Radius, 3), Travel = travel })
	if not ok then warnThrottled("shot_fx", err) end
	task.delay(travel, function()
		local okL, errL = pcall(MOB3.Land, rec, target, tpos)
		if not okL then warnThrottled("shot", errL) end
	end)
end

-- the landing: the target only, still within Radius of the landing point (flat, Y within 6) and still a valid target
-- (a shot from a monster that died meanwhile still lands: it was already flying)
function MOB3.Land(rec, target, to)
	local R = MOB3.Ranged(rec)
	if not R or typeof(target) ~= "Instance" or target.Parent == nil or not Util.IsAlive(target) then return false end
	local troot = Util.GetRoot(target)
	if not troot then return false end
	local p = troot.Position
	if Util.FlatDistance(p, to) > num3(R.Radius, 3) or math.abs(p.Y - to.Y) > 6 then return false end
	local info = { Player = target, Pos = p, Town = isPlayerInTown(target, p), Zone = Config.ZoneAt(p).Id }
	if not targetable(rec, info) then return false end
	if S and S.CombatService then
		S.CombatService.DamagePlayer(target, rec.Def.Damage, nil, false, rec.Kind)
	end
	return true
end

-- the flower ambush (def.Ambush): hidden = no move, no attack, model attribute Hidden (the client hides the nametag)
function MOB3.Hide(rec)
	rec._hidden = true
	if rec.Model then rec.Model:SetAttribute("Hidden", true) end
end

-- pops out: Hidden off, PopAt = server time (the client: a small sparkle + a 0.4 s pop; no loud sound, no shake)
function MOB3.Show(rec)
	if not rec._hidden then return end
	rec._hidden = nil
	if rec.Model then
		rec.Model:SetAttribute("Hidden", false)
		rec.Model:SetAttribute("PopAt", workspace:GetServerTimeNow())
	end
	MonsterService.Moment:Fire(rec, "Spot")
end

-- true when a hidden monster wakes this tick (a player it may chase within Pop studs)
function MOB3.Wake(rec, plist, pos)
	local A = rec.Def.Ambush
	local pop = math.max(1, num3(type(A) == "table" and A.Pop, 8))
	for _, info in plist do
		if Util.FlatDistance(pos, info.Pos) <= pop and targetable(rec, info) then
			MOB3.Show(rec)
			return true
		end
	end
	return false
end

-- the ground material under a ground point (nil when nothing is hit)
function MOB3.MaterialAt(pt)
	local hit = workspace:Raycast(pt + Vector3.new(0, 4, 0), Vector3.new(0, -10, 0), getGroundParams())
	return hit and hit.Material or nil
end

-- A23-87 spawn spots: Ambush = a normal spawn point standing on Material (Tries draws), PartnerOf = beside (4-8 studs)
-- a living monster of that kind with no partner of this kind within 10 studs. nil = use a normal spawn point.
function MOB3.Spot(def, kind)
	local A = def.Ambush
	if type(A) == "table" then
		local okM, mat = pcall(function() return Enum.Material[A.Material] end)
		if not okM or mat == nil then return nil end
		for _ = 1, math.max(1, math.floor(num3(A.Tries, 12))) do
			local pt = pickSpawnPoint(def, kind)
			if not pt then return nil end
			if MOB3.MaterialAt(pt) == mat then return pt end
		end
		return nil
	end
	local with = def.PartnerOf
	if type(with) ~= "string" then return nil end
	local mates, partners = {}, {}
	for _, r in records do
		if r.Alive and r.Owner == nil and r.Root and r.Root.Parent then
			if r.Kind == with then table.insert(mates, r.Root.Position) end
			if r.Kind == kind then table.insert(partners, r.Root.Position) end
		end
	end
	local zone = Config.Zones[def.Zone]
	for _, m in mates do
		local taken = false
		for _, q in partners do
			if Util.FlatDistance(m, q) <= 10 then taken = true end
		end
		if not taken and zone then
			for _ = 1, 6 do
				local a = Util.Random:NextNumber(0, math.pi * 2)
				local d = Util.Random:NextNumber(4, 8)
				local g = groundPoint(m.X + math.cos(a) * d, m.Z + math.sin(a) * d, nil, def) -- A23-129
				if g and Config.ZoneAt(g).Id == def.Zone and SEP.Clear(g, SEP.RadiusOf(def)) then return g end
			end
		end
	end
	return nil
end

local function aiStep(rec, plist, now)
	local root, hum = rec.Root, rec.Humanoid
	if not root or not root.Parent or not hum or not hum.Parent or not rec.Model or not rec.Model.Parent then
		-- model lost (destroyed externally / fell out of the world)
		local kind, noRespawn = rec.Kind, rec.Owner ~= nil or rec.Event == true
		despawn(rec, false)
		if not noRespawn then scheduleRespawn(kind) end
		return
	end
	local pos = root.Position

	-- A10-V3-2 (c): sunk deep (water, knocked off a cliff) for > 2 s -> back home. Also for personal monsters.
	if deepRecovery(rec, pos, now) then return end

	-- A23-113 ①: in the middle of a landing it stays where it is (a leaper already stands on the spot)
	if rec._leap then
		hum:MoveTo(pos)
		return
	end

	if rec.Owner then
		personalStep(rec, plist, now, pos)
		return
	end

	-- A23-87: a hidden flower slime stays put until a player it may chase comes close (or it is hit)
	if rec._hidden and not MOB3.Wake(rec, plist, pos) then
		hum:MoveTo(pos)
		return
	end

	local zone = Config.Zones[rec.ZoneId]
	local homeDist = Util.FlatDistance(pos, rec.Home)

	-- A10-V3-2 (c): out of its own zone (knockback, slid off) or in the water -> walk home, no re-aggro for 3 s.
	-- If it makes no progress (river bank, cliff) it is put back home.
	if Config.ZoneAt(pos).Id ~= rec.ZoneId or pos.Y < OUT_Y then
		rec._target = nil
		rec._returning = true
		rec._detour = nil
		rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
		if isStuck(rec, pos, now, homeDist > ARRIVE_DIST) then
			pivotHome(rec)
			return
		end
		local homeDest = clampToZone(zone, rec.Home)
		NATURAL.Pace(rec, 1)
		rec._goal = homeDest
		rec._walkTo = homeDest -- A23-74: SEP.Walk
		hum:MoveTo(homeDest)
		return
	end

	-- leash: go home and do not re-aggro for a moment (anti-jitter). (A monster standing in a town is out of its zone
	-- and already handled above.)
	if homeDist > MC.LeashRadius then
		rec._returning = true
		rec._target = nil
		rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
	end

	-- A3-M4 / A10-V3-2 (a): the current target stepped into a town, left this zone or went into the water
	-- -> return home, no re-aggro for 3 s
	if rec._target then
		local tinfo = findInfo(plist, rec._target)
		if not tinfo then
			rec._target = nil
		elseif not targetable(rec, tinfo) then
			rec._target = nil
			rec._returning = true
			rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
		end
	end

	-- A11-R5: stuck on terrain while moving -> pick a different destination
	local trying = rec._goal ~= nil and Util.FlatDistance(pos, rec._goal) > ARRIVE_DIST
	if isStuck(rec, pos, now, trying) then
		if rec._returning then
			startDetour(rec, zone, pos, rec.Home, now)
		elseif rec._target then
			rec._chaseStuck += 1
			if rec._chaseStuck >= CHASE_STUCK_GIVEUP then
				-- the target is unreachable (ridge slope etc.): give up, go home, no re-aggro for a moment
				rec._chaseStuck = 0
				rec._target = nil
				rec._returning = true
				rec._noAggroUntil = math.max(rec._noAggroUntil, now + NO_REAGGRO_SECONDS)
			else
				startDetour(rec, zone, pos, rec._goal, now)
			end
		else
			rec._goal = nil
			rec._detour = nil
			rec._nextWanderAt = now -- wander somewhere else right away
		end
	end

	if rec._returning then
		if homeDist <= RETURN_DONE_DIST or (now >= rec._noAggroUntil and homeDist <= MC.LeashRadius * 0.75) then
			rec._returning = false
		else
			steer(rec, clampToZone(zone, rec.Home), pos, now)
			return
		end
	end

	-- target = nearest alive player within AggroRadius standing in THIS zone, outside towns and water (A10-V3-2 a); the
	-- current one is kept TargetHold s, then against a player only a little closer unless it is out of reach and another
	-- is in reach (SEP.Pick, A23-74 review 2026-10-08);
	-- SKL-3 Taunt: until _tauntUntil the taunter first (while still a valid target)
	local best, bestD = nil, nil
	if rec._tauntUntil and now < rec._tauntUntil then
		local tinfo = findInfo(plist, rec._tauntBy)
		if tinfo and targetable(rec, tinfo) then best, bestD = tinfo, Util.FlatDistance(pos, tinfo.Pos) end
	end
	if best == nil and now >= rec._noAggroUntil then
		-- a taunt that just ran out: a free pick (the nearest, as before SEP.Pick), no hold on the taunter
		local free = rec._tauntUntil ~= nil and now >= rec._tauntUntil and rec._target == rec._tauntBy
		best, bestD = SEP.Pick(rec, plist, pos, now, free)
		if free then rec._tauntUntil, rec._tauntBy = nil, nil end
	end

	if best then
		if rec._target ~= best.Player then
			rec._chaseStuck = 0
			rec._targetAt = now -- SEP.Pick holds a new target TargetHold s
			MonsterService.Moment:Fire(rec, "Spot") -- ③ barks: a new target
		end
		local alerting = NATURAL.Alert(rec, best, bestD, now) -- a new target: stop with a '!' for a moment first
		rec._target = best.Player
		if alerting then return end
		if LEAP.Try(rec, best, bestD, now) then -- A23-113 ①: a big landing (or a leaper between leaps in reach)
			rec._chaseStuck = 0
			return
		end
		local ranged = rec.Def.Ranged -- A23-87: shoots within Range, otherwise walks to Stand studs from the target
		if type(ranged) == "table" then
			if bestD <= (tonumber(ranged.Range) or 20) then
				rec._chaseStuck = 0
				MOB3.Shoot(rec, best, now)
			else
				steer(rec, clampToZone(zone, MOB3.StandGoal(pos, best.Pos, ranged.Stand)), pos, now)
			end
			return
		end
		if bestD <= MC.AttackRange then
			rec._chaseStuck = 0
			attack(rec, best, now, clampToZone(zone, SEP.Goal(rec, best))) -- A23-74: between swings it keeps to its slot
		else
			-- A23-74: walk to its own ring slot around the player (A10-V3-2 b: clamped into the zone); waiting on the
			-- outer ring (the inner one is full) it faces the player
			local goal = clampToZone(zone, SEP.Goal(rec, best))
			steer(rec, goal, pos, now)
			if Util.FlatDistance(pos, goal) <= 1 then
				FACE.Active[rec] = { Target = best.Player, Until = now + FACE.Keep }
			end
		end
		return
	end

	rec._target = nil
	if now >= rec._nextWanderAt then
		rec._nextWanderAt = now + Util.Random:NextNumber(WANDER_MIN, WANDER_MAX)
		local dest = pickWanderPoint(rec, zone)
		if dest then
			rec._detour = nil
			steer(rec, dest, pos, now, NATURAL.WanderPace)
		end
	elseif rec._goal and Util.FlatDistance(pos, rec._goal) > ARRIVE_DIST then
		NATURAL.Pace(rec, NATURAL.WanderPace, rec._goal) -- NATURAL: keeps easing in, slows near the goal
		rec._walkTo = rec._goal -- A23-74: SEP.Walk (still on its way)
	else
		-- A23-74 review 2026-10-08: the last few studs of a wander still walk to its MoveTo point (SEP.Walk / SEP.Add
		-- must know it, or a push near the zone's move line carried the body past it)
		if rec._goal then rec._walkTo = rec._goal end
		NATURAL.Idle(rec, pos, plist, now) -- NATURAL: standing between wanders: look around / glance
	end
end

local function aiTick()
	local now = os.clock()
	local plist = {}
	for _, p in readyPlayers() do
		if p.Parent and Util.IsAlive(p) then
			local root = Util.GetRoot(p)
			if root then
				local pos = root.Position
				-- A23-74: Vel = where a walking player is headed (SEP.Goal centres the chase ring a tick ahead)
				table.insert(plist, { Player = p, Pos = pos, Town = isPlayerInTown(p, pos), Zone = Config.ZoneAt(pos).Id,
					Vel = root.AssemblyLinearVelocity })
			end
		end
	end
	local list = {}
	for _, rec in records do
		table.insert(list, rec)
	end
	-- A23-74: grid + chase slots before the steps, the light slide apart after them
	local okSep, errSep = pcall(SEP.Begin, list, plist)
	if not okSep then warnThrottled("sep", errSep) end
	for _, rec in list do
		if rec.Alive then
			local ok, err = pcall(aiStep, rec, plist, now)
			if not ok then warnThrottled("ai", err) end
			ok, err = pcall(SEP.Rotate, rec) -- A23-74: AutoRotate off only while in reach
			if not ok then warnThrottled("sep", err) end
		end
	end
	if okSep then
		okSep, errSep = pcall(SEP.Resolve, plist)
		if not okSep then warnThrottled("sep", errSep) end
	end
end

------------------------------------------------------------------ density (A3-M2 / A5-C1)
local function reevaluate()
	-- A23-28 HW-13: a seasonal kind whose season just ended goes home (floats up and fades, no rewards); event monsters
	-- (the king) are closed by their own service
	local gone = {}
	for _, rec in records do
		if rec.Alive and rec.Owner == nil and not rec.Event and not Config.MonsterActive(rec.Kind) then
			table.insert(gone, rec)
		end
	end
	for _, rec in gone do despawn(rec, true, true) end
	local zoneCounts = playersPerZone()
	local targets = cappedTargets(zoneCounts) -- CR-L13
	local total = totalNonPersonal()
	for _, kind in Config.MonsterTypeOrder do
		local outside = Config.MonsterOutsideCap(kind) -- add-on seasonal kind: its own target, outside the cap
		local target = targets[kind] or targetCount(kind, zoneCounts)
		local have = aliveCountOf(kind) + (pending[kind] or 0)
		local spawned = 0
		while have < target and (outside or total < GLOBAL_CAP) and spawned < MAX_SPAWNS_PER_KIND_PER_PASS do
			local rec = spawnMonster(kind)
			if not rec then break end
			have += 1
			if not outside then total += 1 end
			spawned += 1
		end
	end
end

------------------------------------------------------------------ lifecycle
function MonsterService.Init(registry)
	S = registry
	getMonstersFolder()
	Util.GetFolder(workspace, "Effects")
	Util.GetFolder(ServerStorage, CUSTOM_FOLDER) -- A1: may stay empty
	if S.PlayerService and S.PlayerService.PlayerLeaving then
		S.PlayerService.PlayerLeaving:Connect(function(player)
			onOwnerLeaving(player)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		onOwnerLeaving(player)
	end)
end

function MonsterService.Start()
	-- A23-74: a monster model left in the place file (saved from a test) never stands among the living ones
	local okSweep, errSweep = pcall(GHOST.Sweep)
	if not okSweep then warnThrottled("ghost", errSweep) end
	for _, id in Config.MonsterTypeOrder do
		print(("[MonsterService] custom model for %s: %s"):format(id, getCustomTemplate(id) and "yes" or "no"))
	end

	local total = 0
	local counts = Config.EffectiveMonsterCounts() -- seasonal kinds only while their season is on
	local capped = 0 -- add-on seasonal kinds (Config.MonsterOutsideCap) do not count toward GLOBAL_CAP
	for _, kind in Config.MonsterTypeOrder do
		local def = Config.MonsterTypes[kind]
		if def then
			local outside = Config.MonsterOutsideCap(kind)
			for _ = 1, counts[kind] or 0 do
				if not outside and capped >= GLOBAL_CAP then break end
				local ok, rec = pcall(spawnMonster, kind)
				if ok and rec then
					total += 1
					if not outside then capped += 1 end
				elseif not ok then
					warnThrottled("spawn_" .. kind, rec)
				end
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(MC.AIInterval)
			local ok, err = pcall(aiTick)
			if not ok then warnThrottled("aiLoop", err) end
		end
	end)
	-- FACE: monsters in reach turn toward their target every frame (only the facing ones are touched)
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(FACE.Step, dt)
		if not ok then warnThrottled("faceLoop", err) end
		local okSep, errSep = pcall(SEP.Step, dt) -- A23-74: the light slides apart
		if not okSep then warnThrottled("sepLoop", errSep) end
	end)

	task.spawn(function()
		while true do
			task.wait(REEVAL_INTERVAL)
			local ok, err = pcall(reevaluate)
			if not ok then warnThrottled("density", err) end
			local okG, errG = pcall(GHOST.Sweep) -- A23-74: no stray copy stays in workspace.Monsters
			if not okG then warnThrottled("ghost", errG) end
		end
	end)

	print("[MonsterService] started")
end

return MonsterService
