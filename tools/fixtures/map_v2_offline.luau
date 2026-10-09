-- Offline checks for the world map v2 numbers (SPEC A23-53, game dev 1). The runner (tools/test_map_v2.py) prepends
-- CONFIG_SOURCE (the real Config.luau), PREVIEW_SOURCE (the data block of tools/preview_map.lua, returning its tables),
-- LAYOUT (docs/design/world_map_v2_2026-10-06.json as a Lua table) and HOLLOW_UV (the U / V shares of MapBuilder's
-- HOLLOW.Props). Roblox is replaced by small doubles; every check is named (group :: check). No Studio, no network.

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
	if t ~= "table" then return '"' .. tostring(v) .. '"' end
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
local function show(v)
	local ok, s = pcall(encode, v)
	return ok and s or tostring(v)
end

----------------------------------------------------------------- engine doubles
local function rgb(r, g, b) return { R = r / 255, G = g / 255, B = b / 255, __kind = "Color3" } end
local function ctor(kind)
	return setmetatable({}, { __index = function(_, key) return function(...) return { __kind = kind, Ctor = key, Args = { ... } } end end })
end
local enum = setmetatable({}, { __index = function(_, kind)
	return setmetatable({}, { __index = function(_, id) return kind .. "." .. id end }) end })
local vmt = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __kind = "Vector3" }, vmt) end
vmt.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
vmt.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
vmt.__mul = function(a, b)
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
vmt.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
vmt.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	return nil
end
local function v2(x, y) return { X = x or 0, Y = y or 0, __kind = "Vector2" } end

local function envFor(now)
	return { Vector3 = { new = vec, zero = vec(0, 0, 0) }, Vector2 = { new = v2, zero = v2(0, 0) },
		Color3 = { new = function(r, g, b) return rgb(r * 255, g * 255, b * 255) end, fromRGB = rgb,
			fromHSV = function() return rgb(0, 0, 0) end },
		BrickColor = { new = function(v) return v end }, Rect = ctor("Rect"), UDim2 = ctor("UDim2"), UDim = ctor("UDim"),
		NumberRange = ctor("NumberRange"), NumberSequence = ctor("NumberSequence"), ColorSequence = ctor("ColorSequence"),
		Font = ctor("Font"), Enum = enum, typeof = function(v) return type(v) == "table" and rawget(v, "__kind") or type(v) end,
		workspace = { GetServerTimeNow = function() return now end }, print = function() end, warn = function() end }
end

local function execute(name, text, env)
	local fn, err = loadstring(text, "=" .. name)
	assert(fn, err)
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end

-- in season (2026-09-21) and after the Halloween EndsAt (2027)
local C = execute("Config", CONFIG_SOURCE, envFor(1790000000))
local Off = execute("Config", CONFIG_SOURCE, envFor(1800000000))
local P = execute("PreviewData", PREVIEW_SOURCE, envFor(1790000000))
local L = LAYOUT
local M = C.Map
local Z = C.Zones

----------------------------------------------------------------- helpers
local function near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1e-6) end
local function zrect(z)
	return { MinX = z.Center.X - z.Size.X / 2, MaxX = z.Center.X + z.Size.X / 2, MinZ = z.Center.Z - z.Size.Z / 2, MaxZ = z.Center.Z + z.Size.Z / 2 }
end
local function inRect(p, r, pad)
	pad = pad or 0
	return p.X >= r.MinX - pad and p.X <= r.MaxX + pad and p.Z >= r.MinZ - pad and p.Z <= r.MaxZ + pad
end
local function sameRect(a, b, tol)
	return near(a.MinX, b.MinX, tol) and near(a.MaxX, b.MaxX, tol) and near(a.MinZ, b.MinZ, tol) and near(a.MaxZ, b.MaxZ, tol)
end
local function overlapArea(a, b)
	local w = math.min(a.MaxX, b.MaxX) - math.max(a.MinX, b.MinX)
	local h = math.min(a.MaxZ, b.MaxZ) - math.max(a.MinZ, b.MinZ)
	return (w > 0 and h > 0) and w * h or 0
end
local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end
local function landNamed(name)
	for _, l in M.Lands do if l.Name == name then return l end end
	return nil
end
local function roadNamed(name)
	for _, r in M.Roads do if r.Name == name then return r end end
	return nil
end
local function onLand(p, withSeason)
	for _, l in M.Lands do
		if (withSeason or l.Season == nil) and inRect(p, l) then return l end
	end
	return nil
end
-- distance from a point to a rectangle (0 inside)
local function rectDist(p, r)
	local dx = math.max(r.MinX - p.X, 0, p.X - r.MaxX)
	local dz = math.max(r.MinZ - p.Z, 0, p.Z - r.MaxZ)
	return math.sqrt(dx * dx + dz * dz)
