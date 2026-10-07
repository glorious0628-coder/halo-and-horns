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

-- ground probing (A11-R1: Include only Terrain, Map.Ground and the Map.Decor "Bridge_*" models)
local GROUND_RAY_TOP = 150 -- above every ridge top
local GROUND_RAY_LENGTH = 320
local GROUND_MIN_Y, GROUND_MAX_Y = -2, 6 -- walkable valley floor (zone ground top is Y = 0); higher = ridge, lower = shore
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

-- A11-R1: ground raycasts only see Terrain, workspace.Map.Ground and the bridge models (rebuilt every few seconds
-- so a late MapBuilder pass is picked up). Water is NOT ignored, so a hit on the sea/river reports Material Water.
local function getGroundParams()
	local now = os.clock()
	if groundParams and now - groundParamsAt < GROUND_PARAMS_REFRESH then return groundParams end
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map then
		local ground = map:FindFirstChild("Ground")
		if ground then table.insert(list, ground) end
		local decor = map:FindFirstChild("Decor")
		if decor then
			for _, c in decor:GetChildren() do
				if string.sub(c.Name, 1, 7) == "Bridge_" then table.insert(list, c) end
			end
		end
	end
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

-- walkable ground point at (x, z) or nil (water, ridge, shore, inside solid decor). Second result: true when the ray
-- hit nothing at all (bare test place without Terrain / Map.Ground), so callers can fall back to the legacy flat Y = 0
-- behaviour.
local function groundPoint(x, z)
	local y, water = probeGround(x, z)
	if y == nil then return nil, true end
	if water or y < GROUND_MIN_Y or y > GROUND_MAX_Y then return nil, false end
	if occupied(x, y, z) then return nil, false end -- CR-L14
	return Vector3.new(x, y, z), false
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
-- forPlayer (optional): only the monsters that player may hit (own personal ones + zone monsters of the zone the
-- player stands in, CR-M5). nil = every alive monster.
function MonsterService.GetMonstersInRadius(position, radius, forPlayer)
	local out = {}
	if typeof(position) ~= "Vector3" or type(radius) ~= "number" then return out end
	local fz = zoneIdOf(forPlayer) -- CR-M5
	for _, rec in records do
		if rec.Alive and visibleTo(rec, forPlayer, fz) then
			local root = rec.Root
			if root and root.Parent and Util.FlatDistance(root.Position, position) <= radius then
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
				if d <= radius then
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

