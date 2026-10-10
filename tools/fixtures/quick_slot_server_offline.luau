-- quick_slot_server_offline.luau : A23-109 quick slots 1·2·3 (server: QuickSlotService), offline.
-- tools/test_quick_slot_server.py injects (before tools/fixtures/dev2_kit.luau): CONFIG_SOURCE, UTIL_SOURCE, QUICK_SOURCE,
-- NET_SOURCE, MAIN_SOURCE (the CURRENT src) and CLIENT_PARSE (QuickSlots.Parse cut from the client's QuickSlots.luau).
-- QuickSlotService runs for real on a PlayerService double (data rows, IsReady, PlayerReady). The client side has its own
-- suite (tools/test_quick_slots.py, 게임성 개발 1).

------------------------------------------------------------------ a server with the real QuickSlotService
local MISSING = {} -- Join(id, MISSING): the save has no QuickSlots field

local function qsWorld(opts)
	opts = opts or {}
	local w = newWorld({ EditConfig = opts.EditConfig })
	w.AllowWarn = opts.AllowWarn
	local Signal = w.Util.Signal
	local data = {}
	local ps = { PlayerReady = Signal.new(), PlayerLeaving = Signal.new() }
	function ps.GetData(p) return data[p] end
	function ps.IsReady(p) return w.Ready[p] == true end
	local reg = { PlayerService = ps }
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
	local p0, d0 = w:Join(1, MISSING)
	check(p0:GetAttribute("QuickSlots") == "HP,MP,", "a save without slots shows the Default (HP, MP, empty)",
		tostring(p0:GetAttribute("QuickSlots")))
	check(d0.QuickSlots == nil, "a missing field stays missing (the Default may change later)", tostring(d0.QuickSlots))
	check(same(w.Quick.Get(p0), { "HP", "MP", "" }), "Get = the Default", show(w.Quick.Get(p0)))
	local cases = {
		{ "MP,,HP", "MP,,HP" },
		{ ",,", ",," },
		{ "", ",," },
		{ "HP,HP,MP", "HP,,MP" }, -- a repeat is emptied
		{ "Jelly,MP,Enh70", ",MP," }, -- not a quick item
		{ "hp, MP,", ",," }, -- exact keys only
		{ "HP", "HP,," }, -- short: the rest empty
		{ "MP,HP,,HP,x", "MP,HP," }, -- extra parts ignored
		{ "MP,HP," .. string.rep("x", 200), "HP,MP," }, -- over the length cap: broken = Default
		{ 5, "HP,MP," },
		{ true, "HP,MP," },
		{ { "MP" }, "HP,MP," },
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
	check(d.QuickSlots == nil, "the refused player's save was never written")
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
	local p = w:Join(1, MISSING)
	check(p:GetAttribute("QuickSlots") == ",MP,", "unknown and repeated defaults become empty", tostring(p:GetAttribute("QuickSlots")))
end)

finish()
