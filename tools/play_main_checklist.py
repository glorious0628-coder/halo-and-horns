"""Main Studio Play checklist (검수 2026-10-07, user: "md says applied to the main Studio - check what is not"):
own test Play with a FRESH in-memory save (ServerStorage StudioFreshSave), no mouse / keyboard input.
  py tools/play_main_checklist.py pc|phone|story   (own test Play: tell 검수 first; the main Studio window must not be
  minimized or the 3D view captures white; phone / story also play the first mission with fists and claim it)
Checks + photos: prologue (letterbox), team notice (English, no Hangul anywhere on screen), HUD layout, story portrait
(the Lunch1 card after the first claim, at the Crossroads), reward popup (UIKit.RewardPopup built from the real module into MainGui), map v2 / MeadowKit /
WorldKit3D / new tile ids, SunRays off, a few v2 spots. Stops Play and puts the device back to default at the end."""
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
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "main_checklist", MODE)
LOG = []

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
DEVICE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
return svc:GetDeviceAsync()
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
# client: every visible text on screen (Hangul flagged), big black bars at the top / bottom, open windows
SCREEN = r'''
local HttpService = game:GetService("HttpService")
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
local cam = workspace.CurrentCamera
local vw, vh = cam.ViewportSize.X, cam.ViewportSize.Y
local out = { Viewport = { math.floor(vw), math.floor(vh) }, Texts = {}, Hangul = {}, Bars = {}, Named = {} }
local function visible(x)
	local a = x
	while a and a ~= pg do
		if a:IsA("GuiObject") and not a.Visible then return false end
		if a:IsA("ScreenGui") and not a.Enabled then return false end
		if a:IsA("BillboardGui") or a:IsA("SurfaceGui") then return false end
		a = a.Parent
	end
	return true
end
local seen = {}
for _, x in pg:GetDescendants() do
	if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text ~= "" and visible(x) and x.TextTransparency < 0.95 then
		local t = x.ContentText ~= "" and x.ContentText or x.Text
		if not seen[t] and #out.Texts < 60 then
			seen[t] = true
			table.insert(out.Texts, t)
		end
		if string.find(t, "[\234-\237][\128-\191][\128-\191]") then table.insert(out.Hangul, x:GetFullName() .. " = " .. t) end
	end
	if x:IsA("Frame") and visible(x) and x.BackgroundTransparency < 0.2 then
		local c = x.BackgroundColor3
		local s, ps = x.AbsoluteSize, x.AbsolutePosition
		if c.R < 0.08 and c.G < 0.08 and c.B < 0.08 and s.X >= vw * 0.9 and s.Y >= 8 and s.Y < vh * 0.4 then
			table.insert(out.Bars, string.format("%s %dx%d at y=%d", x:GetFullName():gsub("^.-PlayerGui%.", ""), s.X, s.Y, ps.Y))
		end
	end
	if (x:IsA("Frame") or x:IsA("ImageLabel") or x:IsA("TextButton")) and visible(x) then
		local s2 = x.AbsoluteSize
		local tr = x:IsA("ImageLabel") and math.min(x.BackgroundTransparency, x.ImageTransparency) or x.BackgroundTransparency
		if s2.X >= vw * 0.9 and s2.Y >= vh * 0.9 and tr < 0.9 then
			local c2 = x.BackgroundColor3
			out.Full = out.Full or {}
			table.insert(out.Full, string.format("%s rgb(%d,%d,%d) tr=%.2f", x:GetFullName():gsub("^.-PlayerGui%.", ""), c2.R * 255, c2.G * 255, c2.B * 255, tr))
		end
	end
	if x.Name == "RewardRays" or x.Name == "RewardPopup" or x.Name == "Portrait" or x.Name == "StoryFace" then
		table.insert(out.Named, x:GetFullName():gsub("^.-PlayerGui%.", "") .. (x:IsA("GuiObject") and (" visible=" .. tostring(visible(x))) or ""))
	end
end
local L = game:GetService("Lighting")
out.Cam = string.format("%s (%.0f,%.0f,%.0f) look (%.2f,%.2f,%.2f)", tostring(cam.CameraType):gsub("Enum.CameraType.", ""),
	cam.CFrame.Position.X, cam.CFrame.Position.Y, cam.CFrame.Position.Z, cam.CFrame.LookVector.X, cam.CFrame.LookVector.Y, cam.CFrame.LookVector.Z)
local bloom = L:FindFirstChildOfClass("BloomEffect")
out.Light = string.format("exp=%.2f bright=%.2f fog=%d..%d bloom=%s clock=%.1f", L.ExposureCompensation, L.Brightness, L.FogStart, L.FogEnd,
	bloom and string.format("%.2f", bloom.Intensity) or "-", L.ClockTime)
return HttpService:JSONEncode(out)
'''
WORLD = r'''
local HttpService = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local MS = game:GetService("MaterialService")
local L = game:GetService("Lighting")
local map = workspace:FindFirstChild("Map")
local decor = map and map:FindFirstChild("Decor")
local out = {}
local function count(inst) return inst and #inst:GetChildren() or -1 end
out.MeadowKit = count(decor and decor:FindFirstChild("MeadowKit"))
out.SeaRocks = count(decor and decor:FindFirstChild("SeaRocks"))
out.PondStones = count(decor and decor:FindFirstChild("PondStones"))
out.WorldKit3D = count(SS:FindFirstChild("WorldKit3D"))
out.SlimePondPlateInDecor = decor and decor:FindFirstChild("SlimePond") ~= nil
local zones = {}
for _, z in (map and map:FindFirstChild("Zones") and map.Zones:GetChildren() or {}) do
	zones[z.Name] = string.format("(%.0f,%.0f) %dx%d", z.Position.X, z.Position.Z, z.Size.X, z.Size.Z)
end
out.Zones = zones
local mv = {}
for _, v in MS:GetDescendants() do
	if v:IsA("MaterialVariant") and (v.Name == "GE_Grass" or v.Name == "GE_Rock" or v.Name == "GE_Cobblestone" or v.Name == "GE_DirtPath") then
		mv[v.Name] = v.ColorMap
	end
end
out.Tiles = mv
local rays = L:FindFirstChildOfClass("SunRaysEffect")
out.SunRays = rays and { Enabled = rays.Enabled, Intensity = rays.Intensity } or "none"
out.Water = tostring(workspace.Terrain.WaterColor)
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
params.IgnoreWater = false
local hits = {}
for name, xz in { Crossroads = { 0, -25 }, Meadow = { 300, 0 }, Pond = { 290, 150 }, Pass = { 1225, 0 }, Peak = { 1225, 180 } } do
	local h = workspace:Raycast(Vector3.new(xz[1], 300, xz[2]), Vector3.new(0, -600, 0), params)
	hits[name] = h and string.format("%.1f %s", h.Position.Y, tostring(h.Material):gsub("Enum.Material.", "")) or "none"
end
out.Ground = hits
return HttpService:JSONEncode(out)
'''
CHAT_OPEN = r'''
local ok, err = pcall(function() game:GetService("StarterGui"):SetCore("ChatActive", true) end)
return "ChatActive " .. tostring(ok) .. " " .. tostring(err)
'''
NEAREST_SLIME = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
local best, bd
for _, m in (workspace:FindFirstChild("Monsters") and workspace.Monsters:GetChildren() or {}) do
	local k = m:GetAttribute("MonsterKind") or m.Name
	local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	local h = m:FindFirstChildOfClass("Humanoid")
	if (k == "Slime" or k == "ShardSlime") and r and (not h or h.Health > 0) then
		local d = (r.Position - root.Position).Magnitude
		if not bd or d < bd then best, bd = r, d end
	end
