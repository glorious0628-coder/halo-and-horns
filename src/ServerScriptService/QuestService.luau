-- QuestService.luau : 3 quest slots (KST dailies first, then rolling extras), claim, daily chest, reroll,
-- vacation bonus and QuestsJson publishing (TECH_SPEC §4.20), plus the first-60-seconds tutorial
-- (SPEC_ADDENDUM A4 / A5-C4..C6 / N1) and the faction-filtered quest pool (A6 Neutral).
-- data.Quests is mutated directly (documented exception); every other persisted stat goes through SetStat/AddStat.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "QuestService"

local M = {}

local S = nil

local PUBLISH_INTERVAL = 0.5
local TUTORIAL_TICK = 1
local WARN_THROTTLE = 10
local PROGRESS_EPS = 1e-6 -- Kill/Golden progress is fractional (killWeight)

------------------------------------------------------------------ tutorial constants (A4) — all from Config.Tutorial
local TUT_CFG = Config.Tutorial
local TUT_ID = TUT_CFG.QuestId -- claim id (N1) and QuestsJson Id of the pinned tutorial entry
local TUT_KIND = "Tutorial"
local STEP_KILL = TUT_CFG.Steps.Kill -- 0: personal golden slime
local STEP_GUIDE = TUT_CFG.Steps.Guide -- 1: HUD guide beam to GuideZone
local STEP_QUEST = TUT_CFG.Steps.Quest -- 2: pinned tutorial quest
local TUT_DONE = TUT_CFG.Steps.Done -- 99
local TUT_TARGET = TUT_CFG.QuestKills
local TUT_GOLD = TUT_CFG.QuestRewardGold
local TUT_XP = TUT_CFG.QuestRewardXP or 0
local TUT_TEXT = string.format(TUT_CFG.QuestText, TUT_TARGET)
local TUT_ZONE = TUT_CFG.GuideZone
local TUT_MONSTER = TUT_CFG.Monster
local TUT_MONSTER_OPTS = { Golden = TUT_CFG.Golden == true, HP = TUT_CFG.MonsterHP }
-- toast texts: Config.Text has no tutorial keys, so they stay private (plain format strings)
local TUT_START_TEXT = "튜토리얼 퀘스트: %s! (보상 %s골드)" -- (TUT_TEXT, gold)
local TUT_READY_TEXT = "튜토리얼 퀘스트 완료! [받기]를 눌러요."
local TUT_CLAIMED_TEXT = "튜토리얼 보상 +%s골드! 업그레이드 버튼으로 새 무기를 사 보세요!"
local SPAWN_DELAY_ON_SPAWN = 1 -- s after CharacterSpawned before the personal slime is placed
local SPAWN_DELAY_ON_CLASS = 0.5 -- s after the first class pick
local SPAWN_RETRY = 10 -- s between failed SpawnPersonal attempts
local SPAWN_MAX_FAILS = 3 -- then step 0 is skipped (the tutorial must never get stuck)

-- kills that count for the tutorial quest: monsters living in Slime Meadow
local TUTORIAL_KINDS = {}
for id, def in Config.MonsterTypes do
	if type(def) == "table" and def.Zone == TUT_ZONE then
		TUTORIAL_KINDS[id] = true
	end
end

------------------------------------------------------------------ templates
local TEMPLATE_BY_ID = {}
for _, t in Config.Quests.Templates do
	TEMPLATE_BY_ID[t.Id] = t
end

-- A6: quests that need a Halo/Horns side (PvP, plunder, bounty, goose tug, kaiju). Neutral and "None" never get them.
local SIDE_ONLY_IDS = { Hunt = true, Plunder = true, Goose = true, Bounty = true, Kaiju = true }

------------------------------------------------------------------ state (session only)
local dirty = {} -- [Player] = true -> QuestsJson republished by the publish loop
local rerollReadyAt = {} -- [Player] = server time
local tutorialProgress = {} -- [Player] = tutorial quest kills (step 2)
local personal = {} -- [Player] = { Model = Model, Conn = RBXScriptConnection }
local spawning = {} -- [Player] = true while SpawnPersonal is in flight
local spawnRetryAt = {} -- [Player] = os.clock()
local spawnFailures = {} -- [Player] = number
local lastLoopWarn = {} -- [loopName] = os.clock()
local warnedNoSpawnPersonal = false

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

