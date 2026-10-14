-- VillageFundService.luau : A23-178 the village fund (게임성 개발 2, 2026-10-14; contract
-- docs/design/village_fund_server_2026-10-14.md). A gold sink with no power: a Halo child gives Config.VillageFund.Step
-- gold at the Halo town fountain ('Share'), a Horns child at the Horns one ('Show off'); each gift = Points of the own
-- score (Honor / Infamy, shown as Mischief) through PlayerService.GrantFame (ctx Fund: never on the weekly boards), at
-- most PerDay gifts a KST day (Config.DayIndex, the attendance day). Neutral / no side / a side without a Spot: no fund.
--   - one invisible anchored part per Spot (Workspace.VillageFund.FundSpot_<side>) holds the ProximityPrompt "FundPrompt"
--     (ActionText "" + attributes ActionKey / ObjectKey / Faction: the client writes the words and hides the other
--     side's prompt). A trigger by a child of that side, alive and near: s->c "FundOpen" (the card's numbers).
--   - c->s "FundGive" (no arguments; anything sent is ignored): ready, own side's Spot, alive, within Radius (flat),
--     Config.RateLimits.FundGive, the switch VillageFund on, under PerDay today, ProgressionService.SpendGold(Step,
--     "Fund") -> data.FundDay / FundToday / FundGiven, GrantFame, the week's pending sum, one line, "FundOpen" again.
--   - the weekly sums: DataStore Config.StoreName(Store) (Studio: _STUDIO), key "W<Config.WeekIndex>", { Halo, Horns }
--     merged by adding (UpdateAsync) every FlushSeconds (x0.5..1.5) and at the close; a failed write keeps the gifts.
--     ReadSeconds: GetAsync of this week. Shown sum = stored + this server's unsaved. GameState attributes FundWeek,
--     FundHalo, FundHorns, FundLevelHalo, FundLevelHorns (0 / 1 lanterns / 2 + fireworks: looks only). A level reached
--     after this server's first read of the week = one line to that side's town (once a level a week).
--   VillageFundService.Give(player) / .OnPrompt(player, side) / .Flush() -> bool / .Read() / .SumOf(side) / .LevelOf(sum)
--   / .Pending() / .StateOf(player)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))
local Net = require(Shared:WaitForChild("Net"))

local VillageFundService = {}

