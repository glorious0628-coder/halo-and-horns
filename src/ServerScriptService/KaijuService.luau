-- KaijuService.luau : wanted kaiju ("수배범 괴수화") — FIFO queue, server siren, kaiju HP/scale, stomp,
-- participants, reward pool, survive reward.
-- Owner: G9. Public surface (TECH_SPEC §4.15): KaijuStarted, KaijuEnded, Init, Start, GetState, GetActive,
-- GetHealthMult, HandleKaijuDeath.
-- SPEC_ADDENDUM A6: only Horns players can become a kaiju; only Halo players are stomped, count as participants
-- or get rewards (Neutral / None never take part).
-- Review fixes (anti-collusion, minted gold only; carried gold is a transfer and always moves as specced):
--  * Survived: the +50% bonus needs real opposition (a Halo participant, a stomped Halo player or a Halo player within
--    NearbyRadius at an HP recalc) and is capped at SURVIVE_BONUS_MINUTES of hunting value at the kaiju's level.
--  * Defeated without a Halo player's lethal hit (reset / fall / monster): the minted 3x bounty is scaled by the share of
--    the kaiju's MaxHealth that Halo players actually took off. A real kill pays the full pool.
--  * Each participant gets the minted part of a pool share at most once per Config.PvP.PairRewardCooldown per kaiju player.
-- A11-R1: the stomp's ground raycast includes only Terrain, workspace.Map.Ground and Map.Decor "Bridge_*" models.
-- A12: a transformed kaiju may zoom out to KAIJU_CAMERA_ZOOM; the previous limit is restored when the event ends.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "KaijuService"
local WARN_INTERVAL = 10
local GROUND_RAY_LENGTH = 120
local KAIJU_CAMERA_ZOOM = 60 -- A12: "kaiju may use 60 while transformed, then restore"
-- candidates for Config.Kaiju (G1): survive bonus cap in minutes of Config.HuntValue at the kaiju's level
local SURVIVE_BONUS_MINUTES = 20
local TXT_SURVIVE_CAPPED = "살아남았다! 주머니 골드 + 보너스(최대치) = %s골드가 금고로!"
local TXT_SURVIVE_UNCONTESTED = "살아남았다! 아무도 막지 않아 보너스 없이 %s골드만 금고로."

local KaijuService = {}
KaijuService.KaijuStarted = Util.Signal.new() -- (player)
KaijuService.KaijuEnded = Util.Signal.new() -- (player, outcome: "Defeated" | "Survived" | "Cancelled", participants: { Player })

local S = nil
local gameState = nil

local states = {} -- [Player] = "Queued" | "Siren" | "Active" (absent = "None")
local queue = {} -- FIFO of Players in state "Queued"
local current = nil -- the Siren/Active player
local phase = "None" -- "None" | "Siren" | "Active"
local phaseEndsAt = 0 -- server time: end of the siren (Siren) or of the kaiju (Active)
local kaijuName = ""
local healthMult = 1 -- cached Active health multiplier
local dmg = {} -- [Player] = damage dealt to the Active kaiju (Halo attackers)
local healers = {} -- [Player] = true: Halo players whose release healed a damager
local lastRecalc = 0 -- os.clock()
local lastStomp = 0 -- os.clock()
local contested = false -- a Halo player was near / stomped by / fighting the Active kaiju
local lethalHit = false -- a Halo player's hit dropped the Active kaiju to 0 HP (false = reset, fall, monster, ...)
local lastMaxHealth = 0 -- the Active kaiju's MaxHealth, sampled every tick
local poolPaidAt = {} -- ["participantUserId:kaijuUserId"] = os.clock() of the last minted pool share
local zoomRestore = {} -- [Player] = CameraMaxZoomDistance before the kaiju zoom was raised

local lastWarnAt = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include -- A11-R1

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (lastWarnAt[key] or -math.huge) >= WARN_INTERVAL then
		lastWarnAt[key] = now
		Util.Warn(TAG, tostring(msg))
	end
end

