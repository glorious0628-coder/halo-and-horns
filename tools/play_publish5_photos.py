"""publish5 photos in the MAIN Studio (메인 반영 1, 2026-10-14; HH_MAIN_STUDIO=1 STUDIO_ID=<id>; fresh in-memory save), PC or `phone`:
forge window (rows + texts), buy the joke weapons (UpgradeWeapon 10 / 11 at the anvil), bag at the anvil with a gathered
material, village fund card (step = Config ladder[1]), the joke weapons held (follow camera + a swing), quest line S1 folding
(GameState.GooseNextAt), goal chip. Out: docs/art/verification_2026-10-14/publish5/<dev>_*.png + log_<dev>.txt"""
import os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import play_first_look_photos as plp  # noqa: E402
from studio_mcp import Client  # noqa: E402

OUT = os.path.join(ROOT, "docs", "art", "verification_2026-10-14", "publish5")
LOG = []
plp.OUT, plp.LOG = OUT, LOG
lua, note, save = plp.lua, plp.note, plp.save
R = 'game:GetService("ReplicatedStorage"):WaitForChild("Remotes")'
OPEN = R + ':WaitForChild("OpenPanel"):FireClient(game:GetService("Players"):GetPlayers()[1], "%s") return "open %s"'
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
FUND = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local step = Config.VillageFund.Ladder and Config.VillageFund.Ladder[1] or Config.VillageFund.Step
game:GetService("ReplicatedStorage").Remotes.FundOpen:FireClient(p, { Faction = "Halo", Today = 0, PerDay = 3, Step = step, Gold = 5000, Can = true,
	Week = 1, Sum = 0, Goals = { Lanterns = Config.VillageFund.Goals.Lanterns, Fireworks = Config.VillageFund.Goals.Fireworks }, Level = 0 })
return "fund fired step=" .. tostring(step) .. " goals " .. tostring(Config.VillageFund.Goals.Lanterns)
'''
GS = ('local gs = game:GetService("ReplicatedStorage"):FindFirstChild("GameState") if not gs then return "no GameState" end '
      'gs:SetAttribute("GooseActive", false) gs:SetAttribute("GooseNextAt", os.time() + %d) '
      'return "GooseNextAt +%d active=" .. tostring(gs:GetAttribute("GooseActive"))')
QLINES = r'''
local out = {}
for _, d in game:GetService("Players").LocalPlayer.PlayerGui.MainGui:GetDescendants() do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" and (d.Text:find("Goose") or d.Text:find("goose") or d.Text:find("Golden")) then table.insert(out, d.Name .. "='" .. d.Text .. "'") end
end
return #out > 0 and table.concat(out, " | ") or "no goose text"
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
local wm = p.Character and p.Character:FindFirstChild("WeaponModel")
local d = {}
if wm then for _, x in wm:GetDescendants() do if x:IsA("BasePart") then table.insert(d, x.Name) end end end
return string.format("WeaponTier=%s Mask=%s weapon=%s parts=%s", tostring(p:GetAttribute("WeaponTier")), tostring(p:GetAttribute("WeaponOwnedMask")), wm and wm.ClassName or "none", table.concat(d, ","))
'''


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
        save(c, f"{dev}_01_hud_lv1")
        note("S1: " + S(DBG % '{ "StorySub", "S1" }')); time.sleep(2)
        note(S(GS % (7200, 7200))); time.sleep(3.5); note("far: " + C(QLINES)); save(c, f"{dev}_02_goose_line_far")
        note(S(GS % (600, 600))); time.sleep(3.5); note("near: " + C(QLINES)); save(c, f"{dev}_03_goose_line_near")
        note("gear: " + S(DBG % '{ "Level", 30 }, { "Gold", 5000 }, { "Item", "Herb:5" }'))
        note(S(TP_ANVIL)); time.sleep(2.5); note("pos: " + S(POS))
        note(S(OPEN % ("WeaponShop", "WeaponShop"))); time.sleep(3)
        note("forge texts: " + C(TEXTS)); save(c, f"{dev}_04_forge")
        note(C(R + ':WaitForChild("UpgradeWeapon"):FireServer(10) return "buy 10"')); time.sleep(1.5)
        note(C(R + ':WaitForChild("UpgradeWeapon"):FireServer(11) return "buy 11"')); time.sleep(2)
        note(S(STATE))
        note(S(OPEN % ("Bag", "Bag"))); time.sleep(3)
        note("bag at anvil: " + C(TEXTS)); save(c, f"{dev}_05_bag_anvil")
        note(C(HIDE))
        note(S(TP_FUND)); time.sleep(5); note("pos: " + S(POS))
        note(S(OPEN % ("Bag", "Bag"))); time.sleep(2.5)
        note("bag away: " + C(TEXTS)); save(c, f"{dev}_06_bag_away"); note(C(HIDE)); time.sleep(0.5)
        note(S(FUND)); time.sleep(3); note("fund texts: " + C(TEXTS)); save(c, f"{dev}_07_fund"); note(C(HIDE)); time.sleep(0.5)
        for tier, nm in ((10, "pan"), (11, "chicken")):
            note(C(R + f':WaitForChild("EquipWeapon"):FireServer({tier}) return "eq {tier}"')); time.sleep(3)
            note(S(STATE)); save(c, f"{dev}_08_{nm}_hold")
            note(C(R + ':WaitForChild("Swing"):FireServer() return "swing"')); time.sleep(0.2); save(c, f"{dev}_09_{nm}_swing")
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
