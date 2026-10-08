-- supporter_board_place.luau (게임성 개발 1, 2026-10-08; 검수: 후원자 게시판 = 교차로 분수 광장 한 곳, 현상수배 판 맞은편 쪽,
-- 패드·길·가판대를 막지 않는 빈 자리, 분수를 보게; 금빛 판 X_NoticeBoard_Gold가 오기 전엔 복제본 + 금색 제목)
-- Studio MCP execute_luau, main place, Edit mode. Clones Map.Decor.Crossroads3D.X_NoticeBoard as X_SupporterBoard at SPOT
-- (south-east of the fountain: no pad, road or stall within its box - probe 10/08), facing the fountain, and adds the
-- invisible face part "SupporterFace" (tag "SupporterBoard": SupporterBoard.luau draws the names on its Front face) at the
-- same place on the board as the bounty list sits on X_NoticeBoard (Map.Landmarks.MostWantedBoard, board_fit.luau).
-- The clone keeps no tags, prompts, guis or scripts of the bounty board. Idempotent: a second run re-places the same clone.
-- MODE = "survey" only reports.
local MODE = "apply"
local SPOT = Vector3.new(36, 0, -36)
local FOUNTAIN = Vector3.new(0, 0, 0)
local TAG = "SupporterBoard"
-- X_NoticeBoard_Gold (art/approved.json: the same texture recoloured gold / cream / ruby, uploaded by 이미지 개발 1)
local GOLD = "rbxassetid://127012447674638"
local CollectionService = game:GetService("CollectionService")
local map = workspace:FindFirstChild("Map")
local c3 = map and map:FindFirstChild("Decor") and map.Decor:FindFirstChild("Crossroads3D")
local nb = c3 and c3:FindFirstChild("X_NoticeBoard")
local bounty = map and map:FindFirstChild("Landmarks") and map.Landmarks:FindFirstChild("MostWantedBoard")
assert(nb and nb:IsA("Model"), "Map.Decor.Crossroads3D.X_NoticeBoard missing")
assert(bounty and bounty:IsA("BasePart"), "Map.Landmarks.MostWantedBoard missing")
local out = {}
-- the bounty list's place on its board (pivot space); its SurfaceGui is on its +X (Right) face
local rel = nb:GetPivot():ToObjectSpace(bounty.CFrame)
-- the ground under the spot (the plaza cobblestone)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { map:FindFirstChild("Zones"), c3:FindFirstChild("X_SupporterBoard") }
params.IgnoreWater = true
local hit = workspace:Raycast(Vector3.new(SPOT.X, 80, SPOT.Z), Vector3.new(0, -160, 0), params)
local groundY = hit and hit.Position.Y or SPOT.Y
table.insert(out, string.format("ground at (%.0f, %.0f): %.2f (%s)", SPOT.X, SPOT.Z, groundY,
	hit and (hit.Instance == workspace.Terrain and ("Terrain " .. hit.Material.Name) or hit.Instance:GetFullName()) or "no hit"))
if MODE ~= "apply" then return table.concat(out, "\n") end

local board = c3:FindFirstChild("X_SupporterBoard")
if not board then
	board = nb:Clone()
	board.Name = "X_SupporterBoard"
	table.insert(out, "cloned X_NoticeBoard -> X_SupporterBoard")
end
-- nothing of the bounty board's job comes along
local removed = {}
local function clean(inst)
	for _, tag in CollectionService:GetTags(inst) do
		if not (tag == TAG and inst.Name == "SupporterFace") then
			CollectionService:RemoveTag(inst, tag)
			table.insert(removed, "tag " .. tag)
		end
	end
end
clean(board)
for _, d in board:GetDescendants() do
	if d:IsA("ProximityPrompt") or d:IsA("LuaSourceContainer") or d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
		table.insert(removed, d.ClassName .. " " .. d.Name)
		d:Destroy()
	else
		clean(d)
	end
end
if #removed > 0 then table.insert(out, "removed from the clone: " .. table.concat(removed, ", ")) end
-- the gold look: the bounty board's mesh wears its texture through a SurfaceAppearance ColorMap
local gold = {}
for _, d in board:GetDescendants() do
	-- a name of its own, so a search for the bounty board's mesh never finds this one
	if d:IsA("MeshPart") and d.Name == "X_NoticeBoard" then d.Name = "X_NoticeBoard_Gold" end
	if d:IsA("SurfaceAppearance") then
		local ok, err = pcall(function() d.ColorMap = GOLD end)
		table.insert(gold, ok and ("ColorMap of " .. d.Parent.Name) or ("ColorMap failed: " .. tostring(err)))
	elseif d:IsA("MeshPart") and not d:FindFirstChildWhichIsA("SurfaceAppearance") then
		d.TextureID = GOLD
		table.insert(gold, "TextureID of " .. d.Name)
	end
end
table.insert(out, "gold texture: " .. (#gold > 0 and table.concat(gold, ", ") or "no mesh found"))
board:PivotTo(CFrame.lookAt(Vector3.new(SPOT.X, groundY, SPOT.Z), Vector3.new(FOUNTAIN.X, groundY, FOUNTAIN.Z)))
board.Parent = c3

local face = board:FindFirstChild("SupporterFace")
if not (face and face:IsA("BasePart")) then
	face = Instance.new("Part")
	face.Name = "SupporterFace"
	face.Parent = board
end
face.Anchored = true
face.CanCollide = false
face.CanTouch = false
face.CanQuery = false
face.CastShadow = false
face.Transparency = 1
-- the bounty part is (depth, height, width) with its gui on +X; this one is (width, height, depth) with its gui on Front
face.Size = Vector3.new(bounty.Size.Z, bounty.Size.Y, 0.2)
face.CFrame = board:GetPivot() * rel * CFrame.Angles(0, -math.pi / 2, 0)
CollectionService:AddTag(face, TAG)

local p, look = face.Position, face.CFrame.LookVector
local toFountain = (Vector3.new(FOUNTAIN.X, p.Y, FOUNTAIN.Z) - p).Unit
table.insert(out, string.format("X_SupporterBoard pivot (%.1f, %.1f, %.1f); SupporterFace centre (%.1f, %.1f, %.1f) size %.2f x %.2f, "
	.. "front faces the fountain: dot %.2f; tagged %s: %s", board:GetPivot().Position.X, board:GetPivot().Position.Y,
	board:GetPivot().Position.Z, p.X, p.Y, p.Z, face.Size.X, face.Size.Y, look:Dot(toFountain), TAG,
	tostring(CollectionService:HasTag(face, TAG))))
table.insert(out, "tagged parts in the place: " .. #CollectionService:GetTagged(TAG))
return table.concat(out, "\n")
