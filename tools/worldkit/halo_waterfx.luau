-- halo_waterfx.luau (이미지 생성 1, 2026-10-11, 검수 A23-120 "폭포가 흐름 없는 파란 덩어리"): flowing water on every Halo town water sheet.
-- Studio MCP execute_luau, Edit mode (WorldKit first, then 메인 반영 with the halo_terrain / halo_props order: terrain -> props -> this).
-- Reads ServerStorage.HaloTerrainStore attribute "Waterfalls" (written by halo_terrain apply: "name_step,x,z,topY,dx,dz;..." = the top
-- of each water sheet and its outward direction) and builds, per sheet, in Workspace.Map.Decor.HaloWaterFx:
--   * a Beam (flowing streak texture, TextureSpeed > 0 = it moves down by itself, no script) from the lip to the pool / sea below,
--     its plane facing outward, a little in front of the terrain water
--   * a mist ParticleEmitter at the foot (the default round soft particle: round puffs only, no rays)
--   * a thin white foam ring floating on the pool / sea where the sheet lands
-- MODE "apply" (default) rebuilds the folder, "remove" deletes it, "plan" only counts. STREAK = the uploaded streak texture id ("" =
-- the beam is left out and only mist + foam are made, so the look never invents a texture).

local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "remove" then MODE = "apply" end
local STREAK = "" -- rbxassetid of art/out/Halo_WaterfallStreaks (white / aqua streaks, alpha from luminance); set after the upload
local CFG = {
	Half = 4, -- the terrain sheet half width (halo_terrain CAS.Half)
	Lip = 0.6, -- studs in front of the terrain water face
	Speed = 1.4, -- beam texture speed (studs / s, downward)
	Length = 7, -- beam texture length (studs per repeat)
	Mist = { Rate = 14, Life = NumberRange.new(1.2, 2.0), Size = 3.2, Speed = NumberRange.new(1.5, 3) },
	Foam = { Thick = 0.25, Extra = 3 }, -- foam ring: a flat disc a bit wider than the sheet
	WaterColor = Color3.fromRGB(215, 240, 255),
}
if game:GetService("RunService"):IsRunning() then error("Edit 모드에서만 실행하세요.") end
local store = game:GetService("ServerStorage"):FindFirstChild("HaloTerrainStore")
assert(store, "HaloTerrainStore missing: run halo_terrain apply first")
local spec = store:GetAttribute("Waterfalls") or ""
local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
assert(decor, "Workspace.Map.Decor missing")
local old = decor:FindFirstChild("HaloWaterFx")
if MODE == "remove" then
	if old then old:Destroy() end
	return "halo_waterfx removed"
end

local sheets = {}
for item in string.gmatch(spec, "[^;]+") do
	local name, x, z, top, dx, dz = string.match(item, "^([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$")
	if name then
		table.insert(sheets, { name = name, x = tonumber(x), z = tonumber(z), top = tonumber(top), dx = tonumber(dx), dz = tonumber(dz) })
	end
end
if MODE == "plan" then return "halo_waterfx plan: " .. #sheets .. " sheets" end
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "HaloWaterFx"
folder:SetAttribute("PlacedBy", "halo_waterfx.luau")
folder.Parent = decor

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude
rp.FilterDescendantsInstances = { folder }
rp.IgnoreWater = true
local made = 0
for _, s in sheets do
	local out = Vector3.new(s.dx, 0, s.dz).Unit
	local side = Vector3.new(-out.Z, 0, out.X)
	local lip = Vector3.new(s.x, s.top, s.z) + out * CFG.Lip
	-- where the sheet lands: the ground / pool floor under a point just out from the lip, then the water surface above it
	local hit = workspace:Raycast(lip + out * 1.5 + Vector3.new(0, 1, 0), Vector3.new(0, -80, 0), rp)
	local floorY = hit and hit.Position.Y or (s.top - 8)
	local waterHit = workspace:Raycast(lip + out * 1.5 + Vector3.new(0, 1, 0), Vector3.new(0, -80, 0), (function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = { folder }
		p.IgnoreWater = false
		return p
	end)())
	local landY = waterHit and math.max(waterHit.Position.Y, floorY) or floorY
	if s.top - landY < 1.5 then continue end

	local holder = Instance.new("Part")
	holder.Name = "Fall_" .. s.name
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(lip)
	holder:SetAttribute("Why", "흐르는 폭포 물줄기·물보라(규칙 3, A23-120)")
	holder.Parent = folder
	local a0 = Instance.new("Attachment")
	a0.Name = "Top"
	a0.WorldCFrame = CFrame.lookAt(lip, lip + out) -- the attachment's look = outward: the beam plane faces out (FaceCamera off)
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Name = "Bottom"
	local foot = Vector3.new(lip.X, landY + 0.3, lip.Z) + out * 0.8
	a1.WorldCFrame = CFrame.lookAt(foot, foot + out)
	a1.Parent = holder
	if STREAK ~= "" then
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = STREAK
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = CFG.Length
		b.TextureSpeed = CFG.Speed
		b.Width0, b.Width1 = CFG.Half * 2, CFG.Half * 2 + 0.6
		b.FaceCamera = false
		b.LightEmission = 0.25
		b.LightInfluence = 0.8
		b.Color = ColorSequence.new(CFG.WaterColor)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.85, 0.1), NumberSequenceKeypoint.new(1, 0.45) })
		b.Segments = 6
		b.Parent = holder
	end
	-- mist at the foot (round soft puffs)
	local mist = Instance.new("Attachment")
	mist.Name = "Mist"
	mist.WorldPosition = foot + Vector3.new(0, 0.6, 0)
	mist.Parent = holder
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = CFG.Mist.Rate
	pe.Lifetime = CFG.Mist.Life
	pe.Speed = CFG.Mist.Speed
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, CFG.Mist.Size * 0.5), NumberSequenceKeypoint.new(1, CFG.Mist.Size) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
	pe.LightEmission = 0.2
	pe.Acceleration = Vector3.new(0, 1.2, 0)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Parent = mist
	-- foam ring on the water where it lands (a flat white disc, half see-through)
	local foam = Instance.new("Part")
	foam.Name = "Foam"
	foam.Shape = Enum.PartType.Cylinder
	foam.Anchored, foam.CanCollide, foam.CanQuery, foam.CanTouch = true, false, false, false
	foam.Material = Enum.Material.SmoothPlastic
	foam.Color = Color3.fromRGB(245, 252, 255)
	foam.Transparency = 0.45
	local d = CFG.Half * 2 + CFG.Foam.Extra
	foam.Size = Vector3.new(CFG.Foam.Thick, d, d)
	foam.CFrame = CFrame.new(Vector3.new(foot.X, landY + 0.08, foot.Z)) * CFrame.Angles(0, 0, math.rad(90))
	foam.Parent = holder
	made += 1
end
return string.format("halo_waterfx applied: %d of %d sheets (beam %s)", made, #sheets, STREAK ~= "" and "on" or "OFF - no streak texture yet")
