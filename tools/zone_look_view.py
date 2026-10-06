"""
사냥터 분위기(ZoneLook, A23-30) 확인 캡처: 연습 Studio(UiSandbox) Play에서 캐릭터를 각 지역 안(카메라 뒤)에 세우고,
그 지역 몬스터 무리를 world_blend_view와 같은 카메라로 찍는다. 호박밭은 아직 지역이 없어 초원에서 ZoneLook.Preview로,
경계는 말랑 초원 → 고블린 숲으로 넘어가는 순간(바뀌는 중)과 다 바뀐 뒤를 찍고, 밤(Eclipse)은 초원·폐허를 찍는다.
코드·장소 파일은 바꾸지 않는다(Play 중 서버의 밤 하늘 값만 잠깐 바꾼다). HUD는 숨긴다.

  py tools/zone_look_view.py [--out build/zone_look]
결과: <out>/<이름>.jpeg, <out>/values.json. STUDIO_NAME은 UiSandbox로 고정(dv.ensure_sandbox가 먼저 확인).
끝나면(오류가 나도) Play를 멈추고 기기 흉내를 끈다.
"""

import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["STUDIO_NAME"] = "UiSandbox"  # practice Studio only: forced before studio_mcp is imported (via device_view)
import device_view as dv  # noqa: E402
import world_blend_view as wb  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# name, zone to stand in, camera target (None = densest monster group of the zone), ZoneLook.Preview id
SHOTS = [
    ("meadow", "SlimeMeadow", None, None),
    ("woods", "GoblinWoods", None, None),
    ("ruins", "SkeletonRuins", None, None),
    ("pumpkin", "PumpkinPatch", None, None),
    ("pumpkin_preview", "SlimeMeadow", None, "PumpkinPatch"),
    ("crossroads", "Crossroads", (0, 3, -18), None),
    ("halo_town", "HaloTown", (0, 3, -400), None),
    ("horns_town", "HornsTown", (0, 3, 400), None),
]

# server: put the character inside `zone` on the real ground (a ray down; a guess under a hill dropped it out of the
# map and it respawned in town), 6 studs behind the camera eye (out of the shot), anchored so monsters cannot push it
PLACE = r'''
local Config = require(game.ReplicatedStorage.Shared.Config)
local p = game.Players:GetPlayers()[1]
local char = p and p.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local hrp = char and char:FindFirstChild("HumanoidRootPart")
if hum then hum.MaxHealth = 1e7; hum.Health = 1e7 end
-- ZoneService bounces players under a zone's MinLevel and out of the other faction's town (test-only attributes)
p:SetAttribute("Level", 60)
if "%s" == "HornsTown" then p:SetAttribute("Faction", "Horns") elseif p:GetAttribute("Faction") ~= "Halo" then p:SetAttribute("Faction", "Halo") end
local eye, target = Vector3.new(%f, %f, %f), Vector3.new(%f, %f, %f)
local back = (eye - target) * Vector3.new(1, 0, 1)
back = back.Magnitude > 0.1 and back.Unit or Vector3.new(0, 0, 1)
local function ground(x, z)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local skip = { workspace:FindFirstChild("Monsters") }
    for _, pl in game.Players:GetPlayers() do if pl.Character then table.insert(skip, pl.Character) end end
    params.FilterDescendantsInstances = skip
    local hit = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
    return hit and hit.Position or Vector3.new(x, target.Y, z)
end
local flat = Vector3.new(eye.X, 0, eye.Z) + back * 6
local pos = ground(flat.X, flat.Z)
if Config.ZoneAt(pos).Id ~= "%s" then
    flat = Vector3.new(target.X, 0, target.Z) + back * 4
    pos = ground(flat.X, flat.Z)
end
if hrp then
    hrp.Anchored = true
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3.2, 0))
end
return Config.ZoneAt(pos).Id
'''

ZONE_NOW = r'''return tostring(game.Players.LocalPlayer:GetAttribute("ZoneId"))'''


def wait_zone(c, zone, seconds=8.0):
    end = time.time() + seconds
    now = None
    while time.time() < end:
        now = dv.luau(c, ZONE_NOW, "Client").strip()
        if now == zone:
            return True
        time.sleep(0.4)
    print("  zone did not switch:", now, "wanted", zone)
    return False


PREVIEW = r'''
game.Players.LocalPlayer:SetAttribute("ZoneLookPreview", %s)
return "preview"
'''

