-- skill_signals_offline.luau : A23-116 (docs/design/skills18_2026-10-10.md "0. 18개 공통", row 게임성 개발 2) server checks.
-- tools/test_skill_signals.py binds the tools/test_skills.py sources (the real SkillService, CombatService, DamageWindow,
-- StoryQuestService ...) plus BASE_COMBAT_SOURCE / BASE_SKILL_SOURCE (CombatService / SkillService before A23-116, git);
-- dev2_kit.luau and dev2_combat_world.luau come first. Players face -Z at the origin; monsters are records `dz` studs in
-- front. Rules checked: the Fx Healed list (the UserIds whose HP really went up, the caster too, the nearest 5 first;
-- never a full-HP, Horns, Neutral or far player) and Stole (the HP the life steal really gave: 0 at full HP / at the 3 s
-- cap) on Release / Skill / SkillTick; Released.Healed unchanged (the OTHER players healed, Player objects, no cap);
-- ContactDelay / LaunchDelay on the Skill packet per class / slot (= the Q row; the pet tamer = PetDash); a pull / push
-- starts at the slot's ContactDelay (damage at the press), skipped for a monster that died / was removed or a caster
-- who left; and every number (damage, heal, steal, MP, pull / push, statuses) the same as the sources before A23-116.

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
if not vmt.__unm then vmt.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end end

-- a world with SkillService, Z and X on; o.PvP = PvPZX on, o.Hit = every pair may fight (PvPService double)
local function sigWorld(o)
	o = o or {}
	local w = bareWorld({ Hit = o.Hit })
	local K = w.Config.Skills
	K.ZEnabled, K.XEnabled, K.PvPZX = true, true, o.PvP == true
	K.Tasks.Enabled = false -- 99N D: these heroes open Z / X by the level
	-- a KO runs CombatService's death pipeline: its other services are quiet doubles here
	local reg = w.Registry
	-- o.Hit: only players of different sides may fight (a friend of my side is never a PvP target)
	if o.Hit then reg.PvPService.CanAttack = function(a, v) return a:GetAttribute("Faction") ~= v:GetAttribute("Faction") end end
	reg.GrudgeService.OnCarrierDown = function() end
	reg.PvPService.HandleKO = function() end
	reg.PvPService.HandleNonPvPDeath = function() end
	reg.KaijuService.HandleKaijuDeath = function() end
	w.Rel = {}
	w.Combat.Released:Connect(function(p, info) table.insert(w.Rel, { P = p, Info = info }) end)
	-- a ready Lv25 hero (Q, Z and X) with MP and the class weapon; jo as w:Join plus Mana and HP (Health after joining)
	function w:Hero(id, jo)
		jo = jo or {}
		jo.Level = jo.Level or 25
		jo.Tier, jo.Mask = jo.Tier or 1, jo.Mask or 1
		jo.Attrs = jo.Attrs or {}
		jo.Attrs.Mana = jo.Mana or 100
		local p = self:Join(id, jo)
		if jo.HP then self:Hum(p).Health = jo.HP end
		return p
	end
	function w:Hum(p) return p.Character:FindFirstChild("Humanoid") end
	function w:Use(p, ...)
		self:Advance(0.11) -- RateLimits.UseSkill
		self.Net.Get("UseSkill").OnServerEvent:Fire(p, ...)
		self:Flush()
	end
	function w:Last(slot)
		for i = #self.Rel, 1, -1 do
			if slot == nil or self.Rel[i].Info.Slot == slot then return self.Rel[i].Info end
		end
		return nil
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
	return w
end

-- the world loads CombatService / SkillService from these sources: base = the ones before A23-116
local function withSources(base, fn)
	local combat, skill = COMBAT_SOURCE, SKILL_SOURCE
	if base then COMBAT_SOURCE, SKILL_SOURCE = BASE_COMBAT_SOURCE, BASE_SKILL_SOURCE end
	local ok, res = pcall(fn)
	COMBAT_SOURCE, SKILL_SOURCE = combat, skill
	if not ok then error(res, 0) end
	return res
end

local function hitOf(w, rec, from)
	local n = 0
	for i = (from or 0) + 1, #w.Damage do
		if w.Damage[i].Rec == rec then n += w.Damage[i].N end
	end
	return n
end

local function snapshot(w)
	local hp = {}
	for _, p in w.PlayerList do
		local h = p.Character and p.Character:FindFirstChild("Humanoid")
		if h then hp[p] = h.Health end
	end
	return hp
end

