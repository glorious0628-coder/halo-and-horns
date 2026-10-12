-- RankingService.luau : BB10 weekly rankings and the ONE weekly settle of A23-22 / A23-23 / A23-24 (server only).
-- Plan + 검수 decisions D1-D6: docs/design/ranking_service_plan_2026-10-06.md; contract: beta_basics BB10 (2026-10-06 notes).
--
-- Boards (Config.Ranking.Order), weekly from Monday 00:00 KST (Config.WeekIndex):
--   Honor (Halo) / Infamy (Horns): fair PvP points only (PvPService -> PlayerService.GrantFame -> CreditFame; D1)
--   Artisan (Neutral): scroll enhance gains with scrolls my own kills dropped while in the guild (A23-24)
--   PvP (every faction): +1 per unfair KO (JudgeKO), the "무단 PvP" board whose top 3 become next week's outlaws
-- Points live in data.Rank (week fields, Config.SanitizeRank) and in one OrderedDataStore per season / board / week:
-- HH_Rank_<season>_<board>_W<week>, key U_<userId>, value = score*100 + hidden*10 + factionCode. The season is
-- "STUDIO" in Studio / memory mode, so Studio play never touches PRE / B1 rows.
-- Weekly settle (TickSettle): 10 min after Monday 00:00 KST the first server that finds no settle document reads last
-- week's top 3 per board and stores them once (HH_RankSettle_<season>, key W<week>, first writer wins); every server
-- applies that same document: data.RankReward / data.Outlaw = { WeekId = this week, Season } (idempotent). Failing board
-- reads retry every SettleRetrySeconds; after SettleGiveUpSeconds the server stores { Skipped = true } instead, also
-- first-writer-wins, so every server applies the same decision (D4). Nothing is applied while the store is unreachable.
-- Points, rewards and outlaw weeks carry their season: a Studio test (STUDIO) never acts on a live server and back.
-- Effects are published as attributes the other services read: Outlaw (bool), RankReward ("" or the board id, only
-- while in that board's faction), RankRewardRank, Week<board> (this week's points).
-- Remote c->s "RequestRankings"(board, "Server" | "Global") -> owner-only "Rankings" from the server cache only.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local RankingService = {}
-- (player, board, scope) BB38 metrics: a ranking board the player asked for (RequestRankings answered)
RankingService.Viewed = Util.Signal.new()
local S = nil
local TAG = "RankingService"
local R = Config.Ranking
local TXT = R.Text

