"""Press-through check before merging dev1-first12 + dev2-first12c (최종 검수 10/17). MY test Studio (STUDIO_ID = PhoneTest_1015)
with ../wt_photo2 synced. Values, then a photo each:
1. TutorialPractice: beside the dummy (stays there 2 s?), one F -> TutorialStep 5 -> next
2. KingAnvil: Otto's G -> the bag's scroll step (words)
3. TinyParcel: Tiny's G -> Tiny's words on screen + the goal line after
4. M1_3 step 1: the marker points at Lv5Slimes (250,0,0) - its distance vs the real one
Usage: STUDIO_ID=... py press1017.py"""
import json, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from h1016 import Client, log, save_log, lua, key, shot, scene, start_play, pick, stop_play, close, GAME, WORDS, GO_TO, MARKER  # noqa: E402
import photo1017 as P  # noqa: E402
import photo1017b as B  # noqa: E402

OUT = os.path.join(GAME, "docs", "art", "verification_2026-10-17", "press_first12")
os.makedirs(OUT, exist_ok=True)
GOAL = r'''
local pg = game.Players.LocalPlayer.PlayerGui
local t = pg:FindFirstChild("QuestTracker", true)
local out = {}
for _, d in t and t:GetDescendants() or {} do
	if d:IsA("TextLabel") and d.Visible and d.Text ~= "" then table.insert(out, d.Name .. "=" .. d.Text) end
end
return table.concat(out, " | ")
'''
BUBBLES = r'''
local out = {}
for _, root in { workspace, game.Players.LocalPlayer.PlayerGui } do
	for _, d in root:GetDescendants() do
		if d:IsA("BillboardGui") and d.Enabled and (string.find(d.Name, "Bubble") or d.Name == "StoryFindBubble") then
			local l = d:FindFirstChildWhichIsA("TextLabel", true)
			table.insert(out, d.Name .. "@" .. tostring(d.Adornee and d.Adornee.Parent and d.Adornee.Parent.Name) .. "='" .. tostring(l and l.Text) .. "'")
		end
	end
end
return #out > 0 and table.concat(out, " ; ") or "no bubble"
'''
DIST_TO = r'''
local s = %s
local r = game.Players:GetPlayers()[1].Character.HumanoidRootPart
return string.format("me=(%%.0f,%%.0f) to Lv5Slimes=%%.0f", r.Position.X, r.Position.Z, ((r.Position - s) * Vector3.new(1, 0, 1)).Magnitude)
'''


def main():
    c = Client()
    c.start()
    start_play(c)
    log("pick:", pick(c, "Halo", "Warrior"))
    try:
        log(lua(c, B.FREE, "Client"))
        # 1
        log("1 practice", scene(c, "TutorialPractice"))
        time.sleep(4)
        close(c)
        log(lua(c, P.FACE % (json.dumps("PracticeH"), 4), "Server"))
        for i in range(2):
            time.sleep(1.0)
            log("  stay", i, lua(c, B.DIST % json.dumps("PracticeH"), "Server"))
        log(lua(c, B.FREE, "Client"))
        shot(c, os.path.join(OUT, "1_dummy_before.png"))
        key(c, "F")
        time.sleep(0.35)
        shot(c, os.path.join(OUT, "1_dummy_hit.png"))
        time.sleep(1.5)
        log("  after F", lua(c, B.DIST % json.dumps("PracticeH"), "Server"), lua(c, P.PROPS, "Client"))
        if "step=5" in lua(c, B.DIST % json.dumps("PracticeH"), "Server"):
            key(c, "F")
            time.sleep(1.5)
            log("  after F2", lua(c, B.DIST % json.dumps("PracticeH"), "Server"))
        # 2
        log("2 anvil", scene(c, "KingAnvil"))
        time.sleep(4)
        close(c)
        log(lua(c, GO_TO % "Otto", "Server"))
        time.sleep(1.2)
        log(lua(c, B.FREE, "Client"))
        key(c, "G")
        time.sleep(2.0)
        log("  window:", lua(c, WORDS, "Client"))
        shot(c, os.path.join(OUT, "2_anvil_window.png"))
        close(c)
        # 3
        log("3 tiny", scene(c, "TinyParcel"))
        time.sleep(4)
        close(c)
        log(lua(c, GO_TO % "Tiny", "Server"))
        time.sleep(1.2)
        log(lua(c, B.FREE, "Client"))
        log("  goal before:", lua(c, GOAL, "Client"))
        log("  prompts:", lua(c, B.PROMPTS, "Client"))
        key(c, "G")
        time.sleep(1.2)
        log("  bubbles:", lua(c, BUBBLES, "Client"), "| window:", lua(c, WORDS, "Client"))
        shot(c, os.path.join(OUT, "3_tiny_talk.png"))
        time.sleep(2.5)
        close(c)
        log("  goal after:", lua(c, GOAL, "Client"))
        shot(c, os.path.join(OUT, "3_tiny_after.png"))
        # 4
        log("4 m1_3 step 1", scene(c, {"Faction": "Halo", "Class": "Warrior", "Level": 5, "Tutorial": "Done",
                                       "Done": ["M1_1", "M1_2"], "Main": "M1_3:1", "At": "Zone:Crossroads"}))
        time.sleep(4)
        close(c)
        log(lua(c, B.FREE, "Client"))
        time.sleep(1.0)
        log("  goal:", lua(c, GOAL, "Client"))
        log("  ", lua(c, MARKER, "Client"), lua(c, DIST_TO % "Vector3.new(250, 0, 0)", "Server"))
        shot(c, os.path.join(OUT, "4_m1_3_marker.png"))
        # inside the meadow (its spawn): the marker should be on Lv5Slimes itself
        log(lua(c, 'local s = require(game.ReplicatedStorage.Shared.Config).Zones.SlimeMeadow.Spawn '
                   'game.Players:GetPlayers()[1].Character:PivotTo(CFrame.new(s + Vector3.new(0, 4, 0))) return "in meadow"', "Server"))
        time.sleep(2.5)
        log(lua(c, B.FREE, "Client"))
        log("  meadow:", lua(c, MARKER, "Client"), lua(c, DIST_TO % "Vector3.new(250, 0, 0)", "Server"))
        shot(c, os.path.join(OUT, "4_m1_3_marker_meadow.png"))
    finally:
        save_log(os.path.join(OUT, "log.txt"))
        stop_play(c)


if __name__ == "__main__":
    main()
