-- barks_offline.luau : quality_ideas ③ monster barks (BarkService; lines_pack §2, 검수 2026-10-07). tools/test_barks.py
-- injects CONFIG_SOURCE, UTIL_SOURCE, BARK_SOURCE, MONSTER_SOURCE and MAIN_SOURCE (the CURRENT src) in front of
-- dev2_kit.luau; this file follows. BarkService runs on a MonsterService stand-in that fires Moment(rec, "Spot" | "Hit")
-- and answers GetMonstersInRadius; monster records carry a model double whose attributes are read back. The real
-- MonsterService.DamageMonster runs as a chunk cut from MONSTER_SOURCE (its locals are doubles); the Spot hooks in aiStep /
-- personalStep and the Main order lists are read from the bound sources (so a mutation of them is caught here).
-- Random draws are scripted (w.Script, front first): a roll (NextNumber) then a line pick (NextInteger 1..n).

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local K0 = C0.Barks

-- o.EditConfig(config) before BarkService loads (it reads Config.Barks once)
local function barkWorld(o)
	o = o or {}
	local w = newWorld({ EditConfig = o.EditConfig })
	local Signal = w.Util.Signal
	w.Recs = {}
	local mons = { Moment = Signal.new(), Asked = {} }
	function mons.GetMonstersInRadius(pos, radius, forPlayer)
		table.insert(mons.Asked, { Radius = radius, For = forPlayer })
		local out = {}
		for _, rec in w.Recs do
			if rec.Alive and w.Util.FlatDistance(rec.Root.Position, pos) <= radius then table.insert(out, rec) end
		end
		return out
	end
	local ps = {}
	function ps.GetReadyPlayers() return w.PlayerList end
	local env = w:Env()
	-- the idle loop's task.wait yields this coroutine; w:IdleTick resumes it after IdleEvery s
	env.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = env.task })
	local bark = execute("BarkService", BARK_SOURCE, env)
	bark.Init({ MonsterService = mons, PlayerService = ps })
	local n0 = #w.Spawned
	bark.Start()
	check(#w.Spawned == n0 + 1, "Start queues exactly one loop (the Idle roll)", #w.Spawned - n0)
	local loop = coroutine.create(w.Spawned[n0 + 1][1])
	w.Spawned = {}
	local ok0, wait0 = coroutine.resume(loop)
	assert(ok0, wait0)
	w.Wait = wait0
	function w:IdleTick()
		self:Advance(self.Config.Barks.IdleEvery)
		local ok, waitNext = coroutine.resume(loop)
		assert(ok, waitNext)
		self.Wait = waitNext
	end
	w.Mons = mons
	w.Folder = newInstance("Folder", w)
	function w:Mon(kind, opts)
		opts = opts or {}
		local model = newInstance("Model", w)
		model.Parent = w.Folder
		local root = newInstance("Part", w)
		root.Position = opts.Pos or vec(0, 0, 0)
		local def = w.Config.MonsterTypes[kind]
		local rec = { Kind = kind, Def = def, HP = opts.HP or def.HP, MaxHP = def.HP, Golden = opts.Golden == true, Alive = true,
			Model = model, Root = root, ZoneId = opts.Zone or def.Zone, _target = opts.Target }
		table.insert(w.Recs, rec)
		return rec
	end
	function w:Moment(rec, moment, script)
		self.Script = script
		mons.Moment:Fire(rec, moment)
	end
	return w
end

local function barkOf(rec) return rec.Model.Attrs.Bark end
local function inList(list, v) return type(list) == "table" and v ~= nil and table.find(list, v) ~= nil end
local function words(line)
	local n = 0
	for _ in string.gmatch(line, "%S+") do n += 1 end
	return n
end

runGroup("config", function()
	check(type(K0) == "table" and K0.Enabled == true and K0.PerMonster == 12 and K0.PerZone == 6 and K0.Show == 3
		and K0.MaxDistance == 60 and K0.LowAt == 0.3 and K0.IdleEvery == 10 and K0.IdleNear == 40,
		"Config.Barks: 12 s a monster, 6 s a zone, 3 s bubble, 60 studs, Low below 30%, Idle every 10 s within 40",
		show(K0 and { K0.PerMonster, K0.PerZone, K0.Show, K0.MaxDistance, K0.LowAt, K0.IdleEvery, K0.IdleNear }))
	local C = K0.Chance
	check(C.Spot == 0.5 and C.Hit == 0.2 and C.Low == 1 and C.Idle == 0.15, "chances: Spot 50%, Hit 20%, Low 100%, Idle 15%", show(C))
	check(table.concat(K0.Priority, ",") == "Low,Spot,Hit,Idle", "priority Low > Spot > Hit > Idle", show(K0.Priority))
	-- every monster kind has all four moments; the only other sets are Golden (any golden monster) and Goose
	local missing = {}
	for kind in C0.MonsterTypes do
		local set = K0.Lines[kind]
		for _, moment in { "Spot", "Hit", "Low", "Idle" } do
			if type(set) ~= "table" or type(set[moment]) ~= "table" or #set[moment] == 0 then
				table.insert(missing, kind .. "." .. moment)
			end
		end
	end
	check(#missing == 0, "every Config.MonsterTypes kind has Spot / Hit / Low / Idle lines", show(missing))
	local stray = {}
	for kind in K0.Lines do
		if kind ~= "Golden" and kind ~= "Goose" and C0.MonsterTypes[kind] == nil then table.insert(stray, kind) end
	end
	check(#stray == 0 and K0.Lines.Golden ~= nil and K0.Lines.Goose ~= nil, "no lines for a kind that does not exist (Golden, Goose extra)",
		show(stray))
	local longest, bad, count = 0, {}, 0
	for _, set in K0.Lines do
		for moment, list in set do
			check(moment == "Spot" or moment == "Hit" or moment == "Low" or moment == "Idle", "a known moment: " .. tostring(moment), moment)
			for _, line in list do
				count += 1
				longest = math.max(longest, words(line))
				local low = string.lower(line)
				for _, word in { "kill", "die", "dead", "blood", "scary" } do
					if string.find(low, word, 1, true) then table.insert(bad, line) end
				end
				if string.find(line, "...", 1, true) or string.find(line, "[\128-\255]") and not string.find(line, "…", 1, true) then
					table.insert(bad, line)
				end
			end
		end
	end
	check(count >= 60 and longest <= 8, "lines_pack §2-2 pasted (60+ lines), each 8 words or fewer", show({ count, longest }))
	check(#bad == 0, "no kill / die / dead / blood / scary, the one-glyph ellipsis only", show(bad))
	check(K0.Lines.Slime.Spot[1] == "Blub?" and K0.Lines.Golden.Spot[1] == "So much sparkle! Not sharing!"
		and K0.Lines.Golden.Low[1] == "Okay, okay! Share the sparkle!" and K0.Lines.Goblin.Low[1] == "Wait… why do we grab again?",
		"lines as written (lines_pack §2-2)", show({ K0.Lines.Slime.Spot[1], K0.Lines.Golden.Spot[1] }))
end)

runGroup("spot and hit", function()
	local w = barkWorld()
	local slime = w:Mon("Slime")
	w:Moment(slime, "Spot", { 0.1, 0 }) -- the roll passes (0.1 < 0.5), then the first line
	check(barkOf(slime) == "Blub?" and slime.Model.Attrs.BarkAt == w.Time, "a slime spots you: 'Blub?' with BarkAt = server time",
		show(slime.Model.Attrs))
	-- the same monster within 12 s says nothing, and a blocked moment rolls nothing
	w:Advance(11)
	slime.Model.Attrs.Bark = nil
	w:Moment(slime, "Hit", { 0, 0 })
	check(barkOf(slime) == nil and #w.Script == 2, "the same monster within 12 s says nothing (no roll used)", show({ barkOf(slime), #w.Script }))
	w:Advance(1)
	w:Moment(slime, "Hit", { 0.1, 0 })
	check(inList(K0.Lines.Slime.Hit, barkOf(slime)), "after 12 s it speaks again (a Hit line)", barkOf(slime))
	-- another monster in the same zone within 6 s: dropped; at 6 s: speaks
	local king = w:Mon("BigSlime")
	w:Advance(5)
	w:Moment(king, "Spot", { 0, 0 })
	check(barkOf(king) == nil and #w.Script == 2, "another monster of the zone within 6 s says nothing", barkOf(king))
	w:Advance(1)
	w:Moment(king, "Spot", { 0, 0 })
	check(inList(K0.Lines.BigSlime.Spot, barkOf(king)), "at 6 s the King Slime speaks", barkOf(king))
	-- other zones keep their own clock
	local gob = w:Mon("Goblin")
	w:Moment(gob, "Spot", { 0.49, 0 })
	check(inList(K0.Lines.Goblin.Spot, barkOf(gob)), "a goblin in the woods speaks at once (zones are separate), roll 0.49 < 0.5",
		barkOf(gob))
	-- the rolls: Spot passes below 0.5, Hit below 0.2 (a roll equal to the chance stays quiet)
	local s2 = w:Mon("Skeleton")
	w:Moment(s2, "Spot", { 0.5, 0 })
	check(barkOf(s2) == nil and #w.Script == 1, "a Spot roll of exactly 0.5 says nothing (one draw used)", show({ barkOf(s2), #w.Script }))
	w:Moment(s2, "Hit", { 0.2, 0 })
	check(barkOf(s2) == nil, "a Hit roll of exactly 0.2 says nothing", barkOf(s2))
	w:Moment(s2, "Hit", { 0.19, 0 })
	check(inList(K0.Lines.Skeleton.Hit, barkOf(s2)), "a Hit roll of 0.19 speaks", barkOf(s2))
	-- unknown moments and broken records are ignored
	local s3 = w:Mon("SkeletonKnight")
	w:Advance(13)
	w:Moment(s3, "Wave", { 0, 0 })
	w:Moment({ Kind = "Slime" }, "Spot", { 0, 0 })
	w:Moment(nil, "Hit", { 0, 0 })
	check(barkOf(s3) == nil, "an unknown moment or a record without a model says nothing (no error)", barkOf(s3))
	s3.Alive = false
	w:Moment(s3, "Spot", { 0, 0 })
	check(barkOf(s3) == nil, "a dead monster says nothing", barkOf(s3))
end)

runGroup("low", function()
	local w = barkWorld()
	-- below 30%: the Low line on the next hit, no roll (Low is 100%)
	local brute = w:Mon("GoblinBrute")
	brute.HP = brute.MaxHP * 0.29
	w:Moment(brute, "Hit", { 0 })
	check(barkOf(brute) == K0.Lines.GoblinBrute.Low[1] and #w.Script == 0, "a hit below 30%: the Low line (only the line pick drawn)",
		show({ barkOf(brute), #w.Script }))
	-- once a life: the next lucky hit says a Hit line
	w:Advance(12)
	w:Moment(brute, "Hit", { 0.1, 0 })
	check(inList(K0.Lines.GoblinBrute.Hit, barkOf(brute)), "Low once a life: the next lucky hit says a Hit line", barkOf(brute))
	-- exactly 30% is not low
	local s = w:Mon("Skeleton")
	s.HP = s.MaxHP * 0.3
	w:Moment(s, "Hit", { 0.1, 0 })
	check(inList(K0.Lines.Skeleton.Hit, barkOf(s)), "exactly 30% HP is not low (a Hit line)", barkOf(s))
	-- a Low blocked by a cooldown tries again at the next hit
	local s2 = w:Mon("Skeleton")
	s2.HP = s2.MaxHP * 0.1
	w:Advance(2)
	w:Moment(s2, "Hit", { 0 }) -- the ruins zone spoke 2 s ago
	check(barkOf(s2) == nil, "a Low blocked by the zone's 6 s says nothing", barkOf(s2))
	w:Advance(4)
	w:Moment(s2, "Hit", { 0 })
	check(barkOf(s2) == K0.Lines.Skeleton.Low[1], "the next hit after the cooldown says the Low line", barkOf(s2))
	-- a dead monster (HP 0) is never low
	local s3 = w:Mon("Slime")
	s3.HP = 0
	w:Moment(s3, "Hit", { 0.1, 0 })
	check(inList(K0.Lines.Slime.Hit, barkOf(s3)), "HP 0 (the killing hit is not a Hit moment anyway) is not 'low'", barkOf(s3))
end)

runGroup("golden and fallback", function()
	local w = barkWorld({ EditConfig = function(c)
		c.Barks.Lines.BatGoblin = nil -- a kind without its own lines: its quest kind's (Goblin)
		c.Barks.Lines.Skeleton = nil -- no lines and no QuestAs: silent
		c.Barks.Lines.Golden.Idle = nil -- a moment Golden lacks: the kind's own lines
	end })
	local gold = w:Mon("Slime", { Golden = true })
	w:Moment(gold, "Spot", { 0.1, 0 })
	check(barkOf(gold) == "So much sparkle! Not sharing!", "a golden slime: 'So much sparkle! Not sharing!'", barkOf(gold))
	local gold2 = w:Mon("Goblin", { Golden = true })
	gold2.HP = gold2.MaxHP * 0.2
	w:Moment(gold2, "Hit", { 0 })
	check(barkOf(gold2) == "Okay, okay! Share the sparkle!", "a golden goblin low on HP: 'Share the sparkle!'", barkOf(gold2))
	local bat = w:Mon("BatGoblin")
	w:Advance(6)
	w:Moment(bat, "Spot", { 0.1, 0 })
	check(inList(K0.Lines.Goblin.Spot, barkOf(bat)), "a bat goblin without lines says a goblin line (Config.QuestKind)", barkOf(bat))
	local sk = w:Mon("Skeleton")
	w:Moment(sk, "Spot", { 0.1, 0 })
	check(barkOf(sk) == nil, "a kind with no lines and no QuestAs stays quiet", barkOf(sk))
	-- golden idle (Golden has no Idle here): the slime's own Idle line
	local p = w:NewPlayer(1, {})
	local char = newInstance("Model", w)
	char.Parent = w.Folder
	local root = newInstance("Part", w)
	root.Name, root.Position = "HumanoidRootPart", vec(0, 0, 0)
	root.Parent = char
	p.Character = char
	local gold3 = w:Mon("Slime", { Golden = true, Zone = "Elsewhere", Pos = vec(5, 0, 0) })
	gold.Alive, gold2.Alive, bat.Alive, sk.Alive = false, false, false, false
	w.Script = { 0.1, 0 }
	w:IdleTick()
	check(inList(K0.Lines.Slime.Idle, barkOf(gold3)), "a golden slime's Idle without Golden.Idle: the slime's own", barkOf(gold3))
end)

runGroup("no repeats", function()
	local w = barkWorld()
	local same, last, seen = 0, nil, {}
	for i = 1, 12 do
		local m = w:Mon("BigSlime", { Zone = "Zone" .. i })
		w:Moment(m, "Spot", { 0, 0 }) -- the pick draws line 1 every time
		if barkOf(m) == last then same += 1 end
		last = barkOf(m)
		seen[last or "?"] = true
	end
	check(same == 0 and seen[K0.Lines.BigSlime.Spot[1]] and seen[K0.Lines.BigSlime.Spot[2]],
		"a King Slime's Spot line never repeats back to back (both lines used)", show({ same, seen }))
	-- two lines take turns (Slime Hit)
	local a, b = w:Mon("Slime", { Zone = "A" }), w:Mon("Slime", { Zone = "B" })
	w:Moment(a, "Hit", { 0, 0 })
	w:Moment(b, "Hit", { 0, 0 })
	check(barkOf(a) == K0.Lines.Slime.Hit[1] and barkOf(b) == K0.Lines.Slime.Hit[2], "Slime Hit alternates its two lines", show({ barkOf(a), barkOf(b) }))
end)

runGroup("idle", function()
	local w = barkWorld()
	local p = w:NewPlayer(1, {})
	local char = newInstance("Model", w)
	char.Parent = w.Folder
	local root = newInstance("Part", w)
	root.Name, root.Position = "HumanoidRootPart", vec(0, 0, 0)
	root.Parent = char
	p.Character = char
	check(w.Wait == K0.IdleEvery, "the Idle loop waits IdleEvery (10 s)", w.Wait)
	local near = w:Mon("Skeleton", { Pos = vec(20, 0, 0), Zone = "Z1" })
	local far = w:Mon("Skeleton", { Pos = vec(90, 0, 0), Zone = "Z2" })
	local busy = w:Mon("Skeleton", { Pos = vec(10, 0, 0), Zone = "Z3", Target = p })
	w.Script = { 0.1, 0 }
	w:IdleTick()
	check(inList(K0.Lines.Skeleton.Idle, barkOf(near)), "a skeleton 20 studs away with no target: an Idle line", barkOf(near))
	check(barkOf(far) == nil and barkOf(busy) == nil, "90 studs away or chasing someone: no Idle line", show({ barkOf(far), barkOf(busy) }))
	local asked = w.Mons.Asked[#w.Mons.Asked]
	check(asked and asked.Radius == K0.IdleNear and asked.For == p, "asks MonsterService for the player's monsters within IdleNear",
		show(asked and { asked.Radius, asked.For == p }))
	-- the Idle roll: 15%
	local near2 = w:Mon("Slime", { Pos = vec(-10, 0, 0), Zone = "Z4" })
	near.Alive = false
	w.Script = { 0.15 }
	w:IdleTick()
	check(barkOf(near2) == nil, "an Idle roll of exactly 0.15 says nothing", barkOf(near2))
	w.Script = { 0.14, 0 }
	w:IdleTick()
	check(inList(K0.Lines.Slime.Idle, barkOf(near2)), "an Idle roll of 0.14 speaks", barkOf(near2))
	-- two players next to one monster: it rolls once a tick
	local p2 = w:NewPlayer(2, {})
	local char2 = newInstance("Model", w)
	char2.Parent = w.Folder
	local root2 = newInstance("Part", w)
	root2.Name, root2.Position = "HumanoidRootPart", vec(-12, 0, 0)
	root2.Parent = char2
	p2.Character = char2
	local lone = w:Mon("Goblin", { Pos = vec(-11, 0, 0), Zone = "Z5" })
	near2.Alive = false
	w.Script = { 0.9, 0.0, 0 }
	w:IdleTick()
	check(barkOf(lone) == nil and #w.Script == 2, "two players near one monster: one Idle roll a tick", show({ barkOf(lone), #w.Script }))
end)

runGroup("off", function()
	local w = barkWorld({ EditConfig = function(c) c.Barks.Enabled = false end })
	local slime = w:Mon("Slime")
	w:Moment(slime, "Spot", { 0, 0 })
	w:Moment(slime, "Hit", { 0, 0 })
	check(barkOf(slime) == nil and #w.Script == 2, "Enabled = false: nothing, no roll", show({ barkOf(slime), #w.Script }))
end)

runGroup("monster service hooks", function()
	local src = MONSTER_SOURCE
	local function block(start)
		local a = string.find(src, start, 1, true)
		local b = a and string.find(src, "\nend\n", a, true)
		return a and b and string.sub(src, a, b + 4) or ""
	end
	check(string.find(src, "\nMonsterService.Moment = Util.Signal.new()\n", 1, true) ~= nil, "MonsterService.Moment is a top-level signal")
	-- Spot: aiStep, only when the target changes (a new target)
	local ai = block("local function aiStep(")
	check(string.find(ai, "if rec._target ~= best.Player then\n\t\t\trec._chaseStuck = 0\n\t\t\tMonsterService.Moment:Fire(rec, \"Spot\")",
		1, true) ~= nil, "aiStep fires Spot when a monster picks a new target", #ai)
	local _, spots = string.gsub(ai, "Moment:Fire", "")
	check(spots == 1, "aiStep fires one moment only", spots)
	-- Spot: a personal monster once, when it first goes for its owner (the tutorial golden slime)
	local ps = block("local function personalStep(")
	check(string.find(ps, "if d <= PERSONAL_FOLLOW_RADIUS and not rec._spotted then\n\t\trec._spotted = true\n\t\tMonsterService.Moment:Fire(rec, \"Spot\")",
		1, true) ~= nil, "personalStep fires Spot once (first time near its owner)", #ps)
	-- Hit: the real DamageMonster (a chunk; its locals are doubles)
	local dm = block("function MonsterService.DamageMonster(")
	check(#dm > 0, "DamageMonster found", #dm)
	local w = newWorld({})
	local MS = { Moment = w.Util.Signal.new() }
	local fired, killed = {}, {}
	MS.Moment:Connect(function(rec, moment) table.insert(fired, { Rec = rec, Moment = moment }) end)
	local env = w:Env()
	local chunk = "local MonsterService, updateBar, markHurt, warnThrottled, zoneIdOf, killRecord = ...\n" .. dm .. "\nreturn MonsterService"
	execute("MonsterService.DamageMonster", chunk, env, MS, function() end, function() end, function() end,
		function(p) return p and p.Zone end, function(rec) table.insert(killed, rec); rec.Alive = false end)
	local hitter = { Zone = "SlimeMeadow" }
	local function rec(hp, owner)
		return { Alive = true, HP = hp, MaxHP = 10, ZoneId = "SlimeMeadow", Owner = owner, _contributors = {}, _hits = {}, _dmg = {} }
	end
	local r1 = rec(10)
	MS.DamageMonster(r1, 4, hitter)
	check(#fired == 1 and fired[1].Rec == r1 and fired[1].Moment == "Hit", "a hit that leaves it alive fires Hit", show(fired[1]))
	local r2 = rec(3)
	MS.DamageMonster(r2, 4, hitter)
	check(#fired == 1 and killed[1] == r2, "a killing hit fires no Hit (the pop instead)", #fired)
	local r3 = rec(10, { Zone = "SlimeMeadow" })
	MS.DamageMonster(r3, 4, hitter)
	local r4 = rec(10)
	MS.DamageMonster(r4, 4, { Zone = "GoblinWoods" })
	check(#fired == 1, "a refused hit (someone else's personal monster, a hitter outside the zone) fires nothing", #fired)
	-- the order lists: BarkService loads after MonsterService and starts after it (it connects to Moment in Start)
	local function list(name)
		local a = string.find(MAIN_SOURCE, "local " .. name .. " = {", 1, true)
		local b = a and string.find(MAIN_SOURCE, "\n}", a, true)
		return a and b and string.sub(MAIN_SOURCE, a, b) or ""
	end
	local init, start = list("INIT_ORDER"), list("START_ORDER")
	local iM, iB = string.find(init, "\"MonsterService\"", 1, true), string.find(init, "\"BarkService\"", 1, true)
	local sM, sB = string.find(start, "\"MonsterService\"", 1, true), string.find(start, "\"BarkService\"", 1, true)
	check(iM and iB and iB > iM and sM and sB and sB > sM, "Main: BarkService in INIT_ORDER and START_ORDER after MonsterService",
		show({ iM, iB, sM, sB }))
	local sP = string.find(start, "\"PlayerService\"", 1, true)
	check(sP and sB and sP > sB, "Main: PlayerService still starts last", show({ sB, sP }))
end)

finish()
