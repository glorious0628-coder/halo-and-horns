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
local SCORE_NAME = { Halo = "Honor", Horns = "Mischief" } -- the SHOWN score lost by a FREE switch away (A23-166)
local SCORE_KEY = { Halo = "Honor", Horns = "Infamy" } -- CR-L11: the stat behind SCORE_NAME
local UNDERDOG_IDLE_SECONDS = 120 -- CR-L7: no input / combat for this long = not counted for the underdog bonus

local FactionService = {}

FactionService.FactionChanged = Util.Signal.new() -- (player, newFaction, oldFaction, reason: "Choose" | "Altar" | "Rebirth")

local S = nil
local teams = {} -- [factionId] = Team ("None" = players who have not picked yet)
local NONE_TEAM_NAME = "Choosing a side"
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

-- a faction a player may newly pick / switch to (Config.Pickable: Halo / Horns; the artisan guild only while
-- Config.Features.NeutralFaction is on, A23-57)
local function isPlayable(factionId)
	return Config.Pickable(factionId)
end

-- A23-57: a request for the switched-off artisan guild is refused like any invalid one, with a log line
local function logNeutralRefused(player, factionId)
	if factionId == "Neutral" and not Config.FeatureOn("NeutralFaction") then
		warnThrottled("neutral", ("%s asked for the artisan guild, off for the beta (A23-57)"):format(player.Name))
	end
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
		-- players who have not picked yet sit in the "진영 고르는 중" team, so the player list never shows "Neutral"
		if team and team.Parent then
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
	-- CR-L7: rebirth preview (Panels) reads the same counts the server bonus uses
	local uHalo, uHorns = FactionService.GetUnderdogCounts()
	gs:SetAttribute("UnderdogHalo", uHalo)
	gs:SetAttribute("UnderdogHorns", uHorns)
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

local function bullyStacks(player)
	local j = S.JusticeService
	if j and j.GetBullyStacks then
		local ok, n = pcall(j.GetBullyStacks, player)
		if ok and type(n) == "number" then return n end
	end
	return 0
end

-- data value first, mirrored attribute as fallback
local function statNum(player, key)
	local data = S.PlayerService.GetData(player)
	local v = data and data[key]
	if type(v) ~= "number" then v = player:GetAttribute(key) end
	return tonumber(v) or 0
end

local function lastSwitchTime(player)
	return statNum(player, "LastSwitchTime")
end

-- CR-L7: rookies (PvPService.IsRookie) and idlers (PlayerService.GetLastActive, CR-M20) do not count
local function isUnderdogEligible(player, now)
	local pvp = S.PvPService
	if pvp and pvp.IsRookie then
		local ok, rookie = pcall(pvp.IsRookie, player)
		if ok and rookie == true then return false end
	end
	local ps = S.PlayerService
	if ps and ps.GetLastActive then
		local ok, t = pcall(ps.GetLastActive, player)
		if ok and type(t) == "number" and now - t > UNDERDOG_IDLE_SECONDS then return false end
	end
	return true
end

local function nearAltar(player)
	local root = Util.GetRoot(player)
	if not root then return false end
	local ok, altar = pcall(S.MapBuilder.GetAltar)
	if not ok or typeof(altar) ~= "Instance" or not altar:IsA("BasePart") then return false end
	if Util.FlatDistance(root.Position, altar.Position) > Config.Switch.AltarRange then return false end
	-- CR-H2: a root that just teleported is not near. IsPlausible always logs a suspicious move and returns false
	-- only while Config.AntiCheat.Enforce is true (log-only mode: always true)
	local zs = S.ZoneService
	if zs and zs.IsPlausible then
		local okP, plausible = pcall(zs.IsPlausible, player, root.Position)
		if okP and plausible == false then return false end
	end
	return true
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

