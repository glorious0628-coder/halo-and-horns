-- pet_speed_offline.luau : PET-1 the ONE walk speed (design skills_weapons_pets_2026-10-05 §0-1, SPEC A23-15 / A23-49).
-- tools/test_pet_speed.py injects CONFIG_SOURCE, UTIL_SOURCE (kit), SPEED_SOURCE (PlayerService.ComputeWalkSpeed +
-- RefreshSpeed), APPLY_SOURCE (PlayerService applyStats), MOVE_SOURCE (ZoneService move table + acNum + checkMove) and
-- PET_SOURCE (the whole PetService) in front of dev2_kit.luau; this file follows.
-- Contract: speed = Config.Player.WalkSpeed x class WalkSpeedMult x (1 + the equipped pet's bonus), no skill buff,
-- capped at Config.Speed.Cap x the base; an Active kaiju gets no pet bonus (the kaiju rule); every pet publish refreshes
-- the speed; ZoneService.checkMove never flags a player walking at the computed speed.

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local BASE = C0.Player.WalkSpeed

local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-9 end

-- a humanoid double + a player with attributes
local function humanoid(hp)
	return { Health = hp or 100, MaxHealth = 100, WalkSpeed = 16 }
end

-- PlayerService.ComputeWalkSpeed / RefreshSpeed on a registry; class id from a classDef stub (ClassService.GetClassDef)
local function speedApi(w, registry)
	local ps = {}
	local function classDef(player)
		return w.Config.Classes[player:GetAttribute("Class") or "Warrior"] or w.Config.Classes.Warrior
	end
	execute("PlayerService.speed", SPEED_SOURCE, w:Env(), ps, registry, w.Config, w.Util, classDef)
	return ps
end

local function playerWith(w, attrs, hum)
	local p = w:NewPlayer(#w.PlayerList + 1, attrs)
	p.Hum = hum
	return p
end

-- the kit's Util.GetHumanoid reads Character:FindFirstChildOfClass; the speed code only needs the humanoid
local function withHumanoids(w)
	w.Util.GetHumanoid = function(p) return p.Hum end
end

runGroup("config", function()
	local C = C0
	check(C.Speed and C.Speed.Cap == 1.35, "Config.Speed.Cap = 1.35 (x the base)", show(C.Speed))
	local def = C.Pets and C.Pets.Species and C.Pets.Species.BabySlime
	check(def and def.Speed and def.Speed[1] == 0.07 and def.Speed[2] == 0.10 and C.Pets.MaxLv == 10,
		"baby slime: +7% at pet Lv1 -> +10% at pet Lv10 (design §2)", show(def))
	check(near(C.PetSpeedBonus("BabySlime", 1), 0.07) and near(C.PetSpeedBonus("BabySlime", 10), 0.10)
		and near(C.PetSpeedBonus("BabySlime", 4), 0.08), "bonus grows in a straight line (Lv4 = +8%)",
		show({ C.PetSpeedBonus("BabySlime", 1), C.PetSpeedBonus("BabySlime", 4), C.PetSpeedBonus("BabySlime", 10) }))
	check(C.PetSpeedBonus("BabySlime", 0) == C.PetSpeedBonus("BabySlime", 1) and C.PetSpeedBonus("BabySlime", 99) == C.PetSpeedBonus("BabySlime", 10)
		and C.PetSpeedBonus("BabySlime", 0 / 0) == C.PetSpeedBonus("BabySlime", 1) and C.PetSpeedBonus("BabySlime", nil) == C.PetSpeedBonus("BabySlime", 1),
		"levels clamp to 1..MaxLv (0, 99, NaN, nil)")
	check(C.PetSpeedBonus("Dragon", 5) == 0 and C.PetSpeedBonus("", 5) == 0 and C.PetSpeedBonus(nil, 5) == 0,
		"no / unknown pet: no bonus")
	local cases = {
		{ "Warrior", nil, 0, false, BASE }, { "Mage", nil, 0, false, BASE }, { "Archer", nil, 0, false, BASE * 1.1 },
		{ "Archer", "BabySlime", 1, false, BASE * 1.1 * 1.07 }, { "Archer", "BabySlime", 10, false, BASE * 1.1 * 1.10 },
		{ "Warrior", "BabySlime", 10, false, BASE * 1.10 }, { "Archer", "BabySlime", 10, true, BASE * 1.1 },
		{ "Nope", nil, 0, false, BASE },
	}
	for _, c in cases do
		local got = C.WalkSpeed(c[1], c[2], c[3], c[4])
		check(near(got, c[5]), "WalkSpeed(" .. c[1] .. ", " .. tostring(c[2]) .. " Lv" .. c[3] .. (c[4] and ", kaiju" or "") .. ")",
			show({ got, c[5] }))
	end
	-- ⑤ a summoned pet (Roll.Spd, whole %; tamer_server §4): Lv1 = roll %, MaxLv = roll % + RollGrow (3), a straight line;
	-- no roll (nil / 0) = the species' own line; a roll outside PetRollSpd (5..10) is cut to it
	check(C.Pets.RollGrow == 0.03 and near(C.PetSpeedBonus("BabySlime", 1, 7), 0.07) and near(C.PetSpeedBonus("BabySlime", 10, 7), 0.10)
		and near(C.PetSpeedBonus("BabySlime", 4, 7), 0.08), "roll 7: +7% at Lv1 -> +10% at Lv10 (the baby slime's slope)",
		show({ C.PetSpeedBonus("BabySlime", 1, 7), C.PetSpeedBonus("BabySlime", 10, 7) }))
	check(near(C.PetSpeedBonus("BabySlime", 1, 5), 0.05) and near(C.PetSpeedBonus("BabySlime", 10, 10), 0.13)
		and near(C.PetSpeedBonus("BabySlime", 1, 10), 0.10), "roll 5: +5% at Lv1; roll 10: +10% -> +13%",
		show({ C.PetSpeedBonus("BabySlime", 1, 5), C.PetSpeedBonus("BabySlime", 10, 10) }))
	check(C.PetSpeedBonus("BabySlime", 4, 0) == C.PetSpeedBonus("BabySlime", 4) and C.PetSpeedBonus("BabySlime", 4, nil) == C.PetSpeedBonus("BabySlime", 4)
		and near(C.PetSpeedBonus("BabySlime", 1, 0), 0.07), "roll 0 / nil = the old line (the baby slime 7 -> 10 stays)", "")
	check(near(C.PetSpeedBonus("BabySlime", 1, 50), 0.10) and near(C.PetSpeedBonus("BabySlime", 1, 2), 0.05) and C.PetSpeedBonus("Dragon", 1, 9) == 0,
		"a roll is cut to 5..10; an unknown species is still 0", show({ C.PetSpeedBonus("BabySlime", 1, 50), C.PetSpeedBonus("BabySlime", 1, 2) }))
	check(near(C.WalkSpeed("Archer", "BabySlime", 10, false, 10), BASE * 1.1 * 1.13) and near(C.WalkSpeed("Archer", "BabySlime", 10, true, 10), BASE * 1.1)
		and near(C.WalkSpeed("Warrior", "BabySlime", 1, false, 6), BASE * 1.06), "WalkSpeed takes the roll (kaiju: none)",
		show({ C.WalkSpeed("Archer", "BabySlime", 10, false, 10) }))
	-- the cap: a faster class (tuning) never goes over Cap x the base, with or without the pet
	local alt = execute("Config", CONFIG_SOURCE, nativeEnv())
	alt.Classes.Archer.WalkSpeedMult = 1.4
	check(near(alt.WalkSpeed("Archer", "BabySlime", 10, false), BASE * 1.35) and near(alt.WalkSpeed("Archer", nil, 0, false), BASE * 1.35)
		and near(alt.WalkSpeed("Archer", "BabySlime", 10, false, 10), BASE * 1.35),
		"capped at Cap x the base (a roll 10 pet too)", show({ alt.WalkSpeed("Archer", "BabySlime", 10, false) }))
	check(C.WalkSpeed("Archer", "BabySlime", 10, false, 10) <= BASE * C.Speed.Cap, "the fastest summon (archer + roll 10, Lv10: 24.86) is under the cap",
		tostring(C.WalkSpeed("Archer", "BabySlime", 10, false, 10)))
	local maxNow = 0
	for _, cls in C.ClassOrder do
		for lv = 0, C.Pets.MaxLv do
			maxNow = math.max(maxNow, C.WalkSpeed(cls, lv > 0 and "BabySlime" or nil, lv, false))
		end
	end
	check(maxNow <= BASE * C.Speed.Cap and near(maxNow, BASE * 1.1 * 1.1), "today's fastest = archer + Lv10 pet (24.2), under the cap",
		tostring(maxNow))
end)

runGroup("player-speed", function()
	local w = newWorld({})
	withHumanoids(w)
	local kaiju = {}
	local registry = { KaijuService = { GetState = function(p) return kaiju[p] or "None" end } }
	local ps = speedApi(w, registry)
	local tamer = playerWith(w, { Class = "Archer", Faction = "Neutral", EquippedPet = "BabySlime", PetLv = 10 }, humanoid())
	local plain = playerWith(w, { Class = "Warrior", Faction = "Halo", EquippedPet = "", PetLv = 0 }, humanoid())
	check(near(ps.ComputeWalkSpeed(tamer), BASE * 1.1 * 1.1), "the tamer with a Lv10 baby slime: 24.2", ps.ComputeWalkSpeed(tamer))
	check(near(ps.ComputeWalkSpeed(plain), BASE), "no pet, warrior: the base", ps.ComputeWalkSpeed(plain))
	tamer:SetAttribute("PetLv", 1)
	check(near(ps.ComputeWalkSpeed(tamer), BASE * 1.1 * 1.07), "reads the pet level attribute (Lv1: 23.54)", ps.ComputeWalkSpeed(tamer))
	kaiju[tamer] = "Active"
	check(near(ps.ComputeWalkSpeed(tamer), BASE * 1.1), "an Active kaiju: no pet bonus (the kaiju rule)", ps.ComputeWalkSpeed(tamer))
	kaiju[tamer] = "Siren"
	check(near(ps.ComputeWalkSpeed(tamer), BASE * 1.1 * 1.07), "the siren is not the kaiju yet: the pet bonus stays", ps.ComputeWalkSpeed(tamer))
	kaiju[tamer] = nil
	tamer:SetAttribute("PetRoll", 10)
	check(near(ps.ComputeWalkSpeed(tamer), BASE * 1.1 * 1.10), "reads the PetRoll attribute (roll 10, Lv1: +10%)", ps.ComputeWalkSpeed(tamer))
	tamer:SetAttribute("PetRoll", 0)
	-- no KaijuService / a throwing one: never an error, the pet bonus stays
	local ps2 = speedApi(w, {})
	check(near(ps2.ComputeWalkSpeed(tamer), BASE * 1.1 * 1.07), "no KaijuService in the registry: pet bonus", ps2.ComputeWalkSpeed(tamer))
	local ps3 = speedApi(w, { KaijuService = { GetState = function() error("offline failure") end } })
	check(near(ps3.ComputeWalkSpeed(tamer), BASE * 1.1 * 1.07), "a failing GetState: pet bonus, no error", ps3.ComputeWalkSpeed(tamer))
	-- RefreshSpeed: WalkSpeed only (HP and MaxHealth untouched), never on a dead humanoid, nothing without one
	tamer.Hum.Health, tamer.Hum.MaxHealth = 37, 150
	ps.RefreshSpeed(tamer)
	check(near(tamer.Hum.WalkSpeed, BASE * 1.1 * 1.07) and tamer.Hum.Health == 37 and tamer.Hum.MaxHealth == 150,
		"RefreshSpeed sets WalkSpeed only", show(tamer.Hum))
	local dead = playerWith(w, { Class = "Archer", EquippedPet = "BabySlime", PetLv = 10 }, humanoid(0))
	ps.RefreshSpeed(dead)
	check(dead.Hum.WalkSpeed == 16, "a dead humanoid is left alone", dead.Hum.WalkSpeed)
	local none = playerWith(w, { Class = "Archer" }, nil)
	local ok = pcall(ps.RefreshSpeed, none)
	check(ok, "no character: nothing happens")
	-- applyStats (spawn / RefreshCharacter) uses the same number
	local applyStats = execute("PlayerService.applyStats", APPLY_SOURCE, w:Env(), ps, function() return 200 end)
	local h = humanoid(100)
	local q = playerWith(w, { Class = "Archer", EquippedPet = "BabySlime", PetLv = 10 }, h)
	applyStats(q, h, true)
	check(near(h.WalkSpeed, ps.ComputeWalkSpeed(q)) and h.MaxHealth == 200 and h.Health == 200,
		"applyStats: WalkSpeed = ComputeWalkSpeed (and HP as before)", show(h))
end)

runGroup("pet-publish-refresh", function()
	local w = newWorld({})
	local ss = newInstance("ServerStorage", w)
	w.Services.ServerStorage = ss
	local data = {}
	local refreshed = {}
	local ps = {
		PlayerReady = w.Util.Signal.new(),
		GetData = function(p) return data[p] end,
		IsReady = function() return true end,
		RefreshSpeed = function(p) table.insert(refreshed, { P = p, Pet = p:GetAttribute("EquippedPet"), Lv = p:GetAttribute("PetLv") }) end,
	}
	local registry = { PlayerService = ps, ClassService = { ClassChanged = w.Util.Signal.new() },
		FactionService = { FactionChanged = w.Util.Signal.new() }, MonetizationService = { AddTickets = function() end } }
	local pet = w:Load("PetService", PET_SOURCE)
	pet.Init(registry)
	pet.Start()
	local p = w:NewPlayer(51, { Class = "Archer", Faction = "Neutral" })
	data[p] = { ClassChosen = true, Class = "Archer", Faction = "Neutral", Level = 3, TamerNotice = true, Pets = nil }
	ps.PlayerReady:Fire(p, data[p])
	local last = refreshed[#refreshed]
	check(#refreshed >= 1 and last.P == p and last.Pet == "BabySlime" and last.Lv == 1,
		"granting + equipping the pet refreshes the speed (after the attributes are set)", show({ last.Pet, last.Lv }))
	local n = #refreshed
	data[p].Pets.Equipped = {}
	pet.GiveTamerPet(p, true) -- re-equips the owned slime
	check(#refreshed == n + 1 and refreshed[#refreshed].Pet == "BabySlime", "re-equipping refreshes the speed", #refreshed - n)
	local q = w:NewPlayer(52, { Class = "Warrior", Faction = "Halo" })
	data[q] = { ClassChosen = true, Class = "Warrior", Faction = "Halo", Level = 3 }
	ps.PlayerReady:Fire(q, data[q])
	check(refreshed[#refreshed].P == q and refreshed[#refreshed].Pet == "", "a join without a pet still publishes + refreshes (EquippedPet '')",
		show({ refreshed[#refreshed].Pet, refreshed[#refreshed].Lv }))
	check(p:GetAttribute("PetRoll") == 0 and q:GetAttribute("PetRoll") == 0, "PetRoll = 0 without a summoned pet", "")
	-- ⑤ a summoned pet that follows (nothing else out: it comes out): PetRoll = its Roll.Spd, set before the speed refresh
	data[p].Pets.Equipped = {}
	local sum = pet.SummonPet(p, "BabySlime", { Spd = 9 })
	check(sum ~= nil and data[p].Pets.Equipped[1] == sum and p:GetAttribute("PetRoll") == 9, "a pet with Roll.Spd 9 out: PetRoll = 9",
		tostring(p:GetAttribute("PetRoll")))
end)

runGroup("move-check", function()
	local w = newWorld({})
	local C = w.Config
	local clock = 0
	local env = w:Env()
	env.os = { clock = function() return clock end, time = os.time, date = os.date }
	env.workspace = { Gravity = 196.2 }
	local checkMove, move = execute("ZoneService.checkMove", MOVE_SOURCE, env, C, w.Util)
	local char = {}
	-- walkSpeed = the humanoid's WalkSpeed, moved = the studs per second actually covered (default: walkSpeed)
	local function flatMove(speed, dt, moved)
		local p = { Character = char, Hum = { WalkSpeed = speed } }
		w.Util.GetHumanoid = function(x) return x.Hum end
		move.lastGood[p] = { Pos = vec(0, 5, 0), T = clock, Char = char, VY = 0 }
		clock += dt
		return checkMove(p, vec((moved or speed) * dt, 5, 0))
	end
	local worst = nil
	local fastest = 0
	for _, cls in C.ClassOrder do
		for lv = 0, C.Pets.MaxLv do
			for _, kaijuOn in { false, true } do
				local speed = math.max(C.WalkSpeed(cls, lv > 0 and "BabySlime" or nil, lv, kaijuOn),
					C.WalkSpeed(cls, lv > 0 and "BabySlime" or nil, lv, kaijuOn, lv > 0 and 10 or nil)) -- ⑤ a roll 10 summon
				fastest = math.max(fastest, speed)
				for _, dt in { 0.05, 0.1, 0.2, 0.5, 1, 3 } do
					if not flatMove(speed, dt) then worst = worst or { cls, lv, kaijuOn, dt, speed } end
				end
			end
		end
	end
	check(worst == nil, "every class x pet level x kaiju at its computed speed passes checkMove (dt 0.05..3 s)", show(worst))
	local capped = BASE * C.Speed.Cap
	local flagged = nil
	for _, dt in { 0.05, 0.2, 1, 3 } do
		if not flatMove(capped, dt) then flagged = dt end
	end
	check(flagged == nil, "walking at the cap (27) is never flagged", tostring(flagged))
	check(not flatMove(fastest, 1, fastest * 3), "the check is live: moving 3x the fastest speed for 1 s is flagged")
end)

finish()
