-- SceneSetup.luau : SPEC A23-218 ② (user 2026-10-16, 게임성 개발 2) - one call sets a test scene for photos and checks:
-- level, side, class, the tutorial step, quests (done / the active main or sub at a step), the place, items / gold, the
-- switches, monsters around the player (optionally held in place), a field boss, an open offer, the crown-war round end.
-- STUDIO ONLY: Apply refuses outside Studio, and it is reached only through Main's Studio-only DebugCommand
-- ("Scene", value) - every call marks the save DebugTainted like the other commands (never on the shared boards).
--   game.ServerScriptService.DebugCommand:Invoke("<player>", "Scene", "Calm")      a preset (PRESETS below)
--   game.ServerScriptService.DebugCommand:Invoke("<player>", "Scene", "Kill")      beats the nearest scene monster (a real kill)
--   game.ServerScriptService.DebugCommand:Invoke("<player>", "Scene", '{"Level":12,"At":"Zone:GoblinWoods"}')  a spec (JSON)
--   tools: py tools/scene.py <Preset | Kill | json> (STUDIO_NAME / HH_MAIN_STUDIO as for tools/studio_mcp.py; Play running)
-- Spec fields (all optional, applied in this order): Features = { [Config.Features key] = bool } (this server only),
-- Faction, Class, Level, Tutorial = step name (Config.Tutorial.Steps) or number, Done = { quest ids }, Mark = { Story.First keys },
-- Main = "M2_3:2" (the active main quest at that step), Sub = "KO1:3", Items = { [id] = n }, Gold = n (bank),
-- At = "Npc:<NpcId>" | "Landmark:<key>" | "Zone:<id>" | "Anvil" | "Bench:<Smith|Alch|Tame>" | "Boss:<FieldBosses key>" | "x,z",
-- Monsters = { { Kind, N, Dist, Anchor } } (event monsters near the player; Anchor = they stand still), Boss = a field boss
-- key (it appears now), Offer = an NPC id (its offer window opens), War = { EndsIn = s, Halo = points, Horns = points } (the
-- round ends then; both sides count as present until it does). Returns one line: "ok: <what was done>" or the first problem.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Util = require(Shared:WaitForChild("Util"))

local SceneSetup = {}
local S = nil
local ST = { Spawned = {} } -- Spawned[player] = the scene's monster records

-- the presets game dev 1 / 최종 검수 asked for (A23-218 ②, 10/16)
local DONE_CH1 = { "M1_1", "M1_3", "M1_4" }
local ARTISAN = { NeutralFaction = true, Gathering = true, Crafting = true, Tonics = true, Research = true, Gear = true }
local MATS = { Herb = 40, Jelly = 40, CopperOre = 30, SlimeCore = 20, Glowcap = 20, Petal = 20, OakLog = 20, GoblinTooth = 20,
	MoonCrystal = 20 }
SceneSetup.PRESETS = {
	-- the first Slime Prince fight (M1_1 step 1) in the meadow
	FirstPrince = { Faction = "Halo", Class = "Warrior", Level = 3, Tutorial = "Done", Main = "M1_1:1", At = "Zone:SlimeMeadow",
		Monsters = { { Kind = "BigSlime", N = 1, Dist = 14 } } },
	-- the fountain choice (M2_3 step 2)
	FountainChoice = { Faction = "Halo", Class = "Warrior", Level = 8, Tutorial = "Done", Done = DONE_CH1, Main = "M2_3:2",
		At = "Landmark:Fountain" },
	-- the Lv5 teacher with M1_3's offer window open (game dev 1's OfferM1_3: the Before line + the reward row)
	OfferM1_3 = { Faction = "Halo", Class = "Warrior", Level = 5, Tutorial = "Done", Done = { "M1_1" }, Mark = { "TeacherMet" },
		At = "Npc:Gleam", Offer = "Gleam" },
	-- Pip at the woods' edge (Lv10, the barrel race daily once its pack is in)
	PipGate = { Faction = "Horns", Class = "Archer", Level = 10, Tutorial = "Done", Done = DONE_CH1, At = "Npc:Pip" },
	-- Captain Clatter in front of you in the Crown Pit
	ClatterBoss = { Faction = "Halo", Class = "Warrior", Level = 25, Tutorial = "Done", Done = DONE_CH1, Boss = "Clatter",
		At = "Boss:Clatter" },
	-- game dev 1's calm fade check: three slimes + a Slime Prince held 12-14 studs away (then "Kill" one by one), the King Slime
	Calm = { Faction = "Halo", Class = "Warrior", Level = 5, Tutorial = "Done", Done = { "M1_1" }, At = "Zone:SlimeMeadow",
		Monsters = { { Kind = "Slime", N = 3, Dist = 12, Anchor = true }, { Kind = "BigSlime", N = 1, Dist = 14, Anchor = true } },
		Boss = "SlimeKing" },
	-- the crown-war round ends in 3 s at 7 : 3
	WarEnd = { Faction = "Halo", Class = "Warrior", Level = 10, Tutorial = "Done", Done = DONE_CH1, War = { EndsIn = 3, Halo = 7, Horns = 3 } },
	-- the first mission: the Teacher step beside Gleam / the Forge step beside Otto's anvil
	TutorialTeacher = { Faction = "Halo", Class = "Warrior", Level = 1, Tutorial = "Teacher", At = "Npc:Gleam" },
	TutorialForge = { Faction = "Halo", Class = "Warrior", Level = 1, Tutorial = "Forge", At = "Anvil" },
	-- an artisan at the workbench with materials (the artisan switches on for this server)
	ArtisanAlch = { Features = ARTISAN, Faction = "Neutral", Class = "Mage", Level = 8, Tutorial = "Done", Items = MATS, Gold = 5000,
		At = "Bench:Alch" },
	ArtisanSmith = { Features = ARTISAN, Faction = "Neutral", Class = "Warrior", Level = 8, Tutorial = "Done", Items = MATS,
		Gold = 5000, At = "Bench:Smith" },
}

