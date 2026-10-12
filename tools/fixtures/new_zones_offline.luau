-- new_zones_offline.luau : the two new fields (Coral Coast, Crystal Cave Woods; SPEC A23-119 / A23-123) and their seven
-- monster kinds, offline. tools/test_new_zones.py puts CONFIG_SOURCE, UTIL_SOURCE, BASE_CONFIG_SOURCE (Config.luau as it was
-- at commit 048127fa9e, read with `git show`: before the new zones) + dev2_kit.luau in front of this file. The CURRENT Config
-- runs for real (SeasonOn / MonsterActive / EffectiveMonsterCounts / MonsterTargets / ZoneAt / MonsterLevel / QuestKind /
-- NewZonesApply); only the engine is a double.

local NEW = { "CoralCrab", "Jellyfish", "HermitCrab", "CrystalLizard", "CaveBat", "GlowMushroom", "CrystalGolem" }
local NEW_SET = {}
for _, k in NEW do NEW_SET[k] = true end
local ZONE_IDS = { "CoralCoast", "CrystalWoods" }
local ZONE_SET = { CoralCoast = true, CrystalWoods = true }
local KIND_ZONE = { CoralCrab = "CoralCoast", Jellyfish = "CoralCoast", HermitCrab = "CoralCoast",
	CrystalLizard = "CrystalWoods", CaveBat = "CrystalWoods", GlowMushroom = "CrystalWoods", CrystalGolem = "CrystalWoods" }
local MATERIAL_OF = { CoralCoast = "SeaShell", CrystalWoods = "CrystalShard" }
local MOMENTS = { "Spot", "Hit", "Low", "Idle" }
local STAT_FIELDS = { "HP", "Damage", "XP", "Gold" }

-- two ladders of existing year-round kinds by level: the plain kind of each field and its big kind. A new kind with
-- Scale < 1.2 is plain, otherwise big (Hermit Crab 1.3, Glowing Mushroom 1.2, Crystal Golem 1.9)
local LADDER = { Plain = { "Slime", "Goblin", "Skeleton" }, Big = { "BigSlime", "GoblinBrute", "SkeletonKnight" } }
local LOOT_NEIGHBOUR = { Plain = "Goblin", Big = "GoblinBrute" }
local function classOf(def) return (tonumber(def.Scale) or 1) >= 1.2 and "Big" or "Plain" end

local base = execute("BaseConfig", BASE_CONFIG_SOURCE, nativeEnv())

local function pt(x, z) return vec(x, 0, z) end
local function samples(z)
	local cx, cz, hx, hz = z.Center.X, z.Center.Z, z.Size.X / 2, z.Size.Z / 2
	local out = { pt(cx, cz) }
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			table.insert(out, pt(cx + sx * (hx - 1), cz + sz * (hz - 1))) -- near the corners, inside
			table.insert(out, pt(cx + sx * (hx + 1), cz + sz * (hz + 1))) -- just outside the corners
		end
		table.insert(out, pt(cx + sx * (hx - 1), cz)) -- edge middles, inside / outside
		table.insert(out, pt(cx + sx * (hx + 1), cz))
		table.insert(out, pt(cx, cz + sx * (hz - 1)))
		table.insert(out, pt(cx, cz + sx * (hz + 1)))
	end
	return out
end
local function overlaps(a, b)
	return math.abs(a.Center.X - b.Center.X) < (a.Size.X + b.Size.X) / 2 and math.abs(a.Center.Z - b.Center.Z) < (a.Size.Z + b.Size.Z) / 2
end
local function same(a, b) return show(a) == show(b) end
local function count(list, v)
	local n = 0
	for _, x in list do if x == v then n += 1 end end
	return n
end
local function textOk(s)
	if type(s) ~= "string" or s == "" then return false end
	local ok, good = pcall(function()
		for _, cp in utf8.codes(s) do
			if not ((cp >= 32 and cp <= 126) or cp == 0x2026) then return false end
		end
		return true
	end)
	return ok and good
end
local function rowMap(list)
	local out = {}
	for _, r in list do
		local key = r.Item and ("I:" .. r.Item) or r.Potion and ("P:" .. r.Potion) or r.Weapon and ("W:" .. tostring(r.Weapon)) or "?"
		out[key] = (out[key] or 0) + (tonumber(r.P) or 0)
	end
	return out
