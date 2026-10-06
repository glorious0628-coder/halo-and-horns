"""
배경·몬스터 융화 시안 캡처(검수 2026-10-06 '배경이랑 몹들이 융화가 안 돼요'): 연습 Studio(UiSandbox) Play 중에만 조명·땅 재질 속성을
바꿔 세 자리(말랑 초원 슬라임 무리, 고블린 숲, 해골 폐허)를 같은 카메라로 A(지금) / B(밝은 장난감 세상) / C(B + 땅 타일 키움·색) /
D(C + 잔디 무늬 빼고 색만) / E(B + 이미지 생성의 새 땅 타일 4장) 찍고, 밤(Eclipse) 지금 / 제안을 한 자리에서 찍는다. 코드·장소 파일은 바꾸지 않는다(Play를 멈추면 원래대로 돌아간다). HUD 화면은 숨긴다.

  py tools/world_blend_view.py [--out build/world_blend]
결과: <out>/<spot>_<A|B|C|D|E>.jpeg, <out>/night_<A|new>.jpeg, <out>/values.json(설정값·원래 값·카메라)
STUDIO_NAME 기본값 UiSandbox(메인 게임 장소 81671223175574에서는 아무것도 안 바꾼다). 끝나면 Play를 멈추고 기기 흉내를 끈다.
"""

import base64
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("STUDIO_NAME", "UiSandbox")
from studio_mcp import Client  # noqa: E402
import device_view as dv  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPOTS = ["SlimeMeadow", "GoblinWoods", "SkeletonRuins"]

# Each setup = Lighting props, effect props, MaterialVariant StudsPerTile, terrain colours ({r,g,b} 0-255).
# A = whatever the server applied (recorded at start); B / C / night values are the proposal under test.
SETUPS = {
    "B": {
        # tuned 2026-10-06 at the meadow (B1 2.4 / exposure 0 burnt white roads; B2 kept)
        "Lighting": {"Brightness": 2.0, "ClockTime": 14.2, "Ambient": [110, 108, 106], "OutdoorAmbient": [128, 126, 124],
                     "EnvironmentDiffuseScale": 1.0, "EnvironmentSpecularScale": 0.6, "ShadowSoftness": 0.5,
                     "ExposureCompensation": -0.2, "FogColor": [205, 215, 230], "FogStart": 250, "FogEnd": 1100},
        "Bloom": {"Intensity": 0.2, "Size": 24, "Threshold": 2.2},
        "SunRays": {"Intensity": 0.04},
        "WarTint": {"Brightness": 0.0, "Contrast": 0.05, "Saturation": 0.1, "TintColor": [255, 255, 255]},
    },
    "night_new": {
        "Lighting": {"Brightness": 1.2, "ClockTime": 0.5, "Ambient": [95, 55, 70], "OutdoorAmbient": [110, 70, 85],
                     "EnvironmentDiffuseScale": 1.0, "EnvironmentSpecularScale": 0.6, "ShadowSoftness": 0.5,
                     "ExposureCompensation": 0.35, "FogColor": [90, 10, 20], "FogStart": 120, "FogEnd": 650},
        "Bloom": {"Intensity": 0.5, "Size": 24, "Threshold": 1.6},
        "SunRays": {"Intensity": 0.0},
        "WarTint": {"Brightness": 0.0, "Contrast": 0.05, "Saturation": 0.1, "TintColor": [255, 200, 200]},
    },
    "night_A": {  # today's Eclipse (Config.Sky.Eclipse + WarService fixed values)
        "Lighting": {"Brightness": 0.78, "ClockTime": 0.5, "Ambient": [75, 5, 5], "OutdoorAmbient": [85, 5, 5],
                     "FogColor": [90, 10, 20], "FogStart": 120, "FogEnd": 650, "ExposureCompensation": 0.35},
        "Bloom": {"Intensity": 0.7},
        "SunRays": {"Intensity": 0.0},
        "WarTint": {"TintColor": [255, 185, 185]},
    },
}
# C = B + bigger ground tiles (less busy pattern) + ground colours nudged toward the toy palette (no new art)
GROUND = {
    "Variants": {"GE_Grass": 28, "GE_LeafyGrass": 28, "GE_DirtPath": 28, "GE_Cobblestone": 24, "GE_Slate": 28},
    "TerrainColors": {"Grass": [112, 168, 82], "LeafyGrass": [92, 140, 70], "Slate": [104, 138, 124],
                      "Cobblestone": [178, 168, 148]},
}
# D = C + grass / leafy grass drawn as flat colour (a fresh map-less MaterialVariant override; no new art)
FLAT = dict(GROUND, Flat={"Grass": "WB_FlatGrass", "LeafyGrass": "WB_FlatLeafyGrass"},
            TerrainColors=dict(GROUND["TerrainColors"], Grass=[106, 148, 86], LeafyGrass=[88, 122, 72]))
