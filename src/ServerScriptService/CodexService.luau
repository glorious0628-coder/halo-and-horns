-- CodexService.luau : A23-153 the monster codex (게임성 개발 2, 2026-10-13). Design docs/design/codex_cards_2026-10-12.md,
-- screen contract docs/design/codex_cards_contract_2026-10-13.md, numbers / text Config.Codex.
-- Every kill KillLog counts (MonsterService.MonsterKilled, never a personal monster) of a series-1 kind (Config.Codex.Pages)
-- adds one to the save's Codex[kind].Kills, a golden one to Golden too. Reaching a stage (Config.CodexStage: 1 / 100 / 1000)
-- and the first golden kill of a kind (its Gold Foil card) each pay a small reward (Config.Codex.Reward x the kind's own
-- MonsterTypes XP / Gold, bank gold "Codex") and tell the owner (s->c "CodexUp"; plus a toast while Config.Codex.ServerToast).
-- A page whose every kind has a card gives its title (TitleService.Grant); every card at Stage 3 = the attribute CodexGlow
-- (a cosmetic shown by the client, never a stat). The owner gets the whole codex (s->c "Codex") at join and on c->s
-- "CodexOpen" (no arguments, rate-limited). Cards a save made before the codex come from DataService's v5 step (no reward).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local CodexService = {}

local TAG = "CodexService"
local S = nil
local X = Config.Codex
local STAGE_EVENT = { "Card", "Silver", "Holo" } -- CodexUp Event per stage reached (the line: Config.Codex.Text[Event])
local EVENTS = { Card = true, Silver = true, Holo = true, Golden = true, Page = true, Glow = true } -- every CodexUp Event

local function codexOf(data)
	if type(data.Codex) ~= "table" then data.Codex = {} end
	return data.Codex
end

local function cardsOwned(codex)
	local n = 0
	for _, kind in X.Order do
		local e = codex[kind]
		if type(e) == "table" and (tonumber(e.Stage) or 0) >= 1 then n += 1 end
	end
	return n
end

-- every series-1 card at Stage 3
local function allHolo(codex)
	for _, kind in X.Order do
		local e = codex[kind]
		if type(e) ~= "table" or (tonumber(e.Stage) or 0) < 3 then return false end
	end
	return true
end

local function pageDone(codex, page)
	for _, kind in page.Kinds do
		local e = codex[kind]
		if type(e) ~= "table" or (tonumber(e.Stage) or 0) < 1 then return false end
	end
	return true
end

local function snapshot(codex)
	local cards = {}
	for _, kind in X.Order do
		local e = codex[kind]
		if type(e) == "table" then
			cards[kind] = { Kills = e.Kills, Golden = e.Golden, Stage = e.Stage, First = e.First }
		end
	end
	return { V = 1, Cards = cards, Glow = allHolo(codex) }
end

local function publish(player, codex)
	player:SetAttribute(X.Attr.Cards, cardsOwned(codex))
	player:SetAttribute(X.Attr.Glow, allHolo(codex))
end

local function send(player, codex)
	Net.Get("Codex"):FireClient(player, snapshot(codex))
end

local function shortName(kind)
	local def = Config.MonsterTypes[kind]
	return type(def) == "table" and (def.Short or def.Name) or kind
end

-- the reward of `mult` kills' worth of `kind` (its own XP / Gold, no golden x): bank gold "Codex" + XP (the passes apply).
-- 최종 검수 review 2026-10-13: below the kind's XPCapBelowLevel the XP is at most one level's (A23-27, the kill's own cap:
-- ProgressionService.onMonsterKilled). Returns the gold and XP really added.
local function pay(player, kind, mult)
	local def = Config.MonsterTypes[kind]
	mult = tonumber(mult) or 0
	local gold = math.floor((tonumber(def.Gold) or 0) * mult + 0.5)
	local xp = math.floor((tonumber(def.XP) or 0) * mult + 0.5)
	local cap = nil
	local capBelow = tonumber(def.XPCapBelowLevel)
	if capBelow then
		local data = S.PlayerService.GetData(player)
		local level = math.floor(type(data) == "table" and tonumber(data.Level) or 1)
		if level < capBelow then cap = math.floor(Config.XPToNext(level)) end
	end
	local gotGold, gotXP = 0, 0
	if gold > 0 then
		local ok, got = pcall(S.ProgressionService.AddBankGold, player, gold, "Codex")
		if ok then gotGold = tonumber(got) or gold else Util.Warn(TAG, "gold: " .. tostring(got)) end
	end
	if xp > 0 then
		local ok, got = pcall(S.ProgressionService.AddXP, player, xp, cap)
		if ok then gotXP = tonumber(got) or xp else Util.Warn(TAG, "xp: " .. tostring(got)) end
	end
	return gotGold, gotXP
