"""Run current owner-avatar restoration source in a deterministic offline Luau fixture.

Requires installed official Luau CLI; never calls Studio, network APIs or Git.
Scheduling, Instances and physics are test doubles: live avatar/OFF testing is still required.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/fixtures/owner_restore_offline.luau"
FILES = {
    "PLAYER_SOURCE": ROOT / "src/ServerScriptService/PlayerService.luau",
    "VITALS_SOURCE": ROOT / "src/ServerScriptService/VitalsService.luau",
    "ZONE_SOURCE": ROOT / "src/ServerScriptService/ZoneService.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
}


def between(text: str, first: str, last: str) -> str:
    start = text.find(first)
    end = text.find(last, start + len(first)) if start >= 0 else -1
    if start < 0 or end < 0:
        raise ValueError(f"Source boundary changed: {first!r} / {last!r}")
    return text[start:end]


def lua_string(text: str) -> str:
    equals = "===="
    while f"]{equals}]" in text:
        equals += "="
    return f"[{equals}[{text}]{equals}]"


def expose(text: str, module: str, private: str) -> str:
    pattern = rf"\nreturn {module}\s*$"
    result, count = re.subn(pattern, f"\nreturn {module}, {{ {private} }}\n", text)
    if count != 1:
        raise ValueError(f"Expected one final return in {module}; update the fixture extractor.")
    return result


def harness(sources: dict[str, str]) -> str:
    config = between(sources["CONFIG_SOURCE"], "-- Config.luau", "----------------------------------------------------------------- levels")
    rate_limits = re.search(r"Config\.RateLimits\s*=\s*\{.*?\n\}", sources["CONFIG_SOURCE"], re.S)
    if not rate_limits:
        raise ValueError("Config.RateLimits boundary changed.")
    utility = between(sources["UTIL_SOURCE"], "local Util = {}", "------------------------------------------------------------------ logging")
    utility += "\n" + between(sources["UTIL_SOURCE"], "function Util.GetCharacter(", "-- first existing child")
    bindings = {
        "CONFIG_SOURCE": config + "\n" + rate_limits.group() + "\nreturn Config",
        "UTIL_SOURCE": utility + "\nreturn Util",
        "PLAYER_SOURCE": expose(sources["PLAYER_SOURCE"], "PlayerService", "ready=ready, characterLoading=characterLoading, respawnQueued=respawnQueued, nativeRestore=nativeRestore, cosmeticContext=cosmeticContext, onCharacterAdded=onCharacterAdded, standingHeight=standingHeight, cosmeticPivot=cosmeticPivot, conns=conns"),
        "VITALS_SOURCE": expose(sources["VITALS_SOURCE"], "VitalsService", "states=states, usePotion=usePotion"),
        "ZONE_SOURCE": "local ZoneService = {}\nlocal move = ...\n" + between(sources["ZONE_SOURCE"], "function ZoneService.CaptureMovementTrack(", "-- zone.Spawn") + "\nreturn ZoneService",
    }
    return "\n".join(f"local {key} = {lua_string(value)}" for key, value in bindings.items()) + "\n" + FIXTURE.read_text(encoding="utf-8")


def run(argv: list[str], *, quiet: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(argv, cwd=ROOT, stdout=subprocess.DEVNULL if quiet else subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace", timeout=60)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    parser.add_argument("--compiler", type=Path)
    args = parser.parse_args()
    luau = args.luau.resolve()
    compiler = (args.compiler or luau.with_name("luau-compile" + luau.suffix)).resolve()
    if not luau.is_file() or not compiler.is_file():
        parser.error("Pass installed --luau/--compiler; this test never downloads tools.")
    source_bytes = {key: path.read_bytes() for key, path in FILES.items()}
    sources = {key: value.decode("utf-8-sig") for key, value in source_bytes.items()}
    generated = ROOT / "build/owner_restore_offline_test.luau"
    generated.parent.mkdir(exist_ok=True)
    generated.write_text(harness(sources), encoding="utf-8")
    syntax_paths = [FILES[key] for key in ("PLAYER_SOURCE", "VITALS_SOURCE", "ZONE_SOURCE")]
    compiled = run([str(compiler), *(str(path) for path in syntax_paths)], quiet=True)
    tested = run([str(luau), str(generated)]) if compiled.returncode == 0 else None
    stdout = tested.stdout if tested else ""
    summary = re.search(r"^OWNER_RESTORE_SUMMARY checks=(\d+) cases=(\d+) failed=(\d+) Studio/API calls=0$", stdout, re.M)
    case_rows = [{"name": name, "status": status.lower(), "detail": detail}
                 for name, status, detail in re.findall(r"^OWNER_RESTORE_CASE ([\w_]+) (PASS|FAIL) ?(.*)$", stdout, re.M)]
    passed = compiled.returncode == 0 and tested is not None and tested.returncode == 0 and summary is not None and summary[3] == "0"
    report = {"status": "passed" if passed else "failed", "checks": int(summary[1]) if summary else 0,
              "cases": case_rows, "failedCases": int(summary[3]) if summary else len(case_rows),
              "syntaxFiles": [path.relative_to(ROOT).as_posix() for path in syntax_paths],
              "studioCalls": 0, "apiCalls": 0,
              "liveValidation": "pending: native engine scheduling, ownership, collisions and real OFF/respawn",
              "sourceSHA256": {FILES[key].relative_to(ROOT).as_posix(): hashlib.sha256(value).hexdigest() for key, value in source_bytes.items()},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest()}
    report_path = ROOT / "build/owner_restore_offline_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if compiled.returncode:
        print(compiled.stderr, file=sys.stderr, end="")
    if tested:
        print(tested.stdout, end="")
        print(tested.stderr, file=sys.stderr, end="")
    print(f"Report: {report_path.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Owner restoration offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