-- per-server state. Player keys are dropped when the leave write finished; the tables are weak-keyed so a write still
-- running when a player leaves can never keep the Player alive.
local function weak() return setmetatable({}, { __mode = "k" }) end
local ST = {
	Dirty = weak(), -- [Player] = true: this week's rows changed since the last write
	Force = weak(), -- [Player] = true: write at the next loop step whatever WriteEverySeconds says
	LastWrite = weak(), -- [Player] = os.clock()
	Pending = weak(), -- [Player] = last week's snapshot still to write to last week's stores (week flip while online)
	LastWeek = weak(), -- [Player] = last week's snapshot (kept for the STUDIO settle from this server's board)
	HideQueue = weak(), -- [Player] = true until every row carries the new hidden flag (then Rank.HideSynced)
	Gen = weak(), -- [Player] = n, +1 on every change a write must carry (a change during a yielding write is not lost)
	Writing = weak(), -- [Player] = true while writePlayer runs (the leave write waits for it)
	Leaving = 0, -- leave writes still running (PlayerService's BindToClose waits for them)
	-- [userId] = { [store] = value last written by this server in the player's CURRENT session (false = removed) };
	-- cleared at join and after the leave write: another server may have written the rows in between
	Written = {},
	Cache = {}, -- [board] = { WeekId, Rows = { { UserId, Value, Hidden, Faction } }, UpdatedAt }
	Names = {}, -- [userId] = { Name, At }
	Friends = {}, -- ["<lo>:<hi>"] = bool (successful IsFriendsWith calls only)
	Asking = {}, -- ["<lo>:<hi>"] = true while a background IsFriendsWith runs
	Settled = {}, -- [weekId] = the applied settle document of that week ({ Skipped = true } after D4's give-up)
	SettleFirstFail = {}, -- [weekId] = os.time() of the first failed attempt
	SettleNextTry = 0,
	ReadNext = {}, -- [board] = os.clock() of the next global read
	WarnAt = {}, -- [key] = os.clock() of the last throttled warning
	SeenOutlaw = weak(), -- [Player] = true once this server showed the player as an outlaw (for the OutlawEnd notice)
	OutlawToldAt = weak(), -- [Player] = os.clock() of the outlaw week's start line (RankingService.OutlawToldAt)
	-- the STUDIO season on a save whose ranking belongs to a live season (the working Studio uses the live saves):
	-- this session's points and results live here and are never saved, so a Studio test never touches live data
	Shadow = weak(), -- [Player] = the session's Rank table
	StudioResult = weak(), -- [Player] = { RankReward, Outlaw } of a Studio settle / DebugSettle
}
RankingService.Stats = { Reads = 0, Writes = 0, Skipped = 0, Refused = {}, Settles = 0, SettleSkipped = 0 }

-- an unfair KO (when no exemption covers it) adds 1 to the killer's PvP board: the A23-23 / plan §4 list (weak, idle,
-- new, 4th of the week, just respawned) + "Repeated" (3 KOs of one victim in 10 min, the A23-22 bully rule; 검수
-- 2026-10-06). One KO is one point whatever reasons overlap. YieldCap, WeekCap and Private are not fair either but count
-- on no board.
local UNFAIR = { Weak = true, Fresh = true, Repeated = true, Idle = true, Newbie = true, Repeat = true }
local KILLER_BOARD = { Halo = "Honor", Horns = "Infamy" } -- the board a fair KO by this faction scores on
local HAND = {} -- [Enh scroll id] = true (A23-24 장인 tags)
for _, id in R.HandScrollIds do
	HAND[id] = true
end
local REWARD_BOARDS = {} -- boards whose top 3 get the A23-22 reward (their timed titles)
for _, board in R.Order do
	if R.Boards[board].Reward then table.insert(REWARD_BOARDS, board) end
end

------------------------------------------------------------------ helpers
local function warnThrottled(key, msg)
	local now = os.clock()
	if now - (ST.WarnAt[key] or -math.huge) >= 30 then
		ST.WarnAt[key] = now
		Util.Warn(TAG, msg)
	end
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function week()
	return Config.WeekIndex(os.time())
end

local function factionOf(p)
	local f = p:GetAttribute("Faction")
	return type(f) == "string" and f or "None"
end

local function lastOwn(p)
	local PS = S.PlayerService
	local fn = PS.GetLastOwnActive or PS.GetLastActive
	local ok, t = pcall(fn, p)
	return ok and tonumber(t) or 0
end

local function refuse(reason)
	local s = RankingService.Stats.Refused
	s[reason] = (s[reason] or 0) + 1
end

local function budget(kind)
	local ok, n = pcall(function() return DataStoreService:GetRequestBudgetForRequestType(kind) end)
	return ok and tonumber(n) or 0
end

local function hiddenName(faction)
	local f = faction ~= "None" and Config.Factions[faction] or nil
	return f and string.format(Config.Announce.Text.HiddenName, f.Name) or Config.Announce.Text.Someone
end

local function publicName(p)
	local A = S.AnnounceService
	if A and A.PublicName then
		local ok, name = pcall(A.PublicName, p)
		if ok and type(name) == "string" then return name end
	end
	return p:GetAttribute("HideAnnounceName") == true and hiddenName(factionOf(p)) or Util.PlayerDisplayName(p)
end

-- "STUDIO" in Studio or DataStore memory mode (never PRE / B1 rows from a test), else Config.Ranking.Season
function RankingService.EffectiveSeason()
	local ds = S and S.DataService
	local memory = false
	if ds and ds.IsMemoryMode then
		local ok, m = pcall(ds.IsMemoryMode)
		memory = ok and m == true
	end
	if RunService:IsStudio() or memory then return "STUDIO" end
	return Config.StoreName(R.Season) -- Beta / Live: "<season>_Beta" / "<season>_Live" (the dev place keeps the season as it is)
end

function RankingService.StoreName(board, weekId)
	return R.StorePrefix .. RankingService.EffectiveSeason() .. "_" .. board .. "_W" .. tostring(weekId)
end

local function keyOf(userId)
	return "U_" .. tostring(userId)
end

local function userIdOf(key)
	return tonumber(string.match(tostring(key), "^U_(%-?%d+)$"))
end

function RankingService.Encode(score, hidden, faction)
	return math.max(0, math.floor(score)) * 100 + (hidden and 10 or 0) + (R.FactionCode[faction] or 0)
end

-- (score, hidden, faction)
function RankingService.Decode(value)
	local v = math.max(0, math.floor(tonumber(value) or 0))
	local code = v % 10
	local faction = "None"
	for id, c in R.FactionCode do
		if c == code then faction = id end
	end
	return math.floor(v / 100), math.floor(v / 10) % 10 == 1, faction
end

-- 검수 tie rule: rows ranked by the decoded score only (never the hidden bit or the faction code of the stored value),
-- competition ranks 1, 2, 2, 4; inside a tie the order is UserId (neutral). Sorts `rows` ({ UserId, Value }) in place
-- and sets each row's Rank.
local function rankRows(rows)
	table.sort(rows, function(a, b)
		if a.Value ~= b.Value then return a.Value > b.Value end
		return a.UserId < b.UserId
	end)
	for i, r in rows do
		r.Rank = (i > 1 and rows[i - 1].Value == r.Value) and rows[i - 1].Rank or i
	end
	return rows
end

-- the settle list of one board: everyone whose competition rank is within RewardTop (all tied with 3rd included) and
-- who has at least `min` points -> { userIds }, { ranks }
local function settleList(rows, min)
	local ids, ranks = {}, {}
	for _, r in rankRows(rows) do
		if r.Rank <= R.RewardTop and r.Value >= min then
			table.insert(ids, r.UserId)
			table.insert(ranks, r.Rank)
		end
	end
	return ids, ranks
end

-- this week's points on the attributes (HUD / Tab list fame / character window)
local function publish(p, rank)
	for _, board in R.Order do
		local v = rank[board] or 0
		if p:GetAttribute("Week" .. board) ~= v then p:SetAttribute("Week" .. board, v) end
	end
end

-- data.Rank for the current week and season. A player online across Monday 00:00 KST: last week's points are kept as
-- a snapshot for one more write to last week's stores, then the week fields start over (Config.SanitizeRank). Points of
-- another season (a Studio test on the live saves, or live points in Studio) are dropped, never written here.
-- faction: the faction the snapshot belongs to when the caller knows better (a FactionChanged handler: the old one).
local function liveSeason(s)
	return type(s) == "string" and s ~= "" and s ~= "STUDIO"
end

local function ensureWeek(p, data, faction)
	local rank = data.Rank
	local cur, season = week(), RankingService.EffectiveSeason()
	if season == "STUDIO" and type(rank) == "table" and liveSeason(rank.Season) then
		-- a Studio test on a live save: the live Rank stays untouched, this session counts in a shadow table
		local shadow = ST.Shadow[p]
		if not shadow or shadow.WeekId ~= cur then
			local tmp = { Rank = shadow }
			Config.SanitizeRank(tmp, os.time())
			shadow = tmp.Rank
			shadow.Season = season
			ST.Shadow[p] = shadow
			publish(p, shadow)
		end
		return shadow
	end
	if type(rank) == "table" and rank.WeekId == cur and rank.Season == season then return rank end
	if type(rank) == "table" and rank.Season == season and (tonumber(rank.WeekId) or 0) > 0 then
		local snap = { WeekId = rank.WeekId, Faction = faction or factionOf(p), Hidden = data.HideAnnounceName == true }
		for _, board in R.Order do
			snap[board] = tonumber(rank[board]) or 0
		end
		ST.Pending[p], ST.LastWeek[p] = snap, snap
	elseif type(rank) == "table" then
		rank.WeekId = 0 -- a Studio-born or older-season save on a live server: this week's fields start over
	end
	Config.SanitizeRank(data, os.time())
	data.Rank.Season = season
	publish(p, data.Rank)
	return data.Rank
end

-- a change the next write must carry
local function bump(p)
	ST.Gen[p] = (ST.Gen[p] or 0) + 1
	ST.Dirty[p] = true
end

-- global boards: accounts younger than MinAccountDays / less play than MinPlaySeconds, Tainted saves outside STUDIO and
-- ExcludeUserIds are shown on the server board only
local function eligible(p, data)
	if table.find(R.ExcludeUserIds, p.UserId) then return false, "Excluded" end
	local studio = RankingService.EffectiveSeason() == "STUDIO"
	if data.DebugTainted == true and not studio then return false, "Tainted" end
	if studio then return true end
	if (tonumber(p.AccountAge) or 0) < R.MinAccountDays or (tonumber(data.PlaytimeSeconds) or 0) < R.MinPlaySeconds then
		return false, "Ineligible"
	end
	return true
end

------------------------------------------------------------------ points
-- +n on this week's board. Counts nothing on a private / reserved server, for another faction's board, or past the
-- board's WeekCap. Returns true when the points landed.
function RankingService.Credit(player, board, n, _why)
	n = math.floor(tonumber(n) or 0)
	local def = R.Boards[board]
	if not def or n <= 0 or typeof(player) ~= "Instance" then return false end
	if game.PrivateServerId ~= "" then refuse("Private"); return false end
	if def.Faction and factionOf(player) ~= def.Faction then refuse("Faction"); return false end
	local data = getData(player)
	if not data then return false end
	local rank = ensureWeek(player, data)
	local cap = Config.WeekCapOf(board)
	local cur = rank[board] or 0
	if cap and cur >= cap then
		refuse("WeekCap")
		warnThrottled("cap:" .. board, ("%s reached the weekly %s cap %d"):format(player.Name, board, cap))
		return false
	end
	rank[board] = cap and math.min(cap, cur + n) or cur + n
	publish(player, rank)
	bump(player)
	return true
end

local function pairKey(a, b)
	return tostring(math.min(a.UserId, b.UserId)) .. ":" .. tostring(math.max(a.UserId, b.UserId))
end

-- friends never score on any board; a failed IsFriendsWith counts as friends (and is asked again next time).
-- noYield (a PlayerLeaving handler): only the cache answers, an unknown pair counts as friends (no points)
local function friends(a, b, noYield)
	local key = pairKey(a, b)
	local cached = ST.Friends[key]
	if cached ~= nil then return cached end
	if noYield then return true end
	local ok, res = pcall(function() return a:IsFriendsWith(b.UserId) end)
	if not ok then return true end
	ST.Friends[key] = res == true
	return res == true
end

-- CombatService's death pipeline calls this BEFORE PvPService.HandleKO changes anything: it waits (at most
-- FriendWaitSeconds, well under the respawn time) only for the background call the first hit already started, and
-- never asks Roblox itself. A pair still unknown counts as friends in JudgeKO (no board points).
function RankingService.ResolveFriends(a, b)
	if RankingService.EffectiveSeason() == "STUDIO" then return end
	if typeof(a) ~= "Instance" or typeof(b) ~= "Instance" or a == b then return end
	local key = pairKey(a, b)
	local t0 = os.clock()
	while ST.Friends[key] == nil and ST.Asking[key] and os.clock() - t0 < R.FriendWaitSeconds do
		task.wait(0.1)
	end
