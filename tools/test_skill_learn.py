"""A23-71 skill learn offline test (SkillBar.luau; user 2026-10-07 "스킬도 처음에는 없어야 돼! 레벨 5일 때 하나 배우는 걸로
하자", unlocks Q 5 / Z 15 / X 25): no skill button below its unlock level (a key press says "Skills come at Lv N",
not spammed); unlocking while playing -> "New skill! <name>" banner (UIKit.Announce), the button pops in, one line on it
(C.HUD.Hint(slot, "Press Q") / phones "Tap the new button"), the SkillLearn sound with PowerUp until its file exists;
once per slot; a save loading past the level shows its skills without the moment; reduced motion: no pop.
Runs the real SkillBar.luau + Config.luau (Config.Skills.Unlock set to the A23-71 numbers) in
tools/fixtures/skill_learn_offline.luau.
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-07/offline_skill_learn_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
BAR = ROOT / "src/StarterPlayer/StarterPlayerScripts/SkillBar.luau"
FIXTURE = ROOT / "tools/fixtures/skill_learn_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_skill_learn_2026-10-07.json"

MUTATIONS = [
    ("locked slots show again", "\tlocal visible = st.On and not st.Locked -- A23-71", "\tlocal visible = st.On --"),
    ("a save load shows the moment", "\tif visible and b.Live and b.WasLocked == true then LEARN.Show(b, st) end\n",
     "\tif visible and b.WasLocked == true then LEARN.Show(b, st) end\n"),
    ("the moment repeats", "\tb.WasLocked = st.Locked\n", ""),
    ("no banner", "\tif type(UIKit.Announce) == \"function\" then pcall(UIKit.Announce, string.format(TXT.NewSkill, st.Def.Name), LEARN.Banner) end\n", ""),
    ("no line on the button", "\tif type(hud) == \"table\" and type(hud.Hint) == \"function\" then pcall(hud.Hint, slot, line) end\n", ""),
    ("phones read 'Press Q'", "\tif not IS_TOUCH then\n\t\tlocal kb = C and C.Keybinds", "\tif true then\n\t\tlocal kb = C and C.Keybinds"),
    ("no PowerUp fallback", "\t\tif not (ok and played) then pcall(audio.Play, \"PowerUp\") end\n", ""),
    ("no pop", "\t\tscale.Scale = 0.2\n", "\t\tscale.Scale = 1\n\t\tscale:Destroy()\n"),
    ("pops with reduced motion", "\tif not reduced then\n\t\tlocal scale", "\tif true then\n\t\tlocal scale"),
    ("a locked key press says nothing", "\t\tif st.On and st.Locked then LEARN.Tell(st.Unlock) end\n", ""),
    ("the toast is spammed", "\tif os.clock() - LEARN.TellAt < LEARN.TellGap then return end\n", ""),
    ("SkillSlots ignored (a rebirth at Lv1 looks locked)",
     "\tif locked and type(slots) == \"number\" and slots >= (T.SlotIndex[slot] or 99) then locked = false end\n", ""),
    ("key badges ignore Key hints", "\t\tb.Key.Visible = badges and text ~= \"\"\n", "\t\tb.Key.Visible = text ~= \"\"\n"),
    ("the badges never follow a settings change", "\t\t\tsrc.Changed:Connect(refreshAll)\n", ""),
    ("SkillSlots changes not watched", '"SkillReadyAtX", "SkillBarPreview", "SkillSlots" }', '"SkillReadyAtX", "SkillBarPreview" }'),
    # sound_gaps A9 / A10 (2026-10-07)
    ("the learn sound plays with the banner", "\ttask.delay(LEARN.SoundDelay, LEARN.Sound)\n", "\tLEARN.Sound()\n"),
    ("no SkillReady at the cooldown end",
     'if type(audio) == "table" and type(audio.Play) == "function" then ok, played = pcall(audio.Play, "SkillReady") end', ""),
    ("the click plays on top of SkillReady", 'if not (ok and played) and type(fx) == "table"', 'if type(fx) == "table"'),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, bar: str, name: str):
    path = ROOT / f"build/skill_learn_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal BAR_SOURCE = " + lua_str(bar) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"SKILL_LEARN_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    bar = BAR.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(config, bar, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = bar.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config, bar.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (CONFIG, BAR)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "The button layout without skill slots is image dev's (HudLayout); the real unlock numbers "
                             "come with dev2's Config.Skills.Unlock change; the look of the moment is a Studio check."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
