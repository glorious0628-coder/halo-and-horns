-- english_offline.luau : A23-48 (user 2026-10-06) the game shows English only. tools/test_english.py injects the
-- CURRENT Config / Util (kit) and SERVER_TEXT = every ServerScriptService script, each after a "=====FILE <name>" line.
-- Checks: (1) no Hangul in any string reachable from the loaded Config (also the ones string.format builds at load),
-- except Config.UIArt (image-dev's block; the baked Korean FactionE cards are off) and the language's own name
-- (Settings.Text.Options.ko / koEn); (2) every X / XEn twin holds the same English (one text, two keys; the Keybinds
-- Auto row is 게임성 개발 1's); (3) glossary names (docs/design/glossary_en_2026-10-06.md); (4) no Hangul in the code
-- part of any server script line, except the nickname policy word lists (NicknameService POLICY + the particle checks).

local function hangul(s)
	if type(s) ~= "string" then return false end
	local ok, found = pcall(function()
		for _, c in utf8.codes(s) do
			if (c >= 0xAC00 and c <= 0xD7A3) or (c >= 0x1100 and c <= 0x11FF) or (c >= 0x3130 and c <= 0x318F) then
				return true
			end
		end
		return false
	end)
	return ok and found
end

local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in a do if not same(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

local w = newWorld({ Studio = false })
local C = w.Config

runGroup("Config strings are English", function()
	local seen, bad, count = {}, {}, 0
	local function walk(v, path)
		if type(v) == "string" then
			count += 1
			if hangul(v) then table.insert(bad, path .. " = " .. v) end
			return
		end
		if type(v) ~= "table" or seen[v] then return end
		seen[v] = true
		for k, x in v do
			local p = path .. "." .. tostring(k)
			local skip = p == "Config.UIArt" or p == "Config.Settings.Text.Options.ko" or p == "Config.Settings.Text.Options.koEn"
			if not skip then walk(x, p) end
		end
	end
	walk(C, "Config")
	check(count > 1500, "the walk reached the player strings (" .. count .. " strings)", tostring(count))
	check(#bad == 0, "no Hangul in any Config string outside the listed exceptions", table.concat(bad, " | "):sub(1, 600))
	check(C.UIArt ~= nil and C.Settings.Text.Options.ko == "한국어", "the exceptions still exist (exact paths)",
		tostring(C.Settings.Text.Options.ko))
end)

runGroup("X / XEn twins hold the same English", function()
	local seen, bad, pairsSeen = {}, {}, 0
	local function walk(t, path)
		if type(t) ~= "table" or seen[t] then return end
		seen[t] = true
		for k, v in t do
			if type(k) == "string" and string.sub(k, -2) ~= "En" then
				local twin = t[k .. "En"]
				if twin ~= nil and (type(v) == "string" or type(v) == "table") then
					local keybindAuto = t.Id == "Auto" and t.Group == "Combat" and (k == "Label" or k == "Button")
					if not keybindAuto then
						pairsSeen += 1
						if not same(v, twin) then table.insert(bad, path .. "." .. k) end
					end
				end
			end
			if type(v) == "table" and not (path == "Config" and k == "UIArt") then walk(v, path .. "." .. tostring(k)) end
		end
	end
	walk(C, "Config")
	check(pairsSeen >= 100, "twins found (" .. pairsSeen .. ")", tostring(pairsSeen))
	check(#bad == 0, "every twin pair is the same text", table.concat(bad, ", "):sub(1, 600))
end)

runGroup("glossary names", function()
	local F, Z, M, I = C.Factions, C.Zones, C.MonsterTypes, C.Loot.Items
	check(F.Halo.Name == "Knights of Light" and F.Horns.Name == "Horn Legion" and F.Neutral.Name == "Artisan Guild",
		"factions: Knights of Light / Horn Legion / Artisan Guild", show({ F.Halo.Name, F.Horns.Name, F.Neutral.Name }))
	check(F.Halo.TeamName == F.Halo.Name and F.Horns.TeamName == F.Horns.Name and F.Neutral.TeamName == F.Neutral.Name,
		"team names = faction names", show({ F.Halo.TeamName, F.Horns.TeamName, F.Neutral.TeamName }))
	check(C.ClassName("Warrior", "Neutral") == "Blacksmith" and C.ClassName("Mage", "Neutral") == "Alchemist"
		and C.ClassName("Archer", "Neutral") == "Pet Tamer", "artisan classes: Blacksmith / Alchemist / Pet Tamer",
		show({ C.ClassName("Warrior", "Neutral"), C.ClassName("Mage", "Neutral"), C.ClassName("Archer", "Neutral") }))
	check(C.ClassName("Archer", "Halo") == "Ranger" and C.ClassName("Archer", "Horns") == "Shadow Hunter"
		and C.ClassName("Warrior", "None") == "Warrior" and C.ClassName("Mage", "None") == "Mage"
		and C.ClassName("Archer", "None") == "Archer", "Ranger / Shadow Hunter / Warrior / Mage / Archer",
		show({ C.ClassName("Archer", "Halo"), C.ClassName("Archer", "Horns") }))
	local zones = { Crossroads = "Crossroads", SlimeMeadow = "Squishy Meadow", GoblinWoods = "Goblin Woods",
		SkeletonRuins = "Skeleton Ruins", HaloTown = "Halo Citadel", HornsTown = "Horns Den", PumpkinPatch = "Pumpkin Patch" }
	for id, name in zones do
		check(Z[id].Name == name, "zone " .. id .. " = " .. name, tostring(Z[id].Name))
	end
	for _, d in C.Travel.Destinations do
		if d.Id ~= "Home" then check(d.Name == Z[d.Id].Name, "travel " .. d.Id .. " = the zone name", tostring(d.Name)) end
	end
	local mons = { Slime = "Slime", BigSlime = "Slime Prince", SlimeKing = "King Slime", Goblin = "Goblin", GoblinBrute = "Goblin Brute",
		Skeleton = "Skeleton", SkeletonKnight = "Skeleton Knight", PumpkinSlime = "Pumpkin Slime", LittleGhost = "Little Ghost",
		BatGoblin = "Bat Goblin", PumpkinKing = "Pumpkin King" }
	for id, name in mons do
		check(M[id].Short == name, "monster " .. id .. " = " .. name, tostring(M[id].Short))
	end
	local items = { Jelly = "Jelly", SlimeCore = "Slime Core", GoblinTooth = "Goblin Tooth", BruteHorn = "Brute Horn",
		Bone = "Old Bone", KnightCrest = "Rusty Knight Crest", Candy = "Candy", Enh70 = "Enhance Scroll 70%",
		Move70 = "Transfer Scroll 70%" }
	for id, name in items do
		check(I[id].Name == name, "item " .. id .. " = " .. name, tostring(I[id].Name))
	end
	local hero
	for _, a in C.Keybinds.Actions do if a.Id == "Character" then hero = a end end
	check(hero and hero.Label == "Hero", "the character window is 'Hero'", show(hero))
	check(C.Power.Text.Label == "Power" and C.Tamer.Text.PetName == "Baby Slime" and C.Leaderstats.Names.Power == "Power",
		"Power / Baby Slime", show({ C.Power.Text.Label, C.Tamer.Text.PetName }))
	check(C.Ranking.Text.BoardNames.Honor == "Honor" and C.Ranking.Text.BoardNames.Infamy == "Infamy"
		and C.Ranking.Text.BoardNames.Artisan == "Artisan Fame", "Honor / Infamy / Artisan Fame", show(C.Ranking.Text.BoardNames))
	check(C.Game.Name == "Halo & Horns", "the game is 'Halo & Horns'", tostring(C.Game.Name))
	check(C.Announce.Text.Honorific == "", "no honorific after names in English lines", tostring(C.Announce.Text.Honorific))
	check(string.format(C.Announce.Text.HiddenName, F.Horns.Name) == "A member of the Horn Legion",
		"a hidden name reads 'A member of the Horn Legion'", string.format(C.Announce.Text.HiddenName, F.Horns.Name))
end)

-- ⑪ (lines_pack §1): the five people you always meet have names; quest / help / system lines keep the role
runGroup("the five names", function()
	local W, SQ = C.Tutorial.Welcome, C.StoryQuests
	local want = {
		Halo = { "Hallie", "Guide of Light", "Hallie here! Now you know my name. Welcome to the Knights!", "Hallie here! Now you know my name." },
		Horns = { "Magpie", "Horn Legion Guide", "Finders keepers! HA! You're with us now. I'm Magpie.", "Finders keepers! HA!" },
		Neutral = { "Kit", "Guild Guide", "Fix first. Talk later. I'm Kit. Welcome to the Guild!", "Fix first. Talk later." },
	}
	local m14 = SQ.Defs.M1_4.Steps[2].Lines
	for f, v in want do
		check(W[f].Name == v[1] and W[f].Title == v[2], f .. " guide: " .. v[1] .. " (" .. v[2] .. ")", show({ W[f].Name, W[f].Title }))
		-- 3rd idea round #2 (검수 2026-10-07): page 1 = the mission card, the catchphrase opens page 2
		check(W[f].Lines[2] == v[3] and #W[f].Lines == 2, f .. ": the catchphrase is the welcome's page 2, and the last (two pages only)", show(W[f].Lines))
		-- A23-74 (user 2026-10-07): the weapon first, then the hunt
		check(W[f].Lines[1] == "First, get a weapon from Otto the Blacksmith!\nThen beat 5 slimes to free the supply road.",
			f .. ": page 1 = the mission card (the Blacksmith's weapon first, then 5 slimes)", show(W[f].Lines[1]))
		check(m14[f][1] == v[4], f .. ": the catchphrase opens the M1_4 report", show(m14[f][1]))
		for _, line in W[f].Lines do
			check(not string.find(line, "Noted", 1, true) and not string.find(line, "Captain", 1, true),
				f .. ": no 'Noted' (Tiny's) or 'Captain'", line)
		end
	end
	check(SQ.Speakers.Smith == "Otto" and SQ.Speakers.Guild == "Kit" and SQ.Speakers.Potion == "Fizzby",
		"speakers: Otto / Kit / Fizzby", show({ SQ.Speakers.Smith, SQ.Speakers.Guild, SQ.Speakers.Potion }))
	check(string.find(SQ.Defs.M1_1.Finish, "Otto: Clang, clang… done. Cocoa time.\n", 1, true) == 1, "M1_1: Otto's catchphrase line first",
		SQ.Defs.M1_1.Finish)
	check(string.sub(SQ.Defs.N1.Start, 1, 5) == "Kit: " and string.sub(SQ.Defs.N2.Start, 1, 5) == "Kit: ", "N1 / N2: Kit speaks",
		show({ SQ.Defs.N1.Start, SQ.Defs.N2.Start }))
	local T = SQ.Text
	check(string.format(T.OffSideHalo, 2) == "Hallie: Hmm… not very angel-like! Honor -2"
		and string.format(T.OffSideHorns, 2) == "Magpie: Too nice for a devil! Your call. Infamy -2",
		"the off-side line is said by the guide (one toast, ASCII minus)", show({ T.OffSideHalo, T.OffSideHorns }))
	check(C.Vitals.PotionMerchantLabel == "Fizzby" and C.Vitals.PotionMerchantName == "PotionMerchant",
		"the potion seller's prompt says Fizzby (the model name stays)", show({ C.Vitals.PotionMerchantLabel, C.Vitals.PotionMerchantName }))
	check(C.Text.ForgeGreeting == "Otto: Clang, clang… done. Cocoa time." and C.Text.PotionGreeting == "Fizzby: Glug, glug, feel better!",
		"the shop greetings", show({ C.Text.ForgeGreeting, C.Text.PotionGreeting }))
	-- the role stays in system lines (a kid finds the place by its role)
	check(string.find(C.Text.WeaponFromQuest, "The Blacksmith", 1, true) ~= nil and C.Text.BlacksmithPromptObject == "Forge"
		and string.find(C.Text.PotionShopFar, "Potion Seller", 1, true) ~= nil
		and string.find(C.Loot.Text.FirstWeaponBag, "The Blacksmith", 1, true) ~= nil,
		"system lines keep 'The Blacksmith' / 'Forge' / 'Potion Seller'", show({ C.Text.WeaponFromQuest, C.Text.PotionShopFar }))
	check(string.find(SERVER_TEXT, "prompt.ObjectText = \"Buy potions\", tune.PotionMerchantLabel", 1, true) ~= nil,
		"MapBuilder's potion prompt reads Config.Vitals.PotionMerchantLabel")
end)

runGroup("server scripts send English", function()
	local files, current, bad, lines = 0, nil, {}, 0
	local inPolicy = false
	for line in string.gmatch(SERVER_TEXT .. "\n", "([^\n]*)\n") do
		local name = string.match(line, "^=====FILE (.+)$")
		if name then
			current, files, inPolicy = name, files + 1, false
		else
			lines += 1
			if current == "NicknameService.luau" and string.find(line, "^local POLICY = {") then inPolicy = true end
			local exempt = inPolicy
				or (current == "NicknameService.luau" and string.find(line, 'target .. "', 1, true) ~= nil)
			if inPolicy and line == "}" then inPolicy = false end
			local code = string.match(line, "^(.-)%-%-") or line
			if not exempt and hangul(code) then table.insert(bad, current .. ": " .. string.gsub(line, "^%s+", "")) end
		end
	end
	check(files >= 30 and lines > 10000, "every server script was scanned (" .. files .. " files)", tostring(files))
	check(#bad == 0, "no Hangul in server code outside the nickname word lists", table.concat(bad, " | "):sub(1, 600))
end)

finish()
