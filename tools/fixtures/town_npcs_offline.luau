-- town_npcs_offline.luau : the town people's bodies (TownNpcs.luau, zone_check_halo #22 / #24 / #25 / #26 / #27 / #30 / #34,
-- 게임성 개발 3, 2026-10-10). tools/test_town_npcs.py binds CONFIG_SOURCE and TOWNNPCS_SOURCE in front of dev2_kit.luau; this file
-- follows. TownNpcs runs from source on doubles: a tiny Instance tree (Folder / Model / Humanoid / parts / prompts), the avatar
-- call (Players:CreateHumanoidModelFromDescription, which the real game yields on), a workspace ray (t.Ground(x, z) -> height /
-- { Y, NormalY } / nil), the CollectionService tags and the Crossroads anvil part. The kit's CFrame double records the call
-- ("lookAt" / "new") and its arguments.

local function colorEnv()
	local env = nativeEnv()
	local function c(r, g, b) return { __kind = "Color3", R = r, G = g, B = b } end
	env.Color3 = { new = c, fromRGB = c, fromHSV = c }
	return env
end

local CFG_ENV = colorEnv()
local C0 = execute("Config", CONFIG_SOURCE, CFG_ENV)

local R15 = { "HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm",
	"RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }

local methods, mt = {}, {}
local function object(kind, name)
	return setmetatable({ _p = { ClassName = kind, Name = name or kind, __kind = "Instance" }, _children = {}, _attrs = {} }, mt)
end
mt.__index = function(self, key) return methods[key] or self._p[key] end
mt.__newindex = function(self, key, value)
	if key == "Parent" then
		local old = self._p.Parent
		if old == value then return end
		if old then
			local idx = table.find(old._children, self)
			if idx then table.remove(old._children, idx) end
		end
		self._p.Parent = value
		if value then table.insert(value._children, self) end
	else
		self._p[key] = value
	end
end
function methods:IsA(kind)
	return self.ClassName == kind or (kind == "BasePart" and (self.ClassName == "MeshPart" or self.ClassName == "Part"))
		or (kind == "LuaSourceContainer" and (self.ClassName == "Script" or self.ClassName == "LocalScript" or self.ClassName == "ModuleScript"))
		or (kind == "ModuleScript" and self.ClassName == "ModuleScript")
end
function methods:GetAttribute(key) return self._attrs[key] end
function methods:SetAttribute(key, value) self._attrs[key] = value end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
	local out = {}
	local function visit(n) for _, c in n._children do table.insert(out, c); visit(c) end end
	visit(self)
	return out
end
function methods:FindFirstChild(name) for _, c in self._children do if c.Name == name then return c end end return nil end
function methods:FindFirstChildOfClass(kind) for _, c in self._children do if c:IsA(kind) then return c end end return nil end
function methods:IsDescendantOf(parent)
	local p = self.Parent
	while p do
		if p == parent then return true end
		p = p.Parent
	end
	return false
end
function methods:Destroy()
	for _, c in self:GetChildren() do c:Destroy() end
	self.Parent = nil
	self.Destroyed = true
end
function methods:GetPivot() return self.Pivot end
function methods:GetBoundingBox() return self.Pivot, vec(4, 5.2, 2) end
function methods:PivotTo(cf)
	if cf.Ctor == "lookAt" then
		self.Pivot = { Position = cf.Args[1], Look = cf.Args[2] }
	else
		self.Pivot = { Position = cf.Args[1] }
	end
	if self.PrimaryPart then self.PrimaryPart.Position = self.Pivot.Position end
end

-- one world per scenario
local function townWorld(o)
	o = o or {}
	local t = { Tags = {}, Warnings = {}, Ctx = { pieces = 0 }, Created = {}, Queue = {}, Defer = false, Rays = {}, Characters = {} }
	local cfg = execute("Config", CONFIG_SOURCE, colorEnv())
	t.Config = cfg
	local npcs = object("Folder", "NPCs")
	t.NPCs = npcs
	-- the Crossroads anvil (Map.Landmarks.ArtisanGuild.Anvil), at (39, 0, 49) unless o.NoAnvil
	local map = object("Folder", "Map")
	if not o.NoAnvil then
		local lm = object("Folder", "Landmarks"); lm.Parent = map
		local guild = object("Model", "ArtisanGuild"); guild.Parent = lm
		local anvil = object(o.AnvilModel and "Model" or "Part", "Anvil"); anvil.Position = o.AnvilAt or vec(39, 0, 49); anvil.Parent = guild
		t.Anvil = anvil
	end
	-- the ground: a flat 5 studs on the plaza, 0.2 elsewhere, unless the scenario says otherwise
	function t.Ground(x, z)
		if z <= -444 then return 5 end
		return 0.2
	end
	local ws = { FindFirstChild = function(_, name) if name == "Map" then return map end return nil end }
	function ws:Raycast(origin, direction, params)
		table.insert(t.Rays, { Origin = origin, Direction = direction, Params = params })
		local g = t.Ground(origin.X, origin.Z)
		if g == nil then return nil end
		if type(g) == "table" then return { Position = vec(origin.X, g.Y, origin.Z), Normal = vec(0, g.NormalY, 0) } end
		return { Position = vec(origin.X, g, origin.Z), Normal = vec(0, 1, 0) }
	end
	local players = {}
	function players:GetPlayers()
		local out = {}
		for _, ch in t.Characters do table.insert(out, { Character = ch }) end
		return out
	end
	function players:CreateHumanoidModelFromDescription(desc, rigType)
		table.insert(t.Created, { Desc = desc, Rig = rigType })
		if t.CreateError then error("avatar service unavailable") end
		if t.OnCreate then
			local hook = t.OnCreate
			t.OnCreate = nil
			hook()
		end
		local npc = object("Model", "Player")
		npc.Pivot = { Position = vec(40, 7.6, 40) }
		local human = object("Humanoid", "Humanoid")
		human.Health, human.WalkSpeed, human.JumpPower, human.AutoRotate, human.DisplayDistanceType = 100, 16, 50, true, "Viewer"
		human.Parent = npc
		for _, name in R15 do
			if not (t.NoRoot and name == "HumanoidRootPart") then
				local part = object(name == "HumanoidRootPart" and "Part" or "MeshPart", name)
				part.Position = vec(40, 7.6, 40)
				part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = false, true, true, true
				part.Parent = npc
			end
		end
		for _, kind in { "Script", "LocalScript" } do
			local s = object(kind, "Animate" .. kind); s.Parent = npc
		end
		local nested = object("ModuleScript", "Nested"); nested.Parent = npc:FindFirstChild("Head")
		t.LastNpc = npc
		return npc
	end
	local replicated = { Shared = { Config = cfg, Util = { Warn = function(_, msg) table.insert(t.Warnings, msg) end } } }
	local services = {
		CollectionService = { AddTag = function(_, inst, tag)
			if t.AddTagFail and inst.Name == t.AddTagFail then error("tag service failed") end
			t.Tags[inst] = t.Tags[inst] or {}
			table.insert(t.Tags[inst], tag)
		end },
		ReplicatedStorage = replicated,
		Players = players,
	}
	local env = colorEnv()
	env.game = { GetService = function(_, name) return assert(services[name], "service " .. tostring(name)) end }
	env.workspace = ws
	env.typeof = typeofDouble
	env.Instance = { new = function(kind) return object(kind, kind) end }
	env.RaycastParams = { new = function() return {} end }
	env.task = { spawn = function(fn, ...) if t.Defer then table.insert(t.Queue, table.pack(fn, ...)) else fn(...) end end }
	env.require = function(m) return m end
	env.pcall = pcall
	local mod = execute("TownNpcs", TOWNNPCS_SOURCE, env)
	t.Mod = mod
	function t.Ensure() return mod.Ensure(t.Ctx, npcs) end
	function t.Flush()
		local q = t.Queue
		t.Queue = {}
		for _, job in q do job[1](table.unpack(job, 2, job.n)) end
	end
	function t.Tagged(inst, tag) for _, x in t.Tags[inst] or {} do if x == tag then return true end end return false end
	function t.Npc(name) return npcs:FindFirstChild(name) end
	function t.PromptOf(npc, name) return npc.PrimaryPart and npc.PrimaryPart:FindFirstChild(name) end
	return t
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

------------------------------------------------------------------ config
runGroup("config", function()
	local T = C0.TownNpcs
	check(T.Enabled == true and T.PromptDistance == 10 and T.PromptDistance < C0.StoryQuests.NpcRange, "on; the prompt range is inside the story's NpcRange", show(T.PromptDistance))
	local ids, names, kinds = {}, {}, { Story = 0, Folk = 0, Merchant = 0, Anvil = 0 }
	local halo = C0.Zones.HaloTown
	for _, e in T.List do
		check(not ids[e.Id] and not names[e.Name], e.Id .. ": a unique id and model name", e.Name)
		ids[e.Id], names[e.Name] = true, true
		if e.Story then kinds.Story += 1 end
		if e.Folk then kinds.Folk += 1 end
		if e.Merchant then kinds.Merchant += 1 end
		if e.Anvil then kinds.Anvil += 1 end
		if e.At then
			check(math.abs(e.At.X - halo.Center.X) <= halo.Size.X / 2 and math.abs(e.At.Z - halo.Center.Z) <= halo.Size.Z / 2,
				e.Id .. " stands inside Halo Citadel", show(e.At))
		end
	end
	check(kinds.Story == 2 and kinds.Folk == 4 and kinds.Merchant == 1 and kinds.Anvil == 1, "Bright + Sir Gleam, 4 townsfolk, 1 potion seller, Otto", show(kinds))
	check(ids.Bright and ids.Gleam and ids.Folk1 and ids.Folk4 and ids.PotionHalo and ids.Otto, "the ids the plan names", "")
	-- every NPC a quest step names that is a Halo town person has a body (Smokey / Tiny come with the Horns / Crossroads turns)
	local storyIds = {}
	for _, e in T.List do if e.Story then storyIds[e.Story] = true end end
	local named = {}
	for _, def in C0.StoryQuests.Defs do
		for _, step in def.Steps or {} do if step.Npc then named[step.Npc] = true end end
	end
	check(storyIds.Bright and named.Bright, "Bright is named by quest steps and has a body", show(named))
	for _, e in T.List do
		if e.Merchant then check(e.Enabled == false, "the Halo potion seller stays off until ShopService accepts more than one seller", tostring(e.Enabled)) end
	end
end)

------------------------------------------------------------------ the build
runGroup("build", function()
	local t = townWorld()
	local n = t.Ensure()
	local built = #t.Created
	check(n == 8 and built == 7, "8 entries queued, 7 bodies made (the potion seller is switched off)", show({ n, built }))
	check(t.Ctx.pieces == 7, "ctx.pieces counts the 7 new bodies", tostring(t.Ctx.pieces))
	check(t.Npc("PotionMerchant_Halo") == nil, "no body for the switched-off seller", "")
	-- Bright
	local b = t.Npc("Npc_Bright")
	check(b ~= nil and b.ClassName == "Model" and b.PrimaryPart == b:FindFirstChild("HumanoidRootPart"), "Bright: a model with its root as PrimaryPart", "")
	check(b:GetAttribute("NpcId") == "Bright" and t.Tagged(b, "StoryNpc") and t.Tagged(b, "NPC") and b:GetAttribute("HHC_TownNpc") == "Bright"
		and b:GetAttribute("HHC_TownNpcLook") == "DefaultNPC", "Bright: tagged StoryNpc with NpcId, ours, the temporary look", show(t.Tags[b]))
	local prompt = t.PromptOf(b, "TalkPrompt")
	check(prompt and prompt.ClassName == "ProximityPrompt" and prompt.ActionText == "Talk" and prompt.ObjectText == "Bright"
		and prompt.KeyboardKeyCode == "KeyCode.G" and prompt.HoldDuration == 0 and prompt.MaxActivationDistance == 10 and prompt.RequiresLineOfSight == false
		and prompt.Enabled == true and prompt:GetAttribute("StoryNpcId") == "Bright" and prompt:GetAttribute("Conversation") == true,
		"Bright: a 'Talk' prompt (G, tap, 10 studs) that names her", show(prompt and { prompt.ActionText, prompt.KeyboardKeyCode, prompt.MaxActivationDistance }))
	local pv = b:GetPivot()
	check(near(pv.Position.X, 18) and near(pv.Position.Z, -452) and near(pv.Position.Y, 5 + 2.6), "Bright stands at (18, -452) with her feet on the ground (Y 5 + 2.6)", show(pv.Position))
	check(near(pv.Look.X, 0) and near(pv.Look.Z, -420) and near(pv.Look.Y, pv.Position.Y), "... facing the spawn side (0, -420) at her own height", show(pv.Look))
	-- the body: no scripts, anchored, no collision, a standing humanoid
	local parts = 0
	for _, d in b:GetDescendants() do
		check(not d:IsA("LuaSourceContainer"), "no default script is kept", "")
		if d:IsA("BasePart") then
			parts += 1
			check(d.Anchored and not d.CanCollide and not d.CanTouch and not d.CanQuery, "a part is anchored, no collide / touch / query", d.Name)
		end
	end
	check(parts == #R15, "all 16 R15 parts", tostring(parts))
	local h = b:FindFirstChildOfClass("Humanoid")
	check(h.WalkSpeed == 0 and h.JumpPower == 0 and h.AutoRotate == false and h.DisplayDistanceType == "HumanoidDisplayDistanceType.None",
		"the humanoid cannot move or turn and shows no name plate", show({ h.WalkSpeed, h.DisplayDistanceType }))
	-- the description: Bright's colours, the arms in the colour of the torso (sleeves)
	local made = t.Created[1]
	local bc = C0.TownNpcs.List[1].Colors
	check(made.Desc.ClassName == "HumanoidDescription" and made.Rig == "HumanoidRigType.R15", "a HumanoidDescription R15 body", tostring(made.Rig))
	check(made.Desc.HeadColor.R == bc.Head.R and made.Desc.TorsoColor.R == bc.Torso.R and made.Desc.LeftArmColor.R == bc.Torso.R and made.Desc.RightArmColor.G == bc.Torso.G
		and made.Desc.LeftLegColor.B == bc.Legs.B and made.Desc.RightLegColor.B == bc.Legs.B, "Bright's colours; long sleeves; trousers", show(made.Desc.TorsoColor))
	-- Sir Gleam
	local g = t.Npc("Npc_Gleam")
	check(g:GetAttribute("NpcId") == "Gleam" and t.Tagged(g, "StoryNpc") and t.PromptOf(g, "TalkPrompt").ObjectText == "Sir Gleam", "Sir Gleam: a talker too", "")
	-- the townsfolk: tagged, no prompt, on the plaza
	for i = 1, 4 do
		local f = t.Npc("Npc_Folk" .. i)
		check(f ~= nil and t.Tagged(f, "TownFolk") and f:GetAttribute("FolkId") == "Folk" .. i and not t.Tagged(f, "StoryNpc") and t.PromptOf(f, "TalkPrompt") == nil,
			"Folk" .. i .. ": a townsperson, tagged TownFolk, no prompt", show(t.Tags[f]))
		check(near(f:GetPivot().Position.Y, 5 + 2.6), "Folk" .. i .. ": feet on the ground", show(f:GetPivot().Position))
	end
	-- Otto: 4 studs behind the anvil, away from the Crossroads middle, facing it
	local o = t.Npc("Npc_Otto")
	local len = math.sqrt(39 * 39 + 49 * 49)
	local op = o:GetPivot()
	check(o ~= nil and near(op.Position.X, 39 + 39 / len * 4) and near(op.Position.Z, 49 + 49 / len * 4) and near(op.Position.Y, 0.2 + 2.6),
		"Otto stands 4 studs behind the anvil (away from the Crossroads middle), feet on the ground", show(op.Position))
	check(near(op.Look.X, 0) and near(op.Look.Z, 0), "... facing the Crossroads middle", show(op.Look))
	check(t.PromptOf(o, "TalkPrompt") == nil and t.Tagged(o, "NPC") and not t.Tagged(o, "StoryNpc"), "Otto is decorative: no prompt (the anvil keeps the shop prompt)", "")
	-- the ground ray: from high up, straight down, ignoring the NPC folder
	local ray = t.Rays[1]
	check(ray.Origin.Y == 150 and ray.Direction.X == 0 and ray.Direction.Y == -210 and ray.Direction.Z == 0, "the ray starts 150 up and goes 210 down", show({ ray.Origin, ray.Direction }))
	check(table.find(ray.Params.FilterDescendantsInstances, t.NPCs) ~= nil and ray.Params.FilterType == "RaycastFilterType.Exclude",
		"the NPC folder is excluded from the ray", show(ray.Params.FilterType))
end)

runGroup("the potion seller (switched on)", function()
	local t = townWorld()
	for _, e in t.Config.TownNpcs.List do if e.Merchant then e.Enabled = true end end
	t.Ensure()
	local m = t.Npc("PotionMerchant_Halo")
	check(m ~= nil and #t.Created == 8, "switched on: a body for the seller", tostring(#t.Created))
	check(t.Tagged(m, "PotionMerchant") and t.Tagged(m, "NPC") and m:GetAttribute("HHC_PotionMerchant") == true and m:GetAttribute("NpcId") == nil, "tagged PotionMerchant like the Crossroads seller, not a story NPC", show(t.Tags[m]))
	local p = t.PromptOf(m, t.Config.Vitals.PotionMerchantPrompt)
	check(p and p.ActionText == "Buy potions" and p.ObjectText == "Potion Seller" and p.KeyboardKeyCode == "KeyCode.G" and p.HoldDuration == 0
		and p.MaxActivationDistance == t.Config.Vitals.PotionMerchantDistance and p.Enabled == true and p:GetAttribute("StoryNpcId") == nil,
		"the shop prompt (the Crossroads seller's name and range), no StoryNpcId", show(p and { p.ActionText, p.ObjectText }))
	check(near(m:GetPivot().Position.X, -34) and near(m:GetPivot().Position.Z, -546) and near(m:GetPivot().Position.Y, 5 + 2.6), "at the potion stall (-34, -546), feet on the ground", show(m:GetPivot().Position))
	check(near(m:GetPivot().Look.X, 0), "facing the plaza axis", show(m:GetPivot().Look))
	-- the seller's colours default to the Crossroads seller's (Config.Vitals.PotionMerchantColors)
	local vc = t.Config.Vitals.PotionMerchantColors
	check(t.Created[7].Desc.TorsoColor.R == vc.Torso.R and t.Created[7].Desc.LeftLegColor.R == vc.Legs.R and t.Created[7].Desc.HeadColor.R == vc.Head.R,
		"the same default colours as the Crossroads seller", show(t.Created[7].Desc.TorsoColor))
end)

------------------------------------------------------------------ idempotent, repairing, moving
runGroup("a second build", function()
	local t = townWorld()
	t.Ensure()
	local before, pieces = #t.Created, t.Ctx.pieces
	local npc = t.Npc("Npc_Bright")
	t.Ensure()
	check(#t.Created == before and t.Ctx.pieces == pieces and t.Npc("Npc_Bright") == npc and #t.NPCs:GetChildren() == 7,
		"a rebuild changes nothing: no second body, no new pieces", show({ #t.Created, t.Ctx.pieces, #t.NPCs:GetChildren() }))
	-- a missing prompt is repaired
	t.PromptOf(npc, "TalkPrompt"):Destroy()
	t.Ensure()
	local repaired = t.PromptOf(npc, "TalkPrompt")
	check(repaired and repaired.ActionText == "Talk" and repaired:GetAttribute("StoryNpcId") == "Bright", "a deleted prompt is made again", "")
	-- a foreign object under the prompt's name is replaced by the real prompt
	local junkRoot = t.Npc("Npc_Gleam").PrimaryPart
	t.PromptOf(t.Npc("Npc_Gleam"), "TalkPrompt"):Destroy()
	local junk = object("Part", "TalkPrompt")
	junk.Parent = junkRoot
	t.Ensure()
	local real = junkRoot:FindFirstChild("TalkPrompt")
	check(real ~= junk and real ~= nil and real.ClassName == "ProximityPrompt" and junk.Destroyed == true, "a non-prompt under the prompt's name is replaced", "")
	-- an unchanged spot never moves a body again
	local sentinel = { Position = vec(1, 2, 3), Look = vec(1, 2, 4) }
	t.Npc("Npc_Folk1").Pivot = sentinel
	t.Ensure()
	check(t.Npc("Npc_Folk1"):GetPivot() == sentinel, "the same spot: the body is not moved again", "")
	-- a changed spot moves the same body
	for _, e in t.Config.TownNpcs.List do if e.Id == "Bright" then e.At = vec(-18, 0, -470) end end
	t.Ensure()
	check(t.Npc("Npc_Bright") == npc and #t.Created == before and near(npc:GetPivot().Position.X, -18) and near(npc:GetPivot().Position.Z, -470)
		and npc:GetAttribute("HHC_TownNpcAt") == "-18.0,-470.0", "a new Config spot moves the body (no new body)", show(npc:GetPivot().Position))
	-- one body that cannot be repaired does not stop the others (Folk2 moves although Bright's tag service call throws)
	t.AddTagFail = "Npc_Bright"
	for _, e in t.Config.TownNpcs.List do if e.Id == "Folk2" then e.At = vec(-30, 0, -590) end end
	local warned = #t.Warnings
	t.Ensure()
	t.AddTagFail = nil
	check(near(t.Npc("Npc_Folk2"):GetPivot().Position.X, -30) and #t.Warnings == warned + 1, "a failing body is a warning; the next ones are still repaired / moved", show({ #t.Warnings, warned }))
	-- the config switched off: the prompts go quiet, the bodies stay
	t.Config.TownNpcs.Enabled = false
	t.Ensure()
	check(t.PromptOf(npc, "TalkPrompt").Enabled == false and t.Npc("Npc_Gleam") ~= nil and #t.Created == before, "Config.TownNpcs.Enabled = false: prompts off, bodies stay, nothing new", "")
	t.Config.TownNpcs.Enabled = true
	t.Ensure()
	check(t.PromptOf(npc, "TalkPrompt").Enabled == true, "switched on again: the prompt is back", "")
	-- an entry turned off later: its prompt goes quiet
	for _, e in t.Config.TownNpcs.List do if e.Id == "Gleam" then e.Enabled = false end end
	t.Ensure()
	check(t.PromptOf(t.Npc("Npc_Gleam"), "TalkPrompt").Enabled == false, "an entry with Enabled = false: its prompt is off", "")
end)

------------------------------------------------------------------ failures and bad input
runGroup("failures", function()
	-- no ground under any spot (the map is not built here): nothing is made, one warning each, the build never throws
	local t = townWorld()
	function t.Ground() return nil end
	t.Ensure()
	check(#t.NPCs:GetChildren() == 0 and #t.Warnings >= 1, "no ground: no body, a warning", show({ #t.NPCs:GetChildren(), #t.Warnings }))
	-- a slope is not ground
	local s = townWorld()
	function s.Ground(x, z) return { Y = 3, NormalY = 0.5 } end
	s.Ensure()
	check(#s.NPCs:GetChildren() == 0, "a steep surface under a spot is not ground", tostring(#s.NPCs:GetChildren()))
	local flat = townWorld()
	function flat.Ground(x, z) return { Y = 3, NormalY = 0.7 } end
	flat.Ensure()
	check(#flat.NPCs:GetChildren() == 7, "a slope of exactly 0.7 is still ground", tostring(#flat.NPCs:GetChildren()))
	-- the heights follow the ground (a stepped terrace)
	local st = townWorld()
	function st.Ground(x, z) if z <= -524 then return 11 end if z <= -444 then return 5 end return 0.2 end
	st.Ensure()
	check(near(st.Npc("Npc_Bright"):GetPivot().Position.Y, 5 + 2.6) and near(st.Npc("Npc_Folk1"):GetPivot().Position.Y, 11 + 2.6) and near(st.Npc("Npc_Gleam"):GetPivot().Position.Y, 0.2 + 2.6),
		"each body takes its own terrace height (0.2 / 5 / 11)", show({ st.Npc("Npc_Bright"):GetPivot().Position.Y, st.Npc("Npc_Folk1"):GetPivot().Position.Y }))
	-- the avatar service failing
	local e = townWorld()
	e.CreateError = true
	e.Ensure()
	check(#e.NPCs:GetChildren() == 0 and #e.Warnings >= 7, "the avatar call failing: nothing left half-built, a warning each", show({ #e.NPCs:GetChildren(), #e.Warnings }))
	local nr = townWorld()
	nr.NoRoot = true
	nr.Ensure()
	check(#nr.NPCs:GetChildren() == 0 and nr.LastNpc == nil or (#nr.NPCs:GetChildren() == 0 and nr.LastNpc.Destroyed == true), "a body without a root part is thrown away", tostring(#nr.NPCs:GetChildren()))
	-- the ground disappears between the check and the placing: the body is thrown away, not left at a bad height
	local mid = townWorld()
	local calls = 0
	function mid.Ground()
		calls += 1
		if calls % 2 == 0 then return nil end
		return 5
	end
	mid.Ensure()
	check(#mid.NPCs:GetChildren() == 0 and mid.LastNpc.Destroyed == true and #mid.Warnings >= 7, "no ground at the placing: the made body is destroyed, a warning each", show({ #mid.NPCs:GetChildren(), #mid.Warnings }))
	-- somebody else made the same model while the avatar was being made: ours is thrown away
	local meanwhile = townWorld()
	meanwhile.OnCreate = function()
		local other = object("Model", "Npc_Bright")
		other:SetAttribute("HHC_TownNpc", "Bright")
		other.Parent = meanwhile.NPCs
	end
	meanwhile.Ensure()
	check(#meanwhile.Created == 7 and meanwhile.NPCs:FindFirstChild("Npc_Bright"):GetAttribute("HHC_TownNpc") == "Bright" and #meanwhile.NPCs:GetChildren() == 7,
		"a model that appeared meanwhile is kept; the new body is dropped (never two under one name)", show(#meanwhile.NPCs:GetChildren()))
	-- an anvil that is not a part is no anvil
	local am = townWorld({ AnvilModel = true })
	am.Ensure()
	check(am.Npc("Npc_Otto") == nil and am.Npc("Npc_Bright") ~= nil, "an 'Anvil' that is not a part: no Otto", "")
	-- the name taken by something else: skipped, the others are built
	local oc = townWorld()
	local other = object("Model", "Npc_Bright")
	other.Parent = oc.NPCs
	oc.Ensure()
	check(oc.NPCs:FindFirstChild("Npc_Bright") == other and other:GetAttribute("HHC_TownNpc") == nil and oc.Npc("Npc_Gleam") ~= nil and #oc.Warnings >= 1,
		"a foreign model under the name is left alone (a warning), the rest is built", show(#oc.Warnings))
	local oc2 = townWorld()
	local part = object("Part", "Npc_Gleam")
	part.Parent = oc2.NPCs
	oc2.Ensure()
	check(oc2.NPCs:FindFirstChild("Npc_Gleam") == part and oc2.Npc("Npc_Bright") ~= nil, "a non-model under the name is left alone too", "")
	-- no anvil: Otto is skipped
	local na = townWorld({ NoAnvil = true })
	na.Ensure()
	check(na.Npc("Npc_Otto") == nil and na.Npc("Npc_Bright") ~= nil, "no anvil in the map: no Otto, the rest is built", "")
	-- bad entries
	local bad = townWorld()
	local L = bad.Config.TownNpcs.List
	table.insert(L, { Id = "Bright", Name = "Npc_Dup", Story = "Bright", At = vec(0, 0, -400) })
	table.insert(L, { Id = "NoName", Story = "X", At = vec(0, 0, -400) })
	table.insert(L, { Id = "Nan", Name = "Npc_Nan", Folk = "Nan", At = vec(0 / 0, 0, -400) })
	table.insert(L, { Id = "Far", Name = "Npc_Far", Folk = "Far", At = vec(1e9, 0, -400) })
	table.insert(L, { Id = "Inf", Name = "Npc_Inf", Folk = "Inf", At = vec(math.huge, 0, 0) })
	table.insert(L, { Id = "NoAt", Name = "Npc_NoAt", Folk = "NoAt" })
	table.insert(L, "text")
	table.insert(L, 5)
	table.insert(L, { Id = 5, Name = "Npc_Five" })
	table.insert(L, { Id = "DupName", Name = "Npc_Folk1", Folk = "DupName", At = vec(0, 0, -400) })
	bad.Ensure()
	check(#bad.Mod.Entries() == 12 and #bad.NPCs:GetChildren() == 7 and #bad.Warnings >= 4,
		"duplicate ids, nameless and junk rows are dropped; NaN / huge / infinite / missing spots are refused at build (a warning each)", show({ #bad.Mod.Entries(), #bad.NPCs:GetChildren(), #bad.Warnings }))
	-- Config.TownNpcs missing altogether
	local none = townWorld()
	none.Config.TownNpcs = nil
	check(none.Ensure() == 0 and #none.NPCs:GetChildren() == 0, "no Config.TownNpcs: nothing, no error", "")
	-- the ray ignores the players' characters
	local pc = townWorld()
	local char = object("Model", "Character")
	pc.Characters = { char }
	pc.Ensure()
	local list = pc.Rays[1].Params.FilterDescendantsInstances
	check(table.find(list, char) ~= nil and table.find(list, pc.NPCs) ~= nil, "a player's character is excluded from the ground ray (it would be 'ground')", show(#list))
	-- queued, not built while Build runs
	local q = townWorld()
	q.Defer = true
	q.Ensure()
	check(#q.Created == 0 and #q.NPCs:GetChildren() == 0 and q.Ctx.pieces == 7, "Build only queues the work (bodies come after it returns)", show({ #q.Created, q.Ctx.pieces }))
	q.Flush()
	check(#q.NPCs:GetChildren() == 7, "the queued task builds them", tostring(#q.NPCs:GetChildren()))
end)

finish()
