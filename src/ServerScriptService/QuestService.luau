-- QuestService.luau : 3 quest slots (KST dailies first, then rolling extras), claim, daily chest, reroll,
-- vacation bonus and quest-list publishing to the owner only via the "Quests" remote (TECH_SPEC §4.20, CR-L50),
-- plus persistent first-hunt guidance (2026-10-04: no personal monster in a safe town)
-- and the faction-filtered quest pool (A6 Neutral).
-- data.Quests is mutated directly (documented exception); every other persisted stat goes through SetStat/AddStat.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
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
local TUT_ID = TUT_CFG.QuestId -- claim id (N1) and quest-list Id of the pinned tutorial entry
local TUT_KIND = "Tutorial"
local STEP_WELCOME = TUT_CFG.Steps.Kill -- 0: faction guide dialogue; only explicit acceptance advances
local STEP_GUIDE = TUT_CFG.Steps.Guide -- 1: HUD guide beam to GuideZone
local STEP_QUEST = TUT_CFG.Steps.Quest -- 2: pinned tutorial quest
local TUT_DONE = TUT_CFG.Steps.Done -- 99
local TUT_TARGET = TUT_CFG.QuestKills
local TUT_GOLD = TUT_CFG.QuestRewardGold
local TUT_XP = TUT_CFG.QuestRewardXP or 0
local TUT_TEXT = string.format(TUT_CFG.QuestText, TUT_TARGET)
local TUT_ZONE = TUT_CFG.GuideZone
local TUT_MESSAGES = TUT_CFG.Text or {}
local TUT_START_TEXT = TUT_MESSAGES.QuestStart or "첫 임무: %s! (보상 %s골드)" -- (TUT_TEXT, gold)
local TUT_READY_TEXT = TUT_MESSAGES.QuestReady or "첫 임무 완료! [받기]를 눌러요."
local TUT_CLAIMED_TEXT = TUT_MESSAGES.Claimed or "첫 임무 보상 +%s골드! 다음 목표를 확인해요."
local RESUME_DELAY_ON_SPAWN = 1
local RESUME_DELAY_ON_CLASS = 0.5

-- kills that count for the tutorial quest: monsters living in Slime Meadow (looked up with Config.QuestKind(kind), so a
-- seasonal kind counts as the kind it stands in for)
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

-- A23-14: short, different Lv1-9 dailies and their smaller rewards (nil table = old behaviour everywhere)
local NEWBIE = Config.Quests.Newbie

------------------------------------------------------------------ state (session only)
local dirty = {} -- [Player] = true -> quest list republished by the publish loop
local lastSent = {} -- [Player] = last JSON fired on the "Quests" remote (CR-L50: fire only on change)
local rerollReadyAt = {} -- [Player] = server time
local lastLoopWarn = {} -- [loopName] = os.clock()
local welcomeShown = {} -- [Player] = true after this session's first automatic guide dialogue
-- F10-4: [Player] = os.clock() when this server first saw the first mission at 5/5 unclaimed (safety-net timer)
local TUT_READY_AT = {}
local claimTutorial -- defined with the claim code below; the tutorial loop (safety net) calls it

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

-- CR-M6: unclaimed rewards never pay more than the CURRENT level's value (free class change / rebirth to Lv1).
-- After a level-up the stored value is the smaller one, so it is paid unchanged.
local function capTo(g, x, capG, capX)
	return math.min(g, math.floor(num(capG))), math.min(x, math.floor(num(capX)))
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

-- A23-14: Lv1..Newbie.MaxLevel get the short newbie dailies and the smaller newbie chest
local function isNewbieLevel(level)
	return type(NEWBIE) == "table" and type(NEWBIE.Dailies) == "table" and #NEWBIE.Dailies > 0
		and level <= num(NEWBIE.MaxLevel, 0)
end

-- full-set chest at one level; Lv1-9 pays Newbie.ChestMinutes of hunting instead of Daily's
local function chestAt(level)
	if isNewbieLevel(level) then
		return Config.HuntValue(level, num(NEWBIE.ChestMinutes, Config.Daily.ChestMinutes))
	end
	return Config.DailyChestReward(level)
end

