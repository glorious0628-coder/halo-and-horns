-- save_lock_offline.luau : DataService load-lock retries (A23-48 batch, 검수 2026-10-06: 6 s x 5, 'Loading your save…',
-- Studio locks expire for live servers) and the StudioFreshSave guard (never on outside Studio). tools/test_save_lock.py
-- injects CONFIG_SOURCE, UTIL_SOURCE and DATA_SOURCE (the CURRENT src) in front of dev2_kit.luau; this file follows.
-- The real DataService runs on the kit's DataStore double. task.wait yields a coroutine; the driver advances both
-- clocks by the waited seconds (nothing really sleeps) and may change the stored record between two tries.

local STORE = "HaloHorns_Player_v1"
local NOW = 1790000000

-- one server: w (kit world) + its DataService, started (the store probe runs at once; the autosave loop never runs)
local function newServer(opts)
	local w = newWorld({ Studio = opts.Studio, Stores = opts.Stores, Time = opts.Time or NOW })
	w.Game.JobId = opts.JobId or "live-1"
	local ss = newInstance("ServerStorage", w)
	ss.Name = "ServerStorage"
	ss.Reads = 0
	rawset(ss, "GetAttribute", function(self, key)
		if key == "StudioFreshSave" then ss.Reads += 1 end
		return self.Attrs[key]
	end)
	if opts.Fresh ~= nil then ss.Attrs.StudioFreshSave = opts.Fresh end
	w.Services.ServerStorage = ss
	w.SS = ss
	w.AllowWarn = { "locked by another server", "load attempt", "StudioFreshSave is on", "aborted: a newer session" }

	w.Waits = {}
	local env = w:Env()
	env.task = table.clone(env.task)
	env.task.wait = function(t)
		t = tonumber(t) or 0
		table.insert(w.Waits, t)
		coroutine.yield(t)
		return t
	end
	local ds = execute("DataService", DATA_SOURCE, env)
	ds.Init({})
	ds.Start()
	local probe = table.remove(w.Spawned, 1) -- the store probe; the autosave loop stays queued and never runs
	w.Spawned = {}
	probe[1](table.unpack(probe, 2, probe.n))
	w.DS = ds

	-- runs fn(...) in a coroutine; every task.wait advances the clocks; onWait(n, seconds) runs before the next resume
	function w:Drive(onWait, fn, ...)
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
			if onWait then onWait(n, t) end
			out = table.pack(coroutine.resume(co))
		end
		assert(out[1], out[2])
		return table.unpack(out, 2, out.n)
	end
	return w
end

local function rows(w)
	w.StoreOf(STORE, "Standard")
	return w.Stores[STORE].Rows
end

local function keyOf(w, userId) return w.Config.Data.KeyPrefix .. tostring(userId) end

local function updates(w, key)
	local n = 0
	for _, c in w.DSCalls do
		if c.Op == "Update" and c.Store == STORE and c.Key == key then n += 1 end
	end
	return n
end

local function storeCalls(w, key)
	local n = 0
	for _, c in w.DSCalls do
		if c.Store == STORE and c.Key == key then n += 1 end
	end
	return n
end

local function savedRecord(level, lock)
	return { Version = 3, Level = level, XP = 0, BankGold = 50, CarriedGold = 0, Faction = "Halo", Class = "Mage",
		ClassChosen = true, TutorialStep = 99, SessionLock = lock, SessionToken = "old-token" }
end

-- how often SaveLoading was set to true / the final value
local function loadingSets(p)
	local on = 0
	for _, e in p.Log do
		if e.Key == "SaveLoading" and e.Value == true then on += 1 end
	end
	return on
end

local function noticeCount(w, p, text)
	local n = 0
	for _, t in w:NoticesFor(p, 0) do
		if t == text then n += 1 end
	end
	return n
end

local function sameList(a, b)
	if #a ~= #b then return false end
	for i = 1, #a do if a[i] ~= b[i] then return false end end
	return true
end

runGroup("config", function()
	local w = newServer({ Studio = false })
	local C = w.Config
	check(C.Data.LoadRetries == 5 and C.Data.LoadRetryDelay == 6, "load retries: 5 tries, 6 s apart",
		show({ C.Data.LoadRetries, C.Data.LoadRetryDelay }))
	check(C.Text.SaveLoading == "Loading your save…", "Config.Text.SaveLoading = 'Loading your save…'", tostring(C.Text.SaveLoading))
	check(C.Data.LockTimeout == 120, "a lock older than 120 s is dead (unchanged)", tostring(C.Data.LockTimeout))
end)

