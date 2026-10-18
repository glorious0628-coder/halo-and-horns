import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, lua, key, scene, start_play, pick, stop_play, close
POS = 'local p = game.Players:GetPlayers()[1] local r = p.Character.HumanoidRootPart local s = require(game.ReplicatedStorage.Shared.Config).StoryQuests.Landmarks.PracticeH return string.format("root=(%.0f,%.0f,%.0f) spot=(%.0f,%.0f,%.0f) step=%s zone=%s", r.Position.X, r.Position.Y, r.Position.Z, s.X, s.Y, s.Z, tostring(p:GetAttribute("TutorialStep")), tostring(p:GetAttribute("ZoneId")))'
c = Client(); c.start(); start_play(c); log(pick(c, "Halo", "Warrior"))
try:
    log(scene(c, "TutorialPractice"))
    for i in range(4):
        time.sleep(1.0); log(i, lua(c, POS, "Server"))
    close(c)
    log("tp", lua(c, 'local p = game.Players:GetPlayers()[1] local s = require(game.ReplicatedStorage.Shared.Config).StoryQuests.Landmarks.PracticeH p.Character:PivotTo(CFrame.new(s + Vector3.new(0, 4, 4), s + Vector3.new(0, 4, 0))) return "pivot"', "Server"))
    for i in range(3):
        time.sleep(1.0); log("after tp", i, lua(c, POS, "Server"))
    key(c, "F"); time.sleep(1.2); log("after F", lua(c, POS, "Server"))
    key(c, "F"); time.sleep(1.2); log("after F2", lua(c, POS, "Server"))
finally:
    stop_play(c)
