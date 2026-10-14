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
	if opts and opts.Gate == false then config.Daily.IntroGate = false end
	-- A23-113 #8: from Lv10 one daily is not hunting; the older groups drive kill / skill / gold sets only (NoNonHunt = the old draw)
	if opts and opts.NoNonHunt then config.Quests.NonHuntFrom = 1000000 end
	if opts and opts.EditConfig then opts.EditConfig(config) end
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
				if name == "Quests" then
					f.LastJson = payload
					f.QuestSends = (f.QuestSends or 0) + 1
					-- A23-81: the payload is { Quests = rows, Book } (the JSONEncode double saw the book last)
					if type(payload) == "table" and type(payload.Quests) == "table" then f.LastList = deepCopy(payload.Quests) end
				end
			end }
		end
		return remotes[name]
	end
	function net.Notify(_, text, kind) table.insert(f.Notices, { Text = text, Kind = kind }) end
	function net.NotifyAll() end
	function net.Fx() end
	-- gameplay plan 1-A #3: QuestService reads the next egg hunt (GooseNextAt / GooseActive); by default it starts in 30 minutes
	function net.GameState()
		return { GetAttribute = function(_, key)
			if key == "GooseActive" then return opts ~= nil and opts.GooseActive == true end
			if key == "GooseNextAt" then return f.Now + ((opts and opts.GooseIn) or 1800) end
			return nil
		end }
	end
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
	-- A23-104: the daily jobs open after the intro quest; every world but the "daily-intro" group's starts past it
	if not (opts and opts.Intro == false) then data.DailyIntro = true end
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
	function prog.AddXP(p, amount, cap)
		if cap ~= nil then amount = math.min(amount, math.max(0, math.floor(cap))) end -- the real AddXP's cap (after the pass)
		table.insert(f.Pays, { XP = amount, Cap = cap })
		ps.AddStat(p, "XP", amount)
		return amount
	end
	local registry = { PlayerService = ps, DataService = ds, ProgressionService = prog,
		MonsterService = { MonsterKilled = signal() }, CombatService = { Released = signal() },
		GooseService = { GooseFinished = signal() }, PvPService = { PlayerKO = signal(),
			IsRookie = function() return not (opts and opts.Graduated) end },
		KaijuService = { KaijuEnded = signal() }, StoryQuestService = { QuestDone = signal() }, Deeds = { Booked = signal() },
		GatherService = { Gathered = signal() }, CraftService = { Crafted = signal() }, -- artisan min ④
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
	function f:ClaimVacation() remotes.ClaimVacation.OnServerEvent:Fire(self.Player) end
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
-- A23-71: a rookie row has learned Q (SkillSlots 1, e.g. kept after a level reset), so the kill / skill / gold daily sets
-- below keep their meaning at Lv1-4; the "a23-71 skill dailies" group passes SkillSlots = 0 for a player without Q
local function rookieRow(level, faction, extra)
	local row = { Version = 3, Level = level, Faction = faction or "Halo", ClassChosen = true, Class = "Warrior",
		TutorialStep = 99, BlacksmithVisited = true, WeaponTier = 1, WeaponOwnedMask = 1, SkillSlots = 1, SkillsA71 = true }
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
	-- artisan min ④: the guild's rows (Gather / Craft) are Neutral-only and switched; every player has kill / skill / gold
	local plain = 0
	for id in ids do if id ~= "Gather" and id ~= "Craft" then plain += 1 end end
	check(ids.Kill and ids.Release and ids.Gold and plain == 3, "newbie pool = three different goals (kill / skill / gold) + the guild's rows",
		show(ids))
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
	check(need == 962, "Lv1 -> Lv10 needs 962 XP (Config.XPToNext, EarlyMult 0.35 below Lv10; gameplay plan 1-A #4)", need)
	check(dayXP == 600 and dayXP < need, "one day's newbie set pays 600 XP < 962 (no Lv10 from one day of dailies)", dayXP)
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
	-- 최종 검수 10/13: the XP of a missed early day x EarlyMult / 0.5 (0.35 / 0.5 = 0.7): 600 x 0.7 x 0.7 = 294
	check(vg < 360 and vx < 600 and vg >= 251 and vx == 294, "a missed Lv1-9 day (70% of 10 minutes, XP x 0.7 for EarlyMult 0.35) pays less than a played day (360 + 600)",
		show({ vg, vx }))
	-- documented value (Config comments / fix report): 70% of 360 gold = 252. math.floor(360 * 0.7) gives 251 in floating point.
	check(vg == 252, "a missed Lv1-9 day pays exactly the documented 252 gold (70% of 360; float floor must not lose 1 gold)",
		show({ vg, vx }))
	local _, v3 = CONFIG.VacationReward(1, 3)
	check(v3 == 882 and v3 < need, "3 missed days (max) = 882 XP < 962 (no Lv10 from vacation alone; the claim cap keeps it)", v3)
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
				-- 검수 2026-10-07: the sent rows carry their template's ShortName (the phone quest row, <= 14)
				local sentDaily = 0
				for _, row in f.LastList or {} do
					if row.Kind == "Daily" then
						sentDaily += 1
						local want = TEMPLATE[row.Id] and TEMPLATE[row.Id].ShortName
						check(type(want) == "string" and #want <= 14 and row.ShortName == want,
							"a sent daily row carries its template's ShortName", show({ row.Id, row.ShortName, want }))
					end
				end
				check(sentDaily == 3, "the sent list holds the three dailies", sentDaily)
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

------------------------------------------------------------------ A23-71: no "Skill hits" daily before the first skill
runGroup("a23-71 skill dailies", function()
	local function idsOf(f)
		local ids = {}
		for _, q in f.Data.Quests do ids[q.Id] = (ids[q.Id] or 0) + 1 end
		return ids
	end
	for _, level in { 1, 3, 4 } do
		for seed = 1, 12 do
			local f = questWorld(rookieRow(level, "Halo", { SkillSlots = 0 }), seed * 37 + level)
			local ids = idsOf(f)
			check(#f.Data.Quests == 3 and ids.Release == nil and (ids.Kill or 0) + (ids.Gold or 0) == 3,
				"Lv1-4 without a skill: three dailies, none of them 'Skill hits'", "Lv" .. level .. " " .. show(ids))
			-- S9 / D3: the set is always King Slime 3 + Slime 12-15 + Gold (the King Slime row never twice)
			local king, slimes, gold = 0, 0, 0
			for _, q in f.Data.Quests do
				if q.Id == "Kill" and q.Unit == "BigSlime" and q.Target == 3 then king += 1 end
				if q.Id == "Kill" and q.Unit == "Slime" and (q.Target == 12 or q.Target == 15) then slimes += 1 end
				if q.Id == "Gold" then gold += 1 end
			end
			check(king == 1 and slimes == 1 and gold == 1, "Lv1-4 without a skill: King Slime 3 + Slime 12-15 + Gold (S9)",
				"Lv" .. level .. " seed " .. seed .. " " .. show(f.Data.Quests))
		end
	end
	-- A23-193: Lv5 makes Q ready, the teacher teaches it: the skill daily comes once Q is learned (saved slots 1)
	for seed = 1, 8 do
		local ids = idsOf(questWorld(rookieRow(5, "Horns", { SkillSlots = 0 }), seed * 53))
		check(ids.Release == nil and (ids.Kill or 0) + (ids.Gold or 0) == 3, "Lv5 before the teacher: no 'Skill hits' daily", show(ids))
		ids = idsOf(questWorld(rookieRow(5, "Horns", { SkillSlots = 1 }), seed * 53))
		check(ids.Release == 1 and ids.Kill == 1 and ids.Gold == 1, "Lv5 with Q learned: kill / skill / gold again", show(ids))
	end
	-- a Lv3 who kept Q after a level reset (saved slots 1) keeps the full set
	local kept = idsOf(questWorld(rookieRow(3, "Halo", { SkillSlots = 1 }), 11))
	check(kept.Release == 1 and kept.Kill == 1 and kept.Gold == 1, "a Lv3 who kept Q: kill / skill / gold", show(kept))
	-- an old save (no SkillsA71) gets its slots once from its level and rebirths
	local function oldRow(level, slots, extra)
		local row = rookieRow(level, "Halo", extra)
		row.SkillsA71, row.SkillSlots = nil, slots
		return row
	end
	local o8 = questWorld(oldRow(8, 3), 5)
	check(o8.Data.SkillSlots == 1 and o8.Data.SkillsA71 == true, "an old Lv8 save with 3 slots: Q only after the fix",
		show({ o8.Data.SkillSlots, o8.Data.SkillsA71 }))
	check(questWorld(oldRow(3, 1), 6).Data.SkillSlots == 0, "an old Lv3 save with Q: none (Q comes at Lv5)")
	check(questWorld(oldRow(1, 1, { Rebirths = 1 }), 7).Data.SkillSlots == 3, "an old reborn save: all three")
	check(questWorld(oldRow(30, 2), 8).Data.SkillSlots == 3, "an old Lv30 save: all three (Lv25)")
	-- the fix runs once: a level reset after it (Lv1, saved 1) keeps Q
	local again = deepCopy(o8:SaveAndReload())
	again.Level = 1
	local o8b = questWorld(again, 12)
	check(o8b.Data.SkillSlots == 1 and o8b.Data.SkillsA71 == true, "the fix runs once: a later level reset keeps Q",
		show({ o8b.Data.SkillSlots }))
	-- an unfinished skill daily saved before the rule is remade at join (same reward); a finished one stays to be claimed
	local function withQuests(release)
		local row = oldRow(3, 1)
		row.DailyDay, row.DailyLevel = today(), 3
		row.Quests = {
			release,
			{ Id = "Kill", Kind = "Daily", Target = 12, Progress = 0, RewardGold = 72, RewardXP = 120, Text = "x", Unit = "Slime" },
			{ Id = "Gold", Kind = "Daily", Target = 40, Progress = 0, RewardGold = 72, RewardXP = 120, Text = "x", Unit = "Slime" },
		}
		return row
	end
	local r = questWorld(withQuests({ Id = "Release", Kind = "Daily", Target = 3, Progress = 1, RewardGold = 999,
		RewardXP = 888, Text = "x", Unit = "Slime" }), 13)
	local q1 = r.Data.Quests[1]
	check(q1.Id ~= "Release" and q1.Kind == "Daily" and q1.RewardGold == 999 and q1.RewardXP == 888,
		"an unfinished skill daily without a skill: remade at join, the reward kept", show(q1))
	check(q1.Id == "Kill" and q1.Unit == "BigSlime" and q1.Target == 3,
		"the remade daily is the King Slime row (S9: slimes and gold are taken)", show(q1))
	local sent = false
	for _, row in r.LastList or {} do if row.Id == "Release" then sent = true end end
	check(not sent, "the remade daily is what the list shows", show(r.LastList))
	local r2 = questWorld(withQuests({ Id = "Release", Kind = "Daily", Target = 3, Progress = 3, RewardGold = 999,
		RewardXP = 888, Text = "x", Unit = "Slime" }), 14)
	check(r2.Data.Quests[1].Id == "Release" and r2.Data.Quests[1].Progress == 3, "a finished skill daily stays (claimable)",
		show(r2.Data.Quests[1]))
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

runGroup("vacation never reaches Lv10 (A23-14)", function()
	-- 최종 검수 10/13: EarlyMult 0.35 stays; below Lv10 a vacation claim's XP stops one XP short of Lv10 (after the 2x pass:
	-- the cap goes to ProgressionService.AddXP)
	local function room(level, xp)
		local r = -xp - 1
		for l = level, 9 do r += CONFIG.XPToNext(l) end
		return math.max(0, r)
	end
	for _, case in { { 1, 0 }, { 5, 10 }, { 8, 150 }, { 9, 0 }, { 9, CONFIG.XPToNext(9) - 5 } } do
		local level, xp = case[1], case[2]
		local f = questWorld(rookieRow(level, "Halo"), 900 + level * 7 + xp)
		f.Data.XP = xp
		local g3, x3 = CONFIG.VacationReward(level, 3)
		f.Data.VacationDays, f.Data.VacationGold, f.Data.VacationXP = 3, g3, x3
		f.Pays = {}
		f:ClaimVacation()
		local paidX, cap = 0, false
		for _, e in f.Pays do
			if e.XP then paidX += e.XP; cap = e.Cap end
		end
		local want = math.min(x3, room(level, xp))
		check(paidX == want and cap == room(level, xp) and f.Data.VacationDays == 0,
			"Lv" .. level .. " with " .. xp .. " XP: the claim pays min(" .. x3 .. ", room " .. room(level, xp) .. ") and caps AddXP there",
			show({ paidX, want, cap }))
		check(xp + paidX < room(level, 0) + 1, "... so the vacation alone ends below Lv10", show({ xp, paidX }))
	end
	-- Lv10+: no cap (the woods day pays in full)
	local w = questWorld(rookieRow(12, "Halo"), 977)
	local g12, x12 = CONFIG.VacationReward(12, 3)
	w.Data.VacationDays, w.Data.VacationGold, w.Data.VacationXP = 3, g12, x12
	w.Pays = {}
	w:ClaimVacation()
	local paid, capped = 0, false
	for _, e in w.Pays do
		if e.XP then paid += e.XP; capped = e.Cap ~= nil end
	end
	check(paid == x12 and not capped, "Lv12: the vacation pays its whole XP, no cap", show({ paid, x12 }))
	-- the shown amount stops there too (a Lv9 rookie away 3 days)
	local s = questWorld(rookieRow(9, "Halo", { XP = 200, DailyDay = today() - 4, DailyClaims = 0, DailyLevel = 9, Quests = {} }), 978)
	check(s.Data.VacationDays == 3 and s.Data.VacationXP == math.min(select(2, CONFIG.VacationReward(9, 3)), room(9, 200)),
		"the vacation panel shows the capped XP below Lv10", show({ s.Data.VacationDays, s.Data.VacationXP, room(9, 200) }))
end)

runGroup("dailies-day-change", function()
	-- a whole missed rookie day: vacation in the newbie band
	local f = questWorld(rookieRow(1, "Halo", { DailyDay = today() - 2, DailyClaims = 0, DailyLevel = 1, Quests = {} }), 11)
	local wantG, wantX = CONFIG.VacationReward(1, 2)
	check(f.Data.VacationDays == 2 and f.Data.VacationGold == wantG and f.Data.VacationXP == wantX and wantX == 588,
		"2 missed rookie days = VacationReward(1, 2) in the newbie band (588 XP: 840 x 0.7 for EarlyMult 0.35)", show({ f.Data.VacationDays, f.Data.VacationGold, f.Data.VacationXP }))
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
		local g = questWorld(rookieRow(level, "Halo"), seed, { NoNonHunt = true })
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

------------------------------------------------------------------ A23-113 #8: one daily that is not hunting (+ the Choice daily)
local function nonHuntCount(f)
	local n = 0
	for _, q in f.Data.Quests do
		local t = TEMPLATE[q.Id]
		if t and t.NonHunt == true then n += 1 end
	end
	return n
end

runGroup("dailies-nonhunt (A23-113 #8)", function()
	local W = CONFIG.Quests
	check(W.NonHuntFrom == 10, "the guarantee starts at Lv10", tostring(W.NonHuntFrom))
	for _, id in { "Goose", "Hunt", "Plunder", "Choice" } do
		check(TEMPLATE[id] and TEMPLATE[id].NonHunt == true, id .. " is a non-hunting template", id)
	end
	for _, id in { "Kill", "Golden", "Gold", "Release" } do
		check(TEMPLATE[id] and not TEMPLATE[id].NonHunt, id .. " is hunting", id)
	end
	local C = TEMPLATE.Choice
	check(C and C.DailyUnits[1] == 1 and C.Text == "Make a kind or sneaky choice" and #C.ShortName <= 14, "Choice: one choice, its text, a short name", show(C))
	local row
	for _, r in W.Woods.Dailies do if r.Id == "Choice" then row = r end end
	check(row ~= nil and row.Targets[1] == 1 and #row.Targets == 1, "the woods band has a Choice row (target 1)", show(row))
	-- no choice source on (the beta default): never a Choice daily; Lv10+ still has a non-hunting one for a side player
	for _, faction in { "Halo", "Horns" } do
		for _, level in { 10, 17, 24, 30, 60 } do
			for seed = 1, 30 do
				local f = questWorld(rookieRow(level, faction), seed * 97 + level, { Graduated = level >= 15 })
				check(#f.Data.Quests == 3 and nonHuntCount(f) >= 1, "Lv" .. level .. " " .. faction .. ": at least one of the 3 is not hunting",
					show({ f.Data.Quests[1].Id, f.Data.Quests[2].Id, f.Data.Quests[3].Id }))
				for _, q in f.Data.Quests do check(q.Id ~= "Choice", "no choice source on: no Choice daily", q.Id) end
				local ids = {}
				for _, q in f.Data.Quests do ids[q.Id] = true end
				check(count(ids) == 3, "... and the three goals still differ", show(ids))
			end
		end
	end
	-- the rule is for the LAST slot only: a hunting first slot stays the usual draw (Goose is 1 in ~12 of a Lv12 draw, so it
	-- opens a set in a small share of sets, never in all of them)
	local first, total = 0, 0
	for seed = 1, 60 do
		local f = questWorld(rookieRow(12, "Halo"), seed * 211)
		total += 1
		local t = TEMPLATE[f.Data.Quests[1].Id]
		if t and t.NonHunt == true then first += 1 end
	end
	check(first <= total * 0.4, "the first slot is not forced to be non-hunting (" .. first .. " of " .. total .. ")", tostring(first))
	-- ... and only when the other two both hunt: a set that already has a non-hunting slot draws its last slot as usual (so the
	-- last slot is non-hunting in most of those sets only by the usual odds, not in all of them)
	local natural, both = 0, 0
	for seed = 1, 400 do
		local f = questWorld(rookieRow(17, "Halo"), seed * 37, { Graduated = true })
		local q = f.Data.Quests
		local function nh(i) local t = TEMPLATE[q[i].Id]; return t ~= nil and t.NonHunt == true end
		if nh(1) or nh(2) then
			natural += 1
			if nh(3) then both += 1 end
		end
	end
	check(natural >= 10 and both <= natural * 0.8, "a set with a non-hunting slot among the first two does not always get a third (" .. both .. " of " .. natural .. ")",
		show({ natural, both }))
	-- 검수 2026-10-10: the goose daily is never made two days running (GooseDay = the KST day of the last one); the rule is
	-- "one non-hunting daily if one fits": a rested goose with nothing else that fits leaves three hunting dailies
	check(W.GooseRestDays == 1 and CONFIG.Data.Defaults.GooseDay == 0, "the goose rests 1 day; GooseDay is a save field (default 0)", show({ W.GooseRestDays, CONFIG.Data.Defaults.GooseDay }))
	local geese, oldGeese = 0, 0
	for _, level in { 12, 17, 40 } do
		for seed = 1, 40 do
			local f = questWorld(rookieRow(level, "Halo", { GooseDay = today() - 1 }), seed * 5 + level, { Graduated = false })
			local i, q = f:Slot("Goose")
			check(q == nil and f.Data.GooseDay == today() - 1, "Lv" .. level .. ": a goose daily yesterday: none today (the day mark stays)", show({ f.Data.Quests[1].Id, f.Data.Quests[2].Id, f.Data.Quests[3].Id }))
			check(#f.Data.Quests == 3, "... and still three dailies", tostring(#f.Data.Quests))
			local g = questWorld(rookieRow(level, "Halo", { GooseDay = today() - 2 }), seed * 5 + level, { Graduated = false })
			if g:Slot("Goose") then
				oldGeese += 1
				check(g.Data.GooseDay == today(), "a goose daily made today marks GooseDay", tostring(g.Data.GooseDay))
			end
			local h = questWorld(rookieRow(level, "Halo", { GooseDay = today() }), seed * 5 + level, { Graduated = false })
			if h:Slot("Goose") then geese += 1 end
		end
	end
	check(oldGeese >= 60 and geese >= 60, "two days after (and the same day) the goose is allowed again, and it is the usual last-slot pick (" .. oldGeese .. ", " .. geese .. " of 120)", show({ oldGeese, geese }))
	-- the day after a goose day, through the real day check
	local day2 = questWorld(rookieRow(12, "Halo"), 4242, { Graduated = false })
	local _, gq = day2:Slot("Goose")
	check(gq ~= nil and day2.Data.GooseDay == today(), "a Lv12 Halo day: the last slot is the goose and it is marked", show({ day2.Data.Quests[1].Id, day2.Data.Quests[2].Id, day2.Data.Quests[3].Id }))
	day2.Data.DailyDay = today() - 1
	day2.Data.GooseDay = today() - 1
	day2.Quest.DayCheck(day2.Player)
	check(day2:Slot("Goose") == nil and #day2.Data.Quests == 3, "the next day: no goose daily (three hunting dailies, nothing else fits)", show({ day2.Data.Quests[1].Id, day2.Data.Quests[2].Id, day2.Data.Quests[3].Id }))
	-- the PvP kinds are drawn rarely, so a forced non-hunting slot is not often a fight with a player
	for _, level in { 17, 40 } do
		local sets, pvp, goose = 0, 0, 0
		for seed = 1, 300 do
			local f = questWorld(rookieRow(level, "Halo"), seed * 29 + 7 + level, { Graduated = true })
			sets += 1
			if f:Slot("Hunt") then pvp += 1 end
			if f:Slot("Goose") then goose += 1 end
		end
		check(pvp <= sets * 0.36 and goose > pvp, "Lv" .. level .. " Halo: a PvP daily in at most 36% of the sets, the goose more often (" .. pvp .. " Hunt, " .. goose .. " Goose of " .. sets .. ")", show({ pvp, goose, sets }))
	end
	-- the guild (Neutral) has no Goose / PvP: nothing non-hunting fits, the set is drawn as before
	for seed = 1, 20 do
		local f = questWorld(rookieRow(17, "Neutral"), seed * 53)
		check(nonHuntCount(f) == 0 and #f.Data.Quests == 3, "Neutral with no choice source: all hunting, unchanged", show({ f.Data.Quests[1].Id, f.Data.Quests[2].Id, f.Data.Quests[3].Id }))
	end
	-- gameplay plan 2026-10-13 1-A #3: a goose daily only while the next egg hunt starts within GooseWindow (or one is on), and
	-- the PvP kinds (Hunt / Plunder) are never the forced non-hunting slot (A23-113)
	check(W.GooseWindow == 3600, "Config.Quests.GooseWindow = 3600 s (the hunt comes every 4 hours)", tostring(W.GooseWindow))
	local farHunt, farAll, onGoose, nearGoose = 0, 0, 0, 0
	for _, level in { 12, 17, 40 } do
		for seed = 1, 40 do
			local far = questWorld(rookieRow(level, "Halo"), seed * 13 + level, { Graduated = true, GooseIn = 3 * 3600 })
			check(far:Slot("Goose") == nil and #far.Data.Quests == 3 and far.Data.GooseDay == 0,
				"Lv" .. level .. ": the next hunt 3 hours away: no goose daily (and no GooseDay mark)",
				show({ far.Data.Quests[1].Id, far.Data.Quests[2].Id, far.Data.Quests[3].Id }))
			if far:Slot("Hunt") then farHunt += 1 end
			if nonHuntCount(far) == 0 then farAll += 1 end
			local on = questWorld(rookieRow(level, "Halo"), seed * 13 + level, { Graduated = true, GooseIn = 3 * 3600, GooseActive = true })
			if on:Slot("Goose") then onGoose += 1 end
			local near = questWorld(rookieRow(level, "Halo"), seed * 13 + level, { Graduated = true, GooseIn = 3000 })
			if near:Slot("Goose") then nearGoose += 1 end
		end
	end
	check(farHunt <= 120 * 0.36 and farAll >= 60, "goose far: the PvP daily is never forced into the last slot (" .. farHunt
		.. " Hunt of 120; " .. farAll .. " sets all hunting)", show({ farHunt, farAll }))
	check(onGoose >= 60 and nearGoose >= 60, "a hunt on now, or one within the window: the goose daily is the usual last-slot pick (" .. onGoose
		.. ", " .. nearGoose .. " of 120)", show({ onGoose, nearGoose }))
	-- Lv1-9 is not touched: no non-hunting row, ever
	for _, level in { 1, 5, 9 } do
		for seed = 1, 20 do
			local f = questWorld(rookieRow(level, "Halo"), seed * 31)
			check(nonHuntCount(f) == 0, "Lv" .. level .. ": the meadow set of 3 is unchanged (all hunting)", show({ f.Data.Quests[1].Id, f.Data.Quests[2].Id, f.Data.Quests[3].Id }))
		end
	end
	-- a choice source on: the Choice daily appears (woods band and Lv25+), it is a normal paid daily
	local seen, seenHigh = 0, 0
	for _, level in { 12, 40 } do
		for seed = 1, 80 do
			local f = questWorld(rookieRow(level, "Neutral"), seed * 71 + level, { Graduated = true, EditConfig = function(c) c.LostFound.Enabled = true end })
			local i, q = f:Slot("Choice")
			if q then
				if level == 12 then seen += 1 else seenHigh += 1 end
				local wantG, wantX
				if level < 25 then wantG, wantX = CONFIG.HuntValue(level, W.Woods.RewardMinutes) else wantG, wantX = CONFIG.DailyQuestReward(level) end
				check(q.Kind == "Daily" and q.Target == 1 and q.Progress == 0 and q.Text == "Make a kind or sneaky choice" and q.RewardGold == wantG and q.RewardXP == wantX,
					"Lv" .. level .. ": the Choice daily is one choice, paid like any daily of its band", show({ q.Target, q.Progress, q.Text, q.RewardGold, wantG }))
				check(nonHuntCount(f) >= 1, "(and the Choice slot is the non-hunting one)", "")
			end
		end
	end
	check(seen > 0 and seenHigh > 0, "with a choice source on the Choice daily shows up (Lv12 and Lv40; the guild has no other non-hunting kind)", show({ seen, seenHigh }))
	-- the Board switch, a kill card, the lost things: each is a source on its own
	for label, edit in {
		Board = function(c) c.Board.Enabled = true end,
		LostFound = function(c) c.LostFound.Enabled = true end,
		KillCard = function(c) c.KillCards.FlowerPatch.Enabled = true end,
	} do
		local got = false
		for seed = 1, 120 do
			local f = questWorld(rookieRow(12, "Neutral"), seed * 13, { EditConfig = edit })
			if f:Slot("Choice") then got = true break end
		end
		check(got, label .. " on: the Choice daily can be made", label)
	end
	-- progress: a deed (Deeds.Booked, any caller of Deeds.Add) fills it; other quests / bad players do nothing
	local g
	for seed = 1, 200 do
		local f = questWorld(rookieRow(12, "Neutral"), seed * 13 + 1, { EditConfig = function(c) c.LostFound.Enabled = true end })
		if f:Slot("Choice") then g = f break end
	end
	check(g ~= nil, "a Lv12 world with a Choice daily")
	if g then
		local i, q = g:Slot("Choice")
		local others = 0
		for _, o in g.Data.Quests do others += o.Progress end
		g.Registry.Deeds.Booked:Fire(nil, "Good", 1, true)
		g.Registry.Deeds.Booked:Fire("x", "Good", 1, true)
		check(q.Progress == 0, "a bad player does nothing", q.Progress)
		g.Registry.Deeds.Booked:Fire(g.Player, "Evil", 0, false) -- a naughty pick that took nothing is still a choice
		check(q.Progress == 1 and q.Progress >= q.Target, "a deed fills the Choice daily (even a pick that moved no points)", show({ q.Progress, q.Target }))
		local before = {}
		for _, o in g.Data.Quests do before[o.Id] = o.Progress end
		g.Registry.Deeds.Booked:Fire(g.Player, "Good", 1, true)
		check(q.Progress == 1, "a finished Choice stays at its target", q.Progress)
		g.Now += 2
		g:Claim(i)
		local gold = g:Paid()
		check(gold > 0, "the Choice daily can be claimed and pays", tostring(gold))
	end
	-- a saved Choice daily is remade when its source goes off (the next time the player loads)
	local r
	for seed = 1, 200 do
		local f = questWorld(rookieRow(12, "Neutral"), seed * 13 + 2, { EditConfig = function(c) c.LostFound.Enabled = true end })
		if f:Slot("Choice") then r = f break end
	end
	if r then
		r.Config.LostFound.Enabled = false
		r.PS.PlayerReady:Fire(r.Player, r.Data)
		check(r:Slot("Choice") == nil and #r.Data.Quests == 3, "the source went off: the unfinished Choice daily is remade as another kind", show({ r.Data.Quests[1].Id, r.Data.Quests[2].Id, r.Data.Quests[3].Id }))
	end
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
	local extraRow = slotOf(off.LastList, ki)
	check(extraRow and TEMPLATE[extraRow.Id] and extraRow.ShortName == TEMPLATE[extraRow.Id].ShortName,
		"the extra row carries its template's ShortName", show(extraRow))
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
	local f = { Now = 5000, Clock = 100, Notices = {}, All = {}, Fx = {}, Gold = {}, XP = {}, War = {}, Finished = {}, Paid = {}, Players = {},
		GS = {}, Loop = nil }
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	-- A23-131: these groups test the tug (Mode "Tug" must keep working); the egg hunt has tools/test_golden_egg.py
	config.Goose.Mode = "Tug"
	f.Config = config
	local gs = { Parent = {}, Attrs = {} }
	function gs:SetAttribute(k, v) self.Attrs[k] = v end
	function gs:GetAttribute(k) return self.Attrs[k] end
	f.GS = gs
	local net = { GameState = function() return gs end }
	function net.Notify(p, text, kind) table.insert(f.Notices, { Player = p, Text = text, Kind = kind }) end
	function net.NotifyAll(text, kind, duration) table.insert(f.All, { Text = text, Kind = kind, Duration = duration }) end
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
	-- HealthService (2026-10-09): one GooseRewarded(player, { Won, Rare, Gold, XP, Level, Mode }) per paid player
	goose.GooseRewarded:Connect(function(p, info)
		table.insert(f.Paid, { P = p, Info = info })
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
-- A23-130 (user 2026-10-11): the start is one short "Golden Goose!" banner for 2 s, once, in every mode (no co-op band)
local function startLine(f)
	local n, ok = 0, true
	for _, e in f.All do
		if e.Text == GT.Start then
			n += 1
			ok = ok and e.Kind == "announce" and e.Duration == 2
		end
		if string.find(e.Text, "Only ", 1, true) or string.find(e.Text, "landed in the Crossroads", 1, true) then ok = false end
	end
	return n == 1 and ok
end

runGroup("goose-start-line", function()
	check(GT.Start == "Golden Goose!" and G.StartSeconds == 2, "Config.Goose.Text.Start = 'Golden Goose!', StartSeconds = 2",
		show({ GT.Start, G.StartSeconds }))
	check(GT.CoopStart == nil and CONFIG.Story.GooseStart == nil, "the old start texts are gone (co-op band, tug two-liner)")
end)

runGroup("goose-coop", function()
	check(G.CoopPerPerson == 20 and G.CoopWinShare == 0.7 and G.MinManualHits == 3, "Config.Goose co-op numbers 20 / 0.7 / 3 manual hits",
		show({ G.CoopPerPerson, G.CoopWinShare, G.MinManualHits }))
	-- solo Halo: co-op, target 20, success at 70%, no war points, no cheer star
	local f = gooseWorld({ { "H1", "Halo", 1 } })
	f:Begin()
	local A = f.GS.Attrs
	check(A.GooseActive == true and A.GooseMode == "Coop" and A.GooseCoopSide == "Halo" and A.GooseCoopTarget == 20
		and A.GooseCoopPeople == 1, "only Halo on the server: GameState GooseMode Coop / Halo / target 20 / 1 person", show(A))
	check(startLine(f), "co-op start: one short line for 2 s (A23-130, no co-op band)", show(f.All))
	check(f:Hit(f.H1, 9, true) == 18, "manual hits pull ManualCount 2 each", A.GooseRescue)
	f:Tick()
	check(f:AllText(string.format(GT.CoopFull.Halo, G.MinManualHits)) == 0, "no 'gauge full' line before the target")
	f:Hit(f.H1, 1, true)
	f:Tick(); f:Tick()
	-- A23-130 (server text verdicts 2026-10-11): only the top bar says it (no 'gauge full' / result banners)
	check(f:AllText(string.format(GT.CoopFull.Halo, G.MinManualHits)) == 0, "no 'gauge full' line (the top bar shows it)")
	check(f.Goose.IsActive(), "a full gauge does not end the event early")
	local fin = f:End()
	local g, x = reward(1, "Halo", true, 0.7)
	local fullG, fullX = reward(1, "Halo", true, nil)
	check(f.Gold[f.H1] == g and f.XP[f.H1] == x and g < fullG and g == math.floor(select(1, CONFIG.HuntValue(1, 10)) * G.OffShare * 0.7),
		"co-op success pays 70% of the winner reward", show({ f.Gold[f.H1], f.XP[f.H1], fullG, fullX }))
	check(#f.War == 0, "co-op never gives war points", show(f.War))
	local pay = f.Paid[1]
	check(#f.Paid == 1 and pay.P == f.H1 and pay.Info.Won == true and pay.Info.Rare == false and pay.Info.Gold == g and pay.Info.XP == x
		and pay.Info.Level == 1 and pay.Info.Mode == "Coop", "GooseRewarded: the paid player, won, gold / XP as paid, level, Mode Coop",
		show(pay and pay.Info))
	check(f.H1.Data.CheerStars == 0, "co-op success gives no cheer star", f.H1.Data.CheerStars)
	check(f:NoticeTo(f.H1, string.format(GT.CoopReward.Halo, tostring(g), tostring(x))) == 1, "personal co-op reward toast")
	check(fin and fin.Result == "Halo" and fin.Rewarded[f.H1] == 20 and fin.Info and fin.Info.Mode == "Coop" and fin.Info.Success == true
		and fin.Info.Side == "Halo" and fin.Info.Target == 20, "GooseFinished('Halo', { H1 = 20 }, { Mode Coop, Success })", show(fin))
	check(f:AllText(GT.CoopResult.Halo) == 0, "no co-op result banner (the reward lines and GooseEnd say it)")
	check(A.GooseActive == false and A.GooseMode == "Versus" and A.GooseCoopSide == "None" and A.GooseCoopTarget == 0
		and A.GooseCoopPeople == 0, "GameState back to Versus / None / 0 after the event", show(A))
	-- solo Horns: 함께 밀렵, Horns reward shape
	local h = gooseWorld({ { "R1", "Horns", 4 } })
	h:Begin()
	check(h.GS.Attrs.GooseCoopSide == "Horns" and startLine(h), "only Horns: co-op for Horns (함께 밀렵), the same short start line")
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
	local tm = {}
	for _, row in t.Paid do table.insert(tm, row.Info.Mode) end
	check(#tm == 2 and tm[1] == "Coop" and tm[2] == "Coop", "a failed co-op round still pays with Mode Coop (HealthService counts it as co-op)", show(tm))
	check(t.H1.Data.CheerStars == 1 and t.H2.Data.CheerStars == 1, "failed co-op gives +1 cheer star each")
	check(fin.Rewarded[t.H1] == 10 and fin.Rewarded[t.H2] == 8, "both still get goose quest credit (GooseFinished rewarded)", show(fin.Rewarded))
	check(t:AllText(GT.CoopFail) == 0 and #t.War == 0, "co-op fail: no banner, no war points")
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
	check(n:AllText(CONFIG.Story.GooseResult.Tie) == 0 and #n.War == 0, "plain tie: no banner, no war points")
	-- Pending fixed by the first eligible player mid-event
	local p = gooseWorld({})
	p:Begin()
	local late = p:Add("H1", "Halo", 1)
	check(p:Hit(late, 1, true) == 2, "the first eligible hit fixes the mode and counts")
	check(p.GS.Attrs.GooseMode == "Coop" and p.GS.Attrs.GooseCoopSide == "Halo" and p.GS.Attrs.GooseCoopTarget == 20,
		"Pending -> co-op for the first eligible faction", show(p.GS.Attrs))
	check(startLine(p) and #p.All == 1, "A23-130: the mode fixed later adds no second line (the start line was the only one)",
		show(p.All))
	-- versus: both factions -> the normal tug, 100% / 40%, war points
	local v = gooseWorld({ { "H1", "Halo", 2 }, { "R1", "Horns", 2 } })
	v:Begin()
	check(v.GS.Attrs.GooseMode == "Versus", "both factions present: Versus")
	check(startLine(v), "versus start: the same short line for 2 s (A23-130, no two-line story text)", show(v.All))
	v:Hit(v.H1, 5, true); v:Hit(v.R1, 3, true)
	local vf = v:End()
	check(vf.Result == "Halo" and vf.Info.Mode == "Versus", "versus winner by totals", show(vf.Info))
	check(v.Gold[v.H1] == select(1, reward(2, "Halo", true, nil)) and v.Gold[v.R1] == select(1, reward(2, "Horns", false, nil)),
		"versus pays 100% / 40%", show({ v.Gold[v.H1], v.Gold[v.R1] }))
	check(#v.War == 1 and v.War[1][1] == "Halo" and v.War[1][2] == G.WinWarPoints, "versus win gives war points", show(v.War))
	local vh, vr
	for _, e in v.Paid do
		if e.P == v.H1 then vh = e.Info elseif e.P == v.R1 then vr = e.Info end
	end
	check(#v.Paid == 2 and vh and vh.Won == true and vh.Mode == "Versus" and vh.Level == 2 and vh.Gold == v.Gold[v.H1] and vh.XP == v.XP[v.H1]
		and vr and vr.Won == false and vr.Mode == "Versus" and vr.Gold == v.Gold[v.R1], "GooseRewarded in a versus round: the winner won, the loser did not, both with their pay",
		show({ vh, vr }))
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
	check(l:AllText(string.format(GT.RivalLeft, GT.CoopResult.Halo)) == 0, "rival left: no result banner either")
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
	local data = { Level = level, XP = 7, Class = "Warrior", ClassChosen = opts.Unpicked ~= true, Faction = "Halo", Tickets = { Class = opts.Tickets or 0 } }
	if opts.NoDataLevel then data.Level = nil end
	p.Attrs = { Class = "Warrior", ClassChosen = opts.Unpicked ~= true, Level = opts.AttrLevel or level, XP = 7 }
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
	function f:Choose(classId) remotes.ChooseClass.OnServerEvent:Fire(p, classId) end
	function f:Noticed(text)
		for _, e in self.Notices do if e.Text == text then return true end end
		return false
	end
	return f
end

runGroup("daily-intro (A23-104)", function()
	local C = CONFIG
	check(C.Daily.IntroGate == true and C.Daily.IntroQuest == "D0" and C.Data.Defaults.DailyIntro == false and C.Data.Version == 6,
		"config: the gate is on, the intro quest is D0, the save default DailyIntro = false (data version 6 = A23-186's joke weapons (5 = A23-153's codex, 4 = C1's tier 9))", show({ C.Daily.IntroGate, C.Daily.IntroQuest }))
	local def = C.StoryQuests.Defs.D0
	check(def and def.Kind == "Sub" and def.Factions == nil and def.Hidden ~= true and table.concat(def.Requires.Done, ",") == "M1_4"
		and #def.Steps == 1 and def.Steps[1].Panel == true and def.Steps[1].Npc == nil and def.Steps[1].Obj.Type == "Talk"
		and #def.ShortName <= 14 and table.find(C.StoryQuests.Subs, "D0") ~= nil, "D0: a sub for everyone after the first chapter (M1_4), one dialogue, in the list", show(def and def.Requires))
	-- a new save: nothing is made, shown or counted; the payload says so
	local f = questWorld(nil, 21, { Intro = false })
	check(f.Quest.DailiesOpen(f.Player) == false and #f.Data.Quests == 0 and f.Data.DailyDay == 0 and f.Data.DailyIntro == false,
		"a new save: no daily jobs yet", show({ #f.Data.Quests, f.Data.DailyDay }))
	local function jobRows(list)
		local n = 0
		for _, r in list or {} do if r.Kind == "Daily" or r.Kind == "Extra" then n += 1 end end
		return n
	end
	check(type(f.LastJson) == "table" and f.LastJson.DailyLocked == true and jobRows(f.LastJson.Quests) == 0,
		"the quest list has no daily job and says DailyLocked", show(f.LastJson))
	f:Kill("Slime")
	f:Kill("Slime")
	f:Gold(500, "Monster")
	f:Skill({ MonstersHit = 2, Auto = false })
	f.Registry.ProgressionService.Rebirthed:Fire(f.Player)
	f.Registry.FactionService.FactionChanged:Fire(f.Player, "Horns")
	f.Quest.DebugSimulateAbsence(f.Player, 3)
	check(#f.Data.Quests == 0 and f.Data.DailyDay == 0 and f.Data.VacationDays == 0 and #f.Pays == 0,
		"kills, gold, skills, a rebirth, a faction change and 3 days away make no daily job, no vacation, no pay", show({ #f.Data.Quests, f.Data.DailyDay, f.Data.VacationDays }))
	f:Claim(1)
	f:Reroll(1)
	check(#f.Data.Quests == 0 and #f.Pays == 0, "claim / reroll of a job that does not exist: nothing", "")
	f.Quest.DayCheck(f.Player)
	check(#f.Data.Quests == 0 and f.Data.DailyDay == 0 and jobRows(f.LastJson.Quests) == 0, "the day loop's check makes no set for a locked player", show({ #f.Data.Quests, f.Data.DailyDay }))
	f.Registry.StoryQuestService.QuestDone:Fire(f.Player, "M1_4")
	f.Registry.StoryQuestService.QuestDone:Fire(f.Player, "S0")
	check(f.Quest.DailiesOpen(f.Player) == false and #f.Data.Quests == 0, "another quest's end opens nothing", "")
	-- the intro quest ends: the first set is made at once
	f.Registry.StoryQuestService.QuestDone:Fire(f.Player, "D0")
	check(f.Quest.DailiesOpen(f.Player) == true and f.Data.DailyIntro == true and #f.Data.Quests == C.Quests.Slots and f.Data.DailyDay == today(),
		"D0 done: the daily jobs open, the day's set is made", show({ #f.Data.Quests, f.Data.DailyDay, f.Data.DailyIntro }))
	local kinds = {}
	for _, q in f.Data.Quests do kinds[q.Kind] = (kinds[q.Kind] or 0) + 1 end
	check(kinds.Daily == C.Quests.Slots and f.LastJson.DailyLocked == nil and jobRows(f.LastJson.Quests) == C.Quests.Slots,
		"three Daily jobs, published, no DailyLocked", show(kinds))
	check(f.Data.VacationDays == 0 and #f.Pays == 0, "no vacation reward for the days before (nothing was owed)", show({ f.Data.VacationDays }))
	local before = f.Data.Quests
	f.Registry.StoryQuestService.QuestDone:Fire(f.Player, "D0")
	check(f.Data.Quests == before and f.Quest.OpenDailies(f.Player) == false, "a second signal changes nothing (the set stays)", "")
	-- they work like any daily: a kill counts
	local slot, quest = f:Slot("Kill")
	if quest then
		local was = quest.Progress
		f:Kill("Slime")
		check(f.Data.Quests[slot].Progress > was, "a kill counts for the Kill job now", show({ was, f.Data.Quests[slot].Progress }))
	end
	-- jobs that a locked save somehow still holds are neither shown nor counted (DailyDay 0 = never run)
	local stray = questWorld(rookieRow(8, "Halo", { DailyDay = 0, Quests = { { Id = "Kill", Kind = "Daily", Target = 3, Progress = 0, RewardGold = 5, RewardXP = 5,
		Text = "x", Unit = "Slime" } } }), 24, { Intro = false })
	stray:Kill("Slime")
	check(stray.Quest.DailiesOpen(stray.Player) == false and stray.Data.Quests[1] and stray.Data.Quests[1].Progress == 0 and jobRows(stray.LastJson.Quests) == 0,
		"a stray job of a locked save: not shown, not counted", show(stray.Data.Quests[1]))
	-- a save that already runs its dailies is open without the intro (and never gets the intro quest)
	local old = questWorld(rookieRow(8, "Halo", { DailyDay = today(), Quests = {} }), 22, { Intro = false })
	check(old.Quest.DailiesOpen(old.Player) == true and #old.Data.Quests == C.Quests.Slots and old.Data.Story.Done.D0 == true,
		"an old save with DailyDay > 0: open, the intro quest is marked done", show({ #old.Data.Quests, old.Data.Story.Done.D0 }))
	check(old.LastJson.DailyLocked == nil and jobRows(old.LastJson.Quests) == C.Quests.Slots, "and its list has the three jobs", show(old.LastJson))
	-- the gate off (Config.Daily.IntroGate = false): everybody is open at once, the old rule
	local off = questWorld(nil, 23, { Intro = false, Gate = false })
	check(off.Quest.DailiesOpen(off.Player) == true and #off.Data.Quests == C.Quests.Slots and off.Data.Story.Done.D0 == true,
		"IntroGate = false: a new save has its jobs at once", show({ #off.Data.Quests }))
	-- an unknown player / no data
	check(f.Quest.DailiesOpen({}) == false and f.Quest.OpenDailies({}) == false, "no data: false, no error", "")
end)

runGroup("class-first-pick", function()
	-- the first class pick is free and silent (user 2026-10-10: no "Your class is now ..." after the player's own click)
	local f = classWorld(1, { Unpicked = true })
	f:Choose("Mage")
	check(f.Data.Class == "Mage" and f.Data.ClassChosen == true and f.Data.Level == 1, "the first pick sets the class and ClassChosen", show({ f.Data.Class, f.Data.ClassChosen }))
	check(#f.Changed == 1 and f.Changed[1][1] == "Mage" and #f.Refresh == 1 and f.Refresh[1] == true, "ClassChanged fires once, the character refreshes", show(f.Refresh))
	check(#f.Notices == 0 and CONFIG.Text.ClassChosen == nil, "no notice after the first pick (and no text left for it)", show(f.Notices))
	f:Choose("Archer")
	check(f.Data.Class == "Mage" and #f.Changed == 1 and #f.Notices == 0, "a second pick is ignored, silently", show(f.Data.Class))
	local bad = classWorld(1, { Unpicked = true })
	bad:Choose("Wizard")
	check(bad.Data.ClassChosen == false and bad.Data.Class == "Warrior" and #bad.Notices == 0, "an unknown class changes nothing", show(bad.Data.Class))
end)

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

------------------------------------------------------------------ artisan min ④: the guild's dailies (2026-10-14)
runGroup("guild dailies", function()
	local both = function(c) c.Features.Gathering = true; c.Features.Crafting = true end
	local function ids(f)
		local out = {}
		for _, q in f.Data.Quests do out[q.Id] = true end
		return out
	end
	local function sweep(level, faction, edit)
		local seen = {}
		for seed = 1, 60 do
			local f = questWorld(rookieRow(level, faction), seed * 17 + level, { EditConfig = edit })
			for id in ids(f) do seen[id] = true end
		end
		return seen
	end
	-- switches off (as shipped): never a guild daily
	for _, level in { 5, 12, 30 } do
		local s = sweep(level, "Neutral", nil)
		check(not s.Gather and not s.Craft, "Gathering / Crafting off: no guild daily for a Neutral Lv" .. level, show(s))
	end
	-- on: Neutral gets them in every band, Halo / Horns never
	for _, level in { 5, 12, 30 } do
		local s = sweep(level, "Neutral", both)
		check(s.Gather and s.Craft, "both on: a Neutral Lv" .. level .. " gets Gather and Craft dailies", show(s))
		for _, side in { "Halo", "Horns" } do
			local h = sweep(level, side, both)
			check(not h.Gather and not h.Craft, "both on: never for " .. side .. " Lv" .. level, show(h))
		end
	end
	local onlyGather = sweep(12, "Neutral", function(c) c.Features.Gathering = true end)
	check(onlyGather.Gather and not onlyGather.Craft, "Gathering on, Crafting off: Gather only", show(onlyGather))
	-- texts and sizes
	local T = {}
	for _, t in CONFIG.Quests.Templates do T[t.Id] = t end
	check(T.Gather and T.Gather.Faction == "Neutral" and T.Gather.NonHunt == true and #T.Gather.ShortName <= 14
		and T.Craft and T.Craft.Faction == "Neutral" and T.Craft.NonHunt == true and #T.Craft.ShortName <= 14,
		"templates Gather / Craft: Neutral, not hunting, short names fit the phone row", show({ T.Gather, T.Craft }))
	-- progress: a pick at a node / a finished craft
	local g, c
	for seed = 1, 200 do
		local f = questWorld(rookieRow(12, "Neutral"), seed * 29 + 3, { EditConfig = both })
		local got = ids(f)
		if got.Gather and not g then g = f end
		if got.Craft and not c then c = f end
		if g and c then break end
	end
	check(g ~= nil and c ~= nil, "Lv12 worlds with a Gather and a Craft daily")
	if g then
		local _, q = g:Slot("Gather")
		local p0 = q.Progress -- a new daily may start a little done (EndowedMin)
		g.Registry.GatherService.Gathered:Fire(nil, "Herb", 1, "Herb")
		g.Registry.GatherService.Gathered:Fire("x", "Herb", 1, "Herb")
		check(q.Progress == p0, "Gathered with a bad player: nothing", q.Progress)
		g.Registry.GatherService.Gathered:Fire(g.Player, "Herb", 3, "Herb")
		check(q.Progress == p0 + 1, "one pick = 1 (not the item count)", show({ p0, q.Progress }))
		g.Registry.CraftService.Crafted:Fire(g.Player, "W2", 0)
		check(q.Progress == p0 + 1, "a craft does not fill the Gather daily", q.Progress)
	end
	if c then
		local _, q = c:Slot("Craft")
		local p0 = q.Progress
		c.Registry.CraftService.Crafted:Fire(c.Player, "W2", 1)
		local p1 = q.Progress
		check(p1 == math.min(q.Target, p0 + 1), "one craft = 1", show({ p0, p1, q.Target }))
		c.Registry.GatherService.Gathered:Fire(c.Player, "Herb", 1, "Herb")
		check(q.Progress == p1, "a pick does not fill the Craft daily", q.Progress)
	end
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
