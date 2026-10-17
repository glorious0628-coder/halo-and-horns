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
local function DEFS_COUNT(w, id) return w.Config.StoryQuests.Defs[id].Steps[1].Obj.Count end
-- A23-188: the story hears kills (M1_1's Slime Prince): StoryQuestService.Start with the signals this world lacks
local function startStory(w)
	local reg = w.Registry
	reg.GooseService = reg.GooseService or {}
	reg.GooseService.GooseFinished = reg.GooseService.GooseFinished or w.Util.Signal.new()
	reg.ZoneService.ZoneChanged = reg.ZoneService.ZoneChanged or w.Util.Signal.new()
	w.Story.Start()
	w.Warnings = {}
end
local function flat(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end
local function rootOf(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function count(list, text)
	local n = 0
	for _, x in list do if x == text then n += 1 end end
	return n
end
-- LootService's first-weapon line (A23-130: "First weapon: [name]!", the HUD count-up shows the power)
local FIRST_HEAD = string.match(C0.Loot.Text.FirstWeapon, "^(.-)%[") -- "First weapon: "
local function firstLines(list)
	local n = 0
	for _, x in list do
		if string.sub(x, 1, #FIRST_HEAD) == FIRST_HEAD and not string.find(x, "Power", 1, true) then n += 1 end
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
		local line = TC.Welcome[side].Lines[2] -- 사용자 10/15: page 1 = the hello, page 2 = the mission
		check(string.sub(line, 1, 46) == "First, go to Otto's Forge and get your weapon!" and string.find(line, "10 minutes", 1, true) ~= nil
			and not string.find(line, "slimes", 1, true),
			side .. ": page 2 = the Forge (A23-188: no '5 slimes' mission) + the first 10 minutes' 2x XP (A23-221 ⑦)", line)
	end
	check(TC.Text.Forge == "Go to Otto's Forge in the Crossroads" and TC.ShortNames.Forge == "To the Forge" and #TC.ShortNames.Forge <= 14,
		"the Forge row: text + phone ShortName", show({ TC.Text.Forge, TC.ShortNames.Forge }))
	check(TC.Text.Travel == "Step on the glowing pad to go to Squishy Meadow" and TC.ShortNames.Travel == "To the meadow"
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
	-- A23-222 (user 10/16): M1_1 = the Slime Prince only; the scroll is used at Otto's anvil in M1_2 (the King's Hop), next
	local nextOk = true
	for _, side in { "Halo", "Horns", "Neutral" } do
		if not (M11.Next and M11.Next[side] and M11.Next[side].Id == "M1_2") then nextOk = false end
	end
	check(M11.GiveWeapon == 1 and M11.Reward and M11.Reward.Gold == 1 and M11.Steps[1].Obj.Kind == "BigSlime" and M11.Steps[1].Obj.Count == 1
		and #M11.Steps == 1 and nextOk,
		"M1_1 (A23-188 / A23-222): one Slime Prince (no visit, no scroll step), Gold 1, the gift kept as the safety net, next M1_2",
		show({ M11.GiveWeapon, M11.Reward, #M11.Steps, M11.Next }))
	local anvil = C.StoryQuests.Defs.M1_2 and C.StoryQuests.Defs.M1_2.Steps[5]
	check(anvil and anvil.Obj.Name == "ScrollUsed" and anvil.Obj.Past == true and anvil.Anvil == true and anvil.Npc == "Otto"
		and anvil.GiveItem == nil, "M1_2 step 5: the scroll at Otto's anvil (ScrollUsed, Past; no step gift)", show(anvil))
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
	-- the anvil prompt: the first weapon in hand, no shop window, and the first mission is done (A23-188: it IS the visit)
	local n1, f1 = #w.Notices, #w.Fired
	w:Press(p)
	local said = w:NoticesFor(p, n1)
	check(d.WeaponTier == 1 and d.WeaponOwnedMask == 1 and d.BlacksmithVisited == true, "the gift: tier 1 owned and equipped, the visit counted",
		show({ d.WeaponTier, d.WeaponOwnedMask, d.BlacksmithVisited }))
	-- A23-130: no Otto line; the weapon line, then the mission's reward line
	check(#said == 2 and firstLines({ said[1] }) == 1 and string.find(said[1], w.Config.WeaponName(1, "Warrior", "Halo"), 1, true) ~= nil
		and said[2] == string.format(T.Text.Claimed, "150"), "the first weapon line, then '+150 gold' (A23-188: the first mission done)", show(said))
	check(w:Panels(p, "WeaponShop", f1) == 0, "no weapon window at the gift (the Stronger! moment)", w:Panels(p, "WeaponShop", f1))
	check(step(p) == 99 and d.BankGold == 150 and d.BlacksmithVisited == true,
		"A23-188: the visit finishes the first mission: step 99, 150 gold, the visit kept (no second Forge trip)", show({ step(p), d.BankGold }))
	-- nothing moves the player; no travel step, no "5 slimes" hunt
	local fx1 = #w.Fx
	w:Advance(10)
	check(#w:FxFor(p, "Travel", fx1) == 0 and #w.Travels == 0 and step(p) == 99, "10 s after the gift: no automatic trip, done", show({ #w.Travels, step(p) }))
	w:Press(p)
	check(d.BankGold == 150, "a second visit pays nothing more", d.BankGold)
	w:ClaimFirst(p)
	check(d.BankGold == 150, "an old client's [Claim] pays nothing more", d.BankGold)
	-- M1_1 (A23-188): a Slime Prince in the meadow (the first drops the T2 weapon + the Enhance Scroll), then the scroll used
	startStory(w)
	w.Story.Refresh(p)
	local st = d.Story
	check(st.Main.Id == "M1_1" and st.Main.St == 1 and not st.Done.M1_1, "M1_1 starts at once: 'Beat a Slime Prince'", show(st.Main))
	local M11 = w.Config.StoryQuests.Defs.M1_1
	check(M11.Steps[1].Obj.Type == "Kill" and M11.Steps[1].Obj.Kind == "BigSlime" and M11.Steps[1].Guide == "SlimeMeadow",
		"step 1 sends the player to the meadow (no 'show the jelly' trip)", show(M11.Steps[1]))
	local LT = w.Config.Loot
	local function scrolls() return (type(d.Items) == "table" and d.Items.Enh70) or 0 end
	w:Walk(p, "SlimeMeadow")
	for _ = 1, 5 do w:Drop(p, "Slime") end
	check(d.TutorialKills == 0 and step(p) == 99 and d.BankGold == 150, "meadow slimes: no '5 slimes' mission any more", show({ d.TutorialKills, d.BankGold }))
	local n5 = #w.Notices
	w:Drop(p, "BigSlime")
	w:Flush()
	check(st.Done.M1_1 == true and scrolls() >= 1 and bit32.btest(d.WeaponOwnedMask, 2),
		"the first Slime Prince: the T2 weapon + the scroll; M1_1 done (A23-222: one step, the scroll waits for Otto's anvil)",
		show({ st.Main, st.Done.M1_1, scrolls(), d.WeaponOwnedMask }))
	local lines = w:NoticesFor(p, n5) -- the kill's notices: M1_1's reward line
	local done = false
	for _, line in lines do if string.find(line, " done!", 1, true) then done = true end end
	check(done and d.BankGold > 150, "M1_1's reward line and a little gold (Reward Gold 1)", show(lines))
	w.Story.Refresh(p)
	local M12 = w.Config.StoryQuests.Defs.M1_2
	check(st.Main.Id == "M1_2" and st.Main.St == 1 and M12.Steps[1].Guide == "KingHill" and M12.Title == "The King's Hop"
		and w.Config.StoryQuests.Defs.M1_3.Requires.Level == 5,
		"then the King's Hop (main M1_2) starts at once on the King's hill row; M1_3 still waits for Lv5", show(st.Main))
	-- the scroll used from the bag now does not skip the King: M1_2 stays on its first row (step 5 = Past: it passes later)
	local had = scrolls()
	w:Remote(p, "UseItem", "Enh70", 1)
	check(scrolls() == had - 1 and st.Main.Id == "M1_2" and st.Main.St == 1,
		"a scroll used from the bag right away: M1_2 still waits for the King's hop (step 1)", show({ st.Main, scrolls() }))
end)

------------------------------------------------------------------ 2b. a step's gift (GiveItem: given once when the step opens, tried again at a join)
runGroup("step gift", function()
	local w = forgeWorld()
	local T = w.Config.Tutorial
	-- no step ships a GiveItem since A23-188; the engine keeps it (a test-only gift on a test-only M1_1 step 2: A23-222 ships
	-- M1_1 with one step)
	w.Config.StoryQuests.Defs.M1_1.Steps[2] = { Text = "Use the Enhance Scroll on your weapon", ShortName = "Enhance", Guide = "Bag",
		Obj = { Type = "Event", Name = "ScrollUsed", Past = true }, GiveItem = { Item = "Enh70", N = 1 } }
	local p, d = w:Newbie(2)
	w:Accept(p)
	w:Walk(p, "Crossroads")
	rootOf(p).Position = vec(39, 3, 37)
	w:Press(p)
	startStory(w)
	w.Story.Refresh(p)
	local st = d.Story
	local LT = w.Config.Loot
	local scrollName = LT.Items.Enh70.Name
	local function scrolls() return (type(d.Items) == "table" and d.Items.Enh70) or 0 end
	-- 최종 검수 10/13 review: the gift can give nothing because of a failure (here: GrantItem throws) - then it is not marked
	-- given and the next join tries again; a FULL stack stays marked (no "full" line every join)
	local lootSvc = w.Registry.LootService
	local grantItem, asked = lootSvc.GrantItem, {}
	lootSvc.GrantItem = function(pl, id, n)
		table.insert(asked, id)
		error("offline GrantItem failure")
	end
	w:Walk(p, "SlimeMeadow")
	local n3 = #w.Notices
	w.Registry.MonsterService.MonsterKilled:Fire(p, { Kind = "BigSlime", Golden = false, Position = vec(0, 0, 0), ZoneId = "SlimeMeadow" })
	w:Flush()
	lootSvc.GrantItem = grantItem
	w.Warnings = {} -- the expected GrantItem warning
	local had = scrolls()
	check(#asked == 1 and asked[1] == "Enh70" and st.Main.Id == "M1_1" and st.Main.St == 2, "the step opening asks for the gift once (it fails here)",
		show({ asked, st.Main }))
	check(st.First.GiveM1_12 == nil and count(w:NoticesFor(p, n3), string.format(LT.Text.Got, scrollName)) == 0,
		"a gift that failed is not marked given and shows no '+item' line", show({ st.First.GiveM1_12, w:NoticesFor(p, n3) }))
	local n3b = #w.Notices
	w.Story.RetryGifts(p) -- what the join (PlayerReady) runs
	w:Flush()
	check(scrolls() == had + 1 and st.First.GiveM1_12 == true and count(w:NoticesFor(p, n3b), string.format(LT.Text.Got, scrollName)) == 1,
		"the next join (RetryGifts) gives it with one '+item' line", show({ had, scrolls(), w:NoticesFor(p, n3b) }))
	w.Story.RetryGifts(p)
	w:Flush()
	check(scrolls() == had + 1, "another join gives no second one", show({ had, scrolls() }))
	-- a full stack: nothing given, but it stays marked (the player holds scrolls), so later joins ask nothing
	st.First.GiveM1_12 = nil
	d.Items.Enh70 = LT.ItemCap
	asked = {}
	lootSvc.GrantItem = function(pl, id, n)
		table.insert(asked, id)
		return grantItem(pl, id, n)
	end
	w.Story.RetryGifts(p)
	w.Story.RetryGifts(p)
	w:Flush()
	lootSvc.GrantItem = grantItem
	check(#asked == 1 and st.First.GiveM1_12 == true and d.Items.Enh70 == LT.ItemCap,
		"a full stack: asked once, then marked given (no retry, no repeated 'full' line)", show({ asked, st.First.GiveM1_12 }))
	-- 1-A #2: a scroll used on the weapon (LootService's Event ScrollUsed) passes the scroll step
	check(st.Main.Id == "M1_1" and st.Main.St == 2, "still on the (test-only) scroll step", show(st.Main))
	w:Remote(p, "UseItem", "Enh70", 1)
	check(st.Done.M1_1 == true and d.Items.Enh70 == LT.ItemCap - 1, "a scroll used from the bag: ScrollUsed passes the step (M1_1 done)",
		show({ st.Done.M1_1, st.Main, d.Items.Enh70 }))
	local _ = T
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
	check(step(p2) == 99 and d2.WeaponTier == 1 and d2.WeaponOwnedMask == 1 and firstLines(w2:NoticesFor(p2)) == 1 and d2.BankGold == 150,
		"no anvil at the Forge step: the first weapon at once (Power 0 → N), the mission done (+150, A23-188)", show({ step(p2), d2.WeaponTier }))
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
	check(step(old) == 99 and od.BankGold == 150 and #w:FxFor(old, "Travel", fx0) == 0 and #w.Travels == 0,
		"owns tier 1: [Accept] -> the mission done at once (+150, A23-188), no trip", show({ step(old), od.BankGold }))
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
	check(step(p2) == 99, "A23-188: no hunt step after the gift (the mission was the visit)", step(p2))
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
	check(step(p5) == 99 and d5.WeaponOwnedMask == 1 and d5.BankGold == 150 and count(again, w5.Config.Tutorial.Text.ForgeGift) == 0
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
	check(step(p) == 99 and d.WeaponTier == 1 and d.WeaponOwnedMask == 1 and firstLines(w:NoticesFor(p)) == 1 and d.BankGold == 150,
		"no anvil at [Accept]: the first weapon at once, the mission done (never stuck at the Forge step)", show({ step(p), d.WeaponTier }))
	check(#w:FxFor(p, "Travel", fx0) == 0, "and no trip (A23-88)", #w:FxFor(p, "Travel", fx0))
	-- a save waiting at the Forge step when the shop is closed: the join gives the weapon and moves on
	local q, e = w:Newbie(2, { Tutorial = 3 })
	check(step(q) == 99 and e.WeaponTier == 1 and e.WeaponOwnedMask == 1 and firstLines(w:NoticesFor(q)) == 1 and e.BankGold == 150,
		"a Forge-step save with no anvil: the weapon at the join, the mission done", show({ step(q), e.WeaponTier }))
	-- holding a weapon already (tier 2 bought, no tier 1): [Accept] hunts at once like an old save; nothing is given now
	-- (M1_1 hands the first weapon over later, into the bag)
	local w2 = forgeWorld()
	local h, hd = w2:Newbie(3, { Tier = 2, Mask = 2 })
	local fx1 = #w2.Fx
	w2:Accept(h)
	check(step(h) == 99 and #w2:FxFor(h, "Travel", fx1) == 0 and hd.WeaponOwnedMask == 2 and hd.WeaponTier == 2 and hd.BankGold == 150,
		"holding tier 2 (no tier 1): [Accept] -> done (+150), no trip, no Forge step, nothing given yet",
		show({ step(h), hd.WeaponOwnedMask, #w2:FxFor(h, "Travel", fx1) }))
	w2:QuestTick()
	check(hd.WeaponOwnedMask == 2, "and no late gift either (the same rule for both)", hd.WeaponOwnedMask)
	-- owning the first weapon but holding nothing (a v3 save may keep tier 0 with weapons owned): it is no gift case,
	-- [Accept] hunts at once (equip from the Bag), no Forge step
	local o, od = w2:Newbie(4, { Tier = 0, Mask = 1 })
	local fx2 = #w2.Fx
	w2:Accept(o)
	check(step(o) == 99 and #w2:FxFor(o, "Travel", fx2) == 0 and od.WeaponOwnedMask == 1,
		"owns tier 1, holds nothing: [Accept] -> done, no trip (no Forge step)",
		show({ step(o), od.WeaponOwnedMask, #w2:FxFor(o, "Travel", fx2) }))
end)

------------------------------------------------------------------ quest P1 ② (bible v3 H00 / R00 / N00, H00a / R00a / N00a): the guide's and the
-- teacher's bodies. The first mission is opened by a talk to the guide (no automatic lines, the row only guides), Halo / Horns meet
-- their teacher (step Teacher = 4: met = the lesson is offered in the same talk) and then walk to the Forge; the artisans go
-- to the Forge at once (Otto is their teacher there). A world without the bodies keeps the old way.
runGroup("p1 guide and teacher", function()
	local w = forgeWorld()
	local T = w.Config.Tutorial
	local SQ = w.Config.StoryQuests
	local bodies = {}
	w.Services.CollectionService = { GetTagged = function(_, tag)
		if tag == SQ.NpcTag then return bodies end
		return {}
	end }
	local function body(id, pos)
		local part = newInstance("Part", w)
		part.Name, part.Position = "Npc" .. id, pos
		part.Attrs.NpcId = id
		table.insert(bodies, part)
		return part
	end
	startStory(w)
	local HALLIE, GLEAM, KIT, OTTO = vec(-16, 0, -428), vec(-10, 0, -372), vec(47, 0, 45), vec(39, 0, 49)
	body("Hallie", HALLIE)
	body("Gleam", GLEAM)
	body("Kit", KIT)
	body("Otto", OTTO)
	check(T.Steps.Teacher == 4 and T.Guides.Halo == "Hallie" and T.Guides.Horns == "Magpie" and T.Guides.Neutral == "Kit"
		and #T.ShortNames.Teacher <= 16, "Config: step Teacher = 4, the guides' NpcIds, the row texts", show(T.Guides))
	-- Halo: no automatic lines, the row tap opens nothing, the talk to Hallie does
	local p, d = w:Newbie(301, { Faction = "Halo" })
	check(w:Panels(p, "Welcome") == 0, "a guide with a body: no automatic welcome lines at the join", w:Panels(p, "Welcome"))
	local row = w:Rows(p)[1] or {}
	check(row.TutorialStep == 0 and row.GuideNpc == "Hallie" and row.Text == string.format(T.Text.WelcomeBody, "Hallie"),
		"the row: 'Talk to Hallie' with GuideNpc = Hallie", show({ row.Text, row.GuideNpc }))
	w:Request(p)
	check(w:Panels(p, "Welcome") == 0, "the row tap (RequestTutorial) opens nothing while the guide has a body", "")
	rootOf(p).Position = vec(0, 3, -380)
	check(w.Story.TalkToNpc(p, "Hallie") == nil and w:Panels(p, "Welcome") == 0, "talking to Hallie from 48 studs: nothing", "")
	w:Accept(p)
	check(step(p) == 0, "[Accept] far from Hallie: refused", step(p))
	rootOf(p).Position = vec(-14, 3, -426)
	check(w.Story.TalkToNpc(p, "Hallie") == "Welcome" and w:Panels(p, "Welcome") == 1, "next to Hallie: her lines open", "")
	local tfx = #w.Fx
	w:Accept(p)
	check(step(p) == T.Steps.Teacher and d.TutorialStep == 4, "[Accept] next to Hallie: step Teacher (4), not the Forge yet", step(p))
	-- A23-208 the first mission's story: the Teacher step starts with its Find (Fx StoryScene Id "Tutorial", the step's name)
	local tsc = w:FxFor(p, "StoryScene", tfx)
	check(#tsc == 1 and tsc[1].Data.Id == "Tutorial" and tsc[1].Data.Key == "Find" and tsc[1].Data.Value == "Teacher"
		and type(T.Story.Steps.Teacher.Find.Halo) == "string" and #T.Story.Before.Halo <= 70,
		"A23-208: [Accept] = the Teacher step's Find (Tutorial)", show(tsc[1] and tsc[1].Data))
	tfx = #w.Fx
	row = w:Rows(p)[1] or {}
	check(row.TutorialStep == 4 and row.GuideNpc == "Gleam" and row.Text == string.format(T.Text.Teacher, "Sir Gleam")
		and row.ShortName == string.format(T.ShortNames.Teacher, "Sir Gleam"),
		"the row: 'Meet Sir Gleam at the town gate', GuideNpc = Gleam", show({ row.Text, row.ShortName, row.GuideNpc }))
	-- the lesson is not offered before the teacher is met
	w.Story.Refresh(p)
	check(string.find(p:GetAttribute("StoryOffers") or "", "Gleam", 1, true) == nil, "before the meeting: Sir Gleam offers nothing", p:GetAttribute("StoryOffers"))
	check(w.Story.TalkToNpc(p, "Gleam") == nil and step(p) == T.Steps.Teacher and d.Story.First.TeacherMet ~= true,
		"talking to Sir Gleam from 50 studs: not met", step(p))
	rootOf(p).Position = vec(-12, 3, -374)
	local n0 = #w.Fired
	local said = w.Story.TalkToNpc(p, "Gleam")
	-- A23-221 ① (최종 검수 10/16): the lesson is the first mission's Practice step (5) now, not a side offer
	check(said ~= "Welcome" and step(p) == T.Steps.Practice and T.Steps.Practice == 5 and d.TutorialStep == 5
		and d.Story.First.TeacherMet == true and w:Panels(p, "Offer", n0) == 0,
		"the talk to Sir Gleam: met (saved), the Practice step (5), no side offer (A23-221 ①)", show({ said, step(p) }))
	check(SQ.Defs.H_Basics == nil and SQ.Defs.R_Basics == nil and table.find(SQ.Subs, "H_Basics") == nil
		and table.find(SQ.Subs, "R_Basics") == nil and SQ.Defs.N_Basics ~= nil and T.Practice.Neutral == nil,
		"Config: the Halo / Horns lessons are gone (the artisans keep Otto's N_Basics; no Neutral practice key)", show(T.Practice))
	local keys = {}
	for _, f in w:FxFor(p, "StoryScene", tfx) do
		if f.Data.Id == "Tutorial" then table.insert(keys, f.Data.Key .. "=" .. tostring(f.Data.Value) .. "@" .. tostring(f.Data.St)) end
	end
	check(table.concat(keys, ",") == "Scene=Wave@Teacher,Find=Practice@Practice", "A23-208: met = Sir Gleam's wave, then the Practice step's Find",
		table.concat(keys, ","))
	w.Story.Refresh(p)
	check(p:GetAttribute("PracticeTool") == "Tutorial", "the borrowed practice tool while the dummy step is open (PracticeTool = Tutorial)",
		p:GetAttribute("PracticeTool"))
	row = w:Rows(p)[1] or {}
	check(row.TutorialStep == 5 and row.Text == T.Text.Practice and row.ShortName == T.ShortNames.Practice and row.GuideSpot == "PracticeH"
		and row.Practice == true and #T.ShortNames.Practice <= 14,
		"the row: 'Hit the practice dummy', GuideSpot = PracticeH, Practice = true", show({ row.Text, row.ShortName, row.GuideSpot, row.Practice }))
	local dummy = SQ.Landmarks.PracticeH
	-- 최종 검수 10/16 🔴: the dummy stood 10.8 from Pad_Halo_SlimeMeadow and a player at it was sent to the meadow. The Halo
	-- plaza pads (place/GoodEvil.rbxlx 10/16: Pad_Halo_SlimeMeadow (-24, -357), Pad_Halo_GoblinWoods (24, -357), 10 x 10) and
	-- the town road (|x| <= 8) stay away from it
	local near = math.huge
	for _, pad in { { -24, -357 }, { 24, -357 } } do near = math.min(near, math.sqrt((dummy.X - pad[1]) ^ 2 + (dummy.Z - pad[2]) ^ 2)) end
	check(near >= 25 and math.abs(dummy.X) >= 14, "PracticeH is >= 25 studs from every Halo plaza pad and off the town road",
		show({ dummy.X, dummy.Z, near }))
	local swing = w.Registry.CombatService.BasicSwing
	swing:Fire(p, vec(dummy.X - 15, 0, dummy.Z), vec(1, 0, 0))
	w:Flush()
	check(step(p) == T.Steps.Practice, "a swing 15 studs from the dummy (facing it): nothing", step(p))
	local other = w:Newbie(311, { Faction = "Halo" })
	swing:Fire(other, vec(dummy.X - 4, 0, dummy.Z), vec(1, 0, 0))
	w:Flush()
	check(step(p) == T.Steps.Practice and step(other) == 0, "another player's swing at the dummy: nothing for me (nor for them)",
		show({ step(p), step(other) }))
	local sfx = #w.Fx
	swing:Fire(p, vec(dummy.X - 4, 0, dummy.Z), vec(-1, 0, 0)) -- 4 studs away, facing AWAY from the dummy
	w:Flush()
	check(step(p) == T.Steps.Forge and (d.WeaponTier or 0) == 0,
		"a swing 4 studs from the dummy facing AWAY counts (A23-221 ①: no facing check): bare-handed -> the Forge", step(p))
	keys = {}
	for _, f in w:FxFor(p, "StoryScene", sfx) do
		if f.Data.Id == "Tutorial" then table.insert(keys, f.Data.Key .. "=" .. tostring(f.Data.Value) .. "@" .. tostring(f.Data.St)) end
	end
	check(table.concat(keys, ",") == "Scene=Bow@Practice,Find=Forge@Forge", "Sir Gleam's bow (the stick back), then the Forge step's Find",
		table.concat(keys, ","))
	check((p:GetAttribute("PracticeTool") or "") == "", "the stick is handed back (PracticeTool cleared)", p:GetAttribute("PracticeTool"))
	swing:Fire(p, vec(dummy.X - 4, 0, dummy.Z), vec(1, 0, 0))
	w:Flush()
	check(step(p) == T.Steps.Forge, "a second swing changes nothing", step(p))
	-- the Forge as before: the first weapon and the 150 gold once
	w:Walk(p, "Crossroads")
	rootOf(p).Position = vec(39, 3, 37)
	w:Press(p)
	check(step(p) == 99 and d.WeaponTier == 1 and d.BankGold == 150, "then Otto's gift: the first weapon + 150, the mission done", show({ step(p), d.BankGold }))
	-- the artisans: Kit at the anvil, no teacher step, the lesson offered by Otto after the weapon (the guild's own quests wait for
	-- its switch, A23-57: on here)
	w.Config.Features.NeutralFaction = true
	local n, nd = w:Newbie(302, { Faction = "Neutral", Zone = "Crossroads" })
	check(w:Panels(n, "Welcome") == 0, "Kit has a body: no automatic lines", "")
	rootOf(n).Position = vec(46, 3, 44)
	check(w.Story.TalkToNpc(n, "Kit") == "Welcome", "next to Kit: the lines", "")
	w:Accept(n)
	check(step(n) == T.Steps.Forge, "an artisan goes to the Forge at once (Otto is their teacher there)", step(n))
	w.Story.Refresh(n)
	check(string.find(n:GetAttribute("StoryOffers") or "", "Otto", 1, true) == nil, "no lesson before the first weapon", n:GetAttribute("StoryOffers"))
	rootOf(n).Position = vec(39, 3, 37)
	w:Press(n)
	w.Story.Refresh(n)
	check(step(n) == 99 and string.find(n:GetAttribute("StoryOffers") or "", "Otto", 1, true) ~= nil,
		"after the weapon: Otto offers his lesson", n:GetAttribute("StoryOffers"))
	-- Horns without a teacher body here: [Accept] goes to the Forge as before; a save at step 4 whose teacher is gone moves on
	local r, rd = w:Newbie(303, { Faction = "Horns" })
	check(w:Panels(r, "Welcome") == 1, "Magpie has no body here: the old automatic lines", w:Panels(r, "Welcome"))
	w:Accept(r)
	check(step(r) == T.Steps.Forge, "no teacher body (Rose): no teacher step", step(r))
	local s4, sd = w:Newbie(304, { Faction = "Horns", Tutorial = 4 })
	check(step(s4) == T.Steps.Forge, "a save at the Teacher step whose teacher has no body: on to the Forge at the join", step(s4))
	-- A23-221 ①: Rose's body: the talk -> Practice at PracticeR; the dummy's spot gone while the step waits -> on (never stuck)
	local ROSE = vec(-30, 0, 410)
	body("Smokey", ROSE)
	local h, hd = w:Newbie(305, { Faction = "Horns" })
	rootOf(h).Position = vec(-14, 3, -426) -- (the guide's lines open by the row while Magpie has no body)
	w:Accept(h)
	check(step(h) == T.Steps.Teacher, "Horns with Rose's body: the Teacher step", step(h))
	rootOf(h).Position = vec(-28, 3, 412)
	w.Story.TalkToNpc(h, "Smokey")
	w.Story.Refresh(h)
	check(step(h) == T.Steps.Practice and hd.Story.First.TeacherMet == true and h:GetAttribute("PracticeTool") == "Tutorial",
		"Horns: met Rose -> the Practice step at PracticeR, the stick in hand", show({ step(h), h:GetAttribute("PracticeTool") }))
	local spotR = SQ.Landmarks.PracticeR
	SQ.Landmarks.PracticeR = nil
	w:QuestTick()
	check(step(h) == T.Steps.Forge, "the dummy's spot gone while the Practice step waits: on to the Forge (never stuck)", step(h))
	local h2, hd2 = w:Newbie(306, { Faction = "Horns" })
	w:Accept(h2)
	rootOf(h2).Position = vec(-28, 3, 412)
	w.Story.TalkToNpc(h2, "Smokey")
	check(step(h2) == T.Steps.Forge and hd2.Story.First.TeacherMet == true,
		"a side without a dummy spot: met -> straight to the Forge (no Practice step)", step(h2))
	SQ.Landmarks.PracticeR = spotR
	-- an armed Horns player: the dummy hit finishes the mission (TEACH.After: no Forge trip with a weapon in hand)
	local h3, hd3 = w:Newbie(307, { Faction = "Horns", Tier = 1, Mask = 1 })
	w:Accept(h3)
	rootOf(h3).Position = vec(-28, 3, 412)
	w.Story.TalkToNpc(h3, "Smokey")
	check(step(h3) == T.Steps.Practice, "armed: met Rose -> the Practice step too", step(h3))
	w.Registry.CombatService.BasicSwing:Fire(h3, vec(spotR.X + 6, 0, spotR.Z + 6), vec(1, 0, 0)) -- 8.5 studs, facing away
	w:Flush()
	check(step(h3) == 99 and hd3.BankGold == 150, "armed: the dummy hit finishes the first mission (+150)", show({ step(h3), hd3.BankGold }))
end)

------------------------------------------------------------------ 5. old saves: never left bare-handed
runGroup("old saves", function()
	local w = forgeWorld()
	for i, s in { 1, 2, 99 } do
		local p, d = w:Newbie(10 + i, { Tutorial = s, Zone = s == 2 and "SlimeMeadow" or "HaloTown" })
		-- A23-188: a save at the old steps 1 / 2 (the travel / the "5 slimes" hunt) is done at the join
		check(d.WeaponTier == 1 and d.WeaponOwnedMask == 1 and step(p) == 99, "step " .. s .. " bare-handed: the gift at the join (A23-188: done)",
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
	-- A23-188: the old "5 slimes" mission is gone; a save in it (step 1 / 2, any kills) is done at the join with the same
	-- reward-only line, the Forge visit kept (no second Forge trip any more), once
	local w = forgeWorld()
	local T = w.Config.Tutorial
	local cases = {
		{ Id = 1, Tier = 1, Mask = 1, Step = 2, Kills = 5, Name = "a save at 5/5 (tier 1)" },
		{ Id = 2, Tier = 2, Mask = 3, Step = 2, Kills = 2, Name = "a save at 2/5 (tier 2 owned)" },
		{ Id = 3, Tier = 8, Mask = 129, Step = 1, Kills = 0, Name = "a save on the way to the meadow (the jackpot owned)" },
	}
	for _, c in cases do
		local n = #w.Notices
		local p, d = w:Newbie(c.Id, { Tutorial = c.Step, Tier = c.Tier, Mask = c.Mask, Zone = "SlimeMeadow",
			Data = { TutorialKills = c.Kills, BlacksmithVisited = true } })
		w:QuestTick()
		check(step(p) == 99 and d.BankGold == 150 and d.BlacksmithVisited == true and count(w:NoticesFor(p, n), string.format(T.Text.Claimed, "150")) == 1,
			c.Name .. ": done at the join, +150 gold once, the visit kept", show({ step(p), d.BankGold, w:NoticesFor(p, n) }))
		w:ClaimFirst(p)
		w:QuestTick()
		check(d.BankGold == 150, c.Name .. ": a [Claim] after it pays nothing more", d.BankGold)
	end
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
	for _, case in { { 3, 3 }, { 0, 0 }, { 1, 1 }, { 2, 2 }, { 99, 99 }, { 4, 4 }, { 5, 5 }, { 6, 99 }, { -1, 99 } } do -- P1 ②: 4 = the Teacher step; A23-221 ①: 5 = the dummy
		check(load(case[1]) == case[2], "TutorialStep " .. case[1] .. " loads as " .. case[2], load(case[1]))
	end
end)

------------------------------------------------------------------ r5 플레이: the pinned row on a Learn step
-- 최종 검수 10/16 (game play r5): handing Tiny the parcel (M1_3 step 3) opens step 4 "Learn your first skill from Rose" and makes
-- Q ready at the teacher at once; the pinned row must stay M1_3's (else the row leaves the list, the client never sees step 3
-- end and Tiny's line never shows). A main on another step keeps A23-193's "Learn a skill: meet <teacher>" row first
runGroup("pinned learn row", function()
	local w = forgeWorld()
	startStory(w)
	local function at(id, st, done)
		return { Tutorial = 99, Faction = "Horns", Level = 5, Data = { BlacksmithVisited = true, SkillSlots = 0,
			Story = { Main = { Id = id, St = st, P = 0, T = {}, Claim = false }, Subs = {}, Done = done, Pick = {}, First = { Migrated = true }, Schema = 6 } } }
	end
	local p = w:Newbie(901, at("M1_3", 4, { M1_1 = true, M1_2 = true }))
	p:SetAttribute("SkillLearnReady", 1)
	local row = w:Rows(p)[1] or {}
	local okM, mr = pcall(w.Story.MainRow, p, w.Data[p])
	check(type(row.Story) == "table" and row.Story.Id == "M1_3" and row.Story.St == 4 and row.GoalKind == nil,
		"M1_3 on its Learn step + Q ready: the pinned row stays M1_3 step 4",
		show({ row.Text, row.GoalKind, okM, okM and mr and mr.Story and mr.Story.Id or tostring(mr), w.Data[p].Story.Main.Id, w.Data[p].Story.Main.St }))
	local q = w:Newbie(902, at("M2_5", 2, { M1_1 = true, M1_2 = true, M1_3 = true, M1_4 = true, M2_1 = true, M2_2 = true, M2_3 = true, M2_4 = true }))
	q:SetAttribute("SkillLearnReady", 1)
	local qrow = w:Rows(q)[1] or {}
	check(qrow.GoalKind == "SkillLearn" and qrow.NextGoal == true, "a main on another step: 'Learn a skill: meet <teacher>' stays first (A23-193)",
		show({ qrow.Text, qrow.GoalKind }))
end)

finish()
