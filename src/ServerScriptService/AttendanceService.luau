-- AttendanceService.luau : SPEC A23-77 출석 = 모은 날 수 (게임성 개발 3, 2026-10-08; contract
-- docs/design/attendance_server_2026-10-08.md). One claim a KST day (Config.DayIndex): the next slot of the 7-slot board
-- (Config.Attendance.Board). A missed day is just skipped - no streak, nothing ever resets (user: "끊기면 0되면 안 돼").
-- Days collected (lifetime) open Config.Attendance.Milestones once (stat-free titles, the name frame) and the
-- attendance-only looks (Config.Looks with Unlock.Attendance, A23-75's frame, through MonetizationService.GrantLook).
-- Gold and XP go through ProgressionService with the source "Attendance" (A23-75's 2x passes apply there).
-- Save: data.Attendance = { Days, LastDay, Slot } (Config.Data.Defaults; repaired here at PlayerReady and at a claim).
-- Remote c->s "ClaimAttendance"() (no arguments; ready, class chosen, Config.RateLimits.ClaimAttendance).
-- Owner attributes: AttendDays (days collected), AttendSlot (the slot the next claim pays, 1..7), AttendReady (true = a
-- claim is open now). Fx "Attendance" { Slot, Days, Gold, XP, Items = { { Id, N } }, Box } to the owner after a claim
-- (the board's stamp; Gold / XP = what was really added). Signal AttendanceService.Claimed(player, slot, days).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local AttendanceService = {}
AttendanceService.Claimed = Util.Signal.new() -- (player, slot, days collected)

local TAG = "AttendanceService"
local S = nil
local A = Config.Attendance or {}
local TXT = A.Text or {}
local SLOTS = #(A.Board or {})
local CONNS = {} -- [Player] = { RBXScriptConnection }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function today()
	return Config.DayIndex(os.time())
end

-- data.Attendance repaired in place: Days / LastDay whole numbers >= 0, Slot 1..#Board. A LastDay more than a day ahead
-- of today is a broken value (it would block every claim), so it starts over at 0; Days is never lowered
local function record(data)
	local a = data.Attendance
	if type(a) ~= "table" then
		a = {}
		data.Attendance = a
	end
	a.Days = math.max(0, math.floor(num(a.Days)))
	a.LastDay = math.max(0, math.floor(num(a.LastDay)))
	if a.LastDay > today() + 1 then a.LastDay = 0 end
	local slot = math.floor(num(a.Slot, 1))
	if slot < 1 or slot > SLOTS then slot = 1 end
	a.Slot = slot
	return a
end

local function canClaim(data, a, day)
	return A.Enabled ~= false and SLOTS > 0 and data.ClassChosen == true and a.LastDay < day
end

local function publish(player, data)
	local a = record(data)
	player:SetAttribute("AttendDays", a.Days)
	player:SetAttribute("AttendSlot", a.Slot)
	player:SetAttribute("AttendReady", canClaim(data, a, today()))
end

local function notify(player, text, kind, sound)
	local ok, err = pcall(Net.Notify, player, text, kind or "reward", nil, sound)
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

------------------------------------------------------------------ rewards
-- the materials `minutes` of hunting the level zone's main monster drop on average (Config.Loot.Tables rows of a
-- Material item: KillsPerMinute x minutes x P x N, rounded)
local function materialsFor(level, minutes)
	local zone = Config.QuestZoneForLevel(level)
	local kind = Config.ZoneMainMonster[zone]
	local rows = kind and Config.Loot.Tables[kind]
	local out = {}
	for _, row in type(rows) == "table" and rows or {} do
		local def = type(row.Item) == "string" and Config.Loot.Items[row.Item] or nil
		if def and def.Kind == "Material" then
			local n = math.floor(Config.Economy.KillsPerMinute * minutes * num(row.P) * num(row.N, 1) + 0.5)
			if n > 0 then table.insert(out, { Id = row.Item, N = n }) end
		end
	end
	return out
end

local function itemName(id)
	local def = Config.Loot.Items[id]
	if def then return def.Name end
	return (Config.Loot.Text and Config.Loot.Text.Potion and Config.Loot.Text.Potion[id]) or id
end

-- gold through ProgressionService (A23-75: the 2x pass may double it; the amount really added comes back)
local function addGold(player, amount)
	amount = math.floor(num(amount))
	if amount <= 0 then return 0 end
	local got = S.ProgressionService.AddBankGold(player, amount, "Attendance")
	return math.floor(num(got, amount))
end

local function addXP(player, amount)
	amount = math.floor(num(amount))
	if amount <= 0 then return 0 end
	local got = S.ProgressionService.AddXP(player, amount)
	return math.floor(num(got, amount))
end

-- one item / potion grant through LootService (its caps and full notices); returns how many were given
local function giveItem(player, id, n)
	local loot = S.LootService
	if type(loot) ~= "table" or type(loot.GrantItem) ~= "function" then return 0 end
	local ok, given = pcall(loot.GrantItem, player, id, n)
	if not ok then
		Util.Warn(TAG, "GrantItem " .. tostring(id) .. ": " .. tostring(given))
		return 0
	end
	return math.clamp(math.floor(num(given)), 0, n)
end

-- pays one board slot; returns the reward summary (what was really given)
local function pay(player, data, def)
	local level = math.clamp(math.floor(num(data.Level, 1)), 1, Config.Levels.MaxLevel)
	local out = { Gold = 0, XP = 0, Items = {} }
	local gold, xp = 0, 0
	if num(def.GoldMin) > 0 then gold = (Config.HuntValue(level, def.GoldMin)) end
	if num(def.XPMin) > 0 then
		local _, x = Config.HuntValue(level, def.XPMin)
		xp = x
	end
	local function item(id, n)
		n = math.floor(num(n, 1))
		if type(id) ~= "string" or n < 1 then return end
		local given = giveItem(player, id, n)
		if given > 0 then table.insert(out.Items, { Id = id, N = given }) end
		-- bottles that did not fit the bag are paid at the potion price instead (nothing of a claim is lost)
		local price = Config.Vitals.PotionPrices and Config.Vitals.PotionPrices[id]
		if given < n and price then gold += (n - given) * num(price) end
	end
	if def.Potion then item(def.Potion, def.N) end
	if def.Item then item(def.Item, def.N) end
	if num(def.MaterialMin) > 0 then
		for _, m in materialsFor(level, def.MaterialMin) do item(m.Id, m.N) end
	end
	out.Gold = addGold(player, gold)
	out.XP = addXP(player, xp)
	return out
end

local function partsText(out)
	local parts = {}
	if out.Gold > 0 then table.insert(parts, string.format(TXT.Gold or "+%s gold", Util.FormatNumber(out.Gold))) end
	if out.XP > 0 then table.insert(parts, string.format(TXT.XP or "+%s XP", Util.FormatNumber(out.XP))) end
	for _, it in out.Items do
		if it.N > 1 then
			table.insert(parts, string.format(TXT.ItemN or "+%s x%d", itemName(it.Id), it.N))
		else
			table.insert(parts, string.format(TXT.Item or "+%s", itemName(it.Id)))
		end
	end
	return table.concat(parts, " · ")
end

------------------------------------------------------------------ milestones
-- every attendance look (Config.Looks with Unlock.Attendance <= days), both factions; returns the new ones
local function grantLooks(player, days)
	local new = {}
	local mon = S.MonetizationService
	if type(Config.Looks) ~= "table" or type(mon) ~= "table" or type(mon.GrantLook) ~= "function" then return new end
	for id, look in Config.Looks do
		local need = type(look) == "table" and type(look.Unlock) == "table" and num(look.Unlock.Attendance) or 0
		if need > 0 and need <= days then
			local ok, res = pcall(mon.GrantLook, player, id)
			if not ok then Util.Warn(TAG, "GrantLook " .. tostring(id) .. ": " .. tostring(res)) end
			if ok and res == true then table.insert(new, id) end
		end
	end
	table.sort(new)
	return new
end

local function grantTitle(player, id)
	local titles = S.TitleService
	if type(id) ~= "string" or not Config.TitleDefs[id] or type(titles) ~= "table" or type(titles.Grant) ~= "function" then
		return false
	end
	local ok, res = pcall(titles.Grant, player, id)
	if not ok then Util.Warn(TAG, "title " .. id .. ": " .. tostring(res)) end
	return ok and res == true
end

-- every milestone up to `days` (titles once; TitleService / GrantLook ignore what is owned). loud = the claim that just
-- reached `days`: one line for the milestone of exactly that day, one for each new title / look / frame
-- A23-130: a milestone day's fanfare (RankUp) rides on its first reward line (frame / title / my side's look); only a day
-- with none of them for me (게임성 검수 10/12: the artisan guild at 14 days gets no Halo / Horns look) says "N days collected!"
local function milestones(player, days, loud)
	local lines, hit = {}, false
	for _, m in A.Milestones or {} do
		local at = math.floor(num(m.Days))
		if at > 0 and at <= days then
			local newTitle = m.Title and grantTitle(player, m.Title)
			if loud and at == days then
				hit = true
				if m.Border then table.insert(lines, TXT.NewBorder or "New name frame!") end
			end
			if loud and newTitle then
				table.insert(lines, string.format(TXT.NewTitle or "New title: %s!", Config.TitleDefs[m.Title].Name))
			end
		end
	end
	local faction = player:GetAttribute("Faction")
	for _, id in grantLooks(player, days) do
		local look = Config.Looks[id]
		if loud and look.Faction == faction then
			table.insert(lines, string.format(TXT.NewLook or "New look: %s!", tostring(look.Name or id)))
		end
	end
	if hit then
		notify(player, table.remove(lines, 1) or string.format(TXT.Days or "%d days collected!", days), "reward", "RankUp")
	end
	for _, line in lines do notify(player, line, "reward", "None") end
end

------------------------------------------------------------------ claim
local function onClaim(player, ...)
	if select("#", ...) ~= 0 then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "ClaimAttendance", num(Config.RateLimits.ClaimAttendance, 1)) then return end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	local a = record(data)
	local day = today()
	if not canClaim(data, a, day) then
		publish(player, data)
		return
	end
	local slot = a.Slot
	local def = A.Board[slot]
	-- committed before anything is paid: one claim can never pay twice, whatever fails below
	a.LastDay = day
	a.Days += 1
	a.Slot = slot % SLOTS + 1
	local days = a.Days
	publish(player, data)
	local ok, out = pcall(pay, player, data, def)
	if not ok then
		Util.Warn(TAG, "pay: " .. tostring(out))
		out = { Gold = 0, XP = 0, Items = {} }
	end
	local parts = partsText(out)
	notify(player, string.format(TXT.Claimed or "Day %d reward! %s", slot, parts), "reward", "QuestDone")
	local okFx, errFx = pcall(Net.Fx, player, "Attendance", { Slot = slot, Days = days, Gold = out.Gold, XP = out.XP,
		Items = out.Items, Box = def.Box == true })
	if not okFx then Util.Warn(TAG, "fx: " .. tostring(errFx)) end
	local okM, errM = pcall(milestones, player, days, true)
	if not okM then Util.Warn(TAG, "milestones: " .. tostring(errM)) end
	AttendanceService.Claimed:Fire(player, slot, days)
