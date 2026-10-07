"""Map v2 P2 own test Play (main Studio, FRESH in-memory save via ServerStorage StudioFreshSave; the tester's real save is
not touched): faction / class by remotes, then the character visits the v2 spots (server PivotTo) and each stop records
ZoneId, the ground under the feet (material, height), monsters in that zone and a game-camera photo.
Usage: py tools/play_mapv2_check.py pc|phone [tag]   (phone = device simulator 749x361, back to default at the end; Play
stops at the end). Own test Play only: ask 검수 first (it starts / stops Play in the main Studio)."""
import base64
import io
import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402

MODE = sys.argv[1] if len(sys.argv) > 1 else "pc"
TAG = sys.argv[2] if len(sys.argv) > 2 else MODE
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "map_v2_play")
LOG = []

# name: (x, z, yaw degrees: 0 = looking -Z / north)
STOPS = [
    ("crossroads_spawn", 0, -25, 90),
    ("crossroads_east_road", 120, 0, 90),
    ("meadow_arrival", 236, 0, 90),
    ("meadow_pond", 270, 120, 45),
    ("meadow_king_hill", 400, -120, 90),
    ("woods_arrival", 736, 0, 90),
    ("woods_camp1", 815, 80, 60),
    ("pass_corridor", 1205, 0, 90),
    ("ruins_arrival", 1285, 0, 90),
    ("halo_town", 0, -400, 180),
    ("horns_town", 0, 400, 0),
]
PHONE_STOPS = {"crossroads_spawn", "meadow_arrival", "woods_arrival"}

SET_PHONE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
svc:SetDeviceAsync("samsung_galaxy_s22_ultra")
task.wait(0.3)
svc:SetResolutionAsync(749, 361)
task.wait(0.3)
svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
task.wait(0.3)
local r = svc:GetResolutionAsync()
return svc:GetDeviceAsync() .. " " .. r.X .. "x" .. r.Y
'''
RESTORE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
if svc:GetDeviceAsync() ~= "default" then
	pcall(function() svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) end)
	svc:StopSimulationAsync()
	task.wait(0.3)
end
return svc:GetDeviceAsync()
'''
READY = r'''
local p = game:GetService("Players"):GetPlayers()[1]
return p and p:GetAttribute("DataLoaded") == true and p.Character and "ready" or "wait"
'''
FIRE = r"""
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""
VISIT = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local x, z, yaw = %f, %f, %f
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = false
local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
local y = hit and hit.Position.Y or 0
if not ch:FindFirstChildOfClass("ForceField") then
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = ch
end
ch:PivotTo(CFrame.new(x, y + 4, z) * CFrame.Angles(0, math.rad(-yaw), 0))
return string.format("ground %%s %%.2f", hit and tostring(hit.Material):gsub("Enum.Material.", "") or "none", y)
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
local zone = p:GetAttribute("ZoneId")
local mons, near = 0, 0
local folder = workspace:FindFirstChild("Monsters")
for _, m in (folder and folder:GetChildren() or {}) do
	local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	if r and m:GetAttribute("ZoneId") == zone then mons += 1 end
	if r and root and (r.Position - root.Position).Magnitude < 80 then near += 1 end
end
return string.format("zone=%s pos=(%.0f,%.1f,%.0f) state=%s monstersInZone=%d within80=%d", tostring(zone),
	root and root.Position.X or 0, root and root.Position.Y or 0, root and root.Position.Z or 0,
	hum and tostring(hum:GetState()):gsub("Enum.HumanoidStateType.", "") or "?", mons, near)
'''


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(msg):
    print(msg, flush=True)
    LOG.append(msg)


def save(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            from PIL import Image
            os.makedirs(OUT, exist_ok=True)
            path = os.path.join(OUT, f"{TAG}_{name}.png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(path)
            note("saved " + path)
            return
    note("capture failed " + name)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        if MODE == "phone":
            note("device: " + lua(c, SET_PHONE, "Edit"))
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        t0 = time.time()
        while time.time() - t0 < 90 and lua(c, READY, "Server") != "ready":
            time.sleep(2)
        time.sleep(26)  # the first-time opening
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        time.sleep(2)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        time.sleep(4)
        for name, x, z, yaw in STOPS:
            if MODE == "phone" and name not in PHONE_STOPS:
                continue
            note(f"{name}: " + lua(c, VISIT % (x, z, yaw), "Server"))
            time.sleep(3.5)
            note(f"{name}: " + lua(c, STATE, "Server"))
            save(c, name)
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "warn", "infinite yield"))]
        note("console: " + "\n".join(errs[-25:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        note("device: " + lua(c, RESTORE, "Edit"))
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, f"{TAG}_log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


main()
