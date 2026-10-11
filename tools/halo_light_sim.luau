-- 이미지 개발 2026-10-11: main-game light for the Halo town in WorldKit (Config.Sky.Neutral / DayCycle Night x ZoneLook
-- HaloTown factors x a candidate), with WarTint + ZoneTint colour corrections and the main bloom. Saves WorldKit's own
-- values once (attribute ImgDevSimSaved); halo_light_restore.luau puts them back.
if game.PlaceId == 81671223175574 or string.find(game.Name, "GoodEvil") then error("WRONG STUDIO: main") end
local CAND, PHASE = "%s", "%s"
local L = game:GetService("Lighting")
local Http = game:GetService("HttpService")
local KEYS = { "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "ClockTime", "EnvironmentSpecularScale",
	"EnvironmentDiffuseScale", "GlobalShadows", "ShadowSoftness", "GeographicLatitude" }
if L:GetAttribute("ImgDevSimSaved") == nil then
	local saved = { props = {}, fx = {} }
	for _, k in KEYS do
		local v = L[k]
		saved.props[k] = typeof(v) == "Color3" and { v.R, v.G, v.B } or v
	end
	for _, e in L:GetChildren() do
		if e:IsA("PostEffect") then saved.fx[e.Name] = e.Enabled end
	end
	L:SetAttribute("ImgDevSimSaved", Http:JSONEncode(saved))
end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
-- candidates = ZoneLook HaloTown factors (C0 = today's Config); Diff = a would-be new optional key (ZoneLook never
-- touches diffuse today)
local C = {
	C0 = { Amb = { 1.06, 1.04, 0.95 }, Bright = 0.88, Exp = -0.12, Tint = rgb(255, 246, 228), Sat = 0.06, Con = 0.05, CC = 0 },
	C1 = { Amb = { 1.35, 1.25, 1.0 }, Bright = 0.95, Exp = 0.05, Tint = rgb(255, 244, 226), Sat = 0.06, Con = 0.05, CC = 0 },
	C2 = { Amb = { 1.5, 1.38, 1.05 }, Bright = 1.0, Exp = 0.15, Spec = 0.8, Tint = rgb(255, 242, 222), Sat = 0.08, Con = 0.04,
		CC = 0.02 },
	C3 = { Amb = { 1.3, 1.22, 1.0 }, Bright = 0.95, Exp = 0.1, Diff = 0.8, Tint = rgb(255, 244, 226), Sat = 0.06, Con = 0.05,
		CC = 0 },
}
local z = C[CAND]
assert(z, "no candidate " .. CAND)
local base
if PHASE == "night" then
	base = { ClockTime = 21, Brightness = 1.4, Ambient = rgb(70, 78, 106), OutdoorAmbient = rgb(98, 110, 148), Exp = 0.35 }
else
	base = { ClockTime = 15.3, Brightness = 2, Ambient = rgb(72, 76, 86), OutdoorAmbient = rgb(95, 104, 118), Exp = -0.25 }
end
local function sc(c, f) return Color3.new(math.min(1, c.R * f[1]), math.min(1, c.G * f[2]), math.min(1, c.B * f[3])) end
local bright = z.Bright
if PHASE == "night" then bright = math.max(z.Bright, 0.95) end -- ZoneLook T.NightBright at NightLevel 1
L.ClockTime = base.ClockTime
L.GeographicLatitude = 35
L.Brightness = base.Brightness * bright
L.Ambient = sc(base.Ambient, z.Amb)
L.OutdoorAmbient = sc(base.OutdoorAmbient, z.Amb)
L.ExposureCompensation = base.Exp + z.Exp
L.EnvironmentSpecularScale = z.Spec or 0.6
L.EnvironmentDiffuseScale = z.Diff or 0.5
L.GlobalShadows, L.ShadowSoftness = true, 0.15
for _, e in L:GetChildren() do
	if e:IsA("PostEffect") and not string.find(e.Name, "^ImgDev") then e.Enabled = false end
end
local function cc(name)
	local e = L:FindFirstChild(name) or Instance.new("ColorCorrectionEffect")
	e.Name = name
	e.Parent = L
	e.Enabled = true
	return e
end
local war = cc("ImgDevWarTint")
war.TintColor, war.Contrast, war.Saturation, war.Brightness = rgb(255, 245, 230), 0.12, -0.05, 0
local zt = cc("ImgDevZoneTint")
zt.TintColor, zt.Saturation, zt.Contrast, zt.Brightness = z.Tint, z.Sat, z.Con, z.CC
local bloom = L:FindFirstChild("ImgDevBloom") or Instance.new("BloomEffect")
bloom.Name, bloom.Size, bloom.Threshold, bloom.Intensity, bloom.Enabled = "ImgDevBloom", 24, 2.2, 0.2, true
bloom.Parent = L
return string.format("%s %s: B %.2f Amb %s Out %s Exp %.2f Spec %.2f Diff %.2f sun %s", CAND, PHASE, L.Brightness,
	tostring(L.Ambient), tostring(L.OutdoorAmbient), L.ExposureCompensation, L.EnvironmentSpecularScale,
	L.EnvironmentDiffuseScale, tostring(L:GetSunDirection()))
