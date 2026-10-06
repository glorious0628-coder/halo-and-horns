-- 빛 마을 영웅상(A23-41 무료 먼저): 기본 블록 아바타 몸(머리·몸통·팔·다리 블록)을 파트로 세우고 포즈를 준 흰 대리석 석상.
-- WorldKit 전용. 결과: ServerStorage.KitStage.H_HeroStatue_<POSE> (Model, 모든 파트 Anchored·CanCollide false, 스크립트 없음)
-- POSE: "sword" = 칼을 하늘로 + 방패 / "shield" = 방패 앞으로 + 칼 아래
-- (CreateHumanoidModelFromDescription 몸은 Edit에서 메시가 안 보여서 파트로 만든다)
local POSE = "__POSE__"
local kit = game:GetService("ServerStorage").KitStage
local STONE = Color3.fromRGB(234, 232, 226)
local GOLD = Color3.fromRGB(212, 175, 55)

local m = Instance.new("Model")
m.Name = "H_HeroStatue_" .. POSE
local function part(name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Anchored = true; p.CanCollide = false
	p.Color = color or STONE; p.Material = mat or Enum.Material.Marble
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = m
	return p
end
-- 기본 블록 몸(R6 비율): 다리 1x2x1, 몸통 2x2x1, 팔 1x2x1, 머리 1.2 각진 큐브(둥근 모서리 대신 살짝 작게)
local base = CFrame.new(0, 0, 0)
local hipY = 2
-- 다리: 엉덩이 축에서 회전
local function limb(name, pivot, angles, offsetDown)
	local cf = pivot * angles * CFrame.new(0, -offsetDown, 0)
	return part(name, Vector3.new(1, 2, 1), cf)
end
local legL, legR, armL, armR
local A = math.rad
if POSE == "sword" then
	legL = limb("LeftLeg", base * CFrame.new(-0.5, hipY, 0), CFrame.Angles(A(-12), 0, A(-4)), 1)
	legR = limb("RightLeg", base * CFrame.new(0.5, hipY, 0), CFrame.Angles(A(10), 0, A(4)), 1)
else
	legL = limb("LeftLeg", base * CFrame.new(-0.5, hipY, 0), CFrame.Angles(A(-18), 0, 0), 1)
	legR = limb("RightLeg", base * CFrame.new(0.5, hipY, 0), CFrame.Angles(A(14), 0, A(5)), 1)
end
local torso = part("Torso", Vector3.new(2, 2, 1), base * CFrame.new(0, hipY + 1, 0))
local head = part("Head", Vector3.new(1.25, 1.25, 1.25), base * CFrame.new(0, hipY + 2 + 0.65, 0))
local shoulderY = hipY + 2 - 0.5
local rArm, lArm
if POSE == "sword" then
	-- 오른팔: 하늘로(칼끝 위), 왼팔: 앞으로 굽혀 방패
	rArm = limb("RightArm", base * CFrame.new(1.5, shoulderY, 0), CFrame.Angles(A(170), 0, A(-8)), 0.5)
	lArm = limb("LeftArm", base * CFrame.new(-1.5, shoulderY, 0), CFrame.Angles(A(-70), A(-20), A(10)), 0.5)
else
	rArm = limb("RightArm", base * CFrame.new(1.5, shoulderY, 0), CFrame.Angles(A(-20), 0, A(-10)), 0.5)
	lArm = limb("LeftArm", base * CFrame.new(-1.5, shoulderY, 0), CFrame.Angles(A(-85), 0, A(0)), 0.5)
end
-- 손 끝(팔 아래쪽 끝) 위치
local rHand = rArm.CFrame * CFrame.new(0, -1, 0)
local lHand = lArm.CFrame * CFrame.new(0, -1, 0)
-- 칼: 손에서 팔 방향으로 뻗음
local swordDir = rArm.CFrame
part("SwordGrip", Vector3.new(0.35, 0.9, 0.35), rHand * CFrame.new(0, -0.3, 0))
part("SwordGuard", Vector3.new(0.35, 0.3, 1.6), rHand * CFrame.new(0, -0.8, 0), GOLD, Enum.Material.SmoothPlastic)
part("SwordBlade", Vector3.new(0.25, 3.6, 0.7), rHand * CFrame.new(0, -2.75, 0))
-- 방패: 팔 바깥쪽(앞)에 둥근 판
local sh = part("Shield", Vector3.new(0.4, 2.6, 2.6), lHand * CFrame.new(0, 0.3, -0.6) * CFrame.Angles(0, 0, 0), STONE, Enum.Material.Marble, Enum.PartType.Cylinder)
sh.CFrame = lArm.CFrame * CFrame.new(0, -0.4, -0.75) * CFrame.Angles(0, A(90), 0)
part("ShieldRim", Vector3.new(0.3, 2.9, 2.9), sh.CFrame * CFrame.new(0.06, 0, 0), GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
part("ShieldBoss", Vector3.new(0.8, 0.8, 0.8), sh.CFrame * CFrame.new(-0.25, 0, 0), GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
-- 망토(등 뒤 판), 띠
part("Cape", Vector3.new(1.9, 2.6, 0.2), torso.CFrame * CFrame.new(0, -0.5, 0.6) * CFrame.Angles(A(-8), 0, 0))
part("Belt", Vector3.new(2.05, 0.3, 1.05), torso.CFrame * CFrame.new(0, -0.8, 0), GOLD, Enum.Material.SmoothPlastic)
-- 금 후광
local halo = kit:FindFirstChild("H_HaloRing")
if halo then
	local h = halo:Clone(); h.Parent = m
	local _, s = h:GetBoundingBox(); h:ScaleTo(h:GetScale() * (1.8 / math.max(s.X, s.Z)))
	h:PivotTo(CFrame.new(head.Position + Vector3.new(0, 1.15, 0)))
	for _, d in ipairs(h:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end end
end
-- 받침
local ped = kit:FindFirstChild("H_StatuePedestal")
if ped then
	local p = ped:Clone(); p.Parent = m
	local _, s = p:GetBoundingBox(); p:ScaleTo(p:GetScale() * (3.2 / s.X))
	local cf, sz = p:GetBoundingBox()
	p:PivotTo(p:GetPivot() + (Vector3.new(0, -sz.Y / 2, 0) - cf.Position))
	for _, d in ipairs(p:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
else
	part("Pedestal", Vector3.new(3.2, 1, 3.2), CFrame.new(0, -0.5, 0), STONE, Enum.Material.Marble)
	part("PedestalTrim", Vector3.new(3.4, 0.25, 3.4), CFrame.new(0, -0.05, 0), GOLD, Enum.Material.SmoothPlastic)
end
m.PrimaryPart = torso
local old = kit:FindFirstChild(m.Name); if old then old:Destroy() end
m.Parent = kit
local _, size = m:GetBoundingBox()
return string.format("%s size=%.1fx%.1fx%.1f", m.Name, size.X, size.Y, size.Z)
