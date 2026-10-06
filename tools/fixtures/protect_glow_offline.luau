-- protect_glow_offline.luau : ⑤ (quality_ideas §1, 검수 2026-10-07) spawn protection without the bubble. The ForceField
-- stays (Humanoid:TakeDamage still respects it) but is invisible; while protected the body gets a soft outline in its
-- faction color (Highlight "ProtectGlow": no fill, hidden behind walls). The outline goes with the shield (the
-- protected player's own hit, the end of the time) and PvPService's 1 s loop puts it back on a rebuilt body (an
-- appearance swap moves the ForceField, not the outline). tools/test_protect_glow.py runs the real PvPService and the
-- dev2_world services; rankWorld { PvPLoop = true } steps PvPService's loop by hand (w:PvPTick).

local P0 = C0.PvP
local GLOW = "ProtectGlow"

local function glowOf(p)
	local c = p.Character
	return c and c:FindFirstChild(GLOW) or nil
end
local function fieldOf(p)
	local c = p.Character
	return c and c:FindFirstChildOfClass("ForceField") or nil
end
local function countOf(p, className)
	local n = 0
	for _, child in p.Character:GetChildren() do
		if child.ClassName == className then n += 1 end
	end
	return n
end
local function sameColor(a, b) return a ~= nil and b ~= nil and a.X == b.X and a.Y == b.Y and a.Z == b.Z end
local function spawnBody(w, p)
	w.PS.CharacterSpawned:Fire(p, p.Character, p.Character:FindFirstChild("Humanoid"), false)
	w:Flush()
end

------------------------------------------------------------------ 1. data
runGroup("config", function()
	local g = P0.ProtectGlow
	check(type(g) == "table" and type(g.OutlineTransparency) == "number" and g.OutlineTransparency > 0
		and g.OutlineTransparency < 1, "Config.PvP.ProtectGlow.OutlineTransparency: a soft outline (between 0 and 1)",
		show(g))
	check(C0.Factions.Halo.Color ~= nil and C0.Factions.Horns.Color ~= nil, "the faction colors exist (Halo gold, Horns red)")
	check(P0.SpawnProtection == 10, "spawn protection stays 10 s", P0.SpawnProtection)
end)

------------------------------------------------------------------ 2. a spawn: no bubble, a faction outline
runGroup("spawn", function()
	local w = rankWorld({ PvPLoop = true })
	for _, case in { { 101, "Halo" }, { 102, "Horns" } } do
		local p = w:Join(case[1], case[2])
		check(glowOf(p) == nil and fieldOf(p) == nil, case[2] .. ": nothing before the spawn")
		spawnBody(w, p)
		local ff, h = fieldOf(p), glowOf(p)
		check(ff ~= nil and ff.Visible == false, case[2] .. ": the ForceField is there but invisible (no bubble)",
			show(ff and ff.Visible))
		check(h ~= nil and h.ClassName == "Highlight", case[2] .. ": a Highlight named ProtectGlow on the body",
			show(h and h.ClassName))
		check(h ~= nil and h.FillTransparency == 1, case[2] .. ": outline only (no fill)", show(h and h.FillTransparency))
		check(h ~= nil and sameColor(h.OutlineColor, C0.Factions[case[2]].Color), case[2] .. ": the outline is the faction color",
			show(h and h.OutlineColor))
		check(h ~= nil and h.OutlineTransparency == P0.ProtectGlow.OutlineTransparency, case[2] .. ": soft (Config transparency)",
			show(h and h.OutlineTransparency))
		check(h ~= nil and h.DepthMode == "HighlightDepthMode.Occluded", case[2] .. ": hidden behind walls (Occluded)",
			show(h and h.DepthMode))
		check(p:GetAttribute("Protected") == true, case[2] .. ": Protected (the 'Revive Shield' chip) stays")
		-- a second Protect while protected adds nothing new
		w.PvP.Protect(p, 5)
		check(countOf(p, "ForceField") == 1 and countOf(p, "Highlight") == 1, case[2] .. ": no second shield or outline",
			show({ countOf(p, "ForceField"), countOf(p, "Highlight") }))
	end
end)

------------------------------------------------------------------ 3. it goes with the shield
runGroup("ends", function()
	local w = rankWorld({ PvPLoop = true })
	-- the time runs out
	local a = w:Join(201, "Halo")
	spawnBody(w, a)
	for _ = 1, 9 do w:PvPTick(1) end
	check(glowOf(a) ~= nil and fieldOf(a) ~= nil and a:GetAttribute("Protected") == true, "9 s: still protected, still glowing")
	w:PvPTick(1)
	check(glowOf(a) == nil and fieldOf(a) == nil and a:GetAttribute("Protected") == false,
		"10 s: the shield and the outline are gone together", show({ glowOf(a) ~= nil, fieldOf(a) ~= nil }))
	for _ = 1, 3 do w:PvPTick(1) end
	check(glowOf(a) == nil, "later ticks never bring it back")
	-- the protected player's own hit (CombatService calls BreakProtection)
	local b = w:Join(202, "Horns")
	spawnBody(w, b)
	w:PvPTick(1)
	w.PvP.BreakProtection(b)
	check(glowOf(b) == nil and fieldOf(b) == nil and b:GetAttribute("Protected") == false,
		"a hit breaks the shield: the outline goes too", show({ glowOf(b) ~= nil, fieldOf(b) ~= nil }))
	w:PvPTick(1)
	check(glowOf(b) == nil, "the next tick does not bring it back")
	-- never protected (no spawn yet): the loop adds nothing
	local c = w:Join(203, "Halo")
	for _ = 1, 3 do w:PvPTick(1) end
	check(glowOf(c) == nil and fieldOf(c) == nil, "a body that was never protected never glows")
end)

------------------------------------------------------------------ 4. a rebuilt body (an appearance swap)
runGroup("rebuilt-body", function()
	local w = rankWorld({ PvPLoop = true })
	local p = w:Join(301, "Horns")
	spawnBody(w, p)
	w:PvPTick(1)
	-- PlayerService.installCharacter moves the ForceField to the new body; the old body (and its outline) is destroyed
	local old = p.Character
	local ff = fieldOf(p)
	w:Body(p)
	ff.Parent = p.Character
	old:Destroy()
	w.PS.CharacterSpawned:Fire(p, p.Character, p.Character:FindFirstChild("Humanoid"), true) -- cosmetic: no new shield
	w:Flush()
	check(glowOf(p) == nil and fieldOf(p) == ff and countOf(p, "ForceField") == 1,
		"right after the swap: the moved shield, no outline yet, no new shield", show({ glowOf(p) ~= nil, countOf(p, "ForceField") }))
	w:PvPTick(1)
	local h = glowOf(p)
	check(h ~= nil and sameColor(h.OutlineColor, C0.Factions.Horns.Color) and fieldOf(p).Visible == false,
		"the next second: the outline is back on the new body (the shield still invisible)", show(h and h.OutlineColor))
	-- the swap never renewed the time: it still ends 10 s after the first spawn
	for _ = 1, 7 do w:PvPTick(1) end
	check(glowOf(p) ~= nil, "9 s after the spawn: still glowing")
	w:PvPTick(1)
	check(glowOf(p) == nil and fieldOf(p) == nil, "10 s after the spawn: gone (the swap did not add time)")
end)

finish()
