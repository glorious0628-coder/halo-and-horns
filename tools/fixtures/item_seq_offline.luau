-- A23-32 bag sort '얻은 순': the server's order numbers (data.ItemSeq / data.WeaponSeq / data.ItemSeqNext), run offline.
-- tools/test_item_seq.py injects (before tools/fixtures/dev2_kit.luau): CONFIG_SOURCE, UTIL_SOURCE, LOOT_SOURCE (whole
-- LootService). Gains come through the real paths: RollKill (MonsterKilled), DebugGive, and SetStat of the mirrored
-- potion / weapon-ownership stats (what ShopService, QuestService, StoryQuestService and the drops all do).

local C0 = execute("Config", CONFIG_SOURCE, nativeEnv())

-- a server with the real LootService; o.Saved = a whole save from an earlier session
local function seqWorld()
	local w = newWorld({})
	local cfg = w.Config
	local Signal = w.Util.Signal
	local data = {}
	w.Data = data
	local mirrored = {}
	for _, key in cfg.Data.Mirrored do mirrored[key] = true end
	local ps = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new(), CharacterSpawned = Signal.new() }
	function ps.GetData(p) return data[p] end
	function ps.IsReady(p) return w.Ready[p] == true and p.Parent ~= nil end
	function ps.GetReadyPlayers()
		local out = {}
		for _, p in w.PlayerList do if w.Ready[p] then table.insert(out, p) end end
		return out
	end
	function ps.SetStat(p, key, value)
		local d = data[p]
		if not d then return end
		d[key] = value
		if mirrored[key] then p:SetAttribute(key, value) end
	end
	function ps.MarkActive() end
	local reg = { PlayerService = ps,
		ClassService = { GetClass = function() return "Warrior" end },
		ProgressionService = { AddCarriedGold = function() end },
		CombatService = { IsInCombat = function() return false end },
		MonsterService = { MonsterKilled = Signal.new() },
		ShopService = { CanBuyWeapon = function() return true end },
		AnnounceService = { Announce = function() end },
	}
	w.PS, w.Registry = ps, reg
	local loot = w:Load("LootService", LOOT_SOURCE)
	reg.LootService = loot
	loot.Init(reg)
	loot.Start()
	w.Spawned = {}
	w.Loot = loot
	function w:Join(userId, saved)
		local p = self:NewPlayer(userId, {})
		local d = saved or deepCopy(cfg.Data.Defaults)
		-- what DataService.fillDefaults does for this field set (an old save without the fields gets the defaults)
		for k, v in cfg.Data.Defaults do
			if d[k] == nil then d[k] = deepCopy(v) end
		end
		cfg.SanitizeItemSeq(d)
		d.ClassChosen = true
		data[p] = d
		for key in mirrored do
			if d[key] ~= nil then p:SetAttribute(key, d[key]) end
		end
		self.Ready[p] = true
		ps.PlayerReady:Fire(p, d)
		self:Flush()
		return p, d
	end
	-- one scripted kill: the rows whose Item / Weapon / Potion is in `want` drop, every other row misses
	function w:Drop(p, kind, want)
		local script = {}
		for _, row in cfg.Loot.Tables[kind] do
			local hit = (row.Item and want[row.Item]) or (row.Weapon and want["W" .. row.Weapon]) or (row.Potion and want["P" .. row.Potion])
			table.insert(script, hit and 0 or 0.999999)
		end
		if cfg.Loot.Jackpot.Monsters[kind] then table.insert(script, 0.999999) end
		self.Script = script
		reg.MonsterService.MonsterKilled:Fire(p, { Kind = kind, Golden = false, Position = vec(0, 0, 0) })
		self.Script = nil
		self:Flush()
	end
	function w:Payload(p)
		for i = #self.Fired, 1, -1 do
			local f = self.Fired[i]
			if f.Remote == "Inventory" and f.Player == p then return f.Payload end
		end
		return nil
	end
	return w
end

