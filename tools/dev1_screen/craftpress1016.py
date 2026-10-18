"""Press-through check of the craft window (Potion / Gear rows) in MY test Studio (STUDIO_NAME=PhoneTest_1015), with
개발 2's scene command (dev2-scene-cmd) synced: scene ArtisanAlch / ArtisanSmith -> the bench prompt (Enabled, its key)
-> the craft window opens -> the row (AP1 / G1) -> [Brew / Forge] -> the ring screen -> [Skip] -> the result (stock /
gear). Studio MCP virtual keys / clicks inside my test Play only. Usage: py craftpress1016.py Alch|Smith"""
import base64, io, json, os, subprocess, sys, time
GAME = r"C:\Users\glori\Documents\Roblox\Game"
sys.path.insert(0, os.path.join(GAME, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

ROLE = sys.argv[1] if len(sys.argv) > 1 else "Alch"
ROW = {"Alch": "AP1", "Smith": "G1"}[ROLE]
TREE = r"C:\Users\glori\Documents\Roblox\wt_dev1b"
OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "craft_press")
os.makedirs(OUT, exist_ok=True)
LOG = []


def log(*a):
    s = " ".join(str(x) for x in a)
    print(s, flush=True)
    LOG.append(s)


def text_of(res):
    return "".join(p.get("text", "") for p in res.get("content", []))


def lua(c, code, dm):
    try:
        return text_of(c.call("execute_luau", {"code": code, "datamodel_type": dm}))
    except Exception as e:  # noqa: BLE001
        return "ERR " + str(e)[:300]


def shot(c, name):
    try:
        res = c.call("screen_capture", {"capture_id": name})
    except Exception as e:  # noqa: BLE001
        log("shot fail", name, e)
        return
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, f"{ROLE}_{name}.png"))
            return


def click(c, path):
    try:
        c.call("user_mouse_input", {"actions": [{"action": "moveTo", "instance_path": path},
                                                {"action": "mouseButtonClick", "mouse_button": "left"}], "datamodel_type": "Client"})
        return "clicked " + path
    except Exception as e:  # noqa: BLE001
        return "click err " + str(e)[:200]


BENCH = r'''
local me = game.Players.LocalPlayer
local hrp = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
local best, bd = nil, math.huge
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Parent and d.Parent:IsA("BasePart") and d.Parent:GetAttribute("Role") ~= nil then
		local dist = hrp and (d.Parent.Position - hrp.Position).Magnitude or 0
		if dist < bd then best, bd = d, dist end
	end
end
if not best then return "no bench prompt" end
return string.format("bench role=%s enabled=%s key=%s dist=%.1f action=%s", tostring(best.Parent:GetAttribute("Role")),
	tostring(best.Enabled), best.KeyboardKeyCode.Name, bd, best.ActionText)
'''
FIND = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local x = pg:FindFirstChild("%s", true)
return x and (x:GetFullName() .. " visible=" .. tostring(x.Visible) .. (x:IsA("GuiButton") and (" active=" .. tostring(x.Active)) or "")) or "none"
'''
STATE = r'''
local p = game.Players.LocalPlayer
return "HP=" .. tostring(p:GetAttribute("HPPotionCount")) .. " MP=" .. tostring(p:GetAttribute("MPPotionCount")) .. " gearHp=" .. tostring(p:GetAttribute("GearHp"))
'''


def path_of(found):
    full = found.split(" ")[0]
    return "LocalPlayer.PlayerGui." + full.split("PlayerGui.", 1)[1] if "PlayerGui." in full else full


def main():
    c = Client()
    c.start()
    lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return ""', "Edit")
    c.call("start_stop_play", {"is_start": True})
    try:
        t0 = time.time()
        while time.time() - t0 < 90:
            if lua(c, 'local p = game.Players:GetPlayers()[1] return tostring(p and p:GetAttribute("DataLoaded"))', "Server") == "true":
                break
            time.sleep(1.5)
        time.sleep(2.5)
        c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": "Return"}], "datamodel_type": "Client"})
        time.sleep(2)
        env = dict(os.environ, STUDIO_NAME="PhoneTest_1015")
        r = subprocess.run([sys.executable, os.path.join(TREE, "tools", "scene.py"), "Artisan" + ROLE], capture_output=True, text=True, env=env, timeout=120)
        log("scene:", (r.stdout + r.stderr).strip()[:300])
        time.sleep(3)
        log("before:", lua(c, STATE, "Client"))
        b = lua(c, BENCH, "Client")
        log("1", b)
        key = b.split("key=")[1].split(" ")[0] if "key=" in b else "G"
        c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": key}], "datamodel_type": "Client"})
        time.sleep(2.5)
        row = lua(c, FIND % ("Row_" + ROW), "Client")
        log("2 window row:", row)
        shot(c, "window")
        if row != "none":
            log(click(c, path_of(row)))
            time.sleep(1)
        forge = lua(c, FIND % "Forge", "Client")
        log("3 start button:", forge)
        if forge != "none":
            log(click(c, path_of(forge)))
            time.sleep(2.5)
        skip = lua(c, FIND % "Skip", "Client")
        log("4 ring screen skip:", skip)
        shot(c, "ring")
        if skip != "none":
            log(click(c, path_of(skip)))
            time.sleep(4)
        log("5 after:", lua(c, STATE, "Client"))
        shot(c, "after")
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
        except Exception as e:  # noqa: BLE001
            log("stop", e)
        with open(os.path.join(OUT, f"{ROLE}_log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG))


main()
