"""(tools/play_mage_staff_photos.py) Three mages (Halo / Horns / Neutral alchemist) photos in the main Studio test Play (메인 반영 1, 2026-10-12).
Usage: HH_MAIN_STUDIO=1 py tools/play_mage_staff_photos.py [outdir-name]  (own test Play; Crossroads plaza, level 30, tier 3 staff)   -> front x3 + side x3 + side composite + Halo hand close-up + Halo walking side."""
import base64, io, os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-12", "main_apply", sys.argv[1] if len(sys.argv) > 1 else "staff_photos")
os.makedirs(OUT, exist_ok=True)
LOG = []


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:200]


def note(m):
    print(m, flush=True)
    LOG.append(m)


def save(c, name):
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            p = os.path.join(OUT, name + ".png")
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(p)
            note("saved " + p)
            return p
    note("capture failed " + name)


STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "Class", "ClassChosen", "Level" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
"""
FIRE = r"""
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("%s"):FireServer(%s)
return "fired %s"
"""
DEBUG = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local fn = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
if not (p and fn) then return "no player / DebugCommand" end
local out = {}
for _, kv in { %s } do
	local ok, r = pcall(function() return fn:Invoke(p.Name, kv[1], kv[2]) end)
	table.insert(out, kv[1] .. "=" .. tostring(ok and r or ("ERR " .. tostring(r))))
end
return table.concat(out, " ")
"""
# mode: front | side | hand ; walk=true makes the character step before the shot
CAM = r"""
local Players = game:GetService("Players")
local p = Players.LocalPlayer
local ch = p.Character
local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = false end
end
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 40
local pos = hrp.Position
local look = hrp.CFrame.LookVector
local right = hrp.CFrame.RightVector
local mode = "%s"
local target = pos - Vector3.new(0, 0.2, 0)
local camPos
if mode == "front" then
	camPos = pos + look * 15 + Vector3.new(0, 0.6, 0)
elseif mode == "side" then
	camPos = pos + right * 15 + Vector3.new(0, 0.6, 0)
else
	local hand = ch:FindFirstChild("RightHand") or hrp
	target = hand.Position
	camPos = target + right * 4 + look * 0.5 + Vector3.new(0, 0.3, 0)
	cam.FieldOfView = 35
end
cam.CFrame = CFrame.lookAt(camPos, target)
return string.format("cam %%s at %%.1f,%%.1f,%%.1f", mode, camPos.X, camPos.Y, camPos.Z)
"""
RESET = r"""
local p = game:GetService("Players").LocalPlayer
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do
	if g:IsA("ScreenGui") then g.Enabled = true end
end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
return "reset"
"""
ANCH = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if hrp then hrp.Anchored = %s end
return "anchored %s"
"""
WALK = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
if h then h:Move(Vector3.new(0, 0, -1), true) end
return "walking"
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


TELE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
local ch = p.Character
if ch then ch:PivotTo(CFrame.new(0, 5, -25)) end
return "teleported " .. tostring(ch ~= nil)
"""


def gear(c):
    note("tutorial: " + lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
    time.sleep(1)
    note("gear: " + lua(c, DEBUG % '{ "Level", 30 }, { "WeaponOwnedMask", 127 }', "Server"))
    time.sleep(1)
    note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
    time.sleep(2)


def set_look(c, faction, cls):
    note(f"set {faction} {cls}: " + lua(c, DEBUG % f'{{ "Faction", "{faction}" }}, {{ "Class", "{cls}" }}', "Server"))
    time.sleep(4)
    note(lua(c, TELE, "Server"))
    time.sleep(1)
    note(lua(c, FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client"))
    time.sleep(2)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
        time.sleep(26)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Mage", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        time.sleep(3)
        gear(c)
        time.sleep(2)
        sides = []
        for tag, fac, cls in (("halo", "Halo", "Mage"), ("horns", "Horns", "Mage"), ("alch", "Neutral", "Mage")):
            set_look(c, fac, cls)
            note("state: " + lua(c, STATE, "Server"))
            note(lua(c, ANCH % ("true", "on"), "Server"))
            time.sleep(1.5)
            note(lua(c, CAM % "front", "Client"))
            time.sleep(1.5)
            save(c, f"01_{tag}_front")
            note(lua(c, CAM % "side", "Client"))
            time.sleep(1.5)
            sides.append(save(c, f"01_{tag}_right"))
            if tag == "halo":
                note(lua(c, CAM % "hand", "Client"))
                time.sleep(1.5)
                save(c, "02_halo_hand_right")
                note(lua(c, ANCH % ("false", "off"), "Server"))
                note(lua(c, WALK, "Client"))
                time.sleep(1.0)
                note(lua(c, CAM % "side", "Client"))
                save(c, "04_halo_walk_right")
            note(lua(c, RESET, "Client"))
        imgs = [Image.open(p) for p in sides if p]
        if imgs:
            w, h = imgs[0].size
            sheet = Image.new("RGB", (w * len(imgs), h))
            for i, im in enumerate(imgs):
                sheet.paste(im, (i * w, 0))
            sheet.save(os.path.join(OUT, "three_mages_side_v3.png"))
            note("saved composite")
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))]
        note("console: " + "\n".join(errs[-20:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", nil) return "fresh off"', "Edit"))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
