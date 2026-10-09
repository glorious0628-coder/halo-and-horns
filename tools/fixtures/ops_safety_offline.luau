-- ops_safety_offline.luau : 시스템 점검 1회차 - the environments (Config.StoreName), the server error record
-- (ServerErrorService) and the live switchboard (SwitchService), 게임성 개발 3, 2026-10-09. tools/test_ops_safety.py binds
-- CONFIG_SOURCE, UTIL_SOURCE, ERR_SOURCE and SWITCH_SOURCE in front of dev2_kit.luau + dev3_world.luau; this file follows.
-- Both services run from source; ScriptContext / RunService.Heartbeat / the analytics log are doubles.

local NOON = 1789959600

local function opsWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local w = dev3World(o)
	local Signal = w.Util.Signal
	w.ScriptError = Signal.new()
	w.Heartbeat = Signal.new()
	w.Services.ScriptContext = { Error = w.ScriptError }
	w.Services.RunService.Heartbeat = w.Heartbeat
	w.Services.RunService.IsStudio = function() return o.Studio ~= false end
	w.Logged = {} -- the analytics log: { P, Name, Value, A, B, C }
	w.Reg.TelemetryService = { Custom = function(p, name, value, a, b, c)
		table.insert(w.Logged, { P = p, Name = name, Value = value, A = a, B = b, C = c })
	end }
	w.Reg.GameStateAttrs = {}
	return w
end

local function startErrors(w)
	w:Service("ServerErrorService", ERR_SOURCE)
	w:InitStart({ "ServerErrorService" })
	return w.Reg.ServerErrorService
end

local function startSwitches(w, extra)
	w:Service("SwitchService", SWITCH_SOURCE)
	w:InitStart({ "SwitchService" })
	return w.Reg.SwitchService
end

local function hero(w, id)
	return w:Arrive(id, { Data = { Faction = "Halo", Class = "Warrior", ClassChosen = true, Level = 10 } })
end

local function setDoc(w, store, doc)
	w.StoreOf(store, "Standard")
	w.Stores[store].Rows.Live = doc
end

local function row(w, store, key)
	local st = w.Stores[store]
	return st and st.Rows[key]
end

------------------------------------------------------------------ environments
runGroup("environments", function()
	local w = opsWorld()
	local env = nativeEnv()
	env.game = w.Game
	local C = execute("Config", CONFIG_SOURCE, env)
	check(C.EnvName() == "Dev" and C.StoreName("HaloHorns_Player_v1") == "HaloHorns_Player_v1", "the dev place keeps every store name", C.StoreName("HaloHorns_Player_v1"))
	C.Env.Names[w.Game.PlaceId] = "Beta"
	check(C.EnvName() == "Beta" and C.StoreName("HaloHorns_Player_v1") == "HaloHorns_Player_v1_Beta", "a Beta place: '_Beta' on every store", C.StoreName("HaloHorns_Player_v1"))
	C.Env.Names[w.Game.PlaceId] = "Live"
	check(C.EnvName() == "Live" and C.StoreName("HH_Rank_") == "HH_Rank__Live" and C.StoreName("X") == "X_Live", "a Live place: '_Live'", C.StoreName("X"))
	C.Env.Names[w.Game.PlaceId] = "Test"
	check(C.EnvName() == "Dev" and C.StoreName("X") == "X", "an unknown name is Dev (never a surprise suffix)", C.EnvName())
	C.Env.Names[w.Game.PlaceId] = nil
	C.Env.Names[12345] = "Live"
	check(C.EnvName() == "Dev", "another place's name does not count", C.EnvName())
	w.Game.PlaceId = 12345
	check(C.EnvName() == "Live", "the place id decides", C.EnvName())
	w.Game.PlaceId = "x"
	check(C.EnvName() == "Dev", "a broken place id: Dev", C.EnvName())
	check(C.BuildLabel == "beta-prep 2026.10.09", "the build label is current", C.BuildLabel)
	check(C.ServerErrors.MaxPerMinute == 5 and C.ServerErrors.Keep == 50, "5 a minute, the last 50", show(C.ServerErrors))
	local keys = {}
	for k in C.Switches.Defs do table.insert(keys, k) end
	table.sort(keys)
	check(table.concat(keys, ",") == "CrownWar,Goose,Halloween,PassSales", "the listed switches", table.concat(keys, ","))
end)