end
-- distance from a point inside a rectangle to its border
local function edgeDist(p, r)
	return math.min(math.abs(p.X - r.MinX), math.abs(p.X - r.MaxX), math.abs(p.Z - r.MinZ), math.abs(p.Z - r.MaxZ))
end
local LAND_OF = { Crossroads = "LandCrossroads", HaloTown = "IslandHalo", HornsTown = "IslandHorns", SlimeMeadow = "LandMeadow",
	PumpkinPatch = "LandPumpkinPatch", HauntedHollow = "LandHauntedHollow", GoblinWoods = "LandWoods", SkeletonRuins = "LandRuins" }
-- the kit landmarks the roads must stay clear of (kit_meadow / kit_woods / kit_ruins and the v2 layout)
local KIT_SPOTS = {
	{ "King Slime Hill", vec(430, 0, -170), 30 }, { "slime pond", vec(290, 0, 150), 25 },
	{ "giant pumpkin house", vec(585, 0, 370), 30 }, { "ghost willow", vec(300, 0, 360), 32 },
	{ "goblin treehouse trunk", vec(960, 0, -90), 9 }, { "broken tower", vec(1560, 0, -140), 25 },
	{ "crown altar ruin", vec(1700, 0, 0), 15 },
}

----------------------------------------------------------------- zones
do
	local g = "zones"
	local ids = {}
	for _, lz in L.zones do
		ids[lz.id] = true
		local z = Z[lz.id]
		check(g, "every v2 layout zone is a Config zone", type(z) == "table", lz.id)
		if type(z) == "table" then
			local r = zrect(z)
			check(g, "the zone rectangle = the v2 land rectangle", sameRect(r, { MinX = lz.land[1], MaxX = lz.land[2], MinZ = lz.land[3], MaxZ = lz.land[4] }),
				lz.id .. " " .. show(r))
			if lz.id == "Crossroads" then
				check(g, "the Crossroads spawn keeps its v1 place (0, -25): the Crossroads core is unchanged", near(z.Spawn.X, 0) and near(z.Spawn.Z, -25), show(z.Spawn))
			else
				check(g, "every other spawn = the v2 layout spawn", near(z.Spawn.X, lz.spawn[1]) and near(z.Spawn.Z, lz.spawn[2]), lz.id .. " " .. show(z.Spawn))
			end
			check(g, "PvP follows the layout", (z.PvP == true) == (lz.pvp == true), lz.id)
			local lvl = ({ ["1"] = 1, ["1+"] = 1, ["8-14"] = 1, ["10+"] = 10, ["25+"] = 25 })[lz.lv]
			check(g, "MinLevel follows the layout (8-14 is a recommendation, no gate)", z.MinLevel == lvl, lz.id .. " " .. tostring(z.MinLevel))
			check(g, "a seasonal layout zone is a seasonal Config zone", (lz.season or "") == (z.Season or ""), lz.id)
			check(g, "the spawn lies inside its zone, 15+ studs from the edge", inRect(z.Spawn, r, -15), lz.id .. " " .. show(z.Spawn))
			check(g, "ZoneAt(spawn) is that zone in season", C.ZoneAt(z.Spawn).Id == lz.id, lz.id .. " -> " .. tostring(C.ZoneAt(z.Spawn).Id))
			check(g, "every spawn stands on its own land piece", onLand(z.Spawn, true) ~= nil and onLand(z.Spawn, true).Name == LAND_OF[lz.id],
				lz.id .. " " .. show(onLand(z.Spawn, true)))
			if z.Season then
				check(g, "out of season a seasonal spawn reads as Outskirts", Off.ZoneAt(z.Spawn).Id == "Outskirts", lz.id)
			end
		end
	end
	for _, id in C.ZoneOrder do
		check(g, "every ZoneOrder id is a v2 layout zone", ids[id] == true, id)
	end
	local o = zrect(Z.Outskirts)
	check(g, "Outskirts = Config.Map.Bounds", sameRect(o, M.Bounds), show(o))
	check(g, "the Outskirts spawn = the Crossroads spawn", near(Z.Outskirts.Spawn.X, Z.Crossroads.Spawn.X) and near(Z.Outskirts.Spawn.Z, Z.Crossroads.Spawn.Z))
	-- PvP / safe borders
	local pvp = {}
	for _, id in C.ZoneOrder do if Z[id].PvP then table.insert(pvp, id) end end
	table.sort(pvp)
	check(g, "PvP zones are exactly the Goblin Woods and the Skeleton Ruins", table.concat(pvp, ",") == "GoblinWoods,SkeletonRuins", table.concat(pvp, ","))
	for _, a in C.ZoneOrder do
		for _, b in C.ZoneOrder do
			if a < b and (Z[a].PvP == true) ~= (Z[b].PvP == true) then
				check(g, "no PvP zone overlaps a safe zone", overlapArea(zrect(Z[a]), zrect(Z[b])) == 0, a .. " / " .. b)
			end
		end
	end
	local towns = {}
	for _, id in C.ZoneOrder do if Z[id].Town then table.insert(towns, id) end end
	table.sort(towns)
	check(g, "the towns are the Crossroads and the two faction towns", table.concat(towns, ",") == "Crossroads,HaloTown,HornsTown", table.concat(towns, ","))
	check(g, "towns have no PvP and no level gate", not Z.Crossroads.PvP and not Z.HaloTown.PvP and not Z.HornsTown.PvP
		and Z.HaloTown.MinLevel == 1 and Z.HornsTown.MinLevel == 1)
	check(g, "the faction towns belong to their factions", Z.HaloTown.Faction == "Halo" and Z.HornsTown.Faction == "Horns" and Z.Crossroads.Faction == nil)
