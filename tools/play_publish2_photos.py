"""publish2 new-screen photos in the MAIN Studio (메인 반영 1, 2026-10-14; HH_MAIN_STUDIO=1 STUDIO_ID=<id>; fresh in-memory save).
Halo Warrior, tutorial claimed, then: 01 village fund card (server fires FundOpen with a sample state), 02 settings window
(OpenPanel Settings; log lists the damage-number and name-tag rows), 03 name tag without VIP crown, 04 with PassVIP (this Play
only), camera put in front of my head. Out: docs/art/verification_2026-10-14/publish2/new/"""
import os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_first_look_photos as plp  # noqa: E402
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "publish2", "new")
LOG = []
plp.OUT, plp.LOG = OUT, LOG
lua, note, save = plp.lua, plp.note, plp.save

TP = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local spot = workspace:FindFirstChild("VillageFund") and workspace.VillageFund:FindFirstChild("FundSpot_Halo")
if not spot then return "no FundSpot_Halo" end
p.Character:PivotTo(spot.CFrame * CFrame.new(0, 3, 6))
return "teleported to " .. tostring(spot.Position)
'''
FUND = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local r = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("FundOpen")
r:FireClient(p, { Faction = "Halo", Today = 1, PerDay = 3, Step = 50, Gold = 300, Can = true, Week = 1, Sum = 120,
	Goals = { Lanterns = 200, Fireworks = 600 }, Level = 0 })
return "fund fired"
'''
OPEN = r'''
game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("OpenPanel"):FireClient(game:GetService("Players"):GetPlayers()[1], "Settings")
return "settings fired"
'''
ROWS = r'''
local out = {}
for _, d in game:GetService("Players").LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" and (d:GetFullName():find("Settings") or d:GetFullName():find("Window")) then
		table.insert(out, d.Text)
	end
end
return table.concat(out, " | ")
'''
FUNDGUI = r'''
local out = {}
for _, d in game:GetService("Players").LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and (d.Text:find("Share") or d.Text:find("fund") or d.Text:find("Fund")) then table.insert(out, d:GetFullName() .. "=" .. d.Text) end
end
return #out > 0 and table.concat(out, " | ") or "no fund text"
'''
CLOSE = r'''
local g = game:GetService("Players").LocalPlayer.PlayerGui
for _, w in g:GetDescendants() do
	if w:IsA("GuiButton") and w.Visible and w.Name == "Close" then
		pcall(function() for _, c in getconnections and {} or {} do end end)
		pcall(function() w.Activated:Fire() end)
		pcall(function() w:SetAttribute("x", 1) end)
	end
end
return "close tried"
'''
VIP = r'''
local p = game:GetService("Players"):GetPlayers()[1]
p:SetAttribute("PassVIP", %s)
return "PassVIP " .. tostring(p:GetAttribute("PassVIP"))
'''
CAM = r'''
local cam = workspace.CurrentCamera
local ch = game:GetService("Players").LocalPlayer.Character
local head = ch and ch:FindFirstChild("Head")
if not head then return "no head" end
cam.CameraType = Enum.CameraType.Scriptable
local f = head.CFrame.LookVector
cam.CFrame = CFrame.lookAt(head.Position + f * 9 + Vector3.new(0, 1.5, 0), head.Position + Vector3.new(0, 1.2, 0))
local bb = head:FindFirstChild("Nametag")
local out = {}
if bb then for _, d in bb:GetDescendants() do if d:IsA("TextLabel") then table.insert(out, "'" .. d.Text .. "'") end if d.Name == "VipCrown" then table.insert(out, "crown visible=" .. tostring(d.Visible)) end end end
return "tag: " .. (bb and table.concat(out, " ") or "none")
'''
CAMBACK = 'workspace.CurrentCamera.CameraType = Enum.CameraType.Custom return "cam back"'


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
        if os.environ.get("KEEP"):
            return
        note(lua(c, TP, "Server")); time.sleep(3)
        note(lua(c, FUND, "Server")); time.sleep(3)
        note("fund gui: " + lua(c, FUNDGUI, "Client"))
        note("console: " + " || ".join(l for l in plp.text_of(c.call("get_console_output", {})).splitlines() if "und" in l or "arn" in l or "rror" in l)[:800])
        save(c, "01_village_fund")
        note(lua(c, CLOSE, "Client")); time.sleep(1)
        note(lua(c, OPEN, "Server")); time.sleep(2)
        note("settings texts: " + lua(c, ROWS, "Client")); save(c, "02_settings")
        note(lua(c, CLOSE, "Client")); time.sleep(1)
        note(lua(c, VIP % "false", "Server")); time.sleep(2)
        note(lua(c, CAM, "Client")); save(c, "03_nametag_no_vip")
        note(lua(c, VIP % "true", "Server")); time.sleep(3)
        note(lua(c, CAM, "Client")); save(c, "04_nametag_vip")
        note(lua(c, CAMBACK, "Client"))
    finally:
        try:
            if not os.environ.get("KEEP"):
                c.call("start_stop_play", {"is_start": False}); note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        with open(os.path.join(OUT, "log.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
