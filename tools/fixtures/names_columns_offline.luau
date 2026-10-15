-- BB37 (AnnounceService.PublicName: one name for every server-wide line) and BB12 (Tab list columns), run offline.
-- tools/test_names_columns.py injects (before tools/fixtures/dev2_kit.luau): CONFIG_SOURCE, UTIL_SOURCE,
-- ANNOUNCE_SOURCE (whole AnnounceService), PVP_SOURCE (whole PvPService), LEADERSTATS_SOURCE (PlayerService toInt /
-- COLUMN / buildLeaderstats + its LEADERSTAT_KEYS line) and HELPER_<Service> (the publicName helper cut from
-- PvPService, GrudgeService, ProgressionService, GooseService and KaijuService).

local C = execute("Config", CONFIG_SOURCE, nativeEnv())
-- A23-48: the shipped English Honorific is "" (checked in public-name). Here a visible marker stands in for it, in this
-- copy and in every world below, so the honorific flag plumbing (PublicName(p, true), the publicName helpers) stays
-- observable to the checks and the mutations.
local SHIPPED_HONORIFIC = C.Announce.Text.Honorific
local MARK = "~h"
C.Announce.Text.Honorific = MARK
local T = C.Announce.Text
local HALO, HORNS, NEUTRAL = C.Factions.Halo.Name, C.Factions.Horns.Name, C.Factions.Neutral.Name

-- a server world with the real AnnounceService and a PlayerService double (data rows per player)
local function announceWorld(opts)
	opts = opts or {}
	opts.EditConfig = opts.EditConfig or function(config) config.Announce.Text.Honorific = MARK end
	local w = newWorld(opts)
	local data = {}
	w.Data = data
	local ps = { PlayerReady = w.Util.Signal.new(), PlayerLeaving = w.Util.Signal.new(), CharacterSpawned = w.Util.Signal.new() }
	ps.GetData = function(p) return data[p] end
	ps.IsReady = function(p) return w.Ready[p] == true end
	ps.GetReadyPlayers = function()
		local out = {}
		for _, p in w.PlayerList do if w.Ready[p] then table.insert(out, p) end end
		return out
	end
	ps.SetStat = function(p, key, value)
		local d = data[p]
		if not d then return end
		d[key] = value
		if table.find(w.Config.Data.Mirrored, key) then p:SetAttribute(key, value) end
	end
	ps.AddStat = function(p, key, delta) ps.SetStat(p, key, (tonumber((data[p] or {})[key]) or 0) + delta) end
	w.PS = ps
	w.HideCalls = {}
	local registry = { PlayerService = ps, ClassService = { GetClass = function() return "Warrior" end } }
	if opts.Ranking ~= false then
		registry.RankingService = { MarkHideChanged = function(p)
			table.insert(w.HideCalls, p)
			if opts.RankingThrows then error("ranking offline failure") end
		end }
	end
	w.Registry = registry
	local announce = w:Load("AnnounceService", ANNOUNCE_SOURCE)
	registry.AnnounceService = announce
	announce.Init(registry)
	announce.Start()
	w.Announce = announce
	-- a ready player: nick = verified game nickname (nil = Roblox DisplayName), hide = saved choice (nil = no data)
	function w:Player(userId, faction, nick, hide)
		local p = self:NewPlayer(userId, { Faction = faction })
		if nick then
			p:SetAttribute("Nickname", nick)
			p:SetAttribute("NicknameVerified", true)
		end
		if hide ~= nil then
			data[p] = { HideAnnounceName = hide, Faction = faction, Level = 10 }
			p:SetAttribute("HideAnnounceName", hide)
			self.Ready[p] = true
		end
		return p
	end
	return w
end

