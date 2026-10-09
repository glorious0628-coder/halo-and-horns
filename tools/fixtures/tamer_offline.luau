-- A23-39 pet tamer (server side), run offline. tools/test_tamer.py injects the tools/test_unarmed_start.py bindings
-- plus PET_SOURCE (whole PetService) before tools/fixtures/dev2_kit.luau; the world (bareWorld with PetService,
-- notices, indexOf, C0) is tools/fixtures/dev2_combat_world.luau.

local function petCount(d)
	local n = 0
	for _ in (d.Pets and d.Pets.List) or {} do n += 1 end
	return n
end

local function babySlimes(d)
	local list = {}
	for uid, p in (d.Pets and d.Pets.List) or {} do
		if p.Sp == "BabySlime" then table.insert(list, uid) end
	end
	return list
end

------------------------------------------------------------------ 1. Config: names, weapons, the attack profile
runGroup("config", function()
	local C = C0
	check(C.ClassName("Archer", "Neutral") == "Pet Tamer" and C.ClassName("Archer", "Halo") == "Ranger"
		and C.ClassName("Archer", "Horns") == "Shadow Hunter", "the artisan Archer is the Pet Tamer (Halo / Horns keep theirs)",
		C.ClassName("Archer", "Neutral"))
	check(C.IsTamer("Archer", "Neutral") and not C.IsTamer("Archer", "Halo") and not C.IsTamer("Archer", "None")
		and not C.IsTamer("Warrior", "Neutral") and not C.IsTamer("Mage", "Neutral") and not C.IsTamer(nil, nil),
		"IsTamer = the Neutral Archer only")
	local want = { "Twig Baton", "Wooden Baton", "Iron Baton", "Goblin Thief's Golden Baton", "Old Kingdom Crystal Baton",
		"Guardian Spirit Baton", "Crown Shard Baton", "Jelly Crown Baton" }
	for tier, name in want do
		check(C.WeaponName(tier, "Archer", "Neutral") == name, "tamer weapon " .. tier .. " = " .. name, C.WeaponName(tier, "Archer", "Neutral"))
	end
	check(C.WeaponName(1, "Archer", "Halo") == "Slingshot Bow" and C.WeaponName(0, "Archer", "Neutral") == C.Text.BareHands,
		"Halo Archer keeps the bows; bare hands stay 'Bare hands'")
	check(#C.WeaponNames.Tamer == C.MaxWeaponTier and #C.WeaponNamesEn.Tamer == C.MaxWeaponTier, "baton names KO + EN for every tier")
	for tier = 1, 6 do
		check(C.WeaponArtKey(tier, "Archer", "Neutral") == "Weapon_Tamer_T" .. tier, "baton icon key T" .. tier)
	end
	check(C.WeaponArtKey(7, "Archer", "Neutral") == "Weapon_Archer_T7_Neutral" and C.WeaponArtKey(8, "Archer", "Neutral") == "Weapon_Archer_T8"
		and C.WeaponArtKey(1, "Archer", "Halo") == "Weapon_Archer_T1" and C.WeaponArtKey(0, "Archer", "Neutral") == nil,
		"T7 / T8 keep the Archer keys, Halo keeps bows, bare hands no icon")
	local a, r = C.AttackProfile("Archer", 1, "Neutral"), C.Classes.Archer
	local same = true
	for _, k in { "Pattern", "Range", "SwingInterval", "AimCone", "Targets", "Splash", "Damage", "Ranged", "PvPMult", "Id" } do
		if a[k] ~= r[k] then same = false end
	end
	check(same and a.Style == "PetHeadbutt" and r.Style == nil, "armed tamer = the Archer numbers + Style PetHeadbutt (class row untouched)",
		show({ a.Style, a.Range, a.Targets }))
	check(C.AttackProfile("Archer", 8, "Neutral") == a, "the tamer profile is cached")
	local b = C.AttackProfile("Archer", 0, "Neutral")
	check(b.Style == "PetHeadbutt" and b.Unarmed == true and b.Range == 7 and b.Targets == 1 and b.Damage == 1 and b.SwingInterval == 0.8,
		"bare tamer = the punch numbers + the pet look", show(b))
	check(C.AttackProfile("Archer", 0, "Halo").Style == "Punch" and C.AttackProfile("Archer", 1, "Halo") == r,
		"a Halo archer: punch bare-handed, the class row armed")
	local card = C.ClassCard("Archer", "Neutral")
	check(card == C.Tamer.Card and has(card.Desc, "pet") and C.ClassCard("Archer", "Halo").Desc == r.Desc,
		"class card: the tamer's lines, the archer's for Halo")
	local function pair(t, key)
		local _, na = string.gsub(t[key] or "", "%%[sd]", "")
		local _, nb = string.gsub(t[key .. "En"] or "", "%%[sd]", "")
		return type(t[key]) == "string" and t[key] ~= "" and type(t[key .. "En"]) == "string" and t[key .. "En"] ~= "" and na == nb
	end
	for _, key in { "PetName", "PetGot", "Became", "BecameFree" } do check(pair(C.Tamer.Text, key), "text " .. key .. " KO + EN") end
	for _, key in { "Desc", "PickLine" } do check(pair(C.Tamer.Card, key), "card " .. key .. " KO + EN") end
	check(#C.Tamer.Card.Stats == #C.Tamer.Card.StatsEn and #C.Tamer.Card.Stats == #r.Stats, "card stats KO + EN lines")
	local D = C.Data.Defaults
	check(type(D.Pets) == "table" and next(D.Pets.List) == nil and next(D.Pets.Equipped) == nil and D.Pets.Next == 1
		and D.TamerNotice == false and C.Data.Version == 3, "save defaults: no pet, TamerNotice false, Version 3")
end)

------------------------------------------------------------------ 2. combat: the Archer numbers with the pet look
runGroup("combat", function()
	local function swingOnce(faction, tier, userId)
		local w = bareWorld()
		local p = w:Join(userId, { Class = "Archer", Faction = faction, Tier = tier,
			Mask = tier > 0 and bit32.lshift(1, tier - 1) or 0 })
		local m1, m2 = w:Monster("BigSlime", 12), w:Monster("BigSlime", 20, 2)
		local fx0 = #w.Fx
		w.Combat.Swing(p, true)
		w:Flush()
		return w, p, m1, m2, w:FxOf("Swing", fx0)[1]
	end
	local wt, _, t1, t2, ft = swingOnce("Neutral", 1, 101)
	local wh, _, h1, h2, fh = swingOnce("Halo", 1, 102)
	check(wt:Dealt(t1) > 0 and wt:Dealt(t1) == wh:Dealt(h1) and wt:Dealt(t2) == wh:Dealt(h2),
		"tamer swing = Halo archer swing (two targets at 30, same damage)", show({ wt:Dealt(t1), wh:Dealt(h1), wt:Dealt(t2), wh:Dealt(h2) }))
	local d = ft and ft.Data or {}
	check(d.Style == "PetHeadbutt" and d.Class == "Archer" and d.ContactDelay == 0.3 and d.LaunchDelay == nil
		and d.FlightTime == nil and #(d.Targets or {}) == 2, "tamer Fx Swing: Style PetHeadbutt, contact 0.3, no arrow",
		show({ d.Style, d.Class, d.ContactDelay, d.LaunchDelay, d.FlightTime }))
	check(fh and fh.Data.Style == nil and fh.Data.LaunchDelay ~= nil, "a Halo archer still shoots arrows")
	wt:Advance(0.29)
	check(#wt.Shoves == 0, "no shove before the pet arrives")
	wt:Advance(0.02)
	check(#wt.Shoves == 2, "the pet's headbutt shoves both targets at 0.3 s", #wt.Shoves)
	-- skill Q: the Archer skill, the pet dash look
	local function skillOnce(faction, userId)
		local w = bareWorld()
		local p = w:Join(userId, { Class = "Archer", Faction = faction, Tier = 1, Mask = 1 })
		local m = w:Monster("BigSlime", 20)
		local fx0 = #w.Fx
		w.Combat.Release(p, false)
		w:Flush()
		return w, m, w:FxOf("Release", fx0)[1]
	end
	local wq, mq, fq = skillOnce("Neutral", 103)
	local wr, mr, fr = skillOnce("Halo", 104)
	check(wq:Dealt(mq) > 0 and wq:Dealt(mq) == wr:Dealt(mr), "tamer skill Q = Halo archer skill Q", show({ wq:Dealt(mq), wr:Dealt(mr) }))
	local q = fq and fq.Data or {}
	check(q.Style == "PetDash" and q.Class == "Archer" and q.ContactDelay == 0.35 and q.LaunchDelay == nil,
		"tamer Fx Release: Style PetDash, contact 0.35, no arrow rain", show({ q.Style, q.ContactDelay, q.LaunchDelay }))
	check(fr and fr.Data.Style == nil and fr.Data.LaunchDelay ~= nil, "a Halo archer's skill keeps its look")
	wq:Advance(0.34)
	check(#wq.Shoves == 0, "no skill shove before the dash lands")
	wq:Advance(0.02)
	check(#wq.Shoves == 1, "the dash shoves at 0.35 s", #wq.Shoves)
	-- bare-handed tamer: the punch rules with the pet look
	local wb, pb, b1, b2 = swingOnce("Neutral", 0, 105)
	local fb = wb:FxOf("Swing", 0)
	local last = fb[#fb] and fb[#fb].Data or {}
	check(wb:Dealt(b1) == 0 and wb:Dealt(b2) == 0 and last.Style == "PetHeadbutt", "bare tamer: nothing within 7, pet look",
		show({ wb:Dealt(b1), last.Style }))
	local close = wb:Monster("Slime", 4)
	wb:Advance(1)
	wb.Combat.Swing(pb, true)
	wb:Flush()
	check(wb:Dealt(close) == 2, "bare tamer punches for 2 at 4 studs", wb:Dealt(close))
	-- auto combat: the Archer reach when armed
	local wa = bareWorld()
	local pa = wa:Join(106, { Class = "Archer", Faction = "Neutral", Tier = 1, Mask = 1,
		Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true, Mana = 0 } })
	local far = wa:Monster("BigSlime", 20)
	wa:AutoTick()
	check(wa:Dealt(far) > 0, "auto: the armed tamer's pet reaches 20 studs (Archer range)", wa:Dealt(far))
	check(pa ~= nil, "joined")
end)

------------------------------------------------------------------ 3. the pet: once, for tamers only
runGroup("pet", function()
	-- picking the tamer (Neutral, class not chosen yet -> Archer)
	local w = bareWorld()
	local p, d = w:Join(201, { Faction = "Neutral", Data = { ClassChosen = false, Class = "Warrior" } })
	check(petCount(d) == 0 and p:GetAttribute("EquippedPet") == "" and p:GetAttribute("PetLv") == 0, "no pet before the pick")
	local n0 = #w.Notices
	w.PS.SetStat(p, "Class", "Archer")
	w.PS.SetStat(p, "ClassChosen", true)
	w.Registry.ClassService.ClassChanged:Fire(p, "Archer", "Warrior")
	local slimes = babySlimes(d)
	local uid = slimes[1]
	local pet = uid and d.Pets.List[uid] or {}
	check(#slimes == 1 and pet.Lv == 1 and pet.XP == 0 and pet.Bound == true and d.Pets.Equipped[1] == uid,
		"the pick gives one baby slime, equipped, Bound, Lv1", show(d.Pets))
	check(p:GetAttribute("EquippedPet") == "BabySlime" and p:GetAttribute("PetLv") == 1 and p:GetAttribute("PetForm") == "",
		"attributes EquippedPet / PetLv / PetForm", show({ p:GetAttribute("EquippedPet"), p:GetAttribute("PetLv") }))
	w:Advance(1) -- PET-2b L3: the pet line comes Config.Pets.NoticeAfter later
	check(indexOf(notices(w, p, n0), C0.Tamer.Text.PetGot) ~= nil, "the pet notice")
	check(d.TamerNotice == true and #w.Tickets == 0, "a tamer picked now: the flag is set, no free-change ticket")
	-- the same signal again: no second pet, no second notice
	local n1 = #w.Notices
	w.Registry.ClassService.ClassChanged:Fire(p, "Archer", "Archer")
	w:Advance(1)
	check(#babySlimes(d) == 1 and #notices(w, p, n1) == 0, "no second pet / notice")
	-- leaving the tamer keeps the pet; coming back adds nothing
	w.PS.SetStat(p, "Class", "Warrior")
	w.Registry.ClassService.ClassChanged:Fire(p, "Warrior", "Archer")
	check(#babySlimes(d) == 1 and d.Pets.Equipped[1] == uid, "a class change away keeps the pet")
	w.PS.SetStat(p, "Class", "Archer")
	w.Registry.ClassService.ClassChanged:Fire(p, "Archer", "Warrior")
	check(#babySlimes(d) == 1, "coming back: still one pet")
	-- put away (a save from before the tamer, PET-2b): being a tamer brings the one it owns out, never a second one
	d.Pets.Equipped, d.Pets.Away = {}, true
	w.Registry.ClassService.ClassChanged:Fire(p, "Archer", "Archer")
	check(#babySlimes(d) == 1 and d.Pets.Equipped[1] == uid and p:GetAttribute("EquippedPet") == "BabySlime"
		and d.Pets.Away == false, "an owned, put-away baby slime comes out for the tamer (no duplicate)", show(d.Pets))
	-- a faction change into the guild as an Archer
	local w2 = bareWorld()
	local q, e = w2:Join(202, { Class = "Archer", Faction = "Halo" })
	check(petCount(e) == 0, "a Halo archer has no pet")
	w2.PS.SetStat(q, "Faction", "Neutral")
	w2.Registry.FactionService.FactionChanged:Fire(q, "Neutral", "Halo", "Altar")
	check(#babySlimes(e) == 1 and e.TamerNotice == true and #w2.Tickets == 0, "joining the guild as an Archer: the pet, no ticket")
	-- never for the others
	for _, row in { { "Archer", "Halo" }, { "Archer", "Horns" }, { "Warrior", "Neutral" }, { "Mage", "Neutral" } } do
		local w3 = bareWorld()
		local r, f = w3:Join(203, { Class = row[1], Faction = row[2] })
		w3.Registry.ClassService.ClassChanged:Fire(r, row[1], row[1])
		w3.Registry.FactionService.FactionChanged:Fire(r, row[2], row[2], "Altar")
		check(petCount(f) == 0 and r:GetAttribute("EquippedPet") == "", "no pet for a " .. row[2] .. " " .. row[1])
	end
	-- a player who is not ready yet gets nothing from a signal
	local w4 = bareWorld()
	local s, g = w4:Join(204, { Faction = "Neutral", Data = { ClassChosen = false, Class = "Warrior" } })
	w4.Ready[s] = false
	g.Class, g.ClassChosen = "Archer", true
	w4.Registry.ClassService.ClassChanged:Fire(s, "Archer", "Warrior")
	check(petCount(g) == 0, "not ready: no pet")
end)

------------------------------------------------------------------ PET-4: the lost baby slime for everyone (게임성 개발 2)
runGroup("lost baby slime", function()
	local G = C0.PetGrant
	local def = C0.StoryQuests.Defs[G.Quest]
	check(def and def.Requires.Done[1] == "M1_1" and table.find(C0.StoryQuests.Subs, G.Quest) ~= nil,
		"a sub quest after M1_1", G.Quest)
	local kill, pick = def.Steps[1].Obj, def.Steps[2].Obj
	check(kill.Type == "Kill" and kill.Kind == "Slime" and kill.Zone == "SlimeMeadow" and kill.Count == 8, "8 meadow slimes first")
	check(pick.Type == "Choice" and pick.Good.Label == "Take care of it" and pick.Evil.Label == "Make it my minion"
		and pick.Good.Points == 1 and pick.Evil.Points == 1 and G.Picks[pick.Good.Pick] == "Good" and G.Picks[pick.Evil.Pick] == "Evil"
		and G.Picks.A == "Good" and G.Picks.B == "Evil", "the pick: care (Good) / minion (Evil), 1 point, Neutral A / B")
	check(G.Species == C0.Tamer.Pet and C0.PetSpeedBonus(G.Species, 1) > 0, "the same baby slime, its walk bonus kept (A23-86 decision 4)")
	-- a Halo warrior picks Care: a Good Buddy, equipped, the friendly line (not the tamer's)
	local w = bareWorld()
	local p, d = w:Join(301, { Faction = "Halo", Class = "Warrior" })
	local n0 = #w.Notices
	w.Story.Picked:Fire(p, G.Quest, "Care")
	local slimes = babySlimes(d)
	local pet = slimes[1] and d.Pets.List[slimes[1]] or {}
	check(#slimes == 1 and pet.Lean == "Good" and pet.Name == G.Names.Good and d.Pets.Equipped[1] == slimes[1]
		and p:GetAttribute("EquippedPet") == "BabySlime", "Care: a Good Buddy baby slime, equipped", show(pet))
	-- PET-2b L3: not in the pick's frame (the quest's own lines go first; an open window shows one toast at a time)
	check(indexOf(notices(w, p, n0), G.Text.Got) == nil, "the pet line waits a moment after the pick", show(notices(w, p, n0)))
	w:Advance(C0.Pets.NoticeAfter - 0.01)
	check(indexOf(notices(w, p, n0), G.Text.Got) == nil, "... Config.Pets.NoticeAfter seconds")
	w:Advance(0.02)
	local lines = notices(w, p, n0)
	check(lines[#lines] == G.Text.Got, "then it is the newest line", show(lines))
	check(indexOf(lines, G.Text.Got) ~= nil and indexOf(lines, C0.Tamer.Text.PetGot) == nil, "the pet line for everyone (not 'fights for you')")
	-- the same pick again: nothing more
	local n1 = #w.Notices
	w.Story.Picked:Fire(p, G.Quest, "Care")
	w:Advance(1)
	check(#babySlimes(d) == 1 and #notices(w, p, n1) == 0, "no second pet / line")
	-- a player who leaves before the line: nothing is sent to them
	local wl = bareWorld()
	local pl = wl:Join(306, { Faction = "Halo", Class = "Warrior" })
	local nl = #wl.Notices
	wl.Story.Picked:Fire(pl, G.Quest, "Care")
	wl:Remove(pl)
	wl:Advance(1)
	check(#notices(wl, pl, nl) == 0, "left before the line: no notice")
	-- a Horns pick Minion: a Little Minion; a Neutral's B the same
	local w2 = bareWorld()
	local q, e = w2:Join(302, { Faction = "Horns", Class = "Mage" })
	w2.Story.Picked:Fire(q, G.Quest, "Minion")
	local qp = e.Pets.List[babySlimes(e)[1] or ""] or {}
	check(qp.Lean == "Evil" and qp.Name == G.Names.Evil, "Minion: a Little Minion", show(qp))
	local w3 = bareWorld()
	local r, f = w3:Join(303, { Faction = "Neutral", Class = "Warrior" })
	w3.Story.Picked:Fire(r, G.Quest, "B")
	local rp = f.Pets.List[babySlimes(f)[1] or ""] or {}
	check(rp.Lean == "Evil", "a Neutral's B: Evil lean", show(rp))
	-- another quest's pick, an unknown pick: nothing
	local w4 = bareWorld()
	local s, g = w4:Join(304, { Faction = "Halo", Class = "Warrior" })
	w4.Story.Picked:Fire(s, "Lunch1", "Care") -- a pick name the pet quest uses, on another quest
	w4.Story.Picked:Fire(s, G.Quest, "Nope")
	check(petCount(g) == 0, "other quests / unknown picks give no pet")
	-- a tamer who already has the baby slime: no duplicate, it takes the lean and the name
	local w5 = bareWorld()
	local t, h = w5:Join(305, { Faction = "Neutral", Data = { ClassChosen = false, Class = "Warrior" } })
	w5.PS.SetStat(t, "Class", "Archer")
	w5.PS.SetStat(t, "ClassChosen", true)
	w5.Registry.ClassService.ClassChanged:Fire(t, "Archer", "Warrior")
	w5.Story.Picked:Fire(t, G.Quest, "A")
	local tp = h.Pets.List[babySlimes(h)[1] or ""] or {}
	check(#babySlimes(h) == 1 and tp.Lean == "Good" and tp.Name == G.Names.Good, "a tamer's own baby slime takes the lean / name", show(tp))
end)

------------------------------------------------------------------ PET-2: pet XP, EquipPet, the owner's list, catch-up
runGroup("pet levels and equip", function()
	local P = C0.Pets
	check(P.XPPerKill == 1 and P.XPPerLv == 15 and P.MaxLv == 10, "1 pet XP a kill, Lv n -> n+1 needs 15 x n, max Lv10")
	check(P.NoticeAfter == 0.5 and P.ListEvery == 1, "PET-2b: a pet line 0.5 s after (StoryQuestService replies at 0.35 s), "
		.. "XP-only lists at most once a second", show({ P.NoticeAfter, P.ListEvery }))
	local w = bareWorld()
	local p, d = w:Join(401, { Faction = "Halo", Class = "Warrior" })
	w.Story.Picked:Fire(p, C0.PetGrant.Quest, "Care")
	local uid = babySlimes(d)[1]
	local function petOf() return d.Pets.List[uid] end
	local pet = petOf()
	local function kill(n)
		for _ = 1, n do w.Registry.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime" }) end
	end
	local function lists(from)
		local out = {}
		for i = (from or 0) + 1, #w.Fired do
			local f = w.Fired[i]
			if f.Remote == "PetList" and f.Player == p then table.insert(out, f.Payload) end
		end
		return out
	end
	kill(14)
	check(pet.Lv == 1 and pet.XP == 14, "14 kills: Lv1, 14 / 15", show(pet))
	local speed0 = C0.PetSpeedBonus("BabySlime", 1)
	kill(1)
	check(pet.Lv == 2 and pet.XP == 0 and p:GetAttribute("PetLv") == 2, "the 15th kill: Lv2 (PetLv attribute)", show(pet))
	check(C0.PetSpeedBonus("BabySlime", 2) > speed0, "a higher level walks a bit faster (+7% -> +10% by Lv10)")
	local f0 = #w.Fired
	kill(29)
	check(pet.Lv == 2 and pet.XP == 29, "Lv2 needs 30", show(pet))
	-- the owner's list (s->c PetList). PET-2b L4: XP-only kills right after a list (the level up's) send none at once,
	-- then one with the newest numbers Config.Pets.ListEvery later
	check(#lists(f0) == 0, "XP-only kills right after a list: none at once", #lists(f0))
	w:Advance(C0.Pets.ListEvery)
	check(#lists(f0) == 1, "... then one list", #lists(f0))
	local last = lists(f0)[1]
	check(last and last.Equipped == uid and #last.List == 1 and last.List[1].Lv == 2 and last.List[1].XP == 29
		and last.List[1].Need == 30 and last.List[1].Name == "Good Buddy" and last.List[1].Lean == "Good",
		"PetList to the owner: Equipped, Lv / XP / Need / Name / Lean", show(last and last.List[1]))
	check(last and last.CanPutAway == true, "a non-tamer may put the pet away (PetList CanPutAway)")
	pet.XP = 0
	w:Advance(5)
	local f1 = #w.Fired
	kill(1)
	check(#lists(f1) == 1 and lists(f1)[1].List[1].XP == 1, "an XP-only kill long after the last list: sent at once",
		#lists(f1))
	kill(1)
	check(#lists(f1) == 1, "the next one within ListEvery waits", #lists(f1))
	w:Advance(C0.Pets.ListEvery)
	local l1 = lists(f1)
	check(#l1 == 2 and l1[2].List[1].XP == 2, "... and comes ListEvery later with the newest XP", #l1)
	-- PET-2b L1: a free rider's share (info.Minor) is not a paid kill: no pet XP
	w.Registry.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime", Minor = true })
	check(pet.XP == 2, "a free rider's kill (Minor) gives no pet XP", pet.XP)
	-- max level: no more XP
	pet.Lv, pet.XP = 10, 0
	kill(5)
	check(pet.Lv == 10 and pet.XP == 0, "Lv10 is the top")
	-- EquipPet: "" puts it away, the uid brings it back; others ignored
	local equip = w.Net.Get("EquipPet").OnServerEvent
	w:Advance(1)
	equip:Fire(p, "")
	check(#d.Pets.Equipped == 0 and p:GetAttribute("EquippedPet") == "", "EquipPet \"\": put away")
	petOf().Lv, petOf().XP = 1, 0
	kill(3)
	check(petOf().XP == 0, "a put-away pet gets no XP")
	w:Advance(1)
	equip:Fire(p, uid)
	check(d.Pets.Equipped[1] == uid and p:GetAttribute("EquippedPet") == "BabySlime", "EquipPet uid: it follows again")
	w:Advance(1)
	equip:Fire(p, "P999")
	w:Advance(1)
	equip:Fire(p, 5)
	w:Advance(1)
	equip:Fire(p, "", "extra")
	check(d.Pets.Equipped[1] == uid, "an unknown uid / a number / extra arguments: ignored")
	w:Advance(1)
	equip:Fire(p, uid)
	equip:Fire(p, "")
	check(d.Pets.Equipped[1] == uid, "too fast (rate limit): ignored")
	-- catch-up: the quest is done with a pick but the pet is missing (an old save, a crash)
	local w2 = bareWorld()
	local q, e = w2:Join(402, { Faction = "Horns", Class = "Mage",
		Data = { Story = { Done = { [C0.PetGrant.Quest] = true }, Pick = { [C0.PetGrant.Quest] = "Minion" } } } })
	local qp = e.Pets.List[babySlimes(e)[1] or ""] or {}
	check(#babySlimes(e) == 1 and qp.Lean == "Evil" and qp.Name == "Little Minion", "catch-up: the pet from the saved pick", show(qp))
	local w3 = bareWorld()
	local r, f = w3:Join(403, { Faction = "Halo", Class = "Mage",
		Data = { Story = { Done = {}, Pick = { [C0.PetGrant.Quest] = "Care" } } } })
	check(petCount(f) == 0, "no catch-up without the quest done")
end)

------------------------------------------------------------------ PET-2b: a put-away pet stays away; the tamer never puts away
local function lastList(w, p, from)
	local last = nil
	for i = (from or 0) + 1, #w.Fired do
		local f = w.Fired[i]
		if f.Remote == "PetList" and f.Player == p then last = f.Payload end
	end
	return last
end

runGroup("put away", function()
	local G = C0.PetGrant
	-- a Halo warrior with the lost baby slime puts it away
	local w = bareWorld()
	local p, d = w:Join(601, { Faction = "Halo", Class = "Warrior" })
	w.Story.Picked:Fire(p, G.Quest, "Care")
	-- the quest done with its pick, as the story service saves it (the catch-up's condition is true from now on)
	d.Story = { Done = { [G.Quest] = true }, Pick = { [G.Quest] = "Care" } }
	local uid = babySlimes(d)[1]
	local equip = w.Net.Get("EquipPet").OnServerEvent
	w:Advance(1)
	equip:Fire(p, "")
	check(#d.Pets.Equipped == 0 and d.Pets.Away == true and p:GetAttribute("EquippedPet") == "", "put away: saved as Away",
		show(d.Pets))
	-- the same session: the story pick again, a class change -> still away
	w.Story.Picked:Fire(p, G.Quest, "Care")
	w.PS.SetStat(p, "Class", "Mage")
	w.Registry.ClassService.ClassChanged:Fire(p, "Mage", "Warrior")
	check(#d.Pets.Equipped == 0 and d.Pets.Away == true and #babySlimes(d) == 1, "a pick / class change in the session: still away",
		show(d.Pets))
	-- M1: a rejoin with that save keeps it away (no line, no second pet)
	local w2 = bareWorld()
	local q, e = w2:Join(601, { Saved = jsonDecode(jsonEncode(d)) })
	w2:Advance(1)
	check(#e.Pets.Equipped == 0 and e.Pets.Away == true and q:GetAttribute("EquippedPet") == "" and q:GetAttribute("PetLv") == 0
		and #babySlimes(e) == 1 and #notices(w2, q, 0) == 0, "a rejoin: the put-away pet stays away", show(e.Pets))
	local l = lastList(w2, q)
	check(l and l.Equipped == "" and #l.List == 1 and l.CanPutAway == true, "its PetList: nothing out, the pet listed", show(l))
	w2.Registry.MonsterService.MonsterKilled:Fire(q, { Kind = "Slime" })
	check(e.Pets.List[uid].XP == 0, "away: no pet XP")
	-- bring it back: it follows, Away cleared, the walk bonus and the pet XP come back
	local equip2 = w2.Net.Get("EquipPet").OnServerEvent
	w2:Advance(1)
	equip2:Fire(q, uid)
	check(e.Pets.Equipped[1] == uid and e.Pets.Away == false and q:GetAttribute("EquippedPet") == "BabySlime"
		and q:GetAttribute("PetLv") == 1, "EquipPet uid: out again, Away cleared", show(e.Pets))
	check(C0.WalkSpeed("Mage", q:GetAttribute("EquippedPet"), q:GetAttribute("PetLv")) > C0.WalkSpeed("Mage", "", 0),
		"... the walk bonus is back")
	w2.Registry.MonsterService.MonsterKilled:Fire(q, { Kind = "Slime" })
	check(e.Pets.List[uid].XP == 1, "... and the pet XP", e.Pets.List[uid].XP)
	local w3 = bareWorld()
	local r, f = w3:Join(601, { Saved = jsonDecode(jsonEncode(e)) })
	check(f.Pets.Equipped[1] == uid and f.Pets.Away == false and r:GetAttribute("EquippedPet") == "BabySlime",
		"a rejoin with it out: out")

	-- the tamer (검수 2026-10-09: its pet is its weapon): EquipPet "" ignored, PetList CanPutAway = false
	local wt = bareWorld()
	local t, h = wt:Join(602, { Faction = "Neutral", Class = "Archer" })
	local tuid = babySlimes(h)[1]
	local tequip = wt.Net.Get("EquipPet").OnServerEvent
	wt:Advance(1)
	tequip:Fire(t, "")
	check(h.Pets.Equipped[1] == tuid and h.Pets.Away == false and t:GetAttribute("EquippedPet") == "BabySlime",
		"the tamer: EquipPet \"\" is ignored", show(h.Pets))
	local tl = lastList(wt, t)
	check(tl and tl.CanPutAway == false and tl.Equipped == tuid, "the tamer's PetList: CanPutAway false", show(tl))
	-- leaving the tamer: the list says it may be put away now, and it can
	local nf = #wt.Fired
	wt.PS.SetStat(t, "Class", "Warrior")
	wt.Registry.ClassService.ClassChanged:Fire(t, "Warrior", "Archer")
	local after = lastList(wt, t, nf)
	check(after and after.CanPutAway == true, "a class change away from the tamer: PetList CanPutAway true", show(after))
	wt:Advance(1)
	tequip:Fire(t, "")
	check(#h.Pets.Equipped == 0 and h.Pets.Away == true, "... and the pet can be put away", show(h.Pets))
	-- becoming the tamer again brings it out
	nf = #wt.Fired
	wt.PS.SetStat(t, "Class", "Archer")
	wt.Registry.ClassService.ClassChanged:Fire(t, "Archer", "Warrior")
	after = lastList(wt, t, nf)
	check(h.Pets.Equipped[1] == tuid and h.Pets.Away == false and t:GetAttribute("EquippedPet") == "BabySlime"
		and after and after.CanPutAway == false, "the tamer again: the pet comes out, CanPutAway false", show(h.Pets))
	-- a put-away save that joins as the tamer: out
	local saved = jsonDecode(jsonEncode(h))
	saved.Pets.Equipped, saved.Pets.Away = {}, true
	local wj = bareWorld()
	local j, k = wj:Join(602, { Saved = saved })
	check(k.Pets.Equipped[1] == tuid and k.Pets.Away == false and j:GetAttribute("EquippedPet") == "BabySlime",
		"a put-away save joining as the tamer: out", show(k.Pets))

	-- the catch-up leaves an owned baby slime as it is (no lean / name from the saved pick)
	local wc = bareWorld()
	local own = deepCopy(C0.Data.Defaults)
	own.Faction, own.Class, own.ClassChosen, own.TamerNotice = "Horns", "Mage", true, true
	own.Story = { Done = { [G.Quest] = true }, Pick = { [G.Quest] = "Minion" } }
	own.Pets = { List = { P1 = { Sp = "BabySlime", Lv = 3, XP = 4, Name = "", Lean = "", Bound = true } }, Equipped = { "P1" },
		Next = 2 }
	local _, cd = wc:Join(603, { Saved = own })
	check(#babySlimes(cd) == 1 and cd.Pets.List.P1.Lean == "" and cd.Pets.List.P1.Lv == 3,
		"the catch-up skips an owned baby slime", show(cd.Pets))
end)

------------------------------------------------------------------ 4. saves from before A23-39: the notice + one free change
runGroup("legacy", function()
	local w = bareWorld()
	-- a save from before A23-39, loaded the way DataService does (migrate + fillDefaults): TamerNotice arrives false
	local migrate, fill = execute("DataService.extract", DATA_EXTRACT, w:Env(), w.Config, w.Util)
	local function load(rec)
		migrate(rec, { Name = "P" })
		fill(rec, "P")
		return rec
	end
	local saved = { Version = 3, Faction = "Neutral", Class = "Archer", ClassChosen = true, Level = 7, TutorialStep = 99,
		WeaponTier = 1, WeaponOwnedMask = 1 }
	load(saved)
	check(saved.TamerNotice == false and type(saved.Pets) == "table", "a pre-A23-39 save loads with TamerNotice false + empty Pets")
	local p, d = w:Join(301, { Saved = saved })
	w:Advance(1)
	local list = notices(w, p, 0)
	local iBecame, iPet = indexOf(list, C0.Tamer.Text.Became), indexOf(list, C0.Tamer.Text.PetGot)
	check(iBecame ~= nil and iPet ~= nil and iBecame < iPet, "the hunter-became-tamer notice, then the pet notice", show(list))
	check(#w.Tickets == 1 and w.Tickets[1].P == p and w.Tickets[1].Kind == "Class" and w.Tickets[1].N == 1,
		"one free class change ticket", show({ #w.Tickets, w.Tickets[1] and w.Tickets[1].Kind, w.Tickets[1] and w.Tickets[1].N }))
	check(d.TamerNotice == true and #babySlimes(d) == 1, "flag saved, the pet given")
	-- the next join with that save: nothing again
	local w2 = bareWorld()
	local q, e = w2:Join(301, { Saved = jsonDecode(jsonEncode(d)) })
	w2:Advance(1)
	check(#w2.Tickets == 0 and #notices(w2, q, 0) == 0 and #babySlimes(e) == 1, "the next join: no ticket, no notice, still one pet",
		show({ #w2.Tickets, notices(w2, q, 0) }))
	check(q:GetAttribute("EquippedPet") == "BabySlime" and q:GetAttribute("PetLv") == 1,
		"the next join: the pet attributes are published again (the pet follows every session)",
		show({ q:GetAttribute("EquippedPet"), q:GetAttribute("PetLv") }))
	-- an old hunter below Lv5: the free change keeps the level anyway, so the line says 'free' (no ticket button there)
	local w7 = bareWorld()
	local low = load({ Version = 3, Faction = "Neutral", Class = "Archer", ClassChosen = true, Level = 3, TutorialStep = 99 })
	local lp = w7:Join(305, { Saved = low })
	w7:Advance(1)
	check(indexOf(notices(w7, lp, 0), C0.Tamer.Text.BecameFree) ~= nil and indexOf(notices(w7, lp, 0), C0.Tamer.Text.Became) == nil
		and #w7.Tickets == 1, "Lv3 old hunter: the 'free change' line, still one ticket", show(notices(w7, lp, 0)))
	-- a raw save without the field at all (nil) is the same old hunter
	local w8 = bareWorld()
	local raw = deepCopy(C0.Data.Defaults)
	raw.Faction, raw.Class, raw.ClassChosen, raw.Level, raw.TamerNotice = "Neutral", "Archer", true, 8, nil
	w8:Join(306, { Saved = raw })
	check(#w8.Tickets == 1, "a save with no TamerNotice field at all: the ticket too")
	-- a tamer made during a session (flag set then) rejoins: no ticket
	local w3 = bareWorld()
	local r, f = w3:Join(302, { Faction = "Neutral", Data = { ClassChosen = false, Class = "Warrior" } })
	w3.PS.SetStat(r, "Class", "Archer")
	w3.PS.SetStat(r, "ClassChosen", true)
	w3.Registry.ClassService.ClassChanged:Fire(r, "Archer", "Warrior")
	local w4 = bareWorld()
	local s = w4:Join(302, { Saved = jsonDecode(jsonEncode(f)) })
	w4:Advance(1)
	check(#w3.Tickets == 0 and #w4.Tickets == 0 and indexOf(notices(w4, s, 0), C0.Tamer.Text.Became) == nil,
		"a tamer picked after A23-39 never gets the old-save ticket")
	-- a guild Archer save whose class pick never finished (ClassChosen false): no pet, no notice yet (the picker comes first)
	local w6 = bareWorld()
	local unpicked = deepCopy(C0.Data.Defaults)
	unpicked.Faction, unpicked.Class, unpicked.ClassChosen, unpicked.TamerNotice = "Neutral", "Archer", false, nil
	local u, k = w6:Join(304, { Saved = unpicked })
	w6:Advance(1)
	check(petCount(k) == 0 and #w6.Tickets == 0 and #notices(w6, u, 0) == 0 and k.TamerNotice ~= true,
		"class not picked yet: no pet, no notice, no ticket")
	-- a save that is not the tamer: nothing (the flag stays unset until it becomes one)
	local w5 = bareWorld()
	local old = deepCopy(C0.Data.Defaults)
	old.Faction, old.Class, old.ClassChosen, old.TamerNotice = "Neutral", "Warrior", true, nil
	local t, h = w5:Join(303, { Saved = old })
	w5:Advance(1)
	check(#w5.Tickets == 0 and #notices(w5, t, 0) == 0 and h.TamerNotice ~= true, "a guild warrior's save: no notice, no ticket")
end)

------------------------------------------------------------------ 5. pet data repair
runGroup("sanitize", function()
	local w = bareWorld()
	local Pet = w.Pet
	local d = { Pets = "broken" }
	Pet.Sanitize(d)
	check(type(d.Pets) == "table" and next(d.Pets.List) == nil and next(d.Pets.Equipped) == nil and d.Pets.Next == 1, "a broken Pets -> empty")
	local e = { Pets = { List = { [1] = { Sp = "BabySlime" }, P1 = { Sp = "BabySlime", Lv = 99, XP = -5, Name = string.rep("a", 50), Bound = 1 },
		P2 = "bad", P3 = { Sp = "Dragon", Lv = 0 / 0 }, P4 = { Sp = "BabySlime" } }, Equipped = { "P3", "P1", "P9", "P4" }, Next = -4 } }
	Pet.Sanitize(e)
	local p1, p3 = e.Pets.List.P1, e.Pets.List.P3
	check(p1 and p1.Lv == 10 and p1.XP == 0 and #p1.Name == 20 and p1.Bound == false, "a pet's fields are repaired", show(p1))
	check(p3 and p3.Sp == "Dragon" and p3.Lv == 1 and e.Pets.List[1] == nil and e.Pets.List.P2 == nil,
		"an unknown species is kept (never lost), broken entries dropped")
	check(#e.Pets.Equipped == 1 and e.Pets.Equipped[1] == "P1" and e.Pets.Next == 1, "only one known pet equipped; Next >= 1",
		show(e.Pets.Equipped))
	-- a new uid never reuses a kept entry
	local saved = deepCopy(C0.Data.Defaults)
	saved.Faction, saved.Class, saved.ClassChosen, saved.TamerNotice = "Neutral", "Archer", true, true
	saved.Pets = { List = { P1 = { Sp = "Dragon", Lv = 1, XP = 0, Name = "", Lean = "", Bound = false } }, Equipped = {}, Next = 1 }
	local q, f = w:Join(401, { Saved = saved })
	check(f.Pets.List.P1.Sp == "Dragon" and f.Pets.List.P2 and f.Pets.List.P2.Sp == "BabySlime" and f.Pets.Equipped[1] == "P2"
		and q:GetAttribute("EquippedPet") == "BabySlime", "the baby slime gets P2 (P1 kept)", show(f.Pets))
	-- PET-2b M1: Away is kept only while a pet is owned and none is out (true only)
	local function away(pets)
		local t = { Pets = pets }
		Pet.Sanitize(t)
		return t.Pets.Away
	end
	local a1 = away({ List = { P1 = { Sp = "BabySlime" } }, Equipped = {}, Next = 2, Away = true })
	local a2 = away({ List = { P1 = { Sp = "BabySlime" } }, Equipped = { "P1" }, Next = 2, Away = true })
	local a3 = away({ List = {}, Equipped = {}, Next = 1, Away = true })
	local a4 = away({ List = { P1 = { Sp = "BabySlime" } }, Equipped = {}, Next = 2, Away = "yes" })
	check(a1 == true and a2 == false and a3 == false and a4 == false, "Away kept only for an owned pet with none out",
		show({ a1, a2, a3, a4 }))
	check(C0.Data.Defaults.Pets.Away == false, "save default Away = false")
	-- PET-2b L2: the level cap and the known species come from Config.Pets (a later raise keeps saved levels)
	local wc = bareWorld()
	wc.Config.Pets.MaxLv = 20
	wc.Config.Pets.Species.Bunny = { Speed = { 0.05, 0.08 } }
	local b = { Pets = { List = { P1 = { Sp = "BabySlime", Lv = 15 }, P2 = { Sp = "Bunny", Lv = 25 } }, Equipped = { "P2" }, Next = 3 } }
	wc.Pet.Sanitize(b)
	check(b.Pets.List.P1.Lv == 15 and b.Pets.List.P2.Lv == 20 and b.Pets.Equipped[1] == "P2",
		"Config.Pets.MaxLv 20: Lv15 kept, Lv25 -> 20; a species added to Config.Pets.Species can be out", show(b.Pets))
	check(wc.Pet.XPToNext(15) == 15 * 15 and wc.Pet.XPToNext(20) == 0, "XPToNext follows Config.Pets.MaxLv")
end)

------------------------------------------------------------------ 6b. the pet models the clients draw (PET-3)
runGroup("models", function()
	local w = bareWorld()
	local rs = w.Services.ReplicatedStorage
	local folder = rs:FindFirstChild("PetModels")
	local slime = folder and folder:FindFirstChild("BabySlime")
	check(slime ~= nil and slime.ClassName == "Model" and slime:FindFirstChild("Body") ~= nil,
		"PetService.Start copies CustomModels.PetBabySlime to ReplicatedStorage.PetModels.BabySlime")
	local scripts = 0
	for _, d in (slime and slime:GetDescendants()) or {} do
		if d.ClassName == "Script" or d.ClassName == "LocalScript" or d.ClassName == "ModuleScript" then scripts += 1 end
	end
	check(scripts == 0, "no script is copied with the model", scripts)
	check(w.ServerStorage:FindFirstChild("CustomModels"):FindFirstChild("PetBabySlime") ~= nil, "the source stays in ServerStorage")
	check(w.Pet.PublishModels() == 0 and #folder:GetChildren() == 1, "a second publish adds nothing (no duplicates)")
	w.ServerStorage:FindFirstChild("CustomModels").Parent = nil
	check(w.Pet.PublishModels() == 0, "no CustomModels: nothing, no error")
end)

------------------------------------------------------------------ 6. the weapon model: a baton, never a bow
runGroup("visuals", function()
	local w = bareWorld()
	local built = {}
	local function stub(kind) return function() table.insert(built, kind); return {}, nil end end
	local buildWeapon = execute("CharacterVisuals.extract", VISUALS_EXTRACT, w:Env(), C0, w.Util,
		function() end, function(pl) return pl:GetAttribute("Class") or "Warrior" end,
		function() return 1 end, function() return {} end, stub("Staff"), stub("Bow"), stub("Sword"),
		function() end, function() end, function(name) local m = newInstance("Model", w); m.Name = name; return m end,
		function(pl) return pl:GetAttribute("Faction") or "None" end, function() end, stub("Baton"))
	local t = w:Join(501, { Class = "Archer", Faction = "Neutral", Tier = 1, Mask = 1 })
	buildWeapon(t, t.Character)
	check(built[1] == "Baton", "the tamer holds a baton", show(built))
	local h = w:Join(502, { Class = "Archer", Faction = "Halo", Tier = 1, Mask = 1 })
	buildWeapon(h, h.Character)
	check(built[2] == "Bow", "a Halo archer holds a bow", show(built))
	local b = w:Join(503, { Class = "Archer", Faction = "Neutral" })
	buildWeapon(b, b.Character)
	check(#built == 2, "a bare-handed tamer holds nothing", show(built))
end)

finish()
