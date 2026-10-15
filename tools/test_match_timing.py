"""Quest shape match and workbench timing (퀘스트 바이블 §15 P1 ④, 10/15), offline.

Runs the CURRENT Panels STORY.TimingResult in the official Luau CLI (Good or better strikes counted, 5 tries) and checks
the wiring: OpenPanel "Timing" runs the anvil's ring screen (CraftView, a local session) and its strikes go back as
StoryAction(Id, "Timing", { Good, Tries }); the "Match" window shows the target and three options drawn by Shape AND
colour (no art needed), a pick sends StoryAction(Id, "Match", n), Fx MatchHit closes it, MatchMiss shakes that option
(UIKit.Refuse) and lets me pick again. Each mutation must make a check fail.

Usage: py tools/test_match_timing.py
"""
from __future__ import annotations

from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SPS = ROOT / "src/StarterPlayer/StarterPlayerScripts"
FILES = {"PANELS": SPS / "Panels.luau", "CV": SPS / "CraftView.luau"}
LUAU = ROOT / "build/luau_cli_0_741/luau.exe"
if not LUAU.exists():
    LUAU = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"

PURE = r"""
local STORY = {}
__FUNC__
local fails = 0
local function check(name, ok, detail)
	print((ok and "CHECK_OK " or "CHECK_FAIL ") .. name .. (ok and "" or (" :: " .. tostring(detail))))
	if not ok then fails += 1 end
end
local r = STORY.TimingResult({ "Perfect", "Great", "Good", "Miss", "Miss" })
check("Good or better counted, 5 tries", r.Good == 3 and r.Tries == 5, r.Good)
check("all missed: 0", STORY.TimingResult({ "Miss", "Miss", "Miss", "Miss", "Miss" }).Good == 0)
check("nothing: 0, never an error", STORY.TimingResult(nil).Good == 0)
print(fails == 0 and "MT_PURE_OK" or "MT_PURE_FAILED")
"""


def block(src: str, name: str) -> str:
    m = re.search(r"^function " + re.escape(name) + r"\(.*?^end\n", src, re.S | re.M)
    return m.group(0) if m else ""


def statics(s: dict) -> list[tuple[str, bool]]:
    p, cv = s["PANELS"], s["CV"]
    match = p[p.find("BUILDERS.Match = function(parent)"):]
    match = match[:match.find("\nend\n")]
    on = block(p, "STORY.OnMatch")
    shape = block(p, "STORY.DrawShape")
    return [
        ("OpenPanel Timing = the anvil's ring screen", 'if id == "Timing" then\n\t\tSTORY.Timing(arg)\n\t\treturn' in p
         and "view.Begin({ Id = \"quest:\" .. arg.Id," in p),
        ("the strikes go back to the quest", 'fire("StoryAction", arg.Id, "Timing", STORY.TimingResult(grades))' in p
         and "if type(s.OnDone) == \"function\" then pcall(s.OnDone, table.clone(S.Grades)) end" in cv),
        ("only a practice session reports", "OnDone = practice == true and type(onDone) == \"function\" and onDone or nil" in cv),
        ("Match: target + three options, a pick goes to the server once", "if i > 3 then break end" in match
         and 'fire("StoryAction", arg.Id, "Match", i)' in match and "if STORY.MatchWait then return end" in match),
        ("shapes by form too, not colour alone", all(k in shape for k in ('"Ring"', '"Disc"', '"Square"', '"Diamond"', '"Cross"'))),
        ("hit closes, miss shakes the pick",
         'if kind == "MatchHit" then\n\t\tif currentId == "Match" then Panels.Close() end\n\t\treturn\n\tend' in on and "pcall(UIKit.Refuse, b)" in on),
        ("the answer is heard", 'if kind == "MatchHit" or kind == "MatchMiss" then pcall(STORY.OnMatch, kind, data) end' in p),
    ]


MUTATIONS = [
    ("PANELS", "Timing never reported", 'fire("StoryAction", arg.Id, "Timing", STORY.TimingResult(grades))', "local _ = grades"),
    ("PANELS", "misses count", 'if g == "Good" or g == "Great" or g == "Perfect" then good += 1 end', "good += 1"),
    ("PANELS", "double picks", "\t\t\tif STORY.MatchWait then return end\n", ""),
    ("PANELS", "a miss closes the window", "\tif kind == \"MatchHit\" then\n", "\tif true then\n"),
    ("CV", "a real craft reports to quests", "OnDone = practice == true and type(onDone) == \"function\" and onDone or nil",
     "OnDone = type(onDone) == \"function\" and onDone or nil"),
]


def run(src: dict) -> tuple[bool, list, str]:
    with tempfile.TemporaryDirectory() as d:
        f = Path(d) / "mt.luau"
        f.write_text(PURE.replace("__FUNC__", block(src["PANELS"], "STORY.TimingResult")), encoding="utf-8")
        r = subprocess.run([str(LUAU), str(f)], capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = r.stdout + r.stderr
    st = statics(src)
    return "MT_PURE_OK" in out and all(g for _, g in st), st, out


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