local function rootOf(model)
	if typeof(model) ~= "Instance" then return nil end
	if model:IsA("BasePart") or model:IsA("Part") then return model end
	if model:IsA("Model") then return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true) end
	return nil
end

-- the place At names (a Vector3), or nil + why
local function placeOf(at)
	local kind, key = string.match(tostring(at), "^(%a+):(.+)$")
	if kind == "Npc" then
		for _, m in CollectionService:GetTagged(Config.StoryQuests.NpcTag) do
			local r = m:GetAttribute("NpcId") == key and rootOf(m)
			if r then return r.Position end
		end
		return nil, "no StoryNpc " .. key
	elseif kind == "Landmark" then
		local p = Config.StoryQuests.Landmarks[key]
		return typeof(p) == "Vector3" and p or nil, "no landmark " .. key
	elseif kind == "Zone" then
		local z = Config.Zones[key]
		return z and z.Center or nil, "no zone " .. key
	elseif kind == "Bench" then
		for _, part in CollectionService:GetTagged(Config.Craft.StationTag) do
			if part:GetAttribute("Role") == key and rootOf(part) then return rootOf(part).Position end
		end
		return nil, "no workbench " .. key
	elseif kind == "Boss" then
		local b = Config.FieldBosses[key]
		return b and typeof(b.Spawn) == "Vector3" and b.Spawn or nil, "no field boss spawn " .. key
	elseif at == "Anvil" then
		local ok, anvil = pcall(S.ShopService.Anvil)
		local r = ok and rootOf(anvil)
		return r and r.Position or nil, "no anvil"
	end
	local x, z = string.match(tostring(at), "^(%-?[%d%.]+),%s*(%-?[%d%.]+)$")
	if x then return Vector3.new(tonumber(x), 0, tonumber(z)) end
	return nil, "unknown place " .. tostring(at)
end

-- stands the player beside `pos` (4 studs off, on the ground under it)
local function moveTo(player, pos)
	local char = player.Character
	if not char then return "no character" end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(pos + Vector3.new(4, 200, 4), Vector3.new(0, -400, 0), params)
	local ground = hit and hit.Position or (pos + Vector3.new(4, 0, 4))
	char:PivotTo(CFrame.lookAt(ground + Vector3.new(0, 4, 0), Vector3.new(pos.X, ground.Y + 4, pos.Z)))
	return nil
end

local function setStat(player, key, value)
	local old = S.ClassService.GetClass(player)
	S.PlayerService.SetStat(player, key, value)
	if key == "Class" then S.ClassService.ClassChanged:Fire(player, S.ClassService.GetClass(player), old) end
end

local function story(data)
	if type(data.Story) ~= "table" then data.Story = {} end
	for _, k in { "Subs", "Done", "Pick", "First", "Flags" } do
		if type(data.Story[k]) ~= "table" then data.Story[k] = {} end
	end
	return data.Story
end