-- pcall-protected call into another service; returns its FIRST result, or nil (and warns, throttled) on failure
local function call(serviceName, fnName, ...)
	local svc = S and S[serviceName]
	local fn = svc and svc[fnName]
	if type(fn) ~= "function" then
		warnThrottled(serviceName .. "." .. fnName, "missing " .. serviceName .. "." .. fnName)
		return nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warnThrottled(serviceName .. "." .. fnName, serviceName .. "." .. fnName .. " failed: " .. tostring(result))
		return nil
	end
	return result
end

local function getGameState()
	if gameState and gameState.Parent then return gameState end
	local ok, gs = pcall(Net.GameState)
	if ok and gs then gameState = gs end
	return gameState
end

local function publish(phaseName, userId, name, endsAt)
	local gs = getGameState()
	if not gs then return end
	gs:SetAttribute("KaijuUserId", userId)
	gs:SetAttribute("KaijuName", name)
	gs:SetAttribute("KaijuEndsAt", endsAt)
	gs:SetAttribute("KaijuPhase", phaseName) -- last, so clients see a consistent set when the phase flips
end

local function isPlayer(p)
	return typeof(p) == "Instance" and p:IsA("Player")
end

local function isReady(p)
	return isPlayer(p) and p.Parent ~= nil and call("PlayerService", "IsReady", p) == true
end

local function factionOf(p)
	local f = call("FactionService", "GetFaction", p)
	if type(f) ~= "string" then return "None" end
	return f
end

local function starsOf(p)
	return tonumber(call("PvPService", "GetStars", p)) or 0
end

-- persisted numeric stat: live data table first, mirrored attribute as fallback
local function getNum(p, key)
	local data = call("PlayerService", "GetData", p)
	local v = (type(data) == "table") and data[key] or nil
	if type(v) ~= "number" then v = p:GetAttribute(key) end
	return tonumber(v) or 0
end

local function readyPlayers()
	local list = call("PlayerService", "GetReadyPlayers")
	if type(list) ~= "table" then return {} end
	return list
end

local function setState(p, st)
	if st == "None" then
		states[p] = nil
	else
		states[p] = st
	end
	if isPlayer(p) and p.Parent then
		p:SetAttribute("KaijuState", st)
	end
end

local function removeFromQueue(p)
	local idx = table.find(queue, p)
	while idx do
		table.remove(queue, idx)
		idx = table.find(queue, p)
	end
end

-- eligible to queue / transform: in game, ready, Horns, enough Wanted stars
local function isEligible(p)
	return isReady(p) and factionOf(p) == "Horns" and starsOf(p) >= Config.Kaiju.StarsNeeded
end

local function countNearbyHalo(p)
	local root = Util.GetRoot(p)
	if not root then return 0 end
	local pos = root.Position
	local n = 0
	for _, v in readyPlayers() do
		if v ~= p and factionOf(v) == "Halo" and Util.IsAlive(v) then
			local r = Util.GetRoot(v)
			if r and Util.FlatDistance(r.Position, pos) <= Config.Kaiju.NearbyRadius then
				n += 1
			end
		end
	end
	return n
end

local function computeHealthMult(p)
	local nearby = countNearbyHalo(p)
	if nearby > 0 and phase == "Active" then
		contested = true
	end
	return Config.Kaiju.HPMult * (1 + Config.Kaiju.HPPerNearbyHalo * nearby)
end

-- A11-R1: ground = Terrain + workspace.Map.Ground + bridge models (workspace.Map.Decor children named "Bridge_*")
local function groundTargets()
	local list = { workspace.Terrain }
	local map = workspace:FindFirstChild("Map")
	if map then
		local ground = map:FindFirstChild("Ground")
		if ground then table.insert(list, ground) end
		local decor = map:FindFirstChild("Decor")
		if decor then
			for _, child in decor:GetChildren() do
				if string.sub(child.Name, 1, 7) == "Bridge_" then
					table.insert(list, child)
				end
			end
		end
	end
	return list
end