local TAG = "VillageFundService"
local S = nil
local V = Config.VillageFund or {}
local TXT = V.Text or {}
local SIDES = { "Halo", "Horns" }
local X = {
	Pending = {}, -- [week] = { Halo = gold, Horns = gold } not written yet
	Stored = { Week = -1, Halo = 0, Horns = 0 }, -- the week's document as last read / written
	Base = {}, -- [week] = true once this server read that week (levels before it are never announced)
	Said = {}, -- ["<week>:<side>"] = the highest level announced (or seen at the first read)
	Prompts = {}, -- [ProximityPrompt] = side
	Parts = {}, -- [side] = the prompt's part
	Where = {}, -- [side] = the spot: the pivot of the fountain model Spot.Model once found (review 10/14), else Spot.Pos
	Found = {}, -- [side] = true once the model was found (the search stops)
	Writing = 0, -- weekly writes running now (the close waits for them)
	Store = nil, -- the DataStore, or false when it cannot be opened (Studio without API access)
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function on()
	return V.Enabled == true
end

-- the live switch VillageFund (Config.Switches): no switchboard (or a failing one) = on, like every other switch
local function switchOn()
	local sw = S and S.SwitchService
	if type(sw) ~= "table" or type(sw.On) ~= "function" then return true end
	local ok, value = pcall(sw.On, "VillageFund")
	return not ok or value ~= false
end

local function step() return math.max(1, math.floor(num(V.Step, 1000))) end
local function perDay() return math.max(1, math.floor(num(V.PerDay, 3))) end
local function today() return Config.DayIndex(os.time()) end
local function week() return Config.WeekIndex(os.time()) end

local function spotOf(side)
	local spots = type(V.Spots) == "table" and V.Spots or {}
	local s = type(side) == "string" and spots[side] or nil
	if type(s) == "table" and s.Pos ~= nil then return s end
	return nil
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function notify(player, text, kind, sound)
	if type(text) ~= "string" then return end
	pcall(Net.Notify, player, text, kind, nil, sound)
end

-- gifts already made today (another day's count is 0)
local function todayCount(data, day)
	if math.floor(num(data.FundDay)) ~= day then return 0 end
	return math.max(0, math.floor(num(data.FundToday)))
end

local function spotPos(side, spot)
	return X.Where[side] or spot.Pos
end

-- alive and within the Spot's Radius of its place (flat distance: the pool sits higher than the walk)
local function nearSpot(player, spot, side)
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or num(hum.Health) <= 0 then return false end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local p, c = root.Position, spotPos(side, spot)
	local dx, dz = num(p.X) - num(c.X), num(p.Z) - num(c.Z)
	local r = math.max(1, num(spot.Radius, 16))
	return dx * dx + dz * dz <= r * r
end

------------------------------------------------------------------ the week's sums
function VillageFundService.SumOf(side)
	local wk = week()
	local stored = X.Stored.Week == wk and num(X.Stored[side]) or 0
	local pend = X.Pending[wk]
	return math.max(0, stored + (pend and num(pend[side]) or 0))
end

function VillageFundService.LevelOf(sum)
	local g = type(V.Goals) == "table" and V.Goals or {}
	if sum >= num(g.Fireworks, math.huge) then return 2 end
	if sum >= num(g.Lanterns, math.huge) then return 1 end
	return 0
end

function VillageFundService.Pending()
	return table.clone(X.Pending)
end

-- the shown sums -> GameState; a level above the last one said (Read sets the levels already reached at this server's first
-- read of the week) -> one line to that town
local function publish()
	local wk = week()
	local okGs, gs = pcall(Net.GameState)
	if okGs and gs then
		gs:SetAttribute("FundWeek", wk)
	end
	for _, side in SIDES do
		local sum = VillageFundService.SumOf(side)
		local level = VillageFundService.LevelOf(sum)
		if okGs and gs then
			gs:SetAttribute("Fund" .. side, sum)
			gs:SetAttribute("FundLevel" .. side, level)
		end
		local key = wk .. ":" .. side
		local spot = spotOf(side)
		if X.Base[wk] and spot and level > num(X.Said[key]) then
			X.Said[key] = level
			local line = type(TXT[side]) == "table" and TXT[side][level >= 2 and "Fireworks" or "Lanterns"] or nil
			local ok, list = pcall(S.PlayerService.GetReadyPlayers)
			local zones = S.ZoneService
			for _, p in (ok and type(zones) == "table") and list or {} do
				local okZ, zone = pcall(zones.GetZoneId, p)
				if okZ and zone == spot.Zone then notify(p, line, "reward", "None") end
			end
		end
	end
end

local function sanitize(doc)
	doc = type(doc) == "table" and doc or {}
	return { Halo = math.max(0, num(doc.Halo)), Horns = math.max(0, num(doc.Horns)) }
end

local function merge(old, add)
	local a, b = sanitize(old), sanitize(add)
	return { V = 1, Halo = a.Halo + b.Halo, Horns = a.Horns + b.Horns }
end

local function store()
	if X.Store == nil then
		local base = V.Store or "HaloHorns_VillageFund_v1"
		local name = Config.StoreName and Config.StoreName(base) or base
		if RunService:IsStudio() then name ..= "_STUDIO" end
		local ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, name)
		X.Store = ok and st or false
	end
	return X.Store or nil
end

local function keyOf(wk)
	return "W" .. tostring(wk)
end

-- adds this server's unsaved gifts to each week's document; true when nothing is left unsaved
function VillageFundService.Flush()
	if next(X.Pending) == nil then return true end
	local st = store()
	if not st then return false end
	local mine = X.Pending
	X.Pending = {} -- gifts made while the writes wait go to the next flush
	X.Writing += 1
	local all = true
	for wk, sums in mine do
		local ok, res = pcall(st.UpdateAsync, st, keyOf(wk), function(old)
			return merge(old, sums)
		end)
		if ok then
			if wk == week() and type(res) == "table" then
				local doc = sanitize(res)
				X.Stored = { Week = wk, Halo = doc.Halo, Horns = doc.Horns }
			end
		else
			all = false
			Util.Warn(TAG, "save: " .. tostring(res))
			local back = X.Pending[wk] or {}
			for _, side in SIDES do back[side] = num(back[side]) + num(sums[side]) end
			X.Pending[wk] = back
		end
	end
	X.Writing -= 1
	publish()
	return all
end

-- this week's document; the first GOOD read of a week sets the levels already reached (never announced; review 10/14:
-- a failed read is no base). No DataStore at all (Studio without API access): this server's own sums are all there is
function VillageFundService.Read()
	local wk = week()
	local st = store()
	local okRead = st == nil
	if st then
		local ok, res = pcall(st.GetAsync, st, keyOf(wk))
		if ok then
			local doc = sanitize(res)
			X.Stored = { Week = wk, Halo = doc.Halo, Horns = doc.Horns }
			okRead = true
		else
			Util.Warn(TAG, "read: " .. tostring(res))
		end
	end
	if okRead and not X.Base[wk] then
		X.Base[wk] = true
		for _, side in SIDES do
			X.Said[wk .. ":" .. side] = VillageFundService.LevelOf(VillageFundService.SumOf(side))
		end
	end
	publish()
