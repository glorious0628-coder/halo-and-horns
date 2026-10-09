-- decor_ground.luau (검수 2026-10-09, user: "초원 나무가 붕 떠 보여" — after meadow_terrain re-sculpted the ground)
-- Studio MCP execute_luau, MAIN place, Edit mode only. Re-grounds decoration on the terrain as it is now:
-- for every decoration piece (a Model named Kit_* / W_* / K_*, outermost one only) under the given roots, rays are shot
-- down onto Terrain from the centre and from 8 points on a ring round the base (ring radius = 0.3 x the shorter footprint
-- side, trees 0.16 x at most 5; a second ring at 1.6 x), the LOWEST terrain height is taken, and the piece is moved straight up / down so that the
-- bottom of its visible meshes sits SINK studs under it (SINK = 25% of the piece height, clamped 0.5 .. 1.0; no tilt).
-- Only pieces that float more than FLOAT_MIN above the lowest ground, or are buried deeper than BURY_MAX, are moved.
-- MODE is one string: "<plan|apply|restore>|<roots>|<box>"
--   roots = comma list of paths under workspace (default "Map.Decor.MeadowDress,Map.Decor.MeadowKit"), e.g. "Map.Decor.WoodsKit"
--   4th field "floatonly" = never move a buried piece (only list the most buried)
--   box   = "minX,minZ,maxX,maxZ" (a piece is used when its centre is inside) or "all" (default)
-- plan = read only; apply = move (attribute GroundDelta keeps the move so restore can undo it); restore = undo.
-- Idempotent: a piece already within tolerance is not touched. Reports floating count, max height, buried count.
local RAW = "__MODE__"
local parts = string.split(RAW, "|")
local MODE = parts[1]
if MODE ~= "plan" and MODE ~= "restore" then MODE = "apply" end
local ROOTS = (parts[2] and parts[2] ~= "") and string.split(parts[2], ",") or { "Map.Decor.MeadowDress", "Map.Decor.MeadowKit" }
local BOX
if parts[3] and parts[3] ~= "" and parts[3] ~= "all" then
	local n = string.split(parts[3], ",")
	BOX = { tonumber(n[1]), tonumber(n[2]), tonumber(n[3]), tonumber(n[4]) }
end
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local FLOAT_ONLY = parts[4] == "floatonly" -- 4th field: only lower pieces that float; buried pieces are listed, never moved
local FLOAT_MIN, BURY_MAX = 0.3, 1.6

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = true

local function groundY(x, z)
	local h = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	return h and h.Position.Y or nil
end
local function isPiece(m)
	return m:IsA("Model") and (string.find(m.Name, "^Kit_") or string.find(m.Name, "^W_") or string.find(m.Name, "^K_")) ~= nil
end
local function outermostPiece(m)
	local a = m.Parent
	while a and a ~= workspace do
		if isPiece(a) then return false end
		a = a.Parent
	end
	return true
end
-- bottom of the visible meshes + the footprint
local function measure(m)
	local minY, minX, maxX, minZ, maxZ = math.huge, math.huge, -math.huge, math.huge, -math.huge
	local found = false
	for _, d in m:GetDescendants() do
		if d:IsA("MeshPart") and d.Transparency < 0.95 then
			found = true
			local cf, sz = d.CFrame, d.Size
			-- the 8 corners of the part's box
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for sz2 = -1, 1, 2 do
						local p = (cf * CFrame.new(sx * sz.X / 2, sy * sz.Y / 2, sz2 * sz.Z / 2)).Position
						if p.Y < minY then minY = p.Y end
						if p.X < minX then minX = p.X end
						if p.X > maxX then maxX = p.X end
						if p.Z < minZ then minZ = p.Z end
						if p.Z > maxZ then maxZ = p.Z end
					end
				end
			end
		end
	end
	if not found then return nil end
	return minY, maxX - minX, maxZ - minZ
end