end

----------------------------------------------------------------- lands, bounds, picture
do
	local g = "lands"
	for _, lz in L.zones do
		local l = landNamed(LAND_OF[lz.id])
		check(g, "every layout land is a Config.Map.Lands piece with the same rectangle", l ~= nil
			and sameRect(l, { MinX = lz.land[1], MaxX = lz.land[2], MinZ = lz.land[3], MaxZ = lz.land[4] }), lz.id .. " " .. show(l))
		if l then check(g, "seasonal lands carry the season, the others none", (l.Season or "") == (lz.season or ""), l.Name) end
	end
	local pass = landNamed("LandPass")
	local woods, ruins = landNamed("LandWoods"), landNamed("LandRuins")
	check(g, "LandPass is the mountain band between the woods and the ruins (layout pass x, the woods' z span)", pass ~= nil and woods ~= nil and ruins ~= nil
		and near(pass.MinX, L.pass.land[1]) and near(pass.MaxX, L.pass.land[2]) and near(pass.MinX, woods.MaxX) and near(pass.MaxX, ruins.MinX)
		and pass.MinZ <= L.pass.land[3] and pass.MaxZ >= L.pass.land[4] and near(pass.MinZ, woods.MinZ) and near(pass.MaxZ, woods.MaxZ), show(pass))
	check(g, "PassX is the band's middle, PassHalfZ the layout corridor half-width", pass ~= nil and near(M.PassX, (pass.MinX + pass.MaxX) / 2)
		and near(M.PassHalfZ, L.pass.land[4]), show({ M.PassX, M.PassHalfZ }))
	local n = #M.Lands
	check(g, "nine land pieces (5 continent pieces, 2 islands, 2 Halloween fields)", n == 9, n)
	for i = 1, n do
		for j = i + 1, n do
			local a, b = M.Lands[i], M.Lands[j]
			check(g, "land pieces never overlap (shared edges only)", overlapArea(a, b) == 0, a.Name .. " / " .. b.Name)
		end
	end
	local B = M.Bounds
	for _, l in M.Lands do
		check(g, "every land lies inside Bounds with 20+ studs of sea", l.MinX - B.MinX >= 20 and B.MaxX - l.MaxX >= 20 and l.MinZ - B.MinZ >= 20
			and B.MaxZ - l.MaxZ >= 20, l.Name)
	end
	-- the big map picture (image dev's UIP_WorldMapV2: px = X0 + (x + OffX) * K, py = (z + OffZ) * K)
	local art = C.UIArt and C.UIArt.Parts and C.UIArt.Parts.WorldMapV2
	local T = art and art.Map
	check(g, "Config.UIArt.Parts.WorldMapV2 carries its map transform", type(T) == "table" and type(T.K) == "number" and art.Size ~= nil, show(T))
	if type(T) == "table" and art.Size then
		local cover = { MinX = (0 - T.X0) / T.K - T.OffX, MaxX = (art.Size.X - T.X0) / T.K - T.OffX, MinZ = 0 / T.K - T.OffZ, MaxZ = art.Size.Y / T.K - T.OffZ }
		check(g, "the picture covers Bounds (the whole walkable world shows on the big map)", B.MinX >= cover.MinX - 1 and B.MaxX <= cover.MaxX + 1
			and B.MinZ >= cover.MinZ - 1 and B.MaxZ <= cover.MaxZ + 1, show(cover))
		for _, lz in L.zones do
			local px0, px1 = T.X0 + (lz.land[1] + T.OffX) * T.K, T.X0 + (lz.land[2] + T.OffX) * T.K
			local py0, py1 = (lz.land[3] + T.OffZ) * T.K, (lz.land[4] + T.OffZ) * T.K
			check(g, "every land maps inside the 1024 x 683 picture", px0 >= 0 and px1 <= art.Size.X and py0 >= 0 and py1 <= art.Size.Y + 0.5,
				lz.id .. string.format(" px %.0f..%.0f py %.0f..%.0f", px0, px1, py0, py1))
		end
	end
end

----------------------------------------------------------------- bridges, gates, roads
do
	local g = "links"
	check(g, "four bridges, as in the layout", #M.Bridges == 4 and #L.bridges == 4, #M.Bridges)
	for i, b in M.Bridges do
		local lb = L.bridges[i]
		check(g, "each bridge = the layout bridge (ends, width 22)", lb ~= nil and near(b.From.X, lb.from[1]) and near(b.From.Z, lb.from[2])
			and near(b.To.X, lb.to[1]) and near(b.To.Z, lb.to[2]) and b.Width == lb.width, b.Name)
		local function shoreOf(p)
			for _, l in M.Lands do
				if l.Season == nil and inRect(p, l, 1) and edgeDist(p, l) <= 1 then return l end
			end
			return nil
		end
		local a, c = shoreOf(b.From), shoreOf(b.To)
		check(g, "both bridge ends land on a shore of two different land pieces", a ~= nil and c ~= nil and a ~= c, b.Name .. " " .. show({ a and a.Name, c and c.Name }))
	end
	local gatesByZone = {}
	for _, gte in M.Gates do gatesByZone[gte.Zone] = gte end
	local layoutGate = { SlimeMeadow = L.gates[1], GoblinWoods = L.gates[2], SkeletonRuins = L.gates[3], HaloTown = L.gates[4], HornsTown = L.gates[5] }
	for zone, lg in layoutGate do
		local gte = gatesByZone[zone]
		check(g, "each zone gate = the layout gate", gte ~= nil and near(gte.Position.X, lg.at[1]) and near(gte.Position.Z, lg.at[2]), zone)
		if gte then
			check(g, "each gate stands on its zone's border", inRect(gte.Position, zrect(Z[zone]), 0.5) and edgeDist(gte.Position, zrect(Z[zone])) <= 0.5, zone)
		end
	end
	-- roads on land
	for _, r in M.Roads do
		local pts = { vec(r.MinX, 0, r.MinZ), vec(r.MaxX, 0, r.MinZ), vec(r.MinX, 0, r.MaxZ), vec(r.MaxX, 0, r.MaxZ),
			vec((r.MinX + r.MaxX) / 2, 0, (r.MinZ + r.MaxZ) / 2) }
		local ok = true
		for _, p in pts do
			if not onLand(p, r.Season ~= nil) then ok = false end
		end
		check(g, "every road lies on land (a season road may cross into its season's fields)", ok, r.Name)
		if r.Season == nil then
			for _, k in KIT_SPOTS do
				check(g, "no road runs through a kit landmark", rectDist(k[2], r) >= k[3], r.Name .. " / " .. k[1])
			end
		end
	end
	local cross, meadow, woods, pass, ruins = landNamed("LandCrossroads"), landNamed("LandMeadow"), landNamed("LandWoods"), landNamed("LandPass"), landNamed("LandRuins")
	local rc, rm, rw, rp, rr = roadNamed("RoadCross"), roadNamed("RoadMeadow"), roadNamed("RoadWoods"), roadNamed("RoadPass"), roadNamed("RoadRuins")
	check(g, "the crown road runs shore to shore from the Crossroads to the ruins", rc and rm and rw and rp and rr and near(rc.MaxX, cross.MaxX)
		and near(rm.MinX, meadow.MinX) and near(rm.MaxX, meadow.MaxX) and near(rw.MinX, woods.MinX) and near(rw.MaxX, woods.MaxX)
		and near(rp.MinX, pass.MinX) and near(rp.MaxX, pass.MaxX) and near(rr.MinX, ruins.MinX) and rr.MaxX < ruins.MaxX, "crown road")
	local rn, rs = roadNamed("RoadNorthIsland"), roadNamed("RoadSouthIsland")
	check(g, "the town roads start at the island shores (bridge ends) and end at the castles", rn and rs and near(rn.MaxZ, landNamed("IslandHalo").MaxZ)
		and near(rs.MinZ, landNamed("IslandHorns").MinZ) and near(rn.MinZ, -600) and near(rs.MaxZ, 600))
	-- the pads stay in the Crossroads, off every road
	for _, pad in M.Pads do
		local pr = { MinX = pad.Position.X - M.PadSize.X / 2, MaxX = pad.Position.X + M.PadSize.X / 2, MinZ = pad.Position.Z - M.PadSize.Z / 2,
			MaxZ = pad.Position.Z + M.PadSize.Z / 2 }
		check(g, "every travel pad stands in the Crossroads", C.ZoneAt(pad.Position).Id == "Crossroads", pad.Dest)
		for _, r in M.Roads do
			check(g, "no travel pad touches a road (CR-M22)", overlapArea(pr, r) == 0, pad.Dest .. " / " .. r.Name)
		end
	end
end

----------------------------------------------------------------- Halloween fields
do
	local g = "halloween"
	local HW = M.Halloween
	local patch, hollow, meadow = landNamed("LandPumpkinPatch"), landNamed("LandHauntedHollow"), landNamed("LandMeadow")
	local rp, rh = roadNamed("RoadPumpkin"), roadNamed("RoadHollow")
	check(g, "Config.Map.Halloween has the path, the gates and the sign", type(HW) == "table" and type(HW.PathX) == "number"
		and type(HW.PatchGateZ) == "number" and type(HW.HollowGate) == "table" and type(HW.SignPos) == "table", show(HW))
	if type(HW) == "table" and patch and hollow and meadow and rp and rh then
		check(g, "the pumpkin path runs down the middle of the season road, inside the patch's x range",
			near(HW.PathX, (rp.MinX + rp.MaxX) / 2) and HW.PathX > patch.MinX + 20 and HW.PathX < patch.MaxX - 20, HW.PathX)
		check(g, "the north gate is the patch's north edge (where it joins the meadow)", near(HW.PatchGateZ, patch.MinZ) and near(patch.MinZ, meadow.MaxZ))
		check(g, "the hollow gate is on the shared edge of the patch and the hollow", near(HW.HollowGate.X, patch.MinX) and near(patch.MinX, hollow.MaxX)
			and HW.HollowGate.Z > math.max(patch.MinZ, hollow.MinZ) + 10 and HW.HollowGate.Z < math.min(patch.MaxZ, hollow.MaxZ) - 10, show(HW.HollowGate))
		check(g, "the hollow road leaves through the hollow gate", near((rh.MinZ + rh.MaxZ) / 2, HW.HollowGate.Z) and rh.MinX < HW.HollowGate.X and rh.MaxX >= HW.HollowGate.X)
		local s = HW.SignPos
		check(g, "the sign stands on the meadow, west of the path, near the north gate, off the crown road", inRect(s, meadow) and s.X < HW.PathX - 7
			and patch.MinZ - s.Z <= 30 and patch.MinZ - s.Z > 0 and math.abs(s.Z) > 9, show(s))
		check(g, "the patch and the hollow keep their land-joined layout (the hollow is reached from the patch)", overlapArea(patch, hollow) == 0
			and near(hollow.MaxX, patch.MinX) and hollow.MinZ > meadow.MaxZ)
	end
	local H = C.Halloween
	local R = H.SpawnRadius
	local pz, hz = Z.PumpkinPatch, Z.HauntedHollow
	local pr, hr = zrect(pz), zrect(hz)
	for _, s in H.SpawnSpots do
		check(g, "every pumpkin king spot (+ SpawnRadius) lies in the patch", inRect(s, pr, -R), show(s))
		check(g, "pumpkin king spots are in the far half (away from the meadow entrance)", s.Z - R > pz.Center.Z, show(s))
		check(g, "pumpkin king spots stay off the giant pumpkin house", flat(s, vec(585, 0, 370)) >= 30 + R, show(s))
		check(g, "pumpkin king spots stay 40+ studs from the patch spawn and clear of the west gate", flat(s, pz.Spawn) >= 40
			and (not HW or flat(s, HW.HollowGate) >= R + 20), show(s))
	end
	local ghost = H.Bosses and H.Bosses[2]
	check(g, "the ghost king has its own spots", ghost and type(ghost.SpawnSpots) == "table" and #ghost.SpawnSpots >= 1)
	for _, s in (ghost and ghost.SpawnSpots or {}) do
		check(g, "every ghost king spot (+ SpawnRadius) lies in the hollow", inRect(s, hr, -R), show(s))
		check(g, "ghost king spots are in the far (west) half, away from the gate", s.X + R <= hz.Center.X, show(s))
		check(g, "ghost king spots stay off the ghost willow", flat(s, vec(300, 0, 360)) >= 32 + R, show(s))
	end
	for i, uv in HOLLOW_UV do
		check(g, "every HauntedHollow prop share (U, V) lies inside the land", uv[1] >= 0 and uv[1] <= 1 and uv[2] >= 0 and uv[2] <= 1, i)
	end
end

----------------------------------------------------------------- story places, goose, NPC spots
do
	local g = "places"
	local S = C.StoryQuests.Landmarks
	local function zoneOf(p) return C.ZoneAt(p).Id end
	check(g, "the fountain is the Crossroads centre", near(S.Fountain.X, 0) and near(S.Fountain.Z, 0) and zoneOf(S.Fountain) == "Crossroads")
	check(g, "the slime pond lies in the meadow", zoneOf(S.SlimePond) == "SlimeMeadow", show(S.SlimePond))
	for _, r in M.Roads do
		check(g, "the slime pond (25 wide) is off every road", rectDist(S.SlimePond, r) >= 25, r.Name)
	end
	local function bridgeNamed(n) for _, b in M.Bridges do if b.Name == n then return b end end end
	local wg = S.WoodsGate
	check(g, "WoodsGate: outside the PvP woods and every level gate, on the meadow", zoneOf(wg) == "SlimeMeadow" and not C.ZoneAt(wg).PvP and C.ZoneAt(wg).MinLevel <= 1, show(wg))
	check(g, "WoodsGate stays within 20 studs of the woods bridge's meadow end", flat(wg, bridgeNamed("Goblin").From) <= 20, show(wg))
	check(g, "the Halo / Horns bridge spots are on the Crossroads within 20 studs of their bridge ends", zoneOf(S.HaloBridge) == "Crossroads"
		and zoneOf(S.HornsBridge) == "Crossroads" and flat(S.HaloBridge, bridgeNamed("Halo").From) <= 20 and flat(S.HornsBridge, bridgeNamed("Horns").From) <= 20,
		show({ S.HaloBridge, S.HornsBridge }))
	check(g, "the kids' bench is in the Crossroads", zoneOf(S.KidsBench) == "Crossroads")
	local camps = { S.GoblinCamp1, S.GoblinCamp2, S.GoblinCamp3 }
	for i, cp in camps do
		check(g, "every goblin camp is in the Goblin Woods, away from the arrival", zoneOf(cp) == "GoblinWoods" and flat(cp, Z.GoblinWoods.Spawn) >= 80, i)
		for j = i + 1, 3 do
			check(g, "the goblin camps are 60+ studs apart", flat(cp, camps[j]) >= 60, i .. "/" .. j)
		end
	end
	check(g, "the boss clearing (1110, 120) stays 40+ studs from camp 2 (kit_woods)", flat(S.GoblinCamp2, vec(1110, 0, 120)) >= 40)
	check(g, "the arrivals follow the zone spawns", S.MeadowArrival == Z.SlimeMeadow.Spawn and S.WoodsArrival == Z.GoblinWoods.Spawn)
	local mb = S.MeadowBoard
	check(g, "the meadow board stands beside the arrival, off the crown road", math.abs(mb.X - S.MeadowArrival.X) + math.abs(mb.Z - S.MeadowArrival.Z) <= 12
		and math.abs(mb.Z) > 9 and zoneOf(mb) == "SlimeMeadow", show(mb))
	check(g, "the woods board is at WoodsGate", S.WoodsBoard == S.WoodsGate)
	check(g, "the hero statue road is in Halo Citadel, the lava crack in Horns Den", zoneOf(S.HeroStatue) == "HaloTown" and zoneOf(S.LavaCrack) == "HornsTown",
		show({ S.HeroStatue, S.LavaCrack }))
	local gp = C.Goose.Position
	check(g, "the golden goose perch is in the Crossroads (safe town)", zoneOf(gp) == "Crossroads" and C.ZoneAt(gp).Town == true, show(gp))
	-- the potion seller next to the Crossroads spawn (MapBuilder: Crossroads.Spawn + PotionMerchantOffset)
	local off = C.Vitals.PotionMerchantOffset
	local seller = vec(Z.Crossroads.Spawn.X + off.X, 0, Z.Crossroads.Spawn.Z + off.Z)
	check(g, "the potion seller stands in the Crossroads, beside the spawn", zoneOf(seller) == "Crossroads" and flat(seller, Z.Crossroads.Spawn) >= 6
		and flat(seller, Z.Crossroads.Spawn) <= 25, show(seller))
	for _, r in M.Roads do
		check(g, "the potion seller is off every road", rectDist(seller, r) >= 2, r.Name)
	end
end

----------------------------------------------------------------- tools/preview_map.lua = Config
do
	local g = "preview"
	for _, id in C.ZoneOrder do
		local a, b = P.ZONES[id], Z[id]
		check(g, "preview ZONES = Config.Zones (centre, size, spawn, level, PvP, season)", a ~= nil and near(a.Center.X, b.Center.X) and near(a.Center.Z, b.Center.Z)
			and near(a.Size.X, b.Size.X) and near(a.Size.Z, b.Size.Z) and near(a.Spawn.X, b.Spawn.X) and near(a.Spawn.Z, b.Spawn.Z)
			and a.MinLevel == b.MinLevel and (a.PvP == true) == (b.PvP == true) and (a.Season or "") == (b.Season or ""), id)
	end
	check(g, "preview ZONE_ORDER = Config.ZoneOrder", table.concat(P.ZONE_ORDER, ",") == table.concat(C.ZoneOrder, ","))
	check(g, "preview BOUNDS / WALL_HEIGHT / WATER_TOP = Config.Map", sameRect(P.BOUNDS, M.Bounds) and P.WALL_HEIGHT == M.WallHeight and P.WATER_TOP == M.WaterTop)
	check(g, "preview LANDS = Config.Map.Lands (names, rectangles, seasons)", #P.LANDS == #M.Lands)
	for _, l in M.Lands do
		local found = nil
		for _, q in P.LANDS do if q.Name == l.Name then found = q end end
		check(g, "every Config land is a preview land with the same rectangle and season", found ~= nil and sameRect(found, l) and (found.Season or "") == (l.Season or ""), l.Name)
	end
	for i, b in M.Bridges do
		local q = P.BRIDGES[i]
		check(g, "preview BRIDGES = Config.Map.Bridges", q ~= nil and q.Name == b.Name and near(q.From.X, b.From.X) and near(q.From.Z, b.From.Z)
			and near(q.To.X, b.To.X) and near(q.To.Z, b.To.Z) and q.Width == b.Width, b.Name)
	end
	check(g, "preview ROADS = Config.Map.Roads (same count)", #P.ROADS == #M.Roads, #P.ROADS)
	for _, r in M.Roads do
		local found = nil
		for _, q in P.ROADS do if q.Name == r.Name then found = q end end
		check(g, "every Config road is a preview road with the same strip and season", found ~= nil and sameRect(found, r) and (found.Season or "") == (r.Season or ""), r.Name)
	end
	for _, gte in M.Gates do
		local found = nil
		for _, q in P.GATES do if q.Zone == gte.Zone then found = q end end
		check(g, "preview GATES = Config.Map.Gates", found ~= nil and near(found.Position.X, gte.Position.X) and near(found.Position.Z, gte.Position.Z), gte.Zone)
	end
	check(g, "preview PASS = Config.Map.PassX / PassHalfZ / LandPass", near(P.PASS.X, M.PassX) and near(P.PASS.HalfZ, M.PassHalfZ)
		and sameRect(P.PASS, landNamed("LandPass")))
	for i, pad in M.Pads do
		local q = P.PADS[i]
		check(g, "preview PADS = Config.Map.Pads", q ~= nil and q.Dest == pad.Dest and near(q.Position.X, pad.Position.X) and near(q.Position.Z, pad.Position.Z), pad.Dest)
	end
	check(g, "preview HW = Config.Map.Halloween", near(P.HW.PathX, M.Halloween.PathX) and near(P.HW.PatchGateZ, M.Halloween.PatchGateZ)
		and near(P.HW.HollowGate.X, M.Halloween.HollowGate.X) and near(P.HW.HollowGate.Z, M.Halloween.HollowGate.Z))
	check(g, "preview ALTAR / BOARD / GOOSE_NEST = Config", near(P.ALTAR.Z, M.AltarPosition.Z) and near(P.BOARD.X, M.BoardPosition.X)
		and near(P.GOOSE_NEST.X, C.Goose.Position.X) and near(P.GOOSE_NEST.Z, C.Goose.Position.Z))
end

-- 검수 10/09: the town road parts stop at the Crossroads plaza edge and get a light earthy color (Config.Map.RoadLook,
-- MapBuilder.FitRoads run on stub parts; Config.Map.Roads stays the map data)
do
	local g = "roads"
	local look = C.Map.RoadLook
	check(g, "Config.Map.RoadLook: a plaza radius and the four town road parts", type(look) == "table" and near(look.PlazaRadius, 60)
		and look.Parts.RoadSouth and look.Parts.RoadSouthIsland and look.Parts.RoadNorth and look.Parts.RoadNorthIsland)
	local function dark(c) return c.R * 255 < 120 and c.G * 255 < 100 end
	for name, want in look.Parts do
		check(g, "a look part is a Config road", (function() for _, r in C.Map.Roads do if r.Name == name then return true end end return false end)(), name)
		check(g, "the look colors are light (not the old near-black 70,45,45)", not dark(want.Color) and want.Color.R * 255 >= 140, name)
		local q = nil
		for _, r in P.ROADS do if r.Name == name then q = r end end
		check(g, "preview_map builds the part with the look's color and material", q ~= nil and near(q.Color.R, want.Color.R)
			and near(q.Color.G, want.Color.G) and near(q.Color.B, want.Color.B) and q.Material == want.Material, name)
	end
	check(g, "Config.Map.Roads keeps the full strips (the minimap / world map data)", (function()
		for _, r in C.Map.Roads do
			if r.Name == "RoadSouth" then return near(r.MinZ, 10) and near(r.MaxZ, 150) end
		end
		return false
	end)())
	-- FitRoads on stub parts
	local function part(name, cx, cz, sx, sz)
		return { Name = name, Position = vec(cx, 0.08, cz), Size = vec(sx, 0.2, sz), Color = rgb(70, 45, 45), Material = "Enum.Material.Slate",
			Transparency = 0, IsA = function(_, k) return k == "BasePart" end }
	end
	local parts = {
		RoadSouth = part("RoadSouth", 0, 80, 16, 140), RoadNorth = part("RoadNorth", 0, -80, 16, 140),
		RoadSouthIsland = part("RoadSouthIsland", 0, 465, 16, 270), RoadNorthIsland = part("RoadNorthIsland", 0, -465, 16, 270),
		RoadWest = part("RoadWest", -28, 0, 30, 18),
	}
	local roads = { FindFirstChild = function(_, n) return parts[n] end }
	local decor = { FindFirstChild = function(_, n) return if n == "Roads" then roads else nil end }
	local env = envFor(1790000000)
	env.Config = C
	env.CFrame = { new = function(x, y, z) return { X = x, Y = y, Z = z, __kind = "CFrame" } end }
	local MB = {}
	env.MapBuilder = MB
	execute("FitRoads", FITROADS_SOURCE, env)
	local function apply()
		for _, p in parts do
			if p.CFrame then p.Position = vec(p.CFrame.X, p.CFrame.Y, p.CFrame.Z); p.CFrame = nil end
		end
	end
	local n = MB.FitRoads(decor)
	apply()
	check(g, "FitRoads touches the four look parts", n == 4, n)
	local s, nn = parts.RoadSouth, parts.RoadNorth
	check(g, "RoadSouth now runs from the plaza edge (z 60) to the bridge (z 150)", near(s.Position.Z - s.Size.Z / 2, 60)
		and near(s.Position.Z + s.Size.Z / 2, 150) and near(s.Position.X, 0) and near(s.Size.X, 16) and s.Transparency == 0,
		s.Position.Z .. " " .. s.Size.Z)
	check(g, "RoadNorth now runs from the bridge (z -150) to the plaza edge (z -60)", near(nn.Position.Z - nn.Size.Z / 2, -150)
		and near(nn.Position.Z + nn.Size.Z / 2, -60) and nn.Transparency == 0, nn.Position.Z .. " " .. nn.Size.Z)
	check(g, "the island roads keep their strips", near(parts.RoadSouthIsland.Size.Z, 270) and near(parts.RoadSouthIsland.Position.Z, 465)
		and near(parts.RoadNorthIsland.Size.Z, 270))
	check(g, "the parts get the look's colors", near(s.Color.R, look.Parts.RoadSouth.Color.R) and near(nn.Color.G, look.Parts.RoadNorth.Color.G)
		and s.Material == look.Parts.RoadSouth.Material)
	check(g, "a road not in the look is left alone", near(parts.RoadWest.Size.Z, 18) and near(parts.RoadWest.Color.R * 255, 70))
	MB.FitRoads(decor)
	apply()
	check(g, "running it again changes nothing (idempotent)", near(s.Position.Z - s.Size.Z / 2, 60) and near(s.Size.Z, 90)
		and near(nn.Size.Z, 90))
	local inside = part("RoadSouth", 0, 30, 16, 40)
	parts.RoadSouth = inside
	MB.FitRoads(decor)
	check(g, "a part fully inside the plaza is hidden", inside.Transparency == 1 and near(inside.Size.Z, 40))
	check(g, "no Decor.Roads: nothing to do", MB.FitRoads({ FindFirstChild = function() return nil end }) == 0)
end

local named = {}
for _, key in order do table.insert(named, Named[key]) end
print("MAPV2_VALUES_JSON " .. encode({ SlimePond = { C.StoryQuests.Landmarks.SlimePond.X, C.StoryQuests.Landmarks.SlimePond.Y, C.StoryQuests.Landmarks.SlimePond.Z },
	HaloTown = zrect(Z.HaloTown), HornsTown = zrect(Z.HornsTown), HaloSpawnZ = Z.HaloTown.Spawn.Z, HornsSpawnZ = Z.HornsTown.Spawn.Z }))
print("MAPV2_RESULT_JSON " .. encode({ Checks = checks, Failed = failed, Named = named }))
if failed == 0 then print("MAPV2_OFFLINE_OK checks=" .. checks) end