-- ground point below a position (for the stomp ring); falls back to the map ground plane (Y = 0)
local function groundBelow(pos)
	rayParams.FilterDescendantsInstances = groundTargets()
	local hit = workspace:Raycast(pos, Vector3.new(0, -GROUND_RAY_LENGTH, 0), rayParams)
	if hit then return hit.Position end
	return Vector3.new(pos.X, 0, pos.Z)
end

local function sampleMaxHealth(p)
	local hum = Util.GetHumanoid(p)
	if hum and hum.MaxHealth > 0 then
		lastMaxHealth = hum.MaxHealth
	end
end

-- A12: let the 3x kaiju see around itself; remembers the previous limit for restoreZoom
local function raiseZoom(p)
	local ok, err = pcall(function()
		local prev = p.CameraMaxZoomDistance
		if prev < KAIJU_CAMERA_ZOOM then
			zoomRestore[p] = prev
			p.CameraMaxZoomDistance = KAIJU_CAMERA_ZOOM
		end
	end)
	if not ok then warnThrottled("zoom", "kaiju zoom failed: " .. tostring(err)) end
end

local function restoreZoom(p)
	local prev = zoomRestore[p]
	zoomRestore[p] = nil
	if prev == nil or not isPlayer(p) or p.Parent == nil then return end
	pcall(function()
		if p.CameraMaxZoomDistance == KAIJU_CAMERA_ZOOM then -- untouched since raiseZoom
			p.CameraMaxZoomDistance = prev
		end
	end)
end

-- Halo players still in game who damaged the Active kaiju, plus Halo players who healed (via release) such a damager
local function participantList()
	local list, seen = {}, {}
	local function consider(p)
		if seen[p] then return end
		seen[p] = true
		if isReady(p) and factionOf(p) == "Halo" then
			table.insert(list, p)
		end
	end
	for p, amount in dmg do
		if type(amount) == "number" and amount > 0 then consider(p) end
	end
	for p in healers do
		consider(p)
	end
	return list
end

------------------------------------------------------------------ lifecycle
-- ends the current event for `p`; `leaving` = the player is being removed (skip per-player calls)
local function finish(p, outcome, participants, leaving)
	participants = participants or participantList()
	local inGame = isPlayer(p) and p.Parent ~= nil and not leaving

	-- clear the server-wide event FIRST so a failure below can never repeat the outcome on the next tick
	local wasCurrent = (p == current)
	if wasCurrent then
		current = nil
		phase = "None"
		phaseEndsAt = 0
		kaijuName = ""
		healthMult = 1
		contested = false
		lethalHit = false
		lastMaxHealth = 0
	end
	states[p] = nil

	if inGame then
		call("PvPService", "ResetStars", p)
		p:SetAttribute("KaijuState", "None")
		restoreZoom(p)
	else
		zoomRestore[p] = nil
	end
	if wasCurrent then
		local ok, err = pcall(publish, "None", 0, "", 0)
		if not ok then warnThrottled("publish", "GameState reset failed: " .. tostring(err)) end
	end

	if inGame then
		call("JusticeService", "RefreshScale", p)
		if Util.IsAlive(p) then
			call("PlayerService", "RefreshCharacter", p, false)
			call("PvPService", "Protect", p, Config.Kaiju.ShieldSeconds)
		end
	end

	KaijuService.KaijuEnded:Fire(p, outcome, participants)
	dmg = {}
	healers = {}
end

local function beginSiren()
	while current == nil and #queue > 0 do
		local p = table.remove(queue, 1)
		if states[p] == "Queued" and isEligible(p) then
			current = p
			phase = "Siren"
			kaijuName = p.DisplayName
			phaseEndsAt = Util.Now() + Config.Kaiju.SirenSeconds
			dmg = {}
			healers = {}
			contested = false
			lethalHit = false
			lastMaxHealth = 0
			setState(p, "Siren")
			publish("Siren", p.UserId, kaijuName, phaseEndsAt)
			Net.NotifyAll(string.format(Config.Story.KaijuSiren, kaijuName), "announce", Config.Kaiju.SirenSeconds)
		elseif states[p] == "Queued" then
			setState(p, "None")
		end
	end
end

