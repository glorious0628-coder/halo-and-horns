-- Halloween season (Config.Halloween, lead design 2026-10-06), run offline.
-- tools/test_halloween.py injects the CURRENT repository sources before this file: whole modules (CONFIG_SOURCE,
-- NET_SOURCE, UTIL_SOURCE, DATA_SOURCE, QUEST_SOURCE, STORY_SOURCE, LOOT_SOURCE, ANNOUNCE_SOURCE, HALLOWEEN_SOURCE,
-- MAIN_SOURCE, MONSTER_SOURCE, ANNOUNCE_CLIENT_SOURCE), chunks cut from bigger files (MONSTER_EVENTS_SOURCE,
-- MONSTER_POOL_SOURCE, MONSTER_GOLDEN_SOURCE, MONSTER_POP_SOURCE, MONSTER_TARGET_SOURCE, KING_HUD_SOURCE, WOBBLE_SOURCE,
-- PANELS_ITEMS_SOURCE) and CLIPS (the
-- BatGoblin_* / Goblin_* MonsterAnims modules). Only engine / service boundaries are doubles: no Studio, no network,
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
	print("FINDING [" .. currentGroup .. "] " .. text)
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

local function show(v, depth)
	depth = depth or 0
	if type(v) ~= "table" then return tostring(v) end
	if depth > 3 then return "{...}" end
	if rawget(v, "__kind") == "Instance" then return "<" .. tostring(v.ClassName) .. " " .. tostring(v.Name) .. ">" end
	local parts = {}
	for k, x in v do
		if k ~= "__kind" then table.insert(parts, tostring(k) .. "=" .. show(x, depth + 1)) end
	end
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

local function near(a, b, eps)
	return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 1e-9)
end

------------------------------------------------------------------ engine doubles
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
	if key == "Unit" then
		local n = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / n, v.Y / n, v.Z / n)
	end
	return nil
end

-- D: Color3 (R/G/B 0..1 and X/Y/Z = the 0..255 values) and a CFrame stand-in (translation + rotations; products are
-- exact for the Z rolls Fx WOBBLE uses: (p1, r1) * (p2, r2) = (p1 + Rz(r1) p2, r1 + r2))
local D = { cmt = {}, cfm = {} }
D.cmt.__index = function(_, key) if key == "Lerp" then return function(a) return a end end return nil end
function D.rgb(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255, X = r, Y = g, Z = b, __kind = "Color3" }, D.cmt) end
function D.c3(r, g, b) return D.rgb((r or 0) * 255, (g or 0) * 255, (b or 0) * 255) end
function D.cf(x, y, z, rx, ry, rz)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, Rx = rx or 0, Ry = ry or 0, Rz = rz or 0, __kind = "CFrame" }, D.cfm)
end
D.cfm.__mul = function(a, b)
	assert(getmetatable(b) == D.cfm, "CFrame * non-CFrame")
	local c, s = math.cos(a.Rz), math.sin(a.Rz)
	return D.cf(a.X + c * b.X - s * b.Y, a.Y + s * b.X + c * b.Y, a.Z + b.Z, a.Rx + b.Rx, a.Ry + b.Ry, a.Rz + b.Rz)
end
D.cfm.__index = { Inverse = function(a)
	local c, s = math.cos(-a.Rz), math.sin(-a.Rz)
	return D.cf(-(c * a.X - s * a.Y), -(s * a.X + c * a.Y), -a.Z, -a.Rx, -a.Ry, -a.Rz)
end }
D.CFrame = { new = function(x, y, z) return D.cf(x, y, z) end, Angles = function(rx, ry, rz) return D.cf(0, 0, 0, rx, ry, rz) end,
	identity = D.cf() }

local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function typeofDouble(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end
local function nativeEnv(extra)
	local e = { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec, zero = vec(0, 0, 0) },
		Color3 = { new = D.c3, fromRGB = D.rgb, fromHSV = function(_, _, v) return D.c3(v, v, v) end },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
		NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
		NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"),
		CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum, typeof = typeofDouble }
	for k, v in extra or {} do e[k] = v end
	return e
end

-- seeded Random stand-in (Util.Random, QuestService, MonsterService angles)
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
local RANDOM = { new = function(seed) return seededRandom(tonumber(seed) or 12345) end }

-- INST: a small Roblox Instance stand-in (children by Name, attributes, RemoteEvent logs). RemoteEvent client
-- connections remember INST.client (the player whose client module connected), so FireClient reaches only that client.
local INST = { methods = {}, mt = {}, client = nil }
function INST.new(className, name)
	local o = { __kind = "Instance", _p = { ClassName = className, Name = name or className }, _c = {}, _a = {}, _s = {} }
	setmetatable(o, INST.mt)
	if className == "RemoteEvent" then
		local p = o._p
		p.Log, p.Conns, p.OnServerEvent = {}, {}, signal()
		p.OnClientEvent = { Connect = function(_, fn)
			table.insert(p.Conns, { Fn = fn, Player = INST.client })
			return { Disconnect = function() end }
		end }
	end
	return o
end
INST.mt.__index = function(o, k)
	local m = INST.methods[k]
	if m ~= nil then return m end
	local v = rawget(o, "_p")[k]
	if v ~= nil then return v end
	return rawget(o, "_c")[k]
end
INST.mt.__newindex = function(o, k, v)
	local p = rawget(o, "_p")
	if k == "Parent" then
		local old = p.Parent
		if type(old) == "table" and rawget(old, "_c") and rawget(old, "_c")[p.Name] == o then rawget(old, "_c")[p.Name] = nil end
		p.Parent = v
		if type(v) == "table" and rawget(v, "_c") then rawget(v, "_c")[p.Name] = o end
	else
		p[k] = v
	end
end
do
	local IM = INST.methods
	function IM.FindFirstChild(o, n) return rawget(o, "_c")[n] end
	function IM.WaitForChild(o, n) return assert(rawget(o, "_c")[n], "WaitForChild " .. tostring(n)) end
	function IM.GetChildren(o)
		local out = {}
		for _, c in rawget(o, "_c") do table.insert(out, c) end
		return out
	end
	function IM.IsA(o, c) return o.ClassName == c or c == "Instance" end
	function IM.GetAttribute(o, k) return rawget(o, "_a")[k] end
	function IM.SetAttribute(o, k, v)
		local t = type(v)
		assert(t == "nil" or t == "string" or t == "number" or t == "boolean", "SetAttribute type " .. t .. " for " .. tostring(k))
		local a = rawget(o, "_a")
		local old = a[k]
		a[k] = v
		local s = rawget(o, "_s")[k]
		if s and old ~= v then s:Fire() end
	end
	function IM.GetAttributeChangedSignal(o, k)
		local s = rawget(o, "_s")
		s[k] = s[k] or signal()
		return s[k]
	end
	function IM.Destroy(o) o.Parent = nil end
	function IM.FireAllClients(o, ...)
		local args = table.pack(...)
		local p = rawget(o, "_p")
		table.insert(p.Log, { All = true, Args = args })
		for _, c in table.clone(p.Conns) do c.Fn(table.unpack(args, 1, args.n)) end
	end
	function IM.FireClient(o, player, ...)
		local args = table.pack(...)
		local p = rawget(o, "_p")
		table.insert(p.Log, { Player = player, Args = args })
		for _, c in table.clone(p.Conns) do
			if c.Player == player then c.Fn(table.unpack(args, 1, args.n)) end
		end
	end
	function IM.GetPlayers(o)
		local out = {}
		for _, c in rawget(o, "_c") do if c.ClassName == "Player" then table.insert(out, c) end end
		table.sort(out, function(a, b) return a.UserId < b.UserId end)
		return out
	end
end

-- ReplicatedStorage with Shared.{Config, Util, Net} module placeholders (required by name)
local function sharedStorage()
	local rs = INST.new("ReplicatedStorage")
	local shared = INST.new("Folder", "Shared")
	shared.Parent = rs
	for _, n in { "Config", "Util", "Net" } do INST.new("ModuleScript", n).Parent = shared end
	return rs
end

local function moduleName(m)
	if type(m) == "table" then return m.Name end
	return m
end

local CONFIG = execute("Config", CONFIG_SOURCE, nativeEnv())
local function newConfig(tweak)
	local c = execute("Config", CONFIG_SOURCE, nativeEnv())
	if tweak then tweak(c) end
	return c
end

local SEASONAL = { "PumpkinSlime", "LittleGhost", "BatGoblin", "PumpkinKing" }
local BASE = { "Slime", "BigSlime", "Goblin", "GoblinBrute", "Skeleton", "SkeletonKnight" }
local function zoneSum(config, counts, zone)
	local n = 0
	for kind, c in counts do
		local def = config.MonsterTypes[kind]
		if def and def.Zone == zone then n += c end
	end
	return n
end

------------------------------------------------------------------ 1. config contract
local SPEC = {
	PumpkinSlime = { Name = "호박 슬라임", Short = "호박 슬라임", Zone = "SlimeMeadow", Count = 3, HP = 14, Damage = 2, XP = 6, Gold = 4,
		Speed = 10, Shape = "Slime", Scale = 1.1, Color = { 255, 150, 40 }, QuestAs = "Slime", Takes = { Slime = 3 } },
	LittleGhost = { Name = "꼬마 유령", Short = "꼬마 유령", Zone = "GoblinWoods", Count = 3, HP = 70, Damage = 5, XP = 24, Gold = 14,
		Speed = 11, Shape = "Humanoid", Scale = 1.0, Color = { 220, 215, 255 }, Float = 1.5 },
	BatGoblin = { Name = "박쥐 고블린", Short = "박쥐 고블린", Zone = "GoblinWoods", Count = 3, HP = 95, Damage = 6, XP = 30, Gold = 17,
		Speed = 12, Shape = "Humanoid", Scale = 1.0, Color = { 120, 80, 150 }, QuestAs = "Goblin", Takes = { Goblin = 3 } },
	PumpkinKing = { Name = "호박 대왕", Short = "호박 대왕", Zone = "SlimeMeadow", Count = 0, Boss = true, Shape = "Slime", Scale = 2.5,
		Color = { 255, 130, 30 }, Damage = 8, Speed = 7, XP = 300, Gold = 150 },
}

