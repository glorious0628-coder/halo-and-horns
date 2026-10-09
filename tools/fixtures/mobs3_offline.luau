-- mobs3_offline.luau : A23-87 new kinds (Flower Slime, Slingshot Goblin, Skeleton Archer) + the FlowerPatch kill card,
-- offline. tools/test_mobs3.py puts the source bindings + dev2_kit.luau in front of this file. MonsterService's real
-- A23-87 section (MOB3) and its real targetable() run on engine doubles; KillCardService runs from the current source.

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

local function flat(a, b)
	return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
end

-- a MOB3 world: H = the section's upvalues (doubles), w.Mob = the real MOB3 table
local function mobWorld(opts)
	opts = opts or {}
	local w = newWorld({ EditConfig = opts.EditConfig })
	local C = w.Config
	w.Fxs, w.Hits, w.Moments, w.Town, w.Dead, w.RootOf, w.Rays, w.Picks = {}, {}, {}, {}, {}, {}, {}, {}
	w.Ground = opts.Ground or function() return nil end
	local util = setmetatable({
		IsAlive = function(p) return not w.Dead[p] end,
		GetRoot = function(p) return w.RootOf[p] end,
	}, { __index = w.Util })
	local records = {}
	w.Records = records
	local H = {
		records = records,
		MOB3 = { Net = { Fx = function(p, kind, data) table.insert(w.Fxs, { P = p, Kind = kind, Data = data }) end } },
		FACE = { Active = {}, Keep = 0.6 },
		REACT = { WINDUP_LEEWAY = 2 },
		S = { CombatService = { DamagePlayer = function(p, dmg, _, crit, kind)
			table.insert(w.Hits, { P = p, Dmg = dmg, Crit = crit, Kind = kind })
		end } },
		MonsterService = { Moment = { Fire = function(_, rec, what) table.insert(w.Moments, { Rec = rec, What = what }) end } },
		isPlayerInTown = function(p) return w.Town[p] == true end,
		warnThrottled = function(_, msg) table.insert(w.Warnings, tostring(msg)) end,
		getGroundParams = function() return "params" end,
		pickSpawnPoint = function()
			local p = table.remove(w.Picks, 1)
			return p
		end,
		groundPoint = function(x, z) return vec(x, 1, z) end,
		SEP = { Clear = function() return true end, RadiusOf = function() return 1.25 end },
		workspace = { GetServerTimeNow = function() return w.Time end,
			Raycast = function(_, origin, dir, params)
				table.insert(w.Rays, { Origin = origin, Dir = dir, Params = params })
				local m = w.Ground(origin)
				return m and { Material = m } or nil
			end },
	}
	w.H = H
	local env = w:Env()
	env.Enum = { Material = setmetatable({}, { __index = function(_, k) return "Material." .. k end }) }
	local fn = execute("MOB3", MOB3_EXTRACT, env, C, util, H)
	w.Mob = fn
	function w:Player(id, pos)
		local p = self:NewPlayer(id)
		self.RootOf[p] = { Position = pos }
		return p
	end
	function w:Rec(kind, pos)
		local def = C.MonsterTypes[kind]
		local model = newInstance("Model", self)
		local rec = { Id = #records + 1, Kind = kind, Def = def, Alive = true, ZoneId = def.Zone, Model = model,
			Root = { Position = pos, Parent = model, Anchored = false }, _nextAttackAt = 0, _moves = {} }
		rec.Humanoid = { MoveTo = function(_, p) table.insert(rec._moves, p) end }
		model.Parent = newInstance("Folder", self)
		records[rec.Id] = rec
		return rec
	end
	return w
end

local function zoneCenter(C, id)
	local z = C.Zones[id]
	return vec(z.Center.X, 1, z.Center.Z)
end

