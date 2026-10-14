"""Test-prep screen photos (plan docs/design/gameplay_plan_2026-10-13.md §1-A, 게임성 개발 1's branch fix/test-prep-client):
the attendance board (AttendanceUI), the Shop's six cards / focus / sales off (ShopUI), the HUD private-server chip and
the Forge while it sells no weapon (A23-127). Own test Play with a FRESH in-memory save in the main Studio
(HH_MAIN_STUDIO=1, 메인 반영 1 only, after the merge + sync) or the practice Studio (default STUDIO_NAME=UiSandbox).
Halo Warrior, the tutorial claimed (TutorialStep 99). Studio's own user_mouse_input only (no desktop mouse).
Shots: 01 the board (Day 1 today), 02 after [Claim!] (Day 1 stamped, "Come back tomorrow!"), 03 the next day (DebugCommand
AttendNext: Day 2 today), 04 the week done (Days 2-7 claimed: all stamped), 05 the HUD [Menu] glow (a claim open, window
closed), 06 the Shop (six cards), 07 the Shop on the Sticker Pack ({ Focus = "Stickers" }: gold rim), 08 the Shop with
PassSales off (GameState SwitchPassSales = false: "Not on sale"), 09 the private-server chip (GameState PrivateServer =
true, a test stand-in until 게임성 개발 2 sets it), 10 the Forge with Config.WeaponShop.Buy = false (게임성 개발 2's switch;
before it is merged the script sets it on the client for the photo - if execute_luau's require is not the game's
module the log shows Buy buttons still there: retake after the server switch is merged).
Usage: py tools/play_test_prep_photos.py [outdir-name]   (HH_MAIN_STUDIO=1 for the main Studio)
Out: docs/art/verification_2026-10-13/test_prep/<outdir>/ (default sandbox / main): NN_<name>.png, log.txt"""
import base64
import io
import os
import sys
import time

if os.environ.get("HH_MAIN_STUDIO") != "1":
    os.environ.setdefault("STUDIO_NAME", "UiSandbox")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

TAG = sys.argv[1] if len(sys.argv) > 1 else ("main" if os.environ.get("HH_MAIN_STUDIO") == "1" else "sandbox")
OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-13", "test_prep", TAG)
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
            Image.open(io.BytesIO(base64.b64decode(part["data"]))).save(os.path.join(OUT, name + ".png"))
            note("saved " + name)
            return
    note("capture failed " + name)