local function apply(player, spec)
	local did = {}
	local data = S.PlayerService.GetData(player)
	if type(data) ~= "table" then return "no data" end
	for k, v in type(spec.Features) == "table" and spec.Features or {} do
		if Config.Features[k] ~= nil then Config.Features[k] = v == true end
	end
	if spec.Faction then
		S.FactionService.SetFaction(player, spec.Faction, "Choose")
		table.insert(did, spec.Faction)
	end
	if spec.Class then
		setStat(player, "Class", spec.Class)
		setStat(player, "ClassChosen", true)
	end
	if spec.Level then
		setStat(player, "Level", math.floor(tonumber(spec.Level) or 1))
		table.insert(did, "Lv" .. tostring(spec.Level))
	end
	if spec.Faction or spec.Class or spec.Level then S.PlayerService.RefreshCharacter(player, true) end
	if spec.Tutorial ~= nil then
		local step = Config.Tutorial.Steps[spec.Tutorial] or tonumber(spec.Tutorial)
		if not step then return "unknown tutorial step " .. tostring(spec.Tutorial) end
		setStat(player, "TutorialStep", step)
	end
	local st = story(data)
	for _, id in type(spec.Done) == "table" and spec.Done or {} do
		local r = S.StoryQuestService.DebugDone(player, id)
		if r ~= "ok" then return r end
	end
	for _, key in type(spec.Mark) == "table" and spec.Mark or {} do st.First[key] = true end
	if spec.Main then
		local id, n = string.match(tostring(spec.Main), "^([%w_]+):(%d+)$")
		local def = id and Config.StoryQuests.Defs[id]
		if not def or def.Kind ~= "Main" then return "no main quest " .. tostring(spec.Main) end
		st.Done[id] = nil
		st.Main = { Id = id, St = tonumber(n), P = 0, T = {}, Claim = false }
		table.insert(did, spec.Main)
	end
	if spec.Sub then
		local id, n = string.match(tostring(spec.Sub), "^([%w_]+):?(%d*)$")
		local r = S.StoryQuestService.DebugSub(player, id or "", tonumber(n) or 1)
		if r ~= "ok" then return r end
		table.insert(did, spec.Sub)
	end
	for id, n in type(spec.Items) == "table" and spec.Items or {} do
		pcall(S.LootService.GrantItem, player, id, math.min(99, math.floor(tonumber(n) or 1)))
	end
	if tonumber(spec.Gold) then pcall(S.ProgressionService.AddBankGold, player, math.floor(tonumber(spec.Gold)), "Debug") end
	pcall(S.StoryQuestService.Refresh, player)
	if spec.At then
		local pos, why = placeOf(spec.At)
		if not pos then return why end
		local err = moveTo(player, pos)
		if err then return err end
		table.insert(did, tostring(spec.At))
	end
	if spec.Boss then table.insert(did, spec.Boss .. " " .. tostring(S.FieldBossService.DebugSpawn(spec.Boss))) end
	local root = Util.GetRoot(player)
	ST.Spawned[player] = ST.Spawned[player] or {}
	for _, m in type(spec.Monsters) == "table" and spec.Monsters or {} do
		for _ = 1, math.clamp(math.floor(tonumber(m.N) or 1), 1, 10) do
			local rec = root and S.MonsterService.SpawnEvent(m.Kind, { Near = root.Position, Radius = tonumber(m.Dist) or 12 })
			if rec then
				if m.Anchor == true and rec.Root then rec.Root.Anchored = true end
				table.insert(ST.Spawned[player], rec)
			end
		end
		table.insert(did, tostring(m.N or 1) .. " " .. tostring(m.Kind))
	end
	if spec.Offer then
		local r = S.StoryQuestService.TalkToNpc(player, spec.Offer)
		table.insert(did, "talk " .. spec.Offer .. " -> " .. tostring(r))
	end
	if type(spec.War) == "table" then
		table.insert(did, "war " .. tostring(S.WarService.DebugRound(spec.War.EndsIn, spec.War.Halo, spec.War.Horns)))
	end
	return "ok: " .. table.concat(did, ", ")
end

-- beats the nearest living monster this player's scenes made (a real kill through DamageMonster: drops, the calm fade)
function SceneSetup.Kill(player)
	local root = Util.GetRoot(player)
	local best, bestD = nil, math.huge
	for _, rec in ST.Spawned[player] or {} do
		if rec.Alive and rec.Root and root then
			local d = (rec.Root.Position - root.Position).Magnitude
			if d < bestD then best, bestD = rec, d end
		end
	end
	if not best then return "no scene monster left" end
	S.MonsterService.DamageMonster(best, (tonumber(best.HP) or 0) + 1, player)
	return "ok: beat " .. tostring(best.Kind)
end

-- value = a preset name, "Kill", or a JSON spec
function SceneSetup.Apply(player, value)
	if not RunService:IsStudio() then return "studio only" end
	if value == "Kill" then return SceneSetup.Kill(player) end
	local spec = SceneSetup.PRESETS[value]
	if not spec and type(value) == "string" and string.sub(value, 1, 1) == "{" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, value)
		spec = ok and type(decoded) == "table" and decoded or nil
	end
	if type(spec) ~= "table" then
		local names = {}
		for k in SceneSetup.PRESETS do table.insert(names, k) end
		table.sort(names)
		return "unknown scene; presets: " .. table.concat(names, " ") .. ", Kill, or a JSON spec"
	end
	local ok, res = pcall(apply, player, spec)
	return ok and res or ("error: " .. tostring(res))
end

function SceneSetup.Init(registry)
	S = registry
end

function SceneSetup.Start()
	game:GetService("Players").PlayerRemoving:Connect(function(player) ST.Spawned[player] = nil end)
end

return SceneSetup
