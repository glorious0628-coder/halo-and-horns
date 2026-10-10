-- CombatService.luau : manual class swings, MP skills, damage formulas,
-- player damage / heal, regen and the death pipeline (the ONLY KO entry point).
-- Server-authoritative: clients only send Swing / Release / SetAutoAttack intents.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "CombatService"

local CombatService = {}

------------------------------------------------------------------ public signals (top level)
-- info = { Stacks, Auto, Perfect, Center, Radius, Total, MonstersHit, PlayersHit, Healed = { Player } }
-- (Total = HP really removed, CR-M10; the Release Fx shows the dealt numbers)
CombatService.Released = Util.Signal.new()
-- (victim, amount, attacker) : fired by DamagePlayer only when attacker ~= nil, after the damage.
-- amount = HP actually removed (CR-M10: no overkill; 0 under a ForceField, still fired for the bait log)
CombatService.PlayerDamaged = Util.Signal.new()
-- (victim, by) BB38 metrics: fired with the KO screen's cause (BB14 sendKO: "Player" | "Kaiju" | "Monster" | "Fall" |
-- "Other") once per KO, from the death pipeline
CombatService.KnockedOut = Util.Signal.new()
-- (player, record, killed) A23-68 #5 funnel: a player's hit landed on a monster (a swing, Q or a skill; not a refused
-- hit), fired right after the damage. Handlers must not yield.
CombatService.MonsterHit = Util.Signal.new()

local S = nil

------------------------------------------------------------------ private constants
local MANUAL_GRACE = 0.2 -- a press this close to swing-ready is queued once for network jitter
local MANUAL_QUEUE_RETRIES = 3 -- timer-precision retries for a queued manual swing
local WHIFF_REACH = 12 -- studs in front of the player used as the visual target of a whiffed ranged swing
local LOOP_WARN_INTERVAL = 10 -- seconds between two warnings of the same loop

-- factions that take part in PvP / goose tug (addendum A6: "Neutral" and "None" never do)
local PVP_FACTIONS = { Halo = true, Horns = true }

-- A15 hit feel: every damaged player gets a "Pain" Fx to ALL clients (pain sticker over that player), at most one per
-- victim per PAIN_GAP s; Big = crit or >= BIG_FRACTION of the victim's MaxHealth. Monsters a swing / release lands on
-- are shoved SHOVE_* studs (MonsterService.Shove applies the zone / water / owner rules) SHOVE_DELAY[attack][class] s
-- after the damage, so the slide starts when clients show the hit (contact frame / projectile flight).
-- Config.HitReact, fallbacks.
local HIT_REACT = Config.HitReact or {}
local REACT = {
	PAIN_GAP = HIT_REACT.PainGap or 0.4,
	BIG_FRACTION = HIT_REACT.BigHitFraction or 0.5,
	SHOVE_SWING = HIT_REACT.ShoveSwing or 1.2,
	SHOVE_CRIT = HIT_REACT.ShoveCrit or 1.6,
	SHOVE_RELEASE = HIT_REACT.ShoveRelease or 2,
	SHOVE_DELAY = type(HIT_REACT.ShoveDelay) == "table" and HIT_REACT.ShoveDelay or {},
}

-- review R1 tuning
local TUNE = {
	-- CR-L49: Swing / Release Fx go to the attacker + players whose root is within FxCullDistance + FX_SEND_PAD + the
	-- attack extent of the center (pad >= camera max zoom: 40, kaiju 60; clients cull from the camera)
	FX_CULL = (Config.Visuals and Config.Visuals.FxCullDistance) or 150,
	FX_SEND_PAD = 60,
	-- Approved clips: cosmetic contact/flight only; damage and cooldown still resolve immediately.
	MOTION = {
		Swing = {
			Warrior = { Contact = 0.23 },
			Mage = { Launch = 0.24, Flight = 0.2, Contact = 0.44 },
			Archer = { Launch = 0.22, Flight = 0.15, Contact = 0.37 },
			Punch = { Contact = 0.15 }, -- A23-34 bare hands (every class): a short jab, no projectile
			PetHeadbutt = { Contact = 0.3 }, -- A23-39 pet tamer: the pet reaches its target and bonks it
		},
		Release = {
			Warrior = { Contact = 0.24 },
			Mage = { Launch = 0.35, Contact = 0.35 },
			Archer = { Launch = 0.18, Contact = 0.4 },
			PetDash = { Contact = 0.35 }, -- A23-39 pet tamer: the pet dashes into the area
		},
		-- A23-116 (skills18 §0): the Z / X skills' times (Fx "Skill" ContactDelay / LaunchDelay; SkillService starts a
		-- pull / push at Contact) by class or style (the pet tamer: Config.Tamer.SkillStyle). The Q values for now: each
		-- slot is tuned here (SKILL.Motion)
		Z = {
			Warrior = { Contact = 0.24 },
			Mage = { Launch = 0.35, Contact = 0.35 },
			Archer = { Launch = 0.18, Contact = 0.4 },
			PetDash = { Contact = 0.35 },
		},
		X = {
			Warrior = { Contact = 0.24 },
			Mage = { Launch = 0.35, Contact = 0.35 },
			Archer = { Launch = 0.18, Contact = 0.4 },
			PetDash = { Contact = 0.35 },
		},
	},
	HEALED_MAX = 5, -- A23-116: the Fx Healed signal lists the nearest 5 healed players (the client's heal sparkles)
}

------------------------------------------------------------------ per-player state (session only)
local nextSwingAt = {} -- [Player] = os.clock() when the next manual swing is allowed
local lastManualAt = {} -- [Player] = os.clock() of the last manual attack / skill request (auto combat yields)
local pendingManual = {} -- [Player] = true while one queued manual swing waits for the cooldown
local lastDamagedAt = {} -- [Player] = os.clock() of the last damage of any kind
local lastPvPAttacker = {} -- [Player] = { Player = Player, T = os.clock() }
local lastSource = {} -- BB14: [Player] = { Kind = monster kind | "Kaiju", T = os.clock() } of the last non-player hit
local lastPvPTime = {} -- [Player] = os.clock() of the last PvP damage dealt or received
local painAt = {} -- [Player] = os.clock() of the last "Pain" Fx (A15)
local lastLoopWarn = {} -- [loopName] = os.clock()
local guard = {
	releaseAt = {}, -- accepted skill time; protects direct server calls as well as the remote
	acLogAt = {}, -- CR-H2: [Player] = os.clock() of the last implausible-position log
}

------------------------------------------------------------------ small helpers
local function isPlayer(x)
	return typeof(x) == "Instance" and x:IsA("Player")
end

local function numAttr(player, key, default)
	local v = player:GetAttribute(key)
	if type(v) ~= "number" or v ~= v then
		return default
	end
	return v
end

local function byDist(a, b)
	return a.Dist < b.Dist
end

local function loopWarn(loopName, err)
	local now = os.clock()
	if now - (lastLoopWarn[loopName] or -math.huge) >= LOOP_WARN_INTERVAL then
		lastLoopWarn[loopName] = now
		Util.Warn(TAG, loopName .. ": " .. tostring(err))
	end
end

-- faction(p) = S.FactionService.GetFaction(p)
local function faction(player)
	local f = S.FactionService.GetFaction(player)
	if type(f) ~= "string" then
		return "None"
	end
	return f
end

-- perks = S.FactionService.GetPerks(p) (falls back to the Config table / None)
local function perksOf(player)
	local p = S.FactionService.GetPerks(player)
	if type(p) ~= "table" then
		p = Config.Factions[faction(player)] or Config.Factions.None
	end
	return p
end

-- cls(p) = S.ClassService.GetClassDef(p)
local function cls(player)
	local c = S.ClassService.GetClassDef(player)
	if type(c) ~= "table" then
		c = Config.Classes.Warrior
	end
	return c
end

-- A23-34: the basic attack's shape (Config.AttackProfile): the class row itself with a weapon, the punch when bare-handed
local function attackShape(player, c)
	return Config.AttackProfile((c or cls(player)).Id, numAttr(player, "WeaponTier", 0), faction(player))
end

-- stars(p) = S.PvPService.GetStars(p)
local function stars(player)
	local n = S.PvPService.GetStars(player)
	if type(n) ~= "number" then
		return 0
	end
	return n
end

-- kstate(p) = S.KaijuService.GetState(p)
local function kstate(player)
	local st = S.KaijuService.GetState(player)
	if type(st) ~= "string" then
		return "None"
	end
	return st
end

-- goose body center if this player's swings can count on it (Halo / Horns only), else nil
local function goosePositionFor(player)
	if not PVP_FACTIONS[faction(player)] then
		return nil
	end
	local pos = S.GooseService.GetPosition()
	if typeof(pos) ~= "Vector3" then
		return nil
	end
	return pos
end

-- bare = an A23-34 punch: no weapon to aim from, the right hand for every class
local function weaponPosition(character, classId, fallback, bare)
	local weapon = not bare and character:FindFirstChild("WeaponModel")
	local muzzle = weapon and weapon:GetAttribute("Class") == classId
		and weapon:FindFirstChild("AttackMuzzle", true)
	if muzzle and muzzle:IsA("Attachment") and muzzle.Parent and muzzle.Parent:IsA("BasePart") then
		return muzzle.WorldPosition
	end
	local left = classId == "Archer" and not bare
	local hand = left and Util.FindPart(character, "LeftHand", "Left Arm")
		or (not left and Util.FindPart(character, "RightHand", "Right Arm"))
	if hand then
		return hand.Position
	end
	return fallback
end