-- the UserIds whose HP rose since `before`, nearest to `center` first (ties: the lower id), at most `max`
local function rose(w, before, center, max)
	local list = {}
	for p, h0 in before do
		if w:Hum(p).Health > h0 then
			local r = p.Character:FindFirstChild("HumanoidRootPart")
			table.insert(list, { Id = p.UserId, D = w.Util.FlatDistance(r.Position, center) })
		end
	end
	table.sort(list, function(a, b) return a.D < b.D or (a.D == b.D and a.Id < b.Id) end)
	local ids = {}
	for i = 1, math.min(#list, max or 5) do ids[i] = list[i].Id end
	return ids
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

local ORIGIN = vec(0, 0, 0)

------------------------------------------------------------------ Healed on Q (Fx "Release")
runGroup("healed on Q", function()
	local w = sigWorld()
	local p = w:Hero(1, { Class = "Warrior", Faction = "Halo", HP = 50 })
	local a2 = w:Hero(2, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 3), HP = 40 })
	local a3 = w:Hero(3, { Class = "Archer", Faction = "Halo", Pos = vec(5, 0, 0), HP = 40 })
	local full = w:Hero(4, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 2) })
	local horn = w:Hero(5, { Class = "Mage", Faction = "Horns", Pos = vec(0, 0, 1), HP = 40 })
	local neutral = w:Hero(6, { Class = "Mage", Faction = "Neutral", Pos = vec(1, 0, 1), HP = 40 })
	local far = w:Hero(7, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 20), HP = 40 })
	for i = 1, 5 do w:Monster("Slime", 1 + i, 0, 99999) end
	local before, f0 = snapshot(w), #w.Fx
	w:Use(p, "Q")
	local rel = w:FxTo("Release", p, f0)[1]
	local want = rose(w, before, ORIGIN)
	check(rel ~= nil and same(rel.Healed, { 1, 2, 3 }) and same(want, { 1, 2, 3 }),
		"Halo Q: Fx Release Healed = { me (0), the ally 3 away, the ally 5 away }: who really got HP, nearest first",
		show({ rel and rel.Healed, want }))
	check(w:Hum(full).Health == 100 and w:Hum(horn).Health == 40 and w:Hum(neutral).Health == 40 and w:Hum(far).Health == 40,
		"a full-HP ally, a Horn, a Neutral and an ally 20 away get nothing (so they are not listed)",
		show({ w:Hum(full).Health, w:Hum(horn).Health, w:Hum(neutral).Health, w:Hum(far).Health }))
	check(rel ~= nil and rel.Stole == 0, "a Halo cast steals nothing: Stole 0", show(rel and rel.Stole))
	local info = w:Last("Q")
	local healed = info and info.Healed or {}
	check(#healed == 2 and table.find(healed, a2) ~= nil and table.find(healed, a3) ~= nil and table.find(healed, p) == nil
		and healed[1].ClassName == "Player", "Released.Healed unchanged: the OTHER players healed, as Player objects (not me)",
		show({ #healed }))
	-- at most 5, nearest first; me at full HP is not listed
	local w2 = sigWorld()
	local q = w2:Hero(1, { Class = "Warrior", Faction = "Halo" })
	local dist = { [11] = 6, [12] = 2, [13] = 7, [14] = 1, [15] = 4, [16] = 3, [17] = 5 }
	for id = 11, 17 do w2:Hero(id, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, dist[id]), HP = 40 }) end
	for i = 1, 5 do w2:Monster("Slime", 1 + i, 0, 99999) end
	local b2, g0 = snapshot(w2), #w2.Fx
	w2:Use(q, "Q")
	local rel2 = w2:FxTo("Release", q, g0)[1]
	check(rel2 ~= nil and same(rel2.Healed, { 14, 12, 16, 15, 17 }) and #rose(w2, b2, ORIGIN, 99) == 7,
		"7 allies healed: Healed = the nearest 5 (1, 2, 3, 4, 5 away), nearest first; me at full HP is not listed",
		show(rel2 and rel2.Healed))
	check(#(w2:Last("Q").Healed or {}) == 7, "Released.Healed still lists all 7 others (no cap there)", #(w2:Last("Q").Healed or {}))
	-- a tie across the 5th / 6th place: two allies 5 away (26 joined before 25): the lower UserId keeps the 5th place
	local w3 = sigWorld()
	local t = w3:Hero(1, { Class = "Warrior", Faction = "Halo" })
	for id = 21, 24 do w3:Hero(id, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, id - 20), HP = 40 }) end
	w3:Hero(26, { Class = "Mage", Faction = "Halo", Pos = vec(5, 0, 0), HP = 40 })
	w3:Hero(25, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 5), HP = 40 })
	for i = 1, 5 do w3:Monster("Slime", 1 + i, 0, 99999) end
	local b3, t0 = snapshot(w3), #w3.Fx
	w3:Use(t, "Q")
	local rel3 = w3:FxTo("Release", t, t0)[1]
	check(rel3 ~= nil and same(rel3.Healed, { 21, 22, 23, 24, 25 }) and #rose(w3, b3, ORIGIN, 99) == 6,
		"6 healed with a tie at 5 studs (ids 25 and 26): Healed = 21, 22, 23, 24, 25 (the lower id wins the tie)",
		show(rel3 and rel3.Healed))
end)

------------------------------------------------------------------ Healed on Z / X (Fx "Skill" / "SkillTick")
runGroup("healed on Z and X", function()
	local w = sigWorld()
	local p = w:Hero(1, { Class = "Warrior", Faction = "Halo", HP = 50 })
	w:Hero(2, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 8), HP = 40 })
	local out = w:Hero(3, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 13), HP = 40 })
	local horn = w:Hero(4, { Class = "Mage", Faction = "Horns", Pos = vec(0, 0, 5), HP = 40 })
	for i = 0, 3 do w:Monster("Slime", 6 + i * 3, 0, 99999) end
	local before, f0 = snapshot(w), #w.Fx
	w:Use(p, "Z")
	local sk = w:FxTo("Skill", p, f0)[1]
	check(sk ~= nil and sk.Slot == "Z" and same(sk.Healed, { 1, 2 }) and same(rose(w, before, ORIGIN), { 1, 2 }) and sk.Stole == 0,
		"Halo Z (Glow Lasso): Fx Skill Healed = { me, the ally 8 away }, Stole 0",
		show(sk and { sk.Healed, sk.Stole }))
	check(w:Hum(out).Health == 40 and w:Hum(horn).Health == 40, "an ally 13 away and a Horn 5 away: not healed, not listed", "")
	w:Advance(3.1) -- the 3 s heal window is free again
	local b2, g0 = snapshot(w), #w.Fx
	w:Use(p, "X")
	local skx = w:FxTo("Skill", p, g0)[1]
	check(skx ~= nil and skx.Slot == "X" and skx.Shape == "Roar" and #skx.Healed >= 1 and same(skx.Healed, rose(w, b2, ORIGIN))
		and skx.Stole == 0, "Halo X (Guardian Roar): Fx Skill Healed = who really got HP", show(skx and skx.Healed))
	-- Sun Circle: the first tick (Fx Skill) and every SkillTick, healed around me (12), not around the circle
	local m = sigWorld()
	local mage = m:Hero(1, { Class = "Mage", Faction = "Halo", HP = 30 })
	m:Hero(2, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, 5), HP = 30 })
	local inside = m:Hero(3, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, -22), HP = 30 })
	m:Monster("Slime", 20, 0, 99999)
	local b3, h0 = snapshot(m), #m.Fx
	m:Use(mage, "X")
	local first = m:FxTo("Skill", mage, h0)[1]
	check(first ~= nil and first.Shape == "Field" and same(first.Healed, { 1, 2 }) and same(rose(m, b3, ORIGIN), { 1, 2 })
		and first.Stole == 0 and m:Hum(inside).Health == 30,
		"Sun Circle's first tick (Fx Skill): Healed = me + the friend 5 away (the friend in the circle 22 away: no)",
		show(first and first.Healed))
	local ticks, exact, any = 0, true, false
	for _ = 1, 4 do
		local bt, ft = snapshot(m), #m.Fx
		m:Advance(1)
		local t = m:FxTo("SkillTick", mage, ft)[1]
		if t then
			ticks += 1
			if not (same(t.Healed, rose(m, bt, ORIGIN)) and t.Stole == 0) then exact = false end
			if #t.Healed > 0 then any = true end
		end
	end
	check(ticks == 4 and exact and any, "every SkillTick: Healed = exactly who really got HP that tick (some tick heals)",
		show({ ticks, exact, any }))
