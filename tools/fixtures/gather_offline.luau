-- gather_offline.luau : gathering (GatherService, 게임성 개발 3, 2026-10-11; contract docs/design/gather_server_2026-10-11.md).
-- tools/test_gather.py binds CONFIG_SOURCE, UTIL_SOURCE, LOOT_SOURCE, DEEDS_SOURCE, CARD_SOURCE and GATHER_SOURCE in
-- front of dev2_kit.luau + dev3_world.luau; this file follows. LootService (GrantItems / GrantItem), Deeds, ChoiceCard and
-- GatherService run from source; PlayerService / CombatService are the dev3_world doubles, TelemetryService records
-- Custom events. Engine doubles added here: workspace (Map, Raycast, GetServerTimeNow), ServerStorage, CollectionService,
-- ProximityPromptService (hold began / ended / triggered), RaycastParams, BasePart IsA, PivotTo. Random draws are
-- scripted (w.Script, front first: GatherService draws the double first, then the bloom chance).

local NOON = 1789959600 -- 2026-09-22 12:00 KST

-- the kit's tiny instances, a little more Roblox-like for this suite (parts are BaseParts, models pivot)
do
	local M = instMeta.Methods
	local baseIsA = M.IsA
	local PARTS = { Part = true, MeshPart = true }
	M.IsA = function(o, kind)
		if kind == "BasePart" and PARTS[o.ClassName] then return true end
		return baseIsA(o, kind)
	end
	M.FindFirstChildWhichIsA = function(o, kind, recursive)
		for _, c in o._children do
			if c:IsA(kind) then return c end
			if recursive then
				local d = c:FindFirstChildWhichIsA(kind, true)
				if d then return d end
			end
		end
		return nil
	end
	M.PivotTo = function(o, cf)
		o.PivotAt = type(cf) == "table" and type(cf.Args) == "table" and cf.Args[1] or nil
	end
end

-- o: Off (switch off), GroundY (nil = the ray hits nothing; default 5), Tagged = { { kind, pos } }, Kit = { kind = true },
-- EditConfig(c)
local function gWorld(o)
	o = o or {}
	o.Time = o.Time or NOON
	local edit = o.EditConfig
	o.EditConfig = function(c)
		if o.Off ~= true then c.Features.Gathering = true end
		if edit then edit(c) end
	end
	local w = dev3World(o)
	local ws = newInstance("Workspace", w)
	local map = newInstance("Folder", w)
	map.Name = "Map"
	map.Parent = ws
	w.WS, w.Map, w.Rays = ws, map, {}
	if o.GroundY ~= false then w.GroundY = o.GroundY or 5 end
	ws.GetServerTimeNow = function() return w.Time + 0.25 end
	ws.WaitForChild = function(self, n) return self:FindFirstChild(n) end
	ws.Raycast = function(_, origin, dir, params)
		table.insert(w.Rays, { Origin = origin, Dir = dir, Params = params })
		if w.GroundY == nil then return nil end
		return { Position = vec(origin.X, w.GroundY, origin.Z) }
	end
	local storage = newInstance("ServerStorage", w)
	w.Services.ServerStorage = storage
	w.Tagged = { GatherSpot = {} }
	for _, t in o.Tagged or {} do
		local part = newInstance("Part", w)
		part.Position = t[2]
		part.Attrs.Node = t[1]
		table.insert(w.Tagged.GatherSpot, part)
	end
	if o.Kit then
		local kit = newInstance("Folder", w)
		kit.Name = "GatherKit"
		kit.Parent = storage
		for kind in o.Kit do
			local model = newInstance("Model", w)
			model.Name = kind
			local body = newInstance("Part", w)
			body.Name = "KitBody"
			body.Parent = model
			model.Clone = function()
				local copy = newInstance("Model", w)
				copy.Name = kind
				copy.FromKit = true
				local b = newInstance("Part", w)
				b.Name = "KitBody"
				b.Parent = copy
				return copy
			end
			model.Parent = kit
		end
	end
	w.Services.CollectionService = { GetTagged = function(_, tag) return w.Tagged[tag] or {} end }
	w.PPS = { PromptButtonHoldBegan = rbxSignal(w.Warnings), PromptButtonHoldEnded = rbxSignal(w.Warnings),
		PromptTriggered = rbxSignal(w.Warnings) }
	w.Services.ProximityPromptService = w.PPS
	local baseEnv = w.Env
	function w:Env()
		local e = baseEnv(self)
		e.workspace = ws
		e.RaycastParams = { new = function() return {} end }
		return e
	end
	w.Net.NotifyKey = function(p, key, args, kind)
		table.insert(w.Notices, { Player = p, Key = key, Args = args, Kind = kind, Text = "KEY:" .. tostring(key) })
	end
	w.Tele = {}
	w.Reg.TelemetryService = { Custom = function(p, name, v) table.insert(w.Tele, { P = p, Name = name, V = v }) end }
	w.Reg.QuestService = { MarkDirty = function() end }
	w:Service("LootService", LOOT_SOURCE)
	w:Service("Deeds", DEEDS_SOURCE)
	w:Service("ChoiceCard", CARD_SOURCE)
	w:Service("GatherService", GATHER_SOURCE)
	w.Reg.LootService.Init(w.Reg)
	w:InitStart({ "Deeds", "ChoiceCard", "GatherService" })
	w.G = w.Reg.GatherService
	w.Gathered = {}
	w.G.Gathered:Connect(function(p, item, n, kind) table.insert(w.Gathered, { P = p, Item = item, N = n, Kind = kind }) end)
	w.Script = {}
	return w
