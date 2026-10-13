-- codex_offline.luau : A23-153 the monster codex (CodexService, 게임성 개발 2, 2026-10-13; contract
-- docs/design/codex_cards_contract_2026-10-13.md). tools/test_codex.py binds CONFIG_SOURCE, UTIL_SOURCE, CODEX_SOURCE,
-- TITLE_SOURCE, LOG_SOURCE and DATA_EXTRACT (DataService migrate / fillDefaults) in front of dev2_kit.luau + dev3_world.luau;
-- this file follows. CodexService, TitleService and KillLog run from source; PlayerService / ProgressionService /
-- MonsterService.MonsterKilled are the dev3_world doubles.

local NOW = 1790000000 -- the kit's os.time()
local NAN, INF = 0 / 0, math.huge

-- a tiny Instance tree for the card models (Clone / GetDescendants / IsA with BasePart / Destroy / attributes / Parent).
-- fake(className, name, props, children); a parent may be a kit Instance (anything with _children)
local BASEPARTS = { Part = true, MeshPart = true, UnionOperation = true, WedgePart = true }
local fakeMeta = {}
local function fake(className, name, props, children)
	local o = setmetatable({ ClassName = className, Name = name or className, _children = {}, _parent = nil, Attrs = {} }, fakeMeta)
	for k, v in props or {} do rawset(o, k, v) end
	for _, c in children or {} do c.Parent = o end
	return o
end
fakeMeta.M = {
	IsA = function(o, kind)
		return o.ClassName == kind or kind == "Instance" or (kind == "BasePart" and BASEPARTS[o.ClassName] == true)
	end,
	FindFirstChild = function(o, n)
		for _, c in o._children do if c.Name == n then return c end end
		return nil
	end,
	GetChildren = function(o) return table.clone(o._children) end,
	GetDescendants = function(o)
		local out = {}
		local function walk(x)
			for _, c in x._children do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(o)
		return out
	end,
	Clone = function(o)
		if rawget(o, "CloneFails") then error("offline: this model cannot be cloned") end
		local c = setmetatable({ _children = {}, _parent = nil, Attrs = table.clone(o.Attrs) }, fakeMeta)
		for k, v in o do
			if k ~= "_children" and k ~= "_parent" and k ~= "Attrs" then rawset(c, k, v) end
		end
		for _, kid in o._children do kid:Clone().Parent = c end
		return c
	end,
	Destroy = function(o)
		o.Parent = nil
		rawset(o, "Destroyed", true)
	end,
	SetAttribute = function(o, k, v) o.Attrs[k] = v end,
	GetAttribute = function(o, k) return o.Attrs[k] end,
}
fakeMeta.__index = function(o, k)
	if k == "Parent" then return rawget(o, "_parent") end
	return fakeMeta.M[k]
end
fakeMeta.__newindex = function(o, k, v)
	if k == "Parent" then
		local old = rawget(o, "_parent")
		if old then
			local i = table.find(old._children, o)
			if i then table.remove(old._children, i) end
		end
		rawset(o, "_parent", v)
		if type(v) == "table" and v._children then table.insert(v._children, o) end
		return
	end
	rawset(o, k, v)
end

-- a monster model as an import looks: parts that move and collide, a script, a sound, effects, an attachment
local function importedModel(name, extra)
	return fake("Model", name, extra, {
		fake("MeshPart", "Body", { Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true }, {
			fake("Attachment", "RootAttachment"), fake("ParticleEmitter", "Sparkle"), fake("PointLight", "Glow") }),
		fake("Part", "HumanoidRootPart", { Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true }),
		fake("Script", "Brain"), fake("LocalScript", "Bob"), fake("Sound", "Growl"), fake("BillboardGui", "Tag"),
		fake("Folder", "Bits", nil, { fake("Part", "Hat", { Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true },
			{ fake("ModuleScript", "Deep") }) }),
	})
end

local function codexWorld(o)
	o = o or {}
	-- 게임성 개발 1 10/13: the shipped Config.Codex.ServerToast is off (CodexUI.luau shows every line); these worlds test the
	-- server's toast path with it on (a world's own EditConfig still runs after, e.g. turning it off again)
	local edit = o.EditConfig
	local w = dev3World({ EditConfig = function(c)
		c.Codex.ServerToast = true
		if edit then edit(c) end
	end })
	-- the card models: ServerStorage (o.Custom = the CustomModels folder's children, or nil = no folder) and a ReplicatedStorage
	-- that holds children
	w.ServerStorage = fake("ServerStorage", "ServerStorage")
	if o.Custom then fake("Folder", "CustomModels", nil, o.Custom).Parent = w.ServerStorage end
	w.Services.ServerStorage = w.ServerStorage
	local rs = w.Services.ReplicatedStorage
	rs._children = rs._children or {}
	function rs.FindFirstChild(self, n)
		for _, c in self._children do if c.Name == n then return c end end
		return rawget(self, n)
	end
	w.AllowWarn = o.AllowWarn
	-- 1 = the doubles answer what they added, like the real ProgressionService (2 = a 2x pass)
	w.GoldMult, w.XPMult = o.GoldMult or 1, o.XPMult or 1
	w:Service("TitleService", TITLE_SOURCE)
	w:Service("KillLog", LOG_SOURCE)
	w:Service("CodexService", CODEX_SOURCE)
	w:InitStart({ "TitleService", "KillLog", "CodexService" })
	-- the bank / pocket split (the dev3_world double uses one function for both)
	local bank = w.Prog.AddBankGold
	w.Prog.AddCarriedGold = function(...)
		w.Carried = true
		return bank(...)
	end
	return w
end

local function hero(w, id, extra)
	local data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 10, WeaponTier = 3 }
	for k, v in extra or {} do data[k] = v end
	return w:Arrive(id, { Data = data })
end

