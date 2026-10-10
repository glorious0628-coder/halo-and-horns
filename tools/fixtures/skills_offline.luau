-- skills_offline.luau : SKL-2 (A23-49, docs/design/skill_kit_beta_2026-10-06.md §1-§4, §9) server checks. tools/test_skills.py
-- binds the CURRENT Config, Util, CombatService, LootService, StoryQuestService, PvPService, DamageWindow, SkillService
-- and MonsterService (for the Displace chunk) plus the unarmed suite's extracts; dev2_kit.luau and dev2_combat_world.luau
-- come first. Players face -Z at the origin; monsters are records `dz` studs in front. Rules checked: slots / unlock,
-- the gap and the one queued press, refusals before MP, Line / Chain shapes, damage x Mult, pull / push, the 3 s
-- DamageWindow (player damage, Halo heal, Horns steal), PvPZX, Released / Fx contracts, the Z auto rules.

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
if not vmt.__unm then vmt.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end end

-- a world with SkillService; o.Z / o.X / o.PvP switch the flags on, o.Hit = every pair may fight (PvPService double)
local function skillWorld(o)
	o = o or {}
	local w = bareWorld({ Hit = o.Hit })
	local K = w.Config.Skills
	K.ZEnabled, K.XEnabled, K.PvPZX = o.Z == true, o.X == true, o.PvP == true
	-- A23-71 moved the unlocks to Q Lv5 / Z Lv15 / X Lv25 (the "slots" group runs those: o.RealUnlock). The shape, damage
	-- and auto groups keep their SKL-2 heroes (Lv5 = Q + Z, Lv9 = all three) with the SKL-2 unlock levels
	if not o.RealUnlock then K.Unlock = { Q = 1, Z = 5, X = 8 } end
	w.Rel = {}
	w.Combat.Released:Connect(function(p, info) table.insert(w.Rel, { P = p, Info = info }) end)
	-- a ready player with MP (the attribute the skills read); jo as w:Join plus Mana
	function w:Hero(id, jo)
		jo = jo or {}
		jo.Attrs = jo.Attrs or {}
		jo.Attrs.Mana = jo.Mana or 100
		return self:Join(id, jo)
	end
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
	function w:Count(slot)
		local n = 0
		for _, r in self.Rel do if r.Info.Slot == slot then n += 1 end end
		return n
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
	return w
end

local function hitOf(w, rec, from)
	local n = 0
	for i = (from or 0) + 1, #w.Damage do
		if w.Damage[i].Rec == rec then n += w.Damage[i].N end
	end
	return n
end

local function zDealt(w, p, mult)
	return w.Util.RoundDamage(w.Combat.ComputeMonsterHit(p, false) * mult)
end

