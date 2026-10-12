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
		if edit then edit(c) end
	end
	local w = dev3World(o)
	local ws = newInstance("Workspace", w)
	ws.GetServerTimeNow = function() return w.Time + 0.25 end
	w.Tagged = { CraftStation = {} }
	w.Added = rbxSignal(w.Warnings)
	w.Services.CollectionService = { GetTagged = function(_, tag) return w.Tagged[tag] or {} end,
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
		function L.AddSpare(p, tier, plus)
			if w.SpareFull then return false end
			table.insert(w.Spares, { P = p, Tier = tier, Plus = plus })
			return true
		end
		function L.SpareRoom(p, tier, plus) return not w.SpareFull end
	end
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
	local want = { W1 = { 1, 1, 10, 10 }, W2 = { 2, 1, 40, 20 }, W3 = { 3, 5, 200, 60 }, W4 = { 4, 10, 750, 150 }, W5 = { 5, 15, 2500, 400 },
		W6 = { 6, 20, 7500, 900 }, W7 = { 7, 25, 22500, 2000 }, W9 = { 9, 30, 60000, 4000 } }
	local smithRows = 0
	for _, r in K.Recipes do if r.Role == "Smith" then smithRows += 1 end end
	check(smithRows == 8, "eight blacksmith recipes", tostring(smithRows))
	for id, x in want do
		local r = K.Recipes[id]
		check(r and r.Role == "Smith" and r.Kind == "Weapon" and r.Tier == x[1] and r.Lv == x[2] and r.Gold == x[3] and r.XP == x[4],
			"recipe tier / craft Lv / gold / XP as the design table", id .. " " .. show(r))
	end
	check(K.Recipes.W1.Mats.CopperOre == 2 and K.Recipes.W4.Mats.IronOre == 8 and K.Recipes.W6.Mats.SilverOre == 12
		and K.Recipes.W9.Mats.MoonCrystal == 20 and K.Recipes.W3.Mats.SeaShell == nil and K.Recipes.W5.Mats.CrystalShard == nil,
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
	check(nogem.C.RecipeOn("W7") == nil and nogem.C.RecipeOn("W9") == nil and nogem.C.RecipeOn("W6") ~= nil,
		"without the Clatter Gem item W7 / W9 are off again (the item check stays)", "")
	local gp = smith(nogem, 8)
	startAndHammer(nogem, gp, HONEST)
	local ginfo = last(fired(nogem, "CraftInfo", gp))
	check(ginfo and type(ginfo.On) == "table" and table.concat(ginfo.On, ",") == "W1,W2,W3,W4,W5,W6",
		"CraftInfo.On leaves out the recipes that are off (no Clatter Gem: no W7 / W9)", ginfo and show(ginfo.On) or "")
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
	local p, d = smith(w, 1)
	w.C.TryStart(p, "W2")
	check(type(d.Craft.Pend) == "table" and d.Craft.Pend.Id == "W2" and d.Craft.Pend.Plus == -1 and d.Craft.Pend.Gold == 40
		and d.Craft.Pend.Mats.Jelly == 10 and d.Craft.Pend.Mats.CopperOre == 4, "the save keeps what was paid: Pend { Id, Plus -1, Gold, Mats }",
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
		and S1.Spd[1] == 5 and S1.Spd[2] == 8 and S1.Gold == 100 and S1.Mats.Jelly == 30 and S1.Mats.SlimeCore == 5 and S1.Lv == 1 and S1.XP == 40,
		"S1: research stage 2 (150) + Jelly 30, Slime Core 5, 100 gold -> a baby slime, walk +5..8% before the hammer (crafting_market §4)", show(S1))
	check(T1 and T1.Role == "Tame" and T1.Kind == "Item" and T1.Item == "PetTreat" and T1.N == 3 and T1.Mats.Jelly == 5 and T1.Mats.Herb == 2
		and T1.Mats.Petal == nil, "T1: Jelly 5 + Herb 2 (gathered, 게임성 검수 10/12) -> 3 Pet Treats (+ the hammer's +N)", show(T1))
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
	check(res.Kind == "Pet" and res.Plus == 2 and res.XP == 40 and type(res.Pet) == "table" and res.Pet.Uid == "P11" and res.Pet.Spd == 7
		and res.Pet.Species == "BabySlime" and d.Craft.Tame.Lv == 2 and d.Craft.Tame.XP == 0 and d.Craft.Pend == nil,
		"CraftResult.Pet = { Uid, Species, Spd }; 40 tamer craft XP (Lv2)", show(res.Pet))
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
	dr.Items.Herb = 2
	local st = t.C.TryStart(r, "T1")
	check(st == "ok" and (dr.Items.Herb or 0) == 0, "T1 starts with 2 herbs (no research needed)", tostring(st) .. " " .. tostring(dr.Items.Herb))
	hammer(t, r, HONEST)
	check(dr.Items.PetTreat == 5 and dr.Craft.Tame.XP == 10, "3 + 2 = 5 Pet Treats, 10 craft XP", tostring(dr.Items.PetTreat))
end)

finish()