-- a point `reach` studs in front of the root on the ground plane (visual target of a whiffed ranged swing)
local function forwardPoint(root, reach)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	else
		flat = flat.Unit
	end
	return root.Position + flat * reach
end

-- CR-H2: true when this Swing / Release must be ignored. The zone level gate (the attacker stands in a zone whose
-- MinLevel is above their Level: a teleport hop into a gated zone) is always enforced. ZoneService.IsPlausible logs
-- an implausible position itself ("suspicious move (check, ...)", shared LogCooldown with its zone loop) and returns
-- false ONLY while Config.AntiCheat.Enforce is true, so in log-only mode nothing is blocked or logged here. The
-- Swing / Release line below (at most once per AntiCheat.LogCooldown s) appears only when enforcing; `enforce` is
-- re-checked so blocking stays gated on Config even if ZoneService ever returns false without it.
local function attackBlocked(player, root, what)
	-- A23-68 #1: no swing or skill while the screen fades for the move to the meadow (QuestService MoveLockUntil)
	if numAttr(player, "MoveLockUntil", 0) > Util.Now() then return true end
	local pos = root.Position
	local zone = Config.ZoneAt(pos)
	if (zone.MinLevel or 1) > numAttr(player, "Level", 1) then
		return true
	end
	local zs = S.ZoneService
	if not (zs and type(zs.IsPlausible) == "function") then
		return false
	end
	local ok, plausible = pcall(zs.IsPlausible, player, pos)
	if not ok then
		loopWarn("IsPlausible", plausible)
		return false
	end
	if plausible ~= false then
		return false
	end
	local ac = Config.AntiCheat or {}
	local enforce = ac.Enforce == true
	local now = os.clock()
	if now - (guard.acLogAt[player] or -math.huge) >= (ac.LogCooldown or 10) then
		guard.acLogAt[player] = now
		Util.Warn(
			TAG,
			string.format(
				"CR-H2%s implausible %s position: %s (%d) at %s",
				enforce and "" or " (log only)",
				tostring(what),
				player.Name,
				player.UserId,
				tostring(pos)
			)
		)
	end
	return enforce
end

-- CR-L49: a Swing / Release Fx for the attacker and the players near `center` only (`extent` = the attack's reach
-- around the center); everyone else would cull it on the client anyway
local function fxNear(attacker, kind, center, extent, data)
	local reach = TUNE.FX_CULL + TUNE.FX_SEND_PAD + math.max(0, tonumber(extent) or 0)
	for _, rp in Players:GetPlayers() do
		local send = rp == attacker
		if not send then
			local r = Util.GetRoot(rp)
			send = r ~= nil and (r.Position - center).Magnitude <= reach
		end
		if send then
			Net.Fx(rp, kind, data)
		end
	end
end

------------------------------------------------------------------ removed gauge: legacy attributes stay zero
local function resetLegacyCharge(player)
	if player.Parent == nil then
		return
	end
	player:SetAttribute("Charge", 0)
	player:SetAttribute("ChargeCap", 0)
	player:SetAttribute("PerfectUntil", 0)
end

------------------------------------------------------------------ target selection
-- alive monsters this player may hit within `radius` (flat) of `point`, nearest first: { { Rec, Pos, Dist } }
-- (addendum C2: always passes the attacking player; personal monsters of other players are filtered here too)
-- CR-H2: zone monsters of a zone whose MinLevel is above the attacker's Level are never targets (personal: always)
local function monstersNear(player, point, radius)
	local out = {}
	if radius <= 0 then
		return out
	end
	local list = S.MonsterService.GetMonstersInRadius(point, radius, player)
	if type(list) ~= "table" then
		return out
	end
	local level = numAttr(player, "Level", 1)
	for _, rec in list do
		local zone = type(rec) == "table" and rec.Owner == nil and Config.Zones[rec.ZoneId] or nil
		local gated = zone ~= nil and (zone.MinLevel or 1) > level
		if type(rec) == "table" and rec.Alive and (rec.Owner == nil or rec.Owner == player) and not gated then
			local root = rec.Root
			if root and root.Parent then
				local pos = root.Position
				local d = Util.FlatDistance(pos, point)
				-- A23-92: a big boss is reached at its body's edge (MonsterService.HitPad)
				local pad = type(S.MonsterService.HitPad) == "function" and S.MonsterService.HitPad(rec) or 0
				if d <= radius + pad then
					table.insert(out, { Rec = rec, Pos = pos, Dist = d })
				end
			end
		end
	end
	table.sort(out, byDist)
	return out
end

