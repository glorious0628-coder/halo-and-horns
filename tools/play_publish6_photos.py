"""publish6 photos in the MAIN Studio (메인 반영 1, 2026-10-14; HH_MAIN_STUDIO=1 STUDIO_ID=<id>; fresh in-memory save), PC or `phone`:
8  first mission 'Go to Otto's Forge' + the T1 gift at the anvil (client prompt:InputHoldBegin; the bag's gold before / after)
5  forge window (rows + texts, scrolled), 6 the joke weapons held + a swing, 1 crown bar (+ Journal event tab), 2 chips with Outlaw,
3 goose chip (DebugCommand Goose), 4 attendance 27 -> 28 days, 7 sword / staff / bow standing side view.
Out: docs/art/verification_2026-10-14/publish6/<dev>_*.png + log_<dev>.txt"""
import os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_first_look_photos as plp  # noqa: E402
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "publish6")
LOG = []
plp.OUT, plp.LOG = OUT, LOG
lua, note, save = plp.lua, plp.note, plp.save
R = 'game:GetService("ReplicatedStorage"):WaitForChild("Remotes")'
OPEN = R + ':WaitForChild("OpenPanel"):FireClient(game:GetService("Players"):GetPlayers()[1], "%s"%s) return "open %s"'
DBG = ('local p = game:GetService("Players"):GetPlayers()[1] local fn = game:GetService("ServerScriptService").DebugCommand '
       'local out = {} for _, kv in { %s } do table.insert(out, tostring(fn:Invoke(p.Name, kv[1], kv[2]))) end return table.concat(out, ",")')
TP_ANVIL = ('local p = game:GetService("Players"):GetPlayers()[1] local a = workspace.Map.Landmarks.ArtisanGuild.Anvil '
            'p.Character:PivotTo(CFrame.new(a.Position + Vector3.new(0, 4, 6))) return "anvil " .. tostring(a.Position)')
TP_FUND = ('local p = game:GetService("Players"):GetPlayers()[1] local s = workspace.VillageFund.FundSpot_Halo '
           'p.Character:PivotTo(s.CFrame * CFrame.new(0, 3, 14)) return "plaza"')
POS = ('local p = game:GetService("Players"):GetPlayers()[1] local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart") '
       'return h and tostring(h.Position) or "no root"')
TEXTS = r'''
local out = {}
local modal = game:GetService("Players").LocalPlayer.PlayerGui.MainGui:FindFirstChild("PanelsModal")
if not modal or not modal.Visible then return "no modal visible" end
for _, d in modal:GetDescendants() do if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Visible and d.Text ~= "" then table.insert(out, d.Text) end end
return table.concat(out, " | ")
'''
HIDE = ('local m = game:GetService("Players").LocalPlayer.PlayerGui.MainGui:FindFirstChild("PanelsModal") '
        'if m then m.Visible = false end return "modal hidden"')
