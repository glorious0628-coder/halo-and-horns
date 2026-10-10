-- StoryQuestService.luau : "부서진 왕관 이야기" story quests (Config.StoryQuests; design
-- docs/design/quest_chain_2026-10-06.md, user OK 2026-10-06). One main chain after the first mission
-- (TutorialStep 99) + automatically accepted sub quests (S0 "내 싸움을 배우는 왕관 조각" right after the class pick).
-- Server-authoritative: progress comes only from server signals / server state; the client may only confirm a
-- Talk page or pick a Choice option of the step that is active right now (remote "StoryAction"). A finished step is
-- saved before any reward is paid, so nothing can be paid twice. QuestService puts the rows into the quest list.
--
-- data.Story = { Main = { Id, St, P, T, Claim } | { Id = "" }, Subs = { [id] = { St, P, T, Claim } },
--                Done = { [id] = true }, Pick = { [id] = "Good" | "Evil" | "A" | "B" | "Purify" | "Devour" },
--                First = { [key] = true }, LastSide = "Good" | "Evil" | nil, TownLast = quest id | nil,
--                TownFaction = the faction that made the TownLast pick | nil }
--                (St = 1-based step, P = progress, T = trial progress table; TownLast: A23-64 ① the last
--                Config.TownReact.Order quest picked, its side = SIDE[Pick[TownLast]])
-- A23-64 (zone_check_halo #39): every good / evil pick sends Fx "Afterglow" (afterglow below); a town quest's pick sets
-- the player attribute TownPick "<quest id>:Good|Evil" that game dev 1's TownReact bubbles read (townPickOf below).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local StoryQuestService = {}
-- A23-79 (게임성 개발 3): (player, quest id) a story quest finished / (player, quest id, saved pick) a choice was made
StoryQuestService.QuestDone = Util.Signal.new()
StoryQuestService.Picked = Util.Signal.new()
local S = nil
local TAG = "StoryQuestService"
local SQ = Config.StoryQuests
local TXT = SQ.Text
local DEFS = SQ.Defs
local TUT_DONE = Config.Tutorial.Steps.Done -- 99
local MAIN_INDEX = {}
for i, id in SQ.Main do MAIN_INDEX[id] = i end
local TICK = 1
-- E4 Near.Stay: [Player] = { [questId .. ":" .. step] = os.clock() when the player came inside } (never saved: a rejoin
-- or leaving the spot starts the count again)
local stays = {}
-- story_depth E1 / E2 / E3: a pick's side (Good / Purify / A on one side, Evil / Devour / B on the other). Every Pick in
-- Config.StoryQuests has its side here (검수 2026-10-07: SKL-3 SK2's Guard / Take were missing, so that pick never
-- counted as a change of mind; A23-70 Lunch1's GiveBack / Bite too)
local SIDE = { Good = "Good", Purify = "Good", A = "Good", Evil = "Evil", Devour = "Evil", B = "Evil", Guard = "Good",
	Take = "Evil", GiveBack = "Good", Bite = "Evil", Care = "Good", Minion = "Evil" } -- Care / Minion: PET-4 Pet1

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function faction(player)
	local f = player:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function dirty(player)
	if S.QuestService and type(S.QuestService.MarkDirty) == "function" then
		pcall(S.QuestService.MarkDirty, player)
	end
end

-- BB1: '{Auto}'-style key tokens -> this player's saved key labels (Config.KeyMap of data.Settings.Keys), for toasts.
-- Quest rows keep the raw tokens: the client fills them (HUD L.QuestText: a phone shows the button name, A23-21) and
-- redraws them when the keys change.
local function keyText(data, text)
	if type(text) ~= "string" or not string.find(text, "{", 1, true) then return text end
	local settings = type(data) == "table" and data.Settings or nil
	return Config.FillKeys(text, (Config.KeyMap(type(settings) == "table" and settings.Keys or nil, nil)))
end

local function notify(player, text, kind, sound)
	if type(text) == "string" and text ~= "" then
		pcall(Net.Notify, player, keyText(getData(player), text), kind or "info", nil, sound)
	end
end

------------------------------------------------------------------ data
local function story(data)
	local st = data.Story
	if type(st) ~= "table" then
		st = {}
		data.Story = st
	end
	for _, k in { "Subs", "Done", "Pick", "First" } do
		if type(st[k]) ~= "table" then st[k] = {} end
	end
	if type(st.Main) ~= "table" then st.Main = { Id = "" } end
	return st
end

-- A23-64 ① (zone_check_halo #39): a quest whose pick the townsfolk remember (listed in Config.TownReact.Order)
local function isTownPick(id)
	local R = Config.TownReact
	return type(id) == "string" and type(R) == "table" and type(R.Order) == "table" and table.find(R.Order, id) ~= nil
end

-- "<quest id>:Good" | "<quest id>:Evil" from data.Story.TownLast (the side of its saved pick) for faction f, "" = none /
-- not valid. A pick made under another faction (Story.TownFaction; an Altar or rebirth switch since) is not voiced:
-- S6's card differs per town, so the other town's line would tell a pick the player never made (review 10/10)
local function townPickOf(st, f)
	local id = st.TownLast
	local side = isTownPick(id) and SIDE[st.Pick[id]] or nil
	if not side or (st.TownFaction ~= nil and st.TownFaction ~= f) then return "" end
	return id .. ":" .. side
end

-- the player attribute TownPick (game dev 1's TownReact reads it; set only when it changes)
local function publishTownPick(player, st)
	local value = townPickOf(st, faction(player))
	if player:GetAttribute("TownPick") ~= value then player:SetAttribute("TownPick", value) end
end

-- drop unknown ids / bad numbers (fillDefaults only fills the top level)
local function sanitize(data)
	local st = story(data)
	local function fixTrack(tr, id)
		local def = DEFS[id]
		if type(tr) ~= "table" or not def then return nil end
		tr.St = math.clamp(math.floor(num(tr.St, 1)), 1, #def.Steps)
		tr.P = math.max(0, num(tr.P))
		if type(tr.T) ~= "table" then tr.T = {} end
		tr.Claim = tr.Claim == true
		return tr
	end
	if st.Main.Id ~= "" then
		local moved = DEFS[st.Main.Id]
		-- A23-86: a main quest that became a side line (M3_5) keeps its track as a sub
		if moved and moved.Kind == "Sub" and not st.Done[st.Main.Id] and st.Subs[st.Main.Id] == nil then
			st.Subs[st.Main.Id] = { St = st.Main.St, P = st.Main.P, T = st.Main.T, Claim = st.Main.Claim }
		end
		if not DEFS[st.Main.Id] or DEFS[st.Main.Id].Kind ~= "Main" or st.Done[st.Main.Id] then
			st.Main = { Id = "" }
		else
			fixTrack(st.Main, st.Main.Id)
		end
	end
	for id, tr in st.Subs do
		if not DEFS[id] or DEFS[id].Kind ~= "Sub" or st.Done[id] or not fixTrack(tr, id) then st.Subs[id] = nil end
	end
	for id in st.Done do
		if not DEFS[id] then st.Done[id] = nil end
	end
	if st.LastSide ~= "Good" and st.LastSide ~= "Evil" then st.LastSide = nil end -- E2: the side of the last real pick
	-- A23-64 ①: a missing or bad TownLast (an old save) = the last quest of Config.TownReact.Order with a saved pick that
	-- the save's faction can have (Defs[id].Factions); TownFaction = the faction that made it (an old save: today's)
	if type(st.TownFaction) ~= "string" then st.TownFaction = nil end
	if townPickOf(st, st.TownFaction or data.Faction) == "" then
		st.TownLast, st.TownFaction = nil, nil
		local R = Config.TownReact
		for _, id in type(R) == "table" and type(R.Order) == "table" and R.Order or {} do
			local fs = DEFS[id] and DEFS[id].Factions
			if SIDE[st.Pick[id]] ~= nil and (type(fs) ~= "table" or fs[data.Faction] == true) then st.TownLast = id end
		end
		if st.TownLast then st.TownFaction = data.Faction end
	end
end

------------------------------------------------------------------ step helpers
-- the step definition for this player's faction (a step may carry a Neutral override)
local function stepOf(player, def, index)
	local step = def.Steps[index]
	if not step then return nil end
	local f = faction(player)
	if step[f] and type(step[f]) == "table" then
		local over = table.clone(step)
		for k, v in step[f] do over[k] = v end
		return over
	end
	return step
end

-- E2: the LinesBy entry this player sees (game dev 1's Story window reads it as Var): the exact pick of LinesBy.From
-- when listed, else its side, else Default (an old save has no picks: every LinesBy has a Default). nil = plain Lines.
local function varFor(data, step)
	local by = step and step.LinesBy
	if type(by) ~= "table" or type(data) ~= "table" then return nil end
	local pick = story(data).Pick[by.From]
	if pick ~= nil and by[pick] ~= nil then return pick end
	local side = SIDE[pick]
	if side ~= nil and by[side] ~= nil then return side end
	return "Default"
end

local function homeZone(player)
	return Config.HomeZoneId(faction(player))
end

local function zoneMatches(player, want, zoneId)
	local zone = Config.Zones[zoneId]
	if want == "OwnTown" then return zoneId == homeZone(player) end
	if want == "AnyTown" then return zone ~= nil and zone.Town == true end
	return zoneId == want
end

local function currentZone(player)
	local ok, z = pcall(S.ZoneService.GetZoneId, player)
	return ok and z or player:GetAttribute("ZoneId")
end

-- A23-46: a step with Npc is talked through that town NPC (game dev 1 tags its model SQ.NpcTag with the attribute
-- NpcId). True when the player stands within SQ.NpcRange of it, or when no such NPC exists in the world yet.
local function npcNear(player, npcId)
	if type(npcId) ~= "string" then return true end
	local okTag, tagged = pcall(function()
		return game:GetService("CollectionService"):GetTagged(SQ.NpcTag or "StoryNpc")
	end)
	if not okTag or type(tagged) ~= "table" then return true end
	local root = Util.GetRoot(player)
	local found = false
	for _, inst in tagged do
		if inst:GetAttribute("NpcId") == npcId then
			found = true
			local okPos, pos = pcall(function()
				if inst:IsA("Model") then return inst:GetPivot().Position end
				return inst.Position
			end)
			if okPos and root and typeof(pos) == "Vector3" and Util.FlatDistance(root.Position, pos) <= (SQ.NpcRange or 16) then
				return true
			end
		end
	end
	return not found
end

-- 빛 마을 점검 #2: a landmark follows its placed model (Util.TaggedSpot: a workspace instance tagged SQ.LandmarkTag
-- with the attribute Spot = the key, e.g. on the hero statue pair's centre; the client guides read the same rule), else
-- the Config spot. Read when a step needs it (like npcNear); only flat distances use it, so its height does not matter.
local function landmark(id)
	if type(id) ~= "string" then return nil end
	return Util.TaggedSpot(SQ.LandmarkTag or "StoryLandmark", id) or SQ.Landmarks[id]
end

local function ownsIron(player)
	local mask = math.floor(num(player:GetAttribute("WeaponOwnedMask"), 1))
	return bit32.btest(mask, bit32.lshift(1, 2)) or num(player:GetAttribute("WeaponTier"), 1) >= 3
end

local function stateTrue(player, key)
	if key == "BlacksmithVisited" then return player:GetAttribute("BlacksmithVisited") == true end
	if key == "AutoOn" then return player:GetAttribute("AutoCombatEnabled") == true end
	if key == "OwnIron" then return ownsIron(player) end
	if key == "Graduated" then -- E7 (quest_volume): no Sprout Shield any more (PvPService.IsRookie)
		local pvp = S.PvPService
		if type(pvp) ~= "table" or type(pvp.IsRookie) ~= "function" then return false end
		local ok, rookie = pcall(pvp.IsRookie, player)
		return ok and rookie == false
	end
	return false
end

-- A23-71: the step is a skill hit, or a trial list with a skill-hit trial not done yet
local function needsSkill(obj, track)
	if obj.Type == "SkillHit" then return true end
	if obj.Type ~= "Trials" or type(obj.List) ~= "table" then return false end
	for _, sub in obj.List do
		if sub.Type == "SkillHit" and num(type(track.T) == "table" and track.T[sub.Key]) < num(sub.Count, 1) then return true end
	end
	return false
end

-- a Level step is reached; A23-71 Skill = also once the first skill is learned (Q kept after a free class change took
-- the level back to 1, or a rebirth)
local function levelReached(data, obj)
	if num(data.Level, 1) >= num(obj.Level) then return true end
	return obj.Skill == true and Config.SkillLearned(data.SkillSlots, data.Level, data.Rebirths)
end

-- the opening line(s) of a quest that just started: its Start, then (A23-71 S8) its first Level step's own Start while
-- that level is still ahead (past it, the step passes at once and the next step's Start is said instead)
local function announceStart(player, data, def)
	if def.Hidden then return end -- E5: a hidden sub stays secret
	if def.Start then notify(player, def.Start, "info") end
	local first = stepOf(player, def, 1)
	local obj = first and first.Obj
	if first and first.Start and type(obj) == "table" and obj.Type == "Level" and not levelReached(data, obj) then
		notify(player, first.Start, "info")
	end
end

-- how much one event moves an objective (0 = not this objective)
local function eventAmount(player, obj, ev)
	local t = obj.Type
	if ev.Kind == "Kill" then
		local info = ev.Info
		-- a personal monster never counts, except for a step that asks for exactly that (KO1's rematch Personal = true)
		if (info.Personal == true) ~= (obj.Personal == true) then return 0 end
		if t == "WarPoints" then return math.max(0, num(info.WarPoints)) end
		if t ~= "Kill" and t ~= "BasicKill" and t ~= "SafeKill" and t ~= "AutoKill" then return 0 end
		-- A23-86 Call of the Woods: obj.Alt = { MinLevel, Pairs = { { Kind, Zone } } } lets another kind in its own zone
		-- fill the same step from that level on
		local alt = false
		local a = obj.Alt
		if type(a) == "table" and type(a.Pairs) == "table" then -- (only kill steps get here: the types above)
			local data = getData(player)
			if data and num(data.Level, 1) >= num(a.MinLevel, 1) then
				for _, pair in a.Pairs do
					if Config.QuestKind(info.Kind) == pair.Kind and info.ZoneId == pair.Zone then
						alt = true
						break
					end
				end
			end
		end
		if not alt then
			if obj.Kind and Config.QuestKind(info.Kind) ~= obj.Kind then return 0 end -- a pumpkin slime counts as a slime
			if obj.Zone and info.ZoneId ~= obj.Zone then return 0 end
		end
		if obj.Golden and info.Golden ~= true then return 0 end
		if obj.Near then
			local spot = landmark(obj.Near)
			if not spot or typeof(info.Position) ~= "Vector3" or Util.FlatDistance(info.Position, spot) > (obj.Radius or 40) then return 0 end
		end
		if t == "BasicKill" and info.SkillHit == true then return 0 end
		if t == "AutoKill" and player:GetAttribute("AutoCombatEnabled") ~= true then return 0 end
		if t == "SafeKill" then
			local hum = Util.GetHumanoid(player)
			if not hum or hum.MaxHealth <= 0 or hum.Health / hum.MaxHealth < (obj.MinHP or 0.5) then return 0 end
		end
		return 1
	elseif ev.Kind == "Skill" then
		if t ~= "SkillHit" or ev.Info.Auto == true then return 0 end
		if obj.Slot and ev.Info.Slot ~= obj.Slot then return 0 end -- SKL-3: only that skill's casts (SK1 Z, SK2 X)
		return num(ev.Info.MonstersHit) >= (obj.Min or 1) and 1 or 0
	elseif ev.Kind == "Gold" then
		if t == "EarnGold" and (obj.Source == nil or obj.Source == ev.Source) then return math.floor(num(ev.Amount)) end
		if t == "WarChest" and ev.Source == "War" then return 1 end
		return 0
	elseif ev.Kind == "Goose" then
		return t == "Goose" and 1 or 0
	end
	return 0
end

-- E11: BoardService judges its jobs (Kill / BasicKill / SafeKill / AutoKill / SkillHit / EarnGold ...) by these rules
function StoryQuestService.EventAmount(player, obj, ev)
	return eventAmount(player, obj, ev)
end

------------------------------------------------------------------ rewards / finishing
-- E6 / Reward.Item: an item or potions through LootService.GrantItem (its caps and full notices); the "+Name" part of the
-- reward line, or nil when nothing was given
local function grantItem(player, id, n)
	local loot = S.LootService
	if type(id) ~= "string" or type(loot) ~= "table" or type(loot.GrantItem) ~= "function" then return nil end
	local ok, res = pcall(loot.GrantItem, player, id, math.floor(num(n, 1)))
	if not ok then Util.Warn(TAG, "GrantItem: " .. tostring(res)) end
	local given = ok and math.floor(num(res)) or 0
	if given <= 0 then return nil end
	local item = Config.Loot.Items[id]
	local name = (item and item.Name) or Config.Loot.Text.Potion[id] or id
	return given > 1 and string.format(Config.Loot.Text.GotN, name, given) or string.format(Config.Loot.Text.Got, name)
end

local function payReward(player, def)
	local r = def.Reward
	if type(r) ~= "table" then return nil end
	local level = math.max(1, math.floor(num(player:GetAttribute("Level"), 1)))
	local g, x = 0, 0
	if num(r.Gold) > 0 then g = select(1, Config.HuntValue(level, r.Gold)) end
	if num(r.XP) > 0 then x = select(2, Config.HuntValue(level, r.XP)) end
	-- A23-46: exact gold and a share of the current level's XP bar (the town people's quests)
	if num(r.GoldN) > 0 then g += math.floor(num(r.GoldN)) end
	if num(r.XPBar) > 0 then x += math.floor(Config.XPToNext(level) * num(r.XPBar)) end
	-- A23-75: what was really added (the 2x passes) is what the lines below show
	if g > 0 then g = S.ProgressionService.AddBankGold(player, g, "Quest") or g end
	if x > 0 then x = S.ProgressionService.AddXP(player, x) or x end
	if g > 0 and x > 0 then return string.format(TXT.RewardXP, def.Title, Util.FormatNumber(g), Util.FormatNumber(x)) end
	if g > 0 then return string.format(TXT.Reward, def.Title, Util.FormatNumber(g)) end
	if x > 0 then return string.format(TXT.RewardOnlyXP, def.Title, Util.FormatNumber(x)) end
	return nil
end

local function complete(player, data, id)
	local st = story(data)
	local def = DEFS[id]
	-- saved first: the quest can never be finished (or paid) twice
	st.Done[id] = true
	if st.Main.Id == id then st.Main = { Id = "" } end
	st.Subs[id] = nil
	local msg = payReward(player, def) or string.format(TXT.Done, def.Title)
	if def.Unlock == "AutoCombat" and S.CombatService and type(S.CombatService.UnlockAutoCombat) == "function" then
		pcall(S.CombatService.UnlockAutoCombat, player)
		notify(player, TXT.Unlocked, "reward", "None") -- the completion line below has the sound
	end
	notify(player, def.Finish or msg, "reward", "QuestDone")
	if def.Finish then notify(player, msg, "reward", "None") end
	-- Reward.Item (e.g. Pip1's scroll): one more line under the reward line
	if type(def.Reward) == "table" and def.Reward.Item then
		local line = grantItem(player, def.Reward.Item, def.Reward.N)
		if line then notify(player, line, "reward", "None") end
	end
	if def.Clue then notify(player, def.Clue, "info") end -- story_depth §2-1: a clue toast after the closing lines
	-- E3: a stat-free title (Reward.Title, or Reward.TitleBy by the side of this quest's own pick), once
	local r = type(def.Reward) == "table" and def.Reward or nil
	local titleId = r and (r.Title or (type(r.TitleBy) == "table" and r.TitleBy[SIDE[st.Pick[id]] or ""]) or nil)
	local titles = S.TitleService
	if type(titleId) == "string" and Config.TitleDefs[titleId] and type(titles) == "table" and type(titles.Grant) == "function" then
		local ok, new = pcall(titles.Grant, player, titleId)
		if not ok then Util.Warn(TAG, "TitleService.Grant: " .. tostring(new)) end
		if ok and new == true then notify(player, string.format(TXT.NewTitle, Config.TitleDefs[titleId].Name), "reward", "RankUp") end
	end
	-- A23-34: the blacksmith's free first weapon (M1_1 GiveWeapon = tier; paid once, LootService.GrantFirstWeapon), its
	-- own "전투력 X → Y" line after the story lines
	if def.GiveWeapon and S.LootService and type(S.LootService.GrantFirstWeapon) == "function" then
		local ok, err = pcall(S.LootService.GrantFirstWeapon, player, def.GiveWeapon)
		if not ok then Util.Warn(TAG, "GrantFirstWeapon: " .. tostring(err)) end
	end
	dirty(player)
	StoryQuestService.QuestDone:Fire(player, id)
end

-- A23-110: nothing of potions yet: no stock, no potion ever bought or drunk (the King's Hop is for those saves only)
local function noPotionYet(data)
	local st = story(data)
	if st.First.PotionBought == true or st.First.PotionUsed == true then return false end
	for _, kind in { "HP", "MP" } do
		local key = Config.PotionStockKey(kind)
		if key and num(data[key]) > 0 then return false end
	end
	return true
end

-- an Event step the player has already seen happen (obj.Past): it passes without waiting; obj.Held names a text field of the
-- save whose letters mean it is done already (an old save's quick slots hold "HP,MP,": nothing is left to put in a slot)
local function eventPast(data, obj)
	if type(obj) ~= "table" or obj.Type ~= "Event" or obj.Past ~= true then return false end
	if story(data).First[obj.Name] == true then return true end
	local held = obj.Held
	return type(held) == "string" and type(data[held]) == "string" and string.find(data[held], "%a") ~= nil
end

-- A23-110 TopUpGold: a step that opens with the player short of this much gold (carried + bank) adds the missing part to the
-- carried gold, once per step ("Choice" source: never doubled by the 2x pass). Nothing for a step that already passes.
local function topUpGold(player, data, id, track)
	local step = stepOf(player, DEFS[id], track.St)
	local want = step and math.floor(num(step.TopUpGold)) or 0
	if want <= 0 or eventPast(data, step.Obj) then return end
	local first = story(data).First
	local key = "Top" .. id .. tostring(track.St)
	if first[key] == true then return end
	first[key] = true -- saved before the gold, so it can never be paid twice
	local have = S.ProgressionService.GetTotalGold(player)
	if have < want then S.ProgressionService.AddCarriedGold(player, want - have, "Choice") end
end

-- manual = the player asked (StoryAction "Open"); a step talked through a town NPC (Npc) never pops up by itself
local function openStep(player, id, track, manual)
	local def = DEFS[id]
	local step = def and stepOf(player, def, track.St)
	if not step or not step.Panel then return end
	if step.Npc and manual ~= true then return end
	local var = varFor(getData(player), step) -- E2
	pcall(function()
		Net.Get("OpenPanel"):FireClient(player, "Story", { Id = id, St = track.St, Var = var })
	end)
end

-- the active step reached its goal: next step (saved first), or the quest is finished / waits for [받기]
local function advance(player, data, id, track)
	local def = DEFS[id]
	track.P, track.T = 0, {}
	if stays[player] then stays[player][id .. ":" .. tostring(track.St)] = nil end
	if track.St < #def.Steps then
		track.St += 1
		local nextStep = stepOf(player, def, track.St)
		if nextStep and nextStep.Start then notify(player, nextStep.Start, "info") end
		topUpGold(player, data, id, track)
		dirty(player)
		openStep(player, id, track)
		return
	end
	if def.Claim then
		track.Claim = true
		notify(player, string.format(TXT.Claim, def.Title), "good")
		dirty(player)
		return
	end
	complete(player, data, id)
end

------------------------------------------------------------------ tracks
local function tracks(data)
	local st = story(data)
	local out = {}
	if st.Main.Id ~= "" and DEFS[st.Main.Id] then table.insert(out, { Id = st.Main.Id, Track = st.Main }) end
	for id, tr in st.Subs do table.insert(out, { Id = id, Track = tr }) end
	return out
end

-- A23-110: an open step of this player's quests waits for that happening (and has not seen it before)
local function wantsEvent(player, data, name)
	for _, t in tracks(data) do
		local def, tr = DEFS[t.Id], t.Track
		local step = (not tr.Claim) and stepOf(player, def, tr.St) or nil
		local obj = step and step.Obj
		if obj and obj.Type == "Event" and obj.Name == name and not eventPast(data, obj) then return true end
	end
	return false
end

local function feed(player, ev)
	local data = getData(player)
	if not data then return end
	for _, t in tracks(data) do
		local def, tr = DEFS[t.Id], t.Track
		local step = (not tr.Claim) and stepOf(player, def, tr.St) or nil
		local obj = step and step.Obj
		if obj and obj.Type == "Trials" then
			local changed, doneAll = false, true
			for _, sub in obj.List do
				local cur = num(tr.T[sub.Key])
				if cur < sub.Count then
					local add = eventAmount(player, sub, ev)
					if add > 0 then
						cur = math.min(sub.Count, cur + add)
						tr.T[sub.Key] = cur
						changed = true
						if cur >= sub.Count and sub.Say then notify(player, sub.Say, "info") end -- one line per part done
					end
				end
				if cur < sub.Count then doneAll = false end
			end
			if doneAll then advance(player, data, t.Id, tr) elseif changed then dirty(player) end
		elseif obj and obj.Count then
			local add = eventAmount(player, obj, ev)
			if add > 0 then
				tr.P = math.min(obj.Count, num(tr.P) + add)
				if tr.P >= obj.Count then advance(player, data, t.Id, tr) else dirty(player) end
			end
		end
	end
end

local function requirementsMet(player, data, def)
	local req = def.Requires or {}
	local st = story(data)
	if def.Factions and not def.Factions[faction(player)] then return false end
	-- A23-57: the artisan guild's own quests wait for its switch (a save that is Neutral already keeps what it has)
	if def.Factions and def.Factions.Neutral and not def.Factions.Halo and not def.Factions.Horns
		and not Config.FeatureOn("NeutralFaction") then return false end
	if req.ClassChosen and data.ClassChosen ~= true then return false end
	if req.Tutorial and num(data.TutorialStep) == 0 then return false end
	-- A23-70: TutorialDone = the first mission is claimed (TutorialStep 99); NotDone = none of these quests is done yet
	if req.TutorialDone and num(data.TutorialStep) ~= TUT_DONE then return false end
	for _, gone in req.NotDone or {} do
		if st.Done[gone] then return false end
	end
	if req.Level and num(data.Level, 1) < req.Level then return false end
	-- A23-110: MaxLevel = only up to this level; NoPotionYet = no potion bought, drunk or held yet
	if req.MaxLevel and num(data.Level, 1) > req.MaxLevel then return false end
	if req.NoPotionYet and not noPotionYet(data) then return false end
	-- A23-86 Sprout Oath: Sprout = the Sprout Shield is still on (PvPService.IsRookie; unknown = still a sprout)
	if req.Sprout and stateTrue(player, "Graduated") then return false end
	-- SKL-3: Skill = "Q" / "Z" / "X" learned (its switch on and the saved slot open)
	if req.Skill then
		local skills = Config.Skills or {}
		local index = table.find(skills.Order or { "Q", "Z", "X" }, req.Skill)
		local on = req.Skill == "Q" or skills[req.Skill .. "Enabled"] == true
		if not index or not on or num(data.SkillSlots) < index then return false end
	end
	for _, need in req.Done or {} do
		if not st.Done[need] then return false end
	end
	-- E1: Requires.Pick = { Id, Is }: Is "Good" / "Evil" = that side of the saved pick (Purify / A count as Good), else the
	-- exact pick
	if type(req.Pick) == "table" then
		local pick = st.Pick[req.Pick.Id]
		if pick == nil or (pick ~= req.Pick.Is and SIDE[pick] ~= req.Pick.Is) then return false end
	end
	return data.ClassChosen == true
end

-- start the next main / newly available subs; check state / level / zone steps (1 s loop and on demand)
local function refresh(player)
	if not S.PlayerService.IsReady(player) then return end
	local data = getData(player)
	if not data then return end
	local st = story(data)
	local changed = false
	-- an old save (no story yet) that is already Lv10+ skips the chapters below its level, never later ones
	-- (story_depth E0, quest_chain rule): Lv10-24 = chapters 1-2, Lv25+ = chapters 1-3 (SQ.SkipChapters); no past
	-- rewards or choice points are paid, the next chapter starts
	if st.Main.Id == "" and next(st.Done) == nil and not st.First.Migrated and num(data.Level, 1) >= 10 then
		local upTo = 0
		for _, row in SQ.SkipChapters or {} do
			if num(data.Level, 1) >= row.Level then upTo = math.max(upTo, row.UpTo) end
		end
		for _, id in SQ.Main do
			local def = DEFS[id]
			if def and num(def.Chapter) <= upTo then st.Done[id] = true end
		end
		for _, row in SQ.SkipChapters or {} do -- A23-86: a side line of a skipped chapter (M3_5) is skipped too
			if num(data.Level, 1) >= row.Level then
				for _, sid in row.Subs or {} do st.Done[sid] = true end
			end
		end
		changed = true
	end
	st.First.Migrated = true
	-- main chain starts after the first mission is claimed
	if st.Main.Id == "" and num(data.TutorialStep) == TUT_DONE and data.ClassChosen == true then
		for _, id in SQ.Main do
			if not st.Done[id] then
				st.Main = { Id = id, St = 1, P = 0, T = {}, Claim = false }
				announceStart(player, data, DEFS[id])
				changed = true
				openStep(player, id, st.Main)
				break
			end
		end
	end
	for _, id in SQ.Subs do
		local def = DEFS[id]
		if def and not st.Done[id] and not st.Subs[id] and requirementsMet(player, data, def) then
			st.Subs[id] = { St = 1, P = 0, T = {}, Claim = false }
			announceStart(player, data, def) -- E5: a hidden sub stays secret
			if def.Pop then openStep(player, id, st.Subs[id]) end -- A23-70: the card opens by itself, once
			changed = true
		elseif st.Subs[id] and def.Factions and not def.Factions[faction(player)] then
			st.Subs[id] = nil -- faction changed: the faction-only sub leaves (A6 / design 6-3)
			changed = true
		end
	end
	-- state-driven steps
	for _, t in tracks(data) do
		local def, tr = DEFS[t.Id], t.Track
		local step = (not tr.Claim) and stepOf(player, def, tr.St) or nil
		local obj = step and step.Obj
		if obj then
			local done = false
			if obj.Type == "State" then
				done = stateTrue(player, obj.Key)
			elseif obj.Type == "Event" then
				done = eventPast(data, obj)
			elseif obj.Type == "Level" then
				done = levelReached(data, obj)
				if not done then changed = true end -- the row shows "(지금 LvN)"
			elseif obj.Type == "Enter" then
				done = zoneMatches(player, obj.Zone, currentZone(player))
			elseif obj.Type == "Near" then
				-- standing next to a landmark (e.g. the Crossroads fountain), checked by the 1 s loop
				local spot = landmark(obj.Spot)
				local root = Util.GetRoot(player)
				local inside = spot ~= nil and root ~= nil and (obj.Zone == nil or zoneMatches(player, obj.Zone, currentZone(player)))
					and Util.FlatDistance(root.Position, spot) <= (obj.Radius or 20)
				if num(obj.Stay) > 0 then
					-- E4: stay inside for obj.Stay seconds in one go (leaving starts again); P = whole seconds for the row
					local key = t.Id .. ":" .. tostring(tr.St)
					local mine = stays[player]
					if inside then
						if not mine then
							mine = {}
							stays[player] = mine
						end
						mine[key] = mine[key] or os.clock()
						local held = math.min(obj.Stay, math.floor(os.clock() - mine[key]))
						if held ~= num(tr.P) then
							tr.P = held
							changed = true
						end
						done = held >= obj.Stay
					else
						if mine then mine[key] = nil end
						if num(tr.P) ~= 0 then
							tr.P = 0
							changed = true
						end
					end
				else
					done = inside
				end
			end
			if done then advance(player, data, t.Id, tr) end
		end
	end
	-- user 2026-10-05: no window or waiting choice card ever pauses auto combat ("아이템 열어도 그대로 자동 전투"),
	-- and monsters keep attacking as usual; the old ChoicePending flag is cleared for saves/servers that set it
	if player:GetAttribute("ChoicePending") == true then player:SetAttribute("ChoicePending", false) end
	-- A23-110: tells the client a step waits for a potion drink (it then lets a full HP / MP bar be used: the practice sip)
	local sipAttr = Config.FirstKO and Config.FirstKO.SipAttr
	if type(sipAttr) == "string" then
		local want = wantsEvent(player, data, "PotionUsed")
		if player:GetAttribute(sipAttr) ~= want then player:SetAttribute(sipAttr, want) end
	end
	if changed then dirty(player) end
end

-- A23-34: ShopService runs this when the anvil opens, so an active M1_1 finishes (and hands over its weapon) before
-- the weapon shop shows
function StoryQuestService.Refresh(player)
	refresh(player)
end

local function stepsSum(data)
	local n = 0
	for _, t in tracks(data) do n += num(t.Track.St) end
	return n
end

-- A23-110: a named happening (Config.StoryQuests.Events: FirstKO, PotionBought, PotionUsed) another service reports. It is
-- saved first (data.Story.First[name]), so an Event step that opens later with Past passes at once, then the open step that
-- waits for it moves on (the next one is checked right away). Unknown names / not-ready players do nothing. Returns true when
-- a step moved.
function StoryQuestService.Event(player, name, info)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(name) ~= "string" then return false end
	if SQ.Events == nil or SQ.Events[name] ~= true then return false end
	if not S.PlayerService.IsReady(player) then return false end
	local data = getData(player)
	if not data then return false end
	story(data).First[name] = true
	local moved = false
	for _, t in tracks(data) do
		local def, tr = DEFS[t.Id], t.Track
		local step = (not tr.Claim) and stepOf(player, def, tr.St) or nil
		local obj = step and step.Obj
		if obj and obj.Type == "Event" and obj.Name == name then
			advance(player, data, t.Id, tr)
			moved = true
		end
	end
	if moved then
		-- the steps that pass at once (an Event step whose happening was seen before) follow each other without waiting for
		-- the 1 s loop; the sum of the steps stops changing when nothing more passes
		for _ = 1, 8 do
			local before = stepsSum(data)
			local ok, err = pcall(refresh, player)
			if not ok then
				Util.Warn(TAG, "Event refresh: " .. tostring(err))
				break
			end
			if stepsSum(data) == before then break end
		end
	end
	return moved
end

-- Studio test aids (Main's DebugCommand "StorySub" / "StoryDone", built inside its IsStudio block only): start a Sub quest at a
-- step (what the step needs at its start is done as when it opens: TopUpGold; steps that pass at once pass), and mark one
-- done. No reward, no notice, no QuestDone. Both return "ok" or a short reason.
function StoryQuestService.DebugSub(player, id, step)
	local def = DEFS[id]
	if not def or def.Kind ~= "Sub" then return "no such sub quest " .. tostring(id) end
	local data = getData(player)
	if not data then return "no data" end
	local n = math.floor(num(step, 1))
	if n < 1 or n > #def.Steps then return string.format("%s has steps 1-%d", id, #def.Steps) end
	local st = story(data)
	st.Done[id] = nil
	local track = { St = n, P = 0, T = {}, Claim = false }
	st.Subs[id] = track
	topUpGold(player, data, id, track)
	dirty(player)
	local ok, err = pcall(refresh, player)
	if not ok then Util.Warn(TAG, "DebugSub refresh: " .. tostring(err)) end
	return "ok"
end

function StoryQuestService.DebugDone(player, id)
	local def = DEFS[id]
	if not def then return "no such quest " .. tostring(id) end
	local data = getData(player)
	if not data then return "no data" end
	local st = story(data)
	st.Done[id] = true
	st.Subs[id] = nil
	if st.Main.Id == id then st.Main = { Id = "" } end
	dirty(player)
	return "ok"
end

-- A23-110: true while an open step of this player's quests waits for that happening (and has not seen it before)
function StoryQuestService.Wants(player, name)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(name) ~= "string" then return false end
	local data = getData(player)
	if not data then return false end
	return wantsEvent(player, data, name)
end

-- A23-110: the step (1-based) a started quest is at, nil = not started, done or waiting for [Claim]. Game dev 2's personal King
-- reads it (Config.FirstKO.Quest / Step / RematchStep)
function StoryQuestService.CurrentStep(player, id)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(id) ~= "string" then return nil end
	local data = getData(player)
	if not data then return nil end
	local st = story(data)
	local tr = (st.Main.Id == id) and st.Main or st.Subs[id]
	if type(tr) ~= "table" or tr.Claim == true or st.Done[id] then return nil end
	return tr.St
end

------------------------------------------------------------------ quest list rows (QuestService.publish)
-- 3rd idea round #1: a step text without its count ('King Slimes %d/%d' -> 'King Slimes', 'The shard's test %d/3' ->
-- 'The shard's test', 'Spy by the woods' edge %d/%d s' -> 'Spy by the woods' edge' + unit 's')
local function countless(template)
	local unit = nil
	local s, n = string.gsub(template, "%s*%%d/%%d%s+s$", "")
	if n > 0 then unit = "s" end
	s = string.gsub(s, "%s*%%d/%%d", "")
	s = string.gsub(s, "%s*%%d/%d+", "")
	return s, unit
end

local function rowFor(player, data, id, track)
	local def = DEFS[id]
	local step = stepOf(player, def, track.St)
	local obj = step and step.Obj or {}
	local text, progress, target = step and step.Text or def.Title, 0, 1
	-- A23-86 Call of the Woods: from the Alt level the row names the other kind too
	local template = step and step.Text
	if step and type(step.AltText) == "string" and type(obj.Alt) == "table" and num(data.Level, 1) >= num(obj.Alt.MinLevel, 1) then
		template = step.AltText
	end
	if track.Claim then
		text = string.format(TXT.Claim, def.Title)
		progress, target = 1, 1
	elseif obj.Type == "Trials" then
		local done = 0
		for _, sub in obj.List do
			if num(track.T[sub.Key]) >= sub.Count then done += 1 end
		end
		text = string.format(step.Text, done)
		progress, target = done, #obj.List
	elseif obj.Type == "Level" then
		text = string.format(step.Text, math.floor(num(data.Level, 1)))
	elseif obj.Type == "Near" and num(obj.Stay) > 0 then
		progress, target = math.floor(num(track.P)), math.floor(obj.Stay) -- E4: "%d/%d s"
		local okF, f = pcall(string.format, step.Text, progress, target)
		text = okF and f or step.Text
	elseif obj.Key == "OwnIron" then
		text = string.format(step.Text, Util.FormatNumber(math.floor(num(data.CarriedGold) + num(data.BankGold))))
	elseif obj.Count then
		progress, target = math.floor(num(track.P)), obj.Count
		local okF, f = pcall(string.format, template, progress, target)
		text = okF and f or template
	end
	-- 3rd idea round #1: the HUD draws a ShowProgress row's numbers itself ('King Slimes 0/2 0/2' on PC), so the text
	-- loses its '%d/%d' (a '%d/%d s' row keeps the unit as ProgressUnit)
	local unit = nil
	if target > 1 and not track.Claim and step and type(step.Text) == "string" then
		text, unit = countless(template)
	end
	-- A23-71: a step that needs a skill hit (or a trial list still missing one) before the first skill says when it comes
	if not track.Claim and needsSkill(obj, track) and not Config.SkillLearned(data.SkillSlots, data.Level, data.Rebirths) then
		text = string.format(TXT.SkillLater, text, math.floor(num((Config.Skills.Unlock or {}).Q, 5)))
	end
	return {
		Id = "story:" .. id, Kind = def.Kind, Pinned = def.Kind == "Main", TutorialStep = TUT_DONE,
		Text = Config.Plural(text), Progress = progress, Target = target, -- raw '{Auto}' tokens (client fills them)
		ProgressUnit = unit, -- "s": a seconds row (its numbers are shown by the HUD)
		ShortName = (step and step.ShortName) or def.ShortName, -- 검수 2026-10-07: the phone HUD quest row (<= 14)
		RewardGold = 0, RewardXP = 0,
		CanClaim = track.Claim == true, ShowProgress = target > 1 and not track.Claim,
		-- Npc (A23-46): the town NPC this step is talked through (game dev 1: '!' over it, the row guides there)
		Story = { Id = id, St = track.St, Panel = step and step.Panel == true or nil, Guide = step and step.Guide or nil,
			Npc = (not track.Claim) and step and step.Npc or nil, Var = (not track.Claim) and varFor(data, step) or nil },
	}
end

-- the pinned main row (nil when no main is active)
function StoryQuestService.MainRow(player, data)
	local st = story(data)
	if st.Main.Id == "" or not DEFS[st.Main.Id] then return nil end
	return rowFor(player, data, st.Main.Id, st.Main)
end

local function visible(player, def)
	if def.Show == "GooseSoon" then
		local gs = workspace:FindFirstChild("GameState") or ReplicatedStorage:FindFirstChild("GameState")
		local ok, state = pcall(Net.GameState)
		gs = ok and state or gs
		if not gs then return false end
		if gs:GetAttribute("GooseActive") == true then return true end
		local nextAt = num(gs:GetAttribute("GooseNextAt"))
		return nextAt > 0 and nextAt - Util.Now() <= 180
	end
	return true
end

-- A23-81 quest window (게임성 개발 3): the book lists QuestService.publish sends next to the rows. Done = the finished
-- story quests, the newest first (the main chain backwards, then the subs backwards), at most Config.QuestBook.DoneMax,
-- as "story:<id>" (the client shows the Title). Available = subs that only wait for a level (every other requirement
-- met, not hidden, not started) as { Id, Kind = "Sub", Level, Text = "<Title> · Opens at Lv N" }, lowest level first,
-- plus a sub that is ready but not started yet (the 1 s refresh starts it), at most AvailableMax. The main chain has no
-- level gate (each next main starts at once), so no main is listed.
function StoryQuestService.BookRows(player, data)
	local QB = Config.QuestBook or {}
	local st = story(data)
	local maxDone = math.floor(num(QB.DoneMax, 40))
	local done = {}
	for _, list in { SQ.Main, SQ.Subs } do
		for i = #list, 1, -1 do
			if #done >= maxDone then break end
			if st.Done[list[i]] and DEFS[list[i]] then table.insert(done, "story:" .. list[i]) end
		end
	end
	local avail = {}
	local level = num(data.Level, 1)
	for _, id in SQ.Subs do
		local def = DEFS[id]
		-- a situational sub's check (the goose) that fails counts as not shown: one quest never empties the book
		local okVis, shown = pcall(visible, player, def)
		if def and not def.Hidden and not st.Done[id] and not st.Subs[id] and okVis and shown then
			local need = math.floor(num(type(def.Requires) == "table" and def.Requires.Level))
			if need > level then
				-- the same requirements at the level it waits for (a read-only view of the save)
				if requirementsMet(player, setmetatable({ Level = need }, { __index = data }), def) then
					table.insert(avail, { Id = "story:" .. id, Kind = "Sub", Level = need,
						Text = string.format((QB.Text or {}).OpensAt or "%s · Opens at Lv %d", tostring(def.Title), need) })
				end
			elseif requirementsMet(player, data, def) then
				table.insert(avail, { Id = "story:" .. id, Kind = "Sub" })
			end
		end
	end
	table.sort(avail, function(a, b)
		if (a.Level or 0) ~= (b.Level or 0) then return (a.Level or 0) < (b.Level or 0) end
		return a.Id < b.Id
	end)
	for i = #avail, math.floor(num(QB.AvailableMax, 10)) + 1, -1 do avail[i] = nil end
	return { Available = avail, Done = done }
end

-- sub rows, best first, at most Config.StoryQuests.MaxSubs (quest_volume §2-6: 3; the HUD shows 2, the open list all):
-- 0 = a claim or a Talk / Choice card waiting mid-quest (past step 1), 1 = situational (Show), 2 = started (past step 1
-- or with progress) or S0, 2.5 = a faction town-NPC offer (below the subs in progress, above the other offers), 3 = a new
-- offer waiting at its first card, 4 = the rest; within a rank the newer quest
-- (later in StoryQuests.Subs) first. With A23-56's many subs a sub in progress is never pushed off by new offers or
-- older background subs, and the order index keeps the rows from swapping between refreshes (table.sort is not stable).
-- zone_check_halo #19: a faction town-NPC offer (a sub with Factions whose step waits at its Npc) counts as rank 2.5, so the
-- new Halo / Horns town quest is not pushed out by the other offers, yet never pushes out a sub the player already started
-- (검수 3a2111a0: an offer not yet taken must not push a sub in progress out of the three rows). With Config.StoryQuests.SendAllSubs the rows past
-- MaxSubs are sent too, each marked More = true: the HUD draws only the rows without More (the top MaxSubs), the quest window
-- (QuestBook 'In progress') lists all of them, so no active sub is missing from both. Off = exactly MaxSubs rows, as before.
function StoryQuestService.SubRows(player, data)
	local st = story(data)
	local rows = {}
	for order, id in SQ.Subs do
		local tr = st.Subs[id]
		local def = DEFS[id]
		-- E5: a hidden sub shows once it is found (past its first step, or waiting for [Claim])
		local found = tr ~= nil and (tr.Claim or num(tr.St, 1) > 1)
		if tr and def and (tr.Claim or visible(player, def)) and (not def.Hidden or found) then
			-- before the first mission is accepted only S0 shows (A23-3: one goal at a time)
			if num(data.TutorialStep) ~= 0 or id == "S0" then
				local row = rowFor(player, data, id, tr)
				local step = (not tr.Claim) and stepOf(player, def, tr.St) or nil
				local waiting = step ~= nil and step.Panel == true -- a Talk / Choice card waits
				local started = num(tr.St, 1) > 1 or num(tr.P) > 0 or (type(tr.T) == "table" and next(tr.T) ~= nil)
				local townOffer = waiting and type(def.Factions) == "table" and step.Npc ~= nil
				row.Rank = ((tr.Claim or (waiting and started)) and 0) or (def.Show and 1)
					or ((started or id == "S0") and 2) or (townOffer and 2.5) or (waiting and 3) or 4
				row.Order = order
				table.insert(rows, row)
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.Rank ~= b.Rank then return a.Rank < b.Rank end
		return a.Order > b.Order
	end)
	local out = {}
	local cap = math.max(0, math.floor(num(SQ.MaxSubs, 3)))
	for i = 1, SQ.SendAllSubs == true and #rows or math.min(#rows, cap) do
		rows[i].Rank, rows[i].Order = nil, nil
		if i > cap then rows[i].More = true end -- past the HUD's rows: the quest window only
		table.insert(out, rows[i])
	end
	return out
end

-- [받기] on a story row (QuestService.onClaimQuest passes "story:<id>")
function StoryQuestService.Claim(player, id)
	local data = getData(player)
	if not data or type(id) ~= "string" then return end
	local st = story(data)
	local tr = (st.Main.Id == id) and st.Main or st.Subs[id]
	if not tr or tr.Claim ~= true or st.Done[id] then return end
	tr.Claim = false
	complete(player, data, id)
end

------------------------------------------------------------------ StoryAction (Talk / Choose / Open)
-- A23-64 ② (zone_check_halo #39, 검수 2026-10-10): after a good / evil pick, Fx "Afterglow" { UserId, Side = "Good" |
-- "Evil", Seconds, Private } so game dev 1 draws Seconds of round gold sparkles (Good) / soft purple smoke (Evil) at the
-- chooser's feet. To every client; in a PvP area (ZoneService.IsPvPZone: a PvP zone or the Crown Pit; unknown = PvP)
-- only to the chooser (Private = true). from = "Story" | "Card" | "Finisher" (Config.Afterglow.From); any other side
-- (a card's "None") never glows.
local function afterglow(player, side, from)
	local A = Config.Afterglow
	if type(A) ~= "table" or A.Enabled ~= true or (side ~= "Good" and side ~= "Evil") then return end
	if type(A.From) == "table" and A.From[from] ~= true then return end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return end
	local zones = S.ZoneService
	local okZ, pvp = false, nil
	if type(zones) == "table" and type(zones.IsPvPZone) == "function" then okZ, pvp = pcall(zones.IsPvPZone, player) end
	local private = not okZ or pvp ~= false
	local payload = { UserId = player.UserId, Side = side, Seconds = math.max(1, num(A.Seconds, 60)), Private = private }
	local ok, err = pcall(Net.Fx, private and player or nil, "Afterglow", payload)
	if not ok then Util.Warn(TAG, "afterglow: " .. tostring(err)) end
end

-- (player, "Good" | "Evil", from) for another service's good / evil pick later (e.g. the job board when it is on)
StoryQuestService.Afterglow = afterglow

-- sound_spec 2026-10-07 §4-1: the moment of a story pick (the client plays Purify / Devour on it, never on a score
-- change): Fx "Choice" { Option = "Good" | "Evil" } to the picker (a Neutral A = Good, B = Evil)
local function choiceFx(player, option)
	local ok, err = pcall(Net.Fx, player, "Choice", { Option = option })
	if not ok then Util.Warn(TAG, "choice fx: " .. tostring(err)) end
	afterglow(player, option, "Story") -- A23-64 ②: every story pick, a 0-point one too (A23-70 Lunch1)
end

-- A23-58 (user 2026-10-06, every good / evil pick): my side's own score only. Halo: Good = Honor +pts, Evil = Honor
-- -pts; Horns: Evil = Infamy +pts, Good = Infamy -pts; never below 0, the other side's score never moves. A rank the
-- lower score loses (Config.GetTitle) gets one line. PvP fame (GrantFame) and the weekly boards are not touched.
local function pickScore(player, f, option, pts)
	if pts <= 0 then return end
	local stat = f == "Halo" and "Honor" or "Infamy"
	if (f == "Halo") == (option == "Good") then
		S.PlayerService.AddStat(player, stat, pts)
		notify(player, string.format(option == "Good" and TXT.Good or TXT.Evil, pts), "good")
		return
	end
	local data = getData(player)
	local have = math.max(0, math.floor(num(data and data[stat])))
	local take = math.min(have, pts)
	if take <= 0 then
		-- 3rd idea round #5: nothing to take (A23-58 floor), but the pick still answers: no number, the shard leans
		notify(player, (f == "Halo" and TXT.OffSideHaloZero or TXT.OffSideHornsZero) .. " "
			.. (option == "Good" and TXT.LeanGood or TXT.LeanEvil), "info")
		return
	end
	S.PlayerService.SetStat(player, stat, have - take)
	notify(player, string.format(f == "Halo" and TXT.OffSideHalo or TXT.OffSideHorns, take), "info")
	local function rank(score)
		local _, r = Config.GetTitle(f, f == "Halo" and score or 0, f == "Horns" and score or 0)
		return r
	end
	if rank(have - take) < rank(have) then
		notify(player, f == "Halo" and TXT.RankDownHalo or TXT.RankDownHorns, "info")
	end
end

-- E6: the picked side's own reward (side "Good" | "Evil"; a Neutral A takes Good's, B takes Evil's): an item or potions
-- through LootService.GrantItem (its caps and full notices) and gold to the bank, then one line saying what came
local function payChoice(player, obj, side)
	local r = type(obj[side]) == "table" and obj[side].Reward or nil
	if type(r) ~= "table" then return end
	local parts = {}
	local id = r.Item or r.Potion
	local loot = S.LootService
	if type(id) == "string" and type(loot) == "table" and type(loot.GrantItem) == "function" then
		local ok, res = pcall(loot.GrantItem, player, id, math.floor(num(r.N, 1)))
		if not ok then Util.Warn(TAG, "GrantItem: " .. tostring(res)) end
		local given = ok and math.floor(num(res)) or 0
		if given > 0 then
			local item = Config.Loot.Items[id]
			local name = (item and item.Name) or Config.Loot.Text.Potion[id] or id
			table.insert(parts, given > 1 and string.format(Config.Loot.Text.GotN, name, given)
				or string.format(Config.Loot.Text.Got, name))
		end
	end
	local gold = math.floor(num(r.Gold))
	if gold > 0 then
		-- A23-75 review 2026-10-08 (검수 3rd look): a pick's gold is "Choice", never 2x (many Evil picks are gold: a
		-- paying child must not gain more from one side, GDD §0 / A23-70); the quest's own reward stays "Quest"
		gold = S.ProgressionService.AddBankGold(player, gold, "Choice") or gold
		table.insert(parts, string.format(TXT.ChoiceGold, Util.FormatNumber(gold)))
	end
	if #parts > 0 then notify(player, table.concat(parts, " · "), "reward", "None") end -- the pick's own Choice sound
end

-- E2 (story_depth §7): a real pick (its Choice carries points) on the other side from the last real pick gets one kind
-- line; its side is saved either way (data.Story.LastSide). 0-point picks (easter eggs) never count.
local function changedMind(player, st, obj, pick)
	local side = SIDE[pick]
	if side == nil or (num(obj.Good and obj.Good.Points) <= 0 and num(obj.Evil and obj.Evil.Points) <= 0) then return end
	if st.LastSide ~= nil and st.LastSide ~= side then
		notify(player, side == "Good" and TXT.ChangedGood or TXT.ChangedEvil, "info")
	end
	st.LastSide = side
end

-- 10/08 Play check (게임성 개발 1): while the story card is open the client keeps only the newest toast
-- (UIKit NOTIFY.ToastCap), and the pick's answer came first - the gold line and the step's "done!" pushed it off at
-- once. The answer (A23-70: the other person answers) now goes last, ReplyAfter s after the step moved on (the card
-- has closed by then): the newest line, so it stays.
local REPLY_AFTER = 0.35
local function replyLater(player, text)
	task.delay(REPLY_AFTER, function()
		if player.Parent == Players then notify(player, text, "good", "None") end
	end)
end

local function onStoryAction(player, id, action, option, ...)
	if select("#", ...) ~= 0 then return end
	if type(id) ~= "string" or type(action) ~= "string" or (option ~= nil and type(option) ~= "string") then return end
	if not S.PlayerService.IsReady(player) or player:GetAttribute("ClassChosen") ~= true then return end
	if not Util.RateLimit(player, "StoryAction", (Config.RateLimits and Config.RateLimits.StoryAction) or 0.4) then return end
	local def = DEFS[id]
	local data = getData(player)
	if not def or not data then return end
	local st = story(data)
	local tr = (st.Main.Id == id) and st.Main or st.Subs[id]
	if not tr or tr.Claim then return end
	local step = stepOf(player, def, tr.St)
	if not step or not step.Panel then return end
	if step.Npc and not npcNear(player, step.Npc) then return end -- A23-46: talked through the NPC, standing next to it
	local obj = step.Obj
	if action == "Open" then
		openStep(player, id, tr, true)
	elseif action == "Talk" and obj.Type == "Talk" then
		advance(player, data, id, tr)
	elseif action == "Choose" and obj.Type == "Choice" then
		local f = faction(player)
		local reply = nil -- the other person's answer, sent after the step moved on (replyLater)
		if f == "Halo" or f == "Horns" then
			if option ~= "Good" and option ~= "Evil" then return end
			local pick = obj[option]
			st.Pick[id] = pick.Pick or option -- saved before the points
			choiceFx(player, option)
			local pts = math.floor(num(pick.Points))
			if pts > 0 then
				pickScore(player, f, option, pts)
			elseif not pick.Reply then
				notify(player, option == "Good" and TXT.LeanGood or TXT.LeanEvil, "info") -- E5: no "+0", the shard leans
			end
			reply = pick.Reply -- A23-70: the other person answers (last, replyLater)
			changedMind(player, st, obj, st.Pick[id])
			payChoice(player, obj, option)
		else
			if option ~= "A" and option ~= "B" then return end
			st.Pick[id] = option -- Neutral: recorded only (no good/evil score, A6)
			choiceFx(player, option == "A" and "Good" or "Evil")
			local side = obj[option == "A" and "Good" or "Evil"]
			if type(side) == "table" and side.Reply then
				reply = side.Reply -- A23-70: the other person answers (last, replyLater)
			else
				notify(player, TXT.Recorded, "info")
			end
			changedMind(player, st, obj, option)
			payChoice(player, obj, option == "A" and "Good" or "Evil")
		end
		if isTownPick(id) then
			st.TownLast, st.TownFaction = id, faction(player) -- A23-64 ①: the townsfolk remember this town pick (saved; its side = SIDE[st.Pick[id]])
			publishTownPick(player, st)
		end
		StoryQuestService.Picked:Fire(player, id, st.Pick[id]) -- A23-79: My Way
		advance(player, data, id, tr)
		if type(reply) == "string" then replyLater(player, reply) end
	end
end

------------------------------------------------------------------ signals
local function onMonsterKilled(player, info)
	if type(info) ~= "table" or not (typeof(player) == "Instance" and player:IsA("Player")) then return end
	feed(player, { Kind = "Kill", Info = info })
end

local function onReleased(player, info)
	if type(info) ~= "table" then return end
	feed(player, { Kind = "Skill", Info = info })
end

local function onGoldEarned(player, amount, source)
	feed(player, { Kind = "Gold", Amount = amount, Source = source })
end

local function onGooseFinished(result, counts)
	if type(counts) ~= "table" then return end
	for p, c in counts do
		if typeof(p) == "Instance" and p:IsA("Player") and num(c) > 0 then
			local data = getData(p)
			local st = data and story(data)
			local f = faction(p)
			-- first rescue / poach ever: +1 honor (Halo) or infamy (Horns)
			if st and not st.First.Goose and (f == "Halo" or f == "Horns") then
				st.First.Goose = true
				local pts = (DEFS.S1 and DEFS.S1.FirstPoints) or 1
				S.PlayerService.AddStat(p, f == "Halo" and "Honor" or "Infamy", pts)
				notify(p, string.format(f == "Halo" and TXT.GooseFirstHalo or TXT.GooseFirstHorns, pts), "good")
			end
			feed(p, { Kind = "Goose" })
		end
	end
end

-- zone_check_halo #22 / #25 / #30: a town NPC's "Talk" prompt (TownNpcs: attribute StoryNpcId) opens the dialogue of the player's
-- quest whose CURRENT step is a Panel step talked through that NPC (the main quest first, then the subs, newest first), like
-- a tap on its row (StoryAction "Open"). Returns the quest id it opened, or nil (nothing to say to this player right now).
function StoryQuestService.TalkToNpc(player, npcId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(npcId) ~= "string" then return nil end
	if not S.PlayerService.IsReady(player) or player:GetAttribute("ClassChosen") ~= true then return nil end
	local data = getData(player)
	if not data then return nil end
	local st = story(data)
	local order = {}
	if st.Main.Id ~= "" then table.insert(order, { st.Main.Id, st.Main }) end
	for i = #SQ.Subs, 1, -1 do
		local id = SQ.Subs[i]
		if st.Subs[id] then table.insert(order, { id, st.Subs[id] }) end
	end
	for _, entry in order do
		local id, tr = entry[1], entry[2]
		local def = DEFS[id]
		local step = def and not tr.Claim and stepOf(player, def, tr.St) or nil
		if step and step.Panel == true and step.Npc == npcId and npcNear(player, npcId) then
			openStep(player, id, tr, true)
			return id
		end
	end
	return nil
end

local function connect(serviceName, signalName, fn)
	local service = S[serviceName]
	local signal = service and service[signalName]
	if type(signal) == "table" and type(signal.Connect) == "function" then
		signal:Connect(fn)
	else
		Util.Warn(TAG, "missing signal " .. serviceName .. "." .. signalName)
	end
end

function StoryQuestService.Init(registry)
	S = registry
end

function StoryQuestService.Start()
	Net.Get("StoryAction").OnServerEvent:Connect(onStoryAction)
	connect("MonsterService", "MonsterKilled", onMonsterKilled)
	connect("CombatService", "Released", onReleased)
	connect("ProgressionService", "GoldEarned", onGoldEarned)
	connect("GooseService", "GooseFinished", onGooseFinished)
	connect("ZoneService", "ZoneChanged", function(player) pcall(refresh, player) end)
	connect("ProgressionService", "LeveledUp", function(player) pcall(refresh, player) end)
	connect("PlayerService", "PlayerReady", function(player)
		local data = getData(player)
		if data then
			sanitize(data)
			publishTownPick(player, story(data)) -- A23-64 ①: TownPick from the save (sanitize backfilled it)
		end
		pcall(refresh, player)
	end)
	-- A23-64 ①: an Altar / rebirth faction switch: the old faction's town pick goes quiet (back again: it is voiced again).
	-- Looked up softly like the card hooks below (a world without FactionService connects nothing, with no warning)
	local factions = S.FactionService
	if type(factions) == "table" and type(factions.FactionChanged) == "table" then
		factions.FactionChanged:Connect(function(player)
			local ok, err = pcall(function()
				local data = getData(player)
				if data then publishTownPick(player, story(data)) end
			end)
			if not ok then Util.Warn(TAG, "FactionChanged: " .. tostring(err)) end
		end)
	end
	-- A23-64 ②: the other good / evil picks glow too: a choice card (ChoiceCard.Picked side "Good" | "Evil") and the King
	-- Slime finisher card (FinisherService.Picked "Help" = Good, "Tickle" = Evil); "None" (time up / left) never glows.
	-- Optional services: a server (or an offline world) without them connects nothing, with no warning.
	local cards = S.ChoiceCard
	if type(cards) == "table" and type(cards.Picked) == "table" then
		cards.Picked:Connect(function(player, _, side) afterglow(player, side, "Card") end)
	end
	local finisher = S.FinisherService
	if type(finisher) == "table" and type(finisher.Picked) == "table" then
		finisher.Picked:Connect(function(player, pick)
			afterglow(player, (pick == "Help" and "Good") or (pick == "Tickle" and "Evil") or nil, "Finisher")
		end)
	end
	-- the town NPCs' "Talk" prompts (the service is looked up softly: a world without it simply has no NPC to talk to)
	local okPrompts, prompts = pcall(game.GetService, game, "ProximityPromptService")
	if okPrompts and prompts and prompts.PromptTriggered then
		prompts.PromptTriggered:Connect(function(prompt, player)
			local npcId = typeof(prompt) == "Instance" and prompt:GetAttribute("StoryNpcId") or nil
			if type(npcId) ~= "string" or typeof(player) ~= "Instance" then return end
			if not Util.RateLimit(player, "StoryNpcTalk", (Config.RateLimits and Config.RateLimits.StoryAction) or 0.4) then return end
			local ok, err = pcall(StoryQuestService.TalkToNpc, player, npcId)
			if not ok then Util.Warn(TAG, "TalkToNpc: " .. tostring(err)) end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, p in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(refresh, p)
				if not ok then Util.Warn(TAG, "refresh: " .. tostring(err)) end
			end
			for p in stays do
				if p.Parent == nil then stays[p] = nil end -- E4 counts of players who left
			end
		end
	end)
	print("[StoryQuestService] started")
end

return StoryQuestService
