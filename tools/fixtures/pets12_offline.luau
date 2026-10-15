-- pets12_offline.luau : A23-194 (최종 검수 10/15) the 12 beta pets - the species table, Config.PetReady / PetBonus,
-- PetService.Bonus / BonusExtra (0 in a PvP zone), the bonus attributes and the sure gifts (Config.PetGrants). tools/test_pets12.py
-- binds CONFIG_SOURCE, UTIL_SOURCE and PET_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows.

local NOON = 1789959600 -- 2026-09-22 12:00 KST

local function pWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local edit = o.EditConfig
	o.EditConfig = function(c)
		if o.AllReady then c.Pets.ShowUnready = true end
		if edit then edit(c) end
	end
	local w = dev3World(o)
	local Signal = w.Util.Signal
	w.Services.ServerStorage = newInstance("ServerStorage", w)
	w.PS.RefreshSpeed = function() end
	w.Pvp = {}
	w.Reg.ZoneService.IsPvPZone = function(p) return w.Pvp[p] == true end
	w.Reg.GooseService = { GooseRewarded = Signal.new() }
	w.Reg.KaijuService = { KaijuEnded = Signal.new() }
	w.Reg.FieldBossService = { Defeated = Signal.new() }
	w.Reg.StoryQuestService = { QuestDone = Signal.new(), Picked = Signal.new() }
	w.Reg.ProgressionService.LeveledUp = Signal.new()
	w:Service("PetService", PET_SOURCE)
	w:InitStart({ "PetService" })
	w.P = w.Reg.PetService
	return w
end

local function player(w, id, faction, extra)
	local data = { Faction = faction or "Halo", Class = "Warrior", ClassChosen = true, Level = 20,
		Story = { Main = { Id = "" }, Subs = {}, Done = {}, Pick = {}, First = {} } }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

local function species(d)
	local out = {}
	for _, p in d.Pets.List do out[p.Sp] = (out[p.Sp] or 0) + 1 end
	return out
end

