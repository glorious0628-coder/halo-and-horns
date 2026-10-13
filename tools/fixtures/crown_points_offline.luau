-- crown_points_offline.luau : gameplay_plan 2-A #4 / #5 (A23-135 / A23-137; 게임성 개발 2, 2026-10-13). tools/test_crown_points.py
-- binds CONFIG_SOURCE, UTIL_SOURCE, WAR_SOURCE, HUNT_SOURCE and STORY_SOURCE in front of dev2_kit.luau + dev3_world.luau; this
-- file follows. The REAL WarService (crown points: kill units -> whole personal points, the pool's fraction, the PvP KO cap,
-- the chest and one-side targets, PersonalAdded), the REAL HuntFameService (Honor / Infamy from own-level hunting) and the
-- REAL StoryQuestService.EventAmount (crown-point steps count PersonalAdded). Doubles: Lighting / TweenService / NumberValue
-- (the sky code runs but is not checked here), FactionService (GetFaction / GetCounts), PvPService (PlayerKO, ScalePoints),
-- PlayerService.GrantFame. The war loop is stepped by hand (w:Tick).

local function crownWorld(o)
	o = o or {}
	local w = dev3World(o)
	local Signal = w.Util.Signal
	local C = w.Config
	-- the sky's engine doubles
	local lighting = newInstance("Lighting", w)
	lighting.ClockTime = 14
	w.Services.Lighting = lighting
	w.Services.TweenService = { Create = function(_, inst, info, goal)
		return { Play = function() end, Cancel = function() end, Inst = inst, Goal = goal }
	end }
	-- the registry
	w.Counts = o.Counts or { 1, 1 }
	w.Reg.FactionService.GetFaction = function(p) return p:GetAttribute("Faction") or "None" end
	w.Reg.FactionService.GetCounts = function() return w.Counts[1], w.Counts[2] end
	w.Reg.PvPService = { PlayerKO = Signal.new(), ScalePoints = function(points, mult) return points * mult end }
	w.Reg.MonsterService.MonsterKilled = w.Reg.MonsterService.MonsterKilled or Signal.new()
	w.Fame = {}
	function w.Reg.PlayerService.GrantFame(p, stat, n, ctx)
		table.insert(w.Fame, { P = p, Stat = stat, N = n, Ctx = ctx })
		w.PS.AddStat(p, stat, n)
	end
	local function load(name, src)
		local env = w:Env()
		env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
		local ws = type(env.workspace) == "table" and env.workspace or {}
		env.workspace = setmetatable({ Terrain = newInstance("Terrain", w) }, { __index = ws })
		local inst = env.Instance
		env.Instance = { new = function(cn)
			local x = inst.new(cn)
			if cn == "NumberValue" then x.Changed = Signal.new() end
			return x
		end }
		local m = execute(name, src, env)
		w.Reg[name] = m
		return m
	end
	w.War = load("WarService", WAR_SOURCE)
	w.Hunt = load("HuntFameService", HUNT_SOURCE)
	w.Story = load("StoryQuestService", STORY_SOURCE) -- EventAmount only (never Init / Start here)
	w.War.Init(w.Reg)
	w.Hunt.Init(w.Reg)
	w.War.Start()
	w.Hunt.Start()
	w:StartLoops()
	w.Added = {}
	w.War.PersonalAdded:Connect(function(p, n, src) table.insert(w.Added, { P = p, N = n, Src = src }) end)
	-- a monster kill as MonsterService fires it (per contributor)
	function w:Kill(p, opts)
		opts = opts or {}
		local units = opts.Golden and C.War.GoldenPoints or C.War.MonsterPoints
		self.Reg.MonsterService.MonsterKilled:Fire(p, { Kind = opts.Kind or "Slime", ZoneId = opts.Zone or "SlimeMeadow",
			Golden = opts.Golden == true, WarPoints = opts.Personal and 0 or units, WarShare = opts.Share or units,
			Personal = opts.Personal == true, Practice = opts.Practice })
	end
	function w:Kills(p, n, opts) for _ = 1, n do self:Kill(p, opts) end end
	function w:Round() -- past the round end, one tick
		self:Tick(C.War.RoundSeconds + 1)
	end
	return w
end

local function hero(w, id, faction, level)
	return w:Arrive(id, { Data = { Faction = faction or "Halo", Class = "Warrior", ClassChosen = true, Level = level or 5 } })
end

local function gs(w, k) return w.GameState:GetAttribute(k) end

-- a copy without the player objects (show() of a player overflows the stack)
local function plain(rows)
	local out = {}
	for i, r in rows do
		local c = {}
		for k, v in r do if k ~= "P" then c[k] = v end end
		out[i] = c
	end
	return out