end
if not best then return "none" end
local dir = (root.Position - best.Position) * Vector3.new(1, 0, 1)
dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
local at = best.Position + dir * 4
p.Character:PivotTo(CFrame.lookAt(Vector3.new(at.X, root.Position.Y, at.Z), Vector3.new(best.Position.X, root.Position.Y, best.Position.Z)))
return string.format("slime at %.0f", bd)
'''
DISPATCH_F = r'''
local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
local kb = ps:FindFirstChild("Keybinds")
local d = kb and kb:FindFirstChild("Dispatch")
if not d then return "no dispatch" end
return tostring(d:Invoke({ KeyCode = Enum.KeyCode.F }))
'''
KILLS = r'''
local p = game:GetService("Players"):GetPlayers()[1]
return tostring(p:GetAttribute("TutorialKills")) .. " step " .. tostring(p:GetAttribute("TutorialStep"))
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local keys = { "DataLoaded", "Faction", "Class", "ClassChosen", "TutorialStep", "ZoneId", "Level", "WeaponTier" }
local out = {}
for _, k in keys do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
'''
# client: the real UIKit module built into the real MainGui (same code and art the game uses)
POPUP = r'''
local p = game:GetService("Players").LocalPlayer
local ps = p:WaitForChild("PlayerScripts")
local ok, UIKit = pcall(require, ps:WaitForChild("UIKit"))
if not ok then return "require failed: " .. tostring(UIKit) end
local pg = p:FindFirstChildOfClass("PlayerGui")
local gui = pg:FindFirstChild("MainGui") or pg:FindFirstChildOfClass("ScreenGui")
if not UIKit.Gui then UIKit.Gui = gui end
local ok2, popup = pcall(UIKit.RewardPopup, { Title = "Daily Chest", Lines = { "Test popup (checklist)" },
	Rewards = { { Icon = "IconCoin", Amount = 50 }, { Icon = "IconExp", Amount = 20 } }, Button = "Claim!", Faction = p:GetAttribute("Faction") })