end

-- one CodexUp to the owner (+ the toast while ServerToast). ev = { Event, Kind?, Stage?, Card?, Gold?, XP?, Title?, Page?,
-- Args = the line's %s values }; Key / Text are filled here (Text = the English line incl. the reward part)
local function up(player, ev)
	local key = "Config.Codex.Text." .. ev.Event
	local text = string.format(X.Text[ev.Event], table.unpack(ev.Args or {}))
	if (ev.Gold or 0) > 0 or (ev.XP or 0) > 0 then
		local reward = (ev.XP or 0) > 0 and string.format(X.Text.Reward, Util.FormatInt(ev.Gold or 0), Util.FormatInt(ev.XP))
			or string.format(X.Text.RewardGold, Util.FormatInt(ev.Gold or 0))
		text ..= " " .. reward
	end
	ev.Key, ev.Text = key, text
	Net.Get("CodexUp"):FireClient(player, ev)
	if X.ServerToast then Net.Notify(player, text, "reward") end
end

local function onKilled(player, info)
	if X.Enabled ~= true or type(info) ~= "table" or info.Personal == true then return end
	local kind = info.Kind
	if type(kind) ~= "string" or not X.PageOf[kind] or not Config.MonsterTypes[kind] then return end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	local codex = codexOf(data)
	local e = codex[kind]
	if type(e) ~= "table" then
		e = { Kills = 0, Golden = 0, Stage = 0, First = os.time() }
		codex[kind] = e
	end
	local before = e.Stage
	e.Kills = math.min(X.MaxKills, e.Kills + 1)
	local events = {}
	local reach = Config.CodexStage(kind, e.Kills)
	local boss = Config.MonsterTypes[kind].Boss == true
	while e.Stage < reach and e.Stage < 3 do
		e.Stage += 1
		local mults = boss and X.Reward.BossStage or X.Reward.Stage
		table.insert(events, { Event = STAGE_EVENT[e.Stage], Stage = e.Stage, Mult = mults[e.Stage] })
	end
	if info.Golden == true and Config.CodexCanGold(kind) then
		e.Golden = math.min(e.Kills, e.Golden + 1)
		if e.Golden == 1 then table.insert(events, { Event = "Golden", Stage = e.Stage, Mult = X.Reward.Golden }) end
	end
	-- 최종 검수 review 2026-10-13: a free rider's minor share (info.Minor: the hits, under the boss's damage share) counts
	-- like KillLog, but a stage it reaches pays only MinorShare of the reward (none without one), like its XP / gold
	local share = 1
	if info.Minor == true then share = math.clamp(tonumber(Config.MonsterTypes[kind].MinorShare) or 0, 0, 1) end
	for _, ev in events do
		local gold, xp = pay(player, kind, ev.Mult * share)
		up(player, { Event = ev.Event, Kind = kind, Stage = ev.Stage, Gold = gold, XP = xp, Args = { shortName(kind) },
			Card = { Kills = e.Kills, Golden = e.Golden, Stage = e.Stage, First = e.First } })
	end
	if e.Stage == before then return end
	publish(player, codex)
	-- a new card can finish its page (the title); a new Gold Holo can finish the whole codex (the glow)
	local page = X.Pages[X.PageOf[kind]]
	if before < 1 and page and pageDone(codex, page) and S.TitleService and Config.TitleDefs[page.Title] then
		local ok, new = pcall(S.TitleService.Grant, player, page.Title)
		if not ok then
			Util.Warn(TAG, "title: " .. tostring(new))
		elseif new == true then
			local zone = Config.Zones[page.Id]
			up(player, { Event = "Page", Page = page.Id, Title = page.Title,
				Args = { type(zone) == "table" and zone.Name or page.Id, Config.TitleDefs[page.Title].Name } })
		end
	end
	if before < 3 and e.Stage >= 3 and allHolo(codex) then
		up(player, { Event = "Glow" })
	end