local pieces, seen = {}, {}
for _, path in ROOTS do
	local node = workspace
	for _, n in string.split(path, ".") do node = node and node:FindFirstChild(n) end
	if node then
		for _, d in node:GetDescendants() do
			if isPiece(d) and outermostPiece(d) and not seen[d] then
				seen[d] = true
				table.insert(pieces, d)
			end
		end
	else
		warn("decor_ground: root not found: " .. path)
	end
end

local checked, floating, moved, buried, restored, noGround = 0, 0, 0, 0, 0, 0
local maxFloat, maxBury, sumFloat = 0, 0, 0
local worst, buriedList = {}, {}
for _, m in pieces do
	local pv = m:GetPivot().Position
	if BOX and not (pv.X >= BOX[1] and pv.X <= BOX[3] and pv.Z >= BOX[2] and pv.Z <= BOX[4]) then continue end
	if MODE == "restore" then
		local was = m:GetAttribute("GroundDelta")
		if type(was) == "number" then
			m:PivotTo(m:GetPivot() + Vector3.new(0, -was, 0))
			m:SetAttribute("GroundDelta", nil)
			restored += 1
		end
		continue
	end
	local bottom, sx, sz = measure(m)
	if not bottom then continue end
	checked += 1
	local isTree = string.find(m.Name, "^W_Tree") ~= nil
	local r = math.min(isTree and 5 or 4, math.min(sx, sz) * (isTree and 0.16 or 0.3))
	local low = groundY(pv.X, pv.Z)
	if not low then noGround += 1 continue end
	for _, rr in { r, r * 1.6 } do -- the root flare / the wide base: two rings
		for k = 0, 7 do
			local a = k * math.pi / 4 + (rr == r and 0 or math.pi / 8)
			local y = groundY(pv.X + math.cos(a) * rr, pv.Z + math.sin(a) * rr)
			if y and y < low then low = y end
		end
	end
	local _, size = m:GetBoundingBox()
	local sink = math.clamp(size.Y * 0.25, 0.5, 1.0)
	local target = low - sink
	local delta = target - bottom -- negative = move down
	local float = bottom - low -- how far the bottom is above the lowest ground
	if float > FLOAT_MIN then
		floating += 1
		sumFloat += float
		if float > maxFloat then maxFloat = float end
		table.insert(worst, { float, m:GetFullName() .. string.format(" @(%.0f,%.0f)", pv.X, pv.Z) })
	end
	local bury = low - bottom
	if bury > BURY_MAX then
		buried += 1
		if bury > maxBury then maxBury = bury end
	end
	if bury > BURY_MAX then table.insert(buriedList, { bury, m:GetFullName() .. string.format(" @(%.0f,%.0f)", pv.X, pv.Z) }) end
	if float > FLOAT_MIN or (bury > BURY_MAX and not FLOAT_ONLY) then
		if MODE == "apply" then
			m:PivotTo(m:GetPivot() + Vector3.new(0, delta, 0))
			m:SetAttribute("GroundDelta", (m:GetAttribute("GroundDelta") or 0) + delta)
			moved += 1
		end
	end
end
table.sort(worst, function(a, b) return a[1] > b[1] end)
table.sort(buriedList, function(a, b) return a[1] > b[1] end)
local btop = {}
for i = 1, math.min(8, #buriedList) do table.insert(btop, string.format("%.1f %s", buriedList[i][1], buriedList[i][2])) end
local top = {}
for i = 1, math.min(5, #worst) do table.insert(top, string.format("%.1f %s", worst[i][1], worst[i][2])) end
if MODE == "restore" then return string.format("restore: %d pieces moved back", restored) end
return string.format("%s: roots %s box %s | checked %d, floating (> %.1f) %d (max %.1f, avg %.1f), buried (> %.1f) %d (max %.1f), moved %d, no ground %d%s",
	MODE, table.concat(ROOTS, "+"), BOX and table.concat(BOX, ",") or "all", checked, FLOAT_MIN, floating, maxFloat,
	floating > 0 and sumFloat / floating or 0, BURY_MAX, buried, maxBury, moved, noGround,
	(#top > 0 and ("\nworst floating: " .. table.concat(top, " | ")) or "")
		.. (#btop > 0 and ("\nmost buried: " .. table.concat(btop, " | ")) or ""))
