-- PvPService.luau : PvP rules (CanAttack, rookie / spawn protection), bully detection, KO outcomes
-- (plunder -> grudge sack, honor, bounty), Wanted stars + bounty, revenge marks and the Most Wanted board.
-- Server only. See TECH_SPEC §4.13 and SPEC_ADDENDUM A6 / A10-V3-3.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "PvPService"

-- (the A3-M3 "under attack while auto-attack is ON" hint is sent by CombatService.DamagePlayer only)
local LOOP_INTERVAL = 1
local PRUNE_INTERVAL = 60 -- seconds between prunes of the pair tables
local LOOP_WARN_INTERVAL = 10

-- Most Wanted board lines (TECH_SPEC §4.13 board text)
local BOARD_WANTED_TITLE = "현상수배 TOP 3"
local BOARD_HONOR_TITLE = Config.Factions.Halo.Name .. " 명예 TOP 3"
local BOARD_EMPTY = "(아직 없음)"
local BOARD_BULLY = "깡패"
local BOARD_HONOR_WORD = "명예"
local BOARD_ROWS = 3

local PvPService = {}

PvPService.PlayerKO = Util.Signal.new() -- (killer, victim, info)

local S = nil

-- per-player state (Player keys; cleaned on PlayerLeaving)
local stars = {} -- [Player] = number
local lastStarChange = {} -- [Player] = os.clock()
local protectedUntil = {} -- [Player] = os.clock() (0 = not protected)
local spawnedAt = {} -- [Player] = os.clock() of the last CharacterSpawned
local lastHitOn = {} -- [attacker][victim] = os.clock() (attacker damaged victim)
local revenge = {} -- [Player] = { Target = Player, Until = os.clock() }

-- pair state keyed by "killerUserId:victimUserId" so a rejoin cannot reset it; pruned by age
local koLog = {} -- [pairKey] = { os.clock(), ... } within Config.Bully.RepeatWindow
local pairReward = {} -- [pairKey] = os.clock() of the last minted reward

-- anti-farm: the minted bully part of a bounty is paid at most once per victim (any killer) per this window,
-- the time a max-stack bully needs to decay back to clean. Keyed by victim UserId; pruned by age.
local BULLY_BOUNTY_COOLDOWN = Config.Bully.DecaySeconds * Config.Bully.MaxStacks
local bullyBountyAt = {} -- [victimUserId] = os.clock() of the last minted bully bounty on that victim

local lastLoopWarn = 0

------------------------------------------------------------------ helpers
local function isPlaying(p)
	return p ~= nil and p.Parent ~= nil
end

local function warnLoop(err)
	local now = os.clock()
	if now - lastLoopWarn >= LOOP_WARN_INTERVAL then
		lastLoopWarn = now
		Util.Warn(TAG, "loop error: " .. tostring(err))
	end
end

local function fmt(key, ...)
	return string.format(Config.Text[key], ...)
end

local function notify(p, text, kind)
	if isPlaying(p) then
		Net.Notify(p, text, kind)
	end
end

local function setAttr(p, key, value)
	if p:GetAttribute(key) ~= value then
		p:SetAttribute(key, value)
	end
end

local function faction(p)
	return S.FactionService.GetFaction(p)
end

-- only Halo and Horns ever take part in PvP ("Neutral" and "None" never do; addendum A6)
local function isFighter(f)
	return f == "Halo" or f == "Horns"
end

local function kstate(p)
	local kaiju = S.KaijuService
	if kaiju and kaiju.GetState then
		return kaiju.GetState(p) or "None"
	end
	return "None"
end

-- persisted stat: live data table first, mirrored attribute as fallback
local function num(p, key, default)
	local data = S.PlayerService.GetData(p)
	local v = data and data[key]
	if v == nil then
		v = p:GetAttribute(key)
	end
	return tonumber(v) or default
end

local function bullyStacksOf(p)
	return tonumber(S.JusticeService.GetBullyStacks(p)) or 0
end

-- bully stacks that still carry a bounty: 0 while this bully's bounty was already claimed (BULLY_BOUNTY_COOLDOWN).
-- The stacks themselves (size / damage penalty, "깡패" tag) stay with JusticeService.
local function bountyBullyStacks(p, now)
	local t = bullyBountyAt[p.UserId]
	if t ~= nil and (now or os.clock()) - t < BULLY_BOUNTY_COOLDOWN then
		return 0
	end
	return bullyStacksOf(p)