end

------------------------------------------------------------------ join / leave
local function onReady(player, data)
	if type(data) ~= "table" then data = S.PlayerService.GetData(player) end
	if type(data) ~= "table" then return end
	local a = record(data)
	milestones(player, a.Days, false) -- catch up (e.g. a look added after the day was reached), silently
	publish(player, data)
	for _, c in CONNS[player] or {} do c:Disconnect() end
	CONNS[player] = {
		player:GetAttributeChangedSignal("ClassChosen"):Connect(function()
			local d = S.PlayerService.GetData(player)
			if type(d) == "table" then pcall(publish, player, d) end
		end),
	}
end

-- the open claim of every online player turns on at 00:00 KST
local function dayTick()
	for _, p in S.PlayerService.GetReadyPlayers() do
		local data = S.PlayerService.GetData(p)
		if type(data) == "table" and p.Parent ~= nil then publish(p, data) end
	end
end

function AttendanceService.Init(registry)
	S = registry
end

function AttendanceService.Start()
	Net.Get("ClaimAttendance").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onClaim, player, ...)
		if not ok then Util.Warn(TAG, "ClaimAttendance: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		local ok, err = pcall(onReady, player, data)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		for _, c in CONNS[player] or {} do c:Disconnect() end
		CONNS[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(num(A.CheckInterval, 30))
			local ok, err = pcall(dayTick)
			if not ok then Util.Warn(TAG, "day: " .. tostring(err)) end
		end
	end)
	print("[AttendanceService] started")
end

-- Studio test aid (Main DebugCommand "AttendNext"): today's claim opens again (the last claim moves to yesterday)
function AttendanceService.DebugNextDay(player)
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return "no data" end
	local a = record(data)
	a.LastDay = math.max(0, today() - 1)
	publish(player, data)
	return "ok"
end

return AttendanceService
