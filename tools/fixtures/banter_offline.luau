-- banter_offline.luau : ⑫ the Pumpkin King vs Ghost King 9-day banter (docs/design/lines_pack_2026-10-06.md §4).
-- tools/test_banter.py injects CONFIG_SOURCE, UTIL_SOURCE, ANNOUNCE_SOURCE (AnnounceService) and HALLOWEEN_SOURCE (the
-- CURRENT src) in front of dev2_kit.luau; this file follows. The real HalloweenService + AnnounceService run on the kit's
-- Net double (the "Announce" remote's FireAllClients is recorded); MonsterService is a two-function stand-in. Kings come
-- through HalloweenService.DebugSpawn (the same appear / finish path as the schedule; its loop never runs here).

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local B0 = C0.Halloween.Banter
local DAY1 = 1793372400 -- 2026-10-31 00:00 KST
local function at(day, hourKST) return DAY1 + (day - 1) * 86400 + (hourKST or 8) * 3600 end

local function banterWorld(time)
	local w = newWorld({ Time = time })
	-- Config runs with the plain native env (no workspace / os doubles): its season clock reads this world's time
	w.Config.SeasonNow = function() return w.Time end
	local reg = {}
	w.Recs = {}
	reg.MonsterService = {
		SpawnEvent = function(kind)
			local rec = { Kind = kind, Alive = true, HP = 100 }
			table.insert(w.Recs, rec)
			return rec
		end,
		RemoveEvent = function(rec) rec.Alive = false end,
	}
	local ann = w:Load("AnnounceService", ANNOUNCE_SOURCE)
	ann.Init(reg)
	reg.AnnounceService = ann
	local hs = w:Load("HalloweenService", HALLOWEEN_SOURCE)
	hs.Init(reg)
	hs.Start()
	w.Spawned = {} -- the schedule loop never runs here
	w.HS = hs
	return w
end

-- the latest "Announce" broadcast of `key` (payload { Key, Args, Event })
local function sent(w, key)
	for i = #w.Fired, 1, -1 do
		local f = w.Fired[i]
		if f.Remote == "Announce" and f.All and type(f.Payload) == "table" and f.Payload.Key == key then return f.Payload end
	end
	return nil
end
local function expect(kind, line) return string.format(B0.Format, C0.MonsterTypes[kind].Short, line) end
-- the king leaves (HP left) or is beaten (HP 0); the next DebugSpawn closes it the way the tick does
local function gone(rec, beaten)
	rec.Alive = false
	rec.HP = beaten and 0 or 50
end

runGroup("data", function()
	check(type(B0) == "table" and #B0.Days == 9 and B0.DayOneStart == DAY1 and B0.Format == "%s: \"%s\"",
		"Banter: 9 days from 2026-10-31 00:00 KST, Format 'Name: \"line\"'", show(B0 and { #B0.Days, B0.DayOneStart }))
	local percents = 0
	for d, row in B0.Days do
		for _, key in { "PumpkinKing", "GhostKing" } do
			local line = row[key]
			check(type(line) == "string" and line ~= "", "day " .. d .. " " .. key .. ": a line", show(line))
			local _, n = string.gsub(line or "", "%%", "")
			percents += n
			check(n == 0 or (d == 9 and key == "GhostKing" and n == 1 and string.find(line, "%d", 1, true) ~= nil),
				"day " .. d .. " " .. key .. ": no % except the Day 9 Ghost King's %d", line)
			check(not string.find(line or "", "...", 1, true), "day " .. d .. " " .. key .. ": one-glyph ellipsis", line)
		end
	end
	check(percents == 1 and type(B0.GhostKingZero) == "string" and not string.find(B0.GhostKingZero, "%", 1, true),
		"exactly one %d in the whole block, and a zero line", show(percents))
	local ev = C0.Announce.Events
	check(ev.PumpkinKingAppear and ev.GhostKingAppear, "both Appear events still exist (the banter rides on them)")
end)

runGroup("one line per day", function()
	for day = 1, 9 do
		local w = banterWorld(at(day))
		check(w.HS.DebugSpawn("PumpkinKing") == "spawned" and w.HS.DebugSpawn("GhostKing") == "spawned", "day " .. day .. ": both kings come")
		local p, g = sent(w, "PumpkinKingAppear"), sent(w, "GhostKingAppear")
		check(p and p.Event == true and p.Args.Banter == expect("PumpkinKing", B0.Days[day].PumpkinKing),
			"day " .. day .. ": the Pumpkin King's line rides on its Appear broadcast", show(p and p.Args))
		local ghost = day == 9 and B0.GhostKingZero or B0.Days[day].GhostKing
		check(g and g.Args.Banter == expect("GhostKing", ghost), "day " .. day .. ": the Ghost King's line", show(g and g.Args))
	end
	-- KST days: 08:00 KST is still the previous day in UTC; 23:59 KST is the same day
	local early, late = banterWorld(at(4, 8)), banterWorld(DAY1 + 3 * 86400 + 86399)
	early.HS.DebugSpawn("PumpkinKing")
	late.HS.DebugSpawn("PumpkinKing")
	check(sent(early, "PumpkinKingAppear").Args.Banter == expect("PumpkinKing", B0.Days[4].PumpkinKing)
		and sent(late, "PumpkinKingAppear").Args.Banter == expect("PumpkinKing", B0.Days[4].PumpkinKing),
		"11/03 08:00 and 23:59 KST are both Day 4", show({ sent(early, "PumpkinKingAppear").Args, sent(late, "PumpkinKingAppear").Args }))
	-- a test server before the season shows Day 1; after Day 9 stays Day 9
	local before, after = banterWorld(1791342000), banterWorld(at(9) + 5 * 86400)
	before.HS.DebugSpawn("PumpkinKing")
	after.HS.DebugSpawn("PumpkinKing")
	check(sent(before, "PumpkinKingAppear").Args.Banter == expect("PumpkinKing", B0.Days[1].PumpkinKing),
		"before 10/31 (a test server): Day 1", show(sent(before, "PumpkinKingAppear").Args))
	check(sent(after, "PumpkinKingAppear").Args.Banter == expect("PumpkinKing", B0.Days[9].PumpkinKing),
		"after 11/08: Day 9", show(sent(after, "PumpkinKingAppear").Args))
end)

runGroup("day 9: this server's beaten kings", function()
	local w = banterWorld(at(9, 20))
	w.HS.DebugSpawn("GhostKing")
	check(sent(w, "GhostKingAppear").Args.Banter == expect("GhostKing", B0.GhostKingZero), "no king beaten yet: the zero line",
		show(sent(w, "GhostKingAppear").Args))
	w.HS.DebugSpawn("PumpkinKing")
	gone(w.Recs[2], true) -- the Pumpkin King is beaten
	w.HS.DebugSpawn("PumpkinKing") -- closes it (Defeat) and brings the next one
	gone(w.Recs[3], false) -- this one goes home (Leave): not counted
	w.HS.DebugSpawn("PumpkinKing")
	gone(w.Recs[1], true) -- the first Ghost King is beaten
	w.HS.DebugSpawn("GhostKing")
	local line = sent(w, "GhostKingAppear").Args.Banter
	check(line == expect("GhostKing", string.format(B0.Days[9].GhostKing, 2)),
		"two kings beaten (one left home): 'Kings beaten on this server: 2'", line)
	check(sent(w, "PumpkinKingDefeat") ~= nil and sent(w, "PumpkinKingLeave") ~= nil, "the Defeat / Leave lines still go out")
	for _, f in w.Fired do
		local b = type(f.Payload) == "table" and type(f.Payload.Args) == "table" and f.Payload.Args.Banter or nil
		check(b == nil or (not string.find(b, "%d", 1, true) and not string.find(b, "%", 1, true)), "no raw %d ever reaches the chat", b)
	end
end)

finish()