end

-- addendum A10-V3-3: inside a PvP zone, or combat-tagged (Config.PvP.CombatTagTime) anywhere outside a town
-- (Outskirts, bridges, safe hunting land), so a fight or a sack chase does not end at a zone edge
local function inPvP(p)
	return S.ZoneService.IsPvPZone(p) or (not S.ZoneService.IsTown(p) and S.CombatService.IsInCombat(p))
end

local function rootPos(p)
	local root = Util.GetRoot(p)
	return root and root.Position or nil
end

local function pairKey(a, b)
	return tostring(a.UserId) .. ":" .. tostring(b.UserId)
end

-- remove every time < cutoff from an ascending array of os.clock() values
local function pruneTimes(log, cutoff)
	local i = 1
	while i <= #log do
		if log[i] < cutoff then
			table.remove(log, i)
		else
			i += 1
		end
	end
end

local function computeBounty(p)
	if not isFighter(faction(p)) then
		return 0
	end
	return Config.Bounty(num(p, "Level", 1), stars[p] or 0, bountyBullyStacks(p))
end

local function refreshStarAttrs(p)
	if not isPlaying(p) then
		return
	end
	setAttr(p, "WantedStars", stars[p] or 0)
	setAttr(p, "Bounty", computeBounty(p))
end

-- the newbie PvP shield is meaningless for Neutral (never in PvP at all; addendum A6)
local function rookieAttr(p)
	return faction(p) ~= "Neutral" and PvPService.IsRookie(p)
end

local function announceIfMostWanted(p, before, after)
	if before < Config.PvP.AnnounceStars and after >= Config.PvP.AnnounceStars then
		Net.NotifyAll(fmt("MostWanted", p.DisplayName, Util.FormatNumber(computeBounty(p))))
	end
end

local function addStar(killer)
	local before = stars[killer] or 0
	local after = math.min(Config.PvP.MaxStars, before + 1)
	stars[killer] = after
	lastStarChange[killer] = os.clock()
	refreshStarAttrs(killer)
	announceIfMostWanted(killer, before, after)
end

local function destroyForceFields(p)
	local character = p.Character
	if not character then
		return
	end
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") then
			child:Destroy()
		end
	end
end

local function clearRevenge(p)
	revenge[p] = nil
	if isPlaying(p) then
		setAttr(p, "RevengeTargetId", 0)
		setAttr(p, "RevengeUntil", 0)
	end
end

-- clears p's own revenge mark and every other player's mark that targets p
local function clearRevengeInvolving(p)
	local holders = {}
	for holder, r in revenge do
		if holder == p or r.Target == p then
			table.insert(holders, holder)
		end
	end
	for _, holder in holders do
		clearRevenge(holder)
	end
end

------------------------------------------------------------------ public API
function PvPService.GetStars(player)
	return (player and stars[player]) or 0
end

function PvPService.ResetStars(player)
	if not player then
		return
	end
	stars[player] = 0
	lastStarChange[player] = os.clock()
	refreshStarAttrs(player)
end

function PvPService.DebugSetStars(player, n)
	if not isPlaying(player) then
		return
	end
	local before = stars[player] or 0
	local after = math.clamp(math.floor(tonumber(n) or 0), 0, Config.PvP.MaxStars)
	stars[player] = after
	lastStarChange[player] = os.clock()
	refreshStarAttrs(player)
	announceIfMostWanted(player, before, after)
end

-- Rebirths == 0 and (Level < RookieLevel or PlaytimeSeconds < RookiePlaytime)
function PvPService.IsRookie(player)
	if not player then
		return false
	end
	if num(player, "Rebirths", 0) ~= 0 then
		return false
	end
	return num(player, "Level", 1) < Config.PvP.RookieLevel
		or num(player, "PlaytimeSeconds", 0) < Config.PvP.RookiePlaytime
end

function PvPService.HasRevenge(attacker, victim)
	local r = attacker and revenge[attacker]
	return r ~= nil and victim ~= nil and r.Target == victim and os.clock() < r.Until
end