local function getLevel(data)
	return math.max(1, math.floor(num(data and data.Level, 1)))
end

local function isSlotIndex(v)
	return type(v) == "number" and v == v and v % 1 == 0 and v >= 1 and v <= Config.Quests.Slots
end

local function isValidQuest(q)
	return type(q) == "table"
		and type(q.Id) == "string" and TEMPLATE_BY_ID[q.Id] ~= nil
		and (q.Kind == "Daily" or q.Kind == "Extra")
		and type(q.Target) == "number" and q.Target == q.Target and q.Target > 0
		and type(q.Progress) == "number" and q.Progress == q.Progress
		and type(q.RewardGold) == "number" and type(q.RewardXP) == "number"
		and type(q.Text) == "string"
end

local function isComplete(q)
	return q.Progress >= q.Target
end

local function othersExcept(quests, index)
	local out = {}
	for i, q in quests do
		if i ~= index and type(q) == "table" then
			table.insert(out, q)
		end
	end
	return out
end

local function isSide(faction)
	return faction == "Halo" or faction == "Horns"
end

local function templateFitsFaction(t, faction)
	if t.Faction ~= nil and t.Faction ~= faction then return false end
	if not isSide(faction) and (t.PvP or SIDE_ONLY_IDS[t.Id]) then return false end
	return true
end