------------------------------------------------------------------ spawn point (A7-1, grounded on Terrain per A10/A11)
-- Returns a point ON the ground (Y = ground height) inside def.Zone, or nil when every try landed on water / a ridge
-- (the density pass retries a few seconds later).
local function pickSpawnPoint(def, kind)
	local zone = Config.Zones[def.Zone]
	if not zone then return nil end
	local inset = MC.SpawnInset
	local anyHit = false
	local function try(pt)
		local g, noHit = groundPoint(pt.X, pt.Z)
		if not noHit then anyHit = true end
		if g and Config.ZoneAt(g).Id == def.Zone then return g end
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
	if not anyHit then
		-- no Terrain / Map.Ground under the zone at all (bare test place): legacy flat ground at Y = 0
		return Util.RandomPointInZone(zone, inset)
	end
	warnThrottled("spawnpoint_" .. def.Zone, "no walkable ground found in " .. def.Zone .. " this pass (water/ridge); retrying later")
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
		point = pickSpawnPoint(def, kind)
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
		-- private
		_fill = rig.Fill,
		_scale = rig.Scale,
		_rootOffset = rig.RootOffset,
		_contributors = {},
		_hits = {}, -- [Player] = own hits (A23-27)
		_dmg = {}, -- [Player] = own damage, overkill excluded (A23-27)
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
	}
	records[rec.Id] = rec
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
	}

	-- CR-M18: every contributor keeps the full personal WarPoints, but one kill adds WarPoints to a faction pool only
	-- once: WarShare = WarPoints / (contributors of that faction) (WarService.AddPoints(player, n, poolN))
	local now = os.clock()
	local eligible, perFaction = {}, {}
	local window = tonumber(def.ContributorWindow) or MC.ContributorWindow -- a miniboss fight is longer
	local minHits = tonumber(def.RewardMinHits) or 0
	local minDamage = (tonumber(def.RewardMinDamageFrac) or 0) * rec.MaxHP
	for p, t in rec._contributors do
		if p.Parent and now - t <= window and (rec._hits[p] or 0) >= minHits and (rec._dmg[p] or 0) >= minDamage then
			local okF, f = pcall(factionOf, p)
			if not okF or type(f) ~= "string" then f = "None" end
			table.insert(eligible, { Player = p, Faction = f })
			perFaction[f] = (perFaction[f] or 0) + 1
		end
	end
	-- sound_gaps B11 (검수 2026-10-07): the UserIds this kill pays, kept on the record (sorted) for HalloweenService's
	-- KingDefeat Fx, which runs after the contributor tables below are cleared
	local paid = {}
	for _, e in eligible do table.insert(paid, e.Player.UserId) end
	table.sort(paid)
	rec.PaidUserIds = paid
	rec._contributors, rec._hits, rec._dmg = {}, {}, {}
	for _, e in eligible do
		local i = table.clone(info)
		i.WarShare = info.WarPoints / math.max(1, perFaction[e.Faction] or 1)
		i.SkillHit = type(rec._skillBy) == "table" and rec._skillBy[e.Player] == true -- story S0: "basic attacks only"
		-- BB38 metrics (TelemetryService: kills together / with a friend): how many earned this kill, and the others
		i.Party, i.Others = #eligible, {}
		for _, o in eligible do
			if o.Player ~= e.Player then table.insert(i.Others, o.Player) end
		end
		MonsterService.MonsterKilled:Fire(e.Player, i)
	end

	deathPop(rec, true)
	if isPersonal then
		removePersonalRef(rec)
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
-- skill cast that hits the same monster again (a field's ticks) counts as one hit of that player (A23-27 RewardMinHits)
function MonsterService.DamageMonster(record, amount, player, crit, castId)
	if type(record) ~= "table" or not record.Alive then return false end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then return false end
	if record.Owner and record.Owner ~= player then return false end -- A5-C2
	-- CR-M5: a zone monster takes no damage from a player standing outside its zone (no HP change, no contribution)
	if record.Owner == nil and player and zoneIdOf(player) ~= record.ZoneId then return false end
	if player then
		record._contributors[player] = os.clock()
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
		record._dmg[player] = (record._dmg[player] or 0) + math.min(amount, math.max(0, record.HP))
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
-- or solid decor); falls back to a normal spawn point of the zone. Returns the record, or nil when no ground was found
-- this time (the caller retries). Otherwise it is a normal zone monster (AI, damage, rewards per contributor).
function MonsterService.SpawnEvent(kind, opts)
	local def = type(kind) == "string" and Config.MonsterTypes[kind] or nil
	if type(def) ~= "table" then return nil end
	if type(opts) ~= "table" then opts = {} end
	local pos = nil
	local near = opts.Near
	if typeof(near) == "Vector3" then
		local radius = math.max(0, tonumber(opts.Radius) or 30)
		for i = 1, SPAWN_TRIES * 2 do
			local a = Util.Random:NextNumber(0, math.pi * 2)
			local d = (i == 1) and 0 or Util.Random:NextNumber(0, radius)
			local x, z = near.X + math.cos(a) * d, near.Z + math.sin(a) * d
			local g, noHit = groundPoint(x, z)
			if noHit then g = Vector3.new(x, 0, z) end -- bare test place: legacy flat ground
			if g and Config.ZoneAt(g).Id == def.Zone then
				pos = g
				break
			end
		end
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

