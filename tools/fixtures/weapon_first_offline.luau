-- weapon_first_offline.luau : A23-74 weapon first (tools/test_weapon_first.py). The world is
-- tools/fixtures/dev2_combat_world.luau (bareWorld: the real CombatService / LootService / StoryQuestService and the
-- ShopService extract with the anvil prompt); this file adds the real QuestService (its three loops stepped by hand), a
-- ZoneService travel double (Travel / MarkTeleported / ZoneChanged) and the Crossroads anvil part.
-- Rate limits are onboarding's (tools/test_onboarding.py): here Util.RateLimit always allows, so a remote call never has
-- to move the clocks (the trips' 3 s timers are stepped exactly with w:Advance).

local TC = C0.Tutorial
local STEP = TC.Steps
local ANVIL_POS = vec(39, 1.5, 45)

-- Model:PivotTo (the forge trip's landing): the root moves to the CFrame's position; the last pivot is kept
if not instMeta.Methods.PivotTo then
	instMeta.Methods.PivotTo = function(o, cf)
		o.Pivot = cf
		local root = o:FindFirstChild("HumanoidRootPart")
		if root and type(cf) == "table" and cf.Position then root.Position = cf.Position end
	end
end

local function forgeWorld()
	local w = bareWorld()
	local cfg, reg = w.Config, w.Registry
	local Signal = w.Util.Signal
	w.Util.RateLimit = function() return true end
	-- the zone each player stands in, the travel double (an instant Travel lands at the zone spawn, fires ZoneChanged)
	w.ZoneOf, w.Travels, w.Marked = {}, {}, {}
	reg.ZoneService.GetZoneId = function(p) return w.ZoneOf[p] or "HaloTown" end
	reg.ZoneService.ZoneChanged = Signal.new()
	reg.ZoneService.Travel = function(p, dest, instant)
		table.insert(w.Travels, { P = p, Dest = dest, Instant = instant })
		if w.TravelRefused then return false, "refused" end
		w.ZoneOf[p] = dest
		local root = w.Util.GetRoot(p)
		local at = cfg.Zones[dest].Spawn
		if root then root.Position = vec(at.X, 4, at.Z) end
		reg.ZoneService.ZoneChanged:Fire(p, dest)
		return true
	end
	reg.ZoneService.MarkTeleported = function(p) table.insert(w.Marked, p) end
	reg.GooseService.GooseFinished = Signal.new()
	reg.PvPService.PlayerKO = Signal.new()
	reg.KaijuService.KaijuEnded = Signal.new()
	-- the Crossroads anvil (ShopService.Anvil returns it while the weapon shop is open)
	local anvil = newInstance("BasePart", w)
	anvil.Name, anvil.Position, anvil.Size = "Anvil", ANVIL_POS, vec(4, 3, 2)
	w.AnvilPart = anvil
	reg.ShopService.Anvil = function()
		if w.ShopClosed then return nil end
		return anvil
	end
	-- the real QuestService; task.wait yields so its loops (publish, day, tutorial) are stepped by w:QuestTick
	local qenv = w:Env()
	qenv.task = setmetatable({ wait = function(t) return coroutine.yield(t) end }, { __index = qenv.task })
	qenv.CFrame = { lookAt = function(at, target) return { __kind = "CFrame", Position = at, Target = target } end }
	local quest = execute("QuestService", QUEST_SOURCE, qenv)
	reg.QuestService = quest
	quest.Init(reg)
	local n0 = #w.Spawned
	quest.Start()
	local loops = {}
	for i = n0 + 1, #w.Spawned do table.insert(loops, coroutine.create(w.Spawned[i][1])) end
	w.Spawned = {}
	assert(#loops == 3, "QuestService.Start spawns three loops")
	for _, co in loops do assert(coroutine.resume(co)) end -- each runs to its first task.wait
	w.Quest = quest
	function w:QuestTick()
		for _, co in loops do
			local ok, err = coroutine.resume(co)
			assert(ok, err)
		end
		self:Flush()
	end
	-- a player with the class chosen, bare-handed (the defaults) unless jo says otherwise, at step jo.Tutorial (0)
	function w:Newbie(id, jo)
		jo = jo or {}
		if jo.Tutorial == nil then jo.Tutorial = 0 end
		local zone, before = jo.Zone or "HaloTown", jo.BeforeReady
		jo.BeforeReady = function(p, d)
			self.ZoneOf[p] = zone
			if before then before(p, d) end
		end
		return self:Join(id, jo)
	end
	function w:Remote(p, name, ...)
		self.Remotes[name].OnServerEvent:Fire(p, ...)
		self:Flush()
	end
	function w:Accept(p) self:Remote(p, "AcceptTutorial") end
	function w:Request(p, ...) self:Remote(p, "RequestTutorial", ...) end
	function w:ClaimFirst(p) self:Remote(p, "ClaimQuest", TC.QuestId) end
	-- the anvil prompt (the real ShopService handler, no clock move)
	function w:Press(p)
		self.Shop.Prompt(self.Prompt, p)
		self:Flush()
	end
	-- the last quest list sent to p (after one pass of the loops)
	function w:Rows(p)
		self:QuestTick()
		for i = #self.Fired, 1, -1 do
			local f = self.Fired[i]
			if f.Remote == "Quests" and f.Player == p then return jsonDecode(f.Payload) end
		end
		return {}
	end
	function w:Panels(p, id, from)
		local n = 0
		for i = (from or 0) + 1, #self.Fired do
			local f = self.Fired[i]
			if f.Remote == "OpenPanel" and f.Player == p and f.Payload == id then n += 1 end
		end
		return n
	end
	function w:FxFor(p, kind, from)
		local out = {}
		for _, fx in self:FxOf(kind, from) do if fx.Player == p then table.insert(out, fx) end end
		return out
	end
	function w:Walk(p, zone) -- walk into a zone (no travel)
		self.ZoneOf[p] = zone
		self.Registry.ZoneService.ZoneChanged:Fire(p, zone)
		self:Flush()
	end
	return w
end

local function step(p) return p:GetAttribute("TutorialStep") end
local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end
local function rootOf(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function count(list, text)
	local n = 0
	for _, x in list do if x == text then n += 1 end end
	return n
end
-- LootService's first-weapon line ("You got your first weapon, [name]! Power 0 → N"): bare-handed, so from Power 0
local FIRST_HEAD = string.match(C0.Loot.Text.FirstWeapon, "^(.-)%[") -- "You got your first weapon, "
local function firstLines(list)
	local n = 0
	for _, x in list do
		if string.sub(x, 1, #FIRST_HEAD) == FIRST_HEAD and string.find(x, "Power 0 → ", 1, true) then n += 1 end
	end
	return n
end

------------------------------------------------------------------ 1. Config
runGroup("config", function()
	local C = C0
	local seen = {}
	for _, v in STEP do seen[v] = (seen[v] or 0) + 1 end
	check(STEP.Forge == 3 and seen[3] == 1 and STEP.Kill == 0 and STEP.Guide == 1 and STEP.Quest == 2 and STEP.Done == 99,
		"Steps.Forge = 3, its own value", show(STEP))
	local F = TC.Forge
	check(F.Landing == "Anvil" and F.Back == 8 and F.Lift == 4 and F.Near == 24 and F.TravelDelay == 3,
		"Forge: lands 8 studs in front of the anvil, 4 up; no trip within 24; the meadow trip 3 s after the gift", show(F))
	check(F.Back < 12, "the landing is inside the anvil prompt's reach (12 studs): the prompt is up at once", F.Back)
	for _, side in { "Halo", "Horns", "Neutral" } do
		local line = TC.Welcome[side].Lines[1]
		check(string.find(line, "First, get a weapon", 1, true) == 1 and string.find(line, "5 slimes", 1, true) ~= nil
			and not string.find(line, "fists", 1, true), side .. ": page 1 = the weapon first, then 5 slimes", line)
	end
	check(TC.Text.Forge == "Get your first weapon · Crossroads Forge" and TC.ShortNames.Forge == "To the Forge"
		and #TC.ShortNames.Forge <= 14, "the Forge row: text + phone ShortName", show({ TC.Text.Forge, TC.ShortNames.Forge }))
	check(string.sub(TC.Text.ForgeGift, 1, 6) == "Otto: " and string.find(TC.Text.ForgeGift, "Clang, clang", 1, true) ~= nil,
		"Otto hands it over in his own voice (his catchphrase)", TC.Text.ForgeGift)
	-- the 150 gold: the next weapon (tier 2, Lv1) now that the first one is in hand
	check(TC.QuestRewardGold == 150 and C.Weapons[2].Price == TC.QuestRewardGold and C.Weapons[2].MinLevel == 1,
		"the first mission's 150 gold = the tier-2 price, usable at Lv1", show({ TC.QuestRewardGold, C.Weapons[2].Price }))
	check(string.find(TC.Text.Claimed, "new weapon", 1, true) ~= nil and string.find(TC.Text.AutoClaimed, "new weapon", 1, true) ~= nil
		and string.find(TC.Text.Claimed, "first weapon", 1, true) == nil, "the claim lines point to the next weapon",
		show({ TC.Text.Claimed, TC.Text.AutoClaimed }))
	local M11 = C.StoryQuests.Defs.M1_1
	check(M11.GiveWeapon == 1 and M11.Reward and M11.Reward.Gold == 1 and M11.Steps[1].Obj.Key == "BlacksmithVisited",
		"M1_1: the visit with the jelly, Gold 1, the gift kept as the safety net", show({ M11.GiveWeapon, M11.Reward }))
	local order = {}
	for i, name in C.Analytics.Steps do order[name] = i end
	check(order.FirstMissionAccept < order.ForgeArrive and order.ForgeArrive < order.FirstWeapon
		and order.FirstWeapon < order.MeadowArrive and order.MeadowArrive < order.FirstKill,
		"the funnel: accept -> Forge -> first weapon -> meadow -> first kill", show(C.Analytics.Steps))
end)

------------------------------------------------------------------ 2. the whole first 3 minutes
runGroup("weapon first", function()
	local w = forgeWorld()
	local T = w.Config.Tutorial
	local p, d = w:Newbie(1)
	check(step(p) == 0 and d.WeaponTier == 0 and d.WeaponOwnedMask == 0 and w:Panels(p, "Welcome") == 1,
		"a new player: bare-handed at the welcome (the guide opens)", show({ step(p), d.WeaponTier }))
	local t0, fx0, n0 = w.Time, #w.Fx, #w.Notices
	w:Accept(p)
	local trip = w:FxFor(p, "Travel", fx0)
	check(step(p) == T.Steps.Forge and d.TutorialStep == 3, "[Accept] bare-handed -> the Forge step (3)", step(p))
	check(#trip == 1 and trip[1].Data.To == "Crossroads" and trip[1].Data.Spot == "Forge" and trip[1].Data.T == 3
		and trip[1].Data.UserId == p.UserId, "the forge trip: Fx Travel { UserId, To = Crossroads, Spot = Forge, T = 3 }",
		show(trip[1] and trip[1].Data))
	check(p:GetAttribute("MoveLockUntil") == t0 + 4.5 and #w.Travels == 0, "the fade's lock (now + 4.5), nobody moved yet",
		p:GetAttribute("MoveLockUntil"))
	local rows = w:Rows(p)
	local row = rows[1] or {}
	check(row.Id == "tutorial" and row.Pinned == true and row.TutorialStep == 3 and row.Text == T.Text.Forge
		and row.ShortName == T.ShortNames.Forge and row.CanClaim == false and row.ShowProgress == false,
		"the pinned Forge row (not claimable, no counter)", show(row))
	local folded = 0
	for i = 2, #rows do if rows[i].Folded == true then folded += 1 end end
	check(#rows > 1 and folded == #rows - 1, "every other row stays folded until the first claim", show(#rows))
	-- the trip: 3 s, then the Crossroads, then in front of the anvil
	w:Advance(2.9)
	check(#w.Travels == 0, "nobody moves before T", #w.Travels)
	w:Advance(0.1)
	check(#w.Travels == 1 and w.Travels[1].Dest == "Crossroads" and w.Travels[1].Instant == true and w.ZoneOf[p] == "Crossroads",
		"T s later: an instant Travel to the Crossroads", show(w.Travels[1] and { w.Travels[1].Dest, w.Travels[1].Instant }))
	local root = rootOf(p)
	local pivot = p.Character.Pivot
	check(pivot ~= nil and math.abs(flat(root.Position, ANVIL_POS) - 8) < 1e-6 and math.abs(root.Position.Y - 4) < 1e-6,
		"then 8 studs in front of the anvil, 4 above its bottom", show(root.Position))
	local spawn = w.Config.Zones.Crossroads.Spawn
	check(flat(root.Position, spawn) < flat(ANVIL_POS, spawn), "on the anvil's Crossroads-spawn side (the way players come)",
		show(root.Position))
	check(pivot and pivot.Target and pivot.Target.X == ANVIL_POS.X and pivot.Target.Z == ANVIL_POS.Z and pivot.Target.Y == root.Position.Y,
		"facing the anvil (level)", show(pivot and pivot.Target))
	check(#w.Marked == 1 and w.Marked[1] == p, "the jump is a server teleport (MarkTeleported)", #w.Marked)
	local done = w:FxFor(p, "TravelDone", fx0)
	check(#done == 1 and p:GetAttribute("MoveLockUntil") == 0, "TravelDone and the lock lifted", #done)
	-- the meadow before the Forge: nothing counts
	w:Walk(p, "SlimeMeadow")
	w:Drop(p, "Slime")
	check(step(p) == 3 and d.TutorialKills == 0, "a meadow kill before the weapon counts nothing (still the Forge step)",
		show({ step(p), d.TutorialKills }))
	w:Walk(p, "Crossroads")
	-- the anvil prompt: Otto's line, the first weapon in hand, no shop window, the mission goes on
	local n1, f1 = #w.Notices, #w.Fired
	w:Press(p)
	local said = w:NoticesFor(p, n1)
	check(d.WeaponTier == 1 and d.WeaponOwnedMask == 1 and d.BlacksmithVisited == true, "the gift: tier 1 owned and equipped, the visit counted",
		show({ d.WeaponTier, d.WeaponOwnedMask, d.BlacksmithVisited }))
	check(#said == 2 and said[1] == T.Text.ForgeGift and firstLines({ said[2] }) == 1
		and string.find(said[2], w.Config.WeaponName(1, "Warrior", "Halo"), 1, true) ~= nil,
		"Otto's line, then 'You got your first weapon, [Twig]! Power 0 → N'", show(said))
	check(w:Panels(p, "WeaponShop", f1) == 0, "no weapon window at the gift (the Stronger! moment)", w:Panels(p, "WeaponShop", f1))
	check(step(p) == T.Steps.Guide, "the mission goes on: step 1", step(p))
	-- Forge.TravelDelay later the usual meadow trip
	local fx1 = #w.Fx
	w:Advance(2.9)
	check(#w:FxFor(p, "Travel", fx1) == 0, "no meadow trip before Forge.TravelDelay", #w:FxFor(p, "Travel", fx1))
	w:Advance(0.1)
	local meadow = w:FxFor(p, "Travel", fx1)
	check(#meadow == 1 and meadow[1].Data.To == "SlimeMeadow" and meadow[1].Data.Spot == nil and meadow[1].Data.T == 3,
		"then the meadow trip (Fx Travel To = SlimeMeadow)", show(meadow[1] and meadow[1].Data))
	w:Advance(3)
	check(w.ZoneOf[p] == "SlimeMeadow" and step(p) == T.Steps.Quest and p:GetAttribute("MoveLockUntil") == 0,
		"arrived: the hunt (step 2)", show({ w.ZoneOf[p], step(p) }))
	for _ = 1, 5 do w:Drop(p, "Slime") end
	check(d.TutorialKills == 5, "5 slimes with the weapon", d.TutorialKills)
	-- the claim: 150 gold, the visit cleared, the next-weapon line
	local n2 = #w.Notices
	w:ClaimFirst(p)
	check(step(p) == 99 and d.BankGold == 150 and d.BlacksmithVisited == false, "the claim: 150 gold, the forge visit cleared",
		show({ step(p), d.BankGold, d.BlacksmithVisited }))
	check(count(w:NoticesFor(p, n2), string.format(T.Text.Claimed, "150")) == 1, "the claim line: 150 buys a new weapon",
		show(w:NoticesFor(p, n2)))
	-- M1_1: the jelly to Otto (a new visit), his lines, then the shop where the 150 gold buy tier 2
	w.Story.Refresh(p)
	local st = d.Story
	check(st.Main.Id == "M1_1" and not st.Done.M1_1, "M1_1 waits for a new visit (the first one was before the claim)", show(st.Main))
	local n3, f3 = #w.Notices, #w.Fired
	w:Press(p)
	check(st.Done.M1_1 == true and w:Panels(p, "WeaponShop", f3) == 1, "the visit finishes M1_1, then the shop opens",
		show({ st.Done.M1_1, w:Panels(p, "WeaponShop", f3) }))
	local lines = w:NoticesFor(p, n3)
	check(lines[1] == w.Config.StoryQuests.Defs.M1_1.Finish and d.WeaponTier == 1 and d.WeaponOwnedMask == 1,
		"Otto's jelly lines; no second weapon (the gift is only the safety net)", show(lines))
	check(d.BankGold > 150, "M1_1 pays a little gold (Reward Gold 1)", d.BankGold)
	w:Buy(p, 2)
	check(d.WeaponTier == 2 and d.WeaponOwnedMask == 3, "the 150 gold buy the tier-2 weapon right there", show({ d.WeaponTier, d.WeaponOwnedMask }))
end)

------------------------------------------------------------------ 3. the forge trip: where, when, and when not
runGroup("forge trip", function()
	-- Landing "Spawn": the Crossroads spawn only (no pivot, no teleport mark)
	local w = forgeWorld()
	w.Config.Tutorial.Forge.Landing = "Spawn"
	local p = w:Newbie(1)
	w:Accept(p)
	w:Advance(3)
	local spawn = w.Config.Zones.Crossroads.Spawn
	check(w.ZoneOf[p] == "Crossroads" and p.Character.Pivot == nil and #w.Marked == 0
		and flat(rootOf(p).Position, spawn) < 1e-6, "Landing 'Spawn': the Crossroads spawn only", show(rootOf(p).Position))
	-- the shop closed (no anvil): the same
	local w2 = forgeWorld()
	w2.ShopClosed = true
	local p2 = w2:Newbie(2)
	w2:Accept(p2)
	w2:Advance(3)
	check(w2.ZoneOf[p2] == "Crossroads" and p2.Character.Pivot == nil, "no anvil: the Crossroads spawn only", show(rootOf(p2).Position))
	-- already next to the anvil: no trip, no fade, no lock
	local w3 = forgeWorld()
	local p3 = w3:Newbie(3, { Pos = vec(39, 3, 30) })
	local fx3 = #w3.Fx
	w3:Accept(p3)
	check(step(p3) == 3 and #w3:FxFor(p3, "Travel", fx3) == 0 and p3:GetAttribute("MoveLockUntil") == nil,
		"15 studs from the anvil: the Forge step without a trip", show({ step(p3), p3:GetAttribute("MoveLockUntil") }))
	w3:Advance(3)
	check(#w3.Travels == 0, "nothing moves later either", #w3.Travels)
	-- a new character before the move (a KO): nobody is moved, the fade still ends
	local w4 = forgeWorld()
	local p4 = w4:Newbie(4)
	local fx4 = #w4.Fx
	w4:Accept(p4)
	w4:Body(p4)
	w4:Advance(3)
	check(#w4.Travels == 0 and #w4:FxFor(p4, "TravelDone", fx4) == 1 and p4:GetAttribute("MoveLockUntil") == 0,
		"a respawned character is not moved; TravelDone, the lock lifted", #w4.Travels)
	-- the zone rules refuse the trip: no landing at the anvil, still the Forge step
	local w5 = forgeWorld()
	w5.TravelRefused = true
	local p5 = w5:Newbie(5)
	w5:Accept(p5)
	w5:Advance(3)
	check(#w5.Travels == 1 and w5.ZoneOf[p5] == "HaloTown" and p5.Character.Pivot == nil and step(p5) == 3,
		"a refused Travel: no jump to the anvil, still the Forge step (the beam leads)", show({ #w5.Travels, w5.ZoneOf[p5] }))
	-- the step moved on before the move (e.g. the gift happened): nobody moves
	local w6 = forgeWorld()
	w6.Config.Tutorial.Forge.TravelDelay = nil
	local p6 = w6:Newbie(6)
	w6:Accept(p6)
	check(w6.Quest.ForgeGift(p6) == true and step(p6) == 1, "the gift before the trip ended", step(p6))
	w6:Advance(3)
	check(#w6.Travels == 0, "a trip for a step that moved on moves nobody", #w6.Travels)
	check(#w6:FxFor(p6, "Travel") == 1, "TravelDelay nil: no automatic meadow trip after the gift", #w6:FxFor(p6, "Travel"))
	-- the row's tap (RequestTutorial) at the Forge step: the trip again, never twice at once, never next to the anvil
	local w7 = forgeWorld()
	local p7 = w7:Newbie(7)
	w7:Accept(p7)
	w7:Advance(3)
	-- a rejoin-like state: back home, far away
	w7.ZoneOf[p7] = "HaloTown"
	rootOf(p7).Position = vec(0, 4, -410)
	local fx7 = #w7.Fx
	w7:Request(p7)
	w7:Request(p7)
	check(#w7:FxFor(p7, "Travel", fx7) == 1, "a tap: one forge trip (a second tap during the fade does nothing)",
		#w7:FxFor(p7, "Travel", fx7))
	w7:Request(p7, "extra")
	check(#w7:FxFor(p7, "Travel", fx7) == 1, "a tap with arguments does nothing", #w7:FxFor(p7, "Travel", fx7))
	w7:Advance(3)
	check(w7.ZoneOf[p7] == "Crossroads" and math.abs(flat(rootOf(p7).Position, ANVIL_POS) - 8) < 1e-6,
		"the tap's trip lands at the anvil too", show(rootOf(p7).Position))
	local fx8 = #w7.Fx
	w7:Request(p7)
	check(#w7:FxFor(p7, "Travel", fx8) == 0 and w7:Panels(p7, "Welcome") == 1, "at the anvil a tap does nothing (no trip, no welcome)",
		#w7:FxFor(p7, "Travel", fx8))
	-- at another step the tap is the old one (step 1: nothing; step 0: the welcome)
	local w8 = forgeWorld()
	local p8 = w8:Newbie(8, { Tutorial = 1, Tier = 1, Mask = 1 })
	local fx9 = #w8.Fx
	w8:Request(p8)
	check(#w8:FxFor(p8, "Travel", fx9) == 0 and w8:Panels(p8, "Welcome") == 0, "step 1: a tap asks for nothing", step(p8))
end)

------------------------------------------------------------------ 4. the gift: only at the Forge step
runGroup("gift", function()
	local w = forgeWorld()
	local T = w.Config.Tutorial
	-- a save that owns the first weapon (from before A23-34): [Accept] -> step 1 + the meadow trip, as before
	local old, od = w:Newbie(1, { Tier = 1, Mask = 1 })
	local fx0 = #w.Fx
	w:Accept(old)
	local trip = w:FxFor(old, "Travel", fx0)
	check(step(old) == T.Steps.Guide and #trip == 1 and trip[1].Data.To == "SlimeMeadow", "owns tier 1: [Accept] -> the meadow trip (step 1)",
		show({ step(old), trip[1] and trip[1].Data }))
	-- the anvil at the welcome step / after the first mission: the usual shop, no gift, the step kept
	local p0, d0 = w:Newbie(2)
	local f0 = #w.Fired
	w:Press(p0)
	check(step(p0) == 0 and d0.WeaponTier == 0 and w:Panels(p0, "WeaponShop", f0) == 1,
		"the anvil before [Accept]: the shop window, no gift (the welcome step stays)", show({ step(p0), d0.WeaponTier }))
	local p9, d9 = w:Newbie(3, { Tutorial = 99, Tier = 1, Mask = 1 })
	local f9 = #w.Fired
	w:Press(p9)
	check(step(p9) == 99 and w:Panels(p9, "WeaponShop", f9) == 1 and d9.WeaponOwnedMask == 1,
		"the anvil after the first mission: the shop, the step kept", show({ step(p9), d9.WeaponOwnedMask }))
	check(w.Quest.ForgeGift(p9) == false and w.Quest.ForgeGift({}) == false, "ForgeGift is false off the Forge step / for a non-player", "")
	-- a Forge-step save without a class (a broken record): no gift, the shop as usual
	local pc, dc = w:Newbie(4, { Tutorial = 3, Data = { ClassChosen = false } })
	local fc = #w.Fired
	w:Press(pc)
	check(dc.WeaponTier == 0 and dc.WeaponOwnedMask == 0 and step(pc) == 3 and w:Panels(pc, "WeaponShop", fc) == 1,
		"no class chosen: no gift", show({ dc.WeaponTier, step(pc) }))
	-- the hunt began before Forge.TravelDelay (walked into the meadow): no meadow trip
	local w2 = forgeWorld()
	local p2 = w2:Newbie(5, { Pos = vec(39, 3, 37) })
	w2:Accept(p2)
	w2:Press(p2)
	local fx2 = #w2.Fx
	w2:Walk(p2, "SlimeMeadow")
	check(step(p2) == 2, "walking in after the gift starts the hunt", step(p2))
	w2:Advance(3)
	check(#w2:FxFor(p2, "Travel", fx2) == 0, "then no meadow trip", #w2:FxFor(p2, "Travel", fx2))
	-- a trip already running when the delay ends: no second one
	local w3 = forgeWorld()
	local p3 = w3:Newbie(6, { Pos = vec(39, 3, 37) })
	w3:Accept(p3)
	w3:Press(p3)
	w3:Advance(1)
	p3:SetAttribute("MoveLockUntil", w3.Time + 10)
	local fx3 = #w3.Fx
	w3:Advance(2)
	check(#w3:FxFor(p3, "Travel", fx3) == 0, "a running trip (lock ahead): no meadow trip on top", #w3:FxFor(p3, "Travel", fx3))
	-- a player who left before the delay: nothing
	local w4 = forgeWorld()
	local p4 = w4:Newbie(7, { Pos = vec(39, 3, 37) })
	w4:Accept(p4)
	w4:Press(p4)
	w4:Remove(p4)
	local fx4 = #w4.Fx
	w4:Advance(3)
	check(#w4:FxFor(p4, "Travel", fx4) == 0, "left before the delay: no trip", #w4:FxFor(p4, "Travel", fx4))
	-- the gift once: a second press at step 1 opens the shop, gives nothing more
	local w5 = forgeWorld()
	local p5, d5 = w5:Newbie(8, { Pos = vec(39, 3, 37) })
	w5:Accept(p5)
	w5:Press(p5)
	local n5, f5 = #w5.Notices, #w5.Fired
	w5:Press(p5)
	local again = w5:NoticesFor(p5, n5)
	check(step(p5) == 1 and d5.WeaponOwnedMask == 1 and count(again, w5.Config.Tutorial.Text.ForgeGift) == 0
		and firstLines(again) == 0 and w5:Panels(p5, "WeaponShop", f5) == 1,
		"a second press: the shop, no second gift", show({ step(p5), again }))
end)

------------------------------------------------------------------ 5. old saves: never left bare-handed
runGroup("old saves", function()
	local w = forgeWorld()
	for i, s in { 1, 2, 99 } do
		local p, d = w:Newbie(10 + i, { Tutorial = s, Zone = s == 2 and "SlimeMeadow" or "HaloTown" })
		check(d.WeaponTier == 1 and d.WeaponOwnedMask == 1 and step(p) == s, "step " .. s .. " bare-handed: the gift at the join",
			show({ d.WeaponTier, d.WeaponOwnedMask, step(p) }))
		check(firstLines(w:NoticesFor(p)) == 1, "step " .. s .. ": 'You got your first weapon' once", show(w:NoticesFor(p)))
		w:QuestTick()
		w:QuestTick()
		check(firstLines(w:NoticesFor(p)) == 1, "step " .. s .. ": never twice", show(w:NoticesFor(p)))
	end
	for i, s in { 0, 3 } do
		local p, d = w:Newbie(20 + i, { Tutorial = s })
		w:QuestTick()
		check(d.WeaponTier == 0 and d.WeaponOwnedMask == 0, "step " .. s .. ": no gift at the join (the Forge gives it)",
			show({ d.WeaponTier, step(p) }))
	end
	local pa, da = w:Newbie(30, { Tutorial = 99, Tier = 2, Mask = 2 })
	w:QuestTick()
	check(da.WeaponOwnedMask == 2 and da.WeaponTier == 2, "armed with tier 2 (no tier 1): nothing at the join (M1_1 gives it later)",
		show({ da.WeaponTier, da.WeaponOwnedMask }))
	local pn, dn = w:Newbie(31, { Tutorial = 99, Data = { ClassChosen = false } })
	w:QuestTick()
	check(dn.WeaponOwnedMask == 0, "no class chosen: nothing", dn.WeaponOwnedMask)
	-- a failing grant is tried once a session, not every second
	local w2 = forgeWorld()
	w2.AllowWarn = "late first weapon"
	local calls = 0
	local pf = w2:Newbie(40, { Tutorial = 99, BeforeReady = function()
		w2.Loot.GrantFirstWeapon = function()
			calls += 1
			error("offline: the grant failed")
		end
	end })
	for _ = 1, 3 do w2:QuestTick() end
	check(calls == 1, "a failed late gift is tried once a session", calls)
	local warned = 0
	for _, text in w2.Warnings do if string.find(text, "late first weapon", 1, true) then warned += 1 end end
	check(warned == 1 and pf.Parent ~= nil, "and warned once", warned)
end)

------------------------------------------------------------------ 6. the claim: the visit cleared, the right line
runGroup("claim", function()
	local w = forgeWorld()
	local T = w.Config.Tutorial
	local cases = {
		{ Id = 1, Tier = 1, Mask = 1, Line = T.Text.Claimed, Name = "tier 1 only: 150 buys a new weapon" },
		{ Id = 2, Tier = 2, Mask = 3, Line = T.Text.ClaimedArmed, Name = "tier 2 owned: 'check the gear'" },
		{ Id = 3, Tier = 8, Mask = 129, Line = T.Text.ClaimedArmed, Name = "the jackpot owned: 'check the gear'" },
	}
	for _, c in cases do
		local p, d = w:Newbie(c.Id, { Tutorial = 2, Tier = c.Tier, Mask = c.Mask, Zone = "SlimeMeadow",
			Data = { TutorialKills = 5, BlacksmithVisited = true } })
		local n = #w.Notices
		w:ClaimFirst(p)
		check(step(p) == 99 and d.BlacksmithVisited == false and count(w:NoticesFor(p, n), string.format(c.Line, "150")) == 1,
			c.Name .. " (the visit cleared)", show(w:NoticesFor(p, n)))
	end
	-- the F10-4 safety net pays with the next-weapon line too
	local p, d = w:Newbie(9, { Tutorial = 2, Tier = 1, Mask = 1, Zone = "SlimeMeadow", Data = { TutorialKills = 5 } })
	local n = #w.Notices
	w:QuestTick()
	w:Advance(T.AutoClaimSeconds + 1)
	w:QuestTick()
	check(step(p) == 99 and d.BankGold == 150 and count(w:NoticesFor(p, n), string.format(T.Text.AutoClaimed, "150")) == 1,
		"the auto claim: AutoClaimed (next weapon)", show(w:NoticesFor(p, n)))
end)

------------------------------------------------------------------ 7. the save keeps the Forge step
runGroup("save", function()
	local w = newWorld({ Time = 1791342000 })
	local migrate, fill = execute("DataService.extract", DATA_EXTRACT, w:Env(), w.Config, w.Util)
	local function load(stepValue)
		local d = { Version = 3, Level = 1, Faction = "Halo", Class = "Warrior", ClassChosen = true, TutorialStep = stepValue,
			WeaponTier = 0, WeaponOwnedMask = 0 }
		migrate(d, { Name = "P1" })
		fill(d, "P1")
		return d.TutorialStep
	end
	for _, case in { { 3, 3 }, { 0, 0 }, { 1, 1 }, { 2, 2 }, { 99, 99 }, { 4, 99 }, { -1, 99 } } do
		check(load(case[1]) == case[2], "TutorialStep " .. case[1] .. " loads as " .. case[2], load(case[1]))
	end
end)

finish()
