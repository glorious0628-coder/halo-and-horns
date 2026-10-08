-- gamepass_offline.luau : A23-75 (user 2026-10-08) game passes, server side. tools/test_gamepass.py binds
-- CONFIG_SOURCE, UTIL_SOURCE, PROGRESSION_SOURCE and MONETIZATION_SOURCE in front of dev2_kit.luau: the REAL
-- ProgressionService (the 2x boost, what each grant returns, the kill reward line) and the REAL MonetizationService
-- (ownership at join with retries and the saved fallback, PromptGamePassPurchaseFinished, looks, SetLook, the VIP
-- supporter board, the Studio "Pass" override) run on kit doubles: Players, DataStores, a MarketplaceService double
-- (UserOwnsGamePassAsync answers / failures per user and pass, the purchase-finished signal) and a PlayerService double.
-- The sweep over every XP / gold grant in src/ServerScriptService is a source-text check in tools/test_gamepass.py.

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local EPS = 1e-9

-- the world. opts: Ids = { [kind or look id] = pass id } (EditConfig), Owns = { [userId] = { [passId] = true } },
-- FailAll = { [passId] = true } (every ask errors), FailTimes = { [passId] = n } (the first n asks error)
local function passWorld(opts)
	opts = opts or {}
	local w = newWorld({ Studio = true, EditConfig = function(cfg)
		for key, id in opts.Ids or {} do
			if cfg.GamePasses[key] then cfg.GamePasses[key].Id = id else cfg.Looks[key].PassId = id end
		end
		if opts.EditConfig then opts.EditConfig(cfg) end
	end })
	local cfg = w.Config
	local Signal = w.Util.Signal
	w.Asks, w.Waits = {}, {}
	w.Owns = opts.Owns or {}
	local failTimes = table.clone(opts.FailTimes or {})
	-- MarketplaceService double
	local mp = { PromptGamePassPurchaseFinished = rbxSignal(w.Warnings) }
	function mp.UserOwnsGamePassAsync(_, userId, passId)
		table.insert(w.Asks, { UserId = userId, PassId = passId })
		if w.OnAsk then w.OnAsk(userId, passId) end
		if (opts.FailAll or {})[passId] then error("offline MarketplaceService failure") end
		if (failTimes[passId] or 0) > 0 then
			failTimes[passId] -= 1
			error("offline MarketplaceService failure")
		end
		local mine = w.Owns[userId]
		return mine ~= nil and mine[passId] == true
	end
	w.Services.MarketplaceService = mp
	w.Market = mp

	-- PlayerService double (data, ready, signals, stats mirrored like the real one)
	w.Data = {}
	local mirrored = {}
	for _, key in cfg.Data.Mirrored do mirrored[key] = true end
	local ps = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new() }
	function ps.GetData(p) return w.Data[p] end
	function ps.IsReady(p) return w.Ready[p] == true and p.Parent ~= nil end
	function ps.GetReadyPlayers()
		local out = {}
		for _, p in w.PlayerList do if w.Ready[p] and p.Parent ~= nil then table.insert(out, p) end end
		return out
	end
	function ps.SetStat(p, key, value)
		local d = w.Data[p]
		if not d then return end
		d[key] = value
		if mirrored[key] then p:SetAttribute(key, value) end
	end
	function ps.AddStat(p, key, delta)
		local d = w.Data[p]
		if not d then return 0 end
		local v = (tonumber(d[key]) or 0) + delta
		ps.SetStat(p, key, v)
		return v
	end
	function ps.RefreshCharacter() end
	w.Saves = 0
	local reg = {
		PlayerService = ps,
		DataService = { Save = function() w.Saves += 1; return true end },
		FactionService = { FactionChanged = Signal.new(), GetPerks = function() return cfg.Factions.None end },
		PvPService = { GetStars = function() return 0 end },
		WarService = { HasBlessing = function() return false end },
		CombatService = { IsInCombat = function() return false end },
		MonsterService = { MonsterKilled = Signal.new() },
	}
	w.Reg = reg
	-- a no-yield task.wait for the ownership retries (the waits are recorded)
	local env = w:Env()
	env.task = setmetatable({ wait = function(t)
		table.insert(w.Waits, t)
		if w.BoardCo ~= nil and coroutine.running() == w.BoardCo then coroutine.yield() end
	end }, { __index = env.task })
	local ms = execute("MonetizationService", MONETIZATION_SOURCE, env)
	reg.MonetizationService = ms
	local prog = w:Load("ProgressionService", PROGRESSION_SOURCE)
	reg.ProgressionService = prog
	ms.Init(reg)
	prog.Init(reg)
	ms.Start()
	-- MonetizationService.Start spawns the supporter-board loop (a forever loop: refresh, wait): one pass per
	-- w:BoardTick() (its task.wait yields the loop coroutine)
	w.BoardCo = coroutine.create(table.remove(w.Spawned)[1])
	function w:BoardTick()
		local ok, err = coroutine.resume(self.BoardCo)
		assert(ok, err)
	end
	w:BoardTick() -- the first refresh at Start
	w.Ms, w.Prog = ms, prog
	-- a ready player; o: Faction, Level, Hide, Data (save fields), NoCheck (do not run the join check)
	function w:Join(userId, o)
		o = o or {}
		local p = self:NewPlayer(userId, {})
		local d = deepCopy(cfg.Data.Defaults)
		d.Faction = o.Faction or "Halo"
		d.Level = o.Level or 10
		d.HideAnnounceName = o.Hide == true
		for k, v in o.Data or {} do d[k] = v end
		d.Looks, d.PassSeen = cfg.SanitizeLooks(d.Looks, d.PassSeen)
		self.Data[p] = d
		for _, key in cfg.Data.Mirrored do
			if d[key] ~= nil then p:SetAttribute(key, d[key]) end
		end
		self.Ready[p] = true
		ps.PlayerReady:Fire(p, d)
		if not o.NoCheck then self:RunSpawned() end
		return p
	end
	function w:Leave(p)
		ps.PlayerLeaving:Fire(p, self.Data[p])
		self.Ready[p] = nil
		self:Remove(p)
	end
	function w:Board() return self.GameState:GetAttribute("SupporterNames") or "" end
	return w
