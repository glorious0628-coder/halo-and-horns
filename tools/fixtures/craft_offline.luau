-- craft_offline.luau : artisan crafting (CraftService, 게임성 개발 3, 2026-10-12; contract docs/design/craft_server_2026-10-12.md).
-- tools/test_craft.py binds CONFIG_SOURCE, UTIL_SOURCE, LOOT_SOURCE and CRAFT_SOURCE in front of dev2_kit.luau +
-- dev3_world.luau; this file follows. LootService (TakeItem / GrantItems, from source; AddSpare / SpareRoom = doubles
-- until 게임성 개발 2's C1) and CraftService run from source; PlayerService / ProgressionService (+ SpendGold here) /
-- ShopService.Anvil / TelemetryService are doubles. Engine doubles: workspace:GetServerTimeNow, CollectionService (the
-- workbench tag), player:GetNetworkPing, BasePart IsA. The hammer is played like the client: every ring end sends
-- CraftStrike at the real moment (press + half the ping), then CraftFinish with the claimed offsets.

local NOON = 1789959600 -- 2026-09-22 12:00 KST

do
	local M = instMeta.Methods
	local baseIsA = M.IsA
	M.IsA = function(o, kind)
		if kind == "BasePart" and o.ClassName == "Part" then return true end
		return baseIsA(o, kind)
	end
end

-- o: Off, NoSpare (a LootService without AddSpare / SpareRoom), RealSpare (LootService's own AddSpare / SpareRoom, C1),
-- EditConfig(c)
local function cWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local edit = o.EditConfig
	o.EditConfig = function(c)
		if o.Off ~= true then c.Features.Crafting = true end
		-- 장인 ④: the bench builder (Config.Craft.Benches) only in the groups that ask for it; the rest keep the anvil fallback
		if o.Benches ~= true then c.Craft.Benches = nil end
		-- 장인 ② (10/14): the shipped W1 is gone (tier 1 = the free class weapon); the mechanics groups below keep a
		-- test-only W1 with its old numbers (a tier-1 spare, 10 gold, 5 jelly + 2 copper, XP 10)
		if c.Craft.Recipes.W1 == nil then
			c.Craft.Recipes.W1 = { Role = "Smith", Kind = "Weapon", Tier = 1, Lv = 1, Gold = 10, Mats = { Jelly = 5, CopperOre = 2 }, XP = 10 }
		end
		if edit then edit(c) end
	end
	local w = dev3World(o)
	local ws = newInstance("Workspace", w)
	ws.GetServerTimeNow = function() return w.Time + 0.25 end
	w.Tagged = { CraftStation = {} }
	w.Added = rbxSignal(w.Warnings)
	w.Services.CollectionService = { GetTagged = function(_, tag) return w.Tagged[tag] or {} end,
		AddTag = function(_, inst, tag) -- 장인 ④: CraftService tags the benches it builds
			w.Tagged[tag] = w.Tagged[tag] or {}
			table.insert(w.Tagged[tag], inst)
		end,
		GetInstanceAddedSignal = function() return w.Added end }
	w.PPS = { PromptTriggered = rbxSignal(w.Warnings) }
	w.Services.ProximityPromptService = w.PPS
	local baseEnv = w.Env
	function w:Env()
		local e = baseEnv(self)
		e.workspace = ws
		return e
	end
	w.Net.NotifyKey = function(p, key, args, kind)
		table.insert(w.Notices, { Player = p, Key = key, Kind = kind, Text = "KEY:" .. tostring(key) })
	end
	w.Tele = {}
	w.Reg.TelemetryService = { Custom = function(p, name, v, a, b) table.insert(w.Tele, { P = p, Name = name, V = v, A = a, B = b }) end }
	local anvil = newInstance("Part", w)
	anvil.Position = vec(0, 0, 0)
	w.Anvil = anvil
	w.Reg.ShopService = { Anvil = function() return w.Anvil end }
	function w.Prog.SpendGold(p, amount, reason)
		local d = w.Data[p]
		local carried, bank = tonumber(d.CarriedGold) or 0, tonumber(d.BankGold) or 0
		if carried + bank < amount then return false end
		local fromC = math.min(carried, amount)
		d.CarriedGold, d.BankGold = carried - fromC, bank - (amount - fromC)
		table.insert(w.Spent, { P = p, N = amount, Why = reason })
		return true
	end
	w.Spent = {}
	w.Ping = 0.1
	-- A23-75 pass check double (ProgressionService.PassMult): w.PassXP2[player] = true = the 2x XP pass
	w.PassXP2 = {}
	function w.Prog.PassMult(p, kind) return (kind == "XP2" and w.PassXP2[p]) and 2 or 1 end
	w.Services.ReplicatedStorage.Shared.CraftMini = "CraftMini"
	w.Mini = w:Load("CraftMini", CRAFTMINI_SOURCE)
	w:Service("LootService", LOOT_SOURCE)
	w:Service("CraftService", CRAFT_SOURCE)
	local L = w.Reg.LootService
	L.Init(w.Reg)
	w.Spares, w.SpareFull = {}, false
	if o.NoSpare then
		L.AddSpare, L.SpareRoom = nil, nil -- a LootService without the spares API (the guard in RecipeOn)
	elseif not o.RealSpare then
		function L.AddSpare(p, tier, plus, o)
			if w.SpareFull then return false end
			table.insert(w.Spares, { P = p, Tier = tier, Plus = plus, Opt = o })
			return true
		end
		function L.SpareRoom(p, tier, plus) return not w.SpareFull end
	end
	w.Reg.SwitchService = { Changed = w.Util.Signal.new(), On = function() return true end } -- ⑤: the switchboard double
	w:InitStart({ "CraftService" })
	w.C = w.Reg.CraftService
	w.Crafted = {}
	w.C.Crafted:Connect(function(p, id, plus) table.insert(w.Crafted, { P = p, Id = id, Plus = plus }) end)
	return w
end

local MATS = { Jelly = 200, Petal = 50, CopperOre = 80, SlimeCore = 30, GoblinTooth = 50, BruteHorn = 30, IronOre = 50, OakLog = 30,
	Bone = 200, KnightCrest = 200, CaptainBadge = 10, SilverOre = 60, MoonCrystal = 40 }

-- a ready artisan at the anvil; extra = save fields
local function smith(w, id, extra, class, faction)
	local data = { Faction = faction or "Neutral", Class = class or "Warrior", ClassChosen = true, Level = 10, BankGold = 100000,
		BagSlots = 20, -- bag slots 10/14: the 13 material kinds below need more than the starting 12
		Items = deepCopy(MATS) }
	for k, v in extra or {} do data[k] = v end
	local p, d = w:Arrive(id, { Data = data })
	w.CharFolder = w.CharFolder or newInstance("Folder", w)
	local char = newInstance("Model", w)
	char.Parent = w.CharFolder
	local root = newInstance("Part", w)
	root.Name, root.Position = "HumanoidRootPart", vec(5, 0, 0)
	root.Parent = char
	local hum = newInstance("Humanoid", w)
	hum.Health = 100
	hum.Parent = char
	p.Character = char
	p.GetNetworkPing = function() return w.Ping end
	return p, d
end

local function rootOf(p) return p.Character:FindFirstChild("HumanoidRootPart") end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function fired(w, remote, p)
	local out = {}
	for _, f in w.Fired do
		if f.Remote == remote and f.Player == p then table.insert(out, f.Payload) end
	end
	return out
end

local function last(list) return list[#list] end

local function keysFor(w, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Notices do
		local n = w.Notices[i]
		if n.Player == p and n.Key then table.insert(out, n.Key) end
	end
	return out
end

local function serverNow(w) return w.Time + 0.25 end

-- play the open session like the client (fixed schedule, Shared/CraftMini): offsets = real press offsets from each ring's
-- target (ms, false = no press: no strike); a strike arrives half the ping later. o.Claim = the ms the client says (default
-- = offsets); o.Skip = { [i] = true } presses whose strike never arrives; o.ByRemote = through the remotes; returns the
-- Finish answer and the session
local function hammer(w, p, offsets, o)
	o = o or {}
	local sess = last(fired(w, "CraftSession", p))
	local half = w.Ping / 2
	local claim = o.Claim or offsets
	for i = 1, 5 do
		if offsets[i] then
			local arrive = w.Mini.Target(sess.StartAt, i) + offsets[i] / 1000 + half
			w:Advance(arrive - serverNow(w))
			if not (o.Skip and o.Skip[i]) then
				if o.ByRemote then
					w.Gap = 0
					w:Remote("CraftStrike", p, sess.Id, i, claim[i])
				else
					w.C.Strike(p, sess.Id, i, claim[i])
				end
			end
		end
	end
	w:Advance(math.max(0, w.Mini.Ends(sess.StartAt) - serverNow(w)))
	local r
	if o.ByRemote then
		w.Gap = 0
		w:Remote("CraftFinish", p, sess.Id)
	else
		r = w.C.Finish(p, sess.Id)
	end
	w:Flush()
	return r, sess
end

-- o.Recipe = the recipe (default W1); the rest as hammer()
local function startAndHammer(w, p, offsets, o)
	local s = w.C.TryStart(p, (o and o.Recipe) or "W1")
	if s ~= "ok" then return s end
	return hammer(w, p, offsets, o)
end

local HONEST = { 30, 50, 40, 20, 60 } -- all Perfect (e = 10, 10, 0, 20, 20), not all the same

------------------------------------------------------------------ the table
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local K = C.Craft
	check(C.Features.Crafting == false and C.FeatureOn("Crafting") == false, "Config.Features.Crafting is off", "")
	check(K.Roles.Warrior == "Smith" and K.Roles.Mage == "Alch" and K.Roles.Archer == "Tame", "artisan roles: Warrior Smith, Mage Alch, Archer Tame", show(K.Roles))
	check(K.MaxLv == 30 and K.MaxLv == C.SaveV4.CraftMaxLv and K.XPBase == 40 and K.XPExp == 1.5, "craft Lv 1..30 (same as the save repair), 40 x Lv^1.5", "")
	check(C.CraftXPToNext(1) == 40 and C.CraftXPToNext(2) == 113 and C.CraftXPToNext(29) == 6246 and C.CraftXPToNext(30) == 0
		and C.CraftXPToNext(0) == 40, "XP to next: Lv1 40, Lv2 113, Lv29 6246, Lv30 none", show({ C.CraftXPToNext(1), C.CraftXPToNext(2), C.CraftXPToNext(29) }))
	check(K.Hammer == nil and C.CraftGrade == nil and C.CraftPlus == nil, "no hammer numbers in Config (one place: Shared/CraftMini)", "")
	local M = execute("CraftMini", CRAFTMINI_SOURCE, nativeEnv())
	check(M.T.Strikes == 5 and M.T.Ring == 1.2 and M.T.Rest == 0.35 and M.T.Lead == 0.8 and M.T.Timeout == 20,
		"the shared hammer (CraftMini.T): 5 rings of 1.2 s, 0.35 s rest, 0.8 s lead, 20 s time-up", show(M.T))
	check(K.Range == 12 and K.StartsPerMinute == 6 and C.RateLimits.CraftStart == 3, "12 studs, 6 starts a minute, one start every 3 s", "")
	-- A23-217 (artisan_weekly_r1 §2): XP = the target minutes x 4 (W2 5 / W3 12 / W4 30 / W5 75 / W6 180 / W7 450 / W9 1,125)
	local want = { W2 = { 2, 1, 40, 20 }, W3 = { 3, 5, 200, 48 }, W4 = { 4, 10, 750, 120 }, W5 = { 5, 15, 2500, 300 },
		W6 = { 6, 20, 7500, 720 }, W7 = { 7, 25, 22500, 1800 }, W9 = { 9, 30, 60000, 4500 } }
	local smithRows = 0
	for _, r in K.Recipes do if r.Role == "Smith" and r.Kind == "Weapon" then smithRows += 1 end end
	check(smithRows == 7 and K.Recipes.W1 == nil, "seven blacksmith weapon recipes (장인 ②: no W1, tier 1 is the free class weapon)", tostring(smithRows))
	check(K.Recipes.W2.Mats.Herb == 3 and K.Recipes.W2.Mats.CopperOre == 2 and K.Recipes.W2.Mats.Jelly == nil,
		"W2 = the first craft from N0's harvest only (3 herbs + 2 copper)", show(K.Recipes.W2.Mats))
	-- ⑥ gear rows (게임성 개발 3): Armor / Ring (Smith, Lv 8 / 16 / 24), PetArmor / PetAcc (Tame, Lv 5 / 12 / 20), Kind Gear,
	-- materials that exist; the recipes wait for Config.Features.Gear
	local gearWant = { G1 = { "Smith", "Armor", 1, 8 }, G2 = { "Smith", "Armor", 2, 16 }, G3 = { "Smith", "Armor", 3, 24 },
		R1 = { "Smith", "Ring", 1, 8 }, R2 = { "Smith", "Ring", 2, 16 }, R3 = { "Smith", "Ring", 3, 24 },
		PA1 = { "Tame", "PetArmor", 1, 5 }, PA2 = { "Tame", "PetArmor", 2, 12 }, PA3 = { "Tame", "PetArmor", 3, 20 },
		PC1 = { "Tame", "PetAcc", 1, 5 }, PC2 = { "Tame", "PetAcc", 2, 12 }, PC3 = { "Tame", "PetAcc", 3, 20 } }
	for id, x in gearWant do
		local r = K.Recipes[id]
		local mats = r ~= nil
		for item in (r and r.Mats or {}) do
			if not C.Loot.Items[item] then mats = false end
		end
		check(r and r.Role == x[1] and r.Kind == "Gear" and r.Slot == x[2] and r.Tier == x[3] and r.Lv == x[4] and mats,
			"gear recipe: role / slot / tier / craft Lv as the design, every material is a known item", id .. " " .. show(r))
	end
	local gearOff = cWorld()
	local gearOn = cWorld({ EditConfig = function(c) c.Features.Gear = true end })
	check(gearOff.C.RecipeOn("G1") == nil and gearOn.C.RecipeOn("G1") ~= nil, "a gear recipe is on only while Config.Features.Gear is", "")
	for id, x in want do
		local r = K.Recipes[id]
		check(r and r.Role == "Smith" and r.Kind == "Weapon" and r.Tier == x[1] and r.Lv == x[2] and r.Gold == x[3] and r.XP == x[4],
			"recipe tier / craft Lv / gold / XP as the design table", id .. " " .. show(r))
	end
	check(K.Recipes.W2.Mats.CopperOre == 2 and K.Recipes.W4.Mats.IronOre == 16 and K.Recipes.W6.Mats.SilverOre == 40
		and K.Recipes.W9.Mats.MoonCrystal == 160 and K.Recipes.W3.Mats.SeaShell == nil and K.Recipes.W5.Mats.CrystalShard == nil,
		"gathered ores in the ladder (copper, iron, silver, moon crystal); no Sea Shell / Crystal Shard (one new zone only)", "")
	for _, key in { "NotArtisan", "NeedLevel", "NeedMats", "NeedGold", "Far", "Busy", "Full", "Auto" } do
		check(type(K.Text[key]) == "string" and K.Text[key] ~= "", "a short text for every refusal", key)
	end
end)

------------------------------------------------------------------ which recipes are on
runGroup("recipes", function()
	local w = cWorld()
	local on = {}
	for id in w.Config.Craft.Recipes do if w.C.RecipeOn(id) then on[id] = true end end
	-- C1 (게임성 개발 2): Clatter Gem / Royal Jelly are items and tier 9 exists, so W7 / W9 are on too
	check(on.W1 and on.W2 and on.W3 and on.W4 and on.W5 and on.W6 and on.W7 and on.W9,
		"W1..W7 and W9 on (C1: Clatter Gem / Royal Jelly items + tier 9)", show(on))
	check(w.C.RecipeOn("Nope") == nil and w.C.RecipeOn(nil) == nil, "an unknown recipe is off", "")
	local n = cWorld({ NoSpare = true })
	check(n.C.RecipeOn("W1") == nil, "a LootService without AddSpare / SpareRoom: every weapon recipe is off", "")
	local p = smith(n, 1)
	local nf = #n.Notices
	check(n.C.TryStart(p, "W1") == "recipe" and keysFor(n, p, nf)[1] == "Config.Craft.Text.NotReady", "... and refused with NotReady (a key)", "")
	local nf2 = #n.Notices
	check(n.C.TryStart(p, "Nope") == "recipe" and #keysFor(n, p, nf2) == 0, "an unknown recipe id: refused without a word", "")
	local gem = cWorld({ EditConfig = function(c)
		c.Loot.Items.ClatterGem = { Kind = "Material", Name = "Old Crown Gem", Sell = 400, Icon = "IconClatterGem" }
		c.Loot.Items.KingJelly = { Kind = "Material", Name = "Royal Jelly", Sell = 60, Icon = "IconKingJelly" }
		c.Weapons[9] = { Damage = 2200, MinLevel = 50 } -- T9 (게임성 개발 2 C1)
	end })
	check(gem.C.RecipeOn("W7") ~= nil and gem.C.RecipeOn("W9") ~= nil, "the new drops (and T9) switch W7 / W9 on by themselves", "")
	local nogem = cWorld({ EditConfig = function(c) c.Loot.Items.ClatterGem = nil end })
	check(nogem.C.RecipeOn("W6") == nil and nogem.C.RecipeOn("W7") == nil and nogem.C.RecipeOn("W9") == nil and nogem.C.RecipeOn("W5") ~= nil,
		"without the Clatter Gem item W6 / W7 / W9 are off again (A23-215: W6 needs a gem too; the item check stays)", "")
	local noshard = cWorld({ EditConfig = function(c) c.Loot.Items.DeepMoonShard = nil end })
	check(noshard.C.RecipeOn("W6") == nil and noshard.C.RecipeOn("G3") == nil and noshard.C.RecipeOn("W5") ~= nil,
		"A23-215: without the Deep Moon Shard item its recipes (W6.., G3 ..) are off", "")
	local KR = w.Config.Craft.Recipes
	local w6 = KR.W6.Mats
	local w9 = KR.W9.Mats
	check(w6.CaptainBadge == nil and KR.W7.Mats.CaptainBadge == nil and w9.CaptainBadge == nil and w6.DeepMoonShard == 12
		and KR.W7.Mats.DeepMoonShard == 48 and KR.W7.Mats.TrialCore == 4 and w9.DeepMoonShard == 120 and w9.TrialCore == 10
		and w9.ClatterGem == 8 and w9.KingJelly == 10,
		"A23-215: no Captain's Badge in W6 / W7 / W9; deep shards 4 / 16 / 40, trial cores 4 / 10, W9 8 gems + 10 royal jelly", show(w9))
	local gp = smith(nogem, 8)
	startAndHammer(nogem, gp, HONEST)
	local ginfo = last(fired(nogem, "CraftInfo", gp))
	check(ginfo and type(ginfo.On) == "table" and table.concat(ginfo.On, ",") == "W1,W2,W3,W4,W5",
		"CraftInfo.On leaves out the recipes that are off (no Clatter Gem: no W6 / W7 / W9)", ginfo and show(ginfo.On) or "")
	-- C1: LootService's real AddSpare / SpareRoom (no doubles)
	local real = cWorld({ RealSpare = true })
	check(real.C.RecipeOn("W1") ~= nil and real.C.RecipeOn("W9") ~= nil, "the real LootService.AddSpare / SpareRoom switch the weapon recipes on", "")
	local rp, rd = smith(real, 7)
	check(startAndHammer(real, rp, HONEST) == "ok" and type(rd.Spares) == "table" and rd.Spares["1:2"] == 1,
		"a real W1 craft lands in data.Spares['1:2'] (LootService.AddSpare)", show(rd.Spares))
end)

------------------------------------------------------------------ start
runGroup("start", function()
	local off = cWorld({ Off = true })
	local p0 = smith(off, 1)
	check(off.C.TryStart(p0, "W1") == "off", "switch off: off", "")

	local w = cWorld()
	local knight, dk = smith(w, 2, nil, "Warrior", "Halo")
	local from = #w.Notices
	check(w.C.TryStart(knight, "W1") == "role" and keysFor(w, knight, from)[1] == "Config.Craft.Text.NotArtisan",
		"a Knight cannot craft (NotArtisan, a key)", "")
	local alch = smith(w, 3, nil, "Mage")
	check(w.C.TryStart(alch, "W1") == "role", "an alchemist cannot make blacksmith recipes", "")
	local p, d = smith(w, 4)
	rootOf(p).Position = vec(12.5, 0, 0)
	check(w.C.TryStart(p, "W1") == "far", "12.5 studs from the anvil: far", "")
	rootOf(p).Position = vec(11.9, 0, 0)
	check(w.C.TryStart(p, "W3") == "level", "W3 needs craft Lv5: level", "")
	d.Items.CopperOre = 1
	check(w.C.TryStart(p, "W1") == "mats", "1 copper of 2: mats", "")
	d.Items.CopperOre = 80
	d.BankGold, d.CarriedGold = 9, 0
	check(w.C.TryStart(p, "W1") == "gold", "9 gold of 10: gold", "")
	d.BankGold = 100
	w.SpareFull = true
	check(w.C.TryStart(p, "W1") == "full" and d.Items.Jelly == 200 and d.BankGold == 100, "no spare room: full, nothing taken", "")
	w.SpareFull = false
	p:SetAttribute("AutoCombatUnlocked", true)
	p:SetAttribute("AutoCombatEnabled", true)
	check(w.C.TryStart(p, "W1") == "auto", "auto combat on: refused", "")
	p:SetAttribute("AutoCombatEnabled", false)
	check(w.C.TryStart(p, "W1") == "ok", "everything there: ok", "")
	check(d.BankGold == 90 and d.Items.Jelly == 195 and d.Items.CopperOre == 78 and w.Spent[1].Why == "Craft",
		"the gold (source Craft) and the materials go at the start", show({ d.BankGold, d.Items.Jelly, d.Items.CopperOre }))
	check(type(d.Craft.Pend) == "table" and d.Craft.Pend.Id == "W1" and d.Craft.Pend.Gold == 10, "the save remembers the craft (Craft.Pend)", show(d.Craft.Pend))
	local s = last(fired(w, "CraftSession", p))
	check(s and s.Recipe == "W1" and s.Strikes == 5 and s.Ring == 1.2 and s.Rest == 0.35 and s.StartAt == serverNow(w) + 0.8,
		"CraftSession { Id, Recipe, Strikes 5, Ring 1.2, Rest 0.35, StartAt = server time + 0.8 }", show(s))
	check(w.C.TryStart(p, "W2") == "busy", "a second start while one is open: busy", "")
	-- the workbench tag beats the anvil
	local bench = newInstance("Part", w)
	bench.Position = vec(500, 0, 0)
	bench.Attrs.Role = "Smith"
	table.insert(w.Tagged.CraftStation, bench)
	local q = smith(w, 5)
	check(w.C.TryStart(q, "W1") == "far", "a tagged workbench for my role replaces the anvil (the anvil is far now)", "")
	rootOf(q).Position = vec(505, 0, 0)
	check(w.C.TryStart(q, "W1") == "ok", "next to my workbench: ok", "")
	-- six a minute
	local m = cWorld()
	local r = smith(m, 6)
	local okCount = 0
	for _ = 1, 6 do
		if startAndHammer(m, r, HONEST) == "ok" then okCount += 1 end
	end
	check(okCount == 6 and m.C.TryStart(r, "W1") == "minute", "six crafts in a minute, the seventh waits", tostring(okCount))
	m:Advance(61)
	check(m.C.TryStart(r, "W1") == "ok", "a minute later: ok", "")
end)

------------------------------------------------------------------ the hammer
runGroup("hammer", function()
	local w = cWorld()
	local p, d = smith(w, 1)
	local r = startAndHammer(w, p, HONEST)
	local res = last(fired(w, "CraftResult", p))
	check(r == "ok" and res.Plus == 2 and res.Recipe == "W1" and res.Kind == "Weapon" and res.Tier == 1 and res.XP == 10 and res.Lv == 1
		and res.LvUp == false, "five Perfects: +2; CraftResult { Recipe, Kind, Tier, Plus, XP, Lv, LvUp }", show(res))
	check(#res.Grades == 5 and res.Grades[1] == "Perfect" and res.Grades[5] == "Perfect", "Grades x5", show(res.Grades))
	check(#w.Spares == 1 and w.Spares[1].Tier == 1 and w.Spares[1].Plus == 2, "the weapon goes to the spares (AddSpare 1, +2)", "")
	check(d.Craft.Pend == nil and d.Craft.Made.W1 == 1 and d.Craft.Smith.XP == 10, "Pend cleared, Made.W1 = 1, 10 craft XP", show(d.Craft))
	local info = last(fired(w, "CraftInfo", p))
	check(info and type(info.On) == "table" and table.concat(info.On, ",") == "W1,W2,W3,W4,W5,W6,W7,W9",
		"CraftInfo.On = the blacksmith recipes the server would start now (C1: W7 / W9 too)", info and show(info.On) or "")
	check(info and info.Role == "Smith" and info.Lv == 1 and info.XP == 10 and info.Need == 40 and info.Made.W1 == 1,
		"CraftInfo { Role, Lv, XP, Need, Made } after the craft", show(info))
	check(#w.Crafted == 1 and w.Crafted[1].Id == "W1" and w.Crafted[1].Plus == 2, "Crafted(player, W1, 2)", "")
	local sd = nil
	for _, e in w.Tele do if e.Name == "CraftStrikeD" and e.P == p then sd = e end end
	check(sd and sd.V == 50 and sd.A == 50 and sd.B == 5,
		"CraftStrikeD logged per craft: the biggest / smallest (server ms - client ms) and how many strikes (50 / 50 / 5 at ping 0.1)",
		sd and string.format("%s %s %s", tostring(sd.V), tostring(sd.A), tostring(sd.B)) or "none")

	startAndHammer(w, p, { 40, 150, 220, false, 45 })
	res = last(fired(w, "CraftResult", p))
	check(res.Plus == 1 and res.Grades[2] == "Great" and res.Grades[3] == "Good" and res.Grades[4] == "Miss",
		"Perfect, Great, Good, (no press) Miss, Perfect = 9 points: +1", show(res.Grades))
	startAndHammer(w, p, { 40, 150, 220, false, false })
	check(last(fired(w, "CraftResult", p)).Plus == 0, "6 points: +0 (still made, nothing lost)", "")
	check(w.C.TryStart(p, "W1") == "ok" and w.C.Finish(p, last(fired(w, "CraftSession", p)).Id) == "ok"
		and last(fired(w, "CraftResult", p)).Plus == 0, "Skip (Finish right away): +0, made", "")

	-- a script that presses whenever and claims good numbers: the arrival gives it away
	local liar, dl = smith(w, 2)
	local before = #w.Tele
	startAndHammer(w, liar, { 700, 700, 700, 700, 700 }, { Claim = HONEST })
	res = last(fired(w, "CraftResult", liar))
	check(res.Plus == 0 and res.Grades[1] == "Miss" and res.Grades[5] == "Miss", "claims ~700 ms off the arrival: all Miss, +0", show(res.Grades))
	local mm = 0
	for i = before + 1, #w.Tele do if w.Tele[i].Name == "CraftMismatch" then mm = w.Tele[i].V end end
	check(mm == 5, "CraftMismatch logged (5)", tostring(mm))
	check(dl.Craft.Made.W1 == 1, "the liar still gets the +0 item (nothing lost)", "")

	-- the window (ping 0.1 s: the arrival is 50 ms late; server - client may be -50 .. 250 + 1.5 x 100 ms)
	local function one(id, actual, claim)
		local x = smith(w, id)
		local offs, cl = { 30, 50, 40, 20, 60 }, { 30, 50, 40, 20, 60 }
		offs[2], cl[2] = actual, claim
		startAndHammer(w, x, offs, { Claim = cl })
		return last(fired(w, "CraftResult", x)).Grades[2]
	end
	check(one(3, 385, 40) == "Perfect", "395 ms later than claimed (inside 400): kept", "")
	check(one(4, 395, 40) == "Miss", "405 ms later than claimed: Miss", "")
	check(one(5, -50, 45) == "Perfect", "45 ms earlier than claimed (inside 50): kept", "")
	check(one(6, -60, 45) == "Miss", "55 ms earlier than claimed: Miss", "")
	local slow = smith(w, 10)
	w.Ping = 0
	startAndHammer(w, slow, { 30, 260, 40, 20, 60 }, { Claim = { 30, 0, 40, 20, 60 } })
	w.Ping = 0.1
	check(last(fired(w, "CraftResult", slow)).Grades[2] == "Miss", "with no ping the window is 250 ms (260 off: Miss)", "")
	-- the ping that counts is the biggest of the session start's, the strike's and now (CraftMini.Ping, 게임성 검수)
	local function pingCase(id, startPing, strikePing, endPing)
		local x = smith(w, id)
		w.Ping = startPing
		w.C.TryStart(x, "W1")
		local s = last(fired(w, "CraftSession", x))
		local actual, claim = { 30, 300, 40, 20, 60 }, { 30, 0, 40, 20, 60 }
		for i = 1, 5 do
			w:Advance(w.Mini.Target(s.StartAt, i) + actual[i] / 1000 - serverNow(w))
			w.Ping = i == 2 and strikePing or 0
			w.C.Strike(x, s.Id, i, claim[i])
		end
		w.Ping = endPing
		w.C.Finish(x, s.Id)
		w.Ping = 0.1
		return last(fired(w, "CraftResult", x)).Grades[2]
	end
	check(pingCase(11, 0.3, 0, 0) == "Perfect", "a 300 ms ping at the session start widens the window at the end (300 ms off: kept)", "")
	check(pingCase(12, 0, 0.3, 0) == "Perfect", "a 300 ms ping when the strike came counts", "")
	check(pingCase(13, 0, 0, 0.3) == "Perfect", "a 300 ms ping at the Finish counts", "")
	check(pingCase(14, 0, 0, 0) == "Miss", "no ping anywhere: 300 ms off is a Miss", "")

	-- strikes the server never got, rings, repeats, bad ms
	local sk = smith(w, 7)
	startAndHammer(w, sk, HONEST, { Skip = { [3] = true } })
	local g = last(fired(w, "CraftResult", sk)).Grades
	check(g[3] == "Miss" and g[4] == "Perfect" and g[5] == "Perfect", "a press the server never got is a Miss (the next ones still count)", show(g))
	local o = smith(w, 8)
	check(w.C.TryStart(o, "W1") == "ok", "start", "")
	local sess = last(fired(w, "CraftSession", o))
	w:Advance(w.Mini.Target(sess.StartAt, 1) + 0.08 - serverNow(w))
	check(w.C.Strike(o, sess.Id + 1, 1, 30) == "session", "another session's id: refused", "")
	check(w.C.Strike(o, sess.Id, 0, 30) == "ring" and w.C.Strike(o, sess.Id, 6, 30) == "ring" and w.C.Strike(o, sess.Id, 1.5, 30) == "ring",
		"ring 0 / 6 / 1.5: refused", "")
	check(w.C.Strike(o, sess.Id, 1, "30") == "ms" and w.C.Strike(o, sess.Id, 1, 0 / 0) == "ms", "a text or NaN offset: refused", "")
	check(w.C.Strike(o, sess.Id, 1, 401) == "ms" and w.C.Strike(o, sess.Id, 1, -401) == "ms" and w.C.Session(o).Strikes[1] == nil,
		"an offset beyond 400 ms: refused (CraftMini.T.MaxMs; the ring stays open)", "")
	check(w.C.Strike(o, sess.Id, 1, 30) == "ok" and w.C.Strike(o, sess.Id, 1, -400) == "again", "one strike a ring (the first stays)", "")
	check(w.C.Session(o).Strikes[1].Ms == 30 and w.C.Session(o).Strikes[1].At == serverNow(w), "the strike notes { Ms, At = server time }", "")
	check(w.C.Finish(o, sess.Id + 1) == "session" and w.C.Finish(o, sess.Id) == "ok" and w.C.Finish(o, sess.Id) == "session",
		"Finish: the right id only, once", "")
	-- five equal offsets: not a person
	local bot = smith(w, 9)
	local tb = #w.Tele
	startAndHammer(w, bot, { 40, 40, 40, 40, 40 })
	local botLog = false
	for i = tb + 1, #w.Tele do if w.Tele[i].Name == "CraftBot" then botLog = true end end
	check(last(fired(w, "CraftResult", bot)).Plus == 0 and botLog, "five equal offsets (even on time): +0 and CraftBot", "")
end)

------------------------------------------------------------------ the ends without a finish
runGroup("ends", function()
	local w = cWorld()
	local p, d = smith(w, 1, { Items = (function() local t = table.clone(MATS); t.Herb = 50; return t end)() }) -- 장인 ②: W2 takes herbs
	w.C.TryStart(p, "W2")
	check(type(d.Craft.Pend) == "table" and d.Craft.Pend.Id == "W2" and d.Craft.Pend.Plus == -1 and d.Craft.Pend.Gold == 40
		and d.Craft.Pend.Mats.Herb == 3 and d.Craft.Pend.Mats.CopperOre == 2, "the save keeps what was paid: Pend { Id, Plus -1, Gold, Mats }",
		show(d.Craft.Pend))
	w:Advance(0.8 + 20 + 0.1)
	check(d.Craft.Pend == nil and d.Craft.Made.W2 == 1 and last(w.Spares).Tier == 2 and last(w.Spares).Plus == 0
		and w.C.Session(p) == nil, "no Finish by StartAt + 20 s: made at +0", show(d.Craft))
	local q, dq = smith(w, 2)
	w.C.TryStart(q, "W1")
	w:Leave(q)
	check(dq.Craft.Pend == nil and dq.Craft.Made.W1 == 1, "a leave mid-craft: made at +0 before the save goes", show(dq.Craft))
	local k, dk = smith(w, 3)
	w.C.TryStart(k, "W1")
	w.Reg.PlayerService.CharacterDied:Fire(k)
	check(dk.Craft.Pend == nil and dk.Craft.Made.W1 == 1, "a KO mid-craft: made at +0", "")
	local function craftWith(pend)
		return { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {}, Pend = pend }
	end
	-- a craft the server stopped in the middle of
	local j, dj = smith(w, 4, { Craft = craftWith({ Id = "W2", Plus = -1, Gold = 40, Mats = { Jelly = 10 } }) })
	check(dj.Craft.Pend == nil and dj.Craft.Made.W2 == 1 and last(w.Spares).P == j and last(w.Spares).Plus == 0,
		"a join with a never-hammered W2 finishes it at +0 (paid already)", show(dj.Craft))
	local h, dh = smith(w, 7, { Craft = craftWith({ Id = "W2", Plus = 2, Gold = 40, Mats = { Jelly = 10 } }) })
	check(dh.Craft.Pend == nil and last(w.Spares).P == h and last(w.Spares).Plus == 2, "an earned +2 waiting in the save comes as +2", "")
	-- a recipe gone by now: everything paid comes back
	local u, du = smith(w, 5, { BankGold = 1000, Craft = craftWith({ Id = "Nope", Plus = 1, Gold = 123, Mats = { Jelly = 7, CopperOre = 150 } }) })
	check(du.Craft.Pend == nil and count(du.Craft.Made) == 0 and du.BankGold == 1123 and du.Items.Jelly == 200 + 7
		and du.Items.CopperOre == 80 + 150, "an unknown recipe pays back the gold and every material (150 in two parts)", show({ du.BankGold, du.Items.Jelly, du.Items.CopperOre }))
	local refundGold = nil
	for _, g in w.Gold do if g.P == u then refundGold = g end end
	check(refundGold and refundGold.Src == "CraftRefund", "the gold comes back as CraftRefund (never doubled by a pass)", "")
	-- the result does not fit at the join: it waits, with its +N
	w.SpareFull = true
	local f, df = smith(w, 6, { Craft = craftWith({ Id = "W1", Plus = 2, Gold = 10, Mats = { Jelly = 5 } }) })
	check(type(df.Craft.Pend) == "table" and df.Craft.Pend.Plus == 2 and keysFor(w, f)[1] == "Config.Craft.Text.Full",
		"no room at the join: it stays pending with its +2 (Full notice)", show(df.Craft.Pend))
	check(w.C.TryStart(f, "W1") == "busy", "... and a new craft waits", "")
	w.SpareFull = false
	w:Advance(4)
	check(w.C.TryStart(f, "W1") == "ok" and df.Craft.Made.W1 == 1 and last(w.Spares).P == f and last(w.Spares).Plus == 2,
		"room again: the waiting one is made first at its +2, then the new one starts", show(df.Craft))
	-- the spares fill up during the hammer: the earned +2 is kept, never lost
	local g, dg = smith(w, 8)
	check(w.C.TryStart(g, "W1") == "ok", "start", "")
	w.SpareFull = true
	hammer(w, g, HONEST)
	check(type(dg.Craft.Pend) == "table" and dg.Craft.Pend.Plus == 2 and dg.Craft.Made.W1 == nil, "full at the Finish: +2 earned and kept in the save", show(dg.Craft.Pend))
	w.SpareFull = false
	w:Advance(61)
	check(w.C.TryStart(g, "W1") == "ok" and last(w.Spares).P == g and last(w.Spares).Plus == 2, "the next start pays the +2 first", "")
end)

------------------------------------------------------------------ switched off: nothing written at a join
runGroup("off", function()
	local w = cWorld({ Off = true })
	local pend = { Id = "W1", Plus = 1, Gold = 10, Mats = { Jelly = 5 } }
	local p, d = smith(w, 1, { Craft = { Smith = { Lv = 3, XP = 7 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {}, Pend = deepCopy(pend) } })
	check(type(d.Craft.Pend) == "table" and d.Craft.Pend.Plus == 1 and d.Craft.Pend.Id == "W1" and #w.Spares == 0
		and #fired(w, "CraftInfo", p) == 0, "switch off: a waiting craft is left as it is, no CraftInfo", show(d.Craft.Pend))
	local q, dq = smith(w, 2)
	check(dq.Craft.Pend == nil and dq.Craft.Smith.Lv == 1, "switch off: a save without a craft gets nothing written", show(dq.Craft))
end)

------------------------------------------------------------------ gear / item results: all or nothing (rows come with ⑥ / ④)
runGroup("results", function()
	local w = cWorld({ EditConfig = function(c)
		c.Craft.Recipes.T1 = { Role = "Smith", Kind = "Item", Item = "Jelly", N = 3, Lv = 1, Gold = 1, Mats = { CopperOre = 1 }, XP = 1 }
		c.Craft.Recipes.G1 = { Role = "Smith", Kind = "Gear", Slot = "Armor", Tier = 1, Lv = 1, Gold = 1, Mats = { CopperOre = 1 }, XP = 1 }
		c.Features.Gear = true -- ⑥: a gear recipe is on only while the gear switch is
		c.Craft.Recipes.T2 = { Role = "Smith", Kind = "Item", Item = "Herb", N = 1, Lv = 1, Gold = 1, Mats = { CopperOre = 2 }, XP = 1 }
	end })
	local p, d = smith(w, 1)
	d.Items.Jelly = 990
	check(w.C.TryStart(p, "T1") == "ok", "an item recipe starts with room for 3 + the best +2", "")
	d.Items.Jelly = 998
	hammer(w, p, HONEST)
	check(d.Items.Jelly == 998 and type(d.Craft.Pend) == "table" and d.Craft.Pend.Id == "T1", "only 1 of 5 would fit: nothing given, it waits", show(d.Items.Jelly))
	d.Items.Jelly = 10
	w:Advance(61)
	w.C.Settle(p, d)
	check(d.Items.Jelly == 15 and d.Craft.Pend == nil, "room again: all of it at once (3 + the earned +2 = 5)", tostring(d.Items.Jelly))
	local q, dq = smith(w, 2)
	dq.Gear = { Own = { ["Ring:1:0"] = 20, ["Ring:2:0"] = 20, ["Ring:3:0"] = 19 }, On = { Armor = "", Ring = "" }, Pet = {} }
	check(w.C.TryStart(q, "G1") == "ok", "a gear recipe starts with 59 of 60 things", "")
	dq.Gear.Own["Ring:3:0"] = 20
	hammer(w, q, HONEST)
	check(dq.Gear.Own["Armor:1:2"] == nil and type(dq.Craft.Pend) == "table", "60 of 60 at the Finish: no 61st thing, it waits", show(dq.Gear.Own))
	dq.Gear.Own["Ring:3:0"] = 10
	w.C.Settle(q, dq)
	check(dq.Gear.Own["Armor:1:2"] == 1 and dq.Craft.Pend == nil, "room again: the armor +2 goes in", show(dq.Gear.Own))
	local r, dr = smith(w, 3)
	dr.Gear = { Own = { ["Armor:1:0"] = 19 }, On = { Armor = "", Ring = "" }, Pet = {} }
	check(w.C.TryStart(r, "G1") == "ok", "start", "")
	dr.Gear.Own["Armor:1:0"] = 20
	w.C.Finish(r, last(fired(w, "CraftSession", r)).Id)
	check(dr.Gear.Own["Armor:1:0"] == 20 and type(dr.Craft.Pend) == "table", "a full key (20) at the Finish: no 21st, it waits", show(dr.Gear.Own))
	-- bag slots (10/14): a result of a new kind needs a free slot, checked before anything is taken
	local b, db = smith(w, 4, { BagSlots = 13 })
	check(w.C.TryStart(b, "T2") == "full" and db.Items.CopperOre == 80 and db.Items.Herb == nil,
		"13 kinds in 13 slots: a new kind (Herb) is refused, nothing taken", show({ db.Items.CopperOre, db.Items.Herb }))
	check(w.C.TryStart(b, "T1") == "ok", "... a kind already held (Jelly) still crafts", "")
	local c2, dc2 = smith(w, 5, { BagSlots = 13 })
	dc2.Items.CopperOre = 2
	check(w.C.TryStart(c2, "T2") == "ok" and (dc2.Items.CopperOre or 0) == 0, "the last 2 copper go into it: that slot frees, Herb fits", show(dc2.Items))
	local e2, de2 = smith(w, 6, { BagSlots = 14 })
	check(w.C.TryStart(e2, "T2") == "ok", "one free slot: Herb fits", "")
end)

------------------------------------------------------------------ A23-206 / A23-213 bound materials (user 10/16)
-- every craft (weapons too) may use bound materials, the bound ones first; the result is free (it trades / sells); the
-- materials stay bound themselves: a refund gives the bound part back bound
runGroup("bound materials", function()
	local w = cWorld({ EditConfig = function(c)
		c.Craft.Recipes.T1 = { Role = "Smith", Kind = "Item", Item = "Jelly", N = 3, Lv = 1, Gold = 1, Mats = { CopperOre = 1 }, XP = 1 }
	end })
	local p, d = smith(w, 1, { ItemsBound = { CopperOre = 1 } })
	check(w.C.TryStart(p, "T1") == "ok" and d.Craft.Pend.Bound.CopperOre == 1 and (d.ItemsBound.CopperOre or 0) == 0,
		"an item craft takes the bound copper first and remembers it (Pend.Bound)", show(d.Craft.Pend))
	hammer(w, p, HONEST)
	check(d.Items.Jelly == 205 and (d.ItemsBound.Jelly or 0) == 0, "A23-213: the result (3 + the earned +2) made with a bound one is free",
		show({ d.Items.Jelly, d.ItemsBound }))
	check(w.Reg.LootService.TakeItem(p, "Jelly", 205, "Trade"), "... the market takes all 205 jelly", show({ d.Items.Jelly, d.ItemsBound }))
	local q, dq = smith(w, 2)
	w:Advance(61)
	check(w.C.TryStart(q, "T1") == "ok" and dq.Craft.Pend.Bound == nil, "free copper only: nothing remembered (the old Pend shape)", show(dq.Craft.Pend))
	hammer(w, q, HONEST)
	check(dq.Items.Jelly == 205 and (dq.ItemsBound or {}).Jelly == nil, "... and the result is free", show(dq.ItemsBound))
	-- a refund (the recipe is gone): the bound part comes back bound
	local craftWith = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {},
		Pend = { Id = "Nope", Plus = -1, Gold = 10, Mats = { Jelly = 7, CopperOre = 150 }, Bound = { CopperOre = 120 } } }
	local u, du = smith(w, 3, { Craft = craftWith })
	check(du.Craft.Pend == nil and du.Items.CopperOre == 80 + 150 and du.ItemsBound.CopperOre == 120 and (du.ItemsBound.Jelly or 0) == 0,
		"a refund: 150 copper back, the 120 that were bound stay bound (two rows of at most 99), the jelly free", show({ du.Items, du.ItemsBound }))
	local _ = u
	-- the save keeps Pend.Bound (and an old Pend without it reads as nothing bound)
	local san = w.Config.SanitizeCraft({ Pend = { Id = "T1", Plus = 1, Gold = 1, Mats = { CopperOre = 1 }, Bound = { CopperOre = 1, Bad = -3 } } })
	local old = w.Config.SanitizeCraft({ Pend = { Id = "T1", Plus = 1, Gold = 1, Mats = { CopperOre = 1 } } })
	check(san.Pend.Bound.CopperOre == 1 and san.Pend.Bound.Bad == nil and old.Pend.Bound == nil, "SanitizeCraft keeps Pend.Bound (none = no field)", show(san.Pend))
	-- a weapon craft too (A23-213): all copper bound - it starts, the bound ones go first
	local k, dk = smith(w, 4, { ItemsBound = { CopperOre = 80 } })
	check(w.C.TryStart(k, "W1") == "ok" and dk.Items.CopperOre == 78 and dk.ItemsBound.CopperOre == 78 and dk.Craft.Pend.Bound.CopperOre == 2,
		"W1 from 80 bound copper: starts, 2 bound ones used and noted", show({ dk.Items.CopperOre, dk.ItemsBound, dk.Craft.Pend }))
	local m, dm = smith(w, 5, { ItemsBound = { CopperOre = 1 } })
	check(w.C.TryStart(m, "W1") == "ok" and dm.Items.CopperOre == 78 and (dm.ItemsBound.CopperOre or 0) == 0 and dm.Craft.Pend.Bound.CopperOre == 1,
		"1 bound + free: the bound one goes first, then a free one", show({ dm.Items.CopperOre, dm.ItemsBound }))
	local _ = m
end)

------------------------------------------------------------------ 장인 ⑤ (A23-178): the alchemist's goods
runGroup("alchemist goods", function()
	local w = cWorld({ EditConfig = function(c)
		c.Craft.Recipes.APX = { Role = "Alch", Kind = "Potion", Potion = "Nope", N = 1, Lv = 1, Gold = 1, Mats = { Herb = 1 }, XP = 1 }
	end })
	local C0 = w.Config
	local K0 = C0.Craft.Recipes
	check(K0.AP1.Role == "Alch" and K0.AP1.Kind == "Potion" and K0.AP1.Potion == "HP" and K0.AP1.N == 2 and K0.AP1.Mats.Herb == 3
		and K0.AP1.Mats.Jelly == nil and K0.AP2.Potion == "MP" and K0.AS1.Kind == "Item" and K0.AS1.Item == "Enh70"
		and K0.AS1.Mats.Herb == 10 and K0.AS1.Mats.CopperOre == 8 and K0.AS1.Mats.SlimeCore == 2 and K0.AS1.Lv == 3,
		"Config: HP potions from 3 herbs (최종 검수 10/15), MP potions and the 70% scroll (Alch)", show({ K0.AP1, K0.AS1 }))
	check(w.C.RecipeOn("AP1") ~= nil and w.C.RecipeOn("AS1") ~= nil and w.C.RecipeOn("APX") == nil,
		"a Potion recipe is on only for a real potion (HP / MP)", "")
	local stock = { Herb = 40, Jelly = 20, CopperOre = 10, Petal = 10, SlimeCore = 4 }
	local p, d = smith(w, 11, { Items = deepCopy(stock) }, "Mage")
	local hp = C0.PotionStockKey("HP")
	local before = d[hp] or 0
	startAndHammer(w, p, HONEST, { Recipe = "AP1" })
	local res = last(fired(w, "CraftResult", p))
	check(res and res.Kind == "Potion" and res.Potion == "HP" and (d[hp] or 0) == before + 2 + res.Plus and p:GetAttribute(hp) == d[hp],
		"AP1: 2 HP potions + the hammer's +N into the stock (attribute too); CraftResult says Potion HP", show({ res, d[hp] }))
	check(d.Items.Herb == 37 and d.Items.Jelly == 20, "its materials went at the start (3 herbs, no jelly)", show(d.Items))
	-- the cap: no start when N + 2 would pass it
	w:Advance(61)
	d[hp] = C0.Vitals.PotionInventoryCap - 3
	check(w.C.TryStart(p, "AP1") == "full" and d.Items.Herb == 37, "near the potion cap: full, nothing taken", show(d.Items))
	d[hp] = 0
	-- the scroll waits for craft Lv3
	check(w.C.TryStart(p, "AS1") == "level", "the 70% scroll needs alchemy Lv3", "")
	d.Craft.Alch = { Lv = 3, XP = 0 }
	local enh = d.Items.Enh70 or 0
	startAndHammer(w, p, HONEST, { Recipe = "AS1" })
	local res2 = last(fired(w, "CraftResult", p))
	check(res2 and res2.Item == "Enh70" and (d.Items.Enh70 or 0) == enh + 1 + res2.Plus and d.Items.Herb == 27 and d.Items.CopperOre == 2
		and d.Items.SlimeCore == 2,
		"AS1 at Lv3: 70% scrolls (1 + the hammer's +N) from 10 herbs + 8 copper + 2 slime cores (A23-215)", show({ res2, d.Items }))
	-- a blacksmith cannot make them
	local s = smith(w, 12, { Items = deepCopy(stock) })
	check(w.C.TryStart(s, "AP1") == "role" and w.C.TryStart(s, "AS1") == "role", "a blacksmith cannot brew", "")
end)

------------------------------------------------------------------ 장인 ④ (최종 검수 10/14): the guild yard's three benches
runGroup("benches", function()
	local w = cWorld({ Benches = true })
	local B = w.Config.Craft.Benches
	check(B.Smith and B.Alch and B.Tame and B.Smith.Offset and B.Smith.Offset.X == 9, "Config.Craft.Benches: Smith / Alch / Tame spots by the anvil", "")
	local anvil = newInstance("Part", w)
	anvil.Name, anvil.Position = "Anvil", vec(40, 2, 50)
	local guild = newInstance("Model", w)
	guild.Name = "ArtisanGuild"
	anvil.Parent = guild
	w.Reg.ShopService = w.Reg.ShopService or {}
	w.Reg.ShopService.Anvil = function() return anvil end
	-- (Start already built benches around the world's own anvil: start this check from none)
	w.Tagged.CraftStation = {}
	-- a WorldKit bench of one role is there already
	local kit = newInstance("Part", w)
	kit.Attrs.Role = "Alch"
	table.insert(w.Tagged.CraftStation, kit)
	check(w.C.EnsureBenches() == true, "the anvil is there: done", "")
	local roles, prompts = {}, 0
	for _, part in w.Tagged.CraftStation do
		local role = part:GetAttribute("Role")
		roles[role] = (roles[role] or 0) + 1
		if part ~= kit and part:FindFirstChild("CraftPrompt") then prompts += 1 end
	end
	check(roles.Smith == 1 and roles.Tame == 1 and roles.Alch == 1, "one bench per role (the WorldKit Alch bench kept, no second)", show(roles))
	local smithBench = nil
	for _, part in w.Tagged.CraftStation do if part:GetAttribute("Role") == "Smith" then smithBench = part end end
	check(smithBench and smithBench.Name == "Workbench_Smith" and smithBench.Anchored == true and smithBench.Parent == guild
		and smithBench.Position.X == 40 + B.Smith.Offset.X and smithBench.Position.Z == 50 + B.Smith.Offset.Z and prompts == 2,
		"Workbench_Smith: anchored, in the guild model, beside the anvil, with its Craft prompt", show(smithBench and smithBench.Position))
	check(w.C.EnsureBenches() == true and #w.Tagged.CraftStation == 3, "a second run adds nothing", #w.Tagged.CraftStation)
	-- crafting off: benches without prompts; no anvil: nothing
	local off = cWorld({ Off = true, Benches = true })
	off.Reg.ShopService = off.Reg.ShopService or {}
	off.Reg.ShopService.Anvil = function() return anvil end
	off.Tagged.CraftStation = {}
	check(off.C.EnsureBenches() == true and #off.Tagged.CraftStation == 3, "Crafting off: the three benches still stand", #off.Tagged.CraftStation)
	local offPrompts = 0
	for _, part in off.Tagged.CraftStation do if part:FindFirstChild("CraftPrompt") then offPrompts += 1 end end
	check(offPrompts == 0, "Crafting off: no Craft prompt on them", offPrompts)
	-- the live switch: on = prompts, off = prompts gone, benches stay
	off.Config.Features.Crafting = true
	off.Reg.SwitchService.Changed:Fire("Crafting", true)
	local onPrompts = 0
	for _, part in off.Tagged.CraftStation do if part:FindFirstChild("CraftPrompt") then onPrompts += 1 end end
	check(onPrompts == 3, "switched on: each bench gets its Craft prompt", onPrompts)
	off.Config.Features.Crafting = false
	off.Reg.SwitchService.Changed:Fire("Crafting", false)
	local left = 0
	for _, part in off.Tagged.CraftStation do if part:FindFirstChild("CraftPrompt") then left += 1 end end
	check(left == 0 and #off.Tagged.CraftStation == 3, "switched off: prompts gone, benches stay", left)
	local none = cWorld({ Benches = true })
	none.Reg.ShopService = none.Reg.ShopService or {}
	none.Reg.ShopService.Anvil = function() return nil end
	none.Tagged.CraftStation = {}
	check(none.C.EnsureBenches() == false and #none.Tagged.CraftStation == 0, "no anvil yet: nothing (tried again later)", "")
	-- the built bench works: a blacksmith next to it may craft there
	local p = smith(w, 21, { Items = (function() local t = table.clone(MATS); t.Herb = 50; return t end)() }) -- W2 takes herbs (장인 ②)
	rootOf(p).Position = smithBench.Position
	check(w.C.TryStart(p, "W2") == "ok", "next to the new Smith bench: a craft starts", "")
end)

------------------------------------------------------------------ GPT review ① (10/14): a full bag and a recipe that uses its materials up
runGroup("full bag weapon", function()
	local w = cWorld({ RealSpare = true })
	local recipe = w.Config.Craft.Recipes.W2
	local function bagOf(extra)
		local items, n = table.clone(recipe.Mats), 0
		for _ in items do n += 1 end
		for k, v in extra or {} do items[k] = v end
		local ids = {}
		for id, def in w.Config.Loot.Items do
			if w.Config.BagSlots.Counts[def.Kind] and items[id] == nil then table.insert(ids, id) end
		end
		table.sort(ids)
		for _, id in ids do
			if n >= 12 then break end
			items[id] = 1
			n += 1
		end
		return items
	end
	local p, d = smith(w, 61, { Items = bagOf(), BagSlots = 12 })
	check(w.Config.BagUsed(d) == 12 and not w.Config.BagHasRoom(d), "(12 kinds in 12 slots, W2's materials exactly)", w.Config.BagUsed(d))
	check(w.C.TryStart(p, "W2") == "ok", "W2 uses its kinds up: their slots hold the spare it makes (12 -> 10)", "")
	local more = {}
	for id, n in recipe.Mats do more[id] = n + 5 end
	local q, e = smith(w, 62, { Items = bagOf(more), BagSlots = 12 })
	check(w.C.TryStart(q, "W2") == "full", "the same bag with more of each material: no slot frees, full", "")
end)

------------------------------------------------------------------ ⑤ (최종 검수 10/14): Crafting back on reads the players again
runGroup("switch back on", function()
	local w = cWorld()
	w.Config.LiveOff = { Crafting = true }
	local p, d = smith(w, 51, { Craft = { Pend = { Id = "W2", Plus = 1, Gold = 40, Mats = { CopperOre = 2 } } } })
	check(type(d.Craft.Pend) == "table" and next(w.Spares) == nil, "joined while Crafting was off: the waiting craft waits", show(d.Craft))
	w.Config.LiveOff = nil
	w.Reg.SwitchService.Changed:Fire("Gear", true)
	check(type(d.Craft.Pend) == "table", "another switch: nothing", "")
	w.Reg.SwitchService.Changed:Fire("Crafting", true)
	check(d.Craft.Pend == nil and next(w.Spares) ~= nil, "Crafting back on: the waiting craft is paid (W2 +1)", show(d.Craft))
end)

------------------------------------------------------------------ craft XP
runGroup("xp", function()
	local w = cWorld()
	local p, d = smith(w, 1, { Craft = { Smith = { Lv = 1, XP = 35 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {} } })
	startAndHammer(w, p, HONEST)
	local res = last(fired(w, "CraftResult", p))
	check(d.Craft.Smith.Lv == 2 and d.Craft.Smith.XP == 5 and res.LvUp == true and res.Lv == 2, "35 + 10 XP: Lv2 with 5 over", show(d.Craft.Smith))
	check(d.Craft.Alch.Lv == 1 and d.Craft.Alch.XP == 0, "only the blacksmith role grows", "")
	local big = cWorld({ EditConfig = function(c) c.Craft.Recipes.W1.XP = 200 end })
	local q, dq = smith(big, 2)
	startAndHammer(big, q, HONEST)
	check(dq.Craft.Smith.Lv == 3 and dq.Craft.Smith.XP == 47, "200 XP from Lv1: 40 + 113 used, Lv3 with 47", show(dq.Craft.Smith))
	local top, dt = smith(w, 3, { Craft = { Smith = { Lv = 30, XP = 100 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {} } })
	w:Advance(61)
	startAndHammer(w, top, HONEST)
	check(dt.Craft.Smith.Lv == 30 and dt.Craft.Smith.XP == 110, "Lv30 stays 30", show(dt.Craft.Smith))
	-- A23-139 (user 10/12): the 2x XP pass doubles craft XP too; the faction / rebirth XP bonuses never touch it
	local pw = cWorld()
	local x, dx = smith(pw, 4)
	pw.PassXP2[x] = true
	startAndHammer(pw, x, HONEST)
	check(dx.Craft.Smith.XP == 20 and last(fired(pw, "CraftResult", x)).XP == 20, "with the 2x XP pass: 10 craft XP -> 20 (shown in CraftResult)",
		tostring(dx.Craft.Smith.XP))
	local y, dy = smith(pw, 5)
	startAndHammer(pw, y, HONEST)
	check(dy.Craft.Smith.XP == 10 and last(fired(pw, "CraftResult", y)).XP == 10, "without the pass: 10", tostring(dy.Craft.Smith.XP))
	local bonus = cWorld({ XPMult = 2 })
	local z, dz = smith(bonus, 6)
	startAndHammer(bonus, z, HONEST)
	check(dz.Craft.Smith.XP == 10, "a hunting XP bonus (faction / rebirth) never doubles craft XP", tostring(dz.Craft.Smith.XP))
	-- A23-139: craft XP only for an artisan of that role now (a pending craft after a side change pays the item, no XP)
	local h, dh = smith(pw, 7, { Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {},
		Pend = { Id = "W2", Plus = 1, Gold = 40, Mats = { Jelly = 10 } } } }, "Warrior", "Halo")
	check(dh.Craft.Pend == nil and last(pw.Spares).P == h and last(pw.Spares).Plus == 1 and dh.Craft.Smith.XP == 0
		and last(fired(pw, "CraftResult", h)).XP == 0, "a Knight's waiting craft: the item comes, no craft XP", show(dh.Craft.Smith))
	local m, dm = smith(pw, 8, { Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {},
		Pend = { Id = "W2", Plus = 0, Gold = 40, Mats = { Jelly = 10 } } } }, "Mage")
	check(dm.Craft.Pend == nil and dm.Craft.Smith.XP == 0 and dm.Craft.Alch.XP == 0, "an alchemist finishing an old blacksmith craft: no XP for either role", "")
end)

------------------------------------------------------------------ remotes
runGroup("remotes", function()
	local w = cWorld()
	local p, d = smith(w, 1)
	w.Gap = 3.1
	w:Remote("CraftStart", p, "W1", "x")
	check(#fired(w, "CraftSession", p) == 0, "CraftStart with two arguments: ignored", "")
	w:Remote("CraftStart", p, 5)
	check(#fired(w, "CraftSession", p) == 0, "CraftStart with a number: ignored", "")
	w:Remote("CraftStart", p, "W1")
	local sess = last(fired(w, "CraftSession", p))
	check(sess ~= nil, "CraftStart(W1) opens a session", "")
	w.Gap = 0
	w:Remote("CraftStrike", p, sess.Id, 1)
	w:Remote("CraftStrike", p, tostring(sess.Id), 1, 40)
	check(w.C.Session(p).Strikes[1] == nil, "CraftStrike without its ms or with a text id: ignored", "")
	w:Remote("CraftFinish", p, sess.Id, "x")
	check(w.C.Session(p) ~= nil, "CraftFinish with two arguments: ignored (the session stays open)", "")
	w:Remote("CraftFinish", p, sess.Id + 7)
	w:Remote("CraftFinish", p, sess.Id)
	check(w.C.Session(p) == nil and last(fired(w, "CraftResult", p)).Plus == 0,
		"a wrong id's Finish does not use up the limit: the real CraftFinish(id) right after is taken (+0)", "")
	w.Gap = 3
	w:Remote("CraftStart", p, "W1")
	check(#fired(w, "CraftSession", p) == 2, "3 s later: a new session", "")
	local s2 = last(fired(w, "CraftSession", p))
	local before = #w.Notices
	w.Gap = 0.5
	w:Remote("CraftStart", p, "W2")
	check(#keysFor(w, p, before) == 0, "CraftStart again within 3 s: rate limited before any check (no Busy notice)", "")
	hammer(w, p, HONEST, { ByRemote = true })
	check(last(fired(w, "CraftResult", p)).Plus == 2 and last(fired(w, "CraftResult", p)).Id == s2.Id, "an honest hammer through the remotes: +2", "")
	for _, n in w.Notices do
		if n.Key then
			check(string.match(n.Key, "^Config%.Craft%.Text%.%a+$") ~= nil, "every craft notice is a Config.Craft.Text key", n.Key)
		end
	end
end)

------------------------------------------------------------------ workbench prompts
runGroup("workbench", function()
	local w = cWorld()
	local function bench(role, pos)
		local part = newInstance("Part", w)
		part.Position = pos
		part.Attrs.Role = role
		table.insert(w.Tagged.CraftStation, part)
		w.Added:Fire(part)
		return part
	end
	local anvil = bench("Smith", vec(100, 0, 0))
	local odd = bench("Painter", vec(200, 0, 0))
	local prompt = anvil:FindFirstChild("CraftPrompt")
	check(prompt and prompt.ClassName == "ProximityPrompt" and prompt.HoldDuration == 0 and prompt.ActionText == "" and prompt.ObjectText == ""
		and prompt:GetAttribute("ActionKey") == "Config.Craft.Text.Prompt" and prompt:GetAttribute("ObjectKey") == "Config.Craft.Text.Stations.Smith",
		"a tagged workbench gets one Craft prompt (no words; ActionKey / ObjectKey)", "")
	check(odd:FindFirstChild("CraftPrompt") == nil, "a workbench of an unknown role gets none", "")
	w.Added:Fire(anvil)
	local n = 0
	for _, c in anvil:GetChildren() do if c.Name == "CraftPrompt" then n += 1 end end
	check(n == 1, "never two prompts on one workbench", tostring(n))
	local p = smith(w, 1)
	local before = #fired(w, "CraftInfo", p)
	w.PPS.PromptTriggered:Fire(prompt, p)
	local open = fired(w, "OpenPanel", p)
	check(#open == 1 and open[1] == "Craft" and #fired(w, "CraftInfo", p) == before + 1, "a blacksmith at the anvil: OpenPanel Craft + CraftInfo", "")
	local k = smith(w, 2, nil, "Warrior", "Halo")
	local mage = smith(w, 3, nil, "Mage")
	local from = #w.Notices
	w.PPS.PromptTriggered:Fire(prompt, k)
	w.PPS.PromptTriggered:Fire(prompt, mage)
	check(#fired(w, "OpenPanel", k) == 0 and #fired(w, "OpenPanel", mage) == 0 and keysFor(w, k, from)[1] == "Config.Craft.Text.NotArtisan"
		and keysFor(w, mage, from)[1] == "Config.Craft.Text.NotArtisan", "a Knight or an alchemist at the anvil: NotArtisan, no window", "")
	local other = newInstance("ProximityPrompt", w)
	w.PPS.PromptTriggered:Fire(other, p)
	check(#fired(w, "OpenPanel", p) == 1, "someone else's prompt is not ours", "")
	local off = cWorld({ Off = true })
	local part = newInstance("Part", off)
	part.Attrs.Role = "Smith"
	off.Added:Fire(part)
	check(part:FindFirstChild("CraftPrompt") == nil, "switch off: no prompt", "")
end)

------------------------------------------------------------------ ⑤ the tamer's recipes (summon S1, Pet Treats T1)
-- PetService / TamerService are doubles here (their own code: tools/test_tamer_research.py)
local function tamerWorld(o)
	o = o or {}
	local edit = o.EditConfig
	local w = cWorld({ EditConfig = function(c)
		if o.NoResearch ~= true then c.Features.Research = true end
		if edit then edit(c) end
	end })
	w.Pts, w.Summons, w.Sums, w.PetsFull, w.SummonFails = {}, {}, {}, false, false
	if o.NoPets ~= true then
		w.Reg.PetService = {
			HasRoom = function() return not w.PetsFull end,
			SummonPet = function(p, sp, roll)
				table.insert(w.Summons, { P = p, Sp = sp, Roll = roll })
				if w.SummonFails then return nil end
				return "P" .. tostring(10 + #w.Summons)
			end,
		}
	end
	w.Reg.TamerService = { Points = function(_, fam) return w.Pts[fam] or 0 end,
		AddSummon = function(_, fam) table.insert(w.Sums, fam) return true end }
	return w
end

runGroup("tamer", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local S1, T1 = C.Craft.Recipes.S1, C.Craft.Recipes.T1
	check(S1 and S1.Role == "Tame" and S1.Kind == "Pet" and S1.Species == "BabySlime" and S1.Family == "Slime" and S1.Research == C.Research.Stages[2]
		and S1.Spd[1] == 5 and S1.Spd[2] == 8 and S1.Gold == 100 and S1.Mats.Jelly == 30 and S1.Mats.SlimeCore == 5 and S1.Lv == 1 and S1.XP == 80,
		"S1: research stage 2 (150) + Jelly 30, Slime Core 5, 100 gold -> a baby slime, walk +5..8% before the hammer (crafting_market §4); XP 80 (20 min, A23-217)", show(S1))
	check(T1 and T1.Role == "Tame" and T1.Kind == "Item" and T1.Item == "PetTreat" and T1.N == 3 and T1.Mats.Jelly == nil and T1.Mats.Herb == 3
		and T1.Mats.Petal == nil, "T1: Herb 3 (gathered only, 최종 검수 10/15) -> 3 Pet Treats (+ the hammer's +N)", show(T1))
	local it = C.Loot.Items.PetTreat
	local inOrder = false
	for _, id in C.Loot.Order do if id == "PetTreat" then inOrder = true end end
	check(it and it.Kind == "Treat" and it.Source == "Craft" and inOrder and C.SaveV4.PetRollSpd[2] == 10,
		"Pet Treat: Kind Treat, Source Craft (never sold at the Forge), in the bag order; a pet's walk roll tops at 10", show(it))
	check(type(C.Craft.Text.NeedResearch) == "string", "a NeedResearch line", "")

	-- which recipes are on
	local off = tamerWorld({ NoResearch = true })
	check(off.C.RecipeOn("S1") == nil and off.C.RecipeOn("T1") ~= nil, "research switch off: no summon recipe (treats stay)", "")
	local nop = tamerWorld({ NoPets = true })
	check(nop.C.RecipeOn("S1") == nil, "no PetService summon yet: no summon recipe", "")
	local w = tamerWorld()
	check(w.C.RecipeOn("S1") ~= nil, "both switches + both services: S1 on", "")
	local p, d = smith(w, 1, nil, "Archer")
	local info = last(fired(w, "CraftInfo", p))
	check(info and info.Role == "Tame" and table.concat(info.On, ",") == "S1,T1", "the tamer's CraftInfo.On = S1, T1", info and show(info.On) or "")

	-- research first
	w.Pts.Slime = 149
	local jelly, gold = d.Items.Jelly, d.BankGold
	local nf = #w.Notices
	check(w.C.TryStart(p, "S1") == "research" and keysFor(w, p, nf)[1] == "Config.Craft.Text.NeedResearch" and d.Items.Jelly == jelly
		and d.BankGold == gold, "149 Slime points: NeedResearch, nothing taken", "")
	local smithP = smith(w, 2)
	check(w.C.TryStart(smithP, "S1") == "role", "a blacksmith cannot summon", "")
	w.Pts.Slime = 150
	w.PetsFull = true
	local nf2 = #w.Notices
	check(w.C.TryStart(p, "S1") == "full" and keysFor(w, p, nf2)[1] == "Config.Craft.Text.Full" and d.Items.Jelly == jelly,
		"150 points but 64 pets: Full, nothing taken", "")
	w.PetsFull = false

	-- the roll: random 5..8 + the hammer's +N, at most 10
	w:Advance(61)
	check(w.C.TryStart(p, "S1") == "ok" and d.Items.Jelly == jelly - 30 and d.Items.SlimeCore == MATS.SlimeCore - 5 and d.BankGold == gold - 100,
		"150 points: the summon starts (Jelly 30, Slime Core 5, 100 gold)", "")
	w.Script = { 0.0 }
	hammer(w, p, HONEST)
	local s = w.Summons[1]
	local res = last(fired(w, "CraftResult", p))
	check(s and s.P == p and s.Sp == "BabySlime" and s.Roll.Spd == 7 and #w.Sums == 1 and w.Sums[1] == "Slime",
		"random 5 + the hammer's +2 = walk +7%; SummonPet(BabySlime, { Spd = 7 }), Sum + 1", s and show(s.Roll) or "")
	check(res.Kind == "Pet" and res.Plus == 2 and res.XP == 80 and type(res.Pet) == "table" and res.Pet.Uid == "P11" and res.Pet.Spd == 7
		and res.Pet.Species == "BabySlime" and d.Craft.Tame.Lv == 2 and d.Craft.Tame.XP == 40 and d.Craft.Pend == nil,
		"CraftResult.Pet = { Uid, Species, Spd }; 80 tamer craft XP (Lv2 with 40)", show(res.Pet))
	w:Advance(61)
	w.C.TryStart(p, "S1")
	w.Script = { 0.99 }
	hammer(w, p, HONEST)
	check(w.Summons[2].Roll.Spd == 10, "random 8 + 2 = 10 (the top)", show(w.Summons[2].Roll))
	w:Advance(61)
	w.C.TryStart(p, "S1")
	w.Script = { 0.99 }
	w.C.Finish(p, last(fired(w, "CraftSession", p)).Id)
	w:Flush()
	check(w.Summons[3].Roll.Spd == 8 and last(fired(w, "CraftResult", p)).Plus == 0, "no hammer (+0): 5..8 only (8)", show(w.Summons[3].Roll))
	w:Advance(61)
	w.C.TryStart(p, "S1")
	w.Script = { 0.0 }
	w.C.Finish(p, last(fired(w, "CraftSession", p)).Id)
	w:Flush()
	check(w.Summons[4].Roll.Spd == 5, "no hammer, the lowest draw: 5", show(w.Summons[4].Roll))
	local hi = tamerWorld({ EditConfig = function(c) c.Craft.Recipes.S1.Spd = { 9, 9 } end })
	local h = smith(hi, 3, nil, "Archer")
	hi.Pts.Slime = 150
	hi.C.TryStart(h, "S1")
	hammer(hi, h, HONEST)
	check(hi.Summons[1].Roll.Spd == 10, "never over 10: 9 + 2 is cut to 10", show(hi.Summons[1].Roll))

	-- a summon that does not go in waits (paid, Pend) and counts nothing
	local f = tamerWorld()
	local q, dq = smith(f, 4, nil, "Archer")
	f.Pts.Slime = 150
	f.C.TryStart(q, "S1")
	f.SummonFails = true
	hammer(f, q, HONEST)
	check(type(dq.Craft.Pend) == "table" and dq.Craft.Pend.Id == "S1" and #f.Sums == 0 and dq.Craft.Tame.XP == 0,
		"SummonPet says no: the craft waits (Pend), no Sum, no XP", show(dq.Craft.Pend))
	f.SummonFails = false
	f.C.Settle(q, dq)
	check(dq.Craft.Pend == nil and #f.Sums == 1 and f.Summons[#f.Summons].Roll.Spd >= 7, "the next try: the pet comes at the earned +2", "")

	-- Pet Treats: 3 + the hammer's +N
	local t = tamerWorld()
	local r, dr = smith(t, 5, nil, "Archer")
	check(t.C.TryStart(r, "T1") == "mats", "no herbs: NeedMats", "")
	dr.Items.Herb = 3
	local st = t.C.TryStart(r, "T1")
	check(st == "ok" and (dr.Items.Herb or 0) == 0, "T1 starts with 3 herbs (no research needed)", tostring(st) .. " " .. tostring(dr.Items.Herb))
	hammer(t, r, HONEST)
	check(dr.Items.PetTreat == 5 and dr.Craft.Tame.XP == 10, "3 + 2 = 5 Pet Treats, 10 craft XP", tostring(dr.Items.PetTreat))
end)

------------------------------------------------------------------ 최종 검수 10/15: the tamer's gear made end to end + the craft goal row
runGroup("tamer gear", function()
	local w = tamerWorld({ EditConfig = function(c) c.Features.Gear = true end })
	check(w.C.RecipeOn("PA1") ~= nil and w.C.RecipeOn("PC1") ~= nil and w.C.RecipeOn("PA3") ~= nil and w.C.RecipeOn("PC3") ~= nil,
		"the gear switch on: PA1-3 / PC1-3 are on", "")
	local p, d = smith(w, 1, { Craft = { Tame = { Lv = 5, XP = 0 }, Made = {} } }, "Archer")
	d.Items.Herb = 20
	local jelly, cores, herbs, gold = d.Items.Jelly, d.Items.SlimeCore, d.Items.Herb, d.BankGold
	check(w.C.TryStart(p, "PA1") == "ok" and d.Items.Jelly == jelly - 20 and d.Items.Herb == herbs - 4 and d.Items.SlimeCore == cores - 4
		and d.BankGold == gold - 150, "PA1 at tamer Lv5: Jelly 20, Herb 4, Slime Core 4, 150 gold taken", show({ d.Items.Jelly, d.Items.Herb }))
	hammer(w, p, HONEST)
	check(type(d.Gear) == "table" and d.Gear.Own["PetArmor:1:2"] == 1 and d.Craft.Pend == nil and d.Craft.Made.PA1 == 1,
		"pet armor +2 into data.Gear.Own['PetArmor:1:2'], Made.PA1 = 1", show(d.Gear and d.Gear.Own))
	w:Advance(61)
	check(w.C.TryStart(p, "PC1") == "ok", "PC1 starts (Petal 10, Herb 3, Jelly 12, 120 gold)", "")
	hammer(w, p, HONEST)
	check(d.Gear.Own["PetAcc:1:2"] == 1 and d.Craft.Made.PC1 == 1 and last(fired(w, "CraftResult", p)).Kind == "Gear",
		"pet accessory +2 into 'PetAcc:1:2'; CraftResult Kind Gear", show(d.Gear.Own))
	w:Advance(61)
	check(w.C.TryStart(p, "PA2") == "level", "PA2 needs tamer Lv12: refused at Lv" .. tostring(d.Craft.Tame.Lv), "")
	local s = smith(w, 2)
	check(w.C.TryStart(s, "PA1") == "role", "a blacksmith cannot make pet armor", "")
	local off = tamerWorld()
	local q = smith(off, 3, { Craft = { Tame = { Lv = 5, XP = 0 }, Made = {} } }, "Archer")
	check(off.C.RecipeOn("PA1") == nil and off.C.TryStart(q, "PA1") == "recipe", "the gear switch off: PA1 is off", "")
end)

runGroup("craft goal", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local hooks = C.Tutorial.Ladder.Hooks
	check(hooks[1].Kind == "Craft" and hooks[1].Service == "CraftService" and hooks[1].Feature == "Crafting"
		and type(C.Craft.Text.Goal) == "string" and C.Tutorial.ShortNames.Craft == "Craft",
		"the ladder's first hook = Craft (CraftService, Crafting); Craft.Text.Goal, ShortNames.Craft", show(hooks[1]))
	local function line(station) return string.format(C.Craft.Text.Goal, station) end
	local w = tamerWorld()
	local p, d = smith(w, 1, nil, "Archer")
	d.Items = { Herb = 3 }
	local text, kind = w.C.NextGoal(p, d)
	check(text == line("Research Table") and kind == "Craft", "a tamer with T1's things, never made: 'Make something new at the Research Table'",
		tostring(text))
	d.Craft = { Made = { T1 = 1 } }
	check(w.C.NextGoal(p, d) == nil, "T1 made once already, nothing else ready: no line", "")
	d.Items = { Jelly = 40, SlimeCore = 6 }
	w.Pts.Slime = 149
	check(w.C.NextGoal(p, d) == nil, "S1's things but 149 research: no line", "")
	w.Pts.Slime = 150
	check(w.C.NextGoal(p, d) == line("Research Table"), "150 research: the summon is a new thing to make", "")
	d.Items = { Jelly = 29, SlimeCore = 6 }
	check(w.C.NextGoal(p, d) == nil, "29 jelly (S1 needs 30): no line", "")
	d.Items = { Jelly = 40, SlimeCore = 6 }
	d.BankGold = 50
	check(w.C.NextGoal(p, d) == nil, "50 gold (S1 costs 100): no line", "")
	local s, ds = smith(w, 2)
	ds.Items = { Herb = 3, CopperOre = 2 }
	check(w.C.NextGoal(s, ds) == line("Anvil"), "a blacksmith with W2's harvest: the Anvil", "")
	local a, da = smith(w, 3, nil, "Mage")
	da.Items = { Herb = 3 }
	check(w.C.NextGoal(a, da) == line("Cauldron"), "an alchemist with AP1's things: the Cauldron", "")
	local h, dh = smith(w, 4, nil, "Warrior", "Halo")
	dh.Items = { Herb = 3, CopperOre = 2 }
	check(w.C.NextGoal(h, dh) == nil, "a Halo warrior is no artisan: no line", "")
	local off = cWorld({ Off = true })
	local o, dof = smith(off, 5)
	dof.Items = { Herb = 3, CopperOre = 2 }
	check(off.C.NextGoal(o, dof) == nil, "Crafting off: no line", "")
	check(d.Craft.Tame == nil, "NextGoal writes nothing into the save", show(d.Craft))
end)

------------------------------------------------------------------ ⑦ fame and rank (artisan_fame_2026-10-12.md)
runGroup("fame", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local R = C.Craft.Recipes
	check(C.CraftFame(R.W2, 0) == 1 and C.CraftFame(R.W2, 2) == 2 and C.CraftFame(R.W2, 1) == 1 and C.CraftFame(R.W4, 0) == 2
		and C.CraftFame(R.W6, 0) == 3 and C.CraftFame(R.W9, 0) == 4 and C.CraftFame(R.W9, 2) == 5 and C.CraftFame(nil, 2) == 0,
		"fame: craft Lv 1-9 = 1, 10-19 = 2, 20-29 = 3, 30 = 4; the hammer's +2 adds 1", "")
	local rk = {}
	for _, rep in { 0, 29, 30, 149, 150, 499, 500, 1499, 1500, 1e9 } do table.insert(rk, (C.ArtisanRank(rep))) end
	check(table.concat(rk, ",") == "1,1,2,2,3,3,4,4,5,5" and select(2, C.ArtisanRank(0)) == 30 and select(2, C.ArtisanRank(150)) == 500
		and select(2, C.ArtisanRank(1500)) == 0 and C.ArtisanRank(0 / 0) == 1 and C.ArtisanRank(nil) == 1,
		"ranks at 0 / 30 / 150 / 500 / 1500 (next Rep; 0 at the top)", table.concat(rk, ","))
	check(#C.Craft.Ranks == 5 and type(C.Craft.Text.RankUp) == "string", "five ranks, a RankUp line", "")
	for _, row in C.Craft.Ranks do
		check(type(C.Craft.Text.Ranks[row.Id]) == "string", "every rank has a name", row.Id)
	end

	local w = cWorld()
	w.Credits = {}
	w.Reg.RankingService.Credit = function(p, board, n, why) table.insert(w.Credits, { P = p, B = board, N = n, W = why }) return true end
	local p, d = smith(w, 1)
	check(p:GetAttribute("ArtisanRank") == 1 and last(fired(w, "CraftInfo", p)).Rank == 1 and last(fired(w, "CraftInfo", p)).NextRep == 30
		and last(fired(w, "CraftInfo", p)).Rep == 0, "a new artisan: ArtisanRank 1 (Apprentice), CraftInfo Rep 0 / Rank 1 / NextRep 30", "")
	startAndHammer(w, p, HONEST)
	check(d.Craft.Rep == 2 and #w.Credits == 1 and w.Credits[1].B == "Artisan" and w.Credits[1].N == 2 and w.Credits[1].W == "Craft"
		and last(fired(w, "CraftResult", p)).Fame == 2, "W1 at +2: 2 fame -> Rep and the weekly Artisan board; CraftResult.Fame", tostring(d.Craft.Rep))
	-- the 2x XP pass never touches fame
	w.PassXP2[p] = true
	w:Advance(61)
	startAndHammer(w, p, HONEST)
	check(d.Craft.Rep == 4 and w.Credits[2].N == 2, "with the 2x XP pass: still 2 fame", tostring(d.Craft.Rep))
	-- a rank up: one line (the rank's name key), the signal, the attribute, CraftInfo
	local ups = {}
	w.C.RankUp:Connect(function(pl, rank) table.insert(ups, rank) end)
	d.Craft.Rep = 28
	local from = #w.Notices
	w:Advance(61)
	startAndHammer(w, p, HONEST)
	local ns = {}
	for i = from + 1, #w.Notices do if w.Notices[i].Player == p and w.Notices[i].Key == "Config.Craft.Text.RankUp" then table.insert(ns, w.Notices[i]) end end
	check(d.Craft.Rep == 30 and #ns == 1 and #ups == 1 and ups[1] == 2 and p:GetAttribute("ArtisanRank") == 2
		and last(fired(w, "CraftInfo", p)).Rank == 2 and last(fired(w, "CraftInfo", p)).NextRep == 150, "28 + 2 = 30: Journeyman (one line, RankUp 2, attribute 2)", "")
	w:Advance(61)
	startAndHammer(w, p, HONEST)
	local again = 0
	for i = from + 1, #w.Notices do if w.Notices[i].Player == p and w.Notices[i].Key == "Config.Craft.Text.RankUp" then again += 1 end end
	check(again == 1 and #ups == 1, "the next craft in the same rank: no line", "")
	-- no fame for a waiting craft finished after a side change (the craft XP rule)
	local h, dh = smith(w, 2, { Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 7, Made = {},
		Pend = { Id = "W2", Plus = 2, Gold = 40, Mats = { Jelly = 10 } } } }, "Warrior", "Halo")
	check(dh.Craft.Pend == nil and dh.Craft.Rep == 7 and h:GetAttribute("ArtisanRank") == 0, "a Knight's waiting craft: the item, no fame; ArtisanRank 0", "")
	-- the lifetime cap
	local top, dt = smith(w, 3, { Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 10000000, Made = {} } })
	startAndHammer(w, top, HONEST)
	check(dt.Craft.Rep == 10000000 and top:GetAttribute("ArtisanRank") == 5, "Rep never passes MaxCount; Grandmaster", tostring(dt.Craft.Rep))
	-- a faction change: the attribute follows at once
	d.Faction = "Halo"
	w.Reg.FactionService.FactionChanged:Fire(p)
	check(p:GetAttribute("ArtisanRank") == 0, "left the guild: ArtisanRank 0 (Rep kept: lifetime)", tostring(p:GetAttribute("ArtisanRank")))
	check(d.Craft.Rep == 32, "the lifetime Rep stays", tostring(d.Craft.Rep))
	d.Faction, d.Class = "Neutral", "Mage"
	w.Reg.ClassService.ClassChanged:Fire(p)
	check(p:GetAttribute("ArtisanRank") == 2 and last(fired(w, "CraftInfo", p)).Role == "Alch", "back as an alchemist: rank 2 again (Rep is shared by the roles)", "")
	-- no RankingService: crafting still works
	local n = cWorld()
	n.Reg.RankingService.Credit = nil
	local q, dq = smith(n, 1)
	startAndHammer(n, q, HONEST)
	check(dq.Craft.Rep == 2 and #n.Warnings == 0, "no RankingService.Credit: Rep only, no error", show(n.Warnings))
end)


------------------------------------------------------------------ A23-219 craft tools + the Blessed Scroll (게임성 개발 2)
runGroup("tools", function()
	local w = cWorld()
	local C = w.Config
	local T = C.Craft.Tools
	check(T.Max == 10 and #T.Steps == 10 and T.Steps[1].P == 1 and T.Steps[3].P == 0.9 and T.Steps[10].P == 0.3
		and T.Steps[10].Gold == 18000 and T.Steps[10].Lv == 20 and T.Steps[10].Extra.TrialCore == 1 and T.Steps[7].Extra.KingJelly == 1,
		"Config.Craft.Tools: +1..+10, 100% -> 30%, +10 = 18,000 gold, Lv20, extras from +7 (craft_tools_r1 §1)", show(T.Steps[10]))
	check(T.Names.Smith == "Craft Hammer" and T.Names.Alch == "Mixing Kit" and T.Names.Tame == "Care Kit" and T.Bless[0] == 0
		and T.Bless[1] == 0.005 and T.Bless[10] == 0.05 and T.BlessRecipe == "AS1" and T.BlessItem == "Enh70B",
		"names, Bless 0 -> 0.5% -> 5% (AS1 -> Enh70B)", show(T.Bless))
	local B = C.Loot.Items.Enh70B
	check(B and B.Kind == "Enhance" and B.Chance == 0.7 and B.Plus == 2 and B.Source == "Craft" and table.find(C.Loot.Order, "Enh70B") ~= nil,
		"Enh70B: an Enhance scroll, 70%, +2 on a success, made only by crafting, listed", show(B))
	-- the average total (no drop on a fail = 1 / P tries each): 18.15 tries, about 109,590 gold
	local tries, gold = 0, 0
	for _, st in T.Steps do
		tries += 1 / st.P
		gold += st.Gold / st.P
	end
	check(math.abs(tries - 18.15) < 0.01 and math.abs(gold - 109590) < 1, "+0 -> +10 on average: 18.15 tries, 109,590 gold", show({ tries, gold }))

	-- a blacksmith with no tool saved: +0; one try at +0 -> +1 (100%): 40 gold, 2 copper + 2 jelly
	local p, d = smith(w, 61)
	check(w.C.ToolCost("Smith", 1).Every.Jelly == 2 and w.C.ToolCost("Smith", 1).Every.CopperOre == 2 and w.C.ToolCost("Smith", 7).Every.KnightCrest == 4
		and w.C.ToolCost("Alch", 5).Every.Glowcap == 8 and w.C.ToolCost("Tame", 9).Every.Petal == 12
		and w.C.ToolCost("Smith", 3).Every.Jelly == 6 and w.C.ToolCost("Smith", 6).Every.GoblinTooth == 12
		and w.C.ToolCost("Smith", 4).Every.GoblinTooth == 4 and w.C.ToolCost("Smith", 7).Every.GoblinTooth == nil,
		"ToolCost: the role's band material (Jelly / GoblinTooth / KnightCrest for the smith, ...)", "")
	local gold0, jelly0, copper0 = d.BankGold, d.Items.Jelly, d.Items.CopperOre
	check(w.C.UpgradeTool(p) == "ok" and d.Craft.ToolSmith == 1 and d.BankGold == gold0 - 40 and d.Items.Jelly == jelly0 - 2
		and d.Items.CopperOre == copper0 - 2, "+0 -> +1: paid 40 gold, 2 jelly, 2 copper; saved flat (Craft.ToolSmith)", show({ d.Craft.ToolSmith, d.BankGold }))
	check(d.Craft.Tool == nil, "no nested Tool table in the save (an older server would drop it)", show(d.Craft.Tool))
	local res = last(fired(w, "CraftToolResult", p))
	check(res and res.Role == "Smith" and res.Tool == 1 and res.Ok == true and res.Name == "Craft Hammer", "CraftToolResult { Smith, 1, Ok }", show(res))
	check(last(fired(w, "CraftInfo", p)).Tool == 1, "CraftInfo carries the tool's +N", "")
	-- the craft level gate (+3 needs Lv2)
	d.Craft.ToolSmith = 2
	local before = d.BankGold
	w:Advance(2)
	check(w.C.UpgradeTool(p) == "level" and d.Craft.ToolSmith == 2 and d.BankGold == before, "+2 -> +3 at craft Lv1: level, nothing taken", "")
	-- a fail keeps the tool and pays every-try costs only; the extra (KingJelly at +7) is held and only taken on a success
	d.Craft.Smith = { Lv = 12, XP = 0 }
	d.Craft.ToolSmith = 6
	d.Items.KingJelly = 1
	local silver, crest, g6 = d.Items.SilverOre, d.Items.KnightCrest, d.BankGold
	w.Script = { 0.9 } -- (P = 0.5: 0.9 fails)
	w:Advance(2)
	check(w.C.UpgradeTool(p) == "fail" and d.Craft.ToolSmith == 6 and d.BankGold == g6 - 2500 and d.Items.SilverOre == silver - 8
		and d.Items.KnightCrest == crest - 4 and d.Items.KingJelly == 1, "+6 -> +7 failed: still +6 (never down), 2,500 gold + 8 silver + 4 crests paid, the King Jelly kept",
		show({ d.Craft.ToolSmith, d.Items.KingJelly }))
	check(last(fired(w, "CraftToolResult", p)).Ok == false, "the result says Ok = false", "")
	w.Script = { 0.49 }
	w:Advance(2)
	check(w.C.UpgradeTool(p) == "ok" and d.Craft.ToolSmith == 7 and (d.Items.KingJelly or 0) == 0, "the next try succeeds: +7, the King Jelly taken", show(d.Items.KingJelly))
	-- the extra missing: no try at all
	local g7 = d.BankGold
	w:Advance(2)
	check(w.C.UpgradeTool(p) == "mats" and d.Craft.ToolSmith == 7 and d.BankGold == g7, "+7 -> +8 without the 2 Deep Moon Shards: mats, nothing taken", "")
	-- +10 is the top
	d.Craft.ToolSmith = 10
	w:Advance(2)
	check(w.C.UpgradeTool(p) == "max", "+10: max", "")
	-- far from the workbench / not an artisan / no gold
	d.Craft.ToolSmith = 0
	rootOf(p).Position = vec(200, 0, 0)
	w:Advance(2)
	check(w.C.UpgradeTool(p) == "far" and d.Craft.ToolSmith == 0, "far from the bench: far", "")
	rootOf(p).Position = vec(5, 0, 0)
	d.BankGold, d.CarriedGold = 10, 0
	w:Advance(2)
	check(w.C.UpgradeTool(p) == "gold" and d.Items.Jelly == jelly0 - 2, "no gold: nothing taken", "")
	local h = smith(w, 62, nil, "Warrior", "Halo")
	check(w.C.UpgradeTool(h) == "role", "a Halo knight has no tool", "")
	-- through the remote (no arguments)
	d.BankGold = 100000
	w.Gap = 2
	w:Remote("CraftTool", p)
	check(d.Craft.ToolSmith == 1, "the CraftTool remote tries once", d.Craft.ToolSmith)
	w:Remote("CraftTool", p, "Alch")
	check(d.Craft.ToolSmith == 1, "an argument = ignored", d.Craft.ToolSmith)

	-- the Blessed Scroll: AS1 rolls once at its start with Bless[the Mixing Kit's +N]
	local stock = { Herb = 60, CopperOre = 40, SlimeCore = 12 }
	local a, ad = smith(w, 63, { Items = deepCopy(stock) }, "Mage")
	ad.Craft.Alch = { Lv = 3, XP = 0 }
	ad.Craft.ToolAlch = 10
	w.Script = { 0.04 } -- (< 5%: blessed)
	w:Advance(61)
	startAndHammer(w, a, HONEST, { Recipe = "AS1" })
	local r1 = last(fired(w, "CraftResult", a))
	check(r1 and r1.Blessed == true and (ad.Items.Enh70B or 0) == 1 and (ad.Items.Enh70 or 0) == r1.Plus,
		"+10 kit, a 4% roll: ONE Blessed Scroll + the hammer's +N plain ones (never all blessed)", show({ r1, ad.Items.Enh70, ad.Items.Enh70B }))
	w.Script = { 0.06 } -- (>= 5%: plain)
	w:Advance(61)
	startAndHammer(w, a, HONEST, { Recipe = "AS1" })
	local r2 = last(fired(w, "CraftResult", a))
	check(r2 and r2.Blessed == nil and (ad.Items.Enh70B or 0) == 1, "a 6% roll: plain scrolls only", show(r2))
	-- the roll is saved with the paid craft (a stop / rejoin pays the same)
	w.Script = { 0.01 }
	w:Advance(61)
	check(w.C.TryStart(a, "AS1") == "ok" and ad.Craft.Pend.Bless == true, "the roll is in Craft.Pend (Bless)", show(ad.Craft.Pend))
	local clean = C.SanitizeCraft(deepCopy(ad.Craft))
	check(clean.Pend.Bless == true and clean.ToolAlch == 10, "the save repair keeps Pend.Bless and ToolAlch", show(clean))
	-- a +0 kit never blesses (no roll drawn)
	local z, zd = smith(w, 64, { Items = deepCopy(stock) }, "Mage")
	zd.Craft.Alch = { Lv = 3, XP = 0 }
	w.Script = { 0 }
	startAndHammer(w, z, HONEST, { Recipe = "AS1" })
	check(last(fired(w, "CraftResult", z)).Blessed == nil and (zd.Items.Enh70B or 0) == 0, "a +0 kit: Bless 0%, never blessed", "")
	w.Script = {}
	-- API review (10/17 HIGH): a full bag never pays a blessed craft in parts (a pending craft used to hand out the plain
	-- scrolls again at every Settle). `free` = empty bag slots left after the fill
	local function fullBag(id, items, free)
		local q, qd = smith(w, id, { Items = items }, "Mage")
		qd.Craft.Alch = { Lv = 3, XP = 0 }
		local ids = {}
		for item, def in C.Loot.Items do
			if C.BagSlots.Counts[def.Kind] and qd.Items[item] == nil and item ~= "Enh70" and item ~= "Enh70B" then table.insert(ids, item) end
		end
		table.sort(ids)
		local i = 1
		while C.BagUsed(qd) + free < C.BagSlotsOf(qd) and ids[i] do
			qd.Items[ids[i]] = 1
			i += 1
		end
		check(C.BagUsed(qd) + free == C.BagSlotsOf(qd), "(setup: the bag filled to " .. free .. " free)", show({ C.BagUsed(qd), C.BagSlotsOf(qd) }))
		return q, qd
	end
	local pend = { Id = "AS1", Plus = 1, Gold = 60, Mats = { Herb = 10, CopperOre = 8, SlimeCore = 2 }, Bless = true }
	-- the plain scroll held, no slot left: the Blessed Scroll cannot come in -> the whole craft pays plain, once
	local f1, fd1 = fullBag(65, { Enh70 = 3, Herb = 30 }, 0)
	fd1.Craft.Pend = deepCopy(pend)
	check(w.C.Settle(f1, fd1) == "done" and fd1.Items.Enh70 == 3 + 2 and (fd1.Items.Enh70B or 0) == 0 and fd1.Craft.Pend == nil,
		"full bag + a blessed AS1 (+1): 2 plain scrolls, no Blessed Scroll, nothing pending", show({ fd1.Items.Enh70, fd1.Items.Enh70B, fd1.Craft.Pend }))
	check(w.C.Settle(f1, fd1) == "none" and fd1.Items.Enh70 == 5, "a second Settle pays nothing (free scrolls: 0)", show(fd1.Items.Enh70))
	-- one free slot, neither scroll held: the plain ones take it (never the Blessed Scroll alone and the rest lost)
	local f2, fd2 = fullBag(66, { Herb = 30 }, 1)
	fd2.Craft.Pend = deepCopy(pend)
	check(w.C.Settle(f2, fd2) == "done" and fd2.Items.Enh70 == 2 and (fd2.Items.Enh70B or 0) == 0,
		"one free slot, no scroll held: 2 plain scrolls (the Blessed Scroll would leave no slot for them)", show({ fd2.Items.Enh70, fd2.Items.Enh70B }))
	-- two free slots: the Blessed Scroll + the rest plain, as before
	local f3, fd3 = fullBag(67, { Herb = 30 }, 2)
	fd3.Craft.Pend = deepCopy(pend)
	check(w.C.Settle(f3, fd3) == "done" and fd3.Items.Enh70 == 1 and fd3.Items.Enh70B == 1,
		"two free slots: 1 Blessed + 1 plain", show({ fd3.Items.Enh70, fd3.Items.Enh70B }))
	-- the roll itself waits for room: a full bag (the plain scroll held) never rolls a blessing
	local f4, fd4 = fullBag(68, { Enh70 = 1, Herb = 60, CopperOre = 40, SlimeCore = 12 }, 0)
	fd4.Craft.ToolAlch = 10
	w.Script = { 0.01 }
	check(w.C.TryStart(f4, "AS1") == "ok" and fd4.Craft.Pend.Bless == nil, "a full bag at the start: no blessing rolled (+10 kit, 1%)", show(fd4.Craft.Pend))
	w.Script = {}
	-- the tool try: the same gates as a craft (a pending craft that cannot be paid, auto combat on)
	local g, gd = smith(w, 69)
	gd.BankGold = 100000
	gd.Craft.Pend = { Id = "W2", Plus = 1, Gold = 40, Mats = { CopperOre = 2 } }
	w.SpareFull = true
	w:Advance(2)
	check(w.C.UpgradeTool(g) == "busy" and (gd.Craft.ToolSmith or 0) == 0 and gd.BankGold == 100000, "a pending craft that does not fit: busy, nothing taken", "")
	w.SpareFull = false
	w:Advance(2)
	g:SetAttribute("AutoCombatUnlocked", true)
	g:SetAttribute("AutoCombatEnabled", true)
	check(w.C.UpgradeTool(g) == "auto" and (gd.Craft.ToolSmith or 0) == 0, "auto combat on: auto (the pending one was paid first)", show(gd.Craft.Pend))
	g:SetAttribute("AutoCombatEnabled", false)
	w:Advance(2)
	check(w.C.UpgradeTool(g) == "ok" and gd.Craft.ToolSmith == 1, "auto off: the try goes", "")
	-- the repair: flat Tool<role> 0..10, anything else dropped
	local fix = C.SanitizeCraft({ ToolSmith = 12, ToolAlch = -3, ToolTame = "x", Tool = { Smith = 5 } })
	check(fix.ToolSmith == 10 and fix.ToolAlch == nil and fix.ToolTame == nil and fix.Tool == nil, "repair: 12 -> 10, -3 / 'x' / a table dropped", show(fix))
end)

------------------------------------------------------------------ A23-219 ② crafted options (게임성 개발 2, 최종 검수 10/17)
runGroup("opts", function()
	local function herb(p, d) d.Items.Herb = 60; return p, d end -- (W2 takes Herb)
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local O = C.Craft.Tools.Opt
	check(O.On == false, "API review 10/17: the option switch is off until game dev 1's screens (Opt.On)", tostring(O.On))
	check(O.P[0] == 0.10 and O.P[5] == 0.35 and O.P[10] == 0.60 and O.R[0] == 1 and O.R[2] == 1 and O.R[3] == 2 and O.R[6] == 3
		and O.R[9] == 4 and O.R[10] == 5 and O.Max == 5, "P 10% -> 60% (+5% a step), R 1/2/3 at +0/+3/+6, 4 at +9, 5 at +10", show(O))
	check(C.CraftOptBonus("Weapon", 5) == 0.04 and C.CraftOptBonus("Armor", 5) == 0.02 and C.CraftOptBonus("Ring", 5) == 0.01
		and C.CraftOptBonus("PetArmor", 5) == 0.2 and C.CraftOptBonus("PetAcc", 5) == 0.1 and C.CraftOptBonus("Weapon", 1) == 0.008
		and C.CraftOptBonus("Weapon", 0) == 0 and C.CraftOptBonus("Weapon", 6) == 0 and C.CraftOptBonus("Potion", 3) == 0,
		"sizes: weapon 4%, armor 2%p, ring 1%p, pet armor 20%p, pet acc 10%p (pet XP) at R5", "")
	-- never past the next step (A23-219): the best +9 with the best weapon and ring options stays under a plain +10
	local best9 = C.EnhanceMult(9) * (1 + C.CraftOptBonus("Weapon", 5)) * (1 + C.CraftOptBonus("Ring", 5))
	check(best9 < C.EnhanceMult(10), "+9 x1.04 x1.01 < plain +10", tostring(best9))
	for _, slot in { "Armor", "Ring", "PetArmor" } do
		for t = 1, C.Gear.MaxTier - 1 do
			check(C.GearBonus(slot, t, C.Gear.MaxPlus, O.Max) <= C.GearBonus(slot, t + 1, 0, 0) + 1e-9,
				slot .. " T" .. t .. " +2 with the best option never passes T" .. (t + 1) .. " +0", "")
		end
	end
	check(C.GearBonusOf("Armor", "3:2:5") == 0.24 and C.GearBonusOf("Ring", "3:2:5") == 0.15 and C.GearBonusOf("PetArmor", "3:2:5") == 1.0
		and C.GearBonusOf("PetAcc", "3:2:5") == C.GearBonusOf("PetAcc", "3:2"), "worn bonus: armor 22%+2, ring 14%+1, pet armor 80%+20; pet acc walk unchanged", "")

	-- the switch off (shipped): no roll at all
	local ON = function(c) c.Craft.Tools.Opt.On = true end
	local wo = cWorld()
	local po, dpo = herb(smith(wo, 80))
	dpo.Craft.ToolSmith = 10
	wo.Script = { 0.01 }
	check(wo.C.TryStart(po, "W2") == "ok" and dpo.Craft.Pend.Opt == nil and #wo.Script == 1, "Opt.On false: no option, no roll drawn", show(dpo.Craft.Pend))
	wo.Script = {}
	-- a weapon craft rolls once at its start with the hammer's +N (W2, +10: 60% for size 5)
	local w = cWorld({ EditConfig = ON })
	local p, d = herb(smith(w, 81))
	d.Craft.ToolSmith = 10
	w.Script = { 0.59 }
	local st = w.C.TryStart(p, "W2")
	check(st == "ok" and d.Craft.Pend.Opt == 5, "+10 hammer, a 59% roll: size 5 saved in Craft.Pend.Opt", show({ st, d.Craft.Pend }))
	hammer(w, p, HONEST)
	local res = last(fired(w, "CraftResult", p))
	check(last(w.Spares).Opt == 5 and res.Opt == 5 and d.Craft.Pend == nil, "the spare comes with option 5 (AddSpare o), CraftResult.Opt 5", show({ last(w.Spares).Opt, res.Opt }))
	w.Script = { 0.61 }
	w:Advance(61)
	startAndHammer(w, p, HONEST, { Recipe = "W2" })
	check((last(w.Spares).Opt or 0) == 0 and last(fired(w, "CraftResult", p)).Opt == nil, "a 61% roll: no option", tostring(last(w.Spares).Opt))
	-- +0 hammer: 10% for size 1
	local q, e = herb(smith(w, 82))
	w.Script = { 0.09 }
	check(w.C.TryStart(q, "W2") == "ok" and e.Craft.Pend.Opt == 1, "+0 hammer, a 9% roll: size 1", show(e.Craft.Pend))
	-- +6: 40% for size 3
	local r6, d6 = herb(smith(w, 83))
	d6.Craft.ToolSmith = 6
	w.Script = { 0.39 }
	check(w.C.TryStart(r6, "W2") == "ok" and d6.Craft.Pend.Opt == 3, "+6 hammer, a 39% roll: size 3", show(d6.Craft.Pend))
	-- the roll stays through a full bag and a rejoin's Settle (never rolled again)
	local f, fd = herb(smith(w, 84))
	fd.Craft.ToolSmith = 10
	w.Script = { 0.2 }
	w.C.TryStart(f, "W2")
	w.SpareFull = true
	hammer(w, f, HONEST)
	check(type(fd.Craft.Pend) == "table" and fd.Craft.Pend.Opt == 5, "no room at the end: pending with its option", show(fd.Craft.Pend))
	w.SpareFull = false
	w.Script = { 0.99 } -- a new roll would say none
	check(w.C.Settle(f, fd) == "done" and last(w.Spares).Opt == 5, "the Settle pays the same option (no second roll)", tostring(last(w.Spares).Opt))
	w.Script = {}
	-- AS1 (an item) never rolls an option (its own Blessed Scroll only)
	local a, ad = smith(w, 85, { Items = { Herb = 60, CopperOre = 40, SlimeCore = 12 } }, "Mage")
	ad.Craft.Alch = { Lv = 3, XP = 0 }
	ad.Craft.ToolAlch = 10
	w.Script = { 0.5 } -- (>= 5%: no blessing; an option roll would eat it)
	check(w.C.TryStart(a, "AS1") == "ok" and ad.Craft.Pend.Opt == nil and ad.Craft.Pend.Bless == nil, "AS1: no option roll", show(ad.Craft.Pend))
	w.Script = {}

	-- the real spares: the key "T:P:O"
	local wr = cWorld({ RealSpare = true, EditConfig = function(c) c.Features.Gear = true; ON(c) end })
	local s, sd = herb(smith(wr, 86))
	sd.Craft.ToolSmith = 10
	wr.Script = { 0.1 }
	local sr = startAndHammer(wr, s, HONEST, { Recipe = "W2" })
	check(last(fired(wr, "CraftResult", s)) ~= nil, "(setup: the real-spare craft finished)", tostring(sr))
	local plus = (last(fired(wr, "CraftResult", s)) or {}).Plus
	check(sd.Spares[string.format("2:%d:5", plus)] == 1, "LootService.AddSpare: Spares[\"2:P:5\"]", show(sd.Spares))
	-- gear: Own "<Slot>:T:P:O"
	local g, gd = herb(smith(wr, 87))
	gd.Craft.Smith = { Lv = 8, XP = 0 }
	gd.Items.Glowcap = 10 -- (R1 takes Glowcap)
	gd.Craft.ToolSmith = 3
	wr.Script = { 0.24 }
	wr:Advance(61)
	local gs = startAndHammer(wr, g, HONEST, { Recipe = "R1" })
	check(last(fired(wr, "CraftResult", g)) ~= nil, "(setup: the ring craft finished)", tostring(gs))
	local gp = (last(fired(wr, "CraftResult", g)) or {}).Plus or -1
	check(gd.Gear.Own[string.format("Ring:1:%d:2", gp)] == 1, "a +3 hammer ring with a 24% roll: Own[\"Ring:1:P:2\"]", show(gd.Gear.Own))
	wr.Script = {}
	-- API review 10/17 (HIGH): the room is checked for both outcomes BEFORE the roll - a full key / a full bag refuses with no
	-- roll drawn, so retrying never rerolls and an option can never be forced
	local k1, kd1 = herb(smith(wr, 93))
	kd1.Craft.ToolSmith = 10
	kd1.Spares = { ["2:0"] = 20 } -- the plain key at its cap (20): a plain result would not fit
	wr.Script = { 0.01 }
	wr:Advance(61)
	check(wr.C.TryStart(k1, "W2") == "full" and #wr.Script == 1 and kd1.Craft.Pend == nil, "the plain key full: refused before the roll (an option would fit, still refused)", "")
	check(wr.C.TryStart(k1, "W2") == "full" and #wr.Script == 1, "... and again: still no roll (never rerolled by retrying)", "")
	wr.Script = {}
	local k2, kd2 = herb(smith(wr, 94))
	kd2.Craft.ToolSmith = 10 -- size 5
	kd2.Spares = { ["2:0:5"] = 1, ["2:1:5"] = 1, ["2:2:5"] = 1 } -- the option keys held, the plain ones would need new slots
	kd2.BagSlots = wr.Config.BagUsed(kd2) -- the bag full
	wr.Script = { 0.01 }
	check(wr.C.TryStart(k2, "W2") == "full" and #wr.Script == 1, "a full bag holding the option keys: refused before the roll (no forced option)", "")
	wr.Script = {}
end)

-- A23-219 ② B (최종 검수 10/17): a potion / tonic / treat craft rolls the same P once; a hit = ONE special result, the rest plain
runGroup("specials", function()
	local wr = cWorld({ RealSpare = true, EditConfig = function(c) c.Craft.Tools.Opt.On = true end })
	local mats = { Herb = 60, Jelly = 30, CopperOre = 30, SlimeCore = 10, Petal = 20 }
	-- AP1 (HP potions, N 2): +10 kit, 59% -> one special + the rest plain
	local a, ad = smith(wr, 91, { Items = deepCopy(mats) }, "Mage")
	ad.Craft.ToolAlch = 10
	wr.Script = { 0.59 }
	check(wr.C.TryStart(a, "AP1") == "ok" and ad.Craft.Pend.Opt == 1, "AP1 +10 kit, a 59% roll: a special (Pend.Opt 1)", show(ad.Craft.Pend))
	hammer(wr, a, HONEST)
	local r = last(fired(wr, "CraftResult", a))
	local made = 2 + r.Plus
	check((ad.HPPotionPlusCount or 0) == 1 and (ad.HPPotionCount or 0) == made - 1 and r.Opt == 1,
		"one special HP potion (its own stock), the rest plain", show({ ad.HPPotionPlusCount, ad.HPPotionCount, made }))
	-- A1 (Might Tonic): a 61% roll = all plain
	wr:Advance(61)
	wr.Script = { 0.61 }
	startAndHammer(wr, a, HONEST, { Recipe = "A1" })
	check((ad.Items.MightTonicPlus or 0) == 0 and (ad.Items.MightTonic or 0) >= 1, "A1 with a 61% roll: plain tonics only", show(ad.Items.MightTonic))
	wr:Advance(61)
	wr.Script = { 0.05 }
	local before = ad.Items.MightTonic or 0
	startAndHammer(wr, a, HONEST, { Recipe = "A1" })
	local p2 = last(fired(wr, "CraftResult", a)).Plus
	check(ad.Items.MightTonicPlus == 1 and (ad.Items.MightTonic or 0) - before == p2, "A1 with a 5% roll: one Might Tonic+, the hammer's +N plain", show(ad.Items))
	-- T1 (Pet Treats, N 3) by a tamer: +0 tool, a 9% roll
	local t, td = smith(wr, 92, { Items = deepCopy(mats) }, "Archer")
	wr.Script = { 0.09 }
	startAndHammer(wr, t, HONEST, { Recipe = "T1" })
	local p3 = last(fired(wr, "CraftResult", t)).Plus
	check(td.Items.PetTreatPlus == 1 and td.Items.PetTreat == 3 + p3 - 1, "T1 +0 tool, 9%: one Pet Treat+, the rest plain", show(td.Items))
	-- AS1 (a scroll) never gets a special roll; a weapon keeps its sizes
	check(wr.Config.Craft.Tools.Opt.Special.Enh70 == nil and wr.Config.Craft.Tools.Opt.Special.HP == "HP", "no special scrolls", "")
	wr.Script = {}
end)

------------------------------------------------------------------ A23-217 the weekly workshop gift (게임성 개발 2)
runGroup("week", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local W, R = C.Craft.Week, C.Craft.Recipes
	check(W.Tiers[1] == 500 and W.Tiers[2] == 1000 and W.Tiers[3] == 1600 and #W.Tiers == 3, "A23-217 tiers 500 / 1,000 / 1,600", show(W.Tiers))
	check(W.Gifts[1].HP == 5 and W.Gifts[1].MP == 5 and W.Gifts[1].PetTreat == nil and W.Gifts[2].PetTreat == 3 and W.Gifts[2].Enh70 == nil
		and W.Gifts[3].HP == 5 and W.Gifts[3].MP == 5 and W.Gifts[3].PetTreat == 3 and W.Gifts[3].Enh70 == 1,
		"gifts: HP 5 + MP 5 / + Pet Treat 3 / + Enh70 1 (one bundle, the top tier)", show(W.Gifts))
	local ok, easyIds = true, {}
	for id, r in R do
		if type(r.Min) ~= "number" or r.XP ~= math.floor(r.Min * W.XPPerMin + 0.5) then
			ok = false
			easyIds = { id }
			break
		end
		if C.CraftWeekEasy(r) then table.insert(easyIds, id) end
	end
	table.sort(easyIds)
	check(ok, "every recipe has Min (target minutes, A23-215) and XP = Min x 4 (artisan_weekly_r1 §2)", table.concat(easyIds, ","))
	check(ok and table.concat(easyIds, ",") == "A1,A2,A3,A4,AP1,AP2,T1,W2", "the easy bundle (Min <= 6): W2, the tonics, the potions, the treats",
		table.concat(easyIds, ","))
	check(R.W3.XP == 48 and R.W9.XP == 4500 and R.G3.XP == 300 and R.AS1.XP == 40 and R.S1.XP == 80 and R.AP2.XP == 10 and R.A1.XP == 16,
		"retuned XP: W3 48, W9 4,500, G3 300, AS1 40, S1 80, AP2 10, A1 16", "")
	local function counted(t) return C.CraftWeekCounted(t) end
	local x1, t1, n1 = counted({ WkW = 1, WkE = 600 })
	local x2 = counted({ WkW = 1, WkE = 2000 })
	local x3, t3 = counted({ WkW = 1, Wk_W3 = 1632 })
	local x4, t4, n4 = counted({ WkW = 1, Wk_W9 = 4500 })
	local x5, t5 = counted({ WkW = 1, WkE = 400, Wk_W3 = 624 })
	check(x1 == 500 and t1 == 1 and n1 == 1000, "W2 x30 (600 easy XP): 400 + 200 / 2 = 500 = tier 1, next 1,000", show({ x1, t1, n1 }))
	check(x2 == 600, "the easy bundle stops at 600 (W2 x100)", tostring(x2))
	check(x3 == 1600 and t3 == 3, "W3 x34 (1,632): the recipe cap 1,600 = tier 3", show({ x3, t3 }))
	check(x4 == 4500 and t4 == 3 and n4 == nil, "one W9 (4,500 > the cap): all of it counts, tier 3, no next", show({ x4, t4, n4 }))
	check(x5 == 1024 and t5 == 2, "W2 x20 + W3 x13 = 400 + 624 = 1,024 = tier 2", show({ x5, t5 }))
	check(counted({}) == 0 and counted(nil) == 0 and counted({ WkE = -5, Wk_W3 = 0 / 0 }) == 0, "an empty / broken ledger counts 0", "")

	local function wk(w) return C.WeekIndex(w.Time) end
	-- a craft with presses counts its craft XP; CraftInfo.Week shows it
	local w = cWorld()
	local p, d = smith(w, 1)
	d.Items.Herb = 60
	startAndHammer(w, p, HONEST, { Recipe = "W2" })
	local info = last(fired(w, "CraftInfo", p))
	check(d.Craft.WkW == wk(w) and d.Craft.WkE == 20 and info.Week and info.Week.XP == 20 and info.Week.Tier == 0 and info.Week.Next == 500
		and info.Week.EndsAt == C.WeekStart(wk(w) + 1), "a hammered W2: 20 easy XP this week (CraftInfo.Week 20 / next 500, the week's end)", show(info.Week))
	w:Advance(61)
	d.Craft.Smith.Lv = 5 -- W3 = craft Lv5
	startAndHammer(w, p, HONEST, { Recipe = "W3" })
	check(d.Craft.Wk_W3 == 48 and d.Craft.WkE == 20, "W3 (12 min) goes to its own row (48)", show(d.Craft))
	-- no press at all (the hammer screen never answered): the item and the craft XP, no weekly XP
	local q, e = smith(w, 2)
	e.Items.Herb = 60
	startAndHammer(w, q, { false, false, false, false, false }, { Recipe = "W2" })
	check(e.Craft.Smith.XP == 20 and e.Craft.WkW == nil and e.Craft.WkE == nil, "no press: craft XP paid, nothing for the week", show(e.Craft))
	-- five equal offsets (a bot): no weekly XP either
	local b, bd = smith(w, 3)
	bd.Items.Herb = 60
	startAndHammer(w, b, { 30, 30, 30, 30, 30 }, { Recipe = "W2" })
	check(bd.Craft.WkE == nil, "five equal offsets: nothing for the week", show(bd.Craft))
	-- the 2x XP pass: the XP really gained counts
	local x, xd = smith(w, 4)
	xd.Items.Herb = 60
	w.PassXP2[x] = true
	startAndHammer(w, x, HONEST, { Recipe = "W2" })
	check(xd.Craft.WkE == 40, "with the 2x XP pass: 40 counted (the XP really gained)", tostring(xd.Craft.WkE))
	-- a waiting craft with a press finishes at the join and counts; one without a press does not
	local j, jd = smith(w, 5, { Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {},
		Pend = { Id = "W2", Plus = 1, Gold = 40, Mats = { Herb = 3 }, Hit = true } } })
	check(jd.Craft.Pend == nil and jd.Craft.WkE == 20, "a pressed waiting craft, finished at the join: 20 for the week", show(jd.Craft))
	local k, kd = smith(w, 6, { Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {},
		Pend = { Id = "W2", Plus = -1, Gold = 40, Mats = { Herb = 3 } } } })
	check(kd.Craft.Pend == nil and kd.Craft.WkE == nil, "an unpressed waiting craft: nothing for the week", show(kd.Craft))
	-- a Knight finishing an old artisan craft: no craft XP, so nothing for the week
	local h, hd = smith(w, 7, { Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {},
		Pend = { Id = "W2", Plus = 1, Gold = 40, Mats = { Herb = 3 }, Hit = true } } }, "Warrior", "Halo")
	check(hd.Craft.WkE == nil, "a Knight's waiting craft (no craft XP): nothing for the week", show(hd.Craft))

	-- the week's end: from Monday 00:00 KST + PayDelay (00:10) the online artisan gets the top tier's bundle, bound
	local g, gd = smith(w, 8)
	local cur = wk(w)
	gd.Craft.WkW, gd.Craft.Wk_W3 = cur, 1700
	gd.HPPotionCount, gd.MPPotionCount = 0, 0
	w:Advance(C.WeekStart(cur + 1) + 300 - w.Time) -- Monday 00:05
	w:Tick(60)
	check(gd.Craft.WkW == cur and (gd.Items.Enh70 or 0) == 0, "Monday 00:05 (before 00:10): not yet", show(gd.Craft))
	local nf = #w.Notices
	w:Advance(C.WeekStart(cur + 1) + 660 - w.Time) -- 00:11
	w:Tick(60)
	check(gd.Craft.WkW == nil and gd.Craft.Wk_W3 == nil and gd.HPPotionCount == 5 and gd.MPPotionCount == 5 and gd.Items.PetTreat == 3
		and gd.Items.Enh70 == 1 and gd.ItemsBound.PetTreat == 3 and gd.ItemsBound.Enh70 == 1 and gd.Craft.GiftW == cur and gd.Craft.GiftT == 3
		and gd.Craft.Gift_HP == nil and gd.Craft.Gift_Enh70 == nil,
		"00:11: tier 3 = HP 5 + MP 5 + Pet Treat 3 + Enh70 1 (bound), the ledger cleared, GiftW / GiftT kept", show({ gd.Craft, gd.Items, gd.ItemsBound }))
	check(keysFor(w, g, nf)[1] == "Config.Craft.Week.Text.Gift" and w.Notices[nf + 1].Kind == "reward", "one soft 'reward' notice (a key)", "")
	local infoG = last(fired(w, "CraftInfo", g))
	check(infoG and infoG.Week.LastW == cur and infoG.Week.LastT == 3 and infoG.Week.XP == 0 and infoG.Week.Wait == nil,
		"CraftInfo.Week after it: last gift week / tier 3, this week 0, nothing waits", infoG and show(infoG.Week) or "")
	w:Tick(60)
	check(gd.Items.Enh70 == 1 and gd.HPPotionCount == 5, "never paid twice", "")
	-- full potions: what fits now, the rest waits (never lost) and comes when there is room
	local f, fd = smith(w, 9)
	local cur2 = wk(w)
	fd.Craft.WkW, fd.Craft.WkE = cur2, 600
	fd.HPPotionCount, fd.MPPotionCount = 98, 99
	w:Advance(C.WeekStart(cur2 + 1) + 700 - w.Time)
	w:Tick(60)
	check(fd.HPPotionCount == 99 and fd.MPPotionCount == 99 and fd.Craft.Gift_HP == 4 and fd.Craft.Gift_MP == 5 and fd.Craft.GiftT == 1,
		"tier 1 with HP 98 / MP 99: 1 HP now, 4 HP + 5 MP wait", show(fd.Craft))
	local infoF = last(fired(w, "CraftInfo", f))
	check(infoF and infoF.Week.Wait and infoF.Week.Wait.HP == 4 and infoF.Week.Wait.MP == 5, "CraftInfo.Week.Wait shows what waits", infoF and show(infoF.Week) or "")
	local nf2 = #w.Notices
	w:Tick(60)
	local spam = 0
	for i = nf2 + 1, #w.Notices do if w.Notices[i].Player == f then spam += 1 end end
	check(spam == 0 and fd.Craft.Gift_HP == 4, "still full a minute later: nothing asked, no 'full' notice every minute", tostring(spam))
	fd.HPPotionCount, fd.MPPotionCount = 90, 90
	w:Tick(60)
	check(fd.HPPotionCount == 94 and fd.MPPotionCount == 95 and fd.Craft.Gift_HP == nil and fd.Craft.Gift_MP == nil, "room again: the rest is paid", show(fd.Craft))
	-- below tier 1: nothing, the ledger just ends
	local s, sd = smith(w, 10)
	local cur3 = wk(w)
	sd.Craft.WkW, sd.Craft.WkE = cur3, 499
	w:Advance(C.WeekStart(cur3 + 1) + 700 - w.Time)
	w:Tick(60)
	check(sd.Craft.WkW == nil and sd.Craft.GiftT == nil and (sd.Items.Enh70 or 0) == 0, "499: no gift, the ledger ends", show(sd.Craft))
	-- a craft of the new week before 00:10 settles the old week first (its gift), the new ledger has only the new craft
	local m, md = smith(w, 11)
	md.Items.Herb = 60
	local cur4 = wk(w)
	md.Craft.WkW, md.Craft.WkE = cur4, 1000
	w:Advance(C.WeekStart(cur4 + 1) + 120 - w.Time) -- Monday 00:02
	startAndHammer(w, m, HONEST, { Recipe = "W2" })
	check(md.Craft.WkW == cur4 + 1 and md.Craft.WkE == 20 and md.Craft.GiftW == cur4 and md.Craft.GiftT == 1 and md.HPPotionCount == 5,
		"a craft at 00:02: last week's 600 -> tier 1 paid, this week starts at 20", show(md.Craft))

	-- offline: a ledger two weeks old is paid at the join (crafting switched off too: it was earned)
	local off = cWorld({ Off = true })
	local old = C.WeekIndex(off.Time) - 2
	local o, od = smith(off, 12, { Craft = { Smith = { Lv = 1, XP = 0 }, Alch = { Lv = 1, XP = 0 }, Tame = { Lv = 1, XP = 0 }, Rep = 0, Made = {},
		WkW = old, WkE = 400, Wk_W3 = 600 } })
	check(od.Craft.WkW == nil and od.Craft.GiftW == old and od.Craft.GiftT == 2 and od.Items.PetTreat == 3 and (od.Items.Enh70 or 0) == 0,
		"a join two weeks later, crafting off: tier 2 (1,000) paid at once", show(od.Craft))

	-- the save repair (flat keys, an older server keeps them)
	local sc = C.SanitizeCraft({ WkW = 2970, WkE = 300.7, Wk_W3 = 48, Wk_ = 5, Gift_HP = 5000, Gift_Enh70 = -1, GiftT = 9, GiftW = "x",
		Pend = { Id = "W2", Plus = 1, Gold = 40, Mats = {}, Hit = true } })
	check(sc.WkW == 2970 and sc.WkE == 300 and sc.Wk_W3 == 48 and sc.Wk_ == nil and sc.Gift_HP == W.WaitMax and sc.Gift_Enh70 == nil
		and sc.GiftT == #W.Tiers and sc.GiftW == nil and sc.Pend.Hit == true,
		"SanitizeCraft keeps the week keys (whole, capped), Pend.Hit; drops broken ones", show(sc))
	local sg = C.SanitizeCraft({ Gift_Nope = 3, Gift_PetTreat = 3, Gift_HP = 2 })
	check(sg.Gift_Nope == nil and sg.Gift_PetTreat == 3 and sg.Gift_HP == 2, "a waiting gift of an unknown item is dropped", show(sg))
	local sn = C.SanitizeCraft({ WkE = 300, Wk_W3 = 48 })
	check(sn.WkE == nil and sn.Wk_W3 == nil, "a ledger without its week is dropped", show(sn))
end)

finish()