runGroup("config-kinds", function()
	local MT = CONFIG.MonsterTypes
	for kind, spec in SPEC do
		local def = MT[kind]
		check(type(def) == "table", "Config.MonsterTypes has the Halloween kind", kind)
		if type(def) == "table" then
			check(def.Season == "Halloween", "every Halloween kind carries Season = \"Halloween\"", kind .. " " .. tostring(def.Season))
			for field, want in spec do
				if field == "Color" then
					local c = def.Color
					check(type(c) == "table" and c.X == want[1] and c.Y == want[2] and c.Z == want[3], "colour = design RGB",
						kind .. " " .. show(c and { c.X, c.Y, c.Z }))
				elseif field == "Takes" then
					check(type(def.Takes) == "table" and count(def.Takes) == 1 and def.Takes[next(want)] == want[next(want)],
						"Takes = the design slot takeover", kind .. " " .. show(def.Takes))
				else
					check(def[field] == want, "number / text field = design value", kind .. "." .. field .. " = " .. tostring(def[field]))
				end
			end
			for _, field in { "QuestAs", "Takes", "Float", "Boss" } do
				if spec[field] == nil then
					check(def[field] == nil, "no extra QuestAs / Takes / Float / Boss beyond the design", kind .. "." .. field .. " = " .. tostring(def[field]))
				end
			end
		end
	end
	for _, kind in BASE do
		check(MT[kind] and MT[kind].Season == nil and MT[kind].QuestAs == nil and MT[kind].Takes == nil, "base kinds stay year-round", kind)
	end
	local king = MT.PumpkinKing
	check(king and type(king.HP) == "number" and king.HP > 0 and (tonumber(king.ContributorWindow) or 0) >= 60,
		"the king shares its kill with everyone who fought it (ContributorWindow >= 60 s for a 1-4 minute fight)",
		show(king and { king.HP, king.ContributorWindow }))
	-- MonsterTypeOrder: every kind exactly once, seasonal kinds after the base kind of their zone, base order unchanged
	local O = CONFIG.MonsterTypeOrder
	local idx = {}
	for i, kind in O do
		check(idx[kind] == nil, "MonsterTypeOrder lists a kind once", kind)
		idx[kind] = i
	end
	check(#O == count(MT), "MonsterTypeOrder lists every MonsterTypes kind", #O .. " vs " .. count(MT))
	for kind in MT do check(idx[kind] ~= nil, "every kind is in MonsterTypeOrder", kind) end
	check(idx.PumpkinSlime and idx.PumpkinSlime > idx.Slime and idx.BatGoblin > idx.Goblin and idx.LittleGhost > idx.Goblin
		and idx.PumpkinKing > idx.Slime, "seasonal kinds come after the base kind of their zone", show(idx))
	for i = 2, #BASE do
		check(idx[BASE[i - 1]] < idx[BASE[i]], "base kinds keep their order", BASE[i - 1] .. " < " .. BASE[i])
	end
	-- the quest unit monsters are never seasonal (quest generation must not target a seasonal kind)
	for zone, unit in CONFIG.ZoneMainMonster do
		check(MT[unit] and MT[unit].Season == nil, "ZoneMainMonster units are year-round kinds", zone .. "=" .. tostring(unit))
	end
	for _, row in CONFIG.Quests.Newbie.Dailies do
		if row.Monster then check(MT[row.Monster] and MT[row.Monster].Season == nil, "newbie quest rows never name a seasonal kind", row.Monster) end
	end
	for _, id in CONFIG.StoryQuests.Main do
		for _, step in CONFIG.StoryQuests.Defs[id].Steps do
			local obj = step.Obj or {}
			check(obj.Kind == nil or MT[obj.Kind].Season == nil, "story objectives never name a seasonal kind", id .. " " .. tostring(obj.Kind))
		end
	end
end)

-- Pumpkin King HP model (Config comment next to HP): per player DPS = basic swing 0.5 x D x 1.1 (crit) per
-- SwingInterval + skill 6 x D every 3 s while MP lasts (MaxMana + regen, ReleaseCost each, mage swings cost MP),
-- averaged over Lv 8/10/12 x tier 2/3 x the three classes, 75% uptime. Target: 3 players 60-90 s, 1 player ~4 min.
local function kingFightSeconds(config, players)
	local C, V, B = config, config.Vitals, config.BasicSkill
	local critAvg = 1 + C.Combat.CritChance * (C.Combat.CritMult - 1)
	local function dps(fight)
		local sum, n = 0, 0
		for _, level in { 8, 10, 12 } do
			for _, tier in { 2, 3 } do
				for id, cls in C.Classes do
					local d = C.WeaponDamage(tier, level) * cls.Damage
					local swings = fight / cls.SwingInterval
					local mp = V.MaxMana + V.ManaRegen * fight - ((id == "Mage") and V.MageSwingCost or 0) * swings
					local casts = math.max(0, math.min(fight / B.Cooldown, mp / V.ReleaseCost))
					sum += (swings * B.SwingImmediate * d * critAvg + casts * B.DamageMultiplier * d) / fight
					n += 1
				end
			end
		end
		return sum / n
	end
	local hp = C.MonsterTypes.PumpkinKing.HP
	local t = 1
	while t < 3600 and players * dps(t) * 0.75 * t < hp do t += 0.5 end
	return t, dps(240), dps(80)
end

runGroup("config-king-hp", function()
	local solo, d240, d80 = kingFightSeconds(CONFIG, 1)
	local trio = kingFightSeconds(CONFIG, 3)
	finding(string.format("Pumpkin King HP %d: model DPS %.1f (240 s) / %.1f (80 s) per Lv 8-12 tier 2-3 player; one player "
		.. "about %.0f s, three players about %.0f s (75%% uptime)", CONFIG.MonsterTypes.PumpkinKing.HP, d240, d80, solo, trio))
	check(trio >= 60 and trio <= 90, "three Lv 8-12 players with tier 2-3 weapons need 60-90 s", trio)
	check(solo >= 200 and solo <= 290, "one such player needs about 4 minutes (200-290 s)", solo)
	check(solo <= CONFIG.Halloween.Lifetime, "one player can still finish it inside its 5-minute stay", solo)
end)

------------------------------------------------------------------ 2. season texts
local function textsOf(config)
	local H, A = config.Halloween, config.Announce
	local lines = {}
	for k, v in H.Text or {} do lines["Halloween.Text." .. k] = v end
	for _, k in { "PumpkinKingAppear", "PumpkinKingDefeat", "PumpkinKingLeave" } do
		lines["Announce.Text." .. k] = A.Text[k]
		lines["Announce.Text." .. k .. "En"] = A.Text[k .. "En"]
	end
	return lines
end

runGroup("config-halloween", function()
	local H = CONFIG.Halloween
	check(type(H) == "table" and H.Enabled == true and H.King == "PumpkinKing", "Config.Halloween { Enabled = true, King = PumpkinKing }",
		show(H and { H.Enabled, H.King }))
	check(H.FirstDelay == 360 and H.Interval == 1200 and H.Lifetime == 300, "first king at 6 min, every 20 min, stays 5 min",
		show({ H.FirstDelay, H.Interval, H.Lifetime }))
	local T = H.Text or {}
	for _, key in { "HudNext", "HudActive" } do
		local ko, en = T[key], T[key .. "En"]
		check(type(ko) == "string" and select(2, string.gsub(ko, "%%s", "")) == 1, "HUD line has exactly one %s (m:ss)", key .. " " .. tostring(ko))
		check(type(en) == "string" and en ~= ko and select(2, string.gsub(en, "%%s", "")) == 1 and not string.find(en, "[\128-\255]"),
			"HUD line has a plain English twin (" .. key .. "En)", tostring(en))
	end
	check(T.HudNext and string.find(T.HudNext, "호박 대왕까지", 1, true) == 1, "HudNext reads '호박 대왕까지 m:ss'", tostring(T.HudNext))
	check(T.HudActive and string.find(T.HudActive, "호박 대왕 출현! 남은 시간", 1, true) == 1, "HudActive reads '호박 대왕 출현! 남은 시간 m:ss'",
		tostring(T.HudActive))
	local A = CONFIG.Announce
	local want = { PumpkinKingAppear = "호박 대왕이 말랑 초원에 나타났어요! 함께 잡아요!", PumpkinKingDefeat = "호박 대왕이 사탕을 와르르 쏟았다!",
		PumpkinKingLeave = "호박 대왕이 사탕 자루를 들고 돌아갔어요. 다음에 또 와요!" }
	for key, text in want do
		check(A.Text[key] == text, "server line text = the design line", key .. " " .. tostring(A.Text[key]))
		local en = A.Text[key .. "En"]
		check(type(en) == "string" and en ~= "" and not string.find(en, "[\128-\255]"), "server line has a plain English twin", key .. "En")
		check(type(A.Events) == "table" and type(A.Events[key]) == "table" and typeofDouble(A.Events[key].Color) == "Color3",
			"Config.Announce.Events lists the line with its colour", key)
		check(not string.find(text, "%", 1, true) and not string.find(en or "", "%", 1, true), "event lines take no arguments (no name slot)", key)
	end
	check(A.Events and A.Events.PumpkinKingAppear.Toast == true and A.Events.PumpkinKingDefeat.Toast == true,
		"appear and defeat lines also toast", show(A.Events))
	-- kid-safe, no time pressure; a line that names the season says it comes back every year
	for where, text in textsOf(CONFIG) do
		local low = string.lower(tostring(text))
		check(not string.find(low, "한정", 1, true) and not string.find(low, "limited", 1, true) and not string.find(low, "last chance", 1, true)
			and not string.find(low, "서둘러", 1, true) and not string.find(low, "hurry", 1, true), "no limited-time pressure wording", where)
		if string.find(low, "핼러윈", 1, true) or string.find(low, "halloween", 1, true) then
			check(string.find(low, "매년 돌아와요", 1, true) or string.find(low, "every year", 1, true), "a line naming the season says it comes back every year", where)
		end
	end
	for _, kind in SEASONAL do
		local name = CONFIG.MonsterTypes[kind].Name
		check(not string.find(name, "한정", 1, true), "monster names carry no limited-time wording", name)
	end
	local candy = CONFIG.Loot.Items.Candy
	if candy and string.find(candy.Name, "핼러윈", 1, true) then
		finding("Item name '" .. candy.Name .. "' names the season without 'comes back every year' (a name, not a sentence; "
			.. "the every-year rule was applied to lines only)")
	end
end)

------------------------------------------------------------------ 3. counts (Config shared functions)
local EXPECT_ON = { Slime = 9, PumpkinSlime = 3, BigSlime = 4, PumpkinKing = 0, Goblin = 7, BatGoblin = 3, LittleGhost = 3,
	GoblinBrute = 4, Skeleton = 8, SkeletonKnight = 4 }
local EXPECT_OFF = { Slime = 12, PumpkinSlime = 0, BigSlime = 4, PumpkinKing = 0, Goblin = 10, BatGoblin = 0, LittleGhost = 0,
	GoblinBrute = 4, Skeleton = 8, SkeletonKnight = 4 }

runGroup("counts", function()
	local C = CONFIG
	local on, off, auto = C.EffectiveMonsterCounts(true), C.EffectiveMonsterCounts(false), C.EffectiveMonsterCounts()
	for kind, n in EXPECT_ON do
		check(on[kind] == n, "season on: regular pool count per kind", kind .. " " .. tostring(on[kind]) .. " want " .. n)
		check(off[kind] == EXPECT_OFF[kind], "season off: regular pool count per kind (no seasonal kind, base slots back)",
			kind .. " " .. tostring(off[kind]) .. " want " .. EXPECT_OFF[kind])
		check(auto[kind] == on[kind], "EffectiveMonsterCounts() follows Config.Halloween.Enabled (on)", kind)
	end
	check(count(on) == #C.MonsterTypeOrder, "one count per MonsterTypeOrder kind", count(on))
	check(zoneSum(C, on, "SlimeMeadow") == 16 and zoneSum(C, off, "SlimeMeadow") == 16,
		"meadow total stays 16 with the season on and off (pumpkin slimes replace 3 slimes)",
		zoneSum(C, on, "SlimeMeadow") .. "/" .. zoneSum(C, off, "SlimeMeadow"))
	check(zoneSum(C, on, "GoblinWoods") == zoneSum(C, off, "GoblinWoods") + 3, "woods: bat goblins replace goblins, the 3 ghosts come on top",
		zoneSum(C, on, "GoblinWoods") .. " vs " .. zoneSum(C, off, "GoblinWoods"))
	check(zoneSum(C, on, "SkeletonRuins") == zoneSum(C, off, "SkeletonRuins"), "ruins unchanged by the season")
	check(on.Slime + on.PumpkinSlime == off.Slime and on.Goblin + on.BatGoblin == off.Goblin,
		"jackpot / goblin slot totals are the same in and out of season")
	-- the flag itself
	local cOff = newConfig(function(c) c.Halloween.Enabled = false end)
	local autoOff = cOff.EffectiveMonsterCounts()
	for kind, n in EXPECT_OFF do check(autoOff[kind] == n, "Enabled = false: EffectiveMonsterCounts() = the year-round pool", kind) end
	for _, kind in SEASONAL do
		check(C.MonsterActive(kind) == true and cOff.MonsterActive(kind) == false, "MonsterActive(seasonal kind) follows Enabled", kind)
		check(C.MonsterActive(kind, false) == false and cOff.MonsterActive(kind, true) == true, "MonsterActive override forces the season", kind)
	end
	for _, kind in BASE do
		check(C.MonsterActive(kind) and cOff.MonsterActive(kind) and C.MonsterActive(kind, false), "base kinds are always active", kind)
	end
	check(C.MonsterActive("Dragon") == false and C.MonsterActive(nil) == false, "unknown kinds are never active")
	check(C.SeasonOn(nil) == true and C.SeasonOn("Halloween") == true and cOff.SeasonOn("Halloween") == false and C.SeasonOn("Nope") == false,
		"SeasonOn: nil = always, Halloween = Enabled, unknown season = off")
	-- QuestKind
	local qk = { PumpkinSlime = "Slime", BatGoblin = "Goblin", LittleGhost = "LittleGhost", PumpkinKing = "PumpkinKing", Slime = "Slime",
		Goblin = "Goblin", BigSlime = "BigSlime", Dragon = "Dragon" }
	for kind, want in qk do check(C.QuestKind(kind) == want, "Config.QuestKind(kind) = QuestAs or kind", kind .. " -> " .. tostring(C.QuestKind(kind))) end
	check(C.QuestKind(nil) == nil and C.QuestKind(5) == 5, "QuestKind passes odd values through")
	local bad = newConfig(function(c) c.MonsterTypes.Odd = { QuestAs = "Nowhere", Zone = "SlimeMeadow", Count = 0 } end)
	check(bad.QuestKind("Odd") == "Odd", "QuestAs naming a missing kind falls back to the kind itself")
end)

runGroup("counts-density", function()
	for _, variant in { { "default", nil }, { "ExtraPerPlayer 3 / MaxZoneMult 3", function(c) c.MonsterDensity.ExtraPerPlayer = 3; c.MonsterDensity.MaxZoneMult = 3 end },
		{ "ExtraPerPlayer 1 / MaxZoneMult 1.5", function(c) c.MonsterDensity.ExtraPerPlayer = 1; c.MonsterDensity.MaxZoneMult = 1.5 end } } do
		local C = newConfig(variant[2])
		local per, mult = C.MonsterDensity.ExtraPerPlayer, C.MonsterDensity.MaxZoneMult
		local function grow(c, n) if c <= 0 then return 0 end return math.min(c + per * math.max(0, n - 1), c * mult) end
		for _, n in { 0, 1, 2, 3, 4, 6, 9, 12 } do
			local zp = { SlimeMeadow = n, GoblinWoods = n, SkeletonRuins = n }
			local on, off = C.MonsterTargets(zp, true), C.MonsterTargets(zp, false)
			local tag = variant[1] .. " n=" .. n
			check(near(zoneSum(C, on, "SlimeMeadow"), zoneSum(C, off, "SlimeMeadow")), "meadow target total identical with the season on / off",
				tag .. " " .. zoneSum(C, on, "SlimeMeadow") .. " vs " .. zoneSum(C, off, "SlimeMeadow"))
			check(near(on.Slime + on.PumpkinSlime, grow(12, n)), "slime + pumpkin slime targets = the slime density formula", tag .. " " .. show({ on.Slime, on.PumpkinSlime }))
			check(near(on.Goblin + on.BatGoblin, grow(10, n)), "goblin + bat goblin targets = the goblin density formula", tag)
			check(near(on.LittleGhost, grow(3, n)), "ghosts grow on their own (3 .. 3 x MaxZoneMult)", tag .. " " .. tostring(on.LittleGhost))
			check(near(zoneSum(C, on, "GoblinWoods"), zoneSum(C, off, "GoblinWoods") + grow(3, n)), "woods target = year-round + the ghosts", tag)
			check(on.PumpkinSlime >= 3 and on.BatGoblin >= 3 and on.PumpkinSlime <= on.Slime,
				"seasonal share grows with the zone (never below its base 3, never the majority)", tag .. " " .. show(on))
			check(on.PumpkinKing == 0 and off.PumpkinKing == 0 and off.PumpkinSlime == 0 and off.BatGoblin == 0 and off.LittleGhost == 0,
				"the king never joins the regular pool; season off = no seasonal targets", tag)
			for _, kind in BASE do
				if kind ~= "Slime" and kind ~= "Goblin" then
					local c = C.MonsterTypes[kind].Count
					check(near(on[kind], grow(c, n)) and near(off[kind], grow(c, n)), "untouched kinds keep min(Count + Extra x (n - 1), Count x MaxZoneMult)", tag .. " " .. kind)
				end
			end
			check(near(off.Slime, grow(12, n)) and near(off.Goblin, grow(10, n)), "season off: slimes / goblins back to the full formula", tag)
		end
		-- zones grow independently
		local mixed = C.MonsterTargets({ SlimeMeadow = 6 }, true)
		check(near(mixed.Slime + mixed.PumpkinSlime, grow(12, 6)) and near(mixed.Goblin + mixed.BatGoblin, 10) and mixed.LittleGhost == 3,
			"only the busy zone grows", variant[1] .. " " .. show(mixed))
	end
end)

------------------------------------------------------------------ 4. MonsterService regular pool (real cappedTargets / reevaluate / Start loop)
local function poolWorld(config)
	local f = { Records = {}, Pending = {}, Zone = {}, Serial = 0, Spawned = {} }
	local H = { records = f.Records, pending = f.Pending }
	function H.spawnMonster(kind)
		f.Serial += 1
		local rec = { Id = f.Serial, Kind = kind, Alive = true }
		f.Records[rec.Id] = rec
		f.Spawned[kind] = (f.Spawned[kind] or 0) + 1
		return rec
	end
	function H.playersPerZone() return f.Zone end
	function H.warnThrottled(k, m) table.insert(groupWarnings, "pool " .. tostring(k) .. ": " .. tostring(m)) end
	local util = { Random = seededRandom(7) }
	f.P = execute("MonsterService.pool", MONSTER_POOL_SOURCE, nativeEnv(), config, util, config.Monsters, H)
	function f:Alive()
		local out = {}
		for _, rec in self.Records do if rec.Alive and not rec.Event then out[rec.Kind] = (out[rec.Kind] or 0) + 1 end end
		return out
	end
	return f
end

runGroup("monster-pool", function()
	for _, season in { true, false } do
		local C = newConfig(function(c) c.Halloween.Enabled = season end)
		local want = season and EXPECT_ON or EXPECT_OFF
		local f = poolWorld(C)
		check(f.P.GLOBAL_CAP == C.MonsterDensity.GlobalCap, "GLOBAL_CAP = Config.MonsterDensity.GlobalCap", f.P.GLOBAL_CAP)
		local n = f.P.startSpawn()
		local sum = 0
		for kind, c in want do
			check((f.Spawned[kind] or 0) == c, "MonsterService.Start spawns EffectiveMonsterCounts per kind",
				(season and "on " or "off ") .. kind .. " " .. tostring(f.Spawned[kind]) .. " want " .. c)
			sum += c
		end
		check(n == sum, "Start spawn total = the season's pool", n .. " vs " .. sum)
		-- one player per zone: reevaluate keeps the pool as it is
		f.Zone = { SlimeMeadow = 1, GoblinWoods = 1, SkeletonRuins = 1 }
		f.P.reevaluate()
		local all, capped = 0, 0
		for kind, n in f:Alive() do
			all += n
			if not C.MonsterOutsideCap(kind) then capped += n end
		end
		check(all == sum and f.P.totalNonPersonal() == capped and capped == sum - (want.LittleGhost or 0),
			"one player per zone: nothing more spawns (the cap count leaves the ghosts out)", show({ all, capped, f.P.totalNonPersonal() }))
		-- busy zones: reevaluate fills up to cappedTargets, never above, seasonal kinds only when on
		f.Zone = { SlimeMeadow = 4, GoblinWoods = 3, SkeletonRuins = 2 }
		for _ = 1, 6 do f.P.reevaluate() end
		local targets = f.P.cappedTargets(f.Zone)
		local alive = f:Alive()
		local tsum = 0
		for kind, t in targets do
			check((alive[kind] or 0) == t, "reevaluate fills every kind to its capped target", (season and "on " or "off ") .. kind .. " " .. tostring(alive[kind]) .. "/" .. t)
			if not C.MonsterOutsideCap(kind) then tsum += t end
		end
		check(tsum <= f.P.GLOBAL_CAP, "targets of the capped kinds fit under GLOBAL_CAP", tsum)
		check(targets.PumpkinKing == 0 and (alive.PumpkinKing or 0) == 0, "reevaluate never spawns the king")
		if not season then
			check((alive.PumpkinSlime or 0) + (alive.BatGoblin or 0) + (alive.LittleGhost or 0) == 0, "season off: no seasonal kind ever spawns", show(alive))
		end
		local wanted = C.MonsterTargets(f.Zone)
		for kind, t in targets do
			check(t == wanted[kind], "room under the cap: capped targets = Config.MonsterTargets", kind .. " " .. t .. " vs " .. tostring(wanted[kind]))
		end
		-- an alive event king is outside the pool: not in the cap count, not a reason to spawn or skip anything
		local before = f.P.totalNonPersonal()
		f.Records[9999] = { Id = 9999, Kind = "PumpkinKing", Alive = true, Event = true }
		check(f.P.totalNonPersonal() == before, "an alive event king is not counted toward GLOBAL_CAP", f.P.totalNonPersonal() .. " vs " .. before)
		f.P.reevaluate()
		check(f.P.totalNonPersonal() == before and f.P.aliveCountOf("PumpkinKing") == 1, "the king's presence changes no regular spawn")
		-- a tight cap is shared out and never exceeded
		local tight = newConfig(function(c) c.Halloween.Enabled = season; c.MonsterDensity.GlobalCap = 50 end)
		local g = poolWorld(tight)
		g.P.startSpawn()
		g.Zone = { SlimeMeadow = 12, GoblinWoods = 12, SkeletonRuins = 12 }
		for _ = 1, 8 do g.P.reevaluate() end
		check(g.P.totalNonPersonal() <= 50, "GlobalCap 50: the pool never grows past the cap", g.P.totalNonPersonal())
	end
	-- the fallback cap (no GlobalCap) follows the season's pool without the add-on kinds (they sit outside the cap)
	local fallback = {}
	for _, season in { true, false } do
		local C = newConfig(function(c) c.Halloween.Enabled = season; c.MonsterDensity.GlobalCap = nil end)
		local sum = 0
		for kind, n in C.EffectiveMonsterCounts() do
			if not C.MonsterOutsideCap(kind) then sum += n end
		end
		local f = poolWorld(C)
		fallback[season] = f.P.GLOBAL_CAP
		check(f.P.GLOBAL_CAP == math.floor(sum * 1.7 + 0.5), "no GlobalCap: 1.7 x the season's capped pool", f.P.GLOBAL_CAP .. " sum " .. sum)
	end
	check(fallback[true] == fallback[false], "no GlobalCap: the fallback cap is the same with the season on and off", show(fallback))
	-- the golden roll: a Boss kind is never golden in the regular path, other kinds still roll
	local golden = execute("MonsterService.golden", MONSTER_GOLDEN_SOURCE, nativeEnv(), CONFIG, { Random = { NextNumber = function() return 0 end } }, CONFIG.Monsters)
	check(golden("PumpkinKing", {}) == false, "spawnMonster: the Boss king is never golden (even on a 0 roll)")
	check(golden("Slime", {}) == true and golden("PumpkinSlime", {}) == true, "other kinds still roll the golden chance")
	check(golden("PumpkinKing", { Golden = false }) == false and golden("PumpkinKing", { Golden = true }) == true, "an explicit Golden option wins")
end)

-- the GlobalCap split keeps every zone's capped total the same with the season on (a taker shares its base kind's part,
-- Config.MonsterCapGroup) and the ghosts come on top outside the cap (Config.MonsterOutsideCap); review 2026-10-06
runGroup("monster-cap-season", function()
	local on = newConfig(function(c) c.Halloween.Enabled = true end)
	local off = newConfig(function(c) c.Halloween.Enabled = false end)
	check(on.MonsterOutsideCap("LittleGhost") and on.MonsterOutsideCap("PumpkinKing") and not on.MonsterOutsideCap("PumpkinSlime")
		and not on.MonsterOutsideCap("BatGoblin") and not on.MonsterOutsideCap("Slime") and not on.MonsterOutsideCap("Skeleton"),
		"outside the cap: only the add-on seasonal kinds (ghost, event king)")
	check(on.MonsterCapGroup("PumpkinSlime") == "Slime" and on.MonsterCapGroup("BatGoblin") == "Goblin"
		and on.MonsterCapGroup("Slime") == "Slime" and on.MonsterCapGroup("LittleGhost") == "LittleGhost",
		"cap groups: a taker shares its base kind's part, every other kind its own")
	local pOn, pOff = poolWorld(on), poolWorld(off)
	local function zoneTotals(cfg, targets)
		local z = { SlimeMeadow = 0, GoblinWoods = 0, SkeletonRuins = 0 }
		for kind, n in targets do
			local def = cfg.MonsterTypes[kind]
			if def and not cfg.MonsterOutsideCap(kind) then z[def.Zone] = (z[def.Zone] or 0) + n end
		end
		return z
	end
	local bound, cases = 0, 0
	for meadow = 0, 12 do
		for woods = 0, 8 do
			for ruins = 0, 8 do
				local zc = { SlimeMeadow = meadow, GoblinWoods = woods, SkeletonRuins = ruins }
				local tOn, tOff = pOn.P.cappedTargets(zc), pOff.P.cappedTargets(zc)
				local zOn, zOff = zoneTotals(on, tOn), zoneTotals(off, tOff)
				local wantedOff = 0
				for _, n in off.MonsterTargets(zc) do wantedOff += n end
				cases += 1
				if wantedOff > pOff.P.GLOBAL_CAP then bound += 1 end
				check(zOn.SlimeMeadow == zOff.SlimeMeadow and zOn.GoblinWoods == zOff.GoblinWoods and zOn.SkeletonRuins == zOff.SkeletonRuins,
					"every zone's capped total (ghosts aside) is the same with the season on and off", show({ zc, zOn, zOff }))
				local ghosts = on.MonsterTargets(zc).LittleGhost
				check(tOn.LittleGhost == ghosts and ghosts >= 3 and ghosts <= 6 and (tOff.LittleGhost or 0) == 0,
					"the ghosts get their own full target on top (3..6), none with the season off", show({ zc, tOn.LittleGhost, ghosts }))
				local slimes = tOn.Slime + tOn.PumpkinSlime
				check(slimes == tOff.Slime and tOn.PumpkinSlime >= math.floor(slimes / 4) - 1 and tOn.PumpkinSlime <= math.ceil(slimes / 4) + 1,
					"slimes + pumpkin slimes = the season-off slime target, a quarter of them pumpkins", show({ zc, tOn.Slime, tOn.PumpkinSlime, tOff.Slime }))
				check(tOn.Goblin + tOn.BatGoblin == tOff.Goblin and tOn.BigSlime == tOff.BigSlime and tOn.Skeleton == tOff.Skeleton,
					"goblins + bat goblins = the season-off goblin target; other kinds unchanged", show({ zc, tOn.Goblin, tOn.BatGoblin, tOff.Goblin }))
			end
		end
	end
	check(bound >= 200, "the comparison covers many busy servers where the cap binds", bound .. " of " .. cases)
	-- the review's case: 16 players (7 meadow / 6 woods / 3 ruins)
	local zc = { SlimeMeadow = 7, GoblinWoods = 6, SkeletonRuins = 3 }
	local zOn, zOff = zoneTotals(on, pOn.P.cappedTargets(zc)), zoneTotals(off, pOff.P.cappedTargets(zc))
	check(zOn.SlimeMeadow == zOff.SlimeMeadow and zOn.SkeletonRuins == zOff.SkeletonRuins and zOff.SlimeMeadow + zOff.GoblinWoods + zOff.SkeletonRuins == 72,
		"16 players: meadow and ruins keep their capped totals with the season on (cap 72 reached)", show({ zOn, zOff }))
	-- a full cap: the regular pool stops at 72, the ghosts still reach their target and do not count toward it
	local f = poolWorld(on)
	f.P.startSpawn()
	f.Zone = zc
	for _ = 1, 10 do f.P.reevaluate() end
	local alive = f:Alive()
	local regular = 0
	for kind, n in alive do
		if not on.MonsterOutsideCap(kind) then regular += n end
	end
	local ghostTarget = on.MonsterTargets(zc).LittleGhost
	check(regular == 72 and f.P.totalNonPersonal() == 72, "full server: the regular pool is exactly at the cap", show({ regular, f.P.totalNonPersonal() }))
	check((alive.LittleGhost or 0) == ghostTarget and ghostTarget == 6, "full server: the ghosts still fill their own target (6)", show(alive))
	f.Records[8888] = { Id = 8888, Kind = "LittleGhost", Alive = true }
	f.Pending.LittleGhost = 2
	check(f.P.totalNonPersonal() == 72, "alive / pending ghosts are not counted toward the cap", f.P.totalNonPersonal())
	f.Pending.LittleGhost = 0
	f.Records[8888] = nil
	-- two ghosts die while the regular pool is at the cap: they come back anyway (their slots are outside the cap)
	local killedGhosts = 0
	for _, rec in f.Records do
		if rec.Kind == "LittleGhost" and rec.Alive and killedGhosts < 2 then
			rec.Alive = false
			killedGhosts += 1
		end
	end
	f.P.reevaluate()
	alive = f:Alive()
	check(killedGhosts == 2 and (alive.LittleGhost or 0) == 6 and f.P.totalNonPersonal() == 72,
		"full cap: dead ghosts respawn to their target without waiting for room under the cap", show({ alive.LittleGhost, f.P.totalNonPersonal() }))
end)

------------------------------------------------------------------ 5. loot (real LootService)
local function rowKey(row)
	if row.Item then return "Item:" .. row.Item end
	if row.Potion then return "Potion:" .. row.Potion end
	return "Weapon:" .. tostring(row.Weapon)
end
local function rowMap(rows)
	local out = {}
	for _, row in rows or {} do out[rowKey(row)] = { P = row.P, N = row.N or 1, Dup = out[rowKey(row)] ~= nil } end
	return out
end
local COPY_ROWS = { "Item:Enh70", "Item:Enh30", "Item:Enh10", "Item:Move70", "Item:Move30", "Item:Move10", "Potion:HP", "Potion:MP" }

local function lootWorld(config)
	local f = { Script = {}, Const = nil, Draws = 0, Clock = 100, Notices = {}, Gold = {}, Pushes = {}, Fx = {}, NearAnvil = true }
	config = config or newConfig()
	f.Config = config
	local rs = sharedStorage()
	local players = INST.new("Players")
	local services = { ReplicatedStorage = rs, Players = players,
		RunService = { IsServer = function() return true end, IsClient = function() return false end, IsStudio = function() return true end } }
	local game = { JobId = "offline-halloween-loot", GetService = function(_, n) return assert(services[n], "service " .. tostring(n)) end }
	local modules = { Config = config }
	local osd = setmetatable({ clock = function() return f.Clock end }, { __index = os })
	local function env(rand)
		return nativeEnv({ game = game, workspace = { GetServerTimeNow = function() return f.Clock end }, os = osd, Random = rand or RANDOM,
			print = function() end, warn = function(...) table.insert(groupWarnings, "warn: " .. table.concat({ ... }, " ")) end,
			task = { spawn = function(fn, ...) fn(...) end, defer = function(fn, ...) fn(...) end, delay = function() end,
				wait = function() error("unexpected yield") end },
			require = function(m) return assert(modules[moduleName(m)], "unexpected require " .. tostring(moduleName(m))) end })
	end
	modules.Util = execute("Util", UTIL_SOURCE, env())
	local remotes = {}
	local net = {}
	function net.Get(name)
		if not remotes[name] then
			remotes[name] = { OnServerEvent = signal(), FireClient = function(_, p, payload)
				if name == "Inventory" then table.insert(f.Pushes, deepCopy(payload)) end
			end, FireAllClients = function() table.insert(groupWarnings, "FireAllClients " .. name) end }
		end
		return remotes[name]
	end
	function net.Notify(_, text, kind) table.insert(f.Notices, { Text = text, Kind = kind }) end
	function net.Fx(_, kind, data) table.insert(f.Fx, { Kind = kind, Data = data }) end
	modules.Net = net
	local p = INST.new("Player", "Looter")
	p.UserId, p.DisplayName = 4321, "Looter"
	p.Parent = players
	local data = { Items = {}, WeaponEnhance = {}, LootFlags = { FirstScroll = true }, WeaponOwnedMask = 1, WeaponTier = 1,
		HPPotionCount = 0, MPPotionCount = 0, Level = 10, CarriedGold = 0, Class = "Warrior" }
	f.Player, f.Data = p, data
	local ps = { PlayerReady = signal(), PlayerLeaving = signal(), CharacterSpawned = signal(),
		GetData = function(q) if q == p then return data end return nil end, IsReady = function(q) return q == p end,
		MarkActive = function() end }
	function ps.SetStat(q, k, v) data[k] = v; if type(v) ~= "table" then q:SetAttribute(k, v) end end
	local registry = { PlayerService = ps, ClassService = { GetClass = function() return "Warrior" end },
		ShopService = { CanBuyWeapon = function() return f.NearAnvil end },
		ProgressionService = { AddCarriedGold = function(_, g, src) table.insert(f.Gold, { Gold = g, Source = src }) end },
		MonsterService = { MonsterKilled = signal() }, CombatService = { IsInCombat = function() return false end },
		AnnounceService = { Announce = function() end } }
	-- LootService's own Random: scripted values first, then a constant, else seeded
	local seeded = seededRandom(99)
	local lootRandom = { new = function()
		local r = {}
		function r:NextNumber(a, b)
			f.Draws += 1
			local v
			if #f.Script > 0 then v = table.remove(f.Script, 1) elseif f.Const ~= nil then v = f.Const else v = seeded:NextNumber() end
			if a ~= nil then return a + (b - a) * v end
			return v
		end
		function r:NextInteger(a, b) f.Draws += 1 return seeded:NextInteger(a, b) end
		return r
	end }
	local loot = execute("LootService", LOOT_SOURCE, env(lootRandom))
	loot.Init(registry)
	loot.Start()
	ps.PlayerReady:Fire(p, data)
	f.Loot, f.Registry, f.Remotes = loot, registry, remotes
	function f:Sell() self.Clock += 5; remotes.SellMaterials.OnServerEvent:Fire(p) end
	return f
end

runGroup("loot", function()
	local L = CONFIG.Loot
	local candy = L.Items.Candy
	check(candy and candy.Kind == "Material" and candy.Name == "핼러윈 사탕" and candy.Sell == 5 and candy.Color
		and candy.Color.X == 255 and candy.Color.Y == 140 and candy.Color.Z == 60, "Config.Loot.Items.Candy = material, 핼러윈 사탕, sells for 5",
		show(candy))
	local pos = table.find(L.Order, "Candy")
	local lastBase = 0
	for i, id in L.Order do
		if id ~= "Candy" and L.Items[id] and L.Items[id].Kind == "Material" then lastBase = i end
	end
	check(pos ~= nil and pos > lastBase, "Candy is listed after the base materials in Loot.Order", tostring(pos) .. " > " .. lastBase)
	-- the four drop tables (exact rows)
	local T = L.Tables
	local function copyOf(base, extra)
		local want = {}
		local bm = rowMap(T[base])
		for _, k in COPY_ROWS do want[k] = { P = bm[k] and bm[k].P, N = 1 } end
		for k, v in extra do want[k] = v end
		return want
	end
	local SPEC_ROWS = {
		PumpkinSlime = copyOf("Slime", { ["Item:Candy"] = { P = 0.35, N = 1 }, ["Item:Jelly"] = { P = 0.1, N = 1 } }),
		LittleGhost = copyOf("Goblin", { ["Item:Candy"] = { P = 0.45, N = 1 } }),
		BatGoblin = copyOf("Goblin", { ["Item:Candy"] = { P = 0.3, N = 1 }, ["Item:GoblinTooth"] = { P = 0.3, N = 1 }, ["Weapon:4"] = { P = 0.001, N = 1 } }),
		PumpkinKing = { ["Item:Candy"] = { P = 1, N = 8 }, ["Item:Enh70"] = { P = 0.5, N = 1 }, ["Item:Enh30"] = { P = 0.15, N = 1 },
			["Item:Enh10"] = { P = 0.04, N = 1 }, ["Item:Move70"] = { P = 0.15, N = 1 }, ["Potion:HP"] = { P = 0.5, N = 1 },
			["Potion:MP"] = { P = 0.5, N = 1 }, ["Weapon:4"] = { P = 0.05, N = 1 } },
	}
	for kind, want in SPEC_ROWS do
		local have = rowMap(T[kind])
		check(T[kind] ~= nil and #T[kind] == count(have), "drop table has no duplicate rows", kind)
		check(count(have) == count(want), "drop table has exactly the design rows", kind .. " " .. count(have) .. " vs " .. count(want))
		for k, w in want do
			local h = have[k]
			check(h ~= nil and w.P ~= nil and h.P == w.P and h.N == w.N, "drop row chance / count = design", kind .. " " .. k .. " " .. show(h) .. " want " .. show(w))
		end
	end
	check(L.Jackpot.Monsters.Slime == true and L.Jackpot.Monsters.PumpkinSlime == true and count(L.Jackpot.Monsters) == 2
		and L.Jackpot.Chance == 1 / 20000 and L.Jackpot.Tier == 8, "the slime jackpot (1/20000, tier 8) also covers pumpkin slimes", show(L.Jackpot))

	-- real rollRows (LootService.DebugSimulate): every row of a table is one draw in table order, then the jackpot draw
	local f = lootWorld()
	for _, kind in SEASONAL do
		local rows = T[kind]
		local jack = L.Jackpot.Monsters[kind] == true
		f.Script, f.Const, f.Draws = {}, 0, 0
		local all = f.Loot.DebugSimulate(kind, 1)
		local draws = f.Draws
		f.Const = nil
		check(draws == #rows + (jack and 1 or 0), "one draw per row (+ the jackpot draw for jackpot kinds)", kind .. " " .. draws)
		for _, row in rows do
			local key = row.Item or row.Potion or ("Weapon" .. tostring(row.Weapon))
			local want = row.Item and (row.N or 1) or 1
			check(all and all[key] == want, "a 0 roll drops every row with its count", kind .. " " .. key .. " " .. tostring(all and all[key]))
		end
		check(all and ((all["Weapon" .. L.Jackpot.Tier] ~= nil) == jack), "jackpot legendary only from pumpkin slimes among the Halloween kinds", kind)
		-- per-row threshold: P - 1e-9 hits, P + 1e-9 misses (every other row and the jackpot miss)
		for i, row in rows do
			local key = row.Item or row.Potion or ("Weapon" .. tostring(row.Weapon))
			local always = 0 -- other rows with P >= 1 drop on any roll
			for j, other in rows do if j ~= i and other.P >= 1 then always += 1 end end
			for _, case in { { row.P - 1e-9, true }, { row.P + 1e-9, false } } do
				if case[1] < 1 then
					local script = {}
					for j in rows do script[j] = (j == i) and case[1] or 0.999999999 end
					if jack then table.insert(script, 0.999999999) end
					f.Script = script
					local tally = f.Loot.DebugSimulate(kind, 1)
					f.Script = {}
					check(tally and ((tally[key] ~= nil) == case[2]) and count(tally) == (case[2] and 2 or 1) + always, "row chance threshold = P",
						kind .. " " .. key .. " roll " .. case[1] .. " " .. show(tally))
				end
			end
		end
		if jack then
			for _, case in { { L.Jackpot.Chance - 1e-12, true }, { L.Jackpot.Chance + 1e-12, false } } do
				local script = {}
				for j in rows do script[j] = 0.999999999 end
				table.insert(script, case[1])
				f.Script = script
				local tally = f.Loot.DebugSimulate(kind, 1)
				f.Script = {}
				check(tally and ((tally["Weapon" .. L.Jackpot.Tier] ~= nil) == case[2]), "pumpkin slime jackpot threshold = the slime's 1/20000", case[1])
			end
		end
	end
	-- seeded rates (the real rollRows with the seeded stream): candy and the base material near their P
	local N = 20000
	for kind, rows in { PumpkinSlime = { "Candy", "Jelly" }, LittleGhost = { "Candy" }, BatGoblin = { "Candy", "GoblinTooth" } } do
		f.Script, f.Const = {}, nil
		local tally = f.Loot.DebugSimulate(kind, N)
		local pm = rowMap(T[kind])
		for _, id in rows do
			local pr = pm["Item:" .. id].P
			local hits = tally and tally[id] or 0
			check(math.abs(hits - N * pr) <= 5 * math.sqrt(N * pr * (1 - pr)) + 1, "seeded rate of " .. id .. " matches its P (20000 rolls)",
				kind .. " " .. hits .. " vs " .. N * pr)
		end
	end
	-- the kill signal path (MonsterService.MonsterKilled -> LootService.RollKill) for a seasonal kind
	f.Const = 0
	local maskBefore = f.Data.WeaponOwnedMask
	f.Registry.MonsterService.MonsterKilled:Fire(f.Player, { Kind = "BatGoblin", Golden = false, Position = vec(700, 0, 0) })
	f.Const = nil
	check(f.Data.Items.Candy == 1 and f.Data.Items.GoblinTooth == 1 and bit32.btest(f.Data.WeaponOwnedMask, bit32.lshift(1, 3))
		and maskBefore ~= f.Data.WeaponOwnedMask, "a bat goblin kill through MonsterKilled grants candy, a goblin tooth and (on a 0 roll) the tier-4 weapon",
		show({ f.Data.Items, f.Data.WeaponOwnedMask }))
	f.Data.Items = {}
	f.Data.WeaponOwnedMask = 1
	-- a defeated king: every contributor's own roll gives 8 candies (P = 1 even on the worst roll), sold at the anvil
	f.Const = 0.999999
	local gained = f.Loot.RollKill(f.Player, { Kind = "PumpkinKing", Golden = false, Position = vec(330, 0, 0) })
	f.Const = nil
	check(f.Data.Items.Candy == 8, "a king kill gives 8 candies to the contributor", show(f.Data.Items))
	local gotCandy = false
	for _, g in gained or {} do if g.Item == "Candy" and g.N == 8 then gotCandy = true end end
	check(gotCandy and #gained == 1, "the Loot Fx lists 8 candies (nothing else on a bad roll)", show(gained))
	local push = f.Pushes[#f.Pushes]
	check(push and push.Items.Candy == 8 and push.Seen and push.Seen.PumpkinKing == true, "inventory push shows the candies and the king's drop list",
		show(push))
	f.NearAnvil = false
	f:Sell()
	check(f.Data.Items.Candy == 8 and #f.Gold == 0, "away from the anvil nothing is sold")
	f.NearAnvil = true
	f:Sell()
	check(f.Data.Items.Candy == nil and #f.Gold == 1 and f.Gold[1].Gold == 8 * candy.Sell and f.Gold[1].Source == "Sale",
		"SellMaterials at the anvil sells the candies (8 x 5 gold)", show(f.Gold))
	-- jackpot chance per meadow slot is the same in and out of season (pumpkin slimes replace slimes 1:1)
	local on, off = CONFIG.EffectiveMonsterCounts(true), CONFIG.EffectiveMonsterCounts(false)
	local function jackSlots(counts)
		local n = 0
		for kind, c in counts do if L.Jackpot.Monsters[kind] then n += c end end
		return n
	end
	check(jackSlots(on) == jackSlots(off), "jackpot-carrying meadow slots: 12 in and out of season", jackSlots(on) .. " vs " .. jackSlots(off))
end)

------------------------------------------------------------------ 6. quests (real DataService + QuestService)
local questSerial = 0
local function questWorld(saved, seed, zone)
	questSerial += 1
	local f = { Now = 1000, Rows = {}, Notices = {}, Pays = {}, Tickets = {}, Spawned = {}, Ready = true, Zone = zone or "SlimeMeadow" }
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
			remotes[name] = { OnServerEvent = signal(), FireClient = function(_, _, payload) if name == "Quests" then f.LastJson = payload end end }
		end
		return remotes[name]
	end
	function net.Notify(_, text, kind) table.insert(f.Notices, { Text = text, Kind = kind }) end
	function net.NotifyAll() end
	function net.Fx() end
	local util = { DeepCopy = deepCopy, FormatNumber = tostring, Random = seededRandom(seed or questSerial),
		Warn = function(tag, msg) if tag ~= "DataService" then table.insert(groupWarnings, tag .. ": " .. tostring(msg)) end end,
		RateLimit = function() return true end, Now = function() return f.Now end,
		IsAlive = function() return true end, Signal = { new = signal } }
	local services = { Players = players, ReplicatedStorage = { Shared = { Config = "Config", Util = "Util", Net = "Net" } },
		DataStoreService = { GetDataStore = function() return store end }, RunService = { IsStudio = function() return true end },
		HttpService = { GenerateGUID = function() return "guid-" .. questSerial end, JSONEncode = function(_, v) return show(v) end } }
	local env = { game = { JobId = "offline-halloween", GetService = function(_, name) return assert(services[name], name) end },
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
	local player = { __kind = "Instance", ClassName = "Player", Name = "Q" .. questSerial, DisplayName = "Q", UserId = userId,
		Parent = players, Attrs = {} }
	function player:IsA(kind) return kind == "Player" end
	function player:GetAttribute(k) return self.Attrs[k] end
	function player:SetAttribute(k, v) self.Attrs[k] = v end
	f.Player = player
	local data = assert(ds.Load(player), "DataService.Load failed")
	f.Data = data
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
	function prog.AddBankGold(p, amount) table.insert(f.Pays, { Gold = amount }); ps.AddStat(p, "BankGold", amount) end
	function prog.AddXP(p, amount) table.insert(f.Pays, { XP = amount }); ps.AddStat(p, "XP", amount) end
	local registry = { PlayerService = ps, DataService = ds, ProgressionService = prog,
		MonsterService = { MonsterKilled = signal() }, CombatService = { Released = signal() },
		GooseService = { GooseFinished = signal() }, PvPService = { PlayerKO = signal(), IsRookie = function() return true end },
		KaijuService = { KaijuEnded = signal() },
		FactionService = { FactionChanged = signal(), GetFaction = function(p) return ds.Get(p).Faction end },
		ClassService = { ClassChanged = signal() },
		ZoneService = { ZoneChanged = signal(), GetZoneId = function() return f.Zone end },
		MonetizationService = { AddTickets = function(_, kind, n) table.insert(f.Tickets, { kind, n }) end } }
	local quest = execute("QuestService", QUEST_SOURCE, env)
	quest.Init(registry)
	quest.Start()
	f.Spawned = {}
	f.Quest, f.Registry, f.PS = quest, registry, ps
	ps.PlayerReady:Fire(player, data)
	function f:Kill(kind, extra)
		local info = { Kind = kind, Personal = false, ZoneId = config.MonsterTypes[kind] and config.MonsterTypes[kind].Zone or "SlimeMeadow",
			Golden = false }
		for k, v in extra or {} do info[k] = v end
		registry.MonsterService.MonsterKilled:Fire(self.Player, info)
	end
	function f:Slot(id)
		for i, q in self.Data.Quests do if q.Id == id then return i, q end end
		return nil, nil
	end
	function f:Reroll(slot) remotes.RerollQuest.OnServerEvent:Fire(self.Player, slot) end
	return f
end

local function rookieRow(level, faction, extra)
	local row = { Version = 3, Level = level, Faction = faction or "Halo", ClassChosen = true, Class = "Warrior",
		TutorialStep = 99, BlacksmithVisited = true, WeaponTier = 1, WeaponOwnedMask = 1 }
	for k, v in extra or {} do row[k] = v end
	return row
end

local function killQuestWorld(level, unit, strict, from)
	for seed = from or 1, (from or 1) + 400 do
		local f = questWorld(rookieRow(level, "Halo"), seed)
		local _, q = f:Slot("Kill")
		if q and q.Unit == unit and (strict == nil or (q.Strict == true) == strict) then return f, q end
	end
	error("no seed produced a " .. unit .. " kill daily")
end

runGroup("quests-kill-weight", function()
	local MT = CONFIG.MonsterTypes
	-- delta of the Kill daily's progress for one kill of `kind`
	local function delta(f, q, kind, extra)
		local before = q.Progress
		f:Kill(kind, extra)
		return q.Progress - before
	end
	-- Lv1 슬라임 row (12-15, not strict)
	local f, q = killQuestWorld(1, "Slime", false)
	check(near(delta(f, q, "PumpkinSlime"), 1), "slime daily: a pumpkin slime counts as one slime")
	check(near(delta(f, q, "Slime"), 1), "slime daily: a slime counts one")
	check(near(delta(f, q, "LittleGhost"), 1) and near(delta(f, q, "BatGoblin"), 1), "slime daily: stronger Halloween kinds count one (never more)")
	-- Lv1 왕 슬라임 row (3, strict): weaker kills count 0, the king counts 1
	local s, sq = killQuestWorld(1, "BigSlime", true)
	check(near(delta(s, sq, "PumpkinSlime"), 0), "strict king-slime daily: a pumpkin slime (a slime) counts 0", sq.Progress)
	check(near(delta(s, sq, "PumpkinKing"), 1), "strict king-slime daily: the Pumpkin King counts 1")
	-- Lv10 goblin daily: weights in goblin units
	local g, gq = killQuestWorld(10, "Goblin")
	check(near(delta(g, gq, "BatGoblin", { ZoneId = "GoblinWoods" }), 1), "goblin daily: a bat goblin counts exactly as a goblin")
	check(near(delta(g, gq, "PumpkinSlime"), MT.Slime.XP / MT.Goblin.XP), "goblin daily: a pumpkin slime counts as a slime (Slime.XP / Goblin.XP)",
		string.format("%.4f vs %.4f", gq.Progress, MT.Slime.XP / MT.Goblin.XP))
	check(near(delta(g, gq, "LittleGhost", { ZoneId = "GoblinWoods" }), MT.LittleGhost.XP / MT.Goblin.XP),
		"goblin daily: a little ghost counts as itself (LittleGhost.XP / Goblin.XP)")
	check(near(delta(g, gq, "PumpkinKing"), 1), "goblin daily: the king counts one")
end)

runGroup("quests-tutorial", function()
	local t = questWorld(rookieRow(1, "Halo", { TutorialStep = 2, TutorialKills = 0 }), 3)
	t:Kill("PumpkinSlime")
	check(t.Data.TutorialKills == 1, "first mission: a pumpkin slime in the meadow counts", t.Data.TutorialKills)
	t:Kill("PumpkinKing")
	check(t.Data.TutorialKills == 2, "first mission: the meadow king counts too", t.Data.TutorialKills)
	t:Kill("PumpkinSlime", { Personal = true })
	t:Kill("BatGoblin")
	t:Kill("LittleGhost")
	t:Kill("BatGoblin", { ZoneId = "SlimeMeadow" })
	check(t.Data.TutorialKills == 2, "personal kills and woods kinds never count (a bat goblin is a goblin, not a meadow kind)", t.Data.TutorialKills)
	-- STEP_GUIDE: the first meadow kill (a pumpkin slime) starts the mission and counts
	local g = questWorld(rookieRow(1, "Halo", { TutorialStep = 1, TutorialKills = 0 }), 4, "Crossroads")
	check(g.Data.TutorialStep == 1, "guide step world starts on step 1 (outside the meadow)", g.Data.TutorialStep)
	g:Kill("PumpkinSlime")
	check(g.Data.TutorialStep == 2 and g.Data.TutorialKills == 1, "guide step: a pumpkin slime kill in the meadow starts the mission and counts",
		show({ g.Data.TutorialStep, g.Data.TutorialKills }))
end)

runGroup("quests-generation", function()
	local seasonalNames = {}
	for _, kind in SEASONAL do
		seasonalNames[CONFIG.MonsterTypes[kind].Short] = true
		seasonalNames[CONFIG.MonsterTypes[kind].Name] = true
	end
	local units, rows = {}, 0
	for _, faction in { "Halo", "Horns", "Neutral" } do
		for _, level in { 1, 5, 9, 10, 14, 20, 29, 30, 45, 60 } do
			for seed = 1, 3 do
				local f = questWorld(rookieRow(level, faction), seed * 31 + level)
				for round = 1, 3 do
					for _, q in f.Data.Quests do
						rows += 1
						if q.Unit ~= nil then
							units[q.Unit] = (units[q.Unit] or 0) + 1
							check(f.Config.MonsterTypes[q.Unit] ~= nil and f.Config.MonsterTypes[q.Unit].Season == nil,
								"generated Kill / Golden quests never target a seasonal kind", faction .. " Lv" .. level .. " " .. tostring(q.Unit))
						end
						local hit = nil
						for name in seasonalNames do if string.find(tostring(q.Text), name, 1, true) then hit = name end end
						check(hit == nil, "quest texts never name a Halloween monster", tostring(q.Text))
					end
					if round < 3 then
						for slot in f.Data.Quests do
							f.Now += 100
							f:Reroll(slot)
						end
					end
				end
			end
		end
	end
	check(units.Slime and units.Goblin and units.Skeleton and units.BigSlime, "generation covered every zone's unit monster", show(units))
	check(rows > 0, "quests were generated", rows)
end)

------------------------------------------------------------------ 7. story (real StoryQuestService)
local function storyWorld(data, defs)
	local f = { Notices = {}, Dirty = 0, Zone = "SlimeMeadow", Opened = {} }
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	for id, def in defs or {} do config.StoryQuests.Defs[id] = def end
	f.Config = config
	local rs = sharedStorage()
	local players = INST.new("Players")
	local services = { ReplicatedStorage = rs, Players = players,
		RunService = { IsServer = function() return true end, IsClient = function() return false end, IsStudio = function() return true end } }
	local game = { GetService = function(_, n) return assert(services[n], "service " .. tostring(n)) end }
	local ws = { GetServerTimeNow = function() return 5000 end }
	local modules = { Config = config }
	local env = nativeEnv({ game = game, workspace = ws, Random = RANDOM, print = function() end,
		warn = function(...) table.insert(groupWarnings, "warn: " .. table.concat({ ... }, " ")) end,
		task = { spawn = function() end, wait = function() error("unexpected yield") end, delay = function() end, defer = function(fn, ...) fn(...) end },
		require = function(m) return assert(modules[moduleName(m)], "unexpected require " .. tostring(moduleName(m))) end })
	modules.Util = execute("Util", UTIL_SOURCE, env)
	local gs = INST.new("Folder", "GameState")
	local remotes = {}
	modules.Net = {
		Get = function(name)
			if not remotes[name] then
				remotes[name] = { OnServerEvent = signal(), FireClient = function(_, _, kind, payload)
					if name == "OpenPanel" then table.insert(f.Opened, { Kind = kind, Payload = payload }) end
				end }
			end
			return remotes[name]
		end,
		Notify = function(_, text, kind) table.insert(f.Notices, { Text = text, Kind = kind }) end,
		GameState = function() return gs end,
	}
	local p = INST.new("Player", "Hero")
	p.UserId, p.DisplayName = 555, "Hero"
	p:SetAttribute("Faction", data.Faction or "Halo")
	p:SetAttribute("ClassChosen", true)
	p:SetAttribute("Level", data.Level or 3)
	p.Parent = players
	local hum = { Health = 100, MaxHealth = 100 }
	local root = { Position = vec(0, 0, 0) }
	local char = { Parent = ws }
	function char:FindFirstChildOfClass(c) if c == "Humanoid" then return hum end return nil end
	function char:FindFirstChild(n) if n == "HumanoidRootPart" then return root end if n == "Humanoid" then return hum end return nil end
	p.Character = char
	f.Player, f.Data, f.Hum = p, data, hum
	local ps = { PlayerReady = signal(), GetData = function(q) if q == p then return data end return nil end,
		IsReady = function(q) return q == p end, GetReadyPlayers = function() return { p } end }
	function ps.AddStat(_, k, n) data[k] = (data[k] or 0) + n end
	function ps.SetStat(_, k, v) data[k] = v end
	local registry = { PlayerService = ps, QuestService = { MarkDirty = function() f.Dirty += 1 end },
		MonsterService = { MonsterKilled = signal() }, CombatService = { Released = signal(), UnlockAutoCombat = function() f.Unlocked = true end },
		ProgressionService = { GoldEarned = signal(), LeveledUp = signal(), AddBankGold = function() end, AddXP = function() end },
		GooseService = { GooseFinished = signal() },
		ZoneService = { ZoneChanged = signal(), GetZoneId = function() return f.Zone end } }
	local story = execute("StoryQuestService", STORY_SOURCE, env)
	story.Init(registry)
	story.Start()
	ps.PlayerReady:Fire(p, data)
	f.Story, f.Registry = story, registry
	function f:Kill(kind, extra)
		local info = { Kind = kind, ZoneId = config.MonsterTypes[kind] and config.MonsterTypes[kind].Zone or "SlimeMeadow", Golden = false,
			Personal = false, SkillHit = false, Position = vec(0, 0, 0), WarPoints = 1 }
		for k, v in extra or {} do info[k] = v end
		registry.MonsterService.MonsterKilled:Fire(p, info)
	end
	function f:Track(id) return data.Story and data.Story.Subs and data.Story.Subs[id] end
	return f
end

runGroup("story", function()
	local pond = CONFIG.StoryQuests.Landmarks.SlimePond
	local defs = {
		HW_Goblin = { Kind = "Sub", Title = "t", Steps = { { Text = "%d/%d", Obj = { Type = "Kill", Kind = "Goblin", Count = 10 } } } },
		HW_Ghost = { Kind = "Sub", Title = "t", Steps = { { Text = "%d/%d", Obj = { Type = "Kill", Kind = "LittleGhost", Count = 10 } } } },
		HW_Pond = { Kind = "Sub", Title = "t", Steps = { { Text = "%d/%d", Obj = { Type = "Kill", Kind = "Slime", Near = "SlimePond", Radius = 40, Count = 10 } } } },
	}
	local data = { ClassChosen = true, TutorialStep = 2, Level = 3, Faction = "Halo",
		Story = { Main = { Id = "" }, Subs = { HW_Goblin = { St = 1, P = 0, T = {}, Claim = false }, HW_Ghost = { St = 1, P = 0, T = {}, Claim = false },
			HW_Pond = { St = 1, P = 0, T = {}, Claim = false } }, Done = {}, Pick = {}, First = {} } }
	local f = storyWorld(data, defs)
	local s0 = f:Track("S0")
	check(s0 ~= nil and s0.St == 1, "S0 starts after the class pick (step 1: a king slime in the meadow)", show(s0))
	-- step 1 = Kill BigSlime: neither a pumpkin slime (a slime) nor the Pumpkin King (its own kind) is a king slime
	f:Kill("PumpkinSlime")
	f:Kill("PumpkinKing")
	check(f:Track("S0").St == 1 and (f:Track("S0").P or 0) == 0, "S0 step 1: pumpkin slime / Pumpkin King are not king slimes", show(f:Track("S0")))
	f:Kill("BigSlime")
	s0 = f:Track("S0")
	check(s0 and s0.St == 2, "S0 step 1 done by a king slime", show(s0))
	-- step 2 trials: a = BasicKill Slime x3 (pumpkin slimes count), c = SafeKill BigSlime
	f:Kill("PumpkinSlime")
	check(s0.T.a == 1, "S0 trial 'BasicKill Slime': a pumpkin slime killed with basic attacks counts", show(s0.T))
	f:Kill("PumpkinSlime", { SkillHit = true })
	check(s0.T.a == 1, "S0 trial: a pumpkin slime hit by the skill does not count (basic attacks only)", show(s0.T))
	f:Kill("BatGoblin")
	f:Kill("LittleGhost")
	check(s0.T.a == 1, "S0 trial: woods kinds never count as slimes", show(s0.T))
	f:Kill("Slime")
	f:Kill("PumpkinSlime")
	check(s0.T.a == 3, "S0 trial a reaches 3 with pumpkin slimes and slimes", show(s0.T))
	-- injected objectives: Goblin (bat goblins count), LittleGhost (only ghosts), Slime near the pond (pumpkin slimes)
	local gob, ghost, pondT = f:Track("HW_Goblin"), f:Track("HW_Ghost"), f:Track("HW_Pond")
	local g0, h0, p0 = gob.P, ghost.P, pondT.P
	f:Kill("BatGoblin")
	f:Kill("Goblin")
	f:Kill("LittleGhost")
	f:Kill("GoblinBrute")
	check(gob.P == g0 + 2, "a Goblin objective counts bat goblins and goblins (not ghosts / brutes)", show({ g0, gob.P }))
	check(ghost.P == h0 + 1, "a LittleGhost objective counts only ghosts", show({ h0, ghost.P }))
	local p1 = pondT.P
	f:Kill("PumpkinSlime", { Position = pond + vec(10, 0, 0) })
	f:Kill("PumpkinSlime", { Position = pond + vec(200, 0, 0) })
	check(pondT.P == p1 + 1, "a 'slime near the pond' objective counts a pumpkin slime near the pond only", show({ p0, p1, pondT.P }))
	check(f:Track("HW_Goblin") ~= nil, "injected test objectives stay tracked")
end)

------------------------------------------------------------------ 8. Pumpkin King world (real HalloweenService + AnnounceService + Net + Util,
-- MonsterService event / kill / damage chunks, three client Announce modules)
local function hwWorld(opts)
	opts = opts or {}
	local f = { Now = 50000, Clock = 1000, Spawned = {}, Killed = {}, Respawns = {}, Pops = {}, Pays = {}, Removes = 0,
		Clients = {}, Delays = {}, Ground = "flat", PickPoint = nil, Serial = 0, PlayerSerial = 0 }
	local config = execute("Config", CONFIG_SOURCE, nativeEnv())
	if opts.Season == false then config.Halloween.Enabled = false end
	f.Config = config
	local rs = sharedStorage()
	local players = INST.new("Players")
	players.PlayerRemoving = signal()
	local services = { ReplicatedStorage = rs, Players = players,
		RunService = { IsServer = function() return true end, IsClient = function() return false end, IsStudio = function() return true end },
		HttpService = { JSONEncode = function(_, v) return show(v) end, GenerateGUID = function() return "guid" end } }
	local game = { JobId = "offline-halloween", GetService = function(_, n) return assert(services[n], "service " .. tostring(n)) end }
	local ws = { GetServerTimeNow = function() return f.Now end }
	local osd = setmetatable({ clock = function() return f.Clock end }, { __index = os })
	local modules = { Config = config }
	local function env()
		return nativeEnv({ game = game, workspace = ws, os = osd, Random = RANDOM, Instance = { new = function(c) return INST.new(c) end },
			print = function() end,
			warn = function(...) table.insert(groupWarnings, "warn: " .. table.concat({ ... }, " ")) end,
			task = {
				spawn = function(fn, ...) if f.CaptureSpawn then f.Loop = coroutine.create(fn) else fn(...) end end,
				wait = function(d) return coroutine.yield(d) end,
				delay = function(d, fn, ...) table.insert(f.Delays, { At = f.Clock + (d or 0), Fn = fn, Args = table.pack(...) }) end,
				defer = function(fn, ...) fn(...) end },
			require = function(m) return assert(modules[moduleName(m)], "unexpected require " .. tostring(moduleName(m))) end })
	end
	local util = execute("Util", UTIL_SOURCE, env())
	modules.Util = util
	local net = execute("Net", NET_SOURCE, env())
	modules.Net = net
	net.CreateAll()
	f.Util, f.Net, f.RS, f.PlayersService = util, net, rs, players

	-- MonsterService pieces: SpawnEvent / RemoveEvent / DamageMonster / killRecord / despawn (real), spawnMonster = a
	-- record maker that uses the real golden roll
	local ms = { MonsterKilled = util.Signal.new() }
	ms.MonsterKilled:Connect(function(p, info) table.insert(f.Killed, { Player = p, Info = info }) end)
	local golden = execute("MonsterService.golden", MONSTER_GOLDEN_SOURCE, env(), config, util, config.Monsters)
	local H = { records = {}, pending = {}, SPAWN_TRIES = 8 }
	function H.groundPoint(x, z)
		if f.Ground == "water" then return nil, false end
		if f.Ground == "bare" then return nil, true end
		return vec(x, 0, z), false
	end
	function H.pickSpawnPoint() f.PickCalls = (f.PickCalls or 0) + 1 return f.PickPoint end
	function H.spawnMonster(kind, o)
		o = o or {}
		local def = config.MonsterTypes[kind]
		if not def then return nil end
		f.Serial += 1
		local rec = { Id = f.Serial, Kind = kind, Def = def, HP = def.HP, MaxHP = def.HP, Alive = true, Owner = o.Owner,
			Event = o.Event == true or nil, Golden = golden(kind, o), ZoneId = def.Zone, Home = o.Position, _contributors = {},
			Root = { Parent = true, Position = o.Position } }
		H.records[rec.Id] = rec
		table.insert(f.Spawned, { Kind = kind, Opts = deepCopy(o), Rec = rec, At = f.Now })
		return rec
	end
	function H.warnThrottled(key, msg) table.insert(groupWarnings, "MonsterService " .. tostring(key) .. ": " .. tostring(msg)) end
	function H.updateBar() end
	function H.deathPop(rec, killed, leaving) table.insert(f.Pops, { Rec = rec, Killed = killed, Leaving = leaving }) end
	function H.factionOf(p) return p:GetAttribute("Faction") or "None" end
	function H.removePersonalRef() end
	function H.markHurt() end
	function H.zoneIdOf(p) return p:GetAttribute("ZoneId") end
	function H.scheduleRespawn(kind) table.insert(f.Respawns, kind) end
	local mini = execute("MonsterService.events", MONSTER_EVENTS_SOURCE, env(), config, util, config.Monsters, ms, H)
	local realRemove = ms.RemoveEvent
	ms.RemoveEvent = function(...) f.Removes += 1 return realRemove(...) end
	f.MS, f.Mini, f.H = ms, mini, H

	local function recorder()
		return setmetatable({}, { __index = function(_, k) return function() table.insert(f.Pays, k) end end })
	end
	local registry = { MonsterService = ms, ProgressionService = recorder(), LootService = recorder(), QuestService = recorder(),
		PlayerService = { GetData = function() return {} end, IsReady = function() return true end, SetStat = function() end },
		ClassService = { GetClass = function() return "Warrior" end } }
	local announce = execute("AnnounceService", ANNOUNCE_SOURCE, env())
	registry.AnnounceService = announce
	announce.Init(registry)
	announce.Start()
	f.Announce, f.Registry = announce, registry

	function f:AddPlayer(name, zone, faction)
		self.PlayerSerial += 1
		local p = INST.new("Player", name)
		p.UserId, p.DisplayName = 9000 + self.PlayerSerial, name
		p:SetAttribute("Faction", faction or "Halo")
		p:SetAttribute("ZoneId", zone or "SlimeMeadow")
		p.Parent = players
		return p
	end
	-- clients: each has its own Announce module (+ Net) connected to the shared "Announce" RemoteEvent
	for _, spec in opts.Clients or { { Name = "Ana" }, { Name = "Ben", Lang = "en" }, { Name = "Cyd", Hold = true } } do
		local p = f:AddPlayer(spec.Name)
		local c = { Player = p, Lines = {}, Toasts = {}, Lang = spec.Lang, Hold = spec.Hold == true, Name = spec.Name }
		local channel = { IsA = function(_, k) return k == "TextChannel" end }
		channel.DisplaySystemMessage = function(_, text) table.insert(c.Lines, text) end
		local channels = { FindFirstChild = function(_, n) if n == "RBXGeneral" then return channel end return nil end }
		local tcs = { ChatVersion = "ChatVersion.TextChatService",
			FindFirstChild = function(_, n) if n == "TextChannels" then return channels end return nil end }
		local cServices = { ReplicatedStorage = rs, TextChatService = tcs, Players = players,
			StarterGui = { SetCore = function() table.insert(groupWarnings, "legacy chat used") end },
			RunService = { IsServer = function() return false end, IsClient = function() return true end, IsStudio = function() return true end } }
		local cGame = { GetService = function(_, n) return assert(cServices[n], "client service " .. tostring(n)) end }
		local cModules = { Config = config, Util = util }
		local cEnv = nativeEnv({ game = cGame, workspace = ws, os = osd, print = function() end,
			warn = function(...) table.insert(groupWarnings, "client warn: " .. table.concat({ ... }, " ")) end,
			task = { spawn = function(fn, ...) fn(...) end, wait = function() error("client yield") end, delay = function() end,
				defer = function(fn, ...) fn(...) end },
			require = function(m) return assert(cModules[moduleName(m)], "client require " .. tostring(moduleName(m))) end })
		cModules.Net = execute("Net(client)", NET_SOURCE, cEnv)
		local mod = execute("Announce(client)", ANNOUNCE_CLIENT_SOURCE, cEnv)
		mod.Init({ Settings = { Get = function(k) if k == "Lang" then return c.Lang or "Auto" end return nil end },
			UIKit = { Toast = function(text, kind, secs) table.insert(c.Toasts, { Text = text, Kind = kind, Secs = secs }) end,
				ShouldHoldBanners = function() return c.Hold end, Announce = function() table.insert(c.Toasts, { Banner = true }) end } })
		INST.client = p
		mod.Start()
		INST.client = nil
		c.Module = mod
		table.insert(f.Clients, c)
	end

	-- HalloweenService: its loop is a coroutine resumed once per 0.5 s step
	f.CaptureSpawn = true
	local hs = execute("HalloweenService", HALLOWEEN_SOURCE, env())
	registry.HalloweenService = hs
	hs.Init(registry)
	f.StartAt = f.Now
	hs.Start()
	f.CaptureSpawn = false
	assert(f.Loop, "HalloweenService.Start spawned no loop")
	assert(coroutine.resume(f.Loop))
	f.HS = hs

	function f:Step(dt)
		dt = dt or 0.5
		self.Now += dt
		self.Clock += dt
		local due = {}
		for i = #self.Delays, 1, -1 do
			if self.Delays[i].At <= self.Clock then table.insert(due, 1, table.remove(self.Delays, i)) end
		end
		for _, d in due do d.Fn(table.unpack(d.Args, 1, d.Args.n)) end
		local ok, err = coroutine.resume(self.Loop)
		assert(ok, err)
	end
	function f:Advance(seconds) for _ = 1, math.floor(seconds / 0.5 + 0.5) do self:Step(0.5) end end
	function f:GS(k) return net.GameState():GetAttribute(k) end
	function f:Log() return rs.Remotes.Announce.Log end
	function f:Lines()
		local out = {}
		for _, e in self:Log() do if e.All then table.insert(out, e.Args[1]) end end
		return out
	end
	function f:Direct()
		local n = 0
		for _, e in self:Log() do if not e.All then n += 1 end end
		return n
	end
	function f:Keys()
		local out = {}
		for _, m in self:Lines() do table.insert(out, type(m) == "table" and tostring(m.Key) or "?") end
		return table.concat(out, ",")
	end
	function f:Kings()
		local out = {}
		for _, s in self.Spawned do if s.Kind == config.Halloween.King then table.insert(out, s) end end
		return out
	end
	function f:King()
		local list = self:Kings()
		return list[#list] and list[#list].Rec or nil
	end
	return f
end

-- the plain text of a chat line (TextChatService rich text '<font color="#RRGGBB"><b>text</b></font>')
local function chatText(line)
	local color, text = string.match(tostring(line), '^<font color="(#%x+)"><b>(.*)</b></font>$')
	return text, color
end
local function hexOf(c) return string.format("#%02X%02X%02X", c.X, c.Y, c.Z) end

-- every client shows key's line once more than before: Korean, or English for the English client; colour = the event's
local function clientsShowed(f, key, before)
	local A = f.Config.Announce
	local ok, detail = true, ""
	for i, c in f.Clients do
		local want = (c.Lang == "en") and A.Text[key .. "En"] or A.Text[key]
		local line = c.Lines[(before and before[i] or 0) + 1]
		local text, color = chatText(line)
		if #c.Lines ~= (before and before[i] or 0) + 1 or text ~= want or color ~= hexOf(A.Events[key].Color) then
			ok, detail = false, c.Name .. " " .. tostring(line) .. " want " .. tostring(want)
		end
	end
	return ok, detail
end
local function lineCounts(f)
	local out = {}
	for i, c in f.Clients do out[i] = #c.Lines end
	return out
end
-- no player name / id anywhere in a broadcast payload
local function nameless(f, payload)
	local names = {}
	for _, p in f.PlayersService:GetPlayers() do names[p.Name] = true; names[p.DisplayName] = true; names[tostring(p.UserId)] = true end
	local bad = nil
	local function scan(v, path)
		if type(v) == "table" then
			if rawget(v, "__kind") == "Instance" then bad = path .. " is an Instance" return end
			for k, x in v do
				if k == "Who" or k == "UserId" or k == "Name" or k == "Hidden" or k == "Faction" or k == "Class" or k == "Self" then bad = path .. "." .. tostring(k) end
				scan(x, path .. "." .. tostring(k))
			end
		elseif names[tostring(v)] then
			bad = path .. " = " .. tostring(v)
		end
	end
	scan(payload, "payload")
	return bad == nil, bad
end

runGroup("king-schedule", function()
	local f = hwWorld()
	local HW = f.Config.Halloween
	local t0 = f.StartAt
	check(f:GS("PumpkinKingNextAt") == t0 + 360, "server start: the first king is due 6:00 later (GameState PumpkinKingNextAt, server time)",
		tostring(f:GS("PumpkinKingNextAt")) .. " vs " .. (t0 + 360))
	check(f:GS("PumpkinKingActive") == false and f:GS("PumpkinKingEndsAt") == 0, "server start: nothing active")
	f:Advance(359.5)
	check(#f.Spawned == 0 and #f:Lines() == 0, "no king and no line before 6:00", #f.Spawned)
	f:Advance(0.5)
	local ta = f.Now
	local kings = f:Kings()
	check(#kings == 1 and ta == t0 + 360, "the Pumpkin King appears at 6:00", #kings)
	local s = kings[1]
	if s then
		check(s.Opts.Event == true and s.Opts.Golden == false and s.Rec.Golden == false and s.Rec.Event == true,
			"spawned through MonsterService.SpawnEvent: an event monster, never golden", show(s.Opts))
		-- review 2026-10-06: a far meadow corner (Config.Halloween.SpawnSpots), away from the entrance (first mission at
		-- x 220) and the road (z 0)
		local p = s.Opts.Position
		local nearSpot = false
		for _, spot in HW.SpawnSpots or {} do
			if p ~= nil and (vec(p.X, 0, p.Z) - vec(spot.X, 0, spot.Z)).Magnitude <= HW.SpawnRadius + 1e-6 then nearSpot = true end
		end
		local entry = f.Config.Zones.SlimeMeadow.Spawn
		check(nearSpot and f.Config.ZoneAt(p).Id == "SlimeMeadow" and math.abs(p.Z) >= 60
			and (vec(p.X, 0, p.Z) - vec(entry.X, 0, entry.Z)).Magnitude >= 150,
			"it stands on meadow ground at a far corner spot (away from the entrance and the road)", show(p))
	end
	check(f:GS("PumpkinKingActive") == true and f:GS("PumpkinKingEndsAt") == ta + 300, "GameState: active, leaves 5:00 after appearing",
		show({ f:GS("PumpkinKingActive"), f:GS("PumpkinKingEndsAt"), ta + 300 }))
	check(f:GS("PumpkinKingNextAt") == ta + 1200, "the next king is due 20:00 after this appearance", f:GS("PumpkinKingNextAt"))
	check(f:Keys() == "PumpkinKingAppear" and f:Direct() == 0, "one server-wide appear line (FireAllClients), nothing per player", f:Keys())
	local msg = f:Lines()[1]
	check(type(msg) == "table" and msg.Event == true and type(msg.Args) == "table" and next(msg.Args) == nil and msg.Grade == nil,
		"event payload = { Key, Args = {}, Event = true }", show(msg))
	check(nameless(f, msg), "the appear payload carries no player name or id", select(2, nameless(f, msg)))
	local ok, detail = clientsShowed(f, "PumpkinKingAppear", { 0, 0, 0 })
	check(ok, "every client shows the appear line once (Korean / English twin), in the event colour", detail)
	check(#f.Clients[1].Toasts == 1 and #f.Clients[2].Toasts == 1 and #f.Clients[3].Toasts == 0,
		"appear toast on free clients; skipped (not held) while banners are held", show({ #f.Clients[1].Toasts, #f.Clients[2].Toasts, #f.Clients[3].Toasts }))
	check(f.Clients[2].Toasts[1] and f.Clients[2].Toasts[1].Text == f.Config.Announce.Text.PumpkinKingAppearEn, "the English client toasts the English line",
		show(f.Clients[2].Toasts[1]))
	-- it stays its whole lifetime, then leaves with the friendly line (no rewards, removed through RemoveEvent)
	f:Advance(299.5)
	check(f:King() and f:King().Alive == true and f:GS("PumpkinKingActive") == true, "still here at 4:59.5")
	local before = lineCounts(f)
	f:Advance(0.5)
	local k1 = kings[1] and kings[1].Rec
	check(k1 and k1.Alive == false and f.Removes == 1 and f.Pops[#f.Pops] and f.Pops[#f.Pops].Killed == false,
		"after 5:00 the king is removed through MonsterService.RemoveEvent (fade, no kill)", show({ k1 and k1.Alive, f.Removes }))
	check(f.Pops[#f.Pops] and f.Pops[#f.Pops].Leaving == true, "the leaving king goes home (leave fade, not the death squash)",
		show(f.Pops[#f.Pops] and { f.Pops[#f.Pops].Killed, f.Pops[#f.Pops].Leaving }))
	check(f:Keys() == "PumpkinKingAppear,PumpkinKingLeave", "the leave line goes out once (no defeat line)", f:Keys())
	ok, detail = clientsShowed(f, "PumpkinKingLeave", before)
	check(ok, "every client shows the leave line", detail)
	check(#f.Clients[1].Toasts == 1, "the leave line has no toast", #f.Clients[1].Toasts)
	check(#f.Killed == 0 and #f.Respawns == 0 and #f.Pays == 0, "leaving pays nobody and schedules no respawn", show({ #f.Killed, #f.Respawns, #f.Pays }))
	check(f:GS("PumpkinKingActive") == false and f:GS("PumpkinKingEndsAt") == 0 and f:GS("PumpkinKingNextAt") == ta + 1200,
		"GameState back to the countdown", show({ f:GS("PumpkinKingActive"), f:GS("PumpkinKingEndsAt"), f:GS("PumpkinKingNextAt") }))
	-- second king exactly 20:00 after the first appearance
	f:Advance(ta + 1200 - 0.5 - f.Now)
	check(#f:Kings() == 1, "no second king before 20:00", #f:Kings())
	f:Advance(0.5)
	check(#f:Kings() == 2 and f:GS("PumpkinKingNextAt") == ta + 2400, "second king at 20:00, the next at 40:00", show({ #f:Kings(), f:GS("PumpkinKingNextAt") }))
	-- defeated: defeat line on the next tick, the schedule is unchanged
	local k2 = f:King()
	local hero = f:AddPlayer("Hero")
	f.MS.DamageMonster(k2, k2.MaxHP + 1, hero)
	check(k2.Alive == false and k2.HP == 0, "the killing hit ends the king (HP 0)")
	before = lineCounts(f)
	f:Step(0.5)
	check(f:Keys() == "PumpkinKingAppear,PumpkinKingLeave,PumpkinKingAppear,PumpkinKingDefeat", "a defeated king gets the candy line once", f:Keys())
	ok, detail = clientsShowed(f, "PumpkinKingDefeat", before)
	check(ok, "every client shows the defeat line", detail)
	check(f.Removes == 1, "a defeated king is not removed a second time", f.Removes)
	check(f:GS("PumpkinKingActive") == false and f:GS("PumpkinKingNextAt") == ta + 2400, "after a defeat the countdown keeps the 20-minute rhythm",
		f:GS("PumpkinKingNextAt"))
	f:Advance(ta + 2400 - f.Now)
	check(#f:Kings() == 3, "third king at 40:00", #f:Kings())
	check(#f.Pays == 0 and #f.Respawns == 0, "HalloweenService never pays anything itself; event kings never respawn", show({ f.Pays, f.Respawns }))
	for _, line in f:Lines() do
		check(nameless(f, line), "no event payload carries a name", select(2, nameless(f, line)))
	end
end)

runGroup("king-rewards", function()
	local f = hwWorld()
	f:Advance(360)
	local king = f:King()
	assert(king, "no king")
	check(f.Config.MonsterTypes.PumpkinKing.ContributorWindow == 120, "the king's ContributorWindow is 120 s (finding)",
		f.Config.MonsterTypes.PumpkinKing.ContributorWindow)
	local early = f:AddPlayer("Early")
	local mid = f:AddPlayer("Mid", "SlimeMeadow", "Horns")
	local a = f:AddPlayer("Ace")
	local b = f:AddPlayer("Bo", "SlimeMeadow", "Neutral")
	local outside = f:AddPlayer("Outsider", "GoblinWoods")
	check(f.MS.DamageMonster(king, 100, early) == false and king.HP == king.MaxHP - 100, "a hit lowers the king's HP")
	check(f.MS.DamageMonster(king, 100, outside) == false and king._contributors[outside] == nil and king.HP == king.MaxHP - 100,
		"a player outside the meadow neither hurts nor joins it")
	f:Advance(30)
	f.MS.DamageMonster(king, 100, mid)
	f:Advance(95)
	f.MS.DamageMonster(king, 100, a)
	f:Advance(5)
	-- kill now: Early hit 130 s ago (outside 120 s), Mid 100 s ago (inside), Ace 5 s ago, Bo lands the killing blow
	local killed = f.MS.DamageMonster(king, king.HP, b)
	check(killed == true and king.Alive == false and king.HP == 0, "the killing blow defeats the king")
	local pop = f.Pops[#f.Pops]
	check(pop and pop.Rec == king and pop.Killed == true and not pop.Leaving, "a defeated king plays the normal death pop (not the leave fade)",
		show(pop and { pop.Killed, pop.Leaving }))
	local paid = {}
	for _, e in f.Killed do paid[e.Player.Name] = (paid[e.Player.Name] or 0) + 1 end
	check(paid.Mid == 1 and paid.Ace == 1 and paid.Bo == 1 and paid.Early == nil and paid.Outsider == nil and #f.Killed == 3,
		"MonsterKilled fires once per contributor of the last 120 s (one roll each, no duplicates)", show(paid))
	for _, e in f.Killed do
		local i = e.Info
		check(i.Kind == "PumpkinKing" and i.Golden == false and i.XP == 300 and i.Gold == 150 and i.ZoneId == "SlimeMeadow" and i.Personal == false,
			"each contributor's kill info = the king's XP 300 / Gold 150, never golden", show(i))
	end
	check(#f.Respawns == 0 and f.Mini.aliveCountOf("PumpkinKing") == 0, "a defeated event king never respawns")
	f:Step(0.5)
	check(#f.Killed == 3 and #f.Pays == 0, "the defeat line adds no second payout", show({ #f.Killed, #f.Pays }))
	-- a regular kind keeps the 15 s window
	local slime = f.H.spawnMonster("Slime", {})
	local old = f:AddPlayer("Old")
	f.MS.DamageMonster(slime, 1, old)
	f:Advance(20)
	f.MS.DamageMonster(slime, 100, a)
	local slimePaid = {}
	for _, e in f.Killed do if e.Info.Kind == "Slime" then slimePaid[e.Player.Name] = true end end
	check(slimePaid.Ace and not slimePaid.Old, "regular monsters keep Config.Monsters.ContributorWindow (15 s)", show(slimePaid))
	check(#f.Respawns == 1 and f.Respawns[1] == "Slime", "a regular kill still schedules its respawn", show(f.Respawns))
end)

-- the real MonsterService deathPop: a kill shrinks + bursts; leaving (RemoveEvent(rec, true, true)) marks "Leaving"
-- before the anchor, keeps every part's size, rises and fades a little slower
runGroup("king-leave-visual", function()
	local function popRun(withParticles, leaving)
		local f = { Tweens = {}, Delays = {}, Log = {}, Particles = 0 }
		local H = {
			TweenService = { Create = function(_, inst, info, goal)
				table.insert(f.Tweens, { Inst = inst, Info = info, Goal = goal })
				return { Play = function() end }
			end },
			emitDeathParticles = function() f.Particles += 1 end,
			task = { delay = function(sec) table.insert(f.Delays, sec) end },
		}
		local pop = execute("MonsterService.deathPop", MONSTER_POP_SOURCE, nativeEnv(), CONFIG, CONFIG.Monsters, H)
		local function part(name, size)
			return { Name = name, Size = size, Transparency = 0, IsA = function(_, c) return c == "BasePart" end }
		end
		local bar = { Enabled = true }
		local rootData = { Name = "HumanoidRootPart", Size = vec(2, 2, 1), Transparency = 1, Anchored = false, Parent = true,
			Position = vec(0, 3, 0), CFrame = vec(0, 3, 0), IsA = function(_, c) return c == "BasePart" end,
			FindFirstChild = function(_, n) if n == "MonsterBar" then return bar end return nil end }
		local root = setmetatable({}, { __index = rootData, __newindex = function(_, k, v)
			if k == "Anchored" then table.insert(f.Log, "anchor") end
			rootData[k] = v
		end })
		local mesh = part("Pumpkin", vec(5, 4, 5))
		local visualRoot = part("VisualRoot", vec(0.2, 0.2, 0.2))
		local model = { Attrs = {} }
		function model:SetAttribute(k, v) table.insert(f.Log, "attr:" .. k) self.Attrs[k] = v end
		function model:GetDescendants() return { root, visualRoot, mesh } end
		local hum = { Parent = true, WalkSpeed = 7 }
		pop({ Model = model, Root = root, Humanoid = hum, Def = CONFIG.MonsterTypes.PumpkinKing, _scale = 1 }, withParticles, leaving)
		f.Model, f.Root, f.Mesh, f.Bar, f.Hum, f.RootData = model, root, mesh, bar, hum, rootData
		return f
	end
	local function goalOf(f, inst)
		for _, tw in f.Tweens do if tw.Inst == inst then return tw.Goal end end
		return nil
	end
	local kill = popRun(true, nil)
	local kg = goalOf(kill, kill.Mesh)
	check(kill.Model.Attrs.Leaving == nil and kill.Particles == 1 and kg and kg.Size and near(kg.Size.X, 1) and kg.Transparency == 1,
		"a kill: the parts shrink to 0.2 and fade, with the particle burst", show(kg))
	check(kill.RootData.Anchored == true and kill.Bar.Enabled == false and goalOf(kill, kill.Root) == nil,
		"a kill: anchored on the spot, name bar off", show(kill.Log))
	local leave = popRun(false, true)
	local lg = goalOf(leave, leave.Mesh)
	check(leave.Model.Attrs.Leaving == true and leave.Log[1] == "attr:Leaving" and leave.Log[2] == "anchor",
		"leaving: the model is marked Leaving before the root anchors (clients skip the death splat)", show(leave.Log))
	check(lg and lg.Size == nil and lg.Transparency == 1 and leave.Particles == 0, "leaving: every part keeps its size and only fades (no burst)", show(lg))
	local rg = goalOf(leave, leave.Root)
	check(rg and rg.CFrame and rg.CFrame.Y > 3 + 1, "leaving: it floats up while it fades", show(rg))
	local lInfo = leave.Tweens[#leave.Tweens] and leave.Tweens[#leave.Tweens].Info
	check(lInfo and type(lInfo.Args[1]) == "number" and lInfo.Args[1] >= 0.8 and leave.Delays[1] and leave.Delays[1] >= lInfo.Args[1],
		"leaving: a slower fade than a kill, destroyed after it", show({ lInfo and lInfo.Args[1], leave.Delays[1], kill.Delays[1] }))
	check(leave.Bar.Enabled == false and leave.Hum.WalkSpeed == 0, "leaving: name bar off, it stops walking")
end)

runGroup("king-retry-lost-debug", function()
	local f = hwWorld()
	local t0 = f.StartAt
	-- no walkable ground and no spawn point: retry 10 s later, no line
	f.Ground, f.PickPoint = "water", nil
	f:Advance(360)
	check(#f:Kings() == 0 and #f:Lines() == 0 and f:GS("PumpkinKingNextAt") == t0 + 370, "no ground: no king, no line, retry in 10 s",
		show({ #f:Kings(), f:GS("PumpkinKingNextAt") }))
	check((f.PickCalls or 0) >= 1, "SpawnEvent fell back to a normal zone spawn point first")
	check(f.HS.DebugSpawn() == "no walkable spot found (try again)" and #f:Kings() == 0 and #f:Lines() == 0,
		"DebugSpawn with no ground says so and spawns nothing")
	f.Ground = "flat"
	f:Advance(10)
	check(#f:Kings() == 1 and f:Kings()[1].At == t0 + 370 and f:GS("PumpkinKingNextAt") == t0 + 370 + 1200, "the retry spawns it 10 s later",
		show({ #f:Kings(), f:GS("PumpkinKingNextAt") }))
	-- bare test place (no Terrain hit): legacy flat ground near the center
	-- lost model (fell out of the world): removed without HP 0 -> the leave line, not the candy line
	local k = f:King()
	f.Mini.despawn(k, false)
	f:Step(0.5)
	check(f:Keys() == "PumpkinKingAppear,PumpkinKingLeave" and f.Removes == 0, "a lost king gets the leave line (no candy line, no second removal)",
		f:Keys())
	-- Studio debug spawn: appears now, does not move the schedule; a slot that comes while it is here is skipped
	local nextAt = f:GS("PumpkinKingNextAt")
	f:Advance(nextAt - 100 - f.Now)
	local r = f.HS.DebugSpawn()
	check(r == "spawned" and #f:Kings() == 2 and f:GS("PumpkinKingNextAt") == nextAt and f:GS("PumpkinKingActive") == true,
		"DebugSpawn: the king appears now, the schedule is unchanged", show({ r, #f:Kings(), f:GS("PumpkinKingNextAt") }))
	check(f.HS.DebugSpawn() == "already here" and #f:Kings() == 2, "DebugSpawn while one is here: 'already here'")
	check(f.HS.IsKingActive() == true, "IsKingActive while it is alive")
	f:Advance(100)
	check(#f:Kings() == 2 and f:GS("PumpkinKingNextAt") == nextAt + 1200, "a scheduled slot while a king is here is skipped (+20:00)",
		show({ #f:Kings(), f:GS("PumpkinKingNextAt") }))
	f:Advance(200)
	check(f:Keys() == "PumpkinKingAppear,PumpkinKingLeave,PumpkinKingAppear,PumpkinKingLeave", "the debug king leaves after its 5:00", f:Keys())
	-- killed but not yet closed by the tick: DebugSpawn closes it with the candy line first
	local r2 = f.HS.DebugSpawn()
	local k3 = f:King()
	f.Mini.killRecord(k3)
	local r3 = f.HS.DebugSpawn()
	check(r2 == "spawned" and r3 == "spawned" and #f:Kings() == 4, "DebugSpawn after an unclosed kill spawns a fresh king", show({ r2, r3, #f:Kings() }))
	check(string.sub(f:Keys(), -#"PumpkinKingAppear,PumpkinKingDefeat,PumpkinKingAppear") == "PumpkinKingAppear,PumpkinKingDefeat,PumpkinKingAppear",
		"the defeated one gets its candy line before the next appears", f:Keys())
	-- bare place: legacy flat ground (noHit) is accepted
	local g = hwWorld()
	g.Ground = "bare"
	g:Advance(360)
	check(#g:Kings() == 1 and g:Kings()[1].Opts.Position and g.Config.ZoneAt(g:Kings()[1].Opts.Position).Id == "SlimeMeadow",
		"bare test place (no Terrain hit): the king still appears in the meadow", #g:Kings())
end)

runGroup("season-off", function()
	local f = hwWorld({ Season = false })
	check(f:GS("PumpkinKingNextAt") == 0 and f:GS("PumpkinKingActive") == false, "season off: no countdown in GameState", f:GS("PumpkinKingNextAt"))
	f:Advance(7200)
	check(#f.Spawned == 0 and #f:Lines() == 0 and f:GS("PumpkinKingNextAt") == 0, "season off: no king and no line in two hours",
		show({ #f.Spawned, #f:Lines(), f:GS("PumpkinKingNextAt") }))
	for _, kind in SEASONAL do
		check(f.Config.EffectiveMonsterCounts()[kind] == 0 and f.Config.MonsterActive(kind) == false, "season off: no seasonal kind in the pool", kind)
	end
	-- the Studio test aid still works with the season off, without starting a schedule
	check(f.HS.DebugSpawn() == "spawned" and #f:Kings() == 1 and f:Keys() == "PumpkinKingAppear", "season off: DebugSpawn still brings one (Studio aid)")
	check(f:GS("PumpkinKingActive") == true and f:GS("PumpkinKingNextAt") == 0, "season off: debug king active, no countdown")
	f.Mini.killRecord(f:King())
	f:Advance(3600)
	check(#f:Kings() == 1 and f:Keys() == "PumpkinKingAppear,PumpkinKingDefeat" and f:GS("PumpkinKingNextAt") == 0,
		"season off: after the debug king nothing is scheduled", f:Keys())
end)

runGroup("announce", function()
	local f = hwWorld()
	local A = f.Config.Announce
	local svc = f.Announce
	-- plain event lines: to everyone at once
	for _, key in { "PumpkinKingAppear", "PumpkinKingDefeat", "PumpkinKingLeave" } do
		local n, before = #f:Lines(), lineCounts(f)
		svc.Broadcast(key)
		local msg = f:Lines()[n + 1]
		check(#f:Lines() == n + 1 and msg and msg.Key == key and msg.Event == true and next(msg.Args) == nil, "Broadcast(key) = one FireAllClients", key)
		local ok, detail = clientsShowed(f, key, before)
		check(ok, "all three clients show it (English client in English)", detail)
	end
	check(f:Direct() == 0, "event lines are never sent per player")
	-- only event keys, only plain args
	local n = #f:Lines()
	svc.Broadcast("Jackpot")
	svc.Broadcast("RareWeapon")
	svc.Broadcast("NoSuchLine")
	check(#f:Lines() == n, "Broadcast ignores keys that are not event lines (Jackpot / RareWeapon / unknown)", #f:Lines() - n)
	svc.Broadcast("PumpkinKingAppear", { N = 3, Ok = true, P = f.Clients[1].Player, T = {} })
	local m = f:Lines()[#f:Lines()]
	check(m.Args.N == 3 and m.Args.Ok == true and m.Args.P == nil and m.Args.T == nil, "Broadcast keeps only plain argument values", show(m.Args))
	-- the client never prints a name for an event line, even if one were sent
	local mod = f.Clients[1].Module
	check(mod.Format({ Key = "PumpkinKingDefeat", Args = { Who = "Ana", Hidden = false, Faction = "Halo" } }) == A.Text.PumpkinKingDefeat,
		"client Format: an event line is the plain text, no finder", tostring(mod.Format({ Key = "PumpkinKingDefeat", Args = { Who = "Ana" } })))
	check(f.Clients[2].Module.Format({ Key = "PumpkinKingLeave", Args = {} }) == A.Text.PumpkinKingLeaveEn, "client Format: English setting -> the En twin")
	-- grouping: a player's RareWeapon window never swallows or delays an event line
	local p = f.Clients[1].Player
	local direct = f:Direct()
	svc.Announce(p, "RareWeapon", { Weapon = 4, Monster = "Goblin" }, "Rare")
	check(f:Direct() == direct + 3, "a RareWeapon line opens a window (one send per player)", f:Direct() - direct)
	svc.Announce(p, "RareWeapon", { Weapon = 4, Monster = "BatGoblin" }, "Rare")
	check(f:Direct() == direct + 3 and #f.Delays == 1, "a second RareWeapon in the window is grouped (pending)", #f.Delays)
	local lines = #f:Lines()
	svc.Broadcast("PumpkinKingDefeat")
	check(#f:Lines() == lines + 1 and #f.Delays == 1 and f:Direct() == direct + 3, "an event line in the middle goes out at once and leaves the group alone")
	f:Advance(A.WindowSeconds + 1)
	local more = 0
	for _, e in f:Log() do if not e.All and e.Args[1].Key == "More" then more += 1 end end
	check(more == 3, "the grouped 'More' line still follows (one per player)", more)
	-- the bat goblin weapon line names the kind on the client
	local rare = nil
	for _, line in f.Clients[1].Lines do if string.find(line, f.Config.MonsterTypes.Goblin.Short, 1, true) then rare = line end end
	check(rare ~= nil, "a RareWeapon line still shows (finder lines unchanged)")
end)

-- review 2026-10-06: a Boss kind (the Pumpkin King) never targets or hits a rookie (Rookie == true, or Level below
-- Config.Halloween.SafeBelowLevel); every other kind attacks rookies as usual. Real MonsterService targetable /
-- faceTarget / landAttack / isPlayerInTown (MONSTER_TARGET_SOURCE); CombatService.DamagePlayer is a recorder.
runGroup("king-spares-rookies", function()
	local f = hwWorld({ Clients = {} })
	local config, MC = f.Config, f.Config.Monsters
	local HW = config.Halloween
	local KING = HW.King
	local W = { hits = {}, roots = {}, serial = 0, players = 0 }
	local util = setmetatable({
		IsAlive = function(p) return W.roots[p] ~= nil end,
		GetRoot = function(p) return W.roots[p] end,
	}, { __index = f.Util })
	local H = { records = {}, S = { CombatService = { DamagePlayer = function(p, damage, src)
		table.insert(W.hits, { Player = p, Damage = damage, Src = src })
	end } } }
	function H.warnThrottled(key, msg) table.insert(groupWarnings, "MonsterService " .. tostring(key) .. ": " .. tostring(msg)) end
	local T = execute("MonsterService.target", MONSTER_TARGET_SOURCE,
		nativeEnv({ CFrame = { lookAt = function(_, at) return { LookAt = at } end } }), config, util, MC, H)
	local folder = INST.new("Folder", "Monsters")
	local function newRec(kind, pos)
		W.serial += 1
		local def = config.MonsterTypes[kind]
		local model = INST.new("Model", kind)
		model.Parent = folder
		-- already facing the target (faceTarget leaves it), not anchored
		local root = { Parent = model, Anchored = false, Position = pos, CFrame = { LookVector = { Dot = function() return 1 end } } }
		local rec = { Id = W.serial, Kind = kind, Def = def, Alive = true, ZoneId = def.Zone, Home = pos, Model = model, Root = root }
		H.records[rec.Id] = rec
		return rec
	end
	local function newPlayer(level, rookie, pos)
		W.players += 1
		local p = INST.new("Player", "P" .. W.players)
		p.UserId = 7000 + W.players
		p.Parent = f.PlayersService
		if level ~= nil then p:SetAttribute("Level", level) end
		if rookie ~= nil then p:SetAttribute("Rookie", rookie) end
		W.roots[p] = { Position = pos }
		return p
	end
	local function infoOf(p, zone)
		local pos = W.roots[p].Position
		return { Player = p, Pos = pos, Town = false, Zone = zone or config.ZoneAt(pos).Id }
	end
	-- one wound-up hit (attack() -> REACT.WINDUP later -> landAttack): returns hits dealt, AttackSeq bumped
	local function swing(rec, p)
		local token = {}
		rec._windup = token
		local before, seq = #W.hits, rec.Model:GetAttribute("AttackSeq")
		T.landAttack(rec, token, p)
		local hit = W.hits[#W.hits]
		return #W.hits - before, rec.Model:GetAttribute("AttackSeq") ~= seq, hit
	end

	local kdef = config.MonsterTypes[KING]
	check(HW.SafeBelowLevel == 5, "Config.Halloween.SafeBelowLevel is 5", HW.SafeBelowLevel)
	check(kdef ~= nil and kdef.Boss == true, "the Pumpkin King kind is a Boss", KING)
	local bosses = {}
	for _, kind in config.MonsterTypeOrder do
		if config.MonsterTypes[kind].Boss then table.insert(bosses, kind) end
	end
	check(#bosses == 1 and bosses[1] == KING, "the king is the only Boss kind (the rookie rule touches no other monster)",
		table.concat(bosses, ","))
	local spot = HW.SpawnSpots[1]
	local kpos = vec(spot.X, 0, spot.Z)
	local ppos = vec(spot.X + 2, 0, spot.Z)
	local zone = config.ZoneAt(ppos)
	check(config.ZoneAt(kpos).Id == kdef.Zone and zone.Id == kdef.Zone and zone.Town ~= true
		and f.Util.FlatDistance(kpos, ppos) <= MC.AttackRange, "setup: king and player stand in the meadow, in reach, outside towns",
		show({ config.ZoneAt(kpos).Id, zone.Id }))
	local king = newRec(KING, kpos)

	-- the Rookie shield: never targeted / hit at any level
	for _, level in { 1, 4, 5, 12, 40 } do
		local p = newPlayer(level, true, ppos)
		check(T.targetable(king, infoOf(p)) == false, "the king does not target a Rookie player (any level)", level)
		local n, bumped = swing(king, p)
		check(n == 0 and not bumped, "the king's wound-up hit never lands on a Rookie player (no damage, no lunge)",
			show({ level, n, bumped }))
	end
	-- below SafeBelowLevel without the shield (Rookie false or not set yet): Lv 1-4 are left alone
	for _, level in { 1, 2, 3, 4 } do
		for _, rookie in { false, "unset" } do
			local p = newPlayer(level, if rookie == "unset" then nil else rookie, ppos)
			check(T.targetable(king, infoOf(p)) == false, "the king does not target a Lv1-4 player (no Rookie shield)",
				show({ level, rookie }))
			local n, bumped = swing(king, p)
			check(n == 0 and not bumped, "the king's hit never lands on a Lv1-4 player", show({ level, rookie, n }))
		end
	end
	local noLevel = newPlayer(nil, false, ppos)
	check(T.targetable(king, infoOf(noLevel)) == false and select(1, swing(king, noLevel)) == 0,
		"a player whose Level is not set yet counts as Lv1 (spared)")
	-- Lv5+ without the shield: a normal target, hit for the king's Damage
	for _, level in { 5, 6, 10, 40 } do
		for _, rookie in { false, "unset" } do
			local p = newPlayer(level, if rookie == "unset" then nil else rookie, ppos)
			check(T.targetable(king, infoOf(p)) == true, "the king targets a Lv5+ non-rookie player", show({ level, rookie }))
			local n, bumped, hit = swing(king, p)
			check(n == 1 and bumped and hit and hit.Player == p and hit.Damage == kdef.Damage,
				"the king's hit lands on a Lv5+ non-rookie player (once, its own Damage, lunge played)",
				show({ level, rookie, n, bumped, hit and hit.Damage }))
		end
	end
	-- the usual rules still apply to a Lv5+ target: town, another zone, water
	local adult = newPlayer(10, false, ppos)
	local info = infoOf(adult)
	info.Town = true
	check(T.targetable(king, info) == false, "the king still ignores a Lv5+ player standing in a town")
	info = infoOf(adult, "GoblinWoods")
	check(T.targetable(king, info) == false, "the king still ignores a Lv5+ player in another zone")
	info = infoOf(adult)
	info.Pos = vec(ppos.X, T.OUT_Y - 1, ppos.Z)
	check(T.targetable(king, info) == false, "the king still ignores a Lv5+ player in the water")

	-- every other kind still targets and hits rookies as usual (in its own zone)
	local baby = newPlayer(1, true, ppos)
	for _, kind in config.MonsterTypeOrder do
		local def = config.MonsterTypes[kind]
		if not def.Boss then
			local rec = newRec(kind, vec(0, 0, 0))
			local ok = T.targetable(rec, { Player = baby, Pos = vec(0, 0, 0), Town = false, Zone = def.Zone })
			check(ok == true, "a normal (non-boss) monster still targets a Lv1 Rookie player", kind)
		end
	end
	for _, kind in { "Slime", "PumpkinSlime", "BigSlime" } do
		local def = config.MonsterTypes[kind]
		if check(def ~= nil and def.Zone == kdef.Zone, "meadow kind present for the hit check", kind) then
			local n, bumped, hit = swing(newRec(kind, kpos), baby)
			check(n == 1 and bumped and hit and hit.Damage == def.Damage, "a meadow monster's hit still lands on a Lv1 Rookie player",
				show({ kind, n, bumped }))
		end
	end
	-- a rookie can still hit the king and is remembered as a contributor (shares the candy)
	check(f.HS.DebugSpawn() == "spawned", "debug king spawned for the rookie hit check")
	local live = f:King()
	local hitter = f:AddPlayer("Sprout")
	hitter:SetAttribute("Rookie", true)
	hitter:SetAttribute("Level", 2)
	local hp = live and live.HP
	if live then f.MS.DamageMonster(live, 10, hitter) end
	check(live ~= nil and live.HP == hp - 10 and live._contributors[hitter] ~= nil,
		"a rookie can still hit the king and counts as a contributor", show({ hp, live and live.HP }))

	-- the AI uses the same rule for keeping and picking a target (aiStep), and landAttack checks it again at impact
	local mon = MONSTER_SOURCE
	check(string.find(mon, "elseif not targetable(rec, tinfo) then", 1, true) ~= nil
		and string.find(mon, "\t\tfor _, info in plist do\n\t\t\tif targetable(rec, info) then", 1, true) ~= nil,
		"aiStep drops a current target and picks a new one only through targetable()")
end)

------------------------------------------------------------------ 9. EventHUD Pumpkin King pill (real KING block + helpers)
local function hudWorld(config, rs, isTouch)
	local H = { C = {}, ui = {}, RS = rs, IsTouch = isTouch == true, Relayouts = 0, ChipsBottom = nil }
	local root = { AbsolutePosition = vec(0, 0, 0), AbsoluteSize = vec(1280, 720, 0), IsA = function(_, c) return c == "GuiBase2d" end }
	H.Root = root
	H.ui.Strip = { AbsolutePosition = vec(460, 64, 0), AbsoluteSize = vec(360, 39, 0), Size = { Y = { Offset = 39 } }, Parent = root }
	H.ui.KingChip = { Visible = false }
	H.ui.KingChipText = { Text = "" }
	H.ui.KaijuChip = { Visible = false }
	function H.hudBottom(name) if name == "StatusChips" then return H.ChipsBottom end return nil end
	function H.relayout() H.Relayouts += 1 end
	local util = execute("Util", UTIL_SOURCE, nativeEnv({ game = { GetService = function() return {} end }, Random = RANDOM, workspace = {} }))
	local KING, L = execute("EventHUD.KING", KING_HUD_SOURCE, nativeEnv(), config, util, H)
	return { KING = KING, L = L, H = H, Chip = H.ui.KingChip, Text = H.ui.KingChipText }
end

runGroup("hud", function()
	local config = newConfig()
	local rs = INST.new("ReplicatedStorage")
	local gs = INST.new("Folder", "GameState")
	gs.Parent = rs
	local h = hudWorld(config, rs)
	local T = config.Halloween.Text
	local now = 1000
	h.KING.update(now)
	check(h.Chip.Visible == false, "no GameState attributes: the pill stays hidden")
	gs:SetAttribute("PumpkinKingNextAt", now + 360)
	gs:SetAttribute("PumpkinKingActive", false)
	h.KING.update(now)
	check(h.Chip.Visible == true and h.Text.Text == string.format(T.HudNext, "6:00") and h.Text.Text == "호박 대왕까지 6:00",
		"countdown line '호박 대왕까지 m:ss'", h.Text.Text)
	h.KING.update(now + 298.6)
	check(h.Text.Text == "호박 대왕까지 1:01", "m:ss counts down", h.Text.Text)
	gs:SetAttribute("PumpkinKingActive", true)
	gs:SetAttribute("PumpkinKingEndsAt", now + 600)
	h.KING.update(now + 300.8)
	check(h.Chip.Visible == true and h.Text.Text == "호박 대왕 출현! 남은 시간 4:59", "while it is here: '호박 대왕 출현! 남은 시간 m:ss'", h.Text.Text)
	h.H.C.Settings = { Get = function(k) if k == "Lang" then return "en" end return nil end }
	h.KING.update(now + 300.8)
	check(h.Text.Text == string.format(T.HudActiveEn, "4:59"), "English setting: English twin while it is here", h.Text.Text)
	gs:SetAttribute("PumpkinKingActive", false)
	h.KING.update(now)
	check(h.Text.Text == string.format(T.HudNextEn, "6:00"), "English setting: English countdown", h.Text.Text)
	h.H.C.Settings = nil
	gs:SetAttribute("PumpkinKingNextAt", 0)
	h.KING.update(now)
	check(h.Chip.Visible == false, "NextAt 0 and nothing active: hidden")
	gs:SetAttribute("PumpkinKingNextAt", now + 60)
	config.Halloween.Enabled = false
	gs:SetAttribute("PumpkinKingActive", true)
	h.KING.update(now)
	check(h.Chip.Visible == false, "season off: the pill never shows (even for a Studio debug king)")
	config.Halloween.Enabled = true
	gs:SetAttribute("PumpkinKingActive", false)
	-- placement (logical px, UIScale 1): left of the strip while there is room (shrinks to KingMinW)
	local L = h.L
	h.H.ui.Strip.AbsolutePosition = vec(460, 64, 0)
	h.KING.update(now)
	local sz = h.Chip.Size
	check(L.KingW == 210 and L.KingMinW == 130 and h.Chip.AnchorPoint and h.Chip.AnchorPoint.X == 1 and sz and sz.Ctor == "fromOffset"
		and sz.Args[1] == L.KingW and sz.Args[2] == L.PillH, "room left of the strip: full-width pill on the left", show(sz))
	h.H.ui.Strip.AbsolutePosition = vec(160, 64, 0)
	h.KING.update(now)
	sz = h.Chip.Size
	check(sz and sz.Ctor == "fromOffset" and sz.Args[1] == 160 - 2 * L.KingGap, "less room: the pill shrinks to the room", show(sz))
end)

-- review 2026-10-06: the pill never sits on HUD's player card / quest column (HUD.Layout.LeftX), its bottom-right
-- cluster or the kaiju pill; with no room beside the strip it takes a row under HUD's status chips and the touch
-- personal line moves down (KING.Below -> relayout)
runGroup("hud-king-placement", function()
	local config = newConfig()
	local rs = INST.new("ReplicatedStorage")
	local gs = INST.new("Folder", "GameState")
	gs.Parent = rs
	local now = 1000
	gs:SetAttribute("PumpkinKingNextAt", now + 360)
	gs:SetAttribute("PumpkinKingActive", false)
	-- the pill's logical box from its AnchorPoint / Position / Size relative to the strip
	local function box(h, x0, stripW, y0)
		local c = h.Chip
		local w = c.Size.Args[1]
		local ax, pos = c.AnchorPoint.X, c.Position.Args
		local left = x0 + pos[1] * stripW + pos[2] - ax * w
		return { Left = left, Right = left + w, Top = y0 + pos[3] * 39 + pos[4], W = w }
	end
	local function place(touch, layout, x0, stripW, opts)
		opts = opts or {}
		local h = hudWorld(config, rs, touch)
		h.H.C.HUD = layout and { Layout = layout } or nil
		h.H.Root.AbsoluteSize = vec(layout and layout.W or 1280, 720, 0)
		h.H.ui.Strip.AbsolutePosition = vec(x0, 70, 0)
		h.H.ui.Strip.AbsoluteSize = vec(stripW, 39, 0)
		h.H.ui.KaijuChip.Visible = opts.Kaiju == true
		h.H.ChipsBottom = opts.ChipsBottom
		h.KING.update(now)
		return h, box(h, x0, stripW, 70)
	end
	local L = nil
	-- phone 844x390 (UIScale 0.75 -> 1125 logical): card + quests column ends at 272 (LeftX 280), strip 383..743
	local phone = { W = 1125, H = 520, LeftX = 280, RightX = 1113, ClusterTop = 300, ClusterLeft = 900 }
	local h, b = place(true, phone, 383, 360)
	L = h.L
	check(h.Chip.Visible and b.Left >= phone.LeftX and b.Left >= 383 + 360 + L.KingGap and b.Right <= phone.RightX and b.W == L.KingW
		and h.KING.Below == false, "phone: no room left of the strip -> right of it, clear of the player card", show(b))
	-- phone with the kaiju pill showing: after it, shrunk to the room
	h, b = place(true, phone, 383, 360, { Kaiju = true })
	check(b.Left >= 743 + L.KingGap + 200 + L.KingGap and b.Right <= phone.RightX and b.W >= L.KingMinW and b.W < L.KingW,
		"phone + kaiju pill: the king pill sits after the kaiju pill", show(b))
	-- notched phone (1000 logical) + kaiju pill: no room on either side -> a row under the status chips
	local notch = { W = 1000, H = 520, LeftX = 280, RightX = 988, ClusterTop = 300, ClusterLeft = 780 }
	h, b = place(true, notch, 320, 360, { Kaiju = true, ChipsBottom = 143 })
	check(h.KING.Below == true and b.Top == 143 + L.StripGap and b.Left >= notch.LeftX and b.W == L.KingW and h.H.Relayouts == 1,
		"no room beside the strip: centred under HUD's status chips, the personal line relayouts", show({ b, h.H.Relayouts }))
	h.KING.update(now)
	check(h.H.Relayouts == 1, "staying under the chips does not relayout again", h.H.Relayouts)
	gs:SetAttribute("PumpkinKingNextAt", 0)
	h.KING.update(now)
	check(h.Chip.Visible == false and h.KING.Below == false and h.H.Relayouts == 2, "pill hidden: the personal line moves back up", h.H.Relayouts)
	gs:SetAttribute("PumpkinKingNextAt", now + 360)
	-- status chips not found yet: their fallback row
	h, b = place(true, notch, 320, 360, { Kaiju = true })
	check(h.KING.Below and b.Top == 70 + 39 + L.StripGap + L.ChipsH + L.StripGap, "chips frame missing: the fallback chip row is skipped too", show(b))
	-- the touch cluster reaching up to the strip row blocks the right slot
	h, b = place(true, { W = 1125, H = 520, LeftX = 280, RightX = 1113, ClusterTop = 60, ClusterLeft = 800 }, 383, 360, { ChipsBottom = 143 })
	check(h.KING.Below == true and b.Top == 143 + L.StripGap, "HUD's button cluster up at the strip row: the pill goes under the chips", show(b))
	-- desktop 1280x720 (UIScale 0.8 -> 1600 logical): plenty of room left of the strip, right of the 300 px card
	local desk = { W = 1600, H = 900, LeftX = 320, RightX = 1370, ClusterTop = 700, ClusterLeft = 1400 }
	h, b = place(false, desk, 620, 360)
	check(h.Chip.AnchorPoint.X == 1 and b.Left >= desk.LeftX and b.Right == 620 - L.KingGap and b.W == L.KingW,
		"desktop 16:9: left of the strip, clear of the player card", show(b))
	-- desktop 4:3 (1024x768 -> 1200 logical): too narrow on the left, right of the strip (left of the luck panel)
	local d43 = { W = 1200, H = 900, LeftX = 320, RightX = 970, ClusterTop = 700, ClusterLeft = 1000 }
	h, b = place(false, d43, 420, 360)
	check(b.Left >= 780 + L.KingGap and b.Right <= d43.RightX and b.W == 970 - 788 and h.KING.Below == false,
		"desktop 4:3: right of the strip, inside HUD's RightX (luck panel)", show(b))
	-- every placement above keeps the pill off the card column: re-check the phone with the quests hidden (LeftX 232)
	h, b = place(true, { W = 1125, H = 520, LeftX = 232, RightX = 1113, ClusterTop = 300, ClusterLeft = 900 }, 383, 360)
	check(h.Chip.AnchorPoint.X == 1 and b.Left >= 232 and b.W == 383 - L.KingGap - 232, "phone, quests hidden: the left room between the card and the strip",
		show(b))
end)

runGroup("hud-live", function()
	-- integration: the real HalloweenService GameState drives the pill
	local w = hwWorld()
	local hw = hudWorld(w.Config, w.RS)
	hw.KING.update(w.Now)
	check(hw.Chip.Visible and hw.Text.Text == "호박 대왕까지 6:00", "live: right after server start '호박 대왕까지 6:00'", hw.Text.Text)
	w:Advance(360)
	hw.KING.update(w.Now)
	check(hw.Text.Text == "호박 대왕 출현! 남은 시간 5:00", "live: when it appears '남은 시간 5:00'", hw.Text.Text)
	w.MS.DamageMonster(w:King(), 1e9, w:AddPlayer("Z"))
	w:Advance(130)
	hw.KING.update(w.Now)
	check(hw.Text.Text == "호박 대왕까지 17:50", "live: after the defeat the countdown to the next one (20:00 after it appeared)", hw.Text.Text)
end)

------------------------------------------------------------------ 10. Fx WOBBLE float (real isSlimeModel + WOBBLE)
local function wobbleWorld(config)
	local f = { Clock = 100, Models = {} }
	local folder = { GetChildren = function() return f.Models end }
	local ws = { CurrentCamera = { CFrame = { Position = vec(0, 0, 0) } },
		FindFirstChild = function(_, n) if n == "Monsters" then return folder end return nil end }
	local H = { C = { MonsterMotion = { IsRigged = function(m) return m.Rigged == true end } }, MOTION = { HURT_SEQ_ATTR = "HurtSeq" },
		TweenService = { Create = function() return { Play = function() end } end },
		visualJoint = function(m) return m.Joint end, monsterRoot = function(m) return m.Root end, monsterSize = function() return 4, 2.2 end }
	local env = nativeEnv({ CFrame = D.CFrame, workspace = ws, os = setmetatable({ clock = function() return f.Clock end }, { __index = os }) })
	f.W = execute("Fx.WOBBLE", WOBBLE_SOURCE, env, config, H)
	function f:Model(kind, opts)
		opts = opts or {}
		local m = { Attrs = { MonsterKind = kind }, Sig = {}, AncestryChanged = signal(), Rigged = opts.Rigged,
			Joint = { C1 = D.CFrame.identity, Parent = {}, IsA = function(_, c) return c == "Weld" or c == "JointInstance" end },
			Root = { Anchored = false, Position = vec(10, 0, 0), AssemblyLinearVelocity = opts.Velocity or vec(5, 0, 0), Parent = {} } }
		if opts.Mesh then m.Mesh = { Size = opts.Mesh, IsA = function(_, c) return c == "MeshPart" end } end
		function m:GetAttribute(k) return self.Attrs[k] end
		function m:GetAttributeChangedSignal(k) self.Sig[k] = self.Sig[k] or signal() return self.Sig[k] end
		function m:IsA(c) return c == "Model" end
		function m:FindFirstChild(n)
			if n == "CustomVisual" and self.Mesh then
				local mesh = self.Mesh
				return { GetDescendants = function() return { mesh } end }
			end
			return nil
		end
		table.insert(self.Models, m)
		return m
	end
	-- the visual's offset from the root: C1:Inverse() (Part1 = Part0 * C0 * C1:Inverse(), C0 = identity)
	function f:Lift(m) local inv = m.Joint.C1:Inverse() return inv.Y, inv.Rz, inv.Rx, inv.Ry end
	function f:Step(dt) self.Clock += dt self.W.step(dt) end
	return f
end

runGroup("fx-float", function()
	local config = newConfig(function(c)
		c.MonsterTypes.TestFloatSlime = { Shape = "Slime", Float = 2, Zone = "SlimeMeadow", Count = 0 }
	end)
	local f = wobbleWorld(config)
	local ghost = f:Model("LittleGhost")
	local goblin = f:Model("Goblin")
	local bat = f:Model("BatGoblin", { Rigged = true })
	local pslime = f:Model("PumpkinSlime", { Mesh = vec(3.1, 2, 2.1) })
	local king = f:Model("PumpkinKing", { Mesh = vec(5, 4, 4.75) })
	local fslime = f:Model("TestFloatSlime", { Mesh = vec(2, 2, 2) })
	local st = f.W.track(ghost)
	check(st and st.Float == 1.5 and not st.Slime, "the little ghost is tracked as a floater (Float 1.5)", show(st and { st.Float, st.Slime }))
	local up = f:Lift(ghost)
	check(near(up, 1.5), "it hovers 1.5 studs up from the start (also out of camera range)", up)
	local ps = f.W.track(pslime)
	check(ps and ps.Float == nil and ps.Slime == true, "pumpkin slime: slime hop / squash, no float")
	-- review 2026-10-06 (user: "슬라임이 이상해 보여"): the old depth = width stretch is gone; slime meshes keep their
	-- designed shape
	check(near(pslime.Mesh.Size.X, 3.1) and near(pslime.Mesh.Size.Z, 2.1) and near(pslime.Mesh.Size.Y, 2),
		"slime meshes keep their designed shape (no depth = width stretch)", show(pslime.Mesh.Size))
	local ks = f.W.track(king)
	check(ks and ks.Float == nil and ks.Slime == true and near(king.Mesh.Size.X, 5) and near(king.Mesh.Size.Y, 4)
		and near(king.Mesh.Size.Z, 4.75), "Pumpkin King: slime path, mesh keeps its designed shape", show(king.Mesh.Size))
	local fs = f.W.track(fslime)
	check(fs and fs.Float == nil, "a Float value on a slime shape is ignored (slimes unchanged)")
	f.W.track(goblin)
	f.W.track(bat)
	local gmin, gmax, groll, gotherRot = math.huge, -math.huge, 0, 0
	local bmax, broll = 0, 0
	local smax, sroll = -math.huge, 0
	local wmax, wroll = 0, 0
	for i = 1, 600 do
		if i == 200 then ghost.Sig.HurtSeq:Fire() end
		f:Step(1 / 30)
		local y, rz, rx, ry = f:Lift(ghost)
		gmin, gmax = math.min(gmin, y), math.max(gmax, y)
		groll = math.max(groll, math.abs(rz))
		gotherRot = math.max(gotherRot, math.abs(rx), math.abs(ry))
		local by, brz = f:Lift(bat)
		bmax, broll = math.max(bmax, math.abs(by)), math.max(broll, math.abs(brz))
		local sy, srz = f:Lift(pslime)
		smax, sroll = math.max(smax, sy), math.max(sroll, math.abs(srz))
		local wy, wrz = f:Lift(goblin)
		wmax, wroll = math.max(wmax, math.abs(wy)), math.max(wroll, math.abs(wrz))
	end
	check(gmin >= 1.5 - 0.25 - 0.3 - 1e-6 and gmax <= 1.5 + 0.25 + 1e-6, "the ghost bobs within 1.5 +- 0.25 (a hit dips it at most 0.3 more)",
		string.format("%.3f .. %.3f", gmin, gmax))
	check(gmax - gmin >= 0.4, "the ghost really bobs (slow sine)", string.format("%.3f .. %.3f", gmin, gmax))
	check(gmin > 0.9, "the ghost never touches the floor", gmin)
	check(groll == 0 and gotherRot == 0, "the ghost never rolls or tilts (no waddle)", groll)
	check(wroll > 0.05 and wmax <= 0.23, "a walking goblin still waddles (roll), low bob", string.format("roll %.3f bob %.3f", wroll, wmax))
	check(bmax == 0 and broll == 0, "the rigged bat goblin gets no procedural wobble (MonsterMotion moves its bones)", show({ bmax, broll }))
	check(smax > 0.1 and sroll == 0, "the pumpkin slime hops (no roll)", smax)
	-- out of range / dying: the ghost keeps hovering at Float
	ghost.Root.Position = vec(1000, 0, 0)
	f:Step(1 / 30)
	local restY, restRoll = f:Lift(ghost)
	check(near(restY, 1.5) and restRoll == 0, "out of camera range it rests hovering at 1.5", restY)
	ghost.Root.Position = vec(10, 0, 0)
	f:Step(1 / 30)
	ghost.Root.Anchored = true
	f:Step(1 / 30)
	check(near((f:Lift(ghost)), 1.5), "dying (anchored root): it stays hovering, it does not drop to the floor", (f:Lift(ghost)))
	-- review 2026-10-06: a dying slime splats; the Pumpkin King going home ("Leaving") just rests at its normal size
	local g = wobbleWorld(config)
	local dying = g:Model("PumpkinSlime", { Mesh = vec(3, 2, 3) })
	local leaving = g:Model("PumpkinKing", { Mesh = vec(5, 4, 5) })
	for _ = 1, 10 do g:Step(1 / 30) end
	dying.Root.Anchored = true
	leaving.Attrs.Leaving = true
	leaving.Root.Anchored = true
	g:Step(1 / 30)
	local ds, ls = g.W.State[dying], g.W.State[leaving]
	check(ds and ds.Splat == true and (g:Lift(dying)) < 0, "a killed slime still splats flat", show(ds and { ds.Splat, (g:Lift(dying)) }))
	check(ls and not ls.Splat and near((g:Lift(leaving)), 0) and near(leaving.Mesh.Size.Y, ls.Base.Y) and near(leaving.Mesh.Size.X, ls.Base.X),
		"a leaving king: no splat, back to its rest size and pose while it floats away", show(ls and { ls.Splat, leaving.Mesh.Size }))
end)

------------------------------------------------------------------ 11. Main.server.luau (INIT / START lists, Studio DebugCommand)
local function mainWorld(isStudio)
	local f = { Inits = {}, Starts = {}, Bindables = {}, DebugCalls = 0, GooseCalls = 0 }
	local config = newConfig()
	local rs = INST.new("ReplicatedStorage")
	local shared = INST.new("Folder", "Shared")
	shared.Parent = rs
	INST.new("ModuleScript", "Net").Parent = shared
	INST.new("ModuleScript", "Config").Parent = shared
	local sss = { Name = "ServerScriptService" }
	function sss:WaitForChild(n) return { Name = n, Service = true } end
	local hero = { Name = "P1", ClassName = "Player" }
	local players = { FindFirstChild = function(_, n) if n == "P1" then return hero end return nil end }
	local services = { ReplicatedStorage = rs, ServerScriptService = sss, Players = players,
		RunService = { IsStudio = function() return isStudio end, IsServer = function() return true end },
		HttpService = { JSONEncode = function(_, v) return show(v) end } }
	local stubs = {}
	local function service(name)
		local s = { Name = name }
		s.Init = function(reg) table.insert(f.Inits, name); f.Registry = reg end
		s.Start = function() table.insert(f.Starts, name) end
		return s
	end
	local env = nativeEnv({ game = { GetService = function(_, n) return assert(services[n], "service " .. tostring(n)) end },
		print = function() end, warn = function(...) table.insert(groupWarnings, "warn: " .. table.concat({ ... }, " ")) end,
		Instance = { new = function(c)
			assert(c == "BindableFunction", "unexpected Instance.new " .. tostring(c))
			local b = { ClassName = c }
			table.insert(f.Bindables, b)
			return b
		end },
		require = function(m)
			if m.Service then
				stubs[m.Name] = stubs[m.Name] or service(m.Name)
				return stubs[m.Name]
			end
			if m.Name == "Net" then return { CreateAll = function() f.Created = true end } end
			if m.Name == "Config" then return config end
			error("unexpected require " .. tostring(m.Name))
		end })
	execute("Main.server", MAIN_SOURCE, env)
	f.Stubs = stubs
	return f
end

runGroup("main-debug", function()
	local f = mainWorld(true)
	local function idx(list, name) return table.find(list, name) end
	check(idx(f.Inits, "HalloweenService") ~= nil and f.Registry and f.Registry.HalloweenService == f.Stubs.HalloweenService,
		"HalloweenService is required and Init(registry) is called", show(f.Inits))
	check(idx(f.Starts, "HalloweenService") ~= nil and idx(f.Starts, "HalloweenService") > idx(f.Starts, "MonsterService")
		and idx(f.Starts, "HalloweenService") > idx(f.Starts, "AnnounceService"), "HalloweenService starts after MonsterService and AnnounceService",
		show(f.Starts))
	local n = 0
	for _, name in f.Starts do if name == "HalloweenService" then n += 1 end end
	check(n == 1, "HalloweenService starts once", n)
	check(#f.Bindables == 1 and f.Bindables[1].Name == "DebugCommand" and type(f.Bindables[1].OnInvoke) == "function",
		"Studio: the DebugCommand BindableFunction exists", #f.Bindables)
	local hs = f.Stubs.HalloweenService
	hs.DebugSpawn = function(...) f.DebugCalls += 1; f.DebugArgs = table.pack(...); return "spawned" end
	f.Stubs.PlayerService.IsReady = function() return true end
	f.Stubs.GooseService.DebugStart = function() f.GooseCalls += 1 end
	local invoke = f.Bindables[1] and f.Bindables[1].OnInvoke
	if invoke then
		local r = invoke("P1", "PumpkinKing", 12345)
		check(r == "spawned" and f.DebugCalls == 1 and f.DebugArgs.n == 0, "DebugCommand 'PumpkinKing' calls HalloweenService.DebugSpawn() (value ignored) and returns its result",
			show({ r, f.DebugCalls, f.DebugArgs and f.DebugArgs.n }))
		check(invoke("Nobody", "PumpkinKing", 1) == "no such ready player" and f.DebugCalls == 1, "unknown player: refused, nothing spawned")
		invoke("P1", "Goose")
		check(f.GooseCalls == 1 and f.DebugCalls == 1, "other keys are unchanged (Goose does not spawn the king)")
	end
	local live = mainWorld(false)
	check(#live.Bindables == 0, "outside Studio there is no DebugCommand at all", #live.Bindables)
	check(idx(live.Starts, "HalloweenService") ~= nil, "outside Studio the service still starts")
end)

------------------------------------------------------------------ 12. BatGoblin clips (MonsterAnims modules)
local CLIP_SPEC = { Idle = { 32, true }, Walk = { 36, true }, Slash = { 31, false }, Hurt = { 16, false }, Fall = { 46, false } }

runGroup("clips", function()
	local function load(name)
		local src = CLIPS[name]
		if type(src) ~= "string" then return nil end
		local fn = loadstring(src, "=" .. name)
		local ok, clip = pcall(fn)
		return ok and clip or nil
	end
	for clip, spec in CLIP_SPEC do
		local bat, gob = load("BatGoblin_" .. clip), load("Goblin_" .. clip)
		check(type(bat) == "table" and type(gob) == "table", "BatGoblin_" .. clip .. " and Goblin_" .. clip .. " load as tables", clip)
		if type(bat) == "table" and type(gob) == "table" then
			check(bat.Fps == 15 and gob.Fps == 15, "15 fps", clip)
			check(bat.Frames == spec[1] and bat.Frames == gob.Frames, "frame count = the Goblin clip's (" .. spec[1] .. ")", clip .. " " .. tostring(bat.Frames))
			check(bat.Loop == spec[2] and bat.Loop == gob.Loop, "loop flag = the Goblin clip's (Idle / Walk loop)", clip .. " " .. tostring(bat.Loop))
			local missing, extra, pdiff = {}, {}, {}
			for name, e in gob.Bones do
				if not bat.Bones[name] then table.insert(missing, name) elseif (e.p ~= nil) ~= (bat.Bones[name].p ~= nil) then table.insert(pdiff, name) end
			end
			for name in bat.Bones do if not gob.Bones[name] then table.insert(extra, name) end end
			check(#missing == 0 and #extra == 0, "the same bone names as the Goblin clip (Tripo biped)", clip .. " missing " .. show(missing) .. " extra " .. show(extra))
			if #pdiff > 0 then finding("BatGoblin_" .. clip .. ": translation tracks differ from Goblin on " .. table.concat(pdiff, ", ")) end
			local badLen, badNorm, badNum, differs = 0, 0, 0, false
			for name, e in bat.Bones do
				if type(e.r) ~= "table" or #e.r ~= 4 * bat.Frames then badLen += 1 end
				if e.p ~= nil and #e.p ~= 3 * bat.Frames then badLen += 1 end
				for i = 0, bat.Frames - 1 do
					local x, y, z, w = e.r[i * 4 + 1], e.r[i * 4 + 2], e.r[i * 4 + 3], e.r[i * 4 + 4]
					if type(x) ~= "number" or type(w) ~= "number" then badNum += 1 break end
					local norm = math.sqrt(x * x + y * y + z * z + w * w)
					if math.abs(norm - 1) > 0.002 then badNorm += 1 end
				end
				for _, v in e.p or {} do if v ~= v or math.abs(v) > 100 then badNum += 1 end end
				local g = gob.Bones[name]
				if g and g.r[1] ~= e.r[1] then differs = true end
			end
			check(badLen == 0, "every track has one key per frame (r: 4, p: 3 numbers)", clip .. " " .. badLen)
			check(badNorm == 0 and badNum == 0, "rotations are unit quaternions, positions finite", clip .. " " .. show({ badNorm, badNum }))
			check(differs, "the BatGoblin clip is its own motion (not a copy of the Goblin data)", clip)
			if spec[2] then
				local seam, gseam = 0, 0
				for name, e in bat.Bones do
					local last = (bat.Frames - 1) * 4
					seam = math.max(seam, math.abs(e.r[1] - e.r[last + 1]) + math.abs(e.r[4] - e.r[last + 4]))
					local g = gob.Bones[name]
					if g then gseam = math.max(gseam, math.abs(g.r[1] - g.r[last + 1]) + math.abs(g.r[4] - g.r[last + 4])) end
				end
				finding(string.format("BatGoblin_%s loop seam (max |q0 - qlast| x+w): %.3f (Goblin %.3f)", clip, seam, gseam))
			end
		end
	end
	local kind = CONFIG.MonsterTypes.BatGoblin
	check(kind and kind.Shape == "Humanoid" and kind.Float == nil, "BatGoblin is a walking humanoid kind (MonsterMotion finds 'BatGoblin_<Clip>')")
end)

------------------------------------------------------------------ 13. client / server wiring read from sources
runGroup("client-wiring", function()
	local items = PANELS_ITEMS_SOURCE
	local loopAt = string.find(items, "for _, kind in Config.MonsterTypeOrder do", 1, true)
	local activeAt = loopAt and string.find(items, "Config.MonsterActive(kind)", loopAt, true)
	check(loopAt ~= nil and activeAt ~= nil and activeAt - loopAt < 400,
		"Panels '몬스터가 주는 것' loops over MonsterTypeOrder and skips kinds whose season is off (Config.MonsterActive)")
	-- the same filter on the real Config: in season all ten kinds can show, out of season the six year-round ones
	local cOff = newConfig(function(c) c.Halloween.Enabled = false end)
	local on, off = 0, 0
	for _, kind in CONFIG.MonsterTypeOrder do
		if CONFIG.Loot.Tables[kind] and CONFIG.MonsterActive(kind) then on += 1 end
		if cOff.Loot.Tables[kind] and cOff.MonsterActive(kind) then off += 1 end
	end
	check(on == 10 and off == 6, "drop list kinds: 10 in season, 6 out of season", on .. "/" .. off)
	-- MonsterService pieces that are not run here
	local mon = MONSTER_SOURCE
	check(string.find(mon, "local kind, noRespawn = rec.Kind, rec.Owner ~= nil or rec.Event == true", 1, true) ~= nil
		and string.find(mon, "if not noRespawn then scheduleRespawn(kind) end", 1, true) ~= nil,
		"a lost event king is not respawned by the AI (aiStep model-lost branch)")
	check(string.find(mon, "topAboveRoot + 1.6 + math.max(0, tonumber(def.Float) or 0)", 1, true) ~= nil,
		"the name bar is raised by Float for hovering kinds")
	check(string.find(mon, "Event = opts.Event == true or nil", 1, true) ~= nil, "spawnMonster marks SpawnEvent records (Event = true)")
	local _, fires = string.gsub(mon, "MonsterKilled:Fire%(", "")
	check(fires == 1, "MonsterKilled is fired in one place only (the per-contributor loop)", fires)
	-- the Net defaults HalloweenService publishes (real Net.CreateAll in the king worlds)
	local net = execute("Net", NET_SOURCE, nativeEnv({ game = { GetService = function() return { IsServer = function() return true end } end } }))
	local dflt = net.GameStateDefaults
	check(dflt.PumpkinKingNextAt == 0 and dflt.PumpkinKingActive == false and dflt.PumpkinKingEndsAt == 0,
		"Net.GameStateDefaults has PumpkinKingNextAt 0 / PumpkinKingActive false / PumpkinKingEndsAt 0", show(dflt))
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
print("HALLOWEEN_RESULT_JSON " .. enc({ Checks = total, Failed = failedCount, Named = list, Findings = findings }))
if failedCount == 0 then
	print("HALLOWEEN_OFFLINE_OK checks=" .. total .. " Studio/API calls=0")
else
	print("HALLOWEEN_OFFLINE_FAILED checks=" .. total .. " failed=" .. failedCount)
end
