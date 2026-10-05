"""A23-1 auto combat: run current CombatService + VitalsService (+ the KaijuService Released handler) offline.

No Studio, input injection, network or DataStore calls. Checks: auto starts locked/OFF, UnlockAutoCombat never turns
it ON, the SetAutoAttack toggle contract, the AutoCombatLoop only acts while unlocked + ON + alive (+ ready, class
chosen, not a kaiju), manual presses make auto yield, and auto swings/skills never hit a player or a kaiju.
Usage: py tools/test_auto_combat.py
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "COMBAT_SOURCE": ROOT / "src/ServerScriptService/CombatService.luau",
    "VITALS_SOURCE": ROOT / "src/ServerScriptService/VitalsService.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
    "KAIJU_SOURCE": ROOT / "src/ServerScriptService/KaijuService.luau",
}
FIXTURE = ROOT / "tools/fixtures/auto_combat_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_auto_combat_2026-10-06.json"


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def between(text: str, start: str, end: str) -> str:
    first = text.find(start)
    last = text.find(end, first + len(start)) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r} / {end!r}; update the test extractor.")
    return text[first:last]


def static_checks() -> tuple[int, list[str], dict]:
    """Across src/: AutoCombatEnabled is written only by the toggle remote and AutoCombatUnlocked only by
    CombatService.UnlockAutoCombat, so no quest/unlock path can switch auto combat ON by itself."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    writers: dict[str, list[str]] = {"AutoCombatEnabled": [], "AutoCombatUnlocked": []}
    for path in sorted((ROOT / "src").rglob("*.luau")):
        text = path.read_text(encoding="utf-8-sig")
        for number, line in enumerate(text.splitlines(), 1):
            code = line.split("--", 1)[0]
            for key in writers:
                if re.search(rf'(SetStat\([^)]*"{key}"|SetAttribute\(\s*"{key}"|\.{key}\s*=[^=]|\["{key}"\]\s*=[^=])', code):
                    writers[key].append(f"{path.relative_to(ROOT).as_posix()}:{number}")
    combat = FILES["COMBAT_SOURCE"].read_text(encoding="utf-8-sig")
    toggle = re.search(r"local function onSetAutoAttackRemote\(.*?\nend\n", combat, re.S)
    unlock = re.search(r"function CombatService\.UnlockAutoCombat\(.*?\nend\n", combat, re.S)
    # A23-22 (2026-10-05): the unruly-PvP penalty may switch auto combat OFF (literal false); nothing else may write it,
    # so no quest/unlock path can switch it ON by itself
    src_lines = {}
    def line_of(ref: str) -> str:
        file, number = ref.rsplit(":", 1)
        if file not in src_lines:
            src_lines[file] = (ROOT / file).read_text(encoding="utf-8-sig").splitlines()
        return src_lines[file][int(number) - 1]
    others = [w for w in writers["AutoCombatEnabled"] if 'SetStat(player, "AutoCombatEnabled", enabled)' not in line_of(w)]
    check(len(writers["AutoCombatEnabled"]) - len(others) == 1 and toggle is not None
          and 'SetStat(player, "AutoCombatEnabled", enabled)' in toggle.group()
          and all('"AutoCombatEnabled", false)' in line_of(w) for w in others),
          f"AutoCombatEnabled must be written only by the SetAutoAttack toggle (others may only write false); writers: {writers['AutoCombatEnabled']}")
    check(len(writers["AutoCombatUnlocked"]) == 1 and unlock is not None
          and 'SetStat(player, "AutoCombatUnlocked", true)' in unlock.group() and "AutoCombatEnabled" not in unlock.group(),
          f"AutoCombatUnlocked must be written only by UnlockAutoCombat; writers: {writers['AutoCombatUnlocked']}")
    callers = []
    for path in sorted((ROOT / "src").rglob("*.luau")):
        if "UnlockAutoCombat" in path.read_text(encoding="utf-8-sig") and path != FILES["COMBAT_SOURCE"]:
            callers.append(path.relative_to(ROOT).as_posix())
    check(all(c.startswith("src/ServerScriptService/") for c in callers), f"a client module calls UnlockAutoCombat: {callers}")
    return count, failures, {"callersOfUnlockAutoCombat": callers, "writers": writers}


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    binary = ROOT / "build/luau_cli_0_741/luau.exe"
    compiler = binary.with_name("luau-compile.exe")
    if not binary.is_file() or not compiler.is_file():
        print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
        return 1
    raw = {key: path.read_bytes() for key, path in FILES.items()}
    # normalize CRLF so extraction boundaries do not depend on the editor's line endings
    sources = {key: value.decode("utf-8-sig").replace("\r\n", "\n") for key, value in raw.items()}
    util = sources.pop("UTIL_SOURCE")
    first = util.index("local lastCall = {}")
    last = util.index("function Util.ClearPlayer(", first)
    sources["RATE_SOURCE"] = "local Util = {}\n" + util[first:last] + "\nreturn Util.RateLimit"
    kaiju = sources.pop("KAIJU_SOURCE")
    handler = between(kaiju, "S.CombatService.Released:Connect(function(player, info)", "\nend\n\nfunction KaijuService.Start()")
    sources["KAIJU_RELEASED_SOURCE"] = ("local S, isPlayer, factionOf, phase, current, dmg, healers = ...\n"
                                        + handler + "\nreturn true")
    harness = ROOT / "build/auto_combat_offline.luau"
    harness.parent.mkdir(exist_ok=True)
    harness.write_text("\n".join(f"local {key} = {literal(value)}" for key, value in sources.items())
                       + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    compiled = subprocess.run([str(compiler), str(FILES["COMBAT_SOURCE"]), str(FILES["KAIJU_SOURCE"]), str(FIXTURE)],
                              cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                              text=True, encoding="utf-8", errors="replace", timeout=60)
    result = subprocess.run([str(binary), str(harness)], cwd=ROOT, capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=120)
    static_count, static_failures, static_info = static_checks()
    print(result.stdout, end="")
    print(compiled.stderr + result.stderr, end="")
    for message in static_failures:
        print(f"STATIC_FAILURE {message}")
    if not static_failures:
        print(f"AUTO_COMBAT_STATIC_OK checks={static_count}")
    marker = re.search(r"AUTO_COMBAT_OFFLINE_OK checks=(\d+) Studio/API calls=0", result.stdout)
    changed = [p.relative_to(ROOT).as_posix() for key, p in FILES.items() if p.read_bytes() != raw[key]]
    report = {
        "status": "passed" if compiled.returncode == result.returncode == 0 and marker and not changed
                  and not static_failures else "failed",
        "checks": int(marker[1]) if marker else 0,
        "staticChecks": static_count,
        "staticFailures": static_failures,
        "staticFindings": static_info,
        "failure": None if marker else (result.stderr.strip().splitlines() or ["no output"])[0],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(raw[key]).hexdigest() for key, p in FILES.items()},
        "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "contract": "A23-1 / GDD 0-2: auto combat starts OFF and locked; UnlockAutoCombat only sets AutoCombatUnlocked; the "
                    "player toggles AutoCombatEnabled (saved via SetStat); auto attacks and auto skills hit monsters only.",
        "coverage": [
            "defaults AutoCombatUnlocked/AutoCombatEnabled false and mirrored; exactly one loop at Config.Combat.AutoTick",
            "legacy AutoAttack attribute, unlock alone and repeated unlock never start auto combat",
            "SetAutoAttack: one boolean only, unlocked/ready/alive/class-chosen, rate limited, saved through SetStat",
            "auto stops when OFF, not unlocked, dead, no root, not ready, left, class not chosen, kaiju Active/Siren/Queued",
            "no monster in reach: no swing, no skill, no MP",
            "auto skill: MP cost and 3 s cooldown, Released Auto=true with MonstersHit, never MarkActive",
            "manual swing makes auto yield SwingInterval + ManualYieldPad (Warrior/Mage/Archer)",
            "auto Swing/Release (loop and direct calls) never damage players or an Active kaiju for Around/Splash/Multi, "
            "Halo and Horns attackers, PvP allowed; manual positive control does hit them",
            "KaijuService Released handler ignores info.Auto heals (real handler source extracted)",
            "static: AutoCombatEnabled written only by the SetAutoAttack toggle, AutoCombatUnlocked only by "
            "CombatService.UnlockAutoCombat (StoryQuestService unlock calls it), no client caller",
        ],
        "limitations": "Offline service/physics doubles; real client toggle UI, the unlock quest, animation timing, "
                       "multiplayer and Studio play are not certified here.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Auto combat offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