------------------------------------------------------------------ the error record
runGroup("error text", function()
	local w = opsWorld()
	local E = startErrors(w)
	check(E.Clean("ServerScriptService.Foo:123: attempt to index nil with 'x' (user 1234567)", 200) == "ServerScriptService.Foo:#: attempt to index nil with 'x' (user #)",
		"digit runs of 3+ become '#' (a UserId never reaches the log)", E.Clean("ServerScriptService.Foo:123: attempt to index nil with 'x' (user 1234567)", 200))
	check(E.Clean("a\nb\tc\r\nd", 20) == "a b c d", "control characters become spaces", E.Clean("a\nb\tc\r\nd", 20))
	check(E.Clean("   padded   ", 20) == "padded", "trimmed", E.Clean("   padded   ", 20))
	check(E.Clean("a\1\2b\127c", 20) == "a b c", "other control characters become spaces too", E.Clean("a\1\2b\127c", 20))
	check(E.Clean(string.rep("x", 200), 80) == string.rep("x", 80), "cut to the limit", #E.Clean(string.rep("x", 200), 80))
	check(E.Clean(nil, 10) == "" and E.Clean(5, 10) == "5" and E.Clean({}, 10) ~= nil, "nil / numbers / tables never error", "")
	check(E.Clean("ab", 0) == "a", "a zero limit is one letter", E.Clean("ab", 0))
end)

runGroup("error record", function()
	local w = opsWorld()
	local E = startErrors(w)
	local p = hero(w, 1)
	check(E.Record("Error", "QuestService", "boom 12345", 1) == true, "an error is logged", "")
	local lg = w.Logged[1]
	check(#w.Logged == 1 and lg.P == p and lg.Name == "ServerError" and lg.Value == 1 and lg.A == "QuestService" and lg.B == "boom #" and lg.C == "Error",
		"ONE event 'ServerError': value 1, fields script / message / kind", show({ lg.Name, lg.Value, lg.A, lg.B, lg.C }))
	-- a slow tick: value = milliseconds
	E.Record("Slow", "Heartbeat", "tick 640 ms", 640)
	local slow = w.Logged[2]
	check(slow and slow.Value == 640 and slow.C == "Slow" and slow.A == "Heartbeat", "a slow tick: value = ms, kind Slow", slow and (tostring(slow.Value) .. slow.C .. slow.A))
	-- the minute's limit: 5 events, then only the record
	w:Advance(61)
	w.Logged = {}
	local results = {}
	for i = 1, 8 do table.insert(results, E.Record("Error", "S" .. i, "m" .. i, 1)) end
	check(#w.Logged == 5 and results[5] == true and results[6] == false and results[8] == false, "at most 5 a minute for the server", #w.Logged)
	local newest = E.Recent()
	check(newest[1].S == "S8" and newest[1].M == "m8", "all are still in the record (newest first)", show(newest[1]))
	w:Advance(61)
	check(E.Record("Error", "Later", "again", 1) == true and #w.Logged == 6, "the next minute logs again", #w.Logged)
	-- the same finding in a row: one row with a count
	w:Advance(61)
	w.Logged = {}
	E.Record("Error", "Dup", "same message", 1)
	E.Record("Error", "Dup", "same message", 1)
	E.Record("Error", "Dup", "same message", 1)
	local r = E.Recent()
	check(r[1].S == "Dup" and r[1].N == 3 and r[2].S ~= "Dup", "three in a row = one row x3", show({ r[1].N, r[2] and r[2].S }))
	check(#w.Logged == 3, "(each still counts toward the minute's limit)", #w.Logged)
	E.Record("Error", "Dup", "another message", 1)
	check(E.Recent()[1].M == "another message" and E.Recent()[2].N == 3, "a different message starts a new row", show(E.Recent()[1]))
	-- the same finding long after: a new row
	w:Advance(120)
	E.Record("Error", "Dup", "another message", 1)
	check(E.Recent()[1].N == 1 and E.Recent()[2].N == 1 and E.Recent()[2].M == "another message", "the same message 2 minutes later is a new row", show({ E.Recent()[1].N, E.Recent()[2].N }))
	-- Recent is a copy
	E.Recent()[1].S = "tampered"
	check(E.Recent()[1].S == "Dup", "Recent() is a copy", E.Recent()[1].S)
end)

runGroup("nobody online", function()
	local w = opsWorld()
	local E = startErrors(w)
	check(E.Record("Error", "Lonely", "no player", 1) == false and #w.Logged == 0, "no player to log for: nothing sent", #w.Logged)
	check(E.Recent()[1].S == "Lonely", "but the record keeps it", show(E.Recent()[1]))
end)

runGroup("error record: ring of 50", function()
	local w = opsWorld()
	local E = startErrors(w)
	hero(w, 1)
	for i = 1, 70 do
		w:Advance(1)
		E.Record("Error", "S", "m" .. i, 1)
	end
	local r = E.Recent()
	check(#r == 50 and r[1].M == "m70" and r[50].M == "m21", "the last 50, newest first", show({ #r, r[1].M, r[50].M }))
end)

runGroup("hooks", function()
	local w = opsWorld()
	local E = startErrors(w)
	hero(w, 1)
	-- ScriptContext.Error(message, trace, script)
	w.ScriptError:Fire("Boom at 99999", "trace", { Name = "SkillService" })
	local r = E.Recent()
	check(r[1] and r[1].K == "Error" and r[1].S == "SkillService" and r[1].M == "Boom at #", "ScriptContext.Error is recorded with the script's name", show(r[1]))
	w.ScriptError:Fire("No script", "trace", nil)
	check(E.Recent()[1].S == "?", "an error with no script: '?'", show(E.Recent()[1]))
	-- slow ticks: nothing in the first 30 s (the world builds), then > 0.5 s counts
	local before = #E.Recent()
	w.Heartbeat:Fire(2.0)
	check(#E.Recent() == before, "the first 30 s are ignored", #E.Recent())
	w:Advance(31)
	w.Heartbeat:Fire(0.1)
	w.Heartbeat:Fire(0.5)
	check(#E.Recent() == before, "a fast or exactly-0.5 tick is fine", #E.Recent())
	w.Heartbeat:Fire(0.64)
	check(E.Recent()[1].K == "Slow" and E.Recent()[1].S == "Heartbeat" and E.Recent()[1].M == "tick # ms", "a slow tick is recorded (the ms are the value; a number in a message is cleaned)", show(E.Recent()[1]))
	local lastLog = w.Logged[#w.Logged]
	check(lastLog and lastLog.Name == "ServerError" and lastLog.Value == 640 and lastLog.C == "Slow", "and logged with the milliseconds as its value", lastLog and tostring(lastLog.Value))
	local closer = #w.BoundToClose
	check(closer == 1, "one close handler (the last flush)", closer)
end)

runGroup("error store", function()
	local w = opsWorld({ Studio = false })
	local E = startErrors(w)
	hero(w, 1)
	local base = w.Config.StoreName("HaloHorns_Errors_v1")
	check(E.Flush() == false, "nothing to save yet", "")
	E.Record("Error", "A", "first", 1)
	w:Advance(5)
	E.Record("Slow", "Heartbeat", "tick 700 ms", 700)
	check(E.Flush() == true, "a flush saves", "")
	local doc = row(w, base, "Recent")
	check(doc and #doc == 2 and doc[1].K == "Slow" and doc[2].M == "first", "newest first in the document", show(doc))
	check(E.Flush() == false, "and nothing is saved twice", "")
	-- a second server merges with the first
	w:Advance(10)
	local w2 = opsWorld({ Studio = false })
	w2.Stores = w.Stores
	local E2 = startErrors(w2)
	hero(w2, 2)
	w2.Time = w.Time
	E2.Record("Error", "B", "from the other server", 1)
	E2.Flush()
	local doc2 = row(w, base, "Recent")
	check(doc2 and #doc2 == 3 and doc2[1].S == "B", "another server's flush merges (3 rows, the newest first)", show(doc2))
	-- fifty rows at most
	for i = 1, 60 do
		w:Advance(1)
		E.Record("Error", "S", "n" .. i, 1)
	end
	E.Flush()
	check(#row(w, base, "Recent") == 50, "the document keeps 50", #row(w, base, "Recent"))
	-- a failed save keeps the pending rows for the next try
	E.Record("Error", "Fail", "will retry", 1)
	w.Fail[base .. ":Update"] = 1
	check(E.Flush() == false, "a failed save", "")
	check(#w.Warnings > 0, "(and says so)", #w.Warnings)
	w.Warnings = {}
	check(E.Flush() == true and row(w, base, "Recent")[1].M == "will retry", "the next flush saves what was pending", show(row(w, base, "Recent")[1]))
	-- Studio reads / text
	check(string.find(E.Debug(), "will retry", 1, true) ~= nil and string.find(E.Debug("stored"), "will retry", 1, true) ~= nil, "Debug text from this server and from the store", "")
	check(E.Text({}) == "(no errors)", "an empty list says so", "")
	-- junk in the document is ignored
	w.Stores[base].Rows.Recent = { "oops", { T = "x" }, { T = 5, K = "Error", S = "ok", M = "kept", N = 2 }, 7 }
	local list = E.Stored("stored")
	check(#list == 1 and list[1].M == "kept" and list[1].N == 2, "broken rows are dropped", show(list))
end)

runGroup("error store: Beta", function()
	local w = opsWorld({ Studio = false, EditConfig = function(c) c.EnvName = function() return "Beta" end end })
	local E = startErrors(w)
	hero(w, 1)
	E.Record("Error", "S", "in beta", 1)
	E.Flush()
	check(row(w, "HaloHorns_Errors_v1_Beta", "Recent") ~= nil and row(w, "HaloHorns_Errors_v1", "Recent") == nil, "a Beta server writes the '_Beta' document only", "")
end)

runGroup("error store: Studio and live", function()
	local w = opsWorld({ Studio = true })
	local E = startErrors(w)
	hero(w, 1)
	E.Record("Error", "S", "in studio", 1)
	E.Flush()
	local base = w.Config.StoreName("HaloHorns_Errors_v1")
	check(row(w, base .. "_STUDIO", "Recent") ~= nil and row(w, base, "Recent") == nil, "Studio writes its own '_STUDIO' copy, never the real one", "")
	w.Stores[base] = { Rows = { Recent = { { T = 1, K = "Error", S = "real", M = "from the live game", N = 1 } } }, Kind = "Standard", Log = {} }
	check(string.find(E.Debug("live"), "from the live game", 1, true) ~= nil and string.find(E.Debug("stored"), "in studio", 1, true) ~= nil,
		"('live' reads the real document, 'stored' Studio's)", E.Debug("live"))
end)

------------------------------------------------------------------ the switchboard
runGroup("switches: parse", function()
	local w = opsWorld()
	local SW = startSwitches(w)
	local P = SW.Parse
	check(show(P(nil)) == "{}" and show(P("oops")) == "{}" and show(P({})) == "{}" and show(P({ Set = "x" })) == "{}", "junk documents change nothing", "")
	check(P({ Set = { PassSales = false } }).PassSales == false and P({ Set = { PassSales = true } }).PassSales == true, "a listed Bool", "")
	check(P({ Set = { PassSales = "no", Goose = 0, Halloween = {}, CrownWar = nil } }).PassSales == nil and P({ Set = { Goose = 0 } }).Goose == nil, "a wrong type is ignored (the default stays)", "")
	check(P({ Set = { Cheats = true, Admin = true } }).Cheats == nil, "an unlisted key is ignored", "")
	check(SW.Sanitize({ Type = "Number", Min = 1, Max = 5 }, 99) == 5 and SW.Sanitize({ Type = "Number", Min = 1, Max = 5 }, -9) == 1 and SW.Sanitize({ Type = "Number", Min = 1, Max = 5 }, 3) == 3,
		"a Number is clamped to Min..Max", "")
	check(SW.Sanitize({ Type = "Number", Min = 1, Max = 5 }, 0 / 0) == nil and SW.Sanitize({ Type = "Number", Min = 1, Max = 5 }, math.huge) == nil and SW.Sanitize({ Type = "Number" }, "3") == nil,
		"NaN / inf / strings are not numbers", "")
	check(SW.Sanitize(nil, true) == nil and SW.Sanitize({ Type = "Bool" }, 1) == nil, "no def / a number for a Bool: nothing", "")
end)

runGroup("switches: reading", function()
	local w = opsWorld({ Studio = false })
	local SW = startSwitches(w)
	local gs = w.GameState
	local base = w.Config.StoreName("HaloHorns_Switches_v1")
	check(SW.On("PassSales") == true and SW.On("Halloween") == true and SW.On("CrownWar") == true and SW.On("Goose") == true, "all on by default", "")
	check(SW.On("NoSuchSwitch") == true and SW.Value("NoSuchSwitch") == true, "an unknown key is on (nothing is blocked by a typo)", "")
	check(gs:GetAttribute("SwitchPassSales") == true, "GameState SwitchPassSales = true at the start", tostring(gs:GetAttribute("SwitchPassSales")))
	-- the document
	local changes = {}
	SW.Changed:Connect(function(k, v) table.insert(changes, k .. "=" .. tostring(v)) end)
	setDoc(w, base, { Set = { PassSales = false, Goose = false, Bogus = false }, At = 1 })
	check(SW.Refresh() == true and SW.On("PassSales") == false and SW.On("Goose") == false and SW.On("Halloween") == true, "the document turns two switches off", "")
	check(gs:GetAttribute("SwitchPassSales") == false and gs:GetAttribute("SwitchGoose") == false and gs:GetAttribute("SwitchHalloween") == true, "and publishes them", "")
	table.sort(changes)
	check(table.concat(changes, ",") == "Goose=false,PassSales=false", "Changed fires once per change", table.concat(changes, ","))
	SW.Refresh()
	check(#changes == 2, "no change, no signal", #changes)
	-- a switch that is no longer set goes back to its default
	setDoc(w, base, { Set = { PassSales = false } })
	SW.Refresh()
	check(SW.On("Goose") == true and SW.On("PassSales") == false, "a switch not listed any more is on again", "")
	-- a failed read keeps the last answer
	w.Fail[base .. ":Get"] = 1
	check(SW.Refresh() == false and SW.On("PassSales") == false, "a failed read keeps the last answer", "")
	check(#w.Warnings > 0, "(and says so)", #w.Warnings)
	w.Warnings = {}
	-- a broken document changes the answer to defaults only for the keys it lists (nothing listed: all defaults)
	setDoc(w, base, "garbage")
	SW.Refresh()
	check(SW.On("PassSales") == true, "a garbage document = no switch set = defaults", "")
	-- no document yet
	setDoc(w, base, nil)
	check(SW.Refresh() == true and SW.On("Halloween") == true, "no document = defaults", "")
end)

runGroup("switches: environment and Studio", function()
	local w = opsWorld({ Studio = false, EditConfig = function(c) c.EnvName = function() return "Live" end end })
	local SW = startSwitches(w)
	setDoc(w, "HaloHorns_Switches_v1", { Set = { Goose = false } })
	SW.Refresh()
	check(SW.On("Goose") == true, "a Live server does not read the dev place's document", "")
	setDoc(w, "HaloHorns_Switches_v1_Live", { Set = { Goose = false } })
	SW.Refresh()
	check(SW.On("Goose") == false, "it reads its own '_Live' document", "")
	-- Studio reads only its own copy
	local ws = opsWorld({ Studio = true })
	local SWs = startSwitches(ws)
	setDoc(ws, "HaloHorns_Switches_v1", { Set = { Goose = false } })
	SWs.Refresh()
	check(SWs.On("Goose") == true, "Studio never reads the real switches", "")
	setDoc(ws, "HaloHorns_Switches_v1_STUDIO", { Set = { Goose = false } })
	SWs.Refresh()
	check(SWs.On("Goose") == false, "it reads its own '_STUDIO' copy", "")
end)

runGroup("switches: start and interval", function()
	local w = opsWorld({ Studio = false, EditConfig = function(c) c.Switches.Defs.PassSales.Default = false end })
	local SW = startSwitches(w)
	check(SW.On("PassSales") == false and w.GameState:GetAttribute("SwitchPassSales") == false, "a def whose default is off starts off and says so", tostring(w.GameState:GetAttribute("SwitchPassSales")))
	-- the first read fails: the defaults are still published
	local w3 = opsWorld({ Studio = false, EditConfig = function(c) c.Switches.Defs.PassSales.Default = false end })
	w3.Fail["HaloHorns_Switches_v1:Get"] = 1
	local SW3 = startSwitches(w3)
	check(w3.GameState:GetAttribute("SwitchPassSales") == false and SW3.On("PassSales") == false, "a failed first read still publishes the defaults", tostring(w3.GameState:GetAttribute("SwitchPassSales")))
	w3.Warnings = {}
	local co = w.Loops[#w.Loops]
	local ok, waited = coroutine.resume(co)
	check(ok and waited == 60, "the loop waits Interval (60 s) between reads", tostring(waited))
	local w2 = opsWorld({ Studio = false, EditConfig = function(c) c.Switches.Interval = 1 end })
	startSwitches(w2)
	local ok2, waited2 = coroutine.resume(w2.Loops[#w2.Loops])
	check(ok2 and waited2 == 10, "and never faster than 10 s", tostring(waited2))
end)

runGroup("switches: Halloween", function()
	local w = opsWorld({ Studio = false })
	local SW = startSwitches(w)
	local base = w.Config.StoreName("HaloHorns_Switches_v1")
	local C = w.Config
	local original = C.Halloween.Enabled
	setDoc(w, base, { Set = { Halloween = false } })
	SW.Refresh()
	check(C.Halloween.Enabled == false, "Halloween off: Config.Halloween.Enabled follows", tostring(C.Halloween.Enabled))
	setDoc(w, base, { Set = { Halloween = true } })
	SW.Refresh()
	check(C.Halloween.Enabled == original, "back on: the config's own value again", tostring(C.Halloween.Enabled))
	-- a config that has the season off keeps it off, whatever the switch does
	local w2 = opsWorld({ Studio = false })
	w2.Config.Halloween.Enabled = false
	local SW2 = startSwitches(w2)
	local base2 = w2.Config.StoreName("HaloHorns_Switches_v1")
	setDoc(w2, base2, { Set = { Halloween = false } })
	SW2.Refresh()
	check(w2.Config.Halloween.Enabled == false, "off + a season the config has off: off", tostring(w2.Config.Halloween.Enabled))
	setDoc(w2, base2, { Set = { Halloween = true } })
	SW2.Refresh()
	check(w2.Config.Halloween.Enabled == false and SW2.On("Halloween") == true, "the switch on never turns a season on that the config has off", tostring(w2.Config.Halloween.Enabled))
end)

runGroup("switches: loop", function()
	local w = opsWorld({ Studio = false })
	local SW = startSwitches(w)
	local base = w.Config.StoreName("HaloHorns_Switches_v1")
	setDoc(w, base, { Set = { CrownWar = false } })
	check(SW.On("CrownWar") == true, "(the first read happened at the start, the store was empty then)", "")
	w:Tick(61)
	check(SW.On("CrownWar") == false, "the next read (the loop waits Interval 60 s) applies the change", tostring(SW.On("CrownWar")))
	setDoc(w, base, { Set = {} })
	w:Tick(61)
	check(SW.On("CrownWar") == true, "and the next one undoes it", tostring(SW.On("CrownWar")))
end)

finish()