------------------------------------------------------------------ slots (A23-71: no skill at the start, Q Lv5, Z Lv15, X Lv25)
runGroup("slots", function()
	local d0 = C0.Data.Defaults
	check(d0.SkillSlots == 0 and d0.SkillsA71 == true and table.find(C0.Data.Mirrored, "SkillSlots") ~= nil,
		"a new save has no skill yet (0 slots), follows the A23-71 rule, mirrored", show({ d0.SkillSlots, d0.SkillsA71 }))
	local U = C0.Skills.Unlock
	check(U.Q == 5 and U.Z == 15 and U.X == 25, "A23-71: Q Lv5, Z Lv15, X Lv25", show(U))
	local F = C0.SkillSlotsFor
	check(F(1, 0) == 0 and F(4, 0) == 0 and F(5, 0) == 1 and F(14, 0) == 1 and F(15, 0) == 2 and F(24, 0) == 2
		and F(25, 0) == 3 and F(99, 0) == 3 and F(1, 1) == 3 and F(nil, nil) == 0,
		"Config.SkillSlotsFor: Lv1 0, Lv4 0, Lv5 1, Lv14 1, Lv15 2, Lv24 2, Lv25 3; a rebirth 3; nothing 0",
		show({ F(1, 0), F(4, 0), F(5, 0), F(14, 0), F(15, 0), F(24, 0), F(25, 0), F(1, 1) }))
	local w = skillWorld({ Z = true, RealUnlock = true })
	local p1 = w:Hero(1, { Level = 1 })
	local p4 = w:Hero(2, { Level = 4 })
	local p5 = w:Hero(3, { Level = 5 })
	local p15 = w:Hero(4, { Level = 15 })
	local p25 = w:Hero(7, { Level = 25 })
	local pr = w:Hero(5, { Level = 1, Data = { Rebirths = 1 } })
	local pk = w:Hero(6, { Level = 1, Data = { SkillSlots = 3 } }) -- reached Lv25 before a free class change reset
	local function slots(p) return p:GetAttribute("SkillSlots") end
	check(slots(p1) == 0 and slots(p4) == 0 and slots(p5) == 1 and slots(p15) == 2 and slots(p25) == 3,
		"saves catch up at PlayerReady: Lv1 0, Lv4 0, Lv5 1, Lv15 2, Lv25 3",
		show({ slots(p1), slots(p4), slots(p5), slots(p15), slots(p25) }))
	check(slots(pr) == 3 and w.Data[pr].SkillSlots == 3, "a reborn player has all three", slots(pr))
	check(slots(pk) == 3, "slots are never taken away (Lv1 after a level reset keeps 3)", slots(pk))
	local f0 = #w.Fx
	check(#w:FxOf("SkillUnlocked", 0) == 0, "no unlock notice for a catch-up at join", #w:FxOf("SkillUnlocked", 0))
	-- before Lv5: Q is refused ('Locked', no MP), the old Release remote too
	w:Monster("Slime", 4, 0, 9999)
	w:Use(p1, "Q")
	check(w:Count("Q") == 0 and w:Press(p1) == "Q:Locked" and w:ManaSpent(p1) == 0, "Lv1: Q is locked ('Locked'), no MP",
		show({ w:Count("Q"), w:Press(p1), w:ManaSpent(p1) }))
	w:Advance(0.6)
	w.Net.Get("Release").OnServerEvent:Fire(p1)
	w:Flush()
	check(w:Count("Q") == 0 and w:ManaSpent(p1) == 0, "Lv1: the old Release remote is refused too", w:Count("Q"))
	-- level up: Lv4 -> 5 opens Q (always announced); 14 -> 15 opens Z (ZEnabled: announced); 24 -> 25 opens X (XEnabled
	-- off: saved, no notice)
	w.PS.SetStat(p4, "Level", 5)
	w.Registry.ProgressionService.LeveledUp:Fire(p4, 5)
	local un = w:FxOf("SkillUnlocked", f0)
	check(slots(p4) == 1 and w.Data[p4].SkillSlots == 1 and #un == 1 and un[1].Player == p4 and un[1].Data.Slot == "Q",
		"Lv5: Q opens with the 'new skill' notice", show({ slots(p4), #un, un[1] and un[1].Data.Slot }))
	w:Advance(0.6)
	w:Use(p4, "Q")
	check(w:Count("Q") == 1, "Lv5: Q casts", w:Count("Q"))
	w.PS.SetStat(p4, "Level", 15)
	w.Registry.ProgressionService.LeveledUp:Fire(p4, 15)
	un = w:FxOf("SkillUnlocked", f0)
	check(slots(p4) == 2 and #un == 2 and un[2].Data.Slot == "Z", "Lv15: Z opens with the notice (ZEnabled)",
		show({ slots(p4), #un }))
	w.PS.SetStat(p4, "Level", 25)
	w.Registry.ProgressionService.LeveledUp:Fire(p4, 25)
	check(slots(p4) == 3 and #w:FxOf("SkillUnlocked", f0) == 2, "Lv25: X opens and is saved, no notice while XEnabled is off",
		show({ slots(p4), #w:FxOf("SkillUnlocked", f0) }))
	-- a jump over two unlocks at once (Lv4 -> 16): Q and Z, in order
	local pj = w:Hero(8, { Level = 4 })
	local f1 = #w.Fx
	w.PS.SetStat(pj, "Level", 16)
	w.Registry.ProgressionService.LeveledUp:Fire(pj, 16)
	local uj = w:FxOf("SkillUnlocked", f1)
	check(slots(pj) == 2 and #uj == 2 and uj[1].Data.Slot == "Q" and uj[2].Data.Slot == "Z", "Lv4 -> 16 at once: Q then Z",
		show({ slots(pj), #uj }))
	w.PS.SetStat(p1, "Rebirths", 1)
	w.Registry.ProgressionService.Rebirthed:Fire(p1, 1)
	check(slots(p1) == 3, "a rebirth opens all three", slots(p1))
	-- the flag off: a Lv15 player's Z slot is saved but Z is refused
	local w2 = skillWorld({ Z = false, RealUnlock = true })
	local q15 = w2:Hero(1, { Level = 15 })
	check(q15:GetAttribute("SkillSlots") == 2, "ZEnabled off: the slot is still saved", q15:GetAttribute("SkillSlots"))
	w2:Monster("Slime", 8, 0, 9999)
	w2:Use(q15, "Z")
	check(w2:Count("Z") == 0 and w2:Press(q15) == "Z:Locked" and w2:ManaSpent(q15) == 0, "ZEnabled off: Z is refused ('Locked'), no MP",
		show({ w2:Count("Z"), w2:Press(q15) }))
	-- not unlocked yet: Lv14
	local w3 = skillWorld({ Z = true, RealUnlock = true })
	local q14 = w3:Hero(1, { Level = 14 })
	w3:Monster("Slime", 8, 0, 9999)
	w3:Use(q14, "Z")
	check(w3:Count("Z") == 0 and w3:Press(q14) == "Z:Locked", "Lv14: Z is locked", w3:Press(q14))
	-- auto combat before the first skill: it swings, but never casts
	local w4 = skillWorld({ Z = true, RealUnlock = true })
	local a1 = w4:Hero(1, { Level = 3, Tier = 1, Mask = 1, Class = "Warrior",
		Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	w4:Monster("Slime", 4, 0, 99999)
	w4:Monster("Slime", 6, 0, 99999)
	for _ = 1, 4 do
		w4:AutoTick()
		w4:Advance(0.6)
	end
	check(w4:Count("Q") == 0 and w4:Count("Z") == 0 and w4:ManaSpent(a1) == 0 and #w4:FxOf("SkillPress", 0) == 0,
		"auto combat at Lv3: no skill cast, no MP, no press answer", show({ w4:Count("Q"), w4:Count("Z"), w4:ManaSpent(a1) }))
end)

------------------------------------------------------------------ the remote, the gap and the queue
runGroup("gap and queue", function()
	local w = skillWorld({ Z = true })
	local p = w:Hero(1, { Level = 5, Tier = 1, Mask = 1 })
	w:Monster("Slime", 8, 0, 99999)
	-- bad presses are ignored
	w:Use(p, "W")
	w:Use(p, 2)
	w:Use(p, "Z", "extra")
	w:Use(p)
	check(#w.Rel == 0 and w:Press(p) == "", "a bad slot, a number, an extra argument or nothing: ignored", show({ #w.Rel, w:Press(p) }))
	-- the rate limit (0.1 s)
	w.Net.Get("UseSkill").OnServerEvent:Fire(p, "Z")
	w.Net.Get("UseSkill").OnServerEvent:Fire(p, "Q")
	w:Flush()
	check(w:Count("Z") == 1 and w:Count("Q") == 0 and w:Press(p) == "", "two presses in the same instant: the second is dropped (rate limit)",
		show({ w:Count("Z"), w:Count("Q"), w:Press(p) }))
	-- 0.11 s later: inside the 0.5 s gap -> queued once, fires when the gap ends
	local f0 = #w.Fx
	w:Use(p, "Q")
	check(w:Count("Q") == 0 and w:Press(p, f0) == "Q:Queued", "Q 0.11 s after Z: queued ('Queued')", w:Press(p, f0))
	w:Use(p, "Q")
	check(w:Press(p, f0) == "Q:Queued", "a second press while one is queued adds nothing", w:Press(p, f0))
	w:Advance(0.3) -- 0.52 s after Z
	check(w:Count("Q") == 1 and w:Last("Q").Auto == false, "the queued Q goes off when the gap ends", w:Count("Q"))
	-- the gap holds an auto cast back without queueing it
	local before = #w.Rel
	check(w.Skills.Cast(p, "Q", true) == false and #w.Rel == before, "an auto cast inside the gap simply waits", #w.Rel - before)
	-- the old Release remote goes through the same gap
	w:Advance(3)
	w.Net.Get("Release").OnServerEvent:Fire(p)
	w:Flush()
	check(w:Count("Q") == 2, "the old Release remote still casts Q (through SkillService)", w:Count("Q"))
	w:Advance(0.3)
	local f1 = #w.Fx
	w.Net.Get("Release").OnServerEvent:Fire(p)
	w:Flush()
	check(w:Press(p, f1) == "Q:Queued" or w:Press(p, f1) == "Q:Cooldown", "a Release press inside the gap is queued too (or on cooldown)",
		w:Press(p, f1))
	-- the gap counts from Q too
	w:Advance(0.2) -- the queued Q goes off on time: Q is still on its 3 s cooldown
	check(w:Count("Q") == 2 and w:Press(p, f1) == "Q:Queued,Q:Cooldown", "a queued Q that comes due on cooldown says 'Cooldown'",
		w:Press(p, f1))
	w:Advance(3)
	w:Use(p, "Q")
	check(w:Count("Q") == 3, "setup: Q again after its cooldown", w:Count("Q"))
	local f2 = #w.Fx
	w:Use(p, "Z")
	check(w:Press(p, f2) == "Z:Queued", "Z 0.11 s after Q: queued (the gap counts from any skill)", w:Press(p, f2))
	w:Use(p, "Q")
	check(w:Press(p, f2) == "Z:Queued", "while Z waits, another press is not queued as well", w:Press(p, f2))
	w:Advance(0.3)
	check(w:Count("Z") == 2 and w:Count("Q") == 3, "the queued Z goes off; the extra Q press is gone", show({ w:Count("Z"), w:Count("Q") }))
	-- a queued press dies with the character
	local w2 = skillWorld({ Z = true })
	local q = w2:Hero(1, { Level = 5, Tier = 1, Mask = 1 })
	w2:Monster("Slime", 8, 0, 99999)
	w2:Use(q, "Z")
	w2:Use(q, "Q")
	w2:Body(q) -- a new character before the gap ends
	w2:Advance(0.5)
	check(w2:Count("Q") == 0, "a queued press is dropped when the character changes", w2:Count("Q"))
end)

------------------------------------------------------------------ refusals before MP
runGroup("refusals", function()
	local w = skillWorld({ Z = true })
	local p = w:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior" })
	w:Monster("Slime", 8, 0, 99999)
	w:Use(p, "Z")
	local spent = w:ManaSpent(p)
	check(w:Count("Z") == 1 and spent == 25 and p:GetAttribute("SkillReadyAtZ") == w.Time - 0.11 + 0.11 + 6,
		"Earth Cleave: MP 25, SkillReadyAtZ = now + 6 s", show({ spent, p:GetAttribute("SkillReadyAtZ"), w.Time }))
	w:Advance(3)
	local f0 = #w.Fx
	w:Use(p, "Z")
	check(w:Count("Z") == 1 and w:Press(p, f0) == "Z:Cooldown" and w:ManaSpent(p) == spent, "Z on its 6 s cooldown: 'Cooldown', no MP",
		show({ w:Press(p, f0), w:ManaSpent(p) }))
	w:Advance(3)
	p:SetAttribute("Mana", 24)
	f0 = #w.Fx
	w:Use(p, "Z")
	check(w:Count("Z") == 1 and w:Press(p, f0) == "Z:NoMP" and w:ManaSpent(p) == spent, "24 MP for a 25 MP skill: 'NoMP', nothing spent",
		w:Press(p, f0))
	p:SetAttribute("Mana", 19)
	f0 = #w.Fx
	w:Use(p, "Q")
	check(w:Count("Q") == 0 and w:Press(p, f0) == "Q:NoMP", "Q with 19 MP: 'NoMP' (before CombatService)", w:Press(p, f0))
	p:SetAttribute("Mana", 100)
	w:Use(p, "Q")
	w:Advance(1)
	f0 = #w.Fx
	w:Use(p, "Q")
	check(w:Count("Q") == 1 and w:Press(p, f0) == "Q:Cooldown", "Q on its 3 s cooldown: 'Cooldown'", w:Press(p, f0))
	-- Chain needs a target: no MP, no cooldown
	local m = skillWorld({ Z = true })
	local mage = m:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage" })
	m:Use(mage, "Z")
	check(m:Count("Z") == 0 and m:Press(mage) == "Z:NoTarget" and m:ManaSpent(mage) == 0 and (mage:GetAttribute("SkillReadyAtZ") or 0) == 0,
		"Chain Bolt with nothing in range: 'NoTarget', no MP, no cooldown", show({ m:Press(mage), m:ManaSpent(mage) }))
	m:Monster("Slime", 30, 0, 99999)
	m:Use(mage, "Z")
	check(m:Count("Z") == 1 and m:ManaSpent(mage) == 25, "a monster 30 studs ahead: the chain goes (MP 25)", m:Count("Z"))
	-- a monster behind but beyond the chain's range (35) is no target (within range it is: group "aim behind")
	local b = skillWorld({ Z = true })
	local mage2 = b:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage" })
	b:Monster("Slime", -36, 0, 99999)
	b:Use(mage2, "Z")
	check(b:Count("Z") == 0 and b:Press(mage2) == "Z:NoTarget", "a monster behind beyond 35 studs is no target", b:Press(mage2))
	-- SKL-3: with XEnabled the Warrior's X is Guardian Roar (MP 30); its rules are in tools/test_skills_x.py
	local x = skillWorld({ Z = true, X = true })
	local px = x:Hero(1, { Level = 9, Tier = 1, Mask = 1 })
	x:Monster("Slime", 6, 0, 99999)
	x:Use(px, "X")
	check(x:Count("X") == 1 and x:ManaSpent(px) == 30 and x:Last("X").MonstersHit == 1,
		"SKL-3: X goes off with XEnabled (Guardian Roar, MP 30)", show({ x:Count("X"), x:ManaSpent(px) }))
end)

------------------------------------------------------------------ Line
runGroup("line", function()
	local w = skillWorld({ Z = true })
	local p = w:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns" })
	local inA = w:Monster("Slime", 10, 0, 99999) -- along 10
	local inB = w:Monster("Slime", 20, 4.9, 99999) -- along 20, across 4.9 <= 5
	local wide = w:Monster("Slime", 10, 5.2, 99999) -- across 5.2 > 5
	local far = w:Monster("Slime", 22.5, 0, 99999) -- along 22.5 > 22
	local behind = w:Monster("Slime", -3, 0, 99999)
	local f0 = #w.Fx
	w:Use(p, "Z")
	local dealt = zDealt(w, p, 7.5)
	check(hitOf(w, inA) == dealt and hitOf(w, inB) == dealt, "Earth Cleave hits the band 22 x 10: D x 7.5 each", show({ hitOf(w, inA), dealt }))
	check(hitOf(w, wide) == 0 and hitOf(w, far) == 0 and hitOf(w, behind) == 0, "outside the band (5.2 across, 22.5 along, behind): no hit",
		show({ hitOf(w, wide), hitOf(w, far), hitOf(w, behind) }))
	local info = w:Last("Z")
	check(info and info.MonstersHit == 2 and info.Auto == false and info.Slot == "Z" and info.PlayersHit == 0
		and info.Total == 2 * dealt and info.Stacks == 0 and info.Perfect == false,
		"Released { Slot Z, MonstersHit 2, Auto false, Total }", show(info and { info.Slot, info.MonstersHit, info.Total, dealt }))
	w:Advance(0.25) -- A23-116: the pull starts at the Warrior's ContactDelay (0.24 s)
	local pulls = {}
	for _, d in w.Displaced do table.insert(pulls, d.Mode .. d.Studs) end
	check(#w.Displaced == 2 and w.Displaced[1].Mode == "Pull" and w.Displaced[1].Studs == 5 and w.Displaced[1].P == p
		and w.Displaced[1].From.Z == 0, "a manual Earth Cleave pulls each hit monster 5 studs toward me", show(pulls))
	local fx = w:FxOf("Skill", f0)
	local d = fx[1] and fx[1].Data
	check(#fx >= 1 and d.Slot == "Z" and d.Shape == "Line" and d.Kit == "Warrior" and d.Faction == "Horns" and d.Len == 22
		and d.Width == 10 and math.abs(d.Dir.Z + 1) < 1e-6 and d.Life == 0.3 and d.Auto == false and #d.Hits == 2
		and d.Hits[1].K == "M" and d.Hits[1].A == dealt and type(d.Statuses) == "table" and d.UserId == 1,
		"Fx 'Skill' { Slot, Kit, Faction, Shape Line, Dir, Len, Width, Life 0.3, Hits }", show(d and { d.Slot, d.Shape, d.Len }))
	-- the band turns to the nearest monster in the 75-degree cone
	local w2 = skillWorld({ Z = true })
	local p2 = w2:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior" })
	local side = w2:Monster("Slime", 8, 8, 99999) -- 45 degrees right
	local onLine = w2:Monster("Slime", 12, 12, 99999) -- the same direction, farther (17 along)
	local ahead = w2:Monster("Slime", 15, 0, 99999) -- straight ahead, farther than `side`
	w2:Use(p2, "Z")
	check(hitOf(w2, side) > 0 and hitOf(w2, onLine) > 0 and hitOf(w2, ahead) == 0, "the band points at the nearest aimed monster (45 deg)",
		show({ hitOf(w2, side), hitOf(w2, onLine), hitOf(w2, ahead) }))
	-- nothing in front: straight ahead, still a cast (MP spent, MonstersHit 0)
	local w3 = skillWorld({ Z = true })
	local p3 = w3:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior" })
	w3:Use(p3, "Z")
	check(w3:Count("Z") == 1 and w3:Last("Z").MonstersHit == 0 and w3:ManaSpent(p3) == 25, "no monster: the band goes straight ahead (a whiff)",
		w3:Count("Z"))
	-- Pierce Shot: 40 x 4 toward the aimed target within 40, pushes 3
	local a = skillWorld({ Z = true })
	local archer = a:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Archer" })
	local near = a:Monster("Slime", 12, 0, 99999)
	local deep = a:Monster("Slime", 38, 1.9, 99999)
	local off = a:Monster("Slime", 20, 2.2, 99999)
	a:Use(archer, "Z")
	local ad = zDealt(a, archer, 9)
	check(hitOf(a, near) == ad and hitOf(a, deep) == ad and hitOf(a, off) == 0, "Pierce Shot: the whole 40 x 4 line at D x 9",
		show({ hitOf(a, near), hitOf(a, deep), hitOf(a, off), ad }))
	a:Advance(0.41) -- A23-116: the push starts at the Archer's ContactDelay (0.4 s)
	check(#a.Displaced == 2 and a.Displaced[1].Mode == "Push" and a.Displaced[1].Studs == 3, "Pierce Shot pushes 3 studs", #a.Displaced)
	-- the pet tamer: the archer table (Slime Roll), its own kit name
	local t = skillWorld({ Z = true })
	local tamer = t:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Archer", Faction = "Neutral" })
	t:Monster("Slime", 30, 0, 99999)
	local tf = #t.Fx
	t:Use(tamer, "Z")
	local td = t:FxOf("Skill", tf)[1]
	check(t:Count("Z") == 1 and td and td.Data.Kit == "Tamer" and td.Data.Len == 40, "the pet tamer's Z = Slime Roll (Kit Tamer, line 40)",
		show(td and td.Data.Kit))
end)

------------------------------------------------------------------ Chain
runGroup("chain", function()
	local w = skillWorld({ Z = true })
	local p = w:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage" })
	local A = w:Monster("Slime", 20, 0, 99999)
	local B = w:Monster("Slime", 28, 0, 99999) -- 8 from A
	local Cm = w:Monster("Slime", 28, 7, 99999) -- 7 from B
	local D = w:Monster("Slime", 37, 7, 99999) -- 9 from C
	local E = w:Monster("Slime", 40, 14, 99999) -- 7.6 from D: a fifth link
	local Far = w:Monster("Slime", 20, -12, 99999) -- 12 from A: never reached
	local f0 = #w.Fx
	w:Use(p, "Z")
	local dealt = zDealt(w, p, 5)
	check(hitOf(w, A) == dealt and hitOf(w, B) == dealt and hitOf(w, Cm) == dealt and hitOf(w, D) == dealt,
		"Chain Bolt: A -> B -> C -> D (jumps <= 10), D x 5 each", show({ hitOf(w, A), hitOf(w, B), hitOf(w, Cm), hitOf(w, D), dealt }))
	check(hitOf(w, E) == 0 and hitOf(w, Far) == 0, "four hits at most; 12 studs is too far to jump", show({ hitOf(w, E), hitOf(w, Far) }))
	local fx = w:FxOf("Skill", f0)[1]
	check(fx and fx.Data.Shape == "Chain" and #fx.Data.Points == 4 and fx.Data.Points[2].Z == -28 and fx.Data.Radius == 10,
		"Fx 'Skill' Chain with the 4 points in order", show(fx and #fx.Data.Points))
	w:Advance(1) -- A23-116: past any contact time
	check(#w.Displaced == 0, "the chain moves nobody", #w.Displaced)
	-- 12 studs is too far to jump
	local wj = skillWorld({ Z = true })
	local pj = wj:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage" })
	local first = wj:Monster("Slime", 20, 0, 99999)
	local gapped = wj:Monster("Slime", 32, 0, 99999)
	wj:Use(pj, "Z")
	check(hitOf(wj, first) > 0 and hitOf(wj, gapped) == 0 and wj:Last("Z").MonstersHit == 1, "the next monster 12 studs on: no jump",
		show({ hitOf(wj, first), hitOf(wj, gapped) }))
	-- never the same monster twice
	local w2 = skillWorld({ Z = true })
	local p2 = w2:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage" })
	local a = w2:Monster("Slime", 10, 0, 99999)
	local b = w2:Monster("Slime", 15, 0, 99999)
	w2:Use(p2, "Z")
	check(hitOf(w2, a) == zDealt(w2, p2, 5) and hitOf(w2, b) == zDealt(w2, p2, 5) and w2:Last("Z").MonstersHit == 2,
		"two monsters: two hits, no bouncing back", show({ hitOf(w2, a), hitOf(w2, b) }))
	-- the alchemist: the same chain, its own kit
	local al = skillWorld({ Z = true })
	local alc = al:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Faction = "Neutral" })
	al:Monster("Slime", 10, 0, 99999)
	local af = #al.Fx
	al:Use(alc, "Z")
	local fxa = al:FxOf("Skill", af)[1]
	check(fxa and fxa.Data.Kit == "Alchemist" and fxa.Data.Shape == "Chain", "the alchemist's Z = Bubble Hop (Kit Alchemist)",
		show(fxa and fxa.Data.Kit))
end)

------------------------------------------------------------------ players and the 3 s window
runGroup("pvp window", function()
	-- PvPZX off: Z never hits a player, even an enemy in the band
	local w = skillWorld({ Z = true, Hit = true })
	local a = w:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Halo" })
	local v = w:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns", Pos = vec(0, 0, -6) })
	local vh = v.Character:FindFirstChild("Humanoid")
	w:Use(a, "Z")
	check(w:Count("Z") == 1 and vh.Health == 100 and w:Last("Z").PlayersHit == 0, "PvPZX off: Z leaves players alone", vh.Health)
	-- PvPZX on: Q then Z inside 3 s share one 35% cap
	local p = skillWorld({ Z = true, Hit = true, PvP = true })
	local atk = p:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Halo" })
	local vic = p:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns", Pos = vec(0, 0, -6) })
	local hum = vic.Character:FindFirstChild("Humanoid")
	check(p.Combat.ComputePvPHit(atk, vic) * 6 > 35, "setup: one Q alone would deal more than 35% of 100 HP", p.Combat.ComputePvPHit(atk, vic))
	p:Use(atk, "Q")
	check(hum.Health == 65, "Q: 35 (the window's cap)", hum.Health)
	p:Advance(0.5)
	p:Use(atk, "Z")
	check(p:Count("Z") == 1 and hum.Health == 65 and p:Last("Z").PlayersHit == 0, "Z 0.6 s later: the window is used up, no damage",
		show({ hum.Health, p:Last("Z").PlayersHit }))
	p:Advance(2.4) -- 3.1 s after Q
	hum.Health = 100
	p:Use(atk, "Q")
	check(hum.Health == 65, "3 s later the window is open again (Q 35)", hum.Health)
	-- a fresh pair: Z first deals up to 35, then Q nothing
	local q = skillWorld({ Z = true, Hit = true, PvP = true })
	local atk2 = q:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns" })
	local vic2 = q:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Halo", Pos = vec(0, 0, -6) })
	local hum2 = vic2.Character:FindFirstChild("Humanoid")
	q:Use(atk2, "Z")
	local afterZ = hum2.Health
	q:Advance(0.5)
	q:Use(atk2, "Q")
	check(afterZ == 65 and hum2.Health == 65 and q:Last("Z").PlayersHit == 1, "Z then Q: 35 together (Z hit, Q nothing)",
		show({ afterZ, hum2.Health }))
	-- an auto Z never picks or hits a player
	local r = skillWorld({ Z = true, Hit = true, PvP = true })
	local atk3 = r:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Halo",
		Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	local vic3 = r:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns", Pos = vec(0, 0, -8) })
	r:Monster("BigSlime", 12, 0, 99999)
	local hum3 = vic3.Character:FindFirstChild("Humanoid")
	r.Skills.Cast(atk3, "Z", true)
	check(r:Count("Z") == 1 and r:Last("Z").Auto == true and hum3.Health == 100, "an auto Z hits the monster, never the player",
		show({ r:Count("Z"), hum3.Health }))
	-- the artisan guild never hits players
	local s = skillWorld({ Z = true, Hit = true, PvP = true })
	local smith = s:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Neutral" })
	local vic4 = s:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns", Pos = vec(0, 0, -6) })
	s:Use(smith, "Z")
	check(s:Count("Z") == 1 and vic4.Character:FindFirstChild("Humanoid").Health == 100, "a blacksmith's Hook Chain never hits a player",
		vic4.Character:FindFirstChild("Humanoid").Health)
end)

------------------------------------------------------------------ Halo heal / Horns steal through the window
runGroup("heal and steal", function()
	local w = skillWorld({ Z = true })
	local p = w:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Halo" })
	local ally = w:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 8) })
	local away = w:Hero(3, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Faction = "Halo", Pos = vec(0, 0, 13) })
	local ah, wh = ally.Character:FindFirstChild("Humanoid"), away.Character:FindFirstChild("Humanoid")
	ah.Health, wh.Health = 40, 40
	for i = 0, 4 do w:Monster("Slime", 6 + i * 3.5, 0, 99999) end
	w:Use(p, "Z")
	local total = w:Last("Z").Total
	check(total >= 300, "setup: Z removed 300+ HP (5 monsters)", total)
	check(ah.Health == 70 and wh.Health == 40, "Halo Z heals an ally 8 studs away up to 30% (window), not one 13 away",
		show({ ah.Health, wh.Health, total }))
	local healed = w:Last("Z").Healed
	check(type(healed) == "table" and #healed == 1 and healed[1] == ally, "Released.Healed = the other players healed",
		type(healed) == "table" and #healed or "none")
	w:Advance(0.5)
	w:Use(p, "Q")
	check(ah.Health == 70 and #w:Last("Q").Healed == 0, "Q right after: that ally's 30% is used up for 3 s", ah.Health)
	w:Advance(3)
	w:Use(p, "Q")
	check(ah.Health > 70, "3 s later Q heals again", ah.Health)
	-- Horns: life steal 10% of the damage, at most 3% of MaxHealth per 3 s across Q + Z
	local h = skillWorld({ Z = true })
	local horn = h:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns" })
	local hh = horn.Character:FindFirstChild("Humanoid")
	hh.Health = 50
	for i = 0, 4 do h:Monster("Slime", 6 + i * 3.5, 0, 99999) end
	h:Use(horn, "Z")
	check(hh.Health == 53, "Horns Z steals 3 (3% of 100)", hh.Health)
	h:Advance(0.5)
	h:Use(horn, "Q")
	check(hh.Health == 53, "Q 0.5 s later steals nothing more (same window)", hh.Health)
	h:Advance(3)
	h:Use(horn, "Q")
	check(hh.Health == 56, "3 s later Q steals again", hh.Health)
	-- the artisan: neither
	local n = skillWorld({ Z = true })
	local smith = n:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Neutral" })
	local sh = smith.Character:FindFirstChild("Humanoid")
	sh.Health = 50
	n:Monster("Slime", 8, 0, 99999)
	n:Use(smith, "Z")
	check(sh.Health == 50 and #n:Last("Z").Healed == 0, "the artisan heals and steals nothing (A6)", sh.Health)
end)

------------------------------------------------------------------ auto combat: Z rules, the gap before Q
runGroup("auto", function()
	local auto = { AutoCombatUnlocked = true, AutoCombatEnabled = true }
	-- Warrior: two monsters in the band -> Z (no pull), then Q waits for the gap
	local w = skillWorld({ Z = true })
	local p = w:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Attrs = auto })
	w:Monster("Slime", 4, 0, 99999)
	w:Monster("Slime", 8, 0, 99999)
	w:AutoTick()
	check(w:Count("Z") == 1 and w:Last("Z").Auto == true and #w.Displaced == 0 and w:Count("Q") == 0,
		"auto Warrior: 2 in the band -> Earth Cleave without the pull", show({ w:Count("Z"), #w.Displaced, w:Count("Q") }))
	w:AutoTick()
	check(w:Count("Q") == 0, "the next tick: Q waits for the 0.5 s gap", w:Count("Q"))
	w:Advance(0.5)
	check(#w.Displaced == 0, "the auto Earth Cleave never pulls (also after its contact time)", #w.Displaced)
	w:AutoTick()
	check(w:Count("Q") == 1 and w:Count("Z") == 1, "after the gap: Q (Z on its cooldown)", show({ w:Count("Q"), w:Count("Z") }))
	check(#w:FxOf("SkillPress", 0) == 0, "auto casts never send the press answer", #w:FxOf("SkillPress", 0))
	-- one small monster: no Z (Q instead); one big monster: Z
	local w2 = skillWorld({ Z = true })
	local p2 = w2:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Attrs = auto })
	w2:Monster("Slime", 5, 0, 99999)
	w2:AutoTick()
	check(w2:Count("Z") == 0 and w2:Count("Q") == 1, "auto Warrior: one small monster -> Q, not Z", show({ w2:Count("Z"), w2:Count("Q") }))
	local w3 = skillWorld({ Z = true })
	w3:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Attrs = auto })
	w3:Monster("BigSlime", 6, 0, 99999)
	w3:AutoTick()
	check(w3:Count("Z") == 1, "auto Warrior: one big monster (King Slime) -> Z", w3:Count("Z"))
	-- ZEnabled off / Lv4: never
	local w4 = skillWorld({ Z = false })
	w4:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Attrs = auto })
	w4:Monster("Slime", 4, 0, 99999)
	w4:Monster("Slime", 8, 0, 99999)
	w4:AutoTick()
	check(w4:Count("Z") == 0 and w4:Count("Q") == 1, "ZEnabled off: auto stays Q only", show({ w4:Count("Z"), w4:Count("Q") }))
	-- Mage: one target -> Q first while Q is ready; Z when Q is on cooldown
	local m = skillWorld({ Z = true })
	m:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Attrs = auto })
	m:Monster("Slime", 20, 0, 99999)
	m:AutoTick()
	check(m:Count("Q") == 1 and m:Count("Z") == 0, "auto Mage, one target: Q first", show({ m:Count("Q"), m:Count("Z") }))
	m:Advance(0.5)
	m:AutoTick()
	check(m:Count("Z") == 1, "Q on cooldown: Chain Bolt", m:Count("Z"))
	-- Mage: two spread targets -> Z before Q
	local m2 = skillWorld({ Z = true })
	m2:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Attrs = auto })
	m2:Monster("Slime", 20, 0, 99999)
	m2:Monster("Slime", 29.5, 0, 99999) -- 9.5 apart: outside one Q circle (9), inside a jump (10)
	m2:AutoTick()
	check(m2:Count("Z") == 1 and m2:Count("Q") == 0, "auto Mage, 2 spread targets: Chain Bolt before Q", show({ m2:Count("Z"), m2:Count("Q") }))
	-- Archer: one on the line -> Z
	local ar = skillWorld({ Z = true })
	ar:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Archer", Attrs = auto })
	ar:Monster("Slime", 25, 0, 99999)
	ar:AutoTick()
	check(ar:Count("Z") == 1 and ar:Last("Z").Auto == true, "auto Archer: one on the line -> Pierce Shot", ar:Count("Z"))
	-- my own press wins: auto waits after a manual skill press
	local mw = skillWorld({ Z = true })
	local mp = mw:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Attrs = auto })
	mw:Monster("Slime", 4, 0, 99999)
	mw:Monster("Slime", 8, 0, 99999)
	mw:Use(mp, "Q")
	mw:Advance(0.5)
	mw:AutoTick()
	check(mw:Count("Z") == 0, "right after my own press auto combat yields (no auto Z)", mw:Count("Z"))
end)

------------------------------------------------------------------ respawn / leave
runGroup("respawn and leave", function()
	local w = skillWorld({ Z = true })
	local p = w:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior" })
	w:Monster("Slime", 8, 0, 99999)
	w:Use(p, "Z")
	w:Advance(1)
	w.PS.CharacterSpawned:Fire(p, p.Character, p.Character:FindFirstChild("Humanoid"), true) -- cosmetic
	w:Use(p, "Z")
	check(w:Count("Z") == 1, "a cosmetic respawn keeps the Z cooldown", w:Count("Z"))
	w.PS.CharacterSpawned:Fire(p, p.Character, p.Character:FindFirstChild("Humanoid"), false)
	check(p:GetAttribute("SkillReadyAtZ") == 0, "a real respawn clears SkillReadyAtZ", p:GetAttribute("SkillReadyAtZ"))
	w:Use(p, "Z")
	check(w:Count("Z") == 2, "a real respawn resets the Z cooldown (like Q)", w:Count("Z"))
	-- the window forgets a player who left
	local W = w.Window
	local other = w:Hero(2, { Level = 5 })
	W.Book("Hit", p, other, 20)
	check(W.Room("Hit", p, other, 35) == 15, "setup: 20 of 35 booked", W.Room("Hit", p, other, 35))
	w.PS.PlayerLeaving:Fire(other)
	check(W.Room("Hit", p, other, 35) == 35, "a player who leaves is forgotten (both ways)", W.Room("Hit", p, other, 35))
end)

------------------------------------------------------------------ DamageWindow on its own
runGroup("window", function()
	local w = skillWorld({})
	local W = w.Window
	local a, b = w:Hero(1, {}), w:Hero(2, {})
	check(W.Seconds == 3, "the window is 3 s", W.Seconds)
	check(W.Room("Hit", a, b, 35) == 35 and W.Room("Hit", a, b, 0) == 0 and W.Room("Hit", a, b, 0 / 0) == 0, "an empty window: the whole cap",
		W.Room("Hit", a, b, 35))
	W.Book("Hit", a, b, 20)
	W.Book("Hit", a, b, 0 / 0)
	W.Book("Hit", a, b, -5)
	W.Book("Hit", a, b, math.huge)
	check(W.Room("Hit", a, b, 35) == 15 and W.Room("Hit", b, a, 35) == 35 and W.Room("Heal", a, b, 35) == 35,
		"booked per pair and kind (bad numbers ignored)", show({ W.Room("Hit", a, b, 35), W.Room("Hit", b, a, 35) }))
	w:Advance(1)
	W.Book("Hit", a, b, 10)
	w:Advance(1.9)
	check(W.Room("Hit", a, b, 35) == 5, "2.9 s later both still count", W.Room("Hit", a, b, 35))
	w:Advance(0.1)
	check(W.Room("Hit", a, b, 35) == 25, "at 3 s the first one drops out", W.Room("Hit", a, b, 35))
	W.Book("Hit", a, b, 100)
	check(W.Room("Hit", a, b, 35) == 0, "never below 0", W.Room("Hit", a, b, 35))
end)

------------------------------------------------------------------ MonsterService.Displace (the real code, cut out)
runGroup("displace", function()
	local src = MONSTER_SOURCE
	local function cut(startText, endText)
		local i = string.find(src, startText, 1, true)
		local j = i and string.find(src, endText, i, true)
		return (i and j) and string.sub(src, i, j - 1) or ""
	end
	local inside = cut("local function insideZone(", "-- A10-V3-2 (b): clamp a destination")
	local body = cut("local DISPLACE = {", "------------------------------------------------------------------ event monsters")
	check(#inside > 0 and #body > 0, "Displace found in MonsterService", show({ #inside, #body }))
	local w = newWorld({})
	local cfg = w.Config
	local W = { Wall = false, WaterX = nil }
	local env = w:Env()
	env.workspace = { GetServerTimeNow = function() return w.Time end,
		Raycast = function() return W.Wall and { Position = vec(0, 0, 0) } or nil end }
	local MS = {}
	local chunk = "local Config, Util, MC, MonsterService, ZONE_MOVE_INSET, groundPoint, getShoveParams, warnThrottled = ...\n"
		.. inside .. body .. "\nreturn MonsterService"
	execute("MonsterService.Displace", chunk, env, cfg, w.Util, cfg.Monsters, MS, 6,
		function(x, z)
			if W.WaterX and x > W.WaterX then return nil, false end
			return vec(x, 0, z), false
		end,
		function() return {} end, function(k, m) table.insert(w.Warnings, "displace " .. tostring(k) .. tostring(m)) end)
	local zone = cfg.Zones.SlimeMeadow
	local c = vec(zone.Center.X, 0, zone.Center.Z)
	local function rec(at, o)
		o = o or {}
		local r = { Alive = true, Kind = o.Kind or "Slime", Def = cfg.MonsterTypes[o.Kind or "Slime"], ZoneId = "SlimeMeadow",
			Home = o.Home or c, Owner = o.Owner, _scale = o.Scale or 1,
			Root = { Parent = true, Anchored = false, Position = at } }
		return r
	end
	local n0 = #w.Spawned
	check(cfg.ZoneAt(c).Id == "SlimeMeadow", "setup: the meadow center is in the meadow", cfg.ZoneAt(c).Id)
	check(math.abs(MS.Displace(rec(c), "Pull", c + vec(20, 0, 0), 5, nil) - 5) < 1e-9 and #w.Spawned == n0 + 1,
		"Pull 5 from 20 studs: moves 5 (a slide starts)", #w.Spawned - n0)
	check(math.abs(MS.Displace(rec(c), "Pull", c + vec(6, 0, 0), 5, nil) - 3) < 1e-9, "Pull stops 3 studs in front of the caster (6 away: 3)",
		MS.Displace(rec(c), "Pull", c + vec(6, 0, 0), 5, nil))
	check(MS.Displace(rec(c), "Pull", c + vec(2.5, 0, 0), 5, nil) == 0, "already within 3 studs: no pull", "")
	check(math.abs(MS.Displace(rec(c), "Push", c + vec(-1, 0, 0), 3, nil) - 3) < 1e-9, "Push 3", "")
	check(math.abs(MS.Displace(rec(c, { Scale = 2 }), "Push", c + vec(-1, 0, 0), 4, nil) - 2) < 1e-9, "a monster twice as big moves half",
		MS.Displace(rec(c, { Scale = 2 }), "Push", c + vec(-1, 0, 0), 4, nil))
	check(MS.Displace(rec(c, { Kind = "PumpkinKing" }), "Pull", c + vec(20, 0, 0), 5, nil) == 0, "a boss never moves", "")
	local someone, me = {}, {}
	check(MS.Displace(rec(c, { Owner = someone }), "Pull", c + vec(20, 0, 0), 5, me) == 0
		and math.abs(MS.Displace(rec(c, { Owner = me }), "Pull", c + vec(20, 0, 0), 5, me) - 5) < 1e-9,
		"someone else's personal monster never moves (my own does)", "")
	-- leash: home 58 studs behind; a push of 5 would end 63 from home -> the 1/4 step (59.25)
	local leashRec = rec(c, { Home = c - vec(58, 0, 0) })
	check(math.abs(MS.Displace(leashRec, "Push", c - vec(1, 0, 0), 5, nil) - 1.25) < 1e-9, "the leash (60 from home) shortens the push to 1/4",
		MS.Displace(rec(c, { Home = c - vec(58, 0, 0) }), "Push", c - vec(1, 0, 0), 5, nil))
	-- the zone edge (inset 6)
	local edgeX = zone.Center.X + zone.Size.X / 2 - 6
	local edge = rec(vec(edgeX - 2, 0, zone.Center.Z), { Home = vec(edgeX - 2, 0, zone.Center.Z) })
	check(math.abs(MS.Displace(edge, "Push", vec(edgeX - 3, 0, zone.Center.Z), 4, nil) - 2) < 1e-9,
		"2 studs from the zone edge: a push of 4 becomes 2", MS.Displace(edge, "Push", vec(edgeX - 3, 0, zone.Center.Z), 4, nil))
	-- water ahead: the steps stop before it
	W.WaterX = c.X + 2
	check(math.abs(MS.Displace(rec(c), "Pull", c + vec(20, 0, 0), 4, nil) - 2) < 1e-9, "water 2 studs ahead: only 2", "")
	W.WaterX = c.X + 0.5
	check(MS.Displace(rec(c), "Pull", c + vec(20, 0, 0), 4, nil) == 0, "water right ahead: no move", "")
	W.WaterX = nil
	W.Wall = true
	check(MS.Displace(rec(c), "Pull", c + vec(20, 0, 0), 4, nil) == 0, "a wall in the way: no move", "")
	W.Wall = false
	local dead = rec(c)
	dead.Alive = false
	check(MS.Displace(dead, "Pull", c + vec(20, 0, 0), 4, nil) == 0 and MS.Displace(rec(c), "Spin", c + vec(20, 0, 0), 4, nil) == 0
		and MS.Displace(rec(c), "Pull", c + vec(20, 0, 0), 0 / 0, nil) == 0 and MS.Displace(rec(c), "Pull", nil, 4, nil) == 0,
		"a dead monster, a bad mode, NaN studs or no caster: nothing", "")
	-- a monster outside its own zone (knocked out) is left to its walk home
	local out = rec(c + vec(zone.Size.X, 0, 0))
	check(MS.Displace(out, "Push", c, 3, nil) == 0, "a zone monster standing outside its zone: no move", "")
	-- ... also where another zone overlaps its rect (ZoneAt says it stands in that zone)
	local MS2 = {}
	local other = setmetatable({ ZoneAt = function() return { Id = "PumpkinPatch" } end }, { __index = cfg })
	execute("MonsterService.Displace2", chunk, env, other, w.Util, cfg.Monsters, MS2, 6,
		function(x, z) return vec(x, 0, z), false end, function() return {} end, function() end)
	check(MS2.Displace(rec(c), "Pull", c + vec(20, 0, 0), 4, nil) == 0, "inside its rect but in another zone (overlap): no move", "")
end)

------------------------------------------------------------------ A23-61 server aim for skills (검수 2026-10-07)
-- nothing inside the aim cone: the skill aims at the nearest monster within its reach in any direction and turns the
-- root to it when it goes off; such a cast hits monsters only (players keep the front-half rule)
runGroup("aim behind", function()
	local function turnedOf(p)
		local root = p.Character:FindFirstChild("HumanoidRootPart")
		local cf = root and root.CFrame
		return type(cf) == "table" and cf.Turned and cf.LookVector or nil -- the combat world's CFrame.lookAt double
	end
	-- Line: Earth Cleave toward a slime behind me
	local w = skillWorld({ Z = true })
	local p = w:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior" })
	local back = w:Monster("Slime", -12, 0, 99999)
	w:Use(p, "Z")
	local d = turnedOf(p)
	check(hitOf(w, back) > 0 and d and d.Z > 0.99, "Earth Cleave with only a slime behind: the band turns to it (root turned)",
		show({ hitOf(w, back), d and d.Z }))
	-- Chain: the first target behind me
	local m = skillWorld({ Z = true })
	local mage = m:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage" })
	local mb = m:Monster("Slime", -20, 0, 99999)
	m:Use(mage, "Z")
	check(m:Count("Z") == 1 and hitOf(m, mb) > 0 and turnedOf(mage) ~= nil, "Chain Bolt with only a slime behind: it starts there",
		show({ m:Count("Z"), hitOf(m, mb) }))
	-- Q (Meteor, a target circle): the blast goes to the slime behind
	local q = skillWorld({ Z = true })
	local mq = q:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage" })
	local qb = q:Monster("Slime", -25, 0, 99999)
	q:Use(mq, "Q")
	check(q:Count("Q") == 1 and hitOf(q, qb) > 0 and turnedOf(mq) ~= nil, "Meteor with only a slime behind: the blast lands on it",
		show({ q:Count("Q"), hitOf(q, qb) }))
	-- a target in the cone always wins: no turn
	local f = skillWorld({ Z = true })
	local pf = f:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage" })
	local front = f:Monster("Slime", 25, 0, 99999)
	local near = f:Monster("Slime", -5, 0, 99999)
	f:Use(pf, "Z")
	check(hitOf(f, front) > 0 and turnedOf(pf) == nil, "a slime in front and a nearer one behind: the chain starts in front, no turn",
		show({ hitOf(f, front), hitOf(f, near) }))
	-- players are never the reason to turn, and a turned cast skips them
	local v = skillWorld({ Z = true, Hit = true, PvP = true })
	local atk = v:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Halo" })
	local vic = v:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns", Pos = vec(0, 0, 8) })
	local slime = v:Monster("Slime", -10, 0, 99999)
	v:Use(atk, "Z")
	check(hitOf(v, slime) > 0 and vic.Character:FindFirstChild("Humanoid").Health == 100,
		"PvPZX on, an enemy and a slime behind: turned to the slime, the enemy is not hit",
		show({ hitOf(v, slime), vic.Character:FindFirstChild("Humanoid").Health }))
	local v2 = skillWorld({ Z = true, Hit = true, PvP = true })
	local atk2 = v2:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Faction = "Halo" })
	local vic2 = v2:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns", Pos = vec(0, 0, 20) })
	v2:Use(atk2, "Z")
	check(v2:Count("Z") == 0 and v2:Press(atk2) == "Z:NoTarget" and vic2.Character:FindFirstChild("Humanoid").Health == 100,
		"only an enemy behind: 'No target' (players never pull the aim)", v2:Press(atk2))
	-- auto: a slime behind is in reach for an auto Meteor / Chain Bolt
	local a = skillWorld({ Z = true })
	a:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	a:Monster("Slime", -20, 0, 99999)
	a:AutoTick()
	check(a:Count("Q") == 1, "auto Meteor at a slime behind me", a:Count("Q"))
	-- ... also when the swing's root turn did not take (auto Q looks all around, not at the cone)
	local a2 = skillWorld({ Z = true })
	a2.TurnFails = true
	a2:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	local s2 = a2:Monster("Slime", -20, 0, 99999)
	a2:AutoTick()
	check(a2:Count("Q") == 1 and hitOf(a2, s2) > 0, "auto Meteor at a slime behind me even when the root cannot turn",
		show({ a2:Count("Q"), hitOf(a2, s2) }))
	-- a Meteor turned to a slime behind never hits the enemy standing next to it (players keep the front rule)
	local qp = skillWorld({ Z = true, Hit = true })
	local qm = qp:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Mage", Faction = "Halo" })
	local qs = qp:Monster("Slime", -20, 0, 99999)
	local qv = qp:Hero(2, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Faction = "Horns", Pos = vec(2, 0, 20) })
	qp:Use(qm, "Q")
	check(hitOf(qp, qs) > 0 and qv.Character:FindFirstChild("Humanoid").Health == 100,
		"a Meteor turned to a slime behind: the enemy next to it is not hit", show({ hitOf(qp, qs), qv.Character:FindFirstChild("Humanoid").Health }))
	-- an auto rule that says no never turns me (the turn comes with the cast)
	local n = skillWorld({ Z = true })
	local np = n:Hero(1, { Level = 5, Tier = 1, Mask = 1, Class = "Warrior", Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	n:Monster("Slime", -12, 0, 99999)
	n.Skills.Cast(np, "Z", true) -- one small slime: Earth Cleave's auto rule (2 or a big one) says no
	check(n:Count("Z") == 0 and turnedOf(np) == nil, "an auto Z that does not go off does not turn me", n:Count("Z"))
end)

finish()
