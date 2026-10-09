-- ChoiceCard.luau : A23-86 CC - the shared "choose a side" card (게임성 개발 3, 2026-10-09; contract
-- docs/design/choice_card_server_2026-10-09.md, content_beyond_10min §3 CC). A card only this player sees, with a Good
-- and an Evil option of the same size and a FIXED reward (no draw). Cards come from data: Config.ChoiceCard.Kinds[kind]
-- = { Title, Seconds?, Good = { Label, Done?, Reward = { Item? Potion? N? Gold? }, Points? }, Evil = { ... } }.
--   * Saved cards (no Seconds): one waits for the player (data.Cards.Pending = { Id, Kind, Ctx }), no time limit, and
--     comes back at the next join. Timed cards (Seconds, e.g. the King Slime finisher) are not saved; time up = "None".
--   * One open card a player at a time: Offer answers false while one is open (the caller may try again later).
--   * Points go through the daily ledger (Deeds.Add: 6 a day, +1 own side / -1 other side, 0 floor); the reward keeps
--     coming when the day is full. Gold is source "Choice" (never 2x). Items that do not fit the bag are paid at their
--     sell price. Nothing here is sold; no purchase prompt belongs near the card (A23-79).
--   * Every pick is counted: data.Story.N[kind][side] (My Way reads it later with its own weight).
-- Net: s->c Fx "Card" { Id, Kind, Title, Seconds?, Stat, Good = { Label, Item?, Potion?, N?, Gold?, Score, Hint? }, Evil = ... }
--      s->c Fx "CardEnd" { Id, Kind, Side ("Good" | "Evil" | "None"), Stat, Score, Item?, N, Gold, Full }
--      c->s "CardAction" (id: number, side: "Good" | "Evil"): only the open card, its Id, once, in time.
-- Hint = "Neutral" (no side: the reward only) | "Full" (my side, today's points used up) | "Zero" (the other side,
-- nothing to lose) | nil (the Score says it). Signal ChoiceCard.Picked(player, kind, side, result).
-- API: ChoiceCard.Offer(player, kind, ctx?) -> true | false, reason ; ChoiceCard.Pending(player) -> kind | nil
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local ChoiceCard = {}
ChoiceCard.Picked = Util.Signal.new() -- (player, kind, side, result)

local TAG = "ChoiceCard"
local S = nil
local CC = Config.ChoiceCard or {}
local TXT = CC.Text or {}
local STORY = Config.StoryQuests.Text
-- OPEN[player] = { Id, Kind, Ctx, Ends? } the open card (saved or timed)
local OPEN = {}
local SIDES = { Good = true, Evil = true }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function notify(player, text, kind, sound)
	local ok, err = pcall(Net.Notify, player, text, kind, nil, sound)
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

local function fx(player, kind, payload)
	local ok, err = pcall(Net.Fx, player, kind, payload)
	if not ok then Util.Warn(TAG, kind .. ": " .. tostring(err)) end
end

local function def(kind)
	local kinds = CC.Kinds
	local d = type(kinds) == "table" and kinds[kind] or nil
	if type(d) ~= "table" or type(d.Good) ~= "table" or type(d.Evil) ~= "table" then return nil end
	return d
end

------------------------------------------------------------------ save
-- data.Cards = { Serial, Pending = { Id, Kind, Ctx } | nil }; repaired in place
local function record(data)
	if type(data.Cards) ~= "table" then data.Cards = {} end
	local c = data.Cards
	c.Serial = math.max(0, math.floor(num(c.Serial)))
	local p = c.Pending
	if p ~= nil then
		local d = type(p) == "table" and type(p.Kind) == "string" and def(p.Kind) or nil
		if not d or d.Seconds ~= nil then
			c.Pending = nil
		else
			p.Id = math.max(1, math.floor(num(p.Id, c.Serial)))
			if p.Id > c.Serial then c.Serial = p.Id end
			if type(p.Ctx) ~= "table" then p.Ctx = {} end
		end
	end
	return c
end

