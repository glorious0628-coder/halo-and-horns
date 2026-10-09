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

runGroup("danger (game dev 1's Config.MonsterDanger on these levels)", function()
	local C = newWorld().Config
	local D = C.MonsterDanger
	local L = C.MonsterLevel
	check(type(D) == "table" and type(D.Tier) == "function" and type(D.LevelOf) == "function",
		"one MonsterDanger: game dev 1's table (no second definition)")
	-- Tier(monsterLevel, myLevel) with the Level attribute this server sets
	check(D.LevelOf("Slime", L("Slime")) == L("Slime"), "LevelOf reads the Level attribute")
	check(D.Tier(L("Slime"), 1) == "Even" and D.Tier(L("BigSlime"), 1) == "Strong" and D.Tier(L("SlimeKing"), 1) == "Strong",
		"Lv1: green slimes white, the Slime Prince and the King Slime yellow")
	check(D.Tier(L("GoblinBrute"), 10) == "Deadly" and D.Tier(L("Goblin"), 10) == "Even", "Lv10: the brute red, goblins white")
	check(D.Tier(L("CaptainClatter"), 25) == "Strong" and D.Tier(L("Slime"), 25) == "Weak",
		"Lv25: Captain Clatter yellow, a green slime gray")
end)

finish()
