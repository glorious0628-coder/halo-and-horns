-- alchemy_offline.luau : alchemy tonics (BuffService, 게임성 개발 3, 2026-10-12; contract docs/design/alchemy_server_2026-10-12.md).
-- tools/test_alchemy.py binds CONFIG_SOURCE, UTIL_SOURCE, LOOT_SOURCE and BUFF_SOURCE in front of dev2_kit.luau +
-- dev3_world.luau; this file follows. LootService (TakeItem / RollKill, from source) and BuffService run from source;
-- PlayerService / TelemetryService are doubles; workspace:GetServerTimeNow = os.time + 0.25. The CombatService and
-- ProgressionService hooks are one line each and checked statically by the runner.

local NOON = 1789959600 -- 2026-09-22 12:00 KST

local function aWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local edit = o.EditConfig
	o.EditConfig = function(c)
		if o.Off ~= true then c.Features.Tonics = true end
		if edit then edit(c) end
	end
	local w = dev3World(o)
	local ws = newInstance("Workspace", w)
	ws.GetServerTimeNow = function() return w.Time + 0.25 end
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
	w.Reg.TelemetryService = { Custom = function(p, name, v, a) table.insert(w.Tele, { P = p, Name = name, V = v, A = a }) end }
	w:Service("LootService", LOOT_SOURCE)
	w:Service("BuffService", BUFF_SOURCE)
	w.Reg.LootService.Init(w.Reg)
	w:InitStart({ "BuffService" })
	w.B = w.Reg.BuffService
	return w
end

local function drinker(w, id, extra)
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 10,
		Items = { MightTonic = 3, GuardTonic = 2, LuckyTonic = 1, WisdomTonic = 1, Jelly = 5 } }
	for k, v in extra or {} do data[k] = v end
	local p, d = w:Arrive(id, { Data = data })
	w.CharFolder = w.CharFolder or newInstance("Folder", w)
	local char = newInstance("Model", w)
	char.Parent = w.CharFolder
	local root = newInstance("Part", w)
	root.Name = "HumanoidRootPart"
	root.Parent = char
	local hum = newInstance("Humanoid", w)
	hum.Health = 100
	hum.Parent = char
	p.Character = char
	return p, d
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function keysFor(w, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Notices do
		local n = w.Notices[i]
		if n.Player == p and n.Key then table.insert(out, n.Key) end
	end
	return out
end

local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-9 end

------------------------------------------------------------------ the table
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local A = C.Alchemy
	check(C.Features.Tonics == false and C.FeatureOn("Tonics") == false, "Config.Features.Tonics is off", "")
	check(A.Duration == 180 and A.Duration == C.SaveV4.BuffSeconds and A.MaxActive == 2 and A.MaxActive == C.SaveV4.BuffMax
		and C.RateLimits.UseTonic == 1, "3 minutes, two at a time (the same numbers as the save repair), one drink a second", show(A))
	local want = { MightTonic = { "MonsterDamage", 1.10 }, GuardTonic = { "MonsterHurt", 0.90 }, LuckyTonic = { "MaterialDrop", 1.25 },
		WisdomTonic = { "HuntXP", 1.10 } }
	check(count(A.Tonics) == 4, "four tonics (no speed tonic in the beta)", tostring(count(A.Tonics)))
	local order = {}
	for i, id in C.Loot.Order do order[id] = i end
	for id, x in want do
		local t, it = A.Tonics[id], C.Loot.Items[id]
		check(t and t.Stat == x[1] and t.Mult == x[2], "tonic effects: Might +10% hits, Guard -10% hurt, Lucky x1.25 materials, Wisdom +10% XP",
			id .. " " .. show(t))
		check(it and it.Kind == "Tonic" and it.Source == "Craft" and type(it.Name) == "string" and it.Icon == "Icon" .. id and order[id] ~= nil,
			"a tonic item: Kind Tonic, Source Craft (never in the Forge's sell-all), a name, an icon key, in the bag order", id)
	end
	local rec = { A1 = { "MightTonic", 1, 20 }, A2 = { "GuardTonic", 3, 30 }, A3 = { "LuckyTonic", 8, 60 }, A4 = { "WisdomTonic", 12, 100 } }
	for id, x in rec do
		local r = C.Craft.Recipes[id]
		check(r and r.Role == "Alch" and r.Kind == "Item" and r.Item == x[1] and r.N == 1 and r.Lv == x[2] and r.Gold == x[3],
			"alchemist recipes A1..A4: one bottle (+ the hammer's +N), craft Lv 1 / 3 / 8 / 12, gold 20 / 30 / 60 / 100", id .. " " .. show(r))
	end
	check(C.Craft.Recipes.A1.Mats.Herb == 3 and C.Craft.Recipes.A3.Mats.Glowcap == 3 and C.Craft.Recipes.A2.Mats.SeaShell == nil
		and C.Craft.Recipes.A3.Mats.CrystalShard == nil, "gathered herbs / glowcaps in the tonics (no Sea Shell / Crystal Shard)", "")
	check(type(A.Text.TwoMax) == "string" and type(A.Text.NoTonic) == "string", "two short refusal texts", "")
end)