-- CR-L7: GetCounts without rookies and 120 s idlers (underdog rebirth bonus + GameState UnderdogHalo/Horns).
-- `always` (optional Player) is counted even if idle, e.g. the player rebirthing at the altar right now.
function FactionService.GetUnderdogCounts(always)
	if not S then return 0, 0 end
	local now = os.clock()
	local halo, horns = 0, 0
	for _, p in S.PlayerService.GetReadyPlayers() do
		if isCounted(p) then
			local f = FactionService.GetFaction(p)
			if (f == "Halo" or f == "Horns") and (p == always or isUnderdogEligible(p, now)) then
				if f == "Halo" then
					halo += 1
				else
					horns += 1
				end
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
	if type(factionId) ~= "string" or not isPlayable(factionId) then
		logNeutralRefused(player, factionId)
		return
	end
	if not Util.RateLimit(player, "ChooseFaction", Config.RateLimits.ChooseFaction) then return end
	if FactionService.GetFaction(player) ~= "None" then return end -- silent: first choice only

	-- read BEFORE changing; the sign-on bonus is Halo vs Horns only (A6), GetWeakerFaction never returns "Neutral"
	local wasWeaker = false
	if factionId == "Halo" or factionId == "Horns" then
		wasWeaker = (S.JusticeService.GetWeakerFaction() == factionId)
	end

	FactionService.SetFaction(player, factionId, "Choose")

	if wasWeaker then
		-- CR-L10: the sign-on bonus starts the altar cooldown (no instant free switch after cashing it)
		S.PlayerService.SetStat(player, "LastSwitchTime", os.time())
		-- A23-75: an earned reward ("SignOn": 2x with the 2x Gold pass); the line shows what was added
		local got = S.ProgressionService.AddBankGold(player, Config.Justice.SignOnGold, "SignOn") or Config.Justice.SignOnGold
		-- sound_gaps C1: banked gold (GoldPickup), never QuestDone
		Net.Notify(player, string.format(Config.Text.UnderdogSignOn, got), "reward", nil, "GoldPickup")
	end
	S.PlayerService.Respawn(player)
end

local function onSwitchFaction(player, a, b)
	if not S.PlayerService.IsReady(player) then return end
	local useTicket, target = parseSwitchArgs(a, b)
	if type(useTicket) ~= "boolean" then return end
	if target ~= nil and not isPlayable(target) then
		logNeutralRefused(player, target)
		return
	end
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
	-- CR-L9: Neutral sheds bully stacks (A6), so a bully may not reach it through the altar
	if new == "Neutral" and bullyStacks(player) > 0 then
		notify(player, "BlockedBully", "bad")
		return
	end
	local remaining = lastSwitchTime(player) + Config.Switch.Cooldown - os.time()
	if remaining > 0 then
		notify(player, "SwitchCooldown", "bad", Util.FormatTime(remaining))
		return
	end

	-- leaving Neutral costs nothing (A6: no Neutral score yet), so a ticket is never consumed for it
	local lostScore = SCORE_NAME[old]
	-- CR-L11: a score of 0 has nothing to protect, so the ticket is kept then too
	local scoreKey = SCORE_KEY[old]
	local atStake = scoreKey ~= nil and statNum(player, scoreKey) > 0
	local ticketUsed = false
	if useTicket and lostScore and atStake then
		local okTicket, why = S.MonetizationService.UseTicket(player, "Faction")
		if not okTicket then
			-- CR-L25: a purchase still being saved is not "no ticket"
			notify(player, why == "Pending" and "TicketSaving" or "NoTicket", "bad")
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

	-- A23-130: no "You joined ..." line (the confirm said it, the player respawns in the new town); a free switch
	-- that reset a score says that loss only ("Honor back to 0.")
	if not ticketUsed and lostScore and atStake then
		notify(player, "SwitchDoneFree", "info", lostScore)
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
	local okNone, noneTeam = pcall(getOrCreateTeam, { TeamName = NONE_TEAM_NAME, TeamColor = BrickColor.new("Medium stone grey") })
	if okNone and noneTeam then
		noneTeam.AutoAssignable = true -- new players join it before they pick a faction
		teams.None = noneTeam
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
