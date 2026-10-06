-- 유령 숲(A23-45) 분위기 미리보기 — WorldKit 전용. 하늘 무대(0,300,2000)에 작은 숲을 놓고,
-- LOOK = "on"이면 ZoneLook 제안값(HauntedHollow)을 Lighting에 잠깐 입힌다(원래 값은 속성에 저장, "off"로 되돌림).
-- KitStage에 GF_* (art/models/worldkit/manifest.json ghost_forest)와 유령 대역(G_GhostMinion_C, G_GhostKing_A_tex)이 있어야 한다.
local LOOK = "__LOOK__"
local L = game:GetService("Lighting")
local kit = game:GetService("ServerStorage").KitStage

-- ZoneLook 제안: 달빛 푸른 보라, 안개 없음, 몬스터가 보이게 노출 +0.15
local P = { Amb = { 0.92, 0.95, 1.3 }, Bright = 0.7, Exp = 0.15, Tint = Color3.fromRGB(214, 206, 255), Sat = 0.05, Con = 0.08 }

local function saveOnce(name, v)
	if L:GetAttribute("GF_" .. name) == nil then L:SetAttribute("GF_" .. name, v) end
	return L:GetAttribute("GF_" .. name)
end
local cc = L:FindFirstChild("GF_PreviewCC")
if LOOK == "off" then
	for _, n in ipairs({ "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "ClockTime" }) do
		local v = L:GetAttribute("GF_" .. n)
		if v ~= nil then L[n] = v; L:SetAttribute("GF_" .. n, nil) end
	end
	if cc then cc:Destroy() end
	local f = workspace:FindFirstChild("GhostForestPreview")
	if f then f:Destroy() end
	return "off"
end

local b0 = saveOnce("Brightness", L.Brightness)
local a0 = saveOnce("Ambient", L.Ambient)
local o0 = saveOnce("OutdoorAmbient", L.OutdoorAmbient)
local e0 = saveOnce("ExposureCompensation", L.ExposureCompensation)
saveOnce("ClockTime", L.ClockTime)
local function mul(c, f) return Color3.new(math.min(1, c.R * f[1]), math.min(1, c.G * f[2]), math.min(1, c.B * f[3])) end
L.Brightness = b0 * P.Bright
L.Ambient = mul(a0, P.Amb)
L.OutdoorAmbient = mul(o0, P.Amb)
L.ExposureCompensation = e0 + P.Exp
-- 시간(ClockTime)은 서버 하늘 값 그대로 — ZoneLook은 시간을 바꾸지 않는다
if not cc then cc = Instance.new("ColorCorrectionEffect"); cc.Name = "GF_PreviewCC"; cc.Parent = L end
cc.TintColor = P.Tint; cc.Saturation = P.Sat; cc.Contrast = P.Con; cc.Brightness = 0

local old = workspace:FindFirstChild("GhostForestPreview")
if old then old:Destroy() end
local f = Instance.new("Folder"); f.Name = "GhostForestPreview"; f.Parent = workspace
local BASE = Vector3.new(0, 300, 2000)
local floor = Instance.new("Part")
floor.Anchored = true; floor.Size = Vector3.new(120, 1, 90); floor.CFrame = CFrame.new(BASE + Vector3.new(0, -0.5, 0))
floor.Material = Enum.Material.SmoothPlastic; floor.Color = Color3.fromRGB(118, 106, 150); floor.Parent = f
local path = Instance.new("Part")
path.Anchored = true; path.Size = Vector3.new(10, 0.2, 90); path.CFrame = CFrame.new(BASE + Vector3.new(0, 0.1, 0))
path.Material = Enum.Material.Ground; path.Color = Color3.fromRGB(120, 100, 110); path.Parent = f

local function put(name, x, z, yaw, h)
	local src = kit:FindFirstChild(name)
	if not src then return end
	local m = src:Clone(); m.Parent = f
	local _, s = m:GetBoundingBox()
	m:ScaleTo(m:GetScale() * (h / s.Y))
	m:PivotTo(CFrame.new(m:GetPivot().Position) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	local cf, sz = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + (BASE + Vector3.new(x, sz.Y / 2, z) - cf.Position))
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true end end
	return m
end
put("GF_Arch", 0, -38, 0, 16)
for i, p in ipairs({ { -22, -20 }, { 24, -14 }, { -30, 12 }, { 28, 22 }, { -14, 32 } }) do put("GF_Tree", p[1], p[2], i * 70, 15 + (i % 2) * 3) end
for i, p in ipairs({ { 40, -30 }, { -42, -34 }, { 44, 6 } }) do put("GF_Willow", p[1], p[2], i * 50, 14) end
for i, p in ipairs({ { -7, -24 }, { 7, -8 }, { -7, 8 }, { 7, 24 } }) do
	local m = put("GF_Lantern", p[1], p[2], p[1] > 0 and 180 or 0, 9)
	if m and i <= 2 then
		local glass = m:FindFirstChildWhichIsA("BasePart", true)
		local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(150, 200, 255); light.Range = 16; light.Brightness = 1.4; light.Parent = glass
	end
end
for i, p in ipairs({ { -16, -4 }, { 15, 10 }, { -24, 28 }, { 20, -26 }, { 34, 30 } }) do put("GF_Mushrooms", p[1], p[2], i * 40, 2.5) end
for i, p in ipairs({ { -36, -6 }, { 36, -20 }, { 12, 36 } }) do put("GF_Rock", p[1], p[2], i * 90, 2.5) end
-- 유령 가족 대역(무료 생성본 — 실제 몬스터는 Tripo GLB를 게임성 개발 1이 가져옴)
local g1 = put("G_GhostMinion_C", -4, -2, 180, 3); if g1 then g1:PivotTo(g1:GetPivot() + Vector3.new(0, 1.5, 0)) end
local g2 = put("G_GhostMinion_C", 3, 2, 160, 3); if g2 then g2:PivotTo(g2:GetPivot() + Vector3.new(0, 2.2, 0)) end
local g3 = put("G_GhostKing_A_tex", 0, 14, 180, 8); if g3 then g3:PivotTo(g3:GetPivot() + Vector3.new(0, 0.8, 0)) end
return "ghost forest preview on"
