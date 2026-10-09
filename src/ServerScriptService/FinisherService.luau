-- FinisherService.luau : the King Slime finisher card (게임성 개발 2, 2026-10-08; contract
-- docs/design/king_finisher_2026-10-08.md, rpg_success_analysis_2026-10-08 §4-3 #9, 검수 kid-safe cut). The kill itself
-- never changes (the same pop, XP / gold / drops, A23-2 / A23-12, quests and funnels for everyone). A
-- Config.Finisher.Kinds kill paid to a contributor whose info.Manual is true (MonsterService: an accepted own press, not
-- auto combat, within the ContributorWindow) gives that player one card only they see:
--   s->c Fx "FinisherCard" { Id, Kind, Seconds, Stat, Help = { Item, N, Score, Hint? }, Tickle = { Gold, Score, Hint? } }
--        (Score = what picking it would change now: +Points, -Points or 0; Stat = "Honor" | "Infamy" | "None";
--        Hint = "Neutral" (no side) | "Full" (my side, today's points used up) | "Zero" (the other side, nothing to
--        lose) | nil (the Score says it) - Config.Finisher.Text HintNeutral / HintFull / HintZero)
--   c->s "FinisherPick" (id, "Help" | "Tickle"): only the open card, its Id, within Seconds + Grace, once
--   s->c Fx "FinisherEnd" { Id, Pick = "Help" | "Tickle" | "None", Stat, Score, Item, N, Gold } (what really happened)
-- Help = the Good side (Jelly; a full bag pays the rest at its sell price), Tickle = the Evil side (bank gold, source
-- "Finisher": not a Config.PassBoost source, so never 2x). My side's pick: +Points inside ScoreBudget (P9); the other
-- side's: -Points (A23-58, never below 0); Neutral / no side: the gift only. Points go through AddStat only (no weekly
-- ranking credit, like story picks). One open card a player at a time: a kill meanwhile gives none. Not picked in time
-- or left = "None" (no gift, no points). Metric: FinisherPick (Halo | Horns | None, my faction).
-- Signal FinisherService.Picked(player, "Help" | "Tickle" | "None", kind).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local FinisherService = {}
FinisherService.Picked = Util.Signal.new() -- (player, "Help" | "Tickle" | "None", kind)

local TAG = "FinisherService"
local S = nil
local F = Config.Finisher
local TXT = F.Text
local STORY = Config.StoryQuests.Text -- the A23-58 off-side and rank-down lines of story picks
-- Open[player] = { Id, Kind, Ends } the open card; Serial[player] = the last card id given on this server
local CARD = { Open = {}, Serial = {} }
local SIDE = { Help = "Good", Tickle = "Evil" }
local METRIC = { Help = "Halo", Tickle = "Horns" }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

-- sound (optional): the Config.Audio key, "None" = silent (sound_gaps C1: a pick line never plays QuestDone)
local function notify(player, text, kind, sound)
	local ok, err = pcall(Net.Notify, player, text, kind, nil, sound)
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

local function fx(player, kind, data)
	local ok, err = pcall(Net.Fx, player, kind, data)
	if not ok then Util.Warn(TAG, kind .. ": " .. tostring(err)) end
end

local function sideOf(player)
	local f = player:GetAttribute("Faction")
	if f == "Halo" or f == "Horns" then return f end
	return nil
end

local function points()
	return math.max(0, math.floor(num(F.Points)))
end

-- what picking `option` changes: my side = +Points (the budget left today), the other side = -Points (never below 0)
local function scoreOf(player, option)
	local f = sideOf(player)
	if not f then return "None", 0, false end
	local stat = f == "Halo" and "Honor" or "Infamy"
	if (f == "Halo") == (SIDE[option] == "Good") then
		return stat, math.min(points(), S.ScoreBudget.Left(player)), true
	end
	local data = S.PlayerService.GetData(player)
	local have = math.max(0, math.floor(num(data and data[stat])))
	return stat, -math.min(have, points()), false