STATE = r'''
local L = game:GetService("Lighting")
local t = L:FindFirstChild("ZoneTint")
local lp = game.Players.LocalPlayer
return string.format("zone=%s preview=%s blessing=%s B=%.2f amb=%s diff=%.2f exp=%.2f tint=%s clock=%.1f",
    tostring(lp:GetAttribute("ZoneId")), tostring(lp:GetAttribute("ZoneLookPreview")),
    tostring(game.ReplicatedStorage.GameState:GetAttribute("WarBlessing")), L.Brightness, tostring(L.Ambient),
    L.EnvironmentDiffuseScale, L.ExposureCompensation, t and tostring(t.TintColor) or "none", L.ClockTime)
'''

# server: GoblinWoods tree leaves one step brighter (MapBuilder colour proposal: about x1.35, e.g. 40,90,45 -> 54,121,61)
TREES_BRIGHT = r'''
local Config = require(game.ReplicatedStorage.Shared.Config)
local n, sample = 0, nil
for _, m in workspace:GetDescendants() do
    if m:IsA("Model") and m.Name == "Tree" then
        local trunk = m:FindFirstChild("Trunk")
        if trunk and Config.ZoneAt(trunk.Position).Id == "GoblinWoods" then
            for _, p in m:GetChildren() do
                if p:IsA("BasePart") and (p.Name == "Leaves" or p.Name == "Leaves2") then
                    sample = sample or tostring(p.Color)
                    local c = p.Color
                    p.Color = Color3.new(math.min(1, c.R * 1.35), math.min(1, c.G * 1.35), math.min(1, c.B * 1.35))
                    n += 1
                end
            end
        end
    end
end
return "brighter leaves " .. n .. " (was " .. tostring(sample) .. ")"
'''

# server: the densest group of GoblinWoods trees (look at their crowns: target y + 6)
TREE_SPOT = r'''
local Config = require(game.ReplicatedStorage.Shared.Config)
local list = {}
for _, m in workspace:GetDescendants() do
    if m:IsA("Model") and m.Name == "Tree" then
        local trunk = m:FindFirstChild("Trunk")
        if trunk and Config.ZoneAt(trunk.Position).Id == "GoblinWoods" then table.insert(list, trunk.Position) end
    end
end
if #list == 0 then return "none" end
local best, bestN = list[1], 0
for _, a in list do
    local n = 0
    for _, b in list do if (a - b).Magnitude <= 30 then n += 1 end end
    if n > bestN then best, bestN = a, n end
end
return string.format("%.2f,%.2f,%.2f", best.X, best.Y + 2, best.Z)
'''

# server: the new Neutral sun texture (Config.UIArt.Parts.Sky_Sun)
SKY_SUN = r'''
local Config = require(game.ReplicatedStorage.Shared.Config)
local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
if not sky then return "no sky" end
sky.SunTextureId = Config.UIArt.Parts.Sky_Sun.Id
return "sun " .. sky.SunTextureId .. " size " .. sky.SunAngularSize
'''

# client: camera at the meadow looking straight at the sun
LOOK_SUN = r'''
local dir = game:GetService("Lighting"):GetSunDirection()
local from = Vector3.new(330, 12, 0)
_G.WorldBlendCam = CFrame.lookAt(from, from + dir * 100)
return tostring(dir)
'''

# server: Eclipse sky (what WarService.applySky("Eclipse") writes) + the GameState blessing ZoneLook reads
NIGHT = r'''
local Config = require(game.ReplicatedStorage.Shared.Config)
local L = game:GetService("Lighting")
local e = Config.Sky.Eclipse
L.ClockTime = e.ClockTime
L.Brightness = e.Brightness; L.Ambient = e.Ambient; L.OutdoorAmbient = e.OutdoorAmbient
L.FogColor = e.FogColor; L.FogEnd = e.FogEnd; L.ExposureCompensation = 0.35
local tint = L:FindFirstChild("WarTint")
if tint then tint.TintColor = e.Tint end
game.ReplicatedStorage.GameState:SetAttribute("WarBlessing", "Horns")
return "night"
'''


def eye_of(cam_text):
    return [float(v) for v in cam_text.strip().split(",")]


def shoot(c, out, name, record):
    path = os.path.join(out, name + ".jpeg")
    state = dv.luau(c, STATE, "Client").strip()
    ok = wb.capture(c, path, "zonelook_" + name)
    record[name] = state
    print(name, ok, state)