end

local function addPending(side, n)
	local wk = week()
	local p = X.Pending[wk] or {}
	p[side] = num(p[side]) + n
	X.Pending[wk] = p
end

------------------------------------------------------------------ the card and the gift
function VillageFundService.StateOf(player)
	local data = getData(player)
	if not data then return nil end
	local side = data.Faction
	local count = todayCount(data, today())
	local okG, gold = pcall(S.ProgressionService.GetTotalGold, player)
	gold = okG and math.max(0, math.floor(num(gold))) or 0
	local why = nil
	if not on() or not switchOn() then
		why = "Closed"
	elseif count >= perDay() then
		why = "Full"
	elseif gold < step() then
		why = "Poor"
	end
	local sum = VillageFundService.SumOf(side)
	local g = type(V.Goals) == "table" and V.Goals or {}
	return { Faction = side, Today = count, PerDay = perDay(), Step = step(), Gold = gold, Can = why == nil, Why = why,
		Week = week(), Sum = sum, Goals = { Lanterns = num(g.Lanterns), Fireworks = num(g.Fireworks) },
		Level = VillageFundService.LevelOf(sum) }
end

local function open(player)
	local st = VillageFundService.StateOf(player)
	if not st then return end
	-- the remote names come with 게임성 개발 1's screen branch: a missing one is a warning, never a stop
	local ok, remote = pcall(Net.Get, "FundOpen")
	if ok and remote then remote:FireClient(player, st) end
end

-- the side's own child, ready, alive and near its Spot (the prompt and the gift alike)
local function allowed(player, data)
	if not S.PlayerService.IsReady(player) then return nil end
	local spot = spotOf(data.Faction)
	if not spot or not nearSpot(player, spot, data.Faction) then return nil end
	return spot
end

function VillageFundService.OnPrompt(player, side)
	if not on() then return end
	local data = getData(player)
	if not data or data.Faction ~= side or not allowed(player, data) then return end
	open(player)
end

function VillageFundService.Give(player)
	if not on() then return end
	if not Util.RateLimit(player, "FundGive", num(Config.RateLimits and Config.RateLimits.FundGive, 1)) then return end
	local data = getData(player)
	if not data or not allowed(player, data) then return end
	local side = data.Faction
	if not switchOn() then
		notify(player, TXT.Closed, "bad")
		open(player)
		return
	end
	local day = today()
	local count = todayCount(data, day)
	if count >= perDay() then
		notify(player, type(TXT.Full) == "string" and string.format(TXT.Full, perDay()) or nil, "bad")
		open(player)
		return
	end
	local n = step()
	if S.ProgressionService.SpendGold(player, n, "Fund") ~= true then
		notify(player, type(TXT.Poor) == "string" and string.format(TXT.Poor, Util.FormatInt(n)) or nil, "bad")
		open(player)
		return
	end
	-- paid: the record, the score, the week's sum, the line (nothing below can stop the gift)
	data.FundDay = day
	data.FundToday = count + 1
	data.FundGiven = math.max(0, num(data.FundGiven)) + n
	local stat = type(V.Stat) == "table" and V.Stat[side] or nil
	local points = math.max(1, math.floor(num(V.Points, 1)))
	if stat then
		local ok, err = pcall(S.PlayerService.GrantFame, player, stat, points, { Fund = true })
		if not ok then Util.Warn(TAG, "fame: " .. tostring(err)) end
	end
	addPending(side, n)
	local line = type(TXT[side]) == "table" and TXT[side].Done or nil
	notify(player, type(line) == "string" and string.format(line, Util.FormatInt(n), points) or nil, "reward", "RankUp")
	publish()
	open(player)
