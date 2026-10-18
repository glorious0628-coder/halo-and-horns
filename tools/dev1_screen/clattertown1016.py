"""A23-212 Clatter town scenes photos in MY test Studio (STUDIO_NAME=PhoneTest_1015): fire the three scenes to me and
capture each. Usage: py clattertown1016.py"""
import base64, io, os, sys, time
GAME = r"C:\Users\glori\Documents\Roblox\Game"
sys.path.insert(0, os.path.join(GAME, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-16", "clatter_town")
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
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, name + ".png"))
            log("saved", name)
            return


FIRE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
local cf = hrp.CFrame
local pos = (cf * CFrame.new(3, 0, -9)).Position
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Fx"):FireClient(p, "StoryScene",
	{ Id = "Clatter", Key = "%s", Value = "Clatter", Pos = pos, Look = hrp.Position })
return "fired %s"
'''
CHECK = r'''
local f = workspace:FindFirstChild("HH_ClatterScene")
if not f then return "no scene" end
local head = f:FindFirstChild("Skull")
local bb = head and head:FindFirstChild("StoryFindBubble")
local w = bb and bb:FindFirstChild("Words", true)
return "parts=" .. #f:GetChildren() .. " bubble=" .. tostring(w and w.Text) .. " fits=" .. tostring(w and w.TextFits)
'''


def main():
    c = Client()
    c.start()
    lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", false) return ""', "Edit")
    c.call("start_stop_play", {"is_start": True})
    try:
        t0 = time.time()
        while time.time() - t0 < 90:
            s = lua(c, 'local p = game.Players:GetPlayers()[1] return tostring(p and p:GetAttribute("DataLoaded"))', "Server")
            if s == "true":
                break
            time.sleep(1.5)
        time.sleep(2.5)
        c.call("user_keyboard_input", {"actions": [{"action": "keyPress", "key_code": "Return"}], "datamodel_type": "Client"})
        time.sleep(2)
        log(lua(c, 'local R = game:GetService("ReplicatedStorage"):WaitForChild("Remotes") R:WaitForChild("ChooseFaction"):FireServer("Halo") task.wait(2.5) R:WaitForChild("ChooseClass"):FireServer("Warrior", "M") task.wait(2.5) return "picked"', "Client"))
        time.sleep(2)
        for key in ("Sorry", "Hat", "Carry"):
            log(lua(c, FIRE % (key, key), "Server"))
            time.sleep(0.6)
            shot(c, "t_%s_a" % key)
            log(key, lua(c, CHECK, "Client"))
            try:
                out = text_of(c.call("get_console_output", {}))
                log("console:", " || ".join(l for l in out.splitlines() if "DBG" in l or "Clatter" in l or "rror" in l)[-800:])
            except Exception as e:  # noqa: BLE001
                log("console err", e)
            time.sleep(0.5)
            shot(c, "t_%s_b" % key)
            time.sleep(8.5)
            log(key, "after stay", lua(c, CHECK, "Client"))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
        except Exception as e:  # noqa: BLE001
            log("stop", e)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG))


main()