local function activate(p)
	phase = "Active"
	phaseEndsAt = Util.Now() + Config.Kaiju.Duration
	dmg = {}
	healers = {}
	contested = false
	lethalHit = false
	lastMaxHealth = 0
	healthMult = computeHealthMult(p) -- phase is "Active": a Halo player already nearby marks the event contested
	lastRecalc = os.clock()
	lastStomp = os.clock()
	setState(p, "Active") -- before Justice/Player refresh: they read GetState / GetHealthMult
	publish("Active", p.UserId, kaijuName, phaseEndsAt)
	call("JusticeService", "RefreshScale", p) -- x3 visual (capped by Config.Justice.MaxVisualScale)
	call("PlayerService", "RefreshCharacter", p, true) -- full heal at the transformation
	sampleMaxHealth(p)
	raiseZoom(p)
	Net.NotifyAll(string.format(Config.Story.KaijuStart, kaijuName))
	KaijuService.KaijuStarted:Fire(p)
end

local function survive(p)
	local name = kaijuName
	local participants = participantList()
	local opposed = contested or #participants > 0
	local ok, err = pcall(function()
		-- bonus cap first (pure math), so nothing below can fail after the carried gold was taken
		local level = math.max(1, math.floor(getNum(p, "Level")))
		local okCap, capGold = pcall(Config.HuntValue, level, SURVIVE_BONUS_MINUTES)
		capGold = (okCap and tonumber(capGold)) or 0
		local carried = math.max(0, math.floor(getNum(p, "CarriedGold")))
		local taken = math.max(0, math.floor(tonumber(call("ProgressionService", "TakeCarriedGold", p, carried)) or 0))
		local fullBonus = math.max(0, math.floor(taken * Config.Kaiju.SurviveBankMult) - taken) -- minted part
		local bonus = opposed and math.min(fullBonus, math.max(0, math.floor(capGold))) or 0
		local amount = taken + bonus
		if amount > 0 then
			call("ProgressionService", "AddBankGold", p, amount, "Kaiju")
		end
		p:SetAttribute("SessionTitle", Config.Story.SurviveTitle) -- session only
		call("WarService", "AddFactionPoints", "Horns", Config.Kaiju.HornsWarPoints)
		local text = Config.Text.KaijuSurviveReward
		if not opposed then
			text = TXT_SURVIVE_UNCONTESTED
		elseif bonus < fullBonus then
			text = TXT_SURVIVE_CAPPED
		end
		Net.Notify(p, string.format(text, Util.FormatNumber(amount)), "reward")
		Net.NotifyAll(string.format(Config.Story.KaijuSurvived, name))
	end)
	if not ok then warnThrottled("survive", "survive reward failed: " .. tostring(err)) end
	finish(p, "Survived", participants)
end

local function stomp(p)
	if not Util.IsAlive(p) then return end
	local root = Util.GetRoot(p)
	if not root then return end
	local pos = root.Position
	for _, v in readyPlayers() do
		if v ~= p and factionOf(v) == "Halo" and Util.IsAlive(v) then
			local r = Util.GetRoot(v)
			if r and Util.FlatDistance(r.Position, pos) <= Config.Kaiju.StompRadius
				and call("PvPService", "IsRookie", v) ~= true
				and v:GetAttribute("Protected") ~= true
				and call("ZoneService", "IsTown", v) ~= true then
				local hum = Util.GetHumanoid(v)
				if hum and hum.Health > 0 then
					contested = true -- a Halo player stood in stomp range: the kaiju faced real opposition
					call("CombatService", "DamagePlayer", v, Util.RoundDamage(hum.MaxHealth * Config.Kaiju.StompPct), p)
				end
			end
		end
	end
	Net.Fx(nil, "Stomp", { UserId = p.UserId, Pos = groundBelow(pos), Radius = Config.Kaiju.StompRadius })
end

