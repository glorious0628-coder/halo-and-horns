-- BuffService.luau : alchemy tonics (게임성 개발 3, 2026-10-12; contract docs/design/alchemy_server_2026-10-12.md; A23-133:
-- everyone drinks them - bought on the market, made by alchemists -, monsters only, 3 minutes, two at a time).
-- Switched by Config.Features.Tonics (off: Mult is always 1 and nothing can be drunk).
--   * c->s UseTonic(itemId): a ready, living player with at least one of that tonic (Config.Alchemy.Tonics) and fewer
--     than MaxActive other tonics running; one bottle goes, data.Buffs[itemId] = os.time() + Duration (the same tonic
--     again starts its time over, never stacks). The player attribute "Buff_<itemId>" = the server time it ends (0 =
--     none; every client may show it) is set at once, at the join and cleared when it runs out.
--   * BuffService.Mult(player, stat) -> the product of the running tonics' Mult for that stat (1 without any); the one
--     line each hook adds: CombatService (MonsterDamage on every hit on a monster, MonsterHurt on every monster hit),
--     LootService (MaterialDrop on material rows), ProgressionService (HuntXP on a kill's XP).
-- Saved in data.Buffs (Config.SanitizeBuffs cuts an end later than now + 180 s and drops ended ones at the load).
--   BuffService.Use(player, itemId) -> "ok" | reason (the remote handler; public for the offline test) · Running(player)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local BuffService = {}
BuffService.Drank = Util.Signal.new() -- (player, itemId)

local TAG = "BuffService"
local S = nil

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function A()
	return Config.Alchemy
end

local function on()
	return Config.FeatureOn("Tonics") and type(Config.Alchemy) == "table"
end

local function getData(player)
	if not S then return nil end
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and type(t) == "number" and t or os.time()
end

local function notify(player, key)
	local ok, err = pcall(Net.NotifyKey, player, "Config.Alchemy.Text." .. key, nil, "bad")
	if not ok then Util.Warn(TAG, "notice " .. key .. ": " .. tostring(err)) end
end

-- the tonics running now: { [itemId] = os.time() it ends }
function BuffService.Running(player)
	local out = {}
	local data = getData(player)
	local buffs = data and data.Buffs
	if type(buffs) ~= "table" then return out end
	local now = os.time()
	for id, ends in buffs do
		if type(A().Tonics[id]) == "table" and num(ends) > now then out[id] = num(ends) end
	end
	return out
end

-- the multiplier of `stat` for this player right now (1 = no tonic for it, or the switch is off). Never throws.
function BuffService.Mult(player, stat)
	if not on() or typeof(player) ~= "Instance" then return 1 end
	local mult = 1
	for id in BuffService.Running(player) do
		local t = A().Tonics[id]
		if t.Stat == stat then mult *= num(t.Mult, 1) end
	end
	return mult
end

-- the attribute every client reads: Buff_<id> = the server time it ends, 0 = not running
local function publish(player)
	if typeof(player) ~= "Instance" or player.Parent ~= Players then return end
	local running = BuffService.Running(player)
	local now, snow = os.time(), serverNow()
	for id in A().Tonics do
		local ends = running[id]
		player:SetAttribute("Buff_" .. id, ends and (snow + (ends - now)) or 0)
	end
end

-- clear the attribute when a tonic's time is up (the save keeps nothing extra: Running reads the end times)
local function watch(player, id, ends)
	task.delay(math.max(0, ends - os.time()) + 0.1, function()
		local ok, err = pcall(function()
			if player.Parent ~= Players then return end
			local data = getData(player)
			local buffs = data and data.Buffs
			if type(buffs) == "table" and num(buffs[id]) <= os.time() then
				buffs[id] = nil
				publish(player)
			end
		end)
		if not ok then Util.Warn(TAG, "expire: " .. tostring(err)) end
	end)
end

function BuffService.Use(player, id)
	if not on() then return "off" end
	-- A23-219 ② B: a special (Alchemy.Plus) runs as its Base (never two of one effect), Extra s longer
	local base = Config.TonicBase(id)
	local tonic = base and A().Tonics[base] or nil
	if type(tonic) ~= "table" or not Config.Loot.Items[id] then return "tonic" end
	local sp = base ~= id and type(A().Plus) == "table" and A().Plus[id] or nil
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return "state" end
	local data = getData(player)
	if not data or not S.PlayerService.IsReady(player) or not Util.IsAlive(player) then return "state" end
	local have = type(data.Items) == "table" and math.floor(num(data.Items[id])) or 0
	if have < 1 then
		notify(player, "NoTonic")
		return "none"
	end
	local running = BuffService.Running(player)
	local others = 0
	for other in running do
		if other ~= base then others += 1 end
	end
	if others >= num(A().MaxActive, 2) then
		notify(player, "TwoMax")
		return "two"
	end
	if not S.LootService.TakeItem(player, id, 1) then return "none" end
	if type(data.Buffs) ~= "table" then data.Buffs = {} end
	for other in data.Buffs do
		if not running[other] then data.Buffs[other] = nil end -- ended ones go
	end
	local ends = os.time() + math.floor(num(A().Duration, 180)) + math.max(0, math.floor(num(type(sp) == "table" and sp.Extra, 0)))
	data.Buffs[base] = ends
	publish(player)
	watch(player, base, ends)
	if S.PlayerService.MarkActive then pcall(S.PlayerService.MarkActive, player) end
	if S.TelemetryService and S.TelemetryService.Custom then pcall(S.TelemetryService.Custom, player, "TonicUse", 1, id) end
	BuffService.Drank:Fire(player, id)
	return "ok"
end

------------------------------------------------------------------ service
local function onUse(player, ...)
	if select("#", ...) ~= 1 then return end
	local id = ...
	if type(id) ~= "string" or #id > 32 then return end
	if not Util.RateLimit(player, "UseTonic", num(Config.RateLimits.UseTonic, 1)) then return end
	BuffService.Use(player, id)
end

function BuffService.Init(registry)
	S = registry
end

function BuffService.Start()
	Net.Get("UseTonic").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onUse, player, ...)
		if not ok then Util.Warn(TAG, "UseTonic: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player)
		local ok, err = pcall(function()
			if not on() then return end
			publish(player)
			for id, ends in BuffService.Running(player) do watch(player, id, ends) end
		end)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	print("[BuffService] started")
end

return BuffService
