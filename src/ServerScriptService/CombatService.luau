-- CombatService.luau : class swing patterns, charge & release ("자동은 장전, 손은 발사"), damage formulas,
-- player damage / heal, regen, auto-attack and the death pipeline (the ONLY KO entry point).
-- Server-authoritative: clients only send Swing / Release / SetAutoAttack intents.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "CombatService"

local CombatService = {}

------------------------------------------------------------------ public signals (top level)
-- info = { Stacks, Auto, Perfect, Center, Radius, Total, MonstersHit, PlayersHit, Healed = { Player } }
CombatService.Released = Util.Signal.new()
-- (victim, amount, attacker) : fired by DamagePlayer only when attacker ~= nil, after the damage
CombatService.PlayerDamaged = Util.Signal.new()

local S = nil

------------------------------------------------------------------ private constants
-- addendum H3 auto-loop yield = Config.Combat.ManualPriority; addendum M3 hint = Config.Text.AutoUnderAttack
-- at most once per Config.Combat.AutoPvPHintCooldown (CombatService.DamagePlayer is the single sender)
local MANUAL_GRACE = 0.2 -- a manual request this close to the swing-ready time is queued (network jitter on "hold")
local MANUAL_QUEUE_RETRIES = 3 -- timer-precision retries for a queued manual swing
local WHIFF_REACH = 12 -- studs in front of the player used as the visual target of a whiffed ranged swing
local LOOP_WARN_INTERVAL = 10 -- seconds between two warnings of the same loop

-- factions that take part in PvP / goose tug (addendum A6: "Neutral" and "None" never do)
local PVP_FACTIONS = { Halo = true, Horns = true }

------------------------------------------------------------------ per-player state (session only)
local charge = {} -- [Player] = stacks (may be fractional)
local perfectUntil = {} -- [Player] = server time (Util.Now) of the PERFECT window end, 0 = none
local nextSwingAt = {} -- [Player] = os.clock() when the next swing is allowed (shared by manual + auto)
local lastSwingAuto = {} -- [Player] = true if the last executed swing was an auto swing
local lastManualAt = {} -- [Player] = os.clock() of the last accepted manual swing request
local pendingManual = {} -- [Player] = true while one queued manual swing waits for the cooldown
local lastDamagedAt = {} -- [Player] = os.clock() of the last damage of any kind
local lastPvPAttacker = {} -- [Player] = { Player = Player, T = os.clock() }
local lastPvPTime = {} -- [Player] = os.clock() of the last PvP damage dealt or received
local autoHintAt = {} -- [Player] = os.clock() of the last M3 hint
local lastLoopWarn = {} -- [loopName] = os.clock()

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

local function chargeCapOf(player)
	local cap = perksOf(player).ChargeCap
	if type(cap) ~= "number" or cap <= 0 then
		cap = Config.Factions.None.ChargeCap
	end
	return cap
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

local function handPosition(character, fallback)
	local hand = Util.FindPart(character, "RightHand", "Right Arm")
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

------------------------------------------------------------------ charge
local function publishCharge(player)
	if player.Parent == nil then
		return
	end
	player:SetAttribute("Charge", charge[player] or 0)
	player:SetAttribute("ChargeCap", chargeCapOf(player))
	player:SetAttribute("PerfectUntil", perfectUntil[player] or 0)
end

local function resetCharge(player)
	charge[player] = 0
	perfectUntil[player] = 0
	publishCharge(player)
end

local function addCharge(player, amount)
	if type(amount) ~= "number" or amount <= 0 then
		return
	end
	if player.Parent == nil then
		return
	end
	local cap = chargeCapOf(player)
	local value = math.min(cap, (charge[player] or 0) + amount)
	charge[player] = value
	if value >= cap and (perfectUntil[player] or 0) == 0 then
		perfectUntil[player] = Util.Now() + Config.Charge.PerfectWindow
	end
	publishCharge(player)
end