end

------------------------------------------------------------------ config
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local W = C.War
	check(W.KillsPerPoint == 100 and W.MonsterPoints == 1 and W.GoldenPoints == 5, "A23-135: 100 monsters = 1 point, golden = 5", show(W))
	check(W.PvPKOPoints == 2 and W.PvPKOPerStar == 0.5 and W.PvPKOMaxPerRound == 3, "A23-137: PvP KO 2 + 0.5 a star, 3 a round", show(W))
	check(W.SiegeTarget == 1.5 and W.ChestMinPoints == 1, "one side 1.5 a head, a chest from 1 personal point", show(W))
	check(C.Kaiju.HaloWarPoints == 30 and C.Kaiju.HornsWarPoints == 30 and C.Goose.WinWarPoints == 30, "kaiju 30 / 30, goose 30 (A23-137)",
		show({ C.Kaiju.HaloWarPoints, C.Kaiju.HornsWarPoints, C.Goose.WinWarPoints }))
	local H = C.HuntFame
	check(H.Enabled == true and H.KillsPerPoint == 100 and H.Units == 1 and H.GoldenUnits == 5 and H.Points == 1
		and C.Data.Defaults.HuntFame == 0, "hunt fame: 100 own-level monsters = 1 point, golden 5, saved from 0", show(H))
	local m21 = C.StoryQuests.Defs.M2_1.Steps[1].Obj
	local gw4 = C.StoryQuests.Defs.GW4.Steps[1].Obj
	check(m21.Type == "WarPoints" and m21.Count == 1 and gw4.Type == "WarPoints" and gw4.Count == 3, "M2_1 1 point, GW4 3 points", show({ m21, gw4 }))
	check(not string.find(C.StoryQuests.Defs.M2_1.Start, "Each monster you beat = 1 point", 1, true)
		and string.find(C.StoryQuests.Defs.M2_1.Start, "100 monsters", 1, true) ~= nil, "M2_1's start line says 100 monsters", C.StoryQuests.Defs.M2_1.Start)
	check(not string.find(C.StoryQuests.Defs.S2.Steps[1].Text, "30", 1, true), "S2 names no old point number", C.StoryQuests.Defs.S2.Steps[1].Text)
end)

------------------------------------------------------------------ kills -> whole personal points
runGroup("hunting points", function()
	local w = crownWorld()
	local p = hero(w, 1, "Halo")
	w:Kills(p, 99)
	check(p:GetAttribute("WarPoints") == 0 and #w.Added == 0 and w.War.GetKillUnits(p) == 99,
		"99 monsters: no personal point yet, no PersonalAdded (no '+1' a monster)", show({ p:GetAttribute("WarPoints"), w.War.GetKillUnits(p) }))
	w:Kill(p)
	check(p:GetAttribute("WarPoints") == 1 and #w.Added == 1 and w.Added[1].N == 1 and w.Added[1].Src == "Hunt"
		and w.War.GetKillUnits(p) == 0, "the 100th: 1 whole point, one PersonalAdded(1, Hunt)", show(plain(w.Added)))
	w:Tick(1)
	check(gs(w, "WarHaloScore") == 1, "the pool got 1 point (100 x 1/100)", gs(w, "WarHaloScore"))
	w:Kills(p, 19, { Golden = true })
	check(p:GetAttribute("WarPoints") == 1 and w.War.GetKillUnits(p) == 95, "19 golden = 95 units", w.War.GetKillUnits(p))
	w:Kill(p, { Golden = true })
	check(p:GetAttribute("WarPoints") == 2 and w.War.GetKillUnits(p) == 0, "the 20th golden: point 2", w.War.GetKillUnits(p))
	-- personal monsters give nothing; shared kills give the full personal units but a pool share
	w:Kills(p, 50, { Personal = true })
	check(w.War.GetKillUnits(p) == 0, "personal monsters: no units", w.War.GetKillUnits(p))
	w:Tick(1)
	local before = gs(w, "WarHaloScore")
	w:Kills(p, 100, { Share = 0.5 })
	w:Tick(1)
	check(p:GetAttribute("WarPoints") == 3 and w.War.GetKillUnits(p) == 0 and math.abs(gs(w, "WarHaloScore") - before - 0.5) < 0.01,
		"100 kills shared with another Knight: a full personal point, half a point to the pool",
		show({ p:GetAttribute("WarPoints"), w.War.GetKillUnits(p), before, gs(w, "WarHaloScore") }))
	-- the units carry over the round end; the round's personal points do not
	w:Kills(p, 90)
	w:Round()
	check(p:GetAttribute("WarPoints") == 0 and w.War.GetKillUnits(p) == 90, "a new round: personal 0, the 90 units carried", w.War.GetKillUnits(p))
	w:Kills(p, 10)
	check(p:GetAttribute("WarPoints") == 1, "10 more = a point in the new round", p:GetAttribute("WarPoints"))
	-- Neutral / None never score
	local n = hero(w, 2, "Neutral")
	w:Kills(n, 100)
	check((n:GetAttribute("WarPoints") or 0) == 0 and w.War.GetKillUnits(n) == 0, "Neutral: no crown points", n:GetAttribute("WarPoints"))
	-- a side switch drops the carried units
	w:Kills(p, 40)
	w.Reg.FactionService.FactionChanged:Fire(p, "Horns")
	check(w.War.GetKillUnits(p) == 0, "a side switch drops the carried units", w.War.GetKillUnits(p))
	w:Leave(p)
	check(w.War.GetKillUnits(p) == 0, "a leave forgets them", w.War.GetKillUnits(p))
end)