function PvPService.Protect(player, seconds)
	if not isPlaying(player) then
		return
	end
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then
		return
	end
	local character = player.Character
	if character and character.Parent and not character:FindFirstChildOfClass("ForceField") then
		local ff = Instance.new("ForceField")
		ff.Visible = true
		ff.Parent = character
	end
	protectedUntil[player] = math.max(protectedUntil[player] or 0, os.clock() + seconds)
	setAttr(player, "Protected", true)
end

function PvPService.BreakProtection(player)
	if not player then
		return
	end
	-- cheap early-out: CombatService calls this after every PvP hit
	if (protectedUntil[player] or 0) == 0 and player:GetAttribute("Protected") ~= true then
		return
	end
	protectedUntil[player] = 0
	destroyForceFields(player)
	if isPlaying(player) then
		setAttr(player, "Protected", false)
	end
end

-- (allowed: boolean, reasonKey: string?)
function PvPService.CanAttack(attacker, victim)
	if attacker == nil or victim == nil or attacker == victim then
		return false, "Self"
	end
	local PS = S.PlayerService
	if not PS.IsReady(attacker) or not PS.IsReady(victim) then
		return false, "NotReady"
	end
	if not Util.IsAlive(attacker) or not Util.IsAlive(victim) then
		return false, "Dead"
	end
	local fa, fv = faction(attacker), faction(victim)
	if fa == "Neutral" or fv == "Neutral" then
		return false, "Neutral" -- addendum A6: Neutral never hits / is hit by players, anywhere
	end
	if not isFighter(fa) or not isFighter(fv) or fa == fv then
		return false, "SameFaction"
	end
	-- kaiju exception: Halo may hit the Active kaiju in any zone (rookies allowed, protection ignored)
	if fa == "Halo" and kstate(victim) == "Active" then
		return true, nil
	end
	if not inPvP(attacker) or not inPvP(victim) then
		return false, "SafeZone"
	end
	if PvPService.IsRookie(attacker) or PvPService.IsRookie(victim) then
		return false, "Rookie"
	end
	if victim:GetAttribute("Protected") == true then
		return false, "Protected"
	end
	return true, nil
end

-- called ONLY by CombatService's death pipeline (no kill credit: monster, fall, reset)
function PvPService.HandleNonPvPDeath(victim)
	if not victim then
		return
	end
	if (stars[victim] or 0) >= 1 then
		local carried = num(victim, "CarriedGold", 0)
		local loss = math.floor(carried * Config.PvP.VillainLossOnWantedPvEDeath)
		if loss > 0 then
			S.ProgressionService.TakeCarriedGold(victim, loss)
		end
	end
	PvPService.ResetStars(victim)
end

