-- StoryQuestService.luau : "부서진 왕관 이야기" story quests (Config.StoryQuests; design
-- docs/design/quest_chain_2026-10-06.md, user OK 2026-10-06). One main chain after the first mission
-- (TutorialStep 99) + automatically accepted sub quests (S0 "내 싸움을 배우는 왕관 조각" right after the class pick).
-- Server-authoritative: progress comes only from server signals / server state; the client may only confirm a
-- Talk page or pick a Choice option of the step that is active right now (remote "StoryAction"). A finished step is
-- saved before any reward is paid, so nothing can be paid twice. QuestService puts the rows into the quest list.
--
-- data.Story = { Main = { Id, St, P, T, Claim } | { Id = "" }, Subs = { [id] = { St, P, T, Claim } },
--                Done = { [id] = true }, Pick = { [id] = "Good" | "Evil" | "A" | "B" | "Purify" | "Devour" },
--                First = { [key] = true } }     (St = 1-based step, P = progress, T = trial progress table)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local StoryQuestService = {}
local S = nil
local TAG = "StoryQuestService"
local SQ = Config.StoryQuests
local TXT = SQ.Text
local DEFS = SQ.Defs
local TUT_DONE = Config.Tutorial.Steps.Done -- 99
local MAIN_INDEX = {}
for i, id in SQ.Main do MAIN_INDEX[id] = i end
local TICK = 1

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

local function notify(player, text, kind)
	if type(text) == "string" and text ~= "" then pcall(Net.Notify, player, text, kind or "info") end
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

local function linesFor(player, step)
	local lines = step.Lines or {}
	return lines[faction(player)] or lines.All or {}
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

local function ownsIron(player)
	local mask = math.floor(num(player:GetAttribute("WeaponOwnedMask"), 1))
	return bit32.btest(mask, bit32.lshift(1, 2)) or num(player:GetAttribute("WeaponTier"), 1) >= 3
end

local function stateTrue(player, key)
	if key == "BlacksmithVisited" then return player:GetAttribute("BlacksmithVisited") == true end
	if key == "AutoOn" then return player:GetAttribute("AutoCombatEnabled") == true end
	if key == "OwnIron" then return ownsIron(player) end
	return false
end

-- how much one event moves an objective (0 = not this objective)
local function eventAmount(player, obj, ev)
	local t = obj.Type
	if ev.Kind == "Kill" then
		local info = ev.Info
		if info.Personal == true then return 0 end
		if t == "WarPoints" then return math.max(0, num(info.WarPoints)) end
		if t ~= "Kill" and t ~= "BasicKill" and t ~= "SafeKill" and t ~= "AutoKill" then return 0 end
		if obj.Kind and info.Kind ~= obj.Kind then return 0 end
		if obj.Zone and info.ZoneId ~= obj.Zone then return 0 end
		if obj.Golden and info.Golden ~= true then return 0 end
		if obj.Near then
			local spot = SQ.Landmarks[obj.Near]
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

------------------------------------------------------------------ rewards / finishing
local function payReward(player, def)
	local r = def.Reward
	if type(r) ~= "table" then return nil end
	local level = math.max(1, math.floor(num(player:GetAttribute("Level"), 1)))
	local g, x = 0, 0
	if num(r.Gold) > 0 then g = select(1, Config.HuntValue(level, r.Gold)) end
	if num(r.XP) > 0 then x = select(2, Config.HuntValue(level, r.XP)) end
	if g > 0 then S.ProgressionService.AddBankGold(player, g, "Quest") end
	if x > 0 then S.ProgressionService.AddXP(player, x) end
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
		notify(player, TXT.Unlocked, "reward")
	end
	notify(player, def.Finish or msg, "reward")
	if def.Finish then notify(player, msg, "reward") end
	dirty(player)
end

local function openStep(player, id, track)
	local def = DEFS[id]
	local step = def and stepOf(player, def, track.St)
	if not step or not step.Panel then return end
	pcall(function()
		Net.Get("OpenPanel"):FireClient(player, "Story", { Id = id, St = track.St })
	end)
end

