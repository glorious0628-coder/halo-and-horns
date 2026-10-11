-- tamer_research_offline.luau : the pet tamer's research, summons and treats (TamerService + PetService, 게임성 개발 3,
-- 2026-10-12; contract docs/design/tamer_server_2026-10-12.md §1-§4). tools/test_tamer_research.py binds CONFIG_SOURCE,
-- UTIL_SOURCE, TAMER_SOURCE and PET_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows. TamerService
-- and PetService run from source; PlayerService / MonsterService / LootService are the world's doubles (MonsterKilled
-- fired by hand).

local NOON = 1789959600 -- 2026-09-22 12:00 KST

local function tWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local edit = o.EditConfig
	o.EditConfig = function(c)
		if o.Off ~= true then c.Features.Research = true end
		if edit then edit(c) end
	end
	local w = dev3World(o)
	w.Net.NotifyKey = function(p, key, args, kind)
		table.insert(w.Notices, { Player = p, Key = key, Args = args, Kind = kind, Text = "KEY:" .. tostring(key) })
	end
	w.Services.ServerStorage = newInstance("ServerStorage", w)
	w.Speeds = {}
	w.PS.RefreshSpeed = function(p) table.insert(w.Speeds, { P = p, Roll = p:GetAttribute("PetRoll") }) end
	w:Service("PetService", PET_SOURCE)
	w:Service("TamerService", TAMER_SOURCE)
	w:InitStart({ "PetService", "TamerService" })
	w.T = w.Reg.TamerService
	w.P = w.Reg.PetService
	return w
end

local function player(w, id, class, faction, extra)
	local data = { Faction = faction or "Neutral", Class = class or "Archer", ClassChosen = true, Level = 5, TamerNotice = true }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

local function kill(w, p, kind, extra)
	local info = { Kind = kind, XP = 10, Gold = 5 }
	for k, v in extra or {} do info[k] = v end
	w.Reg.MonsterService.MonsterKilled:Fire(p, info)
	w:RunSpawned()
end

local function fired(w, remote, p)
	local out = {}
	for _, f in w.Fired do
		if f.Remote == remote and f.Player == p then table.insert(out, f.Payload) end
	end
	return out
end

