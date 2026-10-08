-- crossroads_3d_swap.luau (검수 2026-10-08, A23-74 user: "지금까지 그린 거 다 어디갔어 / 이럴 거면 뭐하러 3D로 그렸냐")
-- Studio MCP execute_luau, MAIN place, Edit mode. Swaps the old 21-model K_* crossroads kit (Map.Decor.CrossroadsKit,
-- tools/worldkit/crossroads_kit_main.luau) for the Tripo models in ServerStorage.WorldKit3D (tools/build_kit_from_ids.py),
-- per docs/design/crossroads_3d_swap_2026-10-07.md:
--   * every old K_ model whose new model exists moves to ServerStorage.CrossroadsKOld (kept, never destroyed); the new
--     clone takes its spot (same XZ centre, same bottom height), front (-Z) toward the fountain or the old fixed yaw;
--   * a new model that is missing leaves the old one where it is (the screen never goes blank) and is listed MISSING;
--   * gameplay contract parts are not touched, except: the neon pads move onto the new pad bases (TopY attribute for
--     MapBuilder.placePad, touch stays) and the MostWantedBoard SurfaceGui part moves onto the new board face;
--   * the old KitLight holders (4 lamps + 1 brazier, map light budget 40) are cloned onto the new lamp / brazier;
--   * Kit_M_SignPost goes on the three roads out of the plaza (new, no old model).
-- Idempotent: Map.Decor.Crossroads3D is rebuilt from the stored old spots on every run.
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local SS = game:GetService("ServerStorage")
local kit = SS:FindFirstChild("WorldKit3D")
assert(kit, "ServerStorage.WorldKit3D missing: run tools/build_kit_from_ids.py first")
local map = workspace.Map
local D, L = map.Decor, map.Landmarks
local ck = D:FindFirstChild("CrossroadsKit")
assert(ck, "Map.Decor.CrossroadsKit missing (crossroads_kit_main.luau)")

-- old name -> new kit name; yaw = "face" (front toward the fountain) or fixed degrees (kit_main layout)
local SWAP = {
	K_Fountain = { new = "Town_Halo_Fountain", yaw = 0 },
	K_Bench = { new = "Kit_X_Bench", yaw = "face" },
	K_Lamp = { new = "Kit_X_Lamp", yaw = "face", light = true },
	K_StallRed = { new = "Kit_X_StallRed", yaw = "face" },
	K_StallBlue = { new = "Kit_X_StallBlue", yaw = "face" },
	K_StallGreen = { new = "Kit_X_StallGreen", yaw = "face" },
	K_Potion = { new = "Kit_X_PotionCart", yaw = "face" },
	K_Guild2 = { new = "X_GuildHall", yaw = 0 }, -- front north, toward the anvil / forge yard like the old hall
	K_Gear = { new = false, with = "X_GuildHall" }, -- the new hall already carries the big gear (검수 OK 10/08)
	K_Anvil = { new = "Kit_X_Anvil", yaw = 0 },
	K_Forge = { new = "Kit_X_Forge", yaw = 0 },
	K_Altar = { new = "X_Altar", yaw = 0 },
	K_Brazier = { new = "Kit_X_Brazier", yaw = 0, light = true },
	K_Nest = { new = "X_GooseNest", yaw = "face" },
	K_MarketArch = { new = "X_MarketArch", yaw = "face" },
	K_PoleHalo = { new = "Kit_X_BannerHalo", yaw = "face" },
	K_PoleHorns = { new = "Kit_X_BannerHorns", yaw = "face" },
	K_NoticeBoard2 = { new = "X_NoticeBoard", yaw = "face", board = true },
	K_PadBase = { new = "X_PadBase", yaw = 0, pad = true },
	Curb = { new = "Kit_X_Curb", yaw = "face", noCollide = true }, -- walk-through ring like the old one
}
local SIGNS = { { 11, -70 }, { -11, 70 }, { 86, -11 } } -- Kit_M_SignPost, front toward the plaza
local PAD_MAX_TOP = 1.45 -- old K_PadBase walk top above the plaza (saved place: pad TopY 1.4245)

local store = SS:FindFirstChild("CrossroadsKOld") or Instance.new("Folder")
store.Name = "CrossroadsKOld"
store.Parent = SS
local log, made, missing = {}, {}, {}

local function has(name) return name and kit:FindFirstChild(name) ~= nil end
local function centre(m)
	local cf = m:GetBoundingBox()
	return cf.Position