-- the active step reached its goal: next step (saved first), or the quest is finished / waits for [받기]
local function advance(player, data, id, track)
	local def = DEFS[id]
	track.P, track.T = 0, {}
	if track.St < #def.Steps then
		track.St += 1
		local nextStep = stepOf(player, def, track.St)
		if nextStep and nextStep.Start then notify(player, nextStep.Start, "info") end
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
	if req.ClassChosen and data.ClassChosen ~= true then return false end
	if req.Tutorial and num(data.TutorialStep) == 0 then return false end
	if req.Level and num(data.Level, 1) < req.Level then return false end
	for _, need in req.Done or {} do
		if not st.Done[need] then return false end
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
	-- an old save that is already Lv10+ skips chapters 1-2 (no past rewards or choice points are paid)
	if st.Main.Id == "" and next(st.Done) == nil and not st.First.Migrated and num(data.Level, 1) >= 10 then
		for _, id in SQ.Main do st.Done[id] = true end
		changed = true
	end
	st.First.Migrated = true
	-- main chain starts after the first mission is claimed
	if st.Main.Id == "" and num(data.TutorialStep) == TUT_DONE and data.ClassChosen == true then
		for _, id in SQ.Main do
			if not st.Done[id] then
				st.Main = { Id = id, St = 1, P = 0, T = {}, Claim = false }
				local def = DEFS[id]
				if def.Start then notify(player, def.Start, "info") end
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
			if def.Start then notify(player, def.Start, "info") end
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
			elseif obj.Type == "Level" then
				done = num(data.Level, 1) >= obj.Level
				if not done then changed = true end -- the row shows "(지금 LvN)"
			elseif obj.Type == "Enter" then
				done = zoneMatches(player, obj.Zone, currentZone(player))
			elseif obj.Type == "Near" then
				-- standing next to a landmark (e.g. the Crossroads fountain), checked by the 1 s loop
				local spot = SQ.Landmarks[obj.Spot]
				local root = Util.GetRoot(player)
				done = spot ~= nil and root ~= nil and (obj.Zone == nil or zoneMatches(player, obj.Zone, currentZone(player)))
					and Util.FlatDistance(root.Position, spot) <= (obj.Radius or 20)
			end
			if done then advance(player, data, t.Id, tr) end
		end
	end
	-- P2: while a good / evil choice card waits, auto combat pauses (no choice is ever skipped by hunting AFK)
	local choice = false
	for _, t in tracks(data) do
		local tr = t.Track
		local step = (not tr.Claim) and stepOf(player, DEFS[t.Id], tr.St) or nil
		if step and step.Obj and step.Obj.Type == "Choice" then choice = true end
	end
	if (player:GetAttribute("ChoicePending") == true) ~= choice then
		player:SetAttribute("ChoicePending", choice)
		if choice and player:GetAttribute("AutoCombatEnabled") == true then
			notify(player, Config.Text.AutoChoiceWait, "info")
		end
	end
	if changed then dirty(player) end
end

------------------------------------------------------------------ quest list rows (QuestService.publish)
local function rowFor(player, data, id, track)
	local def = DEFS[id]
	local step = stepOf(player, def, track.St)
	local obj = step and step.Obj or {}
	local text, progress, target = step and step.Text or def.Title, 0, 1
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
	elseif obj.Key == "OwnIron" then
		text = string.format(step.Text, Util.FormatNumber(math.floor(num(data.CarriedGold) + num(data.BankGold))))
	elseif obj.Count then
		progress, target = math.floor(num(track.P)), obj.Count
		local okF, f = pcall(string.format, step.Text, progress, target)
		text = okF and f or step.Text
	end
	return {
		Id = "story:" .. id, Kind = def.Kind, Pinned = def.Kind == "Main", TutorialStep = TUT_DONE,
		Text = text, Progress = progress, Target = target,
		RewardGold = 0, RewardXP = 0,
		CanClaim = track.Claim == true, ShowProgress = target > 1 and not track.Claim,
		Story = { Id = id, St = track.St, Panel = step and step.Panel == true or nil, Guide = step and step.Guide or nil },
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

-- sub rows, best first (claimable > situational > S0 > others), at most Config.StoryQuests.MaxSubs
function StoryQuestService.SubRows(player, data)
	local st = story(data)
	local rows = {}
	for _, id in SQ.Subs do
		local tr = st.Subs[id]
		local def = DEFS[id]
		if tr and def and (tr.Claim or visible(player, def)) then
			-- before the first mission is accepted only S0 shows (A23-3: one goal at a time)
			if num(data.TutorialStep) ~= 0 or id == "S0" then
				local row = rowFor(player, data, id, tr)
				row.Rank = (tr.Claim and 0) or (def.Show and 1) or (id == "S0" and 2) or 3
				table.insert(rows, row)
			end
		end
	end
	table.sort(rows, function(a, b) return a.Rank < b.Rank end)
	local out = {}
	for i = 1, math.min(#rows, SQ.MaxSubs or 2) do
		rows[i].Rank = nil
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
	local obj = step.Obj
	if action == "Open" then
		openStep(player, id, tr)
	elseif action == "Talk" and obj.Type == "Talk" then
		advance(player, data, id, tr)
	elseif action == "Choose" and obj.Type == "Choice" then
		local f = faction(player)
		if f == "Halo" or f == "Horns" then
			if option ~= "Good" and option ~= "Evil" then return end
			local pick = obj[option]
			st.Pick[id] = pick.Pick or option -- saved before the points
			local stat = option == "Good" and "Honor" or "Infamy"
			S.PlayerService.AddStat(player, stat, pick.Points or 0)
			notify(player, string.format(option == "Good" and TXT.Good or TXT.Evil, pick.Points or 0), "good")
			if f == "Halo" and option == "Evil" then notify(player, TXT.OddHalo, "info") end
			if f == "Horns" and option == "Good" then notify(player, TXT.OddHorns, "info") end
		else
			if option ~= "A" and option ~= "B" then return end
			st.Pick[id] = option -- Neutral: recorded only (no good/evil score, A6)
			notify(player, TXT.Recorded, "info")
		end
		advance(player, data, id, tr)
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
		if data then sanitize(data) end
		pcall(refresh, player)
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, p in S.PlayerService.GetReadyPlayers() do
				local ok, err = pcall(refresh, p)
				if not ok then Util.Warn(TAG, "refresh: " .. tostring(err)) end
			end
		end
	end)
	print("[StoryQuestService] started")
end

return StoryQuestService
