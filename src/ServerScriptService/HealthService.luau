-- HealthService.luau : the hourly health report (검수 2026-10-09, system_review_round1 "더할 것 ⑨"; 게임성 개발 3; contract
-- docs/design/health_report_server_2026-10-09.md). A read-only observer like TelemetryService / ServerErrorService: it never
-- changes game state and every handler is pcall'd. It sums what the game does, per UTC hour:
--   Joins, Min[band] (player-minutes per level band), Peak (most ready players on one server), Servers (servers that wrote),
--   XP[band], GoldIn[source] / GoldOut[sink] / GoldBand[band] = { In, Out }, Goose = { Rounds, Versus, Coop, HaloWins, HornsWins,
--   Ties, CoopWins, Empty, Paid, Won, Lost, Rare, Gold, XP }, GooseBand[band] = { N, Gold, XP }, Plunder = { PaidN, PaidG,
--   AvengedN, AvengedG, ReturnedN, ReturnedG }, Pass[id] = { View, Prompt, Bought }.
-- Every Config.Health.FlushSeconds (x0.5..1.5) and when the server closes, the sums not yet saved are MERGED (UpdateAsync, numbers
-- added, Peak = the larger) into ONE DataStore document per UTC hour (Config.StoreName(Config.Health.Store), key "H<YYYYMMDDHH>"), so
-- any number of servers can write the same hour. A failed write puts its sums back for the next flush. The report is read in
-- Studio with DebugCommand("Health") (this server's unsaved sums), ("Health", "stored"[:hours]) (this environment's documents; Studio:
-- its own "_STUDIO" copy) or ("Health", "live"[:hours]) (the real game's, read only): totals, rates per player-hour and ALERT lines.
-- No names, UserIds or free text are ever stored (keys come from the game's own source / sink / pass names, cleaned and capped).
--   HealthService.Merge(old, delta) -> document   (pure; sanitizes both)
--   HealthService.Summarize(rows) / .Alerts(rows, now) / .Text(rows, now, label)   (pure; rows = { { T = hour start, Doc } } oldest first)
--   HealthService.Flush() / .ReadRows(which, hours) / .Debug(value)
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local HealthService = {}

local TAG = "HealthService"
local S = nil
local H = Config.Health or {}
local BUCKETS = {} -- [hour start] = { Delta = { unsaved sums }, Counted = this server was added to the hour's Servers }
local STORE = nil
local MAX_KEYS_DEFAULT = 40
local DEFAULT_BANDS = { { Name = "1-9", Max = 9 }, { Name = "10-24", Max = 24 }, { Name = "25-49", Max = 49 }, { Name = "50+", Max = 1000 } }
local MAXED = { Peak = true } -- document keys that merge as the larger value, not the sum

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function maxKeys()
	return math.max(4, math.floor(num(H.MaxKeys, MAX_KEYS_DEFAULT)))
end

local function bands()
	return type(H.Bands) == "table" and #H.Bands > 0 and H.Bands or DEFAULT_BANDS
end

local function bandOf(level)
	level = math.floor(num(level, 1))
	local list = bands()
	for _, b in list do
		if level <= num(b.Max, 1000) then return b.Name end
	end
	return list[#list].Name
end

-- the keys of a sums table, not counting "Other" (the overflow bucket every table may add on top of MaxKeys)
local function count(t)
	local n = 0
	for k in t do
		if k ~= "Other" then n += 1 end
	end
	return n
end

-- a key of a sums table: letters, digits and _ - + only, 24 long at most ("Other" when nothing is left)
local function cleanKey(k)
	k = string.gsub(tostring(k), "[^%w_%-%+]", "")
	if k == "" then return "Other" end
	return string.sub(k, 1, 24)
end

------------------------------------------------------------------ hours
local function hourOf(t)
	return math.floor(num(t, os.time()) / 3600) * 3600
end

local function hourKey(h)
	return "H" .. os.date("!%Y%m%d%H", h)
end

-- the display time (Korea): "10-09 21:00"
local function kst(t)
	return os.date("!%m-%d %H:%M", t + 9 * 3600)
end

------------------------------------------------------------------ the unsaved sums
local function bucket(t)
	local h = hourOf(t or os.time())
	local b = BUCKETS[h]
	if not b then
		b = { Delta = {}, Counted = false }
		BUCKETS[h] = b
	end
	return b
end

local function sub(t, name)
	local s = t[name]
	if type(s) ~= "table" then
		s = {}
		t[name] = s
	end
	return s
end

-- add n to t[key]. The names come from the game's own code (sources, sinks) or were checked by TelemetryService (pass ids), so the
-- unsaved sums stay small; the cap of Merge (MaxKeys + "Other") is what a saved document keeps.
local function bump(t, key, n)
	key = cleanKey(key)
	t[key] = (t[key] or 0) + n
end

local function levelOf(player)
	if typeof(player) ~= "Instance" then return 1 end
	return num(player:GetAttribute("Level"), 1)
end

local function delta()
	return bucket().Delta
end

------------------------------------------------------------------ recorders (the signal handlers)
function HealthService.OnJoin()
	local d = delta()
	d.Joins = (d.Joins or 0) + 1
end

-- every minute: player-minutes per level band and the most ready players on this server this hour
function HealthService.Minute()
	local ready = S.PlayerService.GetReadyPlayers()
	local d = delta()
	local mins = sub(d, "Min")
	for _, p in ready do
		local band = bandOf(levelOf(p))
		mins[band] = (mins[band] or 0) + 1
	end
	if #ready > 0 then d.Peak = math.max(d.Peak or 0, #ready) end
end

function HealthService.OnGoldIn(player, amount, source)
	amount = math.floor(num(amount))
	if amount <= 0 or type(source) ~= "string" then return end
	local d = delta()
	bump(sub(d, "GoldIn"), source, amount)
	local band = sub(sub(d, "GoldBand"), bandOf(levelOf(player)))
	band.In = (band.In or 0) + amount
end

function HealthService.OnGoldOut(player, amount, sink)
	amount = math.floor(num(amount))
	if amount <= 0 or type(sink) ~= "string" then return end
	local d = delta()
	bump(sub(d, "GoldOut"), sink, amount)
	local band = sub(sub(d, "GoldBand"), bandOf(levelOf(player)))
	band.Out = (band.Out or 0) + amount
end

function HealthService.OnXP(player, amount)
	amount = math.floor(num(amount))
	if amount <= 0 then return end
	local xp = sub(delta(), "XP")
	local band = bandOf(levelOf(player))
	xp[band] = (xp[band] or 0) + amount
end

-- a goose round ended: GooseFinished(result, rewarded, info) (info.Mode = "Versus" | "Coop" | "Pending")
function HealthService.OnGooseFinished(result, _rewarded, info)
	local g = sub(delta(), "Goose")
	g.Rounds = (g.Rounds or 0) + 1
	local mode = type(info) == "table" and info.Mode or "Versus"
	if mode == "Coop" then
		g.Coop = (g.Coop or 0) + 1
		if info.Success == true then g.CoopWins = (g.CoopWins or 0) + 1 end
	elseif mode == "Pending" then
		g.Empty = (g.Empty or 0) + 1
	else
		g.Versus = (g.Versus or 0) + 1
		local key = result == "Halo" and "HaloWins" or result == "Horns" and "HornsWins" or "Ties"
		g[key] = (g[key] or 0) + 1
	end
end

-- one player was paid by the goose: GooseRewarded(player, { Won, Rare, Gold, XP, Level, Mode })
function HealthService.OnGooseRewarded(_player, info)
	if type(info) ~= "table" then return end
	local d = delta()
	local g = sub(d, "Goose")
	local gold, xp = math.max(0, math.floor(num(info.Gold))), math.max(0, math.floor(num(info.XP)))
	g.Paid = (g.Paid or 0) + 1
	local key = info.Won == true and "Won" or "Lost"
	g[key] = (g[key] or 0) + 1
	if info.Rare == true then g.Rare = (g.Rare or 0) + 1 end
	g.Gold = (g.Gold or 0) + gold
	g.XP = (g.XP or 0) + xp
	local b = sub(sub(d, "GooseBand"), bandOf(info.Level))
	b.N = (b.N or 0) + 1
	b.Gold = (b.Gold or 0) + gold
	b.XP = (b.XP or 0) + xp
end

-- a plunder sack ended: SackResolved(thief, outcome, total): "Paid" (the thief kept it) | "Avenged" | "Returned"
local PLUNDER = { Paid = "Paid", Avenged = "Avenged", Returned = "Returned" }
function HealthService.OnSack(_thief, outcome, total)
	local name = type(outcome) == "string" and PLUNDER[outcome] or nil
	if not name then return end
	local p = sub(delta(), "Plunder")
	p[name .. "N"] = (p[name .. "N"] or 0) + 1
	p[name .. "G"] = (p[name .. "G"] or 0) + math.max(0, math.floor(num(total)))
end

-- the shop funnel of a pass: PassView / PurchasePrompt (the client's ClientMetric, TelemetryService's signal) and Bought
function HealthService.OnPass(kind, id)
	if type(id) ~= "string" or (kind ~= "View" and kind ~= "Prompt" and kind ~= "Bought") then return end
	local passes = sub(delta(), "Pass")
	local row = sub(passes, cleanKey(id))
	row[kind] = (row[kind] or 0) + 1
end

function HealthService.OnClientMetric(_player, id, arg)
	if id == "PassView" then
		HealthService.OnPass("View", arg)
	elseif id == "PurchasePrompt" then
		HealthService.OnPass("Prompt", arg)
	end
end

------------------------------------------------------------------ the document
-- sums src into dst (numbers added, MAXED keys take the larger); keys are cleaned, values finite and under 1e12 (a broken
-- document is repaired, never trusted), sums tables hold at most MaxKeys keys (more: "Other"), three levels deep at most
local function sumInto(dst, src, depth)
	for k, v in src do
		if type(k) == "string" then
			local key = cleanKey(k)
			if depth > 1 and dst[key] == nil and count(dst) >= maxKeys() then key = "Other" end
			if type(v) == "number" then
				if v == v and v > -1e12 and v < 1e12 then
					if MAXED[key] then
						dst[key] = math.max(num(dst[key]), v)
					else
						dst[key] = num(dst[key]) + v
					end
				end
			elseif type(v) == "table" and depth < 3 then
				if type(dst[key]) ~= "table" then dst[key] = {} end
				sumInto(dst[key], v, depth + 1)
			end
		end
	end
end

function HealthService.Merge(old, new)
	local out = {}
	if type(old) == "table" then sumInto(out, old, 1) end
	if type(new) == "table" then sumInto(out, new, 1) end
	out.V = 1
	return out
end

local function store()
	if STORE == nil then
		local base = H.Store or "HaloHorns_Health_v1"
		local name = Config.StoreName and Config.StoreName(base) or base
		if RunService:IsStudio() then name ..= "_STUDIO" end
		local ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)
		STORE = ok and st or false
	end
	return STORE or nil
end

-- writes every hour with unsaved sums. Returns true when all of them were saved.
function HealthService.Flush()
	local st = store()
	if not st then return false end
	local hours = {}
	for h, b in BUCKETS do
		if next(b.Delta) ~= nil then table.insert(hours, h) end
	end
	table.sort(hours)
	local allOk = true
	for _, h in hours do
		local b = BUCKETS[h]
		local mine = b.Delta
		b.Delta = {} -- what is added while the write waits goes to the next flush
		if not b.Counted then mine.Servers = 1 end
		local ok, err = pcall(st.UpdateAsync, st, hourKey(h), function(old)
			return HealthService.Merge(old, mine)
		end)
		if ok then
			b.Counted = true
		else
			allOk = false
			Util.Warn(TAG, "save " .. hourKey(h) .. ": " .. tostring(err))
			local back = {}
			sumInto(back, mine, 1)
			sumInto(back, b.Delta, 1)
			back.V = nil
			b.Delta = back
		end
	end
	-- hours long gone with nothing unsaved leave the memory
	local now = hourOf(os.time())
	for h, b in BUCKETS do
		if h < now - 3600 and next(b.Delta) == nil then BUCKETS[h] = nil end
	end
	return allOk
end

------------------------------------------------------------------ the report (pure)
-- rows = { { T = hour start, Doc = a document } } oldest first. Returns the sums of all of them.
function HealthService.Summarize(rows)
	local total = {}
	local servers = 0
	for _, r in rows do
		if type(r) == "table" and type(r.Doc) == "table" then
			sumInto(total, r.Doc, 1)
			servers += num(r.Doc.Servers)
		end
	end
	total.V = nil
	total.Hours = #rows
	total.ServerHours = servers
	return total
end

-- text helpers: I = an exact count with thousands separators, fmt = a rate (1.2K)
local function I(n)
	return Util.FormatInt(num(n))
end

local function fmt(n)
	return Util.FormatNumber(math.floor(num(n) + 0.5))
end

local function ratePerHour(value, minutes)
	if minutes <= 0 then return nil end
	return value / (minutes / 60)
end

-- the alert lines (starter numbers: Config.Health.Alerts); `now` = os.time()
function HealthService.Alerts(rows, now)
	local A = H.Alerts or {}
	local out = {}
	now = num(now, os.time())
	local minMin, ratio, need = num(A.MinPlayerMinutes, 60), num(A.SurgeRatio, 2), math.max(1, math.floor(num(A.MinBaseline, 3)))
	-- quiet: nothing written for QuietHours (only when the window has any data at all)
	local newest = rows[#rows]
	if newest and now - (newest.T + 3600) >= num(A.QuietHours, 3) * 3600 then
		table.insert(out, string.format("QUIET: no server wrote data since %s KST (%s h)", kst(newest.T), I((now - newest.T) / 3600)))
	end
	-- surges: the newest full hour per player-minute vs the earlier full hours (per band, only hours with enough player-minutes)
	local full = {}
	for _, r in rows do
		if r.T + 3600 <= now then table.insert(full, r) end
	end
	for _, band in bands() do
		local name = band.Name
		for _, what in { "XP", "Gold in" } do
			local function pair(doc)
				local mins = type(doc.Min) == "table" and num(doc.Min[name]) or 0
				local v
				if what == "XP" then
					v = type(doc.XP) == "table" and num(doc.XP[name]) or 0
				else
					local gb = type(doc.GoldBand) == "table" and doc.GoldBand[name]
					v = type(gb) == "table" and num(gb.In) or 0
				end
				return v, mins
			end
			local lastIdx
			for i = #full, 1, -1 do
				local _, mins = pair(full[i].Doc)
				if mins >= minMin then
					lastIdx = i
					break
				end
			end
			if lastIdx then
				local v, mins = pair(full[lastIdx].Doc)
				local baseV, baseM, baseHours = 0, 0, 0
				for i = 1, lastIdx - 1 do
					local bv, bm = pair(full[i].Doc)
					if bm >= minMin then
						baseV += bv
						baseM += bm
						baseHours += 1
					end
				end
				local now1, base1 = ratePerHour(v, mins), ratePerHour(baseV, baseM)
				if baseHours >= need and base1 and base1 > 0 and now1 and now1 >= ratio * base1 then
					table.insert(out, string.format("SURGE: %s per player-hour in %s is %.1fx the earlier hours (%s vs %s) at %s KST",
						what, name, now1 / base1, Util.FormatNumber(now1), Util.FormatNumber(base1), kst(full[lastIdx].T)))
				end
			end
		end
	end
	-- the goose: one side wins nearly every decided round
	local total = HealthService.Summarize(rows)
	local g = type(total.Goose) == "table" and total.Goose or {}
	local halo, horns = num(g.HaloWins), num(g.HornsWins)
	if halo + horns >= num(A.GooseMinRounds, 10) then
		local top = math.max(halo, horns)
		if top / (halo + horns) >= num(A.GooseSkew, 0.75) then
			table.insert(out, string.format("GOOSE: %s won %s of %s decided rounds", halo > horns and "Halo" or "Horns", I(top), I(halo + horns)))
		end
	end
	return out
end

-- "a 1.2K, b 900" for a sums table, biggest first (at most `top`)
local function topList(t, top)
	local list = {}
	for k, v in type(t) == "table" and t or {} do
		if type(v) == "number" then table.insert(list, { k, v }) end
	end
	table.sort(list, function(a, b)
		if a[2] ~= b[2] then return a[2] > b[2] end
		return a[1] < b[1]
	end)
	local out = {}
	for i = 1, math.min(#list, top or 6) do table.insert(out, list[i][1] .. " " .. fmt(list[i][2])) end
	return table.concat(out, ", ")
end

local function sumOf(t)
	local n = 0
	for _, v in type(t) == "table" and t or {} do n += num(v) end
	return n
end

local function perBand(label, byBand, mins, unit)
	local parts = {}
	for _, b in bands() do
		local m = type(mins) == "table" and num(mins[b.Name]) or 0
		local v = type(byBand) == "table" and byBand[b.Name] or 0
		if type(v) == "table" then v = num(v.In) end
		if m > 0 then
			table.insert(parts, string.format("%s %s", b.Name, fmt(v / (m / 60))))
		end
	end
	return #parts > 0 and (label .. " per player-hour: " .. table.concat(parts, " | ") .. (unit or "")) or nil
end

function HealthService.Text(rows, now, label)
	now = num(now, os.time())
	local lines = {}
	if #rows == 0 then
		return string.format("Health (%s): no data in this window", label or "?")
	end
	local t = HealthService.Summarize(rows)
	table.insert(lines, string.format("Health (%s): %s hours with data (%s .. %s KST), %s server-hours, %s joins, up to %s ready on one server",
		label or "?", I(t.Hours), kst(rows[1].T), kst(rows[#rows].T), I(t.ServerHours), I(t.Joins), I(t.Peak)))
	local mins = type(t.Min) == "table" and t.Min or {}
	local hoursParts = {}
	for _, b in bands() do
		if num(mins[b.Name]) > 0 then table.insert(hoursParts, string.format("%s %.1f", b.Name, num(mins[b.Name]) / 60)) end
	end
	table.insert(lines, "Player-hours: " .. (#hoursParts > 0 and table.concat(hoursParts, " | ") or "none"))
	local xpLine = perBand("XP", t.XP, mins)
	if xpLine then table.insert(lines, xpLine) end
	local goldIn, goldOut = sumOf(t.GoldIn), sumOf(t.GoldOut)
	table.insert(lines, string.format("Gold in %s (%s) / out %s (%s) / net %s%s", fmt(goldIn), topList(t.GoldIn, 6), fmt(goldOut),
		topList(t.GoldOut, 6), goldIn - goldOut >= 0 and "+" or "-", fmt(math.abs(goldIn - goldOut))))
	local inLine = perBand("Gold in", t.GoldBand, mins)
	if inLine then table.insert(lines, inLine) end
	local g = type(t.Goose) == "table" and t.Goose or {}
	if num(g.Rounds) > 0 or num(g.Paid) > 0 then
		table.insert(lines, string.format("Goose: %s rounds (versus %s: Halo %s, Horns %s, ties %s; coop %s, won %s; nobody paid %s); paid %s: won %s, not won %s, rare %s; per paid player %s gold, %s XP",
			I(g.Rounds), I(g.Versus), I(g.HaloWins), I(g.HornsWins), I(g.Ties), I(g.Coop), I(g.CoopWins), I(g.Empty),
			I(g.Paid), I(g.Won), I(g.Lost), I(g.Rare), num(g.Paid) > 0 and fmt(num(g.Gold) / num(g.Paid)) or "-",
			num(g.Paid) > 0 and fmt(num(g.XP) / num(g.Paid)) or "-"))
		local gb = type(t.GooseBand) == "table" and t.GooseBand or {}
		local parts = {}
		for _, b in bands() do
			local row = gb[b.Name]
			if type(row) == "table" and num(row.N) > 0 then
				table.insert(parts, string.format("%s %s paid, %s gold, %s XP", b.Name, I(row.N), fmt(num(row.Gold) / num(row.N)), fmt(num(row.XP) / num(row.N))))
			end
		end
		if #parts > 0 then table.insert(lines, "Goose pay per player by level band: " .. table.concat(parts, " | ")) end
	end
	local p = type(t.Plunder) == "table" and t.Plunder or {}
	if num(p.PaidN) + num(p.AvengedN) + num(p.ReturnedN) > 0 then
		local function part(name, n, gold)
			return string.format("%s %s (avg %s gold)", name, I(n), num(n) > 0 and fmt(num(gold) / num(n)) or "-")
		end
		table.insert(lines, "Plunder sacks: " .. part("kept", p.PaidN, p.PaidG) .. ", " .. part("avenged", p.AvengedN, p.AvengedG) .. ", "
			.. part("returned", p.ReturnedN, p.ReturnedG))
	end
	local passes = {}
	for id, row in type(t.Pass) == "table" and t.Pass or {} do
		if type(row) == "table" then
			table.insert(passes, string.format("%s view %s / prompt %s / bought %s", id, I(row.View), I(row.Prompt), I(row.Bought)))
		end
	end
	table.sort(passes)
	if #passes > 0 then table.insert(lines, "Passes: " .. table.concat(passes, "; ")) end
	local alerts = HealthService.Alerts(rows, now)
	if #alerts == 0 then
		table.insert(lines, "Alerts: none")
	else
		table.insert(lines, "Alerts:")
		for _, a in alerts do table.insert(lines, "  - " .. a) end
	end
	return table.concat(lines, "\n")
end

------------------------------------------------------------------ reading (Studio)
-- the documents of the last `hours` hours (oldest first) of "stored" (this environment's; Studio: its own copy) or "live"
-- (the real game's, read only). Returns rows, error text (the rows read before a failed read are returned too).
function HealthService.ReadRows(which, hours)
	hours = math.clamp(math.floor(num(hours, num(H.ReadHours, 24))), 1, math.max(1, math.floor(num(H.MaxReadHours, 72))))
	local base = H.Store or "HaloHorns_Health_v1"
	local name = Config.StoreName and Config.StoreName(base) or base
	if which ~= "live" and RunService:IsStudio() then name ..= "_STUDIO" end
	local okStore, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)
	if not okStore then return {}, tostring(st) end
	local rows = {}
	local current = hourOf(os.time())
	for i = hours - 1, 0, -1 do
		local h = current - i * 3600
		local ok, doc = pcall(st.GetAsync, st, hourKey(h))
		if not ok then return rows, tostring(doc) end
		if type(doc) == "table" then table.insert(rows, { T = h, Doc = HealthService.Merge(doc, nil) }) end
	end
	return rows, nil
end

-- this server's unsaved sums, as rows
function HealthService.Pending()
	local rows = {}
	local hours = {}
	for h in BUCKETS do table.insert(hours, h) end
	table.sort(hours)
	for _, h in hours do
		local b = BUCKETS[h]
		if next(b.Delta) ~= nil then table.insert(rows, { T = h, Doc = HealthService.Merge(nil, b.Delta) }) end
	end
	return rows
end

-- DebugCommand("Health"[, value]): nil = this server's unsaved sums, "stored" / "live" (optionally ":hours")
function HealthService.Debug(value)
	local which, hours = nil, nil
	if type(value) == "string" then
		which, hours = string.match(value, "^(%a+):?(%d*)$")
		hours = tonumber(hours)
	end
	if which == "stored" or which == "live" then
		local rows, err = HealthService.ReadRows(which, hours)
		local text = HealthService.Text(rows, os.time(), which)
		if err then text ..= "\n(read stopped: " .. err .. ")" end
		return text
	end
	return HealthService.Text(HealthService.Pending(), os.time(), "this server, not saved yet")
end

------------------------------------------------------------------ start
local function connect(service, signal, fn)
	local svc = S[service]
	local sig = svc and svc[signal]
	if type(sig) == "table" and type(sig.Connect) == "function" then
		sig:Connect(function(...)
			local ok, err = pcall(fn, ...)
			if not ok then Util.Warn(TAG, service .. "." .. signal .. ": " .. tostring(err)) end
		end)
	end
end

function HealthService.Init(registry)
	S = registry
end

function HealthService.Start()
	if H.Enabled == false then return end
	connect("PlayerService", "PlayerReady", HealthService.OnJoin)
	connect("ProgressionService", "GoldEarned", HealthService.OnGoldIn)
	connect("ProgressionService", "GoldSpent", HealthService.OnGoldOut)
	connect("ProgressionService", "XPEarned", HealthService.OnXP)
	connect("GooseService", "GooseFinished", HealthService.OnGooseFinished)
	connect("GooseService", "GooseRewarded", HealthService.OnGooseRewarded)
	connect("GrudgeService", "SackResolved", HealthService.OnSack)
	connect("TelemetryService", "ClientMetric", HealthService.OnClientMetric)
	connect("MonetizationService", "PassBought", function(_player, kind) HealthService.OnPass("Bought", kind) end)
	task.spawn(function()
		while true do
			task.wait(60)
			local ok, err = pcall(HealthService.Minute)
			if not ok then Util.Warn(TAG, "minute: " .. tostring(err)) end
		end
	end)
	task.spawn(function()
		local every = math.max(30, num(H.FlushSeconds, 600))
		while true do
			task.wait(every * (0.5 + Util.Random:NextNumber())) -- servers do not all write in the same second
			pcall(HealthService.Flush)
		end
	end)
	game:BindToClose(function()
		pcall(HealthService.Flush)
	end)
	print("[HealthService] started")
end

return HealthService
