-- first_meetings_offline.luau : A23-113 (검수 2026-10-10: "원한 자루·강화 옮기기 주문서·덩치 저울도 처음 만날 때 퀘스트 한 줄"): the first meeting with a
-- Transfer Scroll (it sits in the bag), the size scale (the player's own SizeMult is above 1) and the Grudge Sack (a PvP KO took gold
-- into a sack) leaves one plain talking row (TS1 / SZ1 / SG1), the frame of the daily jobs' D0. tools/test_first_meetings.py binds the
-- dev2_combat_world sources (the real StoryQuestService).

local SQ0 = C0.StoryQuests

-- a started story world: the 1 s loop is never run (Refresh is called by hand), XP / gold are recorded
local function meetWorld()
	local w = bareWorld({})
	local reg = w.Registry
	local Signal = w.Util.Signal
	reg.ZoneService.ZoneChanged = Signal.new()
	reg.ZoneService.GetZoneId = function() return "Crossroads" end
	reg.GooseService.GooseFinished = Signal.new()
	reg.PvPService.PlayerKO = Signal.new()
	w.XP = {}
	reg.RankingService = setmetatable({}, { __index = function() return function() end end })
	local ws = w:Env().workspace
	ws.FindFirstChild = function() return nil end
	local rs = w.Services.ReplicatedStorage
	if not rs.FindFirstChild then rs.FindFirstChild = function() return nil end end
	reg.ProgressionService.AddXP = function(_, n) table.insert(w.XP, { N = n }) end
	w.Services.CollectionService = { GetTagged = function() return {} end }
	w.Story.Start()
	w.Net.Get("OpenPanel")
	function w:Act(p, id, action, option)
		self:Advance(1) -- RateLimits.StoryAction
		self.Net.Get("StoryAction").OnServerEvent:Fire(p, id, action, option)
		self:Flush()
	end
	function w:Track(d, id) return d.Story and d.Story.Subs and d.Story.Subs[id] end
	function w:KO(killer, victim, info)
		reg.PvPService.PlayerKO:Fire(killer, victim, info)
		self:Flush()
	end
	return w
end

-- a ready Lv20 player who finished the first three chapters (nothing else waits for them), holding `o.Items`
local function joinMeet(w, userId, faction, o)
	o = o or {}
	local story = { Main = { Id = "" }, Subs = {}, Done = o.Done or { M1_1 = true, M1_2 = true }, Pick = {},
		First = o.First or { Migrated = true } }
	local data = { Story = story, Items = o.Items }
	local p, d = w:Join(userId, { Faction = faction, Class = "Warrior", Level = o.Level or 20, Data = data })
	w.Story.Refresh(p)
	w:Flush()
	return p, d
end

local function rowOf(w, p, d, id)
	w.Config.StoryQuests.MaxSubs = 20
	for _, r in w.Story.SubRows(p, d) do
		if r.Story and r.Story.Id == id then return r end
	end
	return nil
end