------------------------------------------------------------------ target selection
-- alive monsters this player may hit within `radius` (flat) of `point`, nearest first: { { Rec, Pos, Dist } }
-- (addendum C2: always passes the attacking player; personal monsters of other players are filtered here too)
local function monstersNear(player, point, radius)
	local out = {}
	if radius <= 0 then
		return out
	end
	local list = S.MonsterService.GetMonstersInRadius(point, radius, player)
	if type(list) ~= "table" then
		return out
	end
	for _, rec in list do
		if type(rec) == "table" and rec.Alive and (rec.Owner == nil or rec.Owner == player) then
			local root = rec.Root
			if root and root.Parent then
				local pos = root.Position
				local d = Util.FlatDistance(pos, point)
				if d <= radius then
					table.insert(out, { Rec = rec, Pos = pos, Dist = d })
				end
			end
		end
	end
	table.sort(out, byDist)
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
function CombatService.GetDamageMult(attacker, victim)
	local c = cls(attacker)
	local mult = S.JusticeService.GetDamageMult(attacker)
	if type(mult) ~= "number" or mult ~= mult then
		mult = 1
	end
	if victim ~= nil and c.Ranged then
		mult *= (c.PvPMult or 1)
	end
	return mult
end

-- NORMAL per-target monster hit (unrounded), before the 50% immediate rule
function CombatService.ComputeMonsterHit(attacker, allowCrit)
	local c = cls(attacker)
	local level = numAttr(attacker, "Level", 1)
	local tier = numAttr(attacker, "WeaponTier", 1)
	local dmg = Config.WeaponDamage(tier, level)
		* (c.Damage or 1)
		* (1 + CombatService.GetDamageBonus(attacker, nil))
		* CombatService.GetDamageMult(attacker, nil)
	local crit = allowCrit == true and Util.Random:NextNumber() < Config.Combat.CritChance
	if crit then
		dmg *= Config.Combat.CritMult
	end
	return dmg, crit
end

-- NORMAL per-target PvP hit (unrounded): based on the victim's BASE MaxHealth (no Size Justice, no kaiju)
function CombatService.ComputePvPHit(attacker, victim)
	local c = cls(attacker)
	local aLevel = numAttr(attacker, "Level", 1)
	local aTier = numAttr(attacker, "WeaponTier", 1)
	local vLevel = numAttr(victim, "Level", 1)
	local vTier = numAttr(victim, "WeaponTier", 1)
	local vClass = S.ClassService.GetClass(victim)
	local base = Config.MaxHealth(vLevel, faction(victim), vClass) * Config.PvP.HitPctOfMaxHP
	local vWeapon = Config.WeaponDamage(vTier, vLevel)
	local ratio = Config.PvP.PowerRatioMax
	if vWeapon > 0 then
		ratio = Config.WeaponDamage(aTier, aLevel) / vWeapon
	end
	ratio = math.clamp(ratio, Config.PvP.PowerRatioMin, Config.PvP.PowerRatioMax)
	return base
		* ratio
		* (c.Damage or 1)
		* (1 + CombatService.GetDamageBonus(attacker, victim))
		* CombatService.GetDamageMult(attacker, victim)
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

-- attacker nil = monster (or any non-player source)
function CombatService.DamagePlayer(victim, amount, attacker)
	if not isPlayer(victim) or victim.Parent == nil then
		return
	end
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 then
		return
	end
	if attacker ~= nil and (not isPlayer(attacker) or attacker == victim) then
		attacker = nil
	end
	-- addendum A6: Neutral (and unassigned) players never deal or receive player damage
	if attacker and (not PVP_FACTIONS[faction(attacker)] or not PVP_FACTIONS[faction(victim)]) then
		return
	end
	if not Util.IsAlive(victim) then
		return
	end
	local hum = Util.GetHumanoid(victim)
	local root = Util.GetRoot(victim)
	if not hum or not root then
		return
	end

	amount = Util.RoundDamage(amount)
	local now = os.clock()
	lastDamagedAt[victim] = now
	if attacker then
		-- bookkeeping BEFORE the damage so a lethal hit is always credited by the death pipeline
		lastPvPAttacker[victim] = { Player = attacker, T = now }
		tagCombat(victim)
		tagCombat(attacker)
	end

	local rootPos = root.Position
	local before = hum.Health
	hum:TakeDamage(amount) -- respects ForceField
	local applied = before - hum.Health
	S.PlayerService.MarkActive(victim)

	if attacker then
		-- addendum M3: AFK-in-PvP hint for players relying on auto attack
		if
			victim:GetAttribute("AutoAttack") == true
			and now - (autoHintAt[victim] or -math.huge) >= Config.Combat.AutoPvPHintCooldown
		then
			autoHintAt[victim] = now
			Net.Notify(victim, Config.Text.AutoUnderAttack, "bad")
		end
		CombatService.PlayerDamaged:Fire(victim, amount, attacker)
	elseif applied > 0 then
		Net.Fx(victim, "Hurt", { Pos = rootPos, Amount = amount })
	end
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

