-- StatService.luau : A23-69 stat points, stage 2 (docs/design/stat_points_2026-10-07.md §2, §3, §5-2, §6).
-- While Config.Features.StatPoints is OFF it does nothing (no attributes, the remote is refused): every number in the
-- game stays as today. On:
--   - the flat attributes StatAtk / StatHp / StatFree / AutoStat follow the save (data.Stats = { Auto, Order }), the
--     level and the class (Config.StatAlloc): at the data load (PlayerReady), LeveledUp (Auto places the new points
--     itself), LevelReset, Rebirthed, ClassChanged and after every action;
--   - remote StatAction(op, arg): "add" "A"|"H" (one point), "add5" "A"|"H" (min(5, free) points), "reset" (Order = "",
--     at most once every Stats.ResetCooldown s), "auto" true|false. add / add5 / reset need Auto OFF. Turning Auto off
--     copies the letters Auto placed into Order (no number moves); turning it on clears Order (the client confirms first).
--     Every action is refused in PvP combat (the tag), as a kaiju or carrying the grudge sack (the class change's words,
--     §2-4), silently when dead or not ready; a level-up's own placement is never blocked. The client never sends numbers;
--   - after a change: attributes -> PlayerService.RefreshCharacter(player, false) (keeps the HP ratio: no free heal) ->
--     JusticeService re-reads the CombatPower attribute (it watches StatAtk / StatHp) -> a "Power X -> Y" notice;
--   - the lines of §6 (after the first [Claim] only): the first point once (data.Story.First.StatPoint), each level-up
--     (Auto: what it placed and the power change; by hand: the new points), the first time Auto is turned off
--     (data.Story.First.StatManual); Fx "Stat" { Kind, From, To, A, H, Free, Auto } lets the HUD glow the power chip.
-- No stat, point or reset is ever sold (A23-69): MonetizationService has no path here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local StatService = {}
local S = nil
local TAG = "StatService"
local ST = Config.Stats or {}
local TXT = ST.Text or {}
local OPS = { add = true, add5 = true, reset = true, auto = true }
-- [Player] = { Level, A, H } last published (the level-up line's "before"), ResetAt = os.clock() of the last reset
local seen = setmetatable({}, { __mode = "k" })

local function on()
	return Config.FeatureOn("StatPoints")
end

local function isPlayer(x)
	return typeof(x) == "Instance" and x:IsA("Player")
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function classOf(player)
	local ok, c = pcall(S.ClassService.GetClass, player)
	return ok and type(c) == "string" and c or "Warrior"
end

local function levelOf(data)
	local lv = tonumber(data.Level) or 1
	if lv ~= lv then lv = 1 end
	return math.max(1, math.floor(lv))
end

local function statsOf(data)
	if type(data.Stats) ~= "table" then data.Stats = Config.SanitizeStats(nil) end
	return data.Stats
end

-- sound: nil = by kind (a refusal "bad" -> Deny); the stat lines are quiet ("None": the level-up Fx has its own sound)
local function notify(player, text, kind, sound)
	if type(text) ~= "string" then return end
	local ok, err = pcall(Net.Notify, player, text, kind or "info", nil, sound)
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

local function fx(player, data)
	local ok, err = pcall(Net.Fx, player, "Stat", data)
	if not ok then Util.Warn(TAG, "fx: " .. tostring(err)) end
end

-- the §6 lines only after the first [Claim] (A23-68 #4: one goal at a time before it)
local function talks(data)
	return tonumber(data.TutorialStep) == (Config.Tutorial.Steps or {}).Done
end

-- the attributes from the save; returns (A, H, free, changed: A or H moved)
local function publish(player, data)
	local a, h, free = Config.StatAlloc(statsOf(data), levelOf(data), classOf(player))
	local before = seen[player]
	local changed = before == nil or before.A ~= a or before.H ~= h
	seen[player] = { Level = levelOf(data), A = a, H = h, ResetAt = before and before.ResetAt or nil }
	player:SetAttribute("StatAtk", a)
	player:SetAttribute("StatHp", h)
	player:SetAttribute("StatFree", free)
	player:SetAttribute("AutoStat", statsOf(data).Auto ~= false)
	return a, h, free, changed
end

-- re-read after a change that moved A or H: the max HP keeps its ratio (never a full heal, §2-4)
local function refresh(player, data)
	local a, h, free, changed = publish(player, data)
	if changed then
		local ok, err = pcall(S.PlayerService.RefreshCharacter, player, false)
		if not ok then Util.Warn(TAG, "refresh: " .. tostring(err)) end
	end
	return a, h, free, changed
end

local function power(player)
	return Config.CombatPowerOf(player)
end

-- the save's Stats replaced (SetStat: the one write path of a save field)
local function saveStats(player, auto, order)
	S.PlayerService.SetStat(player, "Stats", Config.SanitizeStats({ Auto = auto, Order = order }))
end

-- §2-4: the actions wait while the player is in PvP combat, a kaiju or carrying the grudge sack
local function blockedWhy(player)
	local cs = S.CombatService
	if cs and type(cs.IsInCombat) == "function" and cs.IsInCombat(player) then return "TravelBlockedCombat" end
	local ks = S.KaijuService
	if ks and type(ks.GetState) == "function" then
		local ok, st = pcall(ks.GetState, player)
		if ok and type(st) == "string" and st ~= "None" then return "BlockedKaiju" end
	end
	local gs = S.GrudgeService
	if gs and type(gs.HasSack) == "function" then
		local ok, has = pcall(gs.HasSack, player)
		if ok and has == true then return "BlockedSack" end
	end
	return nil
end

-- the first letters of Order the points reach (StatAlloc's window): a new pick goes after them, or replaces the first
-- letter there that is not a beta stat (a later stage's letter keeps its point free until that stage)
local function placeLetter(order, points, letter)
	if #order < points then return order .. letter end
	for i = 1, math.min(#order, points) do
		local ch = string.sub(order, i, i)
		if not (ST.Letters or {})[ch] then return string.sub(order, 1, i - 1) .. letter .. string.sub(order, i + 1) end
	end
	return nil
end

------------------------------------------------------------------ the remote
local function onAction(player, op, arg, ...)
	if select("#", ...) ~= 0 or not isPlayer(player) or not on() then return end
	if type(op) ~= "string" or not OPS[op] then return end
	if (op == "add" or op == "add5") and (type(arg) ~= "string" or not (ST.Letters or {})[arg]) then return end
	if op == "auto" and type(arg) ~= "boolean" then return end
	if op == "reset" and arg ~= nil then return end
	if not S.PlayerService.IsReady(player) or player:GetAttribute("ClassChosen") ~= true then return end
	if not Util.RateLimit(player, "StatAction", Config.RateLimits.StatAction or 0.15) then return end
	if not Util.IsAlive(player) then return end -- silent
	local why = blockedWhy(player)
	if why then
		notify(player, Config.Text[why], "bad")
		return
	end
	local data = getData(player)
	if not data then return end
	local stats = statsOf(data)
	local level, class = levelOf(data), classOf(player)
	local points = Config.StatPoints(level)
	local before = power(player)
	local first = false
	if op == "auto" then
		if (stats.Auto ~= false) == arg then return end
		if arg then
			saveStats(player, true, "") -- back to the class pattern
		else
			-- the letters Auto placed become the picks: not one number moves
			local pattern = ST.AutoPattern[class] or ST.AutoPattern.Warrior
			saveStats(player, false, string.sub(string.rep(pattern, math.ceil(points / #pattern)), 1, points))
			local firsts = type(data.Story) == "table" and type(data.Story.First) == "table" and data.Story.First or nil
			if firsts and firsts.StatManual ~= true then
				firsts.StatManual = true
				first = true
			end
		end
	else
		if stats.Auto ~= false then return end -- the client asks "Turn off Auto to pick yourself?" first
		local order = type(stats.Order) == "string" and stats.Order or ""
		if op == "reset" then
			local s = seen[player]
			local now = os.clock()
			if s and s.ResetAt and now - s.ResetAt < (ST.ResetCooldown or 3) then return end
			if order == "" then return end
			if s then s.ResetAt = now end
			order = ""
		else
			local _, _, free = Config.StatAlloc(stats, level, class)
			local n = op == "add5" and math.min(5, free) or math.min(1, free)
			if n < 1 then return end
			for _ = 1, n do
				order = placeLetter(order, points, arg)
				if not order then return end
			end
		end
		saveStats(player, false, order)
	end
	local a, h, free = refresh(player, data)
	local after = power(player)
	if first then notify(player, TXT.FirstManual, "info", "None") end
	if after ~= before and type((Config.Power.Text or {}).Change) == "string" then
		notify(player, string.format(Config.Power.Text.Change, Util.FormatNumber(before), Util.FormatNumber(after)), "good",
			"None")
	end
	fx(player, { Kind = "Action", From = before, To = after, A = a, H = h, Free = free, Auto = statsOf(data).Auto ~= false })
end

------------------------------------------------------------------ the level / class signals
-- what a level-up placed or gave, as one line (§6); the power from before (last level, last split, same weapon)
local function onLeveledUp(player)
	if not on() or not isPlayer(player) then return end
	local data = getData(player)
	if not data then return end
	local last = seen[player]
	local a, h, free = refresh(player, data)
	if not talks(data) then return end
	local before = last and Config.CombatPower(last.Level, tonumber(player:GetAttribute("WeaponTier")) or 0,
		tonumber(player:GetAttribute("WeaponEnhance")) or 0, { A = last.A, H = last.H }) or nil
	local after = power(player)
	local auto = statsOf(data).Auto ~= false
	local firsts = type(data.Story) == "table" and type(data.Story.First) == "table" and data.Story.First or nil
	local isFirst = firsts ~= nil and firsts.StatPoint ~= true
	if isFirst then firsts.StatPoint = true end
	if auto then
		local parts = {}
		local dA, dH = a - (last and last.A or a), h - (last and last.H or h)
		local names = TXT.Names or {}
		if dA > 0 then table.insert(parts, string.format(TXT.Gain or "+%d %s", dA, names.A or "Attack")) end
		if dH > 0 then table.insert(parts, string.format(TXT.Gain or "+%d %s", dH, names.H or "Health")) end
		if isFirst then
			notify(player, TXT.FirstPoint, "info", "None")
		elseif #parts > 0 and before then
			notify(player, string.format(TXT.LevelAuto, table.concat(parts, " "), Util.FormatNumber(before),
				Util.FormatNumber(after)), "good", "None")
		end
	elseif free > 0 then
		notify(player, Config.Plural(string.format(TXT.LevelPoints, free)), "info", "None")
	end
	fx(player, { Kind = isFirst and "First" or "Level", From = before or after, To = after, A = a, H = h, Free = free,
		Auto = auto })
end

local function onRecount(player)
	if not on() or not isPlayer(player) then return end
	local data = getData(player)
	if data then refresh(player, data) end
end

------------------------------------------------------------------ lifecycle
local function connect(serviceName, signalName, fn)
	local service = S[serviceName]
	local signal = service and service[signalName]
	if signal and type(signal.Connect) == "function" then
		signal:Connect(function(...)
			local ok, err = pcall(fn, ...)
			if not ok then Util.Warn(TAG, signalName .. ": " .. tostring(err)) end
		end)
	else
		Util.Warn(TAG, "missing signal " .. serviceName .. "." .. signalName)
	end
end

function StatService.Init(registry)
	S = registry
end

function StatService.Start()
	Net.Get("StatAction").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onAction, player, ...)
		if not ok then Util.Warn(TAG, "StatAction: " .. tostring(err)) end
	end)
	connect("PlayerService", "PlayerReady", function(player)
		seen[player] = nil
		onRecount(player)
	end)
	connect("ProgressionService", "LeveledUp", onLeveledUp)
	connect("ProgressionService", "LevelReset", onRecount)
	connect("ProgressionService", "Rebirthed", onRecount)
	connect("ClassService", "ClassChanged", onRecount)
	connect("PlayerService", "PlayerLeaving", function(player) seen[player] = nil end)
	print("[StatService] started (StatPoints " .. tostring(on()) .. ")")
end

return StatService
