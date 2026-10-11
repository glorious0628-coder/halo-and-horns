-- TamerService.luau : the pet tamer's monster research (게임성 개발 3, 2026-10-12; contract
-- docs/design/tamer_server_2026-10-12.md §1; crafting_market §4, A23-115 "몬스터에 대한 연구력이 높아지면 그 몬스터를 닮은
-- 펫을 소환"). Switched by Config.Features.Research (off).
--   * Every kill the tamer (Config.IsTamer: the artisan Archer, class picked) is paid for (MonsterService.MonsterKilled,
--     not a MinorShare share; auto combat too: the pet fights for this class) gives 1 point in the monster's family
--     (Config.MonsterFamily) -> data.Research.Pts. A new family past Config.SaveV4.MaxKeys is not counted.
--   * A new stage (Config.Research.Stages) says so once (key Config.Research.Text.Stage, families with a name only).
--   * s->c TamerInfo { Pts, Stage, Sum, Stages } at PlayerReady and after points change (at most once every InfoEvery
--     seconds; a new stage at once).
-- The summon recipes (CraftService, Kind "Pet") read the points with TamerService.Points; a summon adds Sum (AddSummon).
--   TamerService.Points(player, family) · Stage(player, family) · AddSummon(player, family) · OnKilled(player, info)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local TamerService = {}
TamerService.StageUp = Util.Signal.new() -- (player, family, stage)

local TAG = "TamerService"
local S = nil
local ST = {
	Sent = {}, -- [Player] = os.clock() of the last TamerInfo
	Waiting = {}, -- [Player] = true while a TamerInfo is waiting for its turn
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function on()
	return Config.FeatureOn("Research") and type(Config.Research) == "table"
end

local function getData(player)
	if not S then return nil end
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function isTamer(data)
	return type(data) == "table" and data.ClassChosen == true and Config.IsTamer(data.Class, data.Faction)
end

local function researchOf(data)
	if type(data.Research) ~= "table" or type(data.Research.Pts) ~= "table" or type(data.Research.Sum) ~= "table" then
		data.Research = Config.SanitizeResearch(data.Research)
	end
	return data.Research
end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

local function send(player, data)
	ST.Sent[player] = os.clock()
	local r = researchOf(data)
	local stage = {}
	for fam, pts in r.Pts do stage[fam] = Config.ResearchStage(pts) end
	local ok, err = pcall(function()
		Net.Get("TamerInfo"):FireClient(player, { Pts = table.clone(r.Pts), Stage = stage, Sum = table.clone(r.Sum),
			Stages = table.clone(Config.Research.Stages) })
	end)
	if not ok then Util.Warn(TAG, "TamerInfo: " .. tostring(err)) end
end

-- TamerInfo now, or once the InfoEvery wait is over (one waiting send per player)
local function sendSoon(player, data, now)
	local gap = num(Config.Research.InfoEvery, 1)
	local last = ST.Sent[player]
	if now or not last or os.clock() - last >= gap then
		ST.Waiting[player] = nil
		send(player, data)
		return
	end
	if ST.Waiting[player] then return end
	ST.Waiting[player] = true
	task.delay(gap - (os.clock() - last), function()
		if not ST.Waiting[player] then return end
		ST.Waiting[player] = nil
		if player.Parent ~= Players then return end
		local d = getData(player)
		if d then send(player, d) end
	end)
end

function TamerService.Points(player, family)
	local data = getData(player)
	if not data or type(family) ~= "string" then return 0 end
	return math.floor(num(researchOf(data).Pts[family]))
end

function TamerService.Stage(player, family)
	return Config.ResearchStage(TamerService.Points(player, family))
end

-- a summon of that family (CraftService after the pet is in): Sum + 1
function TamerService.AddSummon(player, family)
	local data = getData(player)
	if not data or type(family) ~= "string" then return false end
	local r = researchOf(data)
	if r.Sum[family] == nil and count(r.Sum) >= Config.SaveV4.MaxKeys then return false end
	r.Sum[family] = math.min(Config.SaveV4.MaxCount, math.floor(num(r.Sum[family])) + 1)
	sendSoon(player, data, true)
	return true
end

function TamerService.OnKilled(player, info)
	if not on() or typeof(player) ~= "Instance" or not player:IsA("Player") or type(info) ~= "table" then return end
	if info.Minor == true then return end
	local data = getData(player)
	if not isTamer(data) then return end
	local fam = Config.MonsterFamily(info.Kind)
	if not fam then return end
	local r = researchOf(data)
	if r.Pts[fam] == nil and count(r.Pts) >= Config.SaveV4.MaxKeys then return end
	local before = math.floor(num(r.Pts[fam]))
	local after = math.min(Config.SaveV4.MaxCount, before + 1)
	r.Pts[fam] = after
	local s0, s1 = Config.ResearchStage(before), Config.ResearchStage(after)
	if s1 > s0 then
		if type(Config.Research.Text.Names[fam]) == "string" then
			local ok, err = pcall(Net.NotifyKey, player, "Config.Research.Text.Stage",
				{ { Key = "Config.Research.Text.Names." .. fam }, tostring(s1) }, "reward")
			if not ok then Util.Warn(TAG, "stage notice: " .. tostring(err)) end
		end
		TamerService.StageUp:Fire(player, fam, s1)
	end
	sendSoon(player, data, s1 > s0)
end

local function forget(player)
	ST.Sent[player], ST.Waiting[player] = nil, nil
end

function TamerService.Init(services)
	S = services
end

function TamerService.Start()
	if S.MonsterService and S.MonsterService.MonsterKilled then
		S.MonsterService.MonsterKilled:Connect(function(player, info)
			local ok, err = pcall(TamerService.OnKilled, player, info)
			if not ok then Util.Warn(TAG, "kill: " .. tostring(err)) end
		end)
	end
	S.PlayerService.PlayerReady:Connect(function(player)
		local ok, err = pcall(function()
			if not on() then return end
			local data = getData(player)
			if isTamer(data) then send(player, data) end
		end)
		if not ok then Util.Warn(TAG, "ready: " .. tostring(err)) end
	end)
	Players.PlayerRemoving:Connect(forget)
	print("[TamerService] started")
end

return TamerService