function CombatService.GetCharge(player)
	return charge[player] or 0
end

------------------------------------------------------------------ lifesteal
local function applyLifesteal(player, perks, total)
	local rate = perks.Lifesteal or 0
	if rate <= 0 or total <= 0 then
		return
	end
	local hum = Util.GetHumanoid(player)
	if not hum or hum.Health <= 0 then
		return
	end
	CombatService.HealPlayer(player, math.min(total * rate, hum.MaxHealth * (perks.LifestealCapPct or 0)))
end

------------------------------------------------------------------ swing (public)
function CombatService.Swing(player, isManual)
	isManual = isManual == true
	if not isPlayer(player) or player.Parent == nil or not Util.IsAlive(player) then
		return
	end
	local character = Util.GetCharacter(player)
	local root = Util.GetRoot(player)
	if not character or not root then
		return
	end

	-- 1. shared swing cooldown (manual + auto)
	local now = os.clock()
	if now < (nextSwingAt[player] or 0) then
		return
	end
	local c = cls(player)
	nextSwingAt[player] = now + (c.SwingInterval or 1)
	lastSwingAuto[player] = not isManual

	local pos = root.Position
	local fac = faction(player)
	local perks = perksOf(player)
	local goosePos = goosePositionFor(player)
	local gooseReach = Config.Goose.HitRadius
	local range = c.Range or 10

	-- 2. select targets by class pattern
	local monsters = {} -- { { Rec, Pos, Dist } }
	local victims = {} -- { { Player, Pos, Dist } }
	local hitGoose = false
	local center = pos
	local radius = range
	local targets = {}

	if c.Pattern == "Splash" then
		radius = c.Splash or 0
		local pickPos, pickDist, pickIsGoose = nil, math.huge, false
		local nearMon = monstersNear(player, pos, range)
		if nearMon[1] then
			pickPos, pickDist = nearMon[1].Pos, nearMon[1].Dist
		end
		if isManual then
			local nearPl = playersNear(player, pos, range)
			if nearPl[1] and nearPl[1].Dist < pickDist then
				pickPos, pickDist = nearPl[1].Pos, nearPl[1].Dist
			end
		end
		if goosePos then
			local d = Util.FlatDistance(goosePos, pos)
			if d <= range + gooseReach and d < pickDist then
				pickPos, pickDist, pickIsGoose = goosePos, d, true
			end
		end
		if pickPos then
			center = pickPos
			monsters = monstersNear(player, center, radius)
			if isManual then
				victims = playersNear(player, center, radius)
			end
			hitGoose = goosePos ~= nil
				and (pickIsGoose or Util.FlatDistance(goosePos, center) <= radius + gooseReach)
		else
			center = forwardPoint(root, math.min(range, WHIFF_REACH)) -- whiff: the orb flies forward
		end
		targets = { center }
	elseif c.Pattern == "Multi" then
		radius = 0
		local maxTargets = c.Targets or 0
		local candidates = {}
		for _, m in monstersNear(player, pos, range) do
			table.insert(candidates, { Kind = "M", Entry = m, Pos = m.Pos, Dist = m.Dist })
		end
		if isManual then
			for _, v in playersNear(player, pos, range) do
				table.insert(candidates, { Kind = "P", Entry = v, Pos = v.Pos, Dist = v.Dist })
			end
		end
		if goosePos then
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
	else -- "Around" (default): everything within Range of self
		monsters = monstersNear(player, pos, range)
		if isManual then
			victims = playersNear(player, pos, range)
		end
		hitGoose = goosePos ~= nil and Util.FlatDistance(goosePos, pos) <= range + gooseReach
	end

	local hits = {}
	local totalDealt, monstersHit, playersHit = 0, 0, 0

	-- 3. monsters: 50% of the normal hit right away (crit rolled per target)
	if #monsters > 0 then
		local base = CombatService.ComputeMonsterHit(player, false)
		for _, m in monsters do
			local rec = m.Rec
			if rec.Alive then
				local crit = Util.Random:NextNumber() < Config.Combat.CritChance
				local d = base * (crit and Config.Combat.CritMult or 1)
				local dealt = Util.RoundDamage(d * Config.Charge.SwingImmediate)
				S.MonsterService.DamageMonster(rec, dealt, player)
				table.insert(hits, { P = m.Pos, A = dealt, C = crit, K = "M" })
				totalDealt += dealt
				monstersHit += 1
			end
		end
	end

	-- 4. players (manual swings only; already validated with CanAttack)
	for _, v in victims do
		local vp = v.Player
		if vp.Parent and Util.IsAlive(vp) then
			local dealt = Util.RoundDamage(CombatService.ComputePvPHit(player, vp) * Config.Charge.SwingImmediate)
			CombatService.DamagePlayer(vp, dealt, player)
			table.insert(hits, { P = v.Pos, A = dealt, C = false, K = "P" })
			totalDealt += dealt
			playersHit += 1
		end
	end
	if playersHit > 0 then
		S.PvPService.BreakProtection(player)
	end

	-- 5. golden goose: no damage, no charge
	if hitGoose and goosePos then
		S.GooseService.RegisterHit(player, isManual)
		table.insert(hits, {
			P = goosePos,
			A = isManual and Config.Goose.ManualCount or Config.Goose.AutoCount,
			C = false,
			K = "G",
		})
	end

	-- 6. charge
	if monstersHit + playersHit > 0 then
		addCharge(player, isManual and (c.ChargeManual or 0) or (c.ChargeAuto or 0))
	end

	-- 7. lifesteal (Horns)
	applyLifesteal(player, perks, totalDealt)

	-- 8. activity
	local anyHit = monstersHit + playersHit > 0 or hitGoose
	if isManual or anyHit then
		S.PlayerService.MarkActive(player)

		-- 9. visuals for everyone (manual whiffs too, with empty Hits)
		Net.Fx(nil, "Swing", {
			UserId = player.UserId,
			Class = c.Id,
			Faction = fac,
			From = handPosition(character, pos),
			Pos = center,
			Radius = radius,
			Targets = targets,
			Hits = hits,
		})
	end
