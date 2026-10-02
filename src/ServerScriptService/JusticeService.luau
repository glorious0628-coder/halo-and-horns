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

local JusticeService = {}

local S = nil
local scaleOf = { Halo = 1, Horns = 1 } -- current S per combat faction
local weakerFaction = "None"
local leaving = {} -- [Player] = true while leaving (excluded from sums)
local lastAppliedS = {} -- [Player] = S last pushed to SizeMult / RefreshCharacter
local lastFaction = {} -- [Player] = faction at the last recompute pass
local targets = {} -- [Player] = last computed visual scale target
local bully = {} -- [Player] = { Stacks: number, Last: number (os.clock) }
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
end

------------------------------------------------------------------ public API
function JusticeService.GetPower(player)
	if not player then return 0 end
	local level = math.max(1, tonumber(player:GetAttribute("Level")) or 1)
	local tier = math.clamp(math.floor(tonumber(player:GetAttribute("WeaponTier")) or 1), 1, Config.MaxWeaponTier)
	local rebirthBonus = tonumber(player:GetAttribute("RebirthBonus")) or 0
	return Config.PowerOf(level, tier, 1 + rebirthBonus)
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
	player:SetAttribute("BullyStacks", b.Stacks)
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
	local haloSum, hornsSum, haloCount, hornsCount = 0, 0, 0, 0
	local entries = {}
	for _, p in S.PlayerService.GetReadyPlayers() do
		if isCounted(p) then
			local f = factionOf(p)
			if f == "Halo" or f == "Horns" then
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
local function onPlayerReady(player)
	leaving[player] = nil
	clearPlayer(player)
	player:SetAttribute("SizeMult", 1)
	player:SetAttribute("BullyStacks", 0)
	player:SetAttribute("VisualScale", 1)
	requestRecompute()
end

local function onPlayerLeaving(player)
	leaving[player] = true
	clearPlayer(player)
	requestRecompute()
	task.delay(LEAVE_FORGET_SECONDS, function()
		leaving[player] = nil
	end)
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
	player:SetAttribute("BullyStacks", b.Stacks)
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
			-- (no shrink, no -15% damage, no "깡패" tag); Halo <-> Horns keeps them
			if player and not isFighterFaction(newFaction) then
				local had = bully[player] ~= nil or (tonumber(player:GetAttribute("BullyStacks")) or 0) > 0
				bully[player] = nil
				if had then
					local ok, err = pcall(function()
						player:SetAttribute("BullyStacks", 0)
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
	-- players removed before they were ever ready never fire PlayerLeaving
	Players.PlayerRemoving:Connect(function(player)
		clearPlayer(player)
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
