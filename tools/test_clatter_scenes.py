"""A23-212 Captain Clatter's town scenes + his match lines - the screen part (게임성 개발 1; server = 개발 2
dev2-clatter-guide ClatterScenes / BarkService).

Runs, in the official Luau CLI (build/luau_cli_0_741), MonsterLabels B.SureMoment cut out of the source: a bark text
that is one of a kind's sure lines (Config.Barks.Lines[kind].Start / .Beaten) -> that moment, else nil. Static:
- Fx StoryScene Id "Clatter" reaches StoryNpcs.ClatterScene (Key / Pos / Look);
- his body = the opening's sword-free part body (Intro.ClatterBody / Intro.PlaceClatter; A23-214), standing on the
  ground at Pos (StoryNpcs.GroundAt) facing Look; every Config Scenes Move has a pose (BowHatSlip / CatchHat /
  CarrySalute); the Line shows in the story bubble over his head; he fades out after Config Stay;
- a sure line shows in the wide story bubble (StoryNpcs.Bubble); a beaten body says only its Beaten line.
Mutations: in-memory copies with one rule broken each; each must be caught.

Usage: py tools/test_clatter_scenes.py
Report: docs/art/verification_2026-10-16/offline_clatter_scenes_2026-10-16.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"NPCS": SPS / "StoryNpcs.luau", "INTRO": SPS / "Intro.luau", "LABELS": SPS / "MonsterLabels.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau"}
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-16/offline_clatter_scenes_2026-10-16.json"

FIXTURE = r'''
local checks, failed = 0, 0
local function check(name, ok) checks += 1 if ok then print("CHECK_OK " .. name) else failed += 1 print("CHECK_FAIL " .. name) end end
Config = { Barks = { Lines = { CaptainClatter = { Start = { "Your turn, captain. Ready for a match?" },
	Beaten = { "Good match! I need a sit-down." }, Spot = { "HALT!!" } }, Slime = { Spot = { "Blub!" } } } } }
check("a Start line = Start", B.SureMoment("CaptainClatter", "Your turn, captain. Ready for a match?") == "Start")
check("a Beaten line = Beaten", B.SureMoment("CaptainClatter", "Good match! I need a sit-down.") == "Beaten")
check("a Spot line is no sure line", B.SureMoment("CaptainClatter", "HALT!!") == nil)
check("a kind without sure lines = nil", B.SureMoment("Slime", "Blub!") == nil and B.SureMoment("Nope", "x") == nil)
print(("CLATTER_SUMMARY checks=%d failed=%d"):format(checks, failed))
'''

STATIC = [
    ("NPCS", "Fx StoryScene Id Clatter reaches ClatterScene", ['if data.Id == "Clatter" then', "return StoryNpcs.ClatterScene(key, data.Pos, data.Look)"]),
    ("NPCS", "his body = the opening's part body (no sword), posed by Intro", [
        "local ok, c = pcall(intro.ClatterBody, folder, T.Clatter.Scale)", "pcall(intro.PlaceClatter, c, pose.Root, pose.Head, pose.Aims)"]),
    ("NPCS", "town size: about 1.3 x a player (body, pose and box all shrink)", [
        "Scale = 0.68,", "pcall(StoryNpcs.ClatterPose, sc.Move, t, home, T.Clatter.Scale)", "T.Clatter.Box * T.Clatter.Scale",
        "local function at(x, y, z) return home * CFrame.new(x * u, y * u, z * u) end"]),
    ("NPCS", "the caught helmet is held up over his head, not at his chest", ["local caught = (at(0, 9.75, -0.6)).Position"]),
    ("INTRO", "the opening keeps its size; scale shrinks every part and offset", [
        "s.Clatter = SCENE.Clatter()\n", "Size = size * sc,", "local function at(x, y, z) return CFrame.new(x * sc, y * sc, z * sc) end"]),
    ("NPCS", "on the ground at Pos, facing Look", ["local feet = Vector3.new(pos.X, StoryNpcs.GroundAt(pos), pos.Z)", "local home = CFrame.lookAt(feet, face)"]),
    ("NPCS", "every move has a pose", ['if move == "BowHatSlip" then', 'elseif move == "CatchHat" then', 'elseif move == "CarrySalute" then']),
    ("NPCS", "his line in the story bubble over his head", ["pcall(StoryNpcs.Bubble, c.Head, sc.Line, T.Clatter.Line)"]),
    ("NPCS", "he goes after Stay", ["local stay = tonumber(K.Stay) or 8", "if t >= stay then"]),
    ("INTRO", "the part body is shared from the opening", ["function Intro.ClatterBody(parent, scale)", "function Intro.PlaceClatter(c, root, head, aims)"]),
    ("INTRO", "the body's part list is filled apart from c (PhoneTest 10/16: c.All grew while walked = endless loop)", [
        "\t\t\t\ttable.insert(all, p)\n", "\tc.All = all\n"]),
    ("LABELS", "a sure line = the wide story bubble", ["local sure = B.SureMoment(kindOf(model), text)", "pcall(npcs.Bubble, att, text, B.SureShow)"]),
    ("LABELS", "a beaten body says only its Beaten line", ['if root.Anchored and sure ~= "Beaten" then return end',
                                                       "B.Check(model, root, bb, me) -- A23-212: only a sure Beaten line"]),
]


def moves_in_config(cfg: str) -> list[str]:
    m = re.search(r"Config\.StoryQuests\.Clatter = \{(.*?)\n\}", cfg, re.S)
    return re.findall(r'Move = "(\w+)"', m[1]) if m else []


def run(files: dict[str, str]) -> tuple[int, int, str]:
    m = re.search(r"\nfunction B\.SureMoment\(.*?\nend\n", files["LABELS"], re.S)
    out, failed, checks = "", 0, 0
    if not m:
        failed += 1
        out += "\nCHECK_FAIL B.SureMoment not found"
    else:
        lua = "local B = {}\n" + m[0] + FIXTURE
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "clatter.luau"
            p.write_text(lua, encoding="utf-8")
            proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
        out += proc.stdout + proc.stderr
        mm = re.search(r"CLATTER_SUMMARY checks=(\d+) failed=(\d+)", out)
        checks += int(mm[1]) if mm else 0
        failed += int(mm[2]) if mm else 1
    for fk, name, needles in STATIC:
        ok = all(files[fk].count(n) == 1 for n in needles)
        checks += 1
        failed += 0 if ok else 1
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
    moves = moves_in_config(files["CONFIG"])
    # (10/16 dev 2: chapter 2 adds a 4th scene, Tools, on an existing pose: every scene needs a pose, 3 or more)
    ok = len(moves) >= 3 and all(f'move == "{mv}"' in files["NPCS"] for mv in moves)
    checks += 1
    failed += 0 if ok else 1
    out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + f"every Config Scenes Move has a pose {moves}"
    return checks, failed, out


MUTATIONS = [
    ("NPCS", "the scene never plays", 'if data.Id == "Clatter" then', 'if data.Id == "ClatterX" then'),
    ("NPCS", "the borrowed knight (sword) instead", "local ok, c = pcall(intro.ClatterBody, folder, T.Clatter.Scale)", "local ok, c = false, nil"),
    ("NPCS", "a giant in town (opening size)", "local ok, c = pcall(intro.ClatterBody, folder, T.Clatter.Scale)", "local ok, c = pcall(intro.ClatterBody, folder)"),
    ("NPCS", "small body, opening-size pose", "pcall(StoryNpcs.ClatterPose, sc.Move, t, home, T.Clatter.Scale)", "pcall(StoryNpcs.ClatterPose, sc.Move, t, home)"),
    ("NPCS", "helmet back at his chest like a box", "local caught = (at(0, 9.75, -0.6)).Position", "local caught = (at(0, 6.9, -1.6)).Position"),
    ("INTRO", "the opening shrinks too", "s.Clatter = SCENE.Clatter()\n", "s.Clatter = SCENE.Clatter(0.68)\n"),
    ("NPCS", "floats at Pos (no ground)", "local feet = Vector3.new(pos.X, StoryNpcs.GroundAt(pos), pos.Z)", "local feet = pos"),
    ("NPCS", "no line", "pcall(StoryNpcs.Bubble, c.Head, sc.Line, T.Clatter.Line)", "pcall(print, sc.Line)"),
    ("NPCS", "he never goes", "if t >= stay then", "if false then"),
    ("INTRO", "the part list grows while it is walked again", "\t\t\t\ttable.insert(all, p)\n", "\t\t\t\ttable.insert(c.All or all, p)\n"),
    ("LABELS", "a Spot line counts as sure", 'for _, moment in { "Start", "Beaten" } do', 'for _, moment in { "Start", "Beaten", "Spot" } do'),
    ("LABELS", "a beaten body speaks any line", 'if root.Anchored and sure ~= "Beaten" then return end', ""),
    ("LABELS", "sure lines in the small round bubble", "pcall(npcs.Bubble, att, text, B.SureShow)\n\t\treturn\n", "pcall(print, text)\n"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    files = {k: p.read_text(encoding="utf-8").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(files)
    print(out.strip())
    muts = []
    for fk, name, old, new in MUTATIONS:
        hits = files[fk].count(old)
        caught = False
        if hits == 1:
            copy = dict(files)
            copy[fk] = files[fk].replace(old, new)
            caught = run(copy)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