end

local SETTLED = { Day = 0, N = 0, Bloom = 0, Gift = 0, Total = 0, FirstBloom = true } -- no sure first bloom

-- a ready player with a living character; extra = save fields (Gather = SETTLED unless given)
local function hero(w, id, faction, extra)
	local data = { Faction = faction or "Halo", Class = "Warrior", ClassChosen = true, Level = 5, Gather = deepCopy(SETTLED) }
	for k, v in extra or {} do data[k] = v end
	local p, d = w:Arrive(id, { Data = data })
	w.CharFolder = w.CharFolder or newInstance("Folder", w)
	local char = newInstance("Model", w)
	char.Parent = w.CharFolder
	local root = newInstance("Part", w)
	root.Name, root.Position = "HumanoidRootPart", vec(0, 0, 0)
	root.Parent = char
	local hum = newInstance("Humanoid", w)
	hum.Health = 100
	hum.Parent = char
	p.Character = char
	return p, d
end

local function rootOf(p) return p.Character:FindFirstChild("HumanoidRootPart") end
local function node(w, id) return w.G.Nodes()[id] end
local function stand(p, n, dx) rootOf(p).Position = n.Pos + vec(dx or 2, 0, 0) end
local function items(d, id) return type(d.Items) == "table" and (d.Items[id] or 0) or 0 end

local function count(t)
	local n = 0
	for _ in t do n += 1 end
	return n
end

-- one hold on node `id` (o: Held s, NoMove, NoBegin, BeganOn = another id, Attacker = a player who hits during the
-- hold | "monster", ReleaseEarly = s between the release and the trigger, Draws = scripted draws)
local function gather(w, p, id, o)
	o = o or {}
	local n = node(w, id)
	if not o.NoMove then stand(p, n, o.Dx) end
	w.Script = o.Draws or { 0.5, 0.5 }
	if not o.NoBegin then w.PPS.PromptButtonHoldBegan:Fire((o.BeganOn and node(w, o.BeganOn) or n).Prompt, p) end
	if o.Attacker == "monster" then
		w.Reg.CombatService.PlayerDamaged:Fire(p, 10, nil)
	elseif o.Attacker then
		w.Reg.CombatService.PlayerDamaged:Fire(p, 10, o.Attacker)
	end
	w:Advance(o.Held or n.Def.Hold)
	if o.ReleaseEarly then
		w.PPS.PromptButtonHoldEnded:Fire(n.Prompt, p)
		w:Advance(o.ReleaseEarly)
	end
	w.PPS.PromptTriggered:Fire(n.Prompt, p)
	w.PPS.PromptButtonHoldEnded:Fire(n.Prompt, p)
	w:Flush()
end

-- Try with a hold that began `ago` s earlier (no prompt events): the rate / cap / heavy loops
local function try(w, p, id, ago, draws)
	local n = node(w, id)
	stand(p, n)
	w.Script = draws or { 0.5, 0.5 }
	local r = w.G.Try(p, id, { Id = id, T0 = w.Clock - (ago or 3) })
	w:Flush()
	return r
end

local function keysFor(w, p, from)
	local out = {}
	for i = (from or 0) + 1, #w.Notices do
		local n = w.Notices[i]
		if n.Player == p and n.Key then table.insert(out, n.Key) end
	end
	return out
end

local function states(w, p)
	local out = {}
	for _, f in w.Fired do
		if f.Remote == "GatherState" and f.Player == p then table.insert(out, f.Payload) end
	end
	return out
end