------------------------------------------------------------------ drinking
runGroup("use", function()
	local off = aWorld({ Off = true })
	local p0 = drinker(off, 1)
	check(off.B.Use(p0, "MightTonic") == "off" and off.B.Mult(p0, "MonsterDamage") == 1, "switch off: nothing to drink, Mult 1", "")

	local w = aWorld()
	local p, d = drinker(w, 1)
	check(w.B.Use(p, "Jelly") == "tonic" and w.B.Use(p, "Nope") == "tonic", "not a tonic: refused", "")
	check(p:GetAttribute("Buff_MightTonic") == 0, "at the join every Buff_<tonic> is 0", tostring(p:GetAttribute("Buff_MightTonic")))
	check(w.B.Use(p, "MightTonic") == "ok" and d.Items.MightTonic == 2 and d.Buffs.MightTonic == w.Time + 180,
		"one Might Tonic: a bottle goes, data.Buffs.MightTonic = now + 180", show(d.Buffs))
	check(p:GetAttribute("Buff_MightTonic") == w.Time + 0.25 + 180 and p:GetAttribute("Buff_GuardTonic") == 0,
		"the attribute Buff_MightTonic = the server time it ends", tostring(p:GetAttribute("Buff_MightTonic")))
	w:Advance(60)
	check(w.B.Use(p, "MightTonic") == "ok" and d.Buffs.MightTonic == w.Time + 180 and d.Items.MightTonic == 1,
		"the same tonic again starts its 3 minutes over (never longer)", show(d.Buffs))
	check(w.B.Use(p, "GuardTonic") == "ok", "a second, different tonic: ok", "")
	local from = #w.Notices
	check(w.B.Use(p, "LuckyTonic") == "two" and d.Items.LuckyTonic == 1, "a third different one waits (two at a time), the bottle stays", "")
	check(keysFor(w, p, from)[1] == "Config.Alchemy.Text.TwoMax", "TwoMax notice (a key)", "")
	check(w.B.Use(p, "MightTonic") == "ok", "refreshing one of the two is fine", "")
	w:Advance(181)
	check(p:GetAttribute("Buff_MightTonic") == 0 and d.Buffs.MightTonic == nil and p:GetAttribute("Buff_GuardTonic") == 0,
		"3 minutes later: the attributes go to 0 and the ended tonics leave the save", show(d.Buffs))
	check(w.B.Use(p, "LuckyTonic") == "ok", "after they ran out a new one fits", "")
	local from2 = #w.Notices
	check(w.B.Use(p, "LuckyTonic") == "none" and keysFor(w, p, from2)[1] == "Config.Alchemy.Text.NoTonic", "no bottle left: NoTonic (a key)", "")
	local q = drinker(w, 2)
	w.Ready[q] = false
	check(w.B.Use(q, "MightTonic") == "state", "a player not ready: refused", "")
	w.Ready[q] = true
	q.Character:FindFirstChildOfClass("Humanoid").Health = 0
	check(w.B.Use(q, "MightTonic") == "state", "a KO'd player: refused", "")
	local tl = 0
	for _, t in w.Tele do if t.Name == "TonicUse" and t.P == p then tl += 1 end end
	check(tl == 5, "every drink logs TonicUse", tostring(tl))
end)