end

-- review 2026-10-08: the card's hint for one option (Score 0 means "cap full" on my side, "nothing to lose" on the
-- other side)
local function hintOf(stat, score, mine)
	if stat == "None" then return "Neutral" end
	if score ~= 0 then return nil end
	return mine and "Full" or "Zero"
end

-- applies the pick's points; returns stat, change, mine (my own side's pick), down (an off-side drop lost a rank)
local function applyScore(player, option)
	local f = sideOf(player)
	if not f then return "None", 0, false end
	local stat = f == "Halo" and "Honor" or "Infamy"
	if (f == "Halo") == (SIDE[option] == "Good") then
		local got = S.ScoreBudget.Take(player, points())
		if got > 0 then S.PlayerService.AddStat(player, stat, got) end
		return stat, got, true
	end
	local data = S.PlayerService.GetData(player)
	local have = math.max(0, math.floor(num(data and data[stat])))
	local take = math.min(have, points())
	local down = false
	if take > 0 then
		S.PlayerService.SetStat(player, stat, have - take)
		local function rank(score)
			local _, r = Config.GetTitle(f, f == "Halo" and score or 0, f == "Horns" and score or 0)
			return r
		end
		down = rank(have - take) < rank(have)
	end
	return stat, -take, false, down
end

-- the gift: Help = Jelly (what does not fit is paid at its sell price), Tickle = gold. Returns items, gold to pay
local function gift(player, option)
	if option ~= "Help" then return 0, math.max(0, math.floor(num(F.Tickle.Gold))) end
	local id, n = F.Help.Item, math.max(0, math.floor(num(F.Help.N)))
	local given = 0
	local ok, res = pcall(S.LootService.GrantItem, player, id, n)
	if ok then
		given = math.clamp(math.floor(num(res)), 0, n)
	else
		Util.Warn(TAG, "GrantItem: " .. tostring(res))
	end
	local item = Config.Loot.Items[id]
	return given, (n - given) * math.max(0, math.floor(num(item and item.Sell)))
end

local function metric(player, pick)
	local T = S.TelemetryService
	if type(T) ~= "table" or type(T.Custom) ~= "function" then return end
	local f = player:GetAttribute("Faction")
	local ok, err = pcall(T.Custom, player, "FinisherPick", 1, METRIC[pick] or "None", type(f) == "string" and f or "None")
	if not ok then Util.Warn(TAG, "metric: " .. tostring(err)) end
end

-- closes the card: option = "Help" | "Tickle", nil = not picked (time up / left)
local function finish(player, card, option)
	if CARD.Open[player] ~= card then return end
	CARD.Open[player] = nil
	local out = { Id = card.Id, Pick = option or "None", Stat = "None", Score = 0, Item = F.Help.Item, N = 0, Gold = 0 }
	if option then
		local n, gold = gift(player, option)
		if gold > 0 then
			local added = S.ProgressionService.AddBankGold(player, gold, "Finisher")
			gold = type(added) == "number" and added or gold -- A23-75 returns what was added ("Finisher": never 2x)
		end
		out.N, out.Gold = n, gold
		local stat, change, mine, down = applyScore(player, option)
		out.Stat, out.Score = stat, change
		local parts = { option == "Help" and TXT.HelpDone or TXT.TickleDone }
		local item = Config.Loot.Items[F.Help.Item]
		if n > 0 then
			table.insert(parts, n > 1 and string.format(Config.Loot.Text.GotN, item and item.Name or F.Help.Item, n)
				or string.format(Config.Loot.Text.Got, item and item.Name or F.Help.Item))
		end
		if gold > 0 then table.insert(parts, string.format(STORY.ChoiceGold, Util.FormatNumber(gold))) end
		if change > 0 then table.insert(parts, string.format(TXT.Score, stat, change)) end
		notify(player, table.concat(parts, " · "), "reward", "None") -- the pick's own sound is the client's (FinisherEnd)
		if stat ~= "None" and not mine then
			local f = sideOf(player)
			if change < 0 then
				notify(player, string.format(f == "Halo" and STORY.OffSideHalo or STORY.OffSideHorns, -change), "info")
			else
				-- as a story pick at the A23-58 floor: the guide's line, then the shard leans (3rd idea round #5)
				notify(player, (f == "Halo" and STORY.OffSideHaloZero or STORY.OffSideHornsZero) .. " "
					.. (SIDE[option] == "Good" and STORY.LeanGood or STORY.LeanEvil), "info")
			end
			if down then notify(player, f == "Halo" and STORY.RankDownHalo or STORY.RankDownHorns, "info") end
		elseif mine and change <= 0 and points() > 0 then
			notify(player, TXT.HintFull, "info")
		end
	end
	if player.Parent == Players then fx(player, "FinisherEnd", out) end
	metric(player, option)
	FinisherService.Picked:Fire(player, out.Pick, card.Kind)
