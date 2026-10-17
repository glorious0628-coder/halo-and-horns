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
M.ForgeReached = Util.Signal.new() -- A23-88 (player, seconds since [I'm In!]): the walker first stood at Otto's anvil (metrics: ForgeWalk)

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
local STEP_FORGE = TUT_CFG.Steps.Forge -- 3 (A23-74): to the Crossroads Forge for the first weapon, before the hunt
local TUT_DONE = TUT_CFG.Steps.Done -- 99
-- A23-74: the Forge step's settings (Config.Tutorial.Forge) and its session state (Late[Player] = the late gift for an
-- old save was tried this session)
local FORGE = { Cfg = TUT_CFG.Forge or {}, Zone = "Crossroads", Late = {}, AcceptedAt = {}, Reached = {}, WasNear = {} }
-- quest bible v3 H00 / R00 / N00 (P1 ②, docs/design/quest_p1_server_contract_2026-10-15.md): the first mission is talked through
-- the faction guide's body (Config.Tutorial.Guides) and, for Halo / Horns, the teacher's (Config.Skills.Learn.Teachers) at the
-- step Teacher (4) before the Forge. No body in this world = the old way (the row tap / no teacher step)
local TEACH = { Step = TUT_CFG.Steps.Teacher, Practice = TUT_CFG.Steps.Practice }
local TUT_TARGET = TUT_CFG.QuestKills
local TUT_GOLD = TUT_CFG.QuestRewardGold
local TUT_XP = TUT_CFG.QuestRewardXP or 0
local TUT_TEXT = Config.Plural(string.format(TUT_CFG.QuestText, TUT_TARGET))
local TUT_ZONE = TUT_CFG.GuideZone
local TUT_MESSAGES = TUT_CFG.Text or {}
local TUT_SHORT = TUT_CFG.ShortNames or {} -- 검수 2026-10-07: each row's ShortName (the phone HUD quest row, <= 14)
-- A23-130 (user 2026-10-11 "삭제해 달랬는데 아직 있네"): no start / ready lines; the claim says only the reward
local TUT_CLAIMED_TEXT = TUT_MESSAGES.Claimed or "+%s gold"
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
-- E12 (quest_volume §3-4): the Goblin Woods band Lv10-24 works the same way (Lv25+ keeps the template dailies)
local WOODS = Config.Quests.Woods

------------------------------------------------------------------ state (session only)
local dirty = {} -- [Player] = true -> quest list republished by the publish loop
local lastSent = {} -- [Player] = last JSON fired on the "Quests" remote (CR-L50: fire only on change)
local rerollReadyAt = {} -- [Player] = server time
local lastLoopWarn = {} -- [loopName] = os.clock()
local welcomeShown = {} -- [Player] = true after this session's first automatic guide dialogue
-- F10-4: [Player] = os.clock() when this server first saw the first mission at 5/5 unclaimed (safety-net timer)
local TUT_READY_AT = {}
local claimTutorial -- defined with the claim code below; the tutorial loop (safety net) calls it
local finishFirst -- A23-188: the first mission done (the Forge visit); defined with the claim code below

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

-- 최종 검수 10/13 (A23-14 kept with EarlyMult 0.35): vacation XP alone never reaches Lv(Levels.EarlyUntil): below it a claim
-- stops one XP short of that level. nil = no cap (Lv EarlyUntil and up)
local function vacationXPRoom(data)
	local untilLv = math.floor(num(Config.Levels.EarlyUntil, 10))
	local level = getLevel(data)
	if level >= untilLv then return nil end
	local room = -math.max(0, num(data.XP)) - 1
	for l = level, untilLv - 1 do room += Config.XPToNext(l) end
	return math.max(0, math.floor(room))
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

-- E12: the daily band of a level: Newbie (Lv1..Newbie.MaxLevel), Woods (Woods.MinLevel..MaxLevel) or nil (templates)
local function bandAt(level)
	if isNewbieLevel(level) then return NEWBIE end
	if type(WOODS) == "table" and type(WOODS.Dailies) == "table" and #WOODS.Dailies > 0
		and level >= num(WOODS.MinLevel, math.huge) and level <= num(WOODS.MaxLevel, 0) then
		return WOODS
	end
	return nil
end

-- full-set chest at one level; Lv1-9 pays Newbie.ChestMinutes of hunting instead of Daily's (Lv10-24: Woods')
local function chestAt(level)
	if isNewbieLevel(level) then
		return Config.HuntValue(level, num(NEWBIE.ChestMinutes, Config.Daily.ChestMinutes))
	end
	local band = bandAt(level)
	if band then return Config.HuntValue(level, num(band.ChestMinutes, Config.Daily.ChestMinutes)) end
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

-- A23-113 #8: the daily 'Choice' (one good or naughty deed) exists only while something can offer a choice: the job board, the lost
-- things, or a kill card that is not switched off. Nothing on: the slot is another kind (and a saved Choice daily is remade).
local function choiceOn()
	if type(Config.Board) == "table" and Config.Board.Enabled == true then return true end
	if type(Config.LostFound) == "table" and Config.LostFound.Enabled == true then return true end
	for _, card in type(Config.KillCards) == "table" and Config.KillCards or {} do
		if type(card) == "table" and card.Enabled ~= false then return true end
	end
	return false
end