runGroup("live lock: wait 6 s x 4, the 5th try takes it", function()
	local w = newServer({ Studio = false, JobId = "live-2" })
	local key = keyOf(w, 101)
	rows(w)[key] = savedRecord(7, { JobId = "live-other", Time = NOW - 5 })
	local p = w:NewPlayer(101)
	local during = {}
	local data = w:Drive(function(n)
		during[n] = { Attr = p:GetAttribute("SaveLoading"), Notices = noticeCount(w, p, w.Config.Text.SaveLoading) }
	end, w.DS.Load, p)
	check(type(data) == "table" and data.Level == 7, "the saved data loads after the waits (Level 7)", show(data))
	check(updates(w, key) == 5, "5 tries (UpdateAsync) in all", tostring(updates(w, key)))
	check(sameList(w.Waits, { 6, 6, 6, 6 }), "4 waits of 6 s between the tries (no wait after the last)", show(w.Waits))
	check(w.Clock == 1000 + 24, "about 24 s until the lock is taken", tostring(w.Clock - 1000))
	local rec = rows(w)[key]
	check(rec.SessionLock and rec.SessionLock.JobId == "live-2" and rec.SessionToken ~= "old-token",
		"the record now carries this server's lock and a new token", show(rec.SessionLock))
	check(rec.SessionLock and rec.SessionLock.Studio == nil, "a live server's lock has no Studio flag", show(rec.SessionLock))
	check(during[1] and during[1].Attr == true, "SaveLoading = true while the player waits", show(during[1]))
	check(during[1] and during[1].Notices == 1 and during[4] and during[4].Notices == 1,
		"'Loading your save…' told once (at the first wait, not again)", show(during))
	check(loadingSets(p) == 1, "SaveLoading set once", tostring(loadingSets(p)))
	check(p:GetAttribute("SaveLoading") == nil, "SaveLoading cleared when the load ends", tostring(p:GetAttribute("SaveLoading")))
	check(noticeCount(w, p, w.Config.Text.SaveLoading) == 1, "one notice in all", show(w:NoticesFor(p, 0)))
end)

runGroup("live lock released during the wait", function()
	local w = newServer({ Studio = false, JobId = "live-2" })
	local key = keyOf(w, 102)
	rows(w)[key] = savedRecord(9, { JobId = "live-other", Time = NOW - 2 })
	local p = w:NewPlayer(102)
	local data = w:Drive(function(n)
		if n == 2 then rows(w)[key].SessionLock = nil end -- the other server's final save released it
	end, w.DS.Load, p)
	check(type(data) == "table" and data.Level == 9, "loads the released record", show(data))
	check(updates(w, key) == 3 and sameList(w.Waits, { 6, 6 }), "3 tries, 2 waits", show({ updates(w, key), w.Waits }))
	check(noticeCount(w, p, w.Config.Text.SaveLoading) == 1 and p:GetAttribute("SaveLoading") == nil,
		"one notice, the mark cleared", show({ w:NoticesFor(p, 0), p:GetAttribute("SaveLoading") }))
end)