runGroup("config", function()
	local C = newWorld().Config
	local MT, MC = C.MonsterTypes, C.Monsters
	local fl, sg, sa = MT.FlowerSlime, MT.SlingshotGoblin, MT.SkeletonArcher
	check(fl and sg and sa, "three new kinds")
	check(fl.Zone == "SlimeMeadow" and sg.Zone == "GoblinWoods" and sa.Zone == "SkeletonRuins", "meadow / woods / ruins")
	check(fl.ModelFrom == "Slime" and sg.ModelFrom == "Goblin" and sg.AnimFrom == "Goblin" and sa.ModelFrom == "Skeleton"
		and sa.AnimFrom == "Skeleton", "on their families' models and moves")
	check(fl.QuestAs == "Slime" and sg.QuestAs == "Goblin" and sa.QuestAs == "Skeleton", "quests count them as the family")
	check(not fl.Boss and not sg.Boss and not sa.Boss and fl.Count > 0 and sg.Count > 0 and sa.Count > 0, "regular pool kinds")
	check(sg.Damage < MT.Goblin.Damage and sa.Damage < MT.Skeleton.Damage and fl.Damage <= MT.Slime.Damage,
		"damage under the zone's melee kind", show({ sg.Damage, sa.Damage, fl.Damage }))
	for _, k in { "SlingshotGoblin", "SkeletonArcher" } do
		local R = MT[k].Ranged
		check(type(R) == "table" and R.Range > MC.AttackRange and R.Stand < R.Range and R.Stand > MC.AttackRange,
			k .. ": shoots from afar, stands inside its range", show(R))
		check(R.Speed <= 20 and R.Radius >= 3 and R.Windup >= 0.8 and R.Cooldown >= 3,
			k .. ": slow, big, telegraphed, not often (kid-dodgeable)", show(R))
	end
	check(sa.PartnerOf == "SkeletonKnight", "the archer pairs with the knight")
	check(type(fl.Ambush) == "table" and fl.Ambush.Material == "Salt" and fl.Ambush.Pop >= 6, "the flower slime hides in Salt patches")
	for _, k in { "FlowerSlime", "SlingshotGoblin", "SkeletonArcher" } do
		check(table.find(C.MonsterTypeOrder, k) ~= nil and type(C.Loot.Tables[k]) == "table" and type(C.Barks.Lines[k]) == "table"
			and C.Barks.BubbleFamily[k] ~= nil, k .. ": order, drops, barks, bubble family")
	end
	check(C.Loot.Items.Petal and C.Loot.Items.Petal.Kind == "Material" and C.Loot.Items.Petal.Sell > 0
		and table.find(C.Loot.Order, "Petal") ~= nil, "Petal is a listed sell material")
	local FP = C.ChoiceCard.Kinds.FlowerPatch
	check(FP and FP.Title == "A flower got squished!" and FP.Good.Label == "Replant it" and FP.Evil.Label == "Pick the petals"
		and FP.Evil.Reward.Item == "Petal" and FP.Evil.Reward.N == 2 and type(FP.Good.Reward.XP) == "number"
		and FP.Seconds == nil, "the FlowerPatch card (saved, no timer)", show(FP))
	local KC = C.KillCards.FlowerPatch
	check(KC and KC.Kinds.FlowerSlime == true and KC.Cooldown == 600 and KC.Chance > 0 and KC.Chance <= 1,
		"a Flower Slime kill may offer it, at most once in 10 min a player", show(KC))
end)

