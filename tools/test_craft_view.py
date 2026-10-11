"""③-2 망치질 고리 화면 (게임성 개발 4, 2026-10-12; SPEC A23-56 / A23-127 / A23-130, design
docs/design/hammer_minigame_2026-10-12.md, contract 게임성 검수 10/12 + 개발 3 origin/dev3-craft), offline.

Runs the CURRENT Config.luau, Shared/CraftMini.luau and CraftView.luau in the official Luau CLI
(tools/fixtures/craft_view_offline.luau; a server clock the test moves, the craft remotes, ContextActionService). Checks:
CraftSession / CraftResult bound at Init; a session opens the screen; Space is the strike and is sunk (no jump); the
screen itself is the button (clicks / taps never reach the HUD); a press before the first ring / in the rest does
nothing; a press grades with CraftMini and sends CraftStrike(Id, i, ms) once per ring (40 ms = Perfect, 200 ms = Good);
the dot / word / sound / shake; a ring nobody pressed turns Miss without a strike; the ring's size follows the schedule
(1.8x half way, 1x at the touch); CraftFinish(Id) once after the last ring; a result for another session is ignored; the
result line ("+1 <weapon>"), Skip hidden, the done sound, closing after it (Space unbound); Skip = CraftFinish now and
closing after a few seconds without an answer; the Studio practice (no remote, graded here, "+2"; its Skip just
closes); a click on the screen is the strike. Static: ClientMain loads CraftView; CraftView takes its numbers from
CraftMini (no own windows). Mutations: each must be caught.

Usage: py tools/test_craft_view.py
Report: docs/art/verification_2026-10-12/offline_craft_view_2026-10-12.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"VIEW": ROOT / "src/StarterPlayer/StarterPlayerScripts/CraftView.luau",
         "MINI": ROOT / "src/ReplicatedStorage/Shared/CraftMini.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/craft_view_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-12/offline_craft_view_2026-10-12.json"

MUTATIONS = [
    ("VIEW", "two strikes on one ring", "\tif not i or S.Grades[i] then return nil end\n", "\tif not i then return nil end\n"),
    ("VIEW", "the offset's sign flipped", "\tlocal ms = (t - CraftMini.Target(s.StartAt, i)) * 1000\n",
     "\tlocal ms = (CraftMini.Target(s.StartAt, i) - t) * 1000\n"),
    ("VIEW", "practice talks to the server", "\tif not s.Practice and not S.Sent[i] and math.abs(ms) <= CraftMini.T.MaxMs then\n",
     "\tif not S.Sent[i] and math.abs(ms) <= CraftMini.T.MaxMs then\n"),
    ("VIEW", "a far too early press is sent", "and not S.Sent[i] and math.abs(ms) <= CraftMini.T.MaxMs then", "and not S.Sent[i] then"),
    ("VIEW", "Finish twice", "\tif not s or S.Finished then return end\n\tS.Finished = os.clock()",
     "\tif not s then return end\n\tS.Finished = os.clock()"),
    ("VIEW", "no Miss when a ring closes", "\t\tif not S.Grades[i] and t >= CraftMini.Closes(s.StartAt, i) then\n",
     "\t\tif false then\n"),
    ("VIEW", "jumping stays on (Space / A jump)", "\t\t\tpcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false) end)\n", ""),
    ("VIEW", "jumping never comes back", "\t\tif hum then pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true) end) end\n", ""),
    ("VIEW", "the jump key is no strike", "\t\t\tlast = os.clock()\n\t\t\tCraftView.Press()\n", "\t\t\tlast = os.clock()\n"),
    ("VIEW", "a held jump key strikes every frame", "\t\t\tif os.clock() - last < V.JumpGap then return end\n", ""),
    ("VIEW", "the jump listener never stops", "\t\tif UI.Jump then pcall(function() UI.Jump:Disconnect() end) end\n", ""),
    ("VIEW", "another session's result shown", "if not s or (payload.Id ~= s.Id and not payload.Practice) then return end",
     "if not s then return end"),
    ("VIEW", "never closes after the result", "\tif S.ResultAt and os.clock() - S.ResultAt >= V.Hold then\n",
     "\tif false then\n"),
    ("VIEW", "waits forever without a result", "\telseif S.Finished and not S.ResultAt and os.clock() - S.Finished >= V.ResultWait then\n",
     "\telseif false then\n"),
    ("VIEW", "Skip sends nothing", "\tfinish()\nend\n\n-- one frame", "end\n\n-- one frame"),
    ("VIEW", "the ring ignores the schedule", "(1 + V.Grow * (1 - f))", "(1 + V.Grow)"),
    ("VIEW", "no practice in Studio", "\t\t\t\tCraftView.Begin({ Id = 0, StartAt = now() + CraftMini.T.Lead }, true)\n", ""),
    ("VIEW", "the screen is not a button", "\troot.Activated:Connect(function() CraftView.Press() end)\n", ""),
    ("VIEW", "an open window stays under the ring (UiSandbox 10/12)", "\t\tif ok and open then pcall(panels.Close) end\n", ""),
    ("MAIN", "the view is never loaded", "\"GatherView\", \"CraftView\",", "\"GatherView\","),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    code = "\n".join(l for l in src["VIEW"].splitlines() if not l.strip().startswith("--"))
    return [
        ("ClientMain loads CraftView after UIKit", "CraftView" in names and "UIKit" in names
         and names.index("CraftView") > names.index("UIKit")),
        ("CraftView grades with the shared CraftMini (no own windows / points)",
         "CraftMini.Grade(ms)" in code and "CraftMini.Score(" in code and "Windows" not in code and "PlusAt" not in code
         and "Points" not in code),
        ("no fixed key in CraftView (BB1: the jump request, whatever key the player uses; 게임성 검수 10/12)",
         "Enum.KeyCode" not in code and "UserInputService.JumpRequest:Connect(" in code),
    ]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal MINI_SOURCE = " + lua_str(src["MINI"])
            + "\nlocal VIEW_SOURCE = " + lua_str(src["VIEW"]) + "\n" + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "craft_view.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"CRAFT_VIEW_SUMMARY checks=(\d+) failed=(\d+)", out)
    failed = int(m[2]) if m else 1
    st = static(src)
    for name, ok in st:
        out += ("\nSTATIC_OK " if ok else "\nSTATIC_FAIL ") + name
        failed += 0 if ok else 1
    return (int(m[1]) if m else 0) + len(st), failed, out


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = {k: p.read_text(encoding="utf-8-sig").replace("\r\n", "\n") for k, p in FILES.items()}
    checks, failed, out = run(src)
    print(out.strip())
    muts = []
    for key, name, old, new in MUTATIONS:
        hits = src[key].count(old)
        caught = False
        if hits == 1:
            m = dict(src)
            m[key] = src[key].replace(old, new)
            caught = run(m)[1] > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if failed == 0 and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": failed, "mutations": muts, "status": status,
                               "contract": __doc__.split("Usage")[0].strip(), "studioCalls": 0}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, failed {failed}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
