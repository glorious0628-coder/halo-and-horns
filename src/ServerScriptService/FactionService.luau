-- FactionService.luau : Teams, first faction choice, altar faction switch (free / ticket), SetFaction, faction counts.
-- Factions: "Halo", "Horns", "Neutral" (playable, addendum A6) and "None" (not chosen yet).
-- Faction ratios / counts used by war, Size Justice and rebirth bonuses are Halo vs Horns only (A6).
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Net = require(ReplicatedStorage.Shared.Net)

local TAG = "FactionService"
local RECOUNT_INTERVAL = 10 -- seconds between periodic faction recounts (spec §4.10)
local LEAVE_FORGET_SECONDS = 60 -- how long a leaving player stays in the "leaving" set (they are gone by then)
local ALTAR_PROMPT_RATE = 0.5 -- private rate limit for the altar ProximityPrompt
local WARN_THROTTLE = 10
-- TODO(config): no Config.Text key for a switch that costs nothing (leaving Neutral, addendum A6);
-- Config.Text.SwitchDonePlain is used instead once it exists.
local TEXT_SWITCH_DONE_PLAIN = "%s(으)로 진영을 바꿨어요!"
local SCORE_NAME = { Halo = "명예", Horns = "악명" } -- score lost by a FREE switch away from that faction

local FactionService = {}

FactionService.FactionChanged = Util.Signal.new() -- (player, newFaction, oldFaction, reason: "Choose" | "Altar" | "Rebirth")

local S = nil
local teams = {} -- [factionId] = Team
local leaving = {} -- [Player] = true while the player is leaving (excluded from counts)
local lastWarnAt = {}

local KNOWN = { Halo = true, Horns = true, Neutral = true, None = true }

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	local last = lastWarnAt[key]
	if last and now - last < WARN_THROTTLE then return end
	lastWarnAt[key] = now
	Util.Warn(TAG, tostring(msg))
end

-- a faction a player may pick / switch to (needs its Config entry)
local function isPlayable(factionId)
	return (factionId == "Halo" or factionId == "Horns" or factionId == "Neutral") and Config.Factions[factionId] ~= nil
end

local function isCounted(player)
	return player ~= nil and player.Parent == Players and not leaving[player]
end

local function notify(player, key, kind, ...)
	local fmt = Config.Text[key]
	if type(fmt) ~= "string" then return end
	Net.Notify(player, string.format(fmt, ...), kind)
end

local function applyTeam(player, factionId)
	local team = teams[factionId]
	local ok, err = pcall(function()
		if factionId ~= "None" and team and team.Parent then
			player.Neutral = false
			player.Team = team
		else
			player.Team = nil
			player.Neutral = true
		end
	end)
	if not ok then warnThrottled("team", "team assignment failed: " .. tostring(err)) end
end

local function getOrCreateTeam(def)
	if not def or type(def.TeamName) ~= "string" or def.TeamName == "" then return nil end
	local existing = Teams:FindFirstChild(def.TeamName)
	local team = (existing and existing:IsA("Team")) and existing or Instance.new("Team")
	team.Name = def.TeamName
	if def.TeamColor then team.TeamColor = def.TeamColor end
	team.AutoAssignable = false
	team.Parent = Teams
	return team
end

local function recount()
	if not S then return end
	local halo, horns = FactionService.GetCounts()
	local gs = Net.GameState()
	gs:SetAttribute("HaloCount", halo)
	gs:SetAttribute("HornsCount", horns)
end

local function safeRecount()
	local ok, err = pcall(recount)
	if not ok then warnThrottled("recount", "recount failed: " .. tostring(err)) end
end

local function kaijuState(player)
	local k = S.KaijuService
	if k and k.GetState then
		local ok, st = pcall(k.GetState, player)
		if ok and type(st) == "string" then return st end
	end
	return "None"
end

local function wantedStars(player)
	local p = S.PvPService
	if p and p.GetStars then
		local ok, n = pcall(p.GetStars, player)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

local function lastSwitchTime(player)
	local data = S.PlayerService.GetData(player)
	local t = data and data.LastSwitchTime
	if type(t) ~= "number" then t = player:GetAttribute("LastSwitchTime") end
	return tonumber(t) or 0
end

local function nearAltar(player)
	local root = Util.GetRoot(player)
	if not root then return false end
	local ok, altar = pcall(S.MapBuilder.GetAltar)
	if not ok or typeof(altar) ~= "Instance" or not altar:IsA("BasePart") then return false end
	return Util.FlatDistance(root.Position, altar.Position) <= Config.Switch.AltarRange
end

