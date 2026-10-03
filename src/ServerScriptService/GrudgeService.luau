-- GrudgeService.luau : the grudge sack ("원한 돈자루"). Gold plundered by a Horns thief rides in ONE sack on the
-- thief's back; its 45 s countdown ticks only inside PvP zones. Survive -> Paid to the thief. A Halo KO in time ->
-- Avenged (victims get 120% to the bank, the avenger a bonus). Any other death / leaving -> Returned (100%).
-- Server only. See TECH_SPEC §4.14.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "GrudgeService"

local LOOP_WARN_INTERVAL = 10
local MAX_TICK_STEP = 1 -- clamp for the elapsed time of one tick after a server hitch

local GrudgeService = {}

GrudgeService.SackResolved = Util.Signal.new() -- (thief, outcome: "Paid" | "Avenged" | "Returned", total)

local S = nil

-- [thief: Player] = { Entries = { [victimUserId] = { Amount, Name, Rebirths } }, Total, Remaining, Infamy,
-- LastVictimName }. Entry.Rebirths = the victim's Rebirths when stolen (CR-M6: no refund across a rebirth).
local sacks = {}
-- CR-M4 / CR-L6: anti-collusion cooldowns live in the saved PairCD (follows the player across servers):
-- victim data "steal:<thiefUserId>" (RestealWindow), "refund:0" (extra 20%, per victim);
-- avenger data "avenge:0" (avenger bonus, per avenger)

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

-- CR-M4: pair cooldown kept in the holder's saved PairCD ("<kind>:<otherUserId>" = os.time()). PlayerService.PairReady
-- owns it; the inline copy follows the same contract. commit = false only checks. No data -> false.
local function pairReady(holder, otherUserId, kind, cooldown, commit)
	if not holder then
		return false
	end
	local PS = S.PlayerService
	if PS.PairReady then
		local ok, res = pcall(PS.PairReady, holder, otherUserId, kind, cooldown, commit)
		return ok and res == true
	end
	local d = PS.GetData(holder)
	if type(d) ~= "table" then
		return false
	end
	if type(d.PairCD) ~= "table" then
		d.PairCD = {}
	end
	local k = kind .. ":" .. tostring(otherUserId)
	local t = os.time()
	if t - (tonumber(d.PairCD[k]) or 0) < cooldown then
		return false
	end
	if commit ~= false then
		d.PairCD[k] = t
	end
	return true
end

-- CR-M6: a share is refunded only to the same "life" it was stolen from (a rebirth resets the bank on purpose)
local function sameLife(victim, entry)
	return (tonumber(victim:GetAttribute("Rebirths")) or 0) == (tonumber(entry.Rebirths) or 0)
end

local function rootPos(p)
	local root = Util.GetRoot(p)
	return root and root.Position or nil
end

local function setAttr(p, key, value)
	if p:GetAttribute(key) ~= value then
		p:SetAttribute(key, value)
	end
end

local function publish(thief, sack)
	if not isPlaying(thief) then
		return
	end
	if sack then
		setAttr(thief, "SackGold", sack.Total)
		setAttr(thief, "SackSeconds", math.max(0, math.ceil(sack.Remaining)))
		setAttr(thief, "SackVictimName", sack.LastVictimName)
	else
		setAttr(thief, "SackGold", 0)
		setAttr(thief, "SackSeconds", 0)
		setAttr(thief, "SackVictimName", "")
	end
end

-- victim still in this server (a rejoin counts: entries are keyed by UserId) and ready
local function presentVictim(userId)
	local victim = Players:GetPlayerByUserId(userId)
	if victim and S.PlayerService.IsReady(victim) then
		return victim
	end
	return nil
end

-- removes the sack, resets the thief's attributes, tells the thief (unless leaving) and fires SackResolved
local function closeSack(thief, sack, outcome, tellThief)
	sacks[thief] = nil
	publish(thief, nil)
	if tellThief and outcome ~= "Paid" then
		notify(thief, fmt("SackLost"), "bad")
	end
	GrudgeService.SackResolved:Fire(thief, outcome, sack.Total)
