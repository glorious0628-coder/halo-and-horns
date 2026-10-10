"""Plain-English pass text offline test (검수 2026-10-10, A23-113 follow-up; 게임성 개발 3), plus mutations.

Config.PassInfo (the Shop card line and the create.roblox.com page description of 2x XP, 2x Gold, VIP, the looks and the
private server) must say what the code does and move with its numbers: the "2x" is Config.PassBoost.Mult, 2x Gold names the
doubled sources and says that gold taken from other players is not doubled (Plunder is no doubled source), VIP names only
what exists (crown, chat tag, Supporters board; no emote), nothing promises strength, every text is plain ASCII and ends in
"No stats are for sale.", and the prices (199 / 149 / 249) and the 2x stay as the user set them.
The real Config.luau is loaded with engine doubles (tools/fixtures/pass_text_offline.luau, the installed official Luau CLI).
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-10/offline_pass_text_2026-10-10.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
FIXTURE = ROOT / "tools/fixtures/pass_text_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-10/offline_pass_text_2026-10-10.json"

# (name, exact text in Config, replacement, a text the failing checks must name)
MUTATIONS = [
    ("2x XP says 3x", "Desc = \"Get 2x XP from everything you do, so you level up 2x faster.",
     "Desc = \"Get 3x XP from everything you do, so you level up 3x faster.", "2x XP"),
    ("2x XP card line says 3x", "Line = \"Level up 2x faster\"", "Line = \"Level up 3x faster\"", "2x XP"),
    ("2x XP talks about gold", "It only speeds up leveling.", "It speeds up leveling and gold.", "2x XP does not talk about gold"),
    ("2x Gold promises XP", "Earn 2x gold from hunting, quests and rewards.", "Earn 2x gold and XP from hunting, quests and rewards.",
     "2x Gold does not talk about XP"),
    ("2x Gold forgets the other players", " Gold you take from other players is not doubled.", "", "gold taken from other players"),
    ("2x Gold loses hunting", "Earn 2x gold from hunting, quests and rewards.", "Earn 2x gold from quests and rewards.", "hunting and quests"),
    ("plunder gold is doubled", "GoldSources = { Monster = true,", "GoldSources = { Plunder = true, Monster = true,", "gold taken from other players"),
    ("VIP promises an emote", "a VIP tag in chat, and your name", "a VIP tag in chat, an emote, and your name", "no emote is promised"),
    ("VIP loses the Supporters board", "and your name on the village Supporters board.", "and more.", "the crown, the chat tag"),
    ("a look pass promises strength", "It only changes how you look: the shape still shows your rank.",
     "It only changes how you look and makes you stronger.", "no promise of strength"),
    ("the private server loses the friends", "for you and your friends.", "for you.", "for you and your friends"),
    ("the no-stats sentence changes", "NoStats = \"No stats are for sale.\"", "NoStats = \"Stats are for sale.\"", "no-stats sentence"),
    ("a card line over 38 letters", "Line = \"Crown, chat tag, Supporters board\"", "Line = \"Crown, VIP chat tag, Supporters board and more\"",
     "a short card line"),
    ("a fancy dash", "Line = \"Earn 2x gold\"", "Line = \"Earn 2x gold — now\"", "plain ASCII"),
    ("2x XP costs 99", "Price = 199", "Price = 99", "untouched"),
    ("the 2x becomes 3x", "Mult = 2,\n\tGoldSources", "Mult = 3,\n\tGoldSources", "untouched"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, name: str):
    path = ROOT / f"build/pass_text_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\n" + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"PASS_TEXT_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(config, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new, expect in MUTATIONS:
        applied = config.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config.replace(old, new), "_mut")
            caught = (not m_ok) and any(expect in line for line in why)
        rows.append({"mutation": name, "applied": applied, "caught": caught, "expect": expect, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {CONFIG.relative_to(ROOT).as_posix(): hashlib.sha256(CONFIG.read_bytes()).hexdigest()},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "Words only: the Shop card (ShopUI) and the pass page on create.roblox.com read them by hand / by game dev 1."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
