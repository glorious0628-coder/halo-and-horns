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
# zone_check_halo #34: each mutant must make the fixture fail (exact search text, matched once, in-memory sources only)
SHOP, CONF = "SHOP_SOURCE", "CONFIG_SOURCE"
MUTATIONS = [
    ("#34 tagged sellers ignored (Crossroads only)", SHOP, "for _, merchant in tagged do add(merchant) end", "local _ = tagged"),
    ("#34 the Crossroads seller's old path dropped", SHOP, "if legacy and legacy.Parent == npcs then add(legacy) end",
     "local _ = legacy"),
    ("#34 a moved Crossroads seller still sells by name", SHOP, "if legacy and legacy.Parent == npcs then add(legacy) end",
     "if legacy then add(legacy) end"),
    ("#34 non-Model sellers accepted", SHOP, "not merchant:IsA(\"Model\")", "false"),
    ("#34 sellers outside workspace accepted", SHOP, "not merchant:IsDescendantOf(workspace)", "false"),
    ("#34 seller attribute not required", SHOP, "merchant:GetAttribute(\"HHC_PotionMerchant\") ~= true", "false"),
    ("#34 an unanchored (client-movable) root accepted", SHOP, "part.Anchored ~= true", "false"),
    ("#34 a root outside its model accepted", SHOP, "not part:IsDescendantOf(merchant)", "false"),
    ("#34 a disabled seller prompt still sells", SHOP, "prompt.Parent ~= part or not prompt.Enabled then return nil end",
     "prompt.Parent ~= part then return nil end"),
    ("#34 any seller's prompt opens the shop", SHOP, "if prompt == nil or seller.Prompt == prompt then", "if true then"),
    ("#34 the handler skips the prompt's own seller", SHOP,
     "prompt.Name ~= Config.Vitals.PotionMerchantPrompt or not sellerNear(player, prompt)",
     "prompt.Name ~= Config.Vitals.PotionMerchantPrompt or not sellerNear(player, nil)"),
    ("#34 no distance limit", SHOP, "local best, bestDistance = nil, limit", "local best, bestDistance = nil, math.huge"),
    ("#34 MerchantEnabled ignored", SHOP, "if Config.Vitals.MerchantEnabled ~= true or typeof(player) ~= \"Instance\"",
     "if typeof(player) ~= \"Instance\""),
    ("#34 Config: the seller tag renamed", CONF, "PotionMerchantTag = \"PotionMerchant\",", "PotionMerchantTag = \"NPC\","),
]


def run_mutations(sources: dict[str, str], luau: Path) -> list[dict]:
    results: list[dict] = []
    for index, (name, key, old, new) in enumerate(MUTATIONS):
        hits = sources[key].count(old)
        if hits != 1:
            results.append({"mutation": name, "applied": False, "caught": False,
                            "note": f"pattern matched {hits} times; update MUTATIONS"})
            continue
        mutated = dict(sources)
        mutated[key] = sources[key].replace(old, new, 1)
        try:
            text = make_harness(mutated)
        except ValueError as error:  # the mutant broke an extractor boundary: caught
            results.append({"mutation": name, "applied": True, "caught": True, "note": str(error)})
            continue
        path = ROOT / f"build/potion_mutant_{index:02d}.luau"
        path.write_text(text, encoding="utf-8")
        out = run([str(luau), str(path)])
        survived = out.returncode == 0 and re.search(r"^POTION_OFFLINE_OK ", out.stdout, re.M) is not None
        first = next((line for line in out.stderr.splitlines() if line.strip()), "")
        results.append({"mutation": name, "applied": True, "caught": not survived, "firstFailure": first[-300:]})
    return results


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
    # A23-71: DataService gives an old save its skill slots once with Config.SkillSlotsFor (Config.Skills: all literals)
    skills = re.search(r"^Config\.Skills\s*=\s*\{.*?\n\}", config, re.S | re.M)
    slots_for = re.search(r"^function Config\.SkillSlotsFor\(.*?\nend", config, re.S | re.M)
    if not skills or not slots_for:
        raise ValueError("Config.Skills / Config.SkillSlotsFor boundary changed; update the test extractor.")
    set_stat = between(sources["PLAYER_SOURCE"], "function PlayerService.SetStat(", "function PlayerService.AddStat(")
    bindings = {
        "CONFIG_SOURCE": prefix + "\n" + rates.group() + "\n" + bully.group() + "\n" + settings + "\n" + texts.group()
                         + "\n" + skills.group() + "\n" + slots_for.group()
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
    parser.add_argument("--no-mutations", action="store_true")
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
    mutations = [] if args.no_mutations or tested.returncode or not marker else run_mutations(sources, args.luau)
    missed = [m for m in mutations if not (m["applied"] and m["caught"])]
    passed = tested.returncode == 0 and marker and not static_failures and not missed
    report = {
        # dev2 runner rule: never plain "passed" without the mutation step
        "status": ("passed-no-mutations" if args.no_mutations else "passed") if passed else "failed",
        "mutationsSkipped": bool(args.no_mutations),
        "mutations": {"total": len(MUTATIONS), "caught": sum(1 for m in mutations if m["caught"]), "results": mutations},
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
    for m in mutations:
        print(f"MUTATION {'caught ' if m['caught'] else 'MISSED'} {m['mutation']}" + ("" if m["applied"] else f" ({m['note']})"))
    if mutations:
        print(f"MUTATIONS caught={len(mutations) - len(missed)}/{len(MUTATIONS)}")
    if args.no_mutations:
        print("MUTATIONS SKIPPED (status passed-no-mutations: do not commit this report)")
    if tested.returncode or not marker or static_failures or missed:
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
