-- skills_x_offline.luau : SKL-3 X skills (docs/design/skill_kit_beta_2026-10-06.md §1-§4, §10; A23-71 X at Lv25) server
-- checks. tools/test_skills_x.py binds the tools/test_skills.py sources (the real SkillService, CombatService,
-- DamageWindow, StoryQuestService ...) plus VITALS_EXTRACT and ZONE_EXTRACT; dev2_kit.luau and dev2_combat_world.luau
-- come first. Players face -Z at the origin; monsters are records `dz` studs in front. Rules checked: Roar (the hits,
-- the taunt, my Guard, Halo friends, Horns MP, the anvil, the switches), Field (the circle, 1 s ticks with one cast id,
-- the slow, friends / MP per tick, what ends it, never players, the burst with Fields off), Hop (back as far as
-- HopReach allows, the refusals before MP, the wind, AllowMove, friends at the landing, the tamer), the X auto rules and
-- the X -> Z -> Q order, XEnabled / Lv25; and the real code cut from MonsterService (Taunt, Slow, HopReach, DamageMonster's
-- one hit a cast, NATURAL.Pace's slow), VitalsService.AddMana and ZoneService.AllowMove.

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
if not vmt.__unm then vmt.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end end

-- a world with SkillService, Z and X on (o.Z / o.X = false: off), PvPZX (o.PvP), the §10 switches (o.Taunt / o.Fields /
-- o.Move = false), o.Hit = every pair may fight (PvPService double)
local function xWorld(o)
	o = o or {}
	local w = bareWorld({ Hit = o.Hit })
	local K = w.Config.Skills
	K.ZEnabled, K.XEnabled, K.PvPZX = o.Z ~= false, o.X ~= false, o.PvP == true
	if o.Taunt == false then K.Taunt = false end
	if o.Fields == false then K.Fields = false end
	if o.Move == false then K.MoveSkills = false end
	-- a KO runs CombatService's death pipeline: its other services are quiet doubles here
	local reg = w.Registry
	reg.GrudgeService.OnCarrierDown = function() end
	reg.PvPService.HandleKO = function() end
	reg.PvPService.HandleNonPvPDeath = function() end
	reg.KaijuService.HandleKaijuDeath = function() end
	w.Rel = {}
	w.Combat.Released:Connect(function(p, info) table.insert(w.Rel, { P = p, Info = info }) end)
	-- a ready Lv25 hero (all three skills) with MP and the class weapon; jo as w:Join plus Mana
	function w:Hero(id, jo)
		jo = jo or {}
		jo.Level = jo.Level or 25
		jo.Tier, jo.Mask = jo.Tier or 1, jo.Mask or 1
		jo.Attrs = jo.Attrs or {}
		jo.Attrs.Mana = jo.Mana or 100
		return self:Join(id, jo)
	end
	function w:Use(p, ...)
		self:Advance(0.11) -- RateLimits.UseSkill
		self.Net.Get("UseSkill").OnServerEvent:Fire(p, ...)
		self:Flush()
	end
	function w:Count(slot)
		local n = 0
		for _, r in self.Rel do if r.Info.Slot == slot then n += 1 end end
		return n
	end
	function w:Last(slot)
		for i = #self.Rel, 1, -1 do
			if slot == nil or self.Rel[i].Info.Slot == slot then return self.Rel[i].Info end
		end
		return nil
	end
	function w:Press(p, from)
		local out = {}
		for i = (from or 0) + 1, #self.Fx do
			local f = self.Fx[i]
			if f.Kind == "SkillPress" and f.Player == p then table.insert(out, f.Data.Slot .. ":" .. f.Data.Result) end
		end
		return table.concat(out, ",")
	end
	function w:ManaSpent(p, from)
		local n = 0
		for i = (from or 0) + 1, #self.Mana do
			if self.Mana[i].P == p then n += self.Mana[i].Cost end
		end
		return n
	end
	-- the MP the skills added to `p` (VitalsService.AddMana double)
	function w:Gain(p, from)
		local n = 0
		for i = (from or 0) + 1, #self.Gained do
			if self.Gained[i].P == p then n += self.Gained[i].N end
		end
		return n
	end
	-- the data of every Fx `kind` sent to `p` since index `from`
	function w:FxTo(kind, p, from)
		local out = {}
		for i = (from or 0) + 1, #self.Fx do
			local f = self.Fx[i]
			if f.Kind == kind and f.Player == p then table.insert(out, f.Data) end
		end
		return out
	end
	-- a KO: the humanoid at 0, then CharacterDied (CombatService's death pipeline runs on its doubles)
	function w:KO(p)
		p.Character:FindFirstChild("Humanoid").Health = 0
		self.PS.CharacterDied:Fire(p, p.Character)
		self:Flush()
	end
	return w
end

local function hitOf(w, rec, from)
	local n = 0
	for i = (from or 0) + 1, #w.Damage do
		if w.Damage[i].Rec == rec then n += w.Damage[i].N end
	end
	return n
end

local function dealtX(w, p, mult)
	return w.Util.RoundDamage(w.Combat.ComputeMonsterHit(p, false) * mult)
end

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end

------------------------------------------------------------------ the numbers (Config.Skills.Defs X, SKL-1 tables)
runGroup("x config", function()
	local K0 = C0.Skills
	check(K0.XEnabled == false and K0.Taunt == true and K0.Fields == true and K0.MoveSkills == true and K0.MPStealCap == 20
		and K0.Unlock.X == 25, "XEnabled off until the 10/20 check; Taunt / Fields / MoveSkills on; MP steal cap 20; X at Lv25",
		show({ K0.XEnabled, K0.Taunt, K0.Fields, K0.MoveSkills, K0.MPStealCap, K0.Unlock.X }))
	local function def(cls, fac) return C0.SkillDef(cls, fac, "X") end
	local rh, rd = def("Warrior", "Halo"), def("Warrior", "Horns")
	check(rh.Shape == "Roar" and rh.Radius == 12 and rh.Mult == 2 and rh.TauntRadius == 16 and rh.TauntSec == 4
		and rh.SelfGuard == 0.4 and rh.GuardSec == 6 and rh.MP == 30 and rh.CD == 15 and rh.AllyGuard == 0.2 and rh.AllyRadius == 16
		and rh.MPSteal == nil, "Guardian Roar: r12 x2, taunt 16 for 4 s, my Guard 40% 6 s, Halo friends 20% within 16, MP 30, 15 s",
		show(rh))
	check(rd.MPSteal == 5 and rd.AllyGuard == nil and rd.SelfGuard == 0.4, "Rage Roar: +5 MP a monster hit, no friend Guard (its own stays)",
		show(rd))
	local fh, fd = def("Mage", "Halo"), def("Mage", "Horns")
	check(fh.Shape == "Field" and fh.Range == 35 and fh.Ahead == 10 and fh.Radius == 12 and fh.Duration == 5 and fh.Tick == 1
		and fh.TickMult == 1.5 and fh.Slow == 0.5 and fh.MP == 30 and fh.CD == 14 and fh.AllyGuard == 0.2 and fd.MPStealTick == 2
		and fd.AllyGuard == nil, "Sun / Hex Circle: r12 at the aimed monster (35), 5 ticks x1.5, slow x0.5; Halo friends 20%, Horns 2 MP a monster a tick",
		show(fh))
	local hh, hd = def("Archer", "Halo"), def("Archer", "Horns")
	check(hh.Shape == "Hop" and hh.Hop == 10 and hh.HopTime == 0.25 and hh.Radius == 7 and hh.Mult == 3 and hh.Push == 6 and hh.MP == 25
		and hh.CD == 10 and hh.Auto.Never == true and hh.AllyGuard == 0.2 and hh.AllyRadius == 12 and hh.GuardSec == 4
		and hd.MPSteal == 5, "Light / Shadow Step: 10 back in 0.25 s, the wind r7 x3 push 6, never auto; Halo friends 20% 4 s, Horns +5 MP",
		show(hh))
	local anvil, brew, boing = def("Warrior", "Neutral"), def("Mage", "Neutral"), def("Archer", "Neutral")
	check(anvil.Kit == "Blacksmith" and anvil.Shape == "Roar" and anvil.Craft == "Anvil" and anvil.CraftSec == 6
		and anvil.AllyGuard == nil and anvil.MPSteal == nil and brew.Kit == "Alchemist" and brew.Shape == "Field"
		and brew.Craft == "Cauldron" and brew.AllyGuard == nil and brew.MPStealTick == nil and boing.Kit == "Tamer"
		and boing.Shape == "Hop" and boing.Craft == "BigSlime", "the artisans: Anvil Guard / Jelly Brew / Big Boing, the same shapes with a crafted look, no faction extras",
		show({ anvil.Kit, brew.Kit, boing.Kit }))
end)

------------------------------------------------------------------ Roar (Warrior X)
runGroup("x roar", function()
	local w = xWorld()
	local p = w:Hero(1, { Class = "Warrior", Faction = "Halo" })
	local m1, m2 = w:Monster("Slime", 5, 0, 99999), w:Monster("Slime", 11, 0, 99999)
	local m3, m4 = w:Monster("Slime", 14, 0, 99999), w:Monster("Slime", 20, 0, 99999)
	local ally = w:Hero(2, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 10) })
	local far = w:Hero(3, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 20) })
	local foe = w:Hero(4, { Class = "Mage", Faction = "Horns", Pos = vec(0, 0, 5) })
	check(p:GetAttribute("SkillSlots") == 3, "setup: a Lv25 hero has Q, Z and X", p:GetAttribute("SkillSlots"))
	local f0 = #w.Fx
	w:Use(p, "X")
	local d2 = dealtX(w, p, 2)
	check(w:Count("X") == 1 and w:ManaSpent(p) == 30 and near(p:GetAttribute("SkillReadyAtX"), w.Time + 15),
		"Guardian Roar: MP 30, SkillReadyAtX = now + 15 s", show({ w:Count("X"), w:ManaSpent(p), p:GetAttribute("SkillReadyAtX") }))
	check(hitOf(w, m1) == d2 and hitOf(w, m2) == d2 and hitOf(w, m3) == 0 and hitOf(w, m4) == 0,
		"it hits the monsters within 12 studs (x2), not 14 or 20 away", show({ hitOf(w, m1), hitOf(w, m2), hitOf(w, m3), d2 }))
	local taunted = {}
	for _, t in w.Taunts do taunted[t.Rec] = t end
	check(#w.Taunts == 3 and taunted[m1] and taunted[m2] and taunted[m3] and not taunted[m4] and taunted[m3].Sec == 4
		and taunted[m3].P == p, "the taunt: every monster within 16 (5, 11, 14 away) for 4 s", #w.Taunts)
	local sk = w:FxTo("Skill", p, f0)[1]
	check(sk and sk.Shape == "Roar" and sk.Slot == "X" and sk.Radius == 12 and sk.Statuses.Taunted == 3 and #sk.Hits == 2,
		"Fx Skill { Shape Roar, Radius 12, 2 hits, Statuses.Taunted 3 }", show(sk and { sk.Shape, sk.Radius, #sk.Hits }))
	check(near(w.Skills.GuardOf(p), 0.4) and p:GetAttribute("GuardPct") == 0.4 and near(p:GetAttribute("GuardUntil"), w.Time + 6),
		"my Guard: 40%, GuardPct / GuardUntil = now + 6 s", show({ w.Skills.GuardOf(p), p:GetAttribute("GuardUntil"), w.Time }))
	check(near(w.Skills.GuardOf(ally), 0.2) and ally:GetAttribute("GuardPct") == 0.2 and w.Skills.GuardOf(far) == 0
		and w.Skills.GuardOf(foe) == 0, "Halo friends within 16: 20%; a friend 20 away or a Horn: none",
		show({ w.Skills.GuardOf(ally), w.Skills.GuardOf(far), w.Skills.GuardOf(foe) }))
	local G = sk and sk.Statuses.Guard
	check(G and #G == 2 and G[1].V == p.UserId and G[1].Pct == 0.4 and G[1].Sec == 6 and G[2].V == ally.UserId and G[2].Pct == 0.2
		and G[2].Sec == 6, "Statuses.Guard: me (40%, 6 s), then the friend (20%, 6 s)", show(G))
	check(sk and sk.Statuses.MP == nil and #w.Gained == 0, "a Halo roar takes no MP", #w.Gained)
	-- CombatService.DamagePlayer: only a monster's hit is cut by the Guard
	local horn = w:Hero(5, { Class = "Warrior", Faction = "Horns", Pos = vec(40, 0, 0) })
	local a1 = w.Combat.DamagePlayer(p, 10, nil, false, "Slime")
	local a2 = w.Combat.DamagePlayer(p, 10, nil, false, "Kaiju")
	local a3 = w.Combat.DamagePlayer(p, 10, horn, false)
	check(a1 == 6 and a2 == 10 and a3 == 10, "40% Guard: a slime's 10 -> 6; a kaiju's 10 and a player's 10 stay 10", show({ a1, a2, a3 }))
	w:Advance(6)
	check(w.Skills.GuardOf(p) == 0 and w.Combat.DamagePlayer(p, 10, nil, false, "Slime") == 10, "6 s later: no Guard, a slime's 10 is 10 again",
		w.Skills.GuardOf(p))

	-- the larger Guard wins (time kept); the same one is extended; a real respawn clears it, a cosmetic one keeps it
	local w2 = xWorld()
	local a = w2:Hero(1, { Class = "Warrior", Faction = "Halo" })
	local b = w2:Hero(2, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, 10) })
	local c = w2:Hero(3, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 5) })
	w2:Monster("Slime", 5, 0, 99999)
	w2:Use(b, "X")
	check(near(w2.Skills.GuardOf(b), 0.4) and near(w2.Skills.GuardOf(a), 0.2) and near(w2.Skills.GuardOf(c), 0.2),
		"setup: b roars (40%), a and c are b's friends (20%)", show({ w2.Skills.GuardOf(b), w2.Skills.GuardOf(a), w2.Skills.GuardOf(c) }))
	local bUntil = b:GetAttribute("GuardUntil")
	w2:Advance(2)
	w2:Use(a, "X")
	check(near(w2.Skills.GuardOf(a), 0.4) and near(w2.Skills.GuardOf(b), 0.4) and b:GetAttribute("GuardUntil") == bUntil,
		"a friend's 20% never replaces my 40% (my time stays)", show({ w2.Skills.GuardOf(b), b:GetAttribute("GuardUntil"), bUntil }))
	check(near(c:GetAttribute("GuardUntil"), w2.Time + 6), "the same 20% again: extended to the new 6 s", show({ c:GetAttribute("GuardUntil"), w2.Time }))
	w2:Advance(4.5) -- past b's first 6 s, inside a's
	check(near(w2.Skills.GuardOf(c), 0.2) and w2.Skills.GuardOf(b) == 0, "c is still guarded by the extension; b's own ran out", show({ w2.Skills.GuardOf(c), w2.Skills.GuardOf(b) }))
	w2.PS.CharacterSpawned:Fire(c, c.Character, c.Character:FindFirstChild("Humanoid"), true)
	check(near(w2.Skills.GuardOf(c), 0.2), "a cosmetic respawn keeps the Guard", w2.Skills.GuardOf(c))
	w2.PS.CharacterSpawned:Fire(c, c.Character, c.Character:FindFirstChild("Humanoid"), false)
	check(w2.Skills.GuardOf(c) == 0 and c:GetAttribute("GuardPct") == 0 and c:GetAttribute("GuardUntil") == 0,
		"a real respawn clears the Guard (GuardPct / GuardUntil 0)", show({ w2.Skills.GuardOf(c), c:GetAttribute("GuardPct") }))

	-- Horns: +5 MP a monster hit, at most 20 a cast, only what the MP bar takes
	local w3 = xWorld()
	local h = w3:Hero(1, { Class = "Warrior", Faction = "Horns" })
	w3:Monster("Slime", 4, 0, 99999)
	w3:Monster("Slime", 8, 0, 99999)
	local f3 = #w3.Fx
	w3:Use(h, "X")
	local sk3 = w3:FxTo("Skill", h, f3)[1]
	check(w3:Gain(h) == 10 and sk3 and sk3.Statuses.MP == 10, "Rage Roar on 2 monsters: +10 MP (5 each), Statuses.MP 10",
		show({ w3:Gain(h), sk3 and sk3.Statuses.MP }))
	check(near(w3.Skills.GuardOf(h), 0.4) and sk3 and #sk3.Statuses.Guard == 1, "a Horn's roar guards itself too (40%), no friends",
		w3.Skills.GuardOf(h))
	local w4 = xWorld()
	local h4 = w4:Hero(1, { Class = "Warrior", Faction = "Horns" })
	for i = 1, 5 do w4:Monster("Slime", 2 * i, 0, 99999) end
	w4:Use(h4, "X")
	check(w4:Gain(h4) == 20 and w4:Last("X").MonstersHit == 5, "5 monsters hit (25 MP): capped at 20 a cast", w4:Gain(h4))
	local w5 = xWorld()
	local h5 = w5:Hero(1, { Class = "Warrior", Faction = "Horns" })
	w5:Monster("Slime", 4, 0, 99999)
	w5:Monster("Slime", 8, 0, 99999)
	w5.ManaRoom[h5] = 3
	local f5 = #w5.Fx
	w5:Use(h5, "X")
	check(w5:Gain(h5) == 3 and w5:FxTo("Skill", h5, f5)[1].Statuses.MP == 3, "the MP bar takes only 3 more: +3 (Statuses.MP 3)", w5:Gain(h5))

	-- the blacksmith's Anvil Guard: the taunt and its own Guard, the anvil look; no friends, no MP
	local w6 = xWorld()
	local smith = w6:Hero(1, { Class = "Warrior", Faction = "Neutral" })
	local friend = w6:Hero(2, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 5) })
	w6:Monster("Slime", 4, 0, 99999)
	w6:Monster("Slime", 8, 0, 99999)
	local f6 = #w6.Fx
	w6:Use(smith, "X")
	local sk6 = w6:FxTo("Skill", smith, f6)[1]
	check(sk6 and sk6.Kit == "Blacksmith" and sk6.Craft == "Anvil" and sk6.CraftSec == 6 and sk6.Statuses.Taunted == 2,
		"Anvil Guard: Fx Craft Anvil (6 s), the taunt", show(sk6 and { sk6.Kit, sk6.Craft, sk6.CraftSec }))
	check(near(w6.Skills.GuardOf(smith), 0.4) and w6.Skills.GuardOf(friend) == 0 and sk6 and sk6.Statuses.MP == nil and #w6.Gained == 0,
		"the artisan guards only itself: no friend Guard, no MP", show({ w6.Skills.GuardOf(smith), w6.Skills.GuardOf(friend) }))

	-- §10 Taunt off: no taunt (the hit and the Guard stay); a refused taunt is not counted
	local w7 = xWorld({ Taunt = false })
	local p7 = w7:Hero(1, { Class = "Warrior", Faction = "Halo" })
	local s7 = w7:Monster("Slime", 4, 0, 99999)
	local f7 = #w7.Fx
	w7:Use(p7, "X")
	local sk7 = w7:FxTo("Skill", p7, f7)[1]
	check(#w7.Taunts == 0 and sk7 and sk7.Statuses.Taunted == nil and hitOf(w7, s7) > 0 and near(w7.Skills.GuardOf(p7), 0.4),
		"Skills.Taunt off: no taunt, the hit and my Guard stay", show({ #w7.Taunts, hitOf(w7, s7) }))
	local w8 = xWorld()
	local p8 = w8:Hero(1, { Class = "Warrior", Faction = "Halo" })
	w8:Monster("Slime", 4, 0, 99999)
	w8:Monster("Slime", 8, 0, 99999)
	w8.TauntRefuse = true
	local f8 = #w8.Fx
	w8:Use(p8, "X")
	check(#w8.Taunts == 2 and w8:FxTo("Skill", p8, f8)[1].Statuses.Taunted == 0, "MonsterService refuses the taunts (a boss, someone else's): Taunted 0",
		#w8.Taunts)
end)

------------------------------------------------------------------ Field (Mage X)
runGroup("x field", function()
	local w = xWorld()
	local p = w:Hero(1, { Class = "Mage", Faction = "Halo" })
	local a = w:Monster("Slime", 20, 0, 99999)
	local b = w:Monster("Slime", 26, 0, 99999)
	local weak = w:Monster("Slime", 22, 0, 1)
	local c = w:Monster("Slime", 40, 0, 99999)
	local friend = w:Hero(2, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, -24) })
	local f0, d0 = #w.Fx, #w.Damage
	w:Use(p, "X")
	local d15 = dealtX(w, p, 1.5)
	local sk = w:FxTo("Skill", p, f0)[1]
	check(w:Count("X") == 1 and w:ManaSpent(p) == 30 and near(p:GetAttribute("SkillReadyAtX"), w.Time + 14),
		"Sun Circle: MP 30, SkillReadyAtX = now + 14 s", show({ w:Count("X"), w:ManaSpent(p) }))
	check(sk and sk.Shape == "Field" and sk.Center.X == 0 and sk.Center.Z == -20 and sk.Radius == 12 and sk.Life == 5 and sk.Tick == 1
		and #sk.Hits == 3, "Fx Skill { Shape Field, Center = the aimed slime 20 ahead, Radius 12, Life 5, Tick 1 }",
		show(sk and { sk.Center and sk.Center.Z, sk.Radius, sk.Life, sk.Tick, #sk.Hits }))
	check(hitOf(w, a) == d15 and hitOf(w, b) == d15 and hitOf(w, c) == 0 and weak.Alive == false,
		"the first tick at once: x1.5 on everything inside (one dies), nothing 20 away", show({ hitOf(w, a), hitOf(w, b), hitOf(w, c), d15 }))
	check(w:Count("X") == 1 and w:Last("X").MonstersHit == 3 and w:Last("X").Auto == false, "Released once, at the first tick (3 monsters)",
		show(w:Last("X")))
	check(#w.Slows == 2 and w.Slows[1].Mult == 0.5 and w.Slows[1].Sec == 1.5 and w.Slows[1].Rec ~= weak and w.Slows[2].Rec ~= weak,
		"the living ones are slowed x0.5 for 1.5 s (the tick + 0.5); the dead one is not", #w.Slows)
	check(near(w.Skills.GuardOf(friend), 0.2) and w.Skills.GuardOf(p) == 0, "a Halo friend inside the circle: 20%; the caster outside it: none",
		show({ w.Skills.GuardOf(friend), w.Skills.GuardOf(p) }))
	for _ = 1, 4 do w:Advance(1) end
	local ticks = w:FxTo("SkillTick", p, f0)
	check(#ticks == 4 and ticks[1].Slot == "X" and ticks[1].Radius == 12 and ticks[1].Center.Z == -20 and #ticks[1].Hits == 2
		and ticks[4].Total == 2 * d15, "four more ticks, 1 s apart: Fx SkillTick { Slot X, Center, Radius, Hits, Total }",
		show({ #ticks, ticks[1] and #ticks[1].Hits }))
	check(hitOf(w, a) == 5 * d15 and hitOf(w, b) == 5 * d15, "each monster inside takes 5 ticks of x1.5", show({ hitOf(w, a), 5 * d15 }))
	local ids, n = {}, 0
	for i = d0 + 1, #w.Damage do
		local id = w.Damage[i].Cast
		if id ~= nil and not ids[id] then n += 1 end
		if id ~= nil then ids[id] = true end
	end
	check(n == 1 and w.Damage[d0 + 1].Cast ~= nil and w.Damage[#w.Damage].Cast == w.Damage[d0 + 1].Cast,
		"every tick hits with the same cast id (MonsterService counts one hit a cast)", n)
	check(w:Count("X") == 1 and #w.Slows == 10, "still one Released; the living monsters are slowed again on every tick",
		show({ w:Count("X"), #w.Slows }))
	check(ticks[4].Statuses.Guard and ticks[4].Statuses.Guard[1].V == friend.UserId and near(ticks[4].Statuses.Guard[1].Sec, 1.1),
		"each tick guards the friend again (1.1 s)", show(ticks[4].Statuses))
	w:Advance(1)
	w:Advance(1)
	check(#w:FxTo("SkillTick", p, f0) == 4 and hitOf(w, a) == 5 * d15, "after 5 ticks the field is gone (no 6th)", #w:FxTo("SkillTick", p, f0))
	check(#w:FxTo("SkillEnd", p, f0) == 0, "a field that ran out sends no SkillEnd (its circle ends with Life)", #w:FxTo("SkillEnd", p, f0))
	check(w.Skills.GuardOf(friend) == 0, "the friend's Guard ends 1.1 s after the last tick", w.Skills.GuardOf(friend))

	-- Horns: 2 MP a monster a tick, at most 20 a cast
	local w2 = xWorld()
	local h = w2:Hero(1, { Class = "Mage", Faction = "Horns" })
	w2:Monster("Slime", 16, 0, 99999)
	w2:Monster("Slime", 20, 0, 99999)
	w2:Monster("Slime", 24, 0, 99999)
	w2:Use(h, "X")
	local g = { w2:Gain(h) }
	for _ = 1, 4 do
		w2:Advance(1)
		table.insert(g, w2:Gain(h))
	end
	check(g[1] == 6 and g[2] == 12 and g[3] == 18 and g[4] == 20 and g[5] == 20, "Hex Circle on 3 monsters: +6 MP a tick, 20 a cast in all",
		show(g))
	check(w2.Skills.GuardOf(h) == 0, "a field guards nobody on the Horn side", w2.Skills.GuardOf(h))

	-- what ends a field: a KO, a zone change, a class / faction change, a kaiju (at the tick), a new character, leaving,
	-- a new field
	local function fieldWorld(cd)
		local fw = xWorld()
		local fp = fw:Hero(1, { Class = "Mage", Faction = "Halo" })
		if cd then fw.Config.SkillDef("Mage", "Halo", "X").CD = cd end
		fw:Monster("Slime", 20, 0, 99999)
		fw:Use(fp, "X")
		return fw, fp, #fw.Fx
	end
	local function ends(fw, fp, from)
		local out = {}
		for _, e in fw:FxTo("SkillEnd", fp, from) do table.insert(out, e.Why) end
		return table.concat(out, ",")
	end
	local wd, pd, fd = fieldWorld()
	wd:KO(pd)
	wd:Advance(1)
	check(ends(wd, pd, fd) == "Died" and #wd:FxTo("SkillTick", pd, fd) == 0, "a KO ends it at once (SkillEnd Died), no tick after",
		show({ ends(wd, pd, fd), #wd:FxTo("SkillTick", pd, fd) }))
	check(wd:FxTo("SkillEnd", pd, fd)[1].Slot == "X" and wd:FxTo("SkillEnd", pd, fd)[1].UserId == pd.UserId, "SkillEnd { UserId, Slot X, Why }",
		show(wd:FxTo("SkillEnd", pd, fd)[1]))
	local wz, pz, fz = fieldWorld()
	wz.Registry.ZoneService.ZoneChanged:Fire(pz, "SlimeMeadow", "SlimeMeadow")
	wz:Advance(1)
	check(ends(wz, pz, fz) == "" and #wz:FxTo("SkillTick", pz, fz) == 1, "a zone signal for the same zone keeps it", ends(wz, pz, fz))
	wz.ZoneOf[pz] = "Crossroads"
	wz.Registry.ZoneService.ZoneChanged:Fire(pz, "Crossroads", "SlimeMeadow")
	wz:Advance(1)
	check(ends(wz, pz, fz) == "Zone" and #wz:FxTo("SkillTick", pz, fz) == 1, "walking into another zone ends it (Zone)", ends(wz, pz, fz))
	local wc, pc, fc = fieldWorld()
	wc.Registry.ClassService.ClassChanged:Fire(pc, "Warrior", "Mage")
	local wf, pf, ff = fieldWorld()
	wf.Registry.FactionService.FactionChanged:Fire(pf, "Horns", "Halo", "Altar")
	check(ends(wc, pc, fc) == "Changed" and ends(wf, pf, ff) == "Changed", "a class or faction change ends it (Changed)",
		show({ ends(wc, pc, fc), ends(wf, pf, ff) }))
	local wk, pk, fk = fieldWorld()
	wk.KaijuOf[pk] = "Siren"
	wk:Advance(1)
	check(ends(wk, pk, fk) == "Stop" and #wk:FxTo("SkillTick", pk, fk) == 0, "turning into a kaiju ends it at the next tick (Stop)",
		ends(wk, pk, fk))
	local wr, pr, fr = fieldWorld()
	wr:Body(pr)
	wr:Advance(1)
	check(ends(wr, pr, fr) == "Stop", "a new character ends it at the next tick (Stop)", ends(wr, pr, fr))
	local wl, pl, fl = fieldWorld()
	wl.PS.PlayerLeaving:Fire(pl)
	wl:Remove(pl)
	wl:Advance(1)
	wl:Advance(1)
	local after = 0
	for i = fl + 1, #wl.Fx do
		if wl.Fx[i].Kind == "SkillEnd" or wl.Fx[i].Kind == "SkillTick" then after += 1 end
	end
	check(after == 0, "leaving ends it quietly (no SkillEnd, no more ticks)", after)
	local wn, pn, fn = fieldWorld(1)
	local firstId = wn.Damage[#wn.Damage].Cast
	wn:Advance(1) -- tick 2
	wn:Use(pn, "X") -- the 1 s cooldown is over: a new field
	check(wn:Count("X") == 2 and ends(wn, pn, fn) == "New", "a new field ends the old one (SkillEnd New)", show({ wn:Count("X"), ends(wn, pn, fn) }))
	local newId = wn.Damage[#wn.Damage].Cast
	local t0 = #wn:FxTo("SkillTick", pn, fn)
	wn:Advance(1)
	wn:Advance(1)
	check(newId ~= firstId and #wn:FxTo("SkillTick", pn, fn) - t0 == 2, "one field a player: only the new one ticks (a new cast id)",
		show({ firstId, newId, #wn:FxTo("SkillTick", pn, fn) - t0 }))

	-- never a player: an enemy nearer than the slime is not aimed at and not hit (PvPZX on)
	local wp = xWorld({ Hit = true, PvP = true })
	local mage = wp:Hero(1, { Class = "Mage", Faction = "Halo" })
	local enemy = wp:Hero(2, { Class = "Warrior", Faction = "Horns", Pos = vec(0, 0, -15) })
	wp:Monster("Slime", 20, 0, 99999)
	local fp0 = #wp.Fx
	wp:Use(mage, "X")
	for _ = 1, 5 do wp:Advance(1) end
	local skp = wp:FxTo("Skill", mage, fp0)[1]
	check(skp and skp.Center.Z == -20 and enemy.Character:FindFirstChild("Humanoid").Health == 100,
		"PvPZX on: the circle sits on the slime, not the nearer enemy, and never hits the enemy inside it",
		show({ skp and skp.Center.Z, enemy.Character:FindFirstChild("Humanoid").Health }))
	-- no monster within 35: the circle goes 10 studs ahead (the cast still goes off)
	local wa = xWorld()
	local pa = wa:Hero(1, { Class = "Mage", Faction = "Halo" })
	wa:Use(pa, "X")
	local ska = wa:FxTo("Skill", pa, 0)[1]
	check(wa:Count("X") == 1 and ska and ska.Center.X == 0 and ska.Center.Z == -10, "nothing in reach: the circle 10 studs ahead",
		show(ska and ska.Center))
	-- §10 Fields off: one burst of all 5 ticks, a 3 s slow, the short mark, no ticks
	local wb = xWorld({ Fields = false })
	local pb = wb:Hero(1, { Class = "Mage", Faction = "Halo" })
	local sb = wb:Monster("Slime", 20, 0, 99999)
	local fb = #wb.Fx
	wb:Use(pb, "X")
	local skb = wb:FxTo("Skill", pb, fb)[1]
	check(hitOf(wb, sb) == dealtX(wb, pb, 7.5) and skb and skb.Life == 0.3 and #wb.Slows == 1 and wb.Slows[1].Sec == 3,
		"Skills.Fields off: one burst x7.5, a 3 s slow, the 0.3 s mark", show({ hitOf(wb, sb), dealtX(wb, pb, 7.5), skb and skb.Life }))
	wb:Advance(1)
	wb:Advance(1)
	check(#wb:FxTo("SkillTick", pb, fb) == 0 and hitOf(wb, sb) == dealtX(wb, pb, 7.5), "no ticks after the burst", #wb:FxTo("SkillTick", pb, fb))
	-- the alchemist's Jelly Brew: the cauldron look, no friends, no MP
	local wj = xWorld()
	local alc = wj:Hero(1, { Class = "Mage", Faction = "Neutral" })
	local pal = wj:Hero(2, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, -22) })
	wj:Monster("Slime", 20, 0, 99999)
	local fj = #wj.Fx
	wj:Use(alc, "X")
	local skj = wj:FxTo("Skill", alc, fj)[1]
	check(skj and skj.Kit == "Alchemist" and skj.Craft == "Cauldron" and wj.Skills.GuardOf(pal) == 0 and #wj.Gained == 0,
		"Jelly Brew: Fx Craft Cauldron; no friend Guard, no MP", show(skj and { skj.Kit, skj.Craft }))
end)

------------------------------------------------------------------ Hop (Archer X)
runGroup("x hop", function()
	local w = xWorld()
	local p = w:Hero(1, { Class = "Archer", Faction = "Halo" })
	local m1, m2, m3 = w:Monster("Slime", 3, 0, 99999), w:Monster("Slime", 6, 0, 99999), w:Monster("Slime", 9, 0, 99999)
	local landing = w:Hero(2, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, 15) })
	local away = w:Hero(3, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, -15) })
	local f0 = #w.Fx
	w:Use(p, "X")
	local hop = w:FxTo("Hop", p, f0)
	check(w:Count("X") == 1 and w:ManaSpent(p) == 25 and #hop == 1 and hop[1].To.X == 0 and hop[1].To.Z == 10 and hop[1].T == 0.25,
		"Light Step: MP 25, Fx Hop { To = 10 studs straight back, T = 0.25 }", show(hop[1]))
	local toOthers = 0
	for i = f0 + 1, #w.Fx do
		if w.Fx[i].Kind == "Hop" and w.Fx[i].Player ~= p then toOthers += 1 end
	end
	check(toOthers == 0, "the Hop Fx goes to the caster only", toOthers)
	check(#w.HopAsks == 1 and w.HopAsks[1].Studs == 10 and w.HopAsks[1].Dir.Z == 1 and w.HopAsks[1].From.Z == 0,
		"MonsterService.HopReach asked for 10 studs straight back from where I stand", show(w.HopAsks[1]))
	check(#w.Allowed == 1 and w.Allowed[1].P == p and w.Allowed[1].Studs == 12 and w.Allowed[1].Sec == 1,
		"ZoneService.AllowMove(me, 10 + 2, 1 s): the movement check takes the hop", show(w.Allowed[1] and { w.Allowed[1].Studs, w.Allowed[1].Sec }))
	local d3 = dealtX(w, p, 3)
	check(hitOf(w, m1) == d3 and hitOf(w, m2) == d3 and hitOf(w, m3) == 0, "the wind hits within 7 of the spot I left (x3), not 9 away",
		show({ hitOf(w, m1), hitOf(w, m2), hitOf(w, m3), d3 }))
	check(#w.Displaced == 2 and w.Displaced[1].Mode == "Push" and w.Displaced[1].Studs == 6, "the wind pushes them 6", #w.Displaced)
	local sk = w:FxTo("Skill", p, f0)[1]
	check(sk and sk.Shape == "Hop" and sk.To.Z == 10 and sk.Center.Z == 0 and sk.Radius == 7,
		"Fx Skill { Shape Hop, To = the landing spot, Center = the spot I left, Radius 7 }", show(sk and { sk.Shape, sk.Radius }))
	check(near(w.Skills.GuardOf(landing), 0.2) and near(landing:GetAttribute("GuardUntil"), w.Time + 4) and w.Skills.GuardOf(away) == 0,
		"Halo friends within 12 of the landing spot: 20% for 4 s; one 25 away: none", show({ w.Skills.GuardOf(landing), w.Skills.GuardOf(away) }))
	-- a shorter hop (a wall 5 back), a refused one (under 3), 3 is enough
	local w2 = xWorld()
	local q = w2:Hero(1, { Class = "Archer", Faction = "Horns" })
	w2.HopReach = 5
	w2:Use(q, "X")
	check(w2:FxTo("Hop", q, 0)[1].To.Z == 5 and w2.Allowed[1].Studs == 7, "a wall 5 back: the hop stops at 5 (AllowMove 5 + 2)",
		show({ w2:FxTo("Hop", q, 0)[1].To.Z, w2.Allowed[1].Studs }))
	local w3 = xWorld()
	local r = w3:Hero(1, { Class = "Archer", Faction = "Halo" })
	w3.HopReach = 2.5
	w3:Use(r, "X")
	check(w3:Count("X") == 0 and w3:Press(r) == "X:CantHop" and w3:ManaSpent(r) == 0 and (r:GetAttribute("SkillReadyAtX") or 0) == 0
		and #w3.Allowed == 0, "only 2.5 studs to hop: 'CantHop' before MP (no MP, no cooldown, no move allowed)",
		show({ w3:Press(r), w3:ManaSpent(r) }))
	w3.HopReach = 3
	w3:Advance(1)
	w3:Use(r, "X")
	check(w3:Count("X") == 1, "3 studs is enough (HopMin)", w3:Count("X"))
	-- too heavy: a grudge sack, a kaiju (Siren / Active) - refused before MP, no hop asked
	local w4 = xWorld()
	local s4 = w4:Hero(1, { Class = "Archer", Faction = "Horns" })
	w4.Sacks[s4] = true
	w4:Use(s4, "X")
	w4.Sacks[s4] = nil
	w4.KaijuOf[s4] = "Siren"
	w4:Advance(1)
	w4:Use(s4, "X")
	w4.KaijuOf[s4] = "Active"
	w4:Advance(1)
	w4:Use(s4, "X")
	check(w4:Count("X") == 0 and w4:Press(s4) == "X:TooHeavy,X:TooHeavy,X:TooHeavy" and w4:ManaSpent(s4) == 0 and #w4.HopAsks == 0,
		"a grudge sack, a kaiju siren or an active kaiju: 'TooHeavy' (no MP, no hop asked)", w4:Press(s4))
	w4.KaijuOf[s4] = nil
	w4:Advance(1)
	w4:Use(s4, "X")
	check(w4:Count("X") == 1, "without them it hops", w4:Count("X"))
	-- §10 MoveSkills off: the wind in place (no hop, so no 'TooHeavy' either); Halo friends around me
	local w5 = xWorld({ Move = false })
	local p5 = w5:Hero(1, { Class = "Archer", Faction = "Halo" })
	local s5 = w5:Monster("Slime", 3, 0, 99999)
	local near5 = w5:Hero(2, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, -8) })
	w5.Sacks[p5] = true
	local f5 = #w5.Fx
	w5:Use(p5, "X")
	local sk5 = w5:FxTo("Skill", p5, f5)[1]
	check(w5:Count("X") == 1 and #w5:FxTo("Hop", p5, f5) == 0 and #w5.HopAsks == 0 and #w5.Allowed == 0 and sk5 and sk5.To == nil
		and hitOf(w5, s5) == dealtX(w5, p5, 3), "Skills.MoveSkills off: the wind in place, no hop (a sack does not matter)",
		show({ w5:Count("X"), #w5.HopAsks, hitOf(w5, s5) }))
	check(near(w5.Skills.GuardOf(near5), 0.2), "... and the friends around me are guarded", w5.Skills.GuardOf(near5))
	-- Horns: +5 MP a monster the wind hits
	local w6 = xWorld()
	local h6 = w6:Hero(1, { Class = "Archer", Faction = "Horns" })
	w6:Monster("Slime", 3, 0, 99999)
	w6:Monster("Slime", 6, 0, 99999)
	local f6 = #w6.Fx
	w6:Use(h6, "X")
	check(w6:Gain(h6) == 10 and w6:FxTo("Skill", h6, f6)[1].Statuses.MP == 10, "Shadow Step on 2 monsters: +10 MP", w6:Gain(h6))
	-- the tamer's Big Boing: the big slime look, the same hop, no faction extras
	local w7 = xWorld()
	local t7 = w7:Hero(1, { Class = "Archer", Faction = "Neutral" })
	local f7 = #w7.Fx
	w7:Use(t7, "X")
	local sk7 = w7:FxTo("Skill", t7, f7)[1]
	check(sk7 and sk7.Kit == "Tamer" and sk7.Craft == "BigSlime" and #w7:FxTo("Hop", t7, f7) == 1 and next(sk7.Statuses) == nil,
		"Big Boing: Fx Craft BigSlime, the same hop, no statuses", show(sk7 and { sk7.Kit, sk7.Craft }))
	-- auto combat never hops (Auto.Never)
	local w8 = xWorld()
	w8:Hero(1, { Class = "Archer", Faction = "Halo", Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	w8:Monster("Slime", 3, 0, 99999)
	w8:Monster("Slime", 5, 0, 99999)
	w8:Monster("Slime", 6, 0, 99999)
	for _ = 1, 4 do
		w8:AutoTick()
		w8:Advance(0.6)
	end
	check(w8:Count("X") == 0 and #w8.HopAsks == 0 and w8:Count("Z") + w8:Count("Q") > 0, "auto combat never hops (it uses Z / Q)",
		show({ w8:Count("X"), w8:Count("Z"), w8:Count("Q") }))
end)

------------------------------------------------------------------ X in auto combat, XEnabled, Lv25
runGroup("x auto", function()
	local auto = { AutoCombatUnlocked = true, AutoCombatEnabled = true }
	local w = xWorld()
	w:Hero(1, { Class = "Warrior", Faction = "Halo", Attrs = auto })
	w:Monster("Slime", 4, 0, 99999)
	w:Monster("Slime", 6, 0, 99999)
	w:Monster("Slime", 8, 0, 99999)
	w:AutoTick()
	check(w:Count("X") == 1 and w:Last("X").Auto == true and w:Count("Z") == 0 and w:Count("Q") == 0,
		"auto Warrior, 3 monsters within 16: Guardian Roar first", show({ w:Count("X"), w:Count("Z"), w:Count("Q") }))
	w:AutoTick()
	check(w:Count("Z") == 0 and w:Count("Q") == 0, "the same moment: Z waits for the 0.5 s gap", w:Count("Z"))
	w:Advance(0.5)
	w:AutoTick()
	check(w:Count("Z") == 1 and w:Count("Q") == 0 and w:Count("X") == 1, "0.5 s later: Earth Cleave", show({ w:Count("Z"), w:Count("Q") }))
	w:Advance(0.5)
	w:AutoTick()
	check(w:Count("Q") == 1 and w:Count("X") == 1 and w:Count("Z") == 1, "then Q (X and Z on their cooldowns)", w:Count("Q"))
	check(#w:FxOf("SkillPress", 0) == 0, "auto casts never send the press answer", #w:FxOf("SkillPress", 0))
	-- 2 monsters: no roar (Earth Cleave first); HP under 50% with one monster within 10: the roar
	local w2 = xWorld()
	w2:Hero(1, { Class = "Warrior", Faction = "Halo", Attrs = auto })
	w2:Monster("Slime", 4, 0, 99999)
	w2:Monster("Slime", 8, 0, 99999)
	w2:AutoTick()
	check(w2:Count("X") == 0 and w2:Count("Z") == 1, "2 monsters (HP full): no roar, Earth Cleave", show({ w2:Count("X"), w2:Count("Z") }))
	local function lowHP(hp, dz)
		local lw = xWorld()
		local lp = lw:Hero(1, { Class = "Warrior", Faction = "Halo", Attrs = auto })
		lp.Character:FindFirstChild("Humanoid").Health = hp
		lw:Monster("Slime", dz, 0, 99999)
		lw:AutoTick()
		return lw:Count("X")
	end
	check(lowHP(40, 5) == 1, "HP 40% and a monster 5 away: the roar", lowHP(40, 5))
	check(lowHP(40, 12) == 0 and lowHP(60, 5) == 0, "HP 40% but the monster 12 away, or HP 60%: no roar", show({ lowHP(40, 12), lowHP(60, 5) }))
	-- Mage: the circle when 2 monsters are inside it, else no X
	local m = xWorld()
	m:Hero(1, { Class = "Mage", Faction = "Halo", Attrs = auto })
	m:Monster("Slime", 20, 0, 99999)
	m:Monster("Slime", 26, 0, 99999)
	m:AutoTick()
	check(m:Count("X") == 1 and m:Last("X").Auto == true, "auto Mage, 2 monsters inside the circle: Sun Circle", m:Count("X"))
	local m2 = xWorld()
	m2:Hero(1, { Class = "Mage", Faction = "Halo", Attrs = auto })
	m2:Monster("Slime", 20, 0, 99999)
	m2:AutoTick()
	check(m2:Count("X") == 0 and m2:Count("Q") == 1, "one monster: no circle (Meteor first)", show({ m2:Count("X"), m2:Count("Q") }))
	-- XEnabled off: X is locked by hand and never cast by auto; Lv24: locked
	local wx = xWorld({ X = false })
	local px = wx:Hero(1, { Class = "Warrior", Faction = "Halo" })
	wx:Monster("Slime", 4, 0, 99999)
	wx:Use(px, "X")
	check(wx:Count("X") == 0 and wx:Press(px) == "X:Locked" and wx:ManaSpent(px) == 0, "XEnabled off: X is refused ('Locked'), no MP",
		wx:Press(px))
	local wy = xWorld({ X = false })
	wy:Hero(1, { Class = "Warrior", Faction = "Halo", Attrs = auto })
	wy:Monster("Slime", 4, 0, 99999)
	wy:Monster("Slime", 6, 0, 99999)
	wy:Monster("Slime", 8, 0, 99999)
	wy:AutoTick()
	check(wy:Count("X") == 0 and wy:Count("Z") == 1, "XEnabled off: auto goes straight to Z", show({ wy:Count("X"), wy:Count("Z") }))
	local wl = xWorld()
	local pl = wl:Hero(1, { Class = "Warrior", Faction = "Halo", Level = 24 })
	wl:Monster("Slime", 4, 0, 99999)
	wl:Use(pl, "X")
	check(pl:GetAttribute("SkillSlots") == 2 and wl:Count("X") == 0 and wl:Press(pl) == "X:Locked", "Lv24: two slots, X is locked",
		show({ pl:GetAttribute("SkillSlots"), wl:Press(pl) }))
end)

------------------------------------------------------------------ MonsterService hooks (the real code, cut out)
runGroup("monster hooks", function()
	local src = MONSTER_SOURCE
	local function cut(startText, endText)
		local i = string.find(src, startText, 1, true)
		local j = i and string.find(src, endText, i, true)
		return (i and j) and string.sub(src, i, j - 1) or ""
	end
	local inside = cut("local function insideZone(", "-- A10-V3-2 (b): clamp a destination")
	local body = cut("local DISPLACE = {", "------------------------------------------------------------------ event monsters")
	check(#inside > 0 and string.find(body, "function MonsterService.Taunt(", 1, true) ~= nil
		and string.find(body, "function MonsterService.Slow(", 1, true) ~= nil
		and string.find(body, "function MonsterService.HopReach(", 1, true) ~= nil, "Taunt / Slow / HopReach found beside Displace",
		show({ #inside, #body }))
	local w = newWorld({})
	local cfg = w.Config
	local W = { Wall = false }
	local env = w:Env()
	env.workspace = { GetServerTimeNow = function() return w.Time end,
		Raycast = function() return W.Wall and { Position = vec(0, 0, 0) } or nil end }
	local MS = {}
	execute("MonsterService.X", "local Config, Util, MC, MonsterService, ZONE_MOVE_INSET, groundPoint, getShoveParams, warnThrottled = ...\n"
		.. inside .. body .. "\nreturn MonsterService", env, cfg, w.Util, cfg.Monsters, MS, 6,
		function(x, z)
			if W.NoGroundX and x > W.NoGroundX then return nil, true end
			if W.WaterX and x > W.WaterX then return nil, false end
			if W.CliffX and x > W.CliffX then return vec(x, W.CliffY, z), false end
			return vec(x, 0, z), false
		end,
		function() return {} end, function(k, m) table.insert(w.Warnings, "hooks " .. tostring(k) .. tostring(m)) end)
	local zone = cfg.Zones.SlimeMeadow
	local c = vec(zone.Center.X, 0, zone.Center.Z)
	local p1, p2 = w:NewPlayer(1, {}), w:NewPlayer(2, {})
	local function rec(o)
		o = o or {}
		return { Alive = o.Alive ~= false, Kind = o.Kind or "Slime", Def = cfg.MonsterTypes[o.Kind or "Slime"], Owner = o.Owner,
			ZoneId = "SlimeMeadow", Root = { Parent = true, Anchored = false, Position = c } }
	end
	-- Taunt
	local r = rec()
	check(MS.Taunt(r, p1, 4) == true and r._tauntBy == p1 and near(r._tauntUntil, w.Clock + 4), "Taunt: the monster chases me first for 4 s",
		show({ r._tauntUntil, w.Clock }))
	check(MS.Taunt(r, p2, 4) == false and r._tauntBy == p1, "someone else's live taunt is not taken over", r._tauntBy == p1)
	check(MS.Taunt(r, p1, 6) == true and near(r._tauntUntil, w.Clock + 6), "my own taunt again: refreshed", r._tauntUntil)
	w:Advance(6.1)
	check(MS.Taunt(r, p2, 4) == true and r._tauntBy == p2, "after it runs out another player may taunt it", r._tauntBy == p2)
	local long = rec()
	MS.Taunt(long, p1, 30)
	check(near(long._tauntUntil, w.Clock + 10), "a taunt lasts at most 10 s", long._tauntUntil)
	check(MS.Taunt(rec({ Kind = "PumpkinKing" }), p1, 4) == false, "a boss is never taunted", "")
	check(MS.Taunt(rec({ Owner = p1 }), p1, 4) == false and MS.Taunt(rec({ Owner = p2 }), p1, 4) == false,
		"a personal monster is never taunted (even my own)", "")
	check(MS.Taunt(rec({ Alive = false }), p1, 4) == false and MS.Taunt(rec(), {}, 4) == false and MS.Taunt(rec(), p1, 0) == false
		and MS.Taunt(rec(), p1, 0 / 0) == false, "a dead monster, a non-player, 0 or NaN seconds: no taunt", "")
	-- Slow
	local s1 = rec()
	check(MS.Slow(s1, 0.5, 2) == true and s1._slowMult == 0.5 and near(s1._slowUntil, w.Clock + 2), "Slow x0.5 for 2 s",
		show({ s1._slowMult, s1._slowUntil }))
	check(MS.Slow(s1, 0.8, 5) == true and s1._slowMult == 0.5 and near(s1._slowUntil, w.Clock + 5),
		"the stronger slow running stays, a later one extends the time", show({ s1._slowMult, s1._slowUntil }))
	w:Advance(5.1)
	check(MS.Slow(s1, 0.8, 1) == true and s1._slowMult == 0.8, "after it runs out the new slow applies", s1._slowMult)
	local boss = rec({ Kind = "PumpkinKing" })
	check(MS.Slow(boss, 0.5, 2) == true and near(boss._slowMult, 0.75), "a boss gets half the slow (x0.75)", boss._slowMult)
	local s2 = rec()
	MS.Slow(s2, 0, 30)
	local s3 = rec()
	MS.Slow(s3, 2, 1)
	check(near(s2._slowMult, 0.1) and near(s2._slowUntil, w.Clock + 10) and s3._slowMult == 1, "clamped: x0.1 .. x1, at most 10 s",
		show({ s2._slowMult, s3._slowMult }))
	check(MS.Slow(rec({ Alive = false }), 0.5, 1) == false and MS.Slow(rec(), 0 / 0, 1) == false and MS.Slow(rec(), 0.5, 0) == false
		and MS.Slow(rec(), 0.5, 0 / 0) == false, "a dead monster, NaN or no time: no slow", "")
	-- HopReach (the Displace steps: 1, 3/4, 1/2, 1/4 of the hop)
	local dir = vec(1, 0, 0)
	check(MS.HopReach(c, dir, 10) == 10, "open meadow: the full 10", MS.HopReach(c, dir, 10))
	W.WaterX = c.X + 6
	check(MS.HopReach(c, dir, 10) == 5, "water 6 away: the hop stops at 5", MS.HopReach(c, dir, 10))
	W.WaterX = c.X + 1
	check(MS.HopReach(c, dir, 10) == 0, "water right there: no hop", MS.HopReach(c, dir, 10))
	W.WaterX = nil
	W.CliffX, W.CliffY = c.X + 6, 9
	check(MS.HopReach(c, dir, 10) == 5, "a ledge 9 up, 6 away: stops at 5", MS.HopReach(c, dir, 10))
	W.CliffY = 8
	check(MS.HopReach(c, dir, 10) == 10, "8 up is fine (HopDrop 8)", MS.HopReach(c, dir, 10))
	W.CliffY = -9
	check(MS.HopReach(c, dir, 10) == 5, "a drop of 9: stops before it", MS.HopReach(c, dir, 10))
	W.CliffX = nil
	W.Wall = true
	check(MS.HopReach(c, dir, 10) == 0, "a wall in the way: no hop", MS.HopReach(c, dir, 10))
	W.Wall = false
	W.NoGroundX = c.X + 6
	check(MS.HopReach(c, dir, 10) == 10, "no ground hit at all (noHit): allowed, like Displace", MS.HopReach(c, dir, 10))
	W.NoGroundX = nil
	local edgeX = zone.Center.X + zone.Size.X / 2
	local byEdge = vec(edgeX - 4, 0, zone.Center.Z)
	check(cfg.ZoneAt(byEdge).Id == "SlimeMeadow" and MS.HopReach(byEdge, dir, 10) == 2.5,
		"4 studs from the meadow's edge: only the 1/4 step stays in the zone", show({ cfg.ZoneAt(byEdge).Id, MS.HopReach(byEdge, dir, 10) }))
	check(MS.HopReach(nil, dir, 10) == 0 and MS.HopReach(c, nil, 10) == 0 and MS.HopReach(c, dir, 0 / 0) == 0 and MS.HopReach(c, dir, 0) == 0
		and MS.HopReach(c, dir, 41) == 0 and MS.HopReach(c, dir, 40) == 40, "bad input or more than 40 studs: 0 (40 is fine)", "")
	-- DamageMonster: a cast id hitting again (a field's ticks) is one hit of that player (A23-27 RewardMinHits)
	local i0 = string.find(src, "function MonsterService.DamageMonster(", 1, true)
	local i1 = i0 and string.find(src, "\nend\n", i0, true)
	check(i0 ~= nil and i1 ~= nil, "DamageMonster found", "")
	local DM = execute("MonsterService.DamageMonster", "local zoneIdOf, updateBar, markHurt, warnThrottled, killRecord, MonsterService = ...\n"
		.. string.sub(src, i0, i1 + 4) .. "\nreturn MonsterService", env, function() return "SlimeMeadow" end, function() end,
		function() end, function() end, function(x) x.Alive = false end, { Moment = { Fire = function() end } })
	local d1 = { Alive = true, HP = 1000, ZoneId = "SlimeMeadow", _contributors = {}, _hits = {}, _dmg = {} }
	for _ = 1, 3 do DM.DamageMonster(d1, 10, p1, false, 7) end
	check(d1._hits[p1] == 1 and d1.HP == 970 and d1._dmg[p1] == 30, "one cast id 3 times (a field's ticks): 1 hit, all the damage",
		show({ d1._hits[p1], d1.HP, d1._dmg[p1] }))
	DM.DamageMonster(d1, 10, p1, false, 8)
	check(d1._hits[p1] == 2, "a new cast: one more hit", d1._hits[p1])
	DM.DamageMonster(d1, 10, p1)
	DM.DamageMonster(d1, 10, p1)
	check(d1._hits[p1] == 4, "hits without a cast id (swings, Q) count each", d1._hits[p1])
	DM.DamageMonster(d1, 10, p2, false, 8)
	check(d1._hits[p2] == 1, "another player's hit with the same number is their own", d1._hits[p2])
	-- NATURAL.Pace: walk speed x the slow until it runs out
	local n0 = string.find(src, "local NATURAL = {", 1, true)
	local n1 = n0 and string.find(src, "\n-- A15 hit feel", n0, true)
	local q0 = string.find(src, "function NATURAL.Pace(", 1, true)
	local q1 = q0 and string.find(src, "\nend\n", q0, true)
	check(n0 ~= nil and n1 ~= nil and q0 ~= nil and q1 ~= nil, "NATURAL and NATURAL.Pace found", "")
	local NAT = execute("MonsterService.Pace", "local Util = ...\n" .. string.sub(src, n0, n1) .. string.sub(src, q0, q1 + 4)
		.. "\nreturn NATURAL", env, w.Util)
	local mob = { Root = { AssemblyLinearVelocity = vec(0, 0, 0), Position = c }, Humanoid = { WalkSpeed = 0 }, Def = { Speed = 12 } }
	NAT.Pace(mob, 1, nil)
	local full = mob.Humanoid.WalkSpeed
	mob._slowMult, mob._slowUntil = 0.5, w.Clock + 1
	NAT.Pace(mob, 1, nil)
	check(full > 0 and near(mob.Humanoid.WalkSpeed, full * 0.5), "a slowed monster walks at x0.5", show({ full, mob.Humanoid.WalkSpeed }))
	w:Advance(1.1)
	NAT.Pace(mob, 1, nil)
	check(near(mob.Humanoid.WalkSpeed, full), "after the slow: full speed again", mob.Humanoid.WalkSpeed)
end)

------------------------------------------------------------------ VitalsService.AddMana, ZoneService.AllowMove (cut out)
runGroup("mana and move", function()
	local w = newWorld({})
	local cfg = w.Config
	local env = w:Env()
	local ready = {}
	local states = {}
	local S = { PlayerService = { IsReady = function(p) return ready[p] == true end } }
	local V = execute("VitalsService.AddMana", VITALS_EXTRACT, env, cfg, w.Util, w.Services.Players, S, states, cfg.Vitals)
	local stage = newInstance("Folder", w)
	local function body(p, pos)
		local model = newInstance("Model", w)
		local hum = newInstance("Humanoid", w)
		hum.Name, hum.Health, hum.MaxHealth = "Humanoid", 100, 100
		hum.Parent = model
		local root = newInstance("Part", w)
		root.Name, root.Position = "HumanoidRootPart", pos or vec(0, 0, 0)
		root.Parent = model
		model.Parent = stage
		p.Character = model
		return hum
	end
	local p = w:NewPlayer(1, { ClassChosen = true })
	local hum = body(p)
	ready[p] = true
	states[p] = { Mana = 50, HPReadyAt = 0, MPReadyAt = 0 }
	check(V.AddMana(p, 30) == 30 and states[p].Mana == 80 and p:GetAttribute("Mana") == 80 and p:GetAttribute("MaxMana") == 100,
		"AddMana: +30 from 50 -> 80 (Mana / MaxMana published)", show({ states[p].Mana, p:GetAttribute("Mana") }))
	states[p].Mana = 95
	check(V.AddMana(p, 10) == 5 and states[p].Mana == 100, "never past MaxMana: 95 + 10 -> 100 (+5)", states[p].Mana)
	check(V.AddMana(p, 10) == 0, "a full bar takes nothing", "")
	states[p].Mana = 10
	check(V.AddMana(p, 0) == 0 and V.AddMana(p, -5) == 0 and V.AddMana(p, 0 / 0) == 0 and V.AddMana(p, math.huge) == 0
		and V.AddMana(p, "5") == 0 and states[p].Mana == 10, "0, negative, NaN, infinite or text: nothing", states[p].Mana)
	ready[p] = false
	check(V.AddMana(p, 5) == 0, "not ready: nothing", "")
	ready[p] = true
	hum.Health = 0
	check(V.AddMana(p, 5) == 0, "a KO'd player: nothing", "")
	hum.Health = 100
	p:SetAttribute("ClassChosen", false)
	check(V.AddMana(p, 5) == 0 and states[p].Mana == 10, "no class picked: nothing", states[p].Mana)
	local q = w:NewPlayer(2, { ClassChosen = true })
	body(q)
	ready[q] = true
	check(V.AddMana(q, 5) == 0, "no mana state yet: nothing", "")
	-- ZoneService: AllowMove adds the hop to the movement check for a moment
	local move = { lastGood = {}, graceUntil = {}, extra = {}, lastLog = {} }
	local Z = execute("ZoneService.AllowMove", ZONE_EXTRACT, env, cfg, w.Util, cfg.AntiCheat, move, {}, {}, {}, {})
	local mover = w:NewPlayer(3, {})
	body(mover)
	local function track() move.lastGood[mover] = { Pos = vec(0, 0, 0), T = w.Clock, Char = mover.Character } end
	track()
	check(Z.Check(mover, vec(15, 0, 0)) == false, "setup: 15 studs at once is too far for the movement check", "")
	Z.Allow(mover, 12, 1)
	check(Z.Check(mover, vec(15, 0, 0)) == true and Z.Check(mover, vec(30, 0, 0)) == false, "AllowMove(12, 1 s): 15 studs pass, 30 still do not", "")
	w:Advance(1.01)
	track()
	check(Z.Check(mover, vec(15, 0, 0)) == false, "after 1 s the allowance is gone", "")
	Z.Allow(mover, 100, 10)
	check(move.extra[mover].Studs == 30 and near(move.extra[mover].Until, w.Clock + 2), "capped: at most 30 studs for 2 s",
		show(move.extra[mover]))
	Z.Cleanup(mover)
	check(move.extra[mover] == nil, "cleanup (leaving) forgets it", "")
	Z.Allow({}, 12, 1)
	Z.Allow(mover, 0 / 0, 1)
	Z.Allow(mover, -3, 1)
	Z.Allow(mover, 12, 0)
	check(move.extra[mover] == nil, "a non-player, NaN, negative studs or no time: ignored", "")
end)

finish()