------------------------------------------------------------------ 1. save fields
runGroup("save-fields", function()
	local C = C0
	local D = C.Data.Defaults
	check(type(D.ItemSeq) == "table" and next(D.ItemSeq) == nil and type(D.WeaponSeq) == "table" and D.ItemSeqNext == 0,
		"defaults: ItemSeq {}, WeaponSeq {}, ItemSeqNext 0 (an old save starts at 0)")
	check(C.ItemSeqPotions.PotionHP == "HPPotionCount" and C.ItemSeqPotions.PotionMP == "MPPotionCount", "potion keys follow the potion stats")
	local d = {}
	C.SanitizeItemSeq(d)
	check(next(d.ItemSeq) == nil and #d.WeaponSeq == C.MaxWeaponTier and d.WeaponSeq[1] == 0 and d.ItemSeqNext == 0,
		"an old save: no numbers, a weapon array of MaxWeaponTier zeros", show(d))
	d = { ItemSeq = { Jelly = 5, Enh70 = 9.7, Nope = 99, PotionHP = 3, Bone = 0, [4] = 7, Candy = -2, SlimeCore = 0 / 0 },
		WeaponSeq = { 2, "x", 12, nil, math.huge }, ItemSeqNext = 4 }
	C.SanitizeItemSeq(d)
	check(d.ItemSeq.Jelly == 5 and d.ItemSeq.Enh70 == 9 and d.ItemSeq.PotionHP == 3 and d.ItemSeq.Nope == nil and d.ItemSeq.Bone == nil
		and d.ItemSeq[4] == nil and d.ItemSeq.Candy == nil and d.ItemSeq.SlimeCore == nil, "unknown keys / junk numbers dropped", show(d.ItemSeq))
	check(d.WeaponSeq[1] == 2 and d.WeaponSeq[2] == 0 and d.WeaponSeq[3] == 12 and d.WeaponSeq[5] == 0 and #d.WeaponSeq == C.MaxWeaponTier,
		"weapon numbers: one per tier, junk -> 0", show(d.WeaponSeq))
	check(d.ItemSeqNext == 12, "ItemSeqNext is never below a number already used (no repeats)", d.ItemSeqNext)
	local okEnc, text = pcall(jsonEncode, d)
	check(okEnc, "the fields JSON-encode (string keys / a dense array)", text)
	if okEnc then
		local back = jsonDecode(text)
		C.SanitizeItemSeq(back)
		check(back.ItemSeq.Jelly == 5 and back.WeaponSeq[3] == 12 and back.ItemSeqNext == 12, "JSON round trip keeps the numbers")
	end
	check(C.NoteGained(d, "Bone") == 13 and d.ItemSeq.Bone == 13 and d.ItemSeqNext == 13, "NoteGained: the next number")
	check(C.NoteGained(d, nil, 4) == 14 and d.WeaponSeq[4] == 14 and d.ItemSeq.Bone == 13, "NoteGained with a tier: the weapon number")
	local e = {}
	check(C.NoteGained(e, "Jelly") == 1 and e.ItemSeq.Jelly == 1 and #e.WeaponSeq == C.MaxWeaponTier, "NoteGained on a bare save repairs it first")
end)

------------------------------------------------------------------ 2. drops: Jelly -> scroll -> Jelly
runGroup("drops", function()
	local w = seqWorld()
	local p, d = w:Join(101)
	w:Drop(p, "Slime", { Jelly = true })
	local afterJelly = d.ItemSeq.Jelly
	w:Drop(p, "Slime", { Enh70 = true })
	w:Drop(p, "Slime", { Jelly = true })
	check(afterJelly == 1 and d.ItemSeq.Enh70 == 2 and d.ItemSeq.Jelly == 3 and d.ItemSeqNext == 3,
		"Jelly -> Enh70 -> Jelly: Jelly is the most recent (3), the scroll 2", show(d.ItemSeq))
	local pay = w:Payload(p)
	check(pay ~= nil and pay.ItemSeq.Jelly == 3 and pay.ItemSeq.Enh70 == 2 and pay.Items.Jelly == 2,
		"the owner's Inventory payload carries ItemSeq", show(pay and pay.ItemSeq))
	check(pay ~= nil and #pay.WeaponSeq == C0.MaxWeaponTier and pay.WeaponSeq[1] == 0, "…and WeaponSeq (one number per tier)", show(pay and pay.WeaponSeq))
	-- a multi-count drop row is one gain
	w:Drop(p, "BigSlime", { SlimeCore = true }) -- (the first king slime also grants its Enh70 scroll)
	check(d.ItemSeq.SlimeCore ~= nil and d.ItemSeq.SlimeCore > d.ItemSeq.Jelly, "a later drop is more recent", show(d.ItemSeq))
	-- a full stack gains nothing: no new number
	d.Items.Bone = C0.Loot.ItemCap
	local n0 = d.ItemSeqNext
	w.Loot.DebugGive(p, "Bone", 1)
	check(d.ItemSeqNext == n0 and d.ItemSeq.Bone == nil, "nothing given (full stack): no number")
	w.AllowWarn = "full"
	w.Loot.DebugGive(p, "Candy", 2)
	check(d.ItemSeq.Candy == n0 + 1, "DebugGive (addItem) is a gain too", d.ItemSeq.Candy)
	-- potions and weapons from a drop
	w:Drop(p, "Goblin", { PHP = true })
	check(d.ItemSeq.PotionHP == d.ItemSeqNext and d.HPPotionCount == 1, "a potion drop: PotionHP is the most recent", show(d.ItemSeq))
	w:Drop(p, "Goblin", { W4 = true })
	check(d.WeaponSeq[4] == d.ItemSeqNext and bit32.btest(d.WeaponOwnedMask, 8), "a weapon drop: WeaponSeq[4] is the most recent", show(d.WeaponSeq))
	w:Flush()
	pay = w:Payload(p)
	check(pay and pay.WeaponSeq[4] == d.WeaponSeq[4] and pay.ItemSeq.PotionHP == d.ItemSeq.PotionHP, "the payload follows the potion / weapon numbers")
end)

------------------------------------------------------------------ 3. any service: the mirrored stats
runGroup("other-paths", function()
	local w = seqWorld()
	local p, d = w:Join(102)
	w.PS.SetStat(p, "MPPotionCount", 3) -- the potion shop / a quest reward
	w:Flush()
	check(d.ItemSeq.PotionMP == 1, "buying MP potions (any service raising MPPotionCount) is a gain", show(d.ItemSeq))
	w.PS.SetStat(p, "MPPotionCount", 2) -- drank one
	w:Flush()
	check(d.ItemSeq.PotionMP == 1 and d.ItemSeqNext == 1, "using a potion is not a gain")
	w.PS.SetStat(p, "WeaponOwnedMask", bit32.bor(d.WeaponOwnedMask, 4)) -- the blacksmith sells tier 3
	w:Flush()
	check(d.WeaponSeq[3] == 2 and d.WeaponSeq[1] == 0, "a weapon bought (a new ownership bit) is a gain for that tier", show(d.WeaponSeq))
	w.PS.SetStat(p, "WeaponOwnedMask", bit32.band(d.WeaponOwnedMask, bit32.bnot(4))) -- sold it back
	w:Flush()
	check(d.WeaponSeq[3] == 2 and d.ItemSeqNext == 2, "selling a weapon is not a gain")
	w.PS.SetStat(p, "WeaponOwnedMask", bit32.bor(d.WeaponOwnedMask, 4 + 16)) -- two new bits at once
	w:Flush()
	check(d.WeaponSeq[3] == 3 and d.WeaponSeq[5] == 4, "two new weapons at once: both noted", show(d.WeaponSeq))
	w.PS.SetStat(p, "HPPotionCount", 5)
	w:Flush()
	local pay = w:Payload(p)
	check(pay and pay.ItemSeq.PotionHP == 5 and pay.WeaponSeq[5] == 4, "every noted gain is pushed to the owner", show(pay and pay.ItemSeq))
	-- the stats a join loads are not gains
	local w2 = seqWorld()
	local q, e = w2:Join(103, (function()
		local s = deepCopy(C0.Data.Defaults)
		s.HPPotionCount, s.WeaponOwnedMask = 4, 1 + 2
		return s
	end)())
	check(next(e.ItemSeq) == nil and e.WeaponSeq[2] == 0 and e.ItemSeqNext == 0, "the values a save loads with are not gains")
	check(q ~= nil, "joined")
	-- a later gain counts only its own bit: the loaded weapons are never noted afterwards either (A23-34: the defaults
	-- own nothing, so this save loads its own bits)
	w2.PS.SetStat(q, "WeaponOwnedMask", bit32.bor(e.WeaponOwnedMask, 4))
	w2:Flush()
	check(e.WeaponSeq[3] == 1 and e.WeaponSeq[1] == 0 and e.WeaponSeq[2] == 0 and e.ItemSeqNext == 1,
		"a later gain counts only the new weapon, never the loaded ones", show(e.WeaponSeq))
end)

------------------------------------------------------------------ 4. a rejoin keeps the order
runGroup("rejoin", function()
	local w = seqWorld()
	local p, d = w:Join(104)
	w:Drop(p, "Slime", { Jelly = true })
	w:Drop(p, "Slime", { Enh70 = true })
	local saved = jsonDecode(jsonEncode(d)) -- what the DataStore keeps
	local w2 = seqWorld()
	local q, e = w2:Join(104, saved)
	local pay = w2:Payload(q)
	check(pay and pay.ItemSeq.Jelly == 1 and pay.ItemSeq.Enh70 == 2, "after a rejoin the payload has the same numbers", show(pay and pay.ItemSeq))
	w2:Drop(q, "Slime", { Jelly = true })
	check(e.ItemSeq.Jelly == 3 and e.ItemSeqNext == 3, "the counter continues (Jelly most recent again)", show(e.ItemSeq))
	-- an old save (no fields at all): every number 0, the first gain is 1
	local old = deepCopy(C0.Data.Defaults)
	old.ItemSeq, old.WeaponSeq, old.ItemSeqNext = nil, nil, nil
	old.Items = { Jelly = 4 }
	local w3 = seqWorld()
	local r, f = w3:Join(105, old)
	pay = w3:Payload(r)
	check(pay and pay.Items.Jelly == 4 and pay.ItemSeq.Jelly == nil and pay.WeaponSeq[1] == 0, "an old save: items without a number (0)", show(pay and pay.ItemSeq))
	w3:Drop(r, "Slime", { Enh70 = true })
	check(f.ItemSeq.Enh70 == 1, "an old save's first gain is 1")
end)

finish()
