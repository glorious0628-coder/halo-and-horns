-- GrudgeService.luau : the grudge sack ("원한 돈자루"). Gold plundered by a Horns thief rides in ONE sack on the
-- thief's back; its 45 s countdown ticks only inside PvP zones. Survive -> Paid to the thief. A Halo KO in time ->
-- Avenged (victims get 120% to the bank, the avenger a bonus). Any other death / leaving -> Returned (100%).
-- P3 (2026-10-05): a victim who is not on this server gets their share by grudge mail at the next join.
-- A23-18: the respawned victim can hold the sack ([유령으로 붙잡기], +2 s per 3 s, max +10 s per sack).
-- Server only. See TECH_SPEC §4.14.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

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
-- RankInfamy (BB10: the fair weekly-board part of Infamy, credited only when the sack is Paid), LastVictimName }. Entry.Rebirths = the victim's Rebirths when stolen (CR-M6: no refund across a rebirth).
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

-- BB37: every server-wide line names players through AnnounceService.PublicName (hidden -> "<faction> 한 명")
local function publicName(p, honorific)
	local A = S.AnnounceService
	if A and A.PublicName then
		local ok, name = pcall(A.PublicName, p, honorific)
		if ok and type(name) == "string" then return name end
	end
	return Util.PlayerDisplayName(p) .. (honorific and Config.Announce.Text.Honorific or "")
end

local function fmt(key, ...)
	return string.format(Config.Text[key], ...)
end

local function notify(p, text, kind, sound)
	if isPlaying(p) then
		Net.Notify(p, text, kind, nil, sound)
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
local pointVictim -- A23-18 hold-button target (defined below with the grudge mail; closeSack calls it)

local function closeSack(thief, sack, outcome, tellThief)
	sacks[thief] = nil
	publish(thief, nil)
	if isPlaying(thief) then thief:SetAttribute("SackHeldUntil", 0) end
	for userId in sack.Entries do -- A23-18: the hold button moves to another open sack with my share, or hides
		local v = Players:GetPlayerByUserId(userId)
		if v then pointVictim(v) end
	end
	if tellThief and outcome ~= "Paid" then
		notify(thief, fmt("SackLost"), "bad", "None")
	end
	GrudgeService.SackResolved:Fire(thief, outcome, sack.Total)
end

------------------------------------------------------------------ P3 grudge mail
local MAIL = { Store = nil, Tried = false, Pending = 0 }

function MAIL.Get()
	if not MAIL.Tried then
		MAIL.Tried = true
		local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, Config.Grudge.MailStore)
		MAIL.Store = ok and store or nil
		if not ok then
			Util.Warn(TAG, "grudge mail store unavailable: " .. tostring(store))
			task.delay(60, function() MAIL.Tried = false end) -- try again later instead of never
		end
	end
	return MAIL.Store
end

