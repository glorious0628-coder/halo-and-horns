"""Choice card window photos (gameplay_plan 2-A #3, 게임성 개발 1, 2026-10-14) in the MAIN Studio (메인 반영 1 only,
HH_MAIN_STUDIO=1; own test Play with a FRESH in-memory save; no mouse / keyboard input; a phone run puts the device
emulation back to default at the end, even after an error).
Halo Warrior, the tutorial's first claim done, then:
  01_saved   DebugCommand "Card" FlowerPatch (a saved ChoiceCard card) on a calm screen
  02_picked  CardAction (1, "Good") fired from the client -> the window closes (the server's line)
  03_finisher DebugCommand "Finisher" (the King Slime's timed card: countdown)
  04_after3s the countdown 3 s later
  05_glow_good / 06_glow_evil the afterglow at my feet (Fx "Afterglow" sent from the server side for the photo: the cards'
             own afterglow is the server's to send, Config.Afterglow.From)
Usage: HH_MAIN_STUDIO=1 py tools/play_choice_card_photos.py [phone]
Out: docs/art/verification_2026-10-14/choice_card/<dev>_<name>.png, log.txt"""
import base64
import io
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "choice_card")
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
    time.sleep(1.0)
    res = c.call("screen_capture", {"capture_id": name})
    for part in res.get("content", []):
        if part.get("type") == "image":
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).convert("RGB").save(os.path.join(OUT, name + ".png"))
            note("saved " + name)
            return
    note("capture failed " + name)


SET_PHONE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
svc:SetDeviceAsync("samsung_galaxy_s22_ultra")
task.wait(0.3)
svc:SetResolutionAsync(749, 361)
task.wait(0.3)
svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ActualResolution)
return svc:GetDeviceAsync()
'''
RESTORE = r'''
local svc = game:GetService("StudioDeviceSimulatorService")
if svc:GetDeviceAsync() ~= "default" then
	pcall(function() svc:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.FitToWindow) end)
	svc:StopSimulationAsync()
end
return svc:GetDeviceAsync()
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "ClassChosen", "TutorialStep" } do table.insert(out, k .. "=" .. tostring(p:GetAttribute(k))) end
return table.concat(out, " ")
'''
FIRE = r'''
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("%s"):FireServer(%s)
return "fired %s"
'''
DEBUG = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local fn = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
if not (p and fn) then return "no player / DebugCommand" end
local ok, r = pcall(function() return fn:Invoke(p.Name, "%s", %s) end)
return "%s=" .. tostring(ok and r or ("ERR " .. tostring(r)))
'''
CLAIMED = r'''
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("TutorialStep", 99)
return "TutorialStep " .. tostring(p:GetAttribute("TutorialStep"))
'''
GLOW = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local fx = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Fx")
fx:FireAllClients("Afterglow", { UserId = p.UserId, Side = "%s", Seconds = 20, Private = false })
return "glow %s"
'''
WINDOW = r'''
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
for _, d in pg:GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("GuiObject") then return "modal " .. tostring(d.Visible) end
end
return "none"
'''


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def run(c, dev):
    if dev == "phone":
        note("device: " + lua(c, SET_PHONE, "Edit"))
    note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
    c.call("start_stop_play", {"is_start": True})
    note("loaded: " + wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
    time.sleep(15)
    note(lua(c, FIRE % ("IntroSeen", "", "IntroSeen"), "Client"))
    note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
    wait_state(c, lambda x: "Faction=Halo" in x, 20)
    note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
    note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
    note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
    time.sleep(2)
    note(lua(c, CLAIMED, "Server"))
    time.sleep(6)  # calm: the saved card waits out a fight / busy screen
    note(lua(c, DEBUG % ("Card", '"FlowerPatch"', "Card"), "Server"))
    time.sleep(2.5)
    note("window: " + lua(c, WINDOW, "Client"))
    save(c, f"{dev}_01_saved")
    note(lua(c, FIRE % ("CardAction", '1, "Good"', "CardAction"), "Client"))
    time.sleep(1.5)
    note("window: " + lua(c, WINDOW, "Client"))
    save(c, f"{dev}_02_picked")
    note(lua(c, DEBUG % ("Finisher", "nil", "Finisher"), "Server"))
    time.sleep(0.8)
    save(c, f"{dev}_03_finisher")
    time.sleep(3)
    save(c, f"{dev}_04_after3s")
    note(lua(c, FIRE % ("FinisherPick", '1, "Tickle"', "FinisherPick"), "Client"))
    time.sleep(1.5)
    note(lua(c, GLOW % ("Good", "Good"), "Server"))
    time.sleep(2.5)
    save(c, f"{dev}_05_glow_good")
    note(lua(c, GLOW % ("Evil", "Evil"), "Server"))
    time.sleep(3)
    save(c, f"{dev}_06_glow_evil")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    dev = "phone" if "phone" in sys.argv[1:] else "pc"
    c = Client()
    c.start()
    try:
        st = text_of(c.call("get_studio_state", {}))
        if "Current Studio Mode: Edit" not in st:
            sys.exit("not in Edit: " + st)
        try:
            run(c, dev)
        finally:
            try:
                c.call("start_stop_play", {"is_start": False})
                note("play stopped")
            except Exception as e:  # noqa: BLE001
                note("stop failed " + str(e))
    finally:
        if dev == "phone":
            time.sleep(3)
            note("device: " + lua(c, RESTORE, "Edit"))
        with open(os.path.join(OUT, f"log_{dev}.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
