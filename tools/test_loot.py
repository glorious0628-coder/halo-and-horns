"""A23-11 / A23-12 / A23-14 loot (+ review B1-B13, + the A23-15 announcements LootService makes): run the current LootService (+ Config, DataService,
ProgressionService, CombatService, and the JusticeService / PvPService power helpers) offline.

No Studio, network, DataStore or Roblox API calls. The real repository sources are injected into
tools/fixtures/loot_offline.luau and run with the installed official Luau CLI (build/luau_cli_0_741).
Every check is named and collected; a failure never stops the other checks. A mutation step then breaks
in-memory copies of the sources (never src/), runs them from a temporary directory and counts how many
mutations the checks catch.

Usage: py tools/test_loot.py [--no-mutations] [--luau path/to/luau.exe]
Report: docs/art/verification_2026-10-06/offline_loot_2026-10-06.json
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
FIXTURE = ROOT / "tools/fixtures/loot_offline.luau"
OUT = ROOT / "docs/art/verification_2026-10-06/offline_loot_2026-10-06.json"
FILES = {
    "CONFIG_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Config.luau",
    "NET_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Net.luau",
    "UTIL_SOURCE": ROOT / "src/ReplicatedStorage/Shared/Util.luau",
    "DATA_SOURCE": ROOT / "src/ServerScriptService/DataService.luau",
    "PLAYER_SOURCE": ROOT / "src/ServerScriptService/PlayerService.luau",
    "GOLD_SOURCE": ROOT / "src/ServerScriptService/ProgressionService.luau",
    "COMBAT_SOURCE": ROOT / "src/ServerScriptService/CombatService.luau",
    "LOOT_SOURCE": ROOT / "src/ServerScriptService/LootService.luau",
    # review B5: only the power helpers are extracted (make_harness); the whole files are hashed and mutated
    "JUSTICE_SOURCE": ROOT / "src/ServerScriptService/JusticeService.luau",
    "PVP_SOURCE": ROOT / "src/ServerScriptService/PvPService.luau",
}
EXTRACTED_ONLY = ("PLAYER_SOURCE", "JUSTICE_SOURCE", "PVP_SOURCE")
STATIC_ONLY = {
    "MONSTER": ROOT / "src/ServerScriptService/MonsterService.luau",
    "MAIN": ROOT / "src/ServerScriptService/Main.server.luau",
    "PANELS": ROOT / "src/StarterPlayer/StarterPlayerScripts/Panels.luau",
}
COMPILED = ("CONFIG_SOURCE", "GOLD_SOURCE", "COMBAT_SOURCE", "LOOT_SOURCE", "JUSTICE_SOURCE", "PVP_SOURCE")

SET_OWNED = ('S.PlayerService.SetStat(player, "WeaponOwnedMask", bit32.bor(math.floor(num(data.WeaponOwnedMask, 1)), '
             'bit32.lshift(1, tier - 1)))')
JACKPOT_BRANCH = ('local name = weaponName(player, tier)\n\ttable.insert(gained, { Weapon = tier, Name = name })\n\tif isJackpot then\n'
                  '\t\tnotify(player, string.format(TXT.JackpotSelf, name), "reward")\n'
                  '\t\tannounce(player, "Jackpot", { Weapon = tier }, tier) -- everyone sees it in chat (A23-15)\n')

# (name, source key, exact text, replacement): each must match exactly once in the current source
MUTATIONS = [
    ("enhance failure may go below +0", "LOOT_SOURCE",
     "elseif before > 0 and rng:NextNumber() < LOOT.FailDropChance then", "elseif rng:NextNumber() < LOOT.FailDropChance then"),
    ("enhance success not capped at +10", "LOOT_SOURCE",
     "after = math.min(LOOT.MaxEnhance, before + def.Plus)", "after = before + def.Plus"),
    ("enhance failure always drops", "LOOT_SOURCE",
     "elseif before > 0 and rng:NextNumber() < LOOT.FailDropChance then", "elseif before > 0 then"),
    ("enhance success chance off by 10%", "LOOT_SOURCE",
     "local success = rng:NextNumber() < def.Chance\n\tlocal after = before", "local success = rng:NextNumber() < def.Chance + 0.1\n\tlocal after = before"),
    ("scroll at +10 consumed", "LOOT_SOURCE",
     "if before >= LOOT.MaxEnhance then", "if before > LOOT.MaxEnhance then"),
    ("enhance on an unowned tier", "LOOT_SOURCE",
     "local function useEnhance(player, data, id, def, tier)\n\tif not owns(data, tier) then",
     "local function useEnhance(player, data, id, def, tier)\n\tif false then"),
    ("scroll never consumed", "LOOT_SOURCE",
     "data.Items[id] = have > 1 and have - 1 or nil", "data.Items[id] = have"),
    ("first scroll flag not kept", "LOOT_SOURCE",
     "data.LootFlags.FirstScroll = true", "data.LootFlags.FirstScroll = false"),
    ("golden multiplier ignored", "LOOT_SOURCE",
     "info.Golden == true and LOOT.GoldenMult or 1", "1"),
    ("golden multiplier for any truthy Golden", "LOOT_SOURCE",
     "info.Golden == true and LOOT.GoldenMult or 1", "info.Golden and LOOT.GoldenMult or 1"),
    ("jackpot for every monster kind", "LOOT_SOURCE",
     "jackpot.Monsters[info.Kind] and", "true and"),
    ("two rolls per kill signal", "LOOT_SOURCE",
     "local ok, err = pcall(LootService.RollKill, player, info)",
     "pcall(LootService.RollKill, player, info); local ok, err = pcall(LootService.RollKill, player, info)"),
    ("item cap ignored on drops", "LOOT_SOURCE",
     "local given = math.clamp(n, 0, room)", "local given = n"),
    ("item cap ignored by sanitize", "LOOT_SOURCE",
     "items[id] = math.min(c, LOOT.ItemCap)", "items[id] = c"),
    ("potion cap ignored", "LOOT_SOURCE",
     "if have >= cap then", "if false then"),
    ("duplicate weapon pays no gold", "LOOT_SOURCE",
     "local gold = LOOT.DuplicateWeaponGold[tier] or 0", "local gold = 0"),
    ("duplicate weapon re-announced as new", "LOOT_SOURCE",
     "if owns(data, tier) then\n\t\tlocal gold", "if false then\n\t\tlocal gold"),
    ("transfer replaces instead of adding", "LOOT_SOURCE",
     "after = math.min(LOOT.MaxEnhance, target + amount)", "after = math.min(LOOT.MaxEnhance, amount)"),
    ("transfer keeps the source +N (duplicates)", "LOOT_SOURCE",
     "data.WeaponEnhance[fromTier] = amount - (after - target)", "data.WeaponEnhance[fromTier] = amount"),
    ("transfer loses the overflow", "LOOT_SOURCE",
     "data.WeaponEnhance[fromTier] = amount - (after - target)", "data.WeaponEnhance[fromTier] = 0"),
    ("transfer onto +10 allowed", "LOOT_SOURCE",
     "if target >= LOOT.MaxEnhance then", "if target > LOOT.MaxEnhance then"),
    ("transfer from +0 allowed", "LOOT_SOURCE",
     "if amount <= 0 then", "if amount < 0 then"),
    ("equip gates an OWNED weapon by MinLevel again", "LOOT_SOURCE",
     "\tlocal def = Config.Weapons[tier]\n",
     "\tlocal def = Config.Weapons[tier]\n\tif num(data.Level, 1) < num(def.MinLevel, 1) then return end\n"),
    ("equip ignores combat", "LOOT_SOURCE",
     "if S.CombatService.IsInCombat(player) then notify(player, TXT.EquipCombat",
     "if false then notify(player, TXT.EquipCombat"),
    ("equip ignores a dead character", "LOOT_SOURCE",
     "if not Util.IsAlive(player) then notify(player, TXT.EquipDead", "if false then notify(player, TXT.EquipDead"),
    ("scroll usable in PvP combat", "LOOT_SOURCE",
     "if S.CombatService.IsInCombat(player) then notify(player, TXT.UseCombat", "if false then notify(player, TXT.UseCombat"),
    ("full notice not throttled", "LOOT_SOURCE",
     "if last and now - last < num(LOOT.FullNoticeSeconds, 300) then return end", ""),
    ("first scroll flag set although the stack was full", "LOOT_SOURCE",
     "if giveItem(first.Item, 1) > 0 then", "if giveItem(first.Item, 1) >= 0 then"),
    ("unknown saved ids deleted by sanitize", "LOOT_SOURCE",
     "if type(id) == \"string\" and #id >= 1 and #id <= STATE.SavedIdMaxLen then",
     "if type(id) == \"string\" and LOOT.Items[id] then"),
    ("unknown ids shown in the Inventory payload", "LOOT_SOURCE",
     "if type(id) == \"string\" and LOOT.Items[id] then", "if type(id) == \"string\" then"),
    ("Inventory sent to every client", "LOOT_SOURCE",
     "Net.Get(\"Inventory\"):FireClient(player, inventoryPayload(data))",
     "Net.Get(\"Inventory\"):FireAllClients(inventoryPayload(data))"),
    ("LootRoll grants real drops", "LOOT_SOURCE",
     "local info = { Kind = kind, Golden = golden == true }\n\tfor _ = 1, kills do",
     "local info = { Kind = kind, Golden = golden == true }\n"
     "\tfor _, p in Players:GetPlayers() do LootService.RollKill(p, info) end\n\tfor _ = 1, kills do"),
    ("equip ignores RequiresFaction", "LOOT_SOURCE",
     "if def.RequiresFaction and factionName(player) == \"None\" then", "if false then"),
    ("sell away from the anvil", "LOOT_SOURCE",
     "if not S.ShopService.CanBuyWeapon(player) then", "if false then"),
    ("sell also sells scrolls", "LOOT_SOURCE",
     "if def and def.Kind == \"Material\" then", "if def then"),
    ("remote rate limit bypassed", "LOOT_SOURCE",
     "and Util.RateLimit(player, key, Config.RateLimits[key] or 0.5)", "and true"),
    ("WeaponEnhance attribute not refreshed on equip", "LOOT_SOURCE",
     "if d then player:SetAttribute(\"WeaponEnhance\"", "if false then player:SetAttribute(\"WeaponEnhance\""),
    # P7 seen monsters (LootFlags "Seen:<kind>" -> Inventory payload Seen)
    ("first kill never marks the kind seen", "LOOT_SOURCE",
     "data.LootFlags[seenKey] = true", "local _ = seenKey"),
    ("first kill of a kind not pushed", "LOOT_SOURCE",
     "data.LootFlags[seenKey] = true\n\t\tpublish(player, data)", "data.LootFlags[seenKey] = true"),
    ("kinds without a drop table marked seen", "LOOT_SOURCE",
     "if LOOT.Tables[info.Kind] and data.LootFlags[seenKey] ~= true then", "if data.LootFlags[seenKey] ~= true then"),
    ("payload Seen lists unknown kinds", "LOOT_SOURCE",
     "if kind and v == true and LOOT.Tables[kind] then", "if kind and v then"),
    # A23-15 announcements (AnnounceService stub in the fixture)
    ("jackpot not announced", "LOOT_SOURCE",
     "announce(player, \"Jackpot\", { Weapon = tier }, tier)", "local _ = tier"),
    ("jackpot also announced as a RareWeapon line", "LOOT_SOURCE",
     "announce(player, \"Jackpot\", { Weapon = tier }, tier)",
     "announce(player, \"Jackpot\", { Weapon = tier }, tier); announce(player, \"RareWeapon\", { Weapon = tier, Monster = kind }, tier)"),
    ("jackpot announced before the legendary is saved", "LOOT_SOURCE",
     SET_OWNED + "\n\t" + JACKPOT_BRANCH + "\telse\n",
     JACKPOT_BRANCH + "\t\t" + SET_OWNED + "\n\telse\n\t\t" + SET_OWNED + "\n"),
    ("weapon drops of every grade announced", "LOOT_SOURCE",
     "if g.Rank >= ((Config.Announce and Config.Announce.MinWeaponGrade) or 3) then", "if true then"),
    ("RareWeapon threshold off by one (Rare not announced)", "LOOT_SOURCE",
     "if g.Rank >= ((Config.Announce", "if g.Rank > ((Config.Announce"),
    ("RareWeapon threshold ignores Config.Announce.MinWeaponGrade", "LOOT_SOURCE",
     "((Config.Announce and Config.Announce.MinWeaponGrade) or 3)", "3"),
    ("RareWeapon announce without the monster kind", "LOOT_SOURCE",
     "{ Weapon = tier, Monster = kind }", "{ Weapon = tier }"),
    ("announce grade always Common", "LOOT_SOURCE",
     "info and info.Grade or \"Common\"", "\"Common\""),
    ("announce not protected by pcall", "LOOT_SOURCE",
     "pcall(svc.Announce, player, key, args, info and info.Grade or \"Common\")",
     "svc.Announce(player, key, args, info and info.Grade or \"Common\")"),
    ("missing AnnounceService not skipped", "LOOT_SOURCE",
     "if type(svc) ~= \"table\" or type(svc.Announce) ~= \"function\" then return end", ""),
    ("FirstMax announced at every +10", "LOOT_SOURCE",
     "if after < LOOT.MaxEnhance or data.LootFlags.FirstMax == true then return end",
     "if after < LOOT.MaxEnhance then return end"),
    ("FirstMax announced below +10", "LOOT_SOURCE",
     "if after < LOOT.MaxEnhance or data.LootFlags.FirstMax", "if false or data.LootFlags.FirstMax"),
    ("FirstMax flag not kept", "LOOT_SOURCE",
     "data.LootFlags.FirstMax = true", "data.LootFlags.FirstMax = nil"),
    ("FirstMax flag set after the announce", "LOOT_SOURCE",
     "data.LootFlags.FirstMax = true\n\tannounce(player, \"FirstMax\", { Weapon = tier }, tier)",
     "announce(player, \"FirstMax\", { Weapon = tier }, tier)\n\tdata.LootFlags.FirstMax = true"),
    ("FirstMax never from an enhance scroll", "LOOT_SOURCE",
     "\t\tfirstMax(player, data, tier, after)\n", "\n"),
    ("FirstMax never from a transfer scroll", "LOOT_SOURCE",
     "\t\tfirstMax(player, data, toTier, after) -- after both tiers are saved\n", "\n"),
    ("transfer FirstMax names the source tier", "LOOT_SOURCE",
     "firstMax(player, data, toTier, after)", "firstMax(player, data, fromTier, after)"),
    ("transfer FirstMax before the target +10 is written", "LOOT_SOURCE",
     "data.WeaponEnhance[toTier] = after\n\t\tdata.WeaponEnhance[fromTier] = amount - (after - target)\n\t\tfirstMax(player, data, toTier, after)",
     "firstMax(player, data, toTier, after)\n\t\tdata.WeaponEnhance[toTier] = after\n\t\tdata.WeaponEnhance[fromTier] = amount - (after - target)"),
    ("rebirth resets the weapons (old rule)", "GOLD_SOURCE",
     "S.PlayerService.SetStat(player, \"XP\", 0)\n\n\tlocal newRebirths",
     "S.PlayerService.SetStat(player, \"XP\", 0)\n\tS.PlayerService.SetStat(player, \"WeaponOwnedMask\", 129)"
     "\n\tS.PlayerService.SetStat(player, \"WeaponTier\", 1)\n\n\tlocal newRebirths"),
    ("rebirth resets the gold (old rule)", "GOLD_SOURCE",
     "S.PlayerService.SetStat(player, \"XP\", 0)\n\n\tlocal newRebirths",
     "S.PlayerService.SetStat(player, \"XP\", 0)\n\tS.PlayerService.SetStat(player, \"CarriedGold\", 0)"
     "\n\tS.PlayerService.SetStat(player, \"BankGold\", 0)\n\n\tlocal newRebirths"),
    ("rebirth resets enhancement and items", "GOLD_SOURCE",
     "S.PlayerService.SetStat(player, \"XP\", 0)\n\n\tlocal newRebirths",
     "S.PlayerService.SetStat(player, \"XP\", 0)\n\tdata.WeaponEnhance = {}; data.Items = {}\n\n\tlocal newRebirths"),
    ("rebirth keeps the level", "GOLD_SOURCE",
     "S.PlayerService.SetStat(player, \"Level\", 1)\n\tS.PlayerService.SetStat(player, \"XP\", 0)\n\n\tlocal newRebirths",
     "S.PlayerService.SetStat(player, \"XP\", 0)\n\n\tlocal newRebirths"),
    ("legendary damage back to 90", "CONFIG_SOURCE", "{ Tier = 8, Damage = 76,", "{ Tier = 8, Damage = 90,"),
    ("10% scroll back to +3", "CONFIG_SOURCE",
     "Enh10 = { Kind = \"Enhance\", Name = \"강화 주문서 10%\", Chance = 0.1, Plus = 5,",
     "Enh10 = { Kind = \"Enhance\", Name = \"강화 주문서 10%\", Chance = 0.1, Plus = 3,"),
    ("PowerOf ignores enhancement", "CONFIG_SOURCE",
     "Config.WeaponDamage(weaponTier, level, enhance) * Config.BaseHealth(level)",
     "Config.WeaponDamage(weaponTier, level) * Config.BaseHealth(level)"),
    ("JusticeService power ignores WeaponEnhance", "JUSTICE_SOURCE",
     "local enhance = tonumber(player:GetAttribute(\"WeaponEnhance\")) or 0", "local enhance = 0"),
    ("PvP combatPower fallback ignores WeaponEnhance", "PVP_SOURCE",
     "return Config.CombatPower(level, tier, tonumber(p:GetAttribute(\"WeaponEnhance\")) or 0)",
     "return Config.CombatPower(level, tier, 0)"),
    ("EnhanceMult not clamped", "CONFIG_SOURCE",
     "math.clamp(math.floor(enhance), 0, loot.MaxEnhance)", "math.floor(enhance)"),
    ("PvP power ratio not clamped", "COMBAT_SOURCE",
     "ratio = math.clamp(ratio, Config.PvP.PowerRatioMin, Config.PvP.PowerRatioMax)", "ratio = ratio"),
    ("monster hit ignores enhancement", "COMBAT_SOURCE",
     "local dmg = Config.WeaponDamage(tier, level, numAttr(attacker, \"WeaponEnhance\", 0))",
     "local dmg = Config.WeaponDamage(tier, level, 0)"),
]


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


def function_block(text: str, start: str) -> str:
    """`start` up to and including the first top-level `end` line after it (a whole local function)."""
    first = text.find(start)
    last = text.find("\nend\n", first) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r}; update the test extractor.")
    return text[first:last + 5]


def make_harness(sources: dict[str, str], scale: float) -> str:
    bindings = {key: value for key, value in sources.items() if key not in EXTRACTED_ONLY}
    set_stat = between(sources["PLAYER_SOURCE"], "function PlayerService.SetStat(", "function PlayerService.Respawn(")
    bindings["SET_STAT_SOURCE"] = "local PlayerService = {}\nlocal S, mirrored = ...\n" + set_stat + "\nreturn PlayerService"
    # review B5: JusticeService.GetPower / GetCombatPower (+ levelAndTier) and PvPService's combatPower fallback
    justice = between(sources["JUSTICE_SOURCE"], "local function levelAndTier(", "-- 1 for \"None\"")
    bindings["JUSTICE_POWER_SOURCE"] = "local Config = ...\nlocal JusticeService = {}\n" + justice + "\nreturn JusticeService"
    pvp_num = function_block(sources["PVP_SOURCE"], "local function num(p, key, default)")
    # only the local function itself: PvPService.BoldMult / ScalePoints (A23-18) follow it and need the whole service
    pvp_power = function_block(sources["PVP_SOURCE"], "local function combatPower(p)")
    bindings["PVP_POWER_SOURCE"] = ("local Config = ...\nlocal S = nil\n" + pvp_num + "\n" + pvp_power
                                    + "\nreturn { combatPower = function(p, registry) S = registry; return combatPower(p) end }")
    head = "\n".join(f"local {key} = {literal(value)}" for key, value in bindings.items())
    return head + f"\nlocal SAMPLE_SCALE = {scale!r}\n" + FIXTURE.read_text(encoding="utf-8")


def run_harness(binary: Path, harness_text: str, directory: Path, name: str) -> dict:
    path = directory / name
    path.write_text(harness_text, encoding="utf-8")
    proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=900)
    result = None
    for line in proc.stdout.splitlines():
        if line.startswith("LOOT_RESULT_JSON "):
            result = json.loads(line[len("LOOT_RESULT_JSON "):])
    return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}


def failing_keys(result: dict | None) -> set[str]:
    if not result:
        return set()
    return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}


def static_checks(sources: dict[str, str]) -> tuple[int, list[str]]:
    failures: list[str] = []
    count = 0

    def check(ok: bool, message: str) -> None:
        nonlocal count
        count += 1
        if not ok:
            failures.append(message)

    monster = STATIC_ONLY["MONSTER"].read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    loop = re.search(r"for _, e in eligible do\n(.*?)\n\tend\n", monster, re.S)
    check(loop is not None and "MonsterService.MonsterKilled:Fire(e.Player, i)" in loop.group(1)
          and monster.count("MonsterKilled:Fire(") == 1,
          "MonsterService must fire MonsterKilled once per eligible contributor (one loot roll each)")
    main = STATIC_ONLY["MAIN"].read_text(encoding="utf-8-sig")
    check(main.count('"LootService"') >= 2, "Main.server.luau must list LootService in the load and start lists")
    writers = []
    for path in sorted((ROOT / "src").rglob("*.luau")):
        if path == FILES["LOOT_SOURCE"]:
            continue
        text = path.read_text(encoding="utf-8-sig")
        for number, line in enumerate(text.splitlines(), 1):
            code = line.split("--", 1)[0]
            if re.search(r'(\.(Items|WeaponEnhance|LootFlags)(\[[^\]]*\])?\s*=[^=]|SetAttribute\(\s*"(ItemsJson|EnhanceJson|WeaponEnhance)")', code):
                rel = path.relative_to(ROOT).as_posix()
                if rel.startswith("src/StarterPlayer/") or rel.startswith("src/StarterGui/"):
                    continue  # client-side display tables only
                writers.append(f"{rel}:{number}")
    check(not writers, f"only LootService writes Items / WeaponEnhance / LootFlags and their attributes; other writers: {writers}")
    loot = sources["LOOT_SOURCE"]
    check("Net.Get(\"UseItem\")" in loot and "Net.Get(\"EquipWeapon\")" in loot and "Net.Get(\"SellMaterials\")" in loot,
          "LootService connects UseItem / EquipWeapon / SellMaterials")
    # review B11: ItemsJson / EnhanceJson attributes (replicated to every client) are gone everywhere; the client listens
    # to the owner-only Inventory remote instead
    json_users = []
    for path in sorted((ROOT / "src").rglob("*.luau")):
        for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            if re.search(r"\b(ItemsJson|EnhanceJson)\b", line.split("--", 1)[0]):
                json_users.append(f"{path.relative_to(ROOT).as_posix()}:{number}")
    check(not json_users, f"no code reads or writes the ItemsJson / EnhanceJson attributes any more: {json_users}")
    panels = STATIC_ONLY["PANELS"].read_text(encoding="utf-8-sig")
    check(re.search(r'(Net\.Get\(\s*"Inventory"\s*\)|(FindFirstChild|WaitForChild)\(\s*"Inventory"\s*[,)])', panels) is not None
          and "OnClientEvent" in panels,
          "Panels listens to the owner-only Inventory remote")
    check("FireAllClients" not in loot, "LootService never fires to all clients")
    # review B12: the Studio LootRoll debug key is count-only (DebugSimulate), capped, and never grants
    main_text = STATIC_ONLY["MAIN"].read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    branch = re.search(r'key == "LootRoll" then(.*?)\n\t\telseif', main_text, re.S)
    body = branch.group(1) if branch else ""
    check(branch is not None and "DebugSimulate(" in body and "100000" in body
          and "RollKill" not in body and "DebugGive" not in body,
          "Main LootRoll uses the count-only LootService.DebugSimulate with n capped at 100000")
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

    compiled = subprocess.run([str(compiler), *(str(FILES[k]) for k in COMPILED), str(FIXTURE)], cwd=ROOT,
                              stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", timeout=120)
    static_count, static_failures = static_checks(sources)

    with tempfile.TemporaryDirectory(prefix="loot_offline_") as tmp:
        tmpdir = Path(tmp)
        main_run = run_harness(binary, make_harness(sources, 1.0), tmpdir, "loot_offline_main.luau")
        result = main_run["result"]
        baseline = failing_keys(result)

        mutations = []
        if not args.no_mutations:
            jobs = []
            for name, key, old, new in MUTATIONS:
                hits = sources[key].count(old)
                if hits != 1:
                    mutations.append({"mutation": name, "file": FILES[key].relative_to(ROOT).as_posix(),
                                      "applied": False, "caught": False,
                                      "note": f"pattern matched {hits} times; update MUTATIONS"})
                    continue
                mutated = dict(sources)
                mutated[key] = sources[key].replace(old, new, 1)
                jobs.append((name, key, make_harness(mutated, 0.25)))

            def work(index_job):
                index, (name, key, text) = index_job
                out = run_harness(binary, text, tmpdir, f"loot_mutant_{index:02d}.luau")
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
    marker = re.search(r"LOOT_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
    named = result.get("Named", []) if result else []
    failing = [n for n in named if n.get("Fail", 0) > 0]
    caught = sum(1 for m in mutations if m.get("caught"))
    applied = sum(1 for m in mutations if m.get("applied"))
    ok = (compiled.returncode == 0 and main_run["returncode"] == 0 and marker is not None and not static_failures
          and not changed and all(m.get("applied") for m in mutations))
    report = {
        "status": "passed" if ok else "failed",
        "checks": result.get("Checks", 0) if result else 0,
        "failedChecks": result.get("Failed", 0) if result else 0,
        "namedChecks": len(named),
        "namedChecksFailing": len(failing),
        "failing": [{"group": n["Group"], "check": n["Name"], "failures": n["Fail"], "passes": n["Pass"],
                     "firstFailure": n.get("FirstFailure")} for n in failing],
        "named": [{"group": n["Group"], "check": n["Name"], "pass": n["Pass"], "fail": n["Fail"]} for n in named],
        "findings": result.get("Findings", []) if result else [],
        "measuredRates": result.get("Stats", {}) if result else {},
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
        "contract": "A23-11 / A23-12 / A23-14 + review B1-B13 (2026-10-05): one own server roll per kill contributor; items "
                    "auto-granted, never lost; enhance scrolls 70% +1 / 30% +3 / 10% +5, failure 50% -1 (never below +0) else kept, "
                    "max +10, refused at +10; transfer scrolls 70/30/10% ADD the source +N onto the target up to +10 and leave the "
                    "rest on the source (lossless), refused when the target is +10 or the source +0, failure changes nothing but "
                    "uses the scroll; scrolls refused in PvP combat (kept); equip needs a living character and no PvP combat, "
                    "MinLevel gates purchases only (owned weapons re-equip at any level); drop tables: scroll chances rise with "
                    "the zone (reviewer B2 table, transfer ~1/3), potions halved; legendary damage 76 = 2 x tier 3; PowerOf "
                    "includes enhancement (Justice/PvP read the WeaponEnhance attribute); owner-only Inventory remote "
                    "{ Items = known ids, Enhance = 8 tiers } replaces ItemsJson/EnhanceJson; unknown saved ids kept but hidden; "
                    "full notices once per item id per 5 min (info); FirstScroll flag only on a real grant (6 s guide, Fx First); "
                    "LootRoll debug is count-only; rebirth resets only Level/XP (gold, weapons, enhancement, items kept); "
                    "first BigSlime = one Enh70 once; Slime jackpot tier 8 at 1/20000 (x3 golden); duplicate weapons -> gold; "
                    "materials sold only at the anvil, removed before payment. A23-15: a new non-jackpot weapon drop of grade rank >= "
                    "Config.Announce.MinWeaponGrade (3 = Rare) -> AnnounceService.Announce(player, \"RareWeapon\", { Weapon, "
                    "Monster }, grade id), Common/Fine never; a new jackpot legendary -> exactly one \"Jackpot\" { Weapon } "
                    "(grade Legend), ownership saved first, a duplicate jackpot = gold only, no Net.NotifyAll; the first weapon "
                    "to reach +10 per player (enhance or transfer scroll) sets LootFlags.FirstMax then announces \"FirstMax\" "
                    "{ Weapon } once (saved, survives reload); a missing or failing AnnounceService never blocks the grant.",
        "limitations": "Offline service doubles (DataStore = JSON round trip, rate limit clock, ShopService.CanBuyWeapon and "
                       "CombatService.IsInCombat stubbed for LootService, AnnounceService a recording stub (its 10 s grouping, name "
                       "hiding and client chat text are not exercised), a stand-in character for Util.IsAlive, task.defer "
                       "flushed by the fixture, Inventory remote captured). Justice/PvP power helpers are extracted functions, "
                       "not the whole services. Client item panel, Fx, real MonsterService kills, multiplayer and Studio play "
                       "are not certified here.",
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if compiled.returncode:
        print(compiled.stderr, end="")
    for line in main_run["stdout"].splitlines():
        if line.startswith("CHECK_FAIL") or line.startswith("LOOT_OFFLINE"):
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
    print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
          f"assertions {report['checks'] - report['failedChecks']}/{report['checks']}")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if ok else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"Loot offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
