-- weapon_first_offline.luau : A23-74 weapon first (tools/test_weapon_first.py). The world is
-- tools/fixtures/dev2_combat_world.luau (bareWorld: the real CombatService / LootService / StoryQuestService and the
-- ShopService extract with the anvil prompt); this file adds the real QuestService (its three loops stepped by hand), a
-- ZoneService travel double (Travel / MarkTeleported / ZoneChanged) and the Crossroads anvil part.
-- Rate limits are onboarding's (tools/test_onboarding.py): here Util.RateLimit always allows, so a remote call never has
-- to move the clocks. A23-88 (user 2026-10-09): nothing moves the player by itself - [I'm In!] starts "Go to Otto's
-- Forge" (walking), the gift starts "Travel to the Squishy Meadow" (pad or map), and the walker's arrival is a metric.

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
	cfg.Daily.IntroGate = false -- A23-104 (the daily jobs open after an intro quest) has its own tests: test_a23_14 / test_town_quests
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
			if f.Remote == "Quests" and f.Player == p then
				-- A23-81: the payload is { Quests = rows, Book } (an older server sent the JSON of the rows)
				if type(f.Payload) == "table" then return f.Payload.Quests end
				return jsonDecode(f.Payload)
			end
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
	check(F.Near == 24 and F.Landing == nil and F.Back == nil and F.Lift == nil and F.TravelDelay == nil and TC.AcceptTravelSeconds == nil,
		"A23-88: Forge = { Near = 24 } only; no landing, no trip delay, no accept trip", show(F))
	for _, side in { "Halo", "Horns", "Neutral" } do
		local line = TC.Welcome[side].Lines[1]
		check(string.find(line, "First, get a weapon", 1, true) == 1 and string.find(line, "5 slimes", 1, true) ~= nil
			and not string.find(line, "fists", 1, true), side .. ": page 1 = the weapon first, then 5 slimes", line)
	end
	check(TC.Text.Forge == "Go to Otto's Forge in the Crossroads" and TC.ShortNames.Forge == "To the Forge" and #TC.ShortNames.Forge <= 14,
		"the Forge row: text + phone ShortName", show({ TC.Text.Forge, TC.ShortNames.Forge }))
	check(TC.Text.Travel == "Travel to Squishy Meadow — step on the glowing travel pad (or Map → Travel)" and TC.ShortNames.Travel == "To the meadow"
		and #TC.ShortNames.Travel <= 14, "the travel row (A23-88): the pad or the map, phone ShortName", show({ TC.Text.Travel, TC.ShortNames.Travel }))
	check(string.find(TC.Text.ForgeGift, "Squishy Meadow is next", 1, true) ~= nil, "Otto points to the meadow", TC.Text.ForgeGift)
	check(string.sub(TC.Text.ForgeGift, 1, 6) == "Otto: " and string.find(TC.Text.ForgeGift, "Clang, clang", 1, true) ~= nil,
		"Otto hands it over in his own voice (his catchphrase)", TC.Text.ForgeGift)
	-- the 150 gold: the next weapon (tier 2, Lv1) now that the first one is in hand
	check(TC.QuestRewardGold == 150 and C.Weapons[2].Price == TC.QuestRewardGold and C.Weapons[2].MinLevel == 1,
		"the first mission's 150 gold = the tier-2 price, usable at Lv1", show({ TC.QuestRewardGold, C.Weapons[2].Price }))
	check(TC.Text.Claimed == "+%s gold" and TC.Text.AutoClaimed == nil and TC.Text.ClaimedArmed == nil,
		"A23-130: one claim line, the reward only", show({ TC.Text.Claimed, TC.Text.AutoClaimed }))
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
	local arrivals = {}
	w.Quest.ForgeReached:Connect(function(player, seconds) table.insert(arrivals, seconds) end)
	w:Accept(p)
	check(step(p) == T.Steps.Forge and d.TutorialStep == 3, "[Accept] bare-handed -> the Forge step (3)", step(p))
	check(#w:FxFor(p, "Travel", fx0) == 0 and #w:FxFor(p, "TravelDone", fx0) == 0 and p:GetAttribute("MoveLockUntil") == nil and #w.Travels == 0,
		"A23-88: no automatic trip - no Fx Travel, no lock, nobody moved", show({ #w:FxFor(p, "Travel", fx0), #w.Travels }))
	local rows = w:Rows(p)
	local row = rows[1] or {}
	check(row.Id == "tutorial" and row.Pinned == true and row.TutorialStep == 3 and row.Text == T.Text.Forge
		and row.ShortName == T.ShortNames.Forge and row.CanClaim == false and row.ShowProgress == false,
		"the pinned Forge row (not claimable, no counter)", show(row))
	local folded = 0
	for i = 2, #rows do if rows[i].Folded == true then folded += 1 end end
	check(#rows > 1 and folded == #rows - 1, "every other row stays folded until the first claim", show(#rows))
	-- time passes, nothing moves the player; the walker arrives at the anvil on foot
	w:Advance(30)
	w:QuestTick()
	check(#w.Travels == 0 and w.ZoneOf[p] == "HaloTown" and #arrivals == 0, "30 s later: still where they stand, no arrival yet", show({ #w.Travels, #arrivals }))
	w:Walk(p, "Crossroads")
	rootOf(p).Position = vec(39, 3, 37) -- 8 studs from the anvil (inside Forge.Near)
	w:Advance(5)
	w:QuestTick()
	check(#arrivals == 1 and math.abs(arrivals[1] - 35) < 1.5, "the walker arrives: ForgeReached once, about 35 s after [I'm In!]", show(arrivals))
	w:QuestTick()
	w:QuestTick()
	check(#arrivals == 1, "and only once", #arrivals)
	-- the meadow before the Forge: nothing counts
	w:Walk(p, "SlimeMeadow")
	w:Drop(p, "Slime")
	check(step(p) == 3 and d.TutorialKills == 0, "a meadow kill before the weapon counts nothing (still the Forge step)",
		show({ step(p), d.TutorialKills }))
	w:Walk(p, "Crossroads")
	rootOf(p).Position = vec(39, 3, 37)
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
	-- A23-88: "Travel to the Squishy Meadow": nothing moves the player; the pad / the map / a walk end the step
	local fx1 = #w.Fx
	w:Advance(10)
	check(#w:FxFor(p, "Travel", fx1) == 0 and #w.Travels == 0 and step(p) == T.Steps.Guide, "10 s after the gift: no automatic trip, still step 1",
		show({ #w:FxFor(p, "Travel", fx1), #w.Travels, step(p) }))
	local grow = (w:Rows(p) or {})[1] or {}
	check(grow.Text == T.Text.Travel and grow.ShortName == T.ShortNames.Travel and grow.TutorialStep == 1 and grow.CanClaim == false,
		"the step-1 row teaches the pad / the map", show(grow))
	-- the player's own travel (the pad and Map -> Travel both call ZoneService.Travel) lands in the meadow: the hunt
	local nHunt = #w.Notices
	w.Registry.ZoneService.Travel(p, "SlimeMeadow", false)
	w:Flush()
	check(w.ZoneOf[p] == "SlimeMeadow" and step(p) == T.Steps.Quest, "the travel pad / the map: the hunt (step 2)", show({ w.ZoneOf[p], step(p) }))
	-- A23-130 (user 2026-10-11 "삭제해 달랬는데 아직 있네"): the hunt starts without a line, 5/5 too; the row keeps the mission
	check(#w:NoticesFor(p, nHunt) == 0, "A23-130: no 'First mission: ...' line when the hunt starts", show(w:NoticesFor(p, nHunt)))
	for _ = 1, 4 do w:Drop(p, "Slime") end
	w:Flush()
	local row4 = ((w:Rows(p) or {})[1] or {}).Text
	local nReady = #w.Notices
	w:Drop(p, "Slime")
	w:Flush()
	check(d.TutorialKills == 5, "5 slimes with the weapon", d.TutorialKills)
	check(#w:NoticesFor(p, nReady) == 0, "A23-130: no 'Press [Claim]' line at 5/5", show(w:NoticesFor(p, nReady)))
	local row5 = (w:Rows(p) or {})[1] or {}
	check(type(row4) == "string" and row5.Text == row4 and row5.CanClaim == true and row5.Progress == 5
		and not string.find(row5.Text, "Claim", 1, true), "A23-130: at 5/5 the row keeps the mission line (its [Claim] shows it)",
		show({ row4, row5.Text, row5.Progress }))
	-- the claim: 150 gold, the visit cleared, the next-weapon line
	local n2 = #w.Notices
	w:ClaimFirst(p)
	check(step(p) == 99 and d.BankGold == 150 and d.BlacksmithVisited == false, "the claim: 150 gold, the forge visit cleared",
		show({ step(p), d.BankGold, d.BlacksmithVisited }))
	check(count(w:NoticesFor(p, n2), string.format(T.Text.Claimed, "150")) == 1, "the claim line: +150 gold (A23-130)",
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

------------------------------------------------------------------ 3. the forge walk (A23-88): nothing moves, the arrival is a metric
runGroup("forge walk", function()
	-- a bare-handed player waits at the Forge step wherever they stand; nothing moves them, even much later
	local w = forgeWorld()
	local p = w:Newbie(1)
	local fx = #w.Fx
	local seen = {}
	w.Quest.ForgeReached:Connect(function(player, seconds) table.insert(seen, seconds) end)
	w:Accept(p)
	w:Advance(120)
	w:QuestTick()
	check(step(p) == 3 and #w.Travels == 0 and #w:FxFor(p, "Travel", fx) == 0 and p.Character.Pivot == nil and #w.Marked == 0 and #seen == 0,
		"2 minutes at home: still the Forge step, nobody moved, no arrival", show({ step(p), #w.Travels, #seen }))
	-- already next to the anvil at [Accept]: the arrival is counted at once (0 s), once
	local w3 = forgeWorld()
	local p3 = w3:Newbie(3, { Pos = vec(39, 3, 30) })
	local seen3 = {}
	w3.Quest.ForgeReached:Connect(function(player, seconds) table.insert(seen3, seconds) end)
	local fx3 = #w3.Fx
	w3:Accept(p3)
	w3:QuestTick()
	check(step(p3) == 3 and #w3:FxFor(p3, "Travel", fx3) == 0 and #seen3 == 1 and seen3[1] < 1, "15 studs from the anvil: the Forge step, the arrival counted (0 s)",
		show({ step(p3), seen3 }))
	w3:QuestTick()
	check(#seen3 == 1 and #w3.Travels == 0, "once; nothing moves later either", show({ #seen3, #w3.Travels }))
	-- a save waiting at the Forge step (an old one, or a rejoin): no walk began this session, so no arrival metric
	local w4 = forgeWorld()
	local seen4 = {}
	w4.Quest.ForgeReached:Connect(function(player, seconds) table.insert(seen4, seconds) end)
	local p4 = w4:Newbie(4, { Tutorial = 3, Pos = vec(39, 3, 37) })
	w4:QuestTick()
	check(step(p4) == 3 and #seen4 == 0 and #w4.Travels == 0, "a saved Forge step near the anvil: no arrival metric (the walk was not timed)", show({ step(p4), #seen4 }))
	-- a second [Accept]-like walk after a re-accept starts the clock again
	local w4b = forgeWorld()
	local seen4b = {}
	w4b.Quest.ForgeReached:Connect(function(player, seconds) table.insert(seen4b, seconds) end)
	local p4b = w4b:Newbie(41)
	w4b:Accept(p4b)
	w4b:Advance(12)
	rootOf(p4b).Position = vec(39, 3, 30)
	w4b:QuestTick()
	check(#seen4b == 1 and math.abs(seen4b[1] - 12) < 1.5, "the clock starts at [I'm In!]", show(seen4b))
	-- far from the anvil (24 studs is the line): not yet
	local w4c = forgeWorld()
	local seen4c = {}
	w4c.Quest.ForgeReached:Connect(function(player, seconds) table.insert(seen4c, seconds) end)
	local p4c = w4c:Newbie(42)
	w4c:Accept(p4c)
	rootOf(p4c).Position = vec(39, 3, 45 - 30)
	w4c:QuestTick()
	check(#seen4c == 0, "30 studs away: not arrived", #seen4c)
	rootOf(p4c).Position = vec(39, 3, 45 - 20)
	w4c:QuestTick()
	check(#seen4c == 1, "20 studs: arrived", #seen4c)
	-- the anvil gone: the gift comes at once, never stuck at the Forge step (검수 2026-10-07)
	local w2 = forgeWorld()
	local p2, d2 = w2:Newbie(2)
	w2:Accept(p2)
	check(step(p2) == 3, "setup: the Forge step with the anvil there", step(p2))
	w2.ShopClosed = true
	w2:QuestTick()
	check(step(p2) == 1 and d2.WeaponTier == 1 and d2.WeaponOwnedMask == 1 and firstLines(w2:NoticesFor(p2)) == 1,
		"no anvil at the Forge step: the first weapon at once (Power 0 → N), then step 1", show({ step(p2), d2.WeaponTier }))
	-- the row's tap (RequestTutorial) at the Forge step: nothing is asked for (the client's beam / path light leads)
	local w7 = forgeWorld()
	local p7 = w7:Newbie(7)
	w7:Accept(p7)
	rootOf(p7).Position = vec(0, 4, -410)
	local fx7 = #w7.Fx
	w7:Request(p7)
	w7:Request(p7, "extra")
	check(#w7:FxFor(p7, "Travel", fx7) == 0 and #w7.Travels == 0 and w7:Panels(p7, "Welcome") == 1 and step(p7) == 3,
		"a tap at the Forge step: no trip, no second welcome", show({ #w7:FxFor(p7, "Travel", fx7), #w7.Travels, w7:Panels(p7, "Welcome") }))
	-- a respawned character at the Forge step is simply home (the player walks again)
	local w8 = forgeWorld()
	local p8 = w8:Newbie(8)
	w8:Accept(p8)
	w8:Body(p8)
	w8:Advance(10)
	check(#w8.Travels == 0 and step(p8) == 3, "a KO at the Forge step: nobody moved, still the Forge step", show({ #w8.Travels, step(p8) }))
	-- at another step the tap is the old one (step 1: nothing)
	local w9 = forgeWorld()
	local p9 = w9:Newbie(9, { Tutorial = 1, Tier = 1, Mask = 1 })
	local fx9 = #w9.Fx
	w9:Request(p9)
	check(#w9:FxFor(p9, "Travel", fx9) == 0 and w9:Panels(p9, "Welcome") == 0, "step 1: a tap asks for nothing", step(p9))
end)

------------------------------------------------------------------ 4. the gift: only at the Forge step
runGroup("gift", function()
	local w = forgeWorld()
	local T = w.Config.Tutorial
	-- a save that owns the first weapon (from before A23-34): [Accept] -> step 1 (A23-88: no trip, the pad lesson)
	local old, od = w:Newbie(1, { Tier = 1, Mask = 1 })
	local fx0 = #w.Fx
	w:Accept(old)
	check(step(old) == T.Steps.Guide and #w:FxFor(old, "Travel", fx0) == 0 and #w.Travels == 0, "owns tier 1: [Accept] -> step 1, no trip",
		show({ step(old), #w:FxFor(old, "Travel", fx0) }))
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
	-- the hunt begins on a walk into the meadow too (the step ends however the player got there)
	local w2 = forgeWorld()
	local p2 = w2:Newbie(5, { Pos = vec(39, 3, 37) })
	w2:Accept(p2)
	w2:Press(p2)
	local fx2 = #w2.Fx
	w2:Walk(p2, "SlimeMeadow")
	check(step(p2) == 2, "walking in after the gift starts the hunt", step(p2))
	w2:Advance(10)
	check(#w2:FxFor(p2, "Travel", fx2) == 0 and #w2.Travels == 0, "and nothing ever moved them", #w2:FxFor(p2, "Travel", fx2))
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

------------------------------------------------------------------ 4b. no anvil / a held weapon (검수 2026-10-07 minors 2, 6)
runGroup("no anvil / held weapon", function()
	-- the weapon shop closed at [Accept]: the gift at once, then the usual meadow trip (never the Forge step)
	local w = forgeWorld()
	w.ShopClosed = true
	local p, d = w:Newbie(1)
	local fx0 = #w.Fx
	w:Accept(p)
	check(step(p) == 1 and d.WeaponTier == 1 and d.WeaponOwnedMask == 1 and firstLines(w:NoticesFor(p)) == 1,
		"no anvil at [Accept]: the first weapon at once, step 1 (never stuck at the Forge step)", show({ step(p), d.WeaponTier }))
	check(#w:FxFor(p, "Travel", fx0) == 0, "and no trip (A23-88)", #w:FxFor(p, "Travel", fx0))
	-- a save waiting at the Forge step when the shop is closed: the join gives the weapon and moves on
	local q, e = w:Newbie(2, { Tutorial = 3 })
	check(step(q) == 1 and e.WeaponTier == 1 and e.WeaponOwnedMask == 1 and firstLines(w:NoticesFor(q)) == 1,
		"a Forge-step save with no anvil: the weapon at the join, then step 1", show({ step(q), e.WeaponTier }))
	-- holding a weapon already (tier 2 bought, no tier 1): [Accept] hunts at once like an old save; nothing is given now
	-- (M1_1 hands the first weapon over later, into the bag)
	local w2 = forgeWorld()
	local h, hd = w2:Newbie(3, { Tier = 2, Mask = 2 })
	local fx1 = #w2.Fx
	w2:Accept(h)
	check(step(h) == 1 and #w2:FxFor(h, "Travel", fx1) == 0 and hd.WeaponOwnedMask == 2 and hd.WeaponTier == 2,
		"holding tier 2 (no tier 1): [Accept] -> step 1, no trip, no Forge step, nothing given yet",
		show({ step(h), hd.WeaponOwnedMask, #w2:FxFor(h, "Travel", fx1) }))
	w2:QuestTick()
	check(hd.WeaponOwnedMask == 2, "and no late gift either (the same rule for both)", hd.WeaponOwnedMask)
	-- owning the first weapon but holding nothing (a v3 save may keep tier 0 with weapons owned): it is no gift case,
	-- [Accept] hunts at once (equip from the Bag), no Forge step
	local o, od = w2:Newbie(4, { Tier = 0, Mask = 1 })
	local fx2 = #w2.Fx
	w2:Accept(o)
	check(step(o) == 1 and #w2:FxFor(o, "Travel", fx2) == 0 and od.WeaponOwnedMask == 1,
		"owns tier 1, holds nothing: [Accept] -> step 1, no trip (no Forge step)",
		show({ step(o), od.WeaponOwnedMask, #w2:FxFor(o, "Travel", fx2) }))
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
		-- A23-130 (user 2026-10-11): the same reward-only line for every save
		{ Id = 1, Tier = 1, Mask = 1, Line = T.Text.Claimed, Name = "tier 1 only: +150 gold" },
		{ Id = 2, Tier = 2, Mask = 3, Line = T.Text.Claimed, Name = "tier 2 owned: +150 gold" },
		{ Id = 3, Tier = 8, Mask = 129, Line = T.Text.Claimed, Name = "the jackpot owned: +150 gold" },
	}
	for _, c in cases do
		local p, d = w:Newbie(c.Id, { Tutorial = 2, Tier = c.Tier, Mask = c.Mask, Zone = "SlimeMeadow",
			Data = { TutorialKills = 5, BlacksmithVisited = true } })
		local n = #w.Notices
		w:ClaimFirst(p)
		check(step(p) == 99 and d.BlacksmithVisited == false and count(w:NoticesFor(p, n), string.format(c.Line, "150")) == 1,
			c.Name .. " (the visit cleared)", show(w:NoticesFor(p, n)))
	end
	-- the F10-4 safety net pays with the same reward-only line
	local p, d = w:Newbie(9, { Tutorial = 2, Tier = 1, Mask = 1, Zone = "SlimeMeadow", Data = { TutorialKills = 5 } })
	local n = #w.Notices
	w:QuestTick()
	w:Advance(T.AutoClaimSeconds + 1)
	w:QuestTick()
	check(step(p) == 99 and d.BankGold == 150 and count(w:NoticesFor(p, n), string.format(T.Text.Claimed, "150")) == 1
		and #w:NoticesFor(p, n) == 1, "the auto claim: the same +150 gold line, nothing else", show(w:NoticesFor(p, n)))
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
