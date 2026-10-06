-- JusticeService.luau : Size Justice ("덩치 저울"): faction power sums, per-faction S, bully stacks + decay,
-- and the smooth character scale lerp. The ONLY service that scales characters (always via Util.SafeScaleTo).
-- Addendum A6: "Neutral" players are excluded from power sums / ratios and their S is always 1.0.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "JusticeService"
local DECAY_TICK = 1 -- bully decay loop interval (spec §4.12)
local SCALE_EPSILON = 0.005 -- lerp stops when this close to the target
local S_EPSILON = 0.001 -- a faction S change smaller than this does not refresh characters
local MIN_SCALE = 0.1 -- safety floor for Model:ScaleTo
local SCALE_RETRY_SECONDS = 2 -- after a failed ScaleTo, wait this long before trying that character again
local LEAVE_FORGET_SECONDS = 60
local WARN_THROTTLE = 10
local PIVOT_HEIGHT_AT_SCALE_1 = 3 -- approx. root-center height above the feet for R6 and R15 at scale 1
-- CR-M20: who adds power to the faction sums (everyone still gets their side's S)
local COUNT_RULE = {
	IdleSeconds = 120, -- no input / combat for this long (PlayerService.GetLastActive) = not counted
	TownSeconds = 60, -- standing in a town for this long = not counted
}

local JusticeService = {}

local S = nil
local scaleOf = { Halo = 1, Horns = 1 } -- current S per combat faction
local weakerFaction = "None"
local leaving = {} -- [Player] = true while leaving (excluded from sums)
local lastAppliedS = {} -- [Player] = S last pushed to SizeMult / RefreshCharacter
local lastFaction = {} -- [Player] = faction at the last recompute pass
local targets = {} -- [Player] = last computed visual scale target
local bully = {} -- [Player] = { Stacks: number, Last: number (os.clock) }
local townSince = {} -- [Player] = os.clock() when the player entered a town (nil outside towns), CR-M20
local hipBase = setmetatable({}, { __mode = "k" }) -- [Character] = R15 HipHeight at scale 1
local scaleFailUntil = setmetatable({}, { __mode = "k" }) -- [Character] = os.clock()
local recomputePending = false
local lastWarnAt = {}

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	local last = lastWarnAt[key]
	if last and now - last < WARN_THROTTLE then return end
	lastWarnAt[key] = now
	Util.Warn(TAG, tostring(msg))
end

local function round2(x)
	return math.floor(x * 100 + 0.5) / 100
end

local function factionOf(player)
	if S and S.FactionService and S.FactionService.GetFaction then
		return S.FactionService.GetFaction(player)
	end
	local f = player and player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function kaijuState(player)
	local k = S and S.KaijuService
	if k and k.GetState then
		local ok, st = pcall(k.GetState, player)
		if ok and type(st) == "string" then return st end
	end
	return "None"
end

local function isCounted(player)
	return player ~= nil and player.Parent == Players and not leaving[player]
end

-- only Halo / Horns can be bullies (A6: Neutral never gets bully stacks; "None" has not picked a side)
local function isFighterFaction(factionId)
	return factionId == "Halo" or factionId == "Horns"
end

local function computeTarget(player)
	local s = JusticeService.GetFactionScale(factionOf(player)) * Config.BullyMult(JusticeService.GetBullyStacks(player))
	if kaijuState(player) == "Active" then
		s *= Config.Kaiju.VisualScale
	end
	return math.max(MIN_SCALE, math.min(Config.Justice.MaxVisualScale, s))
end

local function writeVisualScale(player, scale)
	local v = round2(scale)
	if player:GetAttribute("VisualScale") ~= v then
		player:SetAttribute("VisualScale", v)
	end
end

-- R15 hover height does not follow the body when scaled at runtime; keep it proportional (no-op if ScaleTo did it).
local function fixHipHeight(character, scale)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then return end
	local base = hipBase[character]
	if not base or base <= 0 then return end
	local want = base * scale
	if math.abs(hum.HipHeight - want) > 0.01 then
		hum.HipHeight = want
	end
end

local function rememberHipBase(character)
	if hipBase[character] then return end
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then return end
	local cur = character:GetScale()
	if cur > 0 then
		hipBase[character] = hum.HipHeight / cur
	end
end

-- applies `scale` to the character; returns true on success
local function applyScale(character, scale)
	local blockedUntil = scaleFailUntil[character]
	if blockedUntil and os.clock() < blockedUntil then return false end
	if Util.SafeScaleTo(character, scale) then
		fixHipHeight(character, scale)
		return true
	end
	scaleFailUntil[character] = os.clock() + SCALE_RETRY_SECONDS
	return false
end

local function requestRecompute()
	if recomputePending then return end
	recomputePending = true
	task.defer(function()
		recomputePending = false
		local ok, err = pcall(JusticeService.Recompute)
		if not ok then warnThrottled("recompute", "recompute failed: " .. tostring(err)) end
	end)
end

local function clearPlayer(player)
	lastAppliedS[player] = nil
	lastFaction[player] = nil
	targets[player] = nil
	bully[player] = nil
	townSince[player] = nil
end

-- CR-M20: keep townSince in step with the zone (also covers spawning in Crossroads, which fires no ZoneChanged)
local function syncTown(player, now)
	local zs = S and S.ZoneService
	if not zs or not zs.IsTown then return end
	local ok, inTown = pcall(zs.IsTown, player)
	if not ok then return end
	if inTown == true then
		townSince[player] = townSince[player] or now
	else
		townSince[player] = nil
	end
end

-- CR-M20: rookies, 120 s idlers and 60 s town loiterers add no power to the faction sums
local function countsForSums(player, now)
	syncTown(player, now)
	local pvp = S.PvPService
	if pvp and pvp.IsRookie then
		local ok, rookie = pcall(pvp.IsRookie, player)
		if ok and rookie == true then return false end
	end
	local ps = S.PlayerService
	if ps.GetLastActive then
		local ok, t = pcall(ps.GetLastActive, player)
		if ok and type(t) == "number" and now - t > COUNT_RULE.IdleSeconds then return false end
	end
	local since = townSince[player]
	return not (since and now - since >= COUNT_RULE.TownSeconds)
end

-- level, equipped weapon tier and its scroll +N (review B5: the server-written WeaponEnhance attribute;
-- Config.EnhanceMult clamps it to 0..Config.Loot.MaxEnhance and treats a missing value as +0)
local function levelAndTier(player)
	local level = math.max(1, tonumber(player:GetAttribute("Level")) or 1)
	local tier = math.clamp(math.floor(tonumber(player:GetAttribute("WeaponTier")) or 0), 0, Config.MaxWeaponTier) -- A23-34: 0 = bare hands
	local enhance = tonumber(player:GetAttribute("WeaponEnhance")) or 0
	return level, tier, enhance
end

------------------------------------------------------------------ public API
-- faction-sum power (includes the rebirth bonus)
function JusticeService.GetPower(player)
	if not player then return 0 end
	local level, tier, enhance = levelAndTier(player)
	local rebirthBonus = tonumber(player:GetAttribute("RebirthBonus")) or 0
	return Config.PowerOf(level, tier, 1 + rebirthBonus, enhance)
end

-- BB4 "전투력" (integer, Config.CombatPower): the weak-victim (bully) rule and the boldness ratios compare it.
-- CR-L5: the rebirth bonus is gold / XP only, so it is left out
function JusticeService.GetCombatPower(player)
	if not player then return 0 end
	local level, tier, enhance = levelAndTier(player)
	return Config.CombatPower(level, tier, enhance)
end

-- BB4: the CombatPower attribute follows Level / WeaponTier / WeaponEnhance. One deferred refresh per frame, because
-- LootService writes WeaponEnhance right after WeaponTier (an equip changes the attribute exactly once).
local POWER = { Conns = {}, Pending = {} }

function POWER.Refresh(player)
	POWER.Pending[player] = nil
	if player.Parent == nil or not POWER.Conns[player] then return end
	local n = JusticeService.GetCombatPower(player)
	if player:GetAttribute("CombatPower") ~= n then player:SetAttribute("CombatPower", n) end
end

function POWER.Schedule(player)
	if POWER.Pending[player] then return end
	POWER.Pending[player] = true
	task.defer(POWER.Refresh, player)
end

function POWER.Drop(player)
	for _, c in POWER.Conns[player] or {} do c:Disconnect() end
	POWER.Conns[player], POWER.Pending[player] = nil, nil
end

function POWER.Watch(player)
	POWER.Drop(player)
	local list = {}
	for _, attr in { "Level", "WeaponTier", "WeaponEnhance" } do
		table.insert(list, player:GetAttributeChangedSignal(attr):Connect(function() POWER.Schedule(player) end))
	end
	POWER.Conns[player] = list
	POWER.Refresh(player)
end

-- 1 for "None" and "Neutral" (A6)
function JusticeService.GetFactionScale(factionId)
	if factionId == "Halo" or factionId == "Horns" then
		return scaleOf[factionId] or 1
	end
	return 1
end

function JusticeService.GetWeakerFaction()
	return weakerFaction
end

function JusticeService.GetDamageMult(player)
	return JusticeService.GetFactionScale(factionOf(player)) * Config.BullyMult(JusticeService.GetBullyStacks(player))
end

function JusticeService.GetHealthMult(player)
	local mult = JusticeService.GetFactionScale(factionOf(player))
	local k = S and S.KaijuService
	if k and k.GetHealthMult then
		local ok, km = pcall(k.GetHealthMult, player)
		if ok and type(km) == "number" and km > 0 then
			mult *= km
		end
	end
	return mult
end

function JusticeService.GetBullyStacks(player)
	local b = player and bully[player]
	return b and b.Stacks or 0
end

-- A23-22: os.time() when the last stack decays (0 = no penalty); the HUD shows "(N분)" from it.
-- The BullyStacks attribute and this one are written together through publishBully.
local function publishBully(player, b)
	local stacks = b and b.Stacks or 0
	local endsAt = 0
	if stacks > 0 then
		local period = math.max(1, tonumber(Config.Bully.DecaySeconds) or 300)
		local left = (stacks - 1) * period + math.max(0, period - (os.clock() - b.Last))
		endsAt = os.time() + math.ceil(left)
	end
	player:SetAttribute("BullyStacks", stacks)
	player:SetAttribute("BullyEndsAt", endsAt)
end

function JusticeService.AddBullyStack(player)
	if not player then return 0 end
	if not isFighterFaction(factionOf(player)) then return 0 end -- A6: Neutral / None never become bullies
	local b = bully[player]
	if not b then
		b = { Stacks = 0, Last = os.clock() }
		bully[player] = b
	end
	b.Stacks = math.min(Config.Bully.MaxStacks, b.Stacks + 1)
	b.Last = os.clock()
	publishBully(player, b)
	JusticeService.RefreshScale(player)
	return b.Stacks
end

-- recompute this player's visual scale target now (the scale loop moves the character toward it)
function JusticeService.RefreshScale(player)
	if not player then return end
	targets[player] = computeTarget(player)
end

function JusticeService.Recompute()
	if not S then return end
	local now = os.clock()
	local haloSum, hornsSum, haloCount, hornsCount = 0, 0, 0, 0
	local entries = {}
	for _, p in S.PlayerService.GetReadyPlayers() do
		if isCounted(p) then
			local f = factionOf(p)
			-- CR-M20: excluded players still get an entry below (and so their side's S)
			if (f == "Halo" or f == "Horns") and countsForSums(p, now) then
				local ok, power = pcall(JusticeService.GetPower, p)
				power = (ok and type(power) == "number") and power or 0
				if f == "Halo" then
					haloSum += power
					haloCount += 1
				else
					hornsSum += power
					hornsCount += 1
				end
			end
			table.insert(entries, { Player = p, Faction = f })
		end
	end

	local sHalo, sHorns = 1, 1
	if haloCount >= 1 and hornsCount >= 1 then
		sHalo = Config.SizeJustice(haloSum, hornsSum)
		sHorns = Config.SizeJustice(hornsSum, haloSum)
	end
	scaleOf.Halo, scaleOf.Horns = sHalo, sHorns

	-- an empty faction counts as 0; "None" if both sums are 0 or equal
	if (haloSum == 0 and hornsSum == 0) or haloSum == hornsSum then
		weakerFaction = "None"
	elseif haloSum < hornsSum then
		weakerFaction = "Halo"
	else
		weakerFaction = "Horns"
	end

	local gs = Net.GameState()
	gs:SetAttribute("HaloPower", math.floor(haloSum + 0.5))
	gs:SetAttribute("HornsPower", math.floor(hornsSum + 0.5))
	gs:SetAttribute("HaloSize", round2(sHalo))
	gs:SetAttribute("HornsSize", round2(sHorns))
	gs:SetAttribute("WeakerFaction", weakerFaction)

	for _, e in entries do
		local p, f = e.Player, e.Faction
		local s = JusticeService.GetFactionScale(f)
		local prev = lastAppliedS[p]
		if lastFaction[p] ~= f or prev == nil or math.abs(prev - s) > S_EPSILON then
			lastAppliedS[p] = s
			lastFaction[p] = f
			local ok, err = pcall(function()
				p:SetAttribute("SizeMult", round2(s))
				S.PlayerService.RefreshCharacter(p, false) -- HP % preserved
				JusticeService.RefreshScale(p)
			end)
			if not ok then warnThrottled("apply", "apply S failed: " .. tostring(err)) end
		end
	end
end

------------------------------------------------------------------ subscriptions
-- CR-M12: bring back the stacks saved at the last leave, minus the decay that would have happened meanwhile
local function restoreBully(player, data)
	if type(data) ~= "table" then return end
	local saved = math.floor(tonumber(data.SavedBully) or 0)
	local at = tonumber(data.SavedBullyAt) or 0
	-- one-shot: a crash before the next leave must not bring them back a second time
	data.SavedBully, data.SavedBullyAt = 0, 0
	if saved <= 0 or at <= 0 then return end
	if not isFighterFaction(data.Faction) then return end -- A6: only Halo / Horns carry stacks
	local period = math.max(1, tonumber(Config.Bully.DecaySeconds) or 300)
	local elapsed = math.max(0, os.time() - at)
	local decayed = math.floor(elapsed / period)
	local stacks = math.min(Config.Bully.MaxStacks, saved - decayed)
	if stacks <= 0 then return end
	-- keep the running decay period: the next stack drops `period` after the last drop, not after the join
	bully[player] = { Stacks = stacks, Last = os.clock() - (elapsed - decayed * period) }
	publishBully(player, bully[player])
	JusticeService.RefreshScale(player)
end

local function onPlayerReady(player, data)
	leaving[player] = nil
	clearPlayer(player)
	player:SetAttribute("SizeMult", 1)
	player:SetAttribute("BullyStacks", 0)
	player:SetAttribute("BullyEndsAt", 0)
	player:SetAttribute("VisualScale", 1)
	local ok, err = pcall(restoreBully, player, data)
	if not ok then warnThrottled("bullyrestore", "bully restore failed: " .. tostring(err)) end
	POWER.Watch(player)
	requestRecompute()
end

local function onPlayerLeaving(player, data)
	leaving[player] = true
	POWER.Drop(player)
	-- CR-M12: save the stacks; SavedBullyAt = os.time() of the start of the running decay period
	if type(data) == "table" then
		local b = bully[player]
		local stacks = JusticeService.GetBullyStacks(player)
		local into = (stacks > 0 and b) and math.floor(math.max(0, os.clock() - b.Last)) or 0
		data.SavedBully = stacks
		data.SavedBullyAt = os.time() - into
	end
	requestRecompute()
	-- CR-L1: later PlayerLeaving handlers (PvP bounty CR-M11) still read the stacks; clear after them
	task.defer(clearPlayer, player)
	task.delay(LEAVE_FORGET_SECONDS, function()
		leaving[player] = nil
	end)
end

-- CR-M20: town entry time (the 60 s town rule); leaving a town or crossing the 60 s mark re-weighs the sums
local function onZoneChanged(player, newZoneId)
	if not player or leaving[player] then return end
	local zone = Config.Zones[newZoneId]
	if zone and zone.Town == true then
		if townSince[player] then return end -- town to town keeps the clock
		local t = os.clock()
		townSince[player] = t
		task.delay(COUNT_RULE.TownSeconds + 0.5, function()
			if townSince[player] == t then requestRecompute() end
		end)
	else
		local was = townSince[player]
		townSince[player] = nil
		if was and os.clock() - was >= COUNT_RULE.TownSeconds then requestRecompute() end
	end
end

-- fresh characters start at scale 1: snap straight to the target (no lerp)
local function onCharacterSpawned(player, character)
	if not player or not character or not character.Parent then return end
	if player.Character ~= character then return end
	rememberHipBase(character)
	local target = computeTarget(player)
	targets[player] = target
	local cur = character:GetScale()
	if math.abs(target - cur) > SCALE_EPSILON and applyScale(character, target) then
		if target > cur then
			-- CR-H2: a server-side move; the spawn grace (not the shorter default) so ZoneService's own one is not cut
			local zs = S and S.ZoneService
			if zs and zs.MarkTeleported then
				local ac = Config.AntiCheat
				pcall(zs.MarkTeleported, player, (ac and tonumber(ac.SpawnGrace)) or 2)
			end
			-- ScaleTo keeps the pivot (root) in place, so the longer legs would start inside the floor: lift by the growth
			pcall(function()
				character:PivotTo(character:GetPivot() + Vector3.new(0, (target - cur) * PIVOT_HEIGHT_AT_SCALE_1, 0))
			end)
		end
		cur = target
	end
	writeVisualScale(player, cur)
end

------------------------------------------------------------------ loops
local function scaleStep(player, step)
	if not Util.IsAlive(player) then return end
	local character = Util.GetCharacter(player)
	if not character then return end
	local target = computeTarget(player)
	targets[player] = target
	local cur = character:GetScale()
	local diff = target - cur
	if math.abs(diff) <= SCALE_EPSILON then
		writeVisualScale(player, cur)
		return
	end
	rememberHipBase(character)
	local new = cur + math.clamp(diff, -step, step)
	if applyScale(character, new) then
		writeVisualScale(player, new)
	end
end

local function decayStep(player, b)
	if b.Stacks <= 0 then return end
	if os.clock() - b.Last < Config.Bully.DecaySeconds then return end
	b.Stacks -= 1
	b.Last = os.clock()
	if player.Parent ~= Players then return end
	publishBully(player, b)
	Net.Notify(player, string.format(Config.Text.BullyDecay, b.Stacks), "info")
	JusticeService.RefreshScale(player)
end

function JusticeService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(onPlayerReady)
	S.PlayerService.PlayerLeaving:Connect(onPlayerLeaving)
	S.PlayerService.CharacterSpawned:Connect(onCharacterSpawned)
	if S.FactionService and S.FactionService.FactionChanged then
		S.FactionService.FactionChanged:Connect(function(player, newFaction)
			-- A6: a bully who switches to Neutral (altar / rebirth) sheds the stacks at once
			-- (no shrink, no -15% damage, no "깡패" tag); Halo <-> Horns keeps them.
			-- CR-L9: the altar and rebirth refuse Neutral while stacks remain, so this is only a safety net
			if player and not isFighterFaction(newFaction) then
				local had = bully[player] ~= nil or (tonumber(player:GetAttribute("BullyStacks")) or 0) > 0
				bully[player] = nil
				if had then
					local ok, err = pcall(function()
						publishBully(player, nil)
						JusticeService.RefreshScale(player)
					end)
					if not ok then warnThrottled("bullyclear", "bully clear failed: " .. tostring(err)) end
				end
			end
			requestRecompute()
		end)
	end
	if S.ClassService and S.ClassService.ClassChanged then
		S.ClassService.ClassChanged:Connect(function()
			requestRecompute()
		end)
	end
	if S.ProgressionService and S.ProgressionService.Rebirthed then
		S.ProgressionService.Rebirthed:Connect(function()
			requestRecompute()
		end)
	end
	if S.ZoneService and S.ZoneService.ZoneChanged then
		S.ZoneService.ZoneChanged:Connect(onZoneChanged) -- CR-M20
	end
	-- players removed before they were ever ready never fire PlayerLeaving
	-- CR-L1: a ready player is cleared by onPlayerLeaving (deferred, after the other leave handlers)
	Players.PlayerRemoving:Connect(function(player)
		if not S.PlayerService.IsReady(player) then
			clearPlayer(player)
		end
	end)
end

function JusticeService.Start()
	-- periodic recompute
	task.spawn(function()
		while true do
			task.wait(Config.Justice.RecalcInterval)
			local ok, err = pcall(JusticeService.Recompute)
			if not ok then warnThrottled("recompute", "recompute failed: " .. tostring(err)) end
		end
	end)

	-- smooth scale lerp
	task.spawn(function()
		local interval = Config.Justice.ScaleTick
		local step = Config.Justice.ScaleRatePerSec * interval -- max scale change per tick
		while true do
			task.wait(interval)
			for _, p in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(scaleStep, p, step)
				if not ok then warnThrottled("scale", "scale step failed: " .. tostring(err)) end
			end
		end
	end)

	-- bully stack decay
	task.spawn(function()
		while true do
			task.wait(DECAY_TICK)
			for p, b in bully do
				local ok, err = pcall(decayStep, p, b)
				if not ok then warnThrottled("decay", "bully decay failed: " .. tostring(err)) end
			end
		end
	end)

	requestRecompute()
	print("[JusticeService] started")
end

return JusticeService