end
-- a K_ model already stored at (about) the same spot: crossroads_kit_main.luau was re-run after a swap
-- (tools/apply_studio_state.py step 5) and rebuilt a fresh copy; the stored one is identical
local function storedTwin(d)
	local p = centre(d)
	for _, s in store:GetChildren() do
		if s.Name == d.Name and (centre(s) - p).Magnitude < 0.5 then return s end
	end
	return nil
end
local function wanted(rule) return rule and ((rule.new and has(rule.new)) or (rule.new == false and has(rule.with))) end

-- 1. old models out (first run) / back in (a new model disappeared from WorldKit3D)
local function collect(folder)
	for _, d in folder:GetChildren() do
		local rule = SWAP[d.Name]
		if rule and wanted(rule) then
			if storedTwin(d) then
				d:Destroy()
			else
				d:SetAttribute("OrigParent", folder:GetFullName())
				d.Parent = store
			end
		elseif d:IsA("Model") and d.Name == "PlazaCurb" then
			collect(d)
		end
	end
end
collect(ck)
for _, d in store:GetChildren() do
	if not wanted(SWAP[d.Name]) then
		local back = d:GetAttribute("OrigParent") == ck:GetFullName() and ck or ck:FindFirstChild("PlazaCurb") or ck
		d.Parent = back
		table.insert(log, "restored " .. d.Name)
		if d.Name == "K_PadBase" then
			for _, pad in (map:FindFirstChild("Pads") and map.Pads:GetChildren() or {}) do
				local prev = pad:IsA("BasePart") and pad:GetAttribute("Swap3DPrevTopY")
				if prev then
					local delta = Vector3.new(0, prev - (pad.Position.Y + pad.Size.Y / 2), 0)
					for _, c in pad:GetDescendants() do
						if c:IsA("BasePart") then c.CFrame = c.CFrame + delta end
					end
					pad.CFrame = pad.CFrame + delta
					pad:SetAttribute("TopY", prev)
					pad:SetAttribute("Swap3DPrevTopY", nil)
				end
			end
		elseif d.Name == "K_NoticeBoard2" then
			local board = L:FindFirstChild("MostWantedBoard")
			if board and board:GetAttribute("Swap3DPrevCF") then
				board.CFrame = board:GetAttribute("Swap3DPrevCF")
				board:SetAttribute("Swap3DPrevCF", nil)
			end
		end
	end
end

local out = D:FindFirstChild("Crossroads3D")
if out then out:Destroy() end
out = Instance.new("Model")
out.Name = "Crossroads3D"
out.Parent = D -- now: the pad / board raycasts below only see parts inside Workspace

local function solidOf(old)
	for _, p in old:GetDescendants() do
		if p:IsA("BasePart") and p.CanCollide and p.Name ~= "KitLight" then return true end
	end
	return false
end

-- clone `name`, bottom-centre at (x, y, z), front toward the fountain or a fixed yaw
local function place(name, x, z, y, yaw, solid)
	local src = kit:FindFirstChild(name)
	if not src then
		missing[name] = true
		return nil
	end
	local m = src:Clone()
	local pos = Vector3.new(x, y, z)
	if yaw == "face" and (math.abs(x) + math.abs(z)) > 0.5 then
		m:PivotTo(CFrame.lookAt(pos, Vector3.new(0, y, 0)))
	else
		m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(tonumber(yaw) or 0), 0))
	end
	local cf, sz = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (Vector3.new(x, y + sz.Y / 2, z) - cf.Position))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = solid
			d.CanQuery = solid
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy() -- A23-33 safety: kit models never carry scripts
		end
	end
	m.Parent = out
	made[name] = (made[name] or 0) + 1
	return m
end