end
local function around(C, class, lv)
	local lo, hi = nil, nil
	for _, k in LADDER[class] do
		local l = C.MonsterLevel(k)
		if l <= lv then lo = k end
		if l >= lv and hi == nil then hi = k end
	end
	return lo, hi
end

local function onWorld(extra)
	return newWorld({ EditConfig = function(c)
		c.NewZones.Enabled = true
		c.NewZonesApply()
		if extra then extra(c) end
	end })
end

------------------------------------------------------------------ 1. the switch
runGroup("switch", function()
	local C = newWorld().Config
	check(type(C.NewZones) == "table" and C.NewZones.Enabled == false, "Config.NewZones.Enabled is false as shipped", tostring(C.NewZones and C.NewZones.Enabled))
	check(C.NewZones.ZoneIds[1] == "CoralCoast" and C.NewZones.ZoneIds[2] == "CrystalWoods" and #C.NewZones.ZoneIds == 2,
		"ZoneIds = CoralCoast, CrystalWoods (in this order)", show(C.NewZones.ZoneIds))
	for _, id in ZONE_IDS do
		local z = C.Zones[id]
		check(type(z) == "table" and z.Id == id and z.Season == "NewZones", id .. " is in Config.Zones with Season NewZones", show(z and z.Season))
		check(type(z) == "table" and z.PvP == false and z.Town == false and z.Faction == nil and z.PvPArea == nil and z.MinLevel == 1,
			id .. " is a plain level-1 field: no PvP, no town, no faction, no level gate")
		check(type(z) == "table" and math.abs(z.Spawn.X - z.Center.X) <= z.Size.X / 2 and math.abs(z.Spawn.Z - z.Center.Z) <= z.Size.Z / 2,
			id .. " Spawn is inside its rect")
	end
	check(C.SeasonOn("NewZones") == false, "SeasonOn(NewZones) is false")
	check(C.SeasonOn("NewZones", true) == true, "the test override still turns it on")
	check(type(C.NewZonesApply) == "function", "Config.NewZonesApply exists")
	check(C.SeasonOn("Halloween") == base.SeasonOn("Halloween"), "the Halloween switch is untouched")
end)