local function cardOf(w, p)
	local list = w:FxOf("Card", p)
	return list[#list] and list[#list].Data or nil
end

------------------------------------------------------------------ the table
runGroup("config", function()
	local C = execute("Config", CONFIG_SOURCE, nativeEnv())
	local G = C.Gather
	check(C.Features.Gathering == false and C.FeatureOn("Gathering") == false, "Config.Features.Gathering is off", "")
	check(G.DailyCap == 400 and G.MinHoldRatio == 0.8 and G.PromptRange == 8 and G.ServerRange == 12 and G.Regrow == 180
		and G.Double == 0.2 and G.Heavy == 200 and C.RateLimits.Gather == 1,
		"400 a day, 0.8 of the hold, prompt 8 / server 12 studs, 180 s rest, 20% double, heavy 200 an hour, 1 a second", show(G))
	local B = G.Bloom
	check(B.Chance == 0.08 and B.FirstAt == 5 and B.DailyMax == 3 and B.Radius == 40 and B.GiftDailyMax == 10
		and B.Item == "CrownDust" and B.Card == "ShardBloom", "bloom: 8%, sure at the 5th, 3 a day, 40 studs, 10 gifts a day", show(B))
	local want = { HerbBush = { "Herb", 1.5, "Pick", true, "SlimeMeadow" }, CopperRock = { "CopperOre", 2, "Mine", nil, "SlimeMeadow" },
		OakPile = { "OakLog", 1.5, "Pick", nil, "GoblinWoods" }, GlowcapPatch = { "Glowcap", 1.5, "Pick", true, "GoblinWoods" },
		IronRock = { "IronOre", 2, "Mine", nil, "GoblinWoods" }, SilverRock = { "SilverOre", 2, "Mine", nil, "SkeletonRuins" },
		MoonCrystal = { "MoonCrystal", 2, "Mine", nil, "SkeletonRuins" } }
	check(count(G.Nodes) == 7, "seven node kinds", tostring(count(G.Nodes)))
	for kind, x in want do
		local d = G.Nodes[kind]
		check(d ~= nil and d.Item == x[1] and d.Hold == x[2] and d.Action == x[3] and d.Plant == x[4] and d.Zone == x[5],
			"node kinds: item, hold, Pick / Mine, plant, zone as the contract", kind .. " " .. show(d))
	end
	local sells = { Herb = 1, CopperOre = 2, OakLog = 3, Glowcap = 4, IronOre = 5, SilverOre = 8, MoonCrystal = 10, CrownDust = 8 }
	local order = {}
	for i, id in C.Loot.Order do order[id] = i end
	for id, sell in sells do
		local it = C.Loot.Items[id]
		check(it ~= nil and it.Kind == "Material" and it.Sell == sell and it.Source == "Gather" and type(it.Name) == "string"
			and it.Name ~= "" and it.Icon == "Icon" .. id and order[id] ~= nil,
			"the 8 materials: Material, sell price, a name, an Icon<Id> key, in the bag order", id .. " " .. show(it))
	end
	local per = {}
	for zone, list in G.Spots do
		for _, s in list do
			per[zone .. ":" .. s[1]] = (per[zone .. ":" .. s[1]] or 0) + 1
		end
	end
	check(per["SlimeMeadow:HerbBush"] == 12 and per["SlimeMeadow:CopperRock"] == 8 and per["GoblinWoods:OakPile"] == 8
		and per["GoblinWoods:GlowcapPatch"] == 8 and per["GoblinWoods:IronRock"] == 6 and per["SkeletonRuins:SilverRock"] == 6
		and per["SkeletonRuins:MoonCrystal"] == 6 and count(per) == 7,
		"spots: meadow 12 herbs + 8 copper, woods 8 oak + 8 glowcap + 6 iron, ruins 6 silver + 6 moon (no hidden zone)", show(per))
	for zone, list in G.Spots do
		local pts = {}
		for _, s in list do
			local pos = C.GatherSpotPos(zone, s[2], s[3])
			check(pos ~= nil and G.Nodes[s[1]] ~= nil and G.Nodes[s[1]].Zone == zone, "every spot is inside its zone and of that zone's kind",
				zone .. " " .. show(s))
			if pos then
				check(math.abs(pos.Z) > 9, "no spot on the crown road (|z| <= 9)", zone .. " " .. show(pos))
				check((pos - vec(230, 0, 0)).Magnitude > 40, "no spot within 40 studs of the meadow spawn", zone .. " " .. show(pos))
				for _, q in pts do
					check((pos - q).Magnitude >= 8, "spots of a zone are at least 8 studs apart", zone .. " " .. show({ pos, q }))
				end
				table.insert(pts, pos)
			end
		end
	end
	local p = C.GatherSpotPos("SlimeMeadow", 0, 1)
	local z = C.Zones.SlimeMeadow
	check(p.X == z.Center.X - z.Size.X / 2 and p.Z == z.Center.Z + z.Size.Z / 2 and p.Y == 0, "GatherSpotPos: u 0 / v 1 = the west / south edge",
		show(p))
	check(C.GatherSpotPos("Nowhere", 0.5, 0.5) == nil and C.GatherSpotPos("SlimeMeadow", 1.2, 0.5) == nil
		and C.GatherSpotPos("SlimeMeadow", 0 / 0, 0.5) == nil and C.GatherSpotPos("SlimeMeadow", "a", 0.5) == nil,
		"GatherSpotPos: unknown zone / outside 0..1 / NaN / text -> nil", "")
	local T = G.Text
	check(T.Pick == "Pick" and T.Mine == "Mine" and type(T.DailyCap) == "string" and type(T.PvPCut) == "string"
		and type(T.BloomGift) == "string" and type(T.BloomWilt) == "string" and T.FirstHint == nil,
		"texts: Pick, Mine, DailyCap, PvPCut, BloomGift, BloomWilt (no first hint, A23-130)", show(T))
	local K = C.ChoiceCard.Kinds.ShardBloom
	check(K and K.Seconds == 120 and K.Good.Reward.Item == "CrownDust" and K.Good.Reward.N == 2 and K.Evil.Reward.N == 3
		and K.Good.Points == 1 and K.Evil.Points == 1, "the Shard Bloom card: timed 120 s, Share = 2, Keep it all = 3, 1 point", show(K))
end)

------------------------------------------------------------------ the nodes
runGroup("build", function()
	local off = gWorld({ Off = true })
	check(off.Map:FindFirstChild("GatherNodes") == nil and count(off.G.Nodes()) == 0, "switch off: no node, no folder", "")
	local p0 = hero(off, 1)
	check(off.G.Try(p0, "SlimeMeadow:1", { Id = "SlimeMeadow:1", T0 = off.Clock - 5 }) == "off", "switch off: Try answers off", "")
	check(#states(off, p0) == 0, "switch off: no GatherState at join", "")

	local w = gWorld()
	local folder = w.Map:FindFirstChild("GatherNodes")
	local nodes = w.G.Nodes()
	check(folder ~= nil and count(nodes) == 54 and #folder:GetChildren() == 54, "switch on: 54 nodes in workspace.Map.GatherNodes",
		tostring(count(nodes)))
	local perZone = {}
	for id, n in nodes do
		local zone, i = string.match(id, "^(%a+):(%d+)$")
		perZone[zone or "?"] = (perZone[zone or "?"] or 0) + 1
		local prompt = n.Prompt
		check(n.Model:GetAttribute("GatherId") == id and n.Model:GetAttribute("GatherKind") == n.Kind and n.Model.Name == n.Kind
			and n.Model.Parent == folder, "a node model: GatherId, GatherKind, named by its kind, in the folder", id)
		check(prompt and prompt.ClassName == "ProximityPrompt" and prompt.Name == "GatherPrompt" and prompt.HoldDuration == n.Def.Hold
			and prompt.MaxActivationDistance == 8 and prompt.RequiresLineOfSight == false and prompt.ActionText == ""
			and prompt.ObjectText == "", "the prompt: GatherPrompt, the node's hold, 8 studs, no sight line, no words", id)
		local action = prompt:GetAttribute("ActionKey")
		local object = prompt:GetAttribute("ObjectKey")
		local itemId = type(object) == "string" and string.match(object, "^Config%.Loot%.Items%.(%w+)%.Name$")
		check(action == "Config.Gather.Text." .. n.Def.Action and itemId == n.Def.Item and w.Config.Loot.Items[itemId].Name ~= nil,
			"ActionKey = Config.Gather.Text.Pick | Mine, ObjectKey = the item's Name key (the client writes the words)", id .. " " .. tostring(action) .. " " .. tostring(object))
		check(prompt.Enabled == nil, "the server never sets Enabled (the client dims my resting nodes)", id)
		check(n.Pos.Y == 5 and n.Model.PivotAt and n.Model.PivotAt.Y == 5, "a node stands on the ground the ray found", id .. " " .. show(n.Pos))
		check(tonumber(i) ~= nil, "ids are <Zone>:<n>", id)
	end
	check(perZone.SlimeMeadow == 20 and perZone.GoblinWoods == 22 and perZone.SkeletonRuins == 12, "20 / 22 / 12 nodes a zone", show(perZone))
	local ray = w.Rays[1]
	check(ray and ray.Origin.Y == 300 and ray.Dir.Y == -600 and ray.Params.FilterType == "RaycastFilterType.Exclude"
		and table.find(ray.Params.FilterDescendantsInstances, folder) ~= nil,
		"the ground ray: from 300 up, 600 down, the nodes' folder excluded", show({ ray and ray.Origin, ray and ray.Dir }))
	local stand0 = node(w, "SlimeMeadow:1").Model.PrimaryPart
	check(stand0 and stand0.CanCollide == false and stand0.Anchored == true and stand0:FindFirstChild("GatherPrompt") ~= nil,
		"without a kit model: an anchored, walk-through stand-in part holds the prompt", "")

	local air = gWorld({ GroundY = false })
	check(node(air, "SlimeMeadow:1").Pos.Y == 0, "no ground hit: y = 0", "")

	local tagged = gWorld({ Tagged = { { "HerbBush", vec(300, 0, 100) }, { "HerbBush", vec(280, 0, 90) }, { "Nope", vec(1, 0, 1) } } })
	local meadow = 0
	for id in tagged.G.Nodes() do
		if string.sub(id, 1, 12) == "SlimeMeadow:" then meadow += 1 end
	end
	check(meadow == 2 and node(tagged, "SlimeMeadow:1").Pos.X == 280 and node(tagged, "SlimeMeadow:2").Pos.X == 300
		and count(tagged.G.Nodes()) == 36, "WorldKit GatherSpot parts replace their zone's list (sorted by x; an unknown kind ignored)",
		tostring(meadow) .. " " .. tostring(count(tagged.G.Nodes())))

	local kit = gWorld({ Kit = { HerbBush = true } })
	local kn = node(kit, "SlimeMeadow:1")
	check(kn.Model.FromKit == true and kn.Prompt.Parent and kn.Prompt.Parent.Name == "KitBody", "a ServerStorage.GatherKit model is cloned and holds the prompt", "")
	check(node(kit, "SlimeMeadow:13").Model.FromKit == nil, "kinds without a kit model keep the stand-in", "")
end)

------------------------------------------------------------------ one gather
runGroup("gather", function()
	local w = gWorld()
	local p, d = hero(w, 1)
	local id = "SlimeMeadow:1" -- a herb bush
	gather(w, p, id)
	local tPick = w.Time
	check(items(d, "Herb") == 1 and d.Gather.N == 1 and d.Gather.Total == 1, "a full hold gives one herb and counts one gather",
		show({ items(d, "Herb"), d.Gather }))
	check(#w.Gathered == 1 and w.Gathered[1].Item == "Herb" and w.Gathered[1].N == 1 and w.Gathered[1].Kind == "HerbBush",
		"Gathered(player, Herb, 1, HerbBush)", "")
	local loot = w:FxOf("Loot", p)
	check(#loot == 1 and loot[1].Data.Items[1].Item == "Herb" and loot[1].Data.Items[1].N == 1 and loot[1].Data.Pos == node(w, id).Pos,
		"the Loot Fx shows +1 Meadow Herb at the node", "")
	local st = states(w, p)
	local last = st[#st]
	check(#st == 2 and last.N == 1 and last.Cap == 400 and last.Ready[id] == w.Time + 0.25 + 180 and count(last.Ready) == 1,
		"GatherState at join, then { Ready[node] = server time + 180, N, Cap }", show(last))
	check(#w.Tele == 1 and w.Tele[1].Name == "GatherFirst", "the first gather ever is logged once (GatherFirst)", tostring(#w.Tele))
	check(#w:FxOf("Gather", p) == 0, "a Halo gatherer gets no artisan sparkle", "")
	check(w.Reg.PlayerService.Active[p] ~= nil, "a gather counts as activity", "")

	gather(w, p, "SlimeMeadow:2", { Draws = { 0.1, 0.5 } })
	check(items(d, "Herb") == 3 and w.Gathered[2].N == 2, "a draw under 0.2 gives two", tostring(items(d, "Herb")))
	gather(w, p, "SlimeMeadow:3", { Draws = { 0.2, 0.5 } })
	check(items(d, "Herb") == 4, "a draw of 0.2 gives one", tostring(items(d, "Herb")))

	-- rest: mine only, 180 s
	gather(w, p, id)
	check(items(d, "Herb") == 4 and d.Gather.N == 3, "the same node again at once: nothing (it rests for me)", "")
	local q, dq = hero(w, 2)
	gather(w, q, id)
	check(items(dq, "Herb") == 1, "another player picks the node I just picked", "")
	w:Advance(tPick + 179 - 1.5 - w.Time)
	gather(w, p, id)
	check(items(d, "Herb") == 4, "still resting 179 s after the pick", tostring(items(d, "Herb")))
	w:Advance(1)
	gather(w, p, id)
	check(items(d, "Herb") == 5, "picked again once 180 s have passed", tostring(items(d, "Herb")))

	-- the hold
	local rock = "SlimeMeadow:13" -- a copper rock, hold 2.0
	gather(w, p, rock, { Held = 1.59 })
	check(items(d, "CopperOre") == 0, "a rock held 1.59 s (under 0.8 x 2.0) gives nothing", "")
	w:Advance(1)
	gather(w, p, rock, { Held = 1.61 })
	check(items(d, "CopperOre") == 1, "a rock held 1.61 s (just over 0.8 x 2.0) counts", "")
	gather(w, p, "SlimeMeadow:14", { NoBegin = true })
	check(items(d, "CopperOre") == 1, "a trigger without a hold that began (an instant fire) gives nothing", "")
	gather(w, p, "SlimeMeadow:15", { BeganOn = "SlimeMeadow:16" })
	check(items(d, "CopperOre") == 1, "a hold that began on another node gives nothing", "")
	gather(w, p, "SlimeMeadow:17", { ReleaseEarly = 1.5 })
	check(items(d, "CopperOre") == 1, "a trigger 1.5 s after the release is stale: nothing", "")
	gather(w, p, "SlimeMeadow:18", { ReleaseEarly = 0.5 })
	check(items(d, "CopperOre") == 2, "a trigger right after the release still counts", "")

	-- distance
	gather(w, p, "SlimeMeadow:19", { Dx = 12.5 })
	check(items(d, "CopperOre") == 2, "12.5 studs from the node: nothing (server range 12)", "")
	gather(w, p, "SlimeMeadow:19", { Dx = 11.9 })
	check(items(d, "CopperOre") == 3, "11.9 studs: counts", "")

	-- one a second (a hold always takes longer; only a forged trigger is that fast)
	w:Advance(2)
	check(try(w, p, "SlimeMeadow:20", 3) == "ok", "a gather", "")
	check(try(w, p, "SlimeMeadow:4", 3) == "rate", "another one within a second: rate", "")
	w:Advance(1.01)
	check(try(w, p, "SlimeMeadow:4", 3) == "ok", "a second later: ok", "")

	-- who may gather
	local dead, dd = hero(w, 3)
	dead.Character:FindFirstChildOfClass("Humanoid").Health = 0
	gather(w, dead, "SlimeMeadow:5")
	local noClass, dn = hero(w, 4, "Halo", { ClassChosen = false })
	gather(w, noClass, "SlimeMeadow:5")
	local noSide, ds = hero(w, 5, "None")
	gather(w, noSide, "SlimeMeadow:5")
	check(items(dd, "Herb") == 0 and items(dn, "Herb") == 0 and items(ds, "Herb") == 0,
		"a KO'd player, one without a class or without a side gathers nothing", "")
	local art, da = hero(w, 6, "Neutral")
	gather(w, art, "SlimeMeadow:5")
	local fx = w:FxOf("Gather", art)
	check(items(da, "Herb") == 1 and #fx == 1 and fx[1].Data.Id == "SlimeMeadow:5" and fx[1].Data.Artisan == true,
		"an artisan gathers like everyone and gets the artisan sparkle Fx { Id, Artisan }", "")

	-- the switch turned off at run time
	w.Config.Features.Gathering = false
	local herbs = items(d, "Herb")
	gather(w, p, "SlimeMeadow:6")
	check(items(d, "Herb") == herbs and herbs == 6, "switch off at run time: nothing", tostring(items(d, "Herb")))
	w.Config.Features.Gathering = true
	for _, n in w.G.Nodes() do
		check(n.Prompt.Enabled == nil, "no gather ever touched a prompt's Enabled", n.Id)
	end
end)

------------------------------------------------------------------ hits, the bag, the day
runGroup("limits", function()
	local w = gWorld()
	local p, d = hero(w, 1)
	local foe = hero(w, 2, "Horns")
	local from = #w.Notices
	gather(w, p, "SlimeMeadow:1", { Attacker = foe })
	check(items(d, "Herb") == 0 and d.Gather.N == 0, "hit by a player during the hold: nothing", "")
	local keys = keysFor(w, p, from)
	check(#keys == 1 and keys[1] == "Config.Gather.Text.PvPCut", "... and the PvPCut notice (a key)", show(keys))
	gather(w, p, "SlimeMeadow:1")
	check(items(d, "Herb") == 1, "the node did not rest after the cut gather", "")
	gather(w, p, "SlimeMeadow:2", { Attacker = "monster" })
	check(items(d, "Herb") == 2, "a monster hit never cuts a gather", "")

	d.Items.CopperOre = 999
	gather(w, p, "SlimeMeadow:13")
	check(items(d, "CopperOre") == 999 and d.Gather.N == 2, "a full bag: nothing given, nothing counted", show(d.Gather))
	gather(w, p, "SlimeMeadow:13")
	check(d.Gather.N == 2 and #w:FxOf("Loot", p) == 2, "... and the node did not rest (no gather happened)", "")
	d.Items.CopperOre = 998
	gather(w, p, "SlimeMeadow:13", { Draws = { 0.1, 0.5 } })
	check(items(d, "CopperOre") == 999 and d.Gather.N == 3 and w.Gathered[#w.Gathered].N == 1,
		"two rolled but one fits: one given, it counts", show({ items(d, "CopperOre"), d.Gather.N }))

	local c, dc = hero(w, 3)
	dc.Gather.Day = w.Config.DayIndex(w.Time)
	dc.Gather.N = 399
	check(try(w, c, "SlimeMeadow:3") == "ok" and dc.Gather.N == 400, "the 400th gather of the day counts", "")
	local before = #w.Notices
	w:Advance(1.01)
	check(try(w, c, "SlimeMeadow:4") == "cap", "the 401st: cap", "")
	w:Advance(1.01)
	check(try(w, c, "SlimeMeadow:5") == "cap", "again: cap", "")
	local capKeys = keysFor(w, c, before)
	check(#capKeys == 1 and capKeys[1] == "Config.Gather.Text.DailyCap", "the DailyCap notice once a day (a key)", show(capKeys))
	w:ToDay(1)
	check(try(w, c, "SlimeMeadow:6") == "ok" and dc.Gather.N == 1 and dc.Gather.Day == w.Config.DayIndex(w.Time)
		and dc.Gather.Total == 2, "a new KST day: the count starts over (Total keeps going)", show(dc.Gather))

	local h, dh = hero(w, 4)
	local n0 = 0
	local ids = {}
	for id in w.G.Nodes() do table.insert(ids, id) end
	table.sort(ids)
	for i = 1, 202 do
		w:Advance(3.4)
		if try(w, h, ids[(i - 1) % #ids + 1]) == "ok" then n0 += 1 end
	end
	local heavy = {}
	for _, t in w.Tele do
		if t.P == h and t.Name == "GatherHeavy" then table.insert(heavy, t.V) end
	end
	check(n0 == 202 and #heavy == 1 and heavy[1] == 201, "202 gathers in an hour: one GatherHeavy (at 201), every gather counted",
		show({ n0, heavy }))
	w:Leave(h)
	check(dh.Gather.N == 202, "leaving keeps the saved counts", "")

	for _, n in w.Notices do
		if n.Key then
			local path = string.match(n.Key, "^Config%.Gather%.Text%.(%a+)$")
			check(path ~= nil and type(w.Config.Gather.Text[path]) == "string", "every gather notice is a Config.Gather.Text key", n.Key)
		end
	end
end)

------------------------------------------------------------------ the Shard Bloom
runGroup("bloom", function()
	local w = gWorld()
	local fresh = { Day = 0, N = 0, Bloom = 0, Gift = 0, Total = 0, FirstBloom = false }
	local p, d = hero(w, 1, "Halo", { Gather = deepCopy(fresh) })
	for i = 13, 16 do gather(w, p, "SlimeMeadow:" .. i) end -- 4 copper rocks
	check(d.Gather.Total == 4 and cardOf(w, p) == nil, "4 gathers: no card yet", "")
	gather(w, p, "SlimeMeadow:17") -- the 5th is a rock: rocks never bloom
	check(cardOf(w, p) == nil and d.Gather.FirstBloom == false, "the 5th gather on a rock: no bloom", "")
	gather(w, p, "SlimeMeadow:1", { Draws = { 0.5, 0.99 } }) -- the 6th, a herb: sure (the draw does not matter)
	local card = cardOf(w, p)
	check(card and card.Kind == "ShardBloom" and d.Gather.FirstBloom == true and d.Gather.Bloom == 1,
		"the first plant gather from the 5th on opens the Shard Bloom for sure", show(d.Gather))
	gather(w, p, "SlimeMeadow:8", { Draws = { 0.5, 0.0 } })
	check(cardOf(w, p).Id == card.Id and d.Gather.Bloom == 1 and items(d, "Herb") == 2,
		"while the card is open a herb still gathers but never blooms or counts a bloom", show(d.Gather))
	-- share: me 2 (the card), everyone within 40 studs 1
	local near, dnear = hero(w, 2, "Horns")
	local far, dfar = hero(w, 3, "Halo")
	local full, dfull = hero(w, 4, "Halo", { Gather = { Day = w.Config.DayIndex(w.Time), N = 0, Bloom = 0, Gift = 10, Total = 0, FirstBloom = true } })
	rootOf(near).Position = rootOf(p).Position + vec(39, 0, 0)
	rootOf(far).Position = rootOf(p).Position + vec(0, 0, 41)
	rootOf(full).Position = rootOf(p).Position + vec(5, 0, 0)
	local honor = tonumber(d.Honor) or 0
	local from = #w.Notices
	w:Remote("CardAction", p, card.Id, "Good")
	check(items(d, "CrownDust") == 2, "Share it: I get 2 Crown Dust (the card)", tostring(items(d, "CrownDust")))
	check(items(dnear, "CrownDust") == 1 and dnear.Gather.Gift == 1, "a player 39 studs away (any side) gets 1", "")
	check(items(dfar, "CrownDust") == 0, "a player 41 studs away gets nothing", "")
	check(items(dfull, "CrownDust") == 0, "a player who took 10 gifts today gets nothing", "")
	check(#keysFor(w, near, from) == 1 and keysFor(w, near, from)[1] == "Config.Gather.Text.BloomGift"
		and #keysFor(w, p, from) == 0, "the receiver hears BloomGift (a key, no name); the giver no gather notice", "")
	check((tonumber(d.Honor) or 0) == honor + 1, "a Knight who shares: Honor +1 (the card's Deeds point)", show({ honor, d.Honor }))

	-- keep: 3, nobody else
	w.Script = {}
	gather(w, p, "SlimeMeadow:2", { Draws = { 0.5, 0.07 } })
	local c2 = cardOf(w, p)
	check(c2 and c2.Id ~= card.Id and d.Gather.Bloom == 2, "a draw under 8% blooms again", show(d.Gather))
	rootOf(near).Position = rootOf(p).Position + vec(10, 0, 0) -- close enough that a share would reach
	local nearBefore = items(dnear, "CrownDust")
	w:Remote("CardAction", p, c2.Id, "Evil")
	check(items(d, "CrownDust") == 5 and items(dnear, "CrownDust") == nearBefore, "Keep it all: I get 3, nobody else anything", "")

	-- the card already open: no new bloom
	gather(w, p, "SlimeMeadow:3", { Draws = { 0.5, 0.0 } })
	local c3 = cardOf(w, p)
	check(c3 and c3.Id ~= c2.Id and d.Gather.Bloom == 3, "a third bloom", "")
	gather(w, p, "SlimeMeadow:4", { Draws = { 0.5, 0.0 } })
	check(cardOf(w, p).Id == c3.Id and d.Gather.Bloom == 3, "while a card is open no bloom (and nothing counted)", "")
	-- time up: 1, no points
	local wilt = #w.Notices
	local dust = items(d, "CrownDust")
	w:Advance(125)
	check(items(d, "CrownDust") == dust + 1, "120 s without a pick: +1 Crown Dust", tostring(items(d, "CrownDust")))
	local wk = keysFor(w, p, wilt)
	check(#wk == 1 and wk[1] == "Config.Gather.Text.BloomWilt", "... with the BloomWilt notice (a key)", show(wk))
	-- three a day
	gather(w, p, "SlimeMeadow:5", { Draws = { 0.5, 0.0 } })
	check(d.Gather.Bloom == 3 and cardOf(w, p).Id == c3.Id, "a 4th bloom the same day never opens", "")
	w:ToDay(1)
	gather(w, p, "SlimeMeadow:6", { Draws = { 0.5, 0.0 } })
	check(d.Gather.Bloom == 1 and cardOf(w, p).Id ~= c3.Id, "the next day blooms again", show(d.Gather))
	gather(w, p, "SlimeMeadow:13", { Draws = { 0.5, 0.0 } })
	check(d.Gather.Bloom == 1, "a draw of 0 on a rock: no bloom (rocks never bloom)", "")

	-- an artisan's pick scores nothing
	local a, dA = hero(w, 7, "Neutral", { Gather = deepCopy(fresh) })
	dA.Gather.Total = 4
	gather(w, a, "SlimeMeadow:7")
	local ac = cardOf(w, a)
	local before = { dA.Honor, dA.Infamy }
	w:Remote("CardAction", a, ac.Id, "Evil")
	check(items(dA, "CrownDust") == 3 and dA.Honor == before[1] and dA.Infamy == before[2],
		"an artisan keeps it all: 3 dust, no Honor / Infamy change", show({ dA.Honor, dA.Infamy }))
end)

------------------------------------------------------------------ LootService.GrantItems (from source)
runGroup("grant items", function()
	local w = gWorld()
	local p, d = hero(w, 1)
	local L = w.Reg.LootService
	local got = {}
	L.ItemsGranted:Connect(function(pl, rows) table.insert(got, rows) end)
	local rows = L.GrantItems(p, { { Id = "Herb", N = 2 }, { Id = "Nope", N = 1 }, { Id = "Glowcap", N = 0 }, { Id = "OakLog", N = 100 },
		{ Id = "Jelly", N = 1 } }, vec(1, 2, 3), "Gather")
	check(#rows == 2 and rows[1].Item == "Jelly" and rows[1].N == 1 and rows[2].Item == "Herb" and rows[2].N == 2
		and type(rows[2].Name) == "string", "GrantItems: known ids with 1..99 only, rows { Item, Name, N } in the bag order", show(rows))
	check(items(d, "Herb") == 2 and items(d, "Jelly") == 1 and items(d, "OakLog") == 0 and items(d, "Glowcap") == 0,
		"the items are in the save", "")
	local fx = w:FxOf("Loot", p)
	check(#fx == 1 and fx[1].Data.Pos.X == 1 and fx[1].Data.Pos.Y == 2 and fx[1].Data.Pos.Z == 3, "one Loot Fx with the position", "")
	check(#got == 1 and #got[1] == 2, "ItemsGranted once with the rows", "")
	d.Items.Herb = 999
	local none = L.GrantItems(p, { { Id = "Herb", N = 1 } })
	check(#none == 0 and #w:FxOf("Loot", p) == 1 and #got == 1, "a full bag: no row, no Fx, no signal", "")
	check(#L.GrantItems(p, "x") == 0 and #L.GrantItems(p, { "x", { Id = 5, N = 1 } }) == 0, "a broken list gives nothing", "")
end)

finish()
