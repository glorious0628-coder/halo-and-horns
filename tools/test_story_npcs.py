"""StoryNpcs (게임성 개발 1, 빛 마을 점검 #22 / #25 / #30; server = 게임성 개발 3's TownNpcs,
docs/design/town_npcs_server_2026-10-10.md), offline.

Runs, in the official Luau CLI, the CURRENT Config.luau and StoryNpcs.luau in tools/fixtures/story_npcs_offline.luau.
Checks: StoryNpcs.Called = the NPC ids my quest rows talk through (Story.Npc); an NPC no row talks through has no "!"
and her Talk prompt (attribute StoryNpcId) is hidden on this client; a row through her shows both; other prompts are
never touched; one "!" per NPC over her head, near players only; the row moving to another NPC moves the "!" and the
prompt; an NPC out of the world is left alone. Static: ClientMain loads StoryNpcs after HUD and QuestMarker.
Mutations: each must be caught.

Usage: py tools/test_story_npcs.py
Report: docs/art/verification_2026-10-10/offline_story_npcs_2026-10-10.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FILES = {"NPC": ROOT / "src/StarterPlayer/StarterPlayerScripts/StoryNpcs.luau",
         "CONFIG": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
         "MAIN": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau"}
FIXTURE = ROOT / "tools/fixtures/story_npcs_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
if not BINARY.exists():
    BINARY = ROOT.parent / "Game/build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_story_npcs_2026-10-10.json"

MUTATIONS = [
    ("NPC", "the first mission's guide is not called (no Talk prompt on Hallie, 10/16)", "if type(e) == \"table\" and type(e.GuideNpc) == \"string\" and e.GuideNpc ~= \"\" then out[e.GuideNpc] = true end", ""),
    ("NPC", "the '!' always shows", "\t\t\t\tbb.Enabled = on\n", "\t\t\t\tbb.Enabled = true\n"),
    ("NPC", "the Talk prompt never hides", " and d.Enabled ~= on then d.Enabled = on end", " and false then d.Enabled = on end"),
    ("NPC", "every prompt is toggled", "d:IsA(\"ProximityPrompt\") and d:GetAttribute(\"StoryNpcId\") ~= nil", "d:IsA(\"ProximityPrompt\")"),
    ("NPC", "a new '!' every pass", "\tif bb then\n\t\t-- 검수 10/10 (API review", "\tif false then\n\t\t-- 검수 10/10 (API review"),
    ("NPC", "the '!' stays on the old head", "if head and bb.Adornee ~= head then bb.Adornee = head end", "local _ = head"),
    ("NPC", "extra '!' copies stay", "if bb then ch:Destroy() else bb = ch end", "if not bb then bb = ch end"),
    ("NPC", "rows without an NPC count", "\t\tif type(st) == \"table\" and type(st.Npc) == \"string\" and st.Npc ~= \"\" then out[st.Npc] = true end",
     "\t\tif type(st) == \"table\" and type(st.Npc) == \"string\" then out[st.Npc] = true end"),
    ("NPC", "the '!' on the feet", "\tbb.StudsOffsetWorldSpace = Vector3.new(0, T.MarkLift, 0)\n", ""),
    ("NPC", "a Talk press does not open at once", "\tpcall(panels.ExpectStory, tostring(id))\n", ""),
    ("NPC", "every prompt expects a page", 'local id = typeof(prompt) == "Instance" and prompt:GetAttribute("StoryNpcId") or nil',
     'local id = typeof(prompt) == "Instance" and "x" or nil'),
    ("MAIN", "the module is never loaded", "\"QuestMarker\", \"StoryNpcs\",", "\"QuestMarker\","),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def static(src: dict) -> list[tuple[str, bool]]:
    order = re.search(r"local ORDER = \{([^}]*)\}", src["MAIN"])
    names = re.findall(r'"(\w+)"', order.group(1)) if order else []
    return [("ClientMain loads StoryNpcs after HUD and QuestMarker", "StoryNpcs" in names and "HUD" in names
             and "QuestMarker" in names and names.index("StoryNpcs") > names.index("QuestMarker") > names.index("HUD"))]


def run(src: dict) -> tuple[int, int, str]:
    text = ("local CONFIG_SOURCE = " + lua_str(src["CONFIG"]) + "\nlocal NPC_SOURCE = " + lua_str(src["NPC"]) + "\n"
            + FIXTURE.read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory() as d:
        p = Path(d) / "story_npcs.luau"
        p.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(BINARY), str(p)], capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=120)
    out = proc.stdout + proc.stderr
    m = re.search(r"STORY_NPCS_SUMMARY checks=(\d+) failed=(\d+)", out)
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
