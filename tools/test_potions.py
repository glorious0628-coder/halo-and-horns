"""Compile potion services and run their real Luau source against offline fixtures.

Usage: py tools/test_potions.py [--luau path/to/luau.exe] [--compiler path/to/luau-compile.exe]
Requires an installed official Luau CLI. Never downloads tools or calls Studio/Roblox/API services.
Mocked persistence/physics do not replace the live merchant, UI, reconnect and play checks.
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
FIXTURE = ROOT / "tools/fixtures/potions_offline.luau"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "SHOP_SOURCE": ROOT / "src/ServerScriptService/ShopService.luau",
    "VITALS_SOURCE": ROOT / "src/ServerScriptService/VitalsService.luau",
    "GOLD_SOURCE": ROOT / "src/ServerScriptService/ProgressionService.luau",
    "PLAYER_SOURCE": ROOT / "src/ServerScriptService/PlayerService.luau",
    "MAP_SOURCE": ROOT / "src/ServerScriptService/MapBuilder.luau",
    "COSTUME_SOURCE": ROOT / "src/ServerScriptService/CostumeService.luau",
}
OWNED = tuple(FILES[key] for key in ("CONFIG_SOURCE", "NET_SOURCE", "DATA_SOURCE", "SHOP_SOURCE", "VITALS_SOURCE", "MAP_SOURCE"))


def lua_string(value: str) -> str:
    """Preserve UTF-8 source and real newlines without a fixed delimiter collision."""
    equals = "===="
    while f"]{equals}]" in value:
        equals += "="
    return f"[{equals}[{value}]{equals}]"


def between(value: str, start: str, end: str) -> str:
    first = value.find(start)
    last = value.find(end, first + len(start)) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r} / {end!r}; update the test extractor.")
    return value[first:last]


def make_harness(sources: dict[str, str]) -> str:
    config = sources["CONFIG_SOURCE"]
    prefix = between(config, "-- Config.luau", "----------------------------------------------------------------- levels")
    rates = re.search(r"Config\.RateLimits\s*=\s*\{.*?\n\}", config, re.S)
    if not rates:
        raise ValueError("Config.RateLimits boundary changed; update the test extractor.")
    set_stat = between(sources["PLAYER_SOURCE"], "function PlayerService.SetStat(", "function PlayerService.AddStat(")
    bindings = {
        "CONFIG_SOURCE": prefix + "\n" + rates.group() + "\nreturn Config",
        "NET_SOURCE": sources["NET_SOURCE"],
        "DATA_SOURCE": sources["DATA_SOURCE"],
        "SHOP_SOURCE": sources["SHOP_SOURCE"],
        "VITALS_SOURCE": sources["VITALS_SOURCE"],
        "GOLD_SOURCE": sources["GOLD_SOURCE"],
        "SET_STAT_SOURCE": "local PlayerService = {}\nlocal S, mirrored = ...\n" + set_stat + "\nreturn PlayerService.SetStat",
        "MAP_MERCHANT_SOURCE": "local Config, ServerStorage, CostumeService, CollectionService, Util, TAG, retire = ...\n" + between(
            sources["MAP_SOURCE"], "local function ensureMerchantPrompt(", "------------------------------------------------------------------ public API"
        ) + "\nreturn ensurePotionMerchant",
        "COSTUME_VALIDATOR_SOURCE": "local CostumeService = {}\n" + between(
            sources["COSTUME_SOURCE"], "local BODY =", "local function setStatus("
        ) + "\n" + between(sources["COSTUME_SOURCE"], "function CostumeService.ValidateTemplate(", "local function getTemplate(") + "\nreturn CostumeService",
    }
    return "\n".join(f"local {name} = {lua_string(value)}" for name, value in bindings.items()) + "\n" + FIXTURE.read_text(encoding="utf-8")


def run(args: list[str], *, quiet: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=ROOT, stdout=subprocess.DEVNULL if quiet else subprocess.PIPE,
                          stderr=subprocess.PIPE, text=True, encoding="utf-8", errors="replace", timeout=60)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
    parser.add_argument("--compiler", type=Path, help="Defaults to luau-compile beside --luau.")
    args = parser.parse_args()
    args.luau = args.luau.resolve()
    compiler = (args.compiler or args.luau.with_name("luau-compile" + args.luau.suffix)).resolve()
    if not args.luau.is_file() or not compiler.is_file():
        parser.error("Pass --luau and --compiler for installed official Luau tools; this test never downloads them.")
    sources = {key: path.read_text(encoding="utf-8-sig") for key, path in FILES.items()}
    generated = ROOT / "build/potion_offline_test.luau"
    generated.parent.mkdir(exist_ok=True)
    generated.write_text(make_harness(sources), encoding="utf-8")
    compiled = run([str(compiler), *(str(path) for path in OWNED)], quiet=True)
    if compiled.returncode:
        print(compiled.stderr, file=sys.stderr, end="")
        return compiled.returncode
    tested = run([str(args.luau), str(generated)])
    marker = re.search(r"^POTION_OFFLINE_OK checks=(\d+) Studio/API calls=0$", tested.stdout, re.M)
    report = {
        "status": "passed" if tested.returncode == 0 and marker else "failed",
        "syntaxFiles": [path.relative_to(ROOT).as_posix() for path in OWNED],
        "checks": int(marker.group(1)) if marker else 0,
        "studioCalls": 0,
        "apiCalls": 0,
        "liveValidation": "pending: merchant/UI, real datastore/reconnect and engine play",
        "sourceSHA256": {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in FILES.values()},
        "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
    }
    report_path = ROOT / "build/potion_offline_report.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if tested.returncode or not marker:
        print(tested.stdout, end="")
        print(tested.stderr, file=sys.stderr, end="")
        return tested.returncode or 1
    print(f"Syntax OK: {len(OWNED)} Luau files")
    print(marker.group())
    print(f"Report: {report_path.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Potion offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
