-- decor_collision.luau (검수 2026-10-08, SPEC A23-81 — user: "나무, 풀, 이런거를 뚫으면 안되지 캐릭터가. 비켜갈 수 있어야지")
-- Studio MCP execute_luau, MAIN place, Edit mode only. Makes the world decoration block PLAYERS so they walk round it:
--  * trees: the mesh never collides (no invisible canopy hull wall); one invisible cylinder "TrunkPost" at the trunk
--    blocks (an existing TrunkPost from meadow_dress is reused);
--  * bushes, rocks, stumps, logs, fences (posts AND rails), carts, crates, benches, mushrooms, tombstones, pillars, spikes,
--    statues, lamps, signs ... (anything 1.5+ studs tall that is walk-through today) become solid;
--  * knee-low pieces (< 1.5 studs: flowers, grass tufts, lily pads, puddles, pinwheels) and light / effect / water / road
--    parts stay walk-through (hunting lawns keep their tufts walk-through);
--  * everything this tool makes solid goes in the collision group "DecorPlayerOnly" (collides with "Players" only), so
--    monsters and pets are never stuck on decoration; CanQuery stays false on them (spawn / ground / pet rays and the
--    camera ignore them) and CanTouch false. The server registers the same group (PlayerService, 게임성 개발 3); this tool
--    also registers it in the place so Edit and Play agree.
--  * pieces that already collide (cliff boulders, sea rocks, bridges, buildings, benches) are left as they are, except a
--    tree mesh that collides as a whole: it gets the trunk post instead.
-- MODE (the runner replaces "__MODE__"): "plan" = count only (no writes), "apply" (default), "restore" = put back every
-- part this tool changed (attributes DecorCollWas / DecorCollMade) and remove the posts it made.
-- Idempotent: a part already changed (attribute DecorCollWas) is skipped; a re-run after meadow_dress re-dressing fixes the
-- new pieces only. Run it after any decoration tool (meadow_dress, kit_main, crossroads swap, zone kits).

local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "restore" then MODE = "apply" end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local PhysicsService = game:GetService("PhysicsService")

local T = {
	Group = "DecorPlayerOnly",
	PlayersGroup = "Players", -- Config.Player.CollisionGroup (PlayerService)
	LowY = 1.5, -- pieces lower than this stay walk-through
	-- top-level Decor children never touched (structures with their own collision, effects, borders, roads)
	SkipFolder = { "^Roads$", "^MeadowWaterfall$", "^PvPBorder", "^Bridge_", "^Disc$", "^CrossroadsKit$" },
	-- names that always stay walk-through (light, effect, ground cover)
	Pass = { "Flower", "Grass", "Tuft", "Clover", "Lily", "Petal", "Pinwheel", "Puddle", "Wisp", "RedEye", "Glow", "Light",
		"Sparkle", "Mist", "Water", "Falls", "Foam", "Road", "Path", "Disc", "Flag", "Shadow", "Decal", "Collider" },
	Tree = { "Tree", "Pine", "Willow", "Oak", "Birch", "Palm" },
	Fence = { "Fence" }, -- fences block even when low (rails between posts)
	NotPass = { "Cart", "Pot", "Stand", "Basket", "Box" }, -- a FlowerCart / FlowerPot is furniture, not ground cover
	Trunk = { RFrac = 0.09, RMin = 0.6, RMax = 6, HFrac = 0.45, HMin = 4, HMax = 20 },
}

local function hasAny(name, list)
	for _, k in list do
		if string.find(name, k, 1, true) then return true end
	end
	return false
end
local function matchAny(name, pats)
	for _, p in pats do
		if string.match(name, p) then return true end
	end
	return false
end

local map = workspace:FindFirstChild("Map")
local decor = map and map:FindFirstChild("Decor")
if not decor then return "no workspace.Map.Decor" end

