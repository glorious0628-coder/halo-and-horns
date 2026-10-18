"""9판 follow-ups in MY test Studio (STUDIO_ID = PhoneTest_1015), one fresh Play (code: main + dev1-codex-next +
dev1-r9-small). Server changes only through the game's DebugCommand (the MCP context has its own module copies).
E  codex [Go]: open the Codex, the woods tab (Goblin not met) -> [Go] -> the window closes, the quest marker leads
   (shown, its distance) -> stand by a goblin -> the lead ends (the marker back to the quest / gone)
F  KO screen: the first King's one hit (FirstKO "first") -> the KO screen: CauseRow = [head][words], positions + photo
G  rematch King: a potion in slot 1, my King out (FirstKO "retry"), my HP set to 35% -> the slot's KOGlow rim appears once
D  the staff vs the head again (check1018 part D) with the 12-degree tilt
Usage: STUDIO_ID=... py check1019.py [E] [F] [G] [D]   (default all)"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME, click  # noqa: E402
import tune1016 as T1  # noqa: E402
import check1018 as K18  # noqa: E402
from press1017b import SLOTN  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-18", "r9_checks")
os.makedirs(OUT, exist_ok=True)
CH1 = ["M1_1", "M1_2", "M1_3", "M1_4"]
MEADOW = "local p = game.Players:GetPlayers()[1] local g = workspace:Raycast(Vector3.new(%d, 300, %d), Vector3.new(0, -600, 0)) " \
         "local y = g and g.Position.Y + 3 or 5 p.Character:PivotTo(CFrame.new(%d, y, %d)) return 'y=' .. y"
FIND_BTN = '''for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do if d:IsA("GuiButton") and d.Visible and %s then return d:GetFullName() end end return "none"'''
MARK = r'''
local gui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("QuestMarkerGui")
local mk = gui and gui:FindFirstChild("QuestMarker", true)
local out = { "marker=" .. tostring(mk and mk.Visible) }
local dist = mk and mk:FindFirstChild("Distance", true)
if dist then table.insert(out, "dist='" .. tostring(dist.Text) .. "'") end
local panel = game.Players.LocalPlayer.PlayerGui:FindFirstChild("PanelsModal", true)
table.insert(out, "panel=" .. tostring(panel and panel.Visible))
return table.concat(out, " ")
'''
NEAREST_GOBLIN = r'''
local me = game.Players:GetPlayers()[1]
local best, bd = nil, math.huge
for _, m in workspace.Monsters:GetChildren() do
	if (m:GetAttribute("MonsterKind") or m.Name) == "Goblin" and m:GetAttribute("OwnerUserId") == nil then
		local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		if r then
			local d = (r.Position - me.Character:GetPivot().Position).Magnitude
			if d < bd then best, bd = r, d end
		end
	end
end
if not best then return "no goblin" end
me.Character:PivotTo(CFrame.new(best.Position + Vector3.new(8, 2, 0)))
return string.format("by a goblin (was %.0f studs)", bd)
'''
KO_ROW = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local row = pg:FindFirstChild("CauseRow", true)
if not row then
	local c = pg:FindFirstChild("Cause", true)
	return "no CauseRow; cause='" .. tostring(c and c.Text) .. "'"
end
local icon, words = row:FindFirstChild("CauseIcon"), row:FindFirstChild("Cause")
return string.format("row x=%d w=%d | icon x=%d..%d | words x=%d..%d '%s'", row.AbsolutePosition.X, row.AbsoluteSize.X,
	icon and icon.AbsolutePosition.X or -1, icon and icon.AbsolutePosition.X + icon.AbsoluteSize.X or -1,
	words and words.AbsolutePosition.X or -1, words and words.AbsolutePosition.X + words.AbsoluteSize.X or -1, words and words.Text or "")
'''
GLOW = r'''
local b = nil
for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("GuiButton") and d:GetAttribute("QuickSlot") == 1 then b = d end
end
local rim = b and b:FindFirstChild("KOGlow")
local ch = game.Players.LocalPlayer.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
return string.format("hp=%.0f/%.0f glow=%s rimT=%s slots=%s potions=%s", hum and hum.Health or -1, hum and hum.MaxHealth or -1,
	tostring(rim ~= nil and rim.Enabled), tostring(rim and string.format("%.2f", rim.Transparency)),
	tostring(game.Players.LocalPlayer:GetAttribute("QuickSlots")), tostring(game.Players.LocalPlayer:GetAttribute("HPPotionCount")))
'''
SET_HP = '''local h = game.Players:GetPlayers()[1].Character:FindFirstChildOfClass("Humanoid") h.Health = h.MaxHealth * %s return string.format("hp %.0f/%.0f", h.Health, h.MaxHealth)'''


def part_e(c):
    log("E", scene(c, {"Faction": "Halo", "Class": "Archer", "Level": 12, "Tutorial": "Done", "Done": CH1, "At": "Zone:Crossroads"}))
    time.sleep(3)
    close(c)
    log("  open:", lua(c, 'game.ReplicatedStorage.Remotes.OpenPanel:FireClient(game.Players:GetPlayers()[1], "Codex") return "sent"', "Server"))
    time.sleep(1.5)
    tab = lua(c, FIND_BTN % '(d.Text == "Goblin Woods" or (d:FindFirstChildWhichIsA("TextLabel") and d:FindFirstChildWhichIsA("TextLabel").Text == "Goblin Woods"))', "Client")
    log("  woods tab:", tab)
    if tab != "none":
        click(c, tab)
        time.sleep(0.8)
    go = lua(c, FIND_BTN % 'd.Name == "Go"', "Client")
    log("  [Go]:", go)
    shot(c, os.path.join(OUT, "E_codex_go.png"))
    log("  before:", lua(c, MARK, "Client"))
    if go != "none":
        click(c, go)
        time.sleep(1.2)
        log("  after [Go] (Crossroads -> woods trip):", lua(c, MARK, "Client"))
        shot(c, os.path.join(OUT, "E_lead_trip.png"))
        log("  to the woods:", scene(c, {"At": "Zone:GoblinWoods"}))
        time.sleep(3)
        log("  in the woods:", lua(c, MARK, "Client"))
        shot(c, os.path.join(OUT, "E_lead_goblin.png"))
        log("  ", lua(c, NEAREST_GOBLIN, "Server"))
        time.sleep(1.5)
        log("  by a goblin:", lua(c, MARK, "Client"))
        shot(c, os.path.join(OUT, "E_lead_end.png"))


def part_f(c):
    log("F", scene(c, {"Faction": "Halo", "Class": "Warrior", "Level": 3, "Tutorial": "Done", "Done": ["M1_1"], "Main": "M1_2:1",
                       "At": "Zone:SlimeMeadow"}))
    time.sleep(2)
    close(c)
    log("  ", lua(c, MEADOW % (390, -110, 390, -110), "Server"))
    log("  first King:", debug(c, "FirstKO", "first"))
    for i in range(25):
        time.sleep(1)
        r = lua(c, KO_ROW, "Client")
        if "row x=" in r or "cause='K" in r:
            log(f"  KO after {i + 1} s:", r)
            time.sleep(0.5)
            shot(c, os.path.join(OUT, "F_ko_screen.png"))
            break
    else:
        log("  no KO screen:", r)
    log("  FirstKO off:", debug(c, "FirstKO", "off"))
    time.sleep(6)


def part_g(c):
    log("G", scene(c, {"Faction": "Halo", "Class": "Warrior", "Level": 6, "Tutorial": "Done", "Done": ["M1_1"], "Main": "M1_2:6",
                       "At": "Zone:Crossroads"}))
    time.sleep(3)
    close(c)
    log("  potions:", debug(c, "HPPotionCount", 3))
    time.sleep(1)
    slot1 = lua(c, SLOTN % 1, "Client")
    if slot1 != "none":
        click(c, slot1)
        time.sleep(1.2)
        q1 = lua(c, FIND_BTN % 'd.Name == "Quick1"', "Client")
        if q1 != "none":
            click(c, q1)
            time.sleep(1.0)
    close(c)
    log("  slot:", lua(c, GLOW, "Client"))
    log("  ", scene(c, {"At": "Zone:SlimeMeadow"}))
    time.sleep(2)
    log("  ", lua(c, MEADOW % (390, -110, 390, -110), "Server"))
    log("  my King:", debug(c, "FirstKO", "retry"))
    time.sleep(5)
    log("  kings:", lua(c, K18.KINGS, "Client"))
    log("  HP 60%:", lua(c, SET_HP % "0.6", "Server"))
    time.sleep(0.6)
    log("  at 60%:", lua(c, GLOW, "Client"))
    log("  HP 35%:", lua(c, SET_HP % "0.35", "Server"))
    time.sleep(0.4)
    log("  at 35%:", lua(c, GLOW, "Client"))
    shot(c, os.path.join(OUT, "G_king_glow.png"))
    time.sleep(2.0)
    log("  HP 30% again:", lua(c, SET_HP % "0.3", "Server"))
    time.sleep(0.5)
    log("  second time (no new glow; the rim faded):", lua(c, GLOW, "Client"))
    log("  FirstKO off:", debug(c, "FirstKO", "off"))


def main():
    want = [a for a in sys.argv[1:] if a in ("D", "E", "F", "G")] or ["E", "F", "G", "D"]
    c = Client()
    c.start()
    start_play(c)
    log("pick:", pick(c, "Halo", "Warrior"))
    try:
        log(lua(c, T1.CAM, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        for p in want:
            try:
                {"D": K18.part_d, "E": part_e, "F": part_f, "G": part_g}[p](c)
            except Exception as e:  # noqa: BLE001
                log("  failed", p, str(e)[:300])
    finally:
        save_log(os.path.join(OUT, "log.txt"))
        lua(c, T1.CAM_OFF, "Client")
        stop_play(c)


if __name__ == "__main__":
    main()