local function last(list) return list[#list] end

local function noticesFor(w, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Notices do
		local n = w.Notices[i]
		if n.Player == p and n.Key then table.insert(out, n) end
	end
	return out
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

------------------------------------------------------------------ the table
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local R = C.Research
	check(C.Features.Research == false and C.FeatureOn("Research") == false, "Config.Features.Research is off", "")
	check(table.concat(R.Stages, ",") == "50,150,400,1000,2500", "stages 50 / 150 / 400 / 1000 / 2500 (crafting_market §4)", show(R.Stages))
	check(C.ResearchStage(0) == 0 and C.ResearchStage(49) == 0 and C.ResearchStage(50) == 1 and C.ResearchStage(149) == 1
		and C.ResearchStage(150) == 2 and C.ResearchStage(2499) == 4 and C.ResearchStage(2500) == 5 and C.ResearchStage(1e9) == 5,
		"ResearchStage: the stage the points reach", "")
	check(C.ResearchStage(0 / 0) == 0 and C.ResearchStage("150") == 0 and C.ResearchStage(nil) == 0, "ResearchStage: junk = 0", "")
	local slimes = true
	for _, k in { "Slime", "BigSlime", "FlowerSlime", "SlimeKing", "PumpkinSlime" } do
		if C.MonsterFamily(k) ~= "Slime" then slimes = false end
	end
	check(slimes, "every slime (Prince, Flower, King, Pumpkin) is the Slime family", "")
	check(C.MonsterFamily("GoblinBrute") == "Goblin" and C.MonsterFamily("BatGoblin") == "Goblin" and C.MonsterFamily("CaptainClatter") == "Skeleton"
		and C.MonsterFamily("HermitCrab") == "CoralCrab" and C.MonsterFamily("CaveBat") == "CaveBat",
		"other families: the table, else the quest kind", "")
	check(C.MonsterFamily("Nope") == nil and C.MonsterFamily(nil) == nil and C.MonsterFamily(5) == nil, "an unknown kind has no family", "")
	local fams = {}
	for _, f in R.Family do fams[f] = true end
	local named = true
	for f in fams do
		if type(R.Text.Names[f]) ~= "string" then named = false end
	end
	check(named, "every family the table makes has a name", "")
	check(type(R.Text.Stage) == "string" and select(2, string.gsub(R.Text.Stage, "%%s", "")) == 2, "the stage line takes (family, stage)", R.Text.Stage)
	check(R.InfoEvery == 1, "TamerInfo at most once a second", "")
end)

------------------------------------------------------------------ points
runGroup("points", function()
	local w = tWorld()
	local p, d = player(w, 1)
	local info0 = fired(w, "TamerInfo", p)
	check(#info0 == 1 and count(info0[1].Pts) == 0 and table.concat(info0[1].Stages, ",") == "50,150,400,1000,2500",
		"the tamer's join: one TamerInfo (no points yet, the stages)", show(info0[1]))
	kill(w, p, "Slime")
	kill(w, p, "BigSlime")
	kill(w, p, "Goblin")
	check(d.Research.Pts.Slime == 2 and d.Research.Pts.Goblin == 1 and count(d.Research.Pts) == 2,
		"1 point a paid kill, in the monster's family (the Prince counts for Slime)", show(d.Research.Pts))
	kill(w, p, "Slime", { Minor = true })
	check(d.Research.Pts.Slime == 2, "a free rider's share (MinorShare) gives none", show(d.Research.Pts))
	kill(w, p, "Nope")
	check(d.Research.Pts.Nope == nil and count(d.Research.Pts) == 2, "an unknown kind gives none", "")
	kill(w, p, "Slime", { Auto = true })
	check(d.Research.Pts.Slime == 3, "auto combat kills count (the pet fights for this class)", "")
	local k, kd = player(w, 2, "Warrior", "Halo")
	local h, hd = player(w, 3, "Archer", "Halo")
	local m, md = player(w, 4, "Mage", "Neutral")
	local n, nd = player(w, 5, "Archer", "Neutral", { ClassChosen = false })
	for _, q in { k, h, m, n } do kill(w, q, "Slime") end
	check(count(kd.Research.Pts) == 0 and count(hd.Research.Pts) == 0 and count(md.Research.Pts) == 0 and count(nd.Research.Pts) == 0,
		"only the tamer researches (not a Halo archer, an alchemist, or a class not picked yet)", "")
	check(#fired(w, "TamerInfo", k) == 0 and #fired(w, "TamerInfo", h) == 0 and #fired(w, "TamerInfo", n) == 0, "no TamerInfo for others", "")
	kill(w, nil, "Slime")
	kill(w, p, nil)
	w.Reg.MonsterService.MonsterKilled:Fire(p, "Slime")
	check(d.Research.Pts.Slime == 3 and #w.Warnings == 0, "junk kills are ignored without an error", show(w.Warnings))
	-- the save is broken: repaired on the spot
	d.Research = { Pts = "x" }
	kill(w, p, "Slime")
	check(type(d.Research.Pts) == "table" and d.Research.Pts.Slime == 1 and type(d.Research.Sum) == "table", "a broken Research table is repaired, then counted", show(d.Research))
	check(w.T.Points(p, "Slime") == 1 and w.T.Points(p, "Goblin") == 0 and w.T.Points(p, nil) == 0 and w.T.Stage(p, "Slime") == 0,
		"Points / Stage read the save", "")
end)

------------------------------------------------------------------ caps
runGroup("caps", function()
	local w = tWorld()
	local pts = {}
	for i = 1, 64 do pts["K" .. i] = 1 end
	local p, d = player(w, 1, nil, nil, { Research = { Pts = pts, Sum = {} } })
	kill(w, p, "Slime")
	check(d.Research.Pts.Slime == nil and count(d.Research.Pts) == 64, "a new family past MaxKeys (64) is not counted", tostring(count(d.Research.Pts)))
	d.Research.Pts.K1 = nil
	kill(w, p, "Slime")
	check(d.Research.Pts.Slime == 1, "... with room again, it is", "")
	local q, qd = player(w, 2, nil, nil, { Research = { Pts = { Slime = 10000000 }, Sum = {} } })
	kill(w, q, "Slime")
	check(qd.Research.Pts.Slime == 10000000, "a counter never goes past MaxCount", tostring(qd.Research.Pts.Slime))
end)

------------------------------------------------------------------ stages
runGroup("stages", function()
	local w = tWorld()
	local p, d = player(w, 1, nil, nil, { Research = { Pts = { Slime = 48, Goblin = 49, CaveBat = 49 }, Sum = {} } })
	local from = #w.Notices
	kill(w, p, "Slime")
	check(#noticesFor(w, p, from) == 0, "49 points: no stage yet", "")
	local sent = #fired(w, "TamerInfo", p)
	kill(w, p, "Slime")
	local ns = noticesFor(w, p, from)
	check(#ns == 1 and ns[1].Key == "Config.Research.Text.Stage" and ns[1].Kind == "reward" and type(ns[1].Args) == "table"
		and type(ns[1].Args[1]) == "table" and ns[1].Args[1].Key == "Config.Research.Text.Names.Slime" and ns[1].Args[2] == "1",
		"50 points: one stage line (key; args = the family's name key, \"1\")", ns[1] and show(ns[1].Args) or "")
	local info = last(fired(w, "TamerInfo", p))
	check(#fired(w, "TamerInfo", p) == sent + 1 and info.Stage.Slime == 1 and info.Pts.Slime == 50, "a new stage: TamerInfo at once", show(info))
	kill(w, p, "CaveBat")
	check(#noticesFor(w, p, from) == 1 and d.Research.Pts.CaveBat == 50, "a family without a name reaches its stage without a line", "")
	local got = {}
	w.T.StageUp:Connect(function(pl, fam, s) table.insert(got, { pl, fam, s }) end)
	kill(w, p, "Goblin")
	check(#got == 1 and got[1][1] == p and got[1][2] == "Goblin" and got[1][3] == 1, "StageUp(player, family, stage) fires", tostring(#got))
	d.Research.Pts.Slime = 149
	kill(w, p, "SlimeKing")
	local ns2 = noticesFor(w, p, from)
	check(ns2[#ns2].Args[2] == "2", "150 points: stage 2 (the summon stage)", show(ns2[#ns2].Args))
end)

------------------------------------------------------------------ TamerInfo pace
runGroup("pace", function()
	local w = tWorld()
	local p = player(w, 1)
	local n0 = #fired(w, "TamerInfo", p)
	w:Advance(2)
	kill(w, p, "Slime")
	check(#fired(w, "TamerInfo", p) == n0 + 1, "the first change after a quiet second: TamerInfo at once", "")
	kill(w, p, "Slime")
	kill(w, p, "Slime")
	check(#fired(w, "TamerInfo", p) == n0 + 1, "more within the second: they wait", "")
	w:Advance(1)
	local info = last(fired(w, "TamerInfo", p))
	check(#fired(w, "TamerInfo", p) == n0 + 2 and info.Pts.Slime == 3, "... then one TamerInfo with all of them", show(info))
	w:Advance(5)
	check(#fired(w, "TamerInfo", p) == n0 + 2, "nothing more without a change", "")
	kill(w, p, "Slime")
	w:Leave(p)
	w:Advance(2)
	check(#w.Warnings == 0, "a leave forgets the wait without an error", show(w.Warnings))
end)

------------------------------------------------------------------ summons
runGroup("summons", function()
	local w = tWorld()
	local p, d = player(w, 1)
	check(w.T.AddSummon(p, "Slime") == true and d.Research.Sum.Slime == 1, "AddSummon: Sum + 1", show(d.Research.Sum))
	w.T.AddSummon(p, "Slime")
	check(d.Research.Sum.Slime == 2 and last(fired(w, "TamerInfo", p)).Sum.Slime == 2, "... and TamerInfo shows it", "")
	check(w.T.AddSummon(p, nil) == false and w.T.AddSummon(nil, "Slime") == false, "junk: false", "")
end)

------------------------------------------------------------------ switch off
runGroup("off", function()
	local w = tWorld({ Off = true })
	local p, d = player(w, 1)
	kill(w, p, "Slime")
	check(count(d.Research.Pts) == 0 and #fired(w, "TamerInfo", p) == 0, "switch off: no points, no TamerInfo", "")
end)

------------------------------------------------------------------ PetService: summons (§2, §4)
runGroup("summon pets", function()
	local w = tWorld()
	local p, d = player(w, 1)
	check(d.Pets.List.P1 and d.Pets.List.P1.Sp == "BabySlime" and d.Pets.Equipped[1] == "P1" and p:GetAttribute("PetRoll") == 0,
		"the tamer's own baby slime (no roll: PetRoll 0)", "")
	local granted = {}
	w.P.PetGranted:Connect(function(pl, uid, sp) table.insert(granted, { uid, sp }) end)
	local uid = w.P.SummonPet(p, "BabySlime", { Spd = 7 })
	local s = uid and d.Pets.List[uid]
	check(uid == "P2" and s and s.Sp == "BabySlime" and s.Lv == 1 and s.XP == 0 and s.Bound == true and s.Roll and s.Roll.Spd == 7
		and s.Name == "" and s.Lean == "", "a second baby slime: a new Bound pet with Roll { Spd = 7 }", s and show(s) or "nil")
	check(#granted == 1 and granted[1][1] == "P2" and granted[1][2] == "BabySlime", "PetGranted(player, uid, species)", "")
	check(d.Pets.Equipped[1] == "P1", "the pet that follows stays (a summon comes out only when none does)", "")
	local list = last(fired(w, "PetList", p))
	local row = nil
	for _, r in list.List do if r.Uid == "P2" then row = r end end
	check(row and row.Roll and row.Roll.Spd == 7, "PetList rows carry Roll (the window's stats)", row and show(row.Roll) or "")
	for _, bad in { { Spd = 11 }, { Spd = 4 }, { Spd = 7.5 }, { Spd = 7, X = 1 }, { Spd = "7" }, "x" } do
		check(w.P.SummonPet(p, "BabySlime", bad) == nil, "a bad roll: no pet (the server never makes a value up)", show(bad))
	end
	check(w.P.SummonPet(p, "BabySlime", nil) == nil and w.P.SummonPet(p, "Dragon", { Spd = 6 }) == nil and w.P.SummonPet(nil, "BabySlime", { Spd = 6 }) == nil,
		"no roll / an unknown species / no player: no pet", "")
	check(count(d.Pets.List) == 2, "still two pets", tostring(count(d.Pets.List)))
	-- equip the summoned one: PetRoll = its Spd before the speed refresh
	w.Gap = 1
	w:Remote("EquipPet", p, "P2")
	check(d.Pets.Equipped[1] == "P2" and p:GetAttribute("PetRoll") == 7 and last(w.Speeds).P == p and last(w.Speeds).Roll == 7,
		"the summon follows: PetRoll 7, then the speed refresh", show({ p:GetAttribute("PetRoll") }))
	-- a player with no pet out: the summon comes out
	local k, dk = player(w, 2, "Warrior", "Halo")
	check(w.P.SummonPet(k, "BabySlime", { Spd = 5 }) == "P1" and dk.Pets.Equipped[1] == "P1" and k:GetAttribute("PetRoll") == 5,
		"nothing follows: the summon comes out", "")
	-- the 64 cap, checked before a pet goes in
	local list64 = {}
	for i = 1, 63 do list64["Q" .. i] = { Sp = "BabySlime", Lv = 1, XP = 0, Name = "", Lean = "", Bound = true } end
	local f, df = player(w, 3, "Warrior", "Halo", { Pets = { List = list64, Equipped = {}, Next = 1, Away = false } })
	check(w.P.HasRoom(f) == true, "63 pets: room", "")
	check(w.P.SummonPet(f, "BabySlime", { Spd = 6 }) ~= nil and count(df.Pets.List) == 64, "the 64th goes in", tostring(count(df.Pets.List)))
	check(w.P.HasRoom(f) == false and w.P.SummonPet(f, "BabySlime", { Spd = 6 }) == nil and count(df.Pets.List) == 64,
		"64 pets: no room, no 65th (Sanitize would drop some pet at the next join)", tostring(count(df.Pets.List)))
	check(w.P.GetPet(p, "P2").Lv == 1 and w.P.GetPet(p, "P2").Sp == "BabySlime" and w.P.GetPet(p, "Nope") == nil and w.P.GetPet(p, nil) == nil
		and w.P.GetPet(k, "P2") == nil, "GetPet: my pet only", "")
end)

------------------------------------------------------------------ PetService.AddPetXP (a treat's XP, the kill XP's levels)
runGroup("pet xp", function()
	local w = tWorld()
	local p, d = player(w, 1)
	local uid = w.P.SummonPet(p, "BabySlime", { Spd = 6 })
	local sent = #fired(w, "PetList", p)
	w:Advance(5)
	check(w.P.AddPetXP(p, uid, 10) == 1 and d.Pets.List[uid].XP == 10 and #fired(w, "PetList", p) == sent + 1,
		"10 XP on a pet that does not follow: no level yet, the list goes", "")
	check(w.P.AddPetXP(p, uid, 20) == 2 and d.Pets.List[uid].Lv == 2 and d.Pets.List[uid].XP == 15, "10 + 20 = 30: Lv2 (15) with 15 over", show(d.Pets.List[uid]))
	check(p:GetAttribute("PetLv") == 1, "the follower's PetLv is not the summon's", "")
	check(w.P.AddPetXP(p, "P1", 15) == 2 and p:GetAttribute("PetLv") == 2, "the follower levels up: published (PetLv 2)", "")
	for _, bad in { 0, -5, 1.5, 0 / 0, math.huge, "20" } do
		local before = d.Pets.List[uid].XP
		check(w.P.AddPetXP(p, uid, bad) == nil and d.Pets.List[uid].XP == before, "a bad amount: nil, nothing changes", tostring(bad))
	end
	check(w.P.AddPetXP(p, "Nope", 5) == nil and w.P.AddPetXP(nil, uid, 5) == nil, "not my pet: nil", "")
	d.Pets.List[uid].Lv, d.Pets.List[uid].XP = 10, 0
	w:Advance(5)
	local lists = #fired(w, "PetList", p)
	check(w.P.AddPetXP(p, uid, 20) == 10 and d.Pets.List[uid].XP == 0, "MaxLv: unchanged (Lv 10, XP 0)", show(d.Pets.List[uid]))
	w:Advance(5)
	check(#fired(w, "PetList", p) == lists, "... and no list goes (nothing changed)", "")
end)

------------------------------------------------------------------ Pet Treats (FeedPet, §3)
runGroup("feed", function()
	local w = tWorld()
	local C = w.Config
	check(C.Research.Treat == "PetTreat" and C.Research.TreatXP == 20 and C.RateLimits.FeedPet == 0.5, "a treat = +20 pet XP, one a half second", "")
	local p, d = player(w, 1, nil, nil, { Items = { PetTreat = 3 } })
	local from = #w.Notices
	check(w.T.Feed(p, "P1") == "ok" and d.Items.PetTreat == 2 and d.Pets.List.P1.Lv == 2 and d.Pets.List.P1.XP == 5 and p:GetAttribute("PetLv") == 2,
		"one treat: +20 pet XP (Lv1 15 -> Lv2 with 5)", show(d.Pets.List.P1))
	local ns = noticesFor(w, p, from)
	check(#ns == 1 and ns[1].Key == "Config.Research.Text.Fed" and ns[1].Kind == "reward" and ns[1].Args[1] == "20", "the Fed line (a key, \"20\")",
		ns[1] and show(ns[1].Args) or "")
	check(w.T.Feed(p, "Nope") == "pet" and d.Items.PetTreat == 2, "not my pet: the treat stays", "")
	d.Pets.List.P1.Lv, d.Pets.List.P1.XP = 10, 0
	local f2 = #w.Notices
	check(w.T.Feed(p, "P1") == "max" and d.Items.PetTreat == 2 and noticesFor(w, p, f2)[1].Key == "Config.Research.Text.PetMax",
		"a MaxLv pet: PetMax, the treat stays", "")
	local k, dk = player(w, 2, "Warrior", "Halo", { Items = {} })
	local kid = w.P.SummonPet(k, "BabySlime", { Spd = 5 })
	local f3 = #w.Notices
	check(w.T.Feed(k, kid) == "none" and noticesFor(w, k, f3)[1].Key == "Config.Research.Text.NoTreat" and dk.Pets.List[kid].XP == 0,
		"no treat: NoTreat, no XP", "")
	dk.Items.PetTreat = 1
	check(w.T.Feed(k, kid) == "ok" and dk.Items.PetTreat == 0 and dk.Pets.List[kid].Lv == 2, "anyone with a pet feeds it (a Halo knight too)", "")
	w.Ready[k] = nil
	dk.Items.PetTreat = 1
	check(w.T.Feed(k, kid) == "state" and dk.Items.PetTreat == 1, "not ready: no", "")
	w.Ready[k] = true
	check(w.T.Feed(k, 5) == "state" and w.T.Feed(nil, kid) == "state", "junk: no", "")
	-- the remote: one argument, one feed a half second
	d.Pets.List.P1.Lv = 3
	d.Items.PetTreat = 5
	w.Gap = 1
	w:Remote("FeedPet", p, "P1", "x")
	check(d.Items.PetTreat == 5, "FeedPet with two arguments: ignored", "")
	w:Remote("FeedPet", p, "P1")
	w.Gap = 0.1
	w:Remote("FeedPet", p, "P1")
	check(d.Items.PetTreat == 4, "two within half a second: one treat", tostring(d.Items.PetTreat))
	local off = tWorld({ Off = true })
	local o, dob = player(off, 1, nil, nil, { Items = { PetTreat = 2 } })
	check(off.T.Feed(o, "P1") == "off" and dob.Items.PetTreat == 2, "switch off: no feeding", "")
end)

finish()
