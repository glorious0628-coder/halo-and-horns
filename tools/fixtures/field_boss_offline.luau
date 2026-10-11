-- field_boss_offline.luau : the field bosses (FieldBossService; the King Slime A23-84 / A23-85), offline. tools/test_field_boss.py
-- puts the source bindings + dev2_kit.luau in front of this file. Only the engine and the neighbour services
-- (MonsterService SpawnEvent / RemoveEvent, PlayerService, ZoneService, AnnounceService) are doubles; Config, Util and
-- FieldBossService run from the CURRENT sources.

-- the kit's Vector3 double has no Unit
local oldIndex = vmt.__index
vmt.__index = function(v, key)
	if key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return vec(v.X / m, v.Y / m, v.Z / m)
	end
	return oldIndex(v, key)
end

local function near(a, b, eps)
	return typeofDouble(a) == "Vector3" and typeofDouble(b) == "Vector3" and math.abs(a.X - b.X) < (eps or 1e-6)
		and math.abs(a.Y - b.Y) < (eps or 1e-6) and math.abs(a.Z - b.Z) < (eps or 1e-6)
end

local function attrHolder(attrs, part)
	-- part = { Name, Position } makes it a BasePart (the shrine tool's marker part)
	return { Attrs = attrs or {}, Name = part and part.Name or "Folder", Position = part and part.Position or nil,
		GetAttribute = function(self, k) return self.Attrs[k] end,
		IsA = function(self, c) return part ~= nil and (c == "BasePart" or c == "Part") end }
end

-- a boss world. opts: Shrine (Vector3 KingSpawn on a Map descendant), Hill = { Top, Foot } (MeadowTerrainStore),
-- EditConfig(config), SpawnFails (n next SpawnEvent calls return nil)
local function bossWorld(opts)
	opts = opts or {}
	local w = newWorld({ EditConfig = opts.EditConfig })
	local map = { Desc = {} }
	if opts.Shrine then table.insert(map.Desc, attrHolder({ Other = 1 })); table.insert(map.Desc, attrHolder({ KingSpawn = opts.Shrine })) end
	-- 검수's shrine tool: a Part named KingSpawn, or a Part with KingSpawn = true (opts.MarkPart = { Name, Position, Attr })
	if opts.MarkPart then
		table.insert(map.Desc, attrHolder({ Other = 2 }, { Name = "Rock", Position = vec(9, 9, 9) }))
		table.insert(map.Desc, attrHolder(opts.MarkPart.Attr or {}, opts.MarkPart))
	end
	function map.GetDescendants(self) return self.Desc end
	local store = nil
	if opts.Hill then store = attrHolder({ HillTop = opts.Hill.Top, HillPathFoot = opts.Hill.Foot }) end
	w.Services.ServerStorage = { FindFirstChild = function(_, n) return n == "MeadowTerrainStore" and store or nil end }

	w.Spawns, w.Removes, w.Broadcasts, w.DefeatedFired = {}, {}, {}, {}
	w.SpawnFails = opts.SpawnFails or 0
	w.ReadyMap, w.ZoneOf = {}, {}
	local registry = {
		MonsterService = {
			SpawnEvent = function(kind, o)
				table.insert(w.Spawns, { Kind = kind, Opts = o })
				if w.SpawnFails > 0 then w.SpawnFails -= 1; return nil end
				local def = w.Config.MonsterTypes[kind]
				local hp = def and def.HP or 2500
				local rec = { Kind = kind, Alive = true, HP = hp, MaxHP = hp, Event = true, Root = { Position = vec(1, 2, 3) },
					_dmg = {} }
				w.Rec = rec
				return rec
			end,
			RemoveEvent = function(rec, fade, leaving)
				table.insert(w.Removes, { Rec = rec, Fade = fade, Leaving = leaving })
				rec.Alive = false
				return true
			end,
		},
		PlayerService = { IsReady = function(p) return w.ReadyMap[p] == true end,
			GetData = function(p) return w.DataOf[p] end },
		ZoneService = { GetZoneId = function(p) return w.ZoneOf[p] end },
		AnnounceService = { Broadcast = function(k, args) table.insert(w.Broadcasts, k) end },
		-- J extras: crown-war points, titles, the weekly item (GrantItem returns w.GrantReturn or n)
		WarService = { AddPoints = function(p, n, pool) table.insert(w.WarAdds, { P = p, N = n, Pool = pool }) end },
		TitleService = { Grant = function(p, id)
			w.TitlesOf[p] = w.TitlesOf[p] or {}
			if w.TitlesOf[p][id] then return false end
			w.TitlesOf[p][id] = true
			return true
		end },
		LootService = { GrantItem = function(p, id, n)
			table.insert(w.Grants, { P = p, Id = id, N = n })
			if w.GrantReturn ~= nil then return w.GrantReturn end
			return n
		end },
	}
	w.DataOf, w.WarAdds, w.TitlesOf, w.Grants = {}, {}, {}, {}
	w.Registry = registry

	local env = w:Env()
	env.workspace = { GetServerTimeNow = function() return w.Time end,
		FindFirstChild = function(_, n) return n == "Map" and map or nil end }
	env.task = table.clone(env.task)
	env.task.wait = function() coroutine.yield() end
	-- A23-113 ⑦: MonsterService's real SetEventMaxHP / DamageTotals (bar updates counted)
	local MH = execute("MonsterHP", MONSTER_HP_EXTRACT, env)
	registry.MonsterService.SetEventMaxHP = MH.SetEventMaxHP
	registry.MonsterService.DamageTotals = MH.DamageTotals
	w.MH = MH
	local mod = execute("FieldBossService", FIELDBOSS_SOURCE, env)
	w.King = mod
	mod.Defeated:Connect(function(key, kind, ids, rec) table.insert(w.DefeatedFired, { Key = key, Kind = kind, Ids = ids, Rec = rec }) end)
	mod.Init(registry)
	mod.Start()
	local job = table.remove(w.Spawned, 1)
	if job then
		w.Loop = coroutine.create(job[1])
		assert(coroutine.resume(w.Loop)) -- runs to its first wait
	end
	-- one tick after `seconds` more
	function w:Tick(seconds)
		self.Time += seconds or 0.5
		self.Clock += seconds or 0.5
		if self.Loop then
			local ok, err = coroutine.resume(self.Loop)
			if not ok then error(err) end
		end
	end
	function w:Hunter(id, zone, ready)
		local p = self:NewPlayer(id)
		self.ReadyMap[p] = ready ~= false
		self.ZoneOf[p] = zone or "SlimeMeadow"
		self.DataOf[p] = {}
		return p
	end
	-- the boss `key` appears (Studio aid) and dies: paid ids, side damage
	function w:Kill(key, paid, sideDmg)
		local said = self.King.DebugSpawn(key)
		local rec = self.Rec
		rec.Alive, rec.HP, rec.PaidUserIds, rec.FactionDamage = false, 0, paid, sideDmg
		self:Tick(0.5)
		return said, rec
	end
	function w:GS(k) return self.GameState:GetAttribute(k) end
	return w
end

local function count(list, value)
	local n = 0
	for _, v in list do if v == value then n += 1 end end
	return n
end

runGroup("config", function()
	local w = newWorld()
	local C = w.Config
	local def = C.MonsterTypes.SlimeKing
	check(type(def) == "table", "MonsterTypes.SlimeKing exists")
	check(def.Name == "King Slime" and def.Boss == true and def.Count == 0 and def.Zone == "SlimeMeadow",
		"King Slime: a meadow boss outside the regular pool", show(def))
	check(def.ModelFrom == "BigSlime" and def.Shape == "Slime", "borrows the Slime Prince model until its own", show(def.ModelFrom))
	check(table.find(C.MonsterTypeOrder, "SlimeKing") ~= nil, "in MonsterTypeOrder")
	check(C.MonsterTypes.BigSlime.Name == "Slime Prince" and C.MonsterTypes.BigSlime.Short == "Slime Prince",
		"the old King Slime (BigSlime) is now the Slime Prince", show(C.MonsterTypes.BigSlime.Name))
	check(C.MonsterTypes.BigSlime.Count == 4 and C.MonsterTypes.BigSlime.HP == 40, "the Slime Prince's numbers are unchanged")
	local kinds = {}
	for k in C.Finisher.Kinds do table.insert(kinds, k) end
	table.sort(kinds)
	check(#kinds == 2 and kinds[1] == "CaptainClatter" and kinds[2] == "SlimeKing",
		"the finisher cards are the field bosses' only (never the Slime Prince)", show(kinds))
	check(type(C.Loot.Tables.SlimeKing) == "table" and #C.Loot.Tables.SlimeKing > 0,
		"the King Slime has a drop table")
	local A = C.Announce
	for _, suffix in { "Appear", "Defeat", "Leave" } do
		local k = "SlimeKing" .. suffix
		check(type(A.Text[k]) == "string" and type(A.Text[k .. "En"]) == "string" and type(A.Events[k]) == "table",
			"announce line + event style: " .. k)
		local t = string.lower((A.Text[k] or "") .. " " .. (A.Text[k .. "En"] or ""))
		check(not string.find(t, "mom", 1, true) and not string.find(t, "mother", 1, true) and not string.find(t, "wife", 1, true),
			"A23-85 no mom line: " .. k, t)
	end
	check(string.find(A.Text.SlimeKingAppear, "Who's bothering my kids?!", 1, true) ~= nil, "appear line = the dad line")
	check(A.Events.SlimeKingAppear.Toast == true and A.Events.SlimeKingLeave.Toast ~= true, "toast only when it appears")
	check(C.Barks.BubbleFamily.SlimeKing == "Slime" and type(C.Barks.Lines.SlimeKing) == "table", "slime bubbles + dad lines")
	check(C.Audio.SoftKinds.SlimeKing == true, "soft hit sound")
	local K = C.FieldBosses.SlimeKing
	check(table.find(C.FieldBosses.Order, "SlimeKing") ~= nil and K.Enabled == true and K.Kind == "SlimeKing" and K.FirstDelay == 180 and K.Interval == 480 and K.Lifetime == 300,
		"schedule 3 min / every 8 min / stays 5 min", show(K))
	-- Net defaults + Main lists
	check(string.find(NET_SOURCE, "SlimeKingNextAt = 0, SlimeKingActive = false, SlimeKingEndsAt = 0", 1, true) ~= nil,
		"Net GameState defaults")
	local init = string.match(MAIN_SOURCE, "local INIT_ORDER = (%b{})")
	local start = string.match(MAIN_SOURCE, "local START_ORDER = (%b{})")
	check(init and string.find(init, "\"FieldBossService\"", 1, true) ~= nil, "Main INIT_ORDER has it")
	check(start and string.find(start, "\"FieldBossService\"", 1, true) ~= nil
		and string.find(start, "\"FieldBossService\"", 1, true) < string.find(start, "\"PlayerService\"", 1, true),
		"Main START_ORDER has it before PlayerService")
	check(string.find(MAIN_SOURCE, "S.FieldBossService.DebugSpawn(key)", 1, true) ~= nil, "Studio DebugCommand SlimeKing")
end)

runGroup("schedule", function()
	local w = bossWorld({ Shrine = vec(500, 20, -100) })
	local t0 = w.Time
	check(w:GS("SlimeKingNextAt") == t0 + 180 and w:GS("SlimeKingActive") == false and w:GS("SlimeKingEndsAt") == 0,
		"start: next in 180 s, none here", show(w:GS("SlimeKingNextAt")))
	w:Hunter(1, "SlimeMeadow")
	w:Tick(179)
	check(#w.Spawns == 0, "nothing before the first slot")
	w:Tick(1)
	check(#w.Spawns == 1 and w.Spawns[1].Kind == "SlimeKing", "appears at the slot with a hunter in the meadow", show(#w.Spawns))
	check(near(w.Spawns[1].Opts.Near, vec(500, 20, -100)) and w.Spawns[1].Opts.Radius == 2, "at the shrine's KingSpawn, radius 2")
	check(w:GS("SlimeKingActive") == true and w:GS("SlimeKingEndsAt") == w.Time + 300, "Active, leaves in 300 s")
	check(w:GS("SlimeKingNextAt") == w.Time + 480, "next slot 480 s from this appearance")
	check(count(w.Broadcasts, "SlimeKingAppear") == 1, "Appear line once")
	check(w.King.IsActive("SlimeKing") == true, "IsActive")
	w:Tick(10)
	check(#w.Spawns == 1, "only one at a time")
end)

runGroup("waits for a hunter", function()
	local w = bossWorld({ Shrine = vec(0, 0, 0) })
	w:Hunter(1, "GoblinWoods")
	w:Hunter(2, "SlimeMeadow", false)
	w:Tick(200)
	check(#w.Spawns == 0, "no spawn: nobody ready in the meadow")
	check(w:GS("SlimeKingNextAt") < w.Time and w:GS("SlimeKingNextAt") > 0, "due slot kept in the past (waiting)")
	w.ReadyMap[w.PlayerList[2]] = true
	w:Tick(0.5)
	check(#w.Spawns == 1, "the first ready hunter in the meadow brings it")
end)

runGroup("the shrine marker part", function()
	-- a Part named KingSpawn on the hill top (y 14.6): its Position, with the higher MaxY for the hill
	local top = vec(426, 14.6, -170)
	local w = bossWorld({ MarkPart = { Name = "KingSpawn", Position = top } })
	w:Hunter(1)
	w:Tick(180)
	check(#w.Spawns == 1 and near(w.Spawns[1].Opts.Near, top), "a Part named KingSpawn: its Position", show(w.Spawns[1] and w.Spawns[1].Opts.Near))
	check(w.Spawns[1].Opts.MaxY == w.Config.FieldBosses.SlimeKing.MaxY and w.Config.FieldBosses.SlimeKing.MaxY >= 30,
		"SpawnEvent gets the boss's MaxY (the hill top stands above normal ground)", show(w.Spawns[1].Opts.MaxY))
	-- a differently named Part with KingSpawn = true
	local w2 = bossWorld({ MarkPart = { Name = "ShrineDoor", Position = vec(5, 6, 7), Attr = { KingSpawn = true } } })
	w2:Hunter(1)
	w2:Tick(180)
	check(#w2.Spawns == 1 and near(w2.Spawns[1].Opts.Near, vec(5, 6, 7)), "a Part with KingSpawn = true: its Position")
	-- a Vector3 attribute still wins over a marker part
	local w3 = bossWorld({ Shrine = vec(1, 2, 3), MarkPart = { Name = "KingSpawn", Position = top } })
	w3:Hunter(1)
	w3:Tick(180)
	check(near(w3.Spawns[1].Opts.Near, vec(1, 2, 3)), "a Vector3 KingSpawn attribute first")
	-- a Part with KingSpawn = false is not a marker; a non-part named KingSpawn is not either
	local w4 = bossWorld({ MarkPart = { Name = "Other", Position = top, Attr = { KingSpawn = false } } })
	w4:Hunter(1)
	w4:Tick(180)
	check(not near(w4.Spawns[1].Opts.Near, top), "KingSpawn = false: not a marker (the hill / Spawn instead)")
end)

runGroup("ground on a hill (MonsterService.groundPoint)", function()
	local G = execute("groundPoint", GROUND_EXTRACT, nativeEnv())
	G.SetY(14.6)
	check(G.Point(430, -170) ~= nil and G.Point(430, -170).Y == 14.6, "the meadow hill top (14.6) is walkable ground (max 26)")
	G.SetY(30)
	check(G.Point(430, -170) == nil, "30 is above normal ground")
	check(G.Point(430, -170, 40) ~= nil, "... but fine with a boss's MaxY 40")
	check(G.Point(430, -170, 10) == nil, "a lower MaxY never narrows the normal range")
	G.SetY(-3)
	check(G.Point(430, -170, 40) == nil, "below GROUND_MIN_Y (the shore): never")
	G.SetY(nil)
	local g, noHit = G.Point(1, 1)
	check(g == nil and noHit == true, "no ground hit: nil, noHit")
end)

runGroup("a big boss is hit at its body's edge (A23-92)", function()
	local C = newWorld().Config
	local H = execute("HitPad", HITPAD_EXTRACT, nativeEnv(), C)
	local king = C.MonsterTypes.SlimeKing
	check(king.Scale >= 3.2 and king.Boss == true, "the King Slime is bigger (Scale 3.2)", king.Scale)
	local r = H.RadiusOf(king)
	local pad = H.HitPad({ Def = king, _radius = r })
	check(math.abs(r - 1.5 * king.Scale) < 1e-6 and math.abs(pad - (r - 1.5)) < 1e-6,
		"HitPad = its body radius - a normal slime's (3.3 at Scale 3.2)", show({ r, pad }))
	-- a player standing just outside its body (r + 1) is inside the normal reach + pad (the combat reach is measured
	-- to the monster's centre)
	check(r + 1 <= C.Monsters.AttackRange + pad, "a player at the body's edge is reached", show({ r + 1, C.Monsters.AttackRange + pad }))
	check(H.HitPad({ Def = C.MonsterTypes.BigSlime, _radius = H.RadiusOf(C.MonsterTypes.BigSlime) }) == 0
		and H.HitPad({ Def = C.MonsterTypes.Slime }) == 0, "regular monsters: no pad (the Slime Prince too)")
	check(H.HitPad({ Def = C.MonsterTypes.CaptainClatter, _radius = H.RadiusOf(C.MonsterTypes.CaptainClatter) }) > 0,
		"other big bosses get theirs too")
	check(string.find(MONSTER_QUERY_TEXT, "<= radius + MonsterService.HitPad(rec)", 1, true) ~= nil,
		"GetMonstersInRadius adds the pad")
	check(string.find(COMBAT_NEAR_TEXT, "if d <= radius + pad then", 1, true) ~= nil
		and string.find(COMBAT_NEAR_TEXT, "S.MonsterService.HitPad(rec)", 1, true) ~= nil, "CombatService's target search adds the pad")
	check(C.MonsterTypes.FlowerSlime.Color.X < C.MonsterTypes.FlowerSlime.Color.Z
		and C.MonsterTypes.FlowerSlime.Color.Z > 200, "the Flower Slime is purple (A23-92)", show(C.MonsterTypes.FlowerSlime.Color))
end)

runGroup("spot fallbacks", function()
	local w = bossWorld({ Hill = { Top = vec(430, 14.6, -170), Foot = vec(430, 5, -150) } })
	w:Hunter(1)
	w:Tick(180)
	check(#w.Spawns == 1 and near(w.Spawns[1].Opts.Near, vec(430, 14.6, -162), 1e-4),
		"no shrine: hill top moved 8 studs toward the path foot (flat)", show(w.Spawns[1] and w.Spawns[1].Opts.Near))
	local w2 = bossWorld({})
	w2:Hunter(1)
	w2:Tick(180)
	check(#w2.Spawns == 1 and near(w2.Spawns[1].Opts.Near, w2.Config.FieldBosses.SlimeKing.Spawn), "neither: Config.FieldBosses.SlimeKing.Spawn")
	local w3 = bossWorld({ Shrine = vec(1, 1, 1), Hill = { Top = vec(430, 14.6, -170), Foot = vec(430, 5, -150) } })
	w3:Hunter(1)
	w3:Tick(180)
	check(near(w3.Spawns[1].Opts.Near, vec(1, 1, 1)), "the shrine wins over the hill")
end)

runGroup("defeat", function()
	local w = bossWorld({ Shrine = vec(0, 0, 0) })
	w:Hunter(1)
	w:Tick(180)
	local rec = w.Rec
	rec.Alive, rec.HP, rec.PaidUserIds = false, 0, { 11, 12, "x" }
	w:Tick(0.5)
	check(#w.Removes == 0, "a kill is not removed again")
	local fx = nil
	for _, f in w.Fx do if f.Kind == "KingDefeat" then fx = f end end
	check(fx ~= nil and fx.Player == nil and fx.Data.Key == "SlimeKing" and fx.Data.Kind == "SlimeKing",
		"Fx KingDefeat to everyone", show(fx))
	check(fx and #fx.Data.Contributors == 2 and fx.Data.Contributors[1] == 11 and near(fx.Data.Pos, vec(1, 2, 3)),
		"Fx carries the paid ids (numbers only) and the spot")
	check(#w.DefeatedFired == 1 and w.DefeatedFired[1].Key == "SlimeKing" and w.DefeatedFired[1].Kind == "SlimeKing" and w.DefeatedFired[1].Rec == rec and #w.DefeatedFired[1].Ids == 2, "Defeated signal")
	check(count(w.Broadcasts, "SlimeKingDefeat") == 1 and count(w.Broadcasts, "SlimeKingLeave") == 0, "Defeat line, not Leave")
	check(w:GS("SlimeKingActive") == false and w:GS("SlimeKingEndsAt") == 0, "Active off")
	check(w.King.IsActive("SlimeKing") == false, "IsActive false")
end)

runGroup("time up / lost", function()
	local w = bossWorld({ Shrine = vec(0, 0, 0) })
	w:Hunter(1)
	w:Tick(180)
	local rec = w.Rec
	w:Tick(299)
	check(#w.Removes == 0, "still here at 299 s")
	w:Tick(1)
	check(#w.Removes == 1 and w.Removes[1].Rec == rec and w.Removes[1].Fade == true and w.Removes[1].Leaving == true,
		"time up: goes home (fade, leaving)")
	check(count(w.Broadcasts, "SlimeKingLeave") == 1 and count(w.Broadcasts, "SlimeKingDefeat") == 0, "Leave line")
	check(#w.DefeatedFired == 0, "no Defeated")
	for _, f in w.Fx do check(f.Kind ~= "KingDefeat", "no defeat Fx on leave") end
	-- next slot still 480 s after the appearance
	w:Tick(180)
	check(#w.Spawns == 2, "the next slot comes 480 s after the last appearance", show(#w.Spawns))
	-- a lost model (fell out): HP kept
	w.Rec.Alive = false
	w:Tick(0.5)
	check(count(w.Broadcasts, "SlimeKingLeave") == 2 and #w.DefeatedFired == 0, "a lost model is a Leave, not a defeat")
end)

runGroup("retry / off / debug", function()
	local w = bossWorld({ Shrine = vec(0, 0, 0), SpawnFails = 1 })
	w:Hunter(1)
	w:Tick(180)
	check(#w.Spawns == 1 and w:GS("SlimeKingActive") == false, "no ground: nothing appears")
	check(w:GS("SlimeKingNextAt") == w.Time + 10, "retry in 10 s", show(w:GS("SlimeKingNextAt") - w.Time))
	check(count(w.Broadcasts, "SlimeKingAppear") == 0, "no Appear line without a boss")
	w:Tick(10)
	check(#w.Spawns == 2 and w:GS("SlimeKingActive") == true, "the retry spawns it")

	local off = bossWorld({ EditConfig = function(c) c.FieldBosses.SlimeKing.Enabled = false end })
	off:Hunter(1)
	off:Tick(2000)
	check(#off.Spawns == 0 and off:GS("SlimeKingNextAt") == 0, "Enabled = false: never, NextAt 0")

	local d = bossWorld({ Shrine = vec(0, 0, 0) })
	check(d.King.DebugSpawn("SlimeKing") == "spawned" and #d.Spawns == 1, "DebugSpawn now (no hunter needed)")
	check(d.King.DebugSpawn("SlimeKing") == "already here" and #d.Spawns == 1, "DebugSpawn twice: already here")
	d:Hunter(1)
	d:Tick(180)
	check(#d.Spawns == 1, "a slot while one is here is skipped")
	check(d:GS("SlimeKingNextAt") > d.Time, "NextAt moved forward past the skipped slot", show(d:GS("SlimeKingNextAt") - d.Time))
end)

runGroup("two bosses", function()
	-- a second boss (no Hill, no Attr, no Spawn) on its own schedule in another zone
	local w = bossWorld({ Shrine = vec(5, 5, 5), Hill = { Top = vec(430, 14.6, -170), Foot = vec(430, 5, -150) },
		EditConfig = function(c)
			c.FieldBosses.Order = { "SlimeKing", "Ruin" }
			c.FieldBosses.Ruin = { Kind = "Skeleton", FirstDelay = 60, Interval = 600, Lifetime = 120, Radius = 6 }
		end })
	w:Hunter(1, "SkeletonRuins")
	check(w:GS("RuinNextAt") == w.Time + 60 and w:GS("SlimeKingNextAt") == w.Time + 180, "each boss its own first slot")
	w:Tick(60)
	check(#w.Spawns == 1 and w.Spawns[1].Kind == "Skeleton", "the ruins boss comes for a ruins hunter", show(#w.Spawns))
	check(w.Spawns[1].Opts.Near == nil and w.Spawns[1].Opts.Radius == 6,
		"no Attr / Hill / Spawn: a zone spawn point (no Near), its own Radius", show(w.Spawns[1].Opts.Near))
	check(count(w.Broadcasts, "RuinAppear") == 1 and w:GS("RuinActive") == true and w:GS("SlimeKingActive") == false,
		"its own lines and GameState")
	w:Tick(120)
	check(#w.Spawns == 1, "the King Slime waits: nobody in the meadow")
	check(count(w.Broadcasts, "RuinLeave") == 1 and w:GS("RuinActive") == false, "the ruins boss leaves after 120 s")
	w:Hunter(2, "SlimeMeadow")
	w:Tick(0.5)
	check(#w.Spawns == 2 and w.Spawns[2].Kind == "SlimeKing" and near(w.Spawns[2].Opts.Near, vec(5, 5, 5)),
		"the King Slime at its shrine")
	check(w.King.IsActive("SlimeKing") and not w.King.IsActive("Ruin"), "IsActive per key")
	check(w.King.DebugSpawn("Nope") == "no field boss Nope", "DebugSpawn of an unknown key")
	-- the ruins boss alone with the hill store present: still no hill
	local h = bossWorld({ Hill = { Top = vec(430, 14.6, -170), Foot = vec(430, 5, -150) },
		EditConfig = function(c)
			c.FieldBosses.Order = { "Ruin" }
			c.FieldBosses.Ruin = { Kind = "Skeleton", FirstDelay = 10, Interval = 600, Lifetime = 120 }
		end })
	h:Hunter(1, "SkeletonRuins")
	h:Tick(10)
	check(#h.Spawns == 1 and h.Spawns[1].Opts.Near == nil, "the meadow hill is the King Slime's only (Hill = true)")
end)

runGroup("clatter config", function()
	local w = newWorld()
	local C = w.Config
	local K = C.FieldBosses.Clatter
	local def = C.MonsterTypes.CaptainClatter
	check(table.find(C.FieldBosses.Order, "Clatter") ~= nil and K.Kind == "CaptainClatter", "Clatter is a field boss key")
	check(K.FirstDelay == 300 and K.Interval == 1200 and K.Lifetime == 360 and K.MinLevel == 25 and K.War == 20
		and K.Attr == "ClatterSpawn" and K.Hill ~= true, "every 20 min, stays 6 min, chip from Lv25, +20 war, own mark", show(K))
	check(type(K.Weekly) == "table" and K.Weekly.Item == "CaptainBadge" and K.Weekly.Max == 2
		and K.Titles[1] == "ClatterStopper" and K.Titles[10] == "ClatterStopper10" and K.Titles[50] == "ClatterStopper50",
		"weekly badge banked up to 2, titles 1 / 10 / 50")
	check(def and def.Boss == true and def.Count == 0 and def.Zone == "SkeletonRuins" and def.HP == 9000
		and def.Scale == 2.2 and def.ModelFrom == "SkeletonKnight" and def.AnimFrom == "SkeletonKnight"
		and def.RewardMinHits == 3 and def.XP == 3900 and def.Gold == 3900, "Captain Clatter: a ruins boss on the knight", show(def))
	check(table.find(C.MonsterTypeOrder, "CaptainClatter") ~= nil and C.Barks.BubbleFamily.CaptainClatter == "Skeleton"
		and type(C.Barks.Lines.CaptainClatter) == "table", "order, bubble family, barks")
	local T = C.Loot.Tables.CaptainClatter
	local row = {}
	for _, r in T or {} do row[r.Item or (r.Weapon and ("W" .. r.Weapon)) or r.Potion] = r end
	check(row.KnightCrest and row.KnightCrest.P == 1 and row.KnightCrest.N == 3 and row.Enh30 and row.Enh30.P == 0.2
		and row.Enh10 and row.Enh10.P == 0.05 and row.W5 and row.W5.P == 0.03 and row.W6 and row.W6.P == 0.005
		and row.W5.BelowLevel.Item == "KnightCrest" and row.W5.BelowLevel.N == 2, "drops: 3 crests, Enh30 20%, Enh10 5%, T5 3%, T6 0.5%")
	check(C.Loot.Items.CaptainBadge and C.Loot.Items.CaptainBadge.Kind == "Material"
		and table.find(C.Loot.Order, "CaptainBadge") ~= nil, "Captain's Badge is a listed material")
	for _, s in { "Appear", "Defeat", "Leave" } do
		local k = "Clatter" .. s
		check(type(C.Announce.Text[k]) == "string" and C.Announce.Text[k] == C.Announce.Text[k .. "En"]
			and type(C.Announce.Events[k]) == "table", "announce " .. k)
	end
	check(C.Announce.Events.ClatterAppear.Toast == true and C.Announce.Events.ClatterLeave.Toast ~= true, "toast on appear only")
	for _, id in { "ClatterStopper", "ClatterStopper10", "ClatterStopper50" } do
		check(C.TitleDefs[id] ~= nil and table.find(C.TitleOrder, id) ~= nil, "title " .. id)
	end
	check(string.find(NET_SOURCE, "ClatterNextAt = 0, ClatterActive = false, ClatterEndsAt = 0", 1, true) ~= nil, "Net defaults")
	-- the finisher cards: both bosses, the same size each
	local F = C.Finisher
	check(F.Kinds.SlimeKing == true and F.Kinds.CaptainClatter == true and F.Kinds.BigSlime == nil, "card kinds")
	for kind, card in F.Cards do
		local item = C.Loot.Items[card.Help.Item]
		local worth = (item and item.Sell) or card.Help.Worth or 0
		check(card.Help.N * worth == card.Tickle.Gold and card.Tickle.Gold > 0, "card " .. kind .. ": the same size",
			show({ card.Help, card.Tickle }))
		check(type(card.Text.Title) == "string" and type(card.Text.Help) == "string" and type(card.Text.Tickle) == "string"
			and type(card.Text.HelpDone) == "string" and type(card.Text.TickleDone) == "string", "card " .. kind .. ": words")
	end
	check(F.Cards.CaptainClatter.Text.Help == "Let him rest" and F.Cards.CaptainClatter.Text.Tickle == "Count the old treasure!",
		"Clatter's buttons")
end)

runGroup("clatter war pool", function()
	-- 검수 2026-10-09 (the CR-M18 way): +20 personal points each, but one kill adds 20 to a side's pool only once
	local w = bossWorld({})
	local a, b, c = w:Hunter(1, "SkeletonRuins"), w:Hunter(2, "SkeletonRuins"), w:Hunter(3, "SkeletonRuins")
	a.Attrs.Faction, b.Attrs.Faction, c.Attrs.Faction = "Halo", "Halo", "Horns"
	w:Kill("Clatter", { 1, 2, 3 }, { Halo = 50, Horns = 50 })
	local pool, personal = { Halo = 0, Horns = 0 }, 0
	for _, add in w.WarAdds do
		pool[add.P.Attrs.Faction] += add.Pool or add.N
		personal += add.N
	end
	check(#w.WarAdds == 3 and personal == 60, "+20 personal points each", show({ #w.WarAdds, personal }))
	check(pool.Halo == 20 and pool.Horns == 20, "each side's pool gets 20 once (two Halos 10 + 10, one Horns 20)", show(pool))
end)

runGroup("clatter extras", function()
	local w = bossWorld({})
	local a, b = w:Hunter(1, "SkeletonRuins"), w:Hunter(2, "SkeletonRuins")
	local said, rec = w:Kill("Clatter", { 1, 2, 999 }, { Halo = 62, Horns = 38 })
	check(said == "spawned" and w.Spawns[#w.Spawns].Kind == "CaptainClatter", "DebugSpawn Clatter", said)
	local fx = nil
	for _, f in w.Fx do if f.Kind == "KingDefeat" then fx = f end end
	check(fx and fx.Data.Key == "Clatter" and fx.Data.Share and fx.Data.Share.Halo == 62 and fx.Data.Share.Horns == 38,
		"defeat Fx carries the side share", show(fx and fx.Data.Share))
	check(#w.WarAdds == 2 and w.WarAdds[1].N == 20 and w.WarAdds[2].N == 20, "+20 crown-war points each (own side)", #w.WarAdds)
	local da, db = w.DataOf[a].FieldBoss.Clatter, w.DataOf[b].FieldBoss.Clatter
	check(da.Kills == 1 and db.Kills == 1 and w.TitlesOf[a].ClatterStopper and w.TitlesOf[b].ClatterStopper,
		"first kill: Kills 1, Clatter Stopper", show(da))
	check(#w.Grants == 2 and w.Grants[1].Id == "CaptainBadge" and w.Grants[1].N == 1 and da.Owed == 0,
		"the week's first kill always gives the badge", #w.Grants)
	check(#w:NoticesFor(a) == 1, "a badge line", #w:NoticesFor(a))
	-- same week: no badge
	w:Kill("Clatter", { 1 }, { Halo = 10 })
	check(#w.Grants == 2 and da.Kills == 2, "a second kill that week: no badge")
	-- next week: one again
	w.Time += 604800
	w:Kill("Clatter", { 1 }, { Halo = 10 })
	check(#w.Grants == 3 and da.Owed == 0, "next week: the badge again", show(da))
	-- three weeks skipped: two banked (Max), one now, one left for the next kill the same week
	w.Time += 3 * 604800
	w:Kill("Clatter", { 1 }, {})
	check(#w.Grants == 4 and da.Owed == 1, "skipped weeks bank up to 2: one now, one waits", show(da))
	w:Kill("Clatter", { 1 }, {})
	check(#w.Grants == 5 and da.Owed == 0, "the banked one comes with the next kill", show(da))
	-- a full bag: the guarantee waits
	w.Time += 604800
	w.GrantReturn = 0
	w:Kill("Clatter", { 1 }, {})
	check(da.Owed == 1, "a full bag keeps the guarantee", show(da))
	w.GrantReturn = nil
	w:Kill("Clatter", { 1 }, {})
	check(da.Owed == 0, "the next kill gives it", show(da))
	-- no side hit it: no share
	local last = nil
	for _, f in w.Fx do if f.Kind == "KingDefeat" then last = f end end
	check(last and last.Data.Share == nil, "no side damage: no share line")
	-- kill 10: the second title
	for _ = da.Kills + 1, 10 do w:Kill("Clatter", { 1 }, {}) end
	check(da.Kills == 10 and w.TitlesOf[a].ClatterStopper10 == true and not w.TitlesOf[a].ClatterStopper50,
		"10 kills: Clatter Stopper 10", show(da))
	-- the King Slime has no war / weekly / titles
	local before = #w.WarAdds
	local grants = #w.Grants
	w:Kill("SlimeKing", { 2 }, { Horns = 5 })
	check(#w.WarAdds == before and #w.Grants == grants and w.DataOf[b].FieldBoss.SlimeKing.Kills == 1,
		"King Slime: kills counted, no war points / weekly item")
	-- an old save without the table, broken numbers
	w.DataOf[b].FieldBoss = { Clatter = { Kills = "x", Week = -3, Owed = 99 } }
	w:Kill("Clatter", { 2 }, {})
	local fixed = w.DataOf[b].FieldBoss.Clatter
	check(fixed.Kills == 1 and fixed.Owed <= 2, "broken save numbers repaired", show(fixed))
	-- this week already counted but a broken bank of 99: capped at Max (2), one given now
	local week = w.Config.WeekIndex(math.floor(w.Time))
	w.DataOf[b].FieldBoss = { Clatter = { Kills = 3, Week = week, Owed = 99 } }
	local g0 = #w.Grants
	w:Kill("Clatter", { 2 }, {})
	check(#w.Grants == g0 + 1 and w.DataOf[b].FieldBoss.Clatter.Owed == 1, "a broken bank is capped at Max",
		show(w.DataOf[b].FieldBoss.Clatter))
end)

------------------------------------------------------------------ A23-113 ⑦ crowd HP
-- a body for a hunter: its root at `pos` (the boss double stands at (1, 2, 3)), a humanoid with `health`
local function body(p, pos, health)
	local root = { Position = pos or vec(1, 2, 3) }
	local hum = { Health = health or 100 }
	p.Character = { Parent = {}, FindFirstChild = function(_, n) return n == "HumanoidRootPart" and root or nil end,
		FindFirstChildOfClass = function(_, c) return c == "Humanoid" and hum or nil end }
	return root, hum
end

-- the solo DPS model the HP numbers come from (docs/design/field_boss_crowd_2026-10-11.md): one hunter against one boss,
-- swings (SwingImmediate, crit chance x CritMult) + skill Q (ManaCost / Cooldown / DamageMultiplier, MP pool + regen, the
-- Mage's swing MP, the global gap after a skill) over `secs`, x UPTIME (walking, dodging, aim); the CURRENT Config numbers
local UPTIME = 0.75
local function soloDps(C, classId, tier, level, side, secs)
	local cl = C.Classes[classId]
	local f = C.Factions[side]
	local D = C.WeaponDamage(tier, level, 0) * cl.Damage * (1 + (f.DamageBonus or 0))
	local function rnd(x) return math.max(1, math.floor(x + 0.5)) end
	local imm, crit = C.BasicSkill.SwingImmediate, C.Combat.CritChance
	local swing = rnd(D * imm) * (1 - crit) + rnd(D * imm * C.Combat.CritMult) * crit
	local q, cost, cd = rnd(D * C.BasicSkill.DamageMultiplier), C.BasicSkill.ManaCost, C.BasicSkill.Cooldown
	local mageCost = classId == "Mage" and C.Vitals.MageSwingCost or 0
	local mp, t, dmg, nextSwing, nextQ, dt = C.Vitals.MaxMana, 0, 0, 0, 0, 0.05
	while t < secs do
		if t >= nextQ and mp >= cost then
			mp -= cost
			dmg += q
			nextQ = t + cd
			nextSwing = math.max(nextSwing, t + C.Skills.GlobalGap)
		elseif t >= nextSwing and mp >= mageCost then
			mp -= mageCost
			dmg += swing
			nextSwing = t + cl.SwingInterval
		end
		mp = math.min(C.Vitals.MaxMana, mp + C.Vitals.ManaRegen * dt)
		t += dt
	end
	return dmg / secs * UPTIME
end

local function meanDps(C, levels, tiers)
	local sum, n, byClass = 0, 0, {}
	for _, classId in { "Warrior", "Mage", "Archer" } do
		local s, k = 0, 0
		for _, tier in tiers do
			for _, lv in levels do
				for _, side in { "Halo", "Horns", "Neutral" } do
					local d = soloDps(C, classId, tier, lv, side, 120)
					s += d
					k += 1
				end
			end
		end
		byClass[classId] = math.floor(s / k * 10 + 0.5) / 10
		sum += s
		n += k
	end
	return sum / n, byClass
end

runGroup("crowd numbers", function()
	local w = newWorld()
	local C = w.Config
	local K = C.FieldBosses.Crowd
	check(type(K) == "table" and K.PerHunter == 0.5 and K.Max == 10 and K.Radius == 50 and K.Window == 15 and K.Every == 2
		and K.SoloSeconds == 120 and K.ByDamage == nil,
		"Crowd: +50% per hunter, up to 10, within 50 studs, damage of the last 15 s vs a 120 s pace, every 2 s", show(K))
	check(C.FieldBosses.SlimeKing.Crowd == nil and C.FieldBosses.Clatter.Crowd == nil, "both bosses use the shared rule")
	local king, clatter = C.MonsterTypes.SlimeKing.HP, C.MonsterTypes.CaptainClatter.HP
	check(king == 2000 and clatter == 9000, "one hunter's HP: King 2000, Clatter 9000", show({ king, clatter }))
	-- A23-113 ⑦: alone about 2 min (King: Lv 5-8, tier 1-2; Clatter: Lv25 tier 3)
	local kd, kc = meanDps(C, { 5, 6, 7, 8 }, { 1, 2 })
	local cd, cc = meanDps(C, { 25 }, { 3 })
	local kt, ct = king / kd, clatter / cd
	check(kt >= 105 and kt <= 135, "King alone: about 2 min", show({ seconds = math.floor(kt), dps = kd, byClass = kc }))
	check(ct >= 105 and ct <= 135, "Clatter alone: about 2 min", show({ seconds = math.floor(ct), dps = cd, byClass = cc }))
	-- the share's pace (HP / SoloSeconds) is an average hunter's damage, so an average hunter counts about 1
	check(math.abs(kd / (king / K.SoloSeconds) - 1) <= 0.15 and math.abs(cd / (clatter / K.SoloSeconds) - 1) <= 0.15,
		"an average hunter's DPS = the pace within 15% (shares near 1)", show({ kd, king / K.SoloSeconds, cd, clatter / K.SoloSeconds }))
	-- equal hunters: more is always faster, yet a crowd never melts it (>= 55 s with 10, >= 70 s with 3)
	local prev = math.huge
	local times = {}
	for _, n in { 1, 2, 3, 5, 10, 15 } do
		local counted = math.min(n, K.Max)
		local secs = king * (1 + K.PerHunter * (counted - 1)) / (n * kd)
		times[tostring(n)] = math.floor(secs)
		check(secs < prev, "King: " .. n .. " hunters are faster than fewer", show(times))
		prev = secs
	end
	check(times["3"] >= 70 and times["10"] >= 55 and times["2"] >= 80, "a crowd never melts the King (3 >= 70 s, 10 >= 55 s)",
		show(times))
	check(K.PerHunter < 1, "PerHunter < 1: one more hunter always helps (n / (1 + k (n - 1)) grows)", K.PerHunter)
end)

-- own damage on the boss double (MonsterService's _dmg; the fixture's HP does not move)
local function hit(rec, p, dmg)
	rec._dmg[p] = (rec._dmg[p] or 0) + dmg
end

runGroup("crowd hp", function()
	local w = bossWorld({})
	check(w.King.Hunters("SlimeKing") == 0, "no boss: 0 hunters")
	w.King.DebugSpawn("SlimeKing")
	local rec = w.Rec
	check(rec.MaxHP == 2000 and w.King.Hunters("SlimeKing") == 1, "appears with one hunter's HP", show({ rec.MaxHP }))
	-- a bystander next to it who never hits adds nothing
	local idle = w:Hunter(10)
	body(idle, vec(5, 2, 3))
	w:Tick(2)
	check(rec.MaxHP == 2000 and w.King.Hunters("SlimeKing") == 1, "a bystander adds nothing", rec.MaxHP)
	local a = w:Hunter(1)
	body(a, vec(10, 2, 3))
	hit(rec, a, 1000)
	w:Tick(2)
	check(rec.MaxHP == 2000 and w.King.Hunters("SlimeKing") == 1, "one hunter (however strong): 2000", rec.MaxHP)
	-- at half HP a second full hunter (37 studs away) joins: x1.5 at the next count, still half
	rec.HP = 1000
	local b = w:Hunter(2)
	local rb, hb = body(b, vec(1, 2, 40))
	hit(rec, a, 1000)
	hit(rec, b, 1000)
	w:Tick(0.5)
	check(rec.MaxHP == 2000, "the count waits Every s", rec.MaxHP)
	w:Tick(1.5)
	check(rec.MaxHP == 3000 and rec.HP == 1500 and w.King.Hunters("SlimeKing") == 2, "two full hunters: 3000, still half",
		show({ rec.MaxHP, rec.HP, w.King.Hunters("SlimeKing") }))
	check((rec._bars or 0) >= 1, "the HP bar follows", rec._bars)
	-- out of 50 studs / dead / not ready: back to one hunter, the fraction kept each way
	local function again(why, set, unset)
		hit(rec, a, 1000)
		hit(rec, b, 1000)
		set()
		w:Tick(2)
		check(rec.MaxHP == 2000 and rec.HP == 1000 and w.King.Hunters("SlimeKing") == 1, why .. ": not counted",
			show({ rec.MaxHP, rec.HP }))
		unset()
		hit(rec, a, 1000)
		hit(rec, b, 1000)
		w:Tick(2)
		check(rec.MaxHP == 3000 and rec.HP == 1500, why .. ": counted again", show({ rec.MaxHP, rec.HP }))
	end
	again("57 studs away", function() rb.Position = vec(1, 2, 60) end, function() rb.Position = vec(1, 2, 40) end)
	again("dead", function() hb.Health = 0 end, function() hb.Health = 100 end)
	again("not ready", function() w.ReadyMap[b] = false end, function() w.ReadyMap[b] = true end)
	-- b stops (its last damage is in the count at T): still counted at T + 14, not at T + 16 (Window 15, counts every 2 s)
	for _ = 1, 7 do
		hit(rec, a, 1000)
		w:Tick(2)
	end
	check(rec.MaxHP == 3000, "a hunter who stopped 14 s ago still counts", rec.MaxHP)
	hit(rec, a, 1000)
	w:Tick(2)
	check(rec.MaxHP == 2000 and rec.HP == 1000, "... and 16 s ago no more", show({ rec.MaxHP, rec.HP }))
	-- a full hunter + four new players punching 10 every 2 s (0.3 of one hunter's pace each): 2.2 hunters, not 5
	local kids = {}
	for i = 40, 43 do
		local p = w:Hunter(i)
		body(p, vec(1, 2, 8))
		table.insert(kids, p)
	end
	for _ = 1, 9 do
		hit(rec, a, 1000)
		for _, p in kids do hit(rec, p, 10) end
		w:Tick(2)
	end
	check(math.abs(w.King.Hunters("SlimeKing") - 2.2) < 1e-6 and rec.MaxHP == 3200,
		"weak hitters add their small share (1 + 4 x 0.3 = 2.2 -> 3200, not 6000)", show({ w.King.Hunters("SlimeKing"), rec.MaxHP }))
	for _, p in kids do w:Remove(p) end
	-- 13 full hunters count as 10: x5.5
	local many = {}
	for i = 20, 31 do
		local p = w:Hunter(i)
		body(p, vec(1, 2, 3))
		table.insert(many, p)
	end
	for _, p in many do hit(rec, p, 1000) end
	hit(rec, a, 1000)
	w:Tick(2)
	check(rec.MaxHP == 11000 and w.King.Hunters("SlimeKing") == 10, "13 full hunters count as 10: 2000 x 5.5",
		show({ rec.MaxHP, w.King.Hunters("SlimeKing") }))
	-- they leave the game at 1 HP (their damage still on the record): it stays 1, alive, one hunter again
	for _, p in many do w:Remove(p) end
	w:Remove(b)
	rec.HP = 1
	hit(rec, a, 1000)
	w:Tick(2)
	check(rec.MaxHP == 2000 and rec.HP == 1 and rec.Alive == true, "1 HP stays 1 when the crowd leaves (gone players not counted)",
		show({ rec.MaxHP, rec.HP }))
	-- defeated: 0 hunters; the next one comes with one hunter's HP again
	rec.Alive, rec.HP = false, 0
	w:Tick(0.5)
	check(w.King.Hunters("SlimeKing") == 0, "gone: 0 hunters")
	w.King.DebugSpawn("SlimeKing")
	check(w.Rec ~= rec and w.Rec.MaxHP == 2000 and w.King.Hunters("SlimeKing") == 1, "the next King: 2000 again", w.Rec.MaxHP)
	-- Captain Clatter (pace 75 / s): three full hunters = 9000 x 2
	w.King.DebugSpawn("Clatter")
	local cr = w.Rec
	local c1, c2 = w:Hunter(50), w:Hunter(51)
	body(c1)
	body(c2)
	for _, p in { a, c1, c2 } do hit(cr, p, 5000) end
	w:Tick(2)
	check(cr.MaxHP == 18000 and w.King.Hunters("Clatter") == 3, "Clatter with three hunters: 18000", cr.MaxHP)
end)

runGroup("crowd rule per boss", function()
	local off = bossWorld({ EditConfig = function(c) c.FieldBosses.SlimeKing.Crowd = false end })
	off.King.DebugSpawn("SlimeKing")
	for i = 1, 3 do
		local p = off:Hunter(i)
		body(p)
		hit(off.Rec, p, 1000)
	end
	off:Tick(2)
	check(off.Rec.MaxHP == 2000, "Crowd = false: that boss keeps its HP", off.Rec.MaxHP)
	local own = bossWorld({ EditConfig = function(c)
		c.FieldBosses.SlimeKing.Crowd = { PerHunter = 1, Max = 3, Radius = 50, Window = 15, Every = 2, SoloSeconds = 120 }
	end })
	own.King.DebugSpawn("SlimeKing")
	local list = {}
	for i = 1, 5 do
		local p = own:Hunter(i)
		body(p)
		table.insert(list, p)
	end
	hit(own.Rec, list[1], 1000)
	hit(own.Rec, list[2], 1000)
	own:Tick(2)
	check(own.Rec.MaxHP == 4000, "its own Crowd table wins: +100% per hunter", own.Rec.MaxHP)
	for _, p in list do hit(own.Rec, p, 1000) end
	own:Tick(2)
	check(own.Rec.MaxHP == 6000, "... and its own Max (3)", own.Rec.MaxHP)
	-- ByDamage = false: anyone with damage in the window counts 1 (the plain head count)
	local heads = bossWorld({ EditConfig = function(c) c.FieldBosses.Crowd.ByDamage = false end })
	heads.King.DebugSpawn("SlimeKing")
	local strong = heads:Hunter(1)
	body(strong)
	hit(heads.Rec, strong, 1000)
	for i = 2, 5 do
		local p = heads:Hunter(i)
		body(p)
		hit(heads.Rec, p, 1)
	end
	heads:Tick(2)
	check(heads.Rec.MaxHP == 6000 and heads.King.Hunters("SlimeKing") == 5, "ByDamage = false: five heads -> 2000 x 3",
		show({ heads.Rec.MaxHP }))
end)

runGroup("crowd monster api", function()
	local w = bossWorld({})
	local MH = w.MH
	local rec = { Event = true, Alive = true, HP = 50, MaxHP = 100 }
	check(MH.SetEventMaxHP(rec, 300) == true and rec.MaxHP == 300 and rec.HP == 150 and rec._bars == 1, "x3 keeps half",
		show({ rec.MaxHP, rec.HP }))
	check(MH.SetEventMaxHP(rec, 300) == false and rec._bars == 1, "the same MaxHP: no change")
	rec.HP = 100
	check(MH.SetEventMaxHP(rec, 200) == true and rec.HP == 67, "rounded (100 / 300 of 200 = 66.7 -> 67)", rec.HP)
	rec.HP, rec.MaxHP = 1, 3
	check(MH.SetEventMaxHP(rec, 4) == true and rec.HP == 1, "1 / 3 of 4 = 1.33 -> 1", rec.HP)
	rec.HP, rec.MaxHP = 1, 1000
	check(MH.SetEventMaxHP(rec, 10) == true and rec.HP == 1, "never below 1 HP (0.01 -> 1)", rec.HP)
	for _, bad in { 0, -5, 0 / 0, math.huge, "300" } do
		check(MH.SetEventMaxHP(rec, bad) == false and rec.MaxHP == 10, "bad MaxHP refused", tostring(bad))
	end
	local zone = { Alive = true, HP = 5, MaxHP = 10 }
	check(MH.SetEventMaxHP(zone, 20) == false and zone.MaxHP == 10, "a zone monster (not an event) is never changed")
	local dead = { Event = true, Alive = false, HP = 0, MaxHP = 10 }
	check(MH.SetEventMaxHP(dead, 20) == false and dead.MaxHP == 10, "a dead one is never changed")
	check(MH.SetEventMaxHP(nil, 20) == false, "nil refused")
	-- DamageTotals: a copy of the players' positive damage
	local p1, p2, p3 = w:Hunter(1), w:Hunter(2), w:Hunter(3)
	local r = { _dmg = { [p1] = 40, [p2] = 0, [p3] = 0 / 0, Oops = 9 } }
	local got = MH.DamageTotals(r)
	local n = 0
	for _ in got do n += 1 end
	check(n == 1 and got[p1] == 40, "DamageTotals: positive numbers of players only", n)
	got[p1] = 999
	check(r._dmg[p1] == 40, "DamageTotals is a copy (a snapshot never moves with the record)")
	check(next(MH.DamageTotals({})) == nil and next(MH.DamageTotals(nil)) == nil, "no damage table: empty")
end)

finish()
