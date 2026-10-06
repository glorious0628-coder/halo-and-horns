-- A23-14 rookie dailies (Lv1-9), golden goose co-op ("함께 구조") and the free class change below Lv5, run offline.
-- tools/test_a23_14.py injects the CURRENT repository sources before this file (CONFIG_SOURCE, NET_SOURCE, DATA_SOURCE,
-- QUEST_SOURCE, GOOSE_SOURCE, CLASS_SOURCE). Only engine / service boundaries are doubles: no Studio, no network,
-- no DataStore. Every check is named and collected (a failure never aborts the run); the result is one JSON line.

------------------------------------------------------------------ check collection
local results, order, findings = {}, {}, {}
local total, failedCount = 0, 0
local currentGroup = "setup"
local groupWarnings = {}

local function check(ok, name, detail)
	total += 1
	local key = currentGroup .. " :: " .. name
	local r = results[key]
	if not r then
		r = { Group = currentGroup, Name = name, Pass = 0, Fail = 0 }
		results[key] = r
		table.insert(order, key)
	end
	if ok then
		r.Pass += 1
	else
		r.Fail += 1
		failedCount += 1
		if r.Fail <= 3 then print("CHECK_FAIL " .. key .. " :: " .. tostring(detail or "")) end
		r.First = r.First or tostring(detail or "")
	end
	return ok == true
end

local function finding(text)
	table.insert(findings, { Group = currentGroup, Text = text })
end

local function runGroup(name, fn)
	currentGroup = name
	groupWarnings = {}
	local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
	check(ok, "group ran to the end without a Lua error", err)
	check(#groupWarnings == 0, "no service warnings (pcall-swallowed handler errors)", groupWarnings[1])
end

------------------------------------------------------------------ helpers
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in v do out[deepCopy(k)] = deepCopy(x) end
	return out
end

local function show(v)
	if type(v) ~= "table" then return tostring(v) end
	local parts = {}
	for k, x in v do table.insert(parts, tostring(k) .. "=" .. show(x)) end
	table.sort(parts)
	return "{" .. table.concat(parts, ",") .. "}"
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
			return { Disconnect = function() local i = table.find(callbacks, fn); if i then table.remove(callbacks, i) end end }
		end,
		Fire = function(_, ...) for _, fn in table.clone(callbacks) do fn(...) end end,
	}
end

local function execute(name, source, env, ...)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn(...)
end

local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__index = function(v, key)
	if key == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function nativeEnv()
	return { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec }, Color3 = { new = vec, fromRGB = vec, fromHSV = vec },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
		NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
		NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"),
		Font = ctor("Font"), Enum = enum }
end
local function typeofDouble(v) return type(v) == "table" and v.__kind or type(v) end

local CONFIG = execute("Config", CONFIG_SOURCE, nativeEnv())

-- seeded Util.Random stand-in (QuestService / GooseService use NextInteger / NextNumber)
local function seededRandom(seed)
	local state = seed % 2147483647
	if state <= 0 then state += 2147483646 end
	local r = {}
	local function nextFloat()
		state = (state * 48271) % 2147483647
		return (state - 1) / 2147483646
	end
	function r:NextNumber(a, b)
		local v = nextFloat()
		if a ~= nil then return a + (b - a) * v end
		return v
	end
	function r:NextInteger(a, b) return math.min(b, a + math.floor(nextFloat() * (b - a + 1))) end
	return r
end

local function newPlayer(name, userId, players)
	local p = { __kind = "Instance", ClassName = "Player", Name = name, DisplayName = name, UserId = userId, Parent = players,
		Attrs = {} }
	function p:IsA(kind) return kind == "Player" end
	function p:GetAttribute(k) return self.Attrs[k] end
	function p:SetAttribute(k, v) self.Attrs[k] = v end
	return p
end

------------------------------------------------------------------ A. quest world (real DataService + QuestService)
local questSerial = 0
local function questWorld(saved, seed, opts)
	questSerial += 1
	local f = { Now = 1000, Rows = {}, Notices = {}, Pays = {}, Tickets = {}, Spawned = {}, Ready = true, Zone = "SlimeMeadow" }
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	f.Config = config
	local players = { __kind = "Instance", Name = "Players" }
	local userId = 7000 + questSerial
	if saved then f.Rows["P_" .. userId] = deepCopy(saved) end
	local store = {}
	function store:GetAsync(k) return deepCopy(f.Rows[k]) end
	function store:UpdateAsync(k, fn)
		local nextValue = fn(deepCopy(f.Rows[k]))
		if nextValue ~= nil then f.Rows[k] = deepCopy(nextValue) end
		return deepCopy(f.Rows[k])
	end
	local remotes = {}
	local net = {}
	function net.Get(name)
		if not remotes[name] then
			remotes[name] = { OnServerEvent = signal(), FireClient = function(_, p, payload)
				if name == "Quests" then f.LastJson = payload; f.QuestSends = (f.QuestSends or 0) + 1 end
			end }
		end
		return remotes[name]
	end
	function net.Notify(_, text, kind) table.insert(f.Notices, { Text = text, Kind = kind }) end
	function net.NotifyAll() end
	function net.Fx() end
	local random = seededRandom(seed or questSerial)
	local util = { DeepCopy = deepCopy, FormatNumber = tostring, Random = random,
		Warn = function(tag, msg) if tag ~= "DataService" then table.insert(groupWarnings, tag .. ": " .. tostring(msg)) end end,
		RateLimit = function() return true end, Now = function() return f.Now end,
		IsAlive = function() return true end, Signal = { new = signal } }
	local services = { Players = players, ReplicatedStorage = { Shared = { Config = "Config", Util = "Util", Net = "Net" } },
		DataStoreService = { GetDataStore = function() return store end }, RunService = { IsStudio = function() return true end },
		HttpService = { GenerateGUID = function() return "guid-" .. questSerial end,
			JSONEncode = function(_, v) f.LastList = deepCopy(v); return show(v) end } }
	local env = { game = { JobId = "offline-a23-14", GetService = function(_, name) return assert(services[name], name) end },
		workspace = {}, typeof = typeofDouble, print = function() end, warn = function() end,
		task = { spawn = function(fn) table.insert(f.Spawned, fn) end, wait = function() error("unexpected yield") end,
			delay = function() end, defer = function(fn, ...) fn(...) end },
		require = function(name)
			if name == "Config" then return config elseif name == "Util" then return util elseif name == "Net" then return net end
			error("unexpected require " .. tostring(name))
		end }
	local ds = execute("DataService", DATA_SOURCE, env)
	ds.Init({})
	ds.Start()
	f.Spawned[1]() -- the DataStore probe; the autosave loop is never started
	f.Spawned = {}
	local player = newPlayer("Rookie" .. questSerial, userId, players)
	f.Player = player
	local data = assert(ds.Load(player), "DataService.Load failed")
	f.Data, f.DS = data, ds
	local mirrored = {}
	for _, key in config.Data.Mirrored do mirrored[key] = true end
	for key in mirrored do player:SetAttribute(key, data[key]) end
	local ps = { PlayerReady = signal(), PlayerLeaving = signal(), CharacterSpawned = signal(),
		IsReady = function(p) return f.Ready and ds.Get(p) ~= nil end, GetData = function(p) return ds.Get(p) end,
		GetReadyPlayers = function() return { player } end }
	function ps.SetStat(p, key, value)
		local d = assert(ds.Get(p))
		d[key] = value
		if mirrored[key] then p:SetAttribute(key, value) end
	end
	function ps.AddStat(p, key, amount)
		local v = (tonumber(ds.Get(p)[key]) or 0) + amount
		ps.SetStat(p, key, v)
		return v
	end
	local prog = { GoldEarned = signal(), Rebirthed = signal(), LevelReset = signal(), LeveledUp = signal() }
	function prog.AddBankGold(p, amount, source)
		table.insert(f.Pays, { Gold = amount, Source = source })
		ps.AddStat(p, "BankGold", amount)
	end
	function prog.AddXP(p, amount)
		table.insert(f.Pays, { XP = amount })
		ps.AddStat(p, "XP", amount)
	end
	local registry = { PlayerService = ps, DataService = ds, ProgressionService = prog,
		MonsterService = { MonsterKilled = signal() }, CombatService = { Released = signal() },
		GooseService = { GooseFinished = signal() }, PvPService = { PlayerKO = signal(),
			IsRookie = function() return not (opts and opts.Graduated) end },
		KaijuService = { KaijuEnded = signal() },
		FactionService = { FactionChanged = signal(), GetFaction = function(p) return ds.Get(p).Faction end },
		ClassService = { ClassChanged = signal() },
		ZoneService = { ZoneChanged = signal(), GetZoneId = function() return f.Zone end },
		MonetizationService = { AddTickets = function(_, kind, n) table.insert(f.Tickets, { kind, n }) end } }
	local quest = execute("QuestService", QUEST_SOURCE, env)
	quest.Init(registry)
	quest.Start()
	f.Spawned = {} -- publish / day / tutorial loops are never started; their work is driven directly
	f.Quest, f.Registry, f.PS = quest, registry, ps
	ps.PlayerReady:Fire(player, data)

	function f:Kill(kind, extra)
		local info = { Kind = kind, Personal = false, ZoneId = "SlimeMeadow", Golden = false }
		for k, v in extra or {} do info[k] = v end
		registry.MonsterService.MonsterKilled:Fire(self.Player, info)
	end
	function f:Skill(info) registry.CombatService.Released:Fire(self.Player, info) end
	function f:Gold(amount, source) prog.GoldEarned:Fire(self.Player, amount, source) end
	function f:Claim(slot) remotes.ClaimQuest.OnServerEvent:Fire(self.Player, slot) end
	function f:Reroll(slot) remotes.RerollQuest.OnServerEvent:Fire(self.Player, slot) end
	function f:Paid()
		local g, x = 0, 0
		for _, e in self.Pays do g += e.Gold or 0; x += e.XP or 0 end
		self.Pays = {}
		return g, x
	end
	function f:Slot(id)
		for i, q in self.Data.Quests do if q.Id == id then return i, q end end
		return nil, nil
	end
	-- finish a quest of `id` through the real progress handlers
	function f:Finish(id)
		local _, q = self:Slot(id)
		if not q then return end
		for _ = 1, 400 do
			if q.Progress >= q.Target then break end
			if id == "Kill" then self:Kill(q.Unit or "Slime")
			elseif id == "Release" then self:Skill({ Auto = false, MonstersHit = 1 })
			elseif id == "Gold" then self:Gold(5, "Monster") end
		end
	end
	function f:SaveAndReload()
		assert(ds.Save(self.Player, false), "DataService.Save failed")
		return deepCopy(self.Rows["P_" .. userId])
	end
	return f
