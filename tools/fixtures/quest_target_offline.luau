-- Offline checks for QuestTarget (A23-36 quest target, A23-30 pumpkin patch, A23-45 haunted hollow routes). The runner
-- (tools/test_quest_target.py) prepends CONFIG_SOURCE and QT_SOURCE (the current Config.luau / QuestTarget.luau text).
-- Roblox is replaced by small doubles: Vector3 maths, a workspace.Map tree with the parts QuestTarget looks up (Pads,
-- Gates, Decor bridges, Landmarks), Instance.new for its local anchors and a LocalPlayer with attributes and a root part.
-- Every check is named (case :: check) and collected, never asserted. No Studio, Roblox API or network calls.

local Named, order = {}, {}
local checks, failed = 0, 0
local function check(group, name, ok, detail)
	checks += 1
	local key = group .. " :: " .. name
	local n = Named[key]
	if not n then
		n = { Group = group, Name = name, Pass = 0, Fail = 0 }
		Named[key] = n
		table.insert(order, key)
	end
	if ok then
		n.Pass += 1
	else
		n.Fail += 1
		failed += 1
		if not n.FirstFailure then n.FirstFailure = tostring(detail or "") end
		print(("CHECK_FAIL %s :: %s :: %s"):format(group, name, tostring(detail or "")))
	end
end

local function encode(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" then return (string.format("%.4f", v):gsub("%.?0+$", "")) end
	if t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			if c == '"' then return '\\"' end
			if c == "\\" then return "\\\\" end
			return string.format("\\u%04x", string.byte(c))
		end) .. '"'
	end
	if #v > 0 or next(v) == nil then
		local parts = {}
		for _, x in ipairs(v) do table.insert(parts, encode(x)) end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local keys = {}
	for k in v do table.insert(keys, tostring(k)) end
	table.sort(keys)
	local parts = {}
	for _, k in keys do table.insert(parts, encode(k) .. ":" .. encode(v[k])) end
	return "{" .. table.concat(parts, ",") .. "}"
end