STATE = r"""
local p = game:GetService("Players"):GetPlayers()[1]
if not p then return "no player" end
local out = {}
for _, k in { "DataLoaded", "Faction", "ClassChosen", "TutorialStep", "AttendReady", "AttendSlot", "AttendDays" } do
	table.insert(out, k .. "=" .. tostring(p:GetAttribute(k)))
end
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
local ok, r = pcall(function() return fn:Invoke(p.Name, "%s", %s) end)
return "%s=" .. tostring(ok and r or ("ERR " .. tostring(r)))
"""
OPEN = r"""
local p = game:GetService("Players"):GetPlayers()[1]
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("OpenPanel"):FireClient(p, "%s", %s)
return "open %s"
"""
CLOSE = r"""
local p = game:GetService("Players").LocalPlayer
for _, d in p:FindFirstChildOfClass("PlayerGui"):GetDescendants() do
	if d.Name == "PanelsModal" and d:IsA("Frame") then d.Visible = false end
end
return "closed"
"""
PATH = r"""
local p = game:GetService("Players").LocalPlayer
local pg = p:FindFirstChildOfClass("PlayerGui")
for _, d in pg:GetDescendants() do
	if d:IsA("GuiObject") and d.Visible and d.Name == "%s" then
		return "LocalPlayer.PlayerGui" .. string.sub(d:GetFullName(), #pg:GetFullName() + 1)
	end
end
return "none"
"""
LOOK = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local out = {}
for _, d in pg:GetDescendants() do
	if d:FindFirstAncestor("PanelsModal") and (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text ~= "" then
		table.insert(out, d.Name .. ":" .. d.Text)
	end
end
return table.concat(out, " | ")
"""
STAMPS = r"""
local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
local n = 0
for _, d in pg:GetDescendants() do
	if d.Name == "Stamp" and d:IsA("ImageLabel") and d.Visible and d:FindFirstAncestor("Board") then n += 1 end
end
return "stamps shown: " .. n
"""
GAMESTATE = r"""
local gs = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
if not gs then return "no GameState" end
gs:SetAttribute("%s", %s)
return "GameState %s = " .. tostring(gs:GetAttribute("%s"))
"""
FORGE_DROP = r"""
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
Config.WeaponShop.Buy = %s
return "client Config.WeaponShop.Buy = " .. tostring(Config.WeaponShop.Buy)
"""


def wait_state(c, cond, timeout, every=1.0):
    t0, last = time.time(), ""
    while time.time() - t0 < timeout:
        last = lua(c, STATE, "Server")
        if cond(last):
            return last
        time.sleep(every)
    return last


def click(c, name, wait=1.0):
    path = lua(c, PATH % name, "Client")
    note(f"path {name}: {path}")
    if path.startswith("LocalPlayer."):
        r = c.call("user_mouse_input", {"datamodel_type": "Client", "actions": [
            {"action": "moveTo", "instance_path": path}, {"action": "mouseButtonClick", "mouse_button": "left"}]})
        note("mouse: " + text_of(r)[:150])
        time.sleep(wait)
        return True
    return False


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
        time.sleep(20)
        note(lua(c, FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        note("chosen: " + wait_state(c, lambda x: "ClassChosen=true" in x, 20))
        note(lua(c, FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(3)
        note(lua(c, 'local p = game:GetService("Players"):GetPlayers()[1] p:SetAttribute("TutorialStep", 99) '
                    'return "TutorialStep " .. tostring(p:GetAttribute("TutorialStep"))', "Server"))
        note("state: " + wait_state(c, lambda x: "AttendReady=true" in x, 40))
        # the attendance board
        note(lua(c, OPEN % ("Attendance", "nil", "Attendance"), "Server"))
        time.sleep(2.5)
        note("board: " + lua(c, LOOK, "Client"))
        save(c, "01_attendance_today")
        click(c, "ClaimButton", wait=2.5)
        note("state: " + lua(c, STATE, "Server"))
        note("board: " + lua(c, LOOK, "Client") + " | " + lua(c, STAMPS, "Client"))
        save(c, "02_attendance_claimed")
        note(lua(c, DEBUG % ("AttendNext", "nil", "AttendNext"), "Server"))
        time.sleep(2)
        note("board: " + lua(c, LOOK, "Client"))
        save(c, "03_attendance_next_day")
        for _ in range(6):  # days 2..7 (the weekly box last)
            note(lua(c, FIRE % ("ClaimAttendance", "", "ClaimAttendance"), "Client"))
            time.sleep(1.6)
            note(lua(c, DEBUG % ("AttendNext", "nil", "AttendNext"), "Server") if _ < 5 else "last claim")
            time.sleep(1.2)
        time.sleep(1.5)
        note("state: " + lua(c, STATE, "Server"))
        note("board: " + lua(c, LOOK, "Client") + " | " + lua(c, STAMPS, "Client"))
        save(c, "04_attendance_week_done")
        note(lua(c, DEBUG % ("AttendNext", "nil", "AttendNext"), "Server"))
        note(lua(c, CLOSE, "Client"))
        time.sleep(2.5)
        save(c, "05_hud_menu_glow")
        # the Shop
        note(lua(c, OPEN % ("Shop", "nil", "Shop"), "Server"))
        time.sleep(2.5)
        note("shop: " + lua(c, LOOK, "Client"))
        save(c, "06_shop_six_cards")
        note(lua(c, OPEN % ("Shop", '{ Focus = "Stickers" }', "Shop focus"), "Server"))
        time.sleep(2)
        save(c, "07_shop_focus_stickers")
        note(lua(c, GAMESTATE % ("SwitchPassSales", "false", "SwitchPassSales", "SwitchPassSales"), "Server"))
        time.sleep(2.5)
        note("shop: " + lua(c, LOOK, "Client"))
        save(c, "08_shop_sales_off")
        note(lua(c, GAMESTATE % ("SwitchPassSales", "true", "SwitchPassSales", "SwitchPassSales"), "Server"))
        note(lua(c, CLOSE, "Client"))
        # the private-server chip (stand-in attribute)
        note(lua(c, GAMESTATE % ("PrivateServer", "true", "PrivateServer", "PrivateServer"), "Server"))
        time.sleep(1.5)
        save(c, "09_hud_private_chip")
        note(lua(c, GAMESTATE % ("PrivateServer", "nil", "PrivateServer", "PrivateServer"), "Server"))
        # the Forge while it sells no weapon (client stand-in)
        note(lua(c, FORGE_DROP % "false", "Client"))
        note(lua(c, OPEN % ("WeaponShop", "nil", "WeaponShop"), "Server"))
        time.sleep(2.5)
        note("forge: " + lua(c, LOOK, "Client"))
        save(c, "10_forge_drop_mode")
        note(lua(c, FORGE_DROP % "nil", "Client"))
        con = text_of(c.call("get_console_output", {}))
        errs = [ln for ln in con.splitlines() if any(k in ln.lower() for k in ("error", "failed", "infinite yield"))
                and "TexturePack" not in ln]
        note("console: " + "\n".join(errs[-20:]))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False})
            note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        time.sleep(2)
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