end

-- the first PvP hit between two players asks Roblox in the background (CombatService.PlayerDamaged), so the KO itself
-- never waits for a web call of its own
function RankingService.WarmFriends(a, b)
	if RankingService.EffectiveSeason() == "STUDIO" then return end -- friends never matter there
	if typeof(a) ~= "Instance" or typeof(b) ~= "Instance" or a == b then return end
	local key = pairKey(a, b)
	if ST.Friends[key] ~= nil or ST.Asking[key] then return end
	ST.Asking[key] = true
	task.spawn(function()
		friends(a, b)
		ST.Asking[key] = nil
	end)
end

-- BB10 PvPCreditOK: nil = a fair KO, else the first failing reason. facts from PvPService.HandleKO (Bold, Fresh,
-- Repeated). Studio season skips the victim's account age / playtime.
function RankingService.PvPCreditOK(killer, victim, facts)
	facts = type(facts) == "table" and facts or {}
	if game.PrivateServerId ~= "" then return "Private" end -- nothing counts there; the fair counters never move either
	if (tonumber(facts.Bold) or 1) < 1 then return "Weak" end
	if facts.Fresh == true then return "Fresh" end
	if facts.Repeated == true then return "Repeated" end
	local last = lastOwn(victim)
	if last <= 0 or os.clock() - last > R.VictimActiveSeconds then return "Idle" end
	local vdata = getData(victim)
	if RankingService.EffectiveSeason() ~= "STUDIO" and ((tonumber(victim.AccountAge) or 0) < R.PvPMinVictimAccountDays
		or (tonumber(vdata and vdata.PlaytimeSeconds) or 0) < R.PvPMinVictimPlaytime) then
		return "Newbie"
	end
	local kdata = getData(killer)
	if not kdata then return "NoData" end
	if (ensureWeek(killer, kdata).Victims["U" .. tostring(victim.UserId)] or 0) >= R.MaxCreditPerVictimPerWeek then
		return "Repeat"
	end
	if vdata then
		local vrank = ensureWeek(victim, vdata)
		if vrank.YieldDay == Config.DayIndex(os.time()) and vrank.YieldN >= R.MaxYieldPerVictimPerDay then return "YieldCap" end
	end
	-- a killer whose board is already at WeekCap: the point could not land, so it must not use up the fair counters
	local board = KILLER_BOARD[factionOf(killer)]
	local cap = board and Config.WeekCapOf(board)
	if cap and (ensureWeek(killer, kdata)[board] or 0) >= cap then return "WeekCap" end
	return nil
end

-- the ranking verdict of one PvP KO: { Fair, Reason?, Exempt?, Unfair? }. An unfair KO no exemption covers adds 1 to
-- the killer's PvP board here. Exempt (D2 / A23-23): revenge, Wanted / bully / outlaw / kaiju victims, a kaiju killer,
-- a thief carrying a grudge sack and self-defense never count as unfair.
function RankingService.JudgeKO(killer, victim, facts)
	facts = type(facts) == "table" and facts or {}
	local verdict = { Fair = false }
	if RankingService.EffectiveSeason() ~= "STUDIO" and friends(killer, victim, facts.NoYield == true) then
		verdict.Reason = "Friend"
		refuse("Friend")
		return verdict
	end
	local exempt = (facts.Revenge == true and "Revenge") or (facts.VictimWanted == true and "Wanted")
		or (facts.VictimBully == true and "Bully") or (facts.VictimOutlaw == true and "Outlaw")
		or (facts.VictimKaiju == true and "Kaiju") or (facts.KillerKaiju == true and "KillerKaiju")
		or (facts.VictimHadSack == true and "Sack") or (facts.Defense == true and "Defense") or nil
	local reason = RankingService.PvPCreditOK(killer, victim, facts)
	if reason == nil then
		verdict.Fair = true
		return verdict
	end
	refuse(reason)
	verdict.Reason, verdict.Exempt = reason, exempt
	if exempt == nil and UNFAIR[reason] then
		verdict.Unfair = reason
		RankingService.Credit(killer, "PvP", 1, reason)
	end
	return verdict
