-- slime_prince_offline.luau : A23-84 BigSlime's screen name = 'Slime Prince' (게임성 개발 3, 2026-10-08).
-- tools/test_slime_prince.py binds CONFIG_SOURCE in front of dev2_kit.luau; this file follows. Texts only: every
-- objective that counted the old King Slime still counts BigSlime (the first 10 minutes stay the same).

local C = execute("Config", CONFIG_SOURCE, nativeEnv())
local DEFS = C.StoryQuests.Defs

-- every string in Config with its path (shared sub-tables once)
local function strings()
	local out, seen = {}, {}
	local function walk(node, path)
		if seen[node] then return end
		seen[node] = true
		for k, v in node do
			local p = path .. "." .. tostring(k)
			if type(v) == "string" then
				table.insert(out, { Path = p, Text = v })
			elseif type(v) == "table" then
				walk(v, p)
			end
		end
	end
	walk(C, "Config")
	return out
end

-- the BigSlime steps of a story quest (id) as { index, step }
local function princeSteps(id)
	local out = {}
	for i, st in (DEFS[id] and DEFS[id].Steps) or {} do
		if type(st.Obj) == "table" and st.Obj.Kind == "BigSlime" then table.insert(out, { i, st }) end
	end
	return out
end

local function template(id)
	for _, t in C.Quests.Templates do if t.Id == id then return t end end
	return nil
end

runGroup("names", function()
	local m = C.MonsterTypes.BigSlime
	check(m.Name == "Slime Prince" and m.Short == "Slime Prince", "BigSlime = 'Slime Prince' (nametag + quest / board / daily name)",
		show({ m.Name, m.Short }))
	check(C.MonsterTypes.Slime.Short == "Slime", "the green Shard Slime keeps its name", tostring(C.MonsterTypes.Slime.Short))
	local kill = template("Kill")
	local daily = C.Plural(string.format(kill.Text, tostring(m.Short or m.Name), 3))
	check(string.find(daily, "Slime Prince", 1, true) ~= nil, "the rookie daily row reads 'Slime Prince'", daily)
end)