runGroup("no lock / old lock / own lock: no wait", function()
	local w = newServer({ Studio = false, JobId = "live-3" })
	local cases = {
		{ Id = 201, Lock = nil, Name = "no lock" },
		{ Id = 202, Lock = { JobId = "live-other", Time = NOW - 121 }, Name = "a lock older than LockTimeout" },
		{ Id = 203, Lock = { JobId = "live-3", Time = NOW - 1 }, Name = "this server's own lock" },
	}
	for _, c in cases do
		local key = keyOf(w, c.Id)
		rows(w)[key] = savedRecord(c.Id - 190, c.Lock)
		local p = w:NewPlayer(c.Id)
		local before = #w.Waits
		local data = w:Drive(nil, w.DS.Load, p)
		check(type(data) == "table" and data.Level == c.Id - 190, c.Name .. ": loads", show(data))
		check(updates(w, key) == 1 and #w.Waits == before, c.Name .. ": one try, no wait", show({ updates(w, key), w.Waits }))
		check(loadingSets(p) == 0 and noticeCount(w, p, w.Config.Text.SaveLoading) == 0,
			c.Name .. ": no 'Loading your save…'", show(w:NoticesFor(p, 0)))
	end
end)

runGroup("Studio locks never hold a live server", function()
	local w = newServer({ Studio = false, JobId = "live-4" })
	local cases = {
		{ Id = 301, Lock = { JobId = "", Time = NOW - 1 }, Name = "a Studio lock (JobId empty)" },
		{ Id = 302, Lock = { JobId = "team-test-1", Studio = true, Time = NOW - 1 }, Name = "a lock marked Studio = true" },
	}
	for _, c in cases do
		local key = keyOf(w, c.Id)
		rows(w)[key] = savedRecord(c.Id - 290, c.Lock)
		local p = w:NewPlayer(c.Id)
		local data = w:Drive(nil, w.DS.Load, p)
		check(type(data) == "table" and data.Level == c.Id - 290, c.Name .. ": loads at once", show(data))
		check(updates(w, key) == 1 and #w.Waits == 0, c.Name .. ": one try, no wait", show({ updates(w, key), w.Waits }))
		check(loadingSets(p) == 0, c.Name .. ": no loading mark", tostring(loadingSets(p)))
		local rec = rows(w)[key]
		check(rec.SessionLock and rec.SessionLock.JobId == "live-4", c.Name .. ": the live server owns it now", show(rec.SessionLock))
	end
end)

runGroup("a Studio session writes Studio = true and still waits for a live lock", function()
	local stores = {}
	local w = newServer({ Studio = true, JobId = "", Stores = stores })
	check(w.DS.IsMemoryMode() == false, "Studio with API access and no StudioFreshSave: the real store", tostring(w.DS.IsMemoryMode()))
	local key = keyOf(w, 401)
	rows(w)[key] = savedRecord(11, nil)
	local p = w:NewPlayer(401)
	local data = w:Drive(nil, w.DS.Load, p)
	check(type(data) == "table" and data.Level == 11, "Studio loads the save", show(data))
	local rec = rows(w)[key]
	check(rec.SessionLock and rec.SessionLock.JobId == "" and rec.SessionLock.Studio == true,
		"the Studio session's lock is marked Studio = true", show(rec.SessionLock))
	check(w.DS.Save(p, false) == true and rows(w)[key].SessionLock.Studio == true, "a Studio save keeps the mark",
		show(rows(w)[key].SessionLock))

	-- a live server of the same game right after (Studio stopped without the final unlocked save): no wait
	local live = newServer({ Studio = false, JobId = "live-5", Stores = stores, Time = NOW + 3 })
	local q = live:NewPlayer(401)
	local again = live:Drive(nil, live.DS.Load, q)
	check(type(again) == "table" and again.Level == 11 and #live.Waits == 0, "the live server takes the Studio lock at once",
		show({ again and again.Level, live.Waits }))
	-- the Studio session can no longer write over the live session's record
	check(w.DS.Save(p, false) == false and rows(w)[key].SessionLock.JobId == "live-5",
		"the stopped Studio session's later save is refused (SessionToken)", show(rows(w)[key].SessionLock))

	-- Studio meeting a LIVE lock waits like any server
	local w2 = newServer({ Studio = true, JobId = "" })
	local key2 = keyOf(w2, 402)
	rows(w2)[key2] = savedRecord(12, { JobId = "live-9", Time = NOW - 3 })
	local p2 = w2:NewPlayer(402)
	local d2 = w2:Drive(nil, w2.DS.Load, p2)
	check(type(d2) == "table" and updates(w2, key2) == 5 and sameList(w2.Waits, { 6, 6, 6, 6 }),
		"Studio waits for a live server's lock (6 s x 4, takes it at the 5th try)", show({ updates(w2, key2), w2.Waits }))
end)

-- review 2026-10-06 evening: the record has NO lock any more (the live session left with its final release), so only the
-- SessionToken stands between a stopped Studio session and the live data
runGroup("a stopped Studio session never writes over a live session that already left (SessionToken)", function()
	local stores = {}
	local function studioAndLive(userId, jobId)
		local w = newServer({ Studio = true, JobId = "", Stores = stores })
		table.insert(w.AllowWarn, "final save failed")
		local key = keyOf(w, userId)
		rows(w)[key] = savedRecord(11, nil)
		local p = w:NewPlayer(userId)
		local data = w:Drive(nil, w.DS.Load, p)
		local live = newServer({ Studio = false, JobId = jobId, Stores = stores, Time = NOW + 3 })
		local q = live:NewPlayer(userId)
		local liveData = live:Drive(nil, live.DS.Load, q)
		liveData.Level = 21
		live:Drive(nil, live.DS.Release, q)
		return w, key, p, data
	end
	local w, key, p, data = studioAndLive(403, "live-6b")
	check(type(data) == "table" and rows(w)[key].SessionLock == nil and rows(w)[key].Level == 21,
		"the live session took over, played and left: no lock, its data saved", show({ rows(w)[key].SessionLock, rows(w)[key].Level }))
	data.Level = 99
	check(w.DS.Save(p, false) == false and rows(w)[key].Level == 21 and rows(w)[key].SessionLock == nil,
		"the stopped Studio session's save is refused (no lock left: the SessionToken) and the live data stays",
		show({ rows(w)[key].Level, rows(w)[key].SessionLock }))
	-- the same with the final release as the Studio session's first write after the takeover
	local w2, key2, p2, data2 = studioAndLive(404, "live-6c")
	data2.Level = 98
	w2:Drive(nil, w2.DS.Release, p2)
	check(rows(w2)[key2].Level == 21 and rows(w2)[key2].SessionLock == nil and w2.DS.Get(p2) == nil,
		"its release is refused too: the record stays the live session's data", show({ rows(w2)[key2].Level, rows(w2)[key2].SessionLock }))
end)

runGroup("DataStore errors: retry with the same notice", function()
	local w = newServer({ Studio = false, JobId = "live-6" })
	local key = keyOf(w, 501)
	rows(w)[key] = savedRecord(13, nil)
	w.Fail[STORE .. ":Update"] = 2
	local p = w:NewPlayer(501)
	local data = w:Drive(nil, w.DS.Load, p)
	check(type(data) == "table" and data.Level == 13, "loads at the 3rd try", show(data))
	check(sameList(w.Waits, { 6, 6 }), "two 6 s waits", show(w.Waits))
	check(noticeCount(w, p, w.Config.Text.SaveLoading) == 1 and p:GetAttribute("SaveLoading") == nil,
		"one 'Loading your save…', cleared after", show({ w:NoticesFor(p, 0), p:GetAttribute("SaveLoading") }))
end)

runGroup("the player leaves during the wait", function()
	local w = newServer({ Studio = false, JobId = "live-7" })
	local key = keyOf(w, 601)
	rows(w)[key] = savedRecord(14, { JobId = "live-other", Time = NOW - 1 })
	local p = w:NewPlayer(601)
	local data = w:Drive(function(n) if n == 1 then w:Remove(p) end end, w.DS.Load, p)
	check(data == nil, "Load gives nothing for a player who left", show(data))
	check(updates(w, key) == 1, "no more tries after leaving", tostring(updates(w, key)))
	check(rows(w)[key].SessionLock.JobId == "live-other", "the other server's lock stays", show(rows(w)[key].SessionLock))
	check(p:GetAttribute("SaveLoading") == nil, "the mark is cleared anyway", tostring(p:GetAttribute("SaveLoading")))
end)

runGroup("StudioFreshSave is never on outside Studio", function()
	-- live server, attribute set (e.g. left in a published place): ignored, never even read
	local w = newServer({ Studio = false, JobId = "live-8", Fresh = true })
	check(w.DS.IsMemoryMode() == false, "a live server stays on the real store", tostring(w.DS.IsMemoryMode()))
	check(w.SS.Reads == 0, "the attribute is not even read outside Studio", tostring(w.SS.Reads))
	local key = keyOf(w, 701)
	rows(w)[key] = savedRecord(15, nil)
	local p = w:NewPlayer(701)
	local data = w:Drive(nil, w.DS.Load, p)
	check(type(data) == "table" and data.Level == 15 and updates(w, key) == 1, "the real save loads", show(data))

	-- Studio + StudioFreshSave: a fresh in-memory save, the stored one untouched
	local s = newServer({ Studio = true, JobId = "", Fresh = true })
	check(s.DS.IsMemoryMode() == true and s.SS.Reads >= 1, "Studio + StudioFreshSave = true: memory mode",
		show({ s.DS.IsMemoryMode(), s.SS.Reads }))
	local skey = keyOf(s, 702)
	rows(s)[skey] = savedRecord(16, nil)
	local sp = s:NewPlayer(702)
	local fresh = s:Drive(nil, s.DS.Load, sp)
	check(type(fresh) == "table" and fresh.Level == 1 and fresh.TutorialStep == s.Config.Tutorial.Steps.Kill,
		"a brand-new save (Level 1, first-time tutorial)", show({ fresh and fresh.Level, fresh and fresh.TutorialStep }))
	check(storeCalls(s, skey) == 0 and rows(s)[skey].Level == 16, "the stored save is never read or written", tostring(storeCalls(s, skey)))
	check(s.DS.Save(sp, false) == true and storeCalls(s, skey) == 0, "saves stay in memory", tostring(storeCalls(s, skey)))

	-- Studio, attribute false: the real store
	local t = newServer({ Studio = true, JobId = "", Fresh = false })
	check(t.DS.IsMemoryMode() == false, "Studio + StudioFreshSave = false: the real store", tostring(t.DS.IsMemoryMode()))
end)

finish()