------------------------------------------------------------------ PvP
runGroup("pvp", function()
	local w = crownWorld()
	local k = hero(w, 1, "Halo", 20)
	local v = hero(w, 2, "Horns", 20)
	local KO = w.Reg.PvPService.PlayerKO
	KO:Fire(k, v, { Rewarded = true, VictimStars = 2 })
	check(k:GetAttribute("WarPoints") == 3 and w.Added[1].Src == "PvP" and w.Added[1].N == 3, "a KO of a 2-star: 2 + 2 x 0.5 = 3 (PvP)", show(plain(w.Added)))
	KO:Fire(k, v, { Rewarded = false, VictimStars = 5 })
	check(k:GetAttribute("WarPoints") == 3, "an unrewarded KO: nothing", k:GetAttribute("WarPoints"))
	KO:Fire(k, v, { Rewarded = true, VictimStars = 0 })
	KO:Fire(k, v, { Rewarded = true, VictimStars = 0, BoldMult = 2 })
	check(k:GetAttribute("WarPoints") == 9, "two more: 2, then 2 x 2 (bold) = 9", k:GetAttribute("WarPoints"))
	KO:Fire(k, v, { Rewarded = true, VictimStars = 4 })
	check(k:GetAttribute("WarPoints") == 9, "a 4th rewarded KO in the round scores nothing (3 a round)", k:GetAttribute("WarPoints"))
	w:Round()
	KO:Fire(k, v, { Rewarded = true, VictimStars = 0 })
	check(k:GetAttribute("WarPoints") == 2, "a new round counts KOs again", k:GetAttribute("WarPoints"))
end)

------------------------------------------------------------------ the round: chests, one side, events
runGroup("round end", function()
	local w = crownWorld({ Counts = { 1, 1 } })
	local a = hero(w, 1, "Halo", 10)
	local b = hero(w, 2, "Horns", 10)
	local c = hero(w, 3, "Halo", 10)
	w:Kills(a, 100) -- 1 personal point
	w:Kills(c, 60) -- 0 personal points
	w:Kills(b, 30)
	local n0 = #w.Gold
	w:Round()
	local paid = {}
	for i = n0 + 1, #w.Gold do paid[w.Gold[i].P] = w.Gold[i].Src end
	check(paid[a] == "War" and paid[c] == nil and paid[b] == nil, "a chest for 1 personal point; 60 / 30 kills: none", show({ paid[a], paid[c], paid[b] }))
	check(gs(w, "WarBlessing") == "Halo", "1.6 vs 0.3 a head: Halo holds the crown", gs(w, "WarBlessing"))
	-- events go to the pool only (the goose 30, the kaiju 30)
	w.War.AddFactionPoints("Horns", w.Config.Kaiju.HornsWarPoints)
	w:Tick(1)
	check(gs(w, "WarHornsScore") == 30 and (b:GetAttribute("WarPoints") or 0) == 0, "the kaiju's 30 to the Horns pool, nobody's personal", gs(w, "WarHornsScore"))
	-- one side only: the 1.5-a-head target
	local s = crownWorld({ Counts = { 2, 0 } })
	local x = hero(s, 1, "Halo", 10)
	local y = hero(s, 2, "Halo", 10)
	s:Kills(x, 200)
	s:Kills(y, 90)
	s:Round()
	check(s.GameState:GetAttribute("WarBlessing") == "None", "one side, 2.9 / 2 = 1.45 a head: under 1.5, no crown", s.GameState:GetAttribute("WarBlessing"))
	s:Kills(x, 200)
	s:Kills(y, 110)
	s:Round()
	check(s.GameState:GetAttribute("WarBlessing") == "Halo", "3.1 / 2 = 1.55 a head: the crown", s.GameState:GetAttribute("WarBlessing"))
end)

