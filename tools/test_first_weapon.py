"""A23-68 #3 first weapon 'pop' offline test (HUD.luau; user 2026-10-07: "슬라임 5대 > 2대 이런 거는 됐고 그냥 전투력이
올라야지"): the first weapon (WeaponTier 0 -> 1+, seen live after the save loaded and the class was picked) gets one big
moment: a 'Stronger!' banner (UIKit.Announce), the PowerUp sound, gold sparkles on me, the Power number growing and a slow
count-up (L.First.Count); without a power rise it still shows once (fallback); a save loading with a weapon, a later
weapon (1 -> 2) and ordinary power rises show nothing; reduced motion keeps the banner but not the growing number.
Static: Config.Audio.Sounds.PowerUp exists; HUD watches WeaponTier.
Runs the real HUD blocks (L.Pow / L.First / L.PowerPopup / L.TierChanged / L.FirstWeapon) in
tools/fixtures/first_weapon_offline.luau.
Status "passed" only when the fixture passes, the static checks pass AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-07/offline_first_weapon_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
FIXTURE = ROOT / "tools/fixtures/first_weapon_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_first_weapon_2026-10-07.json"

MUTATIONS = [
    ("a save loading with a weapon pops", "\tif F.Tier == nil then F.Tier = tier return end -- the first live reading is the baseline\n",
     "\tif F.Tier == nil then F.Tier = 0 end\n"),
    ("every new weapon pops", "\tif F.Tier <= 0 and tier >= 1 then\n", "\tif tier > F.Tier then\n"),
    ("the moment shows twice", "\t\tL.First.Pop = false\n\t\tL.FirstWeapon()\n", "\t\tL.FirstWeapon()\n"),
    ("no fallback without a power rise", "\t\t\tif F.Pop then\n\t\t\t\tF.Pop = false\n\t\t\t\tL.FirstWeapon()\n\t\t\tend\n", ""),
    ("the normal fast count-up", "\t\tcount = L.First.Count\n", ""),
    ("no sound", "pcall(C.Audio.Play, \"PowerUp\")", "pcall(C.Audio.Play, \"LevelUp\")"),
    ("no sparkles", "\t\te:Emit(F.Sparks)\n", ""),
    ("grows with reduced motion", "\tif label and label.Parent and not reduced then\n", "\tif label and label.Parent then\n"),
]

BLOCK_STARTS = ["L.Pow = {", "L.First = {", "function L.PowerPopup(", "function L.TierChanged()", "function L.FirstWeapon()"]


def blocks(hud: str) -> str:
    out = []
    for start in BLOCK_STARTS:
        i = hud.find(start)
        if i < 0:
            raise ValueError(f"HUD block {start!r} missing; update the test extractor")
        if start.endswith("{"):  # one-line table
            out.append(hud[i:hud.index("\n", i)])
        else:
            j = hud.index("\nend\n", i)
            out.append(hud[i:j + 4])
    return "\n".join(out)


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(hud: str, name: str):
    path = ROOT / f"build/first_weapon_offline{name}.luau"
    path.write_text("local HUD_BLOCKS = " + lua_str(blocks(hud)) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"FIRST_WEAPON_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    hud = HUD.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(hud, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = hud.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(hud.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    static = [
        ("Config.Audio.Sounds.PowerUp exists", re.search(r"^\t\tPowerUp = \{ File = ", config, re.M) is not None),
        ("HUD watches WeaponTier for the first weapon",
         'UIKit.OnAttr({ "WeaponTier", "DataLoaded", "ClassChosen" }, L.TierChanged)' in hud),
        ("the banner text is English", 'Stronger = "Stronger!",' in config),
    ]
    for name, good in static:
        print(("STATIC_OK " if good else "STATIC_FAILURE ") + name)
    passed = ok and all(r["applied"] and r["caught"] for r in rows) and all(g for _, g in static)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "static": [{"check": n, "ok": g} for n, g in static],
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (CONFIG, HUD)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "How big and where the banner and the sparkles look, and the real order of the server's "
                             "WeaponTier / CombatPower updates, are a Studio check (M1_1 gift at the forge)."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")


if __name__ == "__main__":
    main()