------------------------------------------------------------------ 2. inert while off
runGroup("off", function()
	local C = newWorld().Config
	for _, k in NEW do
		local d = C.MonsterTypes[k]
		check(type(d) == "table" and d.Season == "NewZones", k .. " has Season NewZones", show(d and d.Season))
		check(C.MonsterActive(k) == false, k .. " is not active", tostring(C.MonsterActive(k)))
	end
	local counts = C.EffectiveMonsterCounts()
	local targets = C.MonsterTargets({ CoralCoast = 6, CrystalWoods = 6 })
	local alone = C.MonsterTargets({})
	for _, k in NEW do
		check(counts[k] == 0, k .. " effective spawn count is 0", tostring(counts[k]))
		check(targets[k] == 0 and alone[k] == 0, k .. " spawn target is 0 (also with 6 players in its field)", tostring(targets[k]) .. "/" .. tostring(alone[k]))
	end
	for _, id in ZONE_IDS do
		check(count(C.ZoneOrder, id) == 0, id .. " is not in ZoneOrder", show(C.ZoneOrder))
	end
	check(same(C.ZoneOrder, base.ZoneOrder), "ZoneOrder is the base commit's", show(C.ZoneOrder))
	check(C.NewZonesApply() == false and same(C.ZoneOrder, base.ZoneOrder), "NewZonesApply while off does nothing and says false")

	-- ZoneAt of a grid over every EXISTING zone rect is the base commit's answer
	local bad, total = {}, 0
	for id, bz in base.Zones do
		for _, p in samples(bz) do
			total += 1
			local a, b = C.ZoneAt(p).Id, base.ZoneAt(p).Id
			if a ~= b then table.insert(bad, id .. "@" .. p.X .. "," .. p.Z .. " " .. a .. " vs " .. b) end
		end
	end
	check(total > 100 and #bad == 0, "ZoneAt over every existing zone rect (centre, corners, edges, 1 stud outside) = base commit 048127fa9e", tostring(bad[1]) .. " (" .. #bad .. " of " .. total .. ")")
	for _, id in ZONE_IDS do
		local z = C.Zones[id]
		local inNew = 0
		for _, p in samples(z) do
			local got = C.ZoneAt(p).Id
			if got ~= base.ZoneAt(p).Id or got ~= "Outskirts" then inNew += 1 end
		end
		check(inNew == 0, id .. " rect reads as Outskirts while off, as on the base commit", tostring(inNew))
	end

	-- the placeholder rects are east of the map and overlap no zone rect
	for _, id in ZONE_IDS do
		local z = C.Zones[id]
		local hit = {}
		for oid, o in C.Zones do
			if oid ~= id and overlaps(z, o) then table.insert(hit, oid) end
		end
		table.sort(hit)
		check(#hit == 0, id .. " rect overlaps no other zone rect (Outskirts included)", table.concat(hit, ","))
		check(z.Center.X - z.Size.X / 2 > C.Map.Bounds.MaxX, id .. " lies east of Config.Map.Bounds", tostring(z.Center.X - z.Size.X / 2))
	end

	-- nothing that existed changed
	local zoneDiff, kindDiff, lootDiff, itemDiff, barkDiff, lvDiff, famDiff, orderDiff = {}, {}, {}, {}, {}, {}, {}, {}
	for id, bz in base.Zones do if not same(bz, C.Zones[id]) then table.insert(zoneDiff, id) end end
	for k, bd in base.MonsterTypes do if not same(bd, C.MonsterTypes[k]) then table.insert(kindDiff, k) end end
	for k, t in base.Loot.Tables do if not same(t, C.Loot.Tables[k]) then table.insert(lootDiff, k) end end
	for k, t in base.Loot.Items do if not same(t, C.Loot.Items[k]) then table.insert(itemDiff, k) end end
	for k, t in base.Barks.Lines do if not same(t, C.Barks.Lines[k]) then table.insert(barkDiff, k) end end
	for k, v in base.MonsterLevels do if C.MonsterLevels[k] ~= v then table.insert(lvDiff, k) end end
	for k, v in base.Barks.BubbleFamily do if C.Barks.BubbleFamily[k] ~= v then table.insert(famDiff, k) end end
	check(#zoneDiff == 0, "every existing zone is unchanged", table.concat(zoneDiff, ","))
	check(#kindDiff == 0, "every existing monster kind is unchanged (numbers, zone, season)", table.concat(kindDiff, ","))
	check(#lootDiff == 0 and #itemDiff == 0, "every existing loot table and item is unchanged", table.concat(lootDiff, ",") .. "/" .. table.concat(itemDiff, ","))
	check(#barkDiff == 0 and #lvDiff == 0 and #famDiff == 0, "every existing bark, level and bubble family is unchanged", table.concat(barkDiff, ",") .. table.concat(lvDiff, ",") .. table.concat(famDiff, ","))
	local curKinds, newKinds = 0, {}
	for k in C.MonsterTypes do
		curKinds += 1
		if base.MonsterTypes[k] == nil then table.insert(newKinds, k) end
	end
	table.sort(newKinds)
	local want = table.clone(NEW)
	table.sort(want)
	check(table.concat(newKinds, ",") == table.concat(want, ","), "the only added monster kinds are the seven", table.concat(newKinds, ","))
	local oldOrder = {}
	for _, k in C.MonsterTypeOrder do if not NEW_SET[k] then table.insert(oldOrder, k) end end
	check(same(oldOrder, base.MonsterTypeOrder), "MonsterTypeOrder without the new kinds is the base order", show(oldOrder))
	local bc, bt = base.EffectiveMonsterCounts(), base.MonsterTargets({ SlimeMeadow = 3 })
	local ct = C.MonsterTargets({ SlimeMeadow = 3 })
	local drift = {}
	for k, n in bc do if counts[k] ~= n or ct[k] ~= bt[k] then table.insert(drift, k) end end
	check(#drift == 0, "every existing kind's spawn count and target are the base commit's", table.concat(drift, ","))
	check(same(C.ZoneMainMonster, base.ZoneMainMonster), "ZoneMainMonster is unchanged")
end)

------------------------------------------------------------------ 3. on
runGroup("on", function()
	local C = onWorld().Config
	check(C.SeasonOn("NewZones") == true, "Enabled = true turns the season on")
	check(count(C.ZoneOrder, "CoralCoast") == 1 and count(C.ZoneOrder, "CrystalWoods") == 1, "each new zone is in ZoneOrder once", show(C.ZoneOrder))
	local want = table.clone(base.ZoneOrder)
	table.insert(want, "CoralCoast")
	table.insert(want, "CrystalWoods")
	check(same(C.ZoneOrder, want), "they are appended after the base order, in ZoneIds order", show(C.ZoneOrder))

	local twice = {}
	local w2 = newWorld({ EditConfig = function(c)
		c.NewZones.Enabled = true
		twice.First = c.NewZonesApply()
		twice.After1 = table.clone(c.ZoneOrder)
		twice.Second = c.NewZonesApply()
		twice.After2 = table.clone(c.ZoneOrder)
	end })
	check(twice.First == true and twice.Second == true, "NewZonesApply says true while on")
	check(same(twice.After1, twice.After2) and #twice.After2 == #base.ZoneOrder + 2, "calling it twice adds nothing", show(twice.After2))

	for _, id in ZONE_IDS do
		local z = C.Zones[id]
		check(C.ZoneAt(pt(z.Center.X, z.Center.Z)).Id == id, "ZoneAt of the centre of " .. id .. " is " .. id, C.ZoneAt(pt(z.Center.X, z.Center.Z)).Id)
		local bad = 0
		for _, p in samples(z) do
			local inside = math.abs(p.X - z.Center.X) <= z.Size.X / 2 and math.abs(p.Z - z.Center.Z) <= z.Size.Z / 2
			if (C.ZoneAt(p).Id == id) ~= inside then bad += 1 end
		end
		check(bad == 0, id .. " owns exactly the points inside its rect", tostring(bad))
	end

	local counts, alone = C.EffectiveMonsterCounts(), C.MonsterTargets({})
	local crowd = C.MonsterTargets({ CoralCoast = 4, CrystalWoods = 4 })
	local mult = (C.MonsterDensity and C.MonsterDensity.MaxZoneMult) or 2
	for _, k in NEW do
		local d = C.MonsterTypes[k]
		check(C.MonsterActive(k) == true, k .. " is active", tostring(C.MonsterActive(k)))
		check(counts[k] == d.Count and d.Count > 0, k .. " effective count = its Count", tostring(counts[k]))
		check(alone[k] == d.Count, k .. " target without players = its Count", tostring(alone[k]))
		check(crowd[k] >= d.Count and crowd[k] <= d.Count * mult, k .. " target with 4 players stays within Count .. Count x MaxZoneMult", tostring(crowd[k]))
		check(C.MonsterOutsideCap(k) == true and d.Takes == nil, k .. " is an add-on kind (no Takes): outside the global cap, no base slot taken")
	end

	-- no point outside the two rects changes zone; no existing kind's count changes
	local off = newWorld().Config
	local bad, total = {}, 0
	for id, bz in base.Zones do
		for _, p in samples(bz) do
			total += 1
			local a, b = C.ZoneAt(p).Id, base.ZoneAt(p).Id
			if a ~= b then table.insert(bad, id .. "@" .. p.X .. "," .. p.Z .. " " .. a .. " vs " .. b) end
		end
	end
	check(total > 100 and #bad == 0, "with the switch on, ZoneAt over every existing zone rect is still the base commit's", tostring(bad[1]) .. " (" .. #bad .. " of " .. total .. ")")
	local offCounts, offTargets, onTargets = off.EffectiveMonsterCounts(), off.MonsterTargets({ SlimeMeadow = 3, GoblinWoods = 5 }), C.MonsterTargets({ SlimeMeadow = 3, GoblinWoods = 5 })
	local drift = {}
	for k, n in offCounts do
		if not NEW_SET[k] and (counts[k] ~= n or onTargets[k] ~= offTargets[k]) then table.insert(drift, k) end
	end
	check(#drift == 0, "with the switch on, every existing kind keeps its count and target", table.concat(drift, ","))
end)

------------------------------------------------------------------ 4. monsters
runGroup("monsters", function()
	local C = newWorld().Config
	local M = C.MonsterTypes
	local counts = {}
	for k, def in M do
		if NEW_SET[k] then counts[def.Zone] = (counts[def.Zone] or 0) + 1 end
	end
	check(counts.CoralCoast == 3 and counts.CrystalWoods == 4, "3 kinds in Coral Coast, 4 in Crystal Cave Woods", show(counts))
	for _, k in NEW do
		local d = M[k]
		check(d.Zone == KIND_ZONE[k] and ZONE_SET[d.Zone], k .. " lives in " .. KIND_ZONE[k], tostring(d.Zone))
		check(d.Shape ~= "Slime", k .. " is not a slime shape (A23-123)", tostring(d.Shape))
		local from = d.ModelFrom and M[d.ModelFrom]
		check(type(from) == "table" and from.Shape ~= "Slime" and not NEW_SET[d.ModelFrom] and (d.AnimFrom == nil or (M[d.AnimFrom] ~= nil and M[d.AnimFrom].Shape ~= "Slime")),
			k .. " ModelFrom / AnimFrom is an existing non-slime kind", tostring(d.ModelFrom) .. "/" .. tostring(d.AnimFrom))
		check(not string.find(string.lower(k .. " " .. tostring(d.Name)), "slime", 1, true), k .. " has no slime in its name")
		check(d.Boss == nil or d.Boss == false, k .. " is not a boss")
		check(d.Ranged == nil and d.Ambush == nil and d.Pack == nil and d.PartnerOf == nil, k .. " has no Ranged / Ambush / Pack / PartnerOf")
		for _, f in STAT_FIELDS do
			check(type(d[f]) == "number" and d[f] > 0, k .. " " .. f .. " is a positive number", tostring(d[f]))
		end
		check(type(d.Count) == "number" and d.Count >= 1 and d.Count == math.floor(d.Count), k .. " Count is a whole number of 1 or more", tostring(d.Count))
		check(type(d.Speed) == "number" and d.Speed > 0 and type(d.Scale) == "number" and d.Scale > 0, k .. " Speed and Scale are positive")
		check(type(C.MonsterLevels[k]) == "number" and C.MonsterLevel(k) == C.MonsterLevels[k], k .. " has its own level", tostring(C.MonsterLevels[k]))
		if k == "Jellyfish" or k == "CaveBat" then
			check(type(d.Float) == "number" and d.Float > 0, k .. " floats (Float set)", tostring(d.Float))
		else
			check(d.Float == nil, k .. " walks (no Float)", tostring(d.Float))
		end
	end
	local g = M.CrystalGolem
	check(g.Scale >= 1.8 and g.Count <= 3, "the golem is big (Scale >= 1.8) and few (Count <= 3)", tostring(g.Scale) .. "/" .. tostring(g.Count))
	check(M.HermitCrab.Scale >= 1.2 and M.GlowMushroom.Scale >= 1.2, "the tougher kinds are bigger (Scale >= 1.2)")
	check(M.CoralCrab.Scale < 1.2 and M.Jellyfish.Scale < 1.2 and M.CrystalLizard.Scale < 1.2 and M.CaveBat.Scale < 1.2, "the plain kinds are small (Scale < 1.2)")

	-- inside a field the stats rise with the level
	for _, zid in ZONE_IDS do
		local list = {}
		for _, k in NEW do if M[k].Zone == zid then table.insert(list, k) end end
		table.sort(list, function(a, b) return C.MonsterLevel(a) < C.MonsterLevel(b) end)
		local ok, why = true, ""
		for i = 2, #list do
			local a, b = M[list[i - 1]], M[list[i]]
			if C.MonsterLevel(list[i - 1]) >= C.MonsterLevel(list[i]) then ok, why = false, "levels not strictly rising at " .. list[i] end
			if not (a.HP < b.HP and a.XP < b.XP and a.Damage <= b.Damage and a.Gold <= b.Gold) then ok, why = false, list[i - 1] .. " -> " .. list[i] end
		end
		check(ok, zid .. ": with the level HP and XP rise strictly, Damage and Gold never fall", why)
	end

	-- between the level neighbours. Rule: ladder = plain kinds Slime Lv2 / Goblin Lv12 / Skeleton Lv26 when Scale < 1.2,
	-- big kinds Slime Prince Lv5 / Goblin Brute Lv18 / Skeleton Knight Lv30 when Scale >= 1.2; lower = the highest ladder kind
	-- at or below the new kind's level, upper = the lowest at or above it; HP, Damage, XP and Gold lie between them (equal allowed)
	for _, k in NEW do
		local d = M[k]
		local class = classOf(d)
		local lo, hi = around(C, class, C.MonsterLevel(k))
		check(lo ~= nil and hi ~= nil, k .. " (" .. class .. ", Lv" .. C.MonsterLevel(k) .. ") has a lower and an upper ladder neighbour", tostring(lo) .. "/" .. tostring(hi))
		if lo and hi then
			for _, f in STAT_FIELDS do
				check(M[lo][f] <= d[f] and d[f] <= M[hi][f], k .. " " .. f .. " = " .. tostring(d[f]) .. " lies between " .. lo .. " " .. M[lo][f] .. " and " .. hi .. " " .. M[hi][f],
					class)
			end
		end
	end
	-- and the field-level reading: Coral above the slime family (Lv <= 5), Crystal at or above the Goblin (Lv12), below the Knight (Lv30)
	local slimeHP, slimeXP = 0, 0
	for k, d in M do
		if not d.Boss and not NEW_SET[k] and (d.Shape == "Slime") and C.MonsterLevel(k) <= 5 then
			slimeHP, slimeXP = math.max(slimeHP, d.HP), math.max(slimeXP, d.XP)
		end
	end
	for _, k in { "CoralCrab", "Jellyfish", "HermitCrab" } do
		check(M[k].HP > slimeHP and M[k].XP > slimeXP and C.MonsterLevel(k) > 5, k .. " is above every slime-family kind of Lv <= 5 (HP " .. slimeHP .. ", XP " .. slimeXP .. ") and above Lv5",
			tostring(M[k].HP) .. "/" .. tostring(M[k].XP))
	end
	for _, k in { "CrystalLizard", "CaveBat", "GlowMushroom", "CrystalGolem" } do
		check(M[k].HP >= M.Goblin.HP and M[k].XP >= M.Goblin.XP and C.MonsterLevel(k) >= C.MonsterLevel("Goblin")
			and M[k].HP < M.SkeletonKnight.HP and M[k].XP < M.SkeletonKnight.XP and C.MonsterLevel(k) < C.MonsterLevel("SkeletonKnight"),
			k .. " is at or above the Goblin (Lv12) and below the Skeleton Knight (Lv30) in HP, XP and level")
	end
	for _, k in { "CrystalLizard", "CaveBat" } do
		check(M[k].HP < M.Skeleton.HP and M[k].XP < M.Skeleton.XP, k .. " (plain) is below the Skeleton (Lv26)")
	end
	check(M.CoralCrab.Count + M.Jellyfish.Count + M.HermitCrab.Count <= 20 and M.CrystalLizard.Count + M.CaveBat.Count + M.GlowMushroom.Count + M.CrystalGolem.Count <= 24,
		"a field holds at most 20 / 24 monsters (like the woods and ruins)")
end)

------------------------------------------------------------------ 5. loot
runGroup("loot", function()
	local C = newWorld().Config
	local items, tables, M = C.Loot.Items, C.Loot.Tables, C.MonsterTypes
	for _, k in NEW do
		local t = tables[k]
		check(type(t) == "table" and #t > 0, k .. " has a loot table", type(t))
		if type(t) ~= "table" then continue end
		local bad = {}
		for i, r in t do
			local kinds = (r.Item ~= nil and 1 or 0) + (r.Potion ~= nil and 1 or 0) + (r.Weapon ~= nil and 1 or 0)
			if kinds ~= 1 then table.insert(bad, i .. ": not exactly one of Item / Potion / Weapon") end
			if r.Item ~= nil and items[r.Item] == nil then table.insert(bad, i .. ": item " .. tostring(r.Item) .. " does not exist") end
			if r.Potion ~= nil and r.Potion ~= "HP" and r.Potion ~= "MP" then table.insert(bad, i .. ": potion " .. tostring(r.Potion)) end
			if r.Weapon ~= nil and not (type(r.Weapon) == "number" and r.Weapon == math.floor(r.Weapon) and r.Weapon >= 1) then table.insert(bad, i .. ": weapon tier") end
			if not (type(r.P) == "number" and r.P > 0 and r.P <= 1) then table.insert(bad, i .. ": P " .. tostring(r.P) .. " not in (0, 1]") end
			if r.N ~= nil and not (type(r.N) == "number" and r.N >= 1 and r.N == math.floor(r.N)) then table.insert(bad, i .. ": N " .. tostring(r.N)) end
		end
		check(#bad == 0, k .. " rows are valid (existing items, P in (0, 1], whole N)", table.concat(bad, "; "))

		local mine = rowMap(t)
		local own = MATERIAL_OF[M[k].Zone]
		local other = MATERIAL_OF[M[k].Zone == "CoralCoast" and "CrystalWoods" or "CoralCoast"]
		check(mine["I:" .. own] ~= nil and mine["I:" .. other] == nil, k .. " drops its field's material " .. own .. " and not the other field's")

		-- scroll / transfer / potion / weapon rows no higher than the neighbour of the same band: plain -> Goblin, big -> Goblin Brute
		local class = classOf(M[k])
		local nbKind = LOOT_NEIGHBOUR[class]
		local nb = rowMap(tables[nbKind])
		local worse = {}
		for key, p in mine do
			local id = string.sub(key, 3)
			local scroll = string.sub(key, 1, 2) == "I:" and items[id] ~= nil and (items[id].Kind == "Enhance" or items[id].Kind == "Transfer")
			if scroll or string.sub(key, 1, 2) == "P:" or string.sub(key, 1, 2) == "W:" then
				if nb[key] == nil or p > nb[key] + 1e-12 then table.insert(worse, key .. " " .. p .. " > " .. tostring(nb[key])) end
			end
		end
		check(#worse == 0, k .. " scroll / transfer / potion / weapon chances are at most " .. nbKind .. "'s (" .. class .. " band)", table.concat(worse, "; "))

		local weapons = {}
		for _, r in t do if r.Weapon ~= nil then table.insert(weapons, r.Weapon) end end
		if k == "CrystalGolem" then
			check(#weapons >= 1, "the golem has a weapon row")
			for _, tier in weapons do check(tier <= 4, "the golem's weapon tier is 4 or lower", tostring(tier)) end
		else
			check(#weapons == 0, k .. " has no weapon row", show(weapons))
		end
	end
	for _, id in { "SeaShell", "CrystalShard" } do
		local it = items[id]
		check(type(it) == "table" and it.Kind == "Material" and type(it.Sell) == "number" and it.Sell > 0, id .. " is a Material with Sell > 0", show(it and it.Sell))
		check(count(C.Loot.Order, id) == 1, id .. " is in Config.Loot.Order once", show(C.Loot.Order))
		check(type(it) == "table" and textOk(it.Name) and type(it.Icon) == "string" and it.Icon ~= "" and type(it.Color) == "table", id .. " has a name, an icon key and a colour")
	end
	check(items.SeaShell.Sell >= items.Jelly.Sell and items.SeaShell.Sell <= items.GoblinTooth.Sell, "Sea Shell sells between Jelly and Goblin Tooth")
	check(items.CrystalShard.Sell >= items.GoblinTooth.Sell and items.CrystalShard.Sell <= items.Bone.Sell, "Crystal Shard sells between Goblin Tooth and Old Bone")
	local function idx(id) return table.find(C.Loot.Order, id) or -1 end
	check(idx("SlimeCore") < idx("SeaShell") and idx("SeaShell") < idx("GoblinTooth") and idx("BruteHorn") < idx("CrystalShard") and idx("CrystalShard") < idx("Bone"),
		"the two materials sit in the list between their level neighbours")
	-- a later round's own items are not this round's: gathering (게임성 개발 3, 2026-10-11) marks its materials Source = "Gather"
	local function later(id)
		local src = type(items[id]) == "table" and items[id].Source
		return src == "Gather" or src == "Craft" or src == "Goose" -- the gathering / crafting rounds (게임성 개발 3), the egg hunt's (A23-134)
	end
	local order = {}
	for _, id in C.Loot.Order do if id ~= "SeaShell" and id ~= "CrystalShard" and not later(id) then table.insert(order, id) end end
	local baseOrder = {}
	for _, id in base.Loot.Order do table.insert(baseOrder, id) end
	check(same(order, baseOrder), "Loot.Order without the two materials is the base order")
	for id, it in items do
		if base.Loot.Items[id] == nil and id ~= "SeaShell" and id ~= "CrystalShard" and not later(id) then check(false, "no other new item (" .. id .. ")") end
	end
end)

------------------------------------------------------------------ 6. barks
runGroup("barks", function()
	local C = newWorld().Config
	local B = C.Barks
	local owner = {}
	for kind, set in B.Lines do
		for _, moment in MOMENTS do
			if type(set) == "table" and type(set[moment]) == "table" then
				for _, line in set[moment] do
					owner[line] = owner[line] or {}
					owner[line][kind] = true
				end
			end
		end
	end
	for _, k in NEW do
		local set = B.Lines[k]
		check(type(set) == "table", k .. " has Lines", type(set))
		if type(set) ~= "table" then continue end
		for _, moment in MOMENTS do
			local list = set[moment]
			check(type(list) == "table" and #list >= 1, k .. " " .. moment .. " is a non-empty list", show(list))
			if type(list) ~= "table" then continue end
			local bad = {}
			for i, line in list do
				if type(line) ~= "string" or line == "" then
					table.insert(bad, i .. " is not a non-empty string")
				else
					local n = utf8.len(line) or 99
					local words = 0
					for _ in string.gmatch(line, "%S+") do words += 1 end
					if n > 24 then table.insert(bad, line .. ": longer than 24") end
					if n > 12 or words > 2 then table.insert(bad, line .. ": more than 2 words / 12 letters (A23-74)") end
					local sharers = 0
					for _ in owner[line] or {} do sharers += 1 end
					if sharers ~= 1 then table.insert(bad, line .. ": shared with another kind") end
				end
			end
			check(#bad == 0, k .. " " .. moment .. " lines are short (<= 24 chars; A23-74: <= 2 words, 12 letters) and not shared with another kind", table.concat(bad, "; "))
		end
		local fam = B.BubbleFamily[k]
		check(type(fam) == "string" and fam ~= "" and type(B.BubbleArt[fam]) == "string", k .. " has a BubbleFamily whose BubbleArt key is set", tostring(fam))
	end
	check(B.BubbleFamily.CoralCrab == B.BubbleFamily.Jellyfish and B.BubbleFamily.Jellyfish == B.BubbleFamily.HermitCrab, "the Coral Coast kinds share one bubble family")
	check(B.BubbleFamily.CrystalLizard == B.BubbleFamily.CaveBat and B.BubbleFamily.CaveBat == B.BubbleFamily.GlowMushroom and B.BubbleFamily.GlowMushroom == B.BubbleFamily.CrystalGolem,
		"the Crystal Cave Woods kinds share one bubble family")
	check(B.BubbleFamily.CoralCrab ~= B.BubbleFamily.CrystalLizard, "the two fields have different bubble families")
end)

------------------------------------------------------------------ 7. order and quests
runGroup("order", function()
	local C = newWorld().Config
	for _, k in NEW do
		check(count(C.MonsterTypeOrder, k) == 1, k .. " is in MonsterTypeOrder once", show(C.MonsterTypeOrder))
	end
	local every = {}
	for k in C.MonsterTypes do every[k] = count(C.MonsterTypeOrder, k) end
	local missing = {}
	for k, n in every do if n ~= 1 then table.insert(missing, k) end end
	check(#missing == 0, "every kind is in MonsterTypeOrder exactly once", table.concat(missing, ","))
	local hq = C.MonsterTypes.HermitCrab.QuestAs
	check(hq == "CoralCrab" and C.MonsterTypes[hq] ~= nil and C.QuestKind("HermitCrab") == "CoralCrab", "Hermit Crab counts as a Coral Crab for quests (QuestAs resolves)", tostring(hq))
	for _, k in NEW do
		local qa = C.MonsterTypes[k].QuestAs
		check(qa == nil or C.MonsterTypes[qa] ~= nil, k .. " QuestAs (if any) is an existing kind", tostring(qa))
		check(k == "HermitCrab" or qa == nil, k .. " has no QuestAs of its own (only the Hermit Crab counts as a crab)", tostring(qa))
	end
	check(C.QuestKind("CoralCrab") == "CoralCrab" and C.QuestKind("CrystalGolem") == "CrystalGolem", "the others count as themselves")
end)

------------------------------------------------------------------ 8. English only
runGroup("text", function()
	local C = newWorld().Config
	for _, id in ZONE_IDS do
		check(textOk(C.Zones[id].Name), id .. " Name is printable ASCII (plus ... and ~)", tostring(C.Zones[id].Name))
	end
	for _, k in NEW do
		local d = C.MonsterTypes[k]
		check(textOk(d.Name) and textOk(d.Short), k .. " Name / Short are printable ASCII (plus the ellipsis and ~)", tostring(d.Name) .. "/" .. tostring(d.Short))
		local bad = {}
		for _, moment in MOMENTS do
			for _, line in (C.Barks.Lines[k] and C.Barks.Lines[k][moment]) or {} do
				if not textOk(line) then table.insert(bad, tostring(line)) end
			end
		end
		check(#bad == 0, k .. " bark lines are printable ASCII (plus the ellipsis and ~)", table.concat(bad, "; "))
	end
	check(textOk("Hang… zzz~") and not textOk("산호") and not textOk("caf\u{e9}") and not textOk("tab\there") and not textOk(""),
		"the text rule itself: ASCII + ellipsis + ~ pass, Korean / accents / control characters fail")
end)

finish()
