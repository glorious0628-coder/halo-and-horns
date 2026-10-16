-- kaiju_town_offline.luau : 빛 마을 점검 #41 (user 2026-10-10, (b)): a Halo player standing inside a faction town (Halo
-- Citadel / Horns Den) can no longer hit the Active kaiju outside it; the Crossroads fight and fights outside the towns
-- stay as they were (the kaiju exception: rookies allowed, protection ignored). tools/test_kaiju_town.py runs the real
-- PvPService on tools/fixtures/dev2_world.luau (rankWorld); w.ZoneIdOf[p] picks the zone the ZoneService double
-- answers (GetZone / IsTown / IsPvPZone follow it).

local Z = C0.Zones

local function place(w, p, zoneId)
	w.ZoneIdOf[p] = zoneId
	w.InTown[p] = Z[zoneId] ~= nil and Z[zoneId].Town == true
end

local function pair(w, id, opts)
	opts = opts or {}
	local halo = w:Join(id, "Halo", { Level = opts.Level, Playtime = opts.Playtime })
	local kaiju = w:Join(id + 1, "Horns")
	kaiju:SetAttribute("KaijuState", opts.State or "Active")
	return halo, kaiju
end

------------------------------------------------------------------ 1. the zones the rule reads
runGroup("zones", function()
	check(Z.HaloTown.Town == true and Z.HaloTown.Faction == "Halo" and Z.HornsTown.Town == true and Z.HornsTown.Faction == "Horns",
		"Halo Citadel / Horns Den: towns with a faction", show({ Z.HaloTown.Faction, Z.HornsTown.Faction }))
	check(Z.Crossroads.Town == true and Z.Crossroads.Faction == nil, "the Crossroads: a town without a faction", show(Z.Crossroads))
end)

------------------------------------------------------------------ 2. where both stand (A23-218, user 10/16, with A23-203)
runGroup("kaiju exception", function()
	local w = rankWorld()
	local h, k = pair(w, 101)
	place(w, k, "Crossroads")
	place(w, h, "Crossroads")
	check(w.PvP.CanAttack(h, k) == true, "both in the Crossroads: a knight may hit the kaiju (the Crossroads fight stays)")
	local okK, whyK = w.PvP.CanAttack(k, h)
	check(okK == false and whyK == "SafeZone", "... and the kaiju hurts nobody in the Crossroads (A23-218)", show({ okK, whyK }))
	place(w, k, "GoblinWoods")
	place(w, h, "GoblinWoods")
	check(w.PvP.CanAttack(h, k) == true and w.PvP.CanAttack(k, h) == true, "both inside a red zone (Goblin Woods): a normal fight")
	place(w, k, "SlimeMeadow")
	place(w, h, "SlimeMeadow")
	local ok, why = w.PvP.CanAttack(h, k)
	check(ok == false and why == "SafeZone", "both in the safe hunting land: no kaiju hit (A23-203)", show({ ok, why }))
	place(w, h, "Crossroads")
	check(w.PvP.CanAttack(h, k) ~= true, "Crossroads -> a kaiju just outside it: no hit (both must stand there)")
	place(w, h, "GoblinWoods")
	check(w.PvP.CanAttack(h, k) ~= true, "red zone -> a kaiju in the safe land: no hit (both must be inside)")
	place(w, k, "Crossroads")
	place(w, h, "HaloTown")
	ok, why = w.PvP.CanAttack(h, k)
	check(ok == false and why == "SafeZone", "Halo Citadel -> kaiju in the Crossroads: blocked (SafeZone, #41)", show({ ok, why }))
	place(w, h, "HornsTown")
	ok, why = w.PvP.CanAttack(h, k)
	check(ok == false, "Horns Den -> blocked too (any faction town)", show({ ok, why }))
	place(w, h, "Crossroads")
	place(w, k, "HaloTown")
	check(w.PvP.CanAttack(h, k) ~= true, "Crossroads -> a kaiju standing in Halo Citadel: no hit (a town is no fight place)")
end)

------------------------------------------------------------------ 3. what the exception still covers outside the towns
runGroup("rookies and others", function()
	local w = rankWorld()
	-- a rookie (low level, little playtime) may still hit the Active kaiju outside the towns
	local h, k = pair(w, 201, { Level = 3, Playtime = 60 })
	place(w, h, "Crossroads")
	place(w, k, "Crossroads")
	check(w.PvP.CanAttack(h, k) == true, "a rookie Halo in the Crossroads: the kaiju exception still lets them hit")
	place(w, h, "HaloTown")
	check(w.PvP.CanAttack(h, k) ~= true, "a rookie Halo in Halo Citadel: blocked")
	-- a kaiju that is only queued is no exception anywhere: the normal rules (a town is a safe zone)
	local q, s = pair(w, 203, { State = "Queued" })
	place(w, q, "Crossroads")
	place(w, s, "SlimeMeadow")
	check(w.PvP.CanAttack(q, s) ~= true, "a queued kaiju from the Crossroads: the normal safe-zone rule")
	-- Horns never had the exception: unchanged
	local r = w:Join(205, "Horns")
	local hk = w:Join(206, "Halo")
	hk:SetAttribute("KaijuState", "Active")
	place(w, r, "Crossroads")
	place(w, hk, "SlimeMeadow")
	check(w.PvP.CanAttack(r, hk) ~= true, "a Horns player in the Crossroads vs an Active Halo body: no exception (Halo only)")
end)

------------------------------------------------------------------ 4. the kaiju's HP: only Halo players who can fight it count
runGroup("kaiju HP count", function()
	local w = rankWorld()
	local count = execute("KaijuService.countNearbyHalo", KAIJU_COUNT_EXTRACT, w:Env(), w.Config, w.Util, w.Registry,
		function() return w.PS.GetReadyPlayers() end, function(p) return p:GetAttribute("Faction") or "None" end)
	local k = w:Join(301, "Horns")
	k:SetAttribute("KaijuState", "Active")
	place(w, k, "SlimeMeadow")
	local a, b, c = w:Join(302, "Halo"), w:Join(303, "Halo"), w:Join(304, "Halo") -- every body stands at the origin
	place(w, a, "SlimeMeadow")
	place(w, b, "Crossroads")
	place(w, c, "HaloTown")
	check(count(k) == 2, "Halo fighters near the kaiju: the meadow and the Crossroads count, Halo Citadel does not (#41)",
		count(k))
	place(w, c, "SlimeMeadow")
	check(count(k) == 3, "the same player out of town counts again", count(k))
	place(w, a, "HornsTown")
	check(count(k) == 2, "a Halo player standing in Horns Den does not count either", count(k))
end)

finish()