runGroup("ranged shot", function()
	local w = mobWorld()
	local C = w.Config
	local M = w.Mob
	local c = zoneCenter(C, "GoblinWoods")
	local rec = w:Rec("SlingshotGoblin", c)
	local R = rec.Def.Ranged
	local p = w:Player(1, c + vec(15, 0, 0))
	local info = { Player = p, Pos = w.RootOf[p].Position }
	M.Shoot(rec, info, 100)
	check(rec._windup ~= nil and rec.Model:GetAttribute("WindupAt") == w.Time and rec._nextAttackAt == 100 + R.Cooldown,
		"in range: a wind-up (WindupAt), the cooldown", show({ rec._nextAttackAt }))
	check(#rec._moves == 1 and near(rec._moves[1], c) and w.H.FACE.Active[rec] ~= nil, "it stands still facing the target")
	local token = rec._windup
	M.Shoot(rec, info, 100.5)
	check(rec._windup == token and #w.Delayed == 1, "one wind-up at a time")
	rec._nextAttackAt = 0 -- even with the cooldown over, a wind-up in progress is never doubled
	M.Shoot(rec, info, 101)
	check(rec._windup == token and #w.Delayed == 1, "a second wind-up never starts during one")
	rec._nextAttackAt = 100 + R.Cooldown
	-- the release after Windup s (nothing before)
	w:Advance(R.Windup - 0.1)
	check(#w.Fxs == 0, "nothing flies during the wind-up (the telegraph)")
	w:Advance(0.1)
	local shot = w.Fxs[1]
	check(shot and shot.P == nil and shot.Kind == "MonsterShot" and near(shot.Data.From, c) and near(shot.Data.To, c + vec(15, 0, 0))
		and shot.Data.Speed == R.Speed and shot.Data.Radius == R.Radius and math.abs(shot.Data.Travel - 15 / R.Speed) < 1e-6,
		"Fx MonsterShot to everyone: From, To (where it stood), Speed, Radius, Travel", show(shot and shot.Data))
	check(rec.Model:GetAttribute("AttackSeq") == 1 and rec._windup == nil, "AttackSeq bumped at the release")
	-- it stays near (half a step, inside the big Radius): hit
	w.RootOf[p].Position = c + vec(15, 0, R.Radius - 0.5)
	w:Advance(15 / R.Speed)
	check(#w.Hits == 1 and w.Hits[1].P == p and w.Hits[1].Dmg == rec.Def.Damage and w.Hits[1].Kind == "SlingshotGoblin",
		"the target still within Radius: hit for the kind's damage", #w.Hits)
end)

runGroup("dodge and rules", function()
	local w = mobWorld()
	local C = w.Config
	local M = w.Mob
	local c = zoneCenter(C, "GoblinWoods")
	local rec = w:Rec("SlingshotGoblin", c)
	local R = rec.Def.Ranged
	-- steps aside during the flight: missed
	local p = w:Player(1, c + vec(15, 0, 0))
	M.Shoot(rec, { Player = p, Pos = w.RootOf[p].Position }, 0)
	w:Advance(R.Windup)
	w.RootOf[p].Position = c + vec(15, 0, R.Radius + 0.5)
	w:Advance(15 / R.Speed)
	check(#w.Hits == 0, "stepping aside (Radius + 0.5) dodges it")
	-- another player standing at the landing point is never hit (the target only)
	local q = w:Player(2, c + vec(10, 0, 0))
	local o = w:Player(3, c + vec(10, 0, 0))
	rec._nextAttackAt = 0
	M.Shoot(rec, { Player = q, Pos = w.RootOf[q].Position }, 10)
	w:Advance(R.Windup)
	w.RootOf[q].Position = c + vec(10, 0, 9)
	w:Advance(10 / R.Speed)
	check(#w.Hits == 0, "only the target can be hit (a bystander on the spot is not)")
	-- the target ran out of range during the wind-up: no shot
	local f0 = #w.Fxs
	rec._nextAttackAt = 0
	M.Shoot(rec, { Player = q, Pos = w.RootOf[q].Position }, 20)
	w.RootOf[q].Position = c + vec(R.Range + 5, 0, 0)
	w:Advance(R.Windup)
	check(#w.Fxs == f0, "out of range at the release: no shot")
	-- the target went into a town during the flight: no hit
	w.RootOf[q].Position = c + vec(12, 0, 0)
	rec._nextAttackAt = 0
	M.Shoot(rec, { Player = q, Pos = w.RootOf[q].Position }, 30)
	w:Advance(R.Windup)
	w.Town[q] = true
	w:Advance(12 / R.Speed)
	check(#w.Hits == 0, "a target that reached a town is not hit")
	w.Town[q] = nil
	-- the monster died before the release: no shot; a shot already flying still lands
	f0 = #w.Fxs
	rec._nextAttackAt = 0
	M.Shoot(rec, { Player = q, Pos = w.RootOf[q].Position }, 40)
	rec.Alive = false
	w:Advance(R.Windup)
	check(#w.Fxs == f0, "dead before the release: no shot")
	rec.Alive = true
	rec._nextAttackAt = 0
	M.Shoot(rec, { Player = q, Pos = w.RootOf[q].Position }, 50)
	w:Advance(R.Windup)
	rec.Alive = false
	w:Advance(12 / R.Speed)
	check(#w.Hits == 1, "a shot already flying when it died still lands")
	-- a dead target: nothing
	rec.Alive = true
	rec._nextAttackAt = 0
	M.Shoot(rec, { Player = q, Pos = w.RootOf[q].Position }, 60)
	w:Advance(R.Windup)
	w.Dead[q] = true
	w:Advance(12 / R.Speed)
	check(#w.Hits == 1, "a dead target is not hit")
	-- the stand goal: Stand studs from the target on the monster's side
	local g = M.StandGoal(c + vec(40, 3, 0), c, R.Stand)
	check(math.abs(flat(g, c) - R.Stand) < 1e-6 and g.X > c.X, "StandGoal: Stand studs from the target, on its own side")
end)

runGroup("flower ambush", function()
	local w = mobWorld()
	local C = w.Config
	local M = w.Mob
	local c = zoneCenter(C, "SlimeMeadow")
	local rec = w:Rec("FlowerSlime", c)
	M.Hide(rec)
	check(rec._hidden == true and rec.Model:GetAttribute("Hidden") == true, "hidden (Hidden attribute)")
	local pop = rec.Def.Ambush.Pop
	local p = w:Player(1, c + vec(pop + 1, 0, 0))
	local plist = { { Player = p, Pos = w.RootOf[p].Position, Zone = "SlimeMeadow", Town = false } }
	check(M.Wake(rec, plist, c) == false and rec._hidden == true, "a player outside Pop: still hidden")
	plist[1].Town = true
	plist[1].Pos = c + vec(1, 0, 0)
	check(M.Wake(rec, plist, c) == false, "a player it may not chase (a town) never wakes it")
	plist[1].Town = false
	check(M.Wake(rec, plist, c) == true and rec._hidden == nil and rec.Model:GetAttribute("Hidden") == false
		and rec.Model:GetAttribute("PopAt") == w.Time, "close: pops out (Hidden off, PopAt for the sparkle)")
	check(#w.Moments == 1 and w.Moments[1].What == "Spot", "its Spot bark")
	M.Show(rec)
	check(#w.Moments == 1, "showing twice does nothing")
end)

runGroup("spawn spots", function()
	-- the flower slime: the first normal spawn point on Salt
	local salt = vec(5, 1, 5)
	local w = mobWorld({ Ground = function(origin) return (math.abs(origin.X - 5) < 1e-6) and "Material.Salt" or "Material.Grass" end })
	local def = w.Config.MonsterTypes.FlowerSlime
	w.Picks = { vec(1, 1, 1), vec(2, 1, 2), salt, vec(7, 1, 7) }
	check(near(w.Mob.Spot(def, "FlowerSlime"), salt), "Ambush: the first spawn point standing on Salt")
	check(w.Rays[1].Params == "params" and w.Rays[1].Dir.Y < 0, "looked down at the ground under each point")
	w.Picks = {}
	for i = 1, 20 do w.Picks[i] = vec(i + 10, 1, 0) end
	check(w.Mob.Spot(def, "FlowerSlime") == nil and #w.Picks == 20 - def.Ambush.Tries, "no Salt in Tries draws: nil (a normal spot)",
		#w.Picks)
	-- the archer: beside a knight without a partner
	local a = mobWorld()
	local C = a.Config
	local adef = C.MonsterTypes.SkeletonArcher
	local c = zoneCenter(C, "SkeletonRuins")
	a:Rec("SkeletonKnight", c)
	local g = a.Mob.Spot(adef, "SkeletonArcher")
	check(g ~= nil and flat(g, c) >= 4 - 1e-6 and flat(g, c) <= 8 + 1e-6, "PartnerOf: 4-8 studs from a lone knight", show(g))
	a:Rec("SkeletonArcher", c + vec(3, 0, 0))
	check(a.Mob.Spot(adef, "SkeletonArcher") == nil, "a knight that has its archer: none (a normal spot)")
	local b = mobWorld()
	check(b.Mob.Spot(adef, "SkeletonArcher") == nil, "no knight alive: none")
end)

runGroup("kill cards", function()
	local w = newWorld()
	local offers, open = {}, { Value = true }
	local monsterKilled = rbxSignal(w.Warnings)
	local reg = { MonsterService = { MonsterKilled = monsterKilled },
		ChoiceCard = { Offer = function(p, kind)
			table.insert(offers, { P = p, Kind = kind })
			return open.Value
		end } }
	local svc = w:Load("KillCardService", KILLCARD_SOURCE)
	svc.Init(reg)
	svc.Start()
	local p = w:NewPlayer(1)
	local K = w.Config.KillCards.FlowerPatch
	-- a roll below Chance: offered
	w.Script = { K.Chance - 0.01 }
	monsterKilled:Fire(p, { Kind = "FlowerSlime" })
	check(#offers == 1 and offers[1].P == p and offers[1].Kind == "FlowerPatch", "a Flower Slime kill (lucky roll): the card")
	-- within the cooldown: none, even with a lucky roll
	w.Clock += K.Cooldown - 1
	w.Script = { 0 }
	monsterKilled:Fire(p, { Kind = "FlowerSlime" })
	check(#offers == 1, "at most once per 10 min a player")
	w.Clock += 2
	w.Script = { 0 }
	monsterKilled:Fire(p, { Kind = "FlowerSlime" })
	check(#offers == 2, "after the cooldown: again")
	-- an unlucky roll: none; another kind: none
	w.Clock += K.Cooldown + 1
	w.Script = { K.Chance + 0.01 }
	monsterKilled:Fire(p, { Kind = "FlowerSlime" })
	check(#offers == 2, "an unlucky roll: no card")
	w.Script = { 0 }
	monsterKilled:Fire(p, { Kind = "Slime" })
	check(#offers == 2, "a green slime never squishes a flower")
	-- a card already open (Offer false): the cooldown does not start
	open.Value = false
	w.Script = { 0 }
	monsterKilled:Fire(p, { Kind = "FlowerSlime" })
	open.Value = true
	w.Script = { 0 }
	monsterKilled:Fire(p, { Kind = "FlowerSlime" })
	check(#offers == 4, "a refused offer (a card open) keeps the next chance", #offers)
	-- a player who left: nothing
	local q = w:NewPlayer(2)
	w:Remove(q)
	w.Script = { 0 }
	monsterKilled:Fire(q, { Kind = "FlowerSlime" })
	check(#offers == 4, "a player who left gets nothing")
end)

finish()
