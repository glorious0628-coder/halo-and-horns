-- SettingsService.luau : BB2 (docs/design/beta_basics_2026-10-05.md) one saved settings blob per account, so changed
-- keys and options follow the player to the next visit and to other servers.
-- data.Settings = Config.SanitizeSettings(...) = { V, Keys (sparse action id -> key name or "", changes only), Sfx,
-- Shake, DmgNum, Tags, KeyBadges, Lang, BagSort }. Not mirrored; Version stays 3 (DataService.fillDefaults sanitizes old
-- and broken saves). HideAnnounceName / AutoCombatEnabled / IntroSeen keep their own remotes and fields.
-- Remotes:
--   c->s "SetSettings"(blob?): zero args = "send me mine"; else one table with at most Config.Settings.MaxBlobKeys
--     top-level keys, blob.Seq = an integer clamped to 0..2^31. Needs PlayerService.IsReady and Util.RateLimit
--     (Config.RateLimits.SetSettings); a dropped call gets no answer. Saves Config.SanitizeSettings(blob) and echoes.
--   s->c "Settings" { Seq, Settings } to the owner only: the echo of every accepted call (Seq of that blob, 0 for "send
--     me mine") and once on PlayerReady (Seq 0). The client ignores echoes older than its newest sent Seq.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local SettingsService = {}
local S = nil
local TAG = "SettingsService"
local MAX_SEQ = 2 ^ 31

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

-- the saved settings of a loaded player (repairs a missing table), or nil
function SettingsService.Get(player)
	local data = getData(player)
	if not data then return nil end
	if type(data.Settings) ~= "table" then data.Settings = Config.SanitizeSettings(nil) end
	return data.Settings
end

-- full action -> key name map of this player (server view: every action whose Flag is on), for {Auto}-style texts
function SettingsService.KeyMap(player)
	local settings = SettingsService.Get(player)
	return (Config.KeyMap(settings and settings.Keys or nil, nil))
end

local function send(player, seq, settings)
	if type(settings) ~= "table" then return end
	local ok, err = pcall(function()
		Net.Get("Settings"):FireClient(player, { Seq = seq, Settings = Util.DeepCopy(settings) })
	end)
	if not ok then Util.Warn(TAG, "send: " .. tostring(err)) end
end

local function onSetSettings(player, ...)
	local n = select("#", ...)
	if n > 1 then return end
	local blob = ...
	local seq = 0
	if n == 1 then
		if type(blob) ~= "table" then return end
		local count = 0
		for _ in blob do
			count += 1
			if count > (Config.Settings.MaxBlobKeys or 16) then return end
		end
		local s = blob.Seq
		if type(s) == "number" and s == s then seq = math.clamp(math.floor(s), 0, MAX_SEQ) end
	end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "SetSettings", Config.RateLimits.SetSettings or 1) then return end
	local data = getData(player)
	if not data then return end
	if n == 1 then data.Settings = Config.SanitizeSettings(blob) end
	send(player, seq, SettingsService.Get(player))
end

function SettingsService.Init(registry)
	S = registry
end

function SettingsService.Start()
	Net.Get("SetSettings").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onSetSettings, player, ...)
		if not ok then Util.Warn(TAG, "SetSettings: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player)
		local ok, err = pcall(function() send(player, 0, SettingsService.Get(player)) end)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)

	-- BB3 settings footer: GameState SaveOK = false while DataService runs in memory mode (no saving on this server);
	-- the DataStore probe finishes after start and can fall back later, so it is checked again every 30 s (a delay
	-- chain, no waiting thread)
	local function publishSaveOK()
		local okMode, memory = pcall(function() return S.DataService.IsMemoryMode() end)
		if okMode then pcall(function() Net.GameState():SetAttribute("SaveOK", memory ~= true) end) end
		task.delay(30, publishSaveOK)
	end
	publishSaveOK()
	print("[SettingsService] started")
end

return SettingsService
