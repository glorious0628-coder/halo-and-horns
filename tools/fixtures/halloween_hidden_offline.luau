-- A23-119 (user 2026-10-11): the Pumpkin Patch and the Haunted Hollow are hidden. The real Config.luau as shipped (no season
-- override) with engine doubles. Input: CONFIG_SOURCE.
local checks, failed = 0, 0
local function check(ok, name, detail)
	checks += 1
	if not ok then
		failed += 1
		print("CHECK_FAIL " .. name .. " :: " .. tostring(detail))
	end
end
local ENUM
do
	local types = {}
	ENUM = setmetatable({}, { __index = function(_, typeName)
		local t = types[typeName]
		if not t then
			local cache = {}
			t = setmetatable({}, { __index = function(_, itemName)
				local e = cache[itemName]
				if not e then
					e = { Name = itemName, EnumType = typeName, __kind = "EnumItem" }
					cache[itemName] = e
				end
				return e
			end })
			types[typeName] = t
		end
		return t
	end })
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
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local env = setmetatable({ Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec },
	Color3 = { new = vec, fromRGB = vec, fromHSV = vec }, BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"),
	UDim2 = ctor("UDim2"), UDim = ctor("UDim"), NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"),
	ColorSequence = ctor("ColorSequence"), NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), CFrame = ctor("CFrame"),
	TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = ENUM }, { __index = getfenv() })
local fn = assert(loadstring(CONFIG_SOURCE, "=Config"))
setfenv(fn, env)
local Config = fn()

local H = Config.Halloween
local function has(list, id) return list[id] ~= nil end
local SEASONAL_ZONES = { PumpkinPatch = true, HauntedHollow = true }
local SEASONAL_KINDS = { "PumpkinSlime", "BatGoblin", "GhostMinion", "LittleGhost", "PumpkinKing", "GhostKing" }

-- the switch itself
check(type(H) == "table" and H.Enabled == false, "Config.Halloween.Enabled is false as shipped (the season is hidden)", H and tostring(H.Enabled))
check(Config.SeasonOn("Halloween") == false and Config.SeasonOn(nil) == true, "SeasonOn: Halloween is off, no season is on", "")
check(Config.SeasonOn("Halloween", true) == true, "the test override still turns it on (the code and the data are not deleted)", "")

-- zones: both leave ZoneAt; the rest is untouched
local zoneSeasonal, zoneCount = {}, 0
for id, z in Config.Zones do
	zoneCount += 1
	if z.Season ~= nil then zoneSeasonal[id] = z.Season end
end
check(zoneSeasonal.PumpkinPatch == "Halloween" and zoneSeasonal.HauntedHollow == "Halloween" and next(zoneSeasonal, next(zoneSeasonal, next(zoneSeasonal))) == nil,
	"only the two Halloween fields are seasonal zones (still in Config.Zones: nothing is deleted)", "")
for id in SEASONAL_ZONES do
	local z = Config.Zones[id]
	check(Config.ZoneAt(z.Center).Id == "Outskirts" and Config.ZoneAt(z.Spawn).Id == "Outskirts", id .. ": its middle and its spawn read as Outskirts (the zone is gone)", Config.ZoneAt(z.Center).Id)
end
for _, id in { "Crossroads", "HaloTown", "HornsTown", "SlimeMeadow", "GoblinWoods", "SkeletonRuins" } do
	local z = Config.Zones[id]
	check(z ~= nil and Config.ZoneAt(z.Center).Id == id, id .. " is untouched", id)
end

-- monsters: every seasonal kind is off, and nothing else lives in the two fields
local seasonal = 0
for kind, def in Config.MonsterTypes do
	if def.Season ~= nil then
		seasonal += 1
		check(Config.MonsterActive(kind) == false, kind .. " does not spawn", tostring(Config.MonsterActive(kind)))
	else
		check(not SEASONAL_ZONES[def.Zone], kind .. " (no season) lives outside the two fields", tostring(def.Zone))
	end