------------------------------------------------------------------ loop
local function updateQueue()
	-- drop queued players who left, are no longer Horns or have fewer stars
	for i = #queue, 1, -1 do
		local p = queue[i]
		local ok, valid = pcall(function()
			return states[p] == "Queued" and isEligible(p)
		end)
		if not (ok and valid) then
			table.remove(queue, i)
			if states[p] == "Queued" then setState(p, "None") end
		end
	end
	-- append newly eligible Horns players
	for _, p in readyPlayers() do
		local ok, err = pcall(function()
			if states[p] == nil and isEligible(p) then
				table.insert(queue, p)
				setState(p, "Queued")
				if current ~= nil then
					Net.Notify(p, string.format(Config.Text.KaijuQueued), "info")
				end
			end
		end)
		if not ok then warnThrottled("queue", "queue error: " .. tostring(err)) end
	end
end

local function tick()
	updateQueue()

	local p = current
	if p ~= nil then
		if not isPlayer(p) or p.Parent == nil then
			finish(p, "Cancelled", nil, true)
		elseif phase == "Siren" then
			if Util.Now() >= phaseEndsAt then
				if isEligible(p) and Util.IsAlive(p) then
					activate(p)
				else
					finish(p, "Cancelled")
				end
			end
		elseif phase == "Active" then
			if Util.Now() >= phaseEndsAt then
				survive(p)
			else
				sampleMaxHealth(p)
				local now = os.clock()
				if now - lastRecalc >= Config.Kaiju.HPRecalc then
					lastRecalc = now
					local mult = computeHealthMult(p)
					if math.abs(mult - healthMult) > 1e-6 then
						healthMult = mult
						call("PlayerService", "RefreshCharacter", p, false) -- HP % preserved
					end
				end
				if now - lastStomp >= Config.Kaiju.StompInterval then
					lastStomp = now
					stomp(p)
				end
			end
		end
	end

	if current == nil then
		beginSiren()
	end
end

------------------------------------------------------------------ public API
function KaijuService.Init(registry)
	S = registry

	S.PlayerService.PlayerReady:Connect(function(player)
		if not isPlayer(player) or player.Parent == nil then return end
		states[player] = nil
		player:SetAttribute("KaijuState", "None")
		player:SetAttribute("SessionTitle", "")
	end)

	S.PlayerService.PlayerLeaving:Connect(function(player)
		if player == current then
			finish(player, "Cancelled", nil, true) -- no rewards
		end
		removeFromQueue(player)
		states[player] = nil
		dmg[player] = nil
		healers[player] = nil
		zoomRestore[player] = nil
	end)

	S.FactionService.FactionChanged:Connect(function(player, newFaction)
		if player == current then
			finish(player, "Cancelled") -- defensive; switching is normally blocked for kaiju
		elseif states[player] == "Queued" and newFaction ~= "Horns" then
			removeFromQueue(player)
			setState(player, "None")
		end
	end)

	S.CombatService.PlayerDamaged:Connect(function(victim, amount, attacker)
		if phase ~= "Active" or victim ~= current or current == nil then return end
		if not isPlayer(attacker) or attacker == victim then return end
		if type(amount) ~= "number" or amount <= 0 then return end
		if factionOf(attacker) ~= "Halo" then return end
		dmg[attacker] = (dmg[attacker] or 0) + amount
		contested = true
		-- PlayerDamaged fires synchronously right after TakeDamage: Health <= 0 here means THIS Halo hit was lethal
		local hum = Util.GetHumanoid(victim)
		if hum then
			if hum.MaxHealth > 0 then lastMaxHealth = hum.MaxHealth end
			if hum.Health <= 0 then lethalHit = true end
		end
	end)

	S.CombatService.Released:Connect(function(player, info)
		if phase ~= "Active" or current == nil then return end
		if not isPlayer(player) or type(info) ~= "table" or type(info.Healed) ~= "table" then return end
		if factionOf(player) ~= "Halo" then return end
		for _, h in info.Healed do
			if (dmg[h] or 0) > 0 then
				healers[player] = true
				break
			end
		end
	end)
end

function KaijuService.Start()
	getGameState()
	publish("None", 0, "", 0)

	task.spawn(function()
		while true do
			task.wait(Config.Kaiju.Tick)
			local ok, err = pcall(tick)
			if not ok then warnThrottled("loop", "tick error: " .. tostring(err)) end
		end
	end)

	print("[KaijuService] started")
