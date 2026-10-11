-- walk_ground_server_offline.luau : the servers' walking ground (halo_restart 2026-10-11 '걷는 바닥 태그'), offline.
-- tools/test_walk_ground_server.py puts the source bindings + dev2_kit.luau in front of this file. MonsterService's real
-- getGroundParams and KaijuService's real groundTargets run with the current Config.GroundRoots and Util.Tagged on
-- instance doubles (ZoneService's landing spots run in test_water_rescue).

-- a world: workspace with Terrain and a Map (Ground, Decor bridges, a Halo prop kit), CollectionService tags (w.Tagged)
local function groundWorld()
	local w = newWorld()
	w.Tagged = {}
	w.Services.CollectionService = { GetTagged = function(_, tag)
		if w.TagsDown then error("offline tags down") end
		return w.Tagged[tostring(tag)] or {} -- like the engine, a number tag would be read as text
	end }
	local function inst(class, name, parent)
		local i = newInstance(class, w)
		i.Name = name
		i.Parent = parent
		return i
	end
	w.Inst = inst
	local ws = newInstance("Workspace", w)
	local terrain = inst("Terrain", "Terrain", ws)
	ws.Terrain = terrain
	local map = inst("Folder", "Map", ws)
	local ground = inst("Folder", "Ground", map)
	local decor = inst("Folder", "Decor", map)
	local bridge = inst("Model", "Bridge_Halo", decor)
	local tent = inst("Model", "GoblinTent", decor)
	local props = inst("Folder", "HaloProps", decor)
	local cellBridge = inst("Model", "Cell_3_Bridge_-400", props)
	local cell = inst("Model", "Cell_0_-512", props)
	local arch = inst("Model", "Halo_ArchBridge_1", cell)
	local house = inst("Model", "House07", cell)
	local floor = inst("Part", "Floor", house)
	local yard = inst("Part", "Yard", ws)
	w.WS, w.Terrain, w.Map = ws, terrain, map
	w.Parts = { Ground = ground, Bridge = bridge, Tent = tent, CellBridge = cellBridge, Arch = arch, House = house, Floor = floor,
		Yard = yard }
	w.ParamsMade = 0
	local env = w:Env()
	env.workspace = ws
	env.RaycastParams = { new = function() w.ParamsMade += 1; return { __kind = "RaycastParams" } end }
	w.MonGround = execute("getGroundParams", MON_GROUND_EXTRACT, env, w.Config, w.Util)
	w.KaijuGround = execute("groundTargets", KAIJU_GROUND_EXTRACT, env, w.Config, w.Util)
	return w
end

local function has(list, x)
	return table.find(list, x) ~= nil
end

local function count(list, x)
	local n = 0
	for _, v in list do if v == x then n += 1 end end
	return n
end

runGroup("monster ground", function()
	local w = groundWorld()
	local P = w.Parts
	w.Tagged.WalkGround = { P.Floor, P.Yard, P.Bridge }
	local params = w.MonGround()
	local list = params.FilterDescendantsInstances
	check(params.FilterType == "RaycastFilterType.Include" and params.IgnoreWater == false, "Include, water NOT ignored")
	check(list[1] == w.Terrain and has(list, P.Ground) and has(list, P.Bridge), "Terrain, Map.Ground, Decor Bridge_*")
	check(has(list, P.CellBridge) and has(list, P.Arch), "the world kits' bridges (a *Props cell / a cell's model named ...Bridge...)")
	check(has(list, P.Floor) and has(list, P.Yard), "every WalkGround-tagged floor (inside a prop, outside the Map)")
	check(not has(list, P.Tent) and not has(list, P.House) and not has(list, w.Map), "never the other props, the house or the whole Map")
	check(count(list, P.Bridge) == 1, "a tagged bridge listed once")
	-- cached GROUND_PARAMS_REFRESH s (a late MapBuilder pass / tag is picked up after)
	local porch = w.Inst("Part", "Porch", P.House)
	w.Tagged.WalkGround = { P.Floor, P.Yard, porch }
	check(w.MonGround() == params and w.ParamsMade == 1, "kept between rays")
	w.Clock += 11
	local again = w.MonGround()
	check(w.ParamsMade == 2 and has(again.FilterDescendantsInstances, porch), "rebuilt after GROUND_PARAMS_REFRESH: a new tag is seen")
	-- tags unreadable: the map's own ground, never thrown
	w.TagsDown = true
	w.Clock += 11
	local ok, p3 = pcall(w.MonGround)
	check(ok and not has(p3.FilterDescendantsInstances, P.Floor) and has(p3.FilterDescendantsInstances, P.Ground),
		"tags unreadable: no tagged floors, Map.Ground stays (never thrown)")
	-- no Map: Terrain + tagged
	local w2 = groundWorld()
	w2.Map.Parent = nil
	w2.Tagged.WalkGround = { w2.Parts.Yard }
	local l2 = w2.MonGround().FilterDescendantsInstances
	check(#l2 == 2 and l2[1] == w2.Terrain and l2[2] == w2.Parts.Yard, "no workspace.Map: Terrain + the tagged floors", tostring(#l2))
end)

runGroup("kaiju ground", function()
	local w = groundWorld()
	local P = w.Parts
	w.Tagged.WalkGround = { P.Floor, P.Yard }
	local list = w.KaijuGround()
	local mon = w.MonGround().FilterDescendantsInstances
	check(#list == #mon, "the kaiju stomp sees the same ground as the monsters", tostring(#list) .. " vs " .. tostring(#mon))
	local same = true
	for i, v in list do if mon[i] ~= v then same = false end end
	check(same and has(list, P.Floor) and has(list, P.CellBridge) and not has(list, P.Tent),
		"same list, same order (Config.GroundRoots + the WalkGround tag)")
	w.TagsDown = true
	local ok, l2 = pcall(w.KaijuGround)
	check(ok and not has(l2, P.Floor) and has(l2, P.Ground), "tags unreadable: never thrown")
end)

runGroup("Util.Tagged", function()
	local w = groundWorld()
	w.Tagged.X = { 1, 2 }
	check(#w.Util.Tagged("X") == 2 and #w.Util.Tagged("Y") == 0, "the tagged instances / {} for an unused tag")
	w.Tagged["5"], w.Tagged["nil"] = { 1 }, { 1 }
	check(#w.Util.Tagged(nil) == 0 and #w.Util.Tagged(5) == 0, "a bad tag (not text): {}")
	w.TagsDown = true
	local ok, l = pcall(w.Util.Tagged, "X")
	check(ok and #l == 0, "CollectionService failing: {}, never thrown")
	w.Services.CollectionService = { GetTagged = function() return "nope" end }
	w.TagsDown = false
	check(#w.Util.Tagged("X") == 0, "a non-table answer: {}")
end)

finish()