-- ranged classes aim forward: keep only entries within `cone` degrees of the root's flat facing (nil = no limit).
-- The client turns the character toward its target when the button is pressed, so this rarely drops a target.
local function inAim(root, pos, cone)
	if type(cone) ~= "number" or cone >= 180 then return true end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	local dir = (pos - root.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 1 or look.Magnitude < 0.01 then return true end -- on top of me: always fine
	return look.Unit:Dot(dir.Unit) >= math.cos(math.rad(cone))
end

local function aimed(list, root, cone)
	if type(cone) ~= "number" then return list end
	local out = {}
	for _, e in list do
		if inAim(root, e.Pos, cone) then table.insert(out, e) end
	end
	return out
end

-- other players `attacker` may damage (S.PvPService.CanAttack) within `radius` (flat) of `point`, nearest first:
-- { { Player, Pos, Dist } }. Neutral / None never attack and are never attacked (addendum A6).
local function playersNear(attacker, point, radius)
	local out = {}
	if radius <= 0 or not PVP_FACTIONS[faction(attacker)] then
		return out
	end
	for _, v in S.PlayerService.GetReadyPlayers() do
		if v ~= attacker and v.Parent and PVP_FACTIONS[faction(v)] and Util.IsAlive(v) then
			local root = Util.GetRoot(v)
			if root then
				local pos = root.Position
				local d = Util.FlatDistance(pos, point)
				if d <= radius and S.PvPService.CanAttack(attacker, v) == true then
					table.insert(out, { Player = v, Pos = pos, Dist = d })
				end
			end
		end
	end
	table.sort(out, byDist)
	return out
end

-- A23-61 server aim (검수 2026-10-07): true when a swing of shape `w` has a target inside the real front half (AimCone)
-- within Range: a monster, a player (manual swings) or the golden goose
local function frontTarget(player, root, pos, w, range, isManual, goosePos, gooseReach)
	if #aimed(monstersNear(player, pos, range), root, w.AimCone) > 0 then return true end
	if isManual and #aimed(playersNear(player, pos, range), root, w.AimCone) > 0 then return true end
	return goosePos ~= nil and Util.FlatDistance(goosePos, pos) <= range + gooseReach and inAim(root, goosePos, w.AimCone)
end

-- a facing toward `target` for the aim checks (inAim / aimed read Position and CFrame.LookVector), and the real root
-- turned to it (pcall: the client owns its character; the turn only saves it from showing the late one)
local function turnTo(root, pos, target)
	local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	if flat.Magnitude < 1e-3 then return root end
	local look = flat.Unit
	pcall(function() root.CFrame = CFrame.lookAt(pos, pos + look) end)
	return { Position = pos, CFrame = { LookVector = look } }
end

-- other alive Halo players within the party-aura radius of the attacker
local function countAuraAllies(attacker, radius)
	if type(radius) ~= "number" or radius <= 0 then
		return 0
	end
	local root = Util.GetRoot(attacker)
	if not root then
		return 0
	end
	local n = 0
	for _, p in S.PlayerService.GetReadyPlayers() do
		if p ~= attacker and p.Parent and faction(p) == "Halo" and Util.IsAlive(p) then
			local r = Util.GetRoot(p)
			if r and Util.FlatDistance(r.Position, root.Position) <= radius then
				n += 1
			end
		end
	end
	return n
end

------------------------------------------------------------------ damage formulas (public)
-- additive bonus sum
function CombatService.GetDamageBonus(attacker, victim)
	local perks = perksOf(attacker)
	local bonus = perks.DamageBonus or 0
	bonus += stars(attacker) * Config.PvP.StarDamageBonus
	if faction(attacker) == "Halo" and (perks.PartyAuraPerAlly or 0) > 0 then
		local allies = math.min(perks.PartyAuraMaxAllies or 0, countAuraAllies(attacker, perks.PartyAuraRadius))
		bonus += perks.PartyAuraPerAlly * allies
	end
	if victim ~= nil and S.PvPService.HasRevenge(attacker, victim) == true then
		bonus += Config.Revenge.Bonus
	end
	return bonus
end

-- multiplicative factor: Size Justice S x bully factor (JusticeService) x ranged-vs-player factor
-- shape = the basic attack's Config.AttackProfile (A23-34: a punch is never ranged); nil = the class (skill Q)
function CombatService.GetDamageMult(attacker, victim, shape)
	local c = shape or cls(attacker)
	local mult = S.JusticeService.GetDamageMult(attacker)
	if type(mult) ~= "number" or mult ~= mult then
		mult = 1
	end
	if victim ~= nil and c.Ranged then
		mult *= (c.PvPMult or 1)
	end
	return mult
end

-- NORMAL per-target monster hit (unrounded), before the 50% immediate rule. shape = the swing's Config.AttackProfile
-- (A23-34: a punch has class multiplier 1); nil = the class row (skill Q keeps the class multiplier, bare-handed too)
function CombatService.ComputeMonsterHit(attacker, allowCrit, shape)
	local c = shape or cls(attacker)
	local level = numAttr(attacker, "Level", 1)
	local tier = numAttr(attacker, "WeaponTier", 0)
	local dmg = Config.WeaponDamage(tier, level, numAttr(attacker, "WeaponEnhance", 0))
		* (c.Damage or 1)
		* (1 + CombatService.GetDamageBonus(attacker, nil))
		* CombatService.GetDamageMult(attacker, nil, shape)
	local crit = allowCrit == true and Util.Random:NextNumber() < Config.Combat.CritChance
	if crit then
		dmg *= Config.Combat.CritMult
	end
	return dmg, crit
end

-- NORMAL per-target PvP hit (unrounded): based on the victim's BASE MaxHealth (no Size Justice, no kaiju).
-- shape: as ComputeMonsterHit (A23-34: a punch has class multiplier 1 and no ranged factor)
function CombatService.ComputePvPHit(attacker, victim, shape)
	local c = shape or cls(attacker)
	local aLevel = numAttr(attacker, "Level", 1)
	local aTier = numAttr(attacker, "WeaponTier", 0)
	local vLevel = numAttr(victim, "Level", 1)
	local vTier = numAttr(victim, "WeaponTier", 0)
	local vClass = S.ClassService.GetClass(victim)
	local base = Config.MaxHealth(vLevel, faction(victim), vClass) * Config.PvP.HitPctOfMaxHP
	-- A23-12: enhancement and the legendary tier only move this ratio; the PvP clamp below still caps it
	local vWeapon = Config.WeaponDamage(vTier, vLevel, numAttr(victim, "WeaponEnhance", 0))
	local ratio = Config.PvP.PowerRatioMax
	if vWeapon > 0 then
		ratio = Config.WeaponDamage(aTier, aLevel, numAttr(attacker, "WeaponEnhance", 0)) / vWeapon
	end
	-- A23-34 (검수 2026-10-06): a bare-handed attacker never gets the weapon floor PowerRatioMin, so a punch (and a
	-- bare-handed skill) stays weaker than any tier-1 weapon against every opponent (Config.Combat.Unarmed.PvPRatioMin)
	local floor = Config.Weapons[aTier] and Config.PvP.PowerRatioMin or Config.Combat.Unarmed.PvPRatioMin
	ratio = math.clamp(ratio, floor, Config.PvP.PowerRatioMax)
	return base
		* ratio
		* (c.Damage or 1)
		* (1 + CombatService.GetDamageBonus(attacker, victim))
		* CombatService.GetDamageMult(attacker, victim, shape)
end

------------------------------------------------------------------ heal / damage (public)
function CombatService.HealPlayer(player, amount)
	if not isPlayer(player) then
		return 0
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	local hum = Util.GetHumanoid(player)
	if not hum or hum.Health <= 0 then
		return 0 -- never revive
	end
	local missing = hum.MaxHealth - hum.Health
	if missing <= 0 then
		return 0
	end
	local heal = math.min(Util.RoundDamage(amount), missing)
	hum.Health = hum.Health + heal
	return heal
end

local function tagCombat(player)
	lastPvPTime[player] = os.clock()
	if player.Parent then
		player:SetAttribute("InCombatUntil", Util.Now() + Config.PvP.CombatTagTime)
	end
end

-- A15: "Pain" Fx to every client (pain sticker / flinch over the victim), throttled per victim. A lethal hit is left to
-- the KO effects.
local function sendPain(victim, hum, rootPos, applied, crit)
	if applied <= 0 or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - (painAt[victim] or -math.huge) < REACT.PAIN_GAP then
		return
	end
	painAt[victim] = now
	local big = crit == true or (hum.MaxHealth > 0 and applied >= hum.MaxHealth * REACT.BIG_FRACTION)
	Net.Fx(nil, "Pain", { UserId = victim.UserId, Pos = rootPos, Big = big })
end

-- attacker nil = monster (or any non-player source); crit (optional) = the hit was a critical hit (Pain "Big").
-- Returns the HP actually removed (CR-M10: no overkill, 0 when nothing was applied).
function CombatService.DamagePlayer(victim, amount, attacker, crit, sourceKind)
	if not isPlayer(victim) or victim.Parent == nil then
		return 0
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return 0
	end
	if attacker ~= nil and (not isPlayer(attacker) or attacker == victim) then
		attacker = nil
	end
	-- addendum A6: Neutral (and unassigned) players never deal or receive player damage
	if attacker and (not PVP_FACTIONS[faction(attacker)] or not PVP_FACTIONS[faction(victim)]) then
		return 0
	end
	if not Util.IsAlive(victim) then
		return 0
	end
	local hum = Util.GetHumanoid(victim)
	local root = Util.GetRoot(victim)
	if not hum or not root then
		return 0
	end

	-- SKL-3 Guard (SkillService.GuardOf): only a monster's hit (no attacker, a monster kind) is cut, never a player's or
	-- the kaiju's
	if attacker == nil and type(sourceKind) == "string" and Config.MonsterTypes[sourceKind] ~= nil and S.SkillService
		and type(S.SkillService.GuardOf) == "function" then
		local g = tonumber(S.SkillService.GuardOf(victim)) or 0
		if g > 0 then amount = amount * (1 - math.clamp(g, 0, 0.9)) end
	end
	amount = Util.RoundDamage(amount)
	local now = os.clock()
	lastDamagedAt[victim] = now
	-- BB14: who knocked me out when no player did (MonsterService passes the monster kind, KaijuService "Kaiju")
	if attacker == nil and type(sourceKind) == "string" then lastSource[victim] = { Kind = sourceKind, T = now } end
	if attacker then
		-- bookkeeping BEFORE the damage so a lethal hit is always credited by the death pipeline
		lastPvPAttacker[victim] = { Player = attacker, T = now }
		tagCombat(victim)
		tagCombat(attacker)
	end

	local rootPos = root.Position
	local before = hum.Health
	hum:TakeDamage(amount) -- respects ForceField
	local applied = math.max(0, before - hum.Health)
	-- P1 (2026-10-05): only a PLAYER hit is the victim's activity; an AFK player hit by a slime stays idle
	-- (regular luck, size scale and faction headcount use IdleSeconds)
	-- BB10 D6: kind "Hit" = not the victim's own action (the fair-points idle check reads GetLastOwnActive)
	if attacker then S.PlayerService.MarkActive(victim, "Hit") end
	local okPain, errPain = pcall(sendPain, victim, hum, rootPos, applied, crit)
	if not okPain then
		loopWarn("Pain", errPain)
	end

	-- CR-M23: the victim always sees the hit number + red edge, whoever the attacker is (PvP swings, kaiju stomps)
	if applied > 0 then
		Net.Fx(victim, "Hurt", { Pos = rootPos, Amount = applied })
	end

	if attacker then
		CombatService.PlayerDamaged:Fire(victim, applied, attacker) -- CR-M10: real damage (fired even when 0)
	end
	return applied
end

------------------------------------------------------------------ queries (public)
function CombatService.IsInCombat(player)
	local t = lastPvPTime[player]
	return t ~= nil and os.clock() - t <= Config.PvP.CombatTagTime
end

function CombatService.GetLastDamagedAt(player)
	return lastDamagedAt[player] or 0
end

function CombatService.GetLastPvPAttacker(player)
	local e = lastPvPAttacker[player]
	if not e then
		return nil
	end
	if os.clock() - e.T > Config.PvP.CombatTagTime then
		return nil
	end
	local p = e.Player
	if not p or p.Parent == nil then
		return nil
	end
	return p
end

function CombatService.GetCharge(_player)
	return 0 -- compatibility query; the gauge no longer exists
end

-- Retired Studio QA setter: may clear compatibility attributes, but cannot restore a gauge.
function CombatService.DebugSetCharge(player, amount)
	if not game:GetService("RunService"):IsStudio() or not isPlayer(player)
		or type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		return false
	end
	resetLegacyCharge(player)
	return amount == 0 -- legacy QA cannot restore removed gameplay
end

------------------------------------------------------------------ lifesteal
-- CR-M8: an Active kaiju's lifesteal cap uses its health WITHOUT the kaiju multiplier (x20 MaxHealth outhealed the raid)
local function lifestealCapBase(player, hum)
	local capBase = hum.MaxHealth
	if kstate(player) == "Active" and S.KaijuService and type(S.KaijuService.GetHealthMult) == "function" then
		local okK, km = pcall(S.KaijuService.GetHealthMult, player)
		if okK and type(km) == "number" and km > 1 then
			capBase = capBase / km
		end
	end
	return capBase
end

-- a basic swing's lifesteal (per swing; the class skills use SKILL.Steal and the 3 s window)
local function applyLifesteal(player, perks, total)
	local rate = perks.Lifesteal or 0
	if rate <= 0 or total <= 0 then
		return
	end
	local hum = Util.GetHumanoid(player)
	if not hum or hum.Health <= 0 then
		return
	end
	CombatService.HealPlayer(player, math.min(total * rate, lifestealCapBase(player, hum) * (perks.LifestealCapPct or 0)))
end

-- CR-M10: damage a monster and return the HP it actually lost (no overkill; 0 when the hit was refused).
-- killed = DamageMonster's own result. manual: the player's own press, not auto combat (the King Slime finisher card)
local function damageMonster(rec, dealt, player, crit, castId, manual)
	local hpBefore = math.max(0, tonumber(rec.HP) or 0)
	-- castId: SKL-3 one hit a cast
	local killed = S.MonsterService.DamageMonster(rec, dealt, player, crit, castId, manual == true)
	local applied = math.max(0, hpBefore - math.max(0, tonumber(rec.HP) or 0))
	if player and (killed or applied > 0) then CombatService.MonsterHit:Fire(player, rec, killed) end
	return killed, applied
end

------------------------------------------------------------------ A15 monster shove
-- a small slide of a monster my hit landed on, away from `fromPos` (cosmetic: a failure never breaks the hit loop)
local function shoveMonster(rec, fromPos, studs, player)
	if not rec.Alive or type(S.MonsterService.Shove) ~= "function" then
		return
	end
	local ok, err = pcall(S.MonsterService.Shove, rec, fromPos, studs, player)
	if not ok then
		loopWarn("Shove", err)
	end
end

-- Cosmetic shove follows the same contact frame that the Fx packet announces. style = the swing's Fx Style
-- (A23-34 "Punch"): only its contact time; the class check below still uses classId.
local function shoveLater(attack, classId, rec, fromPos, studs, player, style)
	local byClass = REACT.SHOVE_DELAY[attack]
	local motion = TUNE.MOTION[attack] and TUNE.MOTION[attack][style or classId]
	local d = motion and motion.Contact or (type(byClass) == "table" and tonumber(byClass[classId]) or 0)
	if d > 0 then
		local character = Util.GetCharacter(player)
		task.delay(math.min(d, 1), function()
			if player.Parent and Util.IsAlive(player) and Util.GetCharacter(player) == character
				and cls(player).Id == classId then shoveMonster(rec, fromPos, studs, player) end
		end)
	else
		shoveMonster(rec, fromPos, studs, player)
	end
end

------------------------------------------------------------------ SKL-2 skill kit (Q here, Z / X in SkillService)
-- A23-49 rule 4: the class skills' player damage (35% / kaiju 8%), Halo heal (30% an ally) and Horns life steal (3%)
-- count in DamageWindow's 3 s window per pair, so Q + Z + X together stay under one cap. Without DamageWindow (older
-- offline worlds) the room is the whole cap, i.e. the old per-cast caps. CombatService.Kit = this table: SkillService
-- picks targets and deals damage with the same helpers as the swings and Q.
local SKILL = {}