end

function KaijuService.GetState(player)
	return states[player] or "None"
end

function KaijuService.GetActive()
	return current
end

function KaijuService.GetHealthMult(player)
	if player ~= nil and player == current and phase == "Active" then
		return healthMult
	end
	return 1
end

-- called ONLY by CombatService's death pipeline (Defeated; no last-hit bonus)
function KaijuService.HandleKaijuDeath(victim, killer)
	if victim == nil or victim ~= current or phase ~= "Active" then
		warnThrottled("death", "HandleKaijuDeath for a player that is not the active kaiju")
		return
	end
	local name = kaijuName
	local participants = participantList()
	local pool = 0

	local ok, err = pcall(function()
		local level = math.max(1, math.floor(getNum(victim, "Level")))
		local bully = tonumber(call("JusticeService", "GetBullyStacks", victim)) or 0
		local bounty = Config.Bounty(level, starsOf(victim), bully)
		local mint = math.max(0, Config.Kaiju.BountyPoolMult * bounty)

		-- review fix: no Halo player landed the lethal hit (reset, fall, monster, ...) -> mint only the share of the
		-- kaiju's HP that Halo players really took off (a 1-damage tag + reset mints ~0; a near-dead reset still pays)
		if not lethalHit then
			local maxHp = lastMaxHealth
			local hum = Util.GetHumanoid(victim)
			if hum and hum.MaxHealth > 0 then maxHp = math.max(maxHp, hum.MaxHealth) end
			local haloDmg = 0
			for _, amount in dmg do
				if type(amount) == "number" and amount > 0 then haloDmg += amount end
			end
			local frac = (maxHp > 0) and math.clamp(haloDmg / maxHp, 0, 1) or 0
			mint *= frac
		end
		mint = math.floor(mint)

		local carried = math.max(0, math.floor(getNum(victim, "CarriedGold")))
		local taken = math.max(0, math.floor(tonumber(call("ProgressionService", "TakeCarriedGold", victim, carried)) or 0))
		pool = mint + taken

		local n = #participants
		if n > 0 and pool > 0 then
			local totalDmg = 0
			for _, p in participants do
				totalDmg += (dmg[p] or 0)
			end
			local now = os.clock()
			local cooldown = Config.PvP.PairRewardCooldown
			for key, t in poolPaidAt do
				if now - t >= cooldown then poolPaidAt[key] = nil end
			end
			for _, p in participants do
				-- spec split: DamageShare by damage + the rest equally (everything equally if only healers are left)
				local frac = 1 / n
				if totalDmg > 0 then
					frac = Config.Kaiju.DamageShare * (dmg[p] or 0) / totalDmg + (1 - Config.Kaiju.DamageShare) / n
				end
				local share = math.floor(taken * frac) -- carried gold: a transfer, always paid
				-- minted part: once per participant/kaiju pair per PairRewardCooldown (like PvP bounties)
				local key = tostring(p.UserId) .. ":" .. tostring(victim.UserId)
				if mint > 0 and poolPaidAt[key] == nil then
					poolPaidAt[key] = now
					share += math.floor(mint * frac)
				end
				if share > 0 then
					call("ProgressionService", "AddBankGold", p, share, "Kaiju")
					Net.Notify(p, string.format(Config.Text.KaijuReward, Util.FormatNumber(share)), "reward")
				end
			end
		end

		call("WarService", "AddFactionPoints", "Halo", Config.Kaiju.HaloWarPoints)
	end)
	if not ok then warnThrottled("defeat", "defeat reward failed: " .. tostring(err)) end

	local okSend, sendErr = pcall(function()
		Net.NotifyAll(string.format(Config.Story.KaijuDefeated, name, Util.FormatNumber(pool)))
	end)
	if not okSend then warnThrottled("send", "defeat broadcast failed: " .. tostring(sendErr)) end
	finish(victim, "Defeated", participants)
end

return KaijuService
