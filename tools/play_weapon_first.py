"""A23-74 weapon first: own test Play with a FRESH in-memory save (ServerStorage StudioFreshSave, Studio only; nothing
is saved and the tester's real save is not touched), on PC or on the phone simulator (749x361, back to default at the
end): bare hands -> faction / class -> guide [Accept] -> TutorialStep Forge (3) with the 'Off to the Forge!' fade ->
the server walks me to the anvil -> the beam / pinned row point at the anvil -> the anvil prompt hands over the first
weapon -> step 1 and the meadow beam. Captures + probes at each step, then stops Play (finally).
Usage: py tools/play_weapon_first.py pc|phone [outdir-name]   (own test Play only: ask 검수 first; needs the dev2-weapon
server, Config.Tutorial.Steps.Forge = 3; ANVIL_PROMPT env = the anvil prompt's name, default HHC_BlacksmithPrompt)"""
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
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-07", "weapon_first",
                   sys.argv[2] if len(sys.argv) > 2 else MODE)
LOG = []


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
            path = os.path.join(OUT, name + ".png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(path)
            note("saved " + path)
            return
    note("capture failed " + name)


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

STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local keys = { "DataLoaded", "Faction", "Class", "ClassChosen", "TutorialStep", "TutorialKills", "WeaponTier",
	"WeaponOwnedMask", "Level", "BankGold", "CarriedGold", "BlacksmithVisited", "ZoneId" }
local out = {}
for _, k in keys do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if root then table.insert(out, string.format("pos=%.0f,%.0f,%.0f", root.Position.X, root.Position.Y, root.Position.Z)) end
local map = workspace:FindFirstChild("Map")
-- the anvil = the part holding the blacksmith prompt (ShopService.Anvil; kit or primitive guild)
local anvil = nil
for _, d in (map and map:GetDescendants() or {}) do
	if d:IsA("ProximityPrompt") and d.Name == "HHC_BlacksmithPrompt" and d.Parent:IsA("BasePart") then
		anvil = d.Parent
		break
	end
end
if anvil and root then
	table.insert(out, string.format("anvilDist=%.1f", ((root.Position - anvil.Position) * Vector3.new(1, 0, 1)).Magnitude))
end
local w = p.Character and p.Character:FindFirstChild("WeaponModel")
table.insert(out, "weaponModel=" .. tostring(w ~= nil))
return table.concat(out, " ")
"""

# client: the guide beam label (HUDGuideLabel) and every visible line that talks about the first steps
PROBE = r"""
local HttpService = game:GetService("HttpService")
local p = game:GetService("Players").LocalPlayer
local out = { Beam = {}, Lines = {} }
for _, d in workspace:GetDescendants() do
	if d.Name == "HUDGuideLabel" and d:IsA("BillboardGui") then
		local t = d:FindFirstChildOfClass("TextLabel")
		local part = d.Parent
		table.insert(out.Beam, string.format("%s @ %s (%.0f,%.0f,%.0f)", t and t.Text or "?", part and part:GetFullName() or "?",
			part and part.Position.X or 0, part and part.Position.Y or 0, part and part.Position.Z or 0))
	end
end
local seen = {}
local pg = p:FindFirstChildOfClass("PlayerGui")
for _, x in pg:GetDescendants() do
	if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text ~= "" and not seen[x.Text] then
		local vis = x.Visible
		local a = x.Parent
		while vis and a and a ~= pg do
			if a:IsA("GuiObject") and not a.Visible then vis = false end
			if a:IsA("ScreenGui") and not a.Enabled then vis = false end
			a = a.Parent
		end
		local low = string.lower(x.Text)
		if vis and (string.find(low, "forge", 1, true) or string.find(low, "weapon", 1, true) or string.find(low, "anvil", 1, true)
			or string.find(low, "meadow", 1, true) or string.find(low, "otto", 1, true) or string.find(low, "supply", 1, true)
			or string.find(low, "off to", 1, true) or string.find(low, "bare hands", 1, true)) then
			seen[x.Text] = true
			table.insert(out.Lines, x:GetFullName():gsub("^.-PlayerGui%.", "") .. " = " .. x.Text)
		end
	end
end
local cam = workspace.CurrentCamera
out.Viewport = { math.floor(cam.ViewportSize.X), math.floor(cam.ViewportSize.Y) }
return HttpService:JSONEncode(out)
"""

FIRE = r"""
local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
R:WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""

# client: hold the anvil prompt (ProximityPrompt:InputHoldBegin/End, the same path as a custom prompt UI)
ANVIL_PROMPT = r"""
local map = workspace:FindFirstChild("Map")
local found = {}
for _, d in (map or workspace):GetDescendants() do
	if d:IsA("ProximityPrompt") and (d.Name == "%s" or d.Name == "BlacksmithPrompt") then table.insert(found, d) end
end
if #found == 0 then return "no prompt" end
local pr = found[1]
local info = string.format("%%s enabled=%%s hold=%%.1f dist=%%.0f", pr:GetFullName(), tostring(pr.Enabled), pr.HoldDuration, pr.MaxActivationDistance)
pr:InputHoldBegin()
task.wait(pr.HoldDuration + 0.2)
pr:InputHoldEnd()
return "held " .. info
"""

DISPATCH = r"""
local ps = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
local kb = ps:FindFirstChild("Keybinds")
local d = kb and kb:FindFirstChild("Dispatch")
if not d then return "no dispatch" end
return tostring(d:Invoke({ KeyCode = Enum.KeyCode.%s }))
"""


def wait_state(c, cond, timeout, every=1.0):
    t0 = time.time()
    last = ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def probe(c, tag):
    raw = lua(c, PROBE, "Client")
    note(f"probe {tag}: {raw}")
    return raw


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    prompt_name = os.environ.get("ANVIL_PROMPT", "HHC_BlacksmithPrompt")
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
        s = wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0)
        note("loaded: " + s)
        time.sleep(26)  # the first-time opening plays (15-25 s)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        s = wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        note("chosen: " + s)
        time.sleep(4)
        probe(c, "bare hands")
        save(c, "01_bare_hands")
        # the guide's first quest: [Accept] -> the Forge step + the walk to the anvil
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        s = wait_state(c, lambda x: "TutorialStep=3" in x, 10, 0.3)
        note("accepted: " + s)
        time.sleep(1.0)
        probe(c, "walk fade")
        save(c, "02_off_to_the_forge")
        s = wait_state(c, lambda x: "anvilDist=" in x and float(x.split("anvilDist=")[1].split()[0]) < 14, 12, 0.5)
        note("moved: " + s)
        time.sleep(2.0)
        probe(c, "at the forge")
        save(c, "03_at_the_anvil")
        # the first weapon at the anvil
        note("prompt: " + lua(c, ANVIL_PROMPT % prompt_name, "Client"))
        s = wait_state(c, lambda x: "WeaponTier=1" in x, 10, 0.5)
        if "WeaponTier=1" not in s:
            note("prompt gave nothing; forge key U: " + lua(c, DISPATCH % "U", "Client"))
            s = wait_state(c, lambda x: "WeaponTier=1" in x, 10, 0.5)
        note("weapon: " + s)
        time.sleep(1.5)
        probe(c, "first weapon")
        save(c, "04_first_weapon")
        s = wait_state(c, lambda x: "TutorialStep=1" in x or "TutorialStep=2" in x, 10, 0.5)
        note("next step: " + s)
        time.sleep(4.0)
        probe(c, "meadow beam")
        save(c, "05_to_the_meadow")
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
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")
        c.close()


main()