local function pickWeighted(list)
	local total = 0
	for _, t in list do
		total += math.max(0, num(t.Weight))
	end
	if total <= 0 then
		return list[Util.Random:NextInteger(1, #list)]
	end
	local r = Util.Random:NextNumber() * total
	for _, t in list do
		local w = math.max(0, num(t.Weight))
		if w > 0 then
			if r < w then return t end
			r -= w
		end
	end
	return list[#list]
end

------------------------------------------------------------------ quest generation
-- others = quests in the OTHER slots (used for the PvP limit and the "different template" preference)
local function newQuest(player, kind, others)
	local data = S.PlayerService.GetData(player)
	local level = getLevel(data)
	local faction = getFaction(player)

	local otherIds, otherPvP = {}, 0
	for _, q in others or {} do
		if type(q) == "table" and type(q.Id) == "string" then
			otherIds[q.Id] = true
			local ot = TEMPLATE_BY_ID[q.Id]
			if ot and ot.PvP then otherPvP += 1 end
		end
	end

	local pvpAllowed = level >= Config.Quests.PvPMinLevel
		and otherPvP < (Config.Quests.MaxPvPQuests or 1)
		and not S.PvPService.IsRookie(player)

	local candidates, preferred = {}, {}
	for _, t in Config.Quests.Templates do
		if templateFitsFaction(t, faction) and (not t.PvP or pvpAllowed) then
			table.insert(candidates, t)
			if not otherIds[t.Id] then
				table.insert(preferred, t)
			end
		end
	end
	local pool = (#preferred > 0) and preferred or candidates
	local t
	if #pool > 0 then
		t = pickWeighted(pool)
	else
		t = TEMPLATE_BY_ID.Kill or Config.Quests.Templates[1]
	end

	local unitsList = (kind == "Daily" and t.DailyUnits) or t.Units
	if type(unitsList) ~= "table" or #unitsList == 0 then unitsList = { 1 } end
	local units = num(unitsList[Util.Random:NextInteger(1, #unitsList)], 1)

	local mainId = Config.ZoneMainMonster[Config.QuestZoneForLevel(level)]
	local main = Config.MonsterTypes[mainId]
	local target = (t.Id == "Gold") and units * main.Gold or units
	target = math.max(1, math.floor(target))

	local rewardGold, rewardXP
	if kind == "Daily" then
		rewardGold, rewardXP = Config.DailyQuestReward(level)
	else
		local per = num(t.RewardPerUnit, 1)
		local mult = Config.Quests.ExtraRewardMult
		rewardGold = math.floor(units * main.Gold * per * mult)
		rewardXP = math.floor(units * main.XP * per * mult)
	end

	local text
	if t.Id == "Gold" then
		text = string.format(t.Text, Util.FormatNumber(target))
	else
		text = string.format(t.Text, target)
	end

	local progress = 0
	if target >= 5 then
		progress = math.floor(target * Util.Random:NextNumber(Config.Quests.EndowedMin, Config.Quests.EndowedMax))
	end

	return {
		Id = t.Id,
		Kind = kind,
		Target = target,
		Progress = progress,
		RewardGold = math.floor(num(rewardGold)),
		RewardXP = math.floor(num(rewardXP)),
		Text = text,
		MinStacks = t.MinStacks,
		Unit = mainId, -- Kill/Golden progress is measured in kills of this monster (see killWeight)
	}
end

-- exactly Config.Quests.Slots valid quests; missing/invalid entries become fresh extras
local function ensureSlots(player, data)
	local slots = Config.Quests.Slots
	local old = (type(data.Quests) == "table") and data.Quests or {}
	local fixed = {}
	for i = 1, slots do
		local q = old[i]
		if isValidQuest(q) then
			q.Progress = math.clamp(q.Progress, 0, q.Target)
			fixed[i] = q
		end
	end
	for i = 1, slots do
		if not fixed[i] then
			local others = {}
			for j = 1, slots do
				if j ~= i and fixed[j] then table.insert(others, fixed[j]) end
			end
			fixed[i] = newQuest(player, "Extra", others)
		end
	end
	data.Quests = fixed
end

------------------------------------------------------------------ tutorial (A4 / A5)
local function getStep(player)
	local data = getData(player)
	if not data then return TUT_DONE end
	local step = data.TutorialStep
	if type(step) ~= "number" or step ~= step then return TUT_DONE end
	return step
end

local function clearPersonal(player)
	local rec = personal[player]
	personal[player] = nil
	if rec and rec.Conn then
		rec.Conn:Disconnect()
	end
end

local function setStep(player, step)
	if not getData(player) then return end
	S.PlayerService.SetStat(player, "TutorialStep", step)
	-- defensive mirror in case TutorialStep is missing from Config.Data.Mirrored
	if player:GetAttribute("TutorialStep") ~= step then
		player:SetAttribute("TutorialStep", step)
	end
	if step ~= STEP_KILL then
		clearPersonal(player) -- stop tracking; MonsterService despawns the slime on its own (Lifetime / kill)
	end
	if step == STEP_GUIDE then
		if S.ZoneService.GetZoneId(player) == TUT_ZONE then
			setStep(player, STEP_QUEST) -- already standing in the meadow
		end
	elseif step == STEP_QUEST then
		tutorialProgress[player] = 0
		dirty[player] = true
		Net.Notify(player, string.format(TUT_START_TEXT, TUT_TEXT, Util.FormatNumber(TUT_GOLD)), "good")
	else
		tutorialProgress[player] = nil
		dirty[player] = true
	end
end

-- the personal slime left the world (killed, timed out, or despawned with its owner)
local function onPersonalGone(player, model)
	local rec = personal[player]
	if not rec or rec.Model ~= model then return end
	clearPersonal(player)
	if getStep(player) ~= STEP_KILL then return end
	if Util.IsAlive(player) then
		setStep(player, STEP_GUIDE) -- A5-C4: a timed-out sandbag advances the tutorial
	end
	-- owner dead: stay on step 0; the next spawn places a new slime
end

local function spawnPersonalSlime(player)
	local monsterService = S.MonsterService
	if type(monsterService.SpawnPersonal) ~= "function" then
		if not warnedNoSpawnPersonal then
			warnedNoSpawnPersonal = true
			Util.Warn(TAG, "MonsterService.SpawnPersonal is missing; tutorial step 0 is skipped")
		end
		setStep(player, STEP_GUIDE)
		return
	end
	spawning[player] = true
	task.spawn(function()
		local ok, model = pcall(monsterService.SpawnPersonal, player, TUT_MONSTER, table.clone(TUT_MONSTER_OPTS))
		spawning[player] = nil
		if player.Parent == nil or getData(player) == nil then return end -- left mid-call (MonsterService cleans up)
		if getStep(player) ~= STEP_KILL then return end
		if ok and typeof(model) == "Instance" and model:IsDescendantOf(workspace) then
			spawnFailures[player] = nil
			clearPersonal(player)
			local rec = { Model = model, Conn = nil }
			rec.Conn = model.AncestryChanged:Connect(function()
				if not model:IsDescendantOf(workspace) then
					task.defer(onPersonalGone, player, model)
				end
			end)
			personal[player] = rec
		else
			if not ok then
				Util.Warn(TAG, "SpawnPersonal failed: " .. tostring(model))
			end
			local fails = (spawnFailures[player] or 0) + 1
			spawnFailures[player] = fails
			spawnRetryAt[player] = os.clock() + SPAWN_RETRY
			if fails >= SPAWN_MAX_FAILS then
				setStep(player, STEP_GUIDE)
			end
		end
	end)
end

-- idempotent: (re)starts the current tutorial step (A5-C4); called on spawn, first class pick and every second
local function tryTutorial(player)
	local data = getData(player)
	if not data then return end
	local step = getStep(player)
	if step == STEP_GUIDE then
		if S.ZoneService.GetZoneId(player) == TUT_ZONE then
			setStep(player, STEP_QUEST)
		end
		return
	end
	if step ~= STEP_KILL then return end
	-- step 0 starts after the first faction + class pick and a spawn
	if data.ClassChosen ~= true or getFaction(player) == "None" then return end
	if not Util.IsAlive(player) then return end
	local rec = personal[player]
	if rec then
		if rec.Model and rec.Model:IsDescendantOf(workspace) then return end
		onPersonalGone(player, rec.Model)
		return
	end
	if spawning[player] then return end
	if os.clock() < (spawnRetryAt[player] or 0) then return end
	spawnPersonalSlime(player)
end

local function tutorialKill(player, info)
	local cur = tutorialProgress[player] or 0
	if cur >= TUT_TARGET or not TUTORIAL_KINDS[info.Kind] then return end
	cur += 1
	tutorialProgress[player] = cur
	dirty[player] = true
	if cur >= TUT_TARGET then
		Net.Notify(player, string.format(TUT_READY_TEXT), "good")
	end
end

local function claimTutorial(player)
	if getStep(player) ~= STEP_QUEST then return end
	if (tutorialProgress[player] or 0) < TUT_TARGET then return end
	setStep(player, TUT_DONE) -- first, so it can never be paid twice
	S.ProgressionService.AddBankGold(player, TUT_GOLD, "Quest")
	if TUT_XP > 0 then
		S.ProgressionService.AddXP(player, TUT_XP)
	end
	Net.Notify(player, string.format(TUT_CLAIMED_TEXT, Util.FormatNumber(TUT_GOLD)), "reward")
end

------------------------------------------------------------------ publish
local function publish(player)
	dirty[player] = nil
	local data = getData(player)
	if not data then return end
	local list = {}
	if getStep(player) == STEP_QUEST then
		-- A5-C6: pinned tutorial first; no Slot, cannot be rerolled, claimed with "tutorial"
		table.insert(list, {
			Id = TUT_ID,
			Kind = TUT_KIND,
			Text = TUT_TEXT,
			Progress = math.min(TUT_TARGET, tutorialProgress[player] or 0),
			Target = TUT_TARGET,
			RewardGold = TUT_GOLD,
			RewardXP = TUT_XP,
			Pinned = true,
		})
	end
	if type(data.Quests) == "table" then
		for i, q in ipairs(data.Quests) do
			if type(q) == "table" then
				table.insert(list, {
					Id = tostring(q.Id),
					Kind = q.Kind,
					Text = tostring(q.Text),
					Progress = math.floor(num(q.Progress) + PROGRESS_EPS), -- Kill/Golden progress can be fractional
					Target = num(q.Target),
					RewardGold = num(q.RewardGold),
					RewardXP = num(q.RewardXP),
					Slot = i, -- N1: clients address quests by Slot, never by array index
				})
			end
		end
	end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, list)
	if ok then
		player:SetAttribute("QuestsJson", json)
	else
		Util.Warn(TAG, "QuestsJson encode failed: " .. tostring(json))
	end
end

------------------------------------------------------------------ progress & completion
local function payReward(player, gold, xp)
	if gold > 0 then
		S.ProgressionService.AddBankGold(player, gold, "Quest")
	end
	if xp > 0 then
		S.ProgressionService.AddXP(player, xp)
	end
end

local function completeQuest(player, data, index, q)
	q.Progress = q.Target
	dirty[player] = true
	if q.Kind == "Extra" then
		-- replace first so the finished quest can never be paid twice
		data.Quests[index] = newQuest(player, "Extra", othersExcept(data.Quests, index))
		payReward(player, math.floor(num(q.RewardGold)), math.floor(num(q.RewardXP)))
		Net.Notify(player, string.format(Config.Text.QuestDone, Util.FormatNumber(q.RewardGold)), "reward")
	else
		-- dailies stay in their slot until claimed
		Net.Notify(player, string.format(Config.Text.DailyReady), "good")
	end
end

-- Kill/Golden progress of one kill of monster `kind`, in units of the quest's monster (q.Unit, fixed at generation):
-- a weaker monster counts def.XP / unit.XP (never more than 1), so quests whose rewards were sized for the player's
-- level zone cannot be farmed on safe low-zone slimes (also not after a free class change or a rebirth).
local function killWeight(q, kind, level)
	local unitId = q.Unit
	if type(unitId) ~= "string" or Config.MonsterTypes[unitId] == nil then
		unitId = Config.ZoneMainMonster[Config.QuestZoneForLevel(level)] -- quests saved before Unit existed
	end
	local unit = Config.MonsterTypes[unitId]
	local def = Config.MonsterTypes[kind]
	if type(unit) ~= "table" or type(def) ~= "table" or num(unit.XP) <= 0 then return 1 end
	return math.clamp(num(def.XP) / unit.XP, 0, 1)
end

-- amount: number, or function(q) -> number (per-quest amount); accept(q) optional filter
local function addProgress(player, questId, amount, accept)
	if type(amount) ~= "function" then
		amount = num(amount)
		if amount <= 0 then return end
	end
	local data = getData(player)
	if not data or type(data.Quests) ~= "table" then return end
	local quests = data.Quests
	for i = 1, #quests do
		local q = quests[i]
		if type(q) == "table" and q.Id == questId and type(q.Progress) == "number" and type(q.Target) == "number"
			and q.Progress < q.Target and (accept == nil or accept(q)) then
			local add = if type(amount) == "function" then num(amount(q)) else amount
			if add > 0 then
				local progress = q.Progress + add
				if progress >= q.Target - PROGRESS_EPS then
					progress = q.Target -- fractional kill weights must never leave a quest at 49.9999 / 50
				end
				q.Progress = progress
				dirty[player] = true
				if q.Progress >= q.Target then
					completeQuest(player, data, i, q)
				end
			end
		end
	end
end

------------------------------------------------------------------ day check / vacation
local function runDayCheck(player)
	local data = getData(player)
	if not data then return end
	local today = Config.DayIndex(os.time())
	local dailyDay = math.floor(num(data.DailyDay))
	if dailyDay == today then return end

	-- build the fresh dailies first (no side effects yet)
	local fresh = {}
	for i = 1, Config.Quests.Slots do
		fresh[i] = newQuest(player, "Daily", fresh)
	end

	-- completed but unclaimed dailies of the old day are paid automatically
	local toPay = {}
	if type(data.Quests) == "table" then
		for _, q in data.Quests do
			if isValidQuest(q) and q.Kind == "Daily" and isComplete(q) then
				table.insert(toPay, q)
			end
		end
	end

	-- commit: the day flips before anything is paid, so a failure can never double-pay
	S.PlayerService.SetStat(player, "DailyDay", today)
	S.PlayerService.SetStat(player, "DailyClaims", 0)

	if dailyDay > 0 and today > dailyDay + 1 then
		local missed = today - dailyDay - 1
		local days = math.min(Config.Daily.VacationMaxDays, math.max(0, math.floor(num(data.VacationDays))) + missed)
		local g, x = Config.VacationReward(getLevel(data), days)
		S.PlayerService.SetStat(player, "VacationDays", days)
		S.PlayerService.SetStat(player, "VacationGold", g)
		S.PlayerService.SetStat(player, "VacationXP", x)
	end

	data.Quests = fresh
	dirty[player] = true

	local paidGold = 0
	for _, q in toPay do
		local g = math.floor(num(q.RewardGold))
		paidGold += g
		payReward(player, g, math.floor(num(q.RewardXP)))
	end
	if paidGold > 0 then
		Net.Notify(player, string.format(Config.Text.DailyAutoPaid, Util.FormatNumber(paidGold)), "reward")
	end
end

------------------------------------------------------------------ remotes
local function onClaimQuest(player, slot)
	if not S.PlayerService.IsReady(player) then return end
	local isTutorial = (slot == TUT_ID)
	if not isTutorial and not isSlotIndex(slot) then return end
	if not Util.RateLimit(player, "ClaimQuest", Config.RateLimits.ClaimQuest) then return end
	local data = getData(player)
	if not data then return end

	if isTutorial then
		claimTutorial(player)
		return
	end

	if type(data.Quests) ~= "table" then return end
	local q = data.Quests[slot]
	if not isValidQuest(q) or q.Kind ~= "Daily" or not isComplete(q) then return end -- silent

	data.Quests[slot] = newQuest(player, "Extra", othersExcept(data.Quests, slot))
	dirty[player] = true

	local g, x = math.floor(num(q.RewardGold)), math.floor(num(q.RewardXP))
	payReward(player, g, x)
	Net.Notify(player, string.format(Config.Text.DailyClaimed, Util.FormatNumber(g), Util.FormatNumber(x)), "reward")

	local claims = num(S.PlayerService.AddStat(player, "DailyClaims", 1))
	if claims == Config.Quests.Slots then
		local cg, cx = Config.DailyChestReward(getLevel(data))
		cg, cx = math.floor(num(cg)), math.floor(num(cx))
		payReward(player, cg, cx)
		Net.Notify(player, string.format(Config.Text.DailyChest, Util.FormatNumber(cg), Util.FormatNumber(cx)), "reward")
		if Util.Random:NextNumber() < Config.Daily.ChestTicketChance then
			S.MonetizationService.AddTickets(player, "Class", 1)
			Net.Notify(player, string.format(Config.Text.DailyChestTicket), "reward")
		end
	end
end

local function onRerollQuest(player, slot)
	if not S.PlayerService.IsReady(player) then return end
	if not isSlotIndex(slot) then return end
	if not Util.RateLimit(player, "RerollQuest", Config.RateLimits.RerollQuest) then return end
	local data = getData(player)
	if not data or type(data.Quests) ~= "table" then return end

	local now = Util.Now()
	if now < (rerollReadyAt[player] or 0) then return end

	local q = data.Quests[slot]
	local kind = "Extra"
	if isValidQuest(q) then
		if isComplete(q) then return end
		kind = q.Kind
	end

	data.Quests[slot] = newQuest(player, kind, othersExcept(data.Quests, slot))
	local readyAt = now + Config.Quests.RerollCooldown
	rerollReadyAt[player] = readyAt
	player:SetAttribute("RerollReadyAt", readyAt)
	dirty[player] = true
end

local function onClaimVacation(player)
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "ClaimVacation", Config.RateLimits.ClaimVacation) then return end
	local data = getData(player)
	if not data then return end
	if num(data.VacationDays) <= 0 then return end -- silent

	local g = math.floor(math.max(0, num(data.VacationGold)))
	local x = math.floor(math.max(0, num(data.VacationXP)))
	-- zero first, so the reward can never be claimed twice
	S.PlayerService.SetStat(player, "VacationDays", 0)
	S.PlayerService.SetStat(player, "VacationGold", 0)
	S.PlayerService.SetStat(player, "VacationXP", 0)
	payReward(player, g, x)
	Net.Notify(player, string.format(Config.Text.VacationClaimed, Util.FormatNumber(g), Util.FormatNumber(x)), "reward")
end

------------------------------------------------------------------ signal handlers
local function onPlayerReady(player, data)
	if type(data) ~= "table" then data = getData(player) end
	if type(data) ~= "table" then return end

	rerollReadyAt[player] = 0
	player:SetAttribute("RerollReadyAt", 0)

	local step = data.TutorialStep
	if type(step) ~= "number" or step ~= step then step = TUT_DONE end
	if player:GetAttribute("TutorialStep") ~= step then
		player:SetAttribute("TutorialStep", step)
	end
	if step == STEP_QUEST then
		tutorialProgress[player] = 0 -- tutorial quest progress is session only
	end

	ensureSlots(player, data)
	runDayCheck(player)
	publish(player)
end

local function onPlayerLeaving(player)
	clearPersonal(player)
	dirty[player] = nil
	rerollReadyAt[player] = nil
	tutorialProgress[player] = nil
	spawning[player] = nil
	spawnRetryAt[player] = nil
	spawnFailures[player] = nil
end

local function onCharacterSpawned(player)
	task.delay(SPAWN_DELAY_ON_SPAWN, function()
		local ok, err = pcall(tryTutorial, player)
		if not ok then Util.Warn(TAG, "tutorial on spawn: " .. tostring(err)) end
	end)
end

local function onClassChanged(player)
	task.delay(SPAWN_DELAY_ON_CLASS, function()
		local ok, err = pcall(tryTutorial, player)
		if not ok then Util.Warn(TAG, "tutorial on class pick: " .. tostring(err)) end
	end)
end

local function onZoneChanged(player, newZoneId)
	if newZoneId == TUT_ZONE and getStep(player) == STEP_GUIDE then
		setStep(player, STEP_QUEST)
	end
end

local function onMonsterKilled(player, info)
	if type(info) ~= "table" then return end
	local data = getData(player)
	if not data then return end
	local step = getStep(player) -- read before any transition so the step-0 kill never counts for step 2
	local level = getLevel(data)
	local function weight(q)
		return killWeight(q, info.Kind, level)
	end
	addProgress(player, "Kill", weight)
	if info.Golden == true then
		addProgress(player, "Golden", weight)
	end
	if step == STEP_KILL then
		setStep(player, STEP_GUIDE) -- the personal slime (or any first kill: every step is skippable by playing)
	elseif step == STEP_QUEST then
		tutorialKill(player, info)
	end
end

local function onGoldEarned(player, amount, source)
	if source ~= "Monster" then return end
	addProgress(player, "Gold", math.floor(num(amount)))
end

-- A3-L3: automatic releases count too
local function onReleased(player, info)
	if type(info) ~= "table" then return end
	local stacks = num(info.Stacks)
	addProgress(player, "Release", 1, function(q)
		return stacks >= num(q.MinStacks)
	end)
end

local function onGooseFinished(_result, counts)
	if type(counts) ~= "table" then return end
	for p, c in counts do
		if typeof(p) == "Instance" and p:IsA("Player") and num(c) > 0 then
			addProgress(p, "Goose", 1)
		end
	end
end

local function onPlayerKO(killer, _victim, info)
	if type(info) ~= "table" or typeof(killer) ~= "Instance" then return end
	if info.Kind == "Bounty" then
		addProgress(killer, "Hunt", 1)
	elseif info.Kind == "Plunder" then
		addProgress(killer, "Plunder", 1)
	end
end

local function onKaijuEnded(_kaiju, outcome, participants)
	if outcome ~= "Defeated" or type(participants) ~= "table" then return end
	for _, p in participants do
		if typeof(p) == "Instance" and p:IsA("Player") then
			addProgress(p, "Hunt", 1)
		end
	end
end

-- regenerate (same Kind) unfinished slots whose template no longer fits the new faction
local function onFactionChanged(player, newFaction)
	local data = getData(player)
	if not data or type(data.Quests) ~= "table" then return end
	if type(newFaction) ~= "string" then newFaction = getFaction(player) end
	local quests = data.Quests
	for i = 1, #quests do
		local q = quests[i]
		if isValidQuest(q) and not isComplete(q) and not templateFitsFaction(TEMPLATE_BY_ID[q.Id], newFaction) then
			quests[i] = newQuest(player, q.Kind, othersExcept(quests, i))
			dirty[player] = true
		end
	end
end

-- dailies keep their rewards; extras are regenerated for the new (level 1) life
local function onRebirthed(player)
	local data = getData(player)
	if not data or type(data.Quests) ~= "table" then return end
	local quests = data.Quests
	for i = 1, Config.Quests.Slots do
		local q = quests[i]
		if not isValidQuest(q) or q.Kind == "Extra" then
			quests[i] = newQuest(player, "Extra", othersExcept(quests, i))
		end
	end
	dirty[player] = true
end

------------------------------------------------------------------ public API
function M.GetQuests(player)
	local data = getData(player)
	if not data or type(data.Quests) ~= "table" then return {} end
	return data.Quests
end

-- Studio hook: pretend the player was away for `days` whole days, then run the day check
function M.DebugSimulateAbsence(player, days)
	if not getData(player) then return end
	days = math.max(0, math.floor(num(tonumber(days), 1)))
	local today = Config.DayIndex(os.time())
	S.PlayerService.SetStat(player, "DailyDay", today - (days + 1))
	runDayCheck(player)
	publish(player)
end

------------------------------------------------------------------ lifecycle
function M.Init(registry)
	S = registry
	connectSignal("PlayerService", "PlayerReady", onPlayerReady)
	connectSignal("PlayerService", "PlayerLeaving", onPlayerLeaving)
	connectSignal("PlayerService", "CharacterSpawned", onCharacterSpawned)
	connectSignal("MonsterService", "MonsterKilled", onMonsterKilled)
	connectSignal("ProgressionService", "GoldEarned", onGoldEarned)
	connectSignal("ProgressionService", "Rebirthed", onRebirthed)
	connectSignal("CombatService", "Released", onReleased)
	connectSignal("GooseService", "GooseFinished", onGooseFinished)
	connectSignal("PvPService", "PlayerKO", onPlayerKO)
	connectSignal("KaijuService", "KaijuEnded", onKaijuEnded)
	connectSignal("FactionService", "FactionChanged", onFactionChanged)
	connectSignal("ClassService", "ClassChanged", onClassChanged)
	connectSignal("ZoneService", "ZoneChanged", onZoneChanged)
end

function M.Start()
	Net.Get("ClaimQuest").OnServerEvent:Connect(onClaimQuest)
	Net.Get("RerollQuest").OnServerEvent:Connect(onRerollQuest)
	Net.Get("ClaimVacation").OnServerEvent:Connect(onClaimVacation)

	-- publish dirty quest lists
	task.spawn(function()
		while true do
			task.wait(PUBLISH_INTERVAL)
			local list = {}
			for p in dirty do
				table.insert(list, p)
			end
			for _, p in list do
				local ok, err = pcall(publish, p)
				if not ok then loopWarn("publish loop", err) end
			end
		end
	end)

	-- KST day rollover for online players
	task.spawn(function()
		while true do
			task.wait(Config.Daily.CheckInterval)
			for _, p in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(runDayCheck, p)
				if not ok then loopWarn("day loop", err) end
			end
		end
	end)

	-- tutorial watchdog: (re)starts step 0 / detects the meadow for step 1, so it can never get stuck
	task.spawn(function()
		while true do
			task.wait(TUTORIAL_TICK)
			for _, p in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(tryTutorial, p)
				if not ok then loopWarn("tutorial loop", err) end
			end
		end
	end)

	print("[QuestService] started")
end

return M