# E = B + the four new Firefly tiles (art/ui/Tex_*_FF.png, uploaded 2026-10-06 as sandbox-test ids, asset_ids.json)
NEW_TILES = {
    "Fresh": {
        "WB_E_Grass": {"Base": "Grass", "ColorMap": "rbxassetid://104463174886181", "StudsPerTile": 16, "Override": True},
        "WB_E_LeafyGrass": {"Base": "LeafyGrass", "ColorMap": "rbxassetid://92129043469297", "StudsPerTile": 16,
                            "Override": True},
        "WB_E_Cobblestone": {"Base": "Cobblestone", "ColorMap": "rbxassetid://72599078474763", "StudsPerTile": 14,
                             "Override": True},
        "WB_E_DirtPath": {"Base": "Ground", "ColorMap": "rbxassetid://85612652410118", "StudsPerTile": 16, "Roads": True},
    },
    # the painted tiles carry their own colour: neutral terrain tint so they are not darkened twice
    "TerrainColors": {"Grass": [235, 235, 235], "LeafyGrass": [235, 235, 235], "Cobblestone": [235, 235, 235]},
}
SETUPS["C"] = dict(SETUPS["B"], Ground=GROUND)
SETUPS["E"] = dict(SETUPS["B"], Ground=NEW_TILES)
SETUPS["night_new"]["Ground"] = NEW_TILES
SETUPS["D"] = dict(SETUPS["B"], Ground=FLAT)
SETUPS["night_new"]["Ground"] = FLAT  # replaced by NEW_TILES below

LUA_HELPERS = r'''
assert(game.PlaceId ~= 81671223175574, "never the main game place") -- Play datamodels are named "Game": the window pick is by STUDIO_NAME
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local MS = game:GetService("MaterialService")
local function c3(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local function rgb(c) return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } end
local function set(obj, props)
    if not obj or not props then return end
    for k, v in props do
        pcall(function() obj[k] = (type(v) == "table") and c3(v) or v end)
    end
end
local function apply(s)
    set(Lighting, s.Lighting)
    set(Lighting:FindFirstChildOfClass("BloomEffect"), s.Bloom)
    set(Lighting:FindFirstChildOfClass("SunRaysEffect"), s.SunRays)
    set(Lighting:FindFirstChild("WarTint"), s.WarTint)
    local g = s.Ground
    if g then
        for base, name in g.Flat or {} do
            local v = MS:FindFirstChild(name)
            if not v then
                v = Instance.new("MaterialVariant")
                v.Name, v.BaseMaterial, v.StudsPerTile = name, Enum.Material[base], 20
                v.Parent = MS
            end
        end
        for name, f in g.Fresh or {} do -- a fresh map-only variant (never a clone: clones keep the old TexturePack)
            local v = MS:FindFirstChild(name)
            if not v then
                v = Instance.new("MaterialVariant")
                v.Name, v.BaseMaterial = name, Enum.Material[f.Base]
                pcall(function() v.ColorMap = f.ColorMap end)
                v.Parent = MS
            end
            v.StudsPerTile = f.StudsPerTile or 16
            if f.Override then pcall(function() MS:SetBaseMaterialOverride(Enum.Material[f.Base], name) end) end
        end
        for base, name in g.Overrides or {} do
            pcall(function() MS:SetBaseMaterialOverride(Enum.Material[base], name) end)
        end
        local roads = g.RoadVariant
        for name, f in g.Fresh or {} do if f.Roads then roads = name end end
        local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
        local folder = decor and decor:FindFirstChild("Roads")
        if roads and folder then
            for _, part in folder:GetDescendants() do
                if part:IsA("BasePart") then part.MaterialVariant = roads end
            end
        end
        for base, name in g.Flat or {} do
            pcall(function() MS:SetBaseMaterialOverride(Enum.Material[base], name) end)
        end
        for name, spt in g.Variants or {} do
            local v = MS:FindFirstChild(name)
            if v then pcall(function() v.StudsPerTile = spt end) end
        end
        for mat, col in g.TerrainColors or {} do
            pcall(function() workspace.Terrain:SetMaterialColor(Enum.Material[mat], c3(col)) end)
        end
    end
end
'''

