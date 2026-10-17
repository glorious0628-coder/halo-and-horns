-- BB14 KO screen (server part): CombatService's death pipeline sends the owner-only Net.Fx(victim, "KO",
-- { By, Name, Faction, Lost, Sack, RespawnIn }). Runs on tools/fixtures/dev2_world.luau (the real CombatService,
-- PvPService, GrudgeService, RankingService, AnnounceService ...); deaths go through PlayerService.CharacterDied ->
-- CombatService.runDeathPipeline exactly as in a server.

local D0 = C0.Death

-- the KO payloads one player received (in order)
local function kos(w, p)
	local out = {}
	for _, f in w.Fx do
		if f.Kind == "KO" and f.Player == p then table.insert(out, f.Data) end
	end
	return out
end

local function lastKO(w, p)
	local list = kos(w, p)
	return list[#list]
end

local function hurt(w, p, kind, amount)
	return w.Combat.DamagePlayer(p, amount or 2, nil, false, kind)
end

------------------------------------------------------------------ 1. contract texts
runGroup("config", function()
	check(D0.SourceSeconds == 3 and D0.FallBelowFloor == 30, "Config.Death: a hit within 3 s is the cause; 30 below the floor = a fall")
	local missing = {}
	for _, t in { D0.Text, D0.Tips } do
		for k, v in t do
			if type(v) == "string" and string.sub(k, -2) ~= "En" and type(t[k .. "En"]) ~= "string" then table.insert(missing, k) end
		end
	end
	check(#missing == 0, "every Config.Death line has an En pair", table.concat(missing, ","))
	check(D0.Tips.Other == "Stuck? Menu → Travel", "the 'Other' tip from BB14 (English, A23-48)")
end)

------------------------------------------------------------------ 2. monsters, kaiju, falls, other
runGroup("causes", function()
	local w = rankWorld()
	local p = w:Join(101, "Halo")
	hurt(w, p, "Slime")
	w:Die(p)
	local ko = lastKO(w, p)
	check(ko ~= nil and ko.By == "Monster" and ko.Name == C0.MonsterTypes.Slime.Name and ko.Lost == 0 and ko.Sack == false
		and ko.RespawnIn == C0.Player.RespawnTime, "a slime KO: By Monster, the monster's name, nothing lost, RespawnIn", show(ko))
	check(ko ~= nil and ko.Kind == "Slime", "r7: Kind = the monster's MonsterTypes key (the KO card's picture)", show(ko))
	check(#kos(w, p) == 1, "one KO payload per death")
	local other = 0
	for _, f in w.Fx do if f.Kind == "KO" and f.Player ~= p then other += 1 end end
	check(other == 0, "the payload goes to the victim only (never all clients)")
	-- a monster hit older than 3 s is not the cause
	local w2 = rankWorld()
	local q = w2:Join(102, "Halo")
	hurt(w2, q, "Goblin")
	w2:Advance(3.5)
	w2:Die(q)
	check(lastKO(w2, q).By == "Other" and lastKO(w2, q).Kind == nil, "a monster hit 3.5 s before: By Other (a reset), no Kind", show(lastKO(w2, q)))
	-- the source is forgotten after the death
	local w3 = rankWorld()
	local r = w3:Join(103, "Halo")
	hurt(w3, r, "GoblinBrute")
	w3:Die(r)
	check(lastKO(w3, r).Name == C0.MonsterTypes.GoblinBrute.Name, "goblin chief's name")
	w3:Die(r)
	check(lastKO(w3, r).By == "Other", "the next death without a new hit is not the old monster again")
	-- a player's hit never records a monster source; an unknown kind is not a monster
	local w4 = rankWorld()
	local s4 = w4:Join(104, "Halo")
	hurt(w4, s4, "NoSuchMonster")
	w4:Die(s4)
	check(lastKO(w4, s4).By == "Other", "an unknown kind: By Other", show(lastKO(w4, s4)))
	-- kaiju stomp outside PvP zones (no attacker credited)
	local w5 = rankWorld()
	local kaiju = w5:Join(201, "Horns")
	local v5 = w5:Join(105, "Halo")
	w5.Registry.KaijuService.GetActive = function() return kaiju end
	hurt(w5, v5, "Kaiju", 10)
	w5:Die(v5)
	check(lastKO(w5, v5).By == "Kaiju" and lastKO(w5, v5).Name == "P201", "a kaiju stomp: By Kaiju, the kaiju's public name", show(lastKO(w5, v5)))
	-- falls: far below the floor, the body gone (the void), free fall
	local w6 = rankWorld()
	local f1 = w6:Join(106, "Halo")
	f1.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, -40, 0)
	w6:Die(f1)
	check(lastKO(w6, f1).By == "Fall" and lastKO(w6, f1).Kind == nil, "40 below the floor: By Fall (no Kind)", show(lastKO(w6, f1)))
	local f2 = w6:Join(107, "Halo")
	f2.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, -20, 0)
	w6:Die(f2)
	check(lastKO(w6, f2).By == "Other", "20 below the floor (a hole, not the void): By Other")
	local f3 = w6:Join(108, "Halo")
	f3.Character:FindFirstChild("HumanoidRootPart").Parent = nil
	w6:Die(f3)
	check(lastKO(w6, f3).By == "Fall", "the body already gone (destroyed by the void): By Fall")
	local f4 = w6:Join(109, "Halo")
	f4.Character:FindFirstChildOfClass("Humanoid").State = "HumanoidStateType.Freefall"
	w6:Die(f4)
	check(lastKO(w6, f4).By == "Fall", "in free fall: By Fall")
	local f5 = w6:Join(110, "Halo")
	hurt(w6, f5, "Slime")
	f5.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, -40, 0)
	w6:Die(f5)
	check(lastKO(w6, f5).By == "Monster", "a monster hit within 3 s wins over the height (By order)")
end)