-- Spec payload is (useTicket: boolean). Addendum A6 makes the target ambiguous with three factions, so an optional
-- target faction id (string) is accepted in either position: (useTicket, target) or (target, useTicket).
local function parseSwitchArgs(a, b)
	if type(a) == "boolean" then
		if b == nil then return a, nil end
		if type(b) == "string" then return a, b end
		return nil, nil
	end
	if type(a) == "string" and type(b) == "boolean" then
		return b, a
	end
	return nil, nil
end

-- target when the client did not name one: Halo <-> Horns as in the spec; Neutral joins the side that needs players
local function defaultTarget(current)
	if current == "Halo" then return "Horns" end
	if current == "Horns" then return "Halo" end
	local weaker = "None"
	local j = S.JusticeService
	if j and j.GetWeakerFaction then
		local ok, w = pcall(j.GetWeakerFaction)
		if ok then weaker = w end
	end
	if weaker == "Halo" or weaker == "Horns" then return weaker end
	local halo, horns = FactionService.GetCounts()
	return (horns < halo) and "Horns" or "Halo"
end

------------------------------------------------------------------ public API
function FactionService.GetFaction(player)
	if not player then return "None" end
	local f = player:GetAttribute("Faction")
	if type(f) == "string" and KNOWN[f] then return f end
	return "None"
end

function FactionService.GetPerks(player)
	return Config.Factions[FactionService.GetFaction(player)] or Config.Factions.None
end

-- ready players only, excluding leaving players; Neutral / None are not counted (A6: ratios are Halo vs Horns)
function FactionService.GetCounts()
	if not S then return 0, 0 end
	local halo, horns = 0, 0
	for _, p in S.PlayerService.GetReadyPlayers() do
		if isCounted(p) then
			local f = FactionService.GetFaction(p)
			if f == "Halo" then
				halo += 1
			elseif f == "Horns" then
				horns += 1
			end
		end
	end
	return halo, horns
end

function FactionService.GetTeam(factionId)
	local t = teams[factionId]
	if t and t.Parent then return t end
	return nil
end

-- the ONLY writer of the Faction stat. Never touches Honor/Infamy, tickets or cooldowns (callers do).
function FactionService.SetFaction(player, factionId, reason)
	if not player or not S then return end
	if type(factionId) ~= "string" or not KNOWN[factionId] or (factionId ~= "None" and not Config.Factions[factionId]) then
		Util.Warn(TAG, "SetFaction: invalid faction " .. tostring(factionId))
		return
	end
	local old = FactionService.GetFaction(player)
	S.PlayerService.SetStat(player, "Faction", factionId)
	applyTeam(player, factionId)
	FactionService.FactionChanged:Fire(player, factionId, old, reason or "Choose")
	safeRecount()
end

------------------------------------------------------------------ remotes
local function onChooseFaction(player, factionId)
	if not S.PlayerService.IsReady(player) then return end
	if type(factionId) ~= "string" or not isPlayable(factionId) then return end
	if not Util.RateLimit(player, "ChooseFaction", Config.RateLimits.ChooseFaction) then return end
	if FactionService.GetFaction(player) ~= "None" then return end -- silent: first choice only

	-- read BEFORE changing; the sign-on bonus is Halo vs Horns only (A6), GetWeakerFaction never returns "Neutral"
	local wasWeaker = false
	if factionId == "Halo" or factionId == "Horns" then
		wasWeaker = (S.JusticeService.GetWeakerFaction() == factionId)
	end

	FactionService.SetFaction(player, factionId, "Choose")

	if wasWeaker then
		S.ProgressionService.AddBankGold(player, Config.Justice.SignOnGold, "Other")
		notify(player, "UnderdogSignOn", "reward", Config.Justice.SignOnGold)
	end
	S.PlayerService.Respawn(player)
end

