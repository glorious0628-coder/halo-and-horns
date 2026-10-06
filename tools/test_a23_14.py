"""A23-14 rookie dailies, golden goose co-op and the free class change below Lv5, run offline.

Runs the CURRENT Config, DataService, QuestService, GooseService and ClassService sources (injected into
tools/fixtures/a23_14_offline.luau) with the installed official Luau CLI (build/luau_cli_0_741). No Studio, network,
DataStore or Roblox API calls. Every check is named and collected. A mutation step then breaks in-memory copies of the
sources (never src/), runs them from a temporary directory and counts how many mutations the checks catch.

Usage: py tools/test_a23_14.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_a23_14_2026-10-06.json
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/fixtures/a23_14_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_a23_14_2026-10-06.json"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "QUEST_SOURCE": ROOT / "src/ServerScriptService/QuestService.luau",
    "GOOSE_SOURCE": ROOT / "src/ServerScriptService/GooseService.luau",
    "CLASS_SOURCE": ROOT / "src/ServerScriptService/ClassService.luau",
}
STATIC_ONLY = {
    "CLASS_PICKER": ROOT / "src/StarterPlayer/StarterPlayerScripts/ClassPicker.luau",
    "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau",
    "EVENT_HUD": ROOT / "src/StarterPlayer/StarterPlayerScripts/EventHUD.luau",
}

# (name, source key, exact text, replacement): each must match exactly once in the current source
MUTATIONS = [
    ("newbie daily pays the 5-minute reward", "QUEST_SOURCE",
     "rewardGold, rewardXP = Config.HuntValue(level, num(NEWBIE.RewardMinutes, Config.Daily.QuestMinutes))",
     "rewardGold, rewardXP = Config.DailyQuestReward(level)"),
    ("newbie band includes Lv10", "QUEST_SOURCE",
     "and level <= num(NEWBIE.MaxLevel, 0)", "and level <= num(NEWBIE.MaxLevel, 0) + 1"),
    ("strict king-slime row counts slimes as fractions", "QUEST_SOURCE",
     "if strict and w < 1 then return 0 end", ""),
    ("newbie chest pays the Lv10+ chest", "QUEST_SOURCE",
     "return Config.HuntValue(level, num(NEWBIE.ChestMinutes, Config.Daily.ChestMinutes))",
     "return Config.DailyChestReward(level)"),
    ("chest ignores the generation band", "QUEST_SOURCE",
     "if genLevel >= 1 and genLevel ~= level then", "if false then"),
    ("newbie rows allow a repeated goal", "QUEST_SOURCE",
     "if not otherIds[row.Id] then", "if true then"),
    ("vacation uses the Lv10+ day value", "CONFIG_SOURCE",
     "local g, x = Config.HuntValue(level, Config.DailyDayMinutes(level))",
     "local g, x = Config.HuntValue(level, Config.Daily.QuestMinutes * Config.Quests.Slots + Config.Daily.ChestMinutes)"),
    ("co-op success pays 100%", "GOOSE_SOURCE",
     "local share = (judged == \"Coop\" and success) and (tonumber(Config.Goose.CoopWinShare) or 0.7) or nil",
     "local share = nil"),
    ("co-op gives war points", "GOOSE_SOURCE",
     "if judged == \"Versus\" and result ~= \"Tie\" then", "if result ~= \"Tie\" then"),
    ("co-op target ignores the headcount", "GOOSE_SOURCE",
     "return math.max(1, math.floor(per * math.max(1, people) + 0.5))", "return math.max(1, math.floor(per + 0.5))"),
    ("auto-only players are paid", "GOOSE_SOURCE",
     "if (finalManual[p] or 0) >= MIN_MANUAL_HITS then", "if true then"),
    ("rival pulls during co-op", "GOOSE_SOURCE",
     "if mode == \"Coop\" and f ~= coop.Side then", "if false then"),
    ("no co-op when only one faction is present", "GOOSE_SOURCE",
     "elseif halo > 0 or horns > 0 then\n\t\tmode = \"Coop\"", "elseif false then\n\t\tmode = \"Coop\""),
    ("rival-left tug is a forced tie again", "GOOSE_SOURCE",
     "\t\t\trivalLeft = true\n\t\t\tjudged = \"Coop\"", "\t\t\trivalLeft = true\n\t\t\tjudged = \"Pending\""),
    ("GooseFinished skipped for co-op", "GOOSE_SOURCE",
     "GooseService.GooseFinished:Fire(result, rewarded, info)",
     "if judged ~= \"Coop\" then GooseService.GooseFinished:Fire(result, rewarded, info) end"),
    ("free change below Lv5 resets the level", "CLASS_SOURCE",
     "local keepLevel = freeKeepsLevel(player)", "local keepLevel = false"),
    ("ticket spent below Lv5", "CLASS_SOURCE",
     "if keepLevel then useTicket = false end", ""),
    ("keep-level change fully heals", "CLASS_SOURCE",
     "S.PlayerService.RefreshCharacter(player, not keepLevel)", "S.PlayerService.RefreshCharacter(player, true)"),
    ("keep threshold off by one", "CONFIG_SOURCE",
     "return math.floor(lv) < (tonumber(Config.ClassChange.FreeKeepLevelBelow) or 0)",
     "return math.floor(lv) <= (tonumber(Config.ClassChange.FreeKeepLevelBelow) or 0)"),
]


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def make_harness(sources: dict[str, str]) -> str:
    head = "\n".join(f"local {key} = {literal(value)}" for key, value in sources.items())
    return head + "\n" + FIXTURE.read_text(encoding="utf-8")


def run_harness(binary: Path, harness_text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(harness_text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=600)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("A23_14_RESULT_JSON "):
            result = json.loads(line[len("A23_14_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def static_checks() -> tuple[int, list[str]]:
    """Client wiring that the offline services cannot reach (display only; the server rules are run above)."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    picker = STATIC_ONLY["CLASS_PICKER"].read_text(encoding="utf-8-sig")
    check("ClassChangeRuleF" in picker and "FreeKeepLevelBelow" in picker,
          "ClassPicker footer uses Config.Text.ClassChangeRuleF with Config.ClassChange.FreeKeepLevelBelow")
    panels = STATIC_ONLY["PANELS"].read_text(encoding="utf-8-sig")
    check("ClassChangeKeepsLevel" in panels and "ClassFreeKeepLevelF" in panels,
          "Panels class-change preview uses Config.ClassChangeKeepsLevel / ClassFreeKeepLevelF (no 'Lv N -> Lv 1' below Lv5)")
    hud = STATIC_ONLY["EVENT_HUD"].read_text(encoding="utf-8-sig")
    check("GooseMode" in hud and "GooseCoopTarget" in hud and "HudProgress" in hud,
          "EventHUD draws the co-op gauge from GameState GooseMode / GooseCoopTarget and Config.Goose.Text")
    net = FILES["NET_SOURCE"].read_text(encoding="utf-8-sig")
    check(all(key in net for key in ("GooseMode", "GooseCoopSide", "GooseCoopTarget", "GooseCoopPeople")),
          "Net.GameStateDefaults has the four co-op goose attributes")
    return count, failures


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    parser.add_argument("--no-mutations", action="store_true")
    args = parser.parse_args()
    binary = args.luau.resolve()
    compiler = binary.with_name("luau-compile" + binary.suffix)
    if not binary.is_file() or not compiler.is_file():
        print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
        return 1
    raw = {key: path.read_bytes() for key, path in FILES.items()}
    sources = {key: value.decode("utf-8-sig").replace("\r\n", "\n") for key, value in raw.items()}
    fixture_raw = FIXTURE.read_bytes()

    compiled = subprocess.run([str(compiler), *(str(p) for p in FILES.values()), str(FIXTURE)], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", timeout=120)
    static_count, static_failures = static_checks()

    with tempfile.TemporaryDirectory(prefix="a23_14_offline_") as tmp:
        tmpdir = Path(tmp)
        main_run = run_harness(binary, make_harness(sources), tmpdir, "a23_14_main.luau")
        result = main_run["result"]
        baseline = failing_keys(result)
        mutations = []
        if not args.no_mutations:
            jobs = []
            for name, key, old, new in MUTATIONS:
                hits = sources[key].count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(), "applied": False,
                                      "caught": False, "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                mutated = dict(sources)
                mutated[key] = sources[key].replace(old, new, 1)
                jobs.append((name, key, make_harness(mutated)))

            def work(index_job):
                index, (name, key, text) = index_job
                out = run_harness(binary, text, tmpdir, f"a23_14_mutant_{index:02d}.luau")
                new_fail = sorted(failing_keys(out["result"]) - baseline)
                crashed = out["result"] is None
                return {"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(), "applied": True,
                        "caught": crashed or bool(new_fail), "crashed": crashed,
                        "newFailingChecks": new_fail[:6], "newFailingCount": len(new_fail)}

            with ThreadPoolExecutor(max_workers=6) as pool:
                mutations.extend(pool.map(work, enumerate(jobs)))

    changed = [p.relative_to(ROOT).as_posix() for key, p in FILES.items() if p.read_bytes() != raw[key]]
    if FIXTURE.read_bytes() != fixture_raw:
        changed.append(FIXTURE.relative_to(ROOT).as_posix())
    marker = re.search(r"A23_14_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
    named = result.get("Named", []) if result else []
    failing = [n for n in named if n.get("Fail", 0) > 0]
    caught = sum(1 for m in mutations if m.get("caught"))
    applied = sum(1 for m in mutations if m.get("applied"))
    ok = (compiled.returncode == 0 and main_run["returncode"] == 0 and marker is not None and not static_failures
          and not changed and all(m.get("applied") and m.get("caught") for m in mutations))
    report = {
        "status": ("passed-no-mutations" if args.no_mutations else "passed") if ok else "failed",
        "mutationsSkipped": args.no_mutations,
        "checks": result.get("Checks", 0) if result else 0,
        "failedChecks": result.get("Failed", 0) if result else 0,
        "namedChecks": len(named),
        "namedChecksFailing": len(failing),
        "failing": [{"group": n["Group"], "check": n["Name"], "failures": n["Fail"], "passes": n["Pass"],
                     "firstFailure": n.get("FirstFailure")} for n in failing],
        "named": [{"group": n["Group"], "check": n["Name"], "pass": n["Pass"], "fail": n["Fail"]} for n in named],
        "findings": result.get("Findings", []) if result else [],
        "staticChecks": static_count,
        "staticFailures": static_failures,
        "mutations": {"total": len(MUTATIONS), "applied": applied, "caught": caught, "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if result else (main_run["stderr"].strip() or main_run["stdout"].strip())[-2000:],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(raw[key]).hexdigest() for key, p in FILES.items()},
        "fixtureSHA256": hashlib.sha256(fixture_raw).hexdigest(),
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "contract": "A23-14 (user 2026-10-05): Lv1-9 dailies = three different short goals (king slime 3 strict / slime 12-15, "
                    "skill hits 3-5, hunting gold 40-60), 72 gold + 120 XP each and a 144 + 240 chest (one day = 600 XP < 1381 "
                    "for Lv10), vacation 252 + 420 per missed rookie day, chest capped to the generation band; golden goose "
                    "co-op when only one of Halo/Horns is present: target 20 x headcount, 70% of the winner reward, 0 war "
                    "points, 3 manual hits to be paid, Neutral excluded, GooseFinished still fired (quest credit), rival-left "
                    "tug judged by the co-op rule; free class change below Lv5 keeps level/XP (no ticket spent, HP fraction "
                    "kept), from Lv5 free = Lv1 / XP 0 and ticket = level kept.",
        "limitations": "Offline doubles: DataStore table, seeded Util.Random, ProgressionService pay recorder (no level-ups), "
                       "faction counts from the fixture roster, no goose 3D model, rate limits always pass. Client HUD/Panels "
                       "are only checked statically. Studio play, multiple clients and the real timers are not certified here.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in main_run["stdout"].splitlines():
        if line.startswith("CHECK_FAIL") or line.startswith("A23_14_OFFLINE"):
            print(line)
    if not result:
        print(main_run["stderr"], end="")
    for message in static_failures:
        print(f"STATIC_FAILURE {message}")
    print(f"STATIC checks={static_count} failed={len(static_failures)}")
    for m in mutations:
        print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
              + ("" if m.get("applied") else f" ({m.get('note')})"))
    if mutations:
        print(f"MUTATIONS caught={caught}/{applied} (of {len(MUTATIONS)})")
    if args.no_mutations:
        print("MUTATIONS SKIPPED")
    print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
          f"assertions {report['checks'] - report['failedChecks']}/{report['checks']}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"A23-14 offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