----------------------------------------------------------------- engine doubles
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
local function rgb(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, __kind = "Color3" } end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local function typeofDouble(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end

-- instances: Children list, IsA, FindFirstChild(WhichIsA), Parent assignment adds the child to its parent
local PART_CLASSES = { Part = true, MeshPart = true, WedgePart = true }
local imt = {}
imt.__index = {
	IsA = function(self, c)
		return c == self.ClassName or c == "Instance" or (c == "BasePart" and PART_CLASSES[self.ClassName] == true)
	end,
	FindFirstChild = function(self, n)
		for _, ch in self.Children do
			if ch.Name == n then return ch end
		end
		return nil
	end,
	GetChildren = function(self) return table.clone(self.Children) end,
	GetAttribute = function(self, k) return rawget(self, "Attrs") and self.Attrs[k] or nil end,
	FindFirstChildWhichIsA = function(self, c, recursive)
		for _, ch in self.Children do
			if ch:IsA(c) then return ch end
			if recursive then
				local d = ch:FindFirstChildWhichIsA(c, true)
				if d then return d end
			end
		end
		return nil
	end,
}
imt.__newindex = function(self, key, value)
	if key == "Parent" then
		rawset(self, "Parent", value)
		if type(value) == "table" and value.Children then table.insert(value.Children, self) end
		return
	end
	rawset(self, key, value)
end
local function inst(class, name, props)
	local o = setmetatable({ __kind = "Instance", ClassName = class, Name = name, Children = {} }, imt)
	for k, v in props or {} do rawset(o, k, v) end
	return o
end
local function add(parent, child)
	child.Parent = parent
	return child
end

local WORKSPACE, PLAYER, ATTR = nil, nil, {}
local function newWorld()
	WORKSPACE = inst("Workspace", "Workspace")
	WORKSPACE.GetServerTimeNow = function() return 1790000000 end -- 2026-09 (Halloween on; Config.SeasonNow)
	local map = add(WORKSPACE, inst("Folder", "Map"))
	local pads = add(map, inst("Folder", "Pads"))
	local gates = add(map, inst("Folder", "Gates"))
	local decor = add(map, inst("Folder", "Decor"))
	local marks = add(map, inst("Folder", "Landmarks"))
	for _, z in { "SlimeMeadow", "GoblinWoods", "SkeletonRuins", "HaloTown", "HornsTown" } do
		add(pads, inst("Part", "Pad_" .. z, { Position = vec(10, 1, 10) }))
	end
	add(gates, inst("Part", "Gate_SlimeMeadow", { Position = vec(80, 3, 0) }))
	add(decor, inst("Part", "Bridge_Halo", { Position = vec(0, 1, -250) }))
	add(decor, inst("Part", "Bridge_Horns", { Position = vec(0, 1, 250) }))
	local sign = add(marks, inst("Model", "PumpkinPatchSign"))
	add(sign, inst("Part", "Board", { Position = vec(525, 5, 226) })) -- map v2: Config.Map.Halloween.SignPos
	local guild = add(marks, inst("Model", "ArtisanGuild"))
	add(guild, inst("Part", "Anvil", { Position = vec(-30, 2, 10) }))
	ATTR = {}
	local root = inst("Part", "HumanoidRootPart", { Position = vec(0, 3, 0) })
	local char = inst("Model", "Character")
	add(char, root)
	PLAYER = { Character = char, GetAttribute = function(_, n) return ATTR[n] end, Root = root }
end

local function envFor()
	local shared = { WaitForChild = function(_, n) return { __module = n } end }
	local game = { GetService = function(_, n)
		if n == "Players" then return { LocalPlayer = PLAYER } end
		if n == "ReplicatedStorage" then return { WaitForChild = function() return shared end } end
		return {}
	end }
	return { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = vec, zero = vec(0, 0, 0) },
		Color3 = { new = function(r, g, b) return rgb(r * 255, g * 255, b * 255) end, fromRGB = rgb,
			fromHSV = function() return rgb(0, 0, 0) end },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
		NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
		NumberSequenceKeypoint = ctor("NumberSequenceKeypoint"), ColorSequenceKeypoint = ctor("ColorSequenceKeypoint"),
		CFrame = ctor("CFrame"), TweenInfo = ctor("TweenInfo"), Font = ctor("Font"), Enum = enum, typeof = typeofDouble,
		game = game, workspace = WORKSPACE,
		Instance = { new = function(class) return inst(class, class) end } }
end