local function count(data, kind, side)
	if type(data.Story) ~= "table" then data.Story = {} end
	local st = data.Story
	if type(st.N) ~= "table" then st.N = {} end
	if type(st.N[kind]) ~= "table" then st.N[kind] = {} end
	st.N[kind][side] = math.min(1000000, math.max(0, math.floor(num(st.N[kind][side]))) + 1)
end

------------------------------------------------------------------ the card
-- one option as the screen shows it
local function optionView(player, d, side)
	local o = d[side]
	local r = type(o.Reward) == "table" and o.Reward or {}
	local stat, score, mine = S.Deeds.Preview(player, side, o.Points)
	local hint = nil
	if stat == "None" then hint = "Neutral" elseif score == 0 then hint = mine and "Full" or "Zero" end
	return { Label = o.Label, Item = r.Item, Potion = r.Potion, N = r.N, Gold = r.Gold, XP = r.XP, Score = score, Hint = hint },
		stat
end

local function send(player, card)
	local d = def(card.Kind)
	if not d then return end
	local good, stat = optionView(player, d, "Good")
	local evil = optionView(player, d, "Evil")
	fx(player, "Card", { Id = card.Id, Kind = card.Kind, Title = d.Title, Seconds = d.Seconds, Stat = stat,
		Good = good, Evil = evil })
end

-- the reward: items through LootService (a full bag pays the rest at its sell price), gold to the bank. Returns the
-- number of items given, the gold added, the item id
local function pay(player, reward)
	local r = type(reward) == "table" and reward or {}
	local id = r.Item or r.Potion
	local given, gold = 0, math.max(0, math.floor(num(r.Gold)))
	if type(id) == "string" then
		local want = math.max(0, math.floor(num(r.N, 1)))
		local ok, res = pcall(S.LootService.GrantItem, player, id, want)
		if ok then
			given = math.clamp(math.floor(num(res)), 0, want)
		else
			Util.Warn(TAG, "GrantItem: " .. tostring(res))
		end
		local item = Config.Loot.Items[id]
		gold += (want - given) * math.max(0, math.floor(num(item and item.Sell)))
	end
	if gold > 0 then
		local ok, added = pcall(S.ProgressionService.AddBankGold, player, gold, "Choice")
		if ok then
			gold = type(added) == "number" and added or gold
		else
			Util.Warn(TAG, "gold: " .. tostring(added))
			gold = 0
		end
	end
	-- A23-87 (게임성 개발 2, 검수 2026-10-09): Reward.XP, never doubled by the 2x XP pass (a choice's reward stays the
	-- same size for everyone): AddXP's cap = the amount itself, applied after the pass
	local xp = math.max(0, math.floor(num(r.XP)))
	if xp > 0 then
		local ok, added = pcall(S.ProgressionService.AddXP, player, xp, xp)
		if ok then
			xp = type(added) == "number" and added or xp
		else
			Util.Warn(TAG, "xp: " .. tostring(added))
			xp = 0
		end
	end
	return given, gold, id, xp
end

local function itemName(id)
	local item = Config.Loot.Items[id]
	return (item and item.Name) or (Config.Loot.Text.Potion and Config.Loot.Text.Potion[id]) or id
end