------------------------------------------------------------------ crown-point quest steps
runGroup("quests", function()
	local w = crownWorld()
	local p = hero(w, 1, "Halo")
	local obj = { Type = "WarPoints", Count = 1 }
	check(w.Story.EventAmount(p, obj, { Kind = "Kill", Info = { Kind = "Slime", ZoneId = "SlimeMeadow", WarPoints = 1 } }) == 0,
		"a kill's units never move a crown-point step", "")
	check(w.Story.EventAmount(p, obj, { Kind = "War", N = 1 }) == 1 and w.Story.EventAmount(p, obj, { Kind = "War", N = 2.5 }) == 2.5,
		"PersonalAdded's points do", "")
	check(w.Story.EventAmount(p, { Type = "Kill", Kind = "Slime", Count = 5 }, { Kind = "War", N = 1 }) == 0, "a kill step ignores crown points", "")
	check(w.Story.EventAmount(p, obj, { Kind = "War", N = -3 }) == 0, "never negative", "")
end)

------------------------------------------------------------------ Honor / Infamy from hunting (2-A #4)
runGroup("hunt fame", function()
	local w = crownWorld()
	local h, hd = hero(w, 1, "Halo", 5)
	w:Kills(h, 99)
	check(#w.Fame == 0 and hd.HuntFame == 99, "99 own-level monsters: no Honor yet, 99 saved", hd.HuntFame)
	w:Kill(h)
	check(#w.Fame == 1 and w.Fame[1].Stat == "Honor" and w.Fame[1].N == 1 and w.Fame[1].Ctx.Hunt == true and hd.HuntFame == 0
		and hd.Honor == 1, "the 100th: Honor +1 (ctx Hunt), the count back to 0", show(plain(w.Fame)))
	local lines = w:NoticesFor(h)
	check(lines[#lines] == string.format(w.Config.HuntFame.Text.Honor, 1), "one 'Honor +1 from hunting!' line", show(lines))
	w:Kills(h, 20, { Golden = true })
	check(#w.Fame == 2, "20 golden = 100 units = Honor +1", #w.Fame)
	-- Horns: Infamy; Neutral: nothing
	local r, rd = hero(w, 2, "Horns", 15)
	w:Kills(r, 100, { Zone = "GoblinWoods", Kind = "Goblin" })
	check(w.Fame[3] and w.Fame[3].Stat == "Infamy" and rd.Infamy == 1, "a Lv15 Horn in the woods: Infamy +1", show(plain({ w.Fame[3] })))
	local n, nd = hero(w, 3, "Neutral", 5)
	w:Kills(n, 150)
	check(#w.Fame == 3 and (nd.HuntFame or 0) == 0, "Neutral: nothing counted", nd.HuntFame)
	-- too low a zone counts nothing; a harder zone counts
	w:Kills(r, 50) -- meadow slimes at Lv15
	check(rd.HuntFame == 0, "a Lv15 in the meadow: nothing (far below the level)", rd.HuntFame)
	local lo, lod = hero(w, 4, "Halo", 3)
	w:Kills(lo, 7, { Zone = "GoblinWoods", Kind = "Goblin" })
	check(lod.HuntFame == 7, "a Lv3 in the woods: counts (a harder zone)", lod.HuntFame)
	w:Kills(lo, 7, { Zone = "NoSuchZone" })
	check(lod.HuntFame == 7, "an unknown zone: nothing", lod.HuntFame)
	-- personal / practice monsters: nothing
	w:Kills(lo, 5, { Personal = true })
	w:Kills(lo, 5, { Practice = true })
	check(lod.HuntFame == 7, "personal and practice monsters: nothing", lod.HuntFame)
	-- the level rule itself
	local H = w.Hunt
	check(H.Counts(1, "SlimeMeadow") and H.Counts(9, "SlimeMeadow") and not H.Counts(10, "SlimeMeadow") and H.Counts(10, "GoblinWoods")
		and not H.Counts(25, "GoblinWoods") and H.Counts(25, "SkeletonRuins") and H.Counts(5, "SkeletonRuins"),
		"own zone or harder: Lv1-9 meadow, Lv10-24 woods, Lv25+ ruins", "")
end)

runGroup("hunt fame off", function()
	local w = crownWorld({ EditConfig = function(C) C.HuntFame.Enabled = false end })
	local p, d = hero(w, 1, "Halo", 5)
	w:Kills(p, 200)
	check(#w.Fame == 0 and (d.HuntFame or 0) == 0, "HuntFame.Enabled = false: nothing", d.HuntFame)
end)

finish()