-- the chest pays the SMALLER of the current level's chest and the chest of the level the day's dailies were generated
-- at (genLevel, saved as data.DailyLevel; 0 = unknown -> current only). A Lv9 player who levels to 10 before the last
-- claim therefore gets the newbie chest (144/240), not the Lv10 one (1920/3360); a reborn player never gets more either.
local function chestReward(level, genLevel)
	local g, x = chestAt(level)
	genLevel = math.floor(num(genLevel))
	if genLevel >= 1 and genLevel ~= level then
		local gg, gx = chestAt(math.min(genLevel, Config.Levels.MaxLevel))
		g, x = math.min(g, gg), math.min(x, gx)
	end
	return g, x
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
	-- A23-14: Lv1-9 dailies come from Config.Quests.Newbie.Dailies (rows reuse a template Id); everything else as before
	local newbie = kind == "Daily" and isNewbieLevel(level)

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

	-- rows = templates, or A23-14 newbie rows ({ Id = template Id, Targets, Monster?, Strict? })
	local candidates, preferred = {}, {}
	for _, row in (if newbie then NEWBIE.Dailies else Config.Quests.Templates) do
		local rt = type(row) == "table" and TEMPLATE_BY_ID[row.Id]
		if rt and templateFitsFaction(rt, faction) and (not rt.PvP or pvpAllowed) then
			table.insert(candidates, row)
			if not otherIds[row.Id] then
				table.insert(preferred, row)
			end
		end
	end
	local pool = (#preferred > 0) and preferred or candidates
	local row
	if #pool > 0 then
		row = pickWeighted(pool)
	else
		newbie = false -- nothing fits: the old Kill daily (sizes and reward) is the safe fallback
		row = TEMPLATE_BY_ID.Kill or Config.Quests.Templates[1]
	end
	local t = TEMPLATE_BY_ID[row.Id] or row

	local unitsList
	if newbie then
		unitsList = row.Targets
	else
		unitsList = (kind == "Daily" and t.DailyUnits) or t.Units
	end
	if type(unitsList) ~= "table" or #unitsList == 0 then unitsList = { 1 } end
	local units = num(unitsList[Util.Random:NextInteger(1, #unitsList)], 1)

	local mainId = Config.ZoneMainMonster[Config.QuestZoneForLevel(level)]
	local main = Config.MonsterTypes[mainId]
	-- the monster a Kill/Golden quest counts: the zone's unit monster, or the newbie row's Monster (e.g. BigSlime)
	local unitId = mainId
	if newbie and type(row.Monster) == "string" and type(Config.MonsterTypes[row.Monster]) == "table" then
		unitId = row.Monster
	end
	local unitDef = Config.MonsterTypes[unitId]
	local target = units -- newbie Targets are exact (a Gold row already says gold)
	if t.Id == "Gold" and not newbie then
		target = units * main.Gold
	end
	target = math.max(1, math.floor(target))

	local rewardGold, rewardXP
	if kind == "Daily" then
		if newbie then
			rewardGold, rewardXP = Config.HuntValue(level, num(NEWBIE.RewardMinutes, Config.Daily.QuestMinutes))
		else
			rewardGold, rewardXP = Config.DailyQuestReward(level)
		end
	else
		local per = num(t.RewardPerUnit, 1)
		local mult = Config.Quests.ExtraRewardMult
		rewardGold = math.floor(units * main.Gold * per * mult)
		rewardXP = math.floor(units * main.XP * per * mult)
	end

	local text
	if t.Id == "Gold" then
		text = string.format(t.Text, tostring(target)) -- CR-L31: exact number (FormatNumber rounds to "3.2K")
	elseif t.Id == "Kill" or t.Id == "Golden" then
		text = string.format(t.Text, tostring(unitDef.Short or unitDef.Name), target) -- CR-M27: (monster name, target)
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
		Unit = unitId, -- Kill/Golden progress is measured in kills of this monster (see killWeight)
		Strict = (newbie and row.Strict == true) or nil, -- A23-14: only Unit (or stronger) kills count, 1 each
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
			if q.Id == "Release" then
				q.MinStacks = nil
				q.Text = string.format(TEMPLATE_BY_ID.Release.Text, q.Target)
			end
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

-- A saved counter, not a session cache: 4/5 and unclaimed 5/5 survive a normal save/rejoin.
-- A23-34: true when this save owns tier 1, the first weapon (saves from before A23-34 always do)
local function hasFirstWeapon(data)
	return type(data) == "table" and bit32.btest(math.floor(num(data.WeaponOwnedMask, 0)), 1)
end

local function getTutorialKills(data)
	return math.clamp(math.floor(num(data and data.TutorialKills)), 0, TUT_TARGET)
end

local function setStep(player, step)
	if not getData(player) then return end
	local previous = getStep(player)
	S.PlayerService.SetStat(player, "TutorialStep", step)
	dirty[player] = true -- step 0/1 guidance is published too, even before there is a kill quest
	-- defensive mirror in case TutorialStep is missing from Config.Data.Mirrored
	if player:GetAttribute("TutorialStep") ~= step then
		player:SetAttribute("TutorialStep", step)
	end
	if step == STEP_GUIDE then
		if S.ZoneService.GetZoneId(player) == TUT_ZONE then
			setStep(player, STEP_QUEST) -- already standing in the meadow
		end
	elseif step == STEP_QUEST and previous ~= STEP_QUEST then
		Net.Notify(player, string.format(TUT_START_TEXT, TUT_TEXT, Util.FormatNumber(TUT_GOLD)), "good")
	end
end

local function canWelcome(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players
		or not Util.IsAlive(player) then return false end
	local data = getData(player)
	local welcome = TUT_CFG.Welcome
	return data ~= nil and data.ClassChosen == true and Config.Classes[data.Class] ~= nil
		and getStep(player) == STEP_WELCOME and type(welcome) == "table"
		and type(welcome[getFaction(player)]) == "table"
end

local function openWelcome(player)
	if not canWelcome(player) then return end
	Net.Get("OpenPanel"):FireClient(player, "Welcome")
	welcomeShown[player] = true
end

local function onRequestTutorial(player, ...)
	if select("#", ...) ~= 0 or not canWelcome(player) then return end
	if not Util.RateLimit(player, "RequestTutorial", TUT_CFG.WelcomeRate or 0.5) then return end
	openWelcome(player)
end

-- A23-9: the client reports the first-time opening ended; only the server writes the saved flag
local function onIntroSeen(player, ...)
	if select("#", ...) ~= 0 or not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "IntroSeen", 1) then return end
	local data = getData(player)
	if not data or data.IntroSeen == true then return end
	S.PlayerService.SetStat(player, "IntroSeen", true)
end

local function onAcceptTutorial(player, ...)
	if select("#", ...) ~= 0 or not canWelcome(player) then return end
	if not Util.RateLimit(player, "AcceptTutorial", TUT_CFG.WelcomeRate or 0.5) then return end
	welcomeShown[player] = true
	S.PlayerService.SetStat(player, "TutorialKills", 0) -- a fresh acceptance never inherits stale kills
	setStep(player, STEP_GUIDE) -- acceptance in the meadow can enter step 2, without crediting any kill
end

-- Restore existing accepted progress. Step 0 only opens dialogue; closing it never accepts a mission.
local function tryTutorial(player)
	local data = getData(player)
	if not data then return end
	local step = getStep(player)
	if step == TUT_DONE then
		-- The existing watchdog observes purchases and level changes; publish deduplicates identical JSON.
		dirty[player] = true
		return
	end
	if step == STEP_GUIDE then
		if S.ZoneService.GetZoneId(player) == TUT_ZONE then
			setStep(player, STEP_QUEST)
		end
		return
	end
	if step == STEP_QUEST then
		-- F10-4 safety net: a finished first mission is never left unpaid (the [받기] row stays the normal way)
		if getTutorialKills(data) >= TUT_TARGET then
			TUT_READY_AT[player] = TUT_READY_AT[player] or os.clock()
			if os.clock() - TUT_READY_AT[player] >= num(TUT_CFG.AutoClaimSeconds, 60) then
				claimTutorial(player, true)
			end
		else
			TUT_READY_AT[player] = nil
		end
		return
	end
	if step ~= STEP_WELCOME or welcomeShown[player] then return end
	openWelcome(player)
end

local function tutorialKill(player, info)
	local data = getData(player)
	if not data then return end
	local cur = getTutorialKills(data)
	if cur >= TUT_TARGET or not TUTORIAL_KINDS[Config.QuestKind(info.Kind)] or info.Personal == true
		or info.ZoneId ~= TUT_ZONE then return end
	cur += 1
	S.PlayerService.SetStat(player, "TutorialKills", cur)
	dirty[player] = true
	if cur >= TUT_TARGET then
		Net.Notify(player, string.format(TUT_READY_TEXT), "good")
	end
end

-- auto = the F10-4 safety net paid it (Tutorial.AutoClaimSeconds after 5/5 without a claim)
function claimTutorial(player, auto)
	if getStep(player) ~= STEP_QUEST then return end
	if getTutorialKills(getData(player)) < TUT_TARGET then return end
	-- A23-34: M1_1 (show the jelly to the smith, get the first weapon) needs a smithy visit made after this claim, as
	-- the Claimed line says: an anvil visit before the first mission does not hand the weapon over in the meadow. A save
	-- that already owns tier 1 (from before A23-34) gets the old lines and keeps its visit.
	local hasFirst = hasFirstWeapon(getData(player))
	if not hasFirst then S.PlayerService.SetStat(player, "BlacksmithVisited", false) end
	setStep(player, TUT_DONE) -- first, so it can never be paid twice
	TUT_READY_AT[player] = nil
	S.ProgressionService.AddBankGold(player, TUT_GOLD, "Quest")
	if TUT_XP > 0 then
		S.ProgressionService.AddXP(player, TUT_XP)
	end
	local text = auto and (TUT_MESSAGES.AutoClaimed or TUT_CLAIMED_TEXT) or TUT_CLAIMED_TEXT
	if hasFirst then
		text = auto and (TUT_MESSAGES.AutoClaimedArmed or text) or (TUT_MESSAGES.ClaimedArmed or text)
	end
	Net.Notify(player, string.format(text, Util.FormatNumber(TUT_GOLD)), "reward", auto and 6 or nil)
end

-- A23-3: one fixed next-goal line after the blacksmith visit, from existing state only (no new reward).
local IRON_TIER = 3
local NEXT_ZONE = "GoblinWoods"
local hadNextGoal = {} -- [Player] = true while the pinned row shows a next goal (GuideDone toast on its end)
local function nextGoalText(data)
	local level = getLevel(data)
	local iron = Config.Weapons[IRON_TIER]
	local owned = math.floor(num(data.WeaponOwnedMask, 1))
	local hasIron = bit32.btest(owned, bit32.lshift(1, IRON_TIER - 1)) or num(data.WeaponTier, 1) >= IRON_TIER
	if iron and not hasIron then
		if level < iron.MinLevel then
			return string.format(TUT_MESSAGES.NextIronLevel, iron.MinLevel, level)
		end
		local gold = math.floor(math.max(0, num(data.CarriedGold)) + math.max(0, num(data.BankGold)))
		return string.format(TUT_MESSAGES.NextIronGold, Util.FormatNumber(iron.Price), Util.FormatNumber(gold))
	end
	local zone = Config.Zones[NEXT_ZONE]
	if zone and level < zone.MinLevel then
		return string.format(TUT_MESSAGES.NextZone, zone.MinLevel, tostring(zone.Name), level)
	end
	return nil
end

local function tutorialEntry(player, data)
	local step = getStep(player)
	local entry = {
		Id = TUT_ID, Kind = TUT_KIND, Pinned = true, TutorialStep = step,
		Progress = 0, Target = 1, RewardGold = 0, RewardXP = 0,
		CanClaim = false, ShowProgress = false,
	}
	if step == STEP_WELCOME then
		entry.Text = TUT_MESSAGES.Welcome or "첫 임무 · 여기를 눌러 안내자 만나기"
	elseif step == STEP_GUIDE then
		entry.Text = TUT_MESSAGES.Travel or "말랑 초원으로 가요 · 메뉴 > 이동 > 말랑 초원"
	elseif step == STEP_QUEST then
		entry.Progress, entry.Target = getTutorialKills(data), TUT_TARGET
		entry.Text = if entry.Progress >= TUT_TARGET then TUT_READY_TEXT else TUT_TEXT
		entry.RewardGold, entry.RewardXP = TUT_GOLD, TUT_XP
		entry.CanClaim, entry.ShowProgress = true, true
	elseif step == TUT_DONE and data.ClassChosen == true and getFaction(player) ~= "None" then
		if data.BlacksmithVisited ~= true then
			entry.Text = (hasFirstWeapon(data) and TUT_MESSAGES.VisitBlacksmithArmed or TUT_MESSAGES.VisitBlacksmith)
				or "무기 살펴보기 · 교차로 마을 대장간"
		else
			local text = nextGoalText(data)
			if not text then return nil end
			entry.Text = text
			entry.NextGoal = true
		end
	else
		return nil
	end
	return entry
end

------------------------------------------------------------------ publish
local function publish(player)
	dirty[player] = nil
	if player.Parent == nil then
		lastSent[player] = nil -- left: never fire to (or keep state for) a removed player
		hadNextGoal[player] = nil
		return
	end
	local data = getData(player)
	if not data then return end
	local list = {}
	local tutorial = tutorialEntry(player, data)
	-- after the first mission the story main row takes the pinned slot (the next-goal line stays the fallback)
	local story = S.StoryQuestService
	if getStep(player) == TUT_DONE and story and type(story.MainRow) == "function" then
		local okMain, main = pcall(story.MainRow, player, data)
		if okMain and main then tutorial = main end
	end
	if tutorial then table.insert(list, tutorial) end -- always first, never occupies/rerolls a daily slot
	if story and type(story.SubRows) == "function" then
		local okSubs, subs = pcall(story.SubRows, player, data)
		if okSubs and type(subs) == "table" then
			for _, row in subs do table.insert(list, row) end
		end
	end
	-- the guide chain just ran out (iron weapon owned and Lv10 reached): say so once, then the row disappears
	local hasGoal = tutorial ~= nil and (tutorial.NextGoal == true or tutorial.Story ~= nil)
	if hadNextGoal[player] and not hasGoal and getStep(player) == TUT_DONE then
		Net.Notify(player, TUT_MESSAGES.GuideDone or "안내는 여기까지! 이제 사냥하며 강해져요.", "good")
	end
	hadNextGoal[player] = hasGoal or nil
	if type(data.Quests) == "table" then
		-- CR-M6: dailies show what a claim pays now (stored reward capped to the current level; stored value kept)
		local capG, capX = Config.DailyQuestReward(getLevel(data))
		for i, q in ipairs(data.Quests) do
			if type(q) == "table" then
				local rg, rx = num(q.RewardGold), num(q.RewardXP)
				if q.Kind == "Daily" then
					rg, rx = capTo(math.floor(rg), math.floor(rx), capG, capX)
				end
				table.insert(list, {
					Id = tostring(q.Id),
					Kind = q.Kind,
					Text = tostring(q.Text),
					-- CR-M27: Kill/Golden progress is fractional; sent floored to 1 decimal (0.43 -> 0.4)
					Progress = math.floor(num(q.Progress) * 10 + PROGRESS_EPS) / 10,
					Target = num(q.Target),
					RewardGold = rg,
					RewardXP = rx,
					Unit = type(q.Unit) == "string" and q.Unit or nil, -- Kill/Golden: the monster (row icon)
					Slot = i, -- N1: clients address quests by Slot, never by array index
				})
			end
		end
	end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, list)
	if not ok then
		Util.Warn(TAG, "quest list encode failed: " .. tostring(json))
		return
	end
	-- CR-L50: owner-only remote instead of the QuestsJson attribute (which replicated to every client), fired only
	-- on change. Payload = the same JSON string the attribute held.
	if lastSent[player] == json then return end
	local okF, err = pcall(function()
		Net.Get("Quests"):FireClient(player, json)
	end)
	if okF then
		lastSent[player] = json
	else
		Util.Warn(TAG, "Quests fire failed: " .. tostring(err))
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

-- bonus chest for the full set of dailies (claimed by hand, or completed by the midnight auto-pay: CR-M21).
-- genLevel = level the set was generated at (default data.DailyLevel; the midnight auto-pay passes the OLD day's)
local function payChest(player, data, genLevel)
	if genLevel == nil then genLevel = data.DailyLevel end
	local cg, cx = chestReward(getLevel(data), genLevel)
	cg, cx = math.floor(num(cg)), math.floor(num(cx))
	payReward(player, cg, cx)
	Net.Notify(player, string.format(Config.Text.DailyChest, Util.FormatNumber(cg), Util.FormatNumber(cx)), "reward")
	if Util.Random:NextNumber() < Config.Daily.ChestTicketChance then
		local ok, err = pcall(S.MonetizationService.AddTickets, player, "Class", 1)
		if ok then
			Net.Notify(player, string.format(Config.Text.DailyChestTicket), "reward")
		else
			Util.Warn(TAG, "chest ticket failed: " .. tostring(err))
		end
	end
end

local function completeQuest(player, data, index, q)
	q.Progress = q.Target
	dirty[player] = true
	-- A23-3: before the first mission is accepted the dailies are folded on screen, so no "done" toasts either
	local quiet = getStep(player) == STEP_WELCOME
	if q.Kind == "Extra" then
		-- replace first so the finished quest can never be paid twice
		data.Quests[index] = newQuest(player, "Extra", othersExcept(data.Quests, index))
		payReward(player, math.floor(num(q.RewardGold)), math.floor(num(q.RewardXP)))
		if not quiet then
			Net.Notify(player, string.format(Config.Text.QuestDone, Util.FormatNumber(q.RewardGold)), "reward")
		end
	elseif not quiet then
		-- dailies stay in their slot until claimed
		Net.Notify(player, string.format(Config.Text.DailyReady), "good")
	end
end

-- Kill/Golden progress of one kill of monster `kind`, in units of the quest's monster (q.Unit, fixed at generation):
-- a weaker monster counts def.XP / unit.XP (never more than 1), so quests whose rewards were sized for the player's
-- level zone cannot be farmed on safe low-zone slimes (also not after a free class change or a rebirth).
-- Seasonal kinds count as Config.QuestKind(kind) (a pumpkin slime is a slime, a bat goblin a goblin).
local function killWeight(q, kind, level)
	kind = Config.QuestKind(kind)
	local unitId = q.Unit
	if type(unitId) ~= "string" or Config.MonsterTypes[unitId] == nil then
		unitId = Config.ZoneMainMonster[Config.QuestZoneForLevel(level)] -- quests saved before Unit existed
	end
	local unit = Config.MonsterTypes[unitId]
	local def = Config.MonsterTypes[kind]
	local strict = q.Strict == true -- A23-14 "왕 슬라임 3마리": a weaker monster counts 0, not a fraction
	if type(unit) ~= "table" or type(def) ~= "table" or num(unit.XP) <= 0 then
		return if strict and kind ~= unitId then 0 else 1
	end
	local w = math.clamp(num(def.XP) / unit.XP, 0, 1)
	if strict and w < 1 then return 0 end
	return w
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

	-- CR-M21: dailies of the old day that count as done = claimed ones + the ones auto-paid below
	local slots = Config.Quests.Slots
	local prevClaims = math.clamp(math.floor(num(data.DailyClaims)), 0, slots)
	local claims = math.min(slots, prevClaims + #toPay)
	-- the old day's dailies were generated at this level (0 = unknown save -> the current level's band)
	local oldGenLevel = math.floor(num(data.DailyLevel))
	local level = getLevel(data)

	-- commit: the day flips before anything is paid, so a failure can never double-pay
	S.PlayerService.SetStat(player, "DailyDay", today)
	S.PlayerService.SetStat(player, "DailyClaims", 0)
	data.DailyLevel = level -- the fresh set's band (caps its chest, see chestReward)

	-- CR-M21: vacation days = (1 - f) for the old day + every whole missed day (fractional, no floor), where
	-- f = share of a full day's daily value (3 dailies + chest) earned on the old day. A partly played day
	-- therefore never pays less than an absent one. A23-14 review: f uses the minutes of the old day's band (Lv1-9 =
	-- Newbie 2 x 3 + 4, else Daily 5 x 3 + 10) and Config.VacationReward the current level's band, so a missed
	-- Lv1-9 day (252 gold / 420 XP) pays less than a played one (360 / 600).
	if dailyDay > 0 and today > dailyDay then
		local D = Config.Daily
		local band = oldGenLevel >= 1 and oldGenLevel or level
		local newbieDay = isNewbieLevel(band)
		local perQuest = newbieDay and num(NEWBIE.RewardMinutes, D.QuestMinutes) or D.QuestMinutes
		local chestMin = newbieDay and num(NEWBIE.ChestMinutes, D.ChestMinutes) or D.ChestMinutes
		local fullDay = perQuest * slots + chestMin
		local earned = claims * perQuest + ((claims >= slots) and chestMin or 0)
		local f = if fullDay > 0 then math.clamp(earned / fullDay, 0, 1) else 1
		local add = (1 - f) + math.max(0, today - dailyDay - 1)
		if add > 0 then
			local days = math.min(D.VacationMaxDays, math.max(0, num(data.VacationDays)) + add)
			days = math.floor(days * 1000 + 0.5) / 1000 -- keep the mirrored attribute tidy
			local g, x = Config.VacationReward(getLevel(data), days)
			S.PlayerService.SetStat(player, "VacationDays", days)
			S.PlayerService.SetStat(player, "VacationGold", g)
			S.PlayerService.SetStat(player, "VacationXP", x)
		end
	end

	data.Quests = fresh
	dirty[player] = true

	local capG, capX = Config.DailyQuestReward(getLevel(data)) -- CR-M6
	local paidGold = 0
	for _, q in toPay do
		local g, x = capTo(math.floor(num(q.RewardGold)), math.floor(num(q.RewardXP)), capG, capX)
		paidGold += g
		payReward(player, g, x)
	end
	if paidGold > 0 then
		Net.Notify(player, string.format(Config.Text.DailyAutoPaid, Util.FormatNumber(paidGold)), "reward")
	end
	-- CR-M21: an auto-pay that completes the set also pays the bonus chest (capped to the OLD day's band)
	if prevClaims < slots and claims >= slots then
		payChest(player, data, oldGenLevel)
	end
end

------------------------------------------------------------------ remotes
local function onClaimQuest(player, slot)
	if not S.PlayerService.IsReady(player) then return end
	if type(slot) == "string" and string.sub(slot, 1, 6) == "story:" then -- story rows claim by id
		if not Util.RateLimit(player, "ClaimQuest", Config.RateLimits.ClaimQuest) then return end
		local story = S.StoryQuestService
		if story and type(story.Claim) == "function" then pcall(story.Claim, player, string.sub(slot, 7)) end
		return
	end
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
	g, x = capTo(g, x, Config.DailyQuestReward(getLevel(data))) -- CR-M6
	payReward(player, g, x)
	Net.Notify(player, string.format(Config.Text.DailyClaimed, Util.FormatNumber(g), Util.FormatNumber(x)), "reward")

	local claims = num(S.PlayerService.AddStat(player, "DailyClaims", 1))
	if claims == Config.Quests.Slots then
		payChest(player, data)
		-- P8: say once that the day's homework is done (DailyClaims resets with the KST day, so this is once a day)
		task.delay(2, function()
			if player.Parent then pcall(Net.Notify, player, Config.Text.DailyAllDone, "good", 6) end
		end)
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
	g, x = capTo(g, x, Config.VacationReward(getLevel(data), num(data.VacationDays))) -- CR-M6
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
	-- Never reset the saved TutorialKills here: a reconnect can have an unclaimed completed quest.

	ensureSlots(player, data)
	runDayCheck(player)
	tryTutorial(player) -- pending dialogue opens once when choices and a living character are ready
	publish(player)
end

local function onPlayerLeaving(player)
	dirty[player] = nil
	lastSent[player] = nil
	rerollReadyAt[player] = nil
	welcomeShown[player] = nil
	TUT_READY_AT[player] = nil
	hadNextGoal[player] = nil
end

local function onCharacterSpawned(player)
	-- CR-L50 safety net: resend the quest list once per spawn (the client keeps the last payload; same content)
	lastSent[player] = nil
	dirty[player] = true
	task.delay(RESUME_DELAY_ON_SPAWN, function()
		local ok, err = pcall(tryTutorial, player)
		if not ok then Util.Warn(TAG, "tutorial on spawn: " .. tostring(err)) end
	end)
end

local function onClassChanged(player)
	task.delay(RESUME_DELAY_ON_CLASS, function()
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
	local step = getStep(player)
	local level = getLevel(data)
	local function weight(q)
		return killWeight(q, info.Kind, level)
	end
	addProgress(player, "Kill", weight)
	if info.Golden == true then
		addProgress(player, "Golden", weight)
	end
	if step == STEP_QUEST then
		tutorialKill(player, info)
	elseif step == STEP_GUIDE and info.Personal ~= true and info.ZoneId == TUT_ZONE
		and TUTORIAL_KINDS[Config.QuestKind(info.Kind)] then
		-- The kill signal may precede ZoneChanged by one tick.
		setStep(player, STEP_QUEST)
		tutorialKill(player, info)
	end
end

local function onGoldEarned(player, amount, source)
	if source ~= "Monster" then return end
	addProgress(player, "Gold", math.floor(num(amount)))
end

-- Only a server-confirmed manual skill that hit at least one monster counts (A23-1; no whiffs in town).
local function onReleased(player, info)
	if type(info) ~= "table" then return end
	if info.Auto == true then return end
	if num(info.MonstersHit) < 1 then return end
	addProgress(player, "Release", 1)
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
			local nq = newQuest(player, q.Kind, othersExcept(quests, i))
			if q.Kind == "Daily" then
				-- CR-L12: a remade daily keeps the reward it had (a rebirth must not shrink it to Lv1 here;
				-- claiming caps it to the current level anyway: CR-M6)
				nq.RewardGold = math.max(nq.RewardGold, math.floor(num(q.RewardGold)))
				nq.RewardXP = math.max(nq.RewardXP, math.floor(num(q.RewardXP)))
			end
			quests[i] = nq
			dirty[player] = true
		end
	end
end

-- dailies keep their stored rewards (capped to the current level when claimed: CR-M6); extras are regenerated
-- for the new (level 1) life. Also runs on ProgressionService.LevelReset (free class change, CR-M6).
local function onRebirthed(player)
	local data = getData(player)
	if not data then return end
	-- CR-M6: re-cap the mirrored vacation reward to the new level, so the vacation panel shows what a claim pays
	local vg = math.floor(math.max(0, num(data.VacationGold)))
	local vx = math.floor(math.max(0, num(data.VacationXP)))
	local cg, cx = capTo(vg, vx, Config.VacationReward(getLevel(data), num(data.VacationDays)))
	if cg ~= num(data.VacationGold) then
		S.PlayerService.SetStat(player, "VacationGold", cg)
	end
	if cx ~= num(data.VacationXP) then
		S.PlayerService.SetStat(player, "VacationXP", cx)
	end
	if type(data.Quests) ~= "table" then return end
	local quests = data.Quests
	for i = 1, Config.Quests.Slots do
		local q = quests[i]
		if not isValidQuest(q) or q.Kind == "Extra" then
			quests[i] = newQuest(player, "Extra", othersExcept(quests, i))
		end
	end
	dirty[player] = true
end

-- CR-M6: the daily cap rises with the level -> republish so the shown (capped) daily rewards follow it
local function onLeveledUp(player)
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
	connectSignal("ProgressionService", "LevelReset", onRebirthed) -- CR-M6
	connectSignal("ProgressionService", "LeveledUp", onLeveledUp) -- CR-M6
	connectSignal("CombatService", "Released", onReleased)
	connectSignal("GooseService", "GooseFinished", onGooseFinished)
	connectSignal("PvPService", "PlayerKO", onPlayerKO)
	connectSignal("KaijuService", "KaijuEnded", onKaijuEnded)
	connectSignal("FactionService", "FactionChanged", onFactionChanged)
	connectSignal("ClassService", "ClassChanged", onClassChanged)
	connectSignal("ZoneService", "ZoneChanged", onZoneChanged)
end

-- StoryQuestService asks for a fresh quest list after story progress
function M.MarkDirty(player)
	if typeof(player) == "Instance" and player:IsA("Player") then dirty[player] = true end
end

function M.Start()
	Net.Get("RequestTutorial").OnServerEvent:Connect(onRequestTutorial)
	Net.Get("AcceptTutorial").OnServerEvent:Connect(onAcceptTutorial)
	Net.Get("IntroSeen").OnServerEvent:Connect(onIntroSeen)
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

	-- Step 0 only opens the welcome once; entering the meadow advances accepted step 1, never bypasses acceptance.
	task.spawn(function()
		while true do
			task.wait(TUTORIAL_TICK)
			for _, p in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(tryTutorial, p)
				if not ok then loopWarn("tutorial loop", err) end
				-- the next-goal line reads level/gold; publish() only fires when the JSON really changed
				if getStep(p) == TUT_DONE then dirty[p] = true end
			end
		end
	end)

	print("[QuestService] started")
end

return M
