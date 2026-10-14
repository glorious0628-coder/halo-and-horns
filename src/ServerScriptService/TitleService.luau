-- TitleService.luau : BB16 (docs/design/beta_basics_2026-10-05.md) owned titles + the one shown on the nametag.
-- data.Titles = { [id] = os.time() first owned }, data.TitleSel = "" (automatic: faction rank / gray legend) or an owned
-- id from Config.TitleDefs. Titles never give stats. Grants: BetaPioneer (joined before the full launch, A23-18: while
-- Config.Beta.GrantPioneer, before PioneerUntil and the live switch PioneerTitle is on; the old boolean data.BetaPioneer
-- migrates here) and GrayLegend (fall + redeem marks, kept once earned).
-- Remote c->s "SetTitle"(id): one string <= 32 chars, owned or "" (anything else is ignored).
-- The client reads the TitleSel attribute (mirrored) and TitlesOwned ("id,id", for the BB8 picker).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local TitleService = {}
local S = nil
local CONNS = {} -- [Player] = { RBXScriptConnection } (gray legend watchers, dropped on leave)

local function titles(data)
	if type(data.Titles) ~= "table" then data.Titles = {} end
	return data.Titles
end

-- "BetaPioneer,GrayLegend" in Config.TitleDefs order (stable for the picker)
local function publish(player, data)
	local owned = {}
	for _, id in Config.TitleOrder do
		if titles(data)[id] then table.insert(owned, id) end
	end
	player:SetAttribute("TitlesOwned", table.concat(owned, ","))
end

-- returns true when the title is new for this player
function TitleService.Grant(player, id)
	if not Config.TitleDefs[id] then return false end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" or titles(data)[id] then return false end
	titles(data)[id] = os.time()
	publish(player, data)
	return true
end

-- BB10 timed titles (Config.TitleDefs[id].Timed: the weekly "이번 주 명예 1위" titles): RankingService removes them
-- when their week ends; a removed selected title falls back to automatic (""). Returns true when it was owned.
function TitleService.Revoke(player, id)
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" or type(data.Titles) ~= "table" or data.Titles[id] == nil then return false end
	data.Titles[id] = nil
	if data.TitleSel == id then S.PlayerService.SetStat(player, "TitleSel", "") end
	publish(player, data)
	return true
end

function TitleService.Owns(player, id)
	local data = S.PlayerService.GetData(player)
	return type(data) == "table" and type(data.Titles) == "table" and data.Titles[id] ~= nil
end

local function checkGrayLegend(player)
	local min = Config.Rebirth.GrayLegendMin
	if (tonumber(player:GetAttribute("FallMarks")) or 0) >= min and (tonumber(player:GetAttribute("RedeemMarks")) or 0) >= min then
		TitleService.Grant(player, "GrayLegend")
	end
end

-- 2-A ⑦: the live switch PioneerTitle (Config.Switches; the full-launch day turns it off). No switchboard (or a failing
-- one) = on, like every other switch
local function pioneerSwitchOn()
	local sw = S and S.SwitchService
	if type(sw) ~= "table" or type(sw.On) ~= "function" then return true end
	local ok, on = pcall(sw.On, "PioneerTitle")
	return not ok or on ~= false
end

local function onReady(player, data)
	local beta = Config.Beta
	local pioneer = data.BetaPioneer == true
		or (beta.GrantPioneer == true and os.time() < beta.PioneerUntil and pioneerSwitchOn())
	if pioneer then TitleService.Grant(player, "BetaPioneer") end
	-- review 381f6a1: the faction rank (GDD §0) stays the default title; the pioneer shows as a small mark on the
	-- nametag's second line instead. A TitleSel the player never picked (data.TitleSelAt, set only by SetTitle) was the
	-- old one-time auto-select: back to automatic once. Owned titles stay.
	if data.TitleSel == "BetaPioneer" and data.TitleSelAt == nil then
		S.PlayerService.SetStat(player, "TitleSel", "")
	end
	checkGrayLegend(player)
	-- a selected title the player no longer owns (data edited / removed def) falls back to automatic
	if data.TitleSel ~= "" and not (Config.TitleDefs[data.TitleSel] and titles(data)[data.TitleSel]) then
		S.PlayerService.SetStat(player, "TitleSel", "")
	end
	publish(player, data)
	for _, c in CONNS[player] or {} do c:Disconnect() end
	CONNS[player] = {
		player:GetAttributeChangedSignal("FallMarks"):Connect(function() pcall(checkGrayLegend, player) end),
		player:GetAttributeChangedSignal("RedeemMarks"):Connect(function() pcall(checkGrayLegend, player) end),
	}
end

local function onSetTitle(player, ...)
	if select("#", ...) ~= 1 then return end
	local id = ...
	if type(id) ~= "string" or #id > 32 then return end
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "SetTitle", Config.RateLimits.SetTitle) then return end
	if id ~= "" and not (Config.TitleDefs[id] and TitleService.Owns(player, id)) then return end
	local data = S.PlayerService.GetData(player)
	if type(data) == "table" then data.TitleSelAt = os.time() end -- an explicit pick (never undone by the migration)
	S.PlayerService.SetStat(player, "TitleSel", id)
end

function TitleService.Init(registry)
	S = registry
end

function TitleService.Start()
	S.PlayerService.PlayerReady:Connect(function(player, data)
		local ok, err = pcall(onReady, player, data)
		if not ok then Util.Warn("TitleService", "ready: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		for _, c in CONNS[player] or {} do c:Disconnect() end
		CONNS[player] = nil
	end)
	Net.Get("SetTitle").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onSetTitle, player, ...)
		if not ok then Util.Warn("TitleService", "SetTitle: " .. tostring(err)) end
	end)
	print("[TitleService] started")
end

return TitleService