end

-- a fair point was really given: the killer's per-victim week count and the victim's daily yield go up
function RankingService.CommitFair(killer, victim)
	local kdata, vdata = getData(killer), getData(victim)
	if kdata then
		local list = ensureWeek(killer, kdata).Victims
		local key = "U" .. tostring(victim.UserId)
		if list[key] == nil then
			local n, lowKey, low = 0, nil, math.huge
			for k, c in list do
				n += 1
				if c < low then lowKey, low = k, c end
			end
			if n >= R.MaxVictimKeys and lowKey then list[lowKey] = nil end -- the save stays bounded
		end
		list[key] = math.min(99, (list[key] or 0) + 1)
	end
	if vdata then
		local rank = ensureWeek(victim, vdata)
		local today = Config.DayIndex(os.time())
		if rank.YieldDay ~= today then rank.YieldDay, rank.YieldN = today, 0 end
		rank.YieldN = math.min(99, rank.YieldN + 1)
	end
end

-- PlayerService.GrantFame: ctx.RankPoints (a paid grudge sack) credits exactly that; ctx.PvP credits n only when
-- ctx.Fair (then the fair counters go up); no ctx / anything else (story, goose) never reaches a board (D1)
function RankingService.CreditFame(player, stat, n, ctx)
	if type(ctx) ~= "table" then return false end
	local board = (stat == "Honor" and "Honor") or (stat == "Infamy" and "Infamy") or nil
	if not board then return false end
	if ctx.RankPoints ~= nil then
		return RankingService.Credit(player, board, ctx.RankPoints, "Sack")
	end
	if ctx.PvP == true and ctx.Fair == true then
		local ok = RankingService.Credit(player, board, n, "PvP")
		if ok and typeof(ctx.Victim) == "Instance" then RankingService.CommitFair(player, ctx.Victim) end
		return ok
	end
	return false
end

------------------------------------------------------------------ 장인 명성 (A23-24)
-- scrolls from my own kills (RollKill -> ItemsGranted, incl. the first king-slime scroll) while in the guild and
-- active within HandActiveSeconds get one tag each; away auto-hunting and other factions' scrolls get none
local function onItemsGranted(player, gained)
	if factionOf(player) ~= "Neutral" or type(gained) ~= "table" then return end
	if game.PrivateServerId ~= "" then return end -- private-server scrolls never score later on a public server
	local last = lastOwn(player)
	if last <= 0 or os.clock() - last > R.HandActiveSeconds then return end
	local data = getData(player)
	if not data then return end
	local tags = ensureWeek(player, data).HandScroll
	for _, g in gained do
		if type(g) == "table" and HAND[g.Item] then
			local n = math.max(0, math.floor(tonumber(g.N) or 0))
			tags[g.Item] = math.min(Config.Loot.ItemCap, (tags[g.Item] or 0) + n)
		end
	end
end

-- an enhance with a tagged scroll: one tag is used; a success scores the steps it really rose (+10 cut already in
-- after - before). Failures and transfer scrolls score nothing.
local function onEnhanced(player, _tier, before, after, success, id)
	if not HAND[id] then return end
	local data = getData(player)
	if not data then return end
	local tags = ensureWeek(player, data).HandScroll
	local held = type(data.Items) == "table" and math.floor(tonumber(data.Items[id]) or 0) or 0
	local have = math.min(tags[id] or 0, held + 1) -- the used scroll was already taken out of Items
	if have <= 0 then
		tags[id] = nil
		return
	end
	tags[id] = have > 1 and have - 1 or nil
	local gain = success == true and math.max(0, math.floor((tonumber(after) or 0) - (tonumber(before) or 0))) or 0
	if gain > 0 and RankingService.Credit(player, "Artisan", gain, "Enhance") then
		pcall(Net.Notify, player, string.format(TXT.ArtisanGain, gain), "reward", nil, "RankUp") -- sound_gaps C1
	end
end

------------------------------------------------------------------ writes
-- one row: SetAsync (or RemoveAsync for nil) unless this server already wrote that value in this session; false = retry
local function writeRow(written, name, key, value)
	local want = value -- false = "removed" in the cache (never `value == nil and false or value`: that is nil again)
	if want == nil then want = false end
	if written[name] == want then return true end
	if budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) < R.MinBudget then
		RankingService.Stats.Skipped += 1
		return false
	end
	local ok, err = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(name)
		if value == nil then
			store:RemoveAsync(key)
		else
			store:SetAsync(key, value)
		end
	end)
	if not ok then
		warnThrottled("write", "write " .. name .. " failed: " .. tostring(err))
		return false
	end
	written[name] = want
	RankingService.Stats.Writes += 1
	return true
end

-- { [storeName] = value } a player should have: faction boards only for the faction, points > 0 only
local function rowsOf(p, src, hidden)
	local out = {}
	local faction = src.Faction or factionOf(p)
	if src.Hidden ~= nil then hidden = src.Hidden end
	for _, board in R.Order do
		local def = R.Boards[board]
		local score = tonumber(src[board]) or 0
		if score > 0 and (def.Faction == nil or def.Faction == faction) then
			out[RankingService.StoreName(board, src.WeekId)] = RankingService.Encode(score, hidden, faction)
		end
	end
	return out
end