-- one "piece" = the outermost Model under a zone folder (or a loose BasePart); zone folders are Models / Folders whose
-- children are pieces. MeadowDress keeps pieces inside Big / Small cell folders, so descend through plain folders and
-- through Models that only hold other Models (cells).
local pieces = {}
local function isContainer(inst)
	if inst:IsA("Folder") then return true end
	if not inst:IsA("Model") then return false end
	if inst:FindFirstChildWhichIsA("BasePart") then return false end
	return inst:FindFirstChildWhichIsA("Model") ~= nil or inst:FindFirstChildWhichIsA("Folder") ~= nil
end
local function collect(node)
	for _, c in node:GetChildren() do
		if isContainer(c) then
			collect(c)
		elseif c:IsA("Model") or c:IsA("BasePart") then
			table.insert(pieces, c)
		end
	end
end
for _, z in decor:GetChildren() do
	if matchAny(z.Name, T.SkipFolder) then continue end
	if isContainer(z) or z:IsA("Model") then
		if z:IsA("Model") and z:FindFirstChildWhichIsA("BasePart") and not z:FindFirstChildWhichIsA("Model") then
			-- a zone Model holding loose parts (e.g. PumpkinPatch posts / rails, SeaRocks): every part is a piece
			for _, p in z:GetChildren() do
				if p:IsA("BasePart") then table.insert(pieces, p) elseif p:IsA("Model") then table.insert(pieces, p) end
			end
		else
			collect(z)
		end
	elseif z:IsA("BasePart") then
		table.insert(pieces, z)
	end
end

local function partsOf(piece)
	if piece:IsA("BasePart") then return { piece } end
	local out = {}
	for _, d in piece:GetDescendants() do
		if d:IsA("BasePart") then table.insert(out, d) end
	end
	return out
end
local function bbox(piece)
	if piece:IsA("BasePart") then return piece.CFrame, piece.Size end
	return piece:GetBoundingBox()
end

local stats = { pieces = #pieces, solid = 0, solidParts = 0, trees = 0, postsMade = 0, postsReused = 0, meshOff = 0,
	keptPass = 0, keptSolid = 0, restored = 0, removed = 0, unanchored = 0 }
local kinds = {}
local function note(kind, name)
	local base = (string.gsub(string.gsub(name, "_%d+$", ""), "%d+$", ""))
	local k = kind .. ":" .. base
	kinds[k] = (kinds[k] or 0) + 1
end

if MODE == "restore" then
	for _, d in decor:GetDescendants() do
		if d:IsA("BasePart") then
			if d:GetAttribute("DecorCollMade") then
				d:Destroy()
				stats.removed += 1
			else
				local was = d:GetAttribute("DecorCollWas")
				if type(was) == "string" then
					local c, q, t, g = string.match(was, "^(%d)(%d)(%d)|(.*)$")
					if c then
						d.CanCollide, d.CanQuery, d.CanTouch = c == "1", q == "1", t == "1"
						pcall(function() d.CollisionGroup = g end)
					end
					d:SetAttribute("DecorCollWas", nil)
					stats.restored += 1
				end
			end
		end
	end
	return string.format("restore: %d parts put back, %d trunk posts removed", stats.restored, stats.removed)
end

local function remember(p)
	if p:GetAttribute("DecorCollWas") == nil then
		p:SetAttribute("DecorCollWas", string.format("%d%d%d|%s", p.CanCollide and 1 or 0, p.CanQuery and 1 or 0,
			p.CanTouch and 1 or 0, p.CollisionGroup))
	end
end
local function makeSolid(p)
	-- 게임성 개발 3 review: the group never collides with Default (terrain), so an unanchored part would fall through the
	-- ground; such parts stay as they are and are counted
	if not p.Anchored then
		stats.unanchored += 1
		return
	end
	remember(p)
	p.CanCollide, p.CanQuery, p.CanTouch = true, false, false
	p.CollisionGroup = T.Group
end

if MODE == "apply" then
	local okReg = pcall(function()
		if not PhysicsService:IsCollisionGroupRegistered(T.Group) then PhysicsService:RegisterCollisionGroup(T.Group) end
		if not PhysicsService:IsCollisionGroupRegistered(T.PlayersGroup) then
			PhysicsService:RegisterCollisionGroup(T.PlayersGroup)
		end
		for _, g in PhysicsService:GetRegisteredCollisionGroups() do
			PhysicsService:CollisionGroupSetCollidable(T.Group, g.name, g.name == T.PlayersGroup)
		end
	end)
	if not okReg then return "could not register the collision group " .. T.Group .. " (nothing changed)" end