end

------------------------------------------------------------------ release (public)
function CombatService.Release(player, isAuto)
	isAuto = isAuto == true
	if not isPlayer(player) or player.Parent == nil or not Util.IsAlive(player) then
		return
	end
	local root = Util.GetRoot(player)
	if not root then
		return
	end

	-- 1. enough stacks?
	local n = math.floor(charge[player] or 0)
	if n < Config.Charge.MinRelease then
		if isAuto then
			-- defensive: never keep re-triggering an automatic release that cannot happen
			if (perfectUntil[player] or 0) ~= 0 then
				perfectUntil[player] = 0
				publishCharge(player)
			end
		else
			Net.Notify(player, string.format(Config.Text.ReleaseNeed, Config.Charge.MinRelease), "bad")
		end
		return
	end

	local c = cls(player)
	local fac = faction(player)
	local perks = perksOf(player)

	-- 2. PERFECT window (manual only)
	local perfect = (not isAuto) and (perfectUntil[player] or 0) > Util.Now()

	-- 8 (early). consume the charge first so a failure below can never allow a double release
	charge[player] = 0
	perfectUntil[player] = 0
	publishCharge(player)

	-- 3. center + radius
	local pos = root.Position
	local center = pos
	if c.ReleaseCenter == "Target" then
		local range = c.Range or 10
		local bestPos, bestDist = nil, math.huge
		local nearMon = monstersNear(player, pos, range)
		if nearMon[1] then
			bestPos, bestDist = nearMon[1].Pos, nearMon[1].Dist
		end
		if not isAuto then
			local nearPl = playersNear(player, pos, range)
			if nearPl[1] and nearPl[1].Dist < bestDist then
				bestPos, bestDist = nearPl[1].Pos, nearPl[1].Dist
			end
		end
		if bestPos then
			center = bestPos
		end
	end
	local radius = Config.ReleaseRadius(n)
	local releaseMult = c.ReleaseMult or 1

	local hits = {}
	local total, monstersHit, playersHit = 0, 0, 0

	-- 4. monsters (never crit)
	local monsters = monstersNear(player, center, radius)
	if #monsters > 0 then
		local D = CombatService.ComputeMonsterHit(player, false)
		local dealt = Util.RoundDamage(Config.ReleaseDamage(D, n, isAuto) * releaseMult)
		for _, m in monsters do
			if m.Rec.Alive then
				S.MonsterService.DamageMonster(m.Rec, dealt, player)
				table.insert(hits, { P = m.Pos, A = dealt, C = false, K = "M" })
				total += dealt
				monstersHit += 1
			end
		end
	end

	-- 5. players (manual releases only), capped at PvPCapPct of the target's current MaxHealth
	if not isAuto then
		for _, v in playersNear(player, center, radius) do
			local vp = v.Player
			local vHum = Util.GetHumanoid(vp)
			if vp.Parent and vHum and vHum.Health > 0 then
				local D = CombatService.ComputePvPHit(player, vp)
				local raw = math.min(
					Config.ReleaseDamage(D, n, false) * releaseMult,
					Config.Charge.PvPCapPct * vHum.MaxHealth
				)
				local dealt = Util.RoundDamage(raw)
				CombatService.DamagePlayer(vp, dealt, player)
				table.insert(hits, { P = v.Pos, A = dealt, C = false, K = "P" })
				total += dealt
				playersHit += 1
			end
		end
		if playersHit > 0 then
			S.PvPService.BreakProtection(player)
		end
	end

	-- 6. Halo release support: heal Halo allies in the radius (self included), +stacks to OTHER allies.
	-- The stack share needs a release that hit something: otherwise Halo groups could pass charge around
	-- forever in a safe town (MinRelease 10 = HaloAllyStacks 10) and farm Release quests / PERFECT charge.
	-- (The heal is HaloHealPct x total, so a whiff heals nothing anyway.)
	local healed = {}
	local shareStacks = monstersHit + playersHit > 0
	if perks.ReleaseSupport == true and fac == "Halo" then
		for _, a in S.PlayerService.GetReadyPlayers() do
			if a.Parent and faction(a) == "Halo" and Util.IsAlive(a) then
				local aRoot = Util.GetRoot(a)
				local aHum = Util.GetHumanoid(a)
				if aRoot and aHum and Util.FlatDistance(aRoot.Position, center) <= radius then
					local amount = CombatService.HealPlayer(
						a,
						math.min(Config.Charge.HaloHealPct * total, Config.Charge.HaloHealCapPct * aHum.MaxHealth)
					)
					if a ~= player then
						if shareStacks then
							addCharge(a, Config.Charge.HaloAllyStacks)
						end
						if amount > 0 then
							table.insert(healed, a)
						end
					end
				end
			end
		end
	end

	-- 7. lifesteal (Horns) on the total
	applyLifesteal(player, perks, total)

	-- 8. activity (charge already reset above)
	if not isAuto then
		S.PlayerService.MarkActive(player)
	end

	-- 9. visuals + signal
	Net.Fx(nil, "Release", {
		UserId = player.UserId,
		Class = c.Id,
		Faction = fac,
		Pos = center,
		Radius = radius,
		Stacks = n,
		Perfect = perfect,
		Auto = isAuto,
		Total = total,
		Hits = hits,
	})
	CombatService.Released:Fire(player, {
		Stacks = n,
		Auto = isAuto,
		Perfect = perfect,
		Center = center,
		Radius = radius,
		Total = total,
		MonstersHit = monstersHit,
		PlayersHit = playersHit,
		Healed = healed,
	})
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