-- the rows a faction change dropped (Rank.Drop, kept in the save until the removal lands; a board the player is back on
-- with points is simply overwritten), then last week's snapshot and this week's rows (eligible players only).
-- Flags are cleared only for the state this write carried: a change made while it yielded (another Credit, a hide
-- toggle) stays queued for the next loop step. true = everything landed.
local function writePlayer(p, data)
	local key = keyOf(p.UserId)
	local written = ST.Written[p.UserId] or {}
	ST.Written[p.UserId] = written
	local rank = ST.Shadow[p] or data.Rank
	local gen0, hidden = ST.Gen[p] or 0, data.HideAnnounceName == true
	local ok = eligible(p, data)
	local want = ok and rowsOf(p, rank, hidden) or {}
	ST.Writing[p] = true
	local all = true
	for board, wk in table.clone(rank.Drop) do
		local name = RankingService.StoreName(board, wk) -- a removal from last week survives the Monday flip
		if want[name] ~= nil or writeRow(written, name, key, nil) then
			rank.Drop[board] = nil
		else
			all = false
		end
	end
	local done = true
	if not ok then
		RankingService.Stats.Skipped += 1
		ST.Pending[p] = nil
	else
		local snap = ST.Pending[p]
		if snap then
			local sent = true
			for name, value in rowsOf(p, snap, hidden) do
				sent = writeRow(written, name, key, value) and sent
			end
			if sent and ST.Pending[p] == snap then ST.Pending[p] = nil end
			all = all and sent
		end
		for name, value in want do
			done = writeRow(written, name, key, value) and done
		end
	end
	ST.LastWrite[p] = os.clock()
	ST.Writing[p] = nil
	if done then
		if (ST.Gen[p] or 0) == gen0 then ST.Dirty[p] = nil end
		if ST.HideQueue[p] and (data.HideAnnounceName == true) == hidden then
			ST.HideQueue[p] = nil
			rank.HideSynced = hidden
		end
	end
	return all and done
end

-- the hidden flag changed: every row is rewritten at the next loop step (WriteEverySeconds ignored) until it lands
function RankingService.MarkHideChanged(player)
	if typeof(player) ~= "Instance" then return end
	ST.HideQueue[player] = true
	bump(player)
end

function RankingService.TickWrite()
	local now = os.clock()
	for _, p in S.PlayerService.GetReadyPlayers() do
		local data = getData(p)
		if data and not ST.Writing[p] then
			local rank = ensureWeek(p, data)
			local due = ST.Force[p] or ST.HideQueue[p] or ST.Pending[p] or next(rank.Drop) ~= nil
				or (ST.Dirty[p] and now - (ST.LastWrite[p] or -math.huge) >= R.WriteEverySeconds)
			if due then
				ST.Force[p] = nil
				local ok, err = pcall(writePlayer, p, data)
				if not ok then warnThrottled("writePlayer", "writePlayer: " .. tostring(err)) end
			end
		end
	end
end

------------------------------------------------------------------ reads
local function nameOf(userId)
	if userId <= 0 then return string.format(R.StudioNames, math.abs(userId)) end
	local c = ST.Names[userId]
	if c and os.clock() - c.At < R.NameCacheSeconds then return c.Name end
	return nil
end

local function fetchNames(ids)
	local need = {}
	for _, id in ids do
		if id > 0 and nameOf(id) == nil then table.insert(need, id) end
	end
	if #need == 0 then return end
	local ok, infos = pcall(function() return UserService:GetUserInfosByUserIdsAsync(need) end)
	if not ok or type(infos) ~= "table" then
		warnThrottled("names", "name lookup failed: " .. tostring(infos))
		return
	end
	for _, info in infos do
		local id = type(info) == "table" and tonumber(info.Id)
		if id then
			ST.Names[id] = { Name = tostring(info.DisplayName or info.Username or TXT.Unknown), At = os.clock() }
		end
	end
end