runGroup("no King Slime left", function()
	-- allowed: the new boss's own entries (a path with SlimeKing), a story quest that counts SlimeKing, the hill's name
	local kingQuests = {}
	for id, def in DEFS do
		for _, st in def.Steps or {} do
			if type(st.Obj) == "table" and st.Obj.Kind == "SlimeKing" then kingQuests[id] = true end
		end
	end
	local bad, seen = {}, 0
	for _, e in strings() do
		local low = string.gsub(string.lower(e.Text), "king slime hill", "")
		if string.find(low, "king slime", 1, true) or string.find(low, "the king who ate", 1, true) then
			local allowed = string.find(e.Path, "SlimeKing", 1, true) ~= nil
			-- the finisher card is the King Slime boss's only (Config.Finisher.Kinds = { SlimeKing }, 게임성 개발 2)
			if string.find(e.Path, "Finisher.Text.", 1, true) and C.Finisher.Kinds.SlimeKing and not C.Finisher.Kinds.BigSlime then
				allowed = true
			end
			for id in kingQuests do
				if string.find(e.Path, ".Defs." .. id .. ".", 1, true) then allowed = true end
			end
			-- A23-127 (plan 10/13 §1-A #2): the iron weapon is the real King Slime's first drop (Config.MonsterTypes.SlimeKing):
			-- the drop goal + its short name, the tier-3 source line (게임성 개발 1), the first King's weapon lines (게임성 개발 2)
			for _, p in { "Config.Tutorial.Text.NextIronDrop", "Config.Tutorial.ShortNames.IronDrop", "Config.WeaponInfo.3.Source",
				"Config.Loot.Text.FirstKingWeapon", "Config.Loot.Text.FirstKingEquip",
				"Config.ClientText.QuestTarget.King" } do -- A23-222: M1_2's King's hill / rematch mark (the real King Slime)
				if e.Path == p then allowed = true end
			end
			if not allowed then table.insert(bad, e.Path .. " = " .. e.Text) end
		end
		seen += 1
	end
	table.sort(bad)
	check(seen > 1000 and #bad == 0, "no game text calls the Slime Prince 'King Slime' (" .. seen .. " strings)", table.concat(bad, " | "))
end)

runGroup("quest texts", function()
	local want = { S0 = 1, M1_1 = 1, M2_6 = 1, H1 = 1, XR1 = 1, R5 = 1 }
	for id, n in want do
		local steps = princeSteps(id)
		local named = 0
		for _, pair in steps do
			if string.find(pair[2].Text or "", "Slime Prince", 1, true) then named += 1 end
		end
		check(named >= n, id .. ": its Slime Prince step says 'Slime Prince'", show(steps))
	end
	-- A23-222 (user 10/16): M1_1 = the Slime Prince only (one step); M1_2 is the King's Hop (the real King Slime, not a second
	-- Prince) and the two-colour band is found at its anvil step (5) in the player's own words (no Otto card)
	local m2 = DEFS.M1_2
	local anvil = m2 and m2.Steps[5]
	check(#DEFS.M1_1.Steps == 1 and DEFS.M1_1.Finish == nil and m2 ~= nil and m2.Title == "The King's Hop"
		and anvil ~= nil and anvil.Anvil == true and string.find(anvil.Find or "", "two colors", 1, true) ~= nil,
		"M1_1 = the Prince only; M1_2 = the King's Hop, its anvil step finds the two-colour band (my own words, no Otto card)",
		show({ #DEFS.M1_1.Steps, m2 and m2.Title, anvil and anvil.Find }))
	local princeInM12 = false
	for _, st in (m2 and m2.Steps or {}) do
		if type(st.Obj) == "table" and st.Obj.Kind == "BigSlime" then princeInM12 = true end
	end
	check(not princeInM12, "M1_2 counts no Slime Prince (one more Prince felt like a repeat)", show(m2 and m2.Steps))
	local s0 = princeSteps("S0")[1][2]
	check(string.find(s0.Start or "", "A Slime Prince swallowed a shard!", 1, true) ~= nil, "S0: a Slime Prince swallowed the shard",
		tostring(s0.Start))
	-- 10/16 (story ch2 data, 81f00277): H1's old Start line ("Slime Princes gobbled ...") became Bright's Offer lines
	local h1 = DEFS.H1
	local h1Lines = table.concat((h1.Offer and h1.Offer.Lines and h1.Offer.Lines.All) or {}, " ")
	check(string.find(h1Lines, "two princes", 1, true) ~= nil and string.find(string.lower(h1Lines), "king slime", 1, true) == nil,
		"H1: Bright's offer asks to calm two princes (no 'King Slime')", h1Lines)
	local tiny = DEFS.XR1.Steps[princeSteps("XR1")[1][1] - 1]
	check(tiny and tiny.Lines and string.find(tiny.Lines.All[1], "Tiny: A Slime Prince swallowed a teddy bear!", 1, true) ~= nil,
		"XR1: Tiny's line names the Slime Prince", show(tiny and tiny.Lines))
	check(string.find(DEFS.R5.Start or "", "A Slime Prince is wearing my sack", 1, true) ~= nil, "R5: Smokey's line", tostring(DEFS.R5.Start))
end)

runGroup("the family (A23-84 / A23-85)", function()
	local odd = {}
	for _, e in strings() do
		if string.find(e.Text, "Slime Prince", 1, true) then
			local low = string.lower(e.Text)
			for _, w in { "mom", "mother", "mommy", "queen", "wife", "normal family" } do
				if string.find(low, "%f[%a]" .. w .. "%f[%A]") then table.insert(odd, e.Path) end
			end
		end
	end
	check(#odd == 0, "the slime family is the dad + his kids: no mom / queen line", table.concat(odd, ", "))
end)

runGroup("objectives unchanged (the first 10 minutes)", function()
	local function count(id) local n = 0; for _, p in princeSteps(id) do n += p[2].Obj.Count or 1 end; return n end
	check(count("S0") >= 1 and count("M1_1") == 1 and count("M2_6") == 2 and count("XR1") == 1 and count("R5") == 1
		and count("H1") >= 1, "S0 / M1_1 (one Prince, 10/15: no M1_2) / M2_6 / H1 / XR1 / R5 still count BigSlime",
		show({ count("S0"), count("M1_1"), count("M2_6"), count("H1"), count("XR1"), count("R5") }))
	check(C.Loot.FirstScroll.Monster == "BigSlime", "the first 70% scroll still drops from the first Slime Prince",
		tostring(C.Loot.FirstScroll.Monster))
	check(C.Board.Boards.Meadow.Big == "BigSlime", "the meadow board's big job is the Slime Prince", tostring(C.Board.Boards.Meadow.Big))
	local row
	for _, r in C.Quests.Newbie.Dailies do if r.Monster == "BigSlime" then row = r end end
	check(row and row.Id == "Kill" and row.Strict == true and row.Targets[1] == 3 and #row.Targets == 1,
		"the rookie daily: 3 Slime Princes (strict)", show(row))
	check(C.MonsterTypes.BigSlime.HP == 40 and C.MonsterTypes.BigSlime.Count == 4, "the Slime Prince's numbers stay",
		show({ C.MonsterTypes.BigSlime.HP, C.MonsterTypes.BigSlime.Count }))
end)

finish()