RECORD = LUA_HELPERS + r'''
local s = { Lighting = {}, Bloom = {}, SunRays = {}, WarTint = {}, Ground = { Variants = {}, TerrainColors = {}, Overrides = {} } }
for _, k in { "Brightness", "ClockTime", "Ambient", "OutdoorAmbient", "EnvironmentDiffuseScale", "EnvironmentSpecularScale",
    "ShadowSoftness", "ExposureCompensation", "FogColor", "FogStart", "FogEnd" } do
    local v = Lighting[k]
    s.Lighting[k] = typeof(v) == "Color3" and rgb(v) or v
end
local b = Lighting:FindFirstChildOfClass("BloomEffect")
if b then s.Bloom = { Intensity = b.Intensity, Size = b.Size, Threshold = b.Threshold } end
local r = Lighting:FindFirstChildOfClass("SunRaysEffect")
if r then s.SunRays = { Intensity = r.Intensity } end
local t = Lighting:FindFirstChild("WarTint")
if t then s.WarTint = { Brightness = t.Brightness, Contrast = t.Contrast, Saturation = t.Saturation, TintColor = rgb(t.TintColor) } end
for _, name in { "GE_Grass", "GE_LeafyGrass", "GE_DirtPath", "GE_Cobblestone", "GE_Slate" } do
    local v = MS:FindFirstChild(name)
    if v then s.Ground.Variants[name] = v.StudsPerTile end
end
for _, m in { "Grass", "LeafyGrass", "Slate", "Cobblestone" } do
    s.Ground.TerrainColors[m] = rgb(workspace.Terrain:GetMaterialColor(Enum.Material[m]))
end
for _, m in { "Grass", "LeafyGrass", "Cobblestone" } do
    s.Ground.Overrides[m] = MS:GetBaseMaterialOverride(Enum.Material[m])
end
local decor = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Decor")
local road = decor and decor:FindFirstChild("Roads") and decor.Roads:FindFirstChildWhichIsA("BasePart", true)
s.Ground.RoadVariant = road and road.MaterialVariant or "GE_DirtPath"
return HttpService:JSONEncode(s)
'''

APPLY = LUA_HELPERS + r'''
apply(HttpService:JSONDecode(%s))
return "applied"
'''

# server: park the player in town (safe, out of every shot) with a huge HP pool; pick each zone's densest monster group
SETUP_SERVER = r'''
local p = game.Players:GetPlayers()[1]
local char = p and p.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local hrp = char and char:FindFirstChild("HumanoidRootPart")
if hum then hum.MaxHealth = 1e7; hum.Health = 1e7 end
if hrp then hrp.CFrame = CFrame.new(0, 8, -25) end
return "parked"
'''

FIND_GROUP = r'''
local Config = require(game.ReplicatedStorage.Shared.Config)
local zone = "%s"
local list = {}
local folder = workspace:FindFirstChild("Monsters")
for _, m in folder and folder:GetChildren() or {} do
    local r = m:IsA("Model") and m.PrimaryPart
    if r and not r.Anchored and Config.ZoneAt(r.Position).Id == zone then table.insert(list, r.Position) end
end
if #list == 0 then return "none" end
local best, bestN = list[1], 0
for _, a in list do
    local n = 0
    for _, b in list do if (a - b).Magnitude <= 22 then n += 1 end end
    if n > bestN then best, bestN = a, n end
end
local sum, n = Vector3.zero, 0
for _, b in list do if (best - b).Magnitude <= 22 then sum += b; n += 1 end end
local c = sum / n
return string.format("%%.2f,%%.2f,%%.2f,%%d,%%d", c.X, c.Y, c.Z, n, #list)
'''