-- one global read of this week's board into the server cache (clients only ever get the cache)
function RankingService.ReadBoard(board)
	if not R.Boards[board] then return false end
	if budget(Enum.DataStoreRequestType.GetSortedAsync) < R.MinReadBudget then
		RankingService.Stats.Skipped += 1
		return false
	end
	local weekId = week()
	local ok, page = pcall(function()
		return DataStoreService:GetOrderedDataStore(RankingService.StoreName(board, weekId)):GetSortedAsync(false, R.TopN)
			:GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		warnThrottled("read:" .. board, "read " .. board .. " failed: " .. tostring(page))
		return false
	end
	RankingService.Stats.Reads += 1
	local rows, ids = {}, {}
	for _, entry in page do
		local userId = type(entry) == "table" and userIdOf(entry.key)
		if userId then
			local score, hidden, faction = RankingService.Decode(entry.value)
			if score > 0 then
				table.insert(rows, { UserId = userId, Value = score, Hidden = hidden, Faction = faction })
				table.insert(ids, userId)
			end
		end
	end
	rankRows(rows) -- same score = same rank number (the stored order also used the hidden bit / faction code)
	fetchNames(ids)
	ST.Cache[board] = { WeekId = weekId, Rows = rows, UpdatedAt = Util.Now() }
	return true
end

function RankingService.TickRead()
	local now = os.clock()
	for i, board in R.Order do
		if ST.ReadNext[board] == nil then ST.ReadNext[board] = now + (i - 1) * R.ReadStagger end
		if now >= ST.ReadNext[board] then
			ST.ReadNext[board] = now + R.RefreshSeconds
			RankingService.ReadBoard(board)
		end
	end
end

-- rows sent to clients + the real user id of each row (ids[i], never sent: hidden rows have UserId 0)
local function globalRows(board)
	local cache = ST.Cache[board]
	if not cache or cache.WeekId ~= week() then return {}, {}, 0 end
	local rows, ids = {}, {}
	for i, r in cache.Rows do
		local live = Players:GetPlayerByUserId(r.UserId)
		local hidden = r.Hidden
		if live then hidden = live:GetAttribute("HideAnnounceName") == true end -- re-masked from the live choice
		local row = { Rank = r.Rank or i, UserId = hidden and 0 or r.UserId, Faction = r.Faction, Value = r.Value }
		if hidden then
			row.Name = hiddenName(r.Faction)
		else
			row.Name = nameOf(r.UserId) or TXT.Unknown
			if live then
				local nick = Util.PlayerDisplayName(live)
				if nick ~= row.Name then row.Sub = nick end
			end
		end
		rows[i], ids[i] = row, r.UserId
	end
	return rows, ids, cache.UpdatedAt
end

-- this server's live points of one board (weekId = last week: the snapshots taken at the Monday flip)
local function serverRows(board, weekId)
	local def = R.Boards[board]
	local cur = week()
	local list = {}
	for _, p in S.PlayerService.GetReadyPlayers() do
		local data = getData(p)
		if data then
			local v, f = 0, factionOf(p)
			if weekId == nil or weekId == cur then
				v = ensureWeek(p, data)[board] or 0
			else
				local snap = ST.LastWeek[p]
				if snap and snap.WeekId == weekId then v, f = snap[board] or 0, snap.Faction end
			end
			if v > 0 and (def.Faction == nil or def.Faction == f) then
				table.insert(list, { P = p, UserId = p.UserId, Value = v, Faction = f, Test = data.DebugTainted == true or nil })
			end
		end
	end
	rankRows(list)
	local rows, ids = {}, {}
	for i = 1, math.min(R.TopN, #list) do
		local e = list[i]
		local hidden = e.P:GetAttribute("HideAnnounceName") == true
		rows[i] = { Rank = e.Rank, UserId = hidden and 0 or e.P.UserId, Name = publicName(e.P), Faction = e.Faction,
			Value = e.Value, Test = e.Test }
		ids[i] = e.P.UserId
	end
	return rows, ids, Util.Now()
end

-- BB11 town board (PvPService.updateBoard): this server's top `n` of one weekly board, ranked like the window (ties
-- share a number), names through PublicName; Outlaw = the player is an outlaw NOW (last week's settle), never this
-- week's candidates (검수 2026-10-06)
function RankingService.ServerTop(board, n)
	if not R.Boards[board] then return {} end
	local rows, ids = serverRows(board)
	local out = {}
	for i = 1, math.min(tonumber(n) or R.RewardTop, #rows) do
		local p = Players:GetPlayerByUserId(ids[i])
		table.insert(out, { Rank = rows[i].Rank, Name = rows[i].Name, Value = rows[i].Value,
			Outlaw = p ~= nil and p:GetAttribute("Outlaw") == true })
	end
	return out
end

local function onRequest(player, ...)
	if select("#", ...) ~= 2 then return end
	local board, scope = ...
	if type(board) ~= "string" or R.Boards[board] == nil or (scope ~= "Server" and scope ~= "Global") then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "RequestRankings", Config.RateLimits.RequestRankings) then return end
	local rows, ids, updatedAt
	if scope == "Server" then
		rows, ids, updatedAt = serverRows(board)
	else
		rows, ids, updatedAt = globalRows(board)
	end
	local me = { Value = 0 }
	local data = getData(player)
	if data then
		me.Value = ensureWeek(player, data)[board] or 0
		local at = table.find(ids, player.UserId)
		me.Rank = at and rows[at].Rank or nil
		if game.PrivateServerId ~= "" then
			me.Note = "Private"
		elseif scope == "Global" and not eligible(player, data) then
			me.Note = "Ineligible"
		elseif data.HideAnnounceName == true then
			me.Note = "Hidden" -- my rows show '<진영> 한 명' to others (BB37)
		end
	end
	local cur = week()
	Net.Get("Rankings"):FireClient(player, { Board = board, Scope = scope, Rows = rows, Me = me, UpdatedAt = updatedAt,
		WeekId = cur, WeekEndsAt = Config.WeekStart(cur + 1) })
	RankingService.Viewed:Fire(player, board, scope) -- BB38 metrics
end

------------------------------------------------------------------ weekly settle + effects
-- the timed "이번 주 …" titles of the reward boards: only this week's reward keeps its title
local function syncTitles(p, rr, cur)
	local T = S.TitleService
	if not (T and T.Revoke) then return end
	if RankingService.EffectiveSeason() == "STUDIO" then return end -- a Studio test never removes a live title
	for _, board in REWARD_BOARDS do
		for rank = 1, R.RewardTop do
			if not (rr.WeekId == cur and rr.Board == board and rr.Rank == rank) then
				pcall(T.Revoke, p, "Rank" .. board .. rank)
			end
		end
	end
end

-- attributes from the saved results of this season: Outlaw (this week), RankReward / RankRewardRank (this week AND in
-- that board's faction)
local function resultsOf(p, data)
	if RankingService.EffectiveSeason() == "STUDIO" and liveSeason(type(data.Rank) == "table" and data.Rank.Season) then
		ST.StudioResult[p] = ST.StudioResult[p] or {}
		return ST.StudioResult[p] -- Studio on a live save: session-only results
	end
	return data
end

function RankingService.RefreshEffects(p)
	local data = getData(p)
	if not data then return end
	local cur, season = week(), RankingService.EffectiveSeason()
	data = resultsOf(p, data)
	local ol = type(data.Outlaw) == "table" and data.Outlaw or {}
	local outlaw = ol.WeekId == cur and ol.Season == season
	local rr = type(data.RankReward) == "table" and data.RankReward or {}
	local mine = rr.WeekId == cur and rr.Season == season
	local def = R.Boards[rr.Board]
	local on = mine and def ~= nil and def.Reward == true and def.Faction == factionOf(p)
	if outlaw then ST.SeenOutlaw[p] = true end
	if p:GetAttribute("Outlaw") ~= outlaw then
		p:SetAttribute("Outlaw", outlaw)
		-- the end of the week: still a bully -> nothing here (CombatService says BullyPenaltyEnd when the stacks go)
		if not outlaw and ST.SeenOutlaw[p] then
			ST.SeenOutlaw[p] = nil
			if (tonumber(p:GetAttribute("BullyStacks")) or 0) < 1 then
				local text = p:GetAttribute("AutoCombatUnlocked") == true and TXT.OutlawEnd or TXT.OutlawEndNoAuto
				pcall(Net.Notify, p, text, "good")
			end
		end
	end
	local board = on and rr.Board or ""
	if p:GetAttribute("RankReward") ~= board then p:SetAttribute("RankReward", board) end
	local rank = on and rr.Rank or 0
	if p:GetAttribute("RankRewardRank") ~= rank then p:SetAttribute("RankRewardRank", rank) end
	syncTitles(p, mine and rr or {}, cur)
end

-- one settle document applied to one player (idempotent): results count for the week after the settled one only
local function applySettle(p, doc)
	if type(doc) ~= "table" or doc.Skipped or type(doc.Boards) ~= "table" then return end
	local effect = (tonumber(doc.Week) or 0) + 1
	if effect ~= week() then return end
	local data = getData(p)
	if not data then return end
	data = resultsOf(p, data)
	local season = RankingService.EffectiveSeason()
	local best = nil
	for _, board in R.Order do
		local list = doc.Boards[board]
		local at = type(list) == "table" and table.find(list, p.UserId) or nil
		local ranks = type(doc.Ranks) == "table" and doc.Ranks[board] or nil
		local r = at and math.clamp(math.floor(tonumber(type(ranks) == "table" and ranks[at]) or at), 1, R.RewardTop) or nil
		if r and R.Boards[board].Outlaw then
			local ol = data.Outlaw
			if type(ol) ~= "table" or ol.WeekId ~= effect or ol.Season ~= season then
				data.Outlaw = { WeekId = effect, Season = season }
				pcall(Net.Notify, p, string.format(TXT.OutlawStart, r), "bad", 8)
				ST.OutlawToldAt[p] = os.clock()
			end
		elseif r and R.Boards[board].Reward and (best == nil or r < best.Rank) then
			best = { Board = board, Rank = r }
		end
	end
	-- the week's title, also given back when something removed it (Grant is a no-op when it is owned)
	if best and S.TitleService and S.TitleService.Grant then pcall(S.TitleService.Grant, p, "Rank" .. best.Board .. best.Rank) end
	local rr = data.RankReward
	if best and not (type(rr) == "table" and rr.WeekId == effect and rr.Season == season and rr.Board == best.Board
		and rr.Rank == best.Rank) then
		data.RankReward = { WeekId = effect, Season = season, Board = best.Board, Rank = best.Rank }
		local f = R.Boards[best.Board].Faction
		local text = string.format(TXT.RewardStart, TXT.BoardNames[best.Board], best.Rank)
		if f ~= factionOf(p) then -- switched since: the title is given, the +10% waits for that faction
			text = string.format(TXT.RewardStartOff, TXT.BoardNames[best.Board], best.Rank, Config.Factions[f].Name)
		end
		pcall(Net.Notify, p, text, "reward", 8, "RankUp") -- the weekly top-3 title (sound_gaps C1)
	end
	RankingService.RefreshEffects(p)
end

-- the top-RewardTop list of one board of week `weekId` from the global store: everyone tied with 3rd included (the
-- page is TopN long for that), ranked by the decoded score only; PvP needs OutlawMinScore points -> { ids }, { ranks }
local function topOf(board, weekId)
	local page = DataStoreService:GetOrderedDataStore(RankingService.StoreName(board, weekId))
		:GetSortedAsync(false, R.TopN):GetCurrentPage()
	local min = R.Boards[board].Outlaw and R.OutlawMinScore or 1
	local rows = {}
	for _, entry in page do
		local userId = type(entry) == "table" and userIdOf(entry.key)
		local score = userId and RankingService.Decode(entry.value) or 0
		if userId and score > 0 then table.insert(rows, { UserId = userId, Value = score }) end
	end
	local ids, ranks = settleList(rows, min)
	if #page >= R.TopN and #ids > 0 and rows[#rows].Value >= rows[#ids].Value then
		warnThrottled("tie:" .. board, ("%s week %d: a tie at the top reaches the %d-row page; rows past it are not read"):format(
			board, weekId, R.TopN))
	end
	return ids, ranks
end

-- the same lists from this server's points of week `fromWeek` (the STUDIO season settle: last week's snapshots;
-- DebugSettle: this week's live points), stored as the results of week `weekId`
local function serverDoc(weekId, fromWeek)
	local doc = { Week = weekId, Boards = {}, Ranks = {}, At = os.time(), Server = true }
	for _, board in R.Order do
		local rows, ids = serverRows(board, fromWeek)
		local list = {}
		for i, row in rows do
			table.insert(list, { UserId = ids[i], Value = row.Value })
		end
		doc.Boards[board], doc.Ranks[board] = settleList(list, R.Boards[board].Outlaw and R.OutlawMinScore or 1)
	end
	return doc
end

-- once per week per server: last week's results (the stored document, or built and stored first-writer-wins)
function RankingService.TickSettle()
	local cur = week()
	local prev = cur - 1
	if ST.Settled[prev] ~= nil then return end
	if os.time() < Config.WeekStart(cur) + R.SettleDelaySeconds or os.clock() < ST.SettleNextTry then return end
	local season = RankingService.EffectiveSeason()
	local first = ST.SettleFirstFail[prev]
	local giveUp = season ~= "STUDIO" and first ~= nil and os.time() - first >= R.SettleGiveUpSeconds
	local ok, doc = pcall(function()
		local store = DataStoreService:GetDataStore(R.SettleStorePrefix .. season)
		local key = "W" .. tostring(prev)
		local stored = store:GetAsync(key)
		if type(stored) == "table" then return stored end
		local built
		if giveUp then
			-- D4: after SettleGiveUpSeconds of failed reads the skip itself is stored, first writer wins (a real document
			-- another server stored first is still applied), so every server applies the same decision
			built = { Week = prev, Skipped = true, At = os.time() }
		else
			built = { Week = prev, Boards = {}, Ranks = {}, At = os.time() }
			for _, board in R.Order do
				built.Boards[board], built.Ranks[board] = topOf(board, prev)
			end
		end
		return store:UpdateAsync(key, function(old)
			return type(old) == "table" and old or built
		end)
	end)
	if not ok or type(doc) ~= "table" then
		if season ~= "STUDIO" then
			-- nothing is applied until a document (real or skipped) is read or stored: no per-server lists
			ST.SettleFirstFail[prev] = first or os.time()
			ST.SettleNextTry = os.clock() + R.SettleRetrySeconds
			warnThrottled("settle", ("week %d settle failed, retrying in %d s: %s"):format(prev, R.SettleRetrySeconds,
				tostring(doc)))
			return
		end
		doc = serverDoc(prev, prev) -- D4: the STUDIO season settles from this server's board (last week's snapshots)
	end
	ST.Settled[prev] = doc
	if doc.Skipped then
		RankingService.Stats.SettleSkipped += 1
		Util.Warn(TAG, ("week %d settle skipped: board reads failed for %d s (no rewards / outlaws on any server)"):format(
			prev, R.SettleGiveUpSeconds))
		return
	end
	RankingService.Stats.Settles += 1
	for _, p in S.PlayerService.GetReadyPlayers() do
		local okApply, err = pcall(applySettle, p, doc)
		if not okApply then warnThrottled("apply", "apply settle: " .. tostring(err)) end
	end
end

-- every loop step: the week of every online player, the GameState week mirror and the effect attributes
function RankingService.TickWeek()
	local cur = week()
	local okGs, gs = pcall(Net.GameState)
	if okGs and gs then
		if gs:GetAttribute("RankWeekId") ~= cur then gs:SetAttribute("RankWeekId", cur) end
		local ends = Config.WeekStart(cur + 1)
		if gs:GetAttribute("RankWeekEndsAt") ~= ends then gs:SetAttribute("RankWeekEndsAt", ends) end
	end
	for _, p in S.PlayerService.GetReadyPlayers() do
		local data = getData(p)
		if data then
			ensureWeek(p, data)
			RankingService.RefreshEffects(p)
		end
	end
end

------------------------------------------------------------------ debug (Studio season only)
-- DebugCommand "RankSettle": settles THIS week's server board now and applies it at once (results act this week)
-- 게임성 검수 2026-10-12: os.clock() of the outlaw week's start line to this player, or nil. That line already says "no
-- Auto", so CombatService skips its own auto-off line right after it (one line, not two).
function RankingService.OutlawToldAt(p)
	return ST.OutlawToldAt[p]
end

function RankingService.DebugSettle()
	if RankingService.EffectiveSeason() ~= "STUDIO" then return "STUDIO season only" end
	local doc = serverDoc(week() - 1, week())
	for _, p in S.PlayerService.GetReadyPlayers() do
		pcall(applySettle, p, doc)
	end
	local parts = {}
	for _, board in R.Order do
		local ids = {}
		for _, id in doc.Boards[board] do table.insert(ids, tostring(id)) end
		table.insert(parts, board .. "=" .. table.concat(ids, ","))
	end
	return table.concat(parts, " ")
end

-- DebugCommand "RankWrite": write this player's rows at the next loop step
function RankingService.DebugWrite(player)
	ST.Force[player] = true
	ST.Dirty[player] = true
	return "queued"
end

------------------------------------------------------------------ lifecycle
local function onReady(p, data)
	data = type(data) == "table" and data or getData(p)
	if not data then return end
	ST.Written[p.UserId] = nil -- a new session never trusts what this server wrote earlier (another server may have since)
	local rank = ensureWeek(p, data)
	publish(p, rank)
	for _, board in R.Order do
		if (rank[board] or 0) > 0 then ST.Dirty[p] = true end -- a last write that never landed is redone
	end
	if next(rank.Drop) ~= nil then ST.Force[p] = true end -- a removal that never landed
	local doc = ST.Settled[week() - 1]
	if doc then applySettle(p, doc) end
	RankingService.RefreshEffects(p)
	if rank.HideSynced ~= (data.HideAnnounceName == true) then RankingService.MarkHideChanged(p) end
end

-- faction change (altar, rebirth, first pick): the old faction's board row goes (this week's points there are gone; the
-- removal is kept in the save as Rank.Drop until it lands); leaving the guild also drops the 장인 tags; the PvP row keeps
-- its points with the new faction code
local function onFactionChanged(p, newFaction, oldFaction)
	local data = getData(p)
	if not data then return end
	local rank = ensureWeek(p, data, oldFaction) -- a week flip first seen here belongs to the old faction
	for _, board in R.Order do
		local f = R.Boards[board].Faction
		if f and f == oldFaction and f ~= newFaction then
			rank[board] = 0
			rank.Drop[board] = rank.WeekId
		end
	end
	if oldFaction == "Neutral" and newFaction ~= "Neutral" then rank.HandScroll = {} end
	publish(p, rank)
	bump(p)
	ST.Force[p] = true
	RankingService.RefreshEffects(p)
end

local function forget(p)
	for _, t in { ST.Dirty, ST.Force, ST.LastWrite, ST.Pending, ST.LastWeek, ST.HideQueue, ST.Gen, ST.Writing, ST.SeenOutlaw,
		ST.Shadow, ST.StudioResult, ST.OutlawToldAt } do
		t[p] = nil
	end
	ST.Written[p.UserId] = nil
end

-- PlayerLeaving handlers must not yield (the final save waits for them): the last write runs in its own thread with the
-- data table it captured (still valid after the release). It waits for a loop write of the same player still running,
-- tries LeaveWriteTries times, and PlayerService's BindToClose waits for it (RankingService.PendingWrites).
local function onLeaving(p, data)
	data = type(data) == "table" and data or getData(p)
	if type(data) ~= "table" or type(ST.Shadow[p] or data.Rank) ~= "table" then
		forget(p)
		return
	end
	ensureWeek(p, data)
	ST.Leaving += 1
	task.spawn(function()
		local t0 = os.clock()
		while ST.Writing[p] and os.clock() - t0 < R.LeaveWaitSeconds do
			task.wait(0.1)
		end
		for attempt = 1, R.LeaveWriteTries do
			local ok, res = pcall(writePlayer, p, data)
			if not ok then warnThrottled("leave", "leave write: " .. tostring(res)) end
			if ok and res == true then break end
			if attempt < R.LeaveWriteTries then task.wait(1) end
		end
		forget(p)
		ST.Leaving -= 1
	end)
end

-- leave writes still running (PlayerService's BindToClose waits for them after the saves)
function RankingService.PendingWrites()
	return ST.Leaving
end

function RankingService.Init(registry)
	S = registry
end

function RankingService.Start()
	S.PlayerService.PlayerReady:Connect(function(p, data)
		local ok, err = pcall(onReady, p, data)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerLeaving:Connect(function(p, data)
		local ok, err = pcall(onLeaving, p, data)
		if not ok then Util.Warn(TAG, "leaving: " .. tostring(err)) end
	end)
	S.FactionService.FactionChanged:Connect(function(p, newFaction, oldFaction)
		local ok, err = pcall(onFactionChanged, p, newFaction, oldFaction)
		if not ok then Util.Warn(TAG, "faction: " .. tostring(err)) end
	end)
	S.LootService.ItemsGranted:Connect(function(p, gained)
		local ok, err = pcall(onItemsGranted, p, gained)
		if not ok then Util.Warn(TAG, "items: " .. tostring(err)) end
	end)
	S.LootService.Enhanced:Connect(function(p, ...)
		local ok, err = pcall(onEnhanced, p, ...)
		if not ok then Util.Warn(TAG, "enhance: " .. tostring(err)) end
	end)
	if S.CombatService and S.CombatService.PlayerDamaged then
		S.CombatService.PlayerDamaged:Connect(function(victim, _applied, attacker)
			RankingService.WarmFriends(attacker, victim)
		end)
	end
	Net.Get("RequestRankings").OnServerEvent:Connect(function(p, ...)
		local ok, err = pcall(onRequest, p, ...)
		if not ok then Util.Warn(TAG, "RequestRankings: " .. tostring(err)) end
	end)
	task.spawn(function()
		while true do
			task.wait(R.LoopSeconds)
			for _, step in { RankingService.TickWeek, RankingService.TickWrite, RankingService.TickRead, RankingService.TickSettle } do
				local ok, err = pcall(step)
				if not ok then warnThrottled("loop", "loop: " .. tostring(err)) end
			end
		end
	end)
	print("[RankingService] started")
end

return RankingService