end

local function today() return CONFIG.DayIndex(os.time()) end
local function rookieRow(level, faction, extra)
	local row = { Version = 3, Level = level, Faction = faction or "Halo", ClassChosen = true, Class = "Warrior",
		TutorialStep = 99, BlacksmithVisited = true, WeaponTier = 1, WeaponOwnedMask = 1 }
	for k, v in extra or {} do row[k] = v end
	return row
end

local NB = CONFIG.Quests.Newbie
local TEMPLATE = {}
for _, t in CONFIG.Quests.Templates do TEMPLATE[t.Id] = t end
local function inList(list, v) return table.find(list, v) ~= nil end
local function newbieRows(id)
	local out = {}
	for _, row in NB.Dailies do if row.Id == id then table.insert(out, row) end end
	return out
end

------------------------------------------------------------------ A1. config contract
runGroup("dailies-config", function()
	check(type(NB) == "table" and NB.MaxLevel == 9 and NB.RewardMinutes == 2 and NB.ChestMinutes == 4,
		"Config.Quests.Newbie: Lv1-9, 2-minute dailies, 4-minute chest", show(NB and { NB.MaxLevel, NB.RewardMinutes, NB.ChestMinutes }))
	check(CONFIG.Zones.GoblinWoods.MinLevel == NB.MaxLevel + 1, "the newbie band ends where Goblin Woods opens (Lv10)")
	local ids = {}
	for _, row in NB.Dailies do
		ids[row.Id] = true
		check(TEMPLATE[row.Id] ~= nil and not TEMPLATE[row.Id].PvP, "every newbie row reuses a non-PvP template Id", row.Id)
		check(type(row.Targets) == "table" and #row.Targets > 0, "every newbie row has exact Targets", row.Id)
	end
	check(ids.Kill and ids.Release and ids.Gold and count(ids) == 3, "newbie pool = three different goals (kill / skill / gold)", show(ids))
	check(not ids.Goose and not ids.Golden, "no goose / golden-luck goals for rookies")
	local king = newbieRows("Kill")[1]
	check(king and king.Monster == "BigSlime" and king.Strict == true and king.Targets[1] == 3, "first kill row: 왕 슬라임 3마리, strict",
		show(king))
	-- rewards: HuntValue(level, 2) per daily and HuntValue(level, 4) per chest, for every Lv1-9 (all meadow = slime value)
	for level = 1, 9 do
		local g, x = CONFIG.HuntValue(level, NB.RewardMinutes)
		local cg, cx = CONFIG.HuntValue(level, NB.ChestMinutes)
		check(g == 72 and x == 120 and cg == 144 and cx == 240, "Lv1-9 newbie daily 72 gold + 120 XP, chest 144 + 240",
			level .. " " .. show({ g, x, cg, cx }))
	end
	-- Lv10 check: one day's newbie set (3 dailies + chest) never reaches Lv10 from Lv1
	local need = 0
	for level = 1, 9 do need += CONFIG.XPToNext(level) end
	local _, dx = CONFIG.HuntValue(1, NB.RewardMinutes)
	local _, chx = CONFIG.HuntValue(1, NB.ChestMinutes)
	local dayXP = CONFIG.Quests.Slots * dx + chx
	check(need == 1381, "Lv1 -> Lv10 needs 1381 XP (Config.XPToNext, EarlyMult below Lv10)", need)
	check(dayXP == 600 and dayXP < need, "one day's newbie set pays 600 XP < 1381 (no Lv10 from one day of dailies)", dayXP)
	local level, xp = 1, dayXP
	while level < 100 and xp >= CONFIG.XPToNext(level) do xp -= CONFIG.XPToNext(level); level += 1 end
	check(level < 10, "a fresh Lv1 player who only claims one day's dailies ends below Lv10", level)
	local oldDay = CONFIG.Quests.Slots * select(2, CONFIG.DailyQuestReward(1)) + select(2, CONFIG.DailyChestReward(1))
	finding(string.format("Lv1 one-day daily XP: newbie %d vs the old Lv10+ formula %d (Lv10 needs %d); a Lv1 player who only "
		.. "claims dailies reaches Lv%d after day 1 and needs %d days for Lv10.", dayXP, oldDay, need, level, math.ceil(need / dayXP)))
	-- vacation follows the same band (Config.DailyDayMinutes): a missed rookie day pays less than a played one
	check(CONFIG.DailyDayMinutes(1) == 10 and CONFIG.DailyDayMinutes(9) == 10 and CONFIG.DailyDayMinutes(10) == 15
		and CONFIG.DailyDayMinutes(24) == 15 and CONFIG.DailyDayMinutes(25) == 25,
		"DailyDayMinutes: Lv1-9 = 2 x 3 + 4 = 10, Lv10-24 (E12 woods) = 3 x 3 + 6 = 15, Lv25+ = 25",
		show({ CONFIG.DailyDayMinutes(1), CONFIG.DailyDayMinutes(10), CONFIG.DailyDayMinutes(24), CONFIG.DailyDayMinutes(25) }))
	local vg, vx = CONFIG.VacationReward(1, 1)
	check(vg < 360 and vx < 600 and vg >= 251 and vx == 420, "a missed Lv1-9 day (70% of 10 minutes) pays less than a played day (360 + 600)",
		show({ vg, vx }))
	-- documented value (Config comments / fix report): 70% of 360 gold = 252. math.floor(360 * 0.7) gives 251 in floating point.
	check(vg == 252, "a missed Lv1-9 day pays exactly the documented 252 gold (70% of 360; float floor must not lose 1 gold)",
		show({ vg, vx }))
	local _, v3 = CONFIG.VacationReward(1, 3)
	check(v3 == 1260 and v3 < need, "3 missed days (max) = 1260 XP < 1381 (no Lv10 from vacation alone)", v3)
	local tg, tx = CONFIG.HuntValue(25, 25)
	local wg, wx = CONFIG.VacationReward(25, 1)
	check(wg == math.floor(tg * 0.7) and wx == math.floor(tx * 0.7), "Lv25+ vacation unchanged (70% of 25 minutes)", show({ wg, wx }))
	local sg, sx = CONFIG.HuntValue(10, 15)
	local vg10, vx10 = CONFIG.VacationReward(10, 1)
	check(vg10 == math.floor(sg * 0.7 + 1e-6) and vx10 == math.floor(sx * 0.7 + 1e-6), "Lv10-24 vacation = 70% of the woods day (15 minutes)",
		show({ vg10, vx10 }))
end)

------------------------------------------------------------------ A2. generation
runGroup("dailies-generate", function()
	local kingRows, slimeRows, runs = 0, 0, 0
	for _, faction in { "Halo", "Horns", "Neutral" } do
		for _, level in { 1, 5, 9 } do
			for seed = 1, 14 do
				runs += 1
				local f = questWorld(rookieRow(level, faction), seed * 101 + level)
				local d = f.Data
				local ids = {}
				for _, q in d.Quests do ids[q.Id] = (ids[q.Id] or 0) + 1 end
				check(#d.Quests == 3 and ids.Kill == 1 and ids.Release == 1 and ids.Gold == 1,
					"Lv1-9: three different dailies (kill / skill / gold)", faction .. " Lv" .. level .. " " .. show(ids))
				local wantG, wantX = CONFIG.HuntValue(level, NB.RewardMinutes)
				for _, q in d.Quests do
					check(q.Kind == "Daily", "all three are dailies", q.Kind)
					check(q.RewardGold == wantG and q.RewardXP == wantX, "newbie daily reward = HuntValue(level, 2) (72 / 120)",
						show({ q.Id, q.RewardGold, q.RewardXP }))
					check(q.Progress >= 0 and q.Progress < q.Target, "a new daily starts unfinished", show({ q.Id, q.Progress, q.Target }))
					local t = TEMPLATE[q.Id]
					if q.Id == "Kill" then
						local unit = CONFIG.MonsterTypes[q.Unit]
						if q.Unit == "BigSlime" then
							kingRows += 1
							check(q.Strict == true and q.Target == 3, "왕 슬라임 row: 3 kills, strict", show(q))
						else
							slimeRows += 1
							check(q.Unit == "Slime" and q.Strict == nil and inList(newbieRows("Kill")[2].Targets, q.Target),
								"슬라임 row: 12-15 kills, not strict", show(q))
						end
						check(unit and q.Text == string.format(t.Text, tostring(unit.Short or unit.Name), q.Target),
							"kill text names the monster and the target", q.Text)
					elseif q.Id == "Release" then
						check(inList(newbieRows("Release")[1].Targets, q.Target) and q.Text == string.format(t.Text, q.Target),
							"skill row: 3-5 monster hits, template text", show({ q.Target, q.Text }))
						check(string.find(q.Text, "monster", 1, true) ~= nil, "skill row text says the skill must hit a monster", q.Text)
					elseif q.Id == "Gold" then
						check(inList(newbieRows("Gold")[1].Targets, q.Target) and q.Text == string.format(t.Text, tostring(q.Target)),
							"gold row: 40-60 hunting gold, template text", show({ q.Target, q.Text }))
					end
				end
				check(d.DailyLevel == level and d.DailyDay == today(), "DailyLevel / DailyDay record the generation band",
					show({ d.DailyLevel, d.DailyDay }))
			end
		end
	end
	check(kingRows > slimeRows and slimeRows > 0, "both kill variants occur (king slime 3 more often than 12-15 slimes)",
		show({ kingRows, slimeRows, runs }))
	-- Lv25+: the normal dailies (unchanged; Lv10-24 is the E12 woods band, group dailies-woods)
	for seed = 1, 10 do
		local f = questWorld(rookieRow(25, "Halo"), seed * 7)
		local wantG, wantX = CONFIG.DailyQuestReward(25)
		for _, q in f.Data.Quests do
			check(q.Kind == "Daily" and q.RewardGold == wantG and q.RewardXP == wantX and q.Strict == nil,
				"Lv25 dailies keep the old reward (DailyQuestReward) and are never strict", show(q))
			if q.Id == "Kill" then
				check(q.Unit == "Skeleton" and inList(TEMPLATE.Kill.DailyUnits, q.Target), "Lv25 kill daily = 50-60 skeletons (old sizes)", show(q))
			end
		end
	end
	-- the generated band is saved with the record
	local f = questWorld(rookieRow(4, "Horns"), 99)
	local row = f:SaveAndReload()
	check(row.DailyLevel == 4 and #row.Quests == 3 and row.Quests[1].RewardGold == 72, "DailyLevel and the newbie set survive a save",
		show({ row.DailyLevel, #row.Quests }))
end)

------------------------------------------------------------------ A3. progress and claims
local function worldWithKill(unit, level, startSeed)
	for seed = startSeed or 1, startSeed and startSeed + 400 or 400 do
		local f = questWorld(rookieRow(level or 1, "Halo"), seed)
		local _, q = f:Slot("Kill")
		if q and q.Unit == unit then return f end
	end
	error("no seed produced a " .. unit .. " kill daily")
end

runGroup("dailies-progress", function()
	local f = worldWithKill("BigSlime")
	local ki, king = f:Slot("Kill")
	local ri, skill = f:Slot("Release")
	local gi, gold = f:Slot("Gold")
	local before = king.Progress
	for _ = 1, 5 do f:Kill("Slime") end
	check(king.Progress == before, "strict 왕 슬라임 row: a slime counts 0 (no fractions)", king.Progress)
	f:Kill("BigSlime")
	check(king.Progress == before + 1, "a king slime counts exactly 1", king.Progress)
	f:Kill("Goblin")
	check(king.Progress == before + 2, "a stronger monster counts 1 too", king.Progress)
	f:Kill("Dragon")
	check(king.Progress == before + 2, "an unknown monster never counts for a strict row", king.Progress)
	-- skill row: manual casts that hit at least one monster only
	local s0 = skill.Progress
	f:Skill({ Auto = true, MonstersHit = 3 })
	f:Skill({ Auto = false, MonstersHit = 0 })
	f:Skill({ Auto = false })
	f:Skill("bad")
	check(skill.Progress == s0, "auto casts / whiffs / malformed events do not count", skill.Progress)
	f:Skill({ Auto = false, MonstersHit = 4 })
	check(skill.Progress == s0 + 1, "one manual cast hitting monsters counts once", skill.Progress)
	-- gold row: hunting gold only
	local g0 = gold.Progress
	f:Gold(30, "Sale"); f:Gold(30, "Quest"); f:Gold(30, "Event")
	check(gold.Progress == g0, "sale / quest / event gold does not count", gold.Progress)
	f:Gold(7, "Monster")
	check(gold.Progress == g0 + 7, "monster gold counts 1:1", gold.Progress)
	-- finish and claim all three
	f.Notices = {}
	f:Finish("Kill"); f:Finish("Release"); f:Finish("Gold")
	check(king.Progress == king.Target and skill.Progress == skill.Target and gold.Progress == gold.Target,
		"all three can be finished by hunting", show({ king.Progress, skill.Progress, gold.Progress }))
	check(f.Data.Quests[ki] == king and f.Data.Quests[ri] == skill and f.Data.Quests[gi] == gold, "finished dailies wait for a claim")
	local paidBefore = f:Paid()
	check(paidBefore == 0, "finishing pays nothing before the claim", paidBefore)
	local claimed = { 0, 0 }
	for _, slot in { ki, ri, gi } do
		f.Now += 2
		f:Claim(slot)
		local g, x = f:Paid()
		if slot ~= gi then
			check(g == 72 and x == 120, "each claimed newbie daily pays 72 gold + 120 XP", show({ g, x }))
		else
			check(g == 72 + 144 and x == 120 + 240, "the third claim also pays the newbie chest (144 + 240)", show({ g, x }))
		end
		claimed[1] += g; claimed[2] += x
		check(f.Data.Quests[slot].Kind == "Extra", "a claimed daily slot becomes an extra quest", f.Data.Quests[slot].Kind)
	end
	check(claimed[1] == 360 and claimed[2] == 600, "the full rookie day pays 360 gold + 600 XP", show(claimed))
	check(f.Data.DailyClaims == 3, "three claims recorded", f.Data.DailyClaims)
	f:Claim(ki)
	check(f:Paid() == 0, "a second claim of the same slot pays nothing")
	-- non-strict slime row: slimes count 1 each, a king slime counts at most 1
	local s = worldWithKill("Slime", 3)
	local _, slime = s:Slot("Kill")
	local p0 = slime.Progress
	s:Kill("Slime"); s:Kill("BigSlime")
	check(slime.Progress == p0 + 2, "슬라임 row: a slime and a king slime count 1 each", slime.Progress)
end)

runGroup("dailies-reroll-band", function()
	-- reroll keeps the newbie rules
	local f = worldWithKill("BigSlime")
	local ri, q = f:Slot("Release")
	f.Now += 100
	f:Reroll(ri)
	local nq = f.Data.Quests[ri]
	check(nq ~= q and nq.Kind == "Daily" and nq.RewardGold == 72 and nq.RewardXP == 120, "a rerolled newbie daily stays a newbie daily",
		show(nq))
	local found = false
	for _, row in NB.Dailies do if row.Id == nq.Id and inList(row.Targets, nq.Target) then found = true end end
	check(found, "the rerolled target comes from the newbie rows", show({ nq.Id, nq.Target }))
	-- chest band: dailies generated at Lv9, Lv10 reached before the last claim -> the newbie chest, not the Lv10 chest
	local g = questWorld(rookieRow(9, "Halo"), 5)
	check(g.Data.DailyLevel == 9, "Lv9 set generated", g.Data.DailyLevel)
	local slots = {}
	for i in g.Data.Quests do table.insert(slots, i) end
	for _, id in { "Kill", "Release", "Gold" } do g:Finish(id) end
	g:Claim(slots[1]); g.Now += 2; g:Claim(slots[2]); g.Now += 2
	g:Paid()
	g.PS.SetStat(g.Player, "Level", 10)
	g.Registry.ProgressionService.LeveledUp:Fire(g.Player)
	g:Claim(slots[3])
	local pg, px = g:Paid()
	check(pg == 72 + 144 and px == 120 + 240, "Lv9 set claimed at Lv10: stored 72/120 and the newbie chest 144/240 (not 1920/3360)",
		show({ pg, px }))
	-- an old saved Lv1 daily (50 slimes, 180 / 300) is kept and paid as stored
	local old = rookieRow(1, "Halo", { DailyDay = today(), DailyClaims = 0, DailyLevel = 0, Quests = {
		{ Id = "Kill", Kind = "Daily", Target = 50, Progress = 49, RewardGold = 180, RewardXP = 300, Text = "슬라임 50마리 쓰러뜨리기", Unit = "Slime" },
		{ Id = "Gold", Kind = "Daily", Target = 100, Progress = 3, RewardGold = 180, RewardXP = 300, Text = "사냥으로 골드 100 벌기", Unit = "Slime" },
		{ Id = "Release", Kind = "Daily", Target = 3, Progress = 0, RewardGold = 180, RewardXP = 300, Text = "x", Unit = "Slime" },
	} })
	local o = questWorld(old, 3)
	check(o.Data.Quests[1].Target == 50 and o.Data.Quests[1].RewardGold == 180, "an old saved rookie daily is kept until the next day",
		show(o.Data.Quests[1]))
	o:Kill("Slime")
	o:Claim(1)
	local og, ox = o:Paid()
	check(og == 180 and ox == 300, "the old daily pays its stored 180 / 300 (Lv1 cap = 5-minute value)", show({ og, ox }))
end)

runGroup("dailies-day-change", function()
	-- a whole missed rookie day: vacation in the newbie band
	local f = questWorld(rookieRow(1, "Halo", { DailyDay = today() - 2, DailyClaims = 0, DailyLevel = 1, Quests = {} }), 11)
	local wantG, wantX = CONFIG.VacationReward(1, 2)
	check(f.Data.VacationDays == 2 and f.Data.VacationGold == wantG and f.Data.VacationXP == wantX and wantX == 840,
		"2 missed rookie days = VacationReward(1, 2) in the newbie band (840 XP)", show({ f.Data.VacationDays, f.Data.VacationGold, f.Data.VacationXP }))
	-- a fully played old day gives no vacation; a partly played one gives the missing share (f in the old day's band)
	local full = questWorld(rookieRow(1, "Halo", { DailyDay = today() - 1, DailyClaims = 3, DailyLevel = 1, Quests = {} }), 12)
	check((full.Data.VacationDays or 0) == 0, "a fully claimed rookie day adds no vacation", full.Data.VacationDays)
	local part = questWorld(rookieRow(1, "Halo", { DailyDay = today() - 1, DailyClaims = 1, DailyLevel = 1, Quests = {} }), 13)
	check(math.abs((part.Data.VacationDays or 0) - 0.8) < 1e-9, "one claim of three = 2 of 10 rookie minutes -> 0.8 vacation day",
		part.Data.VacationDays)
	-- midnight auto-pay of a finished set generated at Lv1 while the player is now Lv10: stored rewards + the Lv1 chest
	local done = {}
	for i, id in { "Kill", "Release", "Gold" } do
		done[i] = { Id = id, Kind = "Daily", Target = 3, Progress = 3, RewardGold = 72, RewardXP = 120, Text = "t" .. i, Unit = "BigSlime" }
	end
	local a = questWorld(rookieRow(10, "Halo", { DailyDay = today() - 1, DailyClaims = 0, DailyLevel = 1, Quests = done }), 14)
	local ag, ax = a:Paid()
	check(ag == 3 * 72 + 144 and ax == 3 * 120 + 240, "midnight auto-pay: stored 72/120 x 3 + the chest of the OLD (Lv1) band",
		show({ ag, ax }))
	check(a.Data.DailyLevel == 10 and a.Data.Quests[1].RewardGold == select(1, CONFIG.HuntValue(10, CONFIG.Quests.Woods.RewardMinutes)),
		"the new day is generated in the current (Lv10, woods) band", show({ a.Data.DailyLevel, a.Data.Quests[1].RewardGold }))
end)

------------------------------------------------------------------ A4. E12 the Goblin Woods band (Lv10-24, quest_volume §3-4)
local WD = CONFIG.Quests.Woods
local function woodsRows(id)
	local out = {}
	for _, row in WD.Dailies do if row.Id == id then table.insert(out, row) end end
	return out
end
-- a woods set of kill / skill / gold only (the goals f:Finish can drive), generated at `level`
local function woodsKSG(level, from)
	for seed = from or 1, (from or 1) + 600 do
		local g = questWorld(rookieRow(level, "Halo"), seed)
		local ok = true
		for _, q in g.Data.Quests do
			if q.Id ~= "Kill" and q.Id ~= "Release" and q.Id ~= "Gold" then ok = false end
		end
		if ok then return g end
	end
	error("no seed produced a kill / skill / gold woods set")
end

runGroup("dailies-woods", function()
	check(type(WD) == "table" and WD.MinLevel == 10 and WD.MaxLevel == 24 and WD.RewardMinutes == 3 and WD.ChestMinutes == 6,
		"Config.Quests.Woods: Lv10-24, 3-minute dailies, 6-minute chest",
		show(WD and { WD.MinLevel, WD.MaxLevel, WD.RewardMinutes, WD.ChestMinutes }))
	check(WD.MinLevel == NB.MaxLevel + 1 and WD.MaxLevel + 1 == CONFIG.Zones.SkeletonRuins.MinLevel,
		"the woods band starts after the newbie band and ends where the Skeleton Ruins open")
	for _, row in WD.Dailies do
		check(TEMPLATE[row.Id] ~= nil and type(row.Targets) == "table" and #row.Targets > 0,
			"every woods row reuses a template Id with exact Targets", row.Id)
	end
	-- generation: three different goals, the woods reward, targets from the rows, side / PvP rules kept
	local seen = {}
	for _, faction in { "Halo", "Horns", "Neutral" } do
		for _, level in { 10, 17, 24 } do
			for seed = 1, 12 do
				local f = questWorld(rookieRow(level, faction), seed * 131 + level, { Graduated = level >= 15 })
				local ids = {}
				for _, q in f.Data.Quests do
					ids[q.Id] = (ids[q.Id] or 0) + 1
					seen[q.Id] = (seen[q.Id] or 0) + 1
				end
				check(#f.Data.Quests == 3 and count(ids) == 3, "Lv10-24: three different dailies", faction .. " Lv" .. level .. " " .. show(ids))
				local wantG, wantX = CONFIG.HuntValue(level, WD.RewardMinutes)
				for _, q in f.Data.Quests do
					check(q.Kind == "Daily" and q.RewardGold == wantG and q.RewardXP == wantX, "a woods daily pays HuntValue(level, 3)",
						show({ q.Id, q.RewardGold, wantG }))
					local fromRow = false
					for _, row in woodsRows(q.Id) do
						if inList(row.Targets, q.Target) and (row.Monster == nil or row.Monster == q.Unit) then fromRow = true end
					end
					check(fromRow, "the target comes from a woods row", show({ q.Id, q.Target, q.Unit }))
					if q.Id == "Kill" then
						check((q.Unit == "Goblin" and q.Strict == nil) or (q.Unit == "GoblinBrute" and q.Strict == true and q.Target == 2),
							"kill rows: 12-15 goblins, or 2 Goblin Brutes (strict)", show(q))
					elseif q.Id == "Goose" then
						check(faction ~= "Neutral", "no goose daily for the guild", faction)
					elseif q.Id == "Hunt" then
						check(faction == "Halo" and level >= 15, "Hunt: Halo, Lv15+ (no Sprout Shield) only", faction .. level)
					elseif q.Id == "Plunder" then
						check(faction == "Horns" and level >= 15, "Plunder: Horns, Lv15+ (no Sprout Shield) only", faction .. level)
					end
				end
				check(f.Data.DailyLevel == level, "DailyLevel records the woods band", f.Data.DailyLevel)
			end
		end
	end
	check((seen.Kill or 0) > 0 and (seen.Release or 0) > 0 and (seen.Gold or 0) > 0 and (seen.Golden or 0) > 0,
		"kill / skill / gold / golden all show up", show(seen))
	for seed = 1, 20 do
		local f = questWorld(rookieRow(17, "Horns"), seed * 17, { Graduated = false })
		for _, q in f.Data.Quests do check(q.Id ~= "Plunder" and q.Id ~= "Hunt", "a Sprout-shielded Lv17: no PvP daily", q.Id) end
	end
	-- the strict brute row: goblins count 0, a brute 1
	local b
	for seed = 1, 600 do
		local f = questWorld(rookieRow(12, "Halo"), seed)
		local _, q = f:Slot("Kill")
		if q and q.Unit == "GoblinBrute" then b = f; break end
	end
	check(b ~= nil, "a Goblin Brute daily shows up")
	if b then
		local _, q = b:Slot("Kill")
		local p0 = q.Progress
		for _ = 1, 4 do b:Kill("Goblin", { ZoneId = "GoblinWoods" }) end
		check(q.Progress == p0, "strict brute row: goblins count 0", q.Progress)
		b:Kill("GoblinBrute", { ZoneId = "GoblinWoods" })
		check(q.Progress == p0 + 1, "a Goblin Brute counts 1", q.Progress)
	end
	-- a full woods day: 3 x HuntValue(10, 3) + the chest HuntValue(10, 6)
	local f = woodsKSG(10)
	for _, id in { "Kill", "Release", "Gold" } do f:Finish(id) end
	local got = { 0, 0 }
	for i = 1, 3 do
		f.Now += 2
		f:Claim(i)
		local g, x = f:Paid()
		got[1] += g
		got[2] += x
	end
	local dg, dx = CONFIG.HuntValue(10, WD.RewardMinutes)
	local cg, cx = CONFIG.HuntValue(10, WD.ChestMinutes)
	check(got[1] == 3 * dg + cg and got[2] == 3 * dx + cx, "a full Lv10 woods day = 3 x 3 minutes + the 6-minute chest",
		show({ got, dg, cg }))
	-- a Lv24 set whose last claim comes at Lv25: the woods chest, never the bigger Lv25 one
	local h = woodsKSG(24, 50)
	for _, id in { "Kill", "Release", "Gold" } do h:Finish(id) end
	h:Claim(1); h.Now += 2; h:Claim(2); h.Now += 2
	h:Paid()
	h.PS.SetStat(h.Player, "Level", 25)
	h.Registry.ProgressionService.LeveledUp:Fire(h.Player)
	h:Claim(3)
	local hg = h:Paid()
	local storedG = select(1, CONFIG.HuntValue(24, WD.RewardMinutes))
	check(hg == storedG + select(1, CONFIG.HuntValue(24, WD.ChestMinutes)), "a Lv24 set claimed at Lv25: the woods chest",
		show({ hg, storedG }))
	-- a reroll stays in the band
	local r = woodsKSG(15, 90)
	local ri, rq = r:Slot("Release")
	r.Now += 100
	r:Reroll(ri)
	local nq = r.Data.Quests[ri]
	check(nq ~= rq and nq.Kind == "Daily" and nq.RewardGold == select(1, CONFIG.HuntValue(15, WD.RewardMinutes)),
		"a rerolled woods daily stays a woods daily", show(nq))
	-- vacation in the woods band
	local v = questWorld(rookieRow(12, "Halo", { DailyDay = today() - 2, DailyClaims = 0, DailyLevel = 12, Quests = {} }), 31)
	local vg, vx = CONFIG.VacationReward(12, 2)
	check(v.Data.VacationDays == 2 and v.Data.VacationGold == vg and v.Data.VacationXP == vx,
		"2 missed woods days = VacationReward(12, 2) (15-minute days)", show({ v.Data.VacationDays, v.Data.VacationGold, vg }))
	local part = questWorld(rookieRow(12, "Halo", { DailyDay = today() - 1, DailyClaims = 1, DailyLevel = 12, Quests = {} }), 32)
	check(math.abs((part.Data.VacationDays or 0) - 0.8) < 1e-9, "one claim of three = 3 of 15 woods minutes -> 0.8 vacation day",
		part.Data.VacationDays)
end)

------------------------------------------------------------------ A5. E11 the job-board switch (QuestService's side)
local function listed(f)
	f.PS.PlayerReady:Fire(f.Player, f.Data) -- publishes (same day: the quests stay)
	return f.LastList or {}
end
local function slotOf(list, slot)
	for _, row in list do if row.Slot == slot then return row end end
	return nil
end

runGroup("board-switch", function()
	-- off (the beta default until game dev 1's board window ships): a claimed daily slot becomes an extra, as before
	local off = woodsKSG(12, 300)
	check(off.Config.Board.Enabled == false, "Config.Board.Enabled is false", off.Config.Board.Enabled)
	local ki = off:Slot("Kill")
	off:Finish("Kill")
	off:Claim(ki)
	check(off.Data.Quests[ki].Kind == "Extra", "off: a claimed daily slot becomes an extra quest", show(off.Data.Quests[ki]))
	check(slotOf(listed(off), ki) ~= nil, "off: the extra is listed", show(off.LastList))
	-- on: the slot stays empty (not listed, never rerolled), the boards' Job rows are listed instead
	local f = woodsKSG(12, 400)
	f.Config.Board.Enabled = true
	f.Registry.BoardService = { JobRows = function()
		return { { Id = "job:1", Kind = "Job", Text = "King Slime 0/2", Progress = 0, Target = 2, CanClaim = false } }
	end }
	local si = f:Slot("Kill")
	f:Finish("Kill")
	f:Claim(si)
	check(f.Data.Quests[si].Kind == "Empty", "on: a claimed daily slot stays empty (no extra quest)", show(f.Data.Quests[si]))
	local list = listed(f)
	check(slotOf(list, si) == nil, "on: the empty slot is not listed", show(list))
	local jobRow = false
	for _, row in list do if row.Kind == "Job" and row.Id == "job:1" then jobRow = true end end
	check(jobRow, "on: the boards' Job rows are listed", show(list))
	f.Now += 100
	f:Reroll(si)
	check(f.Data.Quests[si].Kind == "Empty", "on: an empty slot is never rerolled into an extra", show(f.Data.Quests[si]))
	-- an extra made before the switch: when it is done, its slot stays empty too
	local gi = f:Slot("Gold")
	f.Data.Quests[gi] = { Id = "Gold", Kind = "Extra", Target = 5, Progress = 0, RewardGold = 10, RewardXP = 10, Text = "x",
		Unit = "Goblin" }
	f:Paid()
	f:Gold(5, "Monster")
	local pg = f:Paid()
	check(f.Data.Quests[gi].Kind == "Empty" and pg == 10, "on: a finished old extra pays and leaves its slot empty",
		show({ f.Data.Quests[gi], pg }))
	-- a rebirth / free class change keeps empty slots empty
	f.Registry.ProgressionService.Rebirthed:Fire(f.Player)
	check(f.Data.Quests[si].Kind == "Empty" and f.Data.Quests[gi].Kind == "Empty", "on: a rebirth keeps the empty slots empty",
		show(f.Data.Quests))
	-- the next KST day: three fresh dailies again
	f.PS.SetStat(f.Player, "DailyDay", today() - 1)
	f.PS.PlayerReady:Fire(f.Player, f.Data)
	local fresh = 0
	for _, q in f.Data.Quests do if q.Kind == "Daily" then fresh += 1 end end
	check(fresh == 3, "on: the next day brings three fresh dailies", show(f.Data.Quests))
	-- turned off again later: an empty slot becomes an extra at the next load
	f.Config.Board.Enabled = false
	f.Data.Quests[1] = { Kind = "Empty" }
	f.PS.PlayerReady:Fire(f.Player, f.Data)
	check(f.Data.Quests[1].Kind == "Extra", "switched off again: an empty slot gets an extra at load", show(f.Data.Quests[1]))
end)

------------------------------------------------------------------ B. golden goose co-op
local function gooseWorld(roster)
	local f = { Now = 5000, Clock = 100, Notices = {}, All = {}, Fx = {}, Gold = {}, XP = {}, War = {}, Finished = {}, Players = {},
		GS = {}, Loop = nil }
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	f.Config = config
	local gs = { Parent = {}, Attrs = {} }
	function gs:SetAttribute(k, v) self.Attrs[k] = v end
	function gs:GetAttribute(k) return self.Attrs[k] end
	f.GS = gs
	local net = { GameState = function() return gs end }
	function net.Notify(p, text, kind) table.insert(f.Notices, { Player = p, Text = text, Kind = kind }) end
	function net.NotifyAll(text, kind) table.insert(f.All, { Text = text, Kind = kind }) end
	function net.Fx(p, kind, data) table.insert(f.Fx, { Player = p, Kind = kind, Data = data }) end
	local util = { Signal = { new = signal }, Now = function() return f.Now end, FormatNumber = tostring,
		PlayerDisplayName = function(p) return p.Name end, Random = { NextNumber = function() return 0.999 end },
		Warn = function(tag, msg)
			msg = tostring(msg)
			-- the 3D goose model cannot be built offline (no Instance API); everything else must run warning-free
			if not string.find(msg, "goose model failed", 1, true) then table.insert(groupWarnings, tag .. ": " .. msg) end
		end }
	local players = { __kind = "Instance", Name = "Players" }
	local services = { ReplicatedStorage = { Shared = { Config = "Config", Util = "Util", Net = "Net" } },
		ServerStorage = { FindFirstChild = function() return nil end }, RunService = { Heartbeat = signal() } }
	local env = nativeEnv()
	-- GooseService builds its procedural body table at load time (CFrame products); only the arithmetic is needed offline
	local cfmt = {}
	local function cf() return setmetatable({ __kind = "CFrame" }, cfmt) end
	cfmt.__mul = function() return cf() end
	cfmt.__add = function() return cf() end
	cfmt.__sub = function() return cf() end
	env.CFrame = { new = cf, Angles = cf, lookAt = cf }
	env.game = { GetService = function(_, name) return assert(services[name], name) end }
	env.workspace = {}
	env.typeof, env.print, env.warn = typeofDouble, function() end, function() end
	env.os = setmetatable({ clock = function() return f.Clock end }, { __index = os })
	env.task = { spawn = function(fn) f.Loop = coroutine.create(fn) end, wait = function(d) return coroutine.yield(d) end,
		delay = function() end, defer = function(fn, ...) fn(...) end }
	env.require = function(name)
		if name == "Config" then return config elseif name == "Util" then return util elseif name == "Net" then return net end
		error("unexpected require " .. tostring(name))
	end
	local function ready()
		local out = {}
		for _, p in f.Players do if p.Parent ~= nil and p.Ready then table.insert(out, p) end end
		return out
	end
	local ps = { PlayerReady = signal(), PlayerLeaving = signal(),
		IsReady = function(p) return p.Ready == true and p.Parent ~= nil end, GetData = function(p) return p.Data end,
		GetReadyPlayers = ready, GetLuckEvents = function() return 0 end }
	function ps.AddStat(p, key, n) p.Data[key] = (p.Data[key] or 0) + n; return p.Data[key] end
	local registry = { PlayerService = ps,
		FactionService = { FactionChanged = signal(), GetFaction = function(p) return p.Faction end,
			GetCounts = function()
				local h, r = 0, 0
				for _, p in ready() do
					if p.Faction == "Halo" then h += 1 elseif p.Faction == "Horns" then r += 1 end
				end
				return h, r
			end },
		ProgressionService = { AddBankGold = function(p, g) f.Gold[p] = (f.Gold[p] or 0) + g end,
			AddXP = function(p, x) f.XP[p] = (f.XP[p] or 0) + x end },
		WarService = { GetRoundEndsAt = function() return nil end, AddFactionPoints = function(fac, n) table.insert(f.War, { fac, n }) end },
		JusticeService = { GetFactionScale = function() return 1 end } }
	local goose = execute("GooseService", GOOSE_SOURCE, env)
	goose.GooseFinished:Connect(function(result, rewarded, info)
		table.insert(f.Finished, { Result = result, Rewarded = rewarded, Info = info })
	end)
	f.Goose, f.Registry = goose, registry
	local serial = 0
	function f:Add(name, faction, level)
		serial += 1
		local p = newPlayer(name, 9000 + serial, players)
		p.Faction, p.Ready, p.Data = faction, true, { Level = level or 1, CheerStars = 0 }
		table.insert(self.Players, p)
		return p
	end
	for _, entry in roster or {} do f[entry[1]] = f:Add(entry[1], entry[2], entry[3]) end
	goose.Init(registry)
	goose.Start()
	assert(coroutine.resume(f.Loop)) -- runs to the loop's first wait (no tick yet)
	function f:Tick() local ok, err = coroutine.resume(self.Loop); assert(ok, err) end
	function f:Begin() self.Goose.DebugStart() end
	-- n hits ~0.4 s apart (MaxCountsPerSecond 3 in a rolling second); returns the total actually added
	function f:Hit(p, n, manual)
		local added = 0
		for _ = 1, n do
			self.Clock += 0.4
			added += self.Goose.RegisterHit(p, manual ~= false)
		end
		return added
	end
	function f:End()
		self.Now += config.Goose.Duration + 1
		self:Tick()
		return self.Finished[#self.Finished]
	end
	function f:AllText(text)
		local n = 0
		for _, e in self.All do if e.Text == text then n += 1 end end
		return n
	end
	function f:NoticeTo(p, text)
		local n = 0
		for _, e in self.Notices do if e.Player == p and e.Text == text then n += 1 end end
		return n
	end
	return f
end

local G = CONFIG.Goose
local GT = G.Text
local function reward(level, faction, won, share)
	return CONFIG.GooseReward(level, faction, won, false, share)
end

runGroup("goose-coop", function()
	check(G.CoopPerPerson == 20 and G.CoopWinShare == 0.7 and G.MinManualHits == 3, "Config.Goose co-op numbers 20 / 0.7 / 3 manual hits",
		show({ G.CoopPerPerson, G.CoopWinShare, G.MinManualHits }))
	-- solo Halo: co-op, target 20, success at 70%, no war points, no cheer star
	local f = gooseWorld({ { "H1", "Halo", 1 } })
	f:Begin()
	local A = f.GS.Attrs
	check(A.GooseActive == true and A.GooseMode == "Coop" and A.GooseCoopSide == "Halo" and A.GooseCoopTarget == 20
		and A.GooseCoopPeople == 1, "only Halo on the server: GameState GooseMode Coop / Halo / target 20 / 1 person", show(A))
	check(f:AllText(GT.CoopStart.Halo) == 1, "co-op start line announced (Halo: 함께 구조)")
	check(f:Hit(f.H1, 9, true) == 18, "manual hits pull ManualCount 2 each", A.GooseRescue)
	f:Tick()
	check(f:AllText(string.format(GT.CoopFull.Halo, G.MinManualHits)) == 0, "no 'gauge full' line before the target")
	f:Hit(f.H1, 1, true)
	f:Tick(); f:Tick()
	check(f:AllText(string.format(GT.CoopFull.Halo, G.MinManualHits)) == 1, "'gauge full' announced exactly once")
	check(f.Goose.IsActive(), "a full gauge does not end the event early")
	local fin = f:End()
	local g, x = reward(1, "Halo", true, 0.7)
	local fullG, fullX = reward(1, "Halo", true, nil)
	check(f.Gold[f.H1] == g and f.XP[f.H1] == x and g < fullG and g == math.floor(select(1, CONFIG.HuntValue(1, 10)) * G.OffShare * 0.7),
		"co-op success pays 70% of the winner reward", show({ f.Gold[f.H1], f.XP[f.H1], fullG, fullX }))
	check(#f.War == 0, "co-op never gives war points", show(f.War))
	check(f.H1.Data.CheerStars == 0, "co-op success gives no cheer star", f.H1.Data.CheerStars)
	check(f:NoticeTo(f.H1, string.format(GT.CoopReward.Halo, tostring(g), tostring(x))) == 1, "personal co-op reward toast")
	check(fin and fin.Result == "Halo" and fin.Rewarded[f.H1] == 20 and fin.Info and fin.Info.Mode == "Coop" and fin.Info.Success == true
		and fin.Info.Side == "Halo" and fin.Info.Target == 20, "GooseFinished('Halo', { H1 = 20 }, { Mode Coop, Success })", show(fin))
	check(f:AllText(GT.CoopResult.Halo) == 1, "co-op result line announced")
	check(A.GooseActive == false and A.GooseMode == "Versus" and A.GooseCoopSide == "None" and A.GooseCoopTarget == 0
		and A.GooseCoopPeople == 0, "GameState back to Versus / None / 0 after the event", show(A))
	-- solo Horns: 함께 밀렵, Horns reward shape
	local h = gooseWorld({ { "R1", "Horns", 4 } })
	h:Begin()
	check(h.GS.Attrs.GooseCoopSide == "Horns" and h:AllText(GT.CoopStart.Horns) == 1, "only Horns: co-op for Horns (함께 밀렵)")
	h:Hit(h.R1, 10, true)
	local hf = h:End()
	local rg, rx = reward(4, "Horns", true, 0.7)
	check(hf.Result == "Horns" and h.Gold[h.R1] == rg and h.XP[h.R1] == rx and #h.War == 0, "Horns co-op success: 70%, no war points",
		show({ hf.Result, h.Gold[h.R1], rg }))
end)

runGroup("goose-coop-rules", function()
	-- target scales with the co-op side's headcount at the start; a later teammate does not change it
	local f = gooseWorld({ { "H1", "Halo", 2 }, { "H2", "Halo", 2 }, { "H3", "Halo", 2 }, { "N1", "Neutral", 2 } })
	f:Begin()
	check(f.GS.Attrs.GooseCoopTarget == 60 and f.GS.Attrs.GooseCoopPeople == 3, "3 Halo players -> target 60 (Neutral not counted)",
		show(f.GS.Attrs))
	check(f:Hit(f.N1, 5, true) == 0, "a Neutral player pulls 0 (A6)")
	f:Add("H4", "Halo", 2)
	f:Tick()
	check(f.GS.Attrs.GooseCoopTarget == 60, "a teammate joining later does not change the target")
	-- 2 Halo, gauge not filled: the tie path (40% + cheer star) but still quest credit
	local t = gooseWorld({ { "H1", "Halo", 3 }, { "H2", "Halo", 3 } })
	t:Begin()
	check(t.GS.Attrs.GooseCoopTarget == 40, "2 Halo players -> target 40")
	t:Hit(t.H1, 5, true); t:Hit(t.H2, 4, true)
	local fin = t:End()
	local lg, lx = reward(3, "Halo", false, nil)
	check(fin.Result == "Tie" and fin.Info.Mode == "Coop" and fin.Info.Success == false, "gauge not full -> result Tie, co-op failed",
		show(fin.Info))
	check(t.Gold[t.H1] == lg and t.Gold[t.H2] == lg and t.XP[t.H1] == lx, "failed co-op pays the tie share (40%)", show({ t.Gold[t.H1], lg }))
	check(t.H1.Data.CheerStars == 1 and t.H2.Data.CheerStars == 1, "failed co-op gives +1 cheer star each")
	check(fin.Rewarded[t.H1] == 10 and fin.Rewarded[t.H2] == 8, "both still get goose quest credit (GooseFinished rewarded)", show(fin.Rewarded))
	check(t:AllText(GT.CoopFail) == 1 and #t.War == 0, "co-op fail line, no war points")
	-- 3 manual hits rule: auto hits pull but never pay; 2 manual hits are not enough; exactly 3 are
	local m = gooseWorld({ { "H1", "Halo", 1 }, { "H2", "Halo", 1 }, { "H3", "Halo", 1 } })
	m:Begin()
	m:Hit(m.H1, 2, true); m:Hit(m.H1, 30, false)
	m:Hit(m.H2, 40, false)
	m:Hit(m.H3, 3, true)
	local mf = m:End()
	check(mf.Result == "Halo" and mf.Info.Success == true, "auto hits still fill the co-op gauge", show(mf.Info))
	check(m.Gold[m.H1] == nil and m.Gold[m.H2] == nil and mf.Rewarded[m.H1] == nil and mf.Rewarded[m.H2] == nil,
		"fewer than 3 manual hits (2 manual + autos, auto only): no reward, no quest credit", show(mf.Rewarded))
	check(m:NoticeTo(m.H1, string.format(GT.NeedManual, G.MinManualHits)) == 1 and m:NoticeTo(m.H2, string.format(GT.NeedManual, G.MinManualHits)) == 1,
		"they are told why (NeedManual)")
	check(m.Gold[m.H3] == select(1, reward(1, "Halo", true, 0.7)) and mf.Rewarded[m.H3] ~= nil, "exactly 3 manual hits are paid")
end)

runGroup("goose-modes", function()
	-- nobody eligible (Neutral only) -> Pending -> plain tie, nobody paid, GooseFinished still fires
	local n = gooseWorld({ { "N1", "Neutral", 5 } })
	n:Begin()
	check(n.GS.Attrs.GooseMode == "Versus" and n.GS.Attrs.GooseCoopSide == "None", "nobody eligible: not co-op (Pending shows as tug)")
	check(n:Hit(n.N1, 4, true) == 0, "Neutral pulls 0")
	local nf = n:End()
	check(nf and nf.Result == "Tie" and count(nf.Rewarded) == 0 and nf.Info.Mode == "Pending", "Pending event ends as a plain tie",
		show(nf))
	check(n:AllText(CONFIG.Story.GooseResult.Tie) == 1 and #n.War == 0, "plain tie line, no war points")
	-- Pending fixed by the first eligible player mid-event
	local p = gooseWorld({})
	p:Begin()
	local late = p:Add("H1", "Halo", 1)
	check(p:Hit(late, 1, true) == 2, "the first eligible hit fixes the mode and counts")
	check(p.GS.Attrs.GooseMode == "Coop" and p.GS.Attrs.GooseCoopSide == "Halo" and p.GS.Attrs.GooseCoopTarget == 20,
		"Pending -> co-op for the first eligible faction", show(p.GS.Attrs))
	check(p:AllText(GT.CoopStart.Halo) == 1, "the co-op line is announced when the mode is fixed")
	-- versus: both factions -> the normal tug, 100% / 40%, war points
	local v = gooseWorld({ { "H1", "Halo", 2 }, { "R1", "Horns", 2 } })
	v:Begin()
	check(v.GS.Attrs.GooseMode == "Versus", "both factions present: Versus")
	v:Hit(v.H1, 5, true); v:Hit(v.R1, 3, true)
	local vf = v:End()
	check(vf.Result == "Halo" and vf.Info.Mode == "Versus", "versus winner by totals", show(vf.Info))
	check(v.Gold[v.H1] == select(1, reward(2, "Halo", true, nil)) and v.Gold[v.R1] == select(1, reward(2, "Horns", false, nil)),
		"versus pays 100% / 40%", show({ v.Gold[v.H1], v.Gold[v.R1] }))
	check(#v.War == 1 and v.War[1][1] == "Halo" and v.War[1][2] == G.WinWarPoints, "versus win gives war points", show(v.War))
	-- a rival arriving during co-op pulls 0 and is told once
	local c = gooseWorld({ { "H1", "Halo", 1 } })
	c:Begin()
	local rival = c:Add("R1", "Horns", 1)
	check(c:Hit(rival, 3, true) == 0, "a rival who arrives during co-op pulls 0")
	check(c:NoticeTo(rival, GT.RivalWait.Halo) == 1, "the rival is told once ('다음 거위부터 줄다리기')")
	c:Hit(c.H1, 10, true)
	local cf = c:End()
	check(cf.Result == "Halo" and cf.Rewarded[rival] == nil and c.Gold[rival] == nil and c.GS.Attrs.GooseCoopTarget == 0,
		"the rival is not paid; the co-op side still succeeds", show(cf.Rewarded))
	-- versus whose rival left before the end: judged like co-op (70%, no war points, RivalLeft prefix)
	local l = gooseWorld({ { "H1", "Halo", 1 }, { "R1", "Horns", 1 } })
	l:Begin()
	l:Hit(l.H1, 10, true); l:Hit(l.R1, 3, true)
	l.R1.Parent = nil
	l.Registry.PlayerService.PlayerLeaving:Fire(l.R1)
	local lf = l:End()
	check(lf.Result == "Halo" and lf.Info.Mode == "Coop" and lf.Info.RivalLeft == true and lf.Info.Success == true,
		"rival left: judged by the co-op rule against the remaining headcount", show(lf.Info))
	check(l.Gold[l.H1] == select(1, reward(1, "Halo", true, 0.7)) and #l.War == 0, "rival left: 70%, no war points",
		show({ l.Gold[l.H1], l.War }))
	check(l:AllText(string.format(GT.RivalLeft, GT.CoopResult.Halo)) == 1, "rival left: the result line says why")
end)

------------------------------------------------------------------ C. class change (A23-14 free change below Lv5)
local function classWorld(level, opts)
	opts = opts or {}
	local f = { Notices = {}, Refresh = {}, Resets = 0, TicketCalls = 0, Changed = {} }
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	f.Config = config
	local remotes = {}
	local net = {}
	function net.Get(name)
		if not remotes[name] then remotes[name] = { OnServerEvent = signal() } end
		return remotes[name]
	end
	function net.Notify(_, text, kind) table.insert(f.Notices, { Text = text, Kind = kind }) end
	local util = { Signal = { new = signal }, RateLimit = function() return true end, IsAlive = function() return f.Alive ~= false end,
		Warn = function(tag, msg) table.insert(groupWarnings, tag .. ": " .. tostring(msg)) end }
	local players = { __kind = "Instance", Name = "Players" }
	local p = newPlayer("Changer", 4242, players)
	local data = { Level = level, XP = 7, Class = "Warrior", ClassChosen = true, Faction = "Halo", Tickets = { Class = opts.Tickets or 0 } }
	if opts.NoDataLevel then data.Level = nil end
	p.Attrs = { Class = "Warrior", ClassChosen = true, Level = opts.AttrLevel or level, XP = 7 }
	f.Player, f.Data = p, data
	local env = { game = { GetService = function(_, name)
			if name == "ReplicatedStorage" then return { Shared = { Config = "Config", Util = "Util", Net = "Net" } } end
			error(name)
		end }, typeof = typeofDouble, print = function() end,
		require = function(name)
			if name == "Config" then return config elseif name == "Util" then return util elseif name == "Net" then return net end
			error("unexpected require " .. tostring(name))
		end }
	local ps = { PlayerReady = signal(), IsReady = function() return true end, GetData = function() return data end }
	function ps.SetStat(_, key, value) data[key] = value; p:SetAttribute(key, value) end
	function ps.RefreshCharacter(_, full) table.insert(f.Refresh, full) end
	local registry = { PlayerService = ps,
		ProgressionService = { ResetLevel = function()
			f.Resets += 1
			ps.SetStat(p, "Level", 1)
			ps.SetStat(p, "XP", 0)
		end },
		MonetizationService = { UseTicket = function(_, kind)
			f.TicketCalls += 1
			if (data.Tickets[kind] or 0) > 0 then data.Tickets[kind] -= 1; return true end
			return false, "None"
		end },
		ZoneService = { IsPvPZone = function() return f.PvPZone == true end },
		GrudgeService = { HasSack = function() return false end },
		KaijuService = { GetState = function() return "None" end },
		CombatService = { IsInCombat = function() return f.InCombat == true end },
		FactionService = { GetFaction = function() return "Halo" end } }
	local class = execute("ClassService", CLASS_SOURCE, env)
	class.Init(registry)
	class.Start()
	class.ClassChanged:Connect(function(_, new, old) table.insert(f.Changed, { new, old }) end)
	function f:Change(classId, useTicket) remotes.ChangeClass.OnServerEvent:Fire(p, classId, useTicket) end
	function f:Noticed(text)
		for _, e in self.Notices do if e.Text == text then return true end end
		return false
	end
	return f
end

runGroup("class-change", function()
	local C = CONFIG
	check(C.ClassChange.FreeKeepLevelBelow == 5, "Config.ClassChange.FreeKeepLevelBelow = 5", C.ClassChange.FreeKeepLevelBelow)
	for _, case in { { 1, true }, { 4, true }, { 4.9, true }, { 5, false }, { 30, false }, { "3", true }, { nil, false }, { 0 / 0, false } } do
		check(C.ClassChangeKeepsLevel(case[1]) == case[2], "Config.ClassChangeKeepsLevel(level)", show(case))
	end
	local mageName = C.ClassName("Mage", "Halo")
	-- Lv1-4: a free change keeps level and XP, never spends a ticket, never fully heals
	for level = 1, 4 do
		for _, useTicket in { false, true } do
			local f = classWorld(level, { Tickets = 2 })
			f:Change("Mage", useTicket)
			check(f.Data.Class == "Mage" and f.Data.Level == level and f.Data.XP == 7 and f.Resets == 0,
				"below Lv5 a free change keeps level and XP", show({ level, useTicket, f.Data.Level, f.Data.XP, f.Resets }))
			check(f.TicketCalls == 0 and f.Data.Tickets.Class == 2, "below Lv5 no ticket is ever spent (even when asked)",
				show({ level, useTicket, f.TicketCalls }))
			check(#f.Refresh == 1 and f.Refresh[1] == false, "keep-level change keeps the HP fraction (no free full heal)", show(f.Refresh))
			check(f:Noticed(string.format(C.Text.ClassChangedFreeKeep, mageName, 5)), "ClassChangedFreeKeep notice (Lv5 전이라 레벨 유지)")
			check(#f.Changed == 1 and f.Changed[1][1] == "Mage" and f.Changed[1][2] == "Warrior", "ClassChanged fired once")
		end
	end
	-- Lv5+: free = Lv1 / XP 0; ticket = level kept
	for _, level in { 5, 6, 30 } do
		local f = classWorld(level)
		f:Change("Archer", false)
		check(f.Data.Class == "Archer" and f.Data.Level == 1 and f.Data.XP == 0 and f.Resets == 1,
			"from Lv5 a free change goes back to Lv1 / XP 0 (old rule)", show({ level, f.Data.Level, f.Resets }))
		check(f.Refresh[1] == true and f:Noticed(string.format(C.Text.ClassChangedFree, C.ClassName("Archer", "Halo"))),
			"level-losing change: full refresh and ClassChangedFree notice")
		local t = classWorld(level, { Tickets = 1 })
		t:Change("Archer", true)
		check(t.Data.Class == "Archer" and t.Data.Level == level and t.Data.XP == 7 and t.Resets == 0 and t.Data.Tickets.Class == 0
			and t.TicketCalls == 1, "from Lv5 a ticket change keeps the level and spends one ticket", show({ level, t.Data.Level }))
		check(t:Noticed(string.format(C.Text.ClassChangedTicket, C.ClassName("Archer", "Halo"))), "ClassChangedTicket notice")
		local none = classWorld(level, { Tickets = 0 })
		none:Change("Archer", true)
		check(none.Data.Class == "Warrior" and none.Data.Level == level and none.Resets == 0, "no ticket: refused, nothing changes")
	end
	-- the level is read from the save first, the attribute only as a fallback; broken values count as Lv1 (keep)
	local attr = classWorld(nil, { NoDataLevel = true, AttrLevel = 3 })
	attr:Change("Mage", false)
	check(attr.Resets == 0 and attr.Data.Class == "Mage", "no saved level: the Level attribute (3) decides -> keep")
	local attrHigh = classWorld(nil, { NoDataLevel = true, AttrLevel = 12 })
	attrHigh:Change("Mage", false)
	check(attrHigh.Resets == 1, "no saved level: Level attribute 12 -> the old reset rule")
	local broken = classWorld(0 / 0)
	broken:Change("Mage", false)
	check(broken.Resets == 0 and broken.Data.Class == "Mage", "NaN level counts as Lv1 -> keep")
	-- the other guards still refuse first
	local cases = {
		{ "same class", function(f) f:Change("Warrior", false) end },
		{ "in PvP combat", function(f) f.InCombat = true; f:Change("Mage", false) end },
		{ "in a PvP zone", function(f) f.PvPZone = true; f:Change("Mage", false) end },
		{ "dead", function(f) f.Alive = false; f:Change("Mage", false) end },
		{ "bad class id", function(f) f:Change("Dragon", false) end },
		{ "non-boolean ticket flag", function(f) f:Change("Mage", "yes") end },
	}
	for _, case in cases do
		local f = classWorld(3)
		case[2](f)
		check(f.Data.Class == "Warrior" and f.Data.Level == 3 and #f.Changed == 0 and #f.Refresh == 0, "refused: " .. case[1])
	end
	check(string.find(C.Text.ClassChangeRuleF, "%d", 1, true) ~= nil and string.format(C.Text.ClassChangeRuleF, 5) ~= C.Text.ClassChangeRuleF,
		"ClassPicker footer text takes the Lv5 number from Config")
end)

------------------------------------------------------------------ summary
local list = {}
for _, key in order do
	local r = results[key]
	table.insert(list, { Group = r.Group, Name = r.Name, Pass = r.Pass, Fail = r.Fail, FirstFailure = r.First })
end
local function enc(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return tostring(v) end
	if t == "number" then return (v == math.floor(v) and math.abs(v) < 2 ^ 53) and string.format("%d", v) or string.format("%.17g", v) end
	if t == "string" then
		return '"' .. string.gsub(v, '[%c"\\]', function(c)
			return ({ ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\t"] = "\\t", ["\r"] = "\\r" })[c] or string.format("\\u%04x", string.byte(c))
		end) .. '"'
	end
	if #v > 0 or next(v) == nil then
		local parts = {}
		for _, x in ipairs(v) do table.insert(parts, enc(x)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do table.insert(keys, k) end
	table.sort(keys)
	local parts = {}
	for _, k in keys do table.insert(parts, enc(tostring(k)) .. ":" .. enc(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end
print("A23_14_RESULT_JSON " .. enc({ Checks = total, Failed = failedCount, Named = list, Findings = findings }))
if failedCount == 0 then
	print("A23_14_OFFLINE_OK checks=" .. total .. " Studio/API calls=0")
else
	print("A23_14_OFFLINE_FAILED checks=" .. total .. " failed=" .. failedCount)
end
