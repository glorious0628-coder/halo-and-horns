"""Run current CombatService + VitalsService source against offline engine doubles.

No Studio, input injection, network, or DataStore calls. Actual Config formulas and
Util.RateLimit are loaded each run; rendering and real-engine combat remain separate QA.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "COMBAT_SOURCE": ROOT / "src/ServerScriptService/CombatService.luau",
    "VITALS_SOURCE": ROOT / "src/ServerScriptService/VitalsService.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
}
FIXTURE = ROOT / "tools/fixtures/skill_release_offline.luau"
HUD = ROOT / "src/StarterPlayer/StarterPlayerScripts/HUD.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"


def key_checks():
    """User 2026-10-08 (MMO keys: I bag, E hero, K skills, M map, Q quest list): the basic skill's default key is Z, the
    interact key (the prompts) is G and nothing in HUD binds a key code directly (static HUD check; replaces the 10/06
    'skill = Q, E = interact' rule). BB1 (2026-10-05 beta basics): keys live in Config.Keybinds and HUD dispatches by
    action id through Keybinds, so the defaults are checked in Config.Keybinds and the action wiring in HUD."""
    hud = HUD.read_text(encoding="utf-8-sig")
    code = "\n".join(line.split("--", 1)[0] for line in hud.splitlines())  # ignore comments
    config = "\n".join(line.split("--", 1)[0] for line in CONFIG.read_text(encoding="utf-8-sig").splitlines())
    failures = []
    if not re.search(r'action == "SkillQ" then\s*doRelease\(\)', code):
        failures.append("HUD does not bind the skill (doRelease) to the SkillQ action")
    if not re.search(r'\{ Id = "SkillQ",[^\n}]*Key = "Z", Pad = "ButtonL2"', config) \
            or not re.search(r"PadWired = \{[^}]*\bSkillQ = true", config):
        failures.append("Config.Keybinds: the SkillQ default is not Z / gamepad L2 (wired)")
    if re.search(r"KeyCode\.[EGQ]\b", code) or not re.search(r'\{ Id = "Interact",[^\n}]*Key = "G"', config) \
            or re.search(r'\{ Id = "(?!Interact")\w+",[^\n}]*Key = "G"', config):
        failures.append("G is not kept as the interact key (HUD binds a key code or another action defaults to G)")
    if not re.search(r'\{ Id = "Journal",[^\n}]*Key = "Q"', config) or not re.search(r'\{ Id = "Character",[^\n}]*Key = "E"', config):
        failures.append("the 10/08 window keys are not Q = quest list / E = hero")
    if len(re.findall(r"doRelease\(\)", code)) < 2:  # keyboard Q / gamepad L2 action + the touch button
        failures.append("skill input bindings missing")
    return 5, failures


def literal(value):
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def main():
    sources = {key: path.read_text(encoding="utf-8-sig") for key, path in FILES.items()}
    util = sources.pop("UTIL_SOURCE")
    first = util.index("local lastCall = {}")
    last = util.index("function Util.ClearPlayer(", first)
    sources["RATE_SOURCE"] = "local Util = {}\n" + util[first:last] + "\nreturn Util.RateLimit"
    harness = ROOT / "build/skill_release_offline.luau"
    harness.write_text("\n".join("local " + key + " = " + literal(value) for key, value in sources.items())
                       + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    binary = ROOT / "build/luau_cli_0_741/luau.exe"
    compiled = subprocess.run([str(binary.with_name("luau-compile.exe")), str(FILES["COMBAT_SOURCE"])],
                              cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                              text=True, encoding="utf-8", errors="replace", timeout=60)
    result = subprocess.run([str(binary), str(harness)], cwd=ROOT, capture_output=True,
                            text=True, encoding="utf-8", errors="replace", timeout=60)
    print(result.stdout, end="")
    print(compiled.stderr + result.stderr, end="")
    marker = re.search(r"SKILL_RELEASE_OFFLINE_OK checks=(\d+) Studio/API calls=0", result.stdout)
    key_count, key_failures = key_checks()
    for message in key_failures:
        print("STATIC_FAILURE " + message)
    if not key_failures:
        print(f"SKILL_KEY_STATIC_OK checks={key_count}")
    report = {
        "status": "passed" if compiled.returncode == result.returncode == 0 and marker and not key_failures else "failed",
        "checks": int(marker[1]) if marker else 0,
        "keyStaticChecks": key_count,
        "keyStaticFailures": key_failures,
        "sourceSHA256": {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in FILES.values()},
        "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
        "studioCalls": 0, "apiCalls": 0,
        "scope": "Real server source: manual MP skill, cooldown, legacy gauge zero, Released.MonstersHit for A23 skill quests, "
                 "auto combat locked/OFF by default (SetAutoAttack refused before unlock, AutoCombatLoop present at Config.Combat.AutoTick "
                 "but idle), Mage MageSwingCost 2 / SwingInterval 1.1, class patterns, support and PvP cap. Auto ON paths: tools/test_auto_combat.py.",
        "limitations": "Offline service/physics doubles; real UI, animations, mouse/touch, damage timing, multiplayer and Studio play are not certified.",
    }
    out = ROOT / "docs/art/verification_2026-10-06/offline_skill_release_2026-10-06.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