end

local function attrs(p)
	return { XP2 = p:GetAttribute("PassXP2"), Gold2 = p:GetAttribute("PassGold2"), VIP = p:GetAttribute("PassVIP"),
		Looks = p:GetAttribute("LooksOwned"), On = p:GetAttribute("LookOn") }
end

------------------------------------------------------------------ config
runGroup("config", function()
	local GP = C0.GamePasses
	check(GP.XP2.Price == 199 and GP.Gold2.Price == 149 and GP.VIP.Price == 249, "prices: 2x XP 199, 2x Gold 149, VIP 249 (A23-75)",
		show({ GP.XP2.Price, GP.Gold2.Price, GP.VIP.Price }))
	check(GP.XP2.Attr == "PassXP2" and GP.Gold2.Attr == "PassGold2" and GP.VIP.Attr == "PassVIP",
		"attributes PassXP2 / PassGold2 / PassVIP (the screen's names)")
	check(GP.XP2.Id == 0 and GP.Gold2.Id == 0 and GP.VIP.Id == 0, "ids 0 until the user makes the passes (Coming soon)")
	local n = 0
	for _ in GP do n += 1 end
	check(n == 3, "three passes: XP2, Gold2, VIP", n)
	local B = C0.PassBoost
	check(B.Mult == 2, "the passes double (2x)", B.Mult)
	local want = { Monster = true, Quest = true, Event = true, Bounty = true, War = true, Loot = true, Kaiju = true, SignOn = true,
		Attendance = true }
	local same = true
	for k in want do if B.GoldSources[k] ~= true then same = false end end
	for k in B.GoldSources do if not want[k] then same = false end end
	check(same, "2x Gold counts for the earned sources only", show(B.GoldSources))
	for _, s in { "Sale", "Refund", "Plunder", "KaijuBank", "KaijuTransfer", "Penalty", "Other" } do
		check(B.GoldSources[s] == nil, "never 2x: " .. s)
	end
	check(B.CheckTries == 3 and B.CheckWait == 1 and B.MaxSupporters == 30 and B.RefreshSeconds == 300,
		"3 tries (1 s, then 2 s), a board of 30, read every 5 min", show({ B.CheckTries, B.CheckWait, B.MaxSupporters, B.RefreshSeconds }))
	-- looks: four sold (99, one pass each), six attendance-only (14 / 50 / 100 days), names fit the shop slot
	local sold, att, bad = 0, {}, {}
	for id, look in C0.Looks do
		if look.Faction ~= "Halo" and look.Faction ~= "Horns" then table.insert(bad, id .. " faction") end
		if type(look.Name) ~= "string" or #look.Name > 12 or #look.Name == 0 then table.insert(bad, id .. " name") end
		if type(look.Icon) ~= "string" or type(look.Order) ~= "number" then table.insert(bad, id .. " icon/order") end
		if look.PassId ~= nil then
			sold += 1
			if look.Price ~= 99 or look.PassId ~= 0 or look.Unlock ~= nil then table.insert(bad, id .. " sale") end
		else
			local days = type(look.Unlock) == "table" and look.Unlock.Attendance
			if not days then table.insert(bad, id .. " unlock") else att[days] = (att[days] or 0) + 1 end
			if look.Price ~= nil then table.insert(bad, id .. " priced") end
		end
	end
	check(sold == 4 and att[14] == 2 and att[50] == 2 and att[100] == 2 and #bad == 0,
		"looks: 4 sold (99 each, pass id 0), attendance-only 14 / 50 / 100 days (a halo and horns each)", show({ sold, att, bad }))
	check(C0.Looks.HaloIce.Name == "Ice Halo" and C0.Looks.HaloGold.Name == "Gold Halo" and C0.Looks.HornsLava.Name == "Lava Horns"
		and C0.Looks.HornsShadow.Name == "Shadow Horns", "the user's four picks keep their names")
	local order = C0.LookOrder()
	check(#order == 10 and order[1] == "HaloIce" and order[4] == "HornsShadow" and order[10] == "HornsPlatinum", "LookOrder: shop order",
		show(order))
	check(C0.RateLimits.SetLook == 0.5, "SetLook at most every 0.5 s", C0.RateLimits.SetLook)
	-- the save fields (additive, Version 3)
	local D = C0.Data.Defaults
	check(type(D.Looks) == "table" and type(D.Looks.Owned) == "table" and D.Looks.On == "" and type(D.PassSeen) == "table"
		and C0.Data.Version == 3, "save: Looks { Owned, On } + PassSeen, Version stays 3")
	local looks, seen = C0.SanitizeLooks({ Owned = { HaloSprout = 1790000000, Nope = 5, HornsSprout = "x", HaloStarlight = -1,
		HaloPlatinum = 0 / 0 }, On = "Nope" }, { XP2 = true, VIP = "yes", HaloIce = false, Junk = true })
	check(looks.Owned.HaloSprout == 1790000000 and looks.Owned.Nope == nil and looks.Owned.HornsSprout == nil
		and looks.Owned.HaloStarlight == nil and looks.Owned.HaloPlatinum == nil and looks.On == "",
		"SanitizeLooks: known ids with a time only; an unknown worn id comes off", show(looks))
	check(seen.XP2 == true and seen.VIP == nil and seen.HaloIce == false and seen.Junk == nil, "PassSeen: booleans of known keys only",
		show(seen))
	local l2, s2 = C0.SanitizeLooks(nil, "broken")
	check(next(l2.Owned) == nil and l2.On == "" and next(s2) == nil, "a missing / broken field: the defaults")
	local l3 = C0.SanitizeLooks({ Owned = {}, On = "HornsLava" })
	check(l3.On == "HornsLava", "a known worn id stays (ownership is checked when it is shown)")
end)

