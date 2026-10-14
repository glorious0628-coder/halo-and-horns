-- gamepass_offline.luau : A23-75 (user 2026-10-08) game passes, server side. tools/test_gamepass.py binds
-- CONFIG_SOURCE, UTIL_SOURCE, PROGRESSION_SOURCE and MONETIZATION_SOURCE in front of dev2_kit.luau: the REAL
-- ProgressionService (the 2x boost, what each grant returns, the kill reward line) and the REAL MonetizationService
-- (ownership at join with retries and the saved fallback, PromptGamePassPurchaseFinished, looks, SetLook, the VIP
-- supporter board, the Studio "Pass" override) run on kit doubles: Players, DataStores, a MarketplaceService double
-- (UserOwnsGamePassAsync answers / failures per user and pass, the purchase-finished signal) and a PlayerService double.
-- The sweep over every XP / gold grant in src/ServerScriptService is a source-text check in tools/test_gamepass.py.
-- A23-75 review 2026-10-08: KAIJU_SURVIVE_SOURCE is KaijuService's REAL survive() (with its call / getNum helpers),
-- extracted by tools/test_gamepass.py and run on passWorld's real ProgressionService (kaijuSurvive below).

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())
local EPS = 1e-9
local function okPassId(id) return type(id) == "number" and id >= 0 and id == math.floor(id) end