------------------------------------------------------------------ the table
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local S = C.Pets.Species
	local ids = {}
	for id in S do table.insert(ids, id) end
	table.sort(ids)
	check(#ids == 12 and table.concat(ids, ",") == "AcornGoblin,BabySlime,BonePup,CrownSlime,FlowerSlime,GearMouse,GoldenGosling,HaloChick,HornsBat,MiniClatter,PocketKaiju,SproutGoblin",
		"12 species (pets_roster.md)", table.concat(ids, ","))
	local bad = {}
	local kinds = { Speed = true, Potion = true, KillGold = true, KillXP = true, MatLuck = true, None = true }
	local rar = { Common = true, Fine = true, Rare = true, Event = true }
	local acq = { Story = true, Craft = true, Quest = true, Event = true }
	for id, def in S do
		if type(def.Name) ~= "string" or def.Name == "" or type(def.Icon) ~= "string" or not rar[def.Rarity]
			or type(def.Family) ~= "string" or not acq[def.Acquire] or type(def.Bonus) ~= "table" or not kinds[def.Bonus.Type]
			or type(def.Ready) ~= "boolean" then
			table.insert(bad, id)
		elseif def.Bonus.Type == "Speed" and type(def.Speed) ~= "table" then
			table.insert(bad, id .. " (Speed line)")
		elseif def.Bonus.Type ~= "Speed" and def.Bonus.Type ~= "None" and not (type(def.Bonus.Min) == "number"
			and type(def.Bonus.Max) == "number" and def.Bonus.Min > 0 and def.Bonus.Max >= def.Bonus.Min) then
			table.insert(bad, id .. " (Min / Max)")
		elseif def.Bonus.Type == "None" and type(def.Emote) ~= "string" then
			table.insert(bad, id .. " (Emote)")
		end
	end
	check(#bad == 0, "every species: Name, Icon, Rarity, Family, Acquire, Bonus { Type, Min / Max | Speed line | Emote }, Ready", table.concat(bad, ", "))
	local caps = { Potion = 0.03, KillGold = 0.02, KillXP = 0.02, MatLuck = 0.01 }
	local over = {}
	for id, def in S do
		local cap = caps[def.Bonus.Type]
		if cap and def.Bonus.Max > cap then table.insert(over, id) end
	end
	check(#over == 0 and S.FlowerSlime.Bonus.Max == 0.03 and S.SproutGoblin.Bonus.Max == 0.02 and S.AcornGoblin.Bonus.Max == 0.01
		and S.BonePup.Bonus.Type == "KillXP" and S.GoldenGosling.Bonus.Type == "KillGold" and S.GearMouse.Bonus.Type == "KillXP",
		"tiny caps: potion +3%, kill gold / XP +2%, material luck x1.01", table.concat(over, ","))
	local ready = {}
	for id, def in S do if def.Ready then table.insert(ready, id) end end
	check(#ready == 1 and ready[1] == "BabySlime" and C.Pets.ShowUnready == false and C.PetReady("BabySlime") and not C.PetReady("FlowerSlime")
		and not C.PetReady("Dragon") and not C.PetReady(nil), "only the Baby Slime has a model (Ready); the rest hidden", table.concat(ready, ","))
	check(S.HaloChick.Speed[1] == 0.07 and S.HaloChick.Speed[2] == 0.10 and S.HornsBat.Speed[2] == 0.10, "Halo Chick / Horns Bat: walk +7 -> 10%", "")
	-- PetBonus
	check(C.PetBonus("FlowerSlime", 1, "Potion") == 0.01 and math.abs(C.PetBonus("FlowerSlime", 10, "Potion") - 0.03) < 1e-9
		and math.abs(C.PetBonus("FlowerSlime", 99, "Potion") - 0.03) < 1e-9 and math.abs(C.PetBonus("FlowerSlime", 5.5, "Potion") - (0.01 + 0.02 * 4 / 9)) < 1e-9,
		"PetBonus: Min at Lv1 -> Max at MaxLv, levels clamped / floored", show({ C.PetBonus("FlowerSlime", 1, "Potion"), C.PetBonus("FlowerSlime", 10, "Potion") }))
	check(C.PetBonus("FlowerSlime", 10, "KillGold") == 0 and C.PetBonus("CrownSlime", 10, "None") == 0 and C.PetBonus("Dragon", 5, "KillXP") == 0
		and C.PetBonus("SproutGoblin", 0 / 0, "KillGold") == 0.01, "PetBonus: another kind / None / unknown = 0; NaN level = Lv1", "")
	check(C.PetBonus("BabySlime", 4, "Speed") == C.PetSpeedBonus("BabySlime", 4) and C.PetBonus("BabySlime", 4, "Speed", 8) == C.PetSpeedBonus("BabySlime", 4, 8),
		"PetBonus Speed = PetSpeedBonus (roll too)", "")
	-- the gift rows and the summon recipes
	local G = C.PetGrants
	local rows = {}
	for _, r in G do rows[r.Id] = r end
	check(#G == 7 and rows.GoldenGosling.Count == "Goose" and rows.GoldenGosling.Need == 3 and rows.CrownSlime.Count == "KingSlime"
		and rows.CrownSlime.Need == 5 and rows.MiniClatter.Count == "Clatter" and rows.PocketKaiju.Count == "Kaiju"
		and rows.HaloChick.Factions.Halo and rows.HornsBat.Factions.Horns and rows.GearMouse.Factions.Neutral
		and C.PetGrantBoss.SlimeKing == "KingSlime" and C.PetGrantBoss.Clatter == "Clatter" and type(C.Data.Defaults.PetGrants) == "table",
		"PetGrants: goose 3 / King 5 / Clatter 3 / kaiju 3 / side quests x3; PetGrantBoss; save default", "")
	local R = C.Craft.Recipes
	check(R.S2.Species == "FlowerSlime" and R.S3.Species == "SproutGoblin" and R.S4.Species == "AcornGoblin" and R.S5.Species == "BonePup"
		and R.S2.Spd == nil and R.S5.Spd == nil and R.S4.Research == 400 and R.S2.Family == "Slime" and R.S5.Family == "Skeleton"
		and R.S1.Spd ~= nil, "Craft S2-S5 (no walk roll), S1 keeps its roll", "")
end)

