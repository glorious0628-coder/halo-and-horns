-- halo_blockout_shots.luau (이미지 생성 1, 2026-10-11): after halo_blockout apply, adds avatar-size blocks at doors + the beam bench (x -3000) and returns the shot list JSON. Run by tools/worldkit/halo_blockout_shots.py.
if string.find(game.Name, "GoodEvil") or game.PlaceId == 81671223175574 then error("main Studio") end
local T = workspace.Terrain
local root = workspace:FindFirstChild("HaloV2")
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { T }
rp.IgnoreWater = true
local function gy(x, z)
	local h = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), rp)
	return h and h.Position.Y or 0
end
local function part(parent, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.Size, p.CFrame, p.Color = name, true, size, cf, color
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end
-- avatar-size references (2 x 5 x 1, like the markers) at doors
local av = root:FindFirstChild("AvatarRefs")
if av then av:Destroy() end
av = Instance.new("Folder")
av.Name = "AvatarRefs"
av.Parent = root
local shots = {}
local function shot(name, cx, cz, ch, lx, lz, lh)
	table.insert(shots, { name = name, cam = { cx, gy(cx, cz) + ch, cz }, look = { lx, gy(lx, lz) + lh, lz } })
end
local function absShot(name, c, l) table.insert(shots, { name = name, cam = c, look = l }) end
for _, id in { "Shop_Potion", "House_Cliff1", "House_Garden1", "Castle", "Armory" } do
	local m = root.Buildings:FindFirstChild(id)
	local hole = m and m:FindFirstChild("DoorHole")
	if hole then
		local out = -hole.CFrame.LookVector -- door hole sits outside the front wall; compute outward from model center
		local c = m.WallBack.Position
		local dir = (Vector3.new(hole.Position.X, 0, hole.Position.Z) - Vector3.new(c.X, 0, c.Z)).Unit
		local base = Vector3.new(hole.Position.X, gy(hole.Position.X, hole.Position.Z), hole.Position.Z) + dir * 3 + hole.CFrame.RightVector * (hole.Size.X / 2 + 1.5)
		local b = part(av, "Avatar_" .. id, Vector3.new(2, 5, 1), CFrame.new(base + Vector3.new(0, 2.5, 0)), Color3.fromRGB(255, 200, 40))
		b.Material = Enum.Material.Neon
		local cam = hole.Position + dir * 18
		table.insert(shots, { name = "avatar_" .. id, cam = { cam.X, gy(cam.X, cam.Z) + 5, cam.Z }, look = { hole.Position.X, gy(hole.Position.X, hole.Position.Z) + 5, hole.Position.Z } })
	end
end
-- gate avatar
local g = part(av, "Avatar_Gate", Vector3.new(2, 5, 1), CFrame.new(4, gy(4, -334) + 2.5, -334), Color3.fromRGB(255, 200, 40))
g.Material = Enum.Material.Neon

-- the town shots come from the plan (tools/worldkit/halo_blockout_shots.py fills __SHOTS__): a point is { x, z, h } with
-- h above the ground there, or { x, y, z, abs = true }
local SPEC = game:GetService("HttpService"):JSONDecode([==[__SHOTS__]==])
local function pt(q)
	if q.abs then return { q.x, q.y, q.z } end
	return { q.x, gy(q.x, q.z) + q.h, q.z }
end
local towerSpecs = {}
for _, sp in SPEC do
	if sp.tower then
		table.insert(towerSpecs, sp)
	else
		table.insert(shots, { name = sp.name, cam = pt(sp.cam), look = pt(sp.look) })
	end
end
-- the lookout tower top (검수 10/11: at the parapet edge, tilted 15-20 deg down): eye = roof + 4.5, 5 studs out toward the view
do
	local tw = root.Buildings.Tower_Lookout.Roof
	local top = tw.Position + Vector3.new(0, tw.Size.Y / 2 + 4.5, 0)
	local function towerShot(name, aimX, aimZ, tilt)
		local h = (Vector3.new(aimX, top.Y, aimZ) - top).Unit
		local cam = top + h * 5
		local dir = (h * math.cos(math.rad(tilt)) - Vector3.new(0, math.sin(math.rad(tilt)), 0))
		absShot(name, { cam.X, cam.Y, cam.Z }, { cam.X + dir.X * 100, cam.Y + dir.Y * 100, cam.Z + dir.Z * 100 })
	end
	for _, sp in towerSpecs do
		towerShot(sp.name, sp.aim[1], sp.aim[2], sp.tilt)
	end
end
-- 15-17 (from above) are in SPEC

-- beam test bench (far from everything: x -3000)
local tb = workspace:FindFirstChild("BeamTest")
if tb then tb:Destroy() end
tb = Instance.new("Folder")
tb.Name = "BeamTest"
tb.Parent = workspace
local O = Vector3.new(-3000, 50, 0)
local floor = part(tb, "Floor", Vector3.new(60, 1, 40), CFrame.new(O), Color3.fromRGB(60, 90, 140))
local dec = Instance.new("Decal")
dec.Texture = "rbxassetid://111806947888357"
dec.Face = Enum.NormalId.Top
dec.Parent = part(tb, "DecalCheck", Vector3.new(10, 1, 10), CFrame.new(O + Vector3.new(-22, 0.2, -12)), Color3.fromRGB(30, 50, 90))
local function beamPair(name, x, mkcf, tex)
	local h = part(tb, name, Vector3.new(1, 1, 1), CFrame.new(O + Vector3.new(x, 2, 0)), Color3.new(1, 0, 0))
	h.Transparency = 1
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	local p0, p1 = O + Vector3.new(x, 1, -12), O + Vector3.new(x, 1, 12)
	a0.Parent, a1.Parent = h, h
	a0.WorldCFrame, a1.WorldCFrame = mkcf(p0), mkcf(p1)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Width0, b.Width1 = 8, 8
	b.FaceCamera = false
	b.LightEmission = 0.6
	b.Texture = tex
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 7
	b.TextureSpeed = 1.4
	b.Segments = 6
	b.Parent = h
end
local side, up = Vector3.new(1, 0, 0), Vector3.new(0, 1, 0)
-- A: like halo_waterfx now (X = side, Y = normal)
beamPair("A_Xside_Ynormal", -8, function(p) return CFrame.fromMatrix(p, side, up) end, "rbxassetid://111806947888357")
-- B: X along the run, Y = side
beamPair("B_Xrun_Yside", 8, function(p) return CFrame.fromMatrix(p, Vector3.new(0, 0, 1), side) end, "rbxassetid://111806947888357")
-- C: plain (no texture), same as A
beamPair("C_plain_A", 22, function(p) return CFrame.fromMatrix(p, side, up) end, "")
-- particles check
local pa = Instance.new("Attachment")
pa.Parent = floor
pa.WorldPosition = O + Vector3.new(-22, 2, 10)
local pe = Instance.new("ParticleEmitter")
pe.Rate, pe.Lifetime, pe.Speed = 40, NumberRange.new(2, 3), NumberRange.new(3)
pe.Size = NumberSequence.new(2)
pe.Color = ColorSequence.new(Color3.new(1, 1, 1))
pe.Parent = pa
-- beam bench shots: py tools/worldkit/halo_blockout_shots.py --bench
return game:GetService("HttpService"):JSONEncode(shots)