-- called ONLY by CombatService's death pipeline (after GrudgeService.OnCarrierDown)
function PvPService.HandleKO(victim, killer)
	if not victim then
		return
	end
	if killer == nil or killer == victim or not isPlaying(killer) then
		PvPService.HandleNonPvPDeath(victim)
		return
	end
	local fk, fv = faction(killer), faction(victim)
	if not isFighter(fk) or not isFighter(fv) or fk == fv then
		-- defensive: Neutral / None / same-faction deaths are never PvP KOs (addendum A6)
		PvPService.HandleNonPvPDeath(victim)
		return
	end

	local P = Config.PvP
	local B = Config.Bully
	local Justice = S.JusticeService
	local Progression = S.ProgressionService
	local now = os.clock()
	local key = pairKey(killer, victim)

	-- 1. snapshot + KO log
	local starsBefore = stars[victim] or 0
	local bullyBefore = bullyStacksOf(victim)
	-- the victim's bully stacks that still pay a bounty (0 once claimed; anti-farm, see BULLY_BOUNTY_COOLDOWN)
	local bountyBully = bountyBullyStacks(victim, now)
	local log = koLog[key]
	if not log then
		log = {}
		koLog[key] = log
	end
	table.insert(log, now)
	pruneTimes(log, now - B.RepeatWindow)

	-- 2. bully check (any faction pairing)
	local weak = (tonumber(Justice.GetPower(victim)) or 0) < B.WeakPowerRatio * (tonumber(Justice.GetPower(killer)) or 0)
	local victimHits = lastHitOn[victim]
	local baitAt = victimHits and victimHits[killer]
	if weak and baitAt and now - baitAt <= B.BaitWindow then
		weak = false -- anti-bait: the victim hit the killer first
	end
	if weak and B.WantedIgnoresWeakRule and (starsBefore > 0 or bullyBefore > 0) then
		weak = false
	end
	local fresh = spawnedAt[victim] ~= nil and now - spawnedAt[victim] < B.FreshSpawnSeconds
	local repeated = #log >= B.RepeatKOs
	local bully = weak or fresh or repeated

	-- 3. revenge (always)
	revenge[victim] = { Target = killer, Until = now + Config.Revenge.Duration }
	setAttr(victim, "RevengeTargetId", killer.UserId)
	setAttr(victim, "RevengeUntil", Util.Now() + Config.Revenge.Duration)
	notify(victim, fmt("Revenge", killer.DisplayName), "info")
	local killerRevenge = revenge[killer]
	if killerRevenge and killerRevenge.Target == victim then
		local wasActive = now < killerRevenge.Until
		clearRevenge(killer)
		if wasActive then
			notify(killer, fmt("RevengeDone"), "good")
		end
	end

	local info
	if bully then
		-- 4. bully KO: no plunder, stars, honor/infamy, bounty or war points
		local n = math.floor(tonumber(Justice.AddBullyStack(killer)) or 0)
		notify(killer, fmt("BullyKO", n), "bad")
		notify(victim, fmt("BullyVictim"), "info")
		refreshStarAttrs(killer) -- bounty doubles while a bully
		info = { Kind = "Bully", Bully = true, VictimStars = starsBefore, Stolen = 0, Bounty = 0, Rewarded = false }
	else
		-- 5. pair cooldown for minted rewards
		local pairOk = now - (pairReward[key] or -math.huge) >= P.PairRewardCooldown
		if pairOk then
			pairReward[key] = now
		end
		local vLevel = num(victim, "Level", 1)

		if fk == "Horns" then
			-- 6a. Horns KO Halo: plunder into the grudge sack
			addStar(killer)
			local stolen = 0
			if not S.GrudgeService.CanSteal(killer, victim) then
				notify(killer, fmt("PlunderTooSoon"), "info")
			else
				local carried = num(victim, "CarriedGold", 0)
				local safeFloor = P.SafeFloorPerLevel * vLevel
				stolen = math.min(math.floor(math.max(0, carried - safeFloor) * P.PlunderRate), P.PlunderCapPerLevel * vLevel)
				if stolen > 0 then
					stolen = math.floor(tonumber(Progression.TakeCarriedGold(victim, stolen)) or 0)
				end
				if stolen > 0 then
					S.GrudgeService.AddToSack(killer, victim, stolen, pairOk and 1 or 0)
					local from, to = rootPos(victim), rootPos(killer)
					if from and to then
						Net.Fx(nil, "Plunder", { From = from, To = to, Amount = stolen })
					end
					notify(victim, fmt("Plundered", killer.DisplayName, Util.FormatNumber(stolen)), "bad")
					notify(killer, fmt("PlunderGain", Util.FormatNumber(stolen), stars[killer] or 0), "reward")
				end
			end
			if stolen == 0 and pairOk then
				S.PlayerService.AddStat(killer, "Infamy", 1) -- no sack to carry it
			end
			local bullyBounty = 0
			if bountyBully > 0 and pairOk then
				bullyBounty = Config.Bounty(vLevel, 0, bountyBully)
				if bullyBounty > 0 then
					bullyBountyAt[victim.UserId] = now -- claimed: no bully bounty on this victim for any killer for a while
					Progression.AddBankGold(killer, bullyBounty, "Bounty")
					notify(killer, fmt("BullyBountyGain", Util.FormatNumber(bullyBounty)), "reward")
				end
			end
			info = {
				Kind = "Plunder", Bully = false, VictimStars = starsBefore,
				Stolen = stolen, Bounty = bullyBounty, Rewarded = pairOk,
			}
		elseif starsBefore == 0 and bountyBully == 0 then
			-- 6b. Halo KO a clean Horns (or a bully whose bounty was already claimed): honor
			if pairOk then
				S.PlayerService.AddStat(killer, "Honor", P.HonorPerKOMin)
				notify(killer, fmt("HonorGain", P.HonorPerKOMin), "reward")
			end
			info = { Kind = "Honor", Bully = false, VictimStars = 0, Stolen = 0, Bounty = 0, Rewarded = pairOk }
		else
			-- 6c. Halo KO a Wanted (or bully) Horns: bounty
			local bounty = pairOk and Config.Bounty(vLevel, starsBefore, bountyBully) or 0
			if bounty > 0 then
				if bountyBully > 0 then
					bullyBountyAt[victim.UserId] = now -- claimed: no bully bounty on this victim for any killer for a while
				end
				Progression.AddBankGold(killer, bounty, "Bounty")
			end
			local honor = pairOk and math.max(1, starsBefore) or 0
			if honor > 0 then
				S.PlayerService.AddStat(killer, "Honor", honor)
			end
			if starsBefore > 0 then
				local carried = num(victim, "CarriedGold", 0)
				local loss = math.floor(carried * P.VillainLossOnBountyKO)
				if loss > 0 then
					Progression.TakeCarriedGold(victim, loss)
				end
			end
			if bounty > 0 or honor > 0 then
				notify(killer, fmt("BountyGain", Util.FormatNumber(bounty), honor), "reward")
			end
			if starsBefore >= P.GlowStars and bounty > 0 then
				Net.NotifyAll(fmt("BountyAnnounce", killer.DisplayName, Util.FormatNumber(bounty)))
			end
			info = {
				Kind = "Bounty", Bully = false, VictimStars = starsBefore,
				Stolen = 0, Bounty = bounty, Rewarded = pairOk,
			}
		end
	end

	-- 7. victim's stars are gone; tell everyone
	PvPService.ResetStars(victim)
	PvPService.PlayerKO:Fire(killer, victim, info)