-- the room DamageWindow leaves for `kind` from -> to under capHP (HP)
function SKILL.Room(kind, from, to, capHP)
	local W = S.DamageWindow
	if W and type(W.Room) == "function" then return W.Room(kind, from, to, capHP) end
	return capHP
end

function SKILL.Book(kind, from, to, n)
	local W = S.DamageWindow
	if W and type(W.Book) == "function" and type(n) == "number" and n > 0 then W.Book(kind, from, to, n) end
end

-- `want` cut to the room left; a used-up window gives 0 (never rounded up to 1 HP past it)
function SKILL.Fit(want, room)
	if room < want then
		return room >= 0.5 and room or 0
	end
	return want
end

-- Halo skill support: every Halo player alive within `radius` of `center` (the caster too) heals HaloHealPct of the HP
-- the cast really removed, at most HaloHealCapPct of their MaxHealth per 3 s from this caster. Returns the OTHER
-- players healed (Released.Healed) and, A23-116, the UserIds of everyone whose HP really went up (the caster too), the
-- TUNE.HEALED_MAX nearest to `center`, nearest first (the Fx Healed signal). A whiff heals nothing.
function SKILL.Heal(player, center, radius, total)
	local healed, got = {}, {}
	local skill = Config.BasicSkill or {}
	if type(total) ~= "number" or total <= 0 or perksOf(player).ReleaseSupport ~= true or faction(player) ~= "Halo" then
		return healed, {}
	end
	for _, a in S.PlayerService.GetReadyPlayers() do
		if a.Parent and faction(a) == "Halo" and Util.IsAlive(a) then
			local aRoot = Util.GetRoot(a)
			local aHum = Util.GetHumanoid(a)
			if aRoot and aHum and Util.FlatDistance(aRoot.Position, center) <= radius then
				local room = SKILL.Room("Heal", player, a, (skill.HaloHealCapPct or 0.30) * aHum.MaxHealth)
				local want = SKILL.Fit((skill.HaloHealPct or 0.10) * total, room)
				local amount = want > 0 and CombatService.HealPlayer(a, want) or 0
				SKILL.Book("Heal", player, a, amount)
				if a ~= player and amount > 0 then
					table.insert(healed, a)
				end
				if amount > 0 then table.insert(got, { Id = a.UserId, D = Util.FlatDistance(aRoot.Position, center) }) end
			end
		end
	end
	table.sort(got, function(x, y) return x.D < y.D or (x.D == y.D and x.Id < y.Id) end)
	local ids = {}
	for i = 1, math.min(#got, TUNE.HEALED_MAX) do ids[i] = got[i].Id end
	return healed, ids
end

-- Horns skill life steal: Lifesteal of the HP the cast removed, at most LifestealCapPct of the caster's MaxHealth (an
-- Active kaiju: without its health multiplier) per 3 s. Returns the HP healed.
function SKILL.Steal(player, total)
	local perks = perksOf(player)
	local rate = perks.Lifesteal or 0
	if rate <= 0 or type(total) ~= "number" or total <= 0 then return 0 end
	local hum = Util.GetHumanoid(player)
	if not hum or hum.Health <= 0 then return 0 end
	local room = SKILL.Room("Steal", player, player, lifestealCapBase(player, hum) * (perks.LifestealCapPct or 0))
	local want = SKILL.Fit(total * rate, room)
	local amount = want > 0 and CombatService.HealPlayer(player, want) or 0
	SKILL.Book("Steal", player, player, amount)
	return amount
end