-- in-flight letters (PlayerService's BindToClose waits for them)
function GrudgeService.MailPending()
	return MAIL.Pending
end

-- a share for a victim who is not here: { Id, A = amount, R = rebirths when stolen, K = "Avenged" | "Returned", T }.
-- Id = thief + sack start + kind, so a retried write never adds the same letter twice (review of 735419e).
-- A taken (paid) letter leaves a tombstone { Id, Done = true, T } for MAIL.TombSeconds, so a Send retry whose first
-- reply was lost cannot add it back after the victim already took it (review of 74345bf: no double pay).
MAIL.TombSeconds = 600 -- far longer than Send's retry span (1 + 2 + 4 s)

local function live(m)
	return type(m) == "table" and m.Done ~= true and (tonumber(m.A) or 0) > 0
end

-- drop old tombstones, then trim to MailMax: tombstones go first, then the oldest letters
local function tidy(list)
	local out, now = {}, os.time()
	for _, m in list do
		if type(m) == "table" and (live(m) or (m.Done == true and now - (tonumber(m.T) or 0) < MAIL.TombSeconds)) then
			table.insert(out, m)
		end
	end
	while #out > Config.Grudge.MailMax do
		local drop = 1
		for i, m in out do
			if m.Done == true then drop = i break end
		end
		table.remove(out, drop)
	end
	return out
end

function MAIL.Send(userId, entry, kind, letterId)
	local amount = math.floor(tonumber(entry.Amount) or 0)
	if amount <= 0 then return end
	MAIL.Pending += 1
	task.spawn(function()
		local store = MAIL.Get()
		for attempt = 1, 4 do
			if not store then break end
			local ok, err = pcall(store.UpdateAsync, store, "M_" .. tostring(userId), function(old)
				local list = tidy(type(old) == "table" and old or {})
				for _, m in list do
					if type(m) == "table" and m.Id == letterId then return nil end -- already written (or already taken)
				end
				table.insert(list, { Id = letterId, A = amount, R = tonumber(entry.Rebirths) or 0, K = kind, T = os.time() })
				return tidy(list)
			end)
			if ok then break end
			Util.Warn(TAG, ("grudge mail send %d/4 failed: %s"):format(attempt, tostring(err)))
			if attempt < 4 then task.wait(2 ^ (attempt - 1)) end
		end
		MAIL.Pending -= 1
	end)
end

local function canPay(victim)
	return isPlaying(victim) and S.PlayerService.IsReady(victim) and type(S.PlayerService.GetData(victim)) == "table"
end

-- the victim could not be paid after the take: the letters go back (in FRONT of newer ones, tombstones removed);
-- retried like Send, merged by Id so a lost reply never duplicates a letter
function MAIL.WriteBack(store, key, letters)
	for attempt = 1, 4 do
		local ok, err = pcall(store.UpdateAsync, store, key, function(old)
			local ids, list = {}, {}
			for _, m in letters do
				if live(m) and (m.Id == nil or not ids[m.Id]) then
					if m.Id ~= nil then ids[m.Id] = true end
					table.insert(list, m)
				end
			end
			for _, m in (type(old) == "table" and old or {}) do
				if type(m) == "table" and (m.Id == nil or not ids[m.Id]) then table.insert(list, m) end
			end
			return tidy(list)
		end)
		if ok then return end
		Util.Warn(TAG, ("grudge mail write-back %d/4 failed: %s"):format(attempt, tostring(err)))
		if attempt < 4 then task.wait(2 ^ (attempt - 1)) end
	end
	Util.Warn(TAG, "grudge mail write-back gave up (letters lost, never paid twice)")
end

-- at join: take every letter, pay those from this "life"; the 120% bonus needs Avenged and the victim's refund
-- cooldown, and only the first such letter gets it. If the victim cannot be paid after the mailbox was emptied
-- (left / not ready), the letters go back in (nothing was paid yet, so nothing can be paid twice).
-- Counted in MAIL.Pending, so BindToClose waits for a take / write-back in flight.
function MAIL.Receive(victim)
	local store = MAIL.Get()
	if not store or not canPay(victim) then return end
	local shutting = S.PlayerService.IsShuttingDown and S.PlayerService.IsShuttingDown()
	if shutting then return end -- the letters wait for the next join
	MAIL.Pending += 1
	local ok, err = pcall(MAIL.Take, store, victim)
	MAIL.Pending -= 1
	if not ok then Util.Warn(TAG, "grudge mail receive failed: " .. tostring(err)) end
end

function MAIL.Take(store, victim)
	local key = "M_" .. tostring(victim.UserId)
	local letters = nil
	local ok, err = pcall(store.UpdateAsync, store, key, function(old)
		letters = {}
		local keep = {}
		for _, m in tidy(type(old) == "table" and old or {}) do
			if live(m) then
				table.insert(letters, m)
				if m.Id ~= nil then table.insert(keep, { Id = m.Id, Done = true, T = os.time() }) end -- tombstone
			else
				table.insert(keep, m)
			end
		end
		if #letters == 0 then return nil end
		return keep
	end)
	if not ok then Util.Warn(TAG, "grudge mail read failed: " .. tostring(err)) return end
	if type(letters) ~= "table" or #letters == 0 then return end
	if not canPay(victim) then
		MAIL.WriteBack(store, key, letters)
		return
	end
	local rebirths = tonumber(victim:GetAttribute("Rebirths")) or 0
	local total, bonusUsed, seen = 0, false, {}
	for i, m in letters do
		local amount = math.floor(tonumber(type(m) == "table" and m.A or 0) or 0)
		local id = m.Id or i -- letters without an Id (first build) are each their own
		if amount > 0 and not seen[id] and (tonumber(m.R) or 0) == rebirths then -- CR-M6 sameLife
			seen[id] = true
			local rate = Config.Grudge.ReturnRate
			if m.K == "Avenged" and not bonusUsed and pairReady(victim, 0, "refund", Config.Grudge.RefundBonusCooldown) then
				rate, bonusUsed = Config.Grudge.AvengeRefundRate, true
			end
			total += math.floor(amount * rate)
		end
	end
	if total > 0 then
		S.ProgressionService.AddBankGold(victim, total, "Refund")
		notify(victim, fmt("GrudgeMail", Util.FormatNumber(total)), "good")
	end
end

-- A23-18: point the victim's hold button at an open sack that still carries their share from this life
-- (several thieves: when one sack closes, the button moves to the next one instead of disappearing)
function pointVictim(victim)
	if not isPlaying(victim) then return end
	local target = 0
	for thief, sack in sacks do
		local entry = sack.Entries[victim.UserId]
		if entry and isPlaying(thief) and sameLife(victim, entry) and (tonumber(entry.Amount) or 0) > 0 then
			target = thief.UserId
		end
	end
	if victim:GetAttribute("GrudgeThiefId") ~= target then victim:SetAttribute("GrudgeThiefId", target) end
end

------------------------------------------------------------------ outcomes
-- Paid: the thief survived 45 s of PvP-zone time
local function pay(thief, sack)
	S.ProgressionService.AddCarriedGold(thief, sack.Total, "Plunder")
	if sack.Infamy > 0 then
		-- BB10: the stat gets every point; the weekly board only the fair part (sack.RankInfamy, never sack.Infamy)
		S.PlayerService.GrantFame(thief, "Infamy", sack.Infamy, { RankPoints = sack.RankInfamy or 0 })
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
		elseif not victim then
			MAIL.Send(userId, entry, "Returned", sack.Id .. ":Returned") -- P3: paid at the next join (sameLife then)
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
				notify(victim, fmt("GrudgeRefund", Util.PlayerDisplayName(killer), Util.FormatNumber(refund)), "good")
				local victimPos = rootPos(victim)
				if thiefPos and victimPos then
					Net.Fx(victim, "Plunder", { From = thiefPos, To = victimPos, Amount = refund })
				end
			end
		elseif not victim then
			MAIL.Send(userId, entry, "Avenged", sack.Id .. ":Avenged") -- P3: 120% decided at the next join
		end
	end

	-- "복수 대행" bonus, once per AVENGER per PairRewardCooldown whatever the thief (CR-L6; avenger's save, CR-M4)
	if pairReady(killer, 0, "avenge", Config.PvP.PairRewardCooldown) then
		S.ProgressionService.AddBankGold(killer, G.AvengerBonus, "Bounty")
		notify(killer, fmt("AvengerBonus", Util.FormatNumber(G.AvengerBonus)), "reward")
	end

	Net.NotifyAll(fmt("GrudgeAvengedAll", publicName(killer, true), publicName(thief, true)), "info")
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

-- amount was already taken from the victim's carried gold (PvPService.HandleKO). rankPts (BB10) = the part of infamy
-- that passed the fair-points check (RankingService.JudgeKO); it reaches the weekly board only if the sack is Paid.
function GrudgeService.AddToSack(thief, victim, amount, infamy, rankPts)
	if not thief or not victim then
		return
	end
	amount = math.floor(tonumber(amount) or 0)
	infamy = math.max(0, math.floor(tonumber(infamy) or 0))
	rankPts = math.clamp(math.floor(tonumber(rankPts) or 0), 0, infamy)
	if amount <= 0 then
		return
	end

	local sack = sacks[thief]
	if not sack then
		sack = { Entries = {}, Total = 0, Remaining = 0, Infamy = 0, RankInfamy = 0, LastVictimName = "", Held = 0,
			Id = tostring(thief.UserId) .. ":" .. tostring(os.time()) } -- grudge mail letter ids
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
		entry.Name = Util.PlayerDisplayName(victim)
		entry.Rebirths = rebirths
	else
		sack.Entries[victim.UserId] = { Amount = amount, Name = Util.PlayerDisplayName(victim), Rebirths = rebirths }
	end
	sack.Total += amount
	-- every new steal restarts the countdown, keeping any ghost-hold seconds already added (never shortens it)
	sack.Held = sack.Held or 0
	sack.Remaining = math.max(sack.Remaining, Config.Grudge.SackSeconds + sack.Held)
	victim:SetAttribute("GrudgeThiefId", thief.UserId) -- A23-18: the victim's [유령으로 붙잡기] button targets this sack
	sack.Infamy += infamy
	sack.RankInfamy = (sack.RankInfamy or 0) + rankPts
	sack.LastVictimName = Util.PlayerDisplayName(victim)
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

------------------------------------------------------------------ A23-18 grudge ghost hold
local function onGhostHold(victim, ...)
	if select("#", ...) ~= 0 or not isPlaying(victim) or not S.PlayerService.IsReady(victim) then return end
	if not Util.IsAlive(victim) then return end -- the respawned victim holds, not the corpse
	if not Util.RateLimit(victim, "GhostHold", Config.RateLimits.GhostHold or Config.Grudge.HoldCooldown) then return end
	local G = Config.Grudge
	local thief = Players:GetPlayerByUserId(tonumber(victim:GetAttribute("GrudgeThiefId")) or 0)
	local sack = thief and sacks[thief]
	local entry = sack and sack.Entries[victim.UserId]
	if not entry or not sameLife(victim, entry) then
		pointVictim(victim) -- stale target (other life / sack moved): fix the button instead of failing silently
		return
	end
	local room = G.HoldMaxSeconds - (sack.Held or 0)
	if room <= 0 then
		notify(victim, fmt("GhostHoldMax", G.HoldMaxSeconds), "info")
		return
	end
	local add = math.min(G.HoldAddSeconds, room)
	sack.Held = (sack.Held or 0) + add
	sack.Remaining += add
	publish(thief, sack)
	-- the ghost above the thief glows hard while held, so other knights see the chase is on (no chat needed)
	local glowUntil = Util.Now() + G.HoldGlowSeconds
	thief:SetAttribute("SackHeldUntil", glowUntil)
	task.delay(G.HoldGlowSeconds + 0.1, function()
		if isPlaying(thief) and thief:GetAttribute("SackHeldUntil") == glowUntil then thief:SetAttribute("SackHeldUntil", 0) end
	end)
	notify(victim, fmt("GhostHoldOk", add, G.HoldMaxSeconds), "good")
	notify(thief, fmt("GhostHeld"), "bad", "None")
	S.PlayerService.MarkActive(victim)
end

------------------------------------------------------------------ signal handlers
local function onPlayerReady(player)
	player:SetAttribute("SackGold", 0)
	player:SetAttribute("SackSeconds", 0)
	player:SetAttribute("SackVictimName", "")
	player:SetAttribute("SackHeldUntil", 0)
	player:SetAttribute("GrudgeThiefId", 0)
	pointVictim(player) -- a rejoin on THIS server while a thief still carries my share: the hold button comes back
	task.spawn(function() -- P3: shares mailed while this victim was away
		local ok, err = pcall(MAIL.Receive, player)
		if not ok then Util.Warn(TAG, "grudge mail: " .. tostring(err)) end
	end)
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
	if S.ProgressionService and S.ProgressionService.Rebirthed then
		-- a rebirth starts a new "life": older shares are no longer mine to hold (CR-M6)
		S.ProgressionService.Rebirthed:Connect(function(player) pcall(pointVictim, player) end)
	end
end

function GrudgeService.Start()
	Net.Get("GhostHold").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onGhostHold, player, ...)
		if not ok then warnLoop(err) end
	end)
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