------------------------------------------------------------------ the bonus
runGroup("bonus", function()
	local w = pWorld({ AllReady = true })
	local p, d = player(w, 1)
	check(w.P.Bonus(p, "KillGold") == 0 and p:GetAttribute("PetBonus") == nil, "no pet: no bonus, no attribute", "")
	d.Pets = { List = { P1 = { Sp = "SproutGoblin", Lv = 10, XP = 0, Name = "", Lean = "", Bound = true } }, Equipped = { "P1" }, Next = 2, Away = false }
	w.P.Refresh(p)
	check(math.abs(w.P.Bonus(p, "KillGold") - 0.02) < 1e-9 and w.P.Bonus(p, "KillXP") == 0, "Sprout Goblin Lv10: kill gold +2%, nothing else", "")
	check(p:GetAttribute("PetBonusType") == "KillGold" and math.abs(p:GetAttribute("PetBonus") - 0.02) < 1e-9,
		"attributes PetBonusType KillGold / PetBonus 0.02", show({ p:GetAttribute("PetBonusType"), p:GetAttribute("PetBonus") }))
	local sum = 0
	for _ = 1, 10 do sum += w.P.BonusExtra(p, "KillGold", 5) end
	check(sum == 1, "10 kills of 5 gold at +2%: 1 extra gold (the fraction carried)", tostring(sum))
	check(w.P.BonusExtra(p, "KillGold", 0) == 0 and w.P.BonusExtra(p, "KillGold", -5) == 0 and w.P.BonusExtra(p, "KillXP", 1000) == 0,
		"no base / another kind: 0", "")
	w.Pvp[p] = true
	check(w.P.Bonus(p, "KillGold") == 0 and w.P.BonusExtra(p, "KillGold", 1000) == 0, "in a PvP zone / the Crown Pit: 0", "")
	w.Pvp[p] = nil
	check(w.P.BonusExtra(p, "KillGold", 1000) == 20, "out of it again: 1000 x 2% = 20", "")
	d.Pets.List.P1.Sp = "CrownSlime"
	w.P.Refresh(p)
	check(w.P.Bonus(p, "KillGold") == 0 and p:GetAttribute("PetBonusType") == nil and p:GetAttribute("PetBonus") == nil,
		"a look-only pet (None): no bonus, no attributes", "")
	-- not Ready (the real switch): no bonus even when owned
	local v = pWorld()
	local q, dq = player(v, 2)
	dq.Pets = { List = { P1 = { Sp = "FlowerSlime", Lv = 10, XP = 0, Name = "", Lean = "", Bound = true } }, Equipped = { "P1" }, Next = 2, Away = false }
	check(v.P.Bonus(q, "Potion") == 0, "a species not Ready gives nothing", "")
	local u, du = player(v, 3)
	du.Pets = { List = { P1 = { Sp = "BabySlime", Lv = 1, XP = 0, Name = "", Lean = "", Bound = true } }, Equipped = { "P1" }, Next = 2, Away = false }
	v.P.Refresh(u)
	check(u:GetAttribute("PetBonusType") == "Speed" and math.abs(u:GetAttribute("PetBonus") - 0.07) < 1e-9, "the Baby Slime: Speed 0.07", "")
end)

------------------------------------------------------------------ summons
runGroup("summon", function()
	local w = pWorld({ AllReady = true })
	local p, d = player(w, 1)
	check(type(w.P.SummonPet(p, "FlowerSlime", nil)) == "string", "a no-roll species is summoned without a roll", "")
	check(w.P.SummonPet(p, "BabySlime", nil) == nil and type(w.P.SummonPet(p, "BabySlime", { Spd = 6 })) == "string",
		"the walk-speed species still needs its roll", "")
	check(w.P.SummonPet(p, "FlowerSlime", { Spd = 99 }) == nil, "a bad roll given is refused", "")
	local v = pWorld()
	local q = player(v, 2)
	check(v.P.SummonPet(q, "FlowerSlime", nil) == nil, "not Ready: no summon", "")
end)

