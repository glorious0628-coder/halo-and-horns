"""publish3 photos in the MAIN Studio (메인 반영 1, 2026-10-14; HH_MAIN_STUDIO=1 STUDIO_ID=<id>; fresh in-memory save):
shop window (pass rows + subscription card; log lists the texts), Menu window (no Travel tile while not subscribed),
Halo Warrior sword held: standing back + side, and the attack moment. Out: docs/art/verification_2026-10-14/publish3/"""
import os, sys, time, io, base64
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_first_look_photos as plp  # noqa: E402
from studio_mcp import Client  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "publish3")
LOG = []
plp.OUT, plp.LOG = OUT, LOG
lua, note, save = plp.lua, plp.note, plp.save
OPEN = 'game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("OpenPanel"):FireClient(game:GetService("Players"):GetPlayers()[1], "%s") return "open %s"'
TEXTS = r'''
local out = {}
local modal = game:GetService("Players").LocalPlayer.PlayerGui.MainGui:FindFirstChild("PanelsModal")
if not modal then return "no modal" end
for _, d in modal:GetDescendants() do
	if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text ~= "" then table.insert(out, d.Text) end
end
return table.concat(out, " | ")
'''
SCROLL = r'''
for _, d in game:GetService("Players").LocalPlayer.PlayerGui.MainGui.PanelsModal:GetDescendants() do
	if d:IsA("ScrollingFrame") and d.Visible and d.AbsoluteSize.Y > 100 then d.CanvasPosition = Vector2.new(0, %d) end
end
return "scrolled"
'''
CLOSEALL = r'''
local m = game:GetService("Players").LocalPlayer.PlayerGui.MainGui:FindFirstChild("PanelsModal")
return m and tostring(m.Visible) or "no modal"
'''
GEAR = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local fn = game:GetService("ServerScriptService"):FindFirstChild("DebugCommand")
local a = fn:Invoke(p.Name, "Level", 30)
local b = fn:Invoke(p.Name, "WeaponOwnedMask", 511)
return tostring(a) .. " " .. tostring(b)
'''
CAM = r'''
local p = game:GetService("Players").LocalPlayer
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do if g:IsA("ScreenGui") then g.Enabled = false end end
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 40
local f, r = hrp.CFrame.LookVector, hrp.CFrame.RightVector
local mode = "%s"
local dir = mode == "side" and r or (mode == "back" and -f or f)
local target = hrp.Position + Vector3.new(0, 0.6, 0)
cam.CFrame = CFrame.lookAt(target + dir * 11 + Vector3.new(0, 0.6, 0), target)
return "cam " .. mode
'''
RESET = r'''
local p = game:GetService("Players").LocalPlayer
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do if g:IsA("ScreenGui") then g.Enabled = true end end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
return "reset"
'''
ANCH = 'local h = game:GetService("Players"):GetPlayers()[1].Character.HumanoidRootPart h.Anchored = %s return "anchored %s"'
HELD = r'''
local ch = game:GetService("Players"):GetPlayers()[1].Character
local wm = ch:FindFirstChild("WeaponModel") or ch:FindFirstChildOfClass("Tool")
return wm and (wm.ClassName .. " " .. wm.Name) or "no weapon"
'''


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    c = Client(); c.start()
    try:
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        note("loaded: " + plp.wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
        time.sleep(15)
        note(lua(c, plp.FIRE % ("IntroSeen", "", "IntroSeen"), "Client"))
        note(lua(c, plp.FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction"), "Client"))
        plp.wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(lua(c, plp.FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass"), "Client"))
        plp.wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        note(lua(c, plp.FIRE % ("AcceptTutorial", "", "AcceptTutorial"), "Client"))
        time.sleep(2); note(lua(c, plp.CLAIMED, "Server")); time.sleep(4)
        # 1 shop
        note(lua(c, OPEN % ("Shop", "Shop"), "Server")); time.sleep(2.5)
        note("shop texts: " + lua(c, TEXTS, "Client")); save(c, "01_shop_top")
        for i, y in enumerate((260, 520, 780)):
            note(lua(c, SCROLL % y, "Client")); time.sleep(0.8); save(c, f"01_shop_scroll{i+1}")
        # 2 menu
        note(lua(c, OPEN % ("Menu", "Menu"), "Server")); time.sleep(2.5)
        txt = lua(c, TEXTS, "Client"); note("menu texts: " + txt); note("travel in menu: " + str("Travel" in txt)); save(c, "02_menu")
        # 3 sword
        note(lua(c, OPEN % ("Menu", "Menu"), "Server"))
        note("gear: " + lua(c, GEAR, "Server")); time.sleep(2)
        note(lua(c, plp.FIRE % ("EquipWeapon", "3", "EquipWeapon"), "Client")); time.sleep(3)
        note("held: " + lua(c, HELD, "Server"))
        note(lua(c, ANCH % ("true", "on"), "Server")); time.sleep(1.2)
        note(lua(c, CAM % "back", "Client")); time.sleep(1); save(c, "03_sword_back")
        note(lua(c, CAM % "side", "Client")); time.sleep(1); save(c, "03_sword_side")
        note(lua(c, plp.FIRE % ("Swing", "", "Swing"), "Client")); time.sleep(0.25); save(c, "03_sword_attack")
        note(lua(c, RESET, "Client")); note(lua(c, ANCH % ("false", "off"), "Server"))
        con = plp.text_of(c.call("get_console_output", {}))
        errs = [l for l in con.splitlines() if any(k in l.lower() for k in ("error", "failed", "infinite yield")) and "DataStore" not in l and "publish this place" not in l]
        note("console errors: " + (" || ".join(errs[-15:]) if errs else "0"))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False}); note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
