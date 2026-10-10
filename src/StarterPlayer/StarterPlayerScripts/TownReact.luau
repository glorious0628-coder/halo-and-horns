-- TownReact.luau : A23-64 ① / A23-113 ⑥ (user 2026-10-10 "마감 전 넣자") - the town people notice my lean. A town person
-- (a Model tagged Config.TownReact.Tag, "TownFolk": TownNpcs' Folk entries) says one short line over its head while I
-- am within Range studs: once every Every s per person, at most one bubble at a time, Show s long, never while a window
-- is open (Panels) or before my data / side are in. The line comes from Config.TownReactLines (my rank, My Way lean and,
-- in my own town, my last town pick): a new TownPick is said first, once, while it is newer than PickFirst s; after that
-- the lines are picked at random, never the same one twice in a row for one person. No judging, no lessons (the lines
-- are game dev 2 / 3's table); no sound; the round code bubble of MonsterLabels (B.Make) sized for a sentence.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

local TownReact = {}
local LocalPlayer = Players.LocalPlayer
local C = nil
local R = type(Config.TownReact) == "table" and Config.TownReact or {}
-- Tick = s between checks; Size = bubble px for a sentence (3 short lines); Lift = studs above the head
local T = { Tick = 1, Size = { 196, 86 }, Lift = 0.6 }
-- NextAt[model] = os.clock() when it may speak again; Last[model] = its last line; Pick = { Value, At } the TownPick seen
local S = { NextAt = setmetatable({}, { __mode = "k" }), Last = setmetatable({}, { __mode = "k" }),
	Pick = { Init = false }, BusyUntil = 0, Started = false }

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default
end

local function attr(name)
	return LocalPlayer:GetAttribute(name)
end

-- the town person's town (its attribute Town, else the zone it stands in)
function TownReact.TownOf(npc)
	local t = npc:GetAttribute("Town")
	if type(t) == "string" and t ~= "" then return t end
	local ok, pos = pcall(function() return npc:GetPivot().Position end)
	if not ok or type(Config.ZoneAt) ~= "function" then return nil end
	local ok2, zone = pcall(Config.ZoneAt, pos)
	return ok2 and type(zone) == "table" and zone.Id or nil
end

-- pure: the line one person says now, or nil. lines / pickLine = Config.TownReactLines; last = its previous line;
-- pickFresh = my TownPick is newer than PickFirst and not said yet; roll(n) -> 1..n
function TownReact.Choose(lines, pickLine, last, pickFresh, roll)
	if type(lines) ~= "table" or #lines == 0 then return nil end
	if pickFresh and type(pickLine) == "string" then return pickLine end
	local pool = {}
	for _, l in lines do
		if l ~= last then table.insert(pool, l) end
	end
	if #pool == 0 then pool = lines end
	return pool[roll(#pool)]
end

local function myRoot()
	local ch = LocalPlayer.Character
	return ch and ch:FindFirstChild("HumanoidRootPart") or nil
end

local function windowOpen()
	local panels = C and C.Panels
	if type(panels) == "table" and type(panels.IsOpen) == "function" then
		local ok, open = pcall(panels.IsOpen)
		if ok and open then return true end
	end
	return false
end

-- one check: the nearest town person in range that may speak, says its line
function TownReact.Step(now)
	now = now or os.clock()
	if R.Enabled ~= true or now < S.BusyUntil then return nil end
	if attr("DataLoaded") ~= true or attr("ClassChosen") ~= true or windowOpen() then return nil end
	local root = myRoot()
	if not root then return nil end
	local pick = attr("TownPick")
	if not S.Pick.Init then
		S.Pick = { Init = true, Value = pick, At = now, Said = true } -- the join's saved pick is old news
	elseif pick ~= S.Pick.Value then
		S.Pick = { Init = true, Value = pick, At = now, Said = false } -- a new pick is said first
	end
	local best, bestD = nil, num(R.Range, 30)
	for _, npc in CollectionService:GetTagged(R.Tag or "TownFolk") do
		if npc:IsA("Model") and npc:IsDescendantOf(workspace) and now >= (S.NextAt[npc] or 0) then
			local ok, pos = pcall(function() return npc:GetPivot().Position end)
			local d = ok and (pos - root.Position).Magnitude or math.huge
			if d <= bestD then best, bestD = npc, d end
		end
	end
	if not best then return nil end
	local lines, pickLine = Config.TownReactLines({ Faction = attr("Faction"), Honor = attr("Honor"), Infamy = attr("Infamy"),
		MyWay = attr("MyWay"), TownPick = pick, Town = TownReact.TownOf(best) })
	local fresh = not S.Pick.Said and now - S.Pick.At <= num(R.PickFirst, 600)
	local line = TownReact.Choose(lines, pickLine, S.Last[best], fresh, function(n) return math.random(1, n) end)
	S.NextAt[best] = now + num(R.Every, 30)
	if not line then return nil end
	if line == pickLine then S.Pick.Said = true end
	S.Last[best] = line
	S.BusyUntil = now + num(R.Show, 4) + 0.5
	TownReact.Say(best, line)
	return best, line
end

-- the bubble over the person's head (MonsterLabels' round code bubble, sentence-sized), gone after Show s
function TownReact.Say(npc, line)
	local head = npc:FindFirstChild("Head") or npc.PrimaryPart
	local labels = C and C.MonsterLabels
	local B = type(labels) == "table" and labels.Bark or nil
	if not head or type(B) ~= "table" or type(B.Make) ~= "function" then return end
	local ok, bubble, fadeOut = pcall(B.Make, head, T.Lift, line, nil, T.Size)
	if not ok or not bubble then return end
	bubble.Name = "TownReactBubble"
	local show = num(R.Show, 4)
	if fadeOut then task.delay(math.max(0, show - (num(B.Out, 0.18))), fadeOut) end
	task.delay(show, function()
		if bubble.Parent then bubble:Destroy() end
	end)
end

function TownReact.Init(registry)
	C = registry
end

function TownReact.Start()
	if S.Started then return end
	S.Started = true
	task.spawn(function()
		while true do
			task.wait(T.Tick)
			local ok, err = pcall(TownReact.Step)
			if not ok then warn("[TownReact] " .. tostring(err)) end
		end
	end)
end

-- test aid
TownReact.State = S

return TownReact