------------------------------------------------------------------ ids 0
runGroup("not sold yet", function()
	local w = passWorld()
	local p = w:Join(101)
	local a = attrs(p)
	check(#w.Asks == 0, "ids 0: Roblox is never asked", #w.Asks)
	check(a.XP2 == false and a.Gold2 == false and a.VIP == false and a.Looks == "" and a.On == "",
		"the attributes say nothing is owned", show(a))
	check(not w.Ms.HasPass(p, "XP2") and not w.Ms.HasPass(p, "VIP") and not w.Ms.HasPass(p, "HaloIce"), "HasPass false")
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 0, true)
	check(not w.Ms.HasPass(p, "XP2") and p:GetAttribute("PassXP2") == false, "a 'purchase' of id 0 grants nothing")
	check(w:Board() == "", "the supporter board stays empty")
end)

------------------------------------------------------------------ ownership at join
runGroup("ownership at join", function()
	local ids = { XP2 = 11, Gold2 = 12, VIP = 13, HaloIce = 21, HornsLava = 23 }
	local w = passWorld({ Ids = ids, Owns = { [201] = { [11] = true, [21] = true }, [202] = {} } })
	local p = w:Join(201)
	local a = attrs(p)
	check(a.XP2 == true and a.Gold2 == false and a.VIP == false, "owned passes on, the rest off", show(a))
	check(a.Looks == "HaloIce" and a.On == "", "an owned look is listed (not worn until picked)", show(a))
	check(#w.Asks == 5, "one ask per sold pass", #w.Asks)
	local seen = w.Data[p].PassSeen
	check(seen.XP2 == true and seen.Gold2 == false and seen.HaloIce == true, "the answers are saved (PassSeen)", show(seen))
	local q = w:Join(202)
	check(not w.Ms.HasPass(q, "XP2") and attrs(q).Looks == "", "a player owning nothing: nothing")
	-- Roblox fails twice, then answers: 3 tries, waits 1 then 2 s
	w = passWorld({ Ids = { XP2 = 11 }, Owns = { [203] = { [11] = true } }, FailTimes = { [11] = 2 } })
	w.Waits = {}
	p = w:Join(203)
	check(w.Ms.HasPass(p, "XP2") and #w.Asks == 3 and show(w.Waits) == show({ 1, 2 }),
		"fails twice, the third try answers (waits 1 s, 2 s)", show({ #w.Asks, w.Waits }))
	-- Roblox never answers: the last saved answer counts (true stays true, unknown = false), nothing saved over it
	w = passWorld({ Ids = { XP2 = 11, Gold2 = 12 }, FailAll = { [11] = true, [12] = true } })
	p = w:Join(204, { Data = { PassSeen = { XP2 = true } } })
	check(w.Ms.HasPass(p, "XP2") and not w.Ms.HasPass(p, "Gold2") and #w.Asks == 6,
		"Roblox down: the saved answer counts (XP2 yes, Gold2 unknown = no)", show({ attrs(p), #w.Asks }))
	check(w.Data[p].PassSeen.XP2 == true and w.Data[p].PassSeen.Gold2 == nil, "a failed check saves nothing")
	-- a refund: Roblox now says no -> off, and that is saved
	w = passWorld({ Ids = { XP2 = 11 }, Owns = { [205] = {} } })
	p = w:Join(205, { Data = { PassSeen = { XP2 = true } } })
	check(not w.Ms.HasPass(p, "XP2") and w.Data[p].PassSeen.XP2 == false, "Roblox says no (refunded): off, saved")
	-- the player left during the check: nothing is set on the old record
	w = passWorld({ Ids = { XP2 = 11 }, Owns = { [206] = { [11] = true } } })
	p = w:Join(206, { NoCheck = true })
	w:Leave(p)
	w:RunSpawned()
	check(w.Data[p].PassSeen.XP2 == nil, "left before Roblox answered: nothing written")
	-- the player leaves while Roblox answers: that answer and the rest are not written
	w = passWorld({ Ids = { XP2 = 11, Gold2 = 12 }, Owns = { [207] = { [11] = true, [12] = true } } })
	p = w:Join(207, { NoCheck = true })
	w.OnAsk = function() if p.Parent ~= nil then w:Leave(p) end end
	w:RunSpawned()
	check(w.Data[p].PassSeen.XP2 == nil and w.Data[p].PassSeen.Gold2 == nil and #w.Asks == 1,
		"left while Roblox answered: nothing written, no more asks", show({ w.Data[p].PassSeen, #w.Asks }))
end)

------------------------------------------------------------------ purchase
runGroup("purchase", function()
	local w = passWorld({ Ids = { XP2 = 11, Gold2 = 12, VIP = 13, HornsLava = 23 }, Owns = { [301] = {} } })
	local bought = {}
	w.Ms.PassBought:Connect(function(pl, key) table.insert(bought, pl.Name .. ":" .. tostring(key)) end)
	local p = w:Join(301, { Faction = "Horns" })
	check(not w.Ms.HasPass(p, "Gold2"), "(not owned at join)")
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 12, true)
	check(w.Ms.HasPass(p, "Gold2") and p:GetAttribute("PassGold2") == true and w.Data[p].PassSeen.Gold2 == true,
		"bought: on at once (attribute too) and saved", show(attrs(p)))
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 11, false)
	check(not w.Ms.HasPass(p, "XP2"), "a closed prompt (not bought): nothing")
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 999, true)
	check(not w.Ms.HasPass(p, "VIP") and not w.Ms.HasPass(p, "XP2"), "an unknown pass id: nothing")
	w.Market.PromptGamePassPurchaseFinished:Fire({ Name = "fake" }, 11, true)
	check(true, "a non-player argument is ignored (no error)")
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 23, true)
	check(w.Ms.OwnsLook(p, "HornsLava") and p:GetAttribute("LooksOwned") == "HornsLava", "a look bought: listed at once")
	-- PassBought (game dev 3's PassShop Bought metric): once per real purchase, with the key, after it is on
	check(show(bought) == show({ "P301:Gold2", "P301:HornsLava" }),
		"PassBought: one per real purchase (not a closed prompt, an unknown id or a fake player)", show(bought))
	bought = {}
	w.Ms.PassBought:Connect(function(pl, key) if not w.Ms.HasPass(pl, key) then table.insert(bought, "off " .. key) end end)
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 11, true)
	check(show(bought) == show({ "P301:XP2" }), "the pass is already on when PassBought fires", show(bought))
	bought = {}
	w.Ms.DebugSetPass(p, "VIP", "on")
	local owner = w:Join(305, { NoCheck = true })
	w.Owns[305] = { [11] = true }
	w:RunSpawned()
	check(w.Ms.HasPass(owner, "XP2") and #bought == 0, "no PassBought for the join check or a Studio override", show(bought))
	-- a purchase while the join check is still asking: the late 'no' never takes it back
	w = passWorld({ Ids = { XP2 = 11 }, Owns = { [302] = {} } })
	p = w:Join(302, { NoCheck = true })
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 11, true)
	w:RunSpawned()
	check(w.Ms.HasPass(p, "XP2") and p:GetAttribute("PassXP2") == true, "bought during the join check: stays on")
	-- VIP bought: on the supporter board at once
	w = passWorld({ Ids = { VIP = 13 }, Owns = { [303] = {} } })
	p = w:Join(303)
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 13, true)
	w:RunSpawned()
	check(w:Board() == "P303", "VIP bought: the name is on the supporter board", w:Board())
end)

------------------------------------------------------------------ the boost
runGroup("boost", function()
	local w = passWorld({ Ids = { XP2 = 11, Gold2 = 12 }, Owns = { [401] = { [11] = true, [12] = true }, [402] = {} } })
	local p = w:Join(401, { Level = 10 })
	local q = w:Join(402, { Level = 10 })
	local Prog = w.Prog
	local earned = {}
	Prog.GoldEarned:Connect(function(pl, amount, source) table.insert(earned, { pl, amount, source }) end)
	local before = w.Data[p].XP
	check(Prog.AddXP(p, 10) == 20 and w.Data[p].XP == before + 20, "2x XP: 10 -> 20 added and returned", w.Data[p].XP - before)
	check(Prog.AddXP(q, 10) == 10, "without the pass: 10")
	check(Prog.AddXP(p, 7.9) == 14, "the amount is floored before doubling (7 -> 14)")
	check(Prog.AddXP(p, 0) == 0 and Prog.AddXP(p, -5) == 0, "nothing / negative: 0")
	check(Prog.AddXP(p, 100, 50) == 50 and Prog.AddXP(q, 100, 50) == 50 and Prog.AddXP(p, 20, 50) == 40,
		"a cap (A23-27) holds after the doubling")
	-- gold: every source
	local srcs = { "Monster", "Quest", "Event", "Bounty", "War", "Loot", "Kaiju", "SignOn", "Attendance", "Sale", "Refund",
		"Plunder", "KaijuBank", "KaijuTransfer", "Penalty", "Other" }
	local wrong = {}
	for _, s in srcs do
		local boosted = C0.PassBoost.GoldSources[s] == true
		local b0 = w.Data[p].BankGold
		local got = Prog.AddBankGold(p, 100, s)
		if got ~= (boosted and 200 or 100) or w.Data[p].BankGold ~= b0 + got then table.insert(wrong, "bank " .. s .. "=" .. tostring(got)) end
		local c0 = w.Data[p].CarriedGold
		got = Prog.AddCarriedGold(p, 50, s)
		if got ~= (boosted and 100 or 50) or w.Data[p].CarriedGold ~= c0 + got then table.insert(wrong, "carried " .. s) end
		if Prog.AddBankGold(q, 100, s) ~= 100 then table.insert(wrong, "no pass " .. s) end
	end
	check(#wrong == 0, "2x Gold: earned sources doubled, sales / refunds / plunder / own gold never, no pass never", show(wrong))
	local last = earned[#earned]
	check(last and last[2] == 100 and last[3] == "Other", "GoldEarned carries what was added and its source", show(last and { last[2], last[3] }))
	check(Prog.AddBankGold(p, 100) == 100, "no source: 'Other', never doubled")
	Prog.AddBankGold(p, 100, "Quest")
	last = earned[#earned]
	check(last and last[2] == 200 and last[3] == "Quest", "GoldEarned carries the doubled amount of an earned source",
		show(last and { last[2], last[3] }))
	-- the multipliers themselves never include the pass (no double doubling)
	check(Prog.GetXPMult(p) == Prog.GetXPMult(q) and Prog.GetGoldMult(p) == Prog.GetGoldMult(q),
		"GetXPMult / GetGoldMult are the same with or without the pass", show({ Prog.GetXPMult(p), Prog.GetXPMult(q) }))
	-- a kill: the reward line shows what was added
	local fx0 = #w.Fx
	w.Reg.MonsterService.MonsterKilled:Fire(p, { Gold = 10, XP = 30, Kind = "Slime", Position = vec(1, 2, 3) })
	local fx = w.Fx[#w.Fx]
	check(#w.Fx > fx0 and fx.Kind == "Reward" and fx.Data.Gold == 20 and fx.Data.XP == 60, "a kill with both passes: +20 gold, +60 XP shown",
		show(fx and fx.Data))
	w.Reg.MonsterService.MonsterKilled:Fire(q, { Gold = 10, XP = 30, Kind = "Slime", Position = vec(1, 2, 3) })
	fx = w.Fx[#w.Fx]
	check(fx.Data.Gold == 10 and fx.Data.XP == 30, "without: +10 / +30", show(fx.Data))
	-- the Pumpkin King and a Lv1 player: at most one level's XP, with the pass too
	local lv1 = w:Join(403, { Level = 1 })
	w.Owns[403] = nil
	w.Ms.DebugSetPass(lv1, "XP2", "on")
	w.Reg.MonsterService.MonsterKilled:Fire(lv1, { Gold = 0, XP = 100000, Kind = "PumpkinKing", Position = vec(0, 0, 0) })
	fx = w.Fx[#w.Fx]
	check(fx.Data.XP == math.floor(C0.XPToNext(1)), "a Lv1 kill of the king with 2x XP: still one level's XP", fx.Data.XP)
end)

------------------------------------------------------------------ looks
runGroup("looks", function()
	local w = passWorld({ Ids = { HaloIce = 21, HornsLava = 23 }, Owns = { [501] = { [21] = true, [23] = true } } })
	local p = w:Join(501, { Faction = "Halo" })
	local remote = w.Net.Get("SetLook")
	check(attrs(p).Looks == "HaloIce,HornsLava", "owned looks in shop order", attrs(p).Looks)
	remote.OnServerEvent:Fire(p, "HaloIce")
	check(p:GetAttribute("LookOn") == "HaloIce" and w.Data[p].Looks.On == "HaloIce", "SetLook: an owned look of my side is worn and saved")
	w:Advance(1)
	remote.OnServerEvent:Fire(p, "HornsLava")
	check(p:GetAttribute("LookOn") == "HaloIce", "the other side's look: ignored")
	w:Advance(1)
	remote.OnServerEvent:Fire(p, "HaloGold")
	check(p:GetAttribute("LookOn") == "HaloIce", "a look not owned: ignored")
	w:Advance(1)
	remote.OnServerEvent:Fire(p, "", "extra")
	check(p:GetAttribute("LookOn") == "HaloIce", "extra arguments: ignored (even a valid id)")
	remote.OnServerEvent:Fire(p, "Nope")
	remote.OnServerEvent:Fire(p, 5)
	remote.OnServerEvent:Fire(p, string.rep("a", 40))
	check(p:GetAttribute("LookOn") == "HaloIce", "unknown id / not a string / too long: ignored")
	w:Advance(1)
	remote.OnServerEvent:Fire(p, "")
	check(p:GetAttribute("LookOn") == "" and w.Data[p].Looks.On == "", "\"\": wear none")
	remote.OnServerEvent:Fire(p, "HaloIce")
	check(p:GetAttribute("LookOn") == "", "twice within 0.5 s: the second is dropped (rate limit)")
	w:Advance(1)
	remote.OnServerEvent:Fire(p, "HaloIce")
	check(p:GetAttribute("LookOn") == "HaloIce", "(worn again)")
	-- a faction switch: the look comes off, and back when switching back (the saved pick stays)
	p:SetAttribute("Faction", "Horns")
	w.Reg.FactionService.FactionChanged:Fire(p, "Horns", "Halo", "Altar")
	check(p:GetAttribute("LookOn") == "" and w.Data[p].Looks.On == "HaloIce", "switched to Horns: the halo look comes off (kept saved)")
	p:SetAttribute("Faction", "Halo")
	w.Reg.FactionService.FactionChanged:Fire(p, "Halo", "Horns", "Altar")
	check(p:GetAttribute("LookOn") == "HaloIce", "back to Halo: worn again")
	-- attendance looks: GrantLook (A23-77) only for Unlock looks, once
	check(w.Ms.GrantLook(p, "HaloSprout") == true and w.Ms.OwnsLook(p, "HaloSprout")
		and attrs(p).Looks == "HaloIce,HornsLava,HaloSprout" and type(w.Data[p].Looks.Owned.HaloSprout) == "number",
		"GrantLook: an attendance look is unlocked, saved and listed", attrs(p).Looks)
	check(w.Ms.GrantLook(p, "HaloSprout") == false, "not twice")
	check(w.Ms.GrantLook(p, "HaloGold") == false and not w.Ms.OwnsLook(p, "HaloGold"), "a sold look is never granted")
	check(w.Ms.GrantLook(p, "Nope") == false, "an unknown id: no")
	w:Advance(1)
	remote.OnServerEvent:Fire(p, "HaloSprout")
	check(p:GetAttribute("LookOn") == "HaloSprout", "an attendance look can be worn")
	-- a saved worn look that is not owned any more (refund): not shown
	local w2 = passWorld({ Ids = { HaloIce = 21 }, Owns = { [502] = {} } })
	local r = w2:Join(502, { Faction = "Halo", Data = { Looks = { Owned = {}, On = "HaloIce" } } })
	check(r:GetAttribute("LookOn") == "", "a worn look no longer owned is not shown", r:GetAttribute("LookOn"))
end)

------------------------------------------------------------------ supporter board
runGroup("supporters", function()
	local ids = { VIP = 13 }
	local stores = {}
	local w = passWorld({ Ids = ids, Owns = { [601] = { [13] = true }, [602] = { [13] = true }, [603] = { [13] = true } },
		EditConfig = function(cfg) cfg.PassBoost.MaxSupporters = 3 end })
	local key = C0.PassBoost.SupporterKey
	local a = w:Join(601)
	w:RunSpawned()
	local row = w.Stores[C0.PassBoost.SupporterStore].Rows -- (kit store: rows by key)
	check(w:Board() == "P601" and row and row[key] and #row[key] == 1 and row[key][1].U == 601 and row[key][1].N == "P601",
		"a VIP joins: on this server's board and in the shared list", show({ w:Board(), row and row[key] }))
	w:Advance(10)
	local b = w:Join(602)
	w:RunSpawned()
	check(w:Board() == "P602\nP601", "newest first", w:Board())
	w:Advance(10)
	w:Leave(a)
	local a2 = w:Join(601)
	w:RunSpawned()
	check(w:Board() == "P601\nP602" and #w.Stores[C0.PassBoost.SupporterStore].Rows[key] == 2,
		"joining again moves the name up (one line per player)", w:Board())
	-- another server's VIPs come in with the refresh; the list keeps MaxSupporters
	local rows = w.Stores[C0.PassBoost.SupporterStore].Rows
	table.insert(rows[key], { U = 900, N = "Far", T = w.Time + 100 })
	table.insert(rows[key], { U = 901, N = "Farther", T = w.Time + 50 })
	w:BoardTick() -- one pass of the loop: refresh, then its wait
	check(w:Board() == "Far\nFarther\nP601", "refresh: other servers' VIPs, newest first, at most MaxSupporters (3)", w:Board())
	-- a hidden name (P5) never goes on the board
	w:Advance(10) -- newer than P601: it would be on the board if the hide were ignored
	local h = w:Join(603, { Hide = true })
	w:RunSpawned()
	check(not string.find(w:Board(), "P603", 1, true), "a VIP who hides their name stays off the board", w:Board())
	-- broken rows are dropped
	rows[key] = { { U = "x" }, 5, { U = 7, N = "", T = 1 }, { U = 8, N = "Ok", T = 2 }, { U = 8, N = "Old", T = 1 } }
	w:BoardTick()
	check(w:Board() == "Ok", "broken rows in the shared list are dropped, one line per player (the newest)", w:Board())
	-- the store failing: this server's board still shows the VIP, no error
	w.Fail[C0.PassBoost.SupporterStore .. ":Update"] = 5
	w:Advance(10)
	local c = w:Join(604, { NoCheck = true })
	local n0 = #w.Spawned
	w.Ms.DebugSetPass(c, "VIP", "on")
	check(string.find(w:Board(), "P604", 1, true) ~= nil, "a Studio VIP override: on this server's board only", w:Board())
	check(#w.Spawned == n0, "(and nothing written to the shared list)", #w.Spawned - n0)
	w.Market.PromptGamePassPurchaseFinished:Fire(c, 13, true)
	w:RunSpawned()
	check(string.find(w:Board(), "P604", 1, true) ~= nil, "the shared list failing: the local board still shows it")
	w.AllowWarn = "supporter board"
	local _ = b and a2 and h
end)

------------------------------------------------------------------ the Studio override
runGroup("debug override", function()
	local w = passWorld({ Ids = { XP2 = 11 }, Owns = { [701] = { [11] = true } } })
	local p = w:Join(701)
	check(w.Ms.HasPass(p, "XP2"), "(owned)")
	check(string.find(w.Ms.DebugSetPass(p, "XP2", "off"), "HasPass = false", 1, true) ~= nil and not w.Ms.HasPass(p, "XP2")
		and p:GetAttribute("PassXP2") == false, "off: the owned pass is off for the test")
	w.Ms.DebugSetPass(p, "XP2", "clear")
	check(w.Ms.HasPass(p, "XP2"), "clear: back to Roblox's answer")
	w.Ms.DebugSetPass(p, "Gold2", "on")
	check(w.Ms.HasPass(p, "Gold2") and w.Data[p].PassSeen.Gold2 == nil, "on: a test pass, never saved")
	check(string.find(w.Ms.DebugSetPass(p, "Nope", "on"), "unknown", 1, true) ~= nil, "an unknown key: refused")
	check(string.find(w.Ms.DebugSetPass(p, "HaloSprout", "on"), "unknown", 1, true) ~= nil, "an attendance look is no pass")
	w:Leave(p)
	local q = w:Join(701)
	check(not w.Ms.HasPass(q, "Gold2") and w.Ms.HasPass(q, "XP2"), "a new session: the test pass is gone")
end)

finish()