local function kill(w, p, kind, extra)
	local info = { Kind = kind, ZoneId = "SlimeMeadow", Golden = false, Personal = false }
	for k, v in extra or {} do info[k] = v end
	w.Reg.MonsterService.MonsterKilled:Fire(p, info)
	w:RunSpawned()
end

-- the payloads of remote `name` fired to p since index `from`
local function fired(w, name, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Fired do
		local f = w.Fired[i]
		if f.Remote == name and f.Player == p then table.insert(out, f.Payload) end
	end
	return out
end

local function events(w, p, from)
	local out = {}
	for _, e in fired(w, "CodexUp", p, from) do table.insert(out, e.Event) end
	return table.concat(out, ",")
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function sameTable(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then return a == b end
	for k, v in a do if not sameTable(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end

local function hasHangul(s)
	return type(s) == "string" and string.find(s, "[\234-\237][\128-\191][\128-\191]") ~= nil
end

------------------------------------------------------------------ config
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local X = C.Codex
	check(C.Data.Version == 5 and C.Data.Defaults.Version == 5, "save version 5 (A23-153), Data and Defaults equal",
		show({ C.Data.Version, C.Data.Defaults.Version }))
	check(type(C.Data.Defaults.Codex) == "table" and next(C.Data.Defaults.Codex) == nil, "save default Codex = {}", show(C.Data.Defaults.Codex))
	check(X.Enabled == true and sameTable(X.Steps, { 1, 100, 1000 }) and sameTable(X.BossSteps, { 1, 10, 30 }),
		"steps 1 / 100 / 1000, bosses 1 / 10 / 30 (최종 검수 2026-10-13)", show({ X.Steps, X.BossSteps }))
	local want = { "Slime", "FlowerSlime", "BigSlime", "SlimeKing", "Goblin", "SlingshotGoblin", "GoblinBrute", "Skeleton",
		"SkeletonArcher", "SkeletonKnight", "CaptainClatter" }
	check(sameTable(X.Order, want), "series 1 = the 11 beta kinds in page order", table.concat(X.Order, ","))
	local zonesOk = true
	for i, page in X.Pages do
		for _, kind in page.Kinds do
			local def = C.MonsterTypes[kind]
			if not def or def.Zone ~= page.Id or X.PageOf[kind] ~= i or def.Season ~= nil then zonesOk = false end
		end
		if not C.Zones[page.Id] or not C.TitleDefs[page.Title] or not table.find(C.TitleOrder, page.Title) then zonesOk = false end
	end
	check(#X.Pages == 3 and zonesOk, "3 pages; every kind is a year-round monster of its page's zone; each page title is defined and ordered", "")
	check(C.TitleDefs.SlimeScholar.Name == "Slime Scholar" and C.TitleDefs.GoblinScholar.Name == "Goblin Scholar"
		and C.TitleDefs.SkeletonScholar.Name == "Skeleton Scholar", "the page titles", "")
	check(sameTable(X.Reward, { Stage = { 3, 20, 100 }, BossStage = { 1, 3, 10 }, Golden = 5 }), "rewards in kills' worth", show(X.Reward))
	check(C.PassBoost.GoldSources.Codex == true and C.RateLimits.CodexOpen == 1 and X.ServerToast == false,
		"codex gold is earned gold (2x pass), CodexOpen 1 s, the server toast is off (CodexUI shows the lines)", "")
	check(C.CodexCanGold("Slime") and not C.CodexCanGold("SlimeKing") and not C.CodexCanGold("CaptainClatter"),
		"bosses have no Gold Foil card (never golden)", "")
	check(C.CodexStage("Slime", 0) == 0 and C.CodexStage("Slime", 1) == 1 and C.CodexStage("Slime", 99) == 1
		and C.CodexStage("Slime", 100) == 2 and C.CodexStage("Slime", 999) == 2 and C.CodexStage("Slime", 1000) == 3
		and C.CodexStage("Slime", 5000) == 3 and C.CodexStage("SlimeKing", 9) == 1 and C.CodexStage("SlimeKing", 10) == 2 and C.CodexStage("SlimeKing", 29) == 2
		and C.CodexStage("CaptainClatter", 30) == 3, "stage from kills (a boss: 10 / 30)", "")
	local textOk, loreOk = true, true
	for _, k in { "Name", "Card", "Silver", "Holo", "Golden", "Reward", "RewardGold", "Page", "Glow", "Foil", "Before" } do
		local s = X.Text[k]
		if type(s) ~= "string" or s == "" or hasHangul(s) or #s > 60 then textOk = false end
	end
	for _, s in X.Text.Stages do
		if type(s) ~= "string" or hasHangul(s) then textOk = false end
	end
	for _, kind in X.Order do
		for _, side in { "Halo", "Horns", "Neutral" } do
			local s = X.Lore[kind] and X.Lore[kind][side]
			if type(s) ~= "string" or s == "" or hasHangul(s) or #s > 60 then loreOk = false end
		end
	end
	check(textOk and #X.Text.Stages == 3, "every line is short English (no Korean, <= 60 letters)", "")
	check(loreOk and count(X.Lore) == 11, "a card-back line per kind for Halo / Horns / Neutral (short English)", "")
	check(not string.find(X.Text.Card .. X.Text.Silver .. X.Text.Holo .. X.Text.Golden, "%%d"), "names are %s slots", "")
end)

------------------------------------------------------------------ a first card
runGroup("first card", function()
	local w = codexWorld()
	local p, d = hero(w, 1)
	local f0, n0 = #w.Fired, #w.Notices
	kill(w, p, "Slime")
	local e = d.Codex.Slime
	check(e and e.Kills == 1 and e.Golden == 0 and e.Stage == 1 and e.First == NOW, "Codex.Slime = { Kills 1, Golden 0, Stage 1, First now }", show(e))
	local ups = fired(w, "CodexUp", p, f0)
	local u = ups[1]
	check(#ups == 1 and u.Event == "Card" and u.Kind == "Slime" and u.Stage == 1, "one CodexUp Card", show(ups))
	check(u and u.Gold == 9 and u.XP == 15, "the reward = 3 Slime kills' worth (3 x 3 gold, 3 x 5 XP)", show(u))
	check(#w.Gold == 1 and w.Gold[1].Src == "Codex" and w.Gold[1].N == 9 and #w.XPs == 1 and w.XPs[1].N == 15,
		"paid as bank gold 'Codex' + XP", show({ #w.Gold, w.Gold[1] and w.Gold[1].Src, w.Gold[1] and w.Gold[1].N, #w.XPs }))
	check(not w.Carried, "never pocket gold (a robbery never takes it)", "")
	check(u and u.Key == "Config.Codex.Text.Card" and u.Args[1] == "Slime" and u.Text == "New card: Slime! +9 gold · +15 XP",
		"the line: key, args, English text", show(u))
	check(u and u.Card.Kills == 1 and u.Card.Stage == 1 and u.Card.First == NOW, "the card rides along", show(u and u.Card))
	local notes = w:NoticesFor(p, n0)
	check(#notes == 1 and notes[1] == u.Text and w.Notices[#w.Notices].Kind == "reward", "and the same line as a reward toast", show(notes))
	check(p:GetAttribute("CodexCards") == 1 and p:GetAttribute("CodexGlow") == false, "attributes: 1 card, no glow",
		show({ p:GetAttribute("CodexCards"), p:GetAttribute("CodexGlow") }))
	local f1 = #w.Fired
	w:Advance(60)
	kill(w, p, "Slime")
	check(d.Codex.Slime.Kills == 2 and d.Codex.Slime.First == NOW and #fired(w, "CodexUp", p, f1) == 0 and #w.Gold == 1,
		"the second kill only counts (First stays)", show(d.Codex.Slime))
end)

------------------------------------------------------------------ evolving
runGroup("silver and gold holo", function()
	local w = codexWorld()
	local p, d = hero(w, 2, { Codex = { Goblin = { Kills = 98, Golden = 0, Stage = 1, First = 5 } } })
	kill(w, p, "Goblin", { ZoneId = "GoblinWoods" })
	check(d.Codex.Goblin.Kills == 99 and d.Codex.Goblin.Stage == 1, "99 kills: still stage 1", show(d.Codex.Goblin))
	local f0 = #w.Fired
	kill(w, p, "Goblin", { ZoneId = "GoblinWoods" })
	local u = fired(w, "CodexUp", p, f0)[1]
	check(d.Codex.Goblin.Stage == 2 and u and u.Event == "Silver" and u.Stage == 2, "the 100th kill: Silver", show(u))
	check(u and u.Gold == 320 and u.XP == 560 and u.Text == "Goblin card is now Silver! +320 gold · +560 XP",
		"Silver pays 20 Goblin kills' worth", show(u))
	d.Codex.Goblin.Kills = 998
	kill(w, p, "Goblin")
	local f1 = #w.Fired
	kill(w, p, "Goblin")
	u = fired(w, "CodexUp", p, f1)[1]
	check(d.Codex.Goblin.Stage == 3 and d.Codex.Goblin.Kills == 1000 and u and u.Event == "Holo"
		and u.Gold == 1600 and u.XP == 2800 and u.Text == "Goblin card is now Gold Holo! +1,600 gold · +2,800 XP",
		"the 1000th: Gold Holo, 100 kills' worth", show(u))
	local f2 = #w.Fired
	kill(w, p, "Goblin")
	check(#fired(w, "CodexUp", p, f2) == 0 and d.Codex.Goblin.Stage == 3, "after Gold Holo: counting only", show(d.Codex.Goblin))
	-- a save behind its kills (a repaired record): the next kill pays every stage it skipped, in order
	local q, qd = hero(w, 3, { Codex = { Skeleton = { Kills = 999, Golden = 0, Stage = 0, First = 0 } } })
	check(qd.Codex.Skeleton.Stage == 2, "join: a stage below its kills is raised silently (no reward)", show(qd.Codex.Skeleton))
	local f3 = #w.Fired
	kill(w, q, "Skeleton")
	check(events(w, q, f3) == "Holo", "then the 1000th kill: Holo only", events(w, q, f3))
	-- a row behind its kills mid-session (never in a repaired save): every skipped stage, in order
	qd.Codex.SkeletonArcher = { Kills = 999, Golden = 0, Stage = 0, First = 0 }
	local f4 = #w.Fired
	kill(w, q, "SkeletonArcher")
	check(events(w, q, f4) == "Card,Silver,Holo", "all three stages, in order", events(w, q, f4))
	-- the ceiling
	qd.Codex.Skeleton.Kills = 1000000000
	kill(w, q, "Skeleton")
	check(qd.Codex.Skeleton.Kills == 1000000000, "a billion kills is the ceiling", show(qd.Codex.Skeleton))
end)

------------------------------------------------------------------ golden
runGroup("gold foil", function()
	local w = codexWorld()
	local p, d = hero(w, 4)
	local f0 = #w.Fired
	kill(w, p, "FlowerSlime", { Golden = true })
	local ups = fired(w, "CodexUp", p, f0)
	check(events(w, p, f0) == "Card,Golden", "a golden first kill: the card, then the Gold Foil card", events(w, p, f0))
	check(d.Codex.FlowerSlime.Golden == 1 and d.Codex.FlowerSlime.Kills == 1, "Golden 1, Kills 1", show(d.Codex.FlowerSlime))
	check(ups[2] and ups[2].Gold == 20 and ups[2].XP == 35 and ups[2].Text == "Gold Foil card: Flower Slime! +20 gold · +35 XP",
		"the foil pays 5 kills' worth (no golden x)", show(ups[2]))
	local f1 = #w.Fired
	kill(w, p, "FlowerSlime", { Golden = true })
	kill(w, p, "FlowerSlime")
	check(d.Codex.FlowerSlime.Golden == 2 and d.Codex.FlowerSlime.Kills == 3 and #fired(w, "CodexUp", p, f1) == 0,
		"a second golden only counts", show(d.Codex.FlowerSlime))
	local f2 = #w.Fired
	kill(w, p, "SlimeKing", { Golden = true })
	check(d.Codex.SlimeKing.Golden == 0 and events(w, p, f2) == "Card", "a boss is never a foil card (a bad golden flag)", show(d.Codex.SlimeKing))
	kill(w, p, "Slime", { Golden = 1 })
	check(d.Codex.Slime.Golden == 0, "only Golden == true counts", show(d.Codex.Slime))
end)

------------------------------------------------------------------ bosses
runGroup("boss cards", function()
	local w = codexWorld()
	local p, d = hero(w, 5, { Level = 30 })
	local f0 = #w.Fired
	kill(w, p, "CaptainClatter", { ZoneId = "SkeletonRuins" })
	local u = fired(w, "CodexUp", p, f0)[1]
	check(u and u.Event == "Card" and u.Gold == 3900 and u.XP == 3900, "Captain Clatter's card pays 1 kill's worth (BossStage)", show(u))
	d.Codex.CaptainClatter.Kills = 8
	kill(w, p, "CaptainClatter")
	check(d.Codex.CaptainClatter.Stage == 1, "9 kills: still stage 1", show(d.Codex.CaptainClatter))
	local f1 = #w.Fired
	kill(w, p, "CaptainClatter")
	u = fired(w, "CodexUp", p, f1)[1]
	check(u and u.Event == "Silver" and u.Gold == 11700 and u.XP == 11700, "a boss's Silver at 10: 3 kills' worth", show(u))
	d.Codex.CaptainClatter.Kills = 29
	local f2 = #w.Fired
	kill(w, p, "CaptainClatter")
	u = fired(w, "CodexUp", p, f2)[1]
	check(u and u.Event == "Holo" and u.Gold == 39000 and u.XP == 39000, "a boss's Gold Holo at 30: 10 kills' worth", show(u))
	-- 최종 검수 review ①: a free rider's minor share (info.Minor) counts, its stage reward is x MinorShare (15%)
	local q, qd = hero(w, 51, { Level = 30 })
	local f3 = #w.Fired
	kill(w, q, "CaptainClatter", { Minor = true })
	u = fired(w, "CodexUp", q, f3)[1]
	check(qd.Codex.CaptainClatter.Kills == 1 and u and u.Event == "Card" and u.Gold == 585 and u.XP == 585,
		"a minor share: counted, the card pays 15% (585)", show(u))
	qd.Codex.CaptainClatter.Kills = 9
	local f4 = #w.Fired
	kill(w, q, "CaptainClatter", { Minor = true })
	u = fired(w, "CodexUp", q, f4)[1]
	check(u and u.Event == "Silver" and u.Gold == 1755 and u.XP == 1755, "a minor share's Silver: 15% of 3 kills' worth (1,755)", show(u))
	local f5 = #w.Fired
	kill(w, q, "SlimeKing", { Minor = true })
	u = fired(w, "CodexUp", q, f5)[1]
	check(qd.Codex.SlimeKing.Kills == 1 and u and u.Event == "Card" and u.Gold == 0 and u.XP == 0 and u.Text == "New card: King Slime!",
		"a minor kill of a boss without a MinorShare: the card, no reward", show(u))
	-- 최종 검수 review ②: below the King Slime's XPCapBelowLevel (8) its card XP is at most one level (A23-27); gold is not capped
	local r = hero(w, 52, { Level = 1 })
	local f6 = #w.Fired
	kill(w, r, "SlimeKing")
	u = fired(w, "CodexUp", r, f6)[1]
	check(u and u.XP == w.Config.XPToNext(1) and u.XP < 120 and u.Gold == 60, "a Lv1 King Slime card: XP capped to one level, 60 gold", show(u))
	-- the cap level itself is free: a King worth more than a level shows it (a test-only XP of 1000)
	local w2 = codexWorld({ EditConfig = function(c) c.MonsterTypes.SlimeKing.XP = 1000 end })
	local s = hero(w2, 53, { Level = 8 })
	local t = hero(w2, 54, { Level = 7 })
	kill(w2, s, "SlimeKing")
	kill(w2, t, "SlimeKing")
	local us, ut = fired(w2, "CodexUp", s, 0)[1], fired(w2, "CodexUp", t, 0)[1]
	check(us and us.XP == 1000 and ut and ut.XP == w2.Config.XPToNext(7) and ut.XP < 1000,
		"Lv8 (the cap level): the full card XP; Lv7: one level", show({ us and us.XP, ut and ut.XP }))
end)

------------------------------------------------------------------ pages and titles
runGroup("page titles", function()
	local w = codexWorld()
	local p, d = hero(w, 6)
	for _, kind in { "Slime", "FlowerSlime", "BigSlime" } do kill(w, p, kind) end
	check(not (d.Titles and d.Titles.SlimeScholar), "3 of 4 meadow cards: no title yet", show(d.Titles))
	local f0, n0 = #w.Fired, #w.Notices
	kill(w, p, "SlimeKing")
	check(events(w, p, f0) == "Card,Page", "the 4th card finishes the page", events(w, p, f0))
	local u = fired(w, "CodexUp", p, f0)[2]
	check(u and u.Title == "SlimeScholar" and u.Page == "SlimeMeadow" and u.Text == "Squishy Meadow page done! New title: Slime Scholar"
		and u.Key == "Config.Codex.Text.Page" and (u.Gold or 0) == 0, "Page: the title, no gold", show(u))
	check(d.Titles.SlimeScholar ~= nil and string.find(p:GetAttribute("TitlesOwned") or "", "SlimeScholar", 1, true) ~= nil,
		"TitleService owns and publishes it", show(p:GetAttribute("TitlesOwned")))
	check(#w:NoticesFor(p, n0) == 2, "two toasts (the card, the page)", show(w:NoticesFor(p, n0)))
	local f1 = #w.Fired
	kill(w, p, "SlimeKing")
	kill(w, p, "Slime")
	check(#fired(w, "CodexUp", p, f1) == 0, "no second Page", events(w, p, f1))
	check(p:GetAttribute("CodexCards") == 4, "CodexCards 4", p:GetAttribute("CodexCards"))
	-- the woods page with a title the player already owns: no Page moment
	local q, qd = hero(w, 7, { Titles = { GoblinScholar = 5 } })
	kill(w, q, "Goblin")
	kill(w, q, "SlingshotGoblin")
	local f2 = #w.Fired
	kill(w, q, "GoblinBrute")
	check(events(w, q, f2) == "Card", "a page whose title is already owned: the card only", events(w, q, f2))
end)

------------------------------------------------------------------ the glow
runGroup("every card gold holo", function()
	local w = codexWorld()
	local cards = {}
	for _, kind in w.Config.Codex.Order do
		cards[kind] = { Kills = w.Config.MonsterTypes[kind].Boss and 29 or 999, Golden = 0, Stage = 2, First = 1 } -- one kill short of Holo
	end
	local p, d = hero(w, 8, { Codex = cards })
	check(p:GetAttribute("CodexGlow") == false and p:GetAttribute("CodexCards") == 11, "11 silver cards: no glow", "")
	local order = w.Config.Codex.Order
	for i = 1, #order - 1 do kill(w, p, order[i]) end
	check(p:GetAttribute("CodexGlow") == false, "10 of 11 Gold Holo: still no glow", "")
	local f0 = #w.Fired
	kill(w, p, order[#order])
	check(events(w, p, f0) == "Holo,Glow", "the 11th Gold Holo lights the glow", events(w, p, f0))
	check(p:GetAttribute("CodexGlow") == true, "CodexGlow = true", "")
	local u = fired(w, "CodexUp", p, f0)[2]
	check(u and u.Text == "Every card is Gold Holo! Your sparkle is on." and (u.Gold or 0) == 0, "the glow line, no reward", show(u))
	local f1 = #w.Fired
	kill(w, p, order[1])
	check(#fired(w, "CodexUp", p, f1) == 0, "once", "")
	local stats = { "Level", "WeaponTier", "HP", "MaxHP", "Damage" }
	local touched = false
	for _, entry in p.Log do
		if table.find(stats, entry.Key) then touched = true end
	end
	check(not touched, "no stat attribute changed (cosmetic only)", "")
end)

------------------------------------------------------------------ what does not count
runGroup("what does not count", function()
	local w = codexWorld()
	local p, d = hero(w, 9)
	local f0 = #w.Fired
	kill(w, p, "Slime", { Personal = true })
	kill(w, p, "PumpkinSlime") -- a Halloween kind: a later series
	kill(w, p, "NoSuchMonster")
	kill(w, p, nil)
	w.Reg.MonsterService.MonsterKilled:Fire(p, "oops")
	w.Reg.MonsterService.MonsterKilled:Fire(p, nil)
	w:RunSpawned()
	check(next(d.Codex) == nil and #fired(w, "CodexUp", p, f0) == 0 and #w.Gold == 0,
		"a personal monster, a Halloween kind, an unknown kind, no kind, a broken info: nothing", show(d.Codex))
	-- a free rider's minor share (info.Minor) still counts, like the kill record
	kill(w, p, "SlimeKing", { Minor = true })
	check(d.Codex.SlimeKing and d.Codex.SlimeKing.Kills == 1, "a minor share counts (the KillLog rule)", show(d.Codex))
	-- switched off: nothing counts
	local w2 = codexWorld({ EditConfig = function(c) c.Codex.Enabled = false end })
	local q, qd = hero(w2, 10)
	kill(w2, q, "Slime")
	check(next(qd.Codex) == nil and #fired(w2, "CodexUp", q, 0) == 0, "Config.Codex.Enabled = false: no counting", show(qd.Codex))
end)

------------------------------------------------------------------ the kill record and the codex agree
runGroup("same count as the kill record", function()
	local w = codexWorld()
	local p, d = hero(w, 11)
	local list = { "Slime", "Slime", "Goblin", "SkeletonKnight", "Slime", "FlowerSlime", "PumpkinSlime", "CaptainClatter" }
	for _, kind in list do kill(w, p, kind) end
	kill(w, p, "Slime", { Personal = true })
	kill(w, p, "Slime", { Golden = true })
	local same = true
	for _, kind in w.Config.Codex.Order do
		local a = d.Codex[kind] and d.Codex[kind].Kills or 0
		local b = d.KillLog.ByKind[kind] or 0
		if a ~= b then same = false end
	end
	check(same, "Codex[kind].Kills == KillLog.ByKind[kind] for every codex kind", show({ d.Codex, d.KillLog.ByKind }))
end)

------------------------------------------------------------------ passes and the toast switch
runGroup("2x passes and the toast switch", function()
	local w = codexWorld({ GoldMult = 2, XPMult = 2 })
	local p = hero(w, 12)
	local f0 = #w.Fired
	kill(w, p, "Slime")
	local u = fired(w, "CodexUp", p, f0)[1]
	check(u and u.Gold == 18 and u.XP == 30 and u.Text == "New card: Slime! +18 gold · +30 XP", "the line says what was added (2x)", show(u))
	local w2 = codexWorld({ EditConfig = function(c) c.Codex.ServerToast = false end })
	local q = hero(w2, 13)
	local n0 = #w2.Notices
	kill(w2, q, "Slime")
	check(#fired(w2, "CodexUp", q, 0) == 1 and #w2:NoticesFor(q, n0) == 0, "ServerToast off: CodexUp only, no toast", "")
	-- the top level: no XP added -> the gold-only reward line
	local w3 = codexWorld({ XPMult = 0 })
	local r = hero(w3, 14)
	kill(w3, r, "Slime")
	u = fired(w3, "CodexUp", r, 0)[1]
	check(u and u.XP == 0 and u.Text == "New card: Slime! +9 gold", "no XP added: '+9 gold' only", show(u))
end)

------------------------------------------------------------------ join and the snapshot
runGroup("join and the snapshot", function()
	local w = codexWorld()
	local p, d = hero(w, 15, { Codex = { Slime = { Kills = 150, Golden = 2, Stage = 2, First = 7 }, Goblin = { Kills = 0, Stage = 1 },
		Ghost = { Kills = 5 }, BigSlime = "oops", SlimeKing = { Kills = 3.7, Golden = 4, Stage = 9, First = NAN } } })
	local snap = fired(w, "Codex", p, 0)
	check(#snap == 1 and snap[1].V == 1 and snap[1].Glow == false, "one snapshot at join (V 1)", show(snap))
	local cards = snap[1] and snap[1].Cards or {}
	check(sameTable(cards.Slime, { Kills = 150, Golden = 2, Stage = 2, First = 7 }), "a sane card as saved", show(cards.Slime))
	check(cards.Goblin == nil and cards.Ghost == nil and cards.BigSlime == nil, "no kills / unknown kind / broken row: dropped", show(cards))
	check(sameTable(cards.SlimeKing, { Kills = 3, Golden = 0, Stage = 3, First = 0 }),
		"a broken boss row: whole kills, no foil, stage capped at 3 (never taken back), First 0", show(cards.SlimeKing))
	check(p:GetAttribute("CodexCards") == 2, "CodexCards counts the cards", p:GetAttribute("CodexCards"))
	-- a full page at join: the title, silently
	local q, qd = hero(w, 16, { Codex = { Goblin = { Kills = 1, Stage = 1 }, SlingshotGoblin = { Kills = 2, Stage = 1 },
		GoblinBrute = { Kills = 3, Stage = 1 } } })
	check(qd.Titles.GoblinScholar ~= nil and #fired(w, "CodexUp", q, 0) == 0 and #w:NoticesFor(q, 0) == 0,
		"a page full at join (the v5 step): its title, no moment, no toast", show(qd.Titles))
	-- CodexOpen: the answer is the snapshot
	local f0 = #w.Fired
	w:Remote("CodexOpen", p)
	check(#fired(w, "Codex", p, f0) == 1, "CodexOpen -> one snapshot", "")
	w.Gap = 0.2
	local f1 = #w.Fired
	w:Remote("CodexOpen", p)
	check(#fired(w, "Codex", p, f1) == 0, "again within 1 s: nothing (rate limit)", "")
	w.Gap = 1.1
	w:Remote("CodexOpen", p, "junk", 5)
	check(#fired(w, "Codex", p, f1) == 1, "extra arguments are ignored", "")
	w.Ready[p] = nil
	local f2 = #w.Fired
	w:Remote("CodexOpen", p)
	check(#fired(w, "Codex", p, f2) == 0, "not ready: nothing", "")
	check(fired(w, "Codex", q, 0)[1] and fired(w, "Codex", p, 0)[1] ~= fired(w, "Codex", q, 0)[1], "each player gets their own", "")
end)

------------------------------------------------------------------ the Studio test aid
runGroup("debug", function()
	local w = codexWorld()
	local p, d = hero(w, 17)
	local CS = w.Reg.CodexService
	check(CS.Debug(p, "Slime:99") == "ok" and d.Codex.Slime.Kills == 99 and d.Codex.Slime.Stage == 1 and #w.Gold == 0,
		"'Slime:99' sets the kills, no reward", show(d.Codex.Slime))
	local f0 = #w.Fired
	kill(w, p, "Slime")
	check(events(w, p, f0) == "Silver", "then one kill evolves it", events(w, p, f0))
	local before = deepCopy(d.Codex)
	local f1 = #w.Fired
	check(CS.Debug(p, "show:Slime:Holo") == "ok", "'show:Slime:Holo' answers ok", "")
	local u = fired(w, "CodexUp", p, f1)[1]
	check(u and u.Event == "Holo" and u.Debug == true and u.Gold == 0 and u.XP == 0 and sameTable(d.Codex, before),
		"the moment again, no reward, no change", show(u))
	check(CS.Debug(p, "show:Slime:Nope") ~= "ok" and CS.Debug(p, "Ghost:5") ~= "ok", "an unknown event / kind is refused", "")
	check(CS.Debug(p, "Slime:0") == "ok" and d.Codex.Slime == nil, "'Slime:0' removes the card", show(d.Codex))
	CS.Debug(p, "Goblin:5")
	check(CS.Debug(p, "reset") == "ok" and next(d.Codex) == nil and p:GetAttribute("CodexCards") == 0, "'reset' clears", show(d.Codex))
end)

------------------------------------------------------------------ the card models (최종 검수 10/13)
runGroup("card models", function()
	local goblin = importedModel("Goblin")
	local knight = importedModel("SkeletonKnight")
	local prince = fake("MeshPart", "BigSlime", { Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true },
		{ fake("Script", "Wobble") })
	local custom = { goblin, knight, prince, fake("Folder", "Skeleton"), importedModel("PumpkinSlime"), importedModel("Slime", { CloneFails = true }) }
	local w = codexWorld({ Custom = custom, AllowWarn = { "model Slime: ", "model FlowerSlime: " } })
	local C = w.Config
	local folder = w.Services.ReplicatedStorage:FindFirstChild("CodexModels")
	check(folder ~= nil and folder.ClassName == "Folder", "ReplicatedStorage.CodexModels exists", "")
	local names = {}
	for _, c in folder:GetChildren() do table.insert(names, c.Name) end
	table.sort(names)
	check(table.concat(names, ",") == "BigSlime,CaptainClatter,Goblin,SkeletonKnight,SlimeKing,SlingshotGoblin",
		"own models + ModelFrom borrowers; no model (GoblinBrute, the Skeleton folder, its archer) or a broken one (Slime and FlowerSlime that borrows it) skipped",
		table.concat(names, ","))
	check(folder:FindFirstChild("PumpkinSlime") == nil, "only the codex kinds", "")
	local g = folder:FindFirstChild("Goblin")
	local kinds = {}
	for _, d in g:GetDescendants() do kinds[d.ClassName] = true end
	check(not (kinds.Script or kinds.LocalScript or kinds.ModuleScript or kinds.Sound or kinds.ParticleEmitter or kinds.PointLight
		or kinds.BillboardGui), "no script, sound, effect, light or GUI left (deep ones too)", show(kinds))
	check(kinds.MeshPart and kinds.Part and kinds.Attachment and kinds.Folder, "the shape stays (parts, attachments, folders)", show(kinds))
	local stillOk = true
	for _, d in g:GetDescendants() do
		if d:IsA("BasePart") and not (d.Anchored == true and d.CanCollide == false and d.CanQuery == false and d.CanTouch == false) then
			stillOk = false
		end
	end
	check(stillOk, "every part Anchored, CanCollide / CanQuery / CanTouch off", "")
	check(g:GetAttribute("CodexScale") == C.MonsterTypes.Goblin.Scale and g:GetAttribute("CodexFrom") == nil, "own model: its scale, no From", "")
	local sling = folder:FindFirstChild("SlingshotGoblin")
	check(sling and sling:GetAttribute("CodexFrom") == "Goblin" and sling:GetAttribute("CodexScale") == C.MonsterTypes.SlingshotGoblin.Scale
		and sling:GetAttribute("CodexColor") == C.MonsterTypes.SlingshotGoblin.Color and sling ~= g,
		"a borrowed model (ModelFrom Goblin): its own copy, From, scale, tint", "")
	local clatter = folder:FindFirstChild("CaptainClatter")
	check(clatter and clatter:GetAttribute("CodexFrom") == "SkeletonKnight" and clatter:GetAttribute("CodexScale") == 2.2, "Captain Clatter borrows the knight", "")
	local king = folder:FindFirstChild("SlimeKing")
	check(king and king.ClassName == "MeshPart" and king.Anchored == true and king.CanQuery == false and #king:GetChildren() == 0
		and king:GetAttribute("CodexFrom") == "BigSlime", "a BasePart model (the King borrows the Prince's): still, its script gone", "")
	-- the originals are untouched
	local orig = {}
	for _, d in goblin:GetDescendants() do orig[d.ClassName] = true end
	check(orig.Script and orig.Sound and goblin.Name == "Goblin" and goblin:FindFirstChild("HumanoidRootPart").Anchored == false
		and prince:FindFirstChild("Wobble") ~= nil, "ServerStorage's models are not changed", "")
	-- again: nothing doubled
	local again = w.Reg.CodexService.PublishModels()
	check(again == 0 and #folder:GetChildren() == 6, "publishing again adds nothing", again)
	-- no CustomModels folder: an empty CodexModels, no warning
	local w2 = codexWorld()
	local f2 = w2.Services.ReplicatedStorage:FindFirstChild("CodexModels")
	check(f2 ~= nil and #f2:GetChildren() == 0, "no CustomModels: an empty folder", "")
end)

------------------------------------------------------------------ the repair
runGroup("repair", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	check(sameTable(C.SanitizeCodex(nil), {}) and sameTable(C.SanitizeCodex("x"), {}) and sameTable(C.SanitizeCodex({}), {}),
		"nil / text / empty -> {}", "")
	local r = C.SanitizeCodex({ Slime = { Kills = 1e12, Golden = 2e12, Stage = 1, First = -4 }, Goblin = { Kills = 50.9, Golden = -1,
		Stage = "2", First = 99.5 }, Skeleton = { Kills = NAN }, SkeletonKnight = { Kills = INF }, BigSlime = { Kills = 120, Stage = 1 },
		FlowerSlime = { Kills = 5, Golden = 9, Stage = 3, First = 1 }, PumpkinSlime = { Kills = 9 }, [1] = { Kills = 1 } })
	check(sameTable(r.Slime, { Kills = 1000000000, Golden = 1000000000, Stage = 3, First = 0 }), "a billion is the ceiling; Golden <= Kills", show(r.Slime))
	check(sameTable(r.Goblin, { Kills = 50, Golden = 0, Stage = 1, First = 99 }), "fractions floored, text / negative -> 0", show(r.Goblin))
	check(r.Skeleton == nil and r.SkeletonKnight == nil, "NaN / inf kills: no card", show(r))
	check(r.BigSlime.Stage == 2, "a stage below its kills is raised", show(r.BigSlime))
	check(r.FlowerSlime.Stage == 3 and r.FlowerSlime.Golden == 5, "a stage above its kills is kept (never taken back); Golden cut to Kills",
		show(r.FlowerSlime))
	check(r.PumpkinSlime == nil and r[1] == nil and count(r) == 4, "only series-1 kinds", show(r))
	check(sameTable(C.SanitizeCodex(r), r), "repairing twice = once", "")
	local filled = C.CodexFromKillLog({ ByKind = { PumpkinSlime = 9, Slime = 2, Ghost = 4 } }, nil)
	check(filled.PumpkinSlime == nil and filled.Ghost == nil and filled.Slime.Kills == 2 and count(filled) == 1,
		"the fill reads series-1 kinds only", show(filled))
end)

------------------------------------------------------------------ the v5 step (DataService migrate + fillDefaults)
runGroup("save v5 step", function()
	local w = newWorld({})
	w.AllowWarn = { "field KillLog had type string, reset to default", "field Codex had type string, reset to default" }
	local C = w.Config
	local DS = execute("DataService.extract", DATA_EXTRACT, w:Env(), C, w.Util, "DataService", 99)
	local function load(rec)
		local d = deepCopy(rec)
		DS.Migrate(d, { Name = "P1" })
		DS.Fill(d, "P1")
		return d
	end
	local v4 = { Version = 4, Level = 20, Faction = "Horns", Class = "Mage", ClassChosen = true, TutorialStep = 99, WeaponTier = 3,
		WeaponOwnedMask = 7, BankGold = 500, KillLog = { Total = 1300, M = 1300, A = 0, Golden = 7,
			ByKind = { Slime = 150, Goblin = 3, SlimeKing = 1000, PumpkinSlime = 9, FlowerSlime = 0 }, ByTier = {} } }
	local d = load(v4)
	check(d.Version == 5, "a v4 record runs the v5 step", d.Version)
	check(sameTable(d.Codex.Slime, { Kills = 150, Golden = 0, Stage = 2, First = 0 })
		and sameTable(d.Codex.Goblin, { Kills = 3, Golden = 0, Stage = 1, First = 0 })
		and sameTable(d.Codex.SlimeKing, { Kills = 1000, Golden = 0, Stage = 3, First = 0 }),
		"its cards come from KillLog.ByKind (Golden 0, First 0 = before the codex)", show(d.Codex))
	check(d.Codex.PumpkinSlime == nil and d.Codex.FlowerSlime == nil and count(d.Codex) == 3, "no Halloween kind, no 0-kill card", show(d.Codex))
	check(d.BankGold == 500 and d.Level == 20 and d.KillLog.ByKind.Slime == 150, "nothing else moves (no reward)", show({ d.BankGold, d.Level }))
	local again = load(d)
	check(sameTable(again.Codex, d.Codex) and again.Version == 5, "loading the v5 record again changes nothing", show(again.Codex))
	-- a v5 record never runs the step again (its codex is its own; the kill record is not read)
	local v5 = deepCopy(d)
	v5.KillLog.ByKind.Goblin = 500
	check(load(v5).Codex.Goblin.Kills == 3, "a v5 record is not filled again from its kill record", "")
	-- older records: every step, no kill record -> no cards
	local v1 = { Version = 1, Level = 6, SwordTier = 3, Faction = "Halo", TutorialStep = 99 }
	local d1 = load(v1)
	check(d1.Version == 5 and next(d1.Codex) == nil and d1.WeaponTier == 3, "a v1 record runs every step up to 5 (no cards)", show(d1.Codex))
	local v3 = { Version = 3, Level = 12, TutorialStep = 99, WeaponTier = 2, WeaponOwnedMask = 3, KillLog = { ByKind = { Skeleton = 2 } } }
	check(load(v3).Codex.Skeleton.Kills == 2, "a v3 record with a kill record gets its cards too", "")
	-- broken kill records
	for _, bad in { "oops", { ByKind = "x" }, { ByKind = { Slime = NAN, Goblin = -5, Skeleton = INF, BigSlime = "9", SkeletonKnight = 2.9 } } } do
		local r = load({ Version = 4, TutorialStep = 99, KillLog = bad })
		local ok = r.Version == 5 and r.Codex.Slime == nil and r.Codex.Goblin == nil and r.Codex.Skeleton == nil and r.Codex.BigSlime == nil
		if type(bad) == "table" and type(bad.ByKind) == "table" then ok = ok and r.Codex.SkeletonKnight.Kills == 2 end
		check(ok, "a broken kill record makes no card from bad numbers", show(r.Codex))
	end
	-- a v4 record that somehow has a codex already: the larger numbers win, its own fields stay
	local odd = { Version = 4, TutorialStep = 99, Codex = { Slime = { Kills = 200, Golden = 3, Stage = 2, First = 11 },
		Goblin = { Kills = 1, Golden = 0, Stage = 1, First = 12 } }, KillLog = { ByKind = { Slime = 150, Goblin = 120 } } }
	local o = load(odd)
	check(sameTable(o.Codex.Slime, { Kills = 200, Golden = 3, Stage = 2, First = 11 })
		and sameTable(o.Codex.Goblin, { Kills = 120, Golden = 0, Stage = 2, First = 12 }), "an existing row keeps its larger numbers", show(o.Codex))
	-- a fresh default record
	local fresh = deepCopy(C.Data.Defaults)
	DS.Fill(fresh, "P2")
	check(fresh.Version == 5 and type(fresh.Codex) == "table" and next(fresh.Codex) == nil, "a brand-new record: Version 5, Codex {}", show(fresh.Codex))
	-- a Codex of the wrong type is reset by the default fill
	local s = load({ Version = 5, TutorialStep = 99, Codex = "oops" })
	check(type(s.Codex) == "table" and next(s.Codex) == nil, "Codex of the wrong type -> {}", show(s.Codex))
	local b = load({ Version = 5, TutorialStep = 99, Codex = { Slime = { Kills = 2.5 }, Ghost = { Kills = 3 } } })
	check(sameTable(b.Codex, { Slime = { Kills = 2, Golden = 0, Stage = 1, First = 0 } }), "a v5 record's codex is repaired at load",
		show(b.Codex))
end)

finish()
