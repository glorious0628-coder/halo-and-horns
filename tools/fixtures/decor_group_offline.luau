-- decor_group_offline.luau : SPEC A23-81 decor that blocks players only (게임성 개발 3, 2026-10-08). tools/test_decor_group.py
-- binds CONFIG_SOURCE, UTIL_SOURCE and SETUP_EXTRACT (PlayerService's collision-group block, cut out) in front of
-- dev2_kit.luau; this file follows. A PhysicsService double keeps the registered groups and a symmetric collidable
-- matrix (pairs never set are collidable, like Roblox).

local function physics(o)
	o = o or {}
	local P = { Groups = { "Default" }, Matrix = {}, Calls = 0 }
	for _, g in o.Pre or {} do table.insert(P.Groups, g) end
	local function key(a, b)
		if a > b then a, b = b, a end
		return a .. "|" .. b
	end
	function P.IsCollisionGroupRegistered(_, name) return table.find(P.Groups, name) ~= nil end
	function P.RegisterCollisionGroup(_, name)
		if o.FailRegister == name then error("offline register failure " .. name) end
		if table.find(P.Groups, name) then error("already registered " .. name) end
		table.insert(P.Groups, name)
	end
	-- o.List = "Names" (default: { name, id, mask } like Roblox) | "NoNames" (an entry shape without names)
	function P.GetRegisteredCollisionGroups(_)
		local out = {}
		for i, g in P.Groups do
			table.insert(out, if o.List == "NoNames" then { id = i - 1, mask = 0 } else { name = g, id = i - 1, mask = 0 })
		end
		return out
	end
	function P.CollisionGroupSetCollidable(_, a, b, v)
		assert(table.find(P.Groups, a) and table.find(P.Groups, b), "unregistered group " .. a .. " / " .. b)
		P.Calls += 1
		P.Matrix[key(a, b)] = v == true
	end
	function P:Collides(a, b)
		local v = self.Matrix[key(a, b)]
		if v == nil then return true end
		return v
	end
	return P
end

local function setup(o)
	local w = newWorld({ EditConfig = o and o.EditConfig })
	local P = physics(o)
	local run = execute("PlayerServiceCollision", SETUP_EXTRACT, w:Env(), P, w.Config, w.Util)
	local ok = run()
	return P, ok, w
end

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	check(C.Player.DecorGroup == "DecorPlayerOnly" and C.Player.CollisionGroup == "Players",
		"Config.Player: DecorGroup DecorPlayerOnly next to Players", tostring(C.Player.DecorGroup))
end)

runGroup("pairs", function()
	local P, ok = setup()
	check(ok == true, "the players' group is set up (collisionGroupOk)", tostring(ok))
	check(P:IsCollisionGroupRegistered("Players") and P:IsCollisionGroupRegistered("DecorPlayerOnly"),
		"both groups registered", table.concat(P.Groups, ","))
	check(P:Collides("DecorPlayerOnly", "Players") == true, "decor x Players: collide (players can't walk through)", "")
	check(P:Collides("DecorPlayerOnly", "Default") == false, "decor x Default: pass (monsters, pets, the rest)", "")
	check(P:Collides("DecorPlayerOnly", "DecorPlayerOnly") == false, "decor x decor: no", "")
	check(P:Collides("Players", "Players") == false, "Players x Players stays off (A7-5)", "")
	check(P:Collides("Players", "Default") == true, "Players x Default untouched (the world still blocks players)", "")
	-- run again (another Start in the same place / the group saved in the place): the same answers, no error
	local P2, ok2 = setup({ Pre = { "Players", "DecorPlayerOnly" } })
	check(ok2 == true and P2:Collides("DecorPlayerOnly", "Players") == true and P2:Collides("DecorPlayerOnly", "Default") == false,
		"groups already registered (saved in the place): same pairs, no error", table.concat(P2.Groups, ","))
end)

runGroup("an unknown list shape", function()
	local P, ok = setup({ List = "NoNames" })
	check(ok == true and P:Collides("DecorPlayerOnly", "Default") == false and P:Collides("DecorPlayerOnly", "DecorPlayerOnly") == false
		and P:Collides("DecorPlayerOnly", "Players") == true,
		"GetRegisteredCollisionGroups without names: Default / itself / Players still set by name", "")
end)

runGroup("other groups", function()
	local P = setup({ Pre = { "Monsters", "Pets" } })
	check(P:Collides("DecorPlayerOnly", "Monsters") == false and P:Collides("DecorPlayerOnly", "Pets") == false,
		"a monster / pet group registered before: decor lets it pass too", "")
	check(P:Collides("Monsters", "Players") == true, "the other groups' own pairs are not touched", "")
	check(P:Collides("DecorPlayerOnly", "Players") == true, "players still blocked", "")
end)

runGroup("failures", function()
	local P, ok, w = setup({ FailRegister = "DecorPlayerOnly" })
	w.AllowWarn = "decor collision group setup failed"
	check(ok == true and P:Collides("Players", "Players") == false, "a decor failure never takes the players' group down", tostring(ok))
	check(#w.Warnings == 1 and string.find(w.Warnings[1], "decor collision group setup failed", 1, true) ~= nil,
		"one warning", tostring(w.Warnings[1]))
	local P2, ok2, w2 = setup({ FailRegister = "Players" })
	w2.AllowWarn = "collision group setup failed"
	check(ok2 == false and P2:Collides("DecorPlayerOnly", "Default") == false,
		"a players' group failure: collisionGroupOk false; decor still set where it can", tostring(ok2))
	local playersWarn = false
	for _, text in w2.Warnings do
		if string.find(text, "[PlayerService] collision group setup failed", 1, true) then playersWarn = true end
	end
	check(playersWarn, "the players' group failure has its own warning", show(w2.Warnings))
end)

finish()
