"""최종 검수 r8 follow-ups in MY test Studio (STUDIO_ID = PhoneTest_1015), one fresh Play:
A  the Mage's staff vs the head - the REAL distance (head centre to the staff's long axis, every frame, resting and over
   a swing; the avatar1017 'Head' hits are GetPartsInPart BOXES) + front / side / back photos at the cast frame
B  the first swing right after an avatar change (avatar1017's mine_Warrior: hand-weapon line 1.96 vs 0.06 on the rest):
   ApplyDescription, then swing at once / again, MEASURE each
C  'Your King': the field King + my rematch King on the hill -> both name tags + the quest mark's adornee, photos
Usage: STUDIO_ID=... py check1018.py [A] [B] [C]   (default all)"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME  # noqa: E402
from measure_common import MEASURE, FACE_SLIME  # noqa: E402
from avatar1017 import APPLY  # noqa: E402
import tune1016 as T1  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-18", "r8_checks")
os.makedirs(OUT, exist_ok=True)
CH1 = ["M1_1", "M1_2", "M1_3", "M1_4"]

# head centre -> the staff: every visible weapon part's long axis as a segment (its longest size), the nearest; the head's
# own radius = half its smallest side (an R15 Head mesh is about its box). secs of frames; -> json
STAFF_HEAD = r'''
local secs = %s
local RS = game:GetService("RunService")
local ch = game.Players.LocalPlayer.Character
local head = ch and ch:FindFirstChild("Head")
local model = ch and ch:FindFirstChild("WeaponModel")
if not (head and model) then return "{\"err\":\"no head / weapon\"}" end
local parts = {}
for _, d in model:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 0.95 then table.insert(parts, d) end end
local function seg(p)
	local s = p.Size
	local ax, len = p.CFrame.RightVector, s.X
	if s.Y > len then ax, len = p.CFrame.UpVector, s.Y end
	if s.Z > len then ax, len = p.CFrame.LookVector, s.Z end
	local thick = math.min(s.X, s.Y, s.Z) / 2
	return p.Position - ax * len / 2, p.Position + ax * len / 2, thick
end
local function dist(pt, a, b)
	local ab = b - a
	local t = math.clamp((pt - a):Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (pt - (a + ab * t)).Magnitude, t
end
local R = { n = 0, minGap = 99, inside = 0, worstT = nil, headR = math.min(head.Size.X, head.Size.Y, head.Size.Z) / 2, parts = #parts }
local t0 = os.clock()
local conn
conn = RS.Heartbeat:Connect(function()
	R.n += 1
	local best = 99
	for _, p in parts do
		local a, b, thick = seg(p)
		local d, t = dist(head.Position, a, b)
		local gap = d - thick - R.headR
		if gap < best then best = gap R.worstT = t end
	end
	R.minGap = math.min(R.minGap, best)
	if best < 0 then R.inside += 1 end
end)
while os.clock() - t0 < secs do task.wait() end
conn:Disconnect()
return game:GetService("HttpService"):JSONEncode(R)
'''
PARTS = r'''
local ch = game.Players.LocalPlayer.Character
local head = ch and ch:FindFirstChild("Head")
local model = ch and ch:FindFirstChild("WeaponModel")
local out = {}
for _, d in model and model:GetDescendants() or {} do
	if d:IsA("BasePart") then
		table.insert(out, string.format("%s %s T%.2f size(%.1f,%.1f,%.1f) %.2f from head", d.Name, d.ClassName, d.Transparency, d.Size.X, d.Size.Y, d.Size.Z,
			head and (d.Position - head.Position).Magnitude or -1))
	end
end
return table.concat(out, " ; ")
'''
KINGS = r'''
local out = {}
local me = game.Players.LocalPlayer
local folder = workspace:FindFirstChild("Monsters")
for _, m in folder and folder:GetChildren() or {} do
	local k = m:GetAttribute("MonsterKind") or m.Name
	if k == "SlimeKing" then
		local bb = m:FindFirstChild("MonsterBar", true)
		local nl = bb and bb:FindFirstChild("NameLabel")
		table.insert(out, string.format("%s owner=%s name='%s' shown=%s", m.Name, tostring(m:GetAttribute("OwnerUserId") == me.UserId and "me" or m:GetAttribute("OwnerUserId")),
			tostring(nl and nl.Text), tostring(bb and bb.Enabled and nl and nl.Visible)))
	end
end
for _, d in me.PlayerGui:GetDescendants() do
	if d:IsA("BillboardGui") and d.Name:find("Quest") and d.Enabled then
		local lbl = d:FindFirstChildWhichIsA("TextLabel", true)
		table.insert(out, string.format("mark %s adornee=%s label='%s'", d.Name, d.Adornee and d.Adornee:GetFullName() or "nil", tostring(lbl and lbl.Text)))
	end
end
return table.concat(out, " | ")
'''


def part_a(c):
    log("A", scene(c, {"Faction": "Halo", "Class": "Mage", "Level": 30, "Tutorial": "Done", "Done": CH1, "At": "Zone:SlimeMeadow"}))
    time.sleep(3)
    close(c)
    debug(c, "WeaponOwnedMask", 7)
    debug(c, "WeaponTier", 1)
    time.sleep(1.5)
    log("  rest 2 s:", lua(c, STAFF_HEAD % 2, "Client"))
    for view in ("front", "side", "back"):
        log("  ", lua(c, FACE_SLIME, "Server"))
        time.sleep(0.8)
        lua(c, 'workspace:SetAttribute("Dev1Cam2", "%s") return ""' % view, "Client")
        time.sleep(0.3)
        key(c, "F")
        time.sleep(0.24)  # MOTION.CAST_DELAY: the cast frame
        shot(c, os.path.join(OUT, f"A_staff_{view}.png"))
        log(f"  swing ({view}) 0.6 s:", lua(c, STAFF_HEAD % 0.6, "Client"))
        time.sleep(1.0)
    lua(c, 'workspace:SetAttribute("Dev1Cam2", nil) return ""', "Client")
    debug(c, "WeaponTier", 4)
    time.sleep(1.5)
    log("  tier 4 rest:", lua(c, STAFF_HEAD % 1.5, "Client"))
    log("  ", lua(c, FACE_SLIME, "Server"))
    time.sleep(0.8)
    key(c, "F")
    log("  tier 4 swing:", lua(c, STAFF_HEAD % 0.6, "Client"))
    debug(c, "WeaponTier", 1)


def part_b(c):
    log("B", scene(c, {"Faction": "Halo", "Class": "Warrior", "Level": 30, "Tutorial": "Done", "Done": CH1, "At": "Zone:SlimeMeadow"}))
    time.sleep(3)
    close(c)
    debug(c, "WeaponOwnedMask", 7)
    debug(c, "WeaponTier", 1)
    for rnd in range(2):
        log("  apply:", lua(c, APPLY % "{}", "Server"))
        time.sleep(2.0)
        log("  ", debug(c, "Class", "Warrior"))
        time.sleep(2.5)
        for i in range(3):
            log("  ", lua(c, FACE_SLIME, "Server"))
            time.sleep(0.8)
            key(c, "F")
            time.sleep(0.15)
            if i == 0:
                shot(c, os.path.join(OUT, f"B_round{rnd + 1}_first.png"))
            raw = lua(c, MEASURE % 0.5, "Client")
            try:
                m = json.loads(raw)
                log(f"  round {rnd + 1} swing {i + 1}: dGripMax={m.get('dGripMax')} axisMax={m.get('axisMax')} kind={m.get('kind')}")
            except Exception:  # noqa: BLE001
                log(f"  round {rnd + 1} swing {i + 1}:", raw[:200])
            time.sleep(1.0)


MARK = r'''
local me = game.Players.LocalPlayer
local cam = workspace.CurrentCamera
local QT = require(me.PlayerScripts:WaitForChild("QuestTarget"))
local root = QT.MyKing("SlimeKing")
local out = { "MyKing=" .. (root and root:GetFullName() or "nil") }
local gui = me.PlayerGui:FindFirstChild("QuestMarkerGui")
local mk = gui and gui:FindFirstChild("QuestMarker", true)
if mk and mk.Visible then
	local c = mk.AbsolutePosition + mk.AbsoluteSize / 2
	table.insert(out, string.format("mark at (%d,%d)", c.X, c.Y))
	local folder = workspace:FindFirstChild("Monsters")
	for _, m in folder and folder:GetChildren() or {} do
		if (m:GetAttribute("MonsterKind") or m.Name) == "SlimeKing" then
			local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
			if r then
				local p, on = cam:WorldToViewportPoint(r.Position)
				local inset = game:GetService("GuiService"):GetGuiInset()
				table.insert(out, string.format("%s king px dist=%d (on=%s, %.0f studs from me)", m:GetAttribute("OwnerUserId") == me.UserId and "MY" or "FIELD",
					math.floor(((Vector2.new(p.X, p.Y) - inset) - c).Magnitude), tostring(on),
					me.Character and (r.Position - me.Character:GetPivot().Position).Magnitude or -1))
			end
		end
	end
	local lbl = mk:FindFirstChildWhichIsA("TextLabel", true)
	table.insert(out, "label=" .. tostring(lbl and lbl.Text))
else
	table.insert(out, "no mark shown")
end
return table.concat(out, " | ")
'''
# the field King (Owner nil) moved 14 studs beside my King for the photo (the 8판 hill: both in view)
MOVE_FIELD = r'''
local me = game.Players:GetPlayers()[1]
local mine, field = nil, nil
for _, m in workspace.Monsters:GetChildren() do
	if (m:GetAttribute("MonsterKind") or m.Name) == "SlimeKing" then
		if m:GetAttribute("OwnerUserId") == me.UserId then mine = m elseif m:GetAttribute("OwnerUserId") == nil then field = m end
	end
end
if not (mine and field) then return "mine=" .. tostring(mine) .. " field=" .. tostring(field) end
field:PivotTo(mine:GetPivot() * CFrame.new(14, 0, 0))
return "moved"
'''
DYING = r'''
local me = game.Players:GetPlayers()[1]
for _, m in workspace.Monsters:GetChildren() do
	if m:GetAttribute("OwnerUserId") == me.UserId then
		local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		if r then r.Anchored = %s return "anchored=" .. tostring(r.Anchored) end
	end
end
return "no own king"
'''


def part_c(c):
    # the test place's old map has a StoryLandmark 'KingHill' in Halo town: untagged for this Play (Config's (400, -118) then)
    log("C untag:", lua(c, 'local CS = game:GetService("CollectionService") local n = 0 for _, i in CS:GetTagged("StoryLandmark") do if i:GetAttribute("Spot") == "KingHill" then CS:RemoveTag(i, "StoryLandmark") n += 1 end end return "untagged " .. n', "Server"))
    log("C", scene(c, {"Faction": "Halo", "Class": "Warrior", "Level": 3, "Tutorial": "Done", "Done": ["M1_1"], "Main": "M1_2:1", "At": "Zone:SlimeMeadow"}))
    time.sleep(2)
    log("  pivot:", lua(c, 'local p = game.Players:GetPlayers()[1] local g = workspace:Raycast(Vector3.new(390, 300, -110), Vector3.new(0, -600, 0)) local y = g and g.Position.Y + 3 or 5 p.Character:PivotTo(CFrame.new(390, y, -110)) return "y=" .. y', "Server"))
    time.sleep(3)
    close(c)
    log("  at:", lua(c, 'local p = game.Players.LocalPlayer local r = p.Character and p.Character:GetPivot().Position return tostring(r) .. " zone=" .. tostring(p:GetAttribute("ZoneId"))', "Client"))
    log("  my King:", debug(c, "FirstKO", "retry"))
    time.sleep(2)
    log("  at:", lua(c, 'local p = game.Players.LocalPlayer local r = p.Character and p.Character:GetPivot().Position return tostring(r) .. " zone=" .. tostring(p:GetAttribute("ZoneId"))', "Client"))
    for i in range(30):
        time.sleep(1)
        k = lua(c, KINGS, "Client")
        if "owner=me" in k:
            log(f"  my King out after {i + 1} s")
            break
    else:
        log("  my King never came:", lua(c, 'local r = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:GetPivot().Position return tostring(r) .. " zone=" .. tostring(game.Players.LocalPlayer:GetAttribute("ZoneId"))', "Client"))
    time.sleep(3)  # the drop from the sky lands
    log("  field King:", debug(c, "SlimeKing", ""))
    time.sleep(2)
    log("  at:", lua(c, 'local p = game.Players.LocalPlayer local r = p.Character and p.Character:GetPivot().Position return tostring(r) .. " zone=" .. tostring(p:GetAttribute("ZoneId"))', "Client"))
    log("  field King moved:", lua(c, MOVE_FIELD, "Server"))
    time.sleep(0.8)
    log("  kings:", lua(c, KINGS, "Client"))
    log("  mark:", lua(c, MARK, "Client"))
    shot(c, os.path.join(OUT, "C_two_kings.png"))
    log("  dying:", lua(c, DYING % "true", "Server"))
    time.sleep(1.5)
    log("  mark (my King dying):", lua(c, MARK, "Client"))
    shot(c, os.path.join(OUT, "C_my_king_dying.png"))
    log("  ", lua(c, DYING % "false", "Server"))
    time.sleep(1.0)
    log("  mark (back):", lua(c, MARK, "Client"))
    log("  FirstKO off:", debug(c, "FirstKO", "off"))


def part_d(c):
    """the tier-4 staff (3 parts) that measured inside the head at rest: photos + the nearest part's name"""
    log("D", scene(c, {"Faction": "Halo", "Class": "Mage", "Level": 30, "Tutorial": "Done", "Done": CH1, "At": "Zone:SlimeMeadow"}))
    time.sleep(3)
    close(c)
    debug(c, "WeaponOwnedMask", 15)
    for tier in (2, 3, 4):
        debug(c, "WeaponTier", tier)
        time.sleep(1.5)
        log(f"  tier {tier} parts:", lua(c, PARTS, "Client"))
        log(f"  tier {tier} rest:", lua(c, STAFF_HEAD % 1.0, "Client"))
        for view in ("front", "side"):
            lua(c, 'workspace:SetAttribute("Dev1Cam2", "%s") return ""' % view, "Client")
            time.sleep(0.4)
            shot(c, os.path.join(OUT, f"D_tier{tier}_rest_{view}.png"))
        log("  ", lua(c, FACE_SLIME, "Server"))
        time.sleep(0.8)
        lua(c, 'workspace:SetAttribute("Dev1Cam2", "front") return ""', "Client")
        key(c, "F")
        time.sleep(0.24)
        shot(c, os.path.join(OUT, f"D_tier{tier}_cast_front.png"))
        log(f"  tier {tier} swing:", lua(c, STAFF_HEAD % 0.5, "Client"))
        time.sleep(1.0)
    lua(c, 'workspace:SetAttribute("Dev1Cam2", nil) return ""', "Client")


def main():
    want = [a for a in sys.argv[1:] if a in ("A", "B", "C", "D")] or ["C", "A", "B"]
    c = Client()
    c.start()
    start_play(c)
    log("pick:", pick(c, "Halo", "Mage"))
    try:
        log(lua(c, T1.CAM, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        for p in want:
            try:
                {"A": part_a, "B": part_b, "C": part_c, "D": part_d}[p](c)
            except Exception as e:  # noqa: BLE001
                log("  failed", p, str(e)[:300])
    finally:
        save_log(os.path.join(OUT, "log.txt"))
        lua(c, T1.CAM_OFF, "Client")
        stop_play(c)


if __name__ == "__main__":
    main()