-- A23-116: the contact / launch times (s from the press) of a skill slot ("Q" | "Z" | "X") for a class id or a style
-- (TUNE.MOTION: Q = its Release row). nil, nil = none (the clients' own defaults)
function SKILL.Motion(slot, classId, style)
	local rows = (slot == "Q" or slot == "Z" or slot == "X") and TUNE.MOTION[slot == "Q" and "Release" or slot] or nil
	local m = rows and rows[style or classId]
	if type(m) ~= "table" then return nil, nil end
	return m.Contact, m.Launch
end

-- a manual skill press (UseSkill): auto combat yields to it like to a manual swing
function SKILL.NoteManual(player)
	lastManualAt[player] = os.clock()
end

SKILL.MonstersNear, SKILL.PlayersNear, SKILL.Aimed, SKILL.InAim = monstersNear, playersNear, aimed, inAim
SKILL.ForwardPoint, SKILL.HitMonster, SKILL.FxNear, SKILL.Blocked = forwardPoint, damageMonster, fxNear, attackBlocked
SKILL.Kaiju, SKILL.TurnTo = kstate, turnTo
CombatService.Kit = SKILL

------------------------------------------------------------------ auto combat (A23-1)
-- Unlocked by the optional quest "내 싸움을 배우는 왕관 조각", starts OFF, toggled and saved by the player.
-- The server loop calls the same Swing / Release paths with the auto flag: same interval, MP, cooldown, range and
-- "one cast = one hit" rules; the auto branches never select players (monsters / goose only, no PvP).
-- A23-22: a bully (BullyStacks >= 1) cannot use auto combat until every stack decayed; A23-23: neither can this week's
-- outlaw (the Outlaw attribute, RankingService). Both at once is still the one penalty.
local function bullyNoAuto(player)
	local pen = Config.Bully.Penalty
	return type(pen) == "table" and pen.NoAuto == true
		and ((tonumber(player:GetAttribute("BullyStacks")) or 0) >= 1 or player:GetAttribute("Outlaw") == true)
end

local function autoReady(player)
	return isPlayer(player) and player.Parent ~= nil and not bullyNoAuto(player)
		and player:GetAttribute("AutoCombatUnlocked") == true and player:GetAttribute("AutoCombatEnabled") == true
		and player:GetAttribute("ClassChosen") == true and kstate(player) == "None"
		and player:GetAttribute("AutoResting") ~= true -- P2: away for 15 min
		and S.PlayerService.IsReady(player) and Util.IsAlive(player)
end

-- P2 idle rest: Zzz above the head while resting (plain text label, removed on wake)
local AUTO_IDLE = { Warned = {} }
function AUTO_IDLE.SetResting(p, on)
	if (p:GetAttribute("AutoResting") == true) == on then return end
	p:SetAttribute("AutoResting", on)
	local head = p.Character and p.Character:FindFirstChild("Head")
	local old = head and head:FindFirstChild("HHC_AutoZzz")
	if old then old:Destroy() end
	if on and head then
		local bb = Instance.new("BillboardGui")
		bb.Name = "HHC_AutoZzz"
		bb.Size = UDim2.fromOffset(80, 40)
		bb.StudsOffset = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 80
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = "Zzz"
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Parent = bb
		bb.Parent = head
	end
	pcall(Net.Notify, p, Config.Text[on and "AutoRestOn" or "AutoRestOff"], "info")
end

-- true while the auto loop must wait: idle rest (with the 30 s warning first) or a pending choice card
function AUTO_IDLE.Check(p)
	local cfg = Config.Combat
	if cfg.AutoIdleRest ~= true then -- user 2026-10-05: auto keeps hunting while away
		if p:GetAttribute("AutoResting") == true then AUTO_IDLE.SetResting(p, false) end
		return false
	end
	local last = S.PlayerService.GetLastActive(p)
	if last <= 0 then
		S.PlayerService.MarkActive(p) -- nothing seen on this server yet: start counting now
		last = os.clock()
	end
	local idle = os.clock() - last
	if idle >= cfg.AutoIdleSeconds then
		AUTO_IDLE.SetResting(p, true)
		return true
	end
	if p:GetAttribute("AutoResting") == true then AUTO_IDLE.SetResting(p, false) end
	if idle >= cfg.AutoIdleSeconds - cfg.AutoIdleWarnSeconds then
		if not AUTO_IDLE.Warned[p] then
			AUTO_IDLE.Warned[p] = true
			pcall(Net.Notify, p, Config.Text.AutoSleepy, "info", cfg.AutoIdleWarnSeconds)
		end
	else
		AUTO_IDLE.Warned[p] = nil
	end
	return false
end

------------------------------------------------------------------ swing (public)
function CombatService.Swing(player, isManual)
	if isManual ~= true and not autoReady(player) then return end -- auto only while auto combat is ON
	isManual = isManual == true
	if not isPlayer(player) or player.Parent == nil or not S.PlayerService.IsReady(player)
		or player:GetAttribute("ClassChosen") ~= true or not Util.IsAlive(player) then
		return
	end
	local character = Util.GetCharacter(player)
	local root = Util.GetRoot(player)
	if not character or not root then
		return
	end
	-- CR-H2: zone level gate + movement plausibility (before the cooldown: a refused swing costs nothing)
	if attackBlocked(player, root, "Swing") then
		return
	end

	-- 1. server-owned manual swing cooldown
	local now = os.clock()
	if now < (nextSwingAt[player] or 0) then
		return
	end
	local c = cls(player)
	-- A23-34: w = this swing's shape (the class row with a weapon; the same short punch for every class bare-handed:
	-- one nearest target within 7, its own interval, no class multiplier, no Mage MP)
	local w = attackShape(player, c)
	if c.Id == "Mage" and not w.Unarmed
		and not S.VitalsService.TrySpendMana(player, Config.Vitals.MageSwingCost, not isManual) then
		return
	end
	nextSwingAt[player] = now + (w.SwingInterval or 1)

	local pos = root.Position
	local fac = faction(player)
	local perks = perksOf(player)
	local goosePos = goosePositionFor(player)
	local gooseReach = Config.Goose.HitRadius
	local range = w.Range or 10

	-- A23-61 server aim (검수 2026-10-07, game dev 1's Studio finding): the client turns the body to the nearest monster
	-- before it sends Swing, but the server sees that turn 0.27-0.43 s late, so a monster behind was missed. With nothing
	-- inside the real front half the swing aims at the nearest monster within Range in any direction (the client
	-- FaceTarget rule) and turns the root to it; a turned swing hits monsters only (players and the goose keep the
	-- front-half rule)
	local aimRoot, turned = root, false
	if not frontTarget(player, root, pos, w, range, isManual, goosePos, gooseReach) then
		local near = monstersNear(player, pos, range)[1]
		if near then
			aimRoot = turnTo(root, pos, near.Pos)
			turned = aimRoot ~= root
		end
	end

	-- 2. select targets by class pattern
	local monsters = {} -- { { Rec, Pos, Dist } }
	local victims = {} -- { { Player, Pos, Dist } }
	local hitGoose = false
	local center = pos
	local radius = range
	local targets = {}

	if w.Pattern == "Splash" then
		radius = w.Splash or 0
		local pickPos, pickDist, pickIsGoose = nil, math.huge, false
		local nearMon = aimed(monstersNear(player, pos, range), aimRoot, w.AimCone)
		if nearMon[1] then
			pickPos, pickDist = nearMon[1].Pos, nearMon[1].Dist
		end
		if isManual and not turned then
			local nearPl = aimed(playersNear(player, pos, range), root, w.AimCone)
			if nearPl[1] and nearPl[1].Dist < pickDist then
				pickPos, pickDist = nearPl[1].Pos, nearPl[1].Dist
			end
		end
		if goosePos and not turned and inAim(root, goosePos, w.AimCone) then
			local d = Util.FlatDistance(goosePos, pos)
			if d <= range + gooseReach and d < pickDist then
				pickPos, pickDist, pickIsGoose = goosePos, d, true
			end
		end
		if pickPos then
			center = pickPos
			monsters = monstersNear(player, center, radius)
			if isManual and not turned then
				victims = playersNear(player, center, radius)
			end
			hitGoose = goosePos ~= nil and not turned
				and (pickIsGoose or Util.FlatDistance(goosePos, center) <= radius + gooseReach)
		else
			center = forwardPoint(root, math.min(range, WHIFF_REACH)) -- whiff: the orb flies forward
		end
		targets = { center }
	elseif w.Pattern == "Multi" then
		radius = 0
		local maxTargets = w.Targets or 0
		local candidates = {}
		for _, m in aimed(monstersNear(player, pos, range), aimRoot, w.AimCone) do
			table.insert(candidates, { Kind = "M", Entry = m, Pos = m.Pos, Dist = m.Dist })
		end
		if isManual and not turned then
			for _, v in aimed(playersNear(player, pos, range), root, w.AimCone) do
				table.insert(candidates, { Kind = "P", Entry = v, Pos = v.Pos, Dist = v.Dist })
			end
		end
		if goosePos and not turned and inAim(root, goosePos, w.AimCone) then
			local d = Util.FlatDistance(goosePos, pos)
			if d <= range + gooseReach then
				table.insert(candidates, { Kind = "G", Pos = goosePos, Dist = d })
			end
		end
		table.sort(candidates, byDist)
		for i, cand in candidates do
			if maxTargets > 0 and i > maxTargets then
				break
			end
			table.insert(targets, cand.Pos)
			if cand.Kind == "M" then
				table.insert(monsters, cand.Entry)
			elseif cand.Kind == "P" then
				table.insert(victims, cand.Entry)
			else
				hitGoose = true
			end
		end
		if #targets == 0 then
			targets = { forwardPoint(root, math.min(range, WHIFF_REACH)) } -- whiff: the arrow flies forward
		end
	else -- "Around" (default): everything within Range of self, in front of me (AimCone; turned: the new front half)
		monsters = aimed(monstersNear(player, pos, range), aimRoot, w.AimCone)
		if isManual and not turned then
			victims = aimed(playersNear(player, pos, range), aimRoot, w.AimCone)
		end
		hitGoose = goosePos ~= nil and not turned and Util.FlatDistance(goosePos, pos) <= range + gooseReach
			and inAim(root, goosePos, w.AimCone)
	end

	local hits = {}
	local totalDealt, monstersHit, playersHit = 0, 0, 0

	-- 3. monsters: 50% of the normal hit right away (crit rolled per target)
	if #monsters > 0 then
		local base = CombatService.ComputeMonsterHit(player, false, w)
		for _, m in monsters do
			local rec = m.Rec
			if rec.Alive then
				local crit = Util.Random:NextNumber() < Config.Combat.CritChance
				local d = base * (crit and Config.Combat.CritMult or 1)
				local dealt = Util.RoundDamage(d * ((Config.BasicSkill and Config.BasicSkill.SwingImmediate) or 0.5))
				local killed, applied = damageMonster(rec, dealt, player, crit, nil, isManual)
				if killed or applied > 0 then -- 0 = refused by MonsterService (owner / zone rules): not a hit
					if not killed then
						shoveLater("Swing", c.Id, rec, pos, crit and REACT.SHOVE_CRIT or REACT.SHOVE_SWING, player, w.Style) -- A15
					end
					table.insert(hits, { P = m.Pos, A = dealt, C = crit, K = "M" }) -- the number shows the hit as dealt
					totalDealt += applied -- CR-M10: lifesteal counts real damage only
					monstersHit += 1
				end
			end
		end
	end

	-- 4. players (manual swings only; already validated with CanAttack)
	for _, v in victims do
		local vp = v.Player
		if vp.Parent and Util.IsAlive(vp) then
			local dealt = Util.RoundDamage(CombatService.ComputePvPHit(player, vp, w)
				* ((Config.BasicSkill and Config.BasicSkill.SwingImmediate) or 0.5))
			totalDealt += CombatService.DamagePlayer(vp, dealt, player) or 0 -- CR-M10
			table.insert(hits, { P = v.Pos, A = dealt, C = false, K = "P", V = vp.UserId }) -- CR-M23: V = victim
			playersHit += 1
		end
	end
	if playersHit > 0 then
		S.PvPService.BreakProtection(player)
	end

	-- 5. golden goose: no damage, no charge. CR-L21: the number is what RegisterHit really counted (0 = none)
	if hitGoose and goosePos then
		local okG, counted = pcall(S.GooseService.RegisterHit, player, isManual)
		if not okG then
			loopWarn("GooseHit", counted)
			counted = 0
		elseif counted == nil then
			counted = isManual and Config.Goose.ManualCount or Config.Goose.AutoCount -- GooseService without a return
		end
		if type(counted) == "number" and counted == counted and counted > 0 then
			table.insert(hits, {
				P = goosePos,
				A = math.floor(counted * 10 + 0.5) / 10,
				C = false,
				K = "G",
			})
		end
	end

	-- 7. lifesteal (Horns)
	applyLifesteal(player, perks, totalDealt)

	-- 8. activity
	local anyHit = monstersHit + playersHit > 0 or hitGoose
	if isManual or anyHit then
		if isManual then S.PlayerService.MarkActive(player) end -- auto hits never count as the player being active

		-- 9. visuals for the attacker + everyone near (manual whiffs too, with empty Hits). CR-L49: the extent covers
		-- the hand (Splash center up to Range away) and Multi targets (radius 0, up to Range away)
		-- A23-34: Style = "Punch" for a bare-handed swing (clients draw a jab from the right hand, no projectile / arc);
		-- nil = the class weapon attack. Class stays the real class id.
		local motion = TUNE.MOTION.Swing[w.Style or c.Id]
		fxNear(player, "Swing", center, math.max(radius, range), {
			UserId = player.UserId,
			Character = character,
			Class = c.Id,
			Style = w.Style,
			Faction = fac,
			From = weaponPosition(character, c.Id, pos, w.Unarmed),
			ContactDelay = motion and motion.Contact,
			LaunchDelay = motion and motion.Launch,
			FlightTime = motion and motion.Flight,
			Pos = center,
			Radius = radius,
			Targets = targets,
			Hits = hits,
			Manual = isManual, -- A15: clients kick the camera on manual hits only
		})
	end
end

------------------------------------------------------------------ release (public)
function CombatService.Release(player, isAuto)
	if isAuto == true and not autoReady(player) then return end -- auto skills only while auto combat is ON
	isAuto = isAuto == true
	if not isPlayer(player) or player.Parent == nil or not S.PlayerService.IsReady(player)
		or player:GetAttribute("ClassChosen") ~= true or not Util.IsAlive(player) then
		return
	end
	local root = Util.GetRoot(player)
	if not root then
		return
	end
	-- CR-H2: zone level gate + movement plausibility (MP is kept)
	if attackBlocked(player, root, "Release") then
		return
	end

	-- 1. MP and a server cooldown are the only skill resources; there is no gauge or PERFECT window.
	local skill = Config.BasicSkill or {}
	local now = os.clock()
	local cooldown = skill.Cooldown or 3
	if now - (guard.releaseAt[player] or -math.huge) < cooldown then return end
	if not S.VitalsService.TrySpendMana(player, skill.ManaCost or Config.Vitals.ReleaseCost, isAuto) then return end -- auto: silent
	guard.releaseAt[player] = now -- failed eligibility/MP checks do not consume the successful-use cooldown
	player:SetAttribute("SkillReadyAt", Util.Now() + cooldown)
	local c = cls(player)
	local fac = faction(player)
	local style = Config.IsTamer(c.Id, fac) and Config.Tamer.SkillStyle or nil -- A23-39 (look only)

	-- 3. center + radius
	local pos = root.Position
	local center = pos
	local turnedQ = false -- A23-61 server aim: the blast went to a monster outside the aim cone (monsters only)
	if c.ReleaseCenter == "Target" then
		local range = c.Range or 10
		local bestPos, bestDist = nil, math.huge
		local nearMon = aimed(monstersNear(player, pos, range), root, c.AimCone)
		if nearMon[1] then
			bestPos, bestDist = nearMon[1].Pos, nearMon[1].Dist
		end
		if not isAuto then
			local nearPl = aimed(playersNear(player, pos, range), root, c.AimCone)
			if nearPl[1] and nearPl[1].Dist < bestDist then
				bestPos, bestDist = nearPl[1].Pos, nearPl[1].Dist
			end
		end
		-- A23-61 server aim (검수 2026-10-07): nothing aimed -> the nearest monster within range in any direction (the
		-- client FaceTarget rule; the root turns to it), the swing's rule
		if not bestPos then
			local nearQ = monstersNear(player, pos, range)[1]
			if nearQ then
				bestPos = nearQ.Pos
				turnedQ = turnTo(root, pos, nearQ.Pos) ~= root
			end
		end
		if bestPos then
			center = bestPos
		end
	end
	local radius = skill.Radius or 9
	local releaseMult = (skill.DamageMultiplier or 6) * (c.ReleaseMult or 1)

	local hits = {}
	-- total = HP really removed (CR-M10: heal / lifesteal / Released.Total); shownTotal = the dealt numbers (Fx)
	local total, shownTotal, monstersHit, playersHit = 0, 0, 0, 0

	-- 4. monsters (never crit)
	local monsters = monstersNear(player, center, radius)
	if #monsters > 0 then
		local D = CombatService.ComputeMonsterHit(player, false)
		local dealt = Util.RoundDamage(D * releaseMult)
		for _, m in monsters do
			if m.Rec.Alive then
				-- marked before the damage: a kill made by this skill counts as a skill kill (S0 trial: basic-attack-only)
				m.Rec._skillBy = m.Rec._skillBy or {}
				m.Rec._skillBy[player] = true
				local killed, applied = damageMonster(m.Rec, dealt, player, nil, nil, not isAuto)
				if killed or applied > 0 then -- 0 = refused by MonsterService (owner / zone rules): not a hit
					if not killed then
						-- A15: a blast pushes outward from its center; the monster at the center goes away from me
						local from = Util.FlatDistance(m.Pos, center) > 0.5 and center or pos
						shoveLater("Release", c.Id, m.Rec, from, REACT.SHOVE_RELEASE, player, style)
					end
					table.insert(hits, { P = m.Pos, A = dealt, C = false, K = "M" })
					total += applied
					shownTotal += dealt
					monstersHit += 1
				end
			end
		end
	end

	-- 5. players (manual releases only), at most PvPCapPct of the target's current MaxHealth (CR-M7: an Active kaiju at
	-- Kaiju.ReleaseCapPct, so its x20 HP is not 3 shots of saved-up stacks). SKL-2: the cap is DamageWindow's 3 s window
	-- per attacker -> victim (Q + Z + X together), no longer per cast; a used-up window deals nothing. A turned blast
	-- (A23-61 server aim) hits monsters only.
	if not isAuto and not turnedQ then
		for _, v in playersNear(player, center, radius) do
			local vp = v.Player
			local vHum = Util.GetHumanoid(vp)
			if vp.Parent and vHum and vHum.Health > 0 then
				local D = CombatService.ComputePvPHit(player, vp)
				local capPct = skill.PvPCapPct or 0.35
				if kstate(vp) == "Active" then
					capPct = Config.Kaiju.ReleaseCapPct or 0.08
				end
				local raw = SKILL.Fit(D * releaseMult, SKILL.Room("Hit", player, vp, capPct * vHum.MaxHealth))
				if raw > 0 then
					local dealt = Util.RoundDamage(raw)
					local applied = CombatService.DamagePlayer(vp, dealt, player) or 0
					SKILL.Book("Hit", player, vp, applied)
					total += applied -- CR-M10
					table.insert(hits, { P = v.Pos, A = dealt, C = false, K = "P", V = vp.UserId }) -- CR-M23: V = victim
					shownTotal += dealt
					playersHit += 1
				end
			end
		end
		if playersHit > 0 then
			S.PvPService.BreakProtection(player)
		end
	end

	-- 6. Halo skill support heals the Halo players inside the blast (self included) from the HP really removed (a whiff
	-- heals nothing); SKL-2: per ally through the 3 s window (SKILL.Heal). A23-116: healedIds = the Fx Healed signal
	local healed, healedIds = SKILL.Heal(player, center, radius, total)

	-- 7. lifesteal (Horns) on the total; SKL-2: the skills' 3 s window (SKILL.Steal). A23-116: stole = the Fx Stole signal
	local stole = SKILL.Steal(player, total)

	-- 8. activity
	if not isAuto then
		S.PlayerService.MarkActive(player)
	end

	-- 9. visuals (CR-L49: the attacker + players near the blast) + signal. A23-39: Style = "PetDash" for the pet tamer
	-- (the same Archer skill; the pet dashes in instead of the arrow rain), nil for every other class
	local motion = TUNE.MOTION.Release[style or c.Id]
	fxNear(player, "Release", center, radius, {
		UserId = player.UserId,
		Character = Util.GetCharacter(player),
		Class = c.Id,
		Style = style,
		Faction = fac,
		ContactDelay = motion and motion.Contact,
		LaunchDelay = motion and motion.Launch,
		Pos = center,
		Radius = radius,
		Stacks = 0, -- legacy Fx compatibility only
		Perfect = false,
		Auto = isAuto,
		Total = shownTotal, -- the big number = the sum of the hit numbers shown
		Hits = hits,
		-- A23-116 common signals, only what the server really restored: the UserIds whose HP this cast's heal raised
		-- (the caster too, the nearest 5 first) and the HP the Horns life steal gave the caster (0 = none)
		Healed = healedIds,
		Stole = stole,
	})
	CombatService.Released:Fire(player, {
		Slot = "Q", -- SKL-2: Z / X casts (SkillService) fire this signal with their own slot
		Stacks = 0, -- legacy event compatibility; never fabricate quest charge
		Auto = isAuto,
		Perfect = false,
		Center = center,
		Radius = radius,
		Total = total,
		MonstersHit = monstersHit,
		PlayersHit = playersHit,
		Healed = healed,
	})
	return true -- SKL-2: the cast went off (SkillService keeps the shared gap from here)
