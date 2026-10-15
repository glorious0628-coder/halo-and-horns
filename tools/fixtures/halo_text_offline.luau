-- halo_text_offline.luau : Halo town text pass (zone_check_halo_2026-10-10 #44 / #55 + the two-page welcome), 게임성 개발 3.
-- tools/test_halo_text.py binds CONFIG_SOURCE in front of dev2_kit.luau; this file follows. Config only, no services.

local C = execute("Config", CONFIG_SOURCE, nativeEnv())
local TC = C.Tutorial
local SQ = C.StoryQuests

-- every string inside a table (except under the keys in `skip`), so a word can be searched in a whole quest
local function strings(t, skip, out)
	out = out or {}
	for k, v in t do
		if not (skip and skip[k]) then
			if type(v) == "string" then
				table.insert(out, v)
			elseif type(v) == "table" then
				strings(v, skip, out)
			end
		end
	end
	return out
end

local function hasWord(list, word)
	for _, s in list do
		if string.find(string.lower(s), "%f[%a]" .. word .. "%f[%A]") then return s end
	end
	return nil
end

runGroup("#44 the Forge row", function()
	check(TC.Text.Forge == "Go to Otto's Forge in the Crossroads", "the first-mission row says where the Forge is", TC.Text.Forge)
	check(TC.ShortNames.Forge == "To the Forge" and #TC.ShortNames.Forge <= 14, "the phone name stays short", TC.ShortNames.Forge)
	check(#TC.Text.Forge <= 40, "the row stays one short line (<= 40 letters)", tostring(#TC.Text.Forge))
	check(string.find(TC.Text.ForgeGift, "Squishy Meadow is next", 1, true) ~= nil, "Otto's line is unchanged", TC.Text.ForgeGift)
end)

runGroup("#55 the Sprout Promise", function()
	local D = SQ.Defs
	-- A23-138: the Horns kid is shown as Rose; her speaker id stays "Smokey" (Speakers.Smokey = "Rose")
	for _, case in { { "OathH", "Bright", "Halo", "Bright" }, { "OathR", "Rose", "Horns", "Smokey" } } do
		local id, who, side = case[1], case[2], case[3]
		local d = D[id]
		check(d.Title == "The Sprout Promise" and d.ShortName == "Sprout promise" and #d.ShortName <= 14, id .. ": title + phone name say 'promise'",
			show({ d.Title, d.ShortName }))
		local last = d.Steps[#d.Steps]
		check(last.Text == "Make your promise to " .. who, id .. ": the last step is 'Make your promise to " .. who .. "'", last.Text)
		local line = last.Lines.All[1]
		check(string.find(line, "Make your promise.", 1, true) ~= nil and string.sub(line, 1, #who + 2) == who .. ": ", id .. ": " .. who .. "'s line asks for the promise", line)
		local found = hasWord(strings(d, { Finish = true }), "oath")
		check(found == nil, id .. ": no 'oath' in the title, steps, lines or start (except the closing line)", tostring(found))
		check(d.Factions[side] == true and d.Speaker == case[4] and (SQ.Speakers[d.Speaker] or d.Speaker) == who,
			id .. ": still " .. side .. "'s, spoken by " .. who, show({ d.Factions, d.Speaker }))
		check(d.Reward.TitleBy.Good == "GuardianCadet" and d.Reward.TitleBy.Evil == "RascalCadet" and C.TitleDefs.GuardianCadet and C.TitleDefs.RascalCadet,
			id .. ": the two cadet titles are unchanged", show(d.Reward))
	end
end)

runGroup("#55 Dusty Heroes", function()
	local h6 = SQ.Defs.H6
	check(h6.Steps[1].Text == "Look at the hero statues in Halo Citadel %d/%d s", "H6 step 1 says where the statues are", h6.Steps[1].Text)
	check(string.find(h6.Start, "hero statues are dusty", 1, true) ~= nil and h6.Steps[1].Obj.Spot == "HeroStatue", "H6's start line and spot are unchanged", h6.Start)
	check(string.format(h6.Steps[1].Text, 4, 10) == "Look at the hero statues in Halo Citadel 4/10 s", "the row still formats (%d/%d s)", "")
end)

runGroup("Hallie's catchphrase stays", function()
	local halo = TC.Welcome.Halo
	-- 사용자 10/15 (fix/welcome-order): page 1 = the guide's own hello, page 2 = the mission
	check(halo.Name == "Hallie" and halo.Lines[1] == "Hallie here! Now you know my name. Welcome to the Knights!", "Hallie opens page 1 of her welcome", show(halo.Lines))
	-- (quest P1 ⑦: M1_4 is the lamp now - the guide's chapter-1 report and its catchphrase line left with it)
	local payoff = hasWord(strings(SQ.Defs.M3_5), "mine")
	check(payoff ~= nil and string.find(payoff, "So now I give mine", 1, true) ~= nil, "its payoff line in M3_5 is still there", tostring(payoff))
end)

runGroup("two-page welcome", function()
	for _, side in { "Halo", "Horns", "Neutral" } do
		local w = TC.Welcome[side]
		check(#w.Lines == 2, side .. ": two pages (the catchphrase, the mission card)", tostring(#w.Lines))
		check(w.Lines[2] == "First, go to Otto's Forge and get your weapon!", side .. ": page 2 = the mission card (A23-188: the Forge visit)",
			w.Lines[2])
		check(#w.Lines[1] > 0 and #w.Lines[1] <= 80 and not string.find(w.Lines[1], "\n", 1, true), side .. ": page 1 = one short catchphrase line", w.Lines[1])
		for _, line in w.Lines do check(#line <= 100, side .. ": a page is at most 100 letters", tostring(#line)) end
		check(not hasWord(w.Lines, "oath") and not hasWord(w.Lines, "oaths"), side .. ": no 'oath' in the welcome", "")
	end
	check(TC.Welcome.Horns.Lines[1] == "Finders keepers! HA! You're with us now. I'm Magpie." and TC.Welcome.Neutral.Lines[1] == "Fix first. Talk later. I'm Kit. Welcome to the Guild!",
		"Magpie's and Kit's catchphrases are unchanged (page 1)", show({ TC.Welcome.Horns.Lines[1], TC.Welcome.Neutral.Lines[1] }))
end)

finish()