------------------------------------------------------------------ 3. players: names, lost gold, sacks
runGroup("players", function()
	-- a Horns plunders a Halo: Lost = the gold that left the pouch
	local w = rankWorld()
	local k = w:Join(201, "Horns")
	local v = w:Join(101, "Halo", { Carried = 10000 })
	w:Hit(v, k, 5)
	w:Die(v)
	local ko = lastKO(w, v)
	local stolen = 10000 - (w.Data[v].CarriedGold or 0)
	check(ko ~= nil and ko.By == "Player" and ko.Name == "P201" and ko.Faction == "Horns", "a PvP KO: By Player, PublicName, the killer's faction", show(ko))
	check(stolen > 0 and ko.Lost == stolen, "Lost = the plundered gold (the real pouch difference)", show({ stolen, ko and ko.Lost }))
	-- a Wanted Horns KO'd by a knight loses its share of the pouch
	local w2 = rankWorld()
	local knight = w2:Join(102, "Halo")
	local villain = w2:Join(202, "Horns", { Carried = 4000 })
	w2.PvP.DebugSetStars(villain, 2)
	w2:Hit(villain, knight, 5)
	w2:Die(villain)
	local ko2 = lastKO(w2, villain)
	check(ko2 and ko2.By == "Player" and ko2.Lost == 4000 - (w2.Data[villain].CarriedGold or 0) and ko2.Lost > 0,
		"a Wanted Horns' KO: Lost = what the bounty KO took", show(ko2))
	-- a clean Horns loses nothing
	local w3 = rankWorld()
	local k3 = w3:Join(103, "Halo")
	local v3 = w3:Join(203, "Horns", { Carried = 500 })
	w3:Hit(v3, k3, 5)
	w3:Die(v3)
	check(lastKO(w3, v3).Lost == 0, "a clean Horns KO'd: nothing lost", show(lastKO(w3, v3)))
	-- a hidden killer
	local w4 = rankWorld()
	local k4 = w4:Join(204, "Horns", { Hide = true })
	local v4 = w4:Join(104, "Halo")
	w4:Hit(v4, k4, 5)
	w4:Die(v4)
	check(lastKO(w4, v4).Name == string.format(C0.Announce.Text.HiddenName, C0.Factions.Horns.Name) and lastKO(w4, v4).Name ~= "P204",
		"a hidden killer is '<진영> 한 명' on the KO screen too", show(lastKO(w4, v4)))
	-- a thief KO'd with the sack
	local w5 = rankWorld()
	local thief = w5:Join(205, "Horns")
	local mark = w5:Join(105, "Halo", { Carried = 10000 })
	local knight5 = w5:Join(106, "Halo")
	w5:KO(mark, thief)
	check(w5.Grudge.HasSack(thief), "the thief carries a sack")
	w5:Hit(thief, knight5, 5)
	w5:Die(thief)
	check(lastKO(w5, thief).Sack == true and not w5.Grudge.HasSack(thief), "KO'd with a grudge sack: Sack = true (and it is gone)", show(lastKO(w5, thief)))
	-- a player's hit with a stray sourceKind is still a PvP KO (attacker first)
	local w6 = rankWorld()
	local k6 = w6:Join(206, "Horns")
	local v6 = w6:Join(107, "Halo")
	w6.Combat.DamagePlayer(v6, 5, k6, false, "Slime")
	w6:RunSpawned()
	w6:Die(v6)
	check(lastKO(w6, v6).By == "Player", "a hit with an attacker is a PvP KO")
	-- the attacker's hit carried a stray kind, then the attacker left: the death is not a monster KO
	local w7 = rankWorld()
	local k7 = w7:Join(207, "Horns")
	local v7 = w7:Join(108, "Halo")
	w7.Combat.DamagePlayer(v7, 5, k7, false, "Slime")
	w7:RunSpawned()
	w7:Leave(k7)
	w7:RunSpawned()
	w7:Die(v7)
	check(lastKO(w7, v7).By == "Other", "a player's hit never records a monster source (killer gone: By Other)", show(lastKO(w7, v7)))
	-- a slime and a player both hit within 3 s: the player is the cause (By order)
	local w8 = rankWorld()
	local k8 = w8:Join(208, "Horns")
	local v8 = w8:Join(109, "Halo")
	hurt(w8, v8, "Slime")
	w8:Hit(v8, k8, 5)
	w8:Die(v8)
	check(lastKO(w8, v8).By == "Player" and lastKO(w8, v8).Name == "P208", "a recent monster hit never hides the PvP killer", show(lastKO(w8, v8)))
end)