end

------------------------------------------------------------------ the fountain prompts
-- review 10/14: the fountain model named Spot.Model, anywhere in the Workspace, is the spot (its pivot); until it is
-- found (a map built later, the stage-6 swap) the spot is Spot.Pos. The prompt's part follows it (Lift studs higher).
local function resolveSpots()
	local Workspace = game:GetService("Workspace")
	for _, side in SIDES do
		local spot = spotOf(side)
		if spot and type(spot.Model) == "string" and not X.Found[side] then
			local okF, m = pcall(Workspace.FindFirstChild, Workspace, spot.Model, true)
			if okF and m and (m:IsA("Model") or m:IsA("BasePart")) then
				local okP, cf = pcall(m.GetPivot, m)
				if okP and cf then
					X.Where[side] = cf.Position
					X.Found[side] = true
					local part = X.Parts[side]
					if part then part.Position = cf.Position + Vector3.new(0, num(spot.Lift, 3), 0) end
				end
			end
		end
	end
end

local function placePrompts()
	local Workspace = game:GetService("Workspace")
	local folder = Instance.new("Folder")
	folder.Name = "VillageFund"
	for _, side in SIDES do
		local spot = spotOf(side)
		if spot then
			local part = Instance.new("Part")
			part.Name = "FundSpot_" .. side
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
			part.Size = Vector3.new(1, 1, 1)
			part.Position = spotPos(side, spot) + Vector3.new(0, num(spot.Lift, 3), 0)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "FundPrompt"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = math.max(1, num(spot.Radius, 16))
			prompt.RequiresLineOfSight = false
			prompt.ActionText = ""
			prompt.ObjectText = ""
			prompt:SetAttribute("ActionKey", "Config.VillageFund.Text." .. side .. ".Prompt")
			prompt:SetAttribute("ObjectKey", "Config.VillageFund.Text.Title")
			prompt:SetAttribute("Faction", side)
			prompt.Parent = part
			part.Parent = folder
			X.Parts[side] = part
			X.Prompts[prompt] = side
		end
	end
	folder.Parent = Workspace
end

function VillageFundService.Init(registry)
	S = registry
end

function VillageFundService.Start()
	if not on() then return end
	local okS, errS = pcall(resolveSpots)
	if not okS then Util.Warn(TAG, "spots: " .. tostring(errS)) end
	local okP, errP = pcall(placePrompts)
	if not okP then Util.Warn(TAG, "prompts: " .. tostring(errP)) end
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
		local side = X.Prompts[prompt]
		if not side then return end
		local ok, err = pcall(VillageFundService.OnPrompt, player, side)
		if not ok then Util.Warn(TAG, "prompt: " .. tostring(err)) end
	end)
	local okR, remote = pcall(Net.Get, "FundGive")
	if okR and remote then
		remote.OnServerEvent:Connect(function(player)
			local ok, err = pcall(VillageFundService.Give, player)
			if not ok then Util.Warn(TAG, "FundGive: " .. tostring(err)) end
		end)
	else
		Util.Warn(TAG, "no FundGive remote (Net.Names): gifts are off")
	end
	task.spawn(function()
		local every = math.max(30, num(V.ReadSeconds, 60))
		while true do
			pcall(resolveSpots) -- a fountain built after the start is picked up here
			pcall(VillageFundService.Read)
			task.wait(every)
		end
	end)
	task.spawn(function()
		local every = math.max(30, num(V.FlushSeconds, 60))
		while true do
			task.wait(every * (0.5 + Util.Random:NextNumber())) -- servers do not all write in the same second
			pcall(VillageFundService.Flush)
		end
	end)
	game:BindToClose(function()
		-- review 10/14: a periodic write still running holds gifts that are no longer pending: wait for it, then write the rest
		local t0 = os.clock()
		while X.Writing > 0 and os.clock() - t0 < num(V.CloseWait, 20) do
			task.wait(0.2)
		end
		pcall(VillageFundService.Flush)
	end)
	print("[VillageFundService] started")
end

return VillageFundService