end

------------------------------------------------------------------ board
local function updateBoard()
	local ok, label = pcall(function()
		return S.MapBuilder.GetBoardLabel()
	end)
	if not ok or not label then
		return
	end

	local wanted, heroes = {}, {}
	for _, p in S.PlayerService.GetReadyPlayers() do
		local bounty = tonumber(p:GetAttribute("Bounty")) or 0
		if bounty > 0 then
			table.insert(wanted, { Name = p.DisplayName, Bounty = bounty, Stars = stars[p] or 0, Bully = bullyStacksOf(p) })
		end
		if faction(p) == "Halo" then
			local honor = num(p, "Honor", 0)
			if honor > 0 then
				table.insert(heroes, { Name = p.DisplayName, Honor = honor })
			end
		end
	end
	table.sort(wanted, function(a, b)
		if a.Bounty ~= b.Bounty then
			return a.Bounty > b.Bounty
		end
		return a.Name < b.Name
	end)
	table.sort(heroes, function(a, b)
		if a.Honor ~= b.Honor then
			return a.Honor > b.Honor
		end
		return a.Name < b.Name
	end)

	local lines = { BOARD_WANTED_TITLE }
	if #wanted == 0 then
		table.insert(lines, BOARD_EMPTY)
	else
		for i = 1, math.min(BOARD_ROWS, #wanted) do
			local w = wanted[i]
			local line = string.format("%d. %s", i, w.Name)
			if w.Stars > 0 then
				line ..= " " .. string.rep("★", w.Stars)
			end
			line ..= " " .. Util.FormatNumber(w.Bounty) .. "G"
			if w.Bully > 0 then
				line ..= " " .. BOARD_BULLY
			end
			table.insert(lines, line)
		end
	end
	table.insert(lines, "")
	table.insert(lines, BOARD_HONOR_TITLE)
	if #heroes == 0 then
		table.insert(lines, BOARD_EMPTY)
	else
		for i = 1, math.min(BOARD_ROWS, #heroes) do
			local h = heroes[i]
			table.insert(lines, string.format("%d. %s %s %s", i, h.Name, BOARD_HONOR_WORD, Util.FormatNumber(h.Honor)))
		end
	end

	local text = table.concat(lines, "\n")
	if label.Text ~= text then
		label.Text = text
	end
end

------------------------------------------------------------------ loops
local function tickPlayer(p, now)
	-- protection expiry
	local pu = protectedUntil[p]
	if pu and pu > 0 and now >= pu then
		protectedUntil[p] = 0
		destroyForceFields(p)
		setAttr(p, "Protected", false)
	end

	-- star decay: one star per StarDecaySeconds, paused while queued / siren / active kaiju
	local s = stars[p] or 0
	if s > 0 then
		if kstate(p) ~= "None" then
			lastStarChange[p] = now
		elseif now - (lastStarChange[p] or now) >= Config.PvP.StarDecaySeconds then
			stars[p] = s - 1
			lastStarChange[p] = now
		end
	end
	refreshStarAttrs(p)
	setAttr(p, "Rookie", rookieAttr(p))

	-- revenge expiry
	local r = revenge[p]
	if r and (now >= r.Until or not isPlaying(r.Target)) then
		clearRevenge(p)
	end
end

local function prunePairs(now)
	local rewardHorizon = Config.PvP.PairRewardCooldown
	for key, t in pairReward do
		if now - t > rewardHorizon then
			pairReward[key] = nil
		end
	end
	for userId, t in bullyBountyAt do
		if now - t >= BULLY_BOUNTY_COOLDOWN then
			bullyBountyAt[userId] = nil
		end
	end
	local cutoff = now - Config.Bully.RepeatWindow
	for key, log in koLog do
		pruneTimes(log, cutoff)
		if #log == 0 then
			koLog[key] = nil
		end
	end
end

------------------------------------------------------------------ signal handlers
local function onPlayerReady(player)
	stars[player] = 0
	lastStarChange[player] = os.clock()
	protectedUntil[player] = 0
	player:SetAttribute("WantedStars", 0)
	player:SetAttribute("Bounty", 0)
	player:SetAttribute("Rookie", rookieAttr(player))
	player:SetAttribute("Protected", false)
	player:SetAttribute("RevengeTargetId", 0)
	player:SetAttribute("RevengeUntil", 0)
end

local function cleanupPlayer(player)
	clearRevengeInvolving(player)
	stars[player] = nil
	lastStarChange[player] = nil
	protectedUntil[player] = nil
	spawnedAt[player] = nil
	revenge[player] = nil
	lastHitOn[player] = nil
	for _, hits in lastHitOn do
		hits[player] = nil
	end
end

local function onPlayerLeaving(player)
	-- other services' PlayerLeaving handlers (e.g. KaijuService) may still call ResetStars; clean up after them
	clearRevengeInvolving(player)
	task.defer(cleanupPlayer, player)
end

local function onCharacterSpawned(player)
	spawnedAt[player] = os.clock()
	PvPService.Protect(player, Config.PvP.SpawnProtection)
end

local function onPlayerDamaged(victim, _amount, attacker)
	if victim == nil or attacker == nil then
		return
	end
	local hits = lastHitOn[attacker]
	if not hits then
		hits = {}
		lastHitOn[attacker] = hits
	end
	hits[victim] = os.clock()
end

local function onFactionChanged(player)
	PvPService.ResetStars(player)
	-- revenge marks never cross a faction change (and Neutral never gives/gets revenge; A6)
	clearRevengeInvolving(player)
	if isPlaying(player) then
		setAttr(player, "Rookie", rookieAttr(player))
	end
end

------------------------------------------------------------------ lifecycle
function PvPService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(onPlayerReady)
	S.PlayerService.PlayerLeaving:Connect(onPlayerLeaving)
	S.PlayerService.CharacterSpawned:Connect(onCharacterSpawned)
	S.CombatService.PlayerDamaged:Connect(onPlayerDamaged)
	S.FactionService.FactionChanged:Connect(onFactionChanged)
end

function PvPService.Start()
	local okBoard, errBoard = pcall(updateBoard)
	if not okBoard then
		Util.Warn(TAG, "board update failed: " .. tostring(errBoard))
	end

	task.spawn(function()
		local boardAcc = 0
		local pruneAcc = 0
		while true do
			task.wait(LOOP_INTERVAL)
			local now = os.clock()
			for _, p in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(tickPlayer, p, now)
				if not ok then
					warnLoop(err)
				end
			end

			boardAcc += LOOP_INTERVAL
			if boardAcc >= Config.PvP.BoardRefresh then
				boardAcc = 0
				local ok, err = pcall(updateBoard)
				if not ok then
					warnLoop(err)
				end
			end

			pruneAcc += LOOP_INTERVAL
			if pruneAcc >= PRUNE_INTERVAL then
				pruneAcc = 0
				local ok, err = pcall(prunePairs, now)
				if not ok then
					warnLoop(err)
				end
			end
		end
	end)

	print("[PvPService] started")
end

return PvPService
