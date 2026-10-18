"""game dev 1 photos for dev1-stow-fix + dev1-first12 (10/17). MY test Studio only (STUDIO_ID = build/PhoneTest_1015.rbxlx),
the photo tree ../wt_photo synced (first12 + stow-fix). One burst:
1. stow: Horns warrior T1 club / Halo warrior T1 sword at the hip (side, back, walk side) + the tip angle and the lowest point
   over the floor; Horns archer bow on the back (side) + the string beams' Enabled
2. TutorialPractice: the dummy + marker + row (normal camera), one F beside it (the wobble), TutorialStep after
3. KingHop: the King's hill mark in the meadow ('King Slime')
4. KingAnvil: Otto's G -> the bag's scroll step with the weapon picked (words logged)
5. signs at the forge: the 'Forge' / 'Altar of Fate' labels (SignFit's hidden list)
Usage: py photo1017.py [--running] [--keep]"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME, WORDS, MARKER, GO_TO, FIND_TEXT  # noqa: E402
import tune1016 as T1  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-17", "dev1_photos")
os.makedirs(OUT, exist_ok=True)

STOW = r'''
local ch = game.Players.LocalPlayer.Character
local tool = ch and ch:FindFirstChild("WeaponModel")
local handle = tool and tool:FindFirstChild("Handle")
if not handle then return "no weapon" end
local w = handle:FindFirstChild("StowWeld")
local hum = ch:FindFirstChildOfClass("Humanoid")
local root = ch.HumanoidRootPart
local floor = root.Position.Y - root.Size.Y / 2 - hum.HipHeight
local low, tipDown = math.huge, nil
for _, p in tool:GetDescendants() do
	if p:IsA("BasePart") and p.Transparency < 1 then
		local cf, s = p.CFrame, p.Size / 2
		for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
			low = math.min(low, (cf * Vector3.new(x * s.X, y * s.Y, z * s.Z)).Y)
		end end end
	end
end
local up = handle.CFrame.UpVector
local beams = {}
local str = tool:FindFirstChild("String")
for _, b in str and str:GetChildren() or {} do if b:IsA("Beam") then table.insert(beams, b.Name .. "=" .. tostring(b.Enabled)) end end
return string.format("stowed=%s tipDown=%.0f deg lowest=%.2f over floor beams=%s", tostring(w and w.Enabled),
	math.deg(math.asin(-up.Y)), low - floor, table.concat(beams, ","))
'''
PROPS = r'''
local f = workspace:FindFirstChild("StoryProps")
local out = {}
for _, m in f and f:GetChildren() or {} do
	local post = m:FindFirstChild("Post")
	table.insert(out, m.Name .. (post and string.format(" post=%.1f", post.Size.Y) or ""))
end
local p = game.Players.LocalPlayer
return "props: " .. table.concat(out, ", ") .. " | step=" .. tostring(p:GetAttribute("TutorialStep")) .. " tool=" .. tostring(p:GetAttribute("PracticeTool"))
'''
FACE = r'''
local key = %s
local spot = require(game:GetService("ReplicatedStorage").Shared.Config).StoryQuests.Landmarks[key]
local r = game.Players:GetPlayers()[1].Character.HumanoidRootPart
local at = spot + Vector3.new(0, 0, %s)
r.CFrame = CFrame.lookAt(Vector3.new(at.X, r.Position.Y, at.Z), Vector3.new(spot.X, r.Position.Y, spot.Z))
return "at " .. key
'''
SIGNS = r'''
local out = {}
for _, d in workspace.Map:GetDescendants() do
	if d:IsA("BillboardGui") then
		local l = d:FindFirstChildWhichIsA("TextLabel", true)
		if l and (string.find(l.Text, "Forge") or string.find(l.Text, "Altar") or string.find(l.Text, "Lv")) then
			table.insert(out, string.sub(l.Text, 1, 30) .. "=" .. tostring(d.Enabled))
		end
	end
end
return table.concat(out, " ; ")
'''
LOOK_ALTAR = r'''
local cam = workspace.CurrentCamera
local r = game.Players.LocalPlayer.Character.HumanoidRootPart
cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(r.Position + Vector3.new(0, 4, 0) - (Vector3.new(0, 0, 45) - r.Position).Unit * 6, Vector3.new(0, 6, 45))
return "look"
'''


def stow_part(c):
    for side, cls in (("Horns", "Warrior"), ("Halo", "Warrior"), ("Horns", "Archer")):
        tag = f"stow_{side}_{cls}"
        T1.setup(c, side, cls, 1)
        time.sleep(6.0)  # HandSeconds 5: stowed
        log(tag, lua(c, STOW, "Client"))
        for v in ("side", "back", "left"):
            lua(c, 'workspace:SetAttribute("Dev1Cam2", %s) return ""' % json.dumps(v), "Client")
            time.sleep(0.4)
            shot(c, os.path.join(OUT, f"{tag}_{v}.png"))
        lua(c, T1.WALK % 60, "Client")
        time.sleep(0.5)
        lua(c, 'workspace:SetAttribute("Dev1Cam2", "side") return ""', "Client")
        time.sleep(0.3)
        shot(c, os.path.join(OUT, f"{tag}_walk_side.png"))
        log(tag, "walking:", lua(c, STOW, "Client"))
        lua(c, T1.HALT, "Client")
    lua(c, T1.CAM_OFF, "Client")


def practice_part(c):
    log("practice scene", scene(c, "TutorialPractice"))
    time.sleep(4)
    close(c)
    log(lua(c, FACE % (json.dumps("PracticeH"), 14), "Server"))
    time.sleep(1.5)
    log(lua(c, PROPS, "Client"))
    log(lua(c, MARKER, "Client"))
    shot(c, os.path.join(OUT, "practice_1_view.png"))
    log(lua(c, FACE % (json.dumps("PracticeH"), 3.5), "Server"))
    time.sleep(1.0)
    key(c, "F")
    time.sleep(0.3)
    shot(c, os.path.join(OUT, "practice_2_hit.png"))
    time.sleep(2.5)
    log("after hit:", lua(c, PROPS, "Client"))
    shot(c, os.path.join(OUT, "practice_3_after.png"))


def king_part(c):
    log("kinghop scene", scene(c, "KingHop"))
    time.sleep(4)
    close(c)
    log(lua(c, MARKER, "Client"))
    log(lua(c, FIND_TEXT % json.dumps("King Slime"), "Client"))
    shot(c, os.path.join(OUT, "kinghop_1.png"))
    log("kinganvil scene", scene(c, "KingAnvil"))
    time.sleep(4)
    close(c)
    log(lua(c, GO_TO % "Otto", "Server"))
    time.sleep(1.5)
    key(c, "G")
    time.sleep(2.0)
    log("anvil window:", lua(c, WORDS, "Client"))
    shot(c, os.path.join(OUT, "kinganvil_window.png"))
    close(c)


def signs_part(c):
    log(lua(c, GO_TO % "Otto", "Server"))
    time.sleep(1.0)
    lua(c, LOOK_ALTAR, "Client")
    time.sleep(1.2)
    log("signs:", lua(c, SIGNS, "Client"))
    shot(c, os.path.join(OUT, "signs_forge.png"))
    lua(c, T1.CAM_OFF, "Client")


def main():
    c = Client()
    c.start()
    if "--running" not in sys.argv:
        start_play(c)
        log("pick:", pick(c, "Horns", "Warrior"))
    try:
        log(lua(c, T1.CAM, "Client"))
        log("clock:", lua(c, 'return tostring(game.ServerScriptService.DebugCommand:Invoke("", "Clock", 13))', "Server"))
        for part in (stow_part, practice_part, king_part, signs_part):
            try:
                part(c)
            except Exception as e:  # noqa: BLE001
                log("part failed", part.__name__, str(e)[:200])
    finally:
        save_log(os.path.join(OUT, "log.txt"))
        if "--keep" not in sys.argv:
            stop_play(c)


if __name__ == "__main__":
    main()
