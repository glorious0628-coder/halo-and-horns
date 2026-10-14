"""publish7 photos (top HUD, Outlaw chip, benches, joke weapon look) in the MAIN Studio (메인 반영 1, 2026-10-14; HH_MAIN_STUDIO=1 STUDIO_ID=<id>; fresh in-memory save), PC or `phone`:
8  first mission 'Go to Otto's Forge' + the T1 gift at the anvil (client prompt:InputHoldBegin; the bag's gold before / after)
5  forge window (rows + texts, scrolled), 6 the joke weapons held + a swing, 1 crown bar (+ Journal event tab), 2 chips with Outlaw,
3 goose chip (DebugCommand Goose), 4 attendance 27 -> 28 days, 7 sword / staff / bow standing side view.
Out: docs/art/verification_2026-10-14/publish7/<dev>_*.png + log_<dev>.txt"""
import os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_first_look_photos as plp  # noqa: E402
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "publish7")
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


BENCH = r'''
local out = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and game:GetService("CollectionService"):HasTag(d, "CraftStation") then
		table.insert(out, d.Name .. " role=" .. tostring(d:GetAttribute("Role")) .. " pos=" .. tostring(d.Position))
	end
end
return #out .. " stations: " .. table.concat(out, " | ")
'''
MEME = r'''
local ch = game:GetService("Players").LocalPlayer.Character
local wm = ch and (ch:FindFirstChild("WeaponModel") or ch:FindFirstChildOfClass("Tool"))
if not wm then return "no weapon" end
local out = { wm.ClassName .. ":" .. wm.Name .. " Meme=" .. tostring(wm:GetAttribute("Meme")) }
for _, c in wm:GetChildren() do
	local extra = ""
	if c:IsA("BasePart") then extra = " LTM=" .. tostring(c.LocalTransparencyModifier) .. " Transp=" .. tostring(c.Transparency) end
	table.insert(out, "  " .. c.ClassName .. ":" .. c.Name .. extra)
	if c.Name == "MemeLook" then for _, d in c:GetDescendants() do if d:IsA("BasePart") then table.insert(out, "    look " .. d.ClassName .. ":" .. d.Name .. " " .. tostring(d.Size)) end end end
end
return table.concat(out, " ; ")
'''
TP_BENCH = ('local p = game:GetService("Players"):GetPlayers()[1] local a = workspace.Map.Landmarks.ArtisanGuild.Anvil '
            'p.Character:PivotTo(CFrame.new(a.Position + Vector3.new(0, 4, 14))) return "yard"')


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    os.makedirs(OUT, exist_ok=True)
    dev = "phone" if "phone" in sys.argv[1:] else "pc"
    c = Client(); c.start()
    S = lambda code: lua(c, code, "Server")
    C = lambda code: lua(c, code, "Client")
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
        time.sleep(2); note(S(plp.CLAIMED)); time.sleep(5)
        note("chips: " + C(CHIPS)); save(c, f"{dev}_01_top_hud")
        note(S('game:GetService("Players"):GetPlayers()[1]:SetAttribute("Outlaw", true) return "outlaw on"')); time.sleep(3)
        note("chips outlaw: " + C(CHIPS)); save(c, f"{dev}_02_outlaw")
        note(S('game:GetService("Players"):GetPlayers()[1]:SetAttribute("Outlaw", false) return "outlaw off"'))
        note("gear: " + S(DBG % '{ "Level", 30 }, { "Gold", 5000 }'))
        note(S(TP_BENCH)); time.sleep(4); note("pos: " + S(POS)); note("benches (server): " + S(BENCH)); save(c, f"{dev}_05_benches")
        note(S(TP_ANVIL)); time.sleep(3)
        note(C(R + ':WaitForChild("UpgradeWeapon"):FireServer(10) return "buy 10"')); time.sleep(2)
        note(S(TP_FUND)); time.sleep(6); note("pos plaza: " + S(POS))
        note(C(R + ':WaitForChild("EquipWeapon"):FireServer(10) return "eq 10"')); time.sleep(3.5)
        note("meme model: " + C(MEME)); note(S(STATE)); save(c, f"{dev}_08_pan_hold")
        note(S(ANCH % ("true", "on"))); time.sleep(1.2); note(C(CAM)); time.sleep(1); save(c, f"{dev}_08_pan_side"); note(C(RESET)); note(S(ANCH % ("false", "off"))); time.sleep(1)
        note(C(R + ':WaitForChild("Swing"):FireServer() return "swing"')); time.sleep(0.25); save(c, f"{dev}_08_pan_swing")
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
            f.write(chr(10).join(LOG) + chr(10))


if __name__ == "__main__":
    main()