local function runDeathPipeline(victim)
	if victim.Parent == nil then
		-- the victim already left: leave flows (GrudgeService / ProgressionService) handle it
		lastPvPAttacker[victim] = nil
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

	-- 1. resolve a grudge sack first (no-op without one)
	pipelineCall("GrudgeService.OnCarrierDown", S.GrudgeService.OnCarrierDown, victim, killer)

	-- 2. kaiju / PvP KO / non-PvP death
	local okState, state = pcall(kstate, victim)
	if okState and state == "Active" then
		pipelineCall("KaijuService.HandleKaijuDeath", S.KaijuService.HandleKaijuDeath, victim, killer)
	elseif killer then
		pipelineCall("PvPService.HandleKO", S.PvPService.HandleKO, victim, killer)
	else
		pipelineCall("PvPService.HandleNonPvPDeath", S.PvPService.HandleNonPvPDeath, victim)
	end

	-- 3. reset charge, forget the attacker
	resetCharge(victim)
	lastPvPAttacker[victim] = nil
end

local function onCharacterDied(player, _character)
	if not isPlayer(player) then
		return
	end
	-- deferred so the lethal hit's PlayerDamaged handlers (kaiju damage share, bait log) always run first,
	-- whatever the Workspace.SignalBehavior is
	task.defer(function()
		local ok, err = pcall(runDeathPipeline, player)
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
	charge[player] = 0
	perfectUntil[player] = 0
	nextSwingAt[player] = 0
	lastSwingAuto[player] = false
	player:SetAttribute("AutoAttack", false)
	player:SetAttribute("InCombatUntil", 0)
	publishCharge(player) -- Charge = 0, ChargeCap = perks.ChargeCap, PerfectUntil = 0
end

local function onPlayerLeaving(player, _data)
	-- deferred: other PlayerLeaving handlers (ProgressionService combat-log penalty) still read IsInCombat
	task.defer(function()
		charge[player] = nil
		perfectUntil[player] = nil
		nextSwingAt[player] = nil
		lastSwingAuto[player] = nil
		lastManualAt[player] = nil
		pendingManual[player] = nil
		lastDamagedAt[player] = nil
		lastPvPAttacker[player] = nil
		lastPvPTime[player] = nil
		autoHintAt[player] = nil
	end)
end

local function onFactionChanged(player, _newFaction, _oldFaction, _reason)
	if not isPlayer(player) then
		return
	end
	resetCharge(player) -- also refreshes ChargeCap for the new faction
end

local function onClassChanged(player, _newClass, _oldClass)
	if not isPlayer(player) then
		return
	end
	resetCharge(player)
end

------------------------------------------------------------------ remotes
-- one queued manual swing that fires as soon as the shared cooldown is ready (addendum H3)
local function queueManualSwing(player)
	pendingManual[player] = true
	local tries = 0
	local function attempt()
		if pendingManual[player] ~= true then
			return
		end
		if player.Parent == nil or not S.PlayerService.IsReady(player) then
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
	if not S.PlayerService.IsReady(player) then
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
	elseif lastSwingAuto[player] or remaining <= MANUAL_GRACE then
		-- the cooldown was consumed by an auto swing (or the request is only jitter-early): never drop it
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
	CombatService.Release(player, false) -- MarkActive inside
end

local function onSetAutoAttackRemote(player, enabled)
	if not S.PlayerService.IsReady(player) then
		return
	end
	if type(enabled) ~= "boolean" then
		return
	end
	if not Util.RateLimit(player, "SetAutoAttack", Config.RateLimits.SetAutoAttack) then
		return
	end
	if enabled and numAttr(player, "Level", 1) < Config.Combat.AutoUnlockLevel then
		Net.Notify(player, string.format(Config.Text.AutoLocked, Config.Combat.AutoUnlockLevel), "bad")
		enabled = false
	end
	player:SetAttribute("AutoAttack", enabled)
end

------------------------------------------------------------------ loops
local function autoTick(p)
	if p:GetAttribute("AutoAttack") ~= true then
		return
	end
	if numAttr(p, "Level", 1) < Config.Combat.AutoUnlockLevel then
		p:SetAttribute("AutoAttack", false)
		return
	end
	if not Util.IsAlive(p) then
		return
	end
	-- addendum H3: manual beats auto
	if pendingManual[p] then
		return
	end
	local lm = lastManualAt[p]
	if lm and os.clock() - lm < Config.Combat.ManualPriority then
		return
	end
	if os.clock() < (nextSwingAt[p] or 0) then
		return
	end
	local root = Util.GetRoot(p)
	if not root then
		return
	end
	local c = cls(p)
	local range = c.Range or 10
	local pos = root.Position
	local count = S.MonsterService.CountInRadius(pos, range, p)
	local hasTarget = type(count) == "number" and count > 0
	if not hasTarget then
		local goosePos = goosePositionFor(p)
		hasTarget = goosePos ~= nil and Util.FlatDistance(goosePos, pos) <= range + Config.Goose.HitRadius
	end
	if hasTarget then
		CombatService.Swing(p, false)
	end
end

local function chargeTick(p)
	local pu = perfectUntil[p]
	if pu and pu > 0 and Util.Now() >= pu then
		CombatService.Release(p, true) -- PERFECT window missed: automatic release (x1.5, monsters only)
	end
end

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
	connectSignal("FactionService", "FactionChanged", onFactionChanged)
	connectSignal("ClassService", "ClassChanged", onClassChanged)
end

function CombatService.Start()
	Net.Get("Swing").OnServerEvent:Connect(onSwingRemote)
	Net.Get("Release").OnServerEvent:Connect(onReleaseRemote)
	Net.Get("SetAutoAttack").OnServerEvent:Connect(onSetAutoAttackRemote)

	startPlayerLoop("AutoLoop", Config.Combat.AutoLoopInterval, autoTick)
	startPlayerLoop("ChargeWatcher", Config.Combat.ChargeTick, chargeTick)
	startPlayerLoop("RegenLoop", Config.Combat.RegenTick, regenTick)

	print("[CombatService] started")
end

return CombatService
