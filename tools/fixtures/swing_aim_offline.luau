-- swing_aim_offline.luau : A23-61 server aim (검수 2026-10-07, game dev 1's Studio finding): the client turns the body to
-- the nearest monster before it sends Swing, but the server sees that turn 0.27-0.43 s late, so a monster behind me was
-- missed 3 / 3. CombatService.Swing now aims at the nearest monster within Range in any direction when nothing is inside
-- the front half (AimCone) and turns the root to it; players and the golden goose keep the front-half rule. Auto combat
-- swings at a monster behind too. tools/test_swing_aim.py binds the CURRENT sources of tools/test_unarmed_start.py
-- (dev2_kit.luau and dev2_combat_world.luau come first). Players face -Z at the origin; `dz` < 0 = behind me.

-- true when the server turned the root since the last look (the combat world's CFrame.lookAt double marks Turned)
local function settle(p)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local cf = root and root.CFrame
	if type(cf) == "table" and cf.Turned then
		cf.Turned = nil
		return true
	end
	return false
end

local function swing(w, p)
	w:Advance(1.2) -- past every swing interval
	w.Net.Get("Swing").OnServerEvent:Fire(p)
	w:Flush()
	return settle(p)
end

local function at(deg, dist)
	local r = math.rad(deg)
	return dist * math.sin(r), dist * math.cos(r) -- dx, dz (dz > 0 = in front, -Z)
end

local function monsterAt(w, kind, deg, dist)
	local dx, dz = at(deg, dist)
	return w:Monster(kind, dz, dx, 99999)
end

-- A23-68 #1: while the screen fades for the move to the meadow (QuestService MoveLockUntil, server time) a swing does
-- nothing and costs nothing; after it the next swing hits
runGroup("move lock", function()
	local w = bareWorld({ Hit = true })
	local p = w:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local m = monsterAt(w, "Slime", 0, w.Config.Classes.Warrior.Range * 0.5)
	p:SetAttribute("MoveLockUntil", w.Time + 10)
	swing(w, p)
	check(w:Dealt(m) == 0, "a swing during the move fade does nothing", w:Dealt(m))
	p:SetAttribute("MoveLockUntil", 0)
	swing(w, p)
	check(w:Dealt(m) > 0, "after the move the swing hits again", w:Dealt(m))
end)

runGroup("warrior around", function()
	local w = bareWorld({ Hit = true })
	local p = w:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local range = w.Config.Classes.Warrior.Range
	local behind = monsterAt(w, "Slime", 180, range * 0.6)
	local turned = swing(w, p)
	check(w:Dealt(behind) > 0 and turned, "a slime right behind me: the swing turns to it and hits", show({ w:Dealt(behind), turned }))
	local root = p.Character:FindFirstChild("HumanoidRootPart")
	check(root.CFrame.LookVector.Z > 0.99, "the root now faces it (+Z)", root.CFrame.LookVector.Z)
	-- something in the front half wins: no turn, the front one is hit
	local w2 = bareWorld({ Hit = true })
	local p2 = w2:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local front = monsterAt(w2, "Slime", 60, range * 0.6)
	local back = monsterAt(w2, "Slime", 175, range * 0.3)
	local t2 = swing(w2, p2)
	check(w2:Dealt(front) > 0 and w2:Dealt(back) == 0 and not t2, "a monster in front (60 deg) and a nearer one behind: the front one, no turn",
		show({ w2:Dealt(front), w2:Dealt(back), t2 }))
	-- out of reach behind: nothing
	local w3 = bareWorld({ Hit = true })
	local p3 = w3:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local far = monsterAt(w3, "Slime", 180, range + 2)
	local t3 = swing(w3, p3)
	check(w3:Dealt(far) == 0 and not t3, "a monster behind but out of Range: no hit, no turn", show({ w3:Dealt(far), t3 }))
	-- turned: everything in the new front half within Range is hit (Around), the old front half is not
	local w4 = bareWorld({ Hit = true })
	local p4 = w4:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local a = monsterAt(w4, "Slime", 180, range * 0.5)
	local b = monsterAt(w4, "Slime", 135, range * 0.8)
	swing(w4, p4)
	check(w4:Dealt(a) > 0 and w4:Dealt(b) > 0, "turned to the one behind: the Around sweep hits the new front half (two monsters)",
		show({ w4:Dealt(a), w4:Dealt(b) }))
end)

runGroup("players keep the front half", function()
	-- a player behind me and no monster: no hit, no turn
	local w = bareWorld({ Hit = true })
	local p = w:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local range = w.Config.Classes.Warrior.Range
	local dx, dz = at(180, range * 0.5)
	local v = w:Join(2, { Class = "Warrior", Faction = "Horns", Level = 5, Tier = 1, Mask = 1, Pos = vec(dx, 0, -dz) })
	local vh = v.Character:FindFirstChild("Humanoid")
	local t = swing(w, p)
	check(vh.Health == 100 and not t, "an enemy player behind me: never hit, no turn", show({ vh.Health, t }))
	-- a monster and a player both behind: turned to the monster, the player is still not hit
	local m = monsterAt(w, "Slime", 170, range * 0.4)
	local t2 = swing(w, p)
	check(w:Dealt(m) > 0 and vh.Health == 100 and t2, "a monster and a player behind: the monster is hit, the player is not",
		show({ w:Dealt(m), vh.Health, t2 }))
	-- a player in front is hit as before (front half)
	local w2 = bareWorld({ Hit = true })
	local p2 = w2:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local fx, fz = at(30, range * 0.5)
	local v2 = w2:Join(2, { Class = "Warrior", Faction = "Horns", Level = 5, Tier = 1, Mask = 1, Pos = vec(fx, 0, -fz) })
	swing(w2, p2)
	check(v2.Character:FindFirstChild("Humanoid").Health < 100, "an enemy in front is hit as before", v2.Character:FindFirstChild("Humanoid").Health)
	-- an enemy in front and a monster behind: the front half has a target, so no turn (the enemy is hit, not the monster)
	local hp = v2.Character:FindFirstChild("Humanoid").Health
	local back = monsterAt(w2, "Slime", 180, range * 0.4)
	local t5 = swing(w2, p2)
	check(v2.Character:FindFirstChild("Humanoid").Health < hp and w2:Dealt(back) == 0 and not t5,
		"an enemy in front and a monster behind: the enemy, no turn", show({ hp, v2.Character:FindFirstChild("Humanoid").Health, w2:Dealt(back), t5 }))
	-- the golden goose behind me never pulls the aim and is not counted by a turned swing
	local w3 = bareWorld({ Hit = true })
	local goose = {}
	w3.Registry.GooseService.GetPosition = function() return vec(0, 0, 4) end
	w3.Registry.GooseService.RegisterHit = function(pl) table.insert(goose, pl) return 1 end
	local p3 = w3:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local t3 = swing(w3, p3)
	check(#goose == 0 and not t3, "the goose behind me alone: no turn, no tug", show({ #goose, t3 }))
	local m3 = monsterAt(w3, "Slime", 180, range * 0.6)
	local t4 = swing(w3, p3)
	check(w3:Dealt(m3) > 0 and t4 and #goose == 0, "a slime and the goose behind: turned to the slime, no tug counted", show({ #goose, t4 }))
end)

runGroup("mage, archer, bare hands", function()
	local w = bareWorld({ Hit = true })
	local mage = w:Join(1, { Class = "Mage", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local mr = w.Config.Classes.Mage.Range
	local m = monsterAt(w, "Slime", 180, mr * 0.7)
	local t = swing(w, mage)
	check(w:Dealt(m) > 0 and t, "Mage (Splash): the orb goes to the monster behind", show({ w:Dealt(m), t }))
	local w2 = bareWorld({ Hit = true })
	local archer = w2:Join(1, { Class = "Archer", Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
	local ar = w2.Config.Classes.Archer.Range
	local m2 = monsterAt(w2, "Slime", -150, ar * 0.7)
	local t2 = swing(w2, archer)
	check(w2:Dealt(m2) > 0 and t2, "Archer (Multi): the arrow goes to the monster behind-left", show({ w2:Dealt(m2), t2 }))
	local w3 = bareWorld({ Hit = true })
	local bare = w3:Join(1, { Class = "Warrior", Faction = "Halo", Level = 1, Tier = 0, Mask = 0 })
	local ur = w3.Config.Combat.Unarmed.Range
	local m3 = monsterAt(w3, "Slime", 180, ur * 0.7)
	local t3 = swing(w3, bare)
	check(w3:Dealt(m3) > 0 and t3, "bare hands: the punch turns to the slime behind", show({ w3:Dealt(m3), t3 }))
	local far = monsterAt(w3, "Slime", 180, ur + 1)
	m3.Alive = false
	local t4 = swing(w3, bare)
	check(w3:Dealt(far) == 0 and not t4, "bare hands: a slime behind beyond the punch reach (7): nothing", show({ w3:Dealt(far), t4 }))
end)

-- the root turn may not take (the client owns its character): the swing still aims through its own facing toward the
-- monster, whatever the root says
runGroup("aim without the turn", function()
	for _, case in { { "Warrior", 0.6 }, { "Mage", 0.7 }, { "Archer", 0.7 } } do
		local w = bareWorld({ Hit = true })
		w.TurnFails = true
		local p = w:Join(1, { Class = case[1], Faction = "Halo", Level = 5, Tier = 1, Mask = 1 })
		local m = monsterAt(w, "Slime", 180, w.Config.Classes[case[1]].Range * case[2])
		local t = swing(w, p)
		check(w:Dealt(m) > 0 and not t, case[1] .. ": the turn fails, the monster behind is still hit", show({ w:Dealt(m), t }))
	end
end)

runGroup("auto combat", function()
	local w = bareWorld({ Hit = true })
	local p = w:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1,
		Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	local range = w.Config.Classes.Warrior.Range
	local m = monsterAt(w, "Slime", 180, range * 0.6)
	w:Advance(1.2)
	w:AutoTick()
	settle(p)
	check(w:Dealt(m) > 0, "auto combat swings at a monster behind me", w:Dealt(m))
	-- a player behind is never an auto target
	local w2 = bareWorld({ Hit = true })
	local p2 = w2:Join(1, { Class = "Warrior", Faction = "Halo", Level = 5, Tier = 1, Mask = 1,
		Attrs = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	local dx, dz = at(180, range * 0.5)
	local v = w2:Join(2, { Class = "Warrior", Faction = "Horns", Level = 5, Tier = 1, Mask = 1, Pos = vec(dx, 0, -dz) })
	w2:Advance(1.2)
	w2:AutoTick()
	check(v.Character:FindFirstChild("Humanoid").Health == 100, "auto never swings at a player", v.Character:FindFirstChild("Humanoid").Health)
end)

finish()