------------------------------------------------------------------ personal monsters (A4 / A5-C2..C4)
function MonsterService.SpawnPersonal(player, monsterId, opts)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent == nil then return nil end
	if type(monsterId) ~= "string" or Config.MonsterTypes[monsterId] == nil then return nil end
	if type(opts) ~= "table" then opts = {} end

	-- one living personal monster of a kind per player: reuse it
	local set = personal[player]
	if set then
		for rec in set do
			if rec.Alive and rec.Kind == monsterId and rec.Model and rec.Model.Parent then
				return rec.Model
			end
		end
	end

	-- ~8 studs in front of the player on walkable ground (then the sides / behind); fallback: the home-zone spawn
	local pos, faceTo
	local root = Util.GetRoot(player)
	if root then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
		local base = root.Position
		for _, ang in { 0, math.pi / 2, -math.pi / 2, math.pi } do
			local c, s = math.cos(ang), math.sin(ang)
			local dir = Vector3.new(flat.X * c - flat.Z * s, 0, flat.X * s + flat.Z * c)
			local p = base + dir * PERSONAL_DISTANCE
			local g, noHit = groundPoint(p.X, p.Z)
			if g then
				pos = g
			elseif noHit then
				pos = Vector3.new(p.X, 0, p.Z) -- bare test place: legacy flat ground
			end
			if pos then break end
		end
		faceTo = base
	end
	if not pos then
		local faction = player:GetAttribute("Faction")
		local zone = Config.Zones[Config.HomeZoneId(type(faction) == "string" and faction or "None")] or Config.Zones.Crossroads
		local p = zone.Spawn + Vector3.new(0, 0, -PERSONAL_DISTANCE)
		local y, water = probeGround(p.X, p.Z)
		pos = Vector3.new(p.X, (y and not water) and y or 0, p.Z)
		faceTo = faceTo or zone.Spawn
	end

	local ok, rec = pcall(spawnMonster, monsterId, {
		Owner = player,
		Golden = opts.Golden == true,
		HP = tonumber(opts.HP),
		Position = pos,
		FaceTo = faceTo,
	})
	if not ok then
		warnThrottled("personal", rec)
		return nil
	end
	if not rec then return nil end

	personal[player] = personal[player] or {}
	personal[player][rec] = true

	task.delay(PERSONAL_LIFETIME, function()
		if rec.Alive then despawn(rec, true) end
	end)
	return rec.Model
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
	if S and S.CombatService then
		S.CombatService.DamagePlayer(target, rec.Def.Damage, nil, false, rec.Kind) -- BB14: the KO screen names the monster
	end
end

-- in reach: stand still, keep facing the target (FACE, every frame) and start a wind-up when the cooldown allows (the
-- cooldown counts from the wind-up start; one wind-up at a time, so a monster never hits twice for one attack). The
-- body turns during the wind-up; the hit waits until the target is in front (landAttack).
local function attack(rec, info, now)
	rec._goal = nil
	rec.Humanoid:MoveTo(rec.Root.Position)
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
	if d > PERSONAL_FOLLOW_RADIUS then
		rec.Humanoid:MoveTo(pos)
	elseif d <= MC.AttackRange then
		attack(rec, info, now)
	else
		rec.Humanoid:MoveTo(info.Pos)
	end
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

	if rec.Owner then
		personalStep(rec, plist, now, pos)
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

	-- target = nearest alive player within AggroRadius standing in THIS zone, outside towns and water (A10-V3-2 a);
	-- SKL-3 Taunt: until _tauntUntil the taunter first (while still a valid target)
	local best, bestD = nil, nil
	if rec._tauntUntil and now < rec._tauntUntil then
		local tinfo = findInfo(plist, rec._tauntBy)
		if tinfo and targetable(rec, tinfo) then best, bestD = tinfo, Util.FlatDistance(pos, tinfo.Pos) end
	end
	if best == nil and now >= rec._noAggroUntil then
		for _, info in plist do
			if targetable(rec, info) then
				local d = Util.FlatDistance(pos, info.Pos)
				if d <= MC.AggroRadius and (bestD == nil or d < bestD) then
					best, bestD = info, d
				end
			end
		end
	end

	if best then
		if rec._target ~= best.Player then
			rec._chaseStuck = 0
			MonsterService.Moment:Fire(rec, "Spot") -- ③ barks: a new target
		end
		local alerting = NATURAL.Alert(rec, best, bestD, now) -- a new target: stop with a '!' for a moment first
		rec._target = best.Player
		if alerting then return end
		if bestD <= MC.AttackRange then
			rec._chaseStuck = 0
			attack(rec, best, now)
		else
			steer(rec, clampToZone(zone, best.Pos), pos, now) -- A10-V3-2 (b)
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
	else
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
				table.insert(plist, { Player = p, Pos = pos, Town = isPlayerInTown(p, pos), Zone = Config.ZoneAt(pos).Id })
			end
		end
	end
	local list = {}
	for _, rec in records do
		table.insert(list, rec)
	end
	for _, rec in list do
		if rec.Alive then
			local ok, err = pcall(aiStep, rec, plist, now)
			if not ok then warnThrottled("ai", err) end
		end
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
