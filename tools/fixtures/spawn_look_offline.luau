-- spawn_look_offline.luau : zone_check_halo_2026-10-10 #43 (게임성 개발 3). tools/test_spawn_look.py binds CONFIG_SOURCE and
-- SPAWN_EXTRACT (ZoneService.GetSpawnCFrame with its spawn constants + PlayerService stat / respawnZoneId / firstMissionOpen /
-- spawnCFrame, cut from the CURRENT sources) in front of dev2_kit.luau. Util (Random, Warn), the DataService and the players are
-- doubles; the kit's CFrame double records the constructor ("lookAt" / "new") and its arguments, so a spawn is read as
-- { Ctor, Args = { position, target } }.

local C = execute("Config", CONFIG_SOURCE, nativeEnv())
local EPS = 1e-6

local function spawnWorld()
	local rng = { Script = {} }
	local w = { Rng = rng, Warnings = {} }
	local U = { Random = randomDouble(rng).new(), Warn = function(_, msg) table.insert(w.Warnings, msg) end }
	local S = { DataService = { Get = function(p) return p.Data end } }
	local env = nativeEnv()
	env.typeof = typeofDouble
	local M = execute("SpawnExtract", SPAWN_EXTRACT, env, C, U, S)
	S.ZoneService = M.ZoneService
	w.M, w.S, w.U = M, S, U
	return w
end

local function player(data, attrs)
	local p = { Data = data, Attrs = attrs or {} }
	function p:GetAttribute(key) return self.Attrs[key] end
	return p
end
local function halo(step) return player({ TutorialStep = step, Faction = "Halo" }) end
local function horns(step) return player({ TutorialStep = step, Faction = "Horns" }) end

local function near(a, b) return math.abs(a - b) < EPS end
local function at(v, x, y, z) return near(v.X, x) and near(v.Y, y) and near(v.Z, z) end
local function describe(cf)
	if not cf then return "nil" end
	local a = cf.Args or {}
	local p, t = a[1], a[2]
	return tostring(cf.Ctor) .. "(" .. (p and string.format("%.1f,%.1f,%.1f", p.X, p.Y, p.Z) or "") .. (t and string.format(" -> %.1f,%.1f,%.1f", t.X, t.Y, t.Z) or "") .. ")"
end
local function middle(w) w.Rng.Script = { 0.5, 0.5 } end -- no jitter: the two NextNumber(-6, 6) draws are 0

runGroup("config", function()
	local looks = {}
	for id, zone in C.Zones do
		if zone.SpawnLook ~= nil then table.insert(looks, id) end
	end
	table.sort(looks)
	check(table.concat(looks, ",") == "HaloTown,HornsTown", "SpawnLook exists for the two towns only", table.concat(looks, ","))
	check(at(C.Zones.HaloTown.SpawnLook, 0, 0, -330) and at(C.Zones.HornsTown.SpawnLook, 0, 0, 330),
		"Halo (0,0,-330), Horns (0,0,330): the gate at the bridge end", show({ C.Zones.HaloTown.SpawnLook, C.Zones.HornsTown.SpawnLook }))
	check(at(C.Zones.HaloTown.Spawn, 0, 0, -420) and at(C.Zones.HornsTown.Spawn, 0, 0, 420), "the spawn points are unchanged (-420 / 420)", "")
	check(C.Tutorial.Steps.Done == 99 and C.Tutorial.Steps.Kill == 0, "the first mission is open below Steps.Done (99)", show(C.Tutorial.Steps))
end)