def run(c, out, record):
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
    for name, zone, target, preview in SHOTS:
        if target is None:
            group = dv.luau(c, wb.FIND_GROUP % zone, "Server").strip()
            if "," not in group:
                print(name, "no monsters")
                continue
            target = tuple(float(v) for v in group.split(",")[:3])
        eye = eye_of(dv.luau(c, wb.CAMERA % target, "Client"))
        print(name, "in", dv.luau(c, PLACE % (zone, *eye, *target, zone), "Server").strip())
        dv.luau(c, PREVIEW % (json.dumps(preview) if preview else "nil"), "Client")
        wait_zone(c, zone)
        time.sleep(2.2)  # ZoneLook eases for 1.5 s
        shoot(c, out, name, record)
    # trees: GoblinWoods leaves one step brighter (MapBuilder colour proposal), same camera as the woods shot
    spot = dv.luau(c, TREE_SPOT, "Server").strip()
    if "," in spot:
        target = tuple(float(v) for v in spot.split(","))
        eye = eye_of(dv.luau(c, wb.CAMERA % target, "Client"))
        dv.luau(c, PLACE % ("GoblinWoods", *eye, *target, "GoblinWoods"), "Server")
        wait_zone(c, "GoblinWoods")
        time.sleep(2.2)
        shoot(c, out, "woods_trees_now", record)
        print(dv.luau(c, TREES_BRIGHT, "Server").strip())
        time.sleep(1.5)
        shoot(c, out, "woods_trees_bright", record)
    # the new sun in the sky (Neutral): camera at the meadow looking at the sun
    print(dv.luau(c, SKY_SUN, "Server").strip())
    dv.luau(c, LOOK_SUN, "Client")
    time.sleep(2)
    shoot(c, out, "sky_sun", record)
    # border: the meadow pass into the goblin woods, one camera; mid-change and settled
    dv.luau(c, PREVIEW % "nil", "Client")
    group = dv.luau(c, wb.FIND_GROUP % "GoblinWoods", "Server").strip()
    target = tuple(float(v) for v in group.split(",")[:3]) if "," in group else (600, 3, 0)
    eye = eye_of(dv.luau(c, wb.CAMERA % target, "Client"))
    dv.luau(c, PLACE % ("SlimeMeadow", *eye, *target, "SlimeMeadow"), "Server")
    dv.luau(c, r'''local hrp = game.Players:GetPlayers()[1].Character.HumanoidRootPart
hrp.Anchored = true
hrp.CFrame = CFrame.new(470, 8, 0) return "meadow side"''', "Server")
    wait_zone(c, "SlimeMeadow")
    time.sleep(2.2)
    shoot(c, out, "border_0_meadow", record)
    dv.luau(c, PLACE % ("GoblinWoods", *eye, *target, "GoblinWoods"), "Server")
    wait_zone(c, "GoblinWoods")
    time.sleep(0.7)  # about half of the 1.5 s ease
    shoot(c, out, "border_1_changing", record)
    time.sleep(2.5)
    shoot(c, out, "border_2_woods", record)
    # night (Eclipse) in the meadow and the ruins
    print(dv.luau(c, NIGHT, "Server"))
    for name, zone in (("night_meadow", "SlimeMeadow"), ("night_ruins", "SkeletonRuins")):
        group = dv.luau(c, wb.FIND_GROUP % zone, "Server").strip()
        if "," not in group:
            continue
        target = tuple(float(v) for v in group.split(",")[:3])
        eye = eye_of(dv.luau(c, wb.CAMERA % target, "Client"))
        dv.luau(c, PLACE % (zone, *eye, *target, zone), "Server")
        wait_zone(c, zone)
        time.sleep(4)  # the server's night writes settle, then ZoneLook eases back
        shoot(c, out, name, record)
    with open(os.path.join(out, "values.json"), "w", encoding="utf-8") as f:
        json.dump(record, f, ensure_ascii=False, indent=1)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    args = sys.argv[1:]
    out = os.path.join(ROOT, "build", "zone_look")
    if "--out" in args:
        out = args[args.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    record = {}
    with dv.sandbox() as c:  # sandbox check first; Play stop + device reset at the end, also after an error
        run(c, out, record)


if __name__ == "__main__":
    main()
