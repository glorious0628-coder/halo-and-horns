-- goblin_notes_offline.luau : EG06 Goblin Notes (story_depth (나), 게임성 개발 3, 2026-10-10). tools/test_goblin_notes.py binds
-- CONFIG_SOURCE in front of dev2_kit.luau; this file follows. Config only.

local C = execute("Config", CONFIG_SOURCE, nativeEnv())
local N = C.GoblinNotes

runGroup("the notes", function()
	check(N.Title == "Goblin Notes" and #N.Lines == 3, "Config.GoblinNotes: 'Goblin Notes', 3 lines", show(N))
	check(N.Lines[1] == "Fixed: goblins stealing dust. (Not fixed.)" and N.Lines[2] == "Known issue: slimes are squishy. Working as intended."
		and N.Lines[3] == "Goblins now steal 0% more. Same as before.", "the three jokes of the design table (story_depth EG06)", show(N.Lines))
	for i, line in N.Lines do
		check(#line <= 70 and not string.find(line, "\n", 1, true), "note " .. i .. " is one short line (<= 70 letters)", tostring(#line))
	end
end)

runGroup("the weekly pick", function()
	local L = N.Lines
	for _, case in { { 0, 1 }, { 6, 1 }, { 6.9, 1 }, { 7, 2 }, { 13, 2 }, { 14, 3 }, { 20, 3 }, { 21, 1 }, { 28, 2 }, { 35, 3 }, { 21 * 100, 1 },
		{ 21 * 100 + 7, 2 }, { 20000, 1 + math.floor(20000 / 7) % 3 }, { -1, 3 }, { -7, 3 }, { -8, 2 } } do
		check(C.GoblinNote(case[1]) == L[case[2]], "day " .. tostring(case[1]) .. " -> note " .. case[2], tostring(C.GoblinNote(case[1])))
	end
	check(C.GoblinNote(nil) == L[1] and C.GoblinNote("7") == L[1] and C.GoblinNote(0 / 0) == L[1] and C.GoblinNote(math.huge) == L[1]
		and C.GoblinNote(-math.huge) == L[1] and C.GoblinNote({}) == L[1], "a broken day index: the first note, never an error", "")
	-- the real clock of the game: the same note all week, a new one the next KST week
	local day = C.DayIndex(1789959600)
	check(C.GoblinNote(day) == C.GoblinNote(day), "the same day, the same note", "")
	local monday = day - day % 7
	check(C.GoblinNote(monday) == C.GoblinNote(monday + 6) and C.GoblinNote(monday + 6) ~= C.GoblinNote(monday + 7)
		and C.GoblinNote(monday + 7) ~= C.GoblinNote(monday + 14), "7 days the same, then the next note", "")
	check(C.GoblinNote(monday) == C.GoblinNote(monday + 21), "three weeks later the first note again", "")
end)

finish()