-- the world. opts: Ids = { [kind or look id] = pass id } (EditConfig), Owns = { [userId] = { [passId] = true } },
-- FailAll = { [passId] = true } (every ask errors), FailTimes = { [passId] = n } (the first n asks error), Studio = true
-- (RunService:IsStudio(); default a live server: A23-75 review 3rd look, Studio purchases take the DebugSetPass road)
local function passWorld(opts)
	opts = opts or {}
	local w = newWorld({ Studio = opts.Studio == true, EditConfig = function(cfg)
		-- 10/14 (set_pass_ids): every world starts "not sold yet" whatever ids Config holds; a group sets the ids it needs
		for _, pass in cfg.GamePasses do pass.Id = 0 end
		for _, look in cfg.Looks do if look.PassId ~= nil then look.PassId = 0 end end
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
	-- A23-182: subscriptions (GetUserSubscriptionStatusAsync answers per user and api id; opts.SubFail = every ask errors)
	w.Subs, w.SubAsks = opts.Subs or {}, {}
	function mp.GetUserSubscriptionStatusAsync(_, player, apiId)
		table.insert(w.SubAsks, { UserId = player.UserId, Id = apiId })
		if opts.SubFail then error("offline subscription failure") end
		if (w.SubFailTimes or 0) > 0 then -- the next N asks error (최종 검수 10/14 ①: the retry)
			w.SubFailTimes -= 1
			error("offline subscription failure")
		end
		local mine = w.Subs[player.UserId]
		return { IsSubscribed = mine ~= nil and mine[apiId] == true, IsRenewing = true }
	end
	local subSig = rbxSignal(w.Warnings)
	subSig.__kind = "RBXScriptSignal"
	w.Players.UserSubscriptionStatusChanged = subSig
	w.SubChanged = subSig
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
		if w.OnWait then w.OnWait(t) end
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
		d.PlaytimeSeconds = 3600 -- past A23-167's first-minutes 2x XP (its own group sets o.Data.PlaytimeSeconds)
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
	-- A23-75 review 2026-10-08 (검수 3rd look): a real purchase = Roblox now says yes, then the purchase signal
	function w:Buy(p, passId)
		self.Owns[p.UserId] = self.Owns[p.UserId] or {}
		self.Owns[p.UserId][passId] = true
		self.Market.PromptGamePassPurchaseFinished:Fire(p, passId, true)
	end
	return w
end

local function attrs(p)
	return { XP2 = p:GetAttribute("PassXP2"), Gold2 = p:GetAttribute("PassGold2"), VIP = p:GetAttribute("PassVIP"),
		Looks = p:GetAttribute("LooksOwned"), On = p:GetAttribute("LookOn") }
end

-- A23-75 review 2026-10-08: KaijuService's real survive(p) on world `w` (its real ProgressionService / MonetizationService
-- through the real `call`); the rest of the kaiju event is a stand-in: opposed (contested), no participants, finish does
-- nothing. Returns survive and SURVIVE_BONUS_MINUTES.
local function kaijuSurvive(w)
	w.Reg.WarService.AddFactionPoints = function() end
	local env = w:Env()
	env.S, env.Config, env.Util, env.Net = w.Reg, w.Config, w.Util, w.Net
	env.TAG, env.WARN_INTERVAL, env.lastWarnAt = "KaijuService", 10, {}
	env.contested = true
	env.publicName = function(p) return p.Name end
	env.participantList = function() return {} end
	env.finish = function() end
	return execute("KaijuSurvive", KAIJU_SURVIVE_SOURCE, env)
end

------------------------------------------------------------------ config
runGroup("config", function()
	local GP = C0.GamePasses
	check(GP.XP2.Price == 199 and GP.Gold2.Price == 149 and GP.VIP.Price == 249, "prices: 2x XP 199, 2x Gold 149, VIP 249 (A23-75)",
		show({ GP.XP2.Price, GP.Gold2.Price, GP.VIP.Price }))
	check(GP.XP2.Attr == "PassXP2" and GP.Gold2.Attr == "PassGold2" and GP.VIP.Attr == "PassVIP",
		"attributes PassXP2 / PassGold2 / PassVIP (the screen's names)")
	-- 10/14: 0 = not made yet (Coming soon), else the user's pass id (tools/set_pass_ids.py): a whole number > 0, never twice
	local ids, seenIds, idsOk = {}, {}, true
	local function addId(key, id)
		ids[key] = id
		if not okPassId(id) then idsOk = false elseif id > 0 then
			if seenIds[id] then idsOk = false end
			seenIds[id] = true
		end
	end
	for key, pass in GP do addId(key, pass.Id) end
	for key, look in C0.Looks do if look.PassId ~= nil then addId(key, look.PassId) end end
	check(idsOk, "pass ids: 0 until the user makes the pass (Coming soon), else a whole number > 0, no id twice", show(ids))
	local n = 0
	for _ in GP do n += 1 end
	check(n == 5 and GP.Stickers.Price == 99 and GP.Stickers.Attr == "PassStickers"
		and GP.Bubbles.Price == 99 and GP.Bubbles.Attr == "PassBubbles",
		"five passes: XP2, Gold2, VIP, the Sticker Pack and the Bubble Pack (99 R$ each; A23-143 / A23-144)", n)
	local B = C0.PassBoost
	check(B.Mult == 2, "the passes double (2x)", B.Mult)
	local want = { Monster = true, Quest = true, Event = true, Bounty = true, War = true, Loot = true, Kaiju = true, SignOn = true,
		Attendance = true, Codex = true } -- A23-153: the monster codex's card rewards are earned gold
	local same = true
	for k in want do if B.GoldSources[k] ~= true then same = false end end
	for k in B.GoldSources do if not want[k] then same = false end end
	check(same, "2x Gold counts for the earned sources only", show(B.GoldSources))
	-- Choice / Finisher (검수 3rd look): a good / evil pick's gold never pays one side more for a paying child
	for _, s in { "Sale", "Refund", "Plunder", "KaijuBank", "KaijuTransfer", "KaijuBonus", "Penalty", "Other", "Choice",
		"Finisher" } do
		check(B.GoldSources[s] == nil, "never 2x: " .. s)
	end
	check(B.CheckTries == 3 and B.CheckWait == 1 and B.MaxSupporters == 30 and B.RefreshSeconds == 300,
		"3 tries (1 s, then 2 s), a board of 30, read every 5 min", show({ B.CheckTries, B.CheckWait, B.MaxSupporters, B.RefreshSeconds }))
	check(B.WriteGap == 10, "the shared supporter list: at most one write per player per 10 s (A23-75 review 2026-10-08)", B.WriteGap)
	-- looks: four sold (99, one pass each), six attendance-only (14 / 50 / 100 days), names fit the shop slot
	local sold, att, bad = 0, {}, {}
	for id, look in C0.Looks do
		if look.Faction ~= "Halo" and look.Faction ~= "Horns" then table.insert(bad, id .. " faction") end
		if type(look.Name) ~= "string" or #look.Name > 12 or #look.Name == 0 then table.insert(bad, id .. " name") end
		if type(look.Icon) ~= "string" or type(look.Order) ~= "number" then table.insert(bad, id .. " icon/order") end
		if look.PassId ~= nil then
			sold += 1
			if look.Price ~= 99 or not okPassId(look.PassId) or look.Unlock ~= nil then table.insert(bad, id .. " sale") end
		else
			local days = type(look.Unlock) == "table" and look.Unlock.Attendance
			if not days then table.insert(bad, id .. " unlock") else att[days] = (att[days] or 0) + 1 end
			if look.Price ~= nil then table.insert(bad, id .. " priced") end
		end
	end
	check(sold == 4 and att[14] == 2 and att[50] == 2 and att[100] == 2 and #bad == 0,
		"looks: 4 sold (99 each, one pass id), attendance-only 14 / 50 / 100 days (a halo and horns each)", show({ sold, att, bad }))
	check(C0.Looks.HaloIce.Name == "Ice Halo" and C0.Looks.HaloGold.Name == "Gold Halo" and C0.Looks.HornsLava.Name == "Lava Horns"
		and C0.Looks.HornsShadow.Name == "Shadow Horns", "the user's four picks keep their names")
	local order = C0.LookOrder()
	check(#order == 10 and order[1] == "HaloIce" and order[4] == "HornsShadow" and order[10] == "HornsPlatinum", "LookOrder: shop order",
		show(order))
	check(C0.RateLimits.SetLook == 0.5, "SetLook at most every 0.5 s", C0.RateLimits.SetLook)
	-- the save fields (additive, Version 3)
	local D = C0.Data.Defaults
	check(type(D.Looks) == "table" and type(D.Looks.Owned) == "table" and D.Looks.On == "" and type(D.PassSeen) == "table"
		and C0.Data.Version == 5, "save: Looks { Owned, On } + PassSeen (additive; Version 5 = A23-153's codex (C1's tier 9 made it 4))")
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
	w:Buy(p, 12)
	check(w.Ms.HasPass(p, "Gold2") and p:GetAttribute("PassGold2") == true and w.Data[p].PassSeen.Gold2 == true,
		"bought: on at once (attribute too) and saved", show(attrs(p)))
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 11, false)
	check(not w.Ms.HasPass(p, "XP2"), "a closed prompt (not bought): nothing")
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 999, true)
	check(not w.Ms.HasPass(p, "VIP") and not w.Ms.HasPass(p, "XP2"), "an unknown pass id: nothing")
	w.Market.PromptGamePassPurchaseFinished:Fire({ Name = "fake" }, 11, true)
	check(true, "a non-player argument is ignored (no error)")
	w:Buy(p, 23)
	check(w.Ms.OwnsLook(p, "HornsLava") and p:GetAttribute("LooksOwned") == "HornsLava", "a look bought: listed at once")
	-- PassBought (game dev 3's PassShop Bought metric): once per real purchase, with the key, after it is on
	check(show(bought) == show({ "P301:Gold2", "P301:HornsLava" }),
		"PassBought: one per real purchase (not a closed prompt, an unknown id or a fake player)", show(bought))
	bought = {}
	w.Ms.PassBought:Connect(function(pl, key) if not w.Ms.HasPass(pl, key) then table.insert(bought, "off " .. key) end end)
	w:Buy(p, 11)
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
	w:Buy(p, 11)
	w.Owns[302][11] = nil -- the join check's (older) answer: no
	w:RunSpawned()
	check(w.Ms.HasPass(p, "XP2") and p:GetAttribute("PassXP2") == true and w.Data[p].PassSeen.XP2 == true,
		"bought during the join check: stays on, and its saved answer stays yes", show(w.Data[p].PassSeen))
	-- VIP bought: on the supporter board at once
	w = passWorld({ Ids = { VIP = 13 }, Owns = { [303] = {} } })
	p = w:Join(303)
	w:Buy(p, 13)
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
	local srcs = { "Monster", "Quest", "Event", "Bounty", "War", "Loot", "Kaiju", "SignOn", "Attendance", "Codex", "Sale", "Refund",
		"Plunder", "KaijuBank", "KaijuTransfer", "KaijuBonus", "Penalty", "Other" }
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
	w:Buy(c, 13)
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

------------------------------------------------------------------ kaiju survive (A23-75 review 2026-10-08)
-- the pouch already holds the 2x Gold pass (its kills paid x2): the +50% bonus made from it is never doubled again
-- ("KaijuBonus"), only its cap is
runGroup("kaiju survive", function()
	local w = passWorld({ Ids = { Gold2 = 12 }, Owns = { [811] = { [12] = true }, [812] = {} } })
	local survive, minutes = kaijuSurvive(w)
	local p = w:Join(811, { Faction = "Horns", Level = 20 })
	local q = w:Join(812, { Faction = "Horns", Level = 20 })
	local cap = C0.HuntValue(20, minutes)
	check(cap > 1000, "(the Lv20 survive bonus cap)", cap)
	local earned = {}
	w.Prog.GoldEarned:Connect(function(pl, amount, source)
		if pl == p then table.insert(earned, source .. "=" .. tostring(amount)) end
	end)
	-- the same kills (2000 gold) fill the pass owner's pouch with 4000
	w.Prog.AddCarriedGold(p, 2000, "Monster")
	w.Prog.AddCarriedGold(q, 2000, "Monster")
	check(w.Data[p].CarriedGold == 4000 and w.Data[q].CarriedGold == 2000, "(the pouches: 4000 with 2x Gold, 2000 without)",
		show({ w.Data[p].CarriedGold, w.Data[q].CarriedGold }))
	table.clear(earned)
	local bp, bq, n0 = w.Data[p].BankGold, w.Data[q].BankGold, #w.Notices
	survive(p)
	survive(q)
	local gotP, gotQ = w.Data[p].BankGold - bp, w.Data[q].BankGold - bq
	check(gotP == 6000 and gotQ == 3000 and w.Data[p].CarriedGold == 0,
		"survived after the same kills: the bonus is half the pouch (2000 with 2x Gold, 1000 without), the pass counts once",
		show({ gotP, gotQ }))
	check(show(earned) == show({ "KaijuBank=4000", "KaijuBonus=2000" }), "the pouch banks as KaijuBank, the bonus as KaijuBonus",
		show(earned))
	local lines = w:NoticesFor(p, n0)
	check(#lines == 1 and has(lines[1], w.Util.FormatNumber(6000)), "the survive line shows what was added", show(lines))
	-- at the cap: the cap doubles with the pass, so the owner still gets 2x (not 1x, not 4x)
	w.Prog.AddCarriedGold(p, 10 * cap, "Monster")
	w.Prog.AddCarriedGold(q, 10 * cap, "Monster")
	bp, bq = w.Data[p].BankGold, w.Data[q].BankGold
	survive(p)
	survive(q)
	gotP, gotQ = w.Data[p].BankGold - bp, w.Data[q].BankGold - bq
	check(gotP == 20 * cap + 2 * cap and gotQ == 10 * cap + cap, "at the cap: the bonus cap doubles with 2x Gold",
		show({ gotP - 20 * cap, gotQ - 10 * cap, cap }))
end)

------------------------------------------------------------------ the join window (A23-75 review 2026-10-08)
-- the saved answers count from PlayerReady on: grants paid there (QuestService's day check pays finished dailies and the
-- chest, attendance) and while Roblox is slow or down see an owned pass
runGroup("join window", function()
	local w = passWorld({ Ids = { XP2 = 11, Gold2 = 12, VIP = 13 }, Owns = { [851] = { [11] = true, [12] = true } } })
	local paid = {}
	w.Reg.PlayerService.PlayerReady:Connect(function(pl) -- a later handler (connected after MonetizationService's)
		paid[pl.UserId] = { Gold = w.Prog.AddBankGold(pl, 100, "Quest"), XP = w.Prog.AddXP(pl, 100) }
	end)
	local p = w:Join(851, { Data = { PassSeen = { XP2 = true, Gold2 = true } } })
	check(paid[851] ~= nil and paid[851].Gold == 200 and paid[851].XP == 200,
		"grants paid inside PlayerReady see the saved passes (2x gold and XP before Roblox answers)", show(paid[851]))
	check(w.Ms.HasPass(p, "XP2") and w.Ms.HasPass(p, "Gold2") and not w.Ms.HasPass(p, "VIP"), "(Roblox agrees after the check)")
	-- Roblox down: the saved passes count during every try, not only after their own three
	w = passWorld({ Ids = { XP2 = 11, Gold2 = 12, VIP = 13 }, FailAll = { [11] = true, [12] = true, [13] = true } })
	local during, r = {}, nil
	w.OnAsk = function()
		table.insert(during, w.Ms.HasPass(r, "XP2") and w.Ms.HasPass(r, "Gold2") and not w.Ms.HasPass(r, "VIP"))
	end
	r = w:Join(852, { NoCheck = true, Data = { PassSeen = { XP2 = true, Gold2 = true } } })
	w:RunSpawned()
	local all = #during == 9
	for _, v in during do
		if v ~= true then all = false end
	end
	check(all and w.Ms.HasPass(r, "Gold2") and w.Ms.HasPass(r, "XP2"), "Roblox down: the saved passes count during every try",
		show(during))
	-- only a sold pass's saved answer counts; Roblox's answer replaces it (a refund turns it off)
	w = passWorld({ Ids = { Gold2 = 12 }, Owns = { [853] = {} } })
	local u = w:Join(853, { NoCheck = true, Data = { PassSeen = { XP2 = true, Gold2 = true } } })
	check(not w.Ms.HasPass(u, "XP2") and w.Ms.HasPass(u, "Gold2"), "only a sold pass's saved answer counts (XP2 id 0: off)")
	w:RunSpawned()
	check(not w.Ms.HasPass(u, "Gold2") and u:GetAttribute("PassGold2") == false and w.Data[u].PassSeen.Gold2 == false,
		"Roblox says no (refunded): the saved answer is replaced", show(attrs(u)))
end)

------------------------------------------------------------------ supporter board: a later hide (A23-75 review 2026-10-08)
-- a hidden name never: hiding later, rejoining hidden or a refund takes it off this board at once and off the shared list
-- (one write per player per WriteGap, with the latest choice)
runGroup("supporters: hide later", function()
	local key, storeName, gap = C0.PassBoost.SupporterKey, C0.PassBoost.SupporterStore, C0.PassBoost.WriteGap
	local w = passWorld({ Ids = { VIP = 13 }, Owns = { [901] = { [13] = true }, [902] = { [13] = true }, [903] = {}, [904] = {} } })
	local ps = w.Reg.PlayerService
	local rows = w.Stores[storeName].Rows
	local function shared()
		local ids = {}
		for _, e in rows[key] or {} do table.insert(ids, e.U) end
		return ids
	end
	local function writes()
		local n = 0
		for _, c in w.DSCalls do
			if c.Op == "Update" and c.Store == storeName then n += 1 end
		end
		return n
	end
	local a = w:Join(901)
	check(w:Board() == "P901" and show(shared()) == show({ 901 }), "(a VIP who shows their name: listed here and in the shared list)",
		show({ w:Board(), shared() }))
	-- hides the name later (P5: AnnounceService SetStat): off this board at once, off the shared list when the gap ends
	ps.SetStat(a, "HideAnnounceName", true)
	w:RunSpawned()
	check(w:Board() == "", "hidden later: off this server's board at once", w:Board())
	w:Advance(gap)
	check(show(shared()) == "{}", "hidden later: off the shared list too (written when the write gap ends)", show(shared()))
	w:BoardTick()
	check(w:Board() == "", "a refresh does not bring the hidden name back", w:Board())
	-- shows it again: listed again
	w:Advance(gap)
	ps.SetStat(a, "HideAnnounceName", false)
	w:RunSpawned()
	check(w:Board() == "P901" and show(shared()) == show({ 901 }), "shown again: listed again here and in the shared list",
		show({ w:Board(), shared() }))
	-- a hide on / off spam (one toggle per frame): nothing written inside the gap, then one write with the last choice
	local n0 = writes()
	for i = 1, 10 do
		ps.SetStat(a, "HideAnnounceName", i % 2 == 1)
		w:RunSpawned()
	end
	check(w:Board() == "P901" and writes() == n0, "toggling inside the write gap: this board follows, the shared list waits",
		show({ w:Board(), writes() - n0 }))
	w:Advance(gap)
	check(writes() == n0 + 1 and show(shared()) == show({ 901 }), "... then one write with the last choice (shown)",
		show({ writes() - n0, shared() }))
	-- hidden, then gone before the gap ends: the removal still lands
	ps.SetStat(a, "HideAnnounceName", true)
	w:Leave(a)
	w:Advance(gap)
	check(show(shared()) == "{}", "hidden and left inside the write gap: the removal is still written", show(shared()))
	-- listed by an earlier session, rejoins with the name hidden: taken off at once
	rows[key] = { { U = 902, N = "P902", T = w.Time } }
	w:BoardTick()
	check(w:Board() == "P902", "(listed by an earlier session)", w:Board())
	local b = w:Join(902, { Hide = true })
	check(w:Board() == "" and show(shared()) == "{}", "a listed VIP who rejoins hidden: off this board and the shared list",
		show({ w:Board(), shared() }))
	-- the shared list still carries a hidden player of this server (their removal has not landed): never shown here
	rows[key] = { { U = 902, N = "P902", T = w.Time } }
	w:BoardTick()
	check(w:Board() == "", "a refresh never shows a hidden player of this server, whatever the shared list says", w:Board())
	-- refunded: Roblox now says no to a VIP saved as owned
	rows[key] = { { U = 903, N = "P903", T = w.Time } }
	w:BoardTick()
	local c = w:Join(903, { Data = { PassSeen = { VIP = true } } })
	check(not w.Ms.HasPass(c, "VIP") and w:Board() == "" and show(shared()) == "{}",
		"a refunded VIP comes off this board and the shared list", show({ w:Board(), shared() }))
	-- no VIP: a hide toggle writes nothing; a hidden buyer of VIP stays off both boards
	local n1 = writes()
	ps.SetStat(c, "HideAnnounceName", true)
	ps.SetStat(c, "HideAnnounceName", false)
	w:Advance(gap)
	w:RunSpawned()
	check(writes() == n1, "a player without VIP toggling the hide writes nothing to the shared list", writes() - n1)
	local d = w:Join(904, { Hide = true })
	w:Buy(d, 13)
	w:RunSpawned()
	w:Advance(gap)
	check(w.Ms.HasPass(d, "VIP") and w:Board() == "" and show(shared()) == "{}", "a hidden player who buys VIP stays off both boards",
		show({ w:Board(), shared() }))
	local _ = b
end)

------------------------------------------------------------------ review 2nd look
runGroup("review 2nd look", function()
	local storeName, key, gap = C0.PassBoost.SupporterStore, C0.PassBoost.SupporterKey, C0.PassBoost.WriteGap
	check(C0.PassBoost.WriteRetries == 3, "a failed shared-list write is tried again 3 times", C0.PassBoost.WriteRetries)
	-- a hide whose removal write fails once: tried again after the gap, the shared list loses the name
	local w = passWorld({ Ids = { VIP = 13 }, Owns = { [951] = { [13] = true }, [952] = { [13] = true } } })
	local rows = w.Stores[storeName].Rows
	local a = w:Join(951)
	check(rows[key] and #rows[key] == 1, "(listed)")
	w:Advance(gap)
	w.Fail[storeName .. ":Update"] = 1
	w.Reg.PlayerService.SetStat(a, "HideAnnounceName", true)
	w:RunSpawned()
	check(#rows[key] == 1, "(the removal write failed once)")
	w:Advance(gap)
	w:RunSpawned()
	check(#rows[key] == 0, "the failed removal is written on the next try", #rows[key])
	-- every try failing: at most WriteRetries more tries, then it stops
	local b = w:Join(952)
	w:Advance(gap)
	w.Fail[storeName .. ":Update"] = 99
	w.Reg.PlayerService.SetStat(b, "HideAnnounceName", true)
	w:RunSpawned()
	for _ = 1, 6 do
		w:Advance(gap)
		w:RunSpawned()
	end
	local n = 0
	for _, c in w.DSCalls do if c.Store == storeName and c.Op == "Update" then n += 1 end end
	check(w.Fail[storeName .. ":Update"] == 99 - 4, "a write that keeps failing: 1 + 3 tries, then it stops", 99 - w.Fail[storeName .. ":Update"])
	w.AllowWarn = "supporter board"
	local _ = n
	-- a long verified nickname (Hangul, 3 bytes a letter) is listed
	local w2 = passWorld({ Ids = { VIP = 13 }, Owns = { [961] = { [13] = true } } })
	local long = string.rep("가", 20) -- the longest nickname (20 letters, 60 bytes; Config.Nickname)
	local p = w2:NewPlayer(960, {})
	p:Destroy()
	local q = w2:Join(961, { NoCheck = true })
	q:SetAttribute("Nickname", long)
	q:SetAttribute("NicknameVerified", true)
	w2:RunSpawned()
	check(w2:Board() == long, "a 20-letter Hangul nickname (60 bytes) is on the board", #w2:Board())
	-- the same pass id in two entries: a warning at Start
	local w3 = passWorld({ Ids = { XP2 = 11, HaloIce = 11 }, Studio = true })
	local warned = false
	for _, text in w3.Warnings do if string.find(text, "used twice", 1, true) then warned = true end end
	check(warned, "one game pass id in two entries: a warning at Start")
	w3.AllowWarn = "used twice"
	-- the top level with a full bar: nothing is added and nothing is shown
	local w4 = passWorld({ Ids = { XP2 = 11 }, Owns = { [971] = { [11] = true } } })
	local top = w4:Join(971, { Level = C0.Levels.MaxLevel, Data = { XP = C0.XPToNext(C0.Levels.MaxLevel) } })
	check(w4.Prog.AddXP(top, 50) == 0, "a full bar at the top level: AddXP returns 0 (nothing added)", w4.Prog.AddXP(top, 50))
	local r = w4:Join(972, { Level = C0.Levels.MaxLevel, Data = { XP = C0.XPToNext(C0.Levels.MaxLevel) - 30 } })
	check(w4.Prog.AddXP(r, 50) == 30, "30 short of full at the top level: AddXP returns 30", w4.Prog.AddXP(r, 50))
end)

------------------------------------------------------------------ review 3rd look (검수 2026-10-08)
runGroup("review 3rd look", function()
	local storeName, key, gap = C0.PassBoost.SupporterStore, C0.PassBoost.SupporterKey, C0.PassBoost.WriteGap
	local function writes(w, name)
		local n = 0
		for _, c in w.DSCalls do if c.Store == (name or storeName) and c.Op == "Update" then n += 1 end end
		return n
	end
	-- 1. a forged purchase signal (Roblox says no): nothing kept, a warning
	local w = passWorld({ Ids = { XP2 = 11, VIP = 13 }, Owns = { [1001] = {} } })
	local bought = {}
	w.Ms.PassBought:Connect(function(_, k) table.insert(bought, k) end)
	local p = w:Join(1001)
	local asks, waits = #w.Asks, #w.Waits
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 11, true)
	w.Market.PromptGamePassPurchaseFinished:Fire(p, 13, true)
	w:RunSpawned()
	check(#w.Asks == asks + 6, "a purchase signal asks Roblox again; a no is asked twice more (2 s, 5 s)", #w.Asks - asks)
	local gaps = {}
	for i = waits + 1, #w.Waits do table.insert(gaps, w.Waits[i]) end
	check(#gaps == 4 and gaps[1] == 2 and gaps[2] == 3 and gaps[3] == 2 and gaps[4] == 3,
		"the rechecks wait 2 s, then 3 s more (5 s after the signal)", show(gaps))
	check(not w.Ms.HasPass(p, "XP2") and not w.Ms.HasPass(p, "VIP") and p:GetAttribute("PassXP2") == false
		and w.Data[p].PassSeen.XP2 == false and w:Board() == "" and writes(w) == 0 and #bought == 0,
		"Roblox says no: no pass, no saved yes, no board, no shared write, no PassBought",
		show({ attrs(p), w.Data[p].PassSeen, w:Board(), writes(w), bought }))
	local warned = 0
	for _, text in w.Warnings do if string.find(text, "does not confirm", 1, true) then warned += 1 end end
	check(warned == 2, "each refused purchase is warned", warned)
	w.AllowWarn = "does not confirm"
	-- 1b. Roblox first says no (a cached answer), then yes on a recheck: the buyer gets it this session, saved
	for _, flipAt in { 2, 3 } do
		local wf = passWorld({ Ids = { XP2 = 11 }, Owns = { [1003] = {} } })
		local bf = {}
		wf.Ms.PassBought:Connect(function(_, k) table.insert(bf, k) end)
		local pf = wf:Join(1003)
		local base, n = #wf.Asks, 0
		wf.OnAsk = function(userId, passId)
			n += 1
			if n == flipAt then wf.Owns[userId][passId] = true end
		end
		wf.Market.PromptGamePassPurchaseFinished:Fire(pf, 11, true)
		wf:RunSpawned()
		check(#wf.Asks - base == flipAt and wf.Ms.HasPass(pf, "XP2") and pf:GetAttribute("PassXP2") == true
			and wf.Data[pf].PassSeen.XP2 == true and #bf == 1 and bf[1] == "XP2",
			"a cached no then yes on recheck " .. flipAt .. ": the pass, saved yes, PassBought, no more asks",
			show({ #wf.Asks - base, attrs(pf), wf.Data[pf].PassSeen, bf }))
		local wn = 0
		for _, text in wf.Warnings do if string.find(text, "does not confirm", 1, true) then wn += 1 end end
		check(wn == 0, "a yes on recheck is not warned", wn)
	end
	-- 1c. the buyer leaves during the recheck wait: nothing more asked, nothing kept
	local wl = passWorld({ Ids = { XP2 = 11 }, Owns = { [1004] = {} } })
	local pl = wl:Join(1004)
	local lb = #wl.Asks
	wl.OnWait = function() pl.Parent = nil end
	wl.Market.PromptGamePassPurchaseFinished:Fire(pl, 11, true)
	wl:RunSpawned()
	check(#wl.Asks - lb == 1 and not wl.Ms.HasPass(pl, "XP2"), "left before the recheck: no more asks, no pass",
		#wl.Asks - lb)
	-- 2. Roblox does not answer the purchase check: this session only (nothing saved, this board only, no PassBought)
	local w2 = passWorld({ Ids = { VIP = 13, XP2 = 11 }, FailAll = { [13] = true, [11] = true } })
	local b2 = {}
	w2.Ms.PassBought:Connect(function(_, k) table.insert(b2, k) end)
	local q = w2:Join(1002)
	w2.Market.PromptGamePassPurchaseFinished:Fire(q, 13, true)
	w2.Market.PromptGamePassPurchaseFinished:Fire(q, 11, true)
	w2:RunSpawned()
	w2:Advance(gap)
	check(w2.Ms.HasPass(q, "VIP") and w2.Ms.HasPass(q, "XP2") and q:GetAttribute("PassVIP") == true,
		"no answer: on for this session", show(attrs(q)))
	check(w2.Data[q].PassSeen.VIP ~= true and w2.Data[q].PassSeen.XP2 ~= true and #b2 == 0,
		"no answer: no saved yes, no PassBought", show({ w2.Data[q].PassSeen, b2 }))
	check(w2:Board() == "P1002" and writes(w2) == 0, "no answer: this server's board only (no shared write)",
		show({ w2:Board(), writes(w2) }))
	-- a hide toggle and a nickname for that unconfirmed VIP stay local too
	w2.Reg.PlayerService.SetStat(q, "HideAnnounceName", true)
	w2.Reg.PlayerService.SetStat(q, "HideAnnounceName", false)
	q:SetAttribute("Nickname", "Sunny")
	q:SetAttribute("NicknameVerified", true)
	w2:RunSpawned()
	w2:Advance(gap)
	w2:RunSpawned()
	local rows2 = w2.Stores[storeName] and w2.Stores[storeName].Rows[key] or nil
	check(w2:Board() == "Sunny" and (rows2 == nil or #rows2 == 0),
		"an unconfirmed VIP's hide / name changes stay on this board only", show({ w2:Board(), writes(w2) }))
	-- 3. Studio: a purchase takes the DebugSetPass road; the shared list is the Studio copy
	local w3 = passWorld({ Ids = { XP2 = 11, VIP = 13 }, Owns = { [1003] = {}, [1004] = { [13] = true } }, Studio = true })
	local b3 = {}
	w3.Ms.PassBought:Connect(function(_, k) table.insert(b3, k) end)
	local s = w3:Join(1003)
	local a3 = #w3.Asks
	w3.Market.PromptGamePassPurchaseFinished:Fire(s, 11, true)
	w3.Market.PromptGamePassPurchaseFinished:Fire(s, 13, true)
	w3:RunSpawned()
	w3:Advance(gap)
	check(w3.Ms.HasPass(s, "XP2") and w3.Ms.HasPass(s, "VIP") and #w3.Asks == a3, "Studio: the test purchase is on (no ask)",
		show({ attrs(s), #w3.Asks - a3 }))
	check(w3.Data[s].PassSeen.XP2 ~= true and w3.Data[s].PassSeen.VIP ~= true and w3.Data[s].DebugTainted == true and #b3 == 0,
		"Studio: nothing saved as owned, the save is DebugTainted, no PassBought",
		show({ w3.Data[s].PassSeen, w3.Data[s].DebugTainted, b3 }))
	check(string.find(w3:Board(), "P1003", 1, true) ~= nil and writes(w3) == 0 and writes(w3, storeName .. "_STUDIO") == 0,
		"Studio: the test VIP on this server's board only", show({ w3:Board(), writes(w3) }))
	w3:Join(1004) -- a real VIP owner joining Studio: the Studio copy of the shared list
	w3:RunSpawned()
	local studioRows = w3.Stores[storeName .. "_STUDIO"] and w3.Stores[storeName .. "_STUDIO"].Rows[key] or {}
	check(writes(w3, storeName .. "_STUDIO") == 1 and writes(w3) == 0 and studioRows[1] ~= nil and studioRows[1].U == 1004,
		"Studio writes the _STUDIO copy of the supporter list, never the live one",
		show({ writes(w3, storeName .. "_STUDIO"), writes(w3) }))
	-- 4. the board follows the verified nickname
	local w4 = passWorld({ Ids = { VIP = 13 }, Owns = { [1005] = { [13] = true } } })
	local n = w4:Join(1005)
	local rows = w4.Stores[storeName].Rows
	check(w4:Board() == "P1005" and rows[key][1].N == "P1005", "(listed with the Roblox display name before the nickname)")
	local w0 = writes(w4)
	n:SetAttribute("Nickname", "Sunny")
	w4:RunSpawned()
	w4:Advance(gap)
	w4:RunSpawned()
	check(w4:Board() == "P1005" and writes(w4) == w0, "a nickname not verified yet: unchanged, nothing written",
		show({ w4:Board(), writes(w4) - w0 }))
	n:SetAttribute("NicknameVerified", true)
	check(w4:Board() == "Sunny", "verified: this server's board shows it at once", w4:Board())
	w4:RunSpawned()
	w4:Advance(gap)
	w4:RunSpawned()
	check(rows[key][1].N == "Sunny" and #rows[key] == 1, "and the shared list (one line, renamed)", show(rows[key]))
	local before = writes(w4)
	n:SetAttribute("NicknameVerified", false)
	n:SetAttribute("NicknameVerified", true)
	w4:Advance(gap)
	w4:RunSpawned()
	check(w4:Board() == "Sunny" and writes(w4) == before + 1, "unverified then verified again: back to the nickname",
		show({ w4:Board(), writes(w4) - before }))
	local before2 = writes(w4)
	n:SetAttribute("Nickname", "Sunny")
	w4:Advance(gap)
	w4:RunSpawned()
	check(writes(w4) == before2, "the same name again: nothing written", writes(w4) - before2)
	n:SetAttribute("Nickname", "Moon")
	w4:Advance(gap)
	w4:RunSpawned()
	check(w4:Board() == "Moon" and rows[key][1].N == "Moon", "a later nickname change follows", show({ w4:Board(), rows[key][1].N }))
	-- a player without VIP changing the nickname: nothing written
	local w5 = passWorld({ Ids = { VIP = 13 }, Owns = { [1006] = {} } })
	local o = w5:Join(1006)
	o:SetAttribute("Nickname", "Star")
	o:SetAttribute("NicknameVerified", true)
	w5:Advance(gap)
	w5:RunSpawned()
	check(w5:Board() == "" and writes(w5) == 0, "no VIP: a nickname writes nothing", show({ w5:Board(), writes(w5) }))
	-- 5. a story pick's gold ("Choice") is never 2x; the quest's own reward ("Quest") is
	local w6 = passWorld({ Ids = { Gold2 = 12 }, Owns = { [1007] = { [12] = true } } })
	local g = w6:Join(1007)
	local choice = w6.Prog.AddBankGold(g, 60, "Choice")
	local quest = w6.Prog.AddBankGold(g, 60, "Quest")
	check(choice == 60 and quest == 120, "2x Gold: a pick's gold 60 -> 60, a quest reward 60 -> 120", show({ choice, quest }))
end)

------------------------------------------------------------------ A23-139: the craft XP pass (CraftService as text)
-- CraftService (게임성 개발 3) reads the 2x XP pass once, for the craft XP of a finished craft; what a craft makes (its
-- count, its +N, a weapon / gear) never reads it (검수 2026-10-08: items are never 2x)
runGroup("craft XP pass", function()
	local code = string.gsub(CRAFT_SOURCE, "%-%-[^\n]*", "")
	local reads = select(2, string.gsub(code, "PassMult%(", ""))
	check(reads == 1 and string.find(code, 'ps.PassMult(player, "XP2")', 1, true) ~= nil,
		"CraftService reads one pass, once: the 2x XP pass", tostring(reads))
	local a = string.find(code, "local function complete(", 1, true)
	local b = a and string.find(code, "\nend\n", a, true)
	local body = (a and b) and string.sub(code, a, b) or ""
	local words = select(2, string.gsub(code, "%f[%w_]pass%f[^%w_]", ""))
	local inBody = select(2, string.gsub(body, "%f[%w_]pass%f[^%w_]", ""))
	check(words == 2 and inBody == 2 and string.find(body, "xp = math.floor(num(r.XP) * (okPass and num(pass, 1) or 1))", 1, true) ~= nil,
		"the pass value is used in the craft XP line only (never the count, the +N or the result)", words .. " / " .. inBody)
	local p0 = string.find(code, "local function payOut(", 1, true)
	local p1 = p0 and string.find(code, "\nend\n", p0, true)
	local pay = (p0 and p1) and string.sub(code, p0, p1) or "Pass"
	check(not string.find(pay, "[Pp]ass"), "payOut (the result: weapon, gear, items) never reads a pass", "")
end)

------------------------------------------------------------------ A23-143 chat stickers
runGroup("stickers", function()
	local w = passWorld({ Ids = { Stickers = 31 }, Owns = { [601] = { [31] = true } } })
	local C = w.Config
	-- a living character (Util.IsAlive: a Humanoid with Health > 0 and a root)
	local function body(p)
		local hum = { Health = 100 }
		p.Character = { Parent = true,
			FindFirstChildOfClass = function(_, cls) return cls == "Humanoid" and hum or nil end,
			FindFirstChild = function(_, name) return name == "HumanoidRootPart" and {} or nil end }
		return hum
	end
	local owner, plain = w:Join(601), w:Join(602)
	body(owner)
	local plainHum = body(plain)
	local remote = w.Net.Get("SendSticker")
	local function sent(p, key)
		local n = 0
		for _, f in w.Fx do
			if f.Kind == "Sticker" and f.Player == nil and f.Data.UserId == p.UserId and (key == nil or f.Data.Key == key) then n += 1 end
		end
		return n
	end
	local free = 0
	for _, k in C.Stickers.Order do if C.StickerFree(k) then free += 1 end end
	check(#C.Stickers.Order == 18 and free == 5 and C.StickerFree("EmoThumbsUp") and C.StickerFree("EmoQuestion") and C.StickerFree("EmoExclaim")
		and C.StickerFree("EmoHelp") and C.StickerFree("EmoThanks") and not C.StickerFree("EmoHeart") and not C.StickerFree("EmoGG")
		and not C.StickerFree("EmoStress"), "18 stickers; the 5 basic ones are free (the art's Free); GG and the other 12 are the pack's",
		show({ #C.Stickers.Order, free }))
	check(owner:GetAttribute("PassStickers") == true and plain:GetAttribute("PassStickers") == false, "PassStickers follows the pass", "")
	remote.OnServerEvent:Fire(plain, "EmoThumbsUp")
	check(sent(plain, "EmoThumbsUp") == 1, "a free sticker: Fx Sticker { UserId, Key } to everyone", sent(plain))
	w:Advance(3)
	remote.OnServerEvent:Fire(plain, "EmoHeart")
	check(sent(plain, "EmoHeart") == 0, "a pack sticker without the pass: nothing", "")
	w:Advance(3)
	remote.OnServerEvent:Fire(owner, "EmoGG")
	check(sent(owner, "EmoGG") == 1, "the pass owner sends GG", "")
	remote.OnServerEvent:Fire(owner, "EmoCrown")
	check(sent(owner, "EmoCrown") == 0, "a second sticker within RateLimits.SendSticker (2 s): dropped", "")
	w:Advance(3)
	remote.OnServerEvent:Fire(owner)
	remote.OnServerEvent:Fire(owner, "EmoCrown", "x")
	remote.OnServerEvent:Fire(owner, 5)
	remote.OnServerEvent:Fire(owner, "Nope")
	remote.OnServerEvent:Fire(owner, "EmoStress")
	check(sent(owner) == 1, "no / two arguments, not a string, an unknown or non-sticker art id: nothing", sent(owner))
	w:Advance(3)
	plainHum.Health = 0
	remote.OnServerEvent:Fire(plain, "EmoHelp")
	check(sent(plain, "EmoHelp") == 0, "a dead player sends nothing", "")
	plainHum.Health = 100
	w.Ready[plain] = nil
	w:Advance(3)
	remote.OnServerEvent:Fire(plain, "EmoHelp")
	check(sent(plain, "EmoHelp") == 0, "a player not ready sends nothing", "")
end)

------------------------------------------------------------------ A23-144 chat bubble skins
runGroup("bubbles", function()
	local w = passWorld({ Ids = { Bubbles = 41 }, Owns = { [701] = { [41] = true } },
		EditConfig = function(c) table.insert(c.Bubbles.Order, "BubbleTestPack") end })
	local C = w.Config
	check(C.Bubbles.Free.Halo == "BubbleHalo" and C.Bubbles.Free.Horns == "BubbleHorns" and C.Bubbles.Free.Neutral == "BubbleArtisan"
		and C.Data.Defaults.Bubble == "" and C.BubbleSide("BubbleHorns") == "Horns" and C.BubbleSide("BubbleTestPack") == nil
		and #C.Bubbles.Order == 10 and C.IsBubble("BubbleCrown") and C.BubbleSide("BubblePixel") == nil,
		"each side's free bubble; the save starts at '' (my side's)", "")
	local owner = w:Join(701, { Faction = "Halo" })
	local plain = w:Join(702, { Faction = "Horns" })
	local artisan = w:Join(703, { Faction = "Neutral" })
	check(owner:GetAttribute("BubbleOn") == "BubbleHalo" and plain:GetAttribute("BubbleOn") == "BubbleHorns"
		and artisan:GetAttribute("BubbleOn") == "BubbleArtisan" and owner:GetAttribute("PassBubbles") == true
		and plain:GetAttribute("PassBubbles") == false, "at join: BubbleOn = my side's free bubble; PassBubbles follows the pass",
		show({ owner:GetAttribute("BubbleOn"), plain:GetAttribute("BubbleOn") }))
	local remote = w.Net.Get("SetBubble")
	remote.OnServerEvent:Fire(owner, "BubbleTestPack")
	check(owner:GetAttribute("BubbleOn") == "BubbleTestPack" and w.Data[owner].Bubble == "BubbleTestPack", "the pass owner picks a pack skin (saved)", "")
	remote.OnServerEvent:Fire(plain, "BubbleTestPack")
	check(plain:GetAttribute("BubbleOn") == "BubbleHorns" and w.Data[plain].Bubble == "", "a pack skin without the pass: refused", "")
	w:Advance(1)
	remote.OnServerEvent:Fire(plain, "BubbleHalo")
	check(plain:GetAttribute("BubbleOn") == "BubbleHorns" and w.Data[plain].Bubble == "", "the other side's free bubble: refused", "")
	w:Advance(1)
	remote.OnServerEvent:Fire(owner, "BubbleHalo")
	remote.OnServerEvent:Fire(owner, "BubbleTestPack")
	check(owner:GetAttribute("BubbleOn") == "BubbleHalo", "twice within 0.5 s: the second is dropped (rate limit)", owner:GetAttribute("BubbleOn"))
	w:Advance(1)
	remote.OnServerEvent:Fire(owner)
	remote.OnServerEvent:Fire(owner, "BubbleTestPack", "x")
	remote.OnServerEvent:Fire(owner, 5)
	remote.OnServerEvent:Fire(owner, "Nope")
	remote.OnServerEvent:Fire(owner, string.rep("a", 40))
	check(owner:GetAttribute("BubbleOn") == "BubbleHalo", "no / two arguments, not a string, unknown, too long: ignored", "")
	w:Advance(1)
	remote.OnServerEvent:Fire(owner, "BubbleTestPack")
	w:Advance(1)
	-- a saved pick that is not usable any more (the pass gone / the side changed) shows my side's free one; the pick stays
	w.Data[owner].Bubble = "BubbleHalo"
	owner:SetAttribute("Faction", "Horns")
	w.Reg.FactionService.FactionChanged:Fire(owner)
	check(owner:GetAttribute("BubbleOn") == "BubbleHorns" and w.Data[owner].Bubble == "BubbleHalo",
		"a side change: the old side's bubble comes off (my new side's free one), the pick is kept", show(owner:GetAttribute("BubbleOn")))
	owner:SetAttribute("Faction", "Halo")
	w.Reg.FactionService.FactionChanged:Fire(owner)
	check(owner:GetAttribute("BubbleOn") == "BubbleHalo", "back on that side: it shows again", "")
	remote.OnServerEvent:Fire(owner, "")
	check(owner:GetAttribute("BubbleOn") == "BubbleHalo" and w.Data[owner].Bubble == "", "'' = my side's free one", "")
	local saved = w:Join(704, { Faction = "Horns", Data = { Bubble = "BubbleTestPack" } })
	check(saved:GetAttribute("BubbleOn") == "BubbleHorns" and w.Data[saved].Bubble == "BubbleTestPack",
		"a saved pack skin without the pass shows the free one (the pick waits for the pass)", "")
end)

------------------------------------------------------------------ A23-167 the first minutes x2 XP (게임성 개발 2, 2026-10-14)
------------------------------------------------------------------ A23-182 the Fast Travel subscription (2026-10-14)
runGroup("subscription", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local S0 = C.Subscriptions.FastTravel
	check(S0.Id == 118606392447792 and S0.Attr == "SubFastTravel", "Config.Subscriptions.FastTravel: the Creator Hub id, attribute SubFastTravel", show(S0))
	local info = C.SubscriptionInfo.FastTravel
	check(info.Name == "Fast Travel" and info.Line == "Teleport to any zone you have unlocked from the menu. No stats are for sale."
		and info.Price == 149 and info.Attr == "SubFastTravel" and info.Icon == "IconTravel" and info.Id == "EXP-118606392447792",
		"Config.SubscriptionInfo.FastTravel: the shop card's keys, its Id made from Config.Subscriptions", show(info))
	check(C.PassInfo == nil or C.PassInfo.FastTravel == nil, "not a pass (PassInfo has no FastTravel)", "")
	local API = "EXP-118606392447792"
	local w = passWorld({ Subs = { [2] = { [API] = true } } })
	check(w.Ms.SubscriptionApiId("FastTravel") == API, "the api id is EXP-<id>", tostring(w.Ms.SubscriptionApiId("FastTravel")))
	local a = w:Join(1)
	local b = w:Join(2)
	check(a:GetAttribute("SubFastTravel") == false and not w.Ms.HasSub(a, "FastTravel"), "not subscribed: SubFastTravel false", "")
	check(b:GetAttribute("SubFastTravel") == true and w.Ms.HasSub(b, "FastTravel") == true, "subscribed: SubFastTravel true", "")
	local asked = 0
	for _, x in w.SubAsks do if x.Id == API then asked += 1 end end
	check(asked == 2, "one ask a join, with the api id", show(w.SubAsks))
	-- bought during the session: Roblox's signal -> asked again
	w.Subs[1] = { [API] = true }
	w.SubChanged:Fire(a, "EXP-999")
	check(a:GetAttribute("SubFastTravel") == false, "another subscription's change: nothing", "")
	w.SubChanged:Fire(a, API)
	check(a:GetAttribute("SubFastTravel") == true and w.Ms.HasSub(a, "FastTravel") == true, "its change: asked again, now on", "")
	-- ended: off again at the next answer
	w.Subs[2] = {}
	w.SubChanged:Fire(b, API)
	check(b:GetAttribute("SubFastTravel") == false and not w.Ms.HasSub(b, "FastTravel"), "ended: off", "")
	w:Leave(a)
	check(not w.Ms.HasSub(a, "FastTravel"), "a player who left: nothing kept", "")
	-- Roblox fails (or Studio): not subscribed, no warning
	local f = passWorld({ SubFail = true, Subs = { [3] = { [API] = true } } })
	local c = f:Join(3)
	check(c:GetAttribute("SubFastTravel") == false and not f.Ms.HasSub(c, "FastTravel") and #f.Warnings == 0, "a failing ask: off, no warning",
		table.concat(f.Warnings, " | "))
	-- Id 0 = off: never asked
	local z = passWorld({ EditConfig = function(cfg) cfg.Subscriptions.FastTravel.Id = 0 end, Subs = { [4] = { [API] = true } } })
	local e = z:Join(4)
	check(#z.SubAsks == 0 and e:GetAttribute("SubFastTravel") == false and z.Ms.SubscriptionApiId("FastTravel") == nil, "Id 0: never asked, off", "")
	-- a string id is used as it is
	local s = passWorld({ EditConfig = function(cfg) cfg.Subscriptions.FastTravel.Id = "EXP-42" end, Subs = { [5] = { ["EXP-42"] = true } } })
	local g = s:Join(5)
	check(g:GetAttribute("SubFastTravel") == true, "a string id EXP-42 is asked as it is", show(s.SubAsks))
	-- 최종 검수 10/14 ①: a failing ask is tried again; the last answer is saved and counts when every try fails
	local r = passWorld({ Subs = { [6] = { [API] = true } } })
	r.SubFailTimes = 1
	local h = r:Join(6)
	local asks = 0
	for _, x in r.SubAsks do if x.Id == API then asks += 1 end end
	check(h:GetAttribute("SubFastTravel") == true and r.Ms.HasSub(h, "FastTravel") == true and asks == 2,
		"the first ask fails, the second says yes: on", show({ asks, h:GetAttribute("SubFastTravel") }))
	check(r.Data[h].PassSeen["Sub:FastTravel"] == true, "Roblox's yes is saved (PassSeen Sub:FastTravel)", show(r.Data[h].PassSeen))
	r.SubFailTimes = 2
	local h2 = r:Join(7)
	check(h2:GetAttribute("SubFastTravel") == false and r.Data[h2].PassSeen["Sub:FastTravel"] == false, "two fails then a no: off, the no saved", show(r.Data[h2].PassSeen))
	local x = passWorld({ SubFail = true })
	local k = x:Join(8, { Data = { PassSeen = { ["Sub:FastTravel"] = true } } })
	local tries = 0
	for _, y in x.SubAsks do if y.Id == API then tries += 1 end end
	check(k:GetAttribute("SubFastTravel") == true and x.Ms.HasSub(k, "FastTravel") == true and tries == x.Config.PassBoost.CheckTries,
		"every try fails (3): the saved yes counts", show({ tries, k:GetAttribute("SubFastTravel") }))
	local k2 = x:Join(9, { Data = { PassSeen = { ["Sub:FastTravel"] = false } } })
	check(k2:GetAttribute("SubFastTravel") == false and not x.Ms.HasSub(k2, "FastTravel"), "every try fails, a saved no: off", "")
	local z2 = passWorld({ EditConfig = function(cfg) cfg.Subscriptions.FastTravel.Id = 0 end })
	local k3 = z2:Join(10, { Data = { PassSeen = { ["Sub:FastTravel"] = true } } })
	check(k3:GetAttribute("SubFastTravel") == false and not z2.Ms.HasSub(k3, "FastTravel"), "Id 0 (off): a saved yes never counts", "")
	local _, seen = x.Config.SanitizeLooks(nil, { ["Sub:FastTravel"] = true, ["Sub:Nope"] = true, Sub = true, ["Sub:"] = false })
	check(seen["Sub:FastTravel"] == true and seen["Sub:Nope"] == nil and seen.Sub == nil and seen["Sub:"] == nil,
		"the save keeps Sub:<a Config.Subscriptions key> only", show(seen))
end)

runGroup("A23-167 first minutes 2x XP", function()
	local E = C0.EarlyXP
	check(type(E) == "table" and E.Enabled == true and E.Seconds == 600 and E.Mult == 2,
		"Config.EarlyXP: on, the first 600 s of play (10 minutes, not 30), x2", show(E))
	local w = passWorld({ Ids = { XP2 = 11 }, Owns = { [602] = { [11] = true } } })
	local Prog = w.Prog
	local p = w:Join(601, { Level = 10, Data = { PlaytimeSeconds = 0, XP = 0 } })
	local d = w.Data[p]
	check(Prog.EarlyXPLeft(p) == 600 and Prog.XPBoost(p) == 2, "a new save: 600 s left, x2", show({ Prog.EarlyXPLeft(p), Prog.XPBoost(p) }))
	check(Prog.AddXP(p, 7) == 14 and d.XP == 14, "a new save: 7 XP -> 14 added and returned", show({ d.XP }))
	check(Prog.AddXP(p, 7.9) == 14, "the amount is floored before the boost (7 -> 14)")
	d.PlaytimeSeconds = 595
	check(Prog.EarlyXPLeft(p) == 5 and Prog.AddXP(p, 5) == 10, "595 s played: 5 s left, still x2", Prog.EarlyXPLeft(p))
	d.PlaytimeSeconds = 600
	check(Prog.EarlyXPLeft(p) == 0 and Prog.XPBoost(p) == 1 and Prog.AddXP(p, 5) == 5, "600 s played: over, x1",
		show({ Prog.EarlyXPLeft(p), Prog.XPBoost(p) }))
	d.PlaytimeSeconds = 99999
	check(Prog.EarlyXPLeft(p) == 0 and Prog.AddXP(p, 5) == 5, "an old save: never")
	-- the 2x XP pass in the first minutes: x2 once, never x4 (A23-167)
	local q = w:Join(602, { Level = 1, Data = { PlaytimeSeconds = 0, XP = 0 } })
	check(q:GetAttribute("PassXP2") == true and Prog.XPBoost(q) == 2 and Prog.AddXP(q, 5) == 10,
		"the 2x XP pass in the first minutes: x2 once (never x4)", show({ Prog.XPBoost(q) }))
	w.Data[q].PlaytimeSeconds = 5000
	check(Prog.AddXP(q, 5) == 10, "the pass after the first minutes: still x2")
	-- the cap comes after the boost: a grant capped at its own amount (choice cards, the bench) stays as it is
	local r = w:Join(603, { Level = 1, Data = { PlaytimeSeconds = 0, XP = 0 } })
	check(Prog.AddXP(r, 30, 30) == 30 and Prog.AddXP(r, 30, 45) == 45 and Prog.AddXP(r, 10, 45) == 20,
		"the cap holds after the boost (own-amount caps never doubled)")
	-- gold and the multipliers are untouched
	check(Prog.AddBankGold(r, 100, "Monster") == 100 and Prog.AddCarriedGold(r, 50, "Quest") == 50,
		"the first minutes double XP only (gold x1)")
	check(Prog.GetXPMult(r) == Prog.GetXPMult(p), "GetXPMult leaves the first minutes out (applied once, in the grant)",
		show({ Prog.GetXPMult(r), Prog.GetXPMult(p) }))
	-- a kill: the reward line shows the doubled XP that was added
	w.Reg.MonsterService.MonsterKilled:Fire(r, { Gold = 10, XP = 4, Kind = "Slime", Position = vec(1, 2, 3) })
	local fx = w.Fx[#w.Fx]
	check(fx and fx.Kind == "Reward" and fx.Data.XP == 8 and fx.Data.Gold == 10, "a kill in the first minutes: +8 XP shown, +10 gold",
		show(fx and fx.Data))
	-- the one-level cap of a kill (A23-27) holds
	local lv1 = w:Join(604, { Level = 1, Data = { PlaytimeSeconds = 0, XP = 0 } })
	w.Reg.MonsterService.MonsterKilled:Fire(lv1, { Gold = 0, XP = 100000, Kind = "PumpkinKing", Position = vec(0, 0, 0) })
	fx = w.Fx[#w.Fx]
	check(fx.Data.XP == math.floor(C0.XPToNext(1)), "a Lv1 king kill in the first minutes: still one level's XP", fx.Data.XP)
	-- the switch
	local w2 = passWorld({ EditConfig = function(c) c.EarlyXP.Enabled = false end })
	local s = w2:Join(605, { Level = 1, Data = { PlaytimeSeconds = 0, XP = 0 } })
	check(w2.Prog.EarlyXPLeft(s) == 0 and w2.Prog.AddXP(s, 5) == 5, "EarlyXP.Enabled = false: x1")
	-- a missing table (an old Config) is off, never an error
	local w3 = passWorld({ EditConfig = function(c) c.EarlyXP = nil end })
	local t = w3:Join(606, { Level = 1, Data = { PlaytimeSeconds = 0, XP = 0 } })
	check(w3.Prog.AddXP(t, 5) == 5, "no Config.EarlyXP: x1")
end)

finish()
