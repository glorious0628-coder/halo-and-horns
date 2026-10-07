-- ProgressionService.luau : XP / levels, carried + bank gold, auto-bank, reward multipliers, monster kill rewards,
-- turncoat rebirth (TECH_SPEC §4.18 + SPEC_ADDENDUM A6 Neutral; A23-14: resets only Level/XP) and ResetLevel
-- (free class change).
-- Gold is changed ONLY through this service; Level/XP only through AddXP / ResetLevel / rebirth.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "ProgressionService"

local M = {}

-- public signals (created at module load so they exist before any Init)
M.GoldEarned = Util.Signal.new() -- (player, amount, source)
-- BB38 economy metrics (TelemetryService): gold that left a player: (player, amount, sink) - SpendGold's reason (Weapon,
-- Potion, ...) or TakeCarriedGold's (Plunder, Penalty, Kaiju, ...). Fired inside no-yield purchase steps: handlers must
-- not yield
M.GoldSpent = Util.Signal.new()
M.LeveledUp = Util.Signal.new() -- (player, newLevel)
M.Rebirthed = Util.Signal.new() -- (player, rebirths, { From, To, Bonus, Mark })
M.LevelReset = Util.Signal.new() -- (player) CR-M6: free class change dropped the player to Lv1 (QuestService remakes extras)

local S = nil

-- BB37: every server-wide line names players through AnnounceService.PublicName (hidden -> "<faction> 한 명")
local function publicName(p, honorific)
	local A = S.AnnounceService
	if A and A.PublicName then
		local ok, name = pcall(A.PublicName, p, honorific)
		if ok and type(name) == "string" then return name end
	end
	return Util.PlayerDisplayName(p) .. (honorific and Config.Announce.Text.Honorific or "")
end

local BANK_TICK = 1 -- seconds between town-bank / auto-bank checks
local WARN_THROTTLE = 10

-- A6: Neutral is a valid rebirth target next to Halo and Horns ("None" never is)
local REBIRTH_TARGETS = { Halo = true, Horns = true, Neutral = true }

local lastAutoBank = {} -- [Player] = os.clock() of the last courier run (or of PlayerReady)
local lastLoopWarn = {} -- [loopName] = os.clock()

------------------------------------------------------------------ helpers
local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
		return v
	end
	return default or 0
end

local function loopWarn(loopName, err)
	local now = os.clock()
	local last = lastLoopWarn[loopName]
	if last and now - last < WARN_THROTTLE then return end
	lastLoopWarn[loopName] = now
	Util.Warn(TAG, loopName .. ": " .. tostring(err))
end

local function connectSignal(serviceName, signalName, fn)
	local service = S and S[serviceName]
	local signal = service and service[signalName]
	if type(signal) == "table" and type(signal.Connect) == "function" then
		signal:Connect(fn)
	else
		Util.Warn(TAG, "missing signal " .. serviceName .. "." .. signalName)
	end
end

-- live data table of a READY player, else nil
local function getData(player)
	if S == nil or player == nil then return nil end
	if not S.PlayerService.IsReady(player) then return nil end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return nil end
	return data
end

local function getFaction(player)
	local f = S.FactionService.GetFaction(player)
	if type(f) ~= "string" then return "None" end
	return f
end

local function getPerks(player)
	local perks = S.FactionService.GetPerks(player)
	if type(perks) ~= "table" then perks = Config.Factions.None end
	return perks
end

local function getStars(player)
	return num(S.PvPService.GetStars(player))
end

local function hasBlessing(player)
	return S.WarService.HasBlessing(player) == true
end

local function rootPosition(player)
	local root = Util.GetRoot(player)
	if root then return root.Position end
	return nil
end

local function getKaijuState(player)
	local ks = S.KaijuService
	if not ks or type(ks.GetState) ~= "function" then return "None" end
	local ok, state = pcall(ks.GetState, player)
	if ok and type(state) == "string" then return state end
	return "None"
end

local function bullyStacks(player)
	local js = S.JusticeService
	if not js or type(js.GetBullyStacks) ~= "function" then return 0 end
	local ok, stacks = pcall(js.GetBullyStacks, player)
	return ok and num(stacks) or 0
end

-- CR-M2: no combat-log penalty while the server itself is closing
local function isShuttingDown()
	local ps = S.PlayerService
	if not ps or type(ps.IsShuttingDown) ~= "function" then return false end
	local ok, closing = pcall(ps.IsShuttingDown)
	return ok and closing == true
