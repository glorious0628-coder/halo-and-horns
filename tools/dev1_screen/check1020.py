"""④ 화면 판 (10/20) in MY test Studio (STUDIO_ID = PhoneTest_1015), one fresh Play. Code = local commit 31047ade in
../wt_dev1base1020 = main 589e4e34 + dev1-dialog-box 59b8a80d + dev1-codex-next 459a37ea + dev1-detail-1 b8259b1b +
dev1-water-hand c02d2925 (sync from there). Server changes only through DebugCommand / plain instances.
A  dialog box (A23-229): new save -> guide Talk -> the box (face, name, line, [Next] / [Bye]) -> Next .. [I'm In!] ->
   teacher Talk -> the box -> Ok. Values + photos.
E  codex [Go] (check1019 part E)
S  A23-232: Halo / Horns warrior idle 7 s -> no hip weld, the right grip on, the handle by the hand + side photos
W  A23-231: a water block (Terrain FillBlock, Play only) -> warrior in it: Swimming, every weapon part hidden, F = no Swing
   on the server (F on land = 1 Swing) -> out: back. Archer: the bow on the back, in / out of the water, its string hidden
P  r11 ② / #8: a potion in quick slot 1, HP 50% -> key 1 drinks -> key 1 again in the cooldown: the slot shakes (RefuseBase /
   the red rim seen), the count unchanged
Usage: STUDIO_ID=... py check1020.py [A] [E] [S] [W] [P]   (default all)"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import (Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME, click,  # noqa: E402
                   GO_TO, NPC_STATE, console_errors)
import tune1016 as T1  # noqa: E402
import check1019 as K19  # noqa: E402
from press1017b import SLOTN  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-20", "screen_1020")
os.makedirs(OUT, exist_ok=True)
K19.OUT = OUT  # part E's photos here too
CH1 = ["M1_1", "M1_2", "M1_3", "M1_4"]
FIND_BTN = K19.FIND_BTN

BOX = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local box = pg:FindFirstChild("DialogBox", true)
if not box then return "box=none" end
local function vis(n)
	local x = box:FindFirstChild(n, true)
	if not (x and x:IsA("GuiObject")) then return "none" end
	local v, y = true, x
	while y and y ~= box do if y:IsA("GuiObject") and not y.Visible then v = false break end y = y.Parent end
	return v and x:GetFullName() or "hidden"
end
local face = box:FindFirstChild("Face", true)
local kind = "none"
if face then
	kind = face.ClassName
	if face:FindFirstChildWhichIsA("ViewportFrame", true) then kind = kind .. "+Viewport" end
	if face:FindFirstChildWhichIsA("ImageLabel", true) then kind = kind .. "+Image" end
end
local name, line = box:FindFirstChild("SpeakerName", true), box:FindFirstChild("Line", true)
return string.format("box=%s at=(%d,%d) size=(%d,%d) face=%s name='%s' line='%s' next=%s bye=%s ok=%s im=%s accept=%s",
	tostring(box.Visible), box.AbsolutePosition.X, box.AbsolutePosition.Y, box.AbsoluteSize.X, box.AbsoluteSize.Y, kind,
	name and name.Text or "?", line and string.sub(line.Text, 1, 70) or "?", vis("DialogNext"), vis("DialogBye"),
	vis("StoryOk"), vis("WelcomeNext"), vis("OfferAccept"))
'''
STATE = r'''
local p = game:GetService("Players"):GetPlayers()[1]
return "step=" .. tostring(p:GetAttribute("TutorialStep")) .. " faction=" .. tostring(p:GetAttribute("Faction"))
'''
WSTATE = r'''
local p = game.Players.LocalPlayer
local ch = p.Character
local hum = ch and ch:FindFirstChildOfClass("Humanoid")
local tool = ch and ch:FindFirstChild("WeaponModel")
local parts, hidden, fx, on, str = 0, 0, 0, 0, ""
for _, d in tool and tool:GetDescendants() or {} do
	if d:IsA("BasePart") then
		parts += 1
		if d.LocalTransparencyModifier >= 0.99 then hidden += 1 end
	elseif d:IsA("Beam") or d:IsA("Light") or d:IsA("ParticleEmitter") then
		fx += 1
		if d.Enabled then on += 1 end
		if d:IsA("Beam") and d.Parent and d.Parent.Name == "String" then str = str .. (d.Enabled and "1" or "0") end
	end
end
local h = tool and tool:FindFirstChild("Handle")
local stow = h and h:FindFirstChild("StowWeld")
local hand = ch and ch:FindFirstChild("RightHand")
local grip = hand and hand:FindFirstChild("RightGrip")
return string.format("state=%s kind=%s parts=%d hidden=%d fx=%d on=%d string=%s stow=%s(%s) grip=%s handToHandle=%.2f",
	hum and hum:GetState().Name or "?", tostring(tool and tool:GetAttribute("Kind")), parts, hidden, fx, on, str,
	tostring(stow and stow.Enabled), tostring(stow and stow.Part0 and stow.Part0.Name), tostring(grip and grip.Enabled),
	(h and hand) and (h.Position - hand.Position).Magnitude or -1)
'''
SWING_HOOK = r'''
local ss = game:GetService("ServerStorage")
ss:SetAttribute("Dev1SwingN", ss:GetAttribute("Dev1SwingN") or 0)
if not ss:GetAttribute("Dev1SwingHooked") then
	local r = game.ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Swing")
	if not r then return "no Swing remote" end
	r.OnServerEvent:Connect(function() ss:SetAttribute("Dev1SwingN", (ss:GetAttribute("Dev1SwingN") or 0) + 1) end)
	ss:SetAttribute("Dev1SwingHooked", true)
end
return "swings=" .. tostring(ss:GetAttribute("Dev1SwingN"))
'''
WATER = r'''
local p = game.Players:GetPlayers()[1]
local x, z = %d, %d
local g = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0))
local y = g and g.Position.Y or 0
workspace.Terrain:FillBlock(CFrame.new(x, y + 7, z), Vector3.new(48, 14, 48), Enum.Material.Water)
workspace:SetAttribute("Dev1WaterY", y)
return string.format("water at (%%d,%%.1f,%%d) ground %%s", x, y + 7, z, g and g.Instance:GetFullName() or "none")
'''
INTO = r'''
local p = game.Players:GetPlayers()[1]
local y = workspace:GetAttribute("Dev1WaterY") or 0
p.Character:PivotTo(CFrame.new(%d, y + 7, %d))
return "in"
'''
OUT_OF = r'''
local p = game.Players:GetPlayers()[1]
local x, z = %d, %d
local g = workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0))
p.Character:PivotTo(CFrame.new(x, (g and g.Position.Y or 0) + 4, z))
return "out on " .. (g and g.Material.Name or "?")
'''
SET_HP = K19.SET_HP
QPROBE = r'''
local b = nil
for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("GuiButton") and d.Visible and d:GetAttribute("QuickSlot") == 1 then b = d end
end
if not b then return "no slot 1" end
b:SetAttribute("Dev1Probe", "armed")
task.spawn(function()
	local t0, shook, red, maxd = os.clock(), false, false, 0
	local x0 = b.Position.X.Offset
	while os.clock() - t0 < 3 do
		if b:GetAttribute("RefuseBase") ~= nil then shook = true end
		maxd = math.max(maxd, math.abs(b.Position.X.Offset - x0))
		for _, s in b:GetChildren() do
			if s:IsA("UIStroke") and s.Enabled and s.Transparency < 0.9 and s.Color.R > 0.8 and s.Color.G < 0.4 then red = true end
		end
		task.wait()
	end
	b:SetAttribute("Dev1Probe", string.format("shake=%s maxdx=%.1f red=%s", tostring(shook), maxd, tostring(red)))
end)
return "armed " .. b:GetFullName()
'''
QREAD = r'''
for _, d in game.Players.LocalPlayer.PlayerGui:GetDescendants() do
	if d:IsA("GuiButton") and d:GetAttribute("QuickSlot") == 1 and d:GetAttribute("Dev1Probe") then
		return tostring(d:GetAttribute("Dev1Probe"))
	end
end
return "no probe"
'''
COUNT = 'local p = game.Players:GetPlayers()[1] return string.format("HP potions=%s readyIn=%.1f", tostring(p:GetAttribute("HPPotionCount")), (p:GetAttribute("HPPotionReadyAt") or 0) - workspace:GetServerTimeNow())'


def box_through(c, label, final):
    """[Next] in the box until `final` (a final button name) shows, then press it"""
    for i in range(10):
        b = lua(c, BOX, "Client")
        log(f"  {label} {i}:", b)
        if i == 0:
            shot(c, os.path.join(OUT, f"A_{label}_first.png"))
        target = b.split(f" {final}=")[1].split(" ")[0] if f" {final}=" in b else "none"
        if target not in ("none", "hidden"):
            shot(c, os.path.join(OUT, f"A_{label}_last.png"))
            log(f"  {label} press {final}:", click(c, target))
            time.sleep(2.0)
            return True
        nxt = b.split(" next=")[1].split(" ")[0] if " next=" in b else "none"
        if nxt in ("none", "hidden"):
            return False
        click(c, nxt)
        time.sleep(1.0)
    return False


def part_a(c, side="Halo"):
    guide, teacher = {"Halo": ("Hallie", "Gleam"), "Horns": ("Magpie", "Smokey")}[side]
    log("A", lua(c, STATE, "Server"))
    log("  ", lua(c, GO_TO % guide, "Server"))
    time.sleep(2)
    log("  near guide:", lua(c, NPC_STATE % guide, "Client"))
    key(c, "G")
    time.sleep(2.5)
    box_through(c, "welcome", "im")
    log("  after I'm In:", lua(c, STATE, "Server"), "|", lua(c, BOX, "Client"))
    close(c)
    log("  ", lua(c, GO_TO % teacher, "Server"))
    time.sleep(2)
    key(c, "G")
    time.sleep(2.5)
    box_through(c, "teacher", "ok")
    log("  after teacher:", lua(c, STATE, "Server"), "|", lua(c, BOX, "Client"))
    # [Bye]: open the guide again and close with Bye
    log("  ", lua(c, GO_TO % guide, "Server"))
    time.sleep(1.5)
    key(c, "G")
    time.sleep(2.0)
    b = lua(c, BOX, "Client")
    bye = b.split(" bye=")[1].split(" ")[0] if " bye=" in b else "none"
    log("  guide again:", b)
    if bye not in ("none", "hidden"):
        log("  [Bye]:", click(c, bye))
        time.sleep(1.0)
        log("  after Bye:", lua(c, BOX, "Client"))


def warrior(c, side, at="Zone:Crossroads"):
    log(scene(c, {"Faction": side, "Class": "Warrior", "Level": 6, "Tutorial": "Done", "Done": CH1, "At": at}))
    time.sleep(3)
    close(c)


def part_s(c):
    for side in ("Halo", "Horns"):
        log("S", side)
        warrior(c, side)
        time.sleep(7)  # > WeaponStow.HandSeconds without an attack
        log("  idle 7 s:", lua(c, WSTATE, "Client"))
        for view in ("side", "front"):
            lua(c, 'workspace:SetAttribute("Dev1Cam2", "%s") return ""' % view, "Client")
            time.sleep(0.8)
            shot(c, os.path.join(OUT, f"S_{side}_{view}.png"))
        lua(c, 'workspace:SetAttribute("Dev1Cam2", nil) return ""', "Client")


def part_w(c, x=370, z=-60):
    log("W", lua(c, SWING_HOOK, "Server"))
    warrior(c, "Halo", "Zone:SlimeMeadow")
    log("  ", lua(c, WATER % (x, z), "Server"))
    log("  ", lua(c, OUT_OF % (x + 40, z), "Server"))
    time.sleep(2)
    log("  land:", lua(c, WSTATE, "Client"))
    before = lua(c, SWING_HOOK, "Server")
    key(c, "F")
    time.sleep(1.0)
    log("  F on land:", before, "->", lua(c, SWING_HOOK, "Server"))
    log("  ", lua(c, INTO % (x, z), "Server"))
    time.sleep(2.5)
    log("  in water:", lua(c, WSTATE, "Client"))
    shot(c, os.path.join(OUT, "W_warrior_in_water.png"))
    before = lua(c, SWING_HOOK, "Server")
    key(c, "F")
    time.sleep(0.6)
    key(c, "F")
    time.sleep(1.0)
    log("  F x2 in water:", before, "->", lua(c, SWING_HOOK, "Server"), "|", lua(c, WSTATE, "Client"))
    log("  ", lua(c, OUT_OF % (x + 40, z), "Server"))
    time.sleep(1.0)
    log("  out (1 s):", lua(c, WSTATE, "Client"))
    shot(c, os.path.join(OUT, "W_warrior_out.png"))
    # the archer: in the hand right after an attack, into the water, 6 s there (stows), out = on the back, string hidden
    log("W archer", scene(c, {"Faction": "Halo", "Class": "Archer", "Level": 6, "Tutorial": "Done", "Done": CH1, "At": "Zone:SlimeMeadow"}))
    time.sleep(3)
    close(c)
    log("  ", lua(c, OUT_OF % (x + 40, z), "Server"))
    time.sleep(6.5)
    log("  land idle (on the back):", lua(c, WSTATE, "Client"))
    key(c, "F")
    time.sleep(0.8)
    log("  land after F (in the hand):", lua(c, WSTATE, "Client"))
    log("  ", lua(c, INTO % (x, z), "Server"))
    time.sleep(1.5)
    log("  in water:", lua(c, WSTATE, "Client"))
    time.sleep(6)
    log("  in water 7.5 s:", lua(c, WSTATE, "Client"))
    log("  ", lua(c, OUT_OF % (x + 40, z), "Server"))
    time.sleep(1.0)
    log("  out:", lua(c, WSTATE, "Client"))
    lua(c, 'workspace:SetAttribute("Dev1Cam2", "back") return ""', "Client")
    time.sleep(0.8)
    shot(c, os.path.join(OUT, "W_archer_out_back.png"))
    lua(c, 'workspace:SetAttribute("Dev1Cam2", nil) return ""', "Client")


def part_p(c):
    log("P")
    warrior(c, "Halo")
    log("  potions:", debug(c, "HPPotionCount", 3))
    time.sleep(1)
    slot1 = lua(c, SLOTN % 1, "Client")
    log("  slot 1:", slot1)
    if slot1 != "none":
        click(c, slot1)
        time.sleep(1.2)
        q1 = lua(c, FIND_BTN % 'd.Name == "Quick1"', "Client")
        if q1 != "none":
            click(c, q1)
            time.sleep(1.0)
    close(c)
    log("  ", lua(c, K19.GLOW, "Client"))
    log("  HP 50%:", lua(c, SET_HP % "0.5", "Server"))
    time.sleep(0.5)
    log("  before:", lua(c, COUNT, "Server"))
    key(c, "One")
    time.sleep(1.0)
    log("  key 1 (drink):", lua(c, COUNT, "Server"))
    log("  ", lua(c, QPROBE, "Client"))
    key(c, "One")
    time.sleep(0.15)
    shot(c, os.path.join(OUT, "P_cooldown_press.png"))
    time.sleep(3.2)
    log("  key 1 in cooldown:", lua(c, QREAD, "Client"), "|", lua(c, COUNT, "Server"))


def main():
    want = [a for a in sys.argv[1:] if a in ("A", "E", "S", "W", "P")] or ["A", "E", "S", "W", "P"]
    c = Client()
    c.start()
    start_play(c)
    log("pick:", pick(c, "Halo", "Warrior"))
    try:
        log(lua(c, T1.CAM, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        for p in want:
            try:
                {"A": part_a, "E": K19.part_e, "S": part_s, "W": part_w, "P": part_p}[p](c)
            except Exception as e:  # noqa: BLE001
                log("  failed", p, str(e)[:300])
        console_errors(c)
    finally:
        save_log(os.path.join(OUT, "log.txt"))
        lua(c, T1.CAM_OFF, "Client")
        stop_play(c)


if __name__ == "__main__":
    main()
