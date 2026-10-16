"""A23-212 (user 2026-10-16 "처음부터 … 범인이 누구인지 밝히고") - the opening's first shot shows Captain Clatter breaking
the crown (게임성 개발 1). Static checks on src/StarterPlayer/StarterPlayerScripts/Intro.luau:
- shot 1 builds the set (SCENE.Build: a part crown in two halves on a pedestal, Clatter's codex copy
  ReplicatedStorage.CodexModels.CaptainClatter, a part clamp), Up studs over the sky crown, and keeps the old crown shot
  when the set cannot be built;
- the order of the beats: the crown wobbles until the clamp is on, the clamp moves in and shuts, CRACK after that, the
  halves drift apart, he hops back and reaches out (upper-arm bones) after the crack;
- the subtitle line 1 still comes at 0.4 s, the shot lasts SCENE.Length (6 s, like the old one), every frame stops when
  the opening is skipped (token);
- 0 won: no new asset ids in the scene.
Mutations: in-memory copies with one rule broken each; each must be caught.

Usage: py tools/test_intro_clatter.py
Report: docs/art/verification_2026-10-16/offline_intro_clatter_2026-10-16.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
INTRO = ROOT / "src/StarterPlayer/StarterPlayerScripts/Intro.luau"
OUT = ROOT / "docs/art/verification_2026-10-16/offline_intro_clatter_2026-10-16.json"

NEEDLES = [
    ("shot 1 builds the set over the sky crown", ["local okSet, set = pcall(SCENE.Build, crown + Vector3.new(0, SCENE.Up, 0))"]),
    ("Clatter = a part body (no borrowed knight mesh, no sword)", ["s.Clatter = SCENE.Clatter()",
        'Helmet = part("Helmet", Enum.PartType.Cylinder']),
    ("he checks the crown first, head tilted, before it wobbles", ["local tilt = t < K.WobbleAt and math.sin(t * 5) * K.Check or 0"]),
    ("the old crown shot stays as the fallback", ["\telse\n\t\tlocal c = CROWN_SHOT\n"]),
    ("subtitle 1 at 0.4 s", ["if not said and t >= 0.4 then"]),
    ("skip stops the scene", ["\t\t\tif state.Token ~= token then return end\n"]),
    ("the crown wobbles from WobbleAt until the clamp is on", ["\tif t >= K.WobbleAt and t < K.ClampIn then\n\t\tw = K.Wobble"]),
    ("the clamp moves in, then shuts", ["local move = math.clamp((t - K.ClampAt) / (K.ClampIn - K.ClampAt), 0, 1)",
                                        "local shut = math.clamp((t - K.ClampIn) / K.Shut, 0, 1)"]),
    ("CRACK once, then the halves drift apart", ["if t >= K.CrackAt and not s.Cracked then",
                                                 "local drift = t >= K.CrackAt and math.clamp((t - K.CrackAt) / K.Drift, 0, 1) or 0"]),
    ("after the crack he hops back and reaches out", ["local back = math.clamp((t - K.CrackAt - 0.1) / 0.35, 0, 1)",
                                                      "local reach = math.clamp((t - K.CrackAt - 0.15) / K.ReachIn, 0, 1)",
                                                      "local aimL = restL:Lerp(toCrown + Vector3.new(0, 0, -1.2), reach)"]),
    ("only the clamp is in his hand, and only until the crack (then empty hands)", [
        "local hand = (t < K.CrackAt) and (jawAt - Vector3.new(1.1, 0, 0)) or nil"]),
]


def run(src: str) -> tuple[int, int, list[str]]:
    lines, checks, failed = [], 0, 0

    def check(name, ok, detail=""):
        nonlocal checks, failed
        checks += 1
        failed += 0 if ok else 1
        lines.append(("CHECK_OK " if ok else "CHECK_FAIL ") + name + ("" if ok else f" :: {detail}"))

    for name, needles in NEEDLES:
        miss = [n for n in needles if src.count(n) != 1]
        check(name, not miss, miss)
    a = src.find("\nlocal SCENE = {")
    body = src[a:src.find("\n", src.find("Length = ", a))] if a >= 0 else ""
    num = {k: float(v) for k, v in re.findall(r"(\w+) = ([\d.]+)[,\s]", body)}
    check("beats in order: check < wobble < clamp starts < clamp on < crack < shot end",
          0 < num.get("WobbleAt", 0) < num.get("ClampAt", 0) < num.get("ClampIn", 0) < num.get("ClampIn", 0) + num.get("Shut", 9) <= num.get("CrackAt", 0)
          < num.get("Length", 0), num)
    check("the shot is as long as the old one (6 s)", num.get("Length") == 6, num.get("Length"))
    scene = src[src.find("\nlocal SCENE = {"):src.find("\nlocal function run(token)")]
    check("0 won: no asset ids in the scene", "rbxassetid" not in scene and "rbxasset://" not in scene, "")
    check("no weapon in the scene (최종 검수 10/16: a sword read as cutting the crown)",
          not re.search(r"sword|blade|CodexModels|Tool", scene, re.I), "")
    return checks, failed, lines


MUTATIONS = [
    ("no set (always the old shot)", "local okSet, set = pcall(SCENE.Build,", "local okSet, set = false, nil --"),
    ("crack before the clamp", "CrackAt = 3.0,", "CrackAt = 1.0,"),
    ("the crown keeps wobbling", "\tif t >= K.WobbleAt and t < K.ClampIn then\n\t\tw = K.Wobble", "\tif t < 99 then\n\t\tw = K.Wobble"),
    ("he reaches before the crack", "local reach = math.clamp((t - K.CrackAt - 0.15) / K.ReachIn, 0, 1)",
     "local reach = math.clamp(t / K.ReachIn, 0, 1)"),
    ("he keeps the clamp after the crack", "local hand = (t < K.CrackAt) and", "local hand = (t < 99) and"),
    ("no head tilt", "math.sin(t * 5) * K.Check or 0", "0 or 0"),
    ("the knight mesh back", "\ts.Clatter = SCENE.Clatter()\n", "\ts.Clatter = SCENE.Clatter() -- CodexModels\n"),
    ("skip does not stop it", "\t\t\tif state.Token ~= token then return end\n", "\t\t\tif false then return end\n"),
    ("a paid asset", "Length = 6 }", 'Length = 6, Img = "rbxassetid://1" }'),
    ("no subtitle", "if not said and t >= 0.4 then", "if not said and t >= 99 then"),
]


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    src = INTRO.read_text(encoding="utf-8").replace("\r\n", "\n")
    checks, failed, lines = run(src)
    print("\n".join(lines))
    muts = []
    for name, old, new in MUTATIONS:
        hits = src.count(old)
        caught = hits == 1 and run(src.replace(old, new))[1] > 0
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
