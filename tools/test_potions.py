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
}
# A23-5/A23-6: the costume modules were deleted; the merchant is a default HumanoidDescription NPC built by MapBuilder.
REMOVED_MODULES = {
    "CostumeService": "src/ServerScriptService/CostumeService.luau",
    "ExpressionService": "src/ServerScriptService/ExpressionService.luau",
    "ExpressionSkinContract": "src/ServerScriptService/ExpressionSkinContract.luau",
    "SkinRetargetClient": "src/StarterPlayer/StarterPlayerScripts/SkinRetargetClient.luau",
    "SkinBindingContract": "src/ReplicatedStorage/Shared/SkinBindingContract.luau",
    "ExpressionAssets": "src/ReplicatedStorage/Shared/ExpressionAssets.luau",
}


def costume_removal_checks() -> tuple[int, list[str]]:
    """Removed modules stay removed and nothing waits for or requires them (a WaitForChild on one hangs start-up)."""
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    lists = {
        "server": (ROOT / "src/ServerScriptService/Main.server.luau").read_text(encoding="utf-8-sig"),
        "client": (ROOT / "src/StarterPlayer/StarterPlayerScripts/ClientMain.client.luau").read_text(encoding="utf-8-sig"),
    }
    every = {path.relative_to(ROOT).as_posix(): path.read_text(encoding="utf-8-sig") for path in (ROOT / "src").rglob("*.luau")}
    for name, rel in REMOVED_MODULES.items():
        check(not (ROOT / rel).exists(), f"{rel} still exists")
        for side, text in lists.items():
            check(f'"{name}"' not in text, f"{side} entry point still loads {name}")
        use = re.compile(rf"(require\([^)]*\b{name}\b|WaitForChild\(\"{name}\"\)|\bS\.{name}\b|\[\"{name}\"\])")
        users = [f"{path}:{number}" for path, text in every.items()
                 for number, line in enumerate(text.splitlines(), 1) if use.search(line.split("--", 1)[0])]
        check(not users, f"{name} is still required/awaited by {users}")
    net = every["src/ReplicatedStorage/Shared/Net.luau"]
    config = every["src/ReplicatedStorage/Shared/Config.luau"]
    check('"SetCostume"' not in net, "Net still registers the SetCostume remote")
    check(not re.search(r"\bSetCostume\s*=", config), "Config.RateLimits still has SetCostume")
    check(not re.search(r"\bCostumeEnabled\s*=", config), "Config still defines CostumeEnabled")
    return count, failures
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
    # ShopService player-facing strings live in Config.Text (central text table for localization); it is all literals.
    texts = re.search(r"^Config\.Text\s*=\s*\{.*?\n\}", config, re.S | re.M)
    if not texts:
        raise ValueError("Config.Text boundary changed; update the test extractor.")
    weapons = re.search(r"^Config\.Weapons\s*=\s*\{(.*?)\n\}", config, re.S | re.M)
    if not weapons:
        raise ValueError("Config.Weapons boundary changed; update the test extractor.")
    max_tier = len(re.findall(r"\{\s*Tier\s*=\s*\d+", weapons.group(1)))
    # BB2: DataService.fillDefaults runs Config.SanitizeSettings (pure; the keys + settings section after RateLimits)
    settings = between(config, "----------------------------------------------------------------- keys + settings (BB1 / BB2)",
                       "\nConfig.Loot = {")
    # BB15: Config.Help (inside that section) formats the bully numbers at load time; Config.Bully is all literals
    bully = re.search(r"^Config\.Bully\s*=\s*\{.*?\n\}", config, re.S | re.M)
    if not bully:
        raise ValueError("Config.Bully boundary changed; update the test extractor.")
    set_stat = between(sources["PLAYER_SOURCE"], "function PlayerService.SetStat(", "function PlayerService.AddStat(")
    bindings = {
        "CONFIG_SOURCE": prefix + "\n" + rates.group() + "\n" + bully.group() + "\n" + settings + "\n" + texts.group()
                         + f"\nConfig.MaxWeaponTier = {max_tier} -- extracted: number of Config.Weapons rows\nreturn Config",
        "NET_SOURCE": sources["NET_SOURCE"],
        "DATA_SOURCE": sources["DATA_SOURCE"],
        "SHOP_SOURCE": sources["SHOP_SOURCE"],
        "VITALS_SOURCE": sources["VITALS_SOURCE"],
        "GOLD_SOURCE": sources["GOLD_SOURCE"],
        "SET_STAT_SOURCE": "local PlayerService = {}\nlocal S, mirrored = ...\n" + set_stat + "\nreturn PlayerService.SetStat",
        "MAP_MERCHANT_SOURCE": "local Config, CollectionService, Util, TAG, retire = ...\n" + between(
            sources["MAP_SOURCE"], "local function ensureMerchantPrompt(", "------------------------------------------------------------------ public API"
        ) + "\nreturn ensurePotionMerchant",
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
    static_count, static_failures = costume_removal_checks()
    for message in static_failures:
        print(f"STATIC_FAILURE {message}", file=sys.stderr)
    sources ={key: path.read_text(encoding="utf-8-sig") for key, path in FILES.items()}
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
        "status": "passed" if tested.returncode == 0 and marker and not static_failures else "failed",
        "syntaxFiles": [path.relative_to(ROOT).as_posix() for path in OWNED],
        "checks": int(marker.group(1)) if marker else 0,
        "costumeRemovalChecks": static_count,
        "costumeRemovalFailures": static_failures,
        "studioCalls": 0,
        "apiCalls": 0,
        "liveValidation": "pending: merchant/UI, real datastore/reconnect and engine play",
        "contract": "A23-6 MerchantEnabled=true, prices 25/25, merchant = MapBuilder default R15 NPC from HumanoidDescription "
                    "(no costume rig), E key + HoldDuration 0 prompt; costume modules, SetCostume remote/rate limit and CostumeEnabled removed",
        "sourceSHA256": {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in FILES.values()},
        "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(),
    }
    report_path = ROOT / "docs/art/verification_2026-10-06/offline_potions_2026-10-06.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if tested.returncode or not marker or static_failures:
        print(tested.stdout, end="")
        print(tested.stderr, file=sys.stderr, end="")
        return tested.returncode or 1
    print(f"Syntax OK: {len(OWNED)} Luau files")
    print(marker.group())
    print(f"COSTUME_REMOVAL_STATIC_OK checks={static_count}")
    print(f"Report: {report_path.relative_to(ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Potion offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
