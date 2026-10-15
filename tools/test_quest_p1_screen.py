"""Quest P1 bundle 2 - the screen part (게임성 개발 2 contract docs/design/quest_p1_server_contract_2026-10-15.md), offline.

Runs the CURRENT StoryNpcs.Spots / FlagsOf / EmoteAt / EmoteNames and Panels STORY.DifficultyLook in the official Luau
CLI on small doubles: an open Practice / Emote / Pickup step gives its place, a step that leads to a Lamp* spot gives the
lamp (my side's override first), the saved StoryFlags text parses, the emote buttons show only at the spot (wave =
Good first), and a request's Difficulty maps to the weapon grade colour and stars (A23-207). Static: the first-mission
row walks to its GuideNpc (HUD tap + QuestTarget marker, no RequestTutorial then), the test goal walks to the teacher,
the dummies wobble on a nearby Swing Fx, the practice tool follows PracticeTool, the Emote press sends
StoryAction(Id, "Emote", name), a StoryScene plays and the Offer window draws the difficulty. Each mutation must make a
check fail.

Usage: py tools/test_quest_p1_screen.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"NPC": SPS / "StoryNpcs.luau", "PANELS": SPS / "Panels.luau", "HUD": SPS / "HUD.luau",
         "QT": SPS / "QuestTarget.luau", "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local V = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, { __type = "Vector3" }) end
local function typeof(v) local mt = type(v) == "table" and getmetatable(v) return mt and mt.__type or type(v) end
local function C3(n) return setmetatable({ N = n }, { __type = "Color3" }) end
local Util = { FlatDistance = function(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end }
local T = { Pickup = { Brush = 5 } }
local Config = { StoryQuests = {
	Landmarks = { PracticeH = V(0, 0, 0), PoseSpot = V(100, 0, 0), LampH = V(200, 0, 0), LampR = V(300, 0, 0), LostBag = V(5, 0, 5) },
	DifficultyGrade = { Easy = "Common", Normal = "Fine", Hard = "Rare", Challenge = "Epic" },
	Defs = {
		B = { Steps = { { Obj = { Type = "Practice", Spot = "PracticeH", Radius = 10 } } } },
		E = { Steps = { { Obj = { Type = "Emote", Spot = "PoseSpot", Allowed = { cheer = "Evil", wave = "Good" } } } } },
		L = { Steps = { { Guide = "LampH", Obj = { Type = "Near", Spot = "LampH", Radius = 12 },
				Horns = { Guide = "LampR", Obj = { Type = "Near", Spot = "LampR", Radius = 12 } } },
			{ Guide = "LampH", Obj = { Type = "Choice" }, Horns = { Guide = "LampR", Obj = { Type = "Choice" } } } } },
		P = { Steps = { { Obj = { Type = "Pickup", Spot = "LostBag" } } } },
		K = { Steps = { { Obj = { Type = "Kill" } } } },
		X = { Steps = { { Obj = { Type = "Practice", Spot = "Nowhere" } } } },
	} },
	WeaponGrades = { Common = { Stars = 1, Color = C3("grey") }, Fine = { Stars = 2, Color = C3("green") }, Rare = { Stars = 3, Color = C3("blue") },
		Epic = { Stars = 4, Color = C3("purple") } } }
local STORY, StoryNpcs = {}, {}
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local function row(id, st) return { Kind = "Sub", Story = { Id = id, St = st } } end
local function find(list, t) for _, s in list do if s.Type == t then return s end end return nil end
local sp = StoryNpcs.Spots({ row("B", 1), row("E", 1), row("L", 1), row("P", 1), row("K", 1), row("X", 1) }, "Halo")
check("Practice: its dummy spot and radius", find(sp, "Practice") and find(sp, "Practice").Spot == "PracticeH" and find(sp, "Practice").Radius == 10)
check("Emote: its spot, radius 10 by default, the allowed names", find(sp, "Emote") and find(sp, "Emote").Radius == 10
	and find(sp, "Emote").Allowed.wave == "Good")
check("a step that leads to a Lamp spot = the lamp", find(sp, "Lamp") and find(sp, "Lamp").Spot == "LampH")
check("Pickup stays a spot", find(sp, "Pickup") and find(sp, "Pickup").Spot == "LostBag")
check("a kill step / an unknown spot: nothing", #sp == 4, #sp)
sp = StoryNpcs.Spots({ row("L", 1) }, "Horns")
check("my side's override first (Horns: LampR)", sp[1] and sp[1].Spot == "LampR", sp[1] and sp[1].Spot)
sp = StoryNpcs.Spots({ row("L", 2) }, "Horns")
check("a choice step with a Lamp guide: the lamp stays", sp[1] and sp[1].Type == "Lamp" and sp[1].Spot == "LampR")
sp = StoryNpcs.Spots({ row("B", 1), row("B", 1) }, "Halo")
check("one place per quest", #sp == 1)
check("nothing: an empty list, never an error", #StoryNpcs.Spots(nil, nil) == 0)
local f = StoryNpcs.FlagsOf("Crown=Paper,Lamp=Mine")
check("StoryFlags: every Key=Value", f.Crown == "Paper" and f.Lamp == "Mine")
check("StoryFlags empty / nil: none", next(StoryNpcs.FlagsOf("")) == nil and next(StoryNpcs.FlagsOf(nil)) == nil)
sp = StoryNpcs.Spots({ row("E", 1) }, "Horns")
check("at the pose spot: its Emote step", StoryNpcs.EmoteAt(sp, V(105, 0, 0)) ~= nil)
check("away from it: no buttons", StoryNpcs.EmoteAt(sp, V(120, 0, 0)) == nil)
local names = StoryNpcs.EmoteNames(sp[1])
check("the buttons: wave (Good) first, then cheer", names[1] == "wave" and names[2] == "cheer", table.concat(names, ","))
sp = StoryNpcs.Spots({ row("P", 1) }, "Halo")
check("brushing past a thing to pick up takes it", StoryNpcs.BrushPickup(sp, V(8, 0, 5)) ~= nil)
check("farther than Brush: still a press", StoryNpcs.BrushPickup(sp, V(12, 0, 5)) == nil)
local d = STORY.DifficultyLook("Hard")
check("Hard = the Rare colour, 3 stars", d and d.Color.N == "blue" and d.Stars == 3)
check("Easy = Common 1 star, Challenge = Epic 4", STORY.DifficultyLook("Easy").Stars == 1 and STORY.DifficultyLook("Challenge").Stars == 4)
check("no / unknown Difficulty: nil (the plain row)", STORY.DifficultyLook(nil) == nil and STORY.DifficultyLook("Wild") == nil)
print(fails == 0 and "P1S_PURE_OK" or "P1S_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def statics(s: dict) -> list[tuple[str, bool]]:
    hud, qt, npc, panels, cfg = s["HUD"], s["QT"], s["NPC"], s["PANELS"], s["CONFIG"]
    walk = block(hud, "L.NpcWalk")
    tools = block(npc, "StoryNpcs.DrawTools")
    swing = block(npc, "StoryNpcs.OnSwing")
    send = block(npc, "StoryNpcs.SendEmote")
    scene = block(npc, "StoryNpcs.Scene")
    world = block(npc, "StoryNpcs.RefreshWorld")
    return [
        ("the row keeps GuideNpc", "GuideNpc = (type(e.GuideNpc) == \"string\" and e.GuideNpc ~= \"\") and e.GuideNpc or nil," in hud),
        ("a guide / teacher with a body: the tap walks there before RequestTutorial",
         "if e.GuideNpc and L.NpcWalk(e.GuideNpc, zone, panels) then return end" in hud
         and hud.find("if e.GuideNpc and L.NpcWalk") < hud.find('if step == 0 then\n\t\tfire("RequestTutorial")')
         and "showGuide(npc, tostring(name), \"story\", 30)" in walk),
        ("the test / learn goal walks to my teacher", '(e.GoalKind == "SkillTest" or e.GoalKind == "SkillLearn")' in hud
         and 'L.NpcWalk(attr("SkillTeacher", ""), zone, panels)' in hud),
        ("the marker points at the GuideNpc and the test goal at the teacher",
         'pack(body, "npc:" .. entry.GuideNpc' in qt and '(entry.GoalKind == "SkillLearn" or entry.GoalKind == "SkillTest")' in qt),
        ("a Swing near a dummy wobbles it at contact", 'm:GetAttribute("PropType") == "Practice"' in swing
         and "StoryNpcs.Wobble(m)" in swing and 'if kind == "Swing" then\n\t\t\t\tpcall(StoryNpcs.OnSwing, data)' in npc),
        ("the practice tool follows PracticeTool in a bare hand", 'p:GetAttribute("PracticeTool")' in tools
         and 'char:FindFirstChildOfClass("Tool") == nil' in tools and "old:Destroy()" in tools),
        ("an Emote press: the free emote + StoryAction(Id, \"Emote\", name)", 'remote:FireServer(id, "Emote", name)' in send
         and "StoryNpcs.PlayEmote, name" in send),
        ("a StoryScene plays; the saved looks come back from StoryFlags", 'elseif kind == "StoryScene" then' in npc
         and 'key == "Demo"' in scene and "StoryNpcs.ApplyFlags, flags" in world and 'me:GetAttribute("StoryFlags")' in world),
        ("the Refresh pass runs the world pieces", "pcall(StoryNpcs.RefreshWorld, entries, me)" in npc),
        ("a brush past a pickup asks the server once per Again s", "local brush = StoryNpcs.BrushPickup(spots, root and root.Position)" in world
         and 'remote:FireServer(brush.Id, "Pickup")' in world and "WS.Brushed[brush.Id] = os.clock()" in world),
        ("the Offer window draws the difficulty", "STORY.DifficultyLook(def.Difficulty)" in panels
         and 'rim.Name = "Difficulty"' in panels and 'string.rep("★", look.Stars)' in panels),
        ("the emote words live in Config", 'EmoteCheer = "Cheer!", EmoteWave = "Wave"' in cfg),
        ("no ray art: round glows only", "Beam" not in npc and "rays" not in re.sub(r"--[^\n]*", "", npc)),
    ]


MUTATIONS = [
    ("NPC", "the override ignored", "local over = type(faction) == \"string\" and step[faction] or nil\n\t\t\tover = type(over) == \"table\" and over or {}",
     "local over = {}"),
    ("NPC", "no lamp from a guide", 'if string.sub(lamp, 1, 4) == "Lamp" then t, key = "Lamp", lamp else t = nil end', "t = nil"),
    ("NPC", "the buttons everywhere", "if s.Type == \"Emote\" and Util.FlatDistance(pos, s.Pos) <= s.Radius then return s end",
     "if s.Type == \"Emote\" then return s end"),
    ("NPC", "the flags never parse", 'for k, v in string.gmatch(text, "([%w_]+)=([%w_]+)") do out[k] = v end', ""),
    ("PANELS", "Hard shown as Easy", "local g = type(diff) == \"string\" and type(Config.WeaponGrades) == \"table\" and Config.WeaponGrades[map[diff] or \"\"] or nil",
     "local g = type(diff) == \"string\" and type(Config.WeaponGrades) == \"table\" and Config.WeaponGrades.Common or nil"),
    ("HUD", "the tap asks for the tutorial again", "\tif e.GuideNpc and L.NpcWalk(e.GuideNpc, zone, panels) then return end\n", ""),
    ("NPC", "no wobble", "\t\t\ttask.delay(math.max(0, tonumber(data.ContactDelay) or 0.1), function() StoryNpcs.Wobble(m) end)\n", ""),
    ("NPC", "the emote never sent", 'if ok and remote then remote:FireServer(id, "Emote", name) end', ""),
    ("NPC", "a brush only when standing on it", "<= math.min(T.Pickup.Brush, s.Radius) then return s end", "<= 0.5 then return s end"),
    ("NPC", "the brush never sent", 'if ok and remote then remote:FireServer(brush.Id, "Pickup") end', ""),
]


def run(src: dict) -> tuple[bool, list, str]:
    funcs = "".join(block(src["NPC"], n) for n in ("StoryNpcs.Spots", "StoryNpcs.FlagsOf", "StoryNpcs.EmoteAt", "StoryNpcs.EmoteNames",
                                                    "StoryNpcs.BrushPickup"))
    funcs += block(src["PANELS"], "STORY.DifficultyLook")
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "p1s.luau"
        f.write_text(PURE.replace("__FUNC__", funcs), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    st = statics(src)
    return "P1S_PURE_OK" in out and all(g for _, g in st), st, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    src = {k: p.read_text(encoding="utf-8") for k, p in FILES.items()}
    good, st, out = run(src)
    print(out.strip())
    for name, g in st:
        print(("STATIC_OK " if g else "STATIC_FAIL ") + name)
    caught = 0
    for key, name, old, new in MUTATIONS:
        if src[key].count(old) != 1:
            print(f"MUTATION NOT_APPLIED {name} (matched {src[key].count(old)})")
            continue
        m = dict(src)
        m[key] = src[key].replace(old, new)
        bad, _, _ = run(m)
        caught += 0 if bad else 1
        print(("MUTATION caught  " if not bad else "MUTATION MISSED ") + name)
    passed = good and caught == len(MUTATIONS)
    print(f"Status: {'passed' if passed else 'failed'} (statics {sum(g for _, g in st)}/{len(st)}, mutations {caught}/{len(MUTATIONS)})")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