end

------------------------------------------------------------------ death pipeline (the only KO entry point)
local function pipelineCall(label, fn, ...)
	if type(fn) ~= "function" then
		Util.Warn(TAG, "death pipeline: missing " .. label)
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		Util.Warn(TAG, "death pipeline: " .. label .. " failed: " .. tostring(err))
	end
end

-- BB14: the cause, the gold this KO took and the sack, to the victim only (Net.Fx "KO"; Config.Death)
local function sendKO(victim, killer, ctx, carriedBefore, died)
	local D = Config.Death
	local by, name, killerFaction = "Other", "", ""
	local src = lastSource[victim]
	local recent = src ~= nil and ctx.At - src.T <= D.SourceSeconds
	local A = S.AnnounceService
	local function publicName(p)
		if A and A.PublicName then
			local ok, n = pcall(A.PublicName, p)
			if ok and type(n) == "string" then return n end
		end
		return Util.PlayerDisplayName(p)
	end
	if killer then
		by, name, killerFaction = "Player", publicName(killer), faction(killer)
	elseif recent and src.Kind == "Kaiju" then
		local K = S.KaijuService
		local okK, k = pcall(function() return K and K.GetActive and K.GetActive() end)
		by, name = "Kaiju", (okK and typeof(k) == "Instance") and publicName(k) or ""
	elseif recent and Config.MonsterTypes[src.Kind] then
		by, name = "Monster", Config.MonsterTypes[src.Kind].Name
	elseif died.Freefall or died.Pos == nil
		or died.Pos.Y < (Config.ZoneAt(died.Pos).Center.Y or 0) - D.FallBelowFloor then
		by = "Fall" -- falling, the body already gone (the void) or far below its zone's floor
	end
	local lost = math.max(0, math.floor(carriedBefore - numAttr(victim, "CarriedGold", 0)))
	-- EG05 (Config.Death.Fun): this KO is counted (data.KOs, saved); about one in Every, never the first SkipFirst, carries a joke tip
	local tip = nil
	local okKO, koCount = pcall(S.PlayerService.AddStat, victim, "KOs", 1)
	if okKO and type(koCount) == "number" then
		local okTip, line = pcall(Config.FunTip, koCount, Util.Random:NextNumber(), Util.Random:NextNumber())
		if okTip then tip = line end
	end
	Net.Fx(victim, "KO", { By = by, Name = name, Faction = killerFaction, Lost = lost, Sack = ctx.HadSack == true,
		RespawnIn = Config.Player.RespawnTime, Tip = tip })
	CombatService.KnockedOut:Fire(victim, by)