-- closes the card: side = "Good" | "Evil", nil = not picked (time up)
local function finish(player, card, side)
	if OPEN[player] ~= card then return end
	OPEN[player] = nil
	local data = S.PlayerService.GetData(player)
	if data then
		local c = record(data)
		if c.Pending and c.Pending.Id == card.Id then c.Pending = nil end -- committed before anything is paid
	end
	local out = { Id = card.Id, Kind = card.Kind, Side = side or "None", Stat = "None", Score = 0, N = 0, Gold = 0, Full = false }
	local d = def(card.Kind)
	if side and d and data then
		local o = d[side]
		local given, gold, id, xp = pay(player, o.Reward)
		out.Item, out.N, out.Gold, out.XP = id, given, gold, xp
		local stat, change, mine, down, full = S.Deeds.Add(player, side, o.Points)
		out.Stat, out.Score, out.Full = stat, change, full
		count(data, card.Kind, side)
		local parts = { o.Done or (side == "Good" and TXT.GoodDone or TXT.EvilDone) }
		if given > 0 then
			table.insert(parts, given > 1 and string.format(Config.Loot.Text.GotN, itemName(id), given)
				or string.format(Config.Loot.Text.Got, itemName(id)))
		end
		if gold > 0 then table.insert(parts, string.format(STORY.ChoiceGold, Util.FormatNumber(gold))) end
		if xp > 0 then table.insert(parts, string.format(TXT.XP or "+%s XP", Util.FormatNumber(xp))) end
		if change > 0 then table.insert(parts, string.format(TXT.Score, stat, change)) end
		notify(player, table.concat(parts, " · "), "reward", "None")
		local f = player:GetAttribute("Faction")
		if stat ~= "None" and not mine then
			if change < 0 then
				notify(player, string.format(f == "Halo" and STORY.OffSideHalo or STORY.OffSideHorns, -change), "info")
			else
				notify(player, (f == "Halo" and STORY.OffSideHaloZero or STORY.OffSideHornsZero) .. " "
					.. (side == "Good" and STORY.LeanGood or STORY.LeanEvil), "info")
			end
			if down then notify(player, f == "Halo" and STORY.RankDownHalo or STORY.RankDownHorns, "info") end
		elseif mine and full then
			notify(player, TXT.Full, "info")
		end
	end
	if player.Parent == Players then fx(player, "CardEnd", out) end
	ChoiceCard.Picked:Fire(player, card.Kind, out.Side, out)
end

function ChoiceCard.Pending(player)
	local card = OPEN[player]
	return card and card.Kind or nil
end

-- opens a card of `kind` for the player. ctx = a small table of numbers / strings kept with a saved card. false, reason
function ChoiceCard.Offer(player, kind, ctx)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return false, "gone" end
	local d = type(kind) == "string" and def(kind) or nil
	if not d then return false, "kind" end
	if OPEN[player] then return false, "open" end
	local data = S.PlayerService.GetData(player)
	if not data or not S.PlayerService.IsReady(player) then return false, "notready" end
	local c = record(data)
	c.Serial += 1
	local id = c.Serial
	local card = { Id = id, Kind = kind, Ctx = type(ctx) == "table" and ctx or {} }
	OPEN[player] = card
	if d.Seconds ~= nil then
		local seconds = math.max(1, num(d.Seconds))
		card.Ends = os.clock() + seconds
		task.delay(seconds + math.max(0, num(CC.Grace, 1)), function() finish(player, card, nil) end)
	else
		c.Pending = { Id = id, Kind = kind, Ctx = card.Ctx }
	end
	send(player, card)
	return true
end

local function onAction(player, ...)
	if select("#", ...) ~= 2 then return end
	local id, side = ...
	if type(id) ~= "number" or id ~= id or type(side) ~= "string" or SIDES[side] ~= true then return end
	if not Util.RateLimit(player, "CardAction", num(Config.RateLimits.CardAction, 0.3)) then return end
	local card = OPEN[player]
	if not card or card.Id ~= id then return end
	if card.Ends and os.clock() > card.Ends + math.max(0, num(CC.Grace, 1)) then return end
	finish(player, card, side)
end

local function onReady(player, data)
	local c = record(data)
	local p = c.Pending
	if p and not OPEN[player] then
		OPEN[player] = { Id = p.Id, Kind = p.Kind, Ctx = p.Ctx }
		send(player, OPEN[player]) -- a saved card waits for the player
	end
end

function ChoiceCard.Init(registry)
	S = registry
end

function ChoiceCard.Start()
	Net.Get("CardAction").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onAction, player, ...)
		if not ok then Util.Warn(TAG, "CardAction: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		local ok, err = pcall(onReady, player, data)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(player)
		local card = OPEN[player]
		if card and card.Ends then pcall(finish, player, card, nil) end -- a timed card ends; a saved one stays saved
		OPEN[player] = nil
	end)
	print("[ChoiceCard] started")
end

return ChoiceCard
