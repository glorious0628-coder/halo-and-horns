-- monster_level_offline.luau : system_review_round1 #6 monster levels (Config.MonsterLevels / MonsterLevel /
-- MonsterDanger), offline. tools/test_monster_level.py puts the source bindings + dev2_kit.luau in front.

local BANDS = { -- field -> { lowest, highest } level a monster there may have
	SlimeMeadow = { 1, 9 }, PumpkinPatch = { 1, 12 }, HauntedHollow = { 1, 12 }, GoblinWoods = { 10, 24 },
	SkeletonRuins = { 25, 40 },
}

runGroup("levels", function()
	local C = newWorld().Config
	for kind, def in C.MonsterTypes do
		local lv = C.MonsterLevel(kind)
		check(type(C.MonsterLevels[kind]) == "number", "every kind has its own level", kind)
		local band = BANDS[def.Zone]
		local hi = band and (def.Boss and band[2] + 3 or band[2])
		check(band ~= nil and lv >= band[1] and lv <= hi, "inside its field's band (bosses up to 3 above)",
			kind .. " " .. tostring(def.Zone) .. " Lv" .. tostring(lv))
		check(lv == math.floor(lv) and lv >= 1, "a whole level", kind)
	end
	-- inside a field: the plain kind lowest, the bosses on top
	local L = C.MonsterLevel
	check(L("Slime") < L("FlowerSlime") and L("FlowerSlime") < L("BigSlime") and L("BigSlime") < L("SlimeKing"),
		"meadow: slime < flower < prince < king")
	check(L("Goblin") < L("SlingshotGoblin") and L("SlingshotGoblin") < L("GoblinBrute"), "woods: goblin < slingshot < brute")
	check(L("Skeleton") < L("SkeletonArcher") and L("SkeletonArcher") < L("SkeletonKnight")
		and L("SkeletonKnight") < L("CaptainClatter"), "ruins: skeleton < archer < knight < captain")
	check(L("PumpkinSlime") < L("PumpkinKing") and L("GhostMinion") < L("GhostKing"), "Halloween: the kings on top")
	-- a kind not listed: its zone's MinLevel
	local w = newWorld({ EditConfig = function(c) c.MonsterLevels.Goblin = nil end })
	check(w.Config.MonsterLevel("Goblin") == w.Config.Zones.GoblinWoods.MinLevel, "not listed: the zone's MinLevel")
	check(C.MonsterLevel("Nope") == 1, "an unknown kind: 1")
end)

runGroup("spawn", function()
	local at = string.find(SPAWN_SOURCE, 'rig.Model:SetAttribute("Level", Config.MonsterLevel(kind))', 1, true)
	local parent = string.find(SPAWN_SOURCE, "rig.Model.Parent = getMonstersFolder()", 1, true)
	check(at ~= nil and parent ~= nil and at < parent, "spawnMonster puts Level on every model before it is parented")
end)

runGroup("danger", function()
	local C = newWorld().Config
	local D = C.MonsterDanger
	check(type(D) == "function", "Config.MonsterDanger is the band function (game dev 1's look table is MonsterDangerLook)")
	check(D(1, 2) == "Even" and D(5, 5) == "Even" and D(5, 7) == "Even", "near the player's level: Even (white)")
	check(D(5, 8) == "Strong" and D(1, 5) == "Strong", "3 or more above: Strong (yellow)")
	check(D(5, 13) == "Deadly" and D(1, 12) == "Deadly", "8 or more above: Deadly (red)")
	check(D(12, 6) == "Weak" and D(30, 2) == "Weak" and D(11, 6) == "Even", "6 or more below: Weak (gray); 5 below still Even")
	check(D(nil, nil) == "Even" and D("x", 4) == "Strong", "bad numbers read as Lv1")
	local L = C.MonsterLevel
	check(D(1, L("Slime")) == "Even" and D(1, L("BigSlime")) == "Strong", "Lv1: green slimes white, the Slime Prince yellow")
	check(D(10, L("GoblinBrute")) == "Deadly" and D(25, L("CaptainClatter")) == "Strong", "Lv10 at the brute red, Lv25 at Captain Clatter yellow")
	-- game dev 1's look table uses the same bands (its Tier(myLevel, monsterLevel) calls this function)
	local Look = C.MonsterDangerLook
	check(type(Look) == "table" and Look.Tier(10, L("GoblinBrute")) == "Deadly" and Look.Tier(12, 6) == "Weak"
		and Look.Tier(11, 6) == "Even", "MonsterDangerLook.Tier = MonsterDanger")
	check(Look.LevelOf("Slime", L("Slime")) == L("Slime"), "MonsterDangerLook.LevelOf reads the Level attribute")
end)

finish()