------------------------------------------------------------------ 1. PublicName
runGroup("public-name", function()
	local w = announceWorld()
	local PN = w.Announce.PublicName
	local shown = w:Player(1, "Halo", "용감한기사", false)
	local hiddenHalo = w:Player(2, "Halo", "숨은기사", true)
	local hiddenHorns = w:Player(3, "Horns", "숨은뿔", true)
	local hiddenNeutral = w:Player(4, "Neutral", "숨은장인", true)
	local hiddenNone = w:Player(5, "None", "숨은새내기", true)
	local noNick = w:Player(6, "Horns", nil, false)
	check(PN(shown) == "용감한기사", "shown: the verified game nickname", PN(shown))
	check(SHIPPED_HONORIFIC == "", "the shipped Text.Honorific is \"\" (English lines add nothing after a name)", SHIPPED_HONORIFIC)
	check(PN(shown, true) == "용감한기사" .. T.Honorific, "shown + honorific: nickname .. Text.Honorific", PN(shown, true))
	check(PN(noNick) == "P6", "no verified nickname: the Roblox DisplayName (Util.PlayerDisplayName)", PN(noNick))
	check(PN(hiddenHalo) == string.format(T.HiddenName, HALO) and PN(hiddenHalo) == "A member of the Knights of Light",
		"hidden Halo: \"A member of the Knights of Light\" (contract text)", PN(hiddenHalo))
	check(PN(hiddenHalo, true) == string.format(T.HiddenName, HALO), "hidden + honorific: nothing added after the hidden name", PN(hiddenHalo, true))
	check(PN(hiddenHorns) == string.format(T.HiddenName, HORNS), "hidden Horns: \"A member of the Horn Legion\"", PN(hiddenHorns))
	check(PN(hiddenNeutral) == string.format(T.HiddenName, NEUTRAL), "hidden Neutral: \"A member of the Artisan Guild\"", PN(hiddenNeutral))
	check(PN(hiddenNone) == T.Someone, "hidden without a faction: Text.Someone (\"Someone\")", PN(hiddenNone))
	for _, p in { hiddenHalo, hiddenHorns, hiddenNeutral, hiddenNone } do
		check(not has(PN(p, true), p:GetAttribute("Nickname")) and not has(PN(p), p.DisplayName),
			"a hidden name never contains the nickname or the Roblox name", PN(p))
	end
	-- the saved choice wins over a stale attribute; without data the mirrored attribute decides
	local stale = w:Player(7, "Halo", "속성만숨김", false)
	stale:SetAttribute("HideAnnounceName", true)
	check(PN(stale) == "속성만숨김", "data.HideAnnounceName = false wins over a stale attribute", PN(stale))
	local loading = w:Player(8, "Horns", "로딩중", nil)
	loading:SetAttribute("HideAnnounceName", true)
	check(PN(loading) == string.format(T.HiddenName, HORNS), "no data yet: the mirrored HideAnnounceName attribute hides", PN(loading))
	check(PN(nil) == "" and PN({}) == "" and PN("P1") == "", "not a Player: \"\"")
	check(type(T.HiddenNameEn) == "string" and type(T.SomeoneEn) == "string" and type(T.SettingLabelEn) == "string"
		and #T.SettingNotes == 2 and #T.SettingNotesEn == 2, "Config.Announce.Text keeps KO/EN pairs for the new lines")
	check(T.SettingLabel == "Hide my name in announcements and rankings", "setting label 'Hide my name in announcements and rankings'",
		T.SettingLabel)
	check(has(T.SettingNotes[1], "Nametags") and has(T.SettingNotes[1], "Tab") and has(T.SettingNotes[2], "A member of the"),
		"setting notes: nametags/Tab cannot be hidden; global rankings show 'A member of the <side>' when hidden")
	-- the chat announce payload (who) still hides the same players
	w.Announce.Announce(hiddenHalo, "FirstMax", { Weapon = 3 }, "Rare")
	local last = w.Fired[#w.Fired]
	check(last and last.Payload.Args.Hidden == true and last.Payload.Args.Who == "", "Announce payload: hidden player -> Who \"\"", show(last and last.Payload))
end)

------------------------------------------------------------------ 2. the server-wide lines read right both ways
runGroup("announce-lines", function()
	local w = announceWorld()
	local PN = w.Announce.PublicName
	local shown = w:Player(1, "Halo", "용감한기사", false)
	local hidden = w:Player(2, "Horns", "숨은뿔", true)
	local lines = {
		{ "MostWanted", "Most Wanted: %s", { "1,200" } },
		{ "BountyAnnounce", "] %s got a", { "300" } },
		{ "GrudgeAvengedAll", "%s took the Grudge Sack back from %s", nil }, -- glossary case (검수 2026-10-07)
		{ "RebirthAnnounce", "%s was reborn", { 2 } },
		{ "RareAnnounce", "%s got a rare", nil },
	}
	for _, l in lines do
		local key, args = l[1], l[3] or {}
		local fmt = C.Text[key]
		check(type(fmt) == "string" and has(fmt, l[2]), key .. " reads with the name as the subject (English)", fmt)
		check(not has(fmt, "님") and not has(fmt, "이(가)"), key .. " has no Korean honorific / particle left", fmt)
		local a = key == "GrudgeAvengedAll" and { PN(shown, true), PN(hidden, true) } or { PN(shown, true), table.unpack(args) }
		local b = key == "GrudgeAvengedAll" and { PN(hidden, true), PN(shown, true) } or { PN(hidden, true), table.unpack(args) }
		local ta, tb = string.format(fmt, table.unpack(a)), string.format(fmt, table.unpack(b))
		check(has(ta, "용감한기사" .. T.Honorific .. " ") and has(tb, string.format(T.HiddenName, HORNS) .. " "),
			key .. ": 'OO …' shown (with the honorific flag), 'A member of the Horn Legion …' hidden", ta .. " / " .. tb)
		check(not has(tb, "숨은뿔") and not has(ta .. tb, T.Honorific .. T.Honorific) and not has(tb, HORNS .. T.Honorific),
			key .. ": no leaked name, no doubled honorific", tb)
	end
end)

------------------------------------------------------------------ 3. the publicName helper of every announcing service
runGroup("service-helpers", function()
	for _, entry in { { "PvPService", HELPER_PvPService }, { "GrudgeService", HELPER_GrudgeService },
		{ "ProgressionService", HELPER_ProgressionService }, { "GooseService", HELPER_GooseService },
		{ "KaijuService", HELPER_KaijuService } } do
		local name, source = entry[1], entry[2]
		local w = announceWorld()
		local shown = w:Player(1, "Halo", "용감한기사", false)
		local hidden = w:Player(2, "Halo", "숨은기사", true)
		local helper = execute(name .. ".publicName", source, w:Env(), w.Registry, w.Util, w.Config)
		check(helper(hidden, true) == w.Announce.PublicName(hidden, true) and helper(hidden) == string.format(T.HiddenName, HALO),
			name .. ": publicName = AnnounceService.PublicName (hidden)", helper(hidden, true))
		check(helper(shown, true) == "용감한기사" .. T.Honorific and helper(shown) == "용감한기사",
			name .. ": publicName passes the honorific flag", helper(shown, true))
		local broken = { AnnounceService = { PublicName = function() error("offline failure") end } }
		local h2 = execute(name .. ".publicName", source, w:Env(), broken, w.Util, w.Config)
		check(h2(shown, true) == "용감한기사" .. T.Honorific, name .. ": a failing PublicName falls back (no error reaches the line)", h2(shown, true))
		local h3 = execute(name .. ".publicName", source, w:Env(), {}, w.Util, w.Config)
		check(h3(shown) == "용감한기사", name .. ": no AnnounceService in the registry falls back to the nickname", h3(shown))
	end
end)

------------------------------------------------------------------ 4. PvPService: Most Wanted line + town board
local function pvpWorld()
	local w = announceWorld()
	local label = { Text = "" }
	w.Label = label
	local J = { GetBullyStacks = function(p) return tonumber(p:GetAttribute("BullyStacks")) or 0 end,
		GetCombatPower = function() return 1000 end }
	local reg = w.Registry
	reg.FactionService = { GetFaction = function(p) return p:GetAttribute("Faction") or "None" end,
		FactionChanged = w.Util.Signal.new() }
	reg.JusticeService = J
	reg.CombatService = { PlayerDamaged = w.Util.Signal.new(), IsInCombat = function() return false end,
		GetLastDamagedAt = function() return 0 end }
	reg.ZoneService = { IsPvPZone = function() return true end, IsTown = function() return false end }
	reg.KaijuService = { GetState = function() return "None" end }
	reg.MapBuilder = { GetBoardLabel = function() return label end }
	reg.ProgressionService = {}
	local pvp = w:Load("PvPService", PVP_SOURCE)
	reg.PvPService = pvp
	pvp.Init(reg)
	w.PvP = pvp
	return w
end

runGroup("pvp-lines", function()
	local w = pvpWorld()
	local shownVillain = w:Player(11, "Horns", "보이는악당", false)
	local hiddenVillain = w:Player(12, "Horns", "숨은악당", true)
	local shownHero = w:Player(13, "Halo", "보이는영웅", false)
	local hiddenHero = w:Player(14, "Halo", "숨은영웅", true)
	w.Data[shownHero].Honor, w.Data[hiddenHero].Honor = 40, 90
	w.PvP.Start()
	for _, p in { shownVillain, hiddenVillain, shownHero, hiddenHero } do w.PvP.DebugSetStars(p, 0) end
	local from = #w.All
	w.PvP.DebugSetStars(hiddenVillain, C.PvP.AnnounceStars)
	w.PvP.DebugSetStars(shownVillain, C.PvP.AnnounceStars)
	-- A23-191 (최종 검수 10/15): no server-wide 'Most Wanted' line any more (WantedStars / Bounty and the board say it)
	check(#w.All == from, "no Most Wanted line for a hidden or a shown villain (A23-191)", #w.All)
	-- board: refreshed by Start's first update and by the loop; run the loop body's board step through Start again
	w.PvP.Start()
	local board = w.Label.Text
	-- (the weekly board rows come from RankingService.ServerTop: checked in tools/test_ranking.py "board")
	check(has(board, "보이는악당"), "town board's wanted line shows a shown player by nickname", board)
	check(not has(board, "숨은악당") and not has(board, "숨은영웅"), "town board never shows a hidden nickname", board)
	check(has(board, string.format(T.HiddenName, HORNS)), "town board's wanted line shows a hidden player as 'A member of the <side>'", board)
	check(not has(board, T.Honorific), "board rows carry no honorific", board)
end)

------------------------------------------------------------------ 5. SetAnnounceName -> RankingService.MarkHideChanged
runGroup("set-name", function()
	local w = announceWorld()
	local p = w:Player(21, "Halo", "숨길사람", false)
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(p, true)
	check(w.Data[p].HideAnnounceName == true and p:GetAttribute("HideAnnounceName") == true, "the remote saves + mirrors the choice")
	check(#w.HideCalls == 1 and w.HideCalls[1] == p, "RankingService.MarkHideChanged(player) runs once per accepted change", #w.HideCalls)
	check(w.Announce.PublicName(p) == string.format(T.HiddenName, HALO), "PublicName follows at once")
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(p, false)
	check(#w.HideCalls == 1, "a call inside RateLimits.SetAnnounceName is ignored (no second MarkHideChanged)", #w.HideCalls)
	w:Advance(1)
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(p, false)
	check(#w.HideCalls == 2 and w.Announce.PublicName(p) == "숨길사람", "showing again also marks the rows", #w.HideCalls)
	w:Advance(1)
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(p, "yes")
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(p, true, 1)
	check(#w.HideCalls == 2 and w.Data[p].HideAnnounceName == false, "wrong type / extra argument: ignored", #w.HideCalls)
	-- no RankingService (before BB10 lands) and a failing one: the setting still works
	local w2 = announceWorld({ Ranking = false })
	local q = w2:Player(22, "Horns", "랭킹없음", false)
	w2.Remotes.SetAnnounceName.OnServerEvent:Fire(q, true)
	check(w2.Data[q].HideAnnounceName == true, "without RankingService the choice is still saved")
	local w3 = announceWorld({ RankingThrows = true })
	local r = w3:Player(23, "Horns", "랭킹오류", false)
	w3.Remotes.SetAnnounceName.OnServerEvent:Fire(r, true)
	check(w3.Data[r].HideAnnounceName == true and #w3.HideCalls == 1, "a failing MarkHideChanged is swallowed after the save")
end)

------------------------------------------------------------------ 6. BB12 Tab list columns
local function columnsWorld(editConfig)
	local w = newWorld({ EditConfig = editConfig })
	w.Conns = {}
	local keys, build = execute("PlayerService.leaderstats", LEADERSTATS_SOURCE, w:Env(), w.Config, w.Util,
		function(_, conn) table.insert(w.Conns, conn) end)
	w.Keys, w.Build = keys, build
	return w
end

local function stat(p, name)
	local folder = p:FindFirstChild("leaderstats")
	local v = folder and folder:FindFirstChild(name)
	return v and v.Value
end

runGroup("leaderstats", function()
	local w = columnsWorld()
	local N = w.Config.Leaderstats.Names
	local p = w:NewPlayer(31, { Level = 12, WeaponTier = 3, WeaponEnhance = 2, Rebirths = 1, Faction = "Halo", Honor = 77,
		Infamy = 5, BankGold = 900, CarriedGold = 100 })
	w.Build(p)
	local folder = p:FindFirstChild("leaderstats")
	local names = {}
	for _, c in folder:GetChildren() do table.insert(names, c.Name) end
	check(table.concat(names, ",") == table.concat({ N.Power, N.Level, N.Rebirths, N.Fame }, ","),
		"columns in order Power, Level, Rebirths, Fame (creation order = list order)", table.concat(names, ","))
	check(folder:FindFirstChild(N.Gold) == nil and folder:FindFirstChild("Gold") == nil, "no gold column (A23-21)")
	check(stat(p, N.Power) == C.CombatPower(12, 3, 2), "before JusticeService sets CombatPower: the same formula", stat(p, N.Power))
	p:SetAttribute("CombatPower", 1234)
	check(stat(p, N.Power) == 1234, "power = the CombatPower attribute (the HUD number)", stat(p, N.Power))
	check(stat(p, N.Level) == 12 and stat(p, N.Rebirths) == 1 and stat(p, N.Fame) == 77, "level / rebirths / Halo fame = Honor")
	-- rebirth: level back to 1, power drops with it, the list follows
	p:SetAttribute("Level", 1)
	p:SetAttribute("Rebirths", 2)
	p:SetAttribute("CombatPower", 283)
	check(stat(p, N.Power) == 283 and stat(p, N.Level) == 1 and stat(p, N.Rebirths) == 2, "a rebirth updates power / level / rebirths at once")
	p:SetAttribute("Faction", "Horns")
	check(stat(p, N.Fame) == 5, "Horns fame = Infamy", stat(p, N.Fame))
	p:SetAttribute("Infamy", 6)
	check(stat(p, N.Fame) == 6, "fame follows Infamy changes", stat(p, N.Fame))
	p:SetAttribute("Faction", "Neutral")
	check(stat(p, N.Fame) == 0, "Neutral fame = this week's 장인 명성 (0 before any)", stat(p, N.Fame))
	p:SetAttribute("WeekArtisan", 9)
	check(stat(p, N.Fame) == 9, "Neutral fame follows WeekArtisan (A23-24)", stat(p, N.Fame))
	p:SetAttribute("Faction", "None")
	check(stat(p, N.Fame) == 0, "None fame = 0", stat(p, N.Fame))
	p:SetAttribute("BankGold", 5000)
	check(stat(p, N.Power) == 283, "gold changes never show anywhere in the list")
	for _, key in { "CombatPower", "Level", "Rebirths", "Honor", "Infamy", "WeekArtisan", "Faction" } do
		check(table.find(w.Keys, key) ~= nil, "LEADERSTAT_KEYS watches " .. key)
	end
	check(#w.Conns == #w.Keys, "one connection per watched attribute (dropped with the player's conns)", #w.Conns)
	-- rebuild replaces the old folder (no duplicate leaderstats)
	w.Build(p)
	local count = 0
	for _, c in p:GetChildren() do if c.Name == "leaderstats" then count += 1 end end
	check(count == 1, "a rebuild leaves exactly one leaderstats folder", count)
end)

runGroup("leaderstats-config", function()
	local w = columnsWorld(function(cfg) cfg.Leaderstats.Columns = { "Level", "Gold" } end)
	local N = w.Config.Leaderstats.Names
	local p = w:NewPlayer(32, { Level = 4, BankGold = 30, CarriedGold = 12 })
	w.Build(p)
	local names = {}
	for _, c in p:FindFirstChild("leaderstats"):GetChildren() do table.insert(names, c.Name) end
	check(table.concat(names, ",") == N.Level .. "," .. N.Gold and stat(p, N.Gold) == 42,
		"one Config line changes the columns (gold = bank + carried when listed)", table.concat(names, ","))
	local w2 = columnsWorld(function(cfg) cfg.Leaderstats.Columns = { "Level", "Nope", "Level" } end)
	w2.AllowWarn = "leaderstats: unknown or repeated column"
	local q = w2:NewPlayer(33, { Level = 2 })
	w2.Build(q)
	check(#q:FindFirstChild("leaderstats"):GetChildren() == 1 and #w2.Warnings == 2,
		"unknown / repeated column ids are skipped with a warning", #w2.Warnings)
end)

finish()