runGroup("GetSpawnCFrame", function()
	local w = spawnWorld()
	local Z = w.M.ZoneService
	middle(w)
	local cf = Z.GetSpawnCFrame("HaloTown", true)
	check(cf.Ctor == "lookAt" and at(cf.Args[1], 0, 4, -420) and at(cf.Args[2], 0, 4, -330), "Halo, faceOut: stands at (0,4,-420), looks at the gate (0,4,-330)", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("HaloTown")
	check(cf.Ctor == "lookAt" and at(cf.Args[2], 0, 4, -515), "Halo, no flag: looks at the town middle (0,4,-515)", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("HaloTown", false)
	check(at(cf.Args[2], 0, 4, -515), "Halo, faceOut false: the town middle", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("HaloTown", 1)
	check(at(cf.Args[2], 0, 4, -515), "only `true` turns it on (1 is not true)", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("HaloTown", "yes")
	check(at(cf.Args[2], 0, 4, -515), "only `true` turns it on (a string is not true)", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("HornsTown", true)
	check(at(cf.Args[1], 0, 4, 420) and at(cf.Args[2], 0, 4, 330), "Horns, faceOut: (0,4,420) -> the gate (0,4,330)", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("HornsTown")
	check(at(cf.Args[2], 0, 4, 515), "Horns, no flag: the town middle (0,4,515)", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("Crossroads", true)
	check(at(cf.Args[1], 0, 4, -25) and at(cf.Args[2], 0, 4, 0), "a zone without SpawnLook keeps the middle even with the flag", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("SlimeMeadow", true)
	check(at(cf.Args[2], 430, 4, 0), "the meadow: the middle with the flag too", describe(cf))
	middle(w)
	cf = Z.GetSpawnCFrame("NoSuchZone", true)
	check(at(cf.Args[1], 0, 4, -25), "an unknown zone falls back to the Crossroads spawn", describe(cf))
	-- the jitter (+-6 in x and z) is unchanged and the look keeps the spawn height
	w.Rng.Script = { 1, 0 }
	cf = Z.GetSpawnCFrame("HaloTown", true)
	check(at(cf.Args[1], 6, 4, -426) and at(cf.Args[2], 0, 4, -330), "jitter +6 / -6 moves the spawn, the look target stays the gate at spawn height", describe(cf))
	-- the look equal to the spawn point: no lookAt (nothing to look at)
	middle(w)
	local keep = C.Zones.HaloTown.SpawnLook
	C.Zones.HaloTown.SpawnLook = vec(0, 0, -420)
	cf = Z.GetSpawnCFrame("HaloTown", true)
	C.Zones.HaloTown.SpawnLook = keep
	check(cf.Ctor == "new" and at(cf.Args[1], 0, 4, -420), "a look on the spawn point itself: a plain CFrame.new", describe(cf))
	-- a zone with a SpawnLook that is no Vector3 is ignored
	middle(w)
	C.Zones.HaloTown.SpawnLook = "gate"
	cf = Z.GetSpawnCFrame("HaloTown", true)
	C.Zones.HaloTown.SpawnLook = keep
	check(at(cf.Args[2], 0, 4, -515), "a broken SpawnLook falls back to the town middle", describe(cf))
end)

runGroup("the first mission decides", function()
	local w = spawnWorld()
	local M = w.M
	for _, step in { 0, 1, 2, 3, 98 } do
		check(M.firstMissionOpen(halo(step)) == true, "TutorialStep " .. step .. ": the first mission is open", "")
	end
	check(M.firstMissionOpen(halo(99)) == false, "TutorialStep 99 (done): closed", "")
	check(M.firstMissionOpen(halo(120)) == false, "a step above Done: closed", "")
	check(M.firstMissionOpen(player(nil, {})) == true, "no data and no attribute: step 0, open (a brand-new player)", "")
	check(M.firstMissionOpen(player(nil, { TutorialStep = 99 })) == false, "no data, the mirrored attribute 99: closed", "")
	check(M.firstMissionOpen(player({ TutorialStep = "x" }, {})) == false, "an unreadable step is never 'open'", "")
	-- the whole spawn of a player: the home zone, then the look
	for _, case in { { "Halo, new (step 0)", halo(0), "HaloTown", true }, { "Halo, at the Forge (3)", halo(3), "HaloTown", true },
		{ "Halo, done", halo(99), "HaloTown", false }, { "Horns, new", horns(0), "HornsTown", true },
		{ "Horns, done", horns(99), "HornsTown", false } } do
		local p = case[2]
		local zoneId = M.respawnZoneId(p)
		check(zoneId == case[3] and M.firstMissionOpen(p) == case[4], case[1] .. ": spawn zone " .. case[3] .. ", faceOut " .. tostring(case[4]),
			zoneId .. " " .. tostring(M.firstMissionOpen(p)))
	end
	middle(w)
	local newcomer = halo(0)
	local cf = M.spawnCFrame(M.respawnZoneId(newcomer), M.firstMissionOpen(newcomer))
	check(cf.Ctor == "lookAt" and at(cf.Args[2], 0, 4, -330) and cf.Args[2].Z > cf.Args[1].Z, "a new Halo player spawns looking toward +Z (the gate), not the castle", describe(cf))
	middle(w)
	local veteran = halo(99)
	cf = M.spawnCFrame(M.respawnZoneId(veteran), M.firstMissionOpen(veteran))
	check(at(cf.Args[2], 0, 4, -515) and cf.Args[2].Z < cf.Args[1].Z, "a Halo player past the first mission looks toward the town middle (-Z)", describe(cf))
	middle(w)
	local hn = horns(0)
	cf = M.spawnCFrame(M.respawnZoneId(hn), M.firstMissionOpen(hn))
	check(at(cf.Args[2], 0, 4, 330) and cf.Args[2].Z < cf.Args[1].Z, "a new Horns player looks toward the Horns gate (-Z from 420)", describe(cf))
end)

runGroup("PlayerService.spawnCFrame guards", function()
	local w = spawnWorld()
	local M, S = w.M, w.S
	-- no ZoneService: the plain spawn
	local zs = S.ZoneService
	S.ZoneService = nil
	local cf = M.spawnCFrame("HaloTown", true)
	check(cf.Ctor == "new" and at(cf.Args[1], 0, 4, -420), "no ZoneService: CFrame.new(Spawn + 4 up)", describe(cf))
	S.ZoneService = { GetSpawnCFrame = function() error("boom") end }
	cf = M.spawnCFrame("HaloTown", true)
	check(cf.Ctor == "new" and #w.Warnings == 1, "a ZoneService error: the plain spawn and one warning", tostring(#w.Warnings))
	S.ZoneService = { GetSpawnCFrame = function() return "nope" end }
	cf = M.spawnCFrame("HornsTown", false)
	check(cf.Ctor == "new" and at(cf.Args[1], 0, 4, 420), "a non-CFrame answer: the plain spawn", describe(cf))
	-- the flag arrives as a plain boolean
	local seen
	S.ZoneService = { GetSpawnCFrame = function(zoneId, faceOut) seen = { zoneId, faceOut }; return { __kind = "CFrame", Ctor = "x", Args = {} } end }
	M.spawnCFrame("HaloTown", true)
	check(seen[1] == "HaloTown" and seen[2] == true, "ZoneService gets (zoneId, true)", show(seen))
	M.spawnCFrame("HaloTown", 1)
	check(seen[2] == false, "a non-boolean flag is passed as false", show(seen))
	M.spawnCFrame("HaloTown")
	check(seen[2] == false, "no flag: false", show(seen))
	S.ZoneService = zs
end)

finish()