end

-- opens a card for this player (false = one is open already / not here)
local function offer(player, kind)
	if CARD.Open[player] or player.Parent ~= Players then return false end
	local id = (CARD.Serial[player] or 0) + 1
	CARD.Serial[player] = id
	local seconds = math.max(1, num(F.Seconds, 10))
	local card = { Id = id, Kind = kind, Ends = os.clock() + seconds }
	CARD.Open[player] = card
	local stat, help, helpMine = scoreOf(player, "Help")
	local _, tickle, tickleMine = scoreOf(player, "Tickle")
	fx(player, "FinisherCard", { Id = id, Kind = kind, Seconds = seconds, Stat = stat,
		Help = { Item = F.Help.Item, N = F.Help.N, Score = help, Hint = hintOf(stat, help, helpMine) },
		Tickle = { Gold = F.Tickle.Gold, Score = tickle, Hint = hintOf(stat, tickle, tickleMine) } })
	task.delay(seconds + math.max(0, num(F.Grace, 1)), function()
		finish(player, card, nil)
	end)
	return true
end

local function onKilled(player, info)
	if type(info) ~= "table" or info.Manual ~= true then return end
	if type(info.Kind) ~= "string" or type(F.Kinds) ~= "table" or F.Kinds[info.Kind] ~= true then return end
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	offer(player, info.Kind)
end

local function onPick(player, id, option, ...)
	if select("#", ...) ~= 0 then return end
	if type(id) ~= "number" or id ~= id or (option ~= "Help" and option ~= "Tickle") then return end
	if not Util.RateLimit(player, "FinisherPick", num(Config.RateLimits.FinisherPick, 0.3)) then return end
	local card = CARD.Open[player]
	if not card or card.Id ~= id then return end
	if os.clock() > card.Ends + math.max(0, num(F.Grace, 1)) then return end -- the timer ends it as "None"
	finish(player, card, option)
end

-- Studio test aid (Main.server DebugCommand "Finisher"): a card without a kill (the King Slime's)
function FinisherService.DebugOffer(player)
	return offer(player, F.Kinds.SlimeKing and "SlimeKing" or next(F.Kinds) or "SlimeKing")
end

function FinisherService.Init(services)
	S = services
end

function FinisherService.Start()
	S.MonsterService.MonsterKilled:Connect(function(player, info)
		local ok, err = pcall(onKilled, player, info)
		if not ok then Util.Warn(TAG, "kill: " .. tostring(err)) end
	end)
	Net.Get("FinisherPick").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onPick, player, ...)
		if not ok then Util.Warn(TAG, "pick: " .. tostring(err)) end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local card = CARD.Open[player]
		if card then
			local ok, err = pcall(finish, player, card, nil)
			if not ok then Util.Warn(TAG, "leave: " .. tostring(err)) end
		end
		CARD.Open[player], CARD.Serial[player] = nil, nil
	end)
end

return FinisherService