------------------------------------------------------------------ the gifts
runGroup("gifts", function()
	local w = pWorld({ AllReady = true })
	local p, d = player(w, 1, "Halo", { Level = 4 })
	local G = w.Reg.GooseService.GooseRewarded
	G:Fire(p, {})
	G:Fire(p, {})
	G:Fire(p, {})
	check(d.PetGrants.N.Goose == 3 and species(d).GoldenGosling == nil, "3 goose rounds at Lv4: counted, no gosling yet (Lv5)", show(d.PetGrants))
	d.Level = 5
	w.Reg.ProgressionService.LeveledUp:Fire(p, 5)
	check(species(d).GoldenGosling == 1 and d.PetGrants.Got.GoldenGosling == true, "Lv5: the Golden Gosling comes", show(species(d)))
	G:Fire(p, {})
	check(species(d).GoldenGosling == 1, "never twice", "")
	for uid, row in d.Pets.List do if row.Sp == "GoldenGosling" then d.Pets.List[uid] = nil end end
	d.Pets.Equipped = {}
	G:Fire(p, {})
	check(species(d).GoldenGosling == nil, "a gift once got never comes again (even when the row is gone)", "")
	d.Level = 30
	-- field bosses by UserId
	local B = w.Reg.FieldBossService.Defeated
	for _ = 1, 4 do B:Fire("SlimeKing", "SlimeKing", { p.UserId }, {}) end
	check(species(d).CrownSlime == nil and d.PetGrants.N.KingSlime == 4, "4 King kills: not yet", "")
	B:Fire("SlimeKing", "SlimeKing", { p.UserId, 99999 }, {})
	check(species(d).CrownSlime == 1, "the 5th: the Crown Slime (an unknown UserId is skipped)", show(species(d)))
	B:Fire("Clatter", "CaptainClatter", { p.UserId }, {})
	B:Fire("Nope", "Nope", { p.UserId }, {})
	check(d.PetGrants.N.Clatter == 1 and d.PetGrants.N.Nope == nil, "Clatter counts, an unknown boss does not", show(d.PetGrants.N))
	-- kaiju: the kaiju and every participant, once each, only Defeated / Survived
	local q, dq = player(w, 2, "Horns")
	local K = w.Reg.KaijuService.KaijuEnded
	K:Fire(q, "Cancelled", { p })
	check((dq.PetGrants and dq.PetGrants.N.Kaiju or 0) == 0, "a cancelled kaiju counts nothing", "")
	for _ = 1, 3 do K:Fire(q, "Survived", { p, p }) end
	check(dq.PetGrants.N.Kaiju == 3 and d.PetGrants.N.Kaiju == 3 and species(dq).PocketKaiju == 1 and species(d).PocketKaiju == 1,
		"3 kaiju events: the kaiju and the participant (listed twice = once) get the Pocket Kaiju", show({ dq.PetGrants.N, d.PetGrants.N }))
	-- side quests
	local QD = w.Reg.StoryQuestService.QuestDone
	d.Story.Done.H2, d.Story.Done.H3 = true, true
	QD:Fire(p, "H3")
	check(species(d).HaloChick == nil, "2 of 3 care quests: no chick", "")
	d.Story.Done.H6 = true
	QD:Fire(p, "H6")
	check(species(d).HaloChick == 1, "H2 + H3 + H6: the Halo Chick", show(species(d)))
	dq.Story.Done.H2, dq.Story.Done.H3, dq.Story.Done.H6 = true, true, true
	QD:Fire(q, "H6")
	check(species(dq).HaloChick == nil, "a Horns player never gets the Halo Chick", "")
	-- the join's catch-up (quiet), a pet owned already counts as got
	local n0 = #w.Notices
	local r, dr = player(w, 3, "Neutral", { Level = 12, PetGrants = { N = { Goose = 7, Bad = "x" }, Got = { Old = 1 } },
		Story = { Main = { Id = "" }, Subs = {}, Done = { N0b = true, N2 = true, N4 = true }, Pick = {}, First = {} },
		Pets = { List = { P1 = { Sp = "GoldenGosling", Lv = 3, XP = 0, Name = "", Lean = "", Bound = true } }, Equipped = { "P1" }, Next = 2, Away = false } })
	check(species(dr).GoldenGosling == 1 and dr.PetGrants.Got.GoldenGosling == true and species(dr).GearMouse == 1,
		"join: an owned gosling = got (no second); the guild quests done -> the Gear Mouse", show(species(dr)))
	check(dr.PetGrants.N.Bad == nil and dr.PetGrants.Got.Old == nil, "junk in the save is dropped", show(dr.PetGrants))
	w:RunSpawned()
	local quiet = true
	for i = n0 + 1, #w.Notices do if w.Notices[i].Player == r then quiet = false end end
	check(quiet, "no line for a gift (A23-191)", "")
	-- not Ready (the real switch): counted, never given
	local v = pWorld()
	local s, ds = player(v, 4)
	for _ = 1, 3 do v.Reg.GooseService.GooseRewarded:Fire(s, {}) end
	check(ds.PetGrants.N.Goose == 3 and species(ds).GoldenGosling == nil and ds.PetGrants.Got.GoldenGosling == nil,
		"no model yet: the goose rounds count, no pet, not marked got", show(ds.PetGrants))
	check(#w.Warnings == 0 and #v.Warnings == 0, "no warnings", show(w.Warnings))
end)

finish()