end

-- A23-110: the lossless first KO (FirstKOService.ClaimKO: the King Slime's one hit on the quest step, once per account,
-- only when nothing is at stake)
-- -> { RespawnIn = s } or nil
local function claimFirstKO(victim, diedAt)
	local svc = S.FirstKOService
	if type(svc) ~= "table" or type(svc.ClaimKO) ~= "function" then return nil end
	local ok, first = pcall(svc.ClaimKO, victim, diedAt)
	if not ok then
		loopWarn("FirstKO", first)
		return nil
	end
	return type(first) == "table" and first or nil
end

-- A23-110: the short KO screen of the first KO (owner only): the King's name, nothing lost, no tip, First = true. The KO
-- is not counted (data.KOs) and nothing else of the pipeline runs (no sack, bounty, PvP KO or ranking)
local function sendFirstKO(victim, first)
	local src = lastSource[victim]
	local def = src and Config.MonsterTypes[src.Kind]
	local fx = { By = def and "Monster" or "Other", Name = def and def.Name or "", Faction = "", Lost = 0, Sack = false,
		RespawnIn = tonumber(first.RespawnIn) or Config.Player.RespawnTime, First = true }
	Net.Fx(victim, "KO", fx)
	CombatService.KnockedOut:Fire(victim, def and "Monster" or "Other")
end

local function runDeathPipeline(victim, diedAt, died)
	if victim.Parent == nil then
		-- the victim already left: leave flows (GrudgeService / ProgressionService) handle it
		lastPvPAttacker[victim] = nil
		return
	end

	-- A23-110: the first KO loses nothing: only its KO screen, then the attacker / source are forgotten
	local first = claimFirstKO(victim, diedAt)
	if first then
		pipelineCall("CombatService.sendFirstKO", sendFirstKO, victim, first)
		resetLegacyCharge(victim)
		lastPvPAttacker[victim] = nil
		lastSource[victim] = nil
		return
	end

	local killer = CombatService.GetLastPvPAttacker(victim)
	if killer then
		local fk, fv = faction(killer), faction(victim)
		-- "None" and "Neutral" never take part in PvP KOs (addendum A6)
		if killer == victim or killer.Parent == nil or fk == fv or not PVP_FACTIONS[fk] or not PVP_FACTIONS[fv] then
			killer = nil
		end
	end

	-- BB10: the weekly ranking's friend check may wait for Roblox (IsFriendsWith). It runs HERE, before anything below
	-- changes state, so PvPService.HandleKO never yields; then both players must still be here.
	local ranking = S.RankingService
	local okActive, activeState = pcall(kstate, victim)
	local kaijuDeath = okActive and activeState == "Active" -- HandleKaijuDeath never asks the ranking
	if killer and ranking and ranking.ResolveFriends and not kaijuDeath and game.PrivateServerId == "" then
		local okFriends, errFriends = pcall(ranking.ResolveFriends, killer, victim)
		if not okFriends then loopWarn("ResolveFriends", errFriends) end
		if victim.Parent == nil then
			lastPvPAttacker[victim] = nil
			return -- left while waiting: the leave flows handle it
		end
		if killer.Parent == nil then killer = nil end
	end

	-- BB10 D2: a thief KO'd while carrying a grudge sack is never an unfair KO (seen before step 1 closes the sack)
	local okSack, hadSack = pcall(S.GrudgeService.HasSack, victim)
	-- At = the KO's own time: the fresh-spawn, bait, revenge and self-defense checks never see the wait above
	local koCtx = { HadSack = okSack and hadSack == true, At = diedAt }

	local carriedBefore = numAttr(victim, "CarriedGold", 0) -- BB14: Lost = what steps 1-2 took

	-- 1. resolve a grudge sack first (no-op without one)
	pipelineCall("GrudgeService.OnCarrierDown", S.GrudgeService.OnCarrierDown, victim, killer)

	-- 2. kaiju / PvP KO / non-PvP death
	local okState, state = pcall(kstate, victim)
	if okState and state == "Active" then
		pipelineCall("KaijuService.HandleKaijuDeath", S.KaijuService.HandleKaijuDeath, victim, killer)
	elseif killer then
		pipelineCall("PvPService.HandleKO", S.PvPService.HandleKO, victim, killer, koCtx)
	else
		pipelineCall("PvPService.HandleNonPvPDeath", S.PvPService.HandleNonPvPDeath, victim)
	end

	-- BB14: the KO screen's facts (owner only)
	pipelineCall("CombatService.sendKO", sendKO, victim, killer, koCtx, carriedBefore, died or {})

	-- 3. clear legacy attributes and forget the attacker
	resetLegacyCharge(victim)
	lastPvPAttacker[victim] = nil
	lastSource[victim] = nil
end

local function onCharacterDied(player, _character)
	if not isPlayer(player) then
		return
	end
	pendingManual[player] = nil
	local diedAt = os.clock() -- BB10: the KO's time, before the friend check may wait (and the victim respawn)
	-- BB14: where the body was when it fell (Pos nil = already gone, the void) and whether it was in free fall
	local root = Util.GetRoot(player)
	local hum = Util.GetHumanoid(player)
	local okState, hstate = pcall(function() return hum and hum:GetState() end)
	local died = { Pos = root and root.Position or nil, Freefall = okState and hstate == Enum.HumanoidStateType.Freefall }
	-- deferred so the lethal hit's PlayerDamaged handlers (kaiju damage share, bait log) always run first,
	-- whatever the Workspace.SignalBehavior is
	task.defer(function()
		local ok, err = pcall(runDeathPipeline, player, diedAt, died)
		if not ok then
			Util.Warn(TAG, "death pipeline error: " .. tostring(err))
		end
	end)
end

------------------------------------------------------------------ player lifecycle handlers
local function onPlayerReady(player, _data)
	if not isPlayer(player) or player.Parent == nil then
		return
	end
	nextSwingAt[player] = 0
	guard.releaseAt[player] = nil
	player:SetAttribute("SkillReadyAt", 0)
	player:SetAttribute("AutoAttack", false)
	player:SetAttribute("InCombatUntil", 0)
	resetLegacyCharge(player)
	-- A23-22: becoming a bully switches auto combat OFF (with the reason); the end of the penalty is announced.
	-- A23-23: an outlaw week does the same (reason OutlawAutoOff); its end is announced by RankingService (OutlawEnd)
	local wasBully = bullyNoAuto(player)
	local function penaltyChanged(fromOutlaw)
		local now = bullyNoAuto(player)
		if now and not wasBully and player:GetAttribute("AutoCombatEnabled") == true and S.PlayerService.IsReady(player) then
			S.PlayerService.SetStat(player, "AutoCombatEnabled", false)
			local outlawOnly = (tonumber(player:GetAttribute("BullyStacks")) or 0) < 1
			-- sound_gaps C3: the AutoOff sound (the attribute) is enough, no Deny on top
			Net.Notify(player, outlawOnly and Config.Ranking.Text.OutlawAutoOff or Config.Text.BullyAutoOff, "bad", nil, "None")
		elseif wasBully and not now and not fromOutlaw and (tonumber(player:GetAttribute("BullyStacks")) or 0) <= 0 then
			local unlocked = player:GetAttribute("AutoCombatUnlocked") == true
			Net.Notify(player, unlocked and Config.Text.BullyPenaltyEnd or Config.Text.BullyPenaltyEndNoAuto, "good")
		end
		wasBully = now
	end
	player:GetAttributeChangedSignal("BullyStacks"):Connect(function() penaltyChanged(false) end)
	player:GetAttributeChangedSignal("Outlaw"):Connect(function() penaltyChanged(true) end)
	if wasBully and player:GetAttribute("AutoCombatEnabled") == true then
		S.PlayerService.SetStat(player, "AutoCombatEnabled", false) -- rejoined with saved stacks
	end
end

local function onCharacterSpawned(player, _character, _humanoid, cosmetic)
	if not isPlayer(player) or player.Parent == nil then return end
	resetLegacyCharge(player)
	player:SetAttribute("AutoAttack", false)
	if not cosmetic then
		-- Match VitalsService's real-respawn MP reset; changing appearance cannot bypass a skill cooldown.
		guard.releaseAt[player] = nil
		player:SetAttribute("SkillReadyAt", 0)
	end
end

local function onPlayerLeaving(player, _data)
	-- deferred: other PlayerLeaving handlers (ProgressionService combat-log penalty) still read IsInCombat
	task.defer(function()
		nextSwingAt[player] = nil
		lastManualAt[player] = nil
		pendingManual[player] = nil
		lastDamagedAt[player] = nil
		lastPvPAttacker[player] = nil
		lastSource[player] = nil
		lastPvPTime[player] = nil
		painAt[player] = nil
		guard.releaseAt[player] = nil
		guard.acLogAt[player] = nil -- CR-H2
	end)