-- a template the player can do now: its faction rule, A23-113 the Choice row only while a choice source is on, and A23-71 the
-- skill row ("Release") only once a skill is learned
local function templateFitsNow(t, faction, data)
	if not templateFitsFaction(t, faction) then return false end
	if t.Id == "Choice" and not choiceOn() then return false end
	-- artisan min ④: the guild's dailies only while their feature is on
	if t.Id == "Gather" and not Config.FeatureOn("Gathering") then return false end
	if t.Id == "Craft" and not Config.FeatureOn("Crafting") then return false end
	return t.Id ~= "Release" or (data ~= nil and Config.SkillLearned(data.SkillSlots, data.Level, data.Rebirths))
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
-- E11: with the job boards on (Config.Board.Enabled) a slot that would get an extra quest stays empty ({ Kind = "Empty" }:
-- not listed, never rerolled, refilled by the next day's dailies); the boards take that role. Off: extras as before.
local function boardOn()
	return type(Config.Board) == "table" and Config.Board.Enabled == true
end

-- A23-104 (user 2026-10-10: "daily quests should be told as a quest, not just thrown at the player"): the daily jobs open when
-- the player has heard about them (the intro sub Config.Daily.IntroQuest after the first chapter; StoryQuestService.QuestDone ->
-- M.OpenDailies). Until then no daily quest is made, shown or counted and the Quests payload says DailyLocked. A save that
-- already ran its dailies (DailyDay > 0) is open. Config.Daily.IntroGate = false: always open (the old rule).
local function dailiesOpen(data)
	if type(data) ~= "table" then return false end
	local D = Config.Daily
	if type(D) ~= "table" or D.IntroGate ~= true then return true end
	return data.DailyIntro == true or num(data.DailyDay) > 0
end

local function isEmptySlot(q)
	return type(q) == "table" and q.Kind == "Empty"
end

-- the row text of template `t` for `target` (Kill / Golden: the monster `unitId`), always from today's Config. 검수
-- 2026-10-08 (게임성 개발 3): a saved Text is never trusted - saves from before A23-48 still held Korean daily text
local function questText(t, target, unitId)
	local text
	if t.Id == "Gold" then
		text = string.format(t.Text, tostring(target)) -- CR-L31: exact number (FormatNumber rounds to "3.2K")
	elseif t.Id == "Kill" or t.Id == "Golden" then
		local unitDef = Config.MonsterTypes[unitId] or {}
		text = string.format(t.Text, tostring(unitDef.Short or unitDef.Name or unitId), target) -- CR-M27: (monster, target)
	else
		text = string.format(t.Text, target)
	end
	return Config.Plural(text) -- "Join the Golden Goose tug 1 time"
end

-- others = quests in the OTHER slots (used for the PvP limit and the "different template" preference)
local function newQuest(player, kind, others)
	local data = S.PlayerService.GetData(player)
	local level = getLevel(data)
	local faction = getFaction(player)
	-- A23-14: Lv1-9 dailies come from Config.Quests.Newbie.Dailies (rows reuse a template Id); E12: Lv10-24 from
	-- Config.Quests.Woods.Dailies the same way (band = the rows' table); everything else as before
	local newbie = kind == "Daily" and isNewbieLevel(level)
	local band = (kind == "Daily" and bandAt(level)) or nil
	local mainId = Config.ZoneMainMonster[Config.QuestZoneForLevel(level)]
	-- the monster a row's quest counts (its Unit): the zone's unit monster, or a band row's Monster (e.g. BigSlime)
	local function unitOf(row)
		if band and type(row.Monster) == "string" and type(Config.MonsterTypes[row.Monster]) == "table" then return row.Monster end
		return mainId
	end

	local otherIds, otherKeys, otherPvP = {}, {}, 0
	local otherCount, otherNonHunt = 0, false -- A23-113 #8
	for _, q in others or {} do
		if type(q) == "table" and type(q.Id) == "string" then
			otherIds[q.Id] = true
			otherKeys[q.Id .. "|" .. tostring(q.Unit)] = true
			local ot = TEMPLATE_BY_ID[q.Id]
			if ot and ot.PvP then otherPvP += 1 end
			otherCount += 1
			if ot and ot.NonHunt == true then otherNonHunt = true end
		end
	end

	-- 검수 2026-10-10: the Golden Goose daily is never made two days running (the goose is a 60 s event; a daily waiting for it
	-- must not become homework)
	local today = Config.DayIndex(os.time())
	local gooseResting = kind == "Daily" and num(data.GooseDay) > 0
		and today - num(data.GooseDay) <= num(Config.Quests.GooseRestDays, 1) and num(data.GooseDay) ~= today
	-- gameplay plan 2026-10-13 1-A #3: a goose daily only while the next egg hunt is near (Config.Quests.GooseWindow) or on
	if kind == "Daily" and not gooseResting then
		local window = num(Config.Quests.GooseWindow, 0)
		if window > 0 then
			local okG, gs = pcall(Net.GameState)
			local active = okG and gs and gs:GetAttribute("GooseActive") == true
			local nextAt = okG and gs and num(gs:GetAttribute("GooseNextAt")) or 0
			if not active and not (nextAt > 0 and nextAt - Util.Now() <= window) then gooseResting = true end
		end
	end

	local pvpAllowed = level >= Config.Quests.PvPMinLevel
		and otherPvP < (Config.Quests.MaxPvPQuests or 1)
		and not S.PvPService.IsRookie(player)

	-- rows = templates, or A23-14 / E12 band rows ({ Id = template Id, Targets, Monster?, Strict? }). A new goal first
	-- (another template), else (A23-71 S9 / D3) at least another monster: Lv1-4 has no skill row, so its set is always
	-- King Slime 3 + Slime 12-15 + Gold, never the King Slime row twice; else anything that fits
	local candidates, preferred, otherUnit = {}, {}, {}
	for _, row in (if band then band.Dailies else Config.Quests.Templates) do
		local rt = type(row) == "table" and TEMPLATE_BY_ID[row.Id]
		if rt and templateFitsNow(rt, faction, data) and (not rt.PvP or pvpAllowed) and not (gooseResting and rt.Id == "Goose") then
			table.insert(candidates, row)
			if not otherIds[row.Id] then
				table.insert(preferred, row)
			elseif not otherKeys[row.Id .. "|" .. tostring(unitOf(row))] then
				table.insert(otherUnit, row)
			end
		end
	end
	local pool = (#preferred > 0 and preferred) or (#otherUnit > 0 and otherUnit) or candidates
	-- A23-113 #8: from Lv10 the three dailies are not all hunting: the last slot, when the other two both hunt, is drawn from the
	-- non-hunting kinds that fit this player now; none fits: unchanged (the other two hold no non-hunting kind, so every one
	-- that fits is a new goal: `preferred` has them all)
	if kind == "Daily" and not newbie and level >= num(Config.Quests.NonHuntFrom, 10)
		and otherCount >= math.max(1, num(Config.Quests.Slots, 3) - 1) and not otherNonHunt then
		local function nonHunt(list)
			local out = {}
			for _, r in list do
				local rt = TEMPLATE_BY_ID[r.Id]
				-- gameplay plan 1-A #3 (A23-113): PvP is never the forced non-hunting slot
				if rt and rt.NonHunt == true and not rt.PvP then table.insert(out, r) end
			end
			return out
		end
		local nh = nonHunt(preferred)
		if #nh > 0 then pool = nh end
	end
	local row
	if #pool > 0 then
		row = pickWeighted(pool)
	else
		newbie, band = false, nil -- nothing fits: the old Kill daily (sizes and reward) is the safe fallback
		row = TEMPLATE_BY_ID.Kill or Config.Quests.Templates[1]
	end
	local t = TEMPLATE_BY_ID[row.Id] or row
	if kind == "Daily" and t.Id == "Goose" then data.GooseDay = today end

	local unitsList
	if band then
		unitsList = row.Targets
	else
		unitsList = (kind == "Daily" and t.DailyUnits) or t.Units
	end
	if type(unitsList) ~= "table" or #unitsList == 0 then unitsList = { 1 } end
	local units = num(unitsList[Util.Random:NextInteger(1, #unitsList)], 1)

	local main = Config.MonsterTypes[mainId]
	-- the monster a Kill/Golden quest counts: the zone's unit monster, or the newbie row's Monster (e.g. BigSlime)
	local unitId = unitOf(row)
	local target = units -- band Targets are exact (a Gold row already says gold)
	if t.Id == "Gold" and not band then
		target = units * main.Gold
	end
	target = math.max(1, math.floor(target))

	local rewardGold, rewardXP
	if kind == "Daily" then
		if newbie then
			rewardGold, rewardXP = Config.HuntValue(level, num(NEWBIE.RewardMinutes, Config.Daily.QuestMinutes))
		elseif band then
			rewardGold, rewardXP = Config.HuntValue(level, num(band.RewardMinutes, Config.Daily.QuestMinutes)) -- E12
		else
			rewardGold, rewardXP = Config.DailyQuestReward(level)
		end
	else
		local per = num(t.RewardPerUnit, 1)
		local mult = Config.Quests.ExtraRewardMult
		rewardGold = math.floor(units * main.Gold * per * mult)
		rewardXP = math.floor(units * main.XP * per * mult)
	end

	local text = questText(t, target, unitId)

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
		Strict = (band and row.Strict == true) or nil, -- A23-14 / E12: only Unit (or stronger) kills count, 1 each
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
			if q.Id == "Release" then q.MinStacks = nil end
			-- the text again from the template (a save from before A23-48 still said Korean; before 2026-10-07 "1 times")
			local unit = (type(q.Unit) == "string" and Config.MonsterTypes[q.Unit] ~= nil) and q.Unit
				or Config.ZoneMainMonster[Config.QuestZoneForLevel(getLevel(data))]
			q.Text = questText(TEMPLATE_BY_ID[q.Id], q.Target, unit)
			fixed[i] = q
		end
	end
	for i = 1, slots do
		if not fixed[i] then
			local others = {}
			for j = 1, slots do
				if j ~= i and fixed[j] then table.insert(others, fixed[j]) end
			end
			fixed[i] = boardOn() and { Kind = "Empty" } or newQuest(player, "Extra", others) -- E11
		end
	end
	data.Quests = fixed
end

-- unfinished quests the player cannot do now (another side's, or A23-71 a skill row before the first skill) are remade
local function remakeUnfit(player, data, faction)
	if type(data.Quests) ~= "table" then return end
	local quests = data.Quests
	for i = 1, #quests do
		local q = quests[i]
		if isValidQuest(q) and not isComplete(q) and not templateFitsNow(TEMPLATE_BY_ID[q.Id], faction, data) then
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

-- A23-74 (검수 2026-10-07: one rule for [Accept] and the late gift): bare-handed and without the first weapon. A player
-- holding a weapon already (a save from before A23-34, a bought or found one) hunts at once; M1_1 still hands the first
-- weapon over later (into the bag)
local function needsFirstWeapon(data)
	return type(data) == "table" and not hasFirstWeapon(data) and math.floor(num(data.WeaponTier, 0)) <= 0
end

local function getTutorialKills(data)
	return math.clamp(math.floor(num(data and data.TutorialKills)), 0, TUT_TARGET)
end

-- A23-208 (최종 검수 10/15): the first mission's story (Config.Tutorial.Story): the left step's Scene, then the new step's
-- Find, as Fx StoryScene { Id = "Tutorial", Key, Value, St = the step's name } (the client reads the words from Config)
function TEACH.Story(player, old, new)
	local story = TUT_CFG.Story
	if type(story) ~= "table" or type(story.Steps) ~= "table" or old == new then return end
	local f = getFaction(player)
	local function nameOf(n)
		for k, v in TUT_CFG.Steps do
			if v == n then return k end
		end
		return nil
	end
	local function fire(key, value, st)
		local ok, err = pcall(Net.Fx, player, "StoryScene", { Id = "Tutorial", Key = key, Value = value, St = st })
		if not ok then Util.Warn(TAG, "tutorial scene: " .. tostring(err)) end
	end
	local oldName, newName = nameOf(old), nameOf(new)
	local left = oldName and story.Steps[oldName]
	local scene = type(left) == "table" and type(left.Scene) == "table" and left.Scene[f] or nil
	if type(scene) == "string" then fire("Scene", scene, oldName) end
	local came = newName and story.Steps[newName]
	local find = type(came) == "table" and type(came.Find) == "table" and came.Find[f] or nil
	if type(find) == "string" then fire("Find", newName, newName) end
end

local function setStep(player, step)
	if not getData(player) then return end
	local old = getStep(player)
	S.PlayerService.SetStat(player, "TutorialStep", step)
	pcall(TEACH.Story, player, old, step)
	dirty[player] = true -- step 0/1 guidance is published too, even before there is a kill quest
	-- defensive mirror in case TutorialStep is missing from Config.Data.Mirrored
	if player:GetAttribute("TutorialStep") ~= step then
		player:SetAttribute("TutorialStep", step)
	end
	if step == STEP_GUIDE then
		if S.ZoneService.GetZoneId(player) == TUT_ZONE then
			setStep(player, STEP_QUEST) -- already standing in the meadow
		end
	end -- A23-130: the hunt starts without a line (the pinned row shows it)
end

-- P1 ②: where npcId's body stands (the StoryNpc-tagged model with that NpcId), or nil when this world has none
function TEACH.Body(npcId)
	if type(npcId) ~= "string" then return nil end
	local okT, tagged = pcall(function()
		return game:GetService("CollectionService"):GetTagged((Config.StoryQuests and Config.StoryQuests.NpcTag) or "StoryNpc")
	end)
	if not okT or type(tagged) ~= "table" then return nil end
	for _, inst in tagged do
		if inst:GetAttribute("NpcId") == npcId then
			local okP, pos = pcall(function()
				if inst:IsA("Model") then return inst:GetPivot().Position end
				return inst.Position
			end)
			if okP and typeof(pos) == "Vector3" then return pos end
		end
	end
	return nil
end

-- the player stands within the story NPC range of npcId's body
function TEACH.Near(player, npcId)
	local pos, root = TEACH.Body(npcId), Util.GetRoot(player)
	return pos ~= nil and root ~= nil and Util.FlatDistance(root.Position, pos) <= num((Config.StoryQuests or {}).NpcRange, 16)
end

-- this player's guide NpcId while it has a body (nil = no body: the row tap opens the guide's lines as before)
function TEACH.Guide(player)
	local g = TUT_CFG.Guides
	local id = type(g) == "table" and g[getFaction(player)] or nil
	return type(id) == "string" and TEACH.Body(id) ~= nil and id or nil
end

-- this player's teacher NpcId for the Teacher step (Halo / Horns with a body; the artisans meet Otto at the Forge itself)
function TEACH.Teacher(player)
	local f = getFaction(player)
	if (f ~= "Halo" and f ~= "Horns") or TEACH.Step == nil then return nil end
	local L = Config.Skills and Config.Skills.Learn
	local id = type(L) == "table" and type(L.Teachers) == "table" and L.Teachers[f] or nil
	return type(id) == "string" and TEACH.Body(id) ~= nil and id or nil
end

-- the name a row says for an NpcId (the guide's Welcome name, the teacher's Config.SkillTeacherName)
function TEACH.Name(player, npcId)
	local w = TUT_CFG.Welcome and TUT_CFG.Welcome[getFaction(player)]
	if type(w) == "table" and npcId == (TUT_CFG.Guides or {})[getFaction(player)] and type(w.Name) == "string" then return w.Name end
	local ok, name = pcall(Config.SkillTeacherName, getFaction(player))
	return ok and type(name) == "string" and name or npcId
end

-- after the teacher (or when there is none): the Forge while bare-handed with an anvil in the world, else the mission is done
function TEACH.After(player)
	if STEP_FORGE and needsFirstWeapon(getData(player)) then
		if FORGE.Anvil() then
			setStep(player, STEP_FORGE)
			return
		end
		FORGE.Give(player, "first weapon (no anvil)")
	end
	finishFirst(player)
end

-- A23-221 ①: the side's practice dummy (Config.Tutorial.Practice[faction] = a Landmarks key; a StoryLandmark-tagged spot
-- first, like every landmark), nil = no practice step for this side
function TEACH.PracticeSpot(player)
	local P = TUT_CFG.Practice
	local key = type(P) == "table" and P[getFaction(player)] or nil
	if type(key) ~= "string" or TEACH.Practice == nil then return nil end
	local SQ = Config.StoryQuests or {}
	local spot = type(Util.TaggedSpot) == "function" and Util.TaggedSpot(SQ.LandmarkTag or "StoryLandmark", key) or nil
	if spot == nil and type(SQ.Landmarks) == "table" then spot = SQ.Landmarks[key] end
	return typeof(spot) == "Vector3" and spot or nil, key
end

-- A23-221 ①: the teacher met: one hit at the dummy (step Practice) when this side has one, else on to the Forge
function TEACH.ToPractice(player)
	if TEACH.PracticeSpot(player) then
		setStep(player, TEACH.Practice)
		local sq = S.StoryQuestService
		if type(sq) == "table" and type(sq.Refresh) == "function" then pcall(sq.Refresh, player) end -- the stick in hand now
		return
	end
	TEACH.After(player)
end

-- A23-221 ①: a manual basic swing (CombatService.BasicSwing) within Practice.Radius of the dummy at the Practice step, in
-- any direction: the teacher takes the stick back (the step's Scene) and the Forge is next
function TEACH.OnSwing(player, pos)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or getStep(player) ~= TEACH.Practice or typeof(pos) ~= "Vector3" then
		return
	end
	local spot = TEACH.PracticeSpot(player)
	if not spot or Util.FlatDistance(pos, spot) > num(TUT_CFG.Practice.Radius, 10) then return end
	TEACH.After(player)
	local sq = S.StoryQuestService
	if type(sq) == "table" and type(sq.Refresh) == "function" then pcall(sq.Refresh, player) end -- the stick goes back
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
	if select("#", ...) ~= 0 then return end
	if not canWelcome(player) then return end
	if TEACH.Guide(player) then return end -- P1 ②: the guide has a body: talking to it opens the lines (the row only guides)
	if not Util.RateLimit(player, "RequestTutorial", TUT_CFG.WelcomeRate or 0.5) then return end
	openWelcome(player)
end

-- A23-9: the client reports the first-time opening ended; only the server writes the saved flag
local function onIntroSeen(player, ...)
	if select("#", ...) ~= 0 or not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "IntroSeen", num(Config.RateLimits.IntroSeen, 1)) then return end
	local data = getData(player)
	if not data or data.IntroSeen == true then return end
	S.PlayerService.SetStat(player, "IntroSeen", true)
end

-- A23-88 (user 2026-10-09): nothing moves the player by itself any more. [I'm In!] starts "Go to Otto's Forge" (walking,
-- the step ends when the blacksmith hands over the first weapon), and after the weapon "Travel to the Squishy Meadow" teaches
-- the travel pad / the map (the step ends when the player stands in the meadow, however they got there).

-- A23-74: the Crossroads anvil (ShopService.Anvil; nil while the weapon shop is closed)
function FORGE.Anvil()
	local shop = S.ShopService
	if type(shop) ~= "table" or type(shop.Anvil) ~= "function" then return nil end
	local ok, anvil = pcall(shop.Anvil)
	if ok and typeof(anvil) == "Instance" and anvil:IsA("BasePart") then return anvil end
	return nil
end

-- the player stands within Forge.Near studs of the anvil (no trip needed)
function FORGE.Near(player)
	local anvil = FORGE.Anvil()
	if anvil == nil then return false end -- (no anvil: no body asked for; the Forge row's 'Talk to Otto' check runs every publish)
	local root = Util.GetRoot(player)
	return root ~= nil and Util.FlatDistance(root.Position, anvil.Position) <= num(FORGE.Cfg.Near, 24)
end

-- the blacksmith's gift without the Forge visit (no anvil in the world, or an old save past the Forge step):
-- LootService.GrantFirstWeapon pays once (owning tier 1 is the record); `why` names the warning when it fails
function FORGE.Give(player, why)
	local loot = S.LootService
	if not loot or type(loot.GrantFirstWeapon) ~= "function" then return end
	local ok, err = pcall(loot.GrantFirstWeapon, player, 1)
	if not ok then Util.Warn(TAG, why .. ": " .. tostring(err)) end
end

local function onAcceptTutorial(player, ...)
	if select("#", ...) ~= 0 or not canWelcome(player) then return end
	if not Util.RateLimit(player, "AcceptTutorial", TUT_CFG.WelcomeRate or 0.5) then return end
	local guide = TEACH.Guide(player)
	-- P1 ②: accepted next to the guide's body - or anywhere once the server itself opened this session's Welcome there
	-- (A23-180, 최종 검수 10/16 first-10 audit: a child who walked off with the window open pressed [I'm In!] and nothing
	-- happened). An [I'm In!] with no Welcome ever opened is still refused
	if guide and not TEACH.Near(player, guide) and not welcomeShown[player] then return end
	welcomeShown[player] = true
	S.PlayerService.SetStat(player, "TutorialKills", 0) -- a fresh acceptance never inherits stale kills
	-- A23-74 weapon first: a bare-handed player without the first weapon walks to the Forge (A23-88: no automatic move);
	-- one holding a weapon already goes on to the travel step. 검수 2026-10-07: with no anvil in the world (the weapon shop
	-- closed) the gift comes at once and the mission goes on, never stuck at the Forge step
	FORGE.AcceptedAt[player] = os.clock()
	-- P1 ②: Halo / Horns meet their teacher first (step Teacher; the Forge follows), when the teacher has a body here
	if TEACH.Teacher(player) then
		setStep(player, TEACH.Step)
		return
	end
	if STEP_FORGE and needsFirstWeapon(getData(player)) then
		if FORGE.Anvil() then
			setStep(player, STEP_FORGE)
			return
		end
		FORGE.Give(player, "first weapon (no anvil)")
	end
	-- A23-188: the first mission IS the Forge visit; one who holds a weapon already (or a world without an anvil) is done
	finishFirst(player)
end

-- A23-74: ShopService runs this when the anvil prompt is used. At the Forge step the blacksmith hands over the class
-- basic weapon (LootService.GrantFirstWeapon: equipped with "Power 0 → N", the client's "Stronger!" moment), the first
-- mission moves on to step 1, "Travel to the Squishy Meadow" (A23-88: the player travels by the pad or the map, nothing
-- moves them). true = handled here (the caller opens no shop window this time)
function M.ForgeGift(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or getStep(player) ~= STEP_FORGE then return false end
	local data = getData(player)
	if not data or data.ClassChosen ~= true then return false end
	-- A23-130: no Otto line, LootService's "First weapon" line and the Stronger! moment answer
	local loot = S.LootService
	if loot and type(loot.GrantFirstWeapon) == "function" then
		local ok, err = pcall(loot.GrantFirstWeapon, player, 1)
		if not ok then Util.Warn(TAG, "GrantFirstWeapon: " .. tostring(err)) end
	end
	finishFirst(player) -- A23-188: the weapon and the 150 gold together; the meadow is the story's next (M1_1)
	return true
end

-- A23-74: nobody stays bare-handed past the Forge step. A save that accepted (or finished) the first mission before the
-- weapon came first, bare-handed and without the first weapon, gets the blacksmith's gift at once (tried once a
-- session; LootService.GrantFirstWeapon pays once: owning tier 1 is the record)
function FORGE.LateGift(player, data, step)
	if FORGE.Late[player] or data.ClassChosen ~= true then return end
	if step ~= STEP_GUIDE and step ~= STEP_QUEST and step ~= TUT_DONE then return end
	if not needsFirstWeapon(data) then return end
	FORGE.Late[player] = true
	FORGE.Give(player, "late first weapon")
end

-- Restore existing accepted progress. Step 0 only opens dialogue; closing it never accepts a mission.
local function tryTutorial(player)
	local data = getData(player)
	if not data then return end
	local step = getStep(player)
	FORGE.LateGift(player, data, step) -- A23-74: an old save past the Forge step is never left bare-handed
	if step == TUT_DONE then
		-- The existing watchdog observes purchases and level changes; publish deduplicates identical JSON.
		dirty[player] = true
		return
	end
	if step == STEP_GUIDE or step == STEP_QUEST then
		-- A23-188: a save from the old flow (past the Forge, on the way to / in the "5 slimes" hunt) is done at once with the
		-- same 150 gold: the slimes are hunted in the meadow anyway, the next is the story (M1_1)
		finishFirst(player)
		return
	end
	if step == STEP_FORGE then
		-- 검수 2026-10-07: the weapon shop gone (no anvil): the gift comes at once and the mission is done, never stuck
		if not FORGE.Anvil() then
			FORGE.Give(player, "first weapon (no anvil)")
			finishFirst(player)
			return
		end
		-- A23-88: the first time the walker stands at the anvil (a metric: seconds since [I'm In!]; only for a walk begun
		-- this session)
		-- A23-221 ⑥: the row follows arriving at / leaving the anvil ("Talk to Otto")
		local near = FORGE.Near(player)
		if FORGE.WasNear[player] ~= near then
			FORGE.WasNear[player] = near
			dirty[player] = true
		end
		local from = FORGE.AcceptedAt[player]
		if from and not FORGE.Reached[player] and near then
			FORGE.Reached[player] = true
			M.ForgeReached:Fire(player, math.max(0, os.clock() - from))
		end
		return
	end
	if step == TEACH.Step then
		-- P1 ②: the teacher's body is gone from this world: never stuck at the step
		if not TEACH.Teacher(player) then TEACH.After(player) end
		return
	end
	if TEACH.Practice ~= nil and step == TEACH.Practice then
		if not TEACH.PracticeSpot(player) then TEACH.After(player) end -- A23-221 ①: no dummy for this side: never stuck
		return
	end
	if step ~= STEP_WELCOME or welcomeShown[player] then return end
	if TEACH.Guide(player) then return end -- P1 ②: no automatic lines: the player walks to the guide (the row guides there)
	openWelcome(player)
end

-- P1 ② (StoryQuestService.TalkToNpc asks first): a talk to the guide opens the first mission's lines ("Welcome"); a talk to the
-- teacher at the Teacher step meets them (saved mark TeacherMet: the lesson is offered in the same talk) and moves on to the
-- Forge ("Teacher"). nil = this talk is not the first mission's
function M.TalkNpc(player, npcId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(npcId) ~= "string" then return nil end
	local step = getStep(player)
	if step == STEP_WELCOME and npcId == TEACH.Guide(player) and canWelcome(player) and TEACH.Near(player, npcId) then
		openWelcome(player)
		return "Welcome"
	end
	if step == TEACH.Step and npcId == TEACH.Teacher(player) and TEACH.Near(player, npcId) then
		local sq = S.StoryQuestService
		if type(sq) == "table" and type(sq.Mark) == "function" then
			local ok, err = pcall(sq.Mark, player, "TeacherMet")
			if not ok then Util.Warn(TAG, "Mark TeacherMet: " .. tostring(err)) end
		end
		TEACH.ToPractice(player)
		return "Teacher"
	end
	return nil
end

local function tutorialKill(player, info)
	local data = getData(player)
	if not data then return end
	local cur = getTutorialKills(data)
	if cur >= TUT_TARGET or not TUTORIAL_KINDS[Config.QuestKind(info.Kind)] or info.Personal == true
		or info.ZoneId ~= TUT_ZONE then return end
	cur += 1
	S.PlayerService.SetStat(player, "TutorialKills", cur) -- A23-130: 5/5 without a line (the row's [Claim] shows it)
	dirty[player] = true
end

-- A23-188: the first mission done (the Forge visit, or an old save past it): 150 gold, once (the step is saved first)
function finishFirst(player)
	local step = getStep(player)
	if step == TUT_DONE or not getData(player) then return end
	setStep(player, TUT_DONE) -- first, so it can never be paid twice
	TUT_READY_AT[player] = nil
	-- A23-75: the line shows what was added (the 2x Gold pass doubles the 150)
	local gotGold = S.ProgressionService.AddBankGold(player, TUT_GOLD, "Quest") or TUT_GOLD
	if TUT_XP > 0 then
		S.ProgressionService.AddXP(player, TUT_XP)
	end
	-- A23-130: the reward only, the same for a [Claim] and the F10-4 safety net
	Net.Notify(player, string.format(TUT_CLAIMED_TEXT, Util.FormatNumber(gotGold)), "reward", nil, "QuestDone")
end

-- an old client's [Claim] (the "5 slimes" row of the old flow): the mission is the Forge visit now (A23-188)
function claimTutorial(player, auto)
	if getStep(player) ~= STEP_QUEST then return end
	finishFirst(player)
end

-- A23-3: one fixed next-goal line after the blacksmith visit, from existing state only (no new reward).
local IRON_TIER = 3
local NEXT_ZONE = "GoblinWoods"
local function nextGoalText(data, player)
	local level = getLevel(data)
	-- A23-193: a ready skill waits at the side's teacher: first (one short walk)
	if typeof(player) == "Instance" and type(TUT_MESSAGES.NextLearn) == "string"
		and num(player:GetAttribute("SkillLearnReady")) > num(data.SkillSlots) then
		return string.format(TUT_MESSAGES.NextLearn, Config.SkillTeacherName(player:GetAttribute("Faction"))), "SkillLearn", nil
	end
	-- P1 ⑤: Lv5 reached but the first skill waits for the teacher's test (not taken yet): go to the teacher
	if typeof(player) == "Instance" and type(TUT_MESSAGES.NextTest) == "string" and num(data.SkillSlots) < 1
		and num(data.Rebirths) < 1 and level >= num((Config.Skills.Unlock or {}).Q, 5) then
		local story = S.StoryQuestService
		local okL, open = false, nil
		if type(story) == "table" and type(story.LearnOpen) == "function" then okL, open = pcall(story.LearnOpen, player, "Q") end
		if okL and open == false then
			return string.format(TUT_MESSAGES.NextTest, Config.SkillTeacherName(player:GetAttribute("Faction"))), "SkillTest", nil
		end
	end
	local iron = Config.Weapons[IRON_TIER]
	local owned = math.floor(num(data.WeaponOwnedMask, 1))
	-- A23-186: the equipped weapon counts when it is at least Iron by strength (never a joke weapon's tier number)
	local hasIron = bit32.btest(owned, bit32.lshift(1, IRON_TIER - 1)) or Config.WeaponAtLeast(math.floor(num(data.WeaponTier, 1)), IRON_TIER)
	if iron and not hasIron then
		if level < iron.MinLevel then
			-- A23-71 D6 / S16: the first skill comes at the same level (Skills.Unlock.Q): one line for both
			local q = math.floor(num((Config.Skills.Unlock or {}).Q))
			if q == iron.MinLevel and TUT_MESSAGES.NextSkillIron
				and not Config.SkillLearned(data.SkillSlots, level, data.Rebirths) then
				return string.format(TUT_MESSAGES.NextSkillIron, iron.MinLevel, level), "SkillIron", iron.MinLevel
			end
			return string.format(TUT_MESSAGES.NextIronLevel, iron.MinLevel, level), "IronLevel", iron.MinLevel
		end
		-- gameplay plan 2026-10-13 1-A #2: no weapon sold (Config.WeaponShop.Buy == false): it drops (Princes, the King);
		-- the line is Tutorial.Text.NextIronDrop (게임성 개발 1's text; none = no iron line, never the gold one)
		if type(Config.WeaponShop) == "table" and Config.WeaponShop.Buy == false then
			-- Codex B5 (최종 검수 10/14): the King Slime line only while a King is here or comes within KingSoon s (a goal
			-- that cannot be done now is not shown first; the next goals below take its place)
			local fb = S and S.FieldBossService
			local wait = nil
			if type(fb) == "table" and type(fb.SecondsUntil) == "function" then
				local okW, w = pcall(fb.SecondsUntil, "SlimeKing")
				wait = okW and w or nil
			end
			local soon = wait ~= nil and wait <= num(TUT_CFG.KingSoon, 120)
			if soon and type(TUT_MESSAGES.NextIronDrop) == "string" then return TUT_MESSAGES.NextIronDrop, "IronDrop" end
		else
			local gold = math.floor(math.max(0, num(data.CarriedGold)) + math.max(0, num(data.BankGold)))
			return string.format(TUT_MESSAGES.NextIronGold, Util.FormatNumber(iron.Price), Util.FormatNumber(gold)), "IronGold"
		end
	end
	-- SKL-3 (skill_kit §2): the next skill this save learns (Q; Z / X while their switch is on), before the next zone
	-- when it comes first
	local skills = Config.Skills or {}
	local skillAt = nil
	if num(data.Rebirths) < 1 then
		local have = math.floor(num(data.SkillSlots))
		for i, slot in skills.Order or { "Q", "Z", "X" } do
			if i > have then
				local need = math.floor(num((skills.Unlock or {})[slot]))
				if (slot == "Q" or skills[slot .. "Enabled"] == true) and need > level then skillAt = need end
				break
			end
		end
	end
	local zone = Config.Zones[NEXT_ZONE]
	local zoneAt = zone and level < zone.MinLevel and zone.MinLevel or nil
	if skillAt and (zoneAt == nil or skillAt <= zoneAt) and TUT_MESSAGES.NextSkill then
		return string.format(TUT_MESSAGES.NextSkill, skillAt, level), "Skill", skillAt
	end
	if zoneAt then
		return string.format(TUT_MESSAGES.NextZone, zone.MinLevel, tostring(zone.Name), level), "Zone", zone.MinLevel
	end
	-- A23-86 F: the ladder (feature hooks, then the rebirth line); the story row, when there is one, is pinned instead
	local ladder = TUT_CFG.Ladder
	if type(ladder) ~= "table" then return nil end
	for _, row in ladder.Hooks or {} do
		local svc = S and S[row.Service]
		if type(svc) == "table" and type(svc.NextGoal) == "function" and (row.Feature == nil or Config.FeatureOn(row.Feature)) then
			local ok, text, kind = pcall(svc.NextGoal, player, data)
			if ok and type(text) == "string" and text ~= "" then return text, type(kind) == "string" and kind or row.Kind, nil end
		end
	end
	local rb = ladder.Rebirth
	if type(rb) == "table" then
		local need = Config.RebirthLevel(math.max(0, math.floor(num(data.Rebirths))))
		if level >= need then
			return TUT_MESSAGES.NextRebirthReady, "RebirthReady", need
		elseif level >= need - math.max(0, math.floor(num(rb.Warn))) then
			return string.format(TUT_MESSAGES.NextRebirth, need, level), "Rebirth", need
		end
	end
	return nil
end

-- ShortName of a next-goal row: Config.Tutorial.ShortNames[kind], "%d" = the level the goal needs
local function goalShort(kind, need)
	local short = TUT_SHORT[kind]
	if type(short) ~= "string" then return nil end
	local ok, text = pcall(string.format, short, need or 0)
	return ok and text or short
end

local function tutorialEntry(player, data)
	local step = getStep(player)
	local entry = {
		Id = TUT_ID, Kind = TUT_KIND, Pinned = true, TutorialStep = step,
		Progress = 0, Target = 1, RewardGold = 0, RewardXP = 0,
		CanClaim = false, ShowProgress = false,
	}
	if step == STEP_WELCOME then
		-- 3rd idea round #3: the guide by name (there is no guide NPC in the world to look for)
		local guide = TUT_CFG.Welcome and TUT_CFG.Welcome[getFaction(player)]
		local name = type(guide) == "table" and type(guide.Name) == "string" and guide.Name or "the Guide"
		entry.Text = string.format(TUT_MESSAGES.Welcome or "Tap here: first quest from %s", name)
		entry.ShortName = type(TUT_SHORT.Welcome) == "string" and string.format(TUT_SHORT.Welcome, name) or nil
		-- P1 ②: the guide has a body: the row walks there (GuideNpc = its NpcId; the talk opens the lines)
		local body = TEACH.Guide(player)
		if body then
			entry.Text = string.format(TUT_MESSAGES.WelcomeBody or "Talk to %s", name)
			entry.GuideNpc = body
		end
	elseif step == TEACH.Step then
		-- P1 ②: meet the teacher (GuideNpc = the teacher's NpcId)
		local teacher = TEACH.Teacher(player)
		local name = TEACH.Name(player, teacher or "")
		entry.Text = string.format(TUT_MESSAGES.Teacher or "Meet %s at the town gate", name)
		entry.ShortName = type(TUT_SHORT.Teacher) == "string" and string.format(TUT_SHORT.Teacher, name) or nil
		entry.GuideNpc = teacher
	elseif TEACH.Practice ~= nil and step == TEACH.Practice then
		-- A23-221 ①: one hit at the dummy (GuideSpot = its Landmarks key: game dev 1's marker and the dummy itself)
		local _, key = TEACH.PracticeSpot(player)
		entry.Text = TUT_MESSAGES.Practice or "Hit the practice dummy"
		entry.ShortName = TUT_SHORT.Practice
		entry.GuideSpot = key
		entry.Practice = true
	elseif step == STEP_GUIDE then
		entry.Text = TUT_MESSAGES.Travel or "Go to the Squishy Meadow · Menu > Travel > Squishy Meadow"
		entry.ShortName = TUT_SHORT.Travel
	elseif step == STEP_QUEST then
		entry.Progress, entry.Target = getTutorialKills(data), TUT_TARGET
		entry.Text = TUT_TEXT -- A23-130: at 5/5 too (no "Press [Claim]": the row's [Claim] shows it)
		entry.ShortName = TUT_SHORT.Quest
		entry.RewardGold, entry.RewardXP = TUT_GOLD, TUT_XP
		entry.CanClaim, entry.ShowProgress = true, true
	elseif step == STEP_FORGE then
		-- A23-74: a tap sends RequestTutorial (the forge trip again); the client's beam goes to the anvil
		entry.Text = TUT_MESSAGES.Forge or "Get your first weapon · Crossroads Forge"
		entry.ShortName = TUT_SHORT.Forge
		-- A23-221 ⑥: arrived (within Forge.Near of the anvil): "Talk to Otto", the guide on Otto (GuideNpc)
		if FORGE.Near(player) then
			entry.Text = TUT_MESSAGES.ForgeHere or "Talk to Otto"
			entry.ShortName = TUT_MESSAGES.ForgeHere or "Talk to Otto"
			entry.GuideNpc = "Otto"
		end
	elseif step == TUT_DONE and data.ClassChosen == true and getFaction(player) ~= "None" then
		if data.BlacksmithVisited ~= true then
			entry.Text = (hasFirstWeapon(data) and TUT_MESSAGES.VisitBlacksmithArmed or TUT_MESSAGES.VisitBlacksmith)
				or "Check the weapons · Crossroads Forge"
			entry.ShortName = TUT_SHORT.Forge
		else
			local text, kind, need = nextGoalText(data, player)
			if not text then return nil end
			entry.Text = text
			-- A23-86 F: the rebirth rows carry the side's own question as a second line
			if kind == "Rebirth" or kind == "RebirthReady" then
				local f = getFaction(player)
				entry.GoalNote = f == "Halo" and TUT_MESSAGES.RebirthNoteHalo or f == "Horns" and TUT_MESSAGES.RebirthNoteHorns or nil
			end
			entry.ShortName = goalShort(kind, need)
			entry.NextGoal = true
			-- A23-48: which next goal this is ("SkillIron" (A23-71 S16) | "IronLevel" | "IronGold" | 1-A #2: "IronDrop" |
			-- "Skill" (SKL-3) |
			-- "Zone" | A23-86 F: "Commission" | "Clatter" | "Crystal" | "Rebirth" | "RebirthReady"), so clients never
			-- search the (now English) text for a word
			entry.GoalKind = kind
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
		return
	end
	local data = getData(player)
	if not data then return end
	local list = {}
	local tutorial = tutorialEntry(player, data)
	-- after the first mission the story main row takes the pinned slot (the next-goal line stays the fallback)
	local story = S.StoryQuestService
	if getStep(player) == TUT_DONE and story and type(story.MainRow) == "function" then
		-- A23-193: a skill waiting at the side's teacher keeps the pinned row ("Learn a skill: meet <teacher>") over the
		-- story main row (after the Forge visit; the main row comes back once it is learned)
		local learnWaits = tutorial ~= nil and tutorial.GoalKind == "SkillLearn"
		local okMain, main = pcall(story.MainRow, player, data)
		-- r5 플레이 (최종 검수 10/16): ...unless the story step itself is that lesson (M1_3's "Learn your first skill from Rose"):
		-- swapping it out made the M1_3 row leave the list in the same publish as Tiny's hand-over, so the client never saw
		-- the Deliver step end (no Tiny line) and the row read the bare "Next goal" line
		local mainLearns = false
		if okMain and type(main) == "table" and type(main.Story) == "table" then
			local def = Config.StoryQuests.Defs[main.Story.Id]
			local stp = type(def) == "table" and type(def.Steps) == "table" and def.Steps[main.Story.St] or nil
			mainLearns = type(stp) == "table" and type(stp.Obj) == "table" and stp.Obj.Type == "Learn"
		end
		if okMain and main and (not learnWaits or mainLearns) then tutorial = main end
	end
	if tutorial then table.insert(list, tutorial) end -- always first, never occupies/rerolls a daily slot
	if story and type(story.SubRows) == "function" then
		local okSubs, subs = pcall(story.SubRows, player, data)
		if okSubs and type(subs) == "table" then
			for _, row in subs do table.insert(list, row) end
		end
	end
	-- E11: the jobs carried from the boards (Kind "Job"; they pay when done, no [Claim])
	local board = S.BoardService
	if boardOn() and board and type(board.JobRows) == "function" then
		local okJobs, jobs = pcall(board.JobRows, player, data)
		if okJobs and type(jobs) == "table" then
			for _, row in jobs do table.insert(list, row) end
		end
	end
	-- #45: the walk of a lost thing to the Lost & Found bench / the vault (Kind "Find", no [Claim]: it pays on arrival)
	local lost = S.LostFoundService
	if lost and type(lost.Rows) == "function" then
		local okLost, lostRows = pcall(lost.Rows, player, data)
		if okLost and type(lostRows) == "table" then
			for _, row in lostRows do table.insert(list, row) end
		end
	end
	-- (the guide chain running out just removes the row: its 'That's all from me!' line is deleted, 최종 검수 10/15)
	local locked = not dailiesOpen(data)
	if not locked and type(data.Quests) == "table" then
		-- CR-M6: dailies show what a claim pays now (stored reward capped to the current level; stored value kept)
		local capG, capX = Config.DailyQuestReward(getLevel(data))
		for i, q in ipairs(data.Quests) do
			if type(q) == "table" and not isEmptySlot(q) then
				local rg, rx = num(q.RewardGold), num(q.RewardXP)
				if q.Kind == "Daily" then
					rg, rx = capTo(math.floor(rg), math.floor(rx), capG, capX)
				end
				local tpl = TEMPLATE_BY_ID[q.Id]
				table.insert(list, {
					Id = tostring(q.Id),
					Kind = q.Kind,
					Text = tostring(q.Text),
					ShortName = tpl and tpl.ShortName or nil, -- 검수 2026-10-07: the phone HUD quest row
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
	-- A23-68 #4: until the first [Claim] only the first mission's line shows; the others are kept but folded
	if TUT_CFG.FoldOthers == true and getStep(player) ~= TUT_DONE then
		for _, row in list do
			if row.Id ~= TUT_ID then row.Folded = true end
		end
	end
	-- A23-81 quest window (게임성 개발 3): the book's "Available" / "Done" lists (StoryQuestService.BookRows)
	local book = nil
	if story and type(story.BookRows) == "function" then
		local okBook, rows = pcall(story.BookRows, player, data)
		if okBook and type(rows) == "table" then book = rows elseif not okBook then loopWarn("quest book", rows) end
	end
	local ok, json = pcall(HttpService.JSONEncode, HttpService, list)
	if not ok then
		Util.Warn(TAG, "quest list encode failed: " .. tostring(json))
		return
	end
	local okBookJson, bookJson = pcall(HttpService.JSONEncode, HttpService, book or {})
	local sentKey = json .. "|" .. (okBookJson and bookJson or "")
	-- CR-L50: owner-only remote instead of the QuestsJson attribute (which replicated to every client), fired only
	-- on change. A23-81: payload = { Quests = the rows, Book = { Available, Done } } (HUD / Audio read .Quests; a JSON
	-- string of the bare rows is the older payload clients still accept)
	if lastSent[player] == sentKey then return end
	local okF, err = pcall(function()
		-- A23-104: DailyLocked = true while the daily jobs are not open yet (game dev 1: the Q window's Daily tab is locked)
		Net.Get("Quests"):FireClient(player, { Quests = list, Book = book, DailyLocked = locked or nil })
	end)
	if okF then
		lastSent[player] = sentKey
	else
		Util.Warn(TAG, "Quests fire failed: " .. tostring(err))
	end
end

------------------------------------------------------------------ progress & completion
-- A23-75: returns the gold and XP really added (the 2x passes), for the lines the callers show
local function payReward(player, gold, xp, xpCap)
	if gold > 0 then
		gold = S.ProgressionService.AddBankGold(player, gold, "Quest") or gold
	end
	if xp > 0 then
		xp = S.ProgressionService.AddXP(player, xp, xpCap) or xp -- xpCap: after the 2x pass (ProgressionService.AddXP)
	end
	return math.max(0, gold), math.max(0, xp)
end

-- bonus chest for the full set of dailies (claimed by hand, or completed by the midnight auto-pay: CR-M21).
-- genLevel = level the set was generated at (default data.DailyLevel; the midnight auto-pay passes the OLD day's)
local function payChest(player, data, genLevel)
	if genLevel == nil then genLevel = data.DailyLevel end
	local cg, cx = chestReward(getLevel(data), genLevel)
	cg, cx = math.floor(num(cg)), math.floor(num(cx))
	cg, cx = payReward(player, cg, cx)
	Net.Notify(player, string.format(Config.Text.DailyChest, Util.FormatNumber(cg), Util.FormatNumber(cx)), "reward", nil,
		"GoldPickup")
	if Util.Random:NextNumber() < Config.Daily.ChestTicketChance then
		local ok, err = pcall(S.MonetizationService.AddTickets, player, "Class", 1)
		if ok then
			Net.Notify(player, string.format(Config.Text.DailyChestTicket), "reward", nil, "None")
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
		-- replace first so the finished quest can never be paid twice (E11 boards on: the slot stays empty)
		data.Quests[index] = boardOn() and { Kind = "Empty" } or newQuest(player, "Extra", othersExcept(data.Quests, index))
		local gotGold = payReward(player, math.floor(num(q.RewardGold)), math.floor(num(q.RewardXP)))
		if not quiet then
			Net.Notify(player, string.format(Config.Text.QuestDone, Util.FormatNumber(gotGold)), "reward", nil, "QuestDone")
		end
	end -- (a finished daily stays in its slot until claimed; its row says Done! / [Claim]: no line, 최종 검수 10/15)
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
	if not data or not dailiesOpen(data) or type(data.Quests) ~= "table" then return end
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
	if not data or not dailiesOpen(data) then return end
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
		local dayBand = bandAt(band) -- A23-14 Newbie / E12 Woods / nil = the template dailies
		local perQuest = dayBand and num(dayBand.RewardMinutes, D.QuestMinutes) or D.QuestMinutes
		local chestMin = dayBand and num(dayBand.ChestMinutes, D.ChestMinutes) or D.ChestMinutes
		local fullDay = perQuest * slots + chestMin
		local earned = claims * perQuest + ((claims >= slots) and chestMin or 0)
		local f = if fullDay > 0 then math.clamp(earned / fullDay, 0, 1) else 1
		local add = (1 - f) + math.max(0, today - dailyDay - 1)
		if add > 0 then
			local days = math.min(D.VacationMaxDays, math.max(0, num(data.VacationDays)) + add)
			days = math.floor(days * 1000 + 0.5) / 1000 -- keep the mirrored attribute tidy
			local g, x = Config.VacationReward(getLevel(data), days)
			local room = vacationXPRoom(data) -- the shown amount stops below Lv10 too (the claim checks again)
			if room ~= nil then x = math.min(x, room) end
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
		paidGold += (payReward(player, g, x))
	end
	if paidGold > 0 then
		Net.Notify(player, string.format(Config.Text.DailyAutoPaid, Util.FormatNumber(paidGold)), "reward", nil, "QuestDone")
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

	data.Quests[slot] = boardOn() and { Kind = "Empty" } or newQuest(player, "Extra", othersExcept(data.Quests, slot)) -- E11
	dirty[player] = true

	local g, x = math.floor(num(q.RewardGold)), math.floor(num(q.RewardXP))
	g, x = capTo(g, x, Config.DailyQuestReward(getLevel(data))) -- CR-M6
	g, x = payReward(player, g, x)
	Net.Notify(player, string.format(Config.Text.DailyClaimed, Util.FormatNumber(g), Util.FormatNumber(x)), "reward", nil,
		"QuestDone")

	local claims = num(S.PlayerService.AddStat(player, "DailyClaims", 1))
	if claims == Config.Quests.Slots then
		payChest(player, data) -- A23-130: no DailyAllDone line after the chest (reward lines only)
	end
end

local function onRerollQuest(player, slot)
	if not S.PlayerService.IsReady(player) then return end
	if not isSlotIndex(slot) then return end
	if not Util.RateLimit(player, "RerollQuest", Config.RateLimits.RerollQuest) then return end
	local data = getData(player)
	if not data or not dailiesOpen(data) or type(data.Quests) ~= "table" then return end -- A23-104: no jobs to reroll yet

	local now = Util.Now()
	if now < (rerollReadyAt[player] or 0) then return end

	local q = data.Quests[slot]
	if boardOn() and not isValidQuest(q) then return end -- E11: an empty slot is never rerolled into an extra
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
	-- 최종 검수 10/13: below Lv10 the XP stops at the end of Lv9 (vacation alone never reaches Lv10), the 2x pass included
	local room = vacationXPRoom(data)
	if room ~= nil then x = math.min(x, room) end
	g, x = payReward(player, g, x, room)
	Net.Notify(player, string.format(Config.Text.VacationClaimed, Util.FormatNumber(g), Util.FormatNumber(x)), "reward", nil,
		"GoldPickup")
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

	if dailiesOpen(data) then
		-- a save that already runs its dailies never gets the intro quest (A23-104)
		local intro = Config.Daily and Config.Daily.IntroQuest
		local done = type(data.Story) == "table" and type(data.Story.Done) == "table" and data.Story.Done or nil
		if done and type(intro) == "string" then done[intro] = true end
		ensureSlots(player, data)
		remakeUnfit(player, data, getFaction(player)) -- A23-71: a skill daily kept from before the Lv5 rule
		runDayCheck(player)
	end
	tryTutorial(player) -- pending dialogue opens once when choices and a living character are ready
	publish(player)
end

local function onPlayerLeaving(player)
	dirty[player] = nil
	lastSent[player] = nil
	rerollReadyAt[player] = nil
	welcomeShown[player] = nil
	TUT_READY_AT[player] = nil
	FORGE.Late[player] = nil
	FORGE.AcceptedAt[player], FORGE.Reached[player], FORGE.WasNear[player] = nil, nil, nil
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
	dirty[player] = true -- 3rd idea round #3: the welcome row names the side's guide
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
	if info.Practice == true then return end -- A23-110: the retry King (a practice King) counts for no daily job
	-- A23-201 (최종 검수 10/15 a): daily jobs have no Credit mode = as before: every player the kill pays, + party proxies
	if type(info.Credit) == "table" and info.Credit.Any ~= true then return end
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

local function onGooseFinished(_result, counts, info)
	-- ④ (최종 검수 10/14): the egg hunt counts everyone who brought an egg home (info.Took), paid or not
	if type(info) == "table" and type(info.Took) == "table" then counts = info.Took end
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
	dirty[player] = true -- 3rd idea round #3: the welcome row names the side's guide
	local data = getData(player)
	if not data then return end
	if type(newFaction) ~= "string" then newFaction = getFaction(player) end
	remakeUnfit(player, data, newFaction)
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
	if not dailiesOpen(data) or type(data.Quests) ~= "table" then return end
	local quests = data.Quests
	for i = 1, Config.Quests.Slots do
		local q = quests[i]
		if not isValidQuest(q) or q.Kind == "Extra" then
			quests[i] = boardOn() and { Kind = "Empty" } or newQuest(player, "Extra", othersExcept(quests, i)) -- E11
		end
	end
	dirty[player] = true
end

-- CR-M6: the daily cap rises with the level -> republish so the shown (capped) daily rewards follow it
local function onLeveledUp(player)
	dirty[player] = true
end

------------------------------------------------------------------ public API
-- A23-104: are this player's daily jobs open (true) or still to be told by the intro quest (false)?
function M.DailiesOpen(player)
	return dailiesOpen(getData(player))
end

-- A23-104: the intro quest is done: the daily jobs open now (the first set is made at once). true = they just opened
function M.OpenDailies(player)
	local data = getData(player)
	if not data or dailiesOpen(data) then return false end
	S.PlayerService.SetStat(player, "DailyIntro", true)
	ensureSlots(player, data)
	runDayCheck(player)
	publish(player) -- at once: the Quests window must not wait for the publish loop to drop its lock
	return true
end

function M.GetQuests(player)
	local data = getData(player)
	if not data or type(data.Quests) ~= "table" then return {} end
	return data.Quests
end

-- the day check of one player now (the 30 s day loop's body; A23-104: a player whose daily jobs are not open yet gets none)
function M.DayCheck(player)
	runDayCheck(player)
	publish(player)
end

-- Studio hook: pretend the player was away for `days` whole days, then run the day check
function M.DebugSimulateAbsence(player, days)
	if not dailiesOpen(getData(player)) then return end -- A23-104: no daily jobs yet, nothing to be away from
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
	local questKill = S.MonsterService and S.MonsterService.QuestKill -- A23-201: quest credit of a kill that does not pay me
	if type(questKill) == "table" and type(questKill.Connect) == "function" then
		questKill:Connect(function(player, info)
			if type(info) == "table" and type(info.Credit) == "table" then onMonsterKilled(player, info) end
		end)
	end
	connectSignal("ProgressionService", "GoldEarned", onGoldEarned)
	connectSignal("ProgressionService", "Rebirthed", onRebirthed)
	connectSignal("ProgressionService", "LevelReset", onRebirthed) -- CR-M6
	connectSignal("ProgressionService", "LeveledUp", onLeveledUp) -- CR-M6
	connectSignal("CombatService", "Released", onReleased)
	-- A23-221 ①: the practice dummy's hit (looked up softly: a world without the signal has no practice step to count)
	local combat = S.CombatService
	if type(combat) == "table" and type(combat.BasicSwing) == "table" and type(combat.BasicSwing.Connect) == "function" then
		combat.BasicSwing:Connect(function(player, pos)
			local ok, err = pcall(TEACH.OnSwing, player, pos)
			if not ok then Util.Warn(TAG, "practice swing: " .. tostring(err)) end
		end)
	end
	connectSignal("GooseService", "GooseFinished", onGooseFinished)
	-- A23-113 #8: a good / naughty deed (a choice card, the King's finisher card, a job board Kind / Sneaky job) fills the daily
	-- 'Choice'. Soft: a world without the ledger simply never has the choice daily.
	local deeds = S.Deeds
	if type(deeds) == "table" and type(deeds.Booked) == "table" and type(deeds.Booked.Connect) == "function" then
		deeds.Booked:Connect(function(player)
			if typeof(player) == "Instance" and player:IsA("Player") then addProgress(player, "Choice", 1) end
		end)
	end
	-- artisan min ④: a pick at a gathering node / a finished craft fills the guild's dailies. Soft: a world without those
	-- services never has those dailies
	for _, hook in { { "GatherService", "Gathered", "Gather" }, { "CraftService", "Crafted", "Craft" } } do
		local svc = S[hook[1]]
		local sig = type(svc) == "table" and svc[hook[2]] or nil
		if type(sig) == "table" and type(sig.Connect) == "function" then
			local questId = hook[3]
			sig:Connect(function(player)
				if typeof(player) == "Instance" and player:IsA("Player") then addProgress(player, questId, 1) end
			end)
		end
	end
	connectSignal("PvPService", "PlayerKO", onPlayerKO)
	connectSignal("KaijuService", "KaijuEnded", onKaijuEnded)
	connectSignal("FactionService", "FactionChanged", onFactionChanged)
	connectSignal("ClassService", "ClassChanged", onClassChanged)
	connectSignal("StoryQuestService", "QuestDone", function(player, id)
		if id ~= (Config.Daily and Config.Daily.IntroQuest) then return end
		local ok, err = pcall(M.OpenDailies, player)
		if not ok then Util.Warn(TAG, "OpenDailies: " .. tostring(err)) end
	end)
	connectSignal("ZoneService", "ZoneChanged", onZoneChanged)
end

-- StoryQuestService asks for a fresh quest list after story progress
function M.MarkDirty(player)
	if typeof(player) == "Instance" and player:IsA("Player") then dirty[player] = true end
end

-- A23-79 (게임성 개발 3): the row publish() pins first (the story main row after the first mission, else the first-mission
-- / next-goal entry), nil when nothing is pinned. ReturnService's pause card / welcome back "Next" line.
function M.PinnedRow(player)
	local data = getData(player)
	if not data then return nil end
	local row = tutorialEntry(player, data)
	local story = S.StoryQuestService
	if getStep(player) == TUT_DONE and story and type(story.MainRow) == "function" then
		local ok, main = pcall(story.MainRow, player, data)
		if ok and main then row = main end
	end
	return row
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
