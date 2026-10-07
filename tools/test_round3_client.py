"""Round 3 'first 10 minutes' client pieces in HUD.luau (docs/design/ideas_first10_2026-10-07.md §3-4, game dev 1):
#1 line 2 after the pinned row = the waiting story -> a claim -> the S0 shard story (until auto combat is unlocked) ->
the first daily, in both the phone header line and the two quest lines; the PC list has no daily header before the
first mission is accepted (step 0); a seconds row's ProgressUnit follows the target ('5/10 s', dev2 2c5e84e).
#3 one tap on the phone quest block whose line 1 is the step-0 pinned row ('Tap here: first quest from Hallie') opens
the guide (L.PinnedTap) instead of the list.
Static source checks (HUD.luau is too large for an offline run of refreshQuests); each check names the exact code.
Report: docs/art/verification_2026-10-07/offline_round3_client_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parents[1]
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_round3_client_2026-10-07.json"


def block(src: str, head: str) -> str:
    i = src.find(head)
    if i < 0:
        return ""
    j = src.find("\nend\n", i)
    return src[i:j + 4] if j > 0 else ""


def main():
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    tap = block(hud, "function L.QuestBlockTap()")
    refresh = hud[hud.find("refreshQuests = function()"):]
    refresh = refresh[:refresh.find("\nend\n") + 4] if refresh else ""
    nums = block(hud, "local function questNums(e)")
    checks = [
        ("#3 the step-0 pinned line opens the guide in one tap (before the claim / list paths)",
         "if e and e.Pinned and e.TutorialStep == 0 and L.PinnedTap then" in tap
         and tap.find("e.TutorialStep == 0") < tap.find("e.Progress >= e.Target")),
        ("#1 S0 is looked up only until auto combat is unlocked",
         'if attr("AutoCombatUnlocked", false) ~= true then' in refresh and 'e.Story and e.Story.Id == "S0"' in refresh),
        ("#1 phone header line 2: story -> claim -> S0 -> daily", "second = callIndex or firstClaim or s0 or firstDaily" in refresh),
        ("#1 quest line 2: story -> claim -> S0 -> daily", "local alt = callIndex or firstClaim or s0 or firstDaily" in refresh),
        ("#1 PC: no daily header at step 0",
         "ui.questHeader.Visible = not (entries[1] and entries[1].Pinned and entries[1].TutorialStep == 0)" in refresh),
        ("ProgressUnit kept from the server row (<= 3 letters)",
         re.search(r"ProgressUnit = \(type\(e\.ProgressUnit\) == \"string\" and #e\.ProgressUnit > 0 and #e\.ProgressUnit <= 3\)", hud)
         is not None),
        ("ProgressUnit follows the target: '5/10 s'", 'if e.ProgressUnit then t = t .. " " .. e.ProgressUnit end' in nums),
    ]
    for name, good in checks:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = all(g for _, g in checks)
    report = {"status": "passed" if passed else "failed", "static": [{"check": n, "ok": g} for n, g in checks],
              "sourceSHA256": {HUD.relative_to(ROOT).as_posix(): hashlib.sha256(HUD.read_bytes()).hexdigest()},
              "studioCalls": 0, "contract": __doc__.split("Static")[0].strip(),
              "limitations": "Static only; the phone tap and the line order are a Studio check (fresh save, phone)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']}")


if __name__ == "__main__":
    main()
