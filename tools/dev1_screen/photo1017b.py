"""2nd short burst (10/17): the camera left on the player (CAM_OFF + CameraSubject), then
1. TutorialPractice: beside the dummy, two F, step / wobble logged, photos
2. TutorialForge: the anvil G = the first weapon -> the held-up icon over the head (FxHoldUp) photo
3. KingAnvil: Otto's G -> the bag's scroll step (words) photo
4. the forge signs (Forge / Altar) from the anvil looking at the altar, SignFit's hidden list
Usage: STUDIO_ID=... py photo1017b.py"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, debug, scene, start_play, pick, stop_play, close, GAME, WORDS, GO_TO  # noqa: E402
import photo1017 as P  # noqa: E402

OUT = P.OUT
FREE = ('pcall(function() game:GetService("RunService"):UnbindFromRenderStep("Dev1Tune") end) workspace:SetAttribute("Dev1Cam2", nil) '
        'local cam = workspace.CurrentCamera local ch = game.Players.LocalPlayer.Character '
        'cam.CameraType = Enum.CameraType.Custom cam.FieldOfView = 70 cam.CameraSubject = ch and ch:FindFirstChildOfClass("Humanoid") '
        'return "free " .. tostring(cam.CameraSubject)')
DIST = r'''
local key = %s
local spot = require(game:GetService("ReplicatedStorage").Shared.Config).StoryQuests.Landmarks[key]
local p = game.Players:GetPlayers()[1]
local r = p.Character.HumanoidRootPart
return string.format("dist=%%.1f step=%%s", ((r.Position - spot) * Vector3.new(1, 0, 1)).Magnitude, tostring(p:GetAttribute("TutorialStep")))
'''
PROMPTS = r'''
local r = game.Players.LocalPlayer.Character.HumanoidRootPart
local out = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Enabled then
		local a = d.Parent
		local pos = a and (a:IsA("Attachment") and a.WorldPosition or a:IsA("BasePart") and a.Position)
		if pos and (pos - r.Position).Magnitude < 14 then
			table.insert(out, string.format("%s(%s,%s,%.0f)", d:GetFullName(), d.ActionText, d.KeyboardKeyCode.Name, (pos - r.Position).Magnitude))
		end
	end
end
return table.concat(out, " ; ")
'''
HOLD = r'''
local g = game.Players.LocalPlayer.PlayerGui:FindFirstChild("FxHoldUp")
return "holdup=" .. tostring(g ~= nil) .. " tier=" .. tostring(game.Players.LocalPlayer:GetAttribute("WeaponTier"))
'''


def main():
    c = Client()
    c.start()
    start_play(c)
    log("pick:", pick(c, "Halo", "Warrior"))
    try:
        log(lua(c, FREE, "Client"))
        # 1 the dummy
        log("practice", scene(c, "TutorialPractice"))
        time.sleep(4)
        close(c)
        log(lua(c, P.FACE % (json.dumps("PracticeH"), 12), "Server"))
        time.sleep(1.2)
        log(lua(c, FREE, "Client"))
        time.sleep(1.0)
        log(lua(c, DIST % json.dumps("PracticeH"), "Server"), lua(c, P.PROPS, "Client"))
        shot(c, os.path.join(OUT, "b_practice_1_view.png"))
        log(lua(c, P.FACE % (json.dumps("PracticeH"), 4), "Server"))
        time.sleep(0.8)
        for i in range(2):
            key(c, "F")
            time.sleep(0.3)
            shot(c, os.path.join(OUT, f"b_practice_2_hit{i}.png"))
            time.sleep(1.0)
            log("after F", i, lua(c, DIST % json.dumps("PracticeH"), "Server"))
        time.sleep(1.5)
        shot(c, os.path.join(OUT, "b_practice_3_after.png"))
        # 2 the first weapon at the anvil
        log("forge", scene(c, "TutorialForge"))
        time.sleep(4)
        close(c)
        log(lua(c, FREE, "Client"))
        log("prompts:", lua(c, PROMPTS, "Client"))
        key(c, "G")
        time.sleep(0.6)
        log(lua(c, HOLD, "Client"))
        shot(c, os.path.join(OUT, "b_firstweapon_holdup.png"))
        time.sleep(2.0)
        close(c)
        # 3 the anvil step
        log("kinganvil", scene(c, "KingAnvil"))
        time.sleep(4)
        close(c)
        log(lua(c, GO_TO % "Otto", "Server"))
        time.sleep(1.2)
        log(lua(c, FREE, "Client"))
        log("prompts:", lua(c, PROMPTS, "Client"))
        key(c, "G")
        time.sleep(2.0)
        log("anvil window:", lua(c, WORDS, "Client"))
        shot(c, os.path.join(OUT, "b_kinganvil_window.png"))
        close(c)
        # 4 signs
        lua(c, P.LOOK_ALTAR, "Client")
        time.sleep(1.2)
        log("signs:", lua(c, P.SIGNS, "Client"))
        shot(c, os.path.join(OUT, "b_signs_forge.png"))
        log(lua(c, FREE, "Client"))
    finally:
        save_log(os.path.join(OUT, "log_b.txt"))
        stop_play(c)


if __name__ == "__main__":
    main()