end

-- join: repair (an offline / hand-made record), titles of full pages (silent: a v5 step may have filled them), attributes,
-- the snapshot
local function onReady(player, data)
	if type(data) ~= "table" then return end
	data.Codex = Config.SanitizeCodex(data.Codex)
	if S.TitleService then
		for _, page in X.Pages do
			if pageDone(data.Codex, page) and Config.TitleDefs[page.Title] then
				local ok, err = pcall(S.TitleService.Grant, player, page.Title)
				if not ok then Util.Warn(TAG, "title: " .. tostring(err)) end
			end
		end
	end
	publish(player, data.Codex)
	send(player, data.Codex)
end

local function onOpen(player)
	if not S.PlayerService.IsReady(player) or not Util.RateLimit(player, "CodexOpen", Config.RateLimits.CodexOpen) then return end
	local data = S.PlayerService.GetData(player)
	if type(data) == "table" then send(player, codexOf(data)) end
end

-- Studio test aid (Main DebugCommand "Codex"): "reset" (no cards), "<Kind>:<kills>" (that card's kills, its stage from them,
-- no reward), "show:<Kind>:<Event>" (one CodexUp with no reward and no change: the card moment again)
function CodexService.Debug(player, value)
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return "no data" end
	local v = tostring(value)
	if v == "reset" then
		data.Codex = {}
	else
		local showKind, event = string.match(v, "^show:(%w+):(%a+)$")
		if showKind then
			if not X.PageOf[showKind] or not EVENTS[event] then return "unknown kind or event" end
			local e = codexOf(data)[showKind] or { Kills = 0, Golden = 0, Stage = 0, First = 0 }
			local args = { shortName(showKind) }
			if event == "Page" then
				local page = X.Pages[X.PageOf[showKind]]
				args = { Config.Zones[page.Id] and Config.Zones[page.Id].Name or page.Id, Config.TitleDefs[page.Title].Name }
			end
			up(player, { Event = event, Kind = showKind, Stage = e.Stage, Gold = 0, XP = 0, Args = args, Debug = true,
				Card = { Kills = e.Kills, Golden = e.Golden, Stage = e.Stage, First = e.First } })
			return "ok"
		end
		local kind, n = string.match(v, "^(%w+):(%d+)$")
		if not kind or not X.PageOf[kind] then return 'use "reset", "<Kind>:<kills>" or "show:<Kind>:<Event>"' end
		local kills = math.min(X.MaxKills, tonumber(n) or 0)
		local codex = codexOf(data)
		if kills < 1 then
			codex[kind] = nil
		else
			local old = codex[kind]
			codex[kind] = { Kills = kills, Golden = old and math.min(old.Golden, kills) or 0, Stage = Config.CodexStage(kind, kills),
				First = old and old.First or os.time() }
		end
	end
	publish(player, codexOf(data))
	send(player, codexOf(data))
	return "ok"
end

function CodexService.Init(registry)
	S = registry
end

function CodexService.Start()
	S.MonsterService.MonsterKilled:Connect(function(player, info)
		local ok, err = pcall(onKilled, player, info)
		if not ok then Util.Warn(TAG, "kill: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		local ok, err = pcall(onReady, player, data)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	Net.Get("CodexOpen").OnServerEvent:Connect(function(player)
		local ok, err = pcall(onOpen, player)
		if not ok then Util.Warn(TAG, "open: " .. tostring(err)) end
	end)
	print("[CodexService] started")
end

return CodexService