------------------------------------------------------------------ the multipliers
runGroup("mult", function()
	local w = aWorld()
	local p = drinker(w, 1)
	check(w.B.Mult(p, "MonsterDamage") == 1 and w.B.Mult(p, "HuntXP") == 1, "no tonic: every Mult is 1", "")
	w.B.Use(p, "MightTonic")
	w.B.Use(p, "WisdomTonic")
	check(near(w.B.Mult(p, "MonsterDamage"), 1.10) and near(w.B.Mult(p, "HuntXP"), 1.10) and w.B.Mult(p, "MonsterHurt") == 1
		and w.B.Mult(p, "MaterialDrop") == 1, "Might x1.1 hits, Wisdom x1.1 XP; the others stay 1", "")
	local q = drinker(w, 2)
	w.B.Use(q, "GuardTonic")
	w.B.Use(q, "LuckyTonic")
	check(near(w.B.Mult(q, "MonsterHurt"), 0.90) and near(w.B.Mult(q, "MaterialDrop"), 1.25), "Guard x0.9 hurt, Lucky x1.25 materials", "")
	check(w.B.Mult(q, "MonsterDamage") == 1, "one player's tonic never helps another", "")
	w.Config.Features.Tonics = false
	check(w.B.Mult(p, "MonsterDamage") == 1, "switch off at run time: Mult 1", "")
	w.Config.Features.Tonics = true
	w:Advance(181)
	check(w.B.Mult(p, "MonsterDamage") == 1 and w.B.Mult(q, "MonsterHurt") == 1, "ended: 1 again", "")
	check(w.B.Mult(nil, "MonsterDamage") == 1 and w.B.Mult("x", "HuntXP") == 1, "no player: 1 (never throws)", "")
end)

------------------------------------------------------------------ a join with running tonics
runGroup("join", function()
	local w = aWorld()
	local p, d = drinker(w, 1, { Buffs = { MightTonic = NOON + 100, Nope = NOON + 100 } })
	check(p:GetAttribute("Buff_MightTonic") == NOON + 100 + 0.25 and near(w.B.Mult(p, "MonsterDamage"), 1.10),
		"a tonic still running at the join shows and works", tostring(p:GetAttribute("Buff_MightTonic")))
	w:Advance(101)
	check(p:GetAttribute("Buff_MightTonic") == 0 and w.B.Mult(p, "MonsterDamage") == 1, "... and runs out on time", "")
	local q = drinker(w, 2, { Buffs = { GuardTonic = w.Time - 5 } })
	check(q:GetAttribute("Buff_GuardTonic") == 0 and w.B.Mult(q, "MonsterHurt") == 1, "a tonic that ended before the join does nothing", "")
end)

------------------------------------------------------------------ the remote
runGroup("remote", function()
	local w = aWorld()
	local p, d = drinker(w, 1)
	w.Gap = 1.1
	w:Remote("UseTonic", p, "MightTonic", "x")
	w:Remote("UseTonic", p, 5)
	check(d.Items.MightTonic == 3, "UseTonic with two arguments or a number: ignored", "")
	w:Remote("UseTonic", p, "MightTonic")
	check(d.Items.MightTonic == 2, "UseTonic(MightTonic): one drunk", "")
	w.Gap = 0.5
	w:Remote("UseTonic", p, "GuardTonic")
	check(d.Items.GuardTonic == 2, "a second drink within a second: rate limited", "")
	w.Gap = 1.1
	w:Remote("UseTonic", p, "GuardTonic")
	check(d.Items.GuardTonic == 1, "a second later: drunk", "")
end)

------------------------------------------------------------------ the Lucky Tonic in a kill's drops (LootService from source)
runGroup("loot", function()
	local w = aWorld()
	local L = w.Reg.LootService
	local function kill(p, draws)
		w.Script = draws
		L.RollKill(p, { Kind = "Slime", Position = vec(0, 0, 0) })
		w:Flush()
	end
	local nine = { 0.99, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99 }
	local plain, dp = drinker(w, 1)
	local before = dp.Items.Jelly
	kill(plain, { 0.35, table.unpack(nine) })
	check(dp.Items.Jelly == before, "a draw of 0.35 misses the slime's 30% jelly row without a tonic", tostring(dp.Items.Jelly))
	local lucky, dl = drinker(w, 2)
	w.B.Use(lucky, "LuckyTonic")
	local b2 = dl.Items.Jelly
	kill(lucky, { 0.35, table.unpack(nine) })
	check(dl.Items.Jelly == b2 + 1, "with a Lucky Tonic the jelly row is 37.5%: 0.35 hits", tostring(dl.Items.Jelly))
	local scroll = dl.Items.Enh70 or 0
	kill(lucky, { 0.99, 0.0035, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99, 0.99 })
	check((dl.Items.Enh70 or 0) == scroll, "a scroll row stays as it was (0.3%: a draw of 0.0035 misses even with the tonic)", "")
end)

finish()