end
check(seasonal == #SEASONAL_KINDS, "exactly the six Halloween kinds are seasonal", seasonal)
for _, kind in SEASONAL_KINDS do
	check(Config.MonsterTypes[kind] ~= nil and Config.MonsterTypes[kind].Season == "Halloween", kind .. " is kept (data stays) and is a Halloween kind", kind)
end
check(Config.MonsterActive("Slime") == true and Config.MonsterActive("Goblin") == true and Config.MonsterActive("SkeletonKnight") == true, "the base kinds are on", "")

-- the lost things: the candy bag (the hidden patch) is not offered
local offered = {}
for _, id in Config.LostFound.Order do
	local d = Config.LostFound.Items[id]
	if Config.SeasonOn(d.Season) then offered[id] = d.Zone end
end
check(offered.CandyBag == nil and offered.Teddy == "SlimeMeadow" and offered.ClubBadge == "GoblinWoods" and offered.GuardMedal == "SkeletonRuins",
	"lost & found: the candy bag is not offered, the other three are", "")

-- nothing a player is told or asked to do names the hidden fields (quests, dailies, the tutorial, help, boards, daily intro)
local BAN = { "pumpkin", "haunted", "halloween", "candy", "spooky" }
local hits = {}
local function scan(v, path, seen, depth)
	if type(v) == "string" then
		local low = string.lower(v)
		for _, w in BAN do
			if string.find(low, w, 1, true) then table.insert(hits, path .. " = " .. string.sub(v, 1, 50)) break end
		end
	elseif type(v) == "table" and not seen[v] and depth < 14 then
		seen[v] = true
		for k, x in v do scan(x, path .. "." .. tostring(k), seen, depth + 1) end
	end
end
for _, name in { "StoryQuests", "Quests", "Tutorial", "Help", "Board", "Daily", "Goose", "Skills", "Deeds", "Titles", "ChoiceCard", "Nudges", "Return" } do
	local root = Config[name]
	if root ~= nil then
		local seen = {}
		if name == "ChoiceCard" and type(root) == "table" then root = { Kinds = { LostTeddy = root.Kinds and root.Kinds.LostTeddy } } end -- LostCandy is only offered by the candy bag
		scan(root, name, seen, 0)
	end
end
check(#hits == 0, "no quest, daily, tutorial, help, board or deed text names pumpkins, haunted places, Halloween or candy", table.concat(hits, " | "))
-- ... and no quest step or daily points at a hidden zone or a seasonal kind by id
local pointers = {}
for id, def in Config.StoryQuests.Defs do
	for i, step in def.Steps or {} do
		local o = step.Obj or {}
		for _, f in { o.Zone, o.Kind, o.Spot, step.Guide, o.Near } do
			if f ~= nil and (SEASONAL_ZONES[f] or table.find(SEASONAL_KINDS, f)) then table.insert(pointers, id .. "." .. i .. ":" .. tostring(f)) end
		end
	end
end
check(#pointers == 0, "no story quest step points at a hidden zone or a Halloween kind", table.concat(pointers, " | "))
for _, row in Config.Quests.Templates do
	check(row.Zone == nil or not SEASONAL_ZONES[row.Zone], "daily template " .. tostring(row.Id) .. " is not a hidden-zone job", tostring(row.Zone))
end

-- the news window: no Halloween line, no December 19 (the beta is 12/1, the launch is late January and is dated in December)
local news = {}
for _, block in Config.Help.News do
	for _, line in block.Lines do table.insert(news, line) end
end
local joined = string.lower(table.concat(news, " "))
check(not string.find(joined, "halloween", 1, true) and not string.find(joined, "pumpkin", 1, true) and not string.find(joined, "haunted", 1, true),
	"the news window has no Halloween line", joined)
check(not string.find(joined, "december 19", 1, true) and not string.find(joined, "dec 19", 1, true), "the news window names no launch date that moved (December 19)", joined)
check(string.find(joined, "full launch", 1, true) ~= nil and string.find(joined, "beta pioneer", 1, true) ~= nil, "the beta lines stay (the save carries over, Beta Pioneer)", joined)

-- the live switch can only turn it off: it exists, and (checked in the test's static part) SwitchService ANDs it with the Config value
check(Config.Switches.Defs.Halloween ~= nil and Config.Switches.Defs.Halloween.Type == "Bool", "the live switch Halloween still exists", "")
print("HALLOWEEN_HIDDEN_SUMMARY checks=" .. checks .. " failed=" .. failed)