local function execute(name, text, env)
	local fn, err = loadstring(text, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end

-- a fresh world, Config and QuestTarget (season override: Config.Halloween.Enabled)
local function load(season)
	newWorld()
	local env = envFor()
	local Config = execute("Config", CONFIG_SOURCE, env)
	if season == false and type(Config.Halloween) == "table" then Config.Halloween.Enabled = false end
	env.require = function() return Config end
	local QT = execute("QuestTarget", QT_SOURCE, env)
	return QT, Config
end

local function where(t)
	if t == nil then return "nil" end
	if typeofDouble(t) == "Vector3" then return ("(%g,%g,%g)"):format(t.X, t.Y, t.Z) end
	local p = t.Position
	return ("%s(%g,%g,%g)"):format(tostring(t.Name), p and p.X or 0 / 0, p and p.Y or 0 / 0, p and p.Z or 0 / 0)
end
local function isNamed(t, name) return type(t) == "table" and t.Name == name end
local function at(t, x, z) return type(t) == "table" and t.Position and math.abs(t.Position.X - x) <= 0.5 and math.abs(t.Position.Z - z) <= 0.5 end

----------------------------------------------------------------- cases
local results = {}
do
	local g = "hollow route"
	local QT, Config = load(true)
	local hollow = Config.Zones and Config.Zones.HauntedHollow
	check(g, "Config has the HauntedHollow zone", type(hollow) == "table", tostring(hollow))
	check(g, "Halloween is on at the pinned clock", Config.SeasonOn("Halloween") == true, "season off")
	-- from the Crossroads: the meadow pad (the patch route starts with the meadow trip)
	local t = QT.Travel("HauntedHollow", "Crossroads", vec(0, 3, 0))
	check(g, "Crossroads -> meadow pad", isNamed(t, "Pad_SlimeMeadow"), where(t))
	-- in the meadow: the patch sign
	t = QT.Travel("HauntedHollow", "SlimeMeadow", vec(330, 3, 0))
	check(g, "meadow -> the pumpkin patch sign", isNamed(t, "Board") and at(t, 525, 226), where(t))
	-- on the meadow land but ZoneId Outskirts: still the sign
	t = QT.Travel("HauntedHollow", "Outskirts", vec(400, 3, 160))
	check(g, "meadow land (Outskirts id) -> the sign", isNamed(t, "Board"), where(t))
	-- in the passage: the patch field
	t = QT.Travel("HauntedHollow", "Outskirts", vec(535, 3, 235))
	check(g, "passage -> the patch field", type(t) == "table" and tostring(t.Name):find("PumpkinField", 1, true) ~= nil, where(t))
	-- in the patch: the gap in its west fence
	t = QT.Travel("HauntedHollow", "PumpkinPatch", vec(535, 3, 335))
	check(g, "patch -> the west fence gap", type(t) == "table" and tostring(t.Name):find("HollowGate", 1, true) ~= nil
		and at(t, 420, 340), where(t))
	-- on the patch land with an Outskirts id: still the gap
	t = QT.Travel("HauntedHollow", "Outskirts", vec(600, 3, 300))
	check(g, "patch land (Outskirts id) -> the gap", type(t) == "table" and at(t, 420, 340), where(t))
	-- inside the hollow: nothing to point at (by id and by position)
	check(g, "inside the hollow (id) -> nil", QT.Travel("HauntedHollow", "HauntedHollow", vec(320, 3, 342)) == nil, "not nil")
	check(g, "inside the hollow (position) -> nil", QT.Travel("HauntedHollow", "", vec(320, 3, 342)) == nil, "not nil")
	-- a story guide to the hollow routes the same way (Story -> Travel, even from inside another zone)
	t = QT.Story("HauntedHollow", "PumpkinPatch", vec(535, 3, 335), "Halo")
	check(g, "story guide -> the gap", type(t) == "table" and at(t, 420, 340), where(t))
	local e = QT.ForEntry({ Story = { Guide = "HauntedHollow" } }, "PumpkinPatch", "Halo", vec(535, 3, 335))
	check(g, "story entry is a travel to the hollow", type(e) == "table" and e.Travel == true and e.Zone == "HauntedHollow",
		e and encode({ Zone = e.Zone, Travel = e.Travel, Tag = e.Tag }) or "nil")
	-- the pumpkin patch itself keeps its own route (the hollow did not change it)
	t = QT.Travel("PumpkinPatch", "PumpkinPatch", vec(535, 3, 335))
	check(g, "pumpkin patch from inside -> nil", t == nil, where(t))
	t = QT.Travel("PumpkinPatch", "SlimeMeadow", vec(330, 3, 0))
	check(g, "pumpkin patch from the meadow -> the sign", isNamed(t, "Board"), where(t))
	results.hollow = true
end
do
	local g = "season off"
	local QT, Config = load(false)
	check(g, "Halloween off", Config.SeasonOn("Halloween") == false, "still on")
	check(g, "hollow -> nil from the Crossroads", QT.Travel("HauntedHollow", "Crossroads", vec(0, 3, 0)) == nil, "not nil")
	check(g, "hollow -> nil from the patch", QT.Travel("HauntedHollow", "PumpkinPatch", vec(535, 3, 335)) == nil, "not nil")
	check(g, "patch -> nil", QT.Travel("PumpkinPatch", "SlimeMeadow", vec(330, 3, 0)) == nil, "not nil")
end
do
	-- 빛 마을 점검 #52 (2026-10-10): a town's own travel pad (Map.Pads child with TravelTo, standing in the town)
	local g = "town pads"
	local QT, Config = load(true)
	local t = QT.Travel("SlimeMeadow", "HaloTown", vec(0, 3, -420))
	check(g, "no town pad yet: the meadow from the Halo town -> its bridge as before", isNamed(t, "Bridge_Halo"), where(t))
	local pads = WORKSPACE:FindFirstChild("Map"):FindFirstChild("Pads")
	local pad = add(pads, inst("Part", "Pad_Halo_SlimeMeadow", { Position = vec(-20, 1, -500), Attrs = { TravelTo = "SlimeMeadow" } }))
	t = QT.Travel("SlimeMeadow", "HaloTown", vec(0, 3, -420))
	check(g, "with the Halo plaza pad: the meadow -> that pad (no bridge walk)", t == pad, where(t))
	check(g, "TownPad finds it for the Halo town only", QT.TownPad("HaloTown", "SlimeMeadow") == pad
		and QT.TownPad("HornsTown", "SlimeMeadow") == nil and QT.TownPad("HaloTown", "GoblinWoods") == nil)
	local mpad = add(pads, inst("Model", "Pad_Halo_GoblinWoods", { Attrs = { TravelTo = "GoblinWoods" } }))
	add(mpad, inst("Part", "Top", { Position = vec(20, 1, -500) }))
	check(g, "a Model pad is ignored (ZoneService connects BaseParts only, 검수 10/10)", QT.TownPad("HaloTown", "GoblinWoods") == nil)
	t = QT.Travel("GoblinWoods", "HaloTown", vec(0, 3, -420))
	check(g, "a zone the town pads do not go to -> the usual route", t ~= pad, where(t))
	t = QT.Travel("SlimeMeadow", "Crossroads", vec(0, 3, 0))
	check(g, "from the Crossroads the Crossroads pad stays", isNamed(t, "Pad_SlimeMeadow"), where(t))
end

do
	local g = "plain zones"
	local QT = load(true)
	local t = QT.Travel("GoblinWoods", "Crossroads", vec(0, 3, 0))
	check(g, "woods from the Crossroads -> its pad", isNamed(t, "Pad_GoblinWoods"), where(t))
	check(g, "already in the zone -> nil", QT.Travel("GoblinWoods", "GoblinWoods", vec(950, 3, 0)) == nil, "not nil")
	t = QT.Travel("SlimeMeadow", "HaloTown", vec(0, 3, -400))
	check(g, "meadow from the Halo town -> the bridge", isNamed(t, "Bridge_Halo"), where(t))
	check(g, "unknown zone -> nil", QT.Travel("Nowhere", "Crossroads", vec(0, 3, 0)) == nil, "not nil")
end

do
	-- A23-36 rows: the pinned row's place, the claim flag (QuestMarker gold) and the English labels (A23-48)
	local g = "rows"
	local QT, Config = load(true)
	-- Hangul syllables are 3-byte UTF-8 sequences starting with 0xEA..0xED
	local function hangul(s)
		if type(s) ~= "string" then return false end
		for k = 1, #s do
			local b = string.byte(s, k)
			if b >= 0xEA and b <= 0xED then return true end
		end
		return false
	end
	-- tutorial step 1 from the Crossroads: a travel to the meadow pad, not claimable
	local e = QT.ForEntry({ Pinned = true, TutorialStep = 1, Progress = 0, Target = 1, CanClaim = true }, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "step 1 from the Crossroads -> meadow pad", type(e) == "table" and isNamed(e.Part, "Pad_SlimeMeadow") and e.Travel == true,
		e and encode({ Tag = e.Tag, Travel = e.Travel }) or "nil")
	check(g, "step 1 is not a claim", type(e) == "table" and e.Claim == false, e and tostring(e.Claim) or "nil")
	-- A23-74 weapon first: the Forge step (3) = the anvil in the Crossroads, the Crossroads from elsewhere - even when
	-- an early visit already set BlacksmithVisited
	ATTR.BlacksmithVisited = true
	local forgeRow = { Id = "tutorial", Kind = "Tutorial", Pinned = true, TutorialStep = 3, Text = "Get your first weapon · Crossroads Forge",
		ShortName = "To the Forge", CanClaim = false, Progress = 0, Target = 1 }
	e = QT.ForEntry(forgeRow, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "Forge step in the Crossroads -> the mark 9 studs over the anvil (BlacksmithVisited ignored)", type(e) == "table"
		and isNamed(e.Part, "HUDGuideAnchor_SmithMark") and at(e.Part, -30, 10) and math.abs(e.Part.Position.Y - 11) <= 0.5
		and e.Travel == false and e.Tag == "blacksmith" and e.Claim == false, where(e and e.Part))
	-- 10/08 Play photo: standing at the anvil the mark lined up with the Goblin Woods pad sign -> no marker there
	e = QT.ForEntry(forgeRow, "Crossroads", "Halo", vec(-22, 3, 14))
	check(g, "Forge step standing at the anvil (9 studs) -> no marker (its own prompt is right there)", e == nil,
		e and encode({ Tag = e.Tag }) or "nil")
	e = QT.ForEntry(forgeRow, "Crossroads", "Halo", vec(-30, 3, 30))
	check(g, "... 20 studs away -> the mark again", type(e) == "table" and isNamed(e.Part, "HUDGuideAnchor_SmithMark"),
		where(e and e.Part))
	e = QT.ForEntry(forgeRow, "SlimeMeadow", "Halo", vec(330, 3, 0))
	check(g, "Forge step from the meadow -> a trip to the Crossroads", type(e) == "table" and e.Travel == true and e.Zone == "Crossroads",
		e and encode({ Tag = e.Tag, Zone = e.Zone, Travel = e.Travel }) or "nil")
	-- 빛 마을 점검 #16 (2026-10-10): from a zone that walks to the forge the mark over the anvil at once (it pointed at
	-- the Crossroads spawn plaza and the distance jumped up at the bridge end)
	for _, z in { "HaloTown", "HornsTown", "Outskirts" } do
		e = QT.ForEntry(forgeRow, z, "Halo", vec(0, 3, z == "HornsTown" and 420 or -420))
		check(g, "Forge step from " .. z .. " -> the mark over the anvil, no trip", type(e) == "table"
			and isNamed(e.Part, "HUDGuideAnchor_SmithMark") and at(e.Part, -30, 10) and e.Travel == false,
			e and encode({ Tag = e.Tag, Zone = e.Zone, Travel = e.Travel }) or "nil")
	end
	-- walking home -> forge (spawn (0,-420) up the road through the bridge to the plaza, then to the anvil): the
	-- target never changes and the distance only goes down
	local walk, last, same, firstPart = {}, math.huge, true, nil
	for zz = -420, 0, 20 do table.insert(walk, { Zone = zz < -200 and "HaloTown" or (zz < -60 and "Outskirts" or "Crossroads"), P = vec(0, 3, zz) }) end
	for k = 1, 5 do table.insert(walk, { Zone = "Crossroads", P = vec(-30 * k / 6, 3, 10 * k / 6) }) end
	local down = true
	for _, w in walk do
		e = QT.ForEntry(forgeRow, w.Zone, "Halo", w.P)
		if e then
			firstPart = firstPart or e.Part
			if e.Part ~= firstPart then same = false end
			local d = math.sqrt((w.P.X - e.Position.X) ^ 2 + (w.P.Z - e.Position.Z) ^ 2)
			if d > last + 1e-6 then down = false end
			last = d
		end
	end
	check(g, "walking from the Halo spawn to the anvil: the same mark all the way", same and firstPart ~= nil)
	check(g, "... and the distance only goes down", down, last)
	local guild = WORKSPACE:FindFirstChild("Map"):FindFirstChild("Landmarks"):FindFirstChild("ArtisanGuild")
	local kept = guild.Children
	rawset(guild, "Children", {})
	e = QT.ForEntry(forgeRow, "HaloTown", "Halo", vec(0, 3, -420))
	check(g, "no anvil (not built yet) -> the Crossroads trip as before", type(e) == "table" and e.Travel == true and e.Zone == "Crossroads",
		e and encode({ Tag = e.Tag, Zone = e.Zone, Travel = e.Travel }) or "nil")
	rawset(guild, "Children", kept)
	ATTR.BlacksmithVisited = nil
	-- step 2 with every kill done: nothing to walk to
	ATTR.TutorialKills = 5
	e = QT.ForEntry({ Pinned = true, TutorialStep = 2, Progress = 5, Target = 5, CanClaim = true }, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "step 2 with 5/5 kills -> nil", e == nil, e and encode({ Tag = e.Tag }) or "nil")
	ATTR.TutorialKills = nil
	-- step 99 blacksmith visit inside the Crossroads: the anvil, labelled in English
	e = QT.ForEntry({ Pinned = true, TutorialStep = 99, NextGoal = false, Text = "Visit the Forge", Progress = 0, Target = 1,
		CanClaim = true }, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "blacksmith step -> the mark over the anvil (its label clears the pad signs)", type(e) == "table"
		and isNamed(e.Part, "HUDGuideAnchor_SmithMark") and at(e.Part, -30, 10) and e.Travel == false, where(e and e.Part))
	check(g, "blacksmith label is English", type(e) == "table" and e.Label == "Forge" and not hangul(e.Label), e and tostring(e.Label) or "nil")
	-- the same row done and waiting for [Claim]: gold marker
	e = QT.ForEntry({ Pinned = true, TutorialStep = 99, NextGoal = false, Text = "Visit the Forge", Progress = 1, Target = 1,
		CanClaim = true }, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "done + CanClaim -> Claim", type(e) == "table" and e.Claim == true, e and tostring(e.Claim) or "nil")
	e = QT.ForEntry({ Pinned = true, TutorialStep = 99, NextGoal = false, Text = "Visit the Forge", Progress = 1, Target = 1,
		CanClaim = false }, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "done but CanClaim false -> no Claim", type(e) == "table" and e.Claim == false, e and tostring(e.Claim) or "nil")
	-- after the visit the iron-weapon gold goal (English row text, A23-48) still points at the anvil from the meadow
	local iron = Config.Weapons[3]
	ATTR.BlacksmithVisited, ATTR.Level = true, iron.MinLevel
	e = QT.ForEntry({ Pinned = true, TutorialStep = 99, NextGoal = true, Text = "Save 800 Gold for an iron weapon", Progress = 0,
		Target = 800, CanClaim = true }, "SlimeMeadow", "Halo", vec(330, 3, 0))
	check(g, "English gold goal -> the forge trip", type(e) == "table" and e.Tag == "blacksmith" and e.Zone == "Crossroads",
		e and encode({ Tag = e.Tag, Zone = e.Zone }) or "nil")
	-- a level goal goes to the hunting zone of my level (Lv 5 -> the meadow): nil while I am in it, the pad from town
	e = QT.ForEntry({ Pinned = true, TutorialStep = 99, NextGoal = true, Text = "Reach Lv 10", Progress = 5, Target = 10,
		CanClaim = true }, "SlimeMeadow", "Halo", vec(330, 3, 0))
	check(g, "level goal inside its zone -> nil", e == nil, e and encode({ Tag = e.Tag }) or "nil")
	e = QT.ForEntry({ Pinned = true, TutorialStep = 99, NextGoal = true, Text = "Reach Lv 10", Progress = 5, Target = 10,
		CanClaim = true }, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "level goal from town -> the meadow pad", type(e) == "table" and isNamed(e.Part, "Pad_SlimeMeadow"),
		e and encode({ Tag = e.Tag }) or "nil")
	ATTR.BlacksmithVisited, ATTR.Level = nil, nil
	-- daily rows have no place; a story pond step labels in English
	check(g, "daily row -> nil", QT.ForEntry({ Kind = "Daily", Progress = 0, Target = 3, CanClaim = true }, "Crossroads", "Halo",
		vec(0, 3, 0)) == nil, "not nil")
	e = QT.ForEntry({ Story = { Id = "X", St = 1, Guide = "SlimePond" } }, "SlimeMeadow", "Halo", vec(330, 3, 120))
	check(g, "pond step label is English", type(e) == "table" and e.Label == "Slime Pond", e and tostring(e.Label) or "nil")
	-- 빛 마을 점검 #17 / #21 / #29 (2026-10-10): a guide that is a story landmark spot (H6 HeroStatue, WoodsGate,
	-- GoblinCamp1, ...) -> a trip to its zone from elsewhere, an anchor over the spot inside it, nothing inside the
	-- Near radius share
	local hero = { Story = { Id = "H6", St = 1, Guide = "HeroStatue" } }
	local spot = Config.StoryQuests.Landmarks.HeroStatue
	local heroZone = Config.ZoneAt(spot).Id
	e = QT.ForEntry(hero, "SlimeMeadow", "Halo", vec(330, 3, 0))
	check(g, "HeroStatue from the meadow -> a trip to its town", type(e) == "table" and e.Travel == true and e.Zone == heroZone
		and heroZone == "HaloTown", e and encode({ Zone = e.Zone, Travel = e.Travel }) or "nil")
	-- 검수 10/10: a landmark a walk away (the Crossroads <-> the towns, like the forge) -> the spot itself, no trip
	e = QT.ForEntry(hero, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "HeroStatue from the Crossroads (a walk away) -> the statue spot straight away, no trip", type(e) == "table"
		and e.Travel == false and isNamed(e.Part, "HUDGuideAnchor_Spot_HeroStatue") and at(e.Part, spot.X, spot.Z),
		e and encode({ Zone = e.Zone, Travel = e.Travel }) or "nil")
	local bridge = Config.StoryQuests.Landmarks.HaloBridge
	e = QT.ForEntry({ Story = { Id = "X", St = 1, Guide = "HaloBridge" } }, "HaloTown", "Halo", vec(0, 3, -470))
	check(g, "HaloBridge from the Halo town -> the bridge spot, no trip", type(e) == "table" and e.Travel == false
		and at(e.Part, bridge.X, bridge.Z), e and encode({ Zone = e.Zone, Travel = e.Travel }) or "nil")
	e = QT.ForEntry(hero, heroZone, "Halo", vec(0, 3, -470))
	check(g, "HeroStatue inside the town -> the anchor over the statue spot", type(e) == "table" and e.Travel == false
		and isNamed(e.Part, "HUDGuideAnchor_Spot_HeroStatue") and at(e.Part, spot.X, spot.Z) and math.abs(e.Part.Position.Y - 3) <= 0.5,
		where(e and e.Part))
	e = QT.ForEntry(hero, heroZone, "Halo", vec(spot.X + 4, 3, spot.Z))
	check(g, "... standing at the statues (inside the Near radius share) -> nothing", e == nil, e and encode({ Tag = e.Tag }) or "nil")
	local gate = Config.StoryQuests.Landmarks.WoodsGate
	local gateZone = Config.ZoneAt(gate).Id
	e = QT.ForEntry({ Story = { Id = "H1", St = 2, Guide = "WoodsGate" } }, gateZone, "Halo", vec(gate.X - 60, 3, gate.Z))
	check(g, "WoodsGate in its zone -> the anchor over the woods' edge", type(e) == "table" and e.Travel == false
		and isNamed(e.Part, "HUDGuideAnchor_Spot_WoodsGate") and at(e.Part, gate.X, gate.Z), where(e and e.Part))
	local camp = Config.StoryQuests.Landmarks.GoblinCamp1
	e = QT.ForEntry({ Story = { Id = "X", St = 1, Guide = "GoblinCamp1" } }, "Crossroads", "Halo", vec(0, 3, 0))
	check(g, "GoblinCamp1 from the Crossroads -> a trip to the goblin woods", type(e) == "table" and e.Travel == true
		and e.Zone == Config.ZoneAt(camp).Id and e.Zone == "GoblinWoods", e and encode({ Zone = e.Zone }) or "nil")
	e = QT.ForEntry({ Story = { Id = "X", St = 1, Guide = "HaloTown" } }, "HaloTown", "Halo", vec(0, 3, -470))
	check(g, "a plain zone guide inside its zone -> still nothing", e == nil, e and encode({ Tag = e.Tag }) or "nil")
end

local named = {}
for _, key in order do table.insert(named, Named[key]) end
print("QUEST_TARGET_RESULT_JSON " .. encode({ Checks = checks, Failed = failed, Named = named }))
if failed == 0 then
	print(("QUEST_TARGET_OFFLINE_OK checks=%d Studio/API calls=0"):format(checks))
end
