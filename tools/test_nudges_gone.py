"""Off nudges deleted as a kind (게임성 개발 1, 최종 검수 10/15; user rule: a UI the user disliked goes with its code, never
behind a switch).

Static: Config.Nudges keeps only the live client switches (PadGlow, TravelPulse); the 4 off server ones (GuideDone,
EnteredSafe, DailyReady, WeaponUsableNow - 개발 2's files, deleted 10/15 with their lines) and the 11 off client switches (DailiesOpened, QuestHead, WarIntro,
GooseSub, AttackHint, ShopFarewell, ZoneStoryLine, SackLore, HuntSlimes, GuideLabel, GuideBeam) are gone from Config and
no client module reads them; their drawing code is gone too: the 'Quests (N) ▼' head row + its ▼ (HUD), the HUD.Hint
bubbles, the guide's ground Beam and floating name chip (the guide target itself stays: QuestMarker / the minimap read
it), the goose bar's line under it (EventHUD TugSub), the sack lore flag, the merchant's farewell (Panels), and the
words only they used. The kept quest way (A23-199 path, PadGlow, TravelPulse) still runs. Mutations: in-memory copies
with one rule broken each; each must be caught.

Usage: py tools/test_nudges_gone.py
Report: docs/art/verification_2026-10-15/offline_nudges_gone_2026-10-15.json
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "src/StarterPlayer/StarterPlayerScripts"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
OUT = ROOT / "docs/art/verification_2026-10-15/offline_nudges_gone_2026-10-15.json"

GONE = ["DailiesOpened", "QuestHead", "WarIntro", "GooseSub", "AttackHint", "ShopFarewell", "ZoneStoryLine", "SackLore",
        "HuntSlimes", "GuideLabel", "GuideBeam", "GuideDone", "EnteredSafe", "DailyReady", "WeaponUsableNow"]
KEPT = ["PadGlow = true,", "TravelPulse = true,"]
# drawing code / words that went with them: file key -> strings that must not appear
ABSENT = {
    "HUD": ["ui.questHead", "QuestHeadOn", "ui.questFold", "function HUD.Hint(", "HUD.ClearHint", "L.Hints",
            "L.HintCfg", "HUDGuideBeam", "HUDGuideLabel", "attachGuideToCharacter", "L.GuideLabel", "TXT.HintClick",
            "TXT.QuestOpenList"],
    "EVENT": ["TugSub", "loreShown", "TXT.HintHalo", "MyCount"],
    "PANELS": ["WSHOP.Farewell", "WeaponBye"],
    "CONFIG": ["WeaponBye", "Config.StoryLines", 'GuideDone = "', 'EnteredSafe = "', 'DailyReady = "', 'WeaponUsableNow = "',
               'WeaponUsableNowEn = "', "HintTap =", "HintClick =", "HintSkill =", "QuestOpenList =",
               "QuestCloseList =", 'QuestHead = "', 'WarIntro = "', 'HuntSlimes = "', 'DailiesOpened = "', 'SackLore = "',
               "HudSub =", "HudFull =", "HudOther =", "HintHalo =", "HintHorns ="],
    # the 4 server lines (개발 2, 10/15)
    "QUEST": ["hadNextGoal", "TUT_MESSAGES.GuideDone", "Text.DailyReady"],
    "ZONE": ['fmt("EnteredSafe")'],
    "LOOT": ["onLeveledUp", "Text.WeaponUsableNow", "STATE.Level"],
}
# what must keep running
PRESENT = {
    "HUD": ["\tlocal g = { Tag = tag, Part = part }\n\tguide = g\n", "L.PadGlow(HUD.PadGlowOn(step, zone, (Config.Nudges or {}).PadGlow), zone)",
            "HUD.TravelPulse(num(\"TutorialStep\", 99), L.TravelSeen, (Config.Nudges or {}).TravelPulse)",
            "function L.PlaceTrackerHead()", "\tblock.Position = UDim2.fromOffset(q.X, q.Y)\n"],
    "EVENT": ["\t\t{ Inst = ui.Tug, W = STRIP_W, H = BAR_H, Strip = true },\n"],
}
MUTATIONS = [
    ("CONFIG", "a gone switch is back in Config.Nudges", "\tPadGlow = true,\n", "\tQuestHead = false,\n\tPadGlow = true,\n"),
    ("CONFIG", "the guide line switch is back", "\tPadGlow = true,\n", "\tGuideBeam = false,\n\tPadGlow = true,\n"),
    ("HUD", "a client module reads a gone switch again", "function L.PlaceTrackerHead()\n",
     "function L.PlaceTrackerHead()\n\tif (Config.Nudges or {}).QuestHead == true then return end\n"),
    ("HUD", "the guide draws a ground line again", "\tlocal g = { Tag = tag, Part = part }\n",
     "\tlocal g = { Tag = tag, Part = part }\n\tlocal beam = Instance.new(\"Beam\")\n\tbeam.Name = \"HUDGuideBeam\"\n"),
    ("HUD", "the guide target is dropped", "\tlocal g = { Tag = tag, Part = part }\n\tguide = g\n", "\tlocal g = { Tag = tag, Part = part }\n"),
    ("EVENT", "the line under the goose bar is back", "\t\t{ Inst = ui.Tug, W = STRIP_W, H = BAR_H, Strip = true },\n",
     "\t\t{ Inst = ui.Tug, W = STRIP_W, H = BAR_H, Strip = true, Tail = ui.TugSub },\n"),
    ("PANELS", "the merchant's farewell is back", "function Panels.Close(manual)\n",
     "function Panels.Close(manual)\n\tlocal farewell = WSHOP.Farewell and WSHOP.Farewell()\n"),
    ("CONFIG", "the pad glow switched off", "\tPadGlow = true,\n", "\tPadGlow = false,\n"),
    ("CONFIG", "a server switch is back", "\tPadGlow = true,\n", "\tDailyReady = false,\n\tPadGlow = true,\n"),
    ("ZONE", "the server reads a deleted switch again", "\tend -- (leaving PvP: no line;",
     "\telseif (Config.Nudges or {}).EnteredSafe then\n\tend -- (leaving PvP: no line;"),
]


def nudges_block(config: str) -> str | None:
    m = re.search(r"\nConfig\.Nudges = \{\n(.*?)\n\}\n", config, re.S)
    return m[1] if m else None


def run(files: dict[str, str]) -> tuple[int, list[str]]:
    checks, fails = 0, []

    def check(name: str, ok: bool) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            fails.append(name)

    block = nudges_block(files["CONFIG"])
    check("Config.Nudges found", block is not None)
    block = block or ""
    code = "\n".join(line.split("--", 1)[0] for line in block.splitlines())
    for key in GONE:
        check(f"Config.Nudges has no {key}", re.search(r"\b" + key + r"\s*=", code) is None)
    for kept in KEPT:
        check(f"Config.Nudges keeps '{kept}'", ("\t" + kept) in block)
    for fk, text in files.items():
        if fk == "CONFIG":
            continue
        for key in GONE:
            check(f"{fk} never reads Config.Nudges.{key}",
                  re.search(r"Nudges(?: or \{\}\))?\)?\." + key + r"\b", text) is None
                  and re.search(r"Nudges\s*\.\s*" + key + r"\b", text) is None)
    for fk, needles in ABSENT.items():
        for n in needles:
            # whole names only ('ui.questHead' is not 'ui.questHeader', 'HintHalo =' is not 'ChoiceHintHalo =')
            pat = (r"(?<![A-Za-z0-9_])" if n[0].isalnum() else "") + re.escape(n) + (r"(?![A-Za-z0-9_])" if n[-1].isalnum() else "")
            check(f"{fk}: '{n}' is gone", re.search(pat, files[fk]) is None)
    for fk, needles in PRESENT.items():
        for n in needles:
            check(f"{fk}: keeps '{n.strip()[:60]}'", files[fk].count(n) == 1)
    # the guide body: no Beam, no BillboardGui (looked up between showGuide and HUD.ShowGuide)
    m = re.search(r"\nlocal function showGuide\(.*?\nend\n", files["HUD"], re.S)
    body = m[0] if m else ""
    check("showGuide found", m is not None)
    check("showGuide makes no Beam / BillboardGui", 'Instance.new("Beam")' not in body and "BillboardGui" not in body)
    return checks, fails


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    files = {
        "HUD": (CLIENT / "HUD.luau").read_text(encoding="utf-8"),
        "EVENT": (CLIENT / "EventHUD.luau").read_text(encoding="utf-8"),
        "PANELS": (CLIENT / "Panels.luau").read_text(encoding="utf-8"),
        "FIRST": (CLIENT / "FirstSteps.luau").read_text(encoding="utf-8"),
        "FX": (CLIENT / "Fx.luau").read_text(encoding="utf-8"),
        "CONFIG": CONFIG.read_text(encoding="utf-8"),
        "QUEST": (ROOT / "src/ServerScriptService/QuestService.luau").read_text(encoding="utf-8"),
        "ZONE": (ROOT / "src/ServerScriptService/ZoneService.luau").read_text(encoding="utf-8"),
        "LOOT": (ROOT / "src/ServerScriptService/LootService.luau").read_text(encoding="utf-8"),
    }
    checks, fails = run(files)
    for f in fails:
        print("CHECK_FAIL " + f)
    print(f"checks {checks}, failed {len(fails)}")
    muts = []
    for fk, name, old, new in MUTATIONS:
        hits = files[fk].count(old)
        caught = False
        if hits == 1:
            copy = dict(files)
            copy[fk] = files[fk].replace(old, new)
            caught = len(run(copy)[1]) > 0
        muts.append({"name": name, "applied": hits == 1, "caught": caught})
        print(("MUTATION caught  " if caught else "MUTATION MISSED ") + name + ("" if hits == 1 else f" (matched {hits})"))
    status = "passed" if not fails and checks > 0 and all(m["caught"] for m in muts) else "failed"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({"checks": checks, "failed": fails, "mutations": muts, "status": status}, indent=2,
                              ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Status: {status} (checks {checks}, mutations {sum(m['caught'] for m in muts)}/{len(muts)})")
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
