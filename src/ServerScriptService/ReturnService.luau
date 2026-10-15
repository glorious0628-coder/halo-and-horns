-- ReturnService.luau : SPEC A23-79 다시 오게 만들기, the server's part (게임성 개발 3, 2026-10-08; contract
-- docs/design/return_server_2026-10-08.md). Nothing here gives a stat, sells anything or counts down.
--   #1 the pause card "Saved! ✓ Next time: …" (Fx "PauseCard" { Why, Next, Zone, Tomorrow?, OptIn? }) at a chapter end
--      (the last main quest of a chapter), when the day's dailies are all claimed (DailyClaims reaches Config.Quests.Slots)
--      and at a crown-war end the player took part in (Config.Return.War: a long session, no card for a while). The
--      next goal is the pinned quest row (QuestService.PinnedRow). And "Welcome back! Next: … [Go]" (Fx "WelcomeBack"
--      { Next, Zone }) once when a player comes back after Config.Return.WelcomeAfter s away (data.LastLogoutTime).
--   #2 the "My Way" name from the player's own good / evil story picks (attribute MyWay = the display name, "" = none
--      yet; the client shows its 2 s line on a change) and the 8 Roblox badges (BadgeService:AwardBadge; Config.Badges
--      ids, 0 = the badge is not made yet -> skipped, awarded later at a join).
--   #5 the notification opt-in moment: after the day's dailies (the card's OptIn flag) or after the first King Diary
--      page (Fx "OptInMoment" { Why }), once (data.Return.OptIn), never in the first 10 minutes or right after a KO /
--      a failed scroll / a purchase prompt. 13+ and the prompt itself are the client's (ExperienceNotificationService);
--      it reports back with ClientMetric "OptIn" ("shown" | "cannot"); a shown prompt adds the UserId to the asked list
--      (DataStore Config.Notify.Store) for the launch-day send.
--   #6 A23-167 ② "내일 또 오기" (게임성 개발 2, 2026-10-14; docs/design/comeback_server_2026-10-14.md): the tomorrow
--      card (Fx "TomorrowGift" { Tomorrow, Today?, Days }, Config.Return.Tomorrow: once a KST day After s into the
--      session, the first attendance week only), the attribute Returned = true on a real return (the guide's line is the
--      client's, Config.Return.Text.BackLines) and the WelcomeBack card's Days + News ("while you were away": crown wars
--      won by each side and goose rounds of every public server, Config.Return.News: one shared DataStore row per hour).
-- Save (additive, Version stays 3): data.Return = { Badges = { [badge key] = { Id, At } }, OptIn = "" | "shown"
-- | "cannot", OptInAt = os.time(), TomorrowDay = the KST day of the last tomorrow card } (repaired here at PlayerReady).
-- Signals: ReturnService.CardShown(player, why), ReturnService.Welcomed(player) (TelemetryService),
-- ReturnService.TomorrowShown(player, tomorrowSlot).
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local ReturnService = {}
ReturnService.CardShown = Util.Signal.new() -- (player, why: "Chapter" | "Daily" | "War")
ReturnService.Welcomed = Util.Signal.new() -- (player)
ReturnService.TomorrowShown = Util.Signal.new() -- (player, the slot a claim tomorrow pays) A23-167 ②

local TAG = "ReturnService"
local S = nil
local R = Config.Return or {}
local MW = Config.MyWay or {}
local B = Config.Badges or {}
local N = Config.Notify or {}
local TXT = R.Text or {}
local TM = R.Tomorrow or {} -- A23-167 ②
local NW = R.News or {}

local T = {
	JoinedAt = {}, -- [Player] = os.clock() the session started
	CardAt = {}, -- [Player] = os.clock() of the last pause card
	KOAt = {}, -- [Player] = os.clock() of the last KO
	FailAt = {}, -- [Player] = os.clock() of the last failed scroll
	BuyAt = {}, -- [Player] = os.clock() of the last purchase prompt (ClientMetric "PurchasePrompt")
	OptInSent = {}, -- [Player] = true: the opt-in moment went out this session (one a session at most)
	Awarding = {}, -- [Player] = { [badge key] = true } while an AwardBadge call runs
	BadgeRetry = {}, -- [Player] = { [badge key] = os.clock() } of a failed call (retried after BadgeRetry s)
	Conns = {}, -- [Player] = { RBXScriptConnection }
	ChapterEnd = {}, -- [main quest id] = chapter number: the last main quest of each chapter
	AskedStore = nil, -- the opted-in list DataStore (false = unavailable)
	-- A23-167 ② news: this server's counts not yet in the shared row ([hour string] = { Halo, Horns, Goose }), the last
	-- row read (Cache, at os.clock() CacheAt), the store (false = unavailable), a read / write running
	News = { Pending = {}, Cache = nil, CacheAt = nil, Store = nil, Reading = false, Flushing = false },
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function getData(player)
	if not S.PlayerService.IsReady(player) then return nil end
	local d = S.PlayerService.GetData(player)
	return type(d) == "table" and d or nil
end

-- data.Return repaired in place (Badges: known keys with { Id = the badge id awarded, At = os.time() } only; OptIn one of
-- the three values)
local function record(data)
	local r = data.Return
	if type(r) ~= "table" then
		r = {}
		data.Return = r
	end
	local badges = {}
	if type(r.Badges) == "table" then
		for key, b in r.Badges do
			if type(key) == "string" and type(B.Ids) == "table" and B.Ids[key] ~= nil and type(b) == "table"
				and num(b.Id) > 0 and num(b.At, -1) >= 0 then
				badges[key] = { Id = math.floor(b.Id), At = math.floor(b.At) }
			end
		end
	end
	r.Badges = badges
	if r.OptIn ~= "shown" and r.OptIn ~= "cannot" then r.OptIn = "" end
	r.OptInAt = math.max(0, math.floor(num(r.OptInAt)))
	r.TomorrowDay = math.max(0, math.floor(num(r.TomorrowDay))) -- A23-167 ②
	return r
end

local function inCombat(player)
	local combat = S.CombatService
	if type(combat) ~= "table" or type(combat.IsInCombat) ~= "function" then return false end
	local ok, res = pcall(combat.IsInCombat, player)
	return ok and res == true
end

local function fx(player, kind, payload)
	local ok, err = pcall(Net.Fx, player, kind, payload)
	if not ok then Util.Warn(TAG, kind .. ": " .. tostring(err)) end
	return ok
end

------------------------------------------------------------------ the next goal
-- the zone of a quest row's Guide: a zone id, a story landmark (Config.StoryQuests.Landmarks -> Config.ZoneAt) or a
-- spot / NPC listed in Config.Return.GuideZones ("Home" = the player's own town)
local function zoneOfGuide(guide)
	if type(guide) ~= "string" then return nil end
	if guide == "Goose" and Config.Goose.Mode == "Eggs" then return nil end -- A23-141: Join from anywhere (no zone)
	if Config.Zones[guide] then return guide end
	local fixed = (R.GuideZones or {})[guide]
	if fixed then return fixed end
	local marks = Config.StoryQuests and Config.StoryQuests.Landmarks
	local pos = type(marks) == "table" and marks[guide] or nil
	if typeof(pos) == "Vector3" then
		local z = Config.ZoneAt(pos)
		if z and z.Id ~= "Outskirts" then return z.Id end
	end
	return nil
end

-- the Travel remote's destination for a zone the player may go to now, or nil: "Home" for the own town (the other
-- side's town never), a seasonal field -> Config.Return.SeasonFallback, else a Config.Travel destination whose level
-- gate the player passes
local function travelZone(player, zoneId)
	if zoneId == "Home" then return "Home" end
	local zone = type(zoneId) == "string" and Config.Zones[zoneId] or nil
	if not zone then return nil end
	if zone.Season ~= nil then
		zoneId = R.SeasonFallback or "SlimeMeadow"
		zone = Config.Zones[zoneId]
		if not zone then return nil end
	end
	if zone.Town and zone.Faction ~= nil then
		return Config.HomeZoneId(player:GetAttribute("Faction")) == zoneId and "Home" or nil
	end
	if num(player:GetAttribute("Level"), 1) < num(zone.MinLevel, 1) then return nil end
	for _, d in Config.Travel.Destinations do
		if d.Id == zoneId then return zoneId end
	end
	return nil
end

-- (next goal text, zone id or nil) from the pinned quest row; the hunting line when nothing is pinned
local function nextGoal(player, data)
	local quest = S.QuestService
	local row = nil
	if type(quest) == "table" and type(quest.PinnedRow) == "function" then
		local ok, res = pcall(quest.PinnedRow, player)
		if ok and type(res) == "table" then row = res end
	end
	local level = math.floor(num(data.Level, 1))
	local hunt = Config.QuestZoneForLevel(level)
	if row == nil then
		return TXT.NextHunt or "Hunt and get stronger!", travelZone(player, hunt)
	end
	local text = (type(row.ShortName) == "string" and row.ShortName ~= "") and row.ShortName or row.Text
	if type(text) ~= "string" or text == "" then text = TXT.NextHunt or "Hunt and get stronger!" end
	local guide = type(row.Story) == "table" and row.Story.Guide or nil
	local zone = zoneOfGuide(guide)
	if zone == nil then
		local kind = row.GoalKind
		zone = (kind == "Zone" and (R.NextZone or "GoblinWoods")) or (kind == "IronGold" and "Crossroads")
			or (R.GoalZones or {})[kind] or hunt
	end
	return text, travelZone(player, zone)
end

------------------------------------------------------------------ #1 pause card / welcome back
local optInMoment -- forward
local newsAdd -- forward (A23-167 ②: the news section below)

-- one pause card (why "Chapter" | "Daily" | "War"); waits out a fight (Config.Return.CombatWait tries) and keeps the
-- MinGap between two cards. Returns nothing; the card fires CardShown.
local function sendCard(player, why, tries)
	tries = tries or 0
	if player.Parent == nil then return end
	local data = getData(player)
	if not data then return end
	if inCombat(player) then
		if tries < num(R.CombatWaitTries, 10) then
			task.delay(num(R.CombatWaitSeconds, 3), sendCard, player, why, tries + 1)
		end
		return
	end
	local now = os.clock()
	if T.CardAt[player] and now - T.CardAt[player] < num(R.MinGap, 120) then return end
	T.CardAt[player] = now
	local nextText, zone = nextGoal(player, data)
	local payload = { Why = why, Next = nextText, Zone = zone }
	if why == "Daily" then
		payload.Tomorrow = TXT.TomorrowDaily or "New dailies"
		local diary = S.DiaryService
		if type(diary) == "table" and type(diary.TomorrowLine) == "function" then
			local ok, line = pcall(diary.TomorrowLine, player)
			if ok and type(line) == "string" and line ~= "" then payload.Tomorrow = line end
		end
		payload.OptIn = optInMoment(player, "Daily", true) or nil
	end
	if fx(player, "PauseCard", payload) then ReturnService.CardShown:Fire(player, why) end
end

local function queueCard(player, why)
	-- A23-130: a card kind the client no longer shows (Config.Return.Cards[why] == false, PauseCard T.PauseWhy) is not
	-- sent, so it never takes the MinGap of a card that shows; the Daily moment still offers the opt-in (Fx OptInMoment)
	if type(R.Cards) == "table" and R.Cards[why] == false then
		if why == "Daily" then
			task.delay(num(R.CardDelay, 1.5), function()
				if player.Parent ~= nil then optInMoment(player, "Daily", false) end
			end)
		end
		return
	end
	task.delay(num(R.CardDelay, 1.5), sendCard, player, why, 0)
end

-- the last main quest of each chapter (Config.StoryQuests.Main order + Defs[id].Chapter)
local function buildChapterEnds()
	local SQ = Config.StoryQuests or {}
	local last = {}
	for _, id in SQ.Main or {} do
		local def = SQ.Defs and SQ.Defs[id]
		local ch = def and math.floor(num(def.Chapter))
		if ch and ch > 0 then last[ch] = id end
	end
	for ch, id in last do T.ChapterEnd[id] = ch end
end

local function onQuestDone(player, id)
	if T.ChapterEnd[id] then queueCard(player, "Chapter") end
end

local function onDailyClaims(player)
	local slots = math.floor(num(Config.Quests and Config.Quests.Slots, 3))
	if math.floor(num(player:GetAttribute("DailyClaims"))) == slots then queueCard(player, "Daily") end
end

local function onWarEnded(winner, mode, snapshot)
	if mode == "Idle" or type(snapshot) ~= "table" then return end
	if winner == "Halo" or winner == "Horns" then newsAdd(winner) end -- A23-167 ② (a draw is no news)
	local W = R.War or {}
	local minPoints = num(Config.War and Config.War.ChestMinPoints, 1)
	for player, points in snapshot do
		if typeof(player) == "Instance" and player.Parent ~= nil and num(points) >= minPoints then
			local joined = T.JoinedAt[player]
			local last = T.CardAt[player]
			local now = os.clock()
			if joined and now - joined >= num(W.MinSession, 900) and (last == nil or now - last >= num(W.MinGap, 1800)) then
				queueCard(player, "War")
			end
		end
	end
end

------------------------------------------------------------------ #6 A23-167 ② news while away
-- the shared row: { [hour index string] = { Halo = n, Horns = n, Goose = n } }, hour index = floor(os.time() / 3600)
local function newsOn()
	return NW.Enabled ~= false and game.PrivateServerId == "" -- private servers never count (nor read: same line for all)
end

local function newsStore()
	local nws = T.News
	if nws.Store == nil then
		local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, Config.StoreName(NW.Store or "HaloHorns_News_v1"))
		nws.Store = ok and store or false
	end
	return nws.Store or nil
end

-- one more event of this server (kind "Halo" | "Horns" = a crown war won, "Goose" = a goose round)
function newsAdd(kind)
	if not newsOn() then return end
	local hour = tostring(math.floor(os.time() / 3600))
	local row = T.News.Pending[hour]
	if not row then
		row = {}
		T.News.Pending[hour] = row
	end
	row[kind] = num(row[kind]) + 1
end

-- `into` += `from` (hour rows); hours older than KeepHours (or broken) are dropped from both. Returns `into`
local function newsMerge(into, from, nowHour)
	local keep = math.max(1, math.floor(num(NW.KeepHours, 168)))
	for hour, row in type(from) == "table" and from or {} do
		local h = tonumber(hour)
		if h and type(row) == "table" and h > nowHour - keep and h <= nowHour + 1 then
			local key = tostring(math.floor(h))
			local out = type(into[key]) == "table" and into[key] or {}
			for _, kind in { "Halo", "Horns", "Goose" } do
				local n = math.max(0, math.floor(num(row[kind])))
				if n > 0 then out[kind] = num(out[kind]) + n end
			end
			if next(out) ~= nil then into[key] = out end
		end
	end
	for hour in into do
		local h = tonumber(hour)
		if not h or h <= nowHour - keep then into[hour] = nil end
	end
	return into
end

-- this server's pending counts into the shared row (a failed write keeps them for the next try)
local function newsFlush()
	local nws = T.News
	if nws.Flushing or next(nws.Pending) == nil then return end
	local store = newsStore()
	if not store then return end
	local batch = nws.Pending
	nws.Pending = {}
	nws.Flushing = true
	local nowHour = math.floor(os.time() / 3600)
	local ok, res = pcall(store.UpdateAsync, store, NW.Key or "Hours", function(old)
		return newsMerge(type(old) == "table" and old or {}, batch, nowHour)
	end)
	nws.Flushing = false
	if ok then
		if type(res) == "table" then nws.Cache, nws.CacheAt = res, os.clock() end
	else
		newsMerge(nws.Pending, batch, math.floor(os.time() / 3600)) -- back in line, with what came meanwhile
		Util.Warn(TAG, "news write: " .. tostring(res))
	end
end

-- the shared row (read at most once every ReadGap s; nil = never read / unavailable). May yield
local function newsRow()
	local nws = T.News
	if nws.Reading then return nws.Cache end
	if nws.CacheAt == nil or os.clock() - nws.CacheAt >= num(NW.ReadGap, 300) then
		local store = newsStore()
		if store then
			nws.Reading = true
			local ok, row = pcall(store.GetAsync, store, NW.Key or "Hours")
			nws.Reading = false
			if ok then
				nws.Cache = type(row) == "table" and row or {}
				nws.CacheAt = os.clock()
			else
				Util.Warn(TAG, "news read: " .. tostring(row))
			end
		end
	end
	return nws.Cache
end

-- the one news line for a player away since `since` (os.time of the last leave), or nil
local function newsLine(player, since)
	if not newsOn() then return nil end
	local row = newsRow()
	if type(row) ~= "table" then return nil end
	local nowHour = math.floor(os.time() / 3600)
	-- the shared row + this server's counts not written yet
	local all = newsMerge(newsMerge({}, row, nowHour), T.News.Pending, nowHour)
	local from = math.floor(num(since) / 3600) + 1 -- the hours after the leave hour
	local sum = { Halo = 0, Horns = 0, Goose = 0 }
	for hour, counts in all do
		local h = tonumber(hour)
		if h and h >= from and h <= nowHour then
			for kind in sum do sum[kind] += num(counts[kind]) end
		end
	end
	local sides = TXT.NewsSides or {}
	if sum.Halo + sum.Horns > 0 then
		local mine = player:GetAttribute("Faction") == "Horns" and "Horns" or "Halo"
		local other = mine == "Horns" and "Halo" or "Horns"
		return string.format(TXT.NewsWar or "Crown war wins while you were away: %s %d, %s %d",
			sides[mine] or mine, sum[mine], sides[other] or other, sum[other])
	end
	if sum.Goose > 0 then return string.format(TXT.NewsGoose or "Goose rounds while you were away: %d", sum.Goose) end
	return nil
end

local function welcomeBack(player, since)
	local data = getData(player)
	if not data or player.Parent == nil then return end
	local nextText, zone = nextGoal(player, data)
	local okNews, news = pcall(newsLine, player, since)
	if not okNews then
		Util.Warn(TAG, "news: " .. tostring(news))
		news = nil
	end
	if player.Parent == nil then return end -- left while the row was read
	local days = math.max(0, math.floor((os.time() - num(since)) / 86400))
	if fx(player, "WelcomeBack", { Next = nextText, Zone = zone, Days = days, News = news }) then
		ReturnService.Welcomed:Fire(player)
	end
end

------------------------------------------------------------------ #6 A23-167 ② the tomorrow card
-- once a KST day, After s into the session (onReady's delay), only in the first attendance week; before the first
-- mission / in a fight / less than MinGap after a card / within Calm s of a purchase prompt it waits RetrySeconds (at
-- most Retries times)
local function tomorrowCard(player, joinedAt, tries)
	if player.Parent == nil or T.JoinedAt[player] ~= joinedAt then return end -- left (or a new session)
	local data = getData(player)
	if not data or TM.Enabled == false then return end
	local r = record(data)
	local day = Config.DayIndex(os.time())
	if r.TomorrowDay >= day then return end
	local att = S.AttendanceService
	if type(att) ~= "table" or type(att.NextSlots) ~= "function" then return end
	local now = os.clock()
	local busy = data.ClassChosen ~= true or num(data.TutorialStep) ~= 99 or inCombat(player)
		or (T.CardAt[player] ~= nil and now - T.CardAt[player] < num(R.MinGap, 120))
		or (T.BuyAt[player] ~= nil and now - T.BuyAt[player] < num(N.Calm, 60))
	if busy then
		if tries < num(TM.Retries, 20) then
			task.delay(num(TM.RetrySeconds, 30), tomorrowCard, player, joinedAt, tries + 1)
		end
		return
	end
	local okSlots, todaySlot, tomorrowSlot, days = pcall(att.NextSlots, player)
	if not okSlots or type(tomorrowSlot) ~= "number" then return end
	if num(days) >= num(TM.MaxDays, 7) then return end
	r.TomorrowDay = day
	T.CardAt[player] = now
	if fx(player, "TomorrowGift", { Tomorrow = tomorrowSlot, Today = todaySlot, Days = math.floor(num(days)) }) then
		ReturnService.TomorrowShown:Fire(player, tomorrowSlot)
	end
end

------------------------------------------------------------------ #2 My Way
-- the side ("Good" | "Evil") of a saved pick of quest `id`: the quest's Choice step names its picks (Good.Pick or
-- "Good", Evil.Pick or "Evil"); Neutral A / B count as Good / Evil like StoryQuestService's own SIDE table
local function sideOf(id, pick)
	local def = Config.StoryQuests and Config.StoryQuests.Defs and Config.StoryQuests.Defs[id]
	for _, step in type(def) == "table" and def.Steps or {} do
		local joke = step.Obj
		-- a joke pick (the Terms of Fate egg: Choice MyWay = false) never counts for My Way, whatever it saved
		if type(joke) == "table" and joke.Type == "Choice" and joke.MyWay == false then return nil end
	end
	if pick == "A" then return "Good" end
	if pick == "B" then return "Evil" end
	for _, step in type(def) == "table" and def.Steps or {} do
		local obj = step.Obj
		if type(obj) == "table" and obj.Type == "Choice" then
			if pick == ((obj.Good and obj.Good.Pick) or "Good") then return "Good" end
			if pick == ((obj.Evil and obj.Evil.Pick) or "Evil") then return "Evil" end
		end
	end
	return nil
end

-- the repeated picks of a save (data.Story.N): the board's flat N.Kind (good) / N.Sneaky (devil) and every ChoiceCard kind's
-- N[kind] = { Good, Evil }
local function repeatedCounts(repeated)
	local good, evil = 0, 0
	for key, v in type(repeated) == "table" and repeated or {} do
		if key == "Kind" and type(v) == "number" then
			good += math.max(0, math.floor(v))
		elseif key == "Sneaky" and type(v) == "number" then
			evil += math.max(0, math.floor(v))
		elseif type(v) == "table" then
			good += math.max(0, math.floor(num(v.Good)))
			evil += math.max(0, math.floor(num(v.Evil)))
		end
	end
	return good, evil
end

-- the My Way id from the saved picks and the faction ("" = none yet: Neutral / None, or fewer than MinPicks picks).
-- `repeated` (data.Story.N, optional): A23-86 repeated cards weigh 1 story pick per MW.RepeatPer and never more than the
-- story picks together
function ReturnService.MyWayOf(faction, picks, repeated)
	if faction ~= "Halo" and faction ~= "Horns" then return "" end
	local good, evil = 0, 0
	for id, pick in type(picks) == "table" and picks or {} do
		local side = type(id) == "string" and sideOf(id, pick) or nil
		if side == "Good" then good += 1 elseif side == "Evil" then evil += 1 end
	end
	local total = good + evil
	if total < num(MW.MinPicks, 2) then return "" end
	local per = math.max(1, math.floor(num(MW.RepeatPer, 5)))
	local rg, re = repeatedCounts(repeated)
	local wg, we = math.floor(rg / per), math.floor(re / per)
	if wg + we > total then -- never more than the story picks together: both sides shrink in the same proportion
		local f = total / (wg + we)
		wg, we = math.floor(wg * f), math.floor(we * f)
	end
	good, evil = good + wg, evil + we
	total = good + evil
	local lean = good - evil
	if math.abs(lean) <= math.floor(total * num(MW.BalanceShare, 0.2)) then return "BalanceWalker" end
	if faction == "Halo" then return lean > 0 and "TrueKnight" or "RebelAngel" end
	return lean < 0 and "ProudRascal" or "SoftDevil"
end

-- (public: BoardService calls it after a finished job - its Kind / Sneaky count is a repeated pick too)
local function refreshMyWay(player)
	local data = getData(player)
	if not data then return end
	local story = type(data.Story) == "table" and data.Story or {}
	local id = ReturnService.MyWayOf(data.Faction, story.Pick, story.N)
	local name = id ~= "" and (MW.Names or {})[id] or ""
	player:SetAttribute("MyWay", name or "")
end

function ReturnService.RefreshMyWay(player)
	if typeof(player) == "Instance" and player:IsA("Player") then refreshMyWay(player) end
end

------------------------------------------------------------------ #2 badges
local function badgeTest(key, player, data)
	if key == "ChoseSide" then return data.Faction == "Halo" or data.Faction == "Horns" or data.Faction == "Neutral" end
	if key == "FirstSlime" then return num(data.TotalKills) > 0 end
	local story = type(data.Story) == "table" and data.Story or {}
	local done = type(story.Done) == "table" and story.Done or {}
	if key == "LostLunchbox" then return done.Lunch1 == true end
	if key == "Stronger" then
		local mask = math.floor(num(data.WeaponOwnedMask))
		return mask >= 0 and bit32.band(mask, bit32.bnot(1)) ~= 0 -- a weapon above the first tier
	end
	if key == "FirstSkill" then return num(data.SkillSlots) >= 1 end
	if key == "ShardChoice" then return done.S0 == true end
	if key == "Rank2" then
		local _, rank = Config.GetTitle(data.Faction, num(data.Honor), num(data.Infamy))
		return num(rank) >= 2
	end
	if key == "Halloween2026" then
		local r = type(data.Return) == "table" and data.Return or {}
		return r.Halloween == true or (type(data.Items) == "table" and num(data.Items.Candy) > 0)
	end
	return false
end

local function award(player, key, id)
	local userId = player.UserId
	local busy = T.Awarding[player]
	if not busy then
		busy = {}
		T.Awarding[player] = busy
	end
	if busy[key] then return end
	busy[key] = true
	task.spawn(function()
		local svc = game:GetService("BadgeService")
		-- 검수 review 2026-10-08: only a real award counts. AwardBadge answers false for a badge that is off / a wrong id
		-- (the user makes the 8 badges by hand at publishing) - and false or an error for one the player already has, so
		-- either asks UserHasBadgeAsync once before it goes the retry way
		local ok, res = pcall(svc.AwardBadge, svc, userId, id)
		local got = ok and res == true
		if not got then
			local okHas, has = pcall(svc.UserHasBadgeAsync, svc, userId, id)
			got = okHas and has == true
		end
		busy[key] = nil
		if got then
			local data = S.PlayerService.GetData(player)
			-- the badge id goes with the record: a corrected Config id is a badge this player still has to get
			if type(data) == "table" then record(data).Badges[key] = { Id = id, At = os.time() } end
		else
			-- a player who left while the call ran gets no retry entry (it would keep the Player object alive)
			if player.Parent ~= nil and T.Conns[player] ~= nil then
				T.BadgeRetry[player] = T.BadgeRetry[player] or {}
				T.BadgeRetry[player][key] = os.clock()
			end
			Util.Warn(TAG, "badge " .. key .. " (" .. tostring(id) .. "): " .. (ok and "not awarded" or tostring(res)))
		end
	end)
end

local function checkBadges(player)
	local data = getData(player)
	if not data or type(B.Ids) ~= "table" then return end
	-- repaired at the join; only a broken table is rebuilt (this runs on every kill while a badge is open)
	local r = data.Return
	if type(r) ~= "table" or type(r.Badges) ~= "table" then r = record(data) end
	for _, key in B.Order or {} do
		local id = math.floor(num(B.Ids[key]))
		local retry = T.BadgeRetry[player] and T.BadgeRetry[player][key]
		local rec = r.Badges[key]
		local have = type(rec) == "table" and rec.Id == id -- awarded under today's Config id
		if id > 0 and not have and (retry == nil or os.clock() - retry >= num(B.RetrySeconds, 300))
			and badgeTest(key, player, data) then
			award(player, key, id)
		end
	end
end

-- Halloween 2026: candy or a king beaten together during the season (the badge's own record)
local function markHalloween(player)
	local data = getData(player)
	if not data then return end
	local season = Config.Halloween
	if type(season) ~= "table" or season.Enabled == false or os.time() >= num(season.EndsAt, 0) then return end
	record(data).Halloween = true
	checkBadges(player)
end

------------------------------------------------------------------ #5 opt-in
-- the moment may come (why "Daily" | "Diary"): once ever (shown) / again after RetryCannot s when the client could not
-- prompt, one a session, not in the first MinPlaySeconds of play, not within Calm s of a KO / a failed scroll / a
-- purchase prompt. inCard = true: the caller puts it in the pause card (no Fx of its own). Returns true when it went out.
function optInMoment(player, why, inCard)
	local data = getData(player)
	if not data or T.OptInSent[player] then return false end
	local r = record(data)
	if r.OptIn == "shown" then return false end
	if r.OptIn == "cannot" and os.time() - r.OptInAt < num(N.RetryCannot, 30 * 86400) then return false end
	if num(data.PlaytimeSeconds) < num(N.MinPlaySeconds, 600) then return false end
	local now, calm = os.clock(), num(N.Calm, 60)
	for _, at in { T.KOAt[player], T.FailAt[player], T.BuyAt[player] } do
		if at and now - at < calm then return false end
	end
	T.OptInSent[player] = true
	if not inCard then fx(player, "OptInMoment", { Why = why }) end
	return true
end

function ReturnService.OptInMoment(player, why)
	return optInMoment(player, why, false)
end

local function askedStore()
	if T.AskedStore == nil then
		local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, Config.StoreName(N.Store or "HaloHorns_NotifyAsked_v1"))
		T.AskedStore = ok and store or false
	end
	return T.AskedStore or nil
end

-- ClientMetric "OptIn" (TelemetryService validates the value): "shown" = Roblox's prompt was shown and closed; "cannot" =
-- CanPromptOptInAsync said no (under 13, already decided, or Roblox's 30-day pause)
local function onOptInResult(player, result)
	local data = getData(player)
	if not data or (result ~= "shown" and result ~= "cannot") then return end
	local r = record(data)
	if r.OptIn == "shown" then return end
	r.OptIn, r.OptInAt = result, os.time()
	if result ~= "shown" then return end
	local userId = player.UserId
	task.spawn(function()
		local store = askedStore()
		if not store then return end
		local ok, err = pcall(store.SetAsync, store, tostring(userId), { At = os.time() })
		if not ok then Util.Warn(TAG, "asked list: " .. tostring(err)) end
	end)
end

------------------------------------------------------------------ join / leave
local function watch(player, attr, fn)
	T.Conns[player] = T.Conns[player] or {}
	table.insert(T.Conns[player], player:GetAttributeChangedSignal(attr):Connect(function()
		local ok, err = pcall(fn, player)
		if not ok then Util.Warn(TAG, attr .. ": " .. tostring(err)) end
	end))
end

local function onReady(player, data)
	if type(data) ~= "table" then data = S.PlayerService.GetData(player) end
	if type(data) ~= "table" then return end
	record(data)
	T.JoinedAt[player] = os.clock()
	for _, c in T.Conns[player] or {} do c:Disconnect() end
	T.Conns[player] = nil
	watch(player, "DailyClaims", onDailyClaims)
	for _, attr in { "WeaponOwnedMask", "SkillSlots", "Honor", "Infamy", "TotalKills" } do watch(player, attr, checkBadges) end
	refreshMyWay(player)
	checkBadges(player)
	-- welcome back: a real return (the last leave WelcomeAfter s ago), after the first mission and the class pick
	local last = num(data.LastLogoutTime)
	if last > 0 and os.time() - last >= num(R.WelcomeAfter, 6 * 3600) and data.ClassChosen == true
		and num(data.TutorialStep) == 99 then
		player:SetAttribute("Returned", true) -- A23-167 ②: the guide's "You're back!" line (client)
		task.delay(num(R.WelcomeDelay, 4), welcomeBack, player, last)
	end
	-- A23-167 ② the tomorrow card, After s into this session
	task.delay(num(TM.After, 600), tomorrowCard, player, T.JoinedAt[player], 0)
end

local function onLeaving(player)
	for _, c in T.Conns[player] or {} do c:Disconnect() end
	for _, t in { T.JoinedAt, T.CardAt, T.KOAt, T.FailAt, T.BuyAt, T.OptInSent, T.Awarding, T.BadgeRetry, T.Conns } do
		t[player] = nil
	end
end

local function connect(service, signal, fn)
	local svc = S[service]
	local sig = type(svc) == "table" and svc[signal] or nil
	if type(sig) == "table" and type(sig.Connect) == "function" then
		sig:Connect(function(...)
			local ok, err = pcall(fn, ...)
			if not ok then Util.Warn(TAG, service .. "." .. signal .. ": " .. tostring(err)) end
		end)
		return true
	end
	return false
end

-- test aid: how many players hold badge retry entries (a player who left must hold none)
function ReturnService.DebugRetryCount()
	local n = 0
	for _ in T.BadgeRetry do n += 1 end
	return n
end

function ReturnService.Init(registry)
	S = registry
end

function ReturnService.Start()
	buildChapterEnds()
	connect("PlayerService", "PlayerReady", onReady)
	connect("PlayerService", "PlayerLeaving", onLeaving)
	connect("StoryQuestService", "QuestDone", function(player, id)
		onQuestDone(player, id)
		checkBadges(player)
	end)
	connect("StoryQuestService", "Picked", function(player) refreshMyWay(player) end)
	connect("ChoiceCard", "Picked", function(player) refreshMyWay(player) end) -- A23-86: repeated cards weigh in too
	connect("FactionService", "FactionChanged", function(player)
		refreshMyWay(player)
		checkBadges(player)
	end)
	connect("WarService", "RoundEnded", onWarEnded)
	connect("GooseService", "GooseFinished", function(_result, _rewarded, info)
		if type(info) == "table" and info.Mode == "Pending" then return end -- nobody played that round (like the war's Idle)
		newsAdd("Goose") -- A23-167 ② news
	end)
	-- A23-167 ② this server's news counts go into the shared row every FlushSeconds and at the close
	task.spawn(function()
		while true do
			task.wait(num(NW.FlushSeconds, 300))
			local ok, err = pcall(newsFlush)
			if not ok then Util.Warn(TAG, "news flush: " .. tostring(err)) end
		end
	end)
	game:BindToClose(function()
		-- a periodic write may be in flight: wait for it (a failed one puts its batch back), then write what is left
		for _ = 1, 40 do -- at most 10 s of the close's 30
			if not T.News.Flushing then break end
			task.wait(0.25)
		end
		local ok, err = pcall(newsFlush)
		if not ok then Util.Warn(TAG, "news close: " .. tostring(err)) end
	end)
	connect("CombatService", "KnockedOut", function(player) T.KOAt[player] = os.clock() end)
	connect("LootService", "Enhanced", function(player, _tier, _before, _after, success)
		if success == false then T.FailAt[player] = os.clock() end
	end)
	connect("LootService", "ItemsGranted", function(player, list)
		for _, it in type(list) == "table" and list or {} do
			if type(it) == "table" and it.Id == "Candy" then markHalloween(player) end
		end
	end)
	connect("HalloweenService", "KingDefeated", function(_key, _kind, ids)
		for _, id in type(ids) == "table" and ids or {} do
			local p = type(id) == "number" and game:GetService("Players"):GetPlayerByUserId(id) or nil
			if p then markHalloween(p) end
		end
	end)
	connect("TelemetryService", "ClientMetric", function(player, id, arg)
		if id == "OptIn" then
			onOptInResult(player, arg)
		elseif id == "PurchasePrompt" then
			T.BuyAt[player] = os.clock()
		end
	end)
	print("[ReturnService] started")
end

return ReturnService
