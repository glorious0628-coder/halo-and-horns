-- DiaryService.luau : SPEC A23-79 #4 호박 대왕 일기 + 사탕 단지 (게임성 개발 3, 2026-10-08; contract
-- docs/design/return_server_2026-10-08.md §4). No streak, no countdown, nothing sold.
--   King Diary: the 9-day chatter of the two Halloween kings (Config.Halloween.Banter.Days) as a book. Each king beaten
--   together (HalloweenService.KingDefeated: the UserIds its kill paid, RewardMinHits rules unchanged) opens the next
--   page, but never past today's page (season day 1..9 from Banter.DayOneStart, KST; before day 1 = page 1). A late
--   player catches up one page per king. Page 9 -> the title Config.Diary.Title + Fx "DiaryDone" once. After page 1 the
--   notification opt-in moment may come (ReturnService.OptInMoment "Diary").
--   Candy jar: c->s "CandyTrade"(id) gives Config.CandyJar[id].Title for .Candy candy (data.Items.Candy), once per
--   title; open after the season too.
-- Save (additive, Version stays 3): data.Diary = { Pages = 0..9, Done = true once the last page's title was given }.
-- Attribute DiaryPages. Fx "DiaryPage" { Page, Today, Late } (owner). Signals: DiaryService.PageOpened(player, page,
-- late), DiaryService.CandyTraded(player, id, candy).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local DiaryService = {}
DiaryService.PageOpened = Util.Signal.new() -- (player, page, late: boolean)
DiaryService.CandyTraded = Util.Signal.new() -- (player, jar id, candy spent)

local TAG = "DiaryService"
local S = nil
local D = Config.Diary or {}
local JAR = Config.CandyJar or {}
local TXT = D.Text or {}
local HW = Config.Halloween or {}
local BANTER = HW.Banter or {}
local PAGES = #(BANTER.Days or {})

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function notify(player, text, kind, sound)
	if type(text) ~= "string" or text == "" then return end
	local ok, err = pcall(Net.Notify, player, text, kind or "reward", nil, sound)
	if not ok then Util.Warn(TAG, "notify: " .. tostring(err)) end
end

local function record(data)
	local d = data.Diary
	if type(d) ~= "table" then
		d = {}
		data.Diary = d
	end
	d.Pages = math.clamp(math.floor(num(d.Pages)), 0, PAGES)
	d.Done = d.Done == true
	return d
end

-- the season's page for `t` (os.time): day 1..PAGES from DayOneStart (before day 1 = 1)
local function todayPage(t)
	local start = num(BANTER.DayOneStart)
	return math.clamp(math.floor((t - start) / 86400) + 1, 1, PAGES)
end

local function seasonOn(t)
	return HW.Enabled ~= false and t < num(HW.EndsAt)
end

local function grantTitle(player, id)
	local titles = S.TitleService
	if type(id) ~= "string" or not Config.TitleDefs[id] or type(titles) ~= "table" or type(titles.Grant) ~= "function" then
		return false
	end
	local ok, res = pcall(titles.Grant, player, id)
	if not ok then Util.Warn(TAG, "title " .. id .. ": " .. tostring(res)) end
	return ok and res == true
end

local function publish(player, d)
	player:SetAttribute("DiaryPages", d.Pages)
end

-- a king beaten with this player paid: the next page, if today's page allows it
local function onKingBeaten(player)
	if not S.PlayerService.IsReady(player) or PAGES < 1 then return end
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return end
	local now = os.time()
	if not seasonOn(now) then return end
	local d = record(data)
	local today = todayPage(now)
	if d.Pages >= today then return end
	d.Pages += 1
	local page = d.Pages
	local late = page < today -- catching up a day already past
	publish(player, d)
	local ok, err = pcall(Net.Fx, player, "DiaryPage", { Page = page, Today = today, Late = late })
	if not ok then Util.Warn(TAG, "fx: " .. tostring(err)) end
	notify(player, string.format(TXT.Page or "King Diary: page %d!", page), "reward", "None")
	DiaryService.PageOpened:Fire(player, page, late)
	if page >= PAGES and not d.Done then
		d.Done = true
		if grantTitle(player, D.Title) then
			notify(player, string.format(TXT.NewTitle or "New title: %s!", Config.TitleDefs[D.Title].Name), "reward", "RankUp")
		end
		local okDone, errDone = pcall(Net.Fx, player, "DiaryDone", {})
		if not okDone then Util.Warn(TAG, "done fx: " .. tostring(errDone)) end
	end
	if page == 1 then
		local ret = S.ReturnService
		if type(ret) == "table" and type(ret.OptInMoment) == "function" then pcall(ret.OptInMoment, player, "Diary") end
	end
end

-- the pause card's "Tomorrow" line while a page is waiting (nil when the diary is done / the season is over)
function DiaryService.TomorrowLine(player)
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return nil end
	local tomorrow = os.time() + 86400
	if not seasonOn(tomorrow) then return nil end
	local d = record(data)
	if d.Pages >= PAGES then return nil end
	return string.format(TXT.Tomorrow or "King Diary page %d", d.Pages + 1)
end

------------------------------------------------------------------ candy jar
local function jarEntry(id)
	for _, e in JAR.Trades or {} do
		if e.Id == id then return e end
	end
	return nil
end

local function onCandyTrade(player, ...)
	if select("#", ...) ~= 1 then return end
	local id = ...
	if type(id) ~= "string" or #id > 32 then return end
	if not S.PlayerService.IsReady(player) then return end
	if not Util.RateLimit(player, "CandyTrade", num(Config.RateLimits.CandyTrade, 1)) then return end
	local e = jarEntry(id)
	if not e or not Config.TitleDefs[e.Title] then return end
	local titles = S.TitleService
	if type(titles) == "table" and type(titles.Owns) == "function" and titles.Owns(player, e.Title) then
		notify(player, TXT.JarOwned or "You already have it!", "info", "None")
		return
	end
	local cost = math.max(1, math.floor(num(e.Candy, 1)))
	local loot = S.LootService
	if type(loot) ~= "table" or type(loot.TakeItem) ~= "function" then return end
	local ok, taken = pcall(loot.TakeItem, player, "Candy", cost)
	if not ok or taken ~= true then
		notify(player, string.format(TXT.JarNeed or "You need %d candy.", cost), "info")
		return
	end
	if grantTitle(player, e.Title) then
		notify(player, string.format(TXT.NewTitle or "New title: %s!", Config.TitleDefs[e.Title].Name), "reward", "RankUp")
	end
	DiaryService.CandyTraded:Fire(player, id, cost)
end

------------------------------------------------------------------ join
local function onReady(player, data)
	if type(data) ~= "table" then data = S.PlayerService.GetData(player) end
	if type(data) ~= "table" then return end
	local d = record(data)
	-- a full book whose title came later (or was lost): given silently
	if d.Pages >= PAGES and PAGES > 0 then
		d.Done = true
		grantTitle(player, D.Title)
	end
	publish(player, d)
end

function DiaryService.Init(registry)
	S = registry
end

function DiaryService.Start()
	Net.Get("CandyTrade").OnServerEvent:Connect(function(player, ...)
		local ok, err = pcall(onCandyTrade, player, ...)
		if not ok then Util.Warn(TAG, "CandyTrade: " .. tostring(err)) end
	end)
	S.PlayerService.PlayerReady:Connect(function(player, data)
		local ok, err = pcall(onReady, player, data)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	local hw = S.HalloweenService
	if type(hw) == "table" and type(hw.KingDefeated) == "table" then
		hw.KingDefeated:Connect(function(_key, _kind, ids)
			for _, id in type(ids) == "table" and ids or {} do
				local p = type(id) == "number" and Players:GetPlayerByUserId(id) or nil
				if p then
					local ok, err = pcall(onKingBeaten, p)
					if not ok then Util.Warn(TAG, "king: " .. tostring(err)) end
				end
			end
		end)
	else
		Util.Warn(TAG, "HalloweenService.KingDefeated missing: no diary pages")
	end
	print("[DiaryService] started")
end

return DiaryService