end

------------------------------------------------------------------ outcomes
-- Paid: the thief survived 45 s of PvP-zone time
local function pay(thief, sack)
	S.ProgressionService.AddCarriedGold(thief, sack.Total, "Plunder")
	if sack.Infamy > 0 then
		S.PlayerService.AddStat(thief, "Infamy", sack.Infamy)
	end
	notify(thief, fmt("SackPaid", Util.FormatNumber(sack.Total)), "reward")
	closeSack(thief, sack, "Paid", true)
end

-- Returned: every present victim gets 100% back to the bank; shares of victims who left (or rebirthed since,
-- CR-M6) are destroyed
local function returnShares(sack)
	for userId, entry in sack.Entries do
		local victim = presentVictim(userId)
		if victim and sameLife(victim, entry) then
			local amount = math.floor(entry.Amount * Config.Grudge.ReturnRate)
			if amount > 0 then
				S.ProgressionService.AddBankGold(victim, amount, "Refund")
				notify(victim, fmt("GrudgeReturned", Util.FormatNumber(amount)), "good")
			end
		end
	end
end

-- Avenged: a Halo player KO'd the thief in time
local function avenge(thief, sack, killer)
	local G = Config.Grudge
	local thiefPos = rootPos(thief)

	for userId, entry in sack.Entries do
		local victim = presentVictim(userId)
		if victim and sameLife(victim, entry) then -- CR-M6
			-- CR-L6: the extra 20% is once per VICTIM per RefundBonusCooldown whatever the thief (victim's save, CR-M4)
			local bonusOk = pairReady(victim, 0, "refund", G.RefundBonusCooldown)
			local refund = math.floor(entry.Amount * (bonusOk and G.AvengeRefundRate or G.ReturnRate))
			if refund > 0 then
				S.ProgressionService.AddBankGold(victim, refund, "Refund")
				notify(victim, fmt("GrudgeRefund", killer.DisplayName, Util.FormatNumber(refund)), "good")
				local victimPos = rootPos(victim)
				if thiefPos and victimPos then
					Net.Fx(victim, "Plunder", { From = thiefPos, To = victimPos, Amount = refund })
				end
			end
		end
	end

	-- "복수 대행" bonus, once per AVENGER per PairRewardCooldown whatever the thief (CR-L6; avenger's save, CR-M4)
	if pairReady(killer, 0, "avenge", Config.PvP.PairRewardCooldown) then
		S.ProgressionService.AddBankGold(killer, G.AvengerBonus, "Bounty")
		notify(killer, fmt("AvengerBonus", Util.FormatNumber(G.AvengerBonus)), "reward")
	end

	Net.NotifyAll(fmt("GrudgeAvengedAll", killer.DisplayName, thief.DisplayName), "info")
end

local function returnSack(thief, tellThief)
	local sack = sacks[thief]
	if not sack then
		return
	end
	returnShares(sack)
	closeSack(thief, sack, "Returned", tellThief)
end

------------------------------------------------------------------ public API
function GrudgeService.HasSack(player)
	return player ~= nil and sacks[player] ~= nil
end

function GrudgeService.GetSackTotal(player)
	local sack = player and sacks[player]
	return sack and sack.Total or 0
end

-- false if this thief stole from this victim less than RestealWindow ago (CR-M4: checked in the victim's save;
-- AddToSack records it)
function GrudgeService.CanSteal(thief, victim)
	if not thief or not victim then
		return false
	end
	return pairReady(victim, thief.UserId, "steal", Config.Grudge.RestealWindow, false)
end

-- amount was already taken from the victim's carried gold (PvPService.HandleKO)
function GrudgeService.AddToSack(thief, victim, amount, infamy)
	if not thief or not victim then
		return
	end
	amount = math.floor(tonumber(amount) or 0)
	infamy = math.max(0, math.floor(tonumber(infamy) or 0))
	if amount <= 0 then
		return
	end

	local sack = sacks[thief]
	if not sack then
		sack = { Entries = {}, Total = 0, Remaining = 0, Infamy = 0, LastVictimName = "" }
		sacks[thief] = sack
	end
	-- CR-M6: remember the victim's rebirth count; a share stolen before a rebirth is never refunded after it
	local rebirths = tonumber(victim:GetAttribute("Rebirths")) or 0
	local entry = sack.Entries[victim.UserId]
	if entry then
		if not sameLife(victim, entry) then
			entry.Amount = 0 -- the older share stays in the sack (thief's Paid total) but is no longer refundable
		end
		entry.Amount += amount
		entry.Name = victim.DisplayName
		entry.Rebirths = rebirths
	else
		sack.Entries[victim.UserId] = { Amount = amount, Name = victim.DisplayName, Rebirths = rebirths }
	end
	sack.Total += amount
	sack.Remaining = Config.Grudge.SackSeconds -- every new steal resets the countdown
	sack.Infamy += infamy
	sack.LastVictimName = victim.DisplayName
	pairReady(victim, thief.UserId, "steal", 0) -- CR-M4: record the steal in the victim's save (RestealWindow)
	publish(thief, sack)
end

-- death pipeline step 1 (CombatService); no-op without a sack
function GrudgeService.OnCarrierDown(player, killer)
	local sack = player and sacks[player]
	if not sack then
		return
	end
	if killer ~= nil and killer ~= player and isPlaying(killer) and S.FactionService.GetFaction(killer) == "Halo" then
		avenge(player, sack, killer)
		closeSack(player, sack, "Avenged", true)
	else
		returnShares(sack)
		closeSack(player, sack, "Returned", true)
	end
end

------------------------------------------------------------------ loop
local function tickSack(thief, dt)
	local sack = sacks[thief]
	if not sack then
		return
	end
	if not isPlaying(thief) then
		-- defensive: left without PlayerLeaving resolving it; leaving never pays the thief
		returnSack(thief, false)
		return
	end
	-- a dead carrier is resolved by the death pipeline; never pay or tick in that window
	if not Util.IsAlive(thief) then
		return
	end
	if not S.ZoneService.IsPvPZone(thief) then
		return
	end
	sack.Remaining -= dt
	if sack.Remaining <= 0 then
		pay(thief, sack)
		return
	end
	setAttr(thief, "SackSeconds", math.max(0, math.ceil(sack.Remaining)))
end

local function tickAll(dt)
	local thieves = {}
	for thief in sacks do
		table.insert(thieves, thief)
	end
	for _, thief in thieves do
		local ok, err = pcall(tickSack, thief, dt)
		if not ok then
			warnLoop(err)
		end
	end
end

------------------------------------------------------------------ signal handlers
local function onPlayerReady(player)
	player:SetAttribute("SackGold", 0)
	player:SetAttribute("SackSeconds", 0)
	player:SetAttribute("SackVictimName", "")
end

local function onPlayerLeaving(player)
	-- leaving with a sack -> Returned (the thief is never paid)
	if sacks[player] then
		returnSack(player, false)
	end
end

local function onFactionChanged(player)
	-- defensive: faction changes are blocked while carrying a sack (Altar / rebirth); never keep one across a switch
	if sacks[player] then
		returnSack(player, true)
	end
end

------------------------------------------------------------------ lifecycle
function GrudgeService.Init(registry)
	S = registry
	S.PlayerService.PlayerReady:Connect(onPlayerReady)
	S.PlayerService.PlayerLeaving:Connect(onPlayerLeaving)
	S.FactionService.FactionChanged:Connect(onFactionChanged)
end

function GrudgeService.Start()
	-- (the anti-collusion cooldowns are in the saves now, CR-M4; PlayerService prunes them at PlayerReady)
	task.spawn(function()
		while true do
			local elapsed = task.wait(Config.Grudge.Tick)
			local dt = math.clamp(tonumber(elapsed) or Config.Grudge.Tick, 0, MAX_TICK_STEP)
			tickAll(dt)
		end
	end)

	print("[GrudgeService] started")
end

return GrudgeService
