-- halo_waterfx.luau (이미지 생성 1, 2026-10-11, 검수 A23-120 "폭포가 흐름 없는 파란 덩어리"): flowing water on every Halo town water sheet.
-- Studio MCP execute_luau, Edit mode (WorldKit first, then 메인 반영 with the halo_terrain / halo_props order: terrain -> props -> this).
-- Reads ServerStorage.HaloTerrainStore attribute "Waterfalls" (written by halo_terrain apply: "name_step,x,z,topY,dx,dz;..." = the top
-- of each water sheet and its outward direction) and builds, per sheet, in Workspace.Map.Decor.HaloWaterFx:
--   * a Beam (flowing streak texture, TextureSpeed > 0 = it moves down by itself, no script) from the lip to the pool / sea below,
--     its plane facing outward, a little in front of the terrain water
--   * a mist ParticleEmitter at the foot (PUFF = the built-in smoke puff: round only, no rays)
--   * white foam puffs on the pool / sea where the sheet lands (round particles lying flat; the flat disc of 10/11 read as a plate)
-- MODE "apply" (default) rebuilds the folder, "remove" deletes it, "plan" only counts. STREAK = the uploaded streak texture id ("" =
-- the beam is left out and only mist + foam are made, so the look never invents a texture).

local MODE = "__MODE__"
if MODE ~= "plan" and MODE ~= "remove" then MODE = "apply" end
local STREAK = "rbxassetid://111806947888357" -- art/ui/Halo_WaterfallStreaks.png (Firefly High, alpha from brightness: tools/streak_alpha.py)
local PUFF = "rbxasset://textures/particles/smoke_main.dds" -- round soft puff; the default particle is a spiky sparkle (no rays)
local CFG = {
	Half = 4, -- the terrain sheet half width (halo_terrain CAS.Half)
	Lip = 0.6, -- studs out from the sheet top where the strip starts
	Walk = 14, -- how far out (studs) to look for the landing
	Lift = 0.25, -- strip height above the water surface
	Speed = 1.4, -- beam texture speed (studs / s, downward)
	Length = 7, -- beam texture length (studs per repeat)
	Mist = { Rate = 14, Life = NumberRange.new(1.2, 2.0), Size = 3.2, Speed = NumberRange.new(1.5, 3) },
	Foam = { Rate = 18, Size = 2.6 }, -- foam puffs at the landing (round, flat on the water)
	Width = 3, -- the streak strip is this much wider than the terrain sheet (it read too thin on 10/11)
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
local rpw = RaycastParams.new()
rpw.FilterType = Enum.RaycastFilterType.Exclude
rpw.FilterDescendantsInstances = { folder }
rpw.IgnoreWater = false
local made = 0
for _, s in sheets do
	local out = Vector3.new(s.dx, 0, s.dz).Unit
	local side = Vector3.new(-out.Z, 0, out.X)
	-- the terrain sheets are sloped water ramps (~6 studs out from the top), not vertical walls: walk outward along the
	-- water surface (ground where there is no water) and land where it stops dropping
	local base = Vector3.new(s.x, s.top, s.z)
	local function surfY(d)
		local p = base + out * d + Vector3.new(0, 1.5, 0)
		local h = workspace:Raycast(p, Vector3.new(0, -80, 0), rpw)
		return h and h.Position.Y or (s.top - 80)
	end
	local lipY = surfY(CFG.Lip)
	local landD, landY = CFG.Lip, lipY
	for d = CFG.Lip + 0.5, CFG.Walk, 0.5 do
		local y = surfY(d)
		if y > landY - 0.15 then
			if landY < lipY - 1 then break end -- already dropped and now flat / rising: this is the pool
		else
			landD, landY = d, y
		end
	end
	if lipY - landY < 1.5 then continue end
	local lip = base + out * CFG.Lip + Vector3.new(0, lipY - s.top + CFG.Lift, 0)

	local holder = Instance.new("Part")
	holder.Name = "Fall_" .. s.name
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(lip)
	holder:SetAttribute("Why", "흐르는 폭포 물줄기·물보라(규칙 3, A23-120)")
	holder.Parent = folder
	local foot = base + out * landD + Vector3.new(0, landY - s.top + CFG.Lift, 0)
	-- the strip lies on the sloped water. A non-FaceCamera beam spreads its width along the attachments' Y axis (beam bench
	-- 10/11: X = side / Y = up stood up like a fin, X = run / Y = side lay flat), so X = down the fall, Y = across it
	local down = (foot - lip).Unit
	local a0 = Instance.new("Attachment")
	a0.Name = "Top"
	a0.Parent = holder -- parent first: a World* set on a loose attachment becomes its local offset (10/11: beams drew at 2x)
	a0.WorldCFrame = CFrame.fromMatrix(lip, down, side)
	local a1 = Instance.new("Attachment")
	a1.Name = "Bottom"
	a1.Parent = holder
	a1.WorldCFrame = CFrame.fromMatrix(foot, down, side)
	if STREAK ~= "" then
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Texture = STREAK
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = CFG.Length
		b.TextureSpeed = CFG.Speed
		b.Width0, b.Width1 = CFG.Half * 2 + CFG.Width, CFG.Half * 2 + CFG.Width + 1
		b.FaceCamera = false
		b.LightEmission = 0.6
		b.LightInfluence = 0.8
		b.Color = ColorSequence.new(CFG.WaterColor)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 0.35) })
		b.Segments = 6
		b.Parent = holder
	end
	-- mist at the foot (round soft puffs)
	local mist = Instance.new("Attachment")
	mist.Name = "Mist"
	mist.Parent = holder
	mist.WorldPosition = foot + Vector3.new(0, 0.6, 0)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = PUFF
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
	-- foam puffs where it lands: round particles lying flat on the water (Orientation VelocityPerpendicular + upward
	-- velocity = the sprite faces up), white, fading out; no hard disc
	local fa = Instance.new("Attachment")
	fa.Name = "Foam"
	fa.Parent = holder
	fa.WorldPosition = Vector3.new(foot.X, landY + 0.15, foot.Z)
	local fe = Instance.new("ParticleEmitter")
	fe.Texture = PUFF
	fe.Rate = CFG.Foam.Rate
	fe.Lifetime = NumberRange.new(0.8, 1.4)
	fe.Speed = NumberRange.new(0.01, 0.02)
	fe.EmissionDirection = Enum.NormalId.Top
	fe.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	fe.SpreadAngle = Vector2.new(0, 0)
	fe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, CFG.Foam.Size * 0.6), NumberSequenceKeypoint.new(1, CFG.Foam.Size * 1.2) })
	fe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	fe.Color = ColorSequence.new(Color3.fromRGB(250, 253, 255))
	fe.LightEmission = 0.3
	fe.Rotation = NumberRange.new(0, 360)
	fe.Parent = fa
	made += 1
end
return string.format("halo_waterfx applied: %d of %d sheets (beam %s)", made, #sheets, STREAK ~= "" and "on" or "OFF - no streak texture yet")