local function onSwitchFaction(player, a, b)
	if not S.PlayerService.IsReady(player) then return end
	local useTicket, target = parseSwitchArgs(a, b)
	if type(useTicket) ~= "boolean" then return end
	if target ~= nil and not isPlayable(target) then return end
	if not Util.RateLimit(player, "SwitchFaction", Config.RateLimits.SwitchFaction) then return end

	local old = FactionService.GetFaction(player)
	if old == "None" then return end -- silent
	local new = target or defaultTarget(old)
	if new == old or not isPlayable(new) then return end -- silent
	if not nearAltar(player) then return end -- silent

	if S.GrudgeService.HasSack(player) then
		notify(player, "BlockedSack", "bad")
		return
	end
	if kaijuState(player) ~= "None" then
		notify(player, "BlockedKaiju", "bad")
		return
	end
	if wantedStars(player) > 0 then
		notify(player, "BlockedStars", "bad")
		return
	end
	if S.CombatService.IsInCombat(player) then
		notify(player, "TravelBlockedCombat", "bad")
		return
	end
	local remaining = lastSwitchTime(player) + Config.Switch.Cooldown - os.time()
	if remaining > 0 then
		notify(player, "SwitchCooldown", "bad", Util.FormatTime(remaining))
		return
	end

	-- leaving Neutral costs nothing (A6: no Neutral score yet), so a ticket is never consumed for it
	local lostScore = SCORE_NAME[old]
	local ticketUsed = false
	if useTicket and lostScore then
		if not S.MonetizationService.UseTicket(player, "Faction") then
			notify(player, "NoTicket", "bad")
			return
		end
		ticketUsed = true
	end

	-- free switch: the score of the faction being LEFT resets ("배신의 대가")
	if not ticketUsed then
		if old == "Halo" then
			S.PlayerService.SetStat(player, "Honor", 0)
		elseif old == "Horns" then
			S.PlayerService.SetStat(player, "Infamy", 0)
		end
	end

	S.PlayerService.AddStat(player, "SwitchCount", 1)
	S.PlayerService.SetStat(player, "LastSwitchTime", os.time())
	FactionService.SetFaction(player, new, "Altar")

	local newName = (Config.Factions[new] and Config.Factions[new].Name) or new
	if ticketUsed then
		notify(player, "SwitchDoneTicket", "good", newName)
	elseif lostScore then
		notify(player, "SwitchDoneFree", "good", newName, lostScore)
	else
		local fmt = Config.Text.SwitchDonePlain
		Net.Notify(player, string.format(type(fmt) == "string" and fmt or TEXT_SWITCH_DONE_PLAIN, newName), "good")
	end
	S.PlayerService.Respawn(player)
end

local function onPromptTriggered(prompt, player)
	if not prompt or prompt.Name ~= "AltarPrompt" then return end
	local parent = prompt.Parent
	if not parent or parent.Name ~= "Altar" then return end
	if not player or not S.PlayerService.IsReady(player) then return end
	if FactionService.GetFaction(player) == "None" then return end
	if not Util.RateLimit(player, "AltarPrompt", ALTAR_PROMPT_RATE) then return end
	Net.Get("OpenPanel"):FireClient(player, "Altar")
end

------------------------------------------------------------------ lifecycle
local function onPlayerReady(player, data)
	leaving[player] = nil
	local f = data and data.Faction
	if type(f) ~= "string" or not KNOWN[f] or (f ~= "None" and not Config.Factions[f]) then
		-- corrupted / unknown value: fall back to "None" (picker shows again). No FactionChanged during join.
		Util.Warn(TAG, "invalid stored faction " .. tostring(f) .. " for " .. player.Name .. "; reset to None")
		S.PlayerService.SetStat(player, "Faction", "None")
		f = "None"
	end
	applyTeam(player, f)
	safeRecount()
end

local function onPlayerLeaving(player)
	leaving[player] = true
	safeRecount()
	task.delay(LEAVE_FORGET_SECONDS, function()
		leaving[player] = nil
	end)
end

function FactionService.Init(registry)
	S = registry
	for _, id in { "Halo", "Horns", "Neutral" } do
		local def = Config.Factions[id]
		if def then
			local ok, teamOrErr = pcall(getOrCreateTeam, def)
			if ok then
				teams[id] = teamOrErr
			else
				Util.Warn(TAG, "could not create team for " .. id .. ": " .. tostring(teamOrErr))
			end
		end
	end
	S.PlayerService.PlayerReady:Connect(onPlayerReady)
	S.PlayerService.PlayerLeaving:Connect(onPlayerLeaving)
end

function FactionService.Start()
	Net.Get("ChooseFaction").OnServerEvent:Connect(onChooseFaction)
	Net.Get("SwitchFaction").OnServerEvent:Connect(onSwitchFaction)

	-- global hook (survives MapBuilder.Rebuild); filtered to workspace.Map.Landmarks.Altar.AltarPrompt
	ProximityPromptService.PromptTriggered:Connect(onPromptTriggered)
	local ok, altar = pcall(S.MapBuilder.GetAltar)
	if not ok or typeof(altar) ~= "Instance" or not altar:FindFirstChild("AltarPrompt") then
		Util.Warn(TAG, "altar or AltarPrompt not found at start; the altar panel cannot open until it exists")
	end

	task.spawn(function()
		while true do
			task.wait(RECOUNT_INTERVAL)
			safeRecount()
		end
	end)
	safeRecount()

	print("[FactionService] started")
end

return FactionService