SCROLL = r'''
local best
for _, d in game:GetService("Players").LocalPlayer.PlayerGui.MainGui.PanelsModal:GetDescendants() do
  if d:IsA("ScrollingFrame") and d.Visible and d.AbsoluteSize.Y > 100 and (not best or d.AbsoluteSize.Y > best.AbsoluteSize.Y) then best = d end
end
if not best then return "no scroll" end
best.CanvasPosition = Vector2.new(0, %d)
return "scroll %d canvas " .. math.floor(best.AbsoluteCanvasSize.Y) .. " win " .. math.floor(best.AbsoluteSize.Y)
'''
PROMPT = r'''
local pl = game:GetService("Players").LocalPlayer
local a = workspace.Map.Landmarks.ArtisanGuild.Anvil
local pr = a:FindFirstChild("HHC_BlacksmithPrompt")
if not pr then return "no prompt" end
pr:InputHoldBegin()
task.wait(0.1)
pr:InputHoldEnd()
return "prompt used enabled=" .. tostring(pr.Enabled)
'''
CHIPS = r'''
local out = {}
for _, d in game:GetService("Players").LocalPlayer.PlayerGui.MainGui:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" and d.AbsolutePosition.Y < 260 and d.AbsolutePosition.X > 150 and d.AbsolutePosition.X < 900 then
		table.insert(out, d.Name .. "='" .. d.Text .. "'")
	end
end
return table.concat(out, " | ")
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local wm = p.Character and p.Character:FindFirstChild("WeaponModel")
local d = {}
if wm then for _, x in wm:GetDescendants() do if x:IsA("BasePart") then table.insert(d, x.Name) end end end
return string.format("Class=%s WeaponTier=%s Mask=%s weapon=%s parts=%s", tostring(p:GetAttribute("Class")), tostring(p:GetAttribute("WeaponTier")), tostring(p:GetAttribute("WeaponOwnedMask")), wm and wm.ClassName or "none", table.concat(d, ","))
'''
CAM = r'''
local p = game:GetService("Players").LocalPlayer
local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
if not hrp then return "no char" end
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do if g:IsA("ScreenGui") then g.Enabled = false end end
local cam = workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 40
local target = hrp.Position + Vector3.new(0, 0.6, 0)
cam.CFrame = CFrame.lookAt(target + hrp.CFrame.RightVector * 11 + Vector3.new(0, 0.6, 0), target)
return "cam side"
'''
RESET = r'''
local p = game:GetService("Players").LocalPlayer
for _, g in p:FindFirstChildOfClass("PlayerGui"):GetChildren() do if g:IsA("ScreenGui") then g.Enabled = true end end
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
return "reset"
'''
ANCH = 'local h = game:GetService("Players"):GetPlayers()[1].Character.HumanoidRootPart h.Anchored = %s return "anchored %s"'


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    dev = "phone" if "phone" in sys.argv[1:] else "pc"
    c = Client(); c.start()
    S = lambda code: lua(c, code, "Server")
    C = lambda code: lua(c, code, "Client")
    FIRE = lambda name: C(R + f':WaitForChild("{name}"):FireServer() return "fired {name}"')
    try:
        if dev == "phone":
            note("device: " + lua(c, plp.SET_PHONE, "Edit"))
        note(lua(c, 'game:GetService("ServerStorage"):SetAttribute("StudioFreshSave", true) return "fresh on"', "Edit"))
        c.call("start_stop_play", {"is_start": True})
        note("loaded: " + plp.wait_state(c, lambda x: "DataLoaded=true" in x, 90, 2.0))
        time.sleep(15)
        note(C(plp.FIRE % ("IntroSeen", "", "IntroSeen")))
        note(C(plp.FIRE % ("ChooseFaction", '"Halo"', "ChooseFaction")))
        plp.wait_state(c, lambda x: "Faction=Halo" in x, 20)
        note(C(plp.FIRE % ("ChooseClass", '"Warrior", "M"', "ChooseClass")))
        plp.wait_state(c, lambda x: "ClassChosen=true" in x, 20)
        note(C(plp.FIRE % ("AcceptTutorial", "", "AcceptTutorial")))
        time.sleep(6)
        # 8: first mission + the T1 gift
        save(c, f"{dev}_08a_first_mission")
        note(S(OPEN % ("Bag", "", "Bag"))); time.sleep(2.5); note("bag before gift: " + C(TEXTS)); save(c, f"{dev}_08b_bag_before"); note(C(HIDE))
        note(S(TP_ANVIL)); time.sleep(3); note("pos: " + S(POS)); note(C(PROMPT)); time.sleep(3)
        note(S(STATE))
        note(S(OPEN % ("Bag", "", "Bag"))); time.sleep(2.5); note("bag after gift: " + C(TEXTS)); save(c, f"{dev}_08c_bag_after"); note(C(HIDE))
        # 5: forge window
        note("gear: " + S(DBG % '{ "Level", 30 }, { "Gold", 5000 }, { "Item", "Herb:5" }'))
        note(S(OPEN % ("WeaponShop", "", "WeaponShop"))); time.sleep(3)
        note("forge texts: " + C(TEXTS)); save(c, f"{dev}_05a_forge_top")
        for i, y in enumerate((300, 99999)):
            note(C(SCROLL % (y, y))); time.sleep(1); save(c, f"{dev}_05{'bc'[i]}_forge_scroll")
        note("forge texts after scroll: " + C(TEXTS))
        for tier in (10, 11):
            note(C(R + f':WaitForChild("UpgradeWeapon"):FireServer({tier}) return "buy {tier}"')); time.sleep(1.5)
        note(S(STATE)); note(C(HIDE))
        # 1-4: HUD things at the plaza
        note(S(TP_FUND)); time.sleep(5)
        note("chips: " + C(CHIPS)); save(c, f"{dev}_01_crown_bar")
        note(S(OPEN % ("Journal", ', { Tab = "Event" }', "Journal event"))); time.sleep(2.5); note("event tab: " + C(TEXTS)); save(c, f"{dev}_01b_event_tab"); note(C(HIDE)); time.sleep(0.5)
        note(S('game:GetService("Players"):GetPlayers()[1]:SetAttribute("Outlaw", true) return "outlaw on"')); time.sleep(3)
        note("chips outlaw: " + C(CHIPS)); save(c, f"{dev}_02_chips_outlaw")
        note(S('game:GetService("Players"):GetPlayers()[1]:SetAttribute("Outlaw", false) return "outlaw off"'))
        note("goose: " + S(DBG % '{ "Goose", 1 }')); time.sleep(4)
        note("chips goose: " + C(CHIPS)); save(c, f"{dev}_03_goose_chip")
        for d in (27, 28):
            note(S(f'local p = game:GetService("Players"):GetPlayers()[1] p:SetAttribute("AttendDays", {d}) p:SetAttribute("AttendReady", true) return "days {d}"'))
            time.sleep(1); note(S(OPEN % ("Attendance", "", "Attendance"))); time.sleep(3)
            note(f"attendance {d}: " + C(TEXTS)); save(c, f"{dev}_04_attendance{d}"); note(C(HIDE)); time.sleep(0.5)
        # 6: joke weapons
        for tier, nm in ((10, "pan"), (11, "chicken")):
            note(C(R + f':WaitForChild("EquipWeapon"):FireServer({tier}) return "eq {tier}"')); time.sleep(3)
            note(S(STATE)); save(c, f"{dev}_06_{nm}_hold")
            note(FIRE("Swing")); time.sleep(0.2); save(c, f"{dev}_06_{nm}_swing")
        # 7: sword / staff / bow standing side view
        note(S(DBG % '{ "WeaponOwnedMask", 511 }'))
        for cls, nm in (("Warrior", "sword"), ("Mage", "staff"), ("Archer", "bow")):
            note(f"class {cls}: " + S(DBG % f'{{ "Class", "{cls}" }}')); time.sleep(3)
            note(C(R + ':WaitForChild("EquipWeapon"):FireServer(3) return "eq 3"')); time.sleep(3)
            note(S(STATE)); note(S(ANCH % ("true", "on"))); time.sleep(1.2)
            note(C(CAM)); time.sleep(1); save(c, f"{dev}_07_{nm}_side")
            note(C(RESET)); note(S(ANCH % ("false", "off"))); time.sleep(1)
        con = plp.text_of(c.call("get_console_output", {}))
        errs = [l for l in con.splitlines() if any(k in l.lower() for k in ("error", "failed", "infinite yield"))
                and "DataStore" not in l and "publish this place" not in l]
        note("console errors: " + (" || ".join(errs[-15:]) if errs else "0"))
    finally:
        try:
            c.call("start_stop_play", {"is_start": False}); note("play stopped")
        except Exception as e:  # noqa: BLE001
            note("stop failed " + str(e))
        if dev == "phone":
            time.sleep(3); note("device: " + lua(c, plp.RESTORE, "Edit"))
        with open(os.path.join(OUT, f"log_{dev}.txt"), "w", encoding="utf-8") as f:
            f.write("\n".join(LOG) + "\n")


if __name__ == "__main__":
    main()