end)

------------------------------------------------------------------ Stole (Horns life steal)
runGroup("stole", function()
	local w = sigWorld()
	local p = w:Hero(1, { Class = "Warrior", Faction = "Horns", HP = 50 })
	local friend = w:Hero(2, { Class = "Mage", Faction = "Horns", Pos = vec(0, 0, 3), HP = 40 })
	for i = 1, 5 do w:Monster("Slime", 1 + i, 0, 99999) end
	local h0, f0 = w:Hum(p).Health, #w.Fx
	w:Use(p, "Q")
	local rel = w:FxTo("Release", p, f0)[1]
	check(rel ~= nil and rel.Stole == 3 and w:Hum(p).Health - h0 == 3, "Horns Q: Stole 3 = the HP really gained (3% of 100)",
		show({ rel and rel.Stole, w:Hum(p).Health - h0 }))
	check(rel ~= nil and same(rel.Healed, {}) and w:Hum(friend).Health == 40, "a Horns cast heals nobody: Healed {}",
		show(rel and rel.Healed))
	w:Advance(0.4)
	local h1, g0 = w:Hum(p).Health, #w.Fx
	w:Use(p, "Z")
	local sk = w:FxTo("Skill", p, g0)[1]
	check(sk ~= nil and sk.Slot == "Z" and #sk.Hits > 0 and sk.Stole == 0 and w:Hum(p).Health == h1,
		"Z 0.5 s later, inside the 3 s cap: Stole 0 and nothing gained", show(sk and { sk.Stole, #sk.Hits }))
	-- outside the 3 s window, below max HP: the Z / X packet's Stole = the HP really gained (> 0)
	w:Advance(3.1)
	local h2, x0 = w:Hum(p).Health, #w.Fx
	w:Use(p, "X")
	local skx = w:FxTo("Skill", p, x0)[1]
	check(skx ~= nil and skx.Slot == "X" and skx.Shape == "Roar" and skx.Stole > 0 and skx.Stole == w:Hum(p).Health - h2
		and h2 < 100, "Horns X (Rage Roar) after the window: Fx Skill Stole = the HP gained (> 0)",
		show(skx and { skx.Stole, w:Hum(p).Health - h2 }))
	local z = sigWorld()
	local zp = z:Hero(1, { Class = "Warrior", Faction = "Horns", HP = 50 })
	for i = 0, 3 do z:Monster("Slime", 6 + i * 3, 0, 99999) end
	local hz, z0 = z:Hum(zp).Health, #z.Fx
	z:Use(zp, "Z")
	local skz = z:FxTo("Skill", zp, z0)[1]
	check(skz ~= nil and skz.Slot == "Z" and skz.Stole > 0 and skz.Stole == z:Hum(zp).Health - hz,
		"Horns Z (Fire Rake) in a fresh window: Fx Skill Stole = the HP gained (> 0)", show(skz and { skz.Stole, z:Hum(zp).Health - hz }))
	local hop = sigWorld()
	local hp = hop:Hero(1, { Class = "Archer", Faction = "Horns", HP = 50 })
	for _, dz in { 2, 4, 6 } do hop:Monster("Slime", dz, 0, 99999) end
	local hh, k0 = hop:Hum(hp).Health, #hop.Fx
	hop:Use(hp, "X")
	local skh = hop:FxTo("Skill", hp, k0)[1]
	check(skh ~= nil and skh.Shape == "Hop" and skh.Stole > 0 and skh.Stole == hop:Hum(hp).Health - hh,
		"Horns X (Shadow Step) in a fresh window: Fx Skill Stole = the HP gained (> 0)", show(skh and { skh.Stole, hop:Hum(hp).Health - hh }))
	local function oneQ(hp, fac, cls)
		local x = sigWorld()
		local c = x:Hero(1, { Class = cls or "Warrior", Faction = fac or "Horns", HP = hp })
		for i = 1, 5 do x:Monster("Slime", 1 + i, 0, 99999) end
		local before, from = x:Hum(c).Health, #x.Fx
		x:Use(c, "Q")
		return x:FxTo("Release", c, from)[1], x:Hum(c).Health - before
	end
	local r1, g1 = oneQ(100)
	check(r1 ~= nil and r1.Stole == 0 and g1 == 0, "at full HP: Stole 0", show(r1 and r1.Stole))
	local r2, g2 = oneQ(99)
	check(r2 ~= nil and r2.Stole == 1 and g2 == 1, "1 HP missing: Stole 1 (what really came in, not 3)", show(r2 and r2.Stole))
	local r3, g3 = oneQ(50, "Neutral")
	check(r3 ~= nil and r3.Stole == 0 and same(r3.Healed, {}) and g3 == 0, "the artisan: Healed {}, Stole 0", show(r3 and r3.Stole))
	-- Hex Circle: Stole = the HP gained, at once and on every tick; the 3 s cap shows as 0
	local m = sigWorld()
	local mage = m:Hero(1, { Class = "Mage", Faction = "Horns", HP = 50 })
	for _, dz in { 18, 20, 22 } do m:Monster("Slime", dz, 0, 99999) end
	local hm, k0 = m:Hum(mage).Health, #m.Fx
	m:Use(mage, "X")
	local first = m:FxTo("Skill", mage, k0)[1]
	check(first ~= nil and first.Shape == "Field" and first.Stole > 0 and first.Stole == m:Hum(mage).Health - hm
		and same(first.Healed, {}), "Hex Circle's first tick (Fx Skill): Stole = the HP gained", show(first and first.Stole))
	local ticks, exact, capped = 0, true, false
	for _ = 1, 4 do
		local ht, kt = m:Hum(mage).Health, #m.Fx
		m:Advance(1)
		local t = m:FxTo("SkillTick", mage, kt)[1]
		if t then
			ticks += 1
			if not (type(t.Stole) == "number" and t.Stole == m:Hum(mage).Health - ht and same(t.Healed, {})) then exact = false end
			if t.Stole == 0 and ht < 100 then capped = true end
		end
	end
	check(ticks == 4 and exact and capped, "every SkillTick: Stole = the HP gained that tick; 0 while the 3 s cap is used up",
		show({ ticks, exact, capped }))
end)

------------------------------------------------------------------ the fields are on every packet (whiffs too)
runGroup("fields on every packet", function()
	local w = sigWorld()
	local halo = w:Hero(1, { Class = "Warrior", Faction = "Halo", HP = 50 })
	local horn = w:Hero(2, { Class = "Mage", Faction = "Horns", Pos = vec(60, 0, 0), HP = 50 })
	local f0 = #w.Fx
	w:Use(halo, "Q") -- nothing in reach: a whiff
	local whiff = w:FxTo("Release", halo, f0)[1]
	check(whiff ~= nil and same(whiff.Healed, {}) and whiff.Stole == 0, "a whiffed Q: Healed {}, Stole 0", show(whiff and whiff.Stole))
	w:Advance(0.5)
	w:Use(halo, "Z") -- a whiff ahead
	local wz = w:FxTo("Skill", halo, f0)[1]
	check(wz ~= nil and same(wz.Healed, {}) and wz.Stole == 0, "a whiffed Z: Healed {}, Stole 0", show(wz and wz.Stole))
	w:Monster("Slime", 6, 0, 99999)
	w:Monster("Slime", 20, 60, 99999)
	w:Advance(3.1)
	w:Use(halo, "Q")
	w:Use(horn, "Q")
	w:Advance(0.5)
	w:Use(halo, "X")
	w:Use(horn, "X")
	for _ = 1, 5 do w:Advance(1) end
	local n, bad = {}, nil
	for i = f0 + 1, #w.Fx do
		local f = w.Fx[i]
		if f.Kind == "Release" or f.Kind == "Skill" or f.Kind == "SkillTick" then
			n[f.Kind] = (n[f.Kind] or 0) + 1
			if type(f.Data.Healed) ~= "table" or type(f.Data.Stole) ~= "number" then bad = bad or (f.Kind .. " " .. show(f.Data.Slot)) end
		end
	end
	check(bad == nil and (n.Release or 0) >= 3 and (n.Skill or 0) >= 3 and (n.SkillTick or 0) >= 4,
		"every Fx Release / Skill / SkillTick carries Healed (a table) and Stole (a number)", show({ n, bad }))
end)

------------------------------------------------------------------ ContactDelay / LaunchDelay on the Skill packet
runGroup("timing on the skill packet", function()
	local kit = sigWorld().Combat.Kit
	local function m(slot, cls, style)
		local c, l = kit.Motion(slot, cls, style)
		return show({ c, l })
	end
	check(type(kit.Motion) == "function" and m("Q", "Warrior") == show({ 0.24 }) and m("Q", "Mage") == show({ 0.35, 0.35 })
		and m("Q", "Archer") == show({ 0.4, 0.18 }) and m("Q", "Archer", "PetDash") == show({ 0.35 }),
		"Kit.Motion(Q): the Release row (Warrior 0.24, Mage 0.35 / 0.35, Archer 0.4 / 0.18, PetDash 0.35)",
		show({ m("Q", "Warrior"), m("Q", "Mage"), m("Q", "Archer") }))
	check(m("Swing", "Warrior") == show({}) and m("Z", "Nobody") == show({}) and m("Z", "Archer", "Punch") == show({}),
		"Kit.Motion: nothing for a swing, an unknown class or a style without a row", show({ m("Swing", "Warrior"), m("Z", "Nobody") }))
	local rows = {
		{ Class = "Warrior", Faction = "Halo", C = 0.24 }, { Class = "Warrior", Faction = "Horns", C = 0.24 },
		{ Class = "Mage", Faction = "Halo", C = 0.35, L = 0.35 }, { Class = "Mage", Faction = "Horns", C = 0.35, L = 0.35 },
		{ Class = "Archer", Faction = "Halo", C = 0.4, L = 0.18 }, { Class = "Archer", Faction = "Horns", C = 0.4, L = 0.18 },
		{ Class = "Warrior", Faction = "Neutral", C = 0.24 }, { Class = "Mage", Faction = "Neutral", C = 0.35, L = 0.35 },
		{ Class = "Archer", Faction = "Neutral", C = 0.35 }, -- the pet tamer: PetDash, like its Q
	}
	for _, r in rows do
		local w = sigWorld()
		local p = w:Hero(1, { Class = r.Class, Faction = r.Faction })
		w:Monster("Slime", 6, 0, 99999)
		local f0 = #w.Fx
		w:Use(p, "Q")
		w:Advance(0.5)
		w:Use(p, "Z")
		w:Advance(0.5)
		w:Use(p, "X")
		local rel = w:FxTo("Release", p, f0)[1]
		local z, x = nil, nil
		for _, d in w:FxTo("Skill", p, f0) do
			if d.Slot == "Z" then z = d elseif d.Slot == "X" then x = d end
		end
		local name = r.Class .. " " .. r.Faction
		check(z ~= nil and x ~= nil and z.ContactDelay == r.C and z.LaunchDelay == r.L and x.ContactDelay == r.C
			and x.LaunchDelay == r.L, name .. ": Fx Skill Z / X ContactDelay / LaunchDelay = its row",
			show({ z and z.ContactDelay, z and z.LaunchDelay, x and x.ContactDelay, x and x.LaunchDelay }))
		check(rel ~= nil and z ~= nil and x ~= nil and rel.ContactDelay == z.ContactDelay and rel.LaunchDelay == z.LaunchDelay
			and rel.ContactDelay == x.ContactDelay and rel.LaunchDelay == x.LaunchDelay,
			name .. ": Z / X carry the same times as its Q (Fx Release) for now",
			show({ rel and rel.ContactDelay, rel and rel.LaunchDelay }))
	end
	-- auto casts carry the same times (auto combat on: SkillService.Cast(p, slot, true))
	local AUTO = { AutoCombatUnlocked = true, AutoCombatEnabled = true }
	local a = sigWorld()
	local ap = a:Hero(1, { Class = "Archer", Faction = "Horns", Attrs = AUTO })
	a:Monster("Slime", 12, 0, 99999)
	local a0 = #a.Fx
	local wentZ = a.Skills.Cast(ap, "Z", true)
	local az = a:FxTo("Skill", ap, a0)[1]
	check(wentZ == true and az ~= nil and az.Auto == true and az.ContactDelay == 0.4 and az.LaunchDelay == 0.18,
		"an auto Moon Shot: Fx Skill ContactDelay 0.4 / LaunchDelay 0.18", show(az and { az.Auto, az.ContactDelay, az.LaunchDelay }))
	local f = sigWorld()
	local fp = f:Hero(1, { Class = "Mage", Faction = "Halo", Attrs = AUTO })
	f:Monster("Slime", 20, 0, 99999)
	f:Monster("Slime", 22, 0, 99999)
	local f1 = #f.Fx
	local wentX = f.Skills.Cast(fp, "X", true)
	local ax = f:FxTo("Skill", fp, f1)[1]
	check(wentX == true and ax ~= nil and ax.Auto == true and ax.Shape == "Field" and ax.ContactDelay == 0.35 and ax.LaunchDelay == 0.35,
		"an auto Sun Circle: Fx Skill ContactDelay 0.35 / LaunchDelay 0.35", show(ax and { ax.Auto, ax.ContactDelay, ax.LaunchDelay }))
end)

------------------------------------------------------------------ a pull / push starts at the slot's ContactDelay
runGroup("displace at contact", function()
	-- Halo and Horns Warrior Z (pull 5 toward where I stood), the same wait for both sides; the damage at once
	for _, fac in { "Halo", "Horns" } do
		local w = sigWorld()
		local p = w:Hero(1, { Class = "Warrior", Faction = fac })
		local a, b = w:Monster("Slime", 8, 0, 99999), w:Monster("Slime", 12, 0, 99999)
		local d0 = #w.Damage
		w:Use(p, "Z")
		check(hitOf(w, a, d0) > 0 and hitOf(w, b, d0) > 0 and w:Last("Z").MonstersHit == 2 and #w.Displaced == 0,
			fac .. " Z: the damage and Released at the press, no pull yet", show({ hitOf(w, a, d0), #w.Displaced }))
		w:Advance(0.2)
		check(#w.Displaced == 0, fac .. " Z: no pull 0.2 s after the press (ContactDelay 0.24)", #w.Displaced)
		w:Advance(0.05)
		local d = w.Displaced
		check(#d == 2 and d[1].Mode == "Pull" and d[1].Studs == 5 and d[1].P == p and d[1].From.X == 0 and d[1].From.Z == 0
			and ((d[1].Rec == a and d[2].Rec == b) or (d[1].Rec == b and d[2].Rec == a)),
			fac .. " Z: at 0.25 s both hit monsters are pulled 5 toward where I stood", show({ #d, d[1] and d[1].Mode }))
	end
	-- Archer Z (push 3) and X (the wind's push 6): not at 0.35 s, at 0.41 s (ContactDelay 0.4)
	for _, slot in { "Z", "X" } do
		local w = sigWorld()
		local p = w:Hero(1, { Class = "Archer", Faction = "Horns" })
		w:Monster("Slime", slot == "Z" and 12 or 3, 0, 99999)
		w:Use(p, slot)
		w:Advance(0.35)
		local early = #w.Displaced
		w:Advance(0.06)
		check(early == 0 and #w.Displaced == 1 and w.Displaced[1].Mode == "Push" and w.Displaced[1].Studs == (slot == "Z" and 3 or 6),
			"Archer " .. slot .. ": the push waits for 0.4 s (none at 0.35, one at 0.41)", show({ early, #w.Displaced }))
	end
	-- the pet tamer's Slime Roll: PetDash 0.35
	local t = sigWorld()
	local tamer = t:Hero(1, { Class = "Archer", Faction = "Neutral" })
	t:Monster("Slime", 12, 0, 99999)
	t:Use(tamer, "Z")
	t:Advance(0.3)
	local early = #t.Displaced
	t:Advance(0.06)
	check(early == 0 and #t.Displaced == 1 and t.Displaced[1].Mode == "Push", "the pet tamer's Slime Roll pushes at 0.35 s (PetDash)",
		show({ early, #t.Displaced }))
	-- an auto cast waits too: an auto Moon Shot pushes at 0.4 s, not at once
	local au = sigWorld()
	local aup = au:Hero(1, { Class = "Archer", Faction = "Horns", Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	au:Monster("Slime", 12, 0, 99999)
	local wentA = au.Skills.Cast(aup, "Z", true)
	local atOnce = #au.Displaced
	au:Advance(0.35)
	local before04 = #au.Displaced
	au:Advance(0.06)
	check(wentA == true and atOnce == 0 and before04 == 0 and #au.Displaced == 1 and au.Displaced[1].Mode == "Push"
		and au.Displaced[1].Studs == 3, "an auto Moon Shot: no push at the cast or at 0.35 s, one push (3) at 0.41 s",
		show({ wentA, atOnce, before04, #au.Displaced }))
	-- the origin: a pull goes toward where I stand at the contact (I walked on), a push from where I pressed (a hop
	-- pushes from the takeoff spot, the landing is 10 back)
	local o1 = sigWorld()
	local wp = o1:Hero(1, { Class = "Warrior", Faction = "Halo" })
	o1:Monster("Slime", 10, 0, 99999)
	o1:Use(wp, "Z")
	wp.Character:FindFirstChild("HumanoidRootPart").Position = vec(3, 0, -4)
	o1:Advance(0.3)
	local od = o1.Displaced[1]
	check(#o1.Displaced == 1 and od.Mode == "Pull" and od.From.X == 3 and od.From.Z == -4,
		"a pull goes toward where I stand at the contact (3, -4), not where I pressed (0, 0)", show(od and { od.From.X, od.From.Z }))
	local o2 = sigWorld()
	local hp2 = o2:Hero(1, { Class = "Archer", Faction = "Horns" })
	o2:Monster("Slime", 3, 0, 99999)
	o2:Use(hp2, "X")
	hp2.Character:FindFirstChild("HumanoidRootPart").Position = vec(0, 0, 10) -- the hop landed
	o2:Advance(0.45)
	local pd = o2.Displaced[1]
	check(#o2.Displaced == 1 and pd.Mode == "Push" and pd.From.X == 0 and pd.From.Z == 0,
		"Shadow Step's wind pushes from the takeoff spot (0, 0), not the landing (0, 10)", show(pd and { pd.From.X, pd.From.Z }))
	-- a KO or a new character before the contact: no pull
	local o3 = sigWorld()
	local ko = o3:Hero(1, { Class = "Warrior", Faction = "Horns" })
	o3:Monster("Slime", 8, 0, 99999)
	o3:Use(ko, "Z")
	o3:Hum(ko).Health = 0
	o3:Advance(0.3)
	check(#o3.Displaced == 0, "the caster was knocked out before the contact: no pull", #o3.Displaced)
	local o4 = sigWorld()
	local re = o4:Hero(1, { Class = "Warrior", Faction = "Halo" })
	o4:Monster("Slime", 8, 0, 99999)
	o4:Use(re, "Z")
	o4:Body(re) -- a new character (respawn) before the contact
	o4:Advance(0.3)
	check(#o4.Displaced == 0, "a new character before the contact: no pull", #o4.Displaced)
	-- a monster that died or was removed meanwhile is skipped; the other one still slides
	local w = sigWorld()
	local p = w:Hero(1, { Class = "Warrior", Faction = "Halo" })
	local a, b, c = w:Monster("Slime", 6, 0, 99999), w:Monster("Slime", 10, 0, 99999), w:Monster("Slime", 14, 0, 99999)
	w:Use(p, "Z")
	a.Alive = false -- another player's hit killed it before the rope arrived
	c.Root.Parent = nil -- despawned
	w:Advance(0.3)
	check(#w.Displaced == 1 and w.Displaced[1].Rec == b, "a monster that died / was removed before the contact: no pull (the living one: yes)",
		#w.Displaced)
	-- a caster who left: nothing
	local l = sigWorld()
	local gone = l:Hero(1, { Class = "Warrior", Faction = "Horns" })
	l:Monster("Slime", 8, 0, 99999)
	l:Use(gone, "Z")
	l:Remove(gone)
	l:Advance(0.3)
	check(#l.Displaced == 0, "the caster left before the contact: no pull", #l.Displaced)
	-- Displace throws: caught and warned (pcall + warn), nothing else breaks
	local e = sigWorld()
	e.AllowWarn = "displace: "
	local ep = e:Hero(1, { Class = "Archer", Faction = "Halo" })
	e:Monster("Slime", 12, 0, 99999)
	e.Registry.MonsterService.Displace = function() error("offline: displace broke") end
	e:Use(ep, "Z")
	local okA = pcall(function() e:Advance(0.5) end)
	local warned = false
	for _, text in e.Warnings do
		if has(text, "displace: ") and has(text, "offline: displace broke") then warned = true end
	end
	check(okA and warned, "a Displace error at the contact time is caught and warned", show({ okA, warned }))
	-- no pull / push for Chain / Field / Roar (no Pull / Push in Config), also after the contact time
	local n = sigWorld()
	local mage = n:Hero(1, { Class = "Mage", Faction = "Halo" })
	n:Monster("Slime", 10, 0, 99999)
	n:Use(mage, "Z")
	n:Advance(0.5)
	n:Use(mage, "X")
	n:Advance(1)
	check(#n.Displaced == 0, "Birdie Bounce / Sun Circle move nobody", #n.Displaced)
end)

------------------------------------------------------------------ every number the same as before A23-116
-- one scripted fight per kit (manual Q / Z / X, auto Q / Z / X, PvP on, a friend, a foe, monsters near and far, one that
-- dies at the first hit) with the sources before A23-116 and with the current ones: the damage, Released, the Fx hits /
-- totals / statuses, every heal (asked / given, CombatService.HealPlayer), every HP after each step, MP, MP steal,
-- pull / push, taunt, slow and Guard must match. big = the caster and the friend at 10000 / 20000 HP: no heal / steal cap
-- binds, so a changed heal or steal rate shows (with 100 HP every Horns cast hits the 3% cap)
local function scene(base, cls, fac, big)
	return withSources(base, function()
		local w = sigWorld({ Hit = true, PvP = true })
		-- A23-126 changed the Halo self-heal cap on purpose (3%): the 'same numbers' scene compares everything else, with
		-- the old self cap (its own group checks the new rule)
		if not base then w.Config.BasicSkill.HaloSelfHealCapPct = w.Config.BasicSkill.HaloHealCapPct end
		local heals, L = {}, {}
		local realHeal = w.Combat.HealPlayer
		w.Combat.HealPlayer = function(pl, amount)
			local got = realHeal(pl, amount)
			table.insert(heals, got)
			table.insert(L, string.format("heal %s asked %s got %s at %.2f", tostring(pl and pl.UserId),
				type(amount) == "number" and string.format("%.4f", amount) or tostring(amount), tostring(got), w.Clock))
			return got
		end
		local p = w:Hero(1, { Class = cls, Faction = fac, HP = 50, Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
		local friend = w:Hero(2, { Class = "Mage", Faction = fac, Pos = vec(0, 0, 4), HP = 40 })
		if big then
			for _, pl in { p, friend } do w:Hum(pl).MaxHealth, w:Hum(pl).Health = 20000, 10000 end
		end
		local foe = w:Hero(3, { Class = "Warrior", Faction = fac == "Halo" and "Horns" or "Halo", Pos = vec(2, 0, -5) })
		w:Hum(foe).MaxHealth, w:Hum(foe).Health = 5000, 5000
		for _, at in { { 3, 0 }, { 6, 0.5 }, { 9, 1 }, { 14, -1 }, { 20, 0 }, { 26, 2 } } do w:Monster("Slime", at[1], at[2], 99999) end
		w:Monster("Slime", 5, -0.5, 1) -- dies at the first hit
		w:Monster("BigSlime", 12, 3, 99999)
		local function stamp(label)
			local hp = {}
			for _, pl in w.PlayerList do table.insert(hp, pl.UserId .. "=" .. tostring(w:Hum(pl).Health)) end
			table.insert(L, "after " .. label .. ": " .. table.concat(hp, " "))
		end
		w:Use(p, "Q")
		stamp("Q")
		w:Advance(3.1)
		w:Use(p, "Z")
		stamp("Z")
		w:Advance(3.1)
		w:Use(p, "X")
		stamp("X")
		for i = 1, 5 do
			w:Advance(1)
			stamp("tick " .. i)
		end
		w:Advance(3.1)
		w.Skills.Cast(p, "Q", true)
		stamp("auto Q")
		w:Advance(3.1)
		w.Skills.Cast(p, "Z", true)
		stamp("auto Z")
		w:Advance(16)
		w.Skills.Cast(p, "X", true)
		stamp("auto X")
		for i = 1, 6 do
			w:Advance(1)
			stamp("auto tick " .. i)
		end
		w:Use(p, "Z")
		stamp("Z again")
		w:Advance(2)
		local moves = {}
		local function idx(rec) return table.find(w.Monsters, rec) or 0 end
		local function xz(v) return typeofDouble(v) == "Vector3" and string.format("%.3f,%.3f", v.X, v.Z) or "-" end
		for _, d in w.Damage do
			table.insert(L, string.format("dmg %d %s by %s cast %s", idx(d.Rec), tostring(d.N), tostring(d.P and d.P.UserId), tostring(d.Cast)))
		end
		for _, r in w.Rel do
			local ids = {}
			for _, x in r.Info.Healed or {} do table.insert(ids, x.ClassName == "Player" and tostring(x.UserId) or "?") end
			table.insert(L, string.format("rel %s auto %s total %s monsters %s players %s healed %s", tostring(r.Info.Slot),
				tostring(r.Info.Auto), tostring(r.Info.Total), tostring(r.Info.MonstersHit), tostring(r.Info.PlayersHit),
				table.concat(ids, ",")))
		end
		for _, f in w.Fx do
			if f.Player == p and (f.Kind == "Release" or f.Kind == "Skill" or f.Kind == "SkillTick" or f.Kind == "Hop"
				or f.Kind == "SkillEnd" or f.Kind == "SkillPress") then
				local d = f.Data
				local hits = {}
				for _, h in d.Hits or {} do table.insert(hits, string.format("%s:%s:%s", tostring(h.K), tostring(h.A), xz(h.P))) end
				table.insert(L, string.format("fx %s slot %s result %s total %s to %s center %s hits %s st %s", f.Kind, tostring(d.Slot),
					tostring(d.Result), tostring(d.Total), xz(d.To), xz(d.Center or d.Pos), table.concat(hits, ";"), show(d.Statuses)))
			end
		end
		for _, pl in w.PlayerList do
			table.insert(L, string.format("hp %d %s guard %s", pl.UserId, tostring(w:Hum(pl).Health), tostring(pl:GetAttribute("GuardPct"))))
		end
		for _, mm in w.Mana do table.insert(L, string.format("mp %d -%s", mm.P.UserId, tostring(mm.Cost))) end
		for _, g in w.Gained do table.insert(L, string.format("mp %d +%s", g.P.UserId, tostring(g.N))) end
		for _, t in w.Taunts do table.insert(L, string.format("taunt %d %s", idx(t.Rec), tostring(t.Sec))) end
		for _, s in w.Slows do table.insert(L, string.format("slow %d %s %s", idx(s.Rec), tostring(s.Mult), tostring(s.Sec))) end
		for _, d in w.Displaced do
			table.insert(moves, string.format("move %d %s %s from %s by %s", idx(d.Rec), d.Mode, tostring(d.Studs), xz(d.From),
				tostring(d.P and d.P.UserId)))
		end
		table.sort(moves) -- the order of equal contact times is not part of the rule
		for _, mv in moves do table.insert(L, mv) end
		local given = 0
		for _, n in heals do
			if type(n) == "number" and n > 0 then given += 1 end
		end
		return { Lines = L, Damage = #w.Damage, Moves = #moves, Rel = #w.Rel, Heals = given }
	end)
end

-- A23-126 (user 2026-10-11 "추천대로"): a Halo heal's share for the caster is at most 3% of its MaxHealth per 3 s (the Horns
-- life steal cap), a friend's 30%; a ranged Q (Star Fall / Feather Rain) heals around the caster within 12, like Z / X
runGroup("A23-126 heal fairness", function()
	local C0 = sigWorld().Config
	local B = C0.BasicSkill
	check(B.HaloSelfHealCapPct == 0.03 and B.HaloHealCapPct == 0.30 and B.HaloHealRadius == 12
		and C0.Factions.Horns.LifestealCapPct == B.HaloSelfHealCapPct, "self 3% (= Horns life steal), friends 30%, ranged Q around me 12",
		show({ B.HaloSelfHealCapPct, B.HaloHealCapPct, B.HaloHealRadius }))
	check(C0.Skills.Defs.Mage.Q.Halo.DescEn == "A big star falls on the closest monster. Heals you and your friends."
		and C0.Skills.Defs.Archer.Q.Halo.DescEn == "Gold arrows rain on the closest group. Heals you and your friends.",
		"Star Fall / Feather Rain lines: '...Heals you and your friends.'")
	local function world()
		local w = sigWorld({})
		w.Got = {}
		local real = w.Combat.HealPlayer
		w.Combat.HealPlayer = function(pl, amount)
			local g = real(pl, amount)
			table.insert(w.Got, { P = pl, A = amount, G = g })
			return g
		end
		function w:HealOf(p, from)
			local n = 0
			for i = (from or 0) + 1, #self.Got do
				if self.Got[i].P == p then n += self.Got[i].G or 0 end
			end
			return n
		end
		return w
	end
	local function hurt(w, p, max, hp)
		w:Hum(p).MaxHealth, w:Hum(p).Health = max, hp
	end
	for _, cls in { "Warrior", "Mage", "Archer" } do
		-- alone: the Q heals me (A23-126: the solo hunter gets it), at most 3% of my MaxHealth per 3 s, Q + Z together
		local w = world()
		local p = w:Hero(1, { Class = cls, Faction = "Halo", Tier = 6, Mask = 63, Level = 40 })
		hurt(w, p, 1000, 100)
		for i = 0, 4 do w:Monster("BigSlime", 5, i - 2, 999999) end
		w:Use(p, "Q")
		local q = w:HealOf(p)
		check(q > 0 and q <= 30 + 1e-6, cls .. " Halo alone: the Q heals me, at most 3% (30 of 1000)", tostring(q))
		local mark = #w.Got
		w:Advance(0.6)
		w:Use(p, "Z")
		check(q + w:HealOf(p, mark) <= 30 + 1e-6, cls .. ": Q + Z within 3 s stay under the one 3% cap", tostring(q + w:HealOf(p, mark)))
		w:Advance(3.2)
		mark = #w.Got
		w:Use(p, "Q")
		check(w:HealOf(p, mark) > 0, cls .. ": 3 s later the cap has room again", tostring(w:HealOf(p, mark)))
		-- a friend beside me: up to 30%
		local w2 = world()
		local p2 = w2:Hero(1, { Class = cls, Faction = "Halo", Tier = 6, Mask = 63, Level = 40 })
		local f2 = w2:Hero(2, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 3) })
		hurt(w2, p2, 1000, 100)
		hurt(w2, f2, 1000, 100)
		for i = 0, 4 do w2:Monster("BigSlime", 5, i - 2, 999999) end
		w2:Use(p2, "Q")
		local mine, theirs = w2:HealOf(p2), w2:HealOf(f2)
		check(mine <= 30 + 1e-6 and theirs > 30 and theirs <= 300 + 1e-6, cls .. ": a friend gets more than my 3% (up to 30%)",
			show({ mine, theirs }))
	end
	-- the ranged Q heals around ME: a friend near me (far from the blast) is healed, one near the blast but 12+ from me not
	for _, cls in { "Mage", "Archer" } do
		local w = world()
		local p = w:Hero(1, { Class = cls, Faction = "Halo", Tier = 6, Mask = 63, Level = 40 })
		local nearMe = w:Hero(2, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, 10.5) }) -- 10.5 behind me (in 12, past 9), 30 from the blast
		local nearBlast = w:Hero(3, { Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, -21) }) -- 1 from the blast, 21 from me
		for _, pl in { nearMe, nearBlast } do hurt(w, pl, 1000, 100) end
		w:Monster("BigSlime", 20, 0, 999999)
		w:Use(p, "Q")
		check(w:HealOf(nearMe) > 0 and w:HealOf(nearBlast) == 0, cls .. " Halo Q: heals around me (12), not around the blast",
			show({ w:HealOf(nearMe), w:HealOf(nearBlast) }))
	end
	-- the Warrior's Q is around itself anyway (radius 9): a friend 10 away is not healed by its Q
	local ww = world()
	local pw = ww:Hero(1, { Class = "Warrior", Faction = "Halo", Tier = 6, Mask = 63, Level = 40 })
	local far = ww:Hero(2, { Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 10) })
	hurt(ww, far, 1000, 100)
	ww:Monster("BigSlime", 3, 0, 999999)
	ww:Use(pw, "Q")
	check(ww:HealOf(far) == 0, "Warrior Halo Q: still its own 9 around itself (a friend 10 away is not healed)", tostring(ww:HealOf(far)))
end)

runGroup("same numbers as before", function()
	local old = withSources(true, function() return sigWorld().Combat.Kit.Motion end)
	local new = withSources(false, function() return sigWorld().Combat.Kit.Motion end)
	check(old == nil and type(new) == "function", "setup: the baseline world runs the sources before A23-116 (no Kit.Motion there)",
		show({ type(old), type(new) }))
	local kits = { { "Warrior", "Halo" }, { "Warrior", "Horns" }, { "Mage", "Halo" }, { "Mage", "Horns" }, { "Archer", "Halo" },
		{ "Archer", "Horns" }, { "Warrior", "Neutral" }, { "Mage", "Neutral" }, { "Archer", "Neutral" } }
	-- the Halo / Horns kits once more with big HP (no cap binds)
	for i = 1, 6 do table.insert(kits, { kits[i][1], kits[i][2], true }) end
	for _, k in kits do
		local before, now = scene(true, k[1], k[2], k[3]), scene(false, k[1], k[2], k[3])
		local name = k[1] .. " " .. k[2] .. (k[3] and " (big HP, no cap)" or "")
		if k[2] ~= "Neutral" then
			check(now.Heals >= 3, name .. ": the scene really heals / steals (3+ heals given)", now.Heals)
		end
		local diff = nil
		for i = 1, math.max(#before.Lines, #now.Lines) do
			if before.Lines[i] ~= now.Lines[i] then
				diff = string.format("line %d: before [%s] now [%s]", i, tostring(before.Lines[i]), tostring(now.Lines[i]))
				break
			end
		end
		check(diff == nil, name .. ": damage, heal, steal, MP, pull / push and statuses identical to the sources before A23-116", diff)
		check(now.Damage >= 10 and now.Rel >= 6 and (k[1] == "Mage" or now.Moves >= 1),
			name .. ": the scene really hits (10+ hits, 6+ casts) and pulls / pushes (not the Mage kits)",
			show({ now.Damage, now.Rel, now.Moves }))
	end
end)

finish()
