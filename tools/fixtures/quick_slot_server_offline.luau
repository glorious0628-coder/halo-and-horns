-- quick_slot_server_offline.luau : A23-109 quick slots 1·2·3 (server: QuickSlotService), offline.
-- tools/test_quick_slot_server.py injects (before tools/fixtures/dev2_kit.luau): CONFIG_SOURCE, UTIL_SOURCE, QUICK_SOURCE,
-- DATA_SOURCE, NET_SOURCE, MAIN_SOURCE (the CURRENT src) and CLIENT_PARSE (QuickSlots.Parse cut from the client's
-- QuickSlots.luau). QuickSlotService runs for real on a PlayerService double (data rows, IsReady, PlayerReady) and a
-- StoryQuestService double (Event); DataService.Load / Release run for real on the kit's DataStore double. The client
-- side has its own suite (tools/test_quick_slots.py, 게임성 개발 1).

------------------------------------------------------------------ a server with the real QuickSlotService
local MISSING = {} -- Join(id, MISSING): the save has no QuickSlots field (a save from before the quick slots)

local function qsWorld(opts)
	opts = opts or {}
	local w = newWorld({ EditConfig = opts.EditConfig })
	w.AllowWarn = opts.AllowWarn
	local Signal = w.Util.Signal
	local data = {}
	local ps = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new() }
	function ps.GetData(p) return data[p] end
	function ps.IsReady(p) return w.Ready[p] == true end
	-- the KO1 quest's entry (게임성 개발 3): every call is logged; opts.NoQuest = no Event, opts.QuestThrows = it errors
	w.QuestLog = {}
	local sq = {}
	if not opts.NoQuest then
		function sq.Event(p, name, info)
			table.insert(w.QuestLog, { P = p.UserId, Name = name, Info = info })
			if opts.QuestThrows then error("quest broke") end
		end
	end
	local reg = { PlayerService = ps, StoryQuestService = sq }
	local quick = w:Load("QuickSlotService", QUICK_SOURCE)
	reg.QuickSlotService = quick
	quick.Init(reg)
	quick.Start()
	w.Data, w.PS, w.Quick = data, ps, quick
	w.ChangedLog = {}
	quick.Changed:Connect(function(p, slots) table.insert(w.ChangedLog, { P = p.UserId, Slots = slots }) end)
	-- a ready player; stored = the save's QuickSlots value (MISSING = no field)
	function w:Join(userId, stored)
		local p = self:NewPlayer(userId, {})
		local d = { HPPotionCount = 0, MPPotionCount = 0 }
		if stored ~= MISSING then d.QuickSlots = stored end
		data[p] = d
		self.Ready[p] = true
		ps.PlayerReady:Fire(p, d)
		return p, d
	end
	-- one SetQuickSlot call 1 s after the last (past the rate limit); SetNow = no wait
	function w:Set(p, ...)
		self:Advance(1)
		self.Remotes.SetQuickSlot.OnServerEvent:Fire(p, ...)
	end
	function w:SetNow(p, ...) self.Remotes.SetQuickSlot.OnServerEvent:Fire(p, ...) end
	-- every attribute write of QuickSlots so far (p.Log keeps every SetAttribute)
	function w:AttrWrites(p)
		local out = {}
		for _, e in p.Log do
			if type(e) == "table" and e.Key == "QuickSlots" then table.insert(out, e.Value) end
		end
		return out
	end
	function w:Snap(p)
		local d = data[p]
		return { tostring(d and d.QuickSlots), tostring(p:GetAttribute("QuickSlots")), #self.ChangedLog, #self:AttrWrites(p) }
	end
	return w
end

local function same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end

-- the client's own reading of the attribute (QuickSlots.Parse from QuickSlots.luau, its T built from Config like there)
local function clientParser(cfg)
	local q = cfg.QuickSlots
	local env = { T = { Count = q.Count, Default = q.Default, Items = q.Items }, QuickSlots = {} }
	local fn, err = loadstring("local T, QuickSlots = T, QuickSlots\n" .. CLIENT_PARSE .. "\nreturn QuickSlots.Parse", "=ClientParse")
	assert(fn, err)
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end

------------------------------------------------------------------ config + wiring
runGroup("config + wiring", function()
	local w = qsWorld()
	local q = w.Config.QuickSlots
	check(type(q) == "table" and q.Count == 3 and #q.Default == 3, "three quick slots, three defaults", show(q and q.Count))
	check(q.Attr == "QuickSlots" and q.Remote == "SetQuickSlot", "the attribute / remote names of the contract", show({ q.Attr, q.Remote }))
	for i, item in q.Default do
		check(item == "" or q.Items[item] ~= nil, "every default is empty or a known item", tostring(i))
	end
	check(type(w.Config.RateLimits.SetQuickSlot) == "number" and w.Config.RateLimits.SetQuickSlot > 0
		and w.Config.RateLimits.SetQuickSlot <= 0.5, "SetQuickSlot has a short rate limit", show(w.Config.RateLimits.SetQuickSlot))
	local init = string.match(MAIN_SOURCE, "local INIT_ORDER = (%b{})") or ""
	local start = string.match(MAIN_SOURCE, "local START_ORDER = (%b{})") or ""
	local function count(list, name)
		local _, c = string.gsub(list, '"' .. name .. '"', "")
		return c
	end
	local function pos(list, name) return string.find(list, '"' .. name .. '"', 1, true) end
	check(count(init, "QuickSlotService") == 1, "Main INIT_ORDER has QuickSlotService once")
	check(count(start, "QuickSlotService") == 1 and pos(start, "PlayerService") ~= nil
		and pos(start, "QuickSlotService") < pos(start, "PlayerService"), "Main START_ORDER has it once, before PlayerService")
	local names = string.match(NET_SOURCE, "Net%.Names = (%b{})") or ""
	check(count(names, q.Remote) == 1, "Net.Names has the remote once")
	check(pos(names, "Commission") ~= nil and pos(names, q.Remote) ~= nil and pos(names, "Commission") < pos(names, q.Remote),
		"the remote is appended after the older names")
	check(count(names, "UsePotion") == 1, "the UsePotion remote stays (a slot press uses it)")
end)

------------------------------------------------------------------ load: the attribute and the save repair
runGroup("ready: missing / stored / broken saves", function()
	local w = qsWorld()
	local parseClient = clientParser(w.Config)
	local DEF = table.concat(w.Quick.Parse(5), ",") -- the Default, cleaned (main 10/10: all empty)
	check(DEF == ",,", "the Default is three empty slots (검수 10/10: a new player fills one in the KO1 quest)", DEF)
	local p0, d0 = w:Join(1, MISSING)
	check(p0:GetAttribute("QuickSlots") == "HP,MP," and d0.QuickSlots == "HP,MP,",
		"a save from before the quick slots (no field) gets HP, MP, empty - shown and saved",
		show({ p0:GetAttribute("QuickSlots"), d0.QuickSlots }))
	check(same(w.Quick.Get(p0), { "HP", "MP", "" }), "Get = HP, MP, empty", show(w.Quick.Get(p0)))
	local pn, dn = w:Join(2, table.concat(w.Config.QuickSlots.Default, ",")) -- what DataService gives a brand-new save
	check(pn:GetAttribute("QuickSlots") == DEF and dn.QuickSlots == DEF, "a brand-new save shows and keeps the Default",
		show({ pn:GetAttribute("QuickSlots"), dn.QuickSlots }))
	local cases = {
		{ "MP,,HP", "MP,,HP" },
		{ ",,", ",," },
		{ "", ",," },
		{ "HP,HP,MP", "HP,,MP" }, -- a repeat is emptied
		{ "Jelly,MP,Enh70", ",MP," }, -- not a quick item
		{ "hp, MP,", ",," }, -- exact keys only
		{ "HP", "HP,," }, -- short: the rest empty
		{ "MP,HP,,HP,x", "MP,HP," }, -- extra parts ignored
		{ "MP,HP," .. string.rep("x", 200), DEF }, -- over the length cap: broken = Default
		{ 5, DEF },
		{ true, DEF },
		{ { "MP" }, DEF },
	}
	for i, c in cases do
		local p, d = w:Join(10 + i, c[1])
		local attr = p:GetAttribute("QuickSlots")
		check(attr == c[2], "stored case " .. i .. " shows the clean slots", show({ In = c[1], Attr = attr }))
		check(d.QuickSlots == c[2], "stored case " .. i .. " is saved clean", show({ In = c[1], Saved = d.QuickSlots }))
		check(same(parseClient(attr), w.Quick.Get(p)), "stored case " .. i .. ": the client reads what the server holds",
			show({ Client = parseClient(attr), Server = w.Quick.Get(p) }))
	end
	check(#w.ChangedLog == 0, "loading fires no Changed", show(w.ChangedLog))
	check(#w.Notices == 0, "loading shows no notice", show(w.Notices))
end)

------------------------------------------------------------------ SetQuickSlot
runGroup("set: fill, move, swap, empty", function()
	local w = qsWorld()
	local p, d = w:Join(1, MISSING) -- HP, MP, empty
	w:Set(p, 3, "HP") -- moves: slot 3 gets HP, slot 1 gets slot 3's empty
	check(d.QuickSlots == ",MP,HP" and p:GetAttribute("QuickSlots") == ",MP,HP", "an item put on another slot moves there",
		show({ d.QuickSlots, p:GetAttribute("QuickSlots") }))
	check(#w.ChangedLog == 1 and w.ChangedLog[1].P == 1 and same(w.ChangedLog[1].Slots, { "", "MP", "HP" }),
		"Changed fires once with the new slots", show(w.ChangedLog))
	w:Set(p, 1, "MP")
	check(d.QuickSlots == "MP,,HP", "moved again (slot 2 gets slot 1's empty)", tostring(d.QuickSlots))
	w:Set(p, 1, "HP") -- two full slots swap
	check(d.QuickSlots == "HP,,MP" and p:GetAttribute("QuickSlots") == "HP,,MP", "two full slots swap", tostring(d.QuickSlots))
	local changed, writes = #w.ChangedLog, #w:AttrWrites(p)
	w:Set(p, 1, "HP") -- already there
	check(#w.ChangedLog == changed and #w:AttrWrites(p) == writes and d.QuickSlots == "HP,,MP",
		"the same item on its own slot changes nothing")
	w:Set(p, 3, "")
	check(d.QuickSlots == "HP,," and p:GetAttribute("QuickSlots") == "HP,,", "\"\" empties a slot", tostring(d.QuickSlots))
	changed = #w.ChangedLog
	w:Set(p, 2, "")
	check(#w.ChangedLog == changed and d.QuickSlots == "HP,,", "emptying an empty slot changes nothing")
	w:Set(p, 2, "MP") -- the player has 0 MP potions: a slot may still hold it
	check(d.MPPotionCount == 0 and d.QuickSlots == "HP,MP,", "an item owned 0 times may sit in a slot", tostring(d.QuickSlots))
	check(same(w.Quick.Get(p), { "HP", "MP", "" }), "Get = the saved slots", show(w.Quick.Get(p)))
	w:Set(p, 1, "")
	w:Set(p, 2, "")
	check(d.QuickSlots == ",," and p:GetAttribute("QuickSlots") == ",,", "all three empty stays saved as empty (not the Default)",
		tostring(d.QuickSlots))
	check(#w.Notices == 0, "setting shows no notice (A23-99)", show(w.Notices))
	-- every attribute the server wrote: three entries, known items, no repeats, read the same by the client
	local parseClient = clientParser(w.Config)
	for i, attr in w:AttrWrites(p) do
		local parts = string.split(attr, ",")
		local seen, okItems = {}, #parts == 3
		for _, item in parts do
			if item ~= "" then
				if seen[item] or w.Config.QuickSlots.Items[item] == nil then okItems = false end
				seen[item] = true
			end
		end
		check(okItems, "attribute write " .. i .. " is three entries, known items, no repeats", attr)
		check(table.concat(parseClient(attr), ",") == attr, "attribute write " .. i .. " reads back the same on the client", attr)
	end
end)

runGroup("set: bad arguments change nothing", function()
	local w = qsWorld()
	local p, d = w:Join(1, "HP,,")
	local bad = {
		{ 0, "MP" }, { 4, "MP" }, { -1, "MP" }, { 1.5, "MP" }, { 0 / 0, "MP" }, { math.huge, "MP" }, { -math.huge, "MP" },
		{ "2", "MP" }, { nil, "MP" }, { true, "MP" }, { { 2 }, "MP" },
		{ 2, "Jelly" }, { 2, "Enh70" }, { 2, "MP " }, { 2, "mp" }, { 2, "PotionMP" }, { 2, "Order" }, { 2, "Items" },
		{ 2, 5 }, { 2, nil }, { 2, true }, { 2, { "MP" } }, { 2, string.rep("M", 5000) },
	}
	for i, args in bad do
		local before = w:Snap(p)
		w:Set(p, args[1], args[2])
		check(same(w:Snap(p), before), "bad SetQuickSlot args " .. i, show(args))
	end
	local before = w:Snap(p)
	w:Set(p, 2, "MP", "extra")
	check(same(w:Snap(p), before), "an extra argument is refused")
	w:Set(p, 2, "MP", nil)
	check(same(w:Snap(p), before), "a trailing nil argument is refused too")
	w:Set(p)
	check(same(w:Snap(p), before), "no arguments: nothing")
	w:Set(p, 2, "MP")
	check(d.QuickSlots == "HP,MP," and p:GetAttribute("QuickSlots") == "HP,MP,", "a good call after the bad ones works",
		tostring(d.QuickSlots))
	check(#w.Notices == 0, "bad calls show no notice", show(w.Notices))
end)

runGroup("set: not ready / left / no data / rate limit", function()
	local w = qsWorld()
	local p, d = w:Join(1, MISSING)
	w.Ready[p] = false
	local before = w:Snap(p)
	w:Set(p, 3, "HP")
	check(same(w:Snap(p), before), "a player who is not ready cannot set")
	w.Ready[p] = true
	w:Remove(p)
	w:Set(p, 3, "HP")
	check(same(w:Snap(p), before), "a player who left cannot set")
	local p2 = w:Join(2, MISSING)
	w.Data[p2] = nil
	w:Set(p2, 3, "HP")
	check(p2:GetAttribute("QuickSlots") == "HP,MP," and #w.ChangedLog == 0, "a ready player without data changes nothing")

	local p3, d3 = w:Join(3, MISSING)
	w:Set(p3, 3, "HP") -- accepted
	check(d3.QuickSlots == ",MP,HP", "the first call is accepted", tostring(d3.QuickSlots))
	w:Advance(0.1)
	w:SetNow(p3, 1, "MP") -- 0.1 s later: dropped
	check(d3.QuickSlots == ",MP,HP", "a second call within the rate limit is dropped", tostring(d3.QuickSlots))
	local p4, d4 = w:Join(4, MISSING)
	w:SetNow(p4, 3, "MP") -- another player at the same moment: their own limit
	check(d4.QuickSlots == "HP,,MP", "another player's call is not held by the first one's limit", tostring(d4.QuickSlots))
	w:Advance(w.Config.RateLimits.SetQuickSlot + 0.01)
	w:SetNow(p3, 1, "MP")
	check(d3.QuickSlots == "MP,,HP", "after the rate limit the next call works", tostring(d3.QuickSlots))
	check(d.QuickSlots == "HP,MP,", "the refused player's save keeps what the load gave it", tostring(d.QuickSlots))
end)

runGroup("a broken Default is reported and read as empty", function()
	local w = qsWorld({
		EditConfig = function(cfg) cfg.QuickSlots.Default = { "Jelly", "MP", "MP" } end,
		AllowWarn = "Default has an unknown item",
	})
	local n = 0
	for _, text in w.Warnings do
		if string.find(text, "Default has an unknown item", 1, true) then n += 1 end
	end
	check(n == 1, "Init warns once about the unknown default", show(w.Warnings))
	local p = w:Join(1, 5) -- a broken stored value reads the Default
	check(p:GetAttribute("QuickSlots") == ",MP,", "unknown and repeated defaults become empty", tostring(p:GetAttribute("QuickSlots")))
end)

------------------------------------------------------------------ the KO1 quest entry
runGroup("quest: QuickSlotSet when an item goes into a slot", function()
	local w = qsWorld()
	local p = w:Join(1, ",,")
	w:Set(p, 2, "HP")
	check(#w.QuestLog == 1 and w.QuestLog[1].P == 1 and w.QuestLog[1].Name == "QuickSlotSet"
		and type(w.QuestLog[1].Info) == "table" and w.QuestLog[1].Info.Slot == 2 and w.QuestLog[1].Info.Kind == "HP",
		"putting HP in slot 2 tells the quest { Slot = 2, Kind = HP }", show(w.QuestLog))
	w:Set(p, 3, "HP") -- moved: slot 3 now holds it
	check(#w.QuestLog == 2 and w.QuestLog[2].Info.Slot == 3 and w.QuestLog[2].Info.Kind == "HP",
		"a move tells the quest the new slot", show(w.QuestLog[2]))
	w:Set(p, 1, "MP")
	w:Set(p, 1, "HP") -- a swap: HP goes to 1, MP to 3 -> one event for the item put in
	check(#w.QuestLog == 4 and w.QuestLog[4].Info.Slot == 1 and w.QuestLog[4].Info.Kind == "HP",
		"a swap tells the quest once, for the item put in", show(w.QuestLog))
	w:Set(p, 1, "HP") -- no change
	w:Set(p, 2, "") -- empty an empty slot
	w:Set(p, 1, "") -- empty a full slot
	check(#w.QuestLog == 4 and w:Snap(p)[1] == ",,MP", "no change and emptying tell the quest nothing", show(w.QuestLog))
	w:Set(p, 9, "HP")
	w:Set(p, 1, "Jelly")
	w.Ready[p] = false
	w:Set(p, 1, "HP")
	check(#w.QuestLog == 4, "refused calls tell the quest nothing", show(w.QuestLog))

	local w2 = qsWorld({ NoQuest = true })
	local p2, d2 = w2:Join(2, ",,")
	w2:Set(p2, 1, "MP")
	check(d2.QuickSlots == "MP,," and #w2.Warnings == 0, "no quest entry yet: the slot still changes, no warning",
		show({ d2.QuickSlots, w2.Warnings }))

	local w3 = qsWorld({ QuestThrows = true, AllowWarn = "quest event: " })
	local p3, d3 = w3:Join(3, ",,")
	w3:Set(p3, 1, "MP")
	local n = 0
	for _, text in w3.Warnings do
		if string.find(text, "quest event: ", 1, true) then n += 1 end
	end
	check(d3.QuickSlots == "MP,," and p3:GetAttribute("QuickSlots") == "MP,," and #w3.ChangedLog == 1 and n == 1,
		"a quest error is caught and warned once; the slot is saved and shown anyway", show({ d3.QuickSlots, w3.Warnings }))
end)

------------------------------------------------------------------ DataService: new saves / old saves (the real Load / Release)
local function dsServer(opts)
	opts = opts or {}
	local w = newWorld({ Studio = opts.Studio == true, Stores = opts.Stores })
	w.Game.JobId = opts.JobId or "live-1"
	-- the Studio test aid: ServerStorage attribute StudioFreshSave = true -> DataService runs in memory mode (always a new record)
	if opts.FreshSave then
		w.Services.ServerStorage = { GetAttribute = function(_, key) return key == "StudioFreshSave" and true or nil end }
	end
	w.AllowWarn = opts.FreshSave and { "had type", "StudioFreshSave" } or { "had type" }
	local env = w:Env()
	env.task = table.clone(env.task)
	env.task.wait = function(t)
		coroutine.yield(tonumber(t) or 0)
		return t
	end
	local ds = execute("DataService", DATA_SOURCE, env)
	ds.Init({})
	ds.Start()
	local probe = table.remove(w.Spawned, 1) -- the store probe; the autosave loop stays queued and never runs
	w.Spawned = {}
	probe[1](table.unpack(probe, 2, probe.n))
	w.DS = ds
	w.StoreName = w.Config.StoreName(w.Config.Data.StoreName)
	function w:Drive(fn, ...)
		local co = coroutine.create(fn)
		local out = table.pack(coroutine.resume(co, ...))
		local n = 0
		while coroutine.status(co) ~= "dead" do
			assert(out[1], out[2])
			n += 1
			assert(n < 200, "runaway waits")
			local t = tonumber(out[2]) or 0
			self.Clock += t
			self.Time += t
			out = table.pack(coroutine.resume(co))
		end
		assert(out[1], out[2])
		return table.unpack(out, 2, out.n)
	end
	function w:Rows()
		self.StoreOf(self.StoreName, "Standard")
		return self.Stores[self.StoreName].Rows
	end
	return w
end

local function stored(extra)
	local r = { Version = 3, Level = 7, XP = 0, BankGold = 50, CarriedGold = 0, Faction = "Halo", Class = "Mage",
		ClassChosen = true, TutorialStep = 99, HPPotionCount = 4, MPPotionCount = 1 }
	for k, v in extra or {} do r[k] = v end
	return r
end

runGroup("save: new saves empty, old saves HP / MP, stored slots kept", function()
	local q = qsWorld()
	local cases = {
		{ "a brand-new save", nil, ",," },
		{ "a v3 save from before the quick slots", stored(), "HP,MP," },
		{ "a v2 save (migrated)", stored({ Version = 2 }), "HP,MP," },
		{ "a save whose slots were emptied stays empty", stored({ QuickSlots = ",," }), ",," },
		{ "a save with its own slots keeps them", stored({ QuickSlots = "MP,,HP" }), "MP,,HP" },
		{ "broken slots are cleaned", stored({ QuickSlots = "MP,MP,Junk" }), "MP,," },
		{ "a slots field of the wrong type is the Default", stored({ QuickSlots = 5 }), ",," },
		{ "a too-long slots text is the Default", stored({ QuickSlots = "HP,MP," .. string.rep("y", 300) }), ",," },
	}
	for i, c in cases do
		local w = dsServer()
		local key = w.Config.Data.KeyPrefix .. tostring(100 + i)
		if c[2] then w:Rows()[key] = c[2] end
		local dp = w:NewPlayer(100 + i)
		local d = w:Drive(w.DS.Load, dp)
		check(type(d) == "table", "load: " .. c[1] .. " loads", show(d))
		if type(d) == "table" then
			-- the loaded data then reaches QuickSlotService at PlayerReady
			local v = d.QuickSlots
			local p, row = q:Join(100 + i, v == nil and MISSING or v)
			check(p:GetAttribute("QuickSlots") == c[3] and row.QuickSlots == c[3], "load + ready: " .. c[1],
				show({ Loaded = v, Attr = p:GetAttribute("QuickSlots"), Want = c[3] }))
		end
	end
	check(#q.ChangedLog == 0 and #q.QuestLog == 0, "loading changes nothing the quest hears")
end)

runGroup("save: the slots survive a release and the next load", function()
	local stores = {}
	local w = dsServer({ Stores = stores })
	local key = w.Config.Data.KeyPrefix .. "201"
	w:Rows()[key] = stored()
	local p = w:NewPlayer(201)
	local d = w:Drive(w.DS.Load, p)
	check(d and d.QuickSlots == nil, "an old save loads without the field (QuickSlotService fills it)", show(d and d.QuickSlots))
	local q = qsWorld()
	local qp = q:Join(201, MISSING)
	q.Data[qp] = d -- the same table as DataService's session data
	q.PS.PlayerReady:Fire(qp, d)
	check(d.QuickSlots == "HP,MP,", "PlayerReady gives the old save HP / MP", show(d.QuickSlots))
	q:Set(qp, 3, "HP")
	check(d.QuickSlots == ",MP,HP", "a change goes into the session data", show(d.QuickSlots))
	w:Drive(w.DS.Release, p)
	check(w:Rows()[key].QuickSlots == ",MP,HP", "the release writes the slots", show(w:Rows()[key].QuickSlots))
	local w2 = dsServer({ Stores = stores, JobId = "live-2" })
	local p2 = w2:NewPlayer(201)
	local d2 = w2:Drive(w2.DS.Load, p2)
	check(d2 and d2.QuickSlots == ",MP,HP", "the next load keeps them (never the old-save HP / MP again)", show(d2 and d2.QuickSlots))
	local w3 = dsServer({ Stores = stores, JobId = "live-3" })
	local p3 = w3:NewPlayer(202)
	w3:Drive(w3.DS.Load, p3)
	w3:Drive(w3.DS.Release, p3)
	local row = w3:Rows()[w3.Config.Data.KeyPrefix .. "202"]
	check(type(row) == "table" and row.QuickSlots == ",,", "a brand-new save is written with the Default", show(row))
end)

-- 검수 10/10 main apply: Studio runs DataService in memory mode (StudioFreshSave, or no DataStore access). Its new record must
-- have the empty Default slots like a first DataStore record - it had no field, so QuickSlotService treated it as an old save
-- (HP, MP) and KO1's 'put the potion in a quick slot' step passed at once.
runGroup("save: a Studio memory-mode record is a brand-new save with empty slots", function()
	local q = qsWorld()
	local w = dsServer({ Studio = true, FreshSave = true })
	local dp = w:NewPlayer(301)
	local d = w:Drive(w.DS.Load, dp)
	check(type(d) == "table" and d.QuickSlots == ",,", "memory mode: the new record has the empty Default slots", show(d and d.QuickSlots))
	check(d and d.TutorialStep == 0 and d.FirstJoinTime ~= nil, "(it is the brand-new tutorial record of memory mode)", show(d and d.TutorialStep))
	local noted = false
	for _, line in w.Warnings do if string.find(line, "StudioFreshSave", 1, true) then noted = true end end
	check(noted, "(the Studio fresh save notice shows memory mode really ran)", show(w.Warnings))
	local p, row = q:Join(301, d.QuickSlots)
	check(p:GetAttribute("QuickSlots") == ",," and row.QuickSlots == ",,", "load + ready: a Studio fresh save has no potion in a slot (not HP, MP)",
		show({ p:GetAttribute("QuickSlots"), row.QuickSlots }))
end)

finish()