# client: hide our screen GUIs, scriptable camera looking at the group from the sun side (3/4 light), same for A/B/C
CAMERA = r'''
local lp = game.Players.LocalPlayer
for _, g in lp.PlayerGui:GetChildren() do
    if g:IsA("ScreenGui") and g.Name ~= "TouchGui" then g.Enabled = false end
end
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 60
local target = Vector3.new(%f, %f, %f)
local sun = game:GetService("Lighting"):GetSunDirection()
local flat = Vector3.new(sun.X, 0, sun.Z)
if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, 1) end
flat = flat.Unit
-- about a gameplay camera (monsters readable, ground in view); the first angle whose view of the group is not blocked
-- by a wall / pillar (monsters and characters ignored)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local skip = { workspace:FindFirstChild("Monsters") }
for _, pl in game.Players:GetPlayers() do if pl.Character then table.insert(skip, pl.Character) end end
params.FilterDescendantsInstances = skip
local look = target + Vector3.new(0, 2.5, 0)
local eye = nil
for _, deg in { 35, -35, 75, -75, 115, -115, 160 } do
    local side = CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(flat)
    local e = target + side * 21 + Vector3.new(0, 8.5, 0)
    if not workspace:Raycast(e, look - e, params) then eye = e break end
    eye = eye or e
end
_G.WorldBlendCam = CFrame.lookAt(eye, look)
-- other camera code (PlayerModule / CameraFollow) may move the camera back: pin it every frame after them
local RunService = game:GetService("RunService")
pcall(function() RunService:UnbindFromRenderStep("WorldBlendCam") end)
RunService:BindToRenderStep("WorldBlendCam", Enum.RenderPriority.Last.Value, function()
    local c = workspace.CurrentCamera
    if c.CameraType ~= Enum.CameraType.Scriptable then c.CameraType = Enum.CameraType.Scriptable end
    c.CFrame = _G.WorldBlendCam
end)
cam.CFrame = _G.WorldBlendCam
return string.format("%%.1f,%%.1f,%%.1f", eye.X, eye.Y, eye.Z)
'''


def capture(c, path, cap_id):
    res = c.call("screen_capture", {"capture_id": cap_id})
    for part in res.get("content", []):
        if part.get("type") == "image":
            with open(path, "wb") as f:
                f.write(base64.b64decode(part["data"]))
            return True
    return False


def apply(c, setup):
    payload = json.dumps(json.dumps(setup))  # a Lua string literal holding the JSON
    for dm in ("Server", "Client"):
        dv.luau(c, APPLY % payload, dm)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    out = os.path.join(ROOT, "build", "world_blend")
    if "--out" in args:
        out = args[args.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    c = Client()
    record = {"spots": {}, "setups": SETUPS}
    try:
        c.start()
        dv.stop_play(c)
        print(dv.luau(c, dv.SET_DEVICE % dv.DEVICES["pc"], "Edit"))
        c.call("start_stop_play", {"is_start": True})
        for _ in range(60):
            time.sleep(0.5)
            if "Client" in dv.state(c):
                break
        time.sleep(6)
        print(dv.luau(c, dv.PICK % "Halo", "Server"))
        time.sleep(5)
        print(dv.luau(c, SETUP_SERVER, "Server"))
        record["A"] = json.loads(dv.luau(c, RECORD, "Server"))
        setups = dict(SETUPS, A=record["A"])
        # warm-up: freshly uploaded tiles render white until they load once
        apply(c, setups["E"])
        time.sleep(8)
        apply(c, setups["A"])
        time.sleep(3)
        for spot in SPOTS:
            group = dv.luau(c, FIND_GROUP % spot, "Server").strip()
            print(spot, "group:", group)
            if group == "none" or "," not in group:
                continue
            x, y, z, n, total = group.split(",")
            apply(c, setups["A"])
            time.sleep(1)
            eye = dv.luau(c, CAMERA % (float(x), float(y), float(z)), "Client")
            record["spots"][spot] = {"target": [float(x), float(y), float(z)], "eye": eye, "group": int(n),
                                     "zoneMonsters": int(total)}
            for name in ("A", "B", "C", "D", "E"):
                apply(c, setups[name])
                time.sleep(1.8)
                path = os.path.join(out, f"{spot}_{name}.jpeg")
                print(path, capture(c, path, f"blend_{spot}_{name}"))
        # night: the meadow group again under today's Eclipse and the proposal
        spot = record["spots"].get("SlimeMeadow")
        if spot:
            apply(c, setups["A"])
            dv.luau(c, CAMERA % tuple(spot["target"]), "Client")
            for name in ("night_A", "night_new"):
                apply(c, setups["A"])  # reset ground before each night setup
                apply(c, setups[name])
                time.sleep(1.8)
                path = os.path.join(out, f"{name}.jpeg")
                print(path, capture(c, path, f"blend_{name}"))
        with open(os.path.join(out, "values.json"), "w", encoding="utf-8") as f:
            json.dump(record, f, ensure_ascii=False, indent=1)
        dv.stop_play(c)
        print(dv.luau(c, dv.RESTORE, "Edit"))
    finally:
        c.close()


if __name__ == "__main__":
    main()