end

local function onFactionChanged(player, _newFaction, _oldFaction, _reason)
	if not isPlayer(player) then
		return
	end
	pendingManual[player] = nil
	resetLegacyCharge(player)
end

local function onClassChanged(player, _newClass, _oldClass)
	if not isPlayer(player) then
		return
	end
	pendingManual[player] = nil
	resetLegacyCharge(player)
end

------------------------------------------------------------------ remotes
-- one queued manual swing that fires as soon as the shared cooldown is ready (addendum H3)
local function queueManualSwing(player)
	local request = { Character = Util.GetCharacter(player), Class = cls(player).Id, Faction = faction(player) }
	pendingManual[player] = request
	local tries = 0
	local function attempt()
		if pendingManual[player] ~= request then
			return
		end
		if player.Parent == nil or not S.PlayerService.IsReady(player) or player:GetAttribute("ClassChosen") ~= true
			or not Util.IsAlive(player)
			or Util.GetCharacter(player) ~= request.Character or cls(player).Id ~= request.Class
			or faction(player) ~= request.Faction then
			pendingManual[player] = nil
			return
		end
		local remaining = (nextSwingAt[player] or 0) - os.clock()
		if remaining > 0 and tries < MANUAL_QUEUE_RETRIES then
			tries += 1
			task.delay(remaining, attempt)
			return
		end
		pendingManual[player] = nil
		CombatService.Swing(player, true)
	end
	task.delay(math.max(0, (nextSwingAt[player] or 0) - os.clock()), attempt)
end

local function onSwingRemote(player)
	if not S.PlayerService.IsReady(player) or player:GetAttribute("ClassChosen") ~= true then
		return
	end
	if not Util.RateLimit(player, "Swing", Config.RateLimits.Swing) then
		return
	end
	S.PlayerService.MarkActive(player)
	lastManualAt[player] = os.clock()
	if pendingManual[player] then
		return -- a manual swing is already queued
	end
	local remaining = (nextSwingAt[player] or 0) - os.clock()
	if remaining <= 0 then
		CombatService.Swing(player, true)
	elseif remaining <= MANUAL_GRACE then
		-- queue a single jitter-early press; holding a button never starts a server attack loop
		queueManualSwing(player)
	end
	-- otherwise an early repeat of a manual swing: silently ignored
end

local function onReleaseRemote(player)
	if not S.PlayerService.IsReady(player) then
		return
	end
	if not Util.RateLimit(player, "Release", Config.RateLimits.Release) then
		return
	end
	lastManualAt[player] = os.clock()
	local skills = S.SkillService
	if skills and type(skills.Cast) == "function" then
		skills.Cast(player, "Q", false) -- SKL-2: the shared 0.5 s gap / one queued press / the refusal words
	else
		CombatService.Release(player, false) -- MarkActive inside
	end
end

-- A23-1: ON/OFF only after the unlock; the choice is saved (AutoCombatEnabled)
local function onSetAutoAttackRemote(player, enabled, ...)
	if select("#", ...) ~= 0 or not S.PlayerService.IsReady(player) then
		return
	end
	if type(enabled) ~= "boolean" then
		return
	end
	if not Util.RateLimit(player, "SetAutoAttack", Config.RateLimits.SetAutoAttack) then
		return
	end
	if player:GetAttribute("AutoCombatUnlocked") ~= true or player:GetAttribute("ClassChosen") ~= true
		or not Util.IsAlive(player) then
		return
	end
	if enabled and bullyNoAuto(player) then
		local outlawOnly = (tonumber(player:GetAttribute("BullyStacks")) or 0) < 1
		Net.Notify(player, outlawOnly and Config.Ranking.Text.OutlawNoAuto or Config.Text.BullyNoAuto, "bad")
		return
	end
	S.PlayerService.SetStat(player, "AutoCombatEnabled", enabled)
end

-- the crown-shard quest calls this once; it never turns auto combat ON by itself
function CombatService.UnlockAutoCombat(player)
	if not isPlayer(player) or not S.PlayerService.IsReady(player) then return false end
	S.PlayerService.SetStat(player, "AutoCombatUnlocked", true)
	return true
end

-- one auto step: a swing when its interval is up and a monster is in reach; the skill when MP / cooldown allow
-- and the blast would hit at least one monster (no whiffs, no MP wasted)
local function autoTick(p)
	-- P2: a resting player wakes the moment they act; the rest flag never outlives auto combat being ON
	if p:GetAttribute("AutoResting") == true and p:GetAttribute("AutoCombatEnabled") == true
		and S.PlayerService.IsReady(p) then
		AUTO_IDLE.Check(p)
		return
	end
	if p:GetAttribute("AutoResting") == true and p:GetAttribute("AutoCombatEnabled") ~= true then
		AUTO_IDLE.SetResting(p, false)
	end
	if not autoReady(p) then return end
	if AUTO_IDLE.Check(p) then return end
	local root = Util.GetRoot(p)
	if not root then return end
	local c = cls(p)
	local w = attackShape(p, c) -- A23-34: the swing's reach / interval (a bare-handed punch: 7 studs, 0.8 s)
	-- my own presses win: auto waits one swing interval + ManualYieldPad after a manual attack / skill
	local lm = lastManualAt[p]
	if lm and os.clock() - lm < (w.SwingInterval or 1) + (Config.Combat.ManualYieldPad or 0.3) then return end
	local pos = root.Position
	local range = c.Range or 10 -- the class range: the skill Q reach below (Q is the class skill, bare-handed too)
	-- A23-61 server aim: a monster anywhere within reach (Swing turns to it when the front half is empty)
	if os.clock() >= (nextSwingAt[p] or 0) and #monstersNear(p, pos, w.Range or 10) > 0 then
		CombatService.Swing(p, false)
	end
	-- SKL-2: Z first when its auto rule holds (SkillService; SKL-3 adds X before it); the skills' shared 0.5 s gap then
	-- holds Q back to a later tick
	local skills = S.SkillService
	if skills and type(skills.AutoCast) == "function" then
		local okZ, cast = pcall(skills.AutoCast, p)
		if not okZ then
			loopWarn("AutoSkill", cast)
		elseif cast then
			return
		end
	end
	local skill = Config.BasicSkill or {}
	if os.clock() - (guard.releaseAt[p] or -math.huge) < (skill.Cooldown or 3) then return end
	if numAttr(p, "Mana", 0) < (skill.ManaCost or Config.Vitals.ReleaseCost) then return end
	local reach = (c.ReleaseCenter == "Target") and range or (skill.Radius or 9)
	local inReach = monstersNear(p, pos, reach) -- A23-61 server aim: any direction (Release turns to it)
	if #inReach > 0 then
		if skills and type(skills.Cast) == "function" then
			skills.Cast(p, "Q", true) -- the shared gap
		else
			CombatService.Release(p, true)
		end
	end
end

------------------------------------------------------------------ loops
local function regenTick(p)
	local hum = Util.GetHumanoid(p)
	if not hum or hum.Health <= 0 or hum.Health >= hum.MaxHealth then
		return
	end
	local pct
	-- an Active kaiju never gets the town regen (it would make the event unwinnable in Crossroads)
	if S.ZoneService.IsTown(p) and kstate(p) ~= "Active" then
		pct = Config.Combat.TownRegenPerSec
	else
		pct = perksOf(p).RegenPerSec or 0
	end
	if type(pct) == "number" and pct > 0 then
		CombatService.HealPlayer(p, hum.MaxHealth * pct * Config.Combat.RegenTick)
	end
end

local function startPlayerLoop(loopName, interval, body)
	task.spawn(function()
		while true do
			task.wait(interval)
			local ok, players = pcall(S.PlayerService.GetReadyPlayers)
			if ok and type(players) == "table" then
				for _, p in players do
					if p.Parent then
						local okBody, err = pcall(body, p)
						if not okBody then
							loopWarn(loopName, err)
						end
					end
				end
			elseif not ok then
				loopWarn(loopName, players)
			end
		end
	end)
end

------------------------------------------------------------------ lifecycle
local function connectSignal(serviceName, signalName, fn)
	local service = S[serviceName]
	local signal = service and service[signalName]
	if type(signal) == "table" and type(signal.Connect) == "function" then
		signal:Connect(fn)
	else
		Util.Warn(TAG, "missing signal " .. serviceName .. "." .. signalName)
	end
end

function CombatService.Init(registry)
	S = registry
	connectSignal("PlayerService", "PlayerReady", onPlayerReady)
	connectSignal("PlayerService", "PlayerLeaving", onPlayerLeaving)
	connectSignal("PlayerService", "CharacterDied", onCharacterDied)
	connectSignal("PlayerService", "CharacterSpawned", onCharacterSpawned)
	connectSignal("FactionService", "FactionChanged", onFactionChanged)
	connectSignal("ClassService", "ClassChanged", onClassChanged)
end

function CombatService.Start()
	Net.Get("Swing").OnServerEvent:Connect(onSwingRemote)
	Net.Get("Release").OnServerEvent:Connect(onReleaseRemote)
	Net.Get("SetAutoAttack").OnServerEvent:Connect(onSetAutoAttackRemote)

	startPlayerLoop("RegenLoop", Config.Combat.RegenTick, regenTick)
	startPlayerLoop("AutoCombatLoop", Config.Combat.AutoTick or 0.2, autoTick)

	print("[CombatService] started")
end

return CombatService