-- 2. new models on the stored spots
local lights, pads, boards = 0, 0, 0
local padParams = RaycastParams.new()
padParams.FilterType = Enum.RaycastFilterType.Include
for _, old in store:GetChildren() do
	local rule = SWAP[old.Name]
	if rule and rule.new then
		local cf, sz = old:GetBoundingBox()
		local x, z, y = cf.Position.X, cf.Position.Z, cf.Position.Y - sz.Y / 2
		local m = place(rule.new, x, z, y, rule.yaw, not rule.noCollide and solidOf(old))
		if m and rule.light then
			for _, h in old:GetDescendants() do
				if h:IsA("BasePart") and h.Name == "KitLight" then
					local c = h:Clone()
					c.Position = Vector3.new(x, h.Position.Y, z)
					c.Parent = m
					lights += 1
				end
			end
		end
		if m and rule.pad then
			-- the neon pad nearest this base sits on the new top (same as crossroads_kit_main.luau)
			padParams.FilterDescendantsInstances = { m }
			local hit = workspace:Raycast(Vector3.new(x, y + 40, z), Vector3.new(0, -80, 0), padParams)
			-- X_PadBase's walk top is ~5.1 studs up: too high to step on (new players would have to jump). Sink the base so
			-- its top sits where the old K_PadBase top was (~1.45 above the plaza); the sides go into the ground.
			if hit and hit.Position.Y - y > PAD_MAX_TOP then
				m:PivotTo(m:GetPivot() - Vector3.new(0, hit.Position.Y - y - PAD_MAX_TOP, 0))
				hit = workspace:Raycast(Vector3.new(x, y + 40, z), Vector3.new(0, -80, 0), padParams)
			end
			local topY = hit and (hit.Position.Y + 0.05)
			local best, bestD = nil, 8
			for _, pad in (map:FindFirstChild("Pads") and map.Pads:GetChildren() or {}) do
				if pad:IsA("BasePart") and pad:GetAttribute("KitBase") then
					local dd = (Vector2.new(pad.Position.X, pad.Position.Z) - Vector2.new(x, z)).Magnitude
					if dd < bestD then best, bestD = pad, dd end
				end
			end
			if best and not topY then
				table.insert(log, string.format("pad base top not found (%.0f, %.0f): pad left as is", x, z))
			elseif best then
				if best:GetAttribute("Swap3DPrevTopY") == nil then
					best:SetAttribute("Swap3DPrevTopY", best:GetAttribute("TopY") or (best.Position.Y + best.Size.Y / 2))
				end
				local delta = Vector3.new(0, topY - (best.Position.Y + best.Size.Y / 2), 0)
				for _, c in best:GetDescendants() do
					if c:IsA("BasePart") then c.CFrame = c.CFrame + delta end
				end
				best.CFrame = best.CFrame + delta
				best:SetAttribute("TopY", topY) -- MapBuilder.placePad keeps this height at runtime
				pads += 1
			else
				table.insert(log, string.format("no pad near base (%.0f, %.0f)", x, z))
			end
		end
		if m and rule.board then
			-- the MostWantedBoard (+X SurfaceGui) moves onto the new board's front face, same size / height as before
			local board = L:FindFirstChild("MostWantedBoard")
			if board and board:GetAttribute("KitPrevCF") then
				padParams.FilterDescendantsInstances = { m }
				local face = nil
				for _, dz in { -4, 0, 4 } do
					local hit = workspace:Raycast(Vector3.new(x + 20, board.Position.Y, z + dz), Vector3.new(-40, 0, 0), padParams)
					if hit and (not face or hit.Position.X > face) then face = hit.Position.X end
				end
				if face then
					if board:GetAttribute("Swap3DPrevCF") == nil then board:SetAttribute("Swap3DPrevCF", board.CFrame) end
					local bcf, bsz = m:GetBoundingBox()
					table.insert(log, string.format("board face x %.2f (model centre x %.2f, box %.1f x %.1f): check a photo",
						face, bcf.Position.X, bsz.X, bsz.Z))
					board.CFrame = CFrame.new(face + board.Size.X / 2 + 0.05, board.Position.Y, z) * board.CFrame.Rotation
					boards += 1
				else
					table.insert(log, "board face not found")
				end
			end
		end
	end
end

-- 3. signposts on the roads out of the plaza (ground under each from a ray that ignores decor)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.FilterDescendantsInstances = { D, out }
for _, xz in SIGNS do
	local hit = workspace:Raycast(Vector3.new(xz[1], 200, xz[2]), Vector3.new(0, -400, 0), groundParams)
	place("Kit_M_SignPost", xz[1], xz[2], hit and hit.Position.Y or 0, "face", true)
end
for k, v in made do table.insert(log, k .. " x" .. v) end
for k in missing do table.insert(log, "MISSING " .. k) end
table.insert(log, string.format("lights %d, pads %d, board %d, old stored %d, old K_ left %d", lights, pads, boards,
	#store:GetChildren(), #ck:GetChildren()))
return table.concat(log, " | ")
