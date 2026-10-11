-- tamer_research_offline.luau : the pet tamer's research (TamerService, 게임성 개발 3, 2026-10-12; contract
-- docs/design/tamer_server_2026-10-12.md §1). tools/test_tamer_research.py binds CONFIG_SOURCE, UTIL_SOURCE and
-- TAMER_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows. TamerService runs from source;
-- PlayerService / MonsterService are the world's doubles (MonsterKilled fired by hand).

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
	w:Service("TamerService", TAMER_SOURCE)
	w:InitStart({ "TamerService" })
	w.T = w.Reg.TamerService
	return w
end

local function player(w, id, class, faction, extra)
	local data = { Faction = faction or "Neutral", Class = class or "Archer", ClassChosen = true, Level = 5 }
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

finish()
