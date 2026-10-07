"""QuestTarget offline check (A23-36 quest target marker routes; A23-30 pumpkin patch, A23-45 haunted hollow).

Runs the CURRENT src/ReplicatedStorage/Shared/Config.luau and src/StarterPlayer/StarterPlayerScripts/QuestTarget.luau,
injected into tools/fixtures/quest_target_offline.luau, with the installed official Luau CLI (build/luau_cli_0_741):
Roblox is replaced by small doubles (Vector3 maths, a workspace.Map tree with pads / gates / bridges / the patch sign,
Instance.new for the local anchors, a LocalPlayer with attributes). No Studio, network or Roblox API calls.

Checks (named, collected): the haunted hollow route (Crossroads -> meadow pad, meadow -> patch sign, passage -> patch
field, patch / patch land -> the gap in the patch's west fence, inside -> nil, story guide and story entry), the season
switch (Halloween off -> no route), plain zone routes (pad, faction-town bridge, already there, unknown zone), quest rows
(tutorial steps, the blacksmith step and the English gold goal, level goals, the Claim flag for QuestMarker's gold,
English labels).
Mutations: in-memory copies of QuestTarget with one rule broken each; each must make a check fail that passes on the
real source. --no-mutations skips them and the status is then "passed-no-mutations" (never "passed").

Usage: py tools/test_quest_target.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_quest_target_2026-10-06.json
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/fixtures/quest_target_offline.luau"
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
QT = ROOT / "src/StarterPlayer/StarterPlayerScripts/QuestTarget.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_quest_target_2026-10-06.json"

# (name, exact text in QuestTarget.luau, replacement): each must match exactly once
MUTATIONS = [
    ("claim ignores CanClaim",
     "return entry.CanClaim == true and num(entry.Progress, 0) >= num(entry.Target, 1)",
     "return num(entry.Progress, 0) >= num(entry.Target, 1)"),
    ("English gold goal not seen",
     ' or string.find(string.lower(text), "gold", 1, true) ~= nil', ""),
    ("blacksmith label back in Korean", 'Blacksmith = "Forge",', 'Blacksmith = "대장간",'),
    ("hollow not routed through the patch",
     "\tif zoneId == K.Hollow.Zone then return hollowRoute(fromZone, pos or myPos()) end\n", ""),
    ("hollow gate moved off the fence gap",
     'Gate = (typeof(HW.HollowGate) == "Vector3" and HW.HollowGate or Vector3.new(420, 0, 340)) + Vector3.new(0, 3, 0),',
     "Gate = Vector3.new(320, 3, 300),"),
    ("patch land not counted as the patch",
     "inPatch = l ~= nil and insideRect(pos, num(l.MinX, 0), num(l.MaxX, 0), num(l.MinZ, 0), num(l.MaxZ, 0))",
     "inPatch = false"),
    ("inside the hollow still points somewhere",
     "if fromZone == H.Zone or insideZone(pos, z) then return nil end", "if false then return nil end"),
    ("patch sign skipped in the meadow", "if inMeadow then\n", "if false then\n"),
    ("faction-town bridge ignored", "local bridge = zoneId == K.GuideZone and K.HomeBridge[fromZone] or nil",
     "local bridge = nil"),
]


def lua_long(text: str) -> str:
    eq = "===="
    while f"]{eq}]" in text:
        eq += "="
    return f"[{eq}[{text}]{eq}]"


def harness(config: str, qt: str) -> str:
    return f"local CONFIG_SOURCE = {lua_long(config)}\nlocal QT_SOURCE = {lua_long(qt)}\n" + FIXTURE.read_text(encoding="utf-8")


def run(binary: Path, text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=300)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("QUEST_TARGET_RESULT_JSON "):
            result = json.loads(line[len("QUEST_TARGET_RESULT_JSON "):])
    return {"stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


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
    raw = {p: p.read_bytes() for p in (CONFIG, QT, FIXTURE)}
    config = raw[CONFIG].decode("utf-8-sig").replace("\r\n", "\n")
    qt = raw[QT].decode("utf-8-sig").replace("\r\n", "\n")
    compiled = subprocess.run([str(compiler), str(QT), str(FIXTURE)], cwd=ROOT, stdout=subprocess.DEVNULL,
                              stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace", timeout=120)
    mutations = []
    with tempfile.TemporaryDirectory(prefix="quest_target_") as tmp:
        tmpdir = Path(tmp)
        real = run(binary, harness(config, qt), tmpdir, "qt_real.luau")
        base = failing(real["result"])
        if not args.no_mutations:
            for i, (name, old, new) in enumerate(MUTATIONS):
                hits = qt.count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "applied": False, "caught": False,
                                      "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                m = run(binary, harness(config, qt.replace(old, new, 1)), tmpdir, f"qt_mut_{i:02d}.luau")
                new_fail = sorted(failing(m["result"]) - base)
                crashed = m["result"] is None
                mutations.append({"mutation": name, "applied": True, "caught": crashed or bool(new_fail),
                                  "crashed": crashed, "newFailingChecks": new_fail[:6]})
    changed = [p.relative_to(ROOT).as_posix() for p, b in raw.items() if p.read_bytes() != b]
    result = real["result"] or {}
    named = result.get("Named", [])
    bad = [n for n in named if n.get("Fail", 0) > 0]
    real_ok = real["result"] is not None and not bad and "QUEST_TARGET_OFFLINE_OK" in real["stdout"]
    mut_ok = all(m.get("applied") and m.get("caught") for m in mutations)
    if compiled.returncode == 0 and real_ok and not changed and mut_ok:
        status = "passed-no-mutations" if args.no_mutations else "passed"
    else:
        status = "failed"
    report = {
        "status": status,
        "checks": result.get("Checks", 0),
        "namedChecks": len(named),
        "failing": [{"group": n["Group"], "check": n["Name"], "firstFailure": n.get("FirstFailure")} for n in bad],
        "mutations": {"total": len(MUTATIONS), "caught": sum(1 for m in mutations if m.get("caught")), "results": mutations},
        "compileOk": compiled.returncode == 0,
        "compileErrors": compiled.stderr.strip(),
        "runtimeError": None if real["result"] else (real["stderr"].strip() or real["stdout"].strip())[-2000:],
        "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(b).hexdigest() for p, b in raw.items()},
        "sourcesChangedDuringRun": changed,
        "studioCalls": 0, "apiCalls": 0,
        "limitations": "Doubles instead of the engine: the map tree holds only the parts QuestTarget looks up; the real "
                       "MapBuilder positions (patch sign, fence gap) are checked in Studio separately.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in real["stdout"].splitlines():
        if line.startswith("QUEST_TARGET_OFFLINE") or line.startswith("CHECK_FAIL"):
            print(line)
    if not real["result"]:
        print(real["stderr"], end="")
    for m in mutations:
        print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
              + ("" if m.get("applied") else f" ({m.get('note')})"))
    print(f"Named checks: {len(named) - len(bad)} passed, {len(bad)} failing")
    print(f"Status: {status}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if status in ("passed", "passed-no-mutations") else 1


if __name__ == "__main__":
    raise SystemExit(main())
