"""SKL-1 offline test (A23-49 skill kit, docs/design/skill_kit_beta_2026-10-06.md sections 1 / 4 / 5 / 6-3 / 8-1), plus
mutations: the real Config.luau loaded with engine doubles. Config.Skills flags off (ZEnabled / XEnabled / PvPZX),
Unlock Q1 / Z5 / X8, 0.5 s gap, MP steal cap 20, 6 kits x 3 slots = 21 skills with the section 4 MP / CD / Mult / shape
numbers and the section 5 English names (<= 14 letters) + descriptions, artisan kits with crafted looks only;
A23-116: the 18 class skills named per side (Halo / Horns tables on Q, Z and X; 18 names all different, no shared word
except an X pair, no word of a monster / pass / look / artisan name, the same numbers for both sides, the Halo words with
no side, Skills.Text QZHalo / QZHorns);
Config.SkillKit / SkillDef (faction table merged, cached) / SkillNumbers ("Costs N MP", A23-60); the SkillX key (X,
pad ButtonR3, Flag Skills.XEnabled, right after SkillZ).
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-07/offline_skill_kit_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
FIXTURE = ROOT / "tools/fixtures/skill_kit_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_skill_kit_2026-10-07.json"

MUTATIONS = [
    ("Z unlocks at Lv10", "Unlock = { Q = 5, Z = 15, X = 25 }", "Unlock = { Q = 5, Z = 10, X = 25 }"),
    ("the Z flag starts on", "ZEnabled = false, XEnabled = false, PvPZX = false,", "ZEnabled = true, XEnabled = false, PvPZX = false,"),
    ("the Warrior's Z band 20 long", 'Z = { Shape = "Line", Len = 22,', 'Z = { Shape = "Line", Len = 20,'),
    ("SkillDef ignores the faction", 'local fx = (factionId == "Halo" or factionId == "Horns") and base[factionId] or nil',
     "local fx = nil"),
    ("the artisan Mage keeps the Mage kit", '\t\tif class == "Mage" then return "Alchemist" end\n', "\n"),
    ("SkillNumbers hides the MP", "local parts = { string.format(T.Cost, math.floor(tonumber(def.MP) or 0)) }", "local parts = {}"),
    ("SkillX on the pad's B (close)", 'Pad = "ButtonR3"', 'Pad = "ButtonB"'),
    ("auto combat may Hop", "CD = 10,\n\t\t\t\tAuto = { Never = true },", "CD = 10,\n\t\t\t\tAuto = { Min = 1 },"),
    ("a name longer than 14 letters", 'NameEn = "Guardian Roar"', 'NameEn = "Guardian Roar of Light"'),
    ("Rage Roar steals no MP", "MPSteal = 5 } },\n\t\t},\n\t\tMage = {", "MPSteal = 0 } },\n\t\t},\n\t\tMage = {"),
    # A23-116: the fourth item is a text the failing checks must name (the new checks, not only the names list)
    ("two skills with one name", 'NameEn = "Star Fall"', 'NameEn = "Halo Slam"', "the 18 names are all different"),
    ("a word shared by a Z and an X name", 'NameEn = "Fire Rake"', 'NameEn = "Fire Roar"', "no word is shared between the 18 names"),
    ("a monster's word in a skill name", 'NameEn = "Purple Pop"', 'NameEn = "Goblin Pop"', "monster, a game pass or a look"),
    ("a look's word in a skill name", 'NameEn = "Comet Arrow"', 'NameEn = "Lava Arrow"', "monster, a game pass or a look"),
    ("an artisan word in a skill name", 'NameEn = "Moon Shot"', 'NameEn = "Hook Shot"', "artisan guild's names"),
    ("a side table changes a number", 'Horns = { NameEn = "Crater Smash"', 'Horns = { Mult = 7, NameEn = "Crater Smash"',
     "holds only NameEn + DescEn"),
    ("a base name left on a class skill", 'Z = { Shape = "Line", Range = 40, Len = 40,',
     'Z = { NameEn = "Pierce Shot", Shape = "Line", Range = 40, Len = 40,', "no base NameEn"),
    ("a Horns line that does not steal", 'Pull monsters in and steal HP."', 'Pull monsters in."', "fits the side"),
    ("a Halo line that does not heal", 'Throw a glowing rope and pull monsters in. Heals you and friends.',
     'Throw a glowing rope and pull monsters in.', "fits the side"),
    ("no Halo words without a side", "elseif out.NameEn == nil then", "elseif false then", "no side yet (None / nil)"),
    ("a skill name over 13 letters", 'NameEn = "Bat Zigzag"', 'NameEn = "Bat Zigzag Flapper"', "18 names <= 13 letters"),
    ("an old name comes back", 'NameEn = "Halo Slam"', 'NameEn = "Shockwave"', "the old names"),
    ("the Horns side line says MP", 'QZHorns = "Horns: your hits steal HP"', 'QZHorns = "Horns: your hits steal MP"',
     "section 5 short words"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, name: str):
    path = ROOT / f"build/skill_kit_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"SKILL_KIT_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(config, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new, *rest in MUTATIONS:
        applied = config.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config.replace(old, new), "_mut")
            caught = not m_ok
            if rest:
                caught = caught and any(rest[0] in line for line in why)
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {CONFIG.relative_to(ROOT).as_posix(): hashlib.sha256(CONFIG.read_bytes()).hexdigest()},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "Data only: casting, shapes, cooldowns and auto combat are SKL-2 / SKL-3 (dev2's SkillService)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
