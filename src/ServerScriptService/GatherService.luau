-- GatherService.luau : gathering (게임성 개발 3, 2026-10-11; contract docs/design/gather_server_2026-10-11.md, background
-- gathering_2026-10-06.md). Everyone (Halo, Horns, artisans) the same: hold the interact key at a herb bush / ore rock
-- (Config.Gather.Nodes) and get one material (Double = the chance of two). No XP, scroll, weapon or potion; auto combat
-- never gathers (the only way in is a held ProximityPrompt). Switched by Config.Features.Gathering: off = no node is
-- built and every handler returns at once.
--   * Nodes: workspace.Map.GatherNodes, one Model per spot (attributes GatherId "<Zone>:<n>", GatherKind) with the
--     ProximityPrompt "GatherPrompt" (HoldDuration = the node's Hold, ActionText / ObjectText "" + attributes ActionKey /
--     ObjectKey: the client writes the words, A23-111). Spots: WorldKit parts tagged "GatherSpot" (attribute Node = a
--     kind) replace a zone's Config.Gather.Spots list. Look: ServerStorage.GatherKit[kind], else a one-part stand-in.
--     The server never changes a prompt's Enabled after building it (the client dims the nodes resting for me only).
--   * A gather counts only when, in this order: the switch is on, the node is ours, the player is alive with a class
--     and a side; the hold began on this node at least Hold x MinHoldRatio s before (PromptButtonHoldBegan); the root is
--     within ServerRange; one gather per Config.RateLimits.Gather s; this node is not resting for me (Regrow s, server
--     memory only); fewer than DailyCap gathers today (KST, data.Gather.N); no other player hit me since the hold began
--     (CombatService.PlayerDamaged; monsters do not count). A full bag gives nothing and counts nothing.
--   * Plant nodes may open a Shard Bloom (ChoiceCard "ShardBloom", timed): the first sure once Total reaches FirstAt,
--     else Chance, at most DailyMax a day and never while another card is open. Good = the card's 2 + 1 to every other
--     player within Radius (each takes at most GiftDailyMax a day), Evil = the card's 3, time up = 1. Points: Deeds,
--     through the card (an artisan's pick scores nothing).
-- Save: data.Gather = { Day, N, Bloom, Gift, Total, FirstBloom } (Config.SanitizeGather; Day = the KST day of N / Bloom /
-- Gift). Net: s->c "GatherState" { Ready = { [GatherId] = server time }, N, Cap }, Fx "Gather" { Id, Artisan = true } for
-- an artisan's touch (looks only), the items' Fx "Loot" (LootService.GrantItems), notices by key only (Net.NotifyKey).
--   GatherService.Try(player, id, hold) -> "ok" | reason   one gather (the prompt handler; public for the offline test)
--   GatherService.Build() / Nodes()                          build the nodes / { [GatherId] = node }
-- Signal: Gathered(player, itemId, n, kind) (quests and telemetry listen).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Util = require(Shared:WaitForChild("Util"))

local GatherService = {}
GatherService.Gathered = Util.Signal.new() -- (player, itemId, n, kind)

local TAG = "GatherService"
local S = nil
local rng = Random.new()
local ST = {
	Nodes = {}, -- [GatherId] = { Id, Kind, Def, Model, Prompt, Pos }
	ByPrompt = {}, -- [ProximityPrompt] = GatherId
	Hold = {}, -- [Player] = { Id, T0 = os.clock() the hold began, Ended = os.clock() it ended | nil, Hit = true | nil }
	Rest = {}, -- [Player] = { [GatherId] = os.time() the node is ready again for this player }
	CapSaid = {}, -- [Player] = the KST day the DailyCap notice was shown
	Bloom = {}, -- [Player] = { Id, Pos } the Shard Bloom card that is open
	Hour = {}, -- [Player] = { T0 = os.clock(), N } gathers in the running hour (Telemetry "GatherHeavy")
	LastPos = {}, -- [Player] = the root position at the last sample (the jump watch)
	Jumped = {}, -- [Player] = os.clock() of the last jump (a teleport / fling: > JumpStuds between two samples)
	Folder = nil,
	StaleHold = 1, -- seconds a hold that ended still counts (the trigger can arrive just after the release)
}

local function num(v, default)
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
	return default or 0
end

local function G()
	return type(Config.Gather) == "table" and Config.Gather or {}
end

local function on()
	return Config.FeatureOn("Gathering") and type(Config.Gather) == "table"
end

local function getData(player)
	local ok, data = pcall(S.PlayerService.GetData, player)
	return ok and type(data) == "table" and data or nil
end

local function rootOf(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root or nil
end

local function today()
	return Config.DayIndex(os.time())
end

local function notify(player, key, kind)
	local ok, err = pcall(Net.NotifyKey, player, "Config.Gather.Text." .. key, nil, kind or "info")
	if not ok then Util.Warn(TAG, "notice " .. key .. ": " .. tostring(err)) end
end

-- data.Gather repaired, its day counters started over on a new KST day
local function gatherOf(data)
	local g = data.Gather
	if type(g) ~= "table" then
		g = Config.SanitizeGather(g)
		data.Gather = g
	end
	local day = today()
	if num(g.Day) ~= day then
		g.Day, g.N, g.Bloom, g.Gift = day, 0, 0, 0
	end
	return g
end

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and type(t) == "number" and t or os.time()
end

local function sendState(player, data)
	local g = gatherOf(data)
	local ready, now, snow = {}, os.time(), serverNow()
	for id, t in ST.Rest[player] or {} do
		if t > now then ready[id] = snow + (t - now) end
	end
	local ok, err = pcall(function()
		Net.Get("GatherState"):FireClient(player, { Ready = ready, N = g.N, Cap = num(G().DailyCap, 400) })
	end)
	if not ok then Util.Warn(TAG, "GatherState: " .. tostring(err)) end
end

------------------------------------------------------------------ nodes
-- the ground under a spot (one downward ray that skips characters, monsters and the nodes); y = 0 when nothing is hit
local function groundAt(pos)
	local ray = G().Ray or {}
	local from, length = num(ray.From, 300), num(ray.Length, 600)
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { ST.Folder }
		local monsters = workspace:FindFirstChild("Monsters")
		if monsters then table.insert(skip, monsters) end
		for _, p in Players:GetPlayers() do
			if p.Character then table.insert(skip, p.Character) end
		end
		params.FilterDescendantsInstances = skip
		return workspace:Raycast(Vector3.new(pos.X, from, pos.Z), Vector3.new(0, -length, 0), params)
	end)
	if ok and hit then return Vector3.new(pos.X, hit.Position.Y, pos.Z) end
	return Vector3.new(pos.X, 0, pos.Z)
end

-- the node's look: the kit model (pivot at its foot) or a one-part stand-in; returns model, the part that holds the prompt
local function makeModel(kind, def)
	local kit = ServerStorage:FindFirstChild("GatherKit")
	local src = kit and kit:FindFirstChild(kind)
	if src and src:IsA("Model") then
		local ok, model = pcall(function() return src:Clone() end)
		if ok and model then
			local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
			if part then return model, part end
			model:Destroy()
		end
	end
	local model = Instance.new("Model")
	local part = Instance.new("Part")
	part.Name = "Body"
	part.Anchored = true
	part.CanCollide = false
	part.Shape = def.Plant and Enum.PartType.Ball or Enum.PartType.Block
	part.Size = def.Plant and Vector3.new(3, 3, 3) or Vector3.new(4, 3, 4)
	part.Color = typeof(def.Color) == "Color3" and def.Color or Color3.new(1, 1, 1)
	part.CFrame = CFrame.new(0, part.Size.Y / 2, 0)
	part.PivotOffset = CFrame.new(0, -part.Size.Y / 2, 0) -- the model's pivot is its foot, like a kit model
	part.Parent = model
	model.PrimaryPart = part
	return model, part
end

local function makeNode(id, kind, pos)
	local def = G().Nodes[kind]
	local item = def and Config.Loot.Items[def.Item]
	if not item then return nil end
	local model, part = makeModel(kind, def)
	model.Name = kind
	model:SetAttribute("GatherId", id)
	model:SetAttribute("GatherKind", kind)
	local foot = groundAt(pos)
	model:PivotTo(CFrame.new(foot))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GatherPrompt"
	prompt.HoldDuration = num(def.Hold, 1.5)
	prompt.MaxActivationDistance = num(G().PromptRange, 8)
	prompt.RequiresLineOfSight = false
	prompt.ActionText = ""
	prompt.ObjectText = ""
	prompt:SetAttribute("ActionKey", "Config.Gather.Text." .. (def.Action == "Mine" and "Mine" or "Pick"))
	prompt:SetAttribute("ObjectKey", "Config.Loot.Items." .. def.Item .. ".Name")
	prompt.Parent = part
	model.Parent = ST.Folder
	local node = { Id = id, Kind = kind, Def = def, Model = model, Prompt = prompt, Pos = foot }
	ST.Nodes[id] = node
	ST.ByPrompt[prompt] = id
	return node
end

-- { zone = { { kind, pos }, ... } }: tagged WorldKit spots replace that zone's Config list
local function spotLists()
	local cfg = G()
	local tagged = {}
	for _, part in CollectionService:GetTagged("GatherSpot") do
		if part:IsA("BasePart") then
			local kind = part:GetAttribute("Node")
			local def = type(kind) == "string" and cfg.Nodes[kind]
			if def and type(def.Zone) == "string" then
				tagged[def.Zone] = tagged[def.Zone] or {}
				table.insert(tagged[def.Zone], { kind, part.Position })
			end
		end
	end
	local out = {}
	for zone, list in tagged do
		table.sort(list, function(a, b)
			if a[2].X ~= b[2].X then return a[2].X < b[2].X end
			return a[2].Z < b[2].Z
		end)
		out[zone] = list
	end
	for zone, list in cfg.Spots or {} do
		if not out[zone] then
			local spots = {}
			for _, s in list do
				local pos = cfg.Nodes[s[1]] and Config.GatherSpotPos(zone, s[2], s[3])
				if pos then table.insert(spots, { s[1], pos }) end
			end
			out[zone] = spots
		end
	end
	return out
end

function GatherService.Build()
	if not on() or ST.Folder then return end
	local map = workspace:FindFirstChild("Map") or workspace:WaitForChild("Map", 30) or workspace
	local folder = map:FindFirstChild("GatherNodes")
	if folder then folder:Destroy() end -- a stale folder from a saved place: its prompts are not ours
	folder = Instance.new("Folder")
	folder.Name = "GatherNodes"
	ST.Folder = folder
	local lists, zones = spotLists(), {}
	for zone in lists do table.insert(zones, zone) end
	table.sort(zones)
	for _, zone in zones do
		for i, spot in lists[zone] do
			local ok, err = pcall(makeNode, zone .. ":" .. i, spot[1], spot[2])
			if not ok then Util.Warn(TAG, "node " .. zone .. ":" .. i .. ": " .. tostring(err)) end
		end
	end
	folder.Parent = map
end

function GatherService.Nodes()
	return ST.Nodes
end

------------------------------------------------------------------ one gather
local function heavy(player)
	local h = ST.Hour[player]
	local now = os.clock()
	if not h or now - h.T0 >= 3600 then
		h = { T0 = now, N = 0 }
		ST.Hour[player] = h
	end
	h.N += 1
	if h.N == math.floor(num(G().Heavy, 200)) + 1 and S.TelemetryService then
		pcall(S.TelemetryService.Custom, player, "GatherHeavy", h.N)
	end
end

local function rollBloom(player, g, node)
	local B = G().Bloom
	if type(B) ~= "table" or not node.Def.Plant then return false end
	if g.Bloom >= num(B.DailyMax, 3) then return false end
	local sure = g.Total >= num(B.FirstAt, 5) and g.FirstBloom ~= true
	if not sure and rng:NextNumber() >= num(B.Chance, 0.08) then return false end
	-- ChoiceCard opens one card at a time: false while any card (this bloom's too) is open
	local ok, opened = pcall(S.ChoiceCard.Offer, player, B.Card, { Gather = node.Id })
	if not ok or opened ~= true then return false end
	g.Bloom += 1
	g.FirstBloom = true
	ST.Bloom[player] = { Id = node.Id, Pos = node.Pos }
	return true
end

function GatherService.Try(player, id, hold)
	local cfg = G()
	-- 1. the switch, our node, a living player with a class and a side
	if not on() then return "off" end
	local node = type(id) == "string" and ST.Nodes[id] or nil
	if not node then return "node" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then return "state" end
	local data = getData(player)
	if not data or not S.PlayerService.IsReady(player) or data.ClassChosen ~= true or not Config.Factions[data.Faction]
		or data.Faction == "None" or not Util.IsAlive(player) then
		return "state"
	end
	-- 1b. not seated (a vehicle / seat), not right after a teleport (게임성 검수 10/12)
	local hum = Util.GetHumanoid(player)
	if hum and hum.Sit == true then return "seated" end
	if os.clock() - num(ST.Jumped[player], -math.huge) < num(cfg.AfterJump, 3) then return "moved" end
	-- 2. the hold began on this node, long enough ago
	if type(hold) ~= "table" or hold.Id ~= id then return "hold" end
	local now = os.clock()
	if hold.Ended and now - hold.Ended > ST.StaleHold then return "hold" end
	if (hold.Ended or now) - num(hold.T0, now) < num(node.Def.Hold, 1.5) * num(cfg.MinHoldRatio, 0.8) then return "hold" end
	-- 3. near the node
	local root = rootOf(player)
	if not root or (root.Position - node.Pos).Magnitude > num(cfg.ServerRange, 12) then return "far" end
	-- 4. one gather a second
	if not Util.RateLimit(player, "Gather", num(Config.RateLimits.Gather, 1)) then return "rate" end
	-- 5. this node rests for me
	local rest = ST.Rest[player]
	if rest and num(rest[id]) > os.time() then return "rest" end
	-- 6. today's cap
	local g = gatherOf(data)
	if g.N >= num(cfg.DailyCap, 400) then
		if ST.CapSaid[player] ~= g.Day then
			ST.CapSaid[player] = g.Day
			notify(player, "DailyCap", "info")
		end
		return "cap"
	end
	-- 7. a player hit me while I held
	if hold.Hit then
		notify(player, "PvPCut", "bad")
		return "pvp"
	end
	-- pay: 1, or 2 at Double; a full bag gives nothing and counts nothing
	local item = node.Def.Item
	local n = rng:NextNumber() < num(cfg.Double, 0.2) and 2 or 1
	-- counted by the bag itself, before and after (an error after the item went in still counts the gather)
	local before = type(data.Items) == "table" and math.floor(num(data.Items[item])) or 0
	local okGrant, err = pcall(S.LootService.GrantItems, player, { { Id = item, N = n } }, node.Pos, "Gather")
	if not okGrant then Util.Warn(TAG, "grant: " .. tostring(err)) end
	local after = type(data.Items) == "table" and math.floor(num(data.Items[item])) or 0
	local got = math.max(0, after - before)
	if got <= 0 then return "full" end
	if not rest then
		rest = {}
		ST.Rest[player] = rest
	end
	rest[id] = os.time() + num(cfg.Regrow, 180)
	g.N += 1
	g.Total += 1
	heavy(player)
	if g.Total == 1 and S.TelemetryService then pcall(S.TelemetryService.Custom, player, "GatherFirst", 1) end
	rollBloom(player, g, node)
	if data.Faction == "Neutral" then pcall(Net.Fx, player, "Gather", { Id = id, Artisan = true }) end
	if S.PlayerService.MarkActive then pcall(S.PlayerService.MarkActive, player) end
	GatherService.Gathered:Fire(player, item, got, node.Kind)
	sendState(player, data)
	return "ok"
end

------------------------------------------------------------------ the bloom's end
local function share(giver, bloom)
	local B = G().Bloom
	-- around the bloom itself (the giver may have walked off during the 120 s card: no share in a town full of
	-- idle players), to ready, living players with a class (게임성 검수 10/12)
	local center = bloom and bloom.Pos
	if not center then return end
	for _, other in Players:GetPlayers() do
		local r = other ~= giver and rootOf(other)
		local data = r and S.PlayerService.IsReady(other) and Util.IsAlive(other) and getData(other)
		if data and data.ClassChosen == true and (r.Position - center).Magnitude <= num(B.Radius, 40) then
			local g = gatherOf(data)
			if g.Gift < num(B.GiftDailyMax, 10) then
				local ok, gained = pcall(S.LootService.GrantItems, other, { { Id = B.Item, N = 1 } }, nil, "Bloom")
				if ok and type(gained) == "table" and #gained > 0 then
					g.Gift += 1
					notify(other, "BloomGift", "reward")
				end
			end
		end
	end
end

local function onPicked(player, kind, side)
	local B = G().Bloom
	if type(B) ~= "table" or kind ~= B.Card then return end
	local bloom = ST.Bloom[player]
	ST.Bloom[player] = nil
	if side == "Good" then
		share(player, bloom)
	elseif side == "None" then
		local ok, gained = pcall(S.LootService.GrantItems, player, { { Id = B.Item, N = 1 } }, nil, "Bloom")
		if ok and type(gained) == "table" and #gained > 0 then notify(player, "BloomWilt", "reward") end
	end
end

------------------------------------------------------------------ prompts
local function onHoldBegan(prompt, player)
	local id = ST.ByPrompt[prompt]
	if not id or not on() or not S.PlayerService.IsReady(player) then return end
	ST.Hold[player] = { Id = id, T0 = os.clock() }
end

local function onHoldEnded(prompt, player)
	local hold = ST.Hold[player]
	if hold and hold.Id == ST.ByPrompt[prompt] and not hold.Ended then hold.Ended = os.clock() end
end

local function onTriggered(prompt, player)
	local id = ST.ByPrompt[prompt]
	if not id then return end
	local hold = ST.Hold[player]
	ST.Hold[player] = nil
	GatherService.Try(player, id, hold)
end

local function onDamaged(victim, amount, attacker)
	-- CombatService fires this only for a player attacker (attacker nil = a monster)
	if typeof(attacker) ~= "Instance" or num(amount) <= 0 then return end
	local hold = ST.Hold[victim]
	if hold then hold.Hit = true end
end

------------------------------------------------------------------ service
function GatherService.Init(registry)
	S = registry
end

local function guard(label, fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then Util.Warn(TAG, label .. ": " .. tostring(err)) end
	end
end

function GatherService.Start()
	ProximityPromptService.PromptButtonHoldBegan:Connect(guard("hold", onHoldBegan))
	ProximityPromptService.PromptButtonHoldEnded:Connect(guard("release", onHoldEnded))
	ProximityPromptService.PromptTriggered:Connect(guard("trigger", onTriggered))
	S.CombatService.PlayerDamaged:Connect(guard("damaged", onDamaged))
	S.ChoiceCard.Picked:Connect(guard("picked", onPicked))
	S.PlayerService.PlayerReady:Connect(guard("ready", function(player, data)
		if on() and type(data) == "table" then sendState(player, data) end
	end))
	-- both leave paths: a player who never got ready still leaves no state behind
	local function forget(player)
		ST.Hold[player], ST.Rest[player], ST.CapSaid[player], ST.Bloom[player], ST.Hour[player] = nil, nil, nil, nil, nil
		ST.LastPos[player], ST.Jumped[player] = nil, nil
	end
	S.PlayerService.PlayerLeaving:Connect(forget)
	Players.PlayerRemoving:Connect(forget)
	task.spawn(guard("build", GatherService.Build))
	-- the jump watch: a root that moved more than JumpStuds between two samples was teleported (or flung)
	task.spawn(function()
		while true do
			task.wait(num(G().JumpSample, 0.5))
			if on() then
				local ok, err = pcall(function()
					for _, p in Players:GetPlayers() do
						local r = rootOf(p)
						if r then
							local last = ST.LastPos[p]
							if last and (r.Position - last).Magnitude > num(G().JumpStuds, 60) then ST.Jumped[p] = os.clock() end
							ST.LastPos[p] = r.Position
						end
					end
				end)
				if not ok then Util.Warn(TAG, "jump watch: " .. tostring(err)) end
			end
		end
	end)
	-- ⑤: the live switch Gathering back on = the players on this server are read again (a join while it was off
	-- skipped them); looked up softly (a world without SwitchService connects nothing)
	local switches = S.SwitchService
	if type(switches) == "table" and type(switches.Changed) == "table" and type(switches.Changed.Connect) == "function" then
		switches.Changed:Connect(function(k, value)
			if k ~= "Gathering" or value ~= true then return end
			local ok, err = pcall(function()
				GatherService.Build()
				for _, p in Players:GetPlayers() do
					local d = S.PlayerService.IsReady(p) and S.PlayerService.GetData(p)
					if type(d) == "table" then sendState(p, d) end
				end
			end)
			if not ok then Util.Warn(TAG, "switch on: " .. tostring(err)) end
		end)
	end
	print("[GatherService] started")
end

return GatherService