-- a toast about one of the three things (the join's own notices - the first weapon, the tips - are not ours)
local OURS = { "transfer", "grudge", "sack", "size scale", "moving a plus", "hear about", "read about" }
local function noticeAny(w, p, from)
	for _, t in w:NoticesFor(p, from) do
		local low = string.lower(t)
		for _, word in OURS do
			if string.find(low, word, 1, true) then return t end
		end
	end
	return nil
end

local function panelsOf(w)
	local out = {}
	local op = w.Net.Get("OpenPanel")
	local base = op.FireClient
	op.FireClient = function(self, p, kind, arg)
		table.insert(out, { P = p, Kind = kind, Arg = arg })
		return base(self, p, kind, arg)
	end
	return out
end

local IDS = { "TS1", "SG1", "SZ1" }

------------------------------------------------------------------ 1. the definitions
runGroup("config", function()
	local words = {
		TS1 = { Meeting = "ScrollMet", Speaker = "Smith", Row = "Hear about your Transfer Scroll", Has = { "transfer scroll", "moves a weapon's + to another weapon", "only the scroll is used up" } },
		SG1 = { Meeting = "SackMet", Speaker = "Notice", Row = "Read about the Grudge Sack", Has = { "grudge sack", "45 seconds", "beat the thief" } },
		SZ1 = { Meeting = "ScaleMet", Speaker = "Fountain", Row = "Hear about the size scale", Has = { "both sides", "bigger", "1.6 times" } },
	}
	for _, id in IDS do
		local def, spec = SQ0.Defs[id], words[id]
		check(def ~= nil and def.Kind == "Sub" and def.Factions == nil and def.Hidden == nil and def.Pop == nil and def.Start == nil and def.Finish == nil,
			id .. ": a plain sub for everyone: no faction, not hidden, no pop-up, no Start / Finish line", show(def and { def.Kind, def.Factions, def.Hidden, def.Pop, def.Start, def.Finish }))
		check(type(def.Requires) == "table" and def.Requires.Seen == spec.Meeting and def.Requires.Done == nil and def.Requires.Level == nil,
			id .. ": it waits only for the meeting " .. spec.Meeting, show(def.Requires))
		check(#def.Steps == 1 and def.Steps[1].Panel == true and def.Steps[1].Obj.Type == "Talk" and def.Steps[1].Text == spec.Row and def.Speaker == spec.Speaker,
			id .. ": one talking row '" .. spec.Row .. "' (the " .. spec.Speaker .. " speaks)", show(def.Steps[1]))
		check(def.Reward and def.Reward.Gold == 1 and def.Reward.XP == 1 and def.Reward.Item == nil and def.Reward.Title == nil,
			id .. ": a minute of hunting, like D0", show(def.Reward))
		check(table.find(SQ0.Subs, id) ~= nil, id .. " is in StoryQuests.Subs", "")
		check(#def.ShortName <= 14 and #def.Title > 0, id .. ": a phone name of at most 14 letters", def.ShortName)
		local lines = def.Steps[1].Lines.All
		check(#lines >= 2 and #lines <= 3, id .. ": two or three short lines", #lines)
		for _, line in lines do
			local n = 0
			for _ in string.gmatch(line, "%a[%w']*") do n += 1 end
			check(n <= 14, id .. ": a line of at most 14 words (the story text rule)", line)
		end
		local joined = string.lower(table.concat(lines, " "))
		for _, word in spec.Has do
			check(string.find(joined, word, 1, true) ~= nil, id .. ": says '" .. word .. "'", joined)
		end
		for _, text in { def.Title, def.ShortName, def.Steps[1].Text, table.unpack(lines) } do
			check(not string.find(text, "[^\32-\126]"), id .. ": plain ASCII", text)
		end
	end
	-- the words follow the numbers
	check(C0.Grudge.SackSeconds == 45, "the sack's 45 seconds are Config.Grudge.SackSeconds", C0.Grudge.SackSeconds)
	check(C0.Justice.MaxScale == 1.6 and C0.Justice.MinScale == 1, "'up to 1.6 times' is Config.Justice.MaxScale", C0.Justice.MaxScale)
	-- the meetings
	check(SQ0.Meetings.ScrollMet.HoldKind == "Transfer" and SQ0.Meetings.ScaleMet.AttrOver.Name == "SizeMult" and SQ0.Meetings.ScaleMet.AttrOver.Over == 1
		and SQ0.Meetings.SackMet == nil and SQ0.Events.SackMet == true, "ScrollMet = a Transfer item in the bag; ScaleMet = SizeMult over 1; SackMet = a listed happening",
		show({ SQ0.Meetings, SQ0.Events }))
	local kinds = {}
	for id, def in C0.Loot.Items do
		if def.Kind == "Transfer" then table.insert(kinds, id) end
	end
	table.sort(kinds)
	check(table.concat(kinds, ",") == "Move10,Move30,Move70", "the Transfer scrolls are Move10 / Move30 / Move70", table.concat(kinds, ","))
	check(C0.Loot.Items.Enh70.Kind == "Enhance", "an enhance scroll is not a transfer scroll", C0.Loot.Items.Enh70.Kind)
end)

------------------------------------------------------------------ 2. nothing is offered before the meeting
runGroup("nothing before the meeting", function()
	local w = meetWorld()
	local panels = panelsOf(w)
	local uid = 2000
	for _, faction in { "Halo", "Horns", "Neutral" } do
		uid += 1
		local n0 = #w.Notices
		local p, d = joinMeet(w, uid, faction)
		for _ = 1, 3 do w.Story.Refresh(p) end
		check(w:Track(d, "TS1") == nil and w:Track(d, "SG1") == nil and w:Track(d, "SZ1") == nil and d.Story.First.ScrollMet == nil
			and d.Story.First.ScaleMet == nil and d.Story.First.SackMet == nil and #panels == 0 and noticeAny(w, p, n0) == nil,
			faction .. ": a player who met nothing has none of the three rows", show({ d.Story.Subs, d.Story.First }))
	end
end)

------------------------------------------------------------------ 3. the Transfer Scroll
runGroup("transfer scroll", function()
	local w = meetWorld()
	local panels = panelsOf(w)
	local uid = 2100
	for _, id in { "Move10", "Move30", "Move70" } do
		uid += 1
		local n0 = #w.Notices
		local p, d = joinMeet(w, uid, "Halo", { Items = { [id] = 1 } })
		local tr = w:Track(d, "TS1")
		local row = rowOf(w, p, d, "TS1")
		check(tr ~= nil and tr.St == 1 and d.Story.First.ScrollMet == true and row ~= nil and row.Text == "Hear about your Transfer Scroll" and row.Story.Panel == true
			and #panels == 0 and noticeAny(w, p, n0) == nil, id .. " in the bag: the row appears, with no popup and no toast", show({ tr, row and row.Text, #panels, noticeAny(w, p, n0) }))
	end
	-- an enhance scroll, nothing, or a count of 0 is not a meeting
	for name, items in { Enhance = { Enh70 = 3, Enh30 = 1 }, Empty = {}, Zero = { Move30 = 0 }, Unknown = { Nope = 2 }, Potion = { HP = 5 } } do
		uid += 1
		local p, d = joinMeet(w, uid, "Horns")
		d.Items = items -- after the join (the join may tidy a bag; the engine itself must not count an empty stack)
		w.Story.Refresh(p)
		check(w:Track(d, "TS1") == nil and d.Story.First.ScrollMet == nil, name .. ": no Transfer Scroll, no row", show({ d.Story.Subs, d.Story.First }))
	end
	-- a scroll that arrives later (a drop) opens the row on the next look; using it up never takes the row away
	uid += 1
	local p, d = joinMeet(w, uid, "Neutral")
	check(w:Track(d, "TS1") == nil, "no scroll yet: no row", "")
	d.Items = { Move30 = 1 }
	w.Story.Refresh(p)
	check(w:Track(d, "TS1") ~= nil and d.Story.First.ScrollMet == true, "the drop arrives: the row appears at the next look", show(d.Story.Subs))
	d.Items = {}
	w.Story.Refresh(p)
	check(w:Track(d, "TS1") ~= nil, "the scroll is used up: the row stays", show(d.Story.Subs))
	-- talking finishes it, once, and the same bag never starts it again
	local gold0, xp0, n0 = d.BankGold or 0, #w.XP, #w.Notices
	w:Act(p, "TS1", "Open")
	check(#panels >= 1 and panels[#panels].Arg.Id == "TS1" and panels[#panels].Arg.St == 1, "pressed: its dialogue opens", show(panels[#panels] and panels[#panels].Arg))
	w:Act(p, "TS1", "Talk")
	check(d.Story.Done.TS1 == true and w:Track(d, "TS1") == nil and (d.BankGold or 0) > gold0 and #w.XP > xp0, "talked: done, a little gold and XP", show({ d.Story.Done, d.BankGold }))
	d.Items = { Move70 = 2 }
	for _ = 1, 3 do w.Story.Refresh(p) end
	check(w:Track(d, "TS1") == nil and d.Story.Done.TS1 == true, "never offered again", show(d.Story.Subs))
end)

------------------------------------------------------------------ 4. the size scale
runGroup("size scale", function()
	local w = meetWorld()
	local panels = panelsOf(w)
	local uid = 2200
	for _, faction in { "Halo", "Horns" } do
		uid += 1
		local n0 = #w.Notices
		local p, d = joinMeet(w, uid, faction)
		p:SetAttribute("SizeMult", 1)
		w.Story.Refresh(p)
		check(w:Track(d, "SZ1") == nil and d.Story.First.ScaleMet == nil, faction .. ": SizeMult 1 (the side is not the smaller one): nothing", show(d.Story.First))
		p:SetAttribute("SizeMult", 1.0001)
		w.Story.Refresh(p)
		check(w:Track(d, "SZ1") ~= nil and d.Story.First.ScaleMet == true and #panels == 0 and noticeAny(w, p, n0) == nil,
			faction .. ": SizeMult just over 1: the row appears, no popup, no toast", show({ d.Story.Subs, #panels }))
		p:SetAttribute("SizeMult", 1)
		w.Story.Refresh(p)
		check(w:Track(d, "SZ1") ~= nil and d.Story.First.ScaleMet == true, faction .. ": the sides even out: the row stays", show(d.Story.Subs))
	end
	-- an Artisan Neutral player never grows (SizeMult stays 1): no row; nothing without the attribute
	uid += 1
	local n, nd = joinMeet(w, uid, "Neutral")
	n:SetAttribute("SizeMult", 1)
	w.Story.Refresh(n)
	check(w:Track(nd, "SZ1") == nil, "Neutral: SizeMult 1: no row", show(nd.Story.First))
	uid += 1
	local q, qd = joinMeet(w, uid, "Halo")
	w.Story.Refresh(q)
	check(w:Track(qd, "SZ1") == nil, "no attribute at all: no row", show(qd.Story.First))
	-- a text value never counts
	q:SetAttribute("SizeMult", "big")
	w.Story.Refresh(q)
	check(w:Track(qd, "SZ1") == nil, "a text SizeMult never counts", show(qd.Story.First))
	-- talking
	local p, d = joinMeet(w, uid + 1, "Horns")
	p:SetAttribute("SizeMult", 1.4)
	w.Story.Refresh(p)
	local gold0 = d.BankGold or 0
	w:Act(p, "SZ1", "Talk")
	check(d.Story.Done.SZ1 == true and (d.BankGold or 0) > gold0, "talked: done with a little gold", show(d.Story.Done))
	w.Story.Refresh(p)
	check(w:Track(d, "SZ1") == nil, "never again", "")
end)

------------------------------------------------------------------ 5. the Grudge Sack
runGroup("grudge sack", function()
	local w = meetWorld()
	local panels = panelsOf(w)
	local thief, td = joinMeet(w, 2301, "Horns")
	local victim, vd = joinMeet(w, 2302, "Halo")
	local other, od = joinMeet(w, 2303, "Halo")
	local n0t, n0v = #w.Notices, #w.Notices
	w:KO(thief, victim, { Kind = "Bully", Stolen = 0 })
	w:KO(thief, victim, { Kind = "Honor", Stolen = 0 })
	w:KO(thief, victim, nil)
	w:KO(thief, victim, "plunder")
	check(w:Track(td, "SG1") == nil and w:Track(vd, "SG1") == nil and td.Story.First.SackMet == nil and vd.Story.First.SackMet == nil,
		"a KO that stole nothing is no meeting (Stolen 0, no info, a bad info)", show({ td.Story.First, vd.Story.First }))
	w:KO(thief, victim, { Kind = "Plunder", Stolen = 120 })
	for _, p in { thief, victim, other } do w.Story.Refresh(p) end -- the 1 s loop
	check(td.Story.First.SackMet == true and vd.Story.First.SackMet == true and w:Track(td, "SG1") ~= nil and w:Track(vd, "SG1") ~= nil
		and w:Track(od, "SG1") == nil, "Stolen gold: the thief AND the victim meet the sack; a bystander does not", show({ td.Story.First, vd.Story.First, od.Story.First }))
	check(#panels == 0 and noticeAny(w, thief, n0t) == nil and noticeAny(w, victim, n0v) == nil, "no popup and no toast", show({ #panels, noticeAny(w, thief, n0t) }))
	local row = rowOf(w, victim, vd, "SG1")
	check(row ~= nil and row.Text == "Read about the Grudge Sack" and row.Story.Panel == true, "the row reads 'Read about the Grudge Sack'", show(row and row.Text))
	-- a second plunder never starts it again; bad arguments never throw
	w:KO(thief, victim, { Kind = "Plunder", Stolen = 50 })
	w:KO(nil, nil, { Stolen = 10 })
	w:KO("a", "b", { Stolen = 10 })
	w:KO(thief, nil, { Stolen = 10 })
	for _, p in { thief, victim } do w.Story.Refresh(p) end
	check(td.Story.Subs.SG1 ~= nil and td.Story.Subs.SG1.St == 1 and vd.Story.Subs.SG1 ~= nil, "a second plunder starts nothing new", show(td.Story.Subs.SG1))
	-- the victim talks: done once
	local gold0 = vd.BankGold or 0
	w:Act(victim, "SG1", "Talk")
	check(vd.Story.Done.SG1 == true and (vd.BankGold or 0) > gold0 and w:Track(vd, "SG1") == nil, "talked: done with a little gold", show(vd.Story.Done))
	w:KO(thief, victim, { Kind = "Plunder", Stolen = 20 })
	check(w:Track(vd, "SG1") == nil, "never again after it is done", "")
	-- a victim who is not ready (still loading) is skipped, not an error
	local ghost = w:NewPlayer(2304, {})
	w:KO(thief, ghost, { Kind = "Plunder", Stolen = 30 })
	check(w.Story.Event(ghost, "SackMet") == false, "a victim that is not ready costs nothing (Event answers false)", "")
end)

finish()