------------------------------------------------------------------ EG05 Fun Tips (story_depth (나), 검수 2026-10-10)
-- about one KO in 15 carries a joke tip (fx field Tip), never one of the first 3 of an account; every KO is counted (data.KOs)
runGroup("fun tips (EG05)", function()
	local F = D0.Fun
	check(F.Every == 15 and F.SkipFirst == 3 and #F.Lines == 4 and C0.Data.Defaults.KOs == 0, "Config.Death.Fun: 1 in 15, not the first 3, 4 lines; the save counts KOs from 0", show(F))
	for i, line in F.Lines do check(string.sub(line, 1, 5) == "Tip: " and #line <= 80, "fun line " .. i .. " starts with 'Tip: ' and is short", line) end
	-- the pure picker
	check(C0.FunTip(1, 0, 0) == nil and C0.FunTip(3, 0, 0) == nil, "the first 3 KOs never get one", tostring(C0.FunTip(3, 0, 0)))
	check(C0.FunTip(4, 0, 0) == F.Lines[1], "the 4th KO can (roll 0, pick 0 = line 1)", tostring(C0.FunTip(4, 0, 0)))
	check(C0.FunTip(4, 0.06, 0.26) == F.Lines[2] and C0.FunTip(4, 0.06, 0.5) == F.Lines[3] and C0.FunTip(4, 0.06, 0.99) == F.Lines[4], "the pick chooses the line (quarters)", "")
	check(C0.FunTip(4, 1 / 15, 0) == nil and C0.FunTip(4, 0.5, 0) == nil and C0.FunTip(4, 0.999, 0) == nil, "a roll of 1/15 or more: none", "")
	check(C0.FunTip(4, -0.1, 0) == nil and C0.FunTip(4, 0 / 0, 0) == nil and C0.FunTip(4, nil, 0) == nil and C0.FunTip("4", 0, 0) == nil and C0.FunTip(0 / 0, 0, 0) == nil
		and C0.FunTip(nil, 0, 0) == nil, "bad numbers: none", "")
	check(C0.FunTip(4, 0, 5) == F.Lines[4] and C0.FunTip(4, 0, -1) == F.Lines[1] and C0.FunTip(4, 0, 0 / 0) == F.Lines[1] and C0.FunTip(4, 0, nil) == F.Lines[1],
		"a bad pick is clamped", "")
	-- through the death pipeline: the count and the payload
	local w = rankWorld()
	local p = w:Join(301, "Halo")
	for i = 1, 3 do
		w.Script = { 0, 0.5 }
		w:Die(p)
		w.Script = nil
		check(lastKO(w, p).Tip == nil, "KO " .. i .. ": no joke tip (one of the first 3)", tostring(lastKO(w, p).Tip))
	end
	w.Script = { 0.01, 0.5 }
	w:Die(p)
	w.Script = nil
	check(lastKO(w, p).Tip == F.Lines[3] and lastKO(w, p).By == "Other", "KO 4 with a lucky roll: line 3 in the KO fx, the rest of the payload as before", show(lastKO(w, p)))
	w.Script = { 0.9, 0.5 }
	w:Die(p)
	w.Script = nil
	check(lastKO(w, p).Tip == nil, "KO 5 with an unlucky roll: no tip", tostring(lastKO(w, p).Tip))
	check(#kos(w, p) == 5, "five payloads for five deaths", tostring(#kos(w, p)))
	-- the count is the account's own (another player starts at 0)
	local q = w:Join(302, "Horns")
	w.Script = { 0, 0 }
	w:Die(q)
	w.Script = nil
	check(lastKO(w, q).Tip == nil, "another player's first KO: no tip", tostring(lastKO(w, q).Tip))
end)

finish()
