-- xp_ladder_offline.luau : the XP ladder (Config.XPToNext: EarlyMult below EarlyUntil, then Config.Levels.Ramp; 최종 검수 10/14,
-- the Lv10 cliff). tools/test_xp_ladder.py binds CONFIG_SOURCE and UTIL_SOURCE in front of dev2_kit.luau; this file follows.

runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local L = C.Levels
	check(L.XPBase == 30 and L.XPExponent == 1.4 and L.EarlyUntil == 10 and L.EarlyMult == 0.35, "the curve and the early share unchanged",
		show({ L.XPBase, L.XPExponent, L.EarlyUntil, L.EarlyMult }))
	check(type(L.Ramp) == "table" and L.Ramp[10] == 0.5 and L.Ramp[11] == 0.65 and L.Ramp[12] == 0.8 and L.Ramp[13] == 0.9
		and L.Ramp[9] == nil and L.Ramp[14] == nil, "Ramp: Lv10 0.5, 11 0.65, 12 0.8, 13 0.9", show(L.Ramp))
end)

runGroup("ladder", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local L = C.Levels
	local function full(level) return math.floor(L.XPBase * level ^ L.XPExponent) end
	local want = {}
	for level = 1, 15 do
		local share = level < L.EarlyUntil and L.EarlyMult or L.Ramp[level] or 1
		want[level] = share == 1 and full(level) or math.max(1, math.floor(full(level) * share))
	end
	local bad = {}
	for level = 1, 15 do
		if C.XPToNext(level) ~= want[level] then table.insert(bad, level .. ": " .. C.XPToNext(level) .. " ~= " .. want[level]) end
	end
	check(#bad == 0, "Lv1-15: EarlyMult below 10, the Ramp share at 10-13, the full curve from 14", table.concat(bad, "; "))
	check(C.XPToNext(9) == 227 and C.XPToNext(10) == 376 and C.XPToNext(11) == 559 and C.XPToNext(14) == full(14),
		"Lv9 227 -> Lv10 376 (was 753) -> Lv11 559; Lv14 the full curve", show({ C.XPToNext(9), C.XPToNext(10), C.XPToNext(11), C.XPToNext(14) }))
	local steps = {}
	for level = 9, 14 do table.insert(steps, C.XPToNext(level + 1) / C.XPToNext(level)) end
	local worst = 0
	for _, s in steps do worst = math.max(worst, s) end
	check(worst < 2, "no step from Lv9 to Lv15 is more than x2 the one before (the cliff was x3.3)", show(steps))
	local sum = 0
	for level = 1, 9 do sum += C.XPToNext(level) end
	check(sum == 962, "Lv1 -> Lv10 still needs 962 XP (the first ten minutes unchanged)", sum)
	for level = 14, 100, 7 do
		if C.XPToNext(level) ~= full(level) then table.insert(bad, "Lv" .. level) end
	end
	check(#bad == 0, "every level past the ramp is the full curve", table.concat(bad, ", "))
	check(C.XPToNext(1) >= 1 and C.XPToNext(100) == full(100), "the ends", "")
	L.EarlyMult, L.Ramp[10] = 0.001, 0.0001
	check(C.XPToNext(1) == 1 and C.XPToNext(10) == 1, "a tiny share never makes a level need less than 1 XP", show({ C.XPToNext(1), C.XPToNext(10) }))
end)

finish()