end

------------------------------------------------------------------ multipliers
function M.GetGoldMult(player)
	local data = getData(player)
	if not data then return 1 end
	local perks = getPerks(player)
	local mult = 1
		+ num(perks.GoldBonus)
		+ getStars(player) * Config.PvP.StarGoldBonus
		+ (hasBlessing(player) and Config.War.BlessingGold or 0)
		+ num(data.RebirthBonus)
		+ num(data.FallMarks) * Config.Rebirth.FallGoldPer
	return math.max(0, mult)
end

function M.GetXPMult(player)
	local data = getData(player)
	if not data then return 1 end
	local perks = getPerks(player)
	local mult = 1
		+ num(perks.XPBonus)
		+ (hasBlessing(player) and Config.War.BlessingXP or 0)
		+ num(data.RebirthBonus)
		+ num(data.RedeemMarks) * Config.Rebirth.RedeemXPPer
	-- A23-22 unruly-PvP penalty: XP x0.5 while the player is a bully or (A23-23) this week's outlaw; both = x0.5 once
	local pen = Config.Bully.Penalty
	if type(pen) == "table" and (num(player:GetAttribute("BullyStacks")) >= 1 or player:GetAttribute("Outlaw") == true) then
		mult *= num(pen.XPMult)
	end
	-- A23-22 / A23-24 weekly top 3: x RewardMult while RankingService shows the reward (only in that board's faction)
	local reward = player:GetAttribute("RankReward")
	if type(reward) == "string" and reward ~= "" and Config.Ranking then mult *= num(Config.Ranking.RewardMult) end
	return math.max(0, mult)
end

------------------------------------------------------------------ XP / levels
-- raw amount (no multiplier); handles level-ups
function M.AddXP(player, amount)
	amount = math.floor(num(amount))
	if amount <= 0 then return end
	local data = getData(player)
	if not data then return end

	local maxLevel = Config.Levels.MaxLevel
	local startLevel = math.clamp(math.floor(num(data.Level, 1)), 1, maxLevel)
	local level = startLevel
	local xp = math.max(0, num(data.XP)) + amount

	while level < maxLevel do
		local need = Config.XPToNext(level)
		if xp < need then break end
		xp -= need
		level += 1
	end
	if level >= maxLevel then
		level = maxLevel
		xp = math.min(xp, Config.XPToNext(maxLevel))
	end

	if level ~= data.Level then
		S.PlayerService.SetStat(player, "Level", level)
	end
	S.PlayerService.SetStat(player, "XP", xp)

	if level > startLevel then
		-- CR-M16: no full heal mid-fight (e.g. claiming a finished daily during PvP) or as an active kaiju
		local fullHeal = not S.CombatService.IsInCombat(player) and getKaijuState(player) ~= "Active"
		S.PlayerService.RefreshCharacter(player, fullHeal)
		-- CR-L23: the LevelUp Fx already shows the level-up announcement on the owner's screen (no extra toast)
		Net.Fx(nil, "LevelUp", {
			UserId = player.UserId,
			Level = level,
			Pos = rootPosition(player) or Vector3.zero,
		})
		M.LeveledUp:Fire(player, level)
	end
end

-- Level 1, XP 0, full heal (free class change). Gold, bank, weapon, rebirth bonus, marks, tickets, quests are kept
-- (unclaimed quest/vacation rewards are capped to the current level when claimed: QuestService CR-M6).
function M.ResetLevel(player)
	if not getData(player) then return end
	S.PlayerService.SetStat(player, "Level", 1)
	S.PlayerService.SetStat(player, "XP", 0)
	S.PlayerService.RefreshCharacter(player, true)
	M.LevelReset:Fire(player) -- CR-M6
end

------------------------------------------------------------------ gold
function M.AddCarriedGold(player, amount, source)
	amount = math.floor(num(amount))
	if amount <= 0 then return end
	if not getData(player) then return end
	S.PlayerService.AddStat(player, "CarriedGold", amount)
	M.GoldEarned:Fire(player, amount, source or "Other")
end

function M.AddBankGold(player, amount, source)
	amount = math.floor(num(amount))
	if amount <= 0 then return end
	if not getData(player) then return end
	S.PlayerService.AddStat(player, "BankGold", amount)
	M.GoldEarned:Fire(player, amount, source or "Other")
end

-- clamped to [0, carried]. Returns the amount actually taken. reason (optional) = the GoldSpent sink ("Taken")
function M.TakeCarriedGold(player, amount, reason)
	local data = getData(player)
	if not data then return 0 end
	local carried = math.floor(math.max(0, num(data.CarriedGold)))
	local taken = math.clamp(math.floor(num(amount)), 0, carried)
	if taken > 0 then
		S.PlayerService.SetStat(player, "CarriedGold", carried - taken)
		M.GoldSpent:Fire(player, taken, type(reason) == "string" and reason or "Taken")
	end
	return taken
end

-- carried first, then bank; false = nothing changed. reason (optional) = the GoldSpent sink ("Other")
function M.SpendGold(player, amount, reason)
	amount = math.ceil(num(amount, -1))
	if amount < 0 then return false end
	local data = getData(player)
	if not data then return false end
	local carried = math.floor(math.max(0, num(data.CarriedGold)))
	local bank = math.floor(math.max(0, num(data.BankGold)))
	if carried + bank < amount then return false end
	if amount == 0 then return true end
	local fromCarried = math.min(carried, amount)
	local fromBank = amount - fromCarried
	if fromCarried > 0 then
		S.PlayerService.SetStat(player, "CarriedGold", carried - fromCarried)
	end
	if fromBank > 0 then
		S.PlayerService.SetStat(player, "BankGold", bank - fromBank)
	end
	M.GoldSpent:Fire(player, amount, type(reason) == "string" and reason or "Other")
	return true
end

function M.GetTotalGold(player)
	local data = getData(player)
	if not data then return 0 end
	return math.max(0, num(data.CarriedGold)) + math.max(0, num(data.BankGold))
end

-- moves every carried coin to the bank; returns the banked amount
function M.BankAll(player, silent)
	local data = getData(player)
	if not data then return 0 end
	local carried = math.floor(math.max(0, num(data.CarriedGold)))
	if carried <= 0 then return 0 end
	S.PlayerService.SetStat(player, "CarriedGold", 0)
	S.PlayerService.AddStat(player, "BankGold", carried)
	if not silent then
		Net.Fx(player, "Bank", { Amount = carried }) -- CR-L23: the Bank Fx shows the only toast
	end
	return carried
end

------------------------------------------------------------------ auto-bank loop body
local function bankTick(player, now)
	local data = getData(player)
	if not data then return end
	local carried = math.floor(math.max(0, num(data.CarriedGold)))

	-- CR-M9: a siren / active kaiju keeps its pouch (the raid pool), even in Crossroads (Town = true)
	local ks = getKaijuState(player)
	if ks == "Siren" or ks == "Active" then return end

	-- towns (every faction's home, incl. Crossroads for Neutral) bank everything
	if S.ZoneService.IsTown(player) then
		if carried > 0 then
			M.BankAll(player, false)
		end
		return
	end

	-- faction courier (Halo: half of the carried gold every 90 s); Neutral/Horns/None have interval 0
	local perks = getPerks(player)
	local interval = num(perks.AutoBankInterval)
	if interval <= 0 then return end
	local last = lastAutoBank[player]
	if last == nil then
		lastAutoBank[player] = now
		return
	end
	if now - last < interval then return end
	lastAutoBank[player] = now

	local amount = math.floor(carried * num(perks.AutoBankFraction))
	if amount <= 0 then return end
	S.PlayerService.SetStat(player, "CarriedGold", carried - amount)
	S.PlayerService.AddStat(player, "BankGold", amount)
	Net.Fx(player, "Bank", { Amount = amount, Courier = true }) -- CR-L23: Fx shows the HaloCourier text (one toast)
end

------------------------------------------------------------------ turncoat rebirth
-- A6: ratios are Halo vs Horns only; Neutral targets always get the normal bonus.
-- CR-L7: counts skip rookies and 120 s idlers (FactionService.GetUnderdogCounts), so Lv1 alts cannot fake an underdog.
local function rebirthBonusFor(player, oldFaction, target)
	if target ~= "Halo" and target ~= "Horns" then
		return Config.Rebirth.BonusNormal
	end
	local fs = S.FactionService
	local halo, horns = nil, nil
	local selfCounted = true
	if type(fs.GetUnderdogCounts) == "function" then
		local ok, h, r = pcall(fs.GetUnderdogCounts)
		if ok and type(h) == "number" and type(r) == "number" then
			halo, horns = h, r
			-- the rebirthing player is active (MarkActive in onRebirthRemote); only a rookie is left out there
			local okR, rookie = pcall(S.PvPService.IsRookie, player)
			selfCounted = not (okR and rookie == true)
		end
	end
	if halo == nil then
		halo, horns = fs.GetCounts()
	end
	halo, horns = math.max(0, num(halo)), math.max(0, num(horns))
	if selfCounted then
		if oldFaction == "Halo" then
			halo = math.max(0, halo - 1)
		elseif oldFaction == "Horns" then
			horns = math.max(0, horns - 1)
		end
	end
	return Config.RebirthBonusFor(target == "Halo" and halo or horns, halo + horns)
end

-- turncoat marks only for Halo <-> Horns switches (A6)
local function markFor(oldFaction, target)
	if oldFaction == "Halo" and target == "Horns" then return "Fall" end
	if oldFaction == "Horns" and target == "Halo" then return "Redeem" end
	return "None"
end

function M.TryRebirth(player, factionId)
	if type(factionId) ~= "string" or not REBIRTH_TARGETS[factionId] then
		return false, nil
	end
	if not Config.Pickable(factionId) then -- A23-57: the artisan guild is off for the beta (refused + one log line)
		Util.Warn(TAG, ("%s asked to be reborn into the artisan guild, off for the beta (A23-57)"):format(player.Name))
		return false, nil
	end
	local data = getData(player)
	if not data then return false, nil end

	local rebirths = math.max(0, math.floor(num(data.Rebirths)))
	local needLevel = Config.RebirthLevel(rebirths)
	if num(data.Level, 1) < needLevel then
		return false, string.format(Config.Text.RebirthNeed, needLevel)
	end
	if getStars(player) > 0 then
		return false, string.format(Config.Text.BlockedStars)
	end
	if S.GrudgeService.HasSack(player) then
		return false, string.format(Config.Text.BlockedSack)
	end
	local kaijuState = S.KaijuService.GetState(player)
	if kaijuState ~= nil and kaijuState ~= "None" then
		return false, string.format(Config.Text.BlockedKaiju)
	end
	if S.CombatService.IsInCombat(player) then
		return false, string.format(Config.Text.TravelBlockedCombat)
	end
	-- CR-L9: the guild has no bully stacks, so becoming Neutral would wipe them; wait until they decay
	if factionId == "Neutral" and bullyStacks(player) > 0 then
		return false, string.format(Config.Text.BlockedBully or "You can join the Artisan Guild after all your bully levels are gone.")
	end

	local old = getFaction(player)
	local bonus = rebirthBonusFor(player, old, factionId)
	local mark = markFor(old, factionId)
	local pos = rootPosition(player) or Vector3.zero

	-- A23-14 (user 2026-10-05): rebirth resets ONLY the level and its XP. Carried + bank gold, the equipped weapon
	-- (WeaponTier), every owned weapon incl. the legendary (WeaponOwnedMask), per-tier enhancement (WeaponEnhance),
	-- items/materials (Items) and LootFlags are kept untouched (replaces A3-L2 / GDD §9 / A23-4 "reset gold + weapons").
	S.PlayerService.SetStat(player, "Level", 1)
	S.PlayerService.SetStat(player, "XP", 0)

	local newRebirths = rebirths + 1
	S.PlayerService.SetStat(player, "Rebirths", newRebirths)
	S.PlayerService.SetStat(player, "RebirthBonus", math.floor((num(data.RebirthBonus) + bonus) * 100 + 0.5) / 100)

	local markMax = Config.Rebirth.MarkMax
	if mark == "Fall" then
		S.PlayerService.SetStat(player, "FallMarks", math.min(markMax, math.floor(num(data.FallMarks)) + 1))
	elseif mark == "Redeem" then
		S.PlayerService.SetStat(player, "RedeemMarks", math.min(markMax, math.floor(num(data.RedeemMarks)) + 1))
	end

	if factionId ~= old then
		-- a rebirth faction change starts the altar cooldown too, so a player cannot bank the underdog bonus / a
		-- turncoat mark and then switch straight back for free at the altar (rebirth itself still ignores the cooldown)
		S.PlayerService.SetStat(player, "LastSwitchTime", os.time())
		S.FactionService.SetFaction(player, factionId, "Rebirth")
		S.PlayerService.Respawn(player)
	else
		S.PlayerService.RefreshCharacter(player, true)
	end

	Net.Fx(nil, "Rebirth", { UserId = player.UserId, Rebirths = newRebirths, Pos = pos, Mark = mark })
	Net.Notify(player, string.format(Config.Text.RebirthDone, math.floor(bonus * 100 + 0.5)), "reward")
	if mark == "Fall" then
		Net.Notify(player, string.format(Config.Story.Fall), "announce")
	elseif mark == "Redeem" then
		Net.Notify(player, string.format(Config.Story.Redeem), "announce")
	end
	Net.NotifyAll(string.format(Config.Text.RebirthAnnounce, publicName(player, true), newRebirths))
	M.Rebirthed:Fire(player, newRebirths, { From = old, To = factionId, Bonus = bonus, Mark = mark })
	return true, nil
end

------------------------------------------------------------------ handlers
local function onMonsterKilled(player, info)
	if type(info) ~= "table" or not getData(player) then return end
	local gold = math.floor(num(info.Gold) * M.GetGoldMult(player) + 0.5)
	local xp = math.floor(num(info.XP) * M.GetXPMult(player) + 0.5)
	-- A23-27: below def.XPCapBelowLevel a kill gives at most one level's XP (the Pumpkin King and a Lv1 player)
	local def = type(info.Kind) == "string" and Config.MonsterTypes[info.Kind] or nil
	local capBelow = def and tonumber(def.XPCapBelowLevel)
	if capBelow then
		local level = math.floor(num(getData(player).Level, 1))
		if level < capBelow then xp = math.min(xp, math.floor(Config.XPToNext(level))) end
	end
	M.AddCarriedGold(player, gold, "Monster")
	M.AddXP(player, xp)
	S.PlayerService.AddStat(player, "TotalKills", 1)
	local pos = info.Position
	if typeof(pos) ~= "Vector3" then
		pos = rootPosition(player) or Vector3.zero
	end
	Net.Fx(player, "Reward", { Pos = pos, Gold = gold, XP = xp, Golden = info.Golden == true })
end

local function onPlayerReady(player, _data)
	lastAutoBank[player] = os.clock()
	local data = getData(player)
	if data and num(data.CarriedGold) > 0 then
		M.BankAll(player, true) -- leftover from a crash
	end
end

-- fired once BEFORE the final save: mutate the data table directly (attributes no longer matter)
local function onPlayerLeaving(player, data)
	lastAutoBank[player] = nil
	if type(data) ~= "table" then
		data = S.PlayerService.GetData(player)
	end
	if type(data) ~= "table" then return end
	local carried = math.floor(math.max(0, num(data.CarriedGold)))
	-- CR-M2: a server shutdown (update) is not a combat log
	if carried > 0 and S.CombatService.IsInCombat(player) and not isShuttingDown() then
		carried = math.floor(carried * (1 - Config.PvP.CombatLogPenalty))
	end
	data.BankGold = math.max(0, num(data.BankGold)) + carried
	data.CarriedGold = 0
end

local function onRebirthRemote(player, factionId)
	if not S.PlayerService.IsReady(player) then return end
	if type(factionId) ~= "string" then return end
	if not Util.RateLimit(player, "Rebirth", Config.RateLimits.Rebirth) then return end
	if type(S.PlayerService.MarkActive) == "function" then
		S.PlayerService.MarkActive(player) -- CR-L7: pressing rebirth is input, so the player counts as active
	end
	local ok, reason = M.TryRebirth(player, factionId)
	if not ok and reason then
		Net.Notify(player, reason, "bad")
	end
end

------------------------------------------------------------------ lifecycle
function M.Init(registry)
	S = registry
	connectSignal("MonsterService", "MonsterKilled", onMonsterKilled)
	connectSignal("PlayerService", "PlayerReady", onPlayerReady)
	connectSignal("PlayerService", "PlayerLeaving", onPlayerLeaving)
end

function M.Start()
	Net.Get("Rebirth").OnServerEvent:Connect(onRebirthRemote)

	task.spawn(function()
		while true do
			task.wait(BANK_TICK)
			local now = os.clock()
			for _, player in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(bankTick, player, now)
				if not ok then loopWarn("bank loop", err) end
			end
		end
	end)

	print("[ProgressionService] started")
end

return M
