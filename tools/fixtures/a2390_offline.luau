-- a2390_offline.luau : A23-90 (the ruins' safe ring + Crown Pit PvP area, private-server rewards x0.5), offline.
-- tools/test_a2390.py binds CONFIG / UTIL / PROGRESSION sources, ZoneService's real applyZone (APPLYZONE_EXTRACT) and
-- the texts of the reward sites in front of dev2_kit.luau.

local function v(x, z) return vec(x, 0, z) end

runGroup("config", function()
	local C = newWorld().Config
	local R = C.Zones.SkeletonRuins
	check(R.PvP == false and type(R.PvPArea) == "table" and R.PvPArea.Name == "Crown Pit" and R.PvPArea.LootMult == 1.25,
		"the ruins: no zone PvP, the Crown Pit area (loot x1.25)", show(R.PvPArea))
	local pit = R.PvPArea
	check(math.abs(pit.Center.X - pit.Size.X / 2 - (R.Center.X - R.Size.X / 2)) > 100
		and pit.Center.X + pit.Size.X / 2 <= R.Center.X + R.Size.X / 2
		and math.abs(pit.Center.Z) + pit.Size.Z / 2 <= R.Center.Z + R.Size.Z / 2,
		"the pit is inside the ruins, well away from the west entrance (a safe ring to hunt)")
	check(C.PvPAt(v(1700, 0)) == true and C.PvPAt(pit.Center) == true, "the crown altar / pit centre: PvP")
	check(C.PvPAt(v(1300, 0)) == false and C.PvPAt(R.Spawn) == false and C.PvPAt(v(1520, 250)) == false,
		"the ruins' entrance, spawn and far corner: safe")
	check(C.PvPAt(v(950, 0)) == true and C.PvPAt(v(430, 0)) == false and C.PvPAt(v(0, 0)) == false,
		"the woods still PvP, the meadow and Crossroads safe")
	local edgeX = pit.Center.X - pit.Size.X / 2
	check(C.PvPAt(v(edgeX + 0.5, 0)) == true and C.PvPAt(v(edgeX - 0.5, 0)) == false, "the pit's west edge")
	local edgeZ = pit.Center.Z + pit.Size.Z / 2
	check(C.PvPAt(v(1700, edgeZ - 0.5)) == true and C.PvPAt(v(1700, edgeZ + 0.5)) == false and C.PvPAt(v(1700, 200)) == false,
		"the pit's south edge (north and south of the pit, still in the ruins: safe)")
	check(C.PvPAreaAt(v(1700, 0)) == pit and C.PvPAreaAt(v(950, 0)) == nil and C.PvPAreaAt(v(1300, 0)) == nil,
		"PvPAreaAt: the pit only inside it")
	check(C.ZoneHasPvP(R) and C.ZoneHasPvP(C.Zones.GoblinWoods) and not C.ZoneHasPvP(C.Zones.SlimeMeadow),
		"ZoneHasPvP: ruins (a pit) and woods yes, meadow no")
	local cl = C.FieldBosses.Clatter.Spawn
	check(typeofDouble(cl) == "Vector3" and C.PvPAt(cl) == true and C.ZoneAt(cl).Id == "SkeletonRuins",
		"Captain Clatter's fallback spot is in the pit", show(cl))
	local P = C.PrivateServer
	check(P.RewardMult == 0.5 and P.HalfSources.Event and P.HalfSources.War and P.HalfSources.Bounty
		and not P.HalfSources.Monster and not P.HalfSources.Quest and P.Text == "Rewards are cut in half in private servers",
		"private servers: goose / war / bounty x0.5 (not hunting / quests), the shop line", show(P))
end)

-- ZoneService's real applyZone with doubles
local function zoneWorld(opts)
	local w = newWorld(opts)
	local H = { zoneIds = {}, pvpNow = {}, pvpNoteAt = {}, notes = {}, changed = {}, faction = {} }
	H.notify = function(p, text, kind, sound) table.insert(H.notes, { P = p, Text = text, Kind = kind, Sound = sound }) end
	H.fmt = function(key) return key end
	H.getFaction = function(p) return H.faction[p] or "Halo" end
	H.ZoneService = { ZoneChanged = { Fire = function(_, p, new, old) table.insert(H.changed, { P = p, New = new, Old = old }) end } }
	local apply = execute("applyZone", APPLYZONE_EXTRACT, w:Env(), w.Config, H)
	w.H, w.Apply = H, apply
	function w:Step(p, x, z)
		local pos = v(x, z)
		apply(p, self.Config.ZoneAt(pos), pos)
	end
	return w
end

runGroup("zone PvP follows the position", function()
	local w = zoneWorld()
	local H = w.H
	local p = w:NewPlayer(1)
	w:Step(p, 1300, 0) -- the ruins' entrance
	check(p.Attrs.ZoneId == "SkeletonRuins" and p.Attrs.ZonePvP == false and H.pvpNow[p] == false, "the ruins' ring: ZonePvP false")
	check(#H.notes == 0 and #H.changed == 1, "entering the ring: no PvP line, ZoneChanged once")
	w:Step(p, 1700, 0) -- into the pit (the same zone)
	check(p.Attrs.ZonePvP == true and H.pvpNow[p] == true and H.notes[1] and H.notes[1].Text == "EnteredPvP"
		and H.notes[1].Sound == "None", "into the Crown Pit: ZonePvP true + the PvP line", #H.notes)
	check(H.ZoneService.IsPvPZone(p) == true, "IsPvPZone: in the pit")
	check(#H.changed == 1, "the same zone: no ZoneChanged")
	w:Step(p, 1710, 10)
	check(#H.notes == 1, "moving inside the pit: nothing new")
	w:Step(p, 1300, 0)
	-- 최종 검수 10/15: the "Safe zone." line is deleted with its code
	check(p.Attrs.ZonePvP == false and #H.notes == 1, "back to the ring: ZonePvP false, no 'Safe zone.' line", #H.notes)
	check(H.ZoneService.IsPvPZone(p) == false and #H.changed == 1, "IsPvPZone: the ring; still one ZoneChanged")
	-- A23-130 (server text verdicts 2026-10-11): a Neutral is immune, so no line at all (EnteredPvPNeutral off)
	local n = w:NewPlayer(2)
	H.faction[n] = "Neutral"
	w:Step(n, 1700, 0)
	check(#H.notes == 1 and n.Attrs.ZonePvP == true, "a Neutral entering the pit: ZonePvP true, no line (immune)", #H.notes)
	-- 검수 10/09: the pit's edge is crossed often - one PvP line per 20 s per player
	w:Step(p, 1700, 0)
	check(#H.notes == 1 and p.Attrs.ZonePvP == true, "back into the pit within 20 s: ZonePvP true, no second PvP line", #H.notes)
	w.Clock += 21
	w:Step(p, 1300, 0)
	w:Step(p, 1700, 0)
	check(#H.notes == 2 and H.notes[2].Text == "EnteredPvP", "20 s later: the PvP line again", #H.notes)
	-- even a Config that names the old switch gets no line (the code is gone)
	local s = zoneWorld({ EditConfig = function(c) c.Nudges.EnteredSafe = true end })
	local sp = s:NewPlayer(9)
	s:Step(sp, 1700, 0)
	s:Step(sp, 1300, 0)
	check(#s.H.notes == 1 and s.H.notes[1].Text == "EnteredPvP", "leaving the pit never says 'Safe zone.'", #s.H.notes)
	check(newWorld().Config.Nudges.EnteredSafe == nil and newWorld().Config.Text.EnteredSafe == nil, "the safe-zone switch and words are gone")
	-- the woods (a PvP zone) still work as before
	local q = w:NewPlayer(3)
	w:Step(q, 950, 0)
	check(q.Attrs.ZonePvP == true and q.Attrs.ZoneId == "GoblinWoods", "the woods: PvP")
	w:Step(q, 430, 0)
	check(q.Attrs.ZonePvP == false and q.Attrs.ZoneId == "SlimeMeadow", "the meadow: safe")
end)

-- the real ProgressionService.AddBankGold / PrivateMult
local function progWorld(private)
	local w = newWorld({ PrivateServerId = private and "ps-1" or "" })
	local Signal = w.Util.Signal
	local data = {}
	local ps = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new(), CharacterSpawned = Signal.new() }
	function ps.IsReady() return true end
	function ps.GetData(p) return data[p] end
	function ps.AddStat(p, k, n) data[p][k] = (data[p][k] or 0) + n end
	function ps.SetStat(p, k, n) data[p][k] = n end
	local reg = { PlayerService = ps, MonetizationService = { HasPass = function(p, kind) return w.Pass == kind end },
		MonsterService = { MonsterKilled = Signal.new() } }
	w.AllowWarn = { "missing signal" } -- only Init runs (no Start): other services' signals are not needed
	local prog = w:Load("ProgressionService", PROGRESSION_SOURCE)
	prog.Init(reg)
	w.Prog, w.DataOf = prog, data
	return w
end

runGroup("private servers", function()
	local pub = progWorld(false)
	local p = pub:NewPlayer(1)
	pub.DataOf[p] = { BankGold = 0 }
	check(pub.Prog.PrivateMult() == 1, "a public server: x1")
	check(pub.Prog.AddBankGold(p, 100, "Event") == 100 and pub.Prog.AddBankGold(p, 100, "Bounty") == 100,
		"a public server: the goose / bounty full")
	local w = progWorld(true)
	local q = w:NewPlayer(2)
	w.DataOf[q] = { BankGold = 0 }
	check(w.Prog.PrivateMult() == 0.5, "a private server: x0.5")
	check(w.Prog.AddBankGold(q, 100, "Event") == 50 and w.Prog.AddBankGold(q, 101, "War") == 50
		and w.Prog.AddBankGold(q, 80, "Bounty") == 40, "goose / war chest / bounty gold halved (rounded down)")
	check(w.Prog.AddBankGold(q, 100, "Monster") == 100 and w.Prog.AddBankGold(q, 100, "Quest") == 100
		and w.Prog.AddBankGold(q, 100, "Choice") == 100, "hunting / quests / cards: full")
	check(w.DataOf[q].BankGold == 140 + 300, "the bank got exactly that", w.DataOf[q].BankGold)
	check(w.Prog.AddBankGold(q, 1, "Event") == 0, "1 gold halved is 0 (nothing added)")
	-- the 2x gold pass doubles after the halving
	w.Pass = "Gold2"
	check(w.Prog.AddBankGold(q, 100, "Event") == 100, "with the 2x gold pass: 100 -> 50 -> 100")
	-- the reward sites use those sources (and the goose halves its XP too)
	check(string.find(GOOSE_SOURCE, 'xp = math.floor(xp * (prog and type(prog.PrivateMult) == "function" and tonumber(prog.PrivateMult()) or 1))', 1, true) ~= nil
		and string.find(GOOSE_SOURCE, '"AddBankGold", p, gold, "Event"', 1, true) ~= nil, "the goose: gold 'Event', XP x PrivateMult")
	check(string.find(WAR_SOURCE, 'AddBankGold(player, amount, "War")', 1, true) ~= nil, "the war chests: 'War'")
	local _, bounties = string.gsub(PVP_SOURCE, '"Bounty"%)', "")
	check(bounties >= 3, "the bounties: 'Bounty'", bounties)
	-- the Crown Pit's better drops: the kill info carries the area's LootMult, the rows multiply it
	check(string.find(AREAMULT_TEXT, 'AreaMult = typeof(pos) == "Vector3" and (Config.PvPAreaAt(pos) or {}).LootMult or nil,', 1, true) ~= nil,
		"MonsterService: a kill's info.AreaMult = the PvP area's LootMult")
	check(string.find(ROWBONUS_TEXT, "local rowBonus = num(info.RowBonus, 1) * num(info.AreaMult, 1)", 1, true) ~= nil,
		"LootService: the drop rows x info.AreaMult")
end)

finish()
