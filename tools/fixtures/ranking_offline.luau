-- BB10 RankingService + the one weekly settle of A23-22 / A23-23 / A23-24, run offline (plan:
-- docs/design/ranking_service_plan_2026-10-06.md §10 + 검수 decisions D1-D6).
-- tools/test_ranking.py injects (before tools/fixtures/dev2_kit.luau): CONFIG_SOURCE, UTIL_SOURCE and the WHOLE
-- RankingService, AnnounceService, PvPService, GrudgeService, TitleService, LootService, CombatService and
-- ProgressionService sources, plus PLAYER_FAME_SOURCE (PlayerService GrantFame + MarkActive / GetLastActive /
-- GetLastOwnActive) and NAMETAG_SOURCE (CharacterVisuals helpers + updateNametag). Only engine / service boundaries
-- are doubles; every rule is driven through the real services (KOs through PvPService.HandleKO or CombatService's
-- death pipeline, drops through LootService.RollKill, enhances through the UseItem remote, sacks through
-- GrudgeService's own loop).

-- (the world: tools/fixtures/dev2_world.luau)

------------------------------------------------------------------ 1. contract numbers and texts
runGroup("config", function()
	local C = C0
	check(C.WeekIndex(MON62) == 2962 and C.WeekIndex(MON62 - 1) == 2961,
		"WeekIndex: Monday 2026-10-05 00:00 KST = 2962, Sunday 23:59:59 KST = 2961", C.WeekIndex(MON62))
	check(C.WeekIndex(MON63 - 1) == 2962 and C.WeekIndex(MON63) == 2963, "WeekIndex flips again at the next Monday 00:00 KST")
	check(C.WeekStart(2962) == MON62 and C.WeekStart(2963) == MON63, "WeekStart(week) = that Monday 00:00 KST", C.WeekStart(2962))
	for _, t in { MON62, MID62, MON63 - 1, MON63 + 12345 } do
		local wk = C.WeekIndex(t)
		check(C.WeekStart(wk) <= t and t < C.WeekStart(wk + 1), "WeekStart(WeekIndex(t)) <= t < WeekStart(+1)", t)
	end
	check(table.concat(R0.Order, ",") == "Honor,Infamy,Artisan,PvP", "four boards in A23-24 order", table.concat(R0.Order, ","))
	check(R0.Boards.Honor.Faction == "Halo" and R0.Boards.Infamy.Faction == "Horns" and R0.Boards.Artisan.Faction == "Neutral"
		and R0.Boards.PvP.Faction == nil, "board factions: Honor Halo, Infamy Horns, Artisan Neutral, PvP every faction")
	check(R0.Boards.Honor.Reward and R0.Boards.Infamy.Reward and R0.Boards.Artisan.Reward and not R0.Boards.PvP.Reward
		and R0.Boards.PvP.Outlaw and not R0.Boards.Honor.Outlaw, "reward boards Honor/Infamy/Artisan, the outlaw board PvP")
	check(R0.WeekCap.Honor == 150 and R0.WeekCap.Infamy == 150 and R0.WeekCap.Artisan == 60 and R0.WeekCap.PvP == nil
		and R0.CraftWeekCap.Artisan == 100,
		"WeekCap Honor 150, Infamy 150, Artisan 60 (100 with crafting on: craft fame joins it, 10/12), PvP none")
	check(R0.OutlawMinScore == 3, "D5: OutlawMinScore = 3", R0.OutlawMinScore)
	check(R0.SettleDelaySeconds == 600 and R0.SettleRetrySeconds == 60 and R0.SettleGiveUpSeconds == 7200,
		"D4: settle 10 min after Monday 00:00, retry 60 s, give up after 2 h")
	check(R0.DefenseWindowSeconds == 10, "D2: self-defense window 10 s")
	check(R0.VictimActiveSeconds == 60 and R0.PvPMinVictimAccountDays == 7 and R0.PvPMinVictimPlaytime == 10800
		and R0.MaxCreditPerVictimPerWeek == 3 and R0.MaxYieldPerVictimPerDay == 5, "BB10 fair-point numbers (60 s, 7 days, 3 h, 3/week, 5/day)")
	check(R0.MinAccountDays == 3 and R0.MinPlaySeconds == 1800 and R0.TopN == 50 and R0.RefreshSeconds == 180
		and R0.WriteEverySeconds == 120 and R0.MinBudget == 5 and R0.MinReadBudget == 2 and R0.LoopSeconds == 10,
		"BB10 store numbers (3 days / 30 min, top 50, read 180 s, write 120 s, budgets 5 / 2, loop 10 s)")
	check(R0.RewardTop == 3 and R0.RewardMult == 1.10 and R0.HandActiveSeconds == 60, "top 3, reward x1.10, hand tags 60 s")
	check(R0.Season == "PRE" and table.find(R0.SeasonHistory, "PRE") ~= nil, "season PRE until beta day")
	check(R0.StorePrefix == "HH_Rank_" and R0.SettleStorePrefix == "HH_RankSettle_", "store prefixes")
	check(R0.FactionCode.None == 0 and R0.FactionCode.Halo == 1 and R0.FactionCode.Horns == 2 and R0.FactionCode.Neutral == 3,
		"faction codes 0 / 1 / 2 / 3")
	for _, board in { "Honor", "Infamy", "Artisan" } do
		for rank = 1, 3 do
			local id = "Rank" .. board .. rank
			local def = C.TitleDefs[id]
			check(def ~= nil and def.Timed == true and def.Name == string.format("This week's %s #%d", R0.Text.TitleNames[board], rank)
				and type(def.NameEn) == "string" and table.find(C.TitleOrder, id) ~= nil,
				"timed title " .. id .. " (\"This week's … #N\", Name / NameEn, in TitleOrder)", def and def.Name)
			local extra = {}
			for k in def or {} do
				if k ~= "Name" and k ~= "NameEn" and k ~= "Color" and k ~= "Timed" then table.insert(extra, k) end
			end
			check(#extra == 0, "timed title " .. id .. " carries no stats", table.concat(extra, ","))
		end
	end
	check(C.TitleDefs.RankPvP1 == nil, "the PvP board has no reward titles")
	check(C.TitleDefs.RankHonor1.Name == "This week's Honor #1" and C.TitleDefs.RankInfamy3.Name == "This week's Mischief #3"
		and C.TitleDefs.RankArtisan2.Name == "This week's Artisan #2", "title wording: 'This week's Honor #1' / 'This week's Artisan #N' (A23-22 / A23-24, A23-48)",
		C.TitleDefs.RankArtisan2.Name)
	check(R0.Text.OutlawChip == "Outlaw: no Auto Battle · half XP and drops (until Monday)", "HUD chip text from A23-23", R0.Text.OutlawChip)
	check(R0.Text.Empty == "No records yet" and R0.Text.OutlawTag == "Outlaw", "empty-board text and the nametag tag")
	local missing = {}
	for key, value in R0.Text do
		if type(value) == "string" and string.sub(key, -2) ~= "En" and type(R0.Text[key .. "En"]) ~= "string" then
			table.insert(missing, key)
		end
	end
	check(#missing == 0, "every Config.Ranking.Text line has an En pair (central text table)", table.concat(missing, ","))
	check(C.RateLimits.RequestRankings == 1, "RateLimits.RequestRankings = 1 s")
	local D = C.Data.Defaults
	check(type(D.Rank) == "table" and D.Rank.WeekId == 0 and D.Rank.PvP == 0 and D.Rank.Artisan == 0
		and type(D.Rank.Victims) == "table" and type(D.Rank.HandScroll) == "table" and D.DebugTainted == false
		and D.Outlaw.WeekId == 0 and D.RankReward.Board == "" and D.Version == 7, "save defaults: Rank / RankReward / Outlaw / DebugTainted (additive; Version 7 = A23-219 ②'s crafted options (6 = A23-186's joke weapons, 5 = A23-153's codex, 4 = C1's tier 9))")
end)

------------------------------------------------------------------ 2. Config.SanitizeRank (DataService.fillDefaults)
runGroup("sanitize", function()
	local C = C0
	local today = C.DayIndex(MID62)
	local d = {}
	C.SanitizeRank(d, MID62)
	local r = d.Rank
	check(r.WeekId == 2962 and r.Honor == 0 and r.Infamy == 0 and r.Artisan == 0 and r.PvP == 0 and next(r.Victims) == nil
		and next(r.HandScroll) == nil and r.YieldDay == today and r.YieldN == 0 and r.HideSynced == false,
		"an old save without Rank gets this week's empty fields", show(r))
	check(d.RankReward.WeekId == 0 and d.RankReward.Board == "" and d.RankReward.Rank == 0 and d.Outlaw.WeekId == 0
		and d.DebugTainted == false and r.Season == "" and d.RankReward.Season == "" and d.Outlaw.Season == ""
		and next(r.Drop) == nil, "RankReward / Outlaw / DebugTainted / Season / Drop defaults")
	d = { Rank = { WeekId = 2962, Season = "PRE", Drop = { Honor = 2962, Infamy = 2961, Artisan = 2960, PvP = 2962, Nope = 2962 } },
		RankReward = { WeekId = 2963, Season = "B1", Board = "Honor", Rank = 1 }, Outlaw = { WeekId = 2963, Season = "x y" } }
	C.SanitizeRank(d, MID62)
	check(d.Rank.Season == "PRE" and d.Rank.Drop.Honor == 2962 and d.Rank.Drop.Infamy == 2961 and d.Rank.Drop.PvP == nil
		and d.Rank.Drop.Nope == nil and d.Rank.Drop.Artisan == nil,
		"Drop: faction boards only, this week's and last week's removals (older ones are past their settle)", show(d.Rank.Drop))
	check(d.RankReward.Season == "B1" and d.Outlaw.Season == "" and d.Outlaw.WeekId == 2963, "seasons kept as short ids, junk -> ''", show(d))
	d = { Rank = { WeekId = 2961, Season = "PRE", Drop = { Honor = 2961, Infamy = 2960 } } }
	C.SanitizeRank(d, MID62)
	check(d.Rank.Drop.Honor == 2961 and d.Rank.Drop.Infamy == nil and d.Rank.Season == "PRE",
		"a removal from last week survives the Monday flip (the week's own fields start over)", show(d.Rank.Drop))
	local victims = {}
	for i = 1, 130 do victims["U" .. i] = (i % 7) + 1 end
	victims.U9001, victims["U-5"], victims.bad, victims.U12x, victims[7], victims.U9002 = 0, 3, 4, 2, 2, 500
	d = { Rank = { WeekId = 2962, Honor = 999, Infamy = -3, Artisan = 12.7, PvP = 40, Victims = victims,
		HandScroll = { Enh70 = 2, Enh30 = 99999, Move70 = 4, Enh10 = -1 }, YieldDay = today, YieldN = 120, HideSynced = true } }
	C.SanitizeRank(d, MID62)
	r = d.Rank
	check(r.Honor == 150 and r.Infamy == 0 and r.Artisan == 12 and r.PvP == 40, "same week: points kept, clamped to 0..WeekCap, floored", show(r))
	local n, badKey, badValue = 0, nil, nil
	for k, v in r.Victims do
		n += 1
		if type(k) ~= "string" or not string.match(k, "^U%-?%d+$") then badKey = k end
		if type(v) ~= "number" or v ~= math.floor(v) or v < 1 or v > 99 then badValue = k end
	end
	check(n <= R0.MaxVictimKeys and n >= 90, "Victims: at most MaxVictimKeys (100) keys", n)
	check(badKey == nil and badValue == nil, "Victims: keys 'U<id>' (negative Studio ids too), counts 1..99", tostring(badKey) .. " " .. tostring(badValue))
	check(r.Victims.U9001 == nil and r.Victims.bad == nil and r.Victims.U12x == nil and r.Victims[7] == nil,
		"Victims: zero counts and malformed keys dropped")
	check(r.HandScroll.Enh70 == 2 and r.HandScroll.Enh30 == C.Loot.ItemCap and r.HandScroll.Move70 == nil
		and r.HandScroll.Enh10 == nil, "HandScroll: only Enh70/30/10, 1..ItemCap", show(r.HandScroll))
	check(r.YieldN == 99 and r.HideSynced == true, "YieldN clamped to 99 on the same day; HideSynced kept")
	-- JSON round trip (the save is JSON): string keys survive, the sanitized table is unchanged
	local Http = { JSONEncode = function(_, v) return jsonEncode(v) end, JSONDecode = function(_, t) return jsonDecode(t) end }
	local okEnc, text = pcall(Http.JSONEncode, Http, d)
	check(okEnc, "the sanitized save JSON-encodes (Victims has only string keys)", text)
	if okEnc then
		local back = Http:JSONDecode(text)
		C.SanitizeRank(back, MID62)
		local same = true
		for k, v in r.Victims do if back.Rank.Victims[k] ~= v then same = false end end
		for k in back.Rank.Victims do if r.Victims[k] == nil then same = false end end
		check(same and back.Rank.Honor == 150 and back.Rank.HandScroll.Enh70 == 2, "JSON round trip keeps Victims / points / tags")
	end
	-- an older week: every week field starts over (they were written to that week's stores at the last leave)
	d = { Rank = { WeekId = 2961, Honor = 30, Infamy = 4, Artisan = 9, PvP = 7, Victims = { U5 = 2 }, HandScroll = { Enh30 = 3 },
		YieldDay = today - 3, YieldN = 4, HideSynced = true } }
	C.SanitizeRank(d, MID62)
	r = d.Rank
	check(r.WeekId == 2962 and r.Honor == 0 and r.Infamy == 0 and r.Artisan == 0 and r.PvP == 0 and next(r.Victims) == nil
		and next(r.HandScroll) == nil, "an older week: points, Victims and HandScroll start over", show(r))
	check(r.YieldN == 0 and r.YieldDay == today and r.HideSynced == true, "another day: YieldN starts over; HideSynced kept")
	-- a newer YieldDay on the same day across a week flip is kept (Monday 00:05: yesterday's counter is gone anyway)
	d = { Rank = { WeekId = 2961, YieldDay = C.DayIndex(MON62 + 300), YieldN = 4 } }
	C.SanitizeRank(d, MON62 + 300)
	check(d.Rank.YieldN == 4, "YieldN is per day, not per week (kept across the Monday flip of the same day)", d.Rank.YieldN)
	-- broken shapes
	d = { Rank = "x", RankReward = { WeekId = 2963, Board = "PvP", Rank = 2 }, Outlaw = 5, DebugTainted = "yes" }
	C.SanitizeRank(d, MID62)
	check(type(d.Rank) == "table" and d.Rank.WeekId == 2962 and d.RankReward.Board == "" and d.RankReward.WeekId == 0
		and d.Outlaw.WeekId == 0 and d.DebugTainted == false, "broken Rank / a PvP 'reward' / Outlaw number / DebugTainted repaired", show(d))
	d = { Rank = { WeekId = 2962, Honor = 0 / 0, PvP = math.huge }, RankReward = { WeekId = 2963, Board = "Honor", Rank = 7 },
		Outlaw = { WeekId = 2963.6 }, DebugTainted = true }
	C.SanitizeRank(d, MID62)
	check(d.Rank.Honor == 0 and d.Rank.PvP == 0 and d.RankReward.Rank == 3 and d.RankReward.Board == "Honor"
		and d.Outlaw.WeekId == 2963 and d.DebugTainted == true, "NaN / inf points -> 0, reward rank clamped to RewardTop, ids floored", show(d))
end)

------------------------------------------------------------------ 3. fair KOs (BB10 PvPCreditOK passes)
runGroup("ko-fair", function()
	local w, k, v = duel()
	w:KO(v, k)
	local rk, rv = w:Rank(k), w:Rank(v)
	check(w.Data[k].Honor == 1, "fair Halo KO of a clean Horns: Honor stat +1 (rule unchanged)", w.Data[k].Honor)
	check(rk.Honor == 1 and k:GetAttribute("WeekHonor") == 1, "fair KO: weekly Honor +1 (WeekHonor attribute too)", show(rk))
	check(rk.PvP == 0 and (k:GetAttribute("WeekPvP") or 0) == 0, "fair KO: the PvP board stays 0", rk.PvP)
	check(rk.Victims.U202 == 1, "CommitFair: the killer's Victims['U202'] = 1", show(rk.Victims))
	check(rv.YieldN == 1 and rv.YieldDay == C0.DayIndex(w.Time), "CommitFair: the victim's YieldN = 1 today", show(rv))
	check(next(w.Ranking.Stats.Refused) == nil, "a fair KO refuses nothing", show(w.Ranking.Stats.Refused))
	-- bold x2 against a much stronger victim
	local w2, k2, v2 = duel({ VictimPower = 1500 })
	w2:KO(v2, k2)
	check(w2.Data[k2].Honor == 2 and w2:Rank(k2).Honor == 2, "a strong victim (bold x2): Honor +2 and weekly +2", w2:Rank(k2).Honor)
	-- Horns KO of a Halo carrying nothing (no sack): Infamy
	local w3, k3, v3 = duel({ KillerFaction = "Horns", VictimFaction = "Halo" })
	w3:KO(v3, k3)
	local r3 = w3:Rank(k3)
	check(w3.Data[k3].Infamy == 1 and r3.Infamy == 1 and k3:GetAttribute("WeekInfamy") == 1,
		"fair Horns KO without a sack: Infamy +1 and weekly Infamy +1", show(r3))
	check(r3.Honor == 0 and r3.PvP == 0 and r3.Victims.U202 == 1, "Horns: no Honor / PvP points; fair counters moved")
	-- the same KO through the real death pipeline (DamagePlayer -> CharacterDied -> HandleKO)
	local w4, k4, v4 = duel()
	w4:Hit(v4, k4, 10)
	check(w4.FriendCalls == 0, "the first PvP hit only queues the friend check (no web call inside the hit)")
	w4:RunSpawned()
	check(w4.FriendCalls == 1, "the queued background job asks IsFriendsWith once")
	w4:Die(v4)
	check(w4:Rank(k4).Honor == 1 and w4.Data[k4].Honor == 1, "death pipeline: a fair KO reaches the weekly Honor board", w4:Rank(k4).Honor)
	check(w4.FriendCalls == 1, "the KO reuses the cached friend answer (no second web call)", w4.FriendCalls)
	-- the background answer never came: the pipeline does not ask Roblox itself (no wait of its own); unknown = friends
	local w5, k5, v5 = duel({ EditConfig = function(c) c.Ranking.FriendWaitSeconds = 0 end })
	w5:Hit(v5, k5, 10)
	w5.Spawned = {} -- the queued background job never ran
	w5.PS.CharacterDied:Fire(v5, v5.Character)
	w5:Flush()
	check(w5.FriendCalls == 0 and w5:Rank(k5).Honor == 0 and w5.Data[k5].Honor == 1,
		"no friend answer yet: the death pipeline makes no web call of its own; the pair counts as friends (stat only)",
		show({ w5.FriendCalls, w5:Rank(k5).Honor }))
	check(R0.FriendWaitSeconds < C0.Player.RespawnTime, "the pipeline's friend wait is shorter than the respawn time",
		R0.FriendWaitSeconds)
	-- the pipeline waits (yields) while the hit's background friend check runs, then judges with its answer
	local w7, k7, v7 = duel()
	w7:Env().task.wait = function(t) return coroutine.yield(t) end -- this world's task.wait really yields
	w7:Hit(v7, k7, 10)
	w7.PS.CharacterDied:Fire(v7, v7.Character)
	local job = table.remove(w7.Deferred)
	local co = coroutine.create(function() job[1](table.unpack(job, 2, job.n)) end)
	local okRun, errRun = coroutine.resume(co)
	check(okRun and coroutine.status(co) == "suspended" and w7:Rank(k7).Honor == 0 and w7.FriendCalls == 0,
		"the death pipeline waits while the hit's friend check is still running", tostring(errRun))
	w7:RunSpawned() -- the background answer arrives
	okRun, errRun = coroutine.resume(co)
	check(okRun and coroutine.status(co) == "dead" and w7:Rank(k7).Honor == 1 and w7.FriendCalls == 1,
		"…then judges the KO with that answer (fair KO counted)", tostring(errRun))
	-- the KO is judged at its own time: a respawn while the pipeline waited is not a 'fresh' victim
	local w6, k6, v6 = duel()
	w6:Hit(v6, k6, 10)
	w6:RunSpawned()
	w6.PS.CharacterDied:Fire(v6, v6.Character) -- the pipeline is deferred
	w6.Clock += 3
	w6.Time += 3
	w6.PS.CharacterSpawned:Fire(v6, v6.Character, nil, false) -- the respawn lands first
	w6:Flush()
	check((k6:GetAttribute("BullyStacks") or 0) == 0 and w6:Rank(k6).PvP == 0 and w6:Rank(k6).Honor == 1,
		"a respawn during the pipeline's wait never makes the KO a fresh-spawn bully KO", show(w6:Rank(k6)))
end)

------------------------------------------------------------------ 4. weaker victims (Bold < 1) -> the PvP board
runGroup("ko-weak", function()
	-- 70% of the killer's power: BoldMult 0.5 (< BoldWeakRatio 0.8) but not a bully KO (>= WeakPowerRatio 0.5)
	local w, k, v = duel({ VictimPower = 700 })
	w.Script = { 0.1 } -- PvPService.ScalePoints(1, 0.5): draw 0.1 < 0.5 -> 1 point
	w:KO(v, k)
	local r = w:Rank(k)
	check(w.Data[k].Honor == 1, "weak victim: the Honor stat still rolls x0.5 (draw 0.1 -> 1)", w.Data[k].Honor)
	check(r.Honor == 0 and (k:GetAttribute("WeekHonor") or 0) == 0, "weak victim: weekly Honor 0", r.Honor)
	check(r.PvP == 1 and k:GetAttribute("WeekPvP") == 1, "weak victim (Bold < 1): PvP board +1", r.PvP)
	check(refused(w, "Weak") == 1, "the refusal reason Weak is counted (A23-18 abuse log)", show(w.Ranking.Stats.Refused))
	check(r.Victims.U202 == nil and w:Rank(v).YieldN == 0, "an unfair KO moves no fair counter")
	check((k:GetAttribute("BullyStacks") or 0) == 0, "70% power is not a bully KO (bully rule unchanged)")
	local w2, k2, v2 = duel({ VictimPower = 700 })
	w2.Script = { 0.9 }
	w2:KO(v2, k2)
	check(w2.Data[k2].Honor == 0 and w2:Rank(k2).PvP == 1, "weak victim, draw 0.9: no Honor point, PvP board still +1")
	-- 40%: a bully KO (stack, no rewards) is also exactly one PvP point
	local w3, k3, v3 = duel({ VictimPower = 400 })
	w3:KO(v3, k3)
	check(k3:GetAttribute("BullyStacks") == 1 and w3:Rank(k3).PvP == 1 and w3.Data[k3].Honor == 0,
		"a bully KO (40% power): one bully stack, PvP board +1 (once), no Honor", show(w3:Rank(k3)))
	-- the Horns side: a weak Halo victim
	local w4, k4, v4 = duel({ KillerFaction = "Horns", VictimFaction = "Halo", VictimPower = 700 })
	w4.Script = { 0.1 }
	w4:KO(v4, k4)
	check(w4:Rank(k4).PvP == 1 and w4:Rank(k4).Infamy == 0 and w4.Data[k4].Infamy == 1,
		"Horns KO of a weak Halo: Infamy stat +1, weekly Infamy 0, PvP +1", show(w4:Rank(k4)))
end)

------------------------------------------------------------------ 5. friends never score on any board
runGroup("ko-friend", function()
	local w, k, v = duel({ Friends = { ["101:202"] = true } })
	w:KO(v, k)
	check(w.Data[k].Honor == 1, "friend KO: the Honor stat is unchanged (only the boards skip it)")
	check(w:Rank(k).Honor == 0 and w:Rank(k).PvP == 0, "friend KO: neither the weekly Honor nor the PvP board", show(w:Rank(k)))
	check(w:Rank(k).Victims.U202 == nil and w:Rank(v).YieldN == 0 and refused(w, "Friend") == 1, "friend KO: no fair counters, reason Friend")
	local w2, k2, v2 = duel({ Friends = { ["101:202"] = true }, VictimPower = 700 })
	w2.Script = { 0.1 }
	w2:KO(v2, k2)
	check(w2:Rank(k2).PvP == 0, "a weak friend KO is not the PvP board either", w2:Rank(k2).PvP)
	-- a failed IsFriendsWith counts as friends and is asked again next time (never cached)
	local w3, k3, v3 = duel({ FriendError = { ["101:202"] = true } })
	w3:KO(v3, k3)
	check(w3:Rank(k3).Honor == 0 and w3:Rank(k3).PvP == 0 and w3.FriendCalls == 1, "IsFriendsWith error: counted as friends (no points)")
	w3.FriendError = {}
	w3:Advance(700)
	w3.PS.MarkActive(v3)
	w3:KO(v3, k3)
	check(w3.FriendCalls == 2 and w3:Rank(k3).Honor == 1, "after an error the pair is asked again (now not friends: fair)", w3.FriendCalls)
	w3:Advance(700)
	w3.PS.MarkActive(v3)
	w3:KO(v3, k3)
	check(w3.FriendCalls == 2 and w3:Rank(k3).Honor == 2, "a successful answer is cached for the session", w3.FriendCalls)
	-- PvPService.HandleKO itself never waits for Roblox: an unknown pair there counts as friends (no points)
	local w4, k4, v4 = duel()
	w4.PvP.HandleKO(v4, k4)
	check(w4.FriendCalls == 0 and w4:Rank(k4).Honor == 0 and w4.Data[k4].Honor == 1,
		"HandleKO without the pipeline's ResolveFriends: no IsFriendsWith call inside it, unknown pair = friends", w4.FriendCalls)
	local w5, k5, v5 = duel()
	w5.Ranking.ResolveFriends(k5, v5)
	check(w5.FriendCalls == 0, "ResolveFriends never asks Roblox itself (it only waits for the hit's background call)")
	w5.Ranking.WarmFriends(k5, v5)
	w5.Ranking.WarmFriends(k5, v5)
	w5:RunSpawned()
	w5.Ranking.WarmFriends(k5, v5)
	w5:RunSpawned()
	check(w5.FriendCalls == 1, "the background check asks once per pair (in flight / cached)", w5.FriendCalls)
	local w6, k6, v6 = duel({ Studio = true })
	w6.Ranking.ResolveFriends(k6, v6)
	check(w6.FriendCalls == 0, "ResolveFriends never asks in the STUDIO season")
end)

------------------------------------------------------------------ 6. the other unfair KOs (BB10 / A23-23 list)
runGroup("ko-unfair", function()
	-- the 4th fair KO of the same victim in a week
	local w, k, v = duel()
	for i = 1, 4 do
		if i > 1 then w:Advance(700) end -- past RepeatWindow (600) and PairRewardCooldown (300): never a bully KO
		w.PS.MarkActive(v)
		w:KO(v, k)
	end
	check(w.Data[k].Honor == 4, "4 KOs: the Honor stat +4 (unchanged)", w.Data[k].Honor)
	check(w:Rank(k).Honor == 3 and w:Rank(k).Victims.U202 == 3, "same victim: 3 fair points a week", show(w:Rank(k)))
	check(w:Rank(k).PvP == 1 and refused(w, "Repeat") == 1, "the 4th KO goes to the PvP board (Repeat)", w:Rank(k).PvP)
	check(w:Rank(v).YieldN == 3, "the victim yielded 3 fair points today", w:Rank(v).YieldN)
	-- an idle victim: only hit by others for 61 s
	local w2, k2, v2 = duel()
	local joinedAt = w2.Clock
	w2:Advance(61)
	w2:Hit(v2, k2, 5)
	check(w2.PS.GetLastActive(v2) == w2.Clock and w2.PS.GetLastOwnActive(v2) == joinedAt,
		"D6: a hit taken moves GetLastActive (idle timers) but never GetLastOwnActive", w2.PS.GetLastOwnActive(v2))
	w2:KO(v2, k2)
	check(w2:Rank(k2).Honor == 0 and w2:Rank(k2).PvP == 1 and refused(w2, "Idle") == 1 and w2.Data[k2].Honor == 1,
		"idle victim (no own action for 61 s): PvP board, no weekly Honor, Honor stat unchanged", show(w2:Rank(k2)))
	local w2b, k2b, v2b = duel()
	w2b:Advance(60)
	w2b:KO(v2b, k2b)
	check(w2b:Rank(k2b).Honor == 1 and w2b:Rank(k2b).PvP == 0, "exactly 60 s since the own action is still active", show(w2b:Rank(k2b)))
	local w2c, k2c, v2c = duel()
	w2c:Advance(61)
	w2c.PS.MarkActive(v2c) -- walking / own input
	w2c:KO(v2c, k2c)
	check(w2c:Rank(k2c).Honor == 1, "an own action (MarkActive without 'Hit') makes the victim active again")
	-- new accounts / short playtime
	local w3, k3, v3 = duel({ VictimAge = 6 })
	w3:KO(v3, k3)
	check(w3:Rank(k3).PvP == 1 and w3:Rank(k3).Honor == 0 and refused(w3, "Newbie") == 1, "victim account 6 days: PvP board (Newbie)")
	local w4, k4, v4 = duel({ VictimPlay = 10799 })
	w4:KO(v4, k4)
	check(w4:Rank(k4).PvP == 1 and w4:Rank(k4).Honor == 0, "victim playtime 10799 s: PvP board (Newbie)")
	local w4b, k4b, v4b = duel({ VictimAge = 7, VictimPlay = 10800 })
	w4b:KO(v4b, k4b)
	check(w4b:Rank(k4b).Honor == 1 and w4b:Rank(k4b).PvP == 0, "exactly 7 days and 3 h: fair")
	-- a just-respawned victim (the bully rule's fresh spawn)
	local w5, k5, v5 = duel()
	w5.PS.CharacterSpawned:Fire(v5, v5.Character, nil, false)
	w5:Advance(5)
	w5.PS.MarkActive(v5)
	w5:KO(v5, k5)
	check(k5:GetAttribute("BullyStacks") == 1 and w5:Rank(k5).PvP == 1 and refused(w5, "Fresh") == 1 and w5:Rank(k5).Honor == 0,
		"a KO 5 s after the victim respawned: bully stack + PvP board (Fresh)", show(w5:Rank(k5)))
	-- 3 KOs of one victim inside 10 minutes (the bully rule's repeat)
	local w6, k6, v6 = duel()
	w6:KO(v6, k6)
	w6:Advance(301)
	w6.PS.MarkActive(v6)
	w6:KO(v6, k6)
	w6:Advance(100)
	w6.PS.MarkActive(v6)
	w6:KO(v6, k6)
	check(w6:Rank(k6).Honor == 2 and w6:Rank(k6).PvP == 1 and refused(w6, "Repeated") == 1 and k6:GetAttribute("BullyStacks") == 1,
		"the 3rd KO inside RepeatWindow (검수: the bully rule is 무단 PvP): PvP +1, no weekly Honor; the first two were fair",
		show(w6:Rank(k6)))
	-- a KO that is both fresh and repeated is still one point
	local w7, k7, v7 = duel()
	w7:KO(v7, k7)
	w7:Advance(301)
	w7.PS.MarkActive(v7)
	w7:KO(v7, k7)
	w7:Advance(100)
	w7.PS.CharacterSpawned:Fire(v7, v7.Character, nil, false)
	w7:Advance(5)
	w7.PS.MarkActive(v7)
	w7:KO(v7, k7)
	check(w7:Rank(k7).PvP == 1 and w7:Rank(k7).Honor == 2 and k7:GetAttribute("BullyStacks") == 1,
		"fresh + repeated on one KO: PvP +1 once (one KO, one point)", show(w7:Rank(k7)))
end)

------------------------------------------------------------------ 7. never unfair (A23-23 / D2)
runGroup("ko-exempt", function()
	local function weakDuel(o)
		o = o or {}
		o.VictimPower = o.VictimPower or 700
		return duel(o)
	end
	local w0, k0, v0 = weakDuel()
	w0.Script = { 0.9 }
	w0:KO(v0, k0)
	check(w0:Rank(k0).PvP == 1, "control: a weak victim with no exemption -> PvP +1")
	-- revenge: the victim KO'd the knight first
	local w, k, v = weakDuel()
	w:KO(k, v)
	w.PvP.DebugSetStars(v, 0) -- the plunder star of that KO would exempt 202 by itself (Wanted)
	check(k:GetAttribute("RevengeTargetId") == 202, "the knight holds a revenge mark on 202")
	w:Advance(5)
	w.PS.MarkActive(v)
	w.Script = { 0.9 }
	w:KO(v, k)
	check(w:Rank(k).PvP == 0 and refused(w, "Weak") >= 1, "revenge KO on a weaker player: never the PvP board", show(w:Rank(k)))
	-- a Wanted victim
	local w2, k2, v2 = weakDuel()
	w2.PvP.DebugSetStars(v2, 1)
	w2.Script = { 0.9 }
	w2:KO(v2, k2)
	check(w2:Rank(k2).PvP == 0, "a Wanted victim (stars): never the PvP board", show(w2:Rank(k2)))
	-- a bully victim
	local w3, k3, v3 = weakDuel({ VictimAttrs = { BullyStacks = 1 } })
	w3.Script = { 0.9 }
	w3:KO(v3, k3)
	check(w3:Rank(k3).PvP == 0, "a bully victim: never the PvP board", show(w3:Rank(k3)))
	-- this week's outlaw (set the way RankingService sets it)
	local w4, k4, v4 = weakDuel()
	w4.Data[v4].Outlaw = OUT(2962)
	w4.Ranking.RefreshEffects(v4)
	check(v4:GetAttribute("Outlaw") == true, "RefreshEffects sets Outlaw for this week's outlaw")
	w4.Script = { 0.9 }
	w4:KO(v4, k4)
	check(w4:Rank(k4).PvP == 0, "an outlaw victim: never the PvP board", show(w4:Rank(k4)))
	local w4b, k4b, v4b = duel({ VictimPower = 400 })
	w4b.Data[v4b].Outlaw = OUT(2962)
	w4b.Ranking.RefreshEffects(v4b)
	w4b:KO(v4b, k4b)
	check((k4b:GetAttribute("BullyStacks") or 0) == 0 and w4b:Rank(k4b).PvP == 0,
		"hunting an outlaw at 40% power is never a bully KO (outlaws are hunted like bullies)", show(w4b:Rank(k4b)))
	-- kaiju victim / kaiju killer
	local w5, k5, v5 = weakDuel({ VictimAttrs = { KaijuState = "Queued" } })
	w5.Script = { 0.9 }
	w5:KO(v5, k5)
	check(w5:Rank(k5).PvP == 0, "a kaiju victim (queued / siren): never the PvP board")
	local w6, k6, v6 = weakDuel({ KillerAttrs = { KaijuState = "Active" } })
	w6.Script = { 0.9 }
	w6:KO(v6, k6)
	check(w6:Rank(k6).PvP == 0, "a killer who is the kaiju (Active): never the PvP board")
	local w6b, k6b, v6b = weakDuel({ KillerAttrs = { KaijuState = "Queued" } })
	w6b.Script = { 0.9 }
	w6b:KO(v6b, k6b)
	check(w6b:Rank(k6b).PvP == 1, "a killer only queued for the kaiju is not one yet: a weak KO is unfair (D2)")
	-- a thief carrying a grudge sack, through the real death pipeline (HasSack read before the sack closes)
	local w7, k7, v7 = weakDuel()
	local h7 = w7:Join(303, "Halo", { Carried = 10000 })
	w7:KO(h7, v7) -- the Horns 202 plunders 303: a sack
	w7.PvP.DebugSetStars(v7, 0) -- the plunder star would exempt 202 by itself (Wanted)
	check(w7.Grudge.HasSack(v7), "202 carries a grudge sack")
	w7:Advance(5)
	w7.PS.MarkActive(v7)
	w7:Hit(v7, k7, 5)
	w7:RunSpawned()
	w7.Script = { 0.9 }
	w7:Die(v7)
	check(not w7.Grudge.HasSack(v7), "the death pipeline closed the sack (avenged)")
	check(w7:Rank(k7).PvP == 0, "a thief KO'd while carrying a sack: never the PvP board (HadSack seen before the sack closed)",
		show(w7:Rank(k7)))
	-- the same pipeline without a sack is unfair
	local w7b, k7b, v7b = weakDuel()
	w7b:Hit(v7b, k7b, 5)
	w7b:RunSpawned()
	w7b.Script = { 0.9 }
	w7b:Die(v7b)
	check(w7b:Rank(k7b).PvP == 1, "control: the death pipeline without a sack -> PvP +1")
	-- self-defense: the victim struck first and kept hitting within 10 s
	local w8, k8, v8 = weakDuel()
	w8:Hit(k8, v8, 5)
	w8:Advance(1)
	w8:Hit(v8, k8, 5)
	w8:Advance(1)
	w8.PS.MarkActive(v8)
	w8.Script = { 0.9 }
	w8:KO(v8, k8)
	check(w8:Rank(k8).PvP == 0, "self-defense (the victim hit first, within 10 s of the KO): never the PvP board", show(w8:Rank(k8)))
	local w9, k9, v9 = weakDuel()
	w9:Hit(k9, v9, 5)
	w9:Advance(1)
	w9:Hit(v9, k9, 5)
	w9:Advance(11)
	w9.PS.MarkActive(v9)
	w9.Script = { 0.9 }
	w9:KO(v9, k9)
	check(w9:Rank(k9).PvP == 1, "the KO landed more than DefenseWindowSeconds after the victim's first hit: not self-defense",
		show(w9:Rank(k9)))
	local w9b, k9b, v9b = weakDuel()
	w9b:Hit(k9b, v9b, 5)
	w9b:Advance(8)
	w9b:Hit(k9b, v9b, 5)
	w9b:Advance(1)
	w9b:Hit(v9b, k9b, 5)
	w9b:Advance(6)
	w9b.PS.MarkActive(v9b)
	w9b.Script = { 0.9 }
	w9b:KO(v9b, k9b)
	check(w9b:Rank(k9b).PvP == 1, "D2: the window counts from the victim's FIRST hit (hits at 0 and 8 s, KO at 15 s: not self-defense)",
		show(w9b:Rank(k9b)))
	local w10, k10, v10 = weakDuel()
	w10:Hit(v10, k10, 5)
	w10:Advance(1)
	w10:Hit(k10, v10, 5)
	w10:Advance(1)
	w10.PS.MarkActive(v10)
	w10.Script = { 0.9 }
	w10:KO(v10, k10)
	check(w10:Rank(k10).PvP == 1, "the killer struck first (the victim only hit back): not self-defense", show(w10:Rank(k10)))
	-- 검수 D2 cases: the fight's first hit is remembered per pair (a long fight never forgets who started it)
	local function fight(script, koAt)
		local wf, kf, vf = weakDuel()
		local t = 0
		for _, step in script do
			wf:Advance(step[1] - t)
			t = step[1]
			if step[2] == "K" then wf:Hit(vf, kf, 1) else wf:Hit(kf, vf, 1) end
		end
		wf:Advance(koAt - t)
		wf.PS.MarkActive(vf)
		wf.Script = { 0.9 }
		wf:KO(vf, kf)
		return wf:Rank(kf).PvP
	end
	local long = { { 0, "K" } }
	for t = 2, 26, 2 do table.insert(long, { t, t % 4 == 0 and "K" or "V" }) end
	check(fight(long, 26) == 1, "a 26 s fight the killer started: not self-defense (the opening hit is not forgotten)")
	local long2 = { { 0, "V" } }
	for t = 2, 18, 2 do table.insert(long2, { t, t % 4 == 0 and "V" or "K" }) end
	check(fight(long2, 18) == 1, "the victim started it but the KO came 18 s later: not self-defense (D2: 10 s)")
	check(fight({ { 0, "V" }, { 1, "K" }, { 3, "V" } }, 8) == 0, "the victim started it, KO 8 s later: self-defense")
	check(fight({ { 0, "V" }, { 21, "K" }, { 22, "V" } }, 23) == 1, "21 s without a hit starts a new fight: the killer started this one")
	check(fight({ { 0, "K" }, { 21, "V" }, { 22, "K" } }, 24) == 0, "a new fight the victim started 3 s before the KO: self-defense")
	-- an exemption never blocks a FAIR point: a Wanted victim of equal power reaches the weekly Honor board
	local w11, k11, v11 = duel()
	w11.PvP.DebugSetStars(v11, 2)
	w11:KO(v11, k11)
	check(w11:Rank(k11).Honor == 2 and w11:Rank(k11).PvP == 0, "a fair KO of a Wanted Horns: weekly Honor +2 (the bounty KO)", show(w11:Rank(k11)))
end)

------------------------------------------------------------------ 8. the victim's daily yield cap
runGroup("ko-yieldcap", function()
	local w, k, v = duel()
	local rv = w:Rank(v)
	rv.YieldDay, rv.YieldN = C0.DayIndex(w.Time), 5
	w:KO(v, k)
	check(w.Data[k].Honor == 1 and w:Rank(k).Honor == 0 and w:Rank(k).PvP == 0 and refused(w, "YieldCap") == 1,
		"victim already gave 5 fair points today: neither board (YieldCap is not unfair)", show(w:Rank(k)))
	check(w:Rank(k).Victims.U202 == nil and rv.YieldN == 5, "YieldCap: no counter moves")
	local w2, k2, v2 = duel()
	local r2 = w2:Rank(v2)
	r2.YieldDay, r2.YieldN = C0.DayIndex(w2.Time) - 1, 5
	w2:KO(v2, k2)
	check(w2:Rank(k2).Honor == 1 and r2.YieldDay == C0.DayIndex(w2.Time) and r2.YieldN == 1, "yesterday's 5 do not count today", show(r2))
	-- five different killers today, the sixth gets nothing
	local w3 = rankWorld()
	local victim = w3:Join(202, "Horns")
	local got = {}
	for i = 1, 6 do
		local killer = w3:Join(100 + i, "Halo")
		w3:Advance(1)
		w3.PS.MarkActive(victim)
		w3:KO(victim, killer)
		got[i] = w3:Rank(killer).Honor
	end
	check(table.concat(got, ",") == "1,1,1,1,1,0" and w3:Rank(victim).YieldN == 5, "MaxYieldPerVictimPerDay: 5 killers score, the 6th does not", table.concat(got, ","))
	-- a killer already at the weekly cap: the point cannot land, so no fair counter moves either
	local w4, k4, v4 = duel()
	w4:Rank(k4).Honor = R0.WeekCap.Honor
	w4:KO(v4, k4)
	check(w4.Data[k4].Honor == 1 and w4:Rank(k4).Honor == R0.WeekCap.Honor and w4:Rank(k4).PvP == 0 and refused(w4, "WeekCap") >= 1,
		"killer at WeekCap: stat only, no PvP point", show(w4:Rank(k4)))
	check(w4:Rank(k4).Victims.U202 == nil and w4:Rank(v4).YieldN == 0, "killer at WeekCap: the victim's daily yield is not used up")
end)

------------------------------------------------------------------ 9. the STUDIO season (Studio test clients)
runGroup("ko-studio", function()
	local w, k, v = duel({ Studio = true, Friends = { ["101:202"] = true }, VictimAge = 0, VictimPlay = 0 })
	check(w.Ranking.EffectiveSeason() == "STUDIO", "Studio: season STUDIO")
	w:KO(v, k)
	check(w:Rank(k).Honor == 1 and w:Rank(k).PvP == 0 and w.FriendCalls == 0,
		"STUDIO season: no friend / account-age / playtime checks (Studio clients are new, negative ids)", show(w:Rank(k)))
	local w2, k2, v2 = duel({ Studio = true, VictimPower = 700 })
	w2.Script = { 0.9 }
	w2:KO(v2, k2)
	check(w2:Rank(k2).PvP == 1, "STUDIO season: a weak victim is still unfair")
	check(rankWorld({ Memory = true }).Ranking.EffectiveSeason() == "STUDIO", "DataStore memory mode outside Studio is STUDIO too")
	check(rankWorld().Ranking.EffectiveSeason() == "PRE", "a live server is Config.Ranking.Season (PRE)")
	check(rankWorld({ EditConfig = function(c) c.Ranking.Season = "B1" end }).Ranking.EffectiveSeason() == "B1", "the season follows Config (B1 on beta day)")
end)

------------------------------------------------------------------ 10. grudge sacks: only paid fair points
runGroup("sack", function()
	local function thief(o)
		o = o or {}
		o.KillerFaction, o.VictimFaction, o.Carried = "Horns", "Halo", o.Carried or 10000
		return duel(o)
	end
	local w, k, v = thief()
	w:KO(v, k)
	check(w.Grudge.HasSack(k), "the plunder made a grudge sack")
	check(w.Data[k].Infamy == 0 and w:Rank(k).Infamy == 0, "nothing is credited before the sack is paid")
	check(w:Rank(k).Victims.U202 == 1 and w:Rank(v).YieldN == 1, "the fair point is committed at the KO (CommitFair once)", show(w:Rank(k).Victims))
	w:GrudgeRun(50)
	check(not w.Grudge.HasSack(k) and w.Data[k].Infamy == 1, "after 45 s in a PvP zone the sack is paid (Infamy stat +1)", w.Data[k].Infamy)
	check(w:Rank(k).Infamy == 1 and k:GetAttribute("WeekInfamy") == 1, "Paid: the weekly board gets the sack's fair RankInfamy", show(w:Rank(k)))
	check(w:Rank(k).Victims.U202 == 1, "the payout does not count the victim a second time")
	-- avenged: a Halo KOs the thief in time
	local w2, k2, v2 = thief()
	w2:KO(v2, k2)
	local h2 = w2:Join(303, "Halo")
	w2.Grudge.OnCarrierDown(k2, h2)
	check(not w2.Grudge.HasSack(k2) and w2.Data[k2].Infamy == 0 and w2:Rank(k2).Infamy == 0, "Avenged: no Infamy, no weekly points")
	-- returned: the thief leaves
	local w3, k3, v3 = thief()
	w3:KO(v3, k3)
	w3:Leave(k3)
	w3:RunSpawned()
	check(w3.Data[k3].Infamy == 0 and w3:Rank(k3).Infamy == 0, "Returned (thief left): no Infamy, no weekly points")
	-- an unfair plunder (weak victim): the sack carries Infamy but no fair points
	local w4, k4, v4 = thief({ VictimPower = 700 })
	w4.Script = { 0.1 }
	w4:KO(v4, k4)
	check(w4:Rank(k4).PvP == 1, "a weak victim's plunder is unfair: PvP +1")
	w4:GrudgeRun(50)
	check(w4.Data[k4].Infamy == 1 and w4:Rank(k4).Infamy == 0, "paid sack of an unfair KO: Infamy stat +1, weekly 0", show(w4:Rank(k4)))
	-- one sack, a fair and an unfair KO: only the fair point reaches the board
	local w5 = rankWorld()
	local t5 = w5:Join(101, "Horns")
	local a5 = w5:Join(202, "Halo", { Carried = 10000 })
	local b5 = w5:Join(203, "Halo", { Carried = 10000, Power = 700 })
	w5:KO(a5, t5)
	w5:Advance(1)
	w5.PS.MarkActive(b5)
	w5.Script = { 0.1 }
	w5:KO(b5, t5)
	w5:GrudgeRun(50)
	check(w5.Data[t5].Infamy == 2 and w5:Rank(t5).Infamy == 1 and w5:Rank(t5).PvP == 1,
		"one sack with a fair and an unfair KO: Infamy +2, weekly Infamy +1, PvP +1", show(w5:Rank(t5)))
	-- AddToSack clamps the fair points to the sack's infamy
	local w6, k6, v6 = thief()
	w6.Grudge.AddToSack(k6, v6, 100, 1, 5)
	w6:GrudgeRun(50)
	check(w6.Data[k6].Infamy == 1 and w6:Rank(k6).Infamy == 1, "AddToSack(…, infamy 1, rankPts 5): only 1 fair point", show(w6:Rank(k6)))
end)

------------------------------------------------------------------ 11. a Wanted leaver pays like a KO (payLeaveBounty)
runGroup("leave-bounty", function()
	local w, k, v = duel()
	w.PvP.DebugSetStars(v, 2)
	w:Hit(v, k, 5)
	w:RunSpawned() -- the friend answer arrives in the background
	w:Leave(v)
	check(w.Data[k].Honor == 2 and w:Rank(k).Honor == 2, "payLeaveBounty: judged like a KO with the leaver as the victim (fair -> weekly Honor)",
		show(w:Rank(k)))
	check(w:Rank(k).Victims.U202 == 1 and w.Data[v].Rank.YieldN == 1, "the leaver's data was still loaded: both fair counters moved")
	check(w.FriendCalls == 1, "the leave itself never calls IsFriendsWith", w.FriendCalls)
	check(w.Ranking.PendingWrites() == 1, "the leaver's last ranking write is pending (BindToClose waits for it)")
	w:RunSpawned()
	check(w.Ranking.PendingWrites() == 0, "…and done", w.Ranking.PendingWrites())
	local w2, k2, v2 = duel()
	w2.PvP.DebugSetStars(v2, 2)
	w2:Hit(v2, k2, 5)
	w2:Leave(v2) -- the background friend job has not run yet
	check(w2.FriendCalls == 0, "PlayerLeaving: no web call (cache only)", w2.FriendCalls)
	check(w2.Data[k2].Honor == 2 and w2:Rank(k2).Honor == 0, "an unknown pair while leaving counts as friends: stat only", show(w2:Rank(k2)))
	w2:RunSpawned()
	local w3, k3, v3 = duel({ VictimPower = 700 })
	w3.PvP.DebugSetStars(v3, 1)
	w3:Hit(v3, k3, 5)
	w3:RunSpawned()
	w3.Script = { 0.9 }
	w3:Leave(v3)
	check(w3:Rank(k3).PvP == 0, "a weak Wanted leaver is never unfair (Wanted exemption)", show(w3:Rank(k3)))
end)

------------------------------------------------------------------ 12. credit guards (D1, factions, caps, private servers)
runGroup("credit-guards", function()
	local w = rankWorld()
	local h = w:Join(101, "Halo")
	local R = w.Ranking
	w.PS.GrantFame(h, "Honor", 5, { Kind = "Story" })
	w.PS.GrantFame(h, "Honor", 5)
	w.PS.GrantFame(h, "Honor", 5, { Kind = "Goose" })
	check(w.Data[h].Honor == 15 and w:Rank(h).Honor == 0, "D1: story / goose fame stays in the stat, never on a board", w:Rank(h).Honor)
	w.PS.GrantFame(h, "Honor", 2, { PvP = true, Fair = false })
	check(w.Data[h].Honor == 17 and w:Rank(h).Honor == 0, "a PvP grant that was not fair: stat only")
	w.PS.GrantFame(h, "Honor", 2, { PvP = true, Fair = true })
	check(w:Rank(h).Honor == 2, "a fair PvP grant: weekly Honor +n", w:Rank(h).Honor)
	w.PS.GrantFame(h, "Infamy", 3, { PvP = true, Fair = true })
	check(w.Data[h].Infamy == 3 and w:Rank(h).Infamy == 0 and refused(w, "Faction") == 1,
		"a Halo player's Infamy never reaches the Horns board (Faction)", show(w:Rank(h)))
	check(w.PS.GrantFame(h, "Gold", 5, { PvP = true, Fair = true }) == 0 and w.Data[h].Gold == nil, "GrantFame takes Honor / Infamy only")
	check(R.Credit(h, "Honor", 0) == false and R.Credit(h, "Honor", -4) == false and R.Credit(h, "Nope", 3) == false
		and R.Credit("P101", "Honor", 1) == false, "Credit: n <= 0, unknown board, not a Player -> false")
	check(R.Credit(h, "Honor", 147) == true and w:Rank(h).Honor == 149, "Credit adds to this week's board")
	check(R.Credit(h, "Honor", 5) == true and w:Rank(h).Honor == 150, "a credit past WeekCap is cut at the cap", w:Rank(h).Honor)
	check(R.Credit(h, "Honor", 1) == false and w:Rank(h).Honor == 150 and refused(w, "WeekCap") == 1, "at the cap: refused")
	local before = #w.Warnings
	R.Credit(h, "Honor", 1)
	check(#w.Warnings == before, "the WeekCap warning is throttled (30 s)")
	w.AllowWarn = "weekly Honor cap"
	check(R.Credit(h, "PvP", 500) == true and w:Rank(h).PvP == 500, "the PvP board has no cap")
	local n = rankWorld()
	local nu = n:Join(301, "Neutral")
	check(n.Config.Features.Crafting ~= true and n.Ranking.Credit(nu, "Artisan", 120) == true and n:Rank(nu).Artisan == 60,
		"Artisan WeekCap 60 while crafting is off", n:Rank(nu).Artisan)
	n.Config.Features.Crafting = true
	check(n.Ranking.Credit(nu, "Artisan", 120) == true and n:Rank(nu).Artisan == 100, "Artisan WeekCap 100 once crafting is on", n:Rank(nu).Artisan)
	n.Config.Features.Crafting = false
	check(n.Ranking.Credit(nu, "Honor", 1) == false, "a Neutral player is never on the Honor board")
	local np = rankWorld({ PrivateServerId = "vip-2" })
	local npu = np:Join(302, "Neutral")
	check(np.Ranking.Credit(npu, "Artisan", 3) == false and np:Rank(npu).Artisan == 0, "private server: no 장인 명성 either (Credit refuses)")
	-- private / reserved servers: nothing counts anywhere
	local w2, k2, v2 = duel({ PrivateServerId = "vip-1" })
	w2:KO(v2, k2)
	check(w2.Data[k2].Honor == 1 and w2:Rank(k2).Honor == 0 and refused(w2, "Private") >= 1, "private server: fair KO, stat only")
	local w3, k3, v3 = duel({ PrivateServerId = "vip-1", VictimPower = 700 })
	w3.Script = { 0.9 }
	w3:KO(v3, k3)
	check(w3:Rank(k3).PvP == 0, "private server: an unfair KO is not counted either")
	local w3b, k3b, v3b = duel({ PrivateServerId = "vip-1", KillerFaction = "Horns", VictimFaction = "Halo", Carried = 10000 })
	w3b:KO(v3b, k3b)
	check(w3b.Grudge.HasSack(k3b) and w3b:Rank(k3b).Victims.U202 == nil and w3b:Rank(v3b).YieldN == 0,
		"private server plunder: the fair counters never move (they would block fair points on public servers)")
	-- a failing ranking never blocks the stat
	local w4 = rankWorld()
	local p4 = w4:Join(101, "Halo")
	w4.Registry.RankingService = { CreditFame = function() error("offline ranking failure") end }
	w4.AllowWarn = "GrantFame"
	check(w4.PS.GrantFame(p4, "Honor", 2, { PvP = true, Fair = true }) == 2 and w4.Data[p4].Honor == 2, "CreditFame error: the stat still goes up")
	w4.Registry.RankingService = nil
	check(w4.PS.GrantFame(p4, "Honor", 1) == 3, "without RankingService: the stat only")
end)

------------------------------------------------------------------ 13. 장인 명성 (A23-24)
runGroup("artisan", function()
	local function guild(o)
		o = o or {}
		local w = rankWorld(o)
		-- holding tier 1 (A23-34: the save defaults start bare-handed; the scroll enhances this weapon)
		local p = w:Join(301, o.Faction or "Neutral", { Data = { WeaponTier = 1, WeaponOwnedMask = 1,
			WeaponEnhance = { o.Plus or 2 }, Items = o.Items or {} } })
		return w, p
	end
	local w, p = guild()
	check(w:Drop(p, "Goblin", { Enh30 = true }) == 0, "one scripted Goblin kill (one draw per row)")
	check((w.Data[p].Items.Enh30 or 0) == 1 and w:Rank(p).HandScroll.Enh30 == 1, "a scroll my own kill dropped while in the guild gets a tag", show(w:Rank(p).HandScroll))
	w:Enhance(p, "Enh30", 1, true)
	check(w.Data[p].WeaponEnhance[1] == 5, "Enh30 success: +2 -> +5", w.Data[p].WeaponEnhance[1])
	check(w:Rank(p).Artisan == 3 and p:GetAttribute("WeekArtisan") == 3, "a tagged Enh30 success at +2 scores 3 (A23-24 acceptance)", w:Rank(p).Artisan)
	check(w:CountNotices(p, string.format(R0.Text.ArtisanGain, 3)) == 1, "the player sees '+3 장인 명성'")
	check(w:Rank(p).HandScroll.Enh30 == nil, "the tag was used")
	w:Drop(p, "Goblin", { Enh30 = true })
	w:Enhance(p, "Enh30", 1, false)
	check(w:Rank(p).Artisan == 3 and w:Rank(p).HandScroll.Enh30 == nil, "a failed tagged scroll: 0 points, the tag is used", show(w:Rank(p)))
	-- away auto-hunting: no own action for 61 s
	local w2, p2 = guild()
	w2:Advance(61)
	w2:Drop(p2, "Goblin", { Enh30 = true })
	check((w2.Data[p2].Items.Enh30 or 0) == 1 and w2:Rank(p2).HandScroll.Enh30 == nil, "a drop while away (61 s) gets no tag")
	w2:Enhance(p2, "Enh30", 1, true)
	check(w2.Data[p2].WeaponEnhance[1] == 5 and w2:Rank(p2).Artisan == 0, "an untagged success scores 0", w2:Rank(p2).Artisan)
	-- a scroll from another faction's days
	local w3, p3 = guild({ Faction = "Halo" })
	w3:Drop(p3, "Goblin", { Enh30 = true })
	check(w3:Rank(p3).HandScroll.Enh30 == nil, "a Halo player's drop gets no tag")
	w3:SetFaction(p3, "Neutral")
	w3:Enhance(p3, "Enh30", 1, true)
	check(w3:Rank(p3).Artisan == 0, "a scroll from the Halo days scores 0 in the guild")
	local wp, pp = guild({ PrivateServerId = "vip-3" })
	wp:Drop(pp, "Goblin", { Enh30 = true })
	check((wp.Data[pp].Items.Enh30 or 0) == 1 and wp:Rank(pp).HandScroll.Enh30 == nil, "a private-server drop gets no tag (it would score later on a public server)")
	-- the +10 cut: Enh10 (+5) at +9 scores the 1 step it really rose
	local w4, p4 = guild({ Plus = 9 })
	w4:Drop(p4, "Goblin", { Enh10 = true })
	w4:Enhance(p4, "Enh10", 1, true)
	check(w4.Data[p4].WeaponEnhance[1] == 10 and w4:Rank(p4).Artisan == 1, "Enh10 at +9: capped at +10, scores 1", w4:Rank(p4).Artisan)
	-- a fail that drops a level scores 0 (never negative)
	local w5, p5 = guild({ Plus = 4 })
	w5:Drop(p5, "Goblin", { Enh70 = true })
	w5:Enhance(p5, "Enh70", 1, false, true)
	check(w5.Data[p5].WeaponEnhance[1] == 3 and w5:Rank(p5).Artisan == 0, "a fail-drop (+4 -> +3) scores 0, never negative")
	-- transfer scrolls never score
	local w6, p6 = guild({ Items = { Move70 = 1 } })
	w6.Data[p6].WeaponOwnedMask = 3
	w6.Data[p6].WeaponEnhance = { 4, 0 }
	w6:Advance(1)
	w6.Script = { 0 }
	w6.Remotes.UseItem.OnServerEvent:Fire(p6, "Move70", 1, 2)
	w6.Script = nil
	check(w6.Data[p6].WeaponEnhance[2] == 4 and w6:Rank(p6).Artisan == 0, "a transfer scroll moves +4 and scores 0")
	-- tags are trimmed to the scrolls really held (a tag never outlives its scroll)
	local w7, p7 = guild({ Items = { Enh70 = 1 } })
	w7:Rank(p7).HandScroll.Enh70 = 5
	w7:Enhance(p7, "Enh70", 1, true)
	check(w7:Rank(p7).Artisan == 1 and w7:Rank(p7).HandScroll.Enh70 == nil, "5 tags but 1 scroll: scores once, no tag left", show(w7:Rank(p7).HandScroll))
	-- 2 tagged + 1 untagged scroll: 2 scoring uses
	local w8, p8 = guild({ Items = { Enh70 = 1 } })
	w8:Drop(p8, "Goblin", { Enh70 = true })
	w8:Drop(p8, "Goblin", { Enh70 = true })
	check(w8.Data[p8].Items.Enh70 == 3 and w8:Rank(p8).HandScroll.Enh70 == 2, "3 scrolls, 2 tagged")
	for _ = 1, 3 do w8:Enhance(p8, "Enh70", 1, true) end
	check(w8:Rank(p8).Artisan == 2, "3 successes, 2 tags: 2 points", w8:Rank(p8).Artisan)
	-- the first king slime's guaranteed scroll is a drop of my own kill
	local w9, p9 = guild()
	w9:Drop(p9, "BigSlime", {})
	check(w9.Data[p9].Items.Enh70 == 1 and w9:Rank(p9).HandScroll.Enh70 == 1, "the guaranteed first king-slime Enh70 gets a tag")
	-- last week's tags score 0
	local w10, p10 = guild({ Time = MON63 - 100 })
	w10:Drop(p10, "Goblin", { Enh30 = true })
	check(w10:Rank(p10).HandScroll.Enh30 == 1, "tag in week 2962")
	w10:Advance(200)
	w10:Tick()
	check(w10:Rank(p10).WeekId == 2963 and next(w10:Rank(p10).HandScroll) == nil, "the week flip clears the tags")
	w10:Enhance(p10, "Enh30", 1, true)
	check(w10:Rank(p10).Artisan == 0, "last week's scroll scores 0")
	-- leaving the guild drops this week's 장인 points, tags and the board row
	local w11, p11 = guild()
	w11:Drop(p11, "Goblin", { Enh30 = true, Enh70 = true })
	w11:Enhance(p11, "Enh30", 1, true)
	w11:Tick()
	check(w11:Row(storeName("PRE", "Artisan", 2962), "U_301") == 303, "the Artisan row: 3 points, Neutral code 3", w11:Row(storeName("PRE", "Artisan", 2962), "U_301"))
	w11:SetFaction(p11, "Halo")
	check(w11:Rank(p11).Artisan == 0 and next(w11:Rank(p11).HandScroll) == nil and p11:GetAttribute("WeekArtisan") == 0,
		"leaving the guild: this week's 장인 points and tags are gone", show(w11:Rank(p11)))
	w11:Tick()
	check(w11:Row(storeName("PRE", "Artisan", 2962), "U_301") == nil and #w11:Calls("Remove", "HH_Rank_PRE_Artisan") == 1,
		"leaving the guild removes the Artisan row at once")
	w11:SetFaction(p11, "Neutral")
	w11:Enhance(p11, "Enh70", 1, true)
	check(w11:Rank(p11).Artisan == 0, "back in the guild: the old tag is gone too")
end)

------------------------------------------------------------------ 14. ordered-store writes
runGroup("writes", function()
	local w = rankWorld()
	local h = w:Join(101, "Halo")
	local honor = storeName("PRE", "Honor", 2962)
	w.Ranking.Credit(h, "Honor", 7)
	w:Tick()
	check(w:Row(honor, "U_101") == 701, "value = score*100 + hidden*10 + faction code (Halo 1), key U_<userId>", w:Row(honor, "U_101"))
	check(#w:Calls("Set", "HH_Rank_STUDIO") == 0 and #w:Calls("Set", "HH_Rank_B1") == 0, "a live PRE server writes PRE stores only")
	w.Ranking.Credit(h, "Honor", 2)
	w:Advance(60)
	w:Tick()
	check(w:Row(honor, "U_101") == 701, "a dirty player is written at most every WriteEverySeconds (120 s)")
	w:Advance(60)
	w:Tick()
	check(w:Row(honor, "U_101") == 901, "120 s after the last write the new value lands")
	local sets = #w:Calls("Set")
	w.Ranking.DebugWrite(h)
	w:Tick()
	check(#w:Calls("Set") == sets, "an unchanged value is never written again (this server's Written cache)")
	-- budget below MinBudget: skipped and retried
	w.Budget[SET] = 4
	w.Ranking.Credit(h, "Honor", 1)
	w:Advance(120)
	local skipped = w.Ranking.Stats.Skipped
	w:Tick()
	check(w:Row(honor, "U_101") == 901 and w.Ranking.Stats.Skipped > skipped, "SetIncrementSortedAsync budget 4 < MinBudget 5: skipped")
	w.Budget[SET] = 5
	w:Advance(120)
	w:Tick()
	check(w:Row(honor, "U_101") == 1001, "budget back: the write lands", w:Row(honor, "U_101"))
	-- several boards and faction codes
	w.Ranking.Credit(h, "PvP", 2)
	w:Advance(120)
	w:Tick()
	check(w:Row(storeName("PRE", "PvP", 2962), "U_101") == 201, "a Halo player's PvP row: faction code 1")
	-- a failed write is retried
	local x = w:Join(102, "Horns")
	w.Ranking.Credit(x, "Infamy", 3)
	w.Fail[storeName("PRE", "Infamy", 2962) .. ":Set"] = 1
	w.AllowWarn = "failed"
	w:Tick()
	check(w:Row(storeName("PRE", "Infamy", 2962), "U_102") == nil, "a failing SetAsync writes nothing (warned)")
	w:Advance(120)
	w:Tick()
	check(w:Row(storeName("PRE", "Infamy", 2962), "U_102") == 302, "the failed write is retried (Horns code 2)", w:Row(storeName("PRE", "Infamy", 2962), "U_102"))
	-- eligibility (global boards only)
	local young = w:Join(103, "Halo", { AccountAge = 2 })
	local short = w:Join(104, "Halo", { Playtime = 1799 })
	local tainted = w:Join(105, "Halo", { Data = { DebugTainted = true } })
	for _, p in { young, short, tainted } do w.Ranking.Credit(p, "Honor", 4) end
	w:Advance(120)
	w:Tick()
	check(w:Row(honor, "U_103") == nil and w:Row(honor, "U_104") == nil, "accounts < 3 days / play < 30 min are never written to the global board")
	check(w:Row(honor, "U_105") == nil, "a DebugTainted save never reaches a PRE board")
	local ex = rankWorld({ EditConfig = function(c) c.Ranking.ExcludeUserIds = { 106 } end })
	local exp = ex:Join(106, "Halo")
	ex.Ranking.Credit(exp, "Honor", 4)
	ex:Tick()
	check(ex:Row(honor, "U_106") == nil, "ExcludeUserIds are never written")
	-- STUDIO season: its own stores, eligibility and taint skipped
	local s = rankWorld({ Studio = true })
	local sp = s:Join(-1, "Halo", { AccountAge = 0, Playtime = 0, Data = { DebugTainted = true } })
	s.Ranking.Credit(sp, "Honor", 2)
	s:Tick()
	check(s:Row(storeName("STUDIO", "Honor", 2962), "U_-1") == 201, "STUDIO season: HH_Rank_STUDIO_* (Studio ids, new accounts, tainted saves)")
	local touched = {}
	for _, c in s.DSCalls do
		if string.find(c.Store, "HH_Rank", 1, true) and not string.find(c.Store, "STUDIO", 1, true) then table.insert(touched, c.Store) end
	end
	check(#touched == 0, "STUDIO season never touches PRE / B1 stores", table.concat(touched, ","))
	-- faction change: the old weekly board row goes at once, the PvP row follows the new faction code
	local f = rankWorld()
	local fp = f:Join(101, "Halo")
	f.Ranking.Credit(fp, "Honor", 5)
	f.Ranking.Credit(fp, "PvP", 1)
	f:Tick()
	f:Advance(5)
	f:SetFaction(fp, "Horns")
	check(f:Rank(fp).Honor == 0 and fp:GetAttribute("WeekHonor") == 0, "faction change: the old faction's weekly points are gone")
	f:Tick()
	check(f:Row(honor, "U_101") == nil and f:Row(storeName("PRE", "PvP", 2962), "U_101") == 102,
		"faction change: RemoveAsync on the old board, PvP row rewritten with the Horns code at once", tostring(f:Row(storeName("PRE", "PvP", 2962), "U_101")))
	-- back to Halo the same week: a new Honor row again
	f:SetFaction(fp, "Halo")
	f.Ranking.Credit(fp, "Honor", 1)
	f:Tick()
	check(f:Row(honor, "U_101") == 101, "back in Halo the same week: the new row is written (the removal is not cached as 'written')", tostring(f:Row(honor, "U_101")))
	-- leaving writes at once
	local l = rankWorld()
	local lp = l:Join(101, "Halo")
	l.Ranking.Credit(lp, "Honor", 1)
	l:Tick()
	l.Ranking.Credit(lp, "Honor", 1)
	l:Leave(lp)
	l:RunSpawned()
	check(l:Row(honor, "U_101") == 201, "PlayerLeaving: the last points are written at once (no 120 s wait)", l:Row(honor, "U_101"))
	-- a removed row is never resurrected by a stale snapshot
	check(#l.Ranking.Stats.Refused == 0, "no refusals in the write tests")
end)

------------------------------------------------------------------ 15. the week flips while online
runGroup("week-flip", function()
	local w = rankWorld({ Time = MON63 - 30 })
	local h = w:Join(101, "Halo")
	w.Ranking.Credit(h, "Honor", 4)
	w.Ranking.Credit(h, "PvP", 2)
	w:Tick()
	w.Ranking.Credit(h, "Honor", 1) -- dirty, inside the 120 s gap
	w:Rank(h).Victims.U5 = 2
	w:Advance(60) -- Monday 00:00:30 KST: week 2963
	w:Tick()
	check(w:Row(storeName("PRE", "Honor", 2962), "U_101") == 501 and w:Row(storeName("PRE", "PvP", 2962), "U_101") == 201,
		"online across Monday 00:00 KST: last week's final points land in last week's stores", tostring(w:Row(storeName("PRE", "Honor", 2962), "U_101")))
	local r = w:Rank(h)
	check(r.WeekId == 2963 and r.Honor == 0 and r.PvP == 0 and next(r.Victims) == nil and h:GetAttribute("WeekHonor") == 0,
		"the week fields start over (points, Victims, WeekHonor attribute)", show(r))
	check(w:Row(storeName("PRE", "Honor", 2963), "U_101") == nil, "zero points are never written to the new week")
	check(w.GameState:GetAttribute("RankWeekId") == 2963 and w.GameState:GetAttribute("RankWeekEndsAt") == C0.WeekStart(2964),
		"GameState RankWeekId / RankWeekEndsAt follow the week")
	w.Ranking.Credit(h, "Honor", 2)
	w:Advance(120)
	w:Tick()
	check(w:Row(storeName("PRE", "Honor", 2963), "U_101") == 201 and w:Row(storeName("PRE", "Honor", 2962), "U_101") == 501,
		"new points go to the new week's store only")
	-- a faction change in the last seconds of Sunday: last week's old-faction row is still removed after the flip
	local wd = rankWorld({ Time = MON63 - 30 })
	local dp = wd:Join(101, "Halo")
	wd.Ranking.Credit(dp, "Honor", 50)
	wd:Tick()
	wd:Advance(25)
	wd:SetFaction(dp, "Horns")
	wd:Advance(10) -- Monday 00:00:05: the next loop step comes after the flip
	wd:Tick()
	check(wd:Row(storeName("PRE", "Honor", 2962), "U_101") == nil and next(wd:Rank(dp).Drop) == nil,
		"a removal pending at the Monday flip still removes LAST week's row", show(wd:Rank(dp).Drop))
	-- a credit arriving first after the flip (before the loop) also snapshots last week
	local w2 = rankWorld({ Time = MON63 - 10 })
	local h2 = w2:Join(101, "Halo")
	w2.Ranking.Credit(h2, "Honor", 3)
	w2:Advance(20)
	w2.Ranking.Credit(h2, "Honor", 1)
	check(w2:Rank(h2).WeekId == 2963 and w2:Rank(h2).Honor == 1, "a credit after the flip starts the new week")
	w2:Tick()
	check(w2:Row(storeName("PRE", "Honor", 2962), "U_101") == 301 and w2:Row(storeName("PRE", "Honor", 2963), "U_101") == 101,
		"…and last week's 3 still land in last week's store")
end)

------------------------------------------------------------------ 15b. sessions, races, persisted removals, seasons
runGroup("writes-sessions", function()
	local honor = storeName("PRE", "Honor", 2962)
	-- a server hop: what this server wrote in an EARLIER session is never trusted (another server wrote since)
	local stores = {}
	local A = rankWorld({ Stores = stores })
	local B = rankWorld({ Stores = stores })
	local a = A:Join(101, "Halo", { Hide = true })
	A.Ranking.Credit(a, "Honor", 10)
	A:Tick()
	check(A:Row(honor, "U_101") == 1011, "server A wrote the hidden row")
	local save = deepCopy(A.Data[a])
	A:Leave(a) -- (its leave thread has not run yet when the player comes back below)
	local b = B:Join(101, "Halo", { Saved = save })
	B:Advance(1)
	B.Remotes.SetAnnounceName.OnServerEvent:Fire(b, false)
	B:Tick()
	check(B:Row(honor, "U_101") == 1001, "server B shows the name again (row rewritten)")
	save = deepCopy(B.Data[b])
	B:Leave(b)
	B:RunSpawned()
	local a2 = A:Join(101, "Halo", { Saved = save })
	A:Advance(1)
	A.Remotes.SetAnnounceName.OnServerEvent:Fire(a2, true)
	A:Tick()
	check(A:Row(honor, "U_101") == 1011, "back on A, hiding again really rewrites the row (A's cache from the first session is dropped at join)",
		A:Row(honor, "U_101"))
	-- a removal that failed is kept in the save and done by the next server
	local stores2 = {}
	local D = rankWorld({ Stores = stores2 })
	local d = D:Join(201, "Halo")
	D.Ranking.Credit(d, "Honor", 4)
	D:Tick()
	D.Fail[honor .. ":Remove"] = 99
	D.AllowWarn = "failed"
	D:SetFaction(d, "Horns")
	D:Tick()
	check(D:Row(honor, "U_201") == 401 and D:Rank(d).Drop.Honor == 2962, "a failed RemoveAsync stays in Rank.Drop (saved, with its week)",
		show(D:Rank(d).Drop))
	local crashed = deepCopy(D.Data[d]) -- the server goes away before it could retry
	local E = rankWorld({ Stores = stores2 })
	local e = E:Join(201, "Horns", { Saved = crashed })
	E:Tick()
	check(E:Row(honor, "U_201") == nil and next(E:Rank(e).Drop) == nil, "the next server removes the old faction's row from the saved Drop",
		tostring(E:Row(honor, "U_201")) .. " " .. show(E:Rank(e)) .. " calls " .. #E:Calls("Remove"))
	-- back in that faction with points before the removal: the row is overwritten, no RemoveAsync
	local F = rankWorld()
	local f = F:Join(202, "Halo")
	F.Ranking.Credit(f, "Honor", 3)
	F:Tick()
	F:SetFaction(f, "Horns")
	F:SetFaction(f, "Halo")
	F.Ranking.Credit(f, "Honor", 1)
	F:Tick()
	check(F:Row(honor, "U_202") == 101 and #F:Calls("Remove", honor) == 0 and next(F:Rank(f).Drop) == nil,
		"back in Halo with points before the removal: overwritten, Drop cleared", show(F:Rank(f)))
	-- a change made while a write is in flight (SetAsync yields) is not lost
	local G = rankWorld()
	local g = G:Join(301, "Halo")
	G.Ranking.Credit(g, "Honor", 2)
	G.OnSet = function(name)
		if name == honor then
			G.OnSet = nil
			G.Ranking.Credit(g, "Honor", 1)
		end
	end
	G:Tick()
	check(G:Row(honor, "U_301") == 201, "the write carried the 2 points it started with")
	G:Advance(120)
	G:Tick()
	check(G:Row(honor, "U_301") == 301, "the point credited during the write is written at the next turn (still dirty)", G:Row(honor, "U_301"))
	G.OnSet = function(name)
		if name == honor then
			G.OnSet = nil
			G.Data[g].HideAnnounceName = true
			g:SetAttribute("HideAnnounceName", true)
			G.Ranking.MarkHideChanged(g)
		end
	end
	G.Ranking.Credit(g, "Honor", 1)
	G:Advance(120)
	G:Tick()
	check(G:Row(honor, "U_301") == 401 and G:Rank(g).HideSynced == false, "a hide toggle during the write: that write was shown, HideSynced not yet set")
	G:Tick()
	check(G:Row(honor, "U_301") == 411 and G:Rank(g).HideSynced == true, "…and the next loop step writes the hidden row", G:Row(honor, "U_301"))
	-- points of another season are dropped (a Studio test on the live place's saves)
	local Ss = rankWorld()
	local sp = Ss:Join(401, "Halo", { Data = { Rank = { WeekId = 2962, Season = "STUDIO", Honor = 7, PvP = 2 } } })
	check(Ss:Rank(sp).Honor == 0 and Ss:Rank(sp).PvP == 0 and Ss:Rank(sp).Season == "PRE", "STUDIO-season points are dropped on a PRE server")
	Ss:Tick()
	check(Ss:Row(honor, "U_401") == nil, "…and never written to a PRE board")
	-- a Studio test on a live save (the working Studio uses the live saves): the save's live ranking is never touched
	local St = rankWorld({ Studio = true })
	local stp = St:Join(402, "Halo", { Data = { Rank = { WeekId = 2962, Season = "PRE", Honor = 7, Victims = { U9 = 2 } },
		RankReward = RR(2962, "Honor", 1), Outlaw = OUT(0), Titles = { RankHonor1 = 1 }, TitleSel = "RankHonor1" } })
	check(stp:GetAttribute("WeekHonor") == 0 and St:Rank(stp).Honor == 7 and St:Rank(stp).Season == "PRE",
		"Studio on a live save: the session counts from 0 in a shadow; the save keeps its PRE week", show(St:Rank(stp)))
	St.Ranking.Credit(stp, "Honor", 2)
	St:Tick()
	check(St:Row(storeName("STUDIO", "Honor", 2962), "U_402") == 201 and St:Rank(stp).Honor == 7 and stp:GetAttribute("WeekHonor") == 2,
		"Studio points go to the STUDIO board only; the saved PRE points stay 7")
	check(St.Title.Owns(stp, "RankHonor1") and St.Data[stp].TitleSel == "RankHonor1" and stp:GetAttribute("RankReward") == "",
		"Studio never removes a live title (its live reward is just off for the session)")
	St.Ranking.Credit(stp, "PvP", 3)
	St.Ranking.DebugSettle()
	check(stp:GetAttribute("Outlaw") == true and St.Data[stp].Outlaw.WeekId == 0 and St.Data[stp].RankReward.Season == "PRE",
		"a Studio DebugSettle acts for the session only (the saved results stay the live ones)", show(St.Data[stp].RankReward))
	local liveAgain = deepCopy(St.Data[stp])
	St:Leave(stp)
	St:RunSpawned()
	local Lv = rankWorld()
	local lp = Lv:Join(402, "Halo", { Saved = liveAgain })
	check(Lv:Rank(lp).Honor == 7 and lp:GetAttribute("RankReward") == "Honor" and Lv.Title.Owns(lp, "RankHonor1")
		and lp:GetAttribute("Outlaw") == false, "back on a live server: the PRE week, the reward and the title are all there")
	-- a live server gives a missing week title back
	local Lw = rankWorld({ Time = MON63 + 600 })
	Lw:Seed(storeName("PRE", "Honor", 2962), "U_101", Lw.Ranking.Encode(9, false, "Halo"))
	local lost = Lw:Join(101, "Halo", { Data = { RankReward = RR(2963, "Honor", 1) } })
	Lw:Tick()
	check(Lw.Title.Owns(lost, "RankHonor1") and Lw:CountNotices(lost, string.format(R0.Text.RewardStart, R0.Text.BoardNames.Honor, 1)) == 0,
		"the settle gives a removed week title back (no repeat notice)")
	-- a join with points marks the rows dirty (a last write that never landed is redone)
	local Jn = rankWorld()
	local jp = Jn:Join(501, "Halo", { Data = { Rank = { WeekId = 2962, Season = "PRE", Honor = 5 } } })
	Jn:Tick()
	check(Jn:Row(honor, "U_501") == 501 and Jn:Rank(jp).Honor == 5, "a join with this week's points writes them at the first loop step")
end)

------------------------------------------------------------------ 16. hiding the name (BB37 must-write)
runGroup("hide", function()
	local w = rankWorld()
	local h = w:Join(101, "Halo")
	local honor, pvp = storeName("PRE", "Honor", 2962), storeName("PRE", "PvP", 2962)
	w.Ranking.Credit(h, "Honor", 3)
	w.Ranking.Credit(h, "PvP", 1)
	w:Tick()
	w:Advance(1)
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(h, true)
	check(w.Data[h].HideAnnounceName == true, "the setting is saved")
	w:Tick()
	check(w:Row(honor, "U_101") == 311 and w:Row(pvp, "U_101") == 111, "hide: every row is rewritten with the hidden flag at the next loop step (120 s gap ignored)",
		tostring(w:Row(honor, "U_101")))
	check(w:Rank(h).HideSynced == true, "all rows written -> Rank.HideSynced = true")
	w:Advance(1)
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(h, false)
	w.Budget[SET] = 0
	w:Tick()
	check(w:Row(honor, "U_101") == 311 and w:Rank(h).HideSynced == true, "no budget: still hidden rows, HideSynced not yet false")
	w.Budget[SET] = 100
	w:Advance(10)
	w:Tick()
	check(w:Row(honor, "U_101") == 301 and w:Row(pvp, "U_101") == 101 and w:Rank(h).HideSynced == false,
		"retried at the next loop step (10 s): shown again, HideSynced = false")
	-- a change the last session could not write is redone at join
	local w2 = rankWorld()
	local p2 = w2:Join(102, "Halo", { Hide = true, Data = { Rank = { WeekId = 2962, Season = "PRE", Honor = 2, HideSynced = false } } })
	w2:Tick()
	check(w2:Row(honor, "U_102") == 211 and w2:Rank(p2).HideSynced == true, "PlayerReady: HideSynced ~= HideAnnounceName -> rewritten at once")
	-- an ineligible player has no rows: the change is synced without writes
	local w3 = rankWorld()
	local p3 = w3:Join(103, "Halo", { AccountAge = 1 })
	w3.Ranking.Credit(p3, "Honor", 2)
	w3:Advance(1)
	w3.Remotes.SetAnnounceName.OnServerEvent:Fire(p3, true)
	w3:Tick()
	check(w3:Rank(p3).HideSynced == true and w3:Row(honor, "U_103") == nil, "ineligible: nothing written, HideSynced still follows")
end)

------------------------------------------------------------------ 17. global reads, names and the RequestRankings remote
runGroup("reads", function()
	local w = rankWorld()
	local honor = storeName("PRE", "Honor", 2962)
	local Enc = w.Ranking.Encode
	w:Seed(honor, "U_900", Enc(50, false, "Halo"))
	w:Seed(honor, "U_901", Enc(40, true, "Halo"))
	w:Seed(honor, "U_902", Enc(30, false, "Halo"))
	w:Seed(honor, "U_-3", Enc(20, false, "Halo"))
	w:Seed(honor, "U_101", Enc(10, false, "Halo"))
	w:Seed(honor, "U_102", Enc(8, false, "Halo"))
	w:Seed(honor, "junk", 99999)
	w:Seed(honor, "U_903", Enc(0, false, "Halo"))
	local h = w:Join(101, "Halo", { Hide = true }) -- the stored row was written before the player hid the name
	local s = w:Join(102, "Halo")
	w.Ranking.Credit(h, "Honor", 10)
	local d1, h1, f1 = w.Ranking.Decode(Enc(37, true, "Neutral"))
	check(d1 == 37 and h1 == true and f1 == "Neutral", "Encode / Decode round trip")
	check(w.Ranking.ReadBoard("Honor") == true and w.Ranking.Stats.Reads == 1, "ReadBoard reads this week's store")
	local sorted = w:Calls("Sorted", honor)
	check(#sorted == 1 and sorted[1].Value == R0.TopN, "GetSortedAsync(false, TopN = 50)")
	check(w.UserInfoCalls == 1, "names: one batched GetUserInfosByUserIdsAsync call", w.UserInfoCalls)
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor", "Global")
	local out = w:LastRankings(h)
	check(out ~= nil and out.Board == "Honor" and out.Scope == "Global" and out.WeekId == 2962 and out.WeekEndsAt == MON63,
		"the Rankings answer: board, scope, week and when it ends", show(out and { out.Board, out.Scope, out.WeekId, out.WeekEndsAt }))
	local rows = out and out.Rows or {}
	check(#rows == 6, "junk keys and zero scores are dropped", #rows)
	check(rows[1] and rows[1].UserId == 900 and rows[1].Name == "Disp900" and rows[1].Value == 50 and rows[1].Rank == 1
		and rows[1].Faction == "Halo", "row 1: Roblox DisplayName, value, faction", show(rows[1]))
	check(rows[2] and rows[2].UserId == 0 and rows[2].Name == string.format(C0.Announce.Text.HiddenName, C0.Factions.Halo.Name),
		"a hidden row: UserId 0 and '<진영> 한 명'", show(rows[2]))
	check(rows[4] and rows[4].UserId == -3 and rows[4].Name == "Player3", "a Studio id (<= 0): StudioNames 'Player%d'", show(rows[4]))
	check(rows[5] and rows[5].UserId == 0 and rows[5].Name == string.format(C0.Announce.Text.HiddenName, C0.Factions.Halo.Name),
		"a player in this server is re-masked from the live HideAnnounceName attribute", show(rows[5]))
	check(rows[6] and rows[6].UserId == 102 and rows[6].Name == "Disp102" and rows[6].Sub == "P102",
		"a player in this server also shows the game nickname as Sub", show(rows[6]))
	for _, r in rows do
		check(r.UserId == 0 or not has(tostring(r.Name), "숨"), "no hidden nickname leaks", show(r))
	end
	check(out and out.Me.Rank == 5 and out.Me.Value == 10, "Me: my rank in the cached rows and my live value", show(out and out.Me))
	check(out and out.Me.Note == "Hidden", "Me.Note 'Hidden': my rows show '<진영> 한 명' to others", show(out and out.Me))
	-- the cache serves every request: no extra reads
	for _ = 1, 10 do
		w:Advance(1)
		w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor", "Global")
	end
	check(w.Ranking.Stats.Reads == 1 and #w:Calls("Sorted", honor) == 1, "10 requests never read the DataStore (server cache only)")
	-- remote validation and the 1 s rate limit
	local fired = #w.Fired
	w:Advance(1)
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor")
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor", "Global", 1)
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Nope", "Global")
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor", "World")
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, 1, "Global")
	check(#w.Fired == fired, "wrong argument count / board / scope: ignored", #w.Fired - fired)
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor", "Server")
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor", "Server")
	check(#w.Fired == fired + 1, "RateLimits.RequestRankings: a second request inside 1 s is ignored")
	w.Ready[s] = nil
	w:Advance(1)
	w.Remotes.RequestRankings.OnServerEvent:Fire(s, "Honor", "Global")
	check(#w.Fired == fired + 1, "a player who is not ready gets nothing")
	w.Ready[s] = true
	-- names are cached for an hour; a failing lookup falls back to '플레이어'
	w.Ranking.ReadBoard("Honor")
	check(w.UserInfoCalls == 1, "a second read inside NameCacheSeconds asks no names", w.UserInfoCalls)
	w:Seed(honor, "U_904", Enc(60, false, "Halo"))
	w.UserInfoFails = true
	w.AllowWarn = { "name lookup failed", "read Honor failed" }
	w.Ranking.ReadBoard("Honor")
	w:Advance(1)
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor", "Global")
	out = w:LastRankings(h)
	check(out and out.Rows[1].UserId == 904 and out.Rows[1].Name == R0.Text.Unknown, "a failed name lookup shows '플레이어'", show(out and out.Rows[1]))
	-- budget / read failure keep the old cache
	local reads = w.Ranking.Stats.Reads
	w.Budget[SORTED] = 1
	check(w.Ranking.ReadBoard("Honor") == false and w.Ranking.Stats.Reads == reads, "GetSortedAsync budget 1 < MinReadBudget 2: no read")
	w.Budget[SORTED] = 100
	w.Fail[honor .. ":Sorted"] = 1
	check(w.Ranking.ReadBoard("Honor") == false, "a failing read returns false")
	w:Advance(1)
	w.Remotes.RequestRankings.OnServerEvent:Fire(h, "Honor", "Global")
	out = w:LastRankings(h)
	check(out and #out.Rows == 7, "…and the last good cache is still served", out and #out.Rows)
	-- the Server scope: this server's live points, faction filtered, PublicName, Test tag
	local w2 = rankWorld()
	local a = w2:Join(101, "Halo")
	local b = w2:Join(102, "Halo", { Hide = true })
	local c = w2:Join(103, "Horns")
	local t = w2:Join(104, "Halo", { Data = { DebugTainted = true } })
	w2.Ranking.Credit(a, "Honor", 2)
	w2.Ranking.Credit(b, "Honor", 5)
	w2.Ranking.Credit(t, "Honor", 2)
	w2.Ranking.Credit(c, "PvP", 4)
	w2.Ranking.Credit(a, "PvP", 1)
	w2:Rank(c).Honor = 9 -- a Horns player's leftover Honor points never show on the Halo board
	w2.Remotes.RequestRankings.OnServerEvent:Fire(a, "Honor", "Server")
	out = w2:LastRankings(a)
	local sr = out and out.Rows or {}
	check(#sr == 3 and sr[1].UserId == 0 and sr[1].Value == 5 and sr[2].UserId == 101 and sr[3].UserId == 104,
		"Server scope: Halo players only, by value then UserId, hidden -> UserId 0", show(sr))
	check(sr[1] and sr[1].Name == string.format(C0.Announce.Text.HiddenName, C0.Factions.Halo.Name) and sr[3].Test == true
		and sr[2].Test == nil, "Server scope: PublicName, DebugTainted rows tagged Test", show(sr))
	check(out and out.Me.Rank == 2 and out.Me.Value == 2, "Server scope: Me.Rank", show(out and out.Me))
	w2:Advance(1)
	w2.Remotes.RequestRankings.OnServerEvent:Fire(a, "PvP", "Server")
	out = w2:LastRankings(a)
	check(out and #out.Rows == 2 and out.Rows[1].UserId == 103 and out.Rows[1].Faction == "Horns", "the PvP board lists every faction", show(out and out.Rows))
	w2:Advance(1)
	w2.Remotes.RequestRankings.OnServerEvent:Fire(a, "Artisan", "Global")
	out = w2:LastRankings(a)
	check(out and #out.Rows == 0 and out.Me.Value == 0, "an unread board is empty (the client shows '아직 기록이 없어요')")
	-- notes: ineligible (Global) and private servers
	local w3 = rankWorld()
	local y = w3:Join(105, "Halo", { AccountAge = 1 })
	w3.Remotes.RequestRankings.OnServerEvent:Fire(y, "Honor", "Global")
	check(w3:LastRankings(y).Me.Note == "Ineligible", "Me.Note 'Ineligible' on the global board for a new account")
	local w4 = rankWorld({ PrivateServerId = "vip" })
	local z = w4:Join(106, "Halo")
	w4.Remotes.RequestRankings.OnServerEvent:Fire(z, "Honor", "Server")
	check(w4:LastRankings(z).Me.Note == "Private", "Me.Note 'Private' on a private server")
	-- staggered reads: board i first at (i - 1) * ReadStagger, then every RefreshSeconds
	local w5 = rankWorld()
	local order = {}
	for step = 0, 200, 5 do
		local n0 = #w5.DSCalls
		w5.Ranking.TickRead()
		for i = n0 + 1, #w5.DSCalls do
			local c = w5.DSCalls[i]
			if c.Op == "Sorted" then table.insert(order, step .. ":" .. string.match(c.Store, "HH_Rank_PRE_(%a+)_")) end
		end
		w5:Advance(5)
	end
	check(table.concat(order, ",") == "0:Honor,45:Infamy,90:Artisan,135:PvP,180:Honor", "reads staggered by 45 s, each board every 180 s",
		table.concat(order, ","))
	-- last week's cache is never served after the flip
	local w6 = rankWorld({ Time = MON63 - 5 })
	local q = w6:Join(101, "Halo")
	w6:Seed(storeName("PRE", "Honor", 2962), "U_900", Enc(5, false, "Halo"))
	w6.Ranking.ReadBoard("Honor")
	w6:Advance(10)
	w6.Remotes.RequestRankings.OnServerEvent:Fire(q, "Honor", "Global")
	check(#w6:LastRankings(q).Rows == 0 and w6:LastRankings(q).WeekId == 2963, "after Monday 00:00 the old week's cache is not shown")
end)

------------------------------------------------------------------ 18. the one weekly settle (A23-22 / 23 / 24, D4, D5)
local function seedLastWeek(w)
	local Enc = w.Ranking.Encode
	for key, v in { U_101 = 9, U_102 = 7, U_103 = 5, U_104 = 3 } do w:Seed(storeName("PRE", "Honor", 2962), key, Enc(v, false, "Halo")) end
	w:Seed(storeName("PRE", "Infamy", 2962), "U_201", Enc(4, false, "Horns"))
	w:Seed(storeName("PRE", "Artisan", 2962), "U_301", Enc(6, false, "Neutral"))
	for key, v in { U_401 = 5, U_402 = 3, U_403 = 2, U_404 = 1 } do w:Seed(storeName("PRE", "PvP", 2962), key, Enc(v, false, "Horns")) end
end

------------------------------------------------------------------ 17b. ties (검수 decision: 1, 2, 2, 4 and the low digits never decide)
runGroup("ties", function()
	local w = rankWorld({ Time = MON63 + 600 })
	local Enc = w.Ranking.Encode
	local H, I, P = storeName("PRE", "Honor", 2962), storeName("PRE", "Infamy", 2962), storeName("PRE", "PvP", 2962)
	w:Seed(H, "U_101", Enc(9, false, "Halo"))
	w:Seed(H, "U_102", Enc(7, false, "Halo")) -- 701
	w:Seed(H, "U_103", Enc(7, true, "Halo")) -- 711: the hidden bit sorts it first in the store
	w:Seed(H, "U_104", Enc(5, true, "Halo"))
	w:Seed(H, "U_105", Enc(5, false, "Halo"))
	for key, v in { U_201 = 8, U_202 = 6, U_203 = 4, U_204 = 4, U_205 = 4, U_206 = 3 } do
		w:Seed(I, key, Enc(v, key == "U_204", "Horns"))
	end
	w:Seed(P, "U_401", Enc(5, false, "Horns"))
	w:Seed(P, "U_402", Enc(3, false, "Halo")) -- 301
	w:Seed(P, "U_403", Enc(3, false, "Horns")) -- 302: the faction code would sort it first
	w:Seed(P, "U_404", Enc(3, true, "Horns"))
	w:Seed(P, "U_405", Enc(2, false, "Horns"))
	local h102 = w:Join(102, "Halo")
	local h103 = w:Join(103, "Halo")
	local h104 = w:Join(104, "Halo")
	local o402 = w:Join(402, "Halo")
	local o403 = w:Join(403, "Horns")
	local i205 = w:Join(205, "Horns")
	w:Tick()
	local doc = w:Row("HH_RankSettle_PRE", "W2962")
	check(doc and table.concat(doc.Boards.Honor, ",") == "101,102,103" and table.concat(doc.Ranks.Honor, ",") == "1,2,2",
		"Honor 9 / 7 / 7 / 5 / 5: ranks 1, 2, 2 (the two 5s are 4th: no reward)", show(doc and { doc.Boards.Honor, doc.Ranks.Honor }))
	check(doc and table.concat(doc.Boards.Infamy, ",") == "201,202,203,204,205" and table.concat(doc.Ranks.Infamy, ",") == "1,2,3,3,3",
		"everyone tied with 3rd gets 3rd (Infamy 8 / 6 / 4 / 4 / 4)", show(doc and { doc.Boards.Infamy, doc.Ranks.Infamy }))
	check(doc and table.concat(doc.Boards.PvP, ",") == "401,402,403,404" and table.concat(doc.Ranks.PvP, ",") == "1,2,2,2",
		"PvP 5 / 3 / 3 / 3 / 2: the three 3s are all 2nd (floor 3 kept)", show(doc and { doc.Boards.PvP, doc.Ranks.PvP }))
	check(w.Data[h102].RankReward.Rank == 2 and w.Data[h103].RankReward.Rank == 2 and w.Title.Owns(h102, "RankHonor2")
		and w.Title.Owns(h103, "RankHonor2"), "a shown and a hidden player tied on 7: both rank 2 with the title")
	check(w.Data[h104].RankReward.Board == "", "tied 4th: no reward")
	check(w.Data[i205].RankReward.Rank == 3 and o402:GetAttribute("Outlaw") == true and o403:GetAttribute("Outlaw") == true,
		"tied 3rd gets the reward; a Halo and a Horns tied on 3 unfair KOs are both outlaws")
	-- the display: same score = same rank number, the order inside a tie by UserId (never the hidden bit)
	local w2 = rankWorld()
	local H2 = storeName("PRE", "Honor", 2962)
	w2:Seed(H2, "U_101", Enc(9, false, "Halo"))
	w2:Seed(H2, "U_102", Enc(7, false, "Halo"))
	w2:Seed(H2, "U_103", Enc(7, true, "Halo"))
	w2:Seed(H2, "U_104", Enc(5, false, "Halo"))
	local me = w2:Join(103, "Halo", { Hide = true })
	w2.Ranking.Credit(me, "Honor", 7)
	w2.Ranking.ReadBoard("Honor")
	w2.Remotes.RequestRankings.OnServerEvent:Fire(me, "Honor", "Global")
	local out = w2:LastRankings(me)
	local ranks, ids = {}, {}
	for _, r in out and out.Rows or {} do
		table.insert(ranks, r.Rank)
		table.insert(ids, r.UserId)
	end
	check(table.concat(ranks, ",") == "1,2,2,4" and table.concat(ids, ",") == "101,102,0,104",
		"global rows: ranks 1, 2, 2, 4; inside the tie UserId order (the hidden 103 after 102)", table.concat(ranks, ",") .. " | " .. table.concat(ids, ","))
	check(out and out.Me.Rank == 2, "Me.Rank = the shared rank", show(out and out.Me))
	-- the server board too
	local w3 = rankWorld()
	local a = w3:Join(101, "Halo")
	local b = w3:Join(102, "Halo", { Hide = true })
	local c = w3:Join(103, "Halo")
	w3.Ranking.Credit(a, "Honor", 4)
	w3.Ranking.Credit(b, "Honor", 4)
	w3.Ranking.Credit(c, "Honor", 2)
	w3.Remotes.RequestRankings.OnServerEvent:Fire(c, "Honor", "Server")
	out = w3:LastRankings(c)
	ranks = {}
	for _, r in out and out.Rows or {} do table.insert(ranks, r.Rank) end
	check(table.concat(ranks, ",") == "1,1,3" and out.Me.Rank == 3, "server rows: 4 / 4 / 2 -> ranks 1, 1, 3", table.concat(ranks, ","))
	-- a tie group longer than the page is logged
	local w4 = rankWorld({ Time = MON63 + 600, EditConfig = function(cfg) cfg.Ranking.TopN = 4 end })
	for i = 1, 6 do w4:Seed(storeName("PRE", "Honor", 2962), "U_" .. (600 + i), Enc(5, false, "Halo")) end
	w4.AllowWarn = "a tie at the top"
	w4:Tick()
	local warned = false
	for _, t in w4.Warnings do if has(t, "a tie at the top") then warned = true end end
	check(warned, "a tie that fills the whole read page is logged (rows past it are not read)")
end)

runGroup("settle", function()
	local stores = {}
	local A = rankWorld({ Stores = stores, Time = MON63 + 599 })
	seedLastWeek(A)
	local a101 = A:Join(101, "Halo")
	local a401 = A:Join(401, "Horns", { Attrs = { AutoCombatUnlocked = true } })
	local a403 = A:Join(403, "Horns")
	local a104 = A:Join(104, "Halo")
	A:Tick()
	check(A.Ranking.Stats.Settles == 0 and A:Row("HH_RankSettle_PRE", "W2962") == nil, "599 s after Monday 00:00 KST: no settle yet")
	A:Advance(1)
	A:Tick()
	local doc = A:Row("HH_RankSettle_PRE", "W2962")
	check(A.Ranking.Stats.Settles == 1 and type(doc) == "table" and doc.Week == 2962, "600 s after Monday: one settle document (key W<week>, season in the store name)", show(doc))
	check(doc and table.concat(doc.Boards.Honor, ",") == "101,102,103" and table.concat(doc.Boards.Infamy, ",") == "201"
		and table.concat(doc.Boards.Artisan, ",") == "301", "reward lists: top 3 of Honor / Infamy / Artisan", show(doc and doc.Boards))
	check(doc and table.concat(doc.Boards.PvP, ",") == "401,402", "D5: PvP top 3 with at least 3 points (2 points is never an outlaw)", show(doc and doc.Boards.PvP))
	local rr = A.Data[a101].RankReward
	check(rr.WeekId == 2963 and rr.Board == "Honor" and rr.Rank == 1 and a101:GetAttribute("RankReward") == "Honor"
		and a101:GetAttribute("RankRewardRank") == 1, "Honor #1: RankReward for THIS week (2963) + attributes", show(rr))
	check(A.Title.Owns(a101, "RankHonor1") and has(a101:GetAttribute("TitlesOwned"), "RankHonor1"), "Honor #1: the timed title '이번 주 명예 1위'")
	check(A:CountNotices(a101, string.format(R0.Text.RewardStart, R0.Text.BoardNames.Honor, 1)) == 1, "Honor #1 is told once")
	check(A.Data[a401].Outlaw.WeekId == 2963 and a401:GetAttribute("Outlaw") == true, "PvP #1 with 5 points: outlaw this week")
	check(A:CountNotices(a401, string.format(R0.Text.OutlawStart, 1)) == 1, "the outlaw is told once")
	check(A.Data[a403].Outlaw.WeekId == 0 and a403:GetAttribute("Outlaw") ~= true, "PvP #3 with 2 points: no outlaw (D5)")
	check(A.Data[a104].RankReward.Board == "" and (a104:GetAttribute("RankReward") or "") == "", "Honor #4: nothing")
	-- server B (same stores) applies the stored document: no second build
	local B = rankWorld({ Stores = stores, Time = MON63 + 700 })
	local b102 = B:Join(102, "Halo")
	local b103 = B:Join(103, "Horns") -- Honor #3 switched to Horns since
	local b402 = B:Join(402, "Halo")
	B:Tick()
	local lastWeekReads = 0
	for _, c in B:Calls("Sorted", "HH_Rank_PRE") do
		if string.find(c.Store, "_W2962", 1, true) then lastWeekReads += 1 end
	end
	check(lastWeekReads == 0 and #B:Calls("Update", "HH_RankSettle") == 0, "server B never rebuilds: it reads the stored document", lastWeekReads)
	check(B.Data[b102].RankReward.Rank == 2 and B.Title.Owns(b102, "RankHonor2"), "server B: Honor #2 gets rank 2 + its title")
	check(b402:GetAttribute("Outlaw") == true, "server B: PvP #2 (a Halo) is an outlaw too")
	check(B.Data[b103].RankReward.Rank == 3 and B.Title.Owns(b103, "RankHonor3") and b103:GetAttribute("RankReward") == ""
		and B:CountNotices(b103, string.format(R0.Text.RewardStartOff, R0.Text.BoardNames.Honor, 3, C0.Factions.Halo.Name)) == 1
		and B:CountNotices(b103, string.format(R0.Text.RewardStart, R0.Text.BoardNames.Honor, 3)) == 0,
		"a top 3 who switched faction: the title, and the line '보상은 빛의 기사단에 있을 때만' instead of '+10% 받았어요'")
	-- applying again changes nothing
	A:Advance(10)
	A:Tick()
	A.Ranking.RefreshEffects(a101)
	check(A.Ranking.Stats.Settles == 1 and A:CountNotices(a101, string.format(R0.Text.RewardStart, R0.Text.BoardNames.Honor, 1)) == 1
		and A:CountNotices(a401, string.format(R0.Text.OutlawStart, 1)) == 1, "a settled week is applied once (no repeat notices)")
	-- a player who joins after the settle gets it at PlayerReady; a rejoin does not repeat it
	local a301 = A:Join(301, "Neutral")
	check(A.Data[a301].RankReward.Board == "Artisan" and a301:GetAttribute("RankReward") == "Artisan" and A.Title.Owns(a301, "RankArtisan1"),
		"joining after the settle: the Artisan #1 reward at PlayerReady")
	local saved = deepCopy(A.Data[a301])
	A:Leave(a301)
	A:RunSpawned()
	local again = A:Join(301, "Neutral", { Saved = saved })
	check(A:CountNotices(again, string.format(R0.Text.RewardStart, R0.Text.BoardNames.Artisan, 1)) == 0 and again:GetAttribute("RankReward") == "Artisan",
		"a rejoin with the saved result: still on, not announced again")
	local savedOutlaw = deepCopy(A.Data[a401])
	A:Leave(a401)
	A:RunSpawned()
	local back = A:Join(401, "Horns", { Saved = savedOutlaw })
	check(back:GetAttribute("Outlaw") == true and A:CountNotices(back, string.format(R0.Text.OutlawStart, 1)) == 0,
		"an outlaw's rejoin: still an outlaw, not announced again")
	-- first writer wins: another server's document lands between this server's read and its UpdateAsync
	local stores2 = {}
	local C = rankWorld({ Stores = stores2, Time = MON63 + 600 })
	seedLastWeek(C)
	local c101 = C:Join(101, "Halo")
	C.BeforeUpdate = function(name, key)
		if name == "HH_RankSettle_PRE" and key == "W2962" and stores2[name].Rows[key] == nil then
			stores2[name].Rows[key] = { Week = 2962, Boards = { Honor = { 777 }, Infamy = {}, Artisan = {}, PvP = {} }, At = 1 }
		end
	end
	C:Tick()
	check(C.Data[c101].RankReward.Board == "" and C:Row("HH_RankSettle_PRE", "W2962").Boards.Honor[1] == 777,
		"UpdateAsync keeps the first writer's document; this server applies that one", show(C:Row("HH_RankSettle_PRE", "W2962")))
	-- a failing read is retried after SettleRetrySeconds and never replaced by this server's board
	local E = rankWorld({ Time = MON63 + 600 })
	seedLastWeek(E)
	local e101 = E:Join(101, "Halo")
	E.Ranking.Credit(e101, "Honor", 2) -- this week's live points must never stand in for last week
	E.Fail[storeName("PRE", "Honor", 2962) .. ":Sorted"] = 1 -- last week's board (this week's reads are not touched)
	E.AllowWarn = "settle"
	E:Tick()
	check(E:Row("HH_RankSettle_PRE", "W2962") == nil and E.Ranking.Stats.Settles == 0 and E.Data[e101].RankReward.Board == "",
		"a failed board read: no document, nothing applied (no per-server lists)")
	E:Advance(30)
	local gets = #E:Calls("Get", "HH_RankSettle")
	E:Tick()
	check(#E:Calls("Get", "HH_RankSettle") == gets, "no retry before SettleRetrySeconds (60 s)")
	E:Advance(30)
	E:Tick()
	check(E.Ranking.Stats.Settles == 1 and E.Data[e101].RankReward.Rank == 1, "retried after 60 s: settled from the global boards")
	-- D4: 2 h of failed board reads -> the week is skipped, and the skip is STORED so every server agrees
	local stores3 = {}
	local F = rankWorld({ Stores = stores3, Time = MON63 + 600 })
	seedLastWeek(F)
	local f101 = F:Join(101, "Halo")
	F.Fail[storeName("PRE", "Honor", 2962) .. ":Sorted"] = 1e9
	F.AllowWarn = "settle"
	local minutes = 0
	while F.Ranking.Stats.SettleSkipped == 0 and minutes < 200 do
		F:Tick()
		F:Advance(60)
		minutes += 1
	end
	check(F.Ranking.Stats.SettleSkipped == 1 and F.Ranking.Stats.Settles == 0 and F.Data[f101].RankReward.Board == "",
		"D4: after SettleGiveUpSeconds (2 h) of failed reads the week is skipped (no reward, no outlaw)")
	check(minutes >= 120 and minutes <= 122, "the skip comes after 2 h of retries, not before", minutes)
	local stored3 = F:Row("HH_RankSettle_PRE", "W2962")
	check(type(stored3) == "table" and stored3.Skipped == true and stored3.Boards == nil, "the skip itself is stored (first writer wins)", show(stored3))
	local skippedWarn = false
	for _, text in F.Warnings do if has(text, "settle skipped") then skippedWarn = true end end
	check(skippedWarn, "the skipped week is logged")
	local triesAfter = #F:Calls("Get", "HH_RankSettle")
	F:Advance(600)
	F:Tick()
	check(#F:Calls("Get", "HH_RankSettle") == triesAfter, "a skipped week is never tried again on this server")
	-- a server that starts later (its reads work) applies the same stored skip: nobody gets that week's results
	local H = rankWorld({ Stores = stores3, Time = MON63 + 9000 })
	local h101 = H:Join(101, "Halo")
	local h401 = H:Join(401, "Horns")
	H.AllowWarn = "settle"
	H:Tick()
	check(H.Ranking.Stats.SettleSkipped == 1 and H.Data[h101].RankReward.Board == "" and h401:GetAttribute("Outlaw") ~= true,
		"another server later applies the stored skip too (no per-server results)")
	-- a healthy server stores the real document before this one gives up: this one applies it, never a skip
	local stores5 = {}
	local J2 = rankWorld({ Stores = stores5, Time = MON63 + 600 })
	seedLastWeek(J2)
	local j2 = J2:Join(101, "Halo")
	J2.Fail[storeName("PRE", "Honor", 2962) .. ":Sorted"] = 1e9
	J2.AllowWarn = "settle"
	for _ = 1, 60 do
		J2:Tick()
		J2:Advance(60)
	end
	local K2 = rankWorld({ Stores = stores5, Time = J2.Time })
	K2:Tick() -- a healthy server stores the real document
	for _ = 1, 70 do
		J2:Tick()
		J2:Advance(60)
	end
	check(J2.Ranking.Stats.SettleSkipped == 0 and J2.Data[j2].RankReward.Rank == 1, "a real document another server stored first is applied, never skipped",
		show(J2.Data[j2].RankReward))
	-- the settle store itself unreachable: nothing is applied and nothing is decided locally (it keeps asking)
	local U = rankWorld({ Time = MON63 + 600 })
	seedLastWeek(U)
	local u101 = U:Join(101, "Halo")
	U.Fail["HH_RankSettle_PRE:Get"] = 1e9
	U.AllowWarn = "settle"
	for _ = 1, 150 do
		U:Tick()
		U:Advance(60)
	end
	check(U.Ranking.Stats.SettleSkipped == 0 and U.Ranking.Stats.Settles == 0 and U.Data[u101].RankReward.Board == "",
		"settle store unreachable: no results and no local skip")
	U.Fail["HH_RankSettle_PRE:Get"] = 0
	U:Tick()
	check(U.Ranking.Stats.SettleSkipped == 1 and U:Row("HH_RankSettle_PRE", "W2962").Skipped == true,
		"store back after 2.5 h: the give-up is stored (no week is settled late from fresh reads)")
	-- the STUDIO season writes / reads its own settle store
	local G = rankWorld({ Studio = true, Time = MON63 + 600 })
	G:Join(-1, "Halo")
	G:Tick()
	check(G:Row("HH_RankSettle_STUDIO", "W2962") ~= nil and G:Row("HH_RankSettle_PRE", "W2962") == nil, "STUDIO settles into HH_RankSettle_STUDIO only")
	-- STUDIO without a reachable store: this server's board, from LAST week's points (the snapshot taken at the flip)
	local St = rankWorld({ Studio = true, Time = MON63 - 30 })
	local sa = St:Join(-1, "Horns")
	local sb = St:Join(-2, "Horns")
	St.Ranking.Credit(sa, "PvP", 3)
	St:Advance(630) -- Monday 00:10 KST
	St.Ranking.Credit(sb, "PvP", 4) -- this week's points never stand in for last week
	St.Fail["HH_RankSettle_STUDIO:Get"] = 1
	St:Tick()
	check(sa:GetAttribute("Outlaw") == true and sb:GetAttribute("Outlaw") ~= true and St.Data[sa].Outlaw.Season == "STUDIO",
		"STUDIO fallback settles last week's server board (3 PvP points last week -> outlaw), stamped STUDIO")
end)

------------------------------------------------------------------ 19. the results act for one week, in that faction
runGroup("settle-effects", function()
	local w = rankWorld({ Time = MON63 + 3600 })
	local h = w:Join(101, "Halo", { Data = { RankReward = RR(2963, "Honor", 1), Outlaw = OUT(2963),
		Titles = { RankHonor1 = 1, RankInfamy2 = 1, BetaPioneer = 1 }, TitleSel = "RankHonor1" } })
	check(h:GetAttribute("Outlaw") == true and h:GetAttribute("RankReward") == "Honor" and h:GetAttribute("RankRewardRank") == 1,
		"join in the result week: Outlaw + RankReward attributes")
	check(not w.Title.Owns(h, "RankInfamy2") and w.Title.Owns(h, "RankHonor1") and w.Title.Owns(h, "BetaPioneer"),
		"an old week's timed title is revoked at join; this week's and permanent titles stay")
	-- switching faction mid-week turns the reward off (the saved result stays)
	w:SetFaction(h, "Horns")
	check(h:GetAttribute("RankReward") == "" and h:GetAttribute("RankRewardRank") == 0 and w.Data[h].RankReward.Board == "Honor",
		"another faction: the reward attribute is off, the saved result kept")
	check(h:GetAttribute("Outlaw") == true, "the outlaw week follows the player into any faction")
	w:SetFaction(h, "Halo")
	check(h:GetAttribute("RankReward") == "Honor", "back in Halo the same week: on again")
	-- next week: everything ends
	w:Advance(7 * 86400)
	w:Tick()
	check(h:GetAttribute("Outlaw") == false and h:GetAttribute("RankReward") == "" and h:GetAttribute("RankRewardRank") == 0,
		"the next Monday: Outlaw / RankReward off")
	check(w:CountNotices(h, R0.Text.OutlawEndNoAuto) == 1 and w:CountNotices(h, R0.Text.OutlawEnd) == 0,
		"the end of the outlaw week is announced once (auto combat never unlocked: the NoAuto line)")
	check(not w.Title.Owns(h, "RankHonor1") and w.Data[h].TitleSel == "" and h:GetAttribute("TitleSel") == ""
		and not has(h:GetAttribute("TitlesOwned"), "RankHonor1") and w.Title.Owns(h, "BetaPioneer"),
		"the week's title is removed (the selected title falls back to automatic); BetaPioneer stays")
	w:Advance(10)
	w:Tick()
	check(w:CountNotices(h, R0.Text.OutlawEndNoAuto) == 1, "no second end notice")
	local we = rankWorld({ Time = MON63 + 3600 })
	local unlocked = we:Join(102, "Halo", { Data = { Outlaw = OUT(2963), AutoCombatUnlocked = true } })
	local bully = we:Join(103, "Halo", { Data = { Outlaw = OUT(2963), AutoCombatUnlocked = true }, Attrs = { BullyStacks = 2 } })
	we:Advance(7 * 86400)
	we:Tick()
	check(we:CountNotices(unlocked, R0.Text.OutlawEnd) == 1, "auto combat unlocked: 'auto combat is back'")
	check(we:CountNotices(bully, R0.Text.OutlawEnd) == 0 and we:CountNotices(bully, R0.Text.OutlawEndNoAuto) == 0,
		"still a bully at the end of the outlaw week: no 'auto combat is back' (the bully end comes later)")
	-- seasons: a Studio test's results never act on a live server, and back
	local ws = rankWorld({ Time = MID62 })
	local fromStudio = ws:Join(104, "Halo", { Data = { RankReward = RR(2962, "Honor", 1, "STUDIO"), Outlaw = OUT(2962, "STUDIO"),
		Titles = { RankHonor1 = 1 } } })
	check(fromStudio:GetAttribute("RankReward") == "" and fromStudio:GetAttribute("Outlaw") == false
		and not ws.Title.Owns(fromStudio, "RankHonor1"), "a STUDIO result on a PRE server: off, its title removed")
	local wst = rankWorld({ Studio = true, Time = MID62 })
	local fromLive = wst:Join(105, "Halo", { Data = { RankReward = RR(2962, "Honor", 1), Outlaw = OUT(2962) } })
	check(fromLive:GetAttribute("RankReward") == "" and fromLive:GetAttribute("Outlaw") == false, "a PRE result in Studio: off")
	-- a reward for a later week (the doc of the week before) is not on yet
	local w2 = rankWorld({ Time = MID62 })
	local p2 = w2:Join(101, "Halo", { Data = { RankReward = RR(2963, "Honor", 2), Outlaw = OUT(2961) } })
	check(p2:GetAttribute("RankReward") == "" and p2:GetAttribute("Outlaw") == false, "a result of another week is off (only WeekId == this week)")
	-- DebugSettle: STUDIO only; applies this week's server board now
	local live = rankWorld()
	check(live.Ranking.DebugSettle() == "STUDIO season only", "DebugSettle refuses outside the STUDIO season")
	local st = rankWorld({ Studio = true })
	local s1 = st:Join(-1, "Halo")
	local s2 = st:Join(-2, "Horns")
	local s3 = st:Join(-3, "Horns")
	st.Ranking.Credit(s1, "Honor", 2)
	st.Ranking.Credit(s2, "PvP", 3)
	st.Ranking.Credit(s3, "PvP", 2)
	local text = st.Ranking.DebugSettle()
	check(has(text, "Honor=-1") and has(text, "PvP=-2") and not has(text, "-3"), "DebugSettle lists this week's server top 3 (OutlawMinScore kept)", text)
	check(s1:GetAttribute("RankReward") == "Honor" and s2:GetAttribute("Outlaw") == true and s3:GetAttribute("Outlaw") ~= true,
		"DebugSettle applies the results at once (this week)")
end)

------------------------------------------------------------------ 19b. BB37 lines (검수 10)
runGroup("bb37-lines", function()
	local T = C0.Text
	local function bountyKO(hide)
		local w = rankWorld()
		local k = w:Join(101, "Halo", { Hide = hide })
		local v = w:Join(202, "Horns")
		w.PvP.DebugSetStars(v, C0.PvP.GlowStars)
		local from = #w.All
		w:KO(v, k)
		for i = #w.All, from + 1, -1 do
			if has(w.All[i].Text, "gold bounty!") then return w.All[i].Text end
		end
		return nil
	end
	-- A23-130 (server text verdicts 2026-10-11): no server-wide bounty brag any more (the hunter gets BountyGain)
	local hidden = bountyKO(true)
	check(hidden == nil, "a hidden knight's bounty: no server-wide line", hidden)
	local shown = bountyKO(false)
	check(shown == nil, "a shown knight's bounty: no server-wide line either", shown)
	check(type(T.BountyAnnounceHiddenEn) == "string" and not has(T.BountyAnnounceHidden, "["), "BountyAnnounceHidden KO/EN without a prefix")
	-- the kaiju's public name follows a hide toggle during the event (GameState KaijuName + the end line)
	local w = rankWorld({ Kaiju = true })
	local p = w:Join(201, "Horns")
	p.CameraMaxZoomDistance = 30
	w.PvP.DebugSetStars(p, C0.Kaiju.StarsNeeded)
	w:KaijuTick()
	check(w.GameState:GetAttribute("KaijuPhase") == "Siren" and w.GameState:GetAttribute("KaijuName") == "P201",
		"the siren publishes the shown name", show({ w.GameState:GetAttribute("KaijuPhase"), w.GameState:GetAttribute("KaijuName") }))
	w:Advance(1)
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(p, true)
	local hiddenName = string.format(C0.Announce.Text.HiddenName, C0.Factions.Horns.Name)
	check(w.GameState:GetAttribute("KaijuName") == hiddenName, "hiding during the siren re-publishes KaijuName at once",
		w.GameState:GetAttribute("KaijuName"))
	w:KaijuTick(C0.Kaiju.SirenSeconds)
	check(w.GameState:GetAttribute("KaijuPhase") == "Active", "the kaiju is active")
	local started = false
	for _, n in w.All do if has(n.Text, "is here!") then started = true end end
	check(not started and w.GameState:GetAttribute("KaijuName") == hiddenName,
		"no server-wide start line (A23-191); KaijuName keeps the hidden name", w.GameState:GetAttribute("KaijuName"))
	w:Advance(1)
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(p, false)
	check(w.GameState:GetAttribute("KaijuName") == "P201", "showing it again during the event re-publishes too")
	w:Advance(1)
	w.Remotes.SetAnnounceName.OnServerEvent:Fire(p, true)
	w:KaijuTick(C0.Kaiju.Duration)
	local survived = nil
	for _, n in w.All do if has(n.Text, "survived to the end") then survived = n.Text end end
	check(survived == nil, "no server-wide 'survived to the end' banner (A23-130: the kaiju's own reward line)", survived)
	w.AllowWarn = { "missing", "zoom" }
end)

------------------------------------------------------------------ 19c. BB11 town board (검수 2026-10-06)
runGroup("board", function()
	local T = R0.Text.Board
	local w = rankWorld()
	local R = w.Ranking
	local a = w:Join(101, "Halo")
	local b = w:Join(102, "Halo", { Hide = true })
	local c = w:Join(201, "Horns")
	local d = w:Join(301, "Neutral")
	local e = w:Join(202, "Horns", { Data = { Outlaw = OUT(2962) } }) -- an outlaw this week
	local f = w:Join(203, "Horns") -- this week's PvP leader: only a candidate
	local g = w:Join(204, "Horns", { Hide = true, Data = { Outlaw = OUT(2962) } }) -- a hidden outlaw
	R.Credit(a, "Honor", 12)
	R.Credit(b, "Honor", 9)
	R.Credit(c, "Infamy", 4)
	R.Credit(d, "Artisan", 3)
	R.Credit(f, "PvP", 6)
	R.Credit(e, "PvP", 5)
	R.Credit(g, "PvP", 5)
	w.PvP.DebugSetStars(c, 2)
	w.PvP.Start()
	w.Spawned = {}
	local text = w.Label.Text
	local lines = string.split(text, "\n")
	local hiddenHalo = string.format(C0.Announce.Text.HiddenName, C0.Factions.Halo.Name)
	local hiddenHorns = string.format(C0.Announce.Text.HiddenName, C0.Factions.Horns.Name)
	local tag = '<font color="#FF4A4A">' .. R0.Text.OutlawTag .. "</font>"
	check(#lines == 6 and lines[1] == T.Header, "header '이 서버 · 이번 주 순위' + 4 weekly boards + the wanted line", text)
	check(lines[2] and has(lines[2], T.Titles.Honor) and has(lines[2], "1. P101 12") and has(lines[2], "2. " .. hiddenHalo .. " 9")
		and not has(lines[2], "P102"), "Honor: this week's points, PublicName (hidden -> '<진영> 한 명')", lines[2])
	check(lines[3] and has(lines[3], T.Titles.Infamy) and has(lines[3], "1. P201 4"), "Infamy line", lines[3])
	check(lines[4] and has(lines[4], T.Titles.Artisan) and has(lines[4], "1. P301 3"), "Artisan line (A23-24: four boards)", lines[4])
	check(lines[5] and has(lines[5], T.Titles.PvP) and has(lines[5], "1. P203 6") and not has(lines[5], "1. P203 6 " .. tag),
		"PvP: this week's leader is shown without the outlaw tag (only a candidate)", lines[5])
	check(lines[5] and has(lines[5], "2. P202 5 " .. tag) and has(lines[5], "2. " .. hiddenHorns .. " 5 " .. tag),
		"PvP: players who ARE outlaws carry the red tag, also when the name is hidden; tied 5s share rank 2", lines[5])
	check(lines[6] and has(lines[6], T.Wanted) and has(lines[6], "1. P201 ★★"), "the wanted line stays (one line at the bottom)", lines[6])
	check(w.Label.RichText == true, "the board label is RichText (the red tag)")
	-- empty boards
	local w2 = rankWorld()
	w2:Join(101, "Halo")
	w2.PvP.Start()
	w2.Spawned = {}
	local empty = 0
	for _, line in string.split(w2.Label.Text, "\n") do
		if has(line, T.Empty) then empty += 1 end
	end
	check(empty == 5, "nothing yet: every line says '(아직 없음)'", w2.Label.Text)
	-- player text is escaped (the board is RichText)
	local w3 = rankWorld()
	local odd = w3:Join(105, "Halo")
	odd.DisplayName = "a<b>&"
	w3.Ranking.Credit(odd, "Honor", 2)
	w3.PvP.Start()
	w3.Spawned = {}
	check(has(w3.Label.Text, "a&lt;b&gt;&amp;") and not has(w3.Label.Text, "a<b>"), "names are escaped on the RichText board", w3.Label.Text)
end)

------------------------------------------------------------------ 20. XP (ProgressionService.GetXPMult)
runGroup("effects-xp", function()
	local w = rankWorld({ Progression = true })
	local p = w:Join(101, "Halo")
	local X = function() return w.Progression.GetXPMult(p) end
	local base = X()
	check(base > 0, "base XP multiplier", base)
	local function near(a, b) return math.abs(a - b) < 1e-9 end
	w.Data[p].RankReward = RR(2962, "Honor", 2)
	w.Ranking.RefreshEffects(p)
	check(near(X(), base * 1.10), "weekly top 3 (in that faction): XP x1.10", X())
	w.Data[p].Outlaw = OUT(2962)
	w.Ranking.RefreshEffects(p)
	check(near(X(), base * 1.10 * 0.5), "reward + outlaw: x1.10 x0.5 = x0.55", X())
	p:SetAttribute("BullyStacks", 2)
	check(near(X(), base * 0.55), "reward + outlaw + bully: still x0.55 (the penalty once, never x0.25)", X())
	w.Data[p].RankReward = { WeekId = 0, Board = "", Rank = 0 }
	w.Ranking.RefreshEffects(p)
	check(near(X(), base * 0.5), "outlaw + bully: x0.5 once", X())
	w.Data[p].Outlaw = { WeekId = 0 }
	w.Ranking.RefreshEffects(p)
	check(near(X(), base * 0.5), "bully only: x0.5", X())
	p:SetAttribute("BullyStacks", 0)
	check(near(X(), base), "nothing: the base multiplier again", X())
	w.Data[p].Outlaw = OUT(2962)
	w.Ranking.RefreshEffects(p)
	check(near(X(), base * 0.5), "outlaw only (no bully stack): x0.5", X())
	-- the reward only in that board's faction
	w.Data[p].Outlaw = { WeekId = 0 }
	w.Data[p].RankReward = RR(2962, "Infamy", 1)
	w.Ranking.RefreshEffects(p)
	check(near(X(), base), "an Infamy reward while in Halo: no bonus", X())
end)

------------------------------------------------------------------ 21. drops (LootService.RollKill)
runGroup("effects-loot", function()
	local w = rankWorld()
	local p = w:Join(101, "Halo")
	local L = w.Config.Loot
	w.Data[p].LootFlags = { FirstScroll = true }
	local tooth = L.Tables.Goblin[1]
	check(tooth.Item == "GoblinTooth" and tooth.P == 0.4, "fixture assumption: Goblin row 1 = GoblinTooth 0.4")
	-- one roll of the Goblin with the tooth row drawing `draw` (every other row misses)
	local function tooth1(draw, golden)
		w.Data[p].Items = {}
		local script = {}
		for i in L.Tables.Goblin do script[i] = i == 1 and draw or 0.999999 end
		w.Script = script
		w.Registry.MonsterService.MonsterKilled:Fire(p, { Kind = "Goblin", Golden = golden == true, Position = vec(0, 0, 0) })
		w.Script = nil
		return (w.Data[p].Items.GoblinTooth or 0) > 0
	end
	local jackpotBit = bit32.lshift(1, L.Jackpot.Tier - 1)
	local function jackpot(draw)
		w.Data[p].WeaponOwnedMask = 1
		local script = {}
		for i in L.Tables.Slime do script[i] = 0.999999 end
		table.insert(script, draw)
		w.Script = script
		w.Registry.MonsterService.MonsterKilled:Fire(p, { Kind = "Slime", Golden = false, Position = vec(0, 0, 0) })
		w.Script = nil
		return bit32.btest(w.Data[p].WeaponOwnedMask, jackpotBit)
	end
	local function set(reward, outlaw, bully)
		w.Data[p].RankReward = reward and RR(2962, "Honor", 1) or { WeekId = 0, Board = "", Rank = 0 }
		w.Data[p].Outlaw = OUT(outlaw and 2962 or 0)
		p:SetAttribute("BullyStacks", bully or 0)
		w.Ranking.RefreshEffects(p)
	end
	local J = L.Jackpot.Chance
	set(false, false)
	check(tooth1(0.4 - 1e-9) and not tooth1(0.4 + 1e-9), "no effect: the row drops iff draw < 0.4")
	check(jackpot(J - 1e-12) and not jackpot(J + 1e-12), "no effect: the jackpot pays iff draw < Chance")
	set(true, false)
	check(tooth1(0.44 - 1e-9) and tooth1(0.4 + 1e-9) and not tooth1(0.44 + 1e-9), "top-3 reward: rows x1.10 (0.4 -> 0.44)")
	check(jackpot(J - 1e-12) and not jackpot(J + 1e-12), "top-3 reward: the jackpot is never x1.10")
	check(tooth1(0.999999, true), "reward x golden x3: a row chance above 1 is cut at 1 (always drops)")
	set(false, true)
	check(tooth1(0.2 - 1e-9) and not tooth1(0.2 + 1e-9), "outlaw: rows x0.5")
	check(jackpot(J * 0.5 - 1e-12) and not jackpot(J * 0.5 + 1e-12), "outlaw: the jackpot x0.5 too")
	set(true, true)
	check(tooth1(0.22 - 1e-9) and not tooth1(0.22 + 1e-9), "reward + outlaw: rows x0.55")
	check(jackpot(J * 0.5 - 1e-12) and not jackpot(J * 0.5 + 1e-12), "reward + outlaw: jackpot x0.5 (no x1.10)")
	set(false, true, 3)
	check(tooth1(0.2 - 1e-9) and not tooth1(0.2 + 1e-9), "outlaw + bully: rows x0.5 once (never x0.25)")
	check(jackpot(J * 0.5 - 1e-12), "outlaw + bully: jackpot x0.5 once")
	-- the first king-slime scroll is a one-time grant: never halved
	local w2 = rankWorld()
	local q = w2:Join(102, "Halo", { Data = { Outlaw = OUT(2962) } })
	check(q:GetAttribute("Outlaw") == true, "the outlaw joined")
	w2:Drop(q, "BigSlime", {})
	check(w2.Data[q].Items.Enh70 == 1, "an outlaw still gets the first king-slime Enh70")
end)

------------------------------------------------------------------ 22. outlaw bounty (D3)
runGroup("effects-bounty", function()
	local B = C0.PvP.BountyPerLevelStar
	-- a Halo outlaw (no stars) KO'd by a Horns: the bully bounty x2
	local w, k, v = duel({ KillerFaction = "Horns", VictimFaction = "Halo", VictimAttrs = {} })
	w.Data[v].Outlaw = OUT(2962)
	w.Ranking.RefreshEffects(v)
	w:KO(v, k)
	local paid = 0
	for _, g in w.Gold do if g.P == k and g.Src == "Bounty" then paid += g.N end end
	check(paid == B * 20 * 1 * 2, "D3: a Halo outlaw counts as one bully stack: bounty x2 (" .. B * 40 .. ")", paid)
	-- a Horns outlaw with no stars KO'd by a Halo: a bounty KO, x2
	local w2, k2, v2 = duel()
	w2.Data[v2].Outlaw = OUT(2962)
	w2.Ranking.RefreshEffects(v2)
	w2:KO(v2, k2)
	paid = 0
	for _, g in w2.Gold do if g.P == k2 and g.Src == "Bounty" then paid += g.N end end
	check(paid == B * 20 * 2, "a Horns outlaw with no stars: bounty x2", paid)
	-- outlaw + bully 3: units 3, x2 once (never x4)
	local w3, k3, v3 = duel({ VictimAttrs = { BullyStacks = 3 } })
	w3.Data[v3].Outlaw = OUT(2962)
	w3.Ranking.RefreshEffects(v3)
	w3:KO(v3, k3)
	paid = 0
	for _, g in w3.Gold do if g.P == k3 and g.Src == "Bounty" then paid += g.N end end
	check(paid == B * 20 * 3 * 2, "outlaw + bully 3: x2 once (max x2)", paid)
	-- the claim cooldown: a second killer right after gets nothing
	local k3b = w3:Join(103, "Halo")
	w3:Advance(30)
	w3.PS.MarkActive(v3)
	w3:KO(v3, k3b)
	paid = 0
	for _, g in w3.Gold do if g.P == k3b and g.Src == "Bounty" then paid += g.N end end
	check(paid == 0, "the bully / outlaw bounty is claimed once per cooldown", paid)
	-- not an outlaw: a clean Horns pays honor only
	local w4, k4, v4 = duel()
	w4:KO(v4, k4)
	paid = 0
	for _, g in w4.Gold do if g.P == k4 and g.Src == "Bounty" then paid += g.N end end
	check(paid == 0, "control: a clean Horns has no bounty")
	-- the Bounty attribute (nametag / board) shows the outlaw bounty
	local w5 = rankWorld()
	local o5 = w5:Join(201, "Horns", { Data = { Outlaw = OUT(2962) } })
	w5.PvP.ResetStars(o5)
	check(o5:GetAttribute("Bounty") == B * 20 * 2, "the Bounty attribute of an outlaw (nametag / board)", o5:GetAttribute("Bounty"))
end)

------------------------------------------------------------------ 23. no auto combat while an outlaw (CombatService)
runGroup("effects-auto", function()
	local w = rankWorld()
	local p = w:Join(101, "Halo", { Data = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	check(p:GetAttribute("AutoCombatEnabled") == true, "auto combat ON before the settle")
	w.Data[p].Outlaw = OUT(2962)
	w.Ranking.RefreshEffects(p)
	check(w.Data[p].AutoCombatEnabled == false and p:GetAttribute("AutoCombatEnabled") == false, "becoming an outlaw switches auto combat OFF")
	check(w:CountNotices(p, R0.Text.OutlawAutoOff) == 1, "…with the outlaw reason")
	w:Advance(1)
	w.Remotes.SetAutoAttack.OnServerEvent:Fire(p, true)
	check(w.Data[p].AutoCombatEnabled == false and w:CountNotices(p, R0.Text.OutlawNoAuto) == 1, "an outlaw cannot switch it back on (OutlawNoAuto)")
	-- an outlaw who is also a bully: the bully text; the end of the outlaw week never says "bully penalty over"
	p:SetAttribute("BullyStacks", 1)
	w:Advance(1)
	w.Remotes.SetAutoAttack.OnServerEvent:Fire(p, true)
	check(w:CountNotices(p, C0.Text.BullyNoAuto) == 1, "outlaw + bully: the bully reason")
	p:SetAttribute("BullyStacks", 0)
	check(w:CountNotices(p, C0.Text.BullyPenaltyEnd) == 0, "the last bully stack decays while still an outlaw: no 'penalty over' yet")
	w.Data[p].Outlaw = { WeekId = 0 }
	w.Ranking.RefreshEffects(p)
	check(w:CountNotices(p, R0.Text.OutlawEnd) == 1 and w:CountNotices(p, C0.Text.BullyPenaltyEnd) == 0,
		"the outlaw week ends: OutlawEnd only")
	w:Advance(1)
	w.Remotes.SetAutoAttack.OnServerEvent:Fire(p, true)
	check(w.Data[p].AutoCombatEnabled == true, "after the outlaw week auto combat can be switched on again")
	-- a rejoin as an outlaw with auto combat saved ON: switched off at join
	local w2 = rankWorld()
	local q = w2:Join(102, "Halo", { Data = { AutoCombatUnlocked = true, AutoCombatEnabled = true, Outlaw = OUT(2962) } })
	check(w2.Data[q].AutoCombatEnabled == false, "joining as an outlaw with auto combat saved ON: OFF", tostring(w2.Data[q].AutoCombatEnabled))
	-- 게임성 검수 2026-10-12: the outlaw week starting while auto is ON = one line (OutlawStart says "no Auto"), not two
	local st = rankWorld({ Studio = true })
	local o = st:Join(-2, "Horns", { Data = { AutoCombatUnlocked = true, AutoCombatEnabled = true } })
	st.Ranking.Credit(o, "PvP", 3)
	st.Ranking.DebugSettle()
	check(o:GetAttribute("Outlaw") == true and st.Data[o].AutoCombatEnabled == false
		and st:CountNotices(o, string.format(R0.Text.OutlawStart, 1)) == 1 and st:CountNotices(o, R0.Text.OutlawAutoOff) == 0,
		"the outlaw week starts with auto ON: auto OFF and one line (OutlawStart), no second OutlawAutoOff line",
		show({ o:GetAttribute("Outlaw"), st.Data[o].AutoCombatEnabled, st:CountNotices(o, R0.Text.OutlawAutoOff) }))
end)

------------------------------------------------------------------ 24. the red '무법자' on the nametag (CharacterVisuals)
runGroup("nametag", function()
	local w = rankWorld()
	local function tagged(p)
		local update = execute("CharacterVisuals.updateNametag", NAMETAG_SOURCE, w:Env(), w.Config, w.Util)
		local bb = newInstance("BillboardGui", w)
		for _, n in { "Line1", "Line2", "Line3" } do
			local l = newInstance("TextLabel", w)
			l.Name, l.Text = n, ""
			l.Parent = bb
		end
		update(p, bb)
		return bb:FindFirstChild("Line2").Text, bb:FindFirstChild("Line1").Text
	end
	local p = w:Join(101, "Halo", { Data = { Outlaw = OUT(2962) } })
	local line2 = tagged(p)
	check(has(line2, '<font color="#FF4A4A">' .. R0.Text.OutlawTag .. "</font>"), "an outlaw's nametag line 2 ends with a red '무법자'", line2)
	local hidden = w:Join(102, "Horns", { Hide = true, Data = { Outlaw = OUT(2962) } })
	check(has(tagged(hidden), R0.Text.OutlawTag), "the tag is shown even with the name hidden (BB37 hides chat lines only)")
	local clean = w:Join(103, "Halo")
	check(not has(tagged(clean), R0.Text.OutlawTag), "not an outlaw: no tag")
	local nick = w:Join(104, "Halo", { Data = { Outlaw = OUT(2962) } })
	nick:SetAttribute("Nickname", "<b>x</b>")
	nick:SetAttribute("NicknameVerified", true)
	local l2, l1 = tagged(nick)
	check(not has(l1, "<b>") and select(2, string.gsub(l2, "<font", "")) == 1, "only the fixed tag is markup (player text stays escaped)", l2)
end)

finish()