end

for _, piece in pieces do
	local name = piece.Name
	local cf, size = bbox(piece)
	local parts = partsOf(piece)
	if #parts == 0 then continue end
	local anyColl, allChanged = false, true
	for _, p in parts do
		if p.CanCollide and p.Name ~= "TrunkPost" then anyColl = true end
		if p:GetAttribute("DecorCollWas") == nil and not p:GetAttribute("DecorCollMade") then allChanged = false end
	end
	if allChanged then continue end -- done on an earlier run

	if hasAny(name, T.Tree) then
		stats.trees += 1
		note("tree", name)
		local post = piece:IsA("Model") and piece:FindFirstChild("TrunkPost", true) or nil
		if MODE == "apply" then
			for _, p in parts do
				if p.Name ~= "TrunkPost" and p.CanCollide then
					remember(p)
					p.CanCollide = false
					stats.meshOff += 1
				elseif p.Name ~= "TrunkPost" then
					remember(p) -- mark as handled (stays walk-through)
				end
			end
			if post then
				makeSolid(post)
				stats.postsReused += 1
			elseif piece:IsA("Model") then
				local r = math.clamp(T.Trunk.RFrac * math.min(size.X, size.Z), T.Trunk.RMin, T.Trunk.RMax)
				local h = math.clamp(T.Trunk.HFrac * size.Y, T.Trunk.HMin, T.Trunk.HMax)
				local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
				-- trunk = the lowest mesh part's centre in X/Z when the bbox is lopsided (leaning trees)
				local base = bottom
				local low
				for _, p in parts do
					if p.Name ~= "TrunkPost" and (not low or p.Position.Y - p.Size.Y / 2 < low.Position.Y - low.Size.Y / 2) then
						low = p
					end
				end
				if low then base = Vector3.new(low.Position.X, bottom.Y, low.Position.Z) end
				local post2 = Instance.new("Part")
				post2.Name = "TrunkPost"
				post2.Shape = Enum.PartType.Cylinder
				post2.Size = Vector3.new(h, r * 2, r * 2) -- cylinder axis = X, stood up below
				post2.CFrame = CFrame.new(base + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
				post2.Anchored = true
				post2.Transparency = 1
				post2.CastShadow = false
				post2:SetAttribute("Collider", true) -- ground rays (PetFollow) skip it, like meadow_dress posts
				post2:SetAttribute("DecorCollMade", true)
				post2.CanCollide, post2.CanQuery, post2.CanTouch = true, false, false
				post2.CollisionGroup = T.Group
				post2.Parent = piece
				stats.postsMade += 1
			end
		else
			stats.postsMade += post and 0 or 1
			stats.postsReused += post and 1 or 0
		end
		continue
	end

	local low = size.Y < T.LowY and not hasAny(name, T.Fence)
	if (hasAny(name, T.Pass) and not hasAny(name, T.NotPass)) or low then
		stats.keptPass += 1
		note("pass", name)
		continue
	end
	if anyColl then
		stats.keptSolid += 1
		note("kept", name)
		continue
	end
	stats.solid += 1
	note("solid", name)
	for _, p in parts do
		if p.Transparency >= 0.98 then continue end -- invisible helpers stay as they are
		if MODE == "apply" then makeSolid(p) end
		stats.solidParts += 1
	end
end

local keys = {}
for k, n in kinds do table.insert(keys, string.format("%s=%d", k, n)) end
table.sort(keys)
return string.format("%s: %d pieces | solid now %d (%d parts) | trees %d (posts made %d, reused %d, canopy meshes off %d)"
	.. " | walk-through kept %d | already solid kept %d | unanchored skipped %d | group %s\n%s", MODE, stats.pieces,
	stats.solid, stats.solidParts, stats.trees, stats.postsMade, stats.postsReused, stats.meshOff, stats.keptPass,
	stats.keptSolid, stats.unanchored, T.Group,
	table.concat(keys, ", "))