if not ok2 then return "popup failed: " .. tostring(popup) end
task.delay(6, function() if popup and popup.Close then pcall(popup.Close) end end)
return "popup shown " .. tostring(popup ~= nil)
'''
VISIT = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
local x, z, yaw = %f, %f, %f
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { workspace.Terrain }
local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0), params)
local y = hit and hit.Position.Y or 0
if not ch:FindFirstChildOfClass("ForceField") then
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = ch
end
ch:PivotTo(CFrame.new(x, y + 4, z) * CFrame.Angles(0, math.rad(-yaw), 0))
task.wait(2.5)
return string.format("zone=%%s", tostring(p:GetAttribute("ZoneId")))
'''
STOPS = [("crossroads", 0, -25, 90), ("meadow_arrival", 236, 0, 90), ("meadow_pond", 262, 122, 45),
         ("woods", 736, 0, 90), ("pass", 1205, 0, 90), ("ruins", 1285, 0, 90), ("halo_town", 0, -400, 180),
         ("horns_bridge", 0, 250, 0)]
PHONE_STOPS = {"crossroads", "meadow_arrival", "meadow_pond"}


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
    try:
        res = c.call("screen_capture", {"capture_id": name})
    except Exception as e:  # noqa: BLE001
        note("capture error " + name + " " + str(e)[:120])
        return
    for part in res.get("content", []):
        if part.get("type") == "image":
            from PIL import Image
            os.makedirs(OUT, exist_ok=True)
            path = os.path.join(OUT, name + ".png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(path)
            note("saved " + path)
            return
    note("capture failed " + name)


def screen(c, tag):
    raw = lua(c, SCREEN, "Client")
    try:
        d = json.loads(raw)
        note(f"[{tag}] viewport {d['Viewport']} hangul={len(d['Hangul'])} bars={d['Bars']} full={d.get('Full')} cam={d.get('Cam')} light={d.get('Light')}")
        note(f"[{tag}] named={d['Named']}")
        if d["Hangul"]:
            note(f"[{tag}] HANGUL: " + " | ".join(d["Hangul"][:8]))
        note(f"[{tag}] texts: " + " | ".join(d["Texts"][:40]))
    except Exception:  # noqa: BLE001
        note(f"[{tag}] screen probe: {raw[:400]}")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        note("device before: " + lua(c, DEVICE, "Edit"))
        if MODE == "phone":
            note("device: " + lua(c, SET_PHONE, "Edit"))
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        t0 = time.time()
        while time.time() - t0 < 90 and lua(c, READY, "Server") != "ready":
            time.sleep(1.5)
        note("loaded after %.0fs" % (time.time() - t0))
        for i, wait_s in enumerate((2, 3, 4, 4)):
            time.sleep(wait_s)
            save(c, f"01_prologue_{i}")
            screen(c, f"prologue {i}")
        time.sleep(13)  # the opening ends (15-25 s)
        save(c, "03_faction_pick")
        screen(c, "faction pick")
        note("chat open: " + lua(c, CHAT_OPEN, "Client"))
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        time.sleep(1.5)
        save(c, "04_team_notice")
        screen(c, "team notice")
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        time.sleep(4)
        note("state: " + lua(c, STATE, "Server"))
        save(c, "05a_guide_window")
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(6)
        note("state: " + lua(c, STATE, "Server"))
        save(c, "05_hud")
        screen(c, "hud")
        note("world: " + lua(c, WORLD, "Server"))
        note("story: " + lua(c, FIRE % ("StoryAction", '"S0", "Open"', "StoryAction"), "Client"))
        time.sleep(2.5)
        save(c, "06_story_portrait")
        screen(c, "story")
        note("popup: " + lua(c, POPUP, "Client"))
        time.sleep(1.5)
        save(c, "07_reward_popup")
        screen(c, "popup")
        time.sleep(5)
        if MODE in ("phone", "story"):
            # the first mission (5 slimes with fists) -> claim -> the S0 story page with its portrait
            t1 = time.time()
            while time.time() - t1 < 160:
                k = lua(c, KILLS, "Server")
                if k.startswith("5 ") or "step 99" in k:
                    break
                lua(c, NEAREST_SLIME, "Server")
                for _ in range(3):
                    lua(c, DISPATCH_F, "Client")
                    time.sleep(0.8)
            note("hunt: " + lua(c, KILLS, "Server"))
            note(lua(c, FIRE % ("ClaimQuest", '"tutorial"', "ClaimQuest"), "Client"))
            time.sleep(4)
            note("after claim: " + lua(c, STATE, "Server"))
            save(c, "08_after_claim")
            screen(c, "after claim")
            # a calm spot (the Lunch1 card pops by itself once, away from fights), then ask for it
            note("calm: " + lua(c, VISIT % (0, -25, 90), "Server"))
            time.sleep(4)
            save(c, "09a_story_pop")
            screen(c, "story pop")
            note("story: " + lua(c, FIRE % ("StoryAction", '"Lunch1", "Open"', "StoryAction"), "Client"))
            time.sleep(3)
            save(c, "09_story_portrait")
            screen(c, "story after claim")
            if MODE == "story":
                return
        note(lua(c, 'local p = game:GetService("Players"):GetPlayers()[1] p:SetAttribute("Level", 30) return "level 30 (test only)"', "Server"))
        for name, x, z, yaw in STOPS:
            if MODE == "phone" and name not in PHONE_STOPS:
                continue
            note(f"{name}: " + lua(c, VISIT % (x, z, yaw), "Server"))
            save(c, "10_" + name)
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "warn", "infinite yield"))]
        note("console: " + "\n".join(errs[-30:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        note("device after: " + lua(c, RESTORE, "Edit"))
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


main()
